MODULE FoxSyntaxTree;   (**  AUTHOR "fof & fn"; PURPOSE "Oberon Compiler: Abstract Syntax Tree";  **)
(* (c) fof ETHZ 2009 *)

(**
	note on documentation:
	Most objects in this module are commented with an informal Oberon syntax example indicating which variables of the respective object stand for what symbol /expression etc.
	This syntax example should not be confused with a profound description of the syntax in an EBNF form, which can rather be found in the parser module.
	The informal Oberon syntax is marked with << ... >>
**)

IMPORT
	Basic := FoxBasic, Scanner := FoxScanner, BitSets, StringPool, Strings(* , D := Debugging (* only for debuggging / counting *) *) ;

CONST
	(** general flags: used in statements, procedure types and symbols
		general flags are unique and may overlap with access flags only
		flag numbers have no meaning and are not used for object files etc., i.e. flag renumbering is possible without effect
	*)
	(** calling conventions *)
	OberonCallingConvention* = 0;
	CCallingConvention* = 1;
	WinAPICallingConvention* = 2;
	InterruptCallingConvention* = 3;
	PlatformCallingConvention* = 4;
	UndefinedCallingConvention* = 5;

	(** Access Flags *)
	InternalRead* = 0;			(** can read symbol in same module *)
	InternalWrite* = 1;		(** can write symbol in same module *)
	ProtectedRead* = 2;		(** can read symbol in type extentions *)
	ProtectedWrite* = 3;		(** can write symbol in type extentions *)
	PublicRead* = 4;			(** can read everywhere *)
	PublicWrite* = 5;			(** can write everywhere *)

	Hidden* = {};
	Internal* = {InternalRead, InternalWrite};
	Protected* = {ProtectedRead, ProtectedWrite} ;
	Public* = {PublicRead, PublicWrite} ;
	ReadOnly* = {InternalRead, ProtectedRead,PublicRead};

	(** parameter forms *)
	ValueParameter* = 0;  VarParameter* = 1;  ConstParameter* = 2;
	InPort*=3; OutPort*=4;

	(** array forms *)
	Static*=1; (* ARRAY x OF .. / ARRAY [x] OF ... *)
	Open*=2; (* ARRAY OF ... / ARRAY [*] OF ... *)
	Tensor*=3; (* ARRAY [?] OF ... *)
	SemiDynamic*=4;

	(** node states, important for checker to avoid cycles *)
	Undefined*={}; BeingResolved*=1; Resolved*=2; Fingerprinted*=3; Warned*=4;

	(* context in which a range expression is used *)
	ArrayIndex* = 0;
	SetElement* = 1;
	CaseGuard* = 2;

	(* reflection flags *)
	FlagProcedureDelegate*=0;
	FlagProcedureConstructor*=1;

	FlagParameterVar*=1;
	FlagParameterConst*=2;

