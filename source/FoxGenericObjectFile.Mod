MODULE FoxGenericObjectFile; (** AUTHOR "negelef"; PURPOSE "Generic Object File Writer"; *)

IMPORT
	Streams, Commands, Basic := FoxBasic, Formats := FoxFormats, Sections := FoxSections, IntermediateCode := FoxIntermediateCode,
	SyntaxTree := FoxSyntaxTree, BinaryCode := FoxBinaryCode,
	Fingerprinter := FoxFingerprinter, Files, Options, ObjectFile, SymbolFileFormat := FoxTextualSymbolFile, Strings, KernelLog, D := Debugging;

CONST
	Trace = FALSE;
	TraceAliases = FALSE;
	WarnDuplicateFingerprints = FALSE;

	(* optimizations *)
	PatchFixups = TRUE; (* patch all fixups that can be processed during object file generation *)
	AliasOnlyExported = TRUE;  (* create an alias only for exported sections *)

TYPE
	Unit = BinaryCode.Unit;

	ObjectFileFormat* = OBJECT (Formats.ObjectFileFormat)

		VAR binary: BOOLEAN; mergeSections: BOOLEAN;

		PROCEDURE & InitObjectFileFormat;
		BEGIN
			Init; SetExtension(ObjectFile.DefaultExtension);
		END InitObjectFileFormat;

		PROCEDURE Export* (module: Formats.GeneratedModule; symbolFileFormat: Formats.SymbolFileFormat): BOOLEAN;
		VAR fileName: Files.FileName; file: Files.File; writer: Files.Writer; fingerprinter: Fingerprinter.Fingerprinter; poolMap: ObjectFile.PoolMap;

			PROCEDURE ExportSection (section: IntermediateCode.Section): BOOLEAN;
			VAR name: ARRAY 256 OF CHAR; (* debugging *)
			BEGIN
				(*
				IF section.IsExternal() OR (section.symbol # NIL) & (section.symbol.scope # NIL) & (section.symbol.scope.ownerModule # module(Sections.Module).module) THEN
					(* nothing to do *)
				ELSE
				*)
					IF section.resolved = NIL THEN
						Basic.SegmentedNameToString(section.name, name);
						D.String('"section.resolved = NIL" for '); D.String(name); D.Ln;
						RETURN FALSE
					END;
					section.resolved.os.identifier.fingerprint := GetFingerprint (section, fingerprinter);
					CopyFixups (NIL, section.resolved, section.resolved, 0);
					ObjectFile.WriteSection(writer,section.resolved.os,binary, poolMap);
				(*
				END;
				*)
				RETURN TRUE
			END ExportSection;

			PROCEDURE MergeSections (module: Sections.Module): BOOLEAN;
			VAR
				section: Sections.Section;
				i: SIZE;
				sname: Basic.SegmentedName;
				codeAlign, dataAlign, constAlign: Unit;
				codeUnit, dataUnit, constUnit: BinaryCode.Bits;
				resolved, codeSection, dataSection, constSection: BinaryCode.Section;
				alias: BinaryCode.Alias;
				irSection: IntermediateCode.Section;
				exported: BOOLEAN;
				sections: Sections.SectionList;
				prefix: SyntaxTree.IdentifierString;
				export: SIZE;
			BEGIN
				sections := module.allSections;
				FOR export := 0 TO module.exports.Length()-1 DO
					prefix := module.exports.GetName(export);
					codeSection := NIL; dataSection := NIL; constSection := NIL;
					codeAlign := 0; dataAlign := 0; constAlign := 0;
					codeUnit := 0; dataUnit := 0; constUnit := 0;
					FOR i := 0 TO sections.Length() - 1 DO

						section := sections.GetSection(i);
						sname := prefix;
						IF Basic.IsPrefix(sname, section.name) THEN
							resolved := section(IntermediateCode.Section).resolved;
							IF resolved = NIL THEN RETURN FALSE END;

							IF (resolved # NIL)  & (resolved.pc # 0) & (~resolved.os.fixed) THEN
								IF section.type = ObjectFile.Code THEN
									codeAlign := CommonAlignment(codeAlign, resolved.os.alignment);
									ASSERT((codeUnit=0) OR (codeUnit = resolved.os.unit));
									codeUnit := resolved.os.unit;
								ELSIF section.type = ObjectFile.Data THEN
									dataAlign := CommonAlignment(dataAlign, resolved.os.alignment);
									ASSERT((dataUnit=0) OR (dataUnit = resolved.os.unit));
									dataUnit := resolved.os.unit;
								ELSIF section.type = ObjectFile.Const THEN
									constAlign := CommonAlignment(constAlign, resolved.os.alignment);
									ASSERT((constUnit=0) OR (constUnit = resolved.os.unit));
									constUnit := resolved.os.unit;
								END;
							END;
						END;
					END;
					IF codeUnit > 0 THEN
						sname := prefix;
						Basic.AppendToSegmentedName(sname,".@CodeSections");
						codeSection := BinaryCode.NewBinarySection(ObjectFile.Code, codeUnit, sname, FALSE, FALSE);
						codeSection.SetAlignment(FALSE,codeAlign);
					END;
					IF dataUnit > 0 THEN
						sname := prefix;
						Basic.AppendToSegmentedName(sname,".@DataSections");
						dataSection := BinaryCode.NewBinarySection(ObjectFile.Data, dataUnit, sname, FALSE, FALSE);
						dataSection.SetAlignment(FALSE,dataAlign);
					END;
					IF constUnit > 0 THEN
						sname := prefix;
						Basic.AppendToSegmentedName(sname,".@ConstSections");
						constSection := BinaryCode.NewBinarySection(ObjectFile.Const, constUnit, sname, FALSE, FALSE);
						constSection.SetAlignment(FALSE,constAlign);
					END;
					(*TRACE(codeAlign, dataAlign, constAlign);*)
					(*codeAlign := 0; dataAlign := 0; constAlign := 0;*)
					FOR i := 0 TO sections.Length() - 1 DO
						section := sections.GetSection(i);
						sname := prefix;
						IF Basic.IsPrefix(sname, section.name) THEN
							resolved := section(IntermediateCode.Section).resolved;
							exported := section(IntermediateCode.Section).exported;
							IF (resolved # NIL) & (resolved.pc # 0) & (~resolved.os.fixed)  THEN
								IF section.type = ObjectFile.Code THEN
									IF resolved.os.alignment # 0 THEN
									codeSection.Align(resolved.os.alignment);
									END;
									resolved.os.identifier.fingerprint := GetFingerprint (section, fingerprinter);

									NEW(alias, resolved.os.identifier, codeSection.pc);
									IF ~AliasOnlyExported OR exported THEN  codeSection.aliasList.AddAlias(alias) END;
									section(IntermediateCode.Section).SetAlias(codeSection, codeSection.pc);
									codeSection.CopyBits(resolved.os.bits,0, resolved.pc*codeUnit);

								ELSIF section.type = ObjectFile.Data THEN
									IF resolved.os.alignment # 0 THEN
									dataSection.Align(resolved.os.alignment);
									END;
									resolved.os.identifier.fingerprint := GetFingerprint (section, fingerprinter);
									NEW(alias, resolved.os.identifier, dataSection.pc);
									IF ~AliasOnlyExported OR exported THEN dataSection.aliasList.AddAlias(alias) END;
									section(IntermediateCode.Section).SetAlias(dataSection, dataSection.pc);
									dataSection.CopyBits(resolved.os.bits,0, resolved.pc*dataUnit );
								ELSIF section.type = ObjectFile.Const THEN
									IF resolved.os.alignment # 0 THEN
									constSection.Align(resolved.os.alignment);
									END;
									resolved.os.identifier.fingerprint := GetFingerprint (section, fingerprinter);
									NEW(alias, resolved.os.identifier, constSection.pc);
									IF ~AliasOnlyExported OR exported THEN constSection.aliasList.AddAlias(alias) END;
									section(IntermediateCode.Section).SetAlias(constSection, constSection.pc);
									constSection.CopyBits(resolved.os.bits,0, resolved.pc*constUnit);
								END;
							END;
						END;
					END;

					FOR i := 0 TO sections.Length() - 1 DO
						section := sections.GetSection(i);
						sname := prefix;
						IF Basic.IsPrefix(sname, section.name) THEN
							resolved := section(IntermediateCode.Section).resolved;
							exported := section(IntermediateCode.Section).exported;
							IF (section(IntermediateCode.Section).alias # NIL) THEN
								CopyFixups(sections, resolved, section(IntermediateCode.Section).alias, section(IntermediateCode.Section).aliasOffset);
							ELSE
								CopyFixups(sections, resolved, resolved,0);
							END;
						END;
					END;

					IF codeSection # NIL THEN
						UpdateAliases (codeSection, fingerprinter);
						irSection := IntermediateCode.NewSection(sections, SIGNED8(codeSection.os.type), codeSection.os.identifier.name, NIL, FALSE);
						irSection.SetResolved(codeSection);
					END;
					IF dataSection # NIL THEN
						UpdateAliases (dataSection, fingerprinter);
						irSection := IntermediateCode.NewSection(sections, SIGNED8(dataSection.os.type), dataSection.os.identifier.name, NIL, FALSE);
						irSection.SetResolved(dataSection);
					END;
					IF constSection # NIL THEN
						UpdateAliases (constSection, fingerprinter);
						irSection := IntermediateCode.NewSection(sections, SIGNED8(constSection.os.type), constSection.os.identifier.name, NIL, FALSE);
						irSection.SetResolved(constSection);
					END;

				END;
				RETURN TRUE;
			END MergeSections;

			PROCEDURE ExportSections (sections: Sections.SectionList): BOOLEAN;
			VAR
				section, test: Sections.Section;
				i, j: SIZE;
				name: ObjectFile.SectionName;
				msg: ARRAY 256 OF CHAR;
			BEGIN

				FOR i := 0 TO sections.Length() - 1 DO
					section := sections.GetSection(i);
					IF (section(IntermediateCode.Section).resolved # NIL) & (section(IntermediateCode.Section).alias = NIL)  THEN
						IF ~ExportSection(section(IntermediateCode.Section)) THEN RETURN FALSE END;
						IF  WarnDuplicateFingerprints &  (section(IntermediateCode.Section).resolved.os.identifier.fingerprint # 0) THEN
							FOR j := 0 TO i - 1 DO
								test := sections.GetSection(j);
								IF (test(IntermediateCode.Section).resolved # NIL)
								&  (test(IntermediateCode.Section).resolved.os.identifier.fingerprint = section(IntermediateCode.Section).resolved.os.identifier.fingerprint) THEN
									msg := "duplicate fingerprints: ";
									ObjectFile.SegmentedNameToString(section(IntermediateCode.Section).resolved.os.identifier.name,name);
									Strings.Append(msg, name);
									Strings.Append(msg, ", ");
									ObjectFile.SegmentedNameToString(test(IntermediateCode.Section).resolved.os.identifier.name,name);
									Strings.Append(msg, name);
									Basic.Warning(diagnostics, module.moduleName,Basic.invalidPosition, msg);
								END
							END
						END
					END
				END;
				RETURN TRUE
			END ExportSections;

			PROCEDURE ExportModule (module: Sections.Module): BOOLEAN;
			VAR result: BOOLEAN;
				offers, requires: ObjectFile.NameList;
				numImports: SIGNED32;
				name: ObjectFile.SectionName;
				import: SyntaxTree.Import;
				i: SIZE;
			BEGIN
				IF mergeSections & ~MergeSections(module) THEN RETURN FALSE END;

				NEW (offers, module.exports.Length());
				FOR i := 0 TO module.exports.Length()-1 DO
					offers[i] := module.exports.GetName(i);
				END;

				IF module.module#NIL THEN
					import := module.module.moduleScope.firstImport;
					numImports := 0;
					WHILE import # NIL DO
						IF import.direct & (import.parameters = NIL) THEN INC(numImports) END;
						import := import.nextImport;
					END;
					NEW(requires, numImports);
					numImports := 0;
					import := module.module.moduleScope.firstImport;
					WHILE import # NIL DO
						IF import.direct & (import.parameters = NIL) THEN
							import.module.GetName(name);
							requires[numImports] := name;
							INC(numImports);
						END;
						import := import.nextImport;
					END;


				END;
				WriteHeader(writer,binary,module.allSections, poolMap, offers, requires, fingerprinter);
				result := ExportSections (module.allSections);
				RETURN result
			END ExportModule;

		BEGIN
			IF Trace THEN D.String(">>> export generic object file"); D.Ln END;

			IF ~(module IS Sections.Module) THEN
				Basic.Error (diagnostics, module.moduleName, Basic.invalidPosition,  "generated module format does not match object file format");
				RETURN FALSE;
			END;

			IF path # "" THEN Files.JoinPath (path, module.moduleName, fileName); ELSE COPY (module.moduleName, fileName); END;
			Files.JoinExtension (fileName, extension, fileName);

			IF Trace THEN D.String(">>> filename: "); D.String(fileName); D.Ln END;

			file := Files.New (fileName);
			IF file = NIL THEN
				Basic.Error(diagnostics, module.moduleName,Basic.invalidPosition, "failed to open object file");
				RETURN FALSE;
			END;

			NEW (fingerprinter);
			Files.OpenWriter (writer, file, 0);
			IF ExportModule (module(Sections.Module)) THEN
				writer.Update;
				Files.Register (file);
				RETURN TRUE;
			ELSE
				RETURN FALSE
			END
		END Export;

		PROCEDURE DefineOptions* (options: Options.Options);
		BEGIN
			options.Add(0X,"objectFileExtension",Options.String);
			options.Add(0X,"textualObjectFile",Options.Flag);
			options.Add(0X,"mergeSections",Options.Flag);
		END DefineOptions;

		PROCEDURE GetOptions* (options: Options.Options);
		VAR extension: Files.FileName;
		BEGIN
			IF options.GetString("objectFileExtension",extension) THEN
				SetExtension(extension);
			END;
			binary := ~options.GetFlag("textualObjectFile");
			mergeSections := options.GetFlag("mergeSections");
		END GetOptions;

		PROCEDURE DefaultSymbolFileFormat*(): Formats.SymbolFileFormat;
		BEGIN RETURN SymbolFileFormat.Get();
		END DefaultSymbolFileFormat;

	END ObjectFileFormat;

	PROCEDURE GetFingerprint (section: Sections.Section; fingerprinter: Fingerprinter.Fingerprinter): ObjectFile.Fingerprint;
	VAR fingerprint: SyntaxTree.Fingerprint; fp: ObjectFile.Fingerprint; string: Basic.SectionName;
	BEGIN
		IF section.fingerprint # 0 THEN
			fp := section.fingerprint
		ELSIF (section.symbol = NIL) OR (section.symbol.scope = NIL) THEN
			fp := 0;
			IF (section(IntermediateCode.Section).resolved # NIL) THEN
				Basic.SegmentedNameToString(section.name, string);
				Fingerprinter.FPString(fp, string)
			END
		ELSIF fingerprinter # NIL THEN
			fingerprint := fingerprinter.SymbolFP (section.symbol);
			fp := fingerprint.shallow;
		END;
		RETURN fp
	END GetFingerprint;

	PROCEDURE CheckAlias(sections: Sections.SectionList; VAR identifier: ObjectFile.Identifier; VAR offset: SIZE);
	VAR section: Sections.Section; alias: BinaryCode.Section;
	BEGIN
		offset := 0;
		IF sections = NIL THEN RETURN END;
		section := sections.FindByName(identifier.name);
		IF (section # NIL) THEN
			alias := section(IntermediateCode.Section).alias;
			IF alias # NIL THEN
				offset := section(IntermediateCode.Section).aliasOffset;
				IF TraceAliases THEN
					Basic.WriteSegmentedName(D.Log, identifier.name); D.String(" => ");
					Basic.WriteSegmentedName(D.Log, alias.os.identifier.name);
					D.Ln;
				END;
				identifier := alias.os.identifier;
			END;
		END;
	END CheckAlias;

	PROCEDURE CopyFixups(sections: Sections.SectionList; from, to: BinaryCode.Section; offset: Unit);
	VAR fixup: BinaryCode.Fixup; i, index, fixups: SIZE; fixupList: ObjectFile.Fixups;
		aliasSymbol: ObjectFile.Identifier; aliasOffset: SIZE;

		PROCEDURE PatchFixup (fixup: BinaryCode.Fixup; fixupOffset, targetOffset: Unit);
		VAR target, address: Unit; j: SIZE;

			PROCEDURE PatchPattern (CONST pattern: ObjectFile.FixupPattern);
			BEGIN
				to.os.bits.SetBits (target * to.os.unit + pattern.offset, pattern.bits, address); address := ASH (address, -pattern.bits);
			END PatchPattern;

			PROCEDURE CheckBits(value, offset: Unit);
			VAR i: SIZE; nobits,remainder: ObjectFile.Bits; minval, maxval: Unit; name: ObjectFile.SectionName; number: ARRAY 32 OF CHAR;
			BEGIN
				nobits := 0;
				FOR i := 0 TO fixup.patterns-1 DO
					INC(nobits,fixup.pattern[i].bits);
				END;

				remainder := ASH(address,-nobits);

				IF  (nobits <32) & ((remainder > 0) OR (remainder < -1)) THEN
					IF fixup.mode = ObjectFile.Relative THEN (* negative values allowed *)
						maxval := ASH(1,nobits-1)-1; minval := -maxval-1
					ELSE
						minval := 0; maxval := ASH(1,nobits);
					END;
					ObjectFile.SegmentedNameToString(to.os.identifier.name,name);
					Strings.Append(name,":");
					Strings.IntToStr(offset,number);
					Strings.Append(name,number);
					D.String(name); D.String("fixup out of range"); D.Ln;
					HALT(100);
				END;
			END CheckBits;

		BEGIN
			target := fixupOffset + fixup.offset  ;
			address := targetOffset + fixup.displacement;
			IF fixup.mode = ObjectFile.Relative THEN
				DEC(address,target)
			END;
			address := ASH (address, fixup.scale);
			CheckBits(address, fixup.offset);
			FOR j := 0 TO fixup.patterns-1 DO PatchPattern(fixup.pattern[j]) END;
		END PatchFixup;

	BEGIN
		fixup := from.fixupList.firstFixup; i := 0; fixups := to.os.fixups; fixupList := to.os.fixup;
		WHILE fixup # NIL DO
			(*! fingerprint := GetFingerprint(fixup.symbol, fingerprinter);  *)
			aliasSymbol := fixup.symbol;
			CheckAlias(sections, aliasSymbol, aliasOffset);
			IF PatchFixups & (aliasSymbol.name = to.os.identifier.name) & (fixup.mode = BinaryCode.Relative) THEN
				PatchFixup(fixup, offset, aliasOffset);
			ELSE
				index := ObjectFile.AddFixup(fixups, fixupList, aliasSymbol.name, aliasSymbol.fingerprint, fixup.mode,fixup.scale, fixup.patterns, fixup.pattern);
				ObjectFile.AddPatch(fixupList[index].patches, fixupList[index].patch, fixup.displacement+aliasOffset,  fixup.offset+offset);
			END;
			fixup := fixup.nextFixup; INC (i);
		END;
		ObjectFile.SetFixups(to.os, fixups, fixupList);
		from.fixupList.InitFixupList; (* delete the source list *)
	END CopyFixups;

	PROCEDURE UpdateAliases (section: BinaryCode.Section;  fingerprinter: Fingerprinter.Fingerprinter);
	VAR alias: BinaryCode.Alias; aliasList: ObjectFile.Aliases; i, aliases, index: SIZE;
	BEGIN
		alias := section.aliasList.firstAlias; i := 0; aliases := 0; aliasList := NIL;
		WHILE alias # NIL DO
			(*! fingerprint := GetFingerprint(alias.symbol, fingerprinter);  *)
			index := ObjectFile.AddAlias(aliases, aliasList, alias.identifier.name, alias.identifier.fingerprint, alias.offset);
			alias := alias.nextAlias; INC (i);
		END;
		ObjectFile.SetAliases(section.os, aliases, aliasList);
		section.aliasList.InitAliasList;
	END UpdateAliases;

	PROCEDURE Get*(): Formats.ObjectFileFormat;
	VAR objectFileFormat: ObjectFileFormat;
	BEGIN NEW(objectFileFormat); RETURN objectFileFormat
	END Get;

	PROCEDURE ReadHeader(reader: Streams.Reader; VAR binary: BOOLEAN; VAR poolMap: ObjectFile.PoolMap; VAR offers, requires: ObjectFile.NameList);
	VAR ch: CHAR; version: INTEGER; string: ARRAY 32 OF CHAR;
	BEGIN
		reader.String(string);
		binary := string="FoxOFB";
		IF ~binary THEN ASSERT(string="FoxOFT") END;
		reader.SkipWhitespace;
		reader.Char(ch); ASSERT(ch='v');
		reader.Int(version,FALSE);
		IF version # ObjectFile.Version THEN KernelLog.String("warning: invalid object file encountered, recompile all sources"); KernelLog.Ln END;
		reader.Char(ch); ASSERT(ch='.');
		IF ~binary THEN reader.SkipWhitespace
		ELSE
			NEW(poolMap,64);
			poolMap.Read(reader);
		END;
		offers := NIL;
		requires := NIL;
		IF ~binary THEN
			reader.String(string); ObjectFile.ReadNameList(reader, offers, binary, poolMap);
			reader.SkipWhitespace;
			reader.String(string); ObjectFile.ReadNameList(reader, requires, binary, poolMap);
			reader.SkipWhitespace;
		ELSE
			ObjectFile.ReadNameList(reader, offers, binary, poolMap);
			ObjectFile.ReadNameList(reader, requires, binary, poolMap);
		END
	END ReadHeader;

	PROCEDURE WriteHeader(writer: Streams.Writer; binary: BOOLEAN; sections: Sections.SectionList; VAR poolMap: ObjectFile.PoolMap; offers, requires: ObjectFile.NameList; fingerprinter:Fingerprinter.Fingerprinter);
	VAR i: SIZE; section: Sections.Section;

		PROCEDURE ProcessSection(section: IntermediateCode.Section);
		VAR i: SIZE; fixup: BinaryCode.Fixup; alias: BinaryCode.Alias;
		BEGIN
			IF (section.resolved # NIL)  & (section.alias = NIL)  THEN
				poolMap.PutSegmentedName(section.resolved.os.identifier.name);
				(* for those sections that have been already resolved *)
				FOR i := 0 TO section.resolved.os.fixups-1 DO
					poolMap.PutSegmentedName(section.resolved.os.fixup[i].identifier.name);
				END;
				FOR i := 0 TO section.resolved.os.aliases-1 DO
					poolMap.PutSegmentedName(section.resolved.os.alias[i].identifier.name);
				END;
				fixup := section.resolved.fixupList.firstFixup; i := 0;
				WHILE fixup # NIL DO
					poolMap.PutSegmentedName(fixup.symbol.name);
					fixup := fixup.nextFixup;
				END;
				alias:= section.resolved.aliasList.firstAlias; i := 0;
				WHILE alias # NIL DO
					poolMap.PutSegmentedName(alias.identifier.name);
					alias := alias.nextAlias;
				END;
			END;
		END ProcessSection;

		PROCEDURE NameList(CONST names: ObjectFile.NameList);
		BEGIN
			IF names # NIL THEN
				FOR i := 0 TO LEN(names)-1 DO
					poolMap.PutSegmentedName(names[i]);
				END;
			END;
		END NameList;

	BEGIN
		IF binary THEN writer.String("FoxOFB");
		ELSE writer.String("FoxOFT");
		END;
		writer.Char(' ');
		writer.Char('v'); writer.Int(ObjectFile.Version,0); writer.Char(".");
		IF ~binary THEN
				writer.Ln;
				writer.String("offers "); ObjectFile.WriteNameList(writer, offers, binary, poolMap);
				writer.String("requires "); ObjectFile.WriteNameList(writer, requires, binary, poolMap);
				writer.Ln;
		ELSE
			NEW(poolMap,512);
			poolMap.BeginWriting(writer);
			FOR i := 0 TO sections.Length()-1 DO
				section := sections.GetSection(i);
				ProcessSection(section(IntermediateCode.Section));
			END;
			NameList(offers); NameList(requires);
			poolMap.EndWriting;
			ObjectFile.WriteNameList(writer, offers, binary, poolMap);
			ObjectFile.WriteNameList(writer, requires, binary, poolMap);
			(*
			FOR i := 0 TO fixups-1 DO
				D.String("fingerprint: "); Basic.WriteSegmentedName(D.Log, fixupList[i].identifier.name); D.Ln;
			END;
			*)
		END;
	END WriteHeader;

	PROCEDURE GCD(a,b: Unit): Unit;
	VAR h: Unit;
	BEGIN
		WHILE b # 0 DO
			h := a MOD b;
			a := b;
			b := h;
		END;
		RETURN a
	END GCD;

	PROCEDURE SCM(a,b: Unit): Unit;
	BEGIN
		RETURN a*b DIV GCD(a,b)
	END SCM;

	PROCEDURE CommonAlignment(a,b: Unit): Unit;
	BEGIN
		(*TRACE(a,b);*)
		IF a = 0 THEN RETURN b
		ELSIF b = 0 THEN RETURN a
		ELSE RETURN SCM(a,b)
		END;
	END CommonAlignment;

	PROCEDURE Show*(context: Commands.Context);
	VAR
		fileName: Files.FileName; file: Files.File; reader: Files.Reader; writer: Streams.Writer;
		section: ObjectFile.Section; binary: BOOLEAN; poolMap, poolMapDummy: ObjectFile.PoolMap;
		offers, requires: ObjectFile.NameList;
	BEGIN
		IF context.arg.GetString(fileName) THEN
			file := Files.Old(fileName);
			IF file # NIL THEN
				NEW(reader,file,0);
				writer := Basic.GetWriter(Basic.GetDebugWriter(fileName));
				ReadHeader(reader, binary, poolMap, offers, requires);
				WriteHeader(writer, FALSE, NIL, poolMapDummy, offers, requires, NIL);
				WHILE reader.Peek () # 0X DO
					ObjectFile.ReadSection (reader, section,binary, poolMap);
					ObjectFile.WriteSection(writer, section, FALSE, NIL); (* textual *)
					reader.SkipWhitespace;
				END;
				writer.Update;
			ELSE
				context.error.String("file not found "); context.error.String(fileName); context.error.Ln
			END;
		ELSE
			context.error.String("no file specificed"); context.error.Ln
		END;
	END Show;

	PROCEDURE MakeLibrary*(context: Commands.Context);
	VAR
		fileName: Files.FileName; file: Files.File; reader: Files.Reader; (*writer: Streams.Writer;*)
		binary: BOOLEAN; poolMap, poolMapDummy: ObjectFile.PoolMap;
		bs: BinaryCode.Section;
		is: IntermediateCode.Section;
		sectionList: Sections.SectionList;
		section: ObjectFile.Section;
		i: SIZE;
		dest: Files.FileName;
		writer: Files.Writer;
		name: ObjectFile.SegmentedName;
		offers, requires: ObjectFile.NameList;
	BEGIN
		NEW(sectionList);
		IF context.arg.GetString(dest) THEN
			(*writer := Basic.GetWriter(Basic.GetDebugWriter(fileName));*)
			WHILE context.arg.GetString(fileName) DO
				file := Files.Old(fileName);
				IF file # NIL THEN
					NEW(reader,file,0);
					ReadHeader(reader, binary, poolMap,offers, requires);
					WHILE reader.Peek () # 0X DO
						ObjectFile.InitSection(section);
						ObjectFile.ReadSection (reader, section, binary, poolMap);
						NEW(bs, SIGNED8(section.type) ,section.unit,name, FALSE, FALSE);
						bs.os := section;
						NEW(is, SIGNED8(bs.os.type),  bs.os.identifier.name,NIL, FALSE);
						is.SetResolved(bs);
						sectionList.AddSection(is);
						reader.SkipWhitespace;
					END;
				ELSE
					context.error.String("file not found "); context.error.String(fileName); context.error.Ln;
					RETURN;
				END;
			END;
			file := Files.New(dest);
			Files.OpenWriter(writer, file, 0);
			WriteHeader(writer, TRUE, sectionList, poolMapDummy, NIL, NIL, NIL);

			FOR i := 0 TO sectionList.Length()-1 DO
				is := sectionList.GetSection(i)(IntermediateCode.Section);
				ObjectFile.WriteSection(writer, is.resolved.os, TRUE, poolMapDummy); (* binary *)
			END;
			writer.Update;
			Files.Register(file);
			context.out.String("Created library "); context.out.String(dest); context.out.Ln;
		END;
	END MakeLibrary;

END FoxGenericObjectFile.
