(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE RX IN Oberon;	(** portable *)	(* Andreas Margelisch, 1990 *)

(*
Work on texts using regular expressions.
$Log$
$   3, Edgar@EdgarSchwarz.de, 01.12.00 22:48:47
Without ArgTools, no renaming to simplify parameter parsing
$   2, Edgar@EdgarSchwarz.de, 26.11.00 20:48:37
ReplaceAll can use filenames as parameter and redirect output.
$   1, Edgar@EdgarSchwarz.de, 26.11.00 08:30:01
21.11.00 prk - Removed TextGadgets0 import.
*)

IMPORT RXA, Oberon, Objects, Texts, Display, Files;

CONST
	blank = 32; (* blank *)
	tab = 9; (* tab *)
	cr = 13; (* carriage return *)
	dq = 34; (* double quotes *)

	noerror = 0;
	strtoolong = -1;
	linetoolong = -2;

	(* nofline = 32000; *) nofline = 10000;
	(* nofrepl = 32000; *) nofrepl = 10000;

VAR
	w: Texts.Writer;
	sbeg, send, errorvar : SIGNED16;
	sdfa : RXA.DFA;
	stext : Texts.Text;
	stextpos, slinelen : SIGNED32;
	sline : ARRAY(nofline+1) OF CHAR;
	sreplaced, casesens, replset : BOOLEAN;
	replstr : ARRAY(nofrepl+1) OF CHAR;
	ch : CHAR;

PROCEDURE GetCaret(VAR f: Display.Frame;  VAR t: Texts.Text; VAR pos: SIGNED32);
VAR M: Oberon.CaretMsg;
BEGIN
	M.id := Oberon.get; M.text := NIL;
	Display.Broadcast(M);
	f := M.car; t := M.text; pos := M.pos
END GetCaret;

PROCEDURE SetSelection(f: Display.Frame; t: Texts.Text; beg, end: SIGNED32);
VAR SM: Oberon.SelectMsg;  CM: Oberon.CaretMsg;
BEGIN
	SM.id := Oberon.set; SM.sel := f; SM.text := t; SM.beg := beg; SM.end := end; SM.time := -1;
	Display.Broadcast(SM);
	CM.id := Oberon.set; CM.text := t; CM.car := f; CM.pos := end;
	Display.Broadcast(CM);
END SetSelection;

PROCEDURE RemoveSelection(f: Display.Frame; t: Texts.Text);
VAR SM: Oberon.SelectMsg;  CM: Oberon.CaretMsg;
BEGIN
	SM.id := Oberon.reset; SM.sel := f; SM.text := t; Display.Broadcast(SM);
	CM.id := Oberon.reset; CM.text := t; CM.car := f; Display.Broadcast(CM);
END RemoveSelection;

PROCEDURE MyCAP( ch : CHAR ) : CHAR;
BEGIN IF ("a" <= ch ) & ( ch <= "z" ) THEN RETURN CAP( ch ) ELSE RETURN ch END;
END MyCAP;

PROCEDURE ThisFrame(X, Y: SIGNED16; VAR F: Display.Frame);
	VAR M: Display.LocateMsg;
BEGIN	M.X := X; M.Y := Y; M.F := NIL; M.loc := NIL; Display.Broadcast(M); F := M.loc
END ThisFrame;

PROCEDURE GetText(  VAR text : Texts.Text; VAR name : ARRAY OF CHAR; VAR s : Texts.Scanner );
	VAR
		 F: Display.Frame;
		 M: Objects.LinkMsg;
BEGIN
	Texts.Scan( s );
	text := NIL; name[0] := 0X;
	IF s.class = Texts.Name THEN
		NEW( text ); Texts.Open( text, s.s ); COPY( s.s, name );
	ELSIF ( s.class = Texts.Char ) & ( s.c = "*" ) THEN
		text := NIL; ThisFrame(Oberon.Pointer.X, Oberon.Pointer.Y, F);
		IF F # NIL THEN
			M.id := Objects.get; M.name := "Model"; M.obj := NIL; M.res := -1; F.handle(F, M);
			IF (M.obj # NIL) & (M.obj IS Texts.Text) THEN text := M.obj(Texts.Text) END
		END;
	END;
END GetText;

PROCEDURE GetOption( VAR reader : Texts.Reader; VAR opti : BOOLEAN );
BEGIN
	casesens := TRUE;
	opti := FALSE;
	Texts.Read( reader, ch );
	WHILE ( ORD(ch) = tab ) OR ( ORD(ch) = blank ) OR ( ORD(ch) = cr ) DO Texts.Read( reader, ch ) END;
	IF  ch = Oberon.OptionChar THEN
		REPEAT
			Texts.Read( reader, ch );
			CASE ch OF
				"c"  : casesens := ~casesens |
				"i" : opti := ~opti |
				"~" : RETURN;
			ELSE
			END;
		UNTIL ( ORD(ch) = blank ) OR ( ORD(ch) = cr ) OR ( ORD(ch) =tab );
	END;
END GetOption;

PROCEDURE GetStr( VAR reader : Texts.Reader; VAR str : ARRAY OF CHAR );
	VAR strfull, inquotes, first : BOOLEAN;
		strind : SIGNED16;

	PROCEDURE Append( chr : CHAR );
	BEGIN
		IF strind < LEN( str ) THEN str[strind] := chr; INC(strind) ELSE strfull := TRUE END;
	END Append;

BEGIN
	strfull := FALSE; strind := 0; inquotes := FALSE; first := FALSE;
	WHILE ( ORD(ch) = tab ) OR ( ORD(ch) = cr ) OR ( ORD(ch) = blank ) DO Texts.Read( reader, ch ) END;
	WHILE ( ~reader.eot ) & ( ORD(ch) # cr ) DO
		IF ~first & ( ORD(ch) = dq ) THEN inquotes := ~inquotes; first := inquotes; Append( ch );
		ELSE
			IF inquotes & ~casesens THEN Append( MyCAP( ch ) ) ELSE Append( ch ) END;
			first := FALSE;
		END;
		Texts.Read( reader, ch );
	END;
	Append( CHR(0) );
	IF strfull THEN errorvar := strtoolong END;
END GetStr;

PROCEDURE RXAErrorHandler( error, pos : SIGNED16 );
BEGIN
	CASE error OF
		RXA.noposfree : Texts.WriteString( w,"regular expression too long ( position table full )") |
		RXA.nostatesfree : Texts.WriteString( w,"regular expression too long ( state table full  )") |
		RXA.nometaexp : Texts.WriteString( w,"no metasymbol at pos "); Texts.WriteInt( w, pos, 3 );
								  Texts.WriteString( w," expected ") |
		RXA.chrleft : Texts.WriteString( w,"regular expression not correct ( ')', ']' or '}' on a wrong place )") |
		RXA.wsubexpr : Texts.WriteString( w,"subexpression, String or shorthands 't' or 'c' at pos "); Texts.WriteInt( w,pos, 3);
								   Texts.WriteString( w," expected ") |
		RXA.subexprrest : Texts.WriteString( w,"marked subexpression at pos "); Texts.WriteInt( w,pos, 3);
									  Texts.WriteString( w," shouldn't be enclosed by '{  }'  ") |
		RXA.wshorthand : Texts.WriteString( w,"wrong shorthand identifier at pos "); Texts.WriteInt( w,pos, 3); Texts.WriteLn( w );
									  Texts.WriteString( w,"permitted are : A, a, b, c, d, h, i, l, o, t, w ") |
		RXA.nodfa : Texts.WriteString( w,"replace faild : automata is missing") |
		RXA.repllinefull : Texts.WriteString( w,"replace faild : replacestring is full ") |
		RXA.notnotexp : Texts.WriteString( w,"metasymbol or more than one literal in qutoes after notoperator") |
		RXA.linecopofl : Texts.WriteString( w, "array linecop in RXA.Replace is too small");
	ELSE
		Texts.Write(w, "'"); Texts.Write(w, CHR(error)); Texts.Write(w, "'"); Texts.WriteString( w," at pos ");
		Texts.WriteInt( w,pos, 3); Texts.WriteString( w," expected ");
	END;
	Texts.WriteLn( w );
	Texts.Append( Oberon.Log, w.buf);
END RXAErrorHandler;

PROCEDURE RXErrorHandler( text : ARRAY OF CHAR );
BEGIN
	CASE errorvar OF
		strtoolong, linetoolong : Texts.WriteString( w, text ); Texts.WriteString( w," too long ");
	ELSE
		Texts.WriteString( w, text );
	END;
	Texts.WriteLn( w );
	Texts.Append( Oberon.Log, w.buf);
	errorvar := noerror;
END RXErrorHandler;

PROCEDURE ParseTexts( text : Texts.Text; name : ARRAY OF CHAR; dfa : RXA.DFA; opti : BOOLEAN );
	VAR
		ch : CHAR;
		r : Texts.Reader;
		line, linec : ARRAY(nofline+1) OF CHAR;
		lineind, i, beg, end : SIGNED16;
		wtext: Texts.Text;
		linefull : BOOLEAN;

	PROCEDURE Append( chr : CHAR );
	BEGIN
		IF lineind < LEN( line ) THEN line[lineind] := chr; INC(lineind) ELSE linefull := TRUE END;
	END Append;

BEGIN
	NEW(wtext); Texts.Open(wtext, "");
	Oberon.OpenText("RX.Grep", wtext, Display.Width DIV 2, 200);
	Texts.OpenReader( r, text, 0 );
	WHILE ( ~ r.eot ) DO
		lineind := 0; linefull := FALSE;
		REPEAT
			Texts.Read( r, ch ); Append( ch );
		UNTIL  r.eot OR ( ch = CHR(cr) );
		Append( CHR(0) );
		IF linefull THEN
			RXErrorHandler( " ERROR : line is too long ");
		ELSE
			beg := 0;
			IF casesens THEN
				RXA.Search( dfa, line, beg, end );
			ELSE
				COPY( line, linec ); i := 0; ch := linec[0];
				WHILE ch # 0X DO linec[i] := MyCAP( ch ); INC(i); ch := linec[i] END;
				RXA.Search( dfa, linec, beg, end );
			END;
			IF r.eot THEN DEC(lineind) END;
			IF ( ( end >= 0 ) & (~opti) ) OR ( ( end < 0 ) & opti ) THEN
				i := 0; WHILE i < lineind-1 DO Texts.Write(w, line[i] ); INC(i) END;
				Texts.Append( wtext, w.buf );
			END;
		END;
	END;
END ParseTexts;


PROCEDURE Grep*;
	VAR
		opti : BOOLEAN;
		rx : ARRAY(nofline+1) OF CHAR;
		error, erpos : SIGNED16;
		dfa : RXA.DFA;
		s : Texts.Scanner;
		text : Texts.Text;
		name : ARRAY 32 OF CHAR;
BEGIN
	Texts.OpenScanner( s, Oberon.Par.text, Oberon.Par.pos );
	GetText( text, name, s );
	GetOption( s, opti );
	GetStr( s, rx );
	IF errorvar = noerror THEN
		RXA.New( rx, dfa, error, erpos );
		IF (error = RXA.noerror) & ( text # NIL ) THEN
			ParseTexts( text, name, dfa, opti )
		ELSE
			RXAErrorHandler( error, erpos )
		END;
	ELSE
		RXErrorHandler("regular expression");
	END;
END Grep;

PROCEDURE SetSearch*;
	VAR
		opti : BOOLEAN;
		rx : ARRAY(nofline+1) OF CHAR;
		error, erpos : SIGNED16;
		r : Texts.Reader;
BEGIN
	Texts.OpenReader( r, Oberon.Par.text, Oberon.Par.pos );
	GetOption( r, opti );
	GetStr( r, rx );
	IF errorvar = noerror THEN
		RXA.New( rx, sdfa, error, erpos );
		IF error # RXA.noerror THEN RXAErrorHandler( error, erpos ) END;
	ELSE
		RXErrorHandler("regular expression");
	END;

(*	RXA.Dump( sdfa, w ); Texts.Append( Oberon.Log, w.buf ); *)

END SetSearch;

PROCEDURE SetReplace*;
	VAR r : Texts.Reader;
BEGIN
	replset := TRUE;
	Texts.OpenReader( r, Oberon.Par.text, Oberon.Par.pos );
	Texts.Read(r, ch);	(* << mmb *)
	GetStr( r, replstr );
	IF errorvar # noerror THEN RXErrorHandler("replace pattern"); END;
END SetReplace;

PROCEDURE SearchPattern( text : Texts.Text; textpos : SIGNED32 );
	VAR
	r : Texts.Reader;
	beg, end, lineind : SIGNED16;
	ch : CHAR;
	line : ARRAY(nofline+1) OF CHAR;
	linelen : SIGNED32;
	linefull : BOOLEAN;

PROCEDURE Append( chr : CHAR );
BEGIN
	IF lineind < LEN( line ) THEN
		IF ~casesens  THEN line[lineind] := MyCAP( chr ) ELSE line[lineind] := chr END;
		INC(lineind);
	ELSE
		linefull := TRUE;
	END;
END Append;

BEGIN
	end := -1;
	Texts.OpenReader( r, text, textpos );
	WHILE  ( ~ r.eot ) & ( end < 0 ) DO
		lineind := 0; linefull := FALSE;
		textpos := Texts.Pos( r );
		REPEAT
			Texts.Read( r, ch );
			Append( ch );
		UNTIL r.eot OR ( ch = CHR(cr) );
		linelen := lineind;
		Append( CHR(0) );
		IF linefull THEN
			RXErrorHandler( " ERROR : line is too long ");
		ELSE
			beg := 0;
			RXA.Search( sdfa, line, beg, end );
		END;
	END;
	IF end >= 0 THEN
		stext := text; stextpos := textpos; slinelen := linelen; sbeg := beg; send := end; sreplaced := FALSE; COPY( line, sline );
		IF r.eot THEN DEC(slinelen) END
	ELSE
		stext := NIL
	END;
END SearchPattern;


PROCEDURE Search*;
	VAR
		frame: Display.Frame;
		text: Texts.Text;
		textpos : SIGNED32;
BEGIN
	errorvar := noerror;
	GetCaret(frame, text, textpos);
	IF frame # NIL THEN
		SearchPattern( text, textpos );
		IF ( ~sreplaced ) & ( text = stext ) THEN
			Oberon.Defocus;
			SetSelection(frame, text, stextpos + sbeg, stextpos + send);
		ELSE
			RemoveSelection(frame, text)
		END
	END;
END Search;

PROCEDURE Replace*;
	VAR
		error, pos, i : SIGNED16;
		frame: Display.Frame;
		text: Texts.Text;
		textpos : SIGNED32;
BEGIN
	IF ( ~sreplaced ) & replset THEN
		GetCaret(frame, text, textpos);
		IF frame # NIL THEN
			IF  textpos = stextpos + send THEN
				RXA.Replace( sdfa, sline, replstr, sbeg, send, error, pos );
				sreplaced := error = RXA.noerror;
				IF sreplaced THEN
					Oberon.Defocus;
					(*Out.String("delete "); Out.Int(slinelen, 5); Out.String(" characters"); Out.Ln;*)
					Texts.Delete( text, stextpos,  stextpos + slinelen);
					i := 0; WHILE( i < LEN( sline ) ) & ( sline[i] # 0X ) DO Texts.Write( w, sline[i] ); INC(i) END;
					Texts.Insert( text, stextpos, w.buf );
					textpos := stextpos + pos;
					SearchPattern( text, textpos );
					IF ~sreplaced & (text = stext) THEN
						SetSelection(frame, (*frame.*)text, stextpos + sbeg, stextpos + send);
					ELSE
						RemoveSelection(frame, (*frame.*)text)
					END;
				ELSE
					RXAErrorHandler( error, pos );
				END;
			END
		END;
	END;
END Replace;

(* Save a text to a file. *)
PROCEDURE storeToFile(t: Texts.Text; name: ARRAY OF CHAR);
VAR
	f: Files.File; R: Files.Rider; len: SIGNED32;
BEGIN
	f := Files.New(name);
	Files.Set(R, f, 0);
	Texts.Store(t, f, Files.Pos(R), len);
	Files.Register(f);
END storeToFile;

(* Get text and optional name: * ,  ^ , 1{<filename>} ~ *)
PROCEDURE textName(VAR text: Texts.Text; VAR name: ARRAY OF CHAR;
									VAR first, last: BOOLEAN; VAR S: Texts.Scanner): BOOLEAN;
VAR beg, end, time: SIGNED32;

PROCEDURE openText(VAR textName: ARRAY OF CHAR): BOOLEAN;
BEGIN
	Texts.WriteString(w, textName); Texts.WriteLn(w); Texts.Append(Oberon.Log, w.buf);
	NEW(text); Texts.Open(text, textName); COPY(textName, name);
	IF text.len = 0 THEN
		text := NIL; RETURN FALSE;
	ELSE
		RETURN TRUE;
	END;
END openText;

BEGIN
	IF last THEN
		RETURN FALSE;
	ELSE
		IF first THEN
			Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);  Texts.Scan(S);
			IF (S.class = Texts.Char) & (S.c = "*") THEN
				(*        marked text           *)
				text := Oberon.MarkedText();
				IF text # NIL THEN
					name[0] := 0X; last := TRUE; RETURN TRUE;
				ELSE RETURN FALSE; END
			ELSIF (S.class = Texts.Char) & (S.c = "^") THEN
			    (*             filename selected               *)
				Oberon.GetSelection(text, beg, end, time);
				IF time >= 0 THEN
					Texts.OpenScanner(S, text, beg); Texts.Scan(S);
					IF S.class = Texts.Name THEN
						last := TRUE; RETURN openText(S.s);
					ELSE RETURN FALSE; END;
				ELSE RETURN FALSE; END
			ELSE (* list of filenames *)
				Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
				IF S.class = Texts.Name THEN
					first := FALSE; RETURN openText(S.s);
				ELSE RETURN FALSE; END;
			END
		ELSE (* not first filenames *)
			Texts.Scan(S);
			IF S.class = Texts.Name THEN
				RETURN openText(S.s);
			ELSE RETURN FALSE; END;
		END
	END
END textName;

(** Replace in marked text or files patterns set by RX.SetSearch and RX.SetReplace.
* marked text, ^ selected filename, 1{<filename>} ~ list of filenames *)
PROCEDURE ReplaceAll*;
	VAR
		text: Texts.Text;
		textpos : SIGNED32;
		error, pos, i : SIGNED16;
		name: ARRAY 128 OF CHAR;
		lastArg, firstArg: BOOLEAN;
		S: Texts.Scanner;
BEGIN
	errorvar := noerror;
	lastArg := FALSE; firstArg := TRUE;
	WHILE textName(text, name, firstArg, lastArg, S) DO
		LOOP
			SearchPattern( text, textpos );
			IF ~sreplaced THEN
				RXA.Replace( sdfa, sline, replstr, sbeg, send, error, pos );
				IF error = RXA.noerror THEN
					sreplaced := TRUE;
					Texts.Delete( text, stextpos,  stextpos + slinelen );
					i := 0; WHILE( i < LEN( sline ) ) & ( sline[i] # 0X ) DO Texts.Write( w, sline[i] ); INC(i) END;
					Texts.Insert( text, stextpos, w.buf );
					textpos := stextpos + pos;
				ELSE
					RXAErrorHandler( error, pos );
					RETURN
				END;
			ELSE
				EXIT;
			END;
		END;
		IF name # "" THEN storeToFile(text, name); END;
	END
END ReplaceAll;

BEGIN
	Texts.OpenWriter( w );
	errorvar := noerror;
	replset := FALSE;
	sreplaced := TRUE;
	sdfa := NIL;
END RX.