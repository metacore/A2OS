MODULE DiffLib; (** AUTHOR "negelef"; PURPOSE "Simple text diff tool"; *)

IMPORT
	Streams, Texts, TextUtilities, Commands, Strings;

CONST
	lineBufferSize = 1000;
	maxLineSize = 256;

	dirNone = 0;
	dirLeft = 1;
	dirUp = 2;
	dirRight = 4;
	dirDown = 5;
	dirDiag = 6;

VAR
	separator: BOOLEAN;

TYPE
	LineBuffer = POINTER TO RECORD
		lines: ARRAY lineBufferSize OF SIZE;
		next: LineBuffer;
		size: SIZE;
	END;

	Element = RECORD
		val: SIZE;
		dir: INTEGER;
	END;

	Handler* = PROCEDURE {DELEGATE} (pos, line: SIZE; string: Strings.String; out : Streams.Writer);
	EmptyHandler* = PROCEDURE {DELEGATE};
	SetupHandler* = PROCEDURE {DELEGATE} (nofLines: SIZE);

	PROCEDURE GetLinePos (lineBuffer: LineBuffer; offset: SIZE): SIZE;
	BEGIN
		WHILE offset >= lineBuffer.size DO
			DEC (offset, lineBuffer.size);
			lineBuffer := lineBuffer.next;
		END;
		RETURN lineBuffer.lines[offset];
	END GetLinePos;

	PROCEDURE GetLineBuffer (reader: Texts.TextReader; VAR size: SIZE): LineBuffer;
	VAR
		first, current: LineBuffer;
		ch: SIGNED32;
	BEGIN
		NEW (first);
		current := first;
		current.size := 0;
		size := 0;

		REPEAT
			IF (current.size = lineBufferSize) THEN
				NEW (current.next);
				current := current.next;
				current.size := 0;
			END;
			current.lines[current.size] := reader.GetPosition ();
			INC (current.size);
			INC (size);
			REPEAT
				reader.ReadCh (ch);
			UNTIL reader.eot OR (ch = Texts.NewLineChar);
		UNTIL reader.eot;
		RETURN first;
	END GetLineBuffer;

	PROCEDURE ReadLine (pos: SIZE; reader: Texts.TextReader): Strings.String;
	VAR
		ch: SIGNED32; i: SIZE;
		string: Strings.String;
	BEGIN
		reader.SetPosition (pos);
		i := 0;
		NEW (string, maxLineSize + 1);
		LOOP
			reader.ReadCh (ch);
			IF reader.eot OR (ch = Texts.NewLineChar) OR (i = maxLineSize) THEN
				EXIT
			ELSE
				string[i] := CHR (ch);
				INC (i);
			END;
		END;
		string[i] := 0X;
		RETURN string;
	END ReadLine;

	PROCEDURE Diff* (
		leftFile, rightFile: ARRAY OF CHAR;
		setup: SetupHandler; leftDiff, rightDiff, leftEqual, rightEqual: Handler; emptyLeft, emptyRight: EmptyHandler;
		out : Streams.Writer);
	VAR
		leftText, rightText: Texts.Text;
		leftReader, rightReader: Texts.TextReader;
		format, res: INTEGER;
		leftBuffer, rightBuffer, left, right: LineBuffer;
		width, height : SIZE;
		table: POINTER TO ARRAY OF ARRAY OF Element;
		x, y, xv, yv: SIZE;

		PROCEDURE CompareLines (left, right: SIZE): BOOLEAN;
		VAR
			leftCh, rightCh: SIGNED32;
		BEGIN
			leftReader.SetPosition (GetLinePos (leftBuffer, left));
			rightReader.SetPosition (GetLinePos (rightBuffer, right));

			LOOP
				leftReader.ReadCh (leftCh);
				rightReader.ReadCh (rightCh);

				IF leftReader.eot & rightReader.eot THEN RETURN TRUE END;

				IF leftCh # rightCh THEN RETURN FALSE END;

				IF (leftCh = Texts.NewLineChar) OR (rightCh = Texts.NewLineChar) THEN
					RETURN leftCh = rightCh;
				END;
			END;
		END CompareLines;

	BEGIN
		NEW (leftText);
		TextUtilities.LoadAuto(leftText, leftFile, format, res);
		leftText.AcquireRead;
		NEW (leftReader, leftText);
		leftReader.SetPosition (0);

		NEW (rightText);
		TextUtilities.LoadAuto(rightText, rightFile, format, res);
		rightText.AcquireRead;
		NEW (rightReader, rightText);
		rightReader.SetPosition (0);

		leftBuffer := GetLineBuffer (leftReader, width);
		rightBuffer := GetLineBuffer (rightReader, height);
		IF setup # NIL THEN setup(width + height); END;

		NEW (table, width + 1, height + 1);

		table[0, 0].val := 0;
		table[0, 0].dir := 0;

		FOR x := 1 TO width DO
			table[x, 0].val := 0;
			table[x, 0].dir := dirLeft;
		END;

		FOR y := 1 TO height DO
			table[0, y].val := 0;
			table[0, y].dir := dirUp;
		END;

		left := leftBuffer;
		right := rightBuffer;

		FOR y := 1 TO height DO
			FOR x := 1 TO width DO
				IF CompareLines (x - 1, y - 1) THEN
					table[x, y].val := table[x - 1, y - 1].val + 1;
					table[x, y].dir := dirDiag;
				ELSE
					xv := table[x - 1, y].val;
					yv := table[x, y - 1].val;
					IF xv > yv THEN
						table[x, y].val := xv;
						table[x, y].dir := dirLeft;
					ELSE
						table[x, y].val := yv;
						table[x, y].dir := dirUp;
					END;
				END;
			END;
		END;

		(* DEC (x); DEC (y); *)
		x := width; y := height;

		WHILE (x # 0) OR (y # 0) DO
			CASE table[x, y].dir OF
			dirUp:
				DEC (y); table[x, y].val := dirDown;
			| dirLeft:
				DEC (x); table[x, y].val := dirRight;
			| dirDiag:
				DEC (x); DEC (y); table[x, y].val := dirDiag;
			END
		END;

		WHILE (x # width) OR (y # height) DO
			CASE table[x, y].val OF
			dirDown:
				INC (y); Handle (y, rightReader, rightBuffer, rightDiff, out); IF emptyLeft # NIL THEN emptyLeft; END;
			| dirRight:
				INC (x); Handle (x, leftReader, leftBuffer, leftDiff, out); IF emptyRight # NIL THEN emptyRight; END;
			| dirDiag:
				INC (x); Handle (x, leftReader, leftBuffer, leftEqual, out);
				INC (y); Handle (y, rightReader, rightBuffer, rightEqual, out);
			END
		END;
	END Diff;

	PROCEDURE Handle (line: SIZE; reader: Texts.TextReader; buffer: LineBuffer; handler: Handler; out : Streams.Writer);
	VAR
		pos: SIZE;
	BEGIN
		IF handler # NIL THEN
			pos := GetLinePos (buffer, line - 1);
			handler (pos, line, ReadLine (pos, reader), out);
		END
	END Handle;

	PROCEDURE Left (pos, line: SIZE; string: Strings.String; out : Streams.Writer);
	BEGIN
		out.String (		"< ("); out.Int (line, 0); out.Char (':');
		out.Int (pos, 0); out.String (") "); out.String (string^); out.Ln;
		separator := TRUE;
	END Left;

	PROCEDURE Right (pos, line: SIZE; string: Strings.String; out : Streams.Writer);
	BEGIN
		out.String ("> ("); out.Int (line, 0); out.Char (':');
		out.Int (pos, 0); out.String (") "); out.String (string^); out.Ln;
		separator := TRUE;
	END Right;

	PROCEDURE Equal (pos, line: SIZE; string: Strings.String; out : Streams.Writer);
	BEGIN
		IF separator THEN out.Ln; separator := FALSE END
	END Equal;

	PROCEDURE Compare* (context : Commands.Context);
	VAR
		left, right: ARRAY 64 OF CHAR;
	BEGIN
		context.arg.SkipWhitespace; context.arg.String(left);
		context.arg.SkipWhitespace; context.arg.String(right);

		context.out.String ("< "); context.out.String (left); context.out.Ln;
		context.out.String ("> "); context.out.String (right); context.out.Ln;
		context.out.Ln;

		separator := FALSE;

		Diff (left, right, NIL, Left, Right, Equal, Equal, NIL, NIL, context.out);
	END Compare;

END DiffLib.

System.Free DiffLib~
DiffLib.Compare DiffTest1.Text DiffTest2.Text~

DiffLib.Compare Configuration.XML Configuration.XML.Bk ~
