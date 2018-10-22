MODULE ModuleParser;	(** AUTHOR "mb"; PURPOSE "Active Oberon parser for use with ModuleTrees **)
(**
 * Notes:
 *	- The Module node's parent is the module node itself
 *)

IMPORT
	Strings, Files, Streams, Diagnostics, FoxScanner, KernelLog, Texts, TextUtilities;

CONST
	(* visibilities *)
	Public* = 1;
	PublicRO* = 2;
	Private* = 3;

	(* block modifiers *)
	Exclusive* = 1;
	Active* = 2;
	Safe* = 3;
	Priority* = 4;
	Unchecked* = 5;
	Uncooperative* = 6;
	HasExclusiveBlock* = 7;
	(* procedure modifiers (in addition to block modifiers) *)
	Overwrite* = 8; (* procedure overwrites procedure in superclass *)
	Overwritten* = 9; (* procedure is overwritten in subclass *)
	Interrupt* = 10; (* procedure is an interrupt handler that might be called asynchronously *)

	ExclusiveStr = "EXCLUSIVE";
	ActiveStr = "ACTIVE";
	RealtimeStr = "REALTIME";
	SafeStr = "SAFE";
	PriorityStr = "PRIORITY";
	UncheckedStr = "UNCHECKED";
	UncooperativeStr = "UNCOOPERATIVE";
	NoPAFStr = "NOPAF"; FixedStr = "FIXED"; AlignedStr = "FIXED";
	DynamicStr = "DYNAMIC"; InterruptStr = "INTERRUPT"; PCOffsetStr = "PCOFFSET";


TYPE
	InfoItem* = OBJECT
	VAR
		name*: Strings.String;
		pos*: LONGINT;
	END InfoItem;

	Node* = OBJECT
	VAR
		parent- : Node;

		PROCEDURE GetModule*() : Module;
		VAR node : Node; module : Module;
		BEGIN
			module := NIL;
			node := SELF;
			WHILE (node # NIL) & (node.parent # node) DO node := node.parent; END;
			IF (node # NIL) THEN
				module := node (Module);
			END;
			RETURN module;
		END GetModule;

		PROCEDURE &Init*(parent : Node);
		BEGIN
			SELF.parent := parent;
		END Init;

	END Node;

	NodeList* = OBJECT(Node);
	VAR
		next*: NodeList;

	END NodeList;

	Import* = OBJECT (NodeList)
	VAR
		ident*, alias*, context*: InfoItem;
	END Import;

	Definition* = OBJECT (NodeList)
	VAR
		ident*: InfoItem;
		refines*: Qualident;
		procs*: ProcHead;
	END Definition;

	Type* = OBJECT(Node)
	VAR
		qualident*: Qualident;
		array*: Array;
		record*: Record;
		pointer*: Pointer;
		object*: Object;
		enum*: Enum;
		cell*: Cell;
		port*: Port;
		procedure*: Procedure;
	END Type;

	Array* = OBJECT(Node)
	VAR
		open*: BOOLEAN;
		len*: InfoItem;
		base*: Type;
	END Array;

	Record* = OBJECT(Node)
	VAR
		super*: Qualident;
		superPtr* : Record;
		fieldList*: FieldDecl;
	END Record;

	FieldDecl* = OBJECT (NodeList)
	VAR
		identList*: IdentList;
		type*: Type;
	END FieldDecl;

	Pointer* = OBJECT(Node)
	VAR
		type*: Type;
	END Pointer;

	Enum* = OBJECT(Node)
	VAR identList*: IdentList;
	END Enum;

	Port*= OBJECT(Node)
	END Port;

	Cell*= OBJECT(Node)
	VAR
		modifiers* : SET;
		declSeq*: DeclSeq;
		bodyPos- : LONGINT;
		formalPars*: FormalPars;

		PROCEDURE FindProcDecl*(CONST name : ARRAY OF CHAR) : ProcDecl;
		VAR procDecl : ProcDecl;
		BEGIN
			IF (declSeq # NIL) THEN
				procDecl := declSeq.FindProcDecl(name);
			ELSE
				procDecl := NIL;
			END;
			RETURN procDecl;
		END FindProcDecl;

	END Cell;

	Object* = OBJECT(Node)
	VAR
		super*, implements*: Qualident;
		superPtr* : Object;
		modifiers* : SET;
		declSeq*: DeclSeq;
		bodyPos- : LONGINT;

		PROCEDURE FindProcDecl*(CONST name : ARRAY OF CHAR) : ProcDecl;
		VAR procDecl : ProcDecl;
		BEGIN
			IF (declSeq # NIL) THEN
				procDecl := declSeq.FindProcDecl(name);
			ELSE
				procDecl := NIL;
			END;
			RETURN procDecl;
		END FindProcDecl;

	END Object;

	Procedure* = OBJECT(Node)
	VAR
		delegate*: BOOLEAN;
		formalPars*: FormalPars;
	END Procedure;

	DeclSeq* = OBJECT (NodeList)
	VAR
		constDecl*: ConstDecl;
		typeDecl*: TypeDecl;
		varDecl*: VarDecl;
		procDecl*: ProcDecl;

		PROCEDURE FindProcDecl*(CONST name : ARRAY OF CHAR) : ProcDecl;
		VAR pd : ProcDecl;
		BEGIN
			pd := procDecl;
			WHILE (pd # NIL) & (pd.head.identDef.ident.name^ # name) DO
				IF (pd.next # NIL) THEN
					pd := pd.next (ProcDecl);
				ELSE
					pd := NIL;
				END;
			END;
			ASSERT((pd = NIL) OR (pd.head.identDef.ident.name^ = name));
			RETURN pd;
		END FindProcDecl;

		PROCEDURE FindTypeDecl*(CONST name : ARRAY OF CHAR) : TypeDecl;
		VAR td : TypeDecl;
		BEGIN
			td := typeDecl;
			WHILE (td # NIL) & (td.identDef.ident.name^ # name) DO
				IF (td.next # NIL) THEN
					td := td.next (TypeDecl);
				ELSE
					td := NIL;
				END;
			END;
			ASSERT((td = NIL) OR (td.identDef.ident.name^ = name));
			RETURN td;
		END FindTypeDecl;

	END DeclSeq;

	ConstDecl* = OBJECT (NodeList)
	VAR
		identDef*: IdentDef;
		constExpr*: Expr;
		expr*: InfoItem;
	END ConstDecl;

	TypeDecl* = OBJECT (NodeList)
	VAR
		identDef*: IdentDef;
		type*: Type;
	END TypeDecl;

	VarDecl* = OBJECT (NodeList)
	VAR
		identList*: IdentList;
		type*: Type;
	END VarDecl;

	ProcDecl* = OBJECT (NodeList)
	VAR
		head*: ProcHead;
		declSeq*: DeclSeq;
		bodyPos- : LONGINT;
	END ProcDecl;

	ProcHead* = OBJECT (NodeList)
	VAR
		sysFlag*: InfoItem;
		constructor*, inline*, operator*: BOOLEAN;
		modifiers* : SET;
		identDef*: IdentDef;
		formalPars*: FormalPars;
	END ProcHead;

	FormalPars* = OBJECT(Node)
	VAR
		fpSectionList*: FPSection;
		returnType*: Type;
	END FormalPars;

	FPSection* = OBJECT (NodeList)
	VAR
		var*, const*: BOOLEAN;
		identList*: IdentList;
		type*: Type;
	END FPSection;

	Expr* = OBJECT (NodeList)
	VAR
		simpleExprL*, simpleExprR*: SimpleExpr;
		relation*: InfoItem;
	END Expr;

	SimpleExpr* = OBJECT (NodeList)
	VAR
		sign*: InfoItem;
		termL*, termR*: Term;
		addOp*: AddOp;
	END SimpleExpr;

	Term* = OBJECT (NodeList)
	VAR
		factorL*, factorR*: Factor;
		mulOp*: MulOp;
	END Term;

	Factor* = OBJECT (NodeList)
	VAR
		designator*: Designator;
		number*, string*, nil*, bool*: InfoItem;
		set*: Element;
		expr*: Expr;
		factor*: Factor;
	END Factor;

	Designator* = OBJECT (NodeList)
	VAR
		qualident*: Qualident;
		ident*, arrowUp*: InfoItem;
		exprList*: Expr;
	END Designator;

	Qualident* = OBJECT (NodeList)
	VAR
		ident*: InfoItem;
	END Qualident;

	Element* = OBJECT (NodeList)
	VAR
		expr*, upToExpr*: Expr;
	END Element;

	MulOp* = OBJECT (NodeList)
	VAR
		op*: InfoItem;
	END MulOp;

	AddOp* = OBJECT (NodeList)
	VAR
		op*: InfoItem;
	END AddOp;

	IdentDef* = OBJECT
	VAR
		ident*: InfoItem;
		vis*: SHORTINT;
		initializer*: InfoItem;
		external*: Strings.String;
	END IdentDef;

	IdentList* = OBJECT (NodeList)
	VAR
		identDef*: IdentDef;
	END IdentList;

	Module* = OBJECT(Node)
	VAR
		ident*, context*: InfoItem;
		importList*: Import;
		modifiers* : SET;
		definitions*: Definition;
		declSeq*: DeclSeq;
		bodyPos- : LONGINT;
		hasError-: BOOLEAN;
		resolved* : BOOLEAN;

		PROCEDURE FindTypeDecl*(CONST name : ARRAY OF CHAR) : TypeDecl;
		VAR typeDecl : TypeDecl;
		BEGIN
			IF (declSeq # NIL) THEN
				typeDecl := declSeq.FindTypeDecl(name);
			ELSE
				typeDecl := NIL;
			END;
			RETURN typeDecl;
		END FindTypeDecl;

		PROCEDURE FindImport*(CONST name : ARRAY OF CHAR) : Import;
		VAR import : Import;
		BEGIN
			import := importList;
			WHILE (import # NIL) & ((import.ident = NIL) OR (import.ident.name^ # name)) DO
				IF (import.next # NIL) THEN
					import := import.next (Import);
				ELSE
					import := NIL;
				END;
			END;
			RETURN import;
		END FindImport;

	END Module;

	Parser = OBJECT
	VAR
		token : FoxScanner.Token;
		scanner: FoxScanner.Scanner;
		hasError: BOOLEAN;

		PROCEDURE & Init*(scanner: FoxScanner.Scanner);
		BEGIN
			ASSERT(scanner # NIL);
			SELF.scanner := scanner;
			hasError := FALSE;
		END Init;

		PROCEDURE NextToken;
		VAR ignore : BOOLEAN;
		BEGIN
			ignore := scanner.GetNextToken(token);
			WHILE (token.symbol = FoxScanner.Comment) DO ignore := scanner.GetNextToken(token); END;
		END NextToken;

		PROCEDURE ModuleP(VAR module: Module);
		VAR
			modName: FoxScanner.IdentifierString;
			definition: Definition;
		BEGIN
			NextToken;
			IF (token.symbol = FoxScanner.Module) OR (token.symbol = FoxScanner.CellNet) THEN
				NEW(module, NIL); module.parent := module;
				NextToken;
				IF token.symbol = FoxScanner.Identifier THEN
					NEW(module.ident);
					COPY(token.identifierString, modName);
					module.ident.name := Strings.NewString(token.identifierString);
					module.ident.pos := token.position.start;
				END;
				NextToken;
				IF token.symbol = FoxScanner.In THEN
					NextToken;
					IF token.symbol = FoxScanner.Identifier THEN
						NEW(module.context);
						module.context.name := Strings.NewString(token.identifierString);
						module.context.pos := token.position.start;
					END;
					Check (FoxScanner.Identifier);
				END;
				IF token.symbol = FoxScanner.LeftBrace THEN
					WHILE (token.symbol # FoxScanner.Semicolon) & (token.symbol # FoxScanner.EndOfText) DO NextToken END;
				END;
				Check(FoxScanner.Semicolon);
				IF token.symbol = FoxScanner.Import THEN
					NEW(module.importList, module);
					ImportListP(module.importList);
				END;
				WHILE token.symbol = FoxScanner.Definition DO
					NEW(definition, module);
					DefinitionP(definition);
					IF module.definitions = NIL THEN module.definitions := definition
					ELSE AppendLast(module.definitions, definition)
					END;
				END;
				IF 	(token.symbol = FoxScanner.Const) OR (token.symbol = FoxScanner.Type) OR
					(token.symbol = FoxScanner.Var) OR (token.symbol = FoxScanner.Procedure) OR (token.symbol = FoxScanner.Operator) THEN
					NEW(module.declSeq, module);
					DeclSeqP(module.declSeq);
				END;
				IF (token.symbol = FoxScanner.Begin) THEN
					module.bodyPos := token.position.start;
				ELSE
					module.bodyPos := 0;
				END;
				BodyP(FALSE, module.modifiers);
				IF (token.symbol = FoxScanner.Identifier) & (token.identifierString = modName) THEN
					(* correct *)
				ELSE
					(* maybe missing END or wrong module name *)
					hasError := TRUE;
					KernelLog.String("err3: "); KernelLog.Int(token.position.start, 0); KernelLog.Ln;
				END;
				module.hasError := hasError;
			END;
		END ModuleP;

		PROCEDURE ImportListP(import: Import);
		VAR newImport: Import;
		BEGIN
			NextToken;
			WHILE token.symbol = FoxScanner.Identifier DO
				NEW(import.ident);
				import.ident.name := Strings.NewString(token.identifierString);
				import.ident.pos := token.position.start;
				NextToken;	(* avoids endless loop *)
				IF token.symbol = FoxScanner.Becomes THEN
					NextToken;
					IF token.symbol = FoxScanner.Identifier THEN
						NEW(import.alias);
						import.alias.name := Strings.NewString(token.identifierString);
						import.alias.pos := token.position.start;
						NextToken;
					ELSE
						(* Error *)
						hasError := TRUE;
						KernelLog.String("err2: "); KernelLog.Int(token.position.start, 0); KernelLog.Ln;
					END;
				END;
				IF token.symbol = FoxScanner.In THEN
					NextToken;
					IF token.symbol = FoxScanner.Identifier THEN
						NEW(import.context);
						import.context.name := Strings.NewString(token.identifierString);
						import.context.pos := token.position.start;
					END;
					Check (FoxScanner.Identifier);
				END;
				IF token.symbol = FoxScanner.Comma THEN
					NextToken;
				END;
				NEW(newImport, import.parent);
				import.next := newImport;
				import := newImport;
			END;
			Check(FoxScanner.Semicolon);
		END ImportListP;

		PROCEDURE DefinitionP(definition: Definition);
		VAR
			procHead: ProcHead;
		BEGIN
			IF token.symbol = FoxScanner.Definition THEN
				NextToken;
				IF token.symbol = FoxScanner.Identifier THEN
					NEW(definition.ident);
					definition.ident.name := Strings.NewString(token.identifierString);
					definition.ident.pos := token.position.start;
					NextToken;
				END;
				WHILE token.symbol = FoxScanner.Semicolon DO NextToken END;
		(*?		IF token.symbol = FoxScanner.Refines THEN
					NextToken;
					NEW(definition.refines, definition);
					QualidentP(definition.refines);
				END; *)
				WHILE (token.symbol = FoxScanner.Procedure) OR (token.symbol = FoxScanner.Operator) DO
					NEW(procHead, definition);
					NextToken;
					ProcHeadP(procHead);
					IF definition.procs = NIL THEN definition.procs := procHead
					ELSE AppendLast(definition.procs, procHead)
					END;
					Check(FoxScanner.Semicolon);
				END;
				Check(FoxScanner.End);
				Check(FoxScanner.Identifier);
				WHILE token.symbol = FoxScanner.Semicolon DO NextToken END;
			END;
		END DefinitionP;

		PROCEDURE DeclSeqP(declSeq: DeclSeq);
		VAR
			constDecl: ConstDecl;
			typeDecl: TypeDecl;
			varDecl: VarDecl;
			procDecl: ProcDecl;

			PROCEDURE CheckEndOrSemicolon;
			BEGIN
				IF token.symbol # FoxScanner.End THEN
					REPEAT Check(FoxScanner.Semicolon) UNTIL token.symbol # FoxScanner.Semicolon
				END;
			END CheckEndOrSemicolon;

		BEGIN
			LOOP
				CASE token.symbol OF
				| FoxScanner.Const:
					NextToken;
					WHILE token.symbol = FoxScanner.Identifier DO
						NEW(constDecl, declSeq);
						ConstDeclP(constDecl);
						IF declSeq.constDecl = NIL THEN declSeq.constDecl := constDecl;
						ELSE AppendLast(declSeq.constDecl, constDecl);
						END;
						CheckEndOrSemicolon;
						(*Check(FoxScanner.Semicolon);*)
					END;
				| FoxScanner.Type:
					NextToken;
					WHILE token.symbol = FoxScanner.Identifier DO
						NEW(typeDecl, declSeq);
						TypeDeclP(typeDecl);
						IF declSeq.typeDecl = NIL THEN declSeq.typeDecl := typeDecl;
						ELSE AppendLast(declSeq.typeDecl, typeDecl);
						END;
						CheckEndOrSemicolon;
						(*Check(FoxScanner.Semicolon);*)
					END;
				| FoxScanner.Var:
					NextToken;
					WHILE token.symbol = FoxScanner.Identifier DO
						NEW(varDecl, declSeq);
						VarDeclP(varDecl);
						IF declSeq.varDecl = NIL THEN declSeq.varDecl := varDecl;
						ELSE AppendLast(declSeq.varDecl, varDecl);
						END;
						CheckEndOrSemicolon;
						(*Check(FoxScanner.Semicolon);*)
					END;
				| FoxScanner.Procedure, FoxScanner.Operator:
					WHILE (token.symbol = FoxScanner.Procedure) OR (token.symbol = FoxScanner.Operator) DO
						NextToken;
						NEW(procDecl, declSeq);
						ProcDeclP(procDecl);
						IF procDecl.head = NIL THEN
							procDecl := NIL
						ELSE
							IF declSeq.procDecl = NIL THEN declSeq.procDecl := procDecl;
							ELSE AppendLast(declSeq.procDecl, procDecl);
							END;
						END;
						CheckEndOrSemicolon;
						(*Check(FoxScanner.Semicolon);*)
					END;
				ELSE
					EXIT;
				END;
			END;
		END DeclSeqP;

		PROCEDURE ConstDeclP(const: ConstDecl);
		BEGIN
			NEW(const.identDef);
			IdentDefP(const.identDef);
			Check(FoxScanner.Equal);
			(* NEW(const.constExpr);
			ExprP(const.constExpr); *)
			NEW(const.expr);
			ConstExprP(FoxScanner.Semicolon, -1, const.expr);
		END ConstDeclP;

		PROCEDURE TypeDeclP(type: TypeDecl);
		BEGIN
			NEW(type.identDef);
			IdentDefP(type.identDef);
			Check(FoxScanner.Equal);
			NEW(type.type, type);
			TypeP(type.type);
		END TypeDeclP;

		PROCEDURE VarDeclP(var: VarDecl);
		VAR
			identDef: IdentDef;
			identList: IdentList;
			
			PROCEDURE Initializer;
			VAR expr: InfoItem;
			BEGIN
				Check (FoxScanner.Becomes); NEW (expr);
				ConstExprP(FoxScanner.Colon, FoxScanner.Comma, expr);
			END Initializer;
			
		BEGIN
			(*SysFlag;*)
			NEW(var.identList, var);
			NEW(var.identList.identDef);
			IdentDefP(var.identList.identDef);
			SysFlag;
			IF token.symbol = FoxScanner.Becomes THEN Initializer END;
			WHILE token.symbol = FoxScanner.Comma DO
				NextToken;	(* avoids endless loop *)
				NEW(identDef);
				IdentDefP(identDef);
				SysFlag;
				IF token.symbol = FoxScanner.Becomes THEN Initializer END;
				NEW(identList, var);
				identList.identDef := identDef;
				AppendLast(var.identList, identList);
			END;
			Check(FoxScanner.Colon);
			NEW(var.type, var);
			TypeP(var.type);
		END VarDeclP;

		PROCEDURE ProcDeclP(proc: ProcDecl);
		VAR
			declSeq: DeclSeq;
		BEGIN
			NEW(proc.head, proc);
			ProcHeadP(proc.head);
			IF proc.head.identDef = NIL THEN proc.head := NIL; RETURN END;
			IF proc.head.identDef.external # NIL THEN RETURN END;
			Check(FoxScanner.Semicolon);
			IF 	(token.symbol = FoxScanner.Const) OR (token.symbol = FoxScanner.Var) OR
				(token.symbol = FoxScanner.Type) OR (token.symbol = FoxScanner.Procedure) OR (token.symbol = FoxScanner.Operator) THEN
				NEW(declSeq, proc);
				DeclSeqP(declSeq);
				IF proc.declSeq = NIL THEN proc.declSeq := declSeq;
				ELSE AppendLast(proc.declSeq, declSeq);
				END;
			END;
			IF (token.symbol = FoxScanner.Begin) THEN
				proc.bodyPos := token.position.start;
			ELSE
				proc.bodyPos := 0;
			END;
			BodyP(FALSE, proc.head.modifiers);
			NextToken;	(* skip ident *)
		END ProcDeclP;

		PROCEDURE ProcHeadP(head: ProcHead);
		VAR forward: BOOLEAN;
		BEGIN
			ProcedureModifierP(head);
			(*SysFlag;*)

			CASE token.symbol OF
			| FoxScanner.Minus: head.inline := TRUE; NextToken;
			| FoxScanner.And: head.constructor := TRUE; NextToken;
			| FoxScanner.Times: (* ignore *) NextToken;
			| FoxScanner.Not: (* ignore *) NextToken;
			| FoxScanner.Arrow: (* ignore *) NextToken; forward := TRUE;
			| FoxScanner.String: head.operator := TRUE;
			| FoxScanner.Number: IF token.numberType = FoxScanner.Character THEN head.operator := TRUE END;
			ELSE
			END;

			NEW(head.identDef);
			IdentDefP(head.identDef);
			OSAIrq;		(* tk: Compatibility to OSACompiler*)

			IF token.symbol = FoxScanner.LeftParenthesis THEN
				NEW(head.formalPars, head);
				FormalParsP(head.formalPars);
			END;
			IF forward THEN
				head.identDef := NIL;
				head.formalPars := NIL;
			END;
		END ProcHeadP;

		PROCEDURE SysFlag;
		VAR ignore: InfoItem;
		BEGIN
			IF token.symbol = FoxScanner.LeftBrace THEN
				NextToken;
				IF token.symbol # FoxScanner.RightBrace THEN
					LOOP
						Check(FoxScanner.Identifier);
						IF (token.symbol = FoxScanner.LeftParenthesis) THEN
							NextToken;
							NEW (ignore);
							ConstExprP	 (FoxScanner.RightParenthesis, -1, ignore);
							Check (FoxScanner.RightParenthesis);
						ELSIF  (token.symbol = FoxScanner.Equal) THEN
							NextToken;
							NEW (ignore);
							ConstExprP	 (FoxScanner.RightBrace, FoxScanner.Comma, ignore);
						END;
						IF token.symbol # FoxScanner.Comma THEN EXIT END;
						NextToken;
					END;
				END;
				Check(FoxScanner.RightBrace);
			END;
		END SysFlag;

		(* tk: For OSA Compatibility *)
		PROCEDURE OSAIrq;
		BEGIN
			IF token.symbol = FoxScanner.LeftBracket THEN
				NextToken;
				Check(FoxScanner.Number);
				Check(FoxScanner.RightBracket);
			END;
		END OSAIrq;

		PROCEDURE FormalParsP(pars: FormalPars);
		VAR
			fpSection: FPSection;
		BEGIN
			NextToken;
			IF (token.symbol = FoxScanner.Var) OR (token.symbol = FoxScanner.Const) OR (token.symbol = FoxScanner.Identifier) THEN
				NEW(pars.fpSectionList, pars);
				FPSectionP(pars.fpSectionList);
				WHILE token.symbol = FoxScanner.Semicolon DO
					NextToken;	(* avoids endless loop *)
					NEW(fpSection, pars.fpSectionList);
					FPSectionP(fpSection);
					AppendLast(pars.fpSectionList, fpSection);
				END;
			END;
			Check(FoxScanner.RightParenthesis);
			IF token.symbol = FoxScanner.Colon THEN
				NextToken;
				SysFlag;
				NEW(pars.returnType, pars);
				TypeP(pars.returnType)
			END;
		END FormalParsP;

		PROCEDURE FPSectionP(fpSection: FPSection);
		VAR
			identList: IdentList; dummy: InfoItem;
		BEGIN
			NEW(dummy);
			IF token.symbol = FoxScanner.Var THEN
				fpSection.var := TRUE;
				NextToken;
			ELSIF token.symbol = FoxScanner.Const THEN
				fpSection.const := TRUE;
				NextToken;
			END;
			IF token.symbol = FoxScanner.Identifier THEN
				(*StringPool.GetString(scanner.name, name);*)
				NEW(fpSection.identList, fpSection);
				NEW(fpSection.identList.identDef);
				IdentDefP(fpSection.identList.identDef);
				SysFlag;
				(*
				fpSection.identList.ident.name := Strings.NewString(name);
				fpSection.identList.ident.pos := token.position.start;
				NextToken;
				*)
				IF token.symbol = FoxScanner.Equal THEN NextToken; ConstExprP(FoxScanner.Comma, FoxScanner.Colon, dummy) END; (* added for optional parameters *)

				WHILE token.symbol = FoxScanner.Comma DO
					NEW(identList, fpSection.identList);
					NextToken;
					NEW(identList.identDef);
					IdentDefP(identList.identDef);
					SysFlag;
					AppendLast(fpSection.identList, identList);
					(*
					IF token.symbol = FoxScanner.Identifier THEN
						StringPool.GetString(scanner.name, name);
						NEW(identDef);
						NEW(identDef.ident);
						identDef.ident.name := Strings.NewString(name);
						identDef.ident.pos := token.position.start;
						AppendLast(fpSection.identlist, identDef);
						NextToken;
					END;
					*)
					IF token.symbol = FoxScanner.Equal THEN NextToken; ConstExprP(FoxScanner.Comma, FoxScanner.Colon, dummy) END; (* added for optional parameters *)
				END;
				Check(FoxScanner.Colon);
				NEW(fpSection.type, fpSection);
				TypeP(fpSection.type);
			END;
		END FPSectionP;

		PROCEDURE TypeP(type: Type);
		BEGIN
			CASE token.symbol OF
			| FoxScanner.Array: NextToken; NEW(type.array, type); ArrayP(type.array);
			| FoxScanner.Record: NextToken; NEW(type.record, type); RecordP(type.record);
			| FoxScanner.Pointer: NextToken; NEW(type.pointer, type); PointerP(type.pointer);
			| FoxScanner.Object: NextToken; NEW(type.object, type); ObjectP(type.object);
			| FoxScanner.Port: NextToken; NEW(type.port, type); PortP(type.port);
			| FoxScanner.Cell, FoxScanner.CellNet: NextToken; NEW(type.cell, type); CellP(type.cell);
			| FoxScanner.Enum: NextToken; NEW(type.enum, type); EnumP(type.enum);
			| FoxScanner.Procedure, FoxScanner.Operator: NextToken; NEW(type.procedure, type); ProcedureP(type.procedure);
			| FoxScanner.Identifier: NEW(type.qualident, type); QualidentP(type.qualident);
			| FoxScanner.Address, FoxScanner.Size: NEW(type.qualident, type); NEW(type.qualident.ident);
				type.qualident.ident.name := Strings.NewString(token.identifierString); type.qualident.ident.pos := token.position.start; NextToken;
			ELSE
				(* Error *)
				hasError := TRUE; KernelLog.String("err4: "); KernelLog.Int(token.position.start, 0); KernelLog.Ln;
				NextToken;	(* ??? *)
			END;
		END TypeP;

		PROCEDURE ArrayP(array: Array);
		BEGIN
			SysFlag;
			IF token.symbol = FoxScanner.Of THEN
				array.open := TRUE;
				NEW(array.base, array);
				NextToken;
				TypeP(array.base);
			ELSE
				NEW(array.len);
				ConstExprP(FoxScanner.Of, FoxScanner.Comma, array.len);
				(*
				SimpleExprP(array.len);
				*)
				IF token.symbol = FoxScanner.Of THEN
					NEW(array.base, array);
					NextToken;
					TypeP(array.base);
				ELSIF token.symbol = FoxScanner.Comma THEN
					NEW(array.base, array);
					NEW(array.base.array, array);
					NextToken;
					ArrayP(array.base.array)
				ELSE
					(* Error *)
					hasError := TRUE;
					KernelLog.String("err1: "); KernelLog.Int(token.position.start, 0); KernelLog.Ln;
				END;
			END;
		END ArrayP;

		PROCEDURE RecordP(record: Record);
		BEGIN
			SysFlag;
			IF token.symbol = FoxScanner.LeftParenthesis THEN
				NextToken;
				NEW(record.super, record);
				QualidentP(record.super);
				Check(FoxScanner.RightParenthesis);
			END;
			WHILE token.symbol = FoxScanner.Semicolon DO NextToken END;
			IF token.symbol = FoxScanner.Identifier THEN
				NEW(record.fieldList, record);
				FieldListP(record.fieldList);
			END;
			Check(FoxScanner.End);
		END RecordP;

		PROCEDURE FieldListP(fieldList: FieldDecl);
		VAR fieldDecl: FieldDecl;
		BEGIN
			FieldDeclP(fieldList);
			WHILE token.symbol = FoxScanner.Semicolon DO
				NextToken;
				NEW(fieldDecl, fieldList);
				FieldDeclP(fieldDecl);
				AppendLast(fieldList, fieldDecl);
			END;
		END FieldListP;

		PROCEDURE FieldDeclP(fieldDecl: FieldDecl);
		VAR
			identDef: IdentDef;
			identList: IdentList;
		BEGIN
			IF token.symbol = FoxScanner.Identifier THEN
				NEW(fieldDecl.identList, fieldDecl);
				NEW(fieldDecl.identList.identDef);
				IdentDefP(fieldDecl.identList.identDef);
				SysFlag;
				WHILE token.symbol = FoxScanner.Comma DO
					NextToken;
					NEW(identDef);
					IdentDefP(identDef);
					SysFlag;
					NEW(identList, identList);
					identList.identDef := identDef;
					AppendLast(fieldDecl.identList, identList);
				END;
				Check(FoxScanner.Colon);
				NEW(fieldDecl.type, fieldDecl);
				TypeP(fieldDecl.type);
			END;
		END FieldDeclP;

		PROCEDURE PointerP(pointer: Pointer);
		BEGIN
			SysFlag;
			Check(FoxScanner.To);
			NEW(pointer.type, pointer);
			TypeP(pointer.type);
		END PointerP;

		PROCEDURE EnumP(enum: Enum);
		VAR identDef: IdentDef; identList: IdentList;
		BEGIN
			NEW(enum.identList, enum);
			NEW(enum.identList.identDef);
			IdentDefP(enum.identList.identDef);
			SysFlag;
			WHILE token.symbol = FoxScanner.Comma DO
				NextToken;	(* avoids endless loop *)
				NEW(identDef);
				IdentDefP(identDef);
				NEW(identList, enum);
				identList.identDef := identDef;
				AppendLast(enum.identList, identList);
			END;
			Check(FoxScanner.End);
		END EnumP;

		PROCEDURE PortP(port: Port);
		BEGIN
			IF (token.symbol = FoxScanner.Out) OR (token.symbol = FoxScanner.In) THEN
				NextToken
			END;
		END PortP;


		PROCEDURE ObjectP(object: Object);
		VAR declSeq: DeclSeq;
			pos: LONGINT;
		(*?	qualident: Qualident; *)
		BEGIN
			IF (token.symbol = FoxScanner.Semicolon) OR (token.symbol = FoxScanner.RightParenthesis) THEN RETURN END;
			SysFlag;
			IF token.symbol = FoxScanner.LeftParenthesis THEN
				NEW(object.super, object);
				NextToken;
				QualidentP(object.super);
				Check(FoxScanner.RightParenthesis);
			END;
		(*?	IF token.symbol = FoxScanner.Implements THEN
				NEW(object.implements, object);
				NextToken;
				QualidentP(object.implements);
				WHILE token.symbol = FoxScanner.Comma DO
					NEW(qualident, object.implements);
					NextToken;
					QualidentP(qualident);
					AppendLast(object.implements, qualident);
				END;
			END; *)
			pos := -1;
			WHILE (token.symbol # FoxScanner.Begin) & (token.symbol # FoxScanner.End) & (token.symbol # FoxScanner.EndOfText) DO
					(* avoid endless-loop *)
				IF pos = token.position.start THEN NextToken END;
				pos := token.position.start;
				NEW(declSeq, object);
				DeclSeqP(declSeq);
				IF object.declSeq = NIL THEN object.declSeq := declSeq;
				ELSE AppendLast(object.declSeq, declSeq);
				END;
			END;
			IF (token.symbol = FoxScanner.Begin) THEN
				object.bodyPos := token.position.start;
			ELSE
				object.bodyPos := 0;
			END;
			BodyP(TRUE, object.modifiers);
			IF token.symbol = FoxScanner.Identifier THEN NextToken END;
		END ObjectP;

		PROCEDURE CellP(cell: Cell);
		VAR declSeq: DeclSeq;
			pos: LONGINT;
		(*?	qualident: Qualident; *)
		BEGIN
			SysFlag;
			IF token.symbol = FoxScanner.LeftParenthesis THEN
				NEW(cell.formalPars, cell);
				FormalParsP(cell.formalPars);
			END;
			pos := -1;
			WHILE (token.symbol # FoxScanner.Begin) & (token.symbol # FoxScanner.End) & (token.symbol # FoxScanner.EndOfText) DO
					(* avoid endless-loop *)
				IF pos = token.position.start THEN NextToken END;
				pos := token.position.start;
				NEW(declSeq, cell);
				DeclSeqP(declSeq);
				IF cell.declSeq = NIL THEN cell.declSeq := declSeq;
				ELSE AppendLast(cell.declSeq, declSeq);
				END;
			END;
			IF (token.symbol = FoxScanner.Begin) THEN
				cell.bodyPos := token.position.start;
			ELSE
				cell.bodyPos := 0;
			END;
			BodyP(TRUE, cell.modifiers);
			IF token.symbol = FoxScanner.Identifier THEN NextToken END;
		END CellP;

		PROCEDURE ProcedureP(proc: Procedure);
		BEGIN
			SysFlag;
			IF token.symbol = FoxScanner.LeftBrace THEN
				NextToken;
				IF token.symbol # FoxScanner.Identifier THEN
					(* Error *)
				ELSIF token.identifierString = "DELEGATE" THEN
					proc.delegate := TRUE;
				END;
				NextToken;
				Check(FoxScanner.RightBrace);
			END;
			IF token.symbol = FoxScanner.LeftParenthesis THEN
				NEW(proc.formalPars, proc);
				FormalParsP(proc.formalPars);
			END;
		END ProcedureP;

		PROCEDURE ConstExprP(delimiter1, delimiter2: FoxScanner.Symbol; expr: InfoItem);
		VAR
			exprStr, name: ARRAY 1024 OF CHAR;
			longExprStr : Strings.String; (* for exprStr content lengths > LEN(exprStr) *)
			paren, brace, brak: LONGINT;

			PROCEDURE Add(CONST str: ARRAY OF CHAR);
			VAR len1, len2 : LONGINT;
			BEGIN
				len1 := Strings.Length(exprStr);
				len2 := Strings.Length(str);
				IF (len1 + len2 + 1 > LEN(exprStr)) THEN
					IF (longExprStr = NIL) THEN
						longExprStr := Strings.ConcatToNew(exprStr, str);
					ELSE
						(* assume that this happens almost never *)
						longExprStr := Strings.ConcatToNew(longExprStr^, exprStr);
						longExprStr := Strings.ConcatToNew(longExprStr^, str);
					END;
					exprStr := "";
				ELSE
					Strings.Append(exprStr, str);
				END;
			END Add;

		BEGIN
			expr.pos := token.position.start;
			IF (token.symbol = delimiter1) OR (token.symbol = delimiter2) THEN RETURN END;
			REPEAT
				CASE token.symbol OF
				| FoxScanner.LeftParenthesis: INC(paren); Add("(");
				| FoxScanner.RightParenthesis: DEC(paren); Add(")");
				| FoxScanner.LeftBrace: INC(brace); Add("{");
				| FoxScanner.RightBrace: DEC(brace); Add("}");
				| FoxScanner.LeftBracket: INC(brak); Add("[");
				| FoxScanner.RightBracket: DEC(brak); Add("]");
				| FoxScanner.Number: Add(token.identifierString);
				| FoxScanner.Nil: Add("NIL");
				| FoxScanner.True: Add("TRUE");
				| FoxScanner.False: Add("FALSE");
				| FoxScanner.Not: Add("~");
				| FoxScanner.Period: Add(".");
				| FoxScanner.Identifier: Add(token.identifierString);
				| FoxScanner.Comma: Add(", ");
				| FoxScanner.Plus: Add(" + ");
				| FoxScanner.Minus: Add(" - ");
				| FoxScanner.Times: Add(" * ");
				| FoxScanner.Upto: Add(" .. ");
				| FoxScanner.Equal: Add(" = ");
				| FoxScanner.Unequal: Add(" # ");
				| FoxScanner.Less: Add(" < ");
				| FoxScanner.LessEqual: Add(" <= ");
				| FoxScanner.Greater: Add(" > ");
				| FoxScanner.GreaterEqual: Add(" >= ");
				| FoxScanner.In: Add(" IN ");
				| FoxScanner.Is: Add(" IS ");
				| FoxScanner.Div: Add(" DIV ");
				| FoxScanner.Mod: Add(" MOD ");
				| FoxScanner.Slash: Add(" / ");
				| FoxScanner.And: Add(" & ");
				| FoxScanner.Or: Add(" OR ");
				| FoxScanner.String: name[0] := '"'; name[1] := 0X; Add(name); Add(token.string^); Add(name);
				| FoxScanner.Arrow: Add("^");
				ELSE
					(* error *)
					hasError := TRUE;
				END;
				NextToken;
				(* urgh, what an ugly condition ... *)
			UNTIL (((token.symbol = delimiter1) OR (token.symbol = delimiter2)) & (paren = 0) & (brace = 0) & (brak = 0)) OR (token.symbol = FoxScanner.EndOfText);
			IF (longExprStr = NIL) THEN
				expr.name := Strings.NewString(exprStr);
			ELSE
				expr.name := Strings.ConcatToNew(longExprStr^, exprStr);
			END;
		END ConstExprP;

		PROCEDURE BlockModifierP(allowBody : BOOLEAN; VAR modifiers : SET);
		VAR ignore : InfoItem;
		BEGIN
			modifiers := {};
			IF token.symbol = FoxScanner.LeftBrace THEN
				NextToken;
				LOOP
					IF token.symbol = FoxScanner.Identifier THEN
						IF token.identifierString = ExclusiveStr  THEN
							modifiers := modifiers + {Exclusive};
							NextToken;
						ELSIF allowBody & (token.identifierString = ActiveStr)  THEN
							modifiers := modifiers + {Active};
							NextToken
						ELSIF allowBody & (token.identifierString = RealtimeStr) THEN
							NextToken;
						ELSIF allowBody & (token.identifierString = SafeStr)  THEN
							modifiers := modifiers + {Safe};
							NextToken
						ELSIF allowBody & (token.identifierString = PriorityStr)  THEN
							modifiers := modifiers + {Priority};
							NextToken;
							IF token.symbol = FoxScanner.LeftParenthesis THEN
								NextToken;
								NEW(ignore);
								ConstExprP(FoxScanner.RightParenthesis, -1, ignore);
								Check(FoxScanner.RightParenthesis);
							END;
						ELSIF token.identifierString = UncheckedStr  THEN
							modifiers := modifiers + {Unchecked};
							NextToken;
						ELSIF token.identifierString = UncooperativeStr  THEN
							modifiers := modifiers + {Uncooperative};
							NextToken;
						ELSE
							Error(token.position.start); NextToken (* skip the ident, probably a typo *)
						END;
					END;
					IF token.symbol # FoxScanner.Comma THEN EXIT END;
					NextToken
				END;
				Check(FoxScanner.RightBrace);
			END;
		END BlockModifierP;

		PROCEDURE ProcedureModifierP(procHead: ProcHead);
		VAR
			value: LONGINT; ignore: InfoItem;
		BEGIN
			IF token.symbol = FoxScanner.LeftBrace THEN
				NextToken;
				IF token.symbol # FoxScanner.RightBrace THEN
					LOOP
						IF token.symbol = FoxScanner.Identifier THEN
							IF token.identifierString = InterruptStr THEN NextToken; procHead.modifiers := procHead.modifiers + {Interrupt}
							ELSE NextToken;
							END;
						ELSE Error(token.position.start); NextToken; (* skip the ident, probably a typo *)
						END;
						IF (token.symbol = FoxScanner.LeftParenthesis) THEN
							NextToken;
							NEW (ignore);
							ConstExprP	 (FoxScanner.RightParenthesis, -1, ignore);
							Check (FoxScanner.RightParenthesis);
						ELSIF (token.symbol = FoxScanner.Equal) THEN
							NextToken;
							NEW (ignore);
							ConstExprP	 (FoxScanner.Comma, FoxScanner.RightBrace, ignore);
						END;
						IF token.symbol # FoxScanner.Comma THEN EXIT END;
						NextToken;
					END
				END;
				Check(FoxScanner.RightBrace)
			END
		END ProcedureModifierP;

		PROCEDURE ModifierValueP(VAR value: LONGINT);
		BEGIN
			IF token.symbol = FoxScanner.Equal THEN
				NextToken; Check(FoxScanner.Number); value := token.integer
			ELSIF token.symbol = FoxScanner.LeftParenthesis THEN
				NextToken; Check(FoxScanner.Number); value := token.integer; Check(FoxScanner.RightParenthesis)
			ELSE
				Error(token.position.start); NextToken
			END
		END ModifierValueP;

		PROCEDURE BodyP(allowBody : BOOLEAN; VAR modifiers : SET);
		VAR end: LONGINT; lastSymbol: FoxScanner.Symbol; m : SET; first : BOOLEAN;
		BEGIN
			IF token.symbol = FoxScanner.Begin THEN
				end := 1;
				first := TRUE;
				REPEAT
					lastSymbol := token.symbol;
					NextToken;
					IF (lastSymbol = FoxScanner.Begin) & (token.symbol = FoxScanner.LeftBrace) THEN
						BlockModifierP(allowBody, m);
						IF first THEN
							allowBody := FALSE;
							modifiers := m;
						ELSE
							IF m * {Exclusive} # {} THEN
								modifiers := modifiers + {HasExclusiveBlock};
							END;
						END;
					END;
					first := FALSE;
					CASE token.symbol OF
					| FoxScanner.Begin: INC(end);
					| FoxScanner.If, FoxScanner.Case, FoxScanner.While, FoxScanner.For, FoxScanner.Loop, FoxScanner.With: INC(end);
					| FoxScanner.Code:
						REPEAT NextToken UNTIL (token.symbol = FoxScanner.End) OR (token.symbol = FoxScanner.EndOfText);
						NextToken;
					| FoxScanner.End: DEC(end);
					ELSE
					END;
				UNTIL (end = 0) OR (token.symbol = FoxScanner.EndOfText);
			ELSIF token.symbol = FoxScanner.Code THEN
				REPEAT NextToken UNTIL (token.symbol = FoxScanner.End) OR (token.symbol = FoxScanner.EndOfText);
			END;
			NextToken;
		END BodyP;

		PROCEDURE QualidentP(qualident: Qualident);
		VAR
			name : ARRAY 64 OF CHAR;
			pos: LONGINT;
		BEGIN
			IF token.symbol = FoxScanner.Identifier THEN
				COPY(token.identifierString, name);
				pos := token.position.start;
				NextToken;
				IF token.symbol = FoxScanner.Period THEN
					NextToken;
					IF token.symbol = FoxScanner.Identifier THEN
						Strings.Append(name, ".");
						Strings.Concat(name, token.identifierString, name);
						NextToken;
					END;
				END;
				NEW(qualident.ident);
				qualident.ident.name := Strings.NewString(name);
				qualident.ident.pos := pos;
			END;
		END QualidentP;

		PROCEDURE IdentDefP(identDef: IdentDef);
		BEGIN
			IF (token.symbol = FoxScanner.Identifier) OR (token.symbol = FoxScanner.Number) & (token.numberType = FoxScanner.Character)  THEN
				NEW(identDef.ident);
				identDef.ident.name := Strings.NewString(token.identifierString);
				identDef.ident.pos := token.position.start;
			ELSIF (token.symbol = FoxScanner.String) THEN
				NEW(identDef.ident);
				identDef.ident.name := Strings.NewString(token.string^);
				identDef.ident.pos := token.position.start;
			END;
			NextToken;
			IF token.symbol = FoxScanner.Times THEN
				identDef.vis := Public;
				NextToken;
			ELSIF token.symbol = FoxScanner.Minus THEN
				identDef.vis := PublicRO;
				NextToken;
			ELSE
				identDef.vis := Private;
			END;
			identDef.external := NIL;
			IF token.symbol = FoxScanner.Becomes THEN
				NextToken;
				NEW(identDef.initializer);
				ConstExprP(FoxScanner.Colon, FoxScanner.Comma, identDef.initializer);
			ELSIF token.symbol = FoxScanner.Extern THEN
				NextToken;
				identDef.external := Strings.NewString(token.string^);
				Check(FoxScanner.String);
				TRACE (identDef.external^);
			END;
		END IdentDefP;

		PROCEDURE Check(symbol: FoxScanner.Symbol);
		BEGIN
			IF token.symbol = symbol THEN
				(* correct *)
			ELSE
				(* error *)

				KernelLog.String("******* Check error **********  ");
				KernelLog.Int(token.position.start, 0);
				KernelLog.Ln;

				hasError := TRUE;
				(*HALT(33);*)
			END;
			NextToken;
		END Check;

		PROCEDURE Error(pos : LONGINT);
		BEGIN
			KernelLog.String("ModuleParser: Error at pos "); KernelLog.Int(pos, 0); KernelLog.Ln;
		END Error;

	END Parser;

	ListEntry = POINTER TO RECORD
		module : Module;
		next : ListEntry;
	END;

	ModuleCache = OBJECT
	VAR
		head : ListEntry; (* private *)
		nofModules : LONGINT;

		PROCEDURE Add(module : Module);
		VAR entry : ListEntry;
		BEGIN {EXCLUSIVE}
			ASSERT((module # NIL) & (module.ident.name # NIL));
			entry := FindEntry(module.ident.name^);
			IF (entry = NIL) THEN
				NEW(entry);
				entry.next := head.next;
				head.next := entry;
				module.resolved := FALSE;
				INC(nofModules);
			END;
			entry.module := module;
		END Add;

		PROCEDURE Get(CONST moduleName : ARRAY OF CHAR) : Module;
		VAR module : Module; entry : ListEntry;
		BEGIN {EXCLUSIVE}
			entry := FindEntry(moduleName);
			IF (entry # NIL) THEN
				module := entry.module;
			ELSE
				module := NIL;
			END;
			RETURN module;
		END Get;

		PROCEDURE Enumerate(enumerator : EnumeratorProc);
		VAR entry : ListEntry;
		BEGIN
			ASSERT(enumerator # NIL);
			entry := head.next;
			WHILE (entry # NIL) DO
				enumerator(entry.module, SELF);
				entry := entry.next;
			END;
		END Enumerate;

		PROCEDURE FindEntry(CONST moduleName : ARRAY OF CHAR) : ListEntry; (* private *)
		VAR entry : ListEntry;
		BEGIN
			entry := head.next;
			WHILE (entry # NIL) & (entry.module.ident.name^ # moduleName) DO entry := entry.next; END;
			RETURN entry;
		END FindEntry;

		PROCEDURE &Init; (* private *)
		BEGIN
			NEW(head); head.module := NIL; head.next := NIL;
			nofModules := 0;
		END Init;

	END ModuleCache;

	EnumeratorProc = PROCEDURE {DELEGATE} (module : Module; cache : ModuleCache);

PROCEDURE AppendLast(head, node: NodeList);
VAR n: NodeList;
BEGIN
	IF head = NIL THEN RETURN END;
	n := head;
	WHILE n.next # NIL DO
		n := n.next;
	END;
	n.next := node;
END AppendLast;

PROCEDURE SplitName*(CONST name : ARRAY OF CHAR; VAR moduleName, typeName : ARRAY OF CHAR);
VAR i, j : LONGINT;
BEGIN
	IF Strings.ContainsChar(name, ".", FALSE) THEN
		i := 0;
		WHILE (i < LEN(name)) & (name[i] # ".") DO moduleName[i] := name[i]; INC(i); END;
		moduleName[i] := 0X;
		INC(i); (* skip "." *)
		j := 0;
		WHILE (i < LEN(name)) & (name[i] # 0X) DO typeName[j] := name[i]; INC(i); INC(j); END;
		typeName[j] := 0X;
	ELSE
		COPY("", moduleName);
		COPY(name, typeName);
	END;
END SplitName;

PROCEDURE FindType(CONST name : ARRAY OF CHAR; type : LONGINT; definitionModule : Module; cache : ModuleCache) : TypeDecl;
VAR
	module : Module; import : Import; typeDecl : TypeDecl;
	moduleName, importName, typeName : ARRAY 256 OF CHAR;
	context : ARRAY 32 OF CHAR;
	filename : Files.FileName;

	PROCEDURE FileExists(CONST filename : ARRAY OF CHAR) : BOOLEAN;
	VAR file : Files.File;
	BEGIN
		file := Files.Old(filename);
		RETURN (file # NIL);
	END FileExists;

	PROCEDURE GenerateFilename(CONST prefix, context, moduleName, fileExtension: ARRAY OF CHAR) : Files.FileName;
	VAR filename : Files.FileName;
	BEGIN
		COPY(prefix, filename);
		IF (context # "") THEN Strings.Append(filename, context); Strings.Append(filename, "."); END;
		Strings.Append(filename, moduleName); Strings.Append(filename, fileExtension);
		RETURN filename;
	END GenerateFilename;

	(* Simple heuristics that tries to find the filename of a given module name *)
	PROCEDURE FindCorrectFilename(CONST context, moduleName : ARRAY OF CHAR) : Files.FileName;
	VAR filename : Files.FileName;
	BEGIN
		filename := GenerateFilename("", context, moduleName, ".Mod");
		IF ~FileExists(filename) THEN
			filename := GenerateFilename("I386.", context, moduleName, ".Mod");
			IF ~FileExists(filename) THEN
				filename := GenerateFilename("Windows.", context, moduleName, ".Mod");
				IF ~FileExists(filename) THEN
					filename := GenerateFilename("Unix.", context, moduleName, ".Mod");
					IF ~FileExists(filename) THEN
						filename := GenerateFilename("Oberon-", context, moduleName, ".Mod");
						IF ~FileExists(filename) THEN
							filename := GenerateFilename("", context, moduleName, ".Mod");
						END;
					END;
				END;
			END;
		END;
		RETURN filename;
	END FindCorrectFilename;

BEGIN
	ASSERT((definitionModule # NIL) & (cache # NIL));
	SplitName(name, moduleName, typeName);
	import := definitionModule.FindImport(moduleName);
	importName := "";
	IF (import # NIL) THEN
		IF (import.context # NIL) THEN
			COPY(import.context.name^, context);
		ELSIF (definitionModule.context # NIL) THEN
			COPY(definitionModule.context.name^, context);
		ELSE
			COPY("", context);
		END;
		IF (import.alias # NIL) THEN
			Strings.Append(importName, import.alias.name^);
		ELSE
			Strings.Append(importName, import.ident.name^);
		END;
	END;
	IF (importName # "") THEN
		module := cache.Get(importName);
		IF (module = NIL) THEN
			filename := FindCorrectFilename(context, importName);
			module := ParseFile(filename, NIL);
			IF (module # NIL) THEN cache.Add(module); END;
		END;
	ELSE
		module := definitionModule;
	END;
	typeDecl := NIL;
	IF (module # NIL) THEN
		typeDecl := module.FindTypeDecl(typeName);
		IF (typeDecl # NIL) & (type # 3) &  (((typeDecl.type.record = NIL) & (type = 0)) OR ((typeDecl.type.object = NIL) & (type = 1)) OR
			(((typeDecl.type.pointer = NIL) OR (typeDecl.type.pointer.type.record = NIL)) & (type = 2))) THEN
			typeDecl := NIL; (* wrong type *)
		END;
	ELSE
		KernelLog.String("Module "); KernelLog.String(moduleName); KernelLog.String(" not found.");
		KernelLog.Ln;
	END;
	RETURN typeDecl;
END FindType;

PROCEDURE ResolveTypeHierarchy(module : Module; cache : ModuleCache);
VAR typeDecl, td : TypeDecl;
BEGIN
	ASSERT(module # NIL);
	IF ~module.resolved & (module.declSeq # NIL) & (module.declSeq.typeDecl # NIL) THEN
		typeDecl := module.declSeq.typeDecl;
		WHILE (typeDecl # NIL) DO
			IF (typeDecl.type.record # NIL) & (typeDecl.type.record.super # NIL) THEN
				td := FindType(typeDecl.type.record.super.ident.name^, 0, module, cache);
				IF (td # NIL) THEN
					typeDecl.type.record.superPtr := td.type.record;
				END;
			ELSIF (typeDecl.type.pointer # NIL) & (typeDecl.type.pointer.type.record # NIL) & (typeDecl.type.pointer.type.record.super # NIL) THEN
				td := FindType(typeDecl.type.pointer.type.record.super.ident.name^, 2, module, cache);
				IF (td # NIL) THEN
					typeDecl.type.pointer.type.record.superPtr := td.type.pointer.type.record;
				END;
			ELSIF (typeDecl.type.object # NIL) & (typeDecl.type.object.super # NIL) THEN
				td := FindType(typeDecl.type.object.super.ident.name^, 1, module, cache);
				IF (td # NIL) THEN
					typeDecl.type.object.superPtr := td.type.object;
				END;
			END;
			IF (typeDecl.next # NIL) THEN
				typeDecl := typeDecl.next (TypeDecl);
			ELSE
				typeDecl := NIL;
			END;
		END;
		module.resolved := TRUE;
	END;
END ResolveTypeHierarchy;

PROCEDURE ResolveMethodOverwrites(module : Module; cache : ModuleCache);
VAR typeDecl : TypeDecl; method, procDecl : ProcDecl; superClass : Object;
BEGIN
	IF module.resolved & (module.declSeq # NIL) & (module.declSeq.typeDecl # NIL) THEN
		typeDecl := module.declSeq.typeDecl;
		WHILE (typeDecl # NIL) DO
			IF (typeDecl.type.object # NIL) & (typeDecl.type.object.declSeq # NIL) THEN
				method := typeDecl.type.object.declSeq.procDecl;
				WHILE (method # NIL) DO
					superClass := typeDecl.type.object.superPtr;
					WHILE (superClass # NIL) DO
						procDecl := superClass.FindProcDecl(method.head.identDef.ident.name^);
						IF (procDecl # NIL) THEN
							INCL(procDecl.head.modifiers, Overwritten);
							INCL(method.head.modifiers, Overwrite)
						END;
						superClass := superClass.superPtr;
					END;
					IF (method.next # NIL) THEN
						method := method.next (ProcDecl);
					ELSE
						method := NIL;
					END;
				END;
			END;
			IF (typeDecl.next # NIL) THEN
				typeDecl := typeDecl.next (TypeDecl);
			ELSE
				typeDecl := NIL;
			END;
		END;
	END;
END ResolveMethodOverwrites;

PROCEDURE ParseFile*(CONST filename : ARRAY OF CHAR; diagnostics : Diagnostics.Diagnostics) : Module;
VAR
	module : Module;
	scanner : FoxScanner.Scanner;
	text : Texts.Text; reader : TextUtilities.TextReader;
	format: LONGINT; res : WORD;
BEGIN
	NEW(text);
	TextUtilities.LoadAuto(text, filename, format, res);
	IF (res = 0) THEN
		NEW(reader, text);
		scanner := FoxScanner.NewScanner(filename, reader, 0, diagnostics);
		Parse(scanner, module);
	ELSIF (diagnostics # NIL) THEN
		diagnostics.Error("ModuleParser", Streams.Invalid, "File not found");
	END;
	RETURN module
END ParseFile;

(** Parse all modules required to set the Record.superPtr and Object.superPtr fields and set these fields*)
PROCEDURE SetSuperTypes*(module: Module);
VAR cache : ModuleCache; nofModules : LONGINT;
BEGIN
	ASSERT(module # NIL);
	NEW(cache);
	cache.Add(module);
	ResolveTypeHierarchy(module, cache);
	nofModules := -1;
	WHILE (nofModules # cache.nofModules) DO
		nofModules := cache.nofModules;
		cache.Enumerate(ResolveTypeHierarchy);
	END;
	cache.Enumerate(ResolveMethodOverwrites);
END SetSuperTypes;

PROCEDURE Parse*(scanner: FoxScanner.Scanner; VAR module: Module);
VAR parser: Parser;
BEGIN
	NEW(parser, scanner);
	parser.ModuleP(module);
END Parse;

END ModuleParser.

PC.Compile \s ModuleParser.Mod ~
Builder.Compile \s  ModuleParser.Mod ~
System.DeleteFiles ModuleParser.Obx ~
System.Free ModuleParser ~
Decoder.Decode ModuleParser ~
