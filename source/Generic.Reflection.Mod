MODULE TestReflection; 
(** (c) Felix Friedrich, ETH Zurich, 2016 -- Reflection with more structured references section emitted by FoxCompiler *)

IMPORT Modules, D := Debugging, Streams, SYSTEM, Commands, Machine, Heaps, Objects, Trace;

CONST 
	ShowAllProcs = TRUE;
	MaxFrames = 128;
	MaxString = 64;
	MaxArray = 8;
	MaxCols = 70;
	Sep = "  ";
	SepLen = 2;
	LineDelay = 0;

CONST 
	sfTypeNone = 0X;
	sfTypeCHAR = 01X;
	sfTypeCHAR8 = 02X;
	sfTypeCHAR16 = 03X;
	sfTypeCHAR32 = 04X;
	sfTypeRANGE = 05X;
	sfTypeSHORTINT = 06X;
	sfTypeINTEGER = 07X;
	sfTypeLONGINT = 08X;
	sfTypeHUGEINT = 09X;
	sfTypeWORD = 0AX;
	sfTypeLONGWORD = 0BX;
	sfTypeSIGNED8 = 0CX;
	sfTypeSIGNED16 = 0DX;
	sfTypeSIGNED32 = 0EX;
	sfTypeSIGNED64 = 0FX;
	sfTypeUNSIGNED8 = 10X;
	sfTypeUNSIGNED16 = 11X; 
	sfTypeUNSIGNED32 = 12X;
	sfTypeUNSIGNED64 = 13X;
	sfTypeREAL = 14X;
	sfTypeLONGREAL = 15X;
	sfTypeCOMPLEX = 16X;
	sfTypeLONGCOMPLEX = 17X;
	sfTypeBOOLEAN = 18X;
	sfTypeSET = 19X;
	sfTypeANY = 1AX;
	sfTypeOBJECT = 1BX; 
	sfTypeBYTE = 1CX; 
	sfTypeADDRESS = 1DX; 
	sfTypeSIZE = 1EX; 

	sfTypeRecord = 20X;	

	sfTypePointerToRecord = 21X;
	sfTypePointerToArray = 22X;
	sfTypeOpenArray = 23X;
	sfTypeStaticArray = 24X;
	sfTypeDynamicArray = 25X;
	sfTypeMathStaticArray = 26X;
	sfTypeMathOpenArray = 27X;
	sfTypeMathTensor = 28X;
	sfTypeDelegate = 29X; 

	sfValPar = 0X;
	sfVarPar = 1X;
	sfConstPar = 2X; 

	sfScopeBegin = 0F0X;
	sfScopeEnd = 0F1X; 
	sfProcedure = 0F2X; 
	sfVariable = 	0F3X;
	sfParameter = 0F4X;
	sfTypeDeclaration = 0F5X;

	(*
		References section format: 
		
		Scope = sfScopeBegin {variable:Variable} {procedure:Procedure} {typeDecl:TypeDeclaration} sfScopeEnd
		Procedure = sfProcedure prevSymbolOffset:SIZE name:String start:ADR end:ADR returnType:Type {parameter:Parameter} Scope
		Variable = sfVariable prevSymbolOffset:SIZE name:String (address:ADDRESS | offset:SIZE) type:Type 
		Parameter = sfParameter prevSymbolOffset:SIZE name:String (rfVar | rfConst | rfVal) offset:SIZE type:Type  
		TypeDeclaration = sfTypeDeclaration prevSymbolOffset:SIZE name:String typeInfo:ADR Scope
	*)


	VAR
		modes: ARRAY 25 OF CHAR;

	TYPE 
		Name = ARRAY 128 OF CHAR;

	PROCEDURE CheckHeapAddress(address: ADDRESS): BOOLEAN;
	BEGIN
		RETURN Machine.ValidHeapAddress(address);
	END CheckHeapAddress;
	
	PROCEDURE Wait(w: Streams.Writer);
	VAR i: LONGINT;
	BEGIN
		IF LineDelay > 0 THEN
			FOR i := 0 TO LineDelay DO END;
			w.Update
		END;
	END Wait;
	
	PROCEDURE Expect(b: BOOLEAN): BOOLEAN;
	BEGIN
		IF ~b THEN Trace.String("Format error in references section"); Trace.Ln END;
		RETURN b;
	END Expect;


	(* consume a char from the byte stream *)
	PROCEDURE GetChar(refs: Modules.Bytes; VAR offset: LONGINT): CHAR;
	VAR c: CHAR; 
	BEGIN
		IF ~Expect(offset < LEN(refs)) THEN RETURN 0X END; 
		c := refs[offset];
		INC(offset);
		RETURN c;
	END GetChar;

	(* skip a char in the byte stream *)
	PROCEDURE SkipChar(VAR offset: LONGINT);
	BEGIN
		INC(offset, SIZEOF(CHAR)); 
	END SkipChar;
	
	(* consume an address in the byte stream *)
	PROCEDURE GetAddress(refs: Modules.Bytes; VAR offset: LONGINT): ADDRESS;
	VAR adr: ADDRESS; i: LONGINT;
	BEGIN
		FOR i := 0 TO SIZEOF(ADDRESS)-1 DO
			SYSTEM.PUT8(ADDRESSOF(adr)+i, GetChar(refs, offset));
		END;
		RETURN adr;
	END GetAddress;

	(* skip an address in the byte stream *)
	PROCEDURE SkipAddress(VAR offset: LONGINT);
	BEGIN
		INC(offset, SIZEOF(ADDRESS)); 
	END SkipAddress;

	(* consume a size in the byte stream *)
	PROCEDURE GetSize(refs: Modules.Bytes; VAR offset: LONGINT): SIZE;
	VAR size: SIZE; i: LONGINT;
	BEGIN
		FOR i := 0 TO SIZEOF(SIZE)-1 DO
			SYSTEM.PUT8(ADDRESSOF(size)+i, refs[offset]);
			INC(offset);
		END;
		RETURN size;
	END GetSize;

	(* skip a size in the byte stream *)
	PROCEDURE SkipSize(VAR offset: LONGINT);
	BEGIN
		INC(offset, SIZEOF(SIZE)); 
	END SkipSize;

	(* consume a string in the byte stream *)
	PROCEDURE GetString(refs: Modules.Bytes; VAR offset: LONGINT; VAR string: ARRAY OF CHAR);
	VAR ch: CHAR; i: LONGINT; 
	BEGIN
		i := 0; 
		REPEAT
			ch := GetChar(refs, offset); 
			string[i] := ch;
			INC(i); 
		UNTIL ch = 0X; 
	END GetString;

	(* skip a string in the byte stream *)
	PROCEDURE SkipString(refs: Modules.Bytes; VAR offset: LONGINT);
	BEGIN
		WHILE(refs[offset] # 0X) DO INC(offset) END; INC(offset);
	END SkipString;
	
	(* extract a full name from the byte stream by traversing up the symbols in their scopes *)
	PROCEDURE GetFullName(refs: Modules.Bytes; offset: LONGINT; VAR name: ARRAY OF CHAR);
	VAR n: LONGINT; 
	
		PROCEDURE Traverse(offset: LONGINT);
		VAR c: CHAR;
		BEGIN
			IF offset >= 0 THEN
				c := GetChar(refs, offset);
				IF (c = sfProcedure) OR (c=sfVariable) OR (c=sfParameter) OR (c=sfTypeDeclaration) THEN
					Traverse(GetSize(refs, offset));
				END;
				IF (n > 0) & (n<LEN(name)) THEN name[n] := "."; INC(n); END;
				WHILE (n<LEN(name)) & (refs[offset] # 0X) DO
					name[n] := refs[offset];
					INC(n); INC(offset);
				END;
			END;
		END Traverse;
		
	BEGIN
		n := 0;
		Traverse(offset);
		name[n] := 0X;
	END GetFullName; 

	
	(* "lock free" version of Modules.ThisTypeByAdr *)
	PROCEDURE ThisTypeByAdr(adr: ADDRESS; VAR m: Modules.Module; VAR t: Modules.TypeDesc);
	BEGIN
		IF adr # 0 THEN
			SYSTEM.GET (adr + Heaps.TypeDescOffset, adr);
			IF CheckHeapAddress(adr) THEN
				t := SYSTEM.VAL(Modules.TypeDesc, adr);
				m := t.mod;
			ELSE
				m := NIL; t := NIL
			END
		ELSE
			m := NIL; t := NIL
		END
	END ThisTypeByAdr;

	(* output type descriptor information *)
	PROCEDURE WriteType*(w: Streams.Writer; adr: ADDRESS);
	VAR module: Modules.Module; typeDesc: Modules.TypeDesc;
	BEGIN
		IF CheckHeapAddress(adr) THEN
			ThisTypeByAdr(adr, module, typeDesc);
			IF module # NIL THEN
				w.String(module.name);
			ELSE
				w.String("NIL");  RETURN
			END;
			w.String(".");
			IF typeDesc # NIL THEN
				IF typeDesc.name = "" THEN
					w.String("ANONYMOUS")
				ELSE
					w.String(typeDesc.name);
				END;
			ELSE
				w.String("NIL");
			END;
		ELSE
			w.String("UNKNOWN");
		END;
	END WriteType;

	(* Write the specified procedure name and returns parameters for use with Variables  *)
	PROCEDURE WriteProc0(w: Streams.Writer; mod: Modules.Module; pc, fp: ADDRESS;  VAR refs: Modules.Bytes; VAR refpos: LONGINT; VAR base: ADDRESS);
	VAR ch: CHAR; startpc, end: ADDRESS; offset: LONGINT;  name: Name;
	BEGIN
		refpos := -1;
		IF mod = NIL THEN
			IF pc = 0 THEN w.String("NIL")
			ELSE
				w.String("Unknown PC="); w.Address(pc); w.Char("H")
			END;
			IF fp # -1 THEN
				w.String(" FP="); w.Address(fp); w.Char("H")
			END
		ELSE
			w.String(mod.name);
			IF FindByAdr(mod.refs, refpos, pc) THEN
				refs := mod.refs;
				offset := refpos;
				IF GetChar(refs, offset) = sfProcedure THEN
					w.Char(".");
					SkipSize(offset);
					SkipString(refs, offset); 
					GetFullName(refs, refpos, name); 
					startpc := GetAddress(refs, offset);
					end := GetAddress(refs, offset); 
					w.String(name); 
					w.Char(":"); w.Int(LONGINT(pc-startpc),1);
					SkipType(refs, offset);
					base := fp; (*! only for local !! *)
					refpos := offset; 
				END;
			END;
			w.String(" pc="); w.Int(LONGINT(pc),1); w.String(" ["); w.Address (pc); w.String("H]");
			w.String(" = "); w.Int(LONGINT(startpc),1);  w.String(" + "); w.Int(LONGINT(pc-startpc),1);
			w.String(" crc="); w.Hex(mod.crc,-8);
			(*Wait(w);*)
		END
	END WriteProc0;
	
	PROCEDURE WriteBasicValue*(w: Streams.Writer; type: CHAR; adr: ADDRESS; VAR size: SIZE);
	VAR
		b: BOOLEAN;
		c: CHAR; c8: CHAR8; c16: CHAR16; c32: CHAR32;
		s: SHORTINT; i: INTEGER; l: LONGINT; h: HUGEINT;
		sz: SIZE; a: ADDRESS;
		word: WORD; lword: LONGWORD;
		s8: SIGNED8; s16: SIGNED16; s32: SIGNED32; s64: SIGNED64;
		u8: UNSIGNED8; u16: UNSIGNED16; u32: UNSIGNED32; u64: UNSIGNED64;
		r: REAL; x: LONGREAL;
		cplx: COMPLEX; lcplx: LONGCOMPLEX;
		set: SET;
		byte: SYSTEM.BYTE;

		PROCEDURE Signed(i: HUGEINT);
		BEGIN
			w.Int(i,1);
		END Signed;
		
		PROCEDURE Unsigned(i: HUGEINT; size: LONGINT);
		BEGIN
			w.Hex(i,-2*size);
		END Unsigned;
			
	BEGIN
		CASE type OF
		| sfTypePointerToRecord, sfTypeANY, sfTypeOBJECT:
			size := SIZEOF(ADDRESS);
			SYSTEM.GET(adr, a); Unsigned(a, SIZEOF(ADDRESS));
		| sfTypeBOOLEAN: 
			size := SIZEOF(BOOLEAN);
			SYSTEM.GET(adr, b); IF b THEN w.String("true") ELSE w.String("false") END; 
		| sfTypeCHAR, sfTypeCHAR8: 
			size := SIZEOF(CHAR);
			SYSTEM.GET(adr, c); IF (c > " ") & (c <= "~") THEN w.Char( c ); ELSE w.Hex( ORD( c ), -2 );  w.Char( "X" ) END;
		| sfTypeCHAR16:
			size := SIZEOF(CHAR16);
			SYSTEM.GET(adr, i); w.Hex(i,-4); w.Char("X");
		| sfTypeCHAR32:
			size := SIZEOF(CHAR32);
			SYSTEM.GET(adr, l); w.Hex(l,-8); w.Char("X");
		| sfTypeSHORTINT: 
			size := SIZEOF(SHORTINT);
			SYSTEM.GET(adr, s); Signed(s);
		| sfTypeINTEGER:  
			size := SIZEOF(INTEGER);
			SYSTEM.GET(adr, i); Signed(i);
		| sfTypeLONGINT: 
			size := SIZEOF(LONGINT);
			SYSTEM.GET(adr, l); Signed(l);
		| sfTypeHUGEINT: 
			size := SIZEOF(HUGEINT);
			SYSTEM.GET(adr, h); Signed(h);
		| sfTypeWORD: 
			size := SIZEOF(WORD);
			SYSTEM.GET(adr, word); Signed(word);
		| sfTypeLONGWORD: 
			size := SIZEOF(LONGWORD);
			SYSTEM.GET(adr, lword); Signed(lword);;
		| sfTypeSIGNED8:
			size := SIZEOF(SIGNED8);
			SYSTEM.GET(adr, s8); Signed(s8);
		| sfTypeSIGNED16:
			size := SIZEOF(SIGNED16);
			SYSTEM.GET(adr, s16); Signed(s16);
		| sfTypeSIGNED32:
			size := SIZEOF(SIGNED32);
			SYSTEM.GET(adr, s32); Signed(s32);		
		| sfTypeSIGNED64:
			size := SIZEOF(SIGNED64);
			SYSTEM.GET(adr, s64); Signed(s64);		
		| sfTypeUNSIGNED8:
			size := SIZEOF(UNSIGNED8); 
			SYSTEM.GET(adr, u8); Unsigned(u8, SIZEOF(UNSIGNED8));	
		| sfTypeUNSIGNED16:
			size := SIZEOF(UNSIGNED16); 
			SYSTEM.GET(adr, u16); Unsigned(u8, SIZEOF(UNSIGNED16));	
		| sfTypeUNSIGNED32:
			size := SIZEOF(UNSIGNED32); 
			SYSTEM.GET(adr, u32); Unsigned(u8, SIZEOF(UNSIGNED32));	
		| sfTypeUNSIGNED64:
			size := SIZEOF(UNSIGNED64); 
			SYSTEM.GET(adr, u64); Unsigned(u8, SIZEOF(UNSIGNED64));	
		| sfTypeREAL:
			size := SIZEOF(REAL);
			SYSTEM.GET(adr, r); w.Float(r,7);
		| sfTypeLONGREAL:
			size := SIZEOF(LONGREAL);
			SYSTEM.GET(adr, x); w.Float(x,13);
		| sfTypeCOMPLEX:
			size := SIZEOF(COMPLEX);
			SYSTEM.GET(adr, cplx); w.Float(RE(cplx),7); w.String("+ i*"); w.Float(IM(cplx),7);
		| sfTypeLONGCOMPLEX:
			size := SIZEOF(LONGCOMPLEX);
			SYSTEM.GET(adr, x); w.Float(x,13); SYSTEM.GET(adr + SIZEOF(LONGREAL), x); w.String("+ i*"); w.Float(x,13);
		| sfTypeSET:
			size := SIZEOF(SET);
			SYSTEM.GET(adr, set); w.Set(set);
		| sfTypeBYTE:
			size := SIZEOF(SYSTEM.BYTE);
			SYSTEM.GET(adr, c); Unsigned(ORD(c), 1);
		| sfTypeRANGE:
			size := SIZEOF(RANGE);
			SYSTEM.GET(adr, sz); Unsigned(sz,SIZEOF(SIZE)); w.String(".."); Unsigned(sz, SIZEOF(SIZE)); 
		| sfTypeADDRESS:
			size := SIZEOF(ADDRESS);
			SYSTEM.GET(adr, a); Unsigned(a, SIZEOF(ADDRESS));
		| sfTypeSIZE:
			size := SIZEOF(SIZE);
			SYSTEM.GET(adr, sz); Signed(sz); w.String("["); Unsigned(sz, SIZEOF(SIZE)); w.String("]");
		ELSE
			w.String("UNKOWN TYPE "); Unsigned(ORD(type),1);
		END;
		w.Update;
	END WriteBasicValue;
	
	PROCEDURE WriteValueString*(w: Streams.Writer; adr: ADDRESS; maxLen: LONGINT);
	CONST MaxString = 32; 
	VAR ch: CHAR;
	BEGIN
		IF maxLen > MaxString THEN maxLen := MaxString END; 
		w.Char('"');
		IF CheckHeapAddress(adr) THEN
			LOOP
				IF maxLen <= 0 THEN EXIT END;
				SYSTEM.GET(adr, ch);
				IF (ch < " ") OR (ch > "~") THEN EXIT END;
				w.Char(ch);
				INC(adr);
				DEC(maxLen);
			END;
		END;
		w.Char('"');
	END WriteValueString;

	PROCEDURE WriteValue*(w: Streams.Writer; refs: Modules.Bytes; VAR offset: LONGINT; adr: ADDRESS);
	VAR type: CHAR; a: ADDRESS; size: SIZE; len: SIZE;
	BEGIN
		type := GetChar(refs, offset);
		CASE type OF
			sfTypeNone:
		| sfTypePointerToRecord, sfTypeANY, sfTypeOBJECT:
			WriteBasicValue(w,type, adr, size);
			SYSTEM.GET(adr, a);
			IF CheckHeapAddress(a) THEN
				SYSTEM.GET(a + Heaps.TypeDescOffset, a);
				w.String(" (");
				WriteType(w,a);
				w.String(")");
			END;
		| sfTypePointerToArray: 
			WriteBasicValue(w, sfTypeANY, adr, size);
			w.String("->");
			SYSTEM.GET(adr, a);
			WriteValue(w,refs,offset, a);
			(*SkipType(refs, offset);*)
		| sfTypeOpenArray: 
			IF refs[offset] = sfTypeCHAR THEN (* ARRAY OF CHAR *)
				WriteValueString(w, adr, MaxString);
			END;
			SkipType(refs, offset);
		| sfTypeStaticArray: 
			len := GetSize(refs, offset); 
			IF refs[offset] = sfTypeCHAR THEN (* ARRAY x OF CHAR *)
				WriteValueString(w, adr, len);
			END;
			SkipType(refs, offset);
		| sfTypeDynamicArray: 
			w.String("...");
			SkipType(refs, offset); 
		| sfTypeMathOpenArray: 
			w.String("...");
			SkipType(refs, offset);
		| sfTypeMathStaticArray: 
			w.String("...");
			SkipSize(offset); SkipType(refs, offset);
		| sfTypeMathTensor: 
			w.String("...");
			SkipType(refs, offset); 
		| sfTypeRecord: 
			w.String("...");
			w.String("(");
			a := GetAddress(refs, offset); 
			WriteType(w,a);
			w.String(")");
		| sfTypeDelegate: 
			WHILE refs[offset] = sfParameter DO SkipParameter(refs, offset) END;
			SkipType(refs, offset); 
		ELSE
			WriteBasicValue(w, type, adr, size);
		END;
		w.Update;
	END WriteValue;
		
	PROCEDURE WriteVariable*(w: Streams.Writer; refs: Modules.Bytes; VAR offset: LONGINT;  base: ADDRESS);
	VAR name: ARRAY 128 OF CHAR;  adr: LONGINT;  prevScope: SIZE;
	BEGIN
		IF ~Expect(GetChar(refs, offset) = sfVariable) THEN RETURN END;
		prevScope := GetSize(refs, offset);
		GetString(refs, offset, name); 
		D.String(name); 
		w.String(Sep); w.String(name); w.Char("=");
		adr := GetSize(refs, offset);
		IF prevScope <0 THEN (* module scope *)
			base := 0
		END;
		WriteValue(w, refs, offset, adr+base); 
	END WriteVariable; 
	
	(* write variables taking meta information from stream in stream at offset, potentially stored at base address
	 *)
	PROCEDURE WriteVariables*(w: Streams.Writer; refs: Modules.Bytes; VAR offset: LONGINT; base: ADDRESS);
	VAR count: LONGINT; 
	BEGIN
		WHILE refs[offset] = sfVariable DO
			WriteVariable(w, refs, offset, base); 
			INC(count); 
		END; 
		IF count > 0 THEN w.Ln; Wait(w); END;
	END WriteVariables;

	(* skip type metadata in stream *)
	PROCEDURE SkipType*(refs: Modules.Bytes; VAR offset: LONGINT);
	VAR size: SIZE;  adr: LONGINT; c: CHAR;
	BEGIN
		c := GetChar(refs, offset);
		CASE c OF
			sfTypeNone .. sfTypeSIZE: 
		| sfTypePointerToRecord:
		| sfTypePointerToArray: SkipType(refs, offset);
		| sfTypeOpenArray: SkipType(refs, offset);
		| sfTypeStaticArray: SkipSize(offset); SkipType(refs, offset);
		| sfTypeDynamicArray: SkipType(refs, offset); 
		| sfTypeMathOpenArray: SkipType(refs, offset);
		| sfTypeMathStaticArray: SkipSize(offset); SkipType(refs, offset);
		| sfTypeMathTensor: SkipType(refs, offset); 
		| sfTypeRecord: SkipSize(offset);
		| sfTypeDelegate: 
			WHILE refs[offset] = sfParameter DO SkipParameter(refs, offset) END;
		ELSE (* ?? *)
		END;
	END SkipType;

	(* skip procedure metadata in stream *)
	PROCEDURE SkipProcedure*(refs: Modules.Bytes; VAR offset: LONGINT);
	BEGIN
		IF ~Expect(GetChar(refs, offset) = sfProcedure) THEN RETURN END; 	
		SkipSize(offset);
		SkipString(refs, offset);
		SkipAddress(offset);
		SkipAddress(offset);
		WHILE (refs[offset] = sfParameter)  DO	SkipParameter(refs, offset) END;
		SkipType(refs, offset); 
		SkipScope(refs, offset);
	END SkipProcedure;

	(* skip parameter meta data in stream *)
	PROCEDURE SkipParameter*(refs: Modules.Bytes; VAR offset: LONGINT);
	VAR name: ARRAY 128 OF CHAR;  adr: LONGINT; c: CHAR;
	BEGIN
		IF ~Expect(GetChar(refs, offset) = sfParameter) THEN RETURN END; 	
		SkipSize(offset);
		SkipString(refs, offset); 
		SkipSize(offset);
		SkipChar(offset);
		SkipType(refs, offset); 
	END SkipParameter; 

	(* skip variable metadata in stream *)
	PROCEDURE SkipVariable*(refs: Modules.Bytes; VAR offset: LONGINT);
	BEGIN
		IF ~Expect(GetChar(refs, offset) = sfVariable) THEN RETURN END;
		SkipSize(offset);
		SkipString(refs, offset); 
		SkipSize(offset);
		SkipType(refs, offset); 	
	END SkipVariable;

	(* skip type declaration meta data in stream *)
	PROCEDURE SkipTypeDeclaration*(refs: Modules.Bytes; VAR offset: LONGINT);
	BEGIN
		IF ~Expect(GetChar(refs, offset) = sfTypeDeclaration) THEN RETURN END;
		SkipSize(offset);
		SkipString(refs, offset); 
		SkipAddress(offset);
		IF refs[offset] = sfScopeBegin THEN SkipScope(refs, offset) END;	
	END SkipTypeDeclaration;
	
	(* skip a scope in stream *)
	PROCEDURE SkipScope*(refs: Modules.Bytes; VAR offset: LONGINT);
	BEGIN	
		IF ~Expect(GetChar(refs, offset) = sfScopeBegin) THEN RETURN END; 
		WHILE (refs[offset] = sfVariable)  DO SkipVariable(refs, offset) END;
		WHILE (refs[offset] = sfProcedure) DO SkipProcedure(refs, offset) END;
		WHILE (refs[offset] = sfTypeDeclaration)  DO SkipTypeDeclaration(refs, offset)	END;
		IF ~Expect(GetChar(refs, offset) = sfScopeEnd) THEN RETURN END;
	END SkipScope;

	TYPE 
	Search = RECORD
		name: ARRAY 256 OF CHAR; 	(* for search by name *)
		nameOffset: LONGINT;				(* to incrementally search through scopes *)
		minLevel: LONGINT; 					(* in order to stop scope search *)
		pc: ADDRESS;							(* for search by address *)
		pos: LONGINT;							(* symbol position in stream *)
		found: BOOLEAN;						(* if found *)
	END;

	(* check if stream contains the string part stored in search record with respective offset *)
	PROCEDURE FindString(refs: Modules.Bytes; VAR offset: LONGINT; level: LONGINT; VAR find: Search);
	VAR ofs: LONGINT;
	BEGIN
		ofs := find.nameOffset;
		WHILE (refs[offset] # 0X) & (find.name[ofs] = refs[offset]) DO
			INC(offset); INC(ofs);
		END;
		IF (refs[offset] = 0X) THEN
			IF find.name[ofs] = 0X THEN
				find.found := TRUE;
			ELSIF find.name[ofs] = "." THEN
				find.minLevel := level+1;
				find.nameOffset := ofs+1;
			END;
		END;
		WHILE(refs[offset] # 0X) DO INC(offset) END;
		INC(offset);
	END FindString;

	(* find a symbol by name or pc starting from the procedure stream section *)
	PROCEDURE FindInProcedure(refs: Modules.Bytes; VAR offset: LONGINT; level: LONGINT; VAR find: Search);
	VAR name: ARRAY 128 OF CHAR;  start, end, pos: LONGINT; 
	BEGIN
		pos := offset; 
		IF ~Expect(GetChar(refs, offset) = sfProcedure) THEN RETURN END; 	
		SkipSize(offset);
		FindString(refs, offset, level, find);
		start := GetAddress(refs, offset);
		end := GetAddress(refs, offset);
		find.found := find.found OR (start <= find.pc) & (find.pc <= end);
		IF find.found THEN
			find.pos := pos; 
			RETURN; 
		END;
		WHILE (refs[offset] = sfParameter) DO
			IF find.minLevel <= level THEN
				FindInParameter(refs, offset, level+1, find);
				IF find.found THEN RETURN END;
			ELSE
				SkipParameter(refs, offset)
			END;
		END;
		SkipType(refs, offset); 
		FindInScope(refs, offset, level+1, find);
	END FindInProcedure;

	(* find a symbol by name or pc starting from the parameter stream section *)
	PROCEDURE FindInParameter(refs: Modules.Bytes; VAR offset: LONGINT; level: LONGINT; VAR find: Search);
	VAR name: ARRAY 128 OF CHAR;  adr: LONGINT; c: CHAR; pos: LONGINT;
	BEGIN
		pos := offset;
		IF ~Expect(GetChar(refs, offset) = sfParameter) THEN RETURN END; 	
		SkipSize(offset);
		FindString(refs, offset, level, find); 
		IF find.found THEN 
			find.pos := pos; 
			RETURN;
		END;
		SkipSize(offset);
		SkipChar(offset); 
		SkipType(refs, offset); 
	END FindInParameter; 

	(* find a symbol by name or pc starting from the variable stream section *)
	PROCEDURE FindInVariable(refs: Modules.Bytes; VAR offset: LONGINT; level: LONGINT; VAR find: Search);
	VAR name: ARRAY 128 OF CHAR;  pos: LONGINT; 
	BEGIN
		pos := offset; 
		IF ~Expect(GetChar(refs, offset) = sfVariable) THEN RETURN END;  	
		SkipSize(offset);
		FindString(refs, offset, level, find); 
		IF find.found THEN
			find.pos := pos; 
			RETURN;
		END; 
		SkipSize(offset);
		SkipType(refs, offset); 
	END FindInVariable; 

	(* find a symbol by name or pc starting from the type declaration stream section *)
	PROCEDURE FindInTypeDeclaration(refs: Modules.Bytes; VAR offset: LONGINT; level: LONGINT; VAR find: Search);
	VAR name: ARRAY 128 OF CHAR;  adr, pos: LONGINT; 
	BEGIN
		pos := offset;
		IF ~Expect(GetChar(refs, offset) = sfTypeDeclaration) THEN RETURN END;
		SkipSize(offset);
		FindString(refs, offset, level, find); 
		IF find.found THEN 
			find.pos := pos;
			RETURN;
		END;
		SkipAddress(offset);
		IF refs[offset] = sfScopeBegin THEN FindInScope(refs, offset, level+1, find) END;
	END FindInTypeDeclaration; 

	(* find a symbol by name or pc in a scope in the stream *)
	PROCEDURE FindInScope(refs: Modules.Bytes; VAR offset: LONGINT; level: LONGINT; VAR find: Search);
	VAR no,i: LONGINT;
	BEGIN
		IF ~Expect(GetChar(refs, offset) = sfScopeBegin) THEN RETURN END;
		WHILE ~find.found &(refs[offset] = sfVariable) &  (find.minLevel <= level) DO (* Variable *)
			FindInVariable(refs, offset, level, find); 
		END;
		WHILE ~find.found & (refs[offset] = sfProcedure)  & (find.minLevel <= level) DO (* Procedure *)
			FindInProcedure(refs, offset, level, find);
		END;
		WHILE ~find.found & (refs[offset] = sfTypeDeclaration) & (find.minLevel <= level) DO (* TypeDeclaration *)
			FindInTypeDeclaration(refs, offset,level, find); 
		END;
		IF find.found OR (find.minLevel > level) THEN RETURN END;
		IF ~Expect(GetChar(refs, offset) = sfScopeEnd) THEN RETURN END;
	END FindInScope;
	
	PROCEDURE InitSearch(VAR search: Search);
	BEGIN
		search.found := FALSE;
		search.name := "";
		search.minLevel := 0;
		search.pc := 0;
	END InitSearch;
	
	PROCEDURE FindByName*(refs: Modules.Bytes; VAR offset: LONGINT; CONST name: ARRAY OF CHAR): BOOLEAN; 
	VAR search: Search; 
	BEGIN
		InitSearch(search); 
		COPY(name, search.name);
		IF ~Expect(GetChar(refs, offset) = 0FFX) THEN RETURN FALSE END;
		FindInScope(refs, offset, 0, search);
		offset := search.pos;
		RETURN search.found;	
	END FindByName;

	PROCEDURE FindByAdr*(refs: Modules.Bytes; VAR offset: LONGINT; pc: ADDRESS): BOOLEAN;
	VAR search: Search;
	BEGIN
		InitSearch(search);
		search.pc := pc;
		IF GetChar(refs, offset) # 0FFX THEN RETURN FALSE END; 
		FindInScope(refs, offset, 0, search);
		offset := search.pos;
		RETURN search.found; 
	END FindByAdr;

	(** service procedures *) 
	
	(** Find procedure name and write it. *)
	PROCEDURE WriteProc*(w: Streams.Writer; pc: ADDRESS);
	VAR refs: Modules.Bytes; refpos: LONGINT; base: ADDRESS;
	BEGIN
		WriteProc0(w, Modules.ThisModuleByAdr0(pc), pc, -1, refs, refpos, base)
	END WriteProc;
	
	(** Write the state of the specified module. *)
	PROCEDURE ModuleState*(w: Streams.Writer; mod: Modules.Module);
	VAR offset: LONGINT; base: ADDRESS; refs: Modules.Bytes;
	BEGIN
		IF mod = NIL THEN RETURN END;
		refs := mod.refs;
		offset := 0; 
		
		w.String("State "); w.String(mod.name); w.Char(":"); w.Ln; Wait(w);
		IF (GetChar(refs, offset) = 0FFX) &  (GetChar(refs, offset) = sfScopeBegin) THEN
			WriteVariables(w, refs, offset, 0)
		END;
	END ModuleState;

	(* Display call trackback. *)
	PROCEDURE StackTraceBack*(w: Streams.Writer; pc, bp: ADDRESS; stackhigh: ADDRESS; long, overflow: BOOLEAN);
	VAR count,offset: LONGINT; stacklow: ADDRESS; base: ADDRESS; m: Modules.Module; refs: Modules.Bytes;
	BEGIN
		count := 0;	(* frame count *)
		stacklow := bp;
		REPEAT
			m := Modules.ThisModuleByAdr0(pc);
			IF (ShowAllProcs OR (m # NIL) OR (count = 0)) & (bp # 0) & (bp >= stacklow) & (bp <= stackhigh) THEN
				IF CheckHeapAddress( pc ) THEN
					WriteProc0(w, m, pc, bp, refs, offset, base); w.Ln;Wait(w); w.Update;
					IF long & (~overflow OR (count > 0)) THEN	(* show variables *)
						IF offset >= 0 THEN 
							IF Expect(GetChar(refs, offset) = sfScopeBegin) THEN
								WriteVariables(w,refs,offset, base); 
							END;
						END;
						IF (m # NIL) & (base # m.sb) & (count = 0) THEN ModuleState(w, m) END
					END;
				ELSE
					w.String( "Unknown external procedure, pc = " );  w.Address( pc );  w.Ln; Wait(w);
				END;
				SYSTEM.GET(bp + SIZEOF(ADDRESS), pc);	(* return addr from stack *)
				SYSTEM.GET(bp, bp);	(* follow dynamic link *)
				INC(count)
			ELSE
				bp := 0
			END;
		UNTIL (bp = 0) OR (count = MaxFrames);
		IF bp # 0 THEN w.String("...") END
	END StackTraceBack;

	(** Write a process's state in one line. *)
	PROCEDURE WriteProcess*(w: Streams.Writer; p: Objects.Process);
	VAR adr: ADDRESS; mode: LONGINT; m: Modules.Module;
	BEGIN
		IF p # NIL THEN
			w.Int(p.id, 5);
			mode := p.mode;
			IF (mode >= Objects.Ready) & (mode <= Objects.Terminated) THEN
				adr := (mode-Objects.Ready)*4;
				FOR adr := adr TO adr+3 DO w.Char(modes[adr]) END
			ELSE
				w.Char(" "); w.Int(mode, 1)
			END;
			w.Int(p.procID, 2);
			w.Int(p.priority, 2);
			w.Update;
			w.Address (SYSTEM.VAL(ADDRESS, p.obj));
			IF p.obj # NIL THEN
				SYSTEM.GET(SYSTEM.VAL(ADDRESS, p.obj) - SIZEOF(ADDRESS), adr);
				w.Char(":"); WriteType(w, adr)
			END;
			w.Update;
			w.Char(" "); WriteProc(w, p.state.PC);
			IF p.mode = Objects.AwaitingLock THEN
				adr := SYSTEM.VAL(ADDRESS, p.waitingOn);
				w.Address (adr);
				w.Update;
				IF adr # 0 THEN	(* can be 0 when snapshot is taken *)
					SYSTEM.GET(adr - SIZEOF(ADDRESS), adr);
					IF adr = SYSTEM.TYPECODE(Modules.Module) THEN
						w.Char("-");
						m := SYSTEM.VAL(Modules.Module, adr);
						w.String(m.name)
					ELSE
						w.Char(":"); WriteType(w, adr)
					END;
					w.Update;
				END
			ELSIF p.mode = Objects.AwaitingCond THEN
				w.Char(" "); WriteProc(w, SYSTEM.VAL(ADDRESS, p.condition));
				w.Address (p.condFP)
			END;
			w.Char(" "); w.Set(p.flags)
		END
	END WriteProcess;

	(** ---------------- TESTING ----------------- *)
	
	PROCEDURE TraceBackThis( eip, ebp: ADDRESS; stackhigh:LONGINT );   (* do a stack trace back w.r.t. given instruction and frame pointers *)
	VAR Log: Streams.Writer;
	BEGIN
		Log := Commands.GetContext().out;
		Log.Ln;  Log.String( "#######################" );
		Log.Ln;  Log.String( "# Debugging.TraceBack #" );
		Log.Ln;  Log.String( "#######################" );
		Log.Ln;  StackTraceBack( Log, eip, ebp, stackhigh, TRUE , FALSE );
		Log.Update;
	END TraceBackThis;

	PROCEDURE TraceBack*;   (* do a stack trace back starting at the calling instruction position *)
	BEGIN
		TraceBackThis( Machine.CurrentPC(), Machine.CurrentBP(), Objects.GetStackBottom(Objects.CurrentProcess()) );
	END TraceBack;

	PROCEDURE ReportType(refs: Modules.Bytes; VAR offset: LONGINT);
	VAR size: SIZE;  adr: LONGINT; c: CHAR;
	BEGIN
		c := GetChar(refs, offset);
		CASE c OF
			sfTypeNone: D.String("no type");
		| sfTypePointerToRecord: D.String("POINTER TO RECORD");
		| sfTypePointerToArray: D.String("POINTER TO "); ReportType(refs, offset);
		| sfTypeOpenArray: D.String("ARRAY OF "); ReportType(refs, offset);
		| sfTypeStaticArray: D.String("ARRAY "); D.Int(GetSize(refs, offset),1 ); D.String(" OF "); ReportType(refs, offset);
		| sfTypeDynamicArray: D.String("DARRAY OF "); ReportType(refs, offset); 
		| sfTypeMathOpenArray: D.String("ARRAY [*] OF "); ReportType(refs, offset);
		| sfTypeMathStaticArray: D.String("ARRAY ["); D.Int(GetSize(refs, offset),1); D.String("] OF "); ReportType(refs, offset);
		| sfTypeMathTensor: D.String("ARRAY [?] OF "); ReportType(refs, offset); 
		| sfTypeRecord: D.String("RECORD ");  D.Address(GetAddress(refs, offset)); 
		| sfTypeDelegate: 
			D.String("PROCEDURE ("); 	
			WHILE refs[offset] = sfParameter DO ReportParameter(refs, offset) END;
			D.String("):"); ReportType(refs, offset); 
		| sfTypeBOOLEAN: D.String("BOOLEAN"); 
		| sfTypeCHAR: D.String("CHAR"); 
		| sfTypeCHAR8: D.String("CHAR8"); 
		| sfTypeCHAR16: D.String("CHAR16"); 
		| sfTypeCHAR32: D.String("CHAR32"); 
		| sfTypeSHORTINT: D.String("SHORTINT"); 
		| sfTypeINTEGER: D.String("INTEGER"); 
		| sfTypeLONGINT: D.String("LONGINT"); 
		| sfTypeHUGEINT: D.String("HUGEINT"); 
		| sfTypeWORD: D.String("WORD"); 
		| sfTypeLONGWORD: D.String("LONGWORD"); 
		| sfTypeSIGNED8: D.String("SIGNED8"); 
		| sfTypeSIGNED16: D.String("SIGNED16"); 
		| sfTypeSIGNED32: D.String("SIGNED32"); 
		| sfTypeSIGNED64: D.String("SIGNED64"); 
		| sfTypeUNSIGNED8: D.String("UNSIGNED8"); 
		| sfTypeUNSIGNED16: D.String("UNSIGNED16"); 
		| sfTypeUNSIGNED32: D.String("UNSIGNED32"); 
		| sfTypeUNSIGNED64: D.String("UNSIGNED64"); 
		| sfTypeREAL: D.String("REAL"); 
		| sfTypeLONGREAL: D.String("LONGREAL"); 
		| sfTypeCOMPLEX: D.String("COMPLEX"); 
		| sfTypeLONGCOMPLEX: D.String("LONGCOMPLEX"); 
		| sfTypeSET: D.String("SET"); 
		| sfTypeANY: D.String("ANY"); 
		| sfTypeOBJECT: D.String("OBJECT"); 
		| sfTypeBYTE: D.String("BYTE"); 
		| sfTypeRANGE: D.String("RANGE"); 
		| sfTypeADDRESS: D.String("ADDRESS"); 
		| sfTypeSIZE: D.String("SIZE"); 
		ELSE D.String("????? TYPE ?????");
		END;
	END ReportType;

	PROCEDURE ReportProcedure(refs: Modules.Bytes; VAR offset: LONGINT);
	VAR name: Name;  start, end: LONGINT; 
	BEGIN
		D.String("PROCEDURE "); 
		IF ~Expect(GetChar(refs, offset) = sfProcedure) THEN RETURN END;
		SkipSize(offset);
		GetString(refs, offset, name); 
		D.String(name); 
		start := GetAddress(refs, offset);
		end := GetAddress(refs, offset);
		D.String("("); 
		WHILE refs[offset] = sfParameter DO
			ReportParameter(refs, offset);
		END;
		D.String(")"); 
		D.String(":"); 
		ReportType(refs, offset); 
		D.String("[@"); D.Address(start); D.String(" - "); D.Address(end); D.String("]");
		D.Ln;
		ReportScope(refs, offset);
	END ReportProcedure;

	PROCEDURE ReportParameter(refs: Modules.Bytes; VAR offset: LONGINT);
	VAR name: ARRAY 128 OF CHAR;  adr: LONGINT; c: CHAR;
	BEGIN
		D.String(" "); 
		IF ~Expect(GetChar(refs, offset) = sfParameter) THEN RETURN END; 	
		SkipSize(offset);
		GetString(refs, offset, name); 
		D.String(name); 
		adr := GetSize(refs, offset);
		c := GetChar(refs, offset); 	
		IF c = sfVarPar THEN
			D.String(" VAR ")
		ELSIF c = sfConstPar THEN
			D.String(" CONST ")
		ELSIF Expect(c = sfValPar) THEN
		END;

		D.String(":"); 
		ReportType(refs, offset); 
		D.String("[@"); D.Int(adr,1); D.String("]"); 
		
		D.String("; "); 
	END ReportParameter; 

	PROCEDURE ReportVariable(refs: Modules.Bytes; VAR offset: LONGINT);
	VAR name: ARRAY 128 OF CHAR;  adr: LONGINT; 
	BEGIN
		D.String("VAR "); 
		IF ~Expect(GetChar(refs, offset) = sfVariable) THEN RETURN END;
		SkipSize(offset);
		GetString(refs, offset, name); 
		D.String(name); 
		adr := GetSize(refs, offset);
		D.String(":"); 
		ReportType(refs, offset); 
		D.String("[@"); D.Int(offset,1); D.String("]");
		D.Ln;
	END ReportVariable; 

	PROCEDURE ReportTypeDeclaration(refs: Modules.Bytes; VAR offset: LONGINT);
	VAR name: ARRAY 128 OF CHAR;  adr: LONGINT; 
	BEGIN
		D.String("TYPE "); 
		IF ~Expect(GetChar(refs, offset) = sfTypeDeclaration) THEN RETURN END; 	
		SkipSize(offset);
		GetString(refs, offset, name); 
		D.String(name); 
		adr := GetAddress(refs, offset);
		D.String(" "); 
		D.Address(adr); 
		D.Ln;
		IF refs[offset] = sfScopeBegin THEN ReportScope(refs, offset) END;
	END ReportTypeDeclaration; 

	PROCEDURE ReportScope(refs: Modules.Bytes; VAR offset: LONGINT);
	BEGIN
		IF ~Expect(GetChar(refs, offset) = sfScopeBegin) THEN RETURN END; 
		WHILE (refs[offset] = sfVariable) DO (* Variable *)
			ReportVariable(refs, offset); 
		END;
		WHILE (refs[offset] = sfProcedure) DO (* Procedure *)
			ReportProcedure(refs, offset);
		END;
		WHILE (refs[offset] = sfTypeDeclaration) DO (* TypeDeclaration *)
			ReportTypeDeclaration(refs, offset); 
		END;
		IF ~Expect(GetChar(refs, offset) = sfScopeEnd) THEN RETURN END;
		D.String("END"); D.Ln; 
	END ReportScope;
					
	PROCEDURE Report(refs: Modules.Bytes);
	VAR offset: LONGINT; 
	BEGIN
		offset := 0; 
		IF Expect(GetChar(refs, offset) = 0FFX) THEN
			ReportScope(refs, offset)
		END;
	END Report;


	PROCEDURE Test*;
	VAR msg: ARRAY 128 OF CHAR; res: LONGINT; m: Modules.Module; offset,i : LONGINT;
	BEGIN
		m := Modules.ThisModule("TestReflection", res, msg);
		Report(m.refs);
		FOR i := 0 TO LEN(m.typeInfo)-1  DO
			TRACE(m.typeInfo[i].name, m.typeInfo[i].refsOffset);
			IF m.typeInfo[i].refsOffset # 0 THEN
				offset := m.typeInfo[i].refsOffset;
				ReportTypeDeclaration(m.refs,offset);
			END;
		END;
		D.String(" ----------- FIND ------------"); D.Ln;
		IF FindByName(m.refs, offset, "TestObject") THEN
			CASE m.refs[offset] OF
			sfProcedure: ReportProcedure(m.refs, offset)
			|sfVariable: ReportVariable(m.refs, offset)
			|sfTypeDeclaration: ReportTypeDeclaration(m.refs, offset)
			|sfParameter: ReportParameter(m.refs, offset); 
			END;
		END;
	END Test;

	PROCEDURE TraceThis*(pc, fp: ADDRESS);
	VAR module: Modules.Module; refs: Modules.Bytes; offset: LONGINT; base: ADDRESS;
		context: Commands.Context; 
		w: Streams.Writer; 
	BEGIN
		context := Commands.GetContext();
		w := context.out; 
		WriteProc0(w, Modules.ThisModuleByAdr0(pc), pc, fp, refs, offset, base);
		w.Ln;Wait(w); w.Update;
		IF offset # -1 THEN 
			IF Expect(GetChar(refs, offset) = sfScopeBegin) THEN 
				WriteVariables(w, refs, offset, base);
			END;
		END;
		(*
		IF (m # NIL) & (base # m.sb) & (count = 0) THEN ModuleState(w, m) END
		*)
	END TraceThis;


	TYPE TestObject = OBJECT
	VAR a,b,c: LONGINT;
		PROCEDURE OP;
		VAR opa: LONGINT; 
		VAR o: OBJECT PROCEDURE TestMe(x: LONGINT); BEGIN END TestMe; END;
		BEGIN
			
		END OP;
		
	END TestObject;

	TYPE MyRecord = RECORD END; 
	
	VAR gx, gy: LONGINT; 
	
	PROCEDURE TrapMe*;
	
		PROCEDURE P; 
		VAR i, j, k : LONGINT; b: ARRAY 32 OF CHAR;
			a: ANY; x: MyRecord;
		BEGIN
			a := Modules.root;
			i := 11; j := 1234; k := 2222;
			b := "Felix";
			TraceThis(Machine.CurrentPC(), Machine.CurrentBP());
		END P;
	 
	BEGIN
		P();
		ModuleState(Commands.GetContext().out, SYSTEM.VAL(Modules.Module, SELF));
		TraceBack;
	END TrapMe;



BEGIN
	modes := " rdy run awl awc awe rip";   (* 4 characters per mode from Objects.Ready to Objects.Terminated *)
END TestReflection.

SystemTools.Free TestReflection ~

TestReflection.TrapMe ~
TestReflection.Test
TestReflection.Trace 09454F69H ~

SystemTools.FreeDownTo FoxIntermediateBackend ~
