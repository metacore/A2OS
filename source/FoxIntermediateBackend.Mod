MODULE FoxIntermediateBackend; (** AUTHOR ""; PURPOSE ""; *)

IMPORT Basic := FoxBasic, SyntaxTree := FoxSyntaxTree, SemanticChecker := FoxSemanticChecker, Backend := FoxBackend, Global := FoxGlobal,
	Scanner := FoxScanner, IntermediateCode := FoxIntermediateCode, Sections := FoxSections, BinaryCode := FoxBinaryCode,  Printout := FoxPrintout,
	SYSTEM, Strings, Options, Streams, Compiler, Formats := FoxFormats, SymbolFileFormat := FoxTextualSymbolFile, D := Debugging,
	Fingerprinter := FoxFingerprinter, StringPool, CRC;

CONST
		(* operand modes *)
		ModeUndefined = 0;
		ModeReference = 1;
		ModeValue = 2;

		(* heap data offsets *)
		ArrayDimTable = 3;	(* dimension table in dyn arrays *)

		(* math array offsets *)
		MathPtrOffset=0;
		MathAdrOffset=1;
		MathFlagsOffset=2;
		MathDimOffset=3;
		MathElementSizeOffset=4;
		MathLenOffset=5;
		MathIncrOffset=6;

		SysDataArrayOffset* = 0; (* array offset in system bl	ock, for 32 byte alignment *)
		ArrDataArrayOffset*= 16*8; (* 16 bytes array offset in array block, to be compatible with the GC scheme of POINTER TO ARRAY OF ... *)

		TensorFlag* = 0;   (* flag indicating a tensor array *)
		RangeFlag* = 1;   (* flag indicating a range, e.g. an array derived from A[..,..] *)
		StackFlag* = 2;   (* flag indicates temporary result *)
		StaticFlag* = 1;   (* flag indicating a static array, may not be reallocated *)

		(** compiler generated traps *)
		WithTrap* = 1; (* generated when a WITH statement fails *)
		CaseTrap* = 2; (* generated when a case statement without else block fails *)
		ReturnTrap* = 3;
		TypeEqualTrap* = 5;
		TypeCheckTrap* = 6;
		IndexCheckTrap* = 7; (* generated when index is out of bounds or range is invalid *)
		AssertTrap* = 8; (* generated when an assert fails *)
		ArraySizeTrap* = 9;
		ArrayFormTrap*=10; (* indicates that array cannot be (re-)allocated since shape, type or size does not match *)
		SetElementTrap*=11; (* indicates that a set element is out of MIN(SET)...MAX(SET) *)
		NegativeDivisorTrap*=12;
		NoReturnTrap*=16; (* indicates that a procedure marked no return did return *)
		NilPointerTrap*=17; (* indicates that a nil pointer was being dereferenced *)
		RethrowTrap* = 18; (* rethrow exception after unlock *)
		Trace = FALSE;
		TraceRegisterUsageCount=TRUE;

		ArrayAlignment = 8*8;			(* first array element of ArrayBlock and first data element of SystemBlock must be aligned to 0 MOD ArrayAlignment *)

		(** system call numbers  *)
		NumberSystemCalls* = 12;
		SysNewRec* = 0;  SysNewArr* = 1;  SysNewSys* = 2;  SysCaseTable* = 3;  SysProcAddr* = 4;
		SysLock* = 5;  SysUnlock* = 6;  SysStart* = 7;  SysAwait* = 8; SysInterfaceLookup* = 9;
		SysRegisterInterface* = 10; SysGetProcedure* = 11;

		DefaultBuiltinsModuleName ="Builtins";
		DefaultTraceModuleName ="KernelLog";
		ChannelModuleName = "Channels";

		NonPointer = -1; (* special pointer values *)
		NoType = 0; (* special type info values *)
		LhsIsPointer = 0; (* for the operator kind *)
		RhsIsPointer = 1;

		(* priority values, lower means higher priority *)
		BasePointerTypeSize = 5;
		BaseArrayTypeSize = BasePointerTypeSize + 3;
			LengthOffset = BasePointerTypeSize + 0;
			DataOffset = BasePointerTypeSize + 1;
			DescriptorOffset = BasePointerTypeSize + 2;
		BaseRecordTypeSize = BasePointerTypeSize + 2;
			ActionOffset = BasePointerTypeSize + 0;
			MonitorOffset = BasePointerTypeSize + 1;
		BaseObjectTypeSize = BaseRecordTypeSize;
			ActionTypeSize = 3;
			MonitorTypeSize = 7;
			ProcessorOffset = BaseObjectTypeSize + 1;
			StackLimitOffset* = BaseObjectTypeSize + 3;
			QuantumOffset = BaseObjectTypeSize + 4;

		(* flags for optimizations with small matricies and vectors (Alexey Morozov) *)
		SmallMatrixFlag = 3; (* flag for identification of a small matrix *)
		SmallVectorFlag = 3; (* flag for identification of a small vector *)
		Size2Flag = 4; (* size = 2 *)
		Size3Flag = 5; (* size = 3 *)
		Size4Flag = 6; (* size = 4 *)
		Size5Flag = 7; (* size = 5 *)
		Size6Flag = 8; (* size = 6 *)
		Size7Flag = 9; (* size = 7 *)
		Size8Flag = 10; (* size = 8 *)

		ReflectionSupport = TRUE;
		(* Solution for identifying procedure descriptors on the stack and for being able to differentiate "old school" stack frames from the underlying operating system stack frames:
			push a procedure desriptor plus one to where the BP pointer would be located. The misalignment of the procedure descriptor makes it possible to identify that it is not
			a base pointer but a procedure descriptor. The base pointer itself is in such cases located at BP + address size.
		*)

		(* I am not 100% sure if it is necessary or not -- so I keep a flag to be able to re-enable this *)
		ProtectModulesPointers = FALSE;

		CreateProcedureDescInfo = TRUE;

		WarningDynamicLoading = FALSE;

		SysvABI = {SyntaxTree.CCallingConvention};
		SysvABIorWINAPI = {SyntaxTree.CCallingConvention, SyntaxTree.WinAPICallingConvention};

TYPE
	Position=SyntaxTree.Position;
	SupportedInstructionProcedure* = PROCEDURE {DELEGATE} (CONST instr: IntermediateCode.Instruction; VAR moduleName,procedureName: ARRAY OF CHAR): BOOLEAN;
	SupportedImmediateProcedure* = PROCEDURE {DELEGATE} (CONST op: IntermediateCode.Operand): BOOLEAN;

	WriteBackCall = POINTER TO RECORD
		call: SyntaxTree.ProcedureCallDesignator;
		next: WriteBackCall;
	END;

	Operand = RECORD
		mode: SHORTINT;
		op: IntermediateCode.Operand;
		tag: IntermediateCode.Operand;
		extra: IntermediateCode.Operand; (* stores the step size of an array range *)
		dimOffset: LONGINT;
		availability: WORD; (* index *)
	END;

	Fixup= POINTER TO RECORD
		pc: LONGINT;
		nextFixup: Fixup;
	END;

	Label= OBJECT
	VAR
		fixups: Fixup;
		section: IntermediateCode.Section;
		pc: LONGINT;

		PROCEDURE &InitLabel(section: IntermediateCode.Section);
		BEGIN
			SELF.section := section; pc := -1;
		END InitLabel;

		PROCEDURE Resolve(pc: LONGINT);
		VAR at: LONGINT;
		BEGIN
			SELF.pc := pc;
			WHILE(fixups # NIL) DO
				at := fixups.pc;
				section.PatchAddress(at,pc);
				fixups := fixups.nextFixup;
			END;
		END Resolve;

		PROCEDURE AddFixup(at: LONGINT);
		VAR fixup: Fixup;
		BEGIN
			ASSERT(pc=-1);
			NEW(fixup); fixup.pc := at; fixup.nextFixup := fixups; fixups := fixup;
		END AddFixup;

	END Label;

	ConditionalBranch = PROCEDURE {DELEGATE}(label: Label; op1,op2: IntermediateCode.Operand);

	DeclarationEmitter =OBJECT
	VAR
		backend: IntermediateBackend;
		implementationEmitter: ImplementationEmitter;
		meta: MetaDataGenerator;
		system: Global.System;
		currentScope: SyntaxTree.Scope;
		module: Sections.Module;
		moduleSelf: SyntaxTree.Variable;
		dump: BOOLEAN;
		forceModuleBody: BOOLEAN;
		addressType: IntermediateCode.Type;

		PROCEDURE & Init(system: Global.System; implementationEmitter: ImplementationEmitter; backend: IntermediateBackend; forceModuleBody, dump: BOOLEAN);
		BEGIN
			currentScope := NIL; module := NIL; moduleSelf := NIL;
			SELF.system := system; SELF.implementationEmitter := implementationEmitter;
			SELF.dump := dump;
			SELF.backend := backend;
			SELF.forceModuleBody := forceModuleBody;
			addressType := IntermediateCode.GetType(system,system.addressType)
		END Init;

		PROCEDURE Error(position: Position; CONST s: ARRAY OF CHAR);
		BEGIN
			backend.Error(module.module.sourceName, position, Streams.Invalid, s);
		END Error;

		(** types **)

		PROCEDURE Type(x: SyntaxTree.Type);
		BEGIN
			WITH x:
			SyntaxTree.QualifiedType DO QualifiedType(x)
			|SyntaxTree.MathArrayType DO meta.CheckTypeDeclaration(x)
			|SyntaxTree.PointerType DO meta.CheckTypeDeclaration(x)			(* base type must not be visited => will be done via record type declaration, otherwise is done twice ! *)
			|SyntaxTree.RecordType DO RecordType(x)
			|SyntaxTree.CellType DO CellType(x)
			ELSE
			END;
		END Type;

		PROCEDURE QualifiedType(x: SyntaxTree.QualifiedType);
		VAR type: SyntaxTree.Type;
		BEGIN (* no further traversal to x.resolved necessary since type descriptor and code will be inserted at "original" position ? *)
			type := x.resolved;
			IF (type.typeDeclaration # NIL) & (type.typeDeclaration.scope.ownerModule # module.module) THEN
				meta.CheckTypeDeclaration(type);
			END;
		END QualifiedType;

		PROCEDURE HasFlag(modifiers: SyntaxTree.Modifier; CONST name: ARRAY OF CHAR): BOOLEAN;
		VAR this: SyntaxTree.Modifier; id: SyntaxTree.Identifier;
		BEGIN
			this := modifiers; id := SyntaxTree.NewIdentifier(name);
			WHILE (this # NIL) & (this.identifier# id) DO
				this := this.nextModifier;
			END;
			RETURN this # NIL
		END HasFlag;

		PROCEDURE RecordType(x: SyntaxTree.RecordType);
		VAR name: ARRAY 256 OF CHAR; td: SyntaxTree.TypeDeclaration;
		BEGIN (* no code emission *)
			meta.CheckTypeDeclaration(x);
			IF (x.recordScope.ownerModule = module.module) & (x.isObject) THEN
				IF x.pointerType.typeDeclaration # NIL THEN
					td := x.pointerType.typeDeclaration
				ELSE
					td := x.typeDeclaration
				END;
				Global.GetSymbolName(td,name);

				(* code section for object *)
			END;
			Scope(x.recordScope);
		END RecordType;

		PROCEDURE CellType(x: SyntaxTree.CellType);
		VAR capabilities: SET;
		BEGIN
			IF backend.cellsAreObjects THEN meta.CheckTypeDeclaration(x) END;
			capabilities := {};
			IF HasFlag(x.modifiers, Global.StringFloatingPoint) THEN INCL(capabilities, Global.FloatingPointCapability) END;
			IF HasFlag(x.modifiers, Global.StringVector) THEN INCL(capabilities, Global.VectorCapability) END;
			backend.SetCapabilities(capabilities);

			IF ~implementationEmitter.checker.SkipImplementation(x) THEN
				Scope(x.cellScope);
			END;
		END CellType;

		(* symbols *)

		PROCEDURE Variable(x: SyntaxTree.Variable);
		VAR name: Basic.SegmentedName; irv: IntermediateCode.Section; align,  dim, i: LONGINT;
			size: LONGINT; lastUpdated: LONGINT; imm: IntermediateCode.Operand;

			PROCEDURE TypeNeedsInitialization(type: SyntaxTree.Type): BOOLEAN;
			BEGIN
				type := type.resolved;
				IF type IS SyntaxTree.RecordType THEN
					IF ScopeNeedsInitialization(type(SyntaxTree.RecordType).recordScope) THEN RETURN TRUE END;
				ELSIF (type IS SyntaxTree.ArrayType) THEN
					IF type(SyntaxTree.ArrayType).form = SyntaxTree.Static THEN
						IF TypeNeedsInitialization(type(SyntaxTree.ArrayType).arrayBase) THEN RETURN TRUE END;
					END;
				ELSIF type IS SyntaxTree.MathArrayType THEN
					WITH type: SyntaxTree.MathArrayType DO
						IF type.form = SyntaxTree.Open THEN
							RETURN TRUE
						ELSIF type.form = SyntaxTree.Static THEN
							IF TypeNeedsInitialization(type.arrayBase) THEN RETURN TRUE END;
						END;
					END;
				END;
				RETURN FALSE
			END TypeNeedsInitialization;

			PROCEDURE ScopeNeedsInitialization(scope: SyntaxTree.Scope): BOOLEAN;
			VAR variable: SyntaxTree.Variable;
			BEGIN
				variable := scope.firstVariable;
				WHILE variable # NIL DO
					IF TypeNeedsInitialization(variable.type) THEN RETURN TRUE END;
					IF variable.initializer # NIL THEN RETURN TRUE END;
					variable := variable.nextVariable;
				END;
				RETURN FALSE
			END ScopeNeedsInitialization;

			PROCEDURE SingleInitialize(CONST op: IntermediateCode.Operand; offset:LONGINT);
			VAR size: LONGINT;
			BEGIN
					size := offset - lastUpdated;
					IF size > 0 THEN
						irv.Emit(Reserve(x.position,size));
					END;
					irv.Emit(Data(x.position, op));
					lastUpdated := offset + ToMemoryUnits(system, op.type.sizeInBits);
			END SingleInitialize;

			PROCEDURE Initialize(type: SyntaxTree.Type; initializer: SyntaxTree.Expression; offset:LONGINT);
			VAR op: Operand; baseType: SyntaxTree.Type; variable: SyntaxTree.Variable; i: LONGINT; size:LONGINT;
			BEGIN
				IF type = NIL THEN RETURN ELSE type := type.resolved END;
				WITH type:
				SyntaxTree.RecordType DO
					baseType := type.baseType;
					IF baseType # NIL THEN
						baseType := baseType.resolved;
						IF baseType IS SyntaxTree.PointerType THEN
							baseType := baseType(SyntaxTree.PointerType).pointerBase
						END;
						Initialize(baseType,NIL, offset);
					END;
					variable := type.recordScope.firstVariable;
					WHILE variable # NIL DO
						Initialize(variable.type, variable.initializer, offset+ToMemoryUnits(system,variable.offsetInBits));
						variable := variable.nextVariable
					END;
				| SyntaxTree.ArrayType DO
						IF type.form = SyntaxTree.Static THEN
							baseType := type.arrayBase;
							IF TypeNeedsInitialization(baseType) THEN
								size := ToMemoryUnits(system,system.AlignedSizeOf(baseType));
								FOR i := 0 TO type.staticLength-1 DO
									Initialize(baseType,NIL,offset+i*size);
								END;
							END;
						END;
				| SyntaxTree.MathArrayType DO
						IF type.form = SyntaxTree.Open THEN
							dim := DynamicDim(type);
							baseType := SemanticChecker.ArrayBase(type,dim);
							imm := IntermediateCode.Immediate(addressType,dim);
							SingleInitialize(imm, offset + ToMemoryUnits(system, addressType.sizeInBits)* MathDimOffset);
							IF baseType = NIL THEN size := 0 ELSE size := system.AlignedSizeOf(baseType) END;
							imm := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,size));
							SingleInitialize(imm, offset + ToMemoryUnits(system, addressType.sizeInBits)* MathElementSizeOffset);
							(* flags remain empty (=0) for open array *)
						ELSIF type.form = SyntaxTree.Static THEN
							baseType := type.arrayBase;
							IF TypeNeedsInitialization(baseType) THEN
								size := ToMemoryUnits(system,system.AlignedSizeOf(baseType));
								ASSERT(type.staticLength < 1024*1024*1024);
								FOR i := 0 TO type.staticLength-1 DO
									Initialize(baseType,NIL,offset+i*size);
								END;
							END;
						END;
				ELSE
					IF initializer # NIL THEN
						implementationEmitter.Evaluate(initializer, op);
						SingleInitialize(op.op, offset);
					END;
				END;
			END Initialize;

		BEGIN
			IF x.externalName # NIL THEN RETURN END;
			IF (currentScope IS SyntaxTree.ModuleScope) OR (currentScope IS SyntaxTree.CellScope) & ~backend.cellsAreObjects THEN
				(* code section for variable *)
				Global.GetSymbolSegmentedName(x,name);
				irv := implementationEmitter.NewSection(module.allSections, Sections.VarSection, name,x,dump);
				irv.SetExported(IsExported(x));
				irv.SetOffset(ToMemoryUnits(system,x.offsetInBits));
				IF (currentScope IS SyntaxTree.CellScope) & IsSemiDynamicArray(x.type) THEN
					irv.Emit(Reserve(x.position, ToMemoryUnits(system, system.addressSize)));
					Basic.SuffixSegmentedName (name, Basic.MakeString ("@len"));
					irv := implementationEmitter.NewSection(module.allSections, Sections.VarSection, name,NIL,dump);
					FOR i := 0 TO DynamicDim(x.type)-1 DO
						irv.Emit(Reserve(x.position, ToMemoryUnits(system, system.addressSize)));
					END;
				ELSE
					lastUpdated:= 0;
					IF ((x.initializer # NIL) OR TypeNeedsInitialization(x.type)) THEN
						Initialize(x.type, x.initializer, 0);
					END;
					size := ToMemoryUnits(system,system.SizeOf(x.type)) - lastUpdated;
					IF size > 0 THEN
						irv.Emit(Reserve(x.position,size));
					END;
					IF ~x.fixed THEN
						align := CommonAlignment(x.alignment, ToMemoryUnits(system, system.AlignmentOf(system.variableAlignment, x.type)));
					ELSE
						align := x.alignment;
					END;
					irv.SetPositionOrAlignment(x.fixed, align);
					meta.CheckTypeDeclaration(x.type);
				END;
			ELSIF currentScope IS SyntaxTree.RecordScope THEN
			ELSIF currentScope IS SyntaxTree.ProcedureScope THEN
			END;
			(* do not call Type(x.type) here as this must already performed in the type declaration section ! *)
		END Variable;

		PROCEDURE Parameter(x: SyntaxTree.Parameter);
		VAR name: Basic.SegmentedName; irv: IntermediateCode.Section; align, i: LONGINT;
			size: LONGINT; lastUpdated: LONGINT;
		BEGIN
			ASSERT(currentScope IS SyntaxTree.CellScope);
			Global.GetSymbolSegmentedName(x,name);
			irv := implementationEmitter.NewSection(module.allSections, Sections.VarSection, name,x,dump);
			irv.SetExported(IsExported(x));
			irv.SetOffset(ToMemoryUnits(system,x.offsetInBits));
			IF (currentScope IS SyntaxTree.CellScope) & IsSemiDynamicArray(x.type) THEN
				irv.Emit(Reserve(x.position, ToMemoryUnits(system, system.addressSize)));
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@len"));
				irv := implementationEmitter.NewSection(module.allSections, Sections.VarSection, name,NIL,dump);
				FOR i := 0 TO DynamicDim(x.type)-1 DO
					irv.Emit(Reserve(x.position, ToMemoryUnits(system, system.addressSize)));
				END;
			ELSE
				lastUpdated:= 0;
				size := ToMemoryUnits(system,system.SizeOf(x.type)) - lastUpdated;
				IF size > 0 THEN
					irv.Emit(Reserve(x.position,size));
				END;
				IF ~x.fixed THEN
					align := CommonAlignment(x.alignment, ToMemoryUnits(system, system.AlignmentOf(system.variableAlignment, x.type)));
				ELSE
					align := x.alignment;
				END;
				irv.SetPositionOrAlignment(x.fixed, align);
				meta.CheckTypeDeclaration(x.type);
			END;
		END Parameter;

		PROCEDURE TypeDeclaration(x: SyntaxTree.TypeDeclaration);
		BEGIN
			Type(x.declaredType); (* => code in objects *)
			IF ~(x.declaredType IS SyntaxTree.QualifiedType) & (x.declaredType.resolved IS SyntaxTree.PointerType) THEN
				Type(x.declaredType.resolved(SyntaxTree.PointerType).pointerBase);
			END;
		END TypeDeclaration;

		PROCEDURE Constant(x: SyntaxTree.Constant);
		BEGIN
			(* not required *)
			(*
			IF (SyntaxTree.Public * x.access # {}) THEN
				implementationEmitter.VisitConstant(x);
			END;
			*)
		END Constant;

		PROCEDURE Scope(x: SyntaxTree.Scope);
		VAR procedure: SyntaxTree.Procedure;
			constant: SyntaxTree.Constant;
			variable: SyntaxTree.Variable;
			prevScope: SyntaxTree.Scope;  typeDeclaration: SyntaxTree.TypeDeclaration;
			cell: SyntaxTree.CellType;
			parameter: SyntaxTree.Parameter;
			property: SyntaxTree.Property;
		BEGIN
			prevScope := currentScope;
			currentScope := x;
			(* constants treated in implementation visitor  *)

			WITH x: SyntaxTree.CellScope DO
				cell := x.ownerCell;
				parameter := cell.firstParameter;
				WHILE parameter # NIL DO
					Parameter(parameter);
					parameter := parameter.nextParameter;
				END;
				property := cell.firstProperty;
				WHILE property # NIL DO
					Variable(property);
					property := property.nextProperty;
				END;
			ELSE
			END;

			typeDeclaration := x.firstTypeDeclaration;
			WHILE typeDeclaration # NIL DO
				TypeDeclaration(typeDeclaration);
				typeDeclaration := typeDeclaration.nextTypeDeclaration;
			END;

			variable := x.firstVariable;
			WHILE variable # NIL DO
				Variable(variable);
				variable := variable.nextVariable;
			END;

			procedure := x.firstProcedure;
			WHILE procedure # NIL DO
				Procedure(procedure);
				procedure := procedure.nextProcedure;
			END;

			constant := x.firstConstant;
			WHILE constant # NIL DO
				Constant(constant);
				constant := constant.nextConstant;
			END;
			currentScope := prevScope;
		END Scope;

		PROCEDURE Parameters(first: SyntaxTree.Parameter);
		VAR parameter: SyntaxTree.Parameter;
		BEGIN
			parameter := first;
			WHILE parameter # NIL DO
				Parameter(parameter);
				parameter := parameter.nextParameter;
			END;
		END Parameters;

		PROCEDURE Procedure(x: SyntaxTree.Procedure);
		VAR scope: SyntaxTree.ProcedureScope;
			prevScope: SyntaxTree.Scope;
			inline, finalizer: BOOLEAN;
			procedureType: SyntaxTree.ProcedureType;
			pc: LONGINT;
			memorySize: Basic.Integer; stackSize: LONGINT;
			name,baseObject: Basic.SegmentedName; ir: IntermediateCode.Section;
			null,size,src,dest,fp,res: IntermediateCode.Operand;
			callingConvention: LONGINT;
			cellType: SyntaxTree.CellType;
			register: WORD;
			registerClass: IntermediateCode.RegisterClass;
			type: IntermediateCode.Type;
			formalParameter: SyntaxTree.Parameter;
			recordType: SyntaxTree.RecordType;
			isModuleBody: BOOLEAN;
			parametersSize: LONGINT;
			position: LONGINT;
			variable: SyntaxTree.Variable;
			nonParameterRegisters: WORD;

			PROCEDURE Signature;
			VAR parameter: SyntaxTree.Parameter; procedureType: SyntaxTree.ProcedureType; returnType : SyntaxTree.Type;
			BEGIN
				procedureType := x.type(SyntaxTree.ProcedureType);
				returnType := procedureType.returnType;
				IF returnType # NIL THEN
					meta.CheckTypeDeclaration(returnType)
				END;
				parameter := procedureType.firstParameter;
				WHILE parameter # NIL DO
					meta.CheckTypeDeclaration(parameter.type); (* we have to re-export a type, i.e. it has to be present in the list of symbols *)
					parameter := parameter.nextParameter;
				END;
			END Signature;

			PROCEDURE CheckIntegerValue(x: SyntaxTree.Expression; VAR value: Basic.Integer): BOOLEAN;
			VAR result: BOOLEAN;
			BEGIN
				result := FALSE;
				IF x = SyntaxTree.invalidExpression THEN
				ELSIF (x.resolved # NIL) & (x.resolved IS SyntaxTree.IntegerValue) THEN
					result := TRUE;
					value := x.resolved(SyntaxTree.IntegerValue).value;
				ELSE
					Error(x.position,"expression is not an integer constant");
				END;
				RETURN result;
			END CheckIntegerValue;

			PROCEDURE HasValue(modifiers: SyntaxTree.Modifier; CONST name: ARRAY OF CHAR; VAR value: Basic.Integer): BOOLEAN;
			VAR this: SyntaxTree.Modifier; id: SyntaxTree.Identifier;
			BEGIN
				this := modifiers; id := SyntaxTree.NewIdentifier(name);
				WHILE (this # NIL) & (this.identifier # id) DO
					this := this.nextModifier;
				END;
				IF this # NIL THEN
					IF this.expression = NIL THEN
						Error(this.position,"expected expression value");
					ELSIF CheckIntegerValue(this.expression,value) THEN
					END;
					RETURN TRUE
				ELSE RETURN FALSE
				END;
			END HasValue;

			CONST DefaultDataMemorySize=512;
		BEGIN
			IF x.externalName # NIL THEN RETURN END;
			(*
			IF Trace & (dump # NIL) THEN dump.String("DeclarationEmitter:Procedure"); dump.Ln END;
			*)
			(* code section for this procedure *)
			position := x.position.start;
			scope := x.procedureScope;
			prevScope := currentScope;
			currentScope := scope;
			procedureType := x.type(SyntaxTree.ProcedureType);
			isModuleBody := x = module.module.moduleScope.bodyProcedure;
			implementationEmitter.temporaries.Clear;
			implementationEmitter.usedRegisters := NIL;
			implementationEmitter.registerUsageCount.Init;

			implementationEmitter.GetCodeSectionNameForSymbol(x, name);
			IF (scope.body # NIL) & (x.isInline)  THEN
				inline := TRUE;
				ir := implementationEmitter.NewSection(module.allSections, Sections.InlineCodeSection, name,x,dump);
				ir.SetExported(IsExported(x));
			ELSIF (x.scope # NIL) & (x.scope IS SyntaxTree.CellScope) & (x.scope(SyntaxTree.CellScope).ownerCell.isCellNet)
				OR (x.scope # NIL) & (x.scope IS SyntaxTree.ModuleScope) & (x.scope(SyntaxTree.ModuleScope).ownerModule.isCellNet) THEN
				IF backend.cellsAreObjects THEN
					ir := implementationEmitter.NewSection(module.allSections, Sections.CodeSection, name, x, dump);
					ir.SetExported(IsExported(x));
				ELSE
					RETURN; (* cellnet cannot be compiled for final static hardware *)
				END;
			ELSIF x = module.module.moduleScope.bodyProcedure THEN
				inline := FALSE;
				AddBodyCallStub(x);
				ir := implementationEmitter.NewSection(module.allSections, Sections.BodyCodeSection, name,x,dump);
				ir.SetExported(IsExported(x));
			ELSIF (scope.outerScope IS SyntaxTree.CellScope) & (x = scope.outerScope(SyntaxTree.CellScope).bodyProcedure) THEN
				inline := FALSE;
				cellType := scope.outerScope(SyntaxTree.CellScope).ownerCell;
				IF ~HasValue(cellType.modifiers,Global.StringDataMemorySize,memorySize) THEN memorySize := DefaultDataMemorySize END;
				AddBodyCallStub(x);
				AddStackAllocation(x,memorySize);
				ir := implementationEmitter.NewSection(module.allSections,Sections.BodyCodeSection, name,x,dump);
				ir.SetExported(IsExported(x));
			ELSIF (scope.outerScope IS SyntaxTree.CellScope) & (x.isConstructor) THEN
				inline := FALSE;
				Parameters(procedureType.firstParameter);
				ir := implementationEmitter.NewSection(module.allSections, Sections.CodeSection, name,x,dump);
				ir.SetExported(IsExported(x));
			ELSE
				inline := FALSE;
				IF x.isEntry OR x.isExit THEN
					IF x.isEntry THEN
						ir := implementationEmitter.NewSection(module.allSections, Sections.EntryCodeSection, name,x,dump);
					ELSE
						ir := implementationEmitter.NewSection(module.allSections, Sections.ExitCodeSection, name,x,dump);
					END;
					ir.SetExported(TRUE);
				ELSE
					ir := implementationEmitter.NewSection(module.allSections, Sections.CodeSection, name,x,dump);
					ir.SetExported(IsExported(x) OR SemanticChecker.InMethodTable(x));
				END;
			END;

			callingConvention := procedureType.callingConvention;
			IF callingConvention = SyntaxTree.WinAPICallingConvention THEN
				parametersSize := ProcedureParametersSize(backend.system,x);
			ELSE
				parametersSize := 0;
			END;

			IF scope.body # NIL THEN

				IF implementationEmitter.emitLabels THEN ir.Emit(LabelInstruction(scope.body.position)) END;

				IF ~inline THEN
					IF scope.lastVariable = NIL THEN
						stackSize := 0
					ELSE
						stackSize := scope.lastVariable.offsetInBits;
					END;
					IF scope.minVariableOffset < stackSize THEN
						stackSize := scope.minVariableOffset;
					END;
					IF stackSize <0 THEN stackSize := -stackSize END;
					Basic.Align(stackSize,system.AlignmentOf(system.parameterAlignment,system.byteType));  (* round up to parameter alignment *)
					(*
					ir.Emit(Nop(position)); (* placeholder for stack frame check *)
					ir.Emit(Nop(position)); (* placeholder for stack frame check (2) *)
					*)
					(*
					ir.Emit(Nop(position)); (* placeholder for fill *)
					*)

					IF (callingConvention # SyntaxTree.OberonCallingConvention) & (~(callingConvention IN SysvABI) OR (system.addressSize # 64)) THEN
						backend.ResetParameterRegisters();
						(* assumption: registers are passed left to right and left parameters are in registers *)
						formalParameter := procedureType.firstParameter;
						WHILE (formalParameter # NIL)  DO
							IF PassInRegister(formalParameter, callingConvention) THEN
								IF formalParameter.type.IsRecordType() THEN
									ASSERT (formalParameter.kind IN {SyntaxTree.VarParameter, SyntaxTree.ConstParameter});
									type := addressType;
								ELSE
									type := GetType(system, formalParameter.type);
								END;
								IF backend.GetParameterRegister(callingConvention, type, register) THEN
									IntermediateCode.InitParameterRegisterClass(registerClass, register);
									src := IntermediateCode.Register(type, registerClass, implementationEmitter.AcquireRegister(type, registerClass));
									IntermediateCode.InitMemory(dest,type,implementationEmitter.sp,ToMemoryUnits(system,formalParameter.offsetInBits - system.addressSize));
									ir.Emit(Mov(Basic.invalidPosition,dest, src));
									implementationEmitter.ReleaseIntermediateOperand(src);
								END;
							END;
							formalParameter := formalParameter.nextParameter;
						END;
					END;

					IF ~procedureType.noPAF THEN (* no procedure activation frame ! *)
						implementationEmitter.EmitEnter(ir,x.position,x,callingConvention,ToMemoryUnits(system,stackSize));
					END;
					pc := ir.pc-1;

					IF (callingConvention IN SysvABI) & (system.addressSize = 64) THEN
						backend.ResetParameterRegisters();
						nonParameterRegisters := 0;
						(* assumption: registers are passed left to right and left parameters are in registers *)
						formalParameter := procedureType.firstParameter;
						WHILE (formalParameter # NIL) DO
							IF PassInRegister(formalParameter, callingConvention) THEN
								IF formalParameter.type.IsRecordType() THEN
									ASSERT (formalParameter.kind IN {SyntaxTree.VarParameter, SyntaxTree.ConstParameter});
									type := addressType;
								ELSE
									type := GetType(system, formalParameter.type);
								END;
								IF backend.GetParameterRegister(callingConvention, type, register) THEN
									IntermediateCode.InitParameterRegisterClass(registerClass, register);
									src := IntermediateCode.Register(type, registerClass, implementationEmitter.AcquireRegister(type, registerClass));
									implementationEmitter.currentScope := currentScope;
									variable := implementationEmitter.GetTemporaryVariable(formalParameter.type,FALSE,FALSE);
									formalParameter.SetOffset(variable.offsetInBits);
									IntermediateCode.InitMemory(dest,type,implementationEmitter.fp,ToMemoryUnits(system,formalParameter.offsetInBits));
									ir.Emit(Mov(Basic.invalidPosition,dest, src));
									implementationEmitter.ReleaseIntermediateOperand(src);
								ELSE
									INC(nonParameterRegisters);
									formalParameter.SetOffset(nonParameterRegisters * addressType.sizeInBits);
								END;
							END;
							formalParameter := formalParameter.nextParameter;
						END;
					END;

				END;

				implementationEmitter.tagsAvailable := callingConvention = SyntaxTree.OberonCallingConvention;

				implementationEmitter.Body(scope.body,currentScope,ir,isModuleBody);

				IF ~inline & ~(procedureType.noPAF) & ~x.isEntry & ~x.isExit THEN
					IF scope.lastVariable # NIL THEN
						stackSize := scope.lastVariable.offsetInBits;
					END;
					IF scope.minVariableOffset < stackSize THEN
						stackSize := scope.minVariableOffset;
					END;

					IF stackSize <0 THEN stackSize := -stackSize END;
					Basic.Align(stackSize,system.AlignmentOf(system.parameterAlignment,system.byteType));  (* round up to parameter alignment *)
				END;

				IF ~inline  & ~(procedureType.noPAF) & ~x.isEntry & ~x.isExit THEN
					(*
					IF ToMemoryUnits(system,stackSize) > 4*1024-256 THEN (* stack frame potentially larger than page size *) (*! get page size from backend *)
						(*! unnecessary with new implementation of ENTER -- should potentially be called by backend
						IF implementationEmitter.GetRuntimeProcedure(implementationEmitter.builtinsModuleName,"EnsureAllocatedStack",procedure,TRUE) THEN
							size := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,stackSize+256));
							ir.EmitAt(pc,Push(size));
							implementationEmitter.StaticCallOperand(result,procedure);
							ir.EmitAt(pc+1,Call(result.op,ProcedureParametersSize(system,procedure)));
						END;
						*)
					END;
					*)

					ir.EmitAt(pc(*+2*),implementationEmitter.Enter(x.position,callingConvention,ToMemoryUnits(system,stackSize))); (*!!*)

					IF stackSize > 0 THEN
						IF (stackSize MOD system.addressSize = 0) THEN
							null := IntermediateCode.Immediate(addressType,0);
							fp := IntermediateCode.Register(addressType,IntermediateCode.GeneralPurposeRegister,IntermediateCode.FP);
							IntermediateCode.AddOffset(fp,ToMemoryUnits(system,-system.addressSize));
							size := IntermediateCode.Immediate(addressType,stackSize DIV system.addressSize);
						ELSE
							null := IntermediateCode.Immediate(int8,0);
							fp := IntermediateCode.Register(addressType,IntermediateCode.GeneralPurposeRegister,IntermediateCode.FP);
							IntermediateCode.AddOffset(fp,ToMemoryUnits(system,-null.type.sizeInBits));
							size := IntermediateCode.Immediate(addressType,stackSize DIV null.type.sizeInBits);
						END;
						(*! should potentially be called by backend -- enter might initialize
						ir.EmitAt(pc+3,Fill(fp,null,size,TRUE));
						*)
					END;

					IF callingConvention = SyntaxTree.WinAPICallingConvention THEN
						parametersSize := ProcedureParametersSize(backend.system,x);
					ELSE
						parametersSize := 0;
					END;

					IF (procedureType.returnType = NIL) OR (scope.body.code # NIL)  THEN
						finalizer := FALSE;
						IF backend.cooperative & x.isFinalizer THEN
							recordType := x.scope(SyntaxTree.RecordScope).ownerRecord;
							Basic.ToSegmentedName("BaseTypes.Object", baseObject);
							GetRecordTypeName(recordType,name);
							finalizer := (name # baseObject) & (recordType.baseType = NIL);
						END;
						implementationEmitter.SetLabel(implementationEmitter.exitLabel);
						IF backend.cooperative THEN
							IF HasPointers (scope) THEN  implementationEmitter.ResetVariables(scope); END;
							IF implementationEmitter.profile  & ~isModuleBody THEN
								implementationEmitter.ProfilerEnterExit(implementationEmitter.numberProcedures-1, FALSE)
							END;
						END;
						implementationEmitter.EmitLeave(ir, x.position,x,callingConvention);
						IF finalizer THEN
							IF backend.hasLinkRegister THEN
								ir.Emit(Pop(Basic.invalidPosition, implementationEmitter.lr));
							END;
							Basic.ToSegmentedName("BaseTypes.Object.Finalize", name);
							IntermediateCode.InitAddress(dest, addressType, name , 0, 0);
							ir.Emit(Br(x.position,dest));
						ELSE
							ir.Emit(Exit(x.position,procedureType.pcOffset,callingConvention, parametersSize));
						END;
					ELSE
						IF ~scope.body.isUnchecked & ~backend.noRuntimeChecks THEN
							implementationEmitter.EmitTrap(x.position,ReturnTrap);
						END;
						implementationEmitter.SetLabel(implementationEmitter.exitLabel);
						IF backend.cooperative THEN
							IF HasPointers (scope) THEN
								IF ~SemanticChecker.ReturnedAsParameter(system,procedureType.returnType) THEN
									res := implementationEmitter.NewRegisterOperand(IntermediateCode.GetType(system, procedureType.returnType));
									ir.Emit(Result(x.position, res));
									ir.Emit(Push(x.position, res));
									implementationEmitter.ResetVariables(scope);
									IF implementationEmitter.profile  & ~isModuleBody THEN implementationEmitter.ProfilerEnterExit(implementationEmitter.numberProcedures-1, FALSE) END;
									ir.Emit(Pop(x.position, res));
									ir.Emit(Return(x.position, res));
								ELSE
									implementationEmitter.ResetVariables(scope);
									IF implementationEmitter.profile & ~isModuleBody THEN implementationEmitter.ProfilerEnterExit(implementationEmitter.numberProcedures-1, FALSE) END;
								END;
							ELSIF  implementationEmitter.profile & ~isModuleBody THEN
								IF ~SemanticChecker.ReturnedAsParameter(system,procedureType.returnType) THEN
									res := implementationEmitter.NewRegisterOperand(IntermediateCode.GetType(system, procedureType.returnType));
									ir.Emit(Result(x.position, res));
									ir.Emit(Push(x.position, res));
									implementationEmitter.ProfilerEnterExit(implementationEmitter.numberProcedures-1, FALSE);
									ir.Emit(Pop(x.position, res));
									ir.Emit(Return(x.position, res));
								ELSE
									implementationEmitter.ProfilerEnterExit(implementationEmitter.numberProcedures-1, FALSE);
								END;
							END;

							implementationEmitter.EmitLeave(ir,x.position,x,callingConvention);
							ir.Emit(Exit(x.position,procedureType.pcOffset,callingConvention, parametersSize));
						ELSE
							ir.Emit(Nop(x.position));
							IF scope.body.isUnchecked OR backend.noRuntimeChecks THEN (* return from procedure in any case *)
								implementationEmitter.EmitLeave(ir,x.position,x,callingConvention);
								ir.Emit(Exit(x.position,procedureType.pcOffset,callingConvention, parametersSize));
							END;
						END;
					END
				ELSIF ~inline THEN
					ir.Emit(Nop(x.position)); (* jump label *)
				END;
			ELSE (* force body for procedures *)
				implementationEmitter.EmitEnter(ir, x.position,x,callingConvention,0);
				implementationEmitter.Body(scope.body,currentScope,ir,x = module.module.moduleScope.bodyProcedure);
				(*IF implementationEmitter.usedRegisters # NIL THEN D.TraceBack END;*)
				implementationEmitter.EmitLeave(ir,x.position,x,callingConvention);
				ir.Emit(Exit(x.position,procedureType.pcOffset,callingConvention, parametersSize));
			END;
			Scope(scope);
			Signature;
			IF (x IS SyntaxTree.Operator) & x(SyntaxTree.Operator).isDynamic THEN implementationEmitter.RegisterDynamicOperator(x(SyntaxTree.Operator)) END;

			currentScope := prevScope;
		END Procedure;

		PROCEDURE AddBodyCallStub(bodyProcedure: SyntaxTree.Procedure); (* code that is only necessary for static linkers *)
		VAR procedure: SyntaxTree.Procedure; procedureScope: SyntaxTree.ProcedureScope; name: Basic.SegmentedName;
			ir: IntermediateCode.Section; op: IntermediateCode.Operand;
		BEGIN
			ASSERT (bodyProcedure # NIL);
			procedureScope := SyntaxTree.NewProcedureScope(bodyProcedure.scope);
			procedure := SyntaxTree.NewProcedure(Basic.invalidPosition,SyntaxTree.NewIdentifier("@BodyStub"), procedureScope);
			procedure.SetScope(bodyProcedure.scope);
			procedure.SetType(SyntaxTree.NewProcedureType(Basic.invalidPosition,bodyProcedure.scope));
			procedure.SetAccess(SyntaxTree.Hidden);
			Global.GetSymbolSegmentedName (procedure,name);
			ir := implementationEmitter.NewSection(module.allSections, Sections.InitCodeSection, name,procedure,dump);
			ir.SetExported(TRUE);
			Global.GetSymbolSegmentedName (bodyProcedure,name);
			IF ~meta.simple THEN
				implementationEmitter.currentScope := module.module.moduleScope;
				implementationEmitter.section := ir;
				implementationEmitter.PushSelfPointer();
				implementationEmitter.CallThis(bodyProcedure.position,"Modules","Register",1);
			ELSIF backend.preregisterStatic THEN
				implementationEmitter.currentScope := module.module.moduleScope;
				implementationEmitter.section := ir;
				implementationEmitter.PushSelfPointer();
				implementationEmitter.CallThis(bodyProcedure.position,"Modules","Preregister",1);
			ELSE
				IntermediateCode.InitAddress(op, addressType, name, implementationEmitter.GetFingerprint(bodyProcedure), 0);
				ir.Emit(Call(bodyProcedure.position,op, 0));
			END;
		END AddBodyCallStub;

		PROCEDURE AddStackAllocation(symbol: SyntaxTree.Symbol; initStack: Basic.Integer); (* code that is only necessary for static linkers *)
		VAR name: Basic.SegmentedName;
			ir: IntermediateCode.Section; op: IntermediateCode.Operand;
		BEGIN
			Global.GetSymbolSegmentedName (symbol,name);
			Basic.RemoveSuffix(name);
			Basic.SuffixSegmentedName(name, Basic.MakeString("@StackAllocation"));
			ir := implementationEmitter.NewSection(module.allSections,Sections.EntryCodeSection,name,NIL,dump);
			ir.SetExported(TRUE);
			IntermediateCode.InitImmediate(op,addressType,initStack);
			ir.Emit(Mov(Basic.invalidPosition,implementationEmitter.sp,op));
		END AddStackAllocation;

		(** entry function to visit a complete module *)
		PROCEDURE Module(x: SyntaxTree.Module; module: Sections.Module);
		VAR
			name: Basic.SegmentedName; idstr: SyntaxTree.IdentifierString;
			hasDynamicOperatorDeclarations: BOOLEAN;
			operator: SyntaxTree.Operator;
			import: SyntaxTree.Import;

			PROCEDURE TypeNeedsInitialization(type: SyntaxTree.Type): BOOLEAN;
			BEGIN
				type := type.resolved;
				IF type IS SyntaxTree.RecordType THEN
					IF ScopeNeedsInitialization(type(SyntaxTree.RecordType).recordScope) THEN RETURN TRUE END;
				ELSIF (type IS SyntaxTree.ArrayType) THEN
					IF type(SyntaxTree.ArrayType).form = SyntaxTree.Static THEN
						IF TypeNeedsInitialization(type(SyntaxTree.ArrayType).arrayBase) THEN RETURN TRUE END;
					END;
				ELSIF type IS SyntaxTree.MathArrayType THEN
					WITH type: SyntaxTree.MathArrayType DO
						IF type.form = SyntaxTree.Open THEN
							RETURN TRUE
						ELSIF type.form = SyntaxTree.Static THEN
							IF TypeNeedsInitialization(type.arrayBase) THEN RETURN TRUE END;
						END;
					END;
				END;
				RETURN FALSE
			END TypeNeedsInitialization;

			PROCEDURE ScopeNeedsInitialization(scope: SyntaxTree.Scope): BOOLEAN;
			VAR variable: SyntaxTree.Variable;
			BEGIN
				variable := scope.firstVariable;
				WHILE variable # NIL DO
					IF TypeNeedsInitialization(variable.type) THEN RETURN TRUE END;
					IF variable.initializer # NIL THEN RETURN TRUE END;
					variable := variable.nextVariable;
				END;
				RETURN FALSE
			END ScopeNeedsInitialization;

		BEGIN
			ASSERT(x # NIL); ASSERT(module # NIL);
			SELF.module := module;

			(* add import names to the generated Sections.Module *)
			import := x.moduleScope.firstImport;
			WHILE import # NIL DO
				import.module.GetName(idstr);
				module.imports.AddName(idstr);
				import := import.nextImport
			END;

			implementationEmitter.module := module;
			implementationEmitter.moduleScope := x.moduleScope;
			implementationEmitter.moduleSelf := moduleSelf;
			implementationEmitter.canBeLoaded := TRUE;
			meta.SetModule(module);

			IF (forceModuleBody OR ~meta.simple  OR ScopeNeedsInitialization(x.moduleScope)) THEN
				EnsureBodyProcedure(x.moduleScope); (* currently needed in Oberon, remove ? *)
			END;

			IF backend.profile THEN
				EnsureBodyProcedure(x.moduleScope);
				Global.GetModuleSegmentedName(module.module,name); Basic.SuffixSegmentedName(name, Basic.MakeString("@ModuleId"));
				implementationEmitter.profileId := implementationEmitter.NewSection(module.allSections, Sections.VarSection, name,NIL,dump);
				implementationEmitter.profileId.Emit(Reserve(Basic.invalidPosition,ToMemoryUnits(system,system.SizeOf(system.longintType))));
				Global.GetModuleSegmentedName(module.module,name); Basic.SuffixSegmentedName(name, Basic.MakeString("@InitProfiler"));
				implementationEmitter.profileInit := implementationEmitter.NewSection(module.allSections, Sections.CodeSection, name,NIL,dump);
				implementationEmitter.EmitEnter(implementationEmitter.profileInit,Basic.invalidPosition,NIL,0,0);

				Global.GetModuleName(module.module,idstr);
				implementationEmitter.ProfilerAddModule(idstr);
				implementationEmitter.numberProcedures := 0;
			END;
			implementationEmitter.profile := backend.profile;

			(* check if there is at least one dynamic operator locally defined *)
			hasDynamicOperatorDeclarations := FALSE;
			operator := x.moduleScope.firstOperator;
			WHILE operator # NIL DO
				IF operator.isDynamic THEN hasDynamicOperatorDeclarations := TRUE END;
				operator := operator.nextOperator
			END;

			(* add operator initialization code section *)
			IF hasDynamicOperatorDeclarations THEN
				EnsureBodyProcedure(x.moduleScope);
				Global.GetModuleSegmentedName(module.module,name); Basic.SuffixSegmentedName(name, Basic.MakeString("@OperatorInitialization"));
				implementationEmitter.operatorInitializationCodeSection := implementationEmitter.NewSection(module.allSections, Sections.CodeSection,name, NIL, dump);
				implementationEmitter.EmitEnter(implementationEmitter.operatorInitializationCodeSection,Basic.invalidPosition,NIL,0,0);
			END;

			Scope(x.moduleScope);

			IF hasDynamicOperatorDeclarations THEN
				implementationEmitter.EmitLeave(implementationEmitter.operatorInitializationCodeSection,Basic.invalidPosition,NIL,0);
				implementationEmitter.operatorInitializationCodeSection.Emit(Exit(Basic.invalidPosition,0,0,0));
			END;

			IF backend.profile THEN
				implementationEmitter.ProfilerPatchInit;
			END;

		END Module;

	END DeclarationEmitter;

	UsedArray=POINTER TO ARRAY OF RECORD count: LONGINT; map: LONGINT; type: IntermediateCode.Type; class: IntermediateCode.RegisterClass END;

	RegisterUsageCount=OBJECT
	VAR used: UsedArray; count: LONGINT;

		PROCEDURE &Init;
		VAR i: LONGINT;
		BEGIN
			count := 0;
			IF used = NIL THEN NEW(used,64); END;
			FOR i := 0 TO LEN(used)-1 DO used[i].count := 0; used[i].map := i END;
		END Init;

		PROCEDURE Grow;
		VAR new: UsedArray; size,i: LONGINT;
		BEGIN
			size := LEN(used)*2;
			NEW(new,size);
			FOR i := 0 TO LEN(used)-1 DO
				new[i].count := used[i].count;
				new[i].type := used[i].type;
				new[i].map := used[i].map
			END;
			FOR i := LEN(used) TO LEN(new)-1 DO new[i].count := 0 END;
			used := new
		END Grow;

		PROCEDURE Next(type: IntermediateCode.Type; class: IntermediateCode.RegisterClass): LONGINT;
		BEGIN
			INC(count);
			IF count = LEN(used) THEN Grow END;
			used[count].type := type;
			used[count].class := class;
			used[count].map := count;
			RETURN count;
		END Next;

		PROCEDURE IncUse(register: LONGINT);
		BEGIN
			INC(used[register].count);
			(*
			IF (register = 1) & (count > 30)  THEN
				D.TraceBack;
			END;
			*)
		END IncUse;

		PROCEDURE DecUse(register: LONGINT);
		BEGIN
			DEC(used[register].count);
		END DecUse;

		PROCEDURE Map(register: LONGINT): LONGINT;
		VAR map : LONGINT;
		BEGIN
			IF register > 0 THEN
				map := used[register].map;
				WHILE register # map DO register := map; map := used[register].map END;
			END;
			RETURN register
		END Map;

		PROCEDURE Use(register: LONGINT): LONGINT;
		BEGIN
			IF register< LEN(used) THEN
				RETURN used[register].count
			ELSE
				RETURN 0
			END
		END Use;

	END RegisterUsageCount;

	RegisterEntry = POINTER TO RECORD
		prev,next: RegisterEntry;
		register: LONGINT;
		registerClass: IntermediateCode.RegisterClass;
		type: IntermediateCode.Type;
	END;

	VariableUse= ARRAY 32 OF SET; (* upper bound of 1024 temporary variables in a procedure .. should be enough for all times *)

	Variables = OBJECT (Basic.List)
	VAR
		inUse: VariableUse;
		registerIndex: LONGINT;
		nameIndex: LONGINT;

		PROCEDURE & Init;
		VAR i: LONGINT;
		BEGIN
			InitList(16);
			FOR i := 0 TO LEN(inUse)-1 DO inUse[i] := {} END;
			registerIndex := 1024;
			nameIndex := 0;
		END Init;

		PROCEDURE Clear*;
		VAR i: LONGINT;
		BEGIN
			Clear^;
			FOR i := 0 TO LEN(inUse)-1 DO inUse[i] := {} END;
			registerIndex := 1024;
			nameIndex := 0;
		END Clear;

		PROCEDURE GetUID(): SyntaxTree.Identifier;
		VAR string: SyntaxTree.IdentifierString ;
		BEGIN
				COPY("@hiddenIRVar",string);
				Basic.AppendNumber(string, nameIndex); INC(nameIndex);
				RETURN SyntaxTree.NewIdentifier(string);
		END GetUID;

		PROCEDURE GetUsage(VAR use: VariableUse);
		BEGIN
			use := inUse;
		END GetUsage;

		PROCEDURE SetUsage(CONST use: VariableUse);
		BEGIN
			inUse := use;
		END SetUsage;

		PROCEDURE GetVariable(i: LONGINT): SyntaxTree.Variable;
		VAR any: ANY;
		BEGIN
			any := Get(i);
			IF any = NIL THEN RETURN NIL ELSE RETURN any(SyntaxTree.Variable) END;
		END GetVariable;

		PROCEDURE SetVariable(pos: LONGINT; v: SyntaxTree.Variable);
		BEGIN
			Set(pos, v);
		END SetVariable;

		PROCEDURE Occupy(pos: LONGINT);
		BEGIN
			INCL(inUse[pos DIV 32], pos MOD 32);
		END Occupy;

		PROCEDURE Occupied(pos: LONGINT): BOOLEAN;
		BEGIN
			RETURN (pos MOD 32) IN inUse[pos DIV 32];
		END Occupied;

		PROCEDURE AddVariable(v: SyntaxTree.Variable);
		BEGIN
			Occupy(Length());
			Add(v);
		END AddVariable;

		PROCEDURE CompatibleType(t1, t2: SyntaxTree.Type): BOOLEAN;
		BEGIN
			t1 := t1.resolved;
			t2 := t2.resolved;
			(*RETURN t1.SameType(t2); *)
			RETURN
				(t1.SameType(t2))
				OR
				SemanticChecker.IsPointerType(t1) & SemanticChecker.IsPointerType(t2)
				OR
				~t1.NeedsTrace() & ~t2.NeedsTrace() & (t1.sizeInBits > 0) & (t1.sizeInBits = t2.sizeInBits)
				OR
				(t1 IS SyntaxTree.MathArrayType) & (t2 IS SyntaxTree.MathArrayType) &
				(t1(SyntaxTree.MathArrayType).form = t2(SyntaxTree.MathArrayType).form) &
				(	(t1(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor)
					OR
					(t1(SyntaxTree.MathArrayType).form = SyntaxTree.Open) &
					(DynamicDim(t1) = DynamicDim(t2))
				);
		END CompatibleType;

		PROCEDURE GetFreeVariable(type: SyntaxTree.Type; untraced: BOOLEAN; VAR pos: LONGINT): SyntaxTree.Variable;
		VAR var : SyntaxTree.Variable; i: LONGINT;
		BEGIN
			pos := Length();
			FOR i := 0 TO pos-1 DO
				IF ~(Occupied(i)) THEN
					var := GetVariable(i);
					IF (~var.preferRegister) & CompatibleType(type, var.type) & (var.untraced = untraced) (*& ~(var.type.NeedsTrace())*) THEN
						pos := i;
						Occupy(i);
						RETURN var;
					END;
				END;
			END;
			RETURN NIL
		END GetFreeVariable;

	END Variables;

	ImplementationEmitter =OBJECT
	VAR
		system: Global.System;
		section: IntermediateCode.Section;
		module: Sections.Module;
		moduleScope : SyntaxTree.ModuleScope; (* shortcut for module.module.moduleScope *)
		awaitProcCounter, labelId, constId, caseId: LONGINT;

		hiddenPointerType: SyntaxTree.RecordType; (* used as hidden pointer, for example for ARRAY OF ANY *)
		delegatePointerType: SyntaxTree.RecordType; (* used for delegates, for example in ARRAY OF PROCEDURE{DELEGATE} *)

		checker: SemanticChecker.Checker;
		backend: IntermediateBackend;
		meta: MetaDataGenerator;
		position: Position;
		moduleSelf: SyntaxTree.Variable;
		(* variables for hand over of variables /  temporary state *)
		currentScope: SyntaxTree.Scope;
		destination: IntermediateCode.Operand;

		arrayDestinationTag: IntermediateCode.Operand;
		arrayDestinationDimension:LONGINT;

		currentLoop: Label; (* variable to hand over loop exit jump list *)
		exitLabel: Label;
		locked: BOOLEAN;
		(*
		usedRegisters: Registers;
		*)
		registerUsageCount: RegisterUsageCount;
		usedRegisters: RegisterEntry;

		(* useful operands and types *)
		nil,one,fp,sp,ap,lr,true,false: IntermediateCode.Operand;
		bool,addressType,setType, sizeType, lenType, byteType: IntermediateCode.Type;

		commentPrintout: Printout.Printer;
		dump: Streams.Writer;
		tagsAvailable : BOOLEAN;
		supportedInstruction: SupportedInstructionProcedure;
		supportedImmediate: SupportedImmediateProcedure;
		inData: BOOLEAN;  (* to prevent indirect reference to data within data sections, cf. VisitIntegerValue *)
		emitLabels: BOOLEAN;
		builtinsModuleName : SyntaxTree.IdentifierString;
		indexCounter: LONGINT;

		profile: BOOLEAN;
		profileId, profileInit: IntermediateCode.Section;
		profileInitPatchPosition: LONGINT;
		numberProcedures: LONGINT;
		procedureResultDesignator : SyntaxTree.Designator;
		operatorInitializationCodeSection: IntermediateCode.Section;
		fingerprinter: Fingerprinter.Fingerprinter;

		temporaries: Variables;
		canBeLoaded : BOOLEAN;

		currentIsInline: BOOLEAN;
		currentInlineExit: Label;

		moduleBodySection: IntermediateCode.Section;
		NeedDescriptor : BOOLEAN;

		cooperativeSwitches: BOOLEAN;
		lastSwitchPC: LONGINT;

		isUnchecked: BOOLEAN;
		isUntracked: BOOLEAN;

		(* EXPERIMENTAL *)
		availableSymbols: ARRAY 1024 OF
		RECORD
			symbol: SyntaxTree.Symbol;
			inMemory, inRegister: BOOLEAN;
			register: IntermediateCode.Operand;
			memory: IntermediateCode.Operand;
		END;

		PROCEDURE & Init(system: Global.System; checker: SemanticChecker.Checker; supportedInstructionProcedure: SupportedInstructionProcedure; supportedImmediateProcedure: SupportedImmediateProcedure; emitLabels: BOOLEAN; CONST runtime: SyntaxTree.IdentifierString; backend: IntermediateBackend);
		BEGIN
			SELF.system := system;
			SELF.builtinsModuleName := runtime;

			currentScope := NIL;
			hiddenPointerType := NIL;
			delegatePointerType := NIL;

			awaitProcCounter := 0;
			labelId := 0; constId := 0; labelId := 0;
			SELF.checker := checker;
			SELF.backend := backend;
			position := Basic.invalidPosition;
			locked := FALSE;
			addressType := IntermediateCode.GetType(system,system.addressType);
			setType := IntermediateCode.GetType(system,system.setType);
			sizeType := IntermediateCode.GetType(system, system.sizeType);
			lenType := IntermediateCode.GetType(system, system.lenType);
			byteType := IntermediateCode.GetType(system, system.byteType);

			fp := IntermediateCode.Register(addressType,IntermediateCode.GeneralPurposeRegister,IntermediateCode.FP);
			sp := IntermediateCode.Register(addressType,IntermediateCode.GeneralPurposeRegister,IntermediateCode.SP);
			ap := IntermediateCode.Register(addressType,IntermediateCode.GeneralPurposeRegister,IntermediateCode.AP);
			lr := IntermediateCode.Register(addressType,IntermediateCode.GeneralPurposeRegister,IntermediateCode.LR);
			nil := IntermediateCode.Immediate(addressType,0);
			one := IntermediateCode.Immediate(addressType,1);

			IntermediateCode.InitOperand(destination);
			tagsAvailable := TRUE;
			supportedInstruction := supportedInstructionProcedure;
			supportedImmediate := supportedImmediateProcedure;
			inData := FALSE;

			SELF.emitLabels := emitLabels;
			IntermediateCode.InitOperand(arrayDestinationTag);

			bool := IntermediateCode.GetType(system,system.booleanType);
			IntermediateCode.InitImmediate(false,bool,0);
			IntermediateCode.InitImmediate(true,bool,1);

			indexCounter := 0;
			NEW(registerUsageCount);
			usedRegisters := NIL;
			procedureResultDesignator := NIL;
			NEW(fingerprinter);
			NEW(temporaries);
			currentIsInline := FALSE;
			NeedDescriptor := FALSE;
			isUnchecked := backend.noRuntimeChecks;
			isUntracked := FALSE;
		END Init;

		TYPE Context = RECORD
			section: IntermediateCode.Section;
			registerUsageCount: RegisterUsageCount;
			usedRegisters: RegisterEntry;
			temporaries: Variables;
			END;

		PROCEDURE SwitchContext(new: IntermediateCode.Section): Context;
		VAR context: Context;
		BEGIN
			context.section := section;
			context.registerUsageCount := registerUsageCount;
			context.usedRegisters := usedRegisters;
			context.temporaries := temporaries;
			section := new;
			NEW(registerUsageCount);
			NEW(temporaries);
			usedRegisters := NIL;
			RETURN context;
		END SwitchContext;

		PROCEDURE ReturnToContext(context: Context);
		BEGIN
			section := context.section;
			registerUsageCount := context.registerUsageCount;
			usedRegisters := context.usedRegisters;
			temporaries := context.temporaries;
		END ReturnToContext;

		PROCEDURE NewSection(list: Sections.SectionList; type: SHORTINT; CONST name: Basic.SegmentedName; syntaxTreeSymbol: SyntaxTree.Symbol; dump: BOOLEAN): IntermediateCode.Section;
		VAR fp: SyntaxTree.Fingerprint; section: IntermediateCode.Section;
		BEGIN
			IF (syntaxTreeSymbol # NIL) & ~((syntaxTreeSymbol IS SyntaxTree.Procedure) & (syntaxTreeSymbol(SyntaxTree.Procedure).isInline)) THEN
				fp := fingerprinter.SymbolFP(syntaxTreeSymbol)
			END;
			section := IntermediateCode.NewSection(list, type, name, syntaxTreeSymbol, dump);
			section.SetExported(IsExported(syntaxTreeSymbol));
			RETURN section
		END NewSection;

		PROCEDURE AcquireRegister(CONST type: IntermediateCode.Type; class: IntermediateCode.RegisterClass): LONGINT;
		VAR new: LONGINT;
		BEGIN
			new :=  registerUsageCount.Next(type,class);
			UseRegister(new);
			RETURN new
		END AcquireRegister;

		PROCEDURE GetFingerprintString(symbol: SyntaxTree.Symbol; VAR string: ARRAY OF CHAR);
		VAR
			fingerprint: SyntaxTree.Fingerprint;
			fingerprintString: ARRAY SIZEOF(Basic.Fingerprint) * 2 + 1 OF CHAR;
		BEGIN
			fingerprint := fingerprinter.SymbolFP(symbol);
			string := "[";
			Strings.IntToHexStr(fingerprint.public, SIZE OF Basic.Fingerprint * 2, fingerprintString);
			Strings.Append(string, fingerprintString);
			Strings.Append(string, "]");
		END GetFingerprintString;

		(** get the name for the code section that represens a certain symbol
		(essentially the same as Global.GetSymbolName, apart from operators) **)
		PROCEDURE GetCodeSectionNameForSymbol(symbol: SyntaxTree.Symbol; VAR name: Basic.SegmentedName);
		VAR string: ARRAY 32 OF CHAR;
		BEGIN
			Global.GetSymbolSegmentedName(symbol, name);
			(* if the symbol is an operator, then append the fingerprint to the name *)
			IF symbol IS SyntaxTree.Operator THEN
				GetFingerprintString(symbol, string);
				Basic.AppendToSegmentedName(name,string);
			END
		END GetCodeSectionNameForSymbol;

		PROCEDURE TraceEnter(CONST s: ARRAY OF CHAR);
		BEGIN
			IF dump # NIL THEN
				dump.String("enter "); dump.String(s); dump.Ln;
			END;
		END TraceEnter;

		PROCEDURE TraceExit(CONST s: ARRAY OF CHAR);
		BEGIN
			IF dump # NIL THEN
				dump.String("exit "); dump.String(s); dump.Ln;
			END;
		END TraceExit;

		PROCEDURE Emit(instruction: IntermediateCode.Instruction);
		VAR moduleName, procedureName: SyntaxTree.IdentifierString;

			PROCEDURE CheckRegister(VAR op: IntermediateCode.Operand);
			BEGIN
				IF op.register >0 THEN IntermediateCode.SetRegister(op,registerUsageCount.Map(op.register)) END;
			END CheckRegister;

		BEGIN
			CheckRegister(instruction.op1);
			CheckRegister(instruction.op2);
			CheckRegister(instruction.op3);

			IF supportedInstruction(instruction,moduleName,procedureName) THEN section.Emit(instruction)
			ELSE section.Emit(instruction);
				EnsureSymbol(moduleName,procedureName); (* remainder for binary object file *)
			END;
		END Emit;

		PROCEDURE EmitTrap (position: Position; trapNo: LONGINT);
		VAR saved: RegisterEntry;
		BEGIN
			IF backend.cooperative THEN
				ReleaseUsedRegisters(saved);
				Emit(Push(position,IntermediateCode.Immediate(sizeType,trapNo)));
				CallThis(position,"Runtime","Trap",1);
				RestoreRegisterUse(saved);
			ELSE
				Emit(Trap(position,trapNo));
			END;
		END EmitTrap;

		PROCEDURE EmitEnter (section: IntermediateCode.Section; position: Position; procedure: SyntaxTree.Procedure; callconv: LONGINT; varSize: LONGINT);
		VAR name: Basic.SegmentedName;
		VAR op1, op2, reg: IntermediateCode.Operand;
		VAR call, nocall: Label;
		VAR parametersSize: LONGINT;
		VAR prevSection: IntermediateCode.Section;
		VAR prevDump: Streams.Writer;
		VAR body: SyntaxTree.Body;
		VAR procedureType: SyntaxTree.ProcedureType;
		VAR nm: ARRAY 256 OF CHAR;
		BEGIN
			procedure.GetName(nm);
			IF procedure # NIL THEN
				procedureType := procedure.type(SyntaxTree.ProcedureType);
			ELSE procedureType := NIL;
			END;
			ASSERT((procedure = NIL) OR ~procedureType.noPAF);
			prevSection := SELF.section;
			SELF.section := section;
			prevDump := dump;
			dump := section.comments;
			IF callconv # SyntaxTree.InterruptCallingConvention THEN
				IF backend.hasLinkRegister THEN
					Emit(Push(Basic.invalidPosition, lr));
				END;
				Emit(Push(Basic.invalidPosition,fp));

				IF procedure # NIL THEN
					body := procedure.procedureScope.body;
				ELSE
					body := NIL;
				END;

				IF backend.cooperative THEN
					IF callconv IN {SyntaxTree.WinAPICallingConvention, SyntaxTree.CCallingConvention} THEN
						Emit(Push(Basic.invalidPosition, one)) ;
					ELSE
						IF (procedure # NIL) & (HasPointers (procedure.procedureScope) OR HasVariableParameters (procedure.procedureScope) OR IsNested (procedure)) THEN
							GetCodeSectionNameForSymbol(procedure, name);
							Basic.SuffixSegmentedName (name, Basic.MakeString ("@StackDescriptor"));
						ELSE
							Basic.ToSegmentedName ("BaseTypes.StackFrame",name);
						END;
						IntermediateCode.InitAddress(op1, addressType, name , 0, 0);
						IntermediateCode.AddOffset(op1, 1);
						Emit(Push(Basic.invalidPosition,op1));
					END;
					Emit(Mov(Basic.invalidPosition,fp, sp));
					IF (body # NIL) & (body.code = NIL) & ~procedure.procedureScope.body.isUnchecked THEN
						NEW(call, section);
						NEW(nocall, section);
						reg := NewRegisterOperand(addressType);
						IntermediateCode.InitImmediate(op1,addressType, varSize);
						Emit(Sub(Basic.invalidPosition,reg, sp, op1));
						BrltL(call, sp, reg);
						IntermediateCode.InitMemory(op2, addressType,ap,ToMemoryUnits(system,system.addressSize*10));
						BrgeL(nocall, sp, op2);
						call.Resolve(section.pc);
						Emit(Push(Basic.invalidPosition, reg));
						ReleaseIntermediateOperand(reg);
						parametersSize := ProcParametersSize(procedure);
						IntermediateCode.InitImmediate(op2,addressType, parametersSize);
						Emit(Push(Basic.invalidPosition, op2));
						CallThis(position, "Activities","ExpandStack",2);
						Emit(Result(Basic.invalidPosition, sp));
						nocall.Resolve(section.pc);
					END;
				ELSE
					IF backend.preciseGC & (body # NIL) & (body.code = NIL) THEN
						Emit(Push(Basic.invalidPosition, one)) ;
						procedureType.SetParametersOffset(1);
						ASSERT(system.GenerateParameterOffsets(procedure, procedure.level > 0));
					END;
					Emit(Mov(Basic.invalidPosition, fp, sp));
				END;
			END;
			Emit(Enter(Basic.invalidPosition, callconv, varSize));
			SELF.section := prevSection;
			dump := prevDump;
		END EmitEnter;

		PROCEDURE Enter(position: Position; callconv: LONGINT; varSize: LONGINT): IntermediateCode.Instruction;
		VAR op1,op2: IntermediateCode.Operand;
		VAR instruction: IntermediateCode.Instruction;
		BEGIN
			IntermediateCode.InitNumber(op1,callconv);
			IntermediateCode.InitNumber(op2,varSize);
			IntermediateCode.InitInstruction(instruction, position, IntermediateCode.enter,op1,op2,emptyOperand);
			RETURN instruction
		END Enter;

		PROCEDURE Leave(position: Position; callconv: LONGINT): IntermediateCode.Instruction;
		VAR op1: IntermediateCode.Operand;
		VAR instruction: IntermediateCode.Instruction;
		BEGIN
			IntermediateCode.InitNumber(op1,callconv);
			IntermediateCode.InitInstruction(instruction, position, IntermediateCode.leave,op1,emptyOperand,emptyOperand);
			RETURN instruction
		END Leave;

		PROCEDURE EmitLeave(section: IntermediateCode.Section; position: Basic.Position; procedure: SyntaxTree.Procedure; callconv: LONGINT);
		VAR prevSection: IntermediateCode.Section;
		VAR op2: IntermediateCode.Operand;
		VAR body: SyntaxTree.Body;
		BEGIN
			prevSection := SELF.section;
			SELF.section := section;
			Emit(Leave(position, callconv));
			IF procedure # NIL THEN
				body := procedure.procedureScope.body;
			ELSE
				body := NIL;
			END;
			IF callconv # SyntaxTree.InterruptCallingConvention THEN
				IF backend.cooperative OR  backend.preciseGC & (body # NIL) & (body.code = NIL) THEN
					IntermediateCode.InitImmediate(op2,addressType, ToMemoryUnits(system, system.addressSize));
					Emit(Add(position, sp, fp, op2));
				ELSE
					Emit(Mov(position, sp, fp));
				END;
				Emit(Pop(position, fp));
			END;
			SELF.section := prevSection;
		END EmitLeave;
		
		PROCEDURE Statement(x: SyntaxTree.Statement);
		VAR use: VariableUse; result: Operand; pos: WORD;
		BEGIN
			pos := x.position.start;
			temporaries.GetUsage(use);
			position := x.position;
			IF emitLabels THEN Emit(LabelInstruction(x.position)) END;
			IF commentPrintout # NIL THEN
				commentPrintout.Statement(x);
				dump.Ln;
				(*dump.Update;*)
			END;
			
			WITH x:
			SyntaxTree.ProcedureCallStatement DO 
				Designate(x.call, result);
				IF (x.call.type # NIL) THEN (* procedure returning ignored value *)
					ReleaseOperand(result)
				END;
			| SyntaxTree.Assignment DO Assign(x.left, x.right ); 
			| SyntaxTree.CommunicationStatement DO CommunicationStatement(x)
			| SyntaxTree.IfStatement DO IfStatement(x)
			| SyntaxTree.WithStatement DO WithStatement(x)
			| SyntaxTree.CaseStatement DO CaseStatement(x)
			| SyntaxTree.WhileStatement DO WhileStatement(x)
			| SyntaxTree.RepeatStatement DO RepeatStatement(x)
			| SyntaxTree.ForStatement DO ForStatement(x)
			| SyntaxTree.LoopStatement DO LoopStatement(x)
			| SyntaxTree.ExitableBlock DO ExitableBlock(x)
			| SyntaxTree.ExitStatement DO ExitStatement(x)
			| SyntaxTree.ReturnStatement DO ReturnStatement(x)
			| SyntaxTree.AwaitStatement DO AwaitStatement(x)
			| SyntaxTree.StatementBlock DO StatementBlock(x)
			| SyntaxTree.Code DO Code(x)
			END;
			(*
			CheckRegistersFree();
			*)
			(*ResetUsedTemporaries(use);*)
			temporaries.SetUsage(use);
		END Statement;

		(* dereference op. If op is already a memory operand then use auxiliary register to dereference
			result will be registered as a new use of operand, op is not released (op must be released by caller)
		*)
		PROCEDURE MakeMemory(VAR res: IntermediateCode.Operand; op: IntermediateCode.Operand; type: IntermediateCode.Type; offset: LONGINT);
		BEGIN

			ASSERT(op.mode # IntermediateCode.Undefined);
			IF op.mode = IntermediateCode.ModeMemory THEN
				ReuseCopy(res,op);
			ELSE
				res := op;
				UseIntermediateOperand(res);
			END;
			IntermediateCode.AddOffset(res,offset);

			IntermediateCode.MakeMemory(res,type);
		END MakeMemory;

		PROCEDURE ToMemory(VAR res: IntermediateCode.Operand; type: IntermediateCode.Type; offset: LONGINT);
		VAR mem: IntermediateCode.Operand;
		BEGIN
			MakeMemory(mem,res,type,offset);
			ReleaseIntermediateOperand(res);
			res := mem;
		END ToMemory;

		PROCEDURE LoadValue(VAR operand: Operand; type: SyntaxTree.Type);
		VAR mem: IntermediateCode.Operand;
			firstOp, lastOp, stepOp: IntermediateCode.Operand;
			componentType: SyntaxTree.Type;
		BEGIN
			type := type.resolved;
			IF operand.mode = ModeReference THEN
				IF type IS SyntaxTree.RangeType THEN
					MakeMemory(firstOp, operand.op, IntermediateCode.GetType(system, system.lenType), 0);
					MakeMemory(lastOp, operand.op, IntermediateCode.GetType(system, system.lenType), ToMemoryUnits(system, system.SizeOf(system.lenType)));
					MakeMemory(stepOp, operand.op, IntermediateCode.GetType(system, system.lenType), 2 * ToMemoryUnits(system, system.SizeOf(system.lenType)));
					ReleaseOperand(operand);
					operand.op := firstOp;
					operand.tag := lastOp;
					operand.extra := stepOp;
				ELSIF type IS SyntaxTree.ComplexType THEN
					componentType := type(SyntaxTree.ComplexType).componentType;
					ASSERT((componentType.SameType(system.realType)) OR (componentType.SameType(system.longrealType)));
					MakeMemory(firstOp, operand.op, IntermediateCode.GetType(system, componentType), 0);
					MakeMemory(lastOp, operand.op, IntermediateCode.GetType(system, componentType), ToMemoryUnits(system, system.SizeOf(componentType)));
					ReleaseOperand(operand);
					operand.op := firstOp;
					operand.tag := lastOp
				ELSE
					MakeMemory(mem,operand.op,IntermediateCode.GetType(system,type),0);
					ReleaseIntermediateOperand(operand.op);
					(* EXPERIMENTAL *)
					IF operand.availability >= 0 THEN
						IF availableSymbols[operand.availability].inRegister THEN
							operand.op := availableSymbols[operand.availability].register;
							UseIntermediateOperand(operand.op);
						ELSE
							availableSymbols[operand.availability].register := NewRegisterOperand(IntermediateCode.GetType(system,type));
							availableSymbols[operand.availability].memory := mem;
							operand.op := availableSymbols[operand.availability].register;
							UseIntermediateOperand(operand.op);
							Emit(Mov(position, operand.op, mem));
							availableSymbols[operand.availability].inRegister := TRUE;
						END;
						ReleaseIntermediateOperand(mem);
					ELSE
						operand.op := mem;
					END;
				END;
				operand.mode := ModeValue;
			END;
			ASSERT(operand.mode = ModeValue);
		END LoadValue;

		PROCEDURE Evaluate(CONST x: SyntaxTree.Expression; VAR result: Operand);
		VAR operand: Operand; type: SyntaxTree.Type; symbol: SyntaxTree.Symbol;
		VAR pos: WORD;
		BEGIN
			pos := x.position.start; 
			
			IF (x.resolved # NIL) & (x.resolved # x) THEN Evaluate(x.resolved, result); RETURN END;

			WITH x:
			SyntaxTree.UnaryExpression DO
				EvaluateUnaryExpression(x, result);
			|SyntaxTree.BinaryExpression DO
				EvaluateBinaryExpression(x, result);
			|SyntaxTree.Set DO
				EvaluateSet(x, result);
			|SyntaxTree.RangeExpression DO
				InitOperand(result, ModeValue);
				ASSERT(x.first # NIL);
				Evaluate(x.first, operand);
				result.op := operand.op;
				UseIntermediateOperand(result.op);
				ReleaseOperand(operand);

				ASSERT(x.last # NIL);
				Evaluate(x.last, operand);
				result.tag := operand.op;
				UseIntermediateOperand(result.tag);
				ReleaseOperand(operand);

				IF x.step # NIL THEN
					Evaluate(x.step, operand);
					result.extra := operand.op;
					UseIntermediateOperand(result.extra);
					ReleaseOperand(operand);
				END;
			|SyntaxTree.SymbolDesignator DO
				symbol := x.symbol;
				WITH symbol: SyntaxTree.Constant DO
					Evaluate(symbol.value, result);
				| SyntaxTree.Alias DO
					Evaluate(symbol.expression, result);
				ELSE (* designate and load --> below *)
					DesignateAndLoad(x, result);
				END;
			|SyntaxTree.BuiltinCallDesignator DO
				EvaluateBuiltinCallDesignator(x,result);
			|SyntaxTree.BooleanValue DO
				InitOperand(result,ModeValue);
				IF x.value THEN result.op := true ELSE result.op := false END;
			|SyntaxTree.IntegerValue DO
				InitOperand(result,ModeValue);
				IntermediateCode.InitImmediate(result.op,IntermediateCode.GetType(system,x.type),x.value);
				IF ~supportedImmediate(result.op)  &~inData THEN
					GetImmediateMem(result.op)
				END;
			|SyntaxTree.CharacterValue DO
				InitOperand(result,ModeValue);
				IntermediateCode.InitImmediate(result.op,IntermediateCode.GetType(system,x.type),SYSTEM.VAL(Basic.Integer,x.value));
			|SyntaxTree.RealValue DO
				InitOperand(result,ModeValue);
				IntermediateCode.InitFloatImmediate(result.op,IntermediateCode.GetType(system,x.type),x.value);
			|SyntaxTree.ComplexValue DO
				type := x.type(SyntaxTree.ComplexType).componentType;
				InitOperand(result,ModeValue);
				IntermediateCode.InitFloatImmediate(result.op,IntermediateCode.GetType(system,type),x.realValue); (* real part *)
				IntermediateCode.InitFloatImmediate(result.tag,IntermediateCode.GetType(system,type),x.imagValue); (* imaginary part *)
			|SyntaxTree.NilValue DO
				InitOperand(result,ModeValue);
				result.op := IntermediateCode.Immediate(IntermediateCode.GetType(system,x.type),0);
				result.tag := IntermediateCode.Immediate(IntermediateCode.GetType(system,x.type),0);
			|SyntaxTree.EnumerationValue DO
				InitOperand(result,ModeValue);
				result.op := IntermediateCode.Immediate(IntermediateCode.GetType(system,x.type),x.value);
			|SyntaxTree.SetValue DO
				InitOperand(result,ModeValue);
				result.op := IntermediateCode.Immediate(IntermediateCode.GetType(system,x.type),SYSTEM.VAL(Basic.Integer,x.value));
			ELSE (* other designators -- go back to fallback case: designate and load *)
				DesignateAndLoad(x,result);
			END;
		END Evaluate;

		PROCEDURE Designate(x: SyntaxTree.Expression; VAR result: Operand);
		VAR pos: WORD;
		BEGIN
			pos := x.position.start; 
			InitOperand(result,ModeUndefined);
			
			IF (x.resolved # NIL) & (x.resolved # x) THEN 
				(* value with address -- string or array value *)
				Designate(x.resolved, result); 
				RETURN;
			END;
			
			WITH x:
			| SyntaxTree.ResultDesignator DO DesignateResultDesignator(x, result)
			| SyntaxTree.SelfDesignator DO DesignateSelfDesignator(x, result)
			| SyntaxTree.SupercallDesignator DO DesignateSupercallDesignator(x, result)
			| SyntaxTree.DereferenceDesignator DO DesignateDereferenceDesignator(x, result)
			| SyntaxTree.TypeGuardDesignator DO DesignateTypeGuardDesignator(x, result)
			| SyntaxTree.BuiltinCallDesignator DO DesignateBuiltinCallDesignator(x, result)
			| SyntaxTree.ProcedureCallDesignator DO DesignateProcedureCallDesignator(x, result)
			| SyntaxTree.InlineCallDesignator DO DesignateInlineCallDesignator(x, result)
			| SyntaxTree.IndexDesignator DO DesignateIndexDesignator(x, result)
			| SyntaxTree.SymbolDesignator DO DesignateSymbolDesignator(x, result)
			| SyntaxTree.Conversion DO DesignateConversion(x, result)
			| SyntaxTree.MathArrayExpression DO DesignateMathArrayExpression(x, result)
			| SyntaxTree.StringValue DO DesignateStringValue(x, result)
			| SyntaxTree.MathArrayValue DO DesignateMathArrayValue(x, result)
			| SyntaxTree.NilValue DO Evaluate(x, result); (* NIL parameter passed in WINAPI cc *)
			END;

			
			(* check this, was commented out in ActiveCells3 *)
			IF (x IS SyntaxTree.Designator) & (x(SyntaxTree.Designator).modifiers # NIL) & ~backend.cellsAreObjects THEN
				Error(x.position, "unsupported modifier");
			END;
		END Designate;

		PROCEDURE DesignateAndLoad(x: SyntaxTree.Expression; VAR result: Operand);
		BEGIN
			Designate(x, result);
			LoadValue(result, x.type.resolved);
		END DesignateAndLoad;

		PROCEDURE Condition(CONST x: SyntaxTree.Expression; label: Label; reason: BOOLEAN);
		VAR skip: Label; recordType: SyntaxTree.RecordType; left, right: Operand;
			leftType, rightType: SyntaxTree.Type; temp: IntermediateCode.Operand;
			leftExpression, rightExpression: SyntaxTree.Expression;
			pos: WORD;
		BEGIN
			pos := x.position.start;
			ASSERT(label # NIL);
			IF (x.resolved # NIL) & (x.resolved # x) THEN Condition(x.resolved, label, reason); RETURN END;
			WITH x:
			SyntaxTree.UnaryExpression DO
				CASE x.operator OF
					Scanner.Not:
						Condition(x.left,label,~reason);
						RETURN;
				ELSE
				END;
			| SyntaxTree.BinaryExpression DO
					leftType := x.left.type.resolved;
					rightType := x.right.type.resolved;
					CASE x.operator OF
					Scanner.Or:
						(* shortcut evaluation of left OR right *)
							IF reason THEN (*left or right*)
								Condition(x.left,label,TRUE);
								Condition(x.right,label,TRUE);
							ELSE (* ~ (left or right) = ~left & ~right *)
								skip := NewLabel();
								Condition(x.left,skip,TRUE);
								Condition(x.right,label,FALSE);
								SetLabel(skip);
							END;
							RETURN;
					|Scanner.And:
						(* shortcut evaluation of left & right *)
						IF reason THEN (* left and right *)
							skip := NewLabel();
							Condition(x.left,skip,FALSE);
							Condition(x.right,label,TRUE);
							SetLabel(skip);
						ELSE (* ~(left and right) = ~left or ~right *)
							Condition(x.left,label,FALSE);
							Condition(x.right,label,FALSE);
						END;
						RETURN;
					|Scanner.Is:
						IF (leftType IS SyntaxTree.NumberType) OR (leftType IS SyntaxTree.AddressType) OR (leftType IS SyntaxTree.SizeType) THEN
							Evaluate(x.left, left);
							TransferToRegister(left.op, left.op);
							ReuseCopy(temp,left.op);
							Convert(temp,IntermediateCode.GetType(system,x.right(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType.resolved));
							Convert(temp,left.op.type);
							IF reason THEN
								BreqL(label,left.op,temp);
							ELSE
								BrneL(label,left.op,temp);
							END;
							ReleaseIntermediateOperand(temp);
						ELSE
							(* get type desc tag *)
							IF IsPointerToRecord(x.left.type,recordType) THEN
								Evaluate(x.left, left);
								Dereference(left,recordType,IsUnsafePointer(x.left.type))
							ELSE
								Designate(x.left,left);
							END;
							TypeTest(left.tag,x.right(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType.resolved,label,reason,FALSE);
						END;
						ReleaseOperand(left);
						RETURN;
					|Scanner.Equal:
					IF (leftType IS SyntaxTree.ArrayType) OR (leftType IS SyntaxTree.StringType) THEN (* string comparison *)
						IF reason THEN
							CompareString(BreqL,label,x.left,x.right);
						ELSE
							CompareString(BrneL,label,x.left,x.right);
						END;
					ELSE
						Evaluate(x.left,left);
						Evaluate(x.right,right);
						IF leftType IS SyntaxTree.RangeType THEN
							ASSERT(rightType IS SyntaxTree.RangeType);
							IF reason THEN
								skip := NewLabel();
								BrneL(skip, left.op, right.op); (* first *)
								BrneL(skip, left.tag, right.tag); (* last *)
								BreqL(label, left.extra, right.extra); (* step *)
								SetLabel(skip);
							ELSE
								BrneL(label, left.op, right.op); (* first *)
								BrneL(label, left.tag, right.tag); (* last *)
								BrneL(label, left.extra, right.extra); (* step *)
							END;
							ReleaseOperand(left); ReleaseOperand(right);
						ELSIF IsDelegate(leftType) OR (leftType IS SyntaxTree.ComplexType) THEN (* pair comparison *)
							IF reason THEN
								skip := NewLabel();
								BrneL(skip, left.op, right.op); (* first *)
								BreqL(label, left.tag, right.tag); (* last *)
								SetLabel(skip);
							ELSE
								BrneL(label, left.op, right.op); (* first *)
								BrneL(label, left.tag, right.tag); (* last *)
							END;
							ReleaseOperand(left); ReleaseOperand(right);
						ELSE
							IF reason THEN
								BreqL(label,left.op,right.op);
							ELSE
								BrneL(label,left.op,right.op);
							END;
							ReleaseOperand(left); ReleaseOperand(right);
						END;
					END;
					RETURN;
				|Scanner.LessEqual:
					IF (leftType IS SyntaxTree.ArrayType) OR (leftType IS SyntaxTree.StringType) THEN (* string comparison *)
						IF reason THEN
							CompareString(BrgeL,label,x.right,x.left);
						ELSE
							CompareString(BrltL,label,x.right,x.left);
						END;
					ELSE
						Evaluate(x.left,left);
						Evaluate(x.right,right);
						IF leftType IS SyntaxTree.SetType THEN (* left subsetequal right: left \cap right = left  *)
							Reuse1(temp,right.op);
							Emit(And(position,temp,left.op,right.op));
							ReleaseOperand(right);
							IF reason THEN
								BreqL(label,temp,left.op);
							ELSE
								BrneL(label,temp,left.op);
							END;
							ReleaseIntermediateOperand(temp);ReleaseOperand(left);
						ELSE
							IF reason THEN
								BrgeL(label,right.op,left.op);
							ELSE
								BrltL(label,right.op,left.op);
							END;
							ReleaseOperand(left); ReleaseOperand(right);
						END;
					END;
					RETURN;
				|Scanner.Less:
					IF leftType IS SyntaxTree.SetType THEN (* left < right <=> left <= right & left # right *)
						leftExpression := SyntaxTree.NewBinaryExpression(Basic.invalidPosition,x.left,x.right,Scanner.LessEqual);
						leftExpression.SetType(system.booleanType);
						rightExpression := SyntaxTree.NewBinaryExpression(Basic.invalidPosition,x.left,x.right,Scanner.Unequal);
						rightExpression.SetType(system.booleanType);
						leftExpression := SyntaxTree.NewBinaryExpression(Basic.invalidPosition,leftExpression,rightExpression,Scanner.And);
						leftExpression.SetType(system.booleanType);
						Condition(leftExpression,label,reason);
					ELSIF (leftType IS SyntaxTree.ArrayType) OR (leftType IS SyntaxTree.StringType) THEN (* string comparison *)
						IF reason THEN
							CompareString(BrltL,label,x.left,x.right);
						ELSE
							CompareString(BrgeL,label,x.left,x.right);
						END;
					ELSE
						Evaluate(x.left,left);
						Evaluate(x.right,right);
						IF reason THEN
							BrltL(label,left.op,right.op);
						ELSE
							BrgeL(label,left.op,right.op);
						END;
						ReleaseOperand(left); ReleaseOperand(right);
					END;
					RETURN;
				|Scanner.Greater:
					IF leftType IS SyntaxTree.SetType THEN (* left > right <=> left >= right & left # right  *)
						leftExpression := SyntaxTree.NewBinaryExpression(Basic.invalidPosition,x.left,x.right,Scanner.GreaterEqual);
						leftExpression.SetType(system.booleanType);
						rightExpression := SyntaxTree.NewBinaryExpression(Basic.invalidPosition,x.left,x.right,Scanner.Unequal);
						rightExpression.SetType(system.booleanType);
						leftExpression := SyntaxTree.NewBinaryExpression(Basic.invalidPosition,leftExpression,rightExpression,Scanner.And);
						leftExpression.SetType(system.booleanType);
						Condition(leftExpression,label,reason);
					ELSIF (leftType IS SyntaxTree.ArrayType) OR (leftType IS SyntaxTree.StringType) THEN (* string comparison *)
						IF reason THEN
							CompareString(BrltL,label,x.right,x.left);
						ELSE
							CompareString(BrgeL,label,x.right,x.left);
						END;
					ELSE
						Evaluate(x.left,left);
						Evaluate(x.right,right);
						IF reason THEN
							BrltL(label, right.op,left.op);
						ELSE
							BrgeL(label, right.op,left.op);
						END;
						ReleaseOperand(left); ReleaseOperand(right);
					END;
					RETURN;
				|Scanner.GreaterEqual:
					IF (leftType IS SyntaxTree.ArrayType) OR (leftType IS SyntaxTree.StringType) THEN (* string comparison *)
						IF reason THEN
							CompareString(BrgeL,label,x.left,x.right);
						ELSE
							CompareString(BrltL,label,x.left,x.right);
						END;
					ELSE
						Evaluate(x.left,left);
						Evaluate(x.right,right);
						IF leftType IS SyntaxTree.SetType THEN (* left supsetequal right: left \cap right = right *)
							Reuse1(temp,left.op);
							Emit(And(position,temp,left.op,right.op));
							ReleaseOperand(left);
							IF reason THEN
								BreqL(label, temp, right.op);
							ELSE
								BrneL(label, temp, right.op);
							END;
							ReleaseIntermediateOperand(temp); ReleaseOperand(right);
						ELSE
							IF reason THEN
								BrgeL(label,left.op,right.op);
							ELSE
								BrltL(label, left.op,right.op);
							END;
							ReleaseOperand(left); ReleaseOperand(right);
						END;
					END;
					RETURN;
				|Scanner.Unequal:
					IF (leftType IS SyntaxTree.ArrayType) OR (leftType IS SyntaxTree.StringType) THEN (* string comparison *)
						IF reason THEN
							CompareString(BrneL,label,x.left,x.right);
						ELSE
							CompareString(BreqL,label,x.left,x.right);
						END
					ELSE
						Evaluate(x.left,left);
						Evaluate(x.right,right);
						IF leftType IS SyntaxTree.RangeType THEN
							ASSERT(rightType IS SyntaxTree.RangeType);
							IF ~reason THEN
								skip := NewLabel();
								BrneL(skip, left.op, right.op); (* first *)
								BrneL(skip, left.tag, right.tag); (* last *)
								BreqL(label, left.extra, right.extra); (* step *)
								SetLabel(skip);
							ELSE
								BrneL(label, left.op, right.op); (* first *)
								BrneL(label, left.tag, right.tag); (* last *)
								BrneL(label, left.extra, right.extra); (* step *)
							END;
							ReleaseOperand(left); ReleaseOperand(right);
						ELSIF IsDelegate(leftType) OR (leftType IS SyntaxTree.ComplexType) THEN (* pair comparison *)
							IF reason THEN
								BrneL(label, left.op, right.op);
								BrneL(label, left.tag, right.tag);
							ELSE
								skip := NewLabel();
								BrneL(skip, left.op, right.op);
								BreqL(label, left.tag, right.tag);
								SetLabel(skip);
							END;
							ReleaseOperand(left); ReleaseOperand(right);
						ELSE
							IF reason THEN
								BrneL(label,left.op,right.op);
							ELSE
								BreqL(label,left.op,right.op);
							END;
							ReleaseOperand(left); ReleaseOperand(right);
						END;
					END;
					RETURN;
				ELSE (* case *)
				END;
			|SyntaxTree.BooleanValue DO
				IF reason = x.value THEN BrL(label) END;
				RETURN;
			ELSE (* with *)
			END;
			(* default case: evaluate and compare result *)
			Evaluate(x,left);
			IF reason THEN
				BrneL(label,left.op, false);
			ELSE
				BreqL(label,left.op, false);
			END;
			ReleaseOperand(left);
		END Condition;

		PROCEDURE EvaluateUnaryExpression(x: SyntaxTree.UnaryExpression; VAR result: Operand);
		VAR type,t0: SyntaxTree.Type; operand: Operand; dest: IntermediateCode.Operand;
		BEGIN
			IF Trace THEN TraceEnter("EvaluateUnaryExpression") END;
			dest := destination; destination := emptyOperand;
			CASE x.operator OF
			Scanner.Not:
				Evaluate(x.left, operand);
				InitOperand(result,ModeValue);
				Reuse1a(result.op,operand.op,dest);
				Emit(Xor(position,result.op,operand.op,true));
				ReleaseOperand(operand);
			|Scanner.Minus:
				Evaluate(x.left, operand);
				InitOperand(result,ModeValue);
				Reuse1a(result.op,operand.op,dest);
				type := x.left.type.resolved;
				IF type IS SyntaxTree.SetType THEN
					Emit(Not(position,result.op,operand.op));
				ELSIF (type IS SyntaxTree.ComplexType) THEN
					Reuse1(result.tag,operand.tag);
					Emit(Neg(position,result.op,operand.op)); (* real part *)
					Emit(Neg(position,result.tag,operand.tag)) (* imaginary part *)
				ELSIF (type IS SyntaxTree.NumberType) OR (type IS SyntaxTree.SizeType) OR (type IS SyntaxTree.AddressType) THEN
					Emit(Neg(position,result.op,operand.op));
				ELSE HALT(200)
				END;
				ReleaseOperand(operand);
			|Scanner.Address:
				Designate(x.left,result);
				result.mode := ModeValue;
				t0 := x.left.type.resolved;
				IF (t0 IS SyntaxTree.MathArrayType) & (t0(SyntaxTree.MathArrayType).form = SyntaxTree.Open) THEN
					ReleaseIntermediateOperand(result.op);
					result.op := result.tag;
					IntermediateCode.InitOperand(result.tag);
				END;
				Convert(result.op,IntermediateCode.GetType(system,x.type));
			END;
			destination := dest;
			IF Trace THEN TraceExit("UnaryExpression") END;
		END EvaluateUnaryExpression;

		PROCEDURE EvaluateBinaryExpression(x: SyntaxTree.BinaryExpression; VAR result: Operand);
		VAR left,right: Operand;zero, one, tempReg, tempReg2: IntermediateCode.Operand;
			leftType,rightType: SyntaxTree.Type;
			leftExpression,rightExpression : SyntaxTree.Expression;
			componentType: IntermediateCode.Type;
			exit: Label; dest: IntermediateCode.Operand;
			size: LONGINT;
		BEGIN
			IF Trace THEN TraceEnter("BinaryExpression") END;
			dest := destination; destination := emptyOperand;
			leftType := x.left.type.resolved;
			rightType := x.right.type.resolved;
			CASE x.operator OF
			Scanner.Or, Scanner.And, Scanner.Is:
				result := ConditionValue(x);
			|Scanner.Plus:
				Evaluate(x.left,left);
				Evaluate(x.right,right);
				IF leftType IS SyntaxTree.SetType THEN
					InitOperand(result,ModeValue);
					Reuse2a(result.op,left.op,right.op,dest);
					Emit(Or(position,result.op,left.op,right.op));
				ELSIF leftType IS SyntaxTree.ComplexType THEN
					InitOperand(result,ModeValue);
					Reuse2a(result.op,left.op,right.op,dest); (* TODO: review this *)
					Reuse2(result.tag,left.tag,right.tag);
					Emit(Add(position,result.op,left.op,right.op));
					Emit(Add(position,result.tag,left.tag,right.tag))
				ELSE
					InitOperand(result,ModeValue);
					Reuse2a(result.op,left.op,right.op,dest);
					Emit(Add(position,result.op,left.op,right.op));
				END;
				ReleaseOperand(left); ReleaseOperand(right);
			|Scanner.Minus:
				Evaluate(x.left,left);
				Evaluate(x.right,right);
				IF leftType IS SyntaxTree.SetType THEN
					InitOperand(result,ModeValue);
					Reuse1(result.op,right.op);
					Emit(Not(position,result.op,right.op));
					ReleaseOperand(right);
					Emit(And(position,result.op,result.op,left.op));
					ReleaseOperand(left);
				ELSIF leftType IS SyntaxTree.ComplexType THEN
					InitOperand(result,ModeValue);
					Reuse2a(result.op,left.op,right.op,dest);
					Reuse2(result.tag,left.tag,right.tag);
					Emit(Sub(position,result.op,left.op,right.op));
					Emit(Sub(position,result.tag,left.tag,right.tag));
					ReleaseOperand(left); ReleaseOperand(right)
				ELSE
					InitOperand(result,ModeValue);
					Reuse2a(result.op,left.op,right.op,dest);
					Emit(Sub(position,result.op,left.op,right.op));
					ReleaseOperand(left); ReleaseOperand(right);
				END;
			|Scanner.Times:
				Evaluate(x.left, left);
				Evaluate(x.right, right);
				IF leftType IS SyntaxTree.SetType THEN
					InitOperand(result,ModeValue);
					Reuse2a(result.op,left.op,right.op,dest);
					Emit(And(position,result.op,left.op,right.op));
				ELSIF leftType IS SyntaxTree.ComplexType THEN
					InitOperand(result, ModeValue);
					componentType := left.op.type;
					result.op := IntermediateCode.Register(componentType, IntermediateCode.GeneralPurposeRegister,AcquireRegister(componentType,IntermediateCode.GeneralPurposeRegister));
					Emit(Mul(position,result.op, left.op, right.op));
					tempReg := IntermediateCode.Register(componentType, IntermediateCode.GeneralPurposeRegister,AcquireRegister(componentType,IntermediateCode.GeneralPurposeRegister));
					Emit(Mul(position,tempReg, left.tag, right.tag));
					Emit(Sub(position,result.op, result.op, tempReg));

					Reuse2(result.tag, left.tag, right.op);
					Emit(Mul(position,result.tag, left.tag, right.op));
					Emit(Mul(position,tempReg, left.op, right.tag));
					Emit(Add(position,result.tag, result.tag, tempReg));

					ReleaseIntermediateOperand(tempReg)
				ELSE
					InitOperand(result,ModeValue);
					Reuse2a(result.op,left.op,right.op,dest);
					Emit(Mul(position,result.op,left.op,right.op));
				END;
				ReleaseOperand(left); ReleaseOperand(right);
			|Scanner.Div:
				Evaluate(x.left, left);
				Evaluate(x.right, right);
				IF (x.type.resolved IS SyntaxTree.IntegerType) & (x.right.resolved = NIL) THEN (* divisor negative check *)
					IntermediateCode.InitImmediate(zero,IntermediateCode.GetType(system,rightType),0);
					IF ~isUnchecked THEN
						exit := NewLabel();
						BrltL(exit,zero,right.op);
						EmitTrap(position,NegativeDivisorTrap);
						SetLabel(exit);
					END;
				END;
				InitOperand(result,ModeValue);
				Reuse2a(result.op,left.op,right.op,dest);
				Emit(Div(position,result.op,left.op,right.op));
				ReleaseOperand(left); ReleaseOperand(right);
			|Scanner.Mod:
				Evaluate(x.left, left);
				Evaluate(x.right, right);
				IF (x.type.resolved IS SyntaxTree.IntegerType) & (x.right.resolved = NIL) THEN (* divisor negative check *)
					IntermediateCode.InitImmediate(zero,IntermediateCode.GetType(system,rightType),0);
					IF ~isUnchecked THEN
						exit := NewLabel();
						BrltL(exit,zero,right.op);
						EmitTrap(position,NegativeDivisorTrap);
						SetLabel(exit);
					END;
				END;
				InitOperand(result,ModeValue);
				Reuse2a(result.op,left.op,right.op,dest);
				Emit(Mod(position,result.op,left.op,right.op));
				ReleaseOperand(left); ReleaseOperand(right);
			|Scanner.Slash:
				Evaluate(x.left, left);
				Evaluate(x.right, right);
				IF leftType IS SyntaxTree.SetType THEN
					InitOperand(result,ModeValue);
					Reuse2a(result.op,left.op,right.op,dest);
					Emit(Xor(position,result.op,left.op,right.op));
				ELSIF leftType IS SyntaxTree.ComplexType THEN
					InitOperand(result,ModeValue);
					componentType := left.op.type;
					(*
					divisor = right.op * right.op + right.tag * right.tag
					result.op = (left.op * right.op + left.tag * right.tag) / divisor
					result.tag = (left.tag * right.op - left.op * right.tag) / divisor
					*)
					tempReg := IntermediateCode.Register(componentType, IntermediateCode.GeneralPurposeRegister,AcquireRegister(componentType,IntermediateCode.GeneralPurposeRegister));
					tempReg2 := IntermediateCode.Register(componentType, IntermediateCode.GeneralPurposeRegister,AcquireRegister(componentType,IntermediateCode.GeneralPurposeRegister));
					Emit(Mul(position,tempReg, right.op, right.op));
					Emit(Mul(position,tempReg2, right.tag, right.tag));
					Emit(Add(position,tempReg, tempReg, tempReg2));

					result.op := tempReg2;
					Emit(Mul(position,result.op, left.op, right.op));
					tempReg2 := IntermediateCode.Register(componentType, IntermediateCode.GeneralPurposeRegister, AcquireRegister(componentType,IntermediateCode.GeneralPurposeRegister));
					Emit(Mul(position,tempReg2, left.tag, right.tag));
					Emit(Add(position,result.op, result.op, tempReg2));
					Emit(Div(position,result.op, result.op, tempReg));

					Reuse2(result.tag, left.tag, right.op);
					Emit(Mul(position,result.tag, left.tag, right.op));
					Emit(Mul(position,tempReg2, left.op, right.tag));
					Emit(Sub(position,result.tag, result.tag, tempReg2));
					Emit(Div(position,result.tag, result.tag, tempReg));

					ReleaseIntermediateOperand(tempReg);
					ReleaseIntermediateOperand(tempReg2)
				ELSE
					InitOperand(result,ModeValue);
					Reuse2a(result.op,left.op,right.op,dest);
					Emit(Div(position,result.op,left.op,right.op));
				END;
				ReleaseOperand(left); ReleaseOperand(right);
			|Scanner.Equal, Scanner.LessEqual, Scanner.Less, Scanner.Greater, Scanner.GreaterEqual, Scanner.Unequal :
				result := ConditionValue(x);
			|Scanner.In:
				ASSERT(rightType.resolved IS SyntaxTree.SetType);
				Evaluate(x.left, left);
				Evaluate(x.right, right);
				Convert(left.op,setType);
				Convert(right.op,setType);
				result.mode := ModeValue;
				result.tag := nil; (* may be left over from calls to evaluate *)
				ReuseCopy(result.op,right.op);
				Emit(Shr(position,result.op,result.op,left.op));
				ReleaseOperand(right); ReleaseOperand(left);
				IntermediateCode.InitImmediate(one,setType,1);
				Emit(And(position,result.op,result.op,one));
				Convert(result.op,bool);
			ELSE
				IF (x.operator = Scanner.Questionmarks) OR (x.operator = Scanner.LessLessQ) & (x.right.type.resolved IS SyntaxTree.PortType) THEN
					IF x.operator = Scanner.Questionmarks THEN
						leftExpression := x.left;
						rightExpression := x.right;
					ELSE
						leftExpression := x.right;
						rightExpression := x.left;
					END;

					Evaluate(leftExpression, left);
					Emit(Push(position,left.op));
					ReleaseOperand(left);
					Designate(rightExpression, right);
					size := ToMemoryUnits(system,system.SizeOf(x.right.type));
					IF ~backend.cellsAreObjects THEN
						IF size # 1 THEN Error(x.right.position,"receive not implemented for complex data types") END;
					END;
					Emit(Push(position,right.op));
					ReleaseOperand(right);
					IF backend.cellsAreObjects THEN
						CallThis(position,"ActiveCellsRuntime","ReceiveNonBlocking",2);
					ELSE
						CallThis(position,ChannelModuleName,"ReceiveNonBlocking",2);
					END;
					InitOperand(result, ModeValue);
					result.op := NewRegisterOperand(bool);
					Emit(Result(position,result.op));
				ELSIF (x.operator = Scanner.ExclamationMarks) OR (x.operator = Scanner.LessLessQ) & (x.left.type.resolved IS SyntaxTree.PortType) THEN
					leftExpression := x.left;
					rightExpression := x.right;

					Evaluate(leftExpression, left);
					Emit(Push(position,left.op));
					ReleaseOperand(left);
					Evaluate(rightExpression, right);
					size := ToMemoryUnits(system,system.SizeOf(x.right.type));
					IF ~backend.cellsAreObjects THEN
						IF size # 1 THEN Error(x.right.position,"send not implemented for complex data types") END;
					END;
					Emit(Push(position,right.op));
					ReleaseOperand(right);
					IF backend.cellsAreObjects THEN
						CallThis(position,"ActiveCellsRuntime","SendNonBlocking",2);
					ELSE
						CallThis(position,ChannelModuleName,"SendNonBlocking",2);
					END;
					InitOperand(result, ModeValue);
					result.op := NewRegisterOperand(bool);
					Emit(Result(position,result.op));
				ELSE
					HALT(100);
				END;
			END;
			destination := dest;
			IF Trace THEN TraceExit("BinaryExpression") END;
		END EvaluateBinaryExpression;

		PROCEDURE EvaluateSet(x: SyntaxTree.Set; VAR result: Operand);
		VAR
			operand: Operand;
			temp, one, noBits, dest: IntermediateCode.Operand;
			expression: SyntaxTree.Expression;
			i: LONGINT;

		BEGIN
			IF Trace THEN TraceEnter("EvaluateSet") END;

			dest := destination;
			destination := emptyOperand;

			noBits := IntermediateCode.Immediate(setType, 0);
			one := IntermediateCode.Immediate(setType, 1);

			(* start off with the empty set *)
			InitOperand(result, ModeValue);
			IntermediateCode.InitRegister(result.op, setType, IntermediateCode.GeneralPurposeRegister, AcquireRegister(setType, IntermediateCode.GeneralPurposeRegister));
			Emit(Mov(position,result.op, noBits));

			FOR i := 0 TO x.elements.Length() - 1 DO
				expression := x.elements.GetExpression(i);

				IF expression IS SyntaxTree.RangeExpression THEN
					(* range of set elements *)
					temp := SetFromRange(expression(SyntaxTree.RangeExpression));
					ASSERT(IntermediateCode.TypeEquals(setType, temp.type));
					Emit(Or(position,result.op, result.op, temp)); (* unify subset with current set *)
					ReleaseIntermediateOperand(temp)
				ELSE
					(* singelton element *)
					Evaluate(expression, operand);
					Convert(operand.op, setType);
					CheckSetElement(operand.op);

					(* create subset containing single element *)
					Reuse1(temp, operand.op);
					Emit(Shl(position,temp, one, operand.op));
					ReleaseOperand(operand);

					Emit(Or(position,result.op, result.op, temp)); (* unify subset with current set *)
					ReleaseIntermediateOperand(temp);
				END
			END;

			destination := dest;
			IF Trace THEN TraceExit("EvaluateSet") END;
		END EvaluateSet;

		PROCEDURE NewRegisterOperand(type: IntermediateCode.Type): IntermediateCode.Operand;
		VAR op: IntermediateCode.Operand; reg: LONGINT;
		BEGIN
			reg := AcquireRegister(type,IntermediateCode.GeneralPurposeRegister);
			IntermediateCode.InitRegister(op, type, IntermediateCode.GeneralPurposeRegister,reg);
			RETURN op
		END NewRegisterOperand;

		PROCEDURE UnuseRegister(register: LONGINT);
		BEGIN
			IF (register > 0) THEN
				register := registerUsageCount.Map(register);
				registerUsageCount.DecUse(register);
				IF TraceRegisterUsageCount & (dump# NIL) THEN
					dump.String("unuse register "); dump.Int(register,1); dump.String(": ");dump.Int(registerUsageCount.Use(register),1); dump.Ln; dump.Update;
				END;
				IF registerUsageCount.Use(register)=0 THEN
					IF ~RemoveRegisterEntry(usedRegisters,register) THEN
						Warning(position, "register cannot be removed");
					END;
					IF TraceRegisterUsageCount & (dump# NIL) THEN
						dump.String("remove register from usedRegisters"); dump.Ln; dump.Update;
					END;
				ELSIF registerUsageCount.Use(register)<0 THEN
					Warning(position, "register removed too often");
					IF dump # NIL THEN
						dump.String("register removed too often"); dump.Ln; dump.Update;
					END;
				END;
			END;
		END UnuseRegister;

		PROCEDURE UseRegister(register: LONGINT);
		BEGIN
			IF (register > 0) THEN
				register := registerUsageCount.Map(register);

				registerUsageCount.IncUse(register);
				IF TraceRegisterUsageCount & (dump# NIL) THEN
					dump.String("use register "); dump.Int(register,1); dump.String(": ");dump.Int(registerUsageCount.Use(register),1); dump.Ln; dump.Update;
				END;
				IF registerUsageCount.Use(register)=1 THEN
					AddRegisterEntry(usedRegisters,register, registerUsageCount.used[register].class, registerUsageCount.used[register].type);
					IF TraceRegisterUsageCount & (dump# NIL) THEN
						dump.String("add register to usedRegisters"); dump.Ln; dump.Update;
					END;
				END;
			END;
		END UseRegister;

		PROCEDURE ReleaseIntermediateOperand(CONST op: IntermediateCode.Operand);
		BEGIN
			UnuseRegister(op.register)
		END ReleaseIntermediateOperand;

		PROCEDURE UseIntermediateOperand(CONST op: IntermediateCode.Operand);
		BEGIN
			UseRegister(op.register)
		END UseIntermediateOperand;

		PROCEDURE ReleaseOperand(CONST op: Operand);
		BEGIN
			UnuseRegister(op.op.register);
			UnuseRegister(op.tag.register);
			UnuseRegister(op.extra.register);
		END ReleaseOperand;

		(* save registers marked in array "markedRegisters" to the stack
			remove entries from array "markedRegisters" and save to array "saved" (=> recursion possible)
		*)
		PROCEDURE SaveRegisters();
		VAR op: IntermediateCode.Operand; entry: RegisterEntry; type: IntermediateCode.Type;
		BEGIN
			entry := usedRegisters;
			WHILE entry # NIL DO
				type := registerUsageCount.used[entry.register].type;
				IntermediateCode.InitRegister(op,entry.type,entry.registerClass, entry.register);
				Emit(Push(position,op));
				entry := entry.next;
			END;
		END SaveRegisters;

		PROCEDURE ReleaseUsedRegisters(VAR saved: RegisterEntry);
		BEGIN
			saved := usedRegisters;
			usedRegisters := NIL;
		END ReleaseUsedRegisters;

		(** remove parameter registers from used queue *)
		PROCEDURE ReleaseParameterRegisters;
		VAR entry,prev,next: RegisterEntry;
		BEGIN
			entry := usedRegisters; prev := NIL; usedRegisters := NIL;
			WHILE entry # NIL DO
				next := entry.next;
				IF entry.registerClass.class = IntermediateCode.Parameter THEN
					registerUsageCount.DecUse(entry.register);
					ASSERT(registerUsageCount.Use(entry.register)=0);
					Emit(Use(Basic.invalidPosition, IntermediateCode.Register(entry.type, entry.registerClass, entry.register))); (* for the backend *)
					IF TraceRegisterUsageCount & (dump# NIL) THEN
						dump.String("unuse register "); dump.Int(entry.register,1); dump.Ln; dump.Update;
					END;
				ELSIF prev = NIL THEN
					usedRegisters := entry; entry.prev := NIL; entry.next := NIL; prev := entry;
				ELSE
					prev.next := entry; entry.prev := prev; entry.next := NIL; prev:= entry;
				END;
				entry := next;
			END;
		END ReleaseParameterRegisters;

		(* restore registers from array saved and re-enter into array markedRegisters (recursion possible) *)
		PROCEDURE RestoreRegisters(CONST saved: RegisterEntry);
		VAR op: IntermediateCode.Operand; entry,prev: RegisterEntry; type: IntermediateCode.Type; class: IntermediateCode.RegisterClass;
		BEGIN
			entry := saved;
			WHILE (entry # NIL) DO prev := entry; entry := entry.next END;
			entry := prev;
			WHILE entry # NIL DO
				prev := entry.prev;
				type := entry.type;
				class := entry.registerClass;
				IntermediateCode.InitRegister(op,type,class,entry.register);
				Emit(Pop(position,op));
				AddRegisterEntry(usedRegisters,entry.register,entry.registerClass, entry.type);
				entry := prev;
			END;
		END RestoreRegisters;

		(* re-enter registers from array saved into array markedRegisters (recursion possible) *)
		PROCEDURE RestoreRegisterUse(CONST saved: RegisterEntry);
		VAR op: IntermediateCode.Operand; entry,prev: RegisterEntry; type: IntermediateCode.Type; class: IntermediateCode.RegisterClass;
		BEGIN
			entry := saved;
			WHILE (entry # NIL) DO prev := entry; entry := entry.next END;
			entry := prev;
			WHILE entry # NIL DO
				prev := entry.prev;
				type := entry.type;
				class := entry.registerClass;
				IntermediateCode.InitRegister(op,type,class,entry.register);
				Emit(Mov(position,op,op));
				AddRegisterEntry(usedRegisters,entry.register,entry.registerClass, entry.type);
				entry := prev;
			END;
		END RestoreRegisterUse;

		PROCEDURE CheckRegistersFree;
		VAR r: RegisterEntry; warning: ARRAY 128 OF CHAR; i: LONGINT;
		BEGIN
			IF usedRegisters # NIL THEN
				r := usedRegisters;
				WHILE r # NIL DO
					warning := "register ";
					Strings.AppendInt(warning, r.register);
					Strings.Append(warning, " not released.");
					Warning(position,warning);
					r := r .next;
				END;
			END;
			FOR i := 0 TO registerUsageCount.count-1 DO
				IF registerUsageCount.used[i].count < 0 THEN
					warning := "register ";
					Strings.AppendInt(warning, i);
					Strings.Append(warning, " unused too often.");
					Warning(position,warning);
				ELSIF registerUsageCount.used[i].count > 0 THEN (* should always coincide with cases above *)
					warning := "register ";
					Strings.AppendInt(warning, i);
					Strings.Append(warning, " not unused often enough.");
					Warning(position,warning);
				END;
			END;
		END CheckRegistersFree;

		(* Reuse2: reuse src1 or src2 for ongoing computation if src1 or src2, respectively, is a register.
			Otherwise allocate a new register.
			Does NOT necessarily keep the content of src1 or src2 in result! *)
		PROCEDURE Reuse2(VAR result: IntermediateCode.Operand; src1,src2: IntermediateCode.Operand);
		BEGIN
			IF ReusableRegister(src1) THEN IntermediateCode.InitRegister(result,src1.type,src1.registerClass, src1.register);
				UseIntermediateOperand(result);
			ELSIF ReusableRegister(src2) THEN IntermediateCode.InitRegister(result,src2.type,src2.registerClass, src2.register);
				UseIntermediateOperand(result);
			ELSE IntermediateCode.InitRegister(result,src1.type,src1.registerClass,AcquireRegister(src1.type, src1.registerClass));
			END;
		END Reuse2;

		(* Reuse2a: reuse src1 or src2 for ongoing computation if src1 or src2, respectively, is a register.
			Otherwise check if an alternative destination is available. If so, then take the alternative (which is not necessarily a register).
			If not then allocate a new register.
			Does NOT necessarily keep the content of src1 or src2 in result!
		*)
		PROCEDURE Reuse2a(VAR result: IntermediateCode.Operand; src1,src2: IntermediateCode.Operand; VAR alternative: IntermediateCode.Operand);
		BEGIN
			IF ReusableRegister(src1) THEN IntermediateCode.InitRegister(result,src1.type,src1.registerClass, src1.register);
				UseIntermediateOperand(result);
			ELSIF ReusableRegister(src2) THEN IntermediateCode.InitRegister(result,src2.type,src2.registerClass, src2.register);
				UseIntermediateOperand(result);
			ELSIF alternative.mode # IntermediateCode.Undefined THEN
				result := alternative; alternative := emptyOperand;
				UseIntermediateOperand(result);
			ELSE IntermediateCode.InitRegister(result,src1.type,src1.registerClass, AcquireRegister(src1.type, src1.registerClass));
			END;
		END Reuse2a;

		(* like reuse2 but only one source *)
		PROCEDURE Reuse1(VAR result: IntermediateCode.Operand; src1: IntermediateCode.Operand);
		BEGIN
			IF ReusableRegister(src1) THEN IntermediateCode.InitRegister(result,src1.type,src1.registerClass, src1.register);
				UseIntermediateOperand(result);
			ELSE IntermediateCode.InitRegister(result,src1.type,src1.registerClass, AcquireRegister(src1.type, src1.registerClass));
			END;
		END Reuse1;

		(* like reuse2a but only one source *)
		PROCEDURE Reuse1a(VAR result: IntermediateCode.Operand; src1: IntermediateCode.Operand; VAR alternative: IntermediateCode.Operand);
		BEGIN
			IF ReusableRegister(src1) THEN IntermediateCode.InitRegister(result,src1.type,src1.registerClass, src1.register);
				UseIntermediateOperand(result);
			ELSIF alternative.mode # IntermediateCode.Undefined THEN result := alternative; alternative := emptyOperand;
				UseIntermediateOperand(result);
			ELSE IntermediateCode.InitRegister(result,src1.type,src1.registerClass, AcquireRegister(src1.type, src1.registerClass));
			END;
		END Reuse1a;

		(* like reuse1 but guarantees that content of src1 is in result *)
		PROCEDURE ReuseCopy(VAR result: IntermediateCode.Operand; src1: IntermediateCode.Operand);
		BEGIN
			IF ReusableRegister(src1) THEN
				IntermediateCode.InitRegister(result,src1.type,src1.registerClass, src1.register);
				ASSERT((src1.mode = IntermediateCode.ModeRegister) & (src1.offset = 0));
				UseIntermediateOperand(result);
			ELSE
				IntermediateCode.InitRegister(result,src1.type,src1.registerClass, AcquireRegister(src1.type, src1.registerClass));
				Emit(Mov(position,result,src1));
			END
		END ReuseCopy;

		PROCEDURE TransferToRegister(VAR result: IntermediateCode.Operand; src: IntermediateCode.Operand);
		BEGIN
			IF ReusableRegister(src) THEN
				IntermediateCode.InitRegister(result,src.type,src.registerClass, src.register);
			ELSE
				IntermediateCode.InitRegister(result,src.type,src.registerClass, AcquireRegister(src.type, src.registerClass));
				Emit(Mov(position,result,src));
				ReleaseIntermediateOperand(src);
			END
		END TransferToRegister;

		(** labels and branches **)
		PROCEDURE NewLabel(): Label;
		VAR label: Label;
		BEGIN
			NEW(label,section); RETURN label;
		END NewLabel;

		(* EXPERIMENTAL *)
		PROCEDURE EndBasicBlock;
		VAR i: LONGINT;
		BEGIN
			i := 0;
			WHILE (availableSymbols[i].symbol # NIL) DO
				IF ~availableSymbols[i].inMemory & availableSymbols[i].inRegister THEN
					Emit(Mov(position,availableSymbols[i].memory, availableSymbols[i].register));
				END;
				IF availableSymbols[i].inRegister THEN
					ReleaseIntermediateOperand(availableSymbols[i].register);
					availableSymbols[i].inRegister := FALSE;
				END;
				availableSymbols[i].symbol := NIL;

				INC(i);
			END;
		END EndBasicBlock;

		(* EXPERIMENTAL *)
		PROCEDURE BeginBasicBlock;
		BEGIN
			ASSERT(availableSymbols[0].symbol = NIL);
		END BeginBasicBlock;

		PROCEDURE SetLabel(label: Label);
		BEGIN
			(* EXPERIMENTAL *)
			EndBasicBlock;
			BeginBasicBlock;

			label.Resolve(section.pc);
		END SetLabel;

		PROCEDURE LabelOperand(label: Label): IntermediateCode.Operand;
		BEGIN
			ASSERT(label # NIL);
			IF label.pc < 0 THEN (* label not yet set *)
				label.AddFixup(section.pc);
			END;
			RETURN IntermediateCode.Address(addressType,label.section.name,GetFingerprint(label.section.symbol), label.pc);
		END LabelOperand;

		PROCEDURE BrL(label: Label);
		BEGIN
			(* EXPERIMENTAL *)
			EndBasicBlock;

			Emit(Br(position,LabelOperand(label)));
		END BrL;

		PROCEDURE BrgeL(label: Label; left,right: IntermediateCode.Operand);
		BEGIN
			Emit(Brge(position,LabelOperand(label),left,right));
		END BrgeL;

		PROCEDURE BrltL(label: Label; left,right: IntermediateCode.Operand);
		BEGIN
			Emit(Brlt(position,LabelOperand(label),left,right));
		END BrltL;

		PROCEDURE BreqL(label: Label; left,right: IntermediateCode.Operand);
		BEGIN
			Emit(Breq(position,LabelOperand(label),left,right));
		END BreqL;

		PROCEDURE BrneL(label: Label; left,right: IntermediateCode.Operand);
		BEGIN
			Emit(Brne(position,LabelOperand(label),left,right));
		END BrneL;

		PROCEDURE Convert(VAR operand: IntermediateCode.Operand; type: IntermediateCode.Type);
		VAR new: IntermediateCode.Operand;
		BEGIN
			IF Trace THEN TraceEnter("Convert") END;
			IF IntermediateCode.TypeEquals(type,operand.type) THEN (* nothing to be done *)
			ELSIF (operand.mode = IntermediateCode.ModeRegister) THEN
				IF (type.sizeInBits = operand.type.sizeInBits) & (type.form IN IntermediateCode.Integer) & (operand.type.form IN IntermediateCode.Integer)
					& (operand.offset = 0)
				THEN
					IntermediateCode.InitRegister(new,type,IntermediateCode.GeneralPurposeRegister,operand.register);
					Emit(Conv(position,new,operand));
				ELSE
					IntermediateCode.InitRegister(new,type,IntermediateCode.GeneralPurposeRegister,AcquireRegister(type,IntermediateCode.GeneralPurposeRegister));
					Emit(Conv(position,new,operand));
					ReleaseIntermediateOperand(operand);
				END;
				operand := new;
			ELSIF (operand.mode = IntermediateCode.ModeImmediate) & (operand.symbol.name = "") & (operand.type.sizeInBits <= type.sizeInBits) & (operand.type.form IN IntermediateCode.Integer) & (type.form IN IntermediateCode.Integer) THEN
				IntermediateCode.InitImmediate(operand,type,operand.intValue);
			ELSE
				IntermediateCode.InitRegister(new,type,IntermediateCode.GeneralPurposeRegister,AcquireRegister(type,IntermediateCode.GeneralPurposeRegister));
				Emit(Conv(position,new,operand));
				ReleaseIntermediateOperand(operand);
				operand := new;
			END;
			IF Trace THEN TraceExit("Convert") END;
		END Convert;

		PROCEDURE TrapC(br: ConditionalBranch; left,right:IntermediateCode.Operand; trapNo: LONGINT);
		VAR exit: Label;
		BEGIN
			Assert((left.mode # IntermediateCode.ModeImmediate) OR (right.mode # IntermediateCode.ModeImmediate),"trap emission with two immediates");
			exit := NewLabel();
			br(exit,left,right);
			EmitTrap(position,trapNo);
			SetLabel(exit);
		END TrapC;

		(** expressions *)

		(** emit necessary runtime check for set elements **)
		PROCEDURE CheckSetElement(o: IntermediateCode.Operand);
		VAR max: IntermediateCode.Operand;
		BEGIN
			IF isUnchecked THEN RETURN END;
			IF o.mode # IntermediateCode.ModeImmediate THEN (* otherwise it's the job of the checker *)
				IntermediateCode.InitImmediate(max, setType, setType.sizeInBits (* number of bits in set *) -1);
				TrapC(BrgeL, max, o, SetElementTrap);
			END;
		END CheckSetElement;

		(** the set that a range represents **)
		PROCEDURE SetFromRange(x: SyntaxTree.RangeExpression): IntermediateCode.Operand;
		VAR
			operand: Operand;
			resultingSet, temp, size, allBits, noBits, one: IntermediateCode.Operand;
		BEGIN
			ASSERT((x.first # NIL) & (x.last # NIL)); (* ensured by the checker *)

			allBits := IntermediateCode.Immediate(setType, -1);  (* bit mask 111...11111 *)
			noBits := IntermediateCode.Immediate(setType, 0);  (* bit mask 0...0 *)
			one := IntermediateCode.Immediate(setType, 1);

			Evaluate(x, operand);

			Convert(operand.op, setType);
			Convert(operand.tag, setType);

			CheckSetElement(operand.op);
			CheckSetElement(operand.tag);

			(* create mask for lower bound
				i.e. shift 11111111 to the left by the value of the lower bound
			*)
			Reuse1(temp, operand.op);
			Emit(Shl(position,temp, allBits, operand.op));
			ReleaseIntermediateOperand(operand.op);
			operand.op := temp;

			(* create mask for upper bound
				i.e. shift 11111111 to the right by the difference between the
				upper bound and the maximum number of set elements
			*)
			IF (operand.tag.mode = IntermediateCode.ModeImmediate) & (operand.tag.symbol.name = "") THEN
				IntermediateCode.InitImmediate(operand.tag, operand.tag.type, operand.op.type.sizeInBits - 1- operand.tag.intValue);
				Reuse1(temp, operand.tag);
			ELSE
				Reuse1(temp, operand.tag);
				IntermediateCode.InitImmediate(size, operand.tag.type, operand.op.type.sizeInBits - 1);
				Emit(Sub(position,temp, size, operand.tag));
			END;
			Emit(Shr(position,temp, allBits, operand.tag));
			ReleaseIntermediateOperand(operand.tag);
			operand.tag := temp;

			Reuse2(resultingSet, operand.op, operand.tag);

			(* intersect the two masks *)
			Emit(And(position,resultingSet, operand.op, operand.tag));

			ReleaseOperand(operand);

			RETURN resultingSet
		END SetFromRange;

		(* math arrays of the form [a,b,c]
			x is a static array and thus does not provide any pointers
		*)
		PROCEDURE DesignateMathArrayExpression(x: SyntaxTree.MathArrayExpression; VAR result: Operand);
		VAR variable: SyntaxTree.Variable; index: SyntaxTree.IndexDesignator; dim: LONGINT;
			designator: SyntaxTree.Designator; i: LONGINT; element: SyntaxTree.IntegerValue;

			PROCEDURE RecursiveAssignment(x: SyntaxTree.MathArrayExpression; dim: LONGINT);
			VAR numberElements,i: LONGINT; expression: SyntaxTree.Expression;
				element: SyntaxTree.IntegerValue;
			BEGIN
				numberElements := x.elements.Length();
				expression := index.parameters.GetExpression(dim);
				element := expression(SyntaxTree.IntegerValue);
				FOR i := 0 TO numberElements-1 DO
					expression := x.elements.GetExpression(i);
					element.SetValue(i);
					IF expression IS SyntaxTree.MathArrayExpression THEN
						RecursiveAssignment(expression(SyntaxTree.MathArrayExpression),dim+1);
					ELSE
						Assign(index,expression);
					END;
				END;
			END RecursiveAssignment;

			PROCEDURE Dimension(): LONGINT;
			VAR dim: LONGINT; expression: SyntaxTree.Expression;
			BEGIN
					dim := 0;
					expression := x;
					WHILE expression IS SyntaxTree.MathArrayExpression DO
						expression := expression(SyntaxTree.MathArrayExpression).elements.GetExpression(0);
						INC(dim);
					END;
					RETURN dim;
			END Dimension;

		BEGIN
			(*static math array not providing pointers anyway *)
			variable := GetTemporaryVariable(x.type, FALSE, FALSE (* untraced *));
			designator := SyntaxTree.NewSymbolDesignator(Basic.invalidPosition,NIL,NIL, variable);
			designator.SetType(variable.type);
			dim := Dimension();
			index := SyntaxTree.NewIndexDesignator(x.position,NIL,designator, SyntaxTree.NewExpressionList());
			FOR i := 0 TO dim-1 DO
				element := SyntaxTree.NewIntegerValue(x.position,0);
				element.SetType(system.longintType);
				index.parameters.AddExpression(element);
			END;
			index.SetType(SemanticChecker.ArrayBase(x.type,dim));
			RecursiveAssignment(x,0);
			Designate(designator, result);
		END DesignateMathArrayExpression;

		(* test if e is of type type, side effect: result of evaluation of e stays in the operand *)
		PROCEDURE TypeTest(tag: IntermediateCode.Operand; type: SyntaxTree.Type; label: Label; reason: BOOLEAN; withPart: BOOLEAN);
		VAR left,right: IntermediateCode.Operand; level,offset: LONGINT; repeatL,skip: Label; originalType: SyntaxTree.Type;
		BEGIN
			type := type.resolved;
			originalType := type;
			IF type IS SyntaxTree.PointerType THEN
				type := type(SyntaxTree.PointerType).pointerBase.resolved;
			END;
			IF (type IS SyntaxTree.ObjectType) & reason THEN
				BrL(label);
			ELSE

				ASSERT(type IS SyntaxTree.RecordType);

				(*
				IntermediateCode.MakeMemory(tag,addressType); (*! already done during generation *)
				*)
				IF withPart THEN
					left := tag;
				ELSE
					ReuseCopy(left,tag);
				END;
				right := TypeDescriptorAdr(type);

				IF backend.cooperative THEN
					repeatL := NewLabel();
					IF (originalType IS SyntaxTree.PointerType) & ~type(SyntaxTree.RecordType).isObject THEN
						Emit(Mov(position,left,IntermediateCode.Memory(addressType,left,ToMemoryUnits(system,addressType.sizeInBits))));
					END;
					SetLabel(repeatL);
					IF reason THEN
						BreqL(label,left,right);
					ELSE
						skip := NewLabel();
						BreqL(skip,left,right);
					END;
					Emit(Mov(position,left,IntermediateCode.Memory(addressType,left,0)));
					BrneL(repeatL,left,nil);
					IF ~reason THEN
						BrL(label);
						SetLabel(skip);
					END;
				ELSIF meta.simple THEN
					level := type(SyntaxTree.RecordType).Level();
					(* get type desc tag of level relative to base tag *)
					offset := (meta.BaseTypesTableOffset + level) * addressType.sizeInBits;
					IntermediateCode.AddOffset(left,ToMemoryUnits(system,offset));
					IntermediateCode.MakeMemory(left,addressType);
					IF reason THEN
						BreqL(label,left,right);
					ELSE
						BrneL(label,left,right);
					END;
				ELSE
					level := type(SyntaxTree.RecordType).Level();
					(* get type desc tag of level relative to base tag *)
					offset := (meta.BaseTypesTableOffset - level) * addressType.sizeInBits;
					IntermediateCode.AddOffset(left,ToMemoryUnits(system,offset));
					IntermediateCode.MakeMemory(left,addressType);
					IF reason THEN
						BreqL(label,left,right);
					ELSE
						BrneL(label,left,right);
					END;
				END;
				IF ~withPart THEN
					ReleaseIntermediateOperand(left);
				END;
				ReleaseIntermediateOperand(right);
			END;
		END TypeTest;

		PROCEDURE Error(position: Position; CONST s: ARRAY OF CHAR);
		BEGIN
			backend.Error(module.module.sourceName,position,Streams.Invalid,s);
			IF dump # NIL THEN
				dump.String(s); dump.Ln;
			END;
		END Error;

		PROCEDURE Warning(position: Position; CONST s: ARRAY OF CHAR);
		BEGIN
			Basic.Warning(backend.diagnostics, module.module.sourceName,position, s);
			IF dump # NIL THEN
				dump.String(s); dump.Ln; dump.Update;
			END;
		END Warning;

		PROCEDURE CreateTraceModuleMethod(mod: SyntaxTree.Module);
		VAR name: Basic.SectionName; pooledName: Basic.SegmentedName; context: Context;
		VAR variable: SyntaxTree.Variable; register,op: IntermediateCode.Operand;
			operand:Operand;
		BEGIN
			Global.GetModuleName(mod,name);
			Strings.Append(name,".@Trace");
			Basic.ToSegmentedName(name, pooledName);
			context := SwitchContext(NewSection(module.allSections, Sections.CodeSection, pooledName,NIL,TRUE));
			IF dump # NIL THEN dump := section.comments END;
			IF backend.hasLinkRegister THEN
				Emit(Push(Basic.invalidPosition, lr));
			END;

			variable := mod.moduleScope.firstVariable;
			WHILE variable # NIL DO
				IF ~variable.untraced & variable.type.resolved.hasPointers THEN
					Symbol(variable, operand);
					register := operand.op;
					CallTraceMethod(register, variable.type);
					ReleaseIntermediateOperand(register);
				END;
				variable := variable.nextVariable;
			END;

			IF backend.hasLinkRegister THEN
				Emit(Pop(Basic.invalidPosition, lr));
			END;
			Basic.ToSegmentedName ("Modules.Module.@Trace",pooledName);
			IntermediateCode.InitAddress(op, addressType, pooledName , 0, 0);
			Emit(Br(position,op));
			INC(statCoopTraceModule, section.pc);
			ReturnToContext(context);
			IF dump # NIL THEN dump := section.comments END;

		END CreateTraceModuleMethod;

		PROCEDURE CallAssignPointer(CONST dst (* address *) , src (* value *): IntermediateCode.Operand);
		BEGIN
			Emit (Push(position, dst));
			Emit (Push(position, src));
			CallThis(position,"GarbageCollector","Assign", 2);
		END CallAssignPointer;

		PROCEDURE CallAssignMethod(CONST dst (* address *) , src (* address *) : IntermediateCode.Operand; type: SyntaxTree.Type);
		VAR name: Basic.SegmentedName; size: LONGINT; base: SyntaxTree.Type; op: IntermediateCode.Operand;
		BEGIN
			IF SemanticChecker.IsPointerType (type) THEN
				CallAssignPointer(dst, IntermediateCode.Memory (addressType,src,0));
			ELSIF type.IsRecordType() THEN
				Emit (Push(position,dst));
				Emit (Push(position,src));
				GetRecordTypeName (type.resolved(SyntaxTree.RecordType),name);
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Assign"));
				IntermediateCode.InitAddress(op, addressType, name , 0, 0);
				Emit(Call(position,op, ToMemoryUnits(system, 2*system.addressSize)));
			ELSIF IsStaticArray(type) THEN
				size := StaticArrayNumElements(type);
				base := StaticArrayBaseType(type);
				IF base.IsRecordType() THEN
					Emit (Push(position, IntermediateCode.Immediate (sizeType,size)));
					Emit (Push(position, dst));
					Emit (Push(position, src));
					GetRecordTypeName (base.resolved(SyntaxTree.RecordType),name);
					Basic.SuffixSegmentedName (name, Basic.MakeString ("@Array"));
					Basic.SuffixSegmentedName (name, Basic.MakeString ("@Assign"));
					IntermediateCode.InitAddress(op, addressType, name , 0, 0);
					Emit(Call(position,op,ToMemoryUnits(system, 3*system.addressSize)));
				ELSIF base.resolved IS SyntaxTree.ProcedureType THEN (* array of delegates *)
					Emit (Push(position, IntermediateCode.Immediate (sizeType,size)));
					Emit (Push(position, dst));
					Emit (Push(position, IntermediateCode.Immediate (sizeType,size)));
					Emit (Push(position, src));
					CallThis(position,"GarbageCollector","AssignDelegateArray", 4);
				ELSE
					Emit (Push(position, IntermediateCode.Immediate (sizeType,size)));
					Emit (Push(position, dst));
					Emit (Push(position, IntermediateCode.Immediate (sizeType,size)));
					Emit (Push(position, src));
					CallThis(position,"GarbageCollector","AssignPointerArray", 4);
					ASSERT(StaticArrayBaseType(type).IsPointer());
				END;
			ELSIF type.resolved IS SyntaxTree.ProcedureType THEN
				ASSERT(type.resolved(SyntaxTree.ProcedureType).isDelegate);
				Emit (Push(position, dst));
				Emit (Push(position, src));
				CallThis(position,"GarbageCollector","AssignDelegate", 2);
			ELSE HALT(100); (* missing ? *)
			END;
		END CallAssignMethod;

		PROCEDURE CreateAssignProcedure (recordType: SyntaxTree.RecordType);
		VAR name: Basic.SegmentedName;
		VAR variable: SyntaxTree.Variable; src, dst, op, ofs: IntermediateCode.Operand; recordBase: SyntaxTree.RecordType;
			parameter1, parameter2, parameter0: IntermediateCode.Operand; label: Label;
			context: Context;
		BEGIN
			parameter0 (* len *) := IntermediateCode.Memory(sizeType,sp,ToMemoryUnits(system,3*addressType.sizeInBits));
			parameter1 (* dest *) := IntermediateCode.Memory(addressType,sp,ToMemoryUnits(system,2*addressType.sizeInBits));
			parameter2 (* src *) := IntermediateCode.Memory(addressType,sp,ToMemoryUnits(system,1*addressType.sizeInBits));

			GetRecordTypeName (recordType,name);
			Basic.SuffixSegmentedName (name, Basic.MakeString ("@Assign"));
			IF module.allSections.FindByName(name) # NIL THEN RETURN END;
			context := SwitchContext(NewSection(module.allSections, Sections.CodeSection, name,NIL,TRUE));
			section.SetExported (TRUE);

			IF dump # NIL THEN dump := section.comments END;
			IF backend.hasLinkRegister THEN
				Emit(Push(Basic.invalidPosition, lr));
			END;

			variable := recordType.recordScope.firstVariable;
			WHILE variable # NIL DO
				IF variable.NeedsTrace() THEN

					dst := NewRegisterOperand (addressType);
					src := NewRegisterOperand (addressType);
					Emit (Mov(position, dst, parameter1));
					Emit (Mov(position, src, parameter2));

					IntermediateCode.AddOffset(dst,ToMemoryUnits(system,variable.offsetInBits));
					IntermediateCode.AddOffset(src,ToMemoryUnits(system,variable.offsetInBits));
					CallAssignMethod(dst, src, variable.type);
					ReleaseIntermediateOperand(src);
					ReleaseIntermediateOperand(dst);
				END;
				variable := variable.nextVariable;
			END;

			recordBase := recordType.GetBaseRecord();
			IF (recordBase # NIL) & recordBase.NeedsTrace() THEN
				IF backend.hasLinkRegister THEN
					Emit(Pop(Basic.invalidPosition, lr));
				END;
				GetRecordTypeName (recordBase,name);
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Assign"));
				IntermediateCode.InitAddress(op, addressType, name , 0, 0);
				Emit(Br(position,op));
			ELSE
				Emit(Exit(position,0,0, 0));
			END;

			INC(statCoopAssignProcedure, section.pc);
			ReturnToContext(context);

			IF ~recordType.isObject THEN
				GetRecordTypeName (recordType,name);
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Array"));
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Assign"));
				context := SwitchContext(NewSection(module.allSections, Sections.CodeSection, name,NIL,dump # NIL));
				section.SetExported (TRUE);

				dst := NewRegisterOperand (addressType);
				src := NewRegisterOperand (addressType);
				ofs := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.AlignedSizeOf(recordType)));
				Emit(Mov(position, dst, parameter1));
				Emit(Mov(position, src, parameter2));
				label := NewLabel();
				SetLabel(label);
				Emit(Push(position, dst));
				Emit(Push(position, src));
				GetRecordTypeName (recordType,name);
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Assign"));
				IntermediateCode.InitAddress(op, addressType, name , 0, 0);
				Emit(Call(position, op, 0));
				Emit(Pop(position, src));
				Emit(Pop(position, dst));
				Emit(Add(position, dst, dst, ofs));
				Emit(Add(position, src, src, ofs));
				Emit(Sub(position, parameter0, parameter0, IntermediateCode.Immediate(sizeType, 1)));
				BrneL(label, parameter0, IntermediateCode.Immediate(sizeType, 0));
				Emit(Exit(position,0,0, 0));
				ReturnToContext(context);
			END;
			IF dump # NIL THEN dump := section.comments END;
		END CreateAssignProcedure;

		PROCEDURE CallTraceMethod(CONST register: IntermediateCode.Operand; type: SyntaxTree.Type);
		VAR name: Basic.SegmentedName; op: IntermediateCode.Operand; size: LONGINT; base: SyntaxTree.Type; skip: Label;
		BEGIN
			IF IsUnsafePointer (type) THEN
				skip := NewLabel();
				IntermediateCode.InitRegister(op, addressType, IntermediateCode.GeneralPurposeRegister, register.register);
				Emit (Mov (position, op, IntermediateCode.Memory (addressType,register,0)));
				BreqL (skip, op, nil);
				CallTraceMethod (op,type.resolved(SyntaxTree.PointerType).pointerBase);
				SetLabel (skip);
			ELSIF SemanticChecker.IsPointerType (type) THEN
				Emit (Push(position, IntermediateCode.Memory (addressType,register,0)));
				CallThis(position,"GarbageCollector","Mark", 1);
			ELSIF type.IsRecordType() THEN
				Emit (Push(position,register));
				GetRecordTypeName (type.resolved(SyntaxTree.RecordType),name);
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Trace"));
				IntermediateCode.InitAddress(op, addressType, name , 0, 0);
				Emit(Call(position,op, ToMemoryUnits(system, system.addressSize)));
			ELSIF IsStaticArray(type) THEN
				size := StaticArrayNumElements(type);
				base := StaticArrayBaseType(type);
				IF base.IsRecordType() THEN
					Emit (Push(position, IntermediateCode.Immediate (sizeType,size)));
					Emit (Push(position, register));
					GetRecordTypeName (base.resolved(SyntaxTree.RecordType), name);
					Basic.SuffixSegmentedName (name, Basic.MakeString ("@Array"));
					Basic.SuffixSegmentedName (name, Basic.MakeString ("@Trace"));
					IntermediateCode.InitAddress(op, addressType, name , 0, 0);
					Emit(Call(position, op, ToMemoryUnits(system, system.addressSize*2)));
				ELSIF base.resolved IS SyntaxTree.ProcedureType THEN (* array of delegates *)
					Emit (Push(position, IntermediateCode.Immediate (sizeType,size)));
					Emit (Push(position, register));
					CallThis(position,"GarbageCollector","MarkDelegateArray", 2);
				ELSE
					Emit (Push(position, IntermediateCode.Immediate (sizeType,size)));
					Emit (Push(position, register));
					CallThis(position,"GarbageCollector","MarkPointerArray", 2);
					ASSERT(base.IsPointer());
				END;
			ELSIF type.resolved IS SyntaxTree.ProcedureType THEN
				Emit (Push(position, IntermediateCode.Memory (addressType,register,ToMemoryUnits(system,addressType.sizeInBits))));
				CallThis(position,"GarbageCollector","Mark", 1);
			ELSE HALT(100); (* missing ? *)
			END;
		END CallTraceMethod;

		PROCEDURE CreateTraceMethod (recordType: SyntaxTree.RecordType);
		VAR name: Basic.SegmentedName; variable: SyntaxTree.Variable; register,op,ofs: IntermediateCode.Operand; recordBase: SyntaxTree.RecordType;
			parameter0, parameter1: IntermediateCode.Operand; label: Label; context: Context;
		BEGIN
			parameter0 (* size *) := IntermediateCode.Memory(sizeType,sp,ToMemoryUnits(system,2*addressType.sizeInBits));
			parameter1 (* address *) := IntermediateCode.Memory(addressType,sp,ToMemoryUnits(system,1*addressType.sizeInBits));
			GetRecordTypeName (recordType,name);
			Basic.SuffixSegmentedName (name, Basic.MakeString ("@Trace"));
			IF module.allSections.FindByName(name) # NIL THEN RETURN END;
			context := SwitchContext(NewSection(module.allSections, Sections.CodeSection, name,NIL,dump # NIL));
			section.SetExported (TRUE);

			IF dump # NIL THEN dump := section.comments END;

			IF backend.hasLinkRegister THEN
				Emit(Push(Basic.invalidPosition, lr));
			END;

			variable := recordType.recordScope.firstVariable;
			WHILE variable # NIL DO
				IF variable.NeedsTrace() THEN
					register := NewRegisterOperand (addressType);
					Emit (Mov(position,register,parameter1));
					IntermediateCode.AddOffset(register,ToMemoryUnits(system,variable.offsetInBits));
					IF recordType.isObject & ((recordType.pointerType = NIL) OR ~recordType.pointerType.isPlain) THEN
						IntermediateCode.AddOffset(register,BaseObjectTypeSize * ToMemoryUnits(system,addressType.sizeInBits));
					END;
					CallTraceMethod(register, variable.type);
					ReleaseIntermediateOperand(register);
				END;
				variable := variable.nextVariable;
			END;

			recordBase := recordType.GetBaseRecord();
			WHILE (recordBase # NIL) & ~recordBase.hasPointers DO
				recordBase := recordBase.GetBaseRecord();
			END;
			IF recordBase # NIL THEN
				IF backend.hasLinkRegister THEN
					Emit(Pop(Basic.invalidPosition, lr));
				END;
				GetRecordTypeName (recordBase,name);
				IF HasExplicitTraceMethod (recordBase) THEN
					Basic.SuffixSegmentedName (name, Basic.MakeString ("Trace"));
				ELSE
					Basic.SuffixSegmentedName (name, Basic.MakeString ("@Trace"));
				END;
				IntermediateCode.InitAddress(op, addressType, name , 0, 0);
				Emit(Br(position,op));
			ELSIF (recordType.pointerType # NIL) & recordType.pointerType.isPlain THEN
				Emit(Exit(position,0,0,0));
			ELSE
				IF backend.hasLinkRegister THEN
					Emit(Pop(Basic.invalidPosition, lr));
				END;
				IF recordType.isObject THEN
					Basic.ToSegmentedName ("BaseTypes.Object",name);
				ELSE
					Basic.ToSegmentedName ("BaseTypes.Record",name);
				END;
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Trace"));
				IntermediateCode.InitAddress(op, addressType, name , 0, 0);
				Emit(Br(position,op));
			END;

			INC(statCoopTraceMethod, section.pc);
			ReturnToContext(context);

			IF ~recordType.isObject THEN
				GetRecordTypeName (recordType,name);
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Pointer"));
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Trace"));
				context := SwitchContext(NewSection(module.allSections, Sections.CodeSection, name,NIL,dump # NIL));
				section.SetExported (TRUE);

				IF dump # NIL THEN dump := section.comments END;

				register := NewRegisterOperand (addressType);
				Emit (Mov(position,register,IntermediateCode.Memory(addressType,sp,ToMemoryUnits(system,addressType.sizeInBits))));
				IF (recordType.pointerType = NIL) OR ~recordType.pointerType.isPlain THEN
					IntermediateCode.AddOffset(register,BaseRecordTypeSize * ToMemoryUnits(system,addressType.sizeInBits));
				END;

				Emit (Push(position,register));
				GetRecordTypeName (recordType,name);
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Trace"));
				IntermediateCode.InitAddress(op, addressType, name , 0, 0);
				Emit(Call(position,op, ToMemoryUnits(system, system.addressSize)));
				ReleaseIntermediateOperand(register);
				Emit(Exit(position,0,0,0));
				ReturnToContext(context);

				GetRecordTypeName (recordType,name);
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Array"));
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Trace"));
				context := SwitchContext(NewSection(module.allSections, Sections.CodeSection, name,NIL,dump # NIL));
				section.SetExported (TRUE);

				register := NewRegisterOperand (addressType);
				ofs := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.AlignedSizeOf(recordType)));
				Emit(Mov(position, register, parameter1));
				label := NewLabel();
				SetLabel(label);
				Emit(Push(position, register));
				GetRecordTypeName (recordType,name);
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Trace"));
				IntermediateCode.InitAddress(op, addressType, name , 0, 0);
				Emit(Call(position, op, 0));
				Emit(Pop(position, register));
				Emit(Add(position, register, register, ofs));
				Emit(Sub(position, parameter0, parameter0, IntermediateCode.Immediate(sizeType, 1)));
				BrneL(label, parameter0, IntermediateCode.Immediate(sizeType, 0));
				Emit(Exit(position,0,0,0));
				ReturnToContext(context);
			END;

			IF dump # NIL THEN dump := section.comments END;
		END CreateTraceMethod;

		PROCEDURE CreateResetProcedure (recordType: SyntaxTree.RecordType);
		VAR name: Basic.SegmentedName;
		VAR variable: SyntaxTree.Variable; dst, op, ofs: IntermediateCode.Operand; recordBase: SyntaxTree.RecordType;
			parameter1, parameter0: IntermediateCode.Operand; label: Label;
			context: Context;
		BEGIN
			IF recordType.isObject THEN RETURN END;
			parameter0 (* len *) := IntermediateCode.Memory(sizeType,sp,ToMemoryUnits(system,2*addressType.sizeInBits));
			parameter1 (* dest *) := IntermediateCode.Memory(addressType,sp,ToMemoryUnits(system,1*addressType.sizeInBits));

			GetRecordTypeName (recordType,name);
			Basic.SuffixSegmentedName (name, Basic.MakeString ("@Reset"));
			IF module.allSections.FindByName(name) # NIL THEN RETURN END;
			context := SwitchContext(NewSection(module.allSections, Sections.CodeSection, name,NIL,dump # NIL));
			section.SetExported (TRUE);

			IF dump # NIL THEN dump := section.comments END;

			IF backend.hasLinkRegister THEN
				Emit(Push(Basic.invalidPosition, lr));
			END;

			variable := recordType.recordScope.firstVariable;
			WHILE variable # NIL DO
				IF variable.NeedsTrace() THEN
					dst := NewRegisterOperand (addressType);
					Emit (Mov(position, dst, parameter1));
					IntermediateCode.AddOffset(dst,ToMemoryUnits(system,variable.offsetInBits));
					IF recordType.isObject & ((recordType.pointerType = NIL) OR ~recordType.pointerType.isPlain) THEN
						IntermediateCode.AddOffset(dst,BaseObjectTypeSize * ToMemoryUnits(system,addressType.sizeInBits));
					END;
					CallResetProcedure(dst, nil, variable.type);
					ReleaseIntermediateOperand(dst);
				END;
				variable := variable.nextVariable;
			END;

			recordBase := recordType.GetBaseRecord();
			IF (recordBase # NIL) & recordBase.NeedsTrace() THEN
				IF backend.hasLinkRegister THEN
					Emit(Pop(Basic.invalidPosition, lr));
				END;
				GetRecordTypeName (recordBase,name);
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Reset"));
				IntermediateCode.InitAddress(op, addressType, name , 0, 0);
				Emit(Br(position,op));
			ELSE
				Emit(Exit(position,0,0, 0));
			END;

			INC(statCoopResetProcedure, section.pc);
			ReturnToContext(context);

			GetRecordTypeName (recordType,name);
			Basic.SuffixSegmentedName (name, Basic.MakeString ("@Array"));
			Basic.SuffixSegmentedName (name, Basic.MakeString ("@Reset"));
			context := SwitchContext(NewSection(module.allSections, Sections.CodeSection, name,NIL,dump # NIL));
			section.SetExported (TRUE);

			dst := NewRegisterOperand (addressType);
			ofs := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.AlignedSizeOf(recordType)));
			Emit(Mov(position, dst, parameter1));
			label := NewLabel();
			SetLabel(label);
			Emit(Push(position, dst));
			GetRecordTypeName (recordType,name);
			Basic.SuffixSegmentedName (name, Basic.MakeString ("@Reset"));
			IntermediateCode.InitAddress(op, addressType, name , 0, 0);
			Emit(Call(position, op, 0));
			Emit(Pop(position, dst));
			Emit(Add(position, dst, dst, ofs));
			Emit(Sub(position, parameter0, parameter0, IntermediateCode.Immediate(sizeType, 1)));
			BrneL(label, parameter0, IntermediateCode.Immediate(sizeType, 0));
			Emit(Exit(position,0,0, 0));
			ReturnToContext(context);

			IF dump # NIL THEN dump := section.comments END;
		END CreateResetProcedure;

		PROCEDURE CreateResetMethod (scope: SyntaxTree.ProcedureScope);
		VAR name: Basic.SegmentedName; context: Context;
		BEGIN
			GetCodeSectionNameForSymbol(scope.ownerProcedure, name);
			Basic.SuffixSegmentedName (name, Basic.MakeString ("@Reset"));
			context := SwitchContext(NewSection(module.allSections, Sections.CodeSection, name,NIL,dump # NIL));
			IF dump # NIL THEN dump := section.comments END;
			IF backend.hasLinkRegister THEN
				Emit(Push(Basic.invalidPosition, lr));
			END;
			Emit(Push(position,fp));
			Emit(Mov(position,fp, IntermediateCode.Memory(addressType,sp,ToMemoryUnits(system,addressType.sizeInBits * 2))));
			ResetVariables(scope);
			Emit(Pop(position,fp));
			Emit(Exit(position,0,0, 0));
			ReturnToContext(context);
			IF dump # NIL THEN dump := section.comments END;
		END CreateResetMethod;

		PROCEDURE CallResetProcedure(dest, tag: IntermediateCode.Operand; type: SyntaxTree.Type);
		VAR base: SyntaxTree.Type; op, size: IntermediateCode.Operand; name: Basic.SegmentedName;
		BEGIN
			IF SemanticChecker.IsPointerType (type) THEN
				Emit (Push(position, dest));
				CallThis(position,"GarbageCollector","Reset", 1);
			ELSIF type.IsRecordType() THEN
				Emit (Push(position, dest));
				GetRecordTypeName (type.resolved(SyntaxTree.RecordType),name);
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Reset"));
				IntermediateCode.InitAddress(op, addressType, name , 0, 0);
				Emit(Call(position,op, ToMemoryUnits(system, system.addressSize)));
			ELSIF type.resolved IS SyntaxTree.ArrayType THEN
				size := GetArrayLength(type, tag);
				base := ArrayBaseType(type);
				IF base.IsRecordType() THEN
					Emit (Push(position, size));
					Emit (Push(position, dest));
					GetRecordTypeName (base.resolved(SyntaxTree.RecordType),name);
					Basic.SuffixSegmentedName (name, Basic.MakeString ("@Array"));
					Basic.SuffixSegmentedName (name, Basic.MakeString ("@Reset"));
					IntermediateCode.InitAddress(op, addressType, name , 0, 0);
					Emit(Call(position,op,ToMemoryUnits(system, 2*system.addressSize)));
				ELSIF base.resolved IS SyntaxTree.ProcedureType THEN (* array of delegates *)
					Emit (Push(position, size));
					Emit (Push(position, dest));
					CallThis(position,"GarbageCollector","ResetDelegateArray", 2);
				ELSE
					Emit (Push(position, size));
					Emit (Push(position, dest));
					CallThis(position,"GarbageCollector","ResetArray", 2);
					ASSERT(ArrayBaseType(type).IsPointer());
				END;
				ReleaseIntermediateOperand(size);
			ELSIF type.resolved IS SyntaxTree.ProcedureType THEN
				ASSERT(type.resolved(SyntaxTree.ProcedureType).isDelegate);
				Emit (Push(position, dest));
				CallThis(position,"GarbageCollector","ResetDelegate", 1);
			ELSE HALT(100); (* missing ? *)
			END;
		END CallResetProcedure;

		PROCEDURE ResetVariables (scope: SyntaxTree.ProcedureScope);
		VAR variable: SyntaxTree.Variable; parameter: SyntaxTree.Parameter; previousScope: SyntaxTree.Scope; prevOffset: SIZE; pc: LONGINT;

			PROCEDURE Reset (symbol: SyntaxTree.Symbol);
			VAR operand: Operand;
			BEGIN
				Symbol (symbol, operand);
				CallResetProcedure(operand.op, operand.tag, symbol.type.resolved);
				ReleaseOperand(operand);
			END Reset;

		BEGIN
			previousScope := currentScope;
			currentScope := scope;
			pc := section.pc;
			prevOffset := MAX(SIZE);
			variable := scope.firstVariable;
			WHILE variable # NIL DO
				IF variable.NeedsTrace() & (variable.offsetInBits # prevOffset) (* multiple temporaries *) THEN
					Reset (variable);
					prevOffset := variable.offsetInBits;
				END;
				variable := variable.nextVariable;
			END;
			parameter := scope.ownerProcedure.type(SyntaxTree.ProcedureType).firstParameter;
			WHILE parameter # NIL DO
				IF parameter.NeedsTrace() & ~IsVariableParameter(parameter) & (parameter.kind # SyntaxTree.ConstParameter) THEN
					Reset (parameter);
				END;
				parameter := parameter.nextParameter;
			END;
				INC(statCoopResetVariables, section.pc - pc);
				currentScope := previousScope;
		END ResetVariables;
		
		PROCEDURE CreateProcedureDescriptor (procedure: SyntaxTree.Procedure);
		VAR name: Basic.SegmentedName; op: IntermediateCode.Operand; context: Context;
		BEGIN
			GetCodeSectionNameForSymbol(procedure, name);
			Basic.SuffixSegmentedName (name, Basic.MakeString ("@StackDescriptor"));
			context := SwitchContext(NewSection(module.allSections, Sections.ConstSection, name,NIL,dump # NIL));
			IF dump # NIL THEN dump := section.comments END;
			Basic.ToSegmentedName ("BaseTypes.StackFrame",name);

			IntermediateCode.InitAddress(op, addressType, name , 0, 0);
			Emit(Data(position,op));
			Emit(Data(position,nil));

			IF HasPointers (procedure.procedureScope) THEN
				GetCodeSectionNameForSymbol(procedure, name);
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Reset"));
			ELSE
				Basic.ToSegmentedName ("BaseTypes.StackFrame.Reset",name);
			END;
			IntermediateCode.InitAddress(op, addressType, name , 0, 0);
			Emit(Data(position,op));
			ReturnToContext(context);
			IF dump # NIL THEN dump := section.comments END;
		END CreateProcedureDescriptor;

		PROCEDURE AddImport(CONST moduleName: ARRAY OF CHAR; VAR module: SyntaxTree.Module; force: BOOLEAN): BOOLEAN;
		VAR import: SyntaxTree.Import;
			s: Basic.MessageString;
			selfName: SyntaxTree.IdentifierString;
		BEGIN
			moduleScope.ownerModule.GetName(selfName);
			IF (moduleName = selfName) & (moduleScope.ownerModule.context = Global.A2Name) THEN
				module := moduleScope.ownerModule
			ELSE
				import := moduleScope.ImportByModuleName(SyntaxTree.NewIdentifier(moduleName),SyntaxTree.NewIdentifier("A2"));

				IF import = NIL THEN
					import := SyntaxTree.NewImport(Basic.invalidPosition,SyntaxTree.NewIdentifier(moduleName),SyntaxTree.NewIdentifier(moduleName),FALSE);

					import.SetContext(SyntaxTree.NewIdentifier("A2"));
					IF ~checker.AddImport(moduleScope.ownerModule,import) THEN
						s := "Module ";
						Strings.Append(s,moduleName);
						Strings.Append(s," cannot be imported.");
						IF force THEN
							Error(position,s);
						ELSIF canBeLoaded THEN
							IF WarningDynamicLoading THEN
								Strings.Append(s, "=> no dynamic linking.");
								Warning(position, s);
							END;
							canBeLoaded := FALSE;
						END;
						RETURN FALSE
					ELSE
						SELF.module.imports.AddName(moduleName)
					END;
				ELSIF import.module = NIL THEN (* already tried *)
					RETURN FALSE
				END;
				module := import.module;
			END;
			RETURN TRUE
		END AddImport;

		(* needed for old binary object file format*)
		PROCEDURE EnsureSymbol(CONST moduleName,procedureName: SyntaxTree.IdentifierString);
		VAR r: Operand; procedure: SyntaxTree.Procedure; module: SyntaxTree.Module; s: ARRAY 128 OF CHAR; fp: Basic.Fingerprint;
		BEGIN
			IF AddImport(moduleName,module,TRUE) THEN
				procedure := module.moduleScope.FindProcedure(SyntaxTree.NewIdentifier(procedureName));
				IF procedure = NIL THEN
					s := "Instruction not supported on target, emulation procedure ";
					Strings.Append(s,moduleName);
					Strings.Append(s,".");
					Strings.Append(s,procedureName);
					Strings.Append(s," not present");
					Error(position,s);
				ELSE
					StaticCallOperand(procedure,r);
					ReleaseOperand(r);
					fp := GetFingerprint(procedure);
				END;
			END;
		END EnsureSymbol;

		PROCEDURE ConditionValue(x: SyntaxTree.Expression): Operand;
		VAR trueL, exitL: Label; op: Operand;
		BEGIN
			InitOperand(op,ModeValue);
			trueL := NewLabel();
			exitL := NewLabel();
			Condition(x,trueL,TRUE);
			IntermediateCode.InitRegister(op.op,IntermediateCode.GetType(system,x.type),IntermediateCode.GeneralPurposeRegister,AcquireRegister(IntermediateCode.GetType(system,x.type),IntermediateCode.GeneralPurposeRegister));
			Emit(Mov(position,op.op,false));
			BrL(exitL);
			SetLabel(trueL);
			Emit(MovReplace(position,op.op,true));
			SetLabel(exitL);
			RETURN op;
		END ConditionValue;

		PROCEDURE GetDynamicSize(type: SyntaxTree.Type; tag: IntermediateCode.Operand):IntermediateCode.Operand;
		VAR size: LONGINT;
			PROCEDURE GetArraySize(type: SyntaxTree.ArrayType; offset: LONGINT):IntermediateCode.Operand;
			VAR baseType: SyntaxTree.Type; size: LONGINT; sizeOperand,len,res: IntermediateCode.Operand;
			BEGIN
				ASSERT(type.form = SyntaxTree.Open);
				baseType := type.arrayBase.resolved;
				IF IsOpenArray(baseType) THEN
					sizeOperand := GetArraySize(baseType(SyntaxTree.ArrayType),offset+system.addressSize);
				ELSE
					size := ToMemoryUnits(system,system.AlignedSizeOf(baseType));
					sizeOperand :=  IntermediateCode.Immediate(addressType,size);
				END;
				len := tag;
				IntermediateCode.AddOffset(len,ToMemoryUnits(system,offset));
				IntermediateCode.MakeMemory(len,addressType);
				UseIntermediateOperand(len);
				Reuse2(res,sizeOperand,len);
				Emit(Mul(position,res,sizeOperand,len));
				ReleaseIntermediateOperand(sizeOperand); ReleaseIntermediateOperand(len);
				RETURN res
			END GetArraySize;

		BEGIN
			type := type.resolved;
			IF IsOpenArray(type)  THEN
				IF tag.mode = IntermediateCode.ModeImmediate THEN (* special rule for winapi/c  arrays *)
					RETURN tag
				ELSE
					RETURN  GetArraySize(type.resolved(SyntaxTree.ArrayType),0)
				END;
			ELSE
				size := ToMemoryUnits(system,system.SizeOf(type));
				RETURN IntermediateCode.Immediate(addressType,size)
			END;
		END GetDynamicSize;

		PROCEDURE GetArrayLength(type: SyntaxTree.Type; tag: IntermediateCode.Operand):IntermediateCode.Operand;

			PROCEDURE GetLength(type: SyntaxTree.ArrayType; offset: LONGINT):IntermediateCode.Operand;
			VAR baseType: SyntaxTree.Type; sizeOperand,len,res: IntermediateCode.Operand;
			BEGIN
				ASSERT(type.form = SyntaxTree.Open);
				baseType := type.arrayBase.resolved;
				IF IsOpenArray(baseType) THEN
					sizeOperand := GetLength(baseType(SyntaxTree.ArrayType),offset+system.addressSize);
				ELSE
					sizeOperand :=  IntermediateCode.Immediate(addressType,StaticArrayNumElements(baseType));
				END;
				len := tag;
				IntermediateCode.AddOffset(len,ToMemoryUnits(system,offset));
				IntermediateCode.MakeMemory(len,addressType);
				UseIntermediateOperand(len);
				Reuse2(res,sizeOperand,len);
				Emit(Mul(position,res,sizeOperand,len));
				ReleaseIntermediateOperand(sizeOperand); ReleaseIntermediateOperand(len);
				RETURN res
			END GetLength;

		BEGIN
			type := type.resolved;
			IF IsOpenArray(type)   THEN
				ASSERT(tag.mode # IntermediateCode.ModeImmediate);
				RETURN  GetLength(type.resolved(SyntaxTree.ArrayType),0)
			ELSIF type IS SyntaxTree.StringType THEN
				RETURN tag;
			ELSE
				RETURN IntermediateCode.Immediate(addressType,StaticArrayNumElements(type))
			END;
		END GetArrayLength;

		PROCEDURE GetSizeFromTag(tag: IntermediateCode.Operand): IntermediateCode.Operand;
		VAR result: IntermediateCode.Operand;
		BEGIN
			IF backend.cooperative THEN
				MakeMemory(result, tag, addressType, ToMemoryUnits(system,system.addressSize));
			ELSE
				MakeMemory(result, tag, addressType, 0);
			END;
			RETURN result
		END GetSizeFromTag;

		PROCEDURE GetArrayOfBytesSize(e: SyntaxTree.Expression; tag: IntermediateCode.Operand): IntermediateCode.Operand;
		VAR parameter: SyntaxTree.Parameter;
		BEGIN
			IF (e IS SyntaxTree.SymbolDesignator) & (e(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Parameter) THEN
				parameter := e(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Parameter);
				IF (parameter.kind IN {SyntaxTree.VarParameter,SyntaxTree.ConstParameter}) & (parameter.type.resolved IS SyntaxTree.RecordType) THEN RETURN GetSizeFromTag(tag) END;
			ELSIF e IS SyntaxTree.DereferenceDesignator THEN
				IF (e.type.resolved IS SyntaxTree.RecordType) THEN RETURN GetSizeFromTag(tag) END;
			END;
			RETURN GetDynamicSize(e.type, tag);
		END GetArrayOfBytesSize;

		(*
		to find imported symbol. not needed ?
		PROCEDURE SymbolByName(CONST moduleName, symbolName: ARRAY OF CHAR): SyntaxTree.Symbol;
		VAR importedModule: SyntaxTree.Module; symbol: SyntaxTree.Symbol;
		BEGIN
			IF AddImport(moduleName,importedModule,FALSE) THEN
				symbol := importedModule.moduleScope.FindSymbol(SyntaxTree.NewIdentifier(symbolName));
				RETURN symbol
			ELSE
				RETURN NIL
			END
		END SymbolByName;
		*)

		PROCEDURE GetRuntimeProcedure(CONST moduleName, procedureName: ARRAY OF CHAR; VAR procedure: SyntaxTree.Procedure; force: BOOLEAN): BOOLEAN;
		VAR runtimeModule: SyntaxTree.Module; s: Basic.MessageString;
		BEGIN
			IF AddImport(moduleName,runtimeModule,force) THEN
				procedure := runtimeModule.moduleScope.FindProcedure(SyntaxTree.NewIdentifier(procedureName));
				IF procedure = NIL THEN
					s := "Procedure ";
					Strings.Append(s,moduleName);
					Strings.Append(s,".");
					Strings.Append(s,procedureName);
					Strings.Append(s," not present");
					Error(position,s);
					RETURN FALSE
				ELSE
					RETURN TRUE
				END;
			ELSE RETURN FALSE
			END;
		END GetRuntimeProcedure;

		PROCEDURE GetTypeDescriptor(CONST moduleName, typeName: ARRAY OF CHAR; VAR name: Basic.SegmentedName): SyntaxTree.Symbol;
		VAR importedModule: SyntaxTree.Module; source: IntermediateCode.Section; symbol: SyntaxTree.Symbol;
			s: Basic.MessageString;
		BEGIN
			Basic.InitSegmentedName(name);
			name[0] := Basic.MakeString(moduleName);
			name[1] := Basic.MakeString(typeName);
			name[2] := -1;

			IF AddImport(moduleName,importedModule, FALSE) THEN
				symbol := importedModule.moduleScope.FindTypeDeclaration(SyntaxTree.NewIdentifier(typeName));
				IF symbol = NIL THEN
					s := "type  ";
					Strings.Append(s,moduleName);
					Strings.Append(s,".");
					Strings.Append(s,typeName);
					Strings.Append(s," not present");
					Error(position,s);
				END;
			ELSE symbol := NIL;
			END;
			IF importedModule = moduleScope.ownerModule THEN
				source := NewSection(module.allSections, Sections.ConstSection, name, symbol, commentPrintout # NIL);
			ELSE
				source := NewSection(module.importedSections, Sections.ConstSection, name, symbol, commentPrintout # NIL);
			END;
			RETURN symbol
		END GetTypeDescriptor;

		(* Call a runtime procedure.  If numberParameters >= 0 then the procedure may be called without module import. Otherwise the signature has to be inferred from the import. *)
		PROCEDURE CallThisChecked(position: Position; CONST moduleName, procedureName: ARRAY OF CHAR; numberParameters: LONGINT; checkNumParameters: BOOLEAN);
		VAR procedure: SyntaxTree.Procedure; result: Operand; reg: IntermediateCode.Operand; source: IntermediateCode.Section;
			pooledName: Basic.SegmentedName; size: LONGINT;
		BEGIN
			IF GetRuntimeProcedure(moduleName,procedureName,procedure,numberParameters < 0) THEN (* ready for dynamic linking *)
				StaticCallOperand(procedure,result);
				IF numberParameters < 0 THEN
					size := ProcParametersSize(procedure);
				ELSE
					size := ToMemoryUnits(system,numberParameters * system.addressSize);
					IF checkNumParameters & (size # ProcParametersSize(procedure)) THEN
						Error(position,"runtime call parameter count mismatch");
					END;
				END;
				Emit(Call(position, result.op, size));
				ReleaseOperand(result);
			ELSE (* only static linking possible *)
				ASSERT(numberParameters >= 0);
				Basic.InitSegmentedName(pooledName);
				pooledName[0] := Basic.MakeString(moduleName);
				pooledName[1] := Basic.MakeString(procedureName);
				pooledName[2] := -1;
				source := NewSection(module.importedSections, Sections.CodeSection, pooledName, NIL,commentPrintout # NIL);
				IntermediateCode.InitAddress(reg, addressType, pooledName , 0, 0);
				Emit(Call(position,reg, ToMemoryUnits(system,numberParameters * system.addressSize)));
			END;
		END CallThisChecked;

		(* Call a runtime procedure.  If numberParameters >= 0 then the procedure may be called without module import. Otherwise the signature has to be inferred from the import. *)
		PROCEDURE CallThis(position: Position; CONST moduleName, procedureName: ARRAY OF CHAR; numberParameters: LONGINT);
		BEGIN
			CallThisChecked(position, moduleName, procedureName, numberParameters,TRUE);
		END CallThis;

		PROCEDURE CompareString(br: ConditionalBranch; label: Label; leftExpression,rightExpression: SyntaxTree.Expression);
		VAR
			left,right: Operand;
			leftSize, rightSize: IntermediateCode.Operand;
			saved: RegisterEntry;
			reg: IntermediateCode.Operand;
			procedureName: SyntaxTree.IdentifierString;
		BEGIN
			procedureName := "CompareString";

			SaveRegisters();ReleaseUsedRegisters(saved);
			Designate(leftExpression,left);
			leftSize := GetDynamicSize(leftExpression.type,left.tag);
			Emit(Push(position,leftSize));
			ReleaseIntermediateOperand(leftSize);
			Emit(Push(position,left.op));
			ReleaseOperand(left);

			Designate(rightExpression,right);
			rightSize := GetDynamicSize(rightExpression.type,right.tag);
			Emit(Push(position,rightSize));
			ReleaseIntermediateOperand(rightSize);
			Emit(Push(position,right.op));
			ReleaseOperand(right);

			CallThis(position,builtinsModuleName,procedureName, 4);

			IntermediateCode.InitRegister(reg,int8,IntermediateCode.GeneralPurposeRegister,AcquireRegister(int8,IntermediateCode.GeneralPurposeRegister));
			Emit(Result(position,reg));
			RestoreRegisters(saved);
			br(label,reg,IntermediateCode.Immediate(int8,0));
			ReleaseIntermediateOperand(reg);
		END CompareString;

		PROCEDURE CopyString(leftExpression,rightExpression: SyntaxTree.Expression);
		VAR
			left,right: Operand;
			leftSize, rightSize: IntermediateCode.Operand;
			saved: RegisterEntry;
			procedureName: SyntaxTree.IdentifierString;
		BEGIN
			procedureName := "CopyString";

			SaveRegisters();ReleaseUsedRegisters(saved);
			Designate(leftExpression,left);
			leftSize := GetDynamicSize(leftExpression.type,left.tag);
			Emit(Push(position,leftSize));
			ReleaseIntermediateOperand(leftSize);
			Emit(Push(position,left.op));
			ReleaseOperand(left);

			Designate(rightExpression,right);
			rightSize := GetDynamicSize(rightExpression.type,right.tag);
			Emit(Push(position,rightSize));
			ReleaseIntermediateOperand(rightSize);
			Emit(Push(position,right.op));
			ReleaseOperand(right);

			CallThis(position,builtinsModuleName,procedureName,4);
			RestoreRegisters(saved);
		END CopyString;

		PROCEDURE DesignateConversion(x: SyntaxTree.Conversion; VAR result: Operand);
		VAR old: Operand; dest: IntermediateCode.Operand; componentType: SyntaxTree.Type;
		BEGIN
			IF Trace THEN TraceEnter("DesignateConversion") END;

			ASSERT(~(x.expression.type.resolved IS SyntaxTree.RangeType));

			dest := destination; destination := emptyOperand;
			Evaluate(x.expression,old);
			InitOperand(result,ModeValue);

			result.op := old.op;
			ASSERT(result.op.mode # 0);
			IF x.type.resolved IS SyntaxTree.ComplexType THEN
				(* convert TO a complex number *)
				componentType := x.type.resolved(SyntaxTree.ComplexType).componentType;
				Convert(result.op,IntermediateCode.GetType(system, componentType));
				ASSERT(result.op.mode # 0);
				IF x.expression.type.resolved IS SyntaxTree.ComplexType THEN
					(* convert FROM a complex number TO a complex number*)
					result.tag := old.tag;
					ASSERT(result.tag.mode # 0);
					Convert(result.tag,IntermediateCode.GetType(system, componentType));
					ASSERT(result.tag.mode # 0)
				ELSE
					ASSERT(componentType IS SyntaxTree.FloatType); (* this excludes complex types based on integer types *)
					result.tag := IntermediateCode.FloatImmediate(IntermediateCode.GetType(system, componentType), 0); (* the imaginary part is set to 0 *)
				END
			ELSE
				Convert(result.op,IntermediateCode.GetType(system,x.type));
				ASSERT(result.op.mode # 0);

				result.tag := old.tag; (*! probably never used *)
			END;

			destination := dest;
			IF Trace THEN TraceExit("DesignateConversion") END;
		END DesignateConversion;

		(** designators (expressions) *)

		PROCEDURE DesignateSymbolDesignator(x: SyntaxTree.SymbolDesignator; VAR result: Operand);
		VAR ownerType, designatorType: SyntaxTree.RecordType;
		BEGIN
			IF Trace THEN TraceEnter("DesignateSymbolDesignator") END;
			IF x.left # NIL THEN Designate(x.left, result) END;
			Symbol(x.symbol,result);
			IF backend.cooperative & (x.symbol IS SyntaxTree.Variable) & (x.symbol.scope # NIL) & (x.symbol.scope IS SyntaxTree.RecordScope) THEN
				ASSERT ((x.left # NIL) & (x.left.type.resolved IS SyntaxTree.RecordType));
				ownerType := x.symbol.scope(SyntaxTree.RecordScope).ownerRecord;
				designatorType := x.left.type.resolved(SyntaxTree.RecordType);
				IF ~ownerType.isObject & designatorType.isObject & ~designatorType.pointerType.isPlain THEN
					IntermediateCode.AddOffset(result.op,BaseRecordTypeSize * ToMemoryUnits(system,addressType.sizeInBits));
				END;
			END;
			IF Trace THEN TraceExit("DesignateSymbolDesignator") END;
		END DesignateSymbolDesignator;

		PROCEDURE BoundCheck(index,length: IntermediateCode.Operand);
		BEGIN
			IF isUnchecked THEN RETURN END;
			IF tagsAvailable THEN
				TrapC(BrltL,index,length,IndexCheckTrap);
			END;
		END BoundCheck;

		PROCEDURE DimensionCheck(base,dim: IntermediateCode.Operand; op: ConditionalBranch );
		VAR d: IntermediateCode.Operand;
		BEGIN
			IF isUnchecked THEN RETURN END;
			MakeMemory(d,base,dim.type,ToMemoryUnits(system,MathDimOffset * addressType.sizeInBits));
			TrapC(op,dim,d,ArraySizeTrap);
			ReleaseIntermediateOperand(d);
		END DimensionCheck;

		PROCEDURE MathIndexDesignator(x: SyntaxTree.IndexDesignator; VAR result: Operand);
		VAR
			index, range, array, sourceLength, sourceIncrement, localResult: Operand;
			firstIndex, lastIndex, stepSize, summand, targetLength, targetIncrement, tmp, srcDim, destDim: IntermediateCode.Operand;
			expression: SyntaxTree.Expression;
			resultingType, leftType, baseType: SyntaxTree.Type;
			skipLabel1: Label;
			i, indexListSize, indexDim, srcDimOffset, destDimOffset, targetArrayDimensionality: LONGINT;
			staticSourceLength, staticSourceIncrement, staticIndex, staticFirstIndex, staticLastIndex, staticStepSize, staticTargetLength: LONGINT;
			variableOp: Operand;
			variable: SyntaxTree.Variable;
			prefixIndices, prefixRanges, suffixIndices, suffixRanges : LONGINT; tensorFound: BOOLEAN;

			PROCEDURE CountIndices(parameters: SyntaxTree.ExpressionList);
			VAR e: SyntaxTree.Expression; i: LONGINT;
			BEGIN
				tensorFound := FALSE;
				FOR i := 0 TO parameters.Length()-1 DO
					e := parameters.GetExpression(i);
					IF e IS SyntaxTree.TensorRangeExpression THEN
						ASSERT(~tensorFound);
						tensorFound := TRUE;
					ELSIF e IS SyntaxTree.RangeExpression THEN
						IF tensorFound THEN INC(suffixRanges) ELSE INC(prefixRanges) END;
					ELSE
						IF tensorFound THEN INC(suffixIndices) ELSE INC(prefixIndices) END;
					END;
				END;

			END CountIndices;

		BEGIN
			ASSERT(tagsAvailable);

			resultingType := x.type.resolved; (* resulting type *)
			leftType := x.left.type.resolved; (* type of array to be indexed over *)

			InitOperand(localResult, ModeReference);

			IF (resultingType IS SyntaxTree.MathArrayType)  & ( (resultingType(SyntaxTree.MathArrayType).form # SyntaxTree.Static) OR NeedDescriptor) THEN
				targetArrayDimensionality := resultingType(SyntaxTree.MathArrayType).Dimensionality();

				IF arrayDestinationTag.mode # IntermediateCode.Undefined THEN
					(* a globally defined array destination tag is available -> use and invalidate it*)
					localResult.tag := arrayDestinationTag;
					IntermediateCode.InitOperand(arrayDestinationTag)
				ELSE
					(* otherwise, create a temporary variable and use it to store the array destination tag *)
					(* the result is of array range type and thus does not provide any collectable pointers *)
					variable := GetTemporaryVariable(GetMathArrayDescriptorType(targetArrayDimensionality), FALSE, TRUE (* untraced *));
					Symbol(variable, variableOp);
					ReuseCopy(localResult.tag, variableOp.op);
					ReleaseOperand(variableOp);
				END
			END;

			indexListSize := x.parameters.Length();

			CountIndices(x.parameters);
			(*ASSERT(tensorRangeCount <= 1);*)

			(* designate the array to be indexed over, perform tensor range check if known *)
			Designate(x.left, array);

			IF leftType(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
				Dereference(array, leftType,FALSE);
				IF ~tensorFound THEN
					DimensionCheck(array.tag, IntermediateCode.Immediate(sizeType, prefixRanges + prefixIndices), BreqL)
				END
			END;

			(* default base offset *)
			srcDimOffset := 0;
			destDimOffset := 0;

			indexDim := 0;

			(* use address of source array as basis *)

			localResult.op := array.op;
			UseIntermediateOperand(localResult.op);

			(* go through the index list *)
			FOR i := 0 TO indexListSize - 1 DO
				expression := x.parameters.GetExpression(i);

				IF expression IS SyntaxTree.TensorRangeExpression THEN
					(* Questionmark in A[x,*,?,x,*] encountered -- now have to count backwards from the end of source and destination *)
					srcDimOffset := -indexListSize;
					destDimOffset := -suffixRanges;
				ELSE
					(* determine which dimension of source array is currently looked at *)
					IF srcDimOffset < 0 THEN (* tensor expression or the form a[?,i,j] *)
						(* get the memory operand pointing to array descriptor dimension *)
						GetMathArrayField(tmp, array.tag, MathDimOffset);
						(* make a reusable register from it *)
						ReuseCopy(srcDim, tmp);
						ReleaseIntermediateOperand(tmp);
						AddInt(srcDim, srcDim, IntermediateCode.Immediate(addressType, i + srcDimOffset));
					ELSE
						srcDim := IntermediateCode.Immediate(sizeType, i);
					END;

					(* get length and increment of source array for current dimension *)
					GetMathArrayLength(leftType(SyntaxTree.MathArrayType), array, srcDim, FALSE, sourceLength);
					Convert(sourceLength.op, sizeType);
					GetMathArrayIncrement(leftType(SyntaxTree.MathArrayType), array, srcDim, FALSE, sourceIncrement);
					Convert(sourceIncrement.op, sizeType);
					(* release the dim operand, if dynamic. No register reuse to decrease register pressure *)
					ReleaseIntermediateOperand(srcDim);

					IF SemanticChecker.IsIntegerType(expression.type.resolved) THEN
						(* SINGLE INDEX *)
						Evaluate(expression, index);
						ReleaseIntermediateOperand(index.tag);
						index.tag := emptyOperand;
						Convert(index.op, sizeType);

						(* lower bound check *)
						IF IsIntegerImmediate(index.op, staticIndex) THEN
							ASSERT(staticIndex >= 0) (* ensured by the checker *)
						ELSIF isUnchecked THEN (* do nothing *)
						ELSE
							TrapC(BrgeL, index.op, IntermediateCode.Immediate(sizeType, 0), IndexCheckTrap)
						END;

						(* upper bound check *)
						IF IsIntegerImmediate(index.op, staticIndex) & IsIntegerImmediate(sourceLength.op, staticSourceLength) THEN
							ASSERT(staticIndex < staticSourceLength) (* ensured by checker *)
						ELSIF isUnchecked THEN (* do nothing *)
						ELSE
							TrapC(BrltL, index.op, sourceLength.op, IndexCheckTrap)
						END;

						ReleaseOperand(sourceLength);
						Convert(index.op, addressType);
						summand := index.op;

					ELSIF expression.type.resolved IS SyntaxTree.RangeType THEN
						(* RANGE OF INDICES *)
						Evaluate(expression, range);
						firstIndex := range.op; UseIntermediateOperand(firstIndex);
						lastIndex := range.tag; UseIntermediateOperand(lastIndex);
						stepSize := range.extra; UseIntermediateOperand(stepSize);
						ReleaseOperand(range);

						Convert(firstIndex, sizeType);
						Convert(lastIndex, sizeType);
						Convert(stepSize, sizeType);

						(* for dynamic upper bounds: add a runtime check, which repaces the upper bound with the largest valid index
						if it is 'MAX(LONGINT)' *)
						IF ~IsIntegerImmediate(lastIndex, staticLastIndex) THEN
							TransferToRegister(lastIndex, lastIndex);
							skipLabel1 := NewLabel();
							BrneL(skipLabel1, lastIndex, IntermediateCode.Immediate(sizeType, MAX(LONGINT)));
							Emit(MovReplace(position,lastIndex, sourceLength.op)); (* make sure that no new register is allocated *)
							Emit(Sub(position,lastIndex, lastIndex, IntermediateCode.Immediate(sizeType, 1)));
							SetLabel(skipLabel1)
						END;

						(* check if step size is valid *)
						IF IsIntegerImmediate(stepSize, staticStepSize) THEN
							ASSERT(staticStepSize >= 1) (* ensured by the checker *)
						ELSIF isUnchecked THEN (* do nothing *)
						ELSE
							TrapC(BrgeL, stepSize, IntermediateCode.Immediate(sizeType, 1), IndexCheckTrap)
						END;

						(* check lower bound check *)
						IF IsIntegerImmediate(firstIndex, staticFirstIndex) THEN
							ASSERT(staticFirstIndex >= 0) (* ensured by the checker *)
						ELSIF isUnchecked THEN (* do nothing *)
						ELSE
							TrapC(BrgeL, firstIndex, IntermediateCode.Immediate(sizeType, 0), IndexCheckTrap)
						END;

						(* check upper bound check *)
						IF IsIntegerImmediate(lastIndex, staticLastIndex) & (staticLastIndex = MAX(LONGINT)) THEN
							(* statically open range: nothing to do *)
						ELSIF IsIntegerImmediate(lastIndex, staticLastIndex) & IsIntegerImmediate(sourceLength.op, staticSourceLength) THEN
							ASSERT(staticLastIndex < staticSourceLength)
						ELSIF isUnchecked THEN (* do nothing *)
						ELSE
							TrapC(BrltL, lastIndex, sourceLength.op, IndexCheckTrap)
						END;

						(* determine length of target array for current dimension *)
						(* 1. incorporate last index: *)
						IF IsIntegerImmediate(lastIndex, staticLastIndex) THEN
							(* last index is static *)
							IF IsIntegerImmediate(lastIndex, staticLastIndex) & (staticLastIndex = MAX(LONGINT)) THEN
								targetLength := sourceLength.op
							ELSE
								targetLength := IntermediateCode.Immediate(sizeType, staticLastIndex + 1)
							END;
							UseIntermediateOperand(targetLength);
						ELSE
							(* targetLength := lastIndex + 1
							Reuse1(targetLength, lastIndex);
							*)
							AddInt(targetLength, lastIndex, IntermediateCode.Immediate(sizeType, 1));
						END;
						ReleaseOperand(sourceLength);
						ReleaseIntermediateOperand(lastIndex);
						(* 2. incorporate first index: *)
						IF IsIntegerImmediate(firstIndex, staticFirstIndex) & IsIntegerImmediate(targetLength, staticTargetLength) THEN
							(* first index and current target length are static *)
							targetLength := IntermediateCode.Immediate(sizeType, staticTargetLength - staticFirstIndex)
						ELSIF IsIntegerImmediate(firstIndex, staticFirstIndex) & (staticFirstIndex = 0) THEN
							(* first index = 0: nothing to do *)
						ELSE
							(* targetLength := targetLength - firstIndex *)
							TransferToRegister(targetLength, targetLength);
							Emit(Sub(position,targetLength, targetLength, firstIndex))
						END;

						(* clip negative lengths to 0 *)
						IF IsIntegerImmediate(targetLength, staticTargetLength) THEN
							IF staticTargetLength < 0 THEN
								targetLength := IntermediateCode.Immediate(sizeType, 0)
							END
						ELSE
							skipLabel1 := NewLabel();
							TransferToRegister(targetLength, targetLength);
							BrgeL(skipLabel1, targetLength, IntermediateCode.Immediate(sizeType, 0));
							Emit(Mov(position,targetLength, IntermediateCode.Immediate(sizeType, 0)));
							SetLabel(skipLabel1)
						END;

						(* 3. incorporate index step size: *)
						IF IsIntegerImmediate(stepSize, staticStepSize) & IsIntegerImmediate(targetLength, staticTargetLength) THEN
							(*step size and current target length are static *)
							staticTargetLength := (staticTargetLength-1) DIV staticStepSize + 1;
							targetLength := IntermediateCode.Immediate(sizeType, staticTargetLength)
						ELSIF IsIntegerImmediate(stepSize, staticStepSize) & (staticStepSize = 1) THEN
							(* step size = 1: nothing to do *)
						ELSE
							(* emit code for this:
								targetLength := (targetLength-1) DIV stepSize +1;
							*)
							AddInt(targetLength, targetLength, IntermediateCode.Immediate(sizeType, -1));
							DivInt(targetLength, targetLength, stepSize);
							AddInt(targetLength, targetLength, IntermediateCode.Immediate(sizeType, 1));

						END;

						(* determine increment of target array for current dimension *)
						IF IsIntegerImmediate(sourceIncrement.op, staticSourceIncrement) & IsIntegerImmediate(stepSize, staticStepSize) THEN
							targetIncrement := IntermediateCode.Immediate(sizeType, staticSourceIncrement * staticStepSize);
						ELSIF IsIntegerImmediate(stepSize, staticStepSize) & (staticStepSize = 1) THEN
							(* step size = 1 *)
							targetIncrement := sourceIncrement.op;
							UseIntermediateOperand(targetIncrement)
						ELSE
							(* targetIncrement := sourceIncrement * stepSize *)
							Reuse1(targetIncrement, stepSize);
							ASSERT((sourceIncrement.op.mode # IntermediateCode.ModeImmediate) OR (stepSize.mode # IntermediateCode.ModeImmediate));
							MulInt(targetIncrement, sourceIncrement.op, stepSize);
						END;
						ReleaseIntermediateOperand(stepSize);

						(* write length and increment of target array to descriptor *)
						IF destDimOffset < 0 THEN
							(* determine which dimension of target array is currently looked at *)
							GetMathArrayField(tmp, localResult.tag, MathDimOffset);
							TransferToRegister(destDim, tmp);
							AddInt(destDim, destDim, IntermediateCode.Immediate(sizeType, (* indexDim + *) destDimOffset));

							PutMathArrayLenOrIncr(localResult.tag, targetLength, destDim, FALSE);
							PutMathArrayLenOrIncr(localResult.tag, targetIncrement, destDim, TRUE);

							ReleaseIntermediateOperand(destDim);
							INC(destDimOffset);
						ELSE
							PutMathArrayLength(localResult.tag, targetLength, indexDim);
							PutMathArrayIncrement(localResult.tag , targetIncrement, indexDim);
						END;
						ReleaseIntermediateOperand(targetLength); targetLength := nil;
						ReleaseIntermediateOperand(targetIncrement); targetIncrement := nil;

						INC(indexDim);

						Convert(firstIndex, addressType);
						TransferToRegister(summand, firstIndex);
					ELSE HALT(100);
					END;

					(*
					ASSERT((summand.mode # IntermediateCode.ModeImmediate) OR (sourceIncrement.op.mode # IntermediateCode.ModeImmediate));
					*)
					Convert(sourceIncrement.op, addressType);
					Convert(summand, addressType);
					MulInt(summand, summand, sourceIncrement.op);
					ReleaseIntermediateOperand(sourceIncrement.op);
					AddInt(localResult.op, localResult.op, summand);
					ReleaseIntermediateOperand(summand);
				END
			END;

			result := localResult;

			IF (resultingType IS SyntaxTree.RecordType) & (resultingType(SyntaxTree.RecordType).pointerType = NIL) THEN
				ReleaseIntermediateOperand(result.tag);
				result.tag := TypeDescriptorAdr(resultingType);

			ELSIF IsDelegate(resultingType) THEN
				ReleaseIntermediateOperand(result.tag);
				IntermediateCode.InitMemory(result.tag,addressType,result.op,ToMemoryUnits(system,system.addressSize));
				UseIntermediateOperand(result.tag);

			ELSIF (resultingType IS SyntaxTree.ArrayType) & (resultingType(SyntaxTree.ArrayType).form = SyntaxTree.Static) THEN
				ReleaseIntermediateOperand(result.tag);
				IntermediateCode.InitImmediate(result.tag,addressType,resultingType(SyntaxTree.ArrayType).staticLength);

			ELSIF (resultingType IS SyntaxTree.ArrayType) THEN
				result.tag := array.tag; UseIntermediateOperand(result.tag); result.dimOffset := array.dimOffset+indexListSize-1;

			ELSIF (resultingType IS SyntaxTree.MathArrayType) & ( (resultingType(SyntaxTree.MathArrayType).form # SyntaxTree.Static) OR NeedDescriptor) THEN
				(* finalize target array descriptor *)
				ASSERT(result.tag.mode # IntermediateCode.Undefined); (* tag has been already set in the beginning *)

				(* write lengths and increments of target array for remaining dimensions *)
				i := indexListSize;
				WHILE indexDim < targetArrayDimensionality DO
					GetMathArrayLengthAt(leftType(SyntaxTree.MathArrayType),array,i,FALSE, sourceLength);
					PutMathArrayLength(result.tag, sourceLength.op,indexDim);
					ReleaseOperand(sourceLength);
					GetMathArrayIncrementAt(leftType(SyntaxTree.MathArrayType),array,i,FALSE,sourceIncrement);
					PutMathArrayIncrement(result.tag, sourceIncrement.op,indexDim);
					ReleaseOperand(sourceIncrement);
					INC(i); INC(indexDim);
				END;

				IF leftType(SyntaxTree.MathArrayType).form = SyntaxTree.Static THEN
					tmp := nil;
				ELSE
					GetMathArrayField(tmp,array.tag,MathPtrOffset);
				END;
				PutMathArrayField(result.tag, tmp, MathPtrOffset);
				ReleaseIntermediateOperand(tmp);
				IF leftType(SyntaxTree.MathArrayType).form = SyntaxTree.Static THEN
					baseType := SemanticChecker.ArrayBase(resultingType, indexDim);
					tmp := IntermediateCode.Immediate(addressType, ToMemoryUnits(system,system.AlignedSizeOf(baseType)));
				ELSE
					GetMathArrayField(tmp,array.tag, MathElementSizeOffset);
				END;
				PutMathArrayField(result.tag, tmp, MathElementSizeOffset);
				ReleaseIntermediateOperand(tmp);

				PutMathArrayField(result.tag, result.op, MathAdrOffset);

				(* write dimensionality *)
				IF targetArrayDimensionality # 0 THEN
					PutMathArrayField(result.tag, IntermediateCode.Immediate(addressType, targetArrayDimensionality),MathDimOffset);
				END;

				PutMathArrayField(result.tag, IntermediateCode.Immediate(addressType,SYSTEM.VAL(LONGINT,{RangeFlag})),MathFlagsOffset);

			END;

			ReleaseOperand(array);

		END MathIndexDesignator;

		(* get the length of an array , trying to make use of static information *)
		PROCEDURE ArrayLength(type: SyntaxTree.Type; dim: LONGINT; tag: IntermediateCode.Operand): IntermediateCode.Operand;
		VAR res: IntermediateCode.Operand; size: LONGINT;
		BEGIN
			type := type.resolved;
			IF type IS SyntaxTree.ArrayType THEN
				WITH type: SyntaxTree.ArrayType DO
					IF type.form = SyntaxTree.Static THEN
						RETURN IntermediateCode.Immediate(addressType,type.staticLength);
					(*ELSIF (type.form = SyntaxTree.SemiDynamic) & backend.cellsAreObjects THEN
						Evaluate(type.length, op);
						ReleaseIntermediateOperand(op.tag);
						RETURN op.op;*)
					ELSE
						res := tag;
						IntermediateCode.AddOffset(res,ToMemoryUnits(system,addressType.sizeInBits*(DynamicDim(type)-1)));
						IntermediateCode.MakeMemory(res,addressType);
						UseIntermediateOperand(res);
						RETURN res
					END
				END;
			ELSE
				size := ToMemoryUnits(system,system.AlignedSizeOf(type));
				RETURN IntermediateCode.Immediate(addressType,size);
			END;
		END ArrayLength;

		PROCEDURE CopyInt(VAR res: IntermediateCode.Operand; x: IntermediateCode.Operand);
		BEGIN
			IF IsImmediate(x) THEN
				IntermediateCode.InitImmediate(res,x.type,x.intValue);
			ELSE
				IF ~ReusableRegister(res) THEN
					IntermediateCode.InitRegister(res,x.type,IntermediateCode.GeneralPurposeRegister,AcquireRegister(x.type,IntermediateCode.GeneralPurposeRegister));
				ELSE
					UseIntermediateOperand(res);
				END;
				Emit(Mov(position,res,x))
			END;
		END CopyInt;

		PROCEDURE AddInt(VAR res: IntermediateCode.Operand; x,y: IntermediateCode.Operand);
		BEGIN
			ReleaseIntermediateOperand(res);
			IF IsImmediate(x) & IsImmediate(y) THEN
				IntermediateCode.InitImmediate(res,x.type,x.intValue+y.intValue);
			ELSIF IsAddress(x) & IsImmediate(y) THEN
				IntermediateCode.InitAddress(res,x.type,x.symbol.name, x.symbol.fingerprint, x.symbolOffset);
				IntermediateCode.AddOffset(res, LONGINT(y.intValue)+x.offset);
			ELSIF IsAddress(y) & IsImmediate(x) THEN
				IntermediateCode.InitAddress(res,y.type,y.symbol.name, y.symbol.fingerprint, y.symbolOffset);
				IntermediateCode.AddOffset(res, LONGINT(x.intValue)+y.offset);
			ELSIF IsRegister(x) & IsImmediate(y) THEN
				IntermediateCode.InitRegister(res, x.type, x.registerClass, x.register);
				IntermediateCode.AddOffset(res, x.offset + LONGINT(y.intValue));
				UseIntermediateOperand(res);
			ELSIF IsRegister(y) & IsImmediate(x) THEN
				IntermediateCode.InitRegister(res, y.type, y.registerClass, y.register);
				IntermediateCode.AddOffset(res, y.offset + LONGINT(x.intValue));
				UseIntermediateOperand(res);
			ELSE
				IF ~ReusableRegister(res) THEN
					IntermediateCode.InitRegister(res,x.type,IntermediateCode.GeneralPurposeRegister,AcquireRegister(x.type,IntermediateCode.GeneralPurposeRegister));
				ELSE
					UseIntermediateOperand(res);
				END;
				IF IsImmediate(x) & (x.intValue = 0) THEN
					Emit(Mov(position,res,y))
				ELSIF IsImmediate(y) & (y.intValue=0) THEN
					Emit(Mov(position,res,x))
				ELSE
					Emit(Add(position,res, x, y));
				END;
			END;
		END AddInt;

		PROCEDURE MulInt(VAR res: IntermediateCode.Operand; x,y: IntermediateCode.Operand);
		BEGIN
			ReleaseIntermediateOperand(res);
			IF IsImmediate(x) & IsImmediate(y) THEN
				IntermediateCode.InitImmediate(res,x.type,x.intValue*y.intValue);
			ELSE
				IF ~ReusableRegister(res) THEN
					IntermediateCode.InitRegister(res,x.type,IntermediateCode.GeneralPurposeRegister,AcquireRegister(x.type,IntermediateCode.GeneralPurposeRegister));
				ELSE UseIntermediateOperand(res);
				END;
				IF IsImmediate(x) & (x.intValue = 1) THEN
					Emit(Mov(position,res,y))
				ELSIF IsImmediate(y) & (y.intValue=1) THEN
					Emit(Mov(position,res,x))
				ELSE
					Emit(Mul(position,res, x, y));
				END;
			END;
		END MulInt;

		PROCEDURE DivInt(VAR res: IntermediateCode.Operand; x,y: IntermediateCode.Operand);
		BEGIN
			ReleaseIntermediateOperand(res);
			IF IsImmediate(x) & IsImmediate(y) THEN
				IntermediateCode.InitImmediate(res,x.type,x.intValue DIV y.intValue);
			ELSE
				IF ~ReusableRegister(res) THEN
					IntermediateCode.InitRegister(res,x.type,IntermediateCode.GeneralPurposeRegister,AcquireRegister(x.type,IntermediateCode.GeneralPurposeRegister));
				ELSE UseIntermediateOperand(res);
				END;
				IF IsImmediate(x) & (x.intValue = 1) THEN
					Emit(Mov(position,res,y))
				ELSIF IsImmediate(y) & (y.intValue=1) THEN
					Emit(Mov(position,res,x))
				ELSE
					Emit(Div(position,res, x, y));
				END;
			END;
		END DivInt;

		PROCEDURE IndexDesignator(x: SyntaxTree.IndexDesignator; VAR result: Operand);
		VAR length,res: IntermediateCode.Operand; type,ttype: SyntaxTree.Type; maxDim: LONGINT; array:Operand;
			index: Operand; e: SyntaxTree.Expression;i: LONGINT; size: LONGINT; atype: SyntaxTree.ArrayType;
		BEGIN
			type := x.left.type.resolved;
			IF type IS SyntaxTree.StringType THEN
				atype := SyntaxTree.NewArrayType(Basic.invalidPosition, NIL, SyntaxTree.Static);
				atype.SetArrayBase(type(SyntaxTree.StringType).baseType);
				atype.SetLength(Global.NewIntegerValue(system,Basic.invalidPosition, type(SyntaxTree.StringType).length));
				type := atype;
				x.left.SetType(type);
			END;

			IntermediateCode.InitImmediate(res,addressType,0);
			maxDim := x.parameters.Length()-1;
			(*
				computation rule:
				a: ARRAY X,Y,Z OF Element with size S
				a[i,j,k] -->
				( ( ( ( i ) * Y  + j ) * Z) + k) * S
			*)
			FOR i := 0 TO maxDim DO
				e := x.parameters.GetExpression(i);
				Evaluate(e,index);
				Convert(index.op,addressType);

				AddInt(res, res, index.op);

				IF i = 0 THEN
					(*
					ReuseCopy(res, index.op);
					*)
					Designate(x.left,array);
					type := x.left.type.resolved;
					IF (type(SyntaxTree.ArrayType).form = SyntaxTree.SemiDynamic) & backend.cellsAreObjects THEN
						Dereference(array, type, FALSE);
					END;
				(*
				ELSE AddInt(res, res, index.op);
				*)
				END;

				IF (array.tag.mode # IntermediateCode.Undefined ) THEN
					length := ArrayLength(type(SyntaxTree.ArrayType),array.dimOffset+i,array.tag);
					IF ((length.mode # IntermediateCode.ModeImmediate) OR (index.op.mode # IntermediateCode.ModeImmediate)) & tagsAvailable THEN
						BoundCheck(index.op, length);
					END;
					ReleaseIntermediateOperand(length);
				END;
				ReleaseOperand(index);
				type := type(SyntaxTree.ArrayType).arrayBase.resolved;

				length := ArrayLength(type,array.dimOffset+i-1,array.tag);
				IF (length.mode # IntermediateCode.ModeImmediate) OR (length.intValue # 1) THEN
					MulInt(res,res,length);
				END;
				ReleaseIntermediateOperand(length);
			END;

			(* remaining open dimensions -- compute address *)
			i := maxDim+1;
			IF type IS SyntaxTree.ArrayType THEN
				ttype := type(SyntaxTree.ArrayType).arrayBase.resolved;
				WHILE (ttype IS SyntaxTree.ArrayType) & (ttype(SyntaxTree.ArrayType).form # SyntaxTree.Static) DO
					length := ArrayLength(ttype,array.dimOffset+i-1,array.tag);
					IF (length.mode # IntermediateCode.ModeImmediate) OR (length.intValue # 1) THEN
						MulInt(res,res,length);
					END;
					ReleaseIntermediateOperand(length);
					INC(i);
					ttype := ttype(SyntaxTree.ArrayType).arrayBase.resolved;
				END;
			END;

			IF (type IS SyntaxTree.ArrayType) THEN
				IF (type(SyntaxTree.ArrayType).form # SyntaxTree.Static) THEN
					size := StaticSize(system, type);
					IF size # 1 THEN
						length := IntermediateCode.Immediate(addressType,size);
						MulInt(res,res,length);
					END;
				ELSE
					size := StaticSize(system, type(SyntaxTree.ArrayType).arrayBase);
					IF size # 1 THEN
						length := IntermediateCode.Immediate(addressType,size);
						MulInt(res,res,length);
					END;
				END;
			END;
			AddInt(res,res,array.op);
			InitOperand(result,ModeReference);
			result.op := res;

			IF (type IS SyntaxTree.RecordType) & (type(SyntaxTree.RecordType).pointerType = NIL) THEN
				ReleaseIntermediateOperand(result.tag);
				result.tag := TypeDescriptorAdr(type);
			ELSIF IsDelegate(type) THEN
				ReleaseIntermediateOperand(result.tag);
				IntermediateCode.InitMemory(result.tag,addressType,result.op,ToMemoryUnits(system,system.addressSize));
				UseIntermediateOperand(result.tag);
			ELSIF (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).form = SyntaxTree.Static) THEN
				ReleaseIntermediateOperand(result.tag);
				IntermediateCode.InitImmediate(result.tag,addressType,type(SyntaxTree.ArrayType).staticLength);
			ELSIF (type IS SyntaxTree.ArrayType)  THEN
				result.tag := array.tag; UseIntermediateOperand(result.tag); result.dimOffset := array.dimOffset+maxDim;
			END;
			ReleaseOperand(array);
		END IndexDesignator;

		PROCEDURE DesignateIndexDesignator(x: SyntaxTree.IndexDesignator; VAR result: Operand);
		VAR type: SyntaxTree.Type; dest: IntermediateCode.Operand;
		BEGIN
			IF Trace THEN TraceEnter("DesignateIndexDesignator") END;
			dest := destination; destination := emptyOperand;
			type := x.left.type.resolved;
			IF type IS SyntaxTree.MathArrayType THEN
				MathIndexDesignator(x, result);
			ELSE ASSERT((type IS SyntaxTree.ArrayType) OR (type IS SyntaxTree.StringType));
				IndexDesignator(x, result);
			END;
			destination := dest;
			IF Trace THEN TraceExit("DesignateIndexDesignator") END;
		END DesignateIndexDesignator;

		PROCEDURE PrepareTensorDescriptor(expression: SyntaxTree.IndexDesignator): SyntaxTree.Variable;
		VAR variable: SyntaxTree.Variable; srcOperand,destOperand,procOp: Operand;
			moduleName, procedureName: SyntaxTree.IdentifierString; arrayBase: SyntaxTree.Module; saved: RegisterEntry; s: Basic.MessageString;
			procedure: SyntaxTree.Procedure;
			parameters: SyntaxTree.ExpressionList; e: SyntaxTree.Expression;
			prefixIndices, prefixRanges, suffixIndices, suffixRanges,i : LONGINT; tensorFound: BOOLEAN;
		BEGIN
			(* variable represents a newly allocaed range array in a tensor, this is allocated in CopyDescriptor and must thus not be untraced *)
			variable := GetTemporaryVariable(expression.left.type, FALSE, FALSE (* untraced *));
			parameters := expression.parameters;

			moduleName := "FoxArrayBase";
			procedureName := "CopyDescriptor";
			IF AddImport(moduleName,arrayBase,TRUE) THEN
				SaveRegisters();ReleaseUsedRegisters(saved);
				procedure := arrayBase.moduleScope.FindProcedure(SyntaxTree.NewIdentifier(procedureName));
				IF procedure = NIL THEN
					s := "procedure ";
					Strings.Append(s,moduleName);
					Strings.Append(s,".");
					Strings.Append(s,procedureName);
					Strings.Append(s," not present");
					Error(position,s);
				ELSE
					(* push address of temporary variable *)
					Symbol(variable,destOperand);
					Emit(Push(position,destOperand.op));
					ReleaseOperand(destOperand);
					(* push src *)
					Evaluate(expression.left,srcOperand);
					(*
					Dereference(srcOperand,expression.type.resolved);
					Emit(Push(position,srcOperand.tag));
					*)
					Emit(Push(position,srcOperand.op));
					ReleaseOperand(srcOperand);

					tensorFound := FALSE;
					FOR i := 0 TO parameters.Length()-1 DO
						e := parameters.GetExpression(i);
						IF e IS SyntaxTree.TensorRangeExpression THEN
							tensorFound := TRUE;
						ELSIF e IS SyntaxTree.RangeExpression THEN
							IF tensorFound THEN INC(suffixRanges) ELSE INC(prefixRanges) END;
						ELSE
							IF tensorFound THEN INC(suffixIndices) ELSE INC(prefixIndices) END;
						END;
					END;

					Emit(Push(position,IntermediateCode.Immediate(sizeType,prefixIndices)));
					Emit(Push(position,IntermediateCode.Immediate(sizeType,prefixRanges)));
					Emit(Push(position,IntermediateCode.Immediate(sizeType,suffixIndices)));
					Emit(Push(position,IntermediateCode.Immediate(sizeType,suffixRanges)));

					StaticCallOperand(procedure,procOp);
					Emit(Call(position,procOp.op,ProcParametersSize(procedure)));
					ReleaseOperand(procOp);
				END;
				RestoreRegisters(saved);
			END;
			RETURN variable

		END PrepareTensorDescriptor;

		PROCEDURE PushParameter(expression: SyntaxTree.Expression; parameter: SyntaxTree.Parameter; callingConvention: LONGINT; needsParameterBackup: BOOLEAN; VAR parameterBackup: IntermediateCode.Operand; register: WORD);
		VAR
			type, descriptorType, baseType, componentType: SyntaxTree.Type;
			operand, tmpOperand, variableOp, variable2Op: Operand;
			baseReg, tmp, dimOp, null, dst: IntermediateCode.Operand;
			variable, variable2: SyntaxTree.Variable;
			dim, i, size: LONGINT;

			(* TODO: needed? *)
			oldArrayDestinationTag: IntermediateCode.Operand;
			oldArrayDestinationDimension: LONGINT;
			position: Position;
			saved: RegisterEntry;

			arrayFlags: SET;
			m, n: LONGINT;

			PROCEDURE Pass(op: IntermediateCode.Operand);
			VAR registerClass: IntermediateCode.RegisterClass; parameterRegister: IntermediateCode.Operand;
			BEGIN
				IF register >= 0 THEN
					IntermediateCode.InitParameterRegisterClass(registerClass, register);
					IntermediateCode.InitRegister(parameterRegister, op.type, registerClass, AcquireRegister(op.type, registerClass));
					Emit(Mov(position,parameterRegister, op));
				ELSE
					Emit(Push(position,op))
				END
			END Pass;

			PROCEDURE PushArrayLens(formalType,actualType: SyntaxTree.Type; dim: LONGINT);
			VAR tmp: IntermediateCode.Operand; actualArrayBase: SyntaxTree.Type;
			BEGIN
				formalType := formalType.resolved; actualType := actualType.resolved;
				IF IsOpenArray(formalType)THEN
					IF actualType IS SyntaxTree.StringType THEN
						Pass((IntermediateCode.Immediate(addressType,actualType(SyntaxTree.StringType).length)));
						RETURN;
					ELSIF (actualType IS SyntaxTree.MathArrayType) & (actualType(SyntaxTree.MathArrayType).form = SyntaxTree.Static) THEN
						Pass((IntermediateCode.Immediate(addressType,actualType(SyntaxTree.MathArrayType).staticLength)));
						actualArrayBase := actualType(SyntaxTree.MathArrayType).arrayBase.resolved;
					ELSIF actualType(SyntaxTree.ArrayType).form = SyntaxTree.Static THEN
						Pass((IntermediateCode.Immediate(addressType,actualType(SyntaxTree.ArrayType).staticLength)));
						actualArrayBase := actualType(SyntaxTree.ArrayType).arrayBase.resolved;
					ELSE
						tmp := baseReg;
						IntermediateCode.AddOffset(tmp,ToMemoryUnits(system,dim*system.addressSize));
						IntermediateCode.MakeMemory(tmp,addressType);
						Pass((tmp));
						actualArrayBase := actualType(SyntaxTree.ArrayType).arrayBase.resolved;
					END;
					PushArrayLens(formalType(SyntaxTree.ArrayType).arrayBase.resolved, actualArrayBase,dim-1);
				END;
			END PushArrayLens;

			PROCEDURE SetSmallArraySizeFlag(VAR flags: SET; size: LONGINT);
			BEGIN
				CASE size OF
					|2: INCL(flags,Size2Flag);
					|3: INCL(flags,Size3Flag);
					|4: INCL(flags,Size4Flag);
					|5: INCL(flags,Size5Flag);
					|6: INCL(flags,Size6Flag);
					|7: INCL(flags,Size7Flag);
					|8: INCL(flags,Size8Flag);
				END;
			END SetSmallArraySizeFlag;

		BEGIN
			IF Trace THEN TraceEnter("PushParameter") END;
			position := expression.position;
			IF expression.resolved # NIL THEN expression := expression.resolved END;
			type := expression.type.resolved;

			IF ~( ((type IS SyntaxTree.MathArrayType) = (parameter.type.resolved IS SyntaxTree.MathArrayType))
						OR  (type IS SyntaxTree.MathArrayType) & (parameter.type.resolved IS SyntaxTree.ArrayType)
							& (type(SyntaxTree.MathArrayType).form = SyntaxTree.Static)
							& (parameter.type.resolved(SyntaxTree.ArrayType).form = SyntaxTree.Open)
				) THEN Printout.Info("type",type);
				TRACE(position.start);
				Printout.Info("parameter",parameter);
				END;

			ASSERT( ((type IS SyntaxTree.MathArrayType) = (parameter.type.resolved IS SyntaxTree.MathArrayType))
						OR  (type IS SyntaxTree.MathArrayType) & (parameter.type.resolved IS SyntaxTree.ArrayType)
							& (type(SyntaxTree.MathArrayType).form = SyntaxTree.Static)
							& (parameter.type.resolved(SyntaxTree.ArrayType).form = SyntaxTree.Open)
				);

			(* TODO: needed? *)
			oldArrayDestinationTag := arrayDestinationTag;
			oldArrayDestinationDimension := arrayDestinationDimension;

			IF IsArrayOfSystemByte(parameter.type) THEN
				IF SemanticChecker.HasAddress(expression) OR (callingConvention = SyntaxTree.WinAPICallingConvention) & (expression IS SyntaxTree.NilValue) THEN
					Designate(expression,operand);
				ELSE
					Evaluate(expression, tmpOperand);
					(* array of system byte does not provide any pointers *)
					variable := GetTemporaryVariable(expression.type, FALSE, FALSE);
					Symbol(variable, operand);
					MakeMemory(tmp,operand.op,tmpOperand.op.type,0);
					Emit(Mov(position,tmp, tmpOperand.op));
					ReleaseOperand(tmpOperand);
				END;
				tmp := GetArrayOfBytesSize(expression,operand.tag);
				ReleaseIntermediateOperand(operand.tag);
				operand.tag := tmp;
				IF callingConvention = SyntaxTree.OberonCallingConvention  THEN
					Pass((operand.tag));
				END;
				Pass((operand.op));
			ELSIF IsOpenArray(parameter.type) THEN
				Designate(expression,operand);
				baseReg := operand.tag;
				IF callingConvention = SyntaxTree.OberonCallingConvention  THEN
					PushArrayLens(parameter.type,type,operand.dimOffset+DynamicDim(parameter.type)-1);
				END;
				Pass((operand.op)); (* address of the array *)
			ELSIF parameter.type.resolved IS SyntaxTree.MathArrayType THEN

				(* case 1
					procedure P([left args], [const] A: array [*,*] of Type, [right args])
				*)
				IF (parameter.type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Open) &
				(parameter.kind IN {SyntaxTree.ValueParameter, SyntaxTree.ConstParameter}) THEN
					size := MathLenOffset + 2*SemanticChecker.Dimension(parameter.type.resolved,{SyntaxTree.Open});
					size := ToMemoryUnits(system,size*addressType.sizeInBits);
					Emit(Sub(position,sp,sp,IntermediateCode.Immediate(addressType,size)));
					dim := SemanticChecker.Dimension(parameter.type.resolved,{SyntaxTree.Open});
					arrayDestinationTag := sp;

					(* case 1b
						P(...,A[a..b,c..d],...): push: push array range descriptor to stack
					*)
					IF expression IS SyntaxTree.IndexDesignator THEN
						ReuseCopy(arrayDestinationTag,arrayDestinationTag);
						dim := SemanticChecker.Dimension(parameter.type.resolved,{SyntaxTree.Open});
						arrayDestinationDimension := dim;
						Designate(expression,operand);
					(* case 1a
						P(...,A,...) push: push array descriptor to stack
					*)
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Open THEN
						Designate(expression,operand);
						Emit(Copy(position,arrayDestinationTag,operand.tag,IntermediateCode.Immediate(addressType,size)));
						i := 0;
						WHILE (i< dim) & (type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Open) DO
							type := type.resolved(SyntaxTree.MathArrayType).arrayBase;
							INC(i);
						END;
						type := expression.type.resolved;
						WHILE (i<dim) DO (* remaining static dimensions *)
							GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
							PutMathArrayLength(arrayDestinationTag,tmpOperand.op,i);
							ReleaseOperand(tmpOperand);
							GetMathArrayIncrementAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
							PutMathArrayIncrement(arrayDestinationTag,tmpOperand.op,i);
							ReleaseOperand(tmpOperand);
							INC(i);
						END;
						dimOp := IntermediateCode.Immediate(addressType,dim);
						PutMathArrayField(arrayDestinationTag,dimOp,MathDimOffset);
						PutMathArrayField(arrayDestinationTag,nil,MathFlagsOffset);

					(* case 1d
						P(...,T,...) push: process left arguments, create array descriptor with given s of dimensions from T on stack
						+ case 1e
						P(.. PT() ... );
					*)
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
						Designate(expression,operand);
						Dereference(operand,type.resolved,FALSE);
						DimensionCheck(operand.tag, IntermediateCode.Immediate(sizeType,dim),BreqL);
						Emit(Copy(position,sp(*arrayDestinationTag*),operand.tag,IntermediateCode.Immediate(addressType,size)));
						PutMathArrayField(arrayDestinationTag,nil,MathFlagsOffset);

					(* case 1f
						P(...,S,...) push: create array descriptor to S on stack
						case 1g
						P(... PS()...)
					*)
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Static THEN
						Designate(expression,operand);
						FOR i := 0 TO dim-1 DO
							GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
							PutMathArrayLength(arrayDestinationTag,tmpOperand.op,i);
							ReleaseOperand(tmpOperand);
							GetMathArrayIncrementAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
							PutMathArrayIncrement(arrayDestinationTag,tmpOperand.op,i);
							ReleaseOperand(tmpOperand);
						END;

						(*******
							identify the cases of small vector and matrices, used for optimizations in FoxArrayBase module (Alexey Morozov)
						*)
						arrayFlags := {StaticFlag};
						IF dim = 1 THEN
							GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,0,FALSE,tmpOperand);
							ReleaseOperand(tmpOperand);
							ASSERT(tmpOperand.op.mode = IntermediateCode.ModeImmediate);
							m := LONGINT(tmpOperand.op.intValue);
							IF (m >= 2) & (m <= 8) THEN INCL(arrayFlags,SmallVectorFlag); SetSmallArraySizeFlag(arrayFlags,m); END;
						ELSIF dim = 2 THEN
							GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,0,FALSE,tmpOperand);
							ReleaseOperand(tmpOperand);
							ASSERT(tmpOperand.op.mode = IntermediateCode.ModeImmediate);
							m := LONGINT(tmpOperand.op.intValue);
							GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,1,FALSE,tmpOperand);
							ReleaseOperand(tmpOperand);
							ASSERT(tmpOperand.op.mode = IntermediateCode.ModeImmediate);
							n := LONGINT(tmpOperand.op.intValue);
							IF (m >= 2) & (m <= 8) & (n >= 2) & (n <= 8) THEN
								INCL(arrayFlags,SmallMatrixFlag);
								IF m = n THEN SetSmallArraySizeFlag(arrayFlags,m); END;
							END;
						END;
						(*******)

						dimOp := IntermediateCode.Immediate(addressType,dim);
						PutMathArrayField(arrayDestinationTag,dimOp,MathDimOffset);
						PutMathArrayField(arrayDestinationTag,operand.op,MathAdrOffset);
						PutMathArrayField(arrayDestinationTag,nil,MathPtrOffset);
						PutMathArrayField(arrayDestinationTag,IntermediateCode.Immediate(addressType,SYSTEM.VAL(LONGINT,arrayFlags)),MathFlagsOffset);
						baseType := SemanticChecker.ArrayBase(type,dim);
						tmp := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.AlignedSizeOf(baseType)));
						PutMathArrayField(arrayDestinationTag,tmp,MathElementSizeOffset);
					ELSE HALT(100);
					END;
				(* case 2
					procedure P([left args], var A: array [*,*] of Type, [right args])
				*)
				ELSIF (parameter.type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Open) & (parameter.kind = SyntaxTree.VarParameter) THEN
					dim := SemanticChecker.Dimension(parameter.type.resolved,{SyntaxTree.Open});
					(* case 2b
						P(...,A[a..b,c..d],...) pre: emit range and push array range descriptor, memorize stack position
							push: push reference to pushed array descriptor
							post: remove array descriptor.
					*)
					IF expression IS SyntaxTree.IndexDesignator THEN
						descriptorType := GetMathArrayDescriptorType(dim);
						(* range type : no allocation possible, should be untraced *)
						variable := GetTemporaryVariable(descriptorType, FALSE, TRUE (* untraced *));
						Symbol(variable,variableOp);
						arrayDestinationTag := variableOp.op;
						ReuseCopy(arrayDestinationTag,arrayDestinationTag);
						arrayDestinationDimension := dim;
						NeedDescriptor := TRUE;
						Designate(expression,operand);
						Pass((operand.tag));
						NeedDescriptor := FALSE;
					(* case 2a
						P(...,A,...)
						push: push reference to array descriptor on stack
					*)
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Open THEN
						WHILE (i< dim) & (type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Open) DO
							type := type.resolved(SyntaxTree.MathArrayType).arrayBase;
							INC(i);
						END;
						IF i = dim THEN
							Designate(expression,operand);
							Pass((operand.tag));
						ELSE (* open-static *)
							type := expression.type.resolved;
							descriptorType := GetMathArrayDescriptorType(dim);
							(* static array , cannot be reallocated, untraced !*)
							variable := GetTemporaryVariable(descriptorType, FALSE, TRUE (* untraced *));
							Symbol(variable,variableOp);
							arrayDestinationTag := variableOp.op;
							Designate(expression,operand);
							FOR i := 0 TO dim-1 DO
								GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
								PutMathArrayLength(arrayDestinationTag,tmpOperand.op,i);
								ReleaseOperand(tmpOperand);
								GetMathArrayIncrementAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
								PutMathArrayIncrement(arrayDestinationTag,tmpOperand.op,i);
								ReleaseOperand(tmpOperand);
							END;
							dimOp := IntermediateCode.Immediate(addressType,dim);
							PutMathArrayField(arrayDestinationTag,dimOp,MathDimOffset);
							PutMathArrayField(arrayDestinationTag,operand.op,MathAdrOffset);
							PutMathArrayField(arrayDestinationTag,nil,MathPtrOffset);
							PutMathArrayField(arrayDestinationTag, IntermediateCode.Immediate(addressType,SYSTEM.VAL(LONGINT,{StaticFlag})),MathFlagsOffset);
							baseType := SemanticChecker.ArrayBase(type,dim);
							tmp := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.AlignedSizeOf(baseType)));
							PutMathArrayField(arrayDestinationTag,tmp,MathElementSizeOffset);
							Pass((arrayDestinationTag));
						END;
					(* case 2d
						P(...,T,...) push: emit dimension check, push T
					*)
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
						Designate(expression,operand);
						Dereference(operand,type.resolved,FALSE);
						DimensionCheck(operand.tag, IntermediateCode.Immediate(sizeType,dim),BreqL);
						Pass((operand.tag));
					(* case 2f
						P(...,S,...) pre: allocate array descriptor on stack and memorize stack position
							push: push reference to pushed array descriptor
							post: remove array descriptor
					*)
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Static THEN
						descriptorType := GetMathArrayDescriptorType(dim);
						(* static array -- cannot be reallocatated, untraced *)
						variable := GetTemporaryVariable(descriptorType, FALSE, TRUE (* untraced *));
						Symbol(variable,variableOp);
						arrayDestinationTag := variableOp.op;
						Designate(expression,operand);
						FOR i := 0 TO dim-1 DO
							GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
							PutMathArrayLength(arrayDestinationTag,tmpOperand.op,i);
							ReleaseOperand(tmpOperand);
							GetMathArrayIncrementAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
							PutMathArrayIncrement(arrayDestinationTag,tmpOperand.op,i);
							ReleaseOperand(tmpOperand);
						END;

						(*
							identify the cases of small vector and matrices, used for optimizations in FoxArrayBase module (Alexey Morozov)
						*)
						arrayFlags := {StaticFlag};
						IF dim = 1 THEN
							GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,0,FALSE,tmpOperand);
							ReleaseOperand(tmpOperand);
							ASSERT(tmpOperand.op.mode = IntermediateCode.ModeImmediate);
							m := LONGINT(tmpOperand.op.intValue);
							IF (m >= 2) & (m <= 8) THEN INCL(arrayFlags,SmallVectorFlag); SetSmallArraySizeFlag(arrayFlags,m); END;
						ELSIF dim = 2 THEN
							GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,0,FALSE,tmpOperand);
							ReleaseOperand(tmpOperand);
							ASSERT(tmpOperand.op.mode = IntermediateCode.ModeImmediate);
							m := LONGINT(tmpOperand.op.intValue);
							GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,1,FALSE,tmpOperand);
							ReleaseOperand(tmpOperand);
							ASSERT(tmpOperand.op.mode = IntermediateCode.ModeImmediate);
							n := LONGINT(tmpOperand.op.intValue);
							IF (m >= 2) & (m <= 8) & (n >= 2) & (n <= 8) THEN
								INCL(arrayFlags,SmallMatrixFlag);
								IF m = n THEN SetSmallArraySizeFlag(arrayFlags,m); END;
							END;
						END;
						(*******)

						dimOp := IntermediateCode.Immediate(addressType,dim);
						PutMathArrayField(arrayDestinationTag,dimOp,MathDimOffset);
						PutMathArrayField(arrayDestinationTag,operand.op,MathAdrOffset);
						PutMathArrayField(arrayDestinationTag,nil,MathPtrOffset);
						PutMathArrayField(arrayDestinationTag,IntermediateCode.Immediate(addressType,SYSTEM.VAL(LONGINT,arrayFlags)),MathFlagsOffset);
						baseType := SemanticChecker.ArrayBase(type,dim);
						tmp := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.AlignedSizeOf(baseType)));
						PutMathArrayField(arrayDestinationTag,tmp,MathElementSizeOffset);
						Pass((arrayDestinationTag));
					ELSE HALT(100);
					END;
				(* case 3
					procedure P([left args], [const] A: array [?] of Type, [right args])
				*)
				ELSIF (parameter.type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor) & (parameter.kind IN {SyntaxTree.ConstParameter,SyntaxTree.ValueParameter}) THEN
					dim := SemanticChecker.Dimension(type,{SyntaxTree.Open,SyntaxTree.Static});
					(* case 3b
						P(...,A[a..b,c..d],...)
					*)
					IF (expression IS SyntaxTree.IndexDesignator) & (type.resolved(SyntaxTree.MathArrayType).form # SyntaxTree.Static) THEN
						IF type(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN (* indexer of form a[e,....,?] *)
							variable := PrepareTensorDescriptor(expression(SyntaxTree.IndexDesignator));
							Symbol(variable,variableOp);
							LoadValue(variableOp,system.addressType);
						ELSE
							descriptorType := GetMathArrayDescriptorType(dim);
							(* range -- cannot be reallocated *)
							variable := GetTemporaryVariable(descriptorType, FALSE, TRUE (* untraced *));
							Symbol(variable,variableOp);
						END;
						arrayDestinationTag := variableOp.op;
						ReuseCopy(arrayDestinationTag,arrayDestinationTag);
						arrayDestinationDimension := 0;
						Designate(expression,operand);
						Pass((operand.tag));
					(* case 3a
						P(...,A,...)
					*)
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Open THEN
						i := 0;
						WHILE (i< dim) & (type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Open) DO
							type := type.resolved(SyntaxTree.MathArrayType).arrayBase;
							INC(i);
						END;
						IF i = dim THEN
							Designate(expression,operand);
							Pass((operand.tag));
						ELSE (* open-static *)
							type := expression.type.resolved;
							descriptorType := GetMathArrayDescriptorType(dim);
							(* static array -- cannot be reallocated -- no pointer to be traced *)
							variable := GetTemporaryVariable(descriptorType, FALSE, TRUE (* untraced *));
							Symbol(variable,variableOp);
							arrayDestinationTag := variableOp.op;
							Designate(expression,operand);
							FOR i := 0 TO dim-1 DO
								GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
								PutMathArrayLength(arrayDestinationTag,tmpOperand.op,i);
								ReleaseOperand(tmpOperand);
								GetMathArrayIncrementAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
								PutMathArrayIncrement(arrayDestinationTag,tmpOperand.op,i);
								ReleaseOperand(tmpOperand);
							END;
							dimOp := IntermediateCode.Immediate(addressType,dim);
							PutMathArrayField(arrayDestinationTag,dimOp,MathDimOffset);
							PutMathArrayField(arrayDestinationTag,operand.op,MathAdrOffset);
							PutMathArrayField(arrayDestinationTag,nil,MathPtrOffset);
							PutMathArrayField(arrayDestinationTag,nil,MathFlagsOffset); (* static flag ? *)
							baseType := SemanticChecker.ArrayBase(type,dim);
							tmp := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.AlignedSizeOf(baseType)));
							PutMathArrayField(arrayDestinationTag,tmp,MathElementSizeOffset);
							Pass((arrayDestinationTag));
						END;
					(* case 3d
						P(...,T,...)
						case 3e
						P(...,PT(...),...)
					*)
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
						Designate(expression,operand);
						Dereference(operand,type.resolved,FALSE);
						Pass((operand.tag));
					(* case 3f
						P(...,S,...)
						case 3g
						P(...,PS(...),...)
					*)
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Static THEN
						descriptorType := GetMathArrayDescriptorType(dim);
						(* static array does not need to be traced *)
						variable := GetTemporaryVariable(descriptorType, FALSE, TRUE (* untraced *));
						Symbol(variable,variableOp);
						arrayDestinationTag := variableOp.op;
						Designate(expression,operand);
						IF operand.op.type.length >1 THEN (* vector register *)
							(* static array does not need to be traced *)
							variable2 := GetTemporaryVariable(type, FALSE, TRUE (* untraced *));
							Symbol(variable2, variable2Op);
							MakeMemory(tmp,variable2Op.op,operand.op.type,0);
							Emit(Mov(position,tmp, operand.op));
							ReleaseOperand(operand);
							Symbol(variable2, operand);
						END;

						FOR i := 0 TO dim-1 DO
							GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
							PutMathArrayLength(arrayDestinationTag,tmpOperand.op,i);
							ReleaseOperand(tmpOperand);
							GetMathArrayIncrementAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
							PutMathArrayIncrement(arrayDestinationTag,tmpOperand.op,i);
							ReleaseOperand(tmpOperand);
						END;
						dimOp := IntermediateCode.Immediate(addressType,dim);
						PutMathArrayField(arrayDestinationTag,dimOp,MathDimOffset);
						PutMathArrayField(arrayDestinationTag,operand.op,MathAdrOffset);
						PutMathArrayField(arrayDestinationTag,nil,MathPtrOffset);
						PutMathArrayField(arrayDestinationTag,IntermediateCode.Immediate(addressType,SYSTEM.VAL(LONGINT,{StaticFlag})),MathFlagsOffset);
						baseType := SemanticChecker.ArrayBase(type,dim);
						tmp := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.AlignedSizeOf(baseType)));
						PutMathArrayField(arrayDestinationTag,tmp,MathElementSizeOffset);
						Pass((arrayDestinationTag));
					ELSE HALT(100);
					END;
				ELSIF (parameter.type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor) & (parameter.kind = SyntaxTree.VarParameter) THEN
					dim := SemanticChecker.Dimension(type,{SyntaxTree.Open,SyntaxTree.Static});
					(* case 4b
						P(...,A[a..b,c..d],...)
					*)
					IF (expression IS SyntaxTree.IndexDesignator) & (type.resolved(SyntaxTree.MathArrayType).form # SyntaxTree.Static) THEN
						IF type(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN (* indexer of form a[e,....,?] *)
							variable := PrepareTensorDescriptor(expression(SyntaxTree.IndexDesignator));
							Symbol(variable,variableOp);
							LoadValue(variableOp,system.addressType);
						ELSE
							descriptorType := GetMathArrayDescriptorType(dim);
							(* range array -- cannot be allocated *)
							variable := GetTemporaryVariable(descriptorType, FALSE, TRUE (* untraced *));
							Symbol(variable,variableOp);
						END;
						arrayDestinationTag := variableOp.op;
						ReuseCopy(arrayDestinationTag,arrayDestinationTag);
						arrayDestinationDimension := 0;
						Designate(expression,operand);
						IF type(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
							Symbol(variable,variableOp);
						ELSE
							(* alias to range -- untraced *)
							variable := GetTemporaryVariable(parameter.type.resolved, FALSE, TRUE (* untraced *));
							Symbol(variable,variableOp);
							MakeMemory(tmp,variableOp.op,addressType,0);
							Emit(Mov(position,tmp,operand.tag));
							ReleaseIntermediateOperand(tmp);
						END;
						Pass((variableOp.op));
						ReleaseOperand(variableOp);
					(* case 4a
						P(...,A,...)
					*)
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Open THEN
						i := 0;
						WHILE (i< dim) & (type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Open) DO
							type := type.resolved(SyntaxTree.MathArrayType).arrayBase;
							INC(i);
						END;
						IF i = dim THEN
							Designate(expression,operand);
							arrayDestinationTag := operand.tag;
						ELSE (* open-static *)
							type := expression.type.resolved;
							descriptorType := GetMathArrayDescriptorType(dim);
							(* static array -- untraced *)
							variable := GetTemporaryVariable(descriptorType, FALSE, TRUE (* untraced *));
							Symbol(variable,variableOp);
							arrayDestinationTag := variableOp.op;
							Designate(expression,operand);
							FOR i := 0 TO dim-1 DO
								GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
								PutMathArrayLength(arrayDestinationTag,tmpOperand.op,i);
								ReleaseOperand(tmpOperand);
								GetMathArrayIncrementAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
								PutMathArrayIncrement(arrayDestinationTag,tmpOperand.op,i);
								ReleaseOperand(tmpOperand);
							END;
							dimOp := IntermediateCode.Immediate(addressType,dim);
							PutMathArrayField(arrayDestinationTag,dimOp,MathDimOffset);
							PutMathArrayField(arrayDestinationTag,operand.op,MathAdrOffset);
							PutMathArrayField(arrayDestinationTag,nil,MathPtrOffset);
							PutMathArrayField(arrayDestinationTag,nil,MathFlagsOffset);
							baseType := SemanticChecker.ArrayBase(type,dim);
							tmp := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.AlignedSizeOf(baseType)));
							PutMathArrayField(arrayDestinationTag,tmp,MathElementSizeOffset);
						END;
						(* tensor alias to open array -- untraced *)
						variable := GetTemporaryVariable(parameter.type.resolved, FALSE, TRUE (* untraced *));
						Symbol(variable,variableOp);
						MakeMemory(tmp,variableOp.op,addressType,0);
						Emit(Mov(position,tmp,arrayDestinationTag));
						ReleaseIntermediateOperand(tmp);
						Pass((variableOp.op));
						ReleaseOperand(variableOp);
					(* case 4d
						P(...,T,...)
					*)
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
						Designate(expression,operand);
						Pass((operand.op));
					(* case 4f
						P(...,S,...)
					*)
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Static THEN
						descriptorType := GetMathArrayDescriptorType(dim);
						(* static array -- cannot be reallocated, untraced *)
						variable := GetTemporaryVariable(descriptorType, FALSE, TRUE (* untraced *));
						Symbol(variable,variableOp);
						arrayDestinationTag := variableOp.op;
						Designate(expression,operand);
						FOR i := 0 TO dim-1 DO
							GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
							PutMathArrayLength(arrayDestinationTag,tmpOperand.op,i);
							ReleaseOperand(tmpOperand);
							GetMathArrayIncrementAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
							PutMathArrayIncrement(arrayDestinationTag,tmpOperand.op,i);
							ReleaseOperand(tmpOperand);
						END;
						dimOp := IntermediateCode.Immediate(addressType,dim);
						PutMathArrayField(arrayDestinationTag,dimOp,MathDimOffset);
						PutMathArrayField(arrayDestinationTag,operand.op,MathAdrOffset);
						PutMathArrayField(arrayDestinationTag,nil,MathPtrOffset);
						PutMathArrayField(arrayDestinationTag,IntermediateCode.Immediate(addressType,SYSTEM.VAL(LONGINT,{StaticFlag})),MathFlagsOffset);
						baseType := SemanticChecker.ArrayBase(type,dim);
						tmp := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.AlignedSizeOf(baseType)));
						PutMathArrayField(arrayDestinationTag,tmp,MathElementSizeOffset);
						variable := GetTemporaryVariable(parameter.type.resolved, FALSE, TRUE (* untraced *));
						Symbol(variable,variableOp);
						MakeMemory(tmp,variableOp.op,addressType,0);
						Emit(Mov(position,tmp,arrayDestinationTag));
						ReleaseIntermediateOperand(tmp);
						Pass((variableOp.op));
						ReleaseOperand(variableOp);
					ELSE HALT(100);
					END;
				ELSIF (parameter.type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Static) & (parameter.kind = SyntaxTree.ValueParameter) THEN
					ASSERT(type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Static);
					IF SemanticChecker.CanPassInRegister(system,parameter.type.resolved) THEN
						Evaluate(expression, operand);
						Emit(Push(position, operand.op));
					(*
					ELSIF operand.op.type.length > 1 THEN
						Emit(Push(position, operand.op));
					*)
					ELSE
						Designate(expression,operand);
						ASSERT(operand.op.type.length =1);
						size := system.SizeOf(type);
						Basic.Align(size,system.AlignmentOf(system.parameterAlignment,type));
						size := ToMemoryUnits(system,size);
						Emit(Sub(position,sp,sp,IntermediateCode.Immediate(addressType,size)));
						arrayDestinationTag := sp;
						Emit(Copy(position,arrayDestinationTag,operand.op,IntermediateCode.Immediate(addressType,size)));
					END;
				ELSIF (parameter.type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Static) & (parameter.kind IN {SyntaxTree.VarParameter,SyntaxTree.ConstParameter}) THEN
					Designate(expression,operand);
					IF operand.op.type.length > 1 THEN (* need temporary to pass register *)
						(* static array no pointer *)
						variable := GetTemporaryVariable(parameter.type.resolved, FALSE, TRUE (* untraced *));
						Symbol(variable,variableOp);
						MakeMemory(tmp,variableOp.op,operand.op.type,0);
						Emit(Mov(position,tmp,operand.op));
						Emit(Push(position,variableOp.op));
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Static THEN
						Pass((operand.op));
					ELSE Error(position,"Forbidden non-static actual type. Conversion involved?");
					END;
				ELSE HALT(200)
				END;
			ELSIF parameter.type.resolved IS SyntaxTree.RangeType THEN
				IF parameter.kind = SyntaxTree.VarParameter THEN
					ASSERT(~(expression IS SyntaxTree.RangeExpression));
					Designate(expression, operand);
					Pass((operand.op));
				ELSE
					ASSERT((parameter.kind = SyntaxTree.ValueParameter) OR (parameter.kind = SyntaxTree.ConstParameter));
					Evaluate(expression, operand);
					IF (register >= 0) OR (system.AlignmentOf(system.parameterAlignment,system.lenType) = system.AlignmentOf(system.variableAlignment,system.lenType)) THEN
						Pass((operand.extra)); (* step *)
						Pass((operand.tag)); (* last *)
						Pass((operand.op)); (* first *)
					ELSE
						(* pass range as structure in order to comply with the variable alignment of its components *)
						size := ToMemoryUnits(system,system.AlignedSizeOf(parameter.type));
						Basic.Align(size,ToMemoryUnits(system,system.AlignmentOf(system.parameterAlignment,system.lenType)));
						Emit(Sub(position,sp,sp,IntermediateCode.Immediate(addressType,size)));
						tmp := sp;
						IntermediateCode.MakeMemory(tmp,operand.op.type);
						Emit(Mov(position,tmp,operand.op)); (* first *)
						size := ToMemoryUnits(system,system.AlignedSizeOf(system.lenType));
						IntermediateCode.AddOffset(tmp,size);
						Emit(Mov(position,tmp,operand.tag)); (* last *)
						IntermediateCode.AddOffset(tmp,size);
						Emit(Mov(position,tmp,operand.extra)); (* step *)
					END;
				END
			ELSIF parameter.type.resolved IS SyntaxTree.ComplexType THEN
				IF parameter.kind = SyntaxTree.VarParameter THEN
					Designate(expression, operand);
					Pass((operand.op));
				ELSE
					ASSERT((parameter.kind = SyntaxTree.ValueParameter) OR (parameter.kind = SyntaxTree.ConstParameter));
					Evaluate(expression, operand);
					componentType := parameter.type.resolved(SyntaxTree.ComplexType).componentType;
					IF (register >= 0) OR (system.AlignmentOf(system.parameterAlignment,componentType) = system.AlignmentOf(system.variableAlignment,componentType)) THEN
						Pass((operand.tag)); (* imaginary part *)
						Pass((operand.op)) (* real part *)
					ELSE
						(* pass complex as structure in order to comply with the variable alignment of its components *)
						size := ToMemoryUnits(system,system.AlignedSizeOf(parameter.type));
						Basic.Align(size,ToMemoryUnits(system,system.AlignmentOf(system.parameterAlignment,componentType)));
						Emit(Sub(position,sp,sp,IntermediateCode.Immediate(addressType,size)));
						tmp := sp;
						IntermediateCode.MakeMemory(tmp,operand.op.type);
						Emit(Mov(position,tmp,operand.op)); (* real part *)
						size := ToMemoryUnits(system,system.AlignedSizeOf(componentType));
						IntermediateCode.AddOffset(tmp,size);
						Emit(Mov(position,tmp,operand.tag)); (* imaginary part *)
					END
				END
			ELSE
				IF (parameter.kind = SyntaxTree.ValueParameter) OR (parameter.kind = SyntaxTree.ConstParameter) & ~(parameter.type.resolved IS SyntaxTree.RecordType) & ~(parameter.type.resolved IS SyntaxTree.ArrayType) THEN
					IF (type IS SyntaxTree.RecordType) OR IsStaticArray(parameter.type) THEN
						Designate(expression,operand);
						size := ToMemoryUnits(system,system.SizeOf(parameter.type));
						(* stack allocation *)
						Emit(Sub(position,sp,sp,IntermediateCode.Immediate(addressType,size + (-size) MOD (system.addressSize DIV system.dataUnit))));
						(*! parameter alignment to be discussed ... *)

						IF type IS SyntaxTree.StringType THEN (* source potentially shorter than destination *)
							size := type(SyntaxTree.StringType).length;
						END;
						IF backend.cooperative & parameter.NeedsTrace() THEN
							dst := NewRegisterOperand (addressType);
							Emit(Mov(position,dst, sp));
							IntermediateCode.InitImmediate(null, byteType, 0);
							Emit(Fill(position, dst, IntermediateCode.Immediate(addressType,size), null));
							ReleaseIntermediateOperand(dst);
							SaveRegisters();ReleaseUsedRegisters(saved);
							(* register dst has been freed before SaveRegisters already *)
							CallAssignMethod(dst, operand.op, parameter.type);
							RestoreRegisters(saved);
						END;
						IF operand.op.type.length > 1 THEN (* vector *)
							MakeMemory(tmp,sp,operand.op.type,0);
							Emit(Mov(position, tmp, operand.op));
						ELSE
							Emit(Copy(position,sp,operand.op,IntermediateCode.Immediate(addressType,size)));
						END;
					ELSIF IsOpenArray(parameter.type) THEN
						Designate(expression,operand);
						baseReg := operand.tag;
						IF callingConvention = SyntaxTree.OberonCallingConvention  THEN
							PushArrayLens(parameter.type,type,operand.dimOffset+DynamicDim(parameter.type)-1);
						END;
						Pass((operand.op)); (* address of the array *)
					ELSIF IsDelegate(parameter.type) THEN
						Evaluate(expression,operand);
						IF backend.cooperative & parameter.NeedsTrace() THEN
							Emit(Push(position, nil));
							dst := NewRegisterOperand (addressType);
							Emit(Mov(position,dst, sp));
							ReleaseIntermediateOperand(dst);
							SaveRegisters();ReleaseUsedRegisters(saved);
							Emit(Push(position, dst));
							(* register dst has been freed before SaveRegisters already *)
							Emit(Push(position, operand.tag));
							CallThis(position,"GarbageCollector","Assign",2);
							RestoreRegisters(saved);
						ELSE
							Pass((operand.tag));
						END;
						Pass((operand.op));
					ELSE
						Evaluate(expression,operand);
						IF backend.cooperative & parameter.NeedsTrace() & (operand.op.mode # IntermediateCode.ModeImmediate) THEN
							Emit(Push(position, nil));
							dst := NewRegisterOperand (addressType);
							Emit(Mov(position,dst, sp));
							ReleaseIntermediateOperand(dst);
							SaveRegisters();ReleaseUsedRegisters(saved);
							Emit(Push(position, dst));
							(* register dst has been freed before SaveRegisters already *)
							Emit(Push(position, operand.op));
							CallThis(position,"GarbageCollector","Assign",2);
							RestoreRegisters(saved);
						ELSE
							Pass((operand.op));
						END;
					END;
				ELSIF expression IS SyntaxTree.NilValue THEN (* for special WinAPI rule *)
					Evaluate(expression,operand);
					Pass((operand.op));
				ELSE (* var parameter *)
					Designate(expression,operand);
					IF (type IS SyntaxTree.RecordType) & (parameter.kind IN {SyntaxTree.ConstParameter, SyntaxTree.VarParameter}) THEN
						IF callingConvention = SyntaxTree.OberonCallingConvention  THEN
							Pass((operand.tag));
						END;
					END;
					Pass((operand.op));
				END;
			END;

			(* TODO: needed? *)
			arrayDestinationTag := oldArrayDestinationTag;
			arrayDestinationDimension := oldArrayDestinationDimension;

			IF needsParameterBackup THEN
				(* IF dump # NIL THEN dump.String("backup parameter"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
				ReuseCopy(parameterBackup, operand.op)
			END;

			ReleaseOperand(operand);
			IF Trace THEN TraceExit("PushParameter") END;
		END PushParameter;

		PROCEDURE DesignateInlineCallDesignator(x: SyntaxTree.InlineCallDesignator; VAR result: Operand);
		VAR recentScope: SyntaxTree.Scope; duplicate: BOOLEAN;
			wasInline: BOOLEAN; var: SyntaxTree.Variable; variableDesignator, resultDesignator: SyntaxTree.Expression;
			prevInlineExit: Label;

			PROCEDURE GetTemp(type: SyntaxTree.Type; tryRegister: BOOLEAN): SyntaxTree.Expression;
			VAR
				variable: SyntaxTree.Variable;
				variableDesignator: SyntaxTree.Designator;
			BEGIN
				variable :=  GetTemporaryVariable(type, tryRegister & FitsInRegister(type), FALSE (* untraced *));
				variableDesignator := SyntaxTree.NewSymbolDesignator(Basic.invalidPosition, NIL, NIL, variable);
				variableDesignator.SetType(type);
				RETURN variableDesignator
			END GetTemp;

			PROCEDURE FitsInRegister(type: SyntaxTree.Type): BOOLEAN;
			BEGIN
				RETURN SemanticChecker.CanPassInRegister(system,type)
			END FitsInRegister;

		BEGIN
			recentScope := currentScope;
			wasInline := currentIsInline;
			prevInlineExit := currentInlineExit;
			currentInlineExit := NewLabel();
			currentIsInline := TRUE;
			resultDesignator := procedureResultDesignator;
			procedureResultDesignator := NIL;
			ASSERT(module.system.GenerateVariableOffsets(currentScope));


			(* must be done by checker because the symbol is otherwise not resolved
			localVariable := x.block.scope.firstVariable;
			WHILE (localVariable # NIL) DO
				variableDesignator := GetTemp(localVariable.type, localVariable..);
				x.block.scope.EnterSymbol(SyntaxTree.NewAlias(x.position, localVariable.name, variableDesignator), duplicate);
				ASSERT(~duplicate);
				localVariable := localVariable.nextVariable;
			END;
			*)

			IF x.block.scope # NIL THEN


				IF x.block.scope.outerScope # currentScope THEN
					Printout.Info("x.block.scope",x.block.scope);
					Printout.Info("currentScope",currentScope);
						HALT(100);
				END;
				currentScope := x.block.scope;
				ASSERT(module.system.GenerateVariableOffsets(currentScope));

				var := currentScope.firstVariable;
				WHILE var # NIL DO
					IF var.preferRegister THEN
						IF var.registerNumber < 0 THEN
							var.RegisterNumber(AcquireRegister(IntermediateCode.GetType(system,var.type),IntermediateCode.GeneralPurposeRegister));
							UnuseRegister(var.registerNumber);
						END;
					END;

					IF var.initializer # NIL THEN
						variableDesignator := SyntaxTree.NewSymbolDesignator(var.position,NIL, NIL,var);
						variableDesignator.SetType(var.type.resolved);
						variableDesignator.SetAssignable(TRUE);
						IF SemanticChecker.IsReference(var) THEN
							AssignReference(variableDesignator, var.initializer);
						ELSE
							Assign(variableDesignator,var.initializer);
						END;
					END;

					IF var.registerNumber >= 0 THEN UseRegister(var.registerNumber) END;

					var := var.nextVariable;
				END;
			END;

			IF x.type # NIL THEN
				IF resultDesignator # NIL THEN
					x.block.scope.EnterSymbol(SyntaxTree.NewAlias(x.position, ResultDesignatorName, resultDesignator), duplicate);
				ELSE
					variableDesignator := GetTemp(x.type, TRUE (* try to allocate register *));
					x.SetResult(variableDesignator);
					x.block.scope.EnterSymbol(SyntaxTree.NewAlias(x.position, ResultDesignatorName, variableDesignator), duplicate);
				END;
			END;

			StatementBlock(x.block);
			SetLabel(currentInlineExit);
			var := currentScope.firstVariable;
			WHILE var # NIL DO
				IF var.preferRegister THEN
					Emit(Use(var.position, IntermediateCode.Register(IntermediateCode.GetType(system,var.type),IntermediateCode.GeneralPurposeRegister, var.registerNumber)));
					UnuseRegister(var.registerNumber);
				END;
				var := var.nextVariable;
			END;


			IF (x.type # NIL)  & (x.result # NIL) THEN
(*				IF structuredReturnType THEN
					RestoreRegisters(saved);
					InitOperand(result,ModeReference);
					Symbol(variable,result);
				ELSE
*)
					Designate(x.result, result);
(*
				END;
*)
			END;
			(* the inline scope must end here as the designation of the result may involve symbols in the inline scope *)
			currentScope := recentScope;

			currentInlineExit := prevInlineExit;
			currentIsInline := wasInline;
		END DesignateInlineCallDesignator;

		PROCEDURE DesignateProcedureCallDesignator(x: SyntaxTree.ProcedureCallDesignator; VAR result: Operand);
		VAR
			parameters: SyntaxTree.ExpressionList;
			d, resultDesignator, actualParameter: SyntaxTree.Expression;
			procedureType: SyntaxTree.ProcedureType;
			formalParameter: SyntaxTree.Parameter;
			operand: Operand;
			reg, size, mask, dest: IntermediateCode.Operand;
			saved,saved2: RegisterEntry;
			symbol: SyntaxTree.Symbol;
			variable: SyntaxTree.Variable;
			i,  parametersSize : LONGINT;
			structuredReturnType: BOOLEAN;
			gap, alignment: LONGINT; (*fld*)
			return: IntermediateCode.Operand;

			parameterBackups: ARRAY 2 OF IntermediateCode.Operand;
			arg: IntermediateCode.Operand;
			dummy: IntermediateCode.Operand;
			recordType: SyntaxTree.RecordType;
			operatorSelectionProcedureOperand: Operand;
			operatorSelectionProcedure: SyntaxTree.Procedure;
			fingerprint: SyntaxTree.Fingerprint;
			isCallOfDynamicOperator, hasDynamicOperands: BOOLEAN;
			identifierNumber: LONGINT;

			parameterRegisters: SIZE;
			registers: ARRAY 64 OF WORD;
			callingConvention: SyntaxTree.CallingConvention;
			type: IntermediateCode.Type;

			firstWriteBackCall, currentWriteBackCall: WriteBackCall;

			(** do preparations before parameter push for array-structured object types (ASOTs):
				if ASOT is passed as VAR parameter:
				- allocate temporary variable of math array type
				- copy contents of ASOT to be passed to temporary variable
				- use temporary variable as the actual parameter instead
				- create and store a write-back call in a list (an index operator call that writes the contents of the temp. variable back into the ASOT)
			**)
			PROCEDURE PrepareParameter(VAR actualParameter: SyntaxTree.Expression; formalParameter: SyntaxTree.Parameter);
			VAR
				expression, left: SyntaxTree.Expression; tempVariableDesignator : SyntaxTree.Designator;
			BEGIN
				IF (formalParameter.kind = SyntaxTree.VarParameter) & SemanticChecker.IsIndexOperator(actualParameter) THEN
					WITH actualParameter: SyntaxTree.ProcedureCallDesignator DO
						(* prepare writeback for any other "normal" indexer *)
						variable := GetTemporaryVariable(actualParameter.type.resolved, FALSE, TRUE (* untraced *));
						tempVariableDesignator := SyntaxTree.NewSymbolDesignator(Basic.invalidPosition, NIL, NIL, variable);
						tempVariableDesignator.SetType(actualParameter.type.resolved);
						Assign(tempVariableDesignator, actualParameter);
						IF firstWriteBackCall = NIL THEN
							NEW(firstWriteBackCall);
							currentWriteBackCall := firstWriteBackCall
						ELSE
							ASSERT(currentWriteBackCall # NIL);
							NEW(currentWriteBackCall.next);
							currentWriteBackCall := currentWriteBackCall.next
						END;

						(* a [^] . P[] ()*)
						left := actualParameter.left; (* procedure call designator --> procedure call *)
						left := left(SyntaxTree.Designator).left; (* procedure call --> caller object *)
						IF left IS SyntaxTree.DereferenceDesignator THEN (* dereference, if required *)
							left := left(SyntaxTree.Designator).left;
						END;
						expression := checker.NewObjectOperatorCall(Basic.invalidPosition, left, 0, actualParameter.parameters, tempVariableDesignator);
						currentWriteBackCall.call := expression(SyntaxTree.ProcedureCallDesignator);
					END;
					actualParameter := tempVariableDesignator;
				END
			END PrepareParameter;

		BEGIN
			IF Trace THEN TraceEnter("DesignateProcedureCallDesignator") END;

			resultDesignator := procedureResultDesignator; procedureResultDesignator := NIL;
			procedureType := x.left.type.resolved(SyntaxTree.ProcedureType);
			callingConvention := procedureType.callingConvention;

			dest := destination; destination := emptyOperand;
			SaveRegisters();ReleaseUsedRegisters(saved);

			parameters := x.parameters;

			IF (x.left IS SyntaxTree.SymbolDesignator) & (x.left(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Operator) THEN
				(* an operator is called *)
				(* IF dump # NIL THEN dump.String("*** begin of operator call ***"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
				ASSERT(callingConvention = SyntaxTree.OberonCallingConvention);

				(* check if a dynamic operator call should be performed *)
				isCallOfDynamicOperator := x.left(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Operator).isDynamic;
			ELSE
				isCallOfDynamicOperator := FALSE
			END;

			IF backend.cooperative & (callingConvention = SyntaxTree.WinAPICallingConvention) THEN
				Emit(Push(position, ap));
			END;

			alignment := procedureType.stackAlignment;
			IF (callingConvention IN SysvABIorWINAPI) & (system.addressSize = 64) THEN
				alignment := 16 (* bytes *);
			END;
			IF alignment > 1 THEN
				IntermediateCode.InitRegister(reg,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
				Emit(Mov(position,reg, sp));
				gap := ParametersSize(system, procedureType,FALSE); (* account for all parameters being pushed *)
				IF (callingConvention = SyntaxTree.WinAPICallingConvention) & (system.addressSize =64) THEN
					IF gap < 4*ToMemoryUnits(system,system.addressSize) THEN (* in WINAPI 64bit there is at least space for four registers on the stack *)
						gap := 4*ToMemoryUnits(system,system.addressSize);
					END;
				ELSIF (callingConvention IN SysvABI) & (system.addressSize =64) THEN
					backend.ResetParameterRegisters();
					formalParameter := procedureType.firstParameter;
					FOR i := 0 TO parameters.Length()-1 DO
						IF (formalParameter.kind = SyntaxTree.VarParameter) THEN
							type := addressType;
						ELSIF formalParameter.type.IsRecordType() OR (formalParameter.type.resolved IS SyntaxTree.ArrayType) THEN
							type := addressType;
						ELSE
							type := GetType(system, formalParameter.type);
						END;
						IF backend.GetParameterRegister(callingConvention, type, registers[i]) THEN
							DEC (gap, ToMemoryUnits(system,system.addressSize))
						END;
						formalParameter := formalParameter.nextParameter;
					END;
					IF gap < 0 THEN
						gap := 0
					END;
				ELSE
					gap := gap + ToMemoryUnits(system,system.offsetFirstParameter)	(* Oberon CC: alignment at the BP in the stack frame *)
				END;
				gap := gap + ToMemoryUnits(system,system.addressSize); (* account for the additionally pushed stack pointer in any case *)

				Emit(Sub(position,sp, sp, IntermediateCode.Immediate(addressType,gap)));
				IntermediateCode.InitImmediate(mask,addressType,-alignment);
				Emit(And(position,sp, sp, mask));
				Emit(Add(position, sp, sp, IntermediateCode.Immediate(addressType, gap)));
				Emit(Push(position,reg));
				ReleaseIntermediateOperand(reg);
			END;

			IF (callingConvention IN SysvABI) & (system.addressSize = 32) THEN
				(* align stack to 16-byte boundary *)
				IntermediateCode.InitImmediate(mask,addressType,-16);
				Emit(And(position,sp, sp, mask));
				gap := (-ParametersSize( system, procedureType, FALSE )) MOD 16;
				IF gap # 0 THEN
					IntermediateCode.InitImmediate(size,addressType,gap);
					Emit(Sub(position,sp,sp,size))
				END;
			END;

			IF x.left IS SyntaxTree.SupercallDesignator THEN
				symbol := x.left(SyntaxTree.SupercallDesignator).left(SyntaxTree.SymbolDesignator).symbol;
			ELSIF x.left IS SyntaxTree.IndexDesignator THEN
				symbol := x.left(SyntaxTree.IndexDesignator).left(SyntaxTree.SymbolDesignator).symbol;
			ELSE
				symbol := x.left(SyntaxTree.SymbolDesignator).symbol;
			END;

			IF procedureType.selfParameter # NIL THEN (* type bound procedure in a record *)
				Designate(x.left(SyntaxTree.Designator).left, operand);
				Emit(Push(position, operand.tag));
				Emit(Push(position, operand.op));
				Symbol(symbol, operand);
				LoadValue(operand, symbol.type);
				(*
				PushParameter(x.left(SyntaxTree.Designator).left, procedureType.selfParameter, callingConvention, FALSE, dummy,-1);
				Evaluate(x.left, operand);
				*)
			ELSE

				Evaluate(x.left, operand);

				IF symbol IS SyntaxTree.Procedure THEN
					IF (procedureType.selfParameter # NIL) THEN
						Emit(Push(position,operand.tag));
					ELSIF x.left IS SyntaxTree.SupercallDesignator THEN
						Emit(Push(position,operand.tag));
					ELSIF (procedureType.isDelegate) THEN
						Emit(Push(position,operand.tag));
					END;
				ELSIF (symbol IS SyntaxTree.Variable) OR (symbol IS SyntaxTree.Parameter) THEN
					IF (procedureType.selfParameter # NIL) THEN
						Emit(Push(position,operand.tag));
					ELSIF (procedureType.isDelegate) THEN (* push self pointer only if procedure is a method *)
						Emit(Push(position,operand.tag));
					END;
				ELSE HALT(200);
				END;
			END;

			ReleaseIntermediateOperand(operand.tag);
			operand.tag := emptyOperand;

			(* determine if a structured return type is needed *)
			structuredReturnType := SemanticChecker.StructuredReturnType(system,procedureType);

			IF structuredReturnType THEN
				IF resultDesignator  # NIL THEN
					d := resultDesignator;
				ELSE
					(* temporary result that might be allocated, must potentially be traced *)
					variable := GetTemporaryVariable(procedureType.returnType, FALSE, procedureType.hasUntracedReturn);
					d := SyntaxTree.NewSymbolDesignator(Basic.invalidPosition,NIL,NIL, variable);
					d.SetType(variable.type);
				END;
				(*IF (procedureType.returnType.resolved IS SyntaxTree.RecordType) THEN
					Designate(d,returnValue);
					returnTypeSize := system.SizeOf(procedureType.returnType.resolved);
					size := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,returnTypeSize));
					Emit(Push(position,size));
					Emit(Push(position,returnValue.op));
					ReleaseOperand(returnValue);
				ELSE*)
					PushParameter(d,procedureType.returnParameter,callingConvention, FALSE, dummy,-1)
					(*
				END;
				*)
			END;

			IF callingConvention # SyntaxTree.OberonCallingConvention THEN
				parameterRegisters := 0;

				backend.ResetParameterRegisters();

				formalParameter := procedureType.firstParameter;
				FOR i := 0 TO parameters.Length()-1 DO
					IF (formalParameter.kind = SyntaxTree.VarParameter) THEN
						type := addressType;
					ELSIF formalParameter.type.IsRecordType() OR (formalParameter.type.resolved IS SyntaxTree.ArrayType) THEN
						type := addressType;
					ELSE
						type := GetType(system, formalParameter.type);
					END;
					IF backend.GetParameterRegister(callingConvention, type, registers[i]) THEN
						INC(parameterRegisters);
						IF ~PassInRegister(formalParameter,callingConvention) THEN
							Error(actualParameter.position,"cannot be passed by register")
						END;
					ELSE
						registers[i] := -1;
					END;
					formalParameter := formalParameter.nextParameter;
				END;
				formalParameter := procedureType.lastParameter;
				FOR i := parameters.Length() - 1 TO 0 BY -1 DO
					actualParameter := parameters.GetExpression(i);
					PushParameter(actualParameter, formalParameter, callingConvention, FALSE, dummy, registers[i]);
					formalParameter := formalParameter.prevParameter;
				END;
				IF (callingConvention = SyntaxTree.WinAPICallingConvention) & (addressType.sizeInBits = 64)  THEN
					(* WINAPI: always (!) reserve 4 addresses for fastcall registers *)
					Emit(Sub(position,sp,sp,IntermediateCode.Immediate(addressType,32)));
				END;
			ELSE
				hasDynamicOperands := FALSE;
				formalParameter := procedureType.firstParameter;
				FOR i := 0 TO parameters.Length() - 1 DO
					actualParameter := parameters.GetExpression(i);
					PrepareParameter(actualParameter, formalParameter);

					IF formalParameter # NIL THEN (* TENTATIVE *)
						IF isCallOfDynamicOperator  & IsStrictlyPointerToRecord(formalParameter.type) & (formalParameter.access # SyntaxTree.Hidden) THEN (* TODO: remove hidden parameters *)
							ASSERT(i < 2);
							hasDynamicOperands := TRUE;
							PushParameter(actualParameter, formalParameter, callingConvention, TRUE, parameterBackups[i],-1)
						ELSE
							PushParameter(actualParameter, formalParameter, callingConvention, FALSE, dummy,-1);
						END;
						formalParameter := formalParameter.nextParameter;
					END;
				END;
			END;

			IF symbol IS SyntaxTree.Procedure THEN
				IF IsNested(symbol(SyntaxTree.Procedure)) THEN
					GetBaseRegister(reg,currentScope,symbol.scope); (* static link, may be fp or [fp+8] (if nested proc calls itself) *)
					Emit(Push(position,reg));
					ReleaseIntermediateOperand(reg);
				END;
				parametersSize := ProcParametersSize(symbol(SyntaxTree.Procedure));
			ELSIF (symbol IS SyntaxTree.Variable) OR (symbol IS SyntaxTree.Parameter) THEN
				parametersSize := ParametersSize(system,procedureType, FALSE);
			END;

			IF isCallOfDynamicOperator & hasDynamicOperands THEN
			(*
				dynamic operator overloading:
				first push parameters, regularly:
				[self]
				par1
				par2

				then push parameters for GetOperator
				identifier
				ptr1
				tag
				ptr2
				tag
				call GetOperatorRuntimeProc

				call Operator
			*)
				IF dump # NIL THEN dump.String("++++++++++ dynamic operator call ++++++++++"); dump.Ln; dump.Update END; (* TENTATIVE *)
				(* push ID *)
				(* IF dump # NIL THEN dump.String("push ID"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
				ASSERT(x.left IS SyntaxTree.SymbolDesignator);
				identifierNumber := Global.GetSymbol(module.module.case, x.left(SyntaxTree.SymbolDesignator).symbol.name);
				Emit(Push(position,IntermediateCode.Immediate(IntermediateCode.GetType(system, system.longintType), identifierNumber)));

				formalParameter := procedureType.firstParameter;
				FOR i := 0 TO parameters.Length() - 1 DO
					IF formalParameter.access # SyntaxTree.Hidden THEN
						ASSERT(i < 2);
						IF IsStrictlyPointerToRecord(formalParameter.type) THEN
							(* push pointer *)
							(* IF dump # NIL THEN dump.String("push pointer"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
							IF formalParameter.kind = SyntaxTree.VarParameter THEN
								(* add dereference *)
								(* IF dump # NIL THEN dump.String("dereference pointer"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
							(*! better: do refer to stack above than using parameter backups !!*)
								ReleaseIntermediateOperand(parameterBackups[i]);
								MakeMemory(parameterBackups[i], parameterBackups[i], addressType, 0)
							END;
							Emit(Push(position,parameterBackups[i]));
							ReleaseIntermediateOperand(parameterBackups[i]);

							(* push typetag *)
							(* IF dump # NIL THEN dump.String("push typetag"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
							recordType := formalParameter.type.resolved(SyntaxTree.PointerType).pointerBase.resolved(SyntaxTree.RecordType);
							arg := TypeDescriptorAdr(recordType);
							Emit(Push(position,arg));
						ELSE
							(* push 'NonPointer' *)
							(* IF dump # NIL THEN dump.String("push 'NonPointer'"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
							Emit(Push(position,IntermediateCode.Immediate(IntermediateCode.GetType(system, system.longintType), NonPointer)));

							(* push fingerprint *)
							(* IF dump # NIL THEN dump.String("push fingerprint"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
							fingerprint := fingerprinter.TypeFP(formalParameter.type.resolved);
							Emit(Push(position,IntermediateCode.Immediate(IntermediateCode.GetType(system, system.hugeintType), fingerprint.public))) (* TODO: push the type's fingerprint *)
						END
					END;
					formalParameter := formalParameter.nextParameter
				END;

				(* for unary operators: complete the information for the second parameter *)
				IF procedureType.numberParameters < 2 THEN
					(* push 'NonPointer' *)
					(* IF dump # NIL THEN dump.String("push 'NonPointer'"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
					Emit(Push(position,IntermediateCode.Immediate(IntermediateCode.GetType(system, system.longintType), NonPointer)));

					(* push 'NoType' *)
					(* IF dump # NIL THEN dump.String("push 'NoType'"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
					Emit(Push(position,IntermediateCode.Immediate(IntermediateCode.GetType(system, system.longintType), NoType)));
				END;

				(* call operator selection procedure *)
				IF GetRuntimeProcedure("FoxOperatorRuntime", "SelectOperator", operatorSelectionProcedure, TRUE) THEN
					StaticCallOperand(operatorSelectionProcedure,operatorSelectionProcedureOperand);
					Emit(Call(position,operatorSelectionProcedureOperand.op, ProcParametersSize( operatorSelectionProcedure)));
					ReleaseOperand(operatorSelectionProcedureOperand);

					(* use the address that the operator selection procedure returned as the target address of the call *)
					InitOperand(operand, ModeValue);
					operand.op := IntermediateCode.Register(addressType, IntermediateCode.GeneralPurposeRegister, AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
					Emit(Result(position,operand.op))
				END
			END;


			IF ~(symbol IS SyntaxTree.Procedure) & backend.trackLeave & ~isUntracked & (callingConvention IN {SyntaxTree.WinAPICallingConvention, SyntaxTree.CCallingConvention}) THEN
				SaveRegisters();ReleaseUsedRegisters(saved2);
				CallThis(position,"Objects","LeaveA2",0);
				RestoreRegisters(saved2);
			END;


			IF (callingConvention = SyntaxTree.WinAPICallingConvention) OR (callingConvention IN SysvABI) THEN
				Emit(Call(position,operand.op,0));
			ELSE
				Emit(Call(position,operand.op,parametersSize));
			END;

			ReleaseParameterRegisters();
			ReleaseOperand(operand);

			IF procedureType.noReturn THEN
				EmitTrap(position,NoReturnTrap);
			END;

			IF (procedureType.returnType # NIL) & ~structuredReturnType THEN
				return := NewRegisterOperand(IntermediateCode.GetType(system,procedureType.returnType));
				Emit(Result(position,return));
			END;

			IF  ~(symbol IS SyntaxTree.Procedure) & backend.trackLeave & ~isUntracked & (callingConvention  IN {SyntaxTree.WinAPICallingConvention, SyntaxTree.CCallingConvention}) THEN
				IF  (procedureType.returnType # NIL) & ~structuredReturnType  THEN
					Emit(Push(position, return));
					CallThis(position,"Objects","ReenterA2",0);
					Emit(Pop(position, return));
				ELSE
					CallThis(position,"Objects","ReenterA2",0);
				END;
			END;

			(* === return parameter space === *)
				IF (callingConvention = SyntaxTree.WinAPICallingConvention) & (addressType.sizeInBits = 64)  THEN
				parametersSize := ToMemoryUnits(system,parameters.Length()*addressType.sizeInBits);
				(* cleanup all space for all parameters *)
				IF parametersSize < 32 THEN
					(* allocated space for all parameter registers -- this is the least we have to cleanup *)
					parametersSize := 32
				END;
				size := IntermediateCode.Immediate(addressType,parametersSize);
				Emit(Add(position,sp,sp,size))
			END;

			IF (callingConvention IN SysvABI) THEN
				IF parameterRegisters > 0 THEN
					IF parameters.Length() > parameterRegisters THEN
						parametersSize := ToMemoryUnits(system,(parameters.Length()-parameterRegisters)*addressType.sizeInBits)
					ELSE
						parametersSize := 0
					END;
				ELSE
					parametersSize := ToMemoryUnits(system,parameters.Length()*addressType.sizeInBits);
					INC( parametersSize, (-parametersSize) MOD 16 )
				END;
				IF parametersSize > 0 THEN
					size := IntermediateCode.Immediate(addressType,parametersSize);
					Emit(Add(position,sp,sp,size))
				END;
			END;

			IF alignment > 1 THEN
				Emit(Pop(position,sp));
			END;

			IF backend.cooperative & (callingConvention = SyntaxTree.WinAPICallingConvention) THEN
				Emit(Pop(position, ap));
			END;

			IF firstWriteBackCall # NIL THEN
				SaveRegisters(); ReleaseUsedRegisters(saved2);
				(* perform all write-back calls in the list *)
				currentWriteBackCall := firstWriteBackCall;
				WHILE currentWriteBackCall # NIL DO
					DesignateProcedureCallDesignator(currentWriteBackCall.call, result);
					currentWriteBackCall := currentWriteBackCall.next
				END;
				RestoreRegisters(saved2);
			END;

			IF (resultDesignator = NIL) & (procedureType.returnType # NIL) THEN
				IF structuredReturnType THEN
					RestoreRegisters(saved);
					InitOperand(result,ModeReference);
					Symbol(variable,result);
				ELSE
					RestoreRegisters(saved);
					InitOperand(result,ModeValue);
					result.op := return;
				END;
			END;

			destination := dest;

			IF Trace THEN TraceExit("DesignateProcedureCallDesignator") END;
		END DesignateProcedureCallDesignator;

		PROCEDURE TypeDescriptorAdr(t: SyntaxTree.Type): IntermediateCode.Operand;
		VAR res: IntermediateCode.Operand; offset: LONGINT; name: Basic.SegmentedName;

			td: SyntaxTree.Symbol;

			PROCEDURE GetHiddenPointerType(): SyntaxTree.Type;
			VAR scope: SyntaxTree.RecordScope; variable: SyntaxTree.Variable; typeDeclaration: SyntaxTree.TypeDeclaration;
			BEGIN
				IF (hiddenPointerType = NIL) OR (hiddenPointerType.typeDeclaration.scope.ownerModule # module.module) THEN
					scope := SyntaxTree.NewRecordScope(module.module.moduleScope);
					variable := SyntaxTree.NewVariable(Basic.invalidPosition,SyntaxTree.NewIdentifier("@Any"));
					variable.SetType(system.anyType);
					scope.AddVariable(variable);
					hiddenPointerType := SyntaxTree.NewRecordType(Basic.invalidPosition,NIL,scope);
					typeDeclaration := SyntaxTree.NewTypeDeclaration(Basic.invalidPosition,SyntaxTree.NewIdentifier("@HdPtrDesc"));
					typeDeclaration.SetDeclaredType(hiddenPointerType);
					typeDeclaration.SetScope(module.module.moduleScope);
					hiddenPointerType.SetTypeDeclaration(typeDeclaration);
					hiddenPointerType.SetState(SyntaxTree.Resolved);
				END;
				RETURN hiddenPointerType;
			END GetHiddenPointerType;

			PROCEDURE GetDelegateType(): SyntaxTree.Type;
			VAR scope: SyntaxTree.RecordScope; variable: SyntaxTree.Variable; typeDeclaration: SyntaxTree.TypeDeclaration;
			BEGIN
				IF (delegatePointerType = NIL) OR (delegatePointerType.typeDeclaration.scope.ownerModule # module.module) THEN
					scope := SyntaxTree.NewRecordScope(module.module.moduleScope);
					variable := SyntaxTree.NewVariable(Basic.invalidPosition,SyntaxTree.NewIdentifier("@Procedure"));
					variable.SetType(SyntaxTree.NewProcedureType(Basic.invalidPosition,NIL));
					scope.AddVariable(variable);
					variable := SyntaxTree.NewVariable(Basic.invalidPosition,SyntaxTree.NewIdentifier("@Any"));
					variable.SetType(system.anyType);
					scope.AddVariable(variable);
					delegatePointerType := SyntaxTree.NewRecordType(Basic.invalidPosition,NIL,scope);
					typeDeclaration := SyntaxTree.NewTypeDeclaration(Basic.invalidPosition,SyntaxTree.NewIdentifier("@Delegate"));
					typeDeclaration.SetDeclaredType(delegatePointerType);
					typeDeclaration.SetScope(module.module.moduleScope);
					delegatePointerType.SetTypeDeclaration(typeDeclaration);
					delegatePointerType.SetState(SyntaxTree.Resolved);
				END;
				RETURN delegatePointerType
			END GetDelegateType;

			PROCEDURE GetBackendType(x: SyntaxTree.Type; VAR offset: LONGINT; VAR name: Basic.SegmentedName): SyntaxTree.Symbol;
			(* create anonymous type declaration for types that need a type descriptor but have been declared anonymously
				such as in VAR a: RECORD ... END;
				reason: type desciptors in Sections are then accessible via a type declaration symbol and for types
				and variables, constants and procedures the same mechanism can be used for fixups etc.
			*)
			VAR  source: Sections.Section;td: SyntaxTree.TypeDeclaration;
				baseRecord: SyntaxTree.RecordType;
			BEGIN (* no code emission *)
				source := NIL;
				x := x.resolved;
				IF (x IS SyntaxTree.AnyType) OR (x IS SyntaxTree.PointerType) THEN
					x := GetHiddenPointerType();
				ELSIF IsDelegate(x) THEN
					x := GetDelegateType();
				ELSIF (x IS SyntaxTree.RecordType) OR (x IS SyntaxTree.CellType) THEN
				ELSE HALT(200);
				END;

				td := x.typeDeclaration;
				IF td = NIL THEN
					ASSERT(x(SyntaxTree.RecordType).pointerType # NIL);
					td := x(SyntaxTree.RecordType).pointerType.resolved.typeDeclaration;
					ASSERT(td # NIL);
				END;

				GetCodeSectionNameForSymbol(td,name);
				IF (td.scope = NIL) OR (td.scope.ownerModule = module.module) THEN
					meta.CheckTypeDeclaration(x);
					source := NewSection(module.allSections, Sections.ConstSection, name,td,commentPrintout # NIL);
				ELSE
					source := NewSection(module.importedSections, Sections.ConstSection,name,td,commentPrintout # NIL);
				END;
				IF backend.cooperative OR meta.simple THEN
					offset := 0;
				ELSE
					IF x IS SyntaxTree.CellType THEN
						baseRecord := x(SyntaxTree.CellType).GetBaseRecord();
						IF baseRecord = NIL THEN
							offset := ToMemoryUnits(system, meta.GetTypeRecordBaseOffset(0));
						ELSE
							offset := ToMemoryUnits(system, meta.GetTypeRecordBaseOffset(baseRecord.recordScope.numberMethods)*system.addressSize);
						END;
					ELSE
						offset := ToMemoryUnits(system,meta.GetTypeRecordBaseOffset(x(SyntaxTree.RecordType).recordScope.numberMethods)*system.addressSize);
					END;
				END;
				RETURN td
			END GetBackendType;

		BEGIN
			(*td := t.typeDeclaration;*)
			td := GetBackendType(t,offset,name); (*! do not dereference a pointer here as the type descriptor for the pointer might be asked for *)
			(*
			IF t IS SyntaxTree.PointerType THEN
				source := GetBackendType(t(SyntaxTree.PointerType).pointerBase.resolved);
			ELSE
				source := GetBackendType(t);
			END;
			*)
			IntermediateCode.InitAddress(res, addressType, name, GetFingerprint(td), 0 (*
			1+t(SyntaxTree.RecordType).recordScope.numberMethods+16+1 *));
			IntermediateCode.SetOffset(res,offset);
			(*
			IntermediateCode.MakeMemory(res,IntermediateCode.UnsignedInteger,addressType.sizeInBits);
			make memory should be used when tag is used, not earlier
			*)

			RETURN res
		END TypeDescriptorAdr;

		(*
		PROCEDURE MakeTypeTag(VAR operand: Operand);
		VAR result: IntermediateCode.Operand;
		BEGIN
			IF operand.tag.mode = IntermediateCode.Undefined THEN
				operand.tag := TypeDescriptorAdr(operand.type);
				IntermediateCode.MakeMemory(operand.tag,addressType);
				UseIntermediateOperand(operand.tag);
			END;
		END MakeTypeTag;
		*)

		PROCEDURE ProfilerInit;
		VAR reg: IntermediateCode.Operand;
		BEGIN
			IntermediateCode.InitAddress(reg, addressType, profileInit.name , GetFingerprint(profileInit.symbol), 0);
			Emit(Call(position,reg,0));
		END ProfilerInit;

		PROCEDURE ProfilerEnterExit(procedureNumber: LONGINT; enter: BOOLEAN);
		VAR reg: IntermediateCode.Operand; result: Operand; procedure: SyntaxTree.Procedure;
		BEGIN
			IF enter & GetRuntimeProcedure("FoxProfiler","EnterProcedure",procedure,TRUE)
			OR ~enter & GetRuntimeProcedure("FoxProfiler","ExitProcedure",procedure,TRUE)
			THEN
				IntermediateCode.InitAddress(reg, addressType, profileId.name , GetFingerprint(profileId.symbol), 0);
				IntermediateCode.MakeMemory(reg, IntermediateCode.GetType(system,system.longintType));
				Emit(Push(position,reg));
				IntermediateCode.InitImmediate(reg, IntermediateCode.GetType(system,system.longintType), procedureNumber);
				Emit(Push(position,reg));
				StaticCallOperand(procedure,result);
				Emit(Call(position,result.op,ProcParametersSize(procedure)));
				ReleaseOperand(result);
			END;
		END ProfilerEnterExit;

		PROCEDURE ProfilerAddProcedure(procedureNumber: LONGINT; CONST name: ARRAY OF CHAR);
		VAR string: SyntaxTree.String; reg: IntermediateCode.Operand; result: Operand; procedure: SyntaxTree.Procedure; sv: SyntaxTree.StringValue;type: SyntaxTree.Type;
		BEGIN
			IF GetRuntimeProcedure("FoxProfiler","AddProcedure",procedure,TRUE) THEN
				IntermediateCode.InitAddress(reg, addressType, profileId.name , GetFingerprint(profileId.symbol), 0);
				IntermediateCode.MakeMemory(reg, IntermediateCode.GetType(system,system.longintType));
				profileInit.Emit(Push(position,reg));
				IntermediateCode.InitImmediate(reg, IntermediateCode.GetType(system,system.longintType), procedureNumber);
				profileInit.Emit(Push(position,reg));
				NEW(string, LEN(name)); COPY(name, string^);
				sv := SyntaxTree.NewStringValue(Basic.invalidPosition,string);
				type := SyntaxTree.NewStringType(Basic.invalidPosition,system.characterType,Strings.Length(name));
				sv.SetType(type);
				Designate(sv,result);
				profileInit.Emit(Push(position,result.tag));
				profileInit.Emit(Push(position,result.op));
				StaticCallOperand(procedure,result);
				profileInit.Emit(Call(position,result.op,ProcParametersSize(procedure)));
				ReleaseOperand(result);
			END;
		END ProfilerAddProcedure;

		PROCEDURE ProfilerAddModule(CONST name: ARRAY OF CHAR);
		VAR string: SyntaxTree.String; sv: SyntaxTree.StringValue; type: SyntaxTree.Type; result: Operand;  reg: IntermediateCode.Operand; procedure: SyntaxTree.Procedure;
		BEGIN
			IF GetRuntimeProcedure("FoxProfiler","AddModule",procedure,TRUE) THEN
				IntermediateCode.InitAddress(reg, addressType, profileId.name , GetFingerprint(profileId.symbol), 0);
				profileInit.Emit(Push(position,reg));
				profileInitPatchPosition := profileInit.pc;
				profileInit.Emit(Nop(position)); (* placeholder, will be patched by number of procedures *)
				NEW(string, LEN(name)); COPY(name, string^);
				sv := SyntaxTree.NewStringValue(Basic.invalidPosition, string);
				type := SyntaxTree.NewStringType(Basic.invalidPosition,system.characterType,Strings.Length(name));
				sv.SetType(type);
				Designate(sv,result);
				profileInit.Emit(Push(position,result.tag));
				profileInit.Emit(Push(position,result.op));
				StaticCallOperand(procedure,result);
				profileInit.Emit(Call(position,result.op,ProcParametersSize(procedure)));
				ReleaseOperand(result);
			END;
		END ProfilerAddModule;

		PROCEDURE ProfilerPatchInit;
		VAR reg: IntermediateCode.Operand;
		BEGIN
			IntermediateCode.InitImmediate(reg, IntermediateCode.GetType(system,system.longintType), numberProcedures);
			profileInit.EmitAt(profileInitPatchPosition,Push(position,reg));
			EmitLeave(profileInit,position,NIL,0);
			profileInit.Emit(Exit(position,0,0,0));
		END ProfilerPatchInit;

		(** if operator can be overloaded dynamically, emit code that registers it in the runtime **)
		PROCEDURE RegisterDynamicOperator(operator: SyntaxTree.Operator);
		VAR
			id: LONGINT;
			leftType, rightType: SyntaxTree.Type;
			procedureType: SyntaxTree.ProcedureType;
			runtimeProcedure: SyntaxTree.Procedure;
			runtimeProcedureOperand, operatorOperand: Operand;
			kind: SET;

			PROCEDURE PushTypeInfo(type: SyntaxTree.Type);
			VAR
				arg: IntermediateCode.Operand;
				recordType: SyntaxTree.RecordType;
				fingerprint: SyntaxTree.Fingerprint;
			BEGIN
				IF type = NIL THEN
					(* no type: push 'NoType' *)
					(* IF dump # NIL THEN dump.String("push 'NoType'"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
					arg := IntermediateCode.Immediate(IntermediateCode.GetType(system, system.longintType), NoType)
				ELSIF IsStrictlyPointerToRecord(type) THEN
					(* pointer to record type: push typetag *)
					(* IF dump # NIL THEN dump.String("push typetag"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
					recordType := type.resolved(SyntaxTree.PointerType).pointerBase.resolved(SyntaxTree.RecordType);
					arg := TypeDescriptorAdr(recordType);
				ELSE
					(* non-pointer to record type: push fingerprint *)
					(* IF dump # NIL THEN dump.String("push fingerprint"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
					fingerprint := fingerprinter.TypeFP(type.resolved);
					arg := IntermediateCode.Immediate(IntermediateCode.GetType(system, system.hugeintType), fingerprint.public)
				END;
				operatorInitializationCodeSection.Emit(Push(position,arg))
			END PushTypeInfo;
		BEGIN
			ASSERT(operatorInitializationCodeSection # NIL);

			ASSERT(operator.type IS SyntaxTree.ProcedureType);
			procedureType := operator.type(SyntaxTree.ProcedureType);

			(* determine types *)
			leftType := procedureType.firstParameter.type;
			IF procedureType.numberParameters = 2 THEN
				ASSERT(procedureType.firstParameter.nextParameter # NIL);
				rightType := procedureType.firstParameter.nextParameter.type;
			ELSE
				rightType := NIL
			END;

			(* determine operator kind *)
			IF IsStrictlyPointerToRecord(leftType) THEN
				kind := {LhsIsPointer}
			ELSE
				kind := {}
			END;
			IF IsStrictlyPointerToRecord(rightType) THEN
				kind := kind + {RhsIsPointer}
			END;

			IF kind # {} THEN (* TODO: to be removed later on *)
				(* at least one of the types is a pointer to record *)

				(* emit a code that registers this specific operator in the runtime *)
				dump := operatorInitializationCodeSection.comments;

				(* IF dump # NIL THEN dump.String("*** begin of operator registration ***"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
				IF GetRuntimeProcedure("FoxOperatorRuntime", "RegisterOperator", runtimeProcedure, TRUE) THEN
					(* push ID *)
					(* IF dump # NIL THEN dump.String("push ID"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
					id := Global.GetSymbol(module.module.case, operator.name);
					operatorInitializationCodeSection.Emit(Push(position,IntermediateCode.Immediate(IntermediateCode.GetType(system, system.longintType), id)));

					(* push kind *)
					(* IF dump # NIL THEN dump.String("push kind"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
					operatorInitializationCodeSection.Emit(Push(position,IntermediateCode.Immediate(setType, SYSTEM.VAL(LONGINT, kind))));

					(* push type infos *)
					PushTypeInfo(leftType);
					PushTypeInfo(rightType);

					(* push operator address *)
					(* IF dump # NIL THEN dump.String("push operator address"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
					StaticCallOperand(operator,operatorOperand);
					operatorInitializationCodeSection.Emit(Push(position,operatorOperand.op));
					ReleaseOperand(operatorOperand);

					StaticCallOperand(runtimeProcedure,runtimeProcedureOperand);
					operatorInitializationCodeSection.Emit(Call(position,runtimeProcedureOperand.op, ProcParametersSize( runtimeProcedure)));
					ReleaseOperand(runtimeProcedureOperand)
				END
				(* IF dump # NIL THEN dump.String("*** end of operator registration ***"); dump.Ln; dump.Update END *) (* TENTATIVE *)
			END
		END RegisterDynamicOperator;

		PROCEDURE SystemTrace(x: SyntaxTree.ExpressionList; pos: Position);
		VAR
			traceModule: SyntaxTree.Module;
			procedure: SyntaxTree.Procedure;
			procedureVariable: SyntaxTree.Variable;
			s,msg: Basic.MessageString;
			res: Operand;
			i: LONGINT;
			sv: SyntaxTree.StringValue;
			type: SyntaxTree.Type;
			recordType: SyntaxTree.RecordType;
			printout: Printout.Printer;
			stringWriter: Streams.StringWriter;
			expression: SyntaxTree.Expression;
			saved: RegisterEntry;

			PROCEDURE GetProcedure(CONST procedureName: ARRAY OF CHAR): BOOLEAN;
			BEGIN
				procedure := traceModule.moduleScope.FindProcedure(SyntaxTree.NewIdentifier(procedureName));
				IF procedure = NIL THEN
					procedureVariable := traceModule.moduleScope.FindVariable(SyntaxTree.NewIdentifier(procedureName));
				END;
				IF (procedure = NIL) & (procedureVariable = NIL) THEN
					s := "procedure ";
					Strings.Append(s,backend.traceModuleName);
					Strings.Append(s,".");
					Strings.Append(s,procedureName);
					Strings.Append(s," not present");
					Error(position,s);
					RETURN FALSE
				ELSE
					RETURN TRUE
				END;
			END GetProcedure;

			PROCEDURE CallProcedure;
			VAR size: LONGINT; result: Operand;
			BEGIN
				IF procedure # NIL THEN
					StaticCallOperand(procedure,result);
					size := ProcParametersSize(procedure);
				ELSE
					Symbol(procedureVariable, result);
					LoadValue(result, procedureVariable.type.resolved);
					size := ParametersSize(system, procedureVariable.type.resolved(SyntaxTree.ProcedureType), FALSE);
				END;
				Emit(Call(position,result.op,size));
			END CallProcedure;

			PROCEDURE String(CONST s: ARRAY OF CHAR);
			VAR res: Operand; string: SyntaxTree.String;
			BEGIN
				SaveRegisters();ReleaseUsedRegisters(saved);
				IF GetProcedure("String") THEN
					NEW(string, LEN(s)); COPY(s, string^);
					sv := SyntaxTree.NewStringValue(Basic.invalidPosition,string);
					type := SyntaxTree.NewStringType(Basic.invalidPosition,system.characterType,Strings.Length(s));
					sv.SetType(type);
					Designate(sv,res);
					Emit(Push(position,res.tag));
					Emit(Push(position,res.op));
					ReleaseOperand(res);
					CallProcedure;
				END;
				RestoreRegisters(saved);
			END String;

			PROCEDURE Integer(op: IntermediateCode.Operand);
			BEGIN
				SaveRegisters();ReleaseUsedRegisters(saved);
				IF GetProcedure("Int") THEN
					Emit(Push(position,op));
					Emit(Push(position,IntermediateCode.Immediate(int32,1)));
					CallProcedure;
				END;
				RestoreRegisters(saved);
			END Integer;

			PROCEDURE Float(op: IntermediateCode.Operand);
			BEGIN
				SaveRegisters();ReleaseUsedRegisters(saved);
				IF GetProcedure("HIntHex") THEN
					Emit(Push(position,op));
					Emit(Push(position,IntermediateCode.Immediate(int32,16)));
					CallProcedure;
				END;
				RestoreRegisters(saved);
			END Float;

			PROCEDURE Set(op: IntermediateCode.Operand);
			BEGIN
				SaveRegisters();ReleaseUsedRegisters(saved);
				IF GetProcedure("Set") THEN
					Emit(Push(position,op));
					(*
					Emit(Push(position,IntermediateCode.Immediate(int32,0))); (* ofs *)
					Emit(Push(position,IntermediateCode.Immediate(int32,32))); (* n *)
					*)
					CallProcedure;
				END;
				RestoreRegisters(saved);
			END Set;

			PROCEDURE Boolean(op: IntermediateCode.Operand);
			BEGIN
				SaveRegisters();ReleaseUsedRegisters(saved);
				IF GetProcedure("Boolean") THEN
					Emit(Push(position,op));
					CallProcedure;
				END;
				RestoreRegisters(saved);
			END Boolean;

			PROCEDURE Char(op: IntermediateCode.Operand);
			BEGIN
				SaveRegisters();ReleaseUsedRegisters(saved);
				IF GetProcedure("Char") THEN
					Emit(Push(position,op));
					CallProcedure;
				END;
				RestoreRegisters(saved);
			END Char;

			PROCEDURE Address(op: IntermediateCode.Operand);
			BEGIN
				SaveRegisters();ReleaseUsedRegisters(saved);
				IF GetProcedure("Address") THEN
					Emit(Push(position,op));
					CallProcedure;
				END;
				RestoreRegisters(saved);
			END Address;

			PROCEDURE Size(op: IntermediateCode.Operand);
			BEGIN
				SaveRegisters();ReleaseUsedRegisters(saved);
				IF GetProcedure("Size") THEN
					Emit(Push(position,op));
					CallProcedure;
				END;
				RestoreRegisters(saved);
			END Size;

			PROCEDURE StringOperand(op: Operand; type: SyntaxTree.Type);
			VAR len: IntermediateCode.Operand;
			BEGIN
				SaveRegisters();ReleaseUsedRegisters(saved);
				IF GetProcedure("String") THEN
					len := GetArrayLength(type, op.tag);
					Emit(Push(position,len));
					ReleaseIntermediateOperand(len);
					Emit(Push(position,op.op));
					CallProcedure;
				END;
				RestoreRegisters(saved);
			END StringOperand;

			PROCEDURE Ln;
			BEGIN
				SaveRegisters();ReleaseUsedRegisters(saved);
				IF GetProcedure("Ln") THEN
					CallProcedure;
				END;
				RestoreRegisters(saved);
			END Ln;

		BEGIN
			IF backend.traceModuleName = "" THEN RETURN END;
			IF AddImport(backend.traceModuleName,traceModule,TRUE) THEN
				IF GetProcedure("Enter") THEN
					SaveRegisters();ReleaseUsedRegisters(saved);
					CallProcedure;
					RestoreRegisters(saved);
				END;
				NEW(stringWriter,LEN(s));
				FOR i := 0 TO x.Length()-1 DO
					msg := "";
					expression := x.GetExpression(i);
					IF currentScope IS SyntaxTree.ProcedureScope THEN
						Global.GetSymbolName(currentScope(SyntaxTree.ProcedureScope).ownerProcedure, s)
					ELSE
					Global.GetModuleName(module.module, s);
					END;
					IF i = 0 THEN
						stringWriter.String(s); stringWriter.String("@"); stringWriter.Int(pos.start,1);
						stringWriter.String(":");
					END;

					printout := Printout.NewPrinter(stringWriter,Printout.SourceCode,FALSE);
					IF ~(expression IS SyntaxTree.StringValue) THEN
						printout.Expression(expression);
						stringWriter.Get(s);
						Strings.Append(msg,s);
						Strings.Append(msg,"= ");
					ELSE stringWriter.Get(s); (* remove from string writer *)
						Strings.Append(msg, s);
					END;
					String(msg);
					IF SemanticChecker.IsStringType(expression.type) THEN
						Designate(expression,res);
						StringOperand(res, expression.type);
					ELSE
						Evaluate(expression,res);
						IF expression.type.resolved IS SyntaxTree.IntegerType THEN
							IF res.op.type.sizeInBits < IntermediateCode.Bits64 THEN
								Convert(res.op,int64);
							END;
							Integer(res.op);
						ELSIF expression.type.resolved IS SyntaxTree.BooleanType THEN
							Boolean(res.op);
						ELSIF expression.type.resolved IS SyntaxTree.SetType THEN
							Set(res.op);
						ELSIF expression.type.resolved IS SyntaxTree.FloatType THEN
							IF res.op.type.sizeInBits = IntermediateCode.Bits32 THEN
								Convert(res.op,float64);
							END;
							Float(res.op);
						ELSIF (expression.type.resolved IS SyntaxTree.CharacterType) & (expression.type.resolved.sizeInBits = 8) THEN
							Char(res.op);
						ELSIF expression.type.resolved IS SyntaxTree.AddressType THEN
							Address(res.op);String("H");
						ELSIF expression.type.resolved IS SyntaxTree.SizeType THEN
							Size(res.op);
						ELSIF (expression.type.resolved IS SyntaxTree.PointerType) OR IsPointerToRecord(expression.type,recordType) THEN
							Address(res.op);String("H");
						ELSIF (expression.type.resolved IS SyntaxTree.ProcedureType) THEN
							Address(res.op);String("H");
						ELSIF expression.type.resolved IS SyntaxTree.NilType THEN
							String("NIL");
						ELSE HALT(200);
						END;
					END;
					ReleaseOperand(res);
					String("; ");
				END;
				IF GetProcedure("Exit") THEN
					SaveRegisters();ReleaseUsedRegisters(saved);
					CallProcedure;
					RestoreRegisters(saved);
				ELSE
					Ln;
				END;
			END;
		END SystemTrace;

		PROCEDURE InitFields(type: SyntaxTree.Type; CONST adr: IntermediateCode.Operand; offset: LONGINT);
		VAR baseType: SyntaxTree.Type; imm,mem: IntermediateCode.Operand; dim,size: LONGINT;
			variable: SyntaxTree.Variable; i: LONGINT; initializerOp: Operand;
		BEGIN
			type := type.resolved;
			IF type IS SyntaxTree.RecordType THEN
				WITH type: SyntaxTree.RecordType DO
					baseType := type.baseType;
					IF baseType # NIL THEN
						baseType := baseType.resolved;
						IF baseType IS SyntaxTree.PointerType THEN baseType := baseType(SyntaxTree.PointerType).pointerBase END;
						InitFields(baseType,adr,offset);
					END;
					variable := type.recordScope.firstVariable;
					WHILE variable # NIL DO
						IF variable.initializer # NIL THEN
							Evaluate(variable.initializer,initializerOp);
							MakeMemory(mem,adr,IntermediateCode.GetType(system,variable.type),offset+ ToMemoryUnits(system,variable.offsetInBits));
							Emit(Mov(position,mem,initializerOp.op));
							ReleaseOperand(initializerOp);
							ReleaseIntermediateOperand(mem);
						END;
						InitFields(variable.type, adr, offset+ ToMemoryUnits(system,variable.offsetInBits));
						variable := variable.nextVariable
					END;
				END;
			ELSIF type IS SyntaxTree.CellType THEN
				WITH type: SyntaxTree.CellType DO
					baseType := type.baseType;
					IF baseType # NIL THEN
						baseType := baseType.resolved;
						IF baseType IS SyntaxTree.PointerType THEN baseType := baseType(SyntaxTree.PointerType).pointerBase END;
						InitFields(baseType,adr,offset);
					END;
					variable := type.cellScope.firstVariable;
					WHILE variable # NIL DO
						IF variable.initializer # NIL THEN
							Evaluate(variable.initializer,initializerOp);
							MakeMemory(mem,adr,IntermediateCode.GetType(system,variable.type),offset+ ToMemoryUnits(system,variable.offsetInBits));
							Emit(Mov(position,mem,initializerOp.op));
							ReleaseOperand(initializerOp);
							ReleaseIntermediateOperand(mem);
						END;
						InitFields(variable.type, adr, offset+ ToMemoryUnits(system,variable.offsetInBits));
						variable := variable.nextVariable
					END;
				END;
			ELSIF (type IS SyntaxTree.ArrayType) THEN
				WITH type: SyntaxTree.ArrayType DO
					IF type.form = SyntaxTree.Static THEN
						baseType := type.arrayBase;
						size := ToMemoryUnits(system,system.AlignedSizeOf(baseType));
						FOR i := 0 TO type.staticLength-1 DO
							InitFields(baseType,adr,offset+i*size);
						END;
					END;
				END;
			ELSIF type IS SyntaxTree.MathArrayType THEN
				WITH type: SyntaxTree.MathArrayType DO
					IF type.form = SyntaxTree.Open THEN
						dim := DynamicDim(type);
						imm := IntermediateCode.Immediate(addressType,dim);
						PutMathArrayFieldOffset(adr,imm,MathDimOffset,offset);
						baseType := SemanticChecker.ArrayBase(type,dim);
						IF baseType = NIL THEN size := 0 ELSE size := system.AlignedSizeOf(baseType) END;
						imm := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,size));
						PutMathArrayFieldOffset(adr,imm,MathElementSizeOffset,offset);
						ReleaseIntermediateOperand(imm);
						(* flags remain empty (=0) for open array *)
					ELSIF type.form = SyntaxTree.Static THEN
						baseType := type.arrayBase;
						size := ToMemoryUnits(system,system.AlignedSizeOf(baseType));
						ASSERT(type.staticLength < 1024*1024*1024);
						FOR i := 0 TO type.staticLength-1 DO
							InitFields(baseType,adr,offset+i*size);
						END;
					END;
				END;
			END;
		END InitFields;

		PROCEDURE InitVariable(VAR variable: SyntaxTree.Variable; temporary: BOOLEAN);
		VAR type: SyntaxTree.Type; operand: Operand; tmp, mem: IntermediateCode.Operand; reference: SyntaxTree.Expression; symbol: SyntaxTree.Symbol;
			saved: RegisterEntry;
		BEGIN
			type := variable.type.resolved;
			IF (type IS SyntaxTree.MathArrayType) THEN
				WITH type: SyntaxTree.MathArrayType DO
					IF type.form = SyntaxTree.Open THEN
						Symbol(variable,operand);
						InitFields(type, operand.tag,0);
						IF temporary THEN
							PutMathArrayField(operand.tag, IntermediateCode.Immediate(addressType,SYSTEM.VAL(LONGINT,{StackFlag})),MathFlagsOffset);
						END;
					ELSIF type.form = SyntaxTree.Tensor THEN
						IF temporary & backend.writeBarriers THEN
							SaveRegisters();ReleaseUsedRegisters(saved);
							Symbol(variable, operand);
							Emit(Push(position,operand.op));
							ReleaseOperand(operand);
							Emit(Push(position,nil));
							CallThis(position,"FoxArrayBase","Assign",2);
							RestoreRegisters(saved);
						ELSE
							Symbol(variable, operand);
							MakeMemory(tmp,operand.op,addressType,0);
							ReleaseOperand(operand);
							IF FALSE & temporary THEN
									(* trick -- temporary object from array base *)
									symbol := GetSymbol(moduleScope,"FoxArrayBase","temporary");
									Symbol(symbol,operand);
									MakeMemory(mem,operand.op,addressType,0);
									ReleaseOperand(operand);
									Emit(Mov(position,tmp, mem) );
									ReleaseOperand(operand);
							ELSE
								Emit(Mov(position,tmp, nil ) );
							END;
							ReleaseIntermediateOperand(tmp)
						END;
					END;
				END;
			ELSE
				Symbol(variable,operand);
				IF variable.initializer # NIL THEN
					reference := SyntaxTree.NewSymbolDesignator(variable.initializer.position,NIL, NIL,variable);
					reference.SetType(variable.type.resolved);
					reference.SetAssignable(TRUE);
					Assign(reference,variable.initializer);
				ELSIF temporary THEN
					IF SemanticChecker.IsPointerType(variable.type) THEN
						IF backend.cooperative THEN
							SaveRegisters();ReleaseUsedRegisters(saved);
							Symbol(variable, operand);
							CallAssignPointer(operand.op, nil);
							ReleaseOperand(operand);
							RestoreRegisters(saved);
						ELSIF backend.writeBarriers THEN
							SaveRegisters();ReleaseUsedRegisters(saved);
							Symbol(variable, operand);
							Emit(Push(position,operand.op));
							ReleaseOperand(operand);
							Emit(Push(position,nil));
							CallThis(position,"Heaps","Assign",2);
							RestoreRegisters(saved);
						ELSE
							Symbol(variable, operand);
							MakeMemory(tmp,operand.op,addressType,0);
							ReleaseOperand(operand);
							Emit(Mov(position,tmp, nil ) );
							ReleaseIntermediateOperand(tmp);
						END;
					END;
				END;
				InitFields(type, operand.op,0);
				ReleaseOperand(operand);
			END;
		END InitVariable;

		PROCEDURE MathArrayDim(type: SyntaxTree.MathArrayType; CONST base: IntermediateCode.Operand; VAR result: Operand);
		VAR end: Label;
		BEGIN
			IF type.form = SyntaxTree.Tensor THEN
				InitOperand(result,ModeValue);
				ReuseCopy(result.op,base);
				end := NewLabel();
				BreqL(end,result.op,IntermediateCode.Immediate(addressType,0));
				Emit(MovReplace(position,result.op,IntermediateCode.Memory(addressType,result.op,ToMemoryUnits(system,MathDimOffset*addressType.sizeInBits))));
				SetLabel(end);
				Convert(result.op,lenType);
			ELSE
				InitOperand(result,ModeValue);
				IntermediateCode.InitImmediate(result.op, lenType, SemanticChecker.Dimension(type,{SyntaxTree.Open, SyntaxTree.Static}));
			END
		END MathArrayDim;

		PROCEDURE PutMathArrayField(base,value: IntermediateCode.Operand; fieldOffset: LONGINT);
		VAR mem: IntermediateCode.Operand; offset: LONGINT;
		BEGIN
			offset := ToMemoryUnits(system,fieldOffset*addressType.sizeInBits);
			MakeMemory(mem,base,addressType,offset);
			Emit(Mov(position,mem,value));
			ReleaseIntermediateOperand(mem);
		END PutMathArrayField;

		PROCEDURE PutMathArrayFieldOffset(base,value: IntermediateCode.Operand; fieldOffset, offset: LONGINT);
		VAR mem: IntermediateCode.Operand;
		BEGIN
			offset := offset + ToMemoryUnits(system,fieldOffset*addressType.sizeInBits);
			MakeMemory(mem,base,addressType,offset);
			Emit(Mov(position,mem,value));
			ReleaseIntermediateOperand(mem);
		END PutMathArrayFieldOffset;

		PROCEDURE GetMathArrayField(VAR value: IntermediateCode.Operand; base: IntermediateCode.Operand; offset: LONGINT);
		BEGIN
			offset := ToMemoryUnits(system,offset*addressType.sizeInBits);
			MakeMemory(value,base,addressType,offset);
		END GetMathArrayField;

		PROCEDURE PutMathArrayLenOrIncr(CONST base,value,dim: IntermediateCode.Operand; incr: BOOLEAN);
		VAR offset: LONGINT; reg,mem: IntermediateCode.Operand;
		BEGIN
			IF incr THEN
				offset := ToMemoryUnits(system,MathIncrOffset*addressType.sizeInBits);
			ELSE
				offset := ToMemoryUnits(system,MathLenOffset*addressType.sizeInBits);
			END;
			IF dim.mode=IntermediateCode.ModeImmediate THEN
				PutMathArrayField(base,value,offset + ToMemoryUnits(system,SHORT(dim.intValue) * 2 * addressType.sizeInBits));
			ELSE
				IntermediateCode.InitRegister(reg,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
				Emit(Mov(position,reg,dim));
				Emit(Mul(position,reg,reg,IntermediateCode.Immediate(addressType,ToMemoryUnits(system,2*addressType.sizeInBits))));
				Emit(Add(position,reg,reg,base));
				MakeMemory(mem, reg, addressType, offset);
				ReleaseIntermediateOperand(reg);
				Emit(Mov(position,mem,value));
				ReleaseIntermediateOperand(mem);
			END;
		END PutMathArrayLenOrIncr;

		PROCEDURE PutMathArrayLength(base,value: IntermediateCode.Operand; dim: LONGINT);
		BEGIN
			PutMathArrayField(base,value,MathLenOffset + dim * 2);
		END PutMathArrayLength;

		PROCEDURE PutMathArrayIncrement(base,value: IntermediateCode.Operand; dim: LONGINT);
		BEGIN
			PutMathArrayField(base,value,MathIncrOffset + dim * 2);
		END PutMathArrayIncrement;

		PROCEDURE GetMathArrayIncrement(type: SyntaxTree.MathArrayType; CONST operand: Operand; VAR dim: IntermediateCode.Operand; check: BOOLEAN; VAR result: Operand);
		BEGIN
			MathArrayLenOrIncr(type,operand,dim,TRUE,check,result);
		END GetMathArrayIncrement;

		PROCEDURE GetMathArrayLength(type: SyntaxTree.MathArrayType; CONST operand: Operand; VAR dim: IntermediateCode.Operand; check: BOOLEAN; VAR result: Operand);
		BEGIN
			MathArrayLenOrIncr(type,operand,dim,FALSE,check,result);
		END GetMathArrayLength;

		PROCEDURE GetMathArrayLengthAt(type: SyntaxTree.MathArrayType; CONST operand: Operand; dim: LONGINT; check: BOOLEAN; VAR result: Operand);
		VAR dimOp: IntermediateCode.Operand;
		BEGIN
			dimOp := IntermediateCode.Immediate(sizeType, dim);
			GetMathArrayLength(type, operand, dimOp, check, result);
		END GetMathArrayLengthAt;

		PROCEDURE GetMathArrayIncrementAt(type: SyntaxTree.MathArrayType; CONST operand: Operand; dim: LONGINT; check: BOOLEAN; VAR result: Operand);
		VAR dimOp: IntermediateCode.Operand;
		BEGIN
			dimOp := IntermediateCode.Immediate(sizeType, dim);
			GetMathArrayIncrement(type, operand, dimOp, check, result);
		END GetMathArrayIncrementAt;

		PROCEDURE MathArrayLenOrIncr(type: SyntaxTree.MathArrayType; CONST operand: Operand; VAR dim: IntermediateCode.Operand; increment: BOOLEAN; check: BOOLEAN; VAR result: Operand );
		VAR val: LONGINT; res,res2: IntermediateCode.Operand; end,next: Label; t: SyntaxTree.Type; imm: IntermediateCode.Operand; hasDynamicPart: BOOLEAN;
			offset: LONGINT;
		BEGIN
			IF increment THEN
				offset := MathIncrOffset;
			ELSE
				offset := MathLenOffset;
			END;
			INC(offset,operand.dimOffset*2);
			IF check & (type.form = SyntaxTree.Tensor) & ~isUnchecked THEN
				TrapC(BrneL,operand.tag,IntermediateCode.Immediate(addressType,0),IndexCheckTrap);
			END;
			(* static dimension *)
			IF  dim.mode = IntermediateCode.ModeImmediate THEN
				IF check & (type.form = SyntaxTree.Tensor) THEN
					DimensionCheck(operand.tag,dim,BrltL);
				END;
				val := SHORT(dim.intValue);
				IF type.form # SyntaxTree.Tensor THEN
					t := SemanticChecker.ArrayBase(type,val);
					type := t.resolved(SyntaxTree.MathArrayType);
					IF type.form = SyntaxTree.Static THEN
						IF increment THEN
							res := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,type.staticIncrementInBits));
						ELSE
							res := IntermediateCode.Immediate(addressType,type.staticLength);
						END;
						InitOperand(result,ModeValue);
						result.op := res;
						RETURN;
					END;
				END;
				offset := ToMemoryUnits(system, (val*2+offset)*addressType.sizeInBits);
				MakeMemory(res,operand.tag,addressType,offset);
				(*
				res := IntermediateCode.Memory(addressType,operand.tag,offset);
				*)
				InitOperand(result,ModeValue);
				result.op := res;
			ELSE
				Convert(dim,addressType);
				IF check THEN
					IF type.form = SyntaxTree.Tensor THEN
						DimensionCheck(operand.tag,dim,BrltL);
					ELSIF isUnchecked THEN (* do nothing *)
					ELSE
						TrapC(BrltL,dim,IntermediateCode.Immediate(addressType,SemanticChecker.Dimension(type,{SyntaxTree.Open,SyntaxTree.Static})), IndexCheckTrap);
					END;
				END;
				end := NewLabel(); next := NIL;

				IntermediateCode.InitRegister(res,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
				Emit(Mov(position,res,dim));
				Convert(res,sizeType);

				t := type; val := operand.dimOffset; hasDynamicPart := FALSE;
				WHILE t IS SyntaxTree.MathArrayType DO
					type := t(SyntaxTree.MathArrayType);
					IF type.form = SyntaxTree.Static THEN
						imm := IntermediateCode.Immediate(sizeType,val);
						next := NewLabel();
						BrneL(next,imm,res);
						IF increment THEN
							imm := IntermediateCode.Immediate(sizeType,ToMemoryUnits(system,type.staticIncrementInBits));
						ELSE
							imm := IntermediateCode.Immediate(sizeType,type.staticLength);
						END;
						Emit(MovReplace(position,res,imm));
						BrL(end);
					ELSE hasDynamicPart := TRUE;
					END;
					t := type.arrayBase.resolved;
					val := val + 1;
					IF next # NIL THEN SetLabel(next) END;
				END;
				IF hasDynamicPart THEN
					IntermediateCode.InitRegister(res2,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
					Emit(Mov(position,res2,dim));
					Emit(Mul(position,res2,res2,IntermediateCode.Immediate(addressType,2*ToMemoryUnits(system,addressType.sizeInBits))));
					imm := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,offset*addressType.sizeInBits));
					Emit(Add(position,res2,res2,imm));
					Emit(Add(position,res2,res2,operand.tag));
					IntermediateCode.MakeMemory(res2,sizeType);
					Emit(MovReplace(position,res,res2));
					ReleaseIntermediateOperand(res2);
				END;
				SetLabel(end);
				Convert(res,sizeType);
				InitOperand(result,ModeValue);
				result.op := res;
			END;
		END MathArrayLenOrIncr;

		PROCEDURE ArrayLen(type: SyntaxTree.ArrayType; VAR operand: Operand; VAR dim: IntermediateCode.Operand; VAR result: Operand );
		VAR val: LONGINT; res,res2: IntermediateCode.Operand; end,next: Label; t: SyntaxTree.Type; imm: IntermediateCode.Operand; hasDynamicPart: BOOLEAN;
			offset: LONGINT;
		BEGIN
			offset := operand.dimOffset+DynamicDim(type)-1;
			IF  dim.mode = IntermediateCode.ModeImmediate THEN
				ASSERT(type.form IN {SyntaxTree.Open, SyntaxTree.SemiDynamic});
				val := SHORT(dim.intValue);
				t := SemanticChecker.ArrayBase(type,val);
				type := t.resolved(SyntaxTree.ArrayType);
				IF type.form = SyntaxTree.Static THEN
					res := IntermediateCode.Immediate(addressType,type.staticLength);
				ELSE
					offset := ToMemoryUnits(system, (offset-val)*addressType.sizeInBits);
					res := IntermediateCode.Memory(addressType,operand.tag,offset);
				END;
				UseIntermediateOperand(res);
				InitOperand(result,ModeValue);
				result.op := res;
			ELSE
				Convert(dim,addressType);
				IF ~isUnchecked THEN
					TrapC(BrltL,dim,IntermediateCode.Immediate(addressType,SemanticChecker.Dimension(type,{SyntaxTree.Open,SyntaxTree.Static})), IndexCheckTrap);
				END;

				end := NewLabel(); next := NIL;

				(* ReuseCopy(dim,res); *)
				IntermediateCode.InitRegister(res,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType, IntermediateCode.GeneralPurposeRegister));
				Emit(Mov(position,res,dim));
				Convert(res,sizeType);

				Convert(res,sizeType);
				t := type; val := operand.dimOffset; hasDynamicPart := FALSE;
				WHILE t IS SyntaxTree.ArrayType DO
					type := t(SyntaxTree.ArrayType);
					IF type.form = SyntaxTree.Static THEN
						imm := IntermediateCode.Immediate(sizeType,val);
						next := NewLabel();
						BrneL(next,imm,res);
						imm := IntermediateCode.Immediate(sizeType,type.staticLength);
						Emit(MovReplace(position,res,imm));
						BrL(end);
					ELSE hasDynamicPart := TRUE;
					END;
					t := type.arrayBase.resolved;
					val := val + 1;
					IF next # NIL THEN SetLabel(next) END;
				END;
				IF hasDynamicPart THEN
					ReuseCopy(res2,dim); (* dim is now in register res2 *)
					Convert(res2,addressType);
					Emit(Mul(position,res2,res2,IntermediateCode.Immediate(addressType,ToMemoryUnits(system,addressType.sizeInBits))));
					imm := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,offset*addressType.sizeInBits));
					Emit(Sub(position,res2,imm,res2));
					Emit(Add(position,res2,res2,operand.tag));
					IntermediateCode.MakeMemory(res2,sizeType);
					Emit(MovReplace(position,res,res2));
					ReleaseIntermediateOperand(res2);
				END;
				SetLabel(end);
				Convert(res,sizeType);
				InitOperand(result,ModeValue);
				result.op := res;
			END;
		END ArrayLen;

		(**
			create a temporary variable in current scope
		**)
		PROCEDURE GetTemporaryVariable(type: SyntaxTree.Type; register: BOOLEAN; untraced: BOOLEAN): SyntaxTree.Variable;
		VAR name: SyntaxTree.Identifier;  variable, v: SyntaxTree.Variable;
			scope: SyntaxTree.Scope; duplicate: BOOLEAN; index: LONGINT;
		BEGIN
			IF ~register THEN
				v := temporaries.GetFreeVariable(type, untraced, index);
			ELSE
				index := temporaries.registerIndex; INC(temporaries.registerIndex);
			END;
			scope := currentScope;
			IF (scope IS SyntaxTree.ProcedureScope) & (scope(SyntaxTree.ProcedureScope).ownerProcedure.type(SyntaxTree.ProcedureType).noPAF) THEN
				Error(scope(SyntaxTree.ProcedureScope).ownerProcedure.position,"implementation restriction: cannot allocate temporary variable in procedure without activation frame");
			END;
			(*
			v := NIL; (* to disable free variable managemenet temporarily *)
			*)
			name := temporaries.GetUID();

			variable := SyntaxTree.NewVariable(Basic.invalidPosition,name);
			variable.SetType(type);
			variable.SetAccess(SyntaxTree.Hidden);
			variable.SetUntraced(untraced);

			IF v = NIL THEN
				temporaries.AddVariable(variable);

				IF ~register THEN
					scope.AddVariable(variable(SyntaxTree.Variable));
					ASSERT(system.GenerateVariableOffsets(scope));
					scope.EnterSymbol(variable, duplicate);
					InitVariable(variable(SyntaxTree.Variable),TRUE);
				ELSE
					variable.PreferRegister(TRUE);
					variable(SyntaxTree.Variable).SetOffset(0);
				END;
			ELSE (* v # NIL *)
				(* reuse slot for new variable, do not create new slot ! *)
				temporaries.SetVariable(index, variable);
				(* ASSERT(v.scope = scope);  can be violated in inline calls *)
				ASSERT(~register);

				variable(SyntaxTree.Variable).SetOffset(v.offsetInBits);
				ASSERT((v.offsetInBits # 0) & (v.offsetInBits # MIN(LONGINT)));

				scope.InsertVariable(variable(SyntaxTree.Variable), v);
				scope.EnterSymbol(variable, duplicate);
				ASSERT(~duplicate);
				InitVariable(variable(SyntaxTree.Variable),TRUE);
			END;
			RETURN variable(SyntaxTree.Variable)
		END GetTemporaryVariable;

		PROCEDURE GetMathArrayDescriptorType(dimensions: LONGINT): SyntaxTree.Type;
		VAR name: ARRAY 32 OF CHAR; symbol: SyntaxTree.Symbol; typeDeclaration: SyntaxTree.TypeDeclaration;
			recordType: SyntaxTree.RecordType; type: SyntaxTree.Type;
			recordScope: SyntaxTree.RecordScope; parentScope: SyntaxTree.Scope; identifier: SyntaxTree.Identifier;
			i: LONGINT; duplicate: BOOLEAN;

			PROCEDURE AddVariable(CONST name: ARRAY OF CHAR; type: SyntaxTree.Type);
			VAR variable: SyntaxTree.Variable;
			BEGIN
				variable := SyntaxTree.NewVariable(Basic.invalidPosition,SyntaxTree.NewIdentifier(name));
				variable.SetType(type);
				recordScope.AddVariable(variable);
			END AddVariable;

		BEGIN
			name := "@ArrayDescriptor";
			Basic.AppendNumber(name,dimensions);
			identifier := SyntaxTree.NewIdentifier(name);
			parentScope := module.module.moduleScope;
			symbol := parentScope.FindSymbol(identifier);
			IF symbol # NIL THEN
				typeDeclaration := symbol(SyntaxTree.TypeDeclaration);
				type := typeDeclaration.declaredType;
			ELSE
				typeDeclaration := SyntaxTree.NewTypeDeclaration(Basic.invalidPosition,SyntaxTree.NewIdentifier(name));
				typeDeclaration.SetAccess(SyntaxTree.Hidden);
				recordScope := SyntaxTree.NewRecordScope(parentScope);
				recordType := SyntaxTree.NewRecordType( Basic.invalidPosition, parentScope, recordScope);
				recordType.SetTypeDeclaration(typeDeclaration);
				recordType.SetState(SyntaxTree.Resolved);
				typeDeclaration.SetDeclaredType(recordType);
				AddVariable("@ptr",system.anyType);
				AddVariable("@adr",system.addressType);
				AddVariable("@flags",system.addressType);
				AddVariable("@dim",system.addressType);
				AddVariable("@elementSize",system.addressType);
				FOR i := 0 TO dimensions-1  DO
					name := "@len";
					Basic.AppendNumber(name,i);
					AddVariable(name,system.addressType);
					name := "@incr";
					Basic.AppendNumber(name,i);
					AddVariable(name,system.addressType);
				END;
				parentScope.AddTypeDeclaration(typeDeclaration);
				parentScope.EnterSymbol(typeDeclaration,duplicate);
				ASSERT(~duplicate);
				type := recordType;
			END;
			RETURN type
		END GetMathArrayDescriptorType;

		PROCEDURE PushConstString(CONST s: ARRAY OF CHAR);
		VAR res: Operand; string: SyntaxTree.String; sv: SyntaxTree.StringValue; type: SyntaxTree.Type;
		BEGIN
			NEW(string, LEN(s)); COPY(s, string^);
			sv := SyntaxTree.NewStringValue(Basic.invalidPosition,string);
			type := SyntaxTree.NewStringType(Basic.invalidPosition,system.characterType,Strings.Length(s));
			sv.SetType(type);
			Designate(sv,res);
			Emit(Push(position,res.tag));
			Emit(Push(position,res.op));
			ReleaseOperand(res);
		END PushConstString;

		PROCEDURE PushConstBoolean(b: BOOLEAN);
		BEGIN
			IF b THEN
				Emit(Push(Basic.invalidPosition, true));
			ELSE
				Emit(Push(Basic.invalidPosition, false));
			END;
		END PushConstBoolean;

		PROCEDURE PushConstSet(v: SET);
		VAR value: SyntaxTree.Value; op: Operand;
		BEGIN
			value := SyntaxTree.NewSetValue(Basic.invalidPosition, v);
			value.SetType(system.setType);
			Evaluate(value, op);
			Emit(Push(Basic.invalidPosition, op.op));
			ReleaseOperand(op);
		END PushConstSet;

		PROCEDURE PushConstInteger(v: LONGINT);
		VAR value: SyntaxTree.Value; op: Operand;
		BEGIN
			value := SyntaxTree.NewIntegerValue(Basic.invalidPosition, v);
			value.SetType(system.longintType);
			Evaluate(value, op);
			Emit(Push(Basic.invalidPosition, op.op));
			ReleaseOperand(op);
		END PushConstInteger;

		PROCEDURE OpenInitializer(symbol: SyntaxTree.Symbol; scope: SyntaxTree.Scope): IntermediateCode.Section;
		VAR name: Basic.SegmentedName; procedure: SyntaxTree.Procedure; procedureScope: SyntaxTree.ProcedureScope;
			section: IntermediateCode.Section;
		BEGIN
			procedureScope := SyntaxTree.NewProcedureScope(scope);
			Global.GetSymbolSegmentedName(symbol, name);
			Basic.SuffixSegmentedName(name, Basic.MakeString("@Initializer"));
			procedure := SyntaxTree.NewProcedure(Basic.invalidPosition, SyntaxTree.NewIdentifier(""), procedureScope);
			procedure.SetScope(moduleScope);
			procedure.SetType(SyntaxTree.NewProcedureType(Basic.invalidPosition,scope));
			procedure.type(SyntaxTree.ProcedureType).SetDelegate(TRUE);
			procedure.SetAccess(SyntaxTree.Hidden);
			currentScope := procedureScope;
			section := NewSection(module.allSections, Sections.CodeSection, name, NIL,commentPrintout # NIL);
			EmitEnter(section, Basic.invalidPosition,procedure,0,0);
			RETURN section;
		END OpenInitializer;

		PROCEDURE CloseInitializer(prev: IntermediateCode.Section);
		BEGIN
			EmitLeave(section, Basic.invalidPosition, NIL, 0 );
			Emit(Exit(Basic.invalidPosition,0 ,0, 0));
			section := prev;
		END CloseInitializer;

		PROCEDURE AddPorts(cell: SyntaxTree.Symbol; x: SyntaxTree.CellType);
		VAR name: SyntaxTree.IdentifierString;
			parameter: SyntaxTree.Parameter;
			type: SyntaxTree.Type;

			PROCEDURE Field(symbol: SyntaxTree.Symbol; VAR op: Operand);
			BEGIN
				InitOperand(op,ModeReference);
				op.op := fp;
				IntermediateCode.AddOffset(op.op,ToMemoryUnits(system,2*addressType.sizeInBits));
				Dereference(op, x, FALSE);
				Symbol(symbol, op);
			END Field;

			PROCEDURE Direction(direction: LONGINT): SET;
			BEGIN
				IF direction = SyntaxTree.OutPort THEN RETURN {0}
				ELSIF direction = SyntaxTree.InPort THEN RETURN {1}
				ELSE HALT(100);
				END;
			END Direction;

			PROCEDURE AddPortProperty(port: SyntaxTree.Parameter; modifier: SyntaxTree.Modifier; value: SyntaxTree.Expression);
			VAR name: ARRAY 256 OF CHAR; op: Operand;
			BEGIN
					Field(port, op);
					ToMemory(op.op,addressType,0);
					Emit(Push(Basic.invalidPosition, op.op));
					ReleaseOperand(op);

					Basic.GetString(modifier.identifier, name);
					PushConstString(name);

					IF SemanticChecker.IsStringType(modifier.expression.type) THEN
						ASSERT(SemanticChecker.IsStringType(value.type));
						Designate(value, op);
						Emit(Push(modifier.position, op.tag));
						Emit(Push(modifier.position, op.op));
						ReleaseOperand(op);
						CallThis(position,"ActiveCellsRuntime","AddPortStringProperty",5);
					ELSIF (modifier.expression.type.resolved IS SyntaxTree.IntegerType) THEN
						ASSERT(value.type.resolved IS SyntaxTree.IntegerType);
						Evaluate(value, op);
						Emit(Push(modifier.position, op.op));
						ReleaseOperand(op);
						CallThis(position,"ActiveCellsRuntime","AddPortIntegerProperty",4);
					ELSE
						CallThis(position,"ActiveCellsRuntime","AddPortFlagProperty",3);
					END;
			END AddPortProperty;

			PROCEDURE AddPortProperties(parameter: SyntaxTree.Parameter);
			VAR modifier: SyntaxTree.Modifier;
			BEGIN
				modifier := parameter.modifiers;
				WHILE modifier # NIL DO
					AddPortProperty(parameter,modifier, modifier.expression);
					modifier := modifier.nextModifier;
				END;
			END AddPortProperties;

			PROCEDURE Parameter(name: ARRAY OF CHAR; parameter: SyntaxTree.Parameter);
			VAR op : Operand; portType: SyntaxTree.PortType; baseType: SyntaxTree.Type;
				size, reg: IntermediateCode.Operand; dim, len: LONGINT;

				PROCEDURE PushLens(type: SyntaxTree.Type);
				BEGIN
					IF IsSemiDynamicArray(type) THEN
						PushLens(type(SyntaxTree.ArrayType).arrayBase.resolved);
						Evaluate(type(SyntaxTree.ArrayType).length, op);
						Emit(Push(Basic.invalidPosition, op.op));
						ReleaseOperand(op);
						INC(dim);
					ELSIF IsStaticArray(type) THEN
						len := len * type(SyntaxTree.ArrayType).staticLength;
						PushLens(type(SyntaxTree.ArrayType).arrayBase.resolved);
						INC(dim);
					ELSE
						baseType := type;
					END;
				END PushLens;

			BEGIN
				(* cell *)
					IF parameter.type IS SyntaxTree.ArrayType THEN
						type := parameter.type;
						dim := 0;
						len := 1;
						PushLens(type);
						portType := baseType.resolved(SyntaxTree.PortType);
					ELSE
						portType := parameter.type(SyntaxTree.PortType);
					END;

					PushSelfPointer();
				(* port / array of ports *)
					IF IsStaticArray(type) THEN
						PushConstInteger(len);
					END;
					Field(parameter, op);
					(*left := SyntaxTree.NewSymbolDesignator(Basic.invalidPosition,left,cell); left.SetType(system.anyType);
					left := SyntaxTree.NewDereferenceDesignator(Basic.invalidPosition, left); left.SetType(x);
					d := SyntaxTree.NewSymbolDesignator(Basic.invalidPosition, left, parameter); d.SetType(parameter.type);
					Designate(d, op);*)
					Emit(Push(Basic.invalidPosition, op.op));
					ReleaseOperand(op);
				(* name *)
					PushConstString(name);
				(* inout *)
					PushConstSet(Direction(portType.direction));
				(* width *)
					PushConstInteger(portType.sizeInBits);

				IF parameter.type IS SyntaxTree.PortType THEN
					CallThis(parameter.position,"ActiveCellsRuntime","AddPort",6);
					AddPortProperties(parameter);
				ELSIF IsStaticArray(type)THEN
					CallThis(parameter.position,"ActiveCellsRuntime","AddStaticPortArray",7);
				ELSIF IsSemiDynamicArray(type) THEN
					IntermediateCode.InitRegister(reg,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
					size :=  IntermediateCode.Immediate(addressType, ToMemoryUnits(system,6*addressType.sizeInBits));
					Emit(Add(position,reg, sp, size));
					(* dim *)
					PushConstInteger(dim);
					(* len array *)
					Emit(Push(position, reg));
					ReleaseIntermediateOperand(reg);
					CallThis(position,"ActiveCellsRuntime","AddPortArray",8);
					size :=  IntermediateCode.Immediate(addressType, ToMemoryUnits(system,dim*addressType.sizeInBits));
					Emit(Add(position, sp,sp, size));
				ELSE
					HALT(100);
				END;
			END Parameter;

		BEGIN
			IF backend.cellsAreObjects THEN
				IF (x.baseType # NIL)  & (x.baseType.resolved IS SyntaxTree.CellType) THEN
					AddPorts(cell, x.baseType.resolved(SyntaxTree.CellType));
				END;
				parameter := x.firstParameter;
				WHILE (parameter # NIL) DO
					type := parameter.type.resolved;
					WHILE (type IS SyntaxTree.ArrayType) DO
						type := type(SyntaxTree.ArrayType).arrayBase.resolved;
					END;
					IF (type IS SyntaxTree.PortType) THEN (* port found *)
						Global.GetSymbolNameInScope(parameter,x.cellScope,name);
						Parameter(name,parameter);
					END;
					parameter := parameter.nextParameter;
				END;
			ELSE HALT(200)
			END;

		END AddPorts;

		PROCEDURE AddProperty(cellType: SyntaxTree.CellType; cell: SyntaxTree.Symbol; property: SyntaxTree.Property; value: SyntaxTree.Expression);
		VAR name: ARRAY 256 OF CHAR; op: Operand;  left, d: SyntaxTree.Designator;
		BEGIN

				Symbol(cell,op);
				ToMemory(op.op,addressType,0);
				Emit(Push(position,op.op));
				ReleaseOperand(op);

				property.GetName(name);
				(* does not work  when inheritance is used:
				Global.GetSymbolNameInScope(property, cellType.cellScope , name);
				*)
				PushConstString(name);

				IF (value # NIL) THEN
					ASSERT(
						SemanticChecker.IsStringType(property.type)
						OR (property.type.resolved IS SyntaxTree.IntegerType)
						OR (property.type.resolved IS SyntaxTree.FloatType)
						OR (property.type.resolved IS SyntaxTree.BooleanType)
						OR (property.type.resolved IS SyntaxTree.SetType)
						);
					left := SyntaxTree.NewSymbolDesignator(Basic.invalidPosition,NIL,left,cell); left.SetType(system.anyType);
					left := SyntaxTree.NewDereferenceDesignator(Basic.invalidPosition, NIL,left); left.SetType(cellType);
					d := SyntaxTree.NewSymbolDesignator(Basic.invalidPosition, NIL,left, property); d.SetType(property.type);
					Designate(d, op);
					IF SemanticChecker.IsStringType(property.type) THEN
						Emit(Push(Basic.invalidPosition, op.tag))
					END;
					Emit(Push(Basic.invalidPosition, op.op));
					ReleaseOperand(op);
				END;

				IF value = NIL THEN
					CallThis(position,"ActiveCellsRuntime","AddFlagProperty",3);
				ELSIF SemanticChecker.IsStringType(property.type) THEN
					ASSERT(SemanticChecker.IsStringType(value.type));
					Designate(value, op);
					PushString(op, value.type);
					ReleaseOperand(op);
					CallThis(position,"ActiveCellsRuntime","AddStringProperty",7);
				ELSIF (property.type.resolved IS SyntaxTree.IntegerType) THEN
					ASSERT(value.type.resolved IS SyntaxTree.IntegerType);
					Evaluate(value, op);
					Emit(Push(property.position, op.op));
					ReleaseOperand(op);
					CallThis(position,"ActiveCellsRuntime","AddIntegerProperty",5);
				ELSIF (property.type.resolved IS SyntaxTree.BooleanType) THEN
					ASSERT(value.type.resolved IS SyntaxTree.BooleanType);
					Evaluate(value, op);
					Emit(Push(property.position, op.op));
					ReleaseOperand(op);
					CallThis(position,"ActiveCellsRuntime","AddBooleanProperty",5);
				ELSIF (property.type.resolved IS SyntaxTree.FloatType) THEN
					ASSERT((value.type.resolved IS SyntaxTree.FloatType) & (value.type.resolved(SyntaxTree.FloatType).sizeInBits =64));
					Evaluate(value, op);
					Emit(Push(property.position, op.op));
					ReleaseOperand(op);
					CallThis(position,"ActiveCellsRuntime","AddRealProperty",-1); (* must import *)
				ELSIF (property.type.resolved IS SyntaxTree.SetType) THEN
					ASSERT((value.type.resolved IS SyntaxTree.SetType));
					Evaluate(value, op);
					Emit(Push(property.position, op.op));
					ReleaseOperand(op);
					CallThis(position,"ActiveCellsRuntime","AddSetProperty",-1); (* must import *)
				ELSE
					HALT(200);
				END;
		END AddProperty;

		PROCEDURE AddModifiers(cellType: SyntaxTree.CellType; cell: SyntaxTree.Symbol; modifier: SyntaxTree.Modifier);
		VAR symbol: SyntaxTree.Symbol;
		BEGIN
			WHILE modifier # NIL DO
				symbol := cellType.FindProperty(modifier.identifier);
				ASSERT ((symbol # NIL) & (symbol IS SyntaxTree.Property));
				AddProperty(cellType, cell, symbol(SyntaxTree.Property), modifier.expression);
				modifier := modifier.nextModifier;
			END;
		END AddModifiers;

		PROCEDURE AppendModifier(VAR to: SyntaxTree.Modifier; this: SyntaxTree.Modifier);
		VAR last: SyntaxTree.Modifier;
		BEGIN
			IF to = NIL THEN
				to := SyntaxTree.NewModifier(this.position, this.identifier, this.expression);
			ELSE
				last := to;
				WHILE (last.nextModifier # NIL) & (this.identifier # last.identifier) DO
					last := last.nextModifier;
				END;
				IF last.identifier # this.identifier THEN
					ASSERT(last.nextModifier = NIL);
					last.SetNext(SyntaxTree.NewModifier(this.position, this.identifier, this.expression));
				END;
			END;
		END AppendModifier;

		PROCEDURE AppendModifiers(VAR to: SyntaxTree.Modifier; this: SyntaxTree.Modifier);
		BEGIN
			WHILE this # NIL DO
				AppendModifier(to, this);
				this := this.nextModifier;
			END;
		END AppendModifiers;

		PROCEDURE AppendCellTypeModifiers(VAR to: SyntaxTree.Modifier; c: SyntaxTree.CellType);
		VAR base: SyntaxTree.Type;
		BEGIN
			AppendModifiers(to, c.modifiers);
			base := c.GetBaseValueType();
			IF (base # NIL) & (base IS SyntaxTree.CellType) THEN
				AppendCellTypeModifiers(to, base(SyntaxTree.CellType))
			END;
		END AppendCellTypeModifiers;

		PROCEDURE AddPortProperty(modifier: SyntaxTree.Modifier; value: SyntaxTree.Expression);
		VAR name: ARRAY 256 OF CHAR; op: Operand;
		BEGIN
			Basic.GetString(modifier.identifier, name);
			PushConstString(name);

			IF SemanticChecker.IsStringType(modifier.expression.type) THEN
				ASSERT(SemanticChecker.IsStringType(value.type));
				Designate(value, op);
				PushString(op, value.type);
				ReleaseOperand(op);
				CallThisChecked(position,"ActiveCellsRuntime","AddPortStringProperty",4,FALSE);
			ELSIF (modifier.expression.type.resolved IS SyntaxTree.IntegerType) THEN
				ASSERT(value.type.resolved IS SyntaxTree.IntegerType);
				Evaluate(value, op);
				Emit(Push(modifier.position, op.op));
				ReleaseOperand(op);
				CallThisChecked(position,"ActiveCellsRuntime","AddPortIntegerProperty",3,FALSE);
			ELSE
				CallThisChecked(position,"ActiveCellsRuntime","AddPortFlagProperty",2,FALSE);
			END;
		END AddPortProperty;

		PROCEDURE AddPortProperties(modifier: SyntaxTree.Modifier);
		BEGIN
			WHILE modifier # NIL DO
				AddPortProperty(modifier, modifier.expression);
				modifier := modifier.nextModifier;
			END;
		END AddPortProperties;

		PROCEDURE PushPort(p: SyntaxTree.Expression);
		VAR op: Operand;
		BEGIN
			Evaluate(p, op);
			Emit(Push(p.position, op.op));
			ReleaseOperand(op);
			IF p IS SyntaxTree.Designator THEN
			AddPortProperties(p(SyntaxTree.Designator).modifiers)
			END;
		END PushPort;

		PROCEDURE PushString(op: Operand; actualType: SyntaxTree.Type);
		VAR tmp: IntermediateCode.Operand;
		BEGIN
			actualType := actualType.resolved;
			IF actualType IS SyntaxTree.StringType THEN
				Emit(Push(position,IntermediateCode.Immediate(addressType,actualType(SyntaxTree.StringType).length)));
			ELSIF actualType(SyntaxTree.ArrayType).form = SyntaxTree.Static THEN
				Emit(Push(position,IntermediateCode.Immediate(addressType,actualType(SyntaxTree.ArrayType).staticLength)));
			ELSE
				tmp := op.tag;
				IntermediateCode.MakeMemory(tmp,addressType);
				Emit(Push(position,tmp));
			END;
			Emit(Push(position,op.op))
		END PushString;

		(* conservative check if x is potentially on the heap, excluding the module heap
			required for generational garbage collector
		*)
		PROCEDURE OnHeap(x: SyntaxTree.Expression): BOOLEAN;
		BEGIN
			RETURN TRUE;
			(*! find a conservative and simple algorithm. The following does, for example, not work for records on the stack
				passed by reference.
			pos := x.position.start;
			WHILE (x # NIL) & ~(x IS SyntaxTree.DereferenceDesignator) & ~(x IS SyntaxTree.SelfDesignator) DO
				x := x(SyntaxTree.Designator).left;
			END;
			RETURN x # NIL;
			*)
		END OnHeap;

		PROCEDURE Allocate(x: SyntaxTree.BuiltinCallDesignator; VAR result: Operand);
		VAR
			p0, p1: SyntaxTree.Expression;
			recordType: SyntaxTree.RecordType; parameter: SyntaxTree.Expression;
			l,r: Operand; res,adr,reg: IntermediateCode.Operand; type: SyntaxTree.Type;
			constructor: SyntaxTree.Procedure; s0,s1: Operand;
			i: LONGINT; formalParameter: SyntaxTree.Parameter;
			tmp:IntermediateCode.Operand;
			size: LONGINT; dim,openDim,len: LONGINT; pointer: IntermediateCode.Operand; t0,t1: SyntaxTree.Type;
			exit,else,end: Label; procedureType: SyntaxTree.ProcedureType;
			name: Basic.SegmentedName; symbol: Sections.Section;
			staticLength: LONGINT;
			isTensor: BOOLEAN;
			baseType: SyntaxTree.Type;
			left: SyntaxTree.Expression;
			procedure: SyntaxTree.Procedure;
			temporaryVariable: SyntaxTree.Variable;
			dummy: IntermediateCode.Operand;
			needsTrace: BOOLEAN;
			n: ARRAY 256 OF CHAR;
			modifier: SyntaxTree.Modifier;
			previous, init: IntermediateCode.Section;
			prevScope: SyntaxTree.Scope;
			firstPar: LONGINT;
			saved: RegisterEntry;
			callingConvention: SyntaxTree.CallingConvention;

			PROCEDURE CallBodies(self: IntermediateCode.Operand; type: SyntaxTree.Type);
			VAR recordScope: SyntaxTree.RecordScope; procedure: SyntaxTree.Procedure; body: SyntaxTree.Body; flags: LONGINT;
				priority: IntermediateCode.Operand;
				op,callop: Operand;
			BEGIN
				IF type = NIL THEN RETURN END;
				type := type.resolved;
				IF type IS SyntaxTree.PointerType THEN
					type := type(SyntaxTree.PointerType).pointerBase.resolved
				END;
				IF type IS SyntaxTree.MathArrayType THEN RETURN END;
				CallBodies(self,type(SyntaxTree.RecordType).baseType);
				recordScope := type(SyntaxTree.RecordType).recordScope;
				IF recordScope.bodyProcedure # NIL THEN
					procedure := recordScope.bodyProcedure;
					body := procedure.procedureScope.body;
					Emit(Push(position,self));
					IF body.isActive THEN
						StaticCallOperand(procedure,callop);
						Emit(Push(position,callop.op));
						IF body.priority # NIL THEN Evaluate(body.priority,op); priority := op.op;
							Convert(priority,sizeType);
						ELSE priority := IntermediateCode.Immediate(sizeType,0)
						END;
						Emit(Push(position,priority));
						ReleaseIntermediateOperand(priority);
						IF backend.cooperative THEN
							Emit(Push(position,self));
							CallThis(position,"Activities","Create",3)
						ELSE
							flags := 0;
							IF body.isSafe THEN
								flags := 1;
							END;
							Emit(Push(position,IntermediateCode.Immediate(IntermediateCode.GetType(system,system.setType),flags)));
							Emit(Push(position,self));
							CallThis(position,"Objects","CreateProcess",4)
						END;
					ELSE
						Emit(Push(position,self));
						StaticCallOperand(procedure,callop);
						Emit(Call(position,callop.op,ProcParametersSize(procedure)));
					END;
					Emit(Pop(position,self));
				END;
			END CallBodies;

		BEGIN
			p0 := NIL; p1 := NIL; len := x.parameters.Length();
			IF len > 0 THEN p0 := x.parameters.GetExpression(0); t0 := p0.type.resolved END;
			IF len > 1 THEN p1 := x.parameters.GetExpression(1); t1 := p1.type.resolved END;
			IF x.type # NIL THEN
				type := x.type.resolved;
				firstPar := 0;
			ELSE
				type := p0.type.resolved;
				firstPar := 1;
			END;
			IF (type IS SyntaxTree.PointerType) & (type(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.RecordType)
			THEN
				recordType := type(SyntaxTree.PointerType).pointerBase.resolved(SyntaxTree.RecordType);
				IF backend.cooperative THEN
					size := ToMemoryUnits(system,system.SizeOf(recordType));
					IF ~type(SyntaxTree.PointerType).isPlain THEN
						IF recordType.isObject THEN
							INC (size, BaseObjectTypeSize * ToMemoryUnits(system,addressType.sizeInBits));
							IF recordType.IsActive() THEN
								INC (size, ActionTypeSize * ToMemoryUnits(system,addressType.sizeInBits))
							END;
							IF recordType.IsProtected() THEN
								INC (size, MonitorTypeSize * ToMemoryUnits(system,addressType.sizeInBits))
							END;
						ELSE
							INC (size, BaseRecordTypeSize * ToMemoryUnits(system,addressType.sizeInBits));
						END;
					END;
					Emit(Push(position,IntermediateCode.Immediate(sizeType,size)));
					CallThis(position,"Runtime","New", 1);
					pointer := NewRegisterOperand(IntermediateCode.GetType(system, type));
					Emit(Result(position, pointer));
					exit := NewLabel();
					BreqL(exit,pointer,nil);

					GetRecordTypeName (recordType,name);
					IF ~recordType.isObject THEN
						Basic.SuffixSegmentedName (name, Basic.MakeString ("@Pointer"));
					END;
					IntermediateCode.InitAddress(adr, addressType, name , 0, 0);
					Emit(Mov(position,IntermediateCode.Memory(addressType,pointer,0),adr));
					IF recordType.isObject THEN
						IF recordType.IsProtected() THEN
							DEC (size, MonitorTypeSize * ToMemoryUnits(system,addressType.sizeInBits));
							Emit(Mov(position,IntermediateCode.Memory(addressType,pointer,MonitorOffset * ToMemoryUnits(system,addressType.sizeInBits)), IntermediateCode.RegisterOffset(addressType,IntermediateCode.GeneralPurposeRegister,pointer.register,size)));
						END;
						IF recordType.IsActive() THEN
							DEC (size, ActionTypeSize * ToMemoryUnits(system,addressType.sizeInBits));
							Emit(Mov(position,IntermediateCode.Memory(addressType,pointer,ActionOffset * ToMemoryUnits(system,addressType.sizeInBits)), IntermediateCode.RegisterOffset(addressType,IntermediateCode.GeneralPurposeRegister,pointer.register,size)));
						END;
					END;

					(* initialize fields *)
					IF type(SyntaxTree.PointerType).isPlain THEN
						size := 0;
					ELSIF recordType.isObject THEN
						size := BaseObjectTypeSize;
					ELSE
						size := BaseRecordTypeSize;
					END;
					InitFields(recordType, pointer,size*ToMemoryUnits(system,addressType.sizeInBits));

					(* call initializer *)
					constructor := GetConstructor(recordType);
					IF constructor # NIL THEN
						(*! should be unified with ProcedureCallDesignator *)
						Emit(Push(position,pointer));
						ReleaseIntermediateOperand(pointer);
						formalParameter := constructor.type(SyntaxTree.ProcedureType).firstParameter;
						FOR i := firstPar TO x.parameters.Length()-1 DO
							PushParameter(x.parameters.GetExpression(i), formalParameter,SyntaxTree.OberonCallingConvention, FALSE, dummy,-1);
							formalParameter := formalParameter.nextParameter;
						END;

						(* static call of the constructor *)
						GetCodeSectionNameForSymbol(constructor,name);
						ASSERT(~constructor.isInline);
						IF constructor.scope.ownerModule # module.module THEN
							symbol := NewSection(module.importedSections, Sections.CodeSection, name,constructor,commentPrintout # NIL);
						ELSE
							symbol := NewSection(module.allSections, Sections.CodeSection, name,constructor,commentPrintout # NIL);
						END;
						Emit(Call(position,IntermediateCode.Address(addressType, symbol.name, GetFingerprint(constructor), 0),ProcParametersSize(constructor) - ToMemoryUnits(system,addressType.sizeInBits)));
						IntermediateCode.InitRegister(pointer,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
						Emit(Pop(position,pointer));
					END;

					(* call bodies *)
					CallBodies(pointer,type);

					SetLabel(exit);
					needsTrace := p0.NeedsTrace();
					IF needsTrace THEN ModifyAssignments(true) END;
					IF ~type(SyntaxTree.PointerType).isDisposable THEN
						Emit(Push(position, pointer));
						CallThisChecked(position,"GarbageCollector","Watch",0,FALSE);
						Emit(Pop(position, pointer));
					END;

					IF x.type # NIL THEN
						temporaryVariable := GetTemporaryVariable(type, FALSE, FALSE (* untraced *));
						Symbol(temporaryVariable,l); (*Designate(temporaryVariable,l)*)
					ELSE
						Designate(p0,l);
					END;
					IF needsTrace THEN
						CallAssignPointer(l.op, pointer);
					ELSE
						ToMemory(l.op,addressType,0);
						Emit(Mov(position,l.op,pointer));
					END;
					ReleaseIntermediateOperand(pointer);
					IF (x.type # NIL) THEN
						result := l; (* temporary variable is the result of NEW Type() *)
					ELSE
						ReleaseOperand(l);
					END;
					IF needsTrace THEN ModifyAssignments(false) END;
				ELSE (* not cooperative backend *)
					temporaryVariable := GetTemporaryVariable(type, FALSE, FALSE (* untraced *));
					IF temporaryVariable # NIL THEN
						Symbol(temporaryVariable,l); (*Designate(temporaryVariable,l)*)
					ELSE
						Designate(p0,l);
					END;
					(* l.op contains address of pointer to record *)
					Emit(Push(position,l.op)); (* address for use after syscall *)
					Emit(Push(position,l.op));
					ReleaseOperand(l);

					(* push type descriptor *)
					reg := TypeDescriptorAdr(recordType);
					Emit(Push(position,reg));
					ReleaseIntermediateOperand(reg);

					(* push realtime flag *)
					IF type.resolved.isRealtime THEN Emit(Push(position,true));
					ELSE Emit(Push(position,false));
					END;

					CallThis(position,"Heaps","NewRec", 3);
					(* check allocation success, if not successful then do not call initializers and bodies *)
					IntermediateCode.InitRegister(pointer,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
					Emit(Pop(position,pointer));
					MakeMemory(reg,pointer,addressType,0);
					ReleaseIntermediateOperand(pointer);
					pointer := reg;
					exit := NewLabel();
					BreqL(exit,pointer,nil);
					Emit(Push(position,pointer));

					(* initialize fields *)
					InitFields(recordType, pointer,0);

					(* call initializer *)
					constructor := GetConstructor(recordType);
					IF constructor # NIL THEN
						(*! should be unified with ProcedureCallDesignator *)
						Emit(Push(position,pointer));
						ReleaseIntermediateOperand(pointer);
						formalParameter := constructor.type(SyntaxTree.ProcedureType).firstParameter;
						FOR i := firstPar TO x.parameters.Length()-1 DO
							PushParameter(x.parameters.GetExpression(i), formalParameter,SyntaxTree.OberonCallingConvention, FALSE, dummy,-1);
							formalParameter := formalParameter.nextParameter;
						END;
						(* static call of the constructor *)
						GetCodeSectionNameForSymbol(constructor,name);
						ASSERT(~constructor.isInline);
						IF constructor.scope.ownerModule # module.module THEN
							symbol := NewSection(module.importedSections, Sections.CodeSection, name,constructor,commentPrintout # NIL);
						ELSE
							symbol := NewSection(module.allSections, Sections.CodeSection, name,constructor,commentPrintout # NIL);
						END;
						Emit(Call(position,IntermediateCode.Address(addressType, symbol.name, GetFingerprint(constructor), 0),ProcParametersSize(constructor)));
					ELSE
						ReleaseIntermediateOperand(pointer);
					END;

					IntermediateCode.InitRegister(pointer,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
					Emit(Pop(position,pointer));

					IF (temporaryVariable # NIL) & (x.type = NIL) THEN
						Designate(p0,l);
						IF backend.writeBarriers & OnHeap(p0) THEN
							SaveRegisters();ReleaseUsedRegisters(saved);
							Emit(Push(position,l.op));
							Emit(Push(position,pointer));
							CallThis(position,"Heaps","Assign",2);
							RestoreRegisters(saved);
						ELSE
							ToMemory(l.op,addressType,0);
							Emit(Mov(position,l.op,pointer));
						END;
						ReleaseOperand(l);
						result.tag := emptyOperand;
					ELSIF (x.type # NIL) THEN
						result := l; (* temporary variable is the result of NEW Type() *)
					END;

					(* call bodies *)
					CallBodies(pointer,type);
					ReleaseIntermediateOperand(pointer);

					IF (temporaryVariable # NIL) & (x.type = NIL) THEN
						end := NewLabel();
						BrL(end);
						SetLabel(exit);
						Designate(p0,l);
						ToMemory(l.op,addressType,0);
						Emit(Mov(position,l.op,nil)); (* write NIL to adr *)
						ReleaseOperand(l);
						SetLabel(end);
					ELSE
						SetLabel(exit);
					END;
				END;
			ELSIF (type IS SyntaxTree.PointerType) & (type(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.ArrayType)  THEN
				type := type(SyntaxTree.PointerType).pointerBase.resolved;
				IF ~backend.cooperative THEN  (* simpler version *)
					(*
						push len0
						push len1
						push len2
						push len_size
						push len_adr

						push tag
						push static elements
						push element size
						push adr
					*)

					dim := 0;

					FOR i := x.parameters.Length()-1 TO firstPar BY -1 DO
						type := type(SyntaxTree.ArrayType).arrayBase.resolved;
						parameter := x.parameters.GetExpression(i);
						Evaluate(parameter,r);
						IF (r.op.mode # IntermediateCode.ModeImmediate) & ~isUnchecked THEN
							IntermediateCode.InitImmediate(tmp,IntermediateCode.GetType(system,parameter.type),0);
							TrapC(BrgeL,r.op,tmp,ArraySizeTrap);
						END;
						Emit(Push(position,r.op));
						ReleaseOperand(r);
						INC(dim);
					END;

					IntermediateCode.InitRegister(adr,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
					Emit(Mov(position, adr, sp));
					Emit(Push(position, IntermediateCode.Immediate(sizeType, dim)));
					Emit(Push(position, adr));
					ReleaseIntermediateOperand(adr);

					openDim := dim;

					staticLength := 1;
					IF type IS SyntaxTree.ArrayType THEN
						WHILE (type IS SyntaxTree.ArrayType) DO (* static array *)
							staticLength := staticLength * type(SyntaxTree.ArrayType).staticLength;
							type := type(SyntaxTree.ArrayType).arrayBase.resolved;
						END;
					END;
					IF SemanticChecker.ContainsPointer(type) THEN
						tmp := TypeDescriptorAdr(type);
					ELSE
						tmp := nil;
					END;
					Emit(Push(position,tmp)); (* type descriptor *)
					Emit(Push(position, IntermediateCode.Immediate(sizeType, staticLength))); (* static length *)
					staticLength := ToMemoryUnits(system,system.AlignedSizeOf(type));
					Emit(Push(position, IntermediateCode.Immediate(sizeType, staticLength))); (* element size *)

					Designate(p0,l);
					Emit(Push(position,l.op)); (* address *)
					ReleaseOperand(l);

					CallThis(position,"Heaps","NewArray", 6);

					tmp := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,dim*system.addressSize));
					Emit(Add(position,sp,sp,tmp));
				ELSE
					dim := 0;
					IntermediateCode.InitOperand(reg);
					IF p1 # NIL THEN
						FOR i := firstPar TO x.parameters.Length()-1 DO
							type := type(SyntaxTree.ArrayType).arrayBase.resolved;
							parameter := x.parameters.GetExpression(i);
							Evaluate(parameter,r);
							IF (r.op.mode # IntermediateCode.ModeImmediate) & ~isUnchecked THEN
								IntermediateCode.InitImmediate(tmp,IntermediateCode.GetType(system,parameter.type),0);
								TrapC(BrgeL,r.op,tmp,ArraySizeTrap);
							END;
							Emit(Push(position,r.op));
							IF i=1 THEN
								CopyInt(reg,r.op);
							ELSE
								MulInt(reg, reg, r.op);
							END;
							ReleaseOperand(r);
							INC(dim);
						END;
						Convert(reg,addressType);
					ELSE
						IntermediateCode.InitRegister(reg,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
						Emit(Mov(position,reg,IntermediateCode.Immediate(addressType,1)));
					END;

					openDim := dim;
					ASSERT(~(type IS SyntaxTree.ArrayType) OR (type(SyntaxTree.ArrayType).form = SyntaxTree.Static));

					IF backend.cooperative THEN
						size := ToMemoryUnits(system,system.SizeOf(type));
						WHILE type IS SyntaxTree.ArrayType DO
							type := type(SyntaxTree.ArrayType).arrayBase.resolved;
						END;
						size := size DIV ToMemoryUnits(system,system.SizeOf(type));
						IF (size # 1) THEN
							MulInt(reg,reg,IntermediateCode.Immediate(addressType,size));
						END;
						Emit(Push(position,reg));
						size := ToMemoryUnits(system,system.SizeOf(type));
						IF (size # 1) THEN
							MulInt(reg,reg,IntermediateCode.Immediate(addressType,size));
						END;
						AddInt(reg, reg, IntermediateCode.Immediate(addressType,ToMemoryUnits(system,(BaseArrayTypeSize + openDim)* system.addressSize)));
						(*Emit(Add(position,reg,reg,IntermediateCode.Immediate(addressType,ToMemoryUnits(system,(BaseArrayTypeSize + openDim)* system.addressSize))));*)
						Emit(Push(position,reg));
						ReleaseIntermediateOperand(reg);
						CallThis(position,"Runtime","New", 1);

						pointer := NewRegisterOperand(IntermediateCode.GetType(system, p0.type));
						Emit(Result(position, pointer));
						exit := NewLabel();
						else := NewLabel();
						BreqL(else,pointer,nil);

						IF ~type.hasPointers THEN
							Basic.ToSegmentedName ("BaseTypes.Array",name);
						ELSIF type IS SyntaxTree.RecordType THEN
							Basic.ToSegmentedName ("BaseTypes.RecordArray",name);
						ELSIF type IS SyntaxTree.ProcedureType THEN
							Basic.ToSegmentedName ("BaseTypes.DelegateArray",name);
						ELSE
							Basic.ToSegmentedName ("BaseTypes.PointerArray",name);
						END;
						Emit(Mov(position,IntermediateCode.Memory(addressType,pointer,0),IntermediateCode.Address(addressType,name,0,0)));

						Emit(Pop(position,IntermediateCode.Memory(addressType,pointer,ToMemoryUnits(system,LengthOffset * system.addressSize))));
						Emit(Mov(position,IntermediateCode.Memory(addressType,pointer,ToMemoryUnits(system,DataOffset * system.addressSize)),IntermediateCode.RegisterOffset(addressType,IntermediateCode.GeneralPurposeRegister,pointer.register,ToMemoryUnits(system,(BaseArrayTypeSize + openDim)* system.addressSize))));
						IF type IS SyntaxTree.RecordType THEN
							GetRecordTypeName(type(SyntaxTree.RecordType),name);
							Emit(Mov(position,IntermediateCode.Memory(addressType,pointer,ToMemoryUnits(system,DescriptorOffset * system.addressSize)),IntermediateCode.Address(addressType,name,0,0)));
						ELSE
							Emit(Mov(position,IntermediateCode.Memory(addressType,pointer,ToMemoryUnits(system,DescriptorOffset * system.addressSize)),nil));
						END;

						FOR i := 0 TO openDim - 1 DO
							Emit(Pop(position,IntermediateCode.Memory(addressType,pointer,ToMemoryUnits(system,(BaseArrayTypeSize + i)* system.addressSize))));
						END;

						needsTrace := p0.NeedsTrace();
						IF needsTrace THEN ModifyAssignments(true) END;
						IF ~p0.type.resolved(SyntaxTree.PointerType).isDisposable THEN
							Emit(Push(position, pointer));
							CallThisChecked(position,"GarbageCollector","Watch",0,FALSE);
							Emit(Pop(position, pointer));
						END;
						Designate(p0,l);
						IF needsTrace THEN
							CallAssignPointer(l.op, pointer);
							ModifyAssignments(false);
						ELSE
							ToMemory(l.op,addressType,0);
							Emit(Mov(position,l.op,pointer));
						END;
						ReleaseIntermediateOperand(pointer);
						ReleaseOperand(l);
						BrL(exit);

						SetLabel(else);
						Emit(Add(position,sp,sp,IntermediateCode.Immediate(addressType,ToMemoryUnits(system,(openDim+1)*system.addressSize))));
						Designate(p0,l);
						IF needsTrace THEN
							CallResetProcedure(l.op,l.tag,p0.type.resolved);
						ELSE
							ToMemory(l.op,addressType,0);
							Emit(Mov(position,l.op,pointer));
						END;
						ReleaseOperand(l);
						SetLabel(exit);

					ELSE
						IF SemanticChecker.ContainsPointer(type) THEN
							IF type IS SyntaxTree.ArrayType THEN
								staticLength := 1;
								WHILE (type IS SyntaxTree.ArrayType) DO (* static array *)
									staticLength := staticLength * type(SyntaxTree.ArrayType).staticLength;
									type := type(SyntaxTree.ArrayType).arrayBase.resolved;
								END;
								tmp := IntermediateCode.Immediate(reg.type,staticLength);
								MulInt(reg,reg,tmp);
							END;
							Designate(p0,l);
							IF openDim > 0 THEN
								Emit(Push(position,l.op)); (* address for use after syscall *)
							END;
							Emit(Push(position,l.op)); (* address *)
							ReleaseOperand(l);

							tmp := TypeDescriptorAdr(type);
							Emit(Push(position,tmp)); (* type descriptor *)
							ReleaseIntermediateOperand(tmp);

							Emit(Push(position,reg)); (* number Elements *)
							ReleaseIntermediateOperand(reg);
							tmp := IntermediateCode.Immediate(addressType,dim);
							Emit(Push(position,tmp)); (* dimensions *)
							(* push realtime flag *)
							IF (p0.type.resolved.isRealtime) THEN Emit(Push(position,true));
							ELSE Emit(Push(position,false));
							END;
							CallThis(position,"Heaps","NewArr",5)
						ELSE
							size := ToMemoryUnits(system,system.SizeOf(type));
							IF (size # 1) THEN
								MulInt(reg, reg, IntermediateCode.Immediate(addressType,size));
								(*
								Emit(Mul(position,reg,reg,IntermediateCode.Immediate(addressType,size))); (*! optimize the multiplication of immediate operands *)
								*)
							END;
							tmp := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,ArrayDimTable * system.addressSize+ system.addressSize+  system.addressSize * 2 * (openDim DIV 2)));
							(* DIV 2 term for some strange alignment, don't understand it at the moment - copied from PCC *)
							AddInt(reg, reg, tmp);
							(*
							Emit(Add(position,reg,reg,tmp));
							*)
							Designate(p0,l);
							IF openDim >0 THEN
								Emit(Push(position,l.op)); (* address for use after syscall *)
							END;
							Emit(Push(position,l.op)); (* address for syscall *)
							ReleaseOperand(l); (* pointer address *)

							Emit(Push(position,reg)); (* size *)
							ReleaseIntermediateOperand(reg);
							(* push realtime flag *)
							IF (p0.type.resolved.isRealtime) THEN Emit(Push(position,true));
							ELSE Emit(Push(position,false));
							END;
							CallThis(position,"Heaps","NewSys", 3)
						END;

						IF openDim > 0 THEN
							IntermediateCode.InitRegister(adr,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
							Emit(Pop(position,adr));
							ToMemory(adr,addressType,0);
							ReuseCopy(tmp,adr);
							ReleaseIntermediateOperand(adr);
							adr := tmp;

							else := NewLabel();
							BreqL(else,adr,IntermediateCode.Immediate(addressType,0));

							i := openDim-1;
							IntermediateCode.InitRegister(reg,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
							WHILE (i >= 0) DO
								Emit(Pop(position,reg));
								IntermediateCode.InitMemory(res,addressType,adr,ToMemoryUnits(system,ArrayDimTable* system.addressSize + system.addressSize*((openDim-1)-i)));
								Emit(Mov(position,res,reg));
								DEC(i);
							END;
							ReleaseIntermediateOperand(adr);
							ReleaseIntermediateOperand(reg);

							exit := NewLabel();
							BrL(exit);
							SetLabel(else);
							(* else part: array could not be allocated *)
							tmp := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,openDim*system.addressSize));
							Emit(Add(position,sp,sp,tmp));
							SetLabel(exit);
						END;
					END;
				END;
			ELSIF (type IS SyntaxTree.MathArrayType) THEN
				IF t1 IS SyntaxTree.MathArrayType THEN (* NEW(a, array) *)
					IF GetRuntimeProcedure("FoxArrayBase","AllocateTensorX",procedure,TRUE) THEN
						left := SyntaxTree.NewSymbolDesignator(Basic.invalidPosition,NIL, NIL,procedure);
						procedureType := procedure.type(SyntaxTree.ProcedureType);
						callingConvention := procedureType.callingConvention;
						left.SetType(procedure.type);
						formalParameter := procedureType.firstParameter;
						(* push array to allocate *)
						PushParameter(p0, formalParameter, callingConvention, FALSE, dummy,-1);
						formalParameter :=formalParameter.nextParameter;
						(* push length array *)
						PushParameter(p1, formalParameter, callingConvention, FALSE, dummy,-1);
						(* push size *)
						type := t0;
						WHILE (type IS SyntaxTree.MathArrayType) & (type(SyntaxTree.MathArrayType).form # SyntaxTree.Static) DO
							type := type(SyntaxTree.MathArrayType).arrayBase.resolved;
						END;
						tmp := IntermediateCode.Immediate(IntermediateCode.GetType(system, system.sizeType),ToMemoryUnits(system,system.SizeOf(type))); (* alignment *)
						Emit(Push(position,tmp));
						(* *)
						IF SemanticChecker.ContainsPointer(type) THEN
							tmp := TypeDescriptorAdr(type);
						ELSE
							tmp := IntermediateCode.Immediate(addressType, 0);
						END;
						Emit(Push(position,tmp)); (* type descriptor *)

						StaticCallOperand(procedure,result);
						Emit(Call(position,result.op,ProcParametersSize(procedure)));
						ReleaseOperand(result);
					END;
					(*
					designator := SyntaxTree.NewIdentifierDesignator(InvalidPosition, Global.ArrayBaseName);
					designator := SyntaxTree.NewSelectorDesignator(InvalidPosition, designator, SyntaxTree.NewIdentifier(InvalidPosition, "AllocateTensorX"));
					result := ResolveExpression(SyntaxTree.NewParameterDesignator(InvalidPosition, designator, actualParameters));
					*)
				ELSE
					(*
						push len0
						push len1
						push len2

						push size
						push len_adr
						push element_size
						push tag
						push adr
					*)

					dim := 0;

					IF type(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
						isTensor := TRUE;
					ELSE
						isTensor := FALSE;
					END;

					FOR i := x.parameters.Length()-1 TO firstPar BY -1 DO
						IF ~isTensor THEN
							type := type(SyntaxTree.MathArrayType).arrayBase.resolved;
						END;
						parameter := x.parameters.GetExpression(i);
						Evaluate(parameter,r);
						IF (r.op.mode # IntermediateCode.ModeImmediate) & ~isUnchecked THEN
							IntermediateCode.InitImmediate(tmp,IntermediateCode.GetType(system,parameter.type),0);
							TrapC(BrgeL,r.op,tmp,ArraySizeTrap);
						END;
						Emit(Push(position,r.op));
						ReleaseOperand(r);
						INC(dim);
					END;

					IntermediateCode.InitRegister(adr,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
					Emit(Mov(position, adr, sp));
					Emit(Push(position, IntermediateCode.Immediate(sizeType, dim)));
					Emit(Push(position, adr));
					ReleaseIntermediateOperand(adr);

					openDim := dim;
					ASSERT(~(type IS SyntaxTree.MathArrayType) OR (type(SyntaxTree.MathArrayType).form IN {SyntaxTree.Static,SyntaxTree.Tensor}));

					IF isTensor THEN
						baseType := SemanticChecker.ArrayBase(type,MAX(LONGINT));
					ELSE
						baseType := SemanticChecker.ArrayBase(type,openDim);
					END;

					staticLength := ToMemoryUnits(system,system.AlignedSizeOf(baseType));
					Emit(Push(position, IntermediateCode.Immediate(sizeType, staticLength)));

					IF SemanticChecker.ContainsPointer(baseType) THEN
						tmp := TypeDescriptorAdr(baseType);
					ELSE
						tmp := nil;
					END;
					Emit(Push(position,tmp)); (* type descriptor *)

					IF isTensor & GetRuntimeProcedure ("FoxArrayBase","AllocateTensorA", procedure, TRUE) THEN
					ELSIF GetRuntimeProcedure ("FoxArrayBase","AllocateArrayA", procedure, TRUE) THEN
					ELSE (* error message has already been emited *)
						RETURN;
					END;

					Designate(p0,l);
					IF isTensor THEN
						Emit(Push(position,l.op)); (* address *)
					ELSE
						Emit(Push(position,l.tag)); (* address *)
					END;
					ReleaseOperand(l);

					StaticCallOperand(procedure,result);
					Emit(Call(position,result.op,ProcParametersSize(procedure)));
					ReleaseOperand(result);

					tmp := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,dim*system.addressSize));
					Emit(Add(position,sp,sp,tmp));
			END;
		ELSIF (type IS SyntaxTree.PointerType) & (type(SyntaxTree.PointerType).pointerBase.resolved  IS SyntaxTree.CellType)
			THEN
				IF ~backend.cellsAreObjects THEN RETURN END;
				IF InCellScope(currentScope) THEN
					PushSelfPointer()
				ELSE
					Emit(Push(position, nil));
				END;
				(* push temp address *)
				baseType := type(SyntaxTree.PointerType).pointerBase.resolved;
				temporaryVariable := GetTemporaryVariable(type, FALSE, FALSE (* untraced *));
				Symbol(temporaryVariable,l); (*Designate(temporaryVariable,l)*)
				(* l.op contains address of pointer to record *)
				Emit(Push(position,l.op)); (* address for use after syscall *)
				ReleaseOperand(l);

				(* push type descriptor *)
				reg := TypeDescriptorAdr(baseType);
				Emit(Push(position,reg));
				ReleaseIntermediateOperand(reg);

				(* push name *)
				(*Global.GetSymbolName(p0, n);*)

				IF currentScope IS SyntaxTree.ProcedureScope THEN
					Global.GetSymbolName(currentScope(SyntaxTree.ProcedureScope).ownerProcedure, n)
				ELSE
					Global.GetModuleName(module.module, n);
				END;
				Strings.Append(n,"@"); Strings.AppendInt(n, p0.position.start);
				(*type.typeDeclaration.GetName(n);*)
				PushConstString(n);

				(* push cellnet boolean *)
				PushConstBoolean(baseType(SyntaxTree.CellType).isCellNet);
				(* push engine boolean *)
				PushConstBoolean(baseType(SyntaxTree.CellType).FindProperty(Global.NameEngine) # NIL);
				(* allocate *)
				CallThis(position,"ActiveCellsRuntime","Allocate",7);

				Symbol(temporaryVariable,l); (*Designate(temporaryVariable,l)*)
				(* l.op contains address of pointer to record *)
				ToMemory(l.op,addressType,0);
				(* l.op contains value  of pointer to record *)
				InitFields(baseType, l.op,0);

				(* add capabilities *)
				modifier := p0(SyntaxTree.Designator).modifiers;

				IF (p0 IS SyntaxTree.SymbolDesignator) & (p0(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Variable) THEN
					(*modifier := p0(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Variable).modifiers;*)
					AppendModifiers(modifier, p0(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Variable).modifiers );
					(* AddModifiers(baseType(SyntaxTree.CellType), temporaryVariable, modifier);*)
				END;
				AppendCellTypeModifiers(modifier, baseType(SyntaxTree.CellType));
				AddModifiers(baseType(SyntaxTree.CellType), temporaryVariable, modifier);

				Symbol(temporaryVariable,l); (*Designate(temporaryVariable,l)*)
				(* l.op contains address of pointer to record *)
				ToMemory(l.op,addressType,0);
				(* l.op contains value  of pointer to record *)
				Emit(Push(position,l.op)); (* address for use after syscall *)
				ReleaseOperand(l);
				CallThis(position,"ActiveCellsRuntime","FinishedProperties",1);

				prevScope := currentScope;
				init := OpenInitializer(temporaryVariable, baseType(SyntaxTree.CellType).cellScope);
				previous := section;
				section := init;

				(* add ports *)
				AddPorts(temporaryVariable, baseType(SyntaxTree.CellType));

				CloseInitializer(previous);
				currentScope := prevScope;

				Symbol(temporaryVariable,l);
				ToMemory(l.op,addressType,0);
				Emit(Push(position,l.op));
				Emit(Call(position,IntermediateCode.Address(addressType, init.name, 0, 0), ToMemoryUnits(system, addressType.sizeInBits)));

				(* call initializer *)
				constructor := baseType(SyntaxTree.CellType).cellScope.constructor (*GetConstructor(p0.type.resolved(SyntaxTree.PointerType).pointerBase.resolved(SyntaxTree.RecordType))*);
				IF constructor # NIL THEN
					(*! should be unified with ProcedureCallDesignator *)
					IF backend.cellsAreObjects THEN
						Symbol(temporaryVariable,l);
						ToMemory(l.op,addressType,0);
						Emit(Push(position,l.op));
						ReleaseOperand(l);
					END;
					formalParameter := constructor.type(SyntaxTree.ProcedureType).firstParameter;
					FOR i := firstPar TO x.parameters.Length()-1 DO
						PushParameter(x.parameters.GetExpression(i), formalParameter,SyntaxTree.OberonCallingConvention, FALSE, dummy,-1);
						formalParameter := formalParameter.nextParameter;
					END;
					(* static call of the constructor *)
					Global.GetSymbolSegmentedName(constructor,name);
					ASSERT(~constructor.isInline);
					IF constructor.scope.ownerModule # module.module THEN
						symbol := NewSection(module.importedSections, Sections.CodeSection, name, constructor, commentPrintout # NIL);
					ELSE
						symbol := NewSection(module.allSections, Sections.CodeSection, name, constructor, commentPrintout # NIL);
					END;
					Emit(Call(position,IntermediateCode.Address(addressType, symbol.name, GetFingerprint(constructor), 0),ProcParametersSize(constructor)));
				(*ELSE
					ReleaseIntermediateOperand(pointer);*)
				END;

				Symbol(temporaryVariable,l); (*Designate(temporaryVariable,l)*)
				ToMemory(l.op, addressType, 0);
				Designate(p0,s0);
				ToMemory(s0.op,addressType,0);
				Emit(Mov(position,s0.op,l.op));
				ReleaseOperand(l);
				ReleaseOperand(s0);
				result.tag := emptyOperand;

				(* start *)
				IF baseType(SyntaxTree.CellType).cellScope.bodyProcedure # NIL THEN
					(* push cell *)
					Symbol(temporaryVariable, l);
					ToMemory(l.op,addressType,0);
					Emit(Push(Basic.invalidPosition,l.op));
					(* push delegate *)
					Emit(Push(Basic.invalidPosition,l.op));
					ReleaseOperand(l);
					StaticCallOperand(baseType(SyntaxTree.CellType).cellScope.bodyProcedure,s1);
					Emit(Push(position, s1.op));
					ReleaseOperand(s1);

					CallThis(position,"ActiveCellsRuntime","Start",3);
				END;

				(*IF temporaryVariable # NIL THEN
					end := NewLabel();
					BrL(end);
					SetLabel(exit);
					Designate(p0,l);
					ToMemory(l.op,addressType,0);
					Emit(Mov(position,l.op,nil)); (* write NIL to adr *)
					ReleaseOperand(l);
					SetLabel(end);
				ELSE
					SetLabel(exit);
				END;
				*)
				(*Error(p0.position,"cannot be allocated in runtime yet");*)
			ELSE (* no pointer to record, no pointer to array *)
				IF ~backend.cellsAreObjects & (type IS SyntaxTree.CellType) THEN
					(* ignore new statement *)
					Warning(p0.position, "cannot run on final hardware");
				ELSE
					HALT(200);
				END;
			END;
		END Allocate;

		PROCEDURE DesignateBuiltinCallDesignator(x: SyntaxTree.BuiltinCallDesignator; VAR result: Operand);
		VAR
			p0,p1,p2: SyntaxTree.Expression; len,val: LONGINT; l,r: Operand; res,adr,reg: IntermediateCode.Operand; type, componentType: SyntaxTree.Type;
			s0,s1,s2: Operand; hint: HUGEINT;
			i: LONGINT; formalParameter: SyntaxTree.Parameter;
			tmp:IntermediateCode.Operand;
			size: LONGINT;
			t0,t1,t2: SyntaxTree.Type; trueL,ignore: Label;
			exit,else,end: Label; procedureType: SyntaxTree.ProcedureType;
			operand: Operand;
			dest: IntermediateCode.Operand;
			itype: IntermediateCode.Type;
			convert: BOOLEAN;
			left: SyntaxTree.Expression;
			call: SyntaxTree.Designator;
			procedure: SyntaxTree.Procedure;
			customBuiltin: SyntaxTree.CustomBuiltin;
			isVarPar: ARRAY 3 OF BOOLEAN;
			callsection: Sections.Section;
			segmentedName: Basic.SegmentedName;
			needsTrace: BOOLEAN;

			PROCEDURE PushTD(type: SyntaxTree.Type);
			VAR op: IntermediateCode.Operand;
			BEGIN
				IF type = NIL THEN Emit(Push(position,IntermediateCode.Immediate(addressType,0)))
				ELSIF type.resolved IS SyntaxTree.AnyType THEN Emit(Push(position,IntermediateCode.Immediate(addressType,1)))
				ELSE
					IF type.resolved IS SyntaxTree.PointerType THEN
						type := type.resolved(SyntaxTree.PointerType).pointerBase;
					END;
					op := TypeDescriptorAdr(type.resolved);
					Emit(Push(position,op));
				END
			END PushTD;


		BEGIN
			IF Trace THEN TraceEnter("DesignateBuiltinCallDesignator") END;

			dest := destination; destination := emptyOperand;
			p0 := NIL; p1 := NIL; p2 := NIL; len := x.parameters.Length();
			IF len > 0 THEN p0 := x.parameters.GetExpression(0); t0 := p0.type.resolved END;
			IF len > 1 THEN p1 := x.parameters.GetExpression(1); t1 := p1.type.resolved END;
			IF len > 2 THEN p2 := x.parameters.GetExpression(2); t2 := p2.type.resolved END;

			CASE x.id OF

			(* ---- COPY ----- *)
			|Global.Copy:
				CopyString(p1,p0); (* roles exchanged: COPY ( src => dest ) *)
			(* ---- EXCL, INCL----- *)
			|Global.Excl,Global.Incl:
				Evaluate(p0,s0);
				Evaluate(p1,s1);
				Convert(s1.op,IntermediateCode.GetType(system,t0));
				IF (s1.op.mode # IntermediateCode.ModeImmediate) & ~isUnchecked THEN
					TrapC(BrltL,s1.op,IntermediateCode.Immediate(s1.op.type,t0.sizeInBits),IndexCheckTrap);
				END;
				ReuseCopy(res,s0.op);
				ReleaseOperand(s0);
				Reuse1(tmp,s1.op);
				ReleaseOperand(s1);
				Emit(Shl(position,tmp,IntermediateCode.Immediate(s1.op.type,1),s1.op));
				IF x.id = Global.Excl THEN
					Emit(Not(position,tmp,tmp));
					Emit(And(position,res,res,tmp));
				ELSE
					Emit(Or(position,res,res,tmp));
				END;
				ReleaseIntermediateOperand(tmp);
				Designate(p0,s0);
				ToMemory(s0.op,s1.op.type,0);
				Emit(Mov(position,s0.op,res));
				ReleaseOperand(s0); ReleaseIntermediateOperand(res);
			(* ---- DISPOSE ----- *)
			|Global.Dispose:
				Designate(p0,s0);
				Emit(Push(position,s0.op));
				ReleaseOperand(s0);
				CallThis(position,"Runtime","Dispose", 1);
			(* ---- GETPROCEDURE ----- *)
			|Global.GetProcedure:
				Designate(p0,s0);
				PushString(s0,p0.type);
				Designate(p1,s1);
				PushString(s1,p1.type);
				procedureType := p2.type.resolved(SyntaxTree.ProcedureType);
				IF (procedureType.firstParameter = NIL) OR (procedureType.firstParameter.access = SyntaxTree.Hidden) THEN PushTD(NIL)
				ELSE PushTD(procedureType.firstParameter.type)
				END;
				PushTD(procedureType.returnType);

				Designate(p2,s2);
				Emit(Push(position,s2.op));
				ReleaseOperand(s0); ReleaseOperand(s1); ReleaseOperand(s2);
				CallThis(position,"Modules","GetProcedure", 7);
			(* ---- ASH, LSH, ROT ----- *)
			|Global.Ash, Global.Asr, Global.Lsh, Global.Rot, Global.Ror:
				Evaluate(p0,s0);
				IF (x.id = Global.Lsh) OR (x.id = Global.Rot) OR (x.id = Global.Ror)THEN
					(* make unsigned arguments in order to produced a logical shift *)
					IF s0.op.type.form = IntermediateCode.SignedInteger THEN
						convert:= TRUE;
						itype := s0.op.type;
						IntermediateCode.InitType(itype,IntermediateCode.UnsignedInteger,s0.op.type.sizeInBits);
						Convert(s0.op,itype);
					ELSE
						convert := FALSE;
					END;
				END;
				Evaluate(p1,s1);
				IF IsIntegerConstant(p1,hint) THEN
					ReuseCopy(reg,s0.op);
					IF hint  > 0 THEN
						IntermediateCode.InitImmediate(s1.op,s1.op.type,hint);
						IF x.id = Global.Ash THEN Emit(Shl(position,reg,s0.op,s1.op))
						ELSIF x.id = Global.Lsh THEN Emit(Shl(position,reg,s0.op,s1.op))
						ELSIF x.id = Global.Rot THEN Emit(Rol(position,reg,s0.op,s1.op))
						ELSIF x.id = Global.Ror THEN Emit(Ror(position,reg,s0.op,s1.op))
						ELSIF x.id = Global.Asr THEN Emit(Shr(position,reg,s0.op,s1.op))
						END;
					ELSIF hint < 0 THEN
						IntermediateCode.InitImmediate(s1.op,s1.op.type,-hint);
						IF x.id = Global.Ash THEN Emit(Shr(position,reg,s0.op,s1.op));
						ELSIF x.id = Global.Lsh THEN Emit(Shr(position,reg,s0.op,s1.op));
						ELSIF x.id = Global.Rot THEN Emit(Ror(position,reg,s0.op,s1.op));
						ELSIF x.id = Global.Ror THEN Emit(Rol(position,reg,s0.op,s1.op))
						ELSIF x.id = Global.Asr THEN Emit(Shl(position,reg,s0.op,s1.op))
						END;
					END;
					ReleaseOperand(s0); ReleaseOperand(s1);
				ELSE
					exit := NewLabel();
					end := NewLabel();
					ReuseCopy(reg,s0.op);
					BrgeL(exit,s1.op,IntermediateCode.Immediate(IntermediateCode.GetType(system,p1.type),0));
					Reuse1(tmp,s1.op);
					Emit(Neg(position,tmp,s1.op));
					Convert(tmp,s1.op.type);
					IF x.id = Global.Ash THEN Emit(Shr(position,reg,reg,tmp))
					ELSIF x.id = Global.Lsh THEN Emit(Shr(position,reg,reg,tmp))
					ELSIF x.id = Global.Rot THEN Emit(Ror(position,reg,reg,tmp))
					ELSIF x.id = Global.Ror THEN Emit(Rol(position,reg,reg,tmp))
					ELSIF x.id = Global.Asr THEN Emit(Shl(position,reg,reg,tmp))
					END;
					ReleaseIntermediateOperand(tmp);
					BrL(end);
					SetLabel(exit);
					ReuseCopy(tmp,s1.op);
					Convert(tmp,s1.op.type);
					IF x.id = Global.Ash THEN Emit(Shl(position,reg,reg,tmp))
					ELSIF x.id = Global.Lsh THEN Emit(Shl(position,reg,reg,tmp))
					ELSIF x.id = Global.Rot THEN Emit(Rol(position,reg,reg,tmp))
					ELSIF x.id = Global.Ror THEN Emit(Ror(position,reg,reg,tmp))
					ELSIF x.id = Global.Asr THEN Emit(Shr(position,reg,reg,tmp))
					END;
					ReleaseIntermediateOperand(tmp);
					SetLabel(end);
					ReleaseOperand(s0); ReleaseOperand(s1);
				END;
				InitOperand(result,ModeValue);
				IF convert THEN
					itype := reg.type;
					IntermediateCode.InitType(itype,IntermediateCode.SignedInteger,reg.type.sizeInBits);
					Convert(reg,itype);
				END;
				result.op := reg;
			(* ---- CAP ----- *)
			|Global.Cap:
				Evaluate(p0,result);
				ReuseCopy(reg,result.op);
				ReleaseIntermediateOperand(result.op);
				ignore := NewLabel();
				BrltL(ignore, reg,IntermediateCode.Immediate(IntermediateCode.GetType(system,system.characterType),ORD("a")));
				BrltL(ignore,IntermediateCode.Immediate(IntermediateCode.GetType(system,system.characterType),ORD("z")),reg);
				Emit(And(position,reg,reg,IntermediateCode.Immediate(IntermediateCode.GetType(system,system.characterType),5FH)));
				SetLabel(ignore);
				result.op := reg;
			(* ---- CHR ----- *)
			|Global.Chr, Global.Chr32:
				Evaluate(p0,result);
				Convert(result.op,IntermediateCode.GetType(system,x.type));
			|Global.Entier, Global.EntierH:
				Evaluate(p0,result);
				Convert(result.op,IntermediateCode.GetType(system,x.type));
			(* ---- MIN and MAX ----- *)
			|Global.Max,Global.Min:
				Evaluate(p0,s0);
				Evaluate(p1,s1);
				Reuse2(res,s0.op,s1.op);
				else := NewLabel();
				IF x.id = Global.Max THEN BrltL(else,s0.op,s1.op);
				ELSE BrltL(else,s1.op,s0.op) END;
				Emit(Mov(position,res,s0.op));
				ReleaseOperand(s0);
				end := NewLabel();
				BrL(end);
				SetLabel(else);
				Emit(MovReplace(position,res,s1.op));
				SetLabel(end);
				ReleaseOperand(s1);
				InitOperand(result,ModeValue);
				result.op := res;
			(* ---- ODD ----- *)
			|Global.Odd:
				Evaluate(p0,result);
				Reuse1(res,result.op);
				Emit(And(position,res,result.op,IntermediateCode.Immediate(IntermediateCode.GetType(system,p0.type),1)));
				ReleaseIntermediateOperand(result.op);
				result.op := res;
				Convert(result.op,bool);
			(* ---- ORD ----- *)
			|Global.Ord, Global.Ord32:
				Evaluate(p0,result);
				Convert(result.op,IntermediateCode.GetType(system,x.type));
			(* ---- SHORT, LONG ----- *)
			|Global.Short, Global.Long:
				Evaluate(p0,result);
				IF x.type IS SyntaxTree.ComplexType THEN
					componentType := x.type(SyntaxTree.ComplexType).componentType;
					Convert(result.op, IntermediateCode.GetType(system, componentType));
					Convert(result.tag, IntermediateCode.GetType(system, componentType));
				ELSE
					Convert(result.op,IntermediateCode.GetType(system,x.type));
				END
			(* ---- HALT, SYSTEM.HALT----- *)
			|Global.Halt, Global.systemHalt:
				val := LONGINT (p0.resolved(SyntaxTree.IntegerValue).value); (* TODO: fix explicit integer truncation *)
				EmitTrap (position, val);
			(* ---- ASSERT ----- *)
			|Global.Assert:
				IF ~backend.noAsserts & (p0.resolved = NIL) THEN
					trueL := NewLabel();
					Condition(p0,trueL,TRUE);
					IF p1 = NIL THEN val := AssertTrap
					ELSE val := LONGINT(p1.resolved(SyntaxTree.IntegerValue).value); (* TODO: fix explicit integer truncation *)
					END;
					EmitTrap(position,val);
					SetLabel(trueL);
				END;

				(*
				Emit(TrapC(result.op,val);
				*)
			(* ---- INC, DEC----- *)
			|Global.Inc,Global.Dec:
				Designate(p0, result); adr := result.op;
				s0 := result;
				LoadValue(result,p0.type);
				(* EXPERIMENTAL *)
				IF (s0.availability >= 0) & (availableSymbols[s0.availability].inRegister) THEN
					availableSymbols[s0.availability].inMemory := FALSE;
				END;

				l := result;
				IF p1 = NIL THEN r.op := IntermediateCode.Immediate(IntermediateCode.GetType(system,p0.type),1);
				ELSE Evaluate(p1, r);
				END;
				IF x.id = Global.Inc THEN
					Emit(Add(position,l.op,l.op,r.op));
				ELSE
					Emit(Sub(position,l.op,l.op,r.op));
				END;
				ReleaseOperand(l); ReleaseOperand(r);
			(* ---- LEN ----- *)
			|Global.Len: (* dynamic length, static length done by checker  *)
				Designate(p0,operand);
				IF p1 = NIL THEN
					InitOperand(l,ModeValue);
					l.op := IntermediateCode.Immediate(sizeType,0);
				ELSE
					Evaluate(p1,l);
				END;
				IF p0.type.resolved IS SyntaxTree.ArrayType THEN
					IF (p0.type.resolved(SyntaxTree.ArrayType).form= SyntaxTree.SemiDynamic) THEN
						Dereference(operand, p0.type.resolved, FALSE);
					END;
					ArrayLen(p0.type.resolved(SyntaxTree.ArrayType),operand,l.op, result);
					ReleaseOperand(operand); ReleaseOperand(l);
				ELSIF p0.type.resolved IS SyntaxTree.MathArrayType THEN
					ASSERT(p1 # NIL);
					IF p0.type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
						Dereference(operand,p0.type.resolved,FALSE);
					END;
					GetMathArrayLength(p0.type.resolved(SyntaxTree.MathArrayType),operand, l.op, TRUE, result);
					ReleaseOperand(operand); ReleaseOperand(l);
				ELSE HALT(100);
				END;
				Convert(result.op,IntermediateCode.GetType(system, x.type));

			(* ---- FIRST ---- *)
			|Global.First:
				IF p0 IS SyntaxTree.RangeExpression THEN (* optimization, could also work with designate *)
					Evaluate(p0(SyntaxTree.RangeExpression).first, result)
				ELSE
					Designate(p0, result)
				END

			(* ---- LAST ---- *)
			|Global.Last:
				IF p0 IS SyntaxTree.RangeExpression THEN (* optimization, could also work with designate *)
					Evaluate(p0(SyntaxTree.RangeExpression).last, result)
				ELSE
					Designate(p0, result);
					(* make sure result.op is a register *)
					tmp := result.op;
					ReuseCopy(result.op, result.op);
					ReleaseIntermediateOperand(tmp);
					(* add offset to result.op *)
					IntermediateCode.AddOffset(result.op, ToMemoryUnits(system, system.SizeOf(system.longintType)))
				END

			(* ---- STEP ---- *)
			|Global.Step:
				IF p0 IS SyntaxTree.RangeExpression THEN (* optimization, could also work with designate *)
					Evaluate(p0(SyntaxTree.RangeExpression).step, result)
				ELSE
					Designate(p0, result);

					(* make sure result.op is a register *)
					tmp := result.op;
					ReuseCopy(result.op, result.op);
					ReleaseIntermediateOperand(tmp);

					(* add offset to result.op *)
					IntermediateCode.AddOffset(result.op, 2 * ToMemoryUnits(system, system.SizeOf(system.longintType)))
				END

			(* ---- RE ---- *)
			|Global.Re:
				IF p0.type.resolved IS SyntaxTree.ComplexType THEN
					Designate(p0, result)
				ELSE
					Evaluate(p0, result)
				END
			(* ---- IM ---- *)
			|Global.Im:
				ASSERT(p0.type.resolved IS SyntaxTree.ComplexType);
				componentType := p0.type.resolved(SyntaxTree.ComplexType).componentType;

				Designate(p0, result);

				(* make sure result.op is a register *)
				tmp := result.op;
				ReuseCopy(result.op, result.op);
				ReleaseIntermediateOperand(tmp);
				(* add offset to result.op *)
				IntermediateCode.AddOffset(result.op, ToMemoryUnits(system, system.SizeOf(componentType)));

			(* ---- ABS ----- *)
			|Global.Abs:
				Evaluate(p0,operand);
				type := p0.type.resolved;
				InitOperand(result,ModeValue);
				Reuse1a(result.op,operand.op,dest);
				Emit(Abs(position,result.op,operand.op));
				ReleaseOperand(operand);
			(* ---- WAIT ----- *)
			|Global.Wait:
				Evaluate(p0,operand);
				Emit(Push(position,operand.op));
				ReleaseOperand(operand);
				CallThis(position,"Activities","Wait", 1);
			(* ---- NEW ----- *)
			|Global.New:
				Allocate(x, result);
			(* ---- ADDRESSOF----- *)
			|Global.systemAdr:
				Designate(p0,s0);
				s0.mode := ModeValue;
				IF (t0 IS SyntaxTree.MathArrayType) & (t0(SyntaxTree.MathArrayType).form = SyntaxTree.Open) THEN
					ReleaseIntermediateOperand(s0.op);
					s0.op := s0.tag;
					IntermediateCode.InitOperand(s0.tag);
				END;
				Convert(s0.op,IntermediateCode.GetType(system,x.type));
				result := s0;
			(* ---- BIT ----- *)
			|Global.systemBit:
				Evaluate(p0,s0);
				ToMemory(s0.op,addressType,0);
				ReuseCopy(res,s0.op);
				ReleaseOperand(s0);
				Evaluate(p1,s1);
				Emit(Ror(position,res,res,s1.op));
				ReleaseOperand(s1);
				Emit(And(position,res,res,IntermediateCode.Immediate(IntermediateCode.GetType(system,p0.type),1)));
				Convert(res,IntermediateCode.GetType(system,system.booleanType));
				InitOperand(result,ModeValue);
				result.op := res;
			(* --- MSK ----*)
			|Global.systemMsk:
				Evaluate(p0,s0);
				Evaluate(p1,s1);
				ReuseCopy(res,s0.op);
				ReleaseOperand(s0);
				Emit(And(position,res,res,s1.op));
				ReleaseOperand(s1);
				InitOperand(result,ModeValue);
				result.op := res;
			(* ---- SYSTEM.GET8|16|32|64 ----- *)
			|Global.systemGet8, Global.systemGet16, Global.systemGet32, Global.systemGet64:
				Evaluate(p0,s0);
				MakeMemory(res,s0.op,IntermediateCode.GetType(system,x.type),0);
				ReleaseOperand(s0);
				InitOperand(result,ModeValue);
				result.op := res;
			(* ---- SYSTEM.GetStackPointer ----- *)
			|Global.systemGetStackPointer:
				InitOperand(result,ModeValue);
				result.op := sp;
			(* ---- SYSTEM.GetFramePointer ----- *)
			|Global.systemGetFramePointer:
				InitOperand(result,ModeValue);
				result.op := fp;
			(* ---- SYSTEM.GetActivity ----- *)
			|Global.systemGetActivity:
				ASSERT(backend.cooperative);
				InitOperand(result,ModeValue);
				result.op := ap;
			(* ---- SYSTEM.SetStackPointer ----- *)
			|Global.systemSetStackPointer:
				Evaluate(p0,s0); (*  *)
				Emit(Mov(position,sp,s0.op));
				ReleaseOperand(s0);
			(* ---- SYSTEM.SetFramePointer ----- *)
			|Global.systemSetFramePointer:
				Evaluate(p0,s0); (*  *)
				Emit(Mov(position,fp,s0.op));
				ReleaseOperand(s0);
			(* ---- SYSTEM.Activity ----- *)
			|Global.systemSetActivity:
				ASSERT(backend.cooperative);
				Evaluate(p0,s0); (*  *)
				Emit(Mov(position,ap,s0.op));
				ReleaseOperand(s0);
			(* ---- SYSTEM.VAL ----- *)
			|Global.systemVal:
				Designate(p1, result);
				s1 := result;
				type :=p0(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType;
				IF s1.mode = ModeReference THEN
					(* nothing to  be done if not record type, just take over new type *)
					IF (type IS SyntaxTree.RecordType) THEN
						ReleaseIntermediateOperand(s1.tag);
						s1.tag := TypeDescriptorAdr(type);
						UseIntermediateOperand(s1.tag);
					END;
					result := s1;
				ELSE (* copy over result to different type, may not use convert *)
					itype := IntermediateCode.GetType(system,type);
					IF itype.sizeInBits = s1.op.type.sizeInBits THEN
						IntermediateCode.InitRegister(s0.op,itype,IntermediateCode.GeneralPurposeRegister,AcquireRegister(itype,IntermediateCode.GeneralPurposeRegister));
						Emit(Mov(position,s0.op,s1.op));
						ReleaseOperand(s1);
						InitOperand(result,ModeValue);
						result.op := s0.op;
					ELSE (* different size, must convert *)
						(*! this is not very clean, should we forbid conversions between operands with different sizes or should we implement a cutting move ??? *)
						Convert(s1.op, IntermediateCode.GetType(system,type));
						result := s1;
					END;
				END;
			(* ---- SYSTEM.GET ----- *)
			|Global.systemGet:
				Evaluate(p0,s0); (* adr *)
				Designate(p1,s1); (* variable *)
				ToMemory(s0.op,IntermediateCode.GetType(system,p1.type),0);
				ToMemory(s1.op,IntermediateCode.GetType(system,p1.type),0);
				Emit(Mov(position,s1.op,s0.op));
				ReleaseOperand(s1);
				ReleaseOperand(s0);
			(* ---- SYSTEM.PUT 8|16|32|64 ----- *)
			|Global.systemPut, Global.systemPut64, Global.systemPut32, Global.systemPut16, Global.systemPut8:
				Evaluate(p0,s0); (*  *)
				Evaluate(p1,s1); (* variable *)
				IF p1.type.resolved IS SyntaxTree.ComplexType THEN
					componentType := p1.type.resolved(SyntaxTree.ComplexType).componentType;

					(* real part *)
					MakeMemory(res, s0.op, IntermediateCode.GetType(system, componentType), 0);
					Emit(Mov(position,res, s1.op));
					ReleaseIntermediateOperand(res);

					(* imaginary part *)
					MakeMemory(res, s0.op, IntermediateCode.GetType(system, componentType), ToMemoryUnits(system, system.SizeOf(componentType)));
					Emit(Mov(position,res, s1.tag));
					ReleaseIntermediateOperand(res);

					ReleaseOperand(s1);
					ReleaseOperand(s0);
				ELSE
					MakeMemory(res,s0.op,IntermediateCode.GetType(system,p1.type),0);
					ReleaseOperand(s0);
					Emit(Mov(position,res,s1.op));
					ReleaseIntermediateOperand(res);
					ReleaseOperand(s1);
				END;
			(* ---- SYSTEM.MOVE ----- *)
			|Global.systemMove:
				Evaluate(p0,s0);
				Evaluate(p1,s1);
				Evaluate(p2,s2);
				Emit(Copy(position,s1.op,s0.op,s2.op));
				ReleaseOperand(s0); ReleaseOperand(s1); ReleaseOperand(s2);
			(* ---- SYSTEM.NEW ----- *)
			|Global.systemNew:
				Designate(p0,s0);
				Emit(Push(position,s0.op));
				ReleaseOperand(s0);
				Evaluate(p1,s1);
				Emit(Push(position,s1.op));
				ReleaseOperand(s1);
				(* push realtime flag: false by default *)
				Emit(Push(position,false));
				CallThis(position,"Heaps","NewSys",3);
			(* ---- SYSTEM.CALL ----- *)
			|Global.systemRef:
				Basic.ToSegmentedName(p0(SyntaxTree.StringValue).value^, segmentedName);
				callsection := NewSection(module.allSections,  Sections.CodeSection, segmentedName, NIL,commentPrintout # NIL);
				s0.mode := ModeValue;
				IntermediateCode.InitAddress(s0.op, addressType, callsection.name, 0, 0);
				result := s0
			(* ---- INCR ----- *)
			|Global.Incr:
				Designate(p0,operand);
				IF p0.type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
					Dereference(operand,p0.type.resolved,FALSE);
				END;
				ASSERT(p1 # NIL);
				Evaluate(p1,l);
				GetMathArrayIncrement(p0.type.resolved(SyntaxTree.MathArrayType),operand, l.op,TRUE, result);

				ReleaseOperand(operand); ReleaseOperand(l);
				Convert(result.op,IntermediateCode.GetType(system, x.type));
			(* ---- SUM ----- *)
			|Global.Sum: HALT(200);
			(* ---- ALL ----- *)
			|Global.All: HALT(200);
			(* ---- CAS ----- *)
			|Global.Cas:
				needsTrace := backend.cooperative & p0.NeedsTrace();
				IF needsTrace THEN ModifyAssignments(true) END;
				Designate(p0,s0);
				Evaluate(p1,s1);
				Evaluate(p2,s2);
				IF needsTrace THEN
					Emit(Push(position, s0.op));
					Emit(Push(position, s1.op));
					Emit(Push(position, s2.op));
					CallThis(position,"GarbageCollector","CompareAndSwap",3);
				ELSE
					Emit(Cas(position,s0.op,s1.op,s2.op));
				END;
				ReleaseOperand(s0); ReleaseOperand(s1); ReleaseOperand(s2);
				IF needsTrace THEN ModifyAssignments(false) END;
				res := NewRegisterOperand(IntermediateCode.GetType(system, p0.type));
				Emit(Result(position, res));
				result.op := res;
				result.mode := ModeValue;
				(*
				IF conditional THEN
					BreqL(trueLabel,IntermediateCode.Immediate(res.type,1),res);
					BrL(falseLabel);
					ReleaseIntermediateOperand(res);
				END;
				*)
			(* ---- DIM ----- *)
			|Global.Dim:
				Designate(p0,s0);
				IF p0.type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
					Dereference(s0,p0.type.resolved,FALSE);
				END;
				MathArrayDim(p0.type.resolved(SyntaxTree.MathArrayType),s0.tag,result);
				ReleaseOperand(s0);
			(* ---- RESHAPE ----- *)
			|Global.Reshape:
				IF GetRuntimeProcedure("FoxArrayBase","Reshape",procedure,TRUE) THEN
					left := SyntaxTree.NewSymbolDesignator(Basic.invalidPosition,NIL,NIL, procedure);
					left.SetType(procedure.type);
					call := SyntaxTree.NewProcedureCallDesignator(position,NIL,left(SyntaxTree.Designator),x.parameters);
					DesignateProcedureCallDesignator(call(SyntaxTree.ProcedureCallDesignator), result);
				END;
			(* ---- SYSTEM.TYPECODE ----- *)
			|Global.systemTypeCode:
				type := p0(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType;
				IF type.resolved IS SyntaxTree.PointerType THEN
					type := type.resolved(SyntaxTree.PointerType).pointerBase;
				END;
				result.op := TypeDescriptorAdr(type);
				Convert(result.op, IntermediateCode.GetType(system,x.type));
				result.mode := ModeValue;
			(* ---- SYSTEM.TRACE ----- *)
			|Global.systemTrace:
				SystemTrace(x.parameters, x.position);
			(* ----- CONNECT ------*)
			|Global.Connect:
				IF backend.cellsAreObjects THEN
					PushPort(p0);
					PushPort(p1);
					IF p2 # NIL THEN
						Evaluate(p2, s2);
						Emit(Push(p2.position, s2.op));
						ReleaseOperand(s2);
					ELSE
						Emit(Push(Basic.invalidPosition, IntermediateCode.Immediate(int32, -1)));
					END;
					CallThis(position,"ActiveCellsRuntime","Connect",3);
				ELSE
					Warning(x.position, "cannot run on final hardware");
				END;
			(* ----- DELEGATE ------*)
			|Global.Delegate:
				IF backend.cellsAreObjects THEN
					PushPort(p0);
					PushPort(p1);
					CallThis(position,"ActiveCellsRuntime","Delegate",2);
				ELSE
					Warning(x.position, "cannot run on final hardware");
				END;

			(* ----- SEND ------*)
			|Global.Send:
				Evaluate(p0,s0);
				Evaluate(p1,s1);
				size := ToMemoryUnits(system,system.SizeOf(p1.type));
				Emit(Push(position,s0.op));
				Emit(Push(position,s1.op));
				(*
				Emit(Push(position,IntermediateCode.Immediate(addressType,size)));
				*)
				IF ~backend.cellsAreObjects THEN
					IF size # 1 THEN Error(p1.position,"send not implemented for complex data types") END;
				END;
				ReleaseOperand(s0);
				ReleaseOperand(s1);
				IF backend.cellsAreObjects THEN
					CallThis(position,"ActiveCellsRuntime","Send",2);
				ELSE

					CallThis(position,ChannelModuleName,"Send",2);
				END;
			(* ----- RECEIVE ------*)
			|Global.Receive:
				Evaluate(p0,s0);
				Emit(Push(position,s0.op));
				Designate(p1,s1);
				size := ToMemoryUnits(system,system.SizeOf(p1.type));
				Emit(Push(position,s1.op));
				IF p2 # NIL THEN
					Designate(p2,s2);
					Emit(Push(position,s2.op));
				END;

				(*
				Emit(Push(position,IntermediateCode.Immediate(addressType,size)));
				*)
				IF ~backend.cellsAreObjects THEN
					IF size # 1 THEN Error(p1.position,"receive not implemented for complex data types") END;
				END;
				ReleaseOperand(s0);
				ReleaseOperand(s1);
				ReleaseOperand(s2);
				IF backend.cellsAreObjects THEN
					IF p2 = NIL THEN
						CallThis(position,"ActiveCellsRuntime","Receive",2)
					ELSE
						CallThis(position,"ActiveCellsRuntime","ReceiveNonBlockingVar",3)
					END;
				ELSE
					IF p2 = NIL THEN
						CallThis(position,ChannelModuleName,"Receive",2)
					ELSE
						CallThis(position,ChannelModuleName,"ReceiveNonBlockingVar",3)
					END;
				END;

			| Global.systemSpecial:
				customBuiltin := x.left(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.CustomBuiltin);
				ASSERT(customBuiltin.type IS SyntaxTree.ProcedureType);
				procedureType := customBuiltin.type(SyntaxTree.ProcedureType);

				(* determine if parameters are of the VAR kind *)
				ASSERT(x.parameters.Length() <= 3);
				formalParameter := procedureType.firstParameter;
				FOR i := 0 TO x.parameters.Length() - 1 DO
					isVarPar[i] := formalParameter.kind = SyntaxTree.VarParameter;
					formalParameter := formalParameter.nextParameter
				END;

				IF p0 # NIL THEN IF isVarPar[0] THEN Designate(p0, s0) ELSE Evaluate(p0,s0) END ELSE InitOperand(s0, ModeValue) END;
				IF p1 # NIL THEN IF isVarPar[1] THEN Designate(p1, s1) ELSE Evaluate(p1,s1) END ELSE InitOperand(s1, ModeValue) END;
				IF p2 # NIL THEN IF isVarPar[2] THEN Designate(p2, s2) ELSE Evaluate(p2,s2) END ELSE InitOperand(s2, ModeValue) END;
				Emit(SpecialInstruction(x.position, customBuiltin.subType,s0.op, s1.op, s2.op));
				ReleaseOperand(s0); ReleaseOperand(s1); ReleaseOperand(s2);
				IF procedureType.returnType # NIL THEN
					res := NewRegisterOperand(IntermediateCode.GetType(system, procedureType.returnType));
					Emit(Result(position, res));
					(*InitOperand(result,ModeValue);
					result.op := res;
					*)

					InitOperand(result,ModeValue); result.op := res;
				END

			ELSE (* function not yet implemented *)
				Error(position,"not yet implemented");
			END;
			destination := dest;
			IF Trace THEN TraceExit("DesignateBuiltinCallDesignator") END;
		END DesignateBuiltinCallDesignator;

		PROCEDURE EvaluateBuiltinCallDesignator(x: SyntaxTree.BuiltinCallDesignator; VAR result: Operand);
		VAR
			p0,p1,p2: SyntaxTree.Expression; len: LONGINT; l: Operand; res,reg: IntermediateCode.Operand; type, componentType: SyntaxTree.Type;
			s0,s1,s2: Operand; hint: HUGEINT;
			i: LONGINT; formalParameter: SyntaxTree.Parameter;
			tmp:IntermediateCode.Operand;
			t0,t1,t2: SyntaxTree.Type; ignore: Label;
			exit,else,end: Label; procedureType: SyntaxTree.ProcedureType;
			operand: Operand;
			dest: IntermediateCode.Operand;
			itype: IntermediateCode.Type;
			convert: BOOLEAN;
			customBuiltin: SyntaxTree.CustomBuiltin;
			isVarPar: ARRAY 3 OF BOOLEAN;
			callsection: Sections.Section;
			segmentedName: Basic.SegmentedName;
			needsTrace: BOOLEAN;
		BEGIN
			IF Trace THEN TraceEnter("EvaluateBuiltinCallDesignator") END;

			dest := destination; destination := emptyOperand;
			p0 := NIL; p1 := NIL; p2 := NIL; len := x.parameters.Length();
			IF len > 0 THEN p0 := x.parameters.GetExpression(0); t0 := p0.type.resolved END;
			IF len > 1 THEN p1 := x.parameters.GetExpression(1); t1 := p1.type.resolved END;
			IF len > 2 THEN p2 := x.parameters.GetExpression(2); t2 := p2.type.resolved END;

			CASE x.id OF
			(* ---- ASH, LSH, ROT ----- *)
			|Global.Ash, Global.Asr, Global.Lsh, Global.Rot, Global.Ror:
				Evaluate(p0, s0);
				IF (x.id = Global.Lsh) OR (x.id = Global.Rot) OR (x.id = Global.Ror)THEN
					(* make unsigned arguments in order to produced a logical shift *)
					IF s0.op.type.form = IntermediateCode.SignedInteger THEN
						convert:= TRUE;
						itype := s0.op.type;
						IntermediateCode.InitType(itype,IntermediateCode.UnsignedInteger,s0.op.type.sizeInBits);
						Convert(s0.op,itype);
					ELSE
						convert := FALSE;
					END;
				END;
				Evaluate(p1,s1);
				IF IsIntegerConstant(p1,hint) THEN
					ReuseCopy(reg,s0.op);
					IF hint  > 0 THEN
						IntermediateCode.InitImmediate(s1.op,s1.op.type,hint);
						IF x.id = Global.Ash THEN Emit(Shl(position,reg,s0.op,s1.op))
						ELSIF x.id = Global.Lsh THEN Emit(Shl(position,reg,s0.op,s1.op))
						ELSIF x.id = Global.Rot THEN Emit(Rol(position,reg,s0.op,s1.op))
						ELSIF x.id = Global.Ror THEN Emit(Ror(position,reg,s0.op,s1.op))
						ELSIF x.id = Global.Asr THEN Emit(Shr(position,reg,s0.op,s1.op))
						END;
					ELSIF hint < 0 THEN
						IntermediateCode.InitImmediate(s1.op,s1.op.type,-hint);
						IF x.id = Global.Ash THEN Emit(Shr(position,reg,s0.op,s1.op));
						ELSIF x.id = Global.Lsh THEN Emit(Shr(position,reg,s0.op,s1.op));
						ELSIF x.id = Global.Rot THEN Emit(Ror(position,reg,s0.op,s1.op));
						ELSIF x.id = Global.Ror THEN Emit(Rol(position,reg,s0.op,s1.op))
						ELSIF x.id = Global.Asr THEN Emit(Shl(position,reg,s0.op,s1.op))
						END;
					END;
					ReleaseOperand(s0); ReleaseOperand(s1);
				ELSE
					exit := NewLabel();
					end := NewLabel();
					ReuseCopy(reg,s0.op);
					BrgeL(exit,s1.op,IntermediateCode.Immediate(IntermediateCode.GetType(system,p1.type),0));
					Reuse1(tmp,s1.op);
					Emit(Neg(position,tmp,s1.op));
					Convert(tmp,s1.op.type);
					IF x.id = Global.Ash THEN Emit(Shr(position,reg,reg,tmp))
					ELSIF x.id = Global.Lsh THEN Emit(Shr(position,reg,reg,tmp))
					ELSIF x.id = Global.Rot THEN Emit(Ror(position,reg,reg,tmp))
					ELSIF x.id = Global.Ror THEN Emit(Rol(position,reg,reg,tmp))
					ELSIF x.id = Global.Asr THEN Emit(Shl(position,reg,reg,tmp))
					END;
					ReleaseIntermediateOperand(tmp);
					BrL(end);
					SetLabel(exit);
					ReuseCopy(tmp,s1.op);
					Convert(tmp,s1.op.type);
					IF x.id = Global.Ash THEN Emit(Shl(position,reg,reg,tmp))
					ELSIF x.id = Global.Lsh THEN Emit(Shl(position,reg,reg,tmp))
					ELSIF x.id = Global.Rot THEN Emit(Rol(position,reg,reg,tmp))
					ELSIF x.id = Global.Ror THEN Emit(Ror(position,reg,reg,tmp))
					ELSIF x.id = Global.Asr THEN Emit(Shr(position,reg,reg,tmp))
					END;
					ReleaseIntermediateOperand(tmp);
					SetLabel(end);
					ReleaseOperand(s0); ReleaseOperand(s1);
				END;
				InitOperand(result,ModeValue);
				IF convert THEN
					itype := reg.type;
					IntermediateCode.InitType(itype,IntermediateCode.SignedInteger,reg.type.sizeInBits);
					Convert(reg,itype);
				END;
				result.op := reg;
			(* ---- CAP ----- *)
			|Global.Cap:
				Evaluate(p0,result);
				ReuseCopy(reg,result.op);
				ReleaseIntermediateOperand(result.op);
				ignore := NewLabel();
				BrltL(ignore, reg,IntermediateCode.Immediate(IntermediateCode.GetType(system,system.characterType),ORD("a")));
				BrltL(ignore,IntermediateCode.Immediate(IntermediateCode.GetType(system,system.characterType),ORD("z")),reg);
				Emit(And(position,reg,reg,IntermediateCode.Immediate(IntermediateCode.GetType(system,system.characterType),5FH)));
				SetLabel(ignore);
				result.op := reg;
			(* ---- CHR ----- *)
			|Global.Chr, Global.Chr32:
				Evaluate(p0, result);
				Convert(result.op,IntermediateCode.GetType(system,x.type));
			|Global.Entier, Global.EntierH:
				Evaluate(p0, result);
				Convert(result.op,IntermediateCode.GetType(system,x.type));
			(* ---- MIN and MAX ----- *)
			|Global.Max,Global.Min:
				Evaluate(p0, s0);
				Evaluate(p1, s1);
				Reuse2(res,s0.op,s1.op);
				else := NewLabel();
				IF x.id = Global.Max THEN BrltL(else,s0.op,s1.op);
				ELSE BrltL(else,s1.op,s0.op) END;
				Emit(Mov(position,res,s0.op));
				ReleaseOperand(s0);
				end := NewLabel();
				BrL(end);
				SetLabel(else);
				Emit(MovReplace(position,res,s1.op));
				SetLabel(end);
				ReleaseOperand(s1);
				InitOperand(result,ModeValue);
				result.op := res;
			(* ---- ODD ----- *)
			|Global.Odd:
				Evaluate(p0, result);
				Reuse1(res,result.op);
				Emit(And(position,res,result.op,IntermediateCode.Immediate(IntermediateCode.GetType(system,p0.type),1)));
				ReleaseIntermediateOperand(result.op);
				result.op := res;
				Convert(result.op,bool);
			(* ---- ORD ----- *)
			|Global.Ord, Global.Ord32:
				Evaluate(p0, result);
				Convert(result.op,IntermediateCode.GetType(system,x.type));
			(* ---- SHORT, LONG ----- *)
			|Global.Short, Global.Long:
				Evaluate(p0, result);
				IF x.type IS SyntaxTree.ComplexType THEN
					componentType := x.type(SyntaxTree.ComplexType).componentType;
					Convert(result.op, IntermediateCode.GetType(system, componentType));
					Convert(result.tag, IntermediateCode.GetType(system, componentType));
				ELSE
					Convert(result.op,IntermediateCode.GetType(system,x.type));
				END
			(* ---- LEN ----- *)
			|Global.Len: (* dynamic length, static length done by checker  *)
				Designate(p0,operand);
				IF p1 = NIL THEN
					InitOperand(l,ModeValue);
					l.op := IntermediateCode.Immediate(sizeType,0);
				ELSE
					Evaluate(p1,l);
				END;
				IF p0.type.resolved IS SyntaxTree.ArrayType THEN
					IF (p0.type.resolved(SyntaxTree.ArrayType).form= SyntaxTree.SemiDynamic) THEN
						Dereference(operand, p0.type.resolved, FALSE);
					END;
					ArrayLen(p0.type.resolved(SyntaxTree.ArrayType),operand,l.op, result);
					ReleaseOperand(operand); ReleaseOperand(l);
				ELSIF p0.type.resolved IS SyntaxTree.MathArrayType THEN
					ASSERT(p1 # NIL);
					IF p0.type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
						Dereference(operand,p0.type.resolved,FALSE);
					END;
					GetMathArrayLength(p0.type.resolved(SyntaxTree.MathArrayType),operand, l.op, TRUE, result);
					ReleaseOperand(operand); ReleaseOperand(l);
				ELSE HALT(100);
				END;
				Convert(result.op,IntermediateCode.GetType(system, x.type));
			(* ---- FIRST ---- *)
			|Global.First:
				IF p0 IS SyntaxTree.RangeExpression THEN (* optimization, could also work with designate *)
					Evaluate(p0(SyntaxTree.RangeExpression).first, result)
				ELSE
					DesignateAndLoad(x, result);
				END

			(* ---- LAST ---- *)
			|Global.Last:
				IF p0 IS SyntaxTree.RangeExpression THEN (* optimization, could also work with designate *)
					Evaluate(p0(SyntaxTree.RangeExpression).last, result)
				ELSE
					DesignateAndLoad(x, result);
				END

			(* ---- STEP ---- *)
			|Global.Step:
				IF p0 IS SyntaxTree.RangeExpression THEN (* optimization, could also work with designate *)
					Evaluate(p0(SyntaxTree.RangeExpression).step, result)
				ELSE
					DesignateAndLoad(x, result);
				END

			(* ---- RE ---- *)
			|Global.Re:
				IF p0.type.resolved IS SyntaxTree.ComplexType THEN
					DesignateAndLoad(x,result);
				ELSE
					Evaluate(p0, result)
				END
			(* ---- IM ---- *)
			|Global.Im:
				DesignateAndLoad(x, result);
			(* ---- ABS ----- *)
			|Global.Abs:
				Evaluate(p0,operand);
				type := p0.type.resolved;
				InitOperand(result,ModeValue);
				Reuse1a(result.op,operand.op,dest);
				Emit(Abs(position,result.op,operand.op));
				ReleaseOperand(operand);
			(* ----- NEW ----- *)
			|Global.New:
				Allocate(x, result);
				LoadValue(result, x.type.resolved);
			(* ---- ADDRESSOF----- *)
			|Global.systemAdr:
				Designate(p0,s0);
				s0.mode := ModeValue;
				IF (t0 IS SyntaxTree.MathArrayType) & (t0(SyntaxTree.MathArrayType).form = SyntaxTree.Open) THEN
					ReleaseIntermediateOperand(s0.op);
					s0.op := s0.tag;
					IntermediateCode.InitOperand(s0.tag);
				END;
				Convert(s0.op,IntermediateCode.GetType(system,x.type));
				result := s0;
			(* ---- BIT ----- *)
			|Global.systemBit:
				Evaluate(p0,s0);
				ToMemory(s0.op,addressType,0);
				ReuseCopy(res,s0.op);
				ReleaseOperand(s0);
				Evaluate(p1, s1);
				Emit(Ror(position,res,res,s1.op));
				ReleaseOperand(s1);
				Emit(And(position,res,res,IntermediateCode.Immediate(IntermediateCode.GetType(system,p0.type),1)));
				Convert(res,IntermediateCode.GetType(system,system.booleanType));
				InitOperand(result,ModeValue);
				result.op := res;
			(* --- MSK ----*)
			|Global.systemMsk:
				Evaluate(p0, s0);
				Evaluate(p1, s1);
				ReuseCopy(res,s0.op);
				ReleaseOperand(s0);
				Emit(And(position,res,res,s1.op));
				ReleaseOperand(s1);
				InitOperand(result,ModeValue);
				result.op := res;
			(* ---- SYSTEM.GET8|16|32|64 ----- *)
			|Global.systemGet8, Global.systemGet16, Global.systemGet32, Global.systemGet64:
				Evaluate(p0, s0);
				MakeMemory(res,s0.op,IntermediateCode.GetType(system,x.type),0);
				ReleaseOperand(s0);
				InitOperand(result,ModeValue);
				result.op := res;
			(* ---- SYSTEM.GetStackPointer ----- *)
			|Global.systemGetStackPointer:
				InitOperand(result,ModeValue);
				result.op := sp;
			(* ---- SYSTEM.GetFramePointer ----- *)
			|Global.systemGetFramePointer:
				InitOperand(result,ModeValue);
				result.op := fp;
			(* ---- SYSTEM.GetActivity ----- *)
			|Global.systemGetActivity:
				ASSERT(backend.cooperative);
				InitOperand(result,ModeValue);
				result.op := ap;
			(* ---- SYSTEM.VAL ----- *)
			|Global.systemVal:
				(*! MUST RESOLVE THIS *)
				IF SemanticChecker.HasAddress(p1)  THEN
					DesignateAndLoad(x, result);
				ELSE
					Evaluate(p1, s1);
					type :=p0(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType;
					ASSERT(s1.mode # ModeReference);
					(* copy over result to different type, may not use convert *)
					itype := IntermediateCode.GetType(system,type);
					IF itype.sizeInBits * itype.length = s1.op.type.sizeInBits * s1.op.type.length THEN
						IntermediateCode.InitRegister(s0.op,itype,IntermediateCode.GeneralPurposeRegister,AcquireRegister(itype,IntermediateCode.GeneralPurposeRegister));
						Emit(Mov(position,s0.op,s1.op));
						ReleaseOperand(s1);
						InitOperand(result,ModeValue);
						result.op := s0.op;
					ELSE (* different size, must convert *)
						(*! this is not very clean, should we forbid conversions between operands with different sizes or should we implement a cutting move ??? *)
						Convert(s1.op, IntermediateCode.GetType(system,type));
						result := s1;
					END;
				END;
			(* ---- SYSTEM.CALL ----- *)
			|Global.systemRef:
				Basic.ToSegmentedName(p0(SyntaxTree.StringValue).value^, segmentedName);
				callsection := NewSection(module.allSections,  Sections.CodeSection, segmentedName, NIL,commentPrintout # NIL);
				s0.mode := ModeValue;
				IntermediateCode.InitAddress(s0.op, addressType, callsection.name, 0, 0);
				result := s0
			(* ---- INCR ----- *)
			|Global.Incr:
				Designate(p0,operand);
				IF p0.type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
					Dereference(operand,p0.type.resolved,FALSE);
				END;
				ASSERT(p1 # NIL);
				Evaluate(p1,l);
				GetMathArrayIncrement(p0.type.resolved(SyntaxTree.MathArrayType),operand, l.op,TRUE, result);

				ReleaseOperand(operand); ReleaseOperand(l);
				Convert(result.op,IntermediateCode.GetType(system, x.type));
			(* ---- SUM ----- *)
			|Global.Sum: HALT(200);
			(* ---- ALL ----- *)
			|Global.All: HALT(200);
			(* ---- CAS ----- *)
			|Global.Cas:
				needsTrace := p0.NeedsTrace();
				IF needsTrace THEN ModifyAssignments(true) END;
				Designate(p0,s0);
				Evaluate(p1,s1);
				Evaluate(p2,s2);
				IF needsTrace THEN
					Emit(Push(position, s0.op));
					Emit(Push(position, s1.op));
					Emit(Push(position, s2.op));
					CallThis(position,"GarbageCollector","CompareAndSwap",3);
				ELSE
					Emit(Cas(position,s0.op,s1.op,s2.op));
				END;
				ReleaseOperand(s0); ReleaseOperand(s1); ReleaseOperand(s2);
				IF needsTrace THEN ModifyAssignments(false) END;
				res := NewRegisterOperand(IntermediateCode.GetType(system, p0.type));
				Emit(Result(position, res));
				result.op := res;
				result.mode := ModeValue;
				(*
				IF conditional THEN
					BreqL(trueLabel,IntermediateCode.Immediate(res.type,1),res);
					BrL(falseLabel);
					ReleaseIntermediateOperand(res);
				END;
				*)
			(* ---- DIM ----- *)
			|Global.Dim:
				Designate(p0,s0);
				IF p0.type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
					Dereference(s0,p0.type.resolved,FALSE);
				END;
				MathArrayDim(p0.type.resolved(SyntaxTree.MathArrayType),s0.tag,result);
				ReleaseOperand(s0);
			(* ---- SYSTEM.TYPECODE ----- *)
			|Global.systemTypeCode:
				type := p0(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType;
				IF type.resolved IS SyntaxTree.PointerType THEN
					type := type.resolved(SyntaxTree.PointerType).pointerBase;
				END;
				result.op := TypeDescriptorAdr(type);
				Convert(result.op, IntermediateCode.GetType(system,x.type));
				result.mode := ModeValue;
			| Global.systemSpecial:
				customBuiltin := x.left(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.CustomBuiltin);
				ASSERT(customBuiltin.type IS SyntaxTree.ProcedureType);
				procedureType := customBuiltin.type(SyntaxTree.ProcedureType);

				(* determine if parameters are of the VAR kind *)
				ASSERT(x.parameters.Length() <= 3);
				formalParameter := procedureType.firstParameter;
				FOR i := 0 TO x.parameters.Length() - 1 DO
					isVarPar[i] := formalParameter.kind = SyntaxTree.VarParameter;
					formalParameter := formalParameter.nextParameter
				END;

				IF p0 # NIL THEN IF isVarPar[0] THEN Designate(p0, s0) ELSE Evaluate(p0,s0) END ELSE InitOperand(s0, ModeValue) END;
				IF p1 # NIL THEN IF isVarPar[1] THEN Designate(p1, s1) ELSE Evaluate(p1,s1) END ELSE InitOperand(s1, ModeValue) END;
				IF p2 # NIL THEN IF isVarPar[2] THEN Designate(p2, s2) ELSE Evaluate(p2,s2) END ELSE InitOperand(s2, ModeValue) END;
				Emit(SpecialInstruction(x.position, customBuiltin.subType,s0.op, s1.op, s2.op));
				ReleaseOperand(s0); ReleaseOperand(s1); ReleaseOperand(s2);
				IF procedureType.returnType # NIL THEN
					res := NewRegisterOperand(IntermediateCode.GetType(system, procedureType.returnType));
					Emit(Result(position, res));
					(*InitOperand(result,ModeValue);
					result.op := res;
					*)

					InitOperand(result,ModeValue); result.op := res;
				END

			ELSE (* function not yet implemented *)
				Error(position,"not yet implemented");
			END;
			destination := dest;
			IF Trace THEN TraceExit("EvaluateBuiltinCallDesignator") END;
		END EvaluateBuiltinCallDesignator;

		PROCEDURE DesignateTypeGuardDesignator(x: SyntaxTree.TypeGuardDesignator; VAR result: Operand);
		VAR trueL: Label; recordType: SyntaxTree.RecordType; dest,tag,ptr,original,converted: IntermediateCode.Operand;
		BEGIN
			IF Trace THEN TraceEnter("DesignateTypeGuardDesignator") END;
			dest := destination; destination := emptyOperand;

			IF (x.type.resolved IS SyntaxTree.NumberType) OR (x.type.resolved IS SyntaxTree.AddressType) OR (x.type.resolved IS SyntaxTree.SizeType) THEN
				Evaluate(x.left, result);
				IF isUnchecked OR (x.left.type.resolved = x.type.resolved) THEN RETURN END; 
				trueL := NewLabel();
				TransferToRegister(result.op, result.op);
				ReuseCopy(original,result.op);
				Convert(result.op,IntermediateCode.GetType(system,x.type.resolved));
				ReuseCopy(converted,result.op);
				Convert(converted,original.type);
				BreqL(trueL,original,converted);
				ReleaseIntermediateOperand(original);
				ReleaseIntermediateOperand(converted);
				EmitTrap(position,TypeCheckTrap);
				SetLabel(trueL);
			ELSE
				Designate(x.left, result);
				IF isUnchecked OR (x.left.type.resolved = x.type.resolved) THEN RETURN END; 
				trueL := NewLabel();
				IF IsPointerToRecord(x.left.type,recordType) THEN
					IntermediateCode.InitRegister(tag,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
					Emit(Mov(position,tag, result.op));
					IF result.mode # ModeValue THEN
						ptr := tag;
						IntermediateCode.MakeMemory(ptr,addressType);
						Emit(Mov(position,tag, ptr));
					END;
					IF ~backend.cooperative THEN
						IntermediateCode.AddOffset(tag,ToMemoryUnits(system,-addressType.sizeInBits));
					END;
					IntermediateCode.MakeMemory(tag,addressType);
				ELSE
					tag := result.tag;
					UseIntermediateOperand(tag);
				END;
				TypeTest(tag,x.type,trueL,TRUE,FALSE);
				ReleaseIntermediateOperand(tag);
				EmitTrap(position,TypeCheckTrap);
				SetLabel(trueL);
			END;
			destination := dest;
			IF Trace THEN TraceExit("DesignateTypeGuardDesignator") END;
		END DesignateTypeGuardDesignator;

		PROCEDURE Dereference(VAR operand: Operand; type: SyntaxTree.Type; isUnsafe: BOOLEAN);
		VAR dereferenced: IntermediateCode.Operand; arrayDataOffset: LONGINT;

			PROCEDURE NilCheck(CONST op: IntermediateCode.Operand);
			VAR label: Label; pc: LONGINT;
			BEGIN
				IF backend.cooperative & ~isUnchecked THEN
					pc := section.pc;
					label := NewLabel();
					BrneL(label, operand.op, nil);
					EmitTrap(position, NilPointerTrap);
					SetLabel(label);
					INC(statCoopNilCheck, section.pc - pc);
				END;
			END NilCheck;

		BEGIN
			LoadValue(operand,system.addressType); (* in case operand is not a value yet *)
			ReuseCopy(dereferenced,operand.op);
			ReleaseOperand(operand);
			operand.mode := ModeReference;
			operand.op := dereferenced;
			operand.tag := dereferenced;
			UseIntermediateOperand(operand.tag);
			IF (type=NIL) OR (type IS SyntaxTree.RecordType)OR (type IS SyntaxTree.CellType) THEN
				IF isUnsafe & ((type = NIL) OR ~type(SyntaxTree.RecordType).isObject) THEN
					ReleaseIntermediateOperand(operand.tag);
					operand.tag := TypeDescriptorAdr(type);
				ELSE
					IF ~backend.cooperative THEN
						IntermediateCode.AddOffset(operand.tag,ToMemoryUnits(system,-addressType.sizeInBits));
					END;
					IntermediateCode.MakeMemory(operand.tag,addressType);
				END;
				NilCheck(operand.op);
			ELSIF type IS SyntaxTree.ArrayType THEN
				IF isUnsafe THEN
					NilCheck(operand.op);
					ReleaseIntermediateOperand(operand.tag);
					IF type(SyntaxTree.ArrayType).form = SyntaxTree.Static THEN
						IntermediateCode.InitImmediate(operand.tag,addressType,type(SyntaxTree.ArrayType).staticLength);
					ELSE
						operand.tag := emptyOperand;
					END;
				ELSE
					NilCheck(operand.op);
					IF backend.cooperative THEN
						arrayDataOffset := (BaseArrayTypeSize + DynamicDim(type)) * addressType.sizeInBits;
						IntermediateCode.AddOffset(operand.op,ToMemoryUnits(system,arrayDataOffset));
						IntermediateCode.AddOffset(operand.tag,ToMemoryUnits(system,BaseArrayTypeSize*system.addressSize));
					ELSE
						arrayDataOffset := DynamicDim(type) * addressType.sizeInBits + 3 * addressType.sizeInBits;
						INC(arrayDataOffset, (-arrayDataOffset) MOD ArrayAlignment);  (* round up to multiple of ArrayAlignment to ensure that first array element is aligned at 0 MOD ArrayAlignment *)
						IntermediateCode.AddOffset(operand.op,ToMemoryUnits(system,arrayDataOffset));
						IntermediateCode.AddOffset(operand.tag,ToMemoryUnits(system,ArrayDimTable*system.addressSize))
					END;
				END;
			ELSIF type IS SyntaxTree.MathArrayType THEN
				IntermediateCode.AddOffset(operand.op,ToMemoryUnits(system,MathAdrOffset*addressType.sizeInBits));
				IntermediateCode.MakeMemory(operand.op,addressType);
			ELSE HALT(100);
			END;
		END Dereference;

		PROCEDURE DesignateDereferenceDesignator(x: SyntaxTree.DereferenceDesignator; VAR result: Operand);
		VAR  type: SyntaxTree.Type; d: Operand; dest: IntermediateCode.Operand;prevIsUnchecked: BOOLEAN;
		BEGIN
			IF Trace THEN TraceEnter("DesignateDereferenceDesignator") END;
			dest := destination; destination := emptyOperand;
			Evaluate(x.left,d);
			type := x.type.resolved;
			prevIsUnchecked := isUnchecked;	
			IF (x.left # NIL) & (x.left IS SyntaxTree.SelfDesignator) THEN
				isUnchecked := TRUE; (* avoid NIL-pointer-check for SELF pointer *)
			END;
			Dereference(d,type,IsUnsafePointer(x.left.type));
			isUnchecked := prevIsUnchecked;
			result := d;
			IF backend.cooperative & (x.left.type.resolved IS SyntaxTree.PointerType) & ~x.left.type.resolved(SyntaxTree.PointerType).isPlain & ~x.left.type.resolved(SyntaxTree.PointerType).isUnsafe THEN
				IF (type IS SyntaxTree.RecordType) & ~type(SyntaxTree.RecordType).isObject THEN
					IntermediateCode.AddOffset(result.op,BaseRecordTypeSize * ToMemoryUnits(system,addressType.sizeInBits));
				END;
			END;
			destination := dest;
			IF Trace THEN TraceExit("DesignateDereferenceDesignator") END;
		END DesignateDereferenceDesignator;

		PROCEDURE DesignateSupercallDesignator(x: SyntaxTree.SupercallDesignator; VAR result: Operand);
		VAR procedure: SyntaxTree.Procedure; tag: IntermediateCode.Operand; dest: IntermediateCode.Operand;
		BEGIN
			IF Trace THEN TraceEnter("DesignateSupercallDesignator") END;
			dest := destination; destination := emptyOperand;
			Designate(x.left(SyntaxTree.SymbolDesignator).left,result);
			tag := result.op;
			(*ReleaseIntermediateOperand(result.tag); not necessary -- done in StaticCallOperand *)
			procedure := x.left(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Procedure);
			StaticCallOperand(procedure.super,result);

			ReleaseIntermediateOperand(result.tag);
			UseIntermediateOperand(tag); (* necessary ? *)

			result.tag := tag;
			destination := dest;
			IF Trace THEN TraceExit("DesignateSupercallDesignator") END;
		END DesignateSupercallDesignator;

		PROCEDURE DesignateSelfDesignator(x: SyntaxTree.SelfDesignator; VAR result: Operand);
		VAR basereg: IntermediateCode.Operand; scope: SyntaxTree.Scope; dest: IntermediateCode.Operand;
			moduleSection: IntermediateCode.Section; moduleOffset, parametersSize: LONGINT;
			name: Basic.SegmentedName;
			procedure: SyntaxTree.Procedure;
			procedureType: SyntaxTree.ProcedureType;
		BEGIN
			IF Trace THEN TraceEnter("DesignateSelfDesignator") END;
			dest := destination; destination := emptyOperand;
			scope := currentScope;
			WHILE (scope.outerScope # NIL) & ((scope.outerScope IS SyntaxTree.ProcedureScope) OR (scope.outerScope IS SyntaxTree.BlockScope)) DO
				scope := scope.outerScope;
			END;
			IF scope.outerScope IS SyntaxTree.ModuleScope THEN
				moduleSection := meta.ModuleSection();
				IF backend.cooperative THEN
					moduleOffset := 0;
				ELSE
					moduleOffset := moduleSection.pc;
				END;
				result.mode := ModeValue;
				result.op := IntermediateCode.Address(addressType, moduleSection.name, GetFingerprint(moduleSection.symbol), moduleOffset);
			ELSIF (scope.outerScope IS SyntaxTree.CellScope) & ~backend.cellsAreObjects THEN
				result.mode := ModeValue;
				Global.GetSymbolSegmentedName(scope.outerScope(SyntaxTree.CellScope).ownerCell.typeDeclaration, name);
				result.op := IntermediateCode.Address(addressType, name, 0, moduleOffset);
			ELSE
				GetBaseRegister(basereg,currentScope,scope);
				InitOperand(result,ModeReference);
				result.op := basereg;
				procedure := scope(SyntaxTree.ProcedureScope).ownerProcedure;
				procedureType := procedure.type(SyntaxTree.ProcedureType);
				parametersSize := ProcParametersSize(procedure);
				IntermediateCode.AddOffset(result.op,ToMemoryUnits(system,addressType.sizeInBits)*(procedureType.parametersOffset+1)+parametersSize);
				IF backend.cooperative THEN
					IntermediateCode.AddOffset(result.op,ToMemoryUnits(system,addressType.sizeInBits));
				END;
				IF ~(x.type.resolved.IsPointer() OR (x.type.resolved IS SyntaxTree.CellType) &  backend.cellsAreObjects) THEN (* var par ! *)
					MakeMemory(result.op, result.op, addressType, 0);
				END;
				(* tag must be loaded when dereferencing SELF pointer *)
			END;
			destination := dest;
			IF Trace THEN TraceExit("DesignateSelfDesignator") END;
		END DesignateSelfDesignator;

		PROCEDURE DesignateResultDesignator(x: SyntaxTree.ResultDesignator; VAR result: Operand);
		VAR procedure: SyntaxTree.Procedure; procedureType: SyntaxTree.ProcedureType; parameter: SyntaxTree.Parameter;
			symbol: SyntaxTree.Symbol;
		BEGIN
			IF Trace THEN TraceEnter("DesignateResultDesignator") END;
			IF currentIsInline THEN
				symbol := currentScope.FindSymbol(ResultDesignatorName); (* is an alias *)
				Symbol(symbol, result);
			ELSE
				procedure := currentScope(SyntaxTree.ProcedureScope).ownerProcedure;
				procedureType := procedure.type(SyntaxTree.ProcedureType);
				parameter := procedureType.returnParameter;
				DesignateParameter(parameter, result);
			END;
			IF Trace THEN TraceExit("DesignateResultDesignator") END;
		END DesignateResultDesignator;

		PROCEDURE GetDataSection(): IntermediateCode.Section;
		VAR name: Basic.SegmentedName; section: IntermediateCode.Section;
		BEGIN
			Global.GetModuleSegmentedName(module.module, name);
			Basic.SuffixSegmentedName(name,Basic.MakeString("@Immediates"));
			section := NewSection(module.allSections, Sections.ConstSection, name,NIL, dump # NIL);
			RETURN section
		END GetDataSection;

		PROCEDURE GetImmediateMem(VAR vop: IntermediateCode.Operand);
		VAR data: IntermediateCode.Section;pc: LONGINT; type: IntermediateCode.Type;
		BEGIN
			type := vop.type;
			data := GetDataSection();
			pc := EnterImmediate(data,vop);
			IntermediateCode.InitAddress(vop, addressType, data.name, 0, pc);
			IntermediateCode.MakeMemory(vop, type);
		END GetImmediateMem;

		PROCEDURE DesignateMathArrayValue(x: SyntaxTree.MathArrayValue; VAR result: Operand);
		VAR  irv: IntermediateCode.Section; name:Basic.SegmentedName; const: SyntaxTree.Constant;

			PROCEDURE RecursiveData(x: SyntaxTree.MathArrayExpression);
			VAR numberElements,i: LONGINT; expression: SyntaxTree.Expression; op: Operand;
			BEGIN
				numberElements := x.elements.Length();
				FOR i := 0 TO numberElements-1 DO
					expression := x.elements.GetExpression(i);
					IF expression IS SyntaxTree.MathArrayExpression THEN
						RecursiveData(expression(SyntaxTree.MathArrayExpression));
					ELSE
						inData := TRUE;
						Evaluate(expression,op);
						irv.Emit(Data(position,op.op));
						inData := FALSE;
						ReleaseOperand(op);
					END;
				END;
			END RecursiveData;

		BEGIN
			IF Trace THEN TraceEnter("DesignateMathArrayValue") END;
			const := BuildConstant(module.module,x,constId);
			GetCodeSectionNameForSymbol(const,name);
			IF (const.scope = NIL) OR (const.scope.ownerModule = module.module) THEN
				irv := NewSection(module.allSections,Sections.ConstSection,name,const,commentPrintout # NIL);
			ELSE
				irv := NewSection(module.importedSections, Sections.ConstSection, name,const,commentPrintout # NIL);
			END;
			IF irv.pc = 0 THEN
				RecursiveData(x.array);
			END;
			InitOperand(result,ModeReference);
			IntermediateCode.InitAddress(result.op, addressType, irv.name, GetFingerprint(irv.symbol), 0);
		END DesignateMathArrayValue;

		PROCEDURE DesignateStringValue(x: SyntaxTree.StringValue; VAR result: Operand);
		VAR  i: LONGINT; name: Basic.SegmentedName;
			irv: IntermediateCode.Section; op: IntermediateCode.Operand;
			const: SyntaxTree.Constant;
		BEGIN
			IF Trace THEN TraceEnter("DesignateStringValue") END;
			const := BuildConstant(module.module,x,constId);
			GetCodeSectionNameForSymbol(const,name);
			IF (const.scope = NIL) OR (const.scope.ownerModule = module.module) THEN
				irv := NewSection(module.allSections, Sections.ConstSection, name,const,commentPrintout # NIL);
			ELSE
				irv := NewSection(module.importedSections, Sections.ConstSection, name,const,commentPrintout # NIL);
			END;
			IF irv.pc = 0 THEN
				FOR i := 0 TO x.length-1 DO
					IntermediateCode.InitImmediate(op,IntermediateCode.GetType(system,system.characterType),ORD(x.value[i]));
					irv.Emit(Data(position,op));
				END;
			END;
			InitOperand(result,ModeReference);
			IntermediateCode.InitAddress(result.op, addressType, irv.name, GetFingerprint(irv.symbol), 0);
			result.tag := IntermediateCode.Immediate(addressType,x.length);
		END DesignateStringValue;

		(** symbols *)

		PROCEDURE GetBaseRegister(VAR result: IntermediateCode.Operand; scope,baseScope: SyntaxTree.Scope);
		VAR left,right: IntermediateCode.Operand;level: LONGINT; s: SyntaxTree.Scope;
		BEGIN
			ASSERT(baseScope # NIL);
			level := 0;
			s := scope;
			WHILE (scope # baseScope) DO
				IF scope IS SyntaxTree.ProcedureScope THEN
					INC(level);
				ELSE
					IF scope IS SyntaxTree.BlockScope  THEN
					ELSE
						Printout.Info("scope",s);
						Printout.Info("baseScope",baseScope);
					END;
					ASSERT(scope IS SyntaxTree.BlockScope);
				END;
				scope := scope.outerScope;
			END;
			(* now scope = baseScope *)
			IF level > 0 THEN
				(* left := [fp+8] *)
				IntermediateCode.InitMemory(right,addressType,fp,ToMemoryUnits(system,2*addressType.sizeInBits));
				IF backend.cooperative OR backend.preciseGC THEN IntermediateCode.AddOffset (right, ToMemoryUnits(system,addressType.sizeInBits)) END;
				ReuseCopy(left,right);
				ReleaseIntermediateOperand(right);
				scope := scope.outerScope;
				DEC(level);
				(* { left := [left+8] } *)
				IntermediateCode.InitMemory(right,addressType,left,ToMemoryUnits(system,2*addressType.sizeInBits));
				IF backend.cooperative  OR backend.preciseGC THEN IntermediateCode.AddOffset (right, ToMemoryUnits(system,addressType.sizeInBits)) END;
				WHILE (level > 0) DO
					Emit(Mov(position,left,right));
					DEC(level);
				END;
				result := left;
			ELSE
				result := fp
			END;
			(*
			IF scope # baseScope THEN
				(* left := [fp+8] *)
				IntermediateCode.InitMemory(right,addressType,fp,ToMemoryUnits(system,2*addressType.sizeInBits));
				IF backend.cooperative OR backend.preciseGC THEN IntermediateCode.AddOffset (right, ToMemoryUnits(system,addressType.sizeInBits)) END;
				ReuseCopy(left,right);
				ReleaseIntermediateOperand(right);
				ASSERT(scope IS SyntaxTree.ProcedureScope);
				scope := scope.outerScope; DEC(level);
				(* { left := [left+8] } *)
				IntermediateCode.InitMemory(right,addressType,left,ToMemoryUnits(system,2*addressType.sizeInBits));
				IF backend.cooperative  OR backend.preciseGC THEN IntermediateCode.AddOffset (right, ToMemoryUnits(system,addressType.sizeInBits)) END;
				WHILE (scope # baseScope) & (scope IS SyntaxTree.ProcedureScope) DO
					Emit(Mov(position,left,right));
					scope := scope.outerScope; DEC(level);
				END;
				ASSERT((scope = baseScope) OR (baseScope = NIL));
				result := left;
			ELSE
				result := fp;
			END;
			*)
		END GetBaseRegister;

		(* EXPERIMENTAL *)
		PROCEDURE GetAvailability(x: SyntaxTree.Variable): WORD;
		VAR i: WORD;
		BEGIN
			IF ~backend.experiment THEN RETURN -1 END;
			i := 0;
			WHILE (availableSymbols[i].symbol # NIL) & (availableSymbols[i].symbol # x) DO
				INC(i);
			END;
			IF availableSymbols[i].symbol = NIL THEN
				availableSymbols[i].inRegister := FALSE;
				availableSymbols[i].inMemory := TRUE;
				availableSymbols[i].symbol := x;
			END;
			RETURN i;
		END GetAvailability;

		PROCEDURE DesignateVariable(x: SyntaxTree.Variable; VAR result (* in / out *): Operand);
		VAR symbol: Sections.Section;  type: SyntaxTree.Type; recordType: SyntaxTree.RecordType;
			name: Basic.SegmentedName; temp, basereg: IntermediateCode.Operand; reg: LONGINT;
			nm: ARRAY 256 OF CHAR;
		BEGIN
			IF Trace THEN TraceEnter("DesignateVariable");  END;
			type := x.type.resolved;
			x.GetName(nm);
			IF (x.preferRegister) THEN
				InitOperand(result, ModeValue);
				IF x.registerNumber < 0 THEN
					x.RegisterNumber(AcquireRegister(IntermediateCode.GetType(system, type),IntermediateCode.GeneralPurposeRegister));
					reg := x.registerNumber;
				ELSE
					reg := registerUsageCount.Map(x.registerNumber);
					UseRegister(reg);
				END;
				IntermediateCode.InitRegister(result.op,IntermediateCode.GetType(system, type),IntermediateCode.GeneralPurposeRegister,reg);
			ELSIF x.externalName # NIL THEN
				InitOperand(result,ModeReference);
				Basic.ToSegmentedName(x.externalName^, name);
				IntermediateCode.InitAddress(result.op, addressType, name, 0, 0);
			ELSIF (x.scope IS SyntaxTree.ProcedureScope)  OR (x.scope IS SyntaxTree.BlockScope) THEN (* local variable (potentially via nested procedure) *)
				InitOperand(result,ModeReference);
				GetBaseRegister(basereg,currentScope,x.scope);
				result.op := basereg;
				IntermediateCode.AddOffset(result.op,ToMemoryUnits(system,x.offsetInBits));
				IF (x.kind = SyntaxTree.VarParameter) OR (x.kind = SyntaxTree.ConstParameter) & (type IS SyntaxTree.RecordType) THEN
					IntermediateCode.MakeMemory(result.op,addressType);
				END;
				(* EXPERIMENTAL *)
				result.availability := GetAvailability(x);
			ELSIF (x.scope = moduleScope) OR (x.scope IS SyntaxTree.CellScope) & ~backend.cellsAreObjects THEN (* global variable *)
				InitOperand(result,ModeReference);
				GetCodeSectionNameForSymbol(x,name);
				symbol := NewSection(module.allSections, Sections.VarSection, name,x,commentPrintout # NIL);
				IntermediateCode.InitAddress(result.op, addressType, symbol.name, GetFingerprint(symbol.symbol), 0);
			ELSIF x.scope IS SyntaxTree.ModuleScope THEN (* global variable in imported module *)
				InitOperand(result,ModeReference);
				GetCodeSectionNameForSymbol(x,name);
				symbol := NewSection(module.importedSections, Sections.VarSection, name,x,commentPrintout # NIL);
				IntermediateCode.InitAddress(result.op, addressType, symbol.name, GetFingerprint(symbol.symbol), 0)
			ELSE (* field, left designator must have been emitted *)
				ASSERT(result.mode = ModeReference);
				IF result.op.mode = IntermediateCode.ModeMemory THEN
					ReuseCopy(temp,result.op);
					ReleaseIntermediateOperand(result.op);
					result.op := temp;
				END;
				IntermediateCode.AddOffset(result.op,ToMemoryUnits(system,x.offsetInBits));

				IF backend.cooperative & (x.scope IS SyntaxTree.RecordScope) THEN
					recordType := x.scope(SyntaxTree.RecordScope).ownerRecord;
					IF recordType.isObject & ~recordType.pointerType.isPlain THEN
						IntermediateCode.AddOffset(result.op,BaseObjectTypeSize * ToMemoryUnits(system,addressType.sizeInBits));
					END;
				END;
			END;

			IF type IS SyntaxTree.ProcedureType THEN
				ReleaseIntermediateOperand(result.tag);
				IF type(SyntaxTree.ProcedureType).isDelegate THEN
					IF x.kind = SyntaxTree.VarParameter THEN
						ReuseCopy(result.tag,result.op);
						IntermediateCode.AddOffset(result.tag,ToMemoryUnits(system,system.addressSize));
						IntermediateCode.MakeMemory(result.tag,addressType);
					ELSE
						IntermediateCode.InitMemory(result.tag,addressType,result.op,ToMemoryUnits(system,system.addressSize));
						UseIntermediateOperand(result.tag);
					END;
				ELSE
					result.tag := nil; (* nil *)
				END;
			ELSIF (type IS SyntaxTree.ArrayType) THEN
				IF type(SyntaxTree.ArrayType).form = SyntaxTree.SemiDynamic THEN
					IF (x.scope IS SyntaxTree.ModuleScope) OR (x.scope IS SyntaxTree.CellScope) & ~backend.cellsAreObjects THEN
						ReleaseIntermediateOperand(result.tag);
						Global.GetSymbolSegmentedName(x,name);
						Basic.SuffixSegmentedName (name, Basic.MakeString ("@len"));
						symbol := NewSection(module.allSections, Sections.VarSection, name,NIL ,commentPrintout # NIL);
						IntermediateCode.InitAddress(result.tag, addressType, symbol.name,0 , 0);
					ELSE
					END;
				ELSE
					ReleaseIntermediateOperand(result.tag);
					IntermediateCode.InitImmediate(result.tag,addressType,type(SyntaxTree.ArrayType).staticLength);
				END;
			ELSIF (type IS SyntaxTree.MathArrayType) THEN
				IF type(SyntaxTree.MathArrayType).form IN {SyntaxTree.Open} THEN
					ReleaseIntermediateOperand(result.tag);
					result.tag := result.op;
					UseIntermediateOperand(result.tag);
					IntermediateCode.AddOffset(result.op,ToMemoryUnits(system,MathAdrOffset*addressType.sizeInBits));
					IntermediateCode.MakeMemory(result.op,addressType);
				END;
			ELSIF (type IS SyntaxTree.RecordType) & (type(SyntaxTree.RecordType).pointerType = NIL) THEN
				IF x.kind = SyntaxTree.ValueParameter THEN
					ReleaseIntermediateOperand(result.tag);
					result.tag := TypeDescriptorAdr(type);
					UseIntermediateOperand(result.tag);
				ELSE (* const or var *)
					ReleaseIntermediateOperand(result.tag);
					result.tag := basereg;
					IntermediateCode.AddOffset(result.tag,ToMemoryUnits(system,x.offsetInBits+system.addressSize));
					IntermediateCode.MakeMemory(result.tag,addressType);
					UseIntermediateOperand(result.tag);
				END;
			END;
			IF Trace THEN TraceExit("DesignateVariable") END;
		END DesignateVariable;


		PROCEDURE DesignateParameter(x: SyntaxTree.Parameter; VAR result: Operand);
		VAR type: SyntaxTree.Type; basereg, mem: IntermediateCode.Operand; symbol: Sections.Section;
			name: Basic.SegmentedName; ptype: SyntaxTree.Type; temp: IntermediateCode.Operand; reg: LONGINT;
		BEGIN
			type := x.type.resolved;
			IF Trace THEN TraceEnter("DesignateParameter") END;

			IF (x.preferRegister) THEN
				InitOperand(result, ModeValue);
				IF x.registerNumber < 0 THEN
					x.RegisterNumber(AcquireRegister(IntermediateCode.GetType(system, type),IntermediateCode.GeneralPurposeRegister));
					reg := x.registerNumber;
				ELSE
					reg := registerUsageCount.Map(x.registerNumber);
					UseRegister(reg);
				END;
				IntermediateCode.InitRegister(result.op,IntermediateCode.GetType(system, type),IntermediateCode.GeneralPurposeRegister,reg);
				RETURN;
			ELSIF x.ownerType IS SyntaxTree.CellType THEN
				ptype := x.type.resolved;
				IF backend.cellsAreObjects THEN
					ASSERT(result.mode = ModeReference);
					IF result.op.mode = IntermediateCode.ModeMemory THEN
						ReuseCopy(temp,result.op);
						ReleaseIntermediateOperand(result.op);
						result.op := temp;
					END;
					IntermediateCode.AddOffset(result.op,ToMemoryUnits(system,x.offsetInBits));
					RETURN;
				ELSE
					InitOperand(result,ModeReference);
					GetCodeSectionNameForSymbol(x,name);
					symbol := NewSection(module.allSections, Sections.VarSection, name,x,commentPrintout # NIL);
					IntermediateCode.InitAddress(result.op, addressType, symbol.name, GetFingerprint(symbol.symbol), 0);
					RETURN;
				END;
			ELSIF ~backend.cellsAreObjects & (currentScope IS SyntaxTree.ProcedureScope) & (currentScope(SyntaxTree.ProcedureScope).ownerProcedure.isConstructor) & (currentScope.outerScope IS SyntaxTree.CellScope) THEN
				InitOperand(result,ModeReference);
				GetCodeSectionNameForSymbol(x,name);
				symbol := NewSection(module.allSections, Sections.VarSection, name,x,commentPrintout # NIL);
				IntermediateCode.InitAddress(result.op, addressType, symbol.name, GetFingerprint(symbol.symbol), 0);
				RETURN
			ELSE
				GetBaseRegister(basereg,currentScope,x.scope);
				InitOperand(result,ModeReference);
				result.op := basereg;
			END;

			IF IsOpenArray(type) THEN
				result.tag := basereg;
				IntermediateCode.AddOffset(result.op,ToMemoryUnits(system,x.offsetInBits));
				IntermediateCode.MakeMemory(result.op,addressType);
				IF Global.IsOberonProcedure(x.ownerType) THEN
					IntermediateCode.AddOffset(result.tag,ToMemoryUnits(system,x.offsetInBits+addressType.sizeInBits));
					UseIntermediateOperand(result.tag);
				ELSE
					IntermediateCode.InitImmediate(result.tag,addressType,MAX(LONGINT)); (* non-Oberon procedure => unbounded array length *)
				END;
			ELSIF IsStaticArray(type) & (x.kind = SyntaxTree.ValueParameter) THEN
				IntermediateCode.AddOffset(result.op,ToMemoryUnits(system,x.offsetInBits));
				IntermediateCode.InitImmediate(result.tag,addressType,type(SyntaxTree.ArrayType).staticLength);
			ELSIF IsStaticArray(type) THEN
				IntermediateCode.AddOffset(result.op,ToMemoryUnits(system,x.offsetInBits));
				IntermediateCode.MakeMemory(result.op,addressType);
				IntermediateCode.InitImmediate(result.tag,addressType,type(SyntaxTree.ArrayType).staticLength);
			ELSIF type IS SyntaxTree.MathArrayType THEN
				IntermediateCode.AddOffset(result.op,ToMemoryUnits(system,x.offsetInBits));
				WITH type: SyntaxTree.MathArrayType DO
					IF (x.kind = SyntaxTree.ValueParameter) OR (x.kind = SyntaxTree.ConstParameter) THEN
						IF type.form = SyntaxTree.Tensor THEN
						ELSIF type.form = SyntaxTree.Open THEN
							result.tag := result.op;
							IntermediateCode.AddOffset(result.op,ToMemoryUnits(system,MathAdrOffset*addressType.sizeInBits));
							IntermediateCode.MakeMemory(result.op,addressType);
							UseIntermediateOperand(result.tag);
						ELSIF type.form = SyntaxTree.Static THEN
							IF x.kind = SyntaxTree.ConstParameter THEN
								IntermediateCode.MakeMemory(result.op,addressType);
							END;
						ELSE HALT(100)
						END;
					ELSIF x.kind = SyntaxTree.VarParameter THEN
						IF type.form = SyntaxTree.Tensor THEN
							ToMemory(result.op,addressType,0);
						ELSIF type.form = SyntaxTree.Open THEN
							MakeMemory(mem, result.op,  addressType, 0); (* offset already added above *)
							ReuseCopy(result.tag, mem);
							ReleaseIntermediateOperand(mem);
							ReleaseIntermediateOperand(result.op);
							MakeMemory(result.op, result.tag, addressType, ToMemoryUnits(system,MathAdrOffset*addressType.sizeInBits));
						ELSIF type.form = SyntaxTree.Static THEN
							IntermediateCode.MakeMemory(result.op,addressType);
						ELSE HALT(100)
						END;
					ELSE HALT(100)
					END;
				END;
			ELSIF (x.kind = SyntaxTree.VarParameter) OR (x.kind = SyntaxTree.ConstParameter) & (type IS SyntaxTree.RecordType) THEN
				IntermediateCode.AddOffset(result.op,ToMemoryUnits(system,x.offsetInBits));
				IntermediateCode.MakeMemory(result.op,addressType);
			ELSIF (x.kind = SyntaxTree.ValueParameter) OR (x.kind = SyntaxTree.ConstParameter) THEN
				IntermediateCode.AddOffset(result.op,ToMemoryUnits(system,x.offsetInBits));
			END;

			IF type IS SyntaxTree.ProcedureType THEN
				ReleaseIntermediateOperand(result.tag);
				IF type(SyntaxTree.ProcedureType).isDelegate THEN
					IF x.kind = SyntaxTree.VarParameter THEN
						ReuseCopy(result.tag,result.op);
						IntermediateCode.AddOffset(result.tag,ToMemoryUnits(system,system.addressSize));
						IntermediateCode.MakeMemory(result.tag,addressType);
					ELSE
						IntermediateCode.InitMemory(result.tag,addressType,result.op,ToMemoryUnits(system,system.addressSize));
						UseIntermediateOperand(result.tag);
					END;
				ELSE
					result.tag := nil;
				END;
			(* tag for pointer type computed not here but during dereferencing *)
			ELSIF (type IS SyntaxTree.RecordType) & (type(SyntaxTree.RecordType).pointerType= NIL) & (x.kind IN {SyntaxTree.VarParameter, SyntaxTree.ConstParameter}) (* & ~(x.selfParameter) *) THEN
				ReleaseIntermediateOperand(result.tag);
				result.tag := basereg;
				IntermediateCode.AddOffset(result.tag,ToMemoryUnits(system,x.offsetInBits+system.addressSize));
				IntermediateCode.MakeMemory(result.tag,addressType);
				UseIntermediateOperand(result.tag);
			ELSIF (type IS SyntaxTree.RecordType) & (type(SyntaxTree.RecordType).pointerType= NIL) & ((x.kind = SyntaxTree.ValueParameter) OR x.selfParameter) THEN
				ReleaseIntermediateOperand(result.tag);
				result.tag := TypeDescriptorAdr(type);
				UseIntermediateOperand(result.tag);
			END;
			IF Trace THEN TraceExit("DesignateParameter") END;
		END DesignateParameter;

		PROCEDURE DynamicCallOperand(x: SyntaxTree.Procedure; VAR operand: Operand);
		VAR tag,reg,tmp: IntermediateCode.Operand; offset: LONGINT; recordType: SyntaxTree.RecordType; name, stackFrame: Basic.SegmentedName;
		BEGIN
			IF Trace THEN TraceEnter("DynamicCallOperand") END;
			(* left.p: left already emitted *)
			tag := operand.op; (* value of pointer to left *)
			(* get type desc *)
			tmp := operand.tag;
			IntermediateCode.MakeMemory(tmp,addressType);
			(* get method adr *)
			Reuse1(reg,tmp);
			ReleaseIntermediateOperand(tmp);

			IF backend.cooperative THEN
				recordType := x.scope(SyntaxTree.RecordScope).ownerRecord;
				WHILE recordType.baseType # NIL DO
					recordType := recordType.GetBaseRecord ();
				END;
				GetRecordTypeName (recordType,name);
				Basic.ToSegmentedName ("BaseTypes.StackFrame",stackFrame);
				IF (name = stackFrame) OR HasExplicitTraceMethod (recordType) THEN
					offset := 0;
				ELSE
					offset := 2;
				END;
				Emit(Add(position,reg,tmp,IntermediateCode.Immediate(addressType, ToMemoryUnits(system,system.addressSize  *(meta.MethodTableOffset + x.methodNumber + offset)))));
			ELSIF meta.simple THEN
				Emit(Add(position,reg,tmp,IntermediateCode.Immediate(addressType, ToMemoryUnits(system,system.addressSize  *(meta.MethodTableOffset + x.methodNumber)))));
			ELSE
				Emit(Add(position,reg,tmp,IntermediateCode.Immediate(addressType, ToMemoryUnits(system,system.addressSize  *(meta.MethodTableOffset - x.methodNumber)))));
			END;

			InitOperand(operand,ModeReference);
			(* then operand.op contains the method adr and operand.tag contains the potential self pointer value *)
			operand.op := reg;
			operand.tag := tag;
			IF Trace THEN TraceExit("DynamicCallOperand") END;
		END DynamicCallOperand;

		PROCEDURE StaticCallOperand(x: SyntaxTree.Procedure; VAR operand: Operand);
		VAR source: IntermediateCode.Section; tag,reg: IntermediateCode.Operand; name:Basic.SegmentedName; sectionType: SHORTINT;
			binary: BinaryCode.Section; bits: SyntaxTree.BinaryCode;
		BEGIN
			IF Trace THEN TraceEnter("StaticCallOperand") END;
			IF x.type(SyntaxTree.ProcedureType).isDelegate THEN
				tag := operand.op;
				ReleaseIntermediateOperand(operand.tag);
			ELSE tag := nil
			END;
			IF x.isInline  THEN
				sectionType := Sections.InlineCodeSection;
			ELSE
				sectionType := Sections.CodeSection;
			END;
			IF x.externalName # NIL THEN
				Basic.ToSegmentedName(x.externalName^, name);
				IntermediateCode.InitAddress(reg, addressType, name, 0, 0);
			ELSE
				GetCodeSectionNameForSymbol(x, name);
				IF (x.scope.ownerModule = module.module) THEN
					source := NewSection(module.allSections, sectionType, name,x,commentPrintout # NIL);
				ELSIF (sectionType = Sections.InlineCodeSection) & (x.procedureScope.body.code.sourceCode # NIL) THEN
					source := NewSection(module.allSections, sectionType, name,x,commentPrintout # NIL);
					IF source.pc = 0 THEN (* no code yet *)
						source.Emit(Asm(position,x.procedureScope.body.code.sourceCode,x.procedureScope (*currentScope*)));
					END;
				ELSIF (sectionType = Sections.InlineCodeSection) & (x.procedureScope.body.code.inlineCode # NIL) THEN
					bits := x.procedureScope.body.code.inlineCode;
					source := NewSection(module.allSections, sectionType, name, x, commentPrintout # NIL);
					binary := BinaryCode.NewBinarySection(source.type, system.codeUnit, name, FALSE, FALSE);
					binary.CopyBits(bits, 0, bits.GetSize());
					source.SetResolved(binary);
				ELSE
					source := NewSection(module.importedSections, sectionType, name,x,commentPrintout # NIL);
				END;
				IntermediateCode.InitAddress(reg, addressType, source.name , GetFingerprint(source.symbol), 0);
			END;
			InitOperand(operand,ModeValue);
			operand.op := reg;
			operand.tag := tag;
			IF Trace THEN TraceExit("StaticCallOperand") END;
		END StaticCallOperand;

		PROCEDURE DesignateProcedure(x: SyntaxTree.Procedure; VAR result: Operand);
		(* handle expressions of the form designator.procedure or procedure *)
		BEGIN
			IF Trace THEN TraceEnter("DesignateProcedure") END;
			EndBasicBlock;
			IF  (x.type(SyntaxTree.ProcedureType).isDelegate) & ~SemanticChecker.IsStaticProcedure(x) & ~(result.tag.mode = IntermediateCode.ModeImmediate) THEN
				DynamicCallOperand(x, result);
			ELSIF x.isInline THEN
				StaticCallOperand(x, result);
			ELSE
				StaticCallOperand(x, result);
			END;
			IF Trace THEN TraceExit("DesignateProcedure") END;
		END DesignateProcedure;

		PROCEDURE Symbol(x: SyntaxTree.Symbol; VAR result: Operand);
		BEGIN
			WITH x:
			| SyntaxTree.TypeDeclaration DO 
						ASSERT((x.declaredType.resolved IS SyntaxTree.EnumerationType) OR (x.declaredType.resolved IS SyntaxTree.RecordType) OR (x.declaredType.resolved IS SyntaxTree.PointerType) & (x.declaredType.resolved(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.RecordType));
			| SyntaxTree.Parameter DO DesignateParameter(x, result); 
			| SyntaxTree.Variable DO DesignateVariable(x, result); 
			| SyntaxTree.Procedure DO DesignateProcedure(x, result);
			| SyntaxTree.Alias DO Designate(x.expression, result);
			| SyntaxTree.Import DO (* nothing *)
			END;
		END Symbol;
		

		(** statements *)

		PROCEDURE AssignMathArray(left,right: SyntaxTree.Expression);
		VAR leftType, rightType: SyntaxTree.MathArrayType;
			leftBase, rightBase: SyntaxTree.Type;
			procedureName,s: SyntaxTree.IdentifierString;
			arrayBase: SyntaxTree.Module; saved: RegisterEntry;  
			procedure: SyntaxTree.Procedure; 
			parameter: SyntaxTree.Parameter;
			size: LONGINT; rightKind: LONGINT;
			dummy: IntermediateCode.Operand;
			result: Operand;

		CONST moduleName = "FoxArrayBase";

			PROCEDURE OpenArray(from: SyntaxTree.MathArrayType): SyntaxTree.MathArrayType;
			VAR result: SyntaxTree.MathArrayType; base: SyntaxTree.Type;
			BEGIN
				base := from(SyntaxTree.MathArrayType).arrayBase.resolved;
				IF base IS SyntaxTree.MathArrayType THEN
					base := OpenArray(base(SyntaxTree.MathArrayType));
				END;
				result := SyntaxTree.NewMathArrayType(left.position,currentScope,SyntaxTree.Open);
				result.SetArrayBase(base);
				RETURN result
			END OpenArray;

		BEGIN
			IF AddImport(moduleName,arrayBase,TRUE) THEN
				SaveRegisters();ReleaseUsedRegisters(saved);
				leftType := left.type.resolved(SyntaxTree.MathArrayType);
				rightType := right.type.resolved(SyntaxTree.MathArrayType);
				leftBase := SemanticChecker.ArrayBase(leftType,MAX(LONGINT));
				rightBase := SemanticChecker.ArrayBase(rightType,MAX(LONGINT));
				ASSERT(leftBase.resolved.SameType(rightBase.resolved));

				IF leftType.form = SyntaxTree.Tensor THEN
					procedureName := "CopyTensor"; rightKind := SyntaxTree.ValueParameter;
				ELSIF leftType.form = SyntaxTree.Open THEN
					procedureName := "CopyArray"; rightKind := SyntaxTree.VarParameter;
				ELSIF leftType.form = SyntaxTree.Static THEN
					procedureName := "CopyArray";rightKind := SyntaxTree.VarParameter;
					leftType := OpenArray(leftType); (* necessary since copy procedure presumes an open array *)
				END;

				procedure := arrayBase.moduleScope.FindProcedure(SyntaxTree.NewIdentifier(procedureName));
				IF procedure = NIL THEN
					s := "Instruction not supported on target, emulation procedure ";
					Strings.Append(s,moduleName);
					Strings.Append(s,".");
					Strings.Append(s,procedureName);
					Strings.Append(s," not present");
					Error(position,s);
				ELSE
					parameter := SyntaxTree.NewParameter(left.position,procedure.type(SyntaxTree.ProcedureType),SyntaxTree.NewIdentifier("temp"), SyntaxTree.VarParameter);
					parameter.SetType(leftType);
					parameter.SetAccess(SyntaxTree.Internal);
					PushParameter(left,parameter,SyntaxTree.OberonCallingConvention, FALSE, dummy,-1);
					parameter.SetKind(rightKind);
					PushParameter(right,parameter,SyntaxTree.OberonCallingConvention, FALSE, dummy,-1);
					size := ToMemoryUnits(system,system.SizeOf(rightBase));
					Emit(Push(position,IntermediateCode.Immediate(sizeType,size)));
					StaticCallOperand(procedure,result);
					Emit(Call(position,result.op,ProcParametersSize(procedure)));
					ReleaseOperand(result);
				END;
				RestoreRegisters(saved);
			END;
		END AssignMathArray;

		VAR modifyAssignmentCounter := 0: LONGINT;

		PROCEDURE ModifyAssignments(CONST value: IntermediateCode.Operand);
		VAR processor,mem,dst: IntermediateCode.Operand;
		BEGIN
			IF value.intValue = true.intValue THEN
				INC(modifyAssignmentCounter);
				IF (modifyAssignmentCounter > 1) THEN RETURN END;
				modifyAssignmentsPC := section.pc;

			ELSE
				DEC(modifyAssignmentCounter);
				IF (modifyAssignmentCounter > 0) THEN RETURN END;
				INC(statCoopModifyAssignments , section.pc - modifyAssignmentsPC);
			END;
			IntermediateCode.InitMemory (processor,  IntermediateCode.SignedIntegerType(addressType.sizeInBits), ap, ToMemoryUnits(system, ProcessorOffset * addressType.sizeInBits));
			dst := NewRegisterOperand (addressType);
			Emit(Mov(position,dst, processor));
			IntermediateCode.InitMemory(mem,bool, dst, 0);
			Emit(Mov(position,mem, value));
			ReleaseIntermediateOperand(dst);
		END ModifyAssignments;

		PROCEDURE CopySize(left: SyntaxTree.Expression; tag: IntermediateCode.Operand): IntermediateCode.Operand;
		VAR type: SyntaxTree.Type; procedureType: SyntaxTree.ProcedureType; parameter: SyntaxTree.Parameter; mem: IntermediateCode.Operand;
		BEGIN
			type := left.type.resolved;
			IF (type IS SyntaxTree.RecordType) & (left IS SyntaxTree.SymbolDesignator) & (left(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Parameter) THEN
				parameter := left(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Parameter);
				procedureType := parameter.ownerType.resolved(SyntaxTree.ProcedureType);
				IF procedureType.returnParameter = parameter THEN
					(* this is the only case where the destination can be dynamically smaller than the source
						in all other cases the dynamic size has to be taken
					*)
					IF backend.cooperative THEN
						MakeMemory(mem, tag, addressType, ToMemoryUnits(system,system.addressSize));
					ELSE
						MakeMemory(mem, tag, addressType, 0);
					END;
					RETURN mem;
				END;
			END;
			RETURN IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.SizeOf(type)));
		END CopySize;

		PROCEDURE AssignReference(left, right: SyntaxTree.Expression);
		VAR leftO, rightO: Operand;
		BEGIN
			Designate(right,rightO);
			Designate(left,leftO);
			Emit(Mov(position,leftO.op,rightO.op));
			IF left.type.resolved IS SyntaxTree.RecordType THEN
				Emit(Mov(position,leftO.tag,rightO.tag));
			END;
			ReleaseOperand(leftO);
			ReleaseOperand(rightO);
		END AssignReference;

		PROCEDURE Assign(left,right: SyntaxTree.Expression);
		VAR
			leftO, rightO: Operand;
			arg, mem, sizeOp: IntermediateCode.Operand;
			leftType, rightType, componentType, base: SyntaxTree.Type;
			size: LONGINT;
			parameters: SyntaxTree.ExpressionList;
			procedure: SyntaxTree.Procedure;
			call: SyntaxTree.ProcedureCallDesignator;
			designator, prevResult: SyntaxTree.Designator;
			saved: RegisterEntry;

			PROCEDURE CanPassAsResultParameter(right: SyntaxTree.Expression): BOOLEAN;
			VAR procedureType: SyntaxTree.ProcedureType;
			BEGIN
				IF SemanticChecker.ReturnedAsParameter(system,right.type)  THEN
					IF right IS SyntaxTree.ProcedureCallDesignator THEN
						procedureType := right(SyntaxTree.ProcedureCallDesignator).left.type.resolved(SyntaxTree.ProcedureType);
						RETURN procedureType.callingConvention = SyntaxTree.OberonCallingConvention
					ELSIF right IS SyntaxTree.BuiltinCallDesignator THEN
						WITH right: SyntaxTree.BuiltinCallDesignator DO
							IF right.id = Global.Reshape THEN RETURN TRUE
							END;
						END;
					ELSIF right IS SyntaxTree.InlineCallDesignator THEN
						RETURN TRUE;
					END;
				END;
				RETURN FALSE
			END CanPassAsResultParameter;

		BEGIN
			IF left = NIL THEN (* ignore result *)
				Evaluate(right, rightO);
				ReleaseOperand(rightO);
				RETURN;
			END;
			ASSERT(left.type # NIL); ASSERT(right.type # NIL);
			leftType := left.type.resolved; rightType:= right.type.resolved;

			IF backend.cooperative & left.NeedsTrace() THEN
				ModifyAssignments(true);
				IF  (leftType IS SyntaxTree.RecordType) OR IsStaticArray(leftType) THEN
					Designate(right, rightO);
					Designate(left, leftO);
					ASSERT(leftO.mode = ModeReference);
					TransferToRegister(leftO.op, leftO.op);
					TransferToRegister(rightO.op, rightO.op);
					Emit(Push(position, leftO.op));
					Emit(Push(position, rightO.op));
					CallAssignMethod(leftO.op, rightO.op, left.type);
					Emit(Pop(position, rightO.op));
					Emit(Pop(position, leftO.op));
					sizeOp := CopySize(left, leftO.tag);
					Emit(Copy(position,leftO.op,rightO.op,sizeOp));
					ReleaseIntermediateOperand(sizeOp);
					ReleaseOperand(leftO);
					ReleaseOperand(rightO);
				ELSE
					Evaluate(right,rightO);
					Designate(left,leftO);
					ASSERT(leftO.mode = ModeReference);
					IF (leftType IS SyntaxTree.ProcedureType) THEN
						(* copy procedure address first *)
						MakeMemory(mem,leftO.op,addressType,0);
						Emit(Mov(position,mem,rightO.op));
						ReleaseIntermediateOperand(mem);
						(* copy pointer address *)
						IntermediateCode.MakeAddress(leftO.tag, addressType);
						CallAssignPointer(leftO.tag, rightO.tag);
					ELSE
						ASSERT(system.SizeOf(left.type) = system.addressSize);
						CallAssignPointer(leftO.op, rightO.op);
					END;
					ReleaseOperand(leftO);
					ReleaseOperand(rightO);
				END;
				ModifyAssignments(false);
				RETURN;
			ELSIF backend.writeBarriers &  left.NeedsTrace() & OnHeap(left) & ~((leftType IS SyntaxTree.MathArrayType) & ~IsStaticMathArray(leftType)) THEN
				SaveRegisters();ReleaseUsedRegisters(saved);
				IF SemanticChecker.IsPointerType(leftType) THEN
					Evaluate(right,rightO);
					Designate(left,leftO);
					Emit(Push(position,leftO.op));
					ReleaseOperand(leftO);
					Emit(Push(position,rightO.op));
					ReleaseOperand(rightO);
					CallThis(position,"Heaps","Assign",2);
				ELSIF leftType.IsRecordType() THEN
					Designate(right,rightO);
					Designate(left,leftO);
					Emit(Push(position,leftO.op));
					Emit(Push(position,leftO.tag)); (* type desc *)
					ReleaseOperand(leftO);
					Emit(Push(position,rightO.op));
					ReleaseOperand(rightO);
					CallThis(position,"Heaps","AssignRecord",3);
				ELSIF IsStaticArray(leftType) THEN
					size := StaticArrayNumElements(leftType);
					base := StaticArrayBaseType(leftType);
					Designate(right,rightO);
					Designate(left,leftO);
					Emit(Push(position,leftO.op));
					ReleaseOperand(leftO);

					arg := TypeDescriptorAdr(base);
					Emit(Push(position,arg));

					Emit(Push(position,IntermediateCode.Immediate(addressType,size)));
					Emit(Push(position,rightO.op));
					ReleaseOperand(rightO);
					CallThis(position,"Heaps","AssignArray",4);
				ELSIF  IsStaticMathArray(leftType) THEN (* the representation of a static math array coincides with static array *)
					size := StaticMathArrayNumElements(leftType);
					base := StaticMathArrayBaseType(leftType);
					Designate(right,rightO);
					Designate(left,leftO);
					Emit(Push(position,leftO.op));
					ReleaseOperand(leftO);

					arg := TypeDescriptorAdr(base);
					Emit(Push(position,arg));

					Emit(Push(position,IntermediateCode.Immediate(addressType,size)));
					Emit(Push(position,rightO.op));
					ReleaseOperand(rightO);
					CallThis(position,"Heaps","AssignArray",4);
				ELSIF leftType IS SyntaxTree.ProcedureType THEN
					ASSERT(leftType(SyntaxTree.ProcedureType).isDelegate);
					Evaluate(right,rightO);
					Designate(left,leftO);
					MakeMemory(mem,leftO.op,addressType,0);
					Emit(Mov(position,mem,rightO.op));
					ReleaseIntermediateOperand(mem);
					IntermediateCode.MakeAddress(leftO.tag, addressType);
					Emit (Push(position, leftO.tag));
					ReleaseOperand(leftO);
					Emit (Push(position, rightO.tag));
					ReleaseOperand(rightO);
					CallThis(position,"Heaps","Assign", 2);
				ELSE HALT(100); (* missing ? *)
				END;
				RestoreRegisters(saved);
				RETURN;
			END;

			IF CanPassAsResultParameter(right) THEN
				prevResult := procedureResultDesignator;
				procedureResultDesignator := left(SyntaxTree.Designator);
				Designate(right, rightO);
				(*Expression(right);*)
				procedureResultDesignator := prevResult;
			ELSIF (right IS SyntaxTree.UnaryExpression) & (right(SyntaxTree.UnaryExpression).operator = Scanner.Alias) THEN
				(* left <-- ALIAS OF right: zerocopy *)
				IF GetRuntimeProcedure("FoxArrayBase","ZeroCopy",procedure,TRUE) THEN
					designator := SyntaxTree.NewSymbolDesignator(Basic.invalidPosition, NIL, NIL, procedure);
					designator.SetType(procedure.type);
					parameters := SyntaxTree.NewExpressionList();  parameters.AddExpression(right(SyntaxTree.UnaryExpression).left); parameters.AddExpression(left);
					call := SyntaxTree.NewProcedureCallDesignator(position,NIL,designator(SyntaxTree.Designator),parameters);
					DesignateProcedureCallDesignator(call(SyntaxTree.ProcedureCallDesignator), rightO);
				END;
			ELSIF leftType IS SyntaxTree.RangeType THEN
				(* LHS is of array range type *)
				ASSERT(rightType IS SyntaxTree.RangeType); (* ensured by the checker *)
				Evaluate(right, rightO);
				Designate(left, leftO);(* The order is crucial. Do not reorder emission of left and right *)

				(* first *)
				MakeMemory(mem, leftO.op, IntermediateCode.GetType(system, system.lenType), 0);
				Emit(Mov(position,mem, rightO.op));
				ReleaseIntermediateOperand(mem);

				(* last *)
				MakeMemory(mem, leftO.op, IntermediateCode.GetType(system, system.lenType), ToMemoryUnits(system, system.SizeOf(system.lenType)));
				Emit(Mov(position,mem, rightO.tag));
				ReleaseIntermediateOperand(mem);

				(* step *)
				MakeMemory(mem, leftO.op, IntermediateCode.GetType(system, system.lenType), 2 * ToMemoryUnits(system, system.SizeOf(system.lenType)));
				Emit(Mov(position,mem, rightO.extra));
				ReleaseIntermediateOperand(mem);

				ReleaseOperand(rightO);
				ReleaseOperand(leftO)
			ELSIF leftType IS SyntaxTree.ComplexType THEN
				ASSERT(leftType.SameType(rightType)); (* ensured by the checker *)

				Evaluate(right, rightO);
				Designate(left, leftO); (* The order is crucial. Do not reorder emission of left and right *)

				componentType := leftType(SyntaxTree.ComplexType).componentType;

				(* real part *)
				MakeMemory(mem, leftO.op, IntermediateCode.GetType(system, componentType), 0);
				Emit(Mov(position,mem, rightO.op));
				ReleaseIntermediateOperand(mem);

				(* imaginary part *)
				MakeMemory(mem, leftO.op, IntermediateCode.GetType(system, componentType), ToMemoryUnits(system, system.SizeOf(componentType)));
				Emit(Mov(position,mem, rightO.tag));
				ReleaseIntermediateOperand(mem);

				ReleaseOperand(rightO);
				ReleaseOperand(leftO)
			ELSIF (leftType IS SyntaxTree.BasicType) OR (leftType IS SyntaxTree.PointerType) OR (leftType IS SyntaxTree.EnumerationType)
				OR (leftType IS SyntaxTree.PortType) THEN
				(* rightO := leftO;*)
				Evaluate(right,rightO);
				(* DO NOT REORDER EMISSION OF LEFT AND RIGHT OPERAND *)
				Designate(left,leftO);
				IF leftO.mode = ModeReference THEN
					MakeMemory(mem,leftO.op,IntermediateCode.GetType(system,left.type),0);
					destination := mem;
				ELSE
					destination := leftO.op;
				END;
				ReleaseOperand(leftO);

				(* EXPERIMENTAL *)
				IF (leftO.availability >= 0) & (availableSymbols[leftO.availability].inRegister) THEN
					ReleaseIntermediateOperand(destination);
					destination := availableSymbols[leftO.availability].register;
					UseIntermediateOperand(destination);
					availableSymbols[leftO.availability].inMemory := FALSE;
				END;

				IF destination.mode # IntermediateCode.Undefined THEN
					Emit(Mov(position,destination,rightO.op));
				END;
				ReleaseOperand(rightO);
				ReleaseIntermediateOperand(mem);
				IntermediateCode.InitOperand(destination);
			ELSIF (leftType IS SyntaxTree.ProcedureType) THEN
				Evaluate(right,rightO);
				Designate(left,leftO);
				MakeMemory(mem,leftO.op,addressType,0);
				Emit(Mov(position,mem,rightO.op));
				ReleaseIntermediateOperand(mem);
				IF leftType(SyntaxTree.ProcedureType).isDelegate THEN
					(* delegate *)
					(*
					MakeMemory(leftO.tag,leftO.tag,addressType); no! is already memory
					*)
					Emit(Mov(position,leftO.tag,rightO.tag));
				END;
				ReleaseOperand(leftO);
				ReleaseOperand(rightO);
			ELSIF (leftType IS SyntaxTree.RecordType) THEN
				Designate(right,rightO);
				Designate(left,leftO);
				sizeOp := CopySize(left, leftO.tag);
				Emit(Copy(position,leftO.op,rightO.op,sizeOp));
				ReleaseIntermediateOperand(sizeOp);
				ReleaseOperand(leftO); ReleaseOperand(rightO);
			ELSIF (leftType IS SyntaxTree.ArrayType) THEN
				IF (rightType IS SyntaxTree.StringType) THEN
					CopyString(left,right);
				ELSIF ((rightType IS SyntaxTree.ArrayType) & (rightType(SyntaxTree.ArrayType).staticLength # 0) OR (rightType IS SyntaxTree.MathArrayType) & (rightType(SyntaxTree.MathArrayType).staticLength # 0)) & (leftType(SyntaxTree.ArrayType).staticLength # 0) THEN
					Designate(right,rightO);
					Designate(left,leftO);
					size := ToMemoryUnits(system,system.SizeOf(rightType));
					Emit(Copy(position,leftO.op, rightO.op, IntermediateCode.Immediate(addressType,size)));
					ReleaseOperand(leftO); ReleaseOperand(rightO);
				ELSE
					HALT(201)
				END;
			ELSIF (leftType IS SyntaxTree.MathArrayType) THEN
				IF (leftType(SyntaxTree.MathArrayType).staticLength # 0) & (rightType IS SyntaxTree.MathArrayType) & (rightType(SyntaxTree.MathArrayType).staticLength # 0) THEN
					IF SemanticChecker.CanPassInRegister(system, right.type) THEN
						Evaluate(right, rightO);
						Designate(left, leftO);
						IF IntermediateCode.IsVectorRegister(leftO.op) THEN
							Emit(Mov(position, leftO.op, rightO.op));
						ELSE
							MakeMemory(mem, leftO.op, rightO.op.type,0);
							Emit(Mov(position, mem, rightO.op));
							ReleaseIntermediateOperand(mem);
						END;
					ELSE
						Designate(right, rightO);
						Designate(left,leftO);

						IF IntermediateCode.IsVectorRegister(rightO.op) &  IntermediateCode.IsVectorRegister(leftO.op) THEN
							Emit(Mov(position, leftO.op, rightO.op));
						ELSIF IntermediateCode.IsVectorRegister(rightO.op) THEN
							MakeMemory(mem, leftO.op, rightO.op.type,0);
							Emit(Mov(position, mem, rightO.op));
							ReleaseIntermediateOperand(mem);
						ELSIF IntermediateCode.IsVectorRegister(leftO.op) THEN
							MakeMemory(mem, rightO.op, leftO.op.type,0);
							Emit(Mov(position, leftO.op, mem));
							ReleaseIntermediateOperand(mem);
						ELSE
							size := ToMemoryUnits(system,system.SizeOf(rightType));
							Emit(Copy(position,leftO.op, rightO.op, IntermediateCode.Immediate(addressType,size)));
						END;
					END;

					ReleaseOperand(leftO); ReleaseOperand(rightO);
				ELSE
					AssignMathArray(left,right);
				END;
			ELSE
				HALT(200);
			END;
		END Assign;

		PROCEDURE EmitCooperativeSwitch;
		VAR quantum, offset, zero: IntermediateCode.Operand; skip: Label; pc: LONGINT;
		BEGIN
			ASSERT (cooperativeSwitches);
			pc := section.pc;
			IF lastSwitchPC = section.pc THEN RETURN END;
			IntermediateCode.InitMemory (quantum,  IntermediateCode.SignedIntegerType(addressType.sizeInBits), ap, ToMemoryUnits(system, QuantumOffset * addressType.sizeInBits));
			IntermediateCode.InitImmediate(offset, quantum.type, section.pc - lastSwitchPC); IntermediateCode.InitImmediate(zero, quantum.type, 0);
			Emit(Sub(position,quantum,quantum, offset)); skip := NewLabel(); BrgeL(skip, quantum, zero);
			lastSwitchPC := section.pc; CallThis(position,"Activities","Switch",0); SetLabel(skip);
			INC(statCoopSwitch, section.pc - pc);
		END EmitCooperativeSwitch;

		PROCEDURE CommunicationStatement(communication: SyntaxTree.CommunicationStatement);
		VAR p0,p1,tmp: SyntaxTree.Expression; s0,s1: Operand; size: LONGINT;
		BEGIN
			p0 := communication.left; p1 := communication.right;
			IF (communication.op = Scanner.ExclamationMark) OR (communication.op = Scanner.LessLess) & (communication.left.type.resolved IS SyntaxTree.PortType) THEN
				Evaluate(p0,s0);
				Evaluate(p1,s1);
				size := ToMemoryUnits(system,system.SizeOf(p1.type));
				Emit(Push(position,s0.op));
				Emit(Push(position,s1.op));
				(*
				Emit(Push(position,IntermediateCode.Immediate(addressType,size)));
				*)
				IF ~backend.cellsAreObjects THEN
					IF size > ToMemoryUnits(system, system.addressSize) THEN Error(p1.position,"send not implemented for complex data types") END;
				END;
				ReleaseOperand(s0);
				ReleaseOperand(s1);
				IF backend.cellsAreObjects THEN
					CallThis(position,"ActiveCellsRuntime","Send",2);
				ELSE
					CallThis(position,ChannelModuleName,"Send",2);
				END;
			(* ----- RECEIVE ------*)
			ELSE
				IF (communication.op = Scanner.LessLess) & (communication.right.type.resolved IS SyntaxTree.PortType) THEN
					tmp := p0; p0 := p1; p1 := tmp;
				END;
				Evaluate(p0,s0);
				Emit(Push(position,s0.op));
				Designate(p1,s1);
				size := ToMemoryUnits(system,system.SizeOf(p1.type));
				Emit(Push(position,s1.op));
				(*
				Emit(Push(position,IntermediateCode.Immediate(addressType,size)));
				*)
				IF ~backend.cellsAreObjects THEN
					IF size > ToMemoryUnits(system, system.addressSize) THEN Error(p1.position,"receive not implemented for complex data types") END;
				END;
				ReleaseOperand(s0);
				ReleaseOperand(s1);
				IF backend.cellsAreObjects THEN
					CallThis(position,"ActiveCellsRuntime","Receive",2);
				ELSE
					CallThis(position,ChannelModuleName,"Receive",2)
				END;
			END;
		END CommunicationStatement;

		PROCEDURE IfStatement(x: SyntaxTree.IfStatement);
		VAR end: Label; i,elsifs: LONGINT; elsif: SyntaxTree.IfPart; escape: BOOLEAN;

			PROCEDURE IfPart(if: SyntaxTree.IfPart; last: BOOLEAN);
			VAR false: Label; condition, value: BOOLEAN;
			BEGIN
				condition := ~SemanticChecker.IsBooleanValue(if.condition, value);
				IF condition THEN
					false := NewLabel();
					Condition(if.condition,false,FALSE);
					StatementSequence(if.statements);
					IF ~last OR (x.elsePart # NIL) THEN BrL(end) END;
					SetLabel(false);
				ELSE
					IF value THEN (* always true *)
						escape := TRUE;
						StatementSequence(if.statements);
						(* no branch necessary -- rest skipped *)
					END;
				END;
			END IfPart;

		BEGIN
			IF Trace THEN TraceEnter("VisitIfStatement") END;
			end := NewLabel();
			elsifs := x.ElsifParts();
			IfPart(x.ifPart,elsifs=0);
			FOR i := 0 TO elsifs-1 DO
				IF ~escape THEN
					elsif := x.GetElsifPart(i);
					IfPart(elsif, i=elsifs-1);
				END;
			END;
			IF (x.elsePart # NIL) & ~escape THEN
				StatementSequence(x.elsePart);
			END;
			SetLabel(end);
			IF Trace THEN TraceExit("VisitIfStatement") END;
		END IfStatement;

		PROCEDURE BrWithPart(CONST tag: IntermediateCode.Operand; x: SyntaxTree.WithPart; VAR trueL: Label);
		VAR reg: IntermediateCode.Operand;
		BEGIN
			trueL := NewLabel();
			IF backend.cooperative THEN
				IntermediateCode.InitRegister(reg,tag.type,tag.registerClass, AcquireRegister(tag.type, tag.registerClass));
				Emit(Mov(position,reg,tag));
				TypeTest(reg, x.type, trueL, TRUE,TRUE);
				ReleaseIntermediateOperand(reg);
			ELSE
				TypeTest(tag, x.type, trueL, TRUE,TRUE);
			END;
		END BrWithPart;

		PROCEDURE EmitWithPart(x: SyntaxTree.WithPart);
		BEGIN
			StatementSequence(x.statements);
		END EmitWithPart;

		PROCEDURE WithStatement(x: SyntaxTree.WithStatement);
		VAR endL,elseL: Label;i: LONGINT; trueL: POINTER TO ARRAY OF Label; res: Operand; recordType: SyntaxTree.RecordType;
			tag: IntermediateCode.Operand;
		BEGIN
			IF Trace THEN TraceEnter("VisitWithStatement") END;

			endL := NewLabel();
			elseL := NewLabel();

			Designate(x.variable,res);
			IF IsPointerToRecord(x.variable.type,recordType) THEN
				Dereference(res,recordType,IsUnsafePointer(x.variable.type))
			END;
			ReuseCopy(tag, res.tag);
			ReleaseOperand(res);
			NEW(trueL, x.WithParts());
			FOR i := 0 TO x.WithParts()-1 DO
				BrWithPart(tag, x.GetWithPart(i), trueL[i]);
			END;
			ReleaseIntermediateOperand(tag);
			BrL(elseL);
			FOR i := 0 TO x.WithParts()-1 DO
				SetLabel(trueL[i]);
				EmitWithPart(x.GetWithPart(i));
				BrL(endL);
			END;
			SetLabel(elseL);
			IF x.elsePart = NIL THEN
				IF ~isUnchecked THEN
					EmitTrap(position,WithTrap);
				END;
			ELSE
				StatementSequence(x.elsePart)
			END;
			SetLabel(endL);
			IF Trace THEN TraceExit("VisitWithStatement") END;
		END WithStatement;

		PROCEDURE CaseStatement(x: SyntaxTree.CaseStatement);
		VAR var: Operand; jmp,res,op,tmp: IntermediateCode.Operand; range, j: Basic.Integer; i,size: LONGINT; part: SyntaxTree.CasePart; constant: SyntaxTree.CaseConstant;
			out,else: Label; label: Label;
			fixups: POINTER TO ARRAY OF Label; section: IntermediateCode.Section; name: Basic.SegmentedName; string: ARRAY 32 OF CHAR;
			symbol: SyntaxTree.Symbol;
			table: BOOLEAN;
		BEGIN
			(*! split case statement into if-elsif statements for large case label lists *)
			IF Trace THEN TraceEnter("VisitCaseStatement") END;
			range := x.max-x.min+1;
			IF (range < 0) OR (range > 1024) & (range DIV x.caseParts.Length() >10) THEN
				(* if case table is larger than 1024 elements and only sparsely used, then do not employ a table *)
				table := FALSE;
				size := x.caseParts.Length();
			ELSE
				table := TRUE;
				size := LONGINT(range);
			END;
			Evaluate(x.variable,var);
			ReuseCopy(tmp,var.op);
			ReleaseIntermediateOperand(var.op);
			var.op := tmp;
			(*
			UniqueId(name,module.module,"case",caseId);
			*)
			NEW(fixups,size); FOR i := 0 TO size-1 DO fixups[i] := NIL END;
			else := NewLabel();
			IF table THEN
				Emit(Sub(position,var.op,var.op,IntermediateCode.Immediate(IntermediateCode.GetType(system,x.variable.type),x.min)));
				Convert(var.op,addressType);
				BrgeL(else,var.op,IntermediateCode.Immediate(addressType,size));
				ReuseCopy(res,var.op);
				ReleaseOperand(var);
				string := "@case"; Basic.AppendNumber(string, caseId); INC(caseId);
				Global.GetModuleSegmentedName(module.module, name);
				Basic.SuffixSegmentedName(name,Basic.MakeString(string));
				symbol := SyntaxTree.NewSymbol(name[1]);
				symbol.SetScope(moduleScope);
				section := NewSection(module.allSections, Sections.ConstSection,name,SyntaxTree.NewSymbol(name[1]),commentPrintout # NIL);
				IntermediateCode.InitAddress(jmp, addressType, section.name, GetFingerprint(section.symbol), 0);
				Emit(Mul(position,res,res,IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.addressSize))));
				Emit(Add(position,res,res,jmp));
				IntermediateCode.MakeMemory(res,addressType);
				Emit(Br(position,res));
				ReleaseIntermediateOperand(res);
			ELSE
				ReuseCopy(res,var.op); (* make sure it is in a register *)
				ReleaseOperand(var);
				BrltL(else,res,IntermediateCode.Immediate(res.type,x.min));
				BrltL(else,IntermediateCode.Immediate(res.type,x.max),res);
				FOR i := 0 TO x.caseParts.Length()-1 DO (* case parts *)
					part := x.GetCasePart(i);
					constant := part.firstConstant;
					fixups[i] := NewLabel();
					WHILE(constant # NIL) DO (* case labels for this case part *)
						IF constant.min = constant.max THEN
							BreqL(fixups[i], res,IntermediateCode.Immediate(res.type,constant.min));
						ELSE
							label := NewLabel();
							BrltL(label, res, IntermediateCode.Immediate(res.type,constant.min));
							BrltL(label, IntermediateCode.Immediate(res.type,constant.max),res);
							BrL(fixups[i]);
							SetLabel(label);
						END;
						constant := constant.next;
					END;
				END;
				BrL(else);
				ReleaseIntermediateOperand(res);
			END;
			out := NewLabel();
			FOR i := 0 TO x.caseParts.Length()-1 DO (* case parts *)
				part := x.GetCasePart(i);
				constant := part.firstConstant;
				IF table THEN
					label := NewLabel();
					SetLabel(label);
					WHILE(constant # NIL) DO (* case labels for this case part *)
						FOR j := constant.min TO constant.max DO
							fixups[j-x.min] := label;
						END;
						constant := constant.next;
					END;
				ELSE
					SetLabel(fixups[i]);
				END;
				StatementSequence(part.statements);
				BrL(out);
			END;
			SetLabel(else);
			FOR i := 0 TO size-1 DO
				IF fixups[i] = NIL THEN
					fixups[i] := else;
				END;
			END;
			IF x.elsePart # NIL THEN
				StatementSequence(x.elsePart);
			ELSIF ~isUnchecked THEN
				EmitTrap(position,CaseTrap);
			END;
			SetLabel(out);
			IF table THEN
				FOR i := 0 TO size-1 DO
					IntermediateCode.InitAddress(op, addressType, fixups[i].section.name, GetFingerprint(fixups[i].section.symbol), fixups[i].pc);
					section.Emit(Data(position,op));
				END;
			END;
			IF Trace THEN TraceExit("VisitCaseStatement") END;
		END CaseStatement;

		PROCEDURE WhileStatement(x: SyntaxTree.WhileStatement);
		VAR startL,falseL: Label;
		BEGIN
			IF Trace THEN TraceEnter("VisitWhileStatement") END;
			IF cooperativeSwitches THEN EmitCooperativeSwitch END;
			startL := NewLabel();
			falseL := NewLabel();
			SetLabel(startL);
			Condition(x.condition,falseL,FALSE);
			StatementSequence(x.statements);
			IF cooperativeSwitches THEN EmitCooperativeSwitch END;
			BrL(startL);
			SetLabel(falseL);
			IF Trace THEN TraceExit("VisitWhileStatement") END;
		END WhileStatement;

		PROCEDURE RepeatStatement(x: SyntaxTree.RepeatStatement);
		VAR falseL: Label;
		BEGIN
			IF Trace THEN TraceEnter("VisitRepeatStatement") END;
			IF cooperativeSwitches THEN EmitCooperativeSwitch END;
			falseL := NewLabel();
			SetLabel(falseL);
			StatementSequence(x.statements);
			IF cooperativeSwitches THEN EmitCooperativeSwitch END;
			Condition(x.condition,falseL,FALSE);
			IF Trace THEN TraceExit("VisitRepeatStatement") END;
		END RepeatStatement;

		PROCEDURE ForStatement(x: SyntaxTree.ForStatement);
		VAR
			binary: SyntaxTree.BinaryExpression; startL,falseL : Label; cmp: LONGINT; by: HUGEINT;
			temporaryVariable: SyntaxTree.Variable;
			temporaryVariableDesignator : SyntaxTree.Designator;
		BEGIN
			IF Trace THEN TraceEnter("VisitForStatement") END;
			falseL := NewLabel();
			startL := NewLabel();

			Assign(x.variable,x.from);
			temporaryVariable := GetTemporaryVariable(x.variable.type, FALSE, FALSE);
			temporaryVariableDesignator := SyntaxTree.NewSymbolDesignator(Basic.invalidPosition, NIL, NIL, temporaryVariable);
			temporaryVariableDesignator.SetType(x.variable.type.resolved);

			Assign(temporaryVariableDesignator,x.to);
			IF x.by = NIL THEN by := 1 ELSE by := x.by.resolved(SyntaxTree.IntegerValue).value END;
			IF by > 0 THEN
				cmp := Scanner.LessEqual
			ELSE
				cmp := Scanner.GreaterEqual
			END;
			binary := SyntaxTree.NewBinaryExpression(Basic.invalidPosition,x.variable,temporaryVariableDesignator,cmp);
			binary.SetType(system.booleanType);

			IF cooperativeSwitches THEN EmitCooperativeSwitch END;
			SetLabel(startL);

			Condition(binary,falseL, FALSE);
			StatementSequence(x.statements);

			binary := SyntaxTree.NewBinaryExpression(Basic.invalidPosition,x.variable,x.by,Scanner.Plus);
			binary.SetType(x.variable.type);
			Assign(x.variable,binary);

			IF cooperativeSwitches THEN EmitCooperativeSwitch END;

			BrL(startL);
			SetLabel(falseL);

			IF Trace THEN TraceExit("VisitForStatement") END;
		END ForStatement;

		PROCEDURE ExitableBlock(x: SyntaxTree.ExitableBlock);
		VAR prevLoop: Label;
		BEGIN
			IF Trace THEN TraceEnter("VisitExitableBlock") END;
			prevLoop := currentLoop;
			currentLoop := NewLabel();
			StatementSequence(x.statements);
			SetLabel(currentLoop);
			currentLoop := prevLoop;
			IF Trace THEN TraceExit("VisitExitableBlock") END;
		END ExitableBlock;

		PROCEDURE LoopStatement(x: SyntaxTree.LoopStatement);
		VAR prevLoop,start: Label;
		BEGIN
			IF Trace THEN TraceEnter("VisitLoopStatement") END;
			IF cooperativeSwitches THEN EmitCooperativeSwitch END;
			start := NewLabel();
			prevLoop := currentLoop;
			SetLabel(start);
			currentLoop := NewLabel();
			StatementSequence(x.statements);
			IF cooperativeSwitches THEN EmitCooperativeSwitch END;
			BrL(start);
			SetLabel(currentLoop);
			currentLoop := prevLoop;
			IF Trace THEN TraceExit("VisitLoopStatement") END;
		END LoopStatement;

		PROCEDURE ExitStatement(x: SyntaxTree.ExitStatement);
		VAR outer: SyntaxTree.Statement;
		BEGIN
			IF Trace THEN TraceEnter("VisitExitStatement") END;
			IF locked  THEN (* r if we jump out of an exclusive block *)
				outer := x.outer;
				WHILE ~(outer IS SyntaxTree.ExitableBlock) & ~((outer IS SyntaxTree.StatementBlock) & outer(SyntaxTree.StatementBlock).isExclusive) DO
					outer := outer.outer;
				END;
				IF ~(outer IS SyntaxTree.ExitableBlock) THEN
					Lock(FALSE);
				END;
			END;
			BrL(currentLoop);
			IF Trace THEN TraceExit("VisitExitStatement") END;
		END ExitStatement;

		PROCEDURE ReturnStatement(x: SyntaxTree.ReturnStatement);
		VAR
			expression, parameterDesignator: SyntaxTree.Expression;
			type, componentType: SyntaxTree.Type;
			res, right: Operand;
			left, mem, reg: IntermediateCode.Operand;
			parameter: SyntaxTree.Parameter;
			procedure: SyntaxTree.Procedure;
			procedureType: SyntaxTree.ProcedureType;
			returnTypeOffset: LONGINT;
			delegate: BOOLEAN;
			callingConvention, parametersSize: LONGINT;
			symbol: SyntaxTree.Symbol;
		BEGIN
			IF Trace THEN TraceEnter("VisitReturnStatement") END;
			expression := x.returnValue;

			IF currentIsInline THEN
				IF expression # NIL THEN
					IF currentScope IS SyntaxTree.BlockScope THEN
						symbol := currentScope.FindSymbol(ResultDesignatorName);
						WITH symbol: SyntaxTree.Alias DO
							Assign(symbol.expression, expression);
						END;
					ELSE
						HALT(200);
						(*
						map := currentMapper.Get(NIL);
						IF map # NIL THEN
							Assign(map.to, expression);
						ELSE
							Evaluate(expression,res);
							Emit(Return(position,res.op));
							ReleaseOperand(res);
						END;
						*)
					END;
				END;
				BrL(currentInlineExit);
				RETURN;
			END;

			procedure := currentScope(SyntaxTree.ProcedureScope).ownerProcedure;
			procedureType := procedure.type(SyntaxTree.ProcedureType);

			IF expression # NIL THEN
				type := expression.type.resolved;
				IF (expression IS SyntaxTree.ResultDesignator) THEN
					IF locked THEN Lock(FALSE) END;

					IF ~backend.cooperative & profile THEN ProfilerEnterExit(numberProcedures,FALSE) END;
					(* "RETURN RESULT" -> no assignment, it is assumed that result has been written to return parameter via structured return type *)
				ELSIF (type IS SyntaxTree.BasicType) & ~(type IS SyntaxTree.RangeType) & ~(type IS SyntaxTree.ComplexType) & ~type.IsPointer() OR (type IS SyntaxTree.EnumerationType) OR (procedureType.callingConvention # SyntaxTree.OberonCallingConvention)
						OR (type IS SyntaxTree.MathArrayType) & SemanticChecker.CanPassInRegister(system,type) THEN
					(* return without structured return parameter *)
					Evaluate(expression,res);
					delegate := (type IS SyntaxTree.ProcedureType) & (type(SyntaxTree.ProcedureType).isDelegate);
					IF locked OR profile THEN
						Emit(Push(position,res.op));
						IF delegate THEN HALT(200) END;
						ReleaseOperand(res);
						IF locked THEN Lock(FALSE) END;
						IF ~backend.cooperative & profile THEN ProfilerEnterExit(numberProcedures,FALSE) END;

						reg := NewRegisterOperand(res.op.type);
						Emit(Pop(position,reg));
						Emit(Return(position,reg));
						ReleaseIntermediateOperand(reg);
					ELSE
						Emit(Return(position,res.op));
						ReleaseOperand(res);
					END;
				ELSIF (type IS SyntaxTree.RecordType) OR (type IS SyntaxTree.ArrayType) OR (type IS SyntaxTree.RangeType) OR (type IS SyntaxTree.ComplexType) OR (type IS SyntaxTree.StringType) OR type.IsPointer()
				THEN
					(* return using structured return parameter *)
					ASSERT((type IS SyntaxTree.RecordType) OR (type IS SyntaxTree.RangeType) OR (type IS SyntaxTree.ComplexType) OR (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).form = SyntaxTree.Static)
						OR (type IS SyntaxTree.StringType)
						OR SemanticChecker.IsPointerType(type));
					(* parameter := currentScope(SyntaxTree.ProcedureScope).FindParameter(Global.ReturnParameterName); *)
					parameter :=procedureType.returnParameter;
					ASSERT(parameter # NIL);
					returnTypeOffset := parameter.offsetInBits;
					(*
					IF parameter# NIL THEN
						returnTypeOffset := parameter.offsetInBits + system.SizeOfParameter(parameter);
						INC(returnTypeOffset,(-returnTypeOffset) MOD system.AlignmentOf(system.parameterAlignment,parameter.type));
					ELSE
						returnTypeOffset := system.offsetFirstParameter
					END;
					*)
					left := IntermediateCode.Memory(addressType,fp,ToMemoryUnits(system,returnTypeOffset));

					IF type IS SyntaxTree.RangeType THEN
						(* array range type *)
						Evaluate(expression, right);

						MakeMemory(mem, left, IntermediateCode.GetType(system, system.lenType), 0);
						Emit(Mov(position,mem, right.op)); (* first *)
						ReleaseIntermediateOperand(mem);

						MakeMemory(mem, left, IntermediateCode.GetType(system, system.lenType), ToMemoryUnits(system, system.SizeOf(system.lenType)));
						Emit(Mov(position,mem, right.tag)); (* last *)
						ReleaseIntermediateOperand(mem);

						MakeMemory(mem, left, IntermediateCode.GetType(system, system.lenType), 2 * ToMemoryUnits(system, system.SizeOf(system.lenType)));
						Emit(Mov(position,mem, right.extra)); (* step *)
						ReleaseIntermediateOperand(mem);

						ReleaseOperand(right);
					ELSIF type IS SyntaxTree.ComplexType THEN
						Evaluate(expression, right);
						componentType := type(SyntaxTree.ComplexType).componentType;

						MakeMemory(mem, left, IntermediateCode.GetType(system, componentType), 0);
						Emit(Mov(position,mem, right.op)); (* real part *)
						ReleaseIntermediateOperand(mem);

						MakeMemory(mem, left, IntermediateCode.GetType(system, componentType), ToMemoryUnits(system, system.SizeOf(componentType)));
						Emit(Mov(position,mem, right.tag)); (* imaginary part *)
						ReleaseIntermediateOperand(mem);

						ReleaseOperand(right);
					ELSE (* covers cases: pointer / record / array *)
						parameter := procedureType.returnParameter;
						checker.SetCurrentScope(currentScope);
						ASSERT(parameter # NIL);
						parameterDesignator := checker.NewSymbolDesignator(expression.position,NIL,NIL, parameter);
						Assign(parameterDesignator,expression);
					END;
					ReleaseIntermediateOperand(left);
					IF locked THEN Lock(FALSE) END;
					IF ~backend.cooperative & profile THEN ProfilerEnterExit(numberProcedures,FALSE) END;
				ELSIF (type IS SyntaxTree.MathArrayType) OR (type IS SyntaxTree.ProcedureType) THEN
					parameter := procedureType.returnParameter;
					checker.SetCurrentScope(currentScope);

					IF parameter = NIL THEN
						Error(procedure.position, "structured return of parameter of procedure not found");
					ELSE
						parameterDesignator := checker.NewSymbolDesignator(expression.position,NIL,NIL, parameter);
						Assign(parameterDesignator,expression);
					END;
					IF locked THEN Lock(FALSE) END;

					IF ~backend.cooperative & profile THEN ProfilerEnterExit(numberProcedures,FALSE) END;
				ELSE
					HALT(200);
				END;
			ELSE
				IF locked THEN Lock(FALSE) END;
				IF ~backend.cooperative & profile THEN ProfilerEnterExit(numberProcedures,FALSE) END;
			END;

			IF backend.cooperative THEN
				BrL(exitLabel);
			ELSE
				callingConvention := procedureType.callingConvention;
				IF callingConvention = SyntaxTree.WinAPICallingConvention THEN
					parametersSize := ProcedureParametersSize(backend.system,procedure);
				ELSE
					parametersSize := 0;
				END;

				EmitLeave(section, position,procedure, callingConvention);
				Emit(Exit(position,procedure.type(SyntaxTree.ProcedureType).pcOffset,callingConvention, parametersSize));
			END;
			IF Trace THEN TraceExit("VisitReturnStatement") END;
		END ReturnStatement;

		PROCEDURE MakeAwaitProcedure(x: SyntaxTree.AwaitStatement): SyntaxTree.Procedure;
		VAR procedure: SyntaxTree.Procedure; procedureType: SyntaxTree.ProcedureType; procedureScope: SyntaxTree.ProcedureScope;
			identifier: SyntaxTree.Identifier; body: SyntaxTree.Body; returnStatement : SyntaxTree.ReturnStatement;
			statements: SyntaxTree.StatementSequence;
			name, suffix: SyntaxTree.IdentifierString;
		BEGIN
			Strings.IntToStr(awaitProcCounter,suffix);
			Strings.Concat("@AwaitProcedure",suffix,name);
			identifier := SyntaxTree.NewIdentifier(name);
			INC(awaitProcCounter);
			ASSERT(currentScope IS SyntaxTree.ProcedureScope);
			procedureScope := SyntaxTree.NewProcedureScope(currentScope);
			ASSERT(procedureScope.outerScope IS SyntaxTree.ProcedureScope);
			procedure := SyntaxTree.NewProcedure(x.position,identifier,procedureScope);
			procedure.SetAccess(SyntaxTree.Hidden);
			procedure.SetScope(currentScope);
			procedureType := SyntaxTree.NewProcedureType(x.position,currentScope);
			procedureType.SetReturnType(system.booleanType);
			procedure.SetType(procedureType);
			body := SyntaxTree.NewBody(x.position,procedureScope);
			procedureScope.SetBody(body);
			returnStatement := SyntaxTree.NewReturnStatement(x.position,body);
			returnStatement.SetReturnValue(x.condition);
			statements := SyntaxTree.NewStatementSequence();
			statements.AddStatement(returnStatement);
			body.SetStatementSequence(statements);
			currentScope.AddProcedure(procedure);
			RETURN procedure
		END MakeAwaitProcedure;

		PROCEDURE AwaitStatement(x: SyntaxTree.AwaitStatement);
		VAR proc: SyntaxTree.Procedure; res: IntermediateCode.Operand; symbol: Sections.Section;
			call: IntermediateCode.Operand; label, startL, trueL: Label; name: Basic.SegmentedName;
			result: Operand;
		BEGIN
			IF Trace THEN TraceEnter("VisitAwaitStatement") END;
			IF profile THEN ProfilerEnterExit(numberProcedures, FALSE) END;

			IF backend.cooperative THEN
				startL := NewLabel();
				trueL := NewLabel();
				SetLabel(startL);
				Condition(x.condition,trueL,TRUE);
				PushSelfPointer();
				CallThis(position,"ExclusiveBlocks","Await",1);
				BrL(startL);
				SetLabel(trueL);
				PushSelfPointer();
				CallThis(position,"ExclusiveBlocks","FinalizeAwait",1);
			ELSE
				proc := MakeAwaitProcedure(x);
				Emit(Push(position,fp));
				GetCodeSectionNameForSymbol(proc,name);
				symbol := NewSection(module.allSections, Sections.CodeSection, name,proc,commentPrintout # NIL);
				IntermediateCode.InitAddress(call,addressType,name, GetFingerprint(proc), 0);
				res := NewRegisterOperand(IntermediateCode.GetType(system,system.booleanType));
				Emit(Call(position,call,ProcParametersSize(proc)));
				Emit(Result(position,res));
				(*
				AcquireThisRegister(IntermediateCode.GetType(system,system.booleanType),IntermediateCode.Result);
				IntermediateCode.InitRegister(res,IntermediateCode.GetType(system,system.booleanType),IntermediateCode.Result);
				*)
				InitOperand(result,ModeValue);
				result.op := res;
				label := NewLabel();
				BreqL(label, result.op, SELF.true);
				ReleaseOperand(result);
				symbol := NewSection(module.allSections, Sections.CodeSection, name,proc,commentPrintout # NIL);
				IntermediateCode.InitAddress(res, addressType, name,GetFingerprint(proc), 0);
				Emit(Push(position,res));
				Emit(Push(position,fp));
				PushSelfPointer();
				Emit(Push(position,nil));
				CallThis(position,"Objects","Await",4);
				SetLabel(label);
			END;

			IF profile THEN ProfilerEnterExit(numberProcedures, TRUE) END;

			IF Trace THEN TraceExit("VisitAwaitStatement") END;
		END AwaitStatement;

		PROCEDURE StatementSequence(x: SyntaxTree.StatementSequence);
		VAR statement: SyntaxTree.Statement;  i: LONGINT; (* pos: LONGINT; *)
		BEGIN
			FOR i := 0 TO x.Length() - 1 DO
				statement := x.GetStatement( i );
				Statement(statement);
				IF cooperativeSwitches & (section.pc - lastSwitchPC > 1000) THEN EmitCooperativeSwitch END;
			END;
		END StatementSequence;

		PROCEDURE PushSelfPointer;
		VAR scope: SyntaxTree.Scope;  op: Operand; moduleSection: IntermediateCode.Section; moduleOffset, parametersSize: LONGINT; procedure: SyntaxTree.Procedure;
			procedureType: SyntaxTree.ProcedureType;
		BEGIN
			scope := currentScope;
			WHILE(scope.outerScope IS SyntaxTree.ProcedureScope) DO
				scope := scope.outerScope;
			END;
			IF scope.outerScope IS SyntaxTree.ModuleScope THEN
				moduleSection := meta.ModuleSection();
				IF backend.cooperative THEN
					moduleOffset := 0;
				ELSE
					moduleOffset := moduleSection.pc;
				END;
				op.op := IntermediateCode.Address(addressType, moduleSection.name, GetFingerprint(moduleSection.symbol), moduleOffset);
			ELSE
				GetBaseRegister(op.op,currentScope,scope);
				procedure := scope(SyntaxTree.ProcedureScope).ownerProcedure;
				procedureType := procedure.type(SyntaxTree.ProcedureType);
				parametersSize := ProcParametersSize(procedure);
				IntermediateCode.AddOffset(op.op,ToMemoryUnits(system,addressType.sizeInBits)*(procedureType.parametersOffset+1)+parametersSize);
				IF backend.cooperative THEN
					IntermediateCode.AddOffset(op.op,ToMemoryUnits(system,addressType.sizeInBits));
				END;
				IntermediateCode.MakeMemory(op.op,addressType);
			END;
			Emit(Push(position,op.op));
			ReleaseOperand(op);
		END PushSelfPointer;

		PROCEDURE Lock(lock: BOOLEAN);
		BEGIN
			IF Trace THEN TraceEnter("Lock") END;
			IF profile THEN ProfilerEnterExit(numberProcedures, FALSE) END;
			CheckRegistersFree(); (* no register may be in use as operands should not be preserved over the lock / unlock boundary *)
			ASSERT(modifyAssignmentCounter = 0);
			IF dump # NIL THEN
				IF lock THEN dump.String("lock") ELSE dump.String("unlock") END;
				dump.Ln;dump.Update;
			END;
			PushSelfPointer;
			IF backend.cooperative THEN
				Emit(Push(position,IntermediateCode.Immediate(sizeType, 1)));
				IF lock THEN CallThis(position,"ExclusiveBlocks","Enter",2)
				ELSE CallThis(position,"ExclusiveBlocks","Exit",2);
				END;
			ELSE
				Emit(Push(position,true));
				IF lock THEN CallThis(position,"Objects","Lock",2)
				ELSE CallThis(position,"Objects","Unlock",2);
				END;
			END;
			IF profile THEN ProfilerEnterExit(numberProcedures, TRUE) END;
			IF Trace THEN TraceExit("Lock") END;
		END Lock;

		PROCEDURE StatementBlock(x: SyntaxTree.StatementBlock);
		VAR previouslyUnchecked, previouslyUntracked, previouslyCooperativeSwitches: BOOLEAN; end: Label;
			prevScope: SyntaxTree.Scope;
		BEGIN
			IF Trace THEN TraceEnter("VisitStatementBlock") END;
			IF emitLabels THEN Emit(LabelInstruction(x.position)) END;

			previouslyUnchecked := isUnchecked;
			previouslyUntracked := isUntracked;
			isUnchecked := isUnchecked OR x.isUnchecked;
			isUntracked := isUntracked OR x.isUntracked;
			previouslyCooperativeSwitches := cooperativeSwitches;
			cooperativeSwitches := cooperativeSwitches & ~x.isUncooperative;
			prevScope := currentScope;
			IF x.scope # NIL THEN currentScope := x.scope END;

			IF x.isExclusive THEN Lock(TRUE); ASSERT(~locked);  locked := TRUE; END;
			IF x.statements # NIL THEN
				StatementSequence(x.statements);
			END;

			IF (x IS SyntaxTree.Body) THEN
				IF (x(SyntaxTree.Body).finally # NIL) THEN
					section.SetFinally(section.pc);
					StatementSequence(x(SyntaxTree.Body).finally)
				ELSIF x.isExclusive THEN
					end := NewLabel();
					BrL(end);
					section.SetFinally(section.pc);
					Lock(FALSE);
					EmitTrap(position,RethrowTrap);
					SetLabel(end);
				END;
			END;

			IF x.isExclusive THEN Lock(FALSE); ASSERT(locked); locked := FALSE; END;
			isUnchecked := previouslyUnchecked;
			isUntracked := previouslyUntracked;
			cooperativeSwitches := previouslyCooperativeSwitches;
			currentScope := prevScope;
			IF Trace THEN TraceExit("VisitStatementBlock") END;
		END StatementBlock;

		PROCEDURE Code(x: SyntaxTree.Code);
		BEGIN
			Emit(Asm(x.position,x.sourceCode, currentScope));
			IF Trace THEN TraceExit("VisitCode") END;
		END Code;

		PROCEDURE ProcParametersSize(procedure: SyntaxTree.Procedure): LONGINT;
		BEGIN
			RETURN ProcedureParametersSize(system, procedure);
		END ProcParametersSize;

		PROCEDURE ParameterCopies(x: SyntaxTree.ProcedureType);
		VAR parameter: SyntaxTree.Parameter; type, base: SyntaxTree.Type;
			op: Operand; temp,size,par,dst, length,null: IntermediateCode.Operand;
			const, call: IntermediateCode.Operand;
			parameterDesignator: SyntaxTree.Expression;
			saved: RegisterEntry;
			name: Basic.SegmentedName;
		BEGIN
			IF Trace THEN TraceEnter("ParameterCopies") END;
			parameter := x.firstParameter;
			WHILE parameter # NIL DO
				IF parameter.kind = SyntaxTree.ValueParameter THEN
					type := parameter.type.resolved;
					IF IsOpenArray(type) THEN
						DesignateParameter(parameter, op); 
						IF backend.cooperative & parameter.NeedsTrace() THEN
							length := GetArrayLength(type, op.tag);
							size := NewRegisterOperand(addressType);
							base := ArrayBaseType(type);
							const := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.SizeOf(base)));
							Emit(Mul(position, size, length, const));

							dst := NewRegisterOperand (addressType);
							Emit(Mov(position, dst, size));
							const := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,-system.addressSize)); (* alignment *)
							Emit(Sub(position,dst,sp,dst));
							Emit(And(position,dst,dst,const));
							Emit(Mov(position,sp,dst));
							par := fp;
							IntermediateCode.AddOffset(par,ToMemoryUnits(system,parameter.offsetInBits));
							IntermediateCode.InitImmediate(null, byteType, 0);
							Emit(Fill(position, dst, size, null));
							ReleaseIntermediateOperand(dst);
							ReleaseIntermediateOperand(length);
							SaveRegisters();ReleaseUsedRegisters(saved);
							(* register dst has been freed before SaveRegisters already *)
							base := ArrayBaseType(type);
							(* assign method of open array *)
							IF base.IsRecordType() THEN
								Emit (Push(position, length));
								Emit (Push(position, dst));
								Emit (Push(position, op.op));
								GetRecordTypeName (base.resolved(SyntaxTree.RecordType),name);
								Basic.SuffixSegmentedName (name, Basic.MakeString ("@Array"));
								Basic.SuffixSegmentedName (name, Basic.MakeString ("@Assign"));
								IntermediateCode.InitAddress(call, addressType, name , 0, 0);
								Emit(Call(position,call,ToMemoryUnits(system, 3*system.addressSize)));
							ELSIF base.resolved IS SyntaxTree.ProcedureType THEN (* array of delegates *)
								Emit (Push(position,length));
								Emit (Push(position, dst));
								Emit (Push(position, length));
								Emit (Push(position, op.op));
								CallThis(position,"GarbageCollector","AssignDelegateArray", 4);
							ELSE
								Emit (Push(position, length));
								Emit (Push(position, dst));
								Emit (Push(position, length));
								Emit (Push(position, op.op));
								CallThis(position,"GarbageCollector","AssignPointerArray", 4);
								ASSERT(ArrayBaseType(type).IsPointer());
							END;
							RestoreRegisters(saved);
						ELSE
							temp := GetDynamicSize(type,op.tag);
							ReuseCopy(size,temp);
							ReleaseIntermediateOperand(temp);
							const := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,-system.addressSize)); (* alignment *)
							Emit(Sub(position,size,sp,size));
							Emit(And(position,size,size,const));
							Emit(Mov(position,sp,size));
							par := fp;
							IntermediateCode.AddOffset(par,ToMemoryUnits(system,parameter.offsetInBits));
							ReleaseIntermediateOperand(size);
							size := GetDynamicSize(type,op.tag);
						END;

						Emit(Copy(position,sp,op.op,size));
						ReleaseIntermediateOperand(size);
						ReleaseOperand(op);
						IntermediateCode.MakeMemory(par,addressType);
						Emit(Mov(position,par,sp));
					ELSIF (type IS SyntaxTree.MathArrayType) & (type(SyntaxTree.MathArrayType).form # SyntaxTree.Static) THEN
						checker.SetCurrentScope(currentScope);
						parameterDesignator := checker.NewSymbolDesignator(position,NIL, NIL,parameter);
						Assign(parameterDesignator,parameterDesignator);
					END;
				END;
				parameter := parameter.nextParameter;
			END;
			IF Trace THEN TraceExit("ParameterCopies") END;
		END ParameterCopies;

		PROCEDURE InitVariables(scope: SyntaxTree.Scope);
		VAR x: SyntaxTree.Variable;
		BEGIN
			x := scope.firstVariable;
			WHILE x # NIL DO
				InitVariable(x,FALSE);
				x := x.nextVariable;
			END;
		END InitVariables;

		PROCEDURE GetFingerprint(symbol: SyntaxTree.Symbol): Basic.Fingerprint;
		BEGIN
			IF (symbol # NIL) THEN
				RETURN fingerprinter.SymbolFP(symbol).public
			ELSE
				RETURN 0
			END;
		END GetFingerprint;

		PROCEDURE Body(x: SyntaxTree.Body; scope: SyntaxTree.Scope; ir: IntermediateCode.Section; moduleBody: BOOLEAN);
		VAR prevScope: SyntaxTree.Scope; procedureType: SyntaxTree.ProcedureType; procedure: SyntaxTree.Procedure;
			cellScope: SyntaxTree.CellScope; op: Operand; string: SyntaxTree.IdentifierString;
			saved: RegisterEntry; left, right: IntermediateCode.Operand;
			name: Basic.SegmentedName;
			offset: LONGINT;
			par: SyntaxTree.Parameter;
			var: SyntaxTree.Variable;
			src, dest: Operand;
			symbol: SyntaxTree.Symbol;
			name0: ARRAY 256 OF CHAR;
		BEGIN
			IF Trace THEN TraceEnter("Body") END;
			ReleaseUsedRegisters(saved); (* just in case ... *)
			section := ir;
			exitLabel := NewLabel ();
			IF moduleBody THEN moduleBodySection := section END;
			IF ir.comments # NIL THEN
				commentPrintout := Printout.NewPrinter(ir.comments,Printout.SourceCode,FALSE);
				commentPrintout.SingleStatement(TRUE);
				dump := ir.comments;
			ELSE
				commentPrintout := NIL;
				dump := NIL;
			END;

			prevScope := currentScope;
			currentScope := scope;

			lastSwitchPC := 0;
			cooperativeSwitches := backend.cooperative;

			procedure := scope(SyntaxTree.ProcedureScope).ownerProcedure;
			procedureType := procedure.type(SyntaxTree.ProcedureType);
			IF x # NIL THEN
				IF emitLabels THEN Emit(LabelInstruction(x.position)) END;
				IF profile & (x.code = NIL) THEN (* do not profile assembler code sections *)
					IF moduleBody THEN
						ProfilerInit();
					ELSE
						Basic.SegmentedNameToString(ir.name, string);
						ProfilerAddProcedure(numberProcedures,string);
						ProfilerEnterExit(numberProcedures,TRUE);
					END;
				END;

				IF moduleBody & (operatorInitializationCodeSection # NIL) THEN
					Emit(Call(position,IntermediateCode.Address(addressType, operatorInitializationCodeSection.name, GetFingerprint(operatorInitializationCodeSection.symbol),  0), 0))
				END;

				section.SetPositionOrAlignment(procedure.fixed, procedure.alignment);
				IF (scope.outerScope # NIL) & (scope.outerScope IS SyntaxTree.CellScope) THEN
					cellScope := scope.outerScope(SyntaxTree.CellScope);
					IF procedure = cellScope.bodyProcedure THEN
						IF (cellScope.constructor # NIL) & ~backend.cellsAreObjects THEN
							StaticCallOperand(cellScope.constructor, op);
							Emit(Call(position,op.op,0));
						END;
					END;
				END;

				var := scope.firstVariable;
				WHILE var # NIL DO
					IF var.preferRegister THEN
						IF var.registerNumber < 0 THEN
							var.RegisterNumber(AcquireRegister(IntermediateCode.GetType(system,var.type),IntermediateCode.GeneralPurposeRegister));
						END;
					END;
					var := var.nextVariable;
				END;
				InitVariables(scope);
				par := procedureType.firstParameter;
				WHILE par # NIL DO
					IF par.preferRegister THEN
						IF par.registerNumber < 0 THEN
							par.PreferRegister(FALSE);
							Symbol(par, src);
							MakeMemory(src.op,src.op,IntermediateCode.GetType(system,par.type),0);
							par.PreferRegister(TRUE);
							par.RegisterNumber(AcquireRegister(IntermediateCode.GetType(system,par.type),IntermediateCode.GeneralPurposeRegister));
							Symbol(par, dest);
							Emit(Mov(par.position, dest.op, src.op));
							ReleaseOperand(src);
							ReleaseOperand(dest);
						END;
					END;
					par := par.nextParameter;
				END;




				IF backend.preciseGC & (x.code = NIL) & (~procedureType.noPAF) & ~procedure.isEntry & ~procedure.isExit THEN
					GetCodeSectionNameForSymbol(procedure, name);
					Basic.SuffixSegmentedName (name, Basic.MakeString ("@Descriptor"));
					IntermediateCode.InitAddress(right, addressType, name, 0, 0);

					IF ProtectModulesPointers THEN
						offset := ToMemoryUnits(module.system,meta.RecordBaseOffset*module.system.addressSize)+1;
					ELSE
						offset := ToMemoryUnits(module.system, 2 * module.system.addressSize)+1;
					END;

					IntermediateCode.SetOffset(right,offset); (* tag *)
					IntermediateCode.InitMemory(left,addressType,fp,0);
					Emit(Mov(position, left, right));
				END;

				(* must be done after the descriptor is there, otherwise copied parameters are forgotten to be traced *)
				ParameterCopies(procedureType);

				IF x.code = NIL THEN
					StatementBlock(x);
				ELSE
					Code(x.code)
				END;
				IF profile & (x.code = NIL) & ~moduleBody THEN (* do not profile assembler code sections *)
					IF ~backend.cooperative THEN
						ProfilerEnterExit(numberProcedures,FALSE);
					END;
					INC(numberProcedures);
				END;
			END;
			IF backend.cooperative THEN
				IF HasPointers (procedure.procedureScope) THEN CreateResetMethod (procedure.procedureScope) END;
				IF HasPointers (procedure.procedureScope) OR HasVariableParameters (procedure.procedureScope) OR IsNested (procedure) THEN CreateProcedureDescriptor (procedure) END;
			END;
			IF x # NIL THEN
				SELF.position := x.position;
			END;
			EndBasicBlock;

			var := scope.firstVariable;
			WHILE var # NIL DO
				IF var.preferRegister THEN
					Emit(Use(var.position, IntermediateCode.Register(IntermediateCode.GetType(system,var.type),IntermediateCode.GeneralPurposeRegister, var.registerNumber)));
					(* hint for backend that register is in use until here *)
					UnuseRegister(var.registerNumber);
				END;
				var := var.nextVariable;
			END;


			par := procedureType.firstParameter;
			WHILE par # NIL DO
				IF par.preferRegister THEN
					IF par.kind = SyntaxTree.VarParameter THEN
							Symbol(par, src);
							par.PreferRegister(FALSE);
							Symbol(par, dest);
							MakeMemory(dest.op,dest.op,IntermediateCode.GetType(system,par.type),0);
							Emit(Mov(par.position, dest.op, src.op));
							ReleaseOperand(dest);
							ReleaseOperand(src);
					ELSE
						Emit(Use(par.position, IntermediateCode.Register(IntermediateCode.GetType(system,par.type),IntermediateCode.GeneralPurposeRegister, par.registerNumber)));
					END;
					(* hint for backend that register is in use until here *)
					UnuseRegister(par.registerNumber);
				END;
				par := par.nextParameter;
			END;

			IF dump # NIL THEN
			symbol := currentScope.firstSymbol;
			WHILE (symbol # NIL) DO
				symbol.GetName(name0);
				dump.String(name0);
				dump.String("@");
				dump.Int(symbol.offsetInBits DIV 8,1);
				dump.Ln;
				dump.Update;
				symbol := symbol.nextSymbol;
			END;
			END;

			CheckRegistersFree();
			ASSERT(modifyAssignmentCounter = 0);
			currentScope := prevScope;
			IF Trace THEN TraceExit("Body") END;
		END Body;

	END ImplementationEmitter;

	MetaDataGenerator=OBJECT
	VAR
		implementationEmitter: ImplementationEmitter;
		declarationEmitter: DeclarationEmitter;
		module: Sections.Module;
		moduleName: ARRAY 128 OF CHAR;
		moduleNamePool: Basic.HashTableInt;
		moduleNamePoolSection: IntermediateCode.Section;
		modulePointerSection: IntermediateCode.Section;
		modulePointerSizePC: LONGINT;
		modulePointerSectionOffset: LONGINT;
		modulePointers: LONGINT;

		simple: BOOLEAN; (* simple = no module loading, no reflection *)

		RecordBaseOffset: LONGINT;
		MethodTableOffset: LONGINT; (* method table offset from zero *)
		BaseTypesTableOffset: LONGINT;	(* table with all record extensions offset *)
		TypeTags: LONGINT; (* type extension level support *)
		TypeRecordBaseOffset: LONGINT; (* offset of type zero offset (without method entries) *)

		patchInfoPC: LONGINT;
		patchCRC: LONGINT;
	CONST
		EmptyBlockOffset = 2;

		PROCEDURE &InitMetaDataGenerator(implementationEmitter: ImplementationEmitter; declarationEmitter: DeclarationEmitter; simple: BOOLEAN);
		BEGIN
			IF implementationEmitter.backend.cooperative THEN
				TypeTags := MAX(LONGINT);
				BaseTypesTableOffset := 0;
				MethodTableOffset := 2;
				TypeRecordBaseOffset := 0;
				RecordBaseOffset := 0;
			ELSIF simple THEN
				TypeTags := 3; (* only 3 extensions allowed *)
				BaseTypesTableOffset := 1;
				MethodTableOffset := BaseTypesTableOffset+TypeTags;
				TypeRecordBaseOffset := 0;
				RecordBaseOffset := 1;
			ELSE
				TypeTags := 16;
				BaseTypesTableOffset := -2; (* typeInfo and size field *)
				MethodTableOffset := -TypeTags+BaseTypesTableOffset;
				TypeRecordBaseOffset := TypeTags + 2; (* MPO, typeInfo *)
				(* change this when Heaps.HeapBlock is modified *)
				IF implementationEmitter.system.addressType.sizeInBits = 64 THEN
					RecordBaseOffset := 8; (* addresses *)
				ELSE
					RecordBaseOffset := 9; (* addresses *)
				END;
			END;
			SELF.simple := simple;
			SELF.implementationEmitter := implementationEmitter;
			SELF.declarationEmitter := declarationEmitter;
			implementationEmitter.meta := SELF;
			declarationEmitter.meta := SELF;
		END InitMetaDataGenerator;

		PROCEDURE SetModule(module: Sections.Module);
		VAR namePoolOffset,  offset: LONGINT; name: Basic.SegmentedName;
		BEGIN
			SELF.module := module;
			Global.GetModuleName(module.module,moduleName);
			Global.GetSymbolSegmentedName(module.module, name);
			IF ReflectionSupport & ~simple & ~implementationEmitter.backend.cooperative THEN
				NEW(moduleNamePool, 32);
				(*! require GC protection *)
				modulePointerSection := Block("Heaps","ArrayBlockDesc",".@ModulePointerArray", modulePointerSectionOffset);
				IF ProtectModulesPointers THEN
					name := "Heaps.AnyPtr";
					offset := ToMemoryUnits(module.system,TypeRecordBaseOffset*module.system.addressSize);
					(* set base pointer *)
					NamedSymbolAt(modulePointerSection, modulePointerSectionOffset -1, name, NIL, 0, offset);
				END;
				ArrayBlock(modulePointerSection, modulePointerSizePC, "", TRUE);
				modulePointers := 0;

				moduleNamePoolSection := Block("Heaps","SystemBlockDesc",".@ModuleNamePool", namePoolOffset);
				AddPointer(moduleNamePoolSection, namePoolOffset);
			END;
		END SetModule;

		PROCEDURE AddPointer(section: IntermediateCode.Section; offset: LONGINT);
		BEGIN
			IF ~implementationEmitter.backend.cooperative THEN
				NamedSymbol(modulePointerSection, section.name, NIL, offset, 0);
				INC(modulePointers);
				(* optimization hint: this can be done once at the end but for consistency of the first tests we keep it like this *)
				PatchSize(modulePointerSection, modulePointerSizePC, modulePointers);
			END;
		END AddPointer;

		PROCEDURE GetTypeRecordBaseOffset(numberMethods: LONGINT): LONGINT;
		BEGIN
			IF implementationEmitter.backend.cooperative OR simple THEN RETURN 0 ELSE RETURN TypeRecordBaseOffset + numberMethods END;
		END GetTypeRecordBaseOffset;

		PROCEDURE HeapBlock(CONST moduleName, typeName: ARRAY OF CHAR; section: IntermediateCode.Section; dataAdrOffset: LONGINT);
		VAR offset: LONGINT; name: Basic.SegmentedName; symbol: SyntaxTree.Symbol;
		BEGIN
			(* change this when Heaps.HeapBlock is modified *)
			INC(dataAdrOffset,7);

			Info(section,"headerAdr");
			Address(section,0);

			Info(section,"typeDesc");
			symbol := implementationEmitter.GetTypeDescriptor(moduleName,typeName, name);
			offset := ToMemoryUnits(module.system,TypeRecordBaseOffset*module.system.addressSize);
			NamedSymbol(section, name, symbol, 0, offset);

			Info(section,"mark: LONGINT;");
			Longint(section,-1);
			Info(section,"refCount: LONGINT;");
			Longint(section,0);
			(*
			IF module.system.addressType.sizeInBits = 64 THEN Longint(section, 0); INC(dataAdrOffset); END;
			*)

			Info(section,"dataAdr-: ADDRESS");
			Symbol(section,section, dataAdrOffset,0);

			Info(section,"size-: SIZE");
			Address(section,0);

			Info(section,"nextMark: HeapBlock;");
			Address(section,0);
		END HeapBlock;

		PROCEDURE ProtectedHeapBlock(CONST moduleName, typeName: ARRAY OF CHAR; section: IntermediateCode.Section; dataAdrOffset: LONGINT);
		VAR i: LONGINT;
		BEGIN
			INC(dataAdrOffset,14); (*! change this when changing data structure below *)
			HeapBlock(moduleName,typeName,section,dataAdrOffset);
			Info(section,"count*: LONGINT");
			Longint(section,0);
			Info(section,"locked*: BOOLEAN");
			Longint(section,0);
			Info(section,"awaitingLock*: ProcessQueue");
			Address(section,0);
			Address(section,0);
			Info(section,"awaitingCond*: ProcessQueue");
			Address(section,0);
			Address(section,0);
			Info(section,"lockedBy*: ANY");
			Address(section,0);
			Info(section,"waitingPriorities*: ARRAY NumPriorities OF LONGINT");
			Longint(section,1);
			FOR i := 2 TO 6 DO
			Longint(section,0);
			END;
			Info(section,"lock*: ANY");
			Address(section,0);
		END ProtectedHeapBlock;

		PROCEDURE Info(section: IntermediateCode.Section; CONST s: ARRAY OF CHAR);
		BEGIN
			IF section.comments # NIL THEN section.comments.String(s); section.comments.Ln; section.comments.Update END;
		END Info;

		PROCEDURE Address(section: IntermediateCode.Section; value: ADDRESS);
		VAR op: IntermediateCode.Operand;
		BEGIN
			IntermediateCode.InitImmediate(op,IntermediateCode.GetType(module.system, module.system.addressType),value);
			section.Emit(Data(Basic.invalidPosition,op));
		END Address;

		PROCEDURE Size(section: IntermediateCode.Section; value: SIZE);
		VAR op: IntermediateCode.Operand;
		BEGIN
			IntermediateCode.InitImmediate(op,IntermediateCode.GetType(module.system, module.system.sizeType),value);
			section.Emit(Data(Basic.invalidPosition,op));
		END Size;

		PROCEDURE Set(section: IntermediateCode.Section; value: Basic.Set);
		VAR op: IntermediateCode.Operand;
		BEGIN
			IntermediateCode.InitImmediate(op,IntermediateCode.GetType(module.system, module.system.setType),SYSTEM.VAL(Basic.Integer,value));
			section.Emit(Data(Basic.invalidPosition,op));
		END Set;

		PROCEDURE Longint(section: IntermediateCode.Section; value: LONGINT);
		VAR op: IntermediateCode.Operand;
		BEGIN
			IntermediateCode.InitImmediate(op,IntermediateCode.GetType(module.system, module.system.longintType),value);
			section.Emit(Data(Basic.invalidPosition,op));
		END Longint;

		PROCEDURE Hugeint(section: IntermediateCode.Section; value: HUGEINT);
		VAR op: IntermediateCode.Operand;
		BEGIN
			IntermediateCode.InitImmediate(op,IntermediateCode.GetType(module.system, module.system.hugeintType),value);
			section.Emit(Data(Basic.invalidPosition,op));
		END Hugeint;

		PROCEDURE PatchSize(section: IntermediateCode.Section; pc: LONGINT; value: LONGINT);
		VAR op,noOperand: IntermediateCode.Operand;
		BEGIN
			IntermediateCode.InitOperand(noOperand);
			IntermediateCode.InitImmediate(op,IntermediateCode.GetType(module.system, module.system.sizeType),value);
			section.PatchOperands(pc,op,noOperand,noOperand);
		END PatchSize;

		PROCEDURE PatchLongint(section: IntermediateCode.Section; pc: LONGINT; value: LONGINT);
		VAR op,noOperand: IntermediateCode.Operand;
		BEGIN
			IntermediateCode.InitOperand(noOperand);
			IntermediateCode.InitImmediate(op,IntermediateCode.GetType(module.system, module.system.longintType),value);
			section.PatchOperands(pc,op,noOperand,noOperand);
		END PatchLongint;

		PROCEDURE PatchSymbol(section: IntermediateCode.Section; pc: LONGINT; name: Basic.SegmentedName; symbol: SyntaxTree.Symbol; virtualOffset, realOffset: LONGINT);
		VAR op, noOperand: IntermediateCode.Operand;
		BEGIN
			IntermediateCode.InitOperand(noOperand);
			IntermediateCode.InitAddress(op, IntermediateCode.GetType(module.system, module.system.addressType), name,implementationEmitter.GetFingerprint(symbol), virtualOffset);
			section.PatchOperands(pc,op,noOperand,noOperand);
		END PatchSymbol;

		PROCEDURE Boolean(section: IntermediateCode.Section; value: BOOLEAN);
		VAR op: IntermediateCode.Operand; intValue: LONGINT;
		BEGIN
			IF value = FALSE THEN intValue := 0 ELSE intValue :=1 END;
			IntermediateCode.InitImmediate(op,IntermediateCode.GetType(module.system, module.system.booleanType),intValue);
			section.Emit(Data(Basic.invalidPosition,op));
		END Boolean;

		PROCEDURE Char(section: IntermediateCode.Section; char: CHAR);
		VAR op: IntermediateCode.Operand;
		BEGIN
			IntermediateCode.InitImmediate(op,IntermediateCode.GetType(module.system, module.system.characterType),ORD(char));
			section.Emit(Data(Basic.invalidPosition,op));
		END Char;

		PROCEDURE String(section: IntermediateCode.Section; CONST str: ARRAY OF CHAR);
		VAR i: LONGINT;
		BEGIN
			Info(section,str);
			i := 0;
			WHILE(str[i] # 0X) DO
				Char(section,str[i]);
				INC(i);
			END;
			Char(section,0X);
		END String;

		PROCEDURE String0(section: IntermediateCode.Section; str: StringPool.Index);
		VAR s: Basic.SectionName;
		BEGIN
			StringPool.GetString(str, s);
			String(section, s);
		END String0;

		PROCEDURE NamedSymbol(section: IntermediateCode.Section; name: Basic.SegmentedName; symbol: SyntaxTree.Symbol; virtualOffset, realOffset: LONGINT);
		VAR op: IntermediateCode.Operand;
		BEGIN
			IntermediateCode.InitAddress(op, IntermediateCode.GetType(module.system, module.system.addressType), name,implementationEmitter.GetFingerprint(symbol), virtualOffset);
			IntermediateCode.SetOffset(op,realOffset);
			section.Emit(Data(Basic.invalidPosition,op));
		END NamedSymbol;

		PROCEDURE NamedSymbolAt(section: IntermediateCode.Section; pc: LONGINT; name: Basic.SegmentedName; symbol: SyntaxTree.Symbol; virtualOffset, realOffset: LONGINT);
		VAR op: IntermediateCode.Operand;
		BEGIN
			IntermediateCode.InitAddress(op, IntermediateCode.GetType(module.system, module.system.addressType), name,implementationEmitter.GetFingerprint(symbol), virtualOffset);
			IntermediateCode.SetOffset(op,realOffset);
			section.EmitAt(pc, Data(Basic.invalidPosition,op));
		END NamedSymbolAt;

		PROCEDURE Symbol(section: IntermediateCode.Section; symbol: Sections.Section; virtualOffset, realOffset: LONGINT);
		BEGIN
			IF symbol= NIL THEN
				Address( section, realOffset);
				ASSERT(virtualOffset = 0);
			ELSE
				NamedSymbol(section, symbol.name, symbol.symbol, virtualOffset, realOffset)
			END;
		END Symbol;

		(* OutPointers delivers
			{pointerOffset}
		*)
		PROCEDURE Pointers(offset: LONGINT; symbol: Sections.Section; section: IntermediateCode.Section; type: SyntaxTree.Type; VAR numberPointers: LONGINT);
		VAR variable: SyntaxTree.Variable; i,n,size: LONGINT; base: SyntaxTree.Type; property: SyntaxTree.Property; parameter: SyntaxTree.Parameter;
		BEGIN
			type := type.resolved;
			IF (type IS SyntaxTree.AnyType) OR (type IS SyntaxTree.ObjectType) THEN
				Symbol(section, symbol, 0, (offset )); INC(numberPointers);
				IF Trace THEN D.Str("ptr at offset="); D.Int(offset,1); D.Ln; END;
			ELSIF (type IS SyntaxTree.PortType) & implementationEmitter.backend.cellsAreObjects THEN
				Symbol(section, symbol, 0, offset); INC(numberPointers);
			ELSIF (type IS SyntaxTree.PointerType) & type.NeedsTrace() THEN
				Symbol(section, symbol, 0, (offset )); INC(numberPointers);
				IF Trace THEN D.Str("ptr at offset="); D.Int(offset,1);D.Ln;  END;
			ELSIF (type IS SyntaxTree.ProcedureType) & (type(SyntaxTree.ProcedureType).isDelegate) THEN
				Symbol(section, symbol, 0, (offset )+ToMemoryUnits(module.system,module.system.addressSize)); INC(numberPointers);
				IF Trace THEN D.Str("ptr at offset="); D.Int(offset+ToMemoryUnits(module.system,module.system.addressSize),1); END;
			ELSIF (type IS SyntaxTree.RecordType) THEN
				(* never treat a record like a pointer, even if the pointer field is set! *)
				WITH type: SyntaxTree.RecordType DO
					base := type.GetBaseRecord();
					IF base  # NIL THEN
						Pointers(offset,symbol,section, base,numberPointers);
					END;
					variable := type.recordScope.firstVariable;
					WHILE(variable # NIL) DO
						IF ~(variable.untraced) THEN
							Pointers(offset+ToMemoryUnits(module.system,variable.offsetInBits), symbol,  section, variable.type,numberPointers);
						END;
						variable := variable.nextVariable;
					END;
				END;
			ELSIF (type IS SyntaxTree.CellType) THEN
				WITH type: SyntaxTree.CellType DO
					base := type.GetBaseRecord();
					IF base  # NIL THEN
						Pointers(offset,symbol,section, base,numberPointers);
					END;
					variable := type.cellScope.firstVariable;
					WHILE(variable # NIL) DO
						IF ~(variable.untraced) THEN
							Pointers(offset+ToMemoryUnits(module.system,variable.offsetInBits), symbol,  section, variable.type,numberPointers);
						END;
						variable := variable.nextVariable;
					END;
					property := type.firstProperty;
					WHILE(property # NIL) DO
						IF ~(property.untraced) THEN
							Pointers(offset+ToMemoryUnits(module.system,property.offsetInBits), symbol,  section, property.type,numberPointers);
						END;
						property := property.nextProperty;
					END;
					parameter := type.firstParameter;
					WHILE(parameter # NIL) DO
						IF ~(parameter.untraced) THEN
							Pointers(offset+ToMemoryUnits(module.system,parameter.offsetInBits), symbol,  section, parameter.type,numberPointers);
						END;
						parameter := parameter.nextParameter;
					END;
				END;
			ELSIF (type IS SyntaxTree.ArrayType) THEN
				WITH type: SyntaxTree.ArrayType DO
					IF type.form= SyntaxTree.Static THEN
						n := type.staticLength;
						base := type.arrayBase.resolved;
						WHILE(base IS SyntaxTree.ArrayType) DO
							type := base(SyntaxTree.ArrayType);
							n := n* type.staticLength;
							base := type.arrayBase.resolved;
						END;
						size := ToMemoryUnits(module.system,module.system.AlignedSizeOf(base));
						IF SemanticChecker.ContainsPointer(base) & base.NeedsTrace()  THEN
							ASSERT(n<1000000); (* not more than one million pointers on the stack ... *)
							FOR i := 0 TO n-1 DO
								Pointers(offset+i*size, symbol, section, base,numberPointers);
							END;
						END;
					ELSE
						Symbol( section, symbol, 0, (offset )); INC(numberPointers);
						IF Trace THEN D.Str("ptr at offset="); D.Int(offset,1); D.Ln; END;
					END;
				END;
			ELSIF (type IS SyntaxTree.MathArrayType) THEN
				WITH type: SyntaxTree.MathArrayType DO
					IF type.form = SyntaxTree.Static THEN
						n := type.staticLength;
						base := type.arrayBase.resolved;
						WHILE(base IS SyntaxTree.MathArrayType) DO
							type := base(SyntaxTree.MathArrayType);
							n := n* type.staticLength;
							base := type.arrayBase.resolved;
						END;
						size := ToMemoryUnits(module.system,module.system.AlignedSizeOf(base));
						IF SemanticChecker.ContainsPointer(base) THEN
							ASSERT(n<1000000); (* not more than one million pointers on the stack ... *)
							FOR i := 0 TO n-1 DO
								Pointers(offset+i*size, symbol,   section, base,numberPointers);
							END;
						END;
					ELSE
						Symbol(section, symbol, 0, (offset )); INC(numberPointers); (* GC relevant pointer is at offset 0 *)
						IF Trace THEN D.Str("ptr at offset="); D.Int(offset,1); D.Ln; END;
					END
				END;
			(* ELSE no pointers in type *)
			END;
		END Pointers;

		PROCEDURE EnterDynamicName(source: IntermediateCode.Section; CONST name: ARRAY OF CHAR; index: LONGINT; pool: Basic.HashTableInt): LONGINT;
		VAR position,i: LONGINT; ch: CHAR;
		BEGIN
			IF pool.Has(index) THEN
				RETURN pool.GetInt(index)
			ELSE
				position := source.pc;
				pool.PutInt(index, position);
				Info(source, name);
				i := 0;
				REPEAT
					ch := name[i]; INC(i);
					Char( source, ch);
				UNTIL ch = 0X;
			END;
			RETURN position;
		END EnterDynamicName;

		PROCEDURE DynamicName(source: IntermediateCode.Section; index: StringPool.Index; pool: Basic.HashTableInt): LONGINT;
		VAR name: Basic.SectionName; position: LONGINT;
		BEGIN
			IF pool.Has(index) THEN
				RETURN pool.GetInt(index)
			ELSE
				StringPool.GetString(index, name);
				position := EnterDynamicName(source,name,index, pool);
			END;
			RETURN position;
		END DynamicName;

		PROCEDURE NamedBlock(CONST mName, typeName: ARRAY OF CHAR; name: Basic.SegmentedName; VAR offset: LONGINT): IntermediateCode.Section;
		VAR section: IntermediateCode.Section;
		BEGIN
			section := IntermediateCode.NewSection(module.allSections, Sections.ConstSection, name, NIL, declarationEmitter.dump);
			IF implementationEmitter.backend.cooperative THEN
				Info(section, "TypeDescriptor");
				Basic.ToSegmentedName("BaseTypes.Array", name);
				NamedSymbol(section, name,NIL, 0, 0);
				BasePointer(section);
				offset := 0;
			ELSE
				IF ProtectModulesPointers THEN
					HeapBlock(mName,typeName,section,2);
				END;
				Info(section, "HeapBlock");

				IF ProtectModulesPointers THEN
					Symbol(section,section,2,0);
				ELSE
					Address(section,0);
				END;

				Info(section, "TypeDescriptor");
				Address(section,0);

				offset := section.pc;
			END;
			RETURN section
		END NamedBlock;

		PROCEDURE Block(CONST mName, typeName, suffix: ARRAY OF CHAR; VAR offset: LONGINT): IntermediateCode.Section;
		VAR name: ARRAY 128 OF CHAR; pooledName: Basic.SegmentedName;
		BEGIN
			COPY(moduleName,name);
			Strings.Append(name,suffix);
			Basic.ToSegmentedName(name, pooledName);
			RETURN NamedBlock(mName, typeName, pooledName, offset);
		END Block;

		PROCEDURE ArrayBlock(source: IntermediateCode.Section; VAR sizePC: LONGINT;  CONST baseType: ARRAY OF  CHAR; hasPointer: BOOLEAN);
		VAR name: Basic.SegmentedName;
		BEGIN
			Info(source,"ArrayHeader");
			IF implementationEmitter.backend.cooperative THEN
				sizePC := source.pc;
				Address(source,0);
				NamedSymbol(source,source.name,NIL,0,ToMemoryUnits(implementationEmitter.system,(BaseArrayTypeSize + 1)*implementationEmitter.addressType.sizeInBits));
				IF baseType # "" THEN
					Basic.ToSegmentedName(baseType, name);
					NamedSymbol(source, name,NIL, 0, 0);
				ELSE
					Address(source,0);
				END;
				Address(source,0);
			ELSE
				Address(source,0);
				Address(source,0);
				(* first pointer for GC *)
				IF hasPointer THEN
					(* points to first element in the array, this is NOT the base type descriptor *)
					NamedSymbol(source,source.name, NIL,source.pc+2,0);
				ELSE
					Address(source,0);
				END;
				sizePC := source.pc;
				Address(source,0);
				Info(source,"array data");
			END;
		END ArrayBlock;

		PROCEDURE PatchArray(section: IntermediateCode.Section; pc: LONGINT; size: LONGINT);
		BEGIN
			IF implementationEmitter.backend.cooperative THEN
				PatchSize(section, pc, size);
				PatchSize(section, pc + 3, size);
			ELSE
				PatchSize(section, pc-3, size); (* actually only for arrays with pointers, but does not harm... *)
				PatchSize(section, pc, size);
			END;
		END PatchArray;

		PROCEDURE ExportDesc(source: IntermediateCode.Section);
		VAR
			i: LONGINT; section: Sections.Section; fingerprinter : Fingerprinter.Fingerprinter;
			sectionArray: POINTER TO ARRAY OF Sections.Section;
			poolMap: Basic.HashTableInt;
			namePool: IntermediateCode.Section;
			namePoolOffset: LONGINT;

			PROCEDURE Compare(VAR s1, s2: Sections.Section): BOOLEAN;
			VAR n1, n2: Basic.SectionName; index: LONGINT; ch1, ch2: CHAR;
			BEGIN
				Basic.SegmentedNameToString(s1.name,n1);
				Basic.SegmentedNameToString(s2.name,n2);
				index := 0;
				ch1 := n1[index];
				ch2 := n2[index];
				WHILE (ch1 # 0X) & (ch1 = ch2)  DO
					INC(index);
					ch1 := n1[index];
					ch2 := n2[index];
				END;
				RETURN ch1 < ch2;
			END Compare;

			PROCEDURE QuickSort(VAR list: ARRAY OF Sections.Section;  lo, hi: LONGINT);
			VAR
				i, j: LONGINT;
				x, t: Sections.Section;
			BEGIN
				IF lo < hi THEN
					i := lo; j := hi; x:= list[(lo+hi) DIV 2];

					WHILE i <= j DO
						WHILE Compare(list[i], x) DO INC(i) END;
						WHILE Compare(x, list[j]) DO DEC(j) END;

						IF i <= j THEN
							t := list[i]; list[i] := list[j]; list[j] := t; (* swap i and j *)
							INC(i); DEC(j)
						END
					END;

					IF lo < j THEN QuickSort(list, lo, j) END;
					IF i < hi THEN QuickSort(list, i, hi) END
				END;
			END QuickSort;

	(*
	ExportDesc* = RECORD
		fp*: HUGEINT;
		name* {UNTRACED}: DynamicName;
		adr*: ADDRESS;
		exports*: LONGINT;
		dsc* {UNTRACED}: ExportArray
	END;
	ExportArray* = POINTER {UNSAFE} TO ARRAY OF ExportDesc;
	*)

			PROCEDURE ExportDesc2(
				source: IntermediateCode.Section;
				namePool: IntermediateCode.Section;
				fingerprinter: Fingerprinter.Fingerprinter;
				symbol: Sections.Section;
				name: StringPool.Index;
				VAR patchAdr: LONGINT
				): BOOLEAN;
			VAR fingerprint: SyntaxTree.Fingerprint;
			BEGIN
				(*IF  (implementationEmitter.backend.cooperative) & (symbol.symbol = NIL) OR (symbol.symbol # NIL) & (symbol.type # Sections.InitCodeSection)
					& (symbol.type # Sections.InlineCodeSection)
				THEN
				*)
				IF (symbol = NIL) OR ( (implementationEmitter.backend.cooperative) & (symbol.symbol = NIL) OR (symbol.symbol # NIL) & (symbol.type # Sections.InitCodeSection) & (symbol.type # Sections.EntryCodeSection)
					& (symbol.type # Sections.ExitCodeSection)
					& (symbol.type # Sections.InlineCodeSection))
				THEN

					IF (symbol = NIL) OR (symbol # NIL) & (symbol.type # Sections.InlineCodeSection) THEN
						IF (symbol # NIL) & (symbol.symbol # NIL) THEN
							fingerprint := fingerprinter.SymbolFP(symbol.symbol);
							Hugeint(source,fingerprint.public);
						ELSE
							Hugeint(source, 0);
						END;

						Symbol(source, namePool, DynamicName(namePool, name, poolMap), 0); (* reference to dynamic name *)
						Symbol(source, symbol,0,0);
						patchAdr := source.pc;
						Longint(source, 0);
						IF module.system.addressType.sizeInBits = 64 THEN Longint(source, 0); END;
						Address(source,0);
					END;
					RETURN TRUE
				ELSE
					RETURN FALSE
				END;
			END ExportDesc2;

			PROCEDURE Export(CONST sections: ARRAY OF Sections.Section);
			VAR level, olevel, s: LONGINT; prev, this: Basic.SegmentedName; name: ARRAY 256 OF CHAR;
				scopes: ARRAY LEN(prev)+1 OF Scope; arrayName: ARRAY 32 OF CHAR;
				sym: Sections.Section; offset: LONGINT; symbol: Sections.Section;
				nextPatch: LONGINT;
			TYPE
				Scope = RECORD
					elements: LONGINT;
					gelements: LONGINT;
					section: IntermediateCode.Section;
					patchAdr: LONGINT;
					arraySizePC: LONGINT;
					beginPC: LONGINT; (* current scope start pc *)
				END;
			BEGIN
				Basic.InitSegmentedName(prev);
				olevel := -1;
				scopes[0].section := source;
				scopes[0].arraySizePC := MIN(LONGINT);

				FOR s := 0 TO LEN(sections)-1 DO
					symbol := sections[s];
					IF (symbol # NIL) & (implementationEmitter.backend.cooperative) & (symbol.symbol = NIL) OR (symbol.symbol # NIL) & (symbol.type # Sections.InitCodeSection) & (symbol.type # Sections.EntryCodeSection) & (symbol.type # Sections.ExitCodeSection) & (symbol.type # Sections.InlineCodeSection) THEN
						this := sections[s].name;
						level := 0;
						WHILE (level < LEN(this)) & (this[level] > 0) DO
							WHILE (level < LEN(this)) & (this[level] > 0) & (prev[level] = this[level]) DO
								INC(level);
							END;
							WHILE level < olevel DO
								(*TRACE("closing",olevel,scopes[olevel].elements); *)
								IF olevel > 0 THEN
									PatchLongint(scopes[olevel-1].section,scopes[olevel-1].patchAdr, scopes[olevel].elements);
									nextPatch := scopes[olevel-1].patchAdr+1;
									IF module.system.addressType.sizeInBits = 64 THEN INC(nextPatch) END;

									PatchSymbol(scopes[olevel-1].section,nextPatch, scopes[olevel].section.name,  scopes[olevel].section.symbol, scopes[olevel].beginPC, 0);
								END;
								scopes[olevel].gelements := scopes[olevel].gelements + scopes[olevel].elements;
								DEC(olevel);
							END;
							IF (level < LEN(this)) & (this[level] > 0) THEN
								IF level > olevel THEN
									(*TRACE("opening",level); *)
									IF scopes[level].section = NIL THEN
										arrayName := ".@ExportArray";
										Strings.AppendInt(arrayName, level);
										scopes[level].section := Block("Heaps","SystemBlockDesc",arrayName,offset);
										AddPointer(scopes[level].section,offset);
										ArrayBlock(scopes[level].section,scopes[level].arraySizePC,"Modules.ExportDesc", FALSE);
									END;
									scopes[level].beginPC := scopes[level].section.pc;

									olevel := level;
									scopes[olevel].elements := 0;
								END;
								IF (level = LEN(this)-1) OR (this[level+1] <= 0) THEN
									sym := sections[s];
								ELSE
									sym := NIL;
								END;
								IF ExportDesc2(scopes[level].section, namePool, fingerprinter, sym, this[level], scopes[level].patchAdr)
								THEN
									INC(scopes[olevel].elements);
								END;
								(* enter string in scope *)
								INC(level);
							END;
						END;
						Basic.SegmentedNameToString(this, name);
						prev := this;
					END;
				END;
				WHILE 0 <= olevel DO
					(*TRACE("closing",olevel,scopes[olevel].elements); *)
					IF olevel > 0 THEN
						PatchLongint(scopes[olevel-1].section,scopes[olevel-1].patchAdr, scopes[olevel].elements);
						nextPatch := scopes[olevel-1].patchAdr+1;
						IF module.system.addressType.sizeInBits = 64 THEN INC(nextPatch) END;

						PatchSymbol(scopes[olevel-1].section,nextPatch, scopes[olevel].section.name,  scopes[olevel].section.symbol, scopes[olevel].beginPC, 0);
					END;
					scopes[olevel].gelements := scopes[olevel].gelements + scopes[olevel].elements;
					DEC(olevel);
				END;

				level := 0;
				WHILE (level < LEN(scopes)) DO
					IF (scopes[level].section # NIL) & (scopes[level].arraySizePC # MIN(LONGINT))  THEN
						PatchArray(scopes[level].section, scopes[level].arraySizePC, scopes[level].gelements);
					END;
					INC(level);
				END;

			END Export;

		BEGIN
			NEW(fingerprinter);
			NEW(poolMap, 64);
			(* this is the name pool private to the export table -- it is sorted and should not be mixed / used for other names in a module *)
			namePool := Block("Heaps","SystemBlockDesc",".@NamePool",namePoolOffset);

			NEW(sectionArray, module.allSections.Length());
			FOR i := 0 TO module.allSections.Length() - 1 DO
				section := module.allSections.GetSection(i);
				sectionArray[i] := section;
			END;
			QuickSort(sectionArray^,0,module.allSections.Length()-1);

			Export(sectionArray^);
		END ExportDesc;

		PROCEDURE ExceptionArray(source: IntermediateCode.Section);
		VAR
			p: Sections.Section; finallyPC, sizePC, size, i: LONGINT;
		BEGIN
			Info(source, "exception table offsets array descriptor");
			size := 0;
			ArrayBlock(source,sizePC,"Modules.ExceptionTableEntry", FALSE);
			Info(source, "exception table content");
			FOR i := 0 TO module.allSections.Length() - 1 DO
				p := module.allSections.GetSection(i);
				IF p.type = Sections.CodeSection THEN
					finallyPC := p(IntermediateCode.Section).finally;
					IF finallyPC>=0 THEN
						Symbol( source, p, 0,0);
						Symbol( source, p,  finallyPC, 0);
						Symbol( source, p, finallyPC,0);
						INC(size);
					END;
				END
			END;
			PatchArray(source,sizePC,size);
			END ExceptionArray;

			PROCEDURE Name(section: IntermediateCode.Section; CONST name: ARRAY OF CHAR);
			VAR i: LONGINT; ch: CHAR;
			BEGIN
				i := 0;
				REPEAT
					ch := name[i]; INC(i);
					Char( section, ch);
				UNTIL ch = 0X;
				WHILE i < 32 DO
					Char( section, 0X); INC(i);
				END;
			END Name;

			PROCEDURE References(section: IntermediateCode.Section);
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
				sfTypeIndirect = 1FX;

				sfTypeRecord = 20X;

				sfTypePointerToRecord = 21X;
				sfTypePointerToArray = 22X;
				sfTypeOpenArray = 23X;
				sfTypeStaticArray = 24X;
				sfTypeDynamicArray = 25X;
				sfTypeMathStaticArray = 26X;
				sfTypeMathOpenArray = 27X;
				sfTypeMathTensor = 28X;
				sfTypeProcedure = 29X;
				sfTypeDelegate = 2AX;
				sfTypeENUM = 2BX;
(*				sfTypeCELL = 2CX; *)
				sfTypePORT = 2DX;

				sfIN = 0X;
				sfOUT = 1X;

				flagDelegate = 0;
				flagConstructor = 1;

				(* variable / parameter addressing modes *)
				sfAbsolute = 0X; (* global vars *)
				sfRelative = 1X; (* variables, value parameters *)
				sfIndirect = 2X; (* var parameters *)

				sfScopeBegin = 0F0X;
				sfScopeEnd = 0F1X;
				sfProcedure = 0F2X;
				sfVariable = 0F3X;
				sfTypeDeclaration = 0F4X;
				sfModule = 0FFX;

				RefInfo = TRUE;

			VAR
				sizePC, startPC, lastOffset: LONGINT;
				indirectTypes: Basic.HashTable;

				PROCEDURE CurrentIndex(): LONGINT;
				VAR i: LONGINT;
				BEGIN
					FOR i := startPC TO section.pc -1 DO
						ASSERT (section.instructions[i].opcode = IntermediateCode.data);
						INC(lastOffset, ToMemoryUnits(module.system, section.instructions[i].op1.type.sizeInBits));
					END;
					startPC := section.pc;
					RETURN lastOffset;
				END CurrentIndex;

			(*
					Scope = sfScopeBegin {Variable} {Procedure} {TypeDeclaration} sfScopeEnd.
					Module = sfModule prevSymbol:SIZE name:String Scope.
					Procedure = sfProcedure prevSymbol:SIZE name:STRING from:ADDRESS to:ADDRESS {Parameter} returnType:Type Scope.
					Variable = sfVariable prevSymbol:SIZE name:STRING (sfAbsolute address:ADDRESS| sfIndirect offset:SIZE | sfRelative offset:SIZE) Type.
					TypeDeclaration = sfTypeDeclaration prevSymbol:SIZE name:STRING td:ADDRESS Scope.
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
						| sfTypeCHAR | sfTypeCHAR8 | sfTypeCHAR16 | sfTypeCHAR32
						| sfTypeSHORTINT | sfTypeINTEGER | sfTypeLONGINT | sfTypeHUGEINT
						| sfTypeSIGNED8 | sfTypeSIGNED16 | sfTypeSIGNED32 | sfTypeSIGNED64
						| sfTypeUNSIGNED8 | sfTypeUNSIGNED16 | sfTypeUNSIGNED32 | sfTypeUNSIGNED64
						| sfTypeWORD | sfTypeLONGWORD
						| sfTypeREAL | sfTypeLONGREAL
						| sfTypeCOMPLEX | sfTypeLONGCOMPLEX
						| sfTypeSET | sfTypeANY | sfTypeOBJECT | sfTypeBYTE | sfTypeADDRESS | sfTypeSIZE
						| sfTypeIndirect offset:SIZE.
		*)

				PROCEDURE Indirect(type: SyntaxTree.Type): BOOLEAN;
				VAR offset: SIZE;
				BEGIN
					IF indirectTypes.Has(type) THEN
						offset := indirectTypes.GetInt(type);
						Char(section, sfTypeIndirect);
						Size(section, offset);
						RETURN TRUE;
					ELSE
						indirectTypes.PutInt(type, CurrentIndex());
						RETURN FALSE;
					END;
				END Indirect;

				PROCEDURE NType(type: SyntaxTree.Type);
				VAR size: SIZE; td: SyntaxTree.TypeDeclaration; tir: Sections.Section;
					segmentedName: Basic.SegmentedName; offset: LONGINT; parameter: SyntaxTree.Parameter;
				BEGIN
					IF type = NIL THEN
						Char(section, sfTypeNone)
					ELSE
						type := type.resolved;
						size := type.sizeInBits;

						WITH type:
						SyntaxTree.PointerType DO
							IF type.pointerBase.resolved IS SyntaxTree.RecordType THEN
								IF RefInfo THEN Info(section,"PointerToRecord") END;
								IF type.pointerBase.resolved(SyntaxTree.RecordType).isObject THEN
									Char(section, sfTypeOBJECT);
								ELSE
									Char(section, sfTypePointerToRecord);
								END;
								(*! do we ever need the pointer base?  NType(type.pointerBase);*)
							ELSE
								IF RefInfo THEN Info(section,"PointerToArray") END;
								Char(section, sfTypePointerToArray);
								NType(type.pointerBase);
							END;
						| SyntaxTree.ArrayType DO
							IF ~Indirect(type) THEN
								IF type.form = SyntaxTree.Open THEN
									IF RefInfo THEN Info(section,"OpenArray") END;
									Char(section, sfTypeOpenArray);
								ELSIF type.form = SyntaxTree.SemiDynamic THEN
									IF RefInfo THEN Info(section,"DynamicArray") END;
									Char(section, sfTypeDynamicArray);
								ELSIF type.form = SyntaxTree.Static THEN
									IF RefInfo THEN Info(section,"StaticArray") END;
									Char(section, sfTypeStaticArray);
									Size(section, type.staticLength);
								ELSE
									HALT(100);
								END;
								NType(type.arrayBase);
							END;
						| SyntaxTree.MathArrayType DO
							IF ~Indirect(type) THEN
								IF type.form = SyntaxTree.Open THEN
									IF RefInfo THEN Info(section,"MathOpenArray") END;
									Char(section, sfTypeMathOpenArray);
								ELSIF type.form = SyntaxTree.Static THEN
									IF RefInfo THEN Info(section,"MathStaticArray") END;
									Char(section, sfTypeMathStaticArray);
									Size(section, type.staticLength);
								ELSIF type.form = SyntaxTree.Tensor THEN
									IF RefInfo THEN Info(section,"MathTensor") END;
									Char(section, sfTypeMathTensor);
								ELSE
									HALT(100);
								END;
								NType(type.arrayBase);
							END;
						| SyntaxTree.RecordType DO
							IF ~Indirect(type) THEN
								IF type.pointerType # NIL (* OBJECT *) THEN
									IF RefInfo THEN Info(section,"PointerToRecord->OBJECT") END;
									Char(section, sfTypeOBJECT)
								ELSE
									IF RefInfo THEN Info(section,"Record") END;
									Char(section, sfTypeRecord);
									td := type.typeDeclaration;
									IF RefInfo THEN Info(section,"TD") END;
									IF (td # NIL) THEN
										Global.GetSymbolSegmentedName(td,segmentedName);
										IF (td.scope = NIL) OR (td.scope.ownerModule = module.module) THEN
											tir := implementationEmitter.NewSection(module.allSections, Sections.ConstSection, segmentedName,td,declarationEmitter.dump);
										ELSE
											tir := implementationEmitter.NewSection(module.importedSections, Sections.ConstSection, segmentedName,td,declarationEmitter.dump);
										END;
										offset := ToMemoryUnits(module.system,GetTypeRecordBaseOffset(type(SyntaxTree.RecordType).recordScope.numberMethods)*module.system.addressSize);
										Symbol(section, tir,  0, offset);
									ELSE
										Address(section, 0);
									END;
								END;
							END;
						| SyntaxTree.CellType DO
								IF ~Indirect(type) THEN
									IF RefInfo THEN Info(section,"Record") END;
									Char(section, sfTypeRecord);
									td := type.typeDeclaration;
									IF RefInfo THEN Info(section,"TD") END;
									IF (td # NIL) THEN
										Global.GetSymbolSegmentedName(td,segmentedName);
										IF (td.scope = NIL) OR (td.scope.ownerModule = module.module) THEN
											tir := implementationEmitter.NewSection(module.allSections, Sections.ConstSection, segmentedName,td,declarationEmitter.dump);
										ELSE
											tir := implementationEmitter.NewSection(module.importedSections, Sections.ConstSection, segmentedName,td,declarationEmitter.dump);
										END;
										offset := ToMemoryUnits(module.system,GetTypeRecordBaseOffset(0)*module.system.addressSize);
										Symbol(section, tir,  0, offset);
									ELSE
										Address(section, 0);
									END;
								END;
						| SyntaxTree.PortType DO
							Char(section, sfTypePORT);
							IF type.direction = SyntaxTree.OutPort THEN
								Char(section, sfOUT)
							ELSE
								Char(section, sfIN)
							END;
						| SyntaxTree.ProcedureType DO
								IF ~Indirect(type) THEN
									IF type.isDelegate THEN
										Char(section, sfTypeDelegate);
									ELSE
										Char(section, sfTypeProcedure);
									END;
									parameter := type.firstParameter;
									WHILE(parameter # NIL) DO
										NParameter(parameter, -1);
										parameter := parameter.nextParameter;
									END;
									NType(type.returnType);
								END;
						| SyntaxTree.EnumerationType DO
								Char(section, sfTypeENUM);
						| SyntaxTree.BasicType DO
							WITH type:
							SyntaxTree.BooleanType DO
								IF RefInfo THEN Info(section,"Boolean") END;
								Char(section, sfTypeBOOLEAN);
							| SyntaxTree.CharacterType DO
										IF type = module.system.characterType THEN
										IF RefInfo THEN Info(section,"CHAR") END;
											Char(section, sfTypeCHAR);
										ELSIF (type = module.system.characterType8) OR (type.sizeInBits= 8) THEN
											IF RefInfo THEN Info(section,"CHAR8") END;
											Char(section, sfTypeCHAR8)
										ELSIF (type = module.system.characterType16) OR (type.sizeInBits= 16) THEN
											IF RefInfo THEN Info(section,"CHAR16") END;
											Char(section, sfTypeCHAR16);
										ELSIF (type = module.system.characterType32) OR (type.sizeInBits = 32) THEN
											IF RefInfo THEN Info(section,"CHAR32") END;
											Char(section, sfTypeCHAR32);
										ELSE
											HALT(100);
										END;
								|SyntaxTree.IntegerType DO
									IF type(SyntaxTree.IntegerType).signed THEN
										IF (type = module.system.shortintType) THEN
											IF RefInfo THEN Info(section,"SHORTINT") END;
											Char(section, sfTypeSHORTINT)
										ELSIF (type = module.system.integerType) THEN
											IF RefInfo THEN Info(section,"INTEGER") END;
											Char(section, sfTypeINTEGER)
										ELSIF (type = module.system.longintType) THEN
											IF RefInfo THEN Info(section,"LONGINT") END;
											Char(section, sfTypeLONGINT)
										ELSIF (type = module.system.hugeintType) THEN
											IF RefInfo THEN Info(section,"HUGEINT") END;
											Char(section, sfTypeHUGEINT)
										ELSIF (type = module.system.wordType) THEN
											IF RefInfo THEN Info(section,"WORD") END;
											Char(section, sfTypeWORD)
										ELSIF (type = module.system.longWordType) THEN
											IF RefInfo THEN Info(section,"LONGWORD") END;
											Char(section, sfTypeLONGWORD);
										ELSIF (type = Global.Integer8) OR (type.sizeInBits = 8 ) THEN
											IF RefInfo THEN Info(section,"SIGNED8") END;
											Char(section, sfTypeSIGNED8)
										ELSIF (type = Global.Integer16) OR (type.sizeInBits = 16 ) THEN
											IF RefInfo THEN Info(section,"SIGNED16") END;
											Char(section, sfTypeSIGNED16)
										ELSIF (type = Global.Integer32) OR (type.sizeInBits = 32 ) THEN
											IF RefInfo THEN Info(section,"SIGNED32") END;
											Char(section, sfTypeSIGNED32)
										ELSIF (type = Global.Integer64) OR (type.sizeInBits = 64 ) THEN
											IF RefInfo THEN Info(section,"SIGNED64") END;
											Char(section, sfTypeSIGNED64)
										ELSE
											HALT(100);
										END
									ELSE (* unsigned *)
										IF (type = Global.Unsigned8) OR (type.sizeInBits = 8 ) THEN
											IF RefInfo THEN Info(section,"UNSIGNED8") END;
											Char(section, sfTypeUNSIGNED8)
										ELSIF (type = Global.Unsigned16) OR (type.sizeInBits = 16 ) THEN
											IF RefInfo THEN Info(section,"UNSIGNED16") END;
											Char(section, sfTypeUNSIGNED16)
										ELSIF (type = Global.Unsigned32) OR (type.sizeInBits = 32 ) THEN
											IF RefInfo THEN Info(section,"UNSIGNED32") END;
											Char(section, sfTypeUNSIGNED32)
										ELSIF (type = Global.Unsigned64) OR (type.sizeInBits = 64 ) THEN
											IF RefInfo THEN Info(section,"UNSIGNED64") END;
											Char(section, sfTypeUNSIGNED64)
										ELSE
											HALT(100)
										END
								END;
							| SyntaxTree.FloatType DO
								IF (type = module.system.realType) OR (type.sizeInBits = 32) THEN
									IF RefInfo THEN Info(section,"REAL") END;
									Char(section, sfTypeREAL);
								ELSIF (type = module.system.longrealType) OR (type.sizeInBits = 64) THEN
									IF RefInfo THEN Info(section,"LONGREAL") END;
									Char(section, sfTypeLONGREAL);
								ELSE
									HALT(100);
								END;
							| SyntaxTree.ComplexType DO
								IF (type = module.system.complexType) OR (type.sizeInBits = 64) THEN
									IF RefInfo THEN Info(section,"COMPLEX") END;
									Char(section, sfTypeCOMPLEX);
								ELSIF (type = module.system.longcomplexType) OR (type.sizeInBits = 12) THEN
									IF RefInfo THEN Info(section,"LONGCOMPLEX") END;
									Char(section, sfTypeLONGCOMPLEX);
								ELSE
									HALT(100);
								END;
							|SyntaxTree.SetType DO
								IF RefInfo THEN Info(section,"SET") END;
								Char(section, sfTypeSET);
							|SyntaxTree.AnyType DO
								IF RefInfo THEN Info(section,"ANY") END;
								Char(section, sfTypeANY);
							|SyntaxTree.ObjectType DO
								IF RefInfo THEN Info(section,"OBJECT") END;
								Char(section, sfTypeOBJECT);
							|SyntaxTree.ByteType DO
								IF RefInfo THEN Info(section,"BYTE") END;
								Char(section, sfTypeBYTE);
							|SyntaxTree.RangeType DO
								IF RefInfo THEN Info(section,"RANGE") END;
								Char(section, sfTypeRANGE)
							|SyntaxTree.AddressType DO
								IF RefInfo THEN Info(section,"ADDRESS") END;
								Char(section, sfTypeADDRESS)
							|SyntaxTree.SizeType DO
								IF RefInfo THEN Info(section,"SIZE") END;
								Char(section, sfTypeSIZE)
							ELSE
								HALT(100)
							END;
						ELSE HALT(101);
						END;
					END;
				END NType;

				(*
					Parameter = sfVariable prevSymbol:SIZE name:STRING (sfIndirec|sfRelative) offset:SIZE Type.
				*)
				PROCEDURE NParameter(parameter: SyntaxTree.Parameter; procOffset: LONGINT);
				VAR type: SyntaxTree.Type;
				BEGIN
					IF RefInfo THEN Info(section, "Parameter") END;
					Char(section, sfVariable);
					Size(section, procOffset);
					String0(section, parameter.name);
					type := parameter.type.resolved;
					IF parameter.kind = SyntaxTree.VarParameter THEN
						IF IsOpenArray(type) THEN Char(section, sfRelative)
						ELSE Char(section, sfIndirect)
						END;
					ELSIF parameter.kind = SyntaxTree.ConstParameter THEN
						IF (type IS SyntaxTree.RecordType) OR IsStaticArray(type) THEN
							Char(section, sfIndirect);
						ELSE
							Char(section, sfRelative);
						END;
					ELSE
						Char(section, sfRelative);
					END;
					Size(section, ToMemoryUnits(module.system,parameter.offsetInBits));
					NType(parameter.type);
				END NParameter;

				(*
					Procedure = sfProcedure prevSymbol:SIZE name:STRING from:ADDRESS to:ADDRESS {Parameter} returnType:Type Scope.
				*)
				PROCEDURE NProcedure(procedure: SyntaxTree.Procedure; scopeOffset: LONGINT);
				VAR s: Sections.Section; procedureType: SyntaxTree.ProcedureType; parameter: SyntaxTree.Parameter; pos: LONGINT;
					flags: SET;
				BEGIN
					IF procedure.externalName # NIL THEN RETURN END;
					IF RefInfo THEN Info(section, "Procedure") END;
					pos := CurrentIndex();
					procedureType := procedure.type.resolved(SyntaxTree.ProcedureType);
					Char(section, sfProcedure);
					Size(section, scopeOffset);
					String0(section,procedure.name);
					s := module.allSections.FindBySymbol(procedure);
					Symbol(section,s,0,0); (* start *)
					Symbol(section,s,s(IntermediateCode.Section).pc,0); (* end *)

					flags := {};
					IF procedureType.isDelegate THEN
						INCL(flags, flagDelegate);
					END;
					IF procedure.isConstructor THEN
						INCL(flags, flagConstructor);
					END;
					Set(section, flags);

					IF RefInfo THEN Info(section, "Parameters") END;
					parameter := procedureType.firstParameter;
					WHILE(parameter # NIL) DO
						NParameter(parameter, pos);
						parameter := parameter.nextParameter;
					END;
					IF procedureType.returnParameter # NIL THEN
						NParameter(procedureType.returnParameter, pos);
					END;
					IF procedureType.selfParameter # NIL THEN
						NParameter(procedureType.selfParameter, pos);
					END;
					IF RefInfo THEN Info(section, "ReturnType") END;
					NType(procedureType.returnType);

					NScope(procedure.procedureScope, pos);
				END NProcedure;

				(*
					Variable = sfVariable prevSymbol:SIZE name:STRING (sfAbsolute address:ADDRESS| sfRelative offset:SIZE) Type.
				*)
				PROCEDURE NVariable(variable: SyntaxTree.Variable; scopeOffset: LONGINT);
				VAR s: Sections.Section; sn: Basic.SegmentedName; pos: LONGINT;
				BEGIN
					IF RefInfo THEN Info(section, "Variable") END;
					pos := CurrentIndex();
					Char(section, sfVariable);
					Size(section, scopeOffset);
					String0(section, variable.name);
					IF (variable.scope # NIL) & (variable.scope IS SyntaxTree.ModuleScope) THEN
						Char(section, sfAbsolute);
						IF variable.externalName # NIL THEN
							sn := variable.externalName^;
							NamedSymbol(section, sn,NIL, 0,0);
						ELSE
							implementationEmitter.GetCodeSectionNameForSymbol(variable, sn);
							NamedSymbol(section, sn,variable, 0,0);
						END;
					ELSE
						Char(section, sfRelative);
						Size(section, ToMemoryUnits(module.system,variable.offsetInBits));
					END;
					NType(variable.type);
					s := module.allSections.FindBySymbol(variable);
				END NVariable;

				(*
					TypeDeclaration = sfTypeDeclaration prevSymbol:SIZE name:STRING td:ADDRESS Scope.
				*)
				PROCEDURE NTypeDeclaration(typeDeclaration: SyntaxTree.TypeDeclaration; scopeOffset: LONGINT);
				VAR declared: SyntaxTree.Type; s: Sections.Section; offset: LONGINT; name: Basic.SegmentedName; pos: LONGINT;
				BEGIN
					IF typeDeclaration = NIL THEN RETURN END;
					pos := CurrentIndex();
					s := module.allSections.FindBySymbol(typeDeclaration);
					IF s = NIL THEN RETURN END; (*! duplicate, what to do? *)

					IF RefInfo THEN Info(section, "TypeDeclaration") END;
					Char(section, sfTypeDeclaration);
					Size(section, scopeOffset);
					String0(section, typeDeclaration.name);

					declared := typeDeclaration.declaredType.resolved;
					IF (declared IS SyntaxTree.PointerType) THEN
						declared := declared(SyntaxTree.PointerType).pointerBase.resolved;
					END;

					WITH declared:
					SyntaxTree.RecordType DO
						offset := ToMemoryUnits(module.system,GetTypeRecordBaseOffset(declared.recordScope.numberMethods)*module.system.addressSize);
						Symbol(section, s,  0, offset);
						Global.GetSymbolSegmentedName(typeDeclaration,name);
						Basic.AppendToSegmentedName(name,".@Info");
						s := module.allSections.FindByName(name);
						IF s # NIL THEN (* does not work for coop *)
							PatchSize(s(IntermediateCode.Section), patchInfoPC, pos);
						END;
						NScope(declared.recordScope, pos);
					|SyntaxTree.CellType DO
						offset := ToMemoryUnits(module.system,GetTypeRecordBaseOffset(0)*module.system.addressSize);
						Symbol(section, s,  0, offset);
						Global.GetSymbolSegmentedName(typeDeclaration,name);
						Basic.AppendToSegmentedName(name,".@Info");
						s := module.allSections.FindByName(name);
						IF s # NIL THEN
							PatchSize(s(IntermediateCode.Section), patchInfoPC, pos);
						END;
						NScope(declared.cellScope, pos);
					ELSE
						Address(section, 0);
					END;
				END NTypeDeclaration;

				PROCEDURE NModule(module: SyntaxTree.Module; prevSymbol: LONGINT);
				VAR pos: LONGINT;
				BEGIN
					pos := CurrentIndex();
					Char(section,sfModule);
					Size(section, prevSymbol);
					String0(section, module.name);
					NScope(module.moduleScope, pos);
				END NModule;

				(*
					Scope = sfScopeBegin {Variable} {Procedure} {TypeDeclaration} sfScopeEnd.
				*)
				PROCEDURE NScope(scope: SyntaxTree.Scope; prevSymbol: LONGINT);
				VAR bodyProcedure, procedure: SyntaxTree.Procedure; variable: SyntaxTree.Variable; typeDeclaration: SyntaxTree.TypeDeclaration;
				BEGIN
					IF scope = NIL THEN RETURN END;
					IF RefInfo THEN Info(section, "Scope") END;
					Char(section, sfScopeBegin);
					variable := scope.firstVariable;
					WHILE (variable # NIL) DO
						NVariable(variable, prevSymbol);
						variable := variable.nextVariable;
					END;
					WITH scope:
					SyntaxTree.ModuleScope DO
						bodyProcedure := scope.bodyProcedure;
					|SyntaxTree.RecordScope DO
						bodyProcedure := scope.bodyProcedure;
					ELSE
						bodyProcedure := NIL;
					END;
					IF bodyProcedure # NIL THEN
						NProcedure(bodyProcedure, prevSymbol)
					END;
					procedure := scope.firstProcedure;
					WHILE procedure # NIL DO
						IF (procedure # bodyProcedure) & ~procedure.isInline THEN NProcedure(procedure, prevSymbol) END;
						procedure := procedure.nextProcedure;
					END;
					typeDeclaration := scope.firstTypeDeclaration;
					WHILE typeDeclaration # NIL DO
						NTypeDeclaration(typeDeclaration, prevSymbol);
						typeDeclaration := typeDeclaration.nextTypeDeclaration;
					END;
					Char(section, sfScopeEnd); (* scope ends *)
				END NScope;

			BEGIN
				NEW(indirectTypes, 32);
				ArrayBlock(section,sizePC,"", FALSE);
				startPC := section.pc;
				NModule(module.module, -1);
				PatchArray(section,sizePC,CurrentIndex());
			END References;

		(*
		Command* = RECORD
			(* Fields exported for initialization by loader/linker only! Consider read-only! *)
			name*: Name; (* name of the procedure *)
			argTdAdr*, retTdAdr* : ADDRESS; (* address of type descriptors of argument and return type, 0 if no type *)
			entryAdr* : ADDRESS; (* entry address of procedure *)
		END;
		*)
		PROCEDURE CommandArray(source: IntermediateCode.Section);
		VAR
			p: Sections.Section;  sizePC, numberCommands: LONGINT;
			procedure : SyntaxTree.Procedure; procedureType: SyntaxTree.ProcedureType;
			name: SyntaxTree.IdentifierString; numberParameters, i: LONGINT;

				(* Returns TRUE if the built-in function GETPROCEDURE can be used with this procedure type *)
				PROCEDURE GetProcedureAllowed() : BOOLEAN;

					PROCEDURE TypeAllowed(type : SyntaxTree.Type) : BOOLEAN;
					BEGIN
						RETURN
							(type = NIL) OR
							(type.resolved IS SyntaxTree.RecordType) OR
							(type.resolved IS SyntaxTree.PointerType) & (type.resolved(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.RecordType) OR
							(type.resolved IS SyntaxTree.AnyType);
				END TypeAllowed;

				BEGIN
					numberParameters := procedureType.numberParameters;
					RETURN
						(numberParameters = 0) & TypeAllowed(procedureType.returnType) OR
						(numberParameters = 1) & TypeAllowed(procedureType.firstParameter.type) & TypeAllowed(procedureType.returnType) OR
						(numberParameters = 1) & (procedureType.firstParameter.type.resolved IS SyntaxTree.AnyType) & (procedureType.returnType # NIL) & (procedureType.returnType.resolved IS SyntaxTree.AnyType);
				END GetProcedureAllowed;

				PROCEDURE WriteType(type : SyntaxTree.Type);
				VAR typeDeclaration: SyntaxTree.TypeDeclaration; section: Sections.Section;
					name: Basic.SegmentedName; offset: LONGINT;
				BEGIN
					IF type = NIL THEN
						Address(source,0);
					ELSIF (type.resolved IS SyntaxTree.AnyType) OR (type.resolved IS SyntaxTree.ObjectType) THEN
						Address(source,1);
					ELSE
						type := type.resolved;
						IF type IS SyntaxTree.PointerType THEN
							type := type(SyntaxTree.PointerType).pointerBase.resolved;
						END;
						typeDeclaration := type.typeDeclaration; (* must be non-nil *)
						IF (typeDeclaration.scope = NIL) OR (typeDeclaration.scope.ownerModule = module.module) THEN
							name[0] := typeDeclaration.name; name[1] := -1;
							section := module.allSections.FindBySymbol(type.typeDeclaration); (*TODO*)
							ASSERT(section # NIL);
						ELSE
							Global.GetSymbolSegmentedName(typeDeclaration,name);
							(* TODO *)
							section := implementationEmitter.NewSection(module.importedSections, Sections.ConstSection, name,typeDeclaration, source.comments # NIL);
						END;
						IF implementationEmitter.backend.cooperative THEN
							offset := 0;
						ELSE
							offset := 1 + type(SyntaxTree.RecordType).recordScope.numberMethods+16+1;
						END;
						Symbol(source,section, 0, ToMemoryUnits(module.system,offset*module.system.addressSize));
					END;
				END WriteType;

		BEGIN
			Info(source, "command array descriptor");
			ArrayBlock(source,sizePC,"Modules.Command", FALSE);
			numberCommands := 0;
			Info(source, "command array content");

			FOR i := 0 TO module.allSections.Length() - 1 DO
				p := module.allSections.GetSection(i);
				IF (p.symbol # NIL) & (p.symbol IS SyntaxTree.Procedure)  THEN
					procedure := p.symbol(SyntaxTree.Procedure);
					procedureType := procedure.type(SyntaxTree.ProcedureType);
					IF (SyntaxTree.PublicWrite IN procedure.access) & ~(procedure.isInline) & ~(procedureType.isDelegate) & GetProcedureAllowed() THEN
						procedure.GetName(name);
						Name(source,name);
						numberParameters := procedureType.numberParameters;
						(* offset of type of first parameter *)
						IF (numberParameters = 0 ) THEN WriteType(NIL)
						ELSE WriteType(procedureType.firstParameter.type)
						END;
						(* offset of type of return parameter *)
						WriteType(procedureType.returnType);
						(* command name *)
						(* command code offset *)
						Symbol(source,p,0,0);
						INC(numberCommands);
						IF Trace THEN
							D.Ln;
						END;
					END;
				END
			END;
			PatchArray(source,sizePC,numberCommands);
		END CommandArray;

		(* to prevent from double import of different module aliases *)
		PROCEDURE IsFirstDirectOccurence(import: SyntaxTree.Import): BOOLEAN; (*! inefficient *)
		VAR i: SyntaxTree.Import;
		BEGIN
			i := module.module.moduleScope.firstImport;
			WHILE (i # NIL) & ((i.module # import.module) OR ~i.direct) DO
				i := i.nextImport;
			END;
			RETURN i = import
		END IsFirstDirectOccurence;

		PROCEDURE ImportsArray(source: IntermediateCode.Section);
		VAR import: SyntaxTree.Import ; pc: LONGINT;name: Basic.SegmentedName; numberImports: LONGINT; offset: LONGINT;
		BEGIN
			(* strictly speaking this needs to be a pointer array but by the construction of module loading, this references are not required *)
			ArrayBlock(source,pc,"", FALSE);
			Info(source, "import module array data");
			IF implementationEmitter.backend.cooperative THEN
				offset := 0;
			ELSE
				IF module.system.addressType.sizeInBits = 64 THEN
					(* change this when Heaps.HeapBlock is modified *)
					offset := ToMemoryUnits(module.system, 18* module.system.addressSize) (* Module pointer offset -- cf. ModuleSection(), how to encode generically correct? *);
				ELSE
					(* change this when Heaps.HeapBlock is modified *)
					offset := ToMemoryUnits(module.system, 23* module.system.addressSize) (* Module pointer offset -- cf. ModuleSection(), how to encode generically correct? *);
				END;
			END;
			import :=  module.module.moduleScope.firstImport;
			numberImports := 0;
			WHILE import # NIL DO
				IF import.direct & ~Global.IsSystemModule(import.module) & IsFirstDirectOccurence(import) THEN
					Global.GetModuleSegmentedName(import.module,name);
					Basic.SuffixSegmentedName(name, StringPool.GetIndex1("@Module"));
					NamedSymbol(source, name, NIL, 0, offset);
					INC(numberImports);
				END;
				import := import.nextImport
			END;
			PatchArray(source,pc,numberImports);
		END ImportsArray;

		PROCEDURE TypeInfoSection(source: IntermediateCode.Section);
		VAR
			p: Sections.Section; sizePC, size, i: LONGINT;
		BEGIN
			Info(source, "Type info section");
			size := 0;
			ArrayBlock(source,sizePC,"Modules.TypeDesc", FALSE);
			FOR i := 0 TO module.allSections.Length() - 1 DO
				p := module.allSections.GetSection(i);
				WITH p: IntermediateCode.Section DO
					IF Basic.SegmentedNameEndsWith(p.name,"@Info") THEN
						Symbol(source,p,EmptyBlockOffset,0);
						INC(size);
					END;
				END
			END;
			PatchArray(source,sizePC,size);
		END TypeInfoSection;

		(*
			ProcTableEntry* = RECORD
				pcFrom*, pcLimit*, pcStatementBegin*, pcStatementEnd*: ADDRESS;
				noPtr*: LONGINT;
			END;

			ProcTable* = POINTER TO ARRAY OF ProcTableEntry;

			PtrTable* = POINTER TO ARRAY OF ADDRESS;
		*)

		PROCEDURE ProcedureDescriptor(section: IntermediateCode.Section; procedureSection: IntermediateCode.Section);
		VAR
			numberPointers: LONGINT;
			procedure: SyntaxTree.Procedure;
		BEGIN
				Info(section,"pcFrom");
				Symbol(section,procedureSection,0,0);
				Info(section,"pcTo");
				Symbol(section, procedureSection, procedureSection.pc, 0);
				Info(section,"pointer to offsets array");
				Symbol(section, section,section.pc+1,0);
				Info(section,"offsets array");
				procedure := procedureSection.symbol(SyntaxTree.Procedure);
				PointerArray(section, procedure.procedureScope, numberPointers);
		END ProcedureDescriptor;

		(* only for tracing, the descriptor is otherwise not complete ! *)
		PROCEDURE MakeProcedureDescriptorTag(procedureSection: IntermediateCode.Section): IntermediateCode.Section;
		VAR section: IntermediateCode.Section; infoName: Basic.SectionName;  moduleSection: IntermediateCode.Section; name: Basic.SegmentedName;
		BEGIN
			(* mini pseudo type tag that only refers to the information data for debugging purposes -- then the descriptor in the GC can be identified *)
			name := procedureSection.name;
			Basic.AppendToSegmentedName(name,".@Info");
			section := implementationEmitter.NewSection(module.allSections, Sections.ConstSection, name, NIL, declarationEmitter.dump);
			Address(section,0);
			Symbol(section,section,2,0);
			(*
				TypeDesc* = POINTER TO RECORD   (* ug: adapt constant TypeDescRecSize if this type is changed !!! *)
					descSize: SIZE;
					sentinel: ADDRESS;	(* = MPO-4 *)
					tag*: ADDRESS; (* pointer to static type descriptor, only used by linker and loader *)
					flags*: SET;
					mod*: Module;	(* hint only, because module may have been freed (at Heaps.ModOfs) *)
					name*: Name;
				END;
			*)
			Size(section, 0);
			Address(section,0);
			Address(section,0);
			Set(section,{});
			moduleSection := ModuleSection();
			Symbol( section, moduleSection, moduleSection.pc,0);
			IF procedureSection.symbol = NIL THEN
				Basic.SegmentedNameToString(procedureSection.name, infoName);
			ELSE
				Global.GetSymbolNameInScope(procedureSection.symbol, module.module.moduleScope, infoName);
			END;
			Name(section, infoName);
			Size(section, 0);
			RETURN section;
		END MakeProcedureDescriptorTag;

		PROCEDURE ProcedureDescriptorPointer(section: IntermediateCode.Section; procedureSection: IntermediateCode.Section);
		VAR dest: IntermediateCode.Section; name: Basic.SegmentedName;  offset: LONGINT;
		BEGIN
			name := procedureSection.name;
			Basic.SuffixSegmentedName(name, Basic.MakeString("@Descriptor"));
			IF implementationEmitter.backend.cooperative THEN
				dest := IntermediateCode.NewSection(module.allSections, Sections.ConstSection, name, NIL, declarationEmitter.dump);
				Info(section, "TypeDescriptor");
				Basic.ToSegmentedName("BaseTypes.Pointer", name);
				NamedSymbol(dest, name,NIL, 0, 0);
				BaseRecord(dest);
				offset := 0;
			ELSIF CreateProcedureDescInfo THEN
				dest := implementationEmitter.NewSection(module.allSections, Sections.ConstSection, name, NIL, declarationEmitter.dump);
				Address(dest,0);
				Symbol(dest, MakeProcedureDescriptorTag(procedureSection),2,0);
				offset := dest.pc;
			ELSE
				dest := NamedBlock("Heaps","SystemBlock",name,offset);
			END;
			ProcedureDescriptor(dest, procedureSection);
			Symbol(section, dest, offset, 0);
		END ProcedureDescriptorPointer;

		PROCEDURE ProcedureDescriptorArray(section: IntermediateCode.Section; VAR numberProcs: LONGINT);
		VAR sizePC, i: LONGINT; destination: Sections.Section;
		BEGIN
			ArrayBlock(section, sizePC,"Modules.ProcedureDesc.@Pointer",FALSE);
			numberProcs := 0;
			FOR i := 0 TO module.allSections.Length() - 1 DO
				destination := module.allSections.GetSection(i);
				IF (destination.type IN {Sections.CodeSection, Sections.BodyCodeSection}) & (destination.symbol # NIL) & (destination.symbol IS SyntaxTree.Procedure) & ~destination.symbol(SyntaxTree.Procedure).isInline THEN
					ProcedureDescriptorPointer(section, destination(IntermediateCode.Section));
					INC(numberProcs);
				END
			END;
			PatchArray(section, sizePC, numberProcs);
		END ProcedureDescriptorArray;

		(*
			Module* = OBJECT (Heaps.RootObject)	(* cf. Linker0 & Heaps.WriteType *)
			VAR
				next*: Module;	(** once a module is published, all fields are read-only *)
				name*: Name;
				init, published: BOOLEAN;
				refcnt*: LONGINT; (* counts loaded modules that import this module *)
				sb*: ADDRESS; <- should be zero as the static base in generic object file is indeed 0 !
				entry*: POINTER TO ARRAY OF ADDRESS; <- not needed in new loader
				command*: POINTER TO ARRAY OF Command;
				ptrAdr*: POINTER TO ARRAY OF ADDRESS;
				typeInfo*: POINTER TO ARRAY OF TypeDesc;
				module*: POINTER TO ARRAY OF Module; <---- currently done by loader
				procTable*: ProcTable; (* information inserted by loader, removed after use in Publish *)
				ptrTable*: PtrTable;  (* information inserted by loader, removed after use in Publish *)
				data*, code*: Bytes;
				staticTypeDescs* (* ug *), refs*: Bytes; <- staticTypeDescs in data section, refs currently unsupported
				export*: ExportDesc;
				term*: TerminationHandler;
				exTable*: ExceptionTable;
				noProcs*: LONGINT;
				firstProc*: ADDRESS; <-   done by loader
				maxPtrs*: LONGINT;
				crc*: LONGINT;
		*)

		PROCEDURE BasePointer (section: IntermediateCode.Section);
		BEGIN
			Info(section, "cycle");
			Size(section,0);
			Info(section, "references");
			Size(section,0);
			Info(section, "nextMarked");
			Address(section,0);
			Info(section, "nextWatched");
			Address(section,0);
		END BasePointer;

		PROCEDURE BaseObject (section: IntermediateCode.Section);
		BEGIN
			BasePointer(section);
			Info(section, "action");
			Address(section,0);
			Info(section, "monitor");
			Address(section,0);
		END BaseObject;

		PROCEDURE BaseRecord (section: IntermediateCode.Section);
		BEGIN
			BasePointer(section);
			Info(section, "action");
			Address(section,0);
			Info(section, "monitor");
			Address(section,0);
		END BaseRecord;

		PROCEDURE ModuleDescriptor(section: IntermediateCode.Section);
		VAR descriptorSection: IntermediateCode.Section; name: ARRAY 128 OF CHAR;
			pooledName: Basic.SegmentedName;
			symbol: SyntaxTree.Symbol;
		BEGIN
			Global.GetModuleName(module.module,name);
			Strings.Append(name,".@Module.@Descriptor");
			Basic.ToSegmentedName(name, pooledName);
			descriptorSection := implementationEmitter.NewSection(module.allSections, Sections.ConstSection, pooledName,NIL,declarationEmitter.dump);
			Symbol(section,descriptorSection,0,0);

			Info(descriptorSection, "descriptor");
			symbol := implementationEmitter.GetTypeDescriptor("Modules","Module", pooledName);
			NamedSymbol(descriptorSection, pooledName,symbol, 0, 0);
			Address(descriptorSection,0);

			Global.GetModuleName(module.module,name);
			Strings.Append(name,".@Trace");
			Basic.ToSegmentedName(name, pooledName);
			NamedSymbol(descriptorSection, pooledName,NIL, 0, 0);

			Basic.ToSegmentedName ("BaseTypes.Object.Finalize",pooledName);
			NamedSymbol(descriptorSection, pooledName,NIL, 0, 0);
		END ModuleDescriptor;

		PROCEDURE ModuleSection(): IntermediateCode.Section;
		VAR name: ARRAY 128 OF CHAR;
			moduleSection: IntermediateCode.Section; offset: LONGINT; pooledName: Basic.SegmentedName;
			symbol: SyntaxTree.Symbol;
		BEGIN
			Global.GetModuleName(module.module,name);
			Strings.Append(name,".@Module");
			Basic.ToSegmentedName(name, pooledName);
			moduleSection := implementationEmitter.NewSection(module.allSections, Sections.ConstSection, pooledName,NIL,declarationEmitter.dump);
			moduleSection.SetExported(TRUE);
			IF moduleSection.pc = 0 THEN
				IF implementationEmitter.backend.cooperative THEN
					Info(moduleSection, "descriptor");
					ModuleDescriptor(moduleSection);
					BaseObject(moduleSection);
					implementationEmitter.CreateTraceModuleMethod(module.module);
				ELSE
					ProtectedHeapBlock("Heaps","ProtRecBlockDesc",moduleSection,2);
					Info(moduleSection, "HeapBlock");
					Symbol(moduleSection,moduleSection,2,0);
					Info(moduleSection, "TypeDescriptor");
					symbol := implementationEmitter.GetTypeDescriptor("Modules","Module", pooledName);
					offset := ToMemoryUnits(module.system,(TypeRecordBaseOffset + 1 (*= numberMethods*))*module.system.addressSize);
					NamedSymbol(moduleSection, pooledName,symbol, 0, offset);
				END;
			END;
			RETURN moduleSection;
		END ModuleSection;

			PROCEDURE NewModuleInfo();
			VAR name: Basic.SegmentedName;source: IntermediateCode.Section;
				moduleSection: IntermediateCode.Section; i: LONGINT; flags: SET;
				sectionName: Basic.SectionName;
			CONST MPO=-40000000H;
			BEGIN
					(*
						TypeDesc* = POINTER TO RECORD
							descSize: SIZE;
							sentinel: LONGINT;	(* = MPO-4 *)
							tag*: ADDRESS; (* pointer to static type descriptor, only used by linker and loader *)
							flags*: SET;
							mod*: Module;	(* hint only, because module may have been freed (at Heaps.ModOfs) *)
							name*: Name;
							refsOffset: SIZE;
						END;
					*)

					(*name is missing prefixes sometimes*)
					Global.GetModuleSegmentedName(module.module,name);
					Basic.AppendToSegmentedName(name,".@Info");
					source := implementationEmitter.NewSection(module.allSections, Sections.ConstSection, name,NIL,declarationEmitter.dump);

					IF ~implementationEmitter.backend.cooperative  THEN
						Info(source, "HeapBlock");
						Address(source,0); (* an empty heap block prevents GC marking *)
						Info(source, "TypeDescriptor");
						Address(source,0);
						ASSERT(source.pc = EmptyBlockOffset); (* sanity check *)
					END;

					Info(source, "type info size");	Address(source, 6*ToMemoryUnits(module.system,module.system.addressSize)+32);
					Address(source,MPO-4);
					Info(source, "type tag pointer");
					Address( source,0);
					Info(source, "type flags");
					flags := {};
					Set( source, flags);

					Info(source, "pointer to module");
					moduleSection := ModuleSection();
					Symbol( source, moduleSection, moduleSection.pc,0);
					Info(source, "type name");
					i := 0;
					sectionName := "@Self";
					(*
					Global.GetSymbolSegmentedName(td,name);
					Basic.SegmentedNameToString(name, sectionName);
					*)
					Name(source,sectionName);
					patchInfoPC := source.pc;
					Size(source, 0);
			END NewModuleInfo;

		PROCEDURE Module(bodyProc: IntermediateCode.Section);
		VAR
			moduleSection, pointerSection, importSection, emptyArraySection, exceptionSection, commandsSection,
			typeInfoSection, procTableSection,  referenceSection : IntermediateCode.Section;
			emptyArraySectionOffset, pointerSectionOffset, importSectionOffset, numberPointers,
			exceptionSectionOffset, commandsSectionOffset, typeInfoSectionOffset, procTableSectionOffset, numberProcs,temp,
			referenceSectionOffset	: LONGINT;
			name: Basic.SegmentedName; offset: LONGINT;
			flags: SET;
		BEGIN
			NewModuleInfo();
			pointerSection := Block("Heaps","SystemBlockDesc",".@PointerArray",pointerSectionOffset);
			PointerArray(pointerSection,module.module.moduleScope, numberPointers);
			importSection := Block("Heaps","SystemBlockDesc",".@ImportsArray",importSectionOffset);
			ImportsArray(importSection);
			commandsSection := Block("Heaps","SystemBlockDesc",".@CommandArray",commandsSectionOffset);
			CommandArray(commandsSection);
			exceptionSection := Block("Heaps","SystemBlockDesc",".@ExceptionArray",exceptionSectionOffset);
			ExceptionArray(exceptionSection);
			typeInfoSection := Block("Heaps","SystemBlockDesc",".@TypeInfoArray",typeInfoSectionOffset);
			AddPointer(typeInfoSection, typeInfoSectionOffset);
			TypeInfoSection(typeInfoSection);
			referenceSection := Block("Heaps","SystemBlockDesc",".@References",referenceSectionOffset);
			referenceSection.SetExported(TRUE);
			References(referenceSection);
			procTableSection := Block("Heaps","SystemBlockDesc",".@ProcTable",procTableSectionOffset);
			ProcedureDescriptorArray(procTableSection, numberProcs);
			IF ProtectModulesPointers THEN
				name := "Heaps.AnyPtr";
				offset := ToMemoryUnits(module.system,TypeRecordBaseOffset*module.system.addressSize);
				(* set base pointer *)
				NamedSymbolAt(procTableSection, procTableSectionOffset  -1 , name, NIL, 0, offset);
			END;

			emptyArraySection := Block("Heaps","SystemBlockDesc",".@EmptyArray",emptyArraySectionOffset);
			ArrayBlock(emptyArraySection,temp,"", FALSE);
			moduleSection := ModuleSection();
			Info(moduleSection, "nextRoot*: RootObject");
			Address(moduleSection,0);
			Info(moduleSection, "next*: Module");
			Address(moduleSection,0);
			Info(moduleSection, "name*: Name");
			Name(moduleSection,moduleName);
			Info(moduleSection, "init, published: BOOLEAN");
			Boolean(moduleSection,FALSE);
			Boolean(moduleSection,FALSE);
			Info(moduleSection,"filler"); (*! introduce alignment! *)
			Boolean(moduleSection,FALSE);
			Boolean(moduleSection,FALSE);
			Info(moduleSection, "refcnt*: LONGINT");
			Longint(moduleSection,0);
			Info(moduleSection, "sb*: ADDRESS");
			Address(moduleSection,0);
			Info(moduleSection, "entry*: POINTER TO ARRAY OF ADDRESS");
			Address(moduleSection,0);
			Info(moduleSection, "command*: POINTER TO ARRAY OF Command");
			Symbol(moduleSection,commandsSection,commandsSectionOffset,0);
			Info(moduleSection, "ptrAdr*: POINTER TO ARRAY OF ADDRESS");
			Symbol(moduleSection,pointerSection,pointerSectionOffset,0);
			Info(moduleSection, "typeInfo*: POINTER TO ARRAY OF TypeDesc");
			Symbol(moduleSection,typeInfoSection,typeInfoSectionOffset,0);
			Info(moduleSection, "module*: POINTER TO ARRAY OF Module");
			Symbol(moduleSection,importSection,importSectionOffset,0);
			Info(moduleSection, "procTable*: ProcTable");
			Symbol(moduleSection,procTableSection,procTableSectionOffset,0);
			Info(moduleSection, "data*, code*, staticTypeDescs*, refs*: Bytes");
			Address(moduleSection,0);
			Address(moduleSection,0);
			Address(moduleSection,0);
			Symbol(moduleSection,referenceSection,referenceSectionOffset,0);
			Info(moduleSection, "export*: ExportDesc");
			ExportDesc(moduleSection);
			Info(moduleSection, "term*: TerminationHandler");
			Address(moduleSection,0);
			Info(moduleSection, "exTable*: ExceptionTable");
			Symbol(moduleSection,exceptionSection,exceptionSectionOffset,0);
			Info(moduleSection,"internal: POINTER TO ARRAY OF Pointer");
			Symbol(moduleSection, modulePointerSection, modulePointerSectionOffset, 0);
			Info(moduleSection, "crc*: LONGINT");
			patchCRC:= moduleSection.pc;
			Longint(moduleSection, 0); (*!  must be implemented *)

			IF module.system.addressType.sizeInBits = 64 THEN Longint(moduleSection, 0); END; (* padding *)
			Info(moduleSection, "body*: ADDRESS");
			Symbol(moduleSection, bodyProc, 0,0);
			Info(moduleSection, "module flags");
			flags := {};
			IF  implementationEmitter.backend.preciseGC THEN INCL(flags,0) END;
			Set( moduleSection, flags);

			IF implementationEmitter.backend.cooperative THEN
				PatchSymbol(moduleSection,MonitorOffset,moduleSection.name,NIL,moduleSection.pc,0);
				Info(moduleSection, "monitor.owner");
				Address(moduleSection,0);
				Info(moduleSection, "monitor.nestingLevel");
				Address(moduleSection,0);
				Info(moduleSection, "monitor.blockedQueue");
				Address(moduleSection,0); Address(moduleSection,0);
				Info(moduleSection, "monitor.waitingQueue");
				Address(moduleSection,0); Address(moduleSection,0);
				Info(moduleSection, "monitor.waitingSentinel");
				Address(moduleSection,0);
			END;
		END Module;

		PROCEDURE PatchCRC(crc: LONGINT);
		BEGIN
			IF ~simple THEN
				PatchLongint(ModuleSection(), patchCRC, crc);
			END;
		END PatchCRC;

		PROCEDURE PointerArray(source: IntermediateCode.Section; scope: SyntaxTree.Scope; VAR numberPointers: LONGINT);
		VAR variable: SyntaxTree.Variable; pc: LONGINT; symbol: Sections.Section; parameter: SyntaxTree.Parameter;
		BEGIN
			ArrayBlock(source,pc,"",FALSE);
			Info(source, "pointer offsets array data");
			IF scope IS SyntaxTree.RecordScope THEN
				Pointers(0,symbol, source,scope(SyntaxTree.RecordScope).ownerRecord,numberPointers);
			ELSIF scope IS SyntaxTree.CellScope THEN
				Pointers(0, symbol, source, scope(SyntaxTree.CellScope).ownerCell, numberPointers);
			ELSIF scope IS SyntaxTree.ModuleScope THEN
				variable := scope(SyntaxTree.ModuleScope).firstVariable;
				WHILE variable # NIL DO
					IF ~(variable.untraced) & (variable.externalName = NIL) THEN
						symbol := module.allSections.FindBySymbol(variable);
						ASSERT(symbol # NIL);
						Pointers(0,symbol, source,variable.type,numberPointers);
					END;
					variable := variable.nextVariable;
				END;
			ELSIF scope IS SyntaxTree.ProcedureScope THEN
					parameter := scope(SyntaxTree.ProcedureScope).ownerProcedure.type(SyntaxTree.ProcedureType).firstParameter;
					WHILE parameter # NIL DO
						IF parameter.NeedsTrace() & ~IsVariableParameter(parameter)  & (parameter.kind # SyntaxTree.ConstParameter) THEN (* immutable or variable parameters do not need tracing  *)
							Pointers(ToMemoryUnits(module.system,parameter.offsetInBits), NIL,  source, parameter.type, numberPointers);
						END;
						parameter := parameter.nextParameter;
					END;
					(* a self parameter does not need to be traced *)
					variable := scope(SyntaxTree.ProcedureScope).firstVariable;
					WHILE(variable # NIL) DO
						IF ~(variable.untraced) & (variable.externalName = NIL) THEN
							Pointers(ToMemoryUnits(module.system,variable.offsetInBits), NIL,  source, variable.type, numberPointers);
						END;
						variable := variable.nextVariable
					END;

			END;
			PatchArray(source,pc,numberPointers);
		END PointerArray;

		PROCEDURE CheckTypeDeclaration(x: SyntaxTree.Type);
		VAR recordType: SyntaxTree.RecordType;
			tir, tdInfo: IntermediateCode.Section; td: SyntaxTree.TypeDeclaration;
			section: Sections.Section; cellType: SyntaxTree.CellType;

			PROCEDURE NewTypeDescriptorInfo(tag: Sections.Section; offset: LONGINT; isProtected: BOOLEAN): IntermediateCode.Section;
			VAR name: Basic.SegmentedName;source: IntermediateCode.Section;
				moduleSection: IntermediateCode.Section; i: LONGINT; flags: SET;
				sectionName: Basic.SectionName;
			CONST MPO=-40000000H;
			BEGIN
					(*
						TypeDesc* = POINTER TO RECORD
							descSize: SIZE;
							sentinel: LONGINT;	(* = MPO-4 *)
							tag*: ADDRESS; (* pointer to static type descriptor, only used by linker and loader *)
							flags*: SET;
							mod*: Module;	(* hint only, because module may have been freed (at Heaps.ModOfs) *)
							name*: Name;
							refsOffset: SIZE;
						END;
					*)
					(* source := module.sections.FindByName(...) *)
					Global.GetSymbolSegmentedName(td,name);
					Basic.AppendToSegmentedName(name,".@Info");
					source := implementationEmitter.NewSection(module.allSections, Sections.ConstSection, name,NIL,declarationEmitter.dump);
					Info(source, "HeapBlock"); (* an empty heap block prevents GC marking *)
					Address(source,0);
					Info(source, "TypeDescriptor");
					Address(source,0);
					ASSERT(source.pc = EmptyBlockOffset); (* sanity check *)

					Info(source, "type info size");	Address(source, 6*ToMemoryUnits(module.system,module.system.addressSize)+32);
					Info(source, "sentinel"); Address(source,MPO-4); (* should be removed ?? *)
					Info(source, "type tag pointer");
					Symbol( source, tag, offset, 0);
					Info(source, "type flags");
					flags := {};
					IF isProtected THEN INCL(flags,31) END;
					Set( source, flags);

					Info(source, "pointer to module");
					moduleSection := ModuleSection();
					Symbol( source, moduleSection, moduleSection.pc,0);
					Info(source, "type name");
					i := 0;
					Global.GetSymbolNameInScope(td, module.module.moduleScope, sectionName);
					(*
					Global.GetSymbolSegmentedName(td,name);
					Basic.SegmentedNameToString(name, sectionName);
					*)
					Name(source,sectionName);
					Size(source, 0);
					RETURN source;
			END NewTypeDescriptorInfo;

			PROCEDURE NewTypeDescriptor;
			VAR name: Basic.SegmentedName; op: IntermediateCode.Operand; source, base: IntermediateCode.Section;
				procedure: SyntaxTree.Procedure; baseRecord: SyntaxTree.RecordType;
				baseTD: SyntaxTree.TypeDeclaration; sym: SyntaxTree.Symbol;
				numberPointers: LONGINT;  padding, i: LONGINT;

			CONST MPO=-40000000H;

				PROCEDURE TdTable(size: LONGINT; reverse: BOOLEAN);
				VAR i: LONGINT;

					PROCEDURE Td(record: SyntaxTree.RecordType);
					VAR baseTD: SyntaxTree.TypeDeclaration; name: Basic.SegmentedName; offset: LONGINT;
					BEGIN
						IF record # NIL THEN
							IF ~reverse THEN Td(record.GetBaseRecord()) END;
							baseTD := record.typeDeclaration;
							Global.GetSymbolSegmentedName(baseTD,name);
							IF (baseTD.scope = NIL) OR (baseTD.scope.ownerModule = module.module) THEN
								tir := implementationEmitter.NewSection(module.allSections, Sections.ConstSection, name,baseTD,declarationEmitter.dump);
							ELSE
								tir := implementationEmitter.NewSection(module.importedSections, Sections.ConstSection, name,baseTD,declarationEmitter.dump);
							END;
							offset := ToMemoryUnits(module.system,GetTypeRecordBaseOffset(record.recordScope.numberMethods)*module.system.addressSize);
							Symbol(source, tir,  0, offset);
							IF reverse THEN Td(record.GetBaseRecord()) END;
						END;
					END Td;

				BEGIN
					Info(source, "tag table");
					baseRecord := recordType;
					i := 0;
					WHILE baseRecord # NIL DO
						INC(i);
						baseRecord := baseRecord.GetBaseRecord();
					END;
					IF i > size THEN implementationEmitter.Error(x.position,"maximal extension level exceeded") END;
					IF ~reverse THEN Td(recordType) END;
					WHILE i < size DO
						Address(source,0);
						INC(i);
					END;
					IF reverse THEN Td(recordType) END;
				END TdTable;

				PROCEDURE MethodTable(reverse: BOOLEAN);
				VAR i,methods: LONGINT;
				BEGIN
					Info(source, "method table");
					IF recordType # NIL THEN
						methods := recordType.recordScope.numberMethods;
						IF reverse THEN
							FOR i := methods-1 TO 0 BY -1 DO
								procedure := recordType.recordScope.FindMethod(i);
								implementationEmitter.GetCodeSectionNameForSymbol(procedure, name);
								NamedSymbol(source, name,procedure, 0,0);
							END;
						ELSE
							FOR i := 0 TO methods-1 DO
								procedure := recordType.recordScope.FindMethod(i);
								implementationEmitter.GetCodeSectionNameForSymbol(procedure, name);
								NamedSymbol(source, name,procedure, 0,0);
							END;
						END;
					END;
				END MethodTable;

				PROCEDURE CooperativeMethodTable(pointer: BOOLEAN);
				VAR baseRecord: SyntaxTree.RecordType; name, stackFrame: Basic.SegmentedName; i,start,methods: LONGINT;
				BEGIN
					Info(source, "method table");
					baseRecord := recordType;
					WHILE baseRecord.baseType # NIL DO
						baseRecord := baseRecord.GetBaseRecord ();
					END;
					GetRecordTypeName (baseRecord, name);
					Basic.ToSegmentedName ("BaseTypes.StackFrame", stackFrame);
					IF name = stackFrame THEN
						start := 0;
					ELSIF ~HasExplicitTraceMethod(recordType) THEN
						baseRecord := recordType;
						WHILE (baseRecord # NIL) & ~baseRecord.hasPointers DO
							baseRecord := baseRecord.GetBaseRecord ();
						END;
						IF baseRecord # NIL THEN
							GetRecordTypeName (baseRecord, name);
							IF pointer & ~baseRecord.isObject THEN
								Basic.SuffixSegmentedName (name, Basic.MakeString ("@Pointer"));
							END;
							Basic.SuffixSegmentedName (name, Basic.MakeString ("@Trace"));
						ELSIF recordType.isObject THEN
							Basic.ToSegmentedName ("BaseTypes.Object.@Trace",name);
						ELSIF pointer THEN
							Basic.ToSegmentedName ("BaseTypes.Pointer.Trace",name);
						ELSE
							Basic.ToSegmentedName ("BaseTypes.Record.@Trace",name);
						END;
						tir := implementationEmitter.NewSection(module.importedSections, Sections.ConstSection, name,NIL,declarationEmitter.dump);
						Symbol(source, tir,  0, 0);
						start := 0;

						baseRecord := recordType;
						WHILE (baseRecord # NIL) DO
							IF HasExplicitTraceMethod(baseRecord) THEN start := 1 END;
							baseRecord := baseRecord.GetBaseRecord ();
						END;
					ELSE
						(* explicit trace method: *)

						procedure := recordType.recordScope.FindMethod(0);
						IF ~procedure.isFinalizer THEN
							Global.GetSymbolSegmentedName(procedure, name);
							NamedSymbol(source, name,procedure, 0,0);
						END;

						start := 1;
					END;
					IF (name # stackFrame) & recordType.isObject THEN
						baseRecord := recordType;
						WHILE (baseRecord # NIL) & (baseRecord.recordScope.finalizer = NIL) DO
							baseRecord := baseRecord.GetBaseRecord ();
						END;
						IF (baseRecord = NIL) OR (baseRecord.recordScope.finalizer = NIL) THEN
							Basic.ToSegmentedName ("BaseTypes.Object.Finalize",name);
						ELSE
							Global.GetSymbolSegmentedName(baseRecord.recordScope.finalizer, name);
						END;
						tir := implementationEmitter.NewSection(module.importedSections, Sections.ConstSection, name,NIL,declarationEmitter.dump);
						Symbol(source, tir,  0, 0);
					END;
					methods := recordType.recordScope.numberMethods;
					FOR i := start TO methods-1 DO
						procedure := recordType.recordScope.FindMethod(i);
						IF ~procedure.isFinalizer THEN
							Global.GetSymbolSegmentedName(procedure, name);
							NamedSymbol(source, name,procedure, 0,0);
						END;
					END;
				END CooperativeMethodTable;

			BEGIN
					Global.GetSymbolSegmentedName(td,name);
					source := implementationEmitter.NewSection(module.allSections, Sections.ConstSection, name,td,declarationEmitter.dump);
					source.SetExported(IsExported(td));

					IF (cellType # NIL) THEN recordType := cellType.GetBaseRecord() END;

					IF implementationEmitter.backend.cooperative THEN

						base := NIL;
						baseRecord := recordType.GetBaseRecord();
						IF baseRecord # NIL THEN
							baseTD := baseRecord.typeDeclaration;
						END;

						IF ~recordType.isObject THEN
							Info(source, "parent");
							IF baseRecord # NIL THEN
								Global.GetSymbolSegmentedName(baseTD,name);
								IF (baseTD.scope = NIL) OR (baseTD.scope.ownerModule = module.module) THEN
									tir := implementationEmitter.NewSection(module.allSections, Sections.ConstSection, name,baseTD,declarationEmitter.dump);
								ELSE
									tir := implementationEmitter.NewSection(module.importedSections, Sections.ConstSection, name,baseTD,declarationEmitter.dump);
								END;
								Symbol(source, tir,  0, 0);
							ELSE
								Address(source,0);
							END;

							Info(source, "record size");
							Address(source, ToMemoryUnits(module.system,module.system.SizeOf(recordType)));
							CooperativeMethodTable(FALSE);

							base := source;
							Global.GetSymbolSegmentedName(td,name);
							Basic.SuffixSegmentedName (name, Basic.MakeString ("@Pointer"));
							source := implementationEmitter.NewSection(module.allSections, Sections.ConstSection, name,NIL,declarationEmitter.dump);
							source.SetExported(IsExported(td));
						END;

						Info(source, "parent");
						IF baseRecord # NIL THEN
							Global.GetSymbolSegmentedName(baseTD,name);
							sym := baseTD;
							IF ~recordType.isObject THEN
								Basic.SuffixSegmentedName (name, Basic.MakeString ("@Pointer"));
								sym := NIL;
							END;
							IF (baseTD.scope = NIL) OR (baseTD.scope.ownerModule = module.module) THEN
								tir := implementationEmitter.NewSection(module.allSections, Sections.ConstSection, name,sym,declarationEmitter.dump);
								tir.SetExported(IsExported(td));
							ELSE
								tir := implementationEmitter.NewSection(module.importedSections, Sections.ConstSection, name,sym,declarationEmitter.dump);
							END;
							Symbol(source, tir,  0, 0);
						ELSIF (recordType.pointerType # NIL) & recordType.pointerType.isPlain THEN
							Address(source,0);
						ELSE
							IF recordType.isObject THEN
								Basic.ToSegmentedName ("BaseTypes.Object",name);
							ELSE
								Basic.ToSegmentedName ("BaseTypes.Record",name);
							END;
							tir := implementationEmitter.NewSection(module.importedSections, Sections.ConstSection, name,NIL,declarationEmitter.dump);
							Symbol(source, tir,  0, 0);
						END;

						Info(source, "base record descriptor");
						Symbol(source, base, 0, 0);
						CooperativeMethodTable(TRUE);

						IF recordType.hasPointers THEN
							IF ~HasExplicitTraceMethod (recordType) THEN
								implementationEmitter.CreateTraceMethod(recordType);
							END;
							implementationEmitter.CreateResetProcedure(recordType);
							implementationEmitter.CreateAssignProcedure(recordType);
						END;
					ELSIF ~simple THEN
						(*

										MethodEnd = MPO
										---
										methods (# methods)
										---
										tags (16)
										---
										TypeDesc = TypeInfoAdr
										---
						td adr ---> rec size
										----
										pointer offsets
										----
										(padding)
										-----
										empty [2 addresses aligned]
										empty
										empty
										numPtrs
										---
										pointer offsets
										---
						*)

						Info(source, "MethodEnd = MPO");
						IntermediateCode.InitImmediate(op,IntermediateCode.GetType(module.system, module.system.addressType),MPO);
						source(IntermediateCode.Section).Emit(Data(Basic.invalidPosition,op));

						MethodTable(TRUE);
						TdTable(TypeTags, TRUE);
						Info(source, "type descriptor info pointer");
						tdInfo := NewTypeDescriptorInfo(source,source.pc+1,recordType.IsProtected());
						Symbol(source, tdInfo,EmptyBlockOffset,0);
						IF (cellType # NIL) THEN
							IF cellType.sizeInBits < 0 THEN
								ASSERT(module.system.GenerateVariableOffsets(cellType.cellScope));
							END;
							Info(source, "cell size");
							Address(source, ToMemoryUnits(module.system,cellType.sizeInBits));
						ELSE
							Info(source, "record size");
							Address(source, ToMemoryUnits(module.system,module.system.SizeOf(recordType)));
						END;
						Info(source, "pointer offsets pointer");
						padding := 1- source.pc MOD 2;
						Symbol(source, source, source.pc+1+padding,0);
						IF padding >0 THEN
							Info(source, "padding");
							FOR i := 1 TO padding DO Address(source,0) END;
						END;
						IF cellType # NIL THEN
							PointerArray(source, cellType.cellScope, numberPointers);
						ELSE
							PointerArray(source, recordType.recordScope, numberPointers);
						END;
					ELSE
						(*
							simple:
							td adr --> size
											tag(1)
											tag(2)
											tag(3)
							methods ->
						*)
						Info(source, "record size");
						Address(source, ToMemoryUnits(module.system,module.system.SizeOf(recordType)));
						TdTable(TypeTags, FALSE);
						MethodTable(FALSE);
					END;
			END NewTypeDescriptor;

		BEGIN
			x := x.resolved;
			IF (x IS SyntaxTree.PointerType) THEN
				x := x(SyntaxTree.PointerType).pointerBase.resolved;
			END;

			IF (x IS SyntaxTree.RecordType) THEN (* enter: insert only if not already inserted *)
				recordType := x(SyntaxTree.RecordType);
				td := x.typeDeclaration;
				IF td = NIL THEN td := recordType.pointerType.resolved.typeDeclaration END; (* for compatibility with paco *)
				ASSERT(td # NIL);

				section := module.allSections.FindBySymbol(td); (* TODO *)
				IF (section = NIL) OR (section(IntermediateCode.Section).pc = 0) THEN
					IF (td.scope = NIL) OR (td.scope.ownerModule = module.module) THEN
						NewTypeDescriptor
					END;
				END;
			ELSIF (x IS SyntaxTree.CellType) & implementationEmitter.backend.cellsAreObjects THEN
				cellType := x(SyntaxTree.CellType);
				td := x.typeDeclaration;
				section := module.allSections.FindBySymbol(td); (* TODO *)
				IF (section = NIL) OR (section(IntermediateCode.Section).pc = 0) THEN
					IF (td.scope = NIL) OR (td.scope.ownerModule = module.module) THEN
						NewTypeDescriptor
					END;
				END;
			END
		END CheckTypeDeclaration

	END MetaDataGenerator;

	IntermediateBackend*= OBJECT (IntermediateCode.IntermediateBackend)
	VAR
		trace-: BOOLEAN;
		traceString-: SyntaxTree.IdentifierString;
		traceModuleName-: SyntaxTree.IdentifierString;
		profile-: BOOLEAN;
		noRuntimeChecks: BOOLEAN;
		simpleMetaData-: BOOLEAN;
		noAsserts: BOOLEAN;
		optimize-: BOOLEAN;
		cooperative-: BOOLEAN;
		preregisterStatic-: BOOLEAN;
		dump-: Basic.Writer;
		cellsAreObjects: BOOLEAN;
		preciseGC, trackLeave, writeBarriers: BOOLEAN;
		experiment: BOOLEAN;

		PROCEDURE &InitIntermediateBackend*;
		BEGIN
			simpleMetaData := FALSE;
			InitBackend;
			SetBuiltinsModuleName(DefaultBuiltinsModuleName);
			SetTraceModuleName(DefaultTraceModuleName);
		END InitIntermediateBackend;

		(* must be overwritten by actual backend, if parameter registers should be used *)
		PROCEDURE GetParameterRegister*(callingConvention: SyntaxTree.CallingConvention; type: IntermediateCode.Type; VAR register: WORD): BOOLEAN;
		BEGIN
			register := -1;
			RETURN FALSE;
		END GetParameterRegister;

		PROCEDURE ResetParameterRegisters*;
		BEGIN
		END ResetParameterRegisters;

		PROCEDURE GenerateIntermediate*(x: SyntaxTree.Module; supportedInstruction: SupportedInstructionProcedure; supportedImmediate: SupportedImmediateProcedure): Sections.Module;
		VAR
			declarationEmitter: DeclarationEmitter;
			implementationEmitter: ImplementationEmitter;
			module: Sections.Module;
			name, platformName: SyntaxTree.IdentifierString;
			meta: MetaDataGenerator;
			crc: CRC.CRC32Stream;
		BEGIN
			ResetError;
			Global.GetSymbolName(x,name);

			NEW(module,x,system); (* backend structures *)

			Global.GetModuleName(x, name);
			module.SetModuleName(name);

			NEW(implementationEmitter,system,checker,supportedInstruction, supportedImmediate, Compiler.FindPC IN flags, builtinsModuleName, SELF);
			NEW(declarationEmitter,system,implementationEmitter,SELF,Compiler.ForceModuleBodies IN flags,trace & (Compiler.Info IN flags));

			NEW(meta, implementationEmitter, declarationEmitter,simpleMetaData);
			declarationEmitter.Module(x,module);

			IF ~meta.simple THEN
				meta.Module(implementationEmitter.moduleBodySection);
			END;

			GetDescription(platformName);
			module.SetPlatformName(platformName);

			NEW(crc);
			module.allSections.WriteRaw(crc);
			crc.Update;
			meta.PatchCRC(crc.GetCRC());

			RETURN module
		END GenerateIntermediate;

		PROCEDURE SupportedImmediate*(CONST op: IntermediateCode.Operand): BOOLEAN;
		BEGIN RETURN TRUE
		END SupportedImmediate;

		PROCEDURE ProcessSyntaxTreeModule*(syntaxTreeModule: SyntaxTree.Module): Formats.GeneratedModule;
		BEGIN RETURN ProcessIntermediateCodeModule(GenerateIntermediate(syntaxTreeModule, SupportedInstruction, SupportedImmediate))
		END ProcessSyntaxTreeModule;

		PROCEDURE ProcessIntermediateCodeModule*(intermediateCodeModule: Formats.GeneratedModule): Formats.GeneratedModule;
		VAR
			result: Sections.Module;
			traceName: Basic.MessageString;
		BEGIN
			ASSERT(intermediateCodeModule IS Sections.Module);
			result := intermediateCodeModule(Sections.Module);

			IF trace THEN
				traceName := "intermediate code trace: ";
				Strings.Append(traceName,traceString);
				dump := Basic.GetWriter(Basic.GetDebugWriter(traceName));
				IF (traceString="") OR (traceString="*") THEN
					result.Dump(dump);
					dump.Update
				ELSE
					Sections.DumpFiltered(dump, result, traceString);
				END
			END;
			RETURN result
		END ProcessIntermediateCodeModule;

		PROCEDURE GetDescription*(VAR instructionSet: ARRAY OF CHAR);
		BEGIN instructionSet := "Intermediate";
		END GetDescription;

		PROCEDURE SetSimpleMetaData*(simpleMetaData: BOOLEAN);
		BEGIN
			SELF.simpleMetaData := simpleMetaData;
		END SetSimpleMetaData;

		PROCEDURE SetTraceModuleName(CONST name: ARRAY OF CHAR);
		BEGIN COPY(name, traceModuleName)
		END SetTraceModuleName;

		PROCEDURE DefineOptions*(options: Options.Options);
		BEGIN
			DefineOptions^(options);
			options.Add(0X,"trace",Options.String);
			options.Add(0X,"builtinsModule",Options.String);
			options.Add(0X,"traceModule",Options.String);
			options.Add(0X,"profile",Options.Flag);
			options.Add(0X,"noRuntimeChecks",Options.Flag);
			options.Add(0X,"noAsserts",Options.Flag);
			options.Add(0X,"metaData",Options.String);
			options.Add('o',"optimize", Options.Flag);
			options.Add(0X,"preregisterStatic", Options.Flag);
			options.Add(0X,"cellsAreObjects", Options.Flag);
			options.Add(0X,"preciseGC", Options.Flag);
			options.Add(0X,"trackLeave", Options.Flag);
			options.Add(0X,"writeBarriers", Options.Flag);
			options.Add(0X,"experiment", Options.Flag);
		END DefineOptions;

		PROCEDURE GetOptions*(options: Options.Options);
		VAR name,string: SyntaxTree.IdentifierString;
		BEGIN
			GetOptions^(options);
			trace := options.GetString("trace",traceString);
			profile := options.GetFlag("profile");
			noRuntimeChecks := options.GetFlag("noRuntimeChecks");
			noAsserts := options.GetFlag("noAsserts");
			cooperative := options.GetFlag("cooperative");
			IF options.GetString("objectFile",string) & (string = "Minos") THEN
				simpleMetaData := TRUE
			END;
			IF options.GetString("metaData",string) THEN
				IF string = "simple" THEN simpleMetaData := TRUE
				ELSIF string ="full" THEN simpleMetaData := FALSE
				END;
			END;
			IF options.GetString("builtinsModule",name) THEN SetBuiltinsModuleName(name) END;
			IF options.GetString("traceModule",name) THEN SetTraceModuleName(name) END;
			optimize := options.GetFlag("optimize");
			preregisterStatic := options.GetFlag("preregisterStatic");
			cellsAreObjects := options.GetFlag("cellsAreObjects");
			preciseGC := options.GetFlag("preciseGC");
			trackLeave := options.GetFlag("trackLeave");
			writeBarriers := options.GetFlag("writeBarriers");
			experiment := options.GetFlag("experiment");
			IF simpleMetaData THEN preciseGC := FALSE END;
		END GetOptions;

		PROCEDURE DefaultSymbolFileFormat*(): Formats.SymbolFileFormat;
		BEGIN RETURN SymbolFileFormat.Get()
		END DefaultSymbolFileFormat;

	END IntermediateBackend;

	(* ----------------------------------- register allocation ------------------------------------- *)

		(* register mapping scheme
			virtual register number	--> register mapping   =		part(0)		-->	ticket	<-->	physical register
																											spill offset

																	part(n)		-->	ticket	<-->	physical register
																											spill offset
		*)

	VAR int8-, int16-, int32-, int64-, uint8-, uint16-, uint32-, uint64-, float32-, float64-: IntermediateCode.Type;
		emptyOperand: IntermediateCode.Operand;
		systemCalls: ARRAY NumberSystemCalls OF SyntaxTree.Symbol;
		statCoopResetVariables: LONGINT;
		statCoopModifyAssignments: LONGINT;
		modifyAssignmentsPC : LONGINT;
		statCoopNilCheck: LONGINT;
		statCoopSwitch: LONGINT;
		statCoopAssignProcedure: LONGINT;
		statCoopTraceMethod: LONGINT;
		statCoopResetProcedure: LONGINT;
		statCoopTraceModule: LONGINT;
		ResultDesignatorName: SyntaxTree.Identifier;

	PROCEDURE ResetStatistics*;
	BEGIN
		statCoopResetVariables := 0;
		statCoopModifyAssignments := 0;
		statCoopNilCheck:= 0;
		statCoopSwitch:= 0;
		statCoopAssignProcedure:= 0;
		statCoopTraceMethod:= 0;
		statCoopResetProcedure:= 0;
		statCoopTraceModule:= 0;
	END ResetStatistics;

	PROCEDURE Statistics*;
	BEGIN
		TRACE(statCoopResetVariables, statCoopModifyAssignments);
		TRACE(statCoopNilCheck, statCoopSwitch);
		TRACE(statCoopAssignProcedure,
		statCoopTraceMethod,
		statCoopResetProcedure,
		statCoopTraceModule)
	END Statistics;

	PROCEDURE GCD(a,b: LONGINT): LONGINT;
	VAR h: LONGINT;
	BEGIN
		WHILE b # 0 DO
			h := a MOD b;
			a := b;
			b := h;
		END;
		RETURN a
	END GCD;

	PROCEDURE SCM(a,b: LONGINT): LONGINT;
	BEGIN
		RETURN a*b DIV GCD(a,b)
	END SCM;

	PROCEDURE CommonAlignment(a,b: LONGINT): LONGINT;
	BEGIN
		(*TRACE(a,b);*)
		IF a = 0 THEN RETURN b
		ELSIF b = 0 THEN RETURN a
		ELSE RETURN SCM(a,b)
		END;
	END CommonAlignment;

	PROCEDURE PassBySingleReference(parameter: SyntaxTree.Parameter; callingConvention: SyntaxTree.CallingConvention): BOOLEAN;
	BEGIN
		IF parameter.kind = SyntaxTree.ValueParameter THEN RETURN FALSE
		ELSIF parameter.kind = SyntaxTree.ConstParameter THEN
			RETURN (parameter.type.resolved IS SyntaxTree.RecordType) OR (parameter.type.resolved IS SyntaxTree.ArrayType) & (callingConvention IN SysvABIorWINAPI)
		ELSIF parameter.kind = SyntaxTree.VarParameter THEN
			RETURN ~(parameter.type.resolved IS SyntaxTree.ArrayType) & ~(parameter.type.resolved IS SyntaxTree.MathArrayType) OR (parameter.type.resolved IS SyntaxTree.ArrayType) & (callingConvention IN SysvABIorWINAPI)
		END
	END PassBySingleReference;

	PROCEDURE PassInRegister(parameter: SyntaxTree.Parameter; callingConvention: SyntaxTree.CallingConvention): BOOLEAN;
	BEGIN
		RETURN  ~parameter.type.IsComposite() OR PassBySingleReference(parameter,callingConvention)
	END PassInRegister;

	PROCEDURE AddRegisterEntry(VAR queue: RegisterEntry; register: LONGINT; class: IntermediateCode.RegisterClass; type: IntermediateCode.Type);
	VAR new: RegisterEntry;
	BEGIN
		NEW(new); new.register := register; new.registerClass := class; new.type := type; new.next := NIL; new.prev := NIL;
		IF queue = NIL THEN
			queue := new
		ELSE
			new.next := queue;
			IF queue#NIL THEN queue.prev := new END;
			queue := new
		END;
	END AddRegisterEntry;

	PROCEDURE RemoveRegisterEntry(VAR queue: RegisterEntry; register: LONGINT): BOOLEAN;
	VAR this: RegisterEntry;
	BEGIN
		this := queue;
		WHILE (this # NIL) & (this.register # register) DO
			this := this.next;
		END;
		IF this = NIL THEN
			RETURN FALSE
		END;
		ASSERT(this # NIL);
		IF this = queue THEN queue := queue.next END;
		IF this.prev # NIL THEN this.prev.next := this.next END;
		IF this.next # NIL THEN this.next.prev := this.prev END;
		RETURN TRUE
	END RemoveRegisterEntry;

	PROCEDURE Assert(cond: BOOLEAN; CONST reason: ARRAY OF CHAR);
	BEGIN ASSERT(cond);
	END Assert;

	PROCEDURE ReusableRegister(op: IntermediateCode.Operand): BOOLEAN;
	BEGIN
		RETURN (op.mode = IntermediateCode.ModeRegister) & (op.register > 0) & (op.offset = 0);
	END ReusableRegister;

	PROCEDURE EnsureBodyProcedure(moduleScope: SyntaxTree.ModuleScope);
	VAR procedure: SyntaxTree.Procedure; procedureScope: SyntaxTree.ProcedureScope;
	BEGIN
		procedure := moduleScope.bodyProcedure;
		IF procedure = NIL THEN (* artificially add body procedure if not existing. Really needed? *)
			procedureScope := SyntaxTree.NewProcedureScope(moduleScope);
			procedure := SyntaxTree.NewProcedure(Basic.invalidPosition,Global.ModuleBodyName, procedureScope);
			procedure.SetScope(moduleScope);
			procedure.SetType(SyntaxTree.NewProcedureType(Basic.invalidPosition,moduleScope));
			procedure.SetAccess(SyntaxTree.Hidden);
			moduleScope.SetBodyProcedure(procedure);
			moduleScope.AddProcedure(procedure);
			procedureScope.SetBody(SyntaxTree.NewBody(Basic.invalidPosition,procedureScope)); (* empty body *)
		END;
	END EnsureBodyProcedure;

	PROCEDURE GetSymbol*(scope: SyntaxTree.ModuleScope; CONST moduleName, symbolName: ARRAY OF CHAR): SyntaxTree.Symbol;
	VAR import: SyntaxTree.Import;
		selfName: SyntaxTree.IdentifierString;
		module: SyntaxTree.Module;
	BEGIN
		scope.ownerModule.GetName(selfName);
		IF (moduleName = selfName) & (scope.ownerModule.context = Global.A2Name) THEN
			module := scope.ownerModule
		ELSE
			import := scope.ImportByModuleName(SyntaxTree.NewIdentifier(moduleName),SyntaxTree.NewIdentifier("A2"));
			IF import = NIL THEN
				RETURN NIL
			ELSIF import.module = NIL THEN
				RETURN NIL
			ELSE module := import.module
			END;
		END;
		RETURN module.moduleScope.FindSymbol(SyntaxTree.NewIdentifier(symbolName));
	END GetSymbol;

	PROCEDURE InitOperand(VAR op: Operand; mode: SHORTINT);
	BEGIN
		op.mode := mode;
		IntermediateCode.InitOperand(op.op);
		IntermediateCode.InitOperand(op.tag);
		IntermediateCode.InitOperand(op.extra);
		op.dimOffset := 0;
		op.availability := -1;
	END InitOperand;

	(* TODO: remove this, and redirect calls to 'IntermediateCode.GetType' directly *)
	PROCEDURE GetType*(system: Global.System; type: SyntaxTree.Type): IntermediateCode.Type;
	BEGIN RETURN IntermediateCode.GetType(system, type)
	END GetType;

	PROCEDURE FindConstant(module: SyntaxTree.Module; value: SyntaxTree.Value): SyntaxTree.Constant;
	VAR constant: SyntaxTree.Constant;
	BEGIN
		constant := module.moduleScope.firstConstant;
		WHILE (constant # NIL) & ~value.Equals(constant.value) DO
			constant := constant.nextConstant;
		END;
		RETURN constant
	END FindConstant;

	PROCEDURE BuildConstant(module: SyntaxTree.Module; value: SyntaxTree.Value; VAR adr: LONGINT): SyntaxTree.Constant;
	VAR name: SyntaxTree.IdentifierString; constant: SyntaxTree.Constant;
	BEGIN
		(*
		UniqueId(name,module,name,adr);
		*)
		constant := FindConstant(module, value);
		IF constant = NIL THEN
			name := "@const"; Basic.AppendNumber(name, adr); INC(adr);
			constant := SyntaxTree.NewConstant(Basic.invalidPosition,SyntaxTree.NewIdentifier(name));
			constant.SetValue(value);
			constant.SetAccess(SyntaxTree.Hidden);
			module.moduleScope.AddConstant(constant);
			constant.SetScope(module.moduleScope);
		END;
		RETURN constant
	END BuildConstant;

	PROCEDURE HasPointers (scope: SyntaxTree.ProcedureScope): BOOLEAN;
	VAR variable: SyntaxTree.Variable; parameter: SyntaxTree.Parameter;
	BEGIN
		variable := scope.firstVariable;
		WHILE variable # NIL DO
			IF variable.NeedsTrace() THEN
				RETURN TRUE;
			END;
			variable := variable.nextVariable;
		END;
		parameter := scope.ownerProcedure.type(SyntaxTree.ProcedureType).firstParameter;
		WHILE parameter # NIL DO
			IF parameter.NeedsTrace() & ~IsVariableParameter(parameter)  & (parameter.kind # SyntaxTree.ConstParameter) THEN
				RETURN TRUE;
			END;
			parameter := parameter.nextParameter;
		END;
		RETURN FALSE;
	END HasPointers;

	PROCEDURE IsVariableParameter (parameter: SyntaxTree.Parameter): BOOLEAN;
	BEGIN RETURN (parameter.kind = SyntaxTree.VarParameter) OR (parameter.kind = SyntaxTree.ConstParameter) & ((parameter.type.resolved IS SyntaxTree.RecordType) OR (parameter.type.resolved IS SyntaxTree.ArrayType) OR (parameter.type.resolved IS SyntaxTree.MathArrayType));
	END IsVariableParameter;

	PROCEDURE HasVariableParameters(scope: SyntaxTree.ProcedureScope): BOOLEAN;
	VAR parameter: SyntaxTree.Parameter;
	BEGIN
		parameter := scope.ownerProcedure.type(SyntaxTree.ProcedureType).firstParameter;
		WHILE parameter # NIL DO
			IF IsVariableParameter (parameter) THEN RETURN TRUE END;
			IF parameter.movable THEN RETURN TRUE END;
			parameter := parameter.nextParameter;
		END;
		RETURN scope.ownerProcedure.type(SyntaxTree.ProcedureType).returnParameter # NIL;
	END HasVariableParameters;

	PROCEDURE HasExplicitTraceMethod(recordType: SyntaxTree.RecordType): BOOLEAN;
	BEGIN
		IF (recordType.pointerType # NIL) & ~recordType.pointerType.isPlain THEN RETURN FALSE END;
		RETURN (recordType.recordScope.firstProcedure # NIL) & Basic.StringEqual (Basic.MakeString ("Trace"), recordType.recordScope.firstProcedure.name);
	END HasExplicitTraceMethod;

	PROCEDURE IsIntegerConstant(expression: SyntaxTree.Expression; VAR val: HUGEINT): BOOLEAN;
	BEGIN
		IF expression.resolved # NIL THEN expression := expression.resolved END;

		IF  (expression IS SyntaxTree.IntegerValue)  THEN
			val := expression(SyntaxTree.IntegerValue).value;
			RETURN TRUE
		ELSE
			RETURN FALSE
		END;
	END IsIntegerConstant;

	PROCEDURE PowerOf2*(val: HUGEINT;  VAR exp: LONGINT): BOOLEAN;
	BEGIN
		IF val <= 0 THEN RETURN FALSE END;
		exp := 0;
		WHILE ~ODD(val) DO
			val := val DIV 2;
			INC(exp)
		END;
		RETURN val = 1
	END PowerOf2;

	PROCEDURE GetConstructor(record: SyntaxTree.RecordType): SyntaxTree.Procedure;
	VAR procedure: SyntaxTree.Procedure;
	BEGIN
		procedure := record.recordScope.constructor;
		IF procedure = NIL THEN
			record := record.GetBaseRecord();
			IF record # NIL THEN
				procedure := GetConstructor(record)
			END;
		END;
		RETURN procedure;
	END GetConstructor;

	PROCEDURE IsIntegerImmediate(CONST op: IntermediateCode.Operand; VAR value: LONGINT): BOOLEAN;
	BEGIN
		value := SHORT(op.intValue);
		RETURN op.mode = IntermediateCode.ModeImmediate;
	END IsIntegerImmediate;

	(** whether a type strictily is a pointer to record or object type
	(however, the basic type <<OBJECT>> is explicitly excluded) **)
	PROCEDURE IsStrictlyPointerToRecord(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		IF type = NIL THEN
			RETURN FALSE
		ELSIF type.resolved IS SyntaxTree.PointerType THEN
			RETURN type.resolved(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.RecordType
		ELSE
			RETURN FALSE
		END
	END IsStrictlyPointerToRecord;

	PROCEDURE IsUnsafePointer(type: SyntaxTree.Type): BOOLEAN;
	BEGIN RETURN (type # NIL) & (type.resolved IS SyntaxTree.PointerType) & type.resolved(SyntaxTree.PointerType).isUnsafe
	END IsUnsafePointer;

	PROCEDURE IsPointerToRecord(type: SyntaxTree.Type; VAR recordType: SyntaxTree.RecordType): BOOLEAN;
	BEGIN type := type.resolved;
		IF type IS SyntaxTree.PointerType THEN
			type := type(SyntaxTree.PointerType).pointerBase;
			type := type.resolved;
			IF type IS SyntaxTree.RecordType THEN
				recordType := type(SyntaxTree.RecordType);
				RETURN TRUE
			ELSE
				RETURN FALSE
			END
		ELSIF type IS SyntaxTree.RecordType THEN
			recordType := type(SyntaxTree.RecordType);
			RETURN type(SyntaxTree.RecordType).pointerType # NIL
		ELSIF type IS SyntaxTree.ObjectType THEN
			RETURN TRUE
		ELSIF type IS SyntaxTree.AnyType THEN
			RETURN TRUE (*! potentially is a pointer to record, treat it this way?? *)
		ELSE
			RETURN FALSE
		END;
	END IsPointerToRecord;

	PROCEDURE IsArrayOfSystemByte(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		type := type.resolved;
		RETURN (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).form = SyntaxTree.Open)
		& (type(SyntaxTree.ArrayType).arrayBase.resolved IS SyntaxTree.ByteType);
	END IsArrayOfSystemByte;

	PROCEDURE IsOpenArray(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		IF type = NIL THEN RETURN FALSE END;
		type := type.resolved;
		RETURN (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).form = SyntaxTree.Open);
	END IsOpenArray;

	PROCEDURE IsSemiDynamicArray(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		IF type = NIL THEN RETURN FALSE END;
		type := type.resolved;
		RETURN (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).form = SyntaxTree.SemiDynamic);
	END IsSemiDynamicArray;

	PROCEDURE IsStaticArray(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		IF type = NIL THEN RETURN FALSE END;
		type := type.resolved;
		RETURN (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).form = SyntaxTree.Static);
	END IsStaticArray;

	PROCEDURE IsStaticMathArray(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		IF type = NIL THEN RETURN FALSE END;
		type := type.resolved;
		RETURN (type IS SyntaxTree.MathArrayType) & (type(SyntaxTree.MathArrayType).form = SyntaxTree.Static);
	END IsStaticMathArray;

	PROCEDURE StaticMathArrayBaseType(type: SyntaxTree.Type): SyntaxTree.Type;
	BEGIN
		WHILE (IsStaticMathArray(type)) DO
			type := type.resolved(SyntaxTree.MathArrayType).arrayBase;
		END;
		RETURN type;
	END StaticMathArrayBaseType;

	PROCEDURE StaticArrayNumElements(type: SyntaxTree.Type): LONGINT;
	VAR size: LONGINT;
	BEGIN
		size := 1;
		WHILE (IsStaticArray(type)) DO
			size := size * type.resolved(SyntaxTree.ArrayType).staticLength;
			type := type.resolved(SyntaxTree.ArrayType).arrayBase;
		END;
		RETURN size;
	END StaticArrayNumElements;

	PROCEDURE StaticMathArrayNumElements(type: SyntaxTree.Type): LONGINT;
	VAR size: LONGINT;
	BEGIN
		size := 1;
		WHILE (IsStaticMathArray(type)) DO
			size := size * type.resolved(SyntaxTree.MathArrayType).staticLength;
			type := type.resolved(SyntaxTree.MathArrayType).arrayBase;
		END;
		RETURN size;
	END StaticMathArrayNumElements;

	PROCEDURE StaticArrayBaseType(type: SyntaxTree.Type): SyntaxTree.Type;
	BEGIN
		WHILE (IsStaticArray(type)) DO
			type := type.resolved(SyntaxTree.ArrayType).arrayBase;
		END;
		RETURN type;
	END StaticArrayBaseType;

	PROCEDURE ArrayBaseType(type: SyntaxTree.Type): SyntaxTree.Type;
	BEGIN
		WHILE (type.resolved IS SyntaxTree.ArrayType) DO
			type := type.resolved(SyntaxTree.ArrayType).arrayBase;
		END;
		RETURN type;
	END ArrayBaseType;

	PROCEDURE IsDelegate(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		IF type = NIL THEN RETURN FALSE END;
		type := type.resolved;
		RETURN (type IS SyntaxTree.ProcedureType) & (type(SyntaxTree.ProcedureType).isDelegate)
	END IsDelegate;

	PROCEDURE DynamicDim(type:SyntaxTree.Type): LONGINT;
	VAR i: LONGINT;
	BEGIN
		i := 0; type := type.resolved;
		WHILE(type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).form # SyntaxTree.Static) DO
			INC(i);
			type := type(SyntaxTree.ArrayType).arrayBase.resolved;
		END;
		WHILE(type # NIL) & (type IS SyntaxTree.MathArrayType) & (type(SyntaxTree.MathArrayType).form # SyntaxTree.Static) DO
			INC(i);
			type := type(SyntaxTree.MathArrayType).arrayBase;
			IF type # NIL THEN type := type.resolved END;
		END;
		RETURN i
	END DynamicDim;

	PROCEDURE StaticSize(system: Global.System; type: SyntaxTree.Type): LONGINT;
	BEGIN
		WHILE (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).form # SyntaxTree.Static) DO
			type := type(SyntaxTree.ArrayType).arrayBase;
		END;
		WHILE (type IS SyntaxTree.MathArrayType) & (type(SyntaxTree.MathArrayType).form # SyntaxTree.Static) DO
			type := type(SyntaxTree.MathArrayType).arrayBase;
		END;
		RETURN ToMemoryUnits(system,system.AlignedSizeOf(type));
	END StaticSize;

	PROCEDURE IsImmediate(x: IntermediateCode.Operand): BOOLEAN;
	BEGIN
		RETURN (x.mode = IntermediateCode.ModeImmediate)  & (x.symbol.name = "");
	END IsImmediate;

	PROCEDURE IsAddress(x: IntermediateCode.Operand): BOOLEAN;
	BEGIN
		RETURN (x.mode = IntermediateCode.ModeImmediate) & (x.symbol.name # "")
	END IsAddress;

	PROCEDURE IsRegister(x: IntermediateCode.Operand): BOOLEAN;
	BEGIN
		RETURN (x.mode = IntermediateCode.ModeRegister);
	END IsRegister;

	PROCEDURE GetRecordTypeName(recordType: SyntaxTree.RecordType; VAR name: Basic.SegmentedName);
	VAR typeDeclaration: SyntaxTree.TypeDeclaration;
	BEGIN
		typeDeclaration := recordType.typeDeclaration;
		IF typeDeclaration = NIL THEN typeDeclaration := recordType.pointerType.resolved.typeDeclaration END; (* for compatibility with paco *)
		Global.GetSymbolSegmentedName(typeDeclaration,name);
	END GetRecordTypeName;

	PROCEDURE ParametersSize(system: Global.System; procedureType: SyntaxTree.ProcedureType; isNested: BOOLEAN): LONGINT;
	VAR parSize: LONGINT; parameter: SyntaxTree.Parameter;
	BEGIN
		parSize := 0;

		IF SemanticChecker.StructuredReturnType(system,procedureType) THEN
			parameter := procedureType.returnParameter;
			INC(parSize,system.SizeOfParameter(parameter));
			parSize := parSize + (-parSize) MOD system.addressSize;
		END;

		parameter :=procedureType.lastParameter;
		WHILE (parameter # NIL) DO
			IF procedureType.callingConvention IN SysvABIorWINAPI THEN
				INC(parSize, system.addressSize);
			ELSE
				INC(parSize,system.SizeOfParameter(parameter));
				parSize := parSize + (-parSize) MOD system.addressSize;
			END;
			parameter := parameter.prevParameter;
		END;

		IF procedureType.selfParameter # NIL THEN
			parameter := procedureType.selfParameter;
			INC(parSize,system.SizeOfParameter(parameter));
			parSize := parSize + (-parSize) MOD system.addressSize;
		ELSIF procedureType.isDelegate THEN INC(parSize,system.addressSize)
		END; (* method => self pointer *)

		IF isNested THEN INC(parSize,system.addressSize) END; (* nested procedure => static base *)

		RETURN ToMemoryUnits(system,parSize)
	END ParametersSize;

	PROCEDURE IsNested(procedure: SyntaxTree.Procedure): BOOLEAN;
	BEGIN
		RETURN (procedure.scope IS SyntaxTree.ProcedureScope) & (procedure.externalName = NIL);
	END IsNested;

	PROCEDURE InCellScope(scope: SyntaxTree.Scope): BOOLEAN;
	BEGIN
		WHILE (scope # NIL) & ~(scope IS SyntaxTree.CellScope) DO
			scope := scope.outerScope;
		END;
		RETURN scope # NIL;
	END InCellScope;

	PROCEDURE ProcedureParametersSize*(system: Global.System; procedure: SyntaxTree.Procedure): LONGINT;
	BEGIN
		RETURN ParametersSize(system,procedure.type(SyntaxTree.ProcedureType), IsNested(procedure));
	END ProcedureParametersSize;

	PROCEDURE ToMemoryUnits*(system: Global.System; size: SIZE): LONGINT;
	VAR dataUnit: LONGINT;
	BEGIN dataUnit := system.dataUnit;

		ASSERT(size MOD system.dataUnit = 0);
		RETURN LONGINT(size DIV system.dataUnit)
	END ToMemoryUnits;

	PROCEDURE Get*(): Backend.Backend;
	VAR backend: IntermediateBackend;
	BEGIN NEW(backend); RETURN backend
	END Get;

	PROCEDURE Nop(position: Basic.Position):IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.nop,emptyOperand,emptyOperand,emptyOperand);
		RETURN instruction
	END Nop;

	PROCEDURE Use(position: Basic.Position; reg: IntermediateCode.Operand):IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.nop,reg,emptyOperand,emptyOperand);
		RETURN instruction
	END Use;

	PROCEDURE Mov(position: Basic.Position;dest,src: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.mov,dest,src,emptyOperand);
		RETURN instruction
	END Mov;

	(* like Mov but ensures that no new register will be allocated for dest *)
	PROCEDURE MovReplace(position: Basic.Position;dest,src: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.mov,dest,src,dest);
		RETURN instruction
	END MovReplace;

	PROCEDURE Conv(position: Basic.Position;dest,src: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.conv,dest,src,emptyOperand);
		RETURN instruction
	END Conv;

	PROCEDURE Call*(position: Basic.Position;op: IntermediateCode.Operand; parSize: LONGINT): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.call,op,IntermediateCode.Number(parSize),emptyOperand);
		RETURN instruction
	END Call;

	PROCEDURE Exit(position: Basic.Position;pcOffset: LONGINT; callingConvention, unwind: LONGINT): IntermediateCode.Instruction;
	VAR op1, op2, op3: IntermediateCode.Operand;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitNumber(op1,pcOffset);
		IntermediateCode.InitNumber(op2,callingConvention);
		IntermediateCode.InitNumber(op3,unwind);
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.exit,op1,op2,op3);
		RETURN instruction
	END Exit;

	PROCEDURE Return(position: Basic.Position;res: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.return,res,emptyOperand,emptyOperand);
		RETURN instruction
	END Return;

	PROCEDURE Result*(position: Basic.Position;res: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.result,res,emptyOperand,emptyOperand);
		RETURN instruction
	END Result;

	PROCEDURE Trap(position: Basic.Position;nr: LONGINT): IntermediateCode.Instruction;
	VAR op1: IntermediateCode.Operand;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitNumber(op1,nr);
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.trap,op1,emptyOperand,emptyOperand);
		RETURN instruction
	END Trap;

	PROCEDURE Br(position: Basic.Position;dest: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.br,dest,emptyOperand,emptyOperand);
		RETURN instruction
	END Br;

	PROCEDURE Breq(position: Basic.Position;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.breq,dest,left,right);
		RETURN instruction
	END Breq;

	PROCEDURE Brne(position: Basic.Position;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.brne,dest,left,right);
		RETURN instruction
	END Brne;

	PROCEDURE Brge(position: Basic.Position;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.brge,dest,left,right);
		RETURN instruction
	END Brge;

	PROCEDURE Brlt(position: Basic.Position;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.brlt,dest,left,right);
		RETURN instruction
	END Brlt;

	PROCEDURE Pop*(position: Basic.Position;op:IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.pop,op,emptyOperand,emptyOperand);
		RETURN instruction
	END Pop;

	PROCEDURE Push*(position: Basic.Position;op: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		ASSERT(op.mode # IntermediateCode.Undefined);
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.push,op,emptyOperand,emptyOperand);
		RETURN instruction
	END Push;

	PROCEDURE Neg(position: Basic.Position;dest,src: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position, IntermediateCode.neg,dest,src,emptyOperand);
		RETURN instruction
	END Neg;

	PROCEDURE Not(position: Basic.Position;dest,src: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.not,dest,src,emptyOperand);
		RETURN instruction
	END Not;

	PROCEDURE Abs(position: Basic.Position;dest,src: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.abs,dest,src,emptyOperand);
		RETURN instruction
	END Abs;

	PROCEDURE Mul(position: Basic.Position;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.mul,dest,left,right);
		ASSERT(~IsImmediate(instruction.op1));
		RETURN instruction
	END Mul;

	PROCEDURE Div(position: Basic.Position;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.div,dest,left,right);
		RETURN instruction
	END Div;

	PROCEDURE Mod(position: Basic.Position;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.mod,dest,left,right);
		RETURN instruction
	END Mod;

	PROCEDURE Sub(position: Basic.Position;dest: IntermediateCode.Operand; left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.sub,dest,left,right);
		RETURN instruction
	END Sub;

	PROCEDURE Add(position: Basic.Position;dest: IntermediateCode.Operand; left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.add,dest,left,right);
		RETURN instruction
	END Add;

	PROCEDURE And(position: Basic.Position;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.and,dest,left,right);
		RETURN instruction
	END And;

	PROCEDURE Or(position: Basic.Position;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.or,dest,left,right);
		RETURN instruction
	END Or;

	PROCEDURE Xor(position: Basic.Position;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.xor,dest,left,right);
		RETURN instruction
	END Xor;

	PROCEDURE Shl(position: Basic.Position;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.shl,dest,left, IntermediateCode.ToUnsigned(right));
		RETURN instruction
	END Shl;

	PROCEDURE Shr(position: Basic.Position;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.shr,dest,left, IntermediateCode.ToUnsigned(right));
		RETURN instruction
	END Shr;

	PROCEDURE Rol(position: Basic.Position;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.rol,dest,left, IntermediateCode.ToUnsigned(right));
		RETURN instruction
	END Rol;

	PROCEDURE Ror(position: Basic.Position;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.ror,dest,left, IntermediateCode.ToUnsigned(right));
		RETURN instruction
	END Ror;

	PROCEDURE Cas(position: Basic.Position;dest,src,size: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.cas,dest,src,size);
		RETURN instruction
	END Cas;

	PROCEDURE Copy(position: Basic.Position;dest,src,size: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		ASSERT(~IntermediateCode.IsVectorRegister(dest));
		ASSERT(~IntermediateCode.IsVectorRegister(src));
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.copy,dest,src,size);
		RETURN instruction
	END Copy;

	PROCEDURE Fill(position: Basic.Position;dest,size, value: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.fill,dest,size,value);
		RETURN instruction
	END Fill;

	PROCEDURE Asm(position: Basic.Position;s: SyntaxTree.SourceCode; scope: SyntaxTree.Scope): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction; string: IntermediateCode.Operand;
	BEGIN
		string := IntermediateCode.String(s);
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.asm,string,emptyOperand,emptyOperand);
		IntermediateCode.SetScope(instruction, scope);
		RETURN instruction
	END Asm;

	PROCEDURE Data*(position: Basic.Position;op: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.data,op,emptyOperand,emptyOperand);
		RETURN instruction
	END Data;

	PROCEDURE SpecialInstruction(position: Basic.Position;subtype: SHORTINT; op1,op2,op3: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.special,op1,op2,op3);
		IntermediateCode.SetSubType(instruction, subtype);
		RETURN instruction
	END SpecialInstruction;

	PROCEDURE Reserve(position: Basic.Position;units: LONGINT): IntermediateCode.Instruction;
	VAR op1: IntermediateCode.Operand;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		(*! generate a warning if size exceeds a certain limit *)
		(*
		ASSERT(bytes < 1000000); (* sanity check *)
		*)
		ASSERT(0 <= units); (* sanity check *)
		IntermediateCode.InitNumber(op1,units);
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.reserve,op1,emptyOperand,emptyOperand);
		RETURN instruction
	END Reserve;

	PROCEDURE LabelInstruction(position: Basic.Position): IntermediateCode.Instruction;
	VAR op1: IntermediateCode.Operand;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitNumber(op1,position.start);
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.label,op1,emptyOperand,emptyOperand);
		RETURN instruction
	END LabelInstruction;

	PROCEDURE EnterImmediate*(data: IntermediateCode.Section; CONST vop: IntermediateCode.Operand): LONGINT;
	VAR pc: LONGINT;

		PROCEDURE ProvidesValue(CONST instr: IntermediateCode.Instruction; op: IntermediateCode.Operand): BOOLEAN;
		BEGIN
			IF instr.opcode # IntermediateCode.data THEN RETURN FALSE END;
			ASSERT(instr.op1.mode = IntermediateCode.ModeImmediate);
			IF instr.op1.type.sizeInBits # op.type.sizeInBits THEN RETURN FALSE END;
			IF instr.op1.type.form # op.type.form THEN RETURN FALSE END;
			IF instr.op1.type.form = IntermediateCode.Float THEN
				RETURN instr.op1.floatValue = op.floatValue
			ELSE
				RETURN instr.op1.intValue = op.intValue
			END;
		END ProvidesValue;

	BEGIN
		ASSERT(vop.mode = IntermediateCode.ModeImmediate);
		pc := 0;
		WHILE (pc<data.pc) & ~ProvidesValue(data.instructions[pc],vop) DO
			INC(pc);
		END;

		IF pc = data.pc THEN
			data.Emit(Data(Basic.invalidPosition,vop));
		END;
		RETURN pc
	END EnterImmediate;

	PROCEDURE Init;
	VAR i: LONGINT; name: SyntaxTree.IdentifierString;
	BEGIN
		int8 := IntermediateCode.NewType(IntermediateCode.SignedInteger,IntermediateCode.Bits8);
		int16 := IntermediateCode.NewType(IntermediateCode.SignedInteger,IntermediateCode.Bits16);
		int32 := IntermediateCode.NewType(IntermediateCode.SignedInteger,IntermediateCode.Bits32);
		int64 := IntermediateCode.NewType(IntermediateCode.SignedInteger,IntermediateCode.Bits64);
		uint8 := IntermediateCode.NewType(IntermediateCode.UnsignedInteger,IntermediateCode.Bits8);
		uint16 := IntermediateCode.NewType(IntermediateCode.UnsignedInteger,IntermediateCode.Bits16);
		uint32 := IntermediateCode.NewType(IntermediateCode.UnsignedInteger,IntermediateCode.Bits32);
		uint64 := IntermediateCode.NewType(IntermediateCode.UnsignedInteger,IntermediateCode.Bits64);
		float32 := IntermediateCode.NewType(IntermediateCode.Float,IntermediateCode.Bits32);
		float64 := IntermediateCode.NewType(IntermediateCode.Float,IntermediateCode.Bits64);
		IntermediateCode.InitOperand(emptyOperand);

		FOR i := 0 TO NumberSystemCalls-1 DO
			name := "@SystemCall";
			Basic.AppendNumber(name,i);
			systemCalls[i] := SyntaxTree.NewSymbol(SyntaxTree.NewIdentifier(name));
		END;
		ResultDesignatorName := SyntaxTree.NewIdentifier("@Result");
	END Init;

	PROCEDURE IsExported(symbol: SyntaxTree.Symbol): BOOLEAN;
	BEGIN
		RETURN (symbol # NIL) & symbol.NeedsSection();
	END IsExported;

BEGIN
	Init;

END FoxIntermediateBackend.

Compiler.Compile -p=Win32 FoxIntermediateBackend.Mod ~

#	Release.Build --path="/temp/obg/" Win32 ~
#	Linker.Link --fileFormat=PE32 --fileName=A2H.exe --extension=GofW --displacement=401000H  Builtins Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands Files WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection  Loader  BootConsole ~
FStols.CloseFiles A2Z.exe ~

System.FreeDownTo FoxIntermediateBackend ~

Compiler.Compile -p=Win32 --destPath=/temp/obg/ --traceModule=Trace
I386.Builtins.Mod Trace.Mod Windows.I386.Kernel32.Mod Windows.I386.Machine.Mod Heaps.Mod
Modules.Mod Windows.I386.Objects.Mod Windows.Kernel.Mod KernelLog.Mod Plugins.Mod Streams.Mod Pipes.Mod
Commands.Mod I386.Reals.Mod Reflection.Mod TrapWriters.Mod CRC.Mod SystemVersion.Mod
Windows.I386.Traps.Mod Locks.Mod Windows.Clock.Mod Disks.Mod Files.Mod Dates.Mod Strings.Mod UTF8Strings.Mod
FileTrapWriter.Mod Caches.Mod DiskVolumes.Mod OldDiskVolumes.Mod RAMVolumes.Mod DiskFS.Mod OldDiskFS.Mod
OberonFS.Mod FATVolumes.Mod FATFiles.Mod ISO9660Volumes.Mod ISO9660Files.Mod Windows.User32.Mod
Windows.WinTrace.Mod Windows.ODBC.Mod Windows.Shell32.Mod Windows.SQL.Mod Windows.WinFS.Mod
RelativeFileSystem.Mod BitSets.Mod Diagnostics.Mod StringPool.Mod ObjectFile.Mod
GenericLinker.Mod Loader.Mod BootConsole.Mod
