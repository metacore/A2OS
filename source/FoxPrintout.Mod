MODULE FoxPrintout; (** AUTHOR "fof & fn"; PURPOSE "Oberon Compiler Module Output for SymbolFile, Pretty Printing and Testing"; *)
(* (c) fof ETHZ 2009 *)

IMPORT
	Scanner := FoxScanner, SyntaxTree := FoxSyntaxTree, Global := FoxGlobal, Basic := FoxBasic, Fingerprinter := FoxFingerprinter, Streams, D:=Debugging, SYSTEM;

CONST
	(* print modes *)
	Exported*=0; SymbolFile*=1; SourceCode*=2;  All*=3;

	DebugPosition=FALSE;
TYPE

	Printer*= OBJECT (SyntaxTree.Visitor)
	VAR
		w-: Basic.Writer; mode: LONGINT; singleStatement: BOOLEAN;
		currentScope: SyntaxTree.Scope; ws: Streams.StringWriter;
		info: BOOLEAN; case: LONGINT;
		useCase: BOOLEAN; (* TRUE to enable case conversion in "Identifier" *)

		alertCount, commentCount: LONGINT;
		fingerprinter:Fingerprinter.Fingerprinter;

		PROCEDURE Small(CONST name: ARRAY OF CHAR; VAR result: ARRAY OF CHAR);
		VAR ch: CHAR; i: LONGINT;
		BEGIN
			i := 0;
			REPEAT
				ch := name[i];
				IF (ch >= 'A') & (ch <= 'Z') THEN
					ch := CHR(ORD(ch)-ORD('A')+ORD('a'));
				END;
				result[i] := ch; INC(i);
			UNTIL ch = 0X;
		END Small;

		PROCEDURE Big(CONST name: ARRAY OF CHAR; VAR result: ARRAY OF CHAR);
		VAR ch: CHAR; i: LONGINT;
		BEGIN
			i := 0;
			REPEAT
				ch := name[i];
				IF (ch >= 'a') & (ch <= 'z') THEN
					ch := CHR(ORD(ch)-ORD('a')+ORD('A'));
				END;
				result[i] := ch; INC(i);
			UNTIL ch = 0X;
		END Big;

		PROCEDURE Keyword(CONST a: ARRAY OF CHAR);
		VAR str: ARRAY 64 OF CHAR;
		BEGIN
			IF case= Scanner.Lowercase THEN Small(a,str) ELSE COPY(a,str) END;
			w.BeginKeyword;
			w.String(str);
			w.EndKeyword;
		END Keyword;

		PROCEDURE AlertString(CONST s: ARRAY OF CHAR);
		BEGIN
			w.BeginAlert; w.String(s); w.EndAlert;
		END AlertString;

		PROCEDURE Indent;
		BEGIN w.Ln;
		END Indent;

		PROCEDURE Identifier*(x: SyntaxTree.Identifier);
		VAR str: Scanner.IdentifierString;
		BEGIN
			Basic.GetString(x,str);
			IF useCase THEN
				IF case = Scanner.Lowercase THEN Small(str,str); ELSE Big(str,str); END;
			END;
			w.String(str);
		END Identifier;

		PROCEDURE QualifiedIdentifier*(x: SyntaxTree.QualifiedIdentifier);
		BEGIN
			IF x.prefix # SyntaxTree.invalidIdentifier THEN Identifier(x.prefix); w.String("."); END;
			Identifier(x.suffix);
		END QualifiedIdentifier;

		PROCEDURE Type*(x: SyntaxTree.Type);
		BEGIN
			IF x= NIL THEN
				AlertString("nil type");
			ELSE
				VType(x);
			END;
		END Type;

		PROCEDURE VisitType*(x: SyntaxTree.Type);
		BEGIN
			IF x = SyntaxTree.importType THEN w.String("importType")
			ELSIF x = SyntaxTree.typeDeclarationType THEN w.String("typeDeclarationType");
			ELSE
				AlertString("InvalidType");
			END;
		END VisitType;

		PROCEDURE VisitBasicType*(x: SyntaxTree.BasicType);
		BEGIN
			IF x.typeDeclaration # NIL THEN
				Identifier(x.typeDeclaration.name);
			ELSE
				Identifier(x.name);
			END
		END VisitBasicType;

		PROCEDURE VisitBooleanType*(x: SyntaxTree.BooleanType);
		BEGIN
			VisitBasicType(x);
		END VisitBooleanType;

		PROCEDURE VisitSetType*(x: SyntaxTree.SetType);
		BEGIN
			VisitBasicType(x);
		END VisitSetType;

		PROCEDURE VisitSizeType*(x: SyntaxTree.SizeType);
		BEGIN
			VisitBasicType(x);
		END VisitSizeType;

		PROCEDURE VisitCharacterType*(x: SyntaxTree.CharacterType);
		BEGIN
			VisitBasicType(x);
		END VisitCharacterType;

		PROCEDURE VisitIntegerType*(x: SyntaxTree.IntegerType);
		BEGIN
			VisitBasicType(x);
		END VisitIntegerType;

		PROCEDURE VisitFloatType*(x: SyntaxTree.FloatType);
		BEGIN
			VisitBasicType(x);
		END VisitFloatType;

		PROCEDURE VisitComplexType*(x: SyntaxTree.ComplexType);
		BEGIN
			VisitBasicType(x);
		END VisitComplexType;

		PROCEDURE VisitByteType*(x: SyntaxTree.ByteType);
		BEGIN
			VisitBasicType(x);
		END VisitByteType;

		PROCEDURE VisitQualifiedType*(x: SyntaxTree.QualifiedType);
		BEGIN
			IF x.resolved = SyntaxTree.invalidType THEN
				AlertString("(*unresolved*)");
			END;
			IF x.qualifiedIdentifier # NIL THEN
				(* Problem: how to distinguish betwteen type aliases, e.g. Status = LONGINT and actual use of LONGINT?
					This tries to use scope level: if the type is declared in the global scope, it should be a basic type use. *)
				IF x.resolved # NIL THEN
					useCase := (x.resolved IS SyntaxTree.BasicType) & (x.scope.Level() = 0);
				END;
				QualifiedIdentifier(x.qualifiedIdentifier);
				useCase := FALSE;
			ELSE
				AlertString("NIL (* missing qualified identifier *)");
			END;
		END VisitQualifiedType;

		PROCEDURE VisitStringType*(x: SyntaxTree.StringType);
		BEGIN
			w.String("STRING"); w.String("(* len = "); w.Int(x.length,1); w.String(" *)");
		END VisitStringType;

		PROCEDURE VisitEnumerationType*(x: SyntaxTree.EnumerationType);
		VAR e: SyntaxTree.Constant; first: BOOLEAN;
		BEGIN
			Keyword("ENUM ");

			IF x.enumerationBase # NIL THEN
				w.String("(");
					Type(x.enumerationBase);
				w.String(") ");
			END;

			e := x.enumerationScope.firstConstant; first := TRUE;
			WHILE (e # NIL) DO
				IF ~first THEN w.String(", ") ELSE first := FALSE END;
				VisitConstant(e);
				e := e.nextConstant;
			END;

			Keyword(" END");
		END VisitEnumerationType;

		PROCEDURE VisitRangeType*(x: SyntaxTree.RangeType);
		BEGIN VisitBasicType(x);
		END VisitRangeType;

		PROCEDURE VisitArrayType*(x: SyntaxTree.ArrayType);
		BEGIN
			Keyword("ARRAY " );
			IF x.length # NIL THEN Expression(x.length);
			w.String( " " );  END;
			Keyword("OF " );
			Type(x.arrayBase);
		END VisitArrayType;

		PROCEDURE VisitNilType*(x: SyntaxTree.NilType);
		BEGIN
			w.String("NILTYPE");
		END VisitNilType;

		PROCEDURE VisitAddressType*(x: SyntaxTree.AddressType);
		BEGIN
			w.String("ADDRESSTYPE");
		END VisitAddressType;

		PROCEDURE VisitObjectType*(x: SyntaxTree.ObjectType);
		BEGIN
			VisitBasicType(x);
		END VisitObjectType;

		PROCEDURE VisitAnyType*(x: SyntaxTree.AnyType);
		BEGIN
			VisitBasicType(x);
		END VisitAnyType;

		PROCEDURE VisitMathArrayType*(x: SyntaxTree.MathArrayType);
		BEGIN
			Keyword("ARRAY " );
			IF x.form = SyntaxTree.Tensor THEN w.String("[?] ");
			ELSE
				w.String("[");
				IF x.length = NIL THEN
					w.String("*")
				ELSE
					Expression(x.length);
				END;
				WHILE(x.arrayBase # NIL) & (x.arrayBase IS SyntaxTree.MathArrayType) DO
					x := x.arrayBase(SyntaxTree.MathArrayType);
					w.String(", ");
					IF x.length = NIL THEN
						w.String("*")
					ELSE
						Expression(x.length);
					END;
				END;
				w.String("] ");
			END;
			IF x.arrayBase # NIL THEN
				Keyword("OF " );
				Type(x.arrayBase);
			END;
		END VisitMathArrayType;

		PROCEDURE PointerFlags(x: SyntaxTree.PointerType);
		VAR first: BOOLEAN;
		BEGIN
			first := TRUE;
			IF x.isUnsafe THEN Flag(Global.NameUnsafe,first) END;
			IF x.isUntraced THEN Flag(Global.NameUntraced,first) END;
			IF x.isRealtime THEN Flag(Global.NameRealtime,first) END;
			IF x.isDisposable THEN Flag(Global.NameDisposable,first) END;
			IF x.isPlain THEN Flag(Global.NamePlain,first) END;
			FlagEnd(first);
		END PointerFlags;

		PROCEDURE ObjectFlags ( rec: SyntaxTree.RecordType; x: SyntaxTree.PointerType);
		VAR first: BOOLEAN;
		BEGIN
			first := TRUE;
			IF x.isUnsafe THEN Flag(Global.NameUnsafe,first) END;
			IF x.isRealtime THEN Flag(Global.NameRealtime,first) END;
			IF x.isDisposable THEN Flag(Global.NameDisposable,first) END;
			IF x.isPlain THEN Flag(Global.NamePlain,first) END;
			IF rec.isAbstract THEN Flag(Global.NameAbstract, first) END;
			IF rec.IsProtected() THEN Flag(Global.NameExclusive, first) END;
			FlagEnd(first);
		END ObjectFlags;

		PROCEDURE VisitPointerType*(x: SyntaxTree.PointerType);
		VAR pointerBase: SyntaxTree.Type;
		BEGIN
			IF x.pointerBase = NIL THEN
				w.BeginAlert; Keyword("POINTER TO NIL"); w.EndAlert;
			ELSE
				pointerBase := x.pointerBase;
				IF x.isHidden THEN
					Type(x.pointerBase);
				ELSIF (pointerBase IS SyntaxTree.RecordType) & (pointerBase(SyntaxTree.RecordType).isObject) THEN
					VisitRecordType(pointerBase(SyntaxTree.RecordType))
				ELSE
					Keyword("POINTER "); PointerFlags(x); Keyword("TO " );  Type(x.pointerBase);
				END;
			END;
		END VisitPointerType;

		PROCEDURE VisitPortType*(x: SyntaxTree.PortType);
		BEGIN
			Keyword("PORT");
			IF x.direction = SyntaxTree.OutPort THEN
				Keyword(" OUT")
			ELSE
				ASSERT(x.direction = SyntaxTree.InPort);
				Keyword(" IN");
			END;
			IF x.sizeExpression # NIL THEN
				w.String(" ("); Expression(x.sizeExpression); w.String(")");
			END;
		END VisitPortType;

		PROCEDURE VisitCellType*(x: SyntaxTree.CellType);
		BEGIN
			IF x.isCellNet THEN
				Keyword("CELLNET ")
			ELSE
				Keyword("CELL ");
			END;
			Modifiers(x.modifiers);
			IF x.firstParameter # NIL THEN ParameterList(x.firstParameter) END;
			Scope(x.cellScope);

			IF (x.cellScope IS SyntaxTree.CellScope) & (x.cellScope(SyntaxTree.CellScope).bodyProcedure # NIL) THEN
				Body(x.cellScope(SyntaxTree.CellScope).bodyProcedure.procedureScope.body, mode >= SourceCode)
			END;

			Indent; Keyword("END ");
			IF (x.typeDeclaration # NIL) THEN
				Identifier(x.typeDeclaration.name);
			END;
		END VisitCellType;

		PROCEDURE VisitRecordType*(x: SyntaxTree.RecordType);
		VAR prevScope: SyntaxTree.Scope;
		BEGIN
			IF x.isObject THEN
				Keyword("OBJECT ");
				IF x.pointerType # NIL THEN ObjectFlags(x, x.pointerType)
				END;
				IF info THEN
					BeginComment; w.String("ObjectType");

					EndComment;
				END;
				IF (x.baseType # NIL)  THEN
					w.String( "(" );
					IF (x.baseType IS SyntaxTree.RecordType) & (x.baseType(SyntaxTree.RecordType).pointerType # NIL) THEN
						Type(x.baseType(SyntaxTree.RecordType).pointerType)
					ELSE
						Type(x.baseType);
					END;
					w.String( ")" );
				END;
				Scope(x.recordScope);

				IF (x.recordScope.bodyProcedure # NIL) THEN
					Body(x.recordScope.bodyProcedure.procedureScope.body, mode >= SourceCode)
				END;

				Indent; Keyword("END ");
				IF (x.pointerType # NIL) & (x.pointerType.typeDeclaration # NIL) THEN
					Identifier(x.pointerType.typeDeclaration.name);
				END;
			ELSE
				Keyword("RECORD ");
				IF (x.baseType # NIL) THEN
					w.String( "(" );
					IF (x.baseType IS SyntaxTree.RecordType) & (x.baseType(SyntaxTree.RecordType).pointerType # NIL) THEN
						Type(x.baseType(SyntaxTree.RecordType).pointerType)
					ELSE
						Type(x.baseType);
					END;
					w.String( ")" );
				END;
				prevScope := currentScope;
				currentScope := x.recordScope;
				VariableList(x.recordScope.firstVariable);
				IF x.recordScope.procedures # NIL THEN w.Ln; ProcedureList(x.recordScope.procedures) END;
				currentScope := prevScope;
				Indent; Keyword("END" );
				IF (x.pointerType = NIL) & (x.recordScope.procedures # NIL) THEN w.Ln; ProcedureList(x.recordScope.procedures) END;
			END;
		END VisitRecordType;

		PROCEDURE Flag(identifier: SyntaxTree.Identifier; VAR first: BOOLEAN);
		VAR name: SyntaxTree.IdentifierString;
		BEGIN
			IF first THEN w.String("{") ELSE w.String(", ") END;
			first := FALSE;
			Basic.GetString(identifier,name);
			w.String(name);
		END Flag;

		PROCEDURE FlagEnd(first: BOOLEAN);
		BEGIN
			IF ~first THEN w.String("} ") END;
		END FlagEnd;

		PROCEDURE Value(identifier: SyntaxTree.Identifier; value: HUGEINT; VAR first: BOOLEAN);
		BEGIN
			Flag(identifier,first);
			w.String("("); w.Int(value,1); w.String(")");
		END Value;

		PROCEDURE VisitProcedureType*(x: SyntaxTree.ProcedureType);
		VAR first: BOOLEAN;
		BEGIN
			Keyword("PROCEDURE " );
			first := TRUE;
			IF x.isDelegate THEN Flag(Global.NameDelegate,first) END;
			IF x.isInterrupt THEN Flag(Global.NameInterrupt,first) END;
			IF x.noPAF THEN Flag(Global.NameNoPAF,first) END;
			IF x.noReturn THEN Flag(Global.NameNoReturn,first) END;
			IF x.callingConvention = SyntaxTree.WinAPICallingConvention THEN
				Flag(Global.NameWinAPI,first)
			ELSIF x.callingConvention = SyntaxTree.CCallingConvention THEN
				Flag(Global.NameC,first)
			ELSIF x.callingConvention = SyntaxTree.PlatformCallingConvention THEN
				Flag(Global.NamePlatformCC,first)
			END;
			IF x.stackAlignment > 1 THEN Value(Global.NameStackAligned,x.stackAlignment,first) END;
			IF ~first THEN w.String("}") END;

			IF (x.modifiers # NIL) & info THEN
				BeginComment;
				Modifiers(x.modifiers);
				EndComment;
			END;
			(*
			CallingConvention(x.callingConvention);
			IF x.isDelegate THEN w.String("{DELEGATE}") END;
			*)
			IF (x.firstParameter # NIL) OR (x.returnType # NIL) THEN
				ParameterList(x.firstParameter)
			END;
			IF x.returnType # NIL THEN
				w.String( ":" );
				IF x.hasUntracedReturn THEN
						first := TRUE;
						Flag(Global.NameUntraced, first);
						FlagEnd(first);
				END;
				Type(x.returnType)
			END;
			IF info & (x.returnParameter # NIL) THEN
				BeginComment;
				VisitParameter(x.returnParameter);
				EndComment;
			END;

		END VisitProcedureType;

		(*** expressions ****)

		PROCEDURE ExpressionList(x: SyntaxTree.ExpressionList);
		VAR i: SIZE;  expression: SyntaxTree.Expression;
		BEGIN
			FOR i := 0 TO x.Length() - 1 DO
				expression := x.GetExpression( i );  Expression(expression);
				IF i < x.Length() - 1 THEN w.String( ", " );  END;
			END;
		END ExpressionList;

		PROCEDURE Expression*(x: SyntaxTree.Expression);
		BEGIN
			IF DebugPosition THEN TRACE(x.position.start, x.position.end, x.end.start, x.end.end) END;
			IF x = NIL THEN
				AlertString("nil expression");
			ELSE
				VExpression(x);
				IF info & (x.resolved # NIL) & (x.resolved # x) THEN
					BeginComment; w.String("value = "); Expression(x.resolved); EndComment;
				END;
			END;
			w.Update;
		END Expression;

		PROCEDURE VisitExpression*(x: SyntaxTree.Expression);
		BEGIN
			AlertString("InvalidExpression");
		END VisitExpression;

		PROCEDURE VisitSet*(x: SyntaxTree.Set);
		BEGIN
			w.String( "{" );  ExpressionList(x.elements); w.String( "}" );
		END VisitSet;

		PROCEDURE VisitMathArrayExpression*(x: SyntaxTree.MathArrayExpression);
		BEGIN
			w.String( "[" );  ExpressionList(x.elements); w.String( "]" );
		END VisitMathArrayExpression;

		PROCEDURE VisitUnaryExpression*(x: SyntaxTree.UnaryExpression);
		VAR identifier: SyntaxTree.Identifier;
		BEGIN
			w.String(" ");
			IF x.operator = Scanner.Transpose THEN
				identifier := Global.GetIdentifier(x.operator,case);
				Expression(x.left);
				Identifier(identifier);
			ELSIF (x.operator = Scanner.Address) OR (x.operator = Scanner.Size) OR (x.operator = Scanner.Alias) THEN
				identifier := Global.GetIdentifier(x.operator,case);
				Identifier(identifier);
				Keyword(" OF ");
				Expression(x.left);
			ELSE
				identifier := Global.GetIdentifier(x.operator,case);
				Identifier(identifier);
				Expression(x.left);
			END;
		END VisitUnaryExpression;

		PROCEDURE VisitBinaryExpression*(x: SyntaxTree.BinaryExpression);
		VAR identifier: SyntaxTree.Identifier;
		BEGIN
			w.String( "(" );
			Expression(x.left);
			identifier := Global.GetIdentifier(x.operator,case);
			w.String(" "); Identifier(identifier); w.String(" ");
			Expression(x.right);
			w.String(")");
		END VisitBinaryExpression;

		PROCEDURE VisitRangeExpression*(x: SyntaxTree.RangeExpression);
		BEGIN
			IF x.missingFirst & x.missingLast & x.missingStep THEN
				(* open range expression *)
				(* the surrounding spaces prevent the asterisk from being next to a parenthesis,
				which could be confused with the beginning or end of a comment *)
				w.String(" * ")

			ELSE
				IF ~x.missingFirst THEN Expression(x.first) END;
				w.String(" .. ");
				IF ~x.missingLast THEN Expression(x.last) END;
				IF ~x.missingStep THEN
					Keyword(" BY ");
					Expression(x.step)
				END
			END;

			IF info THEN
				BeginComment;
				w.String("<RangeExpression:");
				ShortType(x.type);
				w.String(">");
				EndComment
			END
		END VisitRangeExpression;

		PROCEDURE VisitTensorRangeExpression*(x: SyntaxTree.TensorRangeExpression);
		BEGIN
			w.String(" ? ");
		END VisitTensorRangeExpression;

		PROCEDURE VisitConversion*(x: SyntaxTree.Conversion);
		BEGIN
			IF x.typeExpression # NIL THEN Expression(x.typeExpression); w.String("(");
			ELSIF info THEN BeginComment; ShortType(x.type); w.String("<-"); EndComment;
			END;
			Expression(x.expression);
			IF x.typeExpression # NIL THEN w.String(")") END;
		END VisitConversion;

		PROCEDURE VisitDesignator*(x: SyntaxTree.Designator);
		BEGIN
			AlertString("InvalidDesignator");
		END VisitDesignator;

		PROCEDURE VisitIdentifierDesignator*(x: SyntaxTree.IdentifierDesignator);
		BEGIN
			IF info THEN AlertString("(*<IdentifierDesignator>*)") END;
			Identifier(x.identifier)
		END VisitIdentifierDesignator;

		PROCEDURE VisitSelectorDesignator*(x: SyntaxTree.SelectorDesignator);
		BEGIN
			Expression(x.left);
			w.String(".");
			IF info THEN AlertString("(*<SelectorDesignator>*)") END;
			Identifier(x.identifier);
		END VisitSelectorDesignator;

		PROCEDURE VisitBracketDesignator*(x: SyntaxTree.BracketDesignator);
		BEGIN
			Expression(x.left);
			IF info THEN AlertString("(*<BracketDesignator>*)") END;
			w.String("["); ExpressionList(x.parameters); w.String("]");
		END VisitBracketDesignator;

		PROCEDURE VisitParameterDesignator*(x: SyntaxTree.ParameterDesignator);
		BEGIN
			Expression(x.left);
			IF info THEN AlertString("(*<ParameterDesignator>*)") END;
			w.String("("); ExpressionList(x.parameters); w.String(")");
		END VisitParameterDesignator;

		PROCEDURE VisitIndexDesignator*(x: SyntaxTree.IndexDesignator);
		BEGIN
			Expression(x.left);
			w.String("["); ExpressionList(x.parameters); w.String("]");
			IF info THEN
				BeginComment;
				w.String("<IndexDesignator:");
				ShortType(x.type);
				w.String(">");
				EndComment
			END;
		END VisitIndexDesignator;

		PROCEDURE VisitArrowDesignator*(x: SyntaxTree.ArrowDesignator);
		BEGIN
			Expression(x.left);
			IF info THEN AlertString("(*<ArrowDesignator>*)") END;
			w.String( "^" );
		END VisitArrowDesignator;

		PROCEDURE ShortType(x: SyntaxTree.Type); (* for debug information, to prevent recursion *)
		BEGIN
			IF x = NIL THEN w.String("NIL TYPE")
			ELSIF x IS SyntaxTree.QualifiedType THEN Type(x)
			ELSIF x IS SyntaxTree.BasicType THEN Type(x)
			ELSIF x IS SyntaxTree.ProcedureType THEN w.String("ProcedureType:");ShortType(x(SyntaxTree.ProcedureType).returnType);
			ELSE w.String("(other)") END;
		END ShortType;

		PROCEDURE VisitSymbolDesignator*(x: SyntaxTree.SymbolDesignator);
		BEGIN
			IF (x.left # NIL) & ~x.left.isHidden THEN
			Expression(x.left); w.String(".");
			END;
			IF x.symbol IS SyntaxTree.Operator THEN
				w.String('"'); Identifier(x.symbol.name); w.String('"');
			ELSE
				useCase :=
					(x.symbol IS SyntaxTree.Builtin)
					OR ((x.symbol IS SyntaxTree.TypeDeclaration) & (x.symbol(SyntaxTree.TypeDeclaration).declaredType IS SyntaxTree.BasicType))
					OR (x.symbol IS SyntaxTree.Module) & ((x.symbol.name = Global.systemName) OR (x.symbol.name = Global.SystemName));
				Identifier(x.symbol.name);
				useCase := FALSE;
			END;
			IF info THEN
				BeginComment;
				w.String("<SymbolDesignator:");
				ShortType(x.symbol.type);
				w.String(">");
				EndComment
			END;
		END VisitSymbolDesignator;

		PROCEDURE VisitSupercallDesignator*(x: SyntaxTree.SupercallDesignator);
		BEGIN
			Expression(x.left);
			w.String( "^" );
			IF info THEN
				BeginComment;
				w.String("<SupercallDesignator:");
				ShortType(x.type);
				w.String(">");
				EndComment
			END;
		END VisitSupercallDesignator;

		PROCEDURE VisitSelfDesignator*(x: SyntaxTree.SelfDesignator);
		BEGIN
			ASSERT(x.left = NIL);
			IF case = Scanner.Lowercase THEN w.String("self"); ELSE w.String("SELF"); END;
			IF info THEN
				BeginComment;
				w.String("<SelfDesignator:");
				ShortType(x.type);
				w.String(">");
				EndComment
			END;

		END VisitSelfDesignator;

		PROCEDURE VisitResultDesignator*(x: SyntaxTree.ResultDesignator);
		BEGIN
			ASSERT(x.left = NIL);
			w.String("RESULT");
			IF info THEN
				BeginComment;
				w.String("<ResultDesignator:");
				ShortType(x.type);
				w.String(">");
				EndComment
			END;
		END VisitResultDesignator;

		PROCEDURE VisitDereferenceDesignator*(x: SyntaxTree.DereferenceDesignator);
		BEGIN
			Expression(x.left);
			w.String( "^" );
			IF info THEN
				BeginComment;
				w.String("<DereferenceDesignator:");
				ShortType(x.type);
				w.String(">");
				EndComment
			END;
		END VisitDereferenceDesignator;

		PROCEDURE VisitTypeGuardDesignator*(x: SyntaxTree.TypeGuardDesignator);
		BEGIN
			Expression(x.left);
			IF info THEN
				BeginComment;
				w.String("<TypeGuardDesignator:");
				ShortType(x.type);
				w.String(">");
				EndComment
			END;
			w.String("(");
			IF x.typeExpression # NIL THEN Expression(x.typeExpression) ELSE Type(x.type) END;
			w.String(")");
		END VisitTypeGuardDesignator;

		PROCEDURE VisitProcedureCallDesignator*(x: SyntaxTree.ProcedureCallDesignator);
		BEGIN
			Expression(x.left);
			IF info THEN
				BeginComment;
				w.String("<ProcedureCallDesignator:");
				ShortType(x.type);
				w.String(">");
				EndComment
			END;
			w.String("("); ExpressionList(x.parameters); w.String(")");
		END VisitProcedureCallDesignator;

		PROCEDURE VisitInlineCallDesignator*(x: SyntaxTree.InlineCallDesignator);
		BEGIN
			Scope(x.block.scope);
			VisitStatementBlock(x.block);
		END VisitInlineCallDesignator;

		PROCEDURE VisitBuiltinCallDesignator*(x: SyntaxTree.BuiltinCallDesignator);
		BEGIN
			IF x.left # NIL THEN
				Expression(x.left);
			ELSE
				w.String("BUILTIN(");
				w.Int(x.id,1);
				w.String(")");
			END;
			IF info THEN
				BeginComment;
				w.String("<BuiltinCallDesignator:");
				ShortType(x.type);
				w.String(">");
				EndComment
			END;
			w.String("("); ExpressionList(x.parameters); w.String(")");
		END VisitBuiltinCallDesignator;

		PROCEDURE VisitValue*(x: SyntaxTree.Value);
		BEGIN
			AlertString("InvalidValue");
		END VisitValue;

		PROCEDURE VisitBooleanValue*(x: SyntaxTree.BooleanValue);
		BEGIN
			IF Scanner.Uppercase = case THEN
				IF x.value THEN w.String("TRUE" ) ELSE w.String( "FALSE" ) END
			ELSE
				IF x.value THEN w.String("true" ) ELSE w.String( "false" ) END
			END
		END VisitBooleanValue;

		PROCEDURE Hex(x: HUGEINT);
		VAR i: LONGINT; a: ARRAY 20 OF CHAR; y: HUGEINT;
		BEGIN
			i := 0;
			REPEAT
				y := x MOD 10H;
				IF y < 10 THEN a[i] := CHR(y+ORD('0'))
				ELSE a[i] := CHR(y-10+ORD('A'))
				END;
				x := x DIV 10H;
				INC(i);
			UNTIL (x=0) OR (i=16);
			IF y >=10 THEN w.Char("0") END;
			REPEAT DEC( i ); w.Char( a[i] ) UNTIL i = 0
		END Hex;

		PROCEDURE VisitIntegerValue*(x: SyntaxTree.IntegerValue);
		BEGIN
			w.Int(x.value,1);
		END VisitIntegerValue;

		PROCEDURE VisitCharacterValue*(x: SyntaxTree.CharacterValue);
		BEGIN
			Hex( ORD(x.value));  w.String( "X" );
		END VisitCharacterValue;

		PROCEDURE VisitSetValue*(x: SyntaxTree.SetValue);
		VAR i: LONGINT;
		BEGIN
			w.String("{");
			i := 0;
			WHILE (i<MAX(Basic.Set)) & ~(i IN x.value)  DO
				INC(i);
			END;
			IF i<MAX(Basic.Set) THEN
				w.Int(i,1);
				INC(i);
				WHILE i < MAX(Basic.Set) DO
					IF i IN x.value THEN w.String(","); w.Int(i,1); END;
					INC(i)
				END
			END;
			w.String("}");
		END VisitSetValue;

		PROCEDURE VisitMathArrayValue*(x: SyntaxTree.MathArrayValue);
		BEGIN
			VisitMathArrayExpression(x.array);
		END VisitMathArrayValue;

		PROCEDURE FormatedFloat(value: LONGREAL; subtype: LONGINT);
		VAR string: ARRAY 128 OF CHAR; i: LONGINT;
		BEGIN
			IF subtype = Scanner.Real THEN
				ws.SetPos(0); ws.Float(value,11(*mantissa X.XXXXXXX *)+5(*exponent E+XXX *)); ws.Get(string);
				i := 0;
				WHILE(i<LEN(string)) & (string[i] # 0X) DO
					IF string[i] = "D" THEN string[i] := "E" END;
					INC(i);
				END;
				w.String(string);
			ELSIF subtype = Scanner.Longreal THEN
				ws.SetPos(0); ws.Float(value,20(*mantissa X.X..(16)..X *)+5(*exponent E+XXX *) ); ws.Get(string);
				i := 0;
				WHILE(i<LEN(string)) & (string[i] # 0X) DO
					IF string[i] = "E" THEN string[i] := "D" END;
					INC(i);
				END;
				w.String(string);
			ELSE
				w.Float(value,31)
			END;
		END FormatedFloat;

		PROCEDURE VisitRealValue*(x: SyntaxTree.RealValue);
		BEGIN FormatedFloat(x.value, x.subtype)
		END VisitRealValue;

		PROCEDURE VisitComplexValue*(x: SyntaxTree.ComplexValue);
		BEGIN
			IF (x.realValue = 0) & (x.imagValue = 1) THEN
				w.String("IMAG")
			ELSE
				w.String("(");
				FormatedFloat(x.realValue, x.subtype)	;
				w.String(" ");
				IF x.imagValue > 0 THEN w.String("+") END;
				FormatedFloat(x.imagValue, x.subtype);
				w.String("*IMAG)")
			END
		END VisitComplexValue;

		PROCEDURE VisitStringValue*(x: SyntaxTree.StringValue);
		VAR i: LONGINT; ch: CHAR;
		BEGIN
			i := 0;
			w.Char('\');
			w.Char('"');
			WHILE (i < LEN( x.value )) & (x.value[i] # 0X) DO
				ch := x.value[i];
				IF ch = Scanner.CR THEN w.String("\n")
				ELSIF ch = Scanner.LF THEN (* ignore *)
				ELSIF ch = Scanner.TAB THEN w.String("\t")
				ELSIF ch = '\' THEN w.String("\\")
				ELSIF ch = '"' THEN w.String(\"""\); (* " *)
				ELSE w.Char(ch)
				END;
				INC( i );
			END;
			w.Char('"');
			w.Char('\');
		END VisitStringValue;

		PROCEDURE VisitNilValue*(x: SyntaxTree.NilValue);
		BEGIN IF case = Scanner.Lowercase THEN w.String( "nil" ); ELSE w.String( "NIL" ); END; IF info THEN BeginComment; Type(x.type); EndComment; END;
		END VisitNilValue;

		PROCEDURE VisitEnumerationValue*(x: SyntaxTree.EnumerationValue);
		BEGIN w.Int(x.value,1);
		END VisitEnumerationValue;

		PROCEDURE VisitProcedureValue*(x: SyntaxTree.ProcedureValue);
		BEGIN
			Symbol(x.value);
		END VisitProcedureValue;

		(**** symbols ****)

		PROCEDURE Symbol*(x: SyntaxTree.Symbol);
		BEGIN
			IF x = NIL THEN
				AlertString("nil symbol");
			ELSE
				VSymbol(x);
			END
		END Symbol;

		PROCEDURE VisitSymbol*(x: SyntaxTree.Symbol);
		BEGIN
			AlertString("InvalidSymbol");
		END VisitSymbol;

		PROCEDURE Visible(symbol: SyntaxTree.Symbol): BOOLEAN;
		BEGIN
			RETURN TRUE (* (SyntaxTree.Public * symbol.access # {}) OR (mode > SymbolFile) *)
				(* using only exported symbols does not work since there might be dependencies ... *)
		END Visible;

		PROCEDURE PrintSymbol(x: SyntaxTree.Symbol);
		BEGIN
			IF x IS SyntaxTree.Operator THEN
				w.String('"');Identifier(x.name);  w.String('"')
			ELSE
				Identifier(x.name)
			END;

			IF SyntaxTree.PublicWrite IN x.access THEN w.String( "*" )
			ELSIF SyntaxTree.PublicRead IN x.access THEN w.String( "-" )
			ELSIF x.access = {} THEN ASSERT(mode > SourceCode);
				IF info THEN BeginComment; w.String("<- hidden"); EndComment  END;
			END;

			IF x.externalName # NIL THEN
				Keyword(" EXTERN " ); w.Char('"');
				w.String(x.externalName^); w.Char('"');
			END;

			IF info THEN
				BeginComment;
				IF x.offsetInBits # MIN(SIZE) THEN
					w.String("@ofs="); w.Int(x.offsetInBits DIV 8,1);
				ELSE
					IF x.type # NIL THEN
						IF x.type.resolved.alignmentInBits #0 THEN
							w.String("@align="); w.Int(x.type.resolved.alignmentInBits DIV 8,1);
						END;
					END;
				END;
				EndComment;
			END;
		END PrintSymbol;

		PROCEDURE VisitTypeDeclaration*(x: SyntaxTree.TypeDeclaration);
		BEGIN
			IF Visible(x) THEN
				IF (x.access # SyntaxTree.Hidden) OR (mode > SourceCode) THEN
					Comments(x.comment,x,FALSE);
					PrintSymbol(x);
					w.String(" = ");
					IF x.access # SyntaxTree.Hidden THEN
						Type(x.declaredType);
					ELSE ShortType(x.declaredType)
					END;
					Comments(x.comment,x,TRUE);
				END;
			END;
		END VisitTypeDeclaration;

		PROCEDURE TypeDeclarationList(x: SyntaxTree.TypeDeclaration);
		BEGIN
			Indent;
			Keyword("TYPE " );
			w.IncIndent;
			WHILE(x # NIL) DO
				Indent;
				Symbol(x);
				w.String( "; " );
				x := x.nextTypeDeclaration;
				IF x # NIL THEN w.Ln END;
			END;
			w.DecIndent;
		END TypeDeclarationList;

		PROCEDURE VisitConstant*(x: SyntaxTree.Constant);
		BEGIN
			IF Visible(x) THEN
				IF (mode > SourceCode) OR (x.access # SyntaxTree.Hidden) THEN
					Comments(x.comment,x,FALSE);
					PrintSymbol(x);
					IF x.value # NIL THEN
						w.String( " = " );  Expression(x.value);
					END;
					IF info THEN BeginComment; ShortType(x.type); EndComment; END;
					IF info & (x.value.resolved = NIL) THEN AlertString("(*NOT A CONSTANT*)") END;
					Comments(x.comment,x,TRUE);
				END;
			END;
		END VisitConstant;

		PROCEDURE ConstantList(x: SyntaxTree.Constant);
		BEGIN
			Indent;  Keyword("CONST " );
			w.IncIndent;
			WHILE(x # NIL) DO
				IF (x.access # SyntaxTree.Hidden) OR (mode > SourceCode) THEN
					Indent;
					Symbol(x);
					w.String( "; " );
				END;
				x := x.nextConstant;
			END;
			w.DecIndent;
		END ConstantList;

		PROCEDURE VisitVariable*(x: SyntaxTree.Variable);
		BEGIN
			IF Visible(x) THEN
				IF (x.access # SyntaxTree.Hidden) THEN
					Comments(x.comment,x,FALSE);
					PrintSymbol(x);
					IF x.modifiers # NIL THEN w.String(" "); Modifiers(x.modifiers); END;

					IF x.initializer # NIL THEN
						w.String( " := " ); Expression (x.initializer);
					END;
					w.String( ": " );
					Type(x.type);
					Comments(x.comment,x,TRUE);
				ELSIF mode>SourceCode THEN
					Comments(x.comment,x,FALSE);
					PrintSymbol(x);
					IF x.initializer # NIL THEN
						w.String( " := " ); Expression (x.initializer);
					END;
					Comments(x.comment,x,TRUE);
				END
			END;
		END VisitVariable;

		PROCEDURE VariableList(x: SyntaxTree.Variable);
		VAR next: SyntaxTree.Variable;

			PROCEDURE Flags(x: SyntaxTree.Variable);
			VAR first: BOOLEAN;
			BEGIN
				first := TRUE;
				IF x.fixed THEN
					Value(Global.NameFixed,x.alignment,first)
				ELSIF x.alignment > 1 THEN
					Value(Global.NameAligned,x.alignment,first)
				ELSIF x.fictive THEN
					Value(Global.NameFictive, x.fictiveOffset, first);
				ELSIF x.preferRegister THEN
					Flag(Global.NameRegister,first);
				END;
				IF x.untraced THEN
					Flag(Global.NameUntraced,first)
				END;
				FlagEnd(first);
			END Flags;

		BEGIN
			w.IncIndent;
			WHILE(x # NIL) DO
				next := x.nextVariable;
				IF (x.access # SyntaxTree.Hidden) OR (mode > SourceCode) THEN
					Indent;
					Comments(x.comment, x, FALSE);
					PrintSymbol(x); Flags(x);
					IF x.initializer # NIL THEN
						w.String( " := " ); Expression (x.initializer);
					END;
					WHILE(next # NIL) & (next.type = x.type) & ((next.access # SyntaxTree.Hidden) OR (mode > SourceCode)) DO

						w.String(", "); PrintSymbol(next); Flags(next);
						next := next.nextVariable;
					END;
					IF x.access # SyntaxTree.Hidden THEN
						w.String(": ");
						Type(x.type);
					ELSE
						w.String(": ");
						ShortType(x.type);
					END;
					w.String("; ");
					Comments(x.comment,x, TRUE);
				END;
				x := next;
			END;
			w.DecIndent
		END VariableList;

		PROCEDURE AliasList(x: SyntaxTree.Alias);
		VAR next: SyntaxTree.Alias;
		BEGIN
			w.IncIndent;
			WHILE(x # NIL) DO
				next := x.nextAlias;
				IF (x.access # SyntaxTree.Hidden) OR (mode > SourceCode) THEN
					Indent;
					Comments(x.comment, x, FALSE);
					PrintSymbol(x);
					IF x.expression # NIL THEN
						w.String( " := " ); Expression (x.expression);
					END;
					IF x.access # SyntaxTree.Hidden THEN
						w.String(": ");
						Type(x.type);
					ELSE
						w.String(": ");
						ShortType(x.type);
					END;
					w.String("; ");
				END;
				x := next;
			END;
			w.DecIndent
		END AliasList;

		PROCEDURE VisitParameter*(x: SyntaxTree.Parameter);
		BEGIN
			IF (x.access # SyntaxTree.Hidden) THEN
				Comments(x.comment,x,TRUE);
				IF x.kind = SyntaxTree.VarParameter THEN Keyword("VAR " );
				ELSIF x.kind = SyntaxTree.ConstParameter THEN Keyword("CONST " );
				END;
				PrintSymbol(x);
				IF x.modifiers # NIL THEN w.String(" "); Modifiers(x.modifiers); END;

				IF x.defaultValue # NIL THEN
					w.String("= "); Expression(x.defaultValue);
				END;
				w.String( ": " );
				Type(x.type);
				Comments(x.comment,x,TRUE);
			ELSIF (mode > SourceCode) THEN
				Comments(x.comment,x,FALSE);
				PrintSymbol(x);
				Comments(x.comment,x,TRUE);
			END;
		END VisitParameter;

		PROCEDURE ParameterList*(x: SyntaxTree.Parameter);
		VAR next: SyntaxTree.Parameter; first: BOOLEAN;

			PROCEDURE Flags(x: SyntaxTree.Parameter);
			VAR first: BOOLEAN;
			BEGIN
				IF x.modifiers # NIL THEN
					Modifiers(x.modifiers)
				ELSE
					first := TRUE;
					IF x.untraced THEN
						Flag(Global.NameUntraced,first)
					END;

					FlagEnd(first);
				END;
			END Flags;

		BEGIN
			first := TRUE;
			w.String( "(" );
			WHILE(x # NIL) DO
				next := x.nextParameter;
				IF (x.access # SyntaxTree.Hidden) OR (mode > SourceCode) THEN
					IF ~first THEN w.String("; ") END;
					first := FALSE;
					IF x.kind = SyntaxTree.VarParameter THEN Keyword("VAR " );
					ELSIF x.kind = SyntaxTree.ConstParameter THEN Keyword("CONST " );
					END;
					PrintSymbol(x); Flags(x);
					IF x.defaultValue # NIL THEN
						w.String("= "); Expression(x.defaultValue);
					END;

					WHILE (next # NIL) & (next.type = x.type) & (next.kind = x.kind) & ((next.access # SyntaxTree.Hidden) OR (mode > SourceCode)) DO
						w.String(", ");
						PrintSymbol(next); Flags(next);
						IF next.defaultValue # NIL THEN
							w.String("= "); Expression(next.defaultValue);
						END;
						next := next.nextParameter;
					END;
					IF x.access # SyntaxTree.Hidden THEN
						w.String(": ");
						Type(x.type);
					ELSE
						w.String(": ");
						ShortType(x.type);
					END;
				END;
				x := next;
			END;
			w.String( ")" );
		END ParameterList;

		PROCEDURE Access(access: SET);
		BEGIN
			IF SyntaxTree.PublicWrite IN access THEN w.String(" PublicWrite") END;
			IF SyntaxTree.ProtectedWrite IN access THEN w.String(" ProtectedWrite") END;
			IF SyntaxTree.InternalWrite IN access THEN w.String(" InternalWrite") END;
			IF SyntaxTree.PublicRead IN access THEN w.String(" PublicRead") END;
			IF SyntaxTree.ProtectedRead IN access THEN w.String(" ProtectedRead") END;
			IF SyntaxTree.InternalRead IN access THEN w.String(" InternalRead") END;
		END Access;

		PROCEDURE VisitProcedure*(x: SyntaxTree.Procedure);
		VAR type: SyntaxTree.ProcedureType;  first: BOOLEAN; fp: SyntaxTree.Fingerprint;
		BEGIN
			IF Visible(x) THEN

				Indent;
				Comments(x.comment,x,FALSE);
				Keyword("PROCEDURE " );
				IF (mode = SymbolFile) & ~x.isInline & ~x.isOberonInline THEN
					w.String("^ ");
				END;

				type := x.type(SyntaxTree.ProcedureType);

				first := TRUE;
				IF type.stackAlignment > 1 THEN Value(Global.NameStackAligned,type.stackAlignment,first) END;
				IF (type.isRealtime) THEN Flag(Global.NameRealtime,first) END;
				IF (type.noReturn) THEN Flag(Global.NameNoReturn,first) END;
				IF (x.isAbstract) THEN Flag(Global.NameAbstract,first) END;
				IF (x.isFinal) THEN Flag(Global.NameFinal,first) END;
				IF (x.fixed) THEN Value(Global.NameFixed, x.alignment,first)
				ELSIF (x.alignment >1) THEN Value(Global.NameAligned, x.alignment, first)
				END;
				IF type.callingConvention = SyntaxTree.WinAPICallingConvention THEN
					Flag(Global.NameWinAPI,first)
				ELSIF type.callingConvention = SyntaxTree.CCallingConvention THEN
					Flag(Global.NameC,first)
				ELSIF type.callingConvention = SyntaxTree.PlatformCallingConvention THEN
					Flag(Global.NamePlatformCC,first)
				END;

				IF x.isInline & (mode = SymbolFile) THEN
					IF fingerprinter = NIL THEN NEW(fingerprinter) END;
					fp := fingerprinter.SymbolFP(x);
					Value(Global.NameFingerprint, fp.public, first)
				END;
				FlagEnd(first);

				IF x.isInline OR x.isOberonInline THEN w.String(" - ") END;
				IF x.isConstructor THEN w.String(" & ") END;
				IF x.isFinalizer THEN w.String(" ~ ") END;

				IF (type.selfParameter # NIL) & ~(type.selfParameter.name = "@Self") THEN
					ParameterList(type.selfParameter);
				END;

				IF info THEN
					BeginComment;
					Modifiers(x.type(SyntaxTree.ProcedureType).modifiers);
					EndComment;
				END;

				PrintSymbol(x);
				IF (type.firstParameter # NIL)  OR (type.returnType # NIL ) THEN  (* print parentheses only if not parameterless procedure *)
					ParameterList(type.firstParameter);
				END;
				IF type.returnType # NIL THEN
					w.String( ": " );
					IF type.hasUntracedReturn THEN
						first := TRUE;
						Flag(Global.NameUntraced, first);
						FlagEnd(first);
					END;
					Type(type.returnType);
				END;
				IF info & (type.returnParameter # NIL) THEN
					BeginComment;
					w.String("retPar = ");
					Symbol(type.returnParameter);
					EndComment;
				END;
				IF x.externalName = NIL THEN
					IF (mode > SymbolFile) OR (mode = SymbolFile) & (x.isInline OR x.isOberonInline) THEN
						w.String( ";" );
						Comments(x.comment,x,TRUE);
						IF (mode >= SymbolFile) OR x.isOberonInline THEN
							ProcedureScope(x.procedureScope);
						END;
						Indent;  Keyword("END " );  Identifier(x.name);
					END;
				END;
			END;
		END VisitProcedure;

		PROCEDURE VisitOperator*(x: SyntaxTree.Operator);
		VAR type: SyntaxTree.ProcedureType;
			first: BOOLEAN;
		BEGIN
			IF Visible(x) THEN
				Indent;
				Comments(x.comment,x,FALSE);
				Keyword("OPERATOR ");

				first := TRUE;
				IF x.isInline  OR x.isOberonInline THEN
					ASSERT(~x.isDynamic);
					w.String("-");
				ELSE
					IF mode = SymbolFile THEN w.String("^ ") END;
					IF x.isDynamic THEN Flag(Global.NameDynamic, first) END;
					IF ~first THEN w.String("}") END;
				END;

				type := x.type(SyntaxTree.ProcedureType);
				PrintSymbol(x);

				ParameterList(type.firstParameter);
				IF type.returnType # NIL THEN
					w.String( ": " );
					IF type.hasUntracedReturn THEN
						first := TRUE;
						Flag(Global.NameUntraced, first);
						FlagEnd(first);
					END;
					Type(type.returnType);
				END;
				IF info & (type.returnParameter # NIL) THEN
					BeginComment;
					(*w.String("retPar = ");*) (*! this is present in VisitProcedure - should it be present here as well??? *)
					Symbol(type.returnParameter);
					EndComment;
				END;

				IF x.externalName = NIL THEN
					IF (mode > SymbolFile) OR (mode = SymbolFile) & (x.isInline OR x.isOberonInline) THEN
						w.String( ";" );
						Comments(x.comment,x,TRUE);
						IF mode >= SymbolFile THEN
							ProcedureScope(x.procedureScope);
						END;
						Indent; Keyword("END " ); w.String( '"' ); Identifier(x.name); w.String( '"' );
					END;
				END;
			END
		END VisitOperator;

		PROCEDURE ProcedureList(list: SyntaxTree.ProcedureList);
		VAR x: SyntaxTree.Procedure; i: SIZE; type: SyntaxTree.ProcedureType;
		BEGIN
			w.IncIndent;
			FOR i := 0 TO list.Length()-1 DO
				x := list.GetProcedure(i);
				IF (x.access # SyntaxTree.Hidden) & ~(x.isBodyProcedure) OR (mode > SourceCode)
				THEN
					type := x.type(SyntaxTree.ProcedureType);
					IF (type.selfParameter = NIL) OR (type.selfParameter.name = "@Self") & (currentScope IS SyntaxTree.RecordScope)
						OR ~ (type.selfParameter.name = "@Self") & ~(currentScope IS SyntaxTree.RecordScope)
					THEN
						Symbol(x);
						w.String( "; " );
					END;
				END;
				IF (i# list.Length()-1) & (mode > SymbolFile) & ((x.access # SyntaxTree.Hidden) OR (mode > SourceCode)) THEN w.Ln END;
			END;
			w.DecIndent;
		END ProcedureList;

		PROCEDURE VisitImport*(x: SyntaxTree.Import);
		VAR context: SyntaxTree.Identifier; i: SIZE;
		BEGIN
			IF x.moduleName # x.name THEN Identifier(x.name);  w.String( " := " );  END;
			IF (x.scope = NIL) OR (x.scope.ownerModule = NIL) THEN context := SyntaxTree.invalidIdentifier ELSE context := x.scope.ownerModule.context END;
			Identifier(x.moduleName);
			IF x.parameters # NIL THEN
				w.String("(");
				FOR i := 0 TO x.parameters.Length()-1 DO
					Expression(x.parameters.GetExpression(i));
					IF i < x.parameters.Length()-1 THEN
						w.String(",");
					END;
				END;
				w.String(")");
			END;
			IF (x.context # SyntaxTree.invalidIdentifier) & (x.context#context) THEN
				Keyword(" IN ");
				Identifier(x.context)
			END;
		END VisitImport;

		PROCEDURE ImportList(x: SyntaxTree.Import);
		VAR first: BOOLEAN;
		BEGIN
			first := TRUE;
			WHILE(x # NIL) DO
				IF x.direct & (x.module # NIL) OR (mode > SymbolFile) THEN
					IF ~first THEN w.String(", ") ELSE Indent; Keyword("IMPORT "); first := FALSE END;
					Symbol(x);
				END;
				x := x.nextImport;
			END;
			IF ~first THEN w.String( ";" ); END;
		END ImportList;

		PROCEDURE VisitBuiltin*(x: SyntaxTree.Builtin);
		BEGIN
			Indent; Keyword("BUILTIN ");
			Identifier(x.name);
		END VisitBuiltin;

		PROCEDURE BuiltinList(x: SyntaxTree.Builtin);
		BEGIN
			WHILE(x # NIL) DO
				VisitBuiltin(x);
				x := x.nextBuiltin;
			END;
		END BuiltinList;

		PROCEDURE BeginComment;
		BEGIN
			w.BeginComment; w.String("(*");
		END BeginComment;

		PROCEDURE EndComment;
		BEGIN
			w.String("*)");w.EndComment
		END EndComment;

		PROCEDURE Comment(x: SyntaxTree.Comment);
		VAR i: LONGINT; ch: CHAR;
		BEGIN
			BeginComment;
			WHILE (i<LEN(x.source^)) & (x.source[i] #  0X) DO
				ch := x.source[i];
				IF ch = 0DX THEN w.Ln
				ELSE w.Char(ch)
				END;
				INC(i);
			END;
			EndComment;
		END Comment;

		PROCEDURE Comments(c: SyntaxTree.Comment; x: ANY; sameLine: BOOLEAN);
		BEGIN
			IF mode >= SourceCode THEN
				WHILE (c # NIL) & (c.item = x) DO
					IF c.sameLine = sameLine THEN
						Comment(c);
						IF ~sameLine THEN
							Indent;
						END;
					END;
					c := c.nextComment;
				END;
			END;
		END Comments;

		PROCEDURE CommentList(x: SyntaxTree.Comment);
		BEGIN
			IF info THEN
				WHILE (x#NIL) DO
					Indent;
					w.String("comment at position "); w.Int(x.position.start,1);
					IF x.sameLine THEN w.String("(in line with item)") END;
					IF x.item = NIL THEN w.String("(no item)"); END;
					w.String(":");
					Comment(x);
					x := x.nextComment;
				END;
			END;
		END CommentList;

		(*** scopes ****)

		PROCEDURE Scope*(x: SyntaxTree.Scope);
		VAR prevScope: SyntaxTree.Scope;
		BEGIN
			prevScope := currentScope;
			currentScope := x;
			(* ASSERT(currentScope.outerScope = prevScope); (* sanity check *) *)
			WITH x: SyntaxTree.CellScope DO
				IF x.firstImport # NIL THEN ImportList(x.firstImport) END;
			ELSE
			END;
			IF x.firstConstant # NIL THEN ConstantList(x.firstConstant); END;
			IF x.firstTypeDeclaration # NIL THEN TypeDeclarationList(x.firstTypeDeclaration); END;
			IF x.firstVariable # NIL THEN Indent;  Keyword("VAR " );  VariableList(x.firstVariable);  END;
			IF x.firstAlias # NIL THEN Indent; Keyword("ALIAS "); AliasList(x.firstAlias) END;
			IF x.procedures # NIL THEN w.Ln; ProcedureList(x.procedures) END;
			currentScope := prevScope;
		END Scope;

		PROCEDURE ProcedureScope(x: SyntaxTree.ProcedureScope);
		VAR prevScope: SyntaxTree.Scope;
		BEGIN
			prevScope := currentScope;
			currentScope := x;
			IF (mode  >= SourceCode) OR (x.ownerProcedure.isInline) OR (x.ownerProcedure.isOberonInline) THEN
				Scope(x);
			END;
			IF (mode >= SymbolFile) & (x.body # NIL) THEN Body(x.body,  (mode  >= SourceCode) OR (x.ownerProcedure.isInline) OR (x.ownerProcedure.isOberonInline) ) END;
			currentScope := prevScope;
		END ProcedureScope;

		PROCEDURE Statement*(x: SyntaxTree.Statement);
		BEGIN
			IF x = NIL THEN
				AlertString("nil statement")
			ELSE
				Comments(x.comment, x, FALSE);
				IF DebugPosition THEN TRACE(x.position.start, x.position.end, x.end.start, x.end.end) END;
				VStatement(x);
				Comments(x.comment,x,TRUE);
			END
		END Statement;

		PROCEDURE StatementSequence*(x: SyntaxTree.StatementSequence);
		VAR statement: SyntaxTree.Statement;  i: SIZE;
		BEGIN
			IF singleStatement THEN
				w.String("...")
			ELSE
				FOR i := 0 TO x.Length() - 1 DO
					statement := x.GetStatement( i );
					Indent; Statement(statement);
					IF i < x.Length() - 1 THEN w.String( "; " );  END;
				END;
			END;
		END StatementSequence;

		PROCEDURE VisitStatement*(x: SyntaxTree.Statement);
		BEGIN
			AlertString("InvalidStatement");
		END VisitStatement;

		PROCEDURE VisitProcedureCallStatement*(x: SyntaxTree.ProcedureCallStatement);
		BEGIN
			IF x.ignore THEN Keyword("IGNORE " ) END;
			Expression(x.call);
		END VisitProcedureCallStatement;

		PROCEDURE VisitAssignment*(x: SyntaxTree.Assignment);
		BEGIN
			Expression(x.left); w.String( " := " );  Expression(x.right);
		END VisitAssignment;

		PROCEDURE VisitCommunicationStatement*(x: SyntaxTree.CommunicationStatement);
		VAR identifier: SyntaxTree.Identifier;
		BEGIN
			Expression(x.left);
			identifier := Global.GetIdentifier(x.op,case);
			w.String(" "); Identifier(identifier); w.String(" ");
			Expression(x.right);
		END VisitCommunicationStatement;

		PROCEDURE IfPart(x: SyntaxTree.IfPart);
		BEGIN
			IF DebugPosition THEN TRACE(x.position.start, x.position.end, x.end.start, x.end.end) END;
			Comments(x.comment, x, FALSE);
			Keyword("IF " );
			Expression(x.condition);
			Keyword(" THEN " );
			Comments(x.comment,x,TRUE);
			w.IncIndent;
			StatementSequence(x.statements);
			w.DecIndent;
		END IfPart;

		PROCEDURE VisitIfStatement*(x: SyntaxTree.IfStatement);
		VAR i: SIZE;  elsif: SyntaxTree.IfPart;
		BEGIN
			IfPart(x.ifPart);
			FOR i := 0 TO x.ElsifParts() - 1 DO
				elsif := x.GetElsifPart( i );
				Indent; Keyword("ELS");
				IfPart(elsif);
			END;
			IF x.elsePart # NIL THEN
				Indent;  Keyword("ELSE" );
				w.IncIndent;
				StatementSequence(x.elsePart);
				w.DecIndent;
			END;
			Indent;  Keyword("END" );
		END VisitIfStatement;

		PROCEDURE WithPart(x: SyntaxTree.WithPart);
		BEGIN
			Comments(x.comment, x, FALSE);
			Type(x.type);
			Keyword(" DO " );
			Comments(x.comment,x, TRUE);
			w.IncIndent;  StatementSequence(x.statements);  w.DecIndent;
		END WithPart;

		PROCEDURE VisitWithStatement*(x: SyntaxTree.WithStatement);
		VAR i: SIZE;
		BEGIN
			Indent; Keyword("WITH " );
			Expression(x.variable);
			w.String(" : ");
			WithPart(x.GetWithPart(0));
			FOR i := 1 TO x.WithParts()-1 DO
				Indent; w.String("| ");
				WithPart(x.GetWithPart(i));
			END;
			IF x.elsePart # NIL THEN
				Indent; w.String("ELSE ");
				w.IncIndent;  StatementSequence(x.elsePart);  w.DecIndent;
			END;
			Indent; Keyword("END" );
		END VisitWithStatement;

		PROCEDURE CasePart(x: SyntaxTree.CasePart);
		VAR case: SyntaxTree.CaseConstant;
		BEGIN
			Comments(x.comment, x, FALSE);
			ExpressionList(x.elements);
			IF info THEN
				w.BeginComment;
				case := x.firstConstant;
				WHILE(case # NIL) DO
					IF case # x.firstConstant THEN w.String(",") END;
					w.Int(case.min,1); w.String(".."); w.Int(case.max,1);
					case := case.next;
				END;
				EndComment;
			END;
			w.String( ":" );
			Comments(x.comment,x,TRUE);
			w.IncIndent; StatementSequence(x.statements);  w.DecIndent;
		END CasePart;

		PROCEDURE VisitCaseStatement*(x: SyntaxTree.CaseStatement);
		VAR i: SIZE;  case: SyntaxTree.CasePart;
		BEGIN
			Keyword("CASE " );
			Expression(x.variable);
			Keyword(" OF " );
			FOR i := 0 TO x.CaseParts() - 1 DO
				case := x.GetCasePart( i );
				Indent;
				w.String( "| " );
				CasePart(case);
			END;
			IF x.elsePart # NIL THEN
				Indent;
				Keyword("ELSE" );
				w.IncIndent;
				StatementSequence(x.elsePart);
				w.DecIndent;
			END;
			Indent;
			Keyword("END" );
		END VisitCaseStatement;

		PROCEDURE VisitWhileStatement*(x: SyntaxTree.WhileStatement);
		BEGIN
			Keyword("WHILE " );
			Expression(x.condition);
			Keyword(" DO " );
			w.IncIndent;
			StatementSequence(x.statements);
			w.DecIndent;
			Indent;
			Keyword("END" );
		END VisitWhileStatement;

		PROCEDURE VisitRepeatStatement*(x: SyntaxTree.RepeatStatement);
		BEGIN
			Keyword("REPEAT " );
			w.IncIndent;
			StatementSequence(x.statements);
			w.DecIndent;
			Indent;  Keyword("UNTIL " );
			Expression(x.condition);
		END VisitRepeatStatement;

		PROCEDURE VisitForStatement*(x: SyntaxTree.ForStatement);
		BEGIN
			Keyword("FOR " );
			Expression(x.variable);
			w.String( " := " );
			Expression(x.from);
			Keyword(" TO " );
			Expression(x.to);
			IF x.by # NIL THEN
				Keyword(" BY " );
				Expression(x.by);
			END;
			Keyword(" DO " );
			w.IncIndent;
			StatementSequence(x.statements);
			w.DecIndent;
			Indent;
			Keyword("END" );
		END VisitForStatement;

		PROCEDURE VisitLoopStatement*(x: SyntaxTree.LoopStatement);
		BEGIN
			Keyword("LOOP " );
			w.IncIndent;  StatementSequence(x.statements);  w.DecIndent;
			Indent;  Keyword("END" );
		END VisitLoopStatement;

		PROCEDURE VisitExitableBlock*(x: SyntaxTree.ExitableBlock);
		BEGIN
			Keyword("EXITABLE " );
			w.IncIndent;  StatementSequence(x.statements);  w.DecIndent;
			Indent;  Keyword("END " );
		END VisitExitableBlock;

		PROCEDURE VisitExitStatement*(x: SyntaxTree.ExitStatement);
		BEGIN
			Keyword("EXIT" );
		END VisitExitStatement;

		PROCEDURE VisitReturnStatement*(x: SyntaxTree.ReturnStatement);
		BEGIN
			Keyword("RETURN " );
			IF x.returnValue # NIL THEN Expression(x.returnValue) END
		END VisitReturnStatement;

		PROCEDURE VisitAwaitStatement*(x: SyntaxTree.AwaitStatement);
		BEGIN
			Keyword("AWAIT (" );  Expression(x.condition);  w.String( ")" );
		END VisitAwaitStatement;

		PROCEDURE Modifiers(x: SyntaxTree.Modifier);
		VAR name: Scanner.IdentifierString; first: BOOLEAN;
		BEGIN
			first := TRUE;
			WHILE x # NIL DO
				IF first THEN w.String("{"); first := FALSE ELSE w.String(", ") END;
				Basic.GetString(x.identifier,name);
				w.String(name);
				IF x.expression # NIL THEN
					w.String("(");
					Expression(x.expression);
					w.String(")");
				END;
				x := x.nextModifier;
			END;
			IF ~first THEN w.String("} ") END;
		END Modifiers;

		(*
		PROCEDURE BlockModifier(x: SyntaxTree.StatementBlock);
		VAR first: BOOLEAN;
			PROCEDURE Comma;
			BEGIN
				IF first THEN first := FALSE ELSE w.String(", "); END;
			END Comma;
		BEGIN
			first := TRUE;
				IF x.flags # {} THEN
					w.String("{");
					IF SyntaxTree.ActiveFlag IN x.flags THEN Comma; w.String("ACTIVE") END;
					IF SyntaxTree.PriorityFlag IN x.flags THEN Comma; w.String("PRIORITY("); Expression(x(SyntaxTree.Body).priority); w.String(")"); first := FALSE; END;
					IF SyntaxTree.SafeFlag IN x.flags THEN Comma; w.String("SAFE") END;
					IF SyntaxTree.ExclusiveFlag IN x.flags THEN Comma; w.String("EXCLUSIVE") END;
					w.String("}");
				END;
		END BlockModifier;
		*)

		PROCEDURE VisitStatementBlock*(x: SyntaxTree.StatementBlock);
		BEGIN
			Keyword("BEGIN"); Modifiers(x.blockModifiers);
			w.IncIndent;
			IF x.statements # NIL THEN StatementSequence(x.statements);  END;
			w.DecIndent;
			Indent; Keyword("END");
		END VisitStatementBlock;

		PROCEDURE Code(x: SyntaxTree.Code);
		VAR  i: LONGINT; ch: CHAR; cr: BOOLEAN; procedure: SyntaxTree.Procedure; procedureType: SyntaxTree.ProcedureType;
		CONST CR=0DX;
		BEGIN
			IF (currentScope # NIL) & (currentScope IS SyntaxTree.ProcedureScope) THEN
				procedure := currentScope(SyntaxTree.ProcedureScope).ownerProcedure;
				procedureType := procedure.type(SyntaxTree.ProcedureType);
			END;
			IF (mode >= SourceCode) OR (procedure = NIL) OR (procedure.access * SyntaxTree.Public # {}) & (procedure.isInline OR procedure.isOberonInline) THEN
				(*
				IF x.inlineCode # NIL THEN
					unit := 8;
					w.String(" D"); w.Int(unit,1);
					i := 0; size := x.inlineCode.GetSize();
					WHILE i < size DO
						value := x.inlineCode.GetBits(i,unit);
						w.String(" "); w.Int(value,1);
						INC(i,unit);
					END;
				ELS*)
				IF (x.sourceCode # NIL) THEN
					i := 0;
					ch := x.sourceCode[0];
					WHILE (ch # 0X) DO
						IF ch = CR THEN
							cr := TRUE;
						ELSE
							IF cr THEN Indent; cr := FALSE END;
							w.Char(ch);
						END;
						INC(i); ch := x.sourceCode[i];
					END;
				END;
				(*
				IF x.inlineCode # NIL THEN
					w.String("; ");
					size := x.inlineCode.GetSize() DIV 8;
					FOR i := 0 TO size-1 DO
						value := x.inlineCode.GetBits(i*8,8);
						w.Hex(value,-2); w.String(" ");
					END;
				END;
				*)
			END;
		END Code;

		PROCEDURE VisitCode*(x: SyntaxTree.Code);
		BEGIN
			Indent; Keyword("CODE");
			Code(x);
			Indent; Keyword("END");
		END VisitCode;

		PROCEDURE Body(x: SyntaxTree.Body; implementation: BOOLEAN);
		VAR
		BEGIN
			IF DebugPosition THEN TRACE(x.position.start, x.position.end, x.end.start, x.end.end) END;
			IF x.code # NIL THEN
				Indent; Keyword("CODE");
				IF implementation THEN
					Code(x.code);
				END;
			ELSE
				Indent;  Keyword("BEGIN" ); Modifiers(x.blockModifiers);
				IF implementation THEN
					IF x.statements # NIL THEN
						w.IncIndent;
						StatementSequence(x.statements);
						w.DecIndent;
					END;
					IF x.finally # NIL THEN
						Indent;  Keyword("FINALLY" );
						w.IncIndent;
						StatementSequence(x.finally);
						w.DecIndent
					END;
				END;
			END;
			(* "END" written by caller *)
		END Body;

		PROCEDURE VisitModule*(x: SyntaxTree.Module);
		BEGIN Module(x)
		END VisitModule;
		
		PROCEDURE TemplateParameter(x: SyntaxTree.TemplateParameter);
		BEGIN
			IF x.type = SyntaxTree.TemplateType.Const THEN
				Keyword("CONST ");
			ELSIF x.type = SyntaxTree.TemplateType.Type THEN
				Keyword("TYPE ");
			ELSE HALT(200) END;
			Identifier(x.identifier);
		END TemplateParameter;
		

		PROCEDURE Module*(x: SyntaxTree.Module);
		VAR i: SIZE;
		BEGIN
			IF x = NIL THEN
				AlertString("(* no module *)");
			ELSE
				case := x.case;
				currentScope := x.moduleScope.outerScope;
				Comments(x.comment,x,FALSE);
				Keyword("MODULE ");
				Identifier(x.name);
				IF x.parameters # NIL THEN
					w.String("(");
					FOR i := 0 TO x.parameters.Length()-1 DO
						TemplateParameter(x.parameters.Get(i));
						IF i < x.parameters.Length()-1 THEN
							w.String(", ");
						END;
					END;
					w.String(")");
				END;
				IF (x.context # SyntaxTree.invalidIdentifier) & (x.context#Global.A2Name) THEN
					Keyword(" IN ");
					Identifier(x.context)
				END;

				IF (x.type IS SyntaxTree.CellType) & (x.type(SyntaxTree.CellType).firstParameter # NIL) THEN (* for actors *)
					ParameterList(x.type(SyntaxTree.CellType).firstParameter);
				END;

				w.String(";");
				Comments(x.comment,x,TRUE);
				w.IncIndent;
				IF x.moduleScope.firstImport # NIL THEN
					ImportList(x.moduleScope.firstImport)
				END;
				w.DecIndent;
				Scope(x.moduleScope);
				IF x.moduleScope.firstBuiltin # NIL THEN
					BuiltinList(x.moduleScope.firstBuiltin)
				END;

				IF (x.moduleScope.bodyProcedure # NIL) & (x.moduleScope.bodyProcedure.procedureScope.body # NIL) THEN
					Body(x.moduleScope.bodyProcedure.procedureScope.body, mode >= SourceCode)
				END;
				Indent; Keyword("END "); Identifier(x.name); w.String( "." ); w.Ln;  w.Update;

				Comments(x.closingComment,x, FALSE);

				IF (mode > SourceCode) & (x.moduleScope.firstComment # NIL) THEN w.Ln; CommentList(x.moduleScope.firstComment) END;

			END
		END Module;

		PROCEDURE SingleStatement*(b: BOOLEAN);
		BEGIN singleStatement := b
		END SingleStatement;

		PROCEDURE &Init*(w: Streams.Writer; mode: LONGINT; info: BOOLEAN);
		BEGIN
			SELF.w := Basic.GetWriter(w);
			SELF.mode := mode; NEW(ws,128); SELF.info := info; case := Scanner.Uppercase;
			commentCount := 0; alertCount := 0; singleStatement := FALSE;
		END Init;

	END Printer;

(* debugging helper *)
VAR
	debug: Printer;

	PROCEDURE NewPrinter*(w: Streams.Writer; mode: LONGINT; info: BOOLEAN): Printer;
	VAR p: Printer;
	BEGIN
		NEW(p,w,mode,info); RETURN p
	END NewPrinter;

	PROCEDURE Info*(CONST info: ARRAY OF CHAR; a: ANY);
	VAR symbol: SyntaxTree.Symbol; scope: SyntaxTree.Scope;
	BEGIN
		debug.w := Basic.GetWriter(D.Log);
		D.Ln;
		D.Str(" --------> ");
		D.Str(info);
		D.Str(" ");
		D.Hex(SYSTEM.VAL(LONGINT,a),8);
		D.Str(" : ");

		IF a = NIL THEN
			D.Str("NIL");
		ELSIF a IS SyntaxTree.Expression THEN
			debug.Expression(a(SyntaxTree.Expression));
			Info("with type",a(SyntaxTree.Expression).type);
		ELSIF a IS SyntaxTree.Type THEN
			IF a IS SyntaxTree.QualifiedType THEN
				D.Str("[QualifiedType] ");
			END;
			debug.Type(a(SyntaxTree.Type))
		ELSIF a IS SyntaxTree.Symbol THEN
			debug.Symbol(a(SyntaxTree.Symbol))
		ELSIF a IS SyntaxTree.Statement THEN
			debug.Statement(a(SyntaxTree.Statement))
		ELSIF a IS SyntaxTree.StatementSequence THEN
			debug.StatementSequence(a(SyntaxTree.StatementSequence));
		ELSIF a IS SyntaxTree.Scope THEN
			scope := a(SyntaxTree.Scope);
			WHILE(scope # NIL) DO
				D.Ln; D.Str("      ");
				IF scope IS SyntaxTree.ModuleScope THEN D.Str("ModuleScope: ")
				ELSIF scope IS SyntaxTree.ProcedureScope THEN D.Str("ProcedureScope: ");
				ELSIF scope IS SyntaxTree.RecordScope THEN D.Str("RecordScope: ");
				ELSE D.Str("Scope: ");
				END;
				symbol := scope.firstSymbol;
				WHILE(symbol # NIL) DO
					debug.Identifier(symbol.name); D.Str(" ");
					symbol := symbol.nextSymbol;
				END;
				scope := scope.outerScope;
			END;
		(*
		ELSIF a IS SyntaxTree.Identifier THEN
			debug.Identifier(a(SyntaxTree.Identifier));
		*)
		ELSIF a IS SyntaxTree.QualifiedIdentifier THEN
			debug.QualifiedIdentifier(a(SyntaxTree.QualifiedIdentifier));
		ELSIF a IS SyntaxTree.Module THEN
			debug.Module(a(SyntaxTree.Module))
		ELSE
			debug.w.String("unknown");
		END;
		D.Update();
	END Info;

	PROCEDURE Init;
	BEGIN
		NEW(debug,D.Log,All,TRUE);
		debug.case := Scanner.Uppercase;
	END Init;

BEGIN
	Init;
END FoxPrintout.

System.FreeDownTo FoxPrintout ~
