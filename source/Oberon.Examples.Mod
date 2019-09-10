(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

(*
	Examples.Mod, jm 24.2.93 - Modified by AFI - December 18, 1994.

	This module illustrates how gadgets can be manipulated under program control.
	Commands exported by this module are used in the tutorial "GadgetsOberon.html".
*)

MODULE Examples IN Oberon; (** portable *)

IMPORT
	Attributes, BasicGadgets, Desktops, Display, Gadgets, Oberon, Objects,
	Out, Printer, Texts, Documents;

VAR
	W: Texts.Writer;
	tmp: Objects.Object;

(*-- Increment integer gadget --*)
(* This command must be executed from a gadget *)
PROCEDURE Increm*;
	VAR obj: Objects.Object;
BEGIN
	obj := Gadgets.FindObj(Gadgets.context, "Level");
	IF (obj # NIL) THEN
		INC(obj(BasicGadgets.Integer).val);
		Gadgets.Update(obj)
	END
END Increm;

(*-- Decrement integer gadget --*)
(* This command must be executed from a gadget *)
PROCEDURE Decrem*;
	VAR obj: Objects.Object;
BEGIN
	obj := Gadgets.FindObj(Gadgets.context, "Level");
	IF (obj # NIL) THEN
		DEC(obj(BasicGadgets.Integer).val);
		Gadgets.Update(obj)
	END
END Decrem;

(*-- Create a slider gadget and insert it at the caret position --*)
PROCEDURE InsertAtCaret*;
	VAR obj: Objects.Object;
BEGIN
	Out.String("Inserting slider gadget at caret"); Out.Ln;
	obj := Gadgets.CreateObject("BasicGadgets.NewSlider");
	Gadgets.Integrate(obj)
END InsertAtCaret;

(*-- Create a text field linked to an integer and insert it at the caret position --*)
PROCEDURE InsertPair*;
	VAR F: Display.Frame; obj: Objects.Object; L:Objects.LinkMsg;
BEGIN
	Out.String("Insert view/model pair"); Out.Ln;
	F := Gadgets.CreateViewModel("TextFields.NewTextField",
													   "BasicGadgets.NewInteger");
	Gadgets.Integrate(F);
	(* Name the model "Volts" *)
	Gadgets.NameObj(F(Gadgets.Frame).obj, "Volts");

	(* Create a slider, insert it in the desktop and name it "Slider" *)
	obj := Gadgets.CreateObject("BasicGadgets.NewSlider");
	Gadgets.Integrate(obj);
	Gadgets.NameObj(obj, "Slider");

	(* Link the integer to the slider *)
	(* NOT so: obj(Gadgets.Frame).obj := F(Gadgets.Frame).obj
		but so, sending a link message to the slider. *)

	L.id := Objects.set; L.obj := F(Gadgets.Frame).obj;
	L.name := "Model"; L.res := -1; Objects.Stamp(L);
	obj.handle(obj, L);
	Gadgets.Update(obj)
END InsertPair;

(*-- Display names assigned in previous example --*)
PROCEDURE ShowNames*;
	VAR S: Display.SelectMsg; ObjName: ARRAY 64 OF CHAR;
BEGIN
	S.id := Display.get; S.F := NIL; S.time := -1;
	Display.Broadcast(S);
	IF (S.time # -1) & (S.obj # NIL) THEN
		Out.String("Visual gadget name: ");
		Gadgets.GetObjName(S.obj, ObjName);
		Out.String(ObjName); Out.Ln;
			(*==================*)
		IF S.obj(Gadgets.Frame).obj # NIL THEN
			Out.String("Model gadget name: ");
			Gadgets.GetObjName(S.obj(Gadgets.Frame).obj, ObjName);
			Out.String(ObjName); Out.Ln
		ELSE
			Out.String("No model exists"); Out.Ln
		END
	END
END ShowNames;

(*-- Display information about an object --*)
PROCEDURE Info*(obj: Objects.Object);
	VAR A: Objects.AttrMsg;
BEGIN
	IF obj # NIL THEN
		A.id := Objects.get; A.name := "Gen"; A.s := ""; A.res := -1;
		obj.handle(obj, A); (* Retrieve its new procedure *)
		IF A.s # "" THEN Texts.WriteString(W, "  "); Texts.WriteString(W, A.s)
		ELSE Texts.WriteString(W, "  Unknown generator!")
		END;
		IF obj IS Desktops.DocGadget THEN Texts.WriteString(W, ": desktop document")
		ELSIF obj IS Documents.Document THEN Texts.WriteString(W, ": document")
		ELSIF obj IS Gadgets.View THEN Texts.WriteString(W, ": view")
		ELSIF obj IS Gadgets.Frame THEN Texts.WriteString(W, ": visual gadget")
		ELSIF obj IS Display.Frame THEN Texts.WriteString(W, ": display frame")
		ELSIF obj IS Gadgets.Object THEN Texts.WriteString(W, ": model gadget")
		ELSE Texts.WriteString(W, ": type unknown")
		END;
		Texts.WriteLn(W)
	END;
	Texts.Append(Oberon.Log, W.buf)
END Info;

PROCEDURE Explore*;
BEGIN
	Info(Oberon.Par.frame);
	Info(Oberon.Par.obj);
	Info(Gadgets.executorObj);
	Info(Gadgets.context)
END Explore;

(*-- Tell everything about the execution environment --*)
(* This command must be executed from a gadget. *)
PROCEDURE FindObj*;
	VAR obj: Objects.Object;
BEGIN
	(* Note: the context is already set before reaching this point. *)
	obj := Gadgets.FindObj(Gadgets.context, "Test");
	IF (obj # NIL) & (obj IS BasicGadgets.Button) THEN
		Out.String("Executor gadget:"); Out.Ln;
		Info(Gadgets.executorObj);
		Out.String("found:"); Out.Ln;
		Info(obj);
		Out.String("in context:"); Out.Ln;
		Info(Gadgets.context); Out.Ln
	END
END FindObj;

(*-- Select gadget --*)
(* This command must be executed from a gadget *)
PROCEDURE SelectGadget*;
	VAR S: Display.SelectMsg; obj: Objects.Object;
BEGIN
	obj := Gadgets.FindObj(Gadgets.context, "Test");
	IF (obj # NIL) THEN
		Out.String("Select gadget 'Test'"); Out.Ln;
		S.id := Display.set; S.F := obj(Display.Frame); S.obj := NIL; S.sel := NIL; S.time := -1;
		Display.Broadcast(S);
		Info(S.obj);
		Info(S.sel);
		Out.String("Gadget selected."); Out.Ln;
		Gadgets.Update(obj);
		Out.String("   and now redrawn.")
	ELSE Out.String("No object 'Test' found")
	END;
	Out.Ln
END SelectGadget;

(*-- Deselect selected gadget --*)
(* This command must be executed from a gadget *)
PROCEDURE DeselectGadget*;
	VAR S: Display.SelectMsg; obj: Objects.Object;
BEGIN
	Out.String("Deselect gadget"); Out.Ln;
	S.id := Display.get; S.F := NIL; S.obj := NIL; S.time := -1;
	Display.Broadcast(S);
	IF (S.time # -1) & (S.obj # NIL) THEN
		obj := S.obj;
		S.id := Display.reset; S.F := obj(Display.Frame); S.obj := NIL; S.sel := NIL; S.time := -1;
		Display.Broadcast(S);
		Info(S.obj);
		Info(S.sel);
		Out.String("Gadget deselected"); Out.Ln;
		Gadgets.Update(obj);
		Out.String("   and now redrawn.")
	ELSE Out.String("No object selected.")
	END;
	Out.Ln
END DeselectGadget;

(*-- Display information about the currently selected objects --*)
PROCEDURE GetSelection*;
	VAR S: Display.SelectMsg; obj: Objects.Object;
BEGIN
	Out.String("Examples.GetSelection"); Out.Ln;
	S.id := Display.get; S.F := NIL; S.time := -1;
	Display.Broadcast(S);
	IF (S.time # -1) & (S.obj # NIL) THEN
		obj := S.obj;
		WHILE obj # NIL DO
			Info(obj);
			Out.String("    Ancestor:");
			Info(S.sel);
			obj := obj.slink
		END
	ELSE Out.String("No object selected.")
		(*-- time is still = -1 and obj = NIL --*)
	END
END GetSelection;

(*-- Remove selected gadget --*)
PROCEDURE RemoveSelection*;
	VAR S: Display.SelectMsg; C: Display.ControlMsg;
BEGIN
	Out.String("Remove selected gadget"); Out.Ln;
	S.id := Display.get; S.F := NIL; S.obj := NIL; S.time := -1;
	Display.Broadcast(S);
	IF (S.time # -1) & (S.obj # NIL) THEN
		C.id := Display.remove; C.F := S.obj(Display.Frame); Display.Broadcast(C)
	END
END RemoveSelection;

(*-- Suspend selected gadget --*)
PROCEDURE SuspendSelection*;
	VAR S: Display.SelectMsg; C: Display.ControlMsg;
BEGIN
	Out.String("Suspend selected gadget"); Out.Ln;
	S.id := Display.get; S.F := NIL; S.obj := NIL; S.time := -1;
	Display.Broadcast(S);
	IF (S.time # -1) & (S.obj # NIL) THEN
		C.id := Display.suspend; C.F := S.obj(Display.Frame); Display.Broadcast(C)
	END
END SuspendSelection;

(*-- Locate gadget at screen coordinates X, Y --*)
PROCEDURE LocateP*;
	VAR F: Display.Frame; X, Y: SIGNED16; u, v: SIGNED16;
BEGIN
	X := Oberon.Pointer.X;
	Y := Oberon.Pointer.Y;
	Out.String("Gadget at X="); Out.Int(X, 5);
	Out.String("  Y="); Out.Int(Y, 5); Out.Ln;
	Gadgets.ThisFrame(X, Y, F, u, v);
	Info(F);
	Out.String("  Rel. point coord. ");
	Out.String("u="); Out.Int(u, 5);
	Out.String("  v="); Out.Int(v, 5); Out.Ln
END LocateP;

(*-- Locate gadget at screen coordinates X, Y --*)
PROCEDURE Locate*;
	VAR L: Display.LocateMsg; X, Y: SIGNED16;
BEGIN
	X := Oberon.Pointer.X;
	Y := Oberon.Pointer.Y;
	Out.String("Gadget at X="); Out.Int(X, 5);
	Out.String("  Y="); Out.Int(Y, 5); Out.Ln;
	L.X := X; L.Y := Y; L.res := -1; L.F := NIL; L.loc := NIL;
	Display.Broadcast(L);
	Info(L.loc);
	Out.String("  Rel. point coord. ");
	Out.String("u="); Out.Int(L.u, 5);
	Out.String("  v="); Out.Int(L.v, 5); Out.Ln
END Locate;

(*-- Move selected gadget to absolute coordinates X, Y --*)
PROCEDURE MoveGadget*;
	VAR S: Display.SelectMsg; M: Display.ModifyMsg; F: Display.Frame;
		AS: Attributes.Scanner; X, Y: SIGNED16;
BEGIN
	Out.String("Moving gadget."); Out.Ln;
	Attributes.OpenScanner(AS, Oberon.Par.text, Oberon.Par.pos);
	Attributes.Scan(AS);
	IF AS.class = Attributes.Int THEN
		X := SHORT(AS.i); Attributes.Scan(AS);
		IF AS.class = Attributes.Int THEN
			Y := SHORT(AS.i);
			S.id := Display.get; S.F := NIL; S.obj := NIL; S.time := -1;
			Display.Broadcast(S);
			IF (S.time # -1) & (S.obj # NIL) THEN
				F := S.obj(Display.Frame);
				M.id := Display.move;
				M.mode := Display.display;
				M.F := F;
				M.X := F.X + X; M.Y := F.Y + Y;
				M.W := F.W; M.H := F.H;
				M.dX := X; M.dY := Y;
				M.dW := 0; M.dH := 0;
				Display.Broadcast(M)
			END
		END
	END
END MoveGadget;

(*-- Show selected gadget location (X, Y) and size (W, H) --*)
PROCEDURE LocateGadget*;
	VAR S: Display.SelectMsg; F: Display.Frame;
BEGIN
	Out.String("Gadget frame coordinates:"); Out.Ln;
	S.id := Display.get; S.F := NIL; S.obj := NIL; S.time := -1;
	Display.Broadcast(S);
	IF (S.time # -1) & (S.obj # NIL) THEN
		F := S.obj(Display.Frame);
		Out.String("X="); Out.Int(F.X, 5);
		Out.String("   Y"); Out.Int(F.Y, 5); Out.Ln;
		Out.String("W="); Out.Int(F.W, 5);
		Out.String("   H="); Out.Int(F.H, 5); Out.Ln
	END
END LocateGadget;

(*-- Move selected gadgets to the caret --*)
PROCEDURE MoveToCaret*;
	VAR S: Display.SelectMsg; C: Display.ControlMsg; obj: Objects.Object;
BEGIN
	Out.String("Moving gadget to caret"); Out.Ln;
	S.id := Display.get; S.F := NIL; S.obj := NIL; S.time := -1;
	Display.Broadcast(S);
	IF (S.time # -1) & (S.obj # NIL) THEN
		obj := S.obj;
		C.id := Display.remove; C.F := obj(Display.Frame); Display.Broadcast(C);
		Gadgets.Integrate(obj)
	END
END MoveToCaret;

(*-- Print selected gadgets --*)
PROCEDURE PrintGadget*;
	VAR S: Display.SelectMsg; P: Display.DisplayMsg; obj: Objects.Object;
BEGIN
	Printer.Open("LPT1", "");
	Out.String("Printing gadget"); Out.Ln;
	S.id := Display.get; S.F := NIL; S.obj := NIL; S.time := -1;
	Display.Broadcast(S);
	IF (S.time # -1) & (S.obj # NIL) THEN
		obj := S.obj;
		P.device := Display.printer; P.id := Display.contents; P.F := obj(Display.Frame);
		P.res := -1;
		Display.Broadcast(P);
	END
END PrintGadget;

(*-- Show a named attribute of a gadget --*)
PROCEDURE RetrObjAttr(CONST name: ARRAY OF CHAR);
	VAR A: Objects.AttrMsg;
BEGIN
	Out.String("    "); Out.String(name);
	A.id := Objects.get; COPY(name, A.name); A.res := -1; Objects.Stamp(A);
	tmp.handle(tmp, A);
	IF A.res >= 0 THEN	(* Attribute exists *)
		IF A.class = Objects.String THEN Out.String(" is string = "); Out.String(A.s)
		ELSIF A.class = Objects.Int THEN Out.String(" is integer = "); Out.Int(A.i, 5)
		ELSIF A.class = Objects.Real THEN Out.String(" is real = "); Out.Real(A.x, 5)
		ELSIF A.class = Objects.LongReal THEN Out.String(" is real = "); Out.LongReal(A.y, 5)
		ELSIF A.class = Objects.Char THEN Out.String(" is char = "); Out.Char(A.c)
		ELSIF A.class = Objects.Bool THEN Out.String(" is boolean = ");
			IF A.b THEN Out.String("TRUE")
			ELSE Out.String("FALSE")
			END
		ELSE Out.String("Unknown class")
		END
	END;
	Out.Ln
END RetrObjAttr;

PROCEDURE EnumAttr*;
	VAR S: Display.SelectMsg; obj: Objects.Object; A: Objects.AttrMsg;
BEGIN
	Out.String("Examples.EnumAttr"); Out.Ln;
	S.id := Display.get; S.F := NIL; S.obj := NIL; S.time := -1;
	Display.Broadcast(S);
	IF (S.time # -1) & (S.obj # NIL) THEN
		obj := S.obj;
		WHILE obj # NIL DO
			tmp := obj;
			Info(obj);
			A.id := Objects.enum; A.Enum := RetrObjAttr; A.res := -1; Objects.Stamp(A); obj.handle(obj, A);
			obj := tmp.slink
		END
	END
END EnumAttr;

PROCEDURE EnumAttr2*;
	VAR S: Display.SelectMsg; obj: Objects.Object; At: Attributes.Attr;
		AV: Attributes.StringAttr;
BEGIN
	Out.String("Examples.EnumAttr2"); Out.Ln;
	S.id := Display.get; S.F := NIL; S.obj := NIL; S.time := -1;
	Display.Broadcast(S);
	IF (S.time # -1) & (S.obj # NIL) THEN
		obj := S.obj;
		WHILE obj # NIL DO
			tmp := obj;
			Info(obj);
			Info(obj(Gadgets.Frame).obj);
			At := obj(Gadgets.Frame).attr; (* Why is this = NIL ??? *)
			IF At = NIL THEN Out.String("Is Nil") END;
			NEW(AV);
			AV.s := "Gogo";
			AV.next := NIL;
			Attributes.InsertAttr(At, "André", AV);
			Attributes.DeleteAttr(At, "Tutorial");
			Out.String("Done");
			obj := tmp.slink
		END
	END
END EnumAttr2;

(*-- Show the 'Value' attribute of objects --*)
PROCEDURE ShowValue*;
	VAR S: Display.SelectMsg; obj: Objects.Object;
BEGIN
	Out.String("Show 'Value' attribute"); Out.Ln;
	S.id := Display.get; S.F := NIL; S.obj := NIL; S.time := -1;
	Display.Broadcast(S);
	IF (S.time # -1) & (S.obj # NIL) THEN
		obj := S.obj;
		WHILE obj # NIL DO
			Info(obj);
			tmp := obj;
			RetrObjAttr("Value");
			obj := obj.slink
		END
	END
END ShowValue;

(*-- Resize selected gadgets --*)
PROCEDURE Resize*;
	VAR S: Display.SelectMsg; obj: Objects.Object; F: Display.Frame; M: Display.ModifyMsg;
		AS: Attributes.Scanner; W, H: SIGNED16;
BEGIN
	Out.String("Resize selected gadgets"); Out.Ln;
	Attributes.OpenScanner(AS, Oberon.Par.text, Oberon.Par.pos);
	Attributes.Scan(AS);
	IF AS.class = Attributes.Int THEN
		W := SHORT(AS.i); Attributes.Scan(AS);
		IF AS.class = Attributes.Int THEN
			H := SHORT(AS.i);
			S.id := Display.get; S.F := NIL; S.time := -1;
			Display.Broadcast(S);
			IF (S.time # -1) & (S.obj # NIL) THEN
				obj := S.obj;
				WHILE obj # NIL DO
					F := obj(Display.Frame);
					M.id := Display.extend; (* OR Display.reduce: means change size for gadgets *)
					M.mode := Display.display; (* display changes immediately *)
					M.F := F;
					M.X := F.X; M.Y := F.Y;
					M.dX := 0; M.dY := 0;
					M.W := W; M.H := H;
					M.dW := W - F.W; M.dH := H - F.H; (* deltas *)
					Display.Broadcast(M);
				(*	F.handle(F, M);	???	*)
					obj := obj.slink
				END
			END
		END
	END
END Resize;

(*-- Shows the current message path --*)
(* This command must be executed from a gadget *)
PROCEDURE ShowThread*;
VAR obj: Objects.Object;
BEGIN
	Out.String("Examples.ShowThread"); Out.Ln;
	obj := Oberon.Par.obj;
	WHILE obj # NIL DO
		Info(obj);
		obj := obj.dlink
	END
END ShowThread;

(* Consume command. Delete the object thrown into the executor of this command *)
PROCEDURE Delete*;
	VAR C: Display.ControlMsg;
BEGIN
	Out.String("Examples.Delete"); Out.Ln;
	IF Gadgets.senderObj # NIL THEN
		C.id := Display.remove; C.F := Gadgets.senderObj(Display.Frame);
		Display.Broadcast(C)
	END
END Delete;

(*-- Look for an integer model gadget called "Test" in the current
		context and increment its val field. The model is visualized by
		a text field.--*)
(*-- This command must be executed in a given context. --*)
PROCEDURE Inc*;
	VAR obj: Objects.Object;
BEGIN
	obj := Gadgets.FindObj(Gadgets.context, "Test");
	IF (obj # NIL) & (obj IS BasicGadgets.Integer) THEN
		WITH obj: BasicGadgets.Integer DO
			INC(obj.val);
			BasicGadgets.SetValue(obj)
		END
	END;
(*-- Look for an slider gadget called "Slider" in the current
		context and increment its val field --*)
	obj := Gadgets.FindObj(Gadgets.context, "Slider");
	IF (obj # NIL) & (obj IS BasicGadgets.Slider) THEN
		WITH obj: BasicGadgets.Slider DO
			INC(obj.val);
			BasicGadgets.SetValue(obj)
		END
	END
END Inc;

(*-- Look for an integer object called Test in the current context,
		build a slider and link them together, and
		insert the slider at the caret position. *)
(* This command must be executed from a gadget. *)
PROCEDURE AddSlider*;
	VAR obj: Objects.Object; F: Objects.Object;
BEGIN
	obj := Gadgets.FindObj(Gadgets.context, "Test");
	IF (obj # NIL) & (obj IS BasicGadgets.Integer) THEN
		F := Gadgets.CreateObject("BasicGadgets.NewSlider");
		WITH F: Gadgets.Frame DO
			F.obj := obj; (* Link slider to the integer object *)
			Gadgets.Integrate(F);
			Gadgets.Update(obj)
		END
	END
END AddSlider;

PROCEDURE ShowDoc*;
	VAR D: Documents.Document;
BEGIN
	D := Documents.MarkedDoc();
	Info(D);
END ShowDoc;

PROCEDURE OpenDoc*;
VAR D: Documents.Document;
BEGIN
	D := Documents.Open("Tutorials.html");
	IF D # NIL THEN Desktops.ShowDoc(D)
	ELSE Out.String("No such document found.")
	END
END OpenDoc;

(*-----------------------------------*)
(* Used in the GadgetsOberon.html tutorial. *)
	PROCEDURE Add*;
		VAR x, a, b: BasicGadgets.Real;

		PROCEDURE GetReal(CONST name: ARRAY OF CHAR): BasicGadgets.Real;
			VAR obj: Objects.Object;
		BEGIN
			obj := Gadgets.FindObj(Gadgets.context, name);
			IF (obj # NIL) & (obj IS BasicGadgets.Real) THEN
				RETURN obj(BasicGadgets.Real)
			ELSE
				RETURN NIL
			END
		END GetReal;

	BEGIN
		(* 1. get the real gadgets *)
		x := GetReal("xx");
		a := GetReal("aa");
		b := GetReal("bb");
		IF (x = NIL) OR (a = NIL) OR (b = NIL) THEN
			RETURN
		END;
		(* 2. solve the equation *)
		IF Gadgets.executorObj(Gadgets.Frame).obj # x THEN
			(* command executed from text field aa or bb *)
			x.val := b.val -a.val
		END;
		(* 3. notify clients of model x that x.val has changed *)
		BasicGadgets.SetValue(x)
	END Add;
(*-----------------------------------*)

	BEGIN
	Texts.OpenWriter(W)
END Examples.

Some commands to test out the above module:

Examples.GetSelection ~
Examples.RemoveSelection ~
Examples.MoveSelection ~
Examples.ShowAttr ~
Examples.Resize 100 25 ~

Gadgets.ChangeAttr Cmd Examples.ShowThread ~
Gadgets.ChangeAttr ConsumeCmd Examples.Delete ~

Examples.Build ~

Gadgets.ChangeAttr Cmd Examples.Inc ~
Gadgets.ChangeAttr Cmd Examples.AddSlider ~

Examples.MoveGadget 10 10 ~

Examples.LocateGadget