TYPE
	Position*= Scanner.Position;
	SourceCode*= Scanner.StringType;
	BinaryCode*= BitSets.BitSet;
	String*= Scanner.StringType;
	IdentifierString*= Scanner.IdentifierString;
	CallingConvention*= SIGNED32;
	SubType* = Scanner.SubType;

	(** visitor pattern implementation *)
	(* to use this object in your implementation, copy and paste and replace "x: " by "x: SyntaxTree." *)
	Visitor* = OBJECT

		(** types *)
		PROCEDURE VisitType*(x: Type);
		BEGIN HALT(100) (* abstract *) END VisitType;

		PROCEDURE VisitBasicType*(x: BasicType);
		BEGIN HALT(100) (* abstract *) END VisitBasicType;

		PROCEDURE VisitByteType*(x: ByteType);
		BEGIN HALT(100) (* abstract *) END VisitByteType;

		PROCEDURE VisitAnyType*(x: AnyType);
		BEGIN HALT(100) (* abstract *) END VisitAnyType;

		PROCEDURE VisitObjectType*(x: ObjectType);
		BEGIN HALT(100) (* abstract *) END VisitObjectType;

		PROCEDURE VisitNilType*(x: NilType);
		BEGIN HALT(100) (* abstract *) END VisitNilType;

		PROCEDURE VisitAddressType*(x: AddressType);
		BEGIN HALT(100) (* abstract *) END VisitAddressType;

		PROCEDURE VisitSizeType*(x: SizeType);
		BEGIN HALT(100) (* abstract *) END VisitSizeType;

		PROCEDURE VisitBooleanType*(x: BooleanType);
		BEGIN HALT(100) (* abstract *) END VisitBooleanType;

		PROCEDURE VisitSetType*(x: SetType);
		BEGIN HALT(100) (* abstract *) END VisitSetType;

		PROCEDURE VisitCharacterType*(x: CharacterType);
		BEGIN HALT(100) END VisitCharacterType;

		PROCEDURE VisitIntegerType*(x: IntegerType);
		BEGIN HALT(100) END VisitIntegerType;

		PROCEDURE VisitFloatType*(x: FloatType);
		BEGIN HALT(100) END VisitFloatType;

		PROCEDURE VisitComplexType*(x: ComplexType);
		BEGIN HALT(100) END VisitComplexType;

		PROCEDURE VisitQualifiedType*(x: QualifiedType);
		BEGIN HALT(100) (* abstract *) END VisitQualifiedType;

		PROCEDURE VisitStringType*(x: StringType);
		BEGIN HALT(100) (* abstract *) END VisitStringType;

		PROCEDURE VisitEnumerationType*(x: EnumerationType);
		BEGIN HALT(100) (* abstract *) END VisitEnumerationType;

		PROCEDURE VisitRangeType*(x: RangeType);
		BEGIN HALT(100) (* abstract *) END VisitRangeType;

		PROCEDURE VisitArrayType*(x: ArrayType);
		BEGIN HALT(100) (* abstract *) END VisitArrayType;

		PROCEDURE VisitMathArrayType*(x: MathArrayType);
		BEGIN HALT(100) (* abstract *) END VisitMathArrayType;

		PROCEDURE VisitPointerType*(x: PointerType);
		BEGIN HALT(100) (* abstract *) END VisitPointerType;

		PROCEDURE VisitPortType*(x: PortType);
		BEGIN HALT(100) (* abstract *) END VisitPortType;

		PROCEDURE VisitRecordType*(x: RecordType);
		BEGIN HALT(100) (* abstract *) END VisitRecordType;

		PROCEDURE VisitCellType*(x: CellType);
		BEGIN HALT(100) (* abstract *) END VisitCellType;

		PROCEDURE VisitProcedureType*(x: ProcedureType);
		BEGIN HALT(100) (* abstract *) END VisitProcedureType;

		PROCEDURE VType*(x: Type);
		BEGIN
			WITH x: ProcedureType DO VisitProcedureType(x)
			|CellType DO VisitCellType(x)
			|RecordType DO VisitRecordType(x)
			|PortType DO VisitPortType(x)
			|PointerType DO VisitPointerType(x)
			|MathArrayType DO VisitMathArrayType(x)
			|ArrayType DO VisitArrayType(x)
			|RangeType DO VisitRangeType(x)
			|EnumerationType DO VisitEnumerationType(x)
			|StringType DO VisitStringType(x)
			|QualifiedType DO VisitQualifiedType(x)
			|ComplexType DO VisitComplexType(x)
			|FloatType DO VisitFloatType(x)
			|IntegerType DO VisitIntegerType(x)
			|CharacterType DO VisitCharacterType(x)
			|SetType DO VisitSetType(x)
			|BooleanType DO VisitBooleanType(x)
			|SizeType DO VisitSizeType(x)
			|AddressType DO VisitAddressType(x)
			|NilType DO VisitNilType(x)
			|ObjectType DO VisitObjectType(x)
			|AnyType DO VisitAnyType(x)
			|ByteType DO VisitByteType(x)
			|BasicType DO VisitBasicType(x)
			ELSE VisitType(x)
			END;
		END VType;

		(** expressions *)
		PROCEDURE VisitExpression*(x: Expression);
		BEGIN HALT(100) (* abstract *) END VisitExpression;

		PROCEDURE VisitSet*(x: Set);
		BEGIN HALT(100) (* abstract *) END VisitSet;

		PROCEDURE VisitMathArrayExpression*(x: MathArrayExpression);
		BEGIN HALT(100) (* abstract *) END VisitMathArrayExpression;

		PROCEDURE VisitUnaryExpression*(x: UnaryExpression);
		BEGIN HALT(100) (* abstract *) END VisitUnaryExpression;

		PROCEDURE VisitBinaryExpression*(x: BinaryExpression);
		BEGIN HALT(100) (* abstract *) END VisitBinaryExpression;

		PROCEDURE VisitRangeExpression*(x: RangeExpression);
		BEGIN HALT(100) (* abstract *) END VisitRangeExpression;

		PROCEDURE VisitTensorRangeExpression*(x: TensorRangeExpression);
		BEGIN HALT(100) (* abstract *) END VisitTensorRangeExpression;

		PROCEDURE VisitConversion*(x: Conversion);
		BEGIN HALT(100) (* abstract *) END VisitConversion;

		(** designators (expressions) *)
		PROCEDURE VisitDesignator*(x: Designator);
		BEGIN HALT(100) (* abstract *) END VisitDesignator;

		PROCEDURE VisitIdentifierDesignator*(x: IdentifierDesignator);
		BEGIN HALT(100) (* abstract *) END VisitIdentifierDesignator;

		PROCEDURE VisitSelectorDesignator*(x: SelectorDesignator);
		BEGIN HALT(100) (* abstract *) END VisitSelectorDesignator;

		PROCEDURE VisitParameterDesignator*(x: ParameterDesignator);
		BEGIN HALT(100) (* abstract *) END VisitParameterDesignator;

		PROCEDURE VisitArrowDesignator*(x: ArrowDesignator);
		BEGIN HALT(100) (* abstract *) END VisitArrowDesignator;

		PROCEDURE VisitBracketDesignator*(x: BracketDesignator);
		BEGIN HALT(100) (* abstract *) END VisitBracketDesignator;

		PROCEDURE VisitSymbolDesignator*(x: SymbolDesignator);
		BEGIN HALT(100) (* abstract *) END VisitSymbolDesignator;

		PROCEDURE VisitIndexDesignator*(x: IndexDesignator);
		BEGIN HALT(100) (* abstract *) END VisitIndexDesignator;

		PROCEDURE VisitProcedureCallDesignator*(x: ProcedureCallDesignator);
		BEGIN HALT(100) (* abstract *) END VisitProcedureCallDesignator;

		PROCEDURE VisitInlineCallDesignator*(x: InlineCallDesignator);
		BEGIN HALT(100) (* abstract *) END VisitInlineCallDesignator;

		PROCEDURE VisitBuiltinCallDesignator*(x: BuiltinCallDesignator);
		BEGIN HALT(100) (* abstract *) END VisitBuiltinCallDesignator;

		PROCEDURE VisitTypeGuardDesignator*(x: TypeGuardDesignator);
		BEGIN HALT(100) (* abstract *) END VisitTypeGuardDesignator;

		PROCEDURE VisitDereferenceDesignator*(x: DereferenceDesignator);
		BEGIN HALT(100) (* abstract *) END VisitDereferenceDesignator;

		PROCEDURE VisitSupercallDesignator*(x: SupercallDesignator);
		BEGIN HALT(100) (* abstract *) END VisitSupercallDesignator;

		PROCEDURE VisitSelfDesignator*(x: SelfDesignator);
		BEGIN HALT(100) (* abstract *) END VisitSelfDesignator;

		PROCEDURE VisitResultDesignator*(x: ResultDesignator);
		BEGIN HALT(100) (* abstract *) END VisitResultDesignator;

		(** values *)
		PROCEDURE VisitValue*(x: Value);
		BEGIN HALT(100) (* abstract *) END VisitValue;

		PROCEDURE VisitBooleanValue*(x: BooleanValue);
		BEGIN HALT(100) (* abstract *) END VisitBooleanValue;

		PROCEDURE VisitIntegerValue*(x: IntegerValue);
		BEGIN HALT(100) (* abstract *) END VisitIntegerValue;

		PROCEDURE VisitCharacterValue*(x: CharacterValue);
		BEGIN HALT(100) (* abstract *) END VisitCharacterValue;

		PROCEDURE VisitSetValue*(x: SetValue);
		BEGIN HALT(100) (* abstract *) END VisitSetValue;

		PROCEDURE VisitMathArrayValue*(x: MathArrayValue);
		BEGIN HALT(100) (* abstract *) END VisitMathArrayValue;

		PROCEDURE VisitRealValue*(x: RealValue);
		BEGIN HALT(100) (* abstract *) END VisitRealValue;

		PROCEDURE VisitComplexValue*(x: ComplexValue);
		BEGIN HALT(100) (* abstract *) END VisitComplexValue;

		PROCEDURE VisitStringValue*(x: StringValue);
		BEGIN HALT(100) (* abstract *) END VisitStringValue;

		PROCEDURE VisitNilValue*(x: NilValue);
		BEGIN HALT(100) (* abstract *) END VisitNilValue;

		PROCEDURE VisitEnumerationValue*(x: EnumerationValue);
		BEGIN HALT(100) (* abstract *) END VisitEnumerationValue;

		PROCEDURE VisitProcedureValue*(x: ProcedureValue);
		BEGIN HALT(100) (* abstract *) END VisitProcedureValue;

		PROCEDURE VExpression*(x: Expression);
		BEGIN
			WITH x:
			| ResultDesignator DO VisitResultDesignator(x)
			| SelfDesignator DO VisitSelfDesignator(x)
			| SupercallDesignator DO VisitSupercallDesignator(x)
			| DereferenceDesignator DO VisitDereferenceDesignator(x)
			| TypeGuardDesignator DO VisitTypeGuardDesignator(x)
			| BuiltinCallDesignator DO VisitBuiltinCallDesignator(x)
			| ProcedureCallDesignator DO VisitProcedureCallDesignator(x)
			| InlineCallDesignator DO VisitInlineCallDesignator(x)
			| IndexDesignator DO VisitIndexDesignator(x)
			| SymbolDesignator DO VisitSymbolDesignator(x)
			| BracketDesignator DO VisitBracketDesignator(x)
			| ArrowDesignator DO VisitArrowDesignator(x)
			| ParameterDesignator DO VisitParameterDesignator(x)
			| SelectorDesignator DO VisitSelectorDesignator(x)
			| IdentifierDesignator DO VisitIdentifierDesignator(x)
			| Designator DO VisitDesignator(x)
			| Conversion DO VisitConversion(x)
			| TensorRangeExpression DO VisitTensorRangeExpression(x)
			| RangeExpression DO VisitRangeExpression(x)
			| BinaryExpression DO VisitBinaryExpression(x)
			| UnaryExpression DO VisitUnaryExpression(x)
			| MathArrayExpression DO VisitMathArrayExpression(x)
			| Set DO VisitSet(x)
			| BooleanValue DO VisitBooleanValue(x)
			| IntegerValue DO VisitIntegerValue(x)
			| CharacterValue DO VisitCharacterValue(x)
			| SetValue DO VisitSetValue(x)
			| MathArrayValue DO VisitMathArrayValue(x)
			| RealValue DO VisitRealValue(x)
			| ComplexValue DO VisitComplexValue(x)
			| StringValue DO VisitStringValue(x)
			| NilValue DO VisitNilValue(x)
			| EnumerationValue DO VisitEnumerationValue(x);
			| ProcedureValue DO VisitProcedureValue(x);
			| Value DO VisitValue(x);
			ELSE
				VisitExpression(x)
			END;
		END VExpression;

		(** symbols *)
		PROCEDURE VisitSymbol*(x: Symbol);
		BEGIN HALT(100) (* abstract *) END VisitSymbol;

		PROCEDURE VisitModule*(x: Module);
		BEGIN HALT(100) (* abstract *) END VisitModule;

		PROCEDURE VisitTypeDeclaration*(x: TypeDeclaration);
		BEGIN HALT(100) (* abstract *) END VisitTypeDeclaration;

		PROCEDURE VisitConstant*(x: Constant);
		BEGIN HALT(100) (* abstract *) END VisitConstant;

		PROCEDURE VisitVariable*(x: Variable);
		BEGIN HALT(100) (* abstract *) END VisitVariable;

		PROCEDURE VisitParameter*(x: Parameter);
		BEGIN HALT(100) (* abstract *) END VisitParameter;

		PROCEDURE VisitProperty*(x: Property);
		BEGIN HALT(100) (* abstract *) END VisitProperty;

		PROCEDURE VisitProcedure*(x: Procedure);
		BEGIN HALT(100) (* abstract *) END VisitProcedure;

		PROCEDURE VisitAlias*(x: Alias);
		BEGIN HALT(100) (* abstract *) END VisitAlias;

		PROCEDURE VisitBuiltin*(x: Builtin);
		BEGIN HALT(100) (* abstract *) END VisitBuiltin;

		PROCEDURE VisitOperator*(x: Operator);
		BEGIN HALT(100) (* abstract *) END VisitOperator;

		PROCEDURE VisitImport*(x: Import);
		BEGIN HALT(100) (* abstract *) END VisitImport;

		PROCEDURE VSymbol*(x: Symbol);
		BEGIN
			WITH x:
			| Module DO VisitModule(x)
			| TypeDeclaration DO VisitTypeDeclaration(x)
			| Constant DO VisitConstant(x)
			| Parameter DO VisitParameter(x)
			| Property DO VisitProperty(x)
			| Variable DO VisitVariable(x)
			| Operator DO VisitOperator(x)
			| Procedure DO VisitProcedure(x)
			| Alias DO VisitAlias(x)
			| Builtin DO VisitBuiltin(x)
			| Import DO VisitImport(x)
			ELSE
				VisitSymbol(x)
			END;
		END VSymbol;

		(** statements *)
		PROCEDURE VisitStatement*(x: Statement);
		BEGIN HALT(100) (* abstract *) END VisitStatement;

		PROCEDURE VisitProcedureCallStatement*(x: ProcedureCallStatement);
		BEGIN HALT(100) (* abstract *) END VisitProcedureCallStatement;

		PROCEDURE VisitAssignment*(x: Assignment);
		BEGIN HALT(100) (* abstract *) END VisitAssignment;

		PROCEDURE VisitDeclarationStatement*(x: DeclarationStatement);
		BEGIN HALT(100) (* abstract *) END VisitDeclarationStatement;

		PROCEDURE VisitCommunicationStatement*(x: CommunicationStatement);
		BEGIN HALT(100) (* abstract *) END VisitCommunicationStatement;

		PROCEDURE VisitIfStatement*(x: IfStatement);
		BEGIN HALT(100) (* abstract *) END VisitIfStatement;

		PROCEDURE VisitWithStatement*(x: WithStatement);
		BEGIN HALT(100) (* abstract *) END VisitWithStatement;

		PROCEDURE VisitCaseStatement*(x: CaseStatement);
		BEGIN HALT(100) (* abstract *) END VisitCaseStatement;

		PROCEDURE VisitWhileStatement*(x: WhileStatement);
		BEGIN HALT(100) (* abstract *) END VisitWhileStatement;

		PROCEDURE VisitRepeatStatement*(x: RepeatStatement);
		BEGIN HALT(100) (* abstract *) END VisitRepeatStatement;

		PROCEDURE VisitForStatement*(x: ForStatement);
		BEGIN HALT(100) (* abstract *) END VisitForStatement;

		PROCEDURE VisitLoopStatement*(x: LoopStatement);
		BEGIN HALT(100) (* abstract *) END VisitLoopStatement;

		PROCEDURE VisitExitableBlock*(x: ExitableBlock);
		BEGIN HALT(100) (* abstract *) END VisitExitableBlock;

		PROCEDURE VisitExitStatement*(x: ExitStatement);
		BEGIN HALT(100) (* abstract *) END VisitExitStatement;

		PROCEDURE VisitReturnStatement*(x: ReturnStatement);
		BEGIN HALT(100) (* abstract *) END VisitReturnStatement;

		PROCEDURE VisitAwaitStatement*(x: AwaitStatement);
		BEGIN HALT(100) (* abstract *) END VisitAwaitStatement;

		PROCEDURE VisitStatementBlock*(x: StatementBlock);
		BEGIN HALT(100) (* abstract *) END VisitStatementBlock;

		PROCEDURE VisitCode*(x: Code);
		BEGIN HALT(100) (* abstract *) END VisitCode;

		PROCEDURE VStatement*(x: Statement);
		BEGIN
			WITH x:
			ProcedureCallStatement DO VisitProcedureCallStatement(x)
			| Assignment DO VisitAssignment(x)
			| DeclarationStatement DO VisitDeclarationStatement(x)
			| CommunicationStatement DO VisitCommunicationStatement(x)
			| IfStatement DO VisitIfStatement(x)
			| WithStatement DO VisitWithStatement(x)
			| CaseStatement DO VisitCaseStatement(x)
			| WhileStatement DO VisitWhileStatement(x)
			| RepeatStatement DO VisitRepeatStatement(x)
			| ForStatement DO VisitForStatement(x)
			| LoopStatement DO VisitLoopStatement(x)
			| ExitableBlock DO VisitExitableBlock(x)
			| ExitStatement DO VisitExitStatement(x)
			| ReturnStatement DO VisitReturnStatement(x)
			| AwaitStatement DO VisitAwaitStatement(x)
			| StatementBlock DO VisitStatementBlock(x)
			| Code DO VisitCode(x)
			ELSE VisitStatement(x)
			END;
		END VStatement;

	END Visitor;

	ArrayAccessOperators* = RECORD
		len*: Operator; (* length operator *)
		generalRead*, generalWrite*: Operator; (* operators on ARRAY [*] RANGE, for tensors *)
		read*, write*: POINTER TO ARRAY OF Operator; (* fixed-dim. operators *)
	END;

	Fingerprint*= RECORD
		shallow* := 0, public* := 0, private* := 0: Basic.Fingerprint;
		shallowAvailable* := FALSE, deepAvailable* := FALSE: BOOLEAN;
	END;

	(** identifiers in a program text **)
	Identifier* = Basic.String;

	(** qualified identifiers << Identifier.Identifier >> **)
	QualifiedIdentifier* = OBJECT
		VAR
			prefix-, suffix-: Identifier;   (* use string index instead ? *)
			position-: Position;

		PROCEDURE & InitQualifiedIdentifier( position: Position;  prefix, suffix: Identifier);
		BEGIN
			(* ASSERT(suffix # invalidIdentifier); can happen but should be catched by the parser with error report and not here with trap *)
			SELF.position := position;
			SELF.prefix := prefix; SELF.suffix := suffix;
		END InitQualifiedIdentifier;

		PROCEDURE GetName*(VAR name: Basic.SegmentedName);
		BEGIN
			Basic.InitSegmentedName(name);
			IF prefix # invalidIdentifier THEN Basic.SuffixSegmentedName(name, prefix) END;
			Basic.SuffixSegmentedName(name, suffix)
		END GetName;

	END QualifiedIdentifier;

	(**** types ****)
	(**
		Type
			BasicType
				ObjectType
				NilType
				AnyType
				ByteType
				AddressType
				SizeType
				BooleanType
				SetType
				CharacterType
				RangeType
				NumberType
					IntegerType
					FloatType
					ComplexType
			QualifiedType
			StringType
			EnumerationType
			ArrayType
			MathArrayType
			PointerType
			PortType
			RecordType
			CellType
			ProcedureType
	*)

	Type* = OBJECT
		VAR
			typeDeclaration-: TypeDeclaration; (* link to declaration (if any), needed for printing, debugging and symbol lookup *)
			scope-: Scope; (* scope where the type has been declared *)
			resolved-: Type; (* indirection to resolved type to preserve qualified types *)
			position-,end-: Position;
			state-: SET;
			hasPointers-: BOOLEAN;

			fingerprint-: Fingerprint;

			isRealtime-: BOOLEAN;
			recursion: BOOLEAN;

			sizeInBits-: SIZE; (* allocation size of this type in bits *)
			alignmentInBits-: SIZE;

		PROCEDURE & InitType*( position: Position);
		BEGIN
			SELF.position := position; state := Undefined;
			end := invalidPosition;
			typeDeclaration := NIL;
			scope := NIL;
			resolved := SELF;
			sizeInBits := MIN(SIZE);
			alignmentInBits := 0;
			isRealtime := FALSE;
			recursion := FALSE;
			hasPointers := FALSE;
		END InitType;

		PROCEDURE SetSize*(sizeInBits: SIZE);
		BEGIN SELF.sizeInBits := sizeInBits
		END SetSize;

		PROCEDURE SetAlignmentInBits*(alignmentInBits: SIZE);
		BEGIN SELF.alignmentInBits := alignmentInBits
		END SetAlignmentInBits;

		PROCEDURE End*( position: SIGNED32 );
		BEGIN SELF.position.end := position;
		END End;

		PROCEDURE SetFingerprint*(CONST fp: Fingerprint);
		BEGIN
			SELF.fingerprint := fp
		END SetFingerprint;

		PROCEDURE SetState*(state: SIGNED32);
		BEGIN	INCL(SELF.state,state);
		END SetState;

		PROCEDURE SetHasPointers*(has: BOOLEAN);
		BEGIN
			hasPointers := has
		END SetHasPointers;

		PROCEDURE RemoveState*(state: SIGNED32);
		BEGIN EXCL(SELF.state,state)
		END RemoveState;

		PROCEDURE SetTypeDeclaration*(typeDeclaration: TypeDeclaration);
		BEGIN SELF.typeDeclaration := typeDeclaration
		END SetTypeDeclaration;

		PROCEDURE SetScope*(scope: Scope);
		BEGIN SELF.scope := scope
		END SetScope;

		PROCEDURE SetRealtime*(isRealtime: BOOLEAN);
		BEGIN SELF.isRealtime := isRealtime
		END SetRealtime;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN FALSE
		END SameType;

		(** assignment compatibility of this := SELF *)
		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN FALSE
		END CompatibleTo;

		(** Returns if the type is a pointer  *)
		PROCEDURE IsPointer*(): BOOLEAN;
		BEGIN RETURN FALSE
		END IsPointer;

		(** Returns if the type consists of more than one parts. Implies that an instance of this type cannot be (easily) represented in one register. *)
		PROCEDURE IsComposite*(): BOOLEAN;
		BEGIN RETURN FALSE
		END IsComposite;

		(** Returns if the type needs to be traced for garbage collection *)
		PROCEDURE NeedsTrace*(): BOOLEAN;
		BEGIN RETURN IsPointer ();
		END NeedsTrace;

		PROCEDURE IsRecordType*(): BOOLEAN;
		BEGIN
			RETURN FALSE;
		END IsRecordType;

	END Type;

	(* basic types, defined in global name space *)
	BasicType*= OBJECT(Type)
	VAR name-: Identifier;

		PROCEDURE & InitBasicType(CONST id: ARRAY OF CHAR; sizeInBits: SIZE);
		VAR str: IdentifierString;
		BEGIN
			COPY(id, str);Basic.AppendNumber(str,sizeInBits); name := NewIdentifier(str);
			InitType(invalidPosition);
			SetSize(sizeInBits);
			SELF.name := name
		END InitBasicType;

		PROCEDURE SetName*(CONST id: ARRAY OF CHAR);
		BEGIN
			name := NewIdentifier(id);
		END SetName;

		PROCEDURE SetTypeDeclaration*(typeDeclaration: TypeDeclaration);
		BEGIN HALT(100);
		END SetTypeDeclaration;

	END BasicType;

	(** <<OBJECT>>
		object type (base type of all objects)
	**)
	ObjectType*=OBJECT(BasicType)

		PROCEDURE & InitObjectType(sizeInBits: SIZE);
		BEGIN
			InitBasicType("@Object",sizeInBits);
			hasPointers := TRUE;
		END InitObjectType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this IS ObjectType)
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN ((to IS AnyType) OR (to IS ObjectType))
		END CompatibleTo;

		PROCEDURE IsPointer*(): BOOLEAN;
		BEGIN RETURN TRUE
		END IsPointer;

	END ObjectType;

	(** <<NIL>>
		nil type (type of NIL pointers), may be replaced by any type
	**)
	NilType*=OBJECT(BasicType)

		PROCEDURE & InitNilType(sizeInBits: SIZE);
		BEGIN
			InitBasicType("@Nil",sizeInBits);
			SetRealtime(TRUE);
			hasPointers := TRUE;
		END InitNilType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this IS NilType)
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN (to IS NilType) OR (to IS ObjectType) OR (to IS AnyType) OR (to IS PointerType) OR (to IS ProcedureType) OR (to IS AddressType)
		END CompatibleTo;

		PROCEDURE IsPointer*(): BOOLEAN;
		BEGIN RETURN TRUE
		END IsPointer;

	END NilType;

	(** <<ANY>>
		any pointer type (pointer to record and pointer to array)
	**)
	AnyType*=OBJECT(BasicType)

		PROCEDURE & InitAnyType(sizeInBits: SIZE);
		BEGIN
			InitBasicType("@Any",sizeInBits);
			hasPointers := TRUE;
		END InitAnyType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN this IS AnyType
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN (to IS AnyType)
		END CompatibleTo;

		PROCEDURE IsPointer*(): BOOLEAN;
		BEGIN RETURN TRUE
		END IsPointer;

	END AnyType;

	(** <<SYSTEM.BYTE>>
		byte type
	**)
	ByteType*=OBJECT(BasicType)

		PROCEDURE & InitByteType(sizeInBits: SIZE);
		BEGIN
			InitBasicType("@Byte",sizeInBits);
			SetRealtime(TRUE);
		END InitByteType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN this IS ByteType
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN (to IS ByteType)
		END CompatibleTo;

	END ByteType;

	(** <<ADDRESS>>
		address type
	**)
	AddressType*=OBJECT(BasicType)

		PROCEDURE & InitAddressType(sizeInBits: SIZE);
		BEGIN
			InitBasicType("@Address",sizeInBits);
			SetRealtime(TRUE);
		END InitAddressType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this IS AddressType)
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN (to IS AddressType) OR (to IS SizeType) OR (to IS IntegerType) & (to.sizeInBits >= sizeInBits) OR (to IS PointerType) & to(PointerType).isUnsafe
		END CompatibleTo;

	END AddressType;

	(** <<SIZE>>
		size type (signed address type)
	**)
	SizeType*=OBJECT(BasicType)

		PROCEDURE & InitSizeType(sizeInBits: SIZE);
		BEGIN
			InitBasicType("@Size",sizeInBits);
			SetRealtime(TRUE);
		END InitSizeType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN	RETURN (this IS SizeType)
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN (to IS SizeType) OR (to IS AddressType) OR (to IS IntegerType) & (to.sizeInBits >= sizeInBits)
		END CompatibleTo;

	END SizeType;

	(** <<BOOLEAN>>
		boolean type
	**)
	BooleanType*=OBJECT(BasicType)

		PROCEDURE & InitBooleanType(sizeInBits: SIZE);
		BEGIN
			InitBasicType("@Boolean",sizeInBits);
			SetRealtime(TRUE);
		END InitBooleanType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN this IS BooleanType
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN (to IS BooleanType)
		END CompatibleTo;

	END BooleanType;

	(** <<SET>>
		set type
	**)
	SetType*=OBJECT(BasicType)

		PROCEDURE & InitSetType(sizeInBits: SIZE);
		BEGIN
			InitBasicType("@Set",sizeInBits);
			SetRealtime(TRUE);
		END InitSetType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this = SELF) OR (this IS SetType) & (this.sizeInBits = sizeInBits);
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN (to IS SetType) & (to.sizeInBits >= sizeInBits)
		END CompatibleTo;

	END SetType;

	(** <<CHAR>>
		character type
	**)
	CharacterType*=OBJECT(BasicType)

		PROCEDURE & InitCharacterType(sizeInBits: SIZE);
		BEGIN
			InitBasicType("@Character", sizeInBits);
			SetRealtime(TRUE);
		END InitCharacterType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this = SELF) OR (this IS CharacterType) & (this.sizeInBits = sizeInBits)
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN ((to IS CharacterType) OR (to IS ByteType)) & (to.sizeInBits >= sizeInBits)
		END CompatibleTo;

	END CharacterType;

	(** type of ranges (case constants, set elements, array indices)
		represented by basic type <<RANGE>>
	**)
	RangeType* = OBJECT(BasicType)
		PROCEDURE & InitRangeType(sizeInBits: SIZE);
		BEGIN
			InitBasicType("@RangeType",sizeInBits);
			SetRealtime(TRUE);
		END InitRangeType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this = SELF) OR (this IS RangeType)
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN SameType(to)
		END CompatibleTo;

		PROCEDURE IsComposite*(): BOOLEAN;
		BEGIN RETURN TRUE
		END IsComposite;

	END RangeType;

	(* number types: IntegerType or FloatType *)
	NumberType*=OBJECT(BasicType)

		PROCEDURE & InitNumberType( CONST name: ARRAY OF CHAR; sizeInBits: SIZE);
		BEGIN
			InitBasicType(name, sizeInBits);
			SetRealtime(TRUE);
		END InitNumberType;

	END NumberType;

	(** <<SIGNED8, SIGNED16, SIGNED32, SIGNED64>>
		integer types
	**)
	IntegerType*= OBJECT (NumberType)
	VAR signed-: BOOLEAN;

		PROCEDURE & InitIntegerType(sizeInBits: SIZE; signed: BOOLEAN);
		BEGIN
			IF signed THEN
				InitNumberType("@Integer",sizeInBits);
			ELSE
				InitNumberType("@Unsigned",sizeInBits);
			END;
			SELF.signed := signed;
		END InitIntegerType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this = SELF) OR (this IS IntegerType) & (this.sizeInBits = sizeInBits) & (this(IntegerType).signed = signed)
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN ((to IS IntegerType) OR (to IS AddressType) OR (to IS SizeType) OR (to IS ByteType)) & (to.sizeInBits >= sizeInBits) OR (to IS FloatType)
				OR (to IS ComplexType) & CompatibleTo((to(ComplexType).componentType))
		END CompatibleTo;

	END IntegerType;

	(** <<FLOAT32,FLOAT64>>
		real types: FLOAT32, FLOAT64
	**)
	FloatType*= OBJECT (NumberType)

		PROCEDURE & InitFloatType(sizeInBits: SIZE);
		BEGIN
			InitNumberType("@Float",sizeInBits);
		END InitFloatType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this = SELF) OR (this IS FloatType) & (this.sizeInBits = sizeInBits)
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN
			RETURN (to IS FloatType) & (to.sizeInBits >= sizeInBits)
					OR (to IS ComplexType) & CompatibleTo((to(ComplexType).componentType))
		END CompatibleTo;

	END FloatType;

	(** <<COMPLEX32,COMPLEX64>>
		complex types: COMPLEX32, COMPLEX64
	**)
	ComplexType*= OBJECT (NumberType)
		VAR componentType-: Type; (* FLOAT32 or FLOAT64*)

		PROCEDURE & InitComplexType(componentType: Type);
		BEGIN
			ASSERT(componentType # NIL);
			SELF.componentType := componentType;
			sizeInBits := 2 * componentType.sizeInBits;
			InitNumberType("@Complex",sizeInBits);
		END InitComplexType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this = SELF) OR (this IS ComplexType) & (componentType.SameType(this(ComplexType).componentType))
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN (to IS ComplexType) & (componentType.CompatibleTo(to(ComplexType).componentType))
		END CompatibleTo;

		PROCEDURE IsComposite*(): BOOLEAN;
		BEGIN RETURN TRUE
		END IsComposite;

	END ComplexType;

	(** <<qualifiedIdentifier = resolved>>
		named reference to a type
	**)
	QualifiedType* = OBJECT (Type)
		VAR
			qualifiedIdentifier-: QualifiedIdentifier;

		PROCEDURE & InitQualifiedType( position: Position; scope: Scope;  qualifiedIdentifier: QualifiedIdentifier);
		BEGIN
			InitType( position);
			SELF.scope := scope;
			SELF.qualifiedIdentifier := qualifiedIdentifier;
			resolved := NIL;
		END InitQualifiedType;

		PROCEDURE SetResolved*(resolved: Type);
		BEGIN SELF.resolved := resolved; IF resolved # NIL THEN hasPointers := resolved.hasPointers END;
		END SetResolved;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this = SELF) OR (resolved # NIL) & (this.resolved # NIL) & resolved.SameType(this.resolved)
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN (resolved # NIL) & resolved.CompatibleTo(to)
		END CompatibleTo;

		PROCEDURE IsPointer*(): BOOLEAN;
		BEGIN RETURN (resolved # NIL) & resolved.IsPointer()
		END IsPointer;

		PROCEDURE IsComposite*(): BOOLEAN;
		BEGIN RETURN (resolved # NIL) & resolved.IsComposite()
		END IsComposite;

		PROCEDURE NeedsTrace* (): BOOLEAN;
		BEGIN RETURN (resolved # NIL) & (resolved.NeedsTrace());
		END NeedsTrace;

		PROCEDURE IsRecordType*(): BOOLEAN;
		BEGIN
			RETURN (resolved # NIL) & (resolved.IsRecordType());
		END IsRecordType;

	END QualifiedType;

	(** string literal type **)
	StringType*= OBJECT(Type)
	VAR
		length-: SIZE;
		baseType-: Type;

		PROCEDURE & InitStringType(position: Position; baseType: Type; length: SIZE);
		BEGIN
			InitType(position);
			SetRealtime(TRUE);
			SELF.length := length;
			SELF.baseType := baseType;
		END InitStringType;

		PROCEDURE SetLength*(length: SIZE);
		BEGIN SELF.length := length
		END SetLength;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this IS StringType) & (this(StringType).length = length)
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN
			IF to IS ArrayType THEN
				WITH to: ArrayType DO
					RETURN to.arrayBase.SameType(baseType.resolved) & ((to.form = Open) OR (to.staticLength >= length))
				END;
			ELSIF to IS CharacterType THEN
				RETURN (length=2) & baseType.CompatibleTo(to)
			ELSE RETURN FALSE
			END;
		END CompatibleTo;

		PROCEDURE IsComposite*(): BOOLEAN;
		BEGIN RETURN TRUE
		END IsComposite;

	END StringType;

	(** enumeration type of the form <<enum (base) red,green,blue end>> **)
	EnumerationType*=OBJECT(Type)
	VAR
		enumerationScope-: EnumerationScope;
		enumerationBase-: Type;
		rangeLowest-,rangeHighest-: Basic.Integer;

		PROCEDURE &InitEnumerationType(position: Position; scope: Scope; enumerationScope: EnumerationScope);
		BEGIN
			InitType(position);
			SetRealtime(TRUE);
			SELF.scope := scope;
			enumerationBase := NIL;
			rangeLowest := 0; rangeHighest := 0;
			SELF.enumerationScope := enumerationScope;
			enumerationScope.ownerEnumeration := SELF;
		END InitEnumerationType;

		PROCEDURE SetEnumerationBase*(base: Type);
		BEGIN enumerationBase := base
		END SetEnumerationBase;

		PROCEDURE SetRange*(lowest,highest: Basic.Integer);
		BEGIN rangeLowest := lowest; rangeHighest := highest;
		END SetRange;

		PROCEDURE Extends*(this: EnumerationType): BOOLEAN;
		BEGIN	RETURN (SELF = this) OR (enumerationBase # NIL) & (enumerationBase.resolved(EnumerationType).Extends(this));
		END Extends;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN this = SELF
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN (to IS EnumerationType) & (to(EnumerationType).Extends(SELF))
		END CompatibleTo;

	END EnumerationType;

	(** <<ARRAY [length] OF baseType>> *)
	ArrayType* = OBJECT (Type)
		VAR
			arrayBase-: Type;
			length-: Expression;
			staticLength-: SIGNED32;
			form-: SIGNED32; (* redundant: (form = Open) = (staticLength = 0) else (form = Static) *)

		PROCEDURE & InitArrayType(position: Position; scope: Scope;  form: SIGNED32);
		BEGIN
			length := NIL; arrayBase := NIL; InitType(position); staticLength := 0; SELF.form := form; SELF.scope := scope;
		END InitArrayType;

		PROCEDURE SetArrayBase*( type: Type );
		BEGIN
			arrayBase := type; IF (arrayBase # NIL) & (arrayBase.hasPointers) THEN SetHasPointers(TRUE) END;
		END SetArrayBase;

		PROCEDURE SetForm*(f: SIGNED32);
		BEGIN
			form := f;
		END SetForm;

		PROCEDURE SetLength*(length: Expression);
		BEGIN
			SELF.length := length;
			IF (length.resolved # NIL) & (length.resolved IS IntegerValue) THEN
				staticLength := SIGNED32 (length.resolved(IntegerValue).value) (* TODO: staticLength should be of type Basic.Integer too *)
			END;
		END SetLength;

		PROCEDURE Child*(nr: SIGNED32):Type;
		BEGIN
			IF nr = 0 THEN RETURN SELF;
			ELSIF nr = 1 THEN RETURN arrayBase.resolved;
			ELSE RETURN arrayBase.resolved(ArrayType).Child(nr-1);
			END;
		END Child;

		(* recursion safety for cases such as
			A= POINTER TO ARRAY OF B;
			B= POINTER TO ARRAY OF A;
		*)
		PROCEDURE SameType*(this: Type): BOOLEAN;
		VAR result : BOOLEAN;
		BEGIN
			result := FALSE;
			IF this = SELF THEN
				result := TRUE
			ELSIF recursion THEN
				result := TRUE;
			ELSIF this IS ArrayType THEN
				recursion := TRUE;
				WITH this: ArrayType DO
					result := (this.form = form) & (this.staticLength = staticLength) & arrayBase.SameType(this.arrayBase.resolved);
				END;
			END;
			recursion := FALSE;
			RETURN result
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN
			RETURN (form = Static) & SameType(to)
		END CompatibleTo;

		PROCEDURE IsComposite*(): BOOLEAN;
		BEGIN RETURN TRUE
		END IsComposite;

		PROCEDURE NeedsTrace*(): BOOLEAN;
		BEGIN RETURN arrayBase.resolved.NeedsTrace ();
		END NeedsTrace;

	END ArrayType;

	(** <<ARRAY '[' length | '*' | '?' ']' OF baseType>> **)
	MathArrayType* = OBJECT (Type)
		VAR
			modifiers-: Modifier; (* set by the parser *)
			arrayBase-: Type;
			length-: Expression;
			staticLength-: SIGNED32;
			staticIncrementInBits-: SIZE;
			form-: SIGNED32;
			isUnsafe-: BOOLEAN;

		PROCEDURE & InitMathArrayType(position: Position;scope: Scope; form: SIGNED32);
		BEGIN
			length := NIL; arrayBase := NIL; InitType(position); staticLength := 0; staticIncrementInBits := 0; SetForm(form); SELF.scope := scope; isUnsafe := FALSE; modifiers := NIL;
		END InitMathArrayType;

		PROCEDURE SetModifiers*(m: Modifier);
		BEGIN
			modifiers := m;
		END SetModifiers;

		PROCEDURE SetUnsafe*(unsafe: BOOLEAN);
		BEGIN
			isUnsafe := unsafe;
		END SetUnsafe;

		PROCEDURE SetForm*(form: SIGNED32);
		BEGIN
			SELF.form := form; IF form # Static THEN SetHasPointers(TRUE) END;
		END SetForm;

		PROCEDURE SetArrayBase*( type: Type );
		BEGIN
			arrayBase := type; IF (arrayBase # NIL) & (arrayBase.hasPointers) THEN SetHasPointers(TRUE) END;
		END SetArrayBase;

		PROCEDURE SetLength*(length: Expression);
		BEGIN
			SELF.length := length;
			IF (length # NIL) & (length.resolved # NIL) & (length.resolved IS IntegerValue) THEN
				staticLength := SIGNED32 (length.resolved(IntegerValue).value); (* TODO: staticLength should be of type Basic.Integer too *)

				(* optimization: unless the base type is a dynamic array, make this array static *)
				IF ~((arrayBase # NIL) & (arrayBase IS MathArrayType) & (arrayBase(MathArrayType).form # Static)) THEN
					form := Static;
				END

			ELSIF length = NIL THEN
				form := Open;
			END;
		END SetLength;

		PROCEDURE SetIncrement*(increment: SIZE);
		BEGIN staticIncrementInBits := increment
		END SetIncrement;

		(* recursion safety for cases such as
			A= POINTER TO ARRAY OF B;
			B= POINTER TO ARRAY OF A;
		*)
		PROCEDURE SameType*(this: Type): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF this = SELF THEN
				result := TRUE
			ELSIF recursion THEN
				result := TRUE;
			ELSIF this IS MathArrayType THEN
				recursion := TRUE;
				WITH this: MathArrayType DO
					result := (this.form = form) & (this.staticLength = staticLength) &
					((arrayBase = NIL) & (this.arrayBase = NIL) OR (arrayBase # NIL) & (this.arrayBase # NIL) &
					arrayBase.SameType(this.arrayBase.resolved));
				END;
			END;
			recursion := FALSE;
			RETURN result
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN
			HALT(200); (*! implement *)
			RETURN (form = Static) & SameType(to)
		END CompatibleTo;

		(** get the element  type of a math array, i.e. the first type in the math array chain that is not a math array **)
		PROCEDURE ElementType*(): Type;
		VAR
			type: Type;
		BEGIN
			type := SELF;
			WHILE type IS MathArrayType DO
				type := type(MathArrayType).arrayBase.resolved
			END;
			RETURN type
		END ElementType;

		(** get the number of dimensions of a math array; 0 in case of tensors **)
		PROCEDURE Dimensionality*(): SIGNED32;
		VAR
			type: Type;
			dim: SIGNED32;
		BEGIN
			IF form = Tensor THEN
				dim := 0
			ELSE
				type := SELF;
				dim := 0;
				WHILE type IS MathArrayType DO
					ASSERT(type(MathArrayType).form # Tensor);
					INC(dim);
					type := type(MathArrayType).arrayBase.resolved
				END
			END;
			RETURN dim
		END Dimensionality;

		(** if the math array is of the form ARRAY [*, *, ..., *], i.e. contains no static length and is not a tensor either **)
		PROCEDURE IsFullyDynamic*(): BOOLEAN;
		VAR
			type: Type;
			result: BOOLEAN;
		BEGIN
			IF form = Tensor THEN
				result := FALSE;
			ELSE
				result := TRUE;
				type := SELF;
				WHILE type IS MathArrayType DO
					IF type(MathArrayType).form # Open THEN result := FALSE END;
					type := type(MathArrayType).arrayBase.resolved
				END
			END;
			RETURN result
		END IsFullyDynamic;

		PROCEDURE NeedsTrace*(): BOOLEAN;
		BEGIN RETURN hasPointers OR (arrayBase # NIL) & (arrayBase.resolved.NeedsTrace());
		END NeedsTrace;

		PROCEDURE IsComposite*(): BOOLEAN;
		BEGIN RETURN TRUE
		END IsComposite;

	END MathArrayType;

	(** <<POINTER TO pointerBase>> **)
	PointerType* = OBJECT (Type)
		VAR
			modifiers-: Modifier; (* set by the parser *)
			pointerBase-: Type;
			isPlain-: BOOLEAN;
			isUnsafe-: BOOLEAN;
			isUntraced-: BOOLEAN;
			isDisposable-: BOOLEAN;
			isHidden-: BOOLEAN;

		PROCEDURE & InitPointerType(position: Position; scope: Scope);
		BEGIN
			modifiers := NIL;
			pointerBase := NIL;
			isPlain := FALSE;
			isUnsafe := FALSE;
			isDisposable := FALSE;
			InitType(position);
			SELF.scope := scope;
			hasPointers := TRUE;
			isHidden := FALSE;
			isUntraced := FALSE;
		END InitPointerType;

		PROCEDURE SetHidden*(hidden: BOOLEAN);
		BEGIN
			isHidden := hidden;
		END SetHidden;	(** <<POINTER TO pointerBase>> **)

		PROCEDURE SetModifiers*(flags: Modifier);
		BEGIN modifiers := flags
		END SetModifiers;

		PROCEDURE SetPointerBase*( type: Type );
		BEGIN
			pointerBase := type;
		END SetPointerBase;

		PROCEDURE SetPlain*(plain: BOOLEAN);
		BEGIN
			isPlain := plain;
		END SetPlain;

		PROCEDURE SetUnsafe*(unsafe: BOOLEAN);
		BEGIN
			isUnsafe := unsafe;
		END SetUnsafe;

		PROCEDURE SetUntraced*(untraced: BOOLEAN);
		BEGIN
			isUntraced := untraced;
		END SetUntraced;

		PROCEDURE SetDisposable*(disposable: BOOLEAN);
		BEGIN
			isDisposable := disposable;
		END SetDisposable;

		PROCEDURE Extends*(this: Type): BOOLEAN;
		VAR result: BOOLEAN; extension, base: Type;
		BEGIN
			result := FALSE;
			IF ((this IS ObjectType) OR (this IS AnyType)) & (pointerBase.resolved IS RecordType) THEN result := TRUE
			ELSE
				extension := pointerBase.resolved;
				IF this IS PointerType THEN
					base := this(PointerType).pointerBase.resolved;
				ELSIF this IS RecordType THEN
					base := this
				ELSE base := NIL
				END;
				IF (extension IS RecordType) & (base # NIL) THEN
					result := extension(RecordType).Extends(base)
				END;
			END;
			RETURN result
		END Extends;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN	RETURN (SELF = this) OR (this IS PointerType) & (this(PointerType).pointerBase.SameType(pointerBase.resolved) & (this(PointerType).isUnsafe = isUnsafe))
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN	RETURN SameType(to) OR ~(to IS RecordType) & SELF.Extends(to)
		END CompatibleTo;

		PROCEDURE IsPointer*(): BOOLEAN;
		BEGIN RETURN TRUE
		END IsPointer;

		PROCEDURE NeedsTrace*(): BOOLEAN;
		BEGIN RETURN  ~isUntraced;
		END NeedsTrace;

	END PointerType;

	(** << PORT (IN | OUT) [(size)] >>**)
	PortType* = OBJECT (Type)
		VAR
			direction-: SIGNED32;
			sizeExpression-: Expression; (* generated by parser *)
			sizeInBits-: SIZE; (* computed by checker *)
			cellsAreObjects-: BOOLEAN;

		PROCEDURE & InitPortType(position: Position; direction: SIGNED32; sizeExpression: Expression; scope: Scope);
		BEGIN
			InitType(position);
			SELF.sizeExpression := sizeExpression;
			SELF.direction := direction;
			SELF.scope := scope;
			cellsAreObjects := FALSE;
		END InitPortType;

		PROCEDURE SetSize*(size: SIZE);
		BEGIN sizeInBits := size
		END SetSize;

		PROCEDURE SetSizeExpression*(sizeExpression: Expression);
		BEGIN SELF.sizeExpression := sizeExpression
		END SetSizeExpression;

		PROCEDURE SetCellsAreObjects*(b: BOOLEAN);
		BEGIN
			cellsAreObjects := b;
			hasPointers := b;
		END SetCellsAreObjects;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this IS PortType) & (this(PortType).direction = direction) & (this(PortType).sizeInBits = sizeInBits)
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN	RETURN SameType(to)
		END CompatibleTo;

		PROCEDURE IsPointer*(): BOOLEAN;
		BEGIN RETURN cellsAreObjects;
		END IsPointer;

	END PortType;

	(** << recordType =
		[POINTER TO] RECORD (baseType) .. END |
		OBJECT (baseType) .. END
	>> **)
	RecordType* = OBJECT (Type)
		VAR
			recordScope-:RecordScope;
			baseType-: Type;
			pointerType-: PointerType; (* for support of A = POINTER TO RECORD ... END and B = POINTER TO RECORD (A) END; *)
			modifiers-: Modifier;
			isObject-,isProtected: BOOLEAN;
			isAbstract-: BOOLEAN;
			isFinal-: BOOLEAN;

		PROCEDURE & InitRecordType( position: Position; scope: Scope; recordScope: RecordScope);
		BEGIN
			InitType( position);
			SELF.scope := scope;
			baseType := NIL;
			pointerType := NIL;
			SELF.recordScope := recordScope;
			ASSERT(recordScope # NIL);
			ASSERT(recordScope.ownerRecord = NIL); (* cannot register twice ! *)
			recordScope.ownerRecord := SELF;
			isObject := FALSE; isProtected := FALSE;
			modifiers := NIL;
			isAbstract := FALSE;
			isFinal := FALSE;
		END InitRecordType;

		PROCEDURE SetAbstract*(abstract: BOOLEAN);
		BEGIN
			isAbstract := abstract;
		END SetAbstract;

		PROCEDURE SetModifiers*(flag: Modifier);
		BEGIN SELF.modifiers := flag;
		END SetModifiers;

		PROCEDURE SetBaseType*( type: Type );
		BEGIN
			baseType := type; IF (baseType # NIL) & (baseType.hasPointers) THEN hasPointers := TRUE END;
		END SetBaseType;

		PROCEDURE SetPointerType*(pointerType: PointerType);
		BEGIN SELF.pointerType := pointerType
		END SetPointerType;

		PROCEDURE IsObject*(isObject: BOOLEAN);
		BEGIN SELF.isObject := isObject
		END IsObject;

		PROCEDURE IsActive*(): BOOLEAN;
		VAR base: RecordType;
		BEGIN
			IF (recordScope.bodyProcedure # NIL) & (recordScope.bodyProcedure.procedureScope.body # NIL) & (recordScope.bodyProcedure.procedureScope.body.isActive) THEN RETURN TRUE END;
			base := GetBaseRecord();
			IF base # NIL THEN RETURN base.IsActive() END;
			RETURN FALSE
		END IsActive;

		PROCEDURE IsProtected*(): BOOLEAN;
		VAR base: RecordType;
		BEGIN
			IF isProtected THEN RETURN TRUE END;
			base := GetBaseRecord();
			IF base # NIL THEN RETURN base.IsProtected() END;
			RETURN FALSE
		END IsProtected;

		PROCEDURE SetProtected*(protected: BOOLEAN);
		BEGIN SELF.isProtected := protected
		END SetProtected;

		PROCEDURE Level*(): SIGNED32;
		VAR type: RecordType; res: SIGNED32;
		BEGIN
			type := SELF;
			res := 0;
			WHILE (type # NIL) & (type.baseType # NIL) DO
				INC(res);
				type := type.GetBaseRecord();
			END;
			RETURN res;
		END Level;

		PROCEDURE GetBaseRecord*():RecordType;
		BEGIN
			IF (baseType = NIL) OR (baseType.resolved = NIL) THEN RETURN NIL; END;
			IF baseType.resolved IS RecordType THEN
				RETURN baseType.resolved(RecordType);
			ELSIF baseType.resolved IS PointerType THEN
				IF baseType.resolved(PointerType).pointerBase.resolved # NIL THEN
					RETURN baseType.resolved(PointerType).pointerBase.resolved(RecordType);
				END;
			END;
			RETURN NIL;
		END GetBaseRecord;

		PROCEDURE Extends*(this: Type): BOOLEAN;
		VAR result: BOOLEAN; extension: Type;
		BEGIN
			result := FALSE;
			IF this = SELF THEN result := TRUE
			ELSIF this IS RecordType THEN
				IF (baseType # NIL) THEN
					extension := baseType.resolved;
					IF extension IS PointerType THEN
						result := extension(PointerType).Extends(this)
					ELSIF extension IS RecordType THEN
						result := extension(RecordType).Extends(this)
					END;
				END;
			END;
			RETURN result
		END Extends;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this = SELF)
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN	RETURN Extends(to)
		END CompatibleTo;

		PROCEDURE IsComposite*(): BOOLEAN;
		BEGIN RETURN TRUE
		END IsComposite;

		PROCEDURE NeedsTrace*(): BOOLEAN;
		BEGIN RETURN recordScope.NeedsTrace();
		END NeedsTrace;

		PROCEDURE IsRecordType*(): BOOLEAN;
		BEGIN
			RETURN TRUE;
		END IsRecordType;

		PROCEDURE SetFinal*(final: BOOLEAN);
		BEGIN SELF.isFinal := final
		END SetFinal;

	END RecordType;

	CellType*=OBJECT (Type)
	VAR
		firstParameter-,lastParameter-: Parameter; numberParameters-: SIZE;  (* parameters *)
		firstProperty-, lastProperty-: Property; numberProperties: SIZE; (* capabilities *)
		cellScope-: CellScope;
		isCellNet-: BOOLEAN;
		modifiers-: Modifier;
		baseType-: Type;

		PROCEDURE &InitCellType(position: Position; scope: Scope;  cellScope: CellScope);
		BEGIN
			InitType(position);
			SELF.scope := scope;
			numberParameters := 0; firstParameter := NIL; lastParameter := NIL;
			numberProperties := 0; firstProperty := NIL; lastProperty := NIL;
			SELF.cellScope := cellScope;
			isCellNet := FALSE;
			baseType := NIL;
		END InitCellType;

		PROCEDURE SetBaseType*(base: Type);
		BEGIN
			baseType := base;
		END SetBaseType;

		PROCEDURE GetBaseValueType*(): Type;
		BEGIN
			IF baseType = NIL THEN
				RETURN NIL
			ELSIF baseType.resolved IS PointerType THEN
				RETURN baseType.resolved(PointerType).pointerBase.resolved
			ELSE
				RETURN baseType.resolved;
			END;
		END GetBaseValueType;

		PROCEDURE GetBaseRecord*():RecordType;
		BEGIN
			IF baseType = NIL THEN RETURN NIL; END;
			IF baseType.resolved IS CellType THEN
				RETURN baseType.resolved(CellType).GetBaseRecord();
			ELSIF baseType.resolved IS RecordType THEN
				RETURN baseType.resolved(RecordType);
			ELSIF baseType.resolved IS PointerType THEN
				IF baseType.resolved(PointerType).pointerBase.resolved # NIL THEN
					RETURN baseType.resolved(PointerType).pointerBase.resolved(RecordType);
				END;
			END;
			RETURN NIL;
		END GetBaseRecord;

		PROCEDURE AddParameter*(p: Parameter);
		BEGIN
			ASSERT(p # NIL);
			IF lastParameter= NIL THEN firstParameter := p ELSE lastParameter.nextParameter := p; p.prevParameter := lastParameter; END;
			lastParameter := p;
			INC(numberParameters);
		END AddParameter;

		PROCEDURE AddProperty*(p: Property);
		BEGIN
			ASSERT(p # NIL);
			IF lastProperty= NIL THEN firstProperty := p ELSE lastProperty.nextProperty := p; p.prevProperty := lastProperty; END;
			lastProperty := p;
			INC(numberProperties);
		END AddProperty;

		PROCEDURE FindParameter*(identifier: Identifier): Parameter;
		VAR p: Parameter;
		BEGIN
			p := NIL;
			IF (baseType # NIL) & (baseType.resolved IS CellType) THEN
				p := baseType.resolved(CellType).FindParameter(identifier);
			END;
			IF p = NIL THEN
				p := firstParameter;
				WHILE(p#NIL) & (p.name # identifier) DO p := p.nextParameter END;
			END;
			RETURN p;
		END FindParameter;

		PROCEDURE FindProperty*(identifier: Identifier): Property;
		VAR p: Property;
		BEGIN
			p := firstProperty;
			WHILE(p#NIL) & (p.name # identifier) DO p := p.nextProperty END;
			IF p = NIL THEN
				IF (baseType # NIL) & (baseType.resolved IS CellType) THEN
					p := baseType.resolved(CellType).FindProperty(identifier);
				END;
			END;
			RETURN p;
		END FindProperty;

		PROCEDURE SetModifiers*(flag: Modifier);
		BEGIN SELF.modifiers := flag;
		END SetModifiers;

		PROCEDURE IsCellNet*(t: BOOLEAN);
		BEGIN isCellNet := t
		END IsCellNet;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN this = SELF
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN SameType(to)
		END CompatibleTo;

		PROCEDURE IsComposite*(): BOOLEAN;
		BEGIN RETURN TRUE
		END IsComposite;

	END CellType;

	(** <<procedureType = PROCEDURE [{DELEGATE}] (firstParameter .. lastParameter): returnType>>
		also used as type for procedures
	**)
	ProcedureType* = OBJECT (Type)
		VAR
			modifiers-: Modifier; (* set by the parser *)
			returnType-: Type;
			returnTypeModifiers-: Modifier;
			hasUntracedReturn-: BOOLEAN;
			firstParameter-,lastParameter-: Parameter; numberParameters-: SIGNED32;  (* parameters *)
			returnParameter-: Parameter; (* not really necessary in syntax tree but very handy for backends *)
			selfParameter-: Parameter;
			selfParameterInObject-: Parameter;

			isDelegate-,isInterrupt-,noReturn-,isNested-: BOOLEAN;
			pcOffset-: SIZE; (* PC offset: used for ARM interrupt procedures *)
			callingConvention-: CallingConvention;
			stackAlignment-: SIZE;
			parametersOffset-: SIZE; (* stack parameter offset -- in units of addresses: one pointer = 1 *)

		PROCEDURE & InitProcedureType( position: Position; scope: Scope);
		BEGIN
			InitType( position);
			SELF.scope := scope;
			modifiers := NIL;
			firstParameter := NIL; lastParameter := NIL; numberParameters := 0; returnParameter := NIL;
			returnType := NIL;
			stackAlignment := 1;
			isDelegate := FALSE; isInterrupt := FALSE;
			callingConvention := OberonCallingConvention;
			parametersOffset := 0;
			pcOffset := 0;
			hasUntracedReturn := FALSE;
			returnTypeModifiers := NIL;
			selfParameter := NIL;
			isNested := FALSE;
			selfParameterInObject := NIL;
		END InitProcedureType;

		PROCEDURE SetNoReturn*(noReturn: BOOLEAN);
		BEGIN SELF.noReturn := noReturn
		END SetNoReturn;

		PROCEDURE SetPcOffset*(pcOffset: SIZE);
		BEGIN SELF.pcOffset := pcOffset
		END SetPcOffset;

		PROCEDURE SetInterrupt*(isInterrupt: BOOLEAN);
		BEGIN SELF.isInterrupt := isInterrupt
		END SetInterrupt;

		PROCEDURE SetModifiers*(flags: Modifier);
		BEGIN modifiers := flags
		END SetModifiers;

		PROCEDURE SetNested*(nested: BOOLEAN);
		BEGIN
			isNested := nested;
		END SetNested;

		PROCEDURE SetReturnTypeModifiers*(flags: Modifier);
		BEGIN returnTypeModifiers := flags
		END SetReturnTypeModifiers;

		PROCEDURE SetDelegate*(delegate: BOOLEAN);
		BEGIN SELF.isDelegate := delegate; SELF.hasPointers := delegate;
		END SetDelegate;

		PROCEDURE SetUntracedReturn*(untraced: BOOLEAN);
		BEGIN
			hasUntracedReturn := untraced;
		END SetUntracedReturn;

		PROCEDURE SetStackAlignment*(alignment: SIZE);
		BEGIN
			stackAlignment := alignment;
		END SetStackAlignment;

		PROCEDURE SetParametersOffset*(ofs: SIGNED32);
		BEGIN parametersOffset := ofs
		END SetParametersOffset;

		PROCEDURE SetReturnParameter*(parameter: Parameter);
		BEGIN returnParameter := parameter
		END SetReturnParameter;

		PROCEDURE SetSelfParameter*(parameter: Parameter);
		BEGIN selfParameter := parameter
		END SetSelfParameter;


		PROCEDURE SetSelfParameterInObject*(parameter: Parameter);
		BEGIN selfParameterInObject := parameter
		END SetSelfParameterInObject;

		PROCEDURE SetCallingConvention*(cc: CallingConvention);
		BEGIN callingConvention := cc
		END SetCallingConvention;

		PROCEDURE AddParameter*(p: Parameter);
		BEGIN
			ASSERT(p # NIL);
			IF lastParameter= NIL THEN firstParameter := p ELSE lastParameter.nextParameter := p; p.prevParameter := lastParameter; END;
			lastParameter := p;
			INC(numberParameters);
			ASSERT(p.access # {}); (* no hidden parameters ! *)
		END AddParameter;

		PROCEDURE RevertParameters*;
		VAR this,next: Parameter; pnum: SIGNED32;
		BEGIN
			pnum := numberParameters;
			IF lastParameter # NIL THEN
				this := lastParameter;
				lastParameter := NIL;
				firstParameter := NIL;
				numberParameters := 0;
				WHILE this # NIL DO
					next := this.prevParameter;
					this.prevParameter := NIL; this.nextParameter := NIL;
					AddParameter(this);
					this := next;
				END;
			END;
			ASSERT(pnum = numberParameters);
		END RevertParameters;

		PROCEDURE SetReturnType*( type: Type );
		BEGIN
			returnType := type;
		END SetReturnType;

		PROCEDURE SameSignature*(this: Type): BOOLEAN;
		VAR result: BOOLEAN; p1,p2: Parameter;
		BEGIN
			result := FALSE;
			IF recursion THEN
				result := TRUE
			ELSIF this = SELF THEN
				result := TRUE
			ELSIF this IS ProcedureType THEN
				recursion := TRUE;
				WITH this: ProcedureType DO
					result := (returnType = NIL) & (this.returnType = NIL) OR (returnType # NIL) & (this.returnType # NIL) & returnType.SameType(this.returnType.resolved);
					result := result & (callingConvention = this.callingConvention);
					result := result & (noReturn = this.noReturn);
					result :=  result & (isInterrupt = this.isInterrupt);
					result := result & (isNested = this.isNested);
					IF result THEN

						p1 := selfParameter; p2 := this.selfParameter;
						IF (p1 = NIL) # (p2=NIL) OR (p1 # NIL) & ((p1.kind # p2.kind)) THEN
							RETURN FALSE
						END;

						p1 := firstParameter; p2 := this.firstParameter;
						WHILE (p1 # NIL) & (p2 # NIL) & (p1.access # Hidden) & (p2.access # Hidden) & (p1.kind = p2.kind) & (p1.type.SameType(p2.type) OR (p2.type.resolved # NIL) & p1.type.SameType(p2.type.resolved) OR (p1.type.resolved IS AddressType) & (p2.type.resolved IS PointerType) & p2.type.resolved(PointerType).isUnsafe) DO
							p1 := p1.nextParameter; p2 := p2.nextParameter
						END;
						result := ((p1=NIL) OR (p1.access = Hidden)) & ((p2=NIL)  OR (p2.access= Hidden));
					END;
				END;
			END;
			recursion := FALSE;
			RETURN result

		END SameSignature;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN
			RETURN SameSignature(this)
				& (this(ProcedureType).isDelegate = isDelegate)
				& (this(ProcedureType).isRealtime = isRealtime);
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN
			RETURN SameSignature(to) & (~isDelegate OR to(ProcedureType).isDelegate) & (~to.isRealtime OR isRealtime)
					& ((stackAlignment <=1) OR (stackAlignment <= to(ProcedureType).stackAlignment));
		END CompatibleTo;

		PROCEDURE IsComposite*(): BOOLEAN;
		BEGIN RETURN isDelegate
		END IsComposite;

		(** Returns if the type needs to be traced for garbage collection *)
		PROCEDURE NeedsTrace*(): BOOLEAN;
		BEGIN RETURN isDelegate;
		END NeedsTrace;

	END ProcedureType;

	(**** expressions ****)

	Expression* = OBJECT
		VAR
			type-: Type; (* the expression's type. Resolved by checker *)
			assignable-: BOOLEAN;  (* expression can be assigned to (or used as var-parameter): expression := ... *)
			position-, end-: Position;
			state-: SET;
			resolved-: Value;
			original-: Expression;
			isHidden-: BOOLEAN;

		PROCEDURE End*( position: Position);
		BEGIN SELF.end := position;
		END End;

		PROCEDURE SetState*(state: SIGNED32);
		BEGIN	INCL(SELF.state,state);
		END SetState;

		PROCEDURE &InitExpression(position: Position);
		BEGIN
			SELF.position := position; end :=  invalidPosition; state := Undefined; type := NIL; assignable := FALSE; resolved := NIL; isHidden := FALSE;
			original := NIL;
		END InitExpression;

		PROCEDURE SetHidden*(hidden: BOOLEAN);
		BEGIN isHidden := hidden
		END SetHidden;
		PROCEDURE SetType*(type: Type);
		BEGIN
			SELF.type := type;
		END SetType;

		PROCEDURE SetResolved*(value: Value);
		BEGIN SELF.resolved := value
		END SetResolved;

		PROCEDURE SetAssignable*(assignable: BOOLEAN);
		BEGIN SELF.assignable := assignable
		END SetAssignable;

		PROCEDURE SetOriginal*(original: Expression);
		BEGIN
			SELF.original := original;
		END SetOriginal;

		(* overwritten in designators *)
		PROCEDURE SetRelatedRhs*(expression: Expression);
		BEGIN
		END SetRelatedRhs;

		PROCEDURE NeedsTrace* (): BOOLEAN;
		BEGIN RETURN FALSE;
		END NeedsTrace;

		PROCEDURE Equals*(other: Expression): BOOLEAN;
		BEGIN
			IF other = NIL THEN RETURN FALSE END;
			IF resolved # NIL THEN RETURN resolved.Equals(other.resolved) END;
			RETURN other = SELF;
		END Equals;

	END Expression;

	(** <<expression, expression, ...>> **)
	ExpressionList* = OBJECT
		VAR list: Basic.List;

		PROCEDURE & InitList;
		BEGIN NEW( list,8 ); list.nilAllowed := TRUE;
		END InitList;

		PROCEDURE Length*( ): SIZE;
		BEGIN RETURN list.Length();
		END Length;

		PROCEDURE AddExpression*( d: Expression );
		BEGIN list.Add(d)
		END AddExpression;

		PROCEDURE GetExpression*( index: SIZE ): Expression;
		VAR p: ANY;
		BEGIN
			p := list.Get(index);
			IF p = NIL THEN
				RETURN NIL
			ELSE
				RETURN p(Expression);
			END;
		END GetExpression;

		PROCEDURE SetExpression*(index: SIZE; expression: Expression);
		BEGIN list.Set(index,expression)
		END SetExpression;

		PROCEDURE RemoveExpression*(i: SIZE);
		BEGIN list.RemoveByIndex(i);
		END RemoveExpression;

		PROCEDURE Revert*;
		VAR i,j,last: SIZE; ei,ej: ANY;
		BEGIN
			last := Length()-1;
			FOR i := 0 TO last DO
				j := last-i;
				ei := list.Get(i);
				ej := list.Get(j);
				list.Set(i,ej);
				list.Set(j,ei);
			END;
		END Revert;

		PROCEDURE Equals(other: ExpressionList): BOOLEAN;
		VAR i: SIZE;
		BEGIN
			IF other = NIL THEN RETURN FALSE END;
			IF other.Length() # Length() THEN RETURN FALSE END;
			FOR i := 0 TO Length()-1 DO
				IF ~GetExpression(i).Equals(other.GetExpression(i)) THEN RETURN FALSE END;
			END;
			RETURN TRUE;
		END Equals;



	END ExpressionList;

	(** << {elements} >>  **)
	Set* = OBJECT (Expression)
		VAR elements-: ExpressionList; (* an element of the form from .. to is represented as a RangeExpression *)

		PROCEDURE & InitSet( position: Position; e: ExpressionList );
		BEGIN
			InitExpression( position );
			elements := e;
		END InitSet;

	END Set;

	(** << [elements] >>  **)
	MathArrayExpression* = OBJECT (Expression)
		VAR elements-: ExpressionList; (* an element of the form from .. to is represented as a RangeExpression *)

		PROCEDURE & InitMathArrayExpression( position: Position; elems: ExpressionList );
		BEGIN
			InitExpression( position );
			elements := elems;
		END InitMathArrayExpression;

		PROCEDURE Equals(e: Expression): BOOLEAN;
		BEGIN
			IF (e = NIL) OR ~(e IS MathArrayExpression) THEN RETURN FALSE
			ELSE RETURN elements.Equals(e(MathArrayExpression).elements)
			END;
		END Equals;

	END MathArrayExpression;

	(** <<operator left>> **)
	UnaryExpression* = OBJECT (Expression)
		VAR
			left-: Expression;
			operator-: SIGNED32;  (* one of Scanner.Minus ... Scanner.Not *)

		PROCEDURE & InitUnaryExpression( position: Position;  operand: Expression;  operator: SIGNED32 );
		BEGIN
			InitExpression( position );  SELF.left := operand;  SELF.operator := operator;
		END InitUnaryExpression;

		PROCEDURE SetLeft*(left: Expression);
		BEGIN SELF.left := left
		END SetLeft;
	END UnaryExpression;

	(** <<left operator right>> **)
	BinaryExpression* = OBJECT (Expression)
		VAR
			left-, right-: Expression;
			operator-: SIGNED32;  (* one of Scanner.Equal ... Scanner.Minus *)

		PROCEDURE & InitBinaryExpression( position: Position;  left, right: Expression;  operator: SIGNED32 );
		BEGIN
			InitExpression( position );  SELF.left := left;  SELF.right := right;  SELF.operator := operator;
		END InitBinaryExpression;

		PROCEDURE SetLeft*(left: Expression);
		BEGIN SELF.left := left
		END SetLeft;

		PROCEDURE SetRight*(right: Expression);
		BEGIN SELF.right := right
		END SetRight;
	END BinaryExpression;

	(** expression that denotes a range
		<<[first] '..' [last] ['by' step] | '*' >>
	**)
	RangeExpression* = OBJECT (Expression)
	VAR
		first-, last-, step-: Expression;
		missingFirst-, missingLast-, missingStep-: BOOLEAN; (* only for printout*)
		context-: SIGNED8; (* one of ArrayIndex, SetElement or CaseGuard *)

		PROCEDURE &InitRangeExpression(position: Position; first, last, step: Expression);
		BEGIN
			context := ArrayIndex; (* by default, a range represents array indices *)
			InitExpression(position);
			missingFirst := (first = NIL);
			missingLast := (last = NIL);
			missingStep := (step = NIL);
			SELF.first := first;
			SELF.last := last;
			SELF.step := step;
		END InitRangeExpression;

		PROCEDURE SetFirst*(first: Expression);
		BEGIN
			SELF.first := first
		END SetFirst;

		PROCEDURE SetLast*(last: Expression);
		BEGIN SELF.last := last
		END SetLast;

		PROCEDURE SetStep*(step: Expression);
		BEGIN SELF.step := step
		END SetStep;

		PROCEDURE SetContext*(context: SIGNED8);
		BEGIN
			SELF.context := context
		END SetContext;

	END RangeExpression;

	(** << ? >> **)
	TensorRangeExpression*=OBJECT (Expression);

		PROCEDURE &InitTensorRangeExpression(position: Position);
		BEGIN
			InitExpression(position);
		END InitTensorRangeExpression;

	END TensorRangeExpression;

	(** convert expression from expression.type to Conversion.type **)
	Conversion* = OBJECT (Expression)
		VAR
			expression-: Expression;
			typeExpression-: Expression; (* for printout *)

		PROCEDURE & InitConversion( position: Position; expression: Expression; type: Type; typeExpression: Expression);
		BEGIN
			InitExpression( position );  SELF.expression := expression;  SELF.typeExpression := typeExpression; SELF.type := type;
		END InitConversion;


		PROCEDURE SetExpression*(expression: Expression);
		BEGIN SELF.expression := expression
		END SetExpression;

	END Conversion;

	(**** designators ****)

	(** abstract **)
	Designator* = OBJECT(Expression)
		VAR
			left-: Expression;
			modifiers-: Modifier;
			relatedRhs-: Expression;

		PROCEDURE &InitDesignator*(position: Position);
		BEGIN
			InitExpression(position);
			left := NIL;
			modifiers := NIL;
			relatedRhs := NIL;
		END InitDesignator;

		PROCEDURE SetLeft*(l: Expression);
		BEGIN left := l
		END SetLeft;

		PROCEDURE SetModifiers*(flags: Modifier);
		BEGIN modifiers := flags
		END SetModifiers;

		PROCEDURE SetRelatedRhs*(expression: Expression);
		BEGIN
			relatedRhs := expression;
		END SetRelatedRhs;

	END Designator;

	(*** first phase (parse time) designators ***)

	(** <<identifier>>
		may designate any symbol such as Variable, TypeDeclaration, Procedure
	**)
	IdentifierDesignator* = OBJECT(Designator)
		VAR identifier-: Identifier;

		PROCEDURE &InitIdentifierDesignator(position: Position; id: Identifier);
		BEGIN InitDesignator(position); identifier := id
		END InitIdentifierDesignator;

	END IdentifierDesignator;

	(** <<left.identifier>>
		may designate a record / module element (constant, type, variable, procedure)
	**)
	SelectorDesignator* = OBJECT (Designator)
		VAR identifier-: Identifier;

		PROCEDURE & InitSelector(position: Position; left: Expression; identifier: Identifier);
		BEGIN   InitDesignator(position); SELF.left := left; SELF.identifier := identifier;
		END InitSelector;

	END SelectorDesignator;

	(** <<left(arg1, arg2, ...)>>
		may designate a function call or a type guard
	**)
	ParameterDesignator* = OBJECT(Designator)
		VAR
			parameters-: ExpressionList;

		PROCEDURE &InitParameterDesignator(position: Position; left: Expression; parameters: ExpressionList);
		BEGIN InitDesignator(position); SELF.left := left; SELF.parameters := parameters
		END InitParameterDesignator;

	END ParameterDesignator;

	(** <<left^>>
		may designate a pointer dereference or a method supercall
	**)
	ArrowDesignator* = OBJECT (Designator)

		PROCEDURE &InitArrowDesignator(position: Position; left: Expression);
		BEGIN InitDesignator(position); SELF.left := left;
		END InitArrowDesignator;

	END ArrowDesignator;

	(** <<left[parameters]>>
		designates an index designator, before checker
	**)
	BracketDesignator* = OBJECT(Designator)
		VAR parameters-: ExpressionList;

		PROCEDURE &InitBracketDesignator(position: Position; left: Expression; parameters: ExpressionList);
		BEGIN InitDesignator(position); SELF.left := left; SELF.parameters := parameters;
		END InitBracketDesignator;

	END BracketDesignator;

	(*** second phase (after checker) designators ***)

	(** symbol designator emerged from IdentifierDesignator or from Selector **)
	SymbolDesignator* = OBJECT(Designator)
	VAR
		symbol-: Symbol;

		PROCEDURE &InitSymbolDesignator(position: Position; original: Expression; left: Expression; symbol: Symbol);
		BEGIN
			InitDesignator(position);
			SELF.left := left;
			SELF.symbol := symbol;
			SELF.original := original;
		END InitSymbolDesignator;

		PROCEDURE SetSymbol*(s: Symbol);
		BEGIN SELF.symbol := s;
		END SetSymbol;

		PROCEDURE NeedsTrace* (): BOOLEAN;
		BEGIN
			RETURN symbol.NeedsTrace() & ((left = NIL) OR (left.NeedsTrace()));
		END NeedsTrace;

	END SymbolDesignator;

	(** <<left[parameters]>>
		(ranged) indexer
	**)
	IndexDesignator* = OBJECT(Designator)
		VAR
			parameters-: ExpressionList;
			hasRange-: BOOLEAN;
			hasTensorRange-: BOOLEAN;

		PROCEDURE &InitIndexDesignator(position: Position; original: Expression; left: Expression; pars: ExpressionList);
		BEGIN
			InitDesignator(position);
			SELF.left := left;
			SELF.original := original;
			parameters := pars;
			hasRange := FALSE;
			hasTensorRange := FALSE;
		END InitIndexDesignator;

		PROCEDURE HasRange*;
		BEGIN hasRange := TRUE;
		END HasRange;

		PROCEDURE HasTensorRange*;
		BEGIN hasTensorRange := TRUE;
		END HasTensorRange;

		PROCEDURE NeedsTrace* (): BOOLEAN;
		BEGIN RETURN type.NeedsTrace() & left.NeedsTrace(); (* for x[y]: if x is untraced, then also x[y] should be treated untraced *)
		END NeedsTrace;

	END IndexDesignator;


	(** <<left(parameters)>>
		procedure call
	**)
	ProcedureCallDesignator*= OBJECT (Designator)
		VAR parameters-: ExpressionList;

		PROCEDURE & InitProcedureCallDesignator(position: Position; original: Expression; left: Expression;  parameters: ExpressionList);
		BEGIN
			InitDesignator(position);
			SELF.original := original; SELF.left := left; SELF.parameters := parameters;
		END InitProcedureCallDesignator;

	END ProcedureCallDesignator;

	InlineCallDesignator*= OBJECT(Designator)
	VAR
		block-: StatementBlock; (* contains scope *)
		result-: Expression;

		PROCEDURE & InitInlineCall*(position: Position; orig: Expression; b: StatementBlock);
		BEGIN
			InitDesignator(position);
			original := orig;
			block := b;
		END InitInlineCall;

		PROCEDURE SetResult*(e: Expression);
		BEGIN
			result := e;
		END SetResult;

	END InlineCallDesignator;

	(** <<procedure(parameters)>>
		builtin procedure call **)
	BuiltinCallDesignator*= OBJECT (Designator) (*! should this be an extension of a procedure call designator ? *)
		VAR
			id-: SIGNED32;
			parameters-: ExpressionList;
			builtin-: Builtin;
			returnType-: Type;
			expression-: Expression;

		PROCEDURE & InitBuiltinCallDesignator(position: Position; orig: Expression; id: SIGNED32; left: Expression; parameters: ExpressionList);
		BEGIN
			InitDesignator(position);
			SELF.parameters := parameters; SELF.id := id; SELF.left := left; returnType := NIL; original := orig;
			expression := NIL;
		END InitBuiltinCallDesignator;

		PROCEDURE SetReturnType*(type: Type);
		BEGIN
			returnType := type (* used for NEW Type() expression *)
		END SetReturnType;

		PROCEDURE SetExpression*(e: Expression);
		BEGIN
			expression := e;
		END SetExpression;


	END BuiltinCallDesignator;

	(** <<left(type)>>
		resolved parameter designator, designates a type guard
	**)
	TypeGuardDesignator* = OBJECT(Designator)
	VAR
		typeExpression-: Expression; (* for printing only *)

		PROCEDURE &InitTypeGuardDesignator(position: Position; orig: Expression; left: Expression; type: Type);
		BEGIN InitDesignator(position); SELF.left := left; SELF.type := type; typeExpression := NIL; original := orig;
		END InitTypeGuardDesignator;

		PROCEDURE SetTypeExpression*(typeExpression: Expression);
		BEGIN SELF.typeExpression := typeExpression
		END SetTypeExpression;

		PROCEDURE NeedsTrace* (): BOOLEAN;
		BEGIN RETURN left.NeedsTrace() & type.NeedsTrace(); (* for x(Y): if x is untraced, then x as Y should also be treated untraced  *)
		END NeedsTrace;

	END TypeGuardDesignator;

	(** <<left^>> resolved as dereference operation on pointer variable left **)
	DereferenceDesignator*= OBJECT (Designator)

		PROCEDURE &InitDereferenceDesignator(position: Position; orig: Expression; left: Expression);
		BEGIN InitDesignator(position); SELF.left := left; original := orig;
		END InitDereferenceDesignator;

		PROCEDURE NeedsTrace* (): BOOLEAN;
		BEGIN
			(*! semantic of x.y.z := new : if x is untraced then the effect of y.z := new remains untraced!
				In other words: difference between y := x.y; y.z := new and x.y.z := new.
			*)
			RETURN left.NeedsTrace() & type.NeedsTrace(); (* for x^: if x is an untraced pointer, the content of x^ is also treated untraced *)
		END NeedsTrace;

	END DereferenceDesignator;

	(** <<left^>> resolved as supercall operation on method left **)
	SupercallDesignator*= OBJECT (Designator)

		PROCEDURE &InitSupercallDesignator(position: Position; orig: Expression; left: Expression);
		BEGIN InitDesignator(position); SELF.left := left; original := orig;
		END InitSupercallDesignator;

	END SupercallDesignator;

	(**  <<SELF.x>> **)
	SelfDesignator*= OBJECT (Designator)

		PROCEDURE &InitSelfDesignator(position: Position; orig: Expression);
		BEGIN InitDesignator(position); original := orig;
		END InitSelfDesignator;

		PROCEDURE NeedsTrace* (): BOOLEAN;
		BEGIN RETURN type.NeedsTrace();
		END NeedsTrace;

	END SelfDesignator;

	(** <<RESULT>> **)
		ResultDesignator*= OBJECT (Designator)

		PROCEDURE &InitResultDesignator(position: Position);
		BEGIN InitDesignator(position);
		END InitResultDesignator;

	END ResultDesignator;

	(**** values ****)

	Value* = OBJECT (Expression)

		PROCEDURE &InitValue(position: Position);
		BEGIN SELF.position := position; resolved := SELF;
		END InitValue;

		PROCEDURE Equals*(v: Expression):BOOLEAN;
		BEGIN HALT(100); (* abstract *) RETURN FALSE; END Equals;

	END Value;

	(** <<value = TRUE , FALSE>> **)
	BooleanValue* = OBJECT (Value)
		VAR
			value-: BOOLEAN;

		PROCEDURE & InitBooleanValue(position: Position; value: BOOLEAN);
		BEGIN
			InitValue(position);  SELF.value := value;
		END InitBooleanValue;

		PROCEDURE SetValue*(value: BOOLEAN);
		BEGIN	SELF.value := value
		END SetValue;

		PROCEDURE Equals*(v: Expression):BOOLEAN;
		BEGIN RETURN (v# NIL) & (v IS BooleanValue) & (v(BooleanValue).value = value); END Equals;

	END BooleanValue;

	(** <<value = 123456>> **)
	IntegerValue* = OBJECT (Value)
		VAR
			value-: Basic.Integer;

		PROCEDURE & InitIntegerValue(position: Position; value: Basic.Integer);
		BEGIN
			InitValue(position);  SELF.value := value;
		END InitIntegerValue;

		PROCEDURE SetValue*(value: Basic.Integer);
		BEGIN	SELF.value := value;
		END SetValue;

		PROCEDURE Equals*(v: Expression):BOOLEAN;
		BEGIN RETURN (v# NIL) & (v IS IntegerValue) & (v(IntegerValue).value = value); END Equals;

	END IntegerValue;

	(** <<value =  'c',  65X>> **)
	CharacterValue*= OBJECT(Value)
		VAR
			value-: CHAR; (* potential for extension to support CHAR16 and CHAR32 *)

		PROCEDURE & InitCharacterValue(position: Position; value: CHAR);
		BEGIN
			InitValue(position);  SELF.value := value;
		END InitCharacterValue;

		PROCEDURE SetValue*(value: CHAR);
		BEGIN	SELF.value := value
		END SetValue;

		PROCEDURE Equals*(v: Expression):BOOLEAN;
		BEGIN RETURN (v# NIL) & (v IS CharacterValue) & (v(CharacterValue).value = value); END Equals;

	END CharacterValue;

	TYPE SetValueAlias = SetValue;

	(** <<value =  {1,2,3..5}>> **)
	SetValue* = OBJECT (Value)
		VAR
			value-: Basic.Set;

		PROCEDURE & InitSetValue(position: Position; value: Basic.Set);
		BEGIN
			InitValue(position);  SELF.value := value;
		END InitSetValue;

		PROCEDURE SetValue*(value: Basic.Set);
		BEGIN	SELF.value := value
		END SetValue;

		PROCEDURE Equals*(v: Expression):BOOLEAN;
		BEGIN RETURN (v# NIL) & (v IS SetValueAlias) & (v(SetValueAlias).value = value); END Equals;

	END SetValue;

		(** << [elements] >>  **)
	MathArrayValue* = OBJECT (Value)
		VAR array-: MathArrayExpression; (* an element of the form from .. to is represented as a RangeExpression *)

		PROCEDURE & InitMathArrayValue(position: Position; arr: MathArrayExpression);
		BEGIN
			InitValue(position);
			array := arr;
		END InitMathArrayValue;

		PROCEDURE Equals*(v: Expression):BOOLEAN;
		BEGIN RETURN (v# NIL) & (v IS MathArrayValue) & (v(MathArrayValue).array.Equals(array)); END Equals;

	END MathArrayValue;

	(** <<value = 1.2345E01>> **)
	RealValue* = OBJECT (Value)
		VAR
			value-: FLOAT64;
			subtype-: SubType; (* accuracy information: FLOAT32 vs. FLOAT64 *)

		PROCEDURE & InitRealValue(position: Position; value: FLOAT64; subType: SubType);
		BEGIN
			InitValue(position);  SELF.value := value; SELF.subtype := subType;
		END InitRealValue;

		PROCEDURE SetValue*(value: FLOAT64);
		BEGIN	SELF.value := value
		END SetValue;

		PROCEDURE SetSubtype*(subtype: SubType);
		BEGIN SELF.subtype := subtype;
		END SetSubtype;

		PROCEDURE Equals*(v: Expression):BOOLEAN;
		BEGIN RETURN (v# NIL) & (v IS RealValue) & (v(RealValue).value = value); END Equals;

	END RealValue;

	ComplexValue* = OBJECT (Value)
		VAR
			realValue-, imagValue-: FLOAT64;
			subtype-: SubType; (* accuracy information of components: FLOAT32 vs. FLOAT64 *)

		PROCEDURE & InitComplexValue(position: Position; realValue, imagValue: FLOAT64; subType: SubType);
		BEGIN
			InitValue(position); SELF.realValue := realValue; SELF.imagValue := imagValue; SELF.subtype := subType;
		END InitComplexValue;

		PROCEDURE SetValue*(realValue, imagValue: FLOAT64);
		BEGIN	SELF.realValue := realValue; SELF.imagValue := imagValue;
		END SetValue;

		PROCEDURE UpdateSubtype*;
		BEGIN
			ASSERT((type # NIL) & (type.resolved # NIL) & (type.resolved IS ComplexType) & (type.resolved(ComplexType).componentType IS FloatType));
			CASE type.resolved(ComplexType).componentType(FloatType).sizeInBits OF
			| 32: subtype := Scanner.Real
			| 64: subtype := Scanner.Longreal
			END
		END UpdateSubtype;

		PROCEDURE SetSubtype*(subtype: SubType);
		BEGIN SELF.subtype := subtype;
		END SetSubtype;

		PROCEDURE Equals*(v: Expression):BOOLEAN;
		BEGIN RETURN (v# NIL) & (v IS ComplexValue) & (v(ComplexValue).realValue = realValue) & (v(ComplexValue).imagValue = imagValue);
		END Equals;
	END ComplexValue;

	(** <<value = "string">> **)
	StringValue* = OBJECT (Value)
		VAR
			value-: String;
			length-: SIZE;

		PROCEDURE & InitStringValue(position: Position; value: String);
		BEGIN
			InitValue(position);  SELF.value := value;
			length := 0;
			WHILE (length<LEN(value)) & (value[length] # 0X) DO
				INC(length);
			END;
			IF length < LEN(value) THEN INC(length) END
		END InitStringValue;

		PROCEDURE SetValue*(CONST value: String);
		BEGIN	SELF.value := value
		END SetValue;

		PROCEDURE Append*(CONST value: String);
		VAR new: String; len: SIZE;
		BEGIN
			len := Strings.Length(SELF.value^) + Strings.Length(value^) + 1;
			IF LEN(SELF.value) < len THEN
				NEW(new, len);
				COPY(SELF.value^, new^);
				SELF.value := new
			END;
			Strings.Append(SELF.value^, value^);
			length := len;
		END Append;

		PROCEDURE AppendChar*(CONST ch: CHAR);
		VAR v: String;
		BEGIN
			NEW(v,2); v[0] := ch;
			Append(v);
		END AppendChar;

		PROCEDURE Equals*(v: Expression):BOOLEAN;
		BEGIN RETURN (v# NIL) & (v IS StringValue) & (v(StringValue).value = value); END Equals;

	END StringValue;

	(** <<value = NIL>> **)
	NilValue* = OBJECT (Value)

		PROCEDURE Equals*(v: Expression):BOOLEAN;
		BEGIN RETURN (v# NIL) & (v IS NilValue); END Equals;

	END NilValue;

	(** <<value = enum.x >> **)
	EnumerationValue* = OBJECT (Value)
	VAR
		value-: Basic.Integer;

		PROCEDURE & InitEnumerationValue(position: Position; value: Basic.Integer);
		BEGIN
			InitValue(position);  SELF.value := value;
		END InitEnumerationValue;

		PROCEDURE SetValue*(value: Basic.Integer);
		BEGIN SELF.value := value
		END SetValue;

		PROCEDURE Equals*(v: Expression):BOOLEAN;
		BEGIN RETURN (v# NIL) & (v IS EnumerationValue) & (v(EnumerationValue).value = value); END Equals;

	END EnumerationValue;

	ProcedureValue* = OBJECT (Value)
	VAR
		value-: Procedure;

		PROCEDURE & InitProcedureValue(position: Position; value: Procedure);
		BEGIN
			InitValue(position);  SELF.value := value;
		END InitProcedureValue;

		PROCEDURE SetValue*(value: Procedure);
		BEGIN SELF.value := value
		END SetValue;

		PROCEDURE Equals*(v: Expression):BOOLEAN;
		BEGIN RETURN (v# NIL) & (v IS ProcedureValue) & (v(ProcedureValue).value = value); END Equals;

	END ProcedureValue;

	(**** symbols ****)

	Symbol*= OBJECT
	VAR
		nextSymbol-: Symbol;

		name-: Identifier; (* constant / variable / parameter / type name / module name *)
		extern-: Expression; (* const expression: either address or String *)
		externName-: Scanner.StringType;
		access-: SET; (* access flags (exported, readonly etc.) *)
		type-: Type; (* type of constant / variable / parameter / procedure return type *)
		scope-:Scope; (* container of symbol *)
		offsetInBits-: SIZE; (* offset in stack or heap, in bits *)
		used-, written-: BOOLEAN;
		fixed-: BOOLEAN;
		alignment-: SIZE;

		position-, end-: Position; state-: SET;
		fingerprint-: Fingerprint;

		comment-: Comment;

		PROCEDURE & InitSymbol(position: Position; name:Identifier);
		BEGIN
			SELF.position := position; state := Undefined;
			SELF.end := invalidPosition;
			nextSymbol := NIL;
			SELF.name := name;
			extern := NIL;
			scope:= NIL;
			type := NIL;
			access := Internal;
			state := Undefined;
			offsetInBits := MIN(SIZE);
			alignment := 0; (* take default *)
			fixed := FALSE;
			used := FALSE; written := FALSE;
			comment := NIL;
		END InitSymbol;

		PROCEDURE Copy(target: Symbol);
		BEGIN
			target.type := type;
			target.alignment := alignment;
			target.name := name;
		END Copy;

		PROCEDURE SetAlignment*(fix: BOOLEAN; align: SIZE);
		BEGIN SELF.alignment := align; fixed := fix;
		END SetAlignment;

		PROCEDURE SetFingerprint*(CONST fp: Fingerprint);
		BEGIN
			SELF.fingerprint := fp
		END SetFingerprint;

		PROCEDURE SetState*(state: SIGNED32);
		BEGIN	INCL(SELF.state,state);
		END SetState;

		PROCEDURE SetScope*(scope: Scope);
		BEGIN	SELF.scope := scope
		END SetScope;

		PROCEDURE SetType*(type: Type);
		BEGIN
			SELF.type := type;
		END SetType;

		PROCEDURE SetNext*(symbol: Symbol);
		BEGIN SELF.nextSymbol := symbol; END SetNext;

		PROCEDURE SetAccess*(access: SET);
		BEGIN
			(* consistency guarantee *)
			IF PublicWrite IN access THEN ASSERT(ProtectedWrite IN access)  END;
			IF ProtectedWrite IN access THEN ASSERT(InternalWrite IN access) END;
			IF PublicRead IN access THEN ASSERT(ProtectedRead IN access)  END;
			IF ProtectedRead IN access THEN ASSERT(InternalRead IN access)END;
			SELF.access := access;
		END SetAccess;

		PROCEDURE SetOffset*(ofs: SIZE);
		BEGIN offsetInBits := ofs
		END SetOffset;

		PROCEDURE MarkUsed*;
		BEGIN used := TRUE
		END MarkUsed;

		PROCEDURE MarkWritten*;
		BEGIN written := TRUE
		END MarkWritten;

		PROCEDURE GetName*(VAR str: ARRAY OF CHAR);
		BEGIN Basic.GetString(name, str);
		END GetName;

		PROCEDURE SetComment*(comment: Comment);
		BEGIN SELF.comment := comment
		END SetComment;

		PROCEDURE SetExtern*(e: Expression);
		BEGIN extern := e;
		END SetExtern;

		PROCEDURE SetExternName*(name: Scanner.StringType);
		BEGIN
			externName := name;
		END SetExternName;

		PROCEDURE NeedsTrace* (): BOOLEAN;
		BEGIN RETURN FALSE;
		END NeedsTrace;

		(* If a symbol needs to be vieible in the object file
			A symbol needs to be visible in an object file when it is require during linking
			This is the case for exported symbols but also for methods in a method table, for instance.
		*)
		PROCEDURE NeedsSection*(): BOOLEAN;
		BEGIN
			RETURN access * Public # {};
		END NeedsSection;

	END Symbol;


	(** <<expression, expression, ...>> **)
	Symbols* = OBJECT
		VAR list: Basic.List;

		PROCEDURE & InitList*;
		BEGIN NEW( list,8 );
		END InitList;

		PROCEDURE Length*( ): SIZE;
		BEGIN RETURN list.Length();
		END Length;

		PROCEDURE Add*( d: Symbol );
		BEGIN list.Add(d)
		END Add;

		PROCEDURE Get*( index: SIZE ): Symbol;
		VAR p: ANY;
		BEGIN
			p := list.Get(index); RETURN p(Symbol);
		END Get;

		PROCEDURE Set*(index: SIZE; symbol: Symbol);
		BEGIN list.Set(index,symbol)
		END Set;

		PROCEDURE Remove*(i: SIZE);
		BEGIN list.RemoveByIndex(i);
		END Remove;

	END Symbols;


	(** <<expression, expression, ...>> **)
	Variables* = OBJECT
		VAR list: Basic.List;

		PROCEDURE & InitList*;
		BEGIN NEW( list,8 );
		END InitList;

		PROCEDURE Length*( ): SIZE;
		BEGIN RETURN list.Length();
		END Length;

		PROCEDURE Add*( d: Variable );
		BEGIN list.Add(d)
		END Add;

		PROCEDURE Get*( index: SIZE ): Variable;
		VAR p: ANY;
		BEGIN
			p := list.Get(index); RETURN p(Variable);
		END Get;

		PROCEDURE Set*(index: SIZE; symbol: Variable);
		BEGIN list.Set(index,symbol)
		END Set;

		PROCEDURE Remove*(i: SIZE);
		BEGIN list.RemoveByIndex(i);
		END Remove;

	END Variables;


	(**
		<<TYPE name = declaredType>>
		TypeDeclaration symbol represents a type declaration of the form TYPE name  = declaredType.
		Note that the declared type is not stored in the symbol's type field but rather in the declaredType field.
		The type of a type declaration is set to "typeDeclarationType" in the semantic checker
	**)
	TypeDeclaration*= OBJECT(Symbol)
	VAR
		nextTypeDeclaration-: TypeDeclaration;
		declaredType-: Type;

		PROCEDURE &InitTypeDeclaration(position: Position; name: Identifier);
		BEGIN
			InitSymbol(position,name);
			nextTypeDeclaration := NIL;
			declaredType := NIL;
			type := typeDeclarationType;
		END InitTypeDeclaration;

		PROCEDURE SetDeclaredType*(type: Type);
		BEGIN
			declaredType := type;
			IF ~(type IS BasicType) & (type.typeDeclaration = NIL)  THEN
				type.typeDeclaration := SELF;
			END;
		END SetDeclaredType;

		PROCEDURE SetType*(type: Type);
		BEGIN
			ASSERT(type = typeDeclarationType);
		END SetType;

		(* type declarations should be generally included in object files *)
		PROCEDURE NeedsSection*(): BOOLEAN;
		BEGIN
			RETURN TRUE;
		END NeedsSection;

	END TypeDeclaration;

	(** <<CONST name = value >>
		Constant declaration symbol. Represents a constant being defined in the form CONST name  =  value
		The type of the constant is stored in the type field and is resolved by the semantic checker.
	**)
	Constant* = OBJECT (Symbol)
	VAR
		value-: Expression;
		nextConstant-: Constant;

		PROCEDURE & InitConstant( position: Position;  name: Identifier );
		BEGIN
			InitSymbol(position,name);
			value := NIL;
			nextConstant := NIL;
		END InitConstant;

		PROCEDURE Clone*(): Constant;
		VAR new: Constant;
		BEGIN
			NEW(new, position, name);
			Copy(new);
			new.value := CloneExpression(value);
			RETURN new;
		END Clone;

		PROCEDURE SetValue*( value: Expression );
		BEGIN
			SELF.value := value;
		END SetValue;

	END Constant;

	(** <<VAR name: type >>
		Variable declaration symbol. Represents a variable defined in the form VAR name: Type.
		The type of the variable is stored in the symbol's type field and is resolved by the semantic checker.
	**)
	Variable* = OBJECT (Symbol)
	VAR
		nextVariable-: Variable;
		untraced-: BOOLEAN;

		registerNumber-: SIZE;
		inRegister-: BOOLEAN;
		preferRegister-: BOOLEAN;

		modifiers-: Modifier;
		initializer-: Expression;

		usedAsReference-: BOOLEAN;
		kind-: SIGNED32;   (* ValueParameter, ConstParameter, VarParameter *)

		PROCEDURE & InitVariable*( position: Position;  name: Identifier);
		BEGIN
			InitSymbol(position,name);
			SELF.kind := ValueParameter;
			nextVariable := NIL;
			untraced := FALSE;
			modifiers := NIL;
			preferRegister := FALSE;
			inRegister := FALSE;
			registerNumber := -1;
			usedAsReference := FALSE;
			initializer := NIL;
		END InitVariable;

		PROCEDURE SetKind*(kind: SIGNED32);
		BEGIN
			SELF.kind := kind;
		END SetKind;

		PROCEDURE Clone*(): Variable;
		VAR new: Variable;
		BEGIN
			NEW(new, position, name);
			Copy(new);
			new.modifiers := modifiers;
			new.untraced := untraced;
			new.preferRegister := preferRegister;
			new.inRegister := inRegister;
			new.initializer := CloneExpression(initializer);
			RETURN new;
		END Clone;

		PROCEDURE UsedAsReference*;
		BEGIN
			usedAsReference := TRUE
		END UsedAsReference;

		PROCEDURE SetUntraced*(u: BOOLEAN);
		BEGIN untraced := u
		END SetUntraced;

		PROCEDURE PreferRegister*(b: BOOLEAN);
		BEGIN
			preferRegister := b
		END PreferRegister;

		PROCEDURE InRegister*(b: BOOLEAN);
		BEGIN
			inRegister := b;
		END InRegister;

		PROCEDURE RegisterNumber*(reg: SIZE);
		BEGIN
			registerNumber := reg
		END RegisterNumber;

		PROCEDURE SetModifiers*(flag: Modifier);
		BEGIN SELF.modifiers := flag;
		END SetModifiers;

		PROCEDURE SetInitializer*(initializer: Expression);
		BEGIN SELF.initializer := initializer;
		END SetInitializer;

		PROCEDURE NeedsTrace* (): BOOLEAN;
		BEGIN RETURN ~untraced & (extern = NIL) & type.NeedsTrace ();
		END NeedsTrace;

	END Variable;

	(** << [VAR | CONST] name: type >>
		Parameter declaration symbol. Represents a parameter in the form [VAR | CONST] name: Type.
		The parameter's type is stored in the symbol's type field and is resolved by the semantic checker.
	**)
	Parameter* = OBJECT (Symbol)
	VAR
		nextParameter-, prevParameter-: Parameter;
		modifiers-: Modifier;
		defaultValue-: Expression;

		kind-: SIGNED32;   (* ValueParameter, ConstParameter, VarParameter *)
		ownerType-: Type;
		untraced-: BOOLEAN;
		movable-: BOOLEAN;
		selfParameter-: BOOLEAN;
		autoConvert-: BOOLEAN; (* for the support of builtin-functions in backends only *)

		registerNumber-: SIZE;
		inRegister-: BOOLEAN;
		preferRegister-: BOOLEAN;

		PROCEDURE & InitParameter( position: Position;  ownerType: Type ; name: Identifier; kind: SIGNED32);
		BEGIN
			InitSymbol( position, name );
			SELF.kind := kind;
			IF kind = ConstParameter THEN access := access END;
			nextParameter := NIL;
			SELF.ownerType := ownerType;
			modifiers := NIL;
			untraced := FALSE;
			defaultValue := NIL;
			movable := FALSE;
			selfParameter := FALSE;
			preferRegister := FALSE;
			inRegister := FALSE;
			registerNumber := -1;
			autoConvert := FALSE;
		END InitParameter;

		PROCEDURE PreferRegister*(b: BOOLEAN);
		BEGIN
			preferRegister := b
		END PreferRegister;

		PROCEDURE InRegister*(b: BOOLEAN);
		BEGIN
			inRegister := b;
		END InRegister;

		PROCEDURE RegisterNumber*(reg: SIZE);
		BEGIN
			registerNumber := reg
		END RegisterNumber;

		PROCEDURE SetAutoConvert*(auto: BOOLEAN);
		BEGIN
			autoConvert := auto;
		END SetAutoConvert;

		PROCEDURE SetModifiers*(flag: Modifier);
		BEGIN SELF.modifiers := flag;
		END SetModifiers;

		PROCEDURE SetUntraced*(untraced: BOOLEAN);
		BEGIN SELF.untraced := untraced
		END SetUntraced;

		PROCEDURE SetMoveable*(movable: BOOLEAN);
		BEGIN SELF.movable := movable
		END SetMoveable;

		PROCEDURE SetSelfParameter*(b: BOOLEAN);
		BEGIN
			selfParameter := b;
		END SetSelfParameter;

		PROCEDURE SetDefaultValue*(e: Expression);
		BEGIN defaultValue := e
		END SetDefaultValue;

		PROCEDURE SetKind*(kind: SIGNED32);
		BEGIN SELF.kind := kind; END SetKind;

		PROCEDURE NeedsTrace* (): BOOLEAN;
		BEGIN RETURN ~untraced  & type.NeedsTrace ();
		END NeedsTrace;

	END Parameter;

	Property* = OBJECT (Variable)
	VAR
		nextProperty-, prevProperty-: Property;
		value-: Expression;

		PROCEDURE & InitProperty(position: Position;  name: Identifier);
		BEGIN
			InitSymbol( position, name );
		END InitProperty;

		PROCEDURE SetValue*(e: Expression);
		BEGIN value := e
		END SetValue;

	END Property;

	Alias* = OBJECT (Symbol)
	VAR
		expression-: Expression;
		nextAlias-: Alias;

		PROCEDURE & InitAlias*(position: Position; name: Identifier; e: Expression);
		BEGIN
			InitSymbol(position, name);
			expression := e;
			nextAlias := NIL;
		END InitAlias;

		PROCEDURE SetExpression*(e: Expression);
		BEGIN
			expression := e;
		END SetExpression;

	END Alias;

	(** Procedure declaration symbol. Represents a procedure being defined in the form PROCEDURE name(parameters): returnType;
		Note that the type of a procedure is a ProcedureType (and not the return type of the procedure).
		Parameters, local variables, constants and type declarations are stored in the procedureScope field.
	**)
	Procedure* = OBJECT (Symbol)
		VAR
			nextProcedure-: Procedure;
			procedureScope- : ProcedureScope;
			super-: Procedure;
			level-: SIGNED32;
			methodNumber-: SIZE;
			isBodyProcedure-, isConstructor-,isFinalizer-,isInline-,isOberonInline-, isOpening-, isClosing-,isFinal-,isTest-, isAbstract-,isOverwritten-,isPlain-: BOOLEAN;
			resolving-: SIGNED32; (* for recursion detection during inlining *)

		PROCEDURE & InitProcedure( position: Position;  name: Identifier; scope: ProcedureScope);
		BEGIN
			InitSymbol(position,name);
			resolving := 0;
			nextProcedure := NIL;
			procedureScope := scope;
			ASSERT(scope.ownerProcedure = NIL); (* cannot register twice ! *)
			scope.ownerProcedure := SELF;
			super := NIL;
			level := 0;
			methodNumber := -1;
			isBodyProcedure := FALSE;
			isConstructor := FALSE;
			isFinalizer := FALSE;
			isInline := FALSE;
			isOberonInline := FALSE;
			isOpening := FALSE;
			isClosing := FALSE;
			isFinal := FALSE;
			isAbstract := FALSE;
			isOverwritten := FALSE;
			isPlain := FALSE;
			isTest := FALSE;
		END InitProcedure;

		(* cycle detection during inlining *)
		PROCEDURE Resolving*(r: BOOLEAN): BOOLEAN;
		VAR b: BOOLEAN;
		BEGIN
			b := resolving > 0;
			IF r THEN INC(resolving) ELSE DEC(resolving) END;
			RETURN b;
		END Resolving;

		PROCEDURE SetSuper*(super: Procedure);
		BEGIN
			SELF.super := super
		END SetSuper;

		PROCEDURE SetBodyProcedure*(isBodyProcedure: BOOLEAN);
		BEGIN SELF.isBodyProcedure := isBodyProcedure;
		END SetBodyProcedure;

		PROCEDURE SetConstructor*(isConstructor: BOOLEAN);
		BEGIN SELF.isConstructor := isConstructor
		END SetConstructor;

		PROCEDURE SetFinalizer*(isFinalizer: BOOLEAN);
		BEGIN SELF.isFinalizer := isFinalizer
		END SetFinalizer;

		PROCEDURE SetInline*(isInline: BOOLEAN);
		BEGIN SELF.isInline := isInline
		END SetInline;

		PROCEDURE SetOberonInline*(isInline: BOOLEAN);
		BEGIN SELF.isOberonInline := isInline
		END SetOberonInline;

		PROCEDURE SetOpening*(opening: BOOLEAN);
		BEGIN SELF.isOpening := opening
		END SetOpening;

		PROCEDURE SetClosing*(closing: BOOLEAN);
		BEGIN SELF.isClosing := closing
		END SetClosing;

		PROCEDURE SetPlain*(plain: BOOLEAN);
		BEGIN SELF.isPlain := plain;
		END SetPlain;

		PROCEDURE SetFinal*(final: BOOLEAN);
		BEGIN SELF.isFinal := final
		END SetFinal;

		PROCEDURE SetTest*(test: BOOLEAN);
		BEGIN isTest := test
		END SetTest;

		PROCEDURE SetOverwritten*(locallyOverwritten: BOOLEAN);
		BEGIN SELF.isOverwritten := locallyOverwritten
		END SetOverwritten;

		PROCEDURE SetAbstract*(abstract: BOOLEAN);
		BEGIN SELF.isAbstract := abstract
		END SetAbstract;

		PROCEDURE SetLevel*(level: SIGNED32);
		BEGIN SELF.level := level
		END SetLevel;

		PROCEDURE SetMethodNumber*(methodNumber: SIZE);
		BEGIN SELF.methodNumber := methodNumber
		END SetMethodNumber;

		PROCEDURE NeedsSection*(): BOOLEAN;
		BEGIN
			RETURN (access * Public # {}) OR (methodNumber >= 0);
		END NeedsSection;

	END Procedure;

	(** Builtin symbol stands for a builtin procedure. Is resolved by the semantic checker. **)
	Builtin* = OBJECT (Symbol)
	VAR
		nextBuiltin-: Builtin;
		id-: SIGNED32;

		PROCEDURE & InitBuiltin(position: Position; name:Identifier; id: SIGNED32);
		BEGIN
			InitSymbol(position,name); SELF.id := id;
		END InitBuiltin;

	END Builtin;

	CustomBuiltin*=OBJECT (Builtin)
	VAR
		subType-: SubType;

		PROCEDURE & InitCustomBuiltin(position: Position; name: Identifier; id: SIGNED32; subType: SubType);
		BEGIN
			InitBuiltin(position,name,id);
			SELF.subType := subType;
		END InitCustomBuiltin;

		(* TODO: check if this is correct *)
		PROCEDURE CompatibleTo*(otherType: Type): BOOLEAN;
		BEGIN RETURN FALSE
		END CompatibleTo;

	END CustomBuiltin;

	Operator* = OBJECT (Procedure)
	VAR
		nextOperator-: Operator;
		isDynamic-: BOOLEAN; (* nopov *)

		PROCEDURE & InitOperator(position: Position; name: Identifier; scope: ProcedureScope);
		BEGIN
			InitProcedure(position,name,scope);
			nextOperator := NIL;
			isDynamic := FALSE
		END InitOperator;

		(* nopov *)
		PROCEDURE SetDynamic*(isDynamic: BOOLEAN);
		BEGIN SELF.isDynamic := isDynamic
		END SetDynamic;

	END Operator;

	Import* = OBJECT (Symbol)
		VAR
			nextImport-: Import;
			module-: Module;
			moduleName-: Identifier;
			context-: Identifier;
			direct-: BOOLEAN; (* direct import *)
			parameters-: ExpressionList;

		PROCEDURE & InitImport( position: Position;  name, moduleName: Identifier; direct: BOOLEAN );
		BEGIN
			InitSymbol(position,name);
			SELF.direct := direct;
			module := NIL;
			context := invalidIdentifier;
			SELF.moduleName := moduleName;
			type := importType;
			parameters := NIL;
		END InitImport;

		PROCEDURE SetType*(type: Type);
		BEGIN
			ASSERT(type = importType);
		END SetType;

		PROCEDURE SetModule*(module: Module);
		BEGIN
			SELF.module := module;
		END SetModule;

		PROCEDURE SetDirect*(d: BOOLEAN);
		BEGIN
			direct := d
		END SetDirect;

		PROCEDURE SetModuleName*(moduleName: Identifier);
		BEGIN SELF.moduleName := moduleName
		END SetModuleName;

		PROCEDURE SetContext*(context: Identifier);
		BEGIN
			SELF.context := context
		END SetContext;

		PROCEDURE SetParameters*(p: ExpressionList);
		BEGIN
			parameters := p;
		END SetParameters;


	END Import;

	StatementSequence* = OBJECT
		VAR
			list: Basic.List;

		PROCEDURE & InitList;
		BEGIN NEW( list,32 );
		END InitList;

		PROCEDURE Length*( ): SIZE;
		BEGIN RETURN list.Length();
		END Length;

		PROCEDURE AddStatement*( statement: Statement);
		BEGIN list.Add( statement );
		END AddStatement;

		PROCEDURE PrependStatement*( statement: Statement);
		BEGIN list.Prepend( statement );
		END PrependStatement;

		PROCEDURE HasStatement*( statement: Statement):BOOLEAN;
		BEGIN RETURN list.Contains(statement);
		END HasStatement;

		PROCEDURE GetStatement*( index: SIZE ): Statement;
		VAR p: ANY;
		BEGIN p := list.Get( index );  RETURN p( Statement );
		END GetStatement;

		PROCEDURE SetStatement*(index: SIZE; statement: Statement);
		BEGIN
			list.Set(index,statement);
		END SetStatement;

		PROCEDURE RemoveStatement*(statement: Statement);
		BEGIN
			list.Remove(statement);
		END RemoveStatement;

		PROCEDURE InsertBefore*(search, new: Statement);
		BEGIN
			list.Insert(list.IndexOf(search), new);
		END InsertBefore;

		PROCEDURE Clone(VAR copy: StatementSequence);
		VAR i: SIZE;
		BEGIN
			IF copy = NIL THEN NEW(copy) END;
			FOR i := 0 TO Length()-1 DO
				copy.AddStatement(CloneStatement(GetStatement(i)))
			END;
		END Clone;

	END StatementSequence;

	(**** statements ****)

	Statement*= OBJECT
	VAR outer-: Statement;
		position-,end-: Position;
		isUnreachable-: BOOLEAN;

		comment-: Comment;

		PROCEDURE & InitStatement*(position: Position; outer: Statement);
		BEGIN
			SELF.position := position;
			end := invalidPosition;
			SELF.outer := outer;
			isUnreachable := FALSE;
			comment := NIL;
		END InitStatement;

		PROCEDURE SetOuter*(o: Statement);
		BEGIN outer := o
		END SetOuter;

		PROCEDURE SetUnreachable*(unreachable: BOOLEAN);
		BEGIN isUnreachable := unreachable
		END SetUnreachable;

		PROCEDURE SetComment*(comment: Comment);
		BEGIN SELF.comment := comment
		END SetComment;

		PROCEDURE Clone(): Statement;
		BEGIN
			HALT(200) (* abstract *)
		END Clone;

		PROCEDURE End*(pos: Position);
		BEGIN
			end := pos;
		END End;
	END Statement;

	DeclarationStatement*= OBJECT(Statement)
	VAR
		variables-: Variables;
		initializers-: ExpressionList;
		type-: Type;

		PROCEDURE & InitDeclarationStatement(position: Position; outer: Statement);
		BEGIN	InitStatement(position,outer); NEW(variables); NEW(initializers);
		END InitDeclarationStatement;

		PROCEDURE SetType*(t: Type);
		BEGIN
			type := t;
		END SetType;

	END DeclarationStatement;

	(** << call(...) >> **)
	ProcedureCallStatement*= OBJECT(Statement)
		VAR ignore-: BOOLEAN;
		VAR call-: Expression;

		PROCEDURE & InitProcedureCallStatement(position: Position; ignore: BOOLEAN; call: Expression; outer: Statement);
		BEGIN	InitStatement(position,outer); SELF.ignore := ignore; SELF.call := call;
		END InitProcedureCallStatement;

		PROCEDURE SetIgnore*(ignore: BOOLEAN);
		BEGIN	SELF.ignore := ignore;
		END SetIgnore;

		PROCEDURE SetCall*(call: Expression);
		BEGIN	SELF.call := call;
		END SetCall;

		PROCEDURE Clone(): Statement;
		VAR copy: ProcedureCallStatement;
		BEGIN
			NEW(copy, position, ignore, CloneExpression(call), outer);
			RETURN copy
		END Clone;

	END ProcedureCallStatement;

	(** << left := right >> **)
	Assignment* = OBJECT (Statement)
	VAR left-: Expression; right-: Expression;

		PROCEDURE & InitAssignment*( position: Position;  left: Expression;  right: Expression; outer: Statement );
		BEGIN
			InitStatement( position,outer );  SELF.left := left;  SELF.right := right;
		END InitAssignment;

		PROCEDURE SetLeft*(left: Designator);
		BEGIN SELF.left := left
		END SetLeft;

		PROCEDURE SetRight*(right: Expression);
		BEGIN SELF.right := right
		END SetRight;

		PROCEDURE Clone(): Statement;
		VAR copy: Assignment;
		BEGIN
			NEW(copy, position, CloneExpression(left), CloneExpression(right), outer);
			RETURN copy
		END Clone;

	END Assignment;

	(** << left ('!' | '?' | '<<' | '>>') right >> **)
	CommunicationStatement* = OBJECT (Statement)
	VAR
		left-: Expression; right-: Expression; op-: SIGNED32;

		PROCEDURE & InitAssignment*( position: Position; op: SIGNED32; left: Expression;  right: Expression; outer: Statement );
		BEGIN
			InitStatement( position,outer );  SELF.op := op; SELF.left := left;  SELF.right := right;
		END InitAssignment;

		PROCEDURE SetLeft*(left: Designator);
		BEGIN SELF.left := left
		END SetLeft;

		PROCEDURE SetRight*(right: Expression);
		BEGIN SELF.right := right
		END SetRight;

	END CommunicationStatement;

	Part*= OBJECT
	VAR
		position-, end-: Position;

		PROCEDURE InitPart;
		BEGIN
			position := invalidPosition; end := invalidPosition;
		END InitPart;

		PROCEDURE SetPosition*(pos: Position);
		BEGIN
			position := pos;
		END SetPosition;

		PROCEDURE SetEnd*(pos: Position);
		BEGIN
			end := pos;
		END SetEnd;

	END Part;

	(** << ... condition THEN statements ... >> **)
	IfPart*= OBJECT (Part)
	VAR
		condition-: Expression;
		statements-: StatementSequence;

		comment-: Comment;

		PROCEDURE & InitIfPart;
		BEGIN
			InitPart;
			statements := NIL; condition := NIL; comment := NIL;
		END InitIfPart;

		PROCEDURE SetCondition*(condition: Expression);
		BEGIN SELF.condition := condition
		END SetCondition;

		PROCEDURE SetStatements*(statements: StatementSequence);
		BEGIN SELF.statements := statements
		END SetStatements;

		PROCEDURE SetComment*(comment: Comment);
		BEGIN SELF.comment := comment
		END SetComment;

		PROCEDURE Clone(): IfPart;
		VAR copy: IfPart;
		BEGIN
			NEW(copy); copy.condition := CloneExpression(condition);
			copy.statements := CloneStatementSequence(statements);
			RETURN copy
		END Clone;

	END IfPart;

	(** << IF ifPart {ELSIF elsifParts} ELSE elseParts >> **)
	IfStatement* = OBJECT (Statement)
		VAR
			ifPart-: IfPart;
			elsifParts: Basic.List;
			elsePart-: StatementSequence;

		PROCEDURE & InitIfStatement( position: Position ; outer: Statement);
		BEGIN
			InitStatement( position,outer ); ifPart := NewIfPart();
			ifPart.SetPosition(position);
			elsePart := NIL;  elsifParts := NIL;
		END InitIfStatement;

		PROCEDURE SetElsePart*( elsePart: StatementSequence );
		BEGIN
			SELF.elsePart := elsePart;
		END SetElsePart;

		PROCEDURE AddElsifPart*( elsifPart: IfPart );
		BEGIN
			IF elsifParts = NIL THEN NEW(elsifParts,4);  END;
			elsifParts.Add( elsifPart );
		END AddElsifPart;

		PROCEDURE GetElsifPart*( i: SIZE ): IfPart;
		VAR a: ANY;
		BEGIN a := elsifParts.Get( i );  RETURN a( IfPart )
		END GetElsifPart;

		PROCEDURE ElsifParts*( ): SIZE;
		BEGIN
			IF elsifParts = NIL THEN RETURN 0 ELSE RETURN elsifParts.Length();  END;
		END ElsifParts;

		PROCEDURE Clone(): Statement;
		VAR copy: IfStatement; i: SIZE;
		BEGIN
			NEW(copy, position, outer);
			copy.ifPart := ifPart.Clone();
			FOR i := 0 TO ElsifParts()-1 DO
				copy.AddElsifPart(GetElsifPart(i).Clone());
			END;
			copy.SetElsePart(CloneStatementSequence(elsePart));
			RETURN copy
		END Clone;

	END IfStatement;

	WithPart*= OBJECT (Part)
	VAR
		type-: Type; (* initially is qualified type *)
		statements-: StatementSequence;

		comment-: Comment;

		PROCEDURE &InitWithPart();
		BEGIN
			InitPart();
			type := NIL; statements := NIL; comment := NIL;
		END InitWithPart;

		PROCEDURE SetType*( type: Type );
		BEGIN
			SELF.type := type
		END SetType;

		PROCEDURE SetStatements*( statements: StatementSequence );
		BEGIN
			SELF.statements := statements;
		END SetStatements;

		PROCEDURE SetComment*(comment: Comment);
		BEGIN SELF.comment := comment
		END SetComment;

		PROCEDURE Clone(): WithPart;
		VAR copy: WithPart;
		BEGIN
			NEW(copy);
			copy.SetType(type);
			copy.SetStatements(CloneStatementSequence(statements));
			RETURN copy
		END Clone;

	END WithPart;

	(** << WITH variable : type DO statements END >> **)
	WithStatement* = OBJECT (Statement)
		VAR
			variable-: Designator;
			withParts-: Basic.List;
			elsePart-: StatementSequence;

		PROCEDURE & InitWithStatement( position: Position; outer: Statement );
		BEGIN
			InitStatement( position,outer );
			NEW(withParts,4); elsePart := NIL;
			variable := NIL;
		END InitWithStatement;

		PROCEDURE SetVariable*( variable: Designator);
		BEGIN
			SELF.variable := variable
		END SetVariable;

		PROCEDURE AddWithPart*( withPart: WithPart );
		BEGIN withParts.Add( withPart );
		END AddWithPart;

		PROCEDURE GetWithPart*( i: SIZE ): WithPart;
		VAR a: ANY;
		BEGIN a := withParts.Get( i );  RETURN a( WithPart )
		END GetWithPart;

		PROCEDURE WithParts*( ): SIZE;
		BEGIN
			IF withParts = NIL THEN RETURN 0 ELSE RETURN withParts.Length();  END;
		END WithParts;

		PROCEDURE SetElsePart*( elsePart: StatementSequence );
		BEGIN
			SELF.elsePart := elsePart;
		END SetElsePart;

		PROCEDURE Clone(): Statement;
		VAR copy: WithStatement; i: SIZE;
		BEGIN
			NEW(copy, position, outer);
			FOR i := 0 TO WithParts()-1 DO
				copy.AddWithPart(GetWithPart(i).Clone());
			END;
			copy.SetVariable(CloneDesignator(variable));
			copy.SetElsePart(CloneStatementSequence(elsePart));
			RETURN copy
		END Clone;

	END WithStatement;

	CaseConstant*= POINTER TO RECORD min*,max*: Basic.Integer; next*: CaseConstant END;

	(** << elements : statements >> **)
	CasePart* = OBJECT (Part)
		VAR
			elements-: ExpressionList; (* expression list inserted by the parser *)
			firstConstant-: CaseConstant; (* expression list resolved to int32s, inserted by checker *)
			statements-: StatementSequence;

			comment-: Comment;

		PROCEDURE & InitCasePart;
		BEGIN
			InitPart;
			elements := NewExpressionList(); firstConstant := NIL;
		END InitCasePart;

		PROCEDURE SetStatements*( statements: StatementSequence );
		BEGIN
			SELF.statements := statements;
		END SetStatements;

		PROCEDURE SetConstants*(firstConstant: CaseConstant);
		BEGIN SELF.firstConstant := firstConstant
		END SetConstants;

		PROCEDURE SetComment*(comment: Comment);
		BEGIN SELF.comment := comment
		END SetComment;

		PROCEDURE Clone(): CasePart;
		VAR copy: CasePart;
		BEGIN
			NEW(copy);
			copy.SetStatements(CloneStatementSequence(statements));
			copy.firstConstant := firstConstant;
			copy.elements := CloneExpressionList(elements);
			RETURN copy
		END Clone;

	END CasePart;

	(** << CASE varaible OF caseParts ELSE elsePart >> **)
	CaseStatement* = OBJECT (Statement)
		VAR
			variable-: Expression;
			elsePart-: StatementSequence;
			caseParts-: Basic.List;
			min-,max-: Basic.Integer;

		PROCEDURE & InitCaseStatement( position: Position ; outer: Statement);
		BEGIN
			InitStatement(position,outer );  variable := NIL;  elsePart := NIL;  caseParts := NIL;
			min := MAX(Basic.Integer); max := MIN(Basic.Integer);
		END InitCaseStatement;

		PROCEDURE SetVariable*( expression: Expression );
		BEGIN SELF.variable := expression;
		END SetVariable;

		PROCEDURE SetElsePart*( elsePart: StatementSequence );
		BEGIN SELF.elsePart := elsePart;
		END SetElsePart;

		PROCEDURE AddCasePart*( casePart: CasePart );
		BEGIN
			IF caseParts = NIL THEN NEW(caseParts,4);  END;
			caseParts.Add( casePart );
		END AddCasePart;

		PROCEDURE GetCasePart*( i: SIZE ): CasePart;
		VAR a: ANY;
		BEGIN a := caseParts.Get( i );  RETURN a( CasePart )
		END GetCasePart;

		PROCEDURE CaseParts*( ): SIZE;
		BEGIN
			IF caseParts = NIL THEN RETURN 0 ELSE RETURN caseParts.Length();  END;
		END CaseParts;

		PROCEDURE Clone(): Statement;
		VAR copy: CaseStatement; i: SIZE;
		BEGIN
			NEW(copy, position, outer);
			copy.SetVariable(CloneExpression(variable));
			copy.SetElsePart(CloneStatementSequence(elsePart));
			FOR i := 0 TO CaseParts()-1 DO
				copy.AddCasePart(GetCasePart(i).Clone());
			END;
			copy.min := min; copy.max := max;
			RETURN copy
		END Clone;

		PROCEDURE MaxConstant*(): Basic.Integer;
		VAR val: Basic.Integer; i: SIZE; part: CasePart; const: CaseConstant;
		BEGIN
			val := -1;
			FOR i := 0 TO CaseParts() - 1 DO
				part := GetCasePart(i);
				const := part.firstConstant;
				WHILE(const # NIL) DO
					IF const.max > val THEN val := const.max; END;
					const := const.next;
				END;
			END;
			RETURN val;
		END MaxConstant;

		PROCEDURE SetMinMax*(min,max: Basic.Integer);
		BEGIN
			SELF.min := min; SELF.max := max;
		END SetMinMax;

	END CaseStatement;

	(** << WHILE condition DO statements END >> **)
	WhileStatement* = OBJECT (Statement)
		VAR
			condition-: Expression;
			statements-: StatementSequence;

		PROCEDURE & InitWhileStatement( position: Position ; outer: Statement);
		BEGIN
			InitStatement( position,outer );  condition := NIL;  statements := NIL;
		END InitWhileStatement;

		PROCEDURE SetCondition*( condition: Expression );
		BEGIN
			SELF.condition := condition
		END SetCondition;

		PROCEDURE SetStatements*( statements: StatementSequence );
		BEGIN
			SELF.statements := statements;
		END SetStatements;

		PROCEDURE Clone(): Statement;
		VAR copy: WhileStatement;
		BEGIN
			NEW(copy, position, outer);
			copy.SetCondition(CloneExpression(condition));
			copy.SetStatements(CloneStatementSequence(statements));
			RETURN copy
		END Clone;

	END WhileStatement;

	(** << REPEAT statements UNTIL condition >> **)
	RepeatStatement* = OBJECT (Statement)
		VAR
			condition-: Expression;
			statements-: StatementSequence;

		PROCEDURE & InitRepeatStatement( position: Position; outer: Statement );
		BEGIN
			InitStatement( position,outer );  condition := NIL;  statements := NIL;
		END InitRepeatStatement;

		PROCEDURE SetCondition*( condition: Expression );
		BEGIN
			SELF.condition := condition
		END SetCondition;

		PROCEDURE SetStatements*( statements: StatementSequence );
		BEGIN
			SELF.statements := statements;
		END SetStatements;

		PROCEDURE Clone(): Statement;
		VAR copy: RepeatStatement;
		BEGIN
			NEW(copy, position, outer);
			copy.SetCondition(CloneExpression(condition));
			copy.SetStatements(CloneStatementSequence(statements));
			RETURN copy
		END Clone;

	END RepeatStatement;

	(** << FOR variable := from TO to BY by DO statements END >> **)
	ForStatement* = OBJECT (Statement)
		VAR
			variable-: Designator;
			from-, to-, by-: Expression;
			statements-: StatementSequence;

		PROCEDURE & InitForStatement( position: Position; outer: Statement );
		BEGIN
			InitStatement( position,outer );  variable := NIL;from := NIL;  to := NIL;  by := NIL; statements := NIL;
		END InitForStatement;

		PROCEDURE SetVariable*( variable: Designator);
		BEGIN
			SELF.variable := variable
		END SetVariable;

		PROCEDURE SetFrom*( from: Expression );
		BEGIN
			SELF.from := from
		END SetFrom;

		PROCEDURE SetTo*( to: Expression );
		BEGIN
			SELF.to := to
		END SetTo;

		PROCEDURE SetBy*( by: Expression );
		BEGIN SELF.by := by
		END SetBy;

		PROCEDURE SetStatements*( statements: StatementSequence );
		BEGIN SELF.statements := statements;
		END SetStatements;

		PROCEDURE Clone(): Statement;
		VAR copy: ForStatement;
		BEGIN
			NEW(copy, position, outer);
			copy.SetVariable(CloneDesignator(variable));
			copy.SetFrom(CloneExpression(from));
			copy.SetTo(CloneExpression(to));
			copy.SetBy(CloneExpression(by));
			copy.SetStatements(CloneStatementSequence(statements));
			RETURN copy
		END Clone;

	END ForStatement;

	ExitableBlock*= OBJECT (Statement)
	VAR statements-: StatementSequence;

		PROCEDURE & InitExitableBlock( position: Position ; outer: Statement);
		BEGIN
			InitStatement( position ,outer);  statements := NIL;
		END InitExitableBlock;

		PROCEDURE SetStatements*( statements: StatementSequence );
		BEGIN SELF.statements := statements;
		END SetStatements;

		PROCEDURE Clone(): Statement;
		VAR copy: ExitableBlock;
		BEGIN
			NEW(copy, position, outer);
			copy.SetStatements(CloneStatementSequence(statements));
			RETURN copy
		END Clone;

	END ExitableBlock;

	(** << LOOP statements END >> **)
	LoopStatement* = OBJECT (ExitableBlock)

		PROCEDURE Clone(): Statement;
		VAR copy: LoopStatement;
		BEGIN
			NEW(copy, position, outer);
			copy.SetStatements(CloneStatementSequence(statements));
			RETURN copy
		END Clone;

	END LoopStatement;

	(** << EXIT >> **)
	ExitStatement* = OBJECT (Statement)

		PROCEDURE Clone(): Statement;
		VAR copy: ExitStatement;
		BEGIN
			NEW(copy, position, outer);
			RETURN copy
		END Clone;

	END ExitStatement;

	(** << RETURN returnValue >> **)
	ReturnStatement* = OBJECT (Statement)
		VAR returnValue-: Expression; (* strictly speaking this is not a value but this term is in common use here *)

		PROCEDURE & InitReturnStatement( position: Position ; outer: Statement);
		BEGIN
			InitStatement( position,outer );  returnValue := NIL
		END InitReturnStatement;

		PROCEDURE SetReturnValue*( returnValue: Expression );
		BEGIN SELF.returnValue := returnValue
		END SetReturnValue;

		PROCEDURE Clone(): Statement;
		VAR copy: ReturnStatement;
		BEGIN
			NEW(copy, position, outer);
			copy.SetReturnValue(CloneExpression(returnValue));
			RETURN copy
		END Clone;

	END ReturnStatement;

	(** << AWAIT condition >> **)
	AwaitStatement* = OBJECT (Statement)
		VAR
			condition-: Expression;
			procedure-: Procedure;

		PROCEDURE & InitAwaitStatement( position: Position; outer: Statement );
		BEGIN
			InitStatement( position,outer );  condition := NIL; procedure := NIL;
		END InitAwaitStatement;

		PROCEDURE SetCondition*( condition: Expression );
		BEGIN SELF.condition := condition
		END SetCondition;

		PROCEDURE SetProcedure*(p: Procedure);
		BEGIN procedure := p;
		END SetProcedure;


		PROCEDURE Clone(): Statement;
		VAR copy: AwaitStatement;
		BEGIN
			NEW(copy, position, outer);
			copy.SetCondition(CloneExpression(condition));
			RETURN copy
		END Clone;

	END AwaitStatement;

	(* << Identifier ( Expression) >> *)
	Modifier*= OBJECT
	VAR
		identifier-: Identifier; expression-: Expression;
		resolved-: BOOLEAN;
		nextModifier-: Modifier;
		position-: Position;

		PROCEDURE & InitModifier(position: Position; identifier: Identifier; expression: Expression);
		BEGIN
			SELF.position := position;
			SELF.identifier := identifier; SELF.expression := expression; nextModifier := NIL; resolved := FALSE;
		END InitModifier;

		PROCEDURE Resolved*;
		BEGIN resolved := TRUE
		END Resolved;

		PROCEDURE SetExpression*(e: Expression);
		BEGIN SELF.expression := e
		END SetExpression;

		PROCEDURE SetNext*(modifier: Modifier);
		BEGIN	nextModifier := modifier
		END SetNext;

	END Modifier;

	(** << BEGIN {Modifier, Modifier ... }  statements END >> **)
	StatementBlock* = OBJECT (Statement)
		VAR
			statements-: StatementSequence;
			blockModifiers-: Modifier;
			isExclusive-: BOOLEAN;
			isRealtime-: BOOLEAN;
			isUnchecked-: BOOLEAN;
			isUntracked-: BOOLEAN;
			isUncooperative-: BOOLEAN;
			scope-: Scope;

		PROCEDURE & InitStatementBlock( position: Position ; outer: Statement; s: Scope);
		BEGIN
			InitStatement( position ,outer);  statements := NIL;  blockModifiers := NIL;
			isExclusive := FALSE;
			isRealtime := FALSE;
			isUnchecked := FALSE;
			isUntracked := FALSE;
			isUncooperative := FALSE;
			scope := s;
		END InitStatementBlock;

		PROCEDURE SetRealtime*(b: BOOLEAN);
		BEGIN
			isRealtime := b
		END SetRealtime;

		PROCEDURE SetUnchecked*(unchecked: BOOLEAN);
		BEGIN
			isUnchecked := unchecked
		END SetUnchecked;

		PROCEDURE SetUntracked*(untracked: BOOLEAN);
		BEGIN
			isUntracked := untracked
		END SetUntracked;

		PROCEDURE SetUncooperative*(uncooperative: BOOLEAN);
		BEGIN
			isUncooperative := uncooperative
		END SetUncooperative;

		PROCEDURE SetModifier*(modifier: Modifier);
		BEGIN
			blockModifiers := modifier;
		END SetModifier;

		PROCEDURE SetExclusive*(excl: BOOLEAN);
		BEGIN isExclusive := excl
		END SetExclusive;

		PROCEDURE SetStatementSequence*( statements: StatementSequence );
		BEGIN SELF.statements := statements;
		END SetStatementSequence;

		PROCEDURE Clone(): Statement;
		VAR copy: StatementBlock;
		BEGIN
			NEW(copy, position, outer, scope);
			copy^ := SELF^;
			copy.SetStatementSequence(CloneStatementSequence(statements));
			RETURN copy;
		END Clone;

	END StatementBlock;

	(** << CODE {flags} {character}  END >> **)
	Code*= OBJECT(Statement)
	VAR
		sourceCode-: SourceCode; sourceCodeLength-: SIZE;
		inlineCode-: BinaryCode;

		PROCEDURE & InitCode(position: Position; outer: Statement);
		BEGIN
			InitStatement(position,outer);
			inlineCode := NIL;
			sourceCode := NIL; sourceCodeLength := 0;
		END InitCode;

		PROCEDURE SetSourceCode*(source: SourceCode; length: SIZE);
		BEGIN sourceCode := source; sourceCodeLength := length;
			ASSERT(sourceCodeLength <= LEN(source));
		END SetSourceCode;

		PROCEDURE SetBinaryCode*(code: BinaryCode);
		BEGIN
			inlineCode := code;
		END SetBinaryCode;

		PROCEDURE Clone(): Statement;
		VAR copy: Code; s: Scanner.StringType;
		BEGIN
			NEW(copy, position, outer);
			NEW(s, sourceCodeLength);
			Strings.Copy(sourceCode^,0,sourceCodeLength,s^);
			copy.SetSourceCode(s, sourceCodeLength);
			RETURN copy
		END Clone;

	END Code;

	(** << BEGIN {flags} statements FINALLY statements END >> **)
	Body*= OBJECT(StatementBlock)
	VAR
		finally-: StatementSequence;
		priority-: Expression; (* set by checker *)
		inScope-: ProcedureScope;
		code-: Code;
		isActive-, isSafe-: BOOLEAN;

		PROCEDURE & InitBody(position: Position; scope: ProcedureScope);
		BEGIN
			InitStatementBlock(position,NIL,NIL); finally := NIL; priority := NIL; inScope := scope; code := NIL;
			isActive := FALSE; isSafe := FALSE; isRealtime := FALSE;
		END InitBody;

		PROCEDURE SetActive*(active: BOOLEAN);
		BEGIN SELF.isActive := active
		END SetActive;

		PROCEDURE SetSafe*(safe: BOOLEAN);
		BEGIN SELF.isSafe := safe
		END SetSafe;

		PROCEDURE SetFinally*( finally: StatementSequence );
		BEGIN SELF.finally := finally
		END SetFinally;

		PROCEDURE SetPriority*(expression: Expression);
		BEGIN priority := expression
		END SetPriority;

		PROCEDURE SetCode*(code: Code);
		BEGIN SELF.code := code;
		END SetCode;

	END Body;

	(** (* comment *)  *)
	Comment*=OBJECT
	VAR position-: Position;
		source-: String; (* currently: POINTER TO ARRAY OF CHAR *)
		scope-: Scope;
		item-: ANY; sameLine-: BOOLEAN;
		nextComment-: Comment;

		PROCEDURE & InitComment(pos: Position; scope: Scope; CONST s: ARRAY OF CHAR; length: SIZE);
		VAR i: SIZE;
		BEGIN
			SELF.scope := scope;
			NEW(source,length);
			FOR i := 0 TO length-1 DO
				source[i] := s[i];
			END;
			SELF.position := pos;
			nextComment := NIL;
			item := NIL; sameLine := FALSE;
		END InitComment;

		PROCEDURE SetItem*(p: ANY; sameLine: BOOLEAN);
		BEGIN
			item := p; SELF.sameLine := sameLine
		END SetItem;

	END Comment;

	(**** building blocks ****)

	Scope*=OBJECT
		VAR
		firstSymbol-: Symbol; numberSymbols-: SIZE; (* all symbols in scope (sorted) *)
		symbolTable: Basic.HashTableInt;

		firstConstant-,lastConstant-: Constant;  numberConstants-: SIZE; (* constants *)
		firstTypeDeclaration-,lastTypeDeclaration-: TypeDeclaration; numberTypeDeclarations-: SIZE; (* type declarations *)
		firstVariable-,lastVariable-: Variable; numberVariables-: SIZE;  (* variables *)
		firstProcedure-,lastProcedure-: Procedure; numberProcedures-: SIZE;  (* procedures *)
		firstAlias-, lastAlias-: Alias; numberAliases-: SIGNED32; (* aliases *)
		firstScope-,lastScope-: Scope; numberScopes-: SIGNED32; (* scopes *)

		procedures-: ProcedureList;

		outerScope-: Scope; nextScope-: Scope;

		ownerModule-: Module;

		currentVariableOffset-, minVariableOffset-, maxVariableOffset-: SIZE;

		PROCEDURE & InitScope(outer: Scope);
		BEGIN
			currentVariableOffset := 0; minVariableOffset := 0; maxVariableOffset := 0;
			firstSymbol := NIL; numberSymbols := 0;
			firstConstant := NIL; lastConstant := NIL; numberConstants := 0;
			firstTypeDeclaration := NIL; lastTypeDeclaration := NIL; numberTypeDeclarations := 0;
			firstVariable := NIL; lastVariable := NIL; numberVariables := 0;
			firstProcedure := NIL; lastProcedure := NIL; numberProcedures := 0;
			outerScope := outer;
			firstScope:= NIL; lastScope := NIL; numberScopes := 0;
			IF outer # NIL THEN
				ownerModule := outer.ownerModule
			ELSE
				ownerModule := NIL;
			END;
			nextScope := NIL;
			NEW(symbolTable,11);
		END InitScope;

		PROCEDURE SetMinVariableOffset*(o: SIZE);
		BEGIN
			minVariableOffset := o;
		END SetMinVariableOffset;

		PROCEDURE SetCurrentVariableOffset*(o: SIZE);
		BEGIN
			currentVariableOffset := o;
		END SetCurrentVariableOffset;


		PROCEDURE Clear*;
		BEGIN
			firstConstant := NIL; lastConstant := NIL; numberConstants := 0;
			firstTypeDeclaration := NIL; lastTypeDeclaration := NIL; numberTypeDeclarations := 0;
			firstVariable := NIL; lastVariable := NIL; numberVariables := 0;
			firstProcedure := NIL; lastProcedure := NIL; numberProcedures := 0;
		END Clear;

		(** Enter a symbol in the scope, aplhabetically sorted, duplicate = TRUE if multiply identifier *)
		PROCEDURE EnterSymbol*(symbol: Symbol; VAR duplicate: BOOLEAN);
		VAR p,q: Symbol;
		BEGIN
			ASSERT(symbol.nextSymbol = NIL,101); (* symbol may only be present in one scope at a time ! *)
			ASSERT(symbol.scope = NIL,102);
			ASSERT(symbol.name # invalidIdentifier,103);

			p := firstSymbol; q := NIL;
			WHILE (p # NIL) & (StringPool.CompareString(p.name,symbol.name)<0) DO q := p; p := p.nextSymbol END;
			IF (p#NIL) & (symbol.name = p.name) THEN
				duplicate := TRUE;
			ELSE
				duplicate := FALSE
			END;
			symbol.nextSymbol := p;
			IF q = NIL THEN firstSymbol := symbol ELSE q.nextSymbol := symbol END;
			symbol.SetScope(SELF);
			symbolTable.Put(symbol.name,symbol);

			INC(numberSymbols);
		END EnterSymbol;

		(** Find symbol by name *)
		PROCEDURE FindSymbol*(identifier: Identifier): Symbol;
		VAR p: Symbol; a: ANY;
		BEGIN
			IF identifier # invalidIdentifier THEN
				a := symbolTable.Get(identifier);
				IF (a # NIL) & ~(a IS Operator) THEN
					p := a(Symbol);
				END;
				(*
				p := firstSymbol;
				WHILE(p#NIL) & ((p.name # identifier) OR (p IS Operator)) DO p := p.nextSymbol END;
				*)
			END;
			RETURN p;
		END FindSymbol;

		PROCEDURE AddConstant*(c: Constant);
		BEGIN
			ASSERT(c # NIL);
			IF lastConstant= NIL THEN firstConstant := c ELSE lastConstant.nextConstant := c END;
			lastConstant := c;
			INC(numberConstants);
		END AddConstant;

		PROCEDURE FindConstant*(identifier: Identifier): Constant;
		VAR p: Constant;
		BEGIN
			p := firstConstant;
			WHILE(p#NIL) & (p.name # identifier) DO p := p.nextConstant END;
			RETURN p;
		END FindConstant;

		PROCEDURE AddTypeDeclaration*(t: TypeDeclaration);
		BEGIN
			ASSERT(t # NIL);
			IF lastTypeDeclaration= NIL THEN firstTypeDeclaration := t ELSE lastTypeDeclaration.nextTypeDeclaration := t END;
			INC(numberTypeDeclarations);
			lastTypeDeclaration := t;
		END AddTypeDeclaration;

		PROCEDURE FindTypeDeclaration*(identifier: Identifier): TypeDeclaration;
		VAR p: TypeDeclaration;
		BEGIN
			p := firstTypeDeclaration;
			WHILE(p#NIL) & (p.name # identifier) DO p := p.nextTypeDeclaration END;
			RETURN p;
		END FindTypeDeclaration;

		PROCEDURE AddVariable*(v: Variable);
		BEGIN
			ASSERT(v # NIL);
			IF lastVariable= NIL THEN firstVariable := v ELSE lastVariable.nextVariable := v END;
			INC(numberVariables);
			lastVariable := v;
		END AddVariable;

		PROCEDURE AddAlias*(a: Alias);
		BEGIN
			ASSERT(a # NIL);
			IF lastAlias = NIL THEN firstAlias := a; ELSE lastAlias.nextAlias := a END;
			INC(numberAliases);
			lastAlias := a;
		END AddAlias;


		PROCEDURE PushVariable*(v: Variable);
		BEGIN
			ASSERT(v # NIL);
			IF lastVariable= NIL THEN lastVariable := v ELSE v.nextVariable := firstVariable END;
			INC(numberVariables);
			firstVariable := v;
		END PushVariable;

		(* insert variable after variable in list -- can be important to keep variable offsets in order *)
		(* pre: v # NIL, after # NIL *)
		PROCEDURE InsertVariable*(v: Variable; after: Variable);
		BEGIN
			ASSERT(v # NIL);
			ASSERT(after # NIL);
			v.nextVariable := after.nextVariable;
			after.nextVariable := v;
			IF after = lastVariable THEN lastVariable := v END;
		END InsertVariable;

		PROCEDURE FindVariable*(identifier: Identifier): Variable;
		VAR p: Variable;
		BEGIN
			p := firstVariable;
			WHILE(p#NIL) & (p.name # identifier) DO p := p.nextVariable END;
			RETURN p;
		END FindVariable;

		PROCEDURE AddProcedure*(p: Procedure);
		BEGIN
			ASSERT(p # NIL);
			IF lastProcedure= NIL THEN firstProcedure := p ELSE lastProcedure.nextProcedure := p END;
			INC(numberProcedures);
			lastProcedure := p;
		END AddProcedure;

		PROCEDURE AddProcedureDeclaration*(p: Procedure);
		BEGIN
			IF procedures = NIL THEN NEW(procedures) END;
			procedures.AddProcedure(p);
		END AddProcedureDeclaration;

		PROCEDURE FindProcedure*(identifier: Identifier): Procedure;
		VAR p: Procedure;
		BEGIN
			p := firstProcedure;
			WHILE (p#NIL) & ((p.name # identifier) OR (p IS Operator)) DO p := p.nextProcedure END;
			RETURN p;
		END FindProcedure;

		PROCEDURE FindMethod*(number: SIZE): Procedure;
		VAR p: Procedure;
		BEGIN
			p := firstProcedure;
			WHILE (p# NIL) & (p.methodNumber # number) DO
				p := p.nextProcedure
			END;
			RETURN p;
		END FindMethod;

		PROCEDURE Level*(): SIGNED32;
		VAR scope: Scope; level: SIGNED32;
		BEGIN
			level := 0;
			scope := SELF;
			WHILE(scope.outerScope # NIL) DO
				scope := scope.outerScope;
				INC(level);
			END;
			RETURN level;
		END Level;

		PROCEDURE NeedsTrace* (): BOOLEAN;
		VAR variable: Variable;
		BEGIN
			variable := firstVariable;
			WHILE variable # NIL DO
				IF variable.NeedsTrace () THEN RETURN TRUE END;
				variable := variable.nextVariable;
			END;
			RETURN FALSE;
		END NeedsTrace;

		PROCEDURE SetOuter*(outer: Scope);
		BEGIN
			outerScope := outer;
		END SetOuter;

		PROCEDURE AddScope*(c: Scope);
		BEGIN
			IF lastScope= NIL THEN firstScope := c ELSE lastScope.nextScope := c END;
			lastScope := c;
			INC(numberScopes);
		END AddScope;


	END Scope;

	ProcedureScope*=OBJECT (Scope)
		VAR
		ownerProcedure-: Procedure;
		body-: Body;

		PROCEDURE & InitProcedureScope(outer: Scope);
		BEGIN
			InitScope(outer);
			ownerProcedure := NIL;
			body := NIL;
		END InitProcedureScope;

		PROCEDURE SetBody*(body: Body);
		BEGIN
			SELF.body := body;
		END SetBody;

		PROCEDURE NeedsTrace* (): BOOLEAN;
		VAR parameter: Parameter;
		BEGIN
			parameter := ownerProcedure.type.resolved(ProcedureType).firstParameter;
			WHILE parameter # NIL DO
				IF parameter.NeedsTrace () THEN RETURN TRUE END;
				parameter := parameter.nextParameter;
			END;
			RETURN NeedsTrace^();
		END NeedsTrace;

	END ProcedureScope;

	BlockScope* = OBJECT(Scope)
	END BlockScope;

	EnumerationScope*= OBJECT(Scope)
	VAR
		ownerEnumeration-: EnumerationType;

		(** Find symbol by name *)
		PROCEDURE FindSymbol*(identifier: Identifier): Symbol;
		VAR p: Symbol; base: Type;
		BEGIN
			p := FindSymbol^(identifier);
			IF p = NIL THEN
				base := ownerEnumeration.enumerationBase;
				IF (base # NIL) & (base.resolved IS EnumerationType) THEN
					p := base.resolved(EnumerationType).enumerationScope.FindSymbol(identifier)
				END;
			END;
			RETURN p;
		END FindSymbol;

		PROCEDURE &InitEnumerationScope(outer: Scope);
		BEGIN
			InitScope(outer);
			ownerEnumeration := NIL; (* must be set by EnumerationType *)
		END InitEnumerationScope;

	END EnumerationScope;

	RecordScope*= OBJECT(Scope)
		VAR
			ownerRecord-: RecordType;
			bodyProcedure-: Procedure;
			constructor-: Procedure;
			finalizer-: Procedure;
			numberMethods-: SIZE;
			firstParameter-,lastParameter-: Parameter; numberParameters-: SIZE;  (* parameters for Active Cells programming*)
			firstOperator-, lastOperator-: Operator; numberOperators: SIZE; (* defined operators *)

		PROCEDURE & InitRecordScope(outer: Scope);
		BEGIN
			InitScope(outer);
			ownerRecord := NIL;
			numberMethods := 0;
			bodyProcedure := NIL;
			constructor := NIL;
			finalizer := NIL;
			firstOperator := NIL; lastOperator := NIL; numberOperators := 0;
		END InitRecordScope;

		PROCEDURE SetBodyProcedure*(body: Procedure);
		BEGIN SELF.bodyProcedure := body;
		END SetBodyProcedure;

		PROCEDURE SetConstructor*(body: Procedure);
		BEGIN SELF.constructor := body
		END SetConstructor;

		PROCEDURE SetFinalizer*(body: Procedure);
		BEGIN SELF.finalizer := body
		END SetFinalizer;

		PROCEDURE SetNumberMethods*(numberMethods: SIZE);
		BEGIN SELF.numberMethods := numberMethods;
		END SetNumberMethods;

		PROCEDURE AddOperator*(p: Operator);
		BEGIN
			ASSERT(p # NIL);
			IF lastOperator= NIL THEN firstOperator := p ELSE lastOperator.nextOperator := p END;
			INC(numberOperators);
			lastOperator := p;
		END AddOperator;

		(** Find symbol by name *)
		PROCEDURE FindSymbol*(identifier: Identifier): Symbol;
		VAR p: Symbol; base: RecordType;
		BEGIN
			p := FindSymbol^(identifier);
			IF p = NIL THEN
				base := ownerRecord.GetBaseRecord();
				IF (base # NIL) THEN
					p := base.recordScope.FindSymbol(identifier)
				END;
			END;
			RETURN p;
		END FindSymbol;

		(* if there is an abstract procedure in the scope, return it. Otherwise return nil *)
		PROCEDURE AbstractProcedure*(inScope: Scope): Procedure;
		VAR p: Procedure; s: Symbol; base: RecordType;
		BEGIN
			p := firstProcedure;
			WHILE p # NIL DO
				IF p.isAbstract THEN
					IF inScope # SELF THEN  (* elevate to mother scope, if necesary *)
						s := inScope.FindSymbol(p.name);
						IF s = p THEN (* procedure is not overwritten *)
							RETURN p
						ELSE
							ASSERT(s # NIL);
							ASSERT(s IS Procedure);
						END;
					ELSE
						RETURN p
					END;
				END;
				p := p.nextProcedure;
			END;
			base := ownerRecord.GetBaseRecord();
			IF (base # NIL) THEN
				RETURN base.recordScope.AbstractProcedure(inScope);
			END;
			RETURN NIL;
		END AbstractProcedure;

		PROCEDURE FindConstant*(identifier: Identifier): Constant;
		VAR p: Constant; base: RecordType;
		BEGIN
			p := FindConstant^(identifier);
			IF p = NIL THEN
				base := ownerRecord.GetBaseRecord();
				IF (base # NIL) THEN
					p := base.recordScope.FindConstant(identifier)
				END;
			END;
			RETURN p;
		END FindConstant;

		PROCEDURE FindTypeDeclaration*(identifier: Identifier): TypeDeclaration;
		VAR p: TypeDeclaration; base: RecordType;
		BEGIN
			p := FindTypeDeclaration^(identifier);
			IF p = NIL THEN
				base := ownerRecord.GetBaseRecord();
				IF (base # NIL) THEN
					p := base.recordScope.FindTypeDeclaration(identifier)
				END;
			END;
			RETURN p;
		END FindTypeDeclaration;

		PROCEDURE FindVariable*(identifier: Identifier): Variable;
		VAR p: Variable; base: RecordType;
		BEGIN
			p := FindVariable^(identifier);
			IF p = NIL THEN
				base := ownerRecord.GetBaseRecord();
				IF (base # NIL) THEN
					p := base.recordScope.FindVariable(identifier)
				END;
			END;
			RETURN p;
		END FindVariable;

		PROCEDURE FindProcedure*(identifier: Identifier): Procedure;
		VAR p: Procedure; base: RecordType;
		BEGIN
			p := FindProcedure^(identifier);
			IF p = NIL THEN
				base := ownerRecord.GetBaseRecord();
				IF (base # NIL) THEN
					p := base.recordScope.FindProcedure(identifier)
				END;
			END;
			RETURN p;
		END FindProcedure;

		PROCEDURE FindMethod*(number: SIZE): Procedure;
		VAR p: Procedure; base: RecordType;
		BEGIN
			p := FindMethod^(number);
			IF p = NIL THEN
				base := ownerRecord.GetBaseRecord();
				IF (base # NIL) THEN
					p := base.recordScope.FindMethod(number)
				END;
			END;
			RETURN p;
		END FindMethod;

		PROCEDURE NeedsTrace* (): BOOLEAN;
		VAR base: RecordType;
		BEGIN
			base := ownerRecord.GetBaseRecord();
			IF (base # NIL) & (base.NeedsTrace ()) THEN RETURN TRUE END;
			RETURN NeedsTrace^();
		END NeedsTrace;

	END RecordScope;

	CellScope*=OBJECT (Scope)
		VAR
		ownerCell-: CellType;
		bodyProcedure-: Procedure;
		constructor-: Procedure;
		firstImport-,lastImport-: Import; numberImports: SIZE; (* imported modules *)

		PROCEDURE & InitCellScope(outer: Scope);
		BEGIN
			InitScope(outer);
			ownerCell := NIL;
			bodyProcedure := NIL;
			constructor := NIL;
			firstImport := NIL; lastImport := NIL; numberImports := 0;
		END InitCellScope;

		PROCEDURE Clear*;
		BEGIN
			Clear^;
			firstImport := NIL; lastImport := NIL; numberImports := 0;
			constructor := NIL;
			bodyProcedure := NIL;
		END Clear;

		PROCEDURE SetOwnerCell*(owner: CellType);
		BEGIN
			ownerCell := owner
		END SetOwnerCell;

		PROCEDURE SetBodyProcedure*(bodyProcedure: Procedure);
		BEGIN
			SELF.bodyProcedure := bodyProcedure;
		END SetBodyProcedure;

		PROCEDURE SetConstructor*(p: Procedure);
		BEGIN constructor := p
		END SetConstructor;

		PROCEDURE AddImport*(i: Import);
		BEGIN
			ASSERT(i # NIL);
			ASSERT(i.nextImport = NIL);
			IF lastImport= NIL THEN firstImport:= i ELSE lastImport.nextImport := i END;
			lastImport := i;
			INC(numberImports);
		END AddImport;

		PROCEDURE FindImport*(identifier: Identifier): Import;
		VAR p: Import;
		BEGIN
			p := firstImport;
			WHILE(p#NIL) & (p.name # identifier) DO p := p.nextImport END; (* finds imports and re-imports! *)
			RETURN p;
		END FindImport;

		PROCEDURE GetImport*( index: SIGNED32 ): Import;
		VAR import: Import;
		BEGIN
			import := firstImport;
			WHILE(import # NIL) & (index > 0) DO
				import := import.nextImport;
				DEC(index);
			END;
			RETURN import;
		END GetImport;

		PROCEDURE FindSymbol*(identifier: Identifier): Symbol;
		VAR p: Symbol; base: Type;
		BEGIN
			p := FindSymbol^(identifier);
			IF p = NIL THEN
				IF ownerCell.isCellNet THEN
					RETURN ownerCell.FindProperty(identifier);
				END;
			END;
			IF p = NIL THEN
				base := ownerCell.baseType;
				IF (base # NIL) THEN
					base := base.resolved;
					IF base IS PointerType THEN
						base := base(PointerType).pointerBase.resolved;
					END;
					WITH base:
					CellType DO
						p := base.cellScope.FindSymbol(identifier)
					|RecordType DO
						p := base.recordScope.FindSymbol(identifier)

					END;
				END;
			END;

			RETURN p;
		END FindSymbol;

	END CellScope;

	(**
		<<
		IMPORT firstImport .. lastImport;
		...
		firstOperator ... lastOperator
		....
		>>
	**)

	ModuleScope*= OBJECT(Scope)
		VAR
		firstImport-,lastImport-: Import; numberImports: SIZE; (* imported modules *)
		firstOperator-,lastOperator-: Operator; numberOperators: SIZE; (* defined operators *)
		firstBuiltin-,lastBuiltin-: Builtin; numberBuiltins: SIZE; (* defined builtins, only for global and system module *)

		firstComment-,lastComment-: Comment; numberComments-: SIZE; (* comments *)
		bodyProcedure-: Procedure;

		PROCEDURE & InitModuleScope;
		BEGIN
			InitScope(NIL);
			firstComment := NIL; lastComment := NIL; numberComments := 0;
			firstImport:= NIL; lastImport := NIL; numberImports := 0;
			firstOperator := NIL; lastOperator := NIL; numberOperators := 0;
		END InitModuleScope;

		PROCEDURE SetBodyProcedure*(body: Procedure);
		BEGIN SELF.bodyProcedure := body;
		END SetBodyProcedure;

		PROCEDURE SetGlobalScope*(outer: Scope);
		BEGIN
			SELF.outerScope := outer;
		END SetGlobalScope;

		PROCEDURE AddBuiltin*(p: Builtin);
		BEGIN
			ASSERT(p # NIL);
			IF lastBuiltin= NIL THEN firstBuiltin := p ELSE lastBuiltin.nextBuiltin := p END;
			INC(numberBuiltins);
			lastBuiltin := p;
		END AddBuiltin;

		PROCEDURE AddOperator*(p: Operator);
		BEGIN
			ASSERT(p # NIL);
			IF lastOperator= NIL THEN firstOperator := p ELSE lastOperator.nextOperator := p END;
			INC(numberOperators);
			lastOperator := p;
		END AddOperator;

		PROCEDURE FindOperator*(identifier: Identifier): Operator;
		VAR p: Operator;
		BEGIN
			p := firstOperator;
			WHILE(p#NIL) & (p.name # identifier) DO p := p.nextOperator END;
			RETURN p;
		END FindOperator;

		PROCEDURE AddImport*(i: Import);
		BEGIN
			ASSERT(i # NIL);
			ASSERT(i.nextImport = NIL);
			IF lastImport= NIL THEN firstImport:= i ELSE lastImport.nextImport := i END;
			lastImport := i;
			INC(numberImports);
		END AddImport;

		PROCEDURE FindImport*(identifier: Identifier): Import;
		VAR p: Import;
		BEGIN
			p := firstImport;
			WHILE(p#NIL) & (p.name # identifier) DO p := p.nextImport END; (* finds imports and re-imports! *)
			RETURN p;
		END FindImport;

		PROCEDURE GetImport*( index: SIGNED32 ): Import;
		VAR import: Import;
		BEGIN
			import := firstImport;
			WHILE(import # NIL) & (index > 0) DO
				import := import.nextImport;
				DEC(index);
			END;
			RETURN import;
		END GetImport;

		PROCEDURE AddComment*(comment: Comment);
		BEGIN
			ASSERT(comment # NIL);
			IF lastComment= NIL THEN firstComment := comment ELSE lastComment.nextComment := comment END;
			INC(numberComments);
			lastComment := comment;
		END AddComment;

		PROCEDURE ImportByModuleName*(moduleName,context: Identifier): Import;
		VAR p: Import;
		BEGIN
			p := firstImport;
			WHILE(p#NIL) & ~((moduleName = p.moduleName) & (context = p.context)) DO p := p.nextImport END;
			RETURN p;
		END ImportByModuleName;

		PROCEDURE RemoveImporters*(moduleName,context: Identifier);
		VAR this: Import;

			PROCEDURE Check(p: Import): BOOLEAN;
			VAR result: BOOLEAN;
			BEGIN
				IF (moduleName = p.moduleName) & (context = p.context) THEN
					result := TRUE
				ELSE
					result := p.module.moduleScope.ImportByModuleName(moduleName,context) # NIL;
				END;
				RETURN result
			END Check;

		BEGIN
			WHILE(firstImport # NIL) & Check(firstImport) DO
				firstImport := firstImport.nextImport;
				DEC(numberImports);
			END;
			IF firstImport = NIL THEN lastImport := NIL
			ELSE
				this :=firstImport;
				WHILE(this.nextImport # NIL) DO
					IF Check(this.nextImport) THEN
						this.nextImport := this.nextImport.nextImport;
						DEC(numberImports);
					ELSE
						this := this.nextImport
					END;
				END;
				lastImport := this;
			END;
		END RemoveImporters;

	END ModuleScope;

	TemplateType*= ENUM
		Type*, Const*
	END;

	TemplateParameter*= RECORD
		type*: TemplateType;
		identifier*: Identifier;
	END;

	(** <<expression, expression, ...>> **)
	TemplateParameters* = OBJECT
	TYPE
		TemplateParameterArray = POINTER TO ARRAY OF TemplateParameter;
		VAR
			list: TemplateParameterArray;
			len: SIZE;

		PROCEDURE & InitList*;
		BEGIN NEW( list,8 ); len := 0;
		END InitList;

		PROCEDURE Length*( ): SIZE;
		BEGIN RETURN len;
		END Length;

		PROCEDURE Add*(CONST d: TemplateParameter );
		VAR l: TemplateParameterArray; i: SIZE;
		BEGIN
			IF len = LEN(list) THEN
				NEW(l, 2*len);
				FOR i := 0 TO len-1 DO
					l[i] := list[i];
				END;
			END;
			list[len] := d;
			INC(len);
		END Add;

		PROCEDURE Get*( index: SIZE ): TemplateParameter;
		BEGIN
			RETURN list[index];
		END Get;

		PROCEDURE Set*(index: SIZE; symbol: TemplateParameter);
		BEGIN list[index] := symbol;
		END Set;

	END TemplateParameters;

	(* << MODULE name ['in' context] moduleScope name '.' >>  *)
	Module* = OBJECT (Symbol)
		VAR
			sourceName-: Basic.FileName;
			moduleScope-: ModuleScope;
			context-:Identifier; (* modules context *)
			case-: SIGNED32; (* module notation in lower or upper case, important for printout and operators *)
			isCellNet-: BOOLEAN;
			closingComment-: Comment;
			modifiers-: Modifier;
			parameters-: TemplateParameters;

		PROCEDURE & InitModule( CONST sourceName: ARRAY OF CHAR; position: Position; name: Identifier; scope: ModuleScope; case: SIGNED32);
		BEGIN
			InitSymbol(position,name);
			COPY (sourceName, SELF.sourceName);
			moduleScope := scope;
			ASSERT(scope.ownerModule = NIL); (* cannot register twice ! *)
			scope.ownerModule := SELF;
			context := invalidIdentifier;
			SELF.case := case;
			SetType(moduleType);
			closingComment := NIL;
			isCellNet := FALSE;
			modifiers := NIL;
			parameters := NIL;
		END InitModule;

		PROCEDURE SetCase*(case: SIGNED32);
		BEGIN
			SELF.case := case
		END SetCase;

		PROCEDURE SetCellNet*(isCellNet: BOOLEAN);
		BEGIN SELF.isCellNet := isCellNet
		END SetCellNet;

		PROCEDURE SetContext*(context: Identifier);
		BEGIN	SELF.context := context;
		END SetContext;

		PROCEDURE SetName*(name: Identifier);
		BEGIN SELF.name := name
		END SetName;

		PROCEDURE SetClosingComment*(comment: Comment);
		BEGIN SELF.closingComment := comment
		END SetClosingComment;

		PROCEDURE SetModifiers*(modifiers: Modifier);
		BEGIN SELF.modifiers := modifiers
		END SetModifiers;

		PROCEDURE SetParameters*(parameters: TemplateParameters);
		BEGIN SELF.parameters := parameters;
		END SetParameters;

	END Module;

	ProcedureList* = OBJECT
		VAR list: Basic.List;

		PROCEDURE & InitList*;
		BEGIN NEW( list,8 );
		END InitList;

		PROCEDURE Length*( ): SIZE;
		BEGIN RETURN list.Length();
		END Length;

		PROCEDURE AddProcedure*( d: Procedure );
		BEGIN list.Add(d)
		END AddProcedure;

		PROCEDURE GetProcedure*( index: SIZE ): Procedure;
		VAR p: ANY;
		BEGIN
			IF index >= list.Length() THEN RETURN NIL END;
			p := list.Get(index);
			IF p = NIL THEN
				RETURN NIL
			ELSE
				RETURN p(Procedure);
			END;
		END GetProcedure;

		PROCEDURE SetProcedure*(index: SIZE; expression: Procedure);
		BEGIN list.GrowAndSet(index,expression)
		END SetProcedure;

		PROCEDURE RemoveProcedure*(i: SIZE);
		BEGIN list.RemoveByIndex(i);
		END RemoveProcedure;

	END ProcedureList;

VAR
	(* invalid items used, for example, by parser and checker *)
	invalidIdentifier-: Identifier;
	invalidQualifiedIdentifier-: QualifiedIdentifier;
	invalidType-: Type;
	invalidExpression-: Expression; (* mapped to invalidDesignator for better error handling in checker *)
	invalidDesignator-: Designator;
	invalidValue-: Value;
	invalidSymbol-: Symbol;
	invalidPosition-: Position;

	anonymousIdentifier-: Identifier;
	importType-: Type;
	typeDeclarationType-: Type;
	moduleType-: Type;

	indexListSeparator-: Expression;

	PROCEDURE CloneDesignator*(x: Designator): Designator;
	VAR result: Designator;
	BEGIN
		IF x = NIL THEN RETURN NIL END;
		IF x.original # NIL THEN RETURN CloneExpression(x.original)(Designator) END;
		WITH x:
		  ResultDesignator DO
				result := NewResultDesignator(x.position);
		| SelfDesignator DO
				result := NewSelfDesignator(x.position, x.original);
		| SupercallDesignator DO
				result := NewSupercallDesignator(x.position, x.original, CloneExpression(x.left));
		| DereferenceDesignator DO
				result := NewDereferenceDesignator(x.position, x.original, CloneExpression(x.left));
		| TypeGuardDesignator DO
				result := NewTypeGuardDesignator(x.position, x.original, CloneExpression(x.left), x.type);
		| BuiltinCallDesignator DO
				result := NewBuiltinCallDesignator(x.position, x.original, x.id, CloneExpression(x.left), CloneExpressionList(x.parameters));
		| ProcedureCallDesignator DO
				result := NewProcedureCallDesignator(x.position, NIL, CloneExpression(x.left), CloneExpressionList(x.parameters));
		| InlineCallDesignator DO
				result := NewInlineCallDesignator(x.position, NIL, x.block.Clone()(StatementBlock));
		| IndexDesignator DO
				result := NewIndexDesignator(x.position,NIL,CloneExpression(x.left), CloneExpressionList(x.parameters));
		| SymbolDesignator DO
				result := NewSymbolDesignator(x.position, NIL, CloneExpression(x.left), x.symbol);
		| BracketDesignator DO
				result := NewBracketDesignator(x.position, CloneExpression(x.left), CloneExpressionList(x.parameters));
		| ArrowDesignator DO
				result := NewArrowDesignator(x.position, CloneExpression(x.left));
		| ParameterDesignator DO
				result := NewParameterDesignator(x.position, CloneExpression(x.left), CloneExpressionList(x.parameters));
		| SelectorDesignator DO
				result := NewSelectorDesignator(x.position, CloneExpression(x.left), x.identifier);
		| IdentifierDesignator DO
				result := NewIdentifierDesignator(x.position, x.identifier);
		| Designator DO
		END;
		result.modifiers := x.modifiers;
		RETURN result;
	END CloneDesignator;

	PROCEDURE CloneExpression*(x: Expression): Expression;
	VAR result: Expression;
	BEGIN
		IF (x = NIL) OR (x= invalidExpression) THEN RETURN x END;
		IF x.original # NIL THEN RETURN CloneExpression(x.original) END;

		WITH x: Designator DO
			result := CloneDesignator(x);
		| Conversion DO
			result := CloneExpression(x.expression);
		| TensorRangeExpression DO
			result := NewTensorRangeExpression(x.position);
		| RangeExpression DO
			result := NewRangeExpression(x.position, CloneExpression(x.first), CloneExpression(x.last), CloneExpression(x.step));
		| BinaryExpression DO
			result := NewBinaryExpression(x.position, CloneExpression(x.left), CloneExpression(x.right), x.operator);
		| UnaryExpression DO
			result := NewUnaryExpression(x.position, CloneExpression(x.left), x.operator);
		| MathArrayExpression DO
			result := NewMathArrayExpression(x.position, CloneExpressionList(x.elements));
		| Set DO
			result := NewSet(x.position, CloneExpressionList(x.elements));
		| BooleanValue DO
			result := NewBooleanValue(x.position, x.value);
		| IntegerValue DO
			result := NewIntegerValue(x.position, x.value);
		| CharacterValue DO
			result := NewCharacterValue(x.position, x.value);
		| SetValue DO
			result := NewSetValue(x.position, x.value);
		| MathArrayValue DO
			result := NewMathArrayValue(x.position, CloneExpression(x.array)(MathArrayExpression));
		| RealValue DO
			result := NewRealValue(x.position, x.value, x.subtype);
		| ComplexValue DO
			result := NewComplexValue(x.position, x.realValue, x.imagValue,x.subtype);
		| StringValue DO
			result := NewStringValue(x.position, x.value);
		| NilValue DO
			result := NewNilValue(x.position);
		| EnumerationValue DO
			result := NewEnumerationValue(x.position, x.value);
		| ProcedureValue DO
			result := NewProcedureValue(x.position, x.value);
		ELSE
			HALT(100);
		END;
		result.assignable := x.assignable;
		IF x.resolved = x THEN result.resolved := result(Value) ELSE result.resolved := x.resolved END;
		RETURN result;
	END CloneExpression;


	PROCEDURE NewModule*( CONST sourceName: ARRAY OF CHAR; position: Position;  name: Identifier;scope: ModuleScope; case: SIGNED32 ): Module;
	VAR module: Module;
	BEGIN
		NEW( module, sourceName, position, name, scope, case);  RETURN module;
	END NewModule;

	PROCEDURE NewComment*(position: Position; scope: Scope; CONST source: ARRAY OF CHAR; length: SIZE): Comment;
	VAR comment: Comment;
	BEGIN
		NEW(comment,position,scope,source,length); RETURN comment;
	END NewComment;

	PROCEDURE NewImport*( position: Position;  alias, name: Identifier; direct: BOOLEAN): Import;
	VAR import: Import;
	BEGIN
		NEW( import, position, alias, name, direct );  RETURN import
	END NewImport;

	PROCEDURE NewConstant*( position: Position;  name: Identifier ): Constant;
	VAR constant: Constant;
	BEGIN
		NEW( constant, position, name );  RETURN constant
	END NewConstant;

	PROCEDURE NewProcedure*( position: Position;  name: Identifier; scope: ProcedureScope ): Procedure;
	VAR procedure: Procedure;
	BEGIN
		NEW( procedure, position, name, scope);  RETURN procedure
	END NewProcedure;

	PROCEDURE NewAlias*( position: Position;  name: Identifier; expression: Expression): Alias;
	VAR alias: Alias;
	BEGIN
		NEW( alias, position, name, expression);  RETURN alias
	END NewAlias;

	PROCEDURE NewBuiltin*(position: Position; name: Identifier; id: SIGNED32): Builtin;
	VAR builtin: Builtin;
	BEGIN
		NEW(builtin,position,name,id); RETURN builtin
	END NewBuiltin;

	PROCEDURE NewCustomBuiltin*(position: Position; name: Identifier; id: SIGNED32; subType: SIGNED8): CustomBuiltin;
	VAR builtin:CustomBuiltin;
	BEGIN
		NEW(builtin,position,name,id,subType); RETURN builtin
	END NewCustomBuiltin;

	PROCEDURE NewOperator*( position: Position;  name: Identifier; scope: ProcedureScope): Operator;
	VAR operator: Operator;
	BEGIN
		NEW( operator, position, name, scope);  RETURN operator
	END NewOperator;

	PROCEDURE NewType*(): Type;  (* for error handling: invalid Type, is realtime type *)
	VAR type: Type;
	BEGIN
		NEW( type, invalidPosition);
		type.SetRealtime(TRUE);
		RETURN type
	END NewType;

	PROCEDURE NewByteType*(sizeInBits: SIZE): ByteType;
	VAR basicType: ByteType;
	BEGIN
		NEW(basicType, sizeInBits); RETURN basicType;
	END NewByteType;

	PROCEDURE NewAnyType*(sizeInBits: SIZE): AnyType;
	VAR basicType: AnyType;
	BEGIN
		NEW(basicType, sizeInBits); RETURN basicType;
	END NewAnyType;

	PROCEDURE NewObjectType*(sizeInBits: SIZE): ObjectType;
	VAR basicType: ObjectType;
	BEGIN
		NEW(basicType, sizeInBits); RETURN basicType;
	END NewObjectType;

	PROCEDURE NewNilType*(sizeInBits: SIZE): NilType;
	VAR basicType: NilType;
	BEGIN
		NEW(basicType,  sizeInBits); RETURN basicType;
	END NewNilType;

	PROCEDURE NewAddressType*(sizeInBits: SIZE): AddressType;
	VAR basicType: AddressType;
	BEGIN
		NEW(basicType, sizeInBits); RETURN basicType;
	END NewAddressType;

	PROCEDURE NewSizeType*(sizeInBits: SIZE): SizeType;
	VAR basicType: SizeType;
	BEGIN
		NEW(basicType, sizeInBits); RETURN basicType;
	END NewSizeType;

	PROCEDURE NewBooleanType*(sizeInBits: SIZE): BooleanType;
	VAR basicType: BooleanType;
	BEGIN
		NEW(basicType, sizeInBits); RETURN basicType;
	END NewBooleanType;

	PROCEDURE NewSetType*(sizeInBits: SIZE): SetType;
	VAR basicType: SetType;
	BEGIN
		NEW(basicType, sizeInBits); RETURN basicType;
	END NewSetType;

	PROCEDURE NewCharacterType*(sizeInBits: SIZE): CharacterType;
	VAR basicType: CharacterType;
	BEGIN
		NEW(basicType, sizeInBits); RETURN basicType;
	END NewCharacterType;

	PROCEDURE NewRangeType*(sizeInBits: SIZE): RangeType;
	VAR basicType: RangeType;
	BEGIN
		NEW(basicType, sizeInBits); RETURN basicType;
	END NewRangeType;

	PROCEDURE NewComplexType*(base: Type): ComplexType;
	VAR basicType: ComplexType;
	BEGIN
		NEW(basicType, base); RETURN basicType;
	END NewComplexType;

	PROCEDURE NewIntegerType*(size: SIGNED32; signed: BOOLEAN): IntegerType;
	VAR basicType: IntegerType;
	BEGIN
		NEW(basicType, size, signed); RETURN basicType;
	END NewIntegerType;

	PROCEDURE NewFloatType*(sizeInBits: SIZE): FloatType;
	VAR basicType: FloatType;
	BEGIN
		NEW(basicType, sizeInBits); RETURN basicType;
	END NewFloatType;

	PROCEDURE NewTypeDeclaration*(position: Position; name: Identifier): TypeDeclaration;
	VAR typeDeclaration: TypeDeclaration;
	BEGIN
		ASSERT(name # invalidIdentifier);
		NEW(typeDeclaration,position,name); RETURN typeDeclaration
	END NewTypeDeclaration;

	PROCEDURE NewStringType*( position: Position; baseType: Type; length: SIZE): StringType;
	VAR stringType: StringType;
	BEGIN
		NEW( stringType, position, baseType, length);  RETURN stringType;
	END NewStringType;

	PROCEDURE NewEnumerationType*( position: Position; scope: Scope; enumerationScope: EnumerationScope): EnumerationType;
	VAR enumerationType: EnumerationType;
	BEGIN
		NEW( enumerationType, position, scope, enumerationScope);  RETURN enumerationType;
	END NewEnumerationType;

	PROCEDURE NewArrayType*( position: Position; scope: Scope; form: SIGNED32): ArrayType;
	VAR arrayType: ArrayType;
	BEGIN
		NEW( arrayType, position,scope, form);  RETURN arrayType;
	END NewArrayType;

	PROCEDURE NewMathArrayType*( position: Position; scope: Scope; form: SIGNED32): MathArrayType;
	VAR mathArrayType: MathArrayType;
	BEGIN
		NEW( mathArrayType,  position,scope,form);  RETURN mathArrayType;
	END NewMathArrayType;

	PROCEDURE NewPointerType*( position: Position; scope: Scope): PointerType;
	VAR pointerType: PointerType;
	BEGIN
		NEW( pointerType, position,scope);  RETURN pointerType;
	END NewPointerType;

	PROCEDURE NewPortType*( position: Position; direction: SIGNED32; sizeExpression: Expression; scope: Scope): PortType;
	VAR portType: PortType;
	BEGIN
		NEW( portType, position, direction, sizeExpression, scope);  RETURN portType;
	END NewPortType;

	PROCEDURE NewRecordType*( position: Position; scope: Scope; recordScope: RecordScope): RecordType;
	VAR recordType: RecordType;
	BEGIN
		NEW( recordType, position, scope, recordScope);  RETURN recordType
	END NewRecordType;

	PROCEDURE NewCellType*(position: Position; scope:Scope; cellScope: CellScope): CellType;
	VAR actorType: CellType;
	BEGIN
		NEW(actorType, position, scope, cellScope); RETURN actorType;
	END NewCellType;

	PROCEDURE NewProcedureType*( position: Position; scope: Scope): ProcedureType;
	VAR procedureType: ProcedureType;
	BEGIN
		NEW( procedureType, position,scope);  RETURN procedureType;
	END NewProcedureType;

	PROCEDURE NewQualifiedType*( position: Position;   scope: Scope; qualifiedIdentifier: QualifiedIdentifier): QualifiedType;
	VAR qualifiedType: QualifiedType;
	BEGIN
		NEW( qualifiedType, position,scope,qualifiedIdentifier );  RETURN qualifiedType
	END NewQualifiedType;

	PROCEDURE NewSymbol*(name: Identifier): Symbol; (* for error handling: invalid Symbol *)
	VAR symbol: Symbol;
	BEGIN
		NEW(symbol,invalidPosition,name); RETURN symbol
	END NewSymbol;

	PROCEDURE NewVariable*( position: Position;  name: Identifier): Variable;
	VAR variable: Variable;
	BEGIN
		NEW( variable, position, name );  RETURN variable
	END NewVariable;

	PROCEDURE NewQualifiedIdentifier*( position: Position;  prefix, suffix: Identifier ): QualifiedIdentifier;
	VAR qualifiedIdentifier: QualifiedIdentifier;
	BEGIN
		NEW( qualifiedIdentifier, position, prefix, suffix );  RETURN qualifiedIdentifier
	END NewQualifiedIdentifier;

	PROCEDURE NewIdentifier*(CONST name: ARRAY OF CHAR): Identifier;
	BEGIN
		RETURN Basic.MakeString(name);
	END NewIdentifier;

	PROCEDURE NewParameter*( position: Position; ownerType:Type ;  name: Identifier; passAs: SIGNED32): Parameter;
	VAR parameter: Parameter;
	BEGIN
		NEW( parameter, position, ownerType, name, passAs);  RETURN parameter;
	END NewParameter;

	PROCEDURE NewProperty*( position: Position; name: Identifier): Property;
	VAR property: Property;
	BEGIN
		NEW( property, position, name);  RETURN property;
	END NewProperty;

	PROCEDURE NewExpressionList*(): ExpressionList;
	VAR expressionList: ExpressionList;
	BEGIN
		NEW(expressionList);  RETURN expressionList
	END NewExpressionList;

	PROCEDURE CloneExpressionList*(l: ExpressionList): ExpressionList;
	VAR copy: ExpressionList; i: SIZE;
	BEGIN
		IF l = NIL THEN
			copy := NIL;
		ELSE
			NEW(copy);
			FOR i := 0 TO l.Length()-1 DO
				copy.AddExpression(CloneExpression(l.GetExpression(i)));
			END;
		END;
		RETURN copy
	END CloneExpressionList;

	PROCEDURE NewDesignator*(): Designator; (* for error handling: invalid Designator *)
	VAR designator: Designator;
	BEGIN
		NEW(designator,invalidPosition); RETURN designator;
	END NewDesignator;

	PROCEDURE NewIdentifierDesignator*( position: Position; identifier: Identifier): IdentifierDesignator;
	VAR identifierDesignator: IdentifierDesignator;
	BEGIN
		NEW( identifierDesignator, position, identifier );  RETURN identifierDesignator
	END NewIdentifierDesignator;

	PROCEDURE NewSelectorDesignator*( position: Position;  left: Expression; name: Identifier ): SelectorDesignator;
	VAR selectorDesignator: SelectorDesignator;
	BEGIN
		NEW( selectorDesignator, position, left, name );  RETURN selectorDesignator
	END NewSelectorDesignator;

	PROCEDURE NewParameterDesignator*( position: Position; left: Expression; expressionList: ExpressionList ): ParameterDesignator;
	VAR parameterDesignator: ParameterDesignator;
	BEGIN
		NEW( parameterDesignator,position, left, expressionList );  RETURN parameterDesignator
	END NewParameterDesignator;

	PROCEDURE NewArrowDesignator*( position: Position; left: Expression ): ArrowDesignator;
	VAR dereferenceDesignator: ArrowDesignator;
	BEGIN
		NEW( dereferenceDesignator, position, left );  RETURN dereferenceDesignator;
	END NewArrowDesignator;

	PROCEDURE NewBracketDesignator*( position: Position; left: Expression; expressionList: ExpressionList ): BracketDesignator;
	VAR bracketDesignator: BracketDesignator;
	BEGIN
		NEW( bracketDesignator, position, left, expressionList );  RETURN bracketDesignator
	END NewBracketDesignator;

	PROCEDURE NewSymbolDesignator*( position: Position; original: Expression; left: Expression; symbol: Symbol ): SymbolDesignator;
	VAR symbolDesignator: SymbolDesignator;
	BEGIN
		NEW( symbolDesignator, position, original, left, symbol); RETURN symbolDesignator
	END NewSymbolDesignator;

	PROCEDURE NewIndexDesignator*( position: Position; original: Expression; left: Expression; parameters: ExpressionList): IndexDesignator;
	VAR indexDesignator: IndexDesignator;
	BEGIN
		NEW( indexDesignator, position, original, left, parameters);  RETURN indexDesignator
	END NewIndexDesignator;

	PROCEDURE NewProcedureCallDesignator*(position: Position; original: Expression; left: Expression; parameters: ExpressionList): ProcedureCallDesignator;
	VAR procedureCallDesignator: ProcedureCallDesignator;
	BEGIN
		NEW(procedureCallDesignator, position, original, left, parameters); RETURN procedureCallDesignator
	END NewProcedureCallDesignator;

	PROCEDURE NewInlineCallDesignator*(position: Position; o: Expression; block: StatementBlock): InlineCallDesignator;
	VAR inlineCall: InlineCallDesignator;
	BEGIN
		NEW(inlineCall, position, o, block); RETURN inlineCall;
	END NewInlineCallDesignator;

	PROCEDURE NewBuiltinCallDesignator*(position: Position; original: Expression;  id: SIGNED32;left: Expression; parameters: ExpressionList): BuiltinCallDesignator;
	VAR builtinCallDesignator: BuiltinCallDesignator;
	BEGIN
		NEW(builtinCallDesignator, position, original, id, left,parameters); RETURN builtinCallDesignator
	END NewBuiltinCallDesignator;

	PROCEDURE NewTypeGuardDesignator*(position: Position; original: Expression; left: Expression; type: Type): TypeGuardDesignator;
	VAR guardDesignator: TypeGuardDesignator;
	BEGIN
		NEW(guardDesignator,position,original, left,type); RETURN guardDesignator;
	END NewTypeGuardDesignator;

	PROCEDURE NewDereferenceDesignator*( position: Position; original: Expression; left: Expression): DereferenceDesignator;
	VAR dereferenceDesignator: DereferenceDesignator;
	BEGIN
		NEW( dereferenceDesignator, position, original, left);  RETURN dereferenceDesignator
	END NewDereferenceDesignator;

	PROCEDURE NewSupercallDesignator*( position: Position; original: Expression; left: Expression): SupercallDesignator;
	VAR supercallDesignator: SupercallDesignator;
	BEGIN
		NEW( supercallDesignator, position, original, left);  RETURN supercallDesignator
	END NewSupercallDesignator;

	PROCEDURE NewSelfDesignator*( position: Position; original: Expression): SelfDesignator;
	VAR selfDesignator: SelfDesignator;
	BEGIN
		NEW( selfDesignator, position, original);  RETURN selfDesignator
	END NewSelfDesignator;

	PROCEDURE NewResultDesignator*( position: Position): ResultDesignator;
	VAR resultDesignator: ResultDesignator;
	BEGIN
		NEW( resultDesignator, position);  RETURN resultDesignator
	END NewResultDesignator;

	PROCEDURE NewExpression*(): Expression; (* for error handling: invalid Expression *)
	VAR expression: Expression;
	BEGIN
		NEW(expression,invalidPosition); RETURN expression;
	END NewExpression;

	(*
	PROCEDURE CloneExpression*(e: Expression): Expression;
	VAR copy: Expression;
	BEGIN
		IF e = NIL THEN
			RETURN NIL
		ELSE
			copy := e.Clone();
			copy.type := NIL;
			copy.assignable := e.assignable;
			copy.position := e.position;
			copy.state := e.state;
			IF e.resolved = e THEN copy.resolved := copy(Value) ELSE copy.resolved := e.resolved END;
			RETURN copy
		END;
	END CloneExpression;

	PROCEDURE CloneDesignator*(e: Expression): Designator;
	BEGIN
		IF e = NIL THEN RETURN NIL ELSE RETURN CloneExpression(e)(Designator) END;
	END CloneDesignator;
	*)

	PROCEDURE NewElement*( position: Position;  from,to: Expression ): Expression;
	BEGIN
			IF from = to THEN RETURN from
			ELSE RETURN NewRangeExpression(position,from,to,NIL)
			END;
	END NewElement;

	PROCEDURE NewSet*( position: Position; elements: ExpressionList ): Set;
	VAR set: Set;
	BEGIN NEW( set, position, elements );  RETURN set
	END NewSet;

	PROCEDURE NewMathArrayExpression*( position: Position; elements: ExpressionList ): MathArrayExpression;
	VAR mathArrayExpression: MathArrayExpression;
	BEGIN NEW( mathArrayExpression, position, elements );  RETURN mathArrayExpression
	END NewMathArrayExpression;

	PROCEDURE NewBinaryExpression*( position: Position;  left, right: Expression;  operator: SIGNED32 ): BinaryExpression;
	VAR binaryExpression: BinaryExpression;
	BEGIN
		NEW( binaryExpression, position, left, right, operator );  RETURN binaryExpression;
	END NewBinaryExpression;

	PROCEDURE NewRangeExpression*(position: Position; first, last, step: Expression): RangeExpression;
	VAR rangeExpression: RangeExpression;
	BEGIN
		NEW(rangeExpression, position, first, last, step); RETURN rangeExpression
	END NewRangeExpression;

	PROCEDURE NewTensorRangeExpression*(position: Position): TensorRangeExpression;
	VAR tensorRangeExpression: TensorRangeExpression;
	BEGIN
		NEW(tensorRangeExpression,position); RETURN tensorRangeExpression
	END NewTensorRangeExpression;

	PROCEDURE NewUnaryExpression*( position: Position;  operand: Expression;  operator: SIGNED32 ): UnaryExpression;
	VAR unaryExpression: UnaryExpression;
	BEGIN
		NEW( unaryExpression, position, operand, operator );  RETURN unaryExpression;
	END NewUnaryExpression;

	PROCEDURE NewConversion*( position: Position; expression: Expression; type: Type; typeExpression: Expression): Conversion;
	VAR conversion: Conversion;
	BEGIN
		ASSERT(type # NIL);
		NEW( conversion, position, expression,type, typeExpression );  RETURN conversion;
	END NewConversion;

	PROCEDURE NewValue*(): Value;(* for error handling: invalid Value *)
	VAR value: Value;
	BEGIN
		NEW(value,invalidPosition); RETURN value;
	END NewValue;

	PROCEDURE NewIntegerValue*( position: Position;  value: Basic.Integer): IntegerValue;
	VAR integerValue: IntegerValue;
	BEGIN
		NEW( integerValue, position, value);  RETURN integerValue;
	END NewIntegerValue;

	PROCEDURE NewCharacterValue*( position: Position;  value: CHAR): CharacterValue;
	VAR characterValue: CharacterValue;
	BEGIN
		NEW( characterValue, position, value);  RETURN characterValue;
	END NewCharacterValue;

	PROCEDURE NewSetValue*(position: Position; value: Basic.Set): SetValue;
	VAR setValue: SetValue;
	BEGIN
		NEW(setValue, position, value); RETURN setValue
	END NewSetValue;

	PROCEDURE NewMathArrayValue*( position: Position ; arr: MathArrayExpression): MathArrayValue;
	VAR mathArrayValue: MathArrayValue;
	BEGIN NEW( mathArrayValue, position,arr );  RETURN mathArrayValue
	END NewMathArrayValue;

	PROCEDURE NewRealValue*( position: Position;  value: FLOAT64; subType: SubType): RealValue;
	VAR realValue: RealValue;
	BEGIN
		NEW( realValue, position, value, subType);  RETURN realValue
	END NewRealValue;

	PROCEDURE NewComplexValue*( position: Position;  realValue, imagValue: FLOAT64; subType: SubType): ComplexValue;
	VAR complexValue: ComplexValue;
	BEGIN
		NEW( complexValue, position, realValue, imagValue, subType);  RETURN complexValue
	END NewComplexValue;

	PROCEDURE NewStringValue*( position: Position;  value: String): StringValue;
	VAR stringValue: StringValue;
	BEGIN
		NEW( stringValue, position, value );  RETURN stringValue
	END NewStringValue;

	PROCEDURE NewBooleanValue*( position: Position;  value: BOOLEAN): BooleanValue;
	VAR booleanValue: BooleanValue;
	BEGIN
		NEW( booleanValue, position, value );  RETURN booleanValue;
	END NewBooleanValue;

	PROCEDURE NewNilValue*( position: Position ): NilValue;
	VAR nilValue: NilValue;
	BEGIN
		NEW( nilValue, position );  RETURN nilValue
	END NewNilValue;

	PROCEDURE NewEnumerationValue*( position: Position; value: Basic.Integer ): EnumerationValue;
	VAR enumeratorValue: EnumerationValue;
	BEGIN
		NEW( enumeratorValue, position, value );  RETURN enumeratorValue
	END NewEnumerationValue;

	PROCEDURE NewProcedureValue*( position: Position; value: Procedure ): ProcedureValue;
	VAR procedureValue: ProcedureValue;
	BEGIN
		NEW( procedureValue, position, value );  RETURN procedureValue
	END NewProcedureValue;

	PROCEDURE NewStatement*(outer: Statement): Statement; (* for error handling: invalid Statement *)
	VAR statement: Statement;
	BEGIN NEW(statement,invalidPosition,outer); RETURN statement;
	END NewStatement;

	PROCEDURE CloneStatement*(statement: Statement): Statement;
	BEGIN IF statement = NIL THEN RETURN NIL ELSE RETURN statement.Clone() END
	END CloneStatement;

	PROCEDURE NewStatementSequence*(): StatementSequence;
	VAR statementSequence: StatementSequence;
	BEGIN
		NEW( statementSequence);  RETURN statementSequence
	END NewStatementSequence;

	PROCEDURE CloneStatementSequence*(statementSequence: StatementSequence): StatementSequence;
	VAR copy: StatementSequence;
	BEGIN IF statementSequence = NIL THEN RETURN NIL ELSE statementSequence.Clone(copy); RETURN copy END
	END CloneStatementSequence;



	PROCEDURE NewModifier*(position: Position; identifier: Identifier; expression: Expression): Modifier;
	VAR blockModifier: Modifier;
	BEGIN
		NEW(blockModifier,position,identifier,expression); RETURN blockModifier
	END NewModifier;

	PROCEDURE NewStatementBlock*( position: Position ; outer: Statement; scope: Scope): StatementBlock;
	VAR statementBlock: StatementBlock;
	BEGIN
		NEW( statementBlock, position, outer, scope );  RETURN statementBlock
	END NewStatementBlock;


	PROCEDURE NewBody*( position: Position ; scope: ProcedureScope): Body;
	VAR body: Body;
	BEGIN
		NEW( body, position,scope );  RETURN body
	END NewBody;

	PROCEDURE NewIfPart*(): IfPart;
	VAR ifPart: IfPart;
	BEGIN
		NEW( ifPart);  RETURN ifPart
	END NewIfPart;

	PROCEDURE NewIfStatement*( position: Position ; outer: Statement): IfStatement;
	VAR ifStatement: IfStatement;
	BEGIN
		NEW( ifStatement, position,outer );  RETURN ifStatement
	END NewIfStatement;

	PROCEDURE NewAssignment*( position: Position;  left: Expression; right: Expression; outer: Statement): Assignment;
	VAR assignment: Assignment;
	BEGIN
		NEW( assignment, position, left, right,outer );  RETURN assignment
	END NewAssignment;

	PROCEDURE NewCommunicationStatement*( position: Position;  op: SIGNED32; left: Expression; right: Expression; outer: Statement): CommunicationStatement;
	VAR communication: CommunicationStatement;
	BEGIN
		NEW( communication, position, op, left, right,outer );  RETURN communication
	END NewCommunicationStatement;

	PROCEDURE NewDeclarationStatement*(position: Position; outer: Statement): DeclarationStatement;
	VAR declaration: DeclarationStatement;
	BEGIN
		NEW(declaration,position,outer); RETURN declaration
	END NewDeclarationStatement;

	PROCEDURE NewProcedureCallStatement*(position: Position; ignore: BOOLEAN; call: Expression; outer: Statement): ProcedureCallStatement;
	VAR caller: ProcedureCallStatement;
	BEGIN
		NEW(caller,position,ignore,call,outer); RETURN caller
	END NewProcedureCallStatement;

	PROCEDURE NewCaseStatement*( position: Position ; outer: Statement): CaseStatement;
	VAR caseStatement: CaseStatement;
	BEGIN
		NEW( caseStatement, position,outer );  RETURN caseStatement
	END NewCaseStatement;

	PROCEDURE NewCasePart*(): CasePart;
	VAR casePart: CasePart;
	BEGIN
		NEW( casePart);  RETURN casePart
	END NewCasePart;

	PROCEDURE NewWithPart*(): WithPart;
	VAR withPart: WithPart;
	BEGIN
		NEW( withPart);  RETURN withPart
	END NewWithPart;

	PROCEDURE NewWithStatement*( position: Position; outer: Statement): WithStatement;
	VAR withStatement: WithStatement;
	BEGIN
		NEW( withStatement, position, outer );  RETURN withStatement
	END NewWithStatement;

	PROCEDURE NewWhileStatement*( position: Position ; outer: Statement): WhileStatement;
	VAR whileStatement: WhileStatement;
	BEGIN
		NEW( whileStatement, position,outer );  RETURN whileStatement
	END NewWhileStatement;

	PROCEDURE NewRepeatStatement*( position: Position ; outer: Statement): RepeatStatement;
	VAR repeatStatement: RepeatStatement;
	BEGIN
		NEW( repeatStatement, position ,outer);  RETURN repeatStatement
	END NewRepeatStatement;

	PROCEDURE NewForStatement*( position: Position; outer: Statement ): ForStatement;
	VAR forStatement: ForStatement;
	BEGIN
		NEW( forStatement, position,outer );  RETURN forStatement
	END NewForStatement;

	PROCEDURE NewLoopStatement*( position: Position ; outer: Statement): LoopStatement;
	VAR loopStatement: LoopStatement;
	BEGIN
		NEW( loopStatement, position ,outer);  RETURN loopStatement
	END NewLoopStatement;

	PROCEDURE NewExitableBlock*( position: Position ; outer: Statement): ExitableBlock;
	VAR loopStatement: ExitableBlock;
	BEGIN
		NEW( loopStatement, position ,outer);  RETURN loopStatement
	END NewExitableBlock;

	PROCEDURE NewExitStatement*( position: Position ; outer: Statement): ExitStatement;
	VAR exitStatement: ExitStatement;
	BEGIN
		NEW( exitStatement, position, outer);  RETURN exitStatement
	END NewExitStatement;

	PROCEDURE NewReturnStatement*( position: Position; outer: Statement ): ReturnStatement;
	VAR returnStatement: ReturnStatement;
	BEGIN
		NEW( returnStatement, position,outer );  RETURN returnStatement
	END NewReturnStatement;

	PROCEDURE NewAwaitStatement*( position: Position; outer: Statement ): AwaitStatement;
	VAR awaitStatement: AwaitStatement;
	BEGIN
		NEW( awaitStatement, position, outer );  RETURN awaitStatement
	END NewAwaitStatement;

	PROCEDURE NewCode*(position: Position; outer: Statement): Code;
	VAR code: Code;
	BEGIN
		NEW(code,position,outer); RETURN code
	END NewCode;

	PROCEDURE NewProcedureScope*(outer: Scope): ProcedureScope;
	VAR scope: ProcedureScope;
	BEGIN	NEW(scope,outer); RETURN scope
	END NewProcedureScope;

	PROCEDURE NewBlockScope*(outer: Scope): BlockScope;
	VAR scope: BlockScope;
	BEGIN	NEW(scope,outer); RETURN scope
	END NewBlockScope;

	PROCEDURE NewModuleScope*(): ModuleScope;
	VAR scope: ModuleScope;
	BEGIN	NEW(scope); RETURN scope
	END NewModuleScope;

	PROCEDURE NewRecordScope*(outer: Scope): RecordScope;
	VAR scope: RecordScope;
	BEGIN	NEW(scope,outer); RETURN scope
	END NewRecordScope;

	PROCEDURE NewCellScope*(outer: Scope): CellScope;
	VAR scope: CellScope;
	BEGIN	NEW(scope,outer); RETURN scope
	END NewCellScope;

	PROCEDURE NewEnumerationScope*(outer: Scope): EnumerationScope;
	VAR scope: EnumerationScope;
	BEGIN NEW(scope,outer); RETURN scope
	END NewEnumerationScope;

	PROCEDURE Init;
	BEGIN;
		invalidPosition.start := -1;
		invalidIdentifier := Basic.invalidString;
		invalidQualifiedIdentifier := NewQualifiedIdentifier(invalidPosition,invalidIdentifier,Basic.emptyString);
		invalidType := NewType();
		invalidDesignator := NewDesignator();
		invalidDesignator.SetType(invalidType);
		invalidExpression := invalidDesignator;
		invalidValue := NewValue();
		invalidSymbol := NewSymbol(NewIdentifier(""));
		invalidSymbol.SetType(invalidType);

		importType := NewType();
		importType.SetState(Resolved);
		typeDeclarationType := NewType();
		typeDeclarationType.SetState(Resolved);
		moduleType := NewType();
		moduleType.SetState(Resolved);
		anonymousIdentifier := NewIdentifier("");

		indexListSeparator := NewDesignator();
		indexListSeparator.SetType(invalidType);

	END Init;

BEGIN
	Init;
END FoxSyntaxTree.
