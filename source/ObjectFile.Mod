MODULE ObjectFile;	(* AUTHOR "negelef"; PURPOSE "Generic Object File Representation"; *)

IMPORT Streams, BitSets, StringPool, Strings;

CONST
	Version* = 8;

	(* Fixup modes *)
	Absolute* = 0;
	Relative* = 1;

	(* Section categories *)
	(* code section categories, ordered by decreasing linking preference *)
	EntryCode*= 0; (* entry code sections provide the entry point for static linking, enry code runs before module initializer callers *)
	InitCode*=1; (* initcode sections provide the entry point for static linking. A static linker includes this sections, a dynamic linker wants to omit them *)
	ExitCode*=2; (* exit code sections close a statically linked code, are executed after all init code callers *)
	BodyCode*=3; (* body code sections provide the entry point for dynamic linking. A dynamic linker needs to be able to distinguish them from normal code *)
	Code*=4; (* normal executable code *)
	(* data section categories *)
	Data* = 5; (* data sections provide space for (global) variables *)
	Const* = 6; (* const sections are data sections that are immutable *)

	(* alignment types *)
	Aligned=0;
	Fixed=1;

	DefaultExtension* = ".Gof";

TYPE
	Unit* = SIZE;
	Bits* = SIZE;

	Fingerprint* = SIGNED64;

	SegmentedName*= ARRAY 8 OF StringPool.Index;
	SectionName* = ARRAY 128 OF CHAR;

	(* FixupPattern = size (+|-) bits {size (+|-) bits}

		Example:
		fixupPattern = 0+8 -128+4 8-8 means
			store first 8 bits to offset 0
			leave out next 4 bits
			store next 8 bits to offset 8 in reverse order

		most frequently used are
			fixupPattern=0+8 : 8 bit fixup
			fixupPattern=0+16: 16 bit fixup
			fixupPattern=0+32: 32 bit fixup
	*)
	FixupPattern* = RECORD
		offset*, bits*: Bits;
	END;
	FixupPatterns*= POINTER TO ARRAY OF FixupPattern;

	Identifier*= RECORD
		name*: SegmentedName;
		fingerprint*: Fingerprint;
	END;

	Pattern*= POINTER TO RECORD (* this is the same for many fixups *)
		mode-: INTEGER;
		scale-: Bits;
		patterns-: SIZE;
		pattern-: FixupPatterns
	END;

	Patch*= RECORD
		offset-, displacement-: Unit;
	END;
	Patches*= POINTER TO ARRAY OF Patch;

	Fixup* = RECORD
		identifier*: Identifier;
		pattern-: Pattern;
		index*: SIZE;
		patches*: SIZE;
		patch*: Patches;
	END;

	Alias*= RECORD
		identifier*: Identifier;
		offset-: Unit
	END;

	Fixups*=POINTER TO ARRAY OF Fixup;

	Aliases*= POINTER TO ARRAY OF Alias;

	Section* = RECORD
		type*: INTEGER;
		identifier*: Identifier;
		unit*: Bits;
		fixed*: BOOLEAN;
		alignment*: Unit;
		fixups-: SIZE;
		fixup-: Fixups;
		aliases-: SIZE;
		alias-: Aliases;
		bits*: BitSets.BitSet;
	END;

	PoolMap* = OBJECT
	TYPE
		Table = POINTER TO ARRAY OF RECORD key, value: SIZE END;

	VAR
		table: Table;
		size: SIZE;
		used: SIZE;
		maxLoadFactor: FLOAT32;
		writer: Streams.Writer;
		(* Interface *)

		PROCEDURE & Init* (initialSize: SIZE);
		BEGIN
			ASSERT(initialSize > 2);
			NEW(table, initialSize);
			size := initialSize;
			used := 0;
			maxLoadFactor := 0.75;
			Clear;
			Put(0,0); (* empty string mapped one-to-one *)
		END Init;

		PROCEDURE Put(key, value: SIZE);
		VAR hash: SIZE;
		BEGIN
			ASSERT(used < size);
			ASSERT(key >= 0);
			hash := HashValue(key);
			IF table[hash].key <0  THEN
				INC(used, 1);
				table[hash].key := key;
			ELSE
				ASSERT(table[hash].key = key);
			END;
			table[hash].value := value;

			IF (used / size) > maxLoadFactor THEN Grow END;
		END Put;

		PROCEDURE Get*(key: SIZE):SIZE;
		BEGIN
			IF key = -1 THEN
				RETURN -1
			ELSE
				RETURN table[HashValue(key)].value;
			END
		END Get;

		PROCEDURE Has*(key: SIZE):BOOLEAN;
		BEGIN
			RETURN table[HashValue(key)].key = key;
		END Has;

		PROCEDURE Clear*;
		VAR i: SIZE;
		BEGIN
			FOR i := 0 TO size - 1 DO table[i].key := -1; END;
		END Clear;

		(* only correctly working, if NIL key cannot be entered *)
		PROCEDURE HashValue(key: SIZE): SIZE;
		VAR value, h, i: SIZE;
		BEGIN
			value := key;
			i := 0;
			h := value MOD size;
			REPEAT
				value := (h + i) MOD size;
				INC(i);
			UNTIL((table[value].key  < 0) OR (table[value].key = key) OR (i > size));
			ASSERT((table[value].key <0)  OR (table[value].key = key));
			RETURN value;
		END HashValue;

		PROCEDURE Grow;
		VAR oldTable: Table; oldSize, i, key: SIZE;
		BEGIN
			oldSize := size;
			oldTable := table;
			Init(size*2);
			FOR i := 0 TO oldSize-1 DO
				key := oldTable[i].key;
				IF key >=0 THEN
					Put(key, oldTable[i].value);
				END;
			END;
		END Grow;

		(** read map and produce Local --> Global **)
		PROCEDURE Read*(reader: Streams.Reader);
		VAR value, pos: SIZE; name: SectionName;
		BEGIN
			pos := 1;
			reader.RawString(name);
			WHILE name[0] # 0X DO
				StringPool.GetIndex(name,value);
				Put(pos,value);
				INC(pos);
				reader.RawString(name);
			END;
		END Read;

		(** write global --> local map **)
		PROCEDURE PutGlobal*(key: SIZE);
		VAR name: SectionName;
		BEGIN
			IF ~Has(key) THEN
				Put(key, used);
				StringPool.GetString(key, name);
				writer.RawString(name);
			END;
		END PutGlobal;

		PROCEDURE PutSegmentedName*(CONST name: SegmentedName);
		VAR i: SIZE;
		BEGIN
			FOR i := 0 TO LEN(name)-1 DO
				IF name[i] < 0 THEN RETURN END;
				PutGlobal(name[i]);
			END;
		END PutSegmentedName;

		PROCEDURE BeginWriting*(w: Streams.Writer);
		BEGIN
			writer := w;
		END BeginWriting;

		PROCEDURE EndWriting*;
		BEGIN
			writer.RawString("");
			writer := NIL;
		END EndWriting;

	END PoolMap;

	NameList*= POINTER TO ARRAY OF SegmentedName;

