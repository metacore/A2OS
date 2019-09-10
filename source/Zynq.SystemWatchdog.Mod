MODULE SystemWatchdog; (** AUTHOR "Timothée Martiel"; PURPOSE "Zynq system watchdog driver"; *)

IMPORT SYSTEM, Platform;

CONST
	(** Modes *)
	Reset * = TRUE; (** In this mode, the watchdog resets the whole system when triggered *)
	Irq * = FALSE; (** In this mode, the watchdog triggers IRQ 30 *)

	ZmrWdEn = 0;
	ZmrRstEn = 1;
	ZmrIrqEn = 2;
	ZmrIrqLen4 = {};
	ZmrIrqLen8 = {7};
	ZmrIrqLen16 = {8};
	ZmrIrqLen32 = {7, 8};
	ZmrIrqLenMask = {7, 8};
	ZmrKey = LSH(SIGNED32(0ABCH), 12); (*0AB'C0'00H;*)

	CcrDelayMask = {2 .. 13};
	CcrPrescalerMask = 3H;
	CcrKey = 92'00'00H;

	RestartKey = 1999H;

	(** Start the watchdog for delay ms *)
	PROCEDURE Start * (mode: BOOLEAN; delay: SIGNED32);
	VAR val: SET;
	BEGIN
		Stop;
		(* Set clock input *)
		Platform.slcr.SLCR_UNLOCK := Platform.SlcrUnlockKey;
		Platform.slcr.WDT_CLK_SEL := 0;
		Platform.slcr.SLCR_LOCK := Platform.SlcrLockKey;

		(* Set delay *)
		val := SYSTEM.VAL(SET, LSH(delay * 150'000', -12) + 1) * CcrDelayMask;
		Platform.swdt.XWDTPS_CCR_OFFSET := CcrKey + SYSTEM.VAL(SIGNED32, val);

		(* Enable Watchdog *)
		IF mode THEN
			INCL(val, ZmrRstEn)
		ELSE
			INCL(val, ZmrIrqEn)
		END;
		INCL(val, ZmrWdEn);
		val := val + ZmrIrqLen4;
		Platform.swdt.XWDTPS_ZMR_OFFSET := ZmrKey + SYSTEM.VAL(SIGNED32, val);
		Feed
	END Start;

	(** Stop the watchdog *)
	PROCEDURE Stop *;
	BEGIN
		Platform.swdt.XWDTPS_ZMR_OFFSET := ZmrKey
	END Stop;

	(** Feed the watchdog: set its count to delay ms *)
	PROCEDURE Feed *;
	BEGIN
		Platform.swdt.XWDTPS_RESTART_OFFSET := RestartKey;
	END Feed;

	PROCEDURE Test *;
	BEGIN
		Start(Reset, 100)
	END Test;
END SystemWatchdog.
