MODULE WhitespaceRemover; (** AUTHOR "staubesv"; PURPOSE "Remove end-of-line whitespace"; *)

IMPORT
	Commands, Options, Diagnostics, Files, Strings, Texts, TextUtilities;

CONST
	LineFeed = 0AH;

(** Removed all end-of-line whitespace from 'text' *)
PROCEDURE RemoveFromText*(text : Texts.Text; VAR nofRemoved : LONGINT);
VAR reader : Texts.TextReader; char : Texts.Char32; lastWhitespacePosition, nofWhitespaces : LONGINT;
BEGIN
	ASSERT(text # NIL);
	nofRemoved := 0;
	text.AcquireWrite;
	NEW(reader, text);
	lastWhitespacePosition := -1; (* no whitespace so far *)
	reader.ReadCh(char);
	WHILE ~reader.eot DO
		IF (char = LineFeed) THEN
			IF (lastWhitespacePosition > 0) THEN (* remove the whitespace *)
				nofWhitespaces := reader.GetPosition() - 2 - lastWhitespacePosition + 1;
				text.Delete(lastWhitespacePosition, nofWhitespaces);
				nofRemoved := nofRemoved + nofWhitespaces;
			END;
			lastWhitespacePosition := -1;
		ELSIF TextUtilities.IsWhiteSpace(char,text.isUTF) THEN
			IF (lastWhitespacePosition < 0) THEN
				lastWhitespacePosition := reader.GetPosition()-1;
			END;
		ELSE
			lastWhitespacePosition := -1;
		END;
		reader.ReadCh(char);
	END;
	text.ReleaseWrite;
END RemoveFromText;

(** Write a warning to 'diagnostics' for each end-of-line whitespace in 'text' *)
PROCEDURE CheckWhitespace*(text : Texts.Text; diagnostics : Diagnostics.Diagnostics);
VAR
	reader : Texts.TextReader; char : Texts.Char32;
	lastCharWasWhitespace : BOOLEAN;
	lastWhitespacePosition : LONGINT;
BEGIN
	ASSERT((text # NIL) & (diagnostics # NIL));
	text.AcquireRead;
	NEW(reader, text);
	reader.SetPosition(0);
	reader.SetDirection(1);
	lastCharWasWhitespace := FALSE; lastWhitespacePosition := 0;
	reader.ReadCh(char);
	WHILE ~reader.eot DO
		IF (char = LineFeed) THEN
			IF lastCharWasWhitespace THEN
				diagnostics.Warning("", lastWhitespacePosition, "Whitespace at end of line");
				lastCharWasWhitespace := FALSE;
			END;
		ELSIF TextUtilities.IsWhiteSpace(char, text.isUTF) THEN
			IF ~lastCharWasWhitespace THEN
				lastWhitespacePosition := reader.GetPosition()-1;
			END;
			lastCharWasWhitespace := TRUE;
		ELSE
			lastCharWasWhitespace := FALSE;
		END;
		reader.ReadCh(char);
	END;
	text.ReleaseRead;
END CheckWhitespace;

(** Removed all end-of-line whitespace from file named 'filename' *)
PROCEDURE RemoveFromFile*(VAR filename : Files.FileName; VAR nofRemoved: LONGINT; VAR res : WORD);
VAR file : Files.File; text : Texts.Text; format : LONGINT;
BEGIN
	file := Files.Old(filename);
	IF (file # NIL) THEN
		file.GetName(filename);
		NEW(text);
		TextUtilities.LoadAuto(text, filename, format, res);
		IF (res = 0) THEN
			RemoveFromText(text, nofRemoved);
			CASE format OF
				|0: TextUtilities.StoreOberonText(text, filename, res);
				|1: TextUtilities.StoreText(text, filename, res);
				|2: TextUtilities.ExportUTF8(text, filename, res);
			ELSE
				res := -99; (* file format not known *)
			END;
		END;
	ELSE
		res := Files.FileNotFound;
	END;
END RemoveFromFile;

(** Remove end-of-line whitespace in the specified file(s) *)
PROCEDURE Remove*(context : Commands.Context); (** [ "-v" | "--verbose" ] ( filename {" " filename} | filemask ) ~ *)
VAR
	options : Options.Options;
	mask : Files.FileName;
	enum : Files.Enumerator;
	filename : Files.FileName;
	fileflags : SET;
	time, date, size : LONGINT;
	nofRemovedTotal: LONGINT; res : WORD;
	nofFiles, nofErrors : LONGINT;

	PROCEDURE RemoveFromThisFile(VAR filename : Files.FileName);
	VAR oldFilename : Files.FileName; nofRemoved : LONGINT;
	BEGIN
		nofRemoved := 0;
		IF options.GetFlag("verbose") THEN
			COPY(filename, oldFilename);
			context.out.String(filename); context.out.String(" ... "); context.out.Update;
		END;
		RemoveFromFile(filename, nofRemoved, res);
		IF (res = 0) THEN
			IF options.GetFlag("verbose") THEN
				IF (filename # oldFilename) THEN
					context.out.String(filename); context.out.String(": ");
				END;
				context.out.Int(nofRemoved, 0); context.out.String(" removed");
				context.out.Ln; context.out.Update;
			END;
			nofRemovedTotal := nofRemovedTotal + nofRemoved;
			INC(nofFiles);
		ELSE
			nofRemoved := 0;
			INC(nofErrors);
			context.error.String("Error in file "); context.error.String(filename); context.error.String(", res: ");
			context.error.Int(res, 0); context.error.Ln;
			context.error.Update;
		END;
	END RemoveFromThisFile;

BEGIN
	NEW(options);
	options.Add("v", "verbose", Options.Flag);
	IF options.Parse(context.arg, context.error) THEN
		IF context.arg.GetString(mask) THEN
			nofRemovedTotal := 0; nofFiles := 0; nofErrors := 0;
			IF Strings.ContainsChar(mask, "?", FALSE) OR Strings.ContainsChar(mask, "*", FALSE) THEN
				IF options.GetFlag("verbose") THEN
					context.out.String("Removing end-of-line whitespace in "); context.out.String(mask); context.out.String("... ");
					context.out.Ln; context.out.Update;
				END;
				NEW(enum); enum.Open(mask, {});
				WHILE enum.GetEntry(filename, fileflags, time, date, size) DO
					IF ~(Files.Directory IN fileflags) THEN
						RemoveFromThisFile(filename);
					END;
				END;
				enum.Close;
			ELSE
				COPY(mask, filename);
				REPEAT
					RemoveFromThisFile(filename);
					filename := "";
				UNTIL ~context.arg.GetString(filename);
			END;
			IF options.GetFlag("verbose") THEN
				context.out.String("Removed "); context.out.Int(nofRemovedTotal, 0); context.out.String(" whitespaces in ");
				context.out.Int(nofFiles, 0); context.out.String(" files, ");
				context.out.Int(nofErrors, 0); context.out.String(" error(s)");
				context.out.Ln;
			END;
		ELSE
			context.out.String('Usage: Whitespace.Remove [ "-v" | "--verbose" ] ( filename {" " filename} | filemask ) ~'); context.out.Ln;
		END;
	END;
END Remove;

END WhitespaceRemover.

WhitespaceRemover.Remove -v Usbdi.Mod Texts.Mod TextUtilities.Mod ~

WhitespaceRemover.Remove -v WhitespaceRemover.Mod ~

WhitespaceRemover.Remove *.Mod ~

System.Free WhitespaceRemover ~
