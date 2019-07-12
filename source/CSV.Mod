MODULE CSV;
(**
	AUTHOR
		"pb" 2009-10-19;
	PURPOSE
		"Read and Write CSV (comma separated value files)";
	LIMITATIONS
		"Current limitations are:
			- empty fields need to be put in quotes to be recognised
			- escape character is not handled
				- therefore only limited quoting is supported inside a string (for 2 quote chars, only one can occur inside a string)
		";
*)

IMPORT
	Streams, Files, Strings;

CONST
	CR = 0DX;  LF = 0AX;  TAB = 9X;  SP = 20X;

TYPE
	Field* = OBJECT
	VAR next-: Field; string*: Strings.String;
	END Field;

	Line* = OBJECT
	VAR next-: Line; fields-: Field;
	END Line;

	(**
		Responsible for scanning a Stream and interpreting it in CSV format

		Configuration is passed via the File:
			- Field separator character
			- Quoting Characters
			- Escape Character

		Scan: The function for scanning the whole file. Scans the content of the stream into the file passed to Init.
		ScanLine or ScanField just scan a line or a field.
	*)
	Scanner* = OBJECT
	VAR
		r: Streams.Reader;
		buf: Strings.Buffer;
		bufw: Streams.Writer;
		csvFile: CSV;

		(** *)
		PROCEDURE &Init*(file: CSV; r: Streams.Reader);
		VAR
		BEGIN
			ASSERT(file # NIL);
			ASSERT(r # NIL);
			SELF.csvFile := file;
			SELF.r := r;
		END Init;

		(** *)
		PROCEDURE Scan*;
		BEGIN
			WHILE r.res # Streams.EOF DO ScanLine(); END;
		END Scan;

		(** *)
		PROCEDURE ScanLine*;
		BEGIN
			(* Scan fields until EOL is returned *)
			r.SkipWhitespace();
			(* Ensure that there is at least 1 line *)
			csvFile.NewLine();
			WHILE ~r.EOLN() DO ScanField(); END;
		END ScanLine;

		(** *)
		PROCEDURE ScanField*;
		VAR ch, quote, usedQuote: CHAR; fieldLength: SIZE; str: Strings.String;
		BEGIN
			IF buf = NIL THEN NEW(buf, 128); END;
			IF bufw = NIL THEN bufw := buf.GetWriter(); END;

			r.SkipWhitespace();
			quote := 0X;
			usedQuote := 0X;
			fieldLength := 0;
			(* scan char by char and handle it appropriately *)
			LOOP
				ch := r.Peek();
				IF ((ch = csvFile.separator) OR r.EOLN() OR IsWhiteSpace(ch)) & (quote = 0X) OR (ch = 0X) THEN EXIT; END;
				ch := r.Get();
				IF (quote = 0X) & Strings.ContainsChar(csvFile.quoteChars^, ch, FALSE) & (fieldLength = 0) THEN
					(* Only accept the first character of the field to be a quote, later quote characters are not handled as such *)
					quote := ch;
				ELSIF (quote # 0X) & (ch = quote) THEN
					quote := 0X;
					usedQuote := ch;
				ELSE
					bufw.Char(ch);
					INC(fieldLength);
				END;
			END;
			(* Consume up to the next separator ? *)
			IF IsWhiteSpace(ch) & ~r.EOLN() & (quote = 0X) THEN
				WHILE (ch # csvFile.separator) & (r.res = Streams.Ok) DO
					ch := r.Get(); ch := r.Peek();
				END;
			END;
			ch := r.Get();
			ASSERT(fieldLength = buf.GetLength());

			(* add the field to the list of the line *)
			(* Ensure that there is at least 1 line *)
			IF csvFile.lines = NIL THEN csvFile.NewLine(); END;
			str := buf.GetString();
			IF (str^ # "") OR (usedQuote # 0X) THEN
				csvFile.AddField(str^);
			END;
			buf.Clear();
		END ScanField;
	END Scanner;

	CSV* = OBJECT
	VAR
		separator-: CHAR;			(** Character for separating the CSV fields *)
		escaper-: CHAR;				(** Escape character to escape quotes inside a quoted string *)
		quoteChars-: Strings.String;	(** List of quote characters *)
		lines-: Line;					(** Lines in the CSV file (linked list) *)
		curLine: Line;				(** Current line for fast appending *)
		curField: Field;				(** Current field for fast appending *)

		(** separator and escaper are not allowed to be the same. This holds also for quoting characters. *)
		PROCEDURE &Init*(CONST separator, escaper: CHAR; CONST quotes: ARRAY OF CHAR);
		VAR quotesEmpty: BOOLEAN; i, j: SIZE;
		BEGIN
			ASSERT(separator # escaper);
			SELF.separator := separator;
			SELF.escaper := escaper;

			quotesEmpty := quotes = "";
			NEW(quoteChars, LEN(quotes) - Strings.Count(quotes,separator) - Strings.Count(quotes,escaper));
			j := 0;
			FOR i := 0 TO LEN(quotes) - 1 DO
				IF (quotes[i] # separator) & (quotes[i] # escaper) THEN
					quoteChars[j] := quotes[i];
					INC(j);
				END;
			END;
			ASSERT(quoteChars^ = quotes);
		END Init;

		(** *)
		PROCEDURE NewLine*;
		BEGIN
			IF lines = NIL THEN
				NEW(lines); curLine := lines;
			ELSE
				(* make sure we are at the last line *)
				WHILE curLine.next # NIL DO curLine := curLine.next; END;
				NEW(curLine.next); curLine := curLine.next;
			END;
		END NewLine;

		(** *)
		PROCEDURE AddField*(CONST str: ARRAY OF CHAR);
		BEGIN
			IF lines = NIL THEN NewLine(); END;
			IF curLine.fields = NIL THEN
				NEW(curLine.fields); curField := curLine.fields;
			ELSE
				(* make sure we are at the last field of the current line *)
				WHILE curField.next # NIL DO curField := curField.next; END;
				NEW(curField.next); curField := curField.next;
			END;
			curField.string := Strings.NewString(str);
		END AddField;

		(**
			A string in the CSV file needs to be quoted if
				- it contains the field separation character
				- it contains one or more quote characters itself
				- it contains white space (as white space is otherwise skipped)
		*)
		PROCEDURE NeedsQuotes*(CONST str:  ARRAY OF CHAR): BOOLEAN;
		VAR i: SIZE;
		BEGIN
			IF str = "" THEN RETURN TRUE; END;
			FOR i := 0 TO LEN(str) - 1 DO
				IF IsWhiteSpace(str[i]) THEN
					RETURN TRUE;
				ELSE
					IF (str[i] = SELF.separator) OR Strings.ContainsChar(SELF.quoteChars^, str[i], TRUE) THEN
						RETURN TRUE;
					END;
				END;
			END;
			RETURN FALSE;
		END NeedsQuotes;

		(**
			Return the quote character that can be used to quote the string.
				- Does not work if all possible quoting chars are used in the string
					-> TODO: resort to use escape character, but requires also escape character to be escaped!
		*)
		PROCEDURE GetUnusedQuote*(CONST str: ARRAY OF CHAR): CHAR;
		VAR i: SIZE;
		BEGIN
			FOR i := 0 TO LEN(SELF.quoteChars) - 1 DO
				IF ~Strings.ContainsChar(str, SELF.quoteChars[i], TRUE) THEN
					RETURN SELF.quoteChars[i];
				END;
			END;
			HALT(1234); (* should never be reached unless there are all quote chars used already - no escaping yet! *)
			RETURN 0X;
		END GetUnusedQuote;

		(** *)
		PROCEDURE Write*(out: Streams.Writer);
		VAR l: Line; f: Field; quote: CHAR;
		BEGIN
			l := SELF.lines;
			WHILE l # NIL DO
				f := l.fields;
				WHILE f # NIL DO
					IF f # l.fields THEN out.Char(SELF.separator); END;
					IF NeedsQuotes(f.string^) THEN
						quote := GetUnusedQuote(f.string^);
						out.Char(quote);
						(* TODO: Escape all quote characters in string and of course also occuring escape characters *)
						out.String(f.string^);
						out.Char(quote);
					ELSE
						out.String(f.string^);
					END;
					f := f.next;
				END;
				IF l.fields # NIL THEN out.Ln(); END;
				l := l.next;
			END;
		END Write;
	END CSV;

	(** *)
	PROCEDURE IsWhiteSpace*(CONST ch: CHAR): BOOLEAN;
	BEGIN
		CASE ch OF
			| SP, TAB, LF, CR: RETURN TRUE;
		ELSE
			RETURN FALSE;
		END;
	END IsWhiteSpace;

	(** *)
	PROCEDURE ContainsWhitespace*(CONST str: ARRAY OF CHAR): BOOLEAN;
	VAR i: SIZE;
	BEGIN
		FOR i := 0 TO LEN(str) - 1 DO
			IF IsWhiteSpace(str[i]) THEN RETURN TRUE; END;
		END;
		RETURN FALSE;
	END ContainsWhitespace;

	(** *)
	PROCEDURE GetDefaultCSV*(): CSV;
	VAR quotes: ARRAY 3 OF CHAR; csv: CSV;
	BEGIN
		quotes[0] := '"';
		quotes[1] := "'";
		quotes[2] := 0X;
		NEW(csv, ",", "\", quotes);
		RETURN csv;
	END GetDefaultCSV;

	(** Read the content of a (CSV) file system file and interpret it as CSV file content  *)
	PROCEDURE ScanFromFileName*(CONST fn: ARRAY OF CHAR; VAR csv: CSV);
	VAR f: Files.File; r: Files.Reader; s: Scanner;
	BEGIN
		IF csv # NIL THEN
			f := Files.Old(fn);
			IF f # NIL THEN
				Files.OpenReader(r, f, 0);
				NEW(s, csv, r);
				s.Scan();
			END;
		END;
	END ScanFromFileName;

	(** Append the csv content to a File of the file system. *)
	PROCEDURE AppendCSVToFileName*(CONST fn: ARRAY OF CHAR; CONST csv: CSV);
	VAR f: Files.File; w: Files.Writer;
	BEGIN
		IF csv # NIL THEN
			f := Files.Old(fn);
			IF f = NIL THEN f := Files.New(fn); END;
			Files.OpenWriter(w, f, f.Length());
			csv.Write(w);
			w.Update();
			Files.Register(f);
		END;
	END AppendCSVToFileName;

	(** *)
	PROCEDURE CompareCSVs*(a, b: CSV): BOOLEAN;
	VAR la, lb: Line; fa, fb: Field; res: BOOLEAN;
	BEGIN
		res := TRUE;
		la := a.lines;
		lb := b.lines;
		WHILE (la # NIL) & (lb # NIL) & res DO
			fa := la.fields;
			fb := lb.fields;
			WHILE (fa # NIL) & (fb # NIL) & res DO
				res := (fa.string # NIL) & (fb.string # NIL);
				IF res THEN
					res := fa.string^ = fb.string^;
				END;
				fa := fa.next;
				fb := fb.next;
			END;
			la := la.next;
			lb := lb.next;
		END;
		res := res & (fa = NIL) & (fb = NIL) & (la = NIL) & (lb = NIL);
		RETURN res;
	END CompareCSVs;

END CSV.

