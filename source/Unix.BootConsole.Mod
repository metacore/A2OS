MODULE BootConsole;	(** AUTHOR "G.F."; PURPOSE "Boot console"; *)

IMPORT S := SYSTEM, Trace, Unix, Machine, Modules, Objects, Commands, KernelLog;

TYPE
	Module = Modules.Module;
	CommandProc = PROCEDURE;



	PROCEDURE LoadModule( CONST name: Modules.Name );
	VAR
		m: Module;  res: INTEGER;  msg: ARRAY 256 OF CHAR;
	BEGIN
		m := Modules.ThisModule( name, res, msg );
		IF m = NIL THEN
			Trace.String( "could not load module " );  Trace.String( name );  Trace.Ln
		END
	END LoadModule;
	

	PROCEDURE Command( CONST cmd: Modules.Name );
	VAR
		res: INTEGER;
		s: ARRAY 256 OF CHAR;
	BEGIN
		Commands.Call( cmd, {}, res, s );
		IF res # 0 THEN  Trace.String( s ); Trace.Ln  END
	END Command;


	(** Return the named command. *)
	PROCEDURE ThisCommand( m: Module;  CONST name: Modules.Name ): CommandProc;
	VAR cmd: Modules.Command; i: SIGNED32;  found: BOOLEAN;
	BEGIN
		i := 0;  found := FALSE;
		WHILE ~found & (i # LEN( m.command^ )) DO
			IF m.command[i].name = name THEN  found := TRUE;  cmd := m.command[i]  ELSE  INC( i )  END
		END;
		IF (cmd.entryAdr # 0) & (cmd.argTdAdr = 0) & (cmd.retTdAdr = 0) THEN
			RETURN S.VAL( CommandProc, cmd.entryAdr )
		ELSE
			RETURN NIL
		END
	END ThisCommand;
	

	PROCEDURE Execute( CONST modName, procName: Modules.Name );
	VAR m: Module;  cmd: PROCEDURE;  res: INTEGER;
		msg: ARRAY 256 OF CHAR;
	BEGIN
		m := Modules.ThisModule( modName, res, msg );
		IF m # NIL THEN
			cmd := ThisCommand( m, procName );
			IF cmd # NIL THEN  cmd
			ELSE
				Trace.String( "BootConsole.Execute:  module '" );  Trace.String( modName );
				Trace.String( "' has no command '" );  Trace.String( procName );  Trace.Char( "'" );
				Trace.Ln;
			END
		ELSE
			Trace.String( "BootConsole.Execute:  could not load module " );  Trace.String( modName );
			Trace.Ln;
			Trace.String( msg );  Trace.Ln
		END
	END Execute;



(*	PROCEDURE InitializeCoreModules;
	TYPE Body = PROCEDURE;
	VAR m: Modules.Module;  body: Body;  trace: BOOLEAN;
	BEGIN
		m := Modules.root;  trace :=  Glue.debug # {};
		LOOP
			IF m.name = "BootConsole" THEN  EXIT   END;   (* initialize modules belonging to bootfile only *)
			IF trace THEN
				Trace.String( "#### Initializing " );  Trace.String( m.name );
				Trace.String( "     code: [" ); Trace.Hex( ADDRESSOF( m.code[0] ), -8 );
				Trace.String( ".." ); Trace.Hex( ADDRESSOF( m.code[0] ) + LEN( m.code^ ), -8 );
				Trace.Char( ']' ); Trace.Ln
			END;
			body := S.VAL( Body, ADDRESSOF( m.code[0] ) );
			body;
			m := m.next
		END
	END InitializeCoreModules;	*)


	PROCEDURE StartSystem;
	BEGIN
		KernelLog.String( Machine.version );  KernelLog.Ln;
		LoadModule( "Clock" );
		Execute( "XDisplay",  "Install" );
		Execute( "KbdMouse",  "Init" );

		Command( "WindowManager.Install" );
		Command( "DisplayRefresher.Install" );

		Command( "Autostart.Run" );
	END StartSystem;

	PROCEDURE InitSignalHandling;
	BEGIN
		Unix.HandleSignal( Unix.SIGHUP );
		Unix.HandleSignal( Unix.SIGINT );
		Unix.HandleSignal( Unix.SIGQUIT );
		Unix.HandleSignal( Unix.SIGILL );
		Unix.HandleSignal( Unix.SIGTRAP );

		Unix.HandleSignal( Unix.SIGABRT );
		Unix.HandleSignal( Unix.SIGBUS );
		Unix.HandleSignal( Unix.SIGFPE );
		Unix.HandleSignal( Unix.SIGBUS );
		Unix.HandleSignal( Unix.SIGPIPE );
		Unix.HandleSignal( Unix.SIGALRM );
		Unix.HandleSignal( Unix.SIGTERM );
	END InitSignalHandling;

BEGIN
	Machine.VerboseLog;
(*	InitializeCoreModules;	*)
	
	(* make current Frame the last one in FindRoots() *)
	S.PUT( S.GetFramePointer(), ADDRESS( 0 ) );
	
	InitSignalHandling;
	StartSystem;
	#IF ~COOP THEN
		(*	Keep main thread running.
			If the thread is blocked by a mutex (Objects.MainThreadSleep)
			the signals SIGHUP, SIGINT and SIGQUIT don't branch into SignalHandler
			but terminate A2 (at least in Solaris).	*)
		LOOP  Objects.Sleep( 100 ) END;
	#END;
END BootConsole.


