MODULE FoxA2Interface; (** AUTHOR ""; PURPOSE ""; *)

IMPORT Streams, Basic := FoxBasic, WMUtilities, TextUtilities, WMGraphics, Diagnostics, Texts;

CONST
	Tab = 9X;

TYPE
	Writer* = OBJECT (Basic.Writer)
	VAR
		alertCount, commentCount, keywordCount : LONGINT;

		PROCEDURE &InitA2Writer(w: Streams.Writer);
		BEGIN
			InitBasicWriter(w); alertCount := 0; commentCount := 0; keywordCount := 0;
			IF w IS TextUtilities.TextWriter THEN
				w(TextUtilities.TextWriter).SetFontName("Vera");
			END;
		END InitA2Writer;

		PROCEDURE SetFontStyle*(style: SET);
		BEGIN
			IF w IS TextUtilities.TextWriter THEN
				w(TextUtilities.TextWriter).SetFontStyle(style);
			END;
		END SetFontStyle;

		PROCEDURE SetColor;
		BEGIN
			RETURN; (* prohibitively expensive for large files *)
			IF w IS TextUtilities.TextWriter THEN
				IF alertCount > 0 THEN w(TextUtilities.TextWriter).SetFontColor(WMGraphics.Red);
				ELSIF commentCount > 0 THEN w(TextUtilities.TextWriter).SetFontColor(LONGINT(0999999FFH));
				ELSE w(TextUtilities.TextWriter).SetFontColor(WMGraphics.Black);
				END;
			END;
		END SetColor;

		PROCEDURE SetStyle;
		BEGIN
			RETURN; (* prohibitively expensive for large files *)
			IF w IS TextUtilities.TextWriter THEN
				IF keywordCount > 0 THEN w(TextUtilities.TextWriter).SetFontStyle({WMGraphics.FontBold});
				ELSE w(TextUtilities.TextWriter).SetFontStyle({});
				END;
			END;
		END SetStyle;

		PROCEDURE BeginAlert*;
		BEGIN INC(alertCount); IF alertCount = 1 THEN SetColor END;
		END BeginAlert;

		PROCEDURE EndAlert*;
		BEGIN DEC(alertCount); IF alertCount = 0 THEN SetColor END;
		END EndAlert;

		PROCEDURE BeginComment*;
		BEGIN INC(commentCount); IF commentCount = 1 THEN SetColor END;
		END BeginComment;

		PROCEDURE EndComment*;
		BEGIN DEC(commentCount); IF commentCount = 0 THEN SetColor END;
		END EndComment;

		PROCEDURE BeginKeyword*;
		BEGIN INC(keywordCount);  IF keywordCount = 1 THEN SetStyle END;
		END BeginKeyword;

		PROCEDURE EndKeyword*;
		BEGIN DEC(keywordCount); IF keywordCount = 0 THEN SetStyle END;
		END EndKeyword;

		PROCEDURE AlertString*(CONST s: ARRAY OF CHAR);
		BEGIN
			BeginAlert; w.String(s); EndAlert;
		END AlertString;

	END Writer;

	StreamDiagnostics* = OBJECT (Diagnostics.Diagnostics);
	VAR
		writer: Streams.Writer;

		PROCEDURE &Init *(w: Streams.Writer);
		BEGIN
			ASSERT(w # NIL);
			writer := w;
		END Init;

		PROCEDURE Error* (CONST source : ARRAY OF CHAR; position : Streams.Position; CONST message : ARRAY OF CHAR);
		BEGIN Print (writer, source, position, Diagnostics.TypeError, message);
		END Error;

		PROCEDURE Warning* (CONST source : ARRAY OF CHAR; position : Streams.Position; CONST message : ARRAY OF CHAR);
		BEGIN Print (writer, source, position, Diagnostics.TypeWarning, message);
		END Warning;

		PROCEDURE Information* (CONST source : ARRAY OF CHAR; position : Streams.Position; CONST message : ARRAY OF CHAR);
		BEGIN Print (writer, source, position, Diagnostics.TypeInformation, message);
		END Information;

	END StreamDiagnostics;


	PROCEDURE Print (w: Streams.Writer; CONST source : ARRAY OF CHAR; position: Streams.Position; type: WORD; CONST message: ARRAY OF CHAR);
	VAR attributes: Texts.Attributes;
	BEGIN
		IF w IS TextUtilities.TextWriter THEN
			attributes := w(TextUtilities.TextWriter).currentAttributes;
			IF (type = Diagnostics.TypeWarning) THEN
				w(TextUtilities.TextWriter).SetFontColor(LONGINT(0808000FFH));
			ELSIF (type = Diagnostics.TypeError) THEN
				w(TextUtilities.TextWriter).SetFontColor(WMGraphics.Red);
			ELSE
				w(TextUtilities.TextWriter).SetFontColor(WMGraphics.Black);
			END;
		END;
		w.Char(Tab);
		IF (source # "") THEN w.String (source); END;
		IF (position # Streams.Invalid) THEN w.Char ('@'); w.Int(position, 0); END;
		w.Char(Tab);
		IF (type = Diagnostics.TypeWarning) THEN
			w.String("warning");
		ELSIF (type = Diagnostics.TypeError) THEN
			w.String("error");
		ELSE
		END;
		IF (type # Diagnostics.TypeInformation) THEN w.String(": ") END;
		w.String(message); w.Ln;
		w.Update;
		IF attributes # NIL THEN
			w(TextUtilities.TextWriter).SetAttributes(attributes);
		END;
	END Print;

	PROCEDURE DebugWriterFactory(CONST title: ARRAY OF CHAR): Streams.Writer;
	VAR writer: WMUtilities.WindowWriter;
	BEGIN
		NEW(writer,title,600,400,FALSE); RETURN writer
	END DebugWriterFactory;

	PROCEDURE WriterFactory(w: Streams.Writer): Basic.Writer;
	VAR writer: Writer;
	BEGIN
		NEW(writer,w);
		RETURN writer
	END WriterFactory;

	PROCEDURE DiagnosticsFactory(w: Streams.Writer): Diagnostics.Diagnostics;
	VAR diagnostics: StreamDiagnostics;
	BEGIN
		NEW(diagnostics, w);
		RETURN diagnostics
	END DiagnosticsFactory;

	PROCEDURE Install*;
	BEGIN
		Basic.InstallWriterFactory(WriterFactory, DebugWriterFactory, DiagnosticsFactory);
	END Install;

END FoxA2Interface.

FSTools.DeleteFiles FoxA2Interface.Obw ~~

