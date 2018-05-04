MODULE SdControllers;
(**
	AUTHOR Timothée Martiel, 12/2015
	PURPOSE SD Host Controller Initialization for Zynq SoC.
*)

IMPORT
	Platform,
	Sd, SdDisks, SdEnvironment;

CONST
	Trace = FALSE;

VAR
	hc0, hc1: Sd.HostController;

	PROCEDURE HandleInterruptSd0;
	BEGIN
		Sd.HandleInterrupt(hc0);
	END HandleInterruptSd0;

	PROCEDURE HandleInterruptSd1;
	BEGIN
		Sd.HandleInterrupt(hc1)
	END HandleInterruptSd1;

	PROCEDURE Init;
	VAR
		i, result: LONGINT;
	BEGIN
		Platform.slcr.SDIO_CLK_CTRL := 0;
		FOR i := 0 TO Platform.SdNb - 1 DO
			IF SdEnvironment.Enable(i) THEN
			 	IF Trace THEN
					SdEnvironment.String("[SD] Enabling controller "); SdEnvironment.Int(i, 0); SdEnvironment.Ln;
					SdEnvironment.String("[SD]	clock = "); SdEnvironment.Int(SdEnvironment.HcClock(i), 0); SdEnvironment.String(" Hz"); SdEnvironment.Ln;

					SdEnvironment.String("[SD]	regs = "); SdEnvironment.Address(Platform.SdBase[0]); SdEnvironment.Ln;
					SdEnvironment.String("[SD]	irq = "); SdEnvironment.Int(Platform.SdIrq[0], 0); SdEnvironment.Ln
				END;
				INC(Platform.slcr.SDIO_CLK_CTRL, LSH(LONGINT(1), i));
				CASE i OF
					 0:
					 	NEW(hc0);
						Sd.InitHostController(hc0, Platform.SdBase[0]);
						IF Sd.SetExternalClock(hc0, SdEnvironment.HcClock(i), SdEnvironment.HcClock(i), result) THEN
							Sd.SetEventHandler(hc0, SdDisks.HandleSdEvent, NIL);
							SdEnvironment.InstallHandler(HandleInterruptSd0, Platform.SdIrq[0])
						ELSE
							SdEnvironment.String("[SD] Failed to enable controller 0: error code ");
							SdEnvironment.Int(result, 0);
							SdEnvironment.Ln
						END

					|1:
						NEW(hc1);
						Sd.InitHostController(hc1, Platform.SdBase[1]);
						IF Sd.SetExternalClock(hc1, SdEnvironment.HcClock(i), SdEnvironment.HcClock(i), result) THEN
							Sd.SetEventHandler(hc1, SdDisks.HandleSdEvent, NIL);
							SdEnvironment.InstallHandler(HandleInterruptSd1, Platform.SdIrq[1])
						ELSE
							SdEnvironment.String("[SD] Failed to enable controller 0: error code ");
							SdEnvironment.Int(result, 0);
							SdEnvironment.Ln
						END
				END
			ELSE
				IF Trace THEN
					SdEnvironment.String("[SD] Not Enabling controller "); SdEnvironment.Int(i, 0); SdEnvironment.Ln
				END
			END
		END
	END Init;

BEGIN
	Init
END SdControllers.
