MODULE Timer;
IMPORT Machine;

VAR
	t: HUGEINT;

	PROCEDURE Tick *;
	BEGIN
		t := Machine.GetTimer()
	END Tick;

	PROCEDURE Tock * (VAR time: HUGEINT);
	BEGIN
		time := Machine.GetTimer() - t
	END Tock;
END Timer.
