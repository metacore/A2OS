(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Popups IN Oberon; (* jm 14.11.94 *)

(*
This is an example program to show how you can combine gadgets together by program control. The same effect can also be obtained completely interactively with the graphical user interface.

Insert a popup at the caret with the command:

	Popups.Insert "My menu"

The module builds a small popup menu from a Panel with a descriptive text on one side, and a TextNote on the other side. The Iconizer can be opened in-place and text entered inside the TextNote. You may also change the "Cmd" attribute of the TextNote to directly open what you click on with:

	Gadgets.ChangeAttr Cmd "Desktops.OpenDoc #Point" ~

Note: There is one problem though: should the command be executed from a TRAP viewer, the popup will not close again.
*)

IMPORT
	Attributes, Display, Gadgets, Icons, Oberon, Objects, Panels,
	TextFields, TextGadgets, Texts;

PROCEDURE InsertFrame (F, f: Display.Frame; u, v: SIGNED16);
VAR C: Display.ConsumeMsg;
BEGIN
	C.id := Display.drop; C.F := F; C.obj := f; C.u := u; C.v := v; C.res := -1; C.dlink := NIL;
	F.handle(F, C)
END InsertFrame;

PROCEDURE Build* (desc: ARRAY OF CHAR; T: Texts.Text; W, H: SIGNED16): Objects.Object;
VAR F: Icons.Iconizer; close: Panels.Panel; open: TextGadgets.Frame;
	caption: TextFields.Caption; t: Texts.Text;
BEGIN
	NEW(close); Panels.InitPanel(close);
	close.W := W; close.H := H;

	Attributes.StrToTxt (desc, t);
	NEW(caption); TextFields.InitCaption(caption, t);

	IF caption.W + 20 >= close.W THEN close.W := caption.W + 20 END;

	InsertFrame(close, caption, close.W - caption.W - 5, -close.H + 3);

	Attributes.SetBool(close, "Locked", TRUE);
	NEW(open); TextGadgets.Init(open, T, TRUE);

	NEW(F); Icons.MakeIconizer(F, close, open);
	Attributes.SetBool(F, "Popup", TRUE);
	RETURN F
END Build;

PROCEDURE Insert*;
VAR S: Attributes.Scanner; T: Texts.Text;
BEGIN
	Attributes.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
	Attributes.Scan(S);
	IF (S.class = Attributes.Name) OR (S.class = Attributes.String) THEN
		NEW(T); Texts.Open(T, "");
		Gadgets.Integrate(Build(S.s, T, 60, 25))
	END
END Insert;

END Popups.
