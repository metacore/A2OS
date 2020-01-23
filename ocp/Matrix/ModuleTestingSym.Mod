MODULE ModuleTestingSym; (** AUTHOR "Patrick Hunziker"; PURPOSE "automated module testing of modules and procedures with {TEST} flag"; *)
(*can also do without TestSuite if standalone is necessary*)

IMPORT Strings, Modules, Files, Streams, Commands, Options, Diagnostics, TestSuite;

CONST 
	LabeledProcTest* =2;

TYPE AddItemProcedure=	PROCEDURE {DELEGATE}(itemType, testType: INTEGER;  CONST name: ARRAY OF CHAR; success: BOOLEAN);
TYPE AssessCommandProc=PROCEDURE (CONST modName,procName:ARRAY OF CHAR; log:Streams.Writer; addItem:AddItemProcedure);

VAR tester: TestSuite.Tester;

(** Check a path for Symbol Files, identify procedures labeled with {FLAG}, test them, and optionally write the results to a TestSuite.Tester object *)
PROCEDURE ModuleTest*(context:Commands.Context); 
VAR path, extension, testerName: Files.FileName;
	options:Options.Options;
	diag:Diagnostics.Diagnostics;
	log:Streams.Writer;
BEGIN
	NEW(options); 
		options.Add("t","Tester",Options.String);
		options.Add("l","Log",Options.Flag);
	IF options.Parse(context.arg, context.error) & options.GetString("Tester",testerName) THEN  (*! TBD: connect to Tester object from other testing strategies*)
		NEW(diag);
		NEW(tester,diag);
	END;
	IF options.GetFlag("Log") THEN log:=context.out END;
	IF context.arg.GetString(path) & context.arg.GetString(extension) THEN
		IF tester#NIL THEN	EnumerateSymbolFiles(context, path, extension, log, tester.AddItem, AssessCommand);
		ELSE EnumerateSymbolFiles(context, path, extension, log, NIL, AssessCommand);
		END;
	ELSE
		HALT(200)
	END;
END ModuleTest;

PROCEDURE AssessCommand(CONST modName,procName:ARRAY OF CHAR; log:Streams.Writer; addItem: AddItemProcedure);
VAR fullName, msg: ARRAY 256 OF CHAR; res:INTEGER;
BEGIN
	COPY(modName, fullName); Strings.Append(fullName, "."); Strings.Append(fullName, procName);
	IF log#NIL THEN log.String("testing "); log.String(fullName); log.String(": "); log.Update; END;
	Commands.Activate(fullName,NIL,{Commands.Wait},res,msg);
	IF log#NIL THEN log.String(msg); log.Int(res,6); log.Ln; log.Update; END;
	
	IF addItem#NIL THEN addItem(TestSuite.Test, LabeledProcTest, fullName, res=0) END; (*optional integration with TestSuite.Mod *)
END AssessCommand;

PROCEDURE EnumerateSymbolFiles(context:Commands.Context; CONST path,extension:ARRAY OF CHAR; log:Streams.Writer; addItem: AddItemProcedure; testProcEnum: AssessCommandProc);
VAR e:Files.Enumerator; size:Files.Size; flags:SET; time, date: SIGNED32; pos:SIZE;
	mask, fileName:Files.FileName; 
	f:Files.File; r:Files.Reader;
BEGIN
	COPY(path,mask); Strings.Append(mask,extension);
	NEW(e); e.Open(mask, {});
	WHILE e.HasMoreEntries() & e.GetEntry(fileName,flags,time,date,size) DO
		pos:=Strings.Pos(extension,fileName); 
		f:=Files.Old(fileName);
		Files.OpenReader(r,f,0);
		EnumerateTestCommands(log, addItem, r, testProcEnum);
	END;
END EnumerateSymbolFiles;

PROCEDURE EnumerateTestCommands(log:Streams.Writer; addItem:AddItemProcedure; r:Streams.Reader; testProcEnum: AssessCommandProc);
VAR line, keyword, modName, procName, arrow: ARRAY 256 OF CHAR;
	leftbracket, rightbracket, modifier, pos: SIZE;
BEGIN
	WHILE r.GetString(keyword) & (r.res#Streams.Ok) & (keyword#"MODULE")DO END;
	IF r.res#Streams.Ok THEN 
		RETURN
	ELSE
		IGNORE r.GetString(modName);
		pos:=Strings.Pos(";",modName); IF pos>0 THEN modName[pos]:=0X END;
		WHILE r.res=Streams.Ok DO
			r.SkipWhitespace();
			IF r.GetString(keyword) & (keyword="PROCEDURE") & r.GetString(arrow)  THEN (*disentangle this: 	PROCEDURE ^ {TEST} Test1*; *)
				r.Ln(line);
				leftbracket:= Strings.GenericPos("{", 0, line, FALSE,FALSE);
				IF leftbracket>=0 THEN
					rightbracket:= Strings.GenericPos("}", leftbracket, line, FALSE,FALSE);
					modifier:= Strings.GenericPos("TEST", leftbracket, line, FALSE,FALSE);
					IF (modifier>leftbracket) &(modifier<rightbracket) THEN
						Strings.Delete(line,0,rightbracket+2);
						pos:=Strings.Pos("*", line); line[pos]:=0X;
						COPY(line,procName);
						testProcEnum(modName,procName, log, addItem);
					END;
				END;
			END;
		END;	
	END;
END EnumerateTestCommands;

(*
PROCEDURE Install*;
VAR f: Files.File; w:Files.Writer;
BEGIN
	NEW(registry); 
	f:=Files.Old(ModuleTestingDB);
	IF f=NIL THEN f:=Files.New(ModuleTestingDB); Files.Register(f); Files.OpenWriter(w,f,0); w.String("(* database for ModuleTesting.Mod *)"); w.Ln; w.Update; END;
	Compiler.TestModule:=registry.Register
END Install;
*)
TYPE Logger= OBJECT
	VAR w:Streams.Writer;
	PROCEDURE &Open(w:Streams.Writer); BEGIN SELF.w:=w END Open;
	PROCEDURE Write(type:INTEGER; CONST name:ARRAY OF CHAR; success:BOOLEAN);
	BEGIN
		w.Int(type,0); w.String(" "); w.String(name);
		IF success THEN w.String(" success "); ELSE w.String(" failure "); END;
		w.Ln; w.Update;
	END Write;
END Logger;

PROCEDURE ReportResults*(context:Commands.Context);
VAR logger:Logger;
BEGIN
	IF tester#NIL THEN
		NEW(logger, context.out);
		context.out.String("tests: "); context.out.Ln;
		tester.Enumerate(0, logger.Write);
		context.out.String("results: "); context.out.Ln;
		tester.Enumerate(1, logger.Write);
	END;
END ReportResults;

PROCEDURE Uninstall*;
BEGIN
END Uninstall;

BEGIN
	Modules.InstallTermHandler(Uninstall);
END ModuleTestingSym. 

System.FreeDownTo  ModuleTestingSym~
ModuleTestingSym.Install ~
ModuleTestingSym.Uninstall ~

(*test all TEST modules/procedures in symbol files in a path, logging to context and registering in TestSuite.Tester *)
ModuleTestingSym.ModuleTest -l -t=TesterFile "work/*" ".Sym" ~

(*same, but not logging to context*)
ModuleTestingSym.ModuleTest -t=TesterFile "work/*" ".Sym" ~

ModuleTestingSym.ReportResults~ 


