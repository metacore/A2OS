MODULE OFormatter IN Oberon;

(* Formatter for Oberon2 Modules. Parser part taken from OOPP *)
(* usage: see O2Formatter.Tool	*)

(* G.Feldmann	14.1.99	*)
(*	2001.01.30	g.f.	adapted to NO compiler *)
(*  2003.05.05 fof adapted to NO compiler with Active Objects *)

IMPORT IO := OFormatterIO, Texts, Files, Oberon, Out, Display, Objects, EditTools;

CONST
	(* symbol values *)
	null* = 0;  times* = 1;  slash* = 2;  div* = 3;  mod* = 4;  and* = 5;  plus* = 6;  minus* = 7;  or* = 8;  eql* = 9;  neq* = 10;  lss* = 11;  leq* = 12;  gtr* = 13;
	geq* = 14;  in* = 15;  is* = 16;  arrow* = 17;  period* = 18;  comma* = 19;  colon* = 20;  upto* = 21;  rparen* = 22;  rbrak* = 23;  rbrace* = 24;  of* = 25;
	then* = 26;  do* = 27;  to* = 28;  by* = 29;  lparen* = 30;  lbrak* = 31;  lbrace* = 32;  not* = 33;  becomes* = 34;  number* = 35;  nil* = 36;  true* = 37;
	false* = 38;  string* = 39;  ident* = 40;  semicolon* = 41;  bar* = 42;  end* = 43;  else* = 44;  elsif* = 45;  until* = 46;  if* = 47;  case* = 48;  while* = 49;
	repeat* = 50;  for* = 51;  loop* = 52;  with* = 53;  exit* = 54;  passivate* = 55;  return* = 56;  refines* = 57;  implements* = 58;  array* = 59;
	definition* = 60;  object* = 61;  record* = 62;  pointer* = 63;  begin* = 64;  code* = 65;  const* = 66;  type* = 67;  var* = 68;  procedure* = 69;
	import* = 70;  module* = 71;  eof* = 72;  finally* = 73;
	(** fof >> *)
	backslash* = 74;  scalarproduct* = 75;  elementproduct* = 76;  elementquotient* = 77;  dtimes* = 78;  transpose* = 79;  eeql* = 80;  eneq* = 81;
	elss* = 82;  eleq* = 83;  egtr* = 84;  egeq* = 85;  qmark* = 86;  filler* = qmark;
	(** << fof  *)

	undef = 1000;  list = 2;  relop = 3;  addop = 4;  mulop = 5;

TYPE
	BreakPoint = IO.BreakPoint;  ssBP = IO.ssBP;
	Task = POINTER TO RECORD (Oberon.Task)
		frame: Display.Frame;
		text: Texts.Text;
		changed: BOOLEAN;
		lastchanged: SIGNED32;
	END;
VAR
	sym, level: SIGNED8;  noerr: BOOLEAN;  inFormPar: BOOLEAN;  exprdepth: SIGNED16;  sline: SIGNED16;  found: BOOLEAN;  silent, notrap: BOOLEAN;
	forceNL: BOOLEAN;  nobp: BreakPoint;

	PROCEDURE debug( s: ARRAY OF CHAR );
	BEGIN
		Out.String( s );  Out.Ln;
	END debug;

	PROCEDURE clearBPS( bps: ssBP;  k: SIGNED16 );
	VAR i: SIGNED16;
	BEGIN
		IF bps = NIL THEN RETURN END;
		FOR i := k TO 9 DO IO.clearBP( bps.bp[i] ) END
	END clearBPS;

	PROCEDURE DecExprdepth( bps: ssBP );
	VAR i: SIGNED16;
	BEGIN
		DEC( exprdepth );
		IF exprdepth = 1 THEN clearBPS( bps, 6 ) END
	END DecExprdepth;

	PROCEDURE getBP( bps: ssBP;  k: SIGNED8 );
	VAR i: SIGNED16;
	BEGIN
		IF bps = NIL THEN RETURN END;
		CASE k OF
		| 0:   IO.getBP( bps.bp[0] );  clearBPS( bps, 1 );
		| 1:   IO.getBPind( bps.bp[1] );  clearBPS( bps, 2 );
		| 2, 3, 4, 5:
				IF exprdepth = 1 THEN IO.getBPind2( bps.bp[k], exprdepth );  i := k + 1
				ELSIF exprdepth = 2 THEN IO.getBPind2( bps.bp[k + 4], exprdepth );  i := k + 5
				ELSE i := 10
				END;
				clearBPS( bps, i );
		END;
	END getBP;

	PROCEDURE checkLine( bps: ssBP );
	VAR i: SIGNED16;
	BEGIN
		IF (bps # NIL ) & (IO.width >= IO.MaxLineLength) THEN
			IO.breakLine( bps.fbp );  sline := IO.curLine;
			IF IO.width >= IO.MaxLineLength THEN
				IO.breakLine( bps.bbp );  i := 0;  sline := IO.curLine;
				WHILE (IO.width >= IO.MaxLineLength) & (i < 10) DO
					IF bps.bp[i] # NIL THEN
						IO.breakLine( bps.bp[i] );
						IF i = 0 THEN sline := IO.curLine END;
					END;
					INC( i );
				END
			END
		END;
	END checkLine;

	PROCEDURE doForcedNL;
	VAR i: SIGNED16;
	BEGIN
		IF IO.forceNL THEN IO.prepNL;  IO.forceNL := FALSE END
	END doForcedNL;

	PROCEDURE markIndent;
	VAR i: SIGNED16;
	BEGIN
		IF exprdepth IN {1, 2} THEN IO.markIndent( exprdepth ) END
	END markIndent;

	PROCEDURE err( n: SIGNED16 );
	BEGIN
		IF ~silent THEN
			IO.err( n );  noerr := FALSE;
			IF ~notrap THEN HALT( 1000 ) END;
		END;
	END err;

	PROCEDURE CheckSym( s: SIGNED16 );
	BEGIN
		IF sym = s THEN IO.Get( sym ) ELSE err( s ) END
	END CheckSym;

	PROCEDURE qualident;
	VAR lev: SIGNED8;
	BEGIN
		IO.Get( sym );
		IF (sym = period) THEN
			IO.Get( sym );
			IF sym = ident THEN IO.Get( sym ) ELSE err( ident ) END
		END;
	END qualident;

	PROCEDURE ConstExpression;
	BEGIN
		Expression( NIL );
	END ConstExpression;

	PROCEDURE CheckMark;
	BEGIN
		IO.checkMark;  IO.Get( sym );
		IF (sym = times) OR (sym = minus) THEN IO.Get( sym ) END
	END CheckMark;

	PROCEDURE CheckSysFlag;
	VAR sf: SIGNED32;
	BEGIN
		IF sym = lbrak THEN IO.Get( sym );  ConstExpression();  IO.appSP();  CheckSym( rbrak )
		ELSIF sym = lbrace THEN
			IO.Get( sym );  ConstExpression();  IO.appSP();  CheckSym( rbrace )
			(* ELSIF sym = minus THEN IO.Get( sym );   *)
		END
	END CheckSysFlag;

	PROCEDURE RecordType( VAR bp: BreakPoint );
	BEGIN
		CheckSysFlag();   (* IO.incInd; IO.incInd; *) IO.breakLine( bp );
		IF sym = lparen THEN IO.Get( sym );
			(*record extension*)
			IF sym = ident THEN qualident();
			ELSIF sym = object THEN IO.Get( sym )
			ELSE err( ident )
			END;
			CheckSym( rparen )
		END;
		IF sym = semicolon THEN IO.Get( sym )  END;
		IF sym = end THEN IO.Get( sym ) ELSE INC( level );  Block( TRUE );  DEC( level ) END;
		(* IO.decInd;  IO.decInd*)
	END RecordType;

	PROCEDURE ArrayType( VAR bp: BreakPoint;  enhArray: BOOLEAN );
	BEGIN
		IF sym = lbrace THEN  (* sys flags *)
			IO.Get( sym );  ConstExpression();  IO.appSP();  CheckSym( rbrace )
		ELSIF sym = lbrak THEN  (* sys flags *)
			IO.Get( sym );  ConstExpression();  IO.appSP();  CheckSym( rbrak )
		END;
		IF (~enhArray) & (sym = lbrak) THEN IO.appSP();  enhArray := TRUE;  IO.Get( sym )  END;

		IF enhArray THEN
			IF (sym = times) OR (sym = qmark) THEN IO.appSP();  IO.Get( sym )  ELSE Expression( NIL ) END;
			IF sym = rbrak THEN IO.Get( sym );  CheckSym( of );  TypeDecl( bp );
			ELSIF sym = comma THEN IO.Get( sym );  ArrayType( bp, TRUE );
			ELSE err( rbrak );  RETURN
			END;
		ELSIF sym = of THEN IO.appSP;  IO.Get( sym );  TypeDecl( bp );
		ELSE
			ConstExpression();
			IF sym = of THEN IO.appSP;  IO.Get( sym );  TypeDecl( bp );  IO.breakLine( bp );
			ELSIF sym = comma THEN
				IO.appSP;  IO.Get( sym );
				IF sym # of THEN ArrayType( bp, FALSE ) END
			ELSE err( 35 )
			END;
		END;
	END ArrayType;

	PROCEDURE ObjectType( VAR bp: BreakPoint );
	BEGIN
		CheckSysFlag();   (* IO.incInd; IO.incInd; *) IO.breakLine( bp );
		IF sym = lparen THEN IO.Get( sym );
			(*record extension*)
			IF sym = ident THEN qualident();
			ELSIF sym = object THEN IO.Get( sym )
			ELSE err( ident )
			END;
			CheckSym( rparen )
		END;
		IF sym = implements THEN IO.Get( sym )  END;
		IF sym = semicolon THEN IO.Get( sym )  END;
		IF sym = end THEN IO.Get( sym ) ELSE INC( level );  Block( TRUE );  DEC( level ) END;
		(* IO.decInd;  IO.decInd*)
	END ObjectType;

	PROCEDURE Definition( VAR bp: BreakPoint );
	BEGIN
		IF sym = refines THEN IO.Get( sym )  END;
		CheckSym( ident );
		IF sym = semicolon THEN IO.Get( sym )  END;
		IF sym = end THEN IO.Get( sym ) ELSE INC( level );  DefinitionBlock( TRUE );  DEC( level )  END;

		IF sym = ident THEN IO.Get( sym )
		END;
		(* IO.decInd;  IO.decInd*)
	END Definition;

	PROCEDURE PointerType( VAR bp: BreakPoint );
	BEGIN
		CheckSysFlag();  CheckSym( to );
		IF sym = ident THEN qualident()  ELSE TypeDecl( bp )  END;
		IO.breakLine( bp );
	END PointerType;

	PROCEDURE FormalParameters;
	VAR indent: SIGNED16;  bp: BreakPoint;
	BEGIN
		IO.prepSP;  inFormPar := TRUE;  exprdepth := 1;  IO.markIndent( exprdepth );  bp := NIL;
		IF (sym = ident) OR (sym = var) OR (sym = const) THEN
			LOOP
				IF (sym = var) OR (sym = const) THEN
					IO.Get( sym );
					IF sym = lbrace THEN  (* sys flags *)
						IO.Get( sym );  ConstExpression();  IO.appSP();  CheckSym( rbrace )
					END;
				END;
				LOOP
					IF (sym = ident) THEN
						IO.Get( sym );
						IF sym = upto THEN  (* a..b BY c *)  (* range type fof *)
							IO.Get( sym );  CheckSym( ident );  CheckSym( by );  CheckSym( ident );
						ELSIF sym = filler THEN IO.Get( sym );
						END;
					ELSE err( ident )
					END;
					IF sym = comma THEN IO.Get( sym )
					ELSIF sym = ident THEN err( comma )
					ELSIF sym = var THEN err( comma );  IO.Get( sym )
					ELSE EXIT
					END
				END;
				CheckSym( colon );  Type();
				IF sym = semicolon THEN IO.Get( sym );
				ELSIF sym = ident THEN err( semicolon )
				ELSE EXIT
				END;
				IF IO.width >= IO.MaxLineLength THEN IO.breakLine( bp ) END;
				IO.getBPind2( bp, exprdepth );
			END
		END;
		IO.prepSP;  CheckSym( rparen );
		IF sym = colon THEN
			IO.Get( sym );
			IF sym = ident THEN qualident();
			ELSIF sym = array THEN
				IO.Get( sym );  ArrayType( bp, FALSE );
				(* ELSIF sym= tensor THEN IO.Get( sym );  ArrayType( bp, FALSE);   *)
			ELSE err( ident )
			END
		END;
		IF IO.width >= IO.MaxLineLength THEN IO.breakLine( bp ) END;
		inFormPar := FALSE;
	END FormalParameters;

	PROCEDURE TypeDecl( VAR bp: BreakPoint );
	BEGIN
		IF sym < lparen THEN
			err( 12 );
			REPEAT IO.Get( sym ) UNTIL sym >= lparen
		END;
		IF sym = ident THEN qualident();
		ELSIF (sym = array) (* OR (sym=tensor) *) THEN
			IO.Get( sym );  ArrayType( bp, FALSE );
			IF ~inFormPar THEN IO.forceNL := TRUE END
		ELSIF sym = record THEN
			IO.Get( sym );  RecordType( bp );
			IF sym = ident THEN IO.Get( sym ) END;
			IO.forceNL := TRUE
		ELSIF sym = pointer THEN IO.Get( sym );  PointerType( bp );  IO.forceNL := TRUE
		ELSIF sym = object THEN
			IO.Get( sym );
			IF (sym # semicolon) & (sym # rparen) THEN
				ObjectType( bp );
				IF sym = ident THEN IO.Get( sym ) END;
				IO.forceNL := TRUE
			END;
		ELSIF sym = procedure THEN
			IO.Get( sym );  CheckSysFlag();
			IF sym = lparen THEN IO.Get( sym );  FormalParameters()  END;
			IO.forceNL := TRUE;
		ELSE err( 12 )
		END;
		LOOP
			IF ((sym >= semicolon) & (sym <= else)) OR (sym = rparen) OR (sym = eof) THEN EXIT END;
			err( 15 );
			IF sym = ident THEN EXIT END;
			IO.Get( sym )
		END;
	END TypeDecl;

	PROCEDURE Type;
	VAR bp: BreakPoint;
	BEGIN
		bp := NIL;  TypeDecl( bp );
	END Type;

	PROCEDURE ActualParameters( bps: ssBP );
	VAR line: SIGNED16;
	BEGIN
		IF sym # rparen THEN
			IO.prepSP;  line := IO.curLine;  INC( exprdepth );  markIndent;
			LOOP
				Range( bps );  checkLine( bps );
				IF sym = comma THEN IO.Get( sym );
				ELSIF (lparen <= sym) & (sym <= ident) THEN err( comma )
				ELSE IO.prepSP;  EXIT
				END;
				getBP( bps, 2 );
			END;
			DecExprdepth( bps );  CheckSym( rparen );
			IF IO.curLine > line THEN IO.forceNL := TRUE END;
		ELSE IO.Get( sym )
		END;
	END ActualParameters;

	PROCEDURE selector( bps: ssBP );
	BEGIN
		LOOP
			IF sym = lbrak THEN
				INC( exprdepth );  IO.Get( sym );  markIndent;
				LOOP
					Range( bps );
					IF sym = comma THEN IO.Get( sym );  checkLine( bps );  getBP( bps, 2 ) ELSE EXIT END
				END;
				DecExprdepth( bps );  CheckSym( rbrak )
			ELSIF sym = period THEN
				IO.Get( sym );
				IF sym = ident THEN
					IO.Get( sym );
					IF sym = arrow THEN
						(* super call *)
						IO.Get( sym );
					END
				ELSE err( ident )
				END
			ELSIF sym = arrow THEN IO.Get( sym );
			ELSIF sym = lparen THEN IO.Get( sym );  ActualParameters( bps );
			ELSE EXIT
			END
		END
	END selector;

	PROCEDURE Element;
	BEGIN
		Expression( NIL );
		IF sym = upto THEN IO.Get( sym );  Expression( NIL )  END
	END Element;

	PROCEDURE Sets;
	BEGIN
		IF sym # rbrace THEN
			Element();
			LOOP
				IF sym = comma THEN IO.Get( sym )
				ELSIF (lparen <= sym) & (sym <= ident) THEN err( comma )
				ELSE EXIT
				END;
				Element();
			END
		END;
		CheckSym( rbrace )
	END Sets;

	PROCEDURE ConstArray( bps: ssBP );
	BEGIN
		IO.Get( sym );
		LOOP
			IF sym = lbrak THEN ConstArray( bps )  ELSE Expression( bps )  END;
			IF sym = comma THEN IO.Get( sym )  ELSE EXIT END;
		END;
		CheckSym( rbrak );
	END ConstArray;

	PROCEDURE Range( bps: ssBP );
	VAR isRange: BOOLEAN;
	BEGIN
		IF sym = upto THEN
			IO.appSP();   (* ".." without first argument *)
		ELSIF sym = times THEN IO.appSP();  IO.Get( sym );
		ELSIF sym = filler THEN IO.Get( sym );
		ELSE Expression( bps );  isRange := FALSE;
		END;

		IF (sym = upto) THEN
			isRange := TRUE;  IO.Get( sym );
			IF sym = by THEN  (* ".." without second argument *)
				IO.Get( sym );  Expression( bps );
			ELSIF (sym = comma) OR (sym = rbrak) OR (sym = rparen) THEN RETURN;
			ELSE
				Expression( bps );
				IF sym = by THEN IO.Get( sym );  Expression( bps )  END;
			END;
		END;

	END Range;

	PROCEDURE Factor( bps: ssBP );
	BEGIN
		IF (sym < lparen) & (sym # upto) THEN
			err( 13 );
			REPEAT IO.Get( sym ) UNTIL sym >= lparen
		END;
		IF (sym = ident) OR (sym = passivate) THEN
			qualident();  selector( bps );
			IF sym = lparen THEN IO.Get( sym );  ActualParameters( bps )  END
		ELSIF sym = number THEN IO.Get( sym )
		ELSIF sym = string THEN IO.Get( sym )
		ELSIF sym = nil THEN IO.Get( sym )
		ELSIF sym = true THEN IO.Get( sym )
		ELSIF sym = false THEN IO.Get( sym )
		ELSIF sym = lparen THEN IO.Get( sym );  INC( exprdepth );  markIndent;  Range( bps );  DecExprdepth( bps );  CheckSym( rparen );  checkLine( bps );
		ELSIF sym = upto THEN IO.prepSP;  IO.appSP;  Range( bps );
		ELSIF sym = lbrak THEN ConstArray( bps );
		ELSIF sym = lbrace THEN IO.Get( sym );  Sets()
		ELSIF sym = not THEN IO.Get( sym );  Factor( bps );
		ELSE err( 13 );  IO.Get( sym );
		END;

		(** fof >> *)
		(* suffix *)
		IF sym = transpose THEN IO.Get( sym )  END;
		(** << fof  *)

	END Factor;

	PROCEDURE Term( bps: ssBP );
	BEGIN
		Factor( bps );
		WHILE (times <= sym) & (sym <= and) OR (sym >= backslash) & (sym <= egeq) DO
			IO.prepSP;  IO.appSP;  IO.Get( sym );  checkLine( bps );  getBP( bps, mulop );  Factor( bps );
		END
	END Term;

	PROCEDURE SimpleExpression( bps: ssBP );
	BEGIN
		IF sym = minus THEN IO.Get( sym );
		ELSIF sym = plus THEN IO.Get( sym );
		END;
		Term( bps );
		WHILE (plus <= sym) & (sym <= or) DO IO.prepSP;  IO.appSP;  IO.Get( sym );  checkLine( bps );  getBP( bps, addop );  Term( bps ) END
	END SimpleExpression;

	PROCEDURE Expression( bps: ssBP );
	BEGIN
		SimpleExpression( bps );
		IF (eql <= sym) & (sym <= geq) THEN IO.Get( sym );  checkLine( bps );  getBP( bps, relop );  SimpleExpression( bps );
		ELSIF sym = in THEN IO.Get( sym );  SimpleExpression( NIL );
		ELSIF sym = is THEN
			IO.Get( sym );
			IF sym = ident THEN qualident()  ELSE err( ident ) END
		END
	END Expression;

	PROCEDURE Receiver;
	BEGIN
		IF sym = var THEN IO.Get( sym ) END;
		CheckSym( ident );  CheckSym( colon );
		IF sym = ident THEN IO.Get( sym )  ELSE err( ident ) END;
		CheckSym( rparen );
	END Receiver;

	PROCEDURE ProcedureDeclaration;
	VAR forward, cproc: BOOLEAN;

		PROCEDURE GetParams;
		BEGIN
			IF sym = lparen THEN IO.Get( sym );  FormalParameters() END;
		END GetParams;

		PROCEDURE Body;
		VAR c: SIGNED32;
		BEGIN
			CheckSym( semicolon );  Block( FALSE );
			IF (sym = ident) OR (sym = number) OR (sym = string) THEN IO.Get( sym ) ELSE err( ident ) END;
		END Body;

		PROCEDURE TProcDecl;
		BEGIN
			IO.Get( sym );
			IF level > 0 THEN err( 73 ) END;
			Receiver();
			IF sym = ident THEN
				CheckMark();  INC( level );  GetParams;
				IF ~forward THEN Body END;
				DEC( level );
			ELSE err( ident )
			END
		END TProcDecl;

	BEGIN
		forward := FALSE;  cproc := FALSE;
		IF (sym # ident) & (sym # lparen) & (sym # string) & (sym # number) THEN
			IF sym = times THEN
			ELSIF sym = arrow THEN forward := TRUE
			ELSIF sym = plus THEN
			ELSIF sym = and THEN
			ELSIF sym = minus THEN cproc := TRUE;
			ELSE err( ident )
			END;
			IO.Get( sym )
		END;
		IF sym = lparen THEN TProcDecl
		ELSIF (sym = ident) OR (sym = number) OR (sym = string) THEN
			IO.makeImportant;  CheckMark();  INC( level );  GetParams;
			IF ~forward THEN
				IF cproc & (sym = number) THEN
					WHILE sym = number DO
						IO.Get( sym );
						IF sym = comma THEN IO.Get( sym ) END
					END
				ELSE Body
				END
			END;
			DEC( level );
		ELSE err( ident )
		END
	END ProcedureDeclaration;

	PROCEDURE CaseLabelList;
	BEGIN
		LOOP
			ConstExpression();
			IF sym = upto THEN IO.Get( sym );  ConstExpression()  END;
			IF sym = comma THEN IO.Get( sym )
			ELSIF (sym = number) OR (sym = ident) THEN err( comma )
			ELSE EXIT
			END
		END
	END CaseLabelList;

	PROCEDURE StatSeq( bp: BreakPoint;  adj: BOOLEAN );
	VAR cst: BOOLEAN;  line: SIGNED16;  bp1: BreakPoint;  prevbps: ssBP;  withpos: SIGNED32;

		PROCEDURE CasePart;
		VAR n: SIGNED16;  low, high: SIGNED32;  e: BOOLEAN;  bp: BreakPoint;
		BEGIN
			Expression( NIL );  CheckSym( of );  IO.prepNL;
			LOOP
				IF sym < bar THEN CaseLabelList();  CheckSym( colon );  IO.incInd;  StatSeq( nobp, TRUE );  IO.decInd  END;
				IF sym = bar THEN IO.prepNL;  IO.Get( sym ) ELSE EXIT END
			END;
			IF sym = else THEN IO.prepNL;  IO.Get( sym );  IO.getBPind( bp1 );  StatSeq( nobp, FALSE )  END;
		END CasePart;

		PROCEDURE ExpressionAndSym( sym: SIGNED8 );
		VAR line: SIGNED16;
		BEGIN
			line := IO.curLine;  exprdepth := 1;  markIndent;  Expression( IO.curbp );  checkLine( IO.curbp );  clearBPS( IO.curbp, 2 );
			IF sym # null THEN CheckSym( sym ) END;
			IO.forceNL := IO.curLine # line;  exprdepth := 0
		END ExpressionAndSym;

	BEGIN
		IO.incInd;  prevbps := IO.curbp;  IO.NewBPS( IO.curbp );  IO.curbp.fbp := bp;
		IF IO.forceNL THEN doForcedNL
		ELSIF adj THEN IO.adjust
		ELSE IO.getBP( IO.curbp.bbp );
		END;
		LOOP
			doForcedNL;  cst := FALSE;  clearBPS( IO.curbp, 2 );
			IF sym < ident THEN
				err( 14 );
				REPEAT IO.Get( sym ) UNTIL sym >= ident
			END;
			sline := IO.curLine;
			IF IO.emptyLine THEN INC( sline, 2 ) END;
			withpos := IO.Pos();
			IF sym = ident THEN
				qualident();  selector( IO.curbp );  clearBPS( IO.curbp, 2 );
				IF sym = becomes THEN IO.Get( sym );  getBP( IO.curbp, 1 );  ExpressionAndSym( null );
				ELSIF sym = eql THEN err( becomes );  IO.Get( sym );  getBP( IO.curbp, 1 );  ExpressionAndSym( null );
				ELSIF sym = lparen THEN IO.Get( sym );  ActualParameters( IO.curbp )
				END;
			ELSIF sym = exit THEN IO.Get( sym );
			ELSIF sym = return THEN
				IO.Get( sym );
				IF sym < semicolon THEN ExpressionAndSym( null ) END;

			ELSIF (sym >= if) & (sym <= with) THEN
				cst := TRUE;  IO.breakLine( IO.curbp.bbp );  IO.breakLine( bp );  IO.prepNL;  bp1 := NIL;  clearBPS( IO.curbp, 0 );
				IF sym = if THEN
					line := IO.curLine;  IO.Get( sym );  ExpressionAndSym( then );
					IF forceNL THEN IO.prepNL  END;
					StatSeq( nobp, FALSE );
					WHILE sym = elsif DO
						IO.prepNL;  IO.Get( sym );  ExpressionAndSym( then );
						IF forceNL THEN IO.prepNL  END;
						StatSeq( nobp, FALSE );
					END;
					IF sym = else THEN
						IF (IO.curLine = line) THEN IO.getBP( bp1 ) ELSE IO.prepNL;  bp1 := NIL END;
						IO.Get( sym );
						IF forceNL THEN IO.prepNL  END;
						StatSeq( bp1, FALSE );
					END;
					IF IO.curLine = line THEN IO.getBP( bp1 ) ELSE IO.prepNL;  bp1 := NIL END;
					CheckSym( end );
					IF IO.curLine # line THEN IO.breakLine( bp1 ) END
				ELSIF sym = case THEN IO.Get( sym );  CasePart();  IO.prepNL;  CheckSym( end )
				ELSIF sym = while THEN
					line := IO.curLine;  IO.Get( sym );  ExpressionAndSym( do );
					IF forceNL THEN IO.prepNL END;
					StatSeq( nobp, FALSE );
					IF IO.curLine # line THEN IO.prepNL END;
					CheckSym( end )
				ELSIF sym = repeat THEN
					line := IO.curLine;  IO.Get( sym );
					IF forceNL THEN IO.prepNL END;
					StatSeq( nobp, FALSE );
					IF sym = until THEN
						IF line # IO.curLine THEN IO.prepNL;  bp1 := NIL ELSE IO.getBP( IO.curbp.bbp ) END;
						IO.Get( sym );  ExpressionAndSym( null );
					END;
				ELSIF sym = for THEN
					IO.Get( sym );
					IF sym = ident THEN
						qualident();  CheckSym( becomes );  Expression( IO.curbp );  CheckSym( to );  getBP( IO.curbp, 2 );  Expression( IO.curbp );
						IF sym = by THEN IO.Get( sym );  ConstExpression() END;
						CheckSym( do );  line := IO.curLine;  IO.getBPind( bp1 );
						IF forceNL THEN IO.prepNL END;
						StatSeq( nobp, FALSE );
						IF IO.curLine # line THEN IO.prepNL END;
						CheckSym( end );
					ELSE err( ident )
					END
				ELSIF sym = loop THEN
					IO.Get( sym );  IO.prepNL;
					IF forceNL THEN IO.prepNL END;
					StatSeq( nobp, FALSE );  IO.prepNL;  CheckSym( end )
				ELSIF sym = with THEN
					IO.Get( sym );
					LOOP
						IF sym = ident THEN
							qualident();  CheckSym( colon );
							IF sym = ident THEN qualident()  ELSE err( ident ) END
						ELSE err( ident )
						END;
						CheckSym( do );  IO.getBPind( bp1 );  StatSeq( nobp, FALSE );
						IF sym = bar THEN
							IF withpos > 0 THEN Out.String( "OldStyleWith " );  Out.Int( withpos, 1 );  Out.Ln;  withpos := -1  END;
							Out.String( "OldStyleWithCase " );  Out.Int( IO.Pos(), 1 );  Out.Ln;  IO.prepNL;  IO.Get( sym )
						ELSE EXIT
						END
					END;
					IF sym = else THEN
						IF withpos > 0 THEN Out.String( "OldStyleWith " );  Out.Int( withpos, 1 );  Out.Ln  END;
						Out.String( "OldStyleWithElse " );  Out.Int( IO.Pos(), 1 );  Out.Ln;  withpos := 0;  IO.prepNL;  IO.Get( sym );  StatSeq( nobp, FALSE )
					END;
					IO.prepNL;
					IF withpos < 0 THEN Out.String( "OldStyleWithEnd " );  Out.Int( IO.Pos(), 1 );  Out.Ln  END;
					CheckSym( end );
				END;
			ELSIF sym = begin THEN
				IO.prepNL;  IO.Get( sym );  CheckSysFlag();  IO.prepNL;  StatSeq( nobp, FALSE );
				IF IO.curLine # line THEN IO.prepNL END;
				CheckSym( end );
				(*IF sym = end THEN IO.Get( sym )  END;  *)
				(*
				ELSIF (sym = assert) OR (sym = halt) THEN
				IO.prepNL;  IO.Get( sym );
				IF sym = lparen THEN IO.Get( sym );  ActualParameters( IO.curbp ) END;
				cst := TRUE;
			*)
			END;
			exprdepth := 0;
			IF sym = semicolon THEN
				IO.Get( sym );
				IF cst & ((sym = ident) OR (sym = exit) OR (sym = return)) THEN IO.prepNL ELSE checkLine( IO.curbp ) END;
				IF (sym = end) OR (sym = elsif) OR (sym = else) OR (sym = until) THEN EXIT END;
			ELSIF (sym <= ident) OR (if <= sym) & (sym <= return) THEN err( semicolon )
			ELSE checkLine( IO.curbp );  EXIT
			END;
			IF cst THEN clearBPS( IO.curbp, 0 );  IO.curbp.bbp := NIL ELSE IO.forceNL := IO.curLine > sline  END;
			getBP( IO.curbp, 0 );
		END;   (* loop *)
		IO.putComment;  IO.decInd;  IO.curbp := prevbps
	END StatSeq;

	PROCEDURE Code;
	VAR il: SIGNED32;  n: SIGNED16;  skippedspaces: BOOLEAN;  curline: SIGNED16;
	BEGIN
		skippedspaces := FALSE;
		IF sym = lbrace THEN
			REPEAT IO.Get( sym ) UNTIL sym = rbrace;
			IO.Get( sym );
		END;
		IO.AssemblerCommentOff;  IO.EnterCode;  IO.incInd;

		IO.prepNL;  il := IO.inpLine;  n := 1;  curline := 0;
		REPEAT
			IO.Get( sym );

			IF curline # IO.curLine THEN curline := IO.curLine;  n := 1;
			END;
			IO.skipSpaces();  INC( n );

			IF (n = 2) & (sym # colon) THEN IO.prepTAB
			END;
			IF IO.forceNL THEN IO.AssemblerCommentOff  END;
			doForcedNL;

			IF IO.inpLine > il THEN
				IO.forceNL := TRUE;  il := IO.inpLine;  n := 0;  skippedspaces := TRUE;
				(*ELSE
				IO.skipSpaces();
				IF IO.inpLine >il THEN IO.forceNL := TRUE;  il := IO.inpLine;  n := 0;  skippedspaces := TRUE;
				END;
				*)
			END;

			IF sym = semicolon THEN IO.prepTAB;  IO.AssemblerComment  END;

		UNTIL sym = end;
		IO.AssemblerCommentOff;  IO.decInd;  IO.LeaveCode;
	END Code;

	PROCEDURE Block( objScope: BOOLEAN );
	VAR bp: BreakPoint;
	BEGIN
		bp := NIL;
		LOOP
			IF sym = const THEN
				IO.prepNL;  IO.Get( sym );  IO.incInd;
				IF level = 0 THEN IO.prepNL END;
				WHILE sym = ident DO
					CheckMark();
					IF sym = eql THEN IO.Get( sym );  ConstExpression()
					ELSIF sym = becomes THEN err( eql );  IO.Get( sym );  ConstExpression()
					ELSE err( eql );
					END;
					CheckSym( semicolon );
					IF IO.width > IO.MaxLineLength THEN IO.breakLine( bp ) END;
					doForcedNL;  IO.getBP( bp )
				END;
				IO.decInd;  bp := NIL;
			END;
			IF sym = type THEN
				IO.prepNL;  IO.Get( sym );  IO.incInd;
				IF level = 0 THEN IO.prepNL END;
				WHILE sym = ident DO
					IO.makeImportant;  CheckMark();
					IF sym = eql THEN IO.Get( sym );  TypeDecl( bp );
					ELSIF (sym = becomes) OR (sym = colon) THEN err( eql );  IO.Get( sym );  TypeDecl( bp )
					ELSE err( eql )
					END;
					CheckSym( semicolon );
					IF IO.width > IO.MaxLineLength THEN IO.breakLine( bp ) END;
					doForcedNL;  IO.getBP( bp )
				END;
				IO.decInd;  bp := NIL;
			END;
			IF sym = definition THEN IO.Get( sym );  Definition( bp );  CheckSym( semicolon );  IO.forceNL := TRUE END;
			IF (sym = var) OR (objScope & (sym = ident)) THEN
				IO.prepNL;
				IF sym = var THEN IO.Get( sym ) END;
				IO.incInd;
				IF level = 0 THEN IO.prepNL END;
				WHILE sym = ident DO
					LOOP
						IF sym = ident THEN CheckMark();  CheckSysFlag() END;
						IF sym = comma THEN IO.Get( sym )
						ELSIF sym = ident THEN err( comma )
						ELSE EXIT
						END
					END;
					CheckSym( colon );  TypeDecl( bp );
					IF sym = semicolon THEN
						IO.Get( sym );
						IF objScope THEN IO.forceNL := TRUE END
					END;
					IF IO.width > IO.MaxLineLength THEN IO.breakLine( bp ) END;
					doForcedNL;  IO.getBP( bp )
				END;
				IO.decInd;  bp := NIL;
			END;
			IF sym = procedure THEN
				IO.incInd;  IO.putEmptyLines( 1 );  IO.Get( sym );  CheckSysFlag();  ProcedureDeclaration();  CheckSym( semicolon );  IO.decInd;  IO.putEmptyLines( 1 );
			END;
			IF (sym < const) OR (sym > procedure) & (sym # definition) THEN EXIT END;
		END;
		IF sym = begin THEN
			IO.prepNL;  IO.Get( sym );
			IF sym = lbrace THEN
				REPEAT IO.Get( sym ) UNTIL sym = rbrace;
				IO.Get( sym );
			END;
			IO.forceNL := TRUE;  bp := NIL;  StatSeq( nobp, FALSE )
		ELSIF sym = code THEN IO.prepNL;  IO.Get( sym );  IO.forceNL := TRUE;  Code()
		ELSE IO.prepNL
		END;
		IO.prepNL;  CheckSym( end );
	END Block;

	PROCEDURE DefinitionBlock( objScope: BOOLEAN );
	VAR bp: BreakPoint;
	BEGIN
		IO.incInd;  bp := NIL;
		LOOP
			IF sym = procedure THEN
				IO.Get( sym );
				IF sym # ident THEN err( ident );  EXIT ELSE IO.Get( sym ) END;
				CheckSysFlag();
				IF sym = lparen THEN IO.Get( sym );  FormalParameters();  IO.forceNL := TRUE  END;
			ELSIF sym = semicolon THEN IO.Get( sym )
			ELSIF sym = end THEN EXIT;
			ELSE EXIT
			END;
		END;
		IO.decInd;  IO.prepNL;  CheckSym( end );  IO.Get( sym );
	END DefinitionBlock;

	PROCEDURE Context;
	BEGIN
		IF sym = in THEN
			IO.Get( sym );
			IF sym = ident THEN IO.Get( sym ) ELSE err( 16 ) END
		END
	END Context;

	PROCEDURE Module;
	VAR bp: BreakPoint;
	BEGIN
		noerr := TRUE;  level := 0;  exprdepth := 0;  bp := NIL;  inFormPar := FALSE;  IO.Get( sym );
		IF sym = module THEN IO.Get( sym )  ELSE err( 16 ) END;
		IF sym = ident THEN
			IO.Get( sym );  Context;  CheckSym( semicolon );
			IF sym = import THEN
				IO.putEmptyLines( 1 );  IO.Get( sym );  IO.incInd;
				LOOP
					IF sym = ident THEN
						IO.Get( sym );  Context;
						IF sym = becomes THEN
							IO.Get( sym );
							IF sym = ident THEN IO.Get( sym );  Context ELSE err( ident ) END
						END;
					ELSE err( ident )
					END;
					IF sym = comma THEN IO.appSP;  IO.Get( sym );
					ELSIF sym = ident THEN err( comma );
					ELSE EXIT
					END;
					IF IO.width > IO.MaxLineLength THEN IO.breakLine( bp ) END;
					IO.getBP( bp )
				END;
				CheckSym( semicolon );  IO.decInd;  IO.putEmptyLines( 1 );
			END;
			IF noerr THEN
				Block( FALSE );
				IF sym = ident THEN IO.Get( sym ) ELSE err( ident ) END;
				IF sym # period THEN err( period ) END;
			END
		ELSE err( ident )
		END;
		IO.noerr := noerr;  IO.Terminate;
	END Module;

	PROCEDURE TempHandle( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	BEGIN
		IF msg IS Display.DisplayMsg THEN found := TRUE END
	END TempHandle;

	PROCEDURE CheckOnDisplay( t: Task ): BOOLEAN;
	VAR msg: Display.DisplayMsg;  f: Display.Frame;  orighandle: Objects.Handler;
	BEGIN
		f := t.frame;
		IF f = NIL THEN RETURN TRUE END;
		orighandle := f.handle;  f.handle := TempHandle;  found := FALSE;  msg.F := f;  msg.device := Display.screen;  msg.id := Display.full;  msg.res := -1;
		Display.Broadcast( msg );  f.handle := orighandle;
		IF found THEN RETURN TRUE ELSE RETURN FALSE END
	END CheckOnDisplay;

	(*
	PROCEDURE FormatBG( t: Oberon.Task );
	VAR caret: Oberon.CaretMsg;  find: Display.LocateMsg;
	BEGIN
		WITH t: Task DO
			find.loc := t.frame;  find.X := MIN( SIGNED16 );  Display.Broadcast( find );
			IF ~CheckOnDisplay( t ) THEN Out.String( "OFormatter: Text lost" );  Out.Ln;  Oberon.Remove( t )
			ELSE
				caret.id := Oberon.get;  Display.Broadcast( caret );
				IF (caret.text = t.text) THEN
					t.changed := TRUE;
					IF Oberon.Time() - t.lastchanged > 10000 THEN
						silent := TRUE;  forceNL := TRUE;  IO.InitText( t.text, 0X, TRUE );  Module;  t.changed := FALSE;
						caret.id := Oberon.set;  Display.Broadcast( caret );  t.lastchanged := Oberon.Time();
					END;
				ELSIF t.changed THEN
					silent := TRUE;  IO.InitText( t.text, 0X, TRUE );  Module;  t.changed := FALSE;  t.lastchanged := Oberon.Time();
				END;
			END;
		END;
		t.time := Oberon.Time() + 500;
	END FormatBG;

	PROCEDURE InvokeBGFormat*;
	VAR t: Task;  T: Texts.Text;  f: Display.Frame;
	BEGIN
		T := Oberon.MarkedText();
		IF T # NIL THEN
			f := Oberon.MarkedFrame();
			IF f # NIL THEN NEW( t );  t.frame := f;  t.text := T;  t.handle := FormatBG;  Oberon.Install( t );  Out.String( "OFormatter invoked, bg executing for selected text" );  Out.Ln  END;
		END;
		t.time := Oberon.Time() + 10000;
	END InvokeBGFormat;
	*)

	PROCEDURE GetOptions( VAR Sc: Texts.Scanner;  VAR print, large, color, lowercase, uppercase: BOOLEAN );
	VAR i: SIGNED32;
	BEGIN
		WHILE (Sc.class = Texts.Char) & (Sc.c = "\") DO
			Texts.Scan( Sc );
			IF Sc.class = Texts.Char THEN Sc.s[0] := Sc.c;  Sc.s[1] := 0X;  Sc.class := Texts.Name  END;
			IF Sc.class = Texts.Name THEN
				i := 0;
				WHILE Sc.s[i] # 0X DO
					IF Sc.s[i] = 'p' THEN print := TRUE;
					ELSIF Sc.s[i] = 'l' THEN large := TRUE;
					ELSIF Sc.s[i] = "c" THEN color := FALSE
					ELSIF Sc.s[i] = "n" THEN forceNL := TRUE;
					ELSIF Sc.s[i] = "L" THEN lowercase := TRUE;
					ELSIF Sc.s[i] = "U" THEN uppercase := TRUE;
					END;
					INC( i )
				END
			END;
			Texts.Scan( Sc );
		END;

	END GetOptions;

	PROCEDURE Format*;
	VAR par: Oberon.ParList;  T: Texts.Text;  F: Files.File;  Sc: Texts.Scanner;  R: Texts.Reader;  res: SIGNED16;  beg, end, time: SIGNED32;
		name: ARRAY 256 OF CHAR;
		print: BOOLEAN;  ch: CHAR;  i: SIGNED16;  caret: Oberon.CaretMsg;  color: BOOLEAN;  large: BOOLEAN;  prefix: CHAR;  uppercase, lowercase: BOOLEAN;
	BEGIN
		notrap := FALSE;  silent := FALSE;  print := FALSE;  color := TRUE;  forceNL := FALSE;  uppercase := FALSE;  lowercase := FALSE;
		Texts.OpenScanner( Sc, Oberon.Par.text, Oberon.Par.pos );  Texts.Scan( Sc );  GetOptions( Sc, print, large, color, lowercase, uppercase );
		IF large THEN prefix := "l"
		ELSIF print OR lowercase THEN prefix := "l"
		ELSE prefix := 0X
		END;
		IF (Sc.class = Texts.Char) & (Sc.c = "^") OR (Sc.line # 0) THEN
			Oberon.GetSelection( T, beg, end, time );
			IF time >= 0 THEN Texts.OpenScanner( Sc, T, beg );  Texts.Scan( Sc ) END
		END;
		IF (Sc.class = Texts.Name) OR (Sc.class = Texts.String) THEN
			COPY( Sc.s, name );  Out.Ln;  Out.String( "Formating " );  Out.String( name );  Texts.Scan( Sc );  GetOptions( Sc, print, large, color, lowercase, uppercase );
			prefix := 0X;
			IF print OR lowercase THEN Out.String( " for printing" );  prefix := "l"  END;
			IF large THEN prefix := "l" END;
			Out.Ln;  F := Files.Old( name );
			IF F = NIL THEN Out.String( "  ---failed, (file not found)" );  Out.Ln ELSE Files.Close( F );  IO.Init( name, prefix, color, lowercase, uppercase );  Module END;
		ELSIF (Sc.class = Texts.Char) & (Sc.c = "*") THEN
			T := Oberon.MarkedText();
			IF T # NIL THEN IO.InitText( T, prefix, color, lowercase, uppercase );  Module  ELSE Out.String( "no marked text" );  Out.Ln  END;
		ELSIF (Sc.class = Texts.Char) & (Sc.c = "#") THEN
			notrap := TRUE;  caret.id := Oberon.get;  Display.Broadcast( caret );  T := caret.text;
			IF T # NIL THEN IO.InitText( T, prefix, color, lowercase, uppercase );  Module;  caret.id := Oberon.set;  Display.Broadcast( caret )  ELSE Out.String( "no caret text" );  Out.Ln  END
		END
	END Format;

	PROCEDURE IncSize*;
	VAR T: Texts.Text;  caret: Oberon.CaretMsg;
	BEGIN
		caret.id := Oberon.get;  Display.Broadcast( caret );  T := caret.text;
		IF T # NIL THEN EditTools.IncFontSize( T, 0, T.len, 2 );  caret.id := Oberon.set;  Display.Broadcast( caret )  END;
	END IncSize;

	PROCEDURE DecSize*;
	VAR T: Texts.Text;  caret: Oberon.CaretMsg;
	BEGIN
		caret.id := Oberon.get;  Display.Broadcast( caret );  T := caret.text;
		IF T # NIL THEN EditTools.IncFontSize( T, 0, T.len, -2 );  caret.id := Oberon.set;  Display.Broadcast( caret )  END;
	END DecSize;

(* OFormatter.DecSize OFormatter.IncSize*)

	PROCEDURE RemoveOldStyleWith*;
	CONST with = 1;  case = 2;  else = 3;  end = 4;
	TYPE Job = OBJECT
		VAR pos: SIGNED32;
			c: SIGNED32;
			next: Job;
		END Job;
	VAR pos: SIGNED32;  c: SIGNED32;  S: Texts.Scanner;  S1: Texts.Scanner;  T: Texts.Text;  NT: Texts.Text;
		name: ARRAY 256 OF CHAR;
		root, job: Job;  W: Texts.Writer;  ooffset, offset: SIGNED32;

		PROCEDURE StripColon( VAR n1, n2: ARRAY OF CHAR );
		VAR i: SIGNED32;
		BEGIN
			i := 0;
			WHILE (n1[i] # 0X) & (n1[i] # ":") DO n2[i] := n1[i];  INC( i )  END;
			ASSERT( n1[i] = ":" );  n2[i] := 0X;
		END StripColon;

		PROCEDURE InsertJob( pos: SIGNED32;  c: SIGNED32 );
		VAR t, job: Job;
		BEGIN
			NEW( t );  t.pos := pos;  t.c := c;  job := root;
			WHILE (job.next # NIL ) & (job.next.pos < pos) DO job := job.next  END;
			t.next := job.next;  job.next := t;
		END InsertJob;

	BEGIN
		NEW( root );  T := Oberon.MarkedText();
		IF T = NIL THEN RETURN END;
		Texts.OpenWriter( W );  Format;  Out.String( "~~" );  pos := Oberon.Log.len;  Out.String( "FoundOldStyleWiths" );  Out.Ln;  Format;  Out.String( "~" );  Out.Ln;
		Texts.OpenScanner( S, Oberon.Log, pos );  Texts.Scan( S );  offset := 0;  ASSERT( S.s = "FoundOldStyleWiths" );  Texts.Scan( S );
		WHILE (S.class = Texts.Name) DO
			IF S.s = "OldStyleWith" THEN c := with
			ELSIF S.s = "OldStyleWithCase" THEN c := case
			ELSIF S.s = "OldStyleWithElse" THEN c := else
			ELSIF S.s = "OldStyleWithEnd" THEN c := end
			ELSE HALT( 100 );
			END;
			Texts.Scan( S );  ASSERT( S.class = Texts.Int );  InsertJob( S.i, c );  Texts.Scan( S );
		END;
		job := root.next;
		WHILE (job # NIL ) DO
			c := job.c;  pos := job.pos;  Out.Int( c, 5 );  Out.Int( pos, 10 );  Out.String( " " );
			IF (c = with) OR (c = case) THEN
				Texts.OpenScanner( S1, T, pos + offset );  Texts.Scan( S1 );  ASSERT( S1.class = Texts.Name );  StripColon( S1.s, name );  Out.String( name );
				Out.String( " " );  Texts.Scan( S1 );  ASSERT( S1.class = Texts.Name );  Out.String( S1.s );
			END;
			ooffset := offset;
			CASE c OF
			with:
					Texts.WriteString( W, "IF " );  Texts.WriteString( W, name );  Texts.WriteString( W, " IS " );  Texts.WriteString( W, S1.s );  Texts.WriteString( W, " THEN " );
					INC( offset, W.buf.len );  Texts.Insert( T, pos + ooffset - 6, W.buf );
			| case:
					Texts.WriteString( W, "END; ELSIF " );  Texts.WriteString( W, name );  Texts.WriteString( W, " IS " );  Texts.WriteString( W, S1.s );  Texts.WriteString( W, " THEN WITH " );
					INC( offset, W.buf.len - 3 );  Texts.Delete( T, pos + ooffset - 3, pos + ooffset );  Texts.Insert( T, pos + ooffset - 3, W.buf );
			| else:
					Texts.WriteString( W, "END; " );  INC( offset, W.buf.len );  Texts.Insert( T, pos + ooffset - 6, W.buf );
			| end:
					Texts.WriteString( W, "END; " );  INC( offset, W.buf.len );  Texts.Insert( T, pos + ooffset - 5, W.buf );
			END;
			Out.Ln;

			job := job.next;
		END;
		Format;

	END RemoveOldStyleWith;

BEGIN
	nobp := NIL;
END OFormatter.

System.Free OFormatter OFormatterIO ~
OFormatter.RemoveOldStyleWith *  ~


IF A IS B THEN WITH A: B
END; ELSIF A IS C THEN WITH | A: C
END; ELSE
END; END;