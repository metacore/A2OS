(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Suitcases IN Oberon;	(** jm 22.2.95 *)

(** Suitcase gadgets allow you to pack files and texts in a gadget. Storing the gadget, will also
store its contents, keeping the gadget and its contents together.

Usage:
	Suitcases.PackText *		Pack the marked text document and insert the suitcase at the caret.
	Suitcases.PackFiles filenames ~		Pack the named files and insert the suitcases at the caret.

Clicking on a suitcase will open its contents as a document, but NOT overwrite any files on the local
disk. This makes them ideal to be mailed.
*)

IMPORT Files, Display, Display3, Fonts, Printer, Printer3, Effects, Attributes, Objects, Gadgets,
	Oberon, Texts, TextGadgets, Desktops, TextDocs, Documents, Out;

TYPE
	(** FileObj's store complete files *)
	FileObj* = POINTER TO FileObjDesc;
	FileObjDesc* = RECORD (Gadgets.ObjDesc)
		F*: Files.File;	(** carrier file *)
		beg*, len*: SIGNED32;	(** file offset and length *)
	END;

	Suitcase* = POINTER TO SuitcaseDesc;
	SuitcaseDesc* = RECORD (Gadgets.FrameDesc)
		col*: SIGNED16;
		label*: ARRAY 64 OF CHAR;	(** caption *)
	END;

(*  --- FileObj --- *)

PROCEDURE FileObjHandler*(obj: Objects.Object; VAR M: Objects.ObjMsg);
VAR obj0: FileObj; len: SIGNED32; R: Files.Rider; ch: CHAR;
BEGIN
	WITH obj: FileObj DO
		IF M IS Objects.AttrMsg THEN
			WITH M: Objects.AttrMsg DO
				IF M.id = Objects.get THEN
					IF M.name = "Gen" THEN M.class := Objects.String; COPY("Suitcases.NewFileObj", M.s); M.res := 0
					ELSE Gadgets.objecthandle(obj, M)
					END
				ELSIF M.id = Objects.set THEN Gadgets.objecthandle(obj, M)
				ELSIF M.id = Objects.enum THEN Gadgets.objecthandle(obj, M)
				END
			END
		ELSIF M IS Objects.CopyMsg THEN
			WITH M: Objects.CopyMsg DO
				IF M.stamp = obj.stamp THEN M.obj := obj.dlink	(* copy msg arrives again *)
				ELSE (* first time copy message arrives *)
					NEW(obj0); obj.stamp := M.stamp; obj.dlink := obj0;
					obj0.handle := obj.handle;
					obj0.F := obj.F; obj0.beg := obj.beg; obj0.len := obj.len;
					M.obj := obj0
				END
			END
		ELSIF M IS Objects.FileMsg THEN
			WITH M: Objects.FileMsg DO
				IF M.id = Objects.store THEN
					len := obj.len;
					Files.WriteLInt(M.R, obj.len);
					Files.Set(R, obj.F, obj.beg);
					Files.Read(R, ch);
					WHILE len > 0 DO
						Files.Write(M.R, ch);
						Files.Read(R, ch); DEC(len)
					END;
					Files.WriteLInt(M.R, 42);
					Gadgets.objecthandle(obj, M)
				ELSIF M.id = Objects.load THEN
					obj.F := Files.Base(M.R);
					Files.ReadLInt(M.R, obj.len);
					obj.beg := Files.Pos(M.R);
					Files.Set(M.R, Files.Base(M.R), obj.beg + obj.len);
					Files.ReadLInt(M.R, len); ASSERT(len = 42);
					Gadgets.objecthandle(obj, M)
				END
			END
		ELSE Gadgets.objecthandle(obj, M)
		END
	END
END FileObjHandler;

(** Initialize a file object with a file *)
PROCEDURE OpenFileObj*(obj: FileObj; F: Files.File);
BEGIN
	obj.handle := FileObjHandler;
	obj.F := F;
	IF F # NIL THEN
		obj.beg := 0;
		obj.len := Files.Length(F)
	END
END OpenFileObj;

PROCEDURE NewFileObj*;
VAR obj: FileObj;
BEGIN
	NEW(obj); OpenFileObj(obj, NIL); Objects.NewObj := obj;
END NewFileObj;

(** unpack a file object into the named file *)
PROCEDURE UnpackFileObj*(obj: FileObj; CONST filename: ARRAY OF CHAR);
VAR F: Files.File; R, r: Files.Rider; ch: CHAR; len: SIGNED32;
BEGIN
	F := Files.New(filename); Files.Set(r, F, 0);
	len := obj.len;
	Files.Set(R, obj.F, obj.beg);
	Files.Read(R, ch);
	WHILE len > 0 DO
		Files.Write(r, ch);
		Files.Read(R, ch); DEC(len)
	END;
	Files.Register(F);
END UnpackFileObj;

(*  --- Suitcases --- *)

PROCEDURE SuitcaseAttr(F: Suitcase; VAR M: Objects.AttrMsg);
BEGIN
	IF M.id = Objects.get THEN
		IF M.name = "Gen" THEN M.class := Objects.String; COPY("Suitcases.NewSuitcase", M.s); M.res := 0
		ELSIF M.name = "Color" THEN M.class := Objects.Int; M.i := F.col; M.res := 0
		ELSIF M.name = "Label" THEN M.class := Objects.String; COPY(F.label, M.s); M.res := 0
		ELSE Gadgets.framehandle(F, M)
		END
	ELSIF M.id = Objects.set THEN
		IF M.name = "Color" THEN
			IF M.class = Objects.Int THEN F.col := SHORT(M.i); M.res := 0 END
		ELSIF M.name = "Label" THEN
			IF M.class = Objects.String THEN COPY(M.s, F.label); M.res := 0 END
		ELSE Gadgets.framehandle(F, M);
		END
	ELSIF M.id = Objects.enum THEN
		M.Enum("Color"); M.Enum("Label"); Gadgets.framehandle(F, M)
	END
END SuitcaseAttr;

PROCEDURE RestoreSuitcase(F: Suitcase; M: Display3.Mask; x, y, w, h: SIGNED16);
VAR j: SIGNED16;
BEGIN
	j := w DIV 2 - 10;
	Display3.Rect3D(M, Display3.topC, Display3.bottomC, x + j, y + h - 12, 20, 10, 1, Display.replace);
	Display3.Rect3D(M, Display3.bottomC, Display3.topC, x + j + 2, y + h - 10, 16, 6, 1, Display.replace);
	Display3.FilledRect3D(M, Display3.topC, Display3.bottomC, F.col, x, y, w, h - 10, 1, Display.replace);
	Display3.CenterString(M, Display3.FG, x, y, w, h - 10, Fonts.Default, F.label, Display.paint);
	IF Gadgets.selected IN F.state THEN
		Display3.FillPattern(M, Display3.white, Display3.selectpat, x, y, x, y, w, h, Display.paint)
	END
END RestoreSuitcase;

PROCEDURE Print(F: Suitcase; VAR M: Display.DisplayMsg);
VAR R: Display3.Mask;

	PROCEDURE P(x: SIGNED16): SIGNED16;
	BEGIN RETURN SHORT(x * Display.Unit DIV Printer.Unit)
	END P;

BEGIN
	Gadgets.MakePrinterMask(F, M.x, M.y, M.dlink, R);
	Printer3.ReplConst(R, F.col, M.x, M.y, P(F.W), P(F.H), Display.replace);
END Print;

PROCEDURE CopySuitcase*(VAR M: Objects.CopyMsg; from, to: Suitcase);
BEGIN
	to.col := from.col; COPY(from.label, to.label);
	Gadgets.CopyFrame(M, from, to);
END CopySuitcase;

PROCEDURE OpenSuitcase(F: Suitcase; obj: Objects.Object);
VAR D: Documents.Document; f: TextGadgets.Frame; res: SIGNED16;
BEGIN
	IF obj # NIL THEN
		IF obj IS Texts.Text THEN
			WITH obj: Texts.Text DO
				NEW(D); TextDocs.InitDoc(D); (* make document wrapper *)

				NEW(f); TextGadgets.Init(f, obj, FALSE);	(* create content *)

				Documents.Init(D, f); (* and merge together *)
				D.W := Display.Width DIV 8 * 3 + 20;
				COPY(F.label, D.name);
				Desktops.ShowDoc(D)
			END
		ELSIF obj IS FileObj THEN
			WITH obj: FileObj DO
				UnpackFileObj(obj, "Suitcases.Tmp");
				D := Documents.Open("Suitcases.Tmp");
				IF D = NIL THEN Out.String("   document cannot be opened"); Out.Ln
				ELSE
					COPY(F.label, D.name);
					Desktops.ShowDoc(D);
					Files.Delete("Suitcases.Tmp", res);
				END
			END
		END
	END
END OpenSuitcase;

PROCEDURE SuitcaseHandler*(F: Objects.Object; VAR M: Objects.ObjMsg);
VAR x, y, w, h: SIGNED16; F0: Suitcase; R: Display3.Mask;
BEGIN
	WITH F: Suitcase DO
		IF M IS Display.FrameMsg THEN
			WITH M: Display.FrameMsg DO
				IF (M.F = NIL) OR (M.F = F) THEN	(* message addressed to this frame *)
					x := M.x + F.X; y := M.y + F.Y; w := F.W; h := F.H; (* calculate display coordinates *)
					IF M IS Display.DisplayMsg THEN
						WITH M: Display.DisplayMsg  DO
							IF M.device = Display.screen THEN
								IF (M.id = Display.full) OR (M.F = NIL) THEN
									Gadgets.MakeMask(F, x, y, M.dlink, R);
									RestoreSuitcase(F, R, x, y, w, h)
								ELSIF M.id = Display.area THEN
									Gadgets.MakeMask(F, x, y, M.dlink, R);
									Display3.AdjustMask(R, x + M.u, y + h - 1 + M.v, M.w, M.h);
									RestoreSuitcase(F, R, x, y, w, h)
								END
							ELSIF M.device = Display.printer THEN Print(F, M)
							END
						END
					ELSIF M IS Oberon.InputMsg THEN
						WITH M: Oberon.InputMsg DO
							IF (M.id = Oberon.track) & Gadgets.InActiveArea(F, M) & (M.keys = {1}) THEN
								Gadgets.MakeMask(F, x, y, M.dlink, R);
								Effects.TrackHighlight(R, M.keys, M.X, M.Y, x, y, w, h);
								IF Gadgets.InActiveArea(F, M) & (M.keys = {1}) THEN (* activated *)
									IF F.obj # NIL THEN OpenSuitcase(F, F.obj)
									ELSE Out.String("Suitcase is empty"); Out.Ln;
									END
								END;
								M.res := 0;
							ELSE Gadgets.framehandle(F, M)
							END
						END
					ELSE Gadgets.framehandle(F, M)
					END
				END
			END

		(* Object messages *)

		ELSIF M IS Objects.AttrMsg THEN SuitcaseAttr(F, M(Objects.AttrMsg))
		ELSIF M IS Objects.FileMsg THEN
			WITH M: Objects.FileMsg DO
				IF M.id = Objects.store THEN (* store private data here *)
					Files.WriteInt(M.R, F.col);
					Files.WriteString(M.R, F.label);
					Gadgets.framehandle(F, M)
				ELSIF M.id = Objects.load THEN (* load private data here *)
					Files.ReadInt(M.R, F.col);
					Files.ReadString(M.R, F.label);
					Gadgets.framehandle(F, M)
				END
			END
		ELSIF M IS Objects.CopyMsg THEN
			WITH M: Objects.CopyMsg DO
				IF M.stamp = F.stamp THEN M.obj := F.dlink	(* copy msg arrives again *)
				ELSE	(* first time copy message arrives *)
					NEW(F0); F.stamp := M.stamp; F.dlink := F0; CopySuitcase(M, F, F0); M.obj := F0
				END
			END
		ELSIF M IS Objects.BindMsg THEN
			IF F.obj # NIL THEN F.obj.handle(F.obj, M) END;
			Gadgets.framehandle(F, M);
		ELSE	(* unknown msg, framehandler might know it *)
			Gadgets.framehandle(F, M)
		END
	END
END SuitcaseHandler;

PROCEDURE InitSuitcase*(F: Suitcase); (* provided for later type extensions *)
BEGIN F.W := 80; F.H := 30; F.col := Display3.groupC; INCL(F.state, Gadgets.transparent); COPY("Empty", F.label); F.handle := SuitcaseHandler
END InitSuitcase;

PROCEDURE NewSuitcase*;
VAR F: Suitcase;
BEGIN NEW(F); InitSuitcase(F); Objects.NewObj := F;
END NewSuitcase;

(* --- text handling --- *)

PROCEDURE GetLabel(T: Texts.Text; VAR label: ARRAY OF CHAR);
VAR R: Texts.Reader; ch: CHAR; keyw: ARRAY 6 OF CHAR;

	PROCEDURE ReadLine;
	VAR i, j: SIGNED16;
	BEGIN
		Texts.Read(R, ch); i := 0; j := 0;
		WHILE ~R.eot & (ch # 0DX) DO
			IF i < LEN(keyw) - 1 THEN keyw[i] := ch; INC(i);
				IF ch = ":" THEN i := LEN(keyw) END; (* cut off *)
			ELSE
				IF (j < LEN(label) - 1) & (ch > " ") THEN label[j] := ch; INC(j) END;
			END;
			Texts.Read(R, ch);
		END;
		keyw[i] := 0X; label[j] := 0X;
	END ReadLine;

BEGIN
	Texts.OpenReader(R, T, 0);
	ReadLine;
	WHILE ~R.eot & (keyw # "") DO
		IF (keyw = "From:") OR (keyw = "Re:") THEN RETURN END;
		ReadLine;
	END;
	label[0] := 0X
END GetLabel;

(** Make a suitcase out of a text *)
PROCEDURE MakeTextSuitcase*(F: Suitcase; label: ARRAY OF CHAR; T: Texts.Text);
VAR buf: Texts.Buffer; text: Texts.Text; d: SIGNED16; maillabel: ARRAY 128 OF CHAR;
BEGIN
	NEW(buf); Texts.OpenBuf(buf);
	Texts.Save(T, 0, T.len, buf);

	GetLabel(T, maillabel);
	IF maillabel # "" THEN COPY(maillabel, label) END;

	NEW(text); Texts.Open(text, "");
	Texts.Insert(text, 0, buf);

	InitSuitcase(F); COPY(label, F.label); F.obj := text;
	Display3.StringSize(F.label, Fonts.Default, F.W, F.H, d);
	INC(F.W, 10); INC(F.H, 20);
END MakeTextSuitcase;

(** Make a suitcase out of a file *)
PROCEDURE MakeFileSuitcase*(F: Suitcase; CONST filename: ARRAY OF CHAR);
VAR d: SIGNED16; f: FileObj;
BEGIN
	InitSuitcase(F); COPY(filename, F.label);

	NEW(f); OpenFileObj(f, Files.Old(filename)); F.obj := f;
	Display3.StringSize(F.label, Fonts.Default, F.W, F.H, d);
	INC(F.W, 10); INC(F.H, 20);
END MakeFileSuitcase;

(* --- *)

(** Pack the marked text document and insert it at caret *)
PROCEDURE PackText*;
VAR doc: Documents.Document; M: Objects.LinkMsg; F: Suitcase;
BEGIN
	doc := Documents.MarkedDoc();
	IF (doc # NIL) & (doc.dsc # NIL) THEN
		M.id := Objects.get; M.name := "Model"; M.obj := NIL; M.res := -1; doc.dsc.handle(doc.dsc, M);
		IF (M.obj # NIL) & (M.obj IS Texts.Text) THEN
			NEW(F); MakeTextSuitcase(F, doc.name, M.obj(Texts.Text));
			Gadgets.Integrate(F)
		END
	END
END PackText;

(** Suitcases.PackFile filelist ~
Pack the named files and insert the suitcases at the caret. *)
PROCEDURE PackFiles*;
VAR S: Attributes.Scanner; F: Files.File; s: Suitcase; l: Display.Frame;
BEGIN l := NIL;
	Attributes.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
	Attributes.Scan(S);
	WHILE (S.class = Attributes.Name) OR (S.class = Attributes.String) DO
		F := Files.Old(S.s);
		IF F # NIL THEN
			NEW(s); MakeFileSuitcase(s, S.s); s.slink := l; l := s;
		ELSE Out.String(S.s); Out.String("  file not found"); Out.Ln
		END;
		Attributes.Scan(S)
	END;
	Gadgets.Integrate(l);
END PackFiles;

END Suitcases.

System.Free Suitcases ~
Gadgets.Insert Suitcases.NewSuitcase ~

Suitcases.PackText *
Suitcases.PackFile t.Mod
Suitcases.PackFiles Gadgets.Panel ~
Suitcases.PackFiles ^ ~ Gadgets.Panel