 MODULE GenericLinker;	(* AUTHOR "negelef"; PURPOSE "Generic Object File Linker"; *)

IMPORT ObjectFile, Streams, Diagnostics, Strings, StringPool;

TYPE Address* = ObjectFile.Unit;

CONST InvalidAddress* = MAX (Address);

TYPE Priority = LONGINT;

CONST
	Fixed* = 0; InitCode*=1; BodyCode* = 2; Code* = 3; Data* = 4; Const* = 5; Empty* = 6;
	UseAll *= {Fixed .. Empty};
	UseInitCode*={Fixed, InitCode};
	UseAllButInitCode*={Fixed, BodyCode..Empty};

TYPE Arrangement* = OBJECT

	PROCEDURE Preallocate* (CONST section: ObjectFile.Section);
	END Preallocate;

	PROCEDURE Allocate* (CONST section: ObjectFile.Section): Address;
	END Allocate;

	PROCEDURE Patch* (pos, value: Address; offset, bits, unit: ObjectFile.Bits);
	END Patch;

	PROCEDURE CheckReloc*(target: Address; CONST pattern: ObjectFile.Pattern; CONST patch: ObjectFile.Patch);
	BEGIN
		(* to be able to provide relocation information in an image*)
	END CheckReloc;


END Arrangement;

