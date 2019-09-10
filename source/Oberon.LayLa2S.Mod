(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE LayLa2S IN Oberon;	(** portable *)

IMPORT Texts, Oberon, Layouts;

CONST	(** symbol constants *)
		null* = 0;
		(** special caracters *)
		equal* = 4;	lbrak* = 6;	rbrak* = 7;
		(** argument types *)
		String* = 20;	Int* = 21;	Real* = 22;	Char* = 23;	Bool* = 24;	Qualident* = 28;	Ident* = 29;
		(** operators *)
		Config* = 30;	New* = 31;	HList* = 32;	VList* = 33;	Table* = 34;	Place* = 35;
		Contents* = 36;	Deep* = 37;	Shallow* = 38;	Include* = 39;	End* = 40;
		Def* = 41;	Params* = 42;	Layout* = 43;	Attributes* = 44;	Links* = 45;
		Virtual* = 46;	Default* = 47;	Break* = 48;	Span* = 49;
		(** special values *)
		Left* = Layouts.Left;	Right* = Layouts.Right;	Bottom* = Layouts.Bottom;	Top* = Layouts.Top;
		Center* = Layouts.Center;	Static* = Layouts.Static;	Dynamic* = Layouts.Dynamic;
		Hor* = Layouts.Hor;	Vert* = Layouts.Vert;

		strlen = 256;
		idlen = 64;

VAR  reader : Texts.Reader;
		ch : CHAR;
		W : Texts.Writer;

		error* : BOOLEAN;
		eot* : BOOLEAN;
		errpos : SIGNED32;

		s* : ARRAY strlen OF CHAR;
		ident* : ARRAY idlen OF CHAR;
		int* : SIGNED32;
		real* : FLOAT32;
		char* : CHAR;
		bool* : BOOLEAN;

PROCEDURE Pos* () : SIGNED32;
BEGIN	RETURN Texts.Pos(reader)
END Pos;

PROCEDURE Mark* (pos : SIGNED32; t : ARRAY OF CHAR);
VAR p : SIGNED32;
BEGIN	p := Pos ();
	IF p > errpos THEN
		Texts.WriteString (W, "  pos "); Texts.WriteInt(W, pos, 1);
		Texts.WriteString(W, "  err "); Texts.WriteString(W, t);
		Texts.WriteLn (W);
		Texts.Append (Oberon.Log, W.buf);
	END;
	errpos:=p; error:=TRUE
END Mark;

PROCEDURE ReadChar;
BEGIN	IF ~reader.eot THEN Texts.Read (reader, ch) ELSE ch := 0X; eot := TRUE END
END ReadChar;

PROCEDURE Comment;
VAR p : SIGNED32;
BEGIN	p := Pos ();
	REPEAT ReadChar;
		IF ch = '{' THEN Comment END;
		IF eot THEN Mark (p, "Comment not closed"); ch := '}' END
	UNTIL ch = '}';
	ReadChar;
END Comment;

PROCEDURE ReadString (VAR sym : SIGNED16);
VAR i : SIGNED16;
		quot : CHAR;
		pos : SIGNED32;
BEGIN	quot := ch;
	ReadChar; sym := String; pos := Pos ();
	i := 0;
	WHILE (ch # quot) & ~eot DO
		IF i < strlen THEN	s[i] := ch; INC (i)	END;
		ReadChar
	END;
	s[strlen-1] := 0X;
	IF ch # quot THEN Mark (pos, "String not closed")
	ELSIF i = strlen THEN Mark (pos, "String too long")
	ELSE s[i] := 0X END;
	ReadChar;
END ReadString;

PROCEDURE ReadNumber (VAR sym : SIGNED16);
VAR  intE, realE : BOOLEAN;
		n : SIGNED16;
		quotient : FLOAT32;
BEGIN	sym := Int;
	int := 0;	real := 0;	intE := FALSE;	realE := FALSE;
	WHILE (ch >= '0') & (ch <= '9') DO
		n := ORD(ch)-ORD('0');
		IF (MAX(SIGNED32)-n) DIV 10 >= int THEN
			int := int*10 + n;	real := int
		ELSIF (MAX(FLOAT32)-n)/10 >= real THEN
			intE := TRUE;
			real := real*10 + ORD(ch)-ORD('0')
		ELSE realE := TRUE
		END;
		ReadChar
	END;
	IF ch = '.' THEN
		sym := Real;	quotient := 1;
		ReadChar;
		WHILE (ch >= '0') & (ch <= '9') DO
			quotient := quotient/10;	real := real + (ORD(ch)-ORD('0'))*quotient;
			ReadChar;
		END;
	END;
	IF (sym = Int) & intE THEN Mark (Pos (), "Integer overflow")
	ELSIF (sym = Real) & realE THEN Mark (Pos (), "real overflow")
	END
END ReadNumber;

PROCEDURE ReadIdent (VAR sym : SIGNED16);
VAR i : SIGNED16;
BEGIN	sym := Ident;
	i := 0;
	WHILE ((CAP(ch) >= 'A') & (CAP(ch) <= 'Z')) OR ((ch >= '0') & (ch <= '9')) DO
		IF i < idlen THEN ident[i] := ch; INC (i) END;
		ReadChar
	END;
	WHILE ch = '.' DO	sym := Qualident;
		IF i < idlen THEN ident[i] := ch; INC (i) END;
		ReadChar;
		WHILE ((CAP(ch) >= 'A') & (CAP(ch) <= 'Z')) OR ((ch >= '0') & (ch <= '9')) DO
			IF i < idlen THEN ident[i] := ch; INC (i) END;
			ReadChar
		END;
	END;
	IF i = idlen THEN Mark (Pos (), "Identifier too long"); ident[i-1] := 0X ELSE ident[i] := 0X END;
END ReadIdent;

PROCEDURE Get* (VAR sym : SIGNED16);
BEGIN
	IF eot THEN Mark (Pos (), "end of text") END;
	WHILE (ch <= ' ') & (~eot) DO ReadChar END;
	CASE ch OF
	| 0X : ReadChar; sym := End
	| '[' : ReadChar; sym := lbrak
	| ']' : ReadChar; sym := rbrak
	| '-' : ReadChar; IF (ch >= '0') & (ch <= '9') THEN ReadNumber (sym); int := -int; real := -real
								ELSE Mark (Pos (), "number expected") END
	| '=' : ReadChar; sym := equal
	| '{' : Comment; Get (sym)
	| '"', "'" : ReadString (sym)
	| '#' : ReadChar; sym := Char; char := ch; ReadChar
	| '0'..'9' : ReadNumber (sym)
	| 'A' : ReadIdent (sym);	IF (ident = "ATTR") OR (ident = "ATTRIBUTES") THEN sym := Attributes END
	| 'B' : ReadIdent (sym);	IF ident = "BREAK" THEN sym := Break
											ELSIF ident = "BOTTOM" THEN sym := Bottom END
	| 'C' : ReadIdent (sym);	IF ident = "CONTENTS" THEN sym := Contents
											ELSIF ident = "CONFIG" THEN sym := Config
											ELSIF ident = "CENTER" THEN sym := Center END
	| 'D' : ReadIdent (sym);	IF ident = "DYNAMIC" THEN sym := Dynamic
											ELSIF ident = "DCOPY" THEN sym := Deep
											ELSIF ident = "DEFAULT" THEN sym := Default
											ELSIF ident = "DEF" THEN sym := Def END
	| 'E' : ReadIdent (sym);	IF ident = "END" THEN sym := End END
	| 'F' : ReadIdent (sym);	IF ident = "FALSE" THEN sym := Bool; bool := FALSE END
	| 'H' : ReadIdent (sym);	IF ident = "HLIST" THEN sym := HList
											ELSIF ident = "HOR" THEN sym := Hor END
	| 'I' : ReadIdent (sym);	IF ident = "INCLUDE" THEN sym := Include END
	| 'L' : ReadIdent (sym);	IF ident = "LINKS" THEN sym := Links
											ELSIF ident = "LAYOUT" THEN sym := Layout
											ELSIF ident = "LEFT" THEN sym := Left END
	| 'N' : ReadIdent (sym);	IF ident = "NEW" THEN sym := New END
	| 'P' : ReadIdent (sym);	IF ident = "PLACE" THEN sym := Place
											ELSIF ident = "PARAMS" THEN sym := Params END
	| 'R' : ReadIdent (sym);	IF ident = "RIGHT" THEN sym := Right END;
	| 'S' : ReadIdent (sym);	IF ident = "STATIC" THEN sym := Static
											ELSIF ident = "SPAN" THEN sym := Span
											ELSIF ident = "SCOPY" THEN sym := Shallow END
	| 'T' : ReadIdent (sym);	IF ident = "TABLE" THEN sym := Table
											ELSIF ident = "TRUE" THEN sym := Bool; bool := TRUE
											ELSIF ident = "TOP" THEN sym := Top END
	| 'V' : ReadIdent (sym);	IF ident = "VIRTUAL" THEN sym := Virtual
											ELSIF ident = "VLIST" THEN sym := VList
											ELSIF ident = "VERT" THEN sym := Vert END
	| 'a'..'z', 'G', 'J', 'K', 'M', 'O', 'Q', 'U', 'W'..'Z' : ReadIdent (sym)
	ELSE sym := null; ReadChar;
	END
END Get;

PROCEDURE OpenText* (text : Texts.Text; pos : SIGNED32);
BEGIN
	Texts.OpenReader (reader, text, pos);
	ch := ' ';
	errpos := pos;
	eot := FALSE;
END OpenText;

PROCEDURE Init*;
BEGIN
	error := FALSE;
END Init;

BEGIN
	Texts.OpenWriter (W);
END LayLa2S.
