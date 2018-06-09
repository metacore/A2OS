MODULE BeepTest; (** AUTHOR "afi"; PURPOSE "Hearing test using PC speaker"; *)

IMPORT Beep, Kernel, KernelLog;

VAR busy : BOOLEAN; timer : Kernel.Timer;

PROCEDURE Go*;
VAR i : LONGINT;
BEGIN
	IF ~busy THEN
		busy := TRUE;
		FOR i := 1 TO 20 DO	(* in 250Hz steps of 1 second *)
			KernelLog.Int(i * 250, 5);
			Beep.Beep(i * 250);
			timer.Sleep(1000);
			Beep.Beep(0);
		END;
		KernelLog.Ln;
		KernelLog.String("Done");
		KernelLog.Ln;
		busy := FALSE;
	END;
END Go;

BEGIN
	NEW(timer);
END BeepTest.

BeepTest.Go ~
System.Free BeepTest ~
