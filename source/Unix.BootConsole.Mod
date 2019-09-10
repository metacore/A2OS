MODULE BootConsole;	(** AUTHOR "G.F."; PURPOSE "Boot console"; *)

IMPORT S := SYSTEM, Trace, Glue, Unix, Machine, Modules, Objects, Commands, KernelLog;

TYPE
	Module = Modules.Module;
	CommandProc = PROCEDURE;

	CommandThread = OBJECT
	VAR
		mod, cmd: Modules.Name;

		PROCEDURE &Init( CONST modName, cmdName: Modules.Name );
		BEGIN
			mod := modName;  cmd := cmdName
		END Init;

	BEGIN {ACTIVE}
		Execute( mod, cmd );
		Modules.Shutdown( Modules.Reboot )
	END CommandThread;


VAR
	appl: CommandThread;

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


	PROCEDURE CommandError( CONST cmd, msg: ARRAY OF CHAR );
	BEGIN
		Trace.String( "bad command line parameter: -x " );  Trace.String( cmd );
		Trace.String( ": " );  Trace.String( msg );  Trace.Ln;
	END CommandError;


	PROCEDURE TryCommand( ): BOOLEAN;
	VAR
		cmd: ARRAY 128 OF CHAR; ci: SIGNED16;
		modName, cmdName: Modules.Name;

		PROCEDURE IsCharacter( c: CHAR ): BOOLEAN;
		BEGIN  RETURN (('a' <= c) & (c <= 'z')) OR (( 'A' <= c) & (c <= 'Z'))
		END IsCharacter;

		PROCEDURE IsCharOrDigit( c: CHAR ): BOOLEAN;
		BEGIN  RETURN IsCharacter( c ) OR (("0" <= c) & (c <= "9"))
		END IsCharOrDigit;

		PROCEDURE GetName( VAR name: ARRAY OF CHAR ): BOOLEAN;
		VAR j: SIGNED32;  c: CHAR;
		BEGIN
			j := -1;
			IF IsCharacter( cmd[ci] ) THEN
				REPEAT c := cmd[ci];  INC( ci );  INC( j );  name[j] := c  UNTIL ~IsCharOrDigit( c ) OR (j = 31);
				IF c = '.' THEN  name[j] := 0X
				ELSIF c # 0X THEN
					IF IsCharOrDigit( c ) THEN  CommandError( cmd, "name too long" )
					ELSE  CommandError( cmd, "invalid name" )
					END;
					RETURN FALSE
				END;
				RETURN TRUE
			ELSE
				CommandError( cmd, "name must start with a character" );
				RETURN FALSE
			END
		END GetName;

	BEGIN
		Unix.GetArgval( "-x", cmd );
		IF cmd # "" THEN
			ci := 0;
			IF GetName( modName ) & GetName( cmdName ) THEN
				IF Glue.debug # {} THEN
					Trace.String( "Starting " );
					Trace.String( modName );  Trace.Char( "." );  Trace.String( cmdName );
					Trace.Ln
				END;
				NEW( appl, modName, cmdName );
				RETURN TRUE
			ELSE
				(* invalid command string*)
				Unix.exit( 1 )
			END
		END;
		RETURN FALSE
	END TryCommand;



	PROCEDURE InitializeCoreModules;
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
	END InitializeCoreModules;


	PROCEDURE StartSystem;
	BEGIN
		IF ~TryCommand()  THEN
			Machine.VerboseLog( );
			KernelLog.String( Machine.version );  KernelLog.Ln;
			(* normal system start *)
			LoadModule( "Clock" );
			Execute( "XDisplay",  "Install" );
			Execute( "KbdMouse",  "Init" );

			Command( "WindowManager.Install" );
			Command( "DisplayRefresher.Install" );

			Command( "Autostart.Run" );
		END
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
	InitializeCoreModules;
	InitSignalHandling;
	StartSystem;
	#IF ~COOP THEN
		Objects.GCLoop;
	#END
END BootConsole.


