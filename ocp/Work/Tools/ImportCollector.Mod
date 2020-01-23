MODULE ImportCollector; (** AUTHOR "SAGE"; PURPOSE "Utility for collecting of all imported modules for specified applications"; *)

IMPORT
	Machine, Commands, Files, Options, Strings, UTF8Strings,
	Diagnostics, ModuleParser, Generics, Zip, ZipTool, KernelLog;

CONST
	DefaultOutputFilename = "CollectedModules.zip";

TYPE

	ModulesItem = RECORD(Generics.TreeItem)
		module: ModuleParser.Module
	END;

	ModulesSet = OBJECT(Generics.Tree)
	VAR
		array: POINTER TO ARRAY OF ModulesItem;
		
		(* for speedup of Contains procedure *)
		null: ModuleParser.Module;
		
		PROCEDURE &New*;
		VAR
			pCompA, pCompB: POINTER TO ModulesItem;
		BEGIN
			NEW(pCompA);
			NEW(pCompB);
			NEW(null, NIL);
			NEW(null.ident);
			NEW(null.ident.name, 257);
			NewTree(SIZEOF(ModulesItem), pCompA, pCompB, Compare)
		END New;
		
		PROCEDURE ArrayConstruct(iArraySize: LONGINT; VAR pArray: ANY; VAR addrArray: ADDRESS);
		BEGIN
			NEW(array, iArraySize); pArray := array; addrArray := ADDRESSOF(array^[0])
		END ArrayConstruct;

		PROCEDURE Compare(pA, pB: Generics.PItem): BOOLEAN;
		BEGIN
			RETURN UTF8Strings.Compare(pA^(ModulesItem).module.ident.name^,
				pB^(ModulesItem).module.ident.name^) < 0
		END Compare;
		
		PROCEDURE Insert*(module: ModuleParser.Module);
		VAR
			item: ModulesItem;
		BEGIN
			item.module := module;
			InsertInternal(item)
		END Insert;
		
		PROCEDURE Contains*(key: Strings.String): BOOLEAN;
		VAR
			item: ModulesItem;
		BEGIN
			item.module := null;
			COPY(key^, item.module.ident.name^);
			RETURN ContainsInternal(item)
		END Contains;

	END ModulesSet;

VAR
	mapRemember: Generics.ObjectMap;

PROCEDURE FileExists(CONST fileName: ARRAY OF CHAR): BOOLEAN;
VAR
	file: Files.File;
BEGIN
	file := Files.Old(fileName);
	RETURN file # NIL
END FileExists;

(* Simple heuristics that tries to find the filename of a given module name *)
PROCEDURE FindCorrectFilename(CONST path, moduleName: ARRAY OF CHAR): Files.FileName;

	PROCEDURE GenerateFilename(CONST path, prefix, moduleName: ARRAY OF CHAR): Files.FileName;
	VAR
		fileName: Files.FileName;
	BEGIN
		COPY(path, fileName);
		Strings.Append(fileName, prefix);
		Strings.Append(fileName, moduleName);
		Strings.Append(fileName, ".Mod");
		RETURN fileName
	END GenerateFilename;

VAR
	fileName: Files.FileName;
BEGIN
	fileName := GenerateFilename(path, "", moduleName);
	IF ~FileExists(fileName) THEN
		fileName := GenerateFilename(path, "I386.", moduleName);
		IF ~FileExists(fileName) THEN
			fileName := GenerateFilename(path, "Windows.", moduleName);
			IF ~FileExists(fileName) THEN
				fileName := GenerateFilename(path, "Unix.", moduleName);
				IF ~FileExists(fileName) THEN
					COPY(moduleName, fileName)
				END
			END
		END
	END;
	RETURN fileName
END FindCorrectFilename;

(* Simple heuristics that tries to find the filepath of a given module name *)
PROCEDURE FindCorrectFilepath(CONST moduleName: ARRAY OF CHAR; setModulesPaths: Generics.StringSet): Files.FileName;
VAR
	pathName: Files.FileName;
	item: Generics.StringSetItem;
BEGIN
	IF setModulesPaths.Count() = 0 THEN
		pathName := FindCorrectFilename("", moduleName)
	ELSE
		pathName := "";
		setModulesPaths.Iterator().Reset;
		WHILE ~FileExists(pathName) & setModulesPaths.Iterator().GetNext(item) DO
			pathName := FindCorrectFilename(item.key^, moduleName);
		END
	END;
	RETURN pathName
END FindCorrectFilepath;

