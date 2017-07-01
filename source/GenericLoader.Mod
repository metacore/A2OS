MODULE GenericLoader; (** AUTHOR "fof"; PURPOSE "Active Oberon Generic Object File Loader"; *)

(* cf. Linker *)

IMPORT SYSTEM, KernelLog, Modules, Streams, Files, D := KernelLog, GenericLinker, ObjectFile, Diagnostics, Strings, StringPool, Trace, Machine;

CONST
	Ok = 0;
	LinkerError=3400;
	FileNotFound = 3401;
	CommandTrapped* = 3904; (* cf module Commands *) 
	
	SupportOldObjectFileFormat = FALSE;
	TraceLoading = FALSE;
TYPE

	HashEntryIntInt = RECORD
		key,value: LONGINT;
	END;
	HashIntArray = POINTER TO ARRAY OF HashEntryIntInt;

	HashEntryIntAny = RECORD
		key: LONGINT; value: ANY;
	END;

	HashIntAnyArray = POINTER TO ARRAY OF HashEntryIntAny;

	HashTableInt = OBJECT
	VAR
		table: HashIntArray;
		size: LONGINT;
		used-: LONGINT;
		maxLoadFactor: REAL;

		(* Interface *)

		PROCEDURE & Init* (initialSize: LONGINT);
		BEGIN
			ASSERT(initialSize > 2);
			NEW(table, initialSize);
			size := initialSize;
			used := 0;
			maxLoadFactor := 0.75;
		END Init;

		PROCEDURE Put*(key: LONGINT; value: LONGINT);
		VAR hash: LONGINT;
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

		PROCEDURE Get*(key: LONGINT):LONGINT;
		BEGIN
			RETURN table[HashValue(key)].value;
		END Get;

		PROCEDURE Has*(key: LONGINT):BOOLEAN;
		BEGIN
			RETURN table[HashValue(key)].key = key;
		END Has;

		PROCEDURE Length*():LONGINT;
		BEGIN RETURN used; END Length;

		PROCEDURE Clear*;
		VAR i: LONGINT;
		BEGIN FOR i := 0 TO size - 1 DO table[i].key := 0; END; END Clear;

		(* Internals *)

		PROCEDURE HashValue(key: LONGINT):LONGINT;
		VAR value, h1, h2, i: LONGINT;
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
		VAR oldTable: HashIntArray; oldSize, i, key: LONGINT;
		BEGIN
			oldSize := size;
			oldTable := table;
			Init(size*2);
			FOR i := 0 TO oldSize-1 DO
				key := oldTable[i].key;
				IF key # 0 THEN
					Put(key, oldTable[i].value);
				END;
			END;
		END Grow;

	END HashTableInt;

	HashTableIntAny* = OBJECT
	VAR
		table: HashIntAnyArray;
		size: LONGINT;
		used-: LONGINT;
		maxLoadFactor: REAL;

		(* Interface *)

		PROCEDURE & Init* (initialSize: LONGINT);
		BEGIN
			ASSERT(initialSize > 2);
			NEW(table, initialSize);
			size := initialSize;
			used := 0;
			maxLoadFactor := 0.75;
		END Init;

		PROCEDURE Put*(key: LONGINT; value: ANY);
		VAR hash: LONGINT;
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

		PROCEDURE Get*(key: LONGINT):ANY;
		BEGIN
			RETURN table[HashValue(key)].value;
		END Get;

		PROCEDURE Has*(key: LONGINT):BOOLEAN;
		BEGIN
			RETURN table[HashValue(key)].key = key;
		END Has;

		PROCEDURE Length*():LONGINT;
		BEGIN RETURN used; END Length;

		PROCEDURE Clear*;
		VAR i: LONGINT;
		BEGIN FOR i := 0 TO size - 1 DO table[i].key := 0; END; END Clear;

		(* Interface for integer values *)

		(* Internals *)

		PROCEDURE HashValue(key: LONGINT):LONGINT;
		VAR value, h1, h2, i: LONGINT;
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
		VAR oldTable: HashIntAnyArray; oldSize, i, key: LONGINT;
		BEGIN
			oldSize := size;
			oldTable := table;
			Init(size*2);
			FOR i := 0 TO oldSize-1 DO
				key := oldTable[i].key;
				IF key # 0 THEN
					Put(key, oldTable[i].value);
				END;
			END;
		END Grow;

	END HashTableIntAny;

	Data=RECORD size, pos: LONGINT; bytes: Modules.Bytes; firstAddress: LONGINT; END;

	Arrangement* = OBJECT (GenericLinker.Arrangement);
	VAR
		code, data: Data;
		(*moduleAdr: LONGINT;*)
		hasBody: BOOLEAN;
		bodyAddress : LONGINT;

		PROCEDURE & InitArrangement;
		BEGIN InitData(code); InitData(data); hasBody := FALSE;
		END InitArrangement;

		PROCEDURE Preallocate*(CONST section: ObjectFile.Section);
		BEGIN
			ASSERT(section.unit = 8);
			ASSERT(section.bits.GetSize() MOD 8 = 0);
			ASSERT(section.type # ObjectFile.InitCode);
			IF section.type IN {ObjectFile.Code, ObjectFile.BodyCode} THEN
				DoPreallocate(section, code);
			ELSE ASSERT (section.type IN {ObjectFile.Const, ObjectFile.Data});
				DoPreallocate(section, data);
			END;
		END Preallocate;

		PROCEDURE Allocate* (CONST section: ObjectFile.Section): GenericLinker.Address;
		VAR adr: GenericLinker.Address;
		BEGIN
			IF section.type IN {ObjectFile.Code, ObjectFile.BodyCode} THEN
				adr := DoAllocate(section, code);
			ELSE ASSERT(section.type IN {ObjectFile.Const, ObjectFile.Data});
				adr := DoAllocate(section, data);
			END;

			IF section.type = ObjectFile.BodyCode THEN
				hasBody := TRUE; bodyAddress := adr;
			END;

			(*
			IF (section.identifier.name[0] >= 0) & (section.identifier.name[1] >= 0)  THEN
				IF (section.identifier.name[1] = InternalModuleName) OR (section.identifier.name[2] = InternalModuleName) THEN
					moduleAdr := adr
				END;
			END;
			*)

			RETURN adr;
		END Allocate;

		PROCEDURE Patch* (pos, value: GenericLinker.Address; offset, bits, unit: ObjectFile.Bits);
		VAR char: CHAR;
		BEGIN
			ASSERT(bits MOD 8 = 0);
			ASSERT(unit = 8);

			WHILE bits > 0 DO
				char := CHR(value);
				SYSTEM.PUT(pos, char);
				value := value DIV 256;
				DEC(bits,8); INC(pos,1);
			END;

		END Patch;

	END Arrangement;

	ModuleList=OBJECT
	VAR
		hash: HashTableIntAny;

		PROCEDURE &Init;
		BEGIN
			NEW(hash,128);
		END Init;

		PROCEDURE ThisModule(module: Modules.Module): HashTableInt;
		VAR modList: HashTableInt;
			any: ANY;

			PROCEDURE TraverseScopes(CONST scope: Modules.ExportDesc; level: LONGINT);
			VAR adr,i: LONGINT;
			BEGIN
				IF (level > 2) THEN RETURN END;
				IF (scope.fp # 0) THEN
					adr := scope.adr;
					IF SupportOldObjectFileFormat THEN
						IF module.staticTypeDescs # testTypeDescs THEN (* old object file format *)
							IF (adr = 0) & (scope.exports > 0)  THEN (* type in old object file format *)
								adr := scope.dsc[0].adr;
								SYSTEM.GET(module.sb + adr, adr);
							ELSIF adr # 0 THEN
								INC(adr,ADDRESSOF(module.code[0]));
							END;
						END;
					END;
					modList.Put(scope.fp, adr)
				END;
				FOR i := 0 TO scope.exports-1 DO
					IF scope.dsc # NIL THEN TraverseScopes(scope.dsc[i],level+1) END;
				END;
				adr := 0;
			END TraverseScopes;

		BEGIN{EXCLUSIVE}
			IF hash.Has(SYSTEM.VAL(LONGINT, module)) THEN
				any := hash.Get(SYSTEM.VAL(LONGINT,module));
				modList := any(HashTableInt);
			ELSE
				NEW(modList,256);  TraverseScopes(module.export,0);
				hash.Put(SYSTEM.VAL(LONGINT,module), modList);
				RETURN modList
			END;
			RETURN modList;
		END ThisModule;

	END ModuleList;

	Linker = OBJECT (GenericLinker.Linker)
	VAR
		moduleName: ObjectFile.SegmentedName;
		importBlock: GenericLinker.Block;
		hash: HashTableIntAny;
		moduleBlock: GenericLinker.Block;

		PROCEDURE &InitLinkerX* (diagnostics: Diagnostics.Diagnostics; log: Streams.Writer; code, data: GenericLinker.Arrangement; CONST name: ARRAY OF CHAR);
		BEGIN
			ObjectFile.StringToSegmentedName(name, moduleName);
			InitLinker(diagnostics, log, GenericLinker.UseAllButInitCode (* strip init code *), code, data);
			NEW(importBlock);
			NEW(hash,256); (* hash for blocks *)
		END InitLinkerX;

		(* oerwritten functionality of generic linker *)
		PROCEDURE FindBlock(CONST identifier: ObjectFile.Identifier): GenericLinker.Block;
		VAR block: GenericLinker.Block; any: ANY;
		BEGIN
			block := NIL;
			IF IsPrefix(moduleName, identifier.name) THEN (* local block *)
				IF identifier.fingerprint = 0 THEN (* not identifiable via fingerprint *)
					block := FindBlock^(identifier);
				ELSE
					any := hash.Get(identifier.fingerprint);
					IF any # NIL THEN block := any(GenericLinker.Block)  (* local block *) END;
					IF (block # NIL) & (block.identifier.name # identifier.name) THEN (* local block, false or duplicate fingerprint *)
						block := FindBlock^(identifier)
					END;
				END;
			END;
			RETURN block;
		END FindBlock;

		PROCEDURE ExportBlock(block: GenericLinker.Block);
		BEGIN
			IF block.identifier.fingerprint # 0 THEN
				hash.Put(block.identifier.fingerprint, block)
			END;
			IF (block.identifier.name[0] >= 0) & (block.identifier.name[1] >= 0)  THEN
				IF (block.identifier.name[1] = InternalModuleName) & (block.identifier.name[2]<0) OR (block.identifier.name[2] = InternalModuleName) & (block.identifier.name[3] < 0) THEN
					moduleBlock := block;
				END;
			END;
		END ExportBlock;

		PROCEDURE ImportBlock(CONST fixup: ObjectFile.Fixup): GenericLinker.Block;
		VAR name: Modules.Name; res: LONGINT;
			msg: ARRAY 128 OF CHAR; module: Modules.Module; adr: LONGINT; m: HashTableInt;
			s: ObjectFile.SectionName; isModule: BOOLEAN; identifier: ObjectFile.Identifier;
			fp: LONGINT;

			PROCEDURE CheckName(n: StringPool.Index;  name {UNTRACED}: Modules.DynamicName): LONGINT;
			VAR s: ObjectFile.SectionName; i: LONGINT;
			BEGIN
				IF name = NIL THEN RETURN -1 END;
				StringPool.GetString(n, s); 
				i := 0;
				WHILE (s[i] # 0X) & (name[i] # 0X) & (s[i] = name[i]) DO
					INC(i);
				END;
				RETURN ORD(s[i]) - ORD(name[i]);
			END CheckName;
			
			PROCEDURE Error(n: StringPool.Index);
			VAR name: ARRAY 256 OF CHAR;
			BEGIN
				StringPool.GetString(n, name); 
				TRACE("Fingerprint does not match",name);
			END Error;
			
		
			(* stupid implementation: just search for fp in all exports *)
			PROCEDURE CheckScope(CONST scope: Modules.ExportDesc; level: LONGINT): LONGINT;
			VAR adr,lo,hi,m,res: LONGINT;
			BEGIN
				adr := 0;
				(* export names are sorted, binary search: *)
				lo := 0; hi := scope.exports-1;
				WHILE (lo <= hi) DO
				 	m := (lo + hi) DIV 2;
					res := CheckName(identifier.name[level], scope.dsc[m].name);
					IF res = 0 THEN 
						IF (level = LEN(identifier.name)-1) OR (identifier.name[level+1] <= 0) THEN
							(*IF (scope.dsc[m].fp # identifier.fingerprint) & (scope.dsc[m].fp # 0) & (identifier.fingerprint # 0) THEN
								Error(identifier.name[level]);
							END;
							*)
							fp := scope.dsc[m].fp;
							RETURN scope.dsc[m].adr
						ELSE
							RETURN CheckScope(scope.dsc[m], level+1);
						END;
					ELSIF res > 0 THEN lo := m+1;
					ELSE hi := m-1;
					END;
				END;
				RETURN 0;
			END CheckScope;
						

		BEGIN
			identifier := fixup.identifier;

			IF IsPrefix(moduleName, identifier.name) THEN
				D.String("circular import while trying to fetch ");
				s := identifier.name; D.String(s);
				D.Ln;
				RETURN NIL
			END;

			StringPool.GetString(identifier.name[0], name);
			isModule := identifier.name[1] = InternalModuleName;
			IF (identifier.name[0] = OberonName) & (identifier.name[2] >= 0)  THEN (* in Oberon name space *)
				StringPool.GetString(identifier.name[1], s);
				Strings.Append(name, ".");
				Strings.Append(name, s);
				isModule := identifier.name[2] = InternalModuleName;
			END;

			(*
				IF ~isModule & (identifier.fingerprint = 0) THEN
				D.String("Invalid attempt to import symbol without fingerprint ");
				s := identifier.name; D.String(s);
				D.Ln;
				RETURN NIL
			END;
			*)

			module := Modules.ThisModule(name,res,msg);
			IF module = NIL THEN
				D.String("could not get module while importing "); D.String(name); D.Ln;
				RETURN NIL
			END;
			IF isModule THEN
				adr := SYSTEM.VAL(ADDRESS, module) - fixup.patch[0].displacement;
			ELSE
				m := moduleList.ThisModule(module);
				ASSERT(module # NIL);
				(* first try via hash-table *)
				(* disabled -- might be able to remove hash table completely, needs some testing
				IF identifier.fingerprint # 0 THEN
					adr := m.Get(identifier.fingerprint);
				END;
				*)
				(* if it does not work, then try export table directly *)
				IF adr = 0 THEN
					adr := CheckScope(module.export,1(*level*) );
				END;
			END;

			IF adr = 0 THEN
				(*D.String("GenericLoader Fatal error: did not find block "); s := identifier.name; D.String(s); D.Ln;*)
				RETURN NIL;
			ELSE (* found *)
				importBlock.identifier.fingerprint := fp; importBlock.address := adr
			END;
			RETURN importBlock
		END ImportBlock;

	END Linker;

VAR
	moduleList: ModuleList;
	testTypeDescs: Modules.Bytes;
	InternalModuleName, OberonName: StringPool.Index;

	PROCEDURE InitData(VAR data: Data);
	BEGIN
		data.pos := 0; data.size := 0; data.bytes := NIL; data.firstAddress := 0;
	END InitData;

	PROCEDURE IsPrefix(CONST prefix, of: ObjectFile.SegmentedName): BOOLEAN;
	VAR prefixS, ofS: ObjectFile.SectionName; i: LONGINT;
	BEGIN
		i := 0;
		WHILE (i< LEN(prefix)) & (prefix[i] = of[i]) DO INC(i) END;

		IF i = LEN(prefix) THEN RETURN TRUE (* identical *)
		ELSE (* prefix[i] # of[i] *)
			IF prefix[i] < 0 THEN RETURN TRUE (* name longer than prefix *)
			ELSIF of[i] < 0 THEN RETURN FALSE (* prefix longer than name *)
			ELSIF (i<LEN(prefix)-1) THEN RETURN FALSE (* prefix and name differ but not at the tail *)
			ELSE
				(* check tail *)
				StringPool.GetString(prefix[i], prefixS);
				StringPool.GetString(of[i], ofS);
				RETURN Strings.StartsWith(prefixS, 0, ofS)
			END
		END;
	END IsPrefix;

	PROCEDURE DoPreallocate(CONST section: ObjectFile.Section; VAR data: Data);
	BEGIN
		ASSERT(section.bits.GetSize() MOD 8 = 0);
		IF section.alignment > 0 THEN
			INC(data.size, (-data.size) MOD section.alignment); (* here we assume that base-alignment is ok *)
		END;
		INC(data.size, section.bits.GetSize() DIV 8);
	END DoPreallocate;

	PROCEDURE DoAllocate(CONST section: ObjectFile.Section; VAR data: Data): GenericLinker.Address;
	VAR address: ObjectFile.Bits; size: SIZE;
	BEGIN
		IF (data.bytes = NIL) OR (LEN(data.bytes) # data.size) THEN NEW(data.bytes, data.size) END;

		IF section.alignment > 0 THEN
			INC(data.pos, (-data.pos) MOD section.alignment); (* here we assume that base-alignment is ok *)
		END;
		address := ADDRESSOF(data.bytes[0])+data.pos; (*  to account for potentially empty variable at end of data ... *)
		size := section.bits.GetSize();
		section.bits.CopyTo(address, size);
		INC(data.pos, size DIV 8);
		(*
		bitPos:= 0;
		WHILE size > 0 DO
			value := section.bits.GetBits(bitPos,8);
			data.bytes[data.pos] := CHR(value);
			DEC(size,8); INC(data.pos); INC(bitPos,8);
		END;
		*)
		IF data.firstAddress = 0 THEN data.firstAddress := address END;
		RETURN address
	END DoAllocate;
	
	PROCEDURE LoadObj*(CONST name, fileName: ARRAY OF CHAR;  VAR res: LONGINT; VAR msg: ARRAY OF CHAR): Modules.Module;
	TYPE Body=PROCEDURE;
	VAR
		file: Files.File; reader: Files.Reader; linker: Linker;
		arrangement: Arrangement; diagnostics: Diagnostics.StreamDiagnostics; stringWriter: Streams.StringWriter;
		module: Modules.Module; heapBlockAdr,moduleAdr: LONGINT;
		Log: Streams.Writer;
	BEGIN
		file := Files.Old(fileName);

		IF file # NIL THEN
			IF TraceLoading THEN Trace.String("loading"); Trace.String(fileName); Trace.Ln END;
			res := Ok; msg[0] := 0X;
			Files.OpenReader(reader, file, 0);
			NEW(arrangement); NEW(stringWriter,256);
			Streams.OpenWriter( Log, KernelLog.Send );
			NEW(diagnostics,Log);
			NEW(linker, diagnostics, NIL, arrangement, arrangement,name);
			IF TraceLoading THEN Trace.String("before linking"); Trace.Ln END;
			GenericLinker.Process (reader, linker);
			IF ~linker.error THEN linker.Resolve END;
			IF ~linker.error THEN linker.Link END;
			(*D.Update;*)
			IF ~linker.error THEN
				IF TraceLoading THEN Trace.String("linking done"); Trace.Ln END;

				moduleAdr := linker.moduleBlock.address;
				IF ~Machine.IsCooperative THEN
					SYSTEM.GET(moduleAdr+3*SIZEOF(ADDRESS), moduleAdr);
					SYSTEM.GET(moduleAdr-2*SIZEOF(ADDRESS), heapBlockAdr);
					ASSERT(heapBlockAdr = linker.moduleBlock.address+2*SIZEOF(ADDRESS));
				END;
				module := SYSTEM.VAL(Modules.Module,moduleAdr);
				module.staticTypeDescs := testTypeDescs; (* trick to identify new object file loaded modules *)
				module.data := arrangement.data.bytes;
				module.code := arrangement.code.bytes;

				module.sb := 0 (*arrangement.data.firstAddress*); (* zero is correct ! *)
				module.body := SYSTEM.VAL(Body, arrangement.bodyAddress);
				
				(*
				SortProcTable(module);
				SelectionSort(module.exTable);
				*)

				(*
					careful: when GC uses a heuristic for pointer detection on the stack, it will not
					trace the module because the module is not reachable as a heap block in a sweep
					Therefore the code and data array has to be secured in addition.
					Here this is made sure to enter the module in the data structure before returning it. 
				*) 
				Modules.Initialize(module);
			ELSE module := NIL; res := LinkerError; stringWriter.Update; stringWriter.Get(msg);

			END;
		ELSE
			res := FileNotFound;  COPY(fileName, msg);  Modules.Append(" not found", msg)
		END;
		IF res # Ok THEN module := NIL END;
		IF (res # Ok) & (res # FileNotFound) THEN D.String(msg);D.Ln END;
		RETURN module
	FINALLY
		res := CommandTrapped;
		RETURN NIL
	END LoadObj;

	PROCEDURE Install*;
	VAR extension: ARRAY 32 OF CHAR;
	BEGIN
		Machine.GetConfig("ObjectFileExtension", extension);
		IF extension = "" THEN
			COPY(".Gof", extension)
		END;
		Modules.AddLoader(extension, LoadObj); 
	END Install;

	PROCEDURE Remove*;
	BEGIN
		Modules.RemoveLoader(".Gof",LoadObj);
	END Remove;

	BEGIN
		NEW(testTypeDescs,1);
		Modules.InstallTermHandler(Remove);
		StringPool.GetIndex("Oberon",OberonName);
		StringPool.GetIndex("@Module",InternalModuleName);
		NEW(moduleList);
		Install;
	END GenericLoader.



	(* concurrent load test:
	VAR
	startConcurrentLoad: BOOLEAN;

	PROCEDURE ConcurrentLoad*;
	VAR i: LONGINT;
		o: OBJECT 		VAR
			mod: Modules.Module; res: LONGINT; msg: ARRAY 32 OF CHAR;
		BEGIN{ACTIVE}
			WHILE(~startConcurrentLoad) DO END;
			mod := Modules.ThisModule("Test",res,msg);
		END;
	BEGIN
		startConcurrentLoad := FALSE;
		FOR i := 0 TO 128 DO
			NEW(o);
		END;
		startConcurrentLoad := TRUE;
	END ConcurrentLoad;
	*)
	