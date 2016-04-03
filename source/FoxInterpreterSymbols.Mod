MODULE FoxInterpreterSymbols; (** AUTHOR ""; PURPOSE ""; *)

IMPORT Strings, Basic := FoxBasic, StringPool, Streams, Commands, PersistentObjects, Modules, Machine, SYSTEM;

CONST
	TAB = 09X;

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
			sfTypePointerToRecord = 20X;
			sfTypePointerToArray = 21X;
			sfTypeOpenArray = 22X;
			sfTypeStaticArray = 23X;
			sfTypeRecord = 24X;

TYPE

	Item*= PersistentObjects.Object;
	Object* = PersistentObjects.Object;
	Content* = PersistentObjects.Content;

	TYPE

	Result*= OBJECT (Item)

		PROCEDURE Evaluate*(): Value;
		BEGIN
			RETURN NIL;
		END Evaluate;

		PROCEDURE SetV*(v: Value): BOOLEAN;
		BEGIN
			RETURN FALSE;
		END SetV;
		
		PROCEDURE Find*(CONST name: ARRAY OF CHAR): Result;
		BEGIN
			RETURN NIL;
		END Find;

		PROCEDURE Address*(): ADDRESS;
		BEGIN
			RETURN NIL;
		END Address;
		
		PROCEDURE Trace*;
		BEGIN
			
		END Trace;
		
	END Result;
	
		
	SymbolResult*=OBJECT(Result)
	VAR name: ARRAY 32 OF CHAR;
	
		PROCEDURE InitSymbol(CONST n: ARRAY OF CHAR);
		BEGIN
			COPY(n, name);
		END InitSymbol;
		
	END SymbolResult;
	
	ModuleResult*= OBJECT(SymbolResult)
	VAR 
		self: Modules.TypeDesc;
		
		PROCEDURE & InitModule(CONST name: ARRAY OF CHAR; m: Modules.Module);
		BEGIN
			InitSymbol(name);
			ASSERT(m # NIL);
			self := FindType(m.typeInfo, "@Self");
			ASSERT(self # NIL);
		END InitModule;
		
		PROCEDURE Find(CONST name: ARRAY OF CHAR): Result;
		VAR num: LONGINT;
				proc: ProcedureResult;
				field: FieldResult;
		BEGIN
				IF FindProc(self.procedures, name,num) THEN
					NEW(proc, SELF, name, self.procedures[num]);
					proc.address := self.procedures[num].address;
					RETURN proc
				ELSIF FindField(self.fields, name, num) THEN
					NEW(field, name, self.fields[num]);
					field.address := self.fields[num].offset;
					RETURN field;
				END;
				RETURN NIL;
		END Find;


	END ModuleResult;
	
		Callstack = OBJECT
	VAR 
		data: ARRAY 1024 OF CHAR;
		pos: LONGINT;
		size: LONGINT;
		H: HUGEINT; (* result in register *)
		
		retType: Modules.FieldEntry;
		parameters: POINTER TO ARRAY OF Modules.FieldEntry;
		pPos: LONGINT;
		
		PROCEDURE & Init;
		BEGIN
			pos := 1024; size := 0;
		END Init;
		
		PROCEDURE Next(s: SIZE): ADDRESS;
		BEGIN
			DEC(pos, s); INC(size, s);
			RETURN ADDRESSOF(data[pos]);
		END Next;
		
		PROCEDURE PushH(h: HUGEINT);
		VAR p: POINTER {UNSAFE} TO RECORD h: HUGEINT END;
		BEGIN
			p := Next(SIZEOF(HUGEINT));
			p.h := h;
		END PushH;

		PROCEDURE PushL(i: LONGINT);
		VAR p: POINTER {UNSAFE} TO RECORD i: LONGINT END;
		BEGIN
			p := Next(SIZEOF(LONGINT));
			p.i := i;
		END PushL;

		PROCEDURE PushI(i: INTEGER);
		BEGIN
			PushL(i);
		END PushI;		

		PROCEDURE PushS(i: SHORTINT);
		BEGIN
			PushL(i);
		END PushS;		
		
		PROCEDURE PushB(b: BOOLEAN);
		VAR p: POINTER {UNSAFE} TO RECORD b: BOOLEAN END;
		BEGIN
			p := Next(SIZEOF(LONGINT));
			p.b := b;
		END PushB;
		
		PROCEDURE PushC(c: CHAR);
		BEGIN
			PushL(ORD(c));
		END PushC;
		
		PROCEDURE PushSet(set: SET);
		VAR p: POINTER {UNSAFE} TO RECORD s:SET END;
		BEGIN
			p := Next(SIZEOF(SET));
			p.s := set;
		END PushSet;

		PROCEDURE PushR(r: REAL);
		VAR p: POINTER {UNSAFE} TO RECORD r: REAL END;
		BEGIN
			p := Next(SIZEOF(REAL));
			p.r := r;
		END PushR;
		
		PROCEDURE PushX(x: LONGREAL);
		VAR p: POINTER {UNSAFE} TO RECORD x: LONGREAL END;
		BEGIN
			p := Next(SIZEOF(LONGREAL));
			p.x := x;
		END PushX;
		
		PROCEDURE PushA(a: ADDRESS);
		VAR p: POINTER {UNSAFE} TO RECORD a: ADDRESS END;
		BEGIN
			p := Next(SIZEOF(ADDRESS));
			p.a := a;
		END PushA;


		PROCEDURE PushSz(s: SIZE);
		VAR p: POINTER {UNSAFE} TO RECORD s: SIZE END;
		BEGIN
			p := Next(SIZEOF(SIZE));
			p.s := s;
		END PushSz;
		
		PROCEDURE Call(adr: ADDRESS);
		TYPE
			P = PROCEDURE();
		VAR
			esp: ADDRESS;
			p: P; 
		BEGIN
			p := SYSTEM.VAL(P, adr);
			esp := Machine.CurrentSP();
			Machine.SetSP(esp-size);
			IF size > 0 THEN 
				SYSTEM.MOVE(ADDRESS OF data[pos], esp-size, size);
			END;
			p();
			Machine.SetSP(esp);
		END Call; 

		PROCEDURE CallH(adr: ADDRESS): HUGEINT;
		TYPE
			P = PROCEDURE(): HUGEINT;
		VAR
			res: HUGEINT; esp: ADDRESS;
			p: P; 
		BEGIN
			p := SYSTEM.VAL(P, adr);
			esp := Machine.CurrentSP();
			Machine.SetSP(esp-size);
			IF size > 0 THEN 
				SYSTEM.MOVE(ADDRESS OF data[pos], esp-size, size);
			END;
			res := p();
			Machine.SetSP(esp);
			RETURN res;
		END CallH; 

		PROCEDURE CallR(adr: ADDRESS): REAL;
		TYPE
			P = PROCEDURE(): REAL;
		VAR
			res: REAL; esp: ADDRESS;
			p: P; 
		BEGIN
			p := SYSTEM.VAL(P, adr);
			esp := Machine.CurrentSP();
			Machine.SetSP(esp-size);
			IF size > 0 THEN 
				SYSTEM.MOVE(ADDRESS OF data[pos], esp-size, size);
			END;
			res := p();
			Machine.SetSP(esp);
			RETURN res;
		END CallR; 

		PROCEDURE CallX(adr: ADDRESS): LONGREAL;
		TYPE
			P = PROCEDURE(): LONGREAL;
		VAR
			res: LONGREAL; esp: ADDRESS;
			p: P; 
		BEGIN
			p := SYSTEM.VAL(P, adr);
			esp := Machine.CurrentSP();
			Machine.SetSP(esp-size);
			IF size > 0 THEN 
				SYSTEM.MOVE(ADDRESS OF data[pos], esp-size, size);
			END;
			res := p();
			Machine.SetSP(esp);
			RETURN res;
		END CallX; 
	END Callstack;

	ProcedureResult*= OBJECT(SymbolResult)
	VAR 
		proc: Modules.ProcedureEntry;
		address: ADDRESS;
		stack: Callstack;
		index: LONGINT;
		caller-: Result;
		
		PROCEDURE ReturnsPointer*(): BOOLEAN;
		BEGIN
			CASE proc.returnType.class
			OF sfTypeANY, sfTypeOBJECT, sfTypePointerToRecord: RETURN TRUE
			ELSE RETURN FALSE
			END;
		END ReturnsPointer;
		
		PROCEDURE Address(): ADDRESS;
		BEGIN
			RETURN address;
		END Address;
		
	
		PROCEDURE & InitProcedure(c: Result; CONST name: ARRAY OF CHAR; CONST p: Modules.ProcedureEntry);
		BEGIN
			InitSymbol(name); proc := p;
			caller := c; 
		END InitProcedure;
		
		PROCEDURE Pars*();
		BEGIN
			index := 0;
			NEW(stack); (* can optimize this *)
		END Pars;
		
		PROCEDURE PushAddress*(adr: ADDRESS); (* for self pointer *)
		BEGIN
			stack.PushA(adr);
		END PushAddress;
		
		PROCEDURE Push*(o: Result): BOOLEAN;
		VAR type: Modules.EntryType;
			s: SHORTINT; i: INTEGER; l: LONGINT; h: HUGEINT; 
			r: REAL; x: LONGREAL;
			b: BOOLEAN;
			set: SET;
			var: BOOLEAN;
			v:Value;
		BEGIN
			IF (proc.parameters = NIL) OR (index >= LEN(proc.parameters)) THEN RETURN FALSE END; 
			type := proc.parameters[index].type;
			var := 1 IN proc.parameters[index].flags;
			INC(index);
			IF var THEN
				IF type.subclass = 0X THEN
					CASE type.class OF
						sfTypeCHAR .. sfTypePointerToArray:
						(*! check type ! *)
						 stack.PushA(o.Address());
						 RETURN TRUE;
					ELSE
						RETURN FALSE
					END;
				ELSIF type.subclass = sfTypeOpenArray THEN
					CASE type.class OF
					sfTypeCHAR, sfTypeCHAR8:
						IF o IS StringValue THEN
							stack.PushSz(LEN(o(StringValue).value));
							stack.PushA(ADDRESSOF(o(StringValue).value[0])); 
							RETURN TRUE;
						END;
					END;
				END;
			ELSE
			v := o.Evaluate();
			IF v = NIL THEN RETURN FALSE END;
			WITH v: Value DO 
			IF type.subclass = 0X THEN
				CASE type.class OF
				sfTypeSHORTINT,sfTypeSIGNED8 : 
					IF v.GetInt(h) THEN
						s:= SHORTINT(h); stack.PushS(s);
						RETURN TRUE;
					END;
				| sfTypeINTEGER,sfTypeSIGNED16 : 
					IF v.GetInt(h) THEN
						i:= INTEGER(h); stack.PushI(i);
						RETURN TRUE;
					END;
				| sfTypeLONGINT,sfTypeSIGNED32: 
					IF v.GetInt(h) THEN
						l:= LONGINT(h); stack.PushL(l);
						RETURN TRUE;
					END;
				| sfTypeHUGEINT,sfTypeSIGNED64: 
					IF v.GetInt(h) THEN
						stack.PushH(h);
						RETURN TRUE;
					END;
				|sfTypeREAL:
					IF v.GetReal(x) THEN
						r := REAL(x);stack.PushR(r);
						RETURN TRUE;
					END;
				|sfTypeLONGREAL:
					IF v.GetReal(x) THEN
						stack.PushX(x);
						RETURN TRUE;
					END;
				|sfTypeBOOLEAN:
					IF v.GetBoolean(b) THEN
						stack.PushB(b);
					RETURN TRUE
					END;
				|sfTypeSET:
					IF v.GetSet(set) THEN
						stack.PushSet(set);
						RETURN TRUE
					END;
				END;
			ELSIF type.subclass = sfTypeOpenArray THEN
				CASE type.class OF
				sfTypeCHAR, sfTypeCHAR8:
					IF v IS StringValue THEN
						stack.PushSz(LEN(v(StringValue).value));
						stack.PushA(ADDRESSOF(v(StringValue).value[0])); 
						RETURN TRUE;
					END;
				END;
			END;
			END;
			END;
			RETURN FALSE;
		END Push;
		
		PROCEDURE Check*(): BOOLEAN;
		BEGIN
			RETURN (proc.parameters = NIL) & (index = 0) OR  (index = LEN(proc.parameters));
		END Check;

		PROCEDURE Evaluate(): Value;
		VAR 
			type: Modules.EntryType;
			int: IntegerValue;
			real: RealValue;
			bool: BooleanValue;
			set: SetValue;
			any: AnyValue;
		BEGIN
			type := proc.returnType;
			CASE type.class OF
				sfTypeSHORTINT,sfTypeSIGNED8 : 
					NEW(int, SHORTINT(stack.CallH(address))); 
					RETURN int;
			| sfTypeINTEGER,sfTypeSIGNED16 : 
					NEW(int,  INTEGER(stack.CallH(address))); 
					RETURN int;
			| sfTypeLONGINT,sfTypeSIGNED32: 
					NEW(int,  LONGINT(stack.CallH(address))); 
					RETURN int;
			| sfTypeHUGEINT,sfTypeSIGNED64: 
					NEW(int, stack.CallH(address)); 
					RETURN int;
			|sfTypeREAL:
				 NEW(real, stack.CallR(address)); 
				 RETURN real
			|sfTypeLONGREAL:
				NEW(real, stack.CallX(address));
				RETURN real; 
			|sfTypeBOOLEAN:
				NEW(bool, SYSTEM.VAL(BOOLEAN, stack.CallH(address))); 
				RETURN bool; 
			|sfTypeSET:
				NEW(set,  SYSTEM.VAL(SET, stack.CallH(address))); 
				RETURN set;
			| sfTypeANY, sfTypeOBJECT, sfTypePointerToRecord:  (* pointers are passed as varpars *)
				stack.Call(address);
				RETURN NIL;
			| 0X: 
				stack.Call(address);
				RETURN NIL;
			END;
			RETURN NIL;
		END Evaluate;

	END ProcedureResult;

	FieldResult* = OBJECT (SymbolResult)
	VAR field: Modules.FieldEntry;
		address: ADDRESS;
	
		PROCEDURE & InitField(CONST name: ARRAY OF CHAR; CONST f: Modules.FieldEntry);
		BEGIN
			InitSymbol(name); field := f;
		END InitField;
		
		PROCEDURE Address(): ADDRESS;
		BEGIN
			RETURN address;
		END Address;

		PROCEDURE Evaluate(): Value;
		VAR 
			s: SHORTINT;
			i: INTEGER;
			l: LONGINT;
			h: HUGEINT;
			
			int: IntegerValue;
			a: ANY; 
			any: AnyValue; 
		BEGIN
			CASE field.type.class OF
				sfTypeSHORTINT,sfTypeSIGNED8 : 
					SYSTEM.GET(address, s);
					NEW(int, s); 
					RETURN int;
			| sfTypeINTEGER,sfTypeSIGNED16 : 
					SYSTEM.GET(address, i);
					NEW(int, i); 
					RETURN int;
			| sfTypeLONGINT,sfTypeSIGNED32: 
					SYSTEM.GET(address, l);
					NEW(int, l); 
					RETURN int;
			| sfTypeHUGEINT,sfTypeSIGNED64: 
					SYSTEM.GET(address, h);
					NEW(int,LONGINT(h)); 
					RETURN int;
			| sfTypePointerToRecord, sfTypeANY, sfTypeOBJECT:
				SYSTEM.GET(address, a); 
					NEW(any, a);
					RETURN any;
			ELSE
				HALT(100);
			END;
		END Evaluate;
		
		PROCEDURE SetV(v: Value): BOOLEAN;
		VAR 
			s: SHORTINT; i: INTEGER; l: LONGINT; h: HUGEINT; 
			r: REAL; x: LONGREAL;
			b: BOOLEAN;
			set: SET;
		BEGIN
			CASE field.type.class OF
				sfTypeSHORTINT, sfTypeSIGNED8:
				IF v.GetInt(h) THEN
					s:= SHORTINT(h); SYSTEM.PUT(address, s);
					RETURN TRUE;
				END;
			|sfTypeINTEGER, sfTypeSIGNED16:
				IF v.GetInt(h) THEN
					i:= INTEGER(h); SYSTEM.PUT(address, i);
					RETURN TRUE;
				END;
			|sfTypeLONGINT, sfTypeSIGNED32:
				IF v.GetInt(h) THEN
					l:= LONGINT(h); SYSTEM.PUT(address, l);
					RETURN TRUE;
				END;
			|sfTypeHUGEINT, sfTypeSIGNED64:
				IF v.GetInt(h) THEN
					SYSTEM.PUT(address, h); 
					RETURN TRUE
				END;
			|sfTypeREAL:
				IF v.GetReal(x) THEN
					r := REAL(x); SYSTEM.PUT(address, r);
					RETURN TRUE
				END;
			|sfTypeLONGREAL:
				IF v.GetReal(x) THEN
					SYSTEM.PUT(address,x); 
					RETURN TRUE
				END;
			|sfTypeBOOLEAN:
				IF v.GetBoolean(b) THEN
					SYSTEM.PUT(address,b); 
					RETURN TRUE
				END;
			|sfTypeSET:
				IF v.GetSet(set) THEN
					SYSTEM.PUT(address,set); 
					RETURN TRUE
				END;
			END;
		END SetV;

		PROCEDURE Find(CONST name: ARRAY OF CHAR): Result;
		VAR type, value: ADDRESS;
		VAR typeInfo: Modules.TypeDesc; num: LONGINT;
		proc: ProcedureResult; f: FieldResult;
		BEGIN
			IF (field.type.class = sfTypePointerToRecord)
				OR (field.type.class = sfTypeANY) 
				OR (field.type.class = sfTypeOBJECT)
			 THEN
				SYSTEM.GET(address, value);
				SYSTEM.GET(value-SIZEOF(ADDRESS), type); (*  type desc *)
				RETURN FindInType(SELF, value, type, name);
				(*
				SYSTEM.GET(type-SIZEOF(ADDRESS), typeInfo); (* type info*)
				IF FindProc(typeInfo.procedures, name,num) THEN
					NEW(proc, SELF, name, typeInfo.procedures[num]);
					proc.address := typeInfo.procedures[num].address;
					RETURN proc
				ELSIF FindField(typeInfo.fields, name, num) THEN
					NEW(f, name, typeInfo.fields[num]);
					f.address := value + typeInfo.fields[num].offset;
					RETURN f;
				ELSE HALT(101);
				END;
				*)
			ELSIF field.type.class = sfTypeRecord THEN
				type := field.type.type;
				RETURN FindInType(SELF, address, type, name);
				(*
				SYSTEM.GET(type-SIZEOF(ADDRESS), typeInfo); (* type info*)
				IF FindProc(typeInfo.procedures, name,num) THEN
					NEW(proc, SELF, name, typeInfo.procedures[num]);
					proc.address := typeInfo.procedures[num].address;
					RETURN proc
				ELSIF FindField(typeInfo.fields, name, num) THEN
					NEW(f, name, typeInfo.fields[num]);
					f.address := address + typeInfo.fields[num].offset;
					RETURN f;
				ELSE HALT(101);
				END;
				*)
			ELSE HALT(100); 
			END;
		END Find;
		
	END FieldResult;

	(* traverse types and supertypes for first occurence of symbol name *) 	
	PROCEDURE FindInType(scope: Result; address: ADDRESS; type: ADDRESS; CONST name: ARRAY OF CHAR): Result;
	VAR tag: ADDRESS; typeInfo: Modules.TypeDesc; i, num: LONGINT; 
			proc: ProcedureResult; f: FieldResult;	
	BEGIN
		FOR i := 15 TO 0 BY -1 DO
			SYSTEM.GET(type-(2+i)*SIZEOF(ADDRESS), tag); 
			IF tag # NIL THEN
				SYSTEM.GET(tag-SIZEOF(ADDRESS), typeInfo); 
				IF FindProc(typeInfo.procedures, name,num) THEN
					NEW(proc, scope, name, typeInfo.procedures[num]);
					proc.address := typeInfo.procedures[num].address;
					RETURN proc
				ELSIF FindField(typeInfo.fields, name, num) THEN
					NEW(f, name, typeInfo.fields[num]);
					f.address := address + typeInfo.fields[num].offset;
					RETURN f;
				END;
			END;
		END;
		RETURN NIL; 
	END FindInType;
	
TYPE
	Value*= OBJECT(Result)

		PROCEDURE & InitValue;
		BEGIN InitObject
		END InitValue;

		PROCEDURE Evaluate(): Value;
		BEGIN
			RETURN SELF;
		END Evaluate;
		
		PROCEDURE GetInt*(VAR h: HUGEINT): BOOLEAN;
		BEGIN
			RETURN FALSE;
		END GetInt;

		PROCEDURE GetAddress*(VAR a: ADDRESS): BOOLEAN;
		BEGIN
			RETURN FALSE;
		END GetAddress;
		
		PROCEDURE GetReal*(VAR x: LONGREAL): BOOLEAN;
		BEGIN
			RETURN FALSE;
		END GetReal;

		PROCEDURE GetBoolean*(VAR x: BOOLEAN): BOOLEAN;
		BEGIN
			RETURN FALSE;
		END GetBoolean;

		PROCEDURE GetSet*(VAR x: SET): BOOLEAN;
		BEGIN
			RETURN FALSE;
		END GetSet;

		PROCEDURE GetChar*(VAR x: CHAR): BOOLEAN;
		BEGIN
			RETURN FALSE;
		END GetChar;

		PROCEDURE GetRange*(VAR x: RANGE): BOOLEAN;
		BEGIN
			RETURN FALSE;
		END GetRange;

		PROCEDURE WriteValue*(w: Streams.Writer);
		BEGIN
		END WriteValue;

		PROCEDURE GetString*(VAR w: ARRAY OF CHAR);
		VAR stringWriter: Streams.StringWriter;
		BEGIN
			NEW(stringWriter, 128);
			WriteValue(stringWriter); stringWriter.Update;
			stringWriter.Get(w);
		END GetString;

	END Value;


	CONST StrValue="value";
	TYPE

	AnyValue*=OBJECT(Value)
	VAR value*:ANY;

		PROCEDURE & InitAny*(value: ANY);
		BEGIN InitValue; SELF.value := value; type := "AnyValue";
		END InitAny;

		PROCEDURE Enumerate(enum: PersistentObjects.Enumerator);
		BEGIN Enumerate^(enum); enum(StrValue,FALSE);
		END Enumerate;

		PROCEDURE GetAddress(VAR a: ADDRESS): BOOLEAN;
		BEGIN
			a := value; RETURN TRUE;
		END GetAddress;

		PROCEDURE WriteValue(w: Streams.Writer);
		BEGIN w.Address(value);
		END WriteValue;
		
		PROCEDURE Address(): ADDRESS;
		BEGIN
			RETURN ADDRESSOF(value)
		END Address;
		
		PROCEDURE Find(CONST name: ARRAY OF CHAR): Result;
		VAR type, v, address: ADDRESS;
		VAR typeInfo: Modules.TypeDesc; num: LONGINT;
		proc: ProcedureResult; f: FieldResult;
		BEGIN
			IF value # NIL THEN 
				address := value; 
				SYSTEM.GET(address-SIZEOF(ADDRESS), type); (*  type desc *)
				RETURN FindInType(SELF, address, type, name);
				(*
				SYSTEM.GET(type-SIZEOF(ADDRESS), typeInfo); (* type info*)
				IF FindProc(typeInfo.procedures, name,num) THEN
					NEW(proc, SELF, name, typeInfo.procedures[num]);
					proc.address := typeInfo.procedures[num].address;
					RETURN proc
				ELSIF FindField(typeInfo.fields, name, num) THEN
					NEW(f, name, typeInfo.fields[num]);
					f.address := address + typeInfo.fields[num].offset;
					RETURN f;
				ELSE HALT(101);
				END;
				*)
			ELSE
				RETURN NIL;
			END;
		END Find;

	END AnyValue;

	AddressValue*=OBJECT(Value)
	VAR value*:ADDRESS;

		PROCEDURE & InitAny*(value: ADDRESS);
		BEGIN InitValue; SELF.value := value; type := "AnyValue";
		END InitAny;

		PROCEDURE Enumerate(enum: PersistentObjects.Enumerator);
		BEGIN Enumerate^(enum); enum(StrValue,FALSE);
		END Enumerate;

		PROCEDURE Set(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		VAR int: LONGINT;
		BEGIN
			IF name = StrValue THEN c.GetInteger(int); value := int;
			ELSE Set^(name, index, c);
			END;
		END Set;

		PROCEDURE Get(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		BEGIN
			IF name = StrValue THEN c.SetInteger(value);
			ELSE Get^(name, index, c);
			END;
		END Get;

		PROCEDURE GetAddress(VAR a: ADDRESS): BOOLEAN;
		BEGIN
			a := value; RETURN TRUE;
		END GetAddress;

		PROCEDURE WriteValue(w: Streams.Writer);
		BEGIN w.Address(value);
		END WriteValue;
		
		PROCEDURE Address(): ADDRESS;
		BEGIN
			RETURN ADDRESSOF(value)
		END Address;
		

	END AddressValue;

	IntegerValue*=OBJECT(Value)
	VAR value*: HUGEINT;

		PROCEDURE & InitInteger*(value: HUGEINT);
		BEGIN InitValue; SELF.value := value; type := "IntegerValue";
		END InitInteger;

		PROCEDURE Enumerate(enum: PersistentObjects.Enumerator);
		BEGIN Enumerate^(enum); enum(StrValue,FALSE);
		END Enumerate;

		PROCEDURE Set(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		VAR val: LONGINT;
		BEGIN
			IF name = StrValue THEN c.GetInteger(val); value := val;
			ELSE Set^(name, index, c);
			END;
		END Set;

		PROCEDURE Get(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		BEGIN
			IF name = StrValue THEN c.SetInteger(LONGINT(value));
			ELSE Get^(name, index, c);
			END;
		END Get;
		
		PROCEDURE GetInt(VAR v: HUGEINT): BOOLEAN;
		BEGIN
			v := value; RETURN TRUE;
		END GetInt;

		PROCEDURE GetReal(VAR x: LONGREAL): BOOLEAN;
		BEGIN
			x := value; RETURN TRUE;
		END GetReal;

		PROCEDURE WriteValue(w: Streams.Writer);
		BEGIN w.Int(value,0);
		END WriteValue;

		PROCEDURE Address(): ADDRESS;
		BEGIN
			RETURN ADDRESSOF(value)
		END Address;

	END IntegerValue;

	RealValue*=OBJECT(Value)
	VAR value*: LONGREAL;

		PROCEDURE & InitReal*(value: LONGREAL);
		BEGIN InitValue; SELF.value := value; type := "RealValue";
		END InitReal;

		PROCEDURE Enumerate(enum: PersistentObjects.Enumerator);
		BEGIN Enumerate^(enum); enum(StrValue,FALSE);
		END Enumerate;

		PROCEDURE Set(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		BEGIN
			IF name = StrValue THEN c.GetFloat(value);
			ELSE Set^(name, index, c);
			END;
		END Set;

		PROCEDURE Get(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		BEGIN
			IF name = StrValue THEN c.SetFloat(value);
			ELSE Get^(name, index, c);
			END;
		END Get;
		
		PROCEDURE GetReal(VAR x: LONGREAL): BOOLEAN;
		BEGIN
			x := value; RETURN TRUE; 
		END GetReal;
		
		PROCEDURE WriteValue(w: Streams.Writer);
		BEGIN w.Float(value,40);
		END WriteValue;

		PROCEDURE Address(): ADDRESS;
		BEGIN
			RETURN ADDRESSOF(value)
		END Address;

	END RealValue;

	BooleanValue*=OBJECT(Value)
	VAR value*: BOOLEAN;

		PROCEDURE & InitBoolean*(value: BOOLEAN);
		BEGIN InitValue; SELF.value := value; type := "BooleanValue";
		END InitBoolean;

		PROCEDURE Enumerate(enum: PersistentObjects.Enumerator);
		BEGIN Enumerate^(enum); enum(StrValue,FALSE);
		END Enumerate;

		PROCEDURE Set(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		BEGIN
			IF name = StrValue THEN c.GetBoolean(value);
			ELSE Set^(name, index, c);
			END;
		END Set;

		PROCEDURE Get(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		BEGIN
			IF name = StrValue THEN c.SetBoolean(value);
			ELSE Get^(name, index, c);
			END;
		END Get;

		PROCEDURE GetBoolean(VAR x: BOOLEAN): BOOLEAN;
		BEGIN
			x := value; RETURN TRUE;
		END GetBoolean;


		PROCEDURE WriteValue(w: Streams.Writer);
		BEGIN IF value THEN w.String("TRUE") ELSE w.String("FALSE") END
		END WriteValue;

		PROCEDURE Address(): ADDRESS;
		BEGIN
			RETURN ADDRESSOF(value)
		END Address;

	END BooleanValue;

	StringValue*=OBJECT(Value)
	VAR value*: Strings.String;

		PROCEDURE & InitString*(CONST value: ARRAY OF CHAR);
		BEGIN InitValue; SELF.value := Strings.NewString(value); type := "StringValue";
		END InitString;

		PROCEDURE Enumerate(enum: PersistentObjects.Enumerator);
		BEGIN Enumerate^(enum); enum(StrValue,FALSE);
		END Enumerate;

		PROCEDURE Set(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		BEGIN
			IF name = StrValue THEN c.GetString(value);
			ELSE Set^(name, index, c);
			END;
		END Set;

		PROCEDURE Get(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		BEGIN
			IF name = StrValue THEN c.SetString(value);
			ELSE Get^(name, index, c);
			END;
		END Get;

		PROCEDURE WriteValue(w: Streams.Writer);
		BEGIN (*w.String('"');*) w.String(value^); (*w.String('"');*)
		END WriteValue;

		PROCEDURE Address(): ADDRESS;
		BEGIN
			RETURN value;
		END Address;

	END StringValue;


	SetValue*=OBJECT(Value)
	VAR value*: SET;

		PROCEDURE & InitSet*(value: SET);
		BEGIN InitValue; SELF.value := value; type := "SetValue"
		END InitSet;

		PROCEDURE Enumerate(enum: PersistentObjects.Enumerator);
		BEGIN Enumerate^(enum); enum(StrValue,FALSE);
		END Enumerate;

		PROCEDURE Set(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		BEGIN
			IF name = StrValue THEN c.GetSet(value);
			ELSE Set^(name, index, c);
			END;
		END Set;

		PROCEDURE Get(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		BEGIN
			IF name = StrValue THEN c.SetSet(value);
			ELSE Get^(name, index, c);
			END;
		END Get;
		
		PROCEDURE GetSet(VAR x: SET): BOOLEAN;
		BEGIN
			x:= value; RETURN TRUE;
		END GetSet;

		PROCEDURE WriteValue(w: Streams.Writer);
		BEGIN
			w.Set(value)
		END WriteValue;
		
		PROCEDURE Address(): ADDRESS;
		BEGIN
			RETURN ADDRESSOF(value)
		END Address;

	END SetValue;

	RangeValue*=OBJECT(Value)
	VAR value*: RANGE;

		PROCEDURE & InitRange*(r: RANGE);
		BEGIN InitValue; value := r; type := "RangeValue"
		END InitRange;

		PROCEDURE Enumerate(enum: PersistentObjects.Enumerator);
		BEGIN Enumerate^(enum); enum(StrValue,FALSE);
		END Enumerate;

		PROCEDURE Set(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		BEGIN
			IF name = StrValue THEN c.GetRange(value);
			ELSE Set^(name, index, c);
			END;
		END Set;

		PROCEDURE Get(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		BEGIN
			IF name = StrValue THEN c.SetRange(value);
			ELSE Get^(name, index, c);
			END;
		END Get;		

		PROCEDURE GetRange(VAR x: RANGE): BOOLEAN;
		BEGIN
			x := value; RETURN TRUE; 
		END GetRange;


		PROCEDURE WriteValue(w: Streams.Writer);
		BEGIN
			w.Int(FIRST(value),0); w.String(" .. "); w.Int(LAST(value),0); IF STEP(value) # 1 THEN w.String(" BY "); w.Int(STEP(value),0) END;
		END WriteValue;

		PROCEDURE Address(): ADDRESS;
		BEGIN
			RETURN ADDRESSOF(value)
		END Address;

	END RangeValue;

	CharValue*=OBJECT(Value)
	VAR value: CHAR;

		PROCEDURE & InitChar*(c: CHAR);
		BEGIN InitValue; value := c; type := "CharValue";
		END InitChar;

		PROCEDURE Enumerate(enum: PersistentObjects.Enumerator);
		BEGIN Enumerate^(enum); enum(StrValue,FALSE);
		END Enumerate;

		PROCEDURE Set(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		BEGIN
			IF name = StrValue THEN c.GetChar(value);
			ELSE Set^(name, index, c);
			END;
		END Set;

		PROCEDURE Get(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		BEGIN
			IF name = StrValue THEN c.SetChar(value);
			ELSE Get^(name, index, c);
			END;
		END Get;
		
		PROCEDURE GetChar(VAR c: CHAR): BOOLEAN;
		BEGIN
			c := value; RETURN TRUE; 
		END GetChar;

		PROCEDURE WriteValue(w: Streams.Writer);
		BEGIN
			w.Hex(ORD(value),2); w.String("X");
		END WriteValue;

		PROCEDURE Address(): ADDRESS;
		BEGIN
			RETURN ADDRESSOF(value)
		END Address;

	END CharValue;

	EnumValue*=OBJECT(Value)
	VAR value: LONGINT; translation: PersistentObjects.Translation;

		PROCEDURE & InitEnumValue*(trans: PersistentObjects.Translation; v: LONGINT);
		BEGIN InitValue; value := v;  translation := trans; type := "EnumValue";
		END InitEnumValue;

		PROCEDURE Enumerate(enum: PersistentObjects.Enumerator);
		BEGIN Enumerate^(enum); enum(StrValue,FALSE);
		END Enumerate;

		PROCEDURE Set(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		BEGIN
			IF name = StrValue THEN c.GetEnum(translation, value);
			ELSE Set^(name, index, c);
			END;
		END Set;

		PROCEDURE Get(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		BEGIN
			IF name = StrValue THEN c.SetEnum(translation, value);
			ELSE Get^(name, index, c);
			END;
		END Get;

		PROCEDURE WriteValue(w: Streams.Writer);
		VAR str: ARRAY 32 OF CHAR;
		BEGIN
			IF translation.Name(value, str) THEN w.String(str) ELSE w.String("unknown") END;
		END WriteValue;

		PROCEDURE Address(): ADDRESS;
		BEGIN
			RETURN ADDRESSOF(value)
		END Address;

	END EnumValue;

	MathArrayValue*=OBJECT(Value)
	VAR values: ARRAY [*] OF Value;

		PROCEDURE &InitMathArrayValue*(len: LONGINT);
		BEGIN
			InitValue;
			NEW(values, len);
			type := "MathArrayValue";
		END InitMathArrayValue;

		PROCEDURE Enumerate(enum: PersistentObjects.Enumerator);
		BEGIN Enumerate^(enum); enum(StrValue,FALSE);
		END Enumerate;

		PROCEDURE Set(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		BEGIN
			IF name = StrValue THEN values[index] := ContentGetValue(c)
			ELSE Set^(name, index, c);
			END;
		END Set;

		PROCEDURE Get(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		BEGIN
			IF name = StrValue THEN c.SetObject(values[index],"Value");
			ELSE Get^(name, index, c);
			END;
		END Get;

		PROCEDURE SetValue*(at: LONGINT; value: Value);
		BEGIN
			values[at] := value;
		END SetValue;

		PROCEDURE GetValue*(at: LONGINT): Value;
		BEGIN
			RETURN values[at]
		END GetValue;

		PROCEDURE WriteValue*(w: Streams.Writer);
		VAR i: LONGINT; max: LONGINT;
		BEGIN
			w.String("[ ");
			max := LEN(values,0)-1;
			FOR i := 0 TO max  DO
				values[i].WriteValue(w);
				IF i < max THEN
					w.String(", ");
				END;
			END;
			w.String("] ");
		END WriteValue;


	END MathArrayValue;

	(* object value represented as ANY wrapped in Value ? *)
	Symbol*= OBJECT
	VAR
		name: StringPool.Index;
		item-: Item;

		PROCEDURE & InitSymbol(name: StringPool.Index; index: LONGINT);
		BEGIN
			SELF.name := name; SELF.item := item;
		END InitSymbol;

		PROCEDURE GetName(VAR name: ARRAY OF CHAR);
		BEGIN
			StringPool.GetString(SELF.name, name);
		END GetName;

	END Symbol;

	Container* = OBJECT (Item)
	VAR
		symbols-: Basic.List;
		lookup-: Basic.HashTableInt;

		(* New scope. Note that it is possible that a scope is registered with an alias *)
		PROCEDURE & InitContainer*;
		BEGIN
			InitObject();
			NEW(lookup, 16); NEW(symbols, 16);
			type := "Container";
		END InitContainer;

		PROCEDURE Enumerate(enum: PersistentObjects.Enumerator);
		VAR i: LONGINT; symbol: Symbol; o: ANY; name: ARRAY 256 OF CHAR;
		BEGIN Enumerate^(enum);
			FOR i := 0 TO symbols.Length()-1 DO
				o := symbols.Get(i);
				symbol := o(Symbol);
				symbol.GetName(name);
				enum(name, FALSE);
			END;
		END Enumerate;

		PROCEDURE Set(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		BEGIN
			IF FALSE THEN
			ELSE Set^(name, index, c);
			END;
		END Set;

		PROCEDURE Get(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		VAR item: Item;
		BEGIN
			item := Find(name);
			IF item # NIL THEN c.SetObject(item,"Item")
			ELSE Get^(name, index, c);
			END;
		END Get;

		PROCEDURE GetItem*(index: LONGINT): Item;
		BEGIN
			RETURN symbols.Get(index)(Symbol).item
		END GetItem;


		(* Enter a symbol with its name *)
		PROCEDURE Enter1*(item: Item; name: StringPool.Index);
		VAR any: ANY; symbol: Symbol;
		BEGIN
			any := lookup.Get(name);
			IF any # NIL THEN
				symbol := any(Symbol)
			ELSE
				NEW(symbol, name, symbols.Length());
				symbols.Add(symbol);
				lookup.Put(symbol.name, symbol);
			END;
			symbol.item := item
		END Enter1;

		(* Enter a symbol with its name *)
		PROCEDURE Enter*(item: Item; CONST name: ARRAY OF CHAR);
		BEGIN
			Enter1(item, StringPool.GetIndex1(name))
		END Enter;

		PROCEDURE Find1*(id: LONGINT): Item;
		VAR any: ANY;
		BEGIN
			any := lookup.Get(id);
			IF any # NIL THEN RETURN any(Symbol).item ELSE RETURN NIL END
		END Find1;

		(* Find a symbol with name *)
		PROCEDURE Find*(CONST name: ARRAY OF CHAR): Item;
		BEGIN
			RETURN Find1(StringPool.GetIndex1(name))
		END Find;

	END Container;

	Scope* = OBJECT
	VAR
		outer-: Scope;
		object-: Object;
		level: LONGINT;

		PROCEDURE & InitScope*(outer: Scope; object: Object);
		BEGIN
			SELF.outer := outer;
			IF outer = NIL THEN level := 0 ELSE level := outer.level + 1 END;
			ASSERT(object # NIL);
			SELF.object := object
		END InitScope;

		PROCEDURE Enter*(object: Object): Scope;
		VAR scope: Scope;
		BEGIN
			NEW(scope, SELF, object);
			RETURN scope
		END Enter;

		PROCEDURE FindObject*(CONST name: ARRAY OF CHAR; index: LONGINT; VAR in: Object): Object;
		VAR object: Object;
		BEGIN
			in := SELF.object;
			object := FindInObject(in, name, index);
			IF (object = NIL) & (outer # NIL) THEN
				object := outer.FindObject(name, index, in)
			END;
			RETURN object
		END FindObject;

		PROCEDURE FindObject1*(name: StringPool.Index; index: LONGINT; VAR in: Object): Object;
		VAR str: ARRAY 256 OF CHAR;
		BEGIN
			StringPool.GetString(name, str);
			RETURN FindObject(str,index, in);
		END FindObject1;

		PROCEDURE Leave*(): Scope;
		BEGIN
			RETURN outer
		END Leave;

		PROCEDURE Dump*(log: Streams.Writer);
		BEGIN
			IF object # NIL THEN object.Dump(log,"scope object") END;
			log.Ln;
			IF outer # NIL THEN outer.Dump(log) END;
		END Dump;

	END Scope;


	PROCEDURE Indent(w: Streams.Writer; level: LONGINT);
	BEGIN
		WHILE level> 0 DO w.Char(TAB); DEC(level) END;
	END Indent;

	PROCEDURE Test*(context: Commands.Context);
	VAR scope, inner: Scope; container: Container; integer: IntegerValue; float: RealValue; string: StringValue;
	BEGIN
		NEW(container);
		container.Enter(integer, "integer");
		container.Enter(float,"float");
		container.Enter(string,"string");
		NEW(scope, NIL, container);
		NEW(container);
		inner := scope.Enter(container);
		scope.Dump(context.out);

		(*scope.Write(context.out);*)
	END Test;

	PROCEDURE ContentGetValue(c: Content): Value;
	VAR o: Object;
	BEGIN
		c.GetObject(o); IF o = NIL THEN RETURN NIL ELSE RETURN o(Value) END;
	END ContentGetValue;


	PROCEDURE NewIntegerValue(value: LONGINT): IntegerValue;
	VAR obj: IntegerValue;
	BEGIN
		NEW(obj, value); RETURN obj
	END NewIntegerValue;

	PROCEDURE NewFloatValue(value: LONGREAL): RealValue;
	VAR obj: RealValue;
	BEGIN
		NEW(obj, value); RETURN obj
	END NewFloatValue;

	PROCEDURE NewBooleanValue(value: BOOLEAN): BooleanValue;
	VAR obj: BooleanValue;
	BEGIN
		NEW(obj, value); RETURN obj
	END NewBooleanValue;

	PROCEDURE NewStringValue(CONST value: ARRAY OF CHAR): StringValue;
	VAR obj: StringValue;
	BEGIN
		NEW(obj, value); RETURN obj
	END NewStringValue;

	PROCEDURE NewNameValue(CONST value: ARRAY OF CHAR): StringValue;
	VAR obj: StringValue;
	BEGIN
		NEW(obj, value); RETURN obj
	END NewNameValue;

	PROCEDURE NewRangeValue(value: RANGE): RangeValue;
	VAR obj: RangeValue;
	BEGIN
		NEW(obj, value); RETURN obj
	END NewRangeValue;

	PROCEDURE NewCharValue(value: CHAR): CharValue;
	VAR obj: CharValue;
	BEGIN
		NEW(obj, value); RETURN obj
	END NewCharValue;

	PROCEDURE NewSetValue(value: SET): SetValue;
	VAR obj: SetValue;
	BEGIN
		NEW(obj, value); RETURN obj
	END NewSetValue;

	PROCEDURE NewEnumValue(translation: PersistentObjects.Translation; value: LONGINT): EnumValue;
	VAR obj: EnumValue;
	BEGIN
		NEW(obj, translation, value);
	END NewEnumValue;

	PROCEDURE FindInObject*(in: Object; CONST name: ARRAY OF CHAR; index: LONGINT): Object;
	VAR content: Content;
	TYPE Class=PersistentObjects.Class;
	BEGIN
		NEW(content);
		in.Get(name, index, content);
		IF content.success THEN
			CASE content.class OF
				|Class.String: RETURN NewStringValue(content.string^);
				|Class.Object: RETURN content.object
				|Class.Name: RETURN NewNameValue(content.name);
				|Class.Boolean: RETURN NewBooleanValue(content.boolean);
				|Class.Integer: RETURN NewIntegerValue(content.integer);
				|Class.Float: RETURN NewFloatValue(content.float);
				|Class.Enum: RETURN NewEnumValue(content.translation,content.integer)
				|Class.Range: RETURN NewRangeValue(content.range)
				|Class.Set: RETURN NewSetValue(content.set)
				|Class.Char: RETURN NewCharValue(content.char)
			END
		END;
		RETURN NIL
	END FindInObject;

	TYPE
	ObjectFilter* = OBJECT
	VAR
		content: Content;
		object: Object;
		found: Container;
		attribute, value: ARRAY 256 OF CHAR;

		PROCEDURE & InitObjectFilter*;
		BEGIN
			NEW(content); NEW(found);
		END InitObjectFilter;

		PROCEDURE AddFiltered(obj: Object);
		BEGIN
			IF obj # NIL THEN
				obj.Get(attribute, -1, content);
				IF content.success & content.Equals(value) THEN
					found.Enter(obj,"any");
				END;
			END;
		END AddFiltered;

		PROCEDURE Enumerate(CONST name: ARRAY OF CHAR; array: BOOLEAN);
		VAR obj: Object; index: LONGINT;
		BEGIN
			object.Get(name,-1, content);
			IF content.success & (content.class = PersistentObjects.Class.Object) THEN
				IF array THEN
					index := 0;
					REPEAT
						object.Get(name, index, content);
						obj := content.object;
						AddFiltered(obj);
						INC(index);
					UNTIL obj = NIL;
				ELSE
					AddFiltered(content.object)
				END;
			END;
		END Enumerate;

		PROCEDURE Filter*(obj: Object; attribute, value: ARRAY OF CHAR): Container;
		BEGIN
			NEW(found);
			object := obj;
			COPY(attribute, SELF.attribute);
			COPY(value, SELF.value);
			obj.Enumerate(Enumerate);
			RETURN found
		END Filter;

	END ObjectFilter;


			
	PROCEDURE FindType(CONST types: POINTER TO ARRAY OF Modules.TypeDesc; CONST name: ARRAY OF CHAR): Modules.TypeDesc;
	VAR i: LONGINT;
	BEGIN
		IF types = NIL THEN RETURN NIL END;
		FOR i := 0 TO LEN(types)-1 DO
			IF types[i].name = name THEN 
				RETURN types[i];
			END;
		END;
		RETURN NIL;
	END FindType;
	
	PROCEDURE FindField(CONST types: POINTER TO ARRAY OF Modules.FieldEntry; CONST name: ARRAY OF CHAR; VAR num: LONGINT): BOOLEAN;
	BEGIN
		IF types = NIL THEN RETURN FALSE END;
		FOR num := 0 TO LEN(types)-1 DO
			IF types[num].name^ = name THEN 
				RETURN TRUE;
			END;
		END;
		RETURN FALSE;
	END FindField;

	PROCEDURE FindProc(CONST types: POINTER TO ARRAY OF Modules.ProcedureEntry; CONST name: ARRAY OF CHAR; VAR num: LONGINT): BOOLEAN;
	BEGIN
		IF types = NIL THEN RETURN FALSE END;
		FOR num := 0 TO LEN(types)-1 DO
			IF types[num].name^ = name THEN 
				RETURN TRUE;
			END;
		END;
		RETURN FALSE;
	END FindProc;
	
	PROCEDURE GetModule*(CONST name: ARRAY OF CHAR): ModuleResult;
	VAR msg: ARRAY 128 OF CHAR; res: LONGINT; mod:ModuleResult; m: Modules.Module;
	BEGIN
		m := Modules.ThisModule(name, res, msg);
		IF m # NIL THEN 
			NEW(mod, name, m);
		ELSE
			mod := NIL;
		END;
		RETURN mod;
	END GetModule;

	PROCEDURE FindInObject1*(in: Object; name: StringPool.Index; index: LONGINT): Object;
	VAR str: ARRAY 256 OF CHAR;
	BEGIN
		StringPool.GetString(name, str);
		RETURN FindInObject(in,str,index);
	END FindInObject1;

END FoxInterpreterSymbols.

SystemTools.FreeDownTo FoxInterpreterSymbols ~
FoxInterpreterSymbols.Test ~
