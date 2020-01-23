MODULE PascalProjectCombine; (** AUTHOR "Yaroslav Romanchenko rapturize@gmail.com";
	PURPOSE "Tool for smart combination of all source codes of Object Pascal project"; *)

IMPORT
	Strings, Commands, Files, Streams,

	Containers, PreciseTimer, Scanner := PascalScanner;

CONST
	(* Code blocks types *)
	BLK_UNT_INTF = 1; (* Unit Interface *)
	BLK_UNT_IMPL = 2; (* Unit Implementation *)
	BLK_UNT_INIT = 3; (* Unit Initialization *)
	BLK_UNT_FINL = 4; (* Unit Finalization *)
	BLK_PRG_DECL = 5; (* Program Declaration *)
	BLK_PRG_BODY = 6; (* Program Body *)
	BLK_USES = 7; (* Uses block *)
	
	GRAPH_NODE_WHITE = 0;
	GRAPH_NODE_GRAY = 1;
	GRAPH_NODE_BLACK = 2;

TYPE

	Chars = ARRAY OF CHAR;
	String = Strings.String;

	(* Element for list of possible file extensions *)
	Extension = POINTER TO RECORD
		strExt: ARRAY 8 OF CHAR;
		Next: Extension;
	END;

	(* Code block descriptor *)
	CodeBlock = POINTER TO RECORD
		iStart, iStop, iType: LONGINT;
		Next: CodeBlock;
	END;

	(* Base code analyzer *)
	CodeAnalyzer = OBJECT
	VAR
		scanner: Scanner.Scanner;
		item: CodeFile;

		PROCEDURE &Init(scanner: Scanner.Scanner; item: CodeFile);
		BEGIN
			SELF.scanner := scanner;
			SELF.item := item;
			item.blocks := {};
			item.lstBlocks := NIL;
			NEW(item.vecUsesIntf, {});
			NEW(item.vecUsesImpl, {});
			NEW(item.vecUsesDecl, {})
		END Init;

		PROCEDURE Analyze(sym: LONGINT);
		BEGIN
		END Analyze;

		PROCEDURE Print(context: Commands.Context);
		BEGIN
			IF SELF IS ProgramAnalyzer THEN
				context.out.String("Program ")
			ELSIF SELF IS UnitAnalyzer THEN
				context.out.String("Unit ")
			END;
			context.out.String(item.key^);
			context.out.Ln
		END Print;

		PROCEDURE AddBlock(iStart, iStop, iType: LONGINT);
		VAR
			blk: CodeBlock;
		BEGIN
			NEW(blk);
			blk.iStart := iStart;
			blk.iStop := iStop;
			blk.iType := iType;
			blk.Next := item.lstBlocks;
			item.lstBlocks := blk
		END AddBlock;

		(* Calculates start position of current symbol regarding token length *)
		PROCEDURE GetSymStart(): LONGINT;
		BEGIN
			RETURN scanner.curpos - Strings.Length(scanner.str) - 1
		END GetSymStart;

		PROCEDURE PrintCodeBlocks(context: Commands.Context);
		VAR
			blk: CodeBlock;
		BEGIN
			context.out.String("Blocks: ");
			blk := item.lstBlocks;
			WHILE blk # NIL DO
				CASE blk.iType OF
				| BLK_UNT_INTF: context.out.String("Unit Interface: ");
				| BLK_UNT_IMPL: context.out.String("Unit Implementation: ");
				| BLK_UNT_INIT: context.out.String("Unit Initialization: ");
				| BLK_UNT_FINL: context.out.String("Unit Finalization: ");
				| BLK_PRG_DECL: context.out.String("Program Declaration: ");
				| BLK_PRG_BODY: context.out.String("Program Body: ");
				| BLK_USES: context.out.String("Uses block: ");
				ELSE
				END;
				context.out.Int(blk.iStart, 0);
				context.out.String("..");
				context.out.Int(blk.iStop, 0);
				blk := blk.Next;
				IF blk # NIL THEN
					context.out.String(", ")
				END
			END;
			context.out.Ln
		END PrintCodeBlocks;

	END CodeAnalyzer;

	(* Analyzer of main 'Program' module *)
	ProgramAnalyzer = OBJECT(CodeAnalyzer)
	VAR
		bProgDecl, bUsesDecl, bBeginDecl, bEndDecl: BOOLEAN;
		iDeclStart, iUsesStart, iBeginStart, iBodyStart, iEndStart: LONGINT;

		PROCEDURE &Init(scanner: Scanner.Scanner; item: CodeFile);
		BEGIN
			Init^(scanner, item);
			bProgDecl := FALSE;
			bUsesDecl := FALSE;
			bBeginDecl := FALSE;
			bEndDecl := FALSE
		END Init;

		PROCEDURE Analyze(sym: LONGINT);
		BEGIN
			IF bEndDecl & (sym # Scanner.sym_comment) & (sym # Scanner.sym_period) THEN
				bEndDecl := FALSE;
				bBeginDecl := FALSE
			END;
			CASE sym OF
			| Scanner.sym_program: IF item.blocks = {} THEN
					INCL(item.blocks, BLK_PRG_DECL);
					bProgDecl := TRUE
					(*iDeclStart := scanner.curpos - 1*)
				END
			| Scanner.sym_uses:
				IF BLK_PRG_DECL IN item.blocks THEN
					bUsesDecl := TRUE;
					iUsesStart := GetSymStart()
				END
			| Scanner.sym_ident:
				IF (BLK_PRG_DECL IN item.blocks) & bUsesDecl THEN
					item.vecUsesDecl.Add(Strings.LowerCaseInNew(scanner.str)^)
				ELSIF (BLK_PRG_DECL IN item.blocks) & bProgDecl THEN
					bProgDecl := FALSE;
					iDeclStart := scanner.curpos
				END
			| Scanner.sym_semicolon:
				IF (BLK_PRG_DECL IN item.blocks) & bUsesDecl THEN
					bUsesDecl := FALSE;
					AddBlock(iUsesStart, scanner.curpos - 1, BLK_USES)
				END
			| Scanner.sym_begin:
				IF BLK_PRG_DECL IN item.blocks THEN
					bBeginDecl := TRUE;
					iBeginStart := GetSymStart();
					iBodyStart := scanner.curpos - 1
				END
			| Scanner.sym_end:
				IF BLK_PRG_DECL IN item.blocks THEN
					bEndDecl := TRUE;
					iEndStart := GetSymStart()
				END
			| Scanner.sym_period:
				IF (BLK_PRG_DECL IN item.blocks) & bBeginDecl & bEndDecl THEN
					INCL(item.blocks, BLK_PRG_BODY);
					AddBlock(iDeclStart, iBeginStart, BLK_PRG_DECL);
					AddBlock(iBodyStart, GetSymStart() - 1, BLK_PRG_BODY)
				END
			ELSE
			END;
		END Analyze;

		PROCEDURE Print(context: Commands.Context);
		BEGIN
			Print^(context);
			PrintUsesVector(context, "Declaration part dependencies:", item.vecUsesDecl);
			(*PrintCodeBlocks(context);*)
			context.out.Ln
		END Print;

	END ProgramAnalyzer;

	(* Analyzer of 'Unit' modules *)
	UnitAnalyzer = OBJECT(CodeAnalyzer)
	VAR
		bUsesDecl, bEndDecl: BOOLEAN;
		iIntfStart, iImplStart,	iInitStart, iFinStart,
		iUsesStart, iEndStart: LONGINT;

		PROCEDURE &Init(scanner: Scanner.Scanner; item: CodeFile);
		BEGIN
			Init^(scanner, item);
			bUsesDecl := FALSE;
			bEndDecl := FALSE
		END Init;

		PROCEDURE Analyze(sym: LONGINT);
		BEGIN
			IF bEndDecl & (sym # Scanner.sym_comment) & (sym # Scanner.sym_period) THEN
				bEndDecl := FALSE
			END;
			CASE sym OF
			| Scanner.sym_interface: IF item.blocks = {} THEN
					INCL(item.blocks, BLK_UNT_INTF);
					iIntfStart := scanner.curpos - 1
				END
			| Scanner.sym_implementation: IF BLK_UNT_INTF IN item.blocks THEN
					INCL(item.blocks, BLK_UNT_IMPL);
					iImplStart := scanner.curpos - 1;
					AddBlock(iIntfStart, GetSymStart() - 1, BLK_UNT_INTF)
				END;
			| Scanner.sym_initialization: IF item.blocks * {BLK_UNT_INTF, BLK_UNT_IMPL} # {} THEN
					INCL(item.blocks, BLK_UNT_INIT);
					iInitStart := scanner.curpos - 1;
					AddBlock(iImplStart, GetSymStart() - 1, BLK_UNT_IMPL)
				END
			| Scanner.sym_finalization: IF item.blocks * {BLK_UNT_INTF, BLK_UNT_IMPL, BLK_UNT_INIT} # {} THEN
					INCL(item.blocks, BLK_UNT_FINL);
					iFinStart := scanner.curpos - 1;
					AddBlock(iInitStart, GetSymStart() - 1, BLK_UNT_INIT)
				END
			| Scanner.sym_uses:
				IF item.blocks * {BLK_UNT_INTF, BLK_UNT_IMPL} # {} THEN
					bUsesDecl := TRUE;
					iUsesStart := GetSymStart()
				END
			| Scanner.sym_ident:
				IF (item.blocks * {BLK_UNT_INTF, BLK_UNT_IMPL} # {}) & bUsesDecl THEN
					IF BLK_UNT_IMPL IN item.blocks THEN
						item.vecUsesImpl.Add(Strings.LowerCaseInNew(scanner.str)^)
					ELSIF BLK_UNT_INTF IN item.blocks THEN
						item.vecUsesIntf.Add(Strings.LowerCaseInNew(scanner.str)^)
					END
				END
			| Scanner.sym_semicolon:
				IF bUsesDecl THEN
					bUsesDecl := FALSE;
					AddBlock(iUsesStart, scanner.curpos - 1, BLK_USES)
				END
			| Scanner.sym_end:
				IF item.blocks * {BLK_UNT_INTF, BLK_UNT_IMPL} # {} THEN
					bEndDecl := TRUE;
					iEndStart := GetSymStart()
				END
			| Scanner.sym_period:
				IF (item.blocks * {BLK_UNT_INTF, BLK_UNT_IMPL} # {}) & bEndDecl THEN
					IF item.blocks * {BLK_UNT_FINL} # {} THEN
						AddBlock(iFinStart, GetSymStart() - 1, BLK_UNT_FINL)
					ELSIF item.blocks * {BLK_UNT_INIT} # {} THEN
						AddBlock(iInitStart, GetSymStart() - 1, BLK_UNT_INIT)
					ELSE
						AddBlock(iImplStart, GetSymStart() - 1, BLK_UNT_IMPL)
					END
				END
			ELSE
			END;
		END Analyze;

		PROCEDURE Print(context: Commands.Context);
		BEGIN
			Print^(context);
			PrintUsesVector(context, "Interface part dependencies:", item.vecUsesIntf);
			(*PrintUsesVector(context, "Implementation part dependencies:", item.vecUsesImpl);
			PrintCodeBlocks(context);*)
			context.out.Ln
		END Print;

	END UnitAnalyzer;

	CodeFile = POINTER TO RECORD
		(** File name (without extension) as a key *)
		key: Strings.String;
		(** File is present *)
		bPresent: BOOLEAN;
		(** Lists of dependencies for interface and implementation blocks of unit *)
		vecUsesIntf, vecUsesImpl: Containers.StringVector;
		(** List of dependencies for declaration block of main program *)
		vecUsesDecl: Containers.StringVector;
		(** What blocks are present *)
		blocks: SET;
		(** List of blocks start and stop positions *)
		lstBlocks: CodeBlock;
		analyzer: CodeAnalyzer;
		
		(* For Graph Topological sort *)
		(* GRAPH_NODE_WHITE, GRAPH_NODE_GRAY or GRAPH_NODE_BLACK *)
		color: LONGINT;
		(* Nodes that dependent from that node (has this module in uses list in interface part) *)
		vecDependentNodes: CodeFileVector;
		
	END;

	CodeFileMap = OBJECT(Containers.CustomSet)

		PROCEDURE &New;
		BEGIN
			NEW(dictionary, CodeFilesEqual, CodeFileHash)
		END New;

		PROCEDURE CodeFilesEqual(first, second: ANY): BOOLEAN;
		BEGIN
			RETURN first(CodeFile).key^ = second(CodeFile).key^
		END CodeFilesEqual;

		PROCEDURE CodeFileHash(item: ANY): LONGINT;
		BEGIN
			RETURN Containers.HashString(item(CodeFile).key)
		END CodeFileHash;

		PROCEDURE Add(item: CodeFile);
		BEGIN
			dictionary.Add(item)
		END Add;

		PROCEDURE Contains(item: CodeFile): BOOLEAN;
		BEGIN
			RETURN dictionary.Contains(item)
		END Contains;

		PROCEDURE Get*(item: CodeFile): CodeFile;
		VAR
			p: ANY;
		BEGIN
			p := dictionary.Get(item);
			IF p # NIL THEN
				RETURN p(CodeFile)
			ELSE
				RETURN NIL
			END
		END Get;

		PROCEDURE GetIterator(): Containers.DictionaryIterator;
		VAR
			iterator: Containers.DictionaryIterator;
		BEGIN
			NEW(iterator, dictionary);
			RETURN iterator
		END GetIterator;

	END CodeFileMap;
	
	(** Vector of CodeFile's *)
	CodeFileVector = OBJECT(Containers.CustomVector)
			
		PROCEDURE &New(options: SET);
		BEGIN
			NEW(vector, NIL, options)
		END New;
		
		PROCEDURE Add(x: CodeFile);
		BEGIN
			vector.Add(x)
		END Add;

		PROCEDURE GetItem(i: LONGINT): CodeFile;
		BEGIN
			RETURN vector.GetItem(i)(CodeFile)
		END GetItem;
			
	END CodeFileVector;

VAR
	exts: Extension;
	
	strWorkPath: Files.FileName;

	(** Map of resolved dependencies *)
	mapDependencies: CodeFileMap;

	(** List of external dependencies *)
	vecUsesExternal: Containers.StringVector;
	
	OPERATOR "+" (CONST a, b: Chars): String;
	BEGIN
		RETURN Strings.ConcatToNew(a, b)
	END "+";

	PROCEDURE GetBlock(blkStart: CodeBlock; iBlockType: LONGINT): CodeBlock;
	VAR
		blk: CodeBlock;
	BEGIN
		blk := blkStart;
		WHILE blk # NIL DO
			IF blk.iType = iBlockType THEN
				RETURN blk
			END;
			blk := blk.Next
		END;
		RETURN NIL
	END GetBlock;
	
	PROCEDURE GetBlockText(blk: CodeBlock; CONST buffer: ARRAY OF CHAR): Strings.String;
	VAR
		tmp: Strings.String;
		iLen: LONGINT;
	BEGIN
		IF blk # NIL THEN
			iLen := blk.iStop - blk.iStart;
			IF iLen > 0 THEN
				NEW(tmp, iLen + 1);
				Strings.Copy(buffer, blk.iStart, iLen, tmp^);
				RETURN tmp
			END
		END;
		RETURN NIL
	END GetBlockText;

	PROCEDURE GetProgramAnalyzer(scanner: Scanner.Scanner; item: CodeFile; CONST strName: ARRAY OF CHAR): CodeAnalyzer;
	VAR
		analyzer: ProgramAnalyzer;
	BEGIN
		NEW(analyzer, scanner, item);
		item.analyzer := analyzer;
		RETURN analyzer
	END GetProgramAnalyzer;

	PROCEDURE GetUnitAnalyzer(scanner: Scanner.Scanner; item: CodeFile; CONST strName: ARRAY OF CHAR): CodeAnalyzer;
	VAR
		analyzer: UnitAnalyzer;
	BEGIN
		NEW(analyzer, scanner, item);
		item.analyzer := analyzer;
		RETURN analyzer
	END GetUnitAnalyzer;

	PROCEDURE AddExtension(str: ARRAY OF CHAR);
	VAR
		ext: Extension;
	BEGIN
		NEW(ext);
		COPY(str, ext.strExt);
		ext.Next := exts;
		exts := ext
	END AddExtension;
	
	PROCEDURE PrintUsesVector(context: Commands.Context; CONST title: ARRAY OF CHAR; vec: Containers.StringVector);
	VAR
		i: LONGINT;
	BEGIN
		IF vec.GetCount() > 0 THEN
			context.out.String(title);
			context.out.Char(20X);
			FOR i := 0 TO vec.GetCount() - 1 DO
				context.out.String(vec.GetItem(i)^);
				context.out.Char(20X);
			END;
			context.out.Ln;
		END;
	END PrintUsesVector;

	(** Find unit by substitution of registered extentions *)
	PROCEDURE FindCodeFile(strName: ARRAY OF CHAR): Files.File;
	VAR
		ext: Extension;
		strFileName: Files.FileName;
		file: Files.File;
	BEGIN
		file := NIL;
		ext := exts;
		WHILE (ext # NIL) & (file = NIL) DO
			Files.JoinPath(strWorkPath, strName, strFileName);
			Strings.Concat(strFileName, ext.strExt, strFileName);
			file := Files.Old(strFileName);
			ext := ext.Next
		END;
		RETURN file
	END FindCodeFile;
	
	PROCEDURE ReadCodeFileContents(CONST strName: ARRAY OF CHAR): Strings.String;
	VAR
		flIn: Files.File;
		r: Files.Rider;
		buffer: Strings.String;	
	BEGIN
		flIn := FindCodeFile(strName);
		IF flIn = NIL THEN
			RETURN NIL
		END;
		flIn.Set(r, 0);
		NEW(buffer, flIn.Length() + 1);
		r.file.ReadBytes(r, buffer^, 0, flIn.Length());
		buffer[LEN(buffer) - 1] := 0X;
		RETURN buffer
	END ReadCodeFileContents;
	
	PROCEDURE OpenWriter(context: Commands.Context; CONST strName: ARRAY OF CHAR): Files.Writer;
	VAR
		flOut: Files.File;
		wr: Files.Writer;
	BEGIN
		flOut := Files.New(strName);
		IF flOut = NIL THEN
			context.out.String(" can't create file: ");
			context.out.String(strName);
			context.out.Ln;
			RETURN NIL
		END;
		Files.Register(flOut);
		Files.OpenWriter(wr, flOut, 0);
		RETURN wr
	END OpenWriter;
	
	PROCEDURE TopologicalSort(context: Commands.Context; node: CodeFile; output: CodeFileVector);
	VAR
		i: LONGINT;
	BEGIN
		(*
			- If node is Black, do nothing
			- If node is Gray, the Loop is found, Topological Sort is impossible
			- If node is White:
				- Paint node to Gray
				- Perform step of an alogithm for all nodes accessible from that node (dependent nodes)
				- Paint node to Black and put into resulting list
		*)
		IF node.color # GRAPH_NODE_BLACK THEN
		
			(*! The Loop is found, Topological Sort is impossible *)
			ASSERT(node.color # GRAPH_NODE_GRAY);
			
			node.color := GRAPH_NODE_GRAY;
			FOR i := 0 TO node.vecDependentNodes.GetCount() - 1 DO
				TopologicalSort(context, node.vecDependentNodes.GetItem(i), output)
			END;
			node.color := GRAPH_NODE_BLACK;
			output.Add(node);
			(*node.analyzer.Print(context)*)
			
		END

	END TopologicalSort;
	
	PROCEDURE SaveCombinedUnit(context: Commands.Context; itemMain: CodeFile; strName, strPathName: String);
	VAR
		wr: Files.Writer;
		i, j: LONGINT;
		bufIntf, bufImpl, bufInit, bufFinl: Strings.Buffer;
		wrIntf, wrImpl, wrInit, wrFinl, wrBuf: Streams.Writer;
		iterator, iterator2: Containers.DictionaryIterator;
		item, item2: CodeFile;
		buffer, tmp: Strings.String;
		blk: CodeBlock;
		
		(* TODO: use LIFO stack instead of vector *)
		output: CodeFileVector;
		
	BEGIN
		wr := OpenWriter(context, strPathName^);
		IF wr # NIL THEN
			wr.String("unit "); wr.String(strName^); wr.Char(';'); wr.Ln;
			wr.Ln;
			wr.String("interface"); wr.Ln;
			wr.Ln;
			wr.String("uses"); wr.Ln;
			FOR i := 0 TO vecUsesExternal.GetCount() - 1 DO
				wr.Char(9X); wr.String(vecUsesExternal.GetItem(i)^);
				IF i # vecUsesExternal.GetCount() - 1 THEN wr.Char(',') ELSE wr.Char(';') END;
				wr.Ln
			END;
			wr.Ln;
			NEW(bufIntf, 65536); wrIntf := bufIntf.GetWriter();
			NEW(bufImpl, 65536); wrImpl := bufImpl.GetWriter();
			NEW(bufInit, 65536); wrInit := bufInit.GetWriter();
			NEW(bufFinl, 65536); wrFinl := bufFinl.GetWriter();
			
			(* Prepare needed information to form a Graph inside a vector.
			
				Then perform Topological Sort by Tarjan alogithm:
					1. At begining all nodes are White
					2. For all nodes perform step of alogithm:
						- If node is Black, do nothing
						- If node is Gray, the Loop is found, Topological Sort is impossible
						- If node is White:
							- Paint node to Gray
							- Perform step of an alogithm for all nodes accessible from that node (dependent nodes)
							- Paint node to Black and put into resulting list
			*)

			iterator := mapDependencies.GetIterator();
			iterator.Reset;
			WHILE iterator.HasNext() DO
				item := iterator.GetNext()(CodeFile);
				IF (item # itemMain) & item.bPresent THEN
					item.color := GRAPH_NODE_WHITE;
					NEW(item.vecDependentNodes, {})
				END
			END;
			iterator.Reset;
			iterator2 := mapDependencies.GetIterator();
			WHILE iterator.HasNext() DO
				item := iterator.GetNext()(CodeFile);
				IF (item # itemMain) & item.bPresent THEN
					(* Find all nodes that depend of this node and put to list *)
					iterator2.Reset;
					WHILE iterator2.HasNext() DO
						item2 := iterator2.GetNext()(CodeFile);
						IF (item2 # item) & (item2 # itemMain) & item2.bPresent THEN
						
							(* TODO: use map (to say exactly, set) instead of vector *)
							IF item2.vecUsesIntf.IndexOf(item.key^) >= 0 THEN
								item.vecDependentNodes.Add(item2)
							END
							
						END
					END
				END
			END;
			
			(* Topological Sort *)
			NEW(output, {});
			iterator.Reset;
			WHILE iterator.HasNext() DO
				item := iterator.GetNext()(CodeFile);
				IF (item # itemMain) & item.bPresent THEN
					TopologicalSort(context, item, output)
				END
			END;
			
			j := output.GetCount() - 1;
			WHILE j >= 0 DO
				item := output.GetItem(j);
				buffer := ReadCodeFileContents(item.key^);
				IF buffer # NIL THEN
					(* Replace uses sections with spaces *)
					blk := item.lstBlocks;
					WHILE blk # NIL DO
						IF blk.iType = BLK_USES THEN
							FOR i := blk.iStart TO blk.iStop DO
								buffer^[i] := 20X
							END
						END;
						blk := blk.Next
					END;
					blk := item.lstBlocks;
					WHILE blk # NIL DO
						wrBuf := NIL;
						CASE blk.iType OF
						| BLK_UNT_INTF: wrBuf := wrIntf; wrBuf.String("(* Unit "); wrBuf.String(item.key^); wrBuf.String(" interface *)"); wrBuf.Ln
						| BLK_UNT_IMPL: wrBuf := wrImpl; wrBuf.String("(* Unit "); wrBuf.String(item.key^); wrBuf.String(" implementation *)"); wrBuf.Ln
						| BLK_UNT_INIT: wrBuf := wrInit; wrBuf.String("(* Unit "); wrBuf.String(item.key^); wrBuf.String(" initialization *)"); wrBuf.Ln
						| BLK_UNT_FINL: wrBuf := wrFinl; wrBuf.String("(* Unit "); wrBuf.String(item.key^); wrBuf.String(" finalization *)"); wrBuf.Ln
						ELSE
						END;
						IF wrBuf # NIL THEN
							tmp := GetBlockText(blk, buffer^);
							IF tmp # NIL THEN
								wrBuf.String(tmp^); wrBuf.Ln
							END
						END;
						blk := blk.Next
					END
				END;
				DEC(j)
			END;

			wr.Ln;
			wr.String(bufIntf.GetString()^); wr.Ln;
			wr.Ln;
			wr.String("implementation"); wr.Ln;
			wr.Ln;
			wr.String(bufImpl.GetString()^); wr.Ln;
			wr.Ln;
			wr.String("initialization"); wr.Ln;
			wr.Ln;
			wr.String(bufInit.GetString()^); wr.Ln;
			wr.Ln;
			wr.String("finalization"); wr.Ln;
			wr.Ln;
			wr.String(bufFinl.GetString()^); wr.Ln;
			wr.Ln;
			wr.String("end."); wr.Ln
		END
	FINALLY
		IF wr # NIL THEN
			wr.Update
		END
	END SaveCombinedUnit;
	
	PROCEDURE SaveCombinedProgram(context: Commands.Context; itemMain: CodeFile; strName, strUnitName, strUnitFileName, strPathName: String);
	VAR
		wr: Files.Writer;
		blkProgDecl, blkUses: CodeBlock;
		i: LONGINT;
		buffer, tmp: Strings.String;
	BEGIN
		wr := OpenWriter(context, strPathName^);
		buffer := ReadCodeFileContents(itemMain.key^);
		IF (wr # NIL) & (buffer # NIL) THEN
			wr.String("program "); wr.String(strName^); wr.Char(';'); wr.Ln;
			wr.Ln;
			wr.String("uses"); wr.Ln;
			FOR i := 0 TO vecUsesExternal.GetCount() - 1 DO
				wr.Char(9X); wr.String(vecUsesExternal.GetItem(i)^); wr.Char(','); wr.Ln
			END;
			wr.Char(9X); wr.String(strUnitName^); wr.String(" in '"); wr.String(strUnitFileName^); wr.String("';"); wr.Ln;
			wr.Ln;
			blkProgDecl := GetBlock(itemMain.lstBlocks, BLK_PRG_DECL);
			tmp := GetBlockText(blkProgDecl, buffer^);
			IF (blkProgDecl # NIL) & (tmp # NIL) THEN
				(* If uses section present it should be removed *)
				blkUses := GetBlock(itemMain.lstBlocks, BLK_USES);
				IF (blkUses # NIL) & (blkUses.iStart >= blkProgDecl.iStart) & (blkUses.iStop <= blkProgDecl.iStop) THEN
					Strings.Delete(tmp^, blkUses.iStart - blkProgDecl.iStart, blkUses.iStop - blkUses.iStart)
				END;
				wr.String(tmp^); wr.Ln;
				wr.Ln
			END;
			wr.String("begin"); wr.Ln;
			wr.Ln;
			tmp := GetBlockText(GetBlock(itemMain.lstBlocks, BLK_PRG_BODY), buffer^);
			wr.String(tmp^); wr.Ln;
			wr.Ln;
			wr.String("end."); wr.Ln
		END
	FINALLY
		IF wr # NIL THEN
			wr.Update
		END
	END SaveCombinedProgram;

	PROCEDURE AnalyzeCode(context: Commands.Context; CONST strName: ARRAY OF CHAR; bMain: BOOLEAN)(*: BOOLEAN*);
	VAR
		buffer: Strings.String;
		scanner: Scanner.Scanner;
		analyzer: CodeAnalyzer;
		item: CodeFile;
		i: LONGINT;
	BEGIN

		NEW(item);
		item.key := Strings.NewString(strName);

		IF mapDependencies.Contains(item) THEN
			RETURN
		END;

		mapDependencies.Add(item);

		item.bPresent := FALSE;
		
		buffer := ReadCodeFileContents(strName);
		IF buffer = NIL THEN
			RETURN
		END;

		item.bPresent := TRUE;

		NEW(scanner, buffer);

		IF bMain THEN
			analyzer := GetProgramAnalyzer(scanner, item, strName)
		ELSE
			analyzer := GetUnitAnalyzer(scanner, item, strName)
		END;

		scanner.Next;
		WHILE scanner.sym # Scanner.sym_eof DO
			analyzer.Analyze(scanner.sym);
			scanner.Next
		END;

		IF bMain THEN
			FOR i := 0 TO item.vecUsesDecl.GetCount() - 1 DO
				AnalyzeCode(context, item.vecUsesDecl.GetItem(i)^, FALSE)
			END
		ELSE
			FOR i := 0 TO item.vecUsesIntf.GetCount() - 1 DO
				AnalyzeCode(context, item.vecUsesIntf.GetItem(i)^, FALSE)
			END;
			FOR i := 0 TO item.vecUsesImpl.GetCount() - 1 DO
				AnalyzeCode(context, item.vecUsesImpl.GetItem(i)^, FALSE)
			END
		END;

	END AnalyzeCode;

	(*
		Usage. Provide only one parameter, main project file name without extension:
			PascalProjectCombine.ProcessProgram [drive:/path/]mainprojectfilename ~
	*) 
	PROCEDURE ProcessProgram*(context: Commands.Context);
	VAR
		t: HUGEINT;
		iterator: Containers.DictionaryIterator;
		item: CodeFile;
		strName,
		strParamName: Files.FileName;
		strNewName, strNewNameAndPath: String;
		str: ARRAY 128 OF CHAR;
	BEGIN
	
		IF mapDependencies # NIL THEN
			RETURN
		END;
		NEW(mapDependencies);
		NEW(vecUsesExternal, {});
		context.out.Ln;
		IF context.arg.GetString(strParamName) THEN
			t := PreciseTimer.GetTicks();

			Files.SplitPath(strParamName, strWorkPath, strName);
			Strings.LowerCase(strName);
			AnalyzeCode(context, strName, TRUE);

			iterator := mapDependencies.GetIterator();
			iterator.Reset;
			WHILE iterator.HasNext() DO
				item := iterator.GetNext()(CodeFile);
				IF (item # NIL) & ~item.bPresent THEN
					vecUsesExternal.Add(item.key^)
				END
			END;
			
			PrintUsesVector(context, "External dependencies (non-resolved):", vecUsesExternal);
			context.out.Ln;
			
			(*context.out.Ln;
			iterator.Reset;
			WHILE iterator.HasNext() DO
				item := iterator.GetNext()(CodeFile);
				IF (item # NIL) & (item.analyzer # NIL) THEN
					item.analyzer.Print(context)
				END
			END;*)
			
			(*
				Here we need to:
				1. Save combined unit with all code of units included (separately combined: interface,
					implementation, initialization and finalization sections), except code of
					main project file. In USES section external dependencies should be listed;
				2. Save modified main project file with only external dependencies listed
					in uses section + use of unit obtained on step 1
			*)
			(*Strings.Concat(strName, "_combined", strCombinedProgramName);
			Files.JoinPath(strWorkPath, strName + "_combined", strCombinedProgramNameAndPath);
			Strings.Concat(strName, "_combined_unit", strCombinedUnitName);
			Files.JoinPath(strWorkPath, strCombinedUnitName, strCombinedUnitNameAndPath);*)
			strNewName := strName + "_combined";
			strNewNameAndPath := strParamName + "_combined";
			NEW(item);
			item.key := Strings.NewString(strName);
			item := mapDependencies.Get(item);
			IF item # NIL THEN
				(* 1 *)
				(*Strings.Concat(strCombinedUnitNameAndPath, ".pas", strCombinedUnitFileName);*)
				SaveCombinedUnit(context, item, strNewName + "_unit", strNewNameAndPath + "_unit.pas");
				(* 2 *)
				(*Strings.Concat(strCombinedProgramNameAndPath, ".dpr", strCombinedProgramFileName);*)
				SaveCombinedProgram(context, item, strNewName, strNewName + "_unit", strNewName + "_unit.pas", strNewNameAndPath + ".dpr");
			END;

			t := PreciseTimer.GetTicks() - t;
			context.out.String("Time: ");
			Strings.FloatToStr(PreciseTimer.GetTime(t), 0, 3, 0, str);
			context.out.String(str);
			context.out.String(" sec.");
			context.out.Ln;
			context.out.Update;
		END;
	END ProcessProgram;

BEGIN
	exts := NIL;
	AddExtension(".pas"); 
	AddExtension(".pp");
	AddExtension(".dpr");
	AddExtension(".lpr");
	AddExtension(".ppr");
	mapDependencies := NIL;
END PascalProjectCombine.

Compiler.Compile
	Libs/Windows.PreciseTimer.Mod
	Libs/Containers.Mod
	Tools/PascalScanner.Mod
	Tools/PascalProjectCombine.Mod ~

PascalProjectCombine.ProcessProgram Doom32/Doom32 ~

System.Free PascalProjectCombine PascalScanner ~



