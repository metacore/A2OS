(** Watches the USB state *)
MODULE USBTestWatcher;

IMPORT SYSTEM, Trace, Machine, Kernel;

CONST
	USBCmd = ADDRESS(0E0002140H);
	USBSts = ADDRESS(0E0002144H);
	PortSc = ADDRESS(0E0002184H);
	OtgSc = ADDRESS(0E00021A4H);
	UsbMode = ADDRESS(0E00021A8H);

TYPE
	Watcher = OBJECT
	VAR
		timer: Kernel.Timer;

		PROCEDURE & Init *;
		BEGIN
			NEW(timer)
		END Init;

		PROCEDURE Watch;
		VAR
			interrupts: BOOLEAN;
		BEGIN
			interrupts := Machine.AreInterruptsEnabled();
			Machine.Acquire(Machine.TraceOutput);
			Trace.Ln; Trace.StringLn("===== USB Watcher =====");

			Trace.String("Interrupts:	"); Trace.Boolean(interrupts); Trace.String(" -- "); Trace.Address(SYSTEM.VAL(ADDRESS, Machine.proc[0].locksHeld)); Trace.Ln;
			Trace.String("USBCmd:	"); Trace.Address(SYSTEM.GET32(USBCmd)); Trace.Ln;
			Trace.String("USBSts:	"); Trace.Address(SYSTEM.GET32(USBSts)); Trace.Ln;
			Trace.String("Port SC:	"); Trace.Address(SYSTEM.GET32(PortSc)); Trace.Ln;
			Trace.String("OTG SC:	"); Trace.Address(SYSTEM.GET32(OtgSc)); Trace.Ln;
			Trace.String("USB Mode:	"); Trace.Address(SYSTEM.GET32(UsbMode)); Trace.Ln;

			Trace.StringLn("==== End USB Watcher ===="); Trace.Ln;
			Machine.Release(Machine.TraceOutput);

			IF ~interrupts THEN
				Trace.StringLn("Enabling interrupts");
				Machine.EnableInterrupts
			END;
		END Watch;
	BEGIN {ACTIVE}
		LOOP
			Watch;
			timer.Sleep(1000)
		END;
	END Watcher;

VAR
	watcher: Watcher;
	i: SIGNED32;

BEGIN
	NEW(watcher)
END USBTestWatcher.
