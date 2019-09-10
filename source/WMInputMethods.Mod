MODULE WMInputMethods;	(** AUTHOR "TF"; PURPOSE "Abstract input method editor"; *)

IMPORT
	Streams, Strings, Configuration, Texts, TextUtilities, Commands, Modules;

CONST
	CR = 0DX; LF = 0AX;

TYPE
	IMEInterface* = RECORD
		AcquireText*, ReleaseText* : PROCEDURE {DELEGATE};
		InsertUCS32* : PROCEDURE {DELEGATE} (atPosition : SIZE; CONST string : Texts.UCS32String);
		GetCursorPosition* : PROCEDURE {DELEGATE} () : SIZE;
		GetCursorScreenPosition* : PROCEDURE {DELEGATE} (VAR x, y : SIZE);
		SetCursorInfo* : PROCEDURE {DELEGATE} (position : SIZE);
	END;


	IME* = OBJECT
	VAR
		interface : IMEInterface;
		valid : BOOLEAN; (* if TRUE, all delegates in <interface> are not NIL *)

		PROCEDURE &Init*;
		BEGIN
			interface := None;
			valid := FALSE;
		END Init;

		PROCEDURE GetName*() : Strings.String;
		BEGIN
			RETURN NIL
		END GetName;

		PROCEDURE SetInterface*(i : IMEInterface);
		BEGIN {EXCLUSIVE}
			ASSERT(
				 ((i.AcquireText # NIL) & (i.ReleaseText # NIL) & (i.InsertUCS32 # NIL) &
					(i.GetCursorPosition # NIL) & (i.GetCursorScreenPosition # NIL) & (i.SetCursorInfo # NIL))
				OR
				 ((i.AcquireText = NIL) & (i.ReleaseText = NIL) & (i.InsertUCS32 = NIL) &
					(i.GetCursorPosition = NIL) & (i.GetCursorScreenPosition = NIL) & (i.SetCursorInfo = NIL))
			);
			SELF.interface := i;
			valid := interface.AcquireText # NIL;
		END SetInterface;

		PROCEDURE InsertChar*(ucs : SIZE);
		VAR buf : ARRAY 2 OF Texts.Char32;
		BEGIN {EXCLUSIVE}
			IF valid THEN
				interface.AcquireText;
				interface.SetCursorInfo(1);
				buf[0] := ucs(Texts.Char32); buf[1] := 0;
				interface.InsertUCS32(interface.GetCursorPosition(), buf);
				interface.ReleaseText;
			END;
		END InsertChar;

		PROCEDURE InsertMultiChar*(CONST ucs : ARRAY OF SIGNED32);
		VAR buf : ARRAY 2 OF Texts.Char32; pos, i : SIZE;
		BEGIN {EXCLUSIVE}
			IF valid THEN
				interface.AcquireText;
				pos := interface.GetCursorPosition();
				interface.SetCursorInfo(LEN(ucs));
				buf[1] := 0;
				FOR i := 0 TO LEN(ucs) - 1 DO
					buf[0] := ucs[i];
					interface.InsertUCS32(pos, buf);
				END;
				interface.ReleaseText;
			END;
		END InsertMultiChar;

		PROCEDURE InsertUTF8String*(CONST string : ARRAY OF CHAR);
		VAR r : Streams.StringReader;
			pos, i, m: SIZE;
			tempUCS32 : ARRAY 1024 OF Texts.Char32;
			ch, last : Texts.Char32;
		BEGIN {EXCLUSIVE}
			IF valid THEN
				interface.AcquireText;
				pos := interface.GetCursorPosition();
				NEW(r, LEN(string));
				m := LEN(tempUCS32) - 1;
				r.Set(string);
				i := 0;
				REPEAT
					IF TextUtilities.GetUTF8Char(r, ch) THEN
						IF i = m THEN tempUCS32[i] := 0; interface.InsertUCS32(pos, tempUCS32); INC(pos, m); i := 0 END;
						IF (last # ORD(CR)) OR (ch # ORD(LF)) THEN
							IF ch = ORD(CR) THEN tempUCS32[i] := ORD(LF)
							ELSE tempUCS32[i] := ch
							END;
							INC(i)
						END;
						last := ch
					END
				UNTIL (r.res # Streams.Ok);
				tempUCS32[i] := 0; interface.InsertUCS32(pos, tempUCS32);
				interface.ReleaseText;
			END;
		END InsertUTF8String;

		PROCEDURE GetCursorScreenPosition*(VAR x, y : SIZE);
		BEGIN {EXCLUSIVE}
			IF valid THEN
				interface.GetCursorScreenPosition(x, y);
			ELSE
				x := 0; y := 0;
			END;
		END GetCursorScreenPosition;

		PROCEDURE KeyEvent*(ucs : SIZE; flags : SET; keysym : SIZE);
		END KeyEvent;

		PROCEDURE Hide*;
		END Hide;

		PROCEDURE Finalize*;
		BEGIN
			SetInterface(None);
		END Finalize;

	END IME;

	(* the installer will register the IME *)
	IMEInstaller*  = PROCEDURE;

	(* the switch is called to let the owner of the switch know, that the IME has been switched *)
	IMToolSwitchCallback* = PROCEDURE;

VAR
	defaultIME- : IME;
	activeIME- : IME;
	toolSwitch* : IMToolSwitchCallback;
	None- : IMEInterface;

(* Returns the installer procedure of the desired IME *)
PROCEDURE GetIME*(CONST name : ARRAY OF CHAR; VAR res : INTEGER) : IMEInstaller;
VAR
	config, installerName, msg : ARRAY 128 OF CHAR;
	moduleName, procedureName : Modules.Name;
	installer : IMEInstaller;
BEGIN
	res := -1;

	(* look in the config file for the appropriate installer's name *)
	config := "IME."; Strings.Append(config,name);
	Configuration.Get(config,installerName,res);
	(* retrieve the procedure *)
	IF (res = 0) THEN
		Commands.Split(installerName, moduleName, procedureName, res, msg);
	END;
	IF (res = 0) THEN
		GETPROCEDURE(moduleName,procedureName,installer);
	END;
	RETURN installer;
END GetIME;

(* switches the on/off-state of the default IME *)
PROCEDURE SwitchIME*() : IME;
BEGIN
	(* set the active IME to the default IME or to NIL, respectively *)
	IF activeIME = NIL THEN
		activeIME := defaultIME;
	ELSE
		activeIME := NIL;
	END;

	(* If an external tool registered a switch procedure, it is called now *)
	IF toolSwitch # NIL THEN
		toolSwitch;
	END;

	(* return the currently active IME *)
	RETURN activeIME
END SwitchIME;

(* sets a new default IME and sets it active if the old IME was active *)
PROCEDURE InstallIME*(newIME : IME);
BEGIN
	defaultIME := newIME;
	IF (activeIME # NIL) THEN
		activeIME := newIME;
	END;
END InstallIME;

BEGIN
	None.AcquireText := NIL; None.ReleaseText := NIL; None.InsertUCS32 := NIL;
	None.GetCursorPosition := NIL; None.GetCursorScreenPosition := NIL;
END WMInputMethods.
