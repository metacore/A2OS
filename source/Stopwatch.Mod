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

	Ref* = POINTER TO T;
	T* = RECORD
		elapsed, started: Counter;
		isAlive-: BOOLEAN;

		PROCEDURE & Reset*( );
		BEGIN
			elapsed := 0;
			started := 0;
			isAlive := FALSE;
		END Reset;

		PROCEDURE Start*( );
		BEGIN
			IF ~isAlive THEN
				started := PrecisionTimer.GetCounter( );
				isAlive := TRUE;
			END;
		END Start;

		PROCEDURE Restart*( );
		BEGIN
			elapsed := 0;
			started := PrecisionTimer.GetCounter( );
			isAlive := TRUE;
		END Restart;

		PROCEDURE StartNew*( ): T;
		BEGIN
			RESULT.Start( );
			RETURN RESULT;
		END StartNew;

		PROCEDURE StartNewRef*( ): Ref;
		BEGIN
			RESULT := NEW Ref();
			RESULT.Start( );
			RETURN RESULT;
		END StartNewRef;

		PROCEDURE Stop*( );
		BEGIN
			VAR current := PrecisionTimer.GetCounter( );
			IF isAlive THEN
				INC( elapsed,  current - started );
				IF elapsed < 0 THEN
					elapsed := 0;
				END;
				isAlive := FALSE;
			END;
		END Stop;

		PROCEDURE Elapsed*( ): Counter;
		BEGIN
			RETURN ENTIERH( ElapsedTicks( ) * TicksDivFrequency + 0.5 );
		END Elapsed;

		PROCEDURE ElapsedReal*( ): FLOAT64;
		BEGIN
			RETURN ElapsedTicks( ) * TicksDivFrequency;
		END ElapsedReal;

		PROCEDURE ElapsedMilliseconds*( ): Counter;
		BEGIN
			RETURN ENTIERH( ElapsedTicks( ) * TicksDivFrequency + 0.5 ) DIV TicksPerMillisecond;
		END ElapsedMilliseconds;

		PROCEDURE ElapsedTicks*( ): Counter;
		BEGIN
			VAR current := PrecisionTimer.GetCounter( );
			IF isAlive THEN
				RETURN elapsed + ( current - started );
			END;
			RETURN elapsed;
		END ElapsedTicks;

    END (* T *);

	PROCEDURE Append( v: SIGNED32; len: SIZE; VAR s: ARRAY OF CHAR; VAR pos: SIZE );
	VAR i: SIZE;
	BEGIN
		FOR i := 1 TO len DO
			s[ pos + len - i ] := CHR( ORD ( "0" ) + v MOD 10 );
			v := v DIV 10;
		END;
		INC( pos, len );
	END Append;

	PROCEDURE ToString*( aTicks: Counter; VAR date: ARRAY OF CHAR );
	VAR i: SIZE;
	BEGIN
		i := 0;
		Append( SIGNED32( aTicks DIV TicksPerHour MOD 24 ), 2, date, i ); date[ i ] := ":"; INC( i );
		Append( SIGNED32( aTicks DIV TicksPerMinute MOD 60 ), 2, date, i ); date[ i ] := ":"; INC( i );
		Append( SIGNED32( aTicks DIV TicksPerSecond MOD 60 ), 2, date, i ); date[ i ] := ":"; INC( i );
		Append( SIGNED32( aTicks DIV TicksPerMillisecond MOD 1000 ), 3, date, i ); date[ i ] := "."; INC( i );
		Append( SIGNED32( aTicks MOD 10000 ), 4, date, i ); date[ i ] := 0X;
	END ToString;

	PROCEDURE ToStringReal*( aTicks: FLOAT64; VAR date: ARRAY OF CHAR );
	VAR i: SIZE;
	BEGIN
		i := 0;
		Append( SIGNED32( ENTIERH( aTicks / TicksPerHour + 0.5 ) MOD 24 ), 2, date, i ); date[ i ] := ":"; INC( i );
		Append( SIGNED32( ENTIERH( aTicks / TicksPerMinute + 0.5 ) MOD 60 ), 2, date, i ); date[ i ] := ":"; INC( i );
		Append( SIGNED32( ENTIERH( aTicks / TicksPerSecond + 0.5 ) MOD 60 ), 2, date, i ); date[ i ] := ":"; INC( i );
		Append( SIGNED32( ENTIERH( aTicks / TicksPerMillisecond + 0.5 ) MOD 1000 ), 3, date, i ); date[ i ] := "."; INC( i );
		Append( SIGNED32( ENTIERH( aTicks + 0.5 ) MOD 10000 ), 4, date, i ); date[ i ] := 0X;
	END ToStringReal;
END Stopwatch.

System.FreeDownTo Stopwatch~