(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE System IN Oberon; (** portable, except where noted *) (* pjm *)
(**
 * Based on System.Mod by jg, nw, ard, nm, jm, ejz et al.
 * Aos Native Oberon
 *
 * History:
 *
 *	16.03.2007	Activate System.FreeDownTo instead of AosTools.FreeDownTo in procedure FreeOberon (staubesv)
 *)

IMPORT SYSTEM, Kernel, AosFS := Files IN A2, Files, Modules, Objects, Display, Input, Fonts, Viewers, Texts, Oberon, TextFrames,
	KernelLog IN A2, Streams IN A2, Machine IN A2, Heaps IN A2, AosModules := Modules IN A2, AosActive := Objects IN A2,
	ProcessInfo IN A2, Commands IN A2;

CONST
	OberonBaseModule = "Oberon-Kernel";
	WMWindowManager = "WMWindowManager";
	LogWindow = "LogWindow";	(* must have a Close command *)

	MaxString = 64;
	MaxArray = 10;
	LogTime = Input.TimeUnit DIV 2;
	BufSize = 8192;

TYPE
	Bytes = AosModules.Bytes;

	OberonRunner = OBJECT
	VAR exception : BOOLEAN;
	BEGIN {ACTIVE, SAFE, PRIORITY(AosActive.Normal)}
		IF ~exception THEN
			exception := TRUE;
			KernelLog.Enter; KernelLog.String("Oberon started"); KernelLog.Exit;
			Oberon.Loop;
		ELSE
			KernelLog.Enter; KernelLog.String("Oberon restarted due to an exception"); KernelLog.Exit;
			Oberon.Loop;
		END;
		KernelLog.Enter; KernelLog.String("Oberon stopped"); KernelLog.Exit;
	END OberonRunner;

VAR
	W, LogW: Texts.Writer;
	init: BOOLEAN;
	count: LONGINT;
	task: Oberon.Task;
	fixed: Fonts.Font;
	buf: POINTER TO ARRAY OF CHAR;
	log: Texts.Text;
	oberonRunner : OberonRunner;
	time0, date0: LONGINT;

PROCEDURE OpenText(title: ARRAY OF CHAR; T: Texts.Text; system: BOOLEAN);
VAR W: INTEGER;
BEGIN
	IF system THEN W := Display.Width DIV 8*3 ELSE W := 400 END;
	Oberon.OpenText(title, T, W, 240)
END OpenText;

(* --- Toolbox for system control *)

PROCEDURE SetFont*;
VAR beg, end, time: LONGINT; T: Texts.Text; S: Texts.Scanner; f: Fonts.Font;
BEGIN
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
	IF (S.class = Texts.Char) & (S.c = "^") THEN
		Oberon.GetSelection(T, beg, end, time);
		IF time # -1 THEN
			Texts.OpenScanner(S, T, beg); Texts.Scan(S);
			IF S.class = Texts.Name THEN
				f := Fonts.This(S.s);
				IF f # NIL THEN Oberon.SetFont(f) END
			END
		END
	ELSIF S.class = Texts.Name THEN
		f := Fonts.This(S.s);
		IF f # NIL THEN Oberon.SetFont(f) END
	END
END SetFont;

PROCEDURE SetColor*;
VAR beg, end, time: LONGINT; T: Texts.Text; S: Texts.Scanner; ch: CHAR;
BEGIN
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
	IF (S.class = Texts.Char) & (S.c = "^") THEN
		Oberon.GetSelection(T, beg, end, time);
		IF time # -1 THEN
			Texts.OpenReader(S, T, beg); Texts.Read(S, ch); Oberon.SetColor(S.col)
		END
	ELSIF S.class = Texts.Int THEN Oberon.SetColor(SHORT(SHORT(S.i)))
	END
END SetColor;

PROCEDURE SetOffset*;
VAR beg, end, time: LONGINT; T: Texts.Text;S: Texts.Scanner; ch: CHAR;
BEGIN
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
	IF (S.class = Texts.Char) & (S.c = "^") THEN
		Oberon.GetSelection(T, beg, end, time);
		IF time # -1 THEN
			Texts.OpenReader(S, T, beg); Texts.Read(S, ch); Oberon.SetOffset(S.voff)
		END
	ELSIF S.class = Texts.Int THEN Oberon.SetOffset(SHORT(SHORT(S.i)))
	END
END SetOffset;

PROCEDURE Time*;
VAR par: Oberon.ParList; S: Texts.Scanner; t, d, hr, min, sec, yr, mo, day: LONGINT;

	PROCEDURE WritePair(ch: CHAR; x: LONGINT);
	BEGIN Texts.Write(W, ch);
		Texts.Write(W, CHR(x DIV 10 + 30H)); Texts.Write(W, CHR(x MOD 10 + 30H))
	END WritePair;

BEGIN
	par := Oberon.Par;
	Texts.OpenScanner(S, par.text, par.pos); Texts.Scan(S);
	IF S.class = Texts.Int THEN (*set date*)
		day := S.i; Texts.Scan(S); mo := S.i; Texts.Scan(S); yr := S.i; Texts.Scan(S);
		hr := S.i; Texts.Scan(S); min := S.i; Texts.Scan(S); sec := S.i;
		IF yr > 1900 THEN DEC(yr, 1900) END;	(* compatible with old two-digit format *)
		t := (hr*64 + min)*64 + sec; d := (yr*16 + mo)*32 + day;
		Oberon.SetClock(t, d)
	ELSE (*read date*)
		Texts.WriteString(W, "System.Time");
		Oberon.GetClock(t, d); Texts.WriteDate(W, t, d);
		IF (S.class = Texts.Name) & (S.s = "start") THEN
			Texts.WriteString(W, ", started");
			time0 := t; date0 := d
		ELSIF (S.class = Texts.Name) & (S.s = "lap") THEN
			hr := t DIV 4096 MOD 32; min := t DIV 64 MOD 64; sec := t MOD 64;
			DEC(sec, time0 MOD 64);
			IF sec < 0 THEN INC(sec, 60); DEC(min) END;
			DEC(min, time0 DIV 64 MOD 64);
			IF min < 0 THEN INC(min, 60); DEC(hr) END;
			DEC(hr, time0 DIV 4096 MOD 32);
			IF hr < 0 THEN INC(hr, 24) END;	(* assume one day passed *)
			Texts.WriteString(W, ", "); WritePair(" ", hr);
			WritePair(":", min); WritePair(":", sec);
			Texts.WriteString(W, " elapsed");
			IF d # date0 THEN
				Texts.WriteString(W, " (may be incorrect due to date change)")
			END
		END;
		Texts.WriteLn(W);
		Texts.Append(Oberon.Log, W.buf)
	END
END Time;

(* Perform an immediate garbage collection. *)

PROCEDURE Collect*;
BEGIN
	Heaps.GC;	(* force garbage collection *)
	Kernel.GC	(* call Oberon finalizers *)
END Collect;

(* --- Toolbox for standard display *)

PROCEDURE Open*;
VAR par: Oberon.ParList; T: Texts.Text; S: Texts.Scanner; beg, end, time: LONGINT;
BEGIN
	par := Oberon.Par;
	Texts.OpenScanner(S, par.text, par.pos); Texts.Scan(S);
	IF (S.class = Texts.Char) & (S.c = "^") OR (S.line # 0) THEN
		Oberon.GetSelection(T, beg, end, time);
		IF time # -1 THEN Texts.OpenScanner(S, T, beg); Texts.Scan(S) END
	END;
	IF S.class IN {Texts.Name, Texts.String} THEN
		OpenText(S.s, TextFrames.Text(S.s), TRUE)
	END
END Open;

PROCEDURE OpenLog*;
BEGIN
	OpenText("System.Log", Oberon.Log, TRUE);
END OpenLog;

PROCEDURE Clear*;
VAR S: Texts.Scanner; par: Oberon.ParList; F: Display.Frame; L: Objects.LinkMsg; A: Objects.AttrMsg;
BEGIN
	par := Oberon.Par; F := NIL;
	L.id := Objects.get; L.name := "Model"; L.obj := NIL;
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
	IF (S.class = Texts.Char) & (S.c = "*") THEN
		F := Oberon.MarkedFrame()
	ELSIF (par.vwr # NIL) & (par.vwr.dsc # NIL) THEN
		F := par.vwr.dsc.next;
		F.handle(F, L);
		IF (L.obj # NIL) & (L.obj IS Display.Frame) THEN
			A.id := Objects.get; A.name := "Gen"; L.obj.handle(L.obj, A);
			IF A.s = "PanelDocs.NewDoc" THEN (* Desktop *)
				F := Oberon.Par.obj(Display.Frame);
				F := F.dlink(Display.Frame);
				F := F.next.dsc
			ELSE
				F := L.obj(Display.Frame)
			END
		END
	END;
	IF F # NIL THEN
		F.handle(F, L);
		IF (L.obj # NIL) & (L.obj IS Texts.Text) THEN
			Texts.Delete(L.obj(Texts.Text), 0, L.obj(Texts.Text).len)
		END
	END
END Clear;

PROCEDURE Close*;
VAR par: Oberon.ParList; V: Viewers.Viewer;
BEGIN
	par := Oberon.Par;
	IF par.frame = par.vwr.dsc THEN V := par.vwr
	ELSE V := Oberon.MarkedViewer()
	END;
	Viewers.Close(V)
END Close;

PROCEDURE CloseTrack*;
VAR V: Viewers.Viewer;
BEGIN
	V := Oberon.MarkedViewer(); Viewers.CloseTrack(V.X)
END CloseTrack;

PROCEDURE Recall*;
VAR V: Viewers.Viewer; M: Display.ControlMsg;
BEGIN
	Viewers.Recall(V);
	IF (V # NIL) & (V.state = 0) THEN
		Viewers.Open(V, V.X, V.Y + V.H); M.F := NIL; M.id := Display.restore; V.handle(V, M)
	END
END Recall;

PROCEDURE Copy*;
VAR V, V1: Viewers.Viewer; M: Objects.CopyMsg; N: Display.ControlMsg;
BEGIN
	M.id := Objects.shallow;
	V := Oberon.Par.vwr; V.handle(V, M); V1 := M.obj(Viewers.Viewer);
	Viewers.Open(V1, V.X, V.Y + V.H DIV 2);
	N.F := NIL; N.id := Display.restore; V1.handle(V1, N)
END Copy;

PROCEDURE Grow*;
VAR par: Oberon.ParList; V, V1: Viewers.Viewer; M: Objects.CopyMsg; N: Display.ControlMsg; DW, DH: INTEGER;
BEGIN
	par := Oberon.Par;
	IF par.frame = par.vwr.dsc THEN V := par.vwr
	ELSE V := Oberon.MarkedViewer()
	END;
	DW := Oberon.DisplayWidth(V.X); DH := Oberon.DisplayHeight(V.X);
	IF V.H < DH - Viewers.minH THEN Oberon.OpenTrack(V.X, V.W)
	ELSIF V.W < DW THEN Oberon.OpenTrack(Oberon.UserTrack(V.X), DW)
	END;
	IF (V.H < DH - Viewers.minH) OR (V.W < DW) THEN
		M.id := Objects.shallow;
		V.handle(V, M); V1 := M.obj(Viewers.Viewer);
		Viewers.Open(V1, V.X, DH);
		N.F := NIL; N.id := Display.restore; V1.handle(V1, N)
	END
END Grow;

(* --- Toolbox for module management *)

PROCEDURE Free*;
VAR par: Oberon.ParList; S: Texts.Scanner; F: TextFrames.Frame; time, beg, end, pos: LONGINT; T: Texts.Text;

	PROCEDURE FreeFile;
	(*VAR i: LONGINT;*)
	BEGIN
		(*IF S.nextCh # "*" THEN Modules.Free(S.s, FALSE)
		ELSE Modules.Free(S.s, TRUE); Texts.Scan(S)
		END*)
		(*i := 0;  WHILE (S.s[i] # 0X) & (S.s[i] # ".") DO INC(i) END;
		S.s[i] := 0X;*)
		Modules.Free(S.s, FALSE);
		IF Modules.res = 0 THEN
			Texts.WriteString(W, S.s); Texts.WriteString(W, " unloaded")
		ELSE
			Texts.WriteString(W, Modules.resMsg)
		END;
		Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
	END FreeFile;

BEGIN
	par := Oberon.Par;
	Oberon.GetSelection(T, beg, end, time);
	Texts.WriteString(W, "System.Free"); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
	IF (par.vwr.dsc = NIL) OR (par.vwr.dsc # par.frame) OR ~(par.vwr.dsc.next IS TextFrames.Frame) THEN
		Texts.OpenScanner(S, par.text, par.pos); Texts.Scan(S);
		IF (S.class = Texts.Char) & (S.c = "^") OR (S.class = Texts.Inval) THEN
			IF time # -1 THEN
				Texts.OpenScanner(S, T, beg); pos := Texts.Pos(S)-1; Texts.Scan(S);
				WHILE ~S.eot & (S.class = Texts.Name) & (pos < end) DO
					FreeFile;  pos := Texts.Pos(S); Texts.Scan(S);
					WHILE ~S.eot & (S.class = Texts.Int) DO pos := Texts.Pos(S); Texts.Scan(S) END
				END
			END
		ELSE
			WHILE S.class = Texts.Name DO FreeFile; Texts.Scan(S) END
		END
	ELSE
		F := par.vwr.dsc.next(TextFrames.Frame);
		IF F.sel > 0 THEN
			Texts.OpenScanner(S, F.text, F.selbeg.pos);
			WHILE ~S.eot & (Texts.Pos(S) < F.selend.pos) DO
				Texts.Scan(S);
				IF S.class = Texts.Name THEN FreeFile;
					IF Modules.res = 0 THEN
						Texts.OpenReader(S, F.text, F.selbeg.pos);
						REPEAT Texts.Read(S, S.nextCh) UNTIL S.eot OR (S.nextCh = 0DX);
						Texts.Delete(F.text, F.selbeg.pos, Texts.Pos(S));
						DEC(F.selend.pos, Texts.Pos(S) - F.selbeg.pos);
						Texts.OpenScanner(S, F.text, F.selbeg.pos);
					END
				ELSE F.selbeg.pos := Texts.Pos(S)
				END
			END
		END
	END
END Free;

PROCEDURE WriteK(VAR W: Texts.Writer;  k: LONGINT);
VAR suffix: CHAR;
BEGIN
	IF k < 100*1024 THEN suffix := "K"
	ELSIF k < 100*1024*1024 THEN suffix := "M"; k := k DIV 1024
	ELSE suffix := "G"; k := k DIV (1024*1024)
	END;
	Texts.WriteInt(W, k, 1);  Texts.Write(W, suffix);  Texts.Write(W, "B")
END WriteK;

PROCEDURE ShowModules*;
VAR T: Texts.Text; M: Modules.Module; n, t: LONGINT; size: SIZE; tag: ADDRESS;
BEGIN
	T := TextFrames.Text("");
	M := AosModules.root; n := 0; t := 0;
	WHILE M # NIL DO
		SYSTEM.GET(SYSTEM.VAL(ADDRESS, M.code)- SIZEOF (ADDRESS), tag);	(* indirect tag *)
		SYSTEM.GET(tag, size);
		Texts.WriteString(W, M.name); Texts.WriteInt(W, LONGINT (size), 8);
		Texts.WriteInt(W, M.refcnt, 4);
		Texts.WriteLn(W); M := M.next;
		INC(n); INC(t, LONGINT (size))
	END;
	IF n > 1 THEN
		Texts.WriteLn(W); Texts.WriteInt(W, n, 1); Texts.WriteString(W, " modules use ");
		WriteK(W, (t+512) DIV 1024)
	END;
	M := AosModules.freeRoot;
	IF M # NIL THEN
		Texts.WriteLn(W);  Texts.WriteLn(W);
		WHILE M # NIL DO
			Texts.WriteString(W, M.name);  Texts.WriteLn(W);  M := M.next
		END
	END;
	Texts.WriteLn(W); Texts.Append(T, W.buf);
	OpenText("Modules|System.Close System.Free Edit.Search Edit.Store", T, TRUE)
END ShowModules;

(* --- Toolbox for library management *)

PROCEDURE ListLibrary (L: Objects.Library);
BEGIN
	Texts.WriteString(W, L.name); Texts.WriteLn(W); INC(count)
END ListLibrary;

PROCEDURE ShowLibraries*;
VAR t: Texts.Text;
BEGIN
	t := TextFrames.Text(""); count := 0;
	Objects.Enumerate(ListLibrary);
	IF count > 1 THEN
		Texts.WriteLn(W);  Texts.WriteInt(W, count, 1);  Texts.WriteString(W, " public libraries")
	END;
	Texts.WriteLn(W);  Texts.Append(t, W.buf);
	OpenText("Libraries", t, TRUE)
END ShowLibraries;

PROCEDURE FreeLibraries*;
VAR par: Oberon.ParList; T: Texts.Text; S: Texts.Scanner; beg, end, time: LONGINT;
BEGIN
	par := Oberon.Par;
	Texts.WriteString(W, "System.FreeLibraries "); Texts.WriteLn(W);
	Texts.OpenScanner(S, par.text, par.pos); Texts.Scan(S);
	IF (S.class = Texts.Char) & (S.c = "^") THEN
		Oberon.GetSelection(T, beg, end, time);
		IF time # -1 THEN Texts.OpenScanner(S, T, beg); Texts.Scan(S)
		ELSE S.class := Texts.Inval
		END
	ELSE end := MAX(LONGINT)
	END;
	WHILE (S.class = Texts.Name) & (Texts.Pos(S) <= end) DO
		Objects.FreeLibrary(S.s); Texts.WriteString(W,S.s); Texts.WriteLn(W);
		Texts.Scan(S)
	END;
	Texts.Append(Oberon.Log, W.buf)
END FreeLibraries;

(* --- Toolbox of file system *)

PROCEDURE Directory*;
VAR
	beg, end, time, date, size, count, total: LONGINT; enum: AosFS.Enumerator;
	par: Oberon.ParList; R: Texts.Reader; T, t: Texts.Text; flags, fileflags: SET;
	diroption, ch: CHAR; pat: ARRAY 32 OF CHAR;
	name: AosFS.FileName;

	PROCEDURE ReadString(VAR s: ARRAY OF CHAR);
	VAR i, m: LONGINT;
	BEGIN
		Texts.Read(R, ch);
		WHILE ~R.eot & (R.lib IS Fonts.Font) & (ch <= " ") & (ch # 0DX) DO Texts.Read(R, ch) END;
		i := 0; m := LEN(s)-1;
		IF ch = 22X THEN
			Texts.Read(R, ch);
			WHILE ~R.eot & (R.lib IS Fonts.Font) & (ch # 22X) & (ch # 0DX) & (i # m) DO
				s[i] := ch; INC(i); Texts.Read(R, ch)
			END;
			IF ~R.eot & (ch = 22X) THEN Texts.Read(R, ch) END
		ELSE
			WHILE ~R.eot & (R.lib IS Fonts.Font) & (ch > " ") & (ch # Oberon.OptionChar) & (i # m) DO
				s[i] := ch; INC(i); Texts.Read(R, ch)
			END
		END;
		s[i] := 0X
	END ReadString;

BEGIN
	par := Oberon.Par;
	Texts.OpenReader(R, par.text, par.pos); ReadString(pat);
	IF (pat[0] = "^") OR (pat[0] = 0X) THEN
		Oberon.GetSelection(T, beg, end, time);
		IF time # -1 THEN
			Texts.OpenReader(R, T, beg); ReadString(pat)
		END
	END;
	IF ch = Oberon.OptionChar THEN Texts.Read(R, diroption) ELSE diroption := 0X END;
	IF diroption = "d" THEN flags := {AosFS.EnumSize, AosFS.EnumTime} ELSE flags := {} END;
	NEW(enum);
	enum.Open(pat, flags);
	count := 0; total := 0;
	WHILE enum.GetEntry(name, fileflags, time, date, size) DO
		INC(count);
		Texts.WriteString(W, name);
		IF AosFS.EnumTime IN flags THEN
		    Texts.Write(W, 9X); Texts.WriteDate(W, time, date)
		END;
		IF AosFS.EnumSize IN flags THEN
			Texts.Write(W, 9X); Texts.WriteInt(W, size, 1);
			INC(total, size)
		END;
		Texts.WriteLn(W)
	END;
	enum.Close;
	NEW(t); Texts.Open(t, "");
	IF count > 1 THEN
		Texts.WriteLn(W);  Texts.WriteInt(W, count, 1); Texts.WriteString(W, " files");
		IF AosFS.EnumSize IN flags THEN
			Texts.WriteString(W, " use "); WriteK(W, (total+1023) DIV 1024)
		END
	END;
	Texts.Append(t, W.buf);
	OpenText("Directory", t, TRUE)
END Directory;

PROCEDURE CopyFile(name: ARRAY OF CHAR; VAR S: Texts.Scanner);
CONST BufLen = 8192;
VAR f, g: Files.File; Rf, Rg: Files.Rider; buf : ARRAY BufLen OF CHAR; i: LONGINT;
BEGIN
	Texts.Scan(S);
	IF (S.class = Texts.Char) & (S.c = "=") THEN
		Texts.Scan(S);
		IF (S.class = Texts.Char) & (S.c = ">") THEN
			Texts.Scan(S);
			IF S.class IN {Texts.Name, Texts.String} THEN
				Texts.WriteString(W, name); Texts.WriteString(W, " => "); Texts.WriteString(W, S.s);
				Texts.WriteString(W, " copying"); Texts.Append(Oberon.Log, W.buf);
				f := Files.Old(name);
				IF f # NIL THEN g := Files.New(S.s) END;
				IF (f # NIL) & (g # NIL) THEN
					Files.Set(Rf, f, 0); Files.Set(Rg, g, 0);
					i := 0;
					WHILE i < Files.Length(f) DIV BufLen DO
						Files.ReadBytes(Rf,buf,BufLen); Files.WriteBytes(Rg,buf,BufLen); INC(i)
					END;
					Files.ReadBytes(Rf, buf, Files.Length(f) MOD BufLen);
					Files.WriteBytes(Rg, buf, Files.Length(f) MOD BufLen);
					Files.Register(g)
				ELSE
					Texts.WriteString(W, " failed"); S.eot := TRUE
				END;
				Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
			END
		END
	END
END CopyFile;

PROCEDURE CopyFiles*;
VAR beg, end, time: LONGINT; T: Texts.Text; S: Texts.Scanner;
BEGIN
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
	Texts.WriteString(W, "System.CopyFiles"); Texts.WriteLn(W);
	Texts.Append(Oberon.Log, W.buf);
	IF (S.class = Texts.Char) & (S.c = "^") THEN
		Oberon.GetSelection(T, beg, end, time);
		IF time # -1 THEN
			Texts.OpenScanner(S, T, beg); Texts.Scan(S);
			IF S.class IN {Texts.Name, Texts.String} THEN CopyFile(S.s, S) END
		END
	ELSE
		WHILE ~S.eot & (S.class IN {Texts.Name, Texts.String}) DO
			CopyFile(S.s, S); IF ~S.eot THEN Texts.Scan(S) END
		END
	END
END CopyFiles;

PROCEDURE RenameFile (name: ARRAY OF CHAR; VAR S: Texts.Scanner);
VAR res: INTEGER;
BEGIN
	Texts.Scan(S);
	IF (S.class = Texts.Char) & (S.c = "=") THEN
		Texts.Scan(S);
		IF (S.class = Texts.Char) & (S.c = ">") THEN
			Texts.Scan(S);
			IF S.class IN {Texts.Name, Texts.String} THEN
				Texts.WriteString(W, name); Texts.WriteString(W, " => "); Texts.WriteString(W, S.s);
				Texts.WriteString(W, " renaming"); Texts.Append(Oberon.Log, W.buf);
				Files.Rename(name, S.s, res);
				IF (res < 0) OR (res > 1) THEN Texts.WriteString(W, " failed"); S.eot := TRUE END;
				Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
			END
		END
	END
END RenameFile;

PROCEDURE RenameFiles*;
VAR beg, end, time: LONGINT; T: Texts.Text; S: Texts.Scanner;
BEGIN
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
	Texts.WriteString(W, "System.RenameFiles"); Texts.WriteLn(W);
	Texts.Append(Oberon.Log, W.buf);
	IF (S.class = Texts.Char) & (S.c = "^") THEN
		Oberon.GetSelection(T, beg, end, time);
		IF time # -1 THEN
			Texts.OpenScanner(S, T, beg); Texts.Scan(S);
			IF S.class IN {Texts.Name, Texts.String} THEN RenameFile(S.s, S) END
		END
	ELSE
		WHILE ~S.eot & (S.class IN {Texts.Name, Texts.String}) DO
			RenameFile(S.s, S); IF ~S.eot THEN Texts.Scan(S) END
		END
	END
END RenameFiles;

PROCEDURE DeleteFile(VAR name: ARRAY OF CHAR;  VAR S: Texts.Scanner);
VAR res: INTEGER;
BEGIN
	Texts.WriteString(W, name); Texts.WriteString(W, " deleting");
	Texts.Append(Oberon.Log, W.buf); Files.Delete(name, res);
	IF res # 0 THEN Texts.WriteString(W, " failed"); S.eot := TRUE END;
	Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
END DeleteFile;

PROCEDURE DeleteFiles*;
VAR beg, end, time: LONGINT; T: Texts.Text; S: Texts.Scanner;
BEGIN
	Oberon.GetSelection(T, beg, end, time);
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
	Texts.WriteString(W, "System.DeleteFiles"); Texts.WriteLn(W);
	Texts.Append(Oberon.Log, W.buf);
	IF (S.class = Texts.Char) & (S.c = "^") THEN
		IF time # -1 THEN
			Texts.OpenScanner(S, T, beg); Texts.Scan(S);
			IF S.class IN {Texts.Name, Texts.String} THEN DeleteFile(S.s, S) END
		END
	ELSE
		WHILE ~S.eot & (S.class IN {Texts.Name, Texts.String}) DO
			DeleteFile(S.s, S); IF ~S.eot THEN Texts.Scan(S) END
		END
	END
END DeleteFiles;

(* --- Toolbox for system inspection *)

PROCEDURE Watch*;
VAR free, total, largest, low, high, i: SIZE;  list: AosFS.FileSystemTable; fs: AosFS.FileSystem;
BEGIN
	Texts.WriteString(W, "System.Watch");  Texts.WriteLn(W);
	AosFS.GetList(list);
	IF list # NIL THEN
		FOR i := 0 TO LEN(list)-1 DO
			fs := list[i];
			Texts.Write(W, 9X);  Texts.WriteString(W, fs.prefix);  Texts.WriteString(W, ": ");
			IF fs.vol # NIL THEN
				free := ENTIER(fs.vol.Available()/1024.0D0 * fs.vol.blockSize);
				total := ENTIER(fs.vol.size/1024.0D0 * fs.vol.blockSize);
				WriteK(W, LONGINT(free));  Texts.WriteString(W, " of ");
				WriteK(W, LONGINT(total));  Texts.WriteString(W, " free")
			ELSE
				Texts.WriteString(W, fs.desc)
			END;
			Texts.WriteLn(W)
		END
	END;
		(* heap info *)
	Heaps.GetHeapInfo(total, free, largest);
	(*total := (total+512) DIV 1024;*)
	free := (free+512) DIV 1024;
	largest := (largest+512) DIV 1024;
	Machine.GetFreeK(total, low, high);
	INC(free, low+high);
	IF high > largest THEN largest := high END;
	IF low > largest THEN largest := low END;
	Texts.Write(W, 9X); Texts.WriteString(W, "Heap has ");
	WriteK(W, LONGINT(free)); Texts.WriteString(W, " of ");
	WriteK(W, LONGINT(total)); Texts.WriteString(W, " free (");
	WriteK(W, LONGINT(largest)); Texts.WriteString(W, " contiguous)");  Texts.WriteLn(W);
	Texts.Append(Oberon.Log, W.buf)
END Watch;

PROCEDURE GetNum(refs: Bytes;  VAR i, num: LONGINT);
VAR n, s: LONGINT;  x: CHAR;
BEGIN
	s := 0;  n := 0;  x := refs[i];  INC(i);
	WHILE ORD(x) >= 128 DO
		INC(n, ASH(ORD(x) - 128, s));  INC(s, 7);  x := refs[i];  INC(i)
	END;
	num := n + ASH(ORD(x) MOD 64 - ORD(x) DIV 64 * 64, s)
END GetNum;

(*
	Reference = {OldRef | ProcRef} .
	OldRef = 0F8X offset/n name/s {Variable} .
	ProcRef = 0F9X offset/n nofPars/n RetType procLev/1 slFlag/1 name/s {Variable} .
	RetType = 0X | Var | ArrayType | Record .
	ArrayType = 12X | 14X | 15X .	(* static array, dynamic array, open array *)
	Record = 16X .
	Variable = VarMode (Var | ArrayVar | RecordVar ) offset/n name/s .
	VarMode = 1X | 3X .	(* direct, indirect *)
	Var = 1X .. 0FX .	(* byte, boolean, char, shortint, integer, longint, real, longreal, set, ptr, proc, string *)
	ArrayVar = (81X .. 8EX) dim/n .	(* byte, boolean, char, shortint, integer, longint, real, longreal, set, ptr, proc *)
	RecordVar = (16X | 1DX) tdadr/n .	(* record, recordpointer *)
*)

(* FindProc - Find a procedure in the reference block.  Return index of name, or -1 if not found. *)

PROCEDURE FindProc(refs: Bytes;  ofs: LONGINT): LONGINT;
VAR i, m, t, proc: LONGINT;  ch: CHAR;
BEGIN
	proc := -1;  i := 0;  m := LEN(refs^);
	ch := refs[i];  INC(i);
	WHILE (i < m) & ((ch = 0F8X) OR (ch = 0F9X)) DO	(* proc *)
		GetNum(refs, i, t);	(* pofs *)
		IF t > ofs THEN	(* previous procedure was the one *)
			ch := 0X	(* stop search *)
		ELSE	(* ~found *)
			IF ch = 0F9X THEN
				GetNum(refs, i, t);	(* nofPars *)
				INC(i, 3)	(* RetType, procLev, slFlag *)
			END;
			proc := i;	(* remember this position, just before the name *)
			REPEAT ch := refs[i];  INC(i) UNTIL ch = 0X;	(* pname *)
			IF i < m THEN
				ch := refs[i];  INC(i);	(* 1X | 3X | 0F8X | 0F9X *)
				WHILE (i < m) & (ch >= 1X) & (ch <= 3X) DO	(* var *)
					ch := refs[i];  INC(i);	(* type *)
					IF (ch >= 81X) OR (ch = 16X) OR (ch = 1DX) THEN
						GetNum(refs, i, t)	(* dim/tdadr *)
					END;
					GetNum(refs, i, t);	(* vofs *)
					REPEAT ch := refs[i];  INC(i) UNTIL ch = 0X;	(* vname *)
					IF i < m THEN ch := refs[i];  INC(i) END	(* 1X | 3X | 0F8X | 0F9X *)
				END
			END
		END
	END;
	IF (proc = -1) & (i # 0) THEN proc := i END;	(* first procedure *)
	RETURN proc
END FindProc;

PROCEDURE WriteProc(mod: Modules.Module;  pc, fp: ADDRESS;  VAR refs: Bytes;  VAR refpos, base: LONGINT);
VAR ch: CHAR;
BEGIN
	refpos := -1;
	IF mod = NIL THEN
		Texts.WriteString(W, "Unknown EIP =");  Texts.WriteHex(W, LONGINT(pc));  Texts.Write(W, "H");
		IF fp # -1 THEN
			Texts.WriteString(W, " EBP =");  Texts.WriteHex(W, LONGINT(fp));  Texts.Write(W, "H")
		END
	ELSE
		Texts.WriteString(W, mod.name);
		DEC(pc, LONGINT(ADDRESSOF(mod.code[0])));
		refs := SYSTEM.VAL(Bytes, mod.refs);
		IF (refs # NIL) & (LEN(mod.refs) # 0) THEN
			refpos := FindProc(refs, LONGINT(pc));
			IF refpos # -1 THEN
				Texts.Write(W, ".");
				ch := refs[refpos];  INC(refpos);
				IF ch = "$" THEN base := LONGINT(mod.sb) ELSE base := LONGINT(fp) END;	(* for variables *)
				WHILE ch # 0X DO Texts.Write(W, ch);  ch := refs[refpos];  INC(refpos) END
			END
		END;
		Texts.WriteString(W, "  PC = "); Texts.WriteInt(W, LONGINT(pc), 1)
	END
END WriteProc;

PROCEDURE Variables(refs: Bytes;  i, base: LONGINT);
VAR
	mode, ch: CHAR;  m, adr, type, n, lval, size, tmp1, tmp2, tdadr: LONGINT;  etc: BOOLEAN;
	sval: SHORTINT;  ival: INTEGER;  tmp: Bytes;  set: SET;
	rval: REAL;  lrval: LONGREAL;
BEGIN
	m := LEN(refs^);  mode := refs[i];  INC(i);
	WHILE (i < m) & (mode >= 1X) & (mode <= 3X) DO	(* var *)
		type := ORD(refs[i]);  INC(i);  etc := FALSE;
		IF type > 80H THEN
			IF type = 83H THEN type := 15 ELSE DEC(type, 80H) END;
			GetNum(refs, i, n)
		ELSIF (type = 16H) OR (type = 1DH) THEN
			GetNum(refs, i, tdadr); n := 1
		ELSE
			IF type = 15 THEN n := MaxString (* best guess *) ELSE n := 1 END
		END;
		GetNum(refs, i, adr);
		Texts.Write(W, 9X);  ch := refs[i];  INC(i);
		WHILE ch # 0X DO Texts.Write(W, ch);  ch := refs[i];  INC(i) END;
		Texts.WriteString(W, " = ");
		INC(adr, base);
		IF n = 0 THEN	(* open array *)
			SYSTEM.GET(adr+4, n)	(* real LEN from stack *)
		END;
		IF type = 15 THEN
			IF n > MaxString THEN etc := TRUE;  n := MaxString END
		ELSE
			IF n > MaxArray THEN etc := TRUE;  n := MaxArray END
		END;
		IF mode # 1X THEN SYSTEM.GET(adr, adr) END;	(* indirect *)
		IF (adr >= -4) & (adr < 4096) THEN
			Texts.WriteString(W, "NIL reference (");  Texts.WriteHex(W, adr);  Texts.WriteString(W, "H )")
		ELSE
			IF type = 15 THEN
				Texts.Write(W, 22X);
				LOOP
					IF n = 0 THEN EXIT END;
					SYSTEM.GET(adr, ch);  INC(adr);
					IF (ch < " ") OR (ch > "~") THEN EXIT END;
					Texts.Write(W, ch);  DEC(n)
				END;
				Texts.Write(W, 22X);  etc := (ch # 0X)
			ELSE
				CASE type OF
					1..4: size := 1
					|5: size := 2
					|6..7,9,13,14,29: size := 4
					|8, 16: size := 8
					|22: size := 0; ASSERT(n <= 1)
				ELSE
					Texts.WriteString(W, "bad type ");  Texts.WriteInt(W, type, 1);  n := 0
				END;
				WHILE n > 0 DO
					CASE type OF
						1,3:	(* BYTE, CHAR *)
							SYSTEM.GET(adr, ch);
							IF (ch > " ") & (ch <= "~") THEN Texts.Write(W, ch)
							ELSE Texts.WriteHex(W, ORD(ch));  Texts.Write(W, "X")
							END
						|2:	(* BOOLEAN *)
							SYSTEM.GET(adr, ch);
							IF ch = 0X THEN Texts.WriteString(W, "FALSE")
							ELSIF ch = 1X THEN Texts.WriteString(W, "TRUE")
							ELSE Texts.WriteInt(W, ORD(ch), 1)
							END
						|4:	(* SHORTINT *)
							SYSTEM.GET(adr, sval);  Texts.WriteInt(W, sval, 1)
						|5:	(* INTEGER *)
							SYSTEM.GET(adr, ival);  Texts.WriteInt(W, ival, 1)
						|6:	(* LONGINT *)
							SYSTEM.GET(adr, lval);  Texts.WriteInt(W, lval, 1)
						|7:	(* REAL *)
							SYSTEM.GET(adr, rval);  Texts.WriteReal(W, rval, 15)
						|8:	(* LONGREAL *)
							SYSTEM.GET(adr, lrval);  Texts.WriteLongReal(W, lrval, 24)
						|9:	(* SET *)
							SYSTEM.GET(adr, set);  Texts.WriteSet(W, set)
						|13, 29:	(* POINTER *)
							SYSTEM.GET(adr, lval);  Texts.WriteHex(W, lval);  Texts.Write(W, "H")
						|14:	(* PROC *)
							SYSTEM.GET(adr, lval);
							IF lval = 0 THEN Texts.WriteString(W, "NIL")
							ELSE WriteProc(AosModules.ThisModuleByAdr(lval), lval, -1, tmp, tmp1, tmp2)
							END
						|16:	(* HUGEINT *)
							Texts.WriteHex(W, SYSTEM.GET32(adr+4));
							Texts.WriteHex(W, SYSTEM.GET32(adr))
						|22:	(* RECORD *)
							Texts.WriteHex(W, tdadr);  Texts.Write(W, "H")
					END;
					DEC(n);  INC(adr, size);
					IF n > 0 THEN Texts.WriteString(W, ", ") END
				END
			END
		END;
		IF etc THEN Texts.WriteString(W, " ...") END;
		Texts.WriteLn(W);
		IF i < m THEN mode := refs[i];  INC(i) END
	END
END Variables;

PROCEDURE OutState (VAR name: ARRAY OF CHAR; t: Texts.Text);
VAR mod: Modules.Module; refpos, i: LONGINT; refs: Bytes;  ch: CHAR;
BEGIN
	i := 0;  WHILE (name[i] # 0X) & (name[i] # ".") DO INC(i) END;
	name[i] := 0X;
	Texts.WriteString(W, name); mod := AosModules.root;
	WHILE (mod # NIL) & (mod.name # name) DO mod := mod.next END;
	IF mod # NIL THEN
		Texts.WriteString(W, "  SB ="); Texts.WriteHex(W, LONGINT(mod.sb)); Texts.Write(W, "H");  Texts.WriteLn(W);
		refs := SYSTEM.VAL(Bytes, mod.refs);
		IF (refs # NIL) & (LEN(mod.refs) # 0) THEN
			refpos := FindProc(refs, 0);	(* assume module body is at PC = 0 (not true for OMI) *)
			IF refpos # -1 THEN
				REPEAT ch := refs[refpos];  INC(refpos) UNTIL ch = 0X;
				Variables(refs, refpos, LONGINT(mod.sb))
			END
		END
	ELSE
		Texts.WriteString(W, " not loaded");  Texts.WriteLn(W)
	END;
	Texts.Append(t, W.buf)
END OutState;

PROCEDURE State*;
VAR T: Texts.Text; S: Texts.Scanner; beg, end, time: LONGINT;
BEGIN
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
	IF (S.class = Texts.Char) & (S.c = "^") THEN
		Oberon.GetSelection(T, beg, end, time);
		IF time # -1 THEN Texts.OpenScanner(S, T, beg); Texts.Scan(S) END
	END;
	IF S.class = Texts.Name THEN
		T := TextFrames.Text(""); OutState(S.s, T);
		OpenText("State", T, TRUE)
	END
END State;

PROCEDURE ShowCommands*;
VAR M: Modules.Module; beg, end, time: LONGINT; T: Texts.Text; S: Texts.Scanner; i: INTEGER;
BEGIN
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
	IF (S.class = Texts.Char) & (S.c = "^") THEN
		Oberon.GetSelection(T, beg, end, time);
		IF time # -1 THEN Texts.OpenScanner(S, T, beg); Texts.Scan(S) END
	END;
	IF S.class = Texts.Name THEN
		i := 0; WHILE (S.s[i] # 0X) & (S.s[i] # ".") DO INC(i) END; S.s[i] := 0X;
		M := Modules.ThisMod(S.s);
		IF M # NIL THEN
			T := TextFrames.Text("");
			i := 0;
			WHILE i < LEN(M.command) DO
				IF M.command[i].entryAdr # Heaps.NilVal THEN (* only show Oberon commands *)
					Texts.WriteString(W, S.s); Texts.Write(W, ".");
					Texts.WriteString(W, M.command[i].name);
					Texts.WriteLn(W)
				END;
				INC(i)
			END;
			Texts.Append(T, W.buf);
			OpenText("Commands", T, TRUE)
		ELSE
			Texts.WriteString(W, Modules.resMsg);  Texts.WriteLn(W);
			Texts.Append(Oberon.Log, W.buf)
		END
	END
END ShowCommands;

PROCEDURE ShowTasks*;
VAR T: Texts.Text;  n: Oberon.Task;  ofs: ADDRESS; t: LONGINT;  m: Modules.Module;
BEGIN
	n := Oberon.NextTask;  t := Input.Time();
	REPEAT
		ofs := SYSTEM.VAL(ADDRESS, n.handle);  m := AosModules.ThisModuleByAdr(ofs);
		Texts.WriteString(W, m.name);  Texts.WriteString(W, "  PC = ");
		Texts.WriteInt(W, LONGINT(ofs-ADDRESSOF(m.code[0])), 1);
		IF n.safe THEN Texts.WriteString(W, "  safe  ")
		ELSE Texts.WriteString(W, "  unsafe  ")
		END;
		Texts.WriteInt(W, n.time, 1);
		IF n.time - t <= 0 THEN
			Texts.WriteString(W, " ready")
		ELSE
			Texts.WriteString(W, " waiting ");  Texts.WriteInt(W, (n.time-t)*1000 DIV Input.TimeUnit, 1);
			Texts.WriteString(W, "ms")
		END;
		Texts.WriteLn(W);
		n := n.next
	UNTIL n = Oberon.NextTask;
	T := TextFrames.Text("");
	Texts.Append(T, W.buf);
	OpenText("Tasks", T, TRUE)
END ShowTasks;

(*
PROCEDURE WriteTrap(VAR W: Texts.Writer;  error, page: LONGINT);
BEGIN
	Texts.WriteString(W, "TRAP "); Texts.WriteInt(W, error, 1);
	Texts.WriteString(W, "  ");
	IF error > 0 THEN
		CASE error OF
			1: Texts.WriteString(W, "WITH guard failed")
			|2: Texts.WriteString(W, "CASE invalid")
			|3: Texts.WriteString(W, "RETURN missing")
			|5: Texts.WriteString(W, "Implicit type guard failed")
			|6: Texts.WriteString(W, "Type guard failed")
			|7: Texts.WriteString(W, "Index out of range")
			|8: Texts.WriteString(W, "ASSERT failed")
			|9: Texts.WriteString(W, "Array dimension error")
			|13: Texts.WriteString(W, "Keyboard interrupt")
			|14: Texts.WriteString(W, "Out of memory")
			|15: Texts.WriteString(W, "Bad sector number")
			|16: Texts.WriteString(W, "Disk full")
			|17: Texts.WriteString(W, "Disk error")
			|18: Texts.WriteString(W, "File too large")
			|19: Texts.WriteString(W, "Buffer overflow")
				(* for NCFS/OFS *)
			|20: Texts.WriteString(W, "Volume full")
			|21: Texts.WriteString(W, "Volume write-protected")
			|22: Texts.WriteString(W, "Volume not found")
			|23: Texts.WriteString(W, "Illegal Access")
			|24: Texts.WriteString(W, "Volume in use")
			|25: Texts.WriteString(W, "Volume modified")
			|26: Texts.WriteString(W, "Not a valid volume")
			|27: Texts.WriteString(W, "Cannot contact server ")
		ELSE
			IF error = MAX(INTEGER) THEN Texts.WriteString(W, "Trace ");  Texts.WriteInt(W, trap, 1);  INC(trap)
			ELSE Texts.WriteString(W, "HALT statement")
			END
		END
	ELSE
		error := -error;
		IF (error >= 32) & (error <= 39) THEN Texts.WriteString(W, "Floating-point ") END;
		CASE error OF
			0,32: Texts.WriteString(W, "Division by zero")
			|4,33: Texts.WriteString(W, "Overflow")
			|6: Texts.WriteString(W, "Invalid instruction")
			|12: Texts.WriteString(W, "Stack overflow")
			|13: Texts.WriteString(W, "General protection fault")
			|14:	(* page fault *)
				IF (page >= -4) & (page < 4096) THEN Texts.WriteString(W, "NIL reference (")
				(*ELSIF (page >= 100000H) & (page < Kernel.StackOrg) THEN Texts.WriteString(W, "Stack overflow (")*)
				ELSE Texts.WriteString(W, "Page fault (")
				END;
				Texts.WriteHex(W, page);  Texts.WriteString(W, "H )")
			|34: Texts.WriteString(W, "operation invalid")
			|35: Texts.WriteString(W, "stack fault")
		ELSE Texts.WriteString(W, "CPU exception")
		END
	END
END WriteTrap;

PROCEDURE Trap*(error, fp, pc, page: LONGINT);	(** non-portable *)	(* exported for Debug debugger *)
VAR
	T: Texts.Text;  refpos: LONGINT;
	mod: Modules.Module;  lastfp, base: LONGINT;  refs: Bytes;
BEGIN
	IF trapped = 0 THEN
		trapped := 1;
		Display.ResetClip;
		IF Kernel.copro THEN Reals.SetFCR(Reals.DefaultFCR) ELSE resetfp() END;
		IF error # MAX(INTEGER) THEN Viewers.Close(NIL) END;	(* close offending viewer, if any *)
		T := TextFrames.Text("");
		mod := AosModules.ThisModuleByAdr(pc);
		WriteTrap(W, error, page); Texts.WriteLn(W);
		LOOP
			WriteProc(mod, pc, fp, refs, refpos, base);  Texts.WriteLn(W);
			IF refpos # -1 THEN Variables(refs, refpos, base) END;
			lastfp := fp;
			SYSTEM.GET(fp+4, pc);  SYSTEM.GET(fp, fp); (* return addr from stack *)
			(*IF (fp < lastfp) OR (fp >= Kernel.StackOrg) THEN EXIT END; (* not called from stack *)*)
			IF fp = 0 THEN EXIT END;
			mod := AosModules.ThisModuleByAdr(pc)
		END;
		Texts.Append(T, W.buf);
		OpenText("Trap", T, TRUE)
	ELSIF trapped = 1 THEN
		trapped := 2;
		T := TextFrames.Text(""); Texts.WriteLn(W);
		Texts.WriteString(W, "TRAP "); Texts.WriteInt(W, error, 3);  Texts.WriteString(W, " (recursive)");
		Texts.WriteLn(W); Texts.Append(T, W.buf);
		OpenText("Trap", T, TRUE)
	ELSIF trapped = 2 THEN
		trapped := 3;
		Texts.WriteLn(W);  Texts.WriteString(W, "TRAP "); Texts.WriteInt(W, error, 3);
		Texts.WriteString(W, " (recursive)");  Texts.WriteLn(W);  Texts.Append(Oberon.Log, W.buf)
	ELSE (* skip *)
	END;
	trapped := 0
END Trap;
*)

(* Returns TRUE iff Oberon is running in "stand-alone" mode. *)

PROCEDURE Standalone(): BOOLEAN;
BEGIN
	RETURN AosModules.ModuleByName(WMWindowManager) = NIL
END Standalone;

PROCEDURE FreeOberon;
VAR context : Commands.Context; arg : Streams.StringReader; res: WORD; msg: ARRAY 128 OF CHAR;
BEGIN
	Oberon.OpenTrack(0, Display.Width);	(* inhibit display updates *)
	COPY(OberonBaseModule, msg);
	NEW(arg, LEN(msg)); arg.SetRaw(msg, 0, LEN(msg));
	NEW(context, NIL, arg, NIL, NIL, NIL);
	Commands.Activate("System.FreeDownTo", context, {}, res, msg);
	Kernel.UnlockOberon;
	AosActive.Terminate	(* kill Oberon process in an unclean way (race with above! workaround in System.Mod) *)
END FreeOberon;

PROCEDURE Quit*;
BEGIN
	IF Standalone() THEN
		AosModules.Shutdown(AosModules.PowerDown)
	ELSE
		FreeOberon
	END
END Quit;

PROCEDURE Reboot*;	(** non-portable *)
BEGIN
	IF Standalone() THEN
		AosModules.Shutdown(AosModules.Reboot)
	ELSE
		FreeOberon
	END
END Reboot;

PROCEDURE LogHandler(me: Oberon.Task);
VAR i: LONGINT; t: Texts.Text; ch: CHAR; s: ARRAY 512 OF CHAR;
BEGIN
	t := log;
	REPEAT
		KernelLog.GetBuffer(s);
		i := 0;
		LOOP
			ch := s[i];
			IF ch = 0X THEN EXIT END;
			IF (ch < 20X) & (ORD(ch) IN {01H, 02H, 03H, 0DH, 0AH, 0EH, 0FH}) THEN
				IF ch = 01X THEN	(* start trap *)
					IF t = log THEN	(* flush buffer to kernel log text *)
						Texts.Append(t, LogW.buf);
						t := TextFrames.Text("");
						OpenText("Trap", t, TRUE)
					END
				ELSIF ch = 02X THEN	(* stop trap *)
					IF t # log THEN	(* flush buffer to trap text *)
						Texts.Append(t, LogW.buf); t := log
					END
				ELSIF ch = 03X THEN
					Texts.WriteString(LogW, " **overflow**"); Texts.WriteLn(LogW)
				ELSIF ch = 0DX THEN Texts.WriteLn(LogW)
				ELSIF ch = 0EX THEN Texts.SetFont(LogW, fixed)
				ELSIF ch = 0FX THEN Texts.SetFont(LogW, Fonts.Default)
				ELSE (* skip *)
				END
			ELSE
				Texts.Write(LogW, ch)
			END;
			INC(i)
		END
	UNTIL i = 0;
	IF LogW.buf.len # 0 THEN	(* flush buffer to kernel log or trap text *)
		Texts.Append(t, LogW.buf)
	END;
	me.time := Input.Time() + LogTime
END LogHandler;

PROCEDURE OpenKernelLog*;	(** non-portable *)
BEGIN
	IF log = NIL THEN NEW(log); Texts.Open(log, "") END;
	IF task = NIL THEN
		Texts.WriteString(W, "Execute System.StartLog to enable logging"); Texts.WriteLn(W);
		Texts.Append(log, W.buf)
	END;
	OpenText("Kernel.Log|System.Close System.Copy Edit.Search System.Clear", log, TRUE)
END OpenKernelLog;

PROCEDURE Init*;	(** non-portable, for internal use *)
VAR S: Texts.Scanner; Wt: Texts.Writer; T: Texts.Text; F: TextFrames.Frame; ok: BOOLEAN;
BEGIN
	IF ~Machine.AtomicTestSet(init) THEN	(* avoid user call and ignore restart due to exception *)
		Texts.OpenWriter(Wt);
		Oberon.OpenScanner(S, "System.InitCommands");
		IF S.class = Texts.Inval THEN
			OpenLog;
			OpenText("System.Tool", TextFrames.Text("System.Tool"), TRUE);
			StartLog
		ELSE
			WHILE ~S.eot & (S.class = Texts.Char) & (S.c = "{") DO
				ok := FALSE;  Texts.Scan(S);
				IF S.class = Texts.Name THEN
					ok := TRUE;  Texts.WriteString(Wt, S.s)
				END;
				IF ~((S.class = Texts.Char) & (S.c = "}")) THEN
					WHILE ~S.eot & (S.nextCh # "}") DO
						IF ok THEN Texts.Write(Wt, S.nextCh) END;
						Texts.Read(S, S.nextCh)
					END
				END;
				IF ok THEN
					Texts.WriteLn(Wt);  T := TextFrames.Text("");  Texts.Append(T, Wt.buf);
					F := TextFrames.NewText(T, 0);  TextFrames.Call(F, 0, FALSE)
				END;
				Texts.Scan(S);  Texts.Scan(S)
			END
		END;
		NEW(oberonRunner);
	ELSE
		KernelLog.Enter; KernelLog.String("Only one instance of Oberon can be started"); KernelLog.Exit
	END;
END Init;

PROCEDURE Greetings;
BEGIN
	Oberon.GetClock(time0, date0);  Texts.WriteString(W, "System.Time");
	Texts.WriteDate(W, time0, date0);  Texts.WriteLn(W);
	Texts.WriteString(W, "ETH Oberon / ");
	Texts.WriteString(W, Kernel.version);  Texts.WriteLn(W);
	Texts.Append(Oberon.Log, W.buf)
END Greetings;

PROCEDURE WriteType(VAR W: Texts.Writer;  adr: LONGINT);
VAR m: AosModules.Module;  t: AosModules.TypeDesc;
BEGIN
	AosModules.ThisTypeByAdr(adr, m, t);
	IF m # NIL THEN
		Texts.WriteString(W, m.name);  Texts.Write(W, ".");
		IF t.name = "" THEN Texts.WriteString(W, "TYPE") ELSE Texts.WriteString(W, t.name) END
	ELSE
		Texts.WriteString(W, "NIL")
	END
END WriteType;

(** Display the approximate state of all threads in the system. *)

PROCEDURE ShowActive*;	(** non-portable *)
VAR
	processes : ARRAY ProcessInfo.MaxNofProcesses OF AosActive.Process; nofProcesses : LONGINT;
	t: AosActive.Process;  i, mode, adr: LONGINT;  T: Texts.Text;
	pc, tmp1, tmp2: LONGINT; refs: Bytes;
BEGIN
	ProcessInfo.GetProcesses(processes, nofProcesses);
	ProcessInfo.Sort(processes, nofProcesses, ProcessInfo.SortByID);

	(* display the threads *)
	Texts.SetFont(W, fixed);
	FOR i := 0 TO nofProcesses - 1 DO
		t := processes[i];
		Texts.WriteInt(W, t.id, 4);  Texts.Write(W, " ");
		mode := t.mode;
		CASE mode OF
			AosActive.Ready: Texts.WriteString(W, "rdy")
			|AosActive.Running: Texts.WriteString(W, "run")
			|AosActive.AwaitingLock: Texts.WriteString(W, "awl")
			|AosActive.AwaitingCond: Texts.WriteString(W, "awc")
			|AosActive.AwaitingEvent: Texts.WriteString(W, "awe")
			|AosActive.Terminated: Texts.WriteString(W, "rip")
			ELSE Texts.WriteInt(W, mode, 3)
		END;
		Texts.WriteInt(W, t.procID, 2); Texts.WriteInt(W, t.priority, 2);
		(*Texts.WriteHex(W, SYSTEM.VAL(LONGINT, t));  Texts.Write(W, "H");*)
		adr := SYSTEM.VAL(LONGINT, t.obj);
		IF adr # 0 THEN
			Texts.WriteHex(W, adr);  Texts.Write(W, "H");
			SYSTEM.GET(adr-4, adr);  Texts.Write(W, ":");  WriteType(W, adr)
		ELSE
			Texts.WriteString(W, " SYSTEM")
		END;
		(*Texts.WriteHex(W, t.state.EIP);  Texts.Write(W, "H");*)
		IF mode = AosActive.AwaitingLock THEN
			adr := SYSTEM.VAL(LONGINT, t.waitingOn);
			Texts.WriteHex(W, adr);  Texts.Write(W, "H");
			IF adr # 0 THEN
				SYSTEM.GET(adr-4, adr);  Texts.Write(W, ":");  WriteType(W, adr)
			END
		ELSIF mode = AosActive.AwaitingCond THEN
			Texts.Write(W, " ");
			pc := SYSTEM.VAL(LONGINT, t.condition);
			WriteProc(AosModules.ThisModuleByAdr(pc), pc, t.condFP, refs, tmp1, tmp2);
			(*Texts.WriteHex(W, SYSTEM.VAL(LONGINT, t.condition));  Texts.Write(W, "H");*)
			(*Texts.WriteHex(W, t.condFP);  Texts.Write(W, "H")*)
		END;
		IF AosActive.Restart IN t.flags THEN Texts.WriteString(W, " rst") END;
		IF AosActive.PleaseHalt IN t.flags THEN Texts.WriteString(W, " hlt") END;
		IF AosActive.Unbreakable IN t.flags THEN Texts.WriteString(W, " unb"); END;
		IF AosActive.SelfTermination IN t.flags THEN Texts.WriteString(W, " slf"); END;
		IF AosActive.Preempted IN t.flags THEN Texts.WriteString(W, " pre"); END;
		IF AosActive.Resistant IN t.flags THEN Texts.WriteString(W, " res") END;
		Texts.WriteLn(W)
	END;
	Texts.SetFont(W, Fonts.Default);
	T := TextFrames.Text("");  Texts.Append(T, W.buf);
	OpenText("Active Objects", T, FALSE)
END ShowActive;

(* Halt or Terminate the selected thread. *)

PROCEDURE StopProcess(halt: BOOLEAN);
VAR
	s: Texts.Scanner;  text: Texts.Text;  beg, end, time: LONGINT;
	n : AosActive.Process;
BEGIN
	Oberon.GetSelection(text, beg, end, time);
	IF time # -1 THEN
		Texts.OpenScanner(s, text, beg);  Texts.Scan(s);
		IF s.class = Texts.Int THEN
			REPEAT
				n := ProcessInfo.GetProcess(s.i);
				IF n # NIL THEN
					AosActive.TerminateThis(n, halt);
					beg := s.line;
					REPEAT Texts.Scan(s) UNTIL (s.class = Texts.Inval) OR ((s.class = Texts.Int) & (s.line # beg)) OR (Texts.Pos(s) > end);
					IF Texts.Pos(s) > end THEN s.class := Texts.Inval END
				ELSE
					Texts.WriteString(W, "Object ");  Texts.WriteInt(W, s.i, 1);
					Texts.WriteString(W, " not found");  Texts.WriteLn(W);
					Texts.Append(Oberon.Log, W.buf);
					s.class := Texts.Inval
				END
			UNTIL s.class # Texts.Int
		END
	END
END StopProcess;

(** Halt selected thread. *)

PROCEDURE HaltObject*;	(** non-portable *)
BEGIN
	StopProcess(TRUE)
END HaltObject;

(** Terminate selected thread. *)

PROCEDURE TerminateObject*;	(** non-portable *)
BEGIN
	StopProcess(FALSE)
END TerminateObject;

(** Attempt to terminate all non-immune threads. *)

PROCEDURE TerminateObjects*;	(** non-portable *)
VAR processes : ARRAY ProcessInfo.MaxNofProcesses OF AosActive.Process; nofProcesses, i : LONGINT;
BEGIN
	ProcessInfo.GetProcesses(processes, nofProcesses);
	FOR i := 0 TO nofProcesses - 1 DO
		AosActive.TerminateThis(processes[i], FALSE)
	END;
END TerminateObjects;

(** Start monitoring the KernelLog log for trap viewers and OpenKernelLog. *)

PROCEDURE StartLog*;	(** non-portable *)
VAR cmd: PROCEDURE;
BEGIN
	IF task = NIL THEN
		IF AosModules.ModuleByName (LogWindow) # NIL THEN
			GETPROCEDURE (LogWindow, "Close", cmd);
			IF cmd # NIL THEN cmd END;
		END;
		IF buf = NIL THEN NEW(buf, BufSize) END;	(* never reallocate existing buffer *)
		IF log = NIL THEN NEW(log); Texts.Open(log, "") END;
		IF KernelLog.OpenBuffer(ADDRESSOF(buf[0]), LEN(buf)) THEN
			NEW(task); task.safe := TRUE; task.handle := LogHandler;
			task.time := Input.Time(); Oberon.Install(task)
		ELSE
			buf := NIL;
			Texts.WriteString(W, "Log already open elsewhere"); Texts.WriteLn(W);
			Texts.Append(Oberon.Log, W.buf)
		END
	ELSE
		Texts.WriteString(W, "Log already open"); Texts.WriteLn(W);
		Texts.Append(Oberon.Log, W.buf)
	END
END StartLog;

(** Stop monitoring the KernelLog log.  Allows other loggers to work (e.g. LogWindow.Open) *)

PROCEDURE StopLog*;	(** non-portable *)
BEGIN
	IF task # NIL THEN
		KernelLog.CloseBuffer;
		Oberon.Remove(task); task := NIL;
	END
END StopLog;

(*
(** Load the window manager and jump into it. *)

	PROCEDURE LoadWM;
	VAR res: WORD; s: ARRAY 128 OF CHAR;
	BEGIN
		IF Standalone() THEN
			Oberon.OpenTrack(0, Display.Width);	(* inhibit display updates *)
			OberonInput.Remove;	(* remove default Oberon input device *)
			s := "";
			AosFS.AppendStr("WindowManager.Install;OberonDisplay.Install Oberon ", s);
			AosFS.AppendInt(Display.Width, s);
			AosFS.AppendStr("x", s);
			AosFS.AppendInt(Display.Height, s);
			Commands.Call(s, {Commands.Wait}, res, s);
			IF res = 0 THEN
				Display.SetMode(0BEH, {});	(* re-initialize display *)
				Input.Init(0BEH)	(* re-init input *)
			ELSE
				Texts.WriteString(W, s); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
			END;
			Viewers.CloseTrack(0)
		END
	END LoadWM;
*)

BEGIN
	init := FALSE;
	Texts.OpenWriter(W);
	Oberon.Log := TextFrames.Text("");
	Texts.OpenWriter(LogW); fixed := Fonts.This("Courier10.Scn.Fnt");
	Greetings;
	task := NIL;
	Modules.InstallTermHandler(StopLog)
END System.
