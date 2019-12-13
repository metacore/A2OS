MODULE SdControllers;
(**
	AUTHOR Timothée Martiel, 12/2015
	PURPOSE SD Host Controller Initialization for Zynq SoC.
*)

IMPORT
	Platform, Modules, Objects, Commands,
	Sd, SdDisks, SdEnvironment, Log := SdEnvironment;

CONST
	Ready = 0;
	Running = 1;
	Stopped = 2;
	Error = 3;

TYPE
	HostController * = OBJECT
	VAR
		hc: Sd.HostController;
		handler: InterruptHandler;
		state, event: SIGNED32;
		card: Sd.Card;
		halted: BOOLEAN;

		PROCEDURE & Init (base: ADDRESS; int: SIGNED32; clock: SIGNED64);
		VAR
			result: INTEGER;
		BEGIN
			NEW(hc);
			Sd.InitHostController(hc, base);
			IF ~Sd.SetExternalClock(hc, clock, clock, result) THEN
				Log.String("[SD] Failed to initialize host controller: error code ");
				Log.Int(result, 0);
				Log.Ln;
				state := Error;
				RETURN
			END;
			state := Ready; (* Do not put this later, as events might be triggered in the constructor *)
			NEW(handler, SELF);
			SdEnvironment.InstallHandler(handler.Handle, int);
		END Init;

		PROCEDURE HandleEvent (card: Sd.Card; event: SIGNED32; param: ANY);
		BEGIN {EXCLUSIVE}
			AWAIT(state # Running);
			SELF.event := event;
			SELF.card := card;
			IF state = Ready THEN state := Running END
		END HandleEvent;

		PROCEDURE Stop;
		BEGIN {EXCLUSIVE}
			IF state < Stopped THEN state := Stopped END;
			AWAIT(halted)
		END Stop;

		PROCEDURE WaitForEventCompletion;
		BEGIN {EXCLUSIVE}
			AWAIT(state # Running)
		END WaitForEventCompletion;

	BEGIN {ACTIVE}
		LOOP
			BEGIN {EXCLUSIVE}
				AWAIT(state # Ready);
				IF state >= Stopped THEN EXIT END;
			END;
			SdDisks.HandleSdEvent(card, event);
			BEGIN {EXCLUSIVE}
				state := Ready
			END
		END
	FINALLY
		BEGIN {EXCLUSIVE} halted := TRUE END
	END HostController;

	InterruptHandler * = OBJECT
	VAR
		hc: Sd.HostController;
		timer: Objects.Timer;
		mask: SET;
		blocked: BOOLEAN;

		PROCEDURE & Init (hc: HostController);
		BEGIN
			SELF.hc := hc.hc;
			NEW(timer);
			blocked := FALSE
		END Init;

		PROCEDURE Block (hc: Sd.HostController; mask: SET; timeout: SIGNED32): BOOLEAN;
		VAR
			irqs: SET;
		BEGIN {EXCLUSIVE}
			ASSERT(hc = SELF.hc);
			blocked := TRUE;
			irqs := hc.regs.InterruptSignalEnable;
			hc.regs.InterruptSignalEnable := irqs + mask;
			SELF.mask := mask;
			Objects.SetTimeout(timer, Unblock, timeout);
			AWAIT(~blocked);
			hc.regs.InterruptSignalEnable := irqs;
			RETURN mask * hc.regs.InterruptStatus # {}
		END Block;

		PROCEDURE Unblock;
		BEGIN {EXCLUSIVE}
			blocked := FALSE
		END Unblock;

		PROCEDURE Handle;
		BEGIN
			IF hc.regs.InterruptStatus * mask # {} THEN
				Unblock;
				Objects.CancelTimeout(timer);
			END;
			Sd.HandleInterrupt(hc);
		END Handle;
	END InterruptHandler;

VAR
	hc: ARRAY 2 OF HostController;

	PROCEDURE Init;
	VAR
		i: SIGNED32;
	BEGIN
		Modules.InstallTermHandler(Cleanup);
		FOR i := 0 TO LEN(Platform.SdBase,0) - 1 DO
			IF SdEnvironment.Enable(i) THEN
				IF Sd.EnableTrace THEN
					Log.String("[SD] Enabling controller "); Log.Int(i, 0); Log.Ln;
					Log.String("[SD]	register base = "); Log.Address(Platform.SdBase[i]); Log.Ln;
					Log.String("[SD]	base clock = "); Log.Int(SdEnvironment.HcClock(i), 0); Log.String(" Hz"); Log.Ln;
					Log.String("[SD]	irq = "); Log.Int(Platform.SdIrq[i], 0); Log.Ln;
				END;
				NEW(hc[i], Platform.SdBase[i], Platform.SdIrq[i], SdEnvironment.HcClock(i));
				Sd.SetEventHandler(hc[i].hc, hc[i].HandleEvent, NIL);
				hc[i].WaitForEventCompletion;
(*				Sd.SetBlocker(hc[i].hc, hc[i].handler.Block)*)
			ELSE
				IF Sd.EnableTrace THEN
					Log.String("[SD] Not Enabling controller "); Log.Int(i, 0); Log.Ln
				END;
			END
		END
	END Init;

	PROCEDURE Cleanup;
	VAR
		i: SIGNED32;
	BEGIN
		FOR i := 0 TO LEN(hc) - 1 DO
			IF hc[i] # NIL THEN hc[i].Stop END
		END
	END Cleanup;

	PROCEDURE Statistics * (c: Commands.Context);
	VAR
		accesses: SIGNED32;
		byteRead, byteWritten, read, write: SIGNED64;
		tread, twrite: SIGNED64;
		speedR, speedW: FLOAT64;
	BEGIN
		byteRead := Sd.NbyteRead;
		byteWritten := Sd.NbyteWritten;
		read := Sd.Nread;
		write := Sd.Nwrite;
		tread := SdEnvironment.ToMicro(Sd.Tread);
		twrite := SdEnvironment.ToMicro(Sd.Twrite);

		IF read > 0 THEN
			speedR := FLOAT64(byteRead) / FLOAT64(tread);
			c.out.String("SD Statistics:"); c.out.Ln;
			c.out.String("  Bytes read: "); c.out.Int(byteRead, 0); c.out.Ln;
			c.out.String("  Number of reads: "); c.out.Int(read, 0); c.out.Ln;
			c.out.String("  Read time: "); c.out.Int(tread, 0); c.out.String(" us"); c.out.Ln;
			c.out.String("  Average read size: "); c.out.Int(byteRead DIV read, 0); c.out.String(" bytes"); c.out.Ln;
			c.out.String("  Read speed: "); c.out.FloatFix(speedR, 0, 3, 0); c.out.String(" Mb/s"); c.out.Ln;
			c.out.String("  Average read time: "); c.out.FloatFix(FLOAT64(tread) / FLOAT64(read), 0, 3, 0); c.out.String(" us"); c.out.Ln;
		ELSE
			c.out.String("No read statistics");
			c.out.Ln
		END;

		IF write > 0 THEN
			speedW := FLOAT64(byteWritten) / FLOAT64(twrite);
			c.out.String("  Bytes written: "); c.out.Int(byteWritten, 0); c.out.Ln;
			c.out.String("  Number of writes: "); c.out.Int(write, 0); c.out.Ln;
			c.out.String("  Write time: "); c.out.Int(twrite, 0); c.out.String(" us"); c.out.Ln;
			c.out.String("  Average write size: "); c.out.Int(byteWritten DIV write, 0); c.out.String(" bytes"); c.out.Ln;
			c.out.String("  Write speed: "); c.out.FloatFix(speedW, 0, 3, 0); c.out.String(" Mb/s"); c.out.Ln;
			c.out.String("  Average write time: "); c.out.FloatFix(FLOAT64(twrite) / FLOAT64(write), 0, 3, 0); c.out.String(" us"); c.out.Ln;
		ELSE
			c.out.String("No write statistics");
			c.out.Ln
		END;

		accesses := SdDisks.NcacheHits + SdDisks.NcacheMiss;
		c.out.String("SD Disks Cache Statistics"); c.out.Ln;
		c.out.String("  Number of accesses: "); c.out.Int(accesses, 0); c.out.Ln;
		c.out.String("  Number of hits: "); c.out.Int(SdDisks.NcacheHits, 0); c.out.String(" ("); c.out.FloatFix(SdDisks.NcacheHits / accesses * 100.0, 0, 2, 0); c.out.String(" %)"); c.out.Ln;
		c.out.String("  Number of misses: "); c.out.Int(SdDisks.NcacheMiss, 0); c.out.String(" ("); c.out.FloatFix(SdDisks.NcacheMiss / accesses * 100.0, 0, 2, 0); c.out.String(" %)"); c.out.Ln;
		c.out.String("  Number of evictions: "); c.out.Int(SdDisks.NcacheEvict, 0); c.out.String(" ("); c.out.FloatFix(SdDisks.NcacheEvict / SdDisks.NcacheMiss * 100.0, 0, 2, 0); c.out.String(" %)"); c.out.Ln;
		c.out.String("SD Disks Write Buffer Statistics"); c.out.Ln;
		c.out.String("  Average write size: "); c.out.FloatFix(SdDisks.NbufferSize / SdDisks.NbufferWrites, 0, 2, 0); c.out.String(" bytes"); c.out.Ln;
		c.out.String("  Average queue length: "); c.out.FloatFix(SdDisks.NbufferQueueSize / SdDisks.NbufferQueueSamples, 0, 2, 0); c.out.Ln;
		c.out.Update;
	END Statistics;

BEGIN
	Init
END SdControllers.
