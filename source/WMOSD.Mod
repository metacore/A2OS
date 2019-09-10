MODULE WMOSD; (** AUTHOR "staubesv"; PURPOSE "Simple On Screen Display for messages"; *)
(**
 * Usage:
 *
 *	WMOSD.Open message-string [duration] ~ Show message-string for duration milliseconds
 *	WMOSD.Close ~
 *
 *	WMOSD.Test ~	Perform endless self-test
 *	System.Free WMOSD ~
 *
 * History:
 *
 *	03.11.2006	First release (staubesv)
 *)

IMPORT
	KernelLog, Modules, Kernel, Commands, Streams, Displays, Plugins, Random, Strings,
	WM := WMWindowManager, WMComponents, WMStandardComponents, WMGraphics;

CONST

	(* Font settings *)
	DefaultFontName = "Oberon";
	DefaultFontSize = 24;
	DefaultFontStyle = {};

	DefaultHeight = 100;

	DefaultBgFillColor = 00008080H;

	DefaultDuration = 1500; (* in millisecond, resolution: TimerResolution ms *)
	TimerResolution = 100;

TYPE

	(* Singleton overlay window *)
	Window = OBJECT(WMComponents.FormWindow)
	VAR
		label : WMStandardComponents.Label;

		timer : Kernel.Timer;
		alive, dead : BOOLEAN;

		PROCEDURE Show(CONST message : ARRAY OF CHAR);
		BEGIN
			label.caption.SetAOC(message);
		END Show;

		PROCEDURE Stop;
		BEGIN
			alive := FALSE; timer.Wakeup;
		END Stop;

		PROCEDURE IsHit*(x, y : SIZE) : BOOLEAN;
		BEGIN
			RETURN FALSE;
		END IsHit;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR font : WMGraphics.Font;
		BEGIN
			NEW(label);
			label.alignment.Set(WMComponents.AlignClient); label.fillColor.Set(DefaultBgFillColor);
			label.alignH.Set(WMGraphics.AlignCenter); label.alignV.Set(WMGraphics.AlignCenter);
			label.textColor.Set(WMGraphics.White);

			font := WMGraphics.GetFont(DefaultFontName, DefaultFontSize, DefaultFontStyle);
			IF font # NIL THEN
				label.SetFont(font);
			ELSE
				KernelLog.String("Font "); KernelLog.String(DefaultFontName); KernelLog.String(" not found."); KernelLog.Ln;
			END;

			RETURN label;
		END CreateForm;

		PROCEDURE &New*;
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			NEW(timer); alive := TRUE; dead := FALSE;
			vc := CreateForm();
			Init(width, DefaultHeight, TRUE);
			SetContent(vc);
			SetTitle(WM.NewString("Overlay Window"));
			WM.ExtAddViewBoundWindow(SELF, 0, 0, NIL, {WM.FlagNoFocus, WM.FlagStayOnTop, WM.FlagHidden});
		END New;

	BEGIN {ACTIVE}
		REPEAT
			timer.Sleep(TimerResolution);
		UNTIL ~alive OR TimeExpired();

		Close;

		DecNofWindows;
	END Window;

VAR
	window : Window; (* exclusive access only! *)
	width, height : SIGNED32;
	timeleft : SIGNED32; (* exclusive access only! *)
	nofWindows : SIGNED32;

	testsRunning : SIGNED32; (* exclusive access only! *)
	stopSelftest : BOOLEAN;

PROCEDURE DecNofWindows;
BEGIN {EXCLUSIVE}
	DEC(nofWindows);
END DecNofWindows;

PROCEDURE TimeExpired() : BOOLEAN;
BEGIN {EXCLUSIVE}
	DEC(timeleft, TimerResolution);
	RETURN timeleft < 0;
END TimeExpired;

PROCEDURE Show*(CONST message : ARRAY OF CHAR; duration : SIGNED32);
BEGIN {EXCLUSIVE}
	IF duration <= 0 THEN duration := 500; END;
	IF window # NIL THEN
		IF timeleft > 0 THEN
			timeleft := duration;
			window.Show(message);
		ELSE (* too late, window will be closed soon *)
			window.Stop; window := NIL;
			timeleft := duration;
			INC(nofWindows);
			NEW(window); window.Show(message);
		END;
	ELSE
		timeleft := duration;
		INC(nofWindows);
		NEW(window); window.Show(message);
	END;
END Show;

(**	Show the specified message.
	Optionally specified the duration in milliseconds the window is visible. *)
PROCEDURE Open*(context : Commands.Context); (** message_string [duration] ~ *)
VAR message : ARRAY 1024 OF CHAR; duration : SIGNED32;
BEGIN
	IF context.arg.GetString(message) THEN
		IF ~context.arg.GetInteger(duration, FALSE) OR (duration <= 0)  THEN duration := DefaultDuration; END;
		Show(message, duration);
	ELSE
		context.result := Commands.CommandParseError;
	END;
END Open;

(** Close the overlay window if it's open *)
PROCEDURE Close*; (** ~ *)
BEGIN {EXCLUSIVE}
	IF window # NIL THEN window.Stop; window := NIL; END;
END Close;

(** Perform endless self-test. To stop the tests, unload the module. Multiple instances can run simultaneously. *)
PROCEDURE Test*(context : Commands.Context); (** ~ *)
CONST MinDuration = 1; MaxDuration = 100000;
VAR
	random : Random.Generator; timer : Kernel.Timer;
	number : SIGNED32; message : ARRAY 128 OF CHAR;
BEGIN
	BEGIN {EXCLUSIVE}
		stopSelftest := FALSE; INC(testsRunning);
		context.out.String("Overlay Window test started ("); context.out.Int(testsRunning, 0);
		context.out.String(" instances)"); context.out.Ln;
		context.out.Update;
	END;
	NEW(random); NEW(timer);
	LOOP
		number := random.Dice(MaxDuration) + MinDuration;
		Strings.IntToStr(number, message);
		Show(message, number);
		number := random.Dice(2000) + 1;
		timer.Sleep(number);
		IF number MOD 10 = 0 THEN Close; END;
		IF stopSelftest THEN EXIT; END;
	END;
	BEGIN {EXCLUSIVE} DEC(testsRunning); END;
END Test;

PROCEDURE Init;
VAR plugin : Plugins.Plugin;
BEGIN
	plugin := Displays.registry.Get("");
	IF plugin # NIL THEN
		width := plugin(Displays.Display).width;
		height := plugin(Displays.Display).height;
	ELSE
		width := 1024;
		height := 768;
	END;
END Init;

PROCEDURE Cleanup;
BEGIN {EXCLUSIVE}
	IF testsRunning > 0 THEN
		stopSelftest := TRUE;
		AWAIT(testsRunning = 0);
	END;
	IF window # NIL THEN window.Stop; AWAIT(nofWindows = 0); END;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	Init;
END WMOSD.

WMOSD.Open "Hello World" 10000~
WMOSD.Open "Check this" 1000 ~

WMOSD.Close ~

WMOSD.Test ~

System.Free WMOSD ~
