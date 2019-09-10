MODULE Timer;
IMPORT Machine;

VAR
	t: SIGNED64;

	PROCEDURE Tick *;
	BEGIN
		t := Machine.GetTimer()
	END Tick;

	PROCEDURE Tock * (VAR time: SIGNED64);
	BEGIN
		time := Machine.GetTimer() - t
	END Tock;
END Timer.
