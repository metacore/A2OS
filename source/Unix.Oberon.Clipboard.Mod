(* OBERON System 3, Release 2.2.

Copyright 1996, 1997 Team of the Institute of Computer Systems of ETH Zürich, ETH Center, CH-8092 Zürich,
e-mail: oberon@inf.ethz.ch.

This module may be used under the conditions of the general Oberon System 3 license contract.
The full text can be downloaded from

	"ftp://ftp.inf.ethz.ch/pub/software/Oberon/System3/license.txt;A"

or requested from the above mentioned address.

Under the license terms stated it is in particular (a) prohibited to modify the interface of this module
in any way that disagrees with style or content of the system and (b) requested to provide all conversions
of the source code to another platform with the name OBERON. *)

MODULE Clipboard IN Oberon;	(* mad 4.9.1997 *)

IMPORT	SYSTEM, Files, Texts, Oberon, Displays IN A2, XDisplay IN A2, Plugins IN A2, Display,
		X11 IN A2, Strings, Modules IN A2, Machine IN A2 ;

CONST  CR = 0DX; LF = 0AX;

VAR
	scrap: Texts.Text; B: Texts.Buffer;
	W: Texts.Writer;
	selectionData: POINTER TO ARRAY OF CHAR;
	ownSelection: BOOLEAN;
	myProperty, oberonType: X11.Atom;
	retries: INTEGER;
	disp: XDisplay.Display;


PROCEDURE ClearSelection;
BEGIN ownSelection := FALSE
END ClearSelection;

PROCEDURE CopyOverSelection;
	VAR M: Oberon.ConsumeMsg;
BEGIN
	IF scrap.len > 0 THEN
		M.F := NIL; M.text := scrap; M.beg := 0; M.end := scrap.len;
		Display.Broadcast(M)
	END
END CopyOverSelection;

PROCEDURE TakeSelection;
BEGIN
	ownSelection := TRUE;
	Machine.Acquire(Machine.X11);
	X11.SetSelectionOwner(disp.xdisp, X11.XAPRIMARY, disp.primary, X11.lastEventTime);
	IF X11.GetSelectionOwner(disp.xdisp, X11.XAPRIMARY) # disp.primary THEN ClearSelection END;
	Machine.Release(Machine.X11);
END TakeSelection;

PROCEDURE RequestSelection;
BEGIN
	Machine.Acquire(Machine.X11);
	IF retries = 0 THEN
		X11.ConvertSelection(disp.xdisp, X11.XAPRIMARY, oberonType, myProperty, disp.primary, X11.lastEventTime)
	ELSE
		X11.ConvertSelection(disp.xdisp, X11.XAPRIMARY, X11.XASTRING, myProperty, disp.primary, X11.lastEventTime)
	END;
	Machine.Release(Machine.X11);
END RequestSelection;

PROCEDURE SendSelection(VAR event: X11.SelectionRequestEvent);
	VAR ev: X11.SelectionEvent; R: Texts.Reader; i, size: LONGINT; ch: CHAR; f: Files.File; r: Files.Rider;
BEGIN
	ev.typ := X11.SelectionNotify;
	ev.requestor := event.requestor;
	ev.selection := event.selection;
	ev.target := event.target;
	ev.time := event.time;
	IF (event.selection = X11.XAPRIMARY) & (event.target = X11.XASTRING) THEN
		ev.property := event.property;
		NEW(selectionData, scrap.len + 1);
		Texts.OpenReader(R, scrap, 0); Texts.Read(R, ch); i := 0;
		WHILE ~R.eot DO
			IF ch = CR THEN ch := LF END ;
			selectionData[i] := Strings.OberonToISO[ORD(ch)]; INC(i);
			Texts.Read(R, ch)
		END ;
		selectionData[i] := 0X;
		Machine.Acquire(Machine.X11);
		X11.ChangeProperty(disp.xdisp, ev.requestor, ev.property, ev.target, 8, X11.PropModeReplace, ADDRESSOF(selectionData[0]), i);
		Machine.Release(Machine.X11);
	ELSIF (event.selection = X11.XAPRIMARY) & (event.target = oberonType) THEN
		ev.property := event.property;
		f := Files.New(""); Files.Set(r, f, 0); Files.WriteLInt(r, 0);
		Texts.Store(scrap, f, Files.Pos(r), size);
		NEW(selectionData, Files.Length(f));
		IF selectionData # NIL THEN
			Files.Set(r, f, 0); Files.WriteLInt(r, Files.Length(f)-4);
			Files.Set(r, f, 0); Files.Read(r, ch); i:= 0;
			WHILE ~r.eof DO
				selectionData[i] := ch; INC(i);
				Files.Read(r, ch)
			END;
			Machine.Acquire(Machine.X11);
			X11.ChangeProperty(disp.xdisp, ev.requestor, ev.property, ev.target, 8, X11.PropModeReplace,
				ADDRESSOF(selectionData[0]), i);
			Machine.Release(Machine.X11);
		END
	ELSE
		ev.property := X11.None
	END ;
	Machine.Acquire(Machine.X11);
	X11.SendEvent(disp.xdisp, ev.requestor, X11.False, 0, ADDRESSOF(ev));
	Machine.Release(Machine.X11);
