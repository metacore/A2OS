MODULE ImportGraph; (** AUTHOR "SAGE"; PURPOSE "Utility for generation of import graphs in Graphviz (http://www.graphviz.org/) DOT format"; *)

IMPORT
	Commands, Files, Options, Codecs, Streams, Strings, UTF8Strings,
	Diagnostics, ModuleParser, Generics, Modules, KernelLog;

CONST
	DefaultOutputFilename = "ImportGraph.dot";

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
	
PROCEDURE ParseModule(CONST modName: ARRAY OF CHAR): ModuleParser.Module;
VAR
	module: ModuleParser.Module;
	diag: Diagnostics.Diagnostics;
BEGIN
	IF ~Strings.EndsWith(".Mod", modName) & (modName # "SYSTEM") THEN
		module := ModuleParser.ParseFile(Strings.ConcatToNew(modName, ".Mod")^, diag)
	ELSE
		module := ModuleParser.ParseFile(modName, diag)
	END;
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

PROCEDURE ProcessModule(context: Commands.Context; modules: ModulesSet; setModulesNotFound: Generics.StringSet; CONST modName: ARRAY OF CHAR);
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
	IF modules.Contains(name) OR setModulesNotFound.Contains(name) THEN
		RETURN
	END;
	module := ParseModule(name^);
	IF module = NIL THEN
		setModulesNotFound.Insert(name);
		RETURN
	END;
	modules.Insert(module);
	context.out.String("Added "); context.out.String(module.ident.name^);
	context.out.Ln; context.out.Update;
	import := module.importList;
	WHILE import # NIL DO
		info := ProperModuleInfo(import);
		IF (info # NIL) & ~modules.Contains(info.name) THEN
			ProcessModule(context, modules, setModulesNotFound, info.name^)
		END;
		IF import.next # NIL THEN
			import := import.next(ModuleParser.Import)
		ELSE
			import := NIL
		END
	END
END ProcessModule;

(* Get the list of actually imported modules *)
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

PROCEDURE Output(stream: Streams.Writer; modules: ModulesSet; setModulesNotFound: Generics.StringSet);

	PROCEDURE OutputName(n: Strings.String);
	BEGIN
		stream.String('"');
		stream.String(n^);
		stream.String('"')
	END OutputName;

	PROCEDURE OutputLink(from, to: Strings.String);
	BEGIN
		OutputName(from);
		stream.String("->");
		OutputName(to);
		stream.String("; ")
	END OutputLink;

VAR
	item: ModulesItem;
	itemSet: Generics.StringSetItem;
	import: ModuleParser.Import;
	info: ModuleParser.InfoItem;

BEGIN
	stream.String('strict digraph G{');
	stream.Ln;
	modules.Iterator().Reset;
	WHILE modules.Iterator().GetNext(item) DO
		ActualImports(item.module.ident.name^);
		OutputName(item.module.ident.name);
		IF item.module.FindImport("SYSTEM") # NIL THEN
			stream.String(' [fontcolor = red]; ')
		ELSE
			stream.String('; ')
		END;
		import := item.module.importList;
		WHILE import # NIL DO
			info := ProperModuleInfo(import);
			IF info # NIL THEN
				OutputLink(item.module.ident.name, info.name)
			END;
			IF import.next # NIL THEN
				import := import.next(ModuleParser.Import)
			ELSE
				import := NIL
			END
		END
	END;
	setModulesNotFound.Iterator().Reset;
	WHILE modules.Iterator().GetNext(itemSet) DO
		OutputName(itemSet.key);
		stream.String(' [shape = plaintext]; ')
	END;
	stream.String('}');
	stream.Ln;
	stream.Update;
END Output;

PROCEDURE Generate*(context: Commands.Context); (** [options] moduleName {" " modulename} ~  *)
VAR
	modules: ModulesSet;
	setModulesNotFound: Generics.StringSet;
	moduleName, outputFilename: Files.FileName;
	options: Options.Options;
	stream: Streams.Writer;

BEGIN
	NEW(options);
	options.Add("f", "file", Options.String);
	IF options.Parse(context.arg, context.out) THEN
		IF ~options.GetString("file", outputFilename) THEN
			COPY(DefaultOutputFilename, outputFilename);
		END;
		stream := Codecs.OpenOutputStream(outputFilename);
		IF (stream # NIL) THEN

			NEW(modules);
			NEW(setModulesNotFound);

			WHILE context.arg.GetString(moduleName) DO
				ProcessModule(context, modules, setModulesNotFound, moduleName)
			END;

			Output(stream, modules, setModulesNotFound);

			context.out.String("Graph description written to "); context.out.String(outputFilename); context.out.Ln;
		ELSE
			context.out.String("Could not create file "); context.out.String(outputFilename); context.out.Ln;
		END;
	END;
END Generate;

BEGIN

END ImportGraph.

ImportGraph.Generate -f=ImportGraphContainers.dot Containers ~

ImportGraph.Generate -f=ImportGraphWMWindowManager.dot WMWindowManager ~
ImportGraph.Generate -f=ImportGraphImportGraph.dot ImportGraph ~

ImportGraph.Generate -f=ImportGraphWebBrowser.dot WebBrowser ~

Import graph of all components (generator procedure present):
ImportGraph.Generate -f=ImportGraphWMStringGrids.dot 
	WMStringGrids~
ImportGraph.Generate -f=ImportGraphWMTextView.dot 
	WMTextView ~

ImportGraph.Generate -f=ImportGraphWMEditors.dot 
	WMEditors ~

System.Free ImportGraph ~
