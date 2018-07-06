MODULE DependencyWalker;

IMPORT Commands, Diagnostics, Files, Options, Streams, FoxBasic, FoxGlobal, FoxParser, FoxScanner, FoxSyntaxTree;

PROCEDURE Process (CONST moduleName, definitions, fileExtension: ARRAY OF CHAR; diagnostics: Diagnostics.Diagnostics; writer: Streams.Writer): BOOLEAN;
VAR reader: Streams.Reader; scanner: FoxScanner.Scanner; parser: FoxParser.Parser;
VAR module: FoxSyntaxTree.Module; import: FoxSyntaxTree.Import; string: ARRAY 64 OF CHAR;
BEGIN
	reader := FoxBasic.GetFileReader (moduleName);
	IF reader = NIL THEN diagnostics.Error (moduleName, Streams.Invalid, "Failed to open module"); RETURN FALSE END;
	scanner := FoxScanner.NewScanner (moduleName, reader, 0, diagnostics);
	NEW (parser, scanner, diagnostics, definitions);
	module := parser.Module ();
	IF parser.error THEN RETURN FALSE END;
	FoxGlobal.ModuleFileName (module.name, module.context, string);
	writer.String (string);
	writer.String (fileExtension);
	writer.String (": ");
	writer.String (moduleName);
	import := module.moduleScope.firstImport;
	WHILE import # NIL DO
		IF import.moduleName # FoxGlobal.SystemName THEN
			writer.Char (' ');
			IF import.context # FoxSyntaxTree.invalidIdentifier THEN
				FoxGlobal.ModuleFileName (import.moduleName, import.context, string);
			ELSE
				FoxGlobal.ModuleFileName (import.moduleName, module.context, string);
			END;
			writer.String (string);
			writer.String (fileExtension);
		END;
		import := import.nextImport;
	END;
	writer.Ln;
	RETURN TRUE;
END Process;

PROCEDURE Walk* (context: Commands.Context);
VAR options : Options.Options; diagnostics : Diagnostics.StreamDiagnostics;
VAR definitions, fileExtension: Options.Parameter; moduleName: Files.FileName;
BEGIN
	NEW (options);
	options.Add ('d', "define", Options.String);
	options.Add ('e', "fileExtension", Options.String);
	IF ~options.Parse (context.arg, context.error) THEN
		context.result := Commands.CommandParseError; RETURN;
	END;
	IF ~options.GetString ("define", definitions) THEN definitions := "" END;
	IF ~options.GetString ("fileExtension", fileExtension) THEN fileExtension := ".Sym" END;

	NEW (diagnostics, context.error);
	LOOP
		context.arg.SkipWhitespace;
		context.arg.String (moduleName);
		IF moduleName = "" THEN EXIT END;
		IF ~Process (moduleName, definitions, fileExtension, diagnostics, context.out) THEN
			context.result := Commands.CommandError; RETURN;
		END;
	END;
END Walk;

END DependencyWalker.
