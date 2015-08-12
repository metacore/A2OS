MODULE FoxIntermediateParser;

IMPORT
  Basic := FoxBasic, 
  Scanner := FoxIntermediateScanner, 
  Fs	:= FoxScanner,
  D := Debugging, 
  SyntaxTree := FoxSyntaxTree, 
(*  Global := FoxGlobal,  *)
  Diagnostics;

CONST
  Trace = TRUE;
(*  CascadedWithSupport = FALSE;*)

(**
  Module        = 'module' SymbolName [Import] { Section } .
  Import        = 'imports' SymbolName { ',' SymbolName } .
  SectionOffset = 'offset' '=' Int .
  Section       = 'bodycode' SymbolName SectionOffset { Stmt }
                | 'inlinecode' SymbolName SectionOffset { Stmt }
                | 'initcode' SymbolName SectionOffset { Stmt }
                | 'var' SymbolName SectionOffset { Var }
                | 'const' SymbolName SectionOffset { Const }
                | 'code' SymbolName SectionOffset { Stmt }
                .
  Var           = 'reserve' Int .
  Const         = 'data' Operand .
  Stmt          = 'nop'
                | 'mov'     Operand ',' Operand [ ',' Operand ]
                | 'conv'    Operand ',' Operand
                | 'call'    Operand ',' Operand
                | 'enter'   Operand ',' Operand
                | 'leave'   Operand
                | 'return'  Operand
                | 'exit'    Operand
                | 'result'  Operand
                | 'trap'    Operand
                | 'br'      Operand
                | 'breq'    Operand ',' Operand ',' Operand
                | 'brne'    Operand ',' Operand ',' Operand
                | 'brlt'    Operand ',' Operand ',' Operand
                | 'brge'    Operand ',' Operand ',' Operand
                | 'pop'     Operand
                | 'push'    Operand
                | 'not'     Operand ',' Operand
                | 'neg'     Operand ',' Operand
                | 'abs'     Operand ',' Operand
                | 'mul'     Operand ',' Operand ',' Operand
                | 'div'     Operand ',' Operand ',' Operand
                | 'mod'     Operand ',' Operand ',' Operand
                | 'sub'     Operand ',' Operand ',' Operand
                | 'add'     Operand ',' Operand ',' Operand
                | 'and'     Operand ',' Operand ',' Operand
                | 'or'      Operand ',' Operand ',' Operand
                | 'xor'     Operand ',' Operand ',' Operand
                | 'shl'     Operand ',' Operand ',' Operand
                | 'shr'     Operand ',' Operand ',' Operand
                | 'rol'     Operand ',' Operand ',' Operand
                | 'ror'     Operand ',' Operand ',' Operand
                | 'copy'    Operand ',' Operand ',' Operand
                | 'fill'    Operand ',' Operand ',' Operand
                | 'asm'     String
                .
  Operand       = Type '[' MemoryAddr ']'       ; Memory Operand
                | Type Register [ Int ]         ; Register Operand
                | Type OpImmediate              ; Immediate Operand
                | Type String                   ; String Operand
                | Int                           ; Number Operand
                .
  OpImmediate   = Symbol
                | Int
                | Hex
                | Float
                .
  MemoryAddr    = Register [ Int ]
                | Symbol
                | Int
                .
  Register      = '$' 'SP'
                | '$' 'FP'
                | '$' Int
                | '$' 'R' '#' Int
                .
  Symbol        = SymbolName ':' Int [ SymbolOffset ] .
  SymbolOffset  = '(' '@' Int ')' .
  SymbolName    = Id
                | '$' Id
                | '$' '$' Id
                .
  Type          = Id .
  Int           = ['-'|'+']('0'..'9')+           ; Integer
  Hex           = ('0'..'9')('0'..'9'|'A'..'F')+'H'
  Float         = ['-']('0'..'9')+'.'('0'..'9')+['E'('-'|'+')('0'..'9')+]
  Id            = ('a'..'z'|'A'..'Z')('a'..'z'|'A'..'Z'|'0'..'9'|'_'|'.'|'@'|'$')+  ; Identifier
  String        = '\'' { (Byte - '\'')|'\\\'' }  '\''

**)

TYPE
  Parser* = OBJECT
  VAR 
    scanner: Scanner.AssemblerScanner;
    symbol-: Fs.Symbol;
    diagnostics: Diagnostics.Diagnostics;
    currentScope: SyntaxTree.Scope;
    recentSymbol: SyntaxTree.Symbol;
    recentComment: SyntaxTree.Comment;
    moduleScope: SyntaxTree.ModuleScope;
    error-: BOOLEAN;

    indent: LONGINT;   (* for debugging purposes only *)

    PROCEDURE S( CONST s: ARRAY OF CHAR );   (* for debugging purposes only *)
    VAR i: LONGINT;
    BEGIN
      D.Ln;  INC( indent );  D.Int( indent,1 );
      FOR i := 1 TO indent DO D.Str( "  " );  END;
      D.Str( "start: " );  D.Str( s );  D.Str( " at pos " );  D.Int( symbol.start,1 );
    END S;

    PROCEDURE E( CONST s: ARRAY OF CHAR );   (* for debugging purposes only *)
    VAR i: LONGINT;
    BEGIN
      D.Ln;  D.Int( indent,1 );
      FOR i := 1 TO indent DO D.Str( "  " );  END;
      D.Str( "end : " );  D.Str( s );  D.Str( " at pos " );  D.Int( symbol.start,1 );
    END E;

