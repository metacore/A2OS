MODULE PrivateWatchdog; (** AUTHOR "Timothée Martiel, 11/2017"; PURPOSE "Zynq private watchdog driver"; *)
IMPORT SYSTEM, Platform;

CONST
	(** Modes *)
	Reset * = TRUE; (** Resets the system *)
	Interrupt * = FALSE; (** Triggers an interrupt *)

	ControlWatchdogEnable = 0;
	ControlAutoReload = 1;
	ControlItEnable = 2;
	ControlWdMode = 3;
	ControlPrescalerOfs = 8;
	ControlPrescalerMask = {8 .. 15};

VAR
	frequency: HUGEINT;

	(** Start the private watchdog with the given mode and delay *)
	PROCEDURE Start * (mode: BOOLEAN; delay: LONGINT);
	VAR
		val: SET;
	BEGIN
		ASSERT(frequency > 0);
		Platform.mpcore.Watchdog_Reset_Status_Register := 1; (* Clear the reset status *)
		Feed(delay);
		val := {ControlWatchdogEnable};
		IF mode THEN
			(* Reset *)
			INCL(val, ControlWdMode)
		ELSE
			INCL(val, ControlItEnable)
		END;
		Platform.mpcore.Watchdog_Control_Register := SYSTEM.VAL(LONGINT, val)
	END Start;

	(** Stop private watchdog *)
	PROCEDURE Stop *;
	BEGIN
		Platform.mpcore.Watchdog_Disable_Register := Platform.PrivateWatchdogDisableKey0;
		Platform.mpcore.Watchdog_Disable_Register := LONGINT(Platform.PrivateWatchdogDisableKey1);
		Platform.mpcore.Watchdog_Control_Register := 0
	END Stop;

	(** Feed the watchdog: overwrites its count with the given delay *)
	PROCEDURE Feed * (delay: LONGINT);
	BEGIN
		Platform.mpcore.Watchdog_Load_Register := LONGINT(HUGEINT(delay) * frequency);
	END Feed;

	(** Check if the watchdog has been triggered *)
	PROCEDURE Triggered * (): BOOLEAN;
	BEGIN
		RETURN Platform.mpcore.Watchdog_Reset_Status_Register = 1
	END Triggered;

	(** Initialise watchdog reference frequency (CPU freq / 2) *)
	PROCEDURE Init * (timerFrequency: HUGEINT);
	BEGIN
		frequency := timerFrequency
	END Init;
END PrivateWatchdog.
