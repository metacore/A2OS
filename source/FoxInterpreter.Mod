MODULE FoxInterpreter; (** AUTHOR ""; PURPOSE ""; *)

IMPORT Scanner := FoxScanner, FoxParser, SyntaxTree := FoxSyntaxTree, Printout := FoxPrintout, Commands, Diagnostics, StringPool, InterpreterSymbols := FoxInterpreterSymbols, D:= Debugging,
	Strings, Streams, Modules, PersistentObjects, Basic := FoxBasic, SYSTEM, Machine, Global := FoxGlobal, Heaps;

CONST
	EnableTrace = FALSE;
	MaxIndex = 8;


TYPE
	Result*= InterpreterSymbols.Result;
	Value*=InterpreterSymbols.Value;
	Integer*=InterpreterSymbols.IntegerValue;
	Real*=InterpreterSymbols.RealValue;
	String*=InterpreterSymbols.StringValue;
	Boolean*=InterpreterSymbols.BooleanValue;
	Set*=InterpreterSymbols.SetValue;
	Range*=InterpreterSymbols.RangeValue;
	Char*=InterpreterSymbols.CharValue;
	Any*=InterpreterSymbols.AnyValue;
	MathArrayValue*= InterpreterSymbols.MathArrayValue;
	
	Scope*=InterpreterSymbols.Scope;
	Container*= InterpreterSymbols.Container;
	
	Builtin*=OBJECT (InterpreterSymbols.Object)
	VAR id: LONGINT;
	END Builtin;
	
	Item*= RECORD
		object*: InterpreterSymbols.Item;
		in*: InterpreterSymbols.Item;
		name*: StringPool.Index;
		i*: ARRAY MaxIndex OF LONGINT; (* indices if applicable *)
	END;

	CommandStatement = OBJECT (SyntaxTree.Statement)
	VAR command: Strings.String;

		PROCEDURE & InitCommandStatement(s: Strings.String);
		BEGIN
			command := s
		END InitCommandStatement;

	END CommandStatement;

	PrintStatement = OBJECT (SyntaxTree.Statement)
	VAR expression: SyntaxTree.Expression;

		PROCEDURE & InitPrintStatement(e: SyntaxTree.Expression);
		BEGIN
			expression := e;
		END InitPrintStatement;

	END PrintStatement;

	Parser*= OBJECT(FoxParser.Parser)

		PROCEDURE Statement*(statements: SyntaxTree.StatementSequence; outer: SyntaxTree.Statement): BOOLEAN;
		VAR statement: SyntaxTree.Statement;
		BEGIN
			IF (Token() = Scanner.ExclamationMark) THEN
				statement := Cmd();
				IF statement # NIL THEN 
					statements.AddStatement(statement);
				END;
				RETURN TRUE
			ELSIF (Token() = Scanner.Questionmark) THEN
				statement := Print();
				IF statement # NIL THEN 
					statements.AddStatement(statement);
				END;
				RETURN TRUE
			ELSE
				RETURN Statement^(statements, outer);
			END;
		END Statement;

		PROCEDURE Cmd(): SyntaxTree.Statement;
		VAR cmd: CommandStatement; string: Strings.String;
		BEGIN
			NextSymbol;
			IF MandatoryString(string) THEN
			NEW(cmd, string);
			(* TRACE(string^) *)
			END;
			RETURN cmd;
		END Cmd;

		PROCEDURE Print(): SyntaxTree.Statement;
		VAR print: PrintStatement;
		BEGIN
			NextSymbol;
			NEW(print, Expression());
			RETURN print;
		END Print;


	END Parser;

	Interpreter* = OBJECT (SyntaxTree.Visitor)
	VAR
		value: BOOLEAN;
		item-: Item;
		module-: Modules.Module;
		typeDesc-: Modules.TypeDesc;
		scope-: Scope;
		exit: BOOLEAN;
		error-: BOOLEAN;
		diagnostics: Diagnostics.Diagnostics;
		context-: Commands.Context;
		
		
		PROCEDURE & Init*(scope: Scope; diagnostics: Diagnostics.Diagnostics; context: Commands.Context);
		BEGIN
			IF scope = NIL THEN scope := global END;
			SELF.scope := scope;
			error := FALSE;
			SELF.diagnostics := diagnostics;
			SELF.context := context;
		END Init;

		PROCEDURE SetScope*(s: Scope);
		BEGIN
			scope := s
		END SetScope;

		PROCEDURE Reset*;
		BEGIN
			error := FALSE;
		END Reset;

		PROCEDURE Error(CONST msg: ARRAY OF CHAR);
		BEGIN
			IF error THEN RETURN END;
			(*! use diagnostics *)
			error := TRUE;
			Basic.Error(diagnostics, "", Basic.invalidPosition, msg);
			D.TraceBack;
		END Error;

		PROCEDURE ErrorSS(CONST msg: ARRAY OF CHAR; id: StringPool.Index);
		VAR name: ARRAY 128 OF CHAR; message: ARRAY 256 OF CHAR;
		BEGIN
			IF error THEN RETURN END;
			(*! use diagnostics *)
			error := TRUE;
			COPY(msg, message);
			IF id # 0 THEN Strings.Append(message," "); StringPool.GetString(id, name); Strings.Append(message, name); END;
			Basic.Error(diagnostics, "", Basic.invalidPosition, message);
		END ErrorSS;

		(** syntax tree types omitted -- unused *)

		(** expressions *)

		PROCEDURE VisitSet*(x: SyntaxTree.Set);
		VAR s: SET; i: LONGINT; value: Value;
		BEGIN
			FOR i := 0 TO x.elements.Length()-1 DO
				IF GetValue(x.elements.GetExpression(i), value) THEN
					IF value IS Integer THEN INCL(s, LONGINT(value(Integer).value))
					ELSIF value IS Range THEN s := s + {FIRST(value(Range).value)..LAST(value(Range).value)}
					ELSE Error("wrong value type")
					END;
				END;
			END;
			NewSet(s)
		END VisitSet;

		PROCEDURE VisitMathArrayExpression*(x: SyntaxTree.MathArrayExpression);
		VAR numberElements, i: LONGINT; a: MathArrayValue;
		BEGIN
			numberElements := x.elements.Length();
			NEW(a, numberElements);
			FOR i := 0 TO numberElements-1 DO
				Expression(x.elements.GetExpression(i));
				a.SetValue(i,item.object(Value));
			END;
			item.object := a; value := TRUE;
		END VisitMathArrayExpression;

		PROCEDURE NewInt(i: HUGEINT);
		VAR v: Integer;
		BEGIN
			NEW(v, i); item.object := v; value := TRUE
		END NewInt;

		PROCEDURE NewReal(i: LONGREAL);
		VAR v: Real;
		BEGIN
			NEW(v, i); item.object := v; value := TRUE
		END NewReal;

		PROCEDURE NewBool(b: BOOLEAN);
		VAR v: Boolean;
		BEGIN
			NEW(v, b); item.object := v; value := TRUE;
		END NewBool;

		PROCEDURE NewSet(s: SET);
		VAR v: Set;
		BEGIN
			NEW(v, s); item.object := v; value := TRUE;
		END NewSet;

		PROCEDURE NewString(CONST s: ARRAY OF CHAR);
		VAR v: String;
		BEGIN
			NEW(v, s); item.object := v; value := TRUE;
		END NewString;

		PROCEDURE NewRange(r: RANGE);
		VAR v: Range;
		BEGIN
			NEW(v, r ); item.object := v; value := TRUE;
		END NewRange;

		PROCEDURE NewChar(c: CHAR);
		VAR v: Char;
		BEGIN
			NEW(v, c); item.object := v; value := TRUE;
		END NewChar;

		PROCEDURE VisitUnaryExpression*(x: SyntaxTree.UnaryExpression);
		VAR value: Value; i: HUGEINT; r: LONGREAL; b: BOOLEAN; operator: LONGINT;
		BEGIN
			operator := x.operator;
			IF ~GetValue(x.left, value) THEN 
				Error("no operand");
				RETURN 
			END;
			IF value IS Integer THEN
				i := value(Integer).value;
				CASE operator OF
				Scanner.Minus: NewInt(-i)
				|Scanner.Plus: NewInt(i)
				ELSE Error("unary operator not supported")
				END;
			ELSIF value IS Real THEN
				r := value(Real).value;
				CASE operator OF
				Scanner.Minus: NewReal(-r)
				|Scanner.Plus: NewReal(r)
				ELSE Error("unary operator not supported")
				END;
			ELSIF value IS Boolean THEN
				b := value(Boolean).value;
				CASE operator OF
				Scanner.Not: NewBool(~b)
				ELSE Error("unary operator not supported")
				END;
			ELSIF value IS Set THEN
				CASE operator OF
				Scanner.Minus: NewSet(-value(Set).value)
				ELSE Error("unary operator not supported")
				END;
			ELSE
				Error("unary operation not supported");
			END;
		END VisitUnaryExpression;

		PROCEDURE VisitBinaryExpression*(x: SyntaxTree.BinaryExpression);
		VAR left, right: Value; operator: LONGINT; li, ri: HUGEINT; lr, rr: LONGREAL; lb, rb:  BOOLEAN; sl, sr: SET;
		BEGIN
			operator := x.operator;
			IF ~GetValue(x.left, left) OR ~GetValue(x.right, right) THEN RETURN END;

			IF (left IS Integer) & (right IS Integer) THEN
				li := left(Integer).value; ri := right(Integer).value;
				CASE operator OF
				|Scanner.Plus: NewInt(li+ri)
				|Scanner.Minus: NewInt(li-ri);
				|Scanner.Times: NewInt(li * ri);
				|Scanner.Div: NewInt(li DIV ri);
				|Scanner.Mod: NewInt(li MOD ri);
				|Scanner.Equal: NewBool(li = ri);
				|Scanner.Unequal: NewBool(li # ri)
				|Scanner.Less: NewBool(li < ri)
				|Scanner.LessEqual: NewBool(li <= ri)
				|Scanner.Greater: NewBool(li > ri)
				|Scanner.GreaterEqual: NewBool(li >= ri)
				|Scanner.Slash: NewReal(li/ri)
				ELSE Error("binary operator not supported")
				END;
			ELSIF ((left IS Integer) OR (left IS Real)) & ((right IS Integer) OR (right IS Real)) THEN
				IF left IS Integer THEN lr := left(Integer).value
				ELSE lr := left(Real).value
				END;
				IF right IS Integer THEN rr := right(Integer).value;
				ELSE rr := right(Real).value
				END;
				CASE operator OF
				|Scanner.Plus: NewReal(lr+rr)
				|Scanner.Minus: NewReal(lr-rr);
				|Scanner.Times: NewReal(lr * rr);
				|Scanner.Slash: NewReal(lr / rr);
				|Scanner.Equal: NewBool(lr = rr);
				|Scanner.Unequal: NewBool(lr # rr)
				|Scanner.Less: NewBool(lr < rr)
				|Scanner.LessEqual: NewBool(lr <= rr)
				|Scanner.Greater: NewBool(lr > rr)
				|Scanner.GreaterEqual: NewBool(lr >= rr)
				ELSE Error("binary operator not supported")
				END;
			ELSIF (left IS Boolean) & (right IS Boolean) THEN
				lb := left(Boolean).value; rb := right(Boolean).value;
				CASE operator OF
				|Scanner.Or: NewBool(lb OR rb);
				|Scanner.And: NewBool(lb & rb);
				|Scanner.Equal: NewBool(lb = rb)
				|Scanner.Unequal: NewBool(lb # rb)
				ELSE Error("operator not supported")
				END;
			ELSIF (left IS String) & (right IS String) THEN
				CASE operator OF
				|Scanner.Equal: NewBool(left(String).value^ = right(String).value^);
				|Scanner.Unequal: NewBool(left(String).value^ = right(String).value^);
				|Scanner.Less: NewBool(left(String).value^ < right(String).value^);
				|Scanner.LessEqual: NewBool(left(String).value^ <= right(String).value^);
				|Scanner.Greater: NewBool(left(String).value^ > right(String).value^);
				|Scanner.GreaterEqual: NewBool(left(String).value^ >= right(String).value^);
				ELSE Error("binary operator not supported")
				END
			ELSIF (left IS Set) & (right IS Set) THEN
				sl := left(Set).value; sr := right(Set).value;
				CASE operator OF
				|Scanner.Plus: NewSet(sl+sr)
				|Scanner.Minus: NewSet(sl-sr);
				|Scanner.Times: NewSet(sl * sr);
				|Scanner.Slash: NewSet(sl / sr);
				|Scanner.Equal: NewBool(sl = sr);
				|Scanner.Unequal: NewBool(sl # sr)
				|Scanner.Less: NewBool(sl < sr)
				|Scanner.LessEqual: NewBool(sl <= sr)
				|Scanner.Greater: NewBool(sl > sr)
				|Scanner.GreaterEqual: NewBool(sl >= sr)
				ELSE Error("binary operator not supported")
				END;
			ELSIF (left IS Integer) & (right IS Set) THEN
				CASE operator OF
				Scanner.In: NewBool(left(Integer).value IN right(Set).value)
				ELSE Error("binary operator not supported")
				END;
			ELSE
				Error("binary operation not supported");
				Printout.Info("binary operation", x);
			END;
		END VisitBinaryExpression;

		PROCEDURE VisitRangeExpression*(x: SyntaxTree.RangeExpression);
		VAR first,last,step: HUGEINT; value: Integer;
		BEGIN
			IF ~ExpectInteger(x.first, value) THEN RETURN END;
			first := value.value;
			IF ~ExpectInteger(x.last, value) THEN RETURN END;
			last := value.value;
			IF (x.step # NIL) & ExpectInteger(x.step, value) THEN
				step := value.value;
			ELSE
				step := 1
			END;
			NewRange(first ..last BY step);
		END VisitRangeExpression;

		PROCEDURE VisitTensorRangeExpression*(x: SyntaxTree.TensorRangeExpression);
		BEGIN HALT(100) (* abstract *) END VisitTensorRangeExpression;

		PROCEDURE VisitConversion*(x: SyntaxTree.Conversion);
		BEGIN HALT(100) (* abstract *) END VisitConversion;

		(** designators (expressions) *)
		PROCEDURE VisitDesignator*(x: SyntaxTree.Designator);
		BEGIN HALT(100) (* abstract *) END VisitDesignator;
		
		PROCEDURE VisitQualifiedType*(x: SyntaxTree.QualifiedType);
		VAR moduleName, name: Modules.Name; 
		BEGIN
			IF x.qualifiedIdentifier.prefix # SyntaxTree.invalidIdentifier THEN
				item.name := x.qualifiedIdentifier.prefix;
				item.object := scope.FindObject1(item.name, -1, item.in);
				
				IF item.object = NIL THEN
					StringPool.GetString(item.name, moduleName);
					item.object :=InterpreterSymbols.GetModule(moduleName); 
				END;
			END;
			item.name := x.qualifiedIdentifier.suffix;
			IF (item.object # NIL) THEN
				IF item.object IS Result THEN
					StringPool.GetString(item.name, name);
					item.object := item.object(Result).Find(name);
				ELSE
					item.in := item.object;
					item.object := InterpreterSymbols.FindInObject1(item.object, item.name,-1);
				END;
			ELSE
				ErrorSS("invalid selector",item.name);
				item.in := NIL;
			END;
				
				
		END VisitQualifiedType;
		

		(*
		PROCEDURE FindInScope(scope: Scope; symbol: StringPool.Index): Value;
		VAR item: Value;
		BEGIN
			REPEAT
				item := scope.Find1(symbol);

				IF (item = NIL) THEN
					scope := scope.outer
				ELSE
					scope := NIL
				END;
			UNTIL (scope = NIL);
			RETURN item
		END FindInScope;
		*)

(*
		PROCEDURE FindType(CONST types: POINTER TO ARRAY OF Modules.TypeDesc; CONST name: ARRAY OF CHAR): Modules.TypeDesc;
		VAR i: LONGINT;
		BEGIN
		IF types = NIL THEN RETURN NIL END;
		FOR i := 0 TO LEN(types)-1 DO
			IF types[i].name = name THEN 
				RETURN types[i];
			END;
		END;
		RETURN NIL;
		END FindType;

		PROCEDURE FindProc(CONST types: POINTER TO ARRAY OF Modules.ProcedureEntry; CONST name: ARRAY OF CHAR; VAR num: LONGINT): BOOLEAN;
		BEGIN
		IF types = NIL THEN RETURN FALSE END;
		FOR num := 0 TO LEN(types)-1 DO
			IF types[num].name^ = name THEN 
				RETURN TRUE;
			END;
		END;
			RETURN FALSE;
		END FindProc;

		PROCEDURE FindField(CONST types: POINTER TO ARRAY OF Modules.FieldEntry; CONST name: ARRAY OF CHAR; VAR num: LONGINT): BOOLEAN;
		BEGIN
		IF types = NIL THEN RETURN FALSE END;
		FOR num := 0 TO LEN(types)-1 DO
			IF types[num].name^ = name THEN 
				RETURN TRUE;
			END;
		END;
			RETURN FALSE;
		END FindField;

*)

		PROCEDURE VisitIdentifierDesignator*(x: SyntaxTree.IdentifierDesignator);
		VAR moduleName: Modules.Name; msg: ARRAY 128 OF CHAR; res: LONGINT;
			 builtin : Builtin; anyValue: Any;
		BEGIN
			ASSERT(x.left = NIL);
			item.name := x.identifier;
			(*
			item.object := FindInScope(item.scope, item.name);
			*)
			IF item.name = Basic.MakeString("trace") THEN 
				NEW(builtin); builtin.id :=  Global.systemTrace;
				item.object := builtin;
			ELSIF item.name = Basic.MakeString("context") THEN
				NEW(anyValue, context);
				item.object :=  anyValue;
			ELSE
				
				item.object := scope.FindObject1(item.name, -1, item.in);
				
				IF item.object = NIL THEN
					StringPool.GetString(item.name, moduleName);
					item.object :=InterpreterSymbols.GetModule(moduleName); 
				END;
			END;
		END VisitIdentifierDesignator;

		PROCEDURE VisitSelectorDesignator*(x: SyntaxTree.SelectorDesignator);
		VAR traverse: BOOLEAN; name: ARRAY 128 OF CHAR; num: LONGINT;
		BEGIN
			Expression(x.left); traverse := FALSE;
			IF error THEN RETURN END;
			item.name := x.identifier;
			IF (item.object # NIL) THEN
				IF item.object IS Result THEN
					StringPool.GetString(item.name, name);
					item.object := item.object(Result).Find(name);
				ELSE
					item.in := item.object;
					item.object := InterpreterSymbols.FindInObject1(item.object, x.identifier,-1);
				END;
			ELSE
				ErrorSS("invalid selector",item.name);
				item.in := NIL;
			END;
		END VisitSelectorDesignator;
		
	
		PROCEDURE VisitParameterDesignator*(x: SyntaxTree.ParameterDesignator);
		VAR e: SyntaxTree.Expression; proc: InterpreterSymbols.ProcedureResult; i: LONGINT;
			adr: ADDRESS; adrValue: Value; any: InterpreterSymbols.AnyValue;
		BEGIN
			e := x.left;
			Expression(e);
			IF (item.object # NIL) THEN
				IF (item.object IS InterpreterSymbols.ProcedureResult) THEN
					proc := item.object(InterpreterSymbols.ProcedureResult);
					(* self pointer *) 
					proc.Pars();
					IF ~(proc.caller IS InterpreterSymbols.ModuleResult) THEN
						adrValue := proc.caller.Evaluate();
						ASSERT(adrValue.GetAddress(adr)); 
						proc.PushAddress(adr);
					END;
					(* result pointer *) 
					IF proc.ReturnsPointer() THEN
						NEW(any,NIL);
						proc.PushAddress(any.Address());
					END; 
					FOR i := 0 TO x.parameters.Length()-1 DO
						e := x.parameters.GetExpression(i);
						IF ~proc.Push(Designate(e)) THEN Error("wrong parameter"); RETURN END;
					END;
					IF ~proc.Check() THEN Error("non-matching parameter number"); RETURN END; 
					item.object := proc.Evaluate();
					IF any # NIL THEN item.object := any END;
				ELSIF (item.object IS Builtin) THEN
					CASE item.object(Builtin).id OF
					Global.systemTrace:
						SystemTrace(x.parameters);
					ELSE
						Error("no builtin?")
					END;
				ELSE
						Error("no procedure")
				END;
			ELSE
				Error("no procedure")
			END;
		END VisitParameterDesignator;

		PROCEDURE VisitArrowDesignator*(x: SyntaxTree.ArrowDesignator);
		BEGIN HALT(100) (* abstract *) END VisitArrowDesignator;

		PROCEDURE VisitBracketDesignator*(x: SyntaxTree.BracketDesignator);
		VAR array: MathArrayValue; i: LONGINT; element: Value; index: Integer; obj: PersistentObjects.Object;
			leftValue, rightValue: Value; filter: InterpreterSymbols.ObjectFilter; expression: SyntaxTree.Expression;
			attribute, value: ARRAY 128 OF CHAR; val: LONGINT;
		BEGIN
			Expression(x.left);
			IF (item.object # NIL) & (item.object IS MathArrayValue) THEN
				element := item.object(MathArrayValue);
				FOR i := 0 TO x.parameters.Length()-1 DO
					array := element(MathArrayValue);
					IF GetInteger(x.parameters.GetExpression(i), index) THEN
						element := array.GetValue(LONGINT(index.value));
					END;
				END;
				item.object := element;
			ELSIF (item.object # NIL) THEN
				NEW(filter); obj := item.object;
				FOR i := 0 TO x.parameters.Length()-1 DO
					expression := x.parameters.GetExpression(i);
					IF (expression IS SyntaxTree.BinaryExpression) & (expression(SyntaxTree.BinaryExpression).operator = Scanner.Equal) THEN
						IF (expression(SyntaxTree.BinaryExpression).left IS SyntaxTree.IdentifierDesignator) &
						GetValue(expression(SyntaxTree.BinaryExpression).right, rightValue) THEN
							StringPool.GetString(
							expression(SyntaxTree.BinaryExpression).left(SyntaxTree.IdentifierDesignator).identifier, attribute);
							rightValue(Value).GetString(value);
							obj := filter.Filter(obj, attribute, value)
						ELSE HALT(200)
						END;
					ELSE
						IF GetValue(expression, leftValue) THEN
							IF leftValue IS String THEN
								leftValue(Value).GetString(value);
								obj := filter.Filter(obj, "name", value);
							ELSIF leftValue IS Integer THEN
								IF obj IS PersistentObjects.ObjectList THEN
									item.object := obj(PersistentObjects.ObjectList).GetElement(LONGINT(leftValue(Integer).value))
								ELSIF obj IS Container THEN
									item.object := obj(Container).GetItem(LONGINT(leftValue(Integer).value))
								ELSE Error("cannot be indexed")
								END;
							END;
						END;
					END;
				END;
				IF obj(Container).symbols.Length() > 0 THEN
					item.object := obj(Container).GetItem(0);
				ELSE
					Error("no such symbol")
				END;
			END;
		END VisitBracketDesignator;

		PROCEDURE VisitSymbolDesignator*(x: SyntaxTree.SymbolDesignator);
		BEGIN HALT(100) (* abstract *) END VisitSymbolDesignator;

		PROCEDURE VisitIndexDesignator*(x: SyntaxTree.IndexDesignator);
		BEGIN HALT(100) (* abstract *) END VisitIndexDesignator;

		PROCEDURE VisitProcedureCallDesignator*(x: SyntaxTree.ProcedureCallDesignator);
		BEGIN HALT(100)
		END VisitProcedureCallDesignator;
		
		PROCEDURE SystemTrace(x: SyntaxTree.ExpressionList);
		VAR
			printout: Printout.Printer;
			value: Value;
			expression: SyntaxTree.Expression;
			i: LONGINT;
			out: Streams.Writer;
		BEGIN
			out := context.out;
			printout := Printout.NewPrinter(out,Printout.SourceCode,FALSE);
			FOR i := 0 TO x.Length()-1 DO
				expression := x.GetExpression(i);
				IF ~(expression IS SyntaxTree.StringValue) THEN
					printout.Expression(expression);
					out.String("= ");
				END;
				value := Evaluate(expression);
				IF value # NIL THEN
					value.WriteValue(out);
				ELSE
					out.String("UNKNOWN")
				END;
				out.String("; ");
			END;
			out.Ln;
			out.Update;
		END SystemTrace;
		
		PROCEDURE FindType(type: SyntaxTree.Type): Result;
		BEGIN
			type.Accept(SELF);
			IF item.object # NIL THEN
				RETURN item.object(Result);
			END;
			RETURN NIL;
		END FindType;
		
		
		PROCEDURE VisitBuiltinCallDesignator*(x: SyntaxTree.BuiltinCallDesignator);
		VAR p,p0,p1,p2: SyntaxTree.Expression;
			type,t0,t1,t2: SyntaxTree.Type;
			len: LONGINT;
			i: LONGINT; 
			parameter: SyntaxTree.Parameter;
			name: Basic.SectionName;
			modifier: SyntaxTree.Modifier;
			position: SyntaxTree.Position;
			value: Value;
			result: Result;
			address: ADDRESS;
			o: ANY;
			anyValue: InterpreterSymbols.AnyValue;
			proc: InterpreterSymbols.ProcedureResult;
			ignore: Result;
			e: SyntaxTree.Expression;
		BEGIN
			position := x.position;
			p0 := NIL; p1 := NIL; p2 := NIL; 
			IF x.parameters # NIL THEN 
				len := x.parameters.Length();
			ELSE
				len := 0
			END;
			CASE x.id OF
			(* ----- NEW -----*)
			Global.New:
				result := FindType(x.returnType);
				IF (result # NIL) & (result IS InterpreterSymbols.TypeResult)  THEN
					address := result.Address();
					Heaps.NewRec(o, address, FALSE);
					NEW(anyValue, o);
					
					proc := result(InterpreterSymbols.TypeResult).Constructor();
					IF proc # NIL THEN
						proc.Pars();
						proc.PushAddress(o);
						FOR i := 0 TO x.parameters.Length()-1 DO
							e := x.parameters.GetExpression(i);
							IF ~proc.Push(Designate(e)) THEN Error("wrong parameter"); item.object := NIL; RETURN END;
						END;
						IF ~proc.Check() THEN Error("non-matching parameter number"); item.object := NIL; RETURN END; 
						ignore := proc.Evaluate();
					END;
					item.object := anyValue;
				ELSE
					Error("No Type");
				END;
			|Global.systemTrace:
				SystemTrace(x.parameters);
			ELSE (* function not yet implemented *)
				Error("Not Yet Implemented");
			END;
		END VisitBuiltinCallDesignator;

		PROCEDURE VisitTypeGuardDesignator*(x: SyntaxTree.TypeGuardDesignator);
		BEGIN HALT(100) (* abstract *) END VisitTypeGuardDesignator;

		PROCEDURE VisitDereferenceDesignator*(x: SyntaxTree.DereferenceDesignator);
		BEGIN HALT(100) (* abstract *) END VisitDereferenceDesignator;

		PROCEDURE VisitSupercallDesignator*(x: SyntaxTree.SupercallDesignator);
		BEGIN HALT(100) (* abstract *) END VisitSupercallDesignator;

		PROCEDURE VisitSelfDesignator*(x: SyntaxTree.SelfDesignator);
		BEGIN HALT(100) (* abstract *) END VisitSelfDesignator;

		PROCEDURE VisitResultDesignator*(x: SyntaxTree.ResultDesignator);
		BEGIN HALT(100) (* abstract *) END VisitResultDesignator;

		(** values *)
		PROCEDURE VisitValue*(x: SyntaxTree.Value);
		BEGIN HALT(100) (* abstract *) END VisitValue;

		PROCEDURE VisitBooleanValue*(x: SyntaxTree.BooleanValue);
		BEGIN
			NewBool(x.value)
		END VisitBooleanValue;

		PROCEDURE VisitIntegerValue*(x: SyntaxTree.IntegerValue);
		BEGIN
			NewInt(x.value)
		END VisitIntegerValue;

		PROCEDURE VisitCharacterValue*(x: SyntaxTree.CharacterValue);
		BEGIN
			NewChar(x.value);
		END VisitCharacterValue;

		PROCEDURE VisitSetValue*(x: SyntaxTree.SetValue);
		BEGIN
			NewSet(SET(x.value))
		END VisitSetValue;

		PROCEDURE VisitMathArrayValue*(x: SyntaxTree.MathArrayValue);
		BEGIN HALT(100) (* abstract *) END VisitMathArrayValue;

		PROCEDURE VisitRealValue*(x: SyntaxTree.RealValue);
		BEGIN
			NewReal(x.value)
		END VisitRealValue;

		PROCEDURE VisitComplexValue*(x: SyntaxTree.ComplexValue);
		BEGIN HALT(100) (* abstract *) END VisitComplexValue;

		PROCEDURE VisitStringValue*(x: SyntaxTree.StringValue);
		BEGIN
			NewString(x.value^);
		END VisitStringValue;

		PROCEDURE VisitNilValue*(x: SyntaxTree.NilValue);
		BEGIN HALT(100) (* abstract *) END VisitNilValue;

		PROCEDURE VisitEnumerationValue*(x: SyntaxTree.EnumerationValue);
		BEGIN HALT(100) (* abstract *) END VisitEnumerationValue;

		(** symbols *)
		PROCEDURE VisitSymbol*(x: SyntaxTree.Symbol);
		BEGIN HALT(100) (* abstract *) END VisitSymbol;

		PROCEDURE VisitTypeDeclaration*(x: SyntaxTree.TypeDeclaration);
		BEGIN HALT(100) (* abstract *) END VisitTypeDeclaration;

		PROCEDURE VisitConstant*(x: SyntaxTree.Constant);
		BEGIN HALT(100) (* abstract *) END VisitConstant;

		PROCEDURE VisitVariable*(x: SyntaxTree.Variable);
		BEGIN HALT(100) (* abstract *) END VisitVariable;

		PROCEDURE VisitParameter*(x: SyntaxTree.Parameter);
		BEGIN HALT(100) (* abstract *) END VisitParameter;

		PROCEDURE VisitProcedure*(x: SyntaxTree.Procedure);
		BEGIN HALT(100) (* abstract *) END VisitProcedure;

		PROCEDURE VisitBuiltin*(x: SyntaxTree.Builtin);
		BEGIN HALT(100) (* abstract *) END VisitBuiltin;

		PROCEDURE VisitOperator*(x: SyntaxTree.Operator);
		BEGIN HALT(100) (* abstract *) END VisitOperator;

		PROCEDURE VisitImport*(x: SyntaxTree.Import);
		BEGIN HALT(100) (* abstract *) END VisitImport;

		(* copy src to value string replacing substrings that are embraced between refSymbols by expression value *)
		PROCEDURE TranslateString*(cmd: CHAR; CONST str: ARRAY OF CHAR; VAR dest: Strings.String): BOOLEAN;
		CONST
			LeftDelimiter = '{'; RightDelimiter = '}';
		VAR
			position : LONGINT; ch: CHAR;
			destination, expMaker: Scanner.StringMaker; destinationWriter, expressionWriter: Streams.Writer; scanner: Scanner.Scanner; parser: Parser;
			expression: SyntaxTree.Expression; value: Value; len: LONGINT;
			comment: LONGINT;

			PROCEDURE Next(VAR ch: CHAR);
			BEGIN
				IF position = LEN(str) THEN ch := 0X ELSE ch := str[position]; INC(position) END;
			END Next;

			PROCEDURE EvaluateExpression();
			VAR str: Strings.String; reader: Streams.Reader; done: BOOLEAN;
			BEGIN
				reader := expMaker.GetReader();
				scanner := Scanner.NewScanner("", reader, 0, NIL);
				NEW(parser, scanner, NIL);
				REPEAT
					error := FALSE;
					expression := parser.Expression();
					done := GetValue(expression, value);
				UNTIL done OR ~parser.Optional(Scanner.Colon);

				IF done THEN value(Value).WriteValue(destinationWriter);
				ELSE
					destinationWriter.String("#COULD NOT INTERPRETE#");
					error := TRUE;
				END;
			END EvaluateExpression;

		BEGIN
			error := FALSE;
			position := 0;
			Next(ch);
			NEW(destination,256); destinationWriter := destination.GetWriter();
			NEW(expMaker, 256); expressionWriter := expMaker.GetWriter();
			comment := 0;

			WHILE (ch # 0X) DO
				(* copy string literally *)
				IF (comment = 0) & (ch = cmd) THEN
					Next(ch);
					IF ch = LeftDelimiter THEN
						Next(ch);
						REPEAT
							WHILE (ch # 0X) & (ch # RightDelimiter) DO expressionWriter.Char(ch); Next(ch) END;
							IF ch = RightDelimiter THEN
								Next(ch); IF (ch # cmd) THEN expressionWriter.Char(RightDelimiter) END;
							END;
						UNTIL (ch=0X) OR (ch = cmd);
						IF ch # 0X THEN Next(ch) END;
						expressionWriter.Update;
						EvaluateExpression();
						expMaker.Clear;
					ELSE
						destinationWriter.Char(cmd);
					END;
				(* remove comments *)
				ELSIF ch = "(" THEN
					Next(ch);
					IF ch = "*" THEN 
						INC(comment); Next(ch);
					ELSIF comment = 0 THEN 
						destinationWriter.Char("(");
					END;
				ELSIF ch="*" THEN
					Next(ch);
					IF ch = ")" THEN 
						DEC(comment); 
						IF comment < 0 THEN comment := 0 END; Next(ch);
					ELSIF comment = 0 THEN 
						destinationWriter.Char("*")
					END;
				ELSE
					IF comment = 0 THEN destinationWriter.Char(ch) END;
					Next(ch);
				END;
			END;
			destinationWriter.Update;
			dest := destination.GetString(len);
			RETURN ~error
		END TranslateString;
		
		PROCEDURE VisitCommandStatement(x: CommandStatement);
		VAR t: Strings.String; res: LONGINT; msg: ARRAY 128 OF CHAR; i: LONGINT; array: Strings.StringArray; pos: LONGINT;
			command: ARRAY 256 OF CHAR; context: Commands.Context;

			PROCEDURE CreateContext(paramString : Strings.String; pos: LONGINT) : Commands.Context;
			VAR c : Commands.Context; arg : Streams.StringReader; dummy : ARRAY 1 OF CHAR; len: LONGINT;
			BEGIN
				IF (paramString = NIL) THEN
					NEW(arg, 1); dummy := ""; arg.SetRaw(dummy, 0, 1);
				ELSE
					len := Strings.Length(paramString^)+1 (*+1 to include 0X *);
					NEW(arg, len-pos); arg.SetRaw(paramString^, pos, len-pos);
				END;
				NEW(c, context.in, arg, context.out, context.error, context.caller);
				RETURN c;
			END CreateContext;

			PROCEDURE IsDelimiter(ch : CHAR) : BOOLEAN;
			CONST 	CR = 0DX;  LF = 0AX;  TAB = 9X;
			BEGIN
				RETURN (ch = " ") OR (ch = CR) OR (ch = LF) OR (ch = TAB) OR (ch = ";") OR (ch = 0X);
			END IsDelimiter;

		BEGIN
			IF SELF.context = NIL THEN
				context := Commands.GetContext();
			ELSE
				context := SELF.context
			END;
			IF TranslateString("?", x.command^, t) THEN END;
			array := Strings.Split(t^, "~");
			FOR i := 0 TO LEN(array)-1 DO
				Strings.TrimWS(array[i]^);
				IF (array[i]^ # "") THEN
						(* extract command *)
						pos := 0;
						WHILE ~IsDelimiter(array[i][pos])  DO command[pos] := array[i][pos]; INC(pos); END;
						command[pos] := 0X;
						IF pos # 0 THEN
							context := CreateContext(array[i], pos);
							Commands.Activate(command, context, {Commands.Wait, Commands.InheritContext}, res, msg);
							IF res # 0 THEN
								context.out.String("Interpreter: "); context.error.String(command); context.error.String(" failed"); context.error.Ln
							END;
						END;
				END;

			END;
			IF res # 0 THEN Error(msg) END;
		END VisitCommandStatement;

		PROCEDURE VisitPrintStatement(x: PrintStatement);
		VAR out: Streams.Writer; printout: Printout.Printer; expression: SyntaxTree.Expression; value: Value;
		BEGIN
		
			out := context.out;
			printout := Printout.NewPrinter(out,Printout.SourceCode,FALSE);
				expression := x.expression;
				IF ~(expression IS SyntaxTree.StringValue) THEN
					printout.Expression(expression);
					out.String("= ");
				END;
				value := Evaluate(expression);
				IF value # NIL THEN
					value.WriteValue(out);
				ELSE
					out.String("UNKNOWN")
				END;
				out.String("; ");
			out.Ln;
			out.Update;
		END VisitPrintStatement;

		(** statements *)
		PROCEDURE VisitStatement*(x: SyntaxTree.Statement);
		BEGIN
			IF x IS CommandStatement THEN
				VisitCommandStatement(x(CommandStatement));
			ELSIF x IS PrintStatement THEN
				VisitPrintStatement(x(PrintStatement));
			ELSE HALT(100)
			END;
		END VisitStatement;

		PROCEDURE VisitProcedureCallStatement*(x: SyntaxTree.ProcedureCallStatement);
		VAR call: SyntaxTree.Designator;
		BEGIN
			IF ~(x.call IS SyntaxTree.ParameterDesignator) THEN
				call := SyntaxTree.NewParameterDesignator(x.position,x.call,SyntaxTree.NewExpressionList());
			ELSE
				call := x.call;
			END;
			call.Accept(SELF);
		END VisitProcedureCallStatement;

		PROCEDURE LoadValue;
		BEGIN
			IF (item.object # NIL) & (item.object IS Result) THEN
				item.object := item.object(Result).Evaluate();
			ELSE
				ErrorSS("could not load value", item.name);
			END;
		END LoadValue;

		PROCEDURE GetValue*(x: SyntaxTree.Expression; VAR w: Value): BOOLEAN;
		BEGIN
			IF error THEN RETURN FALSE END;
			Expression(x);
			IF error THEN RETURN FALSE END;
			LoadValue();
			IF item.object # NIL THEN 
				w := item.object(Value);
			END;
			RETURN ~error
		END GetValue;
		
		PROCEDURE Designate(x: SyntaxTree.Expression): Result;
		BEGIN
			Expression(x);
			IF item.object # NIL THEN 
				RETURN item.object(Result);
			ELSE 
				RETURN NIL
			END;
		END Designate;
		
		PROCEDURE Evaluate(x: SyntaxTree.Expression): Value;
		VAR w: Value;
		BEGIN
			 IF GetValue(x, w) THEN RETURN w ELSE RETURN NIL END;
		END Evaluate;
		

		PROCEDURE GetInteger(x: SyntaxTree.Expression; VAR i: Integer): BOOLEAN;
		VAR v: Value;
		BEGIN
			IF GetValue(x, v) & (v IS Integer) THEN i := v(Integer); RETURN TRUE ELSE RETURN FALSE END;
		END GetInteger;

		PROCEDURE ExpectInteger(x: SyntaxTree.Expression; VAR i: Integer): BOOLEAN;
		BEGIN IF ~GetInteger(x, i) THEN Error("invalid value - must be integer"); RETURN FALSE ELSE RETURN TRUE END;
		END ExpectInteger;

		PROCEDURE GetBoolean(x: SyntaxTree.Expression; VAR i: Boolean): BOOLEAN;
		VAR v: Value;
		BEGIN
			IF GetValue(x, v) & (v IS Boolean) THEN i := v(Boolean); RETURN TRUE ELSE RETURN FALSE END;
		END GetBoolean;

		PROCEDURE ExpectBoolean(x: SyntaxTree.Expression; VAR b: Boolean): BOOLEAN;
		BEGIN IF ~GetBoolean(x, b) THEN Error("invalid value - must be boolean"); RETURN FALSE ELSE RETURN TRUE END;
		END ExpectBoolean;

		PROCEDURE PutValue(x: SyntaxTree.Designator; v: Value);
		BEGIN
			x.Accept(SELF);
			IF (item.object # NIL) & item.object(Result).SetV(v) THEN
			ELSIF (item.in # NIL) & (item.name # 0) & (item.in IS Container) THEN
				item.in(Container).Enter1(v, item.name);
			END;
		END PutValue;

		PROCEDURE VisitAssignment*(x: SyntaxTree.Assignment);
		VAR value: Value;
		BEGIN
			IF GetValue(x.right, value) THEN
				IF x.left # NIL THEN
					PutValue(x.left, value);
				END;
			END;
		END VisitAssignment;

		PROCEDURE IfPart(ifPart: SyntaxTree.IfPart): BOOLEAN;
		VAR value: Boolean;
		BEGIN
			IF ExpectBoolean(ifPart.condition,value) THEN
				IF value(Boolean).value THEN
					StatementSequence(ifPart.statements);
					RETURN TRUE
				END;
			END;
			RETURN FALSE
		END IfPart;

		PROCEDURE VisitIfStatement*(x: SyntaxTree.IfStatement);
		VAR i: LONGINT; elsif: SyntaxTree.IfPart;
		BEGIN
			IF IfPart(x.ifPart) THEN RETURN END;
			FOR i := 0 TO x.ElsifParts()-1 DO
				elsif := x.GetElsifPart(i);
				IF IfPart(elsif) THEN RETURN END;
			END;
			IF x.elsePart # NIL THEN
				StatementSequence(x.elsePart)
			END;
		END VisitIfStatement;

		PROCEDURE VisitWithStatement*(x: SyntaxTree.WithStatement);
		BEGIN HALT(100) (* abstract *) END VisitWithStatement;

		PROCEDURE CasePart(x: SyntaxTree.CasePart; b: SyntaxTree.BinaryExpression): BOOLEAN;
		VAR i: LONGINT; value: Value;
		BEGIN
			FOR i := 0 TO x.elements.Length()-1 DO
				b.SetRight(x.elements.GetExpression(i));
				IF GetValue(b, value) & (value IS Boolean) THEN
					IF value(Boolean).value THEN StatementSequence(x.statements); RETURN TRUE END;
				ELSE Error("invalid non-boolean value")
				END
			END;
			RETURN FALSE
		END CasePart;

		PROCEDURE VisitCaseStatement*(x: SyntaxTree.CaseStatement);
		VAR binary: SyntaxTree.BinaryExpression; i: LONGINT;
		BEGIN
			binary := SyntaxTree.NewBinaryExpression(Basic.invalidPosition, x.variable, x.variable, Scanner.Equal);
			FOR i := 0 TO x.CaseParts()-1 DO
				IF CasePart(x.GetCasePart(i), binary) THEN RETURN END;
			END;
			IF x.elsePart # NIL THEN
				StatementSequence(x.elsePart)
			END;
		END VisitCaseStatement;

		PROCEDURE VisitWhileStatement*(x: SyntaxTree.WhileStatement);
		VAR value: Boolean;
		BEGIN
			WHILE ExpectBoolean(x.condition, value) & value.value DO
				StatementSequence(x.statements);
			END;
		END VisitWhileStatement;

		PROCEDURE VisitRepeatStatement*(x: SyntaxTree.RepeatStatement);
		VAR value: Boolean;
		BEGIN
			REPEAT
				StatementSequence(x.statements);
			UNTIL ~ExpectBoolean(x.condition, value) OR value.value
		END VisitRepeatStatement;

		PROCEDURE VisitForStatement*(x: SyntaxTree.ForStatement);
		VAR fromV, toV, byV: Integer; from, to, by,i: HUGEINT; int: Integer;
		BEGIN
			IF ExpectInteger(x.from, fromV) & ExpectInteger(x.to, toV) THEN
				from := fromV.value;
				to := toV.value;
				Expression(x.variable);
				NEW(int, from);
				PutValue(x.variable, int);
				i := from;
				WHILE i <= to DO
					int.value := i;
					StatementSequence(x.statements);
					INC(i);
				END;
			END;
		END VisitForStatement;

		PROCEDURE VisitLoopStatement*(x: SyntaxTree.LoopStatement);
		VAR prevExit: BOOLEAN;
		BEGIN
			prevExit := exit;
			exit := FALSE;
			LOOP
				StatementSequence(x.statements);
				IF exit THEN EXIT END;
			END;
			exit := prevExit
		END VisitLoopStatement;

		PROCEDURE VisitExitStatement*(x: SyntaxTree.ExitStatement);
		BEGIN
			exit := TRUE
		END VisitExitStatement;

		PROCEDURE VisitReturnStatement*(x: SyntaxTree.ReturnStatement);
		BEGIN HALT(100) (* abstract *) END VisitReturnStatement;

		PROCEDURE VisitAwaitStatement*(x: SyntaxTree.AwaitStatement);
		BEGIN HALT(100) (* abstract *) END VisitAwaitStatement;

		PROCEDURE VisitStatementBlock*(x: SyntaxTree.StatementBlock);
		BEGIN
			StatementSequence(x.statements)
		END VisitStatementBlock;

		PROCEDURE VisitCode*(x: SyntaxTree.Code);
		BEGIN HALT(100) (* abstract *) END VisitCode;

		PROCEDURE Expression(x: SyntaxTree.Expression);
		BEGIN
			value := FALSE;
			x.Accept(SELF);			
		END Expression;
		
		PROCEDURE Statement*(x: SyntaxTree.Statement);
		BEGIN
			item.object := NIL;
			x.Accept(SELF);
		END Statement;

		PROCEDURE StatementSequence*(x: SyntaxTree.StatementSequence);
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO x.Length()-1 DO
				Statement(x.GetStatement(i));
			END;
		END StatementSequence;

	END Interpreter;

	Resolver*= OBJECT
	VAR
		interpreter: Interpreter;
		content: PersistentObjects.Content;
		resolved: Basic.HashTable;
		current: Scope;
		changed: BOOLEAN;

		PROCEDURE & InitResolver*;
		BEGIN
			NEW(content); NEW(resolved,64); NEW(interpreter, NIL, NIL, NIL);
		END InitResolver;

		PROCEDURE Traverse(CONST name: ARRAY OF CHAR; array: BOOLEAN);
		VAR index: LONGINT; success: BOOLEAN;
		BEGIN
			IF array THEN index := 0 ELSE index := -1 END;
			REPEAT
				success := FALSE;
				content.success := FALSE;
				current.object.Get(name, index, content);
				IF content.success & (content.class = PersistentObjects.Class.Object) THEN
					success := content.object # NIL;
					IF content.object # NIL THEN
						DoResolve(current.Enter(content.object)); (* content object can be overwritten as sideeffect! *)
					END;
				END;
				INC(index);
			UNTIL ~array OR ~success
		END Traverse;

		PROCEDURE DoResolve*(scope: Scope);
		VAR translation: PersistentObjects.Interpretation; prev: Scope; str: Strings.String;
		BEGIN
			IF (scope.object # NIL) & ~resolved.Has(scope.object) THEN
				prev := current;
				current := scope;
				resolved.Put(scope.object, SELF);
				interpreter.Init(scope, NIL, NIL);

				translation := scope.object.firstTranslation;
				WHILE translation # NIL DO
					IF EnableTrace THEN D.String("resolve "); D.String(translation.name^); D.String(":"); D.String(translation.str^); END;
					IF interpreter.TranslateString("?", translation.str^,  str) THEN
						IF EnableTrace THEN D.String(":"); D.Str(str^); END;
						scope.object.Get(translation.name^, -1, content);
						IF ~content.Equals(str^) THEN
							changed := TRUE;
							content.SetAsString(str^);
						END;
						scope.object.Set(translation.name^, -1, content);
					ELSE
						IF EnableTrace THEN D.String(":could not resolve"); END;
					END;
					IF EnableTrace THEN D.Ln; END;
					translation := translation.next
				END;

				scope.object.Enumerate(Traverse);

				current := prev;
			END;
		END DoResolve;

		PROCEDURE Resolve*(scope: Scope);
		BEGIN
			REPEAT
				changed := FALSE;
				resolved.Clear();
				DoResolve(scope);
			UNTIL ~changed;
		END Resolve;

	END Resolver;

VAR global-: Scope;

PROCEDURE Statements*(context: Commands.Context);
VAR scanner: Scanner.Scanner; parser: Parser; diagnostics: Diagnostics.StreamDiagnostics;
	seq: SyntaxTree.StatementSequence; interpreter: Interpreter;
BEGIN
	NEW(diagnostics, context.error);
	scanner := Scanner.NewScanner("",context.arg,0,diagnostics);
	NEW(parser, scanner, diagnostics);
	seq := parser.StatementSequence(NIL);
	NEW(interpreter, global, diagnostics,context); interpreter.StatementSequence(seq);
END Statements;

PROCEDURE Expression*(context: Commands.Context);
VAR scanner: Scanner.Scanner; parser: Parser; diagnostics: Diagnostics.StreamDiagnostics;
	interpreter: Interpreter; value: Value; expression: SyntaxTree.Expression;
BEGIN
	NEW(diagnostics, context.error);
	scanner := Scanner.NewScanner("",context.arg,0,diagnostics);
	NEW(parser, scanner, diagnostics);
	expression := parser.Expression();
	NEW(interpreter, global, diagnostics,NIL);
	IF interpreter.GetValue(expression, value) THEN
		value(Value).WriteValue(context.out); context.out.Ln
	ELSE
		context.error.String("could not evaluate expression"); context.error.Ln
	END;
END Expression;

PROCEDURE TranslateString*(context: Commands.Context);
VAR dest: Strings.String; testString: ARRAY 256 OF CHAR; interpreter: Interpreter; streamDiagnostics: Diagnostics.StreamDiagnostics;
BEGIN
	NEW(streamDiagnostics, context.error);
	NEW(interpreter, global, streamDiagnostics,NIL);
	WHILE context.arg.GetString(testString) DO
		IF interpreter.TranslateString("?", testString, dest) THEN
			context.out.String("RESULT: ");
			context.out.String(dest^);
			context.out.Ln;
		ELSE
			context.error.String("could not translate: ");
			context.error.String(dest^);
			context.error.Ln;
		END;
	END;
END TranslateString;

PROCEDURE InitGlobalScope;
VAR container: Container;
BEGIN
	NEW(container);
	NEW(global, NIL, container);
END InitGlobalScope;

VAR c: LONGINT;
VAR d: RECORD e: LONGINT END;

	PROCEDURE Getter(): LONGINT;
	BEGIN
		RETURN 123;
	END Getter;

	PROCEDURE Setter(a: LONGINT): LONGINT;
	BEGIN
		TRACE(a);
		RETURN a+123;
	END Setter;
	
	TYPE TestO= OBJECT
	VAR i: LONGINT;
	PROCEDURE &P(s: SHORTINT);
	BEGIN
		i := 999+s;
	END P;
	
	END TestO;
	

BEGIN
	InitGlobalScope;
	c := 10; 
	d.e := 20;
END FoxInterpreter.

SystemTools.FreeDownTo FoxInterpreterSymbols ~ FoxInterpreter FoxInterpreterSymbols Reflection2 ~

FoxInterpreter.Expression
	FoxInterpreter.c ~

FoxInterpreter.Expression
	-8 ~

FoxInterpreter.Expression
	FoxInterpreter.d.e ~

FoxInterpreter.Expression
	FoxInterpreter.Getter() ~

FoxInterpreter.Expression
	FoxInterpreter.Setter(1000) ~

FoxInterpreter.Statements
	a := NEW FoxInterpreter.TestO(-8);
	trace(a.i);
	a.i := 10;
	KernelLog.Int(a.i,1);
	KernelLog.Ln;
	~

FoxInterpreter.Expression
	Test.c.b;
	~ 
	
FoxInterpreter.Expression
	Test.Test(5);
	~
FoxInterpreter.Statements
	a := Test.c.b;
	Test.c.b := Test.c.b + 1;
	~	
FoxInterpreter.Expression
	a;
	~	
FoxInterpreter.Expression
	Test.c.b;
	~	

FoxInterpreter.Statements
	Test.Test(123)
	~

FoxInterpreter.Statements
	FOR i := 1 TO 100 DO
		CASE i MOD 10 OF
		1: suffix := "st"
		|2: suffix := "nd"
		|3: suffix := "rd"
		ELSE suffix := "th"
		END;
		IF i MOD 9 = 0 THEN
			! "SystemTools.Show This is the ?{i}??{suffix}? run." ;
			! "SystemTools.Ln";
		END;
	END;
~
FoxInterpreter.Expression
	i MOD 10  ~

FoxInterpreter.Statements
	o := Test.TestO();
	~
	
	

FoxInterpreter.Statements
	s := {0..10, 15};
	a := 10;
	b := 10..20;
	c := {a,b};
	x := 10;
	y := 20;
	z := x;
	z := x + y;
	b := x = y;
	nb := x # y;
	FOR i := 0 TO 3 DO
		a := i;
		IF i<2 THEN
			a := 200+i;
		END;
		CASE i OF
		0: a := 2000;
		|2: HALT(100)
		END;
	END;
	~
	TRACE(x);

	FOR i := 0 TO 100 DO
		x[i] := i
	END;
	~

FoxInterpreter.TranslateString
	"This is a string ?{15+2*20*a:32}? oha."
	"The rest of this string will be evaluated ?{3+5 = 20}?"
	"?{ 100*15"
	"a set in a evaluated expression ?{{1,2,4}}?"
	~

FoxInterpreter.Statements
	a := [[1,2,3],[4,5,6],[7,8,9]];
	FOR i := 0 TO 2 DO
	FOR j := 0 TO 2 DO
		! \+"SystemTools.Show ?{a[i,j]}? ;"+\
	END;
		! \+"SystemTools.Ln;"+\ 
	END;
	! "SystemTools.Show ?{a}? ";
	? a;
	? 1+1;
	? 1+2;
	~

SystemTools.FreeDownTo FoxInterpreter FoxInterpreterSymbols ~
