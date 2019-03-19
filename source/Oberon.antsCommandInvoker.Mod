MODULE antsCommandInvoker IN Oberon;	(** fof  **)
(* Copyright notice:

This file is part of AntsInFields
Copyright (C) 1997-2002, Felix Friedrich

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

Copy of the GNU Lesser General Public License can be found in the file COPYING.TXT
Report any problems as soon as possible to ants@AntsInFields.de
*)

(** Frame gadget, filled rectangle, starts a command after being loaded (Attribute Cmd) by a background task (guarantees that whole frame is loaded),
	you can make it invisible by changing its color to background color or by adjusting its size to w=0, h=0 *)

IMPORT Gadgets,Objects,Display3,Display,Oberon,Attributes,vyHost;

TYPE

	Frame* = POINTER TO FrameDesc;
	FrameDesc* = RECORD (Gadgets.FrameDesc)
	END;

	TaskAfterStore= POINTER TO TaskAfterStoreDesc;
	TaskAfterStoreDesc = RECORD (Oberon.TaskDesc);
		f: Frame;
	END;

VAR
	context*: Objects.Object;
	visible*: BOOLEAN;
	active*: BOOLEAN;

	PROCEDURE ForceString(F: Display.Frame; VAR M: Objects.AttrMsg);
	BEGIN Gadgets.framehandle(F, M);
		IF M.res < 0 THEN M.class := Objects.String; M.s := ""; M.res := 0 END
	END ForceString;

PROCEDURE FrameAttr(F: Frame; VAR M: Objects.AttrMsg);
BEGIN
	IF M.id = Objects.get THEN
		IF M.name = "Gen" THEN M.class := Objects.String; COPY("antsCommandInvoker.NewFrame", M.s); M.res := 0
		ELSIF M.name = "Cmd" THEN ForceString(F, M)
		ELSE Gadgets.framehandle(F, M)
		END;
	ELSIF M.id = Objects.set THEN Gadgets.framehandle(F, M)
	ELSIF M.id = Objects.enum THEN
		M.Enum("Cmd");
		Gadgets.framehandle(F, M)
	END
END FrameAttr;

PROCEDURE RestoreFrame(R: Display3.Mask; F: Frame; x, y, w, h, u, v, w1, h1: INTEGER; dlink: Objects.Object);
VAR D: Display.DisplayMsg; L: Gadgets.Frame; O: Display3.OverlapMsg; A: Objects.AttrMsg; ll, lr, lb, lt: INTEGER;
	col: Display.Color;
BEGIN
	Oberon.RemoveMarks(x, y, w, h);
	A.id := Objects.get; A.name := "Color"; A.class := Objects.Inval; A.i := Display3.upC; A.res := -1;
	F.handle(F, A); IF A.class = Objects.Int THEN col := A.i ELSE col := Display3.upC END;
	IF visible THEN
		Display3.FillPattern(R, col,Display.solid ,x,y,x, y, w, h,  Display3.replace);
		IF Gadgets.selected IN F.state THEN Display3.FillPattern(R, Display3.white, Display3.selectpat, x, y, x, y, w, h, Display.paint) END
	END;
END RestoreFrame;

PROCEDURE CopyFrame*(VAR M: Objects.CopyMsg; from, to: Frame);
BEGIN
	Gadgets.CopyFrame(M, from, to);
END CopyFrame;

