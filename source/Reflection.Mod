MODULE Reflection;
(** (c) Felix Friedrich, ETH Zurich, 2016 -- Reflection with more structured references section emitted by Fox Compiler *)

IMPORT Modules, Streams, SYSTEM, Machine, Heaps, Objects, Trace, Kernel;

CONST
	ShowAllProcs = TRUE;
	MaxFrames = 128;
	MaxString = 64;
	Sep = "  ";
	LineDelay = 0;

CONST
	sfTypeNone* = 0X;
	sfTypeCHAR* = 01X;
	sfTypeRANGE* = 05X;
	sfTypeSHORTINT* = 06X;
	sfTypeINTEGER* = 07X;
	sfTypeLONGINT* = 08X;
	sfTypeHUGEINT* = 09X;
	sfTypeWORD* = 0AX;
	sfTypeLONGWORD* = 0BX;
	sfTypeSIGNED8* = 0CX;
	sfTypeSIGNED16* = 0DX;
	sfTypeSIGNED32* = 0EX;
	sfTypeSIGNED64* = 0FX;
	sfTypeUNSIGNED8* = 10X;
	sfTypeUNSIGNED16* = 11X;
	sfTypeUNSIGNED32* = 12X;
	sfTypeUNSIGNED64* = 13X;
	sfTypeREAL* = 14X;
	sfTypeLONGREAL* = 15X;
	sfTypeCOMPLEX* = 16X;
	sfTypeLONGCOMPLEX* = 17X;
	sfTypeBOOLEAN* = 18X;
	sfTypeSET* = 19X;
	sfTypeANY* = 1AX;
	sfTypeOBJECT* = 1BX;
	sfTypeBYTE* = 1CX;
	sfTypeADDRESS* = 1DX;
	sfTypeSIZE* = 1EX;
	sfTypeIndirect*= 1FX;

	sfTypeRecord* = 20X;

	sfTypePointerToRecord* = 21X;
	sfTypePointerToArray* = 22X;
	sfTypeOpenArray* = 23X;
	sfTypeStaticArray* = 24X;
	sfTypeDynamicArray* = 25X;
	sfTypeMathStaticArray* = 26X;
	sfTypeMathOpenArray* = 27X;
	sfTypeMathTensor* = 28X;
	sfTypeProcedure* = 29X;
	sfTypeDelegate* = 2AX;
	sfTypeENUM* = 2BX;
	sfTypeCELL* = 2CX;
	sfTypePORT* = 2DX;


	sfIN* = 0X;
	sfOUT* = 1X;

	flagDelegate*=0;
	flagConstructor*=1;

	(* variable / parameter addressing modes *)
	sfAbsolute* = 0X; (* global vars *)
	sfRelative* = 1X; (* variables, value parameters *)
	sfIndirect* = 2X; (* var parameters *)

	sfScopeBegin* = 0F0X;
	sfScopeEnd* = 0F1X;
	sfProcedure* = 0F2X;
	sfVariable* = 	0F3X;
	sfTypeDeclaration* = 0F4X;
	sfModule*= 0FFX;

	(*
		References section format:
		Scope = sfScopeBegin {variable:Variable} {procedure:Procedure} {typeDecl:TypeDeclaration} sfScopeEnd.
		Module = sfModule prevSymbolOffset:SIZE name:String Scope.
		Procedure = sfProcedure prevSymbolOffset:SIZE name:String start:ADR end:ADR flags:SET {parameter:Variable} returnType:Type Scope.
		Variable = sfVariable prevSymbolOffset:SIZE name:String (sfRelative offset: SIZE | sfIndirec offset: SIZE | sfAbsolute address:ADDRESS) type:Type.
		TypeDeclaration = sfTypeDeclaration prevSymbolOffset:SIZE name:String typeInfo:ADR Scope.
		Type =
			sfTypePointerToRecord
			| sfTypePointerToArray Type
			| sfTypeOpenArray Type
			| sfTypeDynamicArray Type
			| sfTypeStaticArray length:SIZE Type
			| sfTypeMathOpenArray Type
			| sfTypeMathStaticArray length:SIZE Type
			| sfTypeMathTensor Type
			| sfTypeRecord tdAdr:ADDRESS
			| sfTypeProcedure {Parameter} return:Type
			| sfTypeDelegate {Parameter} return:Type
			| sfTypePort (sfIN | sfOUT)
			| sfTypeBOOLEAN
			| sfTypeCHAR
			| sfTypeSHORTINT | sfTypeINTEGER | sfTypeLONGINT | sfTypeHUGEINT
			| sfTypeSIGNED8 | sfTypeSIGNED16 | sfTypeSIGNED32 | sfTypeSIGNED64
			| sfTypeUNSIGNED8 | sfTypeUNSIGNED16 | sfTypeUNSIGNED32 | sfTypeUNSIGNED64
			| sfTypeWORD | sfTypeLONGWORD
			| sfTypeREAL | sfTypeLONGREAL
			| sfTypeCOMPLEX | sfTypeLONGCOMPLEX
			| sfTypeSET | sfTypeANY | sfTypeOBJECT | sfTypeBYTE | sfTypeADDRESS | sfTypeSIZE
			| sfTypeIndirect offset:SIZE.
	*)


	VAR
		modes: ARRAY 25 OF CHAR;

	TYPE
		Name = ARRAY 256 OF CHAR;

		Meta* = RECORD
			module-: Modules.Module;
			refs-: Modules.Bytes;
			offset*: SIZE;
		END;

	PROCEDURE CheckHeapAddress(address: ADDRESS): BOOLEAN;
	BEGIN
		RETURN Machine.ValidHeapAddress(address);
	END CheckHeapAddress;

	PROCEDURE Wait(w: Streams.Writer);
	VAR i: INTEGER;
	BEGIN
		IF LineDelay > 0 THEN
			FOR i := 0 TO LineDelay DO END;
			w.Update
		END;
	END Wait;

	PROCEDURE Expect(pos: SIZE; b: BOOLEAN): BOOLEAN;
	BEGIN
		IF ~b THEN Trace.String("Format error in references section @"); Trace.Int(pos,1); Trace.Ln END;
		RETURN b;
	END Expect;


	(* consume a char from the byte stream *)
	PROCEDURE GetChar*(refs: Modules.Bytes; VAR offset: SIZE): CHAR;
	VAR c: CHAR;
	BEGIN
		IF ~Expect(offset, offset < LEN(refs)) THEN RETURN 0X END;
		c := refs[offset];
		INC(offset);
		RETURN c;
	END GetChar;

	(* skip a char in the byte stream *)
	PROCEDURE SkipChar*(VAR offset: SIZE);
	BEGIN
		INC(offset, SIZEOF(CHAR));
	END SkipChar;

	(* consume an address in the byte stream *)
	PROCEDURE GetAddress*(refs: Modules.Bytes; VAR offset: SIZE): ADDRESS;
	VAR adr: ADDRESS; i: SIZE;
	BEGIN
		IF ~Expect(offset, offset < LEN(refs)) THEN RETURN 0 END;
		FOR i := 0 TO SIZEOF(ADDRESS)-1 DO
			SYSTEM.PUT8(ADDRESSOF(adr)+i, GetChar(refs, offset));
		END;
		RETURN adr;
	END GetAddress;

	(* skip an address in the byte stream *)
	PROCEDURE SkipAddress*(VAR offset: SIZE);
	BEGIN
		INC(offset, SIZEOF(ADDRESS));
	END SkipAddress;

	(* consume a size in the byte stream *)
	PROCEDURE GetSize*(refs: Modules.Bytes; VAR offset: SIZE): SIZE;
	VAR size: SIZE; i: SIZE;
	BEGIN
		IF ~Expect(offset, offset < LEN(refs)) THEN RETURN 0 END;
		FOR i := 0 TO SIZEOF(SIZE)-1 DO
			SYSTEM.PUT8(ADDRESSOF(size)+i, refs[offset]);
			INC(offset);
		END;
		RETURN size;
	END GetSize;

	(* skip a size in the byte stream *)
	PROCEDURE SkipSize*(VAR offset: SIZE);
	BEGIN
		INC(offset, SIZEOF(SIZE));
	END SkipSize;

	(* consume a set in the byte stream *)
	PROCEDURE GetSet*(refs: Modules.Bytes; VAR offset: SIZE): SET;
	VAR set: SET; i: SIZE;
	BEGIN
		IF ~Expect(offset, offset < LEN(refs)) THEN RETURN {} END;
		FOR i := 0 TO SIZEOF(SET)-1 DO
			SYSTEM.PUT8(ADDRESSOF(set)+i, refs[offset]);
			INC(offset);
		END;
		RETURN set;
	END GetSet;

	(* skip a set in the byte stream *)
	PROCEDURE SkipSet*(VAR offset: SIZE);
	BEGIN
		INC(offset, SIZEOF(SET));
	END SkipSet;

	(* consume a string in the byte stream *)
	PROCEDURE GetString*(refs: Modules.Bytes; VAR offset: SIZE; VAR string: ARRAY OF CHAR);
	VAR ch: CHAR; i: SIZE;
	BEGIN
		i := 0;
		REPEAT
			ch := GetChar(refs, offset);
			string[i] := ch;
			INC(i);
		UNTIL ch = 0X;
	END GetString;

	(* skip a string in the byte stream *)
	PROCEDURE SkipString*(refs: Modules.Bytes; VAR offset: SIZE);
	BEGIN
		WHILE(refs[offset] # 0X) DO INC(offset) END; INC(offset);
	END SkipString;

	(* extract a full name from the byte stream by traversing up the symbols in their scopes *)
	PROCEDURE GetFullName*(refs: Modules.Bytes; offset: SIZE; VAR name: ARRAY OF CHAR);
	VAR n: SIZE;

		PROCEDURE Traverse(offset: SIZE);
		VAR c: CHAR;
		BEGIN
			IF offset >= 0 THEN
				c := GetChar(refs, offset);
				IF (c = sfProcedure) OR (c=sfVariable) OR (c=sfTypeDeclaration) OR (c=sfModule) THEN
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
	#IF COOP THEN
		w.String("UNDETERMINED");
	#ELSE
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
	#END
	END WriteType;

	(* Write the specified procedure name and returns parameters for use with Variables  *)
	PROCEDURE WriteProc0(w: Streams.Writer; mod: Modules.Module; pc, fp: ADDRESS;  VAR refs: Modules.Bytes; VAR refpos: SIZE; VAR base: ADDRESS);
	VAR startpc, end: ADDRESS; offset: SIZE;  name: Name;
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
			refs := mod.refs;
			refpos := FindByAdr(refs, 0, pc);
			IF refpos >= 0 THEN
				offset := refpos;
				IF GetChar(refs, offset) = sfProcedure THEN
					SkipSize(offset);
					SkipString(refs, offset);
					GetFullName(refs, refpos, name);
					startpc := GetAddress(refs, offset);
					end := GetAddress(refs, offset);
					SkipSet(offset);
					w.String(name);
					w.Char(":"); w.Int(pc-startpc,1);
					base := fp; (*! only for local !! *)
					refpos := offset;
				END;
			ELSE
				w.String("procedure not found in module "); w.String(mod.name);
			END;
			w.String(" pc="); w.Address (pc);
			w.String(" fp="); w.Address (fp);
			w.String(" crc="); w.Hex(mod.crc,-8);
			(*Wait(w);*)
		END
	END WriteProc0;

	PROCEDURE WriteBasicValue*(w: Streams.Writer; type: CHAR; adr: ADDRESS; VAR size: SIZE);
	VAR
		b: BOOLEAN;
		c: CHAR;
		s: SIGNED8; i: SIGNED16; l: SIGNED32; h: SIGNED64;
		sz: SIZE; a, pc: ADDRESS;
		word: INTEGER; lword: LONGINTEGER;
		s8: SIGNED8; s16: SIGNED16; s32: SIGNED32; s64: SIGNED64;
		u8: UNSIGNED8; u16: UNSIGNED16; u32: UNSIGNED32;
		r: FLOAT32; x: FLOAT64;
		cplx {UNTRACED}: POINTER {UNSAFE} TO RECORD re,im: FLOAT32 END;
		lcplx {UNTRACED}: POINTER {UNSAFE} TO RECORD re,im: FLOAT64 END;
		set: SET;
		procedure: ARRAY 256 OF CHAR;

		PROCEDURE Signed(i: SIGNED64);
		BEGIN
			w.Int(i,1);
		END Signed;

		PROCEDURE Unsigned(i: SIGNED64; size: SIZE);
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
		| sfTypeCHAR:
			size := SIZEOF(CHAR);
			SYSTEM.GET(adr, c); IF (c > " ") & (c <= "~") THEN w.Char( c ); ELSE w.Hex( ORD( c ), -2 );  w.Char( "X" ) END;
		| sfTypeSHORTINT:
			size := SIZEOF(SIGNED8);
			SYSTEM.GET(adr, s); Signed(s);
		| sfTypeINTEGER:
			size := SIZEOF(SIGNED16);
			SYSTEM.GET(adr, i); Signed(i);
		| sfTypeLONGINT:
			size := SIZEOF(SIGNED32);
			SYSTEM.GET(adr, l); Signed(l);
		| sfTypeHUGEINT:
			size := SIZEOF(SIGNED64);
			SYSTEM.GET(adr, h); Signed(h);
		| sfTypeWORD:
			size := SIZEOF(INTEGER);
			SYSTEM.GET(adr, word); Signed(word);
		| sfTypeLONGWORD:
			size := SIZEOF(LONGINTEGER);
			SYSTEM.GET(adr, lword); Signed(lword);
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
			SYSTEM.GET(adr, u16); Unsigned(u16, SIZEOF(UNSIGNED16));
		| sfTypeUNSIGNED32:
			size := SIZEOF(UNSIGNED32);
			SYSTEM.GET(adr, u32); Unsigned(u32, SIZEOF(UNSIGNED32));
		| sfTypeUNSIGNED64:
			size := SIZEOF(UNSIGNED64);
			SYSTEM.GET(adr, s64); Unsigned(s64, SIZEOF(UNSIGNED64));
		| sfTypeREAL:
			size := SIZEOF(FLOAT32);
			SYSTEM.GET(adr, r); w.Float(r,12);
			w.String(" (");
			SYSTEM.GET(adr, u32); Unsigned(u32, SIZEOF(UNSIGNED32));
			w.String(")");
		| sfTypeLONGREAL:
			size := SIZEOF(FLOAT64);
			SYSTEM.GET(adr, x); w.Float(x,13);
			w.String(" (");
			SYSTEM.GET(adr, s64); Unsigned(s64, SIZEOF(UNSIGNED64));
			w.String(")");
		| sfTypeCOMPLEX:
			size := SIZEOF(COMPLEX32);
			cplx := adr; w.Float(cplx.re,12); w.String("+ i*"); w.Float(cplx.im,12);
		| sfTypeLONGCOMPLEX:
			size := SIZEOF(COMPLEX64);
			lcplx := adr;
			w.Float(lcplx.re,13); w.String("+ i*"); w.Float(lcplx.im,13);
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
			SYSTEM.GET(adr, sz); Signed(sz); IF (sz < -16) OR (sz > 16) THEN w.String("["); Unsigned(sz, SIZEOF(SIZE)); w.String("]") END;
		| sfTypeENUM:
			SYSTEM.GET(adr, word); Signed(word);
		| sfTypePORT:
			SYSTEM.GET(adr, a); Unsigned(a, SIZEOF(ADDRESS));
		| sfTypeProcedure, sfTypeDelegate:
			size := SIZE OF ADDRESS;
			SYSTEM.GET(adr, a); pc := NIL; GetProcedureName(a, procedure, pc);
			IF pc # NIL THEN w.String(procedure) ELSE Unsigned(a, SIZE OF ADDRESS) END;
			IF type = sfTypeDelegate THEN
				SYSTEM.GET(adr + size, a); INC(size, SIZE OF ADDRESS);
				w.String(" {"); Unsigned(a, SIZE OF ADDRESS); w.String("}");
			END;
		ELSE
			w.String("UNKOWN TYPE "); Unsigned(ORD(type),1);
		END;
		w.Update;
	END WriteBasicValue;

	PROCEDURE OnHeapOrStack(adr: ADDRESS; low, high: ADDRESS): BOOLEAN;
	BEGIN
		RETURN (low <= adr) & (adr < high) OR CheckHeapAddress(adr);
	END OnHeapOrStack;

	PROCEDURE WriteValueString*(w: Streams.Writer; adr: ADDRESS; maxLen: SIZE; low, high: ADDRESS);
	CONST MaxString = 96;
	VAR ch: CHAR;
	BEGIN
		IF maxLen > MaxString THEN maxLen := MaxString END;
		w.Char('"');
		LOOP
			IF (maxLen <= 0) OR ~OnHeapOrStack(adr, low, high) THEN
			 EXIT END;
			SYSTEM.GET(adr, ch);
			IF (ch < " ") OR (ch > "~") THEN EXIT END;
			w.Char(ch);
			INC(adr);
			DEC(maxLen);
		END;
		w.Char('"');
		IF maxLen = 0 THEN w.String("..."); END;
	END WriteValueString;

	PROCEDURE WriteMathArray*(w: Streams.Writer; adr: ADDRESS; low, high: ADDRESS);
		TYPE
		LenInc = RECORD
			len: SIZE;
			inc: SIZE
		END;

		UnsafeArray= POINTER {UNSAFE} TO RECORD
			ptr {UNTRACED}: ANY;
			adr: ADDRESS;
			flags: SET;
			dim: SIZE;
			elementSize: SIZE;
			lens: ARRAY 8 OF LenInc;
		END;

		VAR t {UNTRACED}: UnsafeArray; i: SIZE;
	BEGIN
		IF adr = NIL THEN w.String(" (NIL)");
		ELSIF  OnHeapOrStack(adr, low, high) THEN
			t := adr;
			w.String(" len/inc=[ ");
			IF t.dim < 8 THEN
				FOR i := 0 TO t.dim-1 DO
					w.Int(t.lens[i].len,0);
					w.String("/");
					w.Int(t.lens[i].inc,0);
					IF i < t.dim-1 THEN w.String(" , ") END;
				END;
			END;
			w.String(" ]");
			w.String(" flags = "); w.Set(t.flags);
			w.String(" adr = "); w.Address(t.adr);
			w.String(" ptr = "); w.Address(t.ptr);
			w.String(" elementSize = "); w.Int(t.elementSize,0);
		ELSE
			w.String("(UNKNOWN)");
		END;
	END WriteMathArray;


	PROCEDURE WriteValue*(w: Streams.Writer; refs: Modules.Bytes; VAR offset: SIZE; adr: ADDRESS; low, high: ADDRESS);
	VAR type: CHAR; a: ADDRESS; size, ofs: SIZE; len: SIZE;
	BEGIN
		IF ~OnHeapOrStack(adr, low, high) THEN
			SkipType(refs, offset);
			w.String("INVALID ADR:"); w.Address(adr);
			RETURN;
		END;
		type := GetChar(refs, offset);
		IF type = sfTypeIndirect THEN
			ofs := GetSize(refs, offset);
			WriteValue(w, refs, ofs, adr, low, high);
		ELSE
			CASE type OF
				sfTypeNone:
				w.String("NONE");
			| sfTypePointerToRecord, sfTypeANY, sfTypeOBJECT:
				WriteBasicValue(w,type, adr, size);
				SYSTEM.GET(adr, a);
				IF a = 0 THEN
					w.String(" NIL");
				ELSIF CheckHeapAddress(a) THEN
					SYSTEM.GET(a + Heaps.TypeDescOffset, a);
					w.String(" (");
					WriteType(w,a);
					w.String(")");
				ELSE
					w.String(" (UNKNOWN)");
				END;
			| sfTypePointerToArray:
				WriteBasicValue(w, sfTypeANY, adr, size);
				SYSTEM.GET(adr, a);
				IF ~OnHeapOrStack(a,low,high) THEN w.String(" (INVALID)") END;
				SkipType(refs, offset);
			| sfTypeOpenArray:
				IF refs[offset] = sfTypeCHAR THEN (* ARRAY OF CHAR *)
					SYSTEM.GET(adr, a);
					WriteValueString(w, a, MaxString, low, high);
				ELSE
					w.String("... (NO STRING)")
				END;
				SkipType(refs, offset);
			| sfTypeStaticArray:
				len := GetSize(refs, offset);
				IF refs[offset] = sfTypeCHAR THEN (* ARRAY x OF CHAR *)
					WriteValueString(w, adr, len, low, high);
				ELSE
					w.String("... (NO STRING)");
				END;
				SkipType(refs, offset);
			| sfTypeDynamicArray:
				w.String("... (DYNAMIC ARRAY)");
				SkipType(refs, offset);
			| sfTypeMathOpenArray:
				w.String(" OPEN MATH ARRAY ");
				SkipType(refs, offset);
				WriteMathArray(w, adr, low, high);
			| sfTypeMathStaticArray:
				w.String(" ... (MATH STATIC ARRAY)");
				SkipSize(offset); SkipType(refs, offset);
			| sfTypeMathTensor:
				w.String(" TENSOR ");
				SYSTEM.GET(adr, a);
				WriteBasicValue(w, sfTypeANY, adr, size);
				WriteMathArray(w, a, low, high);
				SkipType(refs, offset);
			| sfTypeRecord:
				w.String("...");
				w.String("(");
				a := GetAddress(refs, offset);
				WriteType(w,a);
				w.String(")");
			| sfTypeProcedure, sfTypeDelegate:
				WriteBasicValue(w, type, adr, size);
				WHILE refs[offset] = sfVariable DO SkipVariable(refs, offset) END;
				SkipType(refs, offset);
			| sfTypePORT:
				WriteBasicValue(w, type, adr, size);
				SkipChar(offset);
			ELSE
				WriteBasicValue(w, type, adr, size);
			END;
			w.Update;
		END;
	END WriteValue;

	PROCEDURE WriteVariable*(w: Streams.Writer; refs: Modules.Bytes; VAR offset: SIZE;  base: ADDRESS; low, high: ADDRESS);
	VAR name: Name;  adr: ADDRESS;  prevScope: SIZE; c: CHAR;
	BEGIN
		IF ~Expect(offset, GetChar(refs, offset) = sfVariable) THEN RETURN END;
		prevScope := GetSize(refs, offset);
		GetString(refs, offset, name);
		w.String(Sep); w.String(name); w.Char("=");
		c := GetChar(refs, offset);
		IF c = sfRelative THEN
			adr := base + GetSize(refs, offset);
			w.String(" [@");w.Int(adr-base,1); w.String("] ");
		ELSIF c = sfIndirect THEN
			adr := base + GetSize(refs, offset);
			w.String(" [@");w.Int(adr-base,1); w.String("] ");
			IF ~OnHeapOrStack(adr,low,high) THEN w.String(" (INVALID)");
				SkipType(refs,offset);
				RETURN;
			END;
			SYSTEM.GET(adr, adr);
			w.String("->");
			w.String(" [@");w.Address(adr); w.String("] ");
		ELSE (* absolute *)
			adr := GetAddress(refs, offset);
			w.String(" [@");w.Address(adr); w.String("] ");
		END;
		WriteValue(w, refs, offset, adr, low, high);
	END WriteVariable;

	(* write variables taking meta information from stream in stream at offset, potentially stored at base address
	 *)
	PROCEDURE WriteVariables*(w: Streams.Writer; refs: Modules.Bytes; VAR offset: SIZE; base: ADDRESS; low, high: ADDRESS);
	VAR count: SIZE;
	BEGIN
		WHILE refs[offset] = sfVariable DO
			WriteVariable(w, refs, offset, base, low, high); w.Ln;
			(*INC(count); *)
		END;
		IF count > 0 THEN w.Ln; Wait(w); END;
	END WriteVariables;

	(* skip type metadata in stream *)
	PROCEDURE SkipType*(refs: Modules.Bytes; VAR offset: SIZE);
	VAR c: CHAR;
	BEGIN
		c := GetChar(refs, offset);
		CASE c OF
			sfTypeNone .. sfTypeSIZE:
		| sfTypePointerToRecord:
		| sfTypePointerToArray:SkipType(refs, offset);
		| sfTypeOpenArray: SkipType(refs, offset);
		| sfTypeStaticArray: SkipSize(offset); SkipType(refs, offset);
		| sfTypeDynamicArray: SkipType(refs, offset);
		| sfTypeMathOpenArray: SkipType(refs, offset);
		| sfTypeMathStaticArray: SkipSize(offset); SkipType(refs, offset);
		| sfTypeMathTensor: SkipType(refs, offset);
		| sfTypeRecord: SkipSize(offset);
		| sfTypeProcedure, sfTypeDelegate:
			WHILE refs[offset] = sfVariable DO SkipVariable(refs, offset) END;
			SkipType(refs, offset);
		| sfTypeENUM:
		| sfTypePORT: SkipChar(offset);
		| sfTypeIndirect: SkipSize(offset);
		ELSE (* ?? *)
		END;
	END SkipType;

	(* skip procedure metadata in stream *)
	PROCEDURE SkipProcedure*(refs: Modules.Bytes; VAR offset: SIZE);
	BEGIN
		IF ~Expect(offset, GetChar(refs, offset) = sfProcedure) THEN RETURN END;
		SkipSize(offset);
		SkipString(refs, offset);
		SkipAddress(offset);
		SkipAddress(offset);
		SkipSet(offset);
		WHILE (refs[offset] = sfVariable)  DO	SkipVariable(refs, offset) END;
		SkipType(refs, offset);
		SkipScope(refs, offset);
	END SkipProcedure;


	(* skip variable metadata in stream *)
	PROCEDURE SkipVariable*(refs: Modules.Bytes; VAR offset: SIZE);
	BEGIN
		IF ~Expect(offset, GetChar(refs, offset) = sfVariable) THEN RETURN END;
		SkipSize(offset);
		SkipString(refs, offset);
		SkipChar(offset);
		SkipAddress(offset);
		SkipType(refs, offset);
	END SkipVariable;

	(* skip type declaration meta data in stream *)
	PROCEDURE SkipTypeDeclaration*(refs: Modules.Bytes; VAR offset: SIZE);
	BEGIN
		IF ~Expect(offset, GetChar(refs, offset) = sfTypeDeclaration) THEN RETURN END;
		SkipSize(offset);
		SkipString(refs, offset);
		SkipAddress(offset);
		IF refs[offset] = sfScopeBegin THEN SkipScope(refs, offset) END;
	END SkipTypeDeclaration;

	(* skip type declaration meta data in stream *)
	PROCEDURE SkipModule*(refs: Modules.Bytes; VAR offset: SIZE);
	BEGIN
		IF ~Expect(offset, GetChar(refs, offset) = sfModule) THEN RETURN END;
		SkipSize(offset);
		SkipString(refs, offset);
		IF refs[offset] = sfScopeBegin THEN SkipScope(refs, offset) END;
	END SkipModule;

	(* skip a scope in stream *)
	PROCEDURE SkipScope*(refs: Modules.Bytes; VAR offset: SIZE);
	BEGIN
		IF ~Expect(offset, GetChar(refs, offset) = sfScopeBegin) THEN RETURN END;
		WHILE (refs[offset] = sfVariable)  DO SkipVariable(refs, offset) END;
		WHILE (refs[offset] = sfProcedure) DO SkipProcedure(refs, offset) END;
		WHILE (refs[offset] = sfTypeDeclaration)  DO SkipTypeDeclaration(refs, offset)	END;
		IF ~Expect(offset, GetChar(refs, offset) = sfScopeEnd) THEN RETURN END;
	END SkipScope;

	TYPE
	Search = RECORD
		name: ARRAY 256 OF CHAR; 	(* for search by name *)
		nameOffset: SIZE;				(* to incrementally search through scopes *)
		minLevel: SIZE; 					(* in order to stop scope search *)
		pc: ADDRESS;							(* for search by address *)
		pos: SIZE;							(* symbol position in stream, -1 if not found *)
		found: BOOLEAN;						(* if found *)
	END;

	(* check if stream contains the string part stored in search record with respective offset *)
	PROCEDURE FindString(refs: Modules.Bytes; VAR offset: SIZE; level: SIZE; VAR find: Search);
	VAR ofs: SIZE;
	BEGIN
		IF find.minLevel > level THEN
			SkipString(refs, offset)
		ELSE
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
		END;
	END FindString;

	(* find a symbol by name or pc starting from the procedure stream section *)
	PROCEDURE FindInProcedure(refs: Modules.Bytes; VAR offset: SIZE; level: SIZE; VAR find: Search);
	VAR start, end: ADDRESS; pos: SIZE;
	BEGIN
		pos := offset;
		IF ~Expect(offset, GetChar(refs, offset) = sfProcedure) THEN RETURN END;
		SkipSize(offset);
		FindString(refs, offset, level, find);
		start := GetAddress(refs, offset);
		end := GetAddress(refs, offset);
		SkipSet(offset);
		find.found := find.found OR (start <= find.pc) & (find.pc < end);
		IF find.found THEN
			find.pos := pos;
			RETURN;
		END;
		WHILE (refs[offset] = sfVariable) DO
			IF find.minLevel <= level+1 THEN
				FindInVariable(refs, offset, level+1, find);
				IF find.found THEN RETURN END;
			ELSE
				SkipVariable(refs, offset)
			END;
		END;
		SkipType(refs, offset);
		FindInScope(refs, offset, level+1, find);
	END FindInProcedure;

	(* find a symbol by name or pc starting from the variable stream section *)
	PROCEDURE FindInVariable(refs: Modules.Bytes; VAR offset: SIZE; level: SIZE; VAR find: Search);
	VAR pos: SIZE;
	BEGIN
		pos := offset;
		IF ~Expect(offset, GetChar(refs, offset) = sfVariable) THEN RETURN END;
		SkipSize(offset);
		FindString(refs, offset, level, find);
		IF find.found THEN
			find.pos := pos;
			RETURN;
		END;
		SkipChar(offset);
		SkipSize(offset);
		SkipType(refs, offset);
	END FindInVariable;

	(* find a symbol by name or pc starting from the type declaration stream section *)
	PROCEDURE FindInTypeDeclaration(refs: Modules.Bytes; VAR offset: SIZE; level: SIZE; VAR find: Search);
	VAR pos: SIZE;
	BEGIN
		pos := offset;
		IF ~Expect(offset, GetChar(refs, offset) = sfTypeDeclaration) THEN RETURN END;
		SkipSize(offset);
		FindString(refs, offset, level, find);
		IF find.found THEN
			find.pos := pos;
			RETURN;
		END;
		SkipAddress(offset);
		IF refs[offset] = sfScopeBegin THEN FindInScope(refs, offset, level+1, find) END;
	END FindInTypeDeclaration;

	PROCEDURE FindInModule(refs: Modules.Bytes; VAR offset: SIZE; level: SIZE; VAR find: Search);
	VAR pos: SIZE;
	BEGIN
		pos := offset;
		IF ~Expect(offset, GetChar(refs, offset) = sfModule) THEN RETURN END;
		SkipSize(offset);
		FindString(refs, offset, level, find);
		IF find.found THEN
			find.pos := pos;
			RETURN;
		END;
		FindInScope(refs, offset, level+1, find);
	END FindInModule;

	(* find a symbol by name or pc in a scope in the stream *)
	PROCEDURE FindInScope(refs: Modules.Bytes; VAR offset: SIZE; level: SIZE; VAR find: Search);
	BEGIN
		IF ~Expect(offset, GetChar(refs, offset) = sfScopeBegin) THEN RETURN END;
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
		IF ~Expect(offset, GetChar(refs, offset) = sfScopeEnd) THEN RETURN END;
	END FindInScope;

	PROCEDURE InitSearch(VAR search: Search);
	BEGIN
		search.found := FALSE;
		search.pos := -1;
		search.name := "";
		search.nameOffset := 0;
		search.minLevel := 0;
		search.pc := 0;
	END InitSearch;

	(* Find a symbol in the stream starting at offset.
		If name is supposed to contain the referred to symbol, choose skipFirstSymbol = FALSE
			Example FindByName(m.refs, 0, "Reflection.FindByName", FALSE)
		otherwise choose skipFirstSymbol = TRUE
			Example FindByName(m.refs, 0, "FindByName", TRUE);
	*)
	PROCEDURE FindByName*(refs: Modules.Bytes; offset: SIZE; CONST name: ARRAY OF CHAR; skipFirstSymbol: BOOLEAN): SIZE;
	VAR search: Search;
	BEGIN
		InitSearch(search);
		COPY(name, search.name);
		IF skipFirstSymbol THEN search.minLevel := 1 END;
		CASE refs[offset] OF
			sfModule: FindInModule(refs, offset, 0, search);
			|sfVariable: FindInVariable(refs, offset, 0, search);
			|sfProcedure: FindInProcedure(refs, offset, 0, search);
			|sfTypeDeclaration: FindInTypeDeclaration(refs, offset, 0, search);
		ELSE (* wrong position in stream *)
		END;
		RETURN search.pos;
	END FindByName;

	PROCEDURE FindByAdr*(refs: Modules.Bytes; offset: SIZE; pc: ADDRESS): SIZE;
	VAR search: Search;
	BEGIN
		InitSearch(search);
		search.pc := pc;
		CASE refs[offset] OF
			sfModule: FindInModule(refs, offset, 0, search);
			|sfVariable: FindInVariable(refs, offset, 0, search);
			|sfProcedure: FindInProcedure(refs, offset, 0, search);
			|sfTypeDeclaration: FindInTypeDeclaration(refs, offset, 0, search);
		ELSE (* wrong position in stream *)
		END;
		RETURN search.pos;
	END FindByAdr;

	(** service procedures *)

	(** Find procedure name and write it. *)
	PROCEDURE WriteProc*(w: Streams.Writer; pc: ADDRESS);
	VAR refs: Modules.Bytes; refpos: SIZE; base: ADDRESS;
	BEGIN
		WriteProc0(w, Modules.ThisModuleByAdr0(pc), pc,  -1, refs, refpos, base)
	END WriteProc;

	(** Write the state of the specified module. *)
	PROCEDURE ModuleState*(w: Streams.Writer; mod: Modules.Module);
	VAR offset: SIZE; refs: Modules.Bytes;
	BEGIN
		IF mod = NIL THEN RETURN END;
		refs := mod.refs;
		offset := 0;

		w.String("State "); w.String(mod.name); w.Char(":");
		w.String(" (CRC = "); w.Hex(mod.crc,-8) ; w.String(")");
		w.Ln; Wait(w);
		IF (GetChar(refs, offset) = sfModule) THEN
			SkipSize(offset);
			SkipString(refs, offset);
			IF (GetChar(refs, offset) = sfScopeBegin) THEN
				WriteVariables(w, refs, offset, 0, 0, 0)
			END;
		END;
	END ModuleState;

	(* Display call trackback. *)
	PROCEDURE StackTraceBack*(w: Streams.Writer; pc, bp: ADDRESS; low,high: ADDRESS; long, overflow: BOOLEAN);
	VAR count,offset: SIZE; base: ADDRESS; m: Modules.Module; refs: Modules.Bytes;
	BEGIN
		count := 0;	(* frame count *)
		REPEAT
			m := Modules.ThisModuleByAdr0(pc);
			IF (ShowAllProcs OR (m # NIL) OR (count = 0)) & (bp # 0) & (bp >= low) & (bp <= high) & (bp MOD SIZEOF(ADDRESS)=0) THEN
				IF CheckHeapAddress( pc ) THEN
					WriteProc0(w, m, pc, bp, refs, offset, base); w.Ln;Wait(w); w.Update;
					IF long & (~overflow OR (count > 0)) THEN	(* show variables *)
						IF offset >= 0 THEN
							WriteVariables(w,refs,offset, base, low, high);
							SkipType(refs, offset);
							IF Expect(offset, GetChar(refs, offset) = sfScopeBegin) THEN
								WriteVariables(w,refs,offset, base, low, high);
							END;
						END;
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
	VAR adr: ADDRESS; mode: INTEGER; m: Modules.Module;
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

	(* for interface compatibility *)
	PROCEDURE GetVariableAdr*(fp, pc: ADDRESS; CONST name: ARRAY OF CHAR): SIZE;
	BEGIN
		RETURN -1;
	END GetVariableAdr;

	PROCEDURE GetProcedureName*(pc: ADDRESS; VAR name: ARRAY OF CHAR; VAR startpc: ADDRESS);
	VAR m: Modules.Module; offset: SIZE;
	BEGIN
		name := "";
		m := Modules.ThisModuleByAdr0(pc);
		IF m # NIL THEN
			offset := FindByAdr(m.refs,0,pc);
			IF offset >= 0 THEN
				GetFullName(m.refs, offset, name);
				IF GetChar(m.refs, offset) = sfProcedure THEN
					SkipSize(offset);
					SkipString(m.refs,offset);
					startpc := GetAddress(m.refs, offset);
				END;
			END;
		END;
	END GetProcedureName;

TYPE
	Variable* = RECORD
		adr-: ADDRESS;
		type-, size-, n-: SIZE;
		tdadr-: ADDRESS;
	END;

	(* half-stub for module Info to work *)
	PROCEDURE FindVar*(mod: Modules.Module; CONST name: ARRAY OF CHAR; VAR v: Variable): BOOLEAN;
	VAR offset: SIZE; size: SIZE;adr: ADDRESS;
	BEGIN
		offset := FindByName(mod.refs, 0,name, TRUE);
		IF offset < 0 THEN RETURN FALSE END;
		IF ~Expect(offset, GetChar(mod.refs, offset) = sfVariable) THEN RETURN FALSE END;
		SkipSize(offset);
		SkipString(mod.refs, offset);
		IF GetChar(mod.refs, offset) = sfRelative THEN
			size := GetSize(mod.refs, offset);
		ELSE (* absolute *)
			adr := GetAddress(mod.refs, offset);
		END;

		v.adr := adr;
		v.type := 0;
		v.size := 0;
		v.n := 0;
		v.tdadr :=  0;
		RETURN TRUE;
	END FindVar;

	PROCEDURE WriteVar*(w: Streams.Writer; v: Variable; VAR col: SIGNED32);
	BEGIN
	END WriteVar;



	PROCEDURE ReportType*(w:Streams.Writer; refs: Modules.Bytes; VAR offset: SIZE);
	VAR c: CHAR;
	BEGIN
		c := GetChar(refs, offset);
		CASE c OF
			sfTypeNone: w.String("no type");
		| sfTypePointerToRecord: w.String("POINTER TO RECORD");
		| sfTypePointerToArray: w.String("POINTER TO"); ReportType(w, refs, offset);
		| sfTypeOpenArray: w.String("ARRAY OF "); ReportType(w, refs, offset);
		| sfTypeStaticArray: w.String("ARRAY "); w.Int(GetSize(refs, offset),1 ); w.String(" OF "); ReportType(w, refs, offset);
		| sfTypeDynamicArray: w.String("DARRAY OF "); ReportType(w,refs, offset);
		| sfTypeMathOpenArray: w.String("ARRAY [*] OF "); ReportType(w, refs, offset);
		| sfTypeMathStaticArray: w.String("ARRAY ["); w.Int(GetSize(refs, offset),1); w.String("] OF "); ReportType(w, refs, offset);
		| sfTypeMathTensor: w.String("ARRAY [?] OF "); ReportType(w, refs, offset);
		| sfTypeRecord: w.String("RECORD ");  w.Address(GetAddress(refs, offset));
		| sfTypeProcedure, sfTypeDelegate:
			w.String("PROCEDURE"); IF c = sfTypeDelegate THEN w.String(" {DELEGATE}") END; w.String(" (");
			WHILE refs[offset] = sfVariable DO ReportVariable(w, refs, offset) END;
			w.String("):"); ReportType(w, refs, offset);
		| sfTypeBOOLEAN: w.String("BOOLEAN");
		| sfTypeCHAR: w.String("CHAR");
		| sfTypeSHORTINT: w.String("SIGNED8");
		| sfTypeINTEGER: w.String("SIGNED16");
		| sfTypeLONGINT: w.String("SIGNED32");
		| sfTypeHUGEINT: w.String("SIGNED64");
		| sfTypeWORD: w.String("INTEGER");
		| sfTypeLONGWORD: w.String("LONGINTEGER");
		| sfTypeSIGNED8: w.String("SIGNED8");
		| sfTypeSIGNED16: w.String("SIGNED16");
		| sfTypeSIGNED32: w.String("SIGNED32");
		| sfTypeSIGNED64: w.String("SIGNED64");
		| sfTypeUNSIGNED8: w.String("UNSIGNED8");
		| sfTypeUNSIGNED16: w.String("UNSIGNED16");
		| sfTypeUNSIGNED32: w.String("UNSIGNED32");
		| sfTypeUNSIGNED64: w.String("UNSIGNED64");
		| sfTypeREAL: w.String("FLOAT32");
		| sfTypeLONGREAL: w.String("FLOAT64");
		| sfTypeCOMPLEX: w.String("COMPLEX32");
		| sfTypeLONGCOMPLEX: w.String("COMPLEX64");
		| sfTypeSET: w.String("SET");
		| sfTypeANY: w.String("ANY");
		| sfTypeOBJECT: w.String("OBJECT");
		| sfTypeBYTE: w.String("BYTE");
		| sfTypeRANGE: w.String("RANGE");
		| sfTypeADDRESS: w.String("ADDRESS");
		| sfTypeSIZE: w.String("SIZE");
		| sfTypePORT: w.String("PORT"); IF GetChar(refs,offset) = sfIN THEN w.String("IN") ELSE w.String("OUT") END;
		| sfTypeIndirect: w.String ("INDIRECT AT "); w.Int(GetSize(refs, offset),1);
		ELSE w.String("????? TYPE ?????");
		END;
	END ReportType;

	PROCEDURE ReportProcedure*(w: Streams.Writer; refs: Modules.Bytes; VAR offset: SIZE);
	VAR name: Name;  start, end: ADDRESS;  flags: SET;
	BEGIN
		w.Int(offset,1); w.String(":");
		w.String("PROCEDURE ");
		IF ~Expect(offset, GetChar(refs, offset) = sfProcedure) THEN RETURN END;
		SkipSize(offset);
		GetString(refs, offset, name);
		w.String(name);
		start := GetAddress(refs, offset);
		end := GetAddress(refs, offset);
		flags := GetSet(refs, offset);
		IF flags # {} THEN
			w.Set(flags);
		END;
		w.String("[@"); w.Address(start); w.String(" - "); w.Address(end); w.String("]");
		w.String("("); w.Ln;
		WHILE refs[offset] = sfVariable DO
			ReportVariable(w, refs, offset);
		END;
		w.String(")");
		w.String(":");
		ReportType(w, refs, offset);
		w.Ln;
		ReportScope(w, refs, offset);
	END ReportProcedure;


	PROCEDURE ReportVariable*(w: Streams.Writer; refs: Modules.Bytes; VAR offset: SIZE);
	VAR name: Name;  adr: ADDRESS;  size: SIZE;
	BEGIN
		w.Int(offset,1); w.String(":");
		w.String("VAR ");
		IF ~Expect(offset, GetChar(refs, offset) = sfVariable) THEN RETURN END;
		SkipSize(offset);
		GetString(refs, offset, name);
		w.String(name);
		IF GetChar(refs, offset) = sfRelative THEN
			size := GetSize(refs, offset);
			w.String("[@"); w.Int(size,1); w.String("]");
		ELSE (* absolute *)
			adr := GetAddress(refs, offset);
			w.String("[@"); w.Address(adr); w.String("]");
		END;
		w.String(":");
		ReportType(w, refs, offset);
		w.Ln;
	END ReportVariable;

	PROCEDURE ReportTypeDeclaration*(w: Streams.Writer; refs: Modules.Bytes; VAR offset: SIZE);
	VAR name: Name;  adr: ADDRESS;
	BEGIN
		w.Int(offset,1); w.String(":");
		w.String("TYPE ");
		IF ~Expect(offset, GetChar(refs, offset) = sfTypeDeclaration) THEN RETURN END;
		SkipSize(offset);
		GetString(refs, offset, name);
		w.String(name);
		adr := GetAddress(refs, offset);
		w.String(" ");
		w.Address(adr);
		w.Ln;
		IF refs[offset] = sfScopeBegin THEN ReportScope(w, refs, offset) END;
	END ReportTypeDeclaration;

	PROCEDURE ReportScope*(w:Streams.Writer; refs: Modules.Bytes; VAR offset: SIZE);
	VAR
		offsetOld: SIZE;
	BEGIN
		offsetOld := offset;
		IF ~Expect(offset, GetChar(refs, offset) = sfScopeBegin) THEN RETURN END;
		w.Int(offsetOld, 1); w.String(": Scope"); w.Ln;
		WHILE (refs[offset] = sfVariable) DO (* Variable *)
			ReportVariable(w, refs, offset);
		END;
		WHILE (refs[offset] = sfProcedure) DO (* Procedure *)
			ReportProcedure(w, refs, offset);
		END;
		WHILE (refs[offset] = sfTypeDeclaration) DO (* TypeDeclaration *)
			ReportTypeDeclaration(w, refs, offset);
		END;
		IF ~Expect(offset, GetChar(refs, offset) = sfScopeEnd) THEN RETURN END;
		w.String("END"); w.Ln;
	END ReportScope;

	PROCEDURE ReportModule*(w: Streams.Writer; refs: Modules.Bytes; offset: SIZE);
	VAR name: Name;
	BEGIN
		w.String("MODULE ");
		IF ~Expect(offset, GetChar(refs, offset) = sfModule) THEN RETURN END;
		SkipSize(offset);
		GetString(refs, offset, name);
		w.String(name);
		w.Ln;
		ReportScope(w, refs, offset);
	END ReportModule;

	PROCEDURE Report*(w:Streams.Writer; refs: Modules.Bytes; offset: SIZE);
	BEGIN
		CASE refs[offset] OF
			sfModule: ReportModule(w, refs, offset);
			|sfVariable: ReportVariable(w, refs, offset);
			|sfProcedure: ReportProcedure(w, refs, offset);
			|sfTypeDeclaration: ReportTypeDeclaration(w, refs, offset);
		ELSE (* wrong position in stream *)
		END;
	END Report;


VAR trace: Streams.Writer;

	PROCEDURE WriteMode*(mode : SIGNED32; out : Streams.Writer);
	BEGIN
		CASE mode OF
			|Objects.Ready : out.String("rdy");
			|Objects.Running : out.String("run");
			|Objects.AwaitingLock : out.String("awl");
			|Objects.AwaitingCond : out.String("awc");
			|Objects.AwaitingEvent : out.String("awe");
			|Objects.Terminated : out.String("rip");
		ELSE
			out.String("???");
		END;
		out.Update;
	END WriteMode;

	PROCEDURE WriteWaitingOn*(t : Objects.Process; out : Streams.Writer);
	VAR adr : ADDRESS; mod : Modules.Module;
	BEGIN
		IF t.mode = Objects.AwaitingLock THEN
			adr := SYSTEM.VAL(ADDRESS, t.waitingOn);
			IF adr # 0 THEN	(* can be 0 when snapshot is taken *)
				SYSTEM.GET(adr-SIZEOF(ADDRESS), adr); DEC(adr, adr MOD 8);
				IF adr = SYSTEM.TYPECODE(Modules.Module) THEN
					mod := SYSTEM.VAL(Modules.Module, adr);
					out.String(mod.name)
				ELSE
					WriteType(out, adr)
				END;
			END
		ELSIF t.mode = Objects.AwaitingCond THEN
			WriteProc(out, SYSTEM.VAL(ADDRESS, t.condition));
		END;
		out.Update;
	END WriteWaitingOn;

	PROCEDURE WriteFlags*(flags : SET; out : Streams.Writer);
	VAR comma : BOOLEAN;
	BEGIN
		comma := FALSE;
		IF Objects.Restart IN flags THEN
			out.String("restart"); comma := TRUE;
		END;
		IF Objects.Resistant IN flags THEN
			IF comma THEN out.String(", "); END;
			out.String("resistant"); comma := TRUE;
		END;
		IF Objects.Preempted IN flags THEN
			IF comma THEN out.String(", "); END;
			out.String("preempted"); comma := TRUE;
		END;
		IF Objects.PleaseHalt IN flags THEN
			IF comma THEN out.String(", "); END;
			out.String("pleaseHalt"); comma := TRUE;
		END;
		IF Objects.Unbreakable IN flags THEN
			IF comma THEN out.String(", "); END;
			out.String("unbreakable"); comma := TRUE;
		END;
		IF Objects.SelfTermination IN flags THEN
			IF comma THEN out.String(", "); END;
			out.String("selftermination");
		END;
		out.Update;
	END WriteFlags;

	PROCEDURE TraceH(process: Objects.Process; pc, bp: ADDRESS; stacklow, stackhigh: ADDRESS);
	VAR adr: ADDRESS;
	BEGIN
		trace.String("---------------------------------"); trace.Ln;
		trace.String("Process "); trace.Int(process.id,1); trace.Ln;
		trace.String(" Active Object: ");
		IF process.obj # NIL THEN
			SYSTEM.GET(SYSTEM.VAL(ADDRESS, process.obj)-SIZEOF(ADDRESS), adr);
			WriteType(trace, adr);
		END;
		trace.Ln;
		trace.String("Current Procedure: ");
		WriteProc(trace, pc); trace.Ln;

		(* mode *)
		trace.String("Mode: "); WriteMode(process.mode, trace); trace.Ln;
		trace.String("Waiting On: "); WriteWaitingOn(process, trace); trace.Ln;

		(* Flags *)
		trace.String("Flags: "); WriteFlags(process.flags, trace); trace.Ln;

		trace.String("Stack Trace Back:"); trace.Ln; trace.Update;

		StackTraceBack(trace, pc, bp, stacklow ,stackhigh, TRUE, FALSE);
		trace.String("---------------------------------"); trace.Ln;
		trace.Update;
	END TraceH;

	(* tracing the stacks of all processes during GC phase (needs to identify and stop all processes) *)
	PROCEDURE TraceProcesses*;
	BEGIN
		Objects.TraceProcessHook := TraceH;

		Kernel.GC;
		Objects.TraceProcessHook := NIL;
	END TraceProcesses;

	PROCEDURE Test*;
	VAR res: INTEGER; mod: Modules.Module; msg: ARRAY 32 OF CHAR; pos: SIZE;
	BEGIN
		mod := Modules.ThisModule("Reflection",res,msg);
		ReportModule(trace, mod.refs, pos);
	END Test;


BEGIN
	NEW(trace, Trace.Send, 4 (*4096*) );  (* trace asap *)
	modes := " rdy run awl awc awe rip";   (* 4 characters per mode from Objects.Ready to Objects.Terminated *)
END Reflection.


Linker.Link --fileFormat=PE32 --fileName=A2.exe --extension=GofW --displacement=401000H  Builtins Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands Files WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection  Loader  BootConsole ~