(*    PROCEDURE EE( CONST s, t: ARRAY OF CHAR );   (* for debugging purposes only *)
    VAR i: LONGINT;
    BEGIN
      D.Ln;  D.Int( indent,1 );
      FOR i := 1 TO indent DO D.Str( "  " );  END;
      D.Str( "end : " );  D.Str( s );  D.Str( " (" );  D.Str( t );  D.Str( ") at pos " );
    END EE;*)

    (** constructor, init parser with scanner providing input and with diagnostics for error output *)
    PROCEDURE & Init*( scanner: Scanner.AssemblerScanner; diagnostics: Diagnostics.Diagnostics );
    BEGIN
      SELF.scanner := scanner;
      SELF.diagnostics := diagnostics;
      error := ~scanner.GetNextSymbol(symbol);
      recentSymbol := NIL; recentComment := NIL;
      (* debugging *)
      indent := 0;
    END Init;

    (** output error message and / or given code *)
    PROCEDURE Error(position: LONGINT; code: LONGINT; CONST message: ARRAY OF CHAR);
    VAR errorMessage: ARRAY 256 OF CHAR;
    BEGIN
      IF diagnostics # NIL THEN
        Basic.GetErrorMessage(code,message,errorMessage);
        diagnostics.Error(scanner.source, position, code, errorMessage);
      END;
      error := TRUE
    END Error;

    (** helper procedures interfacing to the scanner **)

    (** Get next symbol from scanner and store it in object-local variable 'symbol' *)
    PROCEDURE NextSymbol;
    VAR comment: SyntaxTree.Comment;
    BEGIN
      error := ~scanner.GetNextSymbol(symbol) OR error;
      WHILE ~error & (symbol.token = Scanner.TK_Comment) DO
        comment := SyntaxTree.NewComment(symbol.start, currentScope, symbol.source^,symbol.stringLength);
        moduleScope.AddComment(comment);
        recentComment := comment; comment.SetPreviousSymbol(recentSymbol);
        error := ~scanner.GetNextSymbol(symbol);
      END;
    END NextSymbol;

    (** Check if current symbol equals sym. If yes then return true, return false otherwise *)
    PROCEDURE Peek(token: Fs.Token): BOOLEAN;
    VAR comment: SyntaxTree.Comment;
    BEGIN
      WHILE ~error & (symbol.token = Scanner.TK_Comment) DO
        comment := SyntaxTree.NewComment(symbol.start, currentScope, symbol.source^,symbol.stringLength);
        moduleScope.AddComment(comment);
        recentComment := comment; comment.SetPreviousSymbol(recentSymbol);
        error := ~scanner.GetNextSymbol(symbol);
      END;
      RETURN symbol.token = token
    END Peek;

    (** Check if the current symbol equals sym.If yes then read next symbol, report error otherwise. returns success value  *)
    PROCEDURE Mandatory( token: Fs.Token): BOOLEAN;
    BEGIN
      ASSERT( token # Scanner.TK_Identifier );  ASSERT( token # Scanner.TK_String );  ASSERT( token # Scanner.TK_Number );   (* because of NextSymbol ! *)
      IF ~Peek(token) THEN
        Error( symbol.start, token, "" );
        RETURN FALSE
      ELSE
        NextSymbol;
        RETURN TRUE
      END
    END Mandatory;

    PROCEDURE MandatoryInteger( VAR value: HUGEINT ): BOOLEAN;
    BEGIN
      IF Peek( Scanner.TK_Number ) THEN
        value := symbol.integer;
        NextSymbol;
        RETURN	TRUE;
      ELSE
        Error( symbol.start, Scanner.TK_Number, "" );
        value := 0;
        RETURN FALSE;
      END;
    END MandatoryInteger;


(*    (** Check if the current symbol equals sym. If yes then read next symbol, report error otherwise  *)
    PROCEDURE Check( token: Scanner.Token );
    VAR b: BOOLEAN;
    BEGIN
      b := Mandatory( token );
    END Check;*)

    (** Check if current symbol is an identifier. If yes then copy identifier to name and get next symbol,
    report error otherwise and set name to empty name. returns success value *)
    PROCEDURE MandatoryIdentifier( VAR name: Fs.StringType): BOOLEAN;
    BEGIN
      IF Peek(Scanner.TK_Identifier) THEN
        name := symbol.string;
        NextSymbol;
        RETURN TRUE
      ELSE
        Error( symbol.start, Scanner.TK_Identifier, "" );
        name := "";
        RETURN FALSE
      END
    END MandatoryIdentifier;

    (** Expect an identifier (using MandatoryIdentifier) and return identifier object **)
    PROCEDURE Identifier(): SyntaxTree.Identifier;
    VAR position: LONGINT; name: Fs.StringType; identifier: SyntaxTree.Identifier;
    BEGIN
      position := symbol.start;
      IF MandatoryIdentifier(name) THEN
        identifier := SyntaxTree.NewIdentifier(position,name);
      ELSE
        identifier := SyntaxTree.invalidIdentifier;
      END;
      RETURN identifier
    END Identifier;

    (** Check if current symbol is a string (or string-like character). If yes then copy identifier to name and get next symbol,
    report error otherwise and set name to empty name. returns success value*)
(*    PROCEDURE MandatoryString( VAR name: Fs.StringType ): BOOLEAN;
    BEGIN
      IF Peek( Scanner.TK_String) THEN
        name := symbol.string;
        NextSymbol;
        RETURN TRUE
      ELSIF Peek( Scanner.TK_Character) THEN (* for compatibility with release: characters treated as strings *)
        name := symbol.string;
        NextSymbol;
        RETURN TRUE
      ELSE
        Error( symbol.start, Scanner.TK_String, "" );
        name := "";
        RETURN FALSE
      END
    END MandatoryString;*)

    (** Check if current symbol is an identifier and if the name matches. If yes then get next symbol, report error otherwise. returns success value*)
(*    PROCEDURE ExpectThisIdentifier( name: SyntaxTree.Identifier ): BOOLEAN;
    VAR string: ARRAY 64 OF CHAR;
    BEGIN
      IF name = NIL THEN (* nothing to be expected *)
        RETURN TRUE
      ELSIF (symbol.token # Scanner.TK_Identifier) OR (Basic.MakeString(symbol.string) #  name.name) THEN
        Basic.GetString(name.name,string);
        Error( symbol.start, Scanner.TK_Identifier, string );
        RETURN FALSE
      ELSE
        NextSymbol;
        RETURN TRUE
      END
    END ExpectThisIdentifier;*)

    (** Check if current symbol is an identifier and if the name matches. If yes then get next symbol, report error otherwise. returns success value*)
(*    PROCEDURE ExpectThisString( CONST name: ARRAY OF CHAR ): BOOLEAN;
    BEGIN
      IF (Peek(Scanner.TK_String) OR Peek(Scanner.TK_Character) OR Peek(Scanner.TK_Identifier)) & (symbol.string = name) THEN
        NextSymbol;
        RETURN TRUE
      ELSE
        Error( symbol.start, Scanner.TK_String, name );
        RETURN FALSE
      END
    END ExpectThisString;*)

    (** Check if current symbol equals sym. If yes then get next symbol, return false otherwise *)
    PROCEDURE Optional( token: Fs.Token ): BOOLEAN;
    BEGIN
      (* do not use for Identifier, String or Number, if the result is needed ! *)
      IF Peek(token) THEN
        NextSymbol;
        RETURN TRUE
      ELSE
        RETURN FALSE
      END
    END Optional;

(*    (* ignore one ore more symbols of type token *)
    PROCEDURE Ignore(token: Scanner.Token);
    BEGIN WHILE Optional(token) DO END;
    END Ignore;

    (** Parsing according to the EBNF **)

    (** QualifiedIdentifier = Identifier ['.' Identifier]. **)
    PROCEDURE QualifiedIdentifier( ): SyntaxTree.QualifiedIdentifier;
    VAR prefix,suffix: SyntaxTree.Identifier; qualifiedIdentifier: SyntaxTree.QualifiedIdentifier;  position: LONGINT;
    BEGIN
      IF Trace THEN S( "QualifiedIdentifier" ) END;
      position:= symbol.start;
      prefix := Identifier();
      IF prefix # SyntaxTree.invalidIdentifier THEN
        IF ~Optional( Scanner.Period )THEN
          suffix := prefix;  prefix := NIL;   (* empty *)
        ELSE
           suffix := Identifier();
        END;
        qualifiedIdentifier := SyntaxTree.NewQualifiedIdentifier( position, prefix,suffix);
      ELSE
        qualifiedIdentifier := SyntaxTree.invalidQualifiedIdentifier;
      END;
      IF Trace THEN E( "QualifiedIdentifier" ) END;
      RETURN qualifiedIdentifier
    END QualifiedIdentifier;

    (** IdentifierDefinition = Identifier [ '*' | '-' ].  **)
    PROCEDURE IdentifierDefinition( VAR name: SyntaxTree.Identifier;  VAR access: SET; allowedReadOnly: BOOLEAN);
    BEGIN
      IF Trace THEN S( "IdentifierDefinition" ) END;
      name := Identifier();

      IF Optional( Scanner.Times ) THEN
        access := SyntaxTree.Public + SyntaxTree.Protected + SyntaxTree.Internal;
      ELSIF Optional( Scanner.Minus ) THEN
        IF ~allowedReadOnly THEN
          Error( symbol.start, Diagnostics.Invalid, "may not be defined read-only" )
        ELSE
          access :=  SyntaxTree.ReadOnly + {SyntaxTree.InternalWrite};
        END;
      ELSE
        access := SyntaxTree.Internal;
      END;
      IF Trace THEN E( "IdentifierDefinition") END;
    END IdentifierDefinition;

    (**    Statement =
                     [
                     Designator [':=' Expression]
                     | 'if' Expression 'then' StatementSequence
                        {'elsif' Expression 'then' StatementSequence} 'end'
                     | 'with' Identifier ':' QualifiedIdentifier 'do'
                         StatementSequence 'end'
                     | 'case' Expression 'of' ['|'] Case {'|' Case} ['else' StatementSequence] 'end'
                     | 'while' Expression 'do' StatementSequence 'end'
                     | 'repeat' StatementSequence 'until' Expression
                     | 'for' Identifier ':=' Expression 'to' Expression ['by' Expression] 'do'
                         StatementSequence 'end'
                     | 'loop' StatementSequence 'end'
                     | 'exit'
                     | 'return' [Expression]
                     | 'await' Expression
                     | 'begin' StatementBlock 'end'
                     | 'code' {any} 'end'
                     ].
    **)
    PROCEDURE Statement( statements: SyntaxTree.StatementSequence; outer: SyntaxTree.Statement): BOOLEAN;
    VAR qualifiedIdentifier: SyntaxTree.QualifiedIdentifier;  expression: SyntaxTree.Expression; designator: SyntaxTree.Designator;  statement: SyntaxTree.Statement;
      ifStatement: SyntaxTree.IfStatement; elsifPart: SyntaxTree.IfPart;   statementSequence: SyntaxTree.StatementSequence;  withStatement: SyntaxTree.WithStatement;
      withPart: SyntaxTree.WithPart; caller: SyntaxTree.ProcedureCallStatement;
      caseStatement: SyntaxTree.CaseStatement;  whileStatement: SyntaxTree.WhileStatement;  repeatStatement: SyntaxTree.RepeatStatement;  forStatement: SyntaxTree.ForStatement;
      identifier: SyntaxTree.Identifier;  loopStatement: SyntaxTree.LoopStatement;  returnStatement: SyntaxTree.ReturnStatement;  awaitStatement: SyntaxTree.AwaitStatement;
      qualifiedType: SyntaxTree.QualifiedType; code : SyntaxTree.Code; position: LONGINT; result: BOOLEAN;
    BEGIN
      IF Trace THEN S( "Statement" ) END;
      CASE symbol.token OF
      | Scanner.Identifier, Scanner.Self, Scanner.Result:
          designator := Designator();
          position := symbol.start;
          IF Optional( Scanner.Becomes ) THEN
            expression := Expression();
            statement := SyntaxTree.NewAssignment( position, designator, expression,outer )
          ELSE
            caller := SyntaxTree.NewProcedureCallStatement(designator.position, designator,outer);
            statement := caller;
          END;
          statements.AddStatement( statement );
          result := TRUE
      | Scanner.If:
          NextSymbol;
          ifStatement := SyntaxTree.NewIfStatement( symbol.start ,outer);
          expression := Expression();
          ifStatement.ifPart.SetCondition( expression );
          Check( Scanner.Then );
          statementSequence := StatementSequence(ifStatement);
          ifStatement.ifPart.SetStatements( statementSequence );
          WHILE Optional( Scanner.Elsif ) DO
            elsifPart := SyntaxTree.NewIfPart();
            ifStatement.AddElsifPart( elsifPart);
            expression := Expression();
            elsifPart.SetCondition( expression );
            Check( Scanner.Then );
            statementSequence := StatementSequence(ifStatement);
            elsifPart.SetStatements( statementSequence );
          END;
          IF Optional( Scanner.Else ) THEN
            statementSequence := StatementSequence(ifStatement);
            ifStatement.SetElsePart( statementSequence );
          END;
          Check( Scanner.End );  statements.AddStatement( ifStatement );
          result := TRUE
      | Scanner.With:
          withStatement := SyntaxTree.NewWithStatement( symbol.start ,outer);
          NextSymbol;
          REPEAT
            identifier := Identifier();
            IF Optional(Scanner.Period) & Optional(Scanner.Identifier) THEN
              Error(identifier.position,Diagnostics.Invalid,"forbidden qualified identifier in with statement");
            END;
            withPart := SyntaxTree.NewWithPart();
            withStatement.AddWithPart(withPart);
            designator := SyntaxTree.NewIdentifierDesignator(identifier.position,identifier);
            withPart.SetVariable( designator );
            Check( Scanner.Colon );
            qualifiedIdentifier := QualifiedIdentifier();
            qualifiedType := SyntaxTree.NewQualifiedType(qualifiedIdentifier.suffix.position, currentScope, qualifiedIdentifier);
            withPart.SetType(qualifiedType);
            Check( Scanner.Do );
            statementSequence := StatementSequence(withStatement);
            withPart.SetStatements( statementSequence );
          UNTIL ~Optional(Scanner.Bar) OR ~CascadedWithSupport;
          IF CascadedWithSupport & Optional(Scanner.Else) THEN
            statementSequence := StatementSequence(withStatement);
            withStatement.SetElsePart(statementSequence);
          END;
          Check( Scanner.End );
          statements.AddStatement( withStatement );
          result := TRUE
      | Scanner.Case:
          caseStatement := SyntaxTree.NewCaseStatement( symbol.start,outer );
          NextSymbol;
          expression := Expression();
          Check( Scanner.Of );
          caseStatement.SetVariable( expression );
          IF Optional(Scanner.Bar) THEN END;
          REPEAT
            Case(caseStatement)
          UNTIL ~Optional(Scanner.Bar);
          IF Optional( Scanner.Else ) THEN
            statementSequence := StatementSequence(caseStatement);
            caseStatement.SetElsePart( statementSequence );
          END;
          Check( Scanner.End );
          statements.AddStatement( caseStatement );
          result := TRUE
      | Scanner.While:
          NextSymbol;
          whileStatement := SyntaxTree.NewWhileStatement( symbol.start, outer );
          expression := Expression();
          Check( Scanner.Do );
          whileStatement.SetCondition( expression );
          statementSequence := StatementSequence(whileStatement);
          whileStatement.SetStatements( statementSequence );
          Check( Scanner.End );
          statements.AddStatement( whileStatement );
          result := TRUE
      | Scanner.Repeat:
          NextSymbol;
          repeatStatement := SyntaxTree.NewRepeatStatement( symbol.start, outer );
          statementSequence := StatementSequence(repeatStatement);
          repeatStatement.SetStatements( statementSequence );
          Check( Scanner.Until );
          expression := Expression();
          repeatStatement.SetCondition( expression );
          statements.AddStatement( repeatStatement );
          result := TRUE
      | Scanner.For:
          NextSymbol;
          forStatement := SyntaxTree.NewForStatement( symbol.start, outer);
          identifier := Identifier();
          IF Optional(Scanner.Period) & Optional(Scanner.Identifier) THEN
            Error(identifier.position,Diagnostics.Invalid,"forbidden non-local counter variable");
          END;
          designator := SyntaxTree.NewIdentifierDesignator(identifier.position,identifier);
          forStatement.SetVariable( designator );
          Check( Scanner.Becomes );
          expression := Expression();
          forStatement.SetFrom( expression );
          Check( Scanner.To );
          expression := Expression();
          forStatement.SetTo( expression );
          IF Optional( Scanner.By ) THEN
            expression := Expression();
            forStatement.SetBy( expression );
          END;
          Check( Scanner.Do );
          statementSequence := StatementSequence(forStatement);
          forStatement.SetStatements( statementSequence );
          Check( Scanner.End );
          statements.AddStatement( forStatement );
          result := TRUE
      | Scanner.Loop:
          NextSymbol;
          loopStatement := SyntaxTree.NewLoopStatement( symbol.start ,outer);
          statementSequence := StatementSequence(loopStatement);
          loopStatement.SetStatements( statementSequence );
          Check( Scanner.End );
          statements.AddStatement( loopStatement );
          result := TRUE;
      | Scanner.Exit:
          NextSymbol;
          statement := SyntaxTree.NewExitStatement( symbol.start, outer);
          statements.AddStatement( statement );
          result := TRUE;
      | Scanner.Return:
          NextSymbol;
          returnStatement := SyntaxTree.NewReturnStatement( symbol.start, outer);
          IF (symbol.token >= Scanner.Plus) & (symbol.token <= Scanner.Identifier) THEN
            expression := Expression();
            returnStatement.SetReturnValue( expression );
          END;
          statements.AddStatement( returnStatement );
          result := TRUE;
      | Scanner.Begin:
          NextSymbol;  statement := StatementBlock(outer);  statements.AddStatement( statement );  Check( Scanner.End );
          result := TRUE;
      | Scanner.Await:
          awaitStatement := SyntaxTree.NewAwaitStatement( symbol.start, outer );
          NextSymbol;
          expression := Expression();
          awaitStatement.SetCondition( expression );
          statements.AddStatement( awaitStatement );
          result := TRUE
      | Scanner.Code:
        (* assemble *)
        code := Code(outer);
        Check(Scanner.End);
        statements.AddStatement( code );
        result := TRUE
      | Scanner.End:  result := FALSE (* end of if, with, case, while, for, loop, or statement sequence *)
      | Scanner.Until: result := FALSE  (* end of repeat *)
      | Scanner.Else:  result := FALSE (* else of if or case *)
      | Scanner.Elsif:  result := FALSE (* elsif of if *)
      | Scanner.Bar:  result := FALSE (* next case *)
      | Scanner.Finally: result := FALSE  (* end block by finally statement *)
      | Scanner.Semicolon: result := FALSE (* allow the empty statement *)
      (* builtin pseudo procedures are resolved by checker *)
      ELSE Error( symbol.start, Scanner.Semicolon, "" ); result := FALSE;
      END;
      IF Trace THEN E( "Statement" ) END;
      RETURN result
    END Statement;

    (** StatementSequence = Statement {';' Statement}. **)
    PROCEDURE StatementSequence(outer: SyntaxTree.Statement ): SyntaxTree.StatementSequence;
    VAR statements: SyntaxTree.StatementSequence; b: BOOLEAN;
    BEGIN
      IF Trace THEN S( "StatementSequence" ) END;
      statements := SyntaxTree.NewStatementSequence();
      IF Lax THEN
        WHILE ~Peek(Scanner.Return) & Statement(statements,outer) DO Ignore(Scanner.Semicolon) END;
        IF Peek(Scanner.Return) & Statement(statements,outer) THEN Ignore(Scanner.Semicolon) END; (* return bound to end of statement sequence *)
      ELSE
        REPEAT
          b := Statement( statements,outer )
        UNTIL ~Optional( Scanner.Semicolon );
      END;
      IF Trace THEN E( "StatementSequence" ) END;
      RETURN statements
    END StatementSequence;

    (** StatementBlock = ['{' BlockModifier '}'] StatementSequence. **)
    PROCEDURE StatementBlock(outer: SyntaxTree.Statement): SyntaxTree.StatementBlock;
    VAR block: SyntaxTree.StatementBlock;
    BEGIN
      IF Trace THEN S( "StatementBlock" ) END;
      block := SyntaxTree.NewStatementBlock( symbol.end, outer );
      IF Optional( Scanner.LeftBrace ) THEN
        block.SetModifier(Flags());
      END;
      block.SetStatementSequence( StatementSequence(block) );
      IF Trace THEN E( "StatementBlock" ) END;
      RETURN block
    END StatementBlock;

    (** Code = {  Any \ 'end' } . **)
    PROCEDURE Code(outer: SyntaxTree.Statement): SyntaxTree.Code;
    VAR startPos, endPos, i ,len: LONGINT; codeString: Scanner.SourceString; code: SyntaxTree.Code;
    BEGIN
      startPos := symbol.start;
      IF scanner.SkipToNextEnd(startPos, endPos, symbol) THEN
        codeString := symbol.source;
        code := SyntaxTree.NewCode(startPos,outer);
        i := 0; len := LEN(codeString);
        code.SetSourceCode(codeString,len);
      END;
      RETURN code;
    END Code;

    (** wrapper for a body in records and modules *)
    PROCEDURE BodyProcedure(parentScope: SyntaxTree.Scope): SyntaxTree.Procedure;
    VAR procedureScope: SyntaxTree.ProcedureScope; procedure: SyntaxTree.Procedure;
    BEGIN
      procedureScope := SyntaxTree.NewProcedureScope(parentScope);
      IF parentScope IS SyntaxTree.ModuleScope THEN
        procedure := SyntaxTree.NewProcedure( symbol.start, Global.ModuleBodyName,procedureScope);
        procedure.SetAccess(SyntaxTree.Hidden);
      ELSE
        procedure := SyntaxTree.NewProcedure( symbol.start, Global.RecordBodyName,procedureScope);
        (*! todo: make this a hidden symbol. Problematic when used with paco. *)
        procedure.SetAccess(SyntaxTree.Public + SyntaxTree.Protected + SyntaxTree.Internal);
      END;
      parentScope.AddProcedure(procedure);
      procedure.SetType(SyntaxTree.NewProcedureType(-1,parentScope));
      procedure.SetBodyProcedure(TRUE);
      procedureScope.SetBody(Body(procedureScope));
      RETURN procedure
    END BodyProcedure;

    (* ProcedureType = 'procedure' [Flags] [FormalParameters]. *)
    PROCEDURE ProcedureType(position: LONGINT;  parentScope: SyntaxTree.Scope): SyntaxTree.ProcedureType;
    VAR procedureType: SyntaxTree.ProcedureType;
    BEGIN
      IF Trace THEN S( "ProcedureType" ) END;
      (* procedure symbol already consumed *)
      procedureType := SyntaxTree.NewProcedureType( position, parentScope);
      IF Optional(Scanner.LeftBrace) THEN
        procedureType.SetModifiers(Flags());
      END;
      IF Optional(Scanner.LeftParenthesis) THEN FormalParameters( procedureType, parentScope) END;
      IF Trace THEN E( "ProcedureType" )
      END;
      RETURN procedureType;
    END ProcedureType;

    (** ParameterDeclaration = ['var'|'const'] Identifier {',' Identifier}':' Type.**)
    PROCEDURE ParameterDeclaration( procedureType: SyntaxTree.ProcedureType ; parentScope: SyntaxTree.Scope);
    VAR
      type: SyntaxTree.Type; name: SyntaxTree.Identifier;
      firstParameter, parameter: SyntaxTree.Parameter;   kind: LONGINT;
    BEGIN
      IF Trace THEN S( "ParameterDeclaration" ) END;
      IF Optional( Scanner.Var ) THEN (* var parameter *)
        kind := SyntaxTree.VarParameter
      ELSIF Optional( Scanner.Const ) THEN (* const parameter *)
        kind := SyntaxTree.ConstParameter
      ELSIF symbol.token # Scanner.Identifier THEN
        Error(symbol.start,Scanner.Identifier,"");
        RETURN
      ELSE kind := SyntaxTree.ValueParameter
      END;
      firstParameter := procedureType.lastParameter;
      REPEAT
        name := Identifier();
        parameter := SyntaxTree.NewParameter(name.position,procedureType,name,kind);
        procedureType.AddParameter(parameter);
      UNTIL ~Optional( Scanner.Comma );
      Check( Scanner.Colon );
      type := Type( NIL, parentScope);
      ASSERT(type # NIL);
      IF firstParameter # NIL THEN parameter := firstParameter.nextParameter ELSE parameter := procedureType.firstParameter END;
      WHILE parameter # NIL DO
        parameter.SetType( type );
        parameter := parameter.nextParameter;
      END;
      IF Trace THEN E( "ParameterDeclaration" )
      END;
    END ParameterDeclaration;
*)
    PROCEDURE CommentSymbol(symbol: SyntaxTree.Symbol);
    BEGIN
      IF (recentComment # NIL) & (recentComment.nextSymbol = NIL) THEN
        recentComment.SetNextSymbol(symbol);
      END;
      recentSymbol := symbol
    END CommentSymbol;
(*
    (** OperatorDeclaration  = 'operator' String ['*'|'-'] FormalParameters ';'
                             DeclarationSequence [Body] 'end' String.
    **)
    PROCEDURE OperatorDeclaration(parentScope: SyntaxTree.Scope );
    VAR
      string: Scanner.StringType; name: Scanner.StringType;
      procedureScope: SyntaxTree.ProcedureScope;
      procedureType: SyntaxTree.ProcedureType;
      operator: SyntaxTree.Operator;
      access: SET;
      i: LONGINT; ch: CHAR; position: LONGINT;
    BEGIN
      IF Trace THEN S( "Operator" ) END;
      (* symbol operator already consumed *)
      position := symbol.start;
      IF MandatoryString( string ) THEN
        (* copy string to name and check for length. LEN(name)>0, LEN(string)>0 can be presumed  *)
        i := 0;
        REPEAT
          ch := string[i];
          name[i] := ch;
          INC(i);
        UNTIL (ch = 0X) OR (i=LEN(string)) OR (i=LEN(name));
        IF ch # 0X THEN (* string too long to act as operator identifier *)
          Error(symbol.start,Basic.StringTooLong,"");
          name := "";
        END;
      ELSE
        name := "";
      END;
      IF Optional( Scanner.Times ) THEN access := SyntaxTree.ReadOnly;
      ELSIF Optional( Scanner.Minus ) THEN access := SyntaxTree.ReadOnly;
      ELSE access := SyntaxTree.Internal;
      END;
      procedureScope := SyntaxTree.NewProcedureScope(parentScope);
      operator := SyntaxTree.NewOperator( symbol.start, SyntaxTree.NewIdentifier(position,name), procedureScope);
      CommentSymbol(operator);
      operator.SetAccess(access * SyntaxTree.ReadOnly);
      procedureType := SyntaxTree.NewProcedureType(symbol.start,parentScope);
      IF Mandatory(Scanner.LeftParenthesis) THEN FormalParameters( procedureType, procedureScope ) END;
      operator.SetType( procedureType );
      IF Lax THEN Ignore(Scanner.Semicolon) ELSE Check( Scanner.Semicolon ) END;
      DeclarationSequence( procedureScope );
      IF Peek(Scanner.Begin) OR Peek(Scanner.Code) THEN
        procedureScope.SetBody(Body(procedureScope));
      END;
      IF Mandatory(Scanner.End) & ExpectThisString(string) THEN END;
      parentScope.AddProcedure(operator);
      IF parentScope IS SyntaxTree.ModuleScope THEN
        parentScope(SyntaxTree.ModuleScope).AddOperator(operator);
      ELSIF parentScope IS SyntaxTree.RecordScope THEN
        parentScope(SyntaxTree.RecordScope).AddOperator(operator);
      ELSE
        Error(position,Diagnostics.Invalid,"Operators only allowed in module scope");
      END;
      IF Trace THEN EE( "Operator", name ) END;
    END OperatorDeclaration;

    (** VariableNameList = IdentifierDefinition [Flags] {',' IdentifierDefinition [Flags]}.**)
    PROCEDURE VariableNameList( scope: SyntaxTree.Scope );
    VAR varname: SyntaxTree.Identifier;  position: LONGINT; variable: SyntaxTree.Variable;  flags,access: SET;
    BEGIN
      IF Trace THEN S( "VariableNameList" ) END;
      REPEAT
        flags := {};
        position := symbol.start;
        IdentifierDefinition( varname, access,TRUE);
        variable := SyntaxTree.NewVariable( position, varname );
        CommentSymbol(variable);
        IF Optional(Scanner.LeftBrace) THEN variable.SetModifiers(Flags()) END;
        variable.SetAccess(access);
        scope.AddVariable(variable);
      UNTIL ~Optional( Scanner.Comma );
      IF Trace THEN E( "VariableNameList" ) END;
    END VariableNameList;

    (** VariableDeclaration = VariableNameList ':' Type. **)
    PROCEDURE VariableDeclaration(parentScope: SyntaxTree.Scope );
    VAR
      variable, firstVariable: SyntaxTree.Variable; type: SyntaxTree.Type;
    BEGIN
      IF Trace THEN S( "VariableDeclaration" ) END;
      firstVariable := parentScope.lastVariable;
      VariableNameList( parentScope );
      Check( Scanner.Colon );
      type := Type( NIL, parentScope );

      variable := firstVariable;
      IF firstVariable #  NIL THEN variable := firstVariable.nextVariable ELSE variable := parentScope.firstVariable END;
      WHILE variable # NIL  DO
        variable.SetType( type );
        variable := variable.nextVariable;
      END;
      IF Trace THEN E( "VariableDeclaration" ) END;
    END VariableDeclaration;

    (** TypeDeclaration = IdentifierDefinition '=' Type.**)
    PROCEDURE TypeDeclaration(parentScope: SyntaxTree.Scope);
    VAR name: SyntaxTree.Identifier;  position: LONGINT; type: SyntaxTree.Type; typeDeclaration: SyntaxTree.TypeDeclaration;   access: SET;
    BEGIN
      IF Trace THEN S( "TypeDeclaration" ) END;
      position := symbol.start;
      IdentifierDefinition( name, access,FALSE);
      typeDeclaration := SyntaxTree.NewTypeDeclaration( position,name);
      CommentSymbol(typeDeclaration);
      Check( Scanner.Equal );
      type := Type( name , parentScope);
      type.SetTypeDeclaration(typeDeclaration);
      typeDeclaration.SetDeclaredType(type);
      (*
      type.SetName(typeDeclaration.name);  (* don't do that: overwrites global names ! *)
      *)
      typeDeclaration.SetAccess(access * SyntaxTree.ReadOnly);
      parentScope.AddTypeDeclaration( typeDeclaration );
      IF Trace THEN E( "TypeDeclaration" ) END;
    END TypeDeclaration;

    (** ConstDeclaration = IdentifierDefinition '=' Expression. **)
    PROCEDURE ConstDeclaration(parentScope: SyntaxTree.Scope );
    VAR name: SyntaxTree.Identifier;  position: LONGINT; constant: SyntaxTree.Constant;  expression: SyntaxTree.Expression;  access: SET;
    BEGIN
      IF Trace THEN S( "ConstDeclaration" ) END;
      IdentifierDefinition( name, access, FALSE);
      position := symbol.start;
      constant := SyntaxTree.NewConstant( position, name );
      CommentSymbol(constant);
      constant.SetAccess(access * SyntaxTree.ReadOnly);
      Check( Scanner.Equal );
      expression := Expression();
      constant.SetValue( expression );
      parentScope.AddConstant( constant );
      IF Trace THEN E( "ConstDeclaration" ) END;
    END ConstDeclaration;
*)

    PROCEDURE StmtSequence( parentScope: SyntaxTree.Scope );
    VAR
    BEGIN
      IF Trace THEN S( "StmtSequence" ) END;
      IF Trace THEN E( "StmtSequence" ) END;
    END StmtSequence;

(**
  OpImmediate   = Symbol
                | Int
                | Hex
                | Float
                .
**)
    PROCEDURE OpImmediate( parentScope: SyntaxTree.Scope ):BOOLEAN;
    VAR
    BEGIN
      IF Trace THEN S( "OpImmediate" ) END;
      IF Trace THEN E( "OpImmediate" ) END;
    END OpImmediate;

(**
  MemoryAddr    = Register [ Int ]
                | Symbol
                | Int
                .
**)
    PROCEDURE MemoryAddr( parentScope: SyntaxTree.Scope ):BOOLEAN;
    VAR
    BEGIN
      IF Trace THEN S( "MemoryAddr" ) END;
      IF Trace THEN E( "MemoryAddr" ) END;
    END MemoryAddr;

(**
  Register      = '$' 'SP'
                | '$' 'FP'
                | '$' Int
                | '$' 'R' '#' Int
                .
**)
    PROCEDURE Register( parentScope: SyntaxTree.Scope ):BOOLEAN;
    VAR
    BEGIN
      IF Trace THEN S( "Register" ) END;
      IF Trace THEN E( "Register" ) END;
    END Register;

    PROCEDURE String( parentScope: SyntaxTree.Scope ):BOOLEAN;
    VAR
    BEGIN
      IF Trace THEN S( "String" ) END;
      IF Trace THEN E( "String" ) END;
    END String;

(**
  Operand       = Type '[' MemoryAddr ']'       ; Memory Operand
                | Type Register [ Int ]         ; Register Operand
                | Type OpImmediate              ; Immediate Operand
                | Type String                   ; String Operand
                | Int                           ; Number Operand
                .
**)
    PROCEDURE Operand( parentScope: SyntaxTree.Scope );
    VAR
      value	: HUGEINT;
      dummy : BOOLEAN;
      type : Fs.StringType;
    BEGIN
      IF Trace THEN S( "Operand" ) END;
      IF MandatoryIdentifier( type ) THEN
        (* Type *)
        IF Optional( Scanner.TK_LeftBracket ) THEN
        
        ELSIF Register( parentScope ) THEN
        
        ELSIF OpImmediate( parentScope ) THEN
        
        ELSIF String( parentScope ) THEN
        
        ELSE
          Error( symbol.start, symbol.token, "Operand" );
        END;
      ELSE
        (* Number *)
        dummy := MandatoryInteger( value );
	 END;
      IF Trace THEN E( "Operand" ) END;
    END Operand;

(**
  Const         = 'data' Operand .
**)
    PROCEDURE ConstSequence( parentScope: SyntaxTree.Scope );
    VAR
    BEGIN
      IF Trace THEN S( "ConstSequence" ) END;
      WHILE Optional( Scanner.TK_Data ) DO
        Operand( parentScope );
      END;
      IF Trace THEN E( "ConstSequence" ) END;
    END ConstSequence;


(**
  SectionOffset = 'offset' '=' Int .
**)
    PROCEDURE SectionOffset( parentScope: SyntaxTree.Scope);
    VAR
      value : HUGEINT;
    BEGIN
      IF Trace THEN S( "SectionOffset" ) END;
      IF Mandatory( Scanner.TK_Offset ) THEN
        IF Mandatory( Scanner.TK_Becomes ) THEN
          IF MandatoryInteger( value ) THEN
          END;
        END;
      END;
      IF Trace THEN E( "SectionOffset" ) END;
    END SectionOffset;

(**
  Section       = 'bodycode' SymbolName SectionOffset { Stmt }
                | 'inlinecode' SymbolName SectionOffset { Stmt }
                | 'initcode' SymbolName SectionOffset { Stmt }
                | 'var' SymbolName SectionOffset { Var }
                | 'const' SymbolName SectionOffset { Const }
                | 'code' SymbolName SectionOffset { Stmt }
                .
**)
    PROCEDURE Section( parentScope: SyntaxTree.Scope);
    VAR
      previousScope: SyntaxTree.Scope;
      name : SyntaxTree.Identifier;
    BEGIN
      previousScope := currentScope;
      currentScope := parentScope;
      IF Trace THEN S( "Section" ) END;
      LOOP
        IF Optional( Scanner.TK_Bodycode ) THEN
          name := Identifier();
          SectionOffset( parentScope );
          StmtSequence( parentScope );
        ELSIF Optional( Scanner.TK_Inlinecode ) THEN
(*          ...*)
        ELSIF Optional( Scanner.TK_Const ) THEN
          name := Identifier();
          SectionOffset( parentScope );
          ConstSequence( parentScope );
        ELSE EXIT
        END;
      END;
      currentScope := previousScope;
      IF Trace THEN E( "Section" ) END;
    END Section;

(**
  Import        = 'imports' SymbolName { ',' SymbolName } .
**)
    PROCEDURE ImportList( moduleScope: SyntaxTree.ModuleScope );
    VAR
      name : SyntaxTree.Identifier;
      import        : SyntaxTree.Import;
      position      : LONGINT;
    BEGIN
      IF Trace THEN S( "Import" ) END;
      (* import symbol already consumed *)
      REPEAT
        position := symbol.start;
        name := Identifier();
        IF name # SyntaxTree.invalidIdentifier THEN
          import := SyntaxTree.NewImport( position, name, name, TRUE );
          CommentSymbol(import);
          moduleScope.AddImport( import );
        END;
      UNTIL ~Optional( Scanner.TK_Comma );
      IF Trace THEN E( "Import" );  END;
    END ImportList;

(**
  Module        = 'module' SymbolName [Import] { Section } .
**)
    PROCEDURE Module*(): SyntaxTree.Module;
    VAR moduleName: SyntaxTree.Identifier;  module: SyntaxTree.Module;  position: LONGINT; 
    BEGIN
      IF Trace THEN S( "Module" ) END;
      position := symbol.start;
      moduleScope := SyntaxTree.NewModuleScope(); (* needed to feed in comment already before module starts *)
      currentScope := moduleScope;
      IF Mandatory( Scanner.TK_Module ) THEN
        moduleName :=  Identifier();
        module := SyntaxTree.NewModule( scanner.source, moduleName.position, moduleName, moduleScope, 0 );
        module.SetType(SyntaxTree.moduleType);
        CommentSymbol(module);
        IF Optional(Scanner.TK_Imports) THEN
        	ImportList(moduleScope)
        END;
        Section( moduleScope );
      END;
      IF Trace THEN E( "Module" ) END;
      RETURN module
    END Module;

    (** check if another module declaration is available after recent module parsing -> for parsing and compiling multiple modules within a single file **)
    PROCEDURE NextModule*(): BOOLEAN;
    BEGIN
      NextSymbol;
      RETURN Peek(Scanner.TK_Module);
    END NextModule;

  END Parser;

  (* utilities *)
(*  PROCEDURE AppendModifier(VAR list: SyntaxTree.Modifier; modifier: SyntaxTree.Modifier);
  VAR this, next: SyntaxTree.Modifier;
  BEGIN
    IF list = NIL THEN list := modifier
    ELSE
      this := list;
      next := list.nextModifier;
      WHILE next # NIL DO
        this := next;
        next := this.nextModifier;
      END;
      this.SetNext(modifier);
    END;
  END AppendModifier;*)

  (** parser retrieval **)
  PROCEDURE NewParser*( scanner: Scanner.AssemblerScanner;  diagnostics: Diagnostics.Diagnostics): Parser;
  VAR parser: Parser;
  BEGIN
    NEW( parser, scanner, diagnostics );  RETURN parser;
  END NewParser;

END FoxIntermediateParser.