TYPE Block* = POINTER TO RECORD (ObjectFile.Section)
	next: Block;
	address*: Address;
	aliasOf*: Block;
	referenced, used: BOOLEAN;
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

	PROCEDURE &InitLinker* (diagnostics: Diagnostics.Diagnostics; log: Streams.Writer; useCategories: SET; code, data: Arrangement);
	BEGIN
		SELF.diagnostics := diagnostics; SELF.log := log; SELF.usedCategories := useCategories;
		error := FALSE; SELF.code := code; SELF.data := data; firstBlock := NIL; firstLinkedBlock := NIL;
		linkRoot := "";
	END InitLinker;

	PROCEDURE SetLinkRoot*(CONST root: ARRAY OF CHAR);
	BEGIN COPY(root, linkRoot)
	END SetLinkRoot;

	PROCEDURE Error* (CONST source, message: ARRAY OF CHAR);
	BEGIN diagnostics.Error (source, Diagnostics.Invalid, Diagnostics.Invalid, message); error := TRUE;
	END Error;

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
	VAR block: Block;
	BEGIN
		block := firstBlock;
		WHILE (block # NIL) & (block.identifier.name # identifier.name) DO block := block.next END;
		RETURN block;
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
	BEGIN  IF ObjectFile.IsCode (block.type) THEN RETURN code; ELSE RETURN data; END;
	END GetArrangement;

	(* this procedure may be overwritten by implementations of the linker that need a special ordering, as, for example, the bodycode in the front or so *)
	PROCEDURE Precedes* (this, that: Block): BOOLEAN;
	VAR leftType, rightType: LONGINT;
	BEGIN
		leftType := GetPriority(this);
		rightType := GetPriority(that);
		RETURN (leftType < rightType) OR (leftType = rightType) & (this.priority < that.priority)
	END Precedes;

	PROCEDURE AddSection* (CONST section: ObjectFile.Section);
	VAR priority: Priority; block, current, previous,newBlock: Block; name: ARRAY 256 OF CHAR; i: LONGINT; alias: ObjectFile.Alias;
	BEGIN
		IF FindBlock (section.identifier) # NIL THEN ObjectFile.SegmentedNameToString(section.identifier.name,name); Error (name, "duplicated section"); RETURN; END;
		NEW (block); ObjectFile.CopySection (section, block^); block.address := InvalidAddress; block.referenced := FALSE; block.used := FALSE;
		current := firstBlock; previous := NIL;
		WHILE (current # NIL) & ~Precedes(block,current) DO previous := current; current := current.next; END;
		IF previous # NIL THEN previous.next := block; ELSE firstBlock := block; END; block.next := current;
		ExportBlock(block);
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
			ExportBlock(current);
		END;

	END AddSection;

	PROCEDURE Resolve*;
	VAR block: Block; used: BOOLEAN; name: ARRAY 256 OF CHAR;
	BEGIN
		IF ~error THEN block := firstBlock;
			WHILE block # firstLinkedBlock DO
				ObjectFile.SegmentedNameToString(block.identifier.name, name);
				used := (GetType (block) IN usedCategories) OR (linkRoot # "") & Strings.StartsWith(linkRoot,0,name) OR (block.aliases > 0);
				Reference (block, used); block := block.next;
			END;
		END;
	END Resolve;

	(*
	PROCEDURE Aliases*(CONST block: Block);
	VAR newBlock: Block; alias: ObjectFile.Alias; i: LONGINT; name: ARRAY 256 OF CHAR;
	BEGIN
		FOR i := 0 TO block.aliases-1 DO
			alias := block.alias[i];
			NEW(newBlock);
			newBlock.identifier := alias.identifier;
			newBlock.address := alias.offset;
			newBlock.aliasOf := block;
			newBlock.used := block.used;
			newBlock.next := firstBlock;
			firstBlock := newBlock;
		END;
	END Aliases;
	*)

	PROCEDURE PatchAlias*(CONST block: Block);
	VAR newBlock: Block; alias: ObjectFile.Alias; i: LONGINT; name: ARRAY 256 OF CHAR;
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
	VAR i: LONGINT;

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
			ELSIF (reference.identifier.fingerprint # 0) & (block.fixup[i].identifier.fingerprint # 0) & (reference.identifier.fingerprint # block.fixup[i].identifier.fingerprint) THEN
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
		FOR i := 0 TO block.fixups - 1 DO ReferenceFixup (block.fixup[i]); END;
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
	VAR arrangement: Arrangement; i: LONGINT;

		PROCEDURE PatchFixup (CONST fixup: ObjectFile.Fixup);
		VAR reference: Block; target, address: Address; i: LONGINT;

			PROCEDURE PatchPattern (CONST pattern: ObjectFile.FixupPattern);
			BEGIN arrangement.Patch (target, address, pattern.offset, pattern.bits, block.unit); address := ASH (address, -pattern.bits);
			END PatchPattern;

			PROCEDURE CheckBits(value: LONGINT; CONST pattern: ObjectFile.Pattern; offset: LONGINT);
			VAR i, nobits,remainder: LONGINT; minval, maxval: ObjectFile.Unit; name: ObjectFile.SectionName; number: ARRAY 32 OF CHAR;
			BEGIN
				nobits := 0;
				FOR i := 0 TO pattern.patterns-1 DO
					INC(nobits,pattern.pattern[i].bits);
				END;

				remainder := ASH(address,-nobits);

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

			PROCEDURE ApplyPatch(CONST pattern: ObjectFile.Pattern; CONST patch: ObjectFile.Patch);
			VAR i,j: LONGINT;
			BEGIN
					target := block.address + patch.offset;
					address := reference.address + patch.displacement;
					IF pattern.mode = ObjectFile.Relative THEN
						DEC(address,target)
					END;
					address := ASH (address, pattern.scale);
					CheckBits(address, pattern, patch.offset);
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
	VAR source, msg,num,name: ARRAY 128 OF CHAR;
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

PROCEDURE GetType*(block: Block): LONGINT;
BEGIN
	IF block.fixed THEN RETURN Fixed END;
	IF block.type = ObjectFile.InitCode THEN RETURN InitCode END;
	IF block.type = ObjectFile.BodyCode THEN RETURN BodyCode END;
	IF block.bits.GetSize () = 0 THEN RETURN Empty END;
	IF block.type = ObjectFile.Code THEN RETURN Code END;
	IF block.type = ObjectFile.Data THEN RETURN Data END;
	IF block.type = ObjectFile.Const THEN RETURN Const END;
	HALT(100); (* undefined type *)
END GetType;

PROCEDURE GetPriority(block: Block): LONGINT;
BEGIN
	IF block.fixed THEN RETURN Fixed END;
	IF block.type = ObjectFile.InitCode THEN RETURN InitCode END;
	IF block.bits.GetSize () = 0 THEN RETURN Empty END;
	IF block.type = ObjectFile.BodyCode THEN RETURN Code END;
	IF block.type = ObjectFile.Code THEN RETURN Code END;
	IF block.type = ObjectFile.Data THEN RETURN Code END;
	IF block.type = ObjectFile.Const THEN RETURN Code END;
	HALT(100); (* undefined type *)
END GetPriority;



PROCEDURE Process* (reader: Streams.Reader; linker: Linker);
VAR section: ObjectFile.Section; string: ARRAY 32 OF CHAR; ch: CHAR; binary: BOOLEAN; poolMap: ObjectFile.PoolMap;

	PROCEDURE Header;
	VAR ch: CHAR; version: LONGINT; string: ARRAY 32 OF CHAR; i,j,pos,size: LONGINT; name: ObjectFile.SectionName;
	BEGIN
		reader.String(string);
		binary := string="FoxOFB";
		IF ~binary THEN ASSERT(string="FoxOFT") END;
		reader.SkipWhitespace;
		reader.Char(ch); ASSERT(ch='v');
		reader.Int(version,FALSE);
		IF version <2 THEN linker.Error("","old object file version encountered. Recompile sources.") END;
		reader.Char(ch); ASSERT(ch='.');
		IF ~binary THEN reader.SkipWhitespace
		ELSE
			NEW(poolMap,64);
			poolMap.Read(reader);
		END;
	END Header;

BEGIN
	Header;
	WHILE reader.Peek () # 0X DO
		ObjectFile.ReadSection (reader, section,binary,poolMap);
		reader.SkipWhitespace;
		IF reader.res = Streams.Ok THEN linker.AddSection (section); END;
	END;
END Process;

END GenericLinker.


Compiler.Compile --objectFile=Generic --newObjectFile GenericLinker.Mod   ~~~