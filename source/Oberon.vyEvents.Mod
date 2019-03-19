MODULE vyEvents IN Oberon; 	(** gs  **)
(* Copyright notice:

This file is part of Voyager
Copyright (C) 1993-2002 Project Voyager, StatLab Heidelberg ; (C) 1993-2002 G. Sawitzki et al.

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
Report any problems as soon as possible to voyager@statlab.uni-heidelberg.de
*)


(* fof, 020624, added DoubleClick Event *)
IMPORT Objects, Oberon, Input, vyHostDisplay := vyGraphBase, vyBase;
CONST
	(** gesture constants for events **)
	EvtUnknown* = - 1;
	EvtEmpty* = 0;
	EvtLoc* = 1;
	EvtIdent* = 2;
	EvtSelect* = 3;
	EvtRemove* = 4;
	EvtCopy* = 5;
	EvtCopyAttr* = 6;
	EvtOpen* = 7;
	EvtPointCmd* = 8;
	EvtCmdPoint* = 9;
	EvtDoubleClick* = 10;  	(* fof 020624 *)
	EvtWheelDown*=11;
	  EvtWheelUp*=12;
	  EvtPointWheelDown*=13;
	  EvtPointWheelUp*=15;
	  EvtSelectWheelDown*=16;
	  EvtSelectWheelUp*=17;

	CdoubleClickTime* = 300;   (* fof 020624 *)

	(**priority codes	  *)

	PrioNone* = 0;
	PrioLow* = 10;
	PrioNormal* = 20;
	PrioHigh* = 30;
	PrioUrgent* = 40;

	(*Keys const  *)
	(*	emptyKeys  = {}; *)
	pointKeys = {vyBase.leftKey};
	cmdKeys = {vyBase.middleKey};
	selectKeys = {vyBase.rightKey};
	copyKeys = selectKeys + cmdKeys;
	removeKeys = selectKeys + pointKeys;
	openKeys = cmdKeys + selectKeys;
	copyAttrKeys = pointKeys + selectKeys;  	(* the order then removeKeys *)(*??? gs this is a set, not a sequence !! *)
	(*	allKeys   = pointKeys+cmdKeys+selectKeys;*)
TYPE
	EventMsg* = RECORD (Objects.ObjMsg)
		gesture- : INTEGER;
		x- , y- : INTEGER;
		time- : LONGINT;
		keys: SET;
		callForResponder* : BOOLEAN;  (*= sent to poll for a responder *)
		responder* : Objects.Object; (*= reply to poll for a responder *)
		priority* : INTEGER(*= reply to poll for a responder *)

	END;

	VAR 	context: EventMsg;
	lastloc: LONGINT;  (* fof 020624 *)
	doubleClickTime*: LONGINT;

PROCEDURE GetWheelEvent*(VAR event: EventMsg; up: BOOLEAN);
VAR keys: SET; x,y: INTEGER;
BEGIN
	Input.Mouse (keys, x, y);  vyHostDisplay.DrawCursor (x, y);
	IF keys = {} THEN
		IF up THEN event.gesture := EvtWheelUp
		ELSE event.gesture := EvtWheelDown
		END;
	ELSIF keys = pointKeys THEN
		IF up THEN event.gesture := EvtPointWheelUp
		ELSE event.gesture := EvtPointWheelDown
		END;
	ELSIF keys = selectKeys THEN
		IF up THEN event.gesture := EvtSelectWheelUp
		ELSE event.gesture := EvtSelectWheelDown
		END;

	END;
	event.x := x; event.y := y;
	event.time := Oberon.Time();
	event.keys := keys + {31};
	context := event;
END GetWheelEvent;


PROCEDURE GetEvent* (VAR nextEvent: EventMsg);  (*vs 0.0a2 md  20.06.95 09:59:20 & FOF 1996*)
	(*= poll for an event and translate it to Voyager event *)

	VAR keys: SET;  x, y: INTEGER;
BEGIN
	Input.Mouse (keys, x, y);  vyHostDisplay.DrawCursor (x, y);
	IF keys = context.keys THEN nextEvent.gesture := context.gesture
	ELSIF (context.gesture >= EvtWheelDown) & (context.gesture <= EvtSelectWheelUp) THEN
			nextEvent.gesture := context.gesture;
	ELSIF keys = {} THEN nextEvent.gesture := EvtEmpty
	ELSE
		IF context.gesture = EvtEmpty THEN
			IF keys = pointKeys THEN nextEvent.gesture :=  EvtLoc;
				IF (- lastloc + Oberon.Time()) < doubleClickTime THEN nextEvent.gesture := EvtDoubleClick;
					lastloc := Oberon.Time() - 2*doubleClickTime    (* fof 020624 *)
				ELSE
					lastloc := Oberon.Time()
				END
			ELSIF keys = cmdKeys THEN nextEvent.gesture := EvtIdent;  lastloc := Oberon.Time() - 2*doubleClickTime
			ELSIF keys = selectKeys THEN nextEvent.gesture := EvtSelect;  lastloc := Oberon.Time() - 2*doubleClickTime
			ELSE nextEvent.gesture := EvtUnknown;  lastloc := Oberon.Time() - 2*doubleClickTime
			END
		ELSIF context.gesture = EvtSelect THEN
			IF keys = copyKeys THEN nextEvent.gesture := EvtCopy;   lastloc := Oberon.Time() - 2*doubleClickTime
			ELSIF keys = removeKeys THEN nextEvent.gesture := EvtRemove;   lastloc := Oberon.Time() - 2*doubleClickTime
			ELSE nextEvent.gesture := EvtUnknown;    lastloc := Oberon.Time() - 2*doubleClickTime
			END
		ELSIF context.gesture =  EvtLoc THEN
			IF keys = copyAttrKeys THEN nextEvent.gesture := EvtCopyAttr;   lastloc := Oberon.Time() - 2*doubleClickTime
			ELSIF keys = pointKeys + cmdKeys THEN nextEvent.gesture := EvtPointCmd;  lastloc := Oberon.Time() - 2*doubleClickTime
			ELSE nextEvent.gesture := EvtUnknown;   lastloc := Oberon.Time() - 2*doubleClickTime
			END
		ELSIF context.gesture = EvtIdent THEN
			IF keys = openKeys THEN nextEvent.gesture := EvtOpen;  lastloc := Oberon.Time() - 2*doubleClickTime
			ELSIF keys = cmdKeys + pointKeys THEN nextEvent.gesture := EvtCmdPoint;  lastloc := Oberon.Time() - 2*doubleClickTime
			ELSE nextEvent.gesture := EvtUnknown;  lastloc := Oberon.Time() - 2*doubleClickTime
			END
		ELSE nextEvent.gesture := EvtEmpty
		END;  (*IF context.gesture=... *)
	END;  (*IF keys=contextKeys *)

	nextEvent.x := x;  nextEvent.y := y;
	nextEvent.time := Oberon.Time();
	nextEvent.keys := keys;
	context := nextEvent
END GetEvent;

PROCEDURE ClearCurrentEvent*;
	(*vs 0.0a2 fof 28.3.96 *)
BEGIN
	(* destroys double click, find better solution ! *)
	context.keys := {};
	context.gesture := EvtEmpty;
	context.time := Oberon.Time()
END ClearCurrentEvent;

BEGIN
	doubleClickTime := CdoubleClickTime;  lastloc := Oberon.Time() - 2*doubleClickTime;
END vyEvents.
