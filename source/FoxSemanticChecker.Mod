MODULE FoxSemanticChecker; (* AUTHOR "fof & fn"; PURPOSE "Oberon Compiler: Semantic Checker"; *)
(* (c) fof ETHZ 2009 *)

IMPORT D := Debugging, Basic := FoxBasic, Scanner := FoxScanner, SyntaxTree := FoxSyntaxTree,
Diagnostics, Global := FoxGlobal, Printout:= FoxPrintout, Formats := FoxFormats, SYSTEM, Strings;

CONST
	Trace = FALSE;

	Infinity = MAX(LONGINT); (* for type distance *)
	UndefinedPhase = 0; DeclarationPhase=1; ImplementationPhase=2;

	InliningSupport = TRUE;

TYPE
	Position=SyntaxTree.Position;
	FileName=ARRAY 256 OF CHAR;

	LateFix= POINTER TO RECORD (* contains a late fix to be resolved in a later step: type fixes and implementations *)
		p: ANY; scope: SyntaxTree.Scope;
		next: LateFix;
	END;

	LateFixList = OBJECT (* fifo queue for items to be resolved later on - deferred fixes *)
	VAR first,last: LateFix;

		PROCEDURE & Init;
		BEGIN first := NIL; last := NIL;
		END Init;

		(* get and remove element from list *)
		PROCEDURE Get(VAR scope: SyntaxTree.Scope): ANY;
		VAR p: ANY;
		BEGIN
			IF first # NIL THEN p := first.p; scope := first.scope; first := first.next ELSE p := NIL; END;
			IF first = NIL THEN last := NIL END;
			RETURN p;
		END Get;

		(* add unresolved type to list *)
		PROCEDURE Add(p: ANY; scope: SyntaxTree.Scope);
		VAR next: LateFix;
		BEGIN
			ASSERT(scope # NIL);
			NEW(next); next.p := p; next.scope := scope;
			next.next := NIL;
			IF first = NIL THEN first := next; last := next;
			ELSE last.next := next; last := next
			END;
		END Add;

	END LateFixList;

	WithEntry = POINTER TO RECORD
		previous: WithEntry;
		symbol: SyntaxTree.Symbol;
		type: SyntaxTree.Type;
	END;

	Replacement*= POINTER TO RECORD
		name*: Basic.SegmentedName;
		expression*: SyntaxTree.Expression;
		used*: BOOLEAN;
		next*: Replacement;
	END;

	(** checker object: used to check and resolve a module
		- resolves types
		- resolves expressions
		- resolves designators
		- resolves declarations
		- resolves statements
		- resolves implementations (bodies)
	**)
	Checker*= OBJECT
	VAR
		module: SyntaxTree.Module;
		diagnostics: Diagnostics.Diagnostics;
		cooperative: BOOLEAN;
		error-: BOOLEAN;
		VerboseErrorMessage: BOOLEAN;
		typeFixes, pointerFixes: LateFixList;
		importCache-: SyntaxTree.ModuleScope; (* contains global imports, did not take ImportList as it was much slower, for whatever reasons *)
		arrayBaseImported: BOOLEAN;
		complexNumbersImported: BOOLEAN;
		phase: LONGINT;
		system-: Global.System;
		symbolFileFormat-: Formats.SymbolFileFormat;
		backendName-: ARRAY 32 OF CHAR;
		inConversion: LONGINT;

		(* temporary variables for the visitors
			they replace variables on a stack during use of the visitor pattern and may only be
			- set in AcceptXXX procedures
			- set and read in ResolveXXX procedures
		*)
		currentScope-: SyntaxTree.Scope;
		currentIsRealtime: BOOLEAN;
		currentIsUnreachable: BOOLEAN;
		currentIsCellNet: BOOLEAN;
		currentIsBodyProcedure: BOOLEAN;
		currentIsExclusive: BOOLEAN;
		currentResultType: SyntaxTree.Type;
		global: SyntaxTree.ModuleScope;
		withEntries: WithEntry;
		activeCellsStatement: BOOLEAN;
		replacements*: Replacement;
		cellsAreObjects: BOOLEAN;
		variableAccessed: BOOLEAN;

		PROCEDURE &InitChecker*(diagnostics: Diagnostics.Diagnostics; verboseErrorMessage,cooperative: BOOLEAN; system: Global.System; symbolFileFormat: Formats.SymbolFileFormat; VAR importCache: SyntaxTree.ModuleScope; CONST backend: ARRAY OF CHAR);
		BEGIN
			SELF.diagnostics := diagnostics;
			SELF.cooperative := cooperative;
			SELF.system := system;
			SELF.symbolFileFormat := symbolFileFormat;
			error := FALSE;
			NEW(typeFixes);
			NEW(pointerFixes);
			currentScope := NIL;
			IF importCache = NIL THEN importCache := SyntaxTree.NewModuleScope() END;
			SELF.importCache := importCache;
			arrayBaseImported := FALSE;
			complexNumbersImported := FALSE;
			SELF.VerboseErrorMessage := verboseErrorMessage;
			global := NIL;
			phase := UndefinedPhase;
			currentIsRealtime := FALSE;
			currentIsUnreachable := FALSE;
			currentIsCellNet := FALSE;
			currentIsBodyProcedure := FALSE;
			currentIsExclusive := FALSE;
			withEntries := NIL;
			SELF.cellsAreObjects := system.cellsAreObjects;
			COPY(backend, backendName);
			inConversion := 0;
		END InitChecker;

		(*------------ service -------------*)
		(** report error **)
		PROCEDURE Error(position: Position; CONST message: ARRAY OF CHAR);
		VAR errModule: SyntaxTree.Module;
		BEGIN
			ASSERT(currentScope # NIL);
			IF module # NIL THEN errModule := module ELSE errModule := currentScope.ownerModule END;
			Basic.ErrorC(diagnostics, errModule.sourceName, position, Basic.InvalidCode, message);
			error := TRUE;
		END Error;

		PROCEDURE Warning(position: Position; CONST message: ARRAY OF CHAR);
		VAR errModule: SyntaxTree.Module;
		BEGIN
			IF module # NIL THEN errModule := module ELSE errModule := currentScope.ownerModule END;
			Basic.Warning(diagnostics, errModule.sourceName, position, message);
		END Warning;

		PROCEDURE ErrorSS(position: Position; CONST msg,msg2: ARRAY OF CHAR);
		VAR errorMessage: ARRAY 256 OF CHAR;
		BEGIN
			Basic.Concat(errorMessage,msg," ", msg2);
			Basic.Error(diagnostics, currentScope.ownerModule.sourceName, position, errorMessage);
			error := TRUE;
		END ErrorSS;

		PROCEDURE InfoSS(position: Position; CONST msg1: ARRAY OF CHAR; CONST s: Basic.String);
		VAR msg, msg2: ARRAY 256 OF CHAR;
		BEGIN
			COPY(msg1, msg);
			Strings.Append(msg, " = ");
			Basic.GetString(s, msg2);
			Strings.Append(msg, msg2);
			Basic.Information(diagnostics, currentScope.ownerModule.sourceName, position, msg);
		END InfoSS;

		(*** symbol lookup ***)

		(** find a symbol in the current scope, traverse to outer scope if traverse=true and no symbol found yet
		**)
		PROCEDURE Find(inScope: SyntaxTree.Scope; name: SyntaxTree.Identifier; traverse: BOOLEAN): SyntaxTree.Symbol;
		VAR
			scope,baseScope: SyntaxTree.Scope;
			symbol, s: SyntaxTree.Symbol;
			ownerRecord,base: SyntaxTree.RecordType;
		BEGIN
			scope := inScope;
			symbol := NIL;

			WHILE (scope # NIL) & (symbol = NIL) DO
				symbol := scope.FindSymbol(name);
				s := NIL;
				IF (symbol # NIL) & (symbol.access * SyntaxTree.Public = {}) & (symbol.scope IS SyntaxTree.CellScope) (* hidden copies of parameters *) THEN
					s := symbol.scope(SyntaxTree.CellScope).ownerCell.FindParameter(name);
				ELSIF (symbol = NIL) & (scope IS SyntaxTree.CellScope) THEN
					symbol := scope(SyntaxTree.CellScope).ownerCell.FindParameter(name);
				END;

				IF (symbol # NIL) & (symbol IS SyntaxTree.Parameter) & (symbol.scope IS SyntaxTree.CellScope) THEN (* ok, symbol auto-export in scope *)
				ELSIF s # NIL THEN (* hidden variable shadows port parameter *)
				ELSE
					WHILE (symbol # NIL) & (symbol.scope.ownerModule # currentScope.ownerModule) & (symbol.access * SyntaxTree.Public = {}) DO
						(* found symbol in different module, but is it not exported, can we go on searching in record base scopes ? *)
						symbol.MarkUsed;
						IF (symbol.scope IS SyntaxTree.RecordScope) THEN
							ownerRecord := symbol.scope(SyntaxTree.RecordScope).ownerRecord;
							base := RecordBase(ownerRecord);
							IF (base # NIL) THEN
								baseScope := base.recordScope;
								symbol := Find(baseScope,name,FALSE);
							ELSE
								symbol := NIL;
							END;
						ELSE
							symbol := NIL;
						END;
					END;
				END;
				IF traverse THEN scope := scope.outerScope ELSE scope := NIL END;
			END;
			IF (symbol # NIL) THEN
				IF ~(SyntaxTree.Resolved IN symbol.state) THEN
					(*ASSERT(phase = DeclarationPhase);*)
					ResolveSymbol(symbol)
				END;
				symbol.MarkUsed;
			END;
			RETURN symbol
		END Find;

		(*------------ types -------------*)

		(** find type declaration with name qualifiedIdentifier and return resolved type
			- check qualified identifier prefix, set scope to module scope if appropriate
			- check suffix in scope
		**)
		PROCEDURE ResolveNamedType(qualifiedIdentifier: SyntaxTree.QualifiedIdentifier; VAR typeDeclaration: SyntaxTree.TypeDeclaration): SyntaxTree.Type;
		VAR prevScope: SyntaxTree.Scope; symbol: SyntaxTree.Symbol; result:SyntaxTree.Type;
		BEGIN
			result := NIL;
			prevScope := currentScope;
			IF (qualifiedIdentifier.prefix # SyntaxTree.invalidIdentifier) THEN
				symbol := Find(currentScope,qualifiedIdentifier.prefix,TRUE);
				IF (symbol # NIL) & (symbol IS SyntaxTree.Import) THEN
					IF symbol(SyntaxTree.Import).module = NIL THEN
						Error(qualifiedIdentifier.position,"module not loaded");
						result := SyntaxTree.invalidType;
						symbol := NIL;
					ELSE
						currentScope := symbol(SyntaxTree.Import).module.moduleScope;
						symbol := Find(currentScope,qualifiedIdentifier.suffix,FALSE);

						IF (symbol = NIL) OR (symbol.access * SyntaxTree.Public = {}) THEN
							IF VerboseErrorMessage THEN
								Printout.Info("scope", currentScope);
								Printout.Info("symbol", symbol);
							END;
							Error(qualifiedIdentifier.position,"undeclared identifier (prefix-suffix)")
						END;
					END;
				ELSE
					D.Str0(qualifiedIdentifier.prefix);D.Ln;
					Error(qualifiedIdentifier.position,"prefix does not denote a module name");
					symbol := NIL;
				END;
			ELSE
				symbol := Find(currentScope,qualifiedIdentifier.suffix,TRUE);
				IF symbol = NIL THEN
					Error(qualifiedIdentifier.position,"undeclared identifier (qualident suffix)");
					IF VerboseErrorMessage THEN
						Printout.Info("Qualident",qualifiedIdentifier);
						Printout.Info("in scope",currentScope) ;
					END;
				END;
			END;

			IF symbol = NIL THEN (* error already handled *)
				typeDeclaration := NIL;
				result := SyntaxTree.invalidType;
			ELSIF ~(symbol IS SyntaxTree.TypeDeclaration) THEN
				Error(qualifiedIdentifier.position,"symbol does not denote a type");
				typeDeclaration := NIL;
				result := SyntaxTree.invalidType;
			ELSE
				currentScope := symbol.scope;
				typeDeclaration := symbol(SyntaxTree.TypeDeclaration);
				result := ResolveType(typeDeclaration.declaredType);
				symbol.MarkUsed;
				ASSERT(result # NIL);
			END;
			currentScope := prevScope;
			RETURN result
		END ResolveNamedType;

		(**
			check enumeration scope: enter symbols and check for duplicate names
		**)
		PROCEDURE CheckEnumerationScope(x: SyntaxTree.EnumerationScope; VAR highest: Basic.Integer);
		VAR e: SyntaxTree.Constant; value: SyntaxTree.Expression; nextHighest: Basic.Integer; prevScope: SyntaxTree.Scope;
		BEGIN
			prevScope := currentScope;
			currentScope := x;
			e := x.firstConstant;
			nextHighest := highest;
			WHILE (e # NIL) DO
				Register(e,x,FALSE);
				IF SymbolNeedsResolution(e) THEN
					IF e.value # NIL THEN
						value := ConstantExpression(e.value);
						value := NewConversion(e.position,value,x.ownerEnumeration,NIL);
					ELSE
						value := SyntaxTree.NewEnumerationValue(e.position,nextHighest+1);
						value.SetType(x.ownerEnumeration);
					END;
					IF (value.resolved # NIL) & (value.resolved IS SyntaxTree.EnumerationValue) THEN
						nextHighest := value.resolved(SyntaxTree.EnumerationValue).value;
						IF nextHighest > highest THEN highest := nextHighest END;
					END;
					e.SetValue(value);
					CheckSymbolVisibility(e);
					e.SetType(x.ownerEnumeration);
					e.SetState(SyntaxTree.Resolved);
				END;
				e := e.nextConstant;
			END;
			currentScope := prevScope;
		END CheckEnumerationScope;

		(**
			resolve enumeration type: check enumeration scope
		**)
		PROCEDURE ResolveEnumerationType(x: SyntaxTree.EnumerationType);
		VAR position: Position; baseScope: SyntaxTree.EnumerationScope; baseType,resolved: SyntaxTree.Type; enumerationBase: SyntaxTree.EnumerationType;
			lowest, highest: Basic.Integer;
		BEGIN
			IF x.enumerationBase # NIL THEN
				position := x.enumerationBase.position;
				baseType := ResolveType(x.enumerationBase);
				resolved := baseType.resolved;
				baseScope := NIL;
				IF resolved = SyntaxTree.invalidType THEN (* error already handled *)
				ELSIF ~(resolved IS SyntaxTree.EnumerationType) THEN
					Error(position, "base type is no enumeration type");
				ELSE
					enumerationBase := resolved(SyntaxTree.EnumerationType);
					lowest := enumerationBase.rangeHighest+1;
				END;
				x.SetEnumerationBase(baseType);
			ELSE lowest := 0;
			END;
			highest := lowest-1;
			CheckEnumerationScope(x.enumerationScope, highest);
			x.SetRange(lowest, highest);
			x.SetState(SyntaxTree.Resolved);
		END ResolveEnumerationType;

		(**
			resolve qualified type
			- find and resolve named type and set resolved type
		**)
		PROCEDURE ResolveQualifiedType(x: SyntaxTree.QualifiedType);
		VAR type: SyntaxTree.Type; typeDeclaration: SyntaxTree.TypeDeclaration;
		BEGIN
			type := ResolveNamedType(x.qualifiedIdentifier, typeDeclaration);
			x.SetResolved(type.resolved);
			x.SetState(SyntaxTree.Resolved);
			x.SetTypeDeclaration (typeDeclaration);
			(*
			ELSIF ~(SyntaxTree.Resolved IN x.state) THEN
				x.SetResolved(SyntaxTree.invalidType);
			END;
			*)
		END ResolveQualifiedType;

		(**
			resolve array type
			- check base type
				- array of math array  forbidden
				- static array of open array forbidden
		**)
		PROCEDURE ResolveArrayType(x: SyntaxTree.ArrayType);
		VAR arrayBase: SyntaxTree.Type; e: SyntaxTree.Expression; pointerType: SyntaxTree.PointerType;
		BEGIN
			x.SetArrayBase(ResolveType(x.arrayBase));
			IF x.arrayBase.resolved.isRealtime THEN x.SetRealtime(TRUE) END;
			arrayBase := x.arrayBase.resolved;
			IF (arrayBase IS SyntaxTree.CellType) (*& (cellsAreObjects)*) THEN
				pointerType := SyntaxTree.NewPointerType(x.position, x.scope);
				pointerType.SetPointerBase(arrayBase);
				pointerType.SetHidden(TRUE);
				IF x.arrayBase IS SyntaxTree.QualifiedType THEN
					x.arrayBase(SyntaxTree.QualifiedType).SetResolved(pointerType)
				ELSE
					x.SetArrayBase(pointerType);
				END;
			END;
			IF x.length # NIL THEN
				variableAccessed := FALSE;
				e := ResolveExpression(x.length);

				IF (e.resolved = NIL) THEN
					IF variableAccessed THEN
						Error(e.position, "forbidden variable access");
					END;
					IF CheckSizeType(e) THEN
						x.SetLength(e); x.SetForm(SyntaxTree.SemiDynamic);
					END;
				ELSE
					x.SetLength(ConstantIntegerGeq0(e (*x.length*)));
				END;
			END;

			IF arrayBase IS SyntaxTree.ArrayType THEN
				IF (x.form = SyntaxTree.Static) & (arrayBase(SyntaxTree.ArrayType).form = SyntaxTree.Open) THEN
					Error(x.position,"forbidden static array of dynamic array");
				END;
			ELSIF arrayBase IS SyntaxTree.MathArrayType THEN
				Error(x.position,"forbidden array mixed form");
			END;
			x.SetHasPointers(arrayBase.hasPointers);
			x.SetState(SyntaxTree.Resolved);
		END ResolveArrayType;

		PROCEDURE ImportModule(name: SyntaxTree.Identifier; position: Position);
		VAR module: SyntaxTree.Module; import, duplicate: SyntaxTree.Import; moduleScope: SyntaxTree.ModuleScope;
		BEGIN
			module := currentScope.ownerModule;
			IF module.name=name THEN
				(* do nothing *)
			ELSE
				moduleScope := module.moduleScope;
				import := moduleScope.FindImport(name);
				IF import = NIL THEN
					import := SyntaxTree.NewImport(position,name,name,TRUE);
					moduleScope.AddImport(import);
					Register(import,moduleScope,FALSE);
					IF import.context = SyntaxTree.invalidIdentifier THEN import.SetContext(SELF.module.context) END;
					ResolveImport(import);
				ELSIF import.direct=FALSE THEN
					import.SetScope(module.moduleScope);
					import.SetDirect(TRUE);
					IF moduleScope.FindSymbol(import.name) = NIL THEN
						duplicate := SyntaxTree.NewImport(Basic.invalidPosition,import.name, import.name,FALSE);
						duplicate.SetContext(import.context);
						duplicate.SetModule(import.module);
						Register(duplicate,moduleScope,TRUE);
						ResolveImport(duplicate);
					END;
				END;
				import.MarkUsed
			END;
		END ImportModule;

		(**
			resolve math array type
			- check base type
				- open math array of array  forbidden
				- math array of tensor forbidden
				- static array of open array forbidden
		**)
		PROCEDURE ResolveMathArrayType(x: SyntaxTree.MathArrayType);
		VAR arrayBase: SyntaxTree.Type; modifiers: SyntaxTree.Modifier; position: SyntaxTree.Position;
		BEGIN
			x.SetArrayBase(ResolveType(x.arrayBase));
			IF x.length # NIL THEN
				x.SetLength(ConstantIntegerGeq0(x.length));
			END;
			arrayBase := x.arrayBase;
			IF arrayBase # NIL THEN
				arrayBase := arrayBase.resolved;
				IF arrayBase = SyntaxTree.invalidType THEN
					(* error already handled *)
				ELSIF arrayBase IS SyntaxTree.ArrayType THEN
					Error(x.position,"forbidden array mixed form");
				ELSIF arrayBase IS SyntaxTree.MathArrayType THEN
					IF (x.form = SyntaxTree.Tensor) OR (arrayBase(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor) THEN
						Error(x.position,"forbidden Tensor Array mix")
					ELSIF (x.form=SyntaxTree.Static) & (arrayBase(SyntaxTree.MathArrayType).form # SyntaxTree.Static) THEN
						Error(x.position,"forbidden static array of dynamic array")
					END;
				END;
				IF x.form = SyntaxTree.Static THEN
					x.SetIncrement(system.SizeOf(arrayBase));
				END;
				x.SetHasPointers((x.form # SyntaxTree.Static) OR arrayBase.hasPointers);
			END;
			modifiers := x.modifiers;
			x.SetUnsafe(HasFlag(modifiers,Global.NameUnsafe,position));
			CheckModifiers(modifiers, TRUE);
			x.SetState(SyntaxTree.Resolved);
		END ResolveMathArrayType;

		(* anonymous type declarations are used for variables that use an anonymous type. They are not used for records that are
			pointed to by a pointer to record. The following diagram shows the possible cases for records and pointer to records.

			(1) Rec = RECORD ... END;					Ptr		<--->		Rec
				Ptr = POINTER TO Rec;						^				|
																|				|
															TypeDesc			TypeDesc

			(2)	Obj = POINTER TO RECORD .. END;		Obj		<--->		Record
																^				/
																|			/
															TypeDesc	<-- /
		*)

		PROCEDURE AnonymousTypeDeclaration(x: SyntaxTree.Type; CONST prefix: ARRAY OF CHAR);
		VAR typeDeclaration: SyntaxTree.TypeDeclaration; name,number: Scanner.IdentifierString;
		BEGIN
			Strings.IntToStr(x.position.start,number);
			COPY(prefix,name);
			Strings.Append(name,"@");
			Strings.Append(name,number);
			typeDeclaration := SyntaxTree.NewTypeDeclaration(x.position,SyntaxTree.NewIdentifier(name));
			typeDeclaration.SetDeclaredType(x);
			typeDeclaration.SetAccess(SyntaxTree.Hidden);
			x.SetTypeDeclaration(typeDeclaration);
			currentScope.AddTypeDeclaration(typeDeclaration);
			typeDeclaration.SetScope(currentScope);
		END AnonymousTypeDeclaration;

		(**
			deferred pointer type resolving
			- resolve base type
			- check that base type is a record or array type
			- if error then set base type to invalid type
		**)
		PROCEDURE FixPointerType(type: SyntaxTree.PointerType);
		VAR resolved, base: SyntaxTree.Type; position: Position; recordType: SyntaxTree.RecordType;
		BEGIN
			ASSERT(type.pointerBase # NIL);
			position := type.pointerBase.position;
			IF (type.pointerBase IS SyntaxTree.RecordType) THEN (* direct POINTER TO RECORD *)
				type.pointerBase(SyntaxTree.RecordType).SetPointerType(type);
				(* not for pointers, a type is needed for the records only
				IF type.typeDeclaration = NIL THEN
					AnonymousTypeDeclaration(type);
				END;
				*)
			END;
			resolved := ResolveType(type.pointerBase);
			IF (resolved.resolved IS SyntaxTree.RecordType) OR (resolved.resolved IS SyntaxTree.ArrayType) OR (resolved.resolved IS SyntaxTree.CellType) THEN
				type.SetPointerBase(resolved);
				IF (resolved.resolved IS SyntaxTree.RecordType) THEN
					recordType := resolved.resolved(SyntaxTree.RecordType);
					IF recordType.isObject & (recordType.baseType # NIL) THEN
						IF type.isRealtime & ~recordType.baseType.resolved.isRealtime THEN
							Error(position, "base type of object must be a realtime object");
						ELSIF ~type.isRealtime & recordType.baseType.resolved.isRealtime THEN
							Error(position, "extensions of realtime objects must be explicitly declared as realtime objects");
						END;
					END;
				END;
				IF type.isRealtime & ~resolved.resolved.isRealtime THEN
					Error(position, "realtime object contains references to non-realtime objects");
				END;
				IF type.isUnsafe & (resolved.resolved IS SyntaxTree.ArrayType) THEN
					(*IF ~IsOpenArray(resolved.resolved, base) THEN
						Error(position, "forbidden unsafe at static array");
					ELS
					*)
					IF IsOpenArray(resolved.resolved(SyntaxTree.ArrayType).arrayBase, base) THEN
						Error(position, "forbidden unsafe at multidimensional array");
					END;
				END;
			ELSE
				Error(position, "forbidden pointer base type");
				type.SetPointerBase(SyntaxTree.invalidType)
			END
		END FixPointerType;

		(**
			resolve pointer type
			- enter pointer type to list of deferred fixes (to avoid infinite loops in the declaration phase)
		**)
		PROCEDURE ResolvePointerType(x: SyntaxTree.PointerType);
		VAR recordType: SyntaxTree.RecordType; recordBaseType: SyntaxTree.Type;
		modifiers: SyntaxTree.Modifier; position: Position;
		BEGIN
			modifiers := x.modifiers;
			x.SetRealtime(HasFlag(modifiers,Global.NameRealtime, position));
			x.SetPlain(HasFlag(modifiers,Global.NamePlain,position));
			x.SetDisposable(HasFlag(modifiers,Global.NameDisposable, position));
			x.SetUnsafe(HasFlag(modifiers,Global.NameUnsafe,position));
			x.SetUntraced(HasFlag(modifiers,Global.NameUntraced,position));
			(* inheritance cycle check
				example:
				A=POINTER TO RECORD(B) END;
				B=POINTER TO RECORD(A) END;
			*)
			IF x.pointerBase IS SyntaxTree.RecordType THEN
				recordType := x.pointerBase(SyntaxTree.RecordType);
				IF x.isRealtime THEN recordType.SetRealtime(TRUE) END;
				recordBaseType := ResolveType(recordType.baseType);
				recordType.SetBaseType(recordBaseType);
				recordType.SetProtected(HasFlag(modifiers, Global.NameExclusive, position));
				recordType.SetAbstract(HasFlag(modifiers, Global.NameAbstract, position));
			END;
			CheckModifiers(modifiers, TRUE);
			typeFixes.Add(x,currentScope);
			x.SetState(SyntaxTree.Resolved);
		END ResolvePointerType;

		(**
			resolve port type
			- enter port type to list of deferred fixes (to avoid infinite loops in the declaration phase)
		**)
		PROCEDURE ResolvePortType(x: SyntaxTree.PortType);
		VAR value: Basic.Integer;
		BEGIN
			x.SetCellsAreObjects(cellsAreObjects);
			x.SetSizeExpression(ResolveExpression(x.sizeExpression));
			IF (x.sizeExpression # NIL) & CheckPositiveIntegerValue(x.sizeExpression,value,FALSE) THEN
				x.SetSize(LONGINT(value)) (* TODO: fix explicit integer truncation *)
			ELSE
				x.SetSize(system.SizeOf(system.longintType));
			END;
			x.SetState(SyntaxTree.Resolved);
		END ResolvePortType;

		(**
			deferred procedure type resolving
			- resolve return type
			- traverse and resolve parameters
		**)
		PROCEDURE FixProcedureType(procedureType: SyntaxTree.ProcedureType);
		VAR resolved: SyntaxTree.Type; parameter: SyntaxTree.Parameter;
		BEGIN
				resolved := ResolveType(procedureType.returnType);
				IF (resolved # NIL) & (resolved.resolved IS SyntaxTree.ArrayType) & (resolved.resolved(SyntaxTree.ArrayType).length = NIL) THEN
					Error(procedureType.position,"forbidden open array return type");
				ELSIF (resolved # NIL) & (procedureType.noReturn) THEN
					Error(procedureType.position,"procedure with return type does not return");
				END;

				procedureType.SetReturnType(resolved);
				IF (resolved # NIL) & StructuredReturnType (system,procedureType) THEN
					parameter := SyntaxTree.NewParameter(procedureType.position,procedureType,Global.ResultName, SyntaxTree.VarParameter);
					parameter.SetType(procedureType.returnType);
					parameter.SetAccess(SyntaxTree.Hidden);
					parameter.SetUntraced(procedureType.hasUntracedReturn);
					ResolveParameter(parameter);
					procedureType.SetReturnParameter(parameter); (* return parameter serves as a cache only *)
				END;

				(* process parameters *)
				parameter :=procedureType.firstParameter;
				WHILE (parameter # NIL) DO
					ResolveParameter(parameter);
					parameter := parameter.nextParameter;
				END;
				parameter := procedureType.selfParameter;
				IF parameter # NIL THEN
					ResolveParameter(parameter)
				END;
		END FixProcedureType;

		PROCEDURE HasFlag(VAR modifiers: SyntaxTree.Modifier; name: SyntaxTree.Identifier; VAR position: Position): BOOLEAN;
		VAR prev,this: SyntaxTree.Modifier;
		BEGIN
			this := modifiers;prev := NIL;
			WHILE (this # NIL) & (this.identifier # name) DO
			prev := this; this := this.nextModifier;
			END;
			IF this # NIL THEN
				IF this.expression # NIL THEN
					Error(this.position,"unexpected expression");
				END;
				this.Resolved;
				position := this.position;
				RETURN TRUE
			ELSE
				RETURN FALSE
			END;
		END HasFlag;

		PROCEDURE HasValue(modifiers: SyntaxTree.Modifier; name: SyntaxTree.Identifier; VAR position: Position; VAR value: Basic.Integer): BOOLEAN;
		VAR prev,this: SyntaxTree.Modifier;
		BEGIN
			this := modifiers;prev := NIL;
			WHILE (this # NIL) & (this.identifier # name) DO
				prev := this; this := this.nextModifier;
			END;
			IF this # NIL THEN
				IF this.expression = NIL THEN
					Error(this.position,"expected expression value");
				ELSE
					this.SetExpression(ConstantExpression(this.expression));
					IF CheckIntegerValue(this.expression,value) THEN END;
				END;
				this.Resolved;
				position := this.position;
				RETURN TRUE
			ELSE RETURN FALSE
			END;
		END HasValue;

		PROCEDURE HasStringValue(modifiers: SyntaxTree.Modifier; name: SyntaxTree.Identifier; VAR position: Position; VAR value: ARRAY OF CHAR): BOOLEAN;
		VAR prev,this: SyntaxTree.Modifier;
		BEGIN
			this := modifiers;prev := NIL;
			WHILE (this # NIL) & (this.identifier # name) DO
				prev := this; this := this.nextModifier;
			END;
			IF this # NIL THEN
				IF this.expression = NIL THEN
					Error(this.position,"expected expression value");
				ELSE
					this.SetExpression(ConstantExpression(this.expression));
					IF CheckStringValue(this.expression,value) THEN END;
				END;
				this.Resolved;
				position := this.position;
				RETURN TRUE
			ELSE RETURN FALSE
			END;
		END HasStringValue;

		PROCEDURE SkipImplementation*(x: SyntaxTree.CellType): BOOLEAN;
		VAR svalue: ARRAY 32 OF CHAR; position: Position;
		BEGIN
			IF cellsAreObjects THEN RETURN FALSE END;
			IF HasStringValue(x.modifiers, Global.NameRuntime, position, svalue) THEN
				IF  svalue = "A2" THEN
					RETURN TRUE
				END;
			END;
			IF (x.baseType # NIL) & (x.baseType.resolved IS SyntaxTree.CellType) THEN
				RETURN SkipImplementation(x.baseType.resolved(SyntaxTree.CellType));
			END;
			RETURN FALSE;
			(*
			(*IF cellsAreObjects THEN RETURN FALSE END;*)
			IF (backendName = "TRM") & x.isCellNet THEN  RETURN TRUE END;
			IF HasStringValue(x.modifiers,Global.NameBackend,position,svalue) THEN
				IF svalue[0] = "~" THEN
					Strings.TrimLeft(svalue, "~");
					IF svalue = backendName THEN
						RETURN TRUE;
					END;
				ELSIF svalue # backendName THEN
					RETURN TRUE;
				END;
			END;
			IF (x.baseType # NIL) & (x.baseType.resolved IS SyntaxTree.CellType) THEN
				RETURN SkipImplementation(x.baseType.resolved(SyntaxTree.CellType));
			END;
			RETURN FALSE;
			*)
		END SkipImplementation;

		PROCEDURE CheckModifiers(modifiers: SyntaxTree.Modifier; checkUse: BOOLEAN);
		VAR this: SyntaxTree.Modifier;
		BEGIN
			this := modifiers;
			WHILE this # NIL DO
				IF ~this.resolved THEN
					IF checkUse THEN
						Error(this.position,"unexpected modifier");
					ELSE
						this.SetExpression(ResolveExpression(this.expression));
						this.Resolved;
					(*! sanity check for "unqualified" modifiers, as for example used in ActiveCells Engine parameterization *)
					END;
				END;
				this := this.nextModifier
			END;
		END CheckModifiers;

		(**
			resolve procedure type
			- enter procedure to list of deferred fixes (to avoid infinite loops in the declaration phase)
		**)
		PROCEDURE ResolveProcedureType(procedureType: SyntaxTree.ProcedureType);
		VAR modifiers: SyntaxTree.Modifier; value: Basic.Integer; position: Position;
		BEGIN
			modifiers := procedureType.modifiers;
			IF HasFlag(modifiers, Global.NameWinAPI,position) THEN procedureType.SetCallingConvention(SyntaxTree.WinAPICallingConvention)
			ELSIF HasFlag(modifiers, Global.NameInterrupt,position) THEN
				procedureType.SetInterrupt(TRUE);
				procedureType.SetCallingConvention(SyntaxTree.InterruptCallingConvention)
			ELSIF HasFlag(modifiers,Global.NameC,position) THEN
				procedureType.SetCallingConvention(SyntaxTree.CCallingConvention)
			ELSIF HasFlag(modifiers,Global.NamePlatformCC, position) THEN
				IF system.platformCallingConvention = SyntaxTree.UndefinedCallingConvention THEN
					Error(position, "undefined platform calling convention");
				ELSE
					procedureType.SetCallingConvention(system.platformCallingConvention);
				END;
			END;
			IF HasFlag(modifiers, Global.NameNoReturn,position) THEN procedureType.SetNoReturn(TRUE) END;
			IF HasValue(modifiers,Global.NameStackAligned,position,value) THEN procedureType.SetStackAlignment(LONGINT (value)) END; (* TODO: fix explicit integer truncation *)
			IF HasFlag(modifiers, Global.NameDelegate,position) THEN procedureType.SetDelegate(TRUE) END;
			IF HasFlag(modifiers, Global.NameRealtime,position) THEN procedureType.SetRealtime(TRUE) END;
			CheckModifiers(modifiers, TRUE);

			modifiers := procedureType.returnTypeModifiers;
			procedureType.SetUntracedReturn(HasFlag(modifiers, Global.NameUntraced, position));
			CheckModifiers(modifiers, TRUE);

			typeFixes.Add(procedureType,currentScope);
			procedureType.SetHasPointers(procedureType.isDelegate);
			procedureType.SetState(SyntaxTree.Resolved);
		END ResolveProcedureType;

		(** check and resolve record type
			- check base type: must be record, math array or array-structured object type
			- check declarations
			- every record type is guaranteed to have a type declaration in the module scope (anonymous or not)
		**)
		PROCEDURE ResolveRecordType(x: SyntaxTree.RecordType);
		VAR resolved, baseType: SyntaxTree.Type; position: Position;
			numberMethods: LONGINT; recordBase, recordType: SyntaxTree.RecordType; procedure: SyntaxTree.Procedure;
			symbol: SyntaxTree.Symbol; isRealtime: BOOLEAN;
			hasPointers: BOOLEAN;
			modifiers: SyntaxTree.Modifier;
			value: Basic.Integer;

			PROCEDURE IsPointerToRecord(type: SyntaxTree.Type; VAR recordType: SyntaxTree.RecordType): BOOLEAN;
			BEGIN
				type := type.resolved;
				IF	(type IS SyntaxTree.PointerType) &
					(type(SyntaxTree.PointerType).pointerBase.resolved # NIL) &
					(type(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.RecordType) THEN
					recordType := type(SyntaxTree.PointerType).pointerBase.resolved(SyntaxTree.RecordType);
					RETURN TRUE
				ELSE
					RETURN FALSE
				END;
			END IsPointerToRecord;

		BEGIN
			hasPointers := FALSE;

			modifiers := x.modifiers;
			IF HasValue(modifiers,Global.NameAligned,position,value) THEN x.SetAlignmentInBits(LONGINT(value)*system.dataUnit) (* TODO: fix explicit integer truncation *)
			END;
			IF HasFlag(modifiers,Global.NameAbstract,position) THEN x.SetAbstract(TRUE) END;
			CheckModifiers(modifiers, TRUE);

			IF x.baseType # NIL THEN

				position := x.baseType.position;
				baseType := ResolveType(x.baseType);
				resolved := baseType.resolved;
				hasPointers := hasPointers OR resolved.hasPointers;

				IF x.isObject THEN (* object *)
					ASSERT(x.pointerType # NIL);
					IF resolved = SyntaxTree.invalidType THEN (* error already handled *)
					ELSIF resolved IS SyntaxTree.ObjectType THEN (* the type denoted by the <<OBJECT>> alone *)
						baseType := NIL
					ELSIF IsPointerToRecord(resolved,recordType) THEN
						IF ~recordType.isObject THEN Warning(position, "deprecated extension of record to object"); END;
					ELSIF resolved IS SyntaxTree.MathArrayType THEN
					ELSE
						Error(position,"object does not extend pointer to record, object or math array ")
					END;
				ELSIF x.pointerType # NIL THEN (* record with type declaration POINTER TO RECORD *)
					IF resolved = SyntaxTree.invalidType THEN (* error already handled *)
					ELSIF IsPointerToRecord(resolved,recordType) THEN
						IF recordType.isObject THEN Error(position,"pointer to record extends object") END;
					ELSIF resolved IS SyntaxTree.RecordType THEN
					ELSE
						Error(position,"pointer to record does not extend pointer to record or record")
					END;

				ELSE
					IF resolved IS SyntaxTree.RecordType THEN
					ELSE
						Error(position,"record does not extend record")
					END;
				END;

				x.SetBaseType(baseType);
				IF x.Level() > 15 THEN
					Error(position, "record/object inheritance level too high");
					(* note:
						the restriction to inheritance with a maximum level of 15 is caused by the implementation of the
						runtime structures: type tests are very efficient and rely on the fact that each type descriptor contains the whole
						inheritance history of a type.
						Example: let inhertitance oe given by B(A), C(B), D(C) etc.
						Then the type descriptor of G contains: A|B|C|D|E|F|G|0|0|0...
						while the type decriptor of D contains: A|B|C|D|0|0|0|0|0|0...
					*)
				END;
				IF (x.pointerType # NIL) & (resolved IS SyntaxTree.PointerType) & (x.pointerType.isDisposable # resolved(SyntaxTree.PointerType).isDisposable) THEN
					Error(position, "invalid inheritance of disposable types");
				END;
			END;
			Declarations(x.recordScope, FALSE, {0});

			x.SetState(SyntaxTree.Resolved);

			Declarations(x.recordScope, FALSE, {1});

			(* computation of sizes and offsets skipped -> done in backend / system *)

			recordBase := x.GetBaseRecord();

			IF recordBase = NIL THEN numberMethods := 0
			ELSE numberMethods := recordBase.recordScope.numberMethods
			END;

			isRealtime := TRUE;
			IF x.isRealtime & (x.recordScope.bodyProcedure # NIL) THEN
				x.recordScope.bodyProcedure.type.SetRealtime(TRUE)
			END;
			symbol := x.recordScope.firstSymbol; (* sorted symbols, important to go through procedures in a sorted way here !*)
			WHILE symbol # NIL DO
				isRealtime := isRealtime & symbol.type.resolved.isRealtime;
				IF symbol IS SyntaxTree.Variable THEN
					hasPointers := hasPointers OR symbol.type.resolved.hasPointers & ~symbol(SyntaxTree.Variable).untraced;
				END;
				IF symbol IS SyntaxTree.Procedure THEN
					procedure := symbol(SyntaxTree.Procedure);
					IF procedure.super # NIL THEN
						procedure.SetMethodNumber(procedure.super.methodNumber);
					ELSIF InMethodTable(procedure) THEN (* not a static method *)
						procedure.SetMethodNumber(numberMethods);
						INC(numberMethods);
					END;
				IF ~x.isRealtime & procedure.type.resolved.isRealtime THEN
					Error(procedure.position,"realtime procedure in non-realtime object")
				END;
				END;
				IF x.isRealtime & ~symbol.type.resolved.isRealtime THEN
					Error(symbol.position,"non-realtime symbol in realtime object")
				END;

				symbol := symbol.nextSymbol;
			END;
			IF isRealtime THEN x.SetRealtime(TRUE) END;

			x.recordScope.SetNumberMethods(numberMethods);

			(* TODO: is this needed anymore? *)
			IF (x.isObject) & (x.baseType # NIL) & (x.baseType.resolved IS SyntaxTree.RecordType) THEN
				Error(x.position,"object extends a record")
			END;
			IF ~x.isAbstract THEN
				IF x.recordScope.AbstractProcedure(x.recordScope) # NIL THEN
					Error(x.position, "non-abstract object contains abstract procedure");
				END;
			ELSE
				IF x.recordScope.AbstractProcedure(x.recordScope) = NIL THEN
					Error(x.position, "abstract object does not contain an abstract method");
				END;
			END;
			IF (x.typeDeclaration = NIL) THEN
				IF (x.pointerType # NIL) & (x.pointerType.resolved.typeDeclaration # NIL) THEN
					x.SetTypeDeclaration(x.pointerType.resolved.typeDeclaration);
					(*
					x.pointerType.resolved.typeDeclaration.name.GetString(name);
					AnonymousTypeDeclaration(x,name);
					*)
				ELSE
					AnonymousTypeDeclaration(x,"Anonymous");
				END;
			END;
			x.SetHasPointers(hasPointers);
			x.SetState(SyntaxTree.Resolved);
		END ResolveRecordType;

			(** check and resolve cell type
			- check base type: must be cell
			- check declarations
			- every cell type is guaranteed to have a type declaration in the module scope (anonymous or not)
		**)
		PROCEDURE ResolveCellType(x: SyntaxTree.CellType);
		VAR
			symbol: SyntaxTree.Symbol; isRealtime: BOOLEAN; parameter: SyntaxTree.Parameter; type: SyntaxTree.Type; len: LONGINT;
			modifier: SyntaxTree.Modifier; position: Position; value: Basic.Integer; isEngine: BOOLEAN; property: SyntaxTree.Property;
			qualifiedIdentifier: SyntaxTree.QualifiedIdentifier;
			recordBase: SyntaxTree.RecordType;
			numberMethods: LONGINT;
			int: Basic.Integer;
			real: LONGREAL;
			bool: BOOLEAN;
			set: Basic.Set;
			v: SyntaxTree.Expression;
			str: Scanner.StringType;
			atype: SyntaxTree.ArrayType;
			prev: SyntaxTree.Scope;
		BEGIN
			recordBase := NIL;
			IF cellsAreObjects THEN
				IF x.baseType = NIL THEN
					qualifiedIdentifier := SyntaxTree.NewQualifiedIdentifier(x.position, SyntaxTree.NewIdentifier("ActiveCellsRuntime"), SyntaxTree.NewIdentifier("Cell"));
					ImportModule(qualifiedIdentifier.prefix, x.position);
					x.SetBaseType(SyntaxTree.NewQualifiedType(x.position, currentScope, qualifiedIdentifier));
					x.SetBaseType(ResolveType(x.baseType));
					recordBase := x.GetBaseRecord();
					IF recordBase = NIL THEN
						Error(x.position,"ActiveCellsRuntime.Cell not present");
					END;
				ELSE
					x.SetBaseType(ResolveType(x.baseType));
				END;
			ELSE
				x.SetBaseType(ResolveType(x.baseType));
			END;

			IF recordBase = NIL THEN numberMethods := 0
			ELSE numberMethods := recordBase.recordScope.numberMethods
			END;

			modifier := x.modifiers;
			(*IF ~x.isCellNet THEN*)
				IF HasValue(modifier,Global.NameDataMemorySize,position,value) THEN END;
				IF HasValue(modifier,Global.NameCodeMemorySize,position,value) THEN END;
				IF HasFlag(modifier, Global.NameEngine, position) THEN isEngine := TRUE ELSE isEngine := FALSE END;
				IF HasFlag(modifier, Global.NameVector,position) THEN END;
				IF HasFlag(modifier, Global.NameFloatingPoint, position) THEN END;
				IF HasFlag(modifier, Global.NameNoMul,position) THEN END;
				IF HasFlag(modifier, Global.NameNonBlockingIO,position) THEN END;
				IF HasFlag(modifier, Global.NameTRM, position) THEN END;
				IF HasFlag(modifier, Global.NameTRMS, position) THEN END;
				symbol := system.activeCellsCapabilities;
				WHILE symbol # NIL DO
					IF HasFlag(modifier, symbol.name, position) THEN END;
					symbol := symbol.nextSymbol;
				END;

				modifier := x.modifiers;
				WHILE (modifier # NIL) DO

					property := SyntaxTree.NewProperty(modifier.position, modifier.identifier);

					IF modifier.expression # NIL THEN
						v := ConstantExpression(modifier.expression);
						property.SetValue(v);
						IF IsIntegerValue(modifier.expression, int) THEN
							(*property.SetValue(modifier.expression);*)
							modifier.SetExpression(NewConversion(modifier.position, modifier.expression, system.longintType, NIL));
							property.SetType(system.longintType);
						ELSIF IsRealValue(modifier.expression, real) THEN
							modifier.SetExpression(NewConversion(modifier.position, modifier.expression, system.longrealType, NIL));
							property.SetType(system.longrealType);
						ELSIF IsBooleanValue(modifier.expression, bool) THEN
							property.SetType(system.booleanType);
						ELSIF IsSetValue(modifier.expression, set) THEN
							property.SetType(system.setType);
						ELSIF IsStringValue(modifier.expression, str) THEN
							(*property.SetValue(modifier.expression);*)
							atype := SyntaxTree.NewArrayType(Basic.invalidPosition, NIL, SyntaxTree.Static);
							atype.SetArrayBase(modifier.expression.type(SyntaxTree.StringType).baseType);
							atype.SetLength(Global.NewIntegerValue(system,Basic.invalidPosition, (* type(SyntaxTree.StringType).length *) 256 (*! check if this is a good idea *) ));
							property.SetType(atype);

						ELSE
							Error(modifier.position, "unsupported property type");
						END;
					ELSE (* flag property *)
						(*property.SetValue(SyntaxTree.NewBooleanValue(position,TRUE));*)
						property.SetType(system.booleanType);
					END;
					(* property.SetScope(x.cellScope); *) (* not required, will be done during entry *)
					(* property.SetState(SyntaxTree.Resolved); *) (* not required, will be done during entry *)

					x.AddProperty(property);

					modifier := modifier.nextModifier;
				END;
			CheckModifiers(modifier, FALSE);

			Declarations(x.cellScope, SkipImplementation(x),{0,1});

			(* process parameters *)
			prev := currentScope;
			currentScope := x.cellScope;
			parameter :=x.firstParameter;
			WHILE (parameter # NIL) DO
				ResolveParameter(parameter);
				type := parameter.type.resolved;
				IF ~(type IS SyntaxTree.PortType) THEN
					WHILE IsStaticArray(type, type, len) DO
						IF IsDynamicArray(type, type) THEN Error(parameter.position, "invalid mixture of dynamic and static array of ports") END;
					END;
					WHILE IsDynamicArray(type, type) DO
						IF IsStaticArray(type, type, len) THEN Error(parameter.position, "invalid mixture of dynamic and static array of ports") END;
					END;
					IF (* ~IsStaticArray(type,type,len) OR*)  ~(type IS SyntaxTree.PortType) THEN
						Error(parameter.position, "invalid type, must be port or static array of port ");
					END;
				END;
				parameter := parameter.nextParameter;
			END;

			currentScope := prev;
			symbol := x.cellScope.firstSymbol; (* sorted symbols, important to go through procedures in a sorted way here !*)
			WHILE symbol # NIL DO
				IF symbol IS SyntaxTree.Variable THEN
					isRealtime := isRealtime & symbol.type.resolved.isRealtime;
				END;
				symbol := symbol.nextSymbol;
			END;
			IF isRealtime THEN x.SetRealtime(TRUE) END;

			IF (x.typeDeclaration = NIL) THEN
				AnonymousTypeDeclaration(x,"Anonymous");
			END;
			x.SetState(SyntaxTree.Resolved);

			IF (x.cellScope.bodyProcedure = NIL) & (~isEngine)THEN
				Warning(x.position, "Forbidden empty Body.");
			ELSIF (x.cellScope.bodyProcedure # NIL) & (isEngine)THEN
				Warning(x.position, "Non-empty body for an engine?");
			END;
		END ResolveCellType;

		(** Check if a node has already been resolved. If not then mark as currently being resolved.
			If node is currently being resolved then emit a cyclic definition error.
			Return TRUE only if node is fully resolved.
		**)
		PROCEDURE TypeNeedsResolution(x: SyntaxTree.Type): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			IF SyntaxTree.Resolved IN x.state THEN
				result := FALSE
			ELSIF SyntaxTree.BeingResolved IN x.state THEN
				Error(x.position,"cyclic definition");
				result := FALSE;
			ELSE
				result := TRUE;
				x.SetState(SyntaxTree.BeingResolved)
			END;
			RETURN result
		END TypeNeedsResolution;

		PROCEDURE ResolveType*(x: SyntaxTree.Type): SyntaxTree.Type;
		BEGIN
			IF (x = NIL) OR (x = SyntaxTree.invalidType) THEN RETURN x
			ELSIF TypeNeedsResolution(x) THEN
				WITH x: SyntaxTree.ProcedureType DO ResolveProcedureType(x)
				|SyntaxTree.CellType DO ResolveCellType(x)
				|SyntaxTree.RecordType DO ResolveRecordType(x)
				|SyntaxTree.PortType DO ResolvePortType(x)
				|SyntaxTree.PointerType DO ResolvePointerType(x)
				|SyntaxTree.MathArrayType DO ResolveMathArrayType(x)
				|SyntaxTree.ArrayType DO ResolveArrayType(x)
				|SyntaxTree.RangeType DO x.SetState(SyntaxTree.Resolved)
				|SyntaxTree.EnumerationType DO ResolveEnumerationType(x)
				|SyntaxTree.StringType DO x.SetState(SyntaxTree.Resolved)
				|SyntaxTree.QualifiedType DO ResolveQualifiedType(x)
				|SyntaxTree.BasicType DO x.SetState(SyntaxTree.Resolved)
				END; (* no other case may remain *)
			END;
			IF SyntaxTree.Resolved IN x.state THEN
				RETURN x
			ELSE
				RETURN SyntaxTree.invalidType
			END;
		END ResolveType;

		(** resolve all pending types (late resolving).
			- type fixes are resolved at the end of the declaration phase
			- type fixes may imply new type fixes that are also entered at the end of the list
		**)
		PROCEDURE FixTypes;
		VAR p: ANY; prevScope: SyntaxTree.Scope;
		BEGIN
			prevScope := currentScope;
			p := typeFixes.Get(currentScope);
			WHILE p # NIL DO
				ASSERT(currentScope # NIL);
				ASSERT(p IS SyntaxTree.Type);

				IF p IS SyntaxTree.PointerType THEN
					FixPointerType(p(SyntaxTree.PointerType))
				ELSIF p IS SyntaxTree.ProcedureType THEN
					FixProcedureType(p(SyntaxTree.ProcedureType))
				ELSE
					HALT(100);
				END;
				p := typeFixes.Get(currentScope);
			END;
			currentScope :=prevScope;
		END FixTypes;

		(*** compatibility rules ***)

		(**
			return a regular type: if type is invalid, NIL, importType or typeDeclarationType then return invalidType else return type
		**)
		PROCEDURE RegularType(position: Position; type: SyntaxTree.Type): SyntaxTree.Type;
		VAR result: SyntaxTree.Type;
		BEGIN
			result := SyntaxTree.invalidType;
			IF type = NIL THEN Error(position, "expression of type NIL");
			ELSIF type = SyntaxTree.invalidType THEN (* error already handled *)
			ELSIF type.resolved = SyntaxTree.importType THEN Error(position, "expression is an import");
			ELSIF type.resolved = SyntaxTree.typeDeclarationType THEN Error(position, "expression is a type");
			ELSE result := type.resolved
			END;
			RETURN result
		END RegularType;

		(** returns signature compatibility of procedure types this and to
			- if not compatible then error is reported
			- compatibility means type equality
		**)
		PROCEDURE SignatureCompatible(position: Position; this, to: SyntaxTree.ProcedureType): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := SameType(to,this);
			IF ~result THEN
				Error(position, "signature incompatible");
				IF VerboseErrorMessage THEN
					Printout.Info("this",this);
					Printout.Info("to",to);
				END;
			ELSIF (to(SyntaxTree.ProcedureType).isRealtime) & ~(this(SyntaxTree.ProcedureType).isRealtime) THEN
				Error(position, "signature incompatible: realtime flag must be inherited");
			END;
			RETURN result
		END SignatureCompatible;

		(** check parameter compatibility for expressions of the form P(actual) where P = PROCEDURE([VAR|CONST] formal)
			- for var parameters compatibility means same type except for
				- formal is of open array of system byte
				- formal is of record type
				- formal is of open array type
				- formal is of open math array type
			- for value parameters compatibllity means assignment compatibility except for
				- formal is of open array type
			if compatible the return true else report error and return false
		**)

		PROCEDURE ParameterCompatible(formal: SyntaxTree.Parameter; actual: SyntaxTree.Expression): BOOLEAN;
		VAR formalType, actualType: SyntaxTree.Type; result,error: BOOLEAN;
		BEGIN
			formalType := RegularType(formal.position,formal.type);
			actualType := RegularType(actual.position,actual.type);
			error := FALSE;

			IF actualType = SyntaxTree.invalidType THEN (* error already handled *)
			ELSIF (formal.kind = SyntaxTree.VarParameter) THEN
				IF (actual IS SyntaxTree.SymbolDesignator) & (actual(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Variable) THEN
					actual(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Variable).UsedAsReference;
				END;
				IF (formal.ownerType(SyntaxTree.ProcedureType).callingConvention = SyntaxTree.WinAPICallingConvention) & (actualType IS SyntaxTree.NilType) THEN
					result := TRUE; (* special rule for WINAPI parameters, needed to be able to pass NIL address to var parameters *)
				ELSIF ~IsVariable(actual) THEN
					result := FALSE; error := TRUE;
					IF actual IS SyntaxTree.ProcedureCallDesignator THEN
						Error(actual.position,"not a variable: no operator for writing");
					ELSE
						Error(actual.position,"is not a variable");
					END;
					IF VerboseErrorMessage THEN
						Printout.Info("actual",actual);
						Printout.Info("formal",formal);
					END;
				ELSIF (formalType IS SyntaxTree.ByteType) OR (formalType IS SyntaxTree.RecordType) & (~formalType(SyntaxTree.RecordType).isObject) THEN
					result := CompatibleTo(system,actualType,formalType);
				ELSIF (formalType IS SyntaxTree.ArrayType) & (formalType(SyntaxTree.ArrayType).form = SyntaxTree.Open) THEN
					result := OpenArrayCompatible(formalType(SyntaxTree.ArrayType),actualType);
				ELSIF IsUnsafePointer(formalType) & IsUnsafePointer(actualType) THEN
					result := TRUE;
				ELSIF (formalType IS SyntaxTree.MathArrayType) THEN
					result := MathArrayCompatible(formalType(SyntaxTree.MathArrayType),actualType);
					IF result & (formalType(SyntaxTree.MathArrayType).form = SyntaxTree.Static) & (actualType(SyntaxTree.MathArrayType).form # SyntaxTree.Static) THEN
						Error(actual.position,"incompatible non-static actual type");
					END;
					IF result & (actualType(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor) & (formalType(SyntaxTree.MathArrayType).form # SyntaxTree.Tensor) THEN
						Error(actual.position,"incompatible tensor (use a range expression)");
					END;
				ELSE
					result := SameType(actualType,formalType)
				END
			ELSE
				IF (formalType IS SyntaxTree.CharacterType) & (actualType IS SyntaxTree.StringType) & (actualType(SyntaxTree.StringType).length = 2) THEN
					actualType := system.characterType;
				END;
				IF (formal.ownerType(SyntaxTree.ProcedureType).callingConvention = SyntaxTree.WinAPICallingConvention) &  ((actualType IS SyntaxTree.NilType) OR (actualType IS SyntaxTree.AnyType)) THEN
					result := TRUE; (* special rule for WINAPI parameters *)
				ELSIF (formalType IS SyntaxTree.ArrayType) & (formalType(SyntaxTree.ArrayType).form = SyntaxTree.Open) THEN
					result := OpenArrayCompatible(formalType(SyntaxTree.ArrayType),actualType);
				ELSE
					result := CompatibleTo(system,actualType,formalType);
					IF result & (formalType IS SyntaxTree.MathArrayType) & (formalType(SyntaxTree.MathArrayType).form = SyntaxTree.Static) & (actualType(SyntaxTree.MathArrayType).form # SyntaxTree.Static) THEN
						Error(actual.position,"incompatible non-static actual type");
					END;
				END;
			END;
			IF ~result & ~error THEN
				Error(actual.position,"incompatible parameter");
				IF VerboseErrorMessage THEN
					Printout.Info("actual",actual);
					Printout.Info("formal",formal);
				END;
			END;
			RETURN result
		END ParameterCompatible;

		(** check compatibility for expressions of the form left := right
			- if compatible then return true else error report and return false
			- check if left is variable
			- check compatiblity
		**)
		PROCEDURE AssignmentCompatible(left: SyntaxTree.Designator; right: SyntaxTree.Expression): BOOLEAN;
		VAR leftType,rightType: SyntaxTree.Type; VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			leftType := RegularType(left.position,left.type);
			rightType := RegularType(right.position,right.type);

			IF (leftType IS SyntaxTree.CharacterType) & (rightType IS SyntaxTree.StringType) & (rightType(SyntaxTree.StringType).length = 2) THEN
				rightType := system.characterType; (* conversion character "x" -> string "x" *)
			END;

			IF (leftType = SyntaxTree.invalidType) OR (rightType = SyntaxTree.invalidType) THEN
				(* error already handled *)
				result := TRUE;

			ELSIF ~IsVariable(left) THEN
				Error(left.position,"is not a variable");
				IF VerboseErrorMessage THEN
					Printout.Info("left",left);
					Printout.Info("right",right);
				END;
			ELSIF (leftType IS SyntaxTree.AddressType) & IsAddressValue(right) THEN
				result := TRUE;
			ELSIF IsUnsignedIntegerType(leftType) & IsUnsignedValue(right, leftType.sizeInBits) THEN
				result := TRUE
			ELSIF ~CompatibleTo(system,rightType,leftType) THEN
				Error(left.position,"incompatible assignment");
				IF VerboseErrorMessage THEN
					Printout.Info("left",left);
					Printout.Info("right",right);
				END;
			ELSIF (right IS SyntaxTree.SymbolDesignator) & (right(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Procedure) &
				(right(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Procedure).scope IS SyntaxTree.ProcedureScope) THEN
				Error(right.position,"forbidden assignment of a nested procedure");
			ELSE
				result := TRUE
			END;
			RETURN result
		END AssignmentCompatible;

		(*** expressions ***)

		(** check and resolve a Set expression of the form {Expression, Expression, ...}
			- check all elements on integer type
			- if element range is constant, then check lower and upper bound
			- if all elements constant then return constant set value else return set expression (via global variable resolvedExpression)
			if an error occurs then report error and return invalidExpression
		**)
		PROCEDURE ResolveSet(set: SyntaxTree.Set): SyntaxTree.Expression;
		VAR
			i: LONGINT;
			element: SyntaxTree.Expression;
			constant: BOOLEAN;
			elements: SyntaxTree.ExpressionList;
			s: Basic.Set;
			result: SyntaxTree.Expression;
			value: SyntaxTree.Value;

			PROCEDURE CheckElement(element: SyntaxTree.Expression): SyntaxTree.Expression;
			VAR
				left, right: SyntaxTree.Expression;
				elementResult: SyntaxTree.Expression;
				leftInteger, rightInteger: Basic.Integer;
			BEGIN
				(* set context of range *)
				IF element IS SyntaxTree.RangeExpression THEN
					element(SyntaxTree.RangeExpression).SetContext(SyntaxTree.SetElement)
				END;

				elementResult := ResolveExpression(element); (* implies checking of subexpressions in binary expressions *)

				IF elementResult = SyntaxTree.invalidExpression THEN
					(* error already reported *)
					constant := FALSE

				ELSIF elementResult IS SyntaxTree.RangeExpression THEN
					(* the element is a range expression *)

					(* extract left and right hand side of range *)
					left := elementResult(SyntaxTree.RangeExpression).first;
					right := elementResult(SyntaxTree.RangeExpression).last;

					(* guaranteed by VisitRangeExpression: *)
					ASSERT((left # NIL) & (right # NIL));
					ASSERT(system.lenType.SameType(left.type.resolved) & system.lenType.SameType(right.type.resolved));

				ELSE
					(* the element is not a range expression *)

					(* check type and add conversion if needed *)
					IF IsIntegerType(elementResult.type.resolved) THEN
						elementResult := NewConversion(elementResult.position, elementResult, system.sizeType, NIL)
					ELSE
						Error(elementResult.position, "non integer element in set");
						elementResult := SyntaxTree.invalidExpression;
						constant := FALSE
					END;

					left := elementResult;
					right := elementResult
				END;

				IF elementResult # SyntaxTree.invalidExpression THEN
					IF IsIntegerValue(left,leftInteger) & IsIntegerValue(right,rightInteger) THEN
						IF (leftInteger<0) OR (leftInteger >= system.setType.sizeInBits) THEN
							Error(left.position,"not allowed set integer value");
							IF (rightInteger<0) OR (rightInteger  >= system.setType.sizeInBits) THEN
								Error(right.position,"not allowed set integer value");
							END
						ELSIF (rightInteger<0) OR (rightInteger >= system.setType.sizeInBits) THEN
							Error(right.position,"not allowed set integer value");
						ELSE
							IF (leftInteger > MAX(SET)) OR (rightInteger <0) THEN
								s := {};
							ELSE
								IF rightInteger > MAX(SET) THEN rightInteger := MAX(SET) END;
								IF leftInteger < 0 THEN leftInteger := 0 END;
								(*!!!!!!!!! this is a hack !!!!!!! *)
								(*!	in case of MAX(SET) =31 and --bits=64 some kind of sign extension
								extends the range  x..31  to  x..63 !!!!!! *)
								s := s + {leftInteger..rightInteger};
							END;
						END;
					ELSE
						constant := FALSE;
					END
				END;

				RETURN elementResult
			END CheckElement;

		BEGIN
			result := set; constant := TRUE; s := {}; elements := set.elements;
			IF elements # NIL THEN
				FOR i := 0 TO elements.Length()-1 DO
					element := elements.GetExpression(i);
					element := CheckElement(element);
					IF element = SyntaxTree.invalidExpression THEN
						result := SyntaxTree.invalidExpression
					END;
					elements.SetExpression(i,element);
				END;
			END;
			IF constant THEN
				value := Global.NewSetValue(system,set.position,s);
				result.SetResolved(value);
				result.SetType(value.type);
			ELSE
				result.SetType(system.setType);
			END;
			(* optimization possible
				convert {a,b,1,2,3,4,c,d} into {a,b,c,d} + {1,2,3,4}
				left this to the programmer...
			*)
			RETURN result;
		END ResolveSet;

		(*
		old variant: quite generic but needs better conversion handling, do this?

		PROCEDURE VisitMathArrayExpression(x: SyntaxTree.MathArrayExpression);
		VAR type: SyntaxTree.Type; position,numberElements,i: LONGINT; expression: SyntaxTree.Expression; isValue: BOOLEAN;
			value: SyntaxTree.MathArrayValue; arrayType: SyntaxTree.MathArrayType;
		BEGIN
			type := NIL;
			numberElements := x.elements.Length();
			FOR i := 0 TO numberElements-1 DO
				expression := x.elements.GetExpression(i);
				position := expression.position;
				expression := ResolveExpression(x.elements.GetExpression(i));
				x.elements.SetExpression(i,de);
				IF type = NIL THEN
					type := expression.type;
				ELSIF CompatibleTo(system,expression.type,type) THEN
					(* ok *)
				ELSIF CompatibleTo(system,type,expression.type) THEN
					type := expression.type
				ELSE
					Error(expression.position, "incompatible element types");
					type := SyntaxTree.invalidType;
				END;
			END;
			isValue := TRUE;
			FOR i := 0 TO numberElements-1 DO
				expression := NewConversion(position,x.elements.GetExpression(i),type);
				x.elements.SetExpression(i,expression);
				isValue := isValue & (expression.resolved # NIL);
			END;
			arrayType := SyntaxTree.NewMathArrayType(x.position,NIL, SyntaxTree.Static);
			arrayType.SetArrayBase(type);
			arrayType.SetLength(Global.NewIntegerValue(system,NewIntegerValue(system,rElements));
			IF isValue THEN
				value := SyntaxTree.NewMathArrayValue(position);
				value.SetElements(x.elements);
				x.SetResolved(value);
			END;
			x.SetType(arrayType);
			resolvedExpression := x;
		END VisitMathArrayExpression;
		*)

		PROCEDURE ResolveMathArrayExpression(x: SyntaxTree.MathArrayExpression): SyntaxTree.Expression;
		VAR type: SyntaxTree.Type; isValue: BOOLEAN;
			value: SyntaxTree.MathArrayValue; arrayType: SyntaxTree.Type;

			PROCEDURE RecursivelyFindType(x: SyntaxTree.MathArrayExpression);
			VAR position: Position; numberElements,i: LONGINT; expression: SyntaxTree.Expression;
			BEGIN
				numberElements := x.elements.Length();
				FOR i := 0 TO numberElements-1 DO
					expression := x.elements.GetExpression(i);
					IF expression IS SyntaxTree.MathArrayExpression THEN
						RecursivelyFindType(expression(SyntaxTree.MathArrayExpression))
					ELSE
						position := expression.position;
						expression := ResolveExpression(x.elements.GetExpression(i));
						x.elements.SetExpression(i,expression);
						IF type = NIL THEN
							type := expression.type;
						ELSIF CompatibleTo(system,expression.type,type) THEN
							(* ok *)
						ELSIF CompatibleTo(system,type,expression.type) THEN
							type := expression.type
						ELSE
							Error(expression.position, "incompatible element types");
							type := SyntaxTree.invalidType;
						END;
					END;
				END;
			END RecursivelyFindType;

			PROCEDURE RecursivelySetExpression(x: SyntaxTree.MathArrayExpression);
			VAR position: Position; numberElements,i: LONGINT; expression: SyntaxTree.Expression;
			BEGIN
				numberElements := x.elements.Length();
				FOR i := 0 TO numberElements-1 DO
					expression := x.elements.GetExpression(i);
					IF expression IS SyntaxTree.MathArrayExpression THEN
						RecursivelySetExpression(expression(SyntaxTree.MathArrayExpression));
					ELSE
						position := expression.position;
						expression := NewConversion(position,x.elements.GetExpression(i),type,NIL);
						x.elements.SetExpression(i,expression);
						isValue := isValue & (expression.resolved # NIL);
					END;
				END;
			END RecursivelySetExpression;

			PROCEDURE RecursivelySetType(x: SyntaxTree.MathArrayExpression): SyntaxTree.Type;
			VAR numberElements,i,size,gsize: LONGINT; baseType: SyntaxTree.Type;expression: SyntaxTree.Expression;
				arrayType: SyntaxTree.MathArrayType;
			BEGIN
				numberElements := x.elements.Length();
				baseType := NIL;
				gsize := 0;
				FOR i := 0 TO numberElements-1 DO
					expression := x.elements.GetExpression(i);
					IF expression IS SyntaxTree.MathArrayExpression THEN
						size := expression(SyntaxTree.MathArrayExpression).elements.Length();
						IF i=0 THEN
							gsize := size;
							baseType := RecursivelySetType(expression(SyntaxTree.MathArrayExpression));
						ELSIF (baseType = type) OR (gsize # size) THEN  Error(expression.position, "invalid array dimensions");
						ELSE expression.SetType(baseType)
						END;
					ELSIF baseType = NIL THEN baseType := type;
					ELSIF baseType # type THEN Error(expression.position, "invalid array dimensions");
					END;
				END;
				arrayType := SyntaxTree.NewMathArrayType(x.position,NIL, SyntaxTree.Static);
				arrayType.SetArrayBase(baseType);
				arrayType.SetLength(Global.NewIntegerValue(system,x.position,numberElements));
				RETURN ResolveType(arrayType);
			END RecursivelySetType;

		BEGIN
			type := NIL;
			RecursivelyFindType(x);
			isValue := TRUE;
			RecursivelySetExpression(x);
			arrayType := RecursivelySetType(x);
			x.SetType(arrayType);
			IF isValue THEN
				value := SyntaxTree.NewMathArrayValue(x.position,x);
				x.SetResolved(value);
				value.SetType(arrayType);
			END;
			x.SetType(arrayType);
			RETURN x;
		END ResolveMathArrayExpression;

		(** check and resolve unary expression **)
		PROCEDURE ResolveUnaryExpression(unaryExpression: SyntaxTree.UnaryExpression): SyntaxTree.Expression;
		VAR
			left: SyntaxTree.Expression;
			int: Basic.Integer; real, imaginary: LONGREAL; set: Basic.Set; operator: LONGINT;
			bool: BOOLEAN;
			result: SyntaxTree.Expression; type: SyntaxTree.Type; operatorCall: SyntaxTree.Expression;
			value: SyntaxTree.Value;
		BEGIN
			type := SyntaxTree.invalidType;
			left := ResolveExpression(unaryExpression.left);
			unaryExpression.SetLeft(left);
			operator := unaryExpression.operator;
			result := unaryExpression;
			IF ~system.operatorDefined[operator] THEN
				Error(left.position,"Operator Not Defined");
				RETURN SyntaxTree.invalidExpression;
			ELSIF left.type = NIL THEN
				Error(left.position,"Invalid Nil Argument in Unary Expression");
				RETURN SyntaxTree.invalidExpression;
			ELSIF left = SyntaxTree.invalidExpression THEN (* error already handled *)
				RETURN SyntaxTree.invalidExpression;
			END;
			IF  ~(left.type.resolved IS SyntaxTree.BasicType) OR (left.type.resolved IS SyntaxTree.ComplexType) THEN
				operatorCall := NewOperatorCall(unaryExpression.position, unaryExpression, operator,left,NIL,NIL);
			END;
			IF operatorCall # NIL THEN
				result := operatorCall;
				type := operatorCall.type;
				(* admissible operators
					Minus			number, set
					Not			boolean
				*)
			ELSE
				CASE unaryExpression.operator OF
				|Scanner.Minus:
					IF IsIntegerType(left.type.resolved) THEN
						IF left.resolved # NIL THEN
							int := -left.resolved(SyntaxTree.IntegerValue).value;
							value := SyntaxTree.NewIntegerValue(unaryExpression.position,int);
							result.SetResolved(value);
							type := Global.GetIntegerType(system,int);
							value.SetType(type);
						ELSE
							type := left.type
						END
					ELSIF left.type.resolved IS SyntaxTree.FloatType THEN
						IF IsRealValue(left,real) THEN
							value := SyntaxTree.NewRealValue(unaryExpression.position,-real, Scanner.None);
							result.SetResolved(value);
							type := left.type;
							value.SetType(type);
						ELSE
							type := left.type;
						END;
					ELSIF left.type.resolved IS SyntaxTree.SetType THEN
						IF IsSetValue(left,set) THEN
							value := SyntaxTree.NewSetValue(unaryExpression.position,-set);
							result.SetResolved(value);
							type := Global.GetSetType(system,-set);
							value.SetType(type);
						ELSE
							type := left.type;
						END;
					ELSIF left.type.resolved IS SyntaxTree.ComplexType THEN
						IF IsComplexValue(left, real, imaginary) THEN
							value := SyntaxTree.NewComplexValue(unaryExpression.position,-real, -imaginary, Scanner.None);
							result.SetResolved(value);
							type := left.type;
							value.SetType(type);
							value(SyntaxTree.ComplexValue).SetSubtype(left.resolved(SyntaxTree.ComplexValue).subtype) (* reuse subtype *)
						ELSE
							type := left.type;
						END
					ELSE
						Error(left.position,"unary operator not applicable");
					END;
				|Scanner.Not:
					IF left.type.resolved IS SyntaxTree.BooleanType THEN
						IF IsBooleanValue(left,bool)  THEN
							value := SyntaxTree.NewBooleanValue(unaryExpression.position,~bool);
							result.SetResolved(value);
							type := system.booleanType;
							value.SetType(type);
						ELSE
							type := system.booleanType;
						END;
					ELSE
						Error(left.position,"unary operator not applicable");
					END;
				|Scanner.Plus:
					IF (left.type.resolved IS SyntaxTree.NumberType) THEN
						result := left; type := left.type;
					ELSE
						Error(left.position,"unary operator not applicable");
					END;
				(* ADDRESS OF *)
				|Scanner.Address:
					IF HasAddress(left) THEN
						type := system.addressType;
					ELSE
						type := SyntaxTree.invalidType;
						Error(left.position,"has no address");
						Printout.Info("par", left);
					END;
				(* SIZE OF *)
				|Scanner.Size:
					IF (left.type = SyntaxTree.typeDeclarationType) THEN
						type := left(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType;
						int := system.SizeOf(type.resolved) DIV 8 (* in bytes *);
						value := SyntaxTree.NewIntegerValue(left.position, int);
						result.SetResolved(value);
						type := Global.GetIntegerType(system,int);
						value.SetType(type)
						(* was Int16  in paco but should be systemSize (conflict with current release) *)
					ELSE
						(* for variables, system sizeof could represent the physically occupied size
							determined via the type descriptor, implement that ? *)
						Error(left.position,"is not a type symbol");
					END
				(* ALIAS OF *)
				|Scanner.Alias:
					type := left.type.resolved;
					IF ~(type IS SyntaxTree.MathArrayType) THEN
						type := SyntaxTree.invalidType;
						Error(left.position,"alias on non math array type");
					END;
				ELSE
					Error(left.position,"unary operator not defined");
				END;
			END;
			result.SetType(type);
			RETURN result
		END ResolveUnaryExpression;

		PROCEDURE MathArrayConversion(position: Position; expression: SyntaxTree.Expression; type: SyntaxTree.Type): SyntaxTree.Expression;
		VAR
			result: SyntaxTree.Expression;
			array: SyntaxTree.MathArrayExpression;
			value: SyntaxTree.MathArrayValue;
			isValue: BOOLEAN;

			PROCEDURE BaseType(type: SyntaxTree.Type): SyntaxTree.Type;
			BEGIN
				type := type.resolved;
				WHILE (type # NIL) & (type IS SyntaxTree.MathArrayType) DO
					type := Resolved(type(SyntaxTree.MathArrayType).arrayBase);
				END;
				WHILE (type # NIL) & (type IS SyntaxTree.ArrayType) DO
					type := Resolved(type(SyntaxTree.ArrayType).arrayBase);
				END;
				RETURN type
			END BaseType;

			PROCEDURE RecursivelyConvert(x, to: SyntaxTree.MathArrayExpression);
			VAR position: Position; numberElements,i: LONGINT; expression: SyntaxTree.Expression; array: SyntaxTree.MathArrayExpression;
			BEGIN
				numberElements := x.elements.Length();
				FOR i := 0 TO numberElements-1 DO
					expression := x.elements.GetExpression(i);
					IF expression IS SyntaxTree.MathArrayExpression THEN
						array := SyntaxTree.NewMathArrayExpression(position, SyntaxTree.NewExpressionList());
						RecursivelyConvert(expression(SyntaxTree.MathArrayExpression), array);
						expression := array;
					ELSE
						position := expression.position;
						expression := NewConversion(position,x.elements.GetExpression(i),type,NIL);
						isValue := isValue & (expression.resolved # NIL);
					END;
					to.elements.AddExpression(expression);
				END;
			END RecursivelyConvert;

			PROCEDURE RecursivelySetType(x: SyntaxTree.MathArrayExpression): SyntaxTree.Type;
			VAR numberElements,i,size,gsize: LONGINT; baseType: SyntaxTree.Type;expression: SyntaxTree.Expression;
				arrayType: SyntaxTree.MathArrayType;
			BEGIN
				numberElements := x.elements.Length();
				baseType := NIL;
				gsize := 0;
				FOR i := 0 TO numberElements-1 DO
					expression := x.elements.GetExpression(i);
					IF expression IS SyntaxTree.MathArrayExpression THEN
						size := expression(SyntaxTree.MathArrayExpression).elements.Length();
						IF i=0 THEN
							gsize := size;
							baseType := RecursivelySetType(expression(SyntaxTree.MathArrayExpression));
						ELSIF (baseType = type) OR (gsize # size) THEN  Error(expression.position, "invalid array dimensions");
						ELSE expression.SetType(baseType)
						END;
					ELSIF baseType = NIL THEN baseType := type;
					ELSIF baseType # type THEN Error(expression.position, "invalid array dimensions");
					END;
				END;
				arrayType := SyntaxTree.NewMathArrayType(x.position,NIL, SyntaxTree.Static);
				arrayType.SetArrayBase(baseType);
				arrayType.SetLength(Global.NewIntegerValue(system,x.position,numberElements));
				RETURN ResolveType(arrayType);
			END RecursivelySetType;

		BEGIN
			result := SyntaxTree.invalidExpression;
			IF (BaseType(type)=NIL) OR (BaseType(expression.type.resolved).SameType(BaseType(type)))  THEN
				result := expression (* do not convert *)
			ELSIF (expression.resolved # NIL) & (BaseType(type) IS SyntaxTree.BasicType) THEN (* compliance has already been checked *)
				isValue := TRUE;
				type :=  BaseType(type);
				array := SyntaxTree.NewMathArrayExpression(expression.position, SyntaxTree.NewExpressionList());
				RecursivelyConvert(expression(SyntaxTree.MathArrayValue).array(SyntaxTree.MathArrayExpression), array);
				value := SyntaxTree.NewMathArrayValue(array.position,array);
				value.SetType(RecursivelySetType(array));
				result := value;
				IF ~isValue THEN Error(position, "incompatible array conversion") END;
			ELSE (* should the search for operators be restricted to the ArrayBase module here ? *)
				result := NewOperatorCall(position,expression, Global.Conversion,expression,NIL,type);
				IF result = NIL THEN
					result := SyntaxTree.invalidExpression;
					Error(position, "incompatible conversion");
					IF VerboseErrorMessage THEN
						Printout.Info("expression",expression);
						Printout.Info("type",type);
					END;
				END;
			END;
			RETURN result
		END MathArrayConversion;

		PROCEDURE ConvertValue(position: Position; expression: SyntaxTree.Value; type: SyntaxTree.Type): SyntaxTree.Expression;
		VAR result: SyntaxTree.Expression; int: Basic.Integer; real, imaginary: LONGREAL; set: Basic.Set; char: CHAR; string: Scanner.StringType;
		BEGIN
			result := expression; type := type.resolved;
			IF (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).arrayBase.resolved IS SyntaxTree.ByteType) THEN
				(* skip, no conversion *)
			ELSIF (expression IS SyntaxTree.IntegerValue)  THEN
				int := expression(SyntaxTree.IntegerValue).value;
				IF (type IS SyntaxTree.IntegerType) OR (type IS SyntaxTree.SizeType) THEN
					int := Global.ConvertSigned(int,system.SizeOf(type));
					result := SyntaxTree.NewIntegerValue(position,int);
					result.SetType(type);
				ELSIF (type IS SyntaxTree.AddressType) OR IsUnsafePointer(type) THEN
					int := Global.ConvertUnsigned(int,system.SizeOf(type));
					result := SyntaxTree.NewIntegerValue(position,int);
					result.SetType(type);
				ELSIF (type IS SyntaxTree.FloatType) THEN
					result := SyntaxTree.NewRealValue(expression.position,int,Scanner.None);
					result.SetType(type);
				ELSIF (type IS SyntaxTree.ComplexType) THEN
					result := SyntaxTree.NewComplexValue(expression.position, int, 0, Scanner.None);
					result.SetType(type);
				ELSIF (type IS SyntaxTree.SetType) THEN
					result := SyntaxTree.NewSetValue(expression.position,SYSTEM.VAL(Basic.Set,int));
					result.SetType(type);
				ELSIF (type IS SyntaxTree.CharacterType) OR (type IS SyntaxTree.ByteType) THEN
					result := SyntaxTree.NewCharacterValue(expression.position,SYSTEM.VAL(CHAR,int));
					result.SetType(type);
				ELSIF (type IS SyntaxTree.EnumerationType) THEN
					result := SyntaxTree.NewEnumerationValue(expression.position,int);
					result.SetType(type);
				ELSIF (type IS SyntaxTree.PortType) THEN
					result := ConvertValue(position, expression, system.integerType);

				ELSE
					Error(position, "integer value cannot be converted");
					result := SyntaxTree.invalidExpression;
					IF VerboseErrorMessage THEN
						Printout.Info("expression",expression);
						Printout.Info("type",type);
					END;
				END;
			ELSIF IsRealValue(expression,real) THEN
				IF (type IS SyntaxTree.IntegerType) & (type.sizeInBits < 64) THEN
					int := Global.ConvertSigned(ENTIER(real),system.SizeOf(type));
					result := SyntaxTree.NewIntegerValue(expression.position,int);
					result.SetType(type);
				ELSIF (type IS SyntaxTree.IntegerType) THEN
					int := ENTIERH(real);
					result := SyntaxTree.NewIntegerValue(expression.position,int);
					result.SetType(type);
				ELSIF (type IS SyntaxTree.FloatType) THEN
					result := SyntaxTree.NewRealValue(position,real,Scanner.None);
					result.SetType(type);
				ELSIF (type IS SyntaxTree.ComplexType) THEN
					result := SyntaxTree.NewComplexValue(expression.position, real, 0, Scanner.None);
					result.SetType(type);
					result(SyntaxTree.ComplexValue).UpdateSubtype;
				ELSIF (type IS SyntaxTree.PortType) THEN
					result := ConvertValue(position, expression, system.integerType);
				ELSE
					Error(position, "real value cannot be converted");
					result := SyntaxTree.invalidExpression;
				END
			ELSIF IsComplexValue(expression, real, imaginary) THEN
				IF (type IS SyntaxTree.ComplexType) THEN
					result := SyntaxTree.NewComplexValue(expression.position, real, imaginary, 0);
					result.SetType(type);
					result(SyntaxTree.ComplexValue).SetSubtype(expression.resolved(SyntaxTree.ComplexValue).subtype) (* reuse subtype *)
				ELSE
					Error(position, "complex value cannot be converted");
					result := SyntaxTree.invalidExpression;
				END
			ELSIF IsSetValue(expression,set) THEN
				IF (type IS SyntaxTree.IntegerType) THEN
					result := SyntaxTree.NewIntegerValue(expression.position,SYSTEM.VAL(Basic.Integer,set));
					result.SetType(type);
				ELSIF (type IS SyntaxTree.CharacterType) OR (type IS SyntaxTree.ByteType) THEN (* for example: possible via ch = CHR(SYSTEM.VAL(Basic.Integer,set)) *)
					result := SyntaxTree.NewCharacterValue(expression.position,SYSTEM.VAL(CHAR,set));
					result.SetType(type);
				ELSIF (type IS SyntaxTree.PortType) THEN
					result := ConvertValue(position, expression, system.integerType);
				ELSIF (type IS SyntaxTree.SetType) THEN
					set := Global.ConvertSet(set,system.SizeOf(type));
					result := SyntaxTree.NewSetValue(expression.position,set);
					result.SetType(type);
				ELSE
					Error(position, "set value cannot be converted");
					result := SyntaxTree.invalidExpression;
				END;
			ELSIF IsStringValue(expression,string) THEN
				IF ((type IS SyntaxTree.CharacterType) OR (type IS SyntaxTree.ByteType)) & (string[1]=0X) THEN
					result := SyntaxTree.NewCharacterValue(expression.position,string[0]);
					result.SetType(type);
				ELSIF (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).arrayBase.resolved IS SyntaxTree.CharacterType) THEN (* nothing to be done *)
				ELSE
					Error(position, "string value cannot be converted");
					result := SyntaxTree.invalidExpression;
				END;
			ELSIF IsCharacterValue(expression,char) THEN
				IF (type IS SyntaxTree.StringType) OR (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).arrayBase.resolved IS SyntaxTree.CharacterType) THEN
					string[0] := char; string[1] := 0X;
					type := SyntaxTree.NewStringType(Basic.invalidPosition,system.characterType,2);
					result := SyntaxTree.NewStringValue(expression.position,string);
					result.SetType(type);
				ELSIF (type IS SyntaxTree.ByteType) THEN
					(* do not simply set the new type as this could invalidate types of constants *)
					result := SyntaxTree.NewCharacterValue(expression.position,char);
					result.SetType(type)
				ELSIF (type IS SyntaxTree.IntegerType) THEN
					result := SyntaxTree.NewIntegerValue(expression.position,SYSTEM.VAL(Basic.Integer,char));
					result.SetType(type);
				ELSIF (type IS SyntaxTree.SetType) THEN
					result := SyntaxTree.NewSetValue(expression.position,SYSTEM.VAL(Basic.Set,Basic.Integer(ORD(char))));
					result.SetType(type);
				ELSIF (type IS SyntaxTree.CharacterType) THEN
					result := SyntaxTree.NewCharacterValue(expression.position,char);
					result.SetType(type);
				ELSIF (type IS SyntaxTree.PortType) THEN
					result := ConvertValue(position, expression, system.integerType);
				ELSE
					Error(position, "character value cannot be converted");
					result := SyntaxTree.invalidExpression;
				END;
			ELSIF expression IS SyntaxTree.NilValue THEN
				IF type IS SyntaxTree.AddressType THEN
					result := SyntaxTree.NewIntegerValue(position,0);
					result.SetType(type);
				ELSE
					result := expression;
				END;
				(* nothing to be done *)
			ELSIF expression IS SyntaxTree.MathArrayValue THEN
				result := MathArrayConversion(position, expression,type);
			ELSIF expression IS SyntaxTree.EnumerationValue THEN
				int := expression(SyntaxTree.EnumerationValue).value;
				IF (type IS SyntaxTree.IntegerType) OR (type IS SyntaxTree.SizeType) THEN
					int := Global.ConvertSigned(int,system.SizeOf(type));
					result := SyntaxTree.NewIntegerValue(position,int);
					result.SetType(type);
				ELSE
					result := expression;
				END;
				(* nothing to be done *)
			ELSE
				Error(position, "expression cannot be converted");
				IF VerboseErrorMessage THEN
					Printout.Info("expression",expression);
					Printout.Info("type",type);
				END;
				result := SyntaxTree.invalidExpression;
			END;
			RETURN result
		END ConvertValue;

		(**
			return a conversion of an expression to a given type
				- if expression is already of same type then return expression
				- if incompatible conversion then report error and return invalidExpression
		**)
		PROCEDURE NewConversion(position: Position; expression: SyntaxTree.Expression; type: SyntaxTree.Type; reference: SyntaxTree.Expression): SyntaxTree.Expression;
		VAR result: SyntaxTree.Expression; value: SyntaxTree.Expression; expressionList: SyntaxTree.ExpressionList; typeDeclaration: SyntaxTree.TypeDeclaration; typeSymbol: SyntaxTree.Designator;
		BEGIN
			type := type.resolved;

			ASSERT(type # NIL); ASSERT(~(type IS SyntaxTree.QualifiedType));
			result := expression;

			IF expression = SyntaxTree.invalidExpression THEN (* error already handled *)
			ELSIF expression = NIL THEN (* NIL expression *)
			ELSIF expression.type = NIL THEN
				Error(position, "expression of type NIL cannot be converted");
			ELSIF expression.type.SameType(type) THEN (* nothing to be done ! *)
			ELSIF IsPointerType(expression.type) & IsPointerType(type) THEN (* nothing to be done *)
			ELSIF (expression.type.resolved IS SyntaxTree.AnyType) THEN (*! binary symbol file problem: ANY and OBJECT cannot be distinguished  *)
			ELSIF (expression.type.resolved IS SyntaxTree.ObjectType) & (type IS SyntaxTree.AnyType) THEN (*! binary symbol file problem *)
			ELSIF expression.resolved # NIL THEN (* value *)
				value := ConvertValue(position,expression.resolved(SyntaxTree.Value),type);
				IF value IS SyntaxTree.Value THEN
					result := SyntaxTree.NewConversion(expression.position,expression,type,reference);
					result.SetResolved(value(SyntaxTree.Value));
					result.SetType(value.type);
				ELSE
					result := value
				END;
			ELSIF (type IS SyntaxTree.ByteType) THEN (* do not convert *)
				expressionList := SyntaxTree.NewExpressionList();
				typeDeclaration := SyntaxTree.NewTypeDeclaration(expression.position,SyntaxTree.NewIdentifier("@byte"));
				typeDeclaration.SetDeclaredType(type);
				typeSymbol := SyntaxTree.NewSymbolDesignator(Basic.invalidPosition,NIL,NIL,typeDeclaration);
				typeSymbol.SetType(typeDeclaration.type);
				expressionList.AddExpression(typeSymbol); (* type declaration symbol skipped *)
				expressionList.AddExpression(expression);
				result := SyntaxTree.NewBuiltinCallDesignator(expression.position,NIL, Global.systemVal,NIL,expressionList);
				result.SetType(type);
			ELSIF (type IS SyntaxTree.MathArrayType) THEN
					IF inConversion>5 THEN
						Error(expression.position,"recursive Conversion");
						IF VerboseErrorMessage THEN
							Printout.Info("expression",expression);
							Printout.Info("type",type);
						END;
					END;
					INC(inConversion);
					IF inConversion < 10 THEN
						IF expression.type.resolved IS SyntaxTree.MathArrayType THEN
							IF IsTensor(expression.type) & (IsUnsafePointer(type) OR (type IS SyntaxTree.AddressType)) THEN
								result := expression
							ELSE
								result := MathArrayConversion(position, expression,type);
							END;
						ELSE
							Error(expression.position,"cannot convert non array type to array type")
						END;
					END;
					DEC(inConversion);
			ELSIF (expression.type.resolved IS SyntaxTree.MathArrayType) THEN
					IF IsTensor(expression.type) & (IsUnsafePointer(type) OR (type IS SyntaxTree.AddressType)) THEN
						result := expression; result.SetType(type);
					ELSIF (expression.type.resolved(SyntaxTree.MathArrayType).form # SyntaxTree.Static)
						OR ~(type IS SyntaxTree.ArrayType) THEN
						Error(expression.position,"cannot convert array type to non-array type")
					END;
			ELSIF IsPointerType(type) & ~IsPointerType(expression.type.resolved) THEN
				result := SyntaxTree.NewConversion(expression.position,expression,system.addressType,reference);
			ELSIF ~(type IS SyntaxTree.BasicType) & ~(expression.type.resolved IS SyntaxTree.CharacterType) THEN
				(*skip, no conversion*)
			ELSIF (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).arrayBase.resolved IS SyntaxTree.ByteType) THEN
				(* skip, no conversion *)
			ELSE
				ASSERT(~(type IS SyntaxTree.RangeType));
				result := SyntaxTree.NewConversion(expression.position,expression,type,reference);
				ASSERT(type # NIL);
			END;
			RETURN result
		END NewConversion;

		PROCEDURE CompatibleConversion(position: Position; expression: SyntaxTree.Expression; type: SyntaxTree.Type): SyntaxTree.Expression;
		BEGIN
			IF CompatibleTo(system,expression.type, type) THEN
				RETURN NewConversion(position, expression, type, NIL);
			ELSE
				Error(expression.position, "incompatible expression");
				RETURN SyntaxTree.invalidExpression
			END;
		END CompatibleConversion;

		(**
			convert operands left and right to a type that both operands are compatible with, if no such type exists then report error
		**)
		PROCEDURE ConvertOperands(VAR left,right: SyntaxTree.Expression);
		VAR leftType,rightType: SyntaxTree.Type;
		BEGIN
			IF left.type = NIL THEN Error(left.position,"no type")
			ELSIF right.type= NIL THEN Error(right.position,"no type")
			ELSIF (left = SyntaxTree.invalidExpression) OR (right = SyntaxTree.invalidExpression) THEN
				(* error already handled *)
			ELSE
				leftType := left.type.resolved; rightType := right.type.resolved;
				IF (leftType IS SyntaxTree.AddressType) & IsAddressExpression(right) THEN
					right := NewConversion(right.position, right, leftType, NIL);
				ELSIF (rightType IS SyntaxTree.AddressType) & IsAddressExpression(left) THEN
					left := NewConversion(left.position,left,rightType,NIL);
				ELSIF (leftType IS SyntaxTree.SizeType) & IsSizeExpression(right) THEN
					right := NewConversion(right.position, right, leftType, NIL);
				ELSIF (rightType IS SyntaxTree.SizeType) & IsSizeExpression(left) THEN
					left := NewConversion(left.position,left,rightType,NIL);
				ELSIF CompatibleTo(system,leftType,rightType) THEN
					left := NewConversion(left.position,left,right.type.resolved,NIL);
				ELSIF CompatibleTo(system,rightType,leftType) THEN
					right := NewConversion(right.position,right,left.type.resolved,NIL);
				ELSIF
					(leftType IS SyntaxTree.ComplexType) & (rightType IS SyntaxTree.FloatType) OR
					(leftType IS SyntaxTree.FloatType) & (rightType IS SyntaxTree.ComplexType) THEN
					(* must be the case LONGREAL / COMPLEX ) *)
					left := NewConversion(left.position, left, Global.Complex128, NIL);
					right := NewConversion(right.position, right, Global.Complex128, NIL);
				ELSE
					Error(left.position,"incompatible operands");
				END;
			END;
		END ConvertOperands;

		(** find and return best operator matching to parameter list (nil, if none)
			- search current module scope and all (directly or indirectly) imported modules for matching operator
			- take operator with smalles distance, where signature distance is computed in procedure Distance
		**)
		PROCEDURE FindOperator(system: Global.System; operator: LONGINT; actualParameters: SyntaxTree.ExpressionList; returnType: SyntaxTree.Type): SyntaxTree.Operator;
		VAR bestOperator: SyntaxTree.Operator; bestDistance: LONGINT; import: SyntaxTree.Import; numberParameters: LONGINT; procedureType: SyntaxTree.ProcedureType;
			identifier: SyntaxTree.Identifier;

			PROCEDURE FindInScope(scope: SyntaxTree.ModuleScope; access: SET);
			VAR operator: SyntaxTree.Operator; distance,i: LONGINT;
			BEGIN
				operator := scope.firstOperator;
				WHILE(operator # NIL) DO
					IF (operator.name=identifier) & (operator.access * access # {}) THEN
						procedureType := operator.type(SyntaxTree.ProcedureType);
						distance := Distance(system, procedureType,actualParameters);
						IF (distance < Infinity) THEN
							IF returnType # NIL THEN
								IF procedureType.returnType = NIL THEN
									distance := Infinity
								ELSE
									i := TypeDistance(system,returnType,procedureType.returnType,TRUE);
									IF i = Infinity THEN distance := Infinity ELSE INC(distance,i) END;
								END;
							END;
						END;

						(*
						IF distance < Infinity THEN
							TRACE(distance, operator);
							Printout.Info("potential operator",operator);
						ELSE
							Printout.Info("operator not possible",operator);
						END;
						*)

						IF distance < bestDistance THEN
							bestDistance := distance;
							bestOperator := operator;
						END;
					END;
					operator := operator.nextOperator;
				END;
				(*
				Printout.Info("taken operator",bestOperator);
				*)
			END FindInScope;

		BEGIN
			bestDistance := Infinity; bestOperator := NIL; numberParameters := actualParameters.Length();
			identifier := Global.GetIdentifier(operator,currentScope.ownerModule.case);
			FindInScope(currentScope.ownerModule.moduleScope,SyntaxTree.ReadOnly);
			import := currentScope.ownerModule.moduleScope.firstImport;
			WHILE (bestDistance > 0) & (import # NIL) DO
				IF import.module # NIL THEN
					identifier := Global.GetIdentifier(operator,import.module.case);
					FindInScope(import.module.moduleScope,SyntaxTree.Public);
				END;
				import := import.nextImport;
			END;
			RETURN bestOperator
		END FindOperator;

		PROCEDURE SetCurrentScope*(scope: SyntaxTree.Scope);
		BEGIN
			currentScope := scope;
		END SetCurrentScope;

		(**
			return a procedure call designator for the best matching operator procedure of the form "op"(leftExpression,rightExpression) (if any)
			- handle LEN and DIM operator for array-structured object types
			- find operator, if found then
				- if in other module then add import designator
				- create symbol designator for operator
			- if error then return invalidExpression, if no operator then return NIL
		**)
		PROCEDURE NewOperatorCall*(position: Position; original: SyntaxTree.Expression; op: LONGINT; leftExpression, rightExpression: SyntaxTree.Expression; resultType: SyntaxTree.Type): SyntaxTree.Expression;
		VAR
			operator: SyntaxTree.Operator;
			import: SyntaxTree.Import;
			expression, result: SyntaxTree.Expression;
			designator: SyntaxTree.Designator;
			actualParameters: SyntaxTree.ExpressionList;
			castReturnType : SyntaxTree.MathArrayType;
		BEGIN
			IF (leftExpression = SyntaxTree.invalidExpression) OR (rightExpression = SyntaxTree.invalidExpression)  THEN
				result := SyntaxTree.invalidExpression

			ELSIF leftExpression = NIL THEN
				result := NIL

			ELSE
				IF ~complexNumbersImported THEN
					IF (leftExpression # NIL) & IsComplexType(leftExpression.type)
						OR (rightExpression # NIL) & IsComplexType(rightExpression.type)
					THEN
						(* operators on complex numbers *)
						ImportModule(Global.ComplexNumbersName,position);
						complexNumbersImported := TRUE;
					END;
				END;

				(* import OCArrayBase if needed *)
				IF ~arrayBaseImported THEN
					IF (leftExpression # NIL) & IsMathArrayType(leftExpression.type) OR (rightExpression # NIL) & IsMathArrayType(rightExpression.type) THEN
						IF op = Global.Dim THEN
							(* not existing in OCArrayBase *)
						ELSIF (op = Global.Len) & (rightExpression # NIL) THEN
							(* not existing in OCArrayBase *)
						ELSE
							ImportModule(Global.ArrayBaseName,position);
							arrayBaseImported := TRUE;
						END
					END;
					IF (op = Global.Len) & (leftExpression # NIL) & IsRangeType(leftExpression.type) & (rightExpression = NIL) THEN
						(* LEN(RANGE) *)
						ImportModule(Global.ArrayBaseName,position);
						arrayBaseImported := TRUE;
					END;
				END;

				actualParameters := SyntaxTree.NewExpressionList();
				actualParameters.AddExpression(leftExpression);
				IF rightExpression # NIL THEN
					actualParameters.AddExpression(rightExpression)
				END;
				operator := FindOperator(system,op,actualParameters,resultType);
				IF operator # NIL THEN
					designator := NIL;
					IF operator.scope.ownerModule # currentScope.ownerModule THEN
						import := currentScope.ownerModule.moduleScope.firstImport;
						WHILE(import # NIL) & (import.module # operator.scope.ownerModule) DO
							import := import.nextImport;
						END;
						expression := NewSymbolDesignator(position,NIL,NIL,import);
						designator := expression(SyntaxTree.Designator);
					END;
					expression := NewSymbolDesignator(position,NIL,designator,operator);
					designator := expression(SyntaxTree.Designator);
					result := NewProcedureCallDesignator(position, original, designator,actualParameters);
					IF op = Scanner.Alias THEN (* hard type cast to same type *)
						castReturnType := SyntaxTree.NewMathArrayType(Basic.invalidPosition, expression.type.scope,SyntaxTree.Tensor);
						castReturnType.SetArrayBase(ArrayBase(leftExpression.type.resolved,MAX(LONGINT)));
						result.SetType(castReturnType);
					END;
				ELSE
					result := NIL;
				END;
			END;
			RETURN result
		END NewOperatorCall;

		(** check and resolve binary expression **)
		PROCEDURE ResolveBinaryExpression(binaryExpression: SyntaxTree.BinaryExpression): SyntaxTree.Expression;
		VAR left,right,result: SyntaxTree.Expression;
			leftType, rightType: SyntaxTree.Type;
			il,ir: Basic.Integer; rl,rr,a,b,c,d,divisor: LONGREAL; hl,hr: Basic.Integer;bl,br: BOOLEAN; sl,sr: Basic.Set;  strl,strr: Scanner.StringType;
			cl,cr: CHAR;
			operator: LONGINT; operatorCall: SyntaxTree.Expression;
			type: SyntaxTree.Type;
			value: SyntaxTree.Value;
			leftFirst, leftLast, leftStep, rightFirst, rightLast, rightStep: Basic.Integer;
			integerConstantFolding: BOOLEAN;
			list: SyntaxTree.ExpressionList;

			PROCEDURE NewBool(v: BOOLEAN);
			BEGIN
				value := SyntaxTree.NewBooleanValue(binaryExpression.position,v);
				value.SetType(system.booleanType);
				result.SetResolved(value);
				type := system.booleanType
			END NewBool;

			PROCEDURE NewSet(v: Basic.Set);
			BEGIN
				value := Global.NewSetValue(system,binaryExpression.position,v);
				result.SetResolved(value);
				type := value.type;
			END NewSet;

			PROCEDURE NewInteger(v: Basic.Integer; t: SyntaxTree.Type);
			BEGIN
				value := Global.NewIntegerValue(system,binaryExpression.position,v);

				(* type cast to "larger" type only if the value is still in the range *)
				IF (t IS SyntaxTree.AddressType) & IsAddressValue(value) THEN
					value.SetType(t);
				END;

				result.SetResolved(value);
				type := value.type;
			END NewInteger;

			PROCEDURE NewReal(v: LONGREAL; t: SyntaxTree.Type);
			BEGIN
				value := SyntaxTree.NewRealValue(binaryExpression.position,v, Scanner.None);
				value.SetType(t);
				result.SetResolved(value);
				type := t;
			END NewReal;

			PROCEDURE NewComplex(realValue, imagValue: LONGREAL; t: SyntaxTree.Type);
			BEGIN
				value := SyntaxTree.NewComplexValue(binaryExpression.position, realValue, imagValue, Scanner.None);
				value.SetType(t);
				value(SyntaxTree.ComplexValue).UpdateSubtype;
				result.SetResolved(value);
				type := t;
			END NewComplex;

		BEGIN
			type := SyntaxTree.invalidType;
			left := ResolveExpression(binaryExpression.left);
			right := ResolveExpression(binaryExpression.right);
			binaryExpression.SetLeft(left);
			binaryExpression.SetRight(right);

			result := binaryExpression;
			operator := binaryExpression.operator;
			IF ~system.operatorDefined[operator] THEN
				Error(left.position,"Operator Not Defined");
				RETURN SyntaxTree.invalidExpression;
			END;
			IF left.type = NIL THEN
				Error(left.position,"Expression has no result type");
				RETURN SyntaxTree.invalidExpression;
			END;
			IF right.type = NIL THEN
				Error(right.position,"Expression has no result type");
				RETURN SyntaxTree.invalidExpression;
			END;
			leftType := left.type.resolved; rightType := right.type.resolved;
			IF ~(leftType IS SyntaxTree.BasicType) OR ~(rightType IS SyntaxTree.BasicType) OR (leftType IS SyntaxTree.ComplexType) OR (rightType IS SyntaxTree.ComplexType) THEN
				operatorCall := NewOperatorCall(binaryExpression.position,binaryExpression, operator,left,right,NIL);
			END;

			IF (operatorCall = NIL) & IsPointerToObject(left.type) THEN
				list := SyntaxTree.NewExpressionList();
				list.AddExpression(right);
				operatorCall := NewObjectOperatorCall(binaryExpression.position, left, operator, NIL, right);
			END;

			IF operatorCall # NIL THEN
				result := operatorCall;
				type := operatorCall.type;

			(* admissible operators:

				Times, Plus, Minus		numeric		numeric		numeric
											set				set				set
				Slash						numeric		numeric		real	/complex
											set				set				set
				Div , Mod					integer			integer			integer
				And, Or					bool			bool			bool
				Equal, Unequal			basic			basic			bool
											pointer		pointer			bool
											object			object			bool
											record			record			bool
											string			string			bool
											enumerator	enumerator	bool

				Less, LessEqual,
				Greater, GreaterEqual		integer/real	integer/real	bool
											enumerator	enumerator	bool

				In							integer			set				bool
				Is							pointer			type			bool
											object			type			bool
											record			type			bool

				Upto: special abbreviation for a..b
			*)

			ELSIF (left.type = NIL) THEN
				Error(left.position,"type (left operand) = NIL in binary expression");
				D.Str("nil type in "); D.Type(left); D.Ln;
				result := SyntaxTree.invalidExpression;
			ELSIF (right.type = NIL) THEN
				Error(right.position,"type (right operand) = NIL in binary expression");
				result := SyntaxTree.invalidExpression;
			ELSIF (leftType = SyntaxTree.invalidType) OR (rightType = SyntaxTree.invalidType) THEN (* error already handled *)
				result := SyntaxTree.invalidExpression;
			ELSIF operator = Scanner.Upto THEN (* left .. right: now solved as RangeExpression*)
				HALT(100);
			ELSIF operator = Scanner.Is THEN (* left IS right: now solved as IsExpression *)
				type := system.booleanType;
				IF  ~(rightType = SyntaxTree.typeDeclarationType) THEN
					Error(right.position,"is not a type ");
				ELSIF ~IsValidTypeTest(leftType, right(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType.resolved) THEN
					Error(binaryExpression.position,"is not a type extension of ");
					IF VerboseErrorMessage THEN
						Printout.Info("left",left);
						Printout.Info("right",right);
					END;
				ELSIF IsUnsafePointer(left.type) THEN
					Error(binaryExpression.position,"forbidden type test on unsafe pointer");
				ELSIF (leftType.SameType(right(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType.resolved)) THEN
					NewBool(TRUE)
				ELSIF right(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType.resolved IS SyntaxTree.AnyType THEN
					NewBool(TRUE);
				ELSIF IsUnextensibleRecord(left) THEN
					NewBool(FALSE)
				ELSIF left.type.resolved.CompatibleTo(right(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType.resolved) THEN
					NewBool(TRUE)
				ELSIF left.resolved # NIL THEN
					NewBool(FALSE);
				END
			ELSIF (right IS SyntaxTree.SymbolDesignator) & (right(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.TypeDeclaration) THEN
				Error(right.position,"must not be a type");
			ELSIF (left IS SyntaxTree.SymbolDesignator) & (left(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.TypeDeclaration) THEN
				Error(left.position,"must not be a type");
			ELSIF operator = Scanner.In THEN (* left IN right *)
				IF IsIntegerType(leftType) & (rightType IS SyntaxTree.SetType) THEN
					IF IsIntegerValue(left,il) & IsSetValue(right,sr) THEN
						NewBool(il IN sr);
					ELSE
						IF leftType.sizeInBits # system.longintType.sizeInBits THEN
							left := NewConversion(left.position, left, system.longintType,NIL);
							binaryExpression.SetLeft(left)
						END;
						type := system.booleanType;
					END
				ELSE
					Error(binaryExpression.position, "incompatible operands");
				END
			ELSIF (leftType IS SyntaxTree.ProcedureType) OR (rightType IS SyntaxTree.ProcedureType) THEN
				IF ~CompatibleTo(system,leftType,rightType) & ~CompatibleTo(system,rightType,leftType) THEN
					Error(binaryExpression.position,"incompatible operands");
				END;

				IF (operator = Scanner.Equal) OR (operator = Scanner.Unequal) THEN type := system.booleanType
				ELSE  Error(binaryExpression.position,"operator not defined 1")
				END
			ELSIF IsPointerType(leftType) OR IsPointerType(rightType) THEN
				IF ~CompatibleTo(system,leftType,rightType) & ~CompatibleTo(system,rightType,leftType) THEN
				(* IsPointerType(leftType) OR ~IsPointerType(rightType) THEN *)
					Error(binaryExpression.position,"incompatible operands");
					IF VerboseErrorMessage THEN Printout.Info("leftType",leftType); Printout.Info("right",rightType) END
				ELSIF (operator = Scanner.Plus) OR (operator = Scanner.Minus) THEN
					left := NewConversion(left.position, left, system.addressType, NIL);
					right := NewConversion(right.position, right, system.addressType, NIL);
					binaryExpression.SetLeft(left);
					binaryExpression.SetRight(right);
					type := system.addressType;
				ELSIF (operator = Scanner.Equal) OR (operator = Scanner.Unequal) THEN
					ConvertOperands(left, right);
					binaryExpression.SetLeft(left);
					binaryExpression.SetRight(right);
					IF (left IS SyntaxTree.NilValue) & (right IS SyntaxTree.NilValue) THEN
						IF operator = Scanner.Equal THEN NewBool(TRUE) ELSE NewBool(FALSE) END;
					END;
					type := system.booleanType;
				ELSE
					Error(binaryExpression.position,"operator not defined 3");
				END
			ELSIF (left.resolved# NIL) & (left.resolved IS SyntaxTree.NilValue) THEN Error(binaryExpression.position,"operator not defined");
			ELSIF (right.resolved # NIL) & (right.resolved IS SyntaxTree.NilValue) THEN Error(binaryExpression.position,"operator not defined");
			ELSIF IsStringType(leftType) & IsStringType(rightType) THEN		(* string ops*)
				IF IsStringType(leftType) & IsStringType(rightType) THEN	(*ok*)
					IF IsStringValue(left,strl) & IsStringValue(right,strr) THEN
						CASE operator OF
						|Scanner.Equal: NewBool(strl^=strr^);
						|Scanner.Unequal:NewBool(strl^#strr^);
						|Scanner.Less: NewBool(strl^<strr^);
						|Scanner.LessEqual: NewBool(strl^<=strr^);
						|Scanner.Greater:  NewBool(strl^>strr^);
						|Scanner.GreaterEqual: NewBool(strl^>=strr^);
						ELSE
							Error(binaryExpression.position,"operator not defined 4");
						END;
					END;
				ELSIF (operator = Scanner.Equal) OR (operator=Scanner.Unequal) OR (operator = Scanner.Less)
						OR (operator = Scanner.LessEqual) OR (operator = Scanner.Greater) OR (operator = Scanner.GreaterEqual) THEN
						type := system.booleanType
				ELSE
					Error(binaryExpression.position,"operator not defined 5");
				END;
				IF (operator = Scanner.Equal) OR (operator=Scanner.Unequal)
					OR (operator = Scanner.Less) OR (operator = Scanner.LessEqual)
					OR (operator = Scanner.Greater) OR (operator = Scanner.GreaterEqual) THEN
					type := system.booleanType;
				ELSE
					Error(binaryExpression.position,"operator not defined 6");
				END
			ELSIF (leftType IS SyntaxTree.EnumerationType) OR (rightType IS SyntaxTree.EnumerationType) THEN
				IF IsEnumerationExtension(left.type,right.type) OR IsEnumerationExtension(right.type,left.type) THEN
					IF (operator = Scanner.Equal) OR (operator = Scanner.Unequal) OR (operator = Scanner.Less) OR (operator = Scanner.LessEqual)
						OR (operator = Scanner.Greater) OR (operator = Scanner.GreaterEqual) THEN
						type := system.booleanType
					ELSE
						Error(binaryExpression.position,"operator not defined for enumerators");
					END;
				ELSE
					Error(binaryExpression.position,"operator not applicable between different enumerators");
				END;
			ELSIF (leftType IS SyntaxTree.PortType) & ((operator = Scanner.Questionmarks) OR (operator = Scanner.ExclamationMarks) OR (operator = Scanner.LessLessQ)) THEN
				type := system.booleanType;
			ELSIF (rightType IS SyntaxTree.PortType) & (operator = Scanner.LessLessQ) THEN
				type := system.booleanType;
			ELSIF (leftType IS SyntaxTree.BasicType) & (rightType IS SyntaxTree.BasicType)
				OR IsCharacterType(leftType) & IsCharacterType(rightType)
			THEN
				integerConstantFolding := IsIntegerValue(left,il) & IsIntegerValue(right,ir);
				IF (leftType # rightType)   THEN
					IF ~integerConstantFolding THEN (* no conversions for constant folding on integer values  *)
						ConvertOperands(left,right); (* operands must be of the same type here *)
					END;
					binaryExpression.SetLeft(left);
					binaryExpression.SetRight(right);
					leftType := left.type.resolved;
					rightType := right.type.resolved;
				END;
				type := leftType;
				IF ~integerConstantFolding & ~leftType.SameType(rightType) THEN
					Error(binaryExpression.position,"conversion failed ?");
					IF VerboseErrorMessage THEN
						Printout.Info("left",left);
						Printout.Info("right",right);
					END;
				ELSIF IsIntegerType(leftType) THEN
					IF IsIntegerValue(right,ir) (* & (right.type.sizeInBits < 64) *) THEN
						hr := right.resolved(SyntaxTree.IntegerValue).value;
						IF (hr=0) & ((operator = Scanner.Mod) OR (operator = Scanner.Div) OR (operator = Scanner.Slash)) THEN
							Error(binaryExpression.position,"division by zero");
						ELSIF (hr<0) & ((operator = Scanner.Mod) OR (operator = Scanner.Div))THEN
							Error(binaryExpression.position,"integer division by negative number");
						END;
					END;
					(* constant folding *)
					(* bootstrap64
					IF IsIntegerValue(left,il) & IsIntegerValue(right,ir)  & (type.sizeInBits < 64) THEN
						CASE operator OF
						|Scanner.Plus: NewInteger(il+ir,left.type);
						|Scanner.Minus: NewInteger(il-ir,left.type);
						|Scanner.Times: NewInteger(il*ir,left.type);
						|Scanner.Slash:
							IF ir # 0 THEN
								NewReal(il/ir, system.realType);
							END;
						|Scanner.Mod:
							IF ir > 0 THEN
								NewInteger(il MOD ir,left.type);
							END;
						|Scanner.Div:
							IF ir > 0 THEN
								NewInteger(il DIV ir,left.type);
							END;
						|Scanner.Equal: NewBool(il=ir);
						|Scanner.Unequal:NewBool(il#ir);
						|Scanner.Less: NewBool(il<ir);
						|Scanner.LessEqual: NewBool(il<=ir);
						|Scanner.Greater:  NewBool(il>ir);
						|Scanner.GreaterEqual: NewBool(il>=ir);
						ELSE Error(binaryExpression.position,"operator not defined 7");
						END;
					ELS*)
					IF IsIntegerValue(left,il) & IsIntegerValue(right,ir) (* bootstrap64 & (type.sizeInBits = 64)*) THEN
						hl := left.resolved(SyntaxTree.IntegerValue).value;
						hr := right.resolved(SyntaxTree.IntegerValue).value;
						CASE operator OF
						|Scanner.Plus: NewInteger(hl+hr,left.type);
						|Scanner.Minus: NewInteger(hl-hr,left.type);
						|Scanner.Times: NewInteger(hl*hr,left.type);
						|Scanner.Slash:
							IF hr = 0 THEN
								Error(binaryExpression.position,"division by zero");
							ELSE
								IF type.sizeInBits = 64 THEN
									NewReal(hl/hr,system.longrealType);
								ELSE
									NewReal(hl/hr,system.realType)
								END
							END;
						(* do the bootstrapping for this kind of expression on hugeint values , then enable: *)
						|Scanner.Mod:
							IF hr = 0 THEN
								Error(binaryExpression.position,"division by zero");
							ELSE
								NewInteger(hl MOD hr, left.type);
								(* bootstrap64
								NewInteger(hl - Machine.DivH(hl,hr)*hr,left.type);
								*)
							END;
						|Scanner.Div:
							IF hr = 0 THEN
								Error(binaryExpression.position,"division by zero");
							ELSE
								NewInteger(hl DIV hr, left.type);
								(* bootstrap64
								NewInteger(Machine.DivH(hl,hr),left.type);
								*)
							END;
						(* *)
						|Scanner.Equal: NewBool(hl=hr);
						|Scanner.Unequal: NewBool(hl#hr);
						|Scanner.Less: NewBool(hl<hr);
						|Scanner.LessEqual: NewBool(hl<=hr);
						|Scanner.Greater: NewBool(hl>hr);
						|Scanner.GreaterEqual:NewBool(hl>=hr);
						ELSE Error(binaryExpression.position,"operator not defined 8");
						END;
					ELSIF (operator = Scanner.Plus) OR (operator = Scanner.Minus) OR (operator = Scanner.Times) OR
					(operator = Scanner.Mod) OR (operator = Scanner.Div) THEN
						type := left.type
					ELSIF (operator = Scanner.Slash) THEN
						left := NewConversion(left.position,left,system.realType,NIL);
						right := NewConversion(right.position,right,system.realType,NIL);
						binaryExpression.SetLeft(left);
						binaryExpression.SetRight(right);
						type := system.realType
					ELSIF (operator = Scanner.Equal) OR (operator = Scanner.Unequal) OR (operator = Scanner.Less) OR (operator = Scanner.LessEqual)
						OR (operator = Scanner.Greater) OR (operator = Scanner.GreaterEqual) THEN
						type := system.booleanType
					ELSE
						Error(binaryExpression.position,"operator not defined 9");
					END;
				ELSIF (leftType IS SyntaxTree.FloatType) THEN
					IF IsRealValue(left,rl) & IsRealValue(right,rr) THEN
						CASE operator OF
						|Scanner.Plus: NewReal(rl+rr,leftType);
						|Scanner.Minus: NewReal(rl-rr,leftType);
						|Scanner.Times:NewReal(rl*rr,leftType);
						|Scanner.Slash:
							IF rr = 0 THEN
								Error(binaryExpression.position,"division by zero");
							ELSE
								NewReal(rl/rr,leftType);
							END
						|Scanner.Equal: NewBool(rl=rr);
						|Scanner.Unequal: NewBool(rl#rr);
						|Scanner.Less: NewBool(rl<rr);
						|Scanner.LessEqual:  NewBool(rl<=rr);
						|Scanner.Greater:  NewBool(rl>rr);
						|Scanner.GreaterEqual: NewBool(rl>=rr);
						ELSE Error(binaryExpression.position,"operator not defined 10");
						END;
					ELSIF (operator = Scanner.Plus) OR (operator = Scanner.Minus) OR (operator = Scanner.Times) OR (operator = Scanner.Slash) THEN
						type := left.type
					ELSIF (operator = Scanner.Equal) OR (operator = Scanner.Unequal) OR (operator = Scanner.Less) OR (operator = Scanner.LessEqual)
						OR (operator = Scanner.Greater) OR (operator = Scanner.GreaterEqual) THEN
						type := system.booleanType
					ELSE
						Error(binaryExpression.position,"operator not defined 11");
						IF VerboseErrorMessage THEN
							Printout.Info("left",left);
							Printout.Info("right",right);
						END;
					END;
				ELSIF (leftType IS SyntaxTree.ComplexType) THEN
					CASE operator OF
					|Scanner.Plus, Scanner.Minus, Scanner.Times, Scanner.Slash: type := left.type
					|Scanner.Equal, Scanner.Unequal: type := system.booleanType
					ELSE
						Error(binaryExpression.position,"operator not defined");
						IF VerboseErrorMessage THEN
							Printout.Info("left", left);
							Printout.Info("right", right)
						END;
					END;

					IF ~error THEN
						IF (operator = Scanner.Slash) & IsComplexValue(right, c, d) & (c = 0) & (d = 0) THEN
							Error(binaryExpression.position,"division by zero")
						ELSIF IsComplexValue(left, a, b) & IsComplexValue(right, c, d) THEN
							(* do constant folding *)
							CASE operator OF
							|Scanner.Plus: NewComplex(a + b, c + d, leftType)
							|Scanner.Minus: NewComplex(a - b, c - d, leftType)
							|Scanner.Times: NewComplex(a * c - b * d, b * c + a * d, leftType)
							|Scanner.Slash:
								divisor := c * c + d * d;
								ASSERT(divisor # 0);
								NewComplex((a * c + b * d) / divisor, (b * c - a * d) / divisor, leftType)
							|Scanner.Equal: NewBool((a = c) & (b = d))
							|Scanner.Unequal: NewBool((a # c) OR (b # d))
							END
						END
					END

				ELSIF (leftType IS SyntaxTree.BooleanType) THEN
					IF IsBooleanValue(left,bl) & IsBooleanValue(right,br) THEN
						CASE operator OF
						|Scanner.And: NewBool(bl & br);
						|Scanner.Or: NewBool(bl OR br);
						|Scanner.Equal: NewBool(bl = br);
						|Scanner.Unequal: NewBool(bl # br);
						ELSE Error(binaryExpression.position,"operator not defined 12");
						END;
					ELSIF (operator = Scanner.Equal) OR (operator = Scanner.Unequal) OR (operator = Scanner.And) OR (operator = Scanner.Or)  THEN
						type := system.booleanType
					ELSE
						Error(binaryExpression.position,"operator not defined 13");
					END;
				ELSIF left.type.resolved IS SyntaxTree.RangeType THEN
					(* constant folding *)
					IF IsStaticRange(left, leftFirst, leftLast, leftStep) & IsStaticRange(right, rightFirst, rightLast, rightStep) THEN
						IF operator = Scanner.Equal THEN
							NewBool((leftFirst = rightFirst) & (leftLast = rightLast) & (leftStep = rightStep))
						ELSIF operator = Scanner.Unequal THEN
							NewBool((leftFirst # rightFirst) OR (leftLast # rightLast) OR (leftStep # rightStep))
						END;
					END;

					IF (operator = Scanner.Equal) OR (operator = Scanner.Unequal) THEN
						type := system.booleanType;
					ELSE
						Error(binaryExpression.position, "operator not defined");
					END;
				ELSIF (leftType IS SyntaxTree.SetType) THEN
					IF IsSetValue(left,sl) & IsSetValue(right,sr) THEN
						CASE operator OF
						|Scanner.Plus: NewSet(sl + sr);
						|Scanner.Minus:  NewSet(sl - sr);
						|Scanner.Times:  NewSet(sl * sr);
						|Scanner.Slash:  NewSet(sl / sr);
						|Scanner.Equal:  NewBool(sl=sr);
						|Scanner.Unequal: NewBool(sl#sr);
						|Scanner.Less: NewBool( (sl * sr = sl) & (sl#sr));
						|Scanner.LessEqual: NewBool(sl*sr = sl);
						|Scanner.Greater: NewBool( (sl * sr = sr) & (sl # sr));
						|Scanner.GreaterEqual: NewBool(sl*sr = sr);
						ELSE Error(binaryExpression.position,"operator not defined 14");
						END;
					ELSIF (operator = Scanner.Equal) OR (operator = Scanner.Unequal)
						OR (operator = Scanner.Less) OR (operator = Scanner.LessEqual)
						OR (operator = Scanner.Greater) OR (operator = Scanner.GreaterEqual)  (* implement inclusion *)
						THEN
						type := system.booleanType
					ELSIF (operator = Scanner.Plus) OR (operator = Scanner.Minus) OR (operator = Scanner.Times) OR (operator = Scanner.Slash) THEN
						type := left.type
					ELSE
						Error(binaryExpression.position,"operator not defined 15");
					END;
				ELSIF IsCharacterType(left.type) THEN
					IF IsCharacterValue(left,cl) & IsCharacterValue(right,cr) THEN
						CASE operator OF
						|Scanner.Equal:  NewBool(cl=cr);
						|Scanner.Unequal: NewBool(cl#cr);
						|Scanner.Less: NewBool(cl<cr);
						|Scanner.LessEqual:  NewBool(cl<=cr);
						|Scanner.Greater:  NewBool(cl>cr);
						|Scanner.GreaterEqual: NewBool(cl>=cr);
						ELSE Error(binaryExpression.position,"operator not defined 16");
						END;
					ELSIF (operator = Scanner.Equal) OR (operator = Scanner.Unequal) OR (operator = Scanner.Less) OR (operator = Scanner.LessEqual)
						OR (operator = Scanner.Greater) OR (operator = Scanner.GreaterEqual) THEN
						type := system.booleanType
					ELSE
						Error(binaryExpression.position,"operator not defined 17");
					END;
				ELSE
					Error(binaryExpression.position,"operator not defined 18");
				END;
			ELSE
				Error(binaryExpression.position,"operator not defined 19");
			END;
			IF type = SyntaxTree.invalidType THEN
				result := SyntaxTree.invalidExpression
			ELSE
				result.SetType(type)
			END;
			RETURN result
		END ResolveBinaryExpression;

		(** resolve a range expression of the from <<first .. last BY step>>
			- depending on the context different things are checked:
				ArrayIndex:
					- components must be integers
					- replace missing lower bound with 0
					- replace missing upper bound with MAX(LONGINT)
					- replace missing step size with 1
				SetElement:
					- components must be integers
					- replace missing lower bound with 0
					- replace missing upper bound with MAX(SET)
					- must not have step size
				CaseGuard:
					- components must be constant
					- components must be integers or characters
					- must have lower and upper bound present
					- components are made compatible
					- must not have step size
			- if error: return invalidExpression
		**)
		PROCEDURE ResolveRangeExpression(x: SyntaxTree.RangeExpression): SyntaxTree.Expression;
		VAR
			hasError: BOOLEAN;
			first, last, step: SyntaxTree.Expression;

		BEGIN
			hasError := FALSE;
			first := x.first;
			last := x.last;
			step := x.step;

			(* check lower bound *)
			IF x.context = SyntaxTree.CaseGuard THEN
				IF first = NIL THEN
					Error(x.position, "missing lower bound");
					hasError := TRUE
				ELSE
					first := ResolveExpression(first);
					IF ~IsIntegerType(first.type.resolved) & ~IsCharacterType(first.type.resolved) THEN
						Error(first.position, "lower bound not integer or character");
						hasError := TRUE
					ELSE
						IF first IS SyntaxTree.StringValue THEN
							(* add conversion from string to character *)
							first := ConvertValue(first.position, first(SyntaxTree.Value), system.characterType)
						END
					END;

					(* check if expression is constant *)
					IF ConstantExpression(first) = SyntaxTree.invalidExpression THEN
						(* error already reported *)
						hasError := TRUE
					END
				END

			ELSE (* ArrayIndex, SetElement *)
				IF first = NIL THEN
					first := SyntaxTree.NewIntegerValue(x.position, 0);
				END;
				first := ResolveExpression(first);
				IF IsIntegerType(first.type.resolved)  THEN
					first := NewConversion(first.position, first, system.lenType, NIL)
				ELSE
					Error(first.position, "lower bound not integer");
					hasError := TRUE
				END
			END;

			(* check upper bound *)
			IF x.context = SyntaxTree.CaseGuard THEN
				IF last = NIL THEN
					Error(x.position, "missing upper bound");
					hasError := TRUE
				ELSE
					last := ResolveExpression(last);
					IF ~IsIntegerType(last.type.resolved) & ~IsCharacterType(last.type.resolved) THEN
						Error(last.position, "lower bound not integer or character");
						hasError := TRUE
					ELSE
						IF last IS SyntaxTree.StringValue THEN
							(* add conversion from string to character *)
							last := ConvertValue(last.position, last(SyntaxTree.Value), system.characterType)
						END
					END;

					(* check if expression is constant *)
					IF ConstantExpression(last) = SyntaxTree.invalidExpression THEN
						(* error already reported *)
						hasError := TRUE
					ELSE
						(* try to make lower and upper bound compatible *)
						ConvertOperands(first, last);
						IF first.type.resolved # last.type.resolved THEN
							Error(x.position, "lower and upper bounds incompatible");
							hasError := TRUE
						END
					END
				END

			ELSE (* ArrayIndex, SetElement *)
				IF last = NIL THEN
					IF x.context = SyntaxTree.ArrayIndex THEN
						last := SyntaxTree.NewIntegerValue(x.position, MAX(LONGINT))
					ELSE
						last := SyntaxTree.NewIntegerValue(x.position, MAX(SET))
					END
				END;
				last := ResolveExpression(last);
				IF IsIntegerType(last.type.resolved) THEN
					last := NewConversion(last.position, last, system.lenType, NIL)
				ELSE
					Error(last.position, "upper bound not integer");
					hasError := TRUE
				END
			END;

			(* check step size *)
			IF x.context = SyntaxTree.ArrayIndex THEN
				IF step = NIL THEN
					step := SyntaxTree.NewIntegerValue(x.position, 1)
				END;
				step := ResolveExpression(step);
				IF IsIntegerType(step.type.resolved) THEN
					step := NewConversion(step.position, step, system.lenType, NIL)
				ELSE
					Error(step.position, "step size not integer");
					hasError := TRUE
				END
			ELSE (* SetElement, CaseGuard *)
				IF step # NIL THEN
					Error(last.position, "step size not allowed in this context");
					hasError := TRUE
				END
			END;

			IF hasError THEN
				RETURN SyntaxTree.invalidExpression
			ELSE
				x.SetFirst(first);
				x.SetLast(last);
				x.SetStep(step);
				x.SetType(system.rangeType);
				x.SetAssignable(FALSE); (* range expressions may never be assigned to *)
				RETURN x;
			END
		END ResolveRangeExpression;

		(** resolve the expression d and return result as designator
			- resolve expression
			- if expression is a designator then return designator else error message and return invalidDesignator
		**)
		PROCEDURE ResolveDesignator(d: SyntaxTree.Expression): SyntaxTree.Designator;
		VAR result: SyntaxTree.Designator; resolved: SyntaxTree.Expression;
		BEGIN
			IF Trace THEN D.Str("ResolveDesignator"); D.Ln; END;
			resolved := ResolveExpression(d);
			IF resolved = SyntaxTree.invalidExpression THEN
				(* error should already have been reported *)
				result := SyntaxTree.invalidDesignator;
			ELSIF resolved IS SyntaxTree.Designator THEN
				result := resolved(SyntaxTree.Designator);
			ELSE
				Error(d.position,"is no designator ! ");
				result := SyntaxTree.invalidDesignator;
			END;

			(* result.type might be nil.  *)
			RETURN result
		END ResolveDesignator;

		(**
			self designator generated in this module
			nothing to be resolved
		**)
		PROCEDURE ResolveSelfDesignator(x: SyntaxTree.SelfDesignator): SyntaxTree.Expression;
		VAR scope: SyntaxTree.Scope; record: SyntaxTree.RecordType; type: SyntaxTree.Type; cell: SyntaxTree.CellType;
		BEGIN
			(* check if in record scope *)
			scope := currentScope;
			IF (scope IS SyntaxTree.ProcedureScope) & (scope(SyntaxTree.ProcedureScope).ownerProcedure.type(SyntaxTree.ProcedureType).selfParameter # NIL) THEN
					RETURN NewSymbolDesignator(x.position, x, NIL, scope(SyntaxTree.ProcedureScope).ownerProcedure.type(SyntaxTree.ProcedureType).selfParameter);
			END;

			WHILE (scope # NIL) & ~(scope IS SyntaxTree.RecordScope) &~(scope IS SyntaxTree.CellScope) DO
				scope := scope.outerScope;
			END;
			IF scope = NIL THEN (* in module scope *)
				x.SetType(system.anyType);
			ELSIF scope IS SyntaxTree.CellScope THEN
				cell := scope(SyntaxTree.CellScope).ownerCell;
				x.SetType(cell);
			ELSE (* in record scope *)
				record := scope(SyntaxTree.RecordScope).ownerRecord;
				IF (record # NIL) & (record.pointerType # NIL) THEN
					type := ResolveType(record.pointerType);
					x.SetType(type);
				ELSE
					x.SetType(record);
					x.SetAssignable(TRUE); (* var parameter *)
				END;
			END;
			RETURN x;
		END ResolveSelfDesignator;

		PROCEDURE ResolveResultDesignator(x: SyntaxTree.ResultDesignator): SyntaxTree.Expression;
		VAR scope: SyntaxTree.Scope; procedure: SyntaxTree.Procedure; procedureType: SyntaxTree.ProcedureType; returnType: SyntaxTree.Type;
		BEGIN
			scope := currentScope;
			IF (scope # NIL) & ((scope IS SyntaxTree.ProcedureScope) OR (scope IS SyntaxTree.BlockScope)) THEN
				IF scope IS SyntaxTree.ProcedureScope THEN
					procedure := scope(SyntaxTree.ProcedureScope).ownerProcedure;
					procedureType := procedure.type(SyntaxTree.ProcedureType);
					returnType := procedureType.returnType;
				ELSE
					returnType := currentResultType;
				END;
				IF IsPointerType(returnType) OR IsArrayType(returnType) OR IsMathArrayType(returnType) & ReturnedAsParameter(system, returnType) OR ReturnedAsParameter(system,returnType)
				THEN
					x.SetType(returnType);
				ELSE
					Error(x.position,"forbidden access to result designator (only pointer, array and math array)");
					x.SetType(SyntaxTree.invalidType);
				END;
			ELSE
				Error(x.position,"forbidden access to result designator");
				x.SetType(SyntaxTree.invalidType);
			END;
			x.SetAssignable(TRUE);
			RETURN x;
		END ResolveResultDesignator;

		(**
			return symbol designator as an expression
			- if symbol is a constant then return the constant value expression
			- else
				- if no left designator present then do auto-self if in record scope identifier-> SELF.identiifer
				- if symbol is a guarded variable then return a TypeGuardDesignator
				- else return a symbol designator
		**)
		PROCEDURE NewSymbolDesignator*(position: Position; original: SyntaxTree.Expression; left: SyntaxTree.Expression; symbol: SyntaxTree.Symbol): SyntaxTree.Expression;
		VAR result: SyntaxTree.Expression; assignable: BOOLEAN; scope: SyntaxTree.Scope;
		guardType: SyntaxTree.Type;
		BEGIN
			IF Trace THEN D.Str("NewSymbolDesignator "); D.Ln; END;
			result := SyntaxTree.invalidExpression;
			ASSERT(symbol # NIL);
			(*
			not necessary any more since a type declaration is of type SyntaxTree.typeDeclarationType now
			IF symbol IS SyntaxTree.TypeDeclaration THEN
				Error(position, "type not allowed here");
			ELS *)

			(* not needed any more as values are stored in the expression
			IF symbol IS SyntaxTree.Constant THEN
				result := symbol(SyntaxTree.Constant).value
				IF symbol(SyntaxTree.Constant).value # NIL THEN
				IF symbol(SyntaxTree.Constant).value IS SyntaxTree.Value THEN
					result := symbol(SyntaxTree.Constant).value(SyntaxTree.Value).Copy(position);
				ELSE
					result := symbol(SyntaxTree.Constant).value
				END;
			ELSE
			*)
			IF (left = NIL) & (symbol.scope IS SyntaxTree.RecordScope)
				OR (left = NIL) & (symbol.scope IS SyntaxTree.CellScope) & cellsAreObjects
			THEN
				left := ResolveDesignator(SyntaxTree.NewSelfDesignator(position,left)); (* auto self *)
				IF (IsPointerType(left.type) OR (left.type.resolved IS SyntaxTree.CellType) & cellsAreObjects) &~(symbol IS SyntaxTree.Import) THEN
					left := NewDereferenceDesignator(position,left,left);
					left.SetHidden(TRUE);
				END;
			ELSIF (symbol.scope IS SyntaxTree.ProcedureScope) THEN
				scope := currentScope;
				WHILE (scope # NIL) & (scope # symbol.scope) & ~(scope IS SyntaxTree.RecordScope) DO
					scope := scope.outerScope;
				END;
				IF (scope # NIL) & (scope # symbol.scope) & ~(symbol IS SyntaxTree.Constant) THEN
					Error(position, "forbidden access to symbol in parent procedure scope");
				END;
			END;

			assignable := (left = NIL) OR left.assignable OR (left IS SyntaxTree.DereferenceDesignator)
				OR (left IS SyntaxTree.SelfDesignator)
				OR (left IS SyntaxTree.SymbolDesignator) & (left(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Import);

			IF (currentScope # NIL) & (symbol.scope.ownerModule # currentScope.ownerModule) THEN
				assignable := assignable & (SyntaxTree.PublicWrite IN symbol.access);
			ELSE
				assignable := assignable & (SyntaxTree.InternalWrite IN symbol.access);
			END;

			assignable := assignable & ((symbol IS SyntaxTree.Variable) OR (symbol IS SyntaxTree.Parameter)
				& (symbol(SyntaxTree.Parameter).kind # SyntaxTree.ConstParameter) & ~(symbol(SyntaxTree.Parameter).ownerType IS SyntaxTree.CellType)
				)
				OR (symbol IS SyntaxTree.Alias) & (symbol(SyntaxTree.Alias).expression.assignable)
				;

			result := SyntaxTree.NewSymbolDesignator(position,original,left,symbol);
			result.SetType(symbol.type);
			result.SetAssignable(assignable);
			symbol.MarkUsed;
			IF symbol IS SyntaxTree.Constant THEN
				result.SetResolved(symbol(SyntaxTree.Constant).value.resolved);
			END;

			IF (symbol IS SyntaxTree.Variable) & ~(symbol IS SyntaxTree.Property) THEN
				variableAccessed := TRUE
			END;

			IF (left = NIL) OR (left IS SyntaxTree.SelfDesignator) OR (left IS SyntaxTree.DereferenceDesignator) & (left(SyntaxTree.DereferenceDesignator).left IS SyntaxTree.SelfDesignator) THEN
				IF GetGuard(symbol,guardType) THEN
					IF (symbol.type.resolved IS SyntaxTree.RecordType) OR ~assignable THEN (* type guard is tested and type cannot be changed *)
						result.SetType(guardType);
					ELSE
						result := NewTypeGuardDesignator(position,original, result(SyntaxTree.SymbolDesignator),guardType, result);
					END;
				END;
			END;

			ASSERT(result.type # NIL);
			RETURN result
		END NewSymbolDesignator;

		(** check and resolve an identifier designator "identifier"
			- if identifier = self then return SelfDesignator
			- else find symbol in current scope
				- if symbol found then return SymbolDesignator, else error message and return invalidDesignator
		**)
		PROCEDURE ResolveIdentifierDesignator(identifierDesignator: SyntaxTree.IdentifierDesignator): SyntaxTree.Expression;
		VAR symbol: SyntaxTree.Symbol;
		BEGIN
			IF Trace THEN D.Str("ResolveIdentifierDesignator "); D.Ln; END;
			symbol := Find(currentScope,identifierDesignator.identifier,TRUE);
			IF symbol # NIL THEN
				ResolveSymbol(symbol);
				ASSERT(symbol.type # NIL);
				RETURN NewSymbolDesignator(identifierDesignator.position,identifierDesignator,NIL,symbol);
			ELSE
				Error(identifierDesignator.position,"Undeclared Identifier");
				IF VerboseErrorMessage THEN
					Printout.Info("cannot find symbol in scope", currentScope);
					Printout.Info("undeclared identifier designator",identifierDesignator);
				END;
				RETURN SyntaxTree.invalidDesignator;
			END;
		END ResolveIdentifierDesignator;

		(** check and resolve a selector designator of the form left.designator
			- if left is a pointer type then do auto dereferenciation
			- left denotes a search scope:
				- if left type is import type then set search scope to respective module
				- if left type is enumeration type then set search scope to respective enumeration scope
				- elsif left type is record type then set search scope to record scope
			- search symbol in computed scope
			returns selector designator (via global variable resolvedExpression) if symbol found, else error message is given and invalidDesignator is returned
		**)
		PROCEDURE ResolveSelectorDesignator(selectorDesignator: SyntaxTree.SelectorDesignator): SyntaxTree.Expression;
		VAR
			symbol: SyntaxTree.Symbol; left: SyntaxTree.Expression; scope: SyntaxTree.Scope;
			module: SyntaxTree.Module; result: SyntaxTree.Expression; type: SyntaxTree.Type;
		BEGIN
			IF Trace THEN D.Str("ResolveSelectorDesignator"); D.Ln; END;
			left := ResolveDesignator(selectorDesignator.left);

			result := SyntaxTree.invalidDesignator;
			IF left # NIL THEN
				IF (left.type # NIL) & IsPointerType(left.type.resolved) THEN
					left := NewDereferenceDesignator(selectorDesignator.position,left,left);
				END;
				scope := NIL;
				IF left.type = NIL THEN
					Error(selectorDesignator.position,"field on nil typed designator");
					IF VerboseErrorMessage THEN Printout.Info("nil typed designator",left) END;
				ELSIF left.type.resolved = SyntaxTree.invalidType THEN (* error already handled *)
				ELSIF left.type.resolved = SyntaxTree.importType THEN
					symbol := left(SyntaxTree.SymbolDesignator).symbol;
					module := symbol(SyntaxTree.Import).module;
					IF module # NIL THEN
						scope := module.moduleScope
					ELSE
						Error(left.position,"module not loaded");
						IF VerboseErrorMessage THEN Printout.Info("unloaded module",symbol) END;
					END;
				ELSIF left.type.resolved IS SyntaxTree.RecordType THEN
					scope := left.type.resolved(SyntaxTree.RecordType).recordScope;
					ASSERT(scope # NIL)
				ELSIF left.type.resolved = SyntaxTree.typeDeclarationType THEN
					symbol := left(SyntaxTree.SymbolDesignator).symbol;
					type := symbol(SyntaxTree.TypeDeclaration).declaredType.resolved;
					IF type IS SyntaxTree.EnumerationType THEN
						scope := type(SyntaxTree.EnumerationType).enumerationScope;
					ELSE
						Error(selectorDesignator.position,"field on non-enumeration type declaration");
						IF VerboseErrorMessage THEN Printout.Info("non-record type designator",left) END;
					END;
				ELSIF left.type.resolved IS SyntaxTree.CellType THEN
					scope := left.type.resolved(SyntaxTree.CellType).cellScope;
				ELSE
					Error(selectorDesignator.position,"field on non-record type designator");
					IF VerboseErrorMessage THEN Printout.Info("non-record type designator",left) END;
				END;

				symbol := NIL;
				IF scope # NIL THEN
					symbol := Find(scope,selectorDesignator.identifier,FALSE (* do not visit nested scopes *));
					IF symbol # NIL THEN
						ResolveSymbol(symbol);
						result := NewSymbolDesignator(selectorDesignator.position,selectorDesignator,left,symbol);
						symbol.MarkUsed
					ELSE
						Error(selectorDesignator.position,"undeclared identifier (selector)");
						IF VerboseErrorMessage THEN
							D.Str("IDENT = "); D.Str0(selectorDesignator.identifier); D.Ln;
							Printout.Info("scope", scope);
							Printout.Info("left", left);
							Printout.Info("undeclared identifier",selectorDesignator);
							Printout.Info("left resolved designator",left);
						END
					END;
				END;

			END;
			RETURN result
		END ResolveSelectorDesignator;

		PROCEDURE IndexCheck(index,length: SyntaxTree.Expression);
		VAR len,idx: Basic.Integer;
		BEGIN
			IF (index # NIL) & IsIntegerValue(index,idx) THEN
				IF idx < 0 THEN
					Error(index.position,"index out of bounds (too small)")
				ELSE
					IF (length # NIL) & IsIntegerValue(length,len) & (idx >= len)  THEN
						Error(index.position,"index out of bounds (too large)");
					END;
				END;
			END;
		END IndexCheck;

		(*
			- if index designator has not type, use newBaseType as its type
			- otherwise, replace the element type (last base type of math array chain) with newBaseType
			- special rule: if static array of dynamic array occurs, make it all dynamic

			index designator type:	new base type:		new index designator type:
			NIL						z					z
			ARRAY [x, y]			z					ARRAY [x, y] OF z
			ARRAY [x, y]			ARRAY [z]			ARRAY [x, y, z]
			ARRAY [x, y]			ARRAY [*]			ARRAY [*, *, *]
		*)
		PROCEDURE SetIndexBaseType(indexDesignator: SyntaxTree.IndexDesignator; newBaseType: SyntaxTree.Type);
		VAR
			mathArrayType: SyntaxTree.MathArrayType;
			makeDynamic: BOOLEAN;
		BEGIN
			IF indexDesignator.type = NIL THEN
				indexDesignator.SetType(newBaseType)
			ELSE
				(* index designator must be a of math array type *)
				ASSERT(indexDesignator.type.resolved IS SyntaxTree.MathArrayType);
				mathArrayType := indexDesignator.type.resolved(SyntaxTree.MathArrayType);

				(* determine if all arrays have to be made dynamic *)
				makeDynamic :=
						(newBaseType.resolved IS SyntaxTree.MathArrayType) &
						(newBaseType.resolved(SyntaxTree.MathArrayType).form # SyntaxTree.Static);

				WHILE (mathArrayType.arrayBase # NIL) & (mathArrayType.arrayBase IS SyntaxTree.MathArrayType) DO
					IF makeDynamic THEN mathArrayType.SetForm(SyntaxTree.Open) END;
					mathArrayType := mathArrayType.arrayBase(SyntaxTree.MathArrayType)
				END;
				IF makeDynamic THEN mathArrayType.SetForm(SyntaxTree.Open) END;
				mathArrayType.SetArrayBase(newBaseType)
			END
		END SetIndexBaseType;

		(** check and append index list element to index designator of math array
			- check validity of single index or array range
			- compute new type
				- if range then create new array type (calculate length of resulting array)
				- otherwise take sourceArray.arrayBase as new type
				- type is not only replaced but might have to be inserted when resolving expressions of the form A[*,i,j,*]
		**)
		PROCEDURE AppendMathIndex(position: Position; indexDesignator: SyntaxTree.IndexDesignator; indexListItem: SyntaxTree.Expression; sourceArray: SyntaxTree.MathArrayType);
		VAR
			targetArray: SyntaxTree.MathArrayType;
			first, last, step: SyntaxTree.Expression;
			firstValue, lastValue, stepValue, length: Basic.Integer;
			rangeExpression: SyntaxTree.RangeExpression;
		BEGIN
			IF indexListItem.type = SyntaxTree.invalidType THEN
				(* error already handled *)
				indexDesignator.parameters.AddExpression(indexListItem)

			ELSIF indexListItem IS SyntaxTree.TensorRangeExpression THEN
				indexDesignator.HasRange;
				indexDesignator.HasTensorRange;
				indexDesignator.parameters.AddExpression(indexListItem);
				indexDesignator.SetType(SyntaxTree.NewMathArrayType(position, NIL, SyntaxTree.Tensor))

			ELSIF IsIntegerType(indexListItem.type.resolved) THEN
				IndexCheck(indexListItem, sourceArray.length);
				indexListItem := NewConversion(Basic.invalidPosition, indexListItem, system.sizeType, NIL);
				indexDesignator.parameters.AddExpression(indexListItem)

			ELSIF indexListItem.type.resolved IS SyntaxTree.RangeType THEN
				indexDesignator.HasRange;

				(* if the range is given as an array range expression, check the validity of its components *)
				IF indexListItem IS SyntaxTree.RangeExpression THEN
					rangeExpression := indexListItem(SyntaxTree.RangeExpression);
					first := rangeExpression.first;
					last := rangeExpression.last;
					step := rangeExpression.step;

					(* perform static checks on range components *)

					IF IsIntegerValue(first, firstValue) & (firstValue < 0) THEN
						Error(indexListItem.position,"lower bound of array range too small")
					END;
					IF IsIntegerValue(last, lastValue) & (lastValue # MAX(LONGINT)) THEN
						IF (sourceArray.length # NIL) & IsIntegerValue(sourceArray.length, length) & (lastValue > (length - 1)) THEN
							Error(indexListItem.position,"upper bound of array range too large")
						END
					END;
					IF IsIntegerValue(step, stepValue) & (stepValue < 1) THEN
						Error(indexListItem.position,"invalid step size")
					END;

					(* add conversions to size type *)
					(* TODO: needed? *)
					rangeExpression.SetFirst(NewConversion(Basic.invalidPosition, first, system.lenType, NIL));
					rangeExpression.SetLast(NewConversion(Basic.invalidPosition, last, system.lenType, NIL));
					rangeExpression.SetStep(NewConversion(Basic.invalidPosition, step, system.lenType, NIL));
				END;

				IF indexDesignator.hasTensorRange THEN
					(* the index designator's base type is a tensor: leave it as is *)
				ELSE
					(* append a new math array to the index designator's base type *)
					targetArray := SyntaxTree.NewMathArrayType(position, NIL, SyntaxTree.Open);

					IF ~error THEN
						(*
						(* optimization: calculate length of target array for static ranges *)
						IF indexListItem IS SyntaxTree.RangeExpression THEN
							IF IsStaticallyOpenRange(rangeExpression) THEN
								(* range is open ('*'): reuse source array length as target array length *)
								targetArray.SetLength(sourceArray.length); (* the length may or may not be static *)
								targetArray.SetIncrement(sourceArray.staticIncrementInBits)

							ELSIF IsStaticRange(rangeExpression, firstValue, lastValue, stepValue) THEN
								IF lastValue = MAX(LONGINT) THEN
									IF IsIntegerValue(sourceArray.length, length) THEN
										lastValue := length - 1;
										isStaticTargetArrayLength := TRUE
									ELSE
										isStaticTargetArrayLength := FALSE
									END
								ELSE
									isStaticTargetArrayLength := TRUE
								END;
								IF isStaticTargetArrayLength THEN
									(* calculate static target array length *)
									IF firstValue > lastValue THEN
										length := 0
									ELSE
										length := 1 + lastValue - firstValue;
										IF length MOD stepValue = 0 THEN
											length := length DIV stepValue
										ELSE
											length := length DIV stepValue + 1
										END
									END;
									targetArray.SetLength(Global.NewIntegerValue(system, position, length));
									targetArray.SetIncrement(sourceArray.staticIncrementInBits * stepValue);
									ASSERT(targetArray.form = SyntaxTree.Static)
								END
							END
						END
						*)
					END;

					SetIndexBaseType(indexDesignator, targetArray)
				END;

				indexDesignator.parameters.AddExpression(indexListItem)

			ELSE
				Error(position,"invalid index list item");
			END;
		END AppendMathIndex;

		PROCEDURE AppendIndex(position: Position; index: SyntaxTree.IndexDesignator; expression: SyntaxTree.Expression; over: SyntaxTree.Type);
		VAR  parameters: SyntaxTree.ExpressionList;
		BEGIN
			parameters := index.parameters;
			IF (expression.type = NIL) THEN
				Error(position, "invalid index");
			ELSIF IsIntegerType(expression.type.resolved) THEN
				IF over IS SyntaxTree.ArrayType THEN
					IndexCheck(expression,over(SyntaxTree.ArrayType).length);
				ELSIF over IS SyntaxTree.StringType THEN
					IndexCheck(expression,Global.NewIntegerValue(system, position, over(SyntaxTree.StringType).length));
				END;
				expression := NewConversion(Basic.invalidPosition,expression,system.sizeType,NIL);
				parameters.AddExpression(expression);
			ELSE
				Error(position, "invalid index");
			END;
		END AppendIndex;

		PROCEDURE NewObjectOperatorCall*(position: Position; left: SyntaxTree.Expression; oper: LONGINT; parameters: SyntaxTree.ExpressionList; rhs: SyntaxTree.Expression): SyntaxTree.Designator;
		VAR type: SyntaxTree.Type; expression: SyntaxTree.Expression; op: SyntaxTree.Operator; recordType: SyntaxTree.RecordType;
			actualParameters: SyntaxTree.ExpressionList; i: LONGINT; result: SyntaxTree.Designator;
			pointer: BOOLEAN; designator: SyntaxTree.Designator;

			PROCEDURE FindOperator(recordType: SyntaxTree.RecordType; identifier: SyntaxTree.Identifier; actualParameters: SyntaxTree.ExpressionList): SyntaxTree.Operator;
			VAR bestOperator: SyntaxTree.Operator; bestDistance: LONGINT; numberParameters: LONGINT; procedureType: SyntaxTree.ProcedureType;

				PROCEDURE FindInScope(scope: SyntaxTree.RecordScope; access: SET);
				VAR operator: SyntaxTree.Operator; distance,i: LONGINT;
				CONST trace = FALSE;
				BEGIN
					IF trace THEN
						FOR i := 0 TO actualParameters.Length()-1 DO
							Printout.Info("par", actualParameters.GetExpression(i));
						END;
					END;
					operator := scope.firstOperator;
					WHILE(operator # NIL) DO
						IF (operator.name=identifier) & (operator.access * access # {}) THEN
							procedureType := operator.type(SyntaxTree.ProcedureType);
							distance := Distance(system, procedureType,actualParameters);
							IF trace THEN Printout.Info("check op ",operator) END;
							IF distance < bestDistance THEN
								IF trace THEN Printout.Info("taken op",operator) END;
								bestDistance := distance;
								bestOperator := operator;
							END;
						END;
						operator := operator.nextOperator;
					END;
				END FindInScope;

			BEGIN
				bestDistance := Infinity; bestOperator := NIL; numberParameters := actualParameters.Length();
				IF oper = 0 THEN  (* index *)
					identifier := SyntaxTree.NewIdentifier("[]");
				ELSE
					identifier := Global.GetIdentifier(oper,currentScope.ownerModule.case);
				END;

				WHILE (recordType # NIL) DO
					FindInScope(recordType.recordScope,SyntaxTree.ReadOnly);
					recordType := recordType.GetBaseRecord();
				END;
				RETURN bestOperator
			END FindOperator;
		BEGIN
			type := left.type.resolved;
			IF type IS SyntaxTree.RecordType THEN
				pointer := FALSE;
				recordType := type(SyntaxTree.RecordType);
			ELSE
				pointer := TRUE;
				IF ~(type IS SyntaxTree.PointerType) THEN RETURN NIL END;
				recordType := type(SyntaxTree.PointerType).pointerBase.resolved(SyntaxTree.RecordType);
			END;

			actualParameters := SyntaxTree.NewExpressionList();
			IF parameters # NIL THEN
				FOR i := 0 TO parameters.Length()-1 DO
					expression := ResolveExpression(parameters.GetExpression(i));
					actualParameters.AddExpression(expression);
				END;
			END;
			IF rhs # NIL THEN actualParameters.AddExpression(rhs) END;

			op := FindOperator(recordType, SyntaxTree.NewIdentifier("[]"), actualParameters);
			IF op # NIL THEN
				designator := left(SyntaxTree.Designator);
				IF pointer THEN designator := NewDereferenceDesignator(Basic.invalidPosition, designator,designator) END;
				expression := NewSymbolDesignator(position, NIL, designator ,op);
				ASSERT(expression IS SyntaxTree.Designator);
				result := NewProcedureCallDesignator(position, NIL, expression(SyntaxTree.Designator), actualParameters);

				(* check if write operator exists, for var parameters *)
				IF (rhs = NIL) & (op.type(SyntaxTree.ProcedureType).returnType # NIL) THEN
					actualParameters := SyntaxTree.NewExpressionList();
					FOR i := 0 TO parameters.Length()-1 DO
						expression := ResolveExpression(parameters.GetExpression(i));
						actualParameters.AddExpression(expression);
					END;
					rhs := SyntaxTree.NewDesignator(); rhs.SetType(op.type(SyntaxTree.ProcedureType).returnType); (* only a stub to test for existence of operator *)
					actualParameters.AddExpression(rhs);
					op := FindOperator(recordType, SyntaxTree.NewIdentifier("[]"), actualParameters);
					IF op = NIL THEN rhs := NIL END;
				END;

				IF rhs # NIL THEN result.SetAssignable(TRUE) END;
			ELSE
				result := NIL;
			END;
			RETURN result;
		END NewObjectOperatorCall;

		(** check and semantically resolve a bracket designator of the form 'left[expression, ..., expression]'
			1. convert bracket designator chains into a single one that contains separators
				e.g.: left[a, b, c][d, e][f] -> left[a, b, c, |, d, e, |, f]

			2. convert single bracket designator into a chain of index- , dereference- and procedure call designators
				e.g.: left[a, b, c, |, d, e, |, f] -> left^[a]^."[]"(b, c, d)[e, f]

				- if an array or math array is indexed over, create index designator
					a[x, |, y] -> a[x][y] (split at separator if 'x' contains range or 'a' is tensor math array)
					a[x, |, y] -> a[x, y] (otherwise, combine into single one)

				- if a pointer is indexed over, splitting and auto-dereferencing takes place:
					a[x, y] -> a[x]^[y] (a: ARRAY OF POINTER TO ARRAY OF INTEGER)

				- if an array-structured object type is indexed over, create procedure call designator
					e.g.: a[x, y] -> a^."[]"(x, y)

			Note 1: for math arrays, there can be a difference between a[x, y] and [y, x]:
				- a[i, *] = a[i][*]
				- a[*, i] # a[*][i]

				Because:
				- 'i-th row' = a[*][i] = a[*][i, *] = a[i, *] = a[i] = a[i][*] = a[i][*][*] = a[i][*][*][*]
				- 'i-th column' = a[*, i]

			Note 2: math arrays of arrays (and vice versa) are forbidden by the type system.
			However, pointers are permitted: e.g. ARRAY [10] OF POINTER TO ARRAY is a valid type.

			Note 3: while this compiler tries to combine multiple bracket designators into a single index designator,
			older Oberon compilers did this the other way around: a[x, y, z] -> A[x][y][z].
		**)
		PROCEDURE ResolveBracketDesignator(bracketDesignator: SyntaxTree.BracketDesignator): SyntaxTree.Expression;
		VAR
			leftBracketDesignator: SyntaxTree.BracketDesignator;
			indexDesignator: SyntaxTree.IndexDesignator;
			designator: SyntaxTree.Designator;
			type: SyntaxTree.Type;
			expression: SyntaxTree.Expression;
			i: LONGINT;
			result: SyntaxTree.Expression;

			PROCEDURE FinalizeIndexDesignator;
			BEGIN
				IF indexDesignator # NIL THEN
					(* the end of a tensor has been reached: *)
					IF IsTensor(type) THEN type := type(SyntaxTree.MathArrayType).arrayBase.resolved END;
					SetIndexBaseType(indexDesignator, type);
					indexDesignator.SetType(ResolveType(indexDesignator.type));
					designator := indexDesignator;
					type := designator.type.resolved;
					indexDesignator := NIL;
					ASSERT(SyntaxTree.Resolved IN type.state)
				END
			END FinalizeIndexDesignator;

		BEGIN
			IF Trace THEN D.Str("ResolveBracketDesignator"); D.Ln; END;

			IF bracketDesignator.left IS SyntaxTree.BracketDesignator THEN
				leftBracketDesignator := bracketDesignator.left(SyntaxTree.BracketDesignator);
				(* copy all index list entries including a separator to the left bracket designator *)
				leftBracketDesignator.parameters.AddExpression(SyntaxTree.indexListSeparator);
				FOR i := 0 TO bracketDesignator.parameters.Length() - 1 DO
					leftBracketDesignator.parameters.AddExpression(bracketDesignator.parameters.GetExpression(i))
				END;
				(* only resolve left bracket designator and use as final result *)
				bracketDesignator.SetRelatedRhs(leftBracketDesignator.relatedRhs);
				result := ResolveExpression(leftBracketDesignator)

			ELSE
				ASSERT(~(bracketDesignator.left IS SyntaxTree.BracketDesignator));

				designator := ResolveDesignator(bracketDesignator.left);
				type := designator.type.resolved;
				indexDesignator := NIL;

				(*!!! clean up *)
				IF (type IS SyntaxTree.PointerType) & (type(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.RecordType)
					OR (type IS SyntaxTree.RecordType)
				THEN
					result := NewObjectOperatorCall(bracketDesignator.position, designator, 0, bracketDesignator.parameters,bracketDesignator.relatedRhs);
					IF result = NIL THEN
						Error(bracketDesignator.position,"undefined operator");
						result := SyntaxTree.invalidDesignator
					END;
					RETURN result;
				END;

				i := 0;
				WHILE i <= bracketDesignator.parameters.Length() - 1 DO
					expression := bracketDesignator.parameters.GetExpression(i);
					expression := ResolveExpression(expression);
					bracketDesignator.parameters.SetExpression(i, expression);

					IF expression = SyntaxTree.indexListSeparator THEN
						(* finalize an existing index designator if needed *)
						IF IsTensor(type) OR (indexDesignator # NIL) & (indexDesignator.hasRange) THEN FinalizeIndexDesignator END;
						INC(i)

					ELSE
						(* do auto-dereferencing if needed *)
						IF (type IS SyntaxTree.PointerType)
						THEN
							(* expression of the form A[x,...] over ARRAY [...] OF POINTER TO ARRAY OF ... *)
							IF (indexDesignator # NIL) & indexDesignator.hasRange THEN
								Error(expression.position, "forbidden range valued indexer over pointer to array");
								designator := SyntaxTree.invalidDesignator;
								type := SyntaxTree.invalidType
							ELSE
								FinalizeIndexDesignator;
								designator := NewDereferenceDesignator(bracketDesignator.position, designator, designator);
								type := designator.type.resolved
							END
						END;

						(* create a new index designator, if needed *)
						IF (indexDesignator = NIL) & ((type IS SyntaxTree.ArrayType) OR (type IS SyntaxTree.MathArrayType) OR (type IS SyntaxTree.StringType)) THEN
							indexDesignator := SyntaxTree.NewIndexDesignator(bracketDesignator.position, bracketDesignator, designator, SyntaxTree.NewExpressionList());
							indexDesignator.SetAssignable(designator.assignable);
							indexDesignator.SetType(NIL); (* type will be re-set when index designator is finalized *)
							(* designator := indexDesignator *)
						END;

						IF type = SyntaxTree.invalidType THEN
							(* error already handled *)
							INC(i)

						ELSIF type IS SyntaxTree.ArrayType THEN
							(* indexing over an array *)
							ASSERT(indexDesignator # NIL);
							AppendIndex(expression.position, indexDesignator, expression, type(SyntaxTree.ArrayType));
							type := type(SyntaxTree.ArrayType).arrayBase.resolved;
							INC(i)
						ELSIF type IS SyntaxTree.StringType THEN
							(* indexing over an array *)
							ASSERT(indexDesignator # NIL);
							AppendIndex(expression.position, indexDesignator, expression, type);
							type := type(SyntaxTree.StringType).baseType.resolved;
							INC(i)

						ELSIF type IS SyntaxTree.MathArrayType THEN
							(* indexing over a math array *)

							ASSERT(indexDesignator # NIL);
							AppendMathIndex(expression.position, indexDesignator, expression, type(SyntaxTree.MathArrayType));
							IF type(SyntaxTree.MathArrayType).form # SyntaxTree.Tensor THEN type := type(SyntaxTree.MathArrayType).arrayBase.resolved END;
							INC(i)
						ELSE
							Error(expression.position,"indexing over non-array type");
							designator := SyntaxTree.invalidDesignator;
							type := SyntaxTree.invalidType;
							INC(i)
						END
					END
				END;

				IF type # SyntaxTree.invalidType THEN FinalizeIndexDesignator END;
				result := designator
			END;
			RETURN result;
		END ResolveBracketDesignator;

		(** check and resolve expression list
			- resolve each expression in an expression list
			- returns true if and only if all statements could have successfully been resolved
		**)
		PROCEDURE ExpressionList(expressionList: SyntaxTree.ExpressionList): BOOLEAN;
		VAR i: LONGINT; expression: SyntaxTree.Expression; result: BOOLEAN;
		BEGIN
			result := TRUE;
			FOR i := 0 TO expressionList.Length()-1 DO
				expression := ResolveExpression(expressionList.GetExpression(i));
				IF expression = SyntaxTree.invalidExpression THEN result := FALSE END;
				expressionList.SetExpression(i,expression);
			END;
			RETURN result
		END ExpressionList;


(*
		PROCEDURE ReplaceExpressions(x: SyntaxTree.ExpressionList; oScope, outer, rScope: SyntaxTree.Scope);
		VAR i: LONGINT;
		BEGIN
				IF x # NIL THEN
					FOR i := 0 TO x.Length()-1 DO
						ReplaceExpression(x.GetExpression(i),oScope,outer,rScope);
					END;
				END;
		END ReplaceExpressions;


		PROCEDURE ReplaceExpression(x: SyntaxTree.Expression; oScope, outer, rScope: SyntaxTree.Scope);
		VAR find: SyntaxTree.Symbol; name: ARRAY 32 OF CHAR;
		BEGIN
			IF x = NIL THEN RETURN END;
			WITH
				x: SyntaxTree.ResultDesignator DO ReplaceExpression(x.left,oScope,outer,rScope);
			| SyntaxTree.SelfDesignator DO ReplaceExpression(x.left,oScope,outer,rScope);
			| SyntaxTree.SupercallDesignator DO ReplaceExpression(x.left,oScope,outer,rScope);
			| SyntaxTree.DereferenceDesignator DO ReplaceExpression(x.left,oScope,outer,rScope);
			| SyntaxTree.TypeGuardDesignator DO ReplaceExpression(x.left,oScope,outer,rScope);
			| SyntaxTree.BuiltinCallDesignator DO
				ReplaceExpression(x.left,oScope,outer,rScope);
				ReplaceExpressions(x.parameters,oScope,outer,rScope);
			| SyntaxTree.StatementDesignator DO
				ReplaceStatement(x.statement,oScope,outer,rScope);
				ReplaceExpression(x.result,oScope,outer,rScope);
			| SyntaxTree.ProcedureCallDesignator DO
				ReplaceExpression(x.left,oScope,outer,rScope);
				ReplaceExpressions(x.parameters,oScope,outer,rScope);
			| SyntaxTree.InlineCallDesignator DO
(*				IF x.initializers.Length()>0 THEN
				Printout.Info("oScope", oScope);
				Printout.Info("outer",outer);
				Printout.Info("rScope",rScope);
				END;
			*)
				ReplaceStatement(x.block,oScope,outer,rScope);
			| SyntaxTree.IndexDesignator DO
				ReplaceExpression(x.left,oScope,outer,rScope);
				ReplaceExpressions(x.parameters,oScope,outer,rScope);
			| SyntaxTree.SymbolDesignator DO
					x.symbol.GetName(name);
					TRACE("a symbol designator with ", name);
					IF x.symbol.scope = oScope THEN
						find := rScope.FindSymbol(x.symbol.name);
						IF find # NIL THEN
							x.symbol.GetName(name);
							TRACE(name);
							x.SetSymbol(find);
							ASSERT(x.symbol.scope = rScope);
						END;
					END;
					ReplaceExpression(x.left,oScope,outer,rScope);
			| SyntaxTree.BracketDesignator DO HALT(100)
			| SyntaxTree.ArrowDesignator DO HALT(100)
			| SyntaxTree.ParameterDesignator DO HALT(100)
			| SyntaxTree.SelectorDesignator DO HALT(100)
			| SyntaxTree.IdentifierDesignator DO HALT(100)
			| SyntaxTree.Conversion DO
				ReplaceExpression(x.expression,oScope,outer,rScope);
			| SyntaxTree.TensorRangeExpression DO
			| SyntaxTree.RangeExpression DO
				ReplaceExpression(x.first,oScope,outer,rScope);
				ReplaceExpression(x.last,oScope,outer,rScope);
				ReplaceExpression(x.step,oScope,outer,rScope);
			| SyntaxTree.BinaryExpression DO
				ReplaceExpression(x.left,oScope,outer,rScope);
				ReplaceExpression(x.right,oScope,outer,rScope);
			| SyntaxTree.UnaryExpression DO
				ReplaceExpression(x.left,oScope,outer,rScope);
			| SyntaxTree.MathArrayExpression DO
				ReplaceExpressions(x.elements,oScope,outer,rScope);
			| SyntaxTree.Set DO
				ReplaceExpressions(x.elements,oScope,outer,rScope);
			END;
		END ReplaceExpression;

		PROCEDURE ReplaceIfPart(x: SyntaxTree.IfPart; oScope, outer, rScope: SyntaxTree.Scope);
		BEGIN
				ReplaceExpression(x.condition,oScope,outer,rScope);
				ReplaceStatements(x.statements,oScope,outer,rScope);
		END ReplaceIfPart;

		PROCEDURE ReplaceStatement(x: SyntaxTree.Statement; oScope, outer, rScope: SyntaxTree.Scope);
		VAR i: LONGINT;
		BEGIN
			WITH x:
			SyntaxTree.ProcedureCallStatement DO
				ReplaceExpression(x.call,oScope,outer,rScope);
			| SyntaxTree.Assignment DO
				ReplaceExpression(x.left,oScope,outer,rScope);
				ReplaceExpression(x.right,oScope,outer,rScope);
			| SyntaxTree.CommunicationStatement DO
					ReplaceExpression(x.left,oScope,outer,rScope);
					ReplaceExpression(x.right,oScope,outer,rScope);
			| SyntaxTree.IfStatement DO
					ReplaceIfPart(x.ifPart,oScope,outer,rScope);
					FOR i := 0 TO x.ElsifParts()-1 DO
						ReplaceIfPart(x.GetElsifPart(i),oScope,outer,rScope);
					END;
					IF x.elsePart # NIL THEN
						ReplaceStatements(x.elsePart,oScope,outer,rScope);
					END;
			| SyntaxTree.WithStatement DO
					ReplaceExpression(x.variable,oScope,outer,rScope);
					FOR i := 0 TO x.WithParts()-1 DO
						ReplaceStatements(x.GetWithPart(i).statements,oScope,outer,rScope);
					END;
					IF x.elsePart # NIL THEN
						ReplaceStatements(x.elsePart,oScope,outer,rScope);
					END;
			| SyntaxTree.CaseStatement DO
					ReplaceExpression(x.variable,oScope,outer,rScope);
					FOR i := 0 TO x.CaseParts()-1 DO
						ReplaceStatements(x.GetCasePart(i).statements,oScope,outer,rScope);
					END;
					IF x.elsePart # NIL THEN
						ReplaceStatements(x.elsePart,oScope,outer,rScope);
					END;
			| SyntaxTree.WhileStatement DO
				ReplaceExpression(x.condition,oScope,outer,rScope);
				ReplaceStatements(x.statements,oScope,outer,rScope);
			| SyntaxTree.RepeatStatement DO
				ReplaceExpression(x.condition,oScope,outer,rScope);
				ReplaceStatements(x.statements,oScope,outer,rScope);
			| SyntaxTree.ForStatement DO
				ReplaceExpression(x.variable,oScope,outer,rScope);
				ReplaceExpression(x.from,oScope,outer,rScope);
				ReplaceExpression(x.to,oScope,outer,rScope);
				ReplaceExpression(x.by,oScope,outer,rScope);
				ReplaceStatements(x.statements,oScope,outer,rScope);
			| SyntaxTree.LoopStatement DO
				ReplaceStatements(x.statements,oScope,outer,rScope);
			| SyntaxTree.ExitStatement DO
			| SyntaxTree.ReturnStatement DO
				ReplaceExpression(x.returnValue,oScope,outer,rScope);
			| SyntaxTree.AwaitStatement DO
				ReplaceExpression(x.condition,oScope,outer,rScope);
			| SyntaxTree.StatementBlock DO
				x.scope.SetOuter(outer);
				Printout.Info("outer",outer);
				Printout.Info("x.scope",x.scope);
				ReplaceStatements(x.statements,oScope,x.scope,rScope);
			END;
		END ReplaceStatement;

		PROCEDURE ReplaceStatements(statements: SyntaxTree.StatementSequence; oScope,outer,rScope: SyntaxTree.Scope);
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO statements.Length()-1 DO
				ReplaceStatement(statements.GetStatement(i),oScope,outer,rScope);
			END;
		END ReplaceStatements;
*)

		(** return procedure call designator left(actualParameters)
			- check realtime procedure call in realtime procedure
			- check number of parameters
			- check parameter compatibility
			return invalidDesignator if error
		**)
		PROCEDURE NewProcedureCallDesignator(position: Position; original: SyntaxTree.Expression; left: SyntaxTree.Expression; actualParameters:SyntaxTree.ExpressionList): SyntaxTree.Designator;
		VAR result: SyntaxTree.Designator;
			numberFormalParameters, numberActualParameters: LONGINT;
			formalType: SyntaxTree.ProcedureType;
			formalParameter: SyntaxTree.Parameter;
			actualParameter: SyntaxTree.Expression;
			i: LONGINT;
			self: SyntaxTree.Expression;
			inlineScope: SyntaxTree.Scope; procedureType: SyntaxTree.ProcedureType;
			tooComplex : BOOLEAN;
			duplicate: BOOLEAN;
			procedure: SyntaxTree.Procedure;
			block: SyntaxTree.StatementBlock;
			returnType: SyntaxTree.Type;
			const, cclone: SyntaxTree.Constant;
			var, clone: SyntaxTree.Variable;
			alias: SyntaxTree.Alias;
			name: ARRAY 32 OF CHAR;
			resolved: SyntaxTree.Statement;
			previousResultType: SyntaxTree.Type;
			symbols: SyntaxTree.Symbols;
		BEGIN
			IF Trace THEN D.Str("ProcedureCallDesignator"); D.Ln; END;
			result := SyntaxTree.invalidDesignator;
			formalType := left.type.resolved(SyntaxTree.ProcedureType); (* type checked in VisitParameterDesignator *)
			numberFormalParameters := formalType.numberParameters;
			numberActualParameters := actualParameters.Length();

			IF (currentIsRealtime) & ~(formalType.isRealtime) THEN
				Error(position, "forbidden call of non-realtime procedure in realtime block");
			END;

			IF (formalType.selfParameter # NIL) & (formalType.selfParameter.kind = SyntaxTree.VarParameter) THEN
				self := left(SyntaxTree.Designator).left;
				IF (self # NIL) & ~IsVariable(self) THEN
					Error(self.position, "Non-variable expression on variable receiver");
				END;
			END;

			IF ~ExpressionList(actualParameters) THEN
				result := SyntaxTree.invalidDesignator
			ELSE
				IF numberActualParameters <= numberFormalParameters THEN
					formalParameter := formalType.firstParameter;
					FOR i := 0 TO numberActualParameters-1 DO
						actualParameter := actualParameters.GetExpression(i);
						IF (actualParameter = SyntaxTree.invalidExpression) THEN
						ELSIF ~ParameterCompatible(formalParameter,actualParameter) THEN
						ELSIF (currentIsRealtime) & ~actualParameter.type.resolved.isRealtime THEN
							Error(position, "non-realtime actual parameter in context of realtime procedure");
						ELSE
							IF ~formalParameter.type.SameType(actualParameter.type.resolved) THEN
								actualParameter := NewConversion(actualParameter.position,actualParameter,formalParameter.type,NIL);
							END;
							actualParameters.SetExpression(i,actualParameter);
						END;
						formalParameter := formalParameter.nextParameter;
					END;
					WHILE (formalParameter # NIL) DO
						IF formalParameter.defaultValue # NIL THEN
							actualParameters.AddExpression(formalParameter.defaultValue);
							formalParameter := formalParameter.nextParameter
						ELSE
							Error(position, "less actual than formal parameters");
							formalParameter := NIL;
						END;
					END;
				ELSE
					Error(position, "more actual than formal parameters")
				END;

				result := SyntaxTree.NewProcedureCallDesignator(position,original,left,actualParameters);
				result.SetAssignable(FALSE);
				result.SetType(left.type.resolved(SyntaxTree.ProcedureType).returnType);
			END;

			IF result = SyntaxTree.invalidDesignator THEN
			ELSIF (left IS SyntaxTree.SymbolDesignator) & (left(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Procedure) THEN
				procedure := left(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Procedure);
			END;

			IF InliningSupport & (procedure # NIL) & IsOberonInline(procedure) THEN
				procedure.GetName(name);
				inlineScope := SyntaxTree.NewBlockScope(currentScope);
 				currentScope := inlineScope;

				procedureType := procedure.type(SyntaxTree.ProcedureType);

				formalParameter := procedureType.firstParameter;
				(* we need a copy of the original parsed expression list here -- may contain inline calls *)
				actualParameters := SyntaxTree.CloneExpressionList(result(SyntaxTree.ProcedureCallDesignator).parameters);

				NEW(symbols);
				tooComplex := FALSE;
				i := 0;
				WHILE (i < actualParameters.Length()) & ~tooComplex DO
					actualParameter := ResolveExpression(actualParameters.GetExpression(i));
					formalParameter.GetName(name);
					IF actualParameter.resolved # NIL THEN
						actualParameter := actualParameter.resolved
					END;
					IF (formalParameter.kind IN {SyntaxTree.ConstParameter, SyntaxTree.VarParameter})
						(* & (actualParameter.resolved # NIL)  & (actualParameter.resolved IS SyntaxTree.Value)  *)
						& SideEffectFree(actualParameter)  THEN
						IF (actualParameter.resolved # NIL) & (actualParameter.resolved IS SyntaxTree.Value) THEN
							const := SyntaxTree.NewConstant(actualParameter.position,formalParameter.name);
							const.SetValue(actualParameter);
							const.SetType(formalParameter.type);
							inlineScope.AddConstant(const);
							symbols.Add(const);
						ELSE
							alias := SyntaxTree.NewAlias(actualParameter.position, formalParameter.name, actualParameter);
							alias.SetType(formalParameter.type);
							inlineScope.AddAlias(alias);
							symbols.Add(alias);
						END;
					ELSE
						var := SyntaxTree.NewVariable(actualParameter.position, formalParameter.name);
						var.SetKind(formalParameter.kind);
						var.PreferRegister(formalParameter.preferRegister);
						(* copy expression to var *)
						var.SetType(formalParameter.type);
						var.SetInitializer(actualParameter);
						inlineScope.AddVariable(var);
						symbols.Add(var);
					END;
					formalParameter := formalParameter.nextParameter;
					INC(i);
				END;

				(* in order to avoid name clashes with parameter names, we do this late *)
				(* remark: setting currentScope := inlineScope here does not work because
				parameters may themselves be inline expressions *)
				FOR i := 0 TO symbols.Length()-1 DO
					inlineScope.EnterSymbol(symbols.Get(i), duplicate);
				END;

 				var := procedure.procedureScope.firstVariable;
 				WHILE (var # NIL) DO
 					clone := var.Clone();
 					inlineScope.AddVariable(clone);
 					inlineScope.EnterSymbol(clone, duplicate);
 					var := var.nextVariable;
 				END;

 				const := procedure.procedureScope.firstConstant;
 				WHILE (const # NIL) DO
 					cclone := const.Clone();
 					inlineScope.AddConstant(cclone);
 					inlineScope.EnterSymbol(cclone, duplicate);
 					const := const.nextConstant;
 				END;
				IF procedure.Resolving(TRUE) THEN
					Warning(position,"inline recursion");
					RETURN result; (* normal procedure call *)
				END;

				previousResultType := currentResultType;
				currentResultType := procedureType.returnType;
 				ASSERT(system.GenerateVariableOffsets(inlineScope));

				block := SyntaxTree.NewStatementBlock(result.position, NIL, inlineScope);
				block.SetStatementSequence(SyntaxTree.CloneStatementSequence(procedure.procedureScope.body.statements));
				resolved := ResolveStatement(block);
				returnType := result.type;
				result := SyntaxTree.NewInlineCallDesignator(result.position, original, block);
				result.SetType(returnType);
				currentScope := inlineScope.outerScope;
 				currentScope.AddScope(inlineScope);
 				currentResultType := previousResultType;
				IF ~procedure.Resolving(FALSE) THEN (*HALT(100) *) END;
			END;

			RETURN result
		END NewProcedureCallDesignator;

		(**
			builtin call designator generated in ResolveParameterDesignator
			-> nothing to be resolved
		**)
		PROCEDURE ResolveBuiltinCallDesignator(x: SyntaxTree.BuiltinCallDesignator): SyntaxTree.Expression;
		BEGIN
			IF (x.returnType # NIL) & ExpressionList(x.parameters) THEN
				RETURN NewBuiltinCallDesignator(x.position,NIL, NIL, x.parameters,NIL, ResolveType(x.returnType));
			ELSIF ExpressionList(x.parameters) THEN
				RETURN x;
			END;
		END ResolveBuiltinCallDesignator;

		(** return true if x is a variable else return false and report error **)
		PROCEDURE CheckVariable(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := TRUE;
			IF x = SyntaxTree.invalidExpression THEN
				result := FALSE;
			ELSIF ~IsVariable(x) THEN
				Error(x.position,"non variable expression");
				IF VerboseErrorMessage THEN Printout.Info("non variable",x) END;
				result := FALSE;
			END;
			RETURN result
		END CheckVariable;

		(**
			if expression x is of basic type then return true else report error and return false
		**)
		PROCEDURE CheckBasicType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF ~IsBasicType(x.type) THEN
				Error(x.position,"is no basic type");
				result := FALSE
			ELSE result := TRUE
			END;
			RETURN result
		END CheckBasicType;

		(**
			if expression x is of number type then return true else report error and return false
		**)
		PROCEDURE CheckNumberType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF ~(x.type.resolved IS SyntaxTree.NumberType) THEN
				Error(x.position,"is non number type");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckNumberType;

		(**
			if expression x is of number or size type but not complex then return true else report error and return false
		**)
		PROCEDURE CheckNonComplexNumberSizeType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF x.type.resolved IS SyntaxTree.ComplexType THEN
				Error(x.position,"is complex type");
			ELSIF ~(x.type.resolved IS SyntaxTree.NumberType) & ~(x.type.resolved IS SyntaxTree.SizeType) THEN
				Error(x.position,"is non number type");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckNonComplexNumberSizeType;

		PROCEDURE CheckAddressType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN; type: SyntaxTree.Type;
		BEGIN
			result := FALSE; type := x.type.resolved;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF  ~(type IS SyntaxTree.AddressType) & ~(type IS SyntaxTree.NilType) & ~(type IS SyntaxTree.SizeType) & ~( (type IS SyntaxTree.IntegerType) & (type.sizeInBits <= system.addressType.sizeInBits)) & ~IsAddressValue(x) & ~IsUnsafePointer(type) THEN
				Error(x.position,"is no address type");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckAddressType;

		PROCEDURE CheckSizeType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN; type: SyntaxTree.Type;
		BEGIN
			result := FALSE; type := x.type.resolved;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF   ~(type IS SyntaxTree.SizeType) & ~( (type IS SyntaxTree.IntegerType) & (type.sizeInBits <= system.sizeType.sizeInBits)) THEN
				Error(x.position,"is no size type");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckSizeType;

		PROCEDURE CheckObjectType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN; type: SyntaxTree.Type;
		BEGIN
			result := FALSE; type := x.type.resolved;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF ~(type IS SyntaxTree.NilType) & ~(type IS SyntaxTree.ObjectType) & (~(type IS SyntaxTree.PointerType) OR ~(type(SyntaxTree.PointerType).pointerBase IS SyntaxTree.RecordType) OR ~type(SyntaxTree.PointerType).pointerBase(SyntaxTree.RecordType).isObject) THEN
				Error(x.position,"is no object type");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckObjectType;

		(**
			if expression x is of integer type then return true else report error and return false
		**)
		PROCEDURE CheckIntegerType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN; type: SyntaxTree.Type;
		BEGIN
			result := FALSE; type := x.type.resolved;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF ~(type IS SyntaxTree.IntegerType) & ~(type IS SyntaxTree.ByteType) & ~(type IS SyntaxTree.AddressType) & ~(type IS SyntaxTree.SizeType) THEN
				Error(x.position,"is no integer type");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckIntegerType;

		(**
			if expression x is of character type then return true else report error and return false
		**)
		PROCEDURE CheckCharacterType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF ~(x.type.resolved IS SyntaxTree.CharacterType) & ~(x.type.resolved IS SyntaxTree.ByteType) & ~IsCharacterType(x.type.resolved) THEN
				Error(x.position,"is no character type");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckCharacterType;

		(**
			if expression x is of real type then return true else report error and return false
		**)
		PROCEDURE CheckRealType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF ~(x.type.resolved IS SyntaxTree.FloatType) THEN
				Error(x.position,"is no float type");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckRealType;

		(**
			if expression x is of range type then return true else report error and return false
		**)
		PROCEDURE CheckRangeType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF ~(x.type.resolved IS SyntaxTree.RangeType) THEN
				Error(x.position,"is no range type");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckRangeType;

		(**
			if expression x is of boolean type then return true else report error and return false
		**)
		PROCEDURE CheckBooleanType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF ~(x.type.resolved IS SyntaxTree.BooleanType) THEN
				Error(x.position,"is no boolean type");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckBooleanType;

		(**
			if expression x is of set type then return true else report error and return false
		**)
		PROCEDURE CheckSetType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF ~(x.type.resolved IS SyntaxTree.SetType) THEN
				Error(x.position,"is no set type");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckSetType;

		(**
			if expression x is of string or array of character type then return true else report error and return false
		**)
		PROCEDURE CheckStringType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF ~IsStringType(x.type.resolved) THEN
				Error(x.position,"is no string type");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckStringType;

		(**
			if expression x is a type declaration type return true else report error and return false
		**)
		PROCEDURE CheckTypeDeclarationType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF (x.type.resolved # SyntaxTree.typeDeclarationType) THEN
				Error(x.position,"is not a type declaration");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckTypeDeclarationType;

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

		PROCEDURE CheckStringValue(x: SyntaxTree.Expression; VAR value: ARRAY OF CHAR): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF (x.resolved # NIL) & (x.resolved IS SyntaxTree.StringValue) THEN
				result := TRUE;
				COPY(x.resolved(SyntaxTree.StringValue).value^, value);
			ELSE
				Error(x.position,"expression is not an integer constant");
			END;
			RETURN result;
		END CheckStringValue;

		PROCEDURE IsUnsignedValue(x: SyntaxTree.Expression; maxSizeInBits: LONGINT): BOOLEAN;
		BEGIN
			IF (x.resolved # NIL) & (x.resolved IS SyntaxTree.IntegerValue) THEN
				RETURN Global.IsUnsignedInteger(x.resolved(SyntaxTree.IntegerValue).value, maxSizeInBits)
			ELSE
				RETURN FALSE
			END;
		END IsUnsignedValue;

		PROCEDURE IsAddressValue(x: SyntaxTree.Expression): BOOLEAN;
		BEGIN
			IF (x.resolved # NIL) & (x.resolved IS SyntaxTree.IntegerValue) THEN
				RETURN Global.IsUnsignedInteger(x.resolved(SyntaxTree.IntegerValue).value, system.addressType.sizeInBits)
			ELSE
				RETURN FALSE
			END
		END IsAddressValue;

		PROCEDURE IsAddressExpression(x: SyntaxTree.Expression): BOOLEAN;
		BEGIN
			RETURN IsAddressType(x.type.resolved, system.addressSize) OR  IsAddressValue(x)
		END IsAddressExpression;

		PROCEDURE IsSizeExpression(x: SyntaxTree.Expression): BOOLEAN;
		BEGIN
			RETURN IsSizeType(x.type.resolved, system.addressSize) OR IsAddressValue(x)
		END IsSizeExpression;

		PROCEDURE CheckEnumerationValue(x: SyntaxTree.Expression; VAR value: Basic.Integer): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF (x.resolved # NIL) & (x.resolved IS SyntaxTree.EnumerationValue) THEN
				result := TRUE;
				value := x.resolved(SyntaxTree.EnumerationValue).value;
			ELSE
				Error(x.position,"expression is not an integer constant");
			END;
			RETURN result;
		END CheckEnumerationValue;

		PROCEDURE CheckCharacterValue(x: SyntaxTree.Expression; VAR value: CHAR): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF (x.resolved # NIL) & (x.resolved IS SyntaxTree.CharacterValue) THEN
				result := TRUE;
				value := x.resolved(SyntaxTree.CharacterValue).value;
			ELSIF (x.resolved # NIL) & (x.resolved IS SyntaxTree.StringValue) & (x.resolved(SyntaxTree.StringValue).length =2) THEN
				result := TRUE;
				value := x.resolved(SyntaxTree.StringValue).value[0];
			ELSE
				Error(x.position,"expression is not a character constant");
			END;
			RETURN result;
		END CheckCharacterValue;

		PROCEDURE CheckPositiveIntegerValue(x: SyntaxTree.Expression; VAR value: Basic.Integer; includeZero: BOOLEAN): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF (x.resolved # NIL) & (x.resolved IS SyntaxTree.IntegerValue) THEN
				value := x.resolved(SyntaxTree.IntegerValue).value;
				IF (value > 0) OR includeZero & (value = 0)  THEN
					result := TRUE;
				ELSE
					Error(x.position,"integer is not positive");
				END
			ELSE
				Error(x.position,"expression is not an integer constant");
			END;
			RETURN result;
		END CheckPositiveIntegerValue;

		PROCEDURE CheckPortType(x: SyntaxTree.Expression; VAR portType: SyntaxTree.PortType): BOOLEAN;
		VAR type: SyntaxTree.Type; result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSE
				type := x.type.resolved;
				IF (type # NIL) & (type IS SyntaxTree.PortType) THEN
					portType := type(SyntaxTree.PortType);
					result := TRUE
				ELSE
					Error(x.position,"no port type");
				END;
			END;
			RETURN result
		END CheckPortType;

				(* move to builtin procedure call statement ?
			remove builtin procedure call designator ?
		*)
		PROCEDURE NewBuiltinCallDesignator(position: Position; original: SyntaxTree.Designator; builtin: SyntaxTree.Builtin; actualParameters:SyntaxTree.ExpressionList; left: SyntaxTree.Expression; returnType: SyntaxTree.Type): SyntaxTree.Expression;
		VAR
			numberActualParameters,numberFormalParameters: LONGINT;
			formalParameter: SyntaxTree.Parameter;
			actualParameter: SyntaxTree.Expression;
			procedureType: SyntaxTree.ProcedureType;
			parameter0, parameter1, parameter2, result: SyntaxTree.Expression;
			inPort, outPort: SyntaxTree.PortType;
			constructor: SyntaxTree.Procedure;
			type0,type1,type2: SyntaxTree.Type;
			type,base,parameterType: SyntaxTree.Type;
			arrayType: SyntaxTree.ArrayType;
			i: LONGINT; i0, i1, value: Basic.Integer;
			r,r0,r1,im: LONGREAL;
			c: CHAR;
			id: LONGINT;
			b: BOOLEAN;
			first: LONGINT;

			mathArrayType: SyntaxTree.MathArrayType;
			customBuiltin: SyntaxTree.CustomBuiltin;

			PROCEDURE CheckArity(from,to: Basic.Integer): BOOLEAN;
			VAR resultB: BOOLEAN;
			BEGIN
				IF numberActualParameters < from THEN
					Error(position, "less actual than formal parameters");
					result := SyntaxTree.invalidExpression;
					resultB := FALSE;
				ELSIF numberActualParameters > to THEN
					Error(position, "more actual than formal parameters");
					result := SyntaxTree.invalidExpression;
					resultB := FALSE;
				ELSE
					resultB := TRUE;
				END;
				RETURN resultB
			END CheckArity;

			PROCEDURE CheckModifiers(cellType: SyntaxTree.CellType; modifier: SyntaxTree.Modifier);
			VAR propertyType, modifierType: SyntaxTree.Type; symbol: SyntaxTree.Symbol;
			BEGIN
				WHILE modifier # NIL DO
					symbol := cellType.FindProperty(modifier.identifier);
					IF (symbol # NIL) & (symbol IS SyntaxTree.Property) THEN
						propertyType := symbol.type.resolved;
						modifierType := modifier.expression.type.resolved;
						IF ~CompatibleTo(system, modifierType, propertyType) &
							~(
								(modifierType IS SyntaxTree.ArrayType) & (propertyType IS SyntaxTree.ArrayType) &
								OpenArrayCompatible(modifierType(SyntaxTree.ArrayType), propertyType(SyntaxTree.ArrayType))) THEN
							Error(modifier.position,"incompatible to cell property");
						END;
					ELSE
						Error(modifier.position, "undefined property");
					END;
					modifier := modifier.nextModifier;
				END;
			END CheckModifiers;

		BEGIN
			type := NIL; result := NIL;
			type0 := NIL; type1 := NIL; type2 := NIL;
			numberActualParameters := actualParameters.Length();
			IF numberActualParameters>0 THEN
				parameter0 := actualParameters.GetExpression(0);
				IF parameter0.type # NIL THEN type0 := parameter0.type.resolved ELSE
					Error(parameter0.position,"forbidden type-less argument");
					result := SyntaxTree.invalidExpression
				END
			END;
			IF numberActualParameters >1 THEN
				parameter1 := actualParameters.GetExpression(1);
				IF parameter1.type # NIL THEN type1 := parameter1.type.resolved
				ELSE
					Error(parameter1.position,"forbidden type-less argument");
					result := SyntaxTree.invalidExpression
				END
			END;
			IF numberActualParameters >2 THEN
				parameter2 := actualParameters.GetExpression(2);
				IF parameter2.type # NIL THEN type2 := parameter2.type.resolved
				ELSE
					Error(parameter2.position,"forbidden type-less argument");
					result := SyntaxTree.invalidExpression
				END
			END;

			IF returnType # NIL THEN
				id := Global.New;
				result := NIL;
			ELSE
				id := builtin.id;
				IF system.operatorDefined[id] THEN (* try to find overloaded operator *)
					result := NewOperatorCall(position,original, builtin.id,parameter0,parameter1,NIL);
				END;
			END;

			IF result = SyntaxTree.invalidExpression THEN (* error already handled *)
			ELSIF result # NIL THEN type := result.type (* operator *)
			ELSE
				result := SyntaxTree.NewBuiltinCallDesignator(position,original, id,left,actualParameters);
				result(SyntaxTree.Designator).SetLeft(left);
				IF returnType # NIL THEN
					type := returnType;
				END;
				(* ---- ASSERT ----- *)
				IF (id = Global.Assert) & CheckArity(1,2)  THEN
					IF CheckBooleanType(parameter0) THEN
	(*					mk: Commented this out because Oberon 07 uses Assert(FALSE, trap) instead of HALT
						fof: commented in again as ASSERT is crucial for compilation tests, Oberon07 obviously needs a HALT statement
							misusing ASSERT does not make the language clearer nor odes it make the compiler simpler!
	*)
						IF IsBooleanValue(parameter0,b) & ~b & ~(currentIsUnreachable)  THEN
							Error(position, "static assertion failed");
						END;
						IF (numberActualParameters > 1) & CheckIntegerValue(parameter1,i1) THEN
							(* modified: any integer parameter value is allowed, it is in the responsibility of the programmer to adhere to
								rules imposed by the architecture / current runtime
							*)
						END;
					END;
				(* ---- COPY ----- *)
				ELSIF (id = Global.Copy) & CheckArity(2,2) THEN
					IF~IsStringType(type0) THEN
						Error(parameter0.position,"no string type");
					END;
					IF ~IsStringType(type1) THEN
						Error(parameter1.position,"no string type");
					ELSIF CheckVariable(parameter1) THEN
						IF (type0 IS SyntaxTree.StringType) THEN
							arrayType := type1(SyntaxTree.ArrayType);
							IF arrayType.form = SyntaxTree.Static THEN
								IF arrayType.staticLength < type0(SyntaxTree.StringType).length THEN
									Error(position, "destination length smaller than source length")
								END;
							END;
						END;
					END;
				(* ---- INC, DEC----- *)
				ELSIF ((id = Global.Dec) OR (id = Global.Inc)) & CheckArity(1,2) THEN
					IF numberActualParameters = 1 THEN
						parameter1 :=Global.NewIntegerValue(system,position,1);
						actualParameters.AddExpression(parameter1);
					END;
					IF CheckVariable(parameter0) & CheckIntegerType(parameter0) & CheckIntegerType(parameter1) THEN
						IF ~CompatibleTo(system,parameter1.type,parameter0.type) THEN
							Error(position, "incompatible increment");
						ELSE
							parameter1 := NewConversion(Basic.invalidPosition,parameter1,parameter0.type,NIL);
							actualParameters.SetExpression(1,parameter1);
						END;
					END;
				(* ---- EXCL, INCL----- *)
				ELSIF ((id = Global.Excl) OR (id = Global.Incl)) & CheckArity(2,2) THEN
					IF CheckVariable(parameter0) & CheckSetType(parameter0) & CheckIntegerType(parameter1) THEN
						IF IsIntegerValue(parameter1,i0) THEN
							IF (i0 < 0) OR (i0>= system.setType.sizeInBits) THEN
								Error(position, "parameter out of SET range")
							END;
						END;
						parameter1 := NewConversion(Basic.invalidPosition,parameter1,system.longintType,NIL);
						actualParameters.SetExpression(1,parameter1);
					END;
				(* ---- HALT, SYSTEM.HALT ----- *)
				ELSIF ((id = Global.Halt) OR (id = Global.systemHalt)) & CheckArity(1,1) THEN
					IF CheckPositiveIntegerValue(parameter0,i0,FALSE) THEN
						(* modified: any integer parameter value is allowed, it is in the responsibility of the programmer to adhere to
							rules imposed by the architecture / current runtime
						*)
					END;
				(* ---- WAIT ----- *)
				ELSIF cooperative & (id = Global.Wait) & CheckArity(1,1) THEN
					IF CheckObjectType(parameter0) THEN
					END;
				(* ---- NEW ----- *)
				ELSIF (id = Global.New)  THEN
					IF returnType # NIL THEN
						first := 0; type2 := type1; type1 := type0 ; type0:= returnType.resolved;
					ELSE
						first := 1;
					END;
					IF CheckArity(first,Infinity) THEN
					IF currentIsRealtime THEN
						Error(position, "forbidden new in realtime block");
					END;
					IF IsUnsafePointer(type0) THEN
						Error(position, "forbidden new on unsafe pointer");
					END;
					(* check constructor *)
					IF (first =0) OR CheckVariable(parameter0) THEN
						IF type0 IS SyntaxTree.PointerType THEN
							type0 := type0(SyntaxTree.PointerType).pointerBase.resolved;
						ELSIF type0 IS SyntaxTree.CellType THEN
						ELSIF type0 IS SyntaxTree.MathArrayType THEN
						ELSE
							Error(position, "forbidden new on value type");
						END;
						IF type0 IS SyntaxTree.ArrayType THEN
							arrayType := type0(SyntaxTree.ArrayType);
							IF arrayType.form = SyntaxTree.Static THEN
								i := first
							ELSIF arrayType.form = SyntaxTree.Open THEN
								i := Dimension(arrayType,{SyntaxTree.Open})+first;
							ELSE HALT(100)
							END;
							IF CheckArity(i,i) & (numberActualParameters>1) THEN
								i := first;
								REPEAT
									actualParameter := actualParameters.GetExpression(i);
									IF CheckSizeType(actualParameter) THEN
										actualParameter := NewConversion(Basic.invalidPosition,actualParameter,system.lenType,NIL);
										actualParameters.SetExpression(i,actualParameter);
									END;
									INC(i);
								UNTIL ~CheckSizeType(actualParameter) OR (actualParameter.resolved # NIL) & ~CheckPositiveIntegerValue(actualParameter,i0,TRUE) OR (i=numberActualParameters);
							END;
						ELSIF (type0 IS SyntaxTree.RecordType) THEN
							IF type0(SyntaxTree.RecordType).isAbstract THEN
								Error(position, "forbidden new on abstract object");
							END;
							constructor := GetConstructor(type0(SyntaxTree.RecordType));
							IF constructor = NIL THEN
								IF CheckArity(first,first) THEN END;
							ELSIF (constructor.scope.ownerModule # currentScope.ownerModule) & ~(SyntaxTree.PublicRead IN constructor.access) THEN
								Error(position, "new on object with hidden constructor");
							ELSE
								procedureType := constructor.type(SyntaxTree.ProcedureType);
								numberFormalParameters := procedureType.numberParameters;
								IF numberActualParameters-first <= numberFormalParameters THEN
									formalParameter := procedureType.firstParameter;
									FOR i := first TO numberActualParameters-1 DO
										actualParameter := actualParameters.GetExpression(i);
										IF (actualParameter = SyntaxTree.invalidExpression) THEN
										ELSIF ~ParameterCompatible(formalParameter,actualParameter) THEN
										ELSE
											IF formalParameter.type.resolved # actualParameter.type.resolved THEN
												actualParameter := NewConversion(actualParameter.position,actualParameter,formalParameter.type,NIL);
											END;
											actualParameters.SetExpression(i,actualParameter);
										END;
										formalParameter := formalParameter.nextParameter;
									END;
									WHILE (formalParameter # NIL) DO
										IF formalParameter.defaultValue # NIL THEN
											actualParameters.AddExpression(formalParameter.defaultValue);
											formalParameter := formalParameter.nextParameter
										ELSE
											Error(position, "less actual than formal parameters");
											formalParameter := NIL;
										END;
									END;
								ELSE
									Error(position, "more actual than formal parameters")
								END;
							END;
						ELSIF type0 IS SyntaxTree.MathArrayType THEN
							mathArrayType := type0(SyntaxTree.MathArrayType);
							IF mathArrayType.form = SyntaxTree.Static THEN
								Error(position, "new on static array");
							ELSE
								IF mathArrayType.form = SyntaxTree.Tensor THEN
									i0 := first+1; i1 := Infinity;
								ELSIF mathArrayType.form = SyntaxTree.Open THEN
									i0 := Dimension(mathArrayType,{SyntaxTree.Open})+first;
									i1 := i0;
								ELSE HALT(100);
								END;
								IF type1 IS SyntaxTree.MathArrayType THEN (* NEW(a, array) *)

									(* use type checking facilities of procedure calls: artificially build parameters here and call checker *)
									base := ArrayBase(type0,MAX(LONGINT));

									parameterType := SyntaxTree.NewMathArrayType(Basic.invalidPosition,currentScope,SyntaxTree.Tensor);
									parameterType(SyntaxTree.MathArrayType).SetArrayBase(base);
									IF ~CompatibleTo(system,type0,parameterType) THEN
										Error(parameter0.position,"incompatible parameter in new");
										result := SyntaxTree.invalidExpression;
									ELSE
										parameter0 := NewConversion(Basic.invalidPosition,parameter0,parameterType,NIL); actualParameters.SetExpression(0,parameter0);
									END;

									parameterType := SyntaxTree.NewMathArrayType(Basic.invalidPosition,currentScope,SyntaxTree.Open);
									parameterType(SyntaxTree.MathArrayType).SetArrayBase(system.sizeType);
									IF ~CompatibleTo(system,type1,parameterType) THEN
										Error(parameter1.position,"parameter incompatible to math array len type");
										result := SyntaxTree.invalidExpression;
									ELSE
										parameter1 := NewConversion(Basic.invalidPosition,parameter1,parameterType,NIL); actualParameters.SetExpression(1,parameter1);
									END;
								ELSE
									IF CheckArity(i0,i1) & (numberActualParameters >first) THEN
										i := first;
										REPEAT
											actualParameter := actualParameters.GetExpression(i);
											IF CheckSizeType(actualParameter) THEN
												actualParameter := NewConversion(Basic.invalidPosition,actualParameter,system.sizeType,NIL);
												actualParameters.SetExpression(i,actualParameter);
											END;
											INC(i);
										UNTIL ~CheckSizeType(actualParameter) OR (actualParameter.resolved # NIL) & ~CheckPositiveIntegerValue(actualParameter,i0,TRUE) OR (i=numberActualParameters);
									END;
								END;
							END;
						ELSIF type0 IS SyntaxTree.CellType THEN
							IF ~(currentIsCellNet) THEN
								Error(position, "cell allocation outside activeCells ");
							ELSE
								constructor := type0(SyntaxTree.CellType).cellScope.constructor;
								IF (constructor = NIL) & CheckArity(1,1) THEN
									(* ok *)
								ELSE
									procedureType := constructor.type(SyntaxTree.ProcedureType);
									numberFormalParameters := procedureType.numberParameters;
									DEC(numberActualParameters);
									IF numberActualParameters <= numberFormalParameters THEN
										formalParameter := procedureType.firstParameter;
										FOR i := first TO numberActualParameters DO
											actualParameter := actualParameters.GetExpression(i);
											IF (actualParameter = SyntaxTree.invalidExpression) THEN
											ELSIF ~ParameterCompatible(formalParameter,actualParameter) THEN
											ELSE
												IF formalParameter.type.resolved # actualParameter.type.resolved THEN
													actualParameter := NewConversion(actualParameter.position,actualParameter,formalParameter.type,NIL);
												END;
												actualParameters.SetExpression(i,actualParameter);
											END;
											formalParameter := formalParameter.nextParameter;
										END;
										WHILE (formalParameter # NIL) DO
											IF formalParameter.defaultValue # NIL THEN
												actualParameters.AddExpression(formalParameter.defaultValue);
												formalParameter := formalParameter.nextParameter
											ELSE
												Error(position, "less actual than formal parameters");
												formalParameter := NIL;
											END;
										END;
									ELSE
										Error(position, "more actual than formal parameters")
									END;

								END;
							END;

							CheckModifiers(type0(SyntaxTree.CellType), parameter0(SyntaxTree.Designator).modifiers);

							activeCellsStatement := TRUE;
						ELSE
							Error(position, "cannot be allocated");
						END;
					END;
					END;
				(* ---- DISPOSE ----- *)
				ELSIF (id = Global.Dispose) & CheckArity(1,1) THEN
					IF ~IsPointerType(parameter0.type) THEN
						Error(parameter0.position,"is not a pointer")
					ELSIF ~IsDisposable(parameter0.type) THEN
						Error(parameter0.position,"is not disposable")
					ELSIF CheckVariable(parameter0) THEN (* ok *)
					END
				(* ---- GETPROCEDURE ----- *)
				ELSIF (id = Global.GetProcedure) & CheckArity(3,3) THEN
					IF CheckStringType(parameter0) & CheckStringType(parameter1) THEN
						IF CheckVariable(parameter2) THEN
							IF ~GetProcedureAllowed(parameter2.type) THEN
								Error(parameter2.position,"GETPROCEDURE not allowed on this type");
							END;
						END;
					END;
				(* ---- ABS ----- *)
				ELSIF (id = Global.Abs) & CheckArity(1,1) THEN
					(* note: ABS on complex numbers is done using overloading *)
					IF CheckNonComplexNumberSizeType(parameter0) THEN
						type := type0;
						IF IsIntegerValue(parameter0,i0) THEN
							result.SetResolved(SyntaxTree.NewIntegerValue(position,ABS(i0)));
							type := Global.GetIntegerType(system,ABS(i0));
						ELSIF IsRealValue(parameter0,r) THEN
							result.SetResolved(SyntaxTree.NewRealValue(position,ABS(r),Scanner.None));
						END;
					ELSE
						type := SyntaxTree.invalidType;
					END;
				(* ---- ASH, ASR ----- *)
				ELSIF ((id = Global.Ash) OR (id= Global.Asr)) & CheckArity(2,2) THEN
					type := type0;
					IF CheckIntegerType(parameter0) & CheckIntegerType(parameter1) THEN
						(*
						ConvertOperands(parameter0,parameter1); (* same type *)
						*)

						type := parameter0.type;
						IF IsIntegerValue(parameter0,i0) THEN
							IF IsIntegerValue(parameter1,i1) THEN
								IF id = Global.Ash THEN i0 := ASH(i0,i1) ELSE i0 := ASR(i0,i1) END;
								result.SetResolved(SyntaxTree.NewIntegerValue(position,i0));
								result := ResolveExpression(result);
								type := Global.GetIntegerType(system,i0);
							END;
						END;

						IF type.resolved.sizeInBits < 32 THEN
							type := system.longintType;
						END;

						(*!compatibility with release, remove when resolved
							critical in release : SHORT(ASH(..))), ASH(ORD(..))
						*)
						parameter1 := NewConversion(parameter1.position,parameter1,system.longintType,NIL);
						parameter0 := NewConversion(parameter0.position,parameter0,type,NIL);
						actualParameters.SetExpression(0,parameter0);
						actualParameters.SetExpression(1,parameter1);
					END;
				(* ---- CAP ----- *)
				ELSIF (id = Global.Cap) & CheckArity(1,1) THEN
					type := system.characterType;
						IF CheckCharacterType (parameter0) THEN
						parameter0 := NewConversion(parameter0.position,parameter0,type,NIL);
						actualParameters.SetExpression(0,parameter0);
						IF IsCharacterValue(parameter0,c) THEN
							IF (c <= "z") & (c >= "a") THEN
								result.SetResolved(SyntaxTree.NewCharacterValue(position,CAP(c)))
							ELSE
								result.SetResolved(SyntaxTree.NewCharacterValue(position,c))
							END;
						END;
					END;
				(* ---- CHR ----- *)
				ELSIF ((id = Global.Chr) OR (id = Global.Chr32)) & CheckArity(1,1) THEN
					IF id = Global.Chr THEN
						type := system.characterType
					ELSE
						type := system.characterType32
					END;
					IF CheckIntegerType(parameter0) THEN
						IF IsIntegerValue(parameter0,i0)  THEN
							result.SetResolved(SyntaxTree.NewCharacterValue(position,CHR(i0)));
							result := ResolveExpression(result);
						ELSE
							(*
							result := NewConversion(parameter0.position,parameter0,type);
							*)
						END;
					END
				(* ---- ENTIER ----- *)
				ELSIF (id = Global.Entier) & CheckArity(1,1) THEN
					type := system.longintType;
					IF CheckRealType(parameter0) THEN
						IF IsRealValue(parameter0,r) THEN
							result.SetResolved(SyntaxTree.NewIntegerValue(position,ENTIER(r)));
							type := Global.GetIntegerType(system,ENTIER(r));
						END
					END;
				(* ---- ENTIERH ----- *)
				ELSIF (id = Global.EntierH) & CheckArity(1,1) THEN
					type := system.hugeintType;
					IF CheckRealType(parameter0) THEN
						IF IsRealValue(parameter0,r) THEN
							result.SetResolved(SyntaxTree.NewIntegerValue(position,ENTIERH(r)));
						END
					END;
				(* ---- LEN ----- *)
				ELSIF (id = Global.Len) & CheckArity(1,2) THEN
					type := system.lenType;
					base := type0;

					IF (base IS SyntaxTree.PointerType) & (parameter0 IS SyntaxTree.Designator) THEN
						IF base(SyntaxTree.PointerType).isUnsafe THEN
							base := base(SyntaxTree.PointerType).pointerBase.resolved;
							IF~(base IS SyntaxTree.ArrayType) OR (base(SyntaxTree.ArrayType).form # SyntaxTree.Static) THEN
								Error(position, "forbidden len on unsafe pointer");
							END;
							type0 := base;
						ELSE
							parameter0 := NewDereferenceDesignator(position,parameter0(SyntaxTree.Designator),parameter0(SyntaxTree.Designator));
							type0 := parameter0.type.resolved;
							actualParameters.SetExpression(0,parameter0);
							base := type0;
						END;
					END;

					IF (numberActualParameters=1) OR (numberActualParameters =2) & CheckIntegerType(parameter1) THEN
						IF ~(numberActualParameters=2) OR ~IsIntegerValue(parameter1,i1) THEN i1 := 0 END;
						IF i1 < 0 THEN
							Error(position, "invalid dimension");
							base := SyntaxTree.invalidType;
						ELSE
							base := ArrayBase(base,LONGINT(i1)); (* TODO: fix explicit integer truncation *)
							IF (base # NIL) & Indexable(base) THEN
							ELSE
								Error(position, "len on no array");
								IF VerboseErrorMessage THEN
									Printout.Info("base",base);
								END;
								base := SyntaxTree.invalidType;
							END;
						END;
						IF numberActualParameters=2 THEN
							parameter1 := NewConversion(parameter1.position,parameter1,system.lenType,NIL);
							actualParameters.SetExpression(1,parameter1);
						ELSIF base IS SyntaxTree.MathArrayType THEN
							Error(position, "missing dimension specification");
						END;
						IF (numberActualParameters=1) OR (numberActualParameters =2) & IsIntegerValue(parameter1,i1) THEN
							IF base IS SyntaxTree.ArrayType THEN
								arrayType := base(SyntaxTree.ArrayType);
								IF (arrayType.length # NIL) & (arrayType.length.resolved # NIL) & IsIntegerValue(arrayType.length,value) THEN
									(* do not use length directly such as in result := length as this mide have side-effects when result types get converted *)
									result := Global.NewIntegerValue(system,position,value);
									type := result.type;(* arrayType.length.type;*)
									ASSERT(type # NIL);
								END;
							ELSIF base IS SyntaxTree.MathArrayType THEN
								mathArrayType := base(SyntaxTree.MathArrayType);
								IF (mathArrayType.length # NIL) & (mathArrayType.length.resolved # NIL) & IsIntegerValue(mathArrayType.length,value) THEN
									result := Global.NewIntegerValue(system,position,value);
									type := result.type;
									(*
									type := mathArrayType.length.type;
									*)
									ASSERT(type # NIL);
								END;
							END;
						END;
					ELSE
						type := system.lenType;
					END;
				(* ---- FIRST ---- *)
				ELSIF (id = Global.First) & CheckArity(1,1) THEN
					type := system.lenType;
					IF CheckRangeType(parameter0) THEN END;
					result.SetAssignable(parameter0.assignable)

				(* ---- LAST ---- *)
				ELSIF (id = Global.Last) & CheckArity(1,1) THEN
					type := system.lenType;
					IF CheckRangeType(parameter0) THEN END;
					result.SetAssignable(parameter0.assignable)

				(* ---- STEP ---- *)
				ELSIF (id = Global.Step) & CheckArity(1,1) THEN
					type := system.lenType;
					IF CheckRangeType(parameter0) THEN END;
					result.SetAssignable(parameter0.assignable)

				(* ---- RE ---- *)
				ELSIF (id = Global.Re) & CheckArity(1,1) THEN
					IF CheckNumberType(parameter0) THEN
						IF parameter0.type.resolved IS SyntaxTree.ComplexType THEN
							type := parameter0.type.resolved(SyntaxTree.ComplexType).componentType;
							IF IsComplexValue(parameter0, r, im) THEN result.SetResolved(SyntaxTree.NewRealValue(parameter0.position, r, Scanner.None)) END
						ELSIF parameter0.type.resolved IS SyntaxTree.FloatType THEN
							type := parameter0.type
						ELSE
							type := system.realType
						END
					END;
					result.SetAssignable(parameter0.assignable)

				(* ---- IM ---- *)
				ELSIF (id = Global.Im) & CheckArity(1,1) THEN
					IF CheckNumberType(parameter0) THEN
						IF parameter0.type.resolved IS SyntaxTree.ComplexType THEN
							type := parameter0.type.resolved(SyntaxTree.ComplexType).componentType;
							IF IsComplexValue(parameter0, r, im) THEN result.SetResolved(SyntaxTree.NewRealValue(parameter0.position, im, Scanner.None)) END
						ELSE
							type := system.realType;
							result.SetResolved(SyntaxTree.NewRealValue(parameter0.position, 0, Scanner.None))
						END
					END;
					result.SetAssignable(parameter0.assignable)

				(* ---- MAX ----- *)
				ELSIF (id = Global.Max) & CheckArity(1,2) THEN
					IF numberActualParameters = 1 THEN
						IF parameter0.type = SyntaxTree.typeDeclarationType THEN
							type := parameter0(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType.resolved;
							IF type IS SyntaxTree.CharacterType THEN result.SetResolved(SyntaxTree.NewCharacterValue(position,MAX(CHAR)));
							(*!! ELSIF type = Global.Char16 THEN result.SetResolved(SyntaxTree.NewIntegerValue(position,0FFFFH));
							ELSIF type = Global.Char32 THEN result.SetResolved(SyntaxTree.NewIntegerValue(position,0FFFFFFFFH));
							*)
							ELSIF type IS SyntaxTree.IntegerType THEN result.SetResolved(SyntaxTree.NewIntegerValue(position,Global.MaxInteger(system,type(SyntaxTree.IntegerType),type(SyntaxTree.IntegerType).signed)));
							ELSIF type IS SyntaxTree.FloatType THEN result.SetResolved(SyntaxTree.NewRealValue(position,Global.MaxFloat(system,type(SyntaxTree.FloatType)), Scanner.None));
							ELSIF type IS SyntaxTree.SetType THEN result.SetResolved(SyntaxTree.NewIntegerValue(position,system.SizeOf(type)-1)); type := system.shortintType;
							ELSIF type IS SyntaxTree.SizeType THEN result.SetResolved(SyntaxTree.NewIntegerValue(position,Global.MaxInteger(system,type(SyntaxTree.BasicType),TRUE)));
							ELSIF type IS SyntaxTree.AddressType THEN result.SetResolved(SyntaxTree.NewIntegerValue(position,Global.MaxInteger(system,type(SyntaxTree.BasicType),FALSE)));
							ELSE Error(parameter0.position, "builtin function not applicable to this type");
							END;
						ELSE
							Error(parameter0.position,"is not a type symbol");
						END
					ELSIF CheckNonComplexNumberSizeType(parameter0) & CheckNonComplexNumberSizeType(parameter1) THEN
						ConvertOperands(parameter0,parameter1);
						actualParameters.SetExpression(0,parameter0);
						actualParameters.SetExpression(1,parameter1);
						IF IsRealValue(parameter0,r0) & IsRealValue(parameter1,r1) THEN
							IF r0 > r1 THEN result.SetResolved(parameter0.resolved)
							ELSE result.SetResolved(parameter0.resolved)
							END;
						ELSIF IsIntegerValue(parameter0,i0) & IsIntegerValue(parameter1,i1) THEN
							IF i0 > i1 THEN result.SetResolved(parameter0.resolved)
							ELSE result.SetResolved(parameter1.resolved)
							END;
						END;
						type := parameter0.type;
					ELSE type := SyntaxTree.invalidType;
					END;
				(* ---- MIN ----- *)
				ELSIF (id = Global.Min) & CheckArity(1,2) THEN
					IF numberActualParameters = 1 THEN
						IF parameter0.type = SyntaxTree.typeDeclarationType THEN
							type := parameter0(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType.resolved;
							IF type IS SyntaxTree.CharacterType THEN result.SetResolved(SyntaxTree.NewCharacterValue(position,MIN(CHAR)));
							ELSIF type IS SyntaxTree.IntegerType THEN result.SetResolved(SyntaxTree.NewIntegerValue(position,Global.MinInteger(system,type(SyntaxTree.IntegerType),type(SyntaxTree.IntegerType).signed)));
							ELSIF type IS SyntaxTree.FloatType THEN result.SetResolved(SyntaxTree.NewRealValue(position,Global.MinFloat(system,type(SyntaxTree.FloatType)), Scanner.None));
							ELSIF type IS SyntaxTree.SetType THEN result.SetResolved(SyntaxTree.NewIntegerValue(position,0)); type := system.shortintType;
							ELSIF type IS SyntaxTree.SizeType THEN result.SetResolved(SyntaxTree.NewIntegerValue(position, Global.MinInteger(system,type(SyntaxTree.BasicType),TRUE)));
							ELSIF type IS SyntaxTree.AddressType THEN result.SetResolved(SyntaxTree.NewIntegerValue(position, Global.MinInteger(system,type(SyntaxTree.BasicType),FALSE)));
							ELSE Error(parameter0.position,"builtin function not applicable to this type");
							END;
						ELSE
							Error(parameter0.position,"is not a type symbol");
						END
					ELSIF CheckNonComplexNumberSizeType(parameter0) & CheckNonComplexNumberSizeType(parameter1) THEN
						ConvertOperands(parameter0,parameter1);
						actualParameters.SetExpression(0,parameter0);
						actualParameters.SetExpression(1,parameter1);
						IF IsRealValue(parameter0,r0) & IsRealValue(parameter1,r1) THEN
							IF r0 < r1 THEN result.SetResolved(parameter0.resolved)
							ELSE result.SetResolved(parameter1.resolved)
							END;
						ELSIF IsIntegerValue(parameter0,i0) & IsIntegerValue(parameter1,i1) THEN
							IF i0 < i1 THEN result.SetResolved(parameter0.resolved)
							ELSE result.SetResolved(parameter1.resolved)
							END;
						END;
						type := parameter0.type;
					ELSE type := SyntaxTree.invalidType;
					END;
				(* ---- ODD ----- *)
				ELSIF (id = Global.Odd) & CheckArity(1,1) THEN
					type := system.booleanType;
					IF CheckIntegerType(parameter0) THEN
						IF IsIntegerValue(parameter0,i0)  THEN
							result.SetResolved(SyntaxTree.NewBooleanValue(position,ODD(i0)));
							type := system.booleanType;
						END;
					END;
				(* ---- ORD ----- *)
				ELSIF ((id = Global.Ord) OR (id = Global.Ord32)) & CheckArity(1,1) THEN
					IF id = Global.Ord THEN
						type := system.integerType;
					ELSE
						type := system.longintType;
					END;
					IF CompatibleTo(system, parameter0.type, system.characterType) THEN
						parameter0 := NewConversion(parameter0.position, parameter0, system.characterType,NIL);
						actualParameters.SetExpression(0,parameter0);
						(* IF CheckCharacterType(parameter0) THEN*)
						IF IsCharacterValue(parameter0,c)THEN
							result.SetResolved(Global.NewIntegerValue(system,position,ORD(c)));
							type := Global.GetSignedIntegerType(system,ORD(c));
						END;
					ELSE Error(parameter0.position, "incompatible parameter");
					END;
				(* ---- SHORT ----- *)
				ELSIF (id = Global.Short) & CheckArity(1,1) THEN
					type := type0;
					IF IsSignedIntegerType(type) THEN
						IF (type.sizeInBits = 8) OR (type = system.shortintType) THEN Error(parameter0.position,"short not applicable")
						ELSIF type = system.integerType THEN type := system.shortintType
						ELSIF type = system.longintType THEN type := system.integerType
						ELSIF type = system.hugeintType THEN type:= system.longintType
						ELSE
							CASE type.sizeInBits OF
								16: type := Global.Integer8
								|32: type := Global.Integer16
								|64: type := Global.Integer32
							END;
						END;
					ELSIF IsUnsignedIntegerType(type) THEN
						IF (type.sizeInBits = 8) OR (type = Global.Unsigned8) THEN Error(parameter0.position,"short not applicable")
						ELSE
							CASE type.sizeInBits OF
								16: type := Global.Unsigned8
								|32: type := Global.Unsigned16
								|64: type := Global.Unsigned32
							END;
						END;
					ELSIF type IS SyntaxTree.FloatType THEN
						IF (type.sizeInBits = 32) OR (type = system.realType) THEN Error(parameter0.position,"short not applicable")
						ELSIF type = system.longrealType THEN type := system.realType
						ELSIF type.sizeInBits = 64 THEN type := Global.Float32
						END;
					ELSIF type IS SyntaxTree.ComplexType THEN
						IF (type.sizeInBits = 64) OR (type = system.complexType) THEN Error(parameter0.position,"short not applicable")
						ELSIF (type = system.longcomplexType) THEN type := system.complexType
						ELSIF type.sizeInBits = 128 THEN type := Global.Complex64
						END;
					ELSE
						Error(parameter0.position,"short not applicable")
					END;
					IF (parameter0.resolved # NIL) THEN
						parameter0 := ConvertValue(parameter0.position,parameter0.resolved,type);
						IF parameter0 IS SyntaxTree.Value THEN
							result.SetResolved(parameter0(SyntaxTree.Value));
						END;
					END;
				(* ---- LONG ----- *)
				ELSIF (id = Global.Long) & CheckArity(1,1) THEN
					type := type0;
					IF IsSignedIntegerType(type) THEN
						IF (type.sizeInBits = 64) OR (type = system.hugeintType) THEN Error(parameter0.position,"long not applicable")
						ELSIF type = system.longintType THEN type := system.hugeintType
						ELSIF type = system.integerType THEN type := system.longintType
						ELSIF type = system.shortintType THEN type := system.integerType
						ELSE
							CASE type.sizeInBits OF
							8: type := Global.Integer16
							|16: type := Global.Integer32
							|32: type := Global.Integer64
							END;
						END;
					ELSIF IsUnsignedIntegerType(type) THEN
						IF (type.sizeInBits = 64) OR (type = Global.Unsigned64) THEN Error(parameter0.position,"long not applicable")
						ELSE
							CASE type.sizeInBits OF
							8: type := Global.Unsigned16
							|16: type := Global.Unsigned32
							|32: type := Global.Unsigned64
							END;
						END;
					ELSIF type IS SyntaxTree.FloatType THEN
						IF (type.sizeInBits = 64) OR (type = system.longrealType) THEN Error(parameter0.position,"long not applicable")
						ELSIF type= system.realType THEN  type := system.longrealType
						ELSIF type.sizeInBits = 32 THEN type := Global.Float64
						END;
					ELSIF type IS SyntaxTree.ComplexType THEN
						IF (type.sizeInBits = 128) OR (type = system.longcomplexType) THEN Error(parameter0.position,"long not applicable")
						ELSIF type = system.complexType THEN type := system.longcomplexType
						ELSIF type.sizeInBits = 64 THEN type := Global.Complex128
						END;
					ELSE
						Error(parameter0.position,"long not applicable")
					END;
					IF (parameter0.resolved # NIL) THEN
						parameter0 := ConvertValue(parameter0.position,parameter0.resolved,type);
						IF parameter0 IS SyntaxTree.Value THEN
							result.SetResolved(parameter0(SyntaxTree.Value));
						END;
					END;
				(* ---- SIZE OF ----- *)
				ELSIF (id = Global.systemSize) & CheckArity(1,1) THEN
					IF (parameter0.type = SyntaxTree.typeDeclarationType) THEN
						type := parameter0(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType;
						result.SetResolved(SyntaxTree.NewIntegerValue(position,system.SizeOf(type.resolved) DIV 8 (* in bytes *) ));
						type := system.integerType;
						(* was Int16  in paco but should be systemSize (conflict with current release) *)
					ELSE
						(* for variables, system sizeof could represent the physically occupied size
							determined via the type descriptor, implement that ? *)
						Error(parameter0.position,"is not a type symbol");
					END
				(* ---- SYSTEM.TRACE -----*)
				ELSIF (id = Global.systemTrace) & CheckArity(1,MAX(LONGINT)) THEN
					FOR i := 0 TO numberActualParameters-1 DO
						parameter0 := actualParameters.GetExpression(i);
						IF ~IsBasicType(parameter0.type) & ~IsStringType(parameter0.type) THEN
							Error(parameter0.position,"incompatible parameter");
						END;
					END;
					(* remaining issues can only be tested in backend *)
				(* ---- ADDRESSOF----- *)
				ELSIF (id = Global.systemAdr) & CheckArity(1,1) THEN
					IF HasAddress(parameter0) THEN
						type := system.addressType;
					ELSE
						type := SyntaxTree.invalidType;
						Error(parameter0.position,"has no address");

					END;
				(* ---- BIT ----- *)
				ELSIF (id = Global.systemBit) & CheckArity(2,2) THEN
					IF CheckAddressType(parameter0) & CheckSizeType(parameter1) THEN
						parameter0 := NewConversion(parameter0.position,parameter0,system.addressType,NIL);
						actualParameters.SetExpression(0,parameter0);
						parameter1 := NewConversion(parameter1.position,parameter1,system.addressType,NIL);
						actualParameters.SetExpression(1,parameter1);
					END;
					type := system.booleanType;
				(* ----- MSK ---- *)
				ELSIF (id = Global.systemMsk) & CheckArity(2,2) THEN
					IF CheckIntegerType(parameter0) & CheckIntegerType(parameter1) THEN
						ConvertOperands(parameter0,parameter1);
						actualParameters.SetExpression(0,parameter0);
						actualParameters.SetExpression(1,parameter1);
					END;
					type := parameter0.type;
				(* ---- SYSTEM.GET64 ----- *)
				ELSIF (id = Global.systemGet64) & CheckArity(1,1) THEN
					IF CheckAddressType(parameter0) THEN
						parameter0 := NewConversion(Basic.invalidPosition,parameter0,system.addressType,NIL);
						actualParameters.SetExpression(0,parameter0);
					END;
					type := system.hugeintType;
				(* ---- SYSTEM.GET32 ----- *)
				ELSIF (id = Global.systemGet32) & CheckArity(1,1) THEN
					IF CheckAddressType(parameter0) THEN
						parameter0 := NewConversion(Basic.invalidPosition,parameter0,system.addressType,NIL);
						actualParameters.SetExpression(0,parameter0);
					END;
					type := system.longintType;
				(* ---- SYSTEM.GET16 ----- *)
				ELSIF (id = Global.systemGet16) & CheckArity(1,1) THEN
					IF CheckAddressType(parameter0) THEN
						parameter0 := NewConversion(Basic.invalidPosition,parameter0,system.addressType,NIL);
						actualParameters.SetExpression(0,parameter0);
					END;
					type := system.integerType;
				(* ---- SYSTEM.GET8 ----- *)
				ELSIF (id = Global.systemGet8) & CheckArity(1,1) THEN
					IF CheckAddressType(parameter0) THEN
						parameter0 := NewConversion(Basic.invalidPosition,parameter0,system.addressType,NIL);
						actualParameters.SetExpression(0,parameter0);
					END;
					type := system.shortintType;
				(* ---- SYSTEM.GetStackPointer ----- *)
				ELSIF (id = Global.systemGetStackPointer) & CheckArity(0,0) THEN
					type := system.addressType;
				(* ---- SYSTEM.GetFramePointer ----- *)
				ELSIF (id = Global.systemGetFramePointer) & CheckArity(0,0) THEN
					type := system.addressType;
				(* ---- SYSTEM.GetActivity ----- *)
				ELSIF cooperative & (id = Global.systemGetActivity) & CheckArity(0,0) THEN
					type := system.objectType;
				(* ---- SYSTEM.SetStackPointer ----- *)
				ELSIF (id = Global.systemSetStackPointer) & CheckArity(1,1) THEN
					IF CheckAddressType(parameter0) THEN
						parameter0 := NewConversion(Basic.invalidPosition,parameter0,system.addressType,NIL);
						actualParameters.SetExpression(0,parameter0);
					END;
				(* ---- SYSTEM.SetFramePointer ----- *)
				ELSIF (id = Global.systemSetFramePointer) & CheckArity(1,1) THEN
					IF CheckAddressType(parameter0) THEN
						parameter0 := NewConversion(Basic.invalidPosition,parameter0,system.addressType,NIL);
						actualParameters.SetExpression(0,parameter0);
					END;
				(* ---- SYSTEM.SetActivity ----- *)
				ELSIF cooperative & (id = Global.systemSetActivity) & CheckArity(1,1) THEN
					IF CheckObjectType(parameter0) THEN
						parameter0 := NewConversion(Basic.invalidPosition,parameter0,system.addressType,NIL);
						actualParameters.SetExpression(0,parameter0);
					END;
				(* ---- LSH, LSL, ROT, ROR ----- *)
				ELSIF ((id = Global.Lsh) OR (id = Global.Rot) OR (id= Global.Ror)) & CheckArity(2,2) THEN
					type := type0;

					parameter1 := NewConversion(parameter1.position,parameter1,system.longintType,NIL);
					actualParameters.SetExpression(1, parameter1);

					IF IsIntegerValue(parameter0,i0) & IsIntegerValue(parameter1,i1) THEN
						IF id = Global.Lsh THEN
							result.SetResolved(SyntaxTree.NewIntegerValue(position,LSH(i0,i1)));
						ELSIF id = Global.Rot THEN
							result.SetResolved(SyntaxTree.NewIntegerValue(position,ROT(i0,i1)));
						ELSIF id = Global.Ror THEN
							result.SetResolved(SyntaxTree.NewIntegerValue(position,ROR(i0,i1)));
						END;
					END;
				(* ---- SYSTEM.VAL ----- *)
				ELSIF (id = Global.systemVal) & CheckArity(2,2) THEN
					IF CheckTypeDeclarationType(parameter0) THEN
						type := parameter0(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType;
						IF (type.resolved IS SyntaxTree.ArrayType) & (type.resolved(SyntaxTree.ArrayType).form # SyntaxTree.Static) THEN
							result := SyntaxTree.invalidExpression;
							Error(parameter0.position,"is no basic type");
						ELSE
							IF (parameter1.resolved # NIL) THEN
								parameter0 := ConvertValue(parameter1.position,parameter1.resolved,type);
								IF parameter0 IS SyntaxTree.Value THEN
									result.SetResolved(parameter0(SyntaxTree.Value));
								END;
							END;
							result.SetAssignable(parameter1.assignable);
						END;
					END;
				(* ---- SYSTEM.GET ----- *)
				ELSIF (id = Global.systemGet) & CheckArity(2,2) THEN
					IF CheckAddressType(parameter0) & CheckBasicType(parameter1) & CheckVariable(parameter1) THEN
						parameter0 := NewConversion(Basic.invalidPosition,parameter0,system.addressType,NIL);
						actualParameters.SetExpression(0,parameter0);
					END;
				(* ---- SYSTEM.PUT ----- *)
				ELSIF (id = Global.systemPut) & CheckArity(2,2) THEN
					IF CheckAddressType(parameter0) & CheckBasicType(parameter1) THEN
						parameter0 := NewConversion(Basic.invalidPosition,parameter0,system.addressType,NIL);
						actualParameters.SetExpression(0,parameter0);
					END;
				(* ---- SYSTEM.PUT64 ----- *)
				ELSIF (id = Global.systemPut64) & CheckArity(2,2) THEN
					IF CheckAddressType(parameter0) & CheckBasicType(parameter1) THEN
						parameter0 := NewConversion(parameter0.position,parameter0,system.addressType,NIL);
						parameter1 := NewConversion(parameter1.position,parameter1,system.hugeintType,NIL);
						actualParameters.SetExpression(0,parameter0);
						actualParameters.SetExpression(1,parameter1);
					END;
				(* ---- SYSTEM.PUT32 ----- *)
				ELSIF (id = Global.systemPut32) & CheckArity(2,2) THEN
					IF CheckAddressType(parameter0) & CheckBasicType(parameter1) THEN
						parameter0 := NewConversion(parameter0.position,parameter0,system.addressType,NIL);
						parameter1 := NewConversion(parameter1.position,parameter1,system.longintType,NIL);
						actualParameters.SetExpression(0,parameter0);
						actualParameters.SetExpression(1,parameter1);
					END;
				(* ---- SYSTEM.PUT16 ----- *)
				ELSIF (id = Global.systemPut16) & CheckArity(2,2) THEN
					IF CheckAddressType(parameter0) & CheckBasicType(parameter1) THEN
						parameter0 := NewConversion(parameter0.position,parameter0,system.addressType,NIL);
						parameter1 := NewConversion(parameter1.position,parameter1,system.integerType,NIL);
						actualParameters.SetExpression(0,parameter0);
						actualParameters.SetExpression(1,parameter1);
					END;
				(* ---- SYSTEM.PUT8 ----- *)
				ELSIF (id = Global.systemPut8) & CheckArity(2,2) THEN
					IF CheckAddressType(parameter0) & CheckBasicType(parameter1) THEN
						parameter0 := NewConversion(parameter0.position,parameter0,system.addressType,NIL);
						parameter1 := NewConversion(parameter1.position,parameter1,system.shortintType,NIL);
						actualParameters.SetExpression(0,parameter0);
						actualParameters.SetExpression(1,parameter1);
					END;
				(* ---- SYSTEM.MOVE ----- *)
				ELSIF (id = Global.systemMove) & CheckArity(3,3) THEN
					IF CheckAddressType(parameter0) & CheckAddressType(parameter1) & CheckAddressType(parameter2) THEN
						parameter0 := NewConversion(Basic.invalidPosition,parameter0,system.addressType,NIL);
						parameter1 := NewConversion(Basic.invalidPosition,parameter1,system.addressType,NIL);
						parameter2 := NewConversion(Basic.invalidPosition,parameter2,system.addressType,NIL);
						actualParameters.SetExpression(0,parameter0);
						actualParameters.SetExpression(1,parameter1);
						actualParameters.SetExpression(2,parameter2);
					END;
				(* ---- SYSTEM.NEW ----- *)
				ELSIF (id = Global.systemNew) & CheckArity(2,2) THEN
					IF ~IsPointerType(parameter0.type) THEN
						Error(parameter0.position,"is not a pointer")
					ELSIF CheckSizeType(parameter1) THEN
						parameter1 := NewConversion(Basic.invalidPosition, parameter1, system.sizeType,NIL);
						actualParameters.SetExpression(1,parameter1);
					END;
				(* ----SYSTEM.REF ---- *)
				ELSIF (id = Global.systemRef) & CheckArity(1,1) & CheckStringType(parameter0) THEN
					type := system.addressType
				(* ---- INCR ----- *)
				ELSIF (id = Global.Incr) & CheckArity(1,2) THEN
					type := system.lenType;
					base := type0;
					IF (numberActualParameters =2) & CheckSizeType(parameter1) THEN
						IF ~IsIntegerValue(parameter1,i1) THEN i1 := 0 END;
						IF i1 < 0 THEN
							Error(position, "invalid dimension");
							base := SyntaxTree.invalidType;
						ELSE
							base := ArrayBase(base,LONGINT(i1)); (* TODO: fix explicit integer truncation *)
							IF (base # NIL) & Indexable(base) THEN
							ELSE
								Error(position, "len on no array");
								IF VerboseErrorMessage THEN
									Printout.Info("base",base);
								END;
								base := SyntaxTree.invalidType;
							END;
						END;
						parameter1 := NewConversion(parameter1.position,parameter1,system.lenType,NIL);
						actualParameters.SetExpression(1,parameter1);
						IF (numberActualParameters =2) & (parameter1 IS SyntaxTree.IntegerValue) THEN
							mathArrayType := base(SyntaxTree.MathArrayType);
							IF (mathArrayType.form = SyntaxTree.Static) THEN
								result := SyntaxTree.NewIntegerValue(position,ToMemoryUnits(system,mathArrayType.staticIncrementInBits));
								type := system.lenType;
							END;
						END;
					ELSE
						type := system.lenType;
					END;

				(* ---- SUM ----- *)
				ELSIF (id = Global.Sum) & CheckArity(1,2) THEN (* can only be found by overloading *)
					Error(position, "sum operator not applicable");
				(* ---- ALL ----- *)
				ELSIF (id = Global.All) & CheckArity(2,4) THEN (* can only be found by overloading *)
					Error(position, "all operator not applicable");
				(* ---- DIM ----- *)
				ELSIF (id = Global.Dim) & CheckArity(1,1) THEN
					type := system.lenType;
					IF type0 IS SyntaxTree.MathArrayType THEN
						IF type0(SyntaxTree.MathArrayType).form # SyntaxTree.Tensor THEN
							i := Dimension(type0,{SyntaxTree.Open,SyntaxTree.Static});
							result.SetResolved(SyntaxTree.NewIntegerValue(position,i));
						END;
					ELSE
						Error(position, "dimension on non math array type");
					END;
				(* ---- CAS ----- *)
				ELSIF (id = Global.Cas) & CheckArity(3,3) THEN
					IF type0.IsComposite () THEN
						Error(position, "first parameter of composite type");
						result := SyntaxTree.invalidExpression;
					ELSIF ~IsVariable (parameter0) THEN
						Error(position, "first parameter not assignable");
						result := SyntaxTree.invalidExpression;
					ELSIF ~CompatibleTo(system,type1,type0) THEN
						Error(position, "second parameter incompatible");
						result := SyntaxTree.invalidExpression;
					ELSIF ~CompatibleTo(system,type2,type0) THEN
						Error(position, "third parameter incompatible");
						result := SyntaxTree.invalidExpression;
					ELSE
						parameter1 := NewConversion(Basic.invalidPosition,parameter1,type0,NIL); actualParameters.SetExpression(1,parameter1);
						parameter2 := NewConversion(Basic.invalidPosition,parameter2,type0,NIL); actualParameters.SetExpression(2,parameter2);
						type := type0;
					END;
				(* ---- RESHAPE ----- *)
				ELSIF (id = Global.Reshape) & CheckArity(2,2) THEN
					IF type0 IS SyntaxTree.MathArrayType THEN
						(* use type checking facilities of procedure calls: artificially build parameters here and call checker *)
						base := ArrayBase(type0,MAX(LONGINT));
						type := SyntaxTree.NewMathArrayType(Basic.invalidPosition,currentScope,SyntaxTree.Tensor);
						type(SyntaxTree.MathArrayType).SetArrayBase(base);

						parameterType := SyntaxTree.NewMathArrayType(Basic.invalidPosition,currentScope,SyntaxTree.Tensor);
						parameterType(SyntaxTree.MathArrayType).SetArrayBase(base);
						IF ~CompatibleTo(system,type0,parameterType) THEN
							Error(parameter0.position,"incompatible parameter in reshape");
							result := SyntaxTree.invalidExpression;
						ELSE
							parameter0 := NewConversion(Basic.invalidPosition,parameter0,parameterType,NIL); actualParameters.SetExpression(0,parameter0);
						END;

						parameterType := SyntaxTree.NewMathArrayType(Basic.invalidPosition,currentScope,SyntaxTree.Open);
						parameterType(SyntaxTree.MathArrayType).SetArrayBase(system.sizeType);
						IF ~CompatibleTo(system,type1,parameterType) THEN
							Error(parameter1.position,"parameter incompatible to math array of longint");
							result := SyntaxTree.invalidExpression;
						ELSE
							parameter1 := NewConversion(Basic.invalidPosition,parameter1,parameterType,NIL); actualParameters.SetExpression(1,parameter1);
						END;
					ELSE
						Error(position,"reshape on non math array type");
						result := SyntaxTree.invalidExpression;
					END;
				(* ---- SYSTEM.TYPECODE ----- *)
				ELSIF (id = Global.systemTypeCode) & CheckArity(1,1) THEN
					IF (parameter0.type = SyntaxTree.typeDeclarationType) THEN
						type := parameter0(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType;
						type := type.resolved;
						IF type IS SyntaxTree.PointerType THEN
							type := type(SyntaxTree.PointerType).pointerBase.resolved;
						END;
						IF ~(type IS SyntaxTree.RecordType) THEN
							Error(parameter0.position,"must be type with type descriptor");
						END;
					ELSE
						Error(parameter0.position,"is not a type symbol");
					END;
					type := system.addressType;
				(* -------- FLT --------- *)
				ELSIF (id = Global.Flt) & CheckArity(1,1) THEN
					type := system.realType;
					IF IsRealValue(parameter0, r) THEN
						result.SetResolved(SyntaxTree.NewRealValue(position, r, Scanner.None));
					ELSIF CheckIntegerType(parameter0) & IsIntegerValue(parameter0, i0) THEN
						value := ABS(i0);
						IF value # 0 THEN
							i1 := 23;
							IF value >= 2*800000H THEN
								REPEAT value := value DIV 2; INC(i1) UNTIL value < 2*800000H;
							ELSIF value < 800000H THEN
								REPEAT value := 2 * value; DEC(i1) UNTIL value >= 800000H;
							END;
							value := (i1 + 127)*800000H - 800000H + value;
							IF i0 < 0 THEN value := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, value) + {31}); END;
						END;
						result.SetResolved(SyntaxTree.NewRealValue(position, SYSTEM.VAL(REAL, value), Scanner.None));
					END;
				(* ------- CONNECT -------*)
				ELSIF (id = Global.Connect) & (CheckArity(2,3)) THEN
					(*IF ~(currentIsCellNet) THEN
						Error(position, "connection outside activeCells body block");
					END;*)

					IF CheckPortType(parameter0, outPort) & CheckPortType(parameter1, inPort) THEN
						IF (outPort.direction # SyntaxTree.OutPort) THEN Error(parameter0.position,"not an out-port") END;
						IF (inPort.direction # SyntaxTree.InPort) THEN Error(parameter1.position,"not an in-port") END;
					END;

					IF numberActualParameters = 3 THEN
						(*IF ~cellsAreObjects & ~IsIntegerValue(parameter2,i0) & (i0>=0) THEN
							Error(position, "incompatible channel size parameter");
						END;
						*)
						parameter2 := NewConversion(Basic.invalidPosition,parameter2,system.longintType,NIL);
						actualParameters.SetExpression(2,parameter2);
					END;

					activeCellsStatement := TRUE;
				(* ---------- DELEGATE --------*)
				ELSIF (id = Global.Delegate) & (CheckArity(2,2)) THEN
					(*
					IF ~(currentIsCellNet) THEN
						Error(position, "connection delegation outside activeCells body block");
					END;
					*)
					IF ~CheckPortType(parameter1, inPort) THEN
						Error(parameter0.position,"not a port")
					ELSIF ~CheckPortType(parameter0, outPort) THEN
						Error(parameter1.position,"not a port")
					ELSIF (outPort.direction # inPort.direction) THEN
						Error(parameter0.position,"invalid port direction");
					ELSIF outPort.sizeInBits # inPort.sizeInBits THEN
						Error(position, "incompatible port sizes");
					END;
					activeCellsStatement := TRUE;
				(* --------- RECEIVE ---------*)
				ELSIF (id = Global.Receive) & CheckArity(2,3) THEN
					IF ~cellsAreObjects THEN ImportModule(Global.NameChannelModule,position) END;
					IF CheckPortType(parameter0,inPort) & CheckVariable(parameter1) THEN
						IF inPort.direction # SyntaxTree.InPort THEN
							Error(parameter0.position,"not an in-port")
						ELSIF inPort.sizeInBits # system.SizeOf(parameter1.type) THEN
							Error(parameter1.position,"incompatible to port type");
						END;
						IF (numberActualParameters=3) & CheckVariable(parameter2) THEN
							IF ~SameType(parameter2.type, system.integerType) THEN
								Error(parameter2.position,"incompatible to integer type");
							END;
						END;
					END;
				(* --------- SEND ---------*)
				ELSIF (id = Global.Send) & CheckArity(2,2) THEN
					IF ~cellsAreObjects THEN ImportModule(Global.NameChannelModule,position) END;
					IF CheckPortType(parameter0,outPort)  THEN
						IF outPort.direction # SyntaxTree.OutPort THEN
							Error(parameter1.position,"not an out-port")
						ELSIF outPort.sizeInBits # system.SizeOf(parameter1.type) THEN
							Error(parameter1.position,"incompatible to port type");
						ELSE
							parameter1 := NewConversion(position,parameter1,parameter0.type.resolved,NIL);
							actualParameters.SetExpression(1,parameter1);
						END;
					END;
				(* ------- custom builtins ----- *)
				ELSIF id = Global.systemSpecial THEN
					customBuiltin := builtin(SyntaxTree.CustomBuiltin);
					ASSERT(customBuiltin.type IS SyntaxTree.ProcedureType);
					procedureType := customBuiltin.type(SyntaxTree.ProcedureType);
					type := procedureType.returnType;
					IF CheckArity(procedureType.numberParameters, procedureType.numberParameters) THEN (* check parameter count *)
						(* go through all formal parameters *)
						formalParameter := procedureType.firstParameter;
						FOR i := 0 TO actualParameters.Length() - 1 DO
							actualParameter := actualParameters.GetExpression(i);
							IF actualParameter = SyntaxTree.invalidExpression THEN
							ELSIF ~ParameterCompatible(formalParameter,actualParameter) THEN
								Error(position,  "incompatible parameter")
							ELSE
								actualParameter := NewConversion(actualParameter.position, actualParameter, formalParameter.type, NIL)
							END;
							actualParameters.SetExpression(i, actualParameter);
							formalParameter := formalParameter.nextParameter
						END
					END

				ELSE
					Error(position, "builtin not implemented");
					result := SyntaxTree.invalidExpression;
				END;
			END;

			IF result # SyntaxTree.invalidExpression THEN
				type := ResolveType(type);
				IF result.resolved # NIL THEN result.resolved.SetType(type) END;
				result.SetType(type);
			END;

			RETURN result
		END NewBuiltinCallDesignator;

		(** return type guard designator left(type)
			- check if type can be extended (i.e. is no static record)
			- check if type is a type extension of left.type
			- returns new type guard designator
			returns invalidDesignator = invalidExpression if error
		**)
		PROCEDURE NewTypeGuardDesignator(position: Position; original: SyntaxTree.Expression; left: SyntaxTree.Expression; type: SyntaxTree.Type; typeExpression: SyntaxTree.Expression): SyntaxTree.Designator;
		VAR result: SyntaxTree.Designator;
		BEGIN
			result := SyntaxTree.invalidDesignator;

			IF ~IsValidTypeTest(left.type.resolved,type.resolved) THEN
				Error(position, "no type extension of type");
				IF VerboseErrorMessage THEN
					Printout.Info("left",left);
					Printout.Info("type",type);
				END;
			ELSIF ~(left.type.resolved = type.resolved) & ~IsExtensibleDesignator(left) THEN (* left is not extensible *)
				Error(position, "variable cannot be extended");
			ELSIF IsUnsafePointer(left.type) THEN
				Error(position, "forbidden type guard on unsafe pointer");
			ELSE
				result := SyntaxTree.NewTypeGuardDesignator(position,original,left,type);
				result.SetType(type);
				result.SetAssignable(left.assignable);
				result(SyntaxTree.TypeGuardDesignator).SetTypeExpression(typeExpression);
				IF left.resolved # NIL THEN
					IF left.type.resolved.CompatibleTo(type.resolved) THEN
						result.SetResolved (left.resolved)
					ELSE
						Error(position, "unsatisfied type guard");
						result := SyntaxTree.invalidDesignator;
					END;
				END;
			END;
			RETURN result
		END NewTypeGuardDesignator;

		(** check and resolve parameter designator left(expression list)
			- check expression list
			- if one parameter and left is extensible type and parameter contains type declaration then return TypeGuardDesignator
			- elsif left is a procedure type then
				- if left is a built-in procedure then return NewBuiltinCallDesignator
				- else return is a procedure call then return ProcedureCallDesignator
			returns invalidDesignator = invalidExpression if error
		**)
		PROCEDURE ResolveParameterDesignator(designator: SyntaxTree.ParameterDesignator): SyntaxTree.Expression;
		VAR
			parameters: SyntaxTree.ExpressionList;
			left: SyntaxTree.Expression;
			result,expression: SyntaxTree.Expression;
			typeDeclaration: SyntaxTree.TypeDeclaration;
			type, expressionType: SyntaxTree.Type;

			PROCEDURE BaseType(type: SyntaxTree.Type): SyntaxTree.Type;
			BEGIN
				type := type.resolved;
				WHILE (type # NIL) & (type IS SyntaxTree.MathArrayType) DO
					type := Resolved(type(SyntaxTree.MathArrayType).arrayBase);
				END;
				RETURN type
			END BaseType;

		BEGIN
			IF Trace THEN D.Str("ResolveParameterDesignator"); D.Ln; END;
			result := SyntaxTree.invalidDesignator;
			left := ResolveExpression(designator.left);
			IF left # SyntaxTree.invalidDesignator THEN
				parameters := designator.parameters;
				IF ExpressionList(parameters) THEN
					IF (left.type = NIL) THEN
						Error(left.position,"object is not a procedure or cannot be extended");
					ELSIF IsExtensibleDesignator(left) & (parameters.Length()=1) & IsTypeDesignator(parameters.GetExpression(0),typeDeclaration) THEN
						result := NewTypeGuardDesignator(designator.position,designator,left,typeDeclaration.declaredType, parameters.GetExpression(0))
					ELSIF IsUnextensibleRecord(left) & (parameters.Length()=1) & IsTypeDesignator(parameters.GetExpression(0),typeDeclaration) & (typeDeclaration.declaredType.resolved = left.type.resolved) THEN
						result := NewTypeGuardDesignator(designator.position,designator,left,typeDeclaration.declaredType, parameters.GetExpression(0))
					ELSIF (left.type.resolved IS SyntaxTree.ProcedureType) THEN
						IF (left IS SyntaxTree.SymbolDesignator) & (left(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Builtin) THEN
							result := NewBuiltinCallDesignator(designator.position,designator,left(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Builtin),parameters,left,NIL);
						ELSE
							result := NewProcedureCallDesignator(designator.position,designator,left,parameters)
						END
					ELSIF IsTypeDesignator(left,typeDeclaration)  & (parameters.Length()=1) THEN
						expression := parameters.GetExpression(0);
						type := typeDeclaration.declaredType.resolved;
						expressionType := BaseType(expression.type); (* type or base type of math array, if applicable *)
						IF ((type IS SyntaxTree.NumberType) OR (type IS SyntaxTree.AddressType) OR (type IS SyntaxTree.SizeType)) &
							((expressionType IS SyntaxTree.NumberType) OR (expressionType IS SyntaxTree.AddressType) OR (expressionType IS SyntaxTree.SizeType)
							OR (expressionType IS SyntaxTree.EnumerationType)
							) OR ((type IS SyntaxTree.SetType) & (expressionType IS SyntaxTree.SetType)) THEN
							IF ((type IS SyntaxTree.AddressType) OR (type IS SyntaxTree.IntegerType) & (~type(SyntaxTree.IntegerType).signed)) & (expressionType IS SyntaxTree.FloatType) THEN
								Error(left.position,"invalid unsigned type in explicit conversion");
							ELSE
								result := NewConversion(designator.position,expression,typeDeclaration.declaredType,left);
								result.SetOriginal(designator);
							END;
						ELSE
							Error(left.position,"invalid type in explicit conversion");
						END;
					ELSE
						Error(left.position,"called object is not a procedure or cannot be extended");
						IF VerboseErrorMessage THEN Printout.Info("designator",designator); Printout.Info("left",left) END;
						result := SyntaxTree.invalidDesignator;
					END;
				ELSE
					result := SyntaxTree.invalidDesignator
				END;
			END;
			RETURN result;
		END ResolveParameterDesignator;

		(** check dereference designator left^
			- check if left is pointer type or left is object type
			- return new dereference designator with type = left.baseType.type (if appropriate)
			with error handling
			returns invalidDesignator = invalidExpression if error
		**)
		PROCEDURE NewDereferenceDesignator(position: Position; original: SyntaxTree.Expression; left: SyntaxTree.Expression): SyntaxTree.Designator;
		VAR type: SyntaxTree.Type; result: SyntaxTree.Designator;
		BEGIN
			result := SyntaxTree.invalidDesignator;
			type := left.type;
			IF (type # NIL) & ((type.resolved IS SyntaxTree.PointerType)) THEN
				type := type.resolved(SyntaxTree.PointerType).pointerBase;
				result := SyntaxTree.NewDereferenceDesignator(position,original,left);
				result.SetAssignable(TRUE);
				result.SetType(type);
				result.SetHidden(left.isHidden);
			ELSIF (type # NIL) & (type.resolved IS SyntaxTree.ArrayType) & (type.resolved(SyntaxTree.ArrayType).form = SyntaxTree.SemiDynamic) THEN
				type := type.resolved;
				result := SyntaxTree.NewDereferenceDesignator(position,original,left);
				result.SetAssignable(TRUE);
				result.SetType(type);
				result.SetHidden(left.isHidden);
			ELSIF (type # NIL) & (type.resolved IS SyntaxTree.CellType) THEN
				result := SyntaxTree.NewDereferenceDesignator(position,original,left);
				result.SetAssignable(TRUE);
				result.SetType(type);
				result.SetHidden(left.isHidden);
			ELSE
				Error(position, "dereference on no pointer");
				IF VerboseErrorMessage THEN
					Printout.Info("pointer", type);
					Printout.Info("scope", currentScope);
				END;
			END;
			RETURN result
		END NewDereferenceDesignator;

		(** check supercall designator left^
			- if left is symbol designator with procedure symbol containing non-nil supermethod then
				- return new supercall designator with type = left.type
			with error handling
		**)
		PROCEDURE NewSupercallDesignator(position: Position;original: SyntaxTree.Designator;  left: SyntaxTree.Designator): SyntaxTree.Designator;
		VAR result: SyntaxTree.Designator; symbol: SyntaxTree.Symbol; procedure: SyntaxTree.Procedure;
			objectScope: SyntaxTree.Scope;
		BEGIN
			result := SyntaxTree.invalidDesignator;
			IF left = SyntaxTree.invalidDesignator THEN
				(* error already handled *)
			ELSIF left IS SyntaxTree.SymbolDesignator THEN
				symbol := left(SyntaxTree.SymbolDesignator).symbol;
				ASSERT(symbol # SyntaxTree.invalidSymbol);
				IF symbol IS SyntaxTree.Procedure THEN
					procedure := symbol(SyntaxTree.Procedure);
					objectScope := currentScope;
					WHILE (objectScope # NIL) & ~(objectScope IS SyntaxTree.RecordScope) DO
						objectScope := objectScope.outerScope;
					END;
					IF (left.left = NIL) OR ~
						(
						(left.left IS SyntaxTree.SelfDesignator) OR
						(left.left IS SyntaxTree.DereferenceDesignator)
						& (left.left(SyntaxTree.Designator).left # NIL)
						& (left.left(SyntaxTree.Designator).left IS SyntaxTree.SelfDesignator)) OR (procedure.scope # objectScope)  THEN
						Error(position, "procedure not in immediate object scope");
						IF VerboseErrorMessage THEN
							Printout.Info("left.left",left.left);
						END;
					ELSIF procedure.super # NIL THEN
						result := SyntaxTree.NewSupercallDesignator(position,original,left);
						result.SetType(left.type.resolved)
					ELSE
						Error(position, "no supermethod for this procedure");
					END;
				ELSE
					Error(position, "symbol is not a procedure");
				END;
			ELSE
				Error(position, "is no symbol designator");
			END;

			RETURN result
		END NewSupercallDesignator;

		(** check and semantically resolve arrow designator left^
			- if left is procedure type -> result := SupercallDesignator
			- else result :=  DereferenceDesignator
			returns result via global variable resolvedExpression
			error handling deferred to procedures SupercallDesignator and DereferenceDesignator
		**)
		PROCEDURE ResolveArrowDesignator(arrowDesignator: SyntaxTree.ArrowDesignator): SyntaxTree.Expression;
		VAR left: SyntaxTree.Designator;
		BEGIN
			IF Trace THEN D.Str("ResolveArrowDesignator"); D.Ln; END;
			left := ResolveDesignator(arrowDesignator.left);
			IF left # NIL THEN
				IF (left.type = NIL) THEN
					Error(arrowDesignator.position,"Invalid arrow designator");
				ELSIF (left.type.resolved # NIL) & (left.type.resolved IS SyntaxTree.ProcedureType) THEN
					RETURN NewSupercallDesignator(arrowDesignator.position,arrowDesignator,left);
				ELSE
					IF IsPointerToObject(left.type) THEN
						(* Warning(arrowDesignator.position,  "forbidden dereference on object"); *)
					END;
					RETURN NewDereferenceDesignator(arrowDesignator.position,arrowDesignator,left)
				END
			END;
			RETURN arrowDesignator;
		END ResolveArrowDesignator;

		(** check and return expression
			- if expression has no type then resolve expression
			- resulting expression is exchanged via global variable "resolvedExpression" which makes this mechanism thread-unsafe
			- return result
		**)
		PROCEDURE ResolveExpression*(x: SyntaxTree.Expression): SyntaxTree.Expression;
		VAR result: SyntaxTree.Expression; subtype: LONGINT; type: SyntaxTree.Type; pos: WORD;
		BEGIN
			IF (x = NIL) OR (x = SyntaxTree.invalidExpression) OR (x.type # NIL) THEN RETURN x END;
			pos := x.position.start;
			IF ~(x IS SyntaxTree.BuiltinCallDesignator) THEN
				x.SetType(SyntaxTree.invalidType);
			END;
			result := x;
			WITH x:
			| SyntaxTree.ResultDesignator DO result := ResolveResultDesignator(x)
			| SyntaxTree.SelfDesignator DO result := ResolveSelfDesignator(x)
			| SyntaxTree.TypeGuardDesignator DO result := x;
			| SyntaxTree.SymbolDesignator DO result := x;
			| SyntaxTree.BuiltinCallDesignator DO result := ResolveBuiltinCallDesignator(x)
			| SyntaxTree.ProcedureCallDesignator DO
				x.SetType(x.left.type.resolved(SyntaxTree.ProcedureType).returnType);
			| SyntaxTree.BracketDesignator DO result := ResolveBracketDesignator(x)
			| SyntaxTree.ArrowDesignator DO result := ResolveArrowDesignator(x)
			| SyntaxTree.ParameterDesignator DO result := ResolveParameterDesignator(x)
			| SyntaxTree.SelectorDesignator DO result := ResolveSelectorDesignator(x)
			| SyntaxTree.IdentifierDesignator DO result := ResolveIdentifierDesignator(x)
			| SyntaxTree.TensorRangeExpression DO x.SetType(NIL);
			| SyntaxTree.RangeExpression DO result := ResolveRangeExpression(x)
			| SyntaxTree.BinaryExpression DO result := ResolveBinaryExpression(x)
			| SyntaxTree.UnaryExpression DO result := ResolveUnaryExpression(x)
			| SyntaxTree.MathArrayExpression DO result := ResolveMathArrayExpression(x)
			| SyntaxTree.Set DO result := ResolveSet(x)
			| SyntaxTree.BooleanValue DO x.SetType(system.booleanType);
			| SyntaxTree.IntegerValue DO x.SetType(Global.GetIntegerType(system,x.value));
			| SyntaxTree.CharacterValue DO x.SetType(system.characterType);
			| SyntaxTree.SetValue DO
				x.SetType(system.setType);
			| SyntaxTree.MathArrayValue DO
				x.SetType(SyntaxTree.invalidType)
			| SyntaxTree.RealValue DO
				subtype := x.subtype;
				IF subtype = Scanner.Real THEN
					type := system.realType
				ELSIF subtype = Scanner.Longreal THEN
					type := system.longrealType
				ELSE
					HALT(100)
				END;
				x.SetType(type);
			| SyntaxTree.ComplexValue DO
					subtype := x.subtype;
				IF subtype = Scanner.Real THEN
					type := system.complexType
				ELSIF subtype = Scanner.Longreal THEN
					type := system.longcomplexType
				ELSE
					HALT(100)
				END;
				x.SetType(type);
			| SyntaxTree.StringValue DO
				x.SetType(ResolveType(SyntaxTree.NewStringType(x.position,system.characterType,x.length)));
			| SyntaxTree.NilValue DO
				x.SetType(system.nilType);
			| SyntaxTree.EnumerationValue DO
				x.SetType(currentScope(SyntaxTree.EnumerationScope).ownerEnumeration);
			| SyntaxTree.InlineCallDesignator DO
				ResolveStatementBlock(x.block);
			END;	(* no other case allowed *)

			IF currentIsRealtime THEN
				IF (result.type # NIL) & ~result.type.resolved.isRealtime THEN
					Error(x.position,"forbidden non-realtime expression in realtime procedure");
				END;
			END;
			(* designator modifiers for backends if they support it ...*)
			WITH x: SyntaxTree.Designator DO
				IF (x.modifiers # NIL) THEN
					WITH result: SyntaxTree.Designator DO
						result.SetModifiers(x.modifiers);
						CheckModifiers(result.modifiers, FALSE);
					ELSE (* error case *)
					END;
				END;
			ELSE
			END;

			RETURN result;
		END ResolveExpression;

		(**
			check expression to be constant expression
			- resolve expression
			- if valid then check that of value type
			report error and return invalidExpression if anything fails
		**)
		PROCEDURE ConstantExpression(expression: SyntaxTree.Expression): SyntaxTree.Expression;
		VAR position: Position;
		BEGIN
			position := expression.position;
			expression := ResolveExpression(expression);
			IF expression = SyntaxTree.invalidExpression THEN (* error already reported *)
			ELSIF (expression.resolved = NIL) THEN
				Error(position, "expression is not constant");
				IF VerboseErrorMessage THEN Printout.Info("expression",expression); END;
				expression := SyntaxTree.invalidExpression;
			END;
			RETURN expression
		END ConstantExpression;

		(** check expression to be constant integer
			- resolve expresssion
			- if valid then check that of integer value type
			report error and return invalidExpression if anything fails
		**)
		PROCEDURE ConstantInteger(expression: SyntaxTree.Expression): SyntaxTree.Expression;
		VAR position: Position;
		BEGIN
			position := expression.position;
			expression := ResolveExpression(expression);
			IF expression = SyntaxTree.invalidExpression THEN (* error already reported *)
			ELSIF (expression.resolved = NIL) OR ~(expression.resolved IS SyntaxTree.IntegerValue) THEN
				expression := SyntaxTree.invalidExpression;
				Error(position, "expression is not a constant integer");
			END;
			RETURN expression
		END ConstantInteger;

		(** check expression as positive (>=0) constant integer
			- resolve expression
			- if valid then check that integer value
			- if integer value then check that value >= 0
			report error and return invalidExpression if anything fails
		**)
		PROCEDURE ConstantIntegerGeq0(expression: SyntaxTree.Expression): SyntaxTree.Expression;
		VAR position: Position;
		BEGIN
			position := expression.position;
			expression := ConstantExpression(expression);
			IF expression = SyntaxTree.invalidExpression THEN
				(* error already reported *)
			ELSIF  (expression.resolved = NIL) OR ~(expression.resolved IS SyntaxTree.IntegerValue) THEN
				Error(position, "expression is not integer valued");
				expression := SyntaxTree.invalidExpression
			ELSIF (expression.resolved(SyntaxTree.IntegerValue).value <0) THEN
				Error(position, "integer is not greater or equal zero");
			END;
			RETURN expression
		END ConstantIntegerGeq0;

		(** check expression as condition
			- resolve expression
			- if valid expression then check that result type is boolean
			report error and return invalidExpression if anything fails
		**)
		PROCEDURE ResolveCondition(expression: SyntaxTree.Expression): SyntaxTree.Expression;
		VAR position: Position;
		BEGIN
			position := expression.position;
			expression := ResolveExpression(expression);
			IF expression = SyntaxTree.invalidExpression THEN (* error already reported *)
			ELSIF (expression.type = NIL) OR ~(expression.type.resolved IS SyntaxTree.BooleanType) THEN
				expression := SyntaxTree.invalidExpression;
				Error(position, "expression is not boolean");
			END;
			RETURN expression
		END ResolveCondition;

		(*** symbols ***)

		PROCEDURE ResolveSymbol*(x: SyntaxTree.Symbol);
		BEGIN
			WITH x:
			| SyntaxTree.TypeDeclaration DO ResolveTypeDeclaration(x)
			| SyntaxTree.Constant DO ResolveConstant(x)
			| SyntaxTree.Parameter DO ResolveParameter(x)
			| SyntaxTree.Variable DO ResolveVariable(x)
			| SyntaxTree.Operator DO ResolveOperator(x)
			| SyntaxTree.Procedure DO ResolveProcedure(x)
			| SyntaxTree.Alias DO ResolveAlias(x)
			| SyntaxTree.Builtin DO ResolveBuiltin(x)
			| SyntaxTree.Import DO ResolveImport(x)
			END;
		END ResolveSymbol;

		(** check a symbol
			- check visibility flags (symbols within procedure scope (direct or indirect) cannot be exported)
		**)
		PROCEDURE CheckSymbolVisibility(symbol: SyntaxTree.Symbol);
		VAR scope: SyntaxTree.Scope;
		BEGIN
			(* visibility *)
			scope := symbol.scope;
			WHILE (scope # NIL) & ~(scope IS SyntaxTree.ProcedureScope) DO
				scope := scope.outerScope;
			END;
			IF (scope # NIL) THEN (* symbol (directly or indirectly) in procedure scope *)
				IF (symbol.access * SyntaxTree.Public # {}) & (~(symbol IS SyntaxTree.Procedure) OR  ~symbol(SyntaxTree.Procedure).isBodyProcedure & ~symbol(SyntaxTree.Procedure).isConstructor & ~symbol(SyntaxTree.Procedure).isFinalizer)  THEN
					Error(symbol.position,"cannot be exported");
					IF VerboseErrorMessage THEN
						Printout.Info("symbol",symbol);
					END;
				END;
			END;
		END CheckSymbolVisibility;

				(** Check if a node has already been resolved. If not then mark as currently being resolved.
			If node is currently being resolved then emit a cyclic definition error.
			Return TRUE only if node is fully resolved.
		**)
		PROCEDURE SymbolNeedsResolution(x: SyntaxTree.Symbol): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			IF SyntaxTree.Resolved IN x.state THEN
				result := FALSE
			ELSIF SyntaxTree.BeingResolved IN x.state THEN
				Error(x.position,"cyclic definition");
				result := FALSE;
			ELSE
				result := TRUE;
				x.SetState(SyntaxTree.BeingResolved)
			END;
			RETURN result
		END SymbolNeedsResolution;

		(** check and resolve a type declaration symbol = Type
			- set type to declaration type
				-> the type of a type declaration is NOT the declared type but the "declaration" type.
					This is so because the type declaration itself does not have a type but it only stands for a type.
					In the implementation of the compiler this made a lot much easier.
			- resolve and set declared type
			- check symbol
		**)
		PROCEDURE ResolveTypeDeclaration(typeDeclaration: SyntaxTree.TypeDeclaration);
		VAR prevScope: SyntaxTree.Scope;
		BEGIN
			IF Trace THEN D.Str("ResolveTypeDeclaration "); D.Str0(typeDeclaration.name);  D.Ln;  END;
			IF SymbolNeedsResolution(typeDeclaration) THEN
				typeDeclaration.SetState(SyntaxTree.Resolved);
				prevScope := currentScope;
				currentScope := typeDeclaration.scope;
				typeDeclaration.SetType(SyntaxTree.typeDeclarationType);
				typeDeclaration.SetDeclaredType(ResolveType(typeDeclaration.declaredType));
				CheckSymbolVisibility(typeDeclaration);
				typeDeclaration.SetState(SyntaxTree.Resolved);
				currentScope := prevScope;
			END;
		END ResolveTypeDeclaration;

		(** check and resolve a constant declaration symbol = (constant) expression
			- check expression
			- set type and value
			- check symbol
		**)
		PROCEDURE ResolveConstant(constant: SyntaxTree.Constant);
		VAR
			expression: SyntaxTree.Expression;
			type: SyntaxTree.Type;
			name: Basic.SegmentedName;
			replacement: Replacement;
		BEGIN
			IF Trace THEN D.Str("ResolveConstant "); D.Str0(constant.name);  D.Ln;  END;
			IF SymbolNeedsResolution(constant) THEN
				expression := constant.value;
				IF replacements # NIL THEN
					Global.GetSymbolSegmentedName(constant, name);
					replacement := replacements;
					WHILE (replacement # NIL) & (replacement.name # name) DO
						replacement := replacement.next;
					END;
					IF replacement # NIL THEN
						InfoSS(constant.position, "replacing constant", constant.name);
						(*
						NEW(stringReader, Strings.Length(replacement.string^));
						stringReader.Set(replacement.string^);
						NEW(scanner, replacement.string^, stringReader,0, diagnostics);
						NEW(parser, scanner, diagnostics);
						expression := parser.Expression();
						*)
						expression := replacement.expression;
						replacement.used := TRUE;
					END;
				END;

				constant.SetType(SyntaxTree.invalidType);
				expression := ConstantExpression(expression);
				ASSERT(expression.type # NIL);
				type := expression.type.resolved;
				constant.SetType(type);
				constant.SetValue(expression);
				CheckSymbolVisibility(constant);
				constant.SetState(SyntaxTree.Resolved);
			END;
		END ResolveConstant;

		PROCEDURE AdaptStackAlignment(procedure: SyntaxTree.Procedure; alignment: LONGINT);
		VAR procedureAlignment: LONGINT;

			PROCEDURE LCM(a0,b0: LONGINT): LONGINT;
			(* least common multiple *)
			VAR a,b: LONGINT;
			BEGIN
				a := a0; b := b0;
				WHILE (a # b) DO
					IF a < b THEN a := a+a0
					ELSE b := b + b0
					END;
				END;
				RETURN a
			END LCM;

		BEGIN
			IF alignment > 1 THEN
				procedureAlignment := procedure.type(SyntaxTree.ProcedureType).stackAlignment;
				IF (procedureAlignment > 1) THEN
					alignment := LCM(alignment, procedureAlignment);
				END;
				procedure.type(SyntaxTree.ProcedureType).SetStackAlignment(alignment);
			END;
		END AdaptStackAlignment;

		(** check and resolve a variable / field
			- check and set type
			- negative check on open array type
			- check symbol
		**)
		PROCEDURE ResolveVariable(variable: SyntaxTree.Variable);
		VAR modifiers: SyntaxTree.Modifier; value: Basic.Integer; position: Position; pointerType: SyntaxTree.PointerType;
		BEGIN
			IF Trace THEN D.Str("ResolveVariable "); D.Str0(variable.name);  D.Ln;  END;
			IF SymbolNeedsResolution(variable) THEN

				modifiers := variable.modifiers;
				(*
				flags := Flags(variable.modifiers,{SyntaxTree.UntracedFlag, SyntaxTree.AlignedFlag, SyntaxTree.FixedFlag});
				variable.AddFlags(flags);
				*)
				variable.SetType(ResolveType(variable.type));
				IF variable.type.resolved IS SyntaxTree.ArrayType THEN
					IF variable.type.resolved(SyntaxTree.ArrayType).length = NIL THEN
						Error(variable.position,"forbidden open array variable");
					END;
				END;
				CheckSymbolVisibility(variable);
				IF HasFlag(modifiers, Global.NameUntraced,position) THEN
					variable.SetUntraced(TRUE);
					IF ~ContainsPointer(variable.type) THEN
						IF VerboseErrorMessage THEN Printout.Info("variable",variable); Printout.Info("variable.type",variable.type.resolved); END;
						Error(position, "untraced flag on non-pointer variable");
					END;
				END;
				IF HasValue(modifiers, Global.NameAligned,position, value) THEN
					IF (variable.scope IS SyntaxTree.ProcedureScope) THEN
						IF ~PowerOf2(value) THEN
							Error(position, "forbidden alignment - must be power of two");
						ELSE
							AdaptStackAlignment(variable.scope(SyntaxTree.ProcedureScope).ownerProcedure, LONGINT (value)); (* TODO: fix explicit integer truncation *)
						END;
					END;
					variable.SetAlignment(FALSE,LONGINT(value)); (* TODO: fix explicit integer truncation *)
				ELSIF HasValue(modifiers, Global.NameFixed,position, value) THEN
					IF (variable.scope IS SyntaxTree.ProcedureScope) THEN
						Error(position, "fixed position not possible in procedure");
					END;
					variable.SetAlignment(TRUE,LONGINT(value)); (* TODO: fix explicit integer truncation *)
				ELSIF HasValue(modifiers, Global.NameFictive, position, value) THEN
					IF (variable.scope IS SyntaxTree.ProcedureScope) THEN
						Error(position,"fictive offset not possible in procedure");
					END;
					variable.SetFictive(LONGINT (value)); (* TODO: fix explicit integer truncation *)
					variable.SetOffset(LONGINT(value)*system.dataUnit); (* TODO: fix explicit integer truncation *)
					IF ContainsPointer(variable.type) THEN variable.SetUntraced(TRUE) END;
				END;
				IF HasFlag(modifiers, Global.NameRegister, position) THEN variable.PreferRegister(TRUE) END;
				IF variable.type.resolved IS SyntaxTree.CellType THEN
					IF HasValue(modifiers, Global.NameCodeMemorySize, position, value) THEN END;
					IF HasValue(modifiers, Global.NameDataMemorySize, position, value) THEN END;
				END;
				CheckModifiers(modifiers, ~InCellNetScope(variable.scope) & ~(variable.type.resolved IS SyntaxTree.CellType) & ~(variable.type.resolved IS SyntaxTree.PortType));
				IF variable.initializer # NIL THEN
					variable.SetInitializer (CompatibleConversion (variable.initializer.position, ResolveExpression(variable.initializer), variable.type));
				END;

				IF (variable.type.resolved IS SyntaxTree.CellType) (*& (cellsAreObjects)*) THEN
					pointerType := SyntaxTree.NewPointerType(variable.position, variable.scope);
					pointerType.SetPointerBase(variable.type);
					pointerType.SetHidden(TRUE);
					variable.SetType(ResolveType(pointerType));
				END;

				variable.SetState(SyntaxTree.Resolved);
			END;
		END ResolveVariable;

		(** check and resolve a (procedure) parameter
			- check and set type
			- check symbol
			- check parameter kind and set read-only flags if appropriate
		**)
		PROCEDURE ResolveParameter(parameter: SyntaxTree.Parameter);
		VAR modifiers: SyntaxTree.Modifier; expression: SyntaxTree.Expression; position: Position;
		BEGIN
			IF Trace THEN D.Str("ResolveParameter "); D.Str0(parameter.name);  D.Ln;  END;
			IF SymbolNeedsResolution(parameter) THEN
				modifiers := parameter.modifiers;
				parameter.SetType(ResolveType(parameter.type));
				ASSERT(parameter.type.resolved # NIL);
				CheckSymbolVisibility(parameter);
				IF parameter.defaultValue # NIL THEN
					IF parameter.kind # SyntaxTree.ValueParameter THEN
						Error(parameter.position,"forbidden default value on non-value parameter");
					ELSE
						expression := ConstantExpression(parameter.defaultValue);
						IF CompatibleTo(system,expression.type, parameter.type) THEN
							expression := NewConversion(expression.position, expression, parameter.type, NIL);
							parameter.SetDefaultValue(expression);
						END;
					END;
				END;
				IF (parameter.kind = SyntaxTree.ValueParameter) & IsMathArrayType(parameter.type) & (parameter.type.resolved(SyntaxTree.MathArrayType).form # SyntaxTree.Static) THEN
					Error(parameter.position, "forbidden value parameter of math array type ");
				END;

				IF HasFlag(modifiers, Global.NameUntraced,position) THEN
					parameter.SetUntraced(TRUE);
					IF ~ContainsPointer(parameter.type) THEN
						IF VerboseErrorMessage THEN Printout.Info("parameter",parameter); Printout.Info("parameter.type",parameter.type.resolved); END;
						Error(position, "untraced flag on non-pointer variable");
					END;
				END;
				IF HasFlag(modifiers, Global.NameRegister,position) THEN
					parameter.PreferRegister(TRUE);
				END;
				IF HasFlag(modifiers, Global.NameMovable,position) THEN
					parameter.SetMoveable(TRUE);
					IF ~(parameter.type.resolved IS SyntaxTree.AddressType) THEN
						IF VerboseErrorMessage THEN Printout.Info("parameter",parameter); Printout.Info("parameter.type",parameter.type.resolved); END;
						Error(position, "illegal movable flag on non-address variable");
					ELSIF parameter.kind = SyntaxTree.VarParameter THEN
						IF VerboseErrorMessage THEN Printout.Info("parameter",parameter); Printout.Info("parameter.type",parameter.type.resolved); END;
						Error(position, "unnecessary movable flag on variable variable");
					END;
				END;
				CheckModifiers(modifiers, ~InCellNetScope(parameter.scope) & ~(parameter.type.resolved IS SyntaxTree.CellType) & ~(parameter.type.resolved IS SyntaxTree.PortType));
				parameter.SetState(SyntaxTree.Resolved);
			END;
		END ResolveParameter;

		(** check and resolve a procedure (with declaration and implementation scope)
			- check the procedure type
			- check if method (i.e. in record scope), if so then
				- check if (unique) constructor
				- check if (unique) finalizer
				- check if super method available, if so then check signature
			- of not in record scope then negative check on constructor flag
			- of not in record scope then negative check on finalizer flag
			- check declarations (including a delayed implementation check, cf procedure Declarations)
			- check procedure symbol
		**)
		PROCEDURE ResolveProcedure(procedure: SyntaxTree.Procedure);
		VAR super,proc: SyntaxTree.Procedure; record: SyntaxTree.RecordType;
			procedureType: SyntaxTree.ProcedureType;
			selfParameter: SyntaxTree.Parameter; qualifiedIdentifier: SyntaxTree.QualifiedIdentifier;
			qualifiedType: SyntaxTree.QualifiedType;
			value: Basic.Integer;
			modifiers: SyntaxTree.Modifier; recentIsRealtime, recentIsBodyProcedure: BOOLEAN;
			position: Position;
			fp: SyntaxTree.Fingerprint;
		BEGIN

			IF SymbolNeedsResolution(procedure) THEN
				IF Trace THEN D.Str("ResolveProcedure "); D.Str0(procedure.name);  D.Ln;  END;

				IF IsOberonInline(procedure) THEN
					procedure.SetInline(FALSE);
					procedure.SetOberonInline(TRUE);
				END;

				recentIsRealtime := currentIsRealtime;
				recentIsBodyProcedure := currentIsBodyProcedure;
				CheckSymbolVisibility(procedure);

				IF Trace THEN D.Str("undefined"); D.Ln; END;
				procedureType := procedure.type(SyntaxTree.ProcedureType);
				modifiers := procedureType.modifiers;
				IF HasFlag(modifiers, Global.NameWinAPI,position) THEN
					procedureType.SetCallingConvention(SyntaxTree.WinAPICallingConvention)
				ELSIF HasFlag(modifiers, Global.NameC,position) THEN
					procedureType.SetCallingConvention(SyntaxTree.CCallingConvention)
				END;
				IF HasFlag(modifiers, Global.NameInterrupt, position) THEN
					procedureType.SetInterrupt(TRUE);
					procedureType.SetCallingConvention(SyntaxTree.InterruptCallingConvention)
				END;
				IF HasFlag(modifiers, Global.NameNoReturn, position) THEN
					procedureType.SetNoReturn(TRUE);
				END;
				IF HasValue(modifiers, Global.NamePcOffset, position, value) THEN procedureType.SetPcOffset(LONGINT(value)) (* TODO: fix explicit integer truncation *) END;

				IF HasFlag(modifiers,Global.NameNoPAF,position) THEN procedureType.SetNoPAF(TRUE) END;
				IF (procedure.scope IS SyntaxTree.ModuleScope) THEN
					IF HasFlag(modifiers, Global.NameEntry,position) THEN procedure.SetEntry(TRUE);
					ELSIF HasFlag(modifiers, Global.NameExit, position) THEN procedure.SetExit(TRUE);
					END;
				END;
				IF HasValue(modifiers,Global.NameAligned,position,value) THEN procedure.SetAlignment(FALSE,LONGINT(value)) (* TODO: fix explicit integer truncation *)
				ELSIF HasValue(modifiers,Global.NameFixed,position,value) THEN procedure.SetAlignment(TRUE,LONGINT(value)) (* TODO: fix explicit integer truncation *)
				END;
				IF HasValue(modifiers,Global.NameStackAligned, position, value) THEN
					IF ~PowerOf2(value) THEN
						Error(position, "forbidden stack alignment - must be power of two");
					ELSE
						procedureType.SetStackAlignment(LONGINT(value)) (* TODO: fix explicit integer truncation *)
					END;
				END;
				IF HasFlag(modifiers,Global.NameRealtime,position) THEN procedureType.SetRealtime(TRUE) END;
				IF HasFlag(modifiers,Global.NameFinal,position) THEN procedure.SetFinal(TRUE)
				ELSIF HasFlag(modifiers,Global.NameAbstract,position) THEN procedure.SetAbstract(TRUE)
				END;
				IF HasValue(modifiers, Global.NameFingerprint, position, value) THEN
					fp.shallow := value;
					fp.public := value;
					fp.private := value;
					fp.shallowAvailable := TRUE;
					procedure.SetFingerprint(fp);
				END;

				CheckModifiers(modifiers, TRUE);

				modifiers := procedureType.returnTypeModifiers;
				procedureType.SetUntracedReturn(HasFlag(modifiers, Global.NameUntraced, position));
				CheckModifiers(modifiers, TRUE);

				procedure.SetState(SyntaxTree.Resolved);

				FixProcedureType(procedureType);
				currentIsRealtime := procedureType.isRealtime;
				currentIsBodyProcedure := procedure.isBodyProcedure;
				IF  ~system.GenerateParameterOffsets(procedure,FALSE) (* assume that this is no nested procedure, is fixed later otherwise *)
				THEN
					Error(procedure.position,"problems during parameter offset computation");
				END;

				IF procedure.scope IS SyntaxTree.ProcedureScope THEN
					procedure.SetLevel(procedure.scope(SyntaxTree.ProcedureScope).ownerProcedure.level+1);
					IF ~system.GenerateParameterOffsets(procedure,TRUE) THEN
						Error(procedure.position,"problem during parameter offset generation");
					END;
				END;
				IF procedure.scope IS SyntaxTree.RecordScope THEN
					record := procedure.scope(SyntaxTree.RecordScope).ownerRecord;
					procedureType.SetDelegate(TRUE);

					IF (record.pointerType # NIL) & (procedureType.selfParameter = NIL) THEN
						(* add auto-self *)
						selfParameter := SyntaxTree.NewParameter(procedure.position,procedureType,Global.SelfParameterName,SyntaxTree.ValueParameter);
						IF (record.pointerType.typeDeclaration = NIL) THEN
							selfParameter.SetType(record.pointerType);
						ELSE
							qualifiedIdentifier := SyntaxTree.NewQualifiedIdentifier(procedure.position,SyntaxTree.invalidIdentifier,record.pointerType.typeDeclaration.name);
							qualifiedType := SyntaxTree.NewQualifiedType(procedure.position,procedure.scope,qualifiedIdentifier);
							qualifiedType.SetResolved(record.pointerType);
							selfParameter.SetType(qualifiedType);
						END;
						selfParameter.SetAccess(SyntaxTree.Hidden);
					ELSIF (procedureType.selfParameter = NIL) THEN
						selfParameter := SyntaxTree.NewParameter(procedure.position,procedureType,Global.SelfParameterName,SyntaxTree.VarParameter);
						IF (record.typeDeclaration = NIL) THEN
							selfParameter.SetType(record);
						ELSE
							qualifiedIdentifier := SyntaxTree.NewQualifiedIdentifier(procedure.position,SyntaxTree.invalidIdentifier,record.typeDeclaration.name);
							qualifiedType := SyntaxTree.NewQualifiedType(procedure.position,procedure.scope,qualifiedIdentifier);
							qualifiedType.SetResolved(record);
							selfParameter.SetType(qualifiedType);
						END;
						procedureType.SetSelfParameter(selfParameter);
					END;

					(*! constructor information is redundant, we can remove "isConstructor" and repplace by constructor procedure reference *)
					IF procedure.isConstructor THEN
						(*! constructor is always visible, compatibility to paco
						procedure.SetAccess(SyntaxTree.Public+SyntaxTree.Protected+SyntaxTree.Internal);
						*)
						procedure.MarkUsed;
						IF procedureType.returnType # NIL THEN
							Error(procedure.position,"constructor with forbidden return type");
						END;
						proc := procedure.scope.firstProcedure;
						WHILE (proc # NIL) & ((proc = procedure) OR ~(proc.isConstructor)) DO
							proc := proc.nextProcedure;
						END;
						IF proc # NIL THEN
							Error(procedure.position,"duplicate constructor")
						ELSE
							procedure.scope(SyntaxTree.RecordScope).SetConstructor(procedure);
						END;
					END;
					IF procedure.isFinalizer THEN
						procedure.MarkUsed;
						IF procedureType.returnType # NIL THEN
							Error(procedure.position,"finalizer with forbidden return type");
						END;
						IF procedureType.numberParameters # 0 THEN
							Error(procedure.position,"finalizer with formal parameters");
						END;
						proc := procedure.scope.firstProcedure;
						WHILE (proc # NIL) & ((proc = procedure) OR ~(proc.isFinalizer)) DO
							proc := proc.nextProcedure;
						END;
						IF proc # NIL THEN
							Error(procedure.position,"duplicate finalizer")
						ELSE
							procedure.scope(SyntaxTree.RecordScope).SetFinalizer(procedure);
						END;
					END;
					super := FindSuperProcedure(record.recordScope, procedure);
					IF (super # NIL) & SignatureCompatible(procedure.position,procedureType,super.type.resolved(SyntaxTree.ProcedureType)) THEN
						IF (super.isConstructor) & ~(procedure.isConstructor) THEN
							Error(procedure.position,"incompatible signature: non-constructor extends constructor");
						END;
						IF (super.isFinalizer) & ~(procedure.isFinalizer) THEN
							Error(procedure.position,"incompatible signature: non-finalizer extends finalizer");
						END;
						IF super.isFinal THEN
							Error(procedure.position,"forbidden method extending final method");
						END;
						(*
						IF super.access # procedure.access THEN
							Warning(procedure.position, "forbiden visibility mismatch of method and super method");
						END;
						*)
						procedure.SetSuper(super);
						super.SetOverwritten(TRUE);
						procedure.SetAccess(procedure.access+super.access);
						procedure.MarkUsed;
					END;
					IF  ~system.GenerateParameterOffsets(procedure,FALSE) (* assume that this is no nested procedure, is fixed later otherwise *)
					THEN
						Error(procedure.position,"problems during parameter offset computation");
					END;
				ELSIF procedure.scope IS SyntaxTree.CellScope THEN (* allowed to be constructor *)
					IF cellsAreObjects THEN
						procedureType.SetDelegate(TRUE);
					END;
					IF procedure.isConstructor THEN
						procedure.scope(SyntaxTree.CellScope).SetConstructor(procedure);
					END;
				ELSIF procedure.isConstructor THEN
					Error(procedure.position,"procedure illegaly marked as initializer - not in object scope");
				END;
				Declarations(procedure.procedureScope, FALSE, {0,1});
				(* body resolution part done as late fix of the procedure type *)
				procedure.SetState(SyntaxTree.Resolved);
				currentIsRealtime := recentIsRealtime;
				currentIsBodyProcedure := recentIsBodyProcedure;
			END;
		END ResolveProcedure;

		PROCEDURE ResolveAlias(x: SyntaxTree.Alias);
		BEGIN
			x.SetExpression(ResolveExpression(x.expression));
		END ResolveAlias;

		(**
			a builtin procedure is a global item that may not be modified locally
			instead the resolving of builtin procedure calls are done in the esignator
		**)
		PROCEDURE ResolveBuiltin(builtinProcedure: SyntaxTree.Builtin);
		VAR type: SyntaxTree.Type;
		BEGIN
			type := ResolveType(builtinProcedure.type);
		END ResolveBuiltin;

		(* nopov *)
		(** check and resolve operator
			- operators are first checked as procedures
			- then additional operator-specific checks are done
			- note that only module-scope operators are checked here
				(operators in a record scope are only allowed in the context of
				array-structured object types and checked in 'ResolveArrayStructure')
			- also note that inter-operator conformity is not checked here
		**)
		PROCEDURE ResolveOperator(operator: SyntaxTree.Operator);
		VAR
			procedureType: SyntaxTree.ProcedureType;
			leftType, rightType: SyntaxTree.Type;
			identifierNumber: LONGINT;  position: Position;
			hasReturnType, mustBeUnary, mustBeBinary, mustReturnBoolean, mustReturnInteger, mustHaveEquitypedOperands: BOOLEAN;
			modifiers: SyntaxTree.Modifier;

			(** whether a type is locally defined in the current module scope
			for arrays, the base type must be locally defined **)
			PROCEDURE IsLocallyDefined(type: SyntaxTree.Type): BOOLEAN;
			BEGIN
				IF type = NIL THEN
					RETURN FALSE
				ELSIF (type.typeDeclaration # NIL) & (type.typeDeclaration.scope.ownerModule = currentScope.ownerModule) THEN
					RETURN TRUE
				ELSIF (type.resolved IS SyntaxTree.ArrayType) THEN
					RETURN IsLocallyDefined(type.resolved(SyntaxTree.ArrayType).arrayBase)
				ELSIF (type.resolved IS SyntaxTree.MathArrayType) THEN
					RETURN IsLocallyDefined(type.resolved(SyntaxTree.MathArrayType).arrayBase)
				ELSE
					RETURN FALSE
				END
			END IsLocallyDefined;
		BEGIN
			ASSERT(operator.type IS SyntaxTree.ProcedureType);
			procedureType := operator.type(SyntaxTree.ProcedureType);

			modifiers := procedureType.modifiers;
			IF HasFlag(modifiers, Global.NameDynamic, position) THEN operator.SetDynamic(TRUE) END;
			CheckModifiers(modifiers, TRUE);

			ResolveProcedure(operator);

			IF operator.scope IS SyntaxTree.RecordScope THEN
			ELSIF operator.scope IS SyntaxTree.ModuleScope THEN
				identifierNumber := Global.GetSymbol(operator.scope.ownerModule.case, operator.name);

				IF identifierNumber = -1 THEN
					Error(operator.position, "operator with unknown identifier")
				ELSIF ~system.operatorDefined[identifierNumber] THEN
					Error(operator.position, "identifier may not be used for operator")
				ELSE
					IF procedureType.numberParameters < 1 THEN
						Error(operator.position, "operator without operand");
					ELSIF procedureType.numberParameters > 2 THEN
						Error(operator.position, "operator with more than two operands");
					ELSE
						(* determine operand types *)
						leftType := procedureType.firstParameter.type;
						IF procedureType.numberParameters > 1 THEN
							rightType := procedureType.firstParameter.nextParameter.type
						ELSE
							rightType := NIL
						END;

						(* check whether at least one of the operand types is declared in the current module (this check is skipped for the module FoxArrayBase) *)
						IF (currentScope.ownerModule.name # Global.ArrayBaseName) & (currentScope.ownerModule.name # Global.ComplexNumbersName) THEN
							IF ~(IsLocallyDefined(leftType) OR IsLocallyDefined(rightType)) THEN
								Error(operator.position, "none of the operands is declared in the same module")
							END
						END;

						(* TODO: refine the checks, think about how restrictive the checks should be
						requiring operators such as "&", "OR", "~" to return Booleans, makes overloading for them almost pointless.
						They might be used for intersection, union, complement of custom object types *)

						(* defaults *)
						hasReturnType := TRUE;
						mustBeUnary := FALSE;
						mustBeBinary := FALSE;
						mustReturnBoolean := FALSE;
						mustReturnInteger := FALSE;
						mustHaveEquitypedOperands := FALSE;

						(* operator-specific exceptions *)
						CASE identifierNumber OF
						| Scanner.Equal, Scanner.Unequal, Scanner.Less, Scanner.LessEqual, Scanner.Greater, Scanner.GreaterEqual:
							mustBeBinary := TRUE; mustReturnBoolean := TRUE;
						| Scanner.DotEqual, Scanner.DotUnequal, Scanner.DotLess, Scanner.DotLessEqual, Scanner.DotGreater, Scanner.DotGreaterEqual:
							mustBeBinary := TRUE
						| Scanner.In: mustBeBinary := TRUE; mustReturnBoolean := TRUE
						| Scanner.Is: mustBeBinary := TRUE; mustReturnBoolean := TRUE
						| Scanner.Times: mustBeBinary := TRUE
						| Scanner.TimesTimes: mustBeBinary := TRUE
						| Scanner.DotTimes: mustBeBinary := TRUE
						| Scanner.PlusTimes: mustBeBinary := TRUE
						| Scanner.Slash: mustBeBinary := TRUE
						| Scanner.Backslash: mustBeBinary := TRUE
						| Scanner.DotSlash: mustBeBinary := TRUE
						| Scanner.Div, Scanner.Mod: mustBeBinary := TRUE;
						| Scanner.And, Scanner.Or: mustBeBinary := TRUE;
						| Scanner.Not: mustBeUnary := TRUE
						| Scanner.Plus, Scanner.Minus: (* unary and binary *)
						| Scanner.Becomes: mustBeBinary := TRUE; hasReturnType := FALSE;
						| Scanner.Transpose: mustBeUnary := TRUE;
						| Global.Conversion: mustBeUnary := TRUE; (* TODO: get rid of return type? *)
						| Global.DotTimesPlus: mustBeBinary := TRUE;
						| Global.AtMulDec, Global.AtMulInc: mustBeBinary := TRUE;
						| Global.DecMul, Global.IncMul: mustBeBinary := TRUE;
						| Global.Dec, Global.Inc: hasReturnType := FALSE; (* unary and binary *)
						| Global.Excl, Global.Incl:hasReturnType := FALSE;
						| Global.Abs: mustBeUnary := TRUE;
						| Global.Ash: (* TODO: arity? *)
						| Global.Cap: (* TODO: arity? *)
						| Global.Chr: mustBeUnary := TRUE;
						| Global.Entier: (* TODO: arity? *)
						| Global.EntierH: (* TODO: arity? *)
						| Global.Len: (* unary and binary *)
						| Global.Short, Global.Long: mustBeUnary := TRUE;
						| Global.Max, Global.Min: (* unary and binary *)
						| Global.Odd: (* TODO: arity? *)
						| Global.Sum: (* TODO: arity? *)
						| Global.All: (* TODO: arity? *)
						| Global.Re, Global.Im:
						| Global.Dim: mustBeUnary := TRUE; mustReturnInteger := TRUE;
						| Scanner.Alias:
						| Global.Reshape:
						| Scanner.GreaterGreater, Scanner.LessLess:
							mustBeBinary := TRUE; hasReturnType := FALSE;
						| Scanner.GreaterGreaterQ, Scanner.LessLessQ:
							mustBeBinary := TRUE; mustReturnBoolean := TRUE;
						END;

						(* check parameter count *)
						IF mustBeUnary & (procedureType.numberParameters # 1) THEN
							Error(operator.position,"operator is not unary")
						ELSIF mustBeBinary & (procedureType.numberParameters # 2) THEN
							Error(operator.position,"operator is not binary")
						END;

						(* check parameter types *)
						(* TODO: is this used at all? *)
						IF mustHaveEquitypedOperands & (procedureType.numberParameters = 2) THEN
							leftType := procedureType.firstParameter.type;
							rightType := procedureType.firstParameter.nextParameter.type;
							IF ~leftType.resolved.SameType(rightType.resolved) THEN
								Error(operator.position, "the two operands are not of the same type")
							END
						END;

						(* check return type *)
						IF hasReturnType THEN
							IF procedureType.returnType = NIL THEN
								Error(operator.position, "return type required")
							ELSIF mustReturnBoolean THEN
								IF ~(procedureType.returnType.resolved IS SyntaxTree.BooleanType) THEN
									Error(operator.position,"return type is not Boolean")
								END
							ELSIF mustReturnInteger THEN
								IF ~IsSizeType(procedureType.returnType, system.addressSize) THEN
									Error(operator.position,"return type is no size type")
								END
							END
						ELSIF procedureType.returnType # NIL THEN
							Error(operator.position, "return type not allowed")
						END
					END
				END
			END
		END ResolveOperator;

		PROCEDURE AddImport*(module: SyntaxTree.Module; x: SyntaxTree.Import): BOOLEAN;
		VAR prevScope: SyntaxTree.Scope; prevDiagnostics: Diagnostics.Diagnostics;
		BEGIN
			IF error THEN RETURN FALSE END;
			prevScope := currentScope;
			prevDiagnostics := diagnostics;
			diagnostics := NIL; (* suppress error output *)
			currentScope := module.moduleScope;
			ResolveImport(x);
			IF ~error THEN
				module.moduleScope.AddImport(x);
				x.SetScope(module.moduleScope);
			END;
			currentScope := prevScope;
			diagnostics := prevDiagnostics;
			IF error THEN error := FALSE; RETURN FALSE ELSE RETURN TRUE END;
		END AddImport;

		(** check and resolve import
			- check for name = SYSTEM
			- check for forbidden self import
			- search through global import cache: already imported?
			- check if already imported indirectly
			- import if necessary -> set module and enter into import cache
			- enter re-imports into list of imported modules as non-direct import (if not in direct import list)
			- after this import this direct import and all indirect imports are stored in the current module's import list
		**)
		PROCEDURE ResolveImport(x: SyntaxTree.Import);
		VAR
			module: SyntaxTree.Module;
			moduleScope: SyntaxTree.ModuleScope;
			import,reimport: SyntaxTree.Import;
			filename: FileName;
			prevScope: SyntaxTree.Scope;
		BEGIN
			IF SymbolNeedsResolution(x) THEN
				prevScope := currentScope;
				x.SetType(SyntaxTree.importType);
				moduleScope := currentScope.ownerModule.moduleScope;

				IF (x.moduleName=Global.SystemName) THEN x.SetModule(system.systemModule[Scanner.Uppercase])
				ELSIF (x.moduleName=Global.systemName) THEN x.SetModule(system.systemModule[Scanner.Lowercase])
				ELSIF (x.moduleName=currentScope.ownerModule.name) & (x.context=currentScope.ownerModule.context) THEN
					Error(x.position,"forbidden self import");
				ELSE

					(* search through global import list: already imported ? *)
					IF (x.module = NIL) & (importCache # NIL)  THEN
						import := importCache.ImportByModuleName(x.moduleName,x.context);
					ELSE import := NIL
					END;

					IF x.module # NIL THEN (* already imported indirectly *)
						module := x.module;
					ELSIF import # NIL THEN (* already in module list *)
						module := import.module;
						ASSERT(module # NIL);
						x.SetModule(module);
					ELSE (* must be imported *)
						Global.ModuleFileName(x.moduleName,x.context,filename);
						IF symbolFileFormat # NIL THEN
							module := symbolFileFormat.Import(filename,importCache); (* includes module parsing *)
							IF module = NIL THEN
								ErrorSS(x.position,"could not import",filename);
								IF VerboseErrorMessage THEN
									Printout.Info("import",x)
								END
							ELSE
								(*
								IF ~(SyntaxTree.Resolved IN module.state) THEN
									(*! should rather be done by importer *)
									checker := NewChecker(diagnostics,VerboseErrorMessage,system,symbolFileFormat,importCache);
									checker.importCache := importCache;
									checker.arrayBaseImported := arrayBaseImported;
									checker.global := global;
									checker.Module(module); (* semantic check *)
									error := error OR checker.error;
								END;
								*)
								(*
								ASSERT(SyntaxTree.Resolved IN module.state);
								*)
								x.SetModule(module);
								IF importCache # NIL THEN
									import := SyntaxTree.NewImport(Basic.invalidPosition,x.moduleName,x.moduleName,FALSE);
									import.SetContext(x.context);
									import.SetModule(module);
									importCache.AddImport(import);
								END;
							END;
						ELSE
							ErrorSS(x.position,"no symbol file specified: cannot import",filename);
						END;
					END;
					IF module # NIL THEN (* enter reimports into list of imported modules *)
						IF SELF.module = NIL THEN (* happens in recursive imports *)
						END;
						import := module.moduleScope.firstImport;
						WHILE(import # NIL) DO
							ASSERT(import.moduleName # SyntaxTree.invalidIdentifier);
							ASSERT(currentScope # NIL);
							ASSERT(currentScope.ownerModule # NIL);
							ASSERT(import.context # SyntaxTree.invalidIdentifier);

							IF (import.moduleName=currentScope.ownerModule.name) & (import.context=currentScope.ownerModule.context) THEN
								Error(x.position,"recursive import");
							ELSE
								IF import.context = SyntaxTree.invalidIdentifier THEN import.SetContext(x.context) END;
								reimport := moduleScope.ImportByModuleName(import.moduleName,import.context);
								IF reimport = NIL THEN  (* indirect import *)
									reimport := SyntaxTree.NewImport(Basic.invalidPosition,import.moduleName,import.moduleName,FALSE);
									reimport.SetContext(import.context);
									reimport.SetModule(import.module);
									moduleScope.AddImport(reimport);
									reimport.SetScope(moduleScope);
								ELSE
									ASSERT(import.module # NIL);
									reimport.SetModule(import.module); (* direct or indirect import *)
								END;
							END;
							import := import.nextImport;
						END;
					END;
				END;
				currentScope := prevScope;
				(* ELSE nothing to be done *)
				x.SetState(SyntaxTree.Resolved);
			END;
		END ResolveImport;

		(*** statements ***)

		PROCEDURE ResolveStatement*(x: SyntaxTree.Statement): SyntaxTree.Statement;
		VAR result: SyntaxTree.Statement; pos: WORD;
		BEGIN
			pos := x.position.start;
			IF currentIsUnreachable THEN x.SetUnreachable(TRUE) END;
			activeCellsStatement := FALSE;
			result := x;
			WITH x:
			SyntaxTree.ProcedureCallStatement DO result := ResolveProcedureCallStatement(x)
			| SyntaxTree.Assignment DO result := ResolveAssignment(x)
			| SyntaxTree.CommunicationStatement DO result := ResolveCommunicationStatement(x)
			| SyntaxTree.IfStatement DO result := ResolveIfStatement(x)
			| SyntaxTree.WithStatement DO result := ResolveWithStatement(x)
			| SyntaxTree.CaseStatement DO result := ResolveCaseStatement(x)
			| SyntaxTree.WhileStatement DO result := ResolveWhileStatement(x)
			| SyntaxTree.RepeatStatement DO result := ResolveRepeatStatement(x)
			| SyntaxTree.ForStatement DO result := ResolveForStatement(x)
			| SyntaxTree.LoopStatement DO result := ResolveLoopStatement(x)
			| SyntaxTree.ExitableBlock DO result := ResolveExitableBlock(x)
			| SyntaxTree.ExitStatement DO result := ResolveExitStatement(x)
			| SyntaxTree.ReturnStatement DO result := ResolveReturnStatement(x)
			| SyntaxTree.AwaitStatement DO result := ResolveAwaitStatement(x)
			| SyntaxTree.StatementBlock DO ResolveStatementBlock(x)
			| SyntaxTree.Code DO ResolveCode(x)
			END;
			RETURN result;
		END ResolveStatement;

		(** check and resolve statement sequence
			- check all statements, replace if necessary
		**)
		PROCEDURE StatementSequence(statementSequence: SyntaxTree.StatementSequence);
		VAR i: LONGINT; statement,resolved: SyntaxTree.Statement;
		BEGIN
			IF statementSequence # NIL THEN (* else empty *)
				FOR i := 0 TO statementSequence.Length()-1 DO
					statement := statementSequence.GetStatement(i);
					resolved := ResolveStatement(statement);
					IF (resolved # statement) THEN
						statementSequence.SetStatement(i,resolved);
					END;
				END;
			END;
		END StatementSequence;

		(** check and resolve procedure call statement procedureCall() or procedureCall;
			- check if call is a procedure call designator, if not (procedure type symbol) try to make one out of it
			- check if procedure is callable
			- check return type = NIL (otherwise must be assignment statement)
		**)
		PROCEDURE ResolveProcedureCallStatement(procedureCall: SyntaxTree.ProcedureCallStatement): SyntaxTree.Statement;
		VAR call: SyntaxTree.Designator;
		BEGIN
			IF Trace THEN D.Str("ResolveProcedureCallStatement"); D.Ln; END;
			call := procedureCall.call;
			IF (call # NIL) &  ~(call IS SyntaxTree.ParameterDesignator) & ~(call IS SyntaxTree.ProcedureCallDesignator) & ~(call IS SyntaxTree.BuiltinCallDesignator)  THEN
				IF procedureCall.ignore THEN Error(procedureCall.position, "ignoring non-procedure call") END;
				call := SyntaxTree.NewParameterDesignator(call.position,call,SyntaxTree.NewExpressionList());
			END;

			call := ResolveDesignator(call);

			IF call = SyntaxTree.invalidDesignator THEN
				(* error already handled *)
			ELSIF ~IsCallable(call) THEN
				Error(procedureCall.position,"called object is not a procedure");
			ELSIF call.type # NIL THEN
				IF ~procedureCall.ignore THEN
					Error(procedureCall.position,"calling procedure with non-void return type");
					IF VerboseErrorMessage THEN Printout.Info("call ",call) END;
				END;
			ELSIF procedureCall.ignore THEN
				Error(procedureCall.position,"ignoring procedure call without return value");
			END;
			procedureCall.SetCall(call);
			RETURN procedureCall;
		END ResolveProcedureCallStatement;

		(** check and resolve assignment LHS := RHS
			- resolve LHS and RHS
			- check if assignment operator is found. if yes, return operator call instead of assignment instruction
			- check if assignment is compatible
			- check if LHS is variable (i.e. assignable)
			- convert RHS if necessary
		**)
		PROCEDURE ResolveAssignment(assignment: SyntaxTree.Assignment): SyntaxTree.Statement;
		VAR
			left: SyntaxTree.Designator;
			right, expression: SyntaxTree.Expression;
			procedureCallDesignator: SyntaxTree.ProcedureCallDesignator;
		BEGIN
			right := ResolveExpression(assignment.right);
			assignment.left.SetRelatedRhs(right);
			left := ResolveDesignator(assignment.left);

			IF (left = SyntaxTree.invalidDesignator) OR (right = SyntaxTree.invalidExpression) THEN
				(* error already handled *)
			ELSIF IsIndexOperator(left) & left.assignable THEN
				(* LHS is index write operator call *)
				procedureCallDesignator :=  left(SyntaxTree.ProcedureCallDesignator);
				RETURN SyntaxTree.NewProcedureCallStatement(assignment.position, FALSE, procedureCallDesignator, assignment.outer);
			ELSIF CheckVariable(left) THEN
				expression := NewOperatorCall(assignment.position, NIL, Scanner.Becomes, left, right, NIL);
				IF (expression # NIL) & (expression IS SyntaxTree.ProcedureCallDesignator) THEN
					procedureCallDesignator := expression(SyntaxTree.ProcedureCallDesignator);
					RETURN SyntaxTree.NewProcedureCallStatement(assignment.position, FALSE, procedureCallDesignator, assignment.outer);
				ELSIF AssignmentCompatible(left, right) THEN
					right := NewConversion(right.position, right, left.type.resolved, NIL);
					assignment.SetLeft(left);
					assignment.SetRight(right);
				END
			END;
			RETURN assignment;
		END ResolveAssignment;

		PROCEDURE ResolveCommunicationStatement(communication: SyntaxTree.CommunicationStatement): SyntaxTree.Statement;
		VAR
			left: SyntaxTree.Designator;
			right: SyntaxTree.Expression;
			inPort, outPort: SyntaxTree.PortType;
			expression: SyntaxTree.Expression;
			procedureCallDesignator: SyntaxTree.ProcedureCallDesignator;
		BEGIN
			right := ResolveExpression(communication.right);
			left := ResolveDesignator(communication.left);
			communication.SetLeft(left);
			communication.SetRight(right);

			expression := NewOperatorCall(communication.position, NIL, communication.op, left, right, NIL);
			IF (expression # NIL) & (expression IS SyntaxTree.ProcedureCallDesignator) THEN
				procedureCallDesignator := expression(SyntaxTree.ProcedureCallDesignator);
				RETURN SyntaxTree.NewProcedureCallStatement(communication.position, FALSE, procedureCallDesignator, communication.outer);
			ELSE

				IF ~cellsAreObjects THEN ImportModule(Global.NameChannelModule,communication.position) END;

				IF (left = SyntaxTree.invalidDesignator) OR (right = SyntaxTree.invalidExpression) THEN
					(* error already handled *)
				ELSIF communication.op = Scanner.LessLess THEN (* left is dest *)
					IF (left.type.resolved IS SyntaxTree.PortType) & CheckPortType(left, outPort) THEN (* send *)
						IF outPort.direction # SyntaxTree.OutPort THEN
							Error(left.position,"not an out-port")
						ELSIF outPort.sizeInBits < system.SizeOf(right.type) THEN
							Error(left.position,"incompatible to port type");
						ELSE
							right := NewConversion(communication.position,right,left.type.resolved,NIL);
							communication.SetRight(right)
						END;
					ELSIF (right.type.resolved IS SyntaxTree.PortType) & CheckPortType(right, inPort) THEN (* receive *)
						IF CheckVariable(left) THEN
							IF inPort.direction # SyntaxTree.InPort THEN
								Error(left.position,"not an in-port")
							ELSIF inPort.sizeInBits # system.SizeOf(left.type) THEN
								Error(right.position,"incompatible to port type");
							END;
						END;
					ELSE
						Error(communication.position,"unsupported stream operation");
					END;
				ELSIF (communication.op = Scanner.ExclamationMark)  & CheckPortType(left,outPort)  THEN
					IF outPort.direction # SyntaxTree.OutPort THEN
						Error(left.position,"not an out-port")
					ELSIF outPort.sizeInBits < system.SizeOf(right.type) THEN
						Error(left.position,"incompatible to port type");
					ELSE
						right := NewConversion(communication.position,right,left.type.resolved,NIL);
						communication.SetRight(right)
					END;
				ELSIF (communication.op = Scanner.Questionmark) & CheckPortType(left,inPort) THEN
					IF CheckVariable(right) THEN
						IF inPort.direction # SyntaxTree.InPort THEN
							Error(left.position,"not an in-port")
						ELSIF inPort.sizeInBits # system.SizeOf(right.type) THEN
							Error(right.position,"incompatible to port type");
						END;
					END;
				ELSE
					Error(communication.position, "unsupported operation");
				END;
			END;
			RETURN communication;
		END ResolveCommunicationStatement;

		(** check and resolve if/eslif part
			- check condition
			- check statement sequence
		**)
		PROCEDURE IfPart(ifPart: SyntaxTree.IfPart; VAR true: BOOLEAN);
		VAR prevUnreachable, b: BOOLEAN;
		BEGIN
			prevUnreachable := currentIsUnreachable;
			ifPart.SetCondition(ResolveCondition(ifPart.condition));
			IF IsBooleanValue(ifPart.condition,b) THEN
				IF b=FALSE THEN
					currentIsUnreachable := TRUE
				ELSIF b=TRUE THEN
					true := TRUE
				END;
			END;
			StatementSequence(ifPart.statements);
			currentIsUnreachable := prevUnreachable;
		END IfPart;

		(** check and resolve if statement
			- check if parts and else part statement sequence
		**)
		PROCEDURE ResolveIfStatement(ifStatement: SyntaxTree.IfStatement): SyntaxTree.Statement;
		VAR elsif: SyntaxTree.IfPart; i: LONGINT; ifPartTrue, prevUnreachable: BOOLEAN;
		BEGIN
			prevUnreachable := currentIsUnreachable;
			ifPartTrue := FALSE;
			IfPart(ifStatement.ifPart,ifPartTrue);
			FOR i := 0 TO ifStatement.ElsifParts()-1 DO
				elsif := ifStatement.GetElsifPart(i);
				IfPart(elsif,ifPartTrue);
			END;
			IF ifStatement.elsePart # NIL THEN
				IF ifPartTrue THEN
					currentIsUnreachable := TRUE
				END;
				StatementSequence(ifStatement.elsePart)
			END;
			currentIsUnreachable := prevUnreachable;
			RETURN ifStatement;
		END ResolveIfStatement;

		PROCEDURE WithPart(withPart: SyntaxTree.WithPart; variable: SyntaxTree.Designator);
		VAR
			type,variableType: SyntaxTree.Type;
			withEntry: WithEntry;
			symbol: SyntaxTree.Symbol
		BEGIN
			type := ResolveType(withPart.type);
			withPart.SetType(type);
			variableType := variable.type.resolved;

			WHILE variable IS SyntaxTree.TypeGuardDesignator DO
				variable := variable(SyntaxTree.TypeGuardDesignator).left(SyntaxTree.Designator);
			END;

			IF (type.resolved = SyntaxTree.invalidType) OR (variableType = SyntaxTree.invalidType) THEN (* error already reported *)
			ELSIF ~(type.resolved = variableType) & ~IsExtensibleDesignator(variable) THEN
				Error(variable.position,"is not extensible designator");
			ELSIF ~(variable IS SyntaxTree.SymbolDesignator) (* OR (variable(SyntaxTree.SymbolDesignator).left # NIL) needed ?? *)  THEN
				Error(variable.position,"is no local variable ");
				IF VerboseErrorMessage THEN
					Printout.Info("variable",variable)
				END;
			ELSIF ~IsTypeExtension(variableType, type.resolved) THEN
				Error(type.position,"type does not extend withguarded symbol");
				IF VerboseErrorMessage THEN
					Printout.Info("variable",variable);
					Printout.Info("type",type);
				END;
			ELSIF ~(variable(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Variable)
					& ~(variable(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Parameter) THEN
				Error(variable.position,"withguarded symbol is no variable ");
				IF VerboseErrorMessage THEN
					Printout.Info("variable",variable);
					Printout.Info("type",type);
				END;
			ELSIF (symbol # NIL) & (symbol # variable(SyntaxTree.SymbolDesignator).symbol) THEN
				Error(variable.position,"invalid change of withguarded symbol");
			ELSE
				symbol := variable(SyntaxTree.SymbolDesignator).symbol;
				NEW(withEntry);
				withEntry.previous := withEntries;
				withEntry.symbol := variable(SyntaxTree.SymbolDesignator).symbol;
				withEntry.type := type;
				withEntries := withEntry;
				StatementSequence(withPart.statements);
				withEntries := withEntries.previous;
			END;

		END WithPart;

		(** check and resolve with statement WITH variable: type DO ... END;
			- check type and variable
			- check that variable type is type extension of type
			- check that variable is a variable
			- enter new with scope and enter guardedVariable with same name and reference to variable
			- create if statement:
				WITH variable: type DO ... END; --> IF ~(variable IS type) THEN HALT(withTrap) ELSE ... END;
		**)
		PROCEDURE ResolveWithStatement(withStatement: SyntaxTree.WithStatement): SyntaxTree.Statement;
		VAR i,j: LONGINT; prevScope: SyntaxTree.Scope; variable: SyntaxTree.Designator;
		BEGIN
			prevScope := currentScope;

			variable := ResolveDesignator(withStatement.variable);
			withStatement.SetVariable(variable);

			FOR i := 0 TO withStatement.WithParts()-1 DO
				WithPart(withStatement.GetWithPart(i),variable);
			END;

			FOR i := 0 TO withStatement.WithParts()-1 DO
				FOR j := i+1 TO withStatement.WithParts()-1 DO
					IF IsTypeExtension(withStatement.GetWithPart(i).type, withStatement.GetWithPart(j).type) THEN
						Error(withStatement.GetWithPart(j).position, "unreachable extended type");
					END;
				END;
			END;

			IF withStatement.elsePart # NIL THEN
				StatementSequence(withStatement.elsePart)
			END;
			currentScope := prevScope;
			RETURN withStatement;
		END ResolveWithStatement;

		(** check and resolve case part <<a, b, c..d: StatementSequence>>
			- check expression to be constant or case range expression <<first .. last>> with constants 'first' and 'last' and compatible to type
			- check 'first' < 'last' and no overlaps between different case labels
			- check statement sequence
		**)
		PROCEDURE CasePart(casePart: SyntaxTree.CasePart; type: SyntaxTree.Type; VAR allcases: SyntaxTree.CaseConstant; VAR min,max: Basic.Integer);
		VAR
			i: LONGINT;
			position: Position;
			expression, left, right: SyntaxTree.Expression;
			expressionType: SyntaxTree.Type;
			l, r: Basic.Integer;
			cl, cr: CHAR;
			thiscases: SyntaxTree.CaseConstant;
		BEGIN
			thiscases := NIL;
			FOR i := 0 TO casePart.elements.Length() - 1 DO
				expression := casePart.elements.GetExpression(i);
				position := expression.position;

				(* set context of range *)
				IF expression IS SyntaxTree.RangeExpression THEN
					expression(SyntaxTree.RangeExpression).SetContext(SyntaxTree.CaseGuard)
				END;

				expression := ResolveExpression(expression);

				IF expression = SyntaxTree.invalidExpression THEN
					(* error already reported *)
					expressionType := SyntaxTree.invalidType;

				ELSIF (expression IS SyntaxTree.RangeExpression) THEN
					(* read out 'first' and 'last' *)
					left := expression(SyntaxTree.RangeExpression).first;
					right := expression(SyntaxTree.RangeExpression).last;
					(* guaranteed by ResolveRangeExpression: *)
					ASSERT((left # NIL) & (right # NIL));
					ASSERT(left.type.resolved = right.type.resolved);
					left := CompatibleConversion(left.position, left, type);
					right := CompatibleConversion(right.position, right, type);
					expression(SyntaxTree.RangeExpression).SetFirst(left);
					expression(SyntaxTree.RangeExpression).SetLast(right);
					expressionType := RegularType(position,left.type);
				ELSE
					expression := ConstantExpression(expression);
					expression := CompatibleConversion(expression.position, expression, type);
					(*
					IF IsStringType(expression.type) (*& IsCharacterValue(expression,cl) *) THEN
						left := Global.NewCharacterValue(system,expression.position,cl);
						expression := casePart.elements.GetExpression(i);
						expression.SetResolved(left(SyntaxTree.CharacterValue));
						expression := left
					END;
					*)
					casePart.elements.SetExpression(i,expression);
					left := expression; right := expression;
					expressionType := RegularType(position,expression.type)
				END;

				IF (expressionType = SyntaxTree.invalidType) THEN
				ELSIF ~CompatibleTo(system,expressionType,type) THEN
					Error(position, "inadmissible case label");
					expression := SyntaxTree.invalidExpression;
				ELSE
					l := 0; r := 0;
					IF IsIntegerValue(left,l) & CheckIntegerValue(right,r) THEN
					ELSIF IsCharacterValue(left,cl) & CheckCharacterValue(right,cr) THEN
						l := ORD(cl); r := ORD(cr);
					ELSIF IsEnumerationValue(left,l) & CheckEnumerationValue(right,r) THEN
					ELSE
						expression := SyntaxTree.invalidExpression
					END;

					IF expression # SyntaxTree.invalidExpression THEN
						IF l>r THEN
							Error(position, "empty case label")
						ELSIF ~EnterCase(thiscases,l,r) OR ~EnterCase(allcases,l,r) THEN
							Error(position, "duplicate case label");
						ELSE
							IF l < min THEN min := l END;
							IF r > max THEN max := r END;
						END;
					END;
				END;
				casePart.elements.SetExpression(i,expression);
			END;
			(*! Coalesce(caseConstants); sort and find succeeeding numbers !!! *)
			casePart.SetConstants(thiscases);
			StatementSequence(casePart.statements);
		END CasePart;

		(** check and resolve case statement CASE variable OF ... END;
			- check variable
			- check case parts
		**)
		PROCEDURE ResolveCaseStatement(caseStatement: SyntaxTree.CaseStatement): SyntaxTree.Statement;
		VAR expression: SyntaxTree.Expression; i: LONGINT; type: SyntaxTree.Type; caseList: SyntaxTree.CaseConstant;
			ch: CHAR; l: Basic.Integer; min,max: Basic.Integer;
		BEGIN
			expression := ResolveExpression(caseStatement.variable);
			type := RegularType(expression.position,expression.type);
			IF type = SyntaxTree.invalidType THEN
				expression := SyntaxTree.invalidExpression;
			ELSIF IsIntegerType(type) THEN
			ELSIF IsStringType(expression.type) (* & IsCharacterValue(expression,ch) *) THEN
				expression := NewConversion(expression.position, expression, system.characterType,NIL);
				(*
				expression := Global.NewCharacterValue(system,expression.position,ch);
				*)
				type := expression.type;
			ELSIF IsCharacterType(type) THEN
			ELSIF IsEnumerationType(type) THEN
			ELSE
				Error(caseStatement.variable.position,"variable must be integer or character type");
				expression := SyntaxTree.invalidExpression;
			END;
			caseStatement.SetVariable(expression);
			caseList := NIL;
			min := MAX(Basic.Integer); max := MIN(Basic.Integer);
			FOR i := 0 TO caseStatement.CaseParts()-1 DO
				CasePart(caseStatement.GetCasePart(i),type,caseList,min,max);
			END;

			caseStatement.SetMinMax(min,max);
			StatementSequence(caseStatement.elsePart);
			IF expression.resolved # NIL THEN
				IF IsCharacterValue(expression,ch) THEN
					l := ORD(ch)
				ELSIF IsIntegerValue(expression,l) THEN
				END;
				IF EnterCase(caseList,l,l) & (caseStatement.elsePart = NIL) THEN Error(caseStatement.position,"no matching case label") END;
			END;
			RETURN caseStatement;
		END ResolveCaseStatement;

		(** check and resolve while statement
			- check condition
			- check statement sequence
		**)
		PROCEDURE ResolveWhileStatement(whileStatement: SyntaxTree.WhileStatement): SyntaxTree.Statement;
		VAR prevIsUnreachable,b: BOOLEAN;
		BEGIN
			prevIsUnreachable := currentIsUnreachable;
			whileStatement.SetCondition(ResolveCondition(whileStatement.condition));
			IF IsBooleanValue(whileStatement.condition,b) THEN
				IF b=FALSE THEN
					currentIsUnreachable := TRUE
				END;
			END;
			StatementSequence(whileStatement.statements);
			currentIsUnreachable := prevIsUnreachable;
			RETURN whileStatement;
		END ResolveWhileStatement;

		(** check and resolve repeat statement
			- check condition
			- check statement sequence
		**)
		PROCEDURE ResolveRepeatStatement(repeatStatement: SyntaxTree.RepeatStatement): SyntaxTree.Statement;
		BEGIN
			repeatStatement.SetCondition(ResolveCondition(repeatStatement.condition));
			StatementSequence(repeatStatement.statements);
			RETURN repeatStatement;
		END ResolveRepeatStatement;

		PROCEDURE GetGuard(symbol: SyntaxTree.Symbol; VAR type: SyntaxTree.Type): BOOLEAN;
		VAR withEntry: WithEntry;
		BEGIN
			withEntry := withEntries;
			WHILE (withEntry # NIL) & (withEntry.symbol # symbol) DO
				withEntry := withEntry.previous
			END;
			IF withEntry = NIL THEN RETURN FALSE
			ELSE
				type := withEntry.type;
				RETURN TRUE
			END;
		END GetGuard;

		(** check and resolve for statement FOR variable := from TO to BY by DO StatementSequence END;
			- check that variable is an integer variable
			- check that from is integer typed with compatible type
			- check that to has compatible type
			- check that by is constant integer with compatible type
		**)
		PROCEDURE ResolveForStatement(forStatement: SyntaxTree.ForStatement): SyntaxTree.Statement;
		VAR expression: SyntaxTree.Expression; designator: SyntaxTree.Designator; type: SyntaxTree.Type;
		BEGIN
			designator := ResolveDesignator(forStatement.variable);
			type := SyntaxTree.invalidType;
			IF designator.type = SyntaxTree.invalidType THEN (* error already handled *)
				designator := SyntaxTree.invalidDesignator;
			ELSIF ~IsIntegerType(designator.type.resolved) THEN
				Error(designator.position,"control variable of non-integer type");
				designator := SyntaxTree.invalidDesignator;
			ELSIF CheckVariable(designator) THEN
				type := designator.type;
			END;
			forStatement.SetVariable(designator);

			expression := ResolveExpression(forStatement.from);
			IF expression = SyntaxTree.invalidExpression THEN
			ELSIF ~CompatibleTo(system,expression.type.resolved,designator.type.resolved) THEN
				Error(expression.position,"start value of incompatible type");
				expression := SyntaxTree.invalidExpression;
			ELSIF type # SyntaxTree.invalidType THEN
				expression := NewConversion(expression.position,expression,type,NIL)
			END;
			forStatement.SetFrom(expression);

			expression := ResolveExpression(forStatement.to);
			IF expression = SyntaxTree.invalidExpression THEN
			ELSIF ~CompatibleTo(system,expression.type.resolved,designator.type.resolved) THEN
				Error(expression.position,"end value of incompatible type");
				expression := SyntaxTree.invalidExpression;
			ELSIF type # SyntaxTree.invalidType THEN
				expression := NewConversion(expression.position,expression,type,NIL)
			END;
			forStatement.SetTo(expression);

			IF forStatement.by # NIL THEN
				expression := ConstantInteger(forStatement.by);
			ELSE
				expression := Global.NewIntegerValue(system,Basic.invalidPosition,1);
			END;

			IF expression = SyntaxTree.invalidExpression THEN
			ELSIF  ~CompatibleTo(system,expression.type.resolved,designator.type.resolved) THEN
				Error(expression.position,"step value of incompatible type");
			ELSIF (expression.resolved(SyntaxTree.IntegerValue).value = 0) THEN
				Error(expression.position,"invalid step value");
			ELSIF type # SyntaxTree.invalidType THEN
				expression := NewConversion(expression.position,expression,type,NIL)
			END;
			forStatement.SetBy(expression);

			StatementSequence(forStatement.statements);
			RETURN forStatement;
		END ResolveForStatement;

		(** check and resolve loop statement LOOP StatementSequence END
			- check statement sequence
		**)
		PROCEDURE ResolveLoopStatement(loopStatement: SyntaxTree.LoopStatement): SyntaxTree.Statement;
		BEGIN
			StatementSequence(loopStatement.statements);
			RETURN loopStatement;
		END ResolveLoopStatement;

		PROCEDURE ResolveExitableBlock(exitableBlock: SyntaxTree.ExitableBlock): SyntaxTree.Statement;
		BEGIN
			StatementSequence(exitableBlock.statements);
			RETURN exitableBlock;
		END ResolveExitableBlock;

		(** check and resolve exit statement EXIT
			- check that exit is within LOOP statement block
		**)
		PROCEDURE ResolveExitStatement(exitStatement: SyntaxTree.ExitStatement): SyntaxTree.Statement;
		VAR outer: SyntaxTree.Statement;
		BEGIN
			outer := exitStatement.outer;
			WHILE(outer # NIL) & ~(outer IS SyntaxTree.ExitableBlock) DO
				outer := outer.outer;
			END;
			IF outer = NIL THEN
				Error(exitStatement.position,"exit statement not within loop statement");
			END;
			RETURN exitStatement;
		END ResolveExitStatement;

		(** check and resolve return statement RETURN [expression]
			- check expression (if any)
			- check if in procedure scope
				- if in procedure scope then check expression compatibility
				- if not in procecdure scope then check on return without expression
		**)
		PROCEDURE ResolveReturnStatement(returnStatement: SyntaxTree.ReturnStatement): SyntaxTree.Statement;
		VAR expression: SyntaxTree.Expression; position: Position; procedure: SyntaxTree.Procedure;
			returnType: SyntaxTree.Type; outer: SyntaxTree.Statement; scope: SyntaxTree.Scope;
		BEGIN
			position := returnStatement.position;
			expression := returnStatement.returnValue;
			IF expression # NIL THEN
				expression := ResolveExpression(expression);
				returnStatement.SetReturnValue(expression);
			END;
			outer := returnStatement.outer;
			WHILE(outer # NIL) & ~(outer IS SyntaxTree.Body) DO
				outer := outer.outer
			END;
			IF (outer # NIL) THEN
				scope := outer(SyntaxTree.Body).inScope;
				IF ~(scope IS SyntaxTree.ProcedureScope) THEN
					IF (expression # NIL) THEN
						Error(position, "return statement with parameter not in procedure scope");
					END;
				ELSE
					procedure := scope(SyntaxTree.ProcedureScope).ownerProcedure;
					IF procedure.type(SyntaxTree.ProcedureType).noReturn THEN
						Error(position, "return statement in procedure that does not return");
					END;
					returnType := procedure.type(SyntaxTree.ProcedureType).returnType;
					IF returnType # NIL THEN
						returnType := returnType.resolved;
						IF expression = NIL THEN
							Error(position, "empty return type in procedure providing a return type")
						ELSIF expression.type = NIL THEN
							Error(position,"returned type incompatible: expression has no type");
						ELSIF ~CompatibleTo(system,expression.type.resolved,returnType) THEN
							Error(position, "return type not compatible");
							IF VerboseErrorMessage THEN
								Printout.Info("returnType",returnType);
								Printout.Info("expression",expression);
							END;
						ELSE
							expression := NewConversion(expression.position,expression,returnType,NIL);
							returnStatement.SetReturnValue(expression);
						END;
					ELSIF expression # NIL THEN
						Error(position, "non-empty return type in procedure providing no return type");
					END;
				END;
			END;
			RETURN returnStatement;
		END ResolveReturnStatement;

		(** check and resolve await statement AWAIT(condition: Expression)
			- check await condition
		**)
		PROCEDURE ResolveAwaitStatement(awaitStatement: SyntaxTree.AwaitStatement): SyntaxTree.Statement;
		VAR condition: SyntaxTree.Expression;
		BEGIN
			condition := ResolveCondition(awaitStatement.condition);
			IF currentIsRealtime THEN
				Error(awaitStatement.position,"forbidden await statement in realtime block");
			END;
			IF (condition.resolved # NIL) & (condition.resolved IS SyntaxTree.BooleanValue) THEN
				Error(awaitStatement.position,"senseless await statement with constant condition");
			END;
			awaitStatement.SetCondition(condition);
			RETURN awaitStatement;
		END ResolveAwaitStatement;

		PROCEDURE CheckSystemImport(position: Position);
		VAR import: SyntaxTree.Import;
		BEGIN
			import := currentScope.ownerModule.moduleScope.firstImport;
			WHILE(import # NIL) DO
				IF (import.module.name = Global.SystemName) OR (import.module.name = Global.systemName)  THEN
					RETURN;
				END;
				import := import.nextImport;
			END;
			Error(position, "forbidden code without system import");
		END CheckSystemImport;

		(** check and resolve code statement: do nothing, must be done by assembler
		**)
		PROCEDURE ResolveCode(code: SyntaxTree.Code);
		BEGIN
			CheckSystemImport(code.position);
		END ResolveCode;

		(** check and set flags of a statement block
			- check for multiply occurence of a flag
			- check and set priority only in bodies
			- check for valid names
		**)
		PROCEDURE BlockFlags(block: SyntaxTree.StatementBlock);
		VAR blockModifier: SyntaxTree.Modifier; expression: SyntaxTree.Expression; name: SyntaxTree.Identifier; flags: SET; position: Position;
			flag: LONGINT; recordBody: SyntaxTree.Body;

			PROCEDURE SetProtectedRecord;
			VAR scope: SyntaxTree.Scope;
			BEGIN
				scope := currentScope;
				WHILE (scope # NIL) & ~(scope IS SyntaxTree.RecordScope) DO
					scope := scope.outerScope
				END;
				IF scope # NIL THEN
					scope(SyntaxTree.RecordScope).ownerRecord.SetProtected(TRUE);
				END;
			END SetProtectedRecord;

		BEGIN
			flags := {};
			IF (block IS SyntaxTree.Body) & (currentIsBodyProcedure) & ((currentScope.outerScope = NIL) OR ~(currentScope.outerScope IS SyntaxTree.ModuleScope)) THEN
				recordBody := block(SyntaxTree.Body)
			ELSE
				recordBody := NIL
			END;

			blockModifier := block.blockModifiers;
			WHILE(blockModifier # NIL) DO
				name := blockModifier.identifier;
				expression := blockModifier.expression;
				position := blockModifier.position;
				flag := -1;
				IF name=Global.NamePriority THEN
					IF expression = NIL THEN
						Error(position, "missing priority expression");
					ELSIF recordBody = NIL THEN
						Error(position, "priority not on record body");
					ELSIF recordBody.priority # NIL THEN
						Error(position, "duplicate priority expression");
					ELSE
						recordBody.SetPriority(expression);
					END;
				ELSIF expression # NIL THEN
					Error(expression.position,"expression not in connection with priority")
				ELSIF name=Global.NameExclusive THEN
					IF block.isExclusive THEN
						Error(position, "duplicate exclusive flag")
					END;
					block.SetExclusive(TRUE); SetProtectedRecord;
				ELSIF name=Global.NameActive THEN
					IF recordBody = NIL THEN
						Error(position, "active not in record body");
					ELSIF recordBody.isActive THEN
						Error(position, "duplicate active flag")
					ELSE
						recordBody.SetActive(TRUE); SetProtectedRecord;
					END;
				ELSIF name=Global.NameSafe THEN
					IF recordBody = NIL THEN
						Error(position, "safe not in record body");
					ELSIF recordBody.isSafe THEN
						Error(position, "duplicate safe flag")
					ELSE
						recordBody.SetSafe(TRUE);
						SetProtectedRecord;
					END;
				ELSIF name=Global.NameRealtime THEN
					IF recordBody = NIL THEN
						Error(position, "realtime not in record body");
					ELSIF recordBody.isRealtime THEN
						Error(position, "duplicate realtime flag")
					ELSE
						recordBody.SetRealtime(TRUE);
						block.SetRealtime(TRUE);
					END;
				ELSIF name=Global.NameUnchecked THEN
					IF block.isUnchecked THEN
						Error(position, "duplicate unchecked flag")
					ELSE
						block.SetUnchecked(TRUE);
					END;
				ELSIF name=Global.NameUntracked THEN
					IF block.isUntracked THEN
						Error(position, "duplicate untracked flag")
					ELSE
						block.SetUntracked(TRUE);
					END;
				ELSIF (name=Global.NameUncooperative) THEN
					IF block.isUncooperative THEN
						Error(position, "duplicate uncooperative flag")
					ELSE
						block.SetUncooperative(TRUE);
					END;
				ELSE
					Error(position, "unknown block modifier");
				END;
				blockModifier := blockModifier.nextModifier;
			END;
		END BlockFlags;

		(** check and resolve statement block
			- check flags (exclusive)
			- check statement sequence
		**)
		PROCEDURE ResolveStatementBlock(statementBlock: SyntaxTree.StatementBlock);
		VAR recentExclusive, recentUnreachable, recentRealtime: BOOLEAN; recentScope: SyntaxTree.Scope;
		BEGIN
			recentScope := currentScope;
			(* IF statementBlock.scope # NIL THEN currentScope := statementBlock.scope END;*)
			BlockFlags(statementBlock);
			IF statementBlock.isExclusive THEN
				(* check that not in exclusive block *)
				IF currentIsExclusive THEN
					Error (statementBlock.position,"forbidden recursive exclusive")
				ELSIF currentIsRealtime THEN
					Error( statementBlock.position,"forbidden exculsive in realtime block");
				END;
			END;
			recentExclusive := currentIsExclusive;
			recentUnreachable := currentIsUnreachable;
			recentRealtime := currentIsRealtime;
			IF statementBlock.isExclusive THEN currentIsExclusive := TRUE END;
			IF statementBlock.isUnreachable THEN currentIsUnreachable := TRUE END;
			IF statementBlock.isRealtime THEN currentIsRealtime := TRUE END;
			StatementSequence(statementBlock.statements);
			currentIsRealtime := recentRealtime;
			currentIsExclusive := recentExclusive;
			currentIsUnreachable := recentUnreachable;
			currentScope := recentScope;
		END ResolveStatementBlock;

		(** check and resolve body
			- check flags (active, priority, safe)
			- check body and finally part
		**)
		PROCEDURE Body(body: SyntaxTree.Body);
		BEGIN
			ResolveStatementBlock(body);
			IF body.isActive THEN
				IF  ~currentIsBodyProcedure THEN
					Error(body.position,"active flag not in object body");
				ELSIF body.priority # NIL THEN
					body.SetPriority(ConstantInteger(body.priority));
				END;
			ELSIF body.isSafe THEN
				Error(body.position,"safe flag not in active body");
			ELSIF body.priority # NIL THEN
				Error(body.position,"priority flag not in active body");
			END;
			IF body.code # NIL THEN
				CheckSystemImport(body.position);
			END;
			StatementSequence(body.finally)
		END Body;

		(*** scopes ***)

		(** Register a symbol in a scope. Check for duplicate symbols and collision with globally defined symbols. **)
		PROCEDURE Register(symbol: SyntaxTree.Symbol; scope: SyntaxTree.Scope; allowDuplicate: BOOLEAN);
		VAR duplicateSymbol: BOOLEAN;
		BEGIN
			ASSERT(symbol.name # SyntaxTree.invalidIdentifier);
			IF ~allowDuplicate & (global.FindSymbol(symbol.name)#NIL) THEN
				Error(symbol.position,"globally defined keyword")
			END;

			scope.EnterSymbol(symbol,duplicateSymbol);
			IF ~allowDuplicate & duplicateSymbol THEN
				Error(symbol.position,"Multiply defined identifier.");
				IF VerboseErrorMessage THEN
					Printout.Info("multiply defined identifier",symbol);
					Printout.Info("in scope",scope);
				END;
			END;
		END Register;

		(**
			implementation: check and resolve an implementation part
		**)
		(*!	can in principle be done in parallel on different checkers: implementations do only depend on declarations)
			move implementation checker to a separate object ? *)
		PROCEDURE Implementation(scope: SyntaxTree.Scope);
		VAR prevScope: SyntaxTree.Scope; procedure: SyntaxTree.Procedure; prevIsRealtime, prevIsBodyProcedure, prevIsCellNet: BOOLEAN;
			procedureType: SyntaxTree.ProcedureType;
		BEGIN
			prevIsRealtime := currentIsRealtime;
			prevIsBodyProcedure := currentIsBodyProcedure;
			prevIsCellNet := currentIsCellNet;
			prevScope := currentScope;
			currentScope := scope;
			WITH scope: SyntaxTree.ProcedureScope DO
				procedure := scope.ownerProcedure;
				procedureType := procedure.type(SyntaxTree.ProcedureType);
				currentIsBodyProcedure := currentIsBodyProcedure OR procedure.isBodyProcedure;
				currentIsRealtime := currentIsRealtime OR procedure.type.isRealtime;
				currentIsCellNet := InCellNetScope(procedure.scope) OR cellsAreObjects;

				IF scope.body # NIL THEN
					IF ~procedure.Resolving(TRUE) THEN (* inline cycle detection *)
						Body(scope(SyntaxTree.ProcedureScope).body)
					END;
					IF ~procedure.Resolving(FALSE) THEN (*HALT(100)*) END;
				END;
				IF procedureType.noPAF THEN
					IF scope.firstVariable # NIL THEN
						Error(procedure.position, "forbidden variable in procedure without activation frame");
					ELSIF procedureType.firstParameter # NIL THEN
						Error(procedure.position, "forbidden parameter in procedure without activation frame");
					END;
				END;
			ELSE
			END;
			currentScope := prevScope;
			currentIsRealtime := prevIsRealtime;
			currentIsBodyProcedure := prevIsBodyProcedure;
			currentIsCellNet := prevIsCellNet;
		END Implementation;

		(** implementation phase:
			check and resolve all scopes (implementation phase) that have been entered into a list during the declaration phase
		**)
		PROCEDURE Implementations(x: SyntaxTree.Module);
		VAR  scope: SyntaxTree.Scope; prevPhase: LONGINT;
		BEGIN
			prevPhase := phase;
			phase := ImplementationPhase;
			Implementation(x.moduleScope);
			scope := x.moduleScope.firstScope;
			WHILE(scope # NIL) DO
				Implementation(scope);
				scope := scope.nextScope;
			END;
			phase := prevPhase;
		END Implementations;

		(** declaration phase:
			check and resolve all declarations of a scope (module scope, procedure scope, record scope):
			- import lists (for module scopes)
			- parameter list (for procedure scopes)
			- constant declarations
			- type declarations
			- variable declarations
			- procedure declarations
			preformed in two stages:
				- first all symbols are entered into the symbol table (with uniqueness check),
				- then all symbols are resolved
			after declaration check, bodies are entered into the global list of implementations that remain to be resolved after all declarations.

			Declarations depend on other declarations, this procedure is neither thread safe not would it be wise to try concurrency here
			phases :
				0 = before procedures
				1 = procedures and later
		**)
		PROCEDURE Declarations(scope: SyntaxTree.Scope; skipImplementation: BOOLEAN; phases: SET);
		VAR
			constant: SyntaxTree.Constant;
			typeDeclaration: SyntaxTree.TypeDeclaration;
			declaredType: SyntaxTree.Type;
			variable: SyntaxTree.Variable;
			procedure: SyntaxTree.Procedure;
			procedureType : SyntaxTree.ProcedureType;
			prevScope: SyntaxTree.Scope;
			parameter: SyntaxTree.Parameter;
			import: SyntaxTree.Import;
			symbol: SyntaxTree.Symbol;
			prevPhase: LONGINT;
			prevError : BOOLEAN;
			i: LONGINT;

			PROCEDURE DeclareCell(type: SyntaxTree.CellType);
			VAR baseType: SyntaxTree.Type; property: SyntaxTree.Property;
			BEGIN
				IF type.baseType # NIL THEN
					baseType := type.baseType.resolved;
					IF baseType IS SyntaxTree.PointerType THEN
						baseType := baseType(SyntaxTree.PointerType).pointerBase.resolved;
					END;
					(*
					IF baseType IS SyntaxTree.CellType THEN
						DeclareCell(baseType(SyntaxTree.CellType));
					END;
					*)
				END;

				parameter := type.firstParameter;
				WHILE(parameter # NIL) DO (* duplicates forbidden *)
					(*
					variable := SyntaxTree.NewVariable(parameter.position, parameter.name);
					variable.SetType(parameter.type);
					variable.SetAccess(SyntaxTree.Hidden);
					variable.SetModifiers(parameter.modifiers);
					currentScope.PushVariable(variable);
					*)
					Register(parameter,scope, FALSE);
					parameter := parameter.nextParameter;
				END;

				property := type.firstProperty;
				WHILE (property # NIL) DO (* duplicates allowed : overwrite *)
					(*
					variable := currentScope.FindVariable(property.name);
					IF (variable # NIL) & (variable IS SyntaxTree.Property) THEN (* overwrite *)
						prop := variable(SyntaxTree.Property);
					ELSE (* add, duplicate symbols detection later *)
						prop := SyntaxTree.NewProperty(property.position, property.name);
						currentScope.PushVariable(prop);
					END;
					prop.SetType(property.type);
					prop.SetValue(property.value);
					prop.SetAccess(SyntaxTree.Hidden);
					*)
					Register(property, scope, FALSE);
					property := property.nextProperty;
				END;
			END DeclareCell;

		BEGIN
			prevError := error;
			prevPhase := phase;
			phase := DeclarationPhase;
			prevScope := currentScope;
			currentScope := scope;
			error := FALSE;

			IF 0 IN phases THEN
				(* first enter all symbols in scope *)
				IF scope IS SyntaxTree.ModuleScope THEN
					(* treat imports first for a module scope, , set default context if necessary *)
					import := scope(SyntaxTree.ModuleScope).firstImport;
					WHILE(import # NIL) DO
						IF import.context = SyntaxTree.invalidIdentifier THEN import.SetContext(scope.ownerModule.context) END;
						Register(import, currentScope, FALSE);
						import := import.nextImport;
					END;
					import := scope(SyntaxTree.ModuleScope).firstImport;
					WHILE(import # NIL) DO (* 2nd stage to avoid duplicate symbol *)
						ResolveSymbol(import);
						import := import.nextImport;
					END;
				ELSIF scope IS SyntaxTree.ProcedureScope THEN
					(* enter parameters for a procedure scope *)
					procedureType := scope(SyntaxTree.ProcedureScope).ownerProcedure.type.resolved(SyntaxTree.ProcedureType);
					parameter := procedureType.firstParameter;
					WHILE(parameter # NIL) DO
						Register(parameter,currentScope, FALSE); parameter := parameter.nextParameter;
					END;
					parameter := procedureType.returnParameter;
					IF parameter # NIL THEN Register(parameter, currentScope, FALSE); END;
					parameter := procedureType.selfParameter;
					IF parameter # NIL THEN
						Register(parameter, currentScope, FALSE);
						parameter.SetState(SyntaxTree.Resolved); (* would lead to cycles, otherwise *)
					END;
				ELSIF scope IS SyntaxTree.CellScope THEN
					DeclareCell(scope(SyntaxTree.CellScope).ownerCell);
					IF~skipImplementation THEN
						import := scope(SyntaxTree.CellScope).firstImport;
						WHILE(import # NIL) DO
							IF import.context = SyntaxTree.invalidIdentifier THEN import.SetContext(scope.ownerModule.context) END;
							Register(import, currentScope, FALSE);
							import := import.nextImport;
						END;
						import := scope(SyntaxTree.CellScope).firstImport;
						WHILE(import # NIL) DO (* 2nd stage to avoid duplicate symbol *)
							ResolveSymbol(import);
							import := import.nextImport;
						END;
					END;
				END;
				IF error THEN RETURN END;

				IF skipImplementation THEN
					scope.Clear;
				END;

				(* constants *)
				constant := scope.firstConstant;
				WHILE (constant # NIL) DO
					Register(constant, currentScope, FALSE); constant := constant.nextConstant;
				END;
				(* type declarations *)
				typeDeclaration := scope.firstTypeDeclaration;
				WHILE (typeDeclaration # NIL) DO
					Register(typeDeclaration, currentScope, FALSE); typeDeclaration := typeDeclaration.nextTypeDeclaration;
				END;
				(* variables *)
				variable := scope.firstVariable;
				WHILE (variable # NIL) DO
					Register(variable, currentScope, FALSE); variable := variable.nextVariable;
				END;
				(* procedures *)
				IF scope.procedures # NIL THEN
					FOR i := 0 TO scope.procedures.Length()-1 DO
						procedure := scope.procedures.GetProcedure(i);
						procedureType := procedure.type.resolved(SyntaxTree.ProcedureType);
						IF procedureType.selfParameter = NIL THEN
							scope.AddProcedure(procedure);
							Register(procedure, currentScope, procedure IS SyntaxTree.Operator);
						ELSE
							typeDeclaration := currentScope.FindTypeDeclaration(procedureType.selfParameter.type(SyntaxTree.QualifiedType).qualifiedIdentifier.suffix);
							IF typeDeclaration = NIL THEN
								Error(procedureType.selfParameter.position, "No such type declaration");
							ELSE
								procedureType.selfParameter.type(SyntaxTree.QualifiedType).SetResolved(typeDeclaration.declaredType.resolved);
								procedureType.selfParameter.SetState(SyntaxTree.Resolved);
								declaredType := typeDeclaration.declaredType;
								IF declaredType IS SyntaxTree.PointerType THEN
									declaredType := declaredType(SyntaxTree.PointerType).pointerBase.resolved
								END;
								IF declaredType IS SyntaxTree.RecordType THEN
									declaredType(SyntaxTree.RecordType).recordScope.AddProcedure(procedure);
									Register(procedure, declaredType(SyntaxTree.RecordType).recordScope, procedure IS SyntaxTree.Operator);
								ELSE
									Error(procedureType.selfParameter.position,"type is no record or pointer to record");
								END;
							END;
						END;
					END;
				END;
			END;

			(* now process all symbols without any presumption on the order *)
			symbol := scope.firstSymbol;
			WHILE(symbol # NIL) DO
				IF ~(symbol IS SyntaxTree.Parameter) OR (symbol(SyntaxTree.Parameter).ownerType IS SyntaxTree.CellType) THEN
					IF (symbol IS SyntaxTree.Procedure) THEN
						IF 1 IN phases THEN
							ResolveSymbol(symbol);
						END;
					ELSE
						IF 0 IN phases THEN
							ResolveSymbol(symbol);
						END;
					END;
				END;
				symbol := symbol.nextSymbol;
			END;

			IF (scope IS SyntaxTree.ProcedureScope) & scope(SyntaxTree.ProcedureScope).ownerProcedure.type.isRealtime THEN
				symbol := scope.firstSymbol;
				WHILE symbol # NIL DO
					IF (symbol IS SyntaxTree.Variable) OR (symbol IS SyntaxTree.Parameter) THEN
						IF (symbol.type IS SyntaxTree.PointerType) OR (symbol.type IS SyntaxTree.QualifiedType) THEN
							pointerFixes.Add(symbol, currentScope);
						END;
						IF ~symbol.type.resolved.isRealtime THEN
							Error(symbol.position,"symbol has no realtime type");
						END;
					END;
					symbol := symbol.nextSymbol
				END;
			END;

			IF ~error & (1 IN phases) & ~system.GenerateVariableOffsets(scope) THEN
				Error(Basic.invalidPosition,"problems during offset computation in module");
			END;

			IF  (scope.ownerModule # NIL) & (1 IN phases)   THEN
				(* add scope to global list of all scopes, very handy for code generation and for checking implementations *)
				scope.ownerModule.moduleScope.AddScope(scope);
			END;

			phase := prevPhase;
			currentScope := prevScope;
			error := error OR prevError;
		END Declarations;

		(* nopov *)
		(** check if all operators from one module are compatible to the ones in the other module
		- check if there are not multiple operators with the same signature
			(apart from the conversion operator "@Convert": it is the only operator that may be defined multiple times with the same signature)
		- check for all operators whose signatures are compatible, whether the return types are compatible
		note that:
			- the return type is not considered to be part of the signature
			- two signatures are considered compatible, if all of the operands are compatible
		**)
		PROCEDURE CheckInterOperatorConformity(thisModuleScope, thatModuleScope: SyntaxTree.ModuleScope);
		VAR
			thisOperator, thatOperator: SyntaxTree.Operator;
			thisProcedureType, thatProcedureType: SyntaxTree.ProcedureType;
			thisParameter, thatParameter: SyntaxTree.Parameter;
			operandsAreEqual, operandsAreCompatible, hasError: BOOLEAN;
			i: LONGINT;
		BEGIN
			currentScope := thisModuleScope;
			hasError := FALSE;

			(* go through all operators in the other module *)
			thatOperator := thatModuleScope.firstOperator;
			WHILE (thatOperator # NIL) & ~hasError DO
				IF (thisModuleScope = thatModuleScope) OR (SyntaxTree.PublicRead IN thatOperator.access) THEN
					(* the other operator is accessible *)
					IF thatOperator.name # Global.GetIdentifier(Global.Conversion, thatModuleScope.ownerModule.case) THEN
						(* the other operator is not the conversion operator *)

						(* go through all operators in this module *)
						thisOperator := thisModuleScope.firstOperator;
						WHILE (thisOperator # NIL) & ~hasError DO
							IF thisOperator # thatOperator THEN
								(* the operators are not the same *)
								IF thisOperator.name = thatOperator.name THEN
									(* the operators share the same identifier *)

									ASSERT(thisOperator.type IS SyntaxTree.ProcedureType);
									ASSERT(thatOperator.type IS SyntaxTree.ProcedureType);
									thisProcedureType := thisOperator.type(SyntaxTree.ProcedureType);
									thatProcedureType := thatOperator.type(SyntaxTree.ProcedureType);
									IF thisProcedureType.numberParameters = thatProcedureType.numberParameters THEN
										(* both operators have the same paramter count *)
										thisParameter := thisProcedureType.firstParameter;
										thatParameter := thatProcedureType.firstParameter;
										operandsAreEqual := TRUE;
										operandsAreCompatible := TRUE;
										(* go through all parameters *)
										FOR i := 1 TO thisProcedureType.numberParameters DO
											ASSERT(thatParameter # NIL);
											IF ~SameType(thisParameter.type, thatParameter.type) THEN
												operandsAreEqual := FALSE;
												IF TypeDistance(system, thisParameter.type, thatParameter.type, thisParameter.kind = SyntaxTree.VarParameter) =Infinity THEN
													operandsAreCompatible := FALSE
												END
											END;
											thisParameter := thisParameter.nextParameter;
											thatParameter := thatParameter.nextParameter
										END;
										IF operandsAreEqual THEN
											Error(thisOperator.position, "operator has the same identifier and operand types as other one");
											hasError := TRUE
										ELSIF operandsAreCompatible THEN
											IF ~CompatibleTo(system, thisProcedureType.returnType, thatProcedureType.returnType) THEN
												Error(thisOperator.position, "operator's return type is not compatible to the one of a more generic operator");
												hasError := TRUE
											ELSIF ~thisOperator.isDynamic & thatOperator.isDynamic THEN
												Error(thisOperator.position, "operator must be dynamic because it is signature-compatible to a dynamic one");
												hasError := TRUE
											END
										END
									END
								END
							END;
							thisOperator := thisOperator.nextOperator
						END
					END
				END;
				thatOperator := thatOperator.nextOperator
			END
		END CheckInterOperatorConformity;

		(** check module:
			- check module declaration
			- add context, if necessary
			- remove module from import cache, if necessary
			- check declarations
			- resolve all type fixes
			- check implementation (bodies)
		**)
		PROCEDURE Module*(x: SyntaxTree.Module);
		VAR (* nopov *)
			import: SyntaxTree.Import; modifier: SyntaxTree.Modifier; value: Basic.Integer; position: Position; prevIsCellNet: BOOLEAN; prevScope: SyntaxTree.Scope;
		BEGIN
			prevScope := currentScope;
			prevIsCellNet := currentIsCellNet;
			module := x;
			ASSERT(x # NIL);
			global := system.globalScope[x.case];
			x.moduleScope.SetGlobalScope(global);
			currentScope := global;
			IF (x.name = Global.SystemName) OR (x.name = Global.systemName) THEN Error(x.position,"name reserved") END;
			IF x.context = SyntaxTree.invalidIdentifier THEN x.SetContext(Global.A2Name) END;
			RemoveModuleFromCache(importCache,x);
			Declarations(x.moduleScope, FALSE, {0,1});
			FixTypes();

			IF module.isCellNet THEN
				currentIsCellNet := TRUE;
				modifier := x.modifiers;
				IF HasValue(modifier,Global.NameFrequencyDivider,position,value) THEN END;
				CheckModifiers(modifier, FALSE);
			END;

			(* nopov *)
			IF ~error THEN
				(* check if operators conform to each other within this module *)
				CheckInterOperatorConformity(x.moduleScope, x.moduleScope);

				(* go through all imports *)
				import := x.moduleScope.firstImport;
				WHILE import # NIL DO
					IF (import.module # NIL) & ~Global.IsSystemModule(import.module) THEN (* ignore SYSTEM-module *)
						(* check if all operators in this module conform to the ones of the imported module *)
						CheckInterOperatorConformity(x.moduleScope, import.module.moduleScope)
					END;
					import := import.nextImport
				END;
			END;

			Implementations(x);
			module := NIL;
			currentIsCellNet := prevIsCellNet;
			currentScope := prevScope;
		END Module;

	END Checker;

	Warnings*=OBJECT
	VAR diagnostics: Diagnostics.Diagnostics; module: SyntaxTree.Module;

		PROCEDURE &InitWarnings*(diagnostics: Diagnostics.Diagnostics);
		BEGIN
			SELF.diagnostics := diagnostics
		END InitWarnings;

		(** types *)
		PROCEDURE Type(CONST x: SyntaxTree.Type);
		BEGIN
			IF SyntaxTree.Warned IN x.state THEN RETURN END;
			x.SetState(SyntaxTree.Warned);
			WITH x:
			SyntaxTree.ArrayType DO  Type(x.arrayBase);
			|SyntaxTree.MathArrayType DO Type(x.arrayBase);
			|SyntaxTree.PointerType DO Type(x.pointerBase);
			|SyntaxTree.RecordType DO Scope(x.recordScope);
			|SyntaxTree.CellType DO Scope(x.cellScope)
			ELSE
			END;
		END Type;

		PROCEDURE Warning(x: SyntaxTree.Symbol; CONST text: ARRAY OF CHAR);
		VAR msg: ARRAY 256 OF CHAR;
		BEGIN
			Global.GetSymbolName(x,msg);
			Strings.Append(msg," ");
			Strings.Append(msg,text);
			Basic.Warning(diagnostics, module.sourceName,x.position, msg);
		END Warning;

		(** symbols *)
		PROCEDURE Symbol(x: SyntaxTree.Symbol);
		BEGIN
			IF ~x.used & (x.access * SyntaxTree.Public = {}) & (x.access # SyntaxTree.Hidden) THEN
				IF ~(x IS SyntaxTree.Parameter) THEN
					Warning(x,"never used");
				END;
			END;
			WITH x:
			SyntaxTree.Procedure DO
				Scope(x.procedureScope)
			| SyntaxTree.TypeDeclaration DO
				Type(x.declaredType);
			ELSE
			END;
		END Symbol;

		PROCEDURE Scope(scope: SyntaxTree.Scope);
		VAR
			symbol: SyntaxTree.Symbol;
		BEGIN
			symbol := scope.firstSymbol;
			WHILE(symbol # NIL) DO
				Symbol(symbol);
				symbol := symbol.nextSymbol;
			END;
		END Scope;

		PROCEDURE Module*(x: SyntaxTree.Module);
		BEGIN
			SELF.module := x;
			Scope(x.moduleScope);
		END Module;

	END Warnings;

	PROCEDURE IsOberonInline(procedure: SyntaxTree.Procedure): BOOLEAN;
	BEGIN
		RETURN procedure.isOberonInline OR procedure.isInline &
			((procedure.procedureScope.body = NIL) OR (procedure.procedureScope.body # NIL) & (procedure.procedureScope.body.code = NIL))
	END IsOberonInline;

	PROCEDURE SideEffectFree(e: SyntaxTree.Expression): BOOLEAN;
	BEGIN
		IF e = NIL THEN RETURN TRUE
		ELSIF (e IS SyntaxTree.SymbolDesignator) THEN RETURN SideEffectFree(e(SyntaxTree.SymbolDesignator).left)
		ELSIF (e IS SyntaxTree.Value) THEN RETURN TRUE
		ELSIF (e IS SyntaxTree.SelfDesignator) THEN RETURN TRUE
		ELSIF (e IS SyntaxTree.ResultDesignator) THEN RETURN TRUE
		ELSIF (e IS SyntaxTree.DereferenceDesignator) THEN RETURN SideEffectFree(e(SyntaxTree.DereferenceDesignator).left)
		ELSE RETURN FALSE
		END;
	END SideEffectFree;

	PROCEDURE Resolved(x: SyntaxTree.Type): SyntaxTree.Type;
	BEGIN
		IF x = NIL THEN RETURN NIL ELSE RETURN x.resolved END;
	END Resolved;

	PROCEDURE PowerOf2(x: Basic.Integer): BOOLEAN;
	VAR i: LONGINT;
	BEGIN
		i := 1;
		WHILE i < x DO
			i := i *2
		END;
		RETURN i=x
	END PowerOf2;

	PROCEDURE IsCellNetScope(scope: SyntaxTree.Scope): BOOLEAN;
	BEGIN
		RETURN
			(scope # NIL) &
			(scope IS SyntaxTree.ModuleScope)
			& (scope(SyntaxTree.ModuleScope).ownerModule.isCellNet)
			OR
			(scope # NIL) & (scope IS SyntaxTree.CellScope)
			& (scope(SyntaxTree.CellScope).ownerCell.isCellNet)
	END IsCellNetScope;

	PROCEDURE IsCellScope(scope: SyntaxTree.Scope): BOOLEAN;
	BEGIN
		RETURN (scope # NIL) & (scope IS SyntaxTree.CellScope) & ~(scope(SyntaxTree.CellScope).ownerCell.isCellNet)
	END IsCellScope;

	PROCEDURE InCellNetScope(scope: SyntaxTree.Scope): BOOLEAN;
	BEGIN
		WHILE (scope # NIL) & ~IsCellScope(scope) & ~IsCellNetScope(scope) DO scope := scope.outerScope END;
		RETURN (scope # NIL) & IsCellNetScope(scope)
	END InCellNetScope;

	PROCEDURE ToMemoryUnits(system: Global.System; size: LONGINT): LONGINT;
	BEGIN
		ASSERT(size MOD system.dataUnit = 0);
		RETURN size DIV system.dataUnit
	END ToMemoryUnits;

	(* Returns TRUE if the built-in function GETPROCEDURE can be used with this procedure type *)
	PROCEDURE GetProcedureAllowed*(type: SyntaxTree.Type) : BOOLEAN;
	VAR procedureType: SyntaxTree.ProcedureType; numberParameters: LONGINT;

		PROCEDURE TypeAllowed(t : SyntaxTree.Type) : BOOLEAN;
		BEGIN
			IF t = NIL THEN
				RETURN TRUE
			ELSE
				t := t.resolved;
				RETURN (t IS SyntaxTree.RecordType) OR IsPointerToRecord(t) OR (t IS SyntaxTree.AnyType);
			END;
		END TypeAllowed;

	BEGIN
		type := type.resolved;
		IF ~(type IS SyntaxTree.ProcedureType) THEN
			RETURN FALSE
		ELSE
			procedureType := type(SyntaxTree.ProcedureType);
			numberParameters := procedureType.numberParameters;
			RETURN
				(numberParameters = 0) & TypeAllowed(procedureType.returnType) OR
				(numberParameters = 1) & TypeAllowed(procedureType.firstParameter.type) & TypeAllowed(procedureType.returnType) OR
				(numberParameters = 1) & (procedureType.firstParameter.ownerType.resolved IS SyntaxTree.AnyType) & (procedureType.returnType.resolved IS SyntaxTree.AnyType)
		END;
	END GetProcedureAllowed;

	(** check import cache: if module x is in current import cache then remove x and all modules importing x from the cache **)
	PROCEDURE RemoveModuleFromCache*(importCache: SyntaxTree.ModuleScope; x: SyntaxTree.Module);
	VAR import: SyntaxTree.Import;
	BEGIN
		import := importCache.ImportByModuleName(x.name,x.context);
		IF import # NIL THEN
			importCache.RemoveImporters(x.name,x.context);
		END;
	END RemoveModuleFromCache;

	PROCEDURE CompatibleTo(system: Global.System; this,to: SyntaxTree.Type): BOOLEAN;
	(* to <- this assignment compatibility *)
	VAR result: BOOLEAN;
	BEGIN
		IF this= NIL THEN result := (to=NIL)
		ELSIF to=NIL THEN result := FALSE
		ELSE
			(*! will be replaced by this:
			ELSE result := this.CompatibleTo(to.resolved);
			*)
			this := this.resolved; to := to.resolved;
			IF to=SyntaxTree.invalidType THEN result := FALSE
			ELSIF to=SyntaxTree.typeDeclarationType THEN result := FALSE;
			ELSIF (to = this) OR (to.SameType(this)) THEN
				result := ~(to IS SyntaxTree.ArrayType) OR (to(SyntaxTree.ArrayType).form # SyntaxTree.Open);

			ELSIF to IS SyntaxTree.BasicType THEN
				IF (to IS SyntaxTree.NumberType) & (this IS SyntaxTree.NumberType) THEN
					IF (to IS SyntaxTree.ComplexType) OR (this IS SyntaxTree.ComplexType) THEN
						result := this.CompatibleTo(to.resolved)
					ELSE
						result := Global.BasicTypeDistance(system,this(SyntaxTree.BasicType),to(SyntaxTree.BasicType)) < Infinity;
					END
				ELSIF (to IS SyntaxTree.SetType) & (this IS SyntaxTree.SetType) THEN
					result := to.sizeInBits >= this.sizeInBits;
				ELSIF (to IS SyntaxTree.IntegerType) & (this IS SyntaxTree.AddressType) THEN
					result := to.sizeInBits >= this.sizeInBits; (* weak compatibility: (unsigned) address may be assigned to signed integer of same (or greater) size *)
				ELSIF (to IS SyntaxTree.IntegerType) & (this IS SyntaxTree.SizeType) THEN
					result := to.sizeInBits >= this.sizeInBits; (* compatibility: (signed) size may be assigned to signed integer of greater or equal size *)
				ELSIF (to IS SyntaxTree.FloatType) & (this IS SyntaxTree.AddressType) OR (this IS SyntaxTree.SizeType) THEN
					result := TRUE;
				ELSIF to IS SyntaxTree.AnyType THEN
					result :=  (this IS SyntaxTree.RecordType) & this(SyntaxTree.RecordType).isObject OR (this IS SyntaxTree.PointerType) OR (this IS SyntaxTree.ProcedureType) OR (this IS SyntaxTree.NilType) OR (this IS SyntaxTree.AnyType) OR (this IS SyntaxTree.ObjectType);
				ELSIF to IS SyntaxTree.ObjectType THEN
					result := IsPointerToRecord(this) OR (this IS SyntaxTree.NilType) OR (this IS SyntaxTree.ObjectType) OR (this IS SyntaxTree.AnyType) (*! remove when symbol file can distinguish OBJECT from ANY *) ;
				ELSIF to IS SyntaxTree.ByteType THEN
					result := (this IS SyntaxTree.IntegerType) & (to.sizeInBits = 8) OR IsCharacterType(this)
				ELSIF to IS SyntaxTree.CharacterType THEN
					result := IsCharacterType(this)
				ELSIF (to IS SyntaxTree.SizeType) & ((this IS SyntaxTree.SizeType) OR (this IS SyntaxTree.IntegerType) OR IsAddressType(this, system.addressSize)) THEN
					result := to.sizeInBits >= this.sizeInBits (*! weak compatibility: signed size type may be assigned with unsigned address type of same size *)
				ELSIF (to IS SyntaxTree.AddressType) & ((this IS SyntaxTree.AddressType) OR (this IS SyntaxTree.IntegerType) OR (this IS SyntaxTree.SizeType) OR IsPointerType(this) OR (this IS SyntaxTree.ProcedureType)
					OR IsTensor(this)
				) THEN
					result := to.sizeInBits >= this.sizeInBits; (*! weak compatibility: addresses may be assigned with signed integer *)
				ELSIF (to IS SyntaxTree.RangeType) & (this IS SyntaxTree.RangeType) THEN
					result := TRUE;
				ELSIF (to IS SyntaxTree.BooleanType) & (this IS SyntaxTree.BooleanType) THEN
					result := TRUE;
				ELSE
					result := FALSE
				END;
			ELSIF IsUnsafePointer(to) & IsUnsafePointer(this) THEN
				result := TRUE;
			ELSIF to IS SyntaxTree.PointerType THEN
				result := (this IS SyntaxTree.NilType) OR
						IsUnsafePointer(to) & ( (this IS SyntaxTree.AddressType) OR (this IS SyntaxTree.IntegerType) OR IsPointerType(this) OR IsTensor(this)) OR
						(IsPointerType(this) & IsTypeExtension(to,this) OR
						((to(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.ArrayType) & SameType(to,this))) & (~to.isRealtime OR this.isRealtime);
			ELSIF to IS SyntaxTree.ProcedureType THEN
				result := (this IS SyntaxTree.NilType) OR (this IS SyntaxTree.ProcedureType) & this.CompatibleTo(to)
			ELSIF (to IS SyntaxTree.RecordType) & to(SyntaxTree.RecordType).isObject THEN
				result := (this IS SyntaxTree.NilType) OR IsTypeExtension(to,this);
			ELSIF to IS SyntaxTree.RecordType THEN
				result :=  (this IS SyntaxTree.RecordType) & IsTypeExtension(to,this);
			ELSIF to IS SyntaxTree.ArrayType THEN
				IF IsStringType(to) & (this IS SyntaxTree.StringType) THEN
					result := (to(SyntaxTree.ArrayType).form = SyntaxTree.Open) OR (to(SyntaxTree.ArrayType).staticLength >= this(SyntaxTree.StringType).length)
				ELSIF StaticArrayCompatible(to, this) THEN
					result := TRUE
				ELSE
					result := (to(SyntaxTree.ArrayType).staticLength # 0) & SameType(to,this)
				END;
			ELSIF to IS SyntaxTree.MathArrayType THEN
				IF this IS SyntaxTree.MathArrayType THEN
					IF to(SyntaxTree.MathArrayType).arrayBase= NIL THEN
						IF to(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
							result := TRUE;
						ELSIF this(SyntaxTree.MathArrayType).arrayBase = NIL THEN
							result := TRUE;
						ELSE
							result := ~(this(SyntaxTree.MathArrayType).arrayBase.resolved IS SyntaxTree.MathArrayType);
						END;
						(* special case: ARRAY [...] OF SYSTEM.ALL *)
					ELSIF (to(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor) OR (this(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor) THEN
						(* ARRAY [?] OF <- ARRAY [x,...,x] OF *)
						result := CompatibleTo(system,ArrayBase(this,Infinity),ArrayBase(to,Infinity));
					ELSIF (to(SyntaxTree.MathArrayType).form = SyntaxTree.Open) OR (this(SyntaxTree.MathArrayType).form = SyntaxTree.Open)
						OR (to(SyntaxTree.MathArrayType).staticLength = this(SyntaxTree.MathArrayType).staticLength) THEN
						(* ARRAY [x] OF <- ARRAY [x] OF  *)
						result := CompatibleTo(system,this(SyntaxTree.MathArrayType).arrayBase,to(SyntaxTree.MathArrayType).arrayBase);
					ELSE
						result := FALSE
					END;
				ELSE
					result := FALSE;
				END;
			ELSIF to IS SyntaxTree.StringType THEN
				result := FALSE;
			ELSIF to IS SyntaxTree.EnumerationType THEN
				result := IsEnumerationExtension(this,to);
			ELSIF to IS SyntaxTree.PortType THEN
				result := SameType(to, this)
			ELSE
				Printout.Info("CompatibleTo",to);
				HALT(100); (* implement missing type check *)
			END;
		END;
		RETURN result
	END CompatibleTo;

	PROCEDURE StaticArrayCompatible(formal: SyntaxTree.Type; actual: SyntaxTree.Type): BOOLEAN;
	VAR actualBase, formalBase: SyntaxTree.Type;
	BEGIN
		IF SameType(formal,actual) THEN
			RETURN TRUE
		ELSIF (formal IS SyntaxTree.MathArrayType) & (actual IS SyntaxTree.ArrayType) THEN
			actualBase := actual(SyntaxTree.ArrayType).arrayBase.resolved;
			formalBase := formal(SyntaxTree.MathArrayType).arrayBase.resolved;
			RETURN
				(formal(SyntaxTree.MathArrayType).form = SyntaxTree.Static)
				& (actual(SyntaxTree.ArrayType).form = SyntaxTree.Static)
				& (actual(SyntaxTree.ArrayType).staticLength = formal(SyntaxTree.MathArrayType).staticLength)
				& StaticArrayCompatible(formalBase,actualBase)
		ELSIF (formal IS SyntaxTree.ArrayType) & (actual IS SyntaxTree.MathArrayType) THEN
			actualBase := actual(SyntaxTree.MathArrayType).arrayBase.resolved;
			formalBase := formal(SyntaxTree.ArrayType).arrayBase.resolved;
			RETURN
				(formal(SyntaxTree.ArrayType).form = SyntaxTree.Static)
				& (actual(SyntaxTree.MathArrayType).form = SyntaxTree.Static)
				& (actual(SyntaxTree.MathArrayType).staticLength = formal(SyntaxTree.ArrayType).staticLength)
				& StaticArrayCompatible(formalBase,actualBase)
		ELSE RETURN FALSE
		END;
	END StaticArrayCompatible;

	PROCEDURE OpenArrayCompatible(formalType: SyntaxTree.ArrayType; actualType: SyntaxTree.Type): BOOLEAN;
	VAR arrayBase: SyntaxTree.Type; result: BOOLEAN;

		PROCEDURE TC(formal,actual: SyntaxTree.Type): BOOLEAN;
		VAR actualBase,formalBase: SyntaxTree.Type; result: BOOLEAN;
		BEGIN
			result := SameType(formal,actual);
			IF ~result & (formal IS SyntaxTree.ArrayType) & (actual IS SyntaxTree.ArrayType) THEN
				actualBase := actual(SyntaxTree.ArrayType).arrayBase.resolved;
				formalBase := formal(SyntaxTree.ArrayType).arrayBase.resolved;
				result := (formal(SyntaxTree.ArrayType).form = SyntaxTree.Open) & TC(formalBase,actualBase)
			ELSIF ~result & (formal IS SyntaxTree.ArrayType) & (actual IS SyntaxTree.MathArrayType) THEN
				actualBase := actual(SyntaxTree.MathArrayType).arrayBase.resolved;
				formalBase := formal(SyntaxTree.ArrayType).arrayBase.resolved;
				result := (formal(SyntaxTree.ArrayType).form = SyntaxTree.Open) & (actual(SyntaxTree.MathArrayType).form = SyntaxTree.Static)
					& TC(formalBase, actualBase);
			END;
			RETURN result
		END TC;

	BEGIN
		IF formalType.form # SyntaxTree.Open THEN result := FALSE
		ELSE
			arrayBase := formalType.arrayBase.resolved;
			IF (actualType IS SyntaxTree.StringType) THEN
				result := arrayBase IS SyntaxTree.CharacterType
			ELSIF actualType IS SyntaxTree.ArrayType THEN
				result := (arrayBase IS SyntaxTree.ByteType) OR TC(formalType,actualType)
			ELSIF actualType IS SyntaxTree.MathArrayType THEN
				result := TC(formalType, actualType);
			ELSE
				result := (arrayBase IS SyntaxTree.ByteType)
			END;
		END;
		RETURN result
	END OpenArrayCompatible;

	PROCEDURE MathArrayCompatible(formalType: SyntaxTree.MathArrayType; actualType: SyntaxTree.Type): BOOLEAN;
	(* special compatibility rule for parameters of the form VAR A: ARRAY [x] OF , VAR A: ARRAY [*] OF and VAR A: ARRAY [?] OF  *)
	VAR formalBase,actualBase: SyntaxTree.Type; result: BOOLEAN; actualArray: SyntaxTree.MathArrayType;
	BEGIN
		IF actualType IS SyntaxTree.MathArrayType THEN
			actualArray := actualType(SyntaxTree.MathArrayType);
			IF (formalType.form = SyntaxTree.Tensor) OR (actualArray.form = SyntaxTree.Tensor) THEN
				(*
					ARRAY [?] OF  -> ARRAY [?|*|k] OF
					ARRAY [?|*|k] OF -> ARRAY [?] OF
				*)
				actualBase := ArrayBase(actualType,Infinity);
				formalBase := ArrayBase(formalType,Infinity);
				result := (formalBase = NIL) OR SameType(formalBase,actualBase);
			ELSE
				(*
					ARRAY [*|k] OF -> ARRAY [*|n] OF
				*)
				formalBase := Resolved(formalType.arrayBase);
				actualBase := Resolved(actualArray.arrayBase);
				IF (formalType.form = SyntaxTree.Static) & (actualArray.form = SyntaxTree.Static) THEN
					(*
						ARRAY [k] -> ARRAY [n]
					*)
					result := (formalType.staticLength = actualArray.staticLength)
				ELSE
					result := TRUE
				END;
				IF ~result THEN
				ELSIF formalBase = NIL THEN result := (actualBase = NIL) OR ~(actualBase IS SyntaxTree.MathArrayType);
				ELSIF actualBase = NIL THEN result := FALSE
				ELSIF formalBase IS SyntaxTree.MathArrayType THEN
					result := MathArrayCompatible(formalBase(SyntaxTree.MathArrayType),actualBase)
				ELSE
					result := SameType(formalBase,actualBase)
				END;
			END;
		ELSE
			result := FALSE
		END;
		RETURN result
	END MathArrayCompatible;

	(**
		Math Array Type distance for assignments / parameter passings of the form
		from -> to
		variants:
		ARRAY [num] | ARRAY [*] | ARRAY [?] -> ARRAY [num] | ARRAY[*] | ARRAY [?]

		allowed:
			static -> static (& size match)
			static -> open
			static -> tensor
			open -> open
			open -> tensor
			open -> static
			tensor -> tensor
			tensor -> open
			tensor -> static
	**)
	(*! think about the metric here: is form matching more important than element type matching? *)
	PROCEDURE MathArrayTypeDistance(system: Global.System; from,to: SyntaxTree.MathArrayType; varpar:BOOLEAN): LONGINT;
	VAR i: LONGINT; fromBase, toBase: SyntaxTree.Type;
	BEGIN
		fromBase := Resolved(from.arrayBase);
		toBase := Resolved(to.arrayBase);
		i := Infinity;
		IF (from = to) OR (from.SameType(to)) THEN
			i := 0;
		ELSIF (from.form = to.form) THEN
			(* static -> static, open -> open, tensor -> tensor *)
			IF (from.form # SyntaxTree.Static) OR (from.staticLength = to.staticLength) THEN
				IF  fromBase = toBase THEN i := 0
				ELSIF toBase = NIL THEN i := 1
				ELSIF fromBase = NIL THEN i := Infinity;
				ELSIF toBase.SameType(fromBase) THEN i := 0
				ELSIF (fromBase IS SyntaxTree.MathArrayType) & (toBase IS SyntaxTree.MathArrayType) THEN
					i := MathArrayTypeDistance(system,fromBase(SyntaxTree.MathArrayType),toBase(SyntaxTree.MathArrayType),varpar);
				ELSE
					i := TypeDistance(system,fromBase, toBase, varpar);
					IF i < Infinity THEN i := i * 5 END;
				END;
			END;
		ELSIF (to.form = SyntaxTree.Static) THEN
			(* forbidden *)
		ELSIF (from.form = SyntaxTree.Tensor) OR (to.form = SyntaxTree.Tensor) THEN
			(* static -> tensor, open -> tensor, tensor -> open *)
			IF (toBase=fromBase) THEN i := 0;
			ELSIF toBase = NIL THEN i := 1;
			ELSIF toBase.SameType(fromBase) THEN i := 0
			ELSIF (toBase IS SyntaxTree.MathArrayType) THEN
				toBase := ArrayBase(toBase,Infinity);
				IF (fromBase=toBase) THEN i := 0
				ELSIF (toBase = NIL) THEN i:= 1
				ELSIF (fromBase = NIL) THEN i := Infinity;
				ELSE i := TypeDistance(system,fromBase,toBase,varpar);
					IF i < Infinity THEN i := i * 5 END;
				END;
			ELSIF (fromBase IS SyntaxTree.MathArrayType) THEN
				fromBase := ArrayBase(fromBase,Infinity);
				IF (fromBase=toBase) THEN i := 0
				ELSIF (toBase = NIL) THEN i := 1
				ELSIF (fromBase = NIL) THEN i := Infinity;
				ELSIF toBase.SameType(fromBase) THEN i := 0
				ELSE i := TypeDistance(system,fromBase,toBase,varpar);
					IF i < Infinity THEN i := i * 5 END;
				END;
			ELSE i := TypeDistance(system, fromBase, toBase, varpar);
				IF i < Infinity THEN i := i * 5 END;
			END;
			IF i # Infinity THEN INC(i,2) END;
		ELSIF (from.form = SyntaxTree.Static) THEN
			(* static -> open *)
			IF (toBase=fromBase) THEN i := 0;
			ELSIF toBase = NIL THEN i := 1
			ELSIF fromBase = NIL THEN i := Infinity
			ELSIF toBase.SameType(fromBase) THEN i := 0
			ELSIF (toBase IS SyntaxTree.MathArrayType) & (fromBase IS SyntaxTree.MathArrayType) THEN
				i := MathArrayTypeDistance(system,fromBase(SyntaxTree.MathArrayType),toBase(SyntaxTree.MathArrayType),varpar);

			ELSE i := TypeDistance(system,fromBase, toBase, varpar);
				IF i < Infinity THEN i := i * 5 END;
			END;
			IF i # Infinity THEN INC(i,1) END;
		ELSE HALT(100); (* unknown case *)
		END;
		RETURN i;
	END MathArrayTypeDistance;

	(** compute and return the distance of two array types
	- return the distance of the base types
	**)
	PROCEDURE ArrayTypeDistance(system: Global.System; from, to: SyntaxTree.ArrayType): LONGINT;
	VAR i: LONGINT;
	BEGIN
		i := Infinity;
		IF from = to THEN
			i := 0
		ELSE
			i := TypeDistance(system,from.arrayBase.resolved, to.arrayBase.resolved,FALSE);
		(*
		ELSIF (from.mode = static) & (to.mode IN {open}) THEN
			i := TypeDistance(from.base, to.base);
			IF i >= 0 THEN INC(i) END
		ELSIF (from.mode = open) & (to.mode = open) THEN
			i := TypeDistance(from.base, to.base);
		*)
		END;
		RETURN i
	END ArrayTypeDistance;

	(** compute the signature distance of a procedure and an actual parameter list
		- if any of the parameters are not compatible, the result is infinite
		- add up and return the distance over all parameters
	**)
	PROCEDURE Distance(system: Global.System; procedureType: SyntaxTree.ProcedureType; actualParameters: SyntaxTree.ExpressionList): LONGINT;
	VAR result: LONGINT; formalParameter: SyntaxTree.Parameter; actualParameter: SyntaxTree.Expression;
	distance: LONGINT; baseFormal,baseActual, to: SyntaxTree.Type; i: LONGINT;
	BEGIN
		IF actualParameters.Length() # (procedureType.numberParameters) THEN
			result := Infinity
		ELSE
			formalParameter := procedureType.firstParameter;
			i := 0;
			result := 0;
			(*! taken from paco, seems to not be 100% correct, check (in particular array part -> length of arrays??) *)
			WHILE (formalParameter # NIL) & (result # Infinity) DO
				actualParameter := actualParameters.GetExpression(i);

				ASSERT(formalParameter.type # NIL);
				IF (actualParameter.type = NIL) THEN distance := Infinity
				ELSE
					distance := TypeDistance(system,actualParameter.type.resolved,formalParameter.type.resolved,formalParameter.kind = SyntaxTree.VarParameter);
				END;
				IF distance = Infinity THEN
					result := Infinity;
				ELSE
					to := formalParameter.type.resolved;
					IF (formalParameter.kind = SyntaxTree.VarParameter) & (distance # 0) THEN
						IF (to IS SyntaxTree.MathArrayType) & (actualParameter.type.resolved IS SyntaxTree.MathArrayType) THEN
							(* already handled varpar *)
							(*
							baseActual := actualParameter.type.resolved(SyntaxTree.MathArrayType).arrayBase.resolved;
							baseFormal := to(SyntaxTree.MathArrayType).arrayBase.resolved;
							WHILE(baseActual IS SyntaxTree.MathArrayType) & (baseFormal IS SyntaxTree.MathArrayType) DO
								baseActual := baseActual(SyntaxTree.MathArrayType).arrayBase.resolved;
								baseFormal := baseFormal(SyntaxTree.MathArrayType).arrayBase.resolved;
							END;
							IF TypeDistance(system,baseActual,baseFormal,FALSE) # 0 THEN
								result := Infinity
							END;
							*)
							INC(result, distance);
						ELSIF (to IS SyntaxTree.ArrayType) & (to(SyntaxTree.ArrayType).length = NIL) & (to(SyntaxTree.ArrayType).arrayBase.resolved IS SyntaxTree.ByteType) THEN
							INC(result, distance);
						ELSIF (to IS SyntaxTree.ArrayType) & (actualParameter.type.resolved IS SyntaxTree.ArrayType) THEN
							baseActual := actualParameter.type.resolved(SyntaxTree.ArrayType).arrayBase.resolved;
							baseFormal := to(SyntaxTree.ArrayType).arrayBase.resolved;
							WHILE(baseActual IS SyntaxTree.ArrayType) & (baseFormal IS SyntaxTree.ArrayType) DO
								baseActual := baseActual(SyntaxTree.ArrayType).arrayBase.resolved;
								baseFormal := baseFormal(SyntaxTree.ArrayType).arrayBase.resolved;
							END;
							IF TypeDistance(system,baseActual,baseFormal,FALSE) # 0 THEN
								result := Infinity
							END;
						ELSE
							result := Infinity
						END;
					ELSE
						INC(result,distance);
					END;
				END;
				(*
				Printout.Info("actual=", actualParameter);
				Printout.Info("formal=", formalParameter);
				TRACE(result);
				*)
				formalParameter := formalParameter.nextParameter; INC(i);
			END;
		END;
		ASSERT(result >= 0);
		RETURN result
	END Distance;

	PROCEDURE ProcedureTypeDistance(system: Global.System; procedureType: SyntaxTree.ProcedureType; right: SyntaxTree.ProcedureType): LONGINT;
	VAR result: LONGINT; formalParameter, rightParameter: SyntaxTree.Parameter; distance: LONGINT; i: LONGINT;
	BEGIN
		IF right.numberParameters # (procedureType.numberParameters) THEN
			result := Infinity
		ELSE
			formalParameter := procedureType.firstParameter;
			rightParameter := right.firstParameter;
			i := 0;
			result := 0;
			IF right.isDelegate & ~procedureType.isDelegate THEN
				INC(result);
			ELSIF procedureType.isDelegate & ~right.isDelegate THEN
				result := Infinity;
			END;

			(*! taken from paco, seems to not be 100% correct, check (in particular array part -> length of arrays??) *)
			WHILE (formalParameter # NIL) & (result # Infinity) DO
				distance := TypeDistance(system,rightParameter.type.resolved,formalParameter.type.resolved,formalParameter.kind = SyntaxTree.VarParameter);
				IF distance = Infinity THEN
					result := Infinity;
				ELSE
					INC(result,distance);
				END;
				formalParameter := formalParameter.nextParameter;
				rightParameter := rightParameter.nextParameter;
			END;
		END;
		ASSERT(result >= 0);
		RETURN result
	END ProcedureTypeDistance;

	(** compute and return the distance between two types, used for computation of signature distance
		from -> to
	**)
	PROCEDURE TypeDistance(system: Global.System; from, to: SyntaxTree.Type; varpar: BOOLEAN): LONGINT;
	VAR i: LONGINT; ptr: SyntaxTree.PointerType;
	BEGIN

		i := Infinity;

		IF from = to THEN
			i := 0
		ELSIF (to = NIL) OR (from=NIL) THEN HALT(100); (* was: SYSTEM.ALL type, removed *)
		ELSIF to.SameType(from) THEN
			i := 0;
		ELSIF (from IS SyntaxTree.NilType) OR (to IS SyntaxTree.NilType) THEN
			i := Infinity;
		ELSIF (to IS SyntaxTree.ArrayType) & (to(SyntaxTree.ArrayType).length = NIL) & (to(SyntaxTree.ArrayType).arrayBase.resolved IS SyntaxTree.ByteType) THEN
			i := 10;
		ELSIF (from IS SyntaxTree.StringType) THEN
			IF (to IS SyntaxTree.ArrayType) & (to(SyntaxTree.ArrayType).length = NIL) & (to(SyntaxTree.ArrayType).arrayBase.resolved  IS SyntaxTree.CharacterType) THEN  i := 1  END
		ELSIF (from IS SyntaxTree.CharacterType) THEN
			IF (to IS SyntaxTree.CharacterType) & (to.sizeInBits = from.sizeInBits) THEN i := 0
			ELSIF (to IS SyntaxTree.ArrayType) & (to(SyntaxTree.ArrayType).length = NIL) & (to(SyntaxTree.ArrayType).arrayBase.resolved IS SyntaxTree.CharacterType) THEN  i := 1
			ELSIF to IS SyntaxTree.ByteType THEN i := 1 END
		ELSIF (from IS SyntaxTree.IntegerType) & (to IS SyntaxTree.ByteType) & (to.sizeInBits = from.sizeInBits) THEN
			i := 1
		ELSIF (from IS SyntaxTree.NilType) THEN
			IF (to IS SyntaxTree.AnyType) OR (to IS SyntaxTree.ObjectType) OR (to IS SyntaxTree.PointerType) OR (to IS SyntaxTree.ProcedureType) THEN i := 1 END
		(*
		ELSIF (from = NoType) THEN
			IF (to IS Delegate) THEN i := 1 END	(*special case: procedure -> proctype, not resolved yet*)
		*)
		ELSIF (from IS SyntaxTree.BasicType) THEN
			IF to IS SyntaxTree.BasicType THEN  i := Global.BasicTypeDistance(system,from(SyntaxTree.BasicType), to(SyntaxTree.BasicType)) END;
			IF varpar & (i # 0) THEN i := Infinity END;
		ELSIF (from IS SyntaxTree.ArrayType) THEN
			IF to IS SyntaxTree.ArrayType THEN i := ArrayTypeDistance(system,from(SyntaxTree.ArrayType), to(SyntaxTree.ArrayType)) END
		ELSIF (from IS SyntaxTree.RecordType) THEN
			IF to IS SyntaxTree.RecordType THEN i := RecordTypeDistance(from(SyntaxTree.RecordType), to (SyntaxTree.RecordType)) END
		ELSIF (from IS SyntaxTree.MathArrayType) THEN
			IF to IS SyntaxTree.MathArrayType THEN
				(*
				IF varpar & (from(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor) & (to(SyntaxTree.MathArrayType).form # SyntaxTree.Tensor) THEN
					i := Infinity;
				ELSE
				*)
					i := MathArrayTypeDistance(system,from(SyntaxTree.MathArrayType), to(SyntaxTree.MathArrayType),varpar)
				(*
				END;
				*)
			END
		ELSIF (from IS SyntaxTree.PointerType) THEN
			ptr := from(SyntaxTree.PointerType);
			IF (to IS SyntaxTree.AnyType) THEN i := 1
			ELSIF to IS SyntaxTree.PointerType THEN i := PointerTypeDistance(ptr, to(SyntaxTree.PointerType))
			(* ELSE i := TypeDistance(ptr.base, to); *)
			END
		ELSIF (from IS SyntaxTree.ProcedureType) THEN
			IF (to IS SyntaxTree.ProcedureType) THEN
				i := ProcedureTypeDistance(system, from(SyntaxTree.ProcedureType), to(SyntaxTree.ProcedureType));
			END;
		ELSIF (from IS SyntaxTree.PortType) THEN
			IF (to IS SyntaxTree.PortType) THEN
				IF (to.sizeInBits = from.sizeInBits) & (to(SyntaxTree.PortType).direction = from(SyntaxTree.PortType).direction) THEN
					i := 0;
				END;
			END;
		(*no procedure test, procedure must be the same*)
		END;
		RETURN i
	END TypeDistance;

	PROCEDURE IsIntegerType*(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		RETURN (type # NIL) & ((type IS SyntaxTree.IntegerType) OR (type IS SyntaxTree.AddressType) OR (type IS SyntaxTree.SizeType))
	END IsIntegerType;

	PROCEDURE IsAddressType*(type: SyntaxTree.Type; addressWidth: LONGINT): BOOLEAN;
	BEGIN
		RETURN (type # NIL) & ((type IS SyntaxTree.IntegerType) & (type(SyntaxTree.IntegerType).sizeInBits <= addressWidth)
					OR (type IS SyntaxTree.AddressType) OR (type IS SyntaxTree.SizeType)
					OR IsPointerType(type)
					)
	END IsAddressType;

	PROCEDURE IsSizeType(type: SyntaxTree.Type; addressWidth: LONGINT): BOOLEAN;
	BEGIN

		RETURN (type # NIL) & ((type.resolved IS SyntaxTree.IntegerType) & (type.resolved(SyntaxTree.IntegerType).sizeInBits <= addressWidth) OR (type.resolved IS SyntaxTree.SizeType))
	END IsSizeType;

	PROCEDURE IsSignedIntegerType*(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		RETURN (type # NIL) & (type IS SyntaxTree.IntegerType) & type(SyntaxTree.IntegerType).signed
	END IsSignedIntegerType;

	PROCEDURE IsUnsignedIntegerType*(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		RETURN (type # NIL) & (type IS SyntaxTree.IntegerType) & ~type(SyntaxTree.IntegerType).signed
	END IsUnsignedIntegerType;

	PROCEDURE IsIntegerValue(x: SyntaxTree.Expression; VAR value: Basic.Integer): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		IF (x.resolved # NIL) & (x.resolved IS SyntaxTree.IntegerValue) THEN
			value :=  x.resolved(SyntaxTree.IntegerValue).value;
			result := TRUE
		ELSE
			result := FALSE
		END;
		RETURN result
	END IsIntegerValue;

	PROCEDURE IsEnumerationValue(x: SyntaxTree.Expression; VAR value: Basic.Integer): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		IF (x.resolved # NIL) & (x.resolved IS SyntaxTree.EnumerationValue) THEN
			value :=  x.resolved(SyntaxTree.EnumerationValue).value;
			result := TRUE
		ELSE
			result := FALSE
		END;
		RETURN result
	END IsEnumerationValue;

	PROCEDURE IsRealValue(x: SyntaxTree.Expression; VAR value: LONGREAL): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		IF  (x.resolved # NIL) & (x.resolved IS SyntaxTree.RealValue) THEN
			value :=  x.resolved(SyntaxTree.RealValue).value;
			result := TRUE
		ELSE
			result := FALSE
		END;
		RETURN result
	END IsRealValue;

	PROCEDURE IsComplexValue(x: SyntaxTree.Expression; VAR realValue, imagValue: LONGREAL): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		IF  (x.resolved # NIL) & (x.resolved IS SyntaxTree.ComplexValue) THEN
			realValue :=  x.resolved(SyntaxTree.ComplexValue).realValue;
			imagValue :=  x.resolved(SyntaxTree.ComplexValue).imagValue;
			result := TRUE
		ELSE
			result := FALSE
		END;
		RETURN result
	END IsComplexValue;

	PROCEDURE IsCharacterValue(x: SyntaxTree.Expression; VAR value: CHAR): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		IF  (x.resolved # NIL) & (x.resolved IS SyntaxTree.CharacterValue) THEN
			value :=  x.resolved(SyntaxTree.CharacterValue).value;
			result := TRUE
		ELSE
			result := FALSE
		END;
		RETURN result
	END IsCharacterValue;

	PROCEDURE IsBooleanValue*(x: SyntaxTree.Expression; VAR value: BOOLEAN): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		IF  (x.resolved # NIL) & (x.resolved IS SyntaxTree.BooleanValue) THEN
			value :=  x.resolved(SyntaxTree.BooleanValue).value;
			result := TRUE
		ELSE
			result := FALSE
		END;
		RETURN result
	END IsBooleanValue;

	PROCEDURE IsSetValue(x: SyntaxTree.Expression; VAR value: Basic.Set): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		IF  (x.resolved # NIL) & (x.resolved IS SyntaxTree.SetValue) THEN
			value :=  x.resolved(SyntaxTree.SetValue).value;
			result := TRUE
		ELSE
			result := FALSE
		END;
		RETURN result
	END IsSetValue;

	PROCEDURE IsStringValue(x: SyntaxTree.Expression; VAR value: Scanner.StringType): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		IF  (x.resolved # NIL) & (x.resolved IS SyntaxTree.StringValue) THEN
			value :=  x.resolved(SyntaxTree.StringValue).value;
			result := TRUE
		ELSE
			result := FALSE
		END;
		RETURN result
	END IsStringValue;

	PROCEDURE Indexable(x: SyntaxTree.Type): BOOLEAN;
	BEGIN
		x := x.resolved;
		RETURN (x IS SyntaxTree.ArrayType) OR (x IS SyntaxTree.MathArrayType);
	END Indexable;

	PROCEDURE SameType(t1,t2: SyntaxTree.Type): BOOLEAN;
	BEGIN
		RETURN t1.SameType(t2.resolved);
	END SameType;

	PROCEDURE ArrayBase*(t: SyntaxTree.Type; max: LONGINT): SyntaxTree.Type;
	BEGIN
		IF t IS SyntaxTree.MathArrayType THEN
			WHILE (t # NIL) & (t IS SyntaxTree.MathArrayType) & ((t(SyntaxTree.MathArrayType).form # SyntaxTree.Tensor) OR (max = Infinity)) & (max > 0) DO
				t := Resolved(t(SyntaxTree.MathArrayType).arrayBase);
				IF (t # NIL) & (t IS SyntaxTree.PointerType) & (t(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.MathArrayType) THEN t := t(SyntaxTree.PointerType).pointerBase.resolved END;
				DEC(max);
			END;
		ELSIF t IS SyntaxTree.ArrayType THEN
			WHILE (t IS SyntaxTree.ArrayType) & (max > 0) DO
				t := t(SyntaxTree.ArrayType).arrayBase.resolved; DEC(max);
				IF (t IS SyntaxTree.PointerType) & (t(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.ArrayType) THEN t := t(SyntaxTree.PointerType).pointerBase.resolved END;
			END;
		END;
		RETURN t;
	END ArrayBase;

	PROCEDURE IsOpenArray*(type: SyntaxTree.Type; VAR base: SyntaxTree.Type): BOOLEAN;
	BEGIN
		type := type.resolved;
		IF (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).form = SyntaxTree.Open) THEN
			base := type(SyntaxTree.ArrayType).arrayBase;
			RETURN TRUE;
		END;
		RETURN FALSE;
	END IsOpenArray;

	PROCEDURE IsStaticArray*(type: SyntaxTree.Type; VAR base: SyntaxTree.Type; VAR dim :LONGINT): BOOLEAN;
	BEGIN
		type := type.resolved;
		IF (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).form = SyntaxTree.Static) THEN
			base := type(SyntaxTree.ArrayType).arrayBase;
			dim := type(SyntaxTree.ArrayType).staticLength;
			RETURN TRUE
		ELSE
			RETURN FALSE
		END;
	END IsStaticArray;

	PROCEDURE IsDynamicArray*(type: SyntaxTree.Type; VAR base: SyntaxTree.Type): BOOLEAN;
	BEGIN
		type := type.resolved;
		IF (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).form = SyntaxTree.SemiDynamic) THEN
			base := type(SyntaxTree.ArrayType).arrayBase;
			RETURN TRUE
		ELSE
			RETURN FALSE
		END;
	END IsDynamicArray;

	PROCEDURE Dimension*(t: SyntaxTree.Type; form: SET): LONGINT;
	VAR i: LONGINT;
	BEGIN
		i := 0;
		t := t.resolved;
		IF t IS SyntaxTree.MathArrayType THEN
			WHILE (t # NIL) & (t IS SyntaxTree.MathArrayType) & (t(SyntaxTree.MathArrayType).form IN form)  DO
				t := Resolved(t(SyntaxTree.MathArrayType).arrayBase); INC(i);
			END;
		ELSIF t IS SyntaxTree.ArrayType THEN
			WHILE(t IS SyntaxTree.ArrayType) & (t(SyntaxTree.ArrayType).form IN form) DO
				t := t(SyntaxTree.ArrayType).arrayBase.resolved; INC(i);
			END;
		END;
		RETURN i
	END Dimension;

	PROCEDURE IsVariable(expression: SyntaxTree.Expression): BOOLEAN;
	BEGIN
		RETURN expression.assignable;
	END IsVariable;

	PROCEDURE IsReferenceType*(kind: LONGINT; type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		type := type.resolved;
		RETURN (kind = SyntaxTree.VarParameter) OR (kind = SyntaxTree.ConstParameter) & ((type IS SyntaxTree.RecordType) OR (type IS SyntaxTree.ArrayType));
	END IsReferenceType;


	PROCEDURE IsReference*(symbol: SyntaxTree.Symbol): BOOLEAN;
	BEGIN
		WITH symbol:
			SyntaxTree.Parameter DO
				RETURN IsReferenceType(symbol.kind, symbol.type);
		| SyntaxTree.Variable DO
				RETURN IsReferenceType(symbol.kind, symbol.type);
		ELSE
			RETURN FALSE
		END;
	END IsReference;

	PROCEDURE IsPointerType*(type: SyntaxTree.Type): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		IF type = NIL THEN result := FALSE
		ELSE
		type := type.resolved;
		result :=  (type IS SyntaxTree.AnyType) OR (type IS SyntaxTree.PointerType) OR (type IS SyntaxTree.NilType)  OR (type  IS SyntaxTree.ObjectType)
		END;
		RETURN result
	END IsPointerType;

	PROCEDURE IsUnsafePointer*(type: SyntaxTree.Type): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		IF type = NIL THEN result := FALSE
		ELSE
		type := type.resolved;
		result :=  (type IS SyntaxTree.PointerType) & type(SyntaxTree.PointerType).isUnsafe OR
			(type IS SyntaxTree.MathArrayType) & (type(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor)
			& type(SyntaxTree.MathArrayType).isUnsafe;
		END;
		RETURN result
	END IsUnsafePointer;

	PROCEDURE IsDisposable*(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		RETURN (type # NIL) & (type.resolved IS SyntaxTree.PointerType) & (type.resolved(SyntaxTree.PointerType).isDisposable)
	END IsDisposable;

	PROCEDURE IsPointerToRecord(type: SyntaxTree.Type): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		IF type = NIL THEN result := FALSE
		ELSE
			type := type.resolved;
			result := (type IS SyntaxTree.PointerType) & (type(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.RecordType);
			result := result OR	(type IS SyntaxTree.RecordType) & (type(SyntaxTree.RecordType).pointerType # NIL);
			result := result OR (type IS SyntaxTree.ObjectType);
		END;
		RETURN result
	END IsPointerToRecord;

	PROCEDURE IsPointerToObject(type: SyntaxTree.Type): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		IF type = NIL THEN result := FALSE
		ELSE
			type := type.resolved;
			result := (type IS SyntaxTree.PointerType) & (type(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.RecordType)
				&  (type(SyntaxTree.PointerType).pointerBase.resolved(SyntaxTree.RecordType).isObject)
				;
			result := result OR	(type IS SyntaxTree.RecordType) & (type(SyntaxTree.RecordType).pointerType # NIL);
			result := result OR (type IS SyntaxTree.ObjectType);
		END;
		RETURN result
	END IsPointerToObject;

	PROCEDURE ContainsPointer*(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		IF type # NIL THEN
			RETURN type.resolved.hasPointers
		ELSE
			RETURN FALSE
		END;
	END ContainsPointer;

	PROCEDURE IsStringType*(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		IF type = NIL THEN RETURN FALSE END;
		type := type.resolved;
		RETURN (type IS SyntaxTree.StringType) OR (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).arrayBase.resolved IS SyntaxTree.CharacterType);
	END IsStringType;

	PROCEDURE IsCharacterType*(type: SyntaxTree.Type):BOOLEAN;
	BEGIN
		IF type = NIL THEN RETURN FALSE END;
		type := type.resolved;
		RETURN (type IS SyntaxTree.CharacterType) OR (type IS SyntaxTree.ByteType) OR (type IS SyntaxTree.StringType) & (type(SyntaxTree.StringType).length = 2)
	END IsCharacterType;

	PROCEDURE IsEnumerationType*(type: SyntaxTree.Type):BOOLEAN;
	BEGIN
		IF type = NIL THEN RETURN FALSE END;
		type := type.resolved;
		RETURN (type IS SyntaxTree.EnumerationType)
	END IsEnumerationType;

	PROCEDURE IsValidTypeTest(base,extension: SyntaxTree.Type): BOOLEAN;
	BEGIN
		base := base.resolved; extension := extension.resolved;
		IF ((base IS SyntaxTree.NumberType) OR (base IS SyntaxTree.AddressType) OR (base IS SyntaxTree.SizeType)) &
			((extension IS SyntaxTree.NumberType) OR (extension IS SyntaxTree.AddressType) OR (extension IS SyntaxTree.SizeType)) THEN
				RETURN TRUE;
		ELSE
			RETURN IsTypeExtension(base, extension);
		END;
	END IsValidTypeTest;

	(** cf. section "Type extension (base type)" in the language report **)
	PROCEDURE IsTypeExtension(base,extension: SyntaxTree.Type): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		ASSERT(base # NIL); ASSERT(extension # NIL);
		base := base.resolved; extension := extension.resolved;

		IF ( (base IS SyntaxTree.ObjectType) OR  (base IS SyntaxTree.AnyType)) & IsPointerToRecord(extension) THEN
			result := TRUE;
		ELSE
			IF (base IS SyntaxTree.PointerType) & (extension IS SyntaxTree.PointerType) THEN
				base := base(SyntaxTree.PointerType).pointerBase.resolved;
				extension := extension(SyntaxTree.PointerType).pointerBase.resolved;
			END;

			WHILE (extension # NIL) & (extension # base) DO
				IF extension IS SyntaxTree.RecordType THEN
					extension := extension(SyntaxTree.RecordType).baseType;
					IF (extension # NIL) THEN extension := extension.resolved END;
					IF (extension # NIL) & (extension IS SyntaxTree.PointerType) THEN
						extension := extension(SyntaxTree.PointerType).pointerBase.resolved;
					END;
				ELSE extension := NIL;
				END;
			END;
			result :=  (extension = base) & (extension IS SyntaxTree.RecordType);
		END;
		RETURN result
	END IsTypeExtension;

	(** check if base is the base enumeration type of extension **)
	PROCEDURE IsEnumerationExtension(base,extension: SyntaxTree.Type): BOOLEAN;
	BEGIN
		base := base.resolved; extension := extension.resolved;

		WHILE (extension # NIL) & (extension # base) DO
			IF extension IS SyntaxTree.EnumerationType THEN
				extension := extension(SyntaxTree.EnumerationType).enumerationBase;
				IF extension # NIL THEN extension := extension.resolved END;
			ELSE
				extension := NIL
			END;
		END;
		RETURN (extension = base) & (base IS SyntaxTree.EnumerationType);
	END IsEnumerationExtension;

	PROCEDURE IsCallable(expression: SyntaxTree.Expression): BOOLEAN;
	BEGIN
		IF expression IS SyntaxTree.ProcedureCallDesignator THEN
			RETURN TRUE
		ELSIF expression IS SyntaxTree.BuiltinCallDesignator THEN
			RETURN TRUE
		ELSIF expression IS SyntaxTree.InlineCallDesignator THEN
			RETURN TRUE
		ELSIF (expression.type # NIL) & (expression.type.resolved IS SyntaxTree.ProcedureType) THEN
			RETURN TRUE
		ELSE
			RETURN FALSE
		END
	END IsCallable;

	(** compute and return the distance of two record types
		returns the number of extension levels of from to to, returns infinite if to is not an extension of from
	**)
	PROCEDURE RecordTypeDistance(from, to: SyntaxTree.RecordType): LONGINT;
	VAR i: LONGINT; baseType: SyntaxTree.Type;
	BEGIN
		i := 0;
		WHILE (from # NIL) & (from # to) DO
			baseType :=  from.baseType;
			IF (baseType # NIL) THEN
				baseType := baseType.resolved;
				IF baseType IS SyntaxTree.PointerType THEN
					baseType := baseType(SyntaxTree.PointerType).pointerBase.resolved;
				END;
				IF baseType IS SyntaxTree.RecordType THEN
					from := baseType(SyntaxTree.RecordType);
				ELSE
					from := NIL;
				END;
			ELSE
				from := NIL
			END;
			INC(i)
		END;
		IF from = NIL THEN  i := Infinity  END;
		RETURN i
	END RecordTypeDistance;

	(** compute and return the distance of two pointer types **)
	PROCEDURE PointerTypeDistance(from, to: SyntaxTree.PointerType): LONGINT;
	BEGIN
		IF ~((to.pointerBase.resolved IS SyntaxTree.RecordType) & (from.pointerBase.resolved IS SyntaxTree.RecordType)) THEN
			RETURN Infinity;
		ELSE
			RETURN RecordTypeDistance(from.pointerBase.resolved(SyntaxTree.RecordType), to.pointerBase.resolved(SyntaxTree.RecordType));
		END;
	END PointerTypeDistance;

	(** check if expression contains a symbol designator pointing to a type declaration.
		- if so then enter type declaration into typeDeclaration and return true else return false
	**)
	PROCEDURE IsTypeDesignator(expression: SyntaxTree.Expression; VAR typeDeclaration: SyntaxTree.TypeDeclaration): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		result := FALSE;
		IF (expression # NIL) & (expression.type.resolved = SyntaxTree.typeDeclarationType) THEN
			result := TRUE;
			typeDeclaration := expression(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration)
		END;
		RETURN result
	END IsTypeDesignator;

	(** returns true if type is an extensible type (pointer to record, record, object or any), returns false otherwise **)
	PROCEDURE IsExtensibleType( type: SyntaxTree.Type): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		type := type.resolved;
		IF type IS SyntaxTree.PointerType THEN
			result := IsExtensibleType(type(SyntaxTree.PointerType).pointerBase.resolved);
		ELSIF (type IS SyntaxTree.AnyType) OR (type IS SyntaxTree.ObjectType)  THEN
			result := TRUE
		ELSIF (type IS SyntaxTree.NumberType) OR (type IS SyntaxTree.AddressType) OR (type IS SyntaxTree.SizeType) THEN
			result := TRUE
		ELSE
			result := type IS SyntaxTree.RecordType
		END;
		RETURN result
	END IsExtensibleType;

	PROCEDURE IsIndexOperator*(expression: SyntaxTree.Expression): BOOLEAN;
	VAR left: SyntaxTree.Expression; symbol: SyntaxTree.Symbol;
	BEGIN
		WITH expression: SyntaxTree.ProcedureCallDesignator DO
			left := expression.left;
			WITH left: SyntaxTree.SymbolDesignator DO
				symbol := left.symbol;
				WITH symbol: SyntaxTree.Operator DO
					RETURN symbol.name = "[]";
				ELSE
					RETURN FALSE
				END;
			ELSE
				RETURN FALSE
			END;
		ELSE
			RETURN FALSE
		END;
	END IsIndexOperator;

	PROCEDURE IsUnextensibleRecord(d: SyntaxTree.Expression): BOOLEAN;
	BEGIN
		RETURN (d.type.resolved IS SyntaxTree.RecordType) &
			(d IS SyntaxTree.SymbolDesignator) &
			( (d(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Variable)
			OR
			(d(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Parameter) & (d(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Parameter).kind = SyntaxTree.ValueParameter));

	END IsUnextensibleRecord;

	PROCEDURE IsExtensibleDesignator(d: SyntaxTree.Expression): BOOLEAN;
	BEGIN
		IF IsUnextensibleRecord(d) THEN
			RETURN FALSE
		ELSE RETURN IsExtensibleType(d.type.resolved)
		END;
	END IsExtensibleDesignator;

	PROCEDURE IsBasicType(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		type := type.resolved;
		IF (type IS SyntaxTree.PointerType) THEN
			RETURN TRUE
		ELSIF (type IS SyntaxTree.RecordType) & (type(SyntaxTree.RecordType).pointerType # NIL) (* object *) THEN
			RETURN TRUE
		ELSIF (type IS SyntaxTree.ProcedureType) THEN
			RETURN TRUE
		ELSIF (type IS SyntaxTree.BasicType) THEN
			RETURN TRUE
		END;
		RETURN FALSE
	END IsBasicType;

	PROCEDURE RecordBase*(record: SyntaxTree.RecordType): SyntaxTree.RecordType;
	VAR baseType: SyntaxTree.Type; recordType: SyntaxTree.RecordType;
	BEGIN
		baseType := record.baseType;
		IF (baseType # NIL) THEN
			baseType := baseType.resolved;
			IF  (baseType IS SyntaxTree.PointerType) THEN
				baseType := baseType(SyntaxTree.PointerType).pointerBase.resolved;
			END;
		END;
		IF (baseType # NIL) & (baseType IS SyntaxTree.RecordType) THEN
			recordType := baseType(SyntaxTree.RecordType);
		ELSE
			recordType := NIL;
		END;
		RETURN recordType
	END RecordBase;

	PROCEDURE FindSuperProcedure*(scope: SyntaxTree.RecordScope; procedure: SyntaxTree.Procedure): SyntaxTree.Procedure;
	VAR super: SyntaxTree.Procedure; operator: SyntaxTree.Operator; procedureType: SyntaxTree.Type; baseRecord: SyntaxTree.RecordType;
	BEGIN
		baseRecord := RecordBase(scope.ownerRecord);
		IF baseRecord = NIL THEN RETURN NIL END;
		scope := baseRecord.recordScope;
		procedureType := procedure.type.resolved;

		IF procedure IS SyntaxTree.Operator THEN
			operator := scope.firstOperator;
			WHILE (operator # NIL) & ((operator.name # procedure.name) OR ~SameType(procedureType, operator.type)) DO
				(*
				Printout.Info("not same ",procedureType);
				Printout.Info("with ",operator.type);
				*)
				operator := operator.nextOperator;
			END;
			super := operator;
		ELSE
			super := scope.firstProcedure;
			WHILE (super # NIL) & (super.name # procedure.name) DO
				super := super.nextProcedure;
			END;
		END;
		IF (super # NIL) & ((super.scope.ownerModule = procedure.scope.ownerModule) OR (SyntaxTree.Public * super.access # {})) THEN
			RETURN super
		ELSIF (super # NIL) & (FindSuperProcedure(scope,procedure)#NIL) THEN (* check if there is an exported supermethod, in which case return (non-exported) supermethod *)
			RETURN super
		ELSE
			RETURN FindSuperProcedure(scope,procedure);
		END;
	END FindSuperProcedure;

	PROCEDURE GetConstructor(record: SyntaxTree.RecordType): SyntaxTree.Procedure;
	VAR procedure: SyntaxTree.Procedure;
	BEGIN
		procedure := record.recordScope.constructor;
		IF procedure = NIL THEN
			record := RecordBase(record);
			IF record # NIL THEN
				procedure := GetConstructor(record)
			END;
		END;
		RETURN procedure;
	END GetConstructor;

	(* enter a case into a list of cases in a sorted way and check for collision *)
	PROCEDURE EnterCase(VAR root: SyntaxTree.CaseConstant; min,max: Basic.Integer): BOOLEAN;
	VAR prev,this,new: SyntaxTree.CaseConstant;
	BEGIN
		this := root;
		prev := NIL;
		WHILE (this # NIL) & (min > this.max) DO  prev := this; this := this.next  END;
		IF (this # NIL) & (max >= this.min) THEN	(* collision since min <=  this.max and max >= this.min *)
			RETURN FALSE
		ELSE
			IF (this # NIL) & (this.min = max+1) THEN
				this.min := min
			ELSIF (prev # NIL) & (min+1 = prev.max) THEN
				prev.max := min
			ELSE
				NEW(new);  new.min := min; new.max := max;
				new.next := this;
				IF prev = NIL THEN
					root := new;
				ELSE
					prev.next := new
				END
			END;
			RETURN TRUE
		END;
	END EnterCase;

	(** generate and return a new checker object, errors are entered into diagnostics **)
	PROCEDURE NewChecker*(diagnostics: Diagnostics.Diagnostics; verboseErrorMessage,cooperative: BOOLEAN; system: Global.System; symbolFileFormat: Formats.SymbolFileFormat; VAR importCache: SyntaxTree.ModuleScope; CONST backend: ARRAY OF CHAR): Checker;
	VAR checker: Checker;
	BEGIN
		NEW(checker, diagnostics,verboseErrorMessage,cooperative,system,symbolFileFormat,importCache,backend);
		RETURN checker
	END NewChecker;

	PROCEDURE NewWarnings*(diagnostics: Diagnostics.Diagnostics): Warnings;
	VAR warnings: Warnings;
	BEGIN
		NEW(warnings, diagnostics); RETURN warnings;
	END NewWarnings;

	PROCEDURE IsRangeType(type: SyntaxTree.Type): BOOLEAN;
	BEGIN RETURN (type # NIL) & (type.resolved IS SyntaxTree.RangeType);
	END IsRangeType;

	PROCEDURE IsMathArrayType(type: SyntaxTree.Type): BOOLEAN;
	BEGIN RETURN (type # NIL) & (type.resolved IS SyntaxTree.MathArrayType);
	END IsMathArrayType;

	PROCEDURE IsArrayType(type: SyntaxTree.Type): BOOLEAN;
	BEGIN RETURN (type # NIL) & (type.resolved IS SyntaxTree.ArrayType);
	END IsArrayType;

	PROCEDURE IsComplexType(type: SyntaxTree.Type): BOOLEAN;
	BEGIN RETURN (type # NIL) & (type.resolved IS SyntaxTree.ComplexType);
	END IsComplexType;

	PROCEDURE IsStaticRange(x: SyntaxTree.Expression; VAR firstValue, lastValue, stepValue: Basic.Integer): BOOLEAN;
	VAR
		result: BOOLEAN;
		rangeExpression: SyntaxTree.RangeExpression;
	BEGIN
		IF x IS SyntaxTree.RangeExpression THEN
			rangeExpression := x(SyntaxTree.RangeExpression);
			result := TRUE;
			IF ~IsIntegerValue(rangeExpression.first, firstValue) THEN result := FALSE END;
			IF ~IsIntegerValue(rangeExpression.last, lastValue) THEN result := FALSE END;
			IF ~IsIntegerValue(rangeExpression.step, stepValue) THEN result := FALSE END
		ELSE
			result := FALSE
		END;
		RETURN result
	END IsStaticRange;

	(** whether a type is a math array of tensor form **)
	PROCEDURE IsTensor(type: SyntaxTree.Type): BOOLEAN;
	BEGIN RETURN (type.resolved IS SyntaxTree.MathArrayType) & (type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor)
	END IsTensor;

	PROCEDURE IsStaticMathArray*(type: SyntaxTree.Type; VAR length: LONGINT; VAR baseType: SyntaxTree.Type): BOOLEAN;
	BEGIN
		IF (type IS SyntaxTree.MathArrayType) & (type(SyntaxTree.MathArrayType).form = SyntaxTree.Static) THEN
			length := type(SyntaxTree.MathArrayType).staticLength;
			baseType := type(SyntaxTree.MathArrayType).arrayBase.resolved;
			RETURN TRUE
		ELSE
			RETURN FALSE
		END;
	END IsStaticMathArray;

	PROCEDURE SymbolHasAddress*(CONST symbol: SyntaxTree.Symbol): BOOLEAN;
	BEGIN
		WITH symbol:
		SyntaxTree.Variable DO RETURN TRUE
		|SyntaxTree.Parameter DO RETURN TRUE
		|SyntaxTree.Procedure DO RETURN TRUE
		|SyntaxTree.Alias DO RETURN HasAddress(symbol.expression)
		ELSE
			RETURN FALSE
		END;
	END SymbolHasAddress;

	PROCEDURE HasAddress*(CONST expression: SyntaxTree.Expression): BOOLEAN;
	BEGIN
		IF expression = NIL THEN RETURN FALSE END;
		WITH expression:
		SyntaxTree.SymbolDesignator DO RETURN SymbolHasAddress(expression.symbol)
		|SyntaxTree.ResultDesignator DO RETURN TRUE;
		|SyntaxTree.IndexDesignator DO RETURN TRUE;
		|SyntaxTree.DereferenceDesignator DO RETURN TRUE;
		|SyntaxTree.TypeGuardDesignator DO RETURN TRUE;
		|SyntaxTree.StringValue DO RETURN TRUE;
		|SyntaxTree.BuiltinCallDesignator DO RETURN (expression.id = Global.systemVal) & HasAddress(expression.parameters.GetExpression(1))
		ELSE
			RETURN FALSE
		END;
	END HasAddress;

	PROCEDURE IsLocalVariable*(e: SyntaxTree.Expression): BOOLEAN;
	VAR d: SyntaxTree.Designator; symbol: SyntaxTree.Symbol;
	BEGIN
		IF (e IS SyntaxTree.Designator) THEN
			d := e(SyntaxTree.Designator);
			WHILE (d # NIL) & ~(d IS SyntaxTree.SymbolDesignator) DO
				IF d IS SyntaxTree.DereferenceDesignator THEN (* on heap *) RETURN FALSE END;
				e := d.left;
				IF (e # NIL) & (e IS SyntaxTree.Designator) THEN d := e(SyntaxTree.Designator) ELSE d := NIL END;
			END;
			IF d # NIL THEN
				symbol := d(SyntaxTree.SymbolDesignator).symbol;
				RETURN (symbol.scope IS SyntaxTree.ProcedureScope) & (symbol.externalName = NIL);
			END;
		END;
		RETURN FALSE;
	END IsLocalVariable;

	PROCEDURE IsStaticProcedure*(procedure: SyntaxTree.Procedure): BOOLEAN;
	BEGIN
		IF procedure.scope IS SyntaxTree.RecordScope THEN
			RETURN (procedure.super = NIL) & ((procedure.isFinal) OR (procedure.access * SyntaxTree.Public = {}) & ~procedure.isOverwritten)
		ELSE
			RETURN TRUE
		END;
	END IsStaticProcedure;

	PROCEDURE InMethodTable*(procedure: SyntaxTree.Procedure): BOOLEAN;
	CONST OptimizeMethodTable = FALSE;
	BEGIN
		RETURN ~OptimizeMethodTable OR IsStaticProcedure(procedure)
	END InMethodTable;

	PROCEDURE CanPassInRegister*(system: Global.System; type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		type := type.resolved;
		IF (type IS SyntaxTree.BasicType) & ~type.IsPointer() & ~type.IsComposite() OR (type IS SyntaxTree.PortType) THEN
			RETURN TRUE
		ELSIF system.CanPassInRegister # NIL THEN
			RETURN system.CanPassInRegister(type);
		ELSE
			RETURN FALSE
		END;
	END CanPassInRegister;


	PROCEDURE ReturnedAsParameter*(system: Global.System; type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		IF type = NIL THEN RETURN FALSE
		ELSE
			type := type.resolved;
			RETURN (type IS SyntaxTree.RecordType) OR (type IS SyntaxTree.RangeType) OR (type IS SyntaxTree.ComplexType) OR (type IS SyntaxTree.ProcedureType) OR IsPointerType(type)
				OR (type IS SyntaxTree.ArrayType) OR (type IS SyntaxTree.MathArrayType) & ~CanPassInRegister(system,type);
		END
	END ReturnedAsParameter;

	PROCEDURE StructuredReturnType*(system: Global.System; procedureType: SyntaxTree.ProcedureType): BOOLEAN;
	BEGIN
		RETURN (procedureType # NIL) & (procedureType.callingConvention=SyntaxTree.OberonCallingConvention) & ReturnedAsParameter(system,procedureType.returnType);
	END StructuredReturnType;


END FoxSemanticChecker.

System.FreeDownTo FoxSemanticChecker ~

System.FreeDownTo FoxIntermediateBackend ~
