MODULE MinosLinker;   (**  AUTHOR "fof"; PURPOSE "Link Minos Image. Standalone Linker taken from OSACompiler from Niklaus Wirth";  **)

IMPORT Streams, Commands, Files, KernelLog;

TYPE
	Name = ARRAY 32 OF CHAR;
	Command = RECORD name: Name; offset: LONGINT END;
	Module = POINTER TO RECORD
		name: Name;
		key:  LONGINT;
		dbase, pbase: LONGINT;
		size, refcnt: LONGINT;
		next: Module;
		entries: LONGINT;
		entry: ARRAY 256 OF LONGINT;
		command: ARRAY 64 OF Command;
	END ;

	Linker* = OBJECT
	VAR
		first, last: Module;
		base, heap, descriptorBase, bodyBase: LONGINT;
		W: Streams.Writer;
		Out: Files.File; Rout: Files.Writer;
		code: ARRAY 256*1024 OF LONGINT;		(* tt: increased image size to one megabyte *)
		plain, descriptors: BOOLEAN;

		PROCEDURE &InitLinker* (w: Streams.Writer; plain, descriptors: BOOLEAN);
		BEGIN W := w;
			SELF.plain := plain; SELF.descriptors := descriptors;
		END InitLinker;

		PROCEDURE SetPos (pos: Files.Position);
		BEGIN
			Rout.Update;
			IF pos > Out.Length () THEN
				Files.OpenWriter(Rout, Out, Out.Length ());
				pos := pos - Out.Length (); REPEAT Rout.Char (0X); DEC (pos) UNTIL pos = 0
			ELSE Files.OpenWriter(Rout, Out, pos)
			END;
		END SetPos;

		PROCEDURE WriteCodeBlock(len, adr: LONGINT);
		VAR i: LONGINT;
		BEGIN
			IF plain THEN SetPos (adr - base) ELSE Rout.RawLInt (len); Rout.RawLInt (adr) END;
			WHILE i < len DO Rout.RawLInt( code[i]); INC(i) END;
			IF ~plain & (len # 0) THEN Rout.RawLInt( 0) END
		END WriteCodeBlock;

		PROCEDURE Fixup(fixloc, offset, base: LONGINT; VAR entry: ARRAY OF LONGINT);
			VAR instr, next, pno: LONGINT;
		BEGIN
			WHILE fixloc # 0 DO
				instr := code[fixloc]; next := instr MOD 10000H;
				pno := instr DIV 10000H MOD 100H;
				IF instr DIV 1000000H MOD 100H = 0EBH THEN  (* case  BL *)
					instr := instr DIV 1000000H * 1000000H + (entry[pno] + offset - fixloc - 2) MOD 1000000H
				ELSE (*indir. proc. address or indir. variable address *) instr := entry[pno]*4 + base
				END ;
				code[fixloc] := instr; fixloc := next
			END
		END Fixup;

		PROCEDURE FixSelf(fixloc, base: LONGINT);
			VAR instr, next: LONGINT;
		BEGIN
			WHILE fixloc # 0 DO
				instr := code[fixloc]; next := instr MOD 10000H;
				code[fixloc] := instr DIV 10000H * 4 + base; fixloc := next
			END
		END FixSelf;

		PROCEDURE ThisMod(VAR modname: ARRAY OF CHAR; VAR success: BOOLEAN): Module;
			VAR mod, imp: Module;
				nofimp, nofentries, codelen, fix, fixself, i: LONGINT;
				R: Files.Reader; F: Files.File;
				name: Name;
				key, datasize: LONGINT;
				import: ARRAY 256 OF Module;			(* tt: Increased from 16 to 256 *)
				fixroot: ARRAY 256 OF LONGINT;		(* tt: Increased from 16 to 256 *)

		BEGIN
			success := TRUE;
			mod := first;
			WHILE (mod # NIL) & (mod.name # modname) DO mod := mod.next END ;
			IF mod = NIL THEN  (*load*)
(*				W.String(" trying to load module with name: "); W.String(modname); W.Ln; W.Update; *)
				F := ThisFile(modname);
				IF F # NIL THEN
					Files.OpenReader(R, F, 0);
					NEW(mod); mod.next := NIL; mod.refcnt := 0;
					R.RawString( mod.name); R.RawLInt( mod.key);
					R.RawLInt( fixself);
					R.RawString( name); success := TRUE; i := 0;
					W.String( "module "); W.String( mod.name); W.String(" key: "); W.Hex( mod.key, -9); W.Ln();
					WHILE (name[0] # 0X) & success DO
						R.RawLInt (key); R.RawLInt (fix);
(*						W.String ("    importing "); W.String(name); W.String(" Key: " );
						W.Hex (key, 9); W.String(" fix: "); W.Int (fix, 6); W.Ln; W.Update;
*)						imp := ThisMod(name, success);
						IF imp # NIL THEN
							IF (key = imp.key) THEN
								import[i] := imp; INC (imp.refcnt); fixroot[i] := fix; INC(i)
							ELSE success := FALSE;
								W.String( name); W.String( " wrong version");
								W.Ln(); W.Update();
							END ;
						ELSE success := FALSE;
							W.String( name); W.String( " not found");
							W.Ln();
						END ;
					R.RawString( name); W.Update()
					END ;
					nofimp := i;
					IF success THEN
						IF first = NIL THEN first := mod ELSE last.next := mod END; last := mod;
						i := 0; R.RawString( mod.command[i].name);
						WHILE mod.command[i].name[0] # 0X DO  (*skip commands*)
							R.RawLInt( mod.command[i].offset); INC (i);
							R.RawString( mod.command[i].name);
						END ;
						R.RawLInt( nofentries); R.RawLInt( mod.entry[0]); i := 0;
						W.String("modEntry ="); W.Int(mod.entry[0],1); W.Ln;
						WHILE i < nofentries DO INC(i); R.RawLInt( mod.entry[i]) END ; INC (i); mod.entry[i] := 0; mod.entries := i;
						mod.dbase := heap; R.RawLInt( datasize); INC (heap, datasize); mod.pbase := heap;
						R.RawLInt( codelen); mod.size := codelen*4; INC (heap, mod.size); i := 0;
						WHILE i < codelen DO R.RawLInt( code[i]); INC(i) END ;
						FixSelf(fixself, mod.pbase); i := 0;
						WHILE i < nofimp DO
							Fixup(fixroot[i], (import[i].pbase - mod.pbase) DIV 4, import[i].pbase, import[i].entry); INC(i)
						END ;
						W.String( "    loading "); W.String( mod.name);
						W.Int( codelen*4, 6);
						W.String(" ");
						W.Hex( mod.dbase,-8);
						W.String(" ");
						W.Hex( mod.pbase,-8);
						W.String(" ");
						W.Hex( mod.entry[0]*4 + mod.pbase,-8);
						WriteCodeBlock(codelen, mod.pbase)
					END
				ELSE
					W.String( modname); W.String( " not found");
					success := FALSE;
				END;
				W.Ln();  W.Update();
			END ;
			RETURN mod
		END ThisMod;

		PROCEDURE Bodies;
		VAR len, base: LONGINT; mod: Module;
		BEGIN
			len := 0; base := heap; mod := first;
			WHILE mod # NIL DO
				code[len] := BodyBranch (mod, heap); INC (len); INC (heap, 4);
				mod := mod.next;
			END;
			code[len] := Branch (heap, heap); INC (len); INC (heap, 4);
			WriteCodeBlock (len, base);
		END Bodies;

		PROCEDURE String (VAR str: ARRAY OF CHAR; VAR index: LONGINT);
		VAR i, len: LONGINT;
		BEGIN
			len := 0; WHILE str[len] # 0X DO INC (len) END; i := 0;
			WHILE i <= len DO
				code[index] := ORD (str[i]) + ORD (str[i+1]) * 100H + ORD (str[i+2]) * 10000H + ORD (str[i+3]) * 1000000H;
				INC (index); INC (i, 4)
			END;
		END String;

		PROCEDURE ModuleDescriptors;
		VAR mod: Module; len, prevmod, prevcmd, i, cfix, efix: LONGINT;
		BEGIN
			mod := first; len := 0; prevmod := 0;
			WHILE mod # NIL DO
				(* Module *)
(*		W.String (mod.name); W.String (": "); W.Hex (heap + len * 4,9); W.Ln; W.Update; *)
				code[len] := prevmod; prevmod := heap + len * 4; INC (len);
				code[len] := mod.key; INC (len);
				code[len] := mod.dbase; INC (len);
				code[len] := mod.pbase; INC (len);
				code[len] := mod.size; INC (len);
				code[len] := mod.refcnt; INC (len);
				cfix := len; INC (len);
				efix := len; INC (len);
				String (mod.name, len);
				(* Commands *)
				i := 0; prevcmd := 0;
				WHILE mod.command[i].name[0] # 0X DO
(*		W.String ("   "); W.String (mod.command[i].name); W.String (":"); W.Hex (heap + len * 4,10); W.Hex (mod.command[i].offset,10); W.Ln; W.Update; *)
					code[len] := prevcmd; prevcmd := heap + len * 4; INC (len);
					code[len] := mod.command[i].offset; INC (len);
					String (mod.command[i].name, len); INC (i)
				END;
				IF i # 0 THEN code[len] := 0; INC (len) END; (* sentinel *)
				code[cfix] := prevcmd;
				code[efix] := heap + len * 4; i := 0;

(*			W.String ("   Entries:"); W.Ln; *)
				WHILE i # mod.entries DO
(* 			W.String ("      "); W.Int (i,0); W.String (": "); W.Hex (mod.entry[i], 0); W.Ln; *)
					code[len] := mod.entry[i]; INC (len); INC (i);
				END;
				mod := mod.next;
			END;
			WriteCodeBlock (len, heap);
			INC (heap, len * 4);
			code[0] := prevmod;
			WriteCodeBlock (1, descriptorBase);
		END ModuleDescriptors;

		PROCEDURE AddHeader(fileHeader: ARRAY OF CHAR; VAR success: BOOLEAN);
		VAR
			header: Files.File;
			in: Files.Reader;
			data, i: LONGINT;
		BEGIN
			i := 0;
			IF fileHeader # "" THEN
				header := Files.Old(fileHeader);
				IF header = NIL THEN
					W.String("Could not open header file "); W.String(fileHeader); W.Ln; W.Update;
					success := FALSE;
				ELSE
			 		Files.OpenReader(in, header, 0);
			 		WHILE in.Available() >= 4 DO
			 			in.RawLInt(data); code[i] := data; INC(heap, 4); INC(i);
			 		END;

					WriteCodeBlock(i, base);
				END;
			END;
		END AddHeader;

		PROCEDURE Begin* (base: LONGINT; fileOut, fileHeader: ARRAY OF CHAR; VAR success: BOOLEAN);
		BEGIN SELF.base := base; heap := base;
			first := NIL; last := NIL;
			Out := Files.New(fileOut);  Files.OpenWriter(Rout, Out, 0);
			AddHeader(fileHeader, success);
			bodyBase := heap;
			IF plain THEN INC (heap, 4) END; (* jump to entry point *)
			IF descriptors THEN descriptorBase := heap; INC (heap, 4) END; (* pointer to first module descriptor *)
		END Begin;

		PROCEDURE Link*(fileIn: ARRAY OF CHAR; VAR success: BOOLEAN);
		VAR mod: Module;
		BEGIN
			success := TRUE;
			mod := ThisMod(fileIn, success);
		END Link;

		PROCEDURE End*;
		VAR link: LONGINT;
			fileName: Files.FileName;
		BEGIN
			IF first = NIL THEN
				W.String ("No output");
			ELSE
				IF descriptors THEN ModuleDescriptors END;
				link := heap; Bodies;
				IF plain THEN code[0] := Branch (link, bodyBase); WriteCodeBlock (1, bodyBase)
				ELSE WriteCodeBlock (0, link) END;
				Out.GetName(fileName); Rout.Update(); Files.Register(Out);
				W.String("Wrote image file "); W.String(fileName); W.Ln;
				W.String( "Output file length ="); W.Int( Out.Length(), -8); W.Char(' ');
				W.String("First entry at "); W.Hex( first.entry[0]*4 + first.pbase, -9); W.Ln(); W.Update();
				SELF.first := NIL; SELF.last := NIL; Out := NIL;
			END;
		END End;

	END Linker;

	PROCEDURE Branch (dest, pc: LONGINT): LONGINT;
	BEGIN RETURN LONGINT(0EA000000H) + ((dest - pc) DIV 4 - 2) MOD 1000000H
	END Branch;

	PROCEDURE BranchLink (dest, pc: LONGINT): LONGINT;
	BEGIN RETURN LONGINT(0EB000000H) + ((dest - pc) DIV 4 - 2) MOD 1000000H
	END BranchLink;

	PROCEDURE BodyBranch (m: Module; pc: LONGINT): LONGINT;
	BEGIN RETURN BranchLink (m.pbase + m.entry[0] * 4, pc);
	END BodyBranch;

	PROCEDURE ThisFile(name: ARRAY OF CHAR): Files.File;
		VAR i: INTEGER;
	BEGIN i := 0;
		WHILE name[i] # 0X DO INC(i) END ;
		name[i] := "."; name[i+1] := "a"; name[i+2] := "r"; name[i+3] := "m"; name[i+4] := 0X;
		RETURN Files.Old(name)
	END ThisFile;

VAR
	log: Streams.Writer;   (* logger to KernelLog *)

	PROCEDURE DoLink( linker: Linker; addHeaderFile: BOOLEAN; context: Commands.Context );
	VAR S: Streams.Reader;  fileOut,fileIn, fileHeader: ARRAY 256 OF CHAR; base: LONGINT;
		success: BOOLEAN; intRes: LONGINT;
	BEGIN
		success := TRUE;
		S := context.arg;
		IF addHeaderFile THEN
			S.SkipWhitespace;  S.String( fileHeader );
		ELSE
			fileHeader := "";
		END;
		S.SkipWhitespace;  S.Int( base, TRUE );
		S.SkipWhitespace;  S.String( fileOut );
		Files.Delete(fileOut, intRes);				(* Try to delete an existing output file *)
		linker.Begin (base, fileOut, fileHeader, success);
		WHILE (S.res = Streams.Ok) & success DO
			S.SkipWhitespace;  S.String( fileIn );
			IF fileIn[0] # 0X THEN linker.Link (fileIn, success) END;
		END;
		IF success THEN linker.End ELSE context.result := Commands.CommandError END;
		SetLog(NIL);
	END DoLink;

	PROCEDURE Link*( context: Commands.Context );
	VAR linker: Linker;
	BEGIN
		SetLog(context.out);
		NEW (linker, log, TRUE, TRUE);
		DoLink(linker, TRUE, context);
		SetLog(NIL);
	END Link;

	PROCEDURE SetLog*( Log: Streams.Writer );
	BEGIN
		IF Log = NIL THEN NEW( log, KernelLog.Send, 512 ) ELSE log := Log END;
	END SetLog;

BEGIN
	SetLog( NIL );
END MinosLinker.

System.Free MinosLinker ~
