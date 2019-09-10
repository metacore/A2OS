MODULE ActiveTimers;

IMPORT
	Objects;

TYPE
	Timer* = OBJECT
		VAR
			timer: Objects.Timer;
			handler: Objects.EventHandler;
			timeout, running: BOOLEAN;

		PROCEDURE &Init*;
		BEGIN
			NEW(timer);
			timeout := FALSE;
			running := TRUE;
		END Init;

		PROCEDURE SetTimeout*(h: Objects.EventHandler; ms: SIGNED32);
		BEGIN
			handler := h;
			Objects.SetTimeout(timer, HandleTimeout, ms)
		END SetTimeout;

		PROCEDURE CancelTimeout*;
		BEGIN
			Objects.CancelTimeout(timer);
		END CancelTimeout;

		PROCEDURE HandleTimeout;
		BEGIN {EXCLUSIVE}
			timeout := TRUE
		END HandleTimeout;

		PROCEDURE Finalize*;
		BEGIN {EXCLUSIVE}
			Objects.CancelTimeout(timer);
			running := FALSE
		END Finalize;

	BEGIN {ACTIVE}
		WHILE running DO
			LOOP
				BEGIN {EXCLUSIVE}
					AWAIT(timeout OR ~running);
					IF ~running THEN
						EXIT
					END;
					timeout := FALSE
				END;
				handler()
			END
		END
	END Timer;

END ActiveTimers.