VAR
	categories: ARRAY 8 OF ARRAY 10 OF CHAR;
	modes: ARRAY 2 OF ARRAY 4 OF CHAR;
	relocatabilities: ARRAY 2 OF ARRAY 8 OF CHAR;

	statHeaders, statHeadersSize: SIZE;
	statFixups, statFixupsSize, statFixupPatterns, statFixupPatches: SIZE;
	statAliases, statAliasesSize: SIZE;
	statSegments, statSegmentsSize: SIZE;

	statCodeSections, statCodeSectionsSize: SIZE;
	statDataSections, statDataSectionsSize: SIZE;
	statConstSections, statConstSectionsSize: SIZE;
	statInitSections, statInitSectionsSize: SIZE;
	statBodySections, statBodySectionsSize: SIZE;

	statSections, statSectionsTotalSize: SIZE;

	PROCEDURE IsCode* (type: INTEGER): BOOLEAN;
	BEGIN RETURN (type IN {EntryCode .. Code})
	END IsCode;

	PROCEDURE Matches*(CONST this, that: Identifier): BOOLEAN;
	BEGIN
		IF (this.fingerprint # 0) & (this.fingerprint = that.fingerprint) THEN RETURN TRUE
		ELSE RETURN (this.name = that.name)
		END;
	END Matches;

	PROCEDURE CopyIdentifier(CONST source: Identifier; VAR dest: Identifier);
	BEGIN
		dest.name := source.name; dest.fingerprint := source.fingerprint
	END CopyIdentifier;

	PROCEDURE CopyPattern( source: Pattern; VAR dest: Pattern);
	VAR i: SIZE;
	BEGIN
		NEW(dest);
		dest.mode := source.mode;
		dest.scale := source.scale;
		dest.patterns := source.patterns;
		NEW(dest.pattern, dest.patterns);
		FOR i := 0 TO LEN(dest.pattern)-1 DO
			dest.pattern[i] := source.pattern[i];
		END;
	END CopyPattern;

	PROCEDURE CopyPatches(sourcePatches: SIZE; source: Patches; VAR destPatches: SIZE; VAR dest: Patches);
	VAR i: SIZE;
	BEGIN
		destPatches := sourcePatches;
		NEW(dest, destPatches);
		FOR i := 0 TO destPatches-1 DO
			dest[i] := source[i]
		END;
	END CopyPatches;

	PROCEDURE CopyFixup*(source: Fixup; VAR dest: Fixup);
	BEGIN
		CopyIdentifier(source.identifier, dest.identifier);
		CopyPattern(source.pattern, dest.pattern);
		CopyPatches(source.patches, source.patch, dest.patches, dest.patch);
	END CopyFixup;

	PROCEDURE CopyAlias*(CONST source: Alias; VAR dest: Alias);
	BEGIN
		CopyIdentifier(source.identifier, dest.identifier);
		dest.offset := source.offset;
	END CopyAlias;

	PROCEDURE CopySection* (CONST source: Section; VAR dest: Section);
	VAR i: SIZE;
	BEGIN
		dest.type := source.type;
		dest.identifier := source.identifier;
		dest.unit := source.unit;
		dest.fixed := source.fixed;
		dest.alignment := source.alignment;

		dest.fixups:= source.fixups;
		dest.aliases := source.aliases;
		NEW (dest.fixup, dest.fixups);
		FOR i := 0 TO dest.fixups - 1 DO
			CopyFixup(source.fixup[i], dest.fixup[i]);
		END;
		NEW (dest.alias, dest.aliases);
		FOR i := 0 TO dest.aliases - 1 DO
			CopyAlias(source.alias[i], dest.alias[i]);
		END;
		NEW (dest.bits, source.bits.GetSize ());
		BitSets.CopyBits (source.bits, 0, dest.bits, 0, source.bits.GetSize ());
	END CopySection;

	PROCEDURE InitSection*(VAR dest: Section);
	BEGIN
		dest.type := 0;
		dest.identifier.name := "";
		dest.identifier.fingerprint := 0;
		dest.unit := 0;
		dest.fixed := FALSE;
		dest.alignment := 0;

		dest.fixups:= 0;
		dest.aliases := 0;
		dest.fixup := NIL;
		dest.alias := NIL;
		dest.bits := NIL;
	END InitSection;

	PROCEDURE NibbleToCharacter* (value: INTEGER): CHAR;
	BEGIN
		IF value >= 10 THEN
			RETURN CHR ((ORD ('A') - 10) + value);
		ELSE
			RETURN CHR (ORD ('0') + value);
		END;
	END NibbleToCharacter;

	PROCEDURE CharacterToNibble* (char: CHAR): INTEGER;
	BEGIN
		IF ORD (char) >= ORD ('A') THEN
			RETURN ORD (char) - (ORD ('A') - 10);
		ELSE
			RETURN ORD (char) - ORD ('0');
		END;
	END CharacterToNibble;

	PROCEDURE WriteSectionTextual (writer: Streams.Writer; CONST section: Section);
	CONST Separator = ' '; Tab = 09X;
	VAR i: SIZE; offset,start, len, size: Bits;

		PROCEDURE WriteValueIdentifier (value: INTEGER; CONST identifiers: ARRAY OF ARRAY OF CHAR);
		BEGIN
			writer.String (identifiers[value]);
		END WriteValueIdentifier;

		PROCEDURE WriteFixupPattern (CONST pattern: FixupPattern);
		BEGIN
			writer.Int (pattern.offset, 0);
			writer.Char (Separator);
			writer.Int (pattern.bits, 0);
		END WriteFixupPattern;

		PROCEDURE WriteIdentifier(CONST identifier: Identifier);
		VAR name: SectionName;
		BEGIN
			SegmentedNameToString(identifier.name, name);
			writer.String (name);
			writer.Char (Separator);
			writer.Hex (identifier.fingerprint, 0);
		END WriteIdentifier;

		PROCEDURE WritePattern(pattern: Pattern);
		VAR i: SIZE;
		BEGIN
			WriteValueIdentifier (pattern.mode, modes);
			writer.Char (Separator);
			writer.Int (pattern.scale, 0);
			writer.Char (Separator);
			writer.Size (pattern.patterns);
			writer.Char (Separator);
			FOR i := 0 TO pattern.patterns - 1 DO
				WriteFixupPattern (pattern.pattern[i]);
				writer.Char (Separator);
			END;
		END WritePattern;

		PROCEDURE WritePatch (CONST patch: Patch);
		BEGIN
			writer.Int (patch.displacement, 0);
			writer.Char (Separator);
			writer.Int (patch.offset, 0);
		END WritePatch;

		PROCEDURE WriteFixup (CONST fixup: Fixup);
		VAR i: SIZE;
		BEGIN
			WriteIdentifier(fixup.identifier);
			writer.Char (Separator);
			WritePattern(fixup.pattern);
			writer.Char(Separator);
			writer.Size(fixup.patches);
			writer.Char(Separator);
			FOR i := 0 TO fixup.patches-1 DO
				WritePatch(fixup.patch[i]);
				writer.Char (Separator);
			END;
		END WriteFixup;

		PROCEDURE WriteAlias (CONST alias: Alias);
		BEGIN
			WriteIdentifier(alias.identifier);
			writer.Char (Separator);
			writer.Int (alias.offset, 0);
		END WriteAlias;

		PROCEDURE Zeros(offset: Bits): Bits;
		VAR zeros: Bits;
		BEGIN
			zeros := 0;
			WHILE (offset < size) & (section.bits.GetBits(offset, MIN(4, size-offset)) = 0) DO
				INC(zeros);
				INC(offset,4);
			END;
			RETURN zeros
		END Zeros;

		PROCEDURE GetSegment(VAR offset, start, len: Bits): BOOLEAN;
		VAR zeros: Bits;
		BEGIN
			INC(offset, Zeros(offset)*4);
			start := offset;
			len := 0;
			WHILE (offset < size) DO
				zeros := Zeros(offset);
				INC(offset, zeros*4);
				IF (zeros > 8) OR (offset >= size) THEN
					RETURN TRUE;
				ELSE
					INC(len, zeros*4);
					INC(len,4); INC(offset,4); (* non-zero element *)
				END;
			END;
			RETURN len > 0;
		END GetSegment;

		PROCEDURE WriteSegment(offset, len: Bits);
		VAR value: INTEGER;
		BEGIN
			ASSERT(len MOD 4 = 0); ASSERT(offset MOD 4 = 0);
			len := len DIV 4;
			writer.Int(len,1); writer.Char(Separator); writer.Int(offset DIV 4,1); writer.Char(Separator);
			WHILE len > 0 DO
				value := section.bits.GetBits(offset, MIN(4, size-offset));
				writer.Char(NibbleToCharacter(value));
				INC(offset, 4);
				DEC(len);
			END;
			writer.Ln;
		END WriteSegment;

	BEGIN
		IF section.type > Const THEN RETURN END; (* ignore exotic sections *)
		WriteValueIdentifier (section.type, categories);
		writer.Char (Separator);
		WriteIdentifier(section.identifier);
		writer.Char (Separator);
		writer.Int (section.unit, 0);
		writer.Char (Separator);
		IF section.fixed THEN WriteValueIdentifier(Fixed,relocatabilities) ELSE WriteValueIdentifier(Aligned,relocatabilities) END;
		writer.Char (Separator);
		writer.Int (section.alignment, 0);
		writer.Char (Separator);

		writer.Size (section.aliases);
		writer.Char (Separator);
		writer.Size (section.fixups);
		writer.Char (Separator);
		size := section.bits.GetSize ();
		writer.Int (size DIV section.unit, 1);
		ASSERT(size MOD section.unit = 0);
		FOR i := 0 TO section.aliases - 1 DO
			writer.Ln; writer.Char (Tab); WriteAlias (section.alias[i]);
		END;
		FOR i := 0 TO section.fixups - 1 DO
			writer.Ln; writer.Char (Tab); WriteFixup (section.fixup[i]);
		END;
		writer.Ln;
		offset := 0;
		WHILE GetSegment(offset, start, len) DO
			WriteSegment(start, len)
		END;
		writer.Int(0,1); writer.Ln;
		writer.Ln;
	END WriteSectionTextual;

	PROCEDURE ReadSectionTextual (reader: Streams.Reader; VAR section: Section);
	VAR i: SIZE; size: SIZE; char: CHAR; relocatibility: INTEGER;

		PROCEDURE ReadValueIdentifier (VAR value: INTEGER; CONST identifiers: ARRAY OF ARRAY OF CHAR);
		VAR identifier: ARRAY 10 OF CHAR;
		BEGIN
			value := 0;
			reader.SkipWhitespace; reader.String (identifier);
			WHILE (value # LEN (identifiers)) & (identifier # identifiers[value]) DO INC (value); END;
			IF value = LEN (identifiers) THEN reader.res := Streams.FormatError; END;
		END ReadValueIdentifier;

		PROCEDURE ReadFixupPattern (VAR pattern: FixupPattern);
		BEGIN
			reader.SkipWhitespace; reader.Size (pattern.offset, FALSE);
			reader.SkipWhitespace; reader.Size (pattern.bits, FALSE);
		END ReadFixupPattern;

		PROCEDURE ReadIdentifier(VAR identifier: Identifier);
		VAR name: SectionName;
		BEGIN
			reader.SkipWhitespace;
			reader.String(name);
			StringToSegmentedName(name,identifier.name);
			reader.SkipWhitespace; reader.HInt (identifier.fingerprint,TRUE);
		END ReadIdentifier;

		PROCEDURE ReadPattern(VAR pattern: Pattern);
		VAR i: SIZE;
		BEGIN
			reader.SkipWhitespace;
			ReadValueIdentifier (pattern.mode, modes);
			reader.SkipWhitespace; reader.Size (pattern.scale, FALSE);
			reader.SkipWhitespace; reader.Size (pattern.patterns, FALSE);

			IF (pattern.pattern = NIL) OR (LEN (pattern.pattern) < pattern.patterns) THEN
				NEW (pattern.pattern, pattern.patterns);
			END;
			FOR i := 0 TO pattern.patterns - 1 DO
				ReadFixupPattern (pattern.pattern[i]);
			END;
		END ReadPattern;

		PROCEDURE ReadPatch (VAR patch: Patch);
		BEGIN
			reader.SkipWhitespace; reader.Size (patch.displacement, FALSE);
			reader.SkipWhitespace; reader.Size (patch.offset, FALSE);
		END ReadPatch;

		PROCEDURE ReadFixup (VAR fixup: Fixup);
		VAR i: SIZE;
		BEGIN
			reader.SkipWhitespace; ReadIdentifier (fixup.identifier);
			IF fixup.pattern = NIL THEN NEW(fixup.pattern) END;
			reader.SkipWhitespace; ReadPattern(fixup.pattern);
			reader.SkipWhitespace; reader.Size (fixup.patches, FALSE);
			IF (fixup.patch = NIL) OR (LEN (fixup.patch) < fixup.patches) THEN
				NEW (fixup.patch, fixup.patches);
			END;
			FOR i := 0 TO fixup.patches - 1 DO
				ReadPatch (fixup.patch[i]);
			END;
		END ReadFixup;

		PROCEDURE ReadAlias (VAR alias: Alias);
		BEGIN
			reader.SkipWhitespace; ReadIdentifier (alias.identifier);
			reader.SkipWhitespace; reader.Size(alias.offset,FALSE);
		END ReadAlias;

		PROCEDURE ReadSegment(): BOOLEAN;
		VAR len, offset: Bits;
		BEGIN
			reader.Size(len,FALSE);
			reader.SkipWhitespace;
			IF len = 0 THEN RETURN FALSE END;
			reader.Size(offset,FALSE); offset := offset * 4;
			reader.SkipWhitespace;
			WHILE len > 0 DO
				reader.Char (char);
				section.bits.SetBits (offset, MIN (4, size - offset), CharacterToNibble (char));
				DEC(len); INC(offset,4);
			END;
			RETURN TRUE
		END ReadSegment;

	BEGIN
		ReadValueIdentifier (section.type, categories);
		ReadIdentifier (section.identifier);
		reader.SkipWhitespace; reader.Size (section.unit, FALSE);
		ReadValueIdentifier(relocatibility, relocatabilities);
		section.fixed := relocatibility = Fixed;
		reader.SkipWhitespace; reader.Size (section.alignment, FALSE);
		reader.SkipWhitespace; reader.Size (section.aliases, FALSE);
		reader.SkipWhitespace; reader.Size (section.fixups, FALSE);
		reader.SkipWhitespace; reader.Size (size, FALSE); size := size * section.unit;
		IF (section.aliases > 0) & ((section.alias = NIL) OR (LEN (section.alias) < section.aliases)) THEN
			NEW (section.alias, section.aliases);
		END;
		FOR i := 0 TO section.aliases - 1 DO
			ReadAlias (section.alias[i]);
		END;
		IF (section.fixups > 0) & ((section.fixup = NIL) OR (LEN (section.fixup) < section.fixups)) THEN
			NEW (section.fixup, section.fixups);
		END;
		FOR i := 0 TO section.fixups - 1 DO
			ReadFixup (section.fixup[i]);
			ASSERT(section.fixup[i].patch # NIL);
		END;
		IF section.bits # NIL THEN
			section.bits.Resize (size);
			section.bits.Zero();
		ELSE
			NEW (section.bits, size);
		END;
		REPEAT
			reader.SkipWhitespace()
		UNTIL ~ReadSegment()
	END ReadSectionTextual;

	PROCEDURE ReadNameList*(reader: Streams.Reader; VAR nameList: NameList; binary: BOOLEAN; poolMap: PoolMap);
	VAR i, len: SIZE; name: ARRAY 256 OF CHAR;

		PROCEDURE ReadIdentifier(VAR name: SegmentedName);
		VAR i: SIZE; num: SIZE;
		BEGIN
			i := 0;
			REPEAT
				reader.RawSize(num);
				name[i] := poolMap.Get(num);
				INC(i);
			UNTIL (i = LEN(name)) OR (num < 0);
			WHILE i < LEN(name) DO
				name[i] := -1; INC(i);
			END;
		END ReadIdentifier;

	BEGIN
		IF binary THEN
			reader.RawSize(len);
			NEW(nameList, len);
			FOR i := 0 TO len-1 DO
				ReadIdentifier(nameList[i]);
			END;
		ELSE
			reader.SkipWhitespace;
			reader.Size(len,FALSE);
			NEW(nameList, len);
			FOR i := 0 TO len-1 DO
				reader.SkipWhitespace;
				reader.String(name);
				nameList[i] := name;
			END;
		END;
	END ReadNameList;

	PROCEDURE WriteNameList*(writer: Streams.Writer; nameList: NameList; binary: BOOLEAN; poolMap: PoolMap);
	VAR i, len: SIZE; name: ARRAY 256 OF CHAR;
	CONST Separator = ' ';

		PROCEDURE WriteIdentifier(CONST name: SegmentedName);
		VAR i: SIZE; num: SIZE;
		BEGIN
			i := 0;
			REPEAT
				num := poolMap.Get(name[i]);
				writer.RawNum(num);
				INC(i);
			UNTIL (i = LEN(name)) OR (num < 0);
		END WriteIdentifier;

	BEGIN
		IF nameList = NIL THEN len := 0
		ELSE len := LEN(nameList);
		END;
		IF binary THEN
			writer.RawNum(len);
			FOR i := 0 TO len-1 DO
				WriteIdentifier(nameList[i]);
			END;
		ELSE
			writer.Int(len,0);
			FOR i := 0 TO len-1 DO
				name := nameList[i];
				writer.Char(Separator);
				writer.String(name);
			END;
			writer.Ln;
		END;
	END WriteNameList;

	PROCEDURE WriteSectionBinary (writer: Streams.Writer; CONST section: Section; poolMap: PoolMap);
	VAR i: SIZE; pos: Streams.Position; offset, start, len, size: Bits;
	CONST ByteSize=8;

		PROCEDURE WriteValueIdentifier (value: INTEGER; CONST identifiers: ARRAY OF ARRAY OF CHAR);
		BEGIN
			writer.RawNum(value);
		END WriteValueIdentifier;

		PROCEDURE WriteFixupPattern (CONST pattern: FixupPattern);
		BEGIN
			writer.RawNum (pattern.offset);
			writer.RawNum (pattern.bits);
			INC(statFixupPatterns);
		END WriteFixupPattern;

		PROCEDURE WriteIdentifier(CONST identifier: Identifier);
		VAR i: SIZE; num: StringPool.Index;
		BEGIN
			i := 0;
			REPEAT
				num := poolMap.Get(identifier.name[i]);
				writer.RawNum(num);
				INC(i);
			UNTIL (i = LEN(identifier.name)) OR (num < 0);
			writer.RawNum (identifier.fingerprint);
		END WriteIdentifier;

		PROCEDURE WritePattern(pattern: Pattern);
		VAR i: SIZE;
		BEGIN
			WriteValueIdentifier (pattern.mode, modes);
			writer.RawNum (pattern.scale);
			writer.RawNum (pattern.patterns);
			FOR i := 0 TO pattern.patterns - 1 DO
				WriteFixupPattern (pattern.pattern[i]);
			END;
		END WritePattern;

		PROCEDURE WritePatch (CONST patch: Patch);
		BEGIN
			writer.RawNum (patch.displacement);
			writer.RawNum (patch.offset);
			INC(statFixupPatches);
		END WritePatch;

		PROCEDURE WriteFixup (CONST fixup: Fixup);
		VAR i: SIZE;
		BEGIN
			INC(statFixups);
			WriteIdentifier(fixup.identifier);
			WritePattern(fixup.pattern);
			writer.RawNum(fixup.patches);
			ASSERT(fixup.patches > 0);
			FOR i := 0 TO fixup.patches-1 DO
				WritePatch(fixup.patch[i]);
			END;
		END WriteFixup;

		PROCEDURE WriteAlias (CONST alias: Alias);
		BEGIN
			WriteIdentifier(alias.identifier);
			writer.RawNum(alias.offset);
		END WriteAlias;

		PROCEDURE Zeros(offset: Bits): Bits;
		VAR zeros: Bits;
		BEGIN
			WHILE (offset < size) & (section.bits.GetBits(offset, MIN(ByteSize, size-offset)) = 0) DO
				INC(zeros);
				INC(offset,ByteSize);
			END;
			RETURN zeros
		END Zeros;

		PROCEDURE GetSegment(VAR offset, start, len: Bits): BOOLEAN;
		VAR zeros: Bits;
		BEGIN
			INC(offset, Zeros(offset)*ByteSize);
			start := offset;
			len := 0;
			WHILE (offset < size) DO
				zeros := Zeros(offset);
				INC(offset, zeros*ByteSize);
				IF (zeros > 2) (* best value evaluated with statistic over whole release *) OR (offset >= size) THEN
					RETURN TRUE;
				ELSE
					ASSERT(offset < size);
					INC(len, zeros*ByteSize);
					INC(len,ByteSize); INC(offset,ByteSize); (* non-zero element *)
				END;
			END;
			RETURN len > 0;
		END GetSegment;

		PROCEDURE WriteSegment(offset, len: Bits);
		VAR value: INTEGER; pos: Streams.Position;
		BEGIN
			pos := writer.Pos();
			ASSERT(len > 0);
			ASSERT(len MOD ByteSize = 0); ASSERT(offset MOD ByteSize = 0);
			len := len DIV ByteSize;
			writer.RawNum(len); writer.RawNum(offset DIV ByteSize);
			WHILE len > 0 DO
				value := section.bits.GetBits(offset, MIN(ByteSize, size-offset));
				INC(offset, ByteSize);
				DEC(len);
				writer.Char(CHR(value));
			END;
			INC(statSegments); INC(statSegmentsSize, SIZE(writer.Pos()-pos));
		END WriteSegment;

	BEGIN
		(* header *)
		pos := writer.Pos();
		IF section.type > Const THEN RETURN END; (* ignore exotic sections *)
		writer.Char(1X);
		WriteValueIdentifier (section.type, categories);
		WriteIdentifier(section.identifier);
		writer.RawNum (section.unit);
		IF section.fixed THEN WriteValueIdentifier(Fixed,relocatabilities) ELSE WriteValueIdentifier(Aligned,relocatabilities) END;
		writer.RawNum (section.alignment);

		writer.RawNum (section.aliases);
		writer.RawNum (section.fixups);
		size := section.bits.GetSize ();
		writer.RawNum (size DIV section.unit);
		INC(statHeaders);
		INC(statHeadersSize, SIZE(writer.Pos()-pos));

		(* aliases *)
		pos := writer.Pos();
		ASSERT(size MOD section.unit = 0);
		FOR i := 0 TO section.aliases - 1 DO
			WriteAlias (section.alias[i]);
		END;
		INC(statAliases, section.aliases);
		INC(statAliasesSize, SIZE(writer.Pos()-pos));

		(* fixups *)
		pos := writer.Pos();
		FOR i := 0 TO section.fixups - 1 DO
			WriteFixup (section.fixup[i]);
		END;
		INC(statFixups, section.fixups);
		INC(statFixupsSize, SIZE(writer.Pos()-pos));

		(* code / data *)
		pos := writer.Pos();
		offset := 0;
		WHILE GetSegment(offset, start, len) DO
			WriteSegment(start, len);
		END;
		writer.RawNum(0);
		CASE section.type OF
			InitCode:  INC(statInitSections); INC(statInitSectionsSize, SIZE(writer.Pos()-pos));
			|BodyCode: INC(statBodySections); INC(statBodySectionsSize, SIZE(writer.Pos()-pos));
			|Code: INC(statCodeSections); INC(statCodeSectionsSize, SIZE(writer.Pos()-pos));
			|Data: INC(statDataSections); INC(statDataSectionsSize, SIZE(writer.Pos()-pos));
			|Const: INC(statConstSections); INC(statConstSectionsSize, SIZE(writer.Pos()-pos));
		ELSE (* ignored *)
		END;
	END WriteSectionBinary;

	PROCEDURE ReadSectionBinary (reader: Streams.Reader; VAR section: Section; poolMap: PoolMap);
	VAR i, size: SIZE; relocatibility: INTEGER; ch: CHAR;;
	CONST ByteSize=8;

		PROCEDURE ReadValueIdentifier (VAR value: INTEGER; CONST identifiers: ARRAY OF ARRAY OF CHAR);
		BEGIN
			reader.RawNum(value);
		END ReadValueIdentifier;

		PROCEDURE ReadIdentifier(VAR identifier: Identifier);
		VAR i: SIZE; num: SIZE;
		BEGIN
			i := 0;
			REPEAT
				reader.RawSize(num);
				identifier.name[i] := poolMap.Get(num);
				INC(i);
			UNTIL (i = LEN(identifier.name)) OR (num < 0);
			WHILE i < LEN(identifier.name) DO
				identifier.name[i] := -1; INC(i);
			END;
			reader.RawHNum (identifier.fingerprint);
		END ReadIdentifier;

		PROCEDURE ReadFixupPattern (VAR pattern: FixupPattern);
		BEGIN
			reader.RawSize (pattern.offset);
			reader.RawSize (pattern.bits);
		END ReadFixupPattern;

		PROCEDURE ReadPattern(VAR pattern: Pattern);
		VAR i: SIZE;
		BEGIN
			ReadValueIdentifier (pattern.mode, modes);
			reader.RawSize (pattern.scale);
			reader.RawSize (pattern.patterns);
			IF (pattern.pattern = NIL) OR (LEN (pattern.pattern) < pattern.patterns) THEN
				NEW (pattern.pattern, pattern.patterns);
			END;
			FOR i := 0 TO pattern.patterns - 1 DO
				ReadFixupPattern (pattern.pattern[i]);
			END;
		END ReadPattern;

		PROCEDURE ReadPatch(VAR patch: Patch);
		BEGIN
			reader.RawSize(patch.displacement);
			reader.RawSize(patch.offset);
		END ReadPatch;

		PROCEDURE ReadFixup (VAR fixup: Fixup);
		VAR i: SIZE;
		BEGIN
			ReadIdentifier (fixup.identifier);
			IF fixup.pattern = NIL THEN NEW(fixup.pattern) END;
			ReadPattern(fixup.pattern);
			reader.RawSize (fixup.patches);
			IF fixup.patches > 0 THEN
				IF (fixup.patch = NIL) OR (LEN (fixup.patch) < fixup.patches) THEN
					NEW (fixup.patch, fixup.patches);
				END;
				FOR i := 0 TO fixup.patches - 1 DO
					ReadPatch (fixup.patch[i]);
				END;
			END;
		END ReadFixup;

		PROCEDURE ReadAlias (VAR alias: Alias);
		BEGIN
			ReadIdentifier (alias.identifier);
			reader.RawSize (alias.offset);
		END ReadAlias;

		PROCEDURE ReadSegment(): BOOLEAN;
		VAR len, offset: Bits; c: CHAR;
			segment: ARRAY 128 OF CHAR;
			received: SIZE;
		BEGIN
			reader.RawSize(len);
			IF len = 0 THEN RETURN FALSE END;
			reader.RawSize(offset); offset := offset * ByteSize;
			WHILE len > LEN(segment) DO
				reader.Bytes(segment, 0, LEN(segment), received);
				ASSERT(received = LEN(segment));
				section.bits.SetBytes(offset, LEN(segment), segment);
				DEC(len, received);
				INC(offset, received*ByteSize);
			END;
			IF size MOD 8 # 0 THEN
				reader.Bytes(segment, 0, len-1, received);
				ASSERT(received = len-1);
				section.bits.SetBytes(offset, received, segment);
				DEC(len, received);
				INC(offset, received*ByteSize);
				(* last byte: only part of a byte *)
				reader.Char(c);
				section.bits.SetBits (offset, MIN (ByteSize, size - offset), ORD(c));
			ELSE
				reader.Bytes(segment, 0, len, received);
				ASSERT(received = len);
				section.bits.SetBytes(offset, received, segment);
			END;
			RETURN TRUE
		END ReadSegment;

	BEGIN
		reader.Char(ch); ASSERT(ch = 1X);
		ReadValueIdentifier (section.type, categories);
		ReadIdentifier (section.identifier);
		reader.RawSize (section.unit);
		ReadValueIdentifier(relocatibility, relocatabilities);
		section.fixed := relocatibility = Fixed;
		reader.RawSize (section.alignment);
		reader.RawSize (section.aliases);
		reader.RawSize (section.fixups);
		reader.RawSize (size); size := size * section.unit;
		IF (section.aliases > 0) &((section.alias = NIL) OR (LEN (section.alias) < section.aliases)) THEN
			NEW (section.alias, section.aliases);
		END;
		FOR i := 0 TO section.aliases - 1 DO
			ReadAlias (section.alias[i]);
		END;
		IF (section.fixups > 0) & ((section.fixup = NIL) OR (LEN (section.fixup) < section.fixups)) THEN
			NEW (section.fixup, section.fixups);
		END;
		FOR i := 0 TO section.fixups - 1 DO
			ReadFixup (section.fixup[i]);
		END;
		IF section.bits # NIL THEN
			section.bits.Resize (size);
			section.bits.Zero();
		ELSE
			NEW (section.bits, size);
		END;

		WHILE ReadSegment() DO
		END;
	END ReadSectionBinary;

	PROCEDURE ReadSection*(reader: Streams.Reader; VAR section: Section; binary: BOOLEAN; poolMap: PoolMap);
	BEGIN
		IF binary THEN
			ReadSectionBinary(reader,section,poolMap)
		ELSE
			ReadSectionTextual(reader,section);
		END
	END ReadSection;

	PROCEDURE WriteSection*(writer: Streams.Writer; CONST section: Section; binary: BOOLEAN; poolMap: PoolMap);
	VAR pos: Streams.Position;
	BEGIN
		pos := writer.Pos();
		IF binary THEN
			WriteSectionBinary(writer,section, poolMap)
		ELSE
			WriteSectionTextual(writer,section)
		END;
		INC(statSections); INC(statSectionsTotalSize, SIZE(writer.Pos()-pos));
	END WriteSection;

	PROCEDURE SetFixups*(VAR section: Section; fixups: SIZE; fixup: Fixups);
	BEGIN
		section.fixups := fixups;
		section.fixup := fixup;
	END SetFixups;

	PROCEDURE SetAliases*(VAR section: Section; aliases: SIZE; alias: Aliases);
	BEGIN
		section.aliases := aliases;
		section.alias := alias;
	END SetAliases;

	PROCEDURE AddPatch*(VAR patches: SIZE; VAR patch: Patches; disp, ofs: Unit);
	VAR newPatch: Patches; newPatches, i: SIZE;
	BEGIN
		FOR i := 0 TO patches-1 DO
			ASSERT(patch[i].offset # ofs);
		END;
		newPatches := patches+1;
		IF (patch = NIL) OR (LEN(patch) < newPatches) THEN
			NEW(newPatch, 2*newPatches);
			FOR i := 0 TO patches-1 DO
				newPatch[i].offset := patch[i].offset;
				newPatch[i].displacement := patch[i].displacement;
			END;
			patch := newPatch;
		END;
		patch[patches].offset := ofs;
		patch[patches].displacement := disp;
		patches := newPatches;
	END AddPatch;

	PROCEDURE SameFixupPattern(patterns: SIZE; left, right: FixupPatterns): BOOLEAN;
	VAR i: SIZE;
	BEGIN
		FOR i := 0 TO patterns-1 DO
			IF (left[i].offset # right[i].offset) OR (left[i].bits # right[i].bits) THEN RETURN FALSE END;
		END;
		RETURN TRUE
	END SameFixupPattern;

	PROCEDURE HasPattern(pat: Pattern; mode: INTEGER; scale: Bits; patterns: SIZE; pattern: FixupPatterns): BOOLEAN;
	BEGIN
		RETURN (pat.mode = mode) & (pat.scale = scale) & (pat.patterns = patterns) & SameFixupPattern(patterns, pat.pattern, pattern);
	END HasPattern;

	PROCEDURE AddFixup*(VAR fixups: SIZE; VAR fixup: Fixups; CONST name: SegmentedName; fingerprint: Fingerprint; mode: INTEGER; scale: Bits; patterns: SIZE; pattern: FixupPatterns): SIZE;
	VAR i, newFixups, index: SIZE; newFixup: Fixups;
	BEGIN
		FOR i := 0 TO fixups-1 DO
			IF (fixup[i].identifier.fingerprint = fingerprint) & (name =fixup[i].identifier.name) & HasPattern(fixup[i].pattern, mode, scale, patterns, pattern) THEN
				RETURN i
			END;
		END;
		newFixups := fixups+1;
		IF (fixup = NIL) OR (LEN(fixup) < newFixups) THEN
			NEW(newFixup, MAX(2*newFixups,32));
			FOR i := 0 TO fixups-1 DO
				newFixup[i] := fixup[i];
				(*CopyFixup(fixup[i], newFixup[i]);*)
			END;
			fixup := newFixup;
		END;
		fixup[fixups].identifier.name := name;
		fixup[fixups].identifier.fingerprint := fingerprint;
		NEW(fixup[fixups].pattern);
		fixup[fixups].pattern.scale := scale;
		fixup[fixups].pattern.mode := mode;
		fixup[fixups].pattern.patterns := patterns;
		fixup[fixups].pattern.pattern := pattern;
		index := fixups;
		fixups := newFixups;
		(* increase size and add *)
		RETURN index;
	END AddFixup;

	PROCEDURE AddAlias*(VAR aliases: SIZE; VAR alias: Aliases; CONST name: SegmentedName; fingerprint: Fingerprint; offset: Unit): SIZE;
	VAR i, newAliases, index: SIZE; newAlias: Aliases;
	BEGIN
		newAliases := aliases+1;
		IF (alias = NIL) OR (LEN(alias) < newAliases) THEN
			NEW(newAlias, MAX(2*newAliases,32));
			FOR i := 0 TO aliases-1 DO
				newAlias[i] := alias[i];
				(*CopyAlias(alias[i], newAlias[i]);*)
			END;
			alias := newAlias;
		END;
		alias[aliases].identifier.name := name;
		alias[aliases].identifier.fingerprint := fingerprint;
		alias[aliases].offset := offset;
		index := aliases;
		aliases := newAliases;
		(* increase size and add *)
		RETURN index;
	END AddAlias;

	PROCEDURE StringToSegmentedName*(CONST name: ARRAY OF CHAR; VAR segmentedName: SegmentedName);
	VAR i, j, segment: SIZE; n: SectionName;
	BEGIN
		(* convert a string of the form A.B.C.suffix to [S(A), S(B), S(C), S(suffix)] *)
		segment := 0; i := 0;
		WHILE (segment < LEN(segmentedName)) DO
			j := 0;
			WHILE (name[i] # 0X) & (name[i] # ".") DO
				n[j] := name[i]; INC(i); INC(j);
			END;
			IF j > 0 THEN
				IF segment = LEN(segmentedName)-1 THEN
				WHILE (name[i] # 0X)  DO n[j] := name[i]; INC(i); INC(j); END;
				END;
				n[j] := 0X; StringPool.GetIndex(n,segmentedName[segment]);
			ELSE
				segmentedName[segment] := -1
			END;
			IF name[i] = "." THEN INC(i) END;
			INC(segment);
		END;
	END StringToSegmentedName;

	PROCEDURE SegmentedNameToString*(CONST segmentedName: SegmentedName; VAR name: ARRAY OF CHAR);
	VAR i, j, segment: SIZE; n: SectionName;
	BEGIN
		i := 0; segment := 0;
		WHILE (segment < LEN(segmentedName)) & (segmentedName[segment] >= 0) DO
			IF segment > 0 THEN name[i] := "."; INC(i) END;
			StringPool.GetString(segmentedName[segment],n);
			j := 0;
			WHILE n[j] # 0X DO
				name[i] := n[j]; INC(i); INC(j);
			END;
			INC(segment);
		END;
		name[i] := 0X;
	END SegmentedNameToString;

	(* result = 0 : equal strings, result < 0: s1 before s2, result > 0 : s1 after s2 (alphanumerically) *)
	PROCEDURE CompareSegmentedNames*(CONST s1, s2: SegmentedName): INTEGER;
	VAR n1, n2: SectionName; index: SIZE; ch1, ch2: CHAR;
	BEGIN
		SegmentedNameToString(s1,n1);
		SegmentedNameToString(s2,n2);
		index := 0;
		ch1 := n1[index];
		ch2 := n2[index];
		WHILE (ch1 # 0X) & (ch1 = ch2)  DO
			INC(index);
			ch1 := n1[index];
			ch2 := n2[index];
		END;
		RETURN ORD(ch1) - ORD(ch2);
	END CompareSegmentedNames;

	PROCEDURE IsPrefix*(CONST prefix, of: SegmentedName): BOOLEAN;
	VAR prefixS, ofS: SectionName; i: SIZE;
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

	OPERATOR "="*(CONST l,r: SegmentedName): BOOLEAN;
	VAR i: SIZE;
	BEGIN
		i := 0; WHILE (i < LEN(l)) & (l[i] = r[i]) & (l[i] # -1)  DO INC(i) END; RETURN (i = LEN(l)) OR (l[i] = r[i]);
	END "=";

	OPERATOR "="*(CONST l,r: Identifier): BOOLEAN;
	BEGIN
		RETURN (l.name = r.name) & (r.fingerprint = l.fingerprint)
	END "=";

	OPERATOR "#"*(CONST l,r: Identifier): BOOLEAN;
	BEGIN
		RETURN (l.name # r.name) OR (r.fingerprint # l.fingerprint)
	END "#";

	OPERATOR ":="*(VAR l: SegmentedName; CONST r: ARRAY OF CHAR);
	BEGIN
		StringToSegmentedName(r, l)
	END ":=";

	OPERATOR ":="*(VAR l: ARRAY OF CHAR; CONST r: SegmentedName);
	BEGIN
		SegmentedNameToString(r, l)
	END ":=";

	OPERATOR "="*(CONST l: SegmentedName; CONST r: ARRAY OF CHAR): BOOLEAN;
	VAR i, j, segment: SIZE; n: SectionName;
	BEGIN
		i := 0; segment := 0;
		WHILE (segment < LEN(l)) DO
			IF l[segment] < 0 THEN
				RETURN r[i] = 0X
			ELSE
				IF (segment>0) THEN
					IF (r[i] # ".") THEN RETURN FALSE END;
					INC(i);
				END;
				StringPool.GetString(l[segment], n);
				j := 0;
				WHILE (r[i] = n[j]) & (n[j] # 0X) & (r[i] # 0X) DO
					INC(i); INC(j);
				END;
				IF n[j] # 0X THEN RETURN FALSE END;
			END;
			INC(segment);
		END;
		RETURN r[i] = 0X;
	END "=";

	OPERATOR "="*(CONST l: ARRAY OF CHAR; r: SegmentedName): BOOLEAN;
	BEGIN
		RETURN r = l
	END "=";

	OPERATOR "#"*(CONST l: SegmentedName; CONST r: ARRAY OF CHAR): BOOLEAN;
	BEGIN RETURN ~(l=r)
	END "#";

	OPERATOR "#"*(CONST l: ARRAY OF CHAR; r: SegmentedName): BOOLEAN;
	BEGIN
		RETURN ~(r=l)
	END "#";

	OPERATOR "#"*(CONST l,r: SegmentedName): BOOLEAN;
	VAR i: SIZE;
	BEGIN
		i := 0; WHILE (i<LEN(l)) & (l[i] = r[i]) & (l[i] # -1)  DO INC(i) END; RETURN (i<LEN(l)) & (l[i] # r[i]);
	END "#";

	PROCEDURE Statistics*;
	VAR sections, sectionsContentSize: SIZE;
	BEGIN
		TRACE(statHeaders, statHeadersSize);
		TRACE(statFixups, statFixupsSize, statFixupPatterns, statFixupPatches);
		TRACE(statAliases, statAliasesSize);
		TRACE(statSegments, statSegmentsSize, statSegmentsSize DIV MAX(1,statSegments));

		TRACE(statCodeSections, statCodeSectionsSize);
		TRACE(statDataSections, statDataSectionsSize);
		TRACE(statConstSections, statConstSectionsSize);
		TRACE(statInitSections, statInitSectionsSize);
		TRACE(statBodySections, statBodySectionsSize);
		sections := statCodeSections + statDataSections + statConstSections + statInitSections + statBodySections;
		sectionsContentSize := statCodeSectionsSize + statDataSectionsSize + statConstSectionsSize + statInitSectionsSize + statBodySectionsSize;
		TRACE(sections, sectionsContentSize);
		TRACE(statSections, statSectionsTotalSize);
	END Statistics;

	PROCEDURE ResetStatistics*;
	BEGIN
		statHeaders := 0; statHeadersSize := 0;
		statFixups := 0; statFixupsSize := 0; statFixupPatterns := 0; statFixupPatches := 0;
		statAliases := 0; statAliasesSize := 0;
		statSegments := 0; statSegmentsSize := 0;
		statCodeSections := 0; statCodeSectionsSize := 0;
		statDataSections := 0; statDataSectionsSize := 0;
		statConstSections := 0; statConstSectionsSize := 0;
		statInitSections := 0; statInitSectionsSize := 0;
		statBodySections := 0; statBodySectionsSize := 0;
		statSections := 0; statSectionsTotalSize := 0;
	END ResetStatistics;

BEGIN
	categories[Code] := "code";
	categories[EntryCode] := "entrycode";
	categories[InitCode] := "initcode";
	categories[ExitCode] := "exitcode";
	categories[BodyCode] := "bodycode";
	categories[Data] := "data";
	categories[Const] := "const";
	modes[Absolute] := "abs";
	modes[Relative] := "rel";
	relocatabilities[Fixed] := "fixed";
	relocatabilities[Aligned] := "aligned";
	ResetStatistics;
END ObjectFile.

ObjectFile.Test
