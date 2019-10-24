MODULE FoxIntermediateLinker;
IMPORT
	Strings, Diagnostics, D := Debugging, SyntaxTree := FoxSyntaxTree, Sections := FoxSections,
	IntermediateCode := FoxIntermediateCode, Basic := FoxBasic, Streams, Files, Backend := FoxBackend,
	Global := FoxGlobal, Formats := FoxFormats,
	ObjectFile, BinaryCode := FoxBinaryCode, Commands, Options, IRObjectFile := FoxIntermediateObjectFile,
	GenericLinker, StaticLinker := Linker;

CONST
	DefaultBackend = "AMD";

TYPE
	SectionName* = ObjectFile.SectionName; (*ARRAY 256 OF CHAR; (*! move *)*)

	(** the assemblinker **)
	Linker* = OBJECT
	CONST
		Trace = FALSE;
		RequireSortedSections = FALSE; (* whether the sections in the generated modules are sorted w.r.t. their fixed positions *)
	TYPE
		ArrangementRestriction = RECORD
			fixed: BOOLEAN;
			positionOrAlignment: SIZE;
		END;
	VAR
		backend-: Backend.Backend;
		diagnostics: Diagnostics.Diagnostics;
		platformName: SyntaxTree.IdentifierString;
		importList, loadedModules: Sections.NameList;
		allSections: Sections.SectionList;
		isSorted, alreadyPrearrangedSinceLastSort: BOOLEAN;
		originalRestrictions: POINTER TO ARRAY OF ArrangementRestriction;
		objectFile-: IRObjectFile.ObjectFileFormat;
		codeUnit: Backend.SizeInBits;

		PROCEDURE & Init*(diagnostics: Diagnostics.Diagnostics; defaultBackend: Backend.Backend);
		BEGIN
			IF diagnostics = NIL THEN
				SELF.diagnostics := Basic.GetDefaultDiagnostics()
			ELSE
				SELF.diagnostics := diagnostics;
			END;
			backend := defaultBackend;
			defaultBackend.GetDescription(platformName);

			NEW(allSections);
			NEW(importList, 128);
			NEW(loadedModules, 128);
			NEW(objectFile); objectFile.Initialize(diagnostics);
			isSorted := FALSE;
			codeUnit := defaultBackend.system.codeUnit;
		END Init;

		PROCEDURE SetInstructionWidth*(unit: Backend.SizeInBits);
		BEGIN
			codeUnit := unit;
		END SetInstructionWidth;



		PROCEDURE PatchStackSize*(CONST typeName: SectionName; size: SIZE);
		VAR sectionName: SectionName; section: Sections.Section; pooledName: Basic.SegmentedName; op1, op2, op3: IntermediateCode.Operand; instruction: IntermediateCode.Instruction;
		BEGIN
			TRACE(size);
			COPY(typeName, sectionName);
			Strings.Append(sectionName,".@StackAllocation");
			Basic.ToSegmentedName(sectionName, pooledName);
			section := allSections.FindByName(pooledName);
			instruction := section(IntermediateCode.Section).instructions[0];
			op1 := instruction.op1;
			op2 := instruction.op2;
			op3 := instruction.op3;
			IntermediateCode.SetIntValue(op2, size);
			section(IntermediateCode.Section).PatchOperands(0, op1, op2, op3);
		END PatchStackSize;

		PROCEDURE EmitAt(section: IntermediateCode.Section; index: SIZE; CONST instruction: IntermediateCode.Instruction);
		VAR reserve: IntermediateCode.Instruction; op: IntermediateCode.Operand;
		BEGIN
			IF index = section.pc THEN
				section.Emit(instruction)
			ELSIF index < section.pc THEN
				section.EmitAt(index, instruction)
			ELSE
				IntermediateCode.InitImmediate(op, instruction.op1.type, 1);
				IntermediateCode.InitInstruction1(reserve,Basic.invalidPosition, IntermediateCode.reserve, op);
				WHILE (section.pc < index) DO
					section.Emit(reserve);
				END;
				section.Emit(instruction);
			END
		END EmitAt;

		PROCEDURE PatchIntegerValue*(CONST sectionName: ARRAY OF CHAR; index: SIZE; value: SIGNED64; type: SyntaxTree.Type): BOOLEAN;
		VAR instruction: IntermediateCode.Instruction; section: Sections.Section; op1: IntermediateCode.Operand;
			pooledName: Basic.SegmentedName; itype: IntermediateCode.Type;
		BEGIN
			Basic.ToSegmentedName(sectionName, pooledName);
			section := allSections.FindByName(pooledName);
			IF section = NIL THEN
				TRACE(sectionName);
				RETURN FALSE
			END; (* nothing to patch *)
			itype := IntermediateCode.GetType(backend.system, type);
			IntermediateCode.InitImmediate(op1,itype, value);
			IntermediateCode.InitInstruction1(instruction, Basic.invalidPosition,  IntermediateCode.data, op1);
			EmitAt(section(IntermediateCode.Section),index, instruction);
			RETURN TRUE;
		END PatchIntegerValue;

		PROCEDURE PatchBooleanValue*(CONST sectionName: ARRAY OF CHAR;index: SIZE; value: BOOLEAN): BOOLEAN;
		VAR instruction: IntermediateCode.Instruction; section: Sections.Section; op1: IntermediateCode.Operand;
			pooledName: Basic.SegmentedName; type: IntermediateCode.Type;
		BEGIN
			Basic.ToSegmentedName(sectionName, pooledName);
			section := allSections.FindByName(pooledName);
			IF section = NIL THEN RETURN FALSE END; (* nothing to patch *)

			type := IntermediateCode.GetType(backend.system, backend.system.booleanType);

			IF value THEN
				IntermediateCode.InitImmediate(op1, type, 1);
			ELSE
				IntermediateCode.InitImmediate(op1, type, 0);
			END;
			IntermediateCode.InitInstruction1(instruction, Basic.invalidPosition,  IntermediateCode.data, op1);
			EmitAt(section(IntermediateCode.Section), index, instruction);
			RETURN TRUE;
		END PatchBooleanValue;

		PROCEDURE PatchStringValue*(CONST sectionName: ARRAY OF CHAR; CONST value: ARRAY OF CHAR): BOOLEAN;
		VAR instruction: IntermediateCode.Instruction; section: Sections.Section; op1: IntermediateCode.Operand;
			pooledName: Basic.SegmentedName; type: IntermediateCode.Type;
			char: CHAR; i: SIZE;
		BEGIN
			Basic.ToSegmentedName(sectionName, pooledName);
			section := allSections.FindByName(pooledName);
			IF section = NIL THEN RETURN FALSE END; (* nothing to patch *)
			section(IntermediateCode.Section).Reset;
			type := IntermediateCode.GetType(backend.system, backend.system.characterType);
			i := 0;
			REPEAT
				char := value[i];
				IntermediateCode.InitImmediate(op1, type, ORD(char));
				IntermediateCode.InitInstruction1(instruction, Basic.invalidPosition,  IntermediateCode.data, op1);
				section(IntermediateCode.Section).Emit(instruction);
				INC(i);
			UNTIL char = 0X;
			RETURN TRUE;
		END PatchStringValue;

		PROCEDURE LoadModule*(CONST moduleFileName: ARRAY OF CHAR; recursive: BOOLEAN): BOOLEAN;
		VAR
			filename, moduleName: SyntaxTree.IdentifierString;
			msg: ARRAY 128 OF CHAR;
			i: SIZE;
			module: Sections.Module;
			name: SyntaxTree.IdentifierString;
		BEGIN
			FileNameToModuleName(moduleFileName, moduleName);
			(* check if the module has already been incorporated *)
			IF loadedModules.ContainsName(moduleName) THEN
				IF Trace THEN D.String(">>> module "); D.String(moduleName); D.String(" has already been loaded"); D.Ln END;
				RETURN TRUE
			ELSE
				IF (moduleName=Global.StringSystemModule)  OR (moduleName=Global.StringsystemModule) THEN
					(* nothing to do *)
				ELSE
					(* open corresponding intermediate code file *)
					module := objectFile.Import(moduleName, backend.GetSystem());
					IF module = NIL THEN
						msg := "failed to import IR file ";
						Strings.Append(msg, moduleFileName);
						Basic.Error(diagnostics, filename, Basic.invalidPosition, msg);
						RETURN FALSE
					ELSE
						loadedModules.AddName(moduleName); (* to avoid recursive reloading this must be done before parsing *)
						IF recursive THEN
							FOR i := 0 TO module.imports.Length()-1 DO
								name := module.imports.GetName(i);
								IF  ~LoadModule(name, recursive) THEN
									msg := "failed to import ";
									Strings.Append(msg, name);
									Basic.Error(diagnostics, filename, Basic.invalidPosition, msg);
									RETURN FALSE
								END;
							END;
						END;
						CopySections(module.allSections, allSections);

						IF Trace THEN
							D.String(">>> IR file successfully parsed: "); D.String(filename); D.Ln;
							DumpSections(D.Log, allSections);
						END;
						isSorted := FALSE; (* sections are not sorted anymore *)

						RETURN TRUE
					END
				END;
				RETURN TRUE
			END
		END LoadModule;

		PROCEDURE LinkPrefixed*(CONST sectionPrefix: ARRAY OF CHAR): BOOLEAN;
		VAR segmentedName: Basic.SegmentedName; filename: Files.FileName;
		BEGIN
			SectionNameToFileName(sectionPrefix, filename);
			MarkReachabilityOfAll(FALSE);
			IF LoadModule(filename, TRUE) THEN
				segmentedName := sectionPrefix;
				MarkAsReachableStartingWith(segmentedName, {Sections.InitCodeSection, Sections.EntryCodeSection, Sections.ExitCodeSection, Sections.BodyCodeSection});

				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END;
		END LinkPrefixed;

		(** mark a section with a certain name as reachable **)
		PROCEDURE MarkAsReachableByName*(CONST name: ARRAY OF CHAR);
		VAR
			section: Sections.Section;
			pooledName: Basic.SegmentedName;
		BEGIN
			Basic.ToSegmentedName(name, pooledName);
			section:= allSections.FindByName(pooledName);
			ASSERT(section # NIL);
			MarkAsReachable(section)
		END MarkAsReachableByName;

		(** mark all sections whose names start with a certain prefix as reachable **)
		PROCEDURE MarkAsReachableStartingWith*(CONST prefix: Basic.SegmentedName; allowedSections: SET);
		VAR
			section: Sections.Section; name: Basic.SegmentedName;
			i: SIZE;
		BEGIN
			(* TODO: could or should one make this faster using a hash table? *)
			(* go through all sections *)
			FOR i := 0 TO allSections.Length() - 1 DO
				section := allSections.GetSection(i);
				IF section.type IN allowedSections THEN
					IF Basic.IsPrefix(prefix, section.name) THEN
						name := section.name;
						Basic.RemoveSuffix(name);
						IF prefix = name THEN
							MarkAsReachable(section)
						END
					END
				END;
			END
		END MarkAsReachableStartingWith;

	(*
		PROCEDURE ModuleIsReachable(CONST name: Basic.String): BOOLEAN;
		VAR i: SIZE; section: Sections.Section;
		BEGIN
			FOR i := 0 TO allSections.Length()-1 DO
				section := allSections.GetSection(i);
				IF (section.name[0] = name) & section.isReachable THEN
					RETURN TRUE
				END;
			END;
			RETURN FALSE
		END ModuleIsReachable;
		*)

		PROCEDURE OperandSection(CONST operand: IntermediateCode.Operand): Sections.Section;
		VAR section: Sections.Section;
		BEGIN
			section := allSections.FindByName(operand.symbol.name);
			IF section = NIL THEN D.String("not found section: "); Basic.WriteSegmentedName(D.Log, operand.symbol.name); D.Ln END;
			RETURN allSections.FindByName(operand.symbol.name);
		END OperandSection;

		(** mark a section as reachable and do the same recursively for all referenced sections **)
		PROCEDURE MarkAsReachable*(section: Sections.Section);
		VAR
			intermediateCodeSection: IntermediateCode.Section;
			i: SIZE;
			procedureName, moduleName: SyntaxTree.IdentifierString;
			prefix: Basic.SegmentedName;
		BEGIN
			IF ~section.isReachable THEN
				IF Trace THEN D.String(">>> MarkAsReachable "); Basic.WriteSegmentedName(D.Log, section.name); D.Ln END;
				section.SetReachability(TRUE);
				prefix := section.name; Basic.RemoveSuffix(prefix);
				MarkAsReachableStartingWith(prefix, {Sections.InitCodeSection});
				ASSERT(section IS IntermediateCode.Section);
				intermediateCodeSection := section(IntermediateCode.Section);
				(* go through all instructions in the section *)
				FOR i := 0 TO intermediateCodeSection.pc - 1 DO
					IF  ~backend(IntermediateCode.IntermediateBackend).SupportedInstruction(intermediateCodeSection.instructions[i], moduleName, procedureName) THEN
						Strings.Append(moduleName,".");
						Strings.Append(moduleName, procedureName);
						MarkAsReachableByName(moduleName);
					END;
					IF intermediateCodeSection.instructions[i].op1.symbol.name # "" THEN MarkAsReachable(OperandSection(intermediateCodeSection.instructions[i].op1)) END;
					IF intermediateCodeSection.instructions[i].op2.symbol.name # "" THEN MarkAsReachable(OperandSection(intermediateCodeSection.instructions[i].op2)) END;
					IF intermediateCodeSection.instructions[i].op3.symbol.name # "" THEN MarkAsReachable(OperandSection(intermediateCodeSection.instructions[i].op3)) END
				END
			END
		END MarkAsReachable;

		(** mark all sections as either reachable or unreachable **)
		PROCEDURE MarkReachabilityOfAll*(isReachable: BOOLEAN);
		VAR
			section: Sections.Section;
			i: SIZE;
		BEGIN
			IF Trace THEN D.String(">>> MarkReachabilityOfAll "); IF isReachable THEN D.String("TRUE") ELSE D.String("FALSE") END; D.Ln END;
			FOR i := 0 TO allSections.Length() - 1 DO
				section := allSections.GetSection(i);
				section.SetReachability(isReachable)
			END
		END MarkReachabilityOfAll;

		(** dump all sections (both reachable and not) **)
		PROCEDURE DumpSections*(writer: Streams.Writer; sections: Sections.SectionList);
		VAR
			section: Sections.Section;
			i: SIZE;
		BEGIN
			FOR i := 0 TO sections.Length() - 1 DO
				section := sections.GetSection(i);
				IF section.isReachable THEN
					writer.String("REACHABLE ")
				ELSE
					writer.String("unreachable ")
				END;
				section.Dump(writer)
			END;
			writer.Update
		END DumpSections;

		(** store the original arrangment restrictions of all sections **)
		PROCEDURE StoreOriginalRestrictions;
		VAR
			section: Sections.Section;
			i: SIZE;
		BEGIN
			NEW(originalRestrictions, allSections.Length());
			FOR i := 0 TO allSections.Length() - 1 DO
				section := allSections.GetSection(i);
				originalRestrictions[i].fixed := section.fixed;
				originalRestrictions[i].positionOrAlignment := section.positionOrAlignment
			END
		END StoreOriginalRestrictions;

		(** restore the original arrangment restrictions of all sections **)
		PROCEDURE RestoreOriginalRestrictions;
		VAR
			section: Sections.Section;
			i: SIZE;
		BEGIN
			ASSERT(LEN(originalRestrictions) = allSections.Length());
			FOR i := 0 TO allSections.Length() - 1 DO
				section := allSections.GetSection(i);
				section.SetPositionOrAlignment(originalRestrictions[i].fixed, originalRestrictions[i].positionOrAlignment)
			END
		END RestoreOriginalRestrictions;

		PROCEDURE PrearrangeReachableDataSections*;
		VAR
			fixedDataSections, flexibleDataSections: Sections.SectionList;
			section, fixedDataSection, flexibleDataSection: Sections.Section;
			i, fixedDataSectionIndex, nextOccupiedAddress, currentAddress, flexibleDataSectionIndex, startAddress, endAddress: SIZE;
			done: BOOLEAN;
		BEGIN
			(* sort sections if necessary *)
			IF ~isSorted THEN
				IF Trace THEN D.String("++++++++++ before sorting ++++++++++"); DumpSections(D.Log, allSections) END;
				FOR i:= 0 TO allSections.Length() - 1 DO
					allSections.GetSection(i).SetOffset(i)
				END;
				allSections.Sort(SectionPositionAndSizeComparison);
				IF Trace THEN D.String("++++++++++ after sorting ++++++++++"); DumpSections(D.Log, allSections) END;
				isSorted := TRUE;
				alreadyPrearrangedSinceLastSort := FALSE
			END;
			ASSERT(isSorted);
			IF alreadyPrearrangedSinceLastSort THEN RestoreOriginalRestrictions ELSE StoreOriginalRestrictions END;

			IF Trace THEN D.String("before prearrangement"); D.Ln; DumpSections(D.Log, allSections); D.Ln END;

			(* create new lists for reachable data sections that are fixed or flexible, respectively *)
			NEW(fixedDataSections);
			NEW(flexibleDataSections);

			(* go through all reachable data sections, and put them into one of two lists *)
			FOR i:= 0 TO allSections.Length() - 1 DO
				section := allSections.GetSection(i);
				IF section.isReachable & ((section.type = Sections.ConstSection) OR (section.type = Sections.VarSection)) THEN
					IF section.fixed THEN
						fixedDataSections.AddSection(section)
					ELSE
						flexibleDataSections.AddSection(section)
					END
				END
			END;

			IF Trace THEN
				D.String("++++++++++ reachable fixed data sections ++++++++++"); fixedDataSections.Dump(D.Log); D.Ln;
				D.String("++++++++++ reachable flexible data sections ++++++++++"); flexibleDataSections.Dump(D.Log); D.Ln;
			END;

			(* arrange the sections (i.e. set the fixed attribute) such that the given fixed-positions and alignments are respected *)
			currentAddress := 0;
			flexibleDataSectionIndex := 0;
			(* go through all fixed data sections of the cell *)
			FOR fixedDataSectionIndex := 0 TO fixedDataSections.Length() DO (* note: the index may be out-of-bounds! *)
				IF fixedDataSectionIndex < fixedDataSections.Length() THEN
					fixedDataSection := fixedDataSections.GetSection(fixedDataSectionIndex);
					ASSERT(fixedDataSection.fixed);
					nextOccupiedAddress := fixedDataSection.positionOrAlignment
				ELSE
					(* there is no more fixed data section *)
					nextOccupiedAddress := MAX(SIZE)
				END;

				done := FALSE;
				WHILE ~done DO
					IF flexibleDataSectionIndex < flexibleDataSections.Length() THEN
						flexibleDataSection := flexibleDataSections.GetSection(flexibleDataSectionIndex);

						(* determine start-address of the next section (respect alignment) *)
						IF flexibleDataSection.IsAligned() & ((currentAddress MOD flexibleDataSection.positionOrAlignment) # 0) THEN
							startAddress := currentAddress + flexibleDataSection.positionOrAlignment - (currentAddress MOD flexibleDataSection.positionOrAlignment)
						ELSE
							startAddress := currentAddress
						END;

						(* determine end-address fo the next section *)
						endAddress := startAddress + flexibleDataSection.GetSize();

						IF endAddress <= nextOccupiedAddress THEN
							(* there is enough space for the section *)
							flexibleDataSection.SetPositionOrAlignment(TRUE, startAddress); (* position is set for section *)
							INC(flexibleDataSectionIndex);
							currentAddress := endAddress
						ELSE
							(* there is no more space for sections *)
							done := TRUE
						END
					ELSE
						(* there are no more flexible data sections *)
						done := TRUE
					END
				END;

				IF fixedDataSectionIndex < fixedDataSections.Length() THEN
					ASSERT(fixedDataSection.GetSize() # Sections.UnknownSize);
					currentAddress := fixedDataSection.positionOrAlignment + fixedDataSection.GetSize()
				END
			END;

			alreadyPrearrangedSinceLastSort := TRUE;

			IF Trace THEN D.String("after prearrangement"); D.Ln; DumpSections(D.Log, allSections); D.Ln END;
		END PrearrangeReachableDataSections;

		PROCEDURE PatchValueInSection*(CONST sectionName: Basic.SegmentedName; syntaxTreeValue: SyntaxTree.Value);
		VAR
			section: Sections.Section;
			emptyOperand, dataOperand: IntermediateCode.Operand;
			dataInstruction: IntermediateCode.Instruction;
			hugeintValue: SIGNED64;
		BEGIN
			section := allSections.FindByName(sectionName);
			ASSERT(section # NIL);

			IF syntaxTreeValue IS SyntaxTree.BooleanValue THEN
				(* BOOLEAN *)
				IF syntaxTreeValue(SyntaxTree.BooleanValue).value THEN hugeintValue := 1 ELSE hugeintValue := 0 END
			ELSIF syntaxTreeValue IS SyntaxTree.IntegerValue THEN
				(* SIGNED16 *)
				hugeintValue := syntaxTreeValue(SyntaxTree.IntegerValue).value;
			ELSE
				HALT(100)
			END;

			IntermediateCode.InitImmediate(dataOperand, IntermediateCode.GetType(backend.GetSystem(), syntaxTreeValue.type.resolved), hugeintValue);
			IntermediateCode.InitOperand(emptyOperand);
			IntermediateCode.InitInstruction(dataInstruction, Basic.invalidPosition, IntermediateCode.data, dataOperand, emptyOperand, emptyOperand);

			ASSERT(section IS IntermediateCode.Section);
			section(IntermediateCode.Section).EmitAt(0, dataInstruction)
		END PatchValueInSection;

		(** get all reachable sections in the form of an intermediate code module with a certain name **)
		PROCEDURE ExtractModuleWithName(CONST desiredName: ARRAY OF CHAR): Sections.Module;
		VAR
			result: Sections.Module;
			section: Sections.Section;
			i: SIZE;
		BEGIN
			NEW(result, NIL, backend.GetSystem()); (* note: there is no syntax tree *)
			result.SetModuleName(desiredName);
			result.SetPlatformName(platformName);
			result.SetImports(importList);

			(* add all of the reachable sections from the cumulative section list into the resulting module's section list *)
			FOR i := 0 TO allSections.Length() - 1 DO
				section := allSections.GetSection(i);

				(* remove any previously generated code *)
				ASSERT(section IS IntermediateCode.Section);
				section(IntermediateCode.Section).SetResolved(NIL);

				IF section.isReachable THEN result.allSections.AddSection(section) END
			END;

			IF RequireSortedSections THEN result.allSections.Sort(SectionPositionComparison) END;

			IF Trace THEN D.String("+++++++++ intermediate code module ++++++++++"); D.Ln; result.Dump(D.Log); D.Ln; END;

			RETURN result
		END ExtractModuleWithName;

		PROCEDURE SectionPositionComparison(leftObject, rightObject: ANY): BOOLEAN;
		VAR
			leftSection, rightSection: Sections.Section;
			leftPosition, rightPosition: SIZE;
		BEGIN
			ASSERT((leftObject IS Sections.Section) & (rightObject IS Sections.Section));
			leftSection := leftObject(Sections.Section);
			rightSection := rightObject(Sections.Section);

			IF leftSection.fixed THEN
				leftPosition := leftSection.positionOrAlignment
			ELSE
				leftPosition := MAX(SIZE)
			END;
			IF rightSection.fixed THEN
				rightPosition := rightSection.positionOrAlignment
			ELSE
				rightPosition := MAX(SIZE)
			END;
			IF leftSection.IsCode() & rightSection.IsCode() THEN RETURN FALSE END;
			RETURN leftPosition < rightPosition
		END SectionPositionComparison;

		(** whether a section should appear before another one in an assembly (used for sorting)
			- 1st priority: when sections have fixed positions, the ones with smaller addresses come first
			- 2nd priority: smaller sections come first
		**)
		PROCEDURE SectionPositionAndSizeComparison(leftObject, rightObject: ANY): BOOLEAN;
		VAR
			leftSection, rightSection: Sections.Section;
			leftPosition, rightPosition, leftSize, rightSize: SIZE;
		BEGIN
			ASSERT((leftObject IS Sections.Section) & (rightObject IS Sections.Section));
			leftSection := leftObject(Sections.Section);
			rightSection := rightObject(Sections.Section);

			IF leftSection.fixed THEN
				leftPosition := leftSection.positionOrAlignment
			ELSE
				leftPosition := MAX(SIZE)
			END;
			IF rightSection.fixed THEN
				rightPosition := rightSection.positionOrAlignment
			ELSE
				rightPosition := MAX(SIZE)
			END;

			IF ~leftSection.IsCode() & rightSection.IsCode() THEN (* data sections first *)
				RETURN TRUE
			ELSIF leftSection.IsCode() & ~rightSection.IsCode() THEN (* data sections first *)
				RETURN FALSE
			ELSIF leftSection.IsCode() & rightSection.IsCode() THEN (* code sections: sorted by linking preference, stable w.r.t. loading order *)
				IF GetPriority(leftSection) < GetPriority(rightSection) THEN
					RETURN TRUE
				ELSIF GetPriority(leftSection) = GetPriority(rightSection) THEN
					RETURN (leftSection.offset < rightSection.offset) (* must keep order as provided by loader *)
				ELSE
					RETURN FALSE
				END
			ELSIF leftPosition < rightPosition THEN (* data sections sorted by position *)
				RETURN TRUE
			ELSIF leftPosition > rightPosition THEN (* data sections sorted by position *)
				RETURN FALSE
			ELSE (* data section sorted by size, if no position provided *)
				ASSERT(leftPosition = rightPosition); (* note: this is the case for sections without fixed positions *)
				leftSize := leftSection.GetSize();
				rightSize := rightSection.GetSize();
				IF (leftSize = Sections.UnknownSize) OR (leftSize = 0) THEN leftSize := MAX(SIZE) END;
				IF (rightSize = Sections.UnknownSize) OR (rightSize = 0) THEN rightSize := MAX(SIZE) END;
				IF leftSize = rightSize THEN
					RETURN leftSection.offset < rightSection.offset (* keeping order as provided by loader, cosmetic *)
				ELSE
					RETURN leftSize < rightSize
				END
			END
		END SectionPositionAndSizeComparison;

		(* set address of sections to a fixed position after compilation *)
		PROCEDURE FixSections(binaryModule: Sections.Module; VAR sizes: ARRAY OF BinaryCode.Unit);
		VAR adr: BinaryCode.Unit; i: SIZE; section: Sections.Section; is: BinaryCode.Section;
		BEGIN
			adr := 0;
			FOR i := 0 TO binaryModule.allSections.Length()-1 DO
				section := binaryModule.allSections.GetSection(i);
				is := section(IntermediateCode.Section).resolved;
				IF (is # NIL) & section.IsCode() THEN
					(*
					Basic.WriteSegmentedName(D.Log,section.name);
					D.String(" @ "); D.Int(adr,1); D.Ln;
					*)
					backend.CheckCodeAddress(adr);
					is.SetAlignment(TRUE, adr);
					IF is.pc > sizes[i] THEN sizes[i] := is.pc END;
					adr := adr + sizes[i];
				END;
				is.Reset; (* enable recompilation *)
			END;
		END FixSections;

		(* check if any of the addresses of sections have changed during last compilation *)
		PROCEDURE Conflict(binaryModule: Sections.Module; VAR sizes: ARRAY OF BinaryCode.Unit): BOOLEAN;
		VAR i: SIZE; section: Sections.Section;is: BinaryCode.Section;
		BEGIN
			FOR i := 0 TO binaryModule.allSections.Length()-1 DO
				section := binaryModule.allSections.GetSection(i);
				is := section(IntermediateCode.Section).resolved;
				IF (is # NIL) & section.IsCode() THEN
					IF is.pc > sizes[i] THEN RETURN TRUE
					(*
					not necessary, the linker places correctly.
					ELSIF is.pc < sizes[i] THEN is.SetPC(sizes[i]) (* set section size to maximal observed size *)
					*)
					END;
				END;
			END;
			RETURN FALSE
		END Conflict;

		(* generate binary code and write an object file with a desired module name *)
		PROCEDURE GenerateObjectFile*(objectFileFormat: Formats.ObjectFileFormat; log: Streams.Writer; CONST desiredName: ARRAY OF CHAR): BOOLEAN;
		VAR
			count: SIZE;
			intermediateCodeModule: Sections.Module;
			binaryModule: Formats.GeneratedModule;
			result: BOOLEAN;
			sizes: POINTER TO ARRAY OF BinaryCode.Unit; i: SIZE;
			objectFileExtension: ARRAY 32 OF CHAR; objectFileName: Files.FileName;
		BEGIN
			intermediateCodeModule := ExtractModuleWithName(desiredName);
			result := TRUE;

			(* generate binary code *)
			backend.Initialize(diagnostics, log, {}, NIL, backend.GetSystem());
			backend.SetCodeUnit(codeUnit);
			binaryModule := backend.ProcessIntermediateCodeModule(intermediateCodeModule); count := 0;

			(* iterative compilation until all sections remain fixed at their position *)
			NEW(sizes, binaryModule(Sections.Module).allSections.Length());
			FOR i := 0 TO LEN(sizes)-1 DO sizes[i] := 0 END;
			REPEAT
				INC(count);
				(* fix all section addresses *)
				FixSections(binaryModule(Sections.Module),sizes^);
				(* compile *)
				binaryModule := backend.ProcessIntermediateCodeModule(intermediateCodeModule);
				(* and repeat if any of the section addresses have to be adapted *)
			UNTIL ~Conflict(binaryModule(Sections.Module),sizes^) OR (count > 10) ;
			ASSERT(count <=10);

			IF binaryModule = NIL THEN
				Basic.Error(diagnostics, desiredName,Basic.invalidPosition, "the specified backend cannot process intermediate code");
				result := FALSE
			ELSIF backend.error THEN
				Basic.Error(diagnostics, desiredName, Basic.invalidPosition, "binary code could not be generated (backend error)");
				result := FALSE
			ELSE
				IF Trace THEN D.String(">>> binary code successfully generated"); D.Ln END;
				IF objectFileFormat = NIL THEN
					Basic.Error(diagnostics, desiredName, Basic.invalidPosition, "no object file format specified");
					result := FALSE
				ELSE
					(* write the generated code into an object file *)
					objectFileFormat.Initialize(diagnostics);
					IF objectFileFormat.Export(binaryModule, NIL) THEN
						IF log # NIL THEN
							log.String("assembled "); log.String(desiredName); log.String(" => ");
							objectFileFormat.GetExtension(objectFileExtension);
							Files.JoinExtension(desiredName, objectFileExtension, objectFileName);
							log.String(objectFileName); log.Ln;
						END;
						IF Trace THEN D.String(">>> object file successfully written"); D.Ln END;
					ELSE
						Basic.Error(diagnostics, desiredName, Basic.invalidPosition, "object file could not be written");
						result := FALSE
					END
				END
			END;
			RETURN result
		END GenerateObjectFile;

	END Linker;

TYPE

	PROCEDURE FileNameToModuleName(CONST filename: ARRAY OF CHAR; VAR moduleName: ARRAY OF CHAR);
	VAR extension: Files.FileName;
	BEGIN
		Files.SplitExtension(filename, moduleName, extension);
	END FileNameToModuleName;

	PROCEDURE SectionNameToFileName(CONST sectionName: ARRAY OF CHAR; VAR fileName: ARRAY OF CHAR);
	VAR i: SIZE;
	BEGIN
		i := 0;
		WHILE (sectionName[i] # 0X) & (sectionName[i] # ".") DO
			fileName[i] := sectionName[i];
			INC(i);
		END;
		fileName[i] := 0X;
	END SectionNameToFileName;

	PROCEDURE GetPriority*(block: Sections.Section): INTEGER;
	CONST Fixed=0; EntryCode=1;InitCode=2; ExitCode=3; BodyCode=4;Code=5; Data=6; Const=7; Empty =8;
	BEGIN
		IF block.fixed THEN RETURN Fixed END;
		IF block.type = ObjectFile.EntryCode THEN RETURN EntryCode END;
		IF block.type = ObjectFile.InitCode THEN RETURN InitCode END;
		IF block.type = ObjectFile.ExitCode THEN RETURN ExitCode END;
		IF block.type = ObjectFile.BodyCode THEN RETURN Code END; (* BodyCode does not necessarily have to be in front of code *)
		IF block.GetSize () = 0 THEN RETURN Empty END;
		IF block.type = ObjectFile.Code THEN RETURN Code END;
		IF block.type = ObjectFile.Data THEN RETURN Code END;
		IF block.type = ObjectFile.Const THEN RETURN Code END;
		HALT(100); (* undefined type *)
	END GetPriority;

	PROCEDURE CopySections*(from, to: Sections.SectionList);
	VAR section, copy: IntermediateCode.Section; i, j: SIZE; s: Sections.Section; instruction: IntermediateCode.Instruction;
	BEGIN
		FOR i := 0 TO from.Length()-1 DO
			s := from.GetSection(i);
			section := s(IntermediateCode.Section);
			copy := IntermediateCode.NewSection(to, section.type, section.name, NIL, FALSE);
			copy.SetBitsPerUnit(section.bitsPerUnit);
			copy.SetPositionOrAlignment(section.fixed, section.positionOrAlignment);
			copy.SetFingerprint(section.fingerprint);
			FOR j := 0 TO section.pc-1 DO
				instruction := section.instructions[j];
				copy.Emit(instruction);
			END;
		END;
	END CopySections;

	PROCEDURE Link*(context: Commands.Context);
	VAR
		input: Streams.Reader;
		diagnostics: Diagnostics.StreamDiagnostics;
		defaultBackend: Backend.Backend;
		objectFileFormat: Formats.ObjectFileFormat;
		filename, name, targetFile: Files.FileName;
		assemblinker: Linker;
		error, result, parsed: BOOLEAN;
		options:Options.Options;
		position: Streams.Position;
		moduleName: SyntaxTree.IdentifierString;

		PROCEDURE Error(CONST error: ARRAY OF CHAR);
		BEGIN
			IF diagnostics # NIL THEN
				Basic.Error(diagnostics, "",Basic.invalidPosition, error);
			END;
		END Error;

	BEGIN
		input := context.arg;
		NEW(diagnostics, context.out);
		result := TRUE;
		NEW(options);
		options.Add("b","backend",Options.String);
		options.Add(0X, "objectFile", Options.String);
		options.Add(0X, "targetFile", Options.String);

		position := input.Pos();
		parsed := options.ParseStaged(input, context.error);

		IF options.GetString("b", name) THEN
			IF name = "" THEN defaultBackend := NIL
			ELSE
				defaultBackend := Backend.GetBackendByName(name);
				IF (defaultBackend = NIL)  THEN
					Error("backend could not be installed"); result := FALSE;
				END;
			END;
		ELSE defaultBackend := Backend.GetBackendByName(DefaultBackend);
			IF defaultBackend = NIL THEN Error("default backend could not be installed"); result := FALSE END;
		END;

		IF options.GetString("objectFile",name) THEN
			IF name = "" THEN objectFileFormat := NIL
			ELSE
				objectFileFormat := Formats.GetObjectFileFormat(name);
				IF objectFileFormat = NIL THEN Error("object file format could not be installed"); result := FALSE END;
			END;
		ELSIF defaultBackend # NIL THEN
			objectFileFormat := defaultBackend.DefaultObjectFileFormat();
		END;
		IF defaultBackend # NIL THEN defaultBackend.DefineOptions (options); END;
		IF objectFileFormat # NIL THEN objectFileFormat.DefineOptions(options); END;

		IF result & ~parsed THEN
			options.Clear;
			input.SetPos(position);
			result := options.Parse(input,context.error)
		END;

		IF result THEN
			IF defaultBackend # NIL THEN defaultBackend.GetOptions (options) END;
			IF objectFileFormat # NIL THEN objectFileFormat.GetOptions(options) END;
			IF ~options.GetString("targetFile",targetFile) THEN targetFile := "" END;
		END;

		error := ~result;
		IF targetFile # "" THEN
			NEW(assemblinker, diagnostics, defaultBackend);
		END;
		WHILE Basic.GetStringParameter(input,filename) & ~error DO
			IF targetFile = "" THEN NEW(assemblinker, diagnostics, defaultBackend) END;
			IF assemblinker.LoadModule(filename, FALSE) THEN
				assemblinker.MarkReachabilityOfAll(TRUE);
				FileNameToModuleName(filename, moduleName);
				IF (targetFile = "") & assemblinker.GenerateObjectFile(objectFileFormat, context.out, moduleName) THEN
					Basic.Information(diagnostics, filename, Basic.invalidPosition, "done.")
				ELSIF targetFile # "" THEN
					Basic.Information(diagnostics, filename,  Basic.invalidPosition, "loaded.")
				ELSE
					error := TRUE
				END
			ELSE
				error := TRUE
			END
		END;
		IF ~error & (targetFile # "") THEN
			assemblinker.PrearrangeReachableDataSections;
			IF assemblinker.GenerateObjectFile(objectFileFormat, context.out, targetFile)
			THEN
				Basic.Information(diagnostics, targetFile, Basic.invalidPosition, "generated.")
			ELSE error := FALSE
			END;
		END;
	END Link;

	PROCEDURE WriteCodeAndDataFiles*(CONST instanceName: ARRAY OF CHAR; CONST codeFileExtension, dataFileExtension: ARRAY OF CHAR; objectFile: Formats.ObjectFileFormat; VAR instructionMemorySize, dataMemorySize: BinaryCode.Unit; backend: Backend.Backend;  diagnostics: Diagnostics.Diagnostics; log:Streams.Writer): BOOLEAN;
	VAR code, data: StaticLinker.Arrangement; linker: GenericLinker.Linker; linkerLog: Files.Writer;
			logFile: Files.File;
			objectFileExtension: ARRAY 32 OF CHAR;
			error : BOOLEAN;
			fileName, codeFileName, dataFileName: Files.FileName;
			system: Global.System;
			msg: ARRAY 256 OF CHAR;
	CONST MinimalStackSize = 64;
	(*CONST CodeFileExtension="code"; DataFileExtension="data";*)
	BEGIN
		error := FALSE;
		NEW (code, 0); NEW (data, 0);
		COPY(instanceName, fileName); Strings.Append(fileName,".log");	logFile := Files.New(fileName);
		IF logFile # NIL THEN NEW(linkerLog,logFile,0) ELSE logFile := NIL END;
		NEW (linker, diagnostics, linkerLog, GenericLinker.UseInitCode, code, data);
		StaticLinker.ReadObjectFile(instanceName, "",objectFile.extension, linker, NIL);

				(* do linking after having read in all blocks to account for potential constraints *)
				IF ~linker.error THEN linker.Link; END;

				system := backend.GetSystem();

				IF (instructionMemorySize > 0) & (instructionMemorySize < code.SizeInBits() DIV system.codeUnit) THEN
					Basic.Error(diagnostics, instanceName, Basic.invalidPosition, "specified instruction memory size too small");
					error := TRUE;
				ELSIF instructionMemorySize = 0 THEN
					instructionMemorySize := code.SizeInBits() DIV system.codeUnit;
				END;

				dataMemorySize := MAX(data.SizeInBits() DIV system.dataUnit, dataMemorySize);

				IF (dataMemorySize - data.SizeInBits() DIV system.dataUnit) < MinimalStackSize THEN
					Basic.Error(diagnostics, instanceName,Basic.invalidPosition, "specified data memory size too small");
					error := TRUE;
				END;

				Files.JoinExtension(instanceName,codeFileExtension,codeFileName);
				Files.JoinExtension(instanceName,dataFileExtension,dataFileName);

				IF ~linker.error THEN
					StaticLinker.WriteOutputFile (code, codeFileName, linker, StaticLinker.WriteTRMCodeFile);
					StaticLinker.WriteOutputFile (data, dataFileName, linker, StaticLinker.WriteTRMDataFile);

					IF linkerLog # NIL THEN linkerLog.Update; Files.Register(logFile) END;
					IF log # NIL THEN
						log.String(instanceName);
						log.String(" linked. IM = ");log.Int(instructionMemorySize,1);
						log.String(" (used: "); log.Int(code.SizeInBits() DIV system.codeUnit,1);
						log.String("), DM = "); log.Int(dataMemorySize,1);
						log.String(" (used: "); log.Int(data.SizeInBits() DIV system.dataUnit,1);
						log.String(")");
						log.Ln; log.Update;

						log.String("generated code file: ");log.String(codeFileName); log.Ln;
						log.String("generated data file: ");log.String(dataFileName); log.Ln;

					END;
				ELSE
					msg := "could not link ";
					Strings.Append(msg,instanceName);
					Basic.Error(diagnostics, "",Basic.invalidPosition, msg);
				END;
				RETURN ~linker.error & ~error

	END WriteCodeAndDataFiles;

	(* to link active cells
		- load all intermediate code files and collect all sections in one object
		- for each cell instance
			- find body stub by name of cell type
			- find all descending sections recursively (!! may depend on backend needs !)
			- add sections for ports and properties
			- assemble, generate gof file
			- link gof file

		- ir code / data units depend on section type, do not necessarily have to be stored
	*)

	PROCEDURE Test*(context: Commands.Context);
	VAR
		input: Streams.Reader;
		diagnostics: Diagnostics.StreamDiagnostics;
		defaultBackend: Backend.Backend;
		objectFileFormat: Formats.ObjectFileFormat;
		name, typeName, instanceName: Files.FileName;
		result, parsed: BOOLEAN;
		options:Options.Options;
		position: Streams.Position;
		extension: SyntaxTree.IdentifierString;
		linker: Linker;

		PROCEDURE Error(CONST error: ARRAY OF CHAR);
		BEGIN
			IF diagnostics # NIL THEN
				Basic.Error(diagnostics, "",Basic.invalidPosition, error);
			END;
		END Error;

	BEGIN
		input := context.arg;
		NEW(diagnostics, context.out);
		result := TRUE;
		NEW(options);
		options.Add("b","backend",Options.String);
		options.Add(0X, "objectFile", Options.String);
		options.Add(0X, "targetFile", Options.String);
		options.Add(0X, "extension", Options.String);

		position := input.Pos();
		parsed := options.ParseStaged(input, context.error);

		IF options.GetString("b", name) THEN
			IF name = "" THEN defaultBackend := NIL
			ELSE
				defaultBackend := Backend.GetBackendByName(name);
				IF (defaultBackend = NIL)  THEN
					Error("backend could not be installed"); result := FALSE;
				END;
			END;
		ELSE defaultBackend := Backend.GetBackendByName(DefaultBackend);
			IF defaultBackend = NIL THEN Error("default backend could not be installed"); result := FALSE END;
		END;

		IF options.GetString("objectFile",name) THEN
			IF name = "" THEN objectFileFormat := NIL
			ELSE
				objectFileFormat := Formats.GetObjectFileFormat(name);
				IF objectFileFormat = NIL THEN Error("object file format could not be installed"); result := FALSE END;
			END;
		ELSIF defaultBackend # NIL THEN
			objectFileFormat := defaultBackend.DefaultObjectFileFormat();
		END;
		IF defaultBackend # NIL THEN defaultBackend.DefineOptions (options); END;
		IF objectFileFormat # NIL THEN objectFileFormat.DefineOptions(options); END;

		IF result & ~parsed THEN
			options.Clear;
			input.SetPos(position);
			result := options.Parse(input,context.error)
		END;

		IF result THEN
			IF defaultBackend # NIL THEN defaultBackend.GetOptions (options) END;
			IF objectFileFormat # NIL THEN objectFileFormat.GetOptions(options) END;
		END;

		IF ~options.GetString("extension",extension) THEN extension := "" END;

		NEW(linker, diagnostics, defaultBackend);

		IF Basic.GetStringParameter(input, typeName) & Basic.GetStringParameter(input, instanceName) THEN
			IF linker.LinkPrefixed(typeName) THEN
				linker.PrearrangeReachableDataSections;
				IF linker.GenerateObjectFile(objectFileFormat, context.out, instanceName) THEN
					context.out.String("generated "); context.out.String(instanceName);
					context.out.String(objectFileFormat.extension);
					context.out.Ln;
				END;
			END;
		END;

		(*
		error := ~result;
		IF targetFile # "" THEN
			NEW(assemblinker, diagnostics, defaultBackend, "");
		END;

		IF Basic.GetStringParameter(input, name) THEN
			SectionNameToFileName(name, filename);
			TRACE(filename);
			IF assemblinker.LoadModule(filename, FALSE) THEN
				segmentedName := name;
				assemblinker.MarkAsReachableStartingWith(segmentedName, {Sections.InitCodeSection, Sections.BodyCodeSection});
			END;
		END;
		*)
		(*
		WHILE Basic.GetStringParameter(input,filename) & ~error DO
			IF targetFile = "" THEN NEW(assemblinker, diagnostics, defaultBackend, "") END;
			IF assemblinker.LoadModule(filename, FALSE) THEN
				assemblinker.MarkReachabilityOfAll(TRUE);
				FileNameToModuleName(filename, moduleName);
				IF (targetFile = "") & assemblinker.GenerateObjectFile(objectFileFormat, context.out, moduleName) THEN
					Basic.Information(diagnostics, filename, Streams.Invalid, "done.")
				ELSIF targetFile # "" THEN
					Basic.Information(diagnostics, filename,  Streams.Invalid, "loaded.")
				ELSE
					error := TRUE
				END
			ELSE
				error := TRUE
			END
		END;
		*)
		(*
		IF ~error & (targetFile # "") THEN
			assemblinker.PrearrangeReachableDataSections;
			IF assemblinker.GenerateObjectFile(objectFileFormat, context.out, targetFile) THEN
				Basic.Information(diagnostics, targetFile, Streams.Invalid, "generated.")
			ELSE error := FALSE
			END;
		END;
		*)
	END Test;

END FoxIntermediateLinker.

System.FreeDownTo FoxIntermediateLinker ~
FoxIntermediateObjectFile.Show Test ~
FoxIntermediateLinker.Link -b=TRM --targetFile=Test Test ~
FoxGenericObjectFile.Show Test.Gof ~

FoxIntermediateLinker.Test -b=TRM --targetFile=Test --extension=.IroT TestActiveCells.TestCellnet.Controller MyController_Name  ~

FoxGenericObjectFile.Show MyController_Name.Gof ~