PROCEDURE ProcessModule(context: Commands.Context; mapModules: ModulesSet; setModulesNotFound, setModulesPaths: Generics.StringSet; CONST modName: ARRAY OF CHAR);

	PROCEDURE ParseModule(CONST modName: ARRAY OF CHAR): ModuleParser.Module;
	VAR
		module: ModuleParser.Module;
		diag: Diagnostics.Diagnostics;
	BEGIN
		module := ModuleParser.ParseFile(FindCorrectFilepath(modName, setModulesPaths), diag);
		RETURN module
	END ParseModule;

	PROCEDURE ProperModuleInfo(import: ModuleParser.Import): ModuleParser.InfoItem;
	BEGIN
		IF (import.alias # NIL) & (import.alias.name^ # "") THEN
			RETURN import.alias
		ELSE
			RETURN import.ident
		END
	END ProperModuleInfo;

VAR
	module: ModuleParser.Module;
	import: ModuleParser.Import;
	name: Strings.String;
	info: ModuleParser.InfoItem;
BEGIN
	name := Strings.NewString(modName);
	IF Strings.EndsWith(".Mod", name^) THEN
		name^[Strings.Length(name^) - 4] := 0X
	END;
	IF (name^ = "SYSTEM") OR mapModules.Contains(name) OR setModulesNotFound.Contains(name) THEN
		RETURN
	END;
	module := ParseModule(name^);
	IF module = NIL THEN
		setModulesNotFound.Insert(name);
		RETURN
	END;
	mapModules.Insert(module);
	context.out.String("Added "); context.out.String(module.ident.name^);
	context.out.Ln; context.out.Update;
	import := module.importList;
	WHILE import # NIL DO
		info := ProperModuleInfo(import);
		IF (info # NIL) & ~mapModules.Contains(info.name) THEN
			ProcessModule(context, mapModules, setModulesNotFound, setModulesPaths, info.name^)
		END;
		IF import.next # NIL THEN
			import := import.next(ModuleParser.Import)
		ELSE
			import := NIL
		END
	END
END ProcessModule;

(* Get the list of actually imported modules *)
(*
PROCEDURE ActualImports(CONST modName: ARRAY OF CHAR);
VAR
	objModule: Modules.Module;
	res: LONGINT;
	msg: ARRAY 8 OF CHAR;
	i: LONGINT;
BEGIN
	objModule := Modules.ThisModule(modName, res, msg);
	IF (objModule # NIL) & (res = Modules.Ok) THEN
		KernelLog.Ln;
		KernelLog.String("Module: ");
		KernelLog.String(objModule.name);
		KernelLog.String(", imports: ");
		IF objModule.module # NIL THEN
			FOR i := 0 TO LEN(objModule.module) - 1 DO
				KernelLog.String(objModule.module[i].name);
				IF i # LEN(objModule.module) - 1 THEN
					KernelLog.String(", ");
				END
			END
		END;
		KernelLog.Ln
	END
END ActualImports;
*)

PROCEDURE Output(CONST sFileName, sRememberKey: ARRAY OF CHAR; mapModules: ModulesSet; setModulesNotFound, setModulesExcludes: Generics.StringSet): BOOLEAN;
VAR
	archive: Zip.Archive;
	res: LONGINT;
	outputFilename: Files.FileName;
	setRem: Generics.StringSet;
	item: ModulesItem;
	sysextension: ARRAY 6 OF CHAR;
BEGIN

	Machine.GetConfig("ObjectFileExtension", sysextension);
	IF sysextension = "" THEN
		COPY(Machine.DefaultObjectFileExtension, sysextension)
	END;
	KernelLog.String(sysextension); KernelLog.Ln;

	setRem := NIL;
	IF sRememberKey # "" THEN
		IF mapRemember.ContainsAOC(sRememberKey) THEN
			setRem := mapRemember.GetAOC(sRememberKey)(Generics.StringSet);
			setRem.Clear
		ELSE
			NEW(setRem);
			mapRemember.InsertAOC(sRememberKey, setRem)
		END
	END;

	archive := Zip.CreateArchive(sFileName, res);
	IF (archive # NIL) & (res = Zip.Ok) THEN
		mapModules.Iterator().Reset;
		WHILE mapModules.Iterator().GetNext(item) DO
			IF ~setModulesExcludes.Contains(item.module.ident.name) THEN

				(** TODO: Implement more robust generation of file name
					as in Modules.ThisModule. Or propose ETHZ to add real
					file name as field to Modules.Module *)
				COPY(item.module.ident.name^, outputFilename);
				Strings.Concat(outputFilename, sysextension, outputFilename);

				ZipTool.AddFile(archive, outputFilename, outputFilename,
					Zip.BestCompression, Zip.DefaultStrategy, res);

				IF res = Zip.Ok THEN
					IF setRem # NIL THEN
						setRem.InsertAOC(item.module.ident.name^)
					END
				ELSIF ~setModulesNotFound.Contains(item.module.ident.name) THEN
					setModulesNotFound.InsertAOC(item.module.ident.name^)
				END
			END
		END;
		RETURN TRUE
	END;

	RETURN FALSE
END Output;

PROCEDURE ParseSemicolonList(CONST list: ARRAY OF CHAR; set: Generics.StringSet);
VAR
	j, k: LONGINT;
	part: Files.FileName;

	PROCEDURE AddPart;
	BEGIN
		IF k > 0 THEN
			part[k] := 0X;
			IF (part # "") & ~set.ContainsAOC(part) THEN
				set.InsertAOC(part)
			END;
			k := 0
		END
	END AddPart;

BEGIN
	k := 0;
	WHILE list[j] # 0X DO
		IF list[j] = ';' THEN
			AddPart
		ELSE
			part[k] := list[j]; INC(k)
		END;
		INC(j)
	END;
	AddPart
END ParseSemicolonList;

(* Try to find references to remembered lists inside excludes *)
PROCEDURE ResolveExcludes(set: Generics.StringSet);
VAR
	sa: Strings.StringArray;
	setTemp, setRem: Generics.StringSet;
	item: Generics.StringSetItem;
BEGIN
	NEW(setTemp);
	set.Iterator().Reset;
	WHILE set.Iterator().GetNext(item) DO
		sa := Strings.Split(item.key^, ':');
		IF LEN(sa) > 1 THEN
			Strings.UpperCase(sa[0]^);
			IF (sa[0]^ = "REF") & mapRemember.Contains(sa[1]) THEN
				setRem := mapRemember.Get(sa[1])(Generics.StringSet);
				setRem.Iterator().Reset;
				WHILE setRem.Iterator().GetNext(item) DO
					setTemp.Insert(item.key)
				END
			END
		END
	END;
	setTemp.Iterator().Reset;
	WHILE setTemp.Iterator().GetNext(item) DO
		IF ~set.Contains(item.key) THEN
			set.Insert(item.key)
		END
	END
END ResolveExcludes;

PROCEDURE Collect*(context: Commands.Context); (** [options] moduleName {" " modulename} ~  *)
VAR
	mapModules: ModulesSet;
	setModulesNotFound,
	setModulesPaths,
	setModulesExcludes: Generics.StringSet;
	item: Generics.StringSetItem;
	moduleName, outputFilename: Files.FileName;
	paths, excludes, remember: ARRAY 1024 OF CHAR;
	options: Options.Options;
	bDummy: BOOLEAN;
BEGIN
	NEW(options);
	options.Add("f", "file", Options.String);
	options.Add("p", "paths", Options.String);
	options.Add("x", "excludes", Options.String);
	options.Add("r", "remember", Options.String); (* Remember results under key *)
	IF options.Parse(context.arg, context.out) THEN
		IF ~options.GetString("file", outputFilename) THEN
			COPY(DefaultOutputFilename, outputFilename)
		END;
		NEW(setModulesPaths);
		setModulesPaths.InsertAOC("");
		IF options.GetString("paths", paths) THEN
			ParseSemicolonList(paths, setModulesPaths)
		END;

		NEW(setModulesExcludes);
		IF options.GetString("excludes", excludes) THEN
			ParseSemicolonList(excludes, setModulesExcludes)
		END;

		ResolveExcludes(setModulesExcludes);

		bDummy := options.GetString("remember", remember);

		NEW(mapModules);
		NEW(setModulesNotFound);
		
		WHILE context.arg.GetString(moduleName) DO
			ProcessModule(context, mapModules, setModulesNotFound, setModulesPaths, moduleName)
		END;

		IF Output(outputFilename, remember, mapModules, setModulesNotFound, setModulesExcludes) THEN
			context.out.String("Collected modules written to "); context.out.String(outputFilename); context.out.Ln;
			IF setModulesNotFound.Count() > 0 THEN
				context.out.String("Some modules wasn't found: "); context.out.Ln;
				setModulesNotFound.Iterator().Reset;
				WHILE setModulesNotFound.Iterator().GetNext(item) DO
					context.out.String(item.key^); context.out.Ln
				END
			END
		ELSE
			context.out.String("Could not create file "); context.out.String(outputFilename); context.out.Ln
		END;
		context.out.Update

	END
END Collect;

BEGIN

	NEW(mapRemember)

END ImportCollector.

ImportCollector.Collect

	-f=ZipLoader.zip
	-p=Libs/
	-x=Kernel32;Trace;Machine;Heaps;Modules;Objects;Kernel;KernelLog;Streams;Commands;Files;WinFS;Loader;BootConsole
	-r=ZipLoaderList

	ZipLoader ~

ImportCollector.Collect

	-f=Obj.Zip
	-p=Bindings/BASS/;Libs/;Components/;Tools/;Demos/;Examples/
	-x=ref:ZipLoaderList;Kernel32;Trace;Machine;Heaps;Modules;Objects;Kernel;KernelLog;Streams;Commands;Files;WinFS;Loader;BootConsole

	WinStarter WMBass3DTest WMBassDSPTest WMRaycaster
	WMRaycasterMaze WMAStar WMFM WMColorLines WMAAGraphicsExample

	DisplayNull Traps FileTrapWriter FSTools RelativeFileSystem
	WMOTFonts WMOberonFonts	Clipboard Autostart
  SkinEngine PNGDecoder BMPCodec Tar ~

ImportCollector.Collect

	-p=Bindings/BASS/;Libs/;Components/;Tools/;Demos/;Examples/
	-x=ref:ZipLoaderList;Kernel32;Trace;Machine;Heaps;Modules;Objects;Kernel;KernelLog;Streams;Commands;Files;WinFS;Loader;BootConsole

	WMAAGraphicsExample

	WinStarter DisplayNull Traps FileTrapWriter SystemVersion PNGDecoder ~


System.Free ImportCollector ~


