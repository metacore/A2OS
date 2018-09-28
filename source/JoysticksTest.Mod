MODULE JoysticksTest; (** AUTHOR "staubesv"; PURPOSE "Joystick simulator for testing purposes"; *)
(**
 * Usage:
 *
 *	JoysticksTest.CreateJoystick [nbrOfButtons] ~ creates a new simulated joystick
 *	System.Free JoysticksTest ~	unload module, unregisters all simulated joysticks at Joysticks.registry
 *
 * History:
 *
 *	28.11.2006	First release (staubesv)
 *)

IMPORT
	KernelLog, Modules, Kernel, Plugins, Commands, Random, Joysticks;

CONST
	DefaultNbrOfButtons = 2;

	MaxSimulatedJoysticks = 16;

	MinAxisValueX = -255;
	MaxAxisValueX = 255;

	MinAxisValueY = 0;
	MaxAxisValueY = 1024;

	MinAxisValueSlider1 = -16384;
	MaxAxisValueSlider1 = 16384;

	MinAxisDefaultValue = -1024;
	MaxAxisDefaultValue = 1024;

	MinSleepTime = 200;
	MaxSleepTime = 1500;

TYPE

	SimulatedJoystick = OBJECT(Joysticks.Joystick)
	VAR
		msg : Joysticks.JoystickDataMessage;
		random : Random.Generator;
		timer : Kernel.Timer;
		alive, dead : BOOLEAN;
		i, minValue, maxValue : LONGINT;

		PROCEDURE Stop;
		BEGIN {EXCLUSIVE}
			alive := FALSE; timer.Wakeup;
			AWAIT(dead);
		END Stop;

		PROCEDURE &Init*(nbrOfButtons  : LONGINT);
		BEGIN
			Init^(nbrOfButtons);
			alive := TRUE; dead := FALSE;
			NEW(timer);
			NEW(random);
		END Init;

	BEGIN {ACTIVE}
		WHILE alive DO
			FOR i := 0 TO nbrOfButtons-1 DO
				IF random.Dice(2) = 1 THEN
					INCL(msg.buttons, i);
				ELSE
					EXCL(msg.buttons, i);
				END;
			END;
			FOR i := 0 TO Joysticks.MaxNbrOfAxis - 1 DO
				IF i IN implementedAxis THEN
					CASE i OF
						| Joysticks.AxisX: minValue := MinAxisValueX; maxValue := MaxAxisValueX;
						| Joysticks.AxisY: minValue := MinAxisValueY; maxValue := MaxAxisValueY;
						| Joysticks.Slider1: minValue := MinAxisValueSlider1; maxValue := MaxAxisValueSlider1;
					ELSE
						minValue := MinAxisDefaultValue; maxValue := MaxAxisDefaultValue;
					END;
					msg.axis[i] := random.Dice(maxValue - minValue) + 1 + minValue;
				END;
			END;
			FOR i := 0 TO nbrOfCoolieHats-1 DO
				EXCL(msg.coolieHat[i], random.Dice(4));
				EXCL(msg.coolieHat[i], random.Dice(4));
				INCL(msg.coolieHat[i], random.Dice(4));
			END;
			Handle(msg);
			timer.Sleep(random.Dice(MaxSleepTime - MinSleepTime) + MinSleepTime);
		END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END SimulatedJoystick;

VAR
	joysticks : ARRAY MaxSimulatedJoysticks OF SimulatedJoystick;
	nbrOfJoysticks : LONGINT;

PROCEDURE CreateJoystick*(context : Commands.Context); (* [nbrOfButtons] ~ *)
VAR joystick : SimulatedJoystick; nbrOfButtons, nbrOfAxis: LONGINT; res : WORD;
BEGIN
	context.arg.SkipWhitespace; context.arg.Int(nbrOfButtons, FALSE);
	context.arg.SkipWhitespace; context.arg.Int(nbrOfAxis, FALSE);
	IF nbrOfButtons <= 0 THEN nbrOfButtons := DefaultNbrOfButtons; END;
	IF nbrOfJoysticks < LEN(joysticks) THEN
		NEW(joystick, nbrOfButtons);
		joystick.AddAxis(Joysticks.AxisX, MinAxisValueX, MaxAxisValueX);
		joystick.AddAxis(Joysticks.AxisY, MinAxisValueY, MaxAxisValueY);
		joystick.AddAxis(Joysticks.Slider1, MinAxisValueSlider1, MaxAxisValueSlider1);
		joystick.AddCoolieHat;
		joystick.AddCoolieHat;
		joystick.desc := "Simulated Joystick";
		joysticks[nbrOfJoysticks] := joystick;
		INC(nbrOfJoysticks);
		Joysticks.registry.Add(joystick, res);
		IF res = Plugins.Ok THEN
			context.out.String("Joystick created."); KernelLog.Ln;
		ELSE
			context.error.String("Could not add joystick to registry, res: "); context.error.Int(res, 0); context.error.Ln;
		END;
	ELSE
		context.error.String("Maximum number of joysticks exceeded."); context.error.Ln;
	END;
END CreateJoystick;

PROCEDURE Cleanup;
VAR i : LONGINT;
BEGIN
	FOR i := 0 TO MaxSimulatedJoysticks - 1 DO
		IF joysticks[i] # NIL THEN
			joysticks[i].Stop;
			Joysticks.registry.Remove(joysticks[i]);
			joysticks[i] := NIL;
		END;
	END;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END JoysticksTest.

Joysticks.Show ~

JoysticksTest.CreateJoystick ~

System.Free WMJoysticks JoysticksTest Joysticks ~

WMJoysticks.Open ~