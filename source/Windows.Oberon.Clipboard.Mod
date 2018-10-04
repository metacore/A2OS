(* Copyright (c) 1994 - 2000 Emil J. Zeller *)

MODULE Clipboard IN Oberon; (** non-portable / source: Windows.Clipboard.Mod *)	(* ejz  *)
	IMPORT SYSTEM, Kernel32 IN A2, User32 IN A2, Files, (*Displays,*)  Display, Strings, Fonts, Texts, Oberon, Gadgets,
		Desktops;

	(** Windows Clipboard commands. *)

	VAR
		W: Texts.Writer;
		CFOberon: INTEGER;

	(** Copy a text stretch to the Clipboard. *)
	PROCEDURE PutToClipboard*(T: Texts.Text; beg, end: LONGINT);
		VAR
			buf: Texts.Buffer; t: Texts.Text;
			f: Files.File; r: Files.Rider;
			hMem: Kernel32.HGLOBAL; adr: ADDRESS;
			size: LONGINT;
			R: Texts.Reader; ch: CHAR;
	BEGIN
		IF User32.OpenClipboard(0) # Kernel32.False THEN
			IGNORE User32.EmptyClipboard();
			IF CFOberon # Kernel32.NULL THEN
				NEW(buf); Texts.OpenBuf(buf); Texts.Save(T, beg, end, buf);
				NEW(t); Texts.Open(t, ""); Texts.Append(t, buf);
				f := Files.New(""); Files.Set(r, f, 0); Files.WriteLInt(r, 0);
				Texts.Store(t, f, Files.Pos(r), size);
				Files.Set(r, f, 0); Files.WriteLInt(r, Files.Length(f)-4);
				hMem := Kernel32.GlobalAlloc({Kernel32.GMemMoveable, Kernel32.GMemDDEShare}, Files.Length(f));
				adr := Kernel32.GlobalLock(hMem);
				Files.Set(r, f, 0); Files.Read(r, ch);
				WHILE ~r.eof DO
					SYSTEM.PUT(adr, ch); INC(adr);
					Files.Read(r, ch)
				END;
				IGNORE Kernel32.GlobalUnlock(hMem);
				hMem := User32.SetClipboardData(CFOberon, hMem)
			END;
			Texts.OpenReader(R, T, beg); size := 0;
			WHILE Texts.Pos(R) < end DO
				Texts.Read(R, ch);
				IF R.lib IS Fonts.Font THEN
					IF ch = 0DX THEN INC(size, 2) ELSE INC(size) END
				END
			END;
			hMem := Kernel32.GlobalAlloc({Kernel32.GMemMoveable, Kernel32.GMemDDEShare}, size + 1);
			adr := Kernel32.GlobalLock(hMem);
			Texts.OpenReader(R, T, beg);
			WHILE Texts.Pos(R) < end DO
				Texts.Read(R, ch);
				IF R.lib IS Fonts.Font THEN
					SYSTEM.PUT(adr, Strings.OberonToISO[ORD(ch)]); INC(adr);
					IF ch = 0DX THEN SYSTEM.PUT(adr, 0AX); INC(adr) END
				END
			END;
			SYSTEM.PUT(adr, 0X);
			IGNORE Kernel32.GlobalUnlock(hMem);
			hMem := User32.SetClipboardData(User32.CFText, hMem);
			IGNORE User32.CloseClipboard()
		END
	END PutToClipboard;

	(** Get text data from the Clipboard. *)
	PROCEDURE GetFromClipboard*( VAR T: Texts.Text);
		VAR
			hMem: Kernel32.HGLOBAL; adr: ADDRESS;
			f: Files.File; r: Files.Rider;
			i: LONGINT;
			ch: CHAR;
	BEGIN
		T := NIL;
		IF User32.OpenClipboard(0) # Kernel32.False THEN
			hMem := User32.GetClipboardData(CFOberon);
			IF hMem # Kernel32.NULL THEN
				adr := Kernel32.GlobalLock(hMem);
				f := Files.New(""); Files.Set(r, f, 0);
				FOR i := 0 TO 3 DO
					SYSTEM.GET(adr, ch); INC(adr); Files.Write(r, ch)
				END;
				Files.Set(r, f, 0); Files.ReadLInt(r, i);
				WHILE i > 0 DO
					SYSTEM.GET(adr, ch); INC(adr); Files.Write(r, ch);
					DEC(i)
				END;
				IGNORE Kernel32.GlobalUnlock(hMem);
				Files.Set(r, f, 0); Files.ReadLInt(r, i); Files.Read(r, ch);
				NEW(T); Texts.Load(T, f, Files.Pos(r), i)
			ELSE
				hMem := User32.GetClipboardData(User32.CFText);
				IF hMem # Kernel32.NULL THEN
					NEW(T); Texts.Open(T, "");
					adr := Kernel32.GlobalLock(hMem);
					SYSTEM.GET(adr, ch); INC(adr);
					WHILE ch # 0X DO
						Texts.Write(W, Strings.ISOToOberon[ORD(ch)]);
						IF ch = 0DX THEN INC(adr) END;
						SYSTEM.GET(adr, ch); INC(adr)
					END;
					IGNORE Kernel32.GlobalUnlock(hMem);
					Texts.Append(T, W.buf)
				END
			END;
			IGNORE User32.CloseClipboard()
		END
	END GetFromClipboard;

	PROCEDURE GetTextSelection(VAR text: Texts.Text; VAR beg, end: LONGINT);
		VAR F: Display.Frame; M: Oberon.SelectMsg;
	BEGIN
		M.F := NIL; M.id := Oberon.get; M.text := NIL; M.time := -1;
		IF Desktops.IsInMenu(Gadgets.context) THEN
			F := Desktops.CurDoc(Gadgets.context);
			F.handle(F, M)
		ELSE
			Display.Broadcast(M)
		END;
		text := M.text; beg := M.beg; end := M.end
	END GetTextSelection;

	(** Cut text selection. *)
	PROCEDURE Cut*;
		VAR T: Texts.Text; beg, end: LONGINT;
	BEGIN
		GetTextSelection(T, beg, end);
		IF T # NIL THEN
			PutToClipboard(T, beg, end);
			Texts.Delete(T, beg, end)
		END
	END Cut;

	(** Copy text selection. *)
	PROCEDURE Copy*;
		VAR T: Texts.Text; beg, end: LONGINT;
	BEGIN
		GetTextSelection(T, beg, end);
		IF T # NIL THEN PutToClipboard( T, beg, end) END
	END Copy;

	(** Insert clipboard (text-) contents at caret. *)
	PROCEDURE Paste*;
		VAR M: Oberon.ConsumeMsg;
	BEGIN
		GetFromClipboard( M.text);
		IF M.text # NIL THEN
			M.F := NIL; M.beg := 0; M.end := M.text.len;
			Display.Broadcast(M)
		END
	END Paste;

	(*
	PROCEDURE PictureThis(this: Displays.Display);
		VAR
			hDC: User32.HDC;
			hBm, hOldBm: GDI32.HBitmap;
	BEGIN
		IF User32.OpenClipboard(this.hWndParent) # Kernel32.False THEN
			hDC := GDI32.CreateCompatibleDC(this.hDC);
			hBm := GDI32.CreateCompatibleBitmap(this.hDC, this.width, this.height);
			hOldBm := GDI32.SelectObject(hDC, hBm);
			GDI32.BitBlt(hDC, 0, 0, this.width, this.height, this.hDC, 0, 0, GDI32.SrcCopy);
			User32.EmptyClipboard();
			User32.SetClipboardData(User32.CFBitmap, hBm);
			User32.CloseClipboard();
			GDI32.SelectObject(hDC, hOldBm);
			GDI32.DeleteObject(hBm);
			GDI32.DeleteDC(hDC)
		END
	END PictureThis;
	*)


	PROCEDURE Init;
	VAR str: ARRAY 32 OF CHAR;
	BEGIN
		str := "ETH Oberon, Text";
		CFOberon := User32.RegisterClipboardFormat(str)
	END Init;


BEGIN
	Texts.OpenWriter(W);
	Init;
END Clipboard.

Clipboard.Cut
Clipboard.Copy
Clipboard.Paste
Clipboard.Snapshot

System.Free Clipboard ~
