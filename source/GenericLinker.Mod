
 MODULE GenericLinker;	(* AUTHOR "negelef"; PURPOSE "Generic Object File Linker"; *)

IMPORT ObjectFile, Streams, Diagnostics, Strings, SYSTEM;

TYPE Address* = ADDRESS;

CONST
	InvalidAddress* = -1 (* MAX (Address) *);

CONST
	(* priorities -- do not coincide with ObjecFile section types *)
	Fixed* = 0; (* placed accroding to placement *)
	EntryCode*= 1; (* must be placed before all other code *)
	InitCode*=2;
	ExitCode*=3; (* must be placed after initcode but before code *)
	BodyCode* = 4;
	Code* = 5;
	Data* = 6;
	Const* = 7;
	Empty* = 8; (* must be placed last *)

	(* refers to priority classes, not to ObjectFile section types *)
	UseAll *= {Fixed .. Empty};
	UseInitCode*={Fixed .. ExitCode};
	UseAllButInitCode*={Fixed, BodyCode..Empty};

TYPE
	HashEntrySegmentedName = RECORD
		key: ObjectFile.SegmentedName; (* key[0]= MIN(SIGNED32) <=> empty *)
		value: Block;
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

		PROCEDURE Put*(CONST key: ObjectFile.SegmentedName; value: Block);
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

		PROCEDURE Get*(CONST key: ObjectFile.SegmentedName):Block;
		VAR hashValue : SIZE;
		BEGIN
			hashValue := HashValue(key);
			IF (table[hashValue].key = key) & (table[hashValue].value # unused) THEN
				RETURN table[hashValue].value;
			ELSE
				RETURN NIL
			END;
		END Get;

		PROCEDURE Clear;
		VAR i: SIZE;
		BEGIN
			FOR i := 0 TO size - 1 DO table[i].key[0] := -1; END;
		END Clear;

		(* Internals *)
		PROCEDURE Hash(CONST name: ObjectFile.SegmentedName): SIZE;
		VAR fp,i: SIZE;
		BEGIN
			fp := name[0]; i := 1;
			WHILE (i<LEN(name)) & (name[i] >= 0) DO
				fp:=SYSTEM.VAL(SIZE, SYSTEM.VAL(SET, ROT(fp, 7)) / SYSTEM.VAL(SET, name[i]));
				INC(i);
			END;
			RETURN fp
		END Hash;

		PROCEDURE HashValue(CONST key: ObjectFile.SegmentedName):SIZE;
		VAR value, h,i: SIZE;
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
		VAR oldTable: HashSegmentedNameArray; oldSize, i: SIZE; key: ObjectFile.SegmentedName;
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

TYPE Arrangement* = OBJECT

	PROCEDURE Preallocate* (CONST section: ObjectFile.Section);
	END Preallocate;

	PROCEDURE Allocate* (CONST section: ObjectFile.Section): Address;
	END Allocate;

	PROCEDURE Patch* (pos, value: Address; offset, bits, unit: ObjectFile.Bits);
	END Patch;

	PROCEDURE CheckReloc*(target: Address; pattern: ObjectFile.Pattern; CONST patch: ObjectFile.Patch);
	BEGIN
		(* to be able to provide relocation information in an image*)
	END CheckReloc;

END Arrangement;

TYPE Block* = POINTER TO RECORD (ObjectFile.Section)
	next: Block;
	address*: Address;
	aliasOf*: Block;
	referenced, used: BOOLEAN;
	priority: INTEGER;
END;

TYPE Linker* = OBJECT
VAR
	diagnostics: Diagnostics.Diagnostics;
	usedCategories: SET;
	error-: BOOLEAN;
	log-: Streams.Writer;
	code, data: Arrangement;
	firstBlock, firstLinkedBlock: Block;
	linkRoot: ObjectFile.SectionName;
	hash: HashTableSegmentedName;
	offers-, requires-: ObjectFile.NameList;

	PROCEDURE &InitLinker* (diagnostics: Diagnostics.Diagnostics; log: Streams.Writer; useCategories: SET; code, data: Arrangement);
	BEGIN
		SELF.diagnostics := diagnostics; SELF.log := log; SELF.usedCategories := useCategories;
		error := FALSE; SELF.code := code; SELF.data := data; firstBlock := NIL; firstLinkedBlock := NIL;
		linkRoot := "";
		NEW(hash,64);

	END InitLinker;

	PROCEDURE SetLinkRoot*(CONST root: ARRAY OF CHAR);
	BEGIN COPY(root, linkRoot)
	END SetLinkRoot;

	PROCEDURE SetOffers*(CONST offers: ObjectFile.NameList);
	BEGIN
		SELF.offers := offers;
	END SetOffers;

	PROCEDURE SetRequires*(CONST requires: ObjectFile.NameList);
	BEGIN
		SELF.requires := requires;
	END SetRequires;


	PROCEDURE Error* (CONST source, message: ARRAY OF CHAR);
	BEGIN diagnostics.Error (source, Streams.Invalid, message); error := TRUE;
	END Error;

	PROCEDURE Warning* (CONST source, message: ARRAY OF CHAR);
	BEGIN diagnostics.Warning (source, Streams.Invalid, message);
	END Warning;

	PROCEDURE ErrorP*(CONST pooledName: ObjectFile.SegmentedName; CONST message: ARRAY OF CHAR);
	VAR source: ARRAY 256 OF CHAR;
	BEGIN
		ObjectFile.SegmentedNameToString(pooledName, source); Error(source, message);
	END ErrorP;

	PROCEDURE Information* (CONST source, message: ARRAY OF CHAR);
	BEGIN IF log#NIL  THEN log.String(source); log.String(":"); log.String(message); log.Ln END;
	END Information;

	PROCEDURE InformationP*(CONST pooledName: ObjectFile.SegmentedName; CONST message: ARRAY OF CHAR);
	VAR source: ARRAY 256 OF CHAR;
	BEGIN
		ObjectFile.SegmentedNameToString(pooledName, source); Information(source, message);
	END InformationP;

	PROCEDURE FindBlock* (CONST identifier: ObjectFile.Identifier): Block;
	BEGIN
		RETURN hash.Get(identifier.name);
	END FindBlock;

	PROCEDURE ImportBlock*(CONST fixup: ObjectFile.Fixup): Block;
	BEGIN
		RETURN NIL
	END ImportBlock;

	PROCEDURE ExportBlock*(block: Block);
	BEGIN
		(* can be overwritten by implementers, for example for hashing the block *)
	END ExportBlock;

	PROCEDURE GetArrangement (block: Block): Arrangement;
	BEGIN IF ObjectFile.IsCode (block.type) THEN RETURN code; ELSE RETURN data; END;
	END GetArrangement;

	(* this procedure may be overwritten by implementations of the linker that need a special ordering, as, for example, the bodycode in the front or so *)
	PROCEDURE Precedes* (left, right: Block): BOOLEAN;
	BEGIN RETURN left.priority < right.priority
	END Precedes;

	PROCEDURE RemoveBlock* (block: Block);
	VAR current: Block;
	BEGIN
		IF block = firstBlock THEN
			firstBlock := block.next
		ELSE
			current := firstBlock;
			WHILE (current.next # NIL) & (current.next # block) DO
				current := current.next;
			END;
			ASSERT(current # NIL);
			current.next := block.next;
		END;
		hash.Put(current.identifier.name, unused);
	END RemoveBlock;

	PROCEDURE RemovePrefixed*(prefix: ObjectFile.SegmentedName);
	VAR block: Block;
	BEGIN
		WHILE (firstBlock # NIL) & ObjectFile.IsPrefix(prefix, firstBlock.identifier.name) DO
			IF hash.Get(firstBlock.identifier.name) # NIL THEN hash.Put(firstBlock.identifier.name, unused) END;
			firstBlock := firstBlock.next;
		END;
		IF firstBlock = NIL THEN
			RETURN
		END;
		block := firstBlock;
		(* invariant: block # NIL & block.identifier.name not prefixed by prefix *)
		WHILE (block.next # NIL) DO
			IF ObjectFile.IsPrefix(prefix, block.next.identifier.name) THEN
				IF hash.Get(block.next.identifier.name) # NIL THEN hash.Put(block.next.identifier.name, unused) END;
				block.next := block.next.next;
			ELSE
				block := block.next;
			END;
		END;
	END RemovePrefixed;


	PROCEDURE AddSection* (CONST section: ObjectFile.Section);
	VAR block, current, previous,newBlock: Block; name: ARRAY 256 OF CHAR; i: SIZE; alias: ObjectFile.Alias;
	BEGIN
		IF FindBlock (section.identifier) # NIL THEN ObjectFile.SegmentedNameToString(section.identifier.name,name); Error (name, "duplicated section"); RETURN; END;
		NEW (block); ObjectFile.CopySection (section, block^); block.address := InvalidAddress; block.referenced := FALSE; block.used := FALSE;
		current := firstBlock; previous := NIL;
		block.priority := GetPriority(block);
		WHILE (current # NIL) & ~Precedes(block,current) DO previous := current; current := current.next; END;
		IF previous # NIL THEN previous.next := block; ELSE firstBlock := block; END; block.next := current;
		current := block;
		(* append all alias blocks after the block *)
		FOR i := 0 TO block.aliases-1 DO
			alias := block.alias[i];
			NEW(newBlock);
			newBlock.identifier := alias.identifier;
			newBlock.address := alias.offset;
			newBlock.aliasOf := block;
			newBlock.used := block.used;
			newBlock.next := current.next;
			current.next := newBlock;
			current := newBlock;
		END;
	END AddSection;

	PROCEDURE EnterBlocks*;
	VAR current: Block;
	BEGIN
		current := firstBlock;
		WHILE (current # NIL) DO
			hash.Put(current.identifier.name, current);
			ExportBlock(current);
			current := current.next;
		END;
	END EnterBlocks;


	PROCEDURE Resolve*;
	VAR block: Block; used: BOOLEAN; name: ARRAY 256 OF CHAR;
	BEGIN
		IF ~error THEN block := firstBlock;
			WHILE (block # firstLinkedBlock) & ~error DO
				ObjectFile.SegmentedNameToString(block.identifier.name, name);
				used := (block.priority IN usedCategories) OR (linkRoot # "") & Strings.StartsWith(linkRoot,0,name) OR (block.aliases > 0);
				Reference (block, used); block := block.next;
			END;
		END;
	END Resolve;

	PROCEDURE PatchAlias*(block: Block);
	BEGIN
		IF block.aliasOf # NIL THEN INC(block.address, block.aliasOf.address) END;
	END PatchAlias;

	PROCEDURE Link*;
	VAR block: Block;
	BEGIN
		(*
		IF ~error THEN block := firstBlock; WHILE block # firstLinkedBlock DO Aliases (block); block := block.next; END; END;
		*)
		Resolve;

		IF ~error THEN block := firstBlock; WHILE block # firstLinkedBlock DO IF block.used & (block.aliasOf=NIL) THEN Prearrange (block); END; block := block.next; END; END;
		IF ~error THEN block := firstBlock; WHILE block # firstLinkedBlock DO IF block.used & (block.aliasOf=NIL) THEN Arrange (block); END; block := block.next; END; END;
		IF ~error THEN block := firstBlock; WHILE block # firstLinkedBlock DO PatchAlias (block); block := block.next; END; END;

		IF ~error THEN block := firstBlock; WHILE block # firstLinkedBlock DO IF block.used & (block.aliasOf = NIL) THEN Patch (block); END; block := block.next; END; END;
		IF ~error THEN firstLinkedBlock := firstBlock; END;
		IF ~error & (log # NIL) THEN block := firstBlock; WHILE block # NIL DO Diagnose (block); block := block.next; END; END;
	END Link;

	PROCEDURE Reference (block: Block; used: BOOLEAN);
	VAR i: SIZE;

		PROCEDURE ReferenceFixup (CONST fixup: ObjectFile.Fixup);
		VAR reference: Block; str,name: ARRAY 256 OF CHAR;
		BEGIN
			reference := FindBlock (fixup.identifier);
			IF reference = NIL THEN reference := ImportBlock(fixup) END;

			IF reference = NIL THEN
				ObjectFile.SegmentedNameToString(fixup.identifier.name,str); Strings.Append(str," in " );
				ObjectFile.SegmentedNameToString(block.identifier.name,name);
				Strings.Append(str,  name);
				Error(str, "unresolved");
			ELSIF (reference.identifier.fingerprint # 0) & (fixup.identifier.fingerprint # 0) & (reference.identifier.fingerprint # fixup.identifier.fingerprint) THEN
				ObjectFile.SegmentedNameToString(fixup.identifier.name,str); Strings.Append(str," in " );
				ObjectFile.SegmentedNameToString(block.identifier.name,name);
				Strings.Append(str,  name);
				Error (str, "incompatible");
			ELSE Reference (reference, block.used); END;
		END ReferenceFixup;

	BEGIN
		IF used & ~block.used THEN block.used := TRUE;
		ELSIF block.referenced THEN RETURN; END; block.referenced := TRUE;
		IF ~used THEN RETURN END;
		FOR i := 0 TO block.fixups - 1 DO
			ReferenceFixup (block.fixup[i]);
			IF error THEN RETURN END;
		END;
	END Reference;

	PROCEDURE Prearrange (block: Block);
	VAR arrangement: Arrangement;
	BEGIN
		ASSERT (block.used);
		arrangement := GetArrangement (block);
		arrangement.Preallocate (block^);
	END Prearrange;

	PROCEDURE Arrange (block: Block);
	VAR arrangement: Arrangement;
	BEGIN
		ASSERT (block.used);
		arrangement := GetArrangement (block);
		block.address := arrangement.Allocate (block^);
		IF block.address = InvalidAddress THEN ErrorP (block.identifier.name, "failed to allocate"); RETURN; END;
		IF block.fixed THEN IF block.address # block.alignment THEN ErrorP (block.identifier.name, "address allocation problem"); RETURN END;
		ELSE ASSERT ((block.alignment = 0) OR (block.address MOD block.alignment = 0)); END;
	END Arrange;

	PROCEDURE Patch (block: Block);
	VAR arrangement: Arrangement; i: SIZE;

		PROCEDURE PatchFixup (CONST fixup: ObjectFile.Fixup);
		VAR reference: Block; target, address: Address; i: SIZE;

			PROCEDURE PatchPattern (CONST pattern: ObjectFile.FixupPattern);
			BEGIN arrangement.Patch (target, address, pattern.offset, pattern.bits, block.unit); address := ASH (address, -pattern.bits);
			END PatchPattern;

			PROCEDURE CheckBits(pattern: ObjectFile.Pattern; offset: ObjectFile.Unit);
			VAR i: SIZE; nobits, remainder: ObjectFile.Bits; minval, maxval: ObjectFile.Unit; name: ObjectFile.SectionName; number: ARRAY 32 OF CHAR;
			BEGIN
				nobits := 0;
				FOR i := 0 TO pattern.patterns-1 DO
					INC(nobits,pattern.pattern[i].bits);
				END;
				remainder := ObjectFile.Bits(ASH(address,-nobits));

				IF  (nobits <32) & ((remainder > 0) OR (remainder < -1)) THEN
					IF pattern.mode = ObjectFile.Relative THEN (* negative values allowed *)
						maxval := ASH(1,nobits-1)-1; minval := -maxval-1
					ELSE
						minval := 0; maxval := ASH(1,nobits);
					END;
					ObjectFile.SegmentedNameToString(block.identifier.name,name);
					Strings.Append(name,":");
					Strings.IntToStr(offset,number);
					Strings.Append(name,number);
					Error(name,"fixup out of range");
				END;
			END CheckBits;

			PROCEDURE ApplyPatch(pattern: ObjectFile.Pattern; CONST patch: ObjectFile.Patch);
			VAR j: SIZE;
			BEGIN
				target := block.address + patch.offset;
				address := reference.address + patch.displacement;
				IF pattern.mode = ObjectFile.Relative THEN
					DEC(address,target)
				END;
				address := ASH (address, pattern.scale);
				CheckBits(pattern, patch.offset);
				FOR j := 0 TO pattern.patterns-1 DO PatchPattern(pattern.pattern[j]) END;
			END ApplyPatch;

		BEGIN
			reference := FindBlock (fixup.identifier);
			IF reference = NIL THEN reference := ImportBlock(fixup) END;
			ASSERT (reference # NIL);
			FOR i := 0 TO fixup.patches-1 DO
				ApplyPatch(fixup.pattern, fixup.patch[i]);
				arrangement.CheckReloc(block.address, fixup.pattern, fixup.patch[i])
			END;
		END PatchFixup;

	BEGIN
		ASSERT (block.used);
		arrangement := GetArrangement (block);
		FOR i := 0 TO block.fixups - 1 DO
			PatchFixup (block.fixup[i])
		END;
	END Patch;

	PROCEDURE Diagnose (block: Block);
	VAR source, num,name: ARRAY 128 OF CHAR; msg: ARRAY 512 OF CHAR;
	BEGIN
		IF block.used THEN
			Strings.IntToHexStr(block.address, 8, num);
			source := "";
			Strings.Append(source,"0");
			Strings.Append(source, num);
			Strings.Append(source,"H");

			msg := "";

			ObjectFile.SegmentedNameToString(block.identifier.name, name);

			IF ObjectFile.IsCode(block.type) THEN msg := " code "
			ELSE msg := " data "
			END;

			Strings.Append(msg, name);

			IF block.bits # NIL THEN
				Strings.Append(msg, " to ");
				Strings.IntToHexStr(block.address+block.bits.GetSize() DIV block.unit-1, 8, num);
				Strings.Append(msg,"0");
				Strings.Append(msg, num);
				Strings.Append(msg,"H");
				(*Strings.IntToStr(block.address+block.bits.GetSize() DIV block.unit-1, num);
				Strings.Append(msg,num);
				*)
			END;
			(*
			Strings.IntToStr(block.address, num);
			Strings.Append(msg," ("); Strings.Append(msg,num); Strings.Append(msg,")");
			*)
			Information (source, msg);
		ELSE InformationP (block.identifier.name, "unused"); END;
	END Diagnose;

END Linker;

VAR unused: Block;

PROCEDURE GetPriority(block: Block): INTEGER;
BEGIN
	IF block.fixed THEN RETURN Fixed END;
	IF block.type = ObjectFile.InitCode THEN RETURN InitCode END;
	IF block.type = ObjectFile.EntryCode THEN RETURN EntryCode END;
	IF block.type = ObjectFile.ExitCode THEN RETURN ExitCode END;
	IF (block.bits = NIL) OR (block.bits.GetSize () = 0) THEN RETURN Empty END;
	IF block.type = ObjectFile.BodyCode THEN RETURN Code END;
	IF block.type = ObjectFile.Code THEN RETURN Code END;
	IF block.type = ObjectFile.Data THEN RETURN Code END;
	IF block.type = ObjectFile.Const THEN RETURN Code END;
	HALT(100); (* undefined type *)
END GetPriority;

PROCEDURE ReadHeader(reader: Streams.Reader; linker: Linker; VAR binary: BOOLEAN; VAR poolMap: ObjectFile.PoolMap; VAR offers, requires: ObjectFile.NameList);
VAR ch: CHAR; version: INTEGER; string: ARRAY 32 OF CHAR;
BEGIN
	reader.String(string);
	binary := string="FoxOFB";
	IF ~binary THEN ASSERT(string="FoxOFT") END;
	reader.SkipWhitespace;
	reader.Char(ch); ASSERT(ch='v');
	reader.Int(version,FALSE);
	IF (version # ObjectFile.Version) & (linker # NIL) THEN linker.Error("","invalid object file version encountered. Recompile sources.") END;
	reader.Char(ch); ASSERT(ch='.');
	IF ~binary THEN reader.SkipWhitespace
	ELSE
		NEW(poolMap,64);
		poolMap.Read(reader);
	END;

	offers := NIL;
	requires := NIL;
	IF ~binary THEN
		reader.String(string);
		ASSERT(string = "offers");
		ObjectFile.ReadNameList(reader, offers, binary, poolMap);
		reader.SkipWhitespace;
		reader.String(string);
		ASSERT(string = "requires");
		ObjectFile.ReadNameList(reader, requires, binary, poolMap);
		reader.SkipWhitespace;
	ELSE
		ObjectFile.ReadNameList(reader, offers, binary, poolMap);
		ObjectFile.ReadNameList(reader, requires, binary, poolMap);
	END
END ReadHeader;

PROCEDURE OffersRequires*(reader: Streams.Reader; VAR offers, requires: ObjectFile.NameList);
VAR binary: BOOLEAN; poolMap: ObjectFile.PoolMap;
BEGIN
	ReadHeader(reader, NIL, binary, poolMap, offers, requires);
END OffersRequires;

PROCEDURE Load* (reader: Streams.Reader; linker: Linker);
VAR section: ObjectFile.Section; binary: BOOLEAN; poolMap: ObjectFile.PoolMap; offers, requires: ObjectFile.NameList;
BEGIN
	ReadHeader(reader, linker, binary, poolMap, offers, requires);
	linker.SetOffers(offers);
	linker.SetRequires(requires);
	WHILE reader.Peek () # 0X DO
		ObjectFile.ReadSection (reader, section,binary,poolMap);
		reader.SkipWhitespace;
		IF reader.res = Streams.Ok THEN linker.AddSection (section); END;
	END;
END Load;

BEGIN
	NEW(unused);
END GenericLinker.

Compiler.Compile GenericLinker.Mod   ~~~
