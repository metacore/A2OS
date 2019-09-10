MODULE FoxBasic;   (**  AUTHOR "fof"; PURPOSE "Oberon Compiler: basic helpers: strings, lists, hash tables, graphs, indented writer";  **)
(* (c) fof ETH Zürich, 2009 *)

IMPORT KernelLog, StringPool, Strings, Streams, Diagnostics, Files, SYSTEM, ObjectFile, Modules, D:= Debugging;

CONST
	(* error numbers *)
	(* first 255 tokens reserved for expected symbol error message *)
	UndeclaredIdentifier* = 256;
	MultiplyDefinedIdentifier* = 257;
	NumberIllegalCharacter* = 258;
	StringIllegalCharacter* = 259;
	NoMatchProcedureName* = 260;
	CommentNotClosed* = 261;
	IllegalCharacterValue* = 262;
	ValueStartIncorrectSymbol* = 263;
	IllegalyMarkedIdentifier* = 264;
	IdentifierNoType* = 265;
	IdentifierNoRecordType* = 266;
	IdentifierNoObjectType* = 267;
	ImportNotAvailable* = 268;
	RecursiveTypeDeclaration* = 269;
	NumberTooLarge* = 270;
	IdentifierTooLong* = 271;
	StringTooLong* = 272;

	InitErrMsgSize = 300;	(* initial size of array of error messages *)

	invalidString* = -1;
	InvalidCode* = -1;
TYPE
	(*
	String* = POINTER TO ARRAY OF CHAR;
	*)
	String* = StringPool.Index;
	SegmentedName*= ObjectFile.SegmentedName;
	FileName*= Files.FileName;
	SectionName*= ARRAY 256 OF CHAR;
	MessageString*= ARRAY 256 OF CHAR;

	Integer* = SIGNED64;
	Set* = SET64;
	Real*= FLOAT64;

	ObjectArray = POINTER TO ARRAY OF ANY;

	ErrorMsgs = POINTER TO ARRAY OF StringPool.Index;

	ComparisonFunction = PROCEDURE {DELEGATE} (object1, object2: ANY): BOOLEAN;

	Position*= RECORD
		start*, end*, line*, linepos*: Streams.Position;
		reader*: Streams.Reader;
	END;

	ErrorCode* = INTEGER;

	Fingerprint* = ObjectFile.Fingerprint;

	List* = OBJECT  (* by Luc Bläser *)
	VAR
		list: ObjectArray;
		count-: SIZE;
		multipleAllowed*: BOOLEAN;
		nilAllowed*: BOOLEAN;

		PROCEDURE & InitList*(initialSize: SIZE) ;
		BEGIN
			IF initialSize <= 0 THEN initialSize := 8 END;
			INC( lists );  NEW( list, initialSize );  count := 0;  multipleAllowed := FALSE;  nilAllowed := FALSE
		END InitList;

		PROCEDURE Length*( ): SIZE;
		BEGIN
			RETURN count
		END Length;

		PROCEDURE Grow;
		VAR old: ObjectArray;  i: SIZE;
		BEGIN
			INC( enlarged );  old := list;  NEW( list, (LEN( list ) * 3+1) DIV 2 (* more optimal for first-fit memory allocators *) ) ;
			FOR i := 0 TO count - 1 DO list[i] := old[i] END
		END Grow;

		PROCEDURE Get*( i: SIZE ): ANY;
		BEGIN
			IF (i < 0) OR (i >= count) THEN HALT( 101 ) END;
			RETURN list[i]
		END Get;

		PROCEDURE Set*(i: SIZE; x: ANY);
		BEGIN
			IF (i < 0) OR (i >= count) THEN HALT( 101 ) END;
			list[i] := x;
		END Set;

		PROCEDURE Add*( x: ANY );
		BEGIN
			IF ~nilAllowed THEN ASSERT( x # NIL ) END;
			IF ~multipleAllowed THEN ASSERT( ~debug OR ~Contains( x ) ) END;   (* already contained *)
			IF count = LEN( list ) THEN Grow END;
			list[count] := x;  INC( count )
		END Add;

		PROCEDURE Prepend*(x: ANY);
		VAR i: SIZE;
		BEGIN
			IF ~nilAllowed THEN ASSERT( x # NIL ) END;
			IF ~multipleAllowed THEN ASSERT( debug OR ~Contains( x ) ) END;   (* already contained *)
			IF count = LEN( list ) THEN Grow END;

			FOR i := count-1  TO 0 BY - 1 DO
				list[i+1] := list[i];
			END;
			list[0] := x; INC(count);
		END Prepend;

		PROCEDURE Append*(x: List);
		VAR i: SIZE;
		BEGIN
			FOR i := 0 TO x.Length() - 1 DO
				IF multipleAllowed OR (~debug OR ~Contains(x.Get(i))) THEN
					Add(x.Get(i));
				END;
			END;
		END Append;

		PROCEDURE Remove*( x: ANY );
		VAR i: SIZE;
		BEGIN
			i := 0;
			WHILE (i < count) & (list[i] # x) DO INC( i ) END;
			IF i < count THEN
				WHILE (i < count - 1) DO list[i] := list[i + 1];  INC( i ) END;
				DEC( count );  list[count] := NIL
			END
		END Remove;

		PROCEDURE RemoveByIndex*( i: SIZE );
		BEGIN
			IF i < count THEN
				WHILE (i < count - 1) DO list[i] := list[i + 1];  INC( i ) END;
				DEC( count );  list[count] := NIL
			END
		END RemoveByIndex;

		PROCEDURE Insert*( i: SIZE; x: ANY );
		VAR j: SIZE;
		BEGIN
			IF ~nilAllowed THEN ASSERT( x # NIL ) END;
			IF ~multipleAllowed THEN ASSERT( ~debug OR ~Contains( x ) ) END;   (* already contained *)

			IF count = LEN( list ) THEN Grow END; INC( count );

			j := count - 2;
			WHILE (j >= i) DO list[j+1] := list[j]; DEC( j ) END;
			list[i] := x;
		END Insert;

		PROCEDURE Replace*( x, y: ANY );
		VAR i: SIZE;
		BEGIN
			IF ~nilAllowed THEN ASSERT( x # NIL );  ASSERT( y # NIL ) END;
			i := IndexOf( x );
			IF i >= 0 THEN list[i] := y END
		END Replace;

		PROCEDURE ReplaceByIndex*( i: SIZE;  x: ANY );
		BEGIN
			IF ~nilAllowed THEN ASSERT( x # NIL ) END;
			IF (i >= 0) & (i < count) THEN list[i] := x
					ELSE HALT( 101 ) (* out of boundaries *)
			END
		END ReplaceByIndex;

		(** If the object is not present, -1 is returned *)
		PROCEDURE IndexOf*( x: ANY ): SIZE;
		VAR i: SIZE;
		BEGIN
			i := 0;
			WHILE i < count DO
				IF list[i] = x THEN RETURN i END;
				INC( i )
			END;
			RETURN -1
		END IndexOf;

		PROCEDURE Contains*( x: ANY ): BOOLEAN;
		BEGIN
			RETURN IndexOf( x ) # -1
		END Contains;

		PROCEDURE Clear*;
		VAR i: SIZE;
		BEGIN
			FOR i := 0 TO count - 1 DO list[i] := NIL END;
			count := 0
		END Clear;

		PROCEDURE GrowAndSet*(i: SIZE; x: ANY);
		BEGIN
			IF (i<0) THEN HALT(101) END;
			WHILE i>=LEN(list) DO Grow END;
			list[i] := x;
			INC(i); IF count < i THEN count := i END;
		END GrowAndSet;

		PROCEDURE Sort*(comparisonFunction: ComparisonFunction);
		BEGIN
			IF count > 0 THEN
				QuickSort(comparisonFunction, 0, count - 1)
			END
		END Sort;

		PROCEDURE QuickSort(comparisonFunction: ComparisonFunction; lo, hi: SIZE);
		VAR
			i, j: SIZE;
			x, t: ANY;
		BEGIN
			i := lo; j := hi;
			x := list[(lo + hi) DIV 2];

			WHILE i <= j DO
				WHILE comparisonFunction(list[i], x) DO INC(i) END;
				WHILE comparisonFunction(x, list[j]) DO DEC(j) END;

				IF i <= j THEN
					(*IF (i < j) & comparisonFunction(list[j], list[i]) THEN*)
						t := list[i]; list[i] := list[j]; list[j] := t; (* swap i and j *)
					(*END;*)

					INC(i); DEC(j)
				END
			END;

			IF lo < j THEN QuickSort(comparisonFunction, lo, j) END;
			IF i < hi THEN QuickSort(comparisonFunction, i, hi) END
		END QuickSort;
	END List;

	HashEntryAny = RECORD
		key, value: ANY;
		valueInt: SIZE;
	END;

	HashEntryInt = RECORD
		key, valueInt: SIZE;
		value: ANY;
	END;

	HashAnyArray = POINTER TO ARRAY OF HashEntryAny;
	HashIntArray = POINTER TO ARRAY OF HashEntryInt;

	HashTable* = OBJECT
	VAR
		table: HashAnyArray;
		size: SIZE;
		used-: SIZE;
		maxLoadFactor: FLOAT32;

		(* Interface *)

		PROCEDURE & Init* (initialSize: SIZE);
		BEGIN
			ASSERT(initialSize > 2);
			NEW(table, initialSize);
			size := initialSize;
			used := 0;
			maxLoadFactor := 0.75;
		END Init;

		PROCEDURE Put*(key, value: ANY);
		VAR hash: SIZE;
		BEGIN
			ASSERT(used < size);
			ASSERT(key # NIL);
			hash := HashValue(key);
			IF table[hash].key = NIL THEN
				INC(used, 1);
			ELSE
				ASSERT(table[hash].key = key);
			END;
			table[hash].key := key;
			table[hash].value := value;

			IF (used / size) > maxLoadFactor THEN Grow END;
		END Put;

		PROCEDURE Get*(key: ANY):ANY;
		BEGIN
			RETURN table[HashValue(key)].value;
		END Get;

		PROCEDURE Has*(key: ANY):BOOLEAN;
		BEGIN
			RETURN table[HashValue(key)].key = key;
		END Has;

		PROCEDURE Length*(): SIZE;
		BEGIN
			RETURN used;
		END Length;

		PROCEDURE Clear*;
		VAR i: SIZE;
		BEGIN
			FOR i := 0 TO size - 1 DO table[i].key := NIL; table[i].value := NIL; table[i].valueInt := 0 END;
		END Clear;

		(* Interface for integer values *)

		PROCEDURE PutInt*(key: ANY; value: SIZE);
		VAR hash: SIZE;
		BEGIN
			ASSERT(used < size);
			hash := HashValue(key);
			IF table[hash].key = NIL THEN
				INC(used, 1);
			END;
			table[hash].key := key;
			table[hash].valueInt := value;
			IF (used / size) > maxLoadFactor THEN Grow END;
		END PutInt;

		PROCEDURE GetInt*(key: ANY):SIZE;
		BEGIN
			RETURN table[HashValue(key)].valueInt;
		END GetInt;

		(* Internals *)

		(* only correctly working, if NIL key cannot be entered *)
		PROCEDURE HashValue(key: ANY): SIZE;
		VAR value, h1, h2, i: SIZE;
		BEGIN
			value := SYSTEM.VAL(SIZE, key) DIV SIZEOF(ADDRESS);
			i := 0;
			h1 := value MOD size;
			h2 := 1; (* Linear probing *)
			REPEAT
				value := (h1 + i*h2) MOD size;
				INC(i);
			UNTIL((table[value].key = NIL) OR (table[value].key = key) OR (i > size));
			ASSERT((table[value].key = NIL) & (table[value].value = NIL) OR (table[value].key = key));
			RETURN value;
		END HashValue;

		PROCEDURE Grow;
		VAR oldTable: HashAnyArray; oldSize, i: SIZE; key: ANY;
		BEGIN
			oldSize := size;
			oldTable := table;
			Init(size*2);
			FOR i := 0 TO oldSize-1 DO
				key := oldTable[i].key;
				IF key # NIL THEN
					IF oldTable[i].value # NIL THEN
						Put(key, oldTable[i].value);
					ELSE
						PutInt(key, oldTable[i].valueInt);
					END;
				END;
			END;
		END Grow;

	END HashTable;

	IntIterator*= OBJECT
	VAR
		table: HashIntArray;
		count : SIZE;

		PROCEDURE & Init(t: HashIntArray);
		BEGIN
			table := t;
			count := -1;
		END Init;

		PROCEDURE GetNext*(VAR key: SIZE; VAR value: ANY): BOOLEAN;
		BEGIN
			REPEAT
				INC(count);
			UNTIL (count = LEN(table)) OR (table[count].value # NIL);
			IF count = LEN(table) THEN
				RETURN FALSE
			END;
			key := table[count].key;
			value := table[count].value;
			RETURN TRUE;
		END GetNext;

	END IntIterator;

	HashTableInt* = OBJECT
	VAR
		table: HashIntArray;
		size: SIZE;
		used-: SIZE;
		maxLoadFactor: FLOAT32;

		(* Interface *)

		PROCEDURE & Init* (initialSize: SIZE);
		BEGIN
			ASSERT(initialSize > 2);
			NEW(table, initialSize);
			size := initialSize;
			used := 0;
			maxLoadFactor := 0.75;
		END Init;

		PROCEDURE Put*(key: SIZE; value: ANY);
		VAR hash: SIZE;
		BEGIN
			ASSERT(key # 0);
			ASSERT(used < size);
			hash := HashValue(key);
			IF table[hash].key = 0 THEN
				INC(used, 1);
			END;
			table[hash].key := key;
			table[hash].value := value;
			IF (used / size) > maxLoadFactor THEN Grow END;
		END Put;

		PROCEDURE Get*(key: SIZE):ANY;
		BEGIN
			RETURN table[HashValue(key)].value;
		END Get;

		PROCEDURE Has*(key: SIZE):BOOLEAN;
		BEGIN
			RETURN table[HashValue(key)].key = key;
		END Has;

		PROCEDURE Length*(): SIZE;
		BEGIN
			RETURN used;
		END Length;

		PROCEDURE Clear*;
		VAR i: SIZE;
		BEGIN
			FOR i := 0 TO size - 1 DO table[i].key := 0; END;
		END Clear;

		(* Interface for integer values *)

		PROCEDURE PutInt*(key, value: SIZE);
		VAR hash: SIZE;
		BEGIN
			(*ASSERT(key # 0);*)
			ASSERT(used < size);
			hash := HashValue(key);
			IF table[hash].key = 0 THEN
				INC(used, 1);
			END;
			table[hash].key := key;
			table[hash].valueInt := value;
			IF (used / size) > maxLoadFactor THEN Grow END;
		END PutInt;

		PROCEDURE GetInt*(key: SIZE): SIZE;
		BEGIN
			RETURN table[HashValue(key)].valueInt;
		END GetInt;

		(* Internals *)

		PROCEDURE HashValue(key: SIZE): SIZE;
		VAR value, h1, h2, i: SIZE;
		BEGIN
			i := 0;
			value := key;
			h1 := key MOD size;
			h2 := 1; (* Linear probing *)
			REPEAT
				value := (h1 + i*h2) MOD size;
				INC(i);
			UNTIL((table[value].key = 0) OR (table[value].key = key) OR (i > size));
			ASSERT((table[value].key = 0) OR (table[value].key = key));
			RETURN value;
		END HashValue;

		PROCEDURE Grow;
		VAR oldTable: HashIntArray; oldSize, i, key: SIZE;
		BEGIN
			oldSize := size;
			oldTable := table;
			Init(size*2);
			FOR i := 0 TO oldSize-1 DO
				key := oldTable[i].key;
				IF key # 0 THEN
					IF oldTable[i].value # NIL THEN
						Put(key, oldTable[i].value);
					ELSE
						PutInt(key, oldTable[i].valueInt);
					END;
				END;
			END;
		END Grow;

		PROCEDURE GetIterator*(): IntIterator;
		VAR iterator: IntIterator;
		BEGIN
			NEW(iterator, table);
			RETURN iterator;
		END GetIterator;

	END HashTableInt;

	HashEntrySegmentedName = RECORD
		key: ObjectFile.SegmentedName; (* key[0]= MIN(SIGNED32) <=> empty *)
		value: ANY;
	END;
	HashSegmentedNameArray = POINTER TO ARRAY OF HashEntrySegmentedName;

	HashTableSegmentedName* = OBJECT
	VAR
		table: HashSegmentedNameArray;
		size: SIZE;
		used-: SIZE;
		maxLoadFactor: FLOAT32;

		(* Interface *)

		PROCEDURE & Init* (initialSize: SIZE);
		BEGIN
			ASSERT(initialSize > 2);
			NEW(table, initialSize);
			size := initialSize;
			used := 0;
			maxLoadFactor := 0.75;
			Clear;
		END Init;

		PROCEDURE Put*(CONST key: SegmentedName; value: ANY);
		VAR hash: SIZE;
		BEGIN
			ASSERT(used < size);
			hash := HashValue(key);
			IF table[hash].key[0] < 0 THEN
				INC(used, 1);
			END;
			table[hash].key := key;
			table[hash].value := value;
			IF (used / size) > maxLoadFactor THEN Grow END;
		END Put;

		PROCEDURE Get*(CONST key: SegmentedName):ANY;
		BEGIN
			RETURN table[HashValue(key)].value;
		END Get;

		PROCEDURE Has*(CONST key: SegmentedName):BOOLEAN;
		BEGIN
			RETURN table[HashValue(key)].key = key;
		END Has;

		PROCEDURE Length*(): SIZE;
		BEGIN
			RETURN used;
		END Length;

		PROCEDURE Clear*;
		VAR i: SIZE;
		BEGIN
			FOR i := 0 TO size - 1 DO table[i].key[0] := -1; END;
		END Clear;

		(* Internals *)
		PROCEDURE Hash*(CONST name: SegmentedName): SIZE;
		VAR fp, i: SIZE;
		BEGIN
			fp := name[0]; i := 1;
			WHILE (i<LEN(name)) & (name[i] >= 0) DO
				fp:=SYSTEM.VAL(SIZE, SYSTEM.VAL(SET, ROT(fp, 7)) / SYSTEM.VAL(SET, name[i]));
				INC(i);
			END;
			RETURN fp
		END Hash;

		PROCEDURE HashValue(CONST key: SegmentedName): SIZE;
		VAR value, h, i: SIZE;
		BEGIN
			ASSERT(key[0] >= 0);
			h := Hash(key);
			i := 0;
			REPEAT
				value := (h + i) MOD size;
				INC(i);
			UNTIL((table[value].key[0] < 0) OR (table[value].key = key) OR (i > size));
			ASSERT((table[value].key[0] <0 ) OR (table[value].key = key));
			RETURN value;
		END HashValue;

		PROCEDURE Grow;
		VAR oldTable: HashSegmentedNameArray; oldSize, i: SIZE; key: SegmentedName;
		BEGIN
			oldSize := size;
			oldTable := table;
			Init(size*2);
			FOR i := 0 TO oldSize-1 DO
				key := oldTable[i].key;
				IF key[0] # MIN(SIGNED32) THEN
					IF oldTable[i].value # NIL THEN
						Put(key, oldTable[i].value);
					END;
				END;
			END;
		END Grow;

	END HashTableSegmentedName;

	IntegerObject = OBJECT
	END IntegerObject;

	Writer* = OBJECT (Streams.Writer)
	VAR
		indent-: SIGNED32;
		doindent: BOOLEAN;
		w-: Streams.Writer;

		PROCEDURE InitBasicWriter*( w: Streams.Writer );
		BEGIN
			SELF.w := w; indent := 0; doindent := TRUE;
		END InitBasicWriter;

		PROCEDURE & InitW(w: Streams.Writer); (* protect against use of NEW *)
		BEGIN InitBasicWriter(w);
		END InitW;

		PROCEDURE Reset*;
		BEGIN w.Reset;
		END Reset;

		PROCEDURE CanSetPos*( ): BOOLEAN;
		BEGIN RETURN w.CanSetPos();
		END CanSetPos;

		PROCEDURE SetPos*( pos: Streams.Position );
		BEGIN w.SetPos(pos);
		END SetPos;

		PROCEDURE Update*;
		BEGIN w.Update;
		END Update;

		PROCEDURE Pos*( ): Streams.Position;
		BEGIN RETURN w.Pos()
		END Pos;

		PROCEDURE Indent;
		VAR i: SIGNED32;
		BEGIN
			IF doindent THEN
				FOR i := 0 TO indent-1 DO
					w.Char(9X);
				END;
				doindent := FALSE
			END;
		END Indent;

		PROCEDURE Char*( x: CHAR );
		BEGIN Indent; w.Char(x);
		END Char;

		PROCEDURE Bytes*(CONST x: ARRAY OF CHAR;  ofs, len: SIZE );
		BEGIN  w.Bytes(x,ofs,len);
		END Bytes;

		PROCEDURE RawSInt*( x: SIGNED8 );
		BEGIN  w.RawSInt(x)
		END RawSInt;

		PROCEDURE RawInt*( x: SIGNED16 );
		BEGIN  w.RawInt(x)
		END RawInt;

		PROCEDURE RawLInt*( x: SIGNED32 );
		BEGIN  w.RawLInt(x)
		END RawLInt;

		PROCEDURE RawHInt*( x: SIGNED64 );
		BEGIN  w.RawHInt(x)
		END RawHInt;

		PROCEDURE Net32*( x: SIGNED32 );
		BEGIN  w.Net32(x)
		END Net32;

		PROCEDURE Net16*( x: SIGNED32 );
		BEGIN  w.Net16(x)
		END Net16;

		PROCEDURE Net8*( x: SIGNED32 );
		BEGIN  w.Net8(x)
		END Net8;

		PROCEDURE RawSet*( x: SET );
		BEGIN  w.RawSet(x)
		END RawSet;

		PROCEDURE RawBool*( x: BOOLEAN );
		BEGIN  w.RawBool(x)
		END RawBool;

		PROCEDURE RawReal*( x: FLOAT32 );
		BEGIN  w.RawReal(x)
		END RawReal;

		PROCEDURE RawLReal*( x: Real );
		BEGIN  w.RawLReal(x)
		END RawLReal;

		PROCEDURE RawString*(CONST x: ARRAY OF CHAR );
		BEGIN  w.RawString(x)
		END RawString;

		PROCEDURE RawNum*( x: SIGNED64 );
		BEGIN  w.RawNum(x)
		END RawNum;

		PROCEDURE Ln*;
		BEGIN w.Ln; doindent := TRUE;
		END Ln;

		PROCEDURE String*(CONST x: ARRAY OF CHAR );
		BEGIN Indent; w.String(x)
		END String;

		PROCEDURE Int*( x: SIGNED64; wd: SIZE );
		BEGIN Indent; w.Int(x,wd)
		END Int;

		PROCEDURE Set*( s: SET );   (* from P. Saladin *)
		BEGIN Indent; w.Set(s)
		END Set;

		PROCEDURE Hex*(x: SIGNED64; wd: SIZE );
		BEGIN Indent; w.Hex(x,wd)
		END Hex;

		PROCEDURE Address* (x: ADDRESS);
		BEGIN Indent; w.Address(x)
		END Address;

		PROCEDURE Date*( t, d: SIGNED32 );
		BEGIN Indent; w.Date(t,d)
		END Date;

		PROCEDURE Date822*( t, d, tz: SIGNED32 );
		BEGIN Indent; w.Date822(t,d,tz)
		END Date822;

		PROCEDURE Float*( x: Real;  n: SIGNED32 );
		BEGIN Indent; w.Float(x,n)
		END Float;

		PROCEDURE FloatFix*( x: Real;  n, f, D: SIGNED32 );
		BEGIN Indent; w.FloatFix(x,n,f,D)
		END FloatFix;

		PROCEDURE SetIndent*(i: SIGNED32);
		BEGIN
			indent := i
		END SetIndent;

		PROCEDURE IncIndent*;
		BEGIN INC(indent)
		END IncIndent;

		PROCEDURE DecIndent*;
		BEGIN DEC(indent)
		END DecIndent;

		PROCEDURE BeginAlert*;
		END BeginAlert;

		PROCEDURE EndAlert*;
		END EndAlert;

		PROCEDURE BeginKeyword*;
		BEGIN
		END BeginKeyword;

		PROCEDURE EndKeyword*;
		BEGIN
		END EndKeyword;

		PROCEDURE BeginComment*;
		END BeginComment;

		PROCEDURE EndComment*;
		END EndComment;

		PROCEDURE AlertString*(CONST s: ARRAY OF CHAR);
		BEGIN
			BeginAlert; w.String(s); EndAlert;
		END AlertString;

	END Writer;

	TracingDiagnostics = OBJECT (Diagnostics.Diagnostics)
	VAR diagnostics: Diagnostics.Diagnostics;

		PROCEDURE &InitDiagnostics(diagnostics: Diagnostics.Diagnostics);
		BEGIN
			SELF.diagnostics := diagnostics
		END InitDiagnostics;

		PROCEDURE Error*(CONST source: ARRAY OF CHAR; position: Streams.Position; CONST message : ARRAY OF CHAR);
		BEGIN
			IF diagnostics # NIL THEN
				diagnostics.Error(source,position,message);
			END;
			D.Ln;
			D.String(" ---------------------- TRACE for COMPILER ERROR  < ");
			D.String(source);
			IF position # Streams.Invalid THEN D.String("@"); D.Int(position,1) END;
			D.String(" "); D.String(message);
			D.String(" > ---------------------- ");
			D.TraceBack
		END Error;

		PROCEDURE Warning*(CONST source : ARRAY OF CHAR; position: Streams.Position; CONST message : ARRAY OF CHAR);
		BEGIN
			IF diagnostics # NIL THEN
				diagnostics.Warning(source,position,message);
			END;
		END Warning;

		PROCEDURE Information*(CONST source : ARRAY OF CHAR; position: Streams.Position; CONST message : ARRAY OF CHAR);
		BEGIN
			IF diagnostics # NIL THEN
				diagnostics.Information(source,position,message);
			END;
		END Information;

	END TracingDiagnostics;

	DebugWriterFactory*= PROCEDURE{DELEGATE} (CONST title: ARRAY OF CHAR): Streams.Writer;
	WriterFactory*=PROCEDURE{DELEGATE} (w: Streams.Writer): Writer;
	DiagnosticsFactory*=PROCEDURE{DELEGATE} (w: Streams.Writer): Diagnostics.Diagnostics;

VAR
	lists-: SIZE;  enlarged-: SIZE;  strings-: SIZE; integerObjects: HashTableInt;
	errMsg: ErrorMsgs;	(*error messages*)
	emptyString-: String;
	debug: BOOLEAN;
	getDebugWriter: DebugWriterFactory;
	getWriter: WriterFactory;
	getDiagnostics: DiagnosticsFactory;
	invalidPosition-: Position;

	(* Make a string out of a series of characters. *)
	PROCEDURE MakeString*( CONST s: ARRAY OF CHAR ): String;
	(* VAR str: String;  *)
	BEGIN
		INC( strings );
		(*
		(* allocation based *)
		NEW( str, Strings.Length( s ) +1);  COPY( s, str^ );  RETURN str;
		*)
		RETURN StringPool.GetIndex1( s )
	END MakeString;

	PROCEDURE GetString*(s: String; VAR str: ARRAY OF CHAR);
	BEGIN
		StringPool.GetString(s,str);
	END GetString;

	PROCEDURE StringEqual*( s, t: String ): BOOLEAN;
	BEGIN
		RETURN s = t;
		(*
		(* allocation based *)
		RETURN s^ = t^
		*)
	END StringEqual;

	PROCEDURE GetErrorMessage*(err: ErrorCode; CONST msg: ARRAY OF CHAR; VAR res: ARRAY OF CHAR);
	VAR str: ARRAY 128 OF CHAR;
	BEGIN
		res := "";
		IF (errMsg # NIL) & (0 <= err) & (err < LEN(errMsg)) THEN
			StringPool.GetString(errMsg[err], str);
			Strings.Append(res,str);
			Strings.Append(res, " ");
		END;
		Strings.Append(res, msg);
        Strings.Append(res, ". ");
	END GetErrorMessage;

	PROCEDURE AppendDetailedErrorMessage*(VAR message: ARRAY OF CHAR; pos: Position; reader: Streams.Reader);
    VAR err: ARRAY 512 OF CHAR; ch: CHAR; oldpos: Streams.Position;
    BEGIN
        IF (reader # NIL) & (reader.CanSetPos()) THEN
            oldpos := reader.Pos();
            reader.SetPos(pos.linepos);
            reader.Char(ch);
            (* read until end of source line *)
            WHILE (ch # 0X) & (ch # 0AX) & (ch # 0DX) DO
                Strings.AppendChar(err, ch);
                IF reader.Pos() = pos.start THEN
                    Strings.Append(err,"(*!*)");
                END;
                reader.Char(ch);
            END;
            reader.SetPos(oldpos);
        END;
        Strings.TrimWS(err);
        Strings.Append(message, err);
    END AppendDetailedErrorMessage;

	PROCEDURE AppendPosition*(VAR msg: ARRAY OF CHAR; pos: Position);
	BEGIN
		IF pos.line >= 0 THEN
			Strings.Append(msg, " in line ");
			Strings.AppendInt(msg, pos.line);
			Strings.Append(msg, ", col ");
			Strings.AppendInt(msg, pos.start- pos.linepos);
		END;
	END AppendPosition;

	PROCEDURE MakeMessage(pos: Position; code: ErrorCode; CONST msg: ARRAY OF CHAR; VAR message: ARRAY OF CHAR);
	BEGIN
		MakeDetailedMessage(pos, code, msg, NIL, message);
		Strings.AppendChar(message, 0X); (* terminate message *)
	END MakeMessage;

	PROCEDURE MakeDetailedMessage(pos: Position; code: ErrorCode; CONST msg: ARRAY OF CHAR; reader: Streams.Reader; VAR message: ARRAY OF CHAR);
	BEGIN
		GetErrorMessage(code, msg, message);
		AppendDetailedErrorMessage(message, pos, reader);
		AppendPosition(message, pos);
	END MakeDetailedMessage;

	(* error message with code *)
	PROCEDURE ErrorC*(diagnostics: Diagnostics.Diagnostics; CONST source: ARRAY OF CHAR; pos: Position; code: ErrorCode; CONST msg: ARRAY OF CHAR);
	VAR message: ARRAY 1024 OF CHAR; file: Files.File;

		PROCEDURE GetReader(): Streams.Reader;
		VAR reader := NIL: Streams.Reader; fileReader : Files.Reader;
		BEGIN
			IF (pos.linepos >= 0) & ((source # "") OR (pos.reader # NIL)) THEN
				reader := pos.reader;
				IF reader = NIL THEN
					file := Files.Old(source);
					IF file # NIL THEN
						NEW (fileReader, file, pos.linepos);
						reader := fileReader;
					END;
				END;
			END;
			RETURN reader;
		END GetReader;

	BEGIN
		IF diagnostics # NIL THEN
			MakeDetailedMessage(pos, code, msg, GetReader(), message);
			diagnostics.Error(source, pos.start, message);
		END;
	END ErrorC;

	(* error message without code *)
	PROCEDURE Error*(diagnostics: Diagnostics.Diagnostics; CONST source: ARRAY OF CHAR; pos: Position; CONST msg: ARRAY OF CHAR);
	BEGIN
		ErrorC(diagnostics, source, pos, InvalidCode, msg);
	END Error;

	PROCEDURE Warning*(diagnostics: Diagnostics.Diagnostics; CONST source: ARRAY OF CHAR; pos: Position; CONST msg: ARRAY OF CHAR);
	VAR message: ARRAY 256 OF CHAR;
	BEGIN
		IF diagnostics # NIL THEN
			MakeMessage(pos, InvalidCode, msg,message);
			diagnostics.Warning(source, pos.start, message);
		END;
	END Warning;

	PROCEDURE Information*(diagnostics: Diagnostics.Diagnostics; CONST source: ARRAY OF CHAR; pos: Position;CONST msg: ARRAY OF CHAR);
	VAR message: ARRAY 256 OF CHAR;
	BEGIN
		IF diagnostics # NIL THEN
			MakeMessage(pos, InvalidCode, msg,message);
			diagnostics.Information(source, pos.start, message);
		END;
	END Information;

	(** SetErrorMsg - Set message for error n *)

	PROCEDURE SetErrorMessage*(n: ErrorCode; CONST  msg: ARRAY OF CHAR);
	BEGIN
		IF errMsg = NIL THEN NEW(errMsg, InitErrMsgSize) END;
		WHILE LEN(errMsg^) < n DO Expand(errMsg) END;
		StringPool.GetIndex(msg, errMsg[n])
	END SetErrorMessage;

	PROCEDURE SetErrorExpected*(n: ErrorCode; CONST msg: ARRAY OF CHAR);
	VAR err: ARRAY 256 OF CHAR;
	BEGIN
		err := "missing '";
		Strings.Append(err,msg);
		Strings.Append(err, "'");
		SetErrorMessage(n,err);
	END SetErrorExpected;

	PROCEDURE AppendNumber*(VAR s: ARRAY OF CHAR; num: SIGNED64);
	VAR nums: ARRAY 32 OF CHAR;
	BEGIN
		Strings.IntToStr(num,nums);
		Strings.Append(s,nums);
	END AppendNumber;

	PROCEDURE InitSegmentedName*(VAR name: SegmentedName);
	VAR i: SIZE;
	BEGIN FOR i := 0 TO LEN(name)-1 DO name[i] := -1 END;
	END InitSegmentedName;

	PROCEDURE ToSegmentedName*(CONST name: ARRAY OF CHAR; VAR pooledName: SegmentedName);
	BEGIN
		ObjectFile.StringToSegmentedName(name,pooledName);
	END ToSegmentedName;

	PROCEDURE SegmentedNameToString*(CONST pooledName: SegmentedName; VAR name: ARRAY OF CHAR);
	BEGIN
		ObjectFile.SegmentedNameToString(pooledName, name);
	END SegmentedNameToString;

	PROCEDURE WriteSegmentedName*(w: Streams.Writer; name: SegmentedName);
	VAR sectionName: ObjectFile.SectionName;
	BEGIN
		SegmentedNameToString(name, sectionName);
		w.String(sectionName);
	END WriteSegmentedName;

	PROCEDURE AppendToSegmentedName*(VAR name: SegmentedName; CONST this: ARRAY OF CHAR);
	VAR i,j: SIZE; string: ObjectFile.SectionName;
	BEGIN
		i := 0;
		WHILE (i<LEN(name)) & (name[i] >= 0)  DO
			INC(i)
		END;
		IF (this[0] = ".") & (i < LEN(name)) THEN (* suffix *)
			j := 0;
			WHILE this[j+1] # 0X DO
				string[j] := this[j+1];
				INC(j);
			END;
			string[j] := 0X;
			name[i] := StringPool.GetIndex1(string);
			IF i<LEN(name)-1 THEN name[i+1] := -1 END;
		ELSE
			StringPool.GetString(name[i-1], string);
			Strings.Append(string, this);
			name[i-1] := StringPool.GetIndex1(string);
		END;
	END AppendToSegmentedName;

	(* suffix using separation character "." *)
	PROCEDURE SuffixSegmentedName*(VAR name: SegmentedName; this: StringPool.Index);
	VAR string, suffix: ObjectFile.SectionName; i: SIZE;
	BEGIN
		i := 0;
		WHILE (i < LEN(name)) & (name[i] >= 0) DO
			INC(i);
		END;
		IF i < LEN(name) THEN (* suffix *)
			name[i] := this;
			IF i<LEN(name)-1 THEN name[i+1] := -1 END;
		ELSE
			StringPool.GetString(name[i-1], string);
			StringPool.GetString(this, suffix);
			Strings.Append(string,".");
			Strings.Append(string, suffix);
			name[i-1] := StringPool.GetIndex1(string);
		END;
	END SuffixSegmentedName;

	PROCEDURE SegmentedNameEndsWith*(CONST name: SegmentedName; CONST this: ARRAY OF CHAR): BOOLEAN;
	VAR string: ObjectFile.SectionName; i: SIZE;
	BEGIN
		i := 0;
		WHILE (i< LEN(name)) & (name[i] >= 0) DO
			INC(i);
		END;
		DEC(i);
		IF i < 0 THEN
			RETURN FALSE
		ELSE
			StringPool.GetString(name[i],string);
			RETURN Strings.EndsWith(this, string);
		END
	END SegmentedNameEndsWith;

	PROCEDURE RemoveSuffix*(VAR name: SegmentedName);
	VAR i,pos,pos0: SIZE; string: ObjectFile.SectionName;
	BEGIN
		i := 0;
		WHILE  (i< LEN(name)) & (name[i] >= 0) DO
			INC(i);
		END;
		ASSERT(i>0);
		IF i < LEN(name) THEN (* name[i] = empty *) name[i-1] := -1
		ELSE (* i = LEN(name), name[i] = nonempty *)
			DEC(i);
			StringPool.GetString(name[i],string);
		pos0 := 0; pos := 0;
		WHILE (pos0 < LEN(string)) & (string[pos0] # 0X) DO
			IF string[pos0] = "." THEN pos := pos0 END;
			INC(pos0);
		END;
		IF pos = 0 THEN (* no dot in name or name starts with dot *)
				name[i] := -1
		ELSE (* remove last part in name *)
			string[pos] := 0X;
				name[i] := StringPool.GetIndex1(string);
		END;
		END;
	END RemoveSuffix;

	PROCEDURE GetSuffix*(CONST name: SegmentedName; VAR string: ARRAY OF CHAR);
	VAR i,pos,pos0: SIZE;
	BEGIN
		i := 0;
		WHILE  (i< LEN(name)) & (name[i] >= 0) DO
			INC(i);
		END;
		ASSERT(i>0);
		StringPool.GetString(name[i-1],string);
		IF i = LEN(name) THEN
			pos0 := 0; pos := 0;
			WHILE (pos0 < LEN(string)) & (string[pos0] # 0X) DO
				IF string[pos0] = "." THEN pos := pos0 END;
				INC(pos0);
			END;
			IF pos # 0 THEN (* no dot in name or name starts with dot *)
				pos0 := 0;
				REPEAT
					INC(pos); (* start with character after "." *)
					string[pos0] := string[pos];
					INC(pos0);
				UNTIL string[pos]  = 0X;
			END;
		END;
	END GetSuffix;

	PROCEDURE IsPrefix*(CONST prefix, of: SegmentedName): BOOLEAN;
	VAR prefixS, ofS: SectionName; i: SIZE;
	BEGIN
		i := 0;
		WHILE (i< LEN(prefix)) & (prefix[i] = of[i]) DO INC(i) END;

		IF i = LEN(prefix) THEN RETURN TRUE (* identical *)
		ELSE (* prefix[i] # of[i] *)
			IF prefix[i] < 0 THEN RETURN TRUE
			ELSIF of[i] < 0 THEN RETURN FALSE
			ELSIF (i<LEN(prefix)-1) THEN RETURN FALSE
			ELSE
				StringPool.GetString(prefix[i], prefixS);
				StringPool.GetString(of[i], ofS);
			RETURN Strings.StartsWith(prefixS, 0, ofS)
			END
		END;
	END IsPrefix;

	PROCEDURE Expand(VAR oldAry: ErrorMsgs);
	VAR
		len, i: SIZE;
		newAry: ErrorMsgs;
	BEGIN
		IF oldAry = NIL THEN RETURN END;
		len := LEN(oldAry^);
		NEW(newAry, len * 2);
		FOR i := 0 TO len-1 DO
			newAry[i] := oldAry[i];
		END;
		oldAry := newAry;
	END Expand;

	PROCEDURE Concat*(VAR result: ARRAY OF CHAR; CONST prefix, name, suffix: ARRAY OF CHAR);
	VAR i, j: SIZE;
	BEGIN
		i := 0; WHILE prefix[i] # 0X DO  result[i] := prefix[i];  INC(i)  END;
		j := 0; WHILE name[j] # 0X DO  result[i+j] := name[j];  INC(j)  END;
		INC(i, j);
		j := 0; WHILE suffix[j] # 0X DO result[i+j] := suffix[j]; INC(j)  END;
		result[i+j] := 0X;
	END Concat;

	PROCEDURE Lowercase*(CONST name: ARRAY OF CHAR; VAR result: ARRAY OF CHAR);
	VAR ch: CHAR; i: SIZE;
	BEGIN
		i := 0;
		REPEAT
			ch := name[i];
			IF (ch >= 'A') & (ch <= 'Z') THEN
				ch := CHR(ORD(ch)-ORD('A')+ORD('a'));
			END;
			result[i] := ch; INC(i);
		UNTIL ch = 0X;
	END Lowercase;

	PROCEDURE Uppercase*(CONST name: ARRAY OF CHAR; VAR result: ARRAY OF CHAR);
	VAR ch: CHAR; i: SIZE;
	BEGIN
		i := 0;
		REPEAT
			ch := name[i];
			IF (ch >= 'a') & (ch <= 'z') THEN
				ch := CHR(ORD(ch)-ORD('a')+ORD('A'));
			END;
			result[i] := ch; INC(i);
		UNTIL ch = 0X;
	END Uppercase;

	PROCEDURE GetIntegerObj*(value: SIGNED32):ANY;
	VAR obj: IntegerObject;
	BEGIN
		IF integerObjects.Has(value) THEN
			RETURN integerObjects.Get(value);
		END;
		NEW(obj);
		integerObjects.Put(value, obj);
		RETURN obj;
	END GetIntegerObj;

	PROCEDURE Align*(VAR offset: SIZE; alignment: SIZE);
	BEGIN
		IF alignment >0  THEN
			INC(offset,(-offset) MOD alignment);
		ELSIF alignment < 0 THEN
			DEC(offset,offset MOD (-alignment));
		END;
	END Align;

	PROCEDURE InitErrorMessages;
	BEGIN
		SetErrorMessage(UndeclaredIdentifier, "undeclared identifier");
		SetErrorMessage(MultiplyDefinedIdentifier, "multiply defined identifier");
		SetErrorMessage(NumberIllegalCharacter, "illegal character in number");
		SetErrorMessage(StringIllegalCharacter, "illegal character in string");
		SetErrorMessage(NoMatchProcedureName, "procedure name does not match");
		SetErrorMessage(CommentNotClosed, "comment not closed");
		SetErrorMessage(IllegalCharacterValue, "illegal character value");
		SetErrorMessage(ValueStartIncorrectSymbol, "value starts with incorrect symbol");
		SetErrorMessage(IllegalyMarkedIdentifier, "illegaly marked identifier");
		SetErrorMessage(IdentifierNoType, "identifier is not a type");
		SetErrorMessage(IdentifierNoRecordType, "identifier is not a record type");
		SetErrorMessage(IdentifierNoObjectType, "identifier is not an object type");
		SetErrorMessage(ImportNotAvailable, "import is not available");
		SetErrorMessage(RecursiveTypeDeclaration, "recursive type declaration");
		SetErrorMessage(NumberTooLarge, "number too large");
		SetErrorMessage(IdentifierTooLong, "identifier too long");
		SetErrorMessage(StringTooLong, "string too long");
	END InitErrorMessages;

	PROCEDURE ActivateDebug*;
	BEGIN
		debug := TRUE;
	END ActivateDebug;

	PROCEDURE GetFileReader*(CONST filename: ARRAY OF CHAR): Streams.Reader;
	VAR
		file: Files.File; fileReader: Files.Reader; offset: SIGNED32;
	BEGIN
		(* Optimisation: skip header of oberon files and return a file reader instead of default text reader*)
		file := Files.Old (filename);
		IF file = NIL THEN RETURN NIL END;
		NEW (fileReader, file, 0);
		IF (fileReader.Get () = 0F0X) & (fileReader.Get () = 001X) THEN
			offset := ORD (fileReader.Get ());
			INC (offset, LONG (ORD (fileReader.Get ())) * 0100H);
			fileReader.SetPos(offset);
		ELSE fileReader.SetPos(0)
		END;
		RETURN fileReader
	END GetFileReader;

	PROCEDURE GetWriter*(w: Streams.Writer): Writer;
	VAR writer: Writer;
	BEGIN
		ASSERT(w # NIL);
		IF w IS Writer THEN RETURN w(Writer)
		ELSIF getWriter = NIL THEN
			NEW(writer,w); RETURN writer
		ELSE RETURN getWriter(w)
		END;
	END GetWriter;

	PROCEDURE GetDebugWriter*(CONST title: ARRAY OF CHAR): Streams.Writer;
	VAR w: Streams.Writer;
	BEGIN
		IF getDebugWriter # NIL THEN  w:= getDebugWriter(title)
		ELSE NEW(w, KernelLog.Send,1024)
		END;
		RETURN w;
	END GetDebugWriter;

	PROCEDURE GetDiagnostics*(w: Streams.Writer): Diagnostics.Diagnostics;
	VAR diagnostics: Diagnostics.StreamDiagnostics;
	BEGIN
		IF getDiagnostics # NIL THEN RETURN getDiagnostics(w)
		ELSE NEW(diagnostics,w); RETURN diagnostics
		END;
	END GetDiagnostics;

	PROCEDURE GetDefaultDiagnostics*(): Diagnostics.Diagnostics;
	VAR w: Streams.Writer;
	BEGIN
		NEW(w, KernelLog.Send,128);
		RETURN GetDiagnostics(w);
	END GetDefaultDiagnostics;

	PROCEDURE InitWindowWriter;
	VAR install: PROCEDURE;
	BEGIN
		getDebugWriter := NIL; getWriter := NIL;
		IF Modules.ModuleByName("WindowManager") # NIL THEN
			GETPROCEDURE("FoxA2Interface","Install",install);
		END;
		IF install # NIL THEN install END;
	END InitWindowWriter;

	PROCEDURE InstallWriterFactory*(writer: WriterFactory; debug: DebugWriterFactory; diagnostics: DiagnosticsFactory);
	BEGIN
		getWriter := writer;
		getDebugWriter := debug;
		getDiagnostics := diagnostics;
	END InstallWriterFactory;

	PROCEDURE Replace(VAR in: ARRAY OF CHAR; CONST this, by: ARRAY OF CHAR);
	VAR pos: SIZE;
	BEGIN
		pos := Strings.Pos(this,in);
		IF pos >= 0 THEN
			Strings.Delete(in,pos,Strings.Length(this));
			Strings.Insert(by, in, pos);
		END;
	END Replace;

	OPERATOR "="*(CONST left: ARRAY OF CHAR; right: String): BOOLEAN;
	BEGIN
		RETURN right = StringPool.GetIndex1(left);
	END "=";

	OPERATOR "="*(left: String; CONST right: ARRAY OF CHAR): BOOLEAN;
	BEGIN
		RETURN right = left;
	END "=";

	PROCEDURE MessageS*(CONST format, s0: ARRAY OF CHAR): MessageString;
	VAR message: MessageString;
	BEGIN
		COPY(format, message);
		Replace(message,"%0",s0);
		RETURN message
	END MessageS;

	PROCEDURE MessageSS*(CONST format, s0, s1: ARRAY OF CHAR): MessageString;
	VAR message: MessageString;
	BEGIN
		COPY(format, message);
		Replace(message,"%0",s0);
		Replace(message,"%1",s1);
		RETURN message
	END MessageSS;

	PROCEDURE MessageI*(CONST format: ARRAY OF CHAR; i0: SIGNED32): MessageString;
	VAR message: MessageString; number: ARRAY 32 OF CHAR;
	BEGIN
		COPY(format, message);
		Strings.IntToStr(i0,number);
		Replace(message,"%0",number);
	END MessageI;

	PROCEDURE MessageSI*(CONST format: ARRAY OF CHAR; CONST s0: ARRAY OF CHAR; i1: SIGNED32): MessageString;
	VAR message: MessageString; number: ARRAY 32 OF CHAR;
	BEGIN
		COPY(format, message);
		Replace(message,"%0",s0);
		Strings.IntToStr(i1,number);
		Replace(message,"%1",number);
	END MessageSI;

		(*
		Get next available name from stream ignoring comments and end of comment brackets
		Returns TRUE on success, returns FALSE on end of stream, on error or if "~" or ";" encountered.
		Scanner based on Peek() feature of stream. Necessary to make it restartable.
	*)
	PROCEDURE GetStringParameter*(r: Streams.Reader; VAR string: ARRAY OF CHAR): BOOLEAN;
	VAR ch: CHAR; i: SIZE; done,error: BOOLEAN;

		PROCEDURE Next;
		BEGIN r.Char(ch); ch := r.Peek();
		END Next;

		PROCEDURE Append(ch: CHAR);
		BEGIN string[i] := ch; INC(i)
		END Append;

		PROCEDURE SkipWhitespace;
		BEGIN WHILE (ch <= " ") & (ch # 0X) DO Next END;
		END SkipWhitespace;

		PROCEDURE Comment;
		VAR done: BOOLEAN;
		BEGIN
			done := FALSE;
			Next;
			REPEAT
				CASE ch OF
				|"(": Next; IF ch = "*" THEN Comment; SkipWhitespace END;
				|"*": Next; IF ch =")" THEN Next; done:= TRUE END;
				| 0X: done := TRUE;
				ELSE Next;
				END;
			UNTIL done;
		END Comment;

		PROCEDURE String(delimiter: CHAR);
		VAR done: BOOLEAN;
		BEGIN
			done := FALSE; Next;
			REPEAT
				IF ch = delimiter THEN done := TRUE; Next;
				ELSIF ch = 0X THEN done := TRUE; error := TRUE;
				ELSE Append(ch); Next;
				END;
			UNTIL done OR (i=LEN(string)-1);
		END String;

	BEGIN
		i := 0; done := FALSE;
		ch := r.Peek(); (* restart scanning *)
		SkipWhitespace;
		REPEAT
			CASE ch OF
				"(": Next; IF ch = "*" THEN Comment ; SkipWhitespace ELSE Append(ch) END;
				| "*": Next; IF ch = ")" THEN Next; SkipWhitespace ELSE Append(ch) END;
				| '"', "'": done := TRUE; IF i = 0 THEN String(ch) END;
				| 0X .. ' ', '~', ';': done := TRUE;
			ELSE
				Append(ch);
				Next;
			END;
		UNTIL done OR (i = LEN(string)-1);
		string[i] := 0X;
		RETURN (i > 0) & done & ~error;
	END GetStringParameter;

	PROCEDURE GetTracingDiagnostics*(diagnostics: Diagnostics.Diagnostics): Diagnostics.Diagnostics;
	VAR tracing: TracingDiagnostics;
	BEGIN
		NEW(tracing, diagnostics); RETURN tracing
	END GetTracingDiagnostics;

BEGIN
	InitErrorMessages;
	InitWindowWriter;
	lists := 0;  enlarged := 0;  strings := 0;
	emptyString := MakeString("");
	debug := FALSE;
	invalidPosition.start := -1;
	invalidPosition.end := -1;
	invalidPosition.line := -1;
	invalidPosition.linepos := -1;
	NEW(integerObjects, 128);
END FoxBasic.

FoxBasic.ActivateDebug ~

FoxBasic.Test ~