END SendSelection;

PROCEDURE ReceiveSelection(VAR event: X11.SelectionEvent);
	VAR type: X11.Atom; format: WORD; len, after: LONGWORD;  prop, adr: ADDRESS; ch: CHAR; f: Files.File; r: Files.Rider; i: LONGINT;
BEGIN
	IF (event.property = X11.None) & (retries = 0) THEN
		retries := 1; RequestSelection; RETURN
	END;
	retries := 0;
	Texts.Delete(scrap, 0, scrap.len);
	IF (event.selection = X11.XAPRIMARY) & (event.property = myProperty) THEN
		Machine.Acquire(Machine.X11);
		X11.GetWindowProperty(disp.xdisp, event.requestor, event.property, 0, 8192, X11.False, event.target, type, format, len, after, prop);
		adr := prop;
		IF len > 0 THEN
			IF type = oberonType THEN
				f := Files.New(""); Files.Set(r, f, 0);
				FOR i := 0 TO 3 DO
					SYSTEM.GET(adr, ch); INC(adr); Files.Write(r, ch)
				END;
				Files.Set(r, f, 0); Files.ReadLInt(r, i);
				WHILE i > 0 DO
					SYSTEM.GET(adr, ch); INC(adr); Files.Write(r, ch);
					DEC(i)
				END;
				Files.Set(r, f, 0); Files.ReadLInt(r, i); Files.Read(r, ch);
				Texts.Load(scrap, f, Files.Pos(r), i)
			ELSE
				WHILE len > 0 DO
					SYSTEM.GET(adr, ch); INC(adr); DEC(len);
					IF ch = LF THEN ch := CR END ;
					IF ch # 0X THEN Texts.Write(W, Strings.ISOToOberon[ORD(ch)]) END
				END ;
				Texts.Append(scrap, W.buf);
			END;
			X11.Free(prop); X11.DeleteProperty(disp.xdisp, event.requestor, event.property)
		END ;
		Machine.Release(Machine.X11);
		CopyOverSelection
	END
END ReceiveSelection;

PROCEDURE Cut*;
	VAR t: Texts.Text; beg, end, time: LONGINT;
BEGIN
	Texts.Delete(scrap, 0, scrap.len); Oberon.GetSelection(t, beg, end, time);
	IF time > 0 THEN Texts.Save(t, beg, end, B); Texts.Delete(t, beg, end); Texts.Append(scrap, B) END ;
	TakeSelection
END Cut;

PROCEDURE Copy*;
	VAR t: Texts.Text; beg, end, time: LONGINT;
BEGIN
	Texts.Delete(scrap, 0, scrap.len); Oberon.GetSelection(t, beg, end, time);
	IF time >= 0 THEN Texts.Save(t, beg, end, B); Texts.Append(scrap, B) END ;
	TakeSelection
END Copy;

PROCEDURE Paste*;
BEGIN
	IF ownSelection THEN CopyOverSelection ELSE RequestSelection END
END Paste;

PROCEDURE InitKeys;
END InitKeys;

	PROCEDURE GetXDisplay;
	VAR p: Plugins.Plugin;
	BEGIN
		p := Displays.registry.Await("XDisplay");
		disp := p(XDisplay.Display)
	END GetXDisplay;

(* set Selection handlers to NIL *)
PROCEDURE OnClose;
BEGIN
	X11.SendSelection := NIL;
	X11.ReceiveSelection := NIL;
	X11.ClearSelection := NIL;
END OnClose;


BEGIN
	Texts.OpenWriter(W); NEW(B); Texts.OpenBuf(B);
	GetXDisplay;
	NEW(scrap); Texts.Open(scrap, "");
	X11.SendSelection := SendSelection;
	X11.ReceiveSelection := ReceiveSelection;
	X11.ClearSelection := ClearSelection;
	ClearSelection;
	myProperty := X11.InternAtom(disp.xdisp, "OberonProperty", X11.False);
	oberonType := X11.InternAtom(disp.xdisp, "Oberon System 3 Data", X11.False);
	retries := 0; InitKeys;
	Modules.InstallTermHandler(OnClose);
END Clipboard.


Clipboard.Copy
Clipboard.Cut
Clipboard.Paste
