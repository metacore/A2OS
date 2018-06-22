MODULE TextConverter; (** AUTHOR "negelef"; PURPOSE "automated text format convertion"; *)

IMPORT Commands, Streams, Diagnostics, Files, Texts, TextUtilities;

TYPE Converter = PROCEDURE (text : Texts.Text; CONST filename : ARRAY OF CHAR; VAR res : WORD);

PROCEDURE Convert (diagnostics: Diagnostics.Diagnostics; list: Streams.Reader; converter: Converter);
VAR text: Texts.Text; filename: Files.FileName; format, res: LONGINT;
BEGIN
	WHILE list.GetString (filename) DO
		NEW (text);
		TextUtilities.LoadAuto (text, filename, format, res);
		IF res = 0 THEN
			converter (text, filename, res);
			IF res = 0 THEN
				diagnostics.Information (filename, Streams.Invalid, "successfully converted");
			ELSE
				diagnostics.Information (filename, Streams.Invalid, "failed to store");
			END
		ELSE
			diagnostics.Error (filename, Streams.Invalid, "failed to load");
		END;
	END;
END Convert;

(* converts the provided list of text files into the oberon format *)
PROCEDURE Oberon* (context: Commands.Context);
VAR diagnostics: Diagnostics.StreamDiagnostics;
BEGIN
	NEW (diagnostics, context.error);
	Convert (diagnostics, context.arg, TextUtilities.StoreOberonText);
END Oberon;

PROCEDURE UTF8*(context : Commands.Context);
VAR diagnostics: Diagnostics.StreamDiagnostics;
BEGIN
	NEW (diagnostics, context.error);
	Convert (diagnostics, context.arg, TextUtilities.ExportUTF8);
END UTF8;

END TextConverter.
