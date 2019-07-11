MODULE FoxTextualSymbolFile; (** AUTHOR "fof & fn"; PURPOSE "Oberon Compiler: Symbolfile in- and output"; *)
(* (c) fof ETH Zürich, 2008 *)

IMPORT
	D := Debugging, Basic := FoxBasic,  Scanner := FoxScanner, SyntaxTree := FoxSyntaxTree, Global := FoxGlobal, Formats := FoxFormats, Files,Streams,
	Printout := FoxPrintout,Parser:= FoxParser , SemanticChecker := FoxSemanticChecker, InterfaceComparison := FoxInterfaceComparison, Options;

CONST Trace = FALSE;

TYPE
	TextualSymbolFile = OBJECT (Formats.SymbolFileFormat)
	VAR extension: Basic.FileName; noRedefinition, noModification: BOOLEAN;

		PROCEDURE Import*(CONST moduleFileName: ARRAY OF CHAR; importCache: SyntaxTree.ModuleScope): SyntaxTree.Module;
		VAR fileName: Files.FileName; module: SyntaxTree.Module; reader: Streams.Reader; scanner: Scanner.Scanner; parser: Parser.Parser;
			checker: SemanticChecker.Checker;
		BEGIN
			Basic.Concat(fileName,path,moduleFileName,extension);
			IF Trace THEN D.Ln; D.Str("importing "); D.Str(fileName); D.Ln; D.Update;  END;
			module := NIL;
			reader := Basic.GetFileReader(fileName);
			IF reader # NIL THEN
				scanner := Scanner.NewScanner(fileName, reader, reader.Pos(), diagnostics);
				IF ~scanner.error THEN
					parser := Parser.NewParser(scanner,diagnostics, "");
					module := parser.Module();
					IF parser.error THEN module := NIL END;
				END;
			END;
			IF (module # NIL) & ~(SyntaxTree.Resolved IN module.state) & (module.parameters = NIL) THEN
				(*! should rather be done by importer *)
				checker := SemanticChecker.NewChecker(diagnostics,FALSE,TRUE,system,SELF,importCache,"");
				checker.Module(module); (* semantic check *)
				IF checker.error THEN module := NIL END;
			END;

			RETURN module
		END Import;

		PROCEDURE Export*(module: SyntaxTree.Module; importCache: SyntaxTree.ModuleScope): BOOLEAN;
		VAR moduleName,fileName: Basic.FileName; writer: Files.Writer; file: Files.File; printer: Printout.Printer; result: BOOLEAN;flags: SET;
		BEGIN
			Global.ModuleFileName(module.name,module.context,moduleName);
			Basic.Concat(fileName,path,moduleName,extension);
			IF Trace THEN D.Ln; D.Str("exporting"); D.Str(fileName); D.Ln; D.Update;  END;

			file := Files.New(fileName);
			IF file = NIL THEN
				Basic.Error(diagnostics, module.sourceName, Basic.invalidPosition,  "could not open export file for writing");
				result := FALSE;
			ELSE

				flags := {};
				
				IF module.parameters = NIL THEN
					InterfaceComparison.CompareThis(module,SELF,diagnostics,importCache,flags);
				END;
				
				IF noRedefinition OR noModification THEN
					IF (InterfaceComparison.Redefined IN flags) THEN
						Basic.Error(diagnostics, module.sourceName, Basic.invalidPosition, " no redefinition of symbol file allowed");
						RETURN FALSE;
					END;
				END;
				IF noModification THEN
					IF (InterfaceComparison.Extended IN flags) THEN
						Basic.Error(diagnostics, module.sourceName,Basic.invalidPosition,  " no extension of symbol file allowed");
						RETURN FALSE;
					END;
				END;

				NEW(writer,file,0);
				IF module.parameters = NIL THEN
					printer := Printout.NewPrinter(writer, Printout.SymbolFile,FALSE);
				ELSE
					printer := Printout.NewPrinter(writer, Printout.SourceCode, FALSE);
				END;
				printer.Module(module);
				writer.Update();
				Files.Register(file);
				result := TRUE;
			END;
			RETURN result
		END Export;

		PROCEDURE DefineOptions*(options: Options.Options);
		BEGIN
			options.Add(0X,"symbolFileExtension",Options.String);
			options.Add(0X,"noRedefinition",Options.Flag);
			options.Add(0X,"noModification",Options.Flag);
		END DefineOptions;

		PROCEDURE GetOptions*(options: Options.Options);
		BEGIN
			IF ~options.GetString("symbolFileExtension",extension) THEN extension := ".Sym" END;
			noRedefinition := options.GetFlag("noRedefinition");
			noModification := options.GetFlag("noModification");
		END GetOptions;

	END TextualSymbolFile;

	PROCEDURE Get*(): Formats.SymbolFileFormat;
	VAR symbolFile: TextualSymbolFile;
	BEGIN
		NEW(symbolFile); RETURN symbolFile
	END Get;

END FoxTextualSymbolFile.
