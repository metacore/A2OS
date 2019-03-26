MODULE XMLGeneratorSchema;	(** Stefan Walthert  *)
(** AUTHOR "swalthert"; PURPOSE "XCCS: XML Component Configuration Schema"; *)

IMPORT
	Modules, KernelLog, XMLObjects, XML, XMLScanner, XMLParser, Files;

PROCEDURE OpenGeneratorSchema*(CONST xgsName: ARRAY OF CHAR): XML.ElementRegistry;
VAR xgsFile: Files.File; scanner: XMLScanner.Scanner; parser: XMLParser.Parser; doc: XML.Document;
	root: XML.Element; name, moduleName, procedureName, generator, elementName: XML.String; contents: XMLObjects.Enumerator; content: ANY;
	module: Modules.Module; generatorProc : XML.GeneratorProcedure;
	res: WORD; i: LONGINT; msg: ARRAY 1024 OF CHAR; er: XML.ElementRegistry;
	reader: Files.Reader;
BEGIN
	xgsFile := Files.Old(xgsName);
	IF xgsFile = NIL THEN RETURN NIL END;
	NEW(reader, xgsFile, 0);
	NEW(scanner, reader); NEW(parser, scanner);
	doc := parser.Parse();
	root := doc.GetRoot();
	name := root.GetName();
	IF name^ = "generator-schema" THEN
		contents := root.GetContents();
		NEW(er);
		WHILE contents.HasMoreElements() DO
			content := contents.GetNext();
			IF content IS XML.Element THEN
				generator := content(XML.Element).GetAttributeValue("generator");
				IF generator # NIL THEN
					NEW(moduleName, LEN(generator));
					i := 0;
					WHILE (i < LEN(moduleName) - 1) & (generator[i] # '.') DO
						moduleName[i] := generator[i]; INC(i)
					END;
					moduleName[i] := 0X; INC(i);
					module := Modules.ThisModule(moduleName^, res, msg);
					IF module # NIL THEN
						NEW(procedureName, LEN(generator));
						res := i;
						WHILE i < LEN(procedureName) - 1 DO
							procedureName[i - res] := generator[i]; INC(i)
						END;
						procedureName[i - res] := 0X;
						elementName := content(XML.Element).GetName();
						GETPROCEDURE(moduleName^, procedureName^, generatorProc);
						IF (generatorProc # NIL) THEN
							er.RegisterElement(elementName^, generatorProc)
						ELSE
							KernelLog.Enter; KernelLog.String('Procedure  "');
							KernelLog.String(name^); KernelLog.String('" not found'); KernelLog.Exit
						END
					ELSE
						KernelLog.Enter; KernelLog.String('Module "'); KernelLog.String(name^); KernelLog.String('" not found'); KernelLog.Exit
					END
				ELSE
					KernelLog.Enter; KernelLog.String("generator attribute not specified ('generator = "); KernelLog.Char(22X);
					KernelLog.String("Module.Generator"); KernelLog.Char(22X); KernelLog.String("')"); KernelLog.Exit
				END
			END
		END
	ELSE
		KernelLog.String("wrong document name: '"); KernelLog.String(name^); KernelLog.String("' instead of 'generator-schema'");
	END;
	RETURN er
END OpenGeneratorSchema;

END XMLGeneratorSchema.
