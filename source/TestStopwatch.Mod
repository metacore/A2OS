MODULE TestStopwath; (** AUTHOR ""; PURPOSE ""; *)

IMPORT
	Commands, Kernel, Strings, Stopwatch;

TYPE
	R = RECORD
		PROCEDURE P(); END P;
	END;

PROCEDURE Do*(context: Commands.Context);
VAR buffer: ARRAY 256 OF CHAR;
VAR i64: Stopwatch.Counter;
VAR r: R;
BEGIN
	VAR timer := NEW Kernel.Timer( );
	VAR stopWatch := NEW Stopwatch.T( );
	stopWatch.Start( );
		timer.Sleep( 100 );
	stopWatch.Stop( );
	VAR timerElapsed := stopWatch.Elapsed( );

	Stopwatch.ToString( timerElapsed, buffer );
	context.out.String( "timer elapsed: " );
	context.out.String( buffer );
	context.out.Ln;

	stopWatch.Restart( );

		VAR stopWatchIntToStr := stopWatch.StartNew( );
			Strings.IntToStr( MAX( SIGNED64 ), buffer );
		stopWatchIntToStr.Stop( );

		VAR stopWatchStrToHInt := stopWatch.StartNew( );
			Strings.StrToHInt( buffer, i64 );
		stopWatchStrToHInt.Stop( );

		VAR stopWatchStartNew := stopWatch.StartNew( );
			IGNORE stopWatchStartNew .StartNew( );
		stopWatchStartNew.Stop( );

		VAR stopWatchMethodCall := stopWatch.StartNew( );
			r.P( );
		stopWatchMethodCall.Stop;

	stopWatch.Stop();

	Stopwatch.ToString( stopWatch.Elapsed( ), buffer );
	context.out.String("all elapsed: " );
	context.out.String( buffer );
	context.out.Ln;

	Stopwatch.ToString( stopWatchIntToStr.Elapsed( ), buffer );
	context.out.String("IntToStr elapsed: " );
	context.out.String( buffer );
	context.out.Ln;

	Stopwatch.ToString( stopWatchStrToHInt.Elapsed( ), buffer );
	context.out.String("StrToHInt elapsed: " );
	context.out.String( buffer );
	context.out.Ln;

	Stopwatch.ToString( stopWatchStartNew.Elapsed( ), buffer );
	context.out.String("StartNew elapsed: " );
	context.out.String( buffer );
	context.out.Ln;

	Stopwatch.ToString( stopWatchMethodCall.Elapsed( ), buffer );
	context.out.String("method call elapsed: " );
	context.out.String( buffer );
	context.out.Ln;
END Do;

END TestStopwath.Do~


System.FreeDownTo TestStopwath~