PROCEDURE ComeBack(t: Oberon.Task);
VAR f: Frame; cmd,string: ARRAY 256 OF CHAR; res: INTEGER; i,j: INTEGER;
BEGIN
	WITH t: TaskAfterStore DO
		f := t.f;
		Attributes.GetString(f,"Cmd",cmd);
		Gadgets.Update(f);
		context := f.dlink;
		Gadgets.context := context;
		IF cmd # "" THEN
			i := 0;
			WHILE(cmd[i] # " ") & (cmd[i] # 0X) DO
				INC(i);
			END;
			IF cmd[i] # 0X THEN
			cmd[i] := 0X; INC(i);  j := 0;
				WHILE(cmd[i] # 0X) DO
					string[j] := cmd[i]; INC(i); INC(j);
				END;
			END;
			vyHost.CallWString(cmd,string,FALSE,res);
		END;
	END;
	Oberon.Remove(t);
END ComeBack;


PROCEDURE InvokeCommand(F: Frame);
VAR task: TaskAfterStore;
BEGIN
	IF active THEN
		NEW(task);
		task.handle := ComeBack;
		task.f := F;
		task.time := Oberon.Time();
		Oberon.Install(task);
	END;
END InvokeCommand;


PROCEDURE FrameHandler*(F: Objects.Object; VAR M: Objects.ObjMsg);
VAR F2: Frame; x, y, w, h: INTEGER;
	keysum: SET; ver: LONGINT; f: Gadgets.Frame; R: Display3.Mask;
BEGIN
	WITH F: Frame DO
		IF M IS Objects.AttrMsg THEN
			WITH M: Objects.AttrMsg DO FrameAttr(F, M) END;
		ELSIF M IS Objects.FileMsg THEN
			WITH M: Objects.FileMsg DO
				IF M.id = Objects.store THEN
					Gadgets.framehandle(F, M);
				ELSIF M.id = Objects.load THEN
					Gadgets.framehandle(F, M);
					InvokeCommand(F);
				END
			END
		ELSIF M IS Objects.CopyMsg THEN
			WITH M: Objects.CopyMsg DO
				IF M.stamp = F.stamp THEN
					M.obj := F.dlink
				ELSE
					NEW(F2); F.stamp := M.stamp; F.dlink := F2; CopyFrame(M, F, F2); M.obj := F2
				END
			END
		ELSIF M IS Display.FrameMsg THEN
			WITH M: Display.FrameMsg DO
				IF M.res >= 0 THEN RETURN END;
				x := M.x + F.X; y := M.y + F.Y; w := F.W; h := F.H;
				F.dlink := M.dlink;
				IF M IS Display.DisplayMsg THEN
					WITH M: Display.DisplayMsg DO
						IF M.device = Display.screen THEN
							IF (M.F = NIL) OR ((M.id = Display.full) & (M.F = F)) THEN
								Gadgets.MakeMask(F, x, y, M.dlink, R);
								RestoreFrame(R, F, x, y, w, h, 0, 1 - h, w, h, M.dlink);
							ELSIF (M.id = Display.area) & (M.F = F) THEN
								Gadgets.MakeMask(F, x, y, M.dlink, R);
								Display3.AdjustMask(R, x + M.u, y + h - 1 + M.v, M.w, M.h);
								RestoreFrame(R, F, x, y, w, h, M.u, M.v, M.w, M.h, M.dlink)
							END
						END
					END
				ELSE
					Gadgets.framehandle(F, M);
				END;
			END;
		ELSE
			Gadgets.framehandle(F, M);
		END;
	END;
END FrameHandler;

PROCEDURE InitFrame*(F: Frame);
BEGIN
	F.handle := FrameHandler; F.W := 10; F.H := 10;
END InitFrame;

PROCEDURE NewFrame*;
VAR F: Frame;
BEGIN
	NEW(F); InitFrame(F); Objects.NewObj := F;
END NewFrame;

PROCEDURE Visible*;
BEGIN
	visible := TRUE;
END Visible;

PROCEDURE InVisible*;
BEGIN
	visible := FALSE;
END InVisible;

PROCEDURE DebugMode*;
BEGIN
	active := FALSE;
END DebugMode;

PROCEDURE NormalMode*;
BEGIN
	active := TRUE;
END NormalMode;



(* ========== Checkboxes ================ *)


(* ------ Gadgets ------ *)


BEGIN visible := TRUE;  active := TRUE;
END antsCommandInvoker.

Gadgets.Insert antsCommandInvoker.NewFrame  ~
antsCommandInvoker.Visible ~ antsCommandInvoker.InVisible ~
antsCommandInvoker.Test