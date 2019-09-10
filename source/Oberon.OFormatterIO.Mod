MODULE OFormatterIO IN Oberon;

(* INPUT/OUTPUT for the O2Fomatter *)
(* g.f.	17.1.99,		Scanner part taken from OPS	*)
(* g.f.	30.1.01,		adapted to NO compiler	*)

IMPORT Texts, Fonts, Objects, Display, Oberon, Strings, Out;

(*--- constants you may wish to change -----------------------*)
CONST
	(*MaxLineLength* = 1200;   (* line length (in pixel) *)*)
	Wheight = 800;   (* window height *)
	Wwidth = 650;   (* window width *)
	defaultCol = 15;


	(*--- end of constants for costomization ---------------------------*)

	(*symbols:
	    |  0          1          2          3          4
	 ---|--------------------------------------------------------
	  0 |  null       *          /          DIV        MOD
	  5 |  &          +          -          OR         =
	 10 |  #          <          <=         >          >=
	 15 |  IN         IS         ^          .          ,
	 20 |  :          ..         )          ]          }
	 25 |  OF         THEN       DO         TO         BY
	 30 |  (          [          {          ~          :=
	 35 |  number     NIL        TRUE       FALSE      string
	 40 |  ident      ;          |          END        ELSE
	 45 |  ELSIF      UNTIL      IF         CASE       WHILE
	 50 |  REPEAT     FOR        LOOP       WITH       EXIT
	 55 |  RETURN     ARRAY      OBJECT     RECORD     POINTER
	 60 |  BEGIN      CONST      TYPE       VAR        PROCEDURE
	 65 |  IMPORT     MODULE     CODE       DEFINITION IMPLEMENTS
	 70 | REFINES ASSERT SYSTEM HALT eof        **
	 *)


VAR
	T: Texts.Text;  R: Texts.Reader;   (* input text *)
	ch: CHAR;   (*current input character*)
	str: ARRAY 1024 OF CHAR;
	tokenlen: SIGNED16;  MaxLineLength*: SIGNED32;  reservedCols: SET;
	defaultFont: ARRAY 9 OF ARRAY 32 OF CHAR;
	defaultColor: ARRAY 9 OF SIGNED8;
	lcase, ucase: BOOLEAN;   (* true: recognize lowercase keywords *)
	firstId: BOOLEAN;  n1: CHAR;
CONST
	null* = 0;  times* = 1;  slash* = 2;  div* = 3;  mod* = 4;  and* = 5;  plus* = 6;  minus* = 7;  or* = 8;  eql* = 9;  neq* = 10;  lss* = 11;  leq* = 12;  gtr* = 13;  geq* = 14;  in* = 15;  is* = 16;  arrow* = 17;
	period* = 18;  comma* = 19;  colon* = 20;  upto* = 21;  rparen* = 22;  rbrak* = 23;  rbrace* = 24;  of* = 25;  then* = 26;  do* = 27;  to* = 28;  by* = 29;  lparen* = 30;  lbrak* = 31;  lbrace* = 32;
	not* = 33;  becomes* = 34;  number* = 35;  nil* = 36;  true* = 37;  false* = 38;  string* = 39;  ident* = 40;  semicolon* = 41;  bar* = 42;  end* = 43;  else* = 44;  elsif* = 45;  until* = 46;  if* = 47;
	case* = 48;  while* = 49;  repeat* = 50;  for* = 51;  loop* = 52;  with* = 53;  exit* = 54;  passivate* = 55;  return* = 56;  refines* = 57;  implements* = 58;  array* = 59;  definition* = 60;  object* = 61;
	record* = 62;  pointer* = 63;  begin* = 64;  code* = 65;  const* = 66;  type* = 67;  var* = 68;  procedure* = 69;  import* = 70;  module* = 71;  eof* = 72;  finally* = 73;
	(** fof >> *)
	backslash* = 74;  scalarproduct* = 75;  elementproduct* = 76;  elementquotient* = 77;  dtimes* = 78;  transpose* = 79;  eeql* = 80;  eneq* = 81;  elss* = 82;  eleq* = 83;  egtr* = 84;  egeq* = 85;  qmark* = 86;

	(** << fof  *)


	(** << fof  *)



	(* ----------- Synthesis part ---------------- *)

	normalN = 0;  exportN = 1;  keywordN = 2;  commentN = 3;  importantN = 4;  stringN = 5;  extraN = 6;

CONST
	Eot = 0X;  CR = 0DX;  TAB = 09X;  NL = 0AX;
TYPE
	BreakPoint* = POINTER TO RECORD
		line-: SIGNED16;
		textpos-: SIGNED32;
		width-: SIGNED16;
		indent-: SIGNED16;   (* in pixel *)
		pred: BreakPoint
	END;

	ssBP* = POINTER TO ssBPDesc;
	ssBPDesc* = RECORD
		fbp*: BreakPoint;   (* breakposition before statment sequence,  e.g. before ELSE *)
		bbp*: BreakPoint;   (* begin of statement sequence *)
		bp*: ARRAY 10 OF BreakPoint;   (* breakpoints in current statement *)
		(*
				0:	begin of curr. statement
			    1:	":="
			    2, 6:	begin of (parm | expr) (list)
			    3, 7:	rel. operateror
			    4, 8:	+, -, OR
			    5, 9:	*, /, &
			*)
	END;

VAR
	forceNL*: BOOLEAN;
	curbp*: ssBP;   (* breakpoints in current statement sequence  *)
	curLine-, width-, curInd-: SIGNED16;   (* in output file *)
	inpLine-: SIGNED32;  inCode: BOOLEAN;

	N: Texts.Text;  W: Texts.Writer;   (* output text *)
	newFile: ARRAY 256 OF CHAR;
	lastch: CHAR;   (* last outpuct char *)
	outsym: SIGNED8;   (* symbol for output *)
	kw: BOOLEAN;  nossbp: ssBP;
	tabw: SIGNED16;   (* width of indentation TAB (in pixel) *)
	spw: SIGNED16;   (* width of pace char (in pixel) *)
	indentl1, indentl2: SIGNED16;   (* marked indentation for level1 and level2 expr. *)
	il1pos, il2pos: SIGNED32;  gotEmptyLine, emptyLine*: BOOLEAN;
	emptyLines: SIGNED16;   (* no of empty lines done (output) *)
	nlines: SIGNED16;   (* CR's between last token or comment and comment  (input) *)
	needSp, instring, linestart, adjusted: BOOLEAN;  haveToken: BOOLEAN;
	com: RECORD
		preNL, postNL: SIGNED16;   (* NLs around comment *)
		lines: SIGNED16;   (* no. of lines in comment *)
		W: Texts.Writer;   (* the comment text *)
		width: SIGNED16;   (* width of comment (last comment line) *)
	END;
	pc: BOOLEAN;   (* TRUE: a comment preceeding a statement/declaration *)
	lowercase, uppercase, usecolors: BOOLEAN;   (* print keywords in lower case *)
	curFont, tokCol: SIGNED8;  lastbp: BreakPoint;
	lastNL: BreakPoint;   (* at this point occured the last NL in source file *)
	expMark: BOOLEAN;  important: BOOLEAN;  isstring: BOOLEAN;  isextra: BOOLEAN;  inBreakLine, inPutComment, inAssComment: BOOLEAN;  lastLineStart: SIGNED32;  noerr*: BOOLEAN;

	fonts: ARRAY 9 OF RECORD
		f: Fonts.Font;
		cw: ARRAY 256 OF SIGNED8;
		col: SIGNED8;
	END;

	PROCEDURE strSym( s: SIGNED8 ): BOOLEAN;
	BEGIN
		RETURN (s = number) OR (s = string) OR (s = ident)
	END strSym;

	PROCEDURE sSs( s: SIGNED8 ): BOOLEAN;
	BEGIN
		(* RETURN (s IN {and, eql..geq}) OR (s = becomes)	fails! bug in OOP2 Compiler for PowerPC! *)
		RETURN ((s < 32) & (s IN {and, eql..geq})) OR (s = becomes)
	END sSs;

	PROCEDURE Ss( s: SIGNED8 ): BOOLEAN;
	BEGIN
		RETURN (s = comma) OR (s = colon) OR (s = semicolon) OR (s = bar)
	END Ss;

	PROCEDURE AssemblerComment*;
	BEGIN
		inCode := FALSE;  setFont( 3 );
		IF usecolors THEN Texts.SetColor( W, fonts[3].col );  END;
		inAssComment := TRUE;
	END AssemblerComment;

	PROCEDURE AssemblerCommentOff*;
	BEGIN
		inAssComment := FALSE;  setFont( 7 );  inCode := TRUE;
		IF usecolors THEN Texts.SetColor( W, fonts[0].col ) END;
	END AssemblerCommentOff;

	PROCEDURE EnterCode*;
	BEGIN
		inCode := TRUE;
	END EnterCode;

	PROCEDURE LeaveCode*;
	BEGIN
		inCode := FALSE;
	END LeaveCode;

	PROCEDURE setFont( fn: SIGNED8 );
	BEGIN
		IF ~inAssComment & ~inCode THEN Texts.SetFont( W, fonts[fn].f );  curFont := fn END;
	END setFont;

	PROCEDURE put( ch: CHAR );
	VAR wi: SIGNED16;
	BEGIN
		Texts.Write( W, ch );  lastch := ch;
		IF ch = CR THEN INC( curLine );  linestart := TRUE;  width := 0;  lastLineStart := N.len + W.buf.len
		ELSIF ch = TAB THEN
			INC( width, tabw );
			IF linestart THEN INC( lastLineStart ) END;
		ELSE wi := fonts[curFont].cw[ORD( ch )];  INC( width, wi );  linestart := FALSE;  emptyLines := 0;
		END;
		adjusted := FALSE;
	END put;

	PROCEDURE checkMark*;
	BEGIN
		skipSpaces;  expMark := (ch = '*') OR (ch = '-')
	END checkMark;

	PROCEDURE makeImportant*;
	BEGIN
		important := TRUE;
	END makeImportant;

	PROCEDURE adjLine;
	VAR i: SIGNED16;
	BEGIN
		IF width > tabw * curInd THEN
			i := 0;
			WHILE width > tabw * curInd DO INC( i );  width := width - tabw END;
			IF i > 0 THEN Texts.Append( N, W.buf );  Texts.Delete( N, N.len - i, N.len ) END;
		ELSIF width < tabw * curInd THEN
			REPEAT put( TAB ) UNTIL width >= tabw * curInd;
		END;
	END adjLine;

	PROCEDURE checkLine*;
	VAR i: SIGNED16;
	BEGIN
		IF width >= MaxLineLength THEN
			breakLine( curbp.fbp );
			IF width >= MaxLineLength THEN
				breakLine( curbp.bbp );  i := 0;
				WHILE (width >= MaxLineLength) & (i < 10) DO
					IF curbp.bp[i] # NIL THEN breakLine( curbp.bp[i] );  END;
					INC( i );
				END
			END
		END;
	END checkLine;

	PROCEDURE putComment*;
	VAR i, k, tl: SIGNED16;  comAtLinestart, movelastbp: BOOLEAN;
	BEGIN
		IF (com.W.buf.len > 0) & ~inPutComment THEN
			inPutComment := TRUE;  movelastbp := FALSE;  comAtLinestart := linestart;
			IF ~inBreakLine THEN
				IF (com.preNL > 0) OR (com.lines > 1) THEN
					(* comment starts in a new line *)
					IF curbp.bbp # lastbp THEN breakLine( curbp.bbp );  breakLine( curbp.fbp ) END;
					clearBP( lastbp );
				ELSIF  (*com.lines = 1*) com.postNL > 0 THEN
					(* statements or declarations followed by a comment will remain as single lines! *)
					IF (curbp.bbp # NIL ) & ((curbp.bbp.textpos <= lastNL.textpos) OR (lastNL.textpos = 0)) THEN breakLine( curbp.bbp );  breakLine( curbp.fbp ) END;
					breakLine( lastNL );
					IF (width + com.width) > MaxLineLength THEN
						(* upLn;  *)
						IF curbp = nossbp THEN
							(* put( TAB );  put( TAB );  put( TAB );  *)
							linestart := FALSE  (* prohibit readjusting *)
						END
					END;
				ELSE  (* com.preNL = 0) & (com.lines = 1) & omm.postNL = 0) *)
					movelastbp := (lastbp # NIL ) & (lastbp.textpos >= N.len + W.buf.len);
				END;
			END;
			IF linestart THEN adjLine;  k := 2
			ELSIF com.preNL = 0 THEN put( ' ' );  k := 1
			ELSE k := 1
			END;
			setFont( 0 );
			FOR i := k TO com.preNL DO upLn END;
			Texts.Append( N, W.buf );  Texts.Append( N, com.W.buf );  curLine := curLine + com.lines - 1;
			IF com.lines = 1 THEN width := width + com.width;  ELSE width := com.width END;
			setFont( 0 );
			IF com.postNL > 0 THEN
				FOR i := 1 TO com.postNL DO upLn END;
			ELSIF com.lines > 1 THEN upLn;
			ELSE put( ' ' );
			END;
			Texts.Append( N, W.buf );  pc := (comAtLinestart OR (com.preNL > 0)) & ((com.lines = 1) & (com.postNL = 0));
			IF ~inBreakLine THEN
				tl := com.preNL + com.lines + com.postNL;
				IF tl = 1 THEN checkLine END;
				IF tl > 1 THEN clearBP( curbp.bbp );  clearBP( lastbp ) END;
				IF movelastbp & (lastbp # NIL ) THEN lastbp.textpos := N.len + W.buf.len;  lastbp.width := width;  lastbp.line := curLine ELSE clearBP( lastbp ) END
			END;
			inPutComment := FALSE
		END;
	END putComment;

	PROCEDURE putToken;
	VAR i: SIGNED16;

		PROCEDURE appSp;
		BEGIN
			IF lastNL.textpos >= N.len + W.buf.len THEN INC( lastNL.textpos ) END;
			put( ' ' );
		END appSp;

	BEGIN
		IF haveToken THEN
			haveToken := FALSE;  putComment;
			IF inAssComment & usecolors THEN Texts.SetColor( W, fonts[commentN].col )
			ELSIF (tokCol IN reservedCols) & usecolors THEN Texts.SetColor( W, defaultCol )
			ELSE Texts.SetColor( W, tokCol );
			END;

			IF emptyLine THEN putEmptyLines( 1 )
			END;
			IF linestart THEN adjLine END;
			IF lastch > ' ' THEN
				IF (kw (* & outsym # halt*) ) OR (needSp & strSym( outsym )) OR sSs( outsym ) THEN appSp END
			END;
			IF kw THEN
				setFont( 2 );
				IF inAssComment & usecolors THEN Texts.SetColor( W, fonts[commentN].col )
				ELSIF (tokCol IN reservedCols) & usecolors THEN Texts.SetColor( W, fonts[keywordN].col )
				END;
			ELSIF expMark THEN
				setFont( 1 );
				IF inAssComment & usecolors THEN Texts.SetColor( W, fonts[commentN].col )
				ELSIF (tokCol IN reservedCols) & usecolors THEN Texts.SetColor( W, fonts[exportN].col )
				END;
			ELSIF important THEN
				setFont( 4 );
				IF (tokCol IN reservedCols) & usecolors THEN Texts.SetColor( W, fonts[importantN].col ) END;
			ELSIF isextra THEN
				setFont( 6 );
				IF (tokCol IN reservedCols) & usecolors THEN Texts.SetColor( W, fonts[extraN].col ) END;
			ELSIF isstring THEN
				setFont( 5 );
				IF (tokCol IN reservedCols) & usecolors THEN Texts.SetColor( W, fonts[stringN].col ) END;
			END;
			FOR i := 0 TO tokenlen - 1 DO put( str[i] ) END;
			setFont( 0 );  expMark := FALSE;  needSp := FALSE;  important := FALSE;  isstring := FALSE;  isextra := FALSE;
			IF (kw & (ch # ';') (* & (outsym # halt)*) ) OR sSs( outsym ) THEN appSp
			ELSIF Ss( outsym ) THEN
				appSp;
				IF outsym = semicolon THEN appSp END
			ELSIF strSym( outsym ) THEN needSp := TRUE;
			END;
		END;
		tokenlen := 0;  pc := FALSE
	END putToken;

	PROCEDURE err*( n: SIGNED16 );
	BEGIN
		putToken;  Texts.Append( N, W.buf );  Out.String( "        pos " );  Out.Int( N.len + W.buf.len, 1 );  Out.Int( Texts.Pos( R ), 10 );  Out.String( " err " );  Out.Int( n, 3 );  Out.Ln;
	END err;

	PROCEDURE appSP*;
	BEGIN
		putToken;
		IF lastch > ' ' THEN put( ' ' ) END
	END appSP;

	PROCEDURE prepSP*;
	BEGIN
		putComment;
		IF lastch > ' ' THEN put( ' ' ) END;
	END prepSP;

	PROCEDURE prepTAB*;
	BEGIN
		putComment;
		IF lastch > ' ' THEN put( TAB ) END;
	END prepTAB;

	PROCEDURE upLn;
	VAR i: SIGNED16;
	BEGIN
		IF linestart THEN INC( emptyLines ) END;
		put( CR );
		FOR i := 1 TO curInd DO put( TAB ) END;
		lastNL.textpos := 0;   (* clear *)
		linestart := TRUE;  forceNL := FALSE
	END upLn;

	PROCEDURE prepNL*;
	BEGIN
		putComment;
		IF ~pc THEN
			IF ~linestart THEN
				IF ~adjusted THEN upLn END
			ELSE adjLine;
			END;
		END
	END prepNL;

	PROCEDURE adjust*;
	BEGIN
		IF width > tabw * curInd THEN prepNL ELSE
			WHILE width < tabw * curInd DO put( ' ' ) END;
		END;
		adjusted := TRUE;
	END adjust;

	PROCEDURE getNLbp;
	BEGIN
		IF ~linestart & (com.W.buf.len = 0) THEN lastNL.textpos := N.len + W.buf.len + tokenlen;  lastNL.width := width;  lastNL.indent := curInd * tabw;  lastNL.line := curLine;  END;
	END getNLbp;

	PROCEDURE NewBPS*( VAR bps: ssBP );
	VAR i: SIGNED16;
	BEGIN
		NEW( bps );  bps.fbp := NIL;  bps.bbp := NIL;
		FOR i := 0 TO 9 DO bps.bp[i] := NIL END;
	END NewBPS;

	PROCEDURE getBP*( VAR bp: BreakPoint );
	BEGIN
		putComment;
		IF linestart THEN bp := NIL
		ELSE
			NEW( bp );  bp.textpos := N.len + W.buf.len;  bp.width := width;  bp.indent := curInd * tabw;  bp.line := curLine;  bp.pred := lastbp;  lastbp := bp;
			IF lastch > ' ' THEN INC( bp.textpos ) END;
		END;
	END getBP;

	PROCEDURE getBPind*( VAR bp: BreakPoint );
	BEGIN
		getBP( bp );
		IF bp # NIL THEN INC( bp.indent, tabw ) END
	END getBPind;

	PROCEDURE getBPind2*( VAR bp: BreakPoint;  exprdepth: SIGNED16 );
	BEGIN
		IF exprdepth IN {1, 2} THEN
			getBP( bp );
			IF bp # NIL THEN
				IF exprdepth = 1 THEN bp.indent := indentl1 ELSE bp.indent := indentl2 END;
			END
		ELSE bp := NIL
		END
	END getBPind2;

	PROCEDURE markIndent*( exprdepth: SIGNED16 );
	BEGIN
		IF exprdepth = 1 THEN indentl1 := width;  il1pos := N.len + W.buf.len;  ELSE indentl2 := width;  il2pos := N.len + W.buf.len;  END;
	END markIndent;

	PROCEDURE fixBPs( bp: BreakPoint;  pdiff, wdiff: SIGNED16 );
	VAR this: BreakPoint;  i: SIGNED16;
	BEGIN
		IF curbp = nossbp THEN
			(* in declaration part *)
			IF lastNL.textpos > bp.textpos THEN lastNL.textpos := lastNL.textpos + pdiff;  INC( lastNL.line );  END;
			this := lastbp;
			WHILE (this # NIL ) & (this # bp) DO
				IF this.textpos > 0 THEN this.textpos := this.textpos + pdiff;  this.indent := bp.indent;  this.width := this.width - wdiff;  INC( this.line );  END;
				this := this.pred
			END;
		ELSE
			(* in statements *)
			IF lastNL.textpos > bp.textpos THEN lastNL.textpos := lastNL.textpos + pdiff;  INC( lastNL.line );  END;
			this := curbp.bbp;
			IF (this # NIL ) & (this.textpos > bp.textpos) THEN this.textpos := this.textpos + pdiff;  this.width := this.width - wdiff;  INC( this.line ) END;
			FOR i := 0 TO 9 DO
				this := curbp.bp[i];
				IF (this # NIL ) & (this.textpos > bp.textpos) THEN
					IF i > 1 THEN DEC( this.indent, wdiff ) END;
					DEC( this.width, wdiff );  this.textpos := this.textpos + pdiff;  INC( this.line )
				END
			END;
		END
	END fixBPs;

	PROCEDURE breakLine*( VAR bp: BreakPoint );
	VAR i, j, nbc, r, wdiff: SIGNED16;  nl: Texts.Writer;  del: SIGNED16;  p: SIGNED32;
	BEGIN
		IF (bp # NIL ) & (bp.textpos > lastLineStart) THEN
			inBreakLine := TRUE;  p := bp.textpos;
			IF p >= N.len + W.buf.len THEN prepNL;  ELSE
				IF lastNL.textpos <= p THEN lastNL.textpos := 0 END;
				Texts.Append( N, W.buf );  Texts.OpenWriter( nl );  Texts.SetFont( nl, fonts[0].f );  Texts.WriteLn( nl );  j := 0;  nbc := 1;
				FOR i := 1 TO bp.indent DIV tabw DO Texts.Write( nl, TAB );  INC( j, tabw );  INC( nbc );  END;
				WHILE j < bp.indent DO Texts.Write( nl, ' ' );  INC( j, spw );  INC( nbc );  END;
				Texts.Insert( N, p, nl.buf );
				IF p >= lastNL.textpos THEN lastNL.textpos := 0 END;
				IF bp.line = curLine THEN
					r := width - bp.width;  wdiff := width - (bp.indent + r);  width := width - wdiff;
					IF il1pos > p THEN il1pos := il1pos + nbc;  DEC( indentl1, wdiff ) END;
					IF il2pos > p THEN il2pos := il2pos + nbc;  DEC( indentl2, wdiff ) END;
				ELSE wdiff := 0
				END;
				fixBPs( bp, nbc, wdiff );  INC( curLine );
			END;
			bp.textpos := 0;  inBreakLine := FALSE;
		END
	END breakLine;

	PROCEDURE clearBP*( VAR bp: BreakPoint );
	BEGIN
		IF bp # NIL THEN bp.textpos := 0 END
	END clearBP;

	PROCEDURE putEmptyLines*( n: SIGNED16 );
	VAR i: SIGNED16;
	BEGIN
		putComment;
		IF ~linestart THEN put( CR );  emptyLines := 0 END;
		IF emptyLines < n THEN
			FOR i := emptyLines + 1 TO n DO put( CR ) END;
			FOR i := 1 TO curInd DO put( TAB ) END;
			emptyLines := n;
		END;
		curbp.fbp := NIL;  curbp.bbp := NIL;  curbp.bp[0] := NIL
	END putEmptyLines;

	PROCEDURE aLn*;
	VAR i: SIGNED16;
	BEGIN
		putToken;
		IF ~linestart THEN
			put( CR );
			FOR i := 1 TO curInd DO put( TAB ) END;
		END
	END aLn;

	PROCEDURE decInd*;
	BEGIN
		DEC( curInd );
		IF linestart THEN adjLine END
	END decInd;

	PROCEDURE incInd*;
	BEGIN
		INC( curInd );
		IF linestart THEN put( TAB ) END;
		INC( lastNL.indent, tabw )
	END incInd;

	PROCEDURE getCharWidths;
	VAR obj: Objects.Object;  T: Texts.Text;  R: Texts.Reader;  W: Texts.Writer;  f, i: SIGNED16;  c: CHAR;  dx: SIGNED16;
	BEGIN
		FOR f := 0 TO 4 DO
			NEW( T );  Texts.Open( T, "" );  Texts.OpenWriter( W );  W.lib := fonts[f].f;  Texts.WriteString( W, " abcdefg" );  Texts.Append( T, W.buf );  Texts.OpenReader( R, T, 0 );  Texts.Read( R, c );
			FOR i := 0 TO 255 DO R.lib.GetObj( R.lib, i, obj );  dx := obj( Fonts.Char ).dx;  fonts[f].cw[i] := SHORT( dx );  END;
		END;
		tabw := fonts[0].cw[ORD( TAB )];  spw := fonts[0].cw[ORD( ' ' )]
	END getCharWidths;

	PROCEDURE Terminate*;
	VAR beg, end: SIGNED32;  F: Texts.Finder;  obj: Objects.Object;  C: Objects.CopyMsg;
	BEGIN
		putToken;  beg := Texts.Pos( R ) - 1;  end := T.len;  Texts.OpenFinder( F, T, beg );
		WHILE F.pos < end DO
			IF beg < F.pos THEN Texts.Save( T, beg, F.pos, W.buf ) END;
			beg := F.pos;  Texts.FindObj( F, obj );
			IF (obj IS Display.Frame) THEN
				C.id := Objects.shallow;  Objects.Stamp( C );
				obj.handle( obj, C );   (* copy *)
				Texts.WriteObj( W, C.obj );  INC( beg )
			END
		END;
		IF beg < end THEN Texts.Save( T, beg, end, W.buf ) END;
		Texts.Append( N, W.buf );
		IF newFile # "" THEN Oberon.OpenText( newFile, N, Wwidth, Wheight ) ELSE
			IF noerr THEN Texts.Save( N, 0, N.len, W.buf );  Texts.Replace( T, 0, T.len, W.buf );  END;
		END;
	END Terminate;

(* ------------ Scanner part ------------- *)

	PROCEDURE Pos*( ): SIGNED32;
	BEGIN
		RETURN Texts.Pos( R );
	END Pos;

	PROCEDURE nextChar;
	BEGIN
		IF (ch > ' ') OR instring THEN
			str[tokenlen] := ch;  INC( tokenlen );
			REPEAT Texts.Read( R, ch );  UNTIL R.eot OR ((R.lib # NIL ) & (R.lib IS Fonts.Font));
			IF (ch = CR) OR (ch = NL) THEN INC( inpLine ) END
		END;
	END nextChar;

	PROCEDURE Str( VAR sym: SIGNED8 );
	VAR i: SIGNED16;  och: CHAR;
	BEGIN
		instring := TRUE;  i := 0;  och := ch;
		LOOP
			nextChar;
			IF ch = och THEN EXIT END;
			IF ch < " " THEN err( 3 );  EXIT END;
			INC( i )
		END;
		instring := FALSE;  nextChar;  isstring := TRUE;
		IF i = 1 THEN sym := number;  ELSE sym := string END;
	END Str;

	PROCEDURE Identifier( VAR sym: SIGNED8 );
	BEGIN
		REPEAT nextChar UNTIL ((ch < "0") OR ("9" < ch) & (CAP( ch ) < "A") OR ("Z" < CAP( ch ))) & (ch # "_");

		str[tokenlen] := 0X;  sym := ident;
	END Identifier;

	PROCEDURE Number;
	VAR i, m, n, d, e: SIGNED16;
		dig: ARRAY 24 OF CHAR;
		f: FLOAT64;  expCh: CHAR;  neg: BOOLEAN;  intval: SIGNED32;

		PROCEDURE Ord( ch: CHAR;  hex: BOOLEAN ): SIGNED16;
		BEGIN
			(* ("0" <= ch) & (ch <= "9") OR ("A" <= ch) & (ch <= "F") *)
			IF ch <= "9" THEN RETURN ORD( ch ) - ORD( "0" )
			ELSIF hex THEN RETURN ORD( ch ) - ORD( "A" ) + 10
			ELSE err( 2 );  RETURN 0
			END
		END Ord;

	BEGIN  (* ("0" <= ch) & (ch <= "9") *)
		i := 0;  m := 0;  n := 0;  d := 0;
		LOOP  (* read mantissa *)
			IF ("0" <= ch) & (ch <= "9") OR (d = 0) & ("A" <= ch) & (ch <= "F") THEN
				IF (m > 0) OR (ch # "0") THEN
					(* ignore leading zeros *)
					IF n < LEN( dig ) THEN dig[n] := ch;  INC( n ) END;
					INC( m )
				END;
				nextChar;  INC( i )
			ELSIF ch = "." THEN
				nextChar;
				IF ch = "." THEN
					(* ellipsis *)
					ch := 7FX;  EXIT
				ELSIF d = 0 THEN  (* i > 0 *) d := i
				ELSE err( 2 )
				END
			ELSE EXIT
			END
		END;   (* 0 <= n <= m <= i, 0 <= d <= i *)
		IF d = 0 THEN
			(* integer *)
			IF n = m THEN
				intval := 0;  i := 0;
				IF ch = "X" THEN
					(* character *)
					nextChar;
					IF n <= 2 THEN
						WHILE i < n DO intval := intval * 10H + Ord( dig[i], TRUE );  INC( i ) END
					ELSE err( 203 )
					END
				ELSIF ch = "H" THEN  (* hexadecimal *) nextChar;
				ELSE
					(* decimal *)
					WHILE i < n DO d := Ord( dig[i], FALSE );  INC( i );  END
				END
			ELSE err( 203 )
			END
		ELSE
			(* fraction *)
			f := 0;  e := 0;  expCh := "E";
			WHILE n > 0 DO
				(* 0 <= f < 1 *)
				DEC( n );  f := (Ord( dig[n], FALSE ) + f) / 10
			END;
			IF (ch = "E") OR (ch = "D") THEN
				expCh := ch;  nextChar;  neg := FALSE;
				IF ch = "-" THEN neg := TRUE;  nextChar
				ELSIF ch = "+" THEN nextChar
				END;
				IF ("0" <= ch) & (ch <= "9") THEN
					REPEAT
						n := Ord( ch, FALSE );  nextChar;
						IF e <= (MAX( SIGNED16 ) - n) DIV 10 THEN e := e * 10 + n ELSE err( 203 ) END
					UNTIL (ch < "0") OR ("9" < ch);
					IF neg THEN e := -e END
				ELSE err( 2 )
				END
			END;
			DEC( e, i - d - m );   (* decimal point shift *)
		END
	END Number;

	PROCEDURE skipSpaces*;
	BEGIN
		WHILE ch <= " " DO
			(* ignore control characters *)
			IF ch = Eot THEN RETURN ELSE
				IF ch = CR THEN
					IF (com.W.buf.len > 0) & ~haveToken THEN INC( com.postNL );  ELSE
						IF nlines = 0 THEN getNLbp
						ELSIF nlines = 1 THEN gotEmptyLine := TRUE;  lastNL.textpos := 0
						END;
						INC( nlines )
					END;
				END;
				REPEAT Texts.Read( R, ch ) UNTIL R.eot OR ((R.lib # NIL ) & (R.lib IS Fonts.Font));
				IF (ch = CR) OR (ch = NL) THEN INC( inpLine ) END
			END
		END;
	END skipSpaces;

	PROCEDURE putc( ch: CHAR;  cnl: BOOLEAN );
	VAR wi, i: SIGNED16;
	BEGIN
		Texts.Write( com.W, ch );
		IF ch = CR THEN com.width := 0;  INC( com.lines );  setFont( 0 );
		ELSIF ch = TAB THEN INC( com.width, tabw )
		ELSE setFont( 3 );  wi := fonts[3].cw[ORD( ch )];  INC( com.width, wi );  emptyLines := 0;
		END;
		IF ch = ' ' THEN

			IF cnl & ((curInd * tabw + com.width) > MaxLineLength) THEN
				putc( CR, cnl );
				FOR i := 1 TO curInd + 1 DO putc( TAB, cnl ) END
			END

		END
	END putc;

	PROCEDURE Get*( VAR sym: SIGNED8 );
	VAR s: SIGNED8;  k: SIGNED16;  read: BOOLEAN;

		PROCEDURE Comment;   (* do not read after end of file *)
		VAR specialcolor: SIGNED8;
			fnt, number: ARRAY 64 OF CHAR;
			size, cnt: SIGNED32;

			PROCEDURE next;
			VAR F: Texts.Finder;  obj: Objects.Object;  C: Objects.CopyMsg;
			BEGIN
				REPEAT
					IF read THEN Texts.Read( R, ch );  ELSE read := TRUE END;
					IF ch = "*" THEN specialcolor := fonts[commentN].col;  Texts.SetFont( com.W, fonts[3].f );  END;
					IF (R.col IN reservedCols) & usecolors THEN Texts.SetColor( com.W, specialcolor ) ELSE Texts.SetColor( com.W, R.col ) END;
					IF (R.lib # NIL ) & (R.lib IS Fonts.Font) THEN putc( ch, FALSE )
					ELSE
						Texts.OpenFinder( F, T, Texts.Pos( R ) - 1 );  Texts.FindObj( F, obj );
						IF (obj IS Display.Frame) THEN
							C.id := Objects.shallow;  Objects.Stamp( C );
							obj.handle( obj, C );   (*  copy *)
							Texts.WriteObj( com.W, C.obj );  INC( com.width, 24 )
						END
					END
				UNTIL R.eot OR ((R.lib # NIL ) & (R.lib IS Fonts.Font));
			END next;

		BEGIN
			read := TRUE;  specialcolor := fonts[commentN].col;  next;
			IF ch = "*" THEN
				size := 6;  cnt := 0;
				WHILE (ch = "*") DO INC( size, 2 );  INC( cnt );  next;  END;
				IF ch = ")" THEN
					RETURN;   (* comment off *)
				END;

				IF size > 24 THEN size := 24
				END;

				fnt := "Syntax";  Strings.IntToStr( size, number );  Strings.Append( fnt, number );  Strings.Append( fnt, "b.Scn.Fnt" );

				Texts.SetFont( com.W, Fonts.This( fnt ) );   (*read := FALSE;  *)
			ELSIF ch = "#" THEN
				next;
				IF Strings.IsDigit( ch ) THEN
					fnt := "Courier";
					WHILE (Strings.IsDigit( ch )) DO Strings.AppendCh( fnt, ch );  next;  END;
					Strings.Append( fnt, "b.Scn.Fnt" );  Texts.SetFont( com.W, Fonts.This( fnt ) );
				END;
			END;
			IF ch = "!" THEN specialcolor := fonts[exportN].col
			ELSIF ch = "?" THEN specialcolor := fonts[keywordN].col
			END;
			LOOP
				LOOP
					WHILE ch = "(" DO
						next;
						IF ch = "*" THEN Comment END;
					END;
					IF ch = "*" THEN next;  EXIT END;
					IF ch = Eot THEN EXIT END;
					next
				END;
				IF ch = ")" THEN EXIT END;
				IF ch = Eot THEN err( 5 );  EXIT END
			END
		END Comment;

	BEGIN
		nlines := 0;  gotEmptyLine := FALSE;  skipSpaces;
		IF ch = Eot THEN sym := eof;  RETURN END;
		putToken;   (* prev read token *)
		kw := FALSE;  emptyLine := gotEmptyLine;  tokCol := R.col;
		CASE ch OF
		(* ch > " " *)
		| 22X, 27X:
				Str( s )
		| "#":     s := neq;  nextChar
		| "&":     s := and;  nextChar
		| "(":     nextChar;
				IF ch = "*" THEN
					IF com.W.buf.len >= 4 THEN
						putComment;   (* comment preceding this comment *)
						nlines := 0
					END;
					com.preNL := nlines;  com.postNL := 0;  com.lines := 1;  com.width := 0;  Texts.SetFont( com.W, fonts[3].f );
					IF (R.col IN reservedCols) & usecolors THEN Texts.SetColor( com.W, fonts[commentN].col ) ELSE Texts.SetColor( com.W, R.col ) END;
					putc( "(", TRUE );  putc( "*", TRUE );  Comment;  tokenlen := 0;  nextChar;  Get( sym );  RETURN
				ELSE s := lparen
				END
		| ")":     s := rparen;  nextChar
		| "*":     nextChar;
				(** fof >> *)
				IF ch = "*" THEN nextChar;  s := dtimes;  ELSE s := times END;
				(** << fof  *)


		| "+":     nextChar;
				(** fof >> *)
				IF ch = "*" THEN nextChar;  s := scalarproduct;  ELSE s := plus END;
				(** << fof  *)
		| ",":     s := comma;  nextChar
		| "-":     s := minus;  nextChar
		| ".":     nextChar;
				IF ch = "." THEN
					nextChar;  s := upto;
					(*
					IF ch="." THEN nextChar; s := filler;
					ELSE s := upto
					END;
					*)
					(** fof >> *)
				ELSIF ch = "*" THEN
					nextChar;  s := elementproduct (*fof*)
				ELSIF ch = "/" THEN nextChar;  s := elementquotient
				ELSIF ch = "=" THEN nextChar;  s := eeql
				ELSIF ch = "#" THEN nextChar;  s := eneq
				ELSIF ch = ">" THEN
					nextChar;
					IF ch = "=" THEN s := egeq;  nextChar;  ELSE s := egtr END;
				ELSIF ch = "<" THEN
					nextChar;
					IF ch = "=" THEN s := eleq;  nextChar;  ELSE s := elss END;
					(** << fof  *)
				ELSE s := period
				END
		| "`":     s := transpose;  nextChar;
				(** << fof  *)
		| "/":     s := slash;  nextChar
		| "\":     s := backslash;  nextChar;
		| "0".."9":   Number;  s := number
		| ":":     nextChar;
				IF ch = "=" THEN nextChar;  s := becomes ELSE s := colon END
		| ";":     s := semicolon;  nextChar
		| "<":     nextChar;
				IF ch = "=" THEN nextChar;  s := leq ELSE s := lss END
		| "=":     s := eql;  nextChar
		| ">":     nextChar;
				IF ch = "=" THEN nextChar;  s := geq ELSE s := gtr END
		| "A".."Z":   Identifier( s );
				IF ucase THEN

					n1 := str[0];
					CASE n1 OF
					| "A":     IF str = "ARRAY" THEN kw := TRUE;  s := array
							ELSIF str = "AWAIT" THEN  (* kw := TRUE; s := passivate*)  (* not handled in OFormatter *)
							END
					| "B":     IF str = "BEGIN" THEN kw := TRUE;  s := begin
							ELSIF str = "BY" THEN kw := TRUE;  s := by
							END
					| "C":     IF str = "CONST" THEN kw := TRUE;  s := const
							ELSIF str = "CASE" THEN kw := TRUE;  s := case
							ELSIF str = "CODE" THEN kw := TRUE;  s := code
							END
					| "D":     IF str = "DO" THEN kw := TRUE;  s := do
							ELSIF str = "DIV" THEN kw := TRUE;  s := div
							ELSIF str = "DEFINITION" THEN kw := TRUE;  s := definition
							END
					| "E":     IF str = "END" THEN kw := TRUE;  s := end
							ELSIF str = "ELSE" THEN kw := TRUE;  s := else
							ELSIF str = "ELSIF" THEN kw := TRUE;  s := elsif
							ELSIF str = "EXIT" THEN kw := TRUE;  s := exit
							END
					| "F":     IF str = "FALSE" THEN kw := TRUE;  s := false
							ELSIF str = "FOR" THEN kw := TRUE;  s := for
							ELSIF str = "FINALLY" THEN kw := TRUE;  s := finally
							END
					| "I":     IF str = "IF" THEN kw := TRUE;  s := if
							ELSIF str = "IN" THEN kw := TRUE;  s := in
							ELSIF str = "IS" THEN kw := TRUE;  s := is
							ELSIF str = "IMPORT" THEN kw := TRUE;  s := import
							ELSIF str = "IMPLEMENTS" THEN kw := TRUE;  s := implements
							END
					| "L":     IF str = "LOOP" THEN kw := TRUE;  s := loop END
					| "M":     IF str = "MOD" THEN kw := TRUE;  s := mod
							ELSIF str = "MODULE" THEN kw := TRUE;  s := module;  lcase := FALSE
							END
					| "N":     IF str = "NIL" THEN kw := TRUE;  s := nil END
					| "O":     IF str = "OR" THEN kw := TRUE;  s := or
							ELSIF str = "OF" THEN kw := TRUE;  s := of
							ELSIF str = "OBJECT" THEN kw := TRUE;  s := object
							END
					| "P":     IF str = "PROCEDURE" THEN kw := TRUE;  s := procedure
							ELSIF str = "POINTER" THEN kw := TRUE;  s := pointer
							END
					| "R":     IF str = "RECORD" THEN kw := TRUE;  s := record
							ELSIF str = "REPEAT" THEN kw := TRUE;  s := repeat
							ELSIF str = "RETURN" THEN kw := TRUE;  s := return
							ELSIF str = "REFINES" THEN kw := TRUE;  s := refines
							END
					| "T":
							(* 	     IF str = "TENSOR" THEN kw := TRUE;  s := tensor (* fof *)
						ELS*)
							IF str = "THEN" THEN kw := TRUE;  s := then
							ELSIF str = "TRUE" THEN kw := TRUE;  s := true
							ELSIF str = "TO" THEN kw := TRUE;  s := to
							ELSIF str = "TYPE" THEN kw := TRUE;  s := type
							END
					| "U":     IF str = "UNTIL" THEN kw := TRUE;  s := until END
					| "V":     IF str = "VAR" THEN kw := TRUE;  s := var END
					| "W":     IF str = "WHILE" THEN kw := TRUE;  s := while
							ELSIF str = "WITH" THEN kw := TRUE;  s := with
							END
					ELSE
					END;
				END;
		| "a".."z":   Identifier( s );
				IF lcase THEN
					n1 := str[0];
					CASE n1 OF
					| "a":     IF str = "array" THEN kw := TRUE;  s := array
							ELSIF str = "await" THEN kw := TRUE;  s := passivate
							END
					| "b":     IF str = "begin" THEN kw := TRUE;  s := begin
							ELSIF str = "by" THEN kw := TRUE;  s := by
							END
					| "c":     IF str = "const" THEN kw := TRUE;  s := const
							ELSIF str = "case" THEN kw := TRUE;  s := case
							ELSIF str = "code" THEN kw := TRUE;  s := code
							END
					| "d":     IF str = "do" THEN kw := TRUE;  s := do
							ELSIF str = "div" THEN kw := TRUE;  s := div
							ELSIF str = "definition" THEN kw := TRUE;  s := definition
							END
					| "e":     IF str = "end" THEN kw := TRUE;  s := end
							ELSIF str = "else" THEN kw := TRUE;  s := else
							ELSIF str = "elsif" THEN kw := TRUE;  s := elsif
							ELSIF str = "exit" THEN kw := TRUE;  s := exit
							END
					| "f":     IF str = "false" THEN kw := TRUE;  s := false
							ELSIF str = "for" THEN kw := TRUE;  s := for
							ELSIF str = "finally" THEN kw := TRUE;  s := finally
							END
					| "i":     IF str = "if" THEN kw := TRUE;  s := if
							ELSIF str = "in" THEN kw := TRUE;  s := in
							ELSIF str = "is" THEN kw := TRUE;  s := is
							ELSIF str = "import" THEN kw := TRUE;  s := import
							ELSIF str = "implements" THEN kw := TRUE;  s := implements
							END
					| "l":     IF str = "loop" THEN kw := TRUE;  s := loop END
					| "m":     IF str = "mod" THEN kw := TRUE;  s := mod
							ELSIF str = "module" THEN kw := TRUE;  s := module;  ucase := FALSE;
							END
					| "n":     IF str = "nil" THEN kw := TRUE;  s := nil END
					| "o":     IF str = "or" THEN kw := TRUE;  s := or
							ELSIF str = "of" THEN kw := TRUE;  s := of
							ELSIF str = "object" THEN kw := TRUE;  s := object
							END
					| "p":     IF str = "procedure" THEN kw := TRUE;  s := procedure
							ELSIF str = "pointer" THEN kw := TRUE;  s := pointer
							END
					| "r":     IF str = "record" THEN kw := TRUE;  s := record
							ELSIF str = "repeat" THEN kw := TRUE;  s := repeat
							ELSIF str = "return" THEN kw := TRUE;  s := return
							ELSIF str = "refines" THEN kw := TRUE;  s := refines
							END
					| "t":      (*   IF str = "tensor" THEN kw := TRUE;  s := tensor;
							ELS*)
							IF str = "then" THEN kw := TRUE;  s := then
							ELSIF str = "true" THEN kw := TRUE;  s := true
							ELSIF str = "to" THEN kw := TRUE;  s := to
							ELSIF str = "type" THEN kw := TRUE;  s := type
							END
					| "u":     IF str = "until" THEN kw := TRUE;  s := until END
					| "v":     IF str = "var" THEN kw := TRUE;  s := var END
					| "w":     IF str = "while" THEN kw := TRUE;  s := while
							ELSIF str = "with" THEN kw := TRUE;  s := with
							END
					ELSE
					END;
					IF firstId & (s # module) THEN lcase := FALSE;  s := ident END;
				END
		| "[":     s := lbrak;  nextChar
		| "]":     s := rbrak;  nextChar
		| "^":     s := arrow;  nextChar
		| "{":     s := lbrace;  nextChar
		| "|":     s := bar;  nextChar
		| "}":     s := rbrace;  nextChar
		| "~":     s := not;  nextChar
		| "?":     s := qmark;  nextChar
		| 7FX:
				s := upto;  str := ".";  tokenlen := 1;  ch := " ";  nextChar;
		ELSE s := null;  nextChar
		END;
		firstId := FALSE;  sym := s;  outsym := s;
		IF ucase & lowercase & kw THEN
			FOR k := 0 TO tokenlen - 1 DO str[k] := CHR( ORD( str[k] ) + 32 ) END
		ELSIF lcase & uppercase & kw THEN
			FOR k := 0 TO tokenlen - 1 DO str[k] := CHR( ORD( str[k] ) - 32 ) END
		END;
		haveToken := TRUE;
	END Get;

	PROCEDURE LoadFont( n: SIGNED16;  prefix: CHAR;  VAR col: SIGNED8 ): Fonts.Font;
	VAR S: Texts.Scanner;
		rname, fname: ARRAY 64 OF CHAR;
		na: ARRAY 2 OF CHAR;
		f: Fonts.Font;
	BEGIN
		fname := "";  rname := "OberonFormatter.";
		IF prefix # 0X THEN Strings.AppendCh( rname, prefix ) END;
		Strings.Append( rname, "font" );  na[0] := CHR( ORD( '0' ) + n );  na[1] := 0X;  Strings.Append( rname, na );

		Oberon.OpenScanner( S, rname );
		IF (S.class = Texts.Name) THEN
			COPY( S.s, fname );  f := Fonts.This( fname );
			IF f = NIL THEN Out.String( "failed to load font '" );  Out.String( fname );  Out.Char( "'" );  Out.Ln END;
		ELSIF (prefix # "p") & (n < 8) THEN
			IF (n = 3) & (prefix = 'l') THEN n := 0 END;  (* lower case keywords *)
			COPY( defaultFont[n], fname );
			f := Fonts.This( fname );
			IF f = NIL THEN Out.String( "failed to load font " );  Out.String( fname );  Out.Ln END;
		ELSE f := Fonts.Default
		END;
		Texts.Scan( S );
		IF S.class = Texts.Int THEN col := SHORT( SHORT( S.i ) )
		ELSIF (prefix # "p") & (n < 8) THEN col := (defaultColor[n]);
		ELSE col := 15
		END;
		RETURN f
	END LoadFont;

	PROCEDURE Init*( CONST fn: ARRAY OF CHAR;  prefix: CHAR;  color: BOOLEAN;  lower, upper: BOOLEAN );
	VAR i: SIGNED16;
	BEGIN
		uppercase := upper;  lowercase := lower;  usecolors := color;
		FOR i := 1 TO LEN( fonts ) DO fonts[i - 1].f := LoadFont( i, prefix, fonts[i - 1].col );  END;
		getCharWidths();  ch := " ";  NEW( T );  Texts.Open( T, fn );
		IF T # NIL THEN Texts.OpenReader( R, T, 0 ) END;
		COPY( fn, newFile );  i := 0;
		WHILE newFile[i] # 0X DO INC( i ) END;
		newFile[i] := '.';  INC( i );
		IF prefix = 0X THEN newFile[i] := 'n' END;
		INC( i );  newFile[i] := 0X;  NEW( N );  Texts.Open( N, "" );  setFont( 0 );  tokenlen := 0;  haveToken := FALSE;  curInd := 0;  width := 0;  lastch := 0X;  needSp := FALSE;  linestart := TRUE;  instring := FALSE;
		curLine := 1;  expMark := FALSE;  lastbp := NIL;  NewBPS( nossbp );  curbp := nossbp;  lastNL.line := -1;  lastNL.textpos := 0;  il1pos := 0;  il2pos := 0;  indentl1 := 0;  indentl2 := 0;  inBreakLine := FALSE;
		inPutComment := FALSE;  inAssComment := FALSE;  forceNL := FALSE;  inpLine := 1;  lastLineStart := 0;  lcase := TRUE;  ucase := TRUE;  firstId := TRUE;
	END Init;

	PROCEDURE InitText*( t: Texts.Text;  prefix: CHAR;  color: BOOLEAN;  lower, upper: BOOLEAN );
	VAR i: SIGNED16;
	BEGIN
		uppercase := upper;  lowercase := lower;  usecolors := TRUE;  reservedCols := {};
		FOR i := 1 TO LEN( fonts ) DO fonts[i - 1].f := LoadFont( i, prefix, fonts[i - 1].col );  INCL( reservedCols, fonts[i - 1].col );  END;
		IF ~color THEN  (* remove colors *)
			FOR i := 1 TO LEN( fonts ) DO
				fonts[i - 1].col := 15 (* black *)
			END;
		END;
		getCharWidths();  ch := " ";   (* NEW( T );  Texts.Open( T, fn ); *)
		T := t;
		IF T # NIL THEN Texts.OpenReader( R, T, 0 ) END;
		(*
		COPY( fn, newFile );  i := 0;
		WHILE newFile[i] # 0X DO INC( i ) END;
		newFile[i] := '.';  INC( i );
		IF print THEN newFile[i] := 'p' ELSE newFile[i] := 'n' END;
		INC( i );  newFile[i] := 0X;
		*)
		newFile := "";  NEW( N );  Texts.Open( N, "" );  setFont( 0 );  tokenlen := 0;  haveToken := FALSE;  curInd := 0;  width := 0;  lastch := 0X;  needSp := FALSE;  linestart := TRUE;  instring := FALSE;  curLine := 1;
		expMark := FALSE;  lastbp := NIL;  NewBPS( nossbp );  curbp := nossbp;  lastNL.line := -1;  lastNL.textpos := 0;  il1pos := 0;  il2pos := 0;  indentl1 := 0;  indentl2 := 0;  inBreakLine := FALSE;
		inPutComment := FALSE;  forceNL := FALSE;  inpLine := 1;  lastLineStart := 0;  lcase := TRUE;  firstId := TRUE;  ucase := TRUE;

	END InitText;

BEGIN
	Texts.OpenWriter( W );  Texts.OpenWriter( com.W );  NEW( lastNL );  MaxLineLength := Display.Width DIV 2 ;
	(*
		1=	nomal, 2 = exported identifiers, 3 = key words, 4 = comments,  5 = important, 6 = string, 7 = extra keyword
	*)
	defaultFont[0] := "Oberon10b.Scn.Fnt";  defaultColor[1] := 15;	(* lower case keywords *)
	defaultFont[1] := "Syntax10.Scn.Fnt";  defaultColor[1] := 15;
	defaultFont[2] := "Syntax10b.Scn.Fnt";  defaultColor[2] := 7;
	defaultFont[3] := "Oberon8b.Scn.Fnt";  defaultColor[3] := 15;
	defaultFont[4] := "Oberon10.Scn.Fnt";  defaultColor[4] := 8;
	defaultFont[5] := "Syntax10m.Scn.Fnt";  defaultColor[5] := 9;
	defaultFont[6] := "Oberon10i.Scn.Fnt";  defaultColor[6] := 11;
	defaultFont[7] := "Syntax10.Scn.Fnt";  defaultColor[7] := 15;

END OFormatterIO.