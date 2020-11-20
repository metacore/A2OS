MODULE Stopwatch;
IMPORT PrecisionTimer;

CONST TicksPerMillisecond = Counter(10000);
CONST TicksPerSecond = TicksPerMillisecond * 1000;
CONST TicksPerMinute = TicksPerSecond * 60;
CONST TicksPerHour = TicksPerMinute * 60;

VAR Frequency- := PrecisionTimer.GetFrequency(): Counter;
VAR TicksDivFrequency := FLOAT64(TicksPerSecond) / Frequency: FLOAT64;

TYPE
	Counter* = PrecisionTimer.Counter;

	T* = RECORD
		elapsed, startTimeStamp: Counter;
		isAlive-: BOOLEAN;

		PROCEDURE & Reset*( );
		BEGIN
			elapsed := 0;
			startTimeStamp := 0;
			isAlive := FALSE;
		END Reset;

		PROCEDURE Start*( );
		BEGIN
			IF ~isAlive THEN
				startTimeStamp := PrecisionTimer.GetCounter( );
				isAlive := TRUE;
			END;
		END Start;

		PROCEDURE Restart*( );
		BEGIN
			elapsed := 0;
			startTimeStamp := PrecisionTimer.GetCounter( );
			isAlive := TRUE;
		END Restart;

		PROCEDURE StartNew*( ): T;
		BEGIN
			RESULT.Start( );
			RETURN RESULT;
		END StartNew;

		PROCEDURE Stop*( );
		BEGIN
			IF isAlive THEN
				isAlive := FALSE;
				INC( elapsed, PrecisionTimer.GetCounter( ) - startTimeStamp );
				IF elapsed < 0 THEN
					elapsed := 0;
				END;
			END;
		END Stop;

		PROCEDURE Elapsed*( ): Counter;
		BEGIN
			RETURN ENTIERH( ElapsedTicks() * TicksDivFrequency );
		END Elapsed

		PROCEDURE ElapsedMilliseconds*( ): Counter;
		BEGIN
			RETURN ENTIERH( ElapsedTicks( ) * TicksDivFrequency ) DIV TicksPerMillisecond;
		END ElapsedMilliseconds;

		PROCEDURE ElapsedTicks*( ): Counter;
		BEGIN
			IF isAlive THEN
				RETURN elapsed + ( PrecisionTimer.GetCounter() - startTimeStamp );
			END;
			RETURN elapsed;
		END ElapsedTicks;

    END (* T *);

	PROCEDURE ToString*( aTicks: Counter; VAR date: ARRAY OF CHAR );
	VAR i: SIZE;

		PROCEDURE Append ( v: SIGNED32; len: SIZE; VAR s: ARRAY OF CHAR; VAR pos: SIZE );
		VAR i: SIZE;
		BEGIN
			FOR i := 1 TO len DO
				s[ pos + len - i ] := CHR( ORD ( "0" ) + v MOD 10 );
				v := v DIV 10;
			END;
			INC( pos, len );
		END Append;

	BEGIN
		i := 0;
		Append( SIGNED32( aTicks DIV TicksPerHour MOD 24 ), 2, date, i ); date[ i ] := ":"; INC( i );
		Append( SIGNED32( aTicks DIV TicksPerMinute MOD 60 ), 2, date, i ); date[ i ] := ":"; INC( i );
		Append( SIGNED32( aTicks DIV TicksPerSecond MOD 60 ), 2, date, i ); date[ i ] := ":"; INC( i );
		Append( SIGNED32( aTicks DIV TicksPerMillisecond MOD 1000 ), 3, date, i ); date[ i ] := "."; INC( i );
		Append( SIGNED32( aTicks MOD 10000), 4, date, i ); date[ i ] := 0X;
	END ToString;

END Stopwatch.

System.FreeDownTo Stopwatch~