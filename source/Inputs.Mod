(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Inputs; (** AUTHOR "pjm"; PURPOSE "Abstract input device"; *)

(* Based on SemInput.Mod by Marc Frei *)

IMPORT Machine, Kernel, Plugins;

CONST
		(** KeyboardMsg flags. *)
	Release* = 0;	(** a key release event, otherwise a key press or repeat. *)

		(** shift key states. *)
	LeftShift* = 1; RightShift* = 2; LeftCtrl* = 3; RightCtrl* = 4;
	LeftAlt* = 5; RightAlt* = 6; LeftMeta* = 7; RightMeta* = 8;

		(** combined shift key states. *)
	Shift* = {LeftShift, RightShift}; Ctrl* = {LeftCtrl, RightCtrl};
	Alt* = {LeftAlt, RightAlt}; Meta* = {LeftMeta, RightMeta};

		(** flags for KeyState *)
	SHIFT* = 0;  CTRL* = 1;  ALT* = 2;

		(** keysym values, similar to X11 keysyms *)
	KsNil* = 0FFFFFFH;	(** no key *)

		(** TTY Functions, cleverly chosen to map to ascii *)
	KsBackSpace* = 0FF08H;	(** back space, back char *)
	KsTab* = 0FF09H;
	KsReturn* = 0FF0DH;	(** Return, enter *)
	KsPause* = 0FF13H;	(** Pause, hold *)
	KsScrollLock* = 0FF14H;
	KsSysReq* = 0FF15H;
	KsEscape* = 0FF1BH;
	KsDelete* = 0FFFFH;	(** Delete, rubout *)

		(** Cursor control & motion *)
	KsHome* = 0FF50H;
	KsLeft* = 0FF51H;	(** Move left, left arrow *)
	KsUp* = 0FF52H;	(** Move up, up arrow *)
	KsRight* = 0FF53H;	(** Move right, right arrow *)
	KsDown* = 0FF54H;	(** Move down, down arrow *)
	KsPageUp* = 0FF55H;	(** Prior, previous *)
	KsPageDown* = 0FF56H;	(** Next *)
	KsEnd* = 0FF57H;	(** EOL *)

		(** Misc Functions *)
	KsPrint* = 0FF61H;
	KsInsert* = 0FF63H;	(** Insert, insert here *)
	KsMenu* = 0FF67H;	(** Windows menu *)
	KsBreak* = 0FF6BH;
	KsNumLock* = 0FF7FH;

		(** Keypad functions *)
	KsKPEnter* = 0FF8DH;	(** enter *)
	KsKPMultiply* = 0FFAAH;
	KsKPAdd* = 0FFABH;
	KsKPSubtract* = 0FFADH;
	KsKPDecimal* = 0FFAEH;
	KsKPDivide* = 0FFAFH;

		(** Function keys *)
	KsF1* = 0FFBEH; KsF2* = 0FFBFH; KsF3* = 0FFC0H; KsF4* = 0FFC1H; KsF5* = 0FFC2H; KsF6* = 0FFC3H;
	KsF7* = 0FFC4H; KsF8* = 0FFC5H; KsF9* = 0FFC6H; KsF10* = 0FFC7H; KsF11* = 0FFC8H; KsF12* = 0FFC9H;

		(** Modifiers *)
	KsShiftL* = 0FFE1H;	(** Left shift *)
	KsShiftR* = 0FFE2H;	(** Right shift *)
	KsControlL* = 0FFE3H;	(** Left control *)
	KsControlR* = 0FFE4H;	(** Right control *)
	KsCapsLock* = 0FFE5H;	(** Caps lock *)
	KsMetaL* = 0FFE7H;	(** Left meta, Left Windows *)
	KsMetaR* = 0FFE8H;	(** Right meta, Right Windows *)
	KsAltL* = 0FFE9H;	(** Left alt *)
	KsAltR* = 0FFEAH;	(** Right alt *)

		(** HID Consumer Keys**)
	KsScanPreviousTrack*=	0FF0000H;
	KsScanNextTrack*= 		0FF0001H;
	KsALConsumerControl*= 	0FF0002H;
	KsMute*= 				0FF0003H;
	KsVolumeDecrement*= 	0FF0004H;
	KsVolumeIncrement*= 	0FF0005H;
	KsPlayPause*= 			0FF0006H;
	KsStopOSC*=			0FF0007H;
	KsALEmailReader*=		0FF0008H;
	KsALCalculator*=		0FF0009H;
	KsACSearch*=			0FF000AH;
	KsACHome*=			0FF000BH;
	KsACBack*=				0FF000CH;
	KsACForward*=			0FF000DH;
	KsACBookmarks*=		0FF000EH;
	KsConsumerButtons*=	0FFF000H;

TYPE
	Message* = RECORD END;	(** generic message. *)

	KeyboardMsg* = RECORD (Message)
		ch*: CHAR;	(** extended ASCII key code, or 0X if not relevant *)
		flags*: SET;	(** key flags *)
		keysym*: SIGNED32	(** X11-compatible key code *)
	END;

	MouseMsg* = RECORD (Message)
		keys*: SET;	(** mouse key state. *)
		dx*, dy*, dz*: SIGNED32	(** mouse movement vector. *)
	END;

	AbsMouseMsg*= RECORD(Message);
		keys*: SET;
		x*,y*,z*,dx*,dy*,dz*: SIGNED32;
	END;

	PointerMsg* = RECORD (Message)
		keys*: SET;	(** pointer key state. *)
		x*, y*, z*: SIGNED32;	(** pointer position. *)
		mx*, my*, mz*: SIGNED32	(** pointer max values. *)
	END;

TYPE
	Sink* = OBJECT	(** a message receiver. *)
		(** Handle is overriden by a concrete receiver. *)
		PROCEDURE Handle*(VAR msg: Message);
		BEGIN HALT(301) END Handle;
	END Sink;

	Group* = OBJECT	(** a group of message receivers. *)
		(** Add a receiver to a group. *)
		PROCEDURE Register*(s: Sink);
		BEGIN HALT(301) END Register;

		(** Remove a receiver from a group. *)
		PROCEDURE Unregister*(s: Sink);
		BEGIN HALT(301) END Unregister;

		(** Send a message to all receivers currently in the group. *)
		PROCEDURE Handle*(VAR msg: Message);
		BEGIN HALT(301) END Handle;
	END Group;

TYPE
	Pointer* = OBJECT (Sink)	(** convert incremental movements into absolute positions *)
		VAR
			cur: PointerMsg;
			threshold, speedup: SIGNED32;
			fixedKeys: SET;

		PROCEDURE Update;
		VAR p: PointerMsg;
		BEGIN
			IF cur.x < 0 THEN cur.x := 0
			ELSIF cur.x > cur.mx THEN cur.x := cur.mx
			END;
			IF cur.y < 0 THEN cur.y := 0
			ELSIF cur.y > cur.my THEN cur.y := cur.my
			END;
			IF cur.z < 0 THEN cur.z := 0
			ELSIF cur.z > cur.mz THEN cur.z := cur.mz
			END;
			p := cur; p.keys := p.keys + fixedKeys;
			pointer.Handle(p)
		END Update;

		PROCEDURE SetKeys(keys: SET);
		BEGIN {EXCLUSIVE}
			fixedKeys := keys; Update
		END SetKeys;

		PROCEDURE Handle*(VAR m: Message);
		VAR dx, dy: SIGNED32;
		BEGIN {EXCLUSIVE}
			IF m IS MouseMsg THEN
				WITH m: MouseMsg DO
				dx := m.dx; dy := m.dy;
				IF (ABS(dx) > threshold) OR (ABS(dy) > threshold) THEN
					dx := dx*speedup DIV 10; dy := dy*speedup DIV 10
				END;
				INC(cur.x, dx); INC(cur.y, dy); INC(cur.z, m.dz);
				cur.keys := m.keys;
				Update;
				END;
			ELSIF m IS AbsMouseMsg THEN
				WITH m: AbsMouseMsg DO
					cur.x := m.x; cur.y := m.y; cur.z := m.z;
					cur.keys := m.keys;
					Update
				END;
			END
		END Handle;

		PROCEDURE SetLimits*(mx, my, mz: SIGNED32);
		BEGIN {EXCLUSIVE}
			cur.mx := mx; cur.my := my; cur.mz := mz;
			Update
		END SetLimits;

		PROCEDURE &Init*(t, s: SIGNED32);
		BEGIN
			threshold := t; speedup := s;
			cur.x := 0; cur.y := 0; cur.z := 0;
			cur.mx := 1; cur.my := 1; cur.mz := 1;
			cur.keys := {}; fixedKeys := {};
			mouse.Register(SELF)
		END Init;

	END Pointer;

TYPE
	List = POINTER TO RECORD
		next: List;
		s: Sink
	END;

	Broadcaster = OBJECT (Group)
		VAR sentinel: List;

		PROCEDURE Register*(s: Sink);
		VAR n: List;
		BEGIN {EXCLUSIVE}
			NEW(n); n.s := s; n.next := sentinel.next; sentinel.next := n
		END Register;

		PROCEDURE Unregister*(s: Sink);
		VAR n: List;
		BEGIN {EXCLUSIVE}
			n := sentinel;
			WHILE (n.next # NIL) & (n.next.s # s) DO n := n.next END;
			IF n.next # NIL THEN n.next := n.next.next END
		END Unregister;

		PROCEDURE Handle*(VAR msg: Message);
		VAR n: List;
		BEGIN {EXCLUSIVE}
			n := sentinel.next;
			WHILE n # NIL DO n.s.Handle(msg); n := n.next END
		END Handle;

	END Broadcaster;


TYPE
	OberonInput* = OBJECT (Plugins.Plugin)
		VAR timer-: Kernel.Timer;

		PROCEDURE Mouse*(VAR x, y: SIGNED16; VAR keys:SET);
		BEGIN
			HALT(99)	(* abstract *)
		END Mouse;

		PROCEDURE Read*(VAR ch: CHAR; VAR break: BOOLEAN);
		BEGIN
			HALT(99)	(* abstract *)
		END Read;

		PROCEDURE Available*(VAR num: SIGNED16; VAR break: BOOLEAN);
		BEGIN
			HALT(99)	(* abstract *)
		END Available;

		PROCEDURE KeyState*(VAR k: SET);
		BEGIN
			HALT(99)	(* abstract *)
		END KeyState;

		PROCEDURE &Init*;
		BEGIN
			NEW(timer)
		END Init;

	END OberonInput;

TYPE
	MouseFixer = OBJECT (Sink)
		VAR ctrl: BOOLEAN;

		PROCEDURE Handle*(VAR m: Message);
		VAR new: BOOLEAN;
		BEGIN {EXCLUSIVE}
			WITH m: KeyboardMsg DO
				new := m.flags * Ctrl # {};
				IF new # ctrl THEN
					ctrl := new;
					IF ctrl THEN main.SetKeys({1}) ELSE main.SetKeys({}) END
				END
			END
		END Handle;

		PROCEDURE &Init*;
		BEGIN
			ctrl := FALSE; keyboard.Register(SELF)
		END Init;

	END MouseFixer;

VAR
	keyboard*, mouse*, pointer*: Group;
	main*: Pointer;
	oberonInput*: Plugins.Registry;
	mouseFixer: MouseFixer;

(** Return a default message broadcaster instance. *)
PROCEDURE NewBroadcaster*(): Group;
VAR b: Broadcaster;
BEGIN
	NEW(b); NEW(b.sentinel); b.sentinel.next := NIL;
	RETURN b
END NewBroadcaster;

PROCEDURE Init;
VAR s: ARRAY 16 OF CHAR; i: SIZE; threshold, speedup: SIGNED32;
BEGIN
	Machine.GetConfig("Threshold", s);
	i := 0; threshold := Machine.StrToInt(i, s);
	IF threshold <= 0 THEN threshold := 5 END;
	Machine.GetConfig("Speedup", s);
	i := 0; speedup := Machine.StrToInt(i, s);
	IF speedup <= 0 THEN speedup := 15 END;
	NEW(main, threshold, speedup);
	Machine.GetConfig("MB", s);
	IF (s = "2") OR (s = "-2") THEN NEW(mouseFixer) END
END Init;

BEGIN
	keyboard := NewBroadcaster();
	mouse := NewBroadcaster();
	pointer := NewBroadcaster();
	NEW(oberonInput, "Inputs", "Oberon input drivers");
	Init
END Inputs.
