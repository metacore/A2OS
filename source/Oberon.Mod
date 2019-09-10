MODULE Oberon IN A2; (** AUTHOR "negelef"; PURPOSE "Oberon command interpreter interface for A2"; *)

IMPORT Modules, Commands, Strings, OberonDisplay, Displays, Plugins ;

	PROCEDURE Call* (context: Commands.Context);
	VAR string, msg: ARRAY 64 OF CHAR; module, command: Modules.Name; res: INTEGER; procedure: PROCEDURE;
	BEGIN
		context.arg.SkipWhitespace; context.arg.String (string);
		Commands.Split (string, module, command, res, msg);
		IF res # Commands.Ok THEN
			context.error.String (msg); context.error.Ln; RETURN;
		END;
		Strings.Concat ("Oberon-", module, module);
		GETPROCEDURE (module, command, procedure);
		IF procedure = NIL THEN
			context.error.String ("Oberon command '"); context.error.String (string);
			context.error.String ("' not found"); context.error.Ln; RETURN;
		END;
		procedure;
	END Call;

	PROCEDURE Start*( context: Commands.Context );
	VAR disp: Plugins.Plugin;  proc: PROCEDURE;
	BEGIN
		proc := NIL;
		BEGIN {EXCLUSIVE}
			disp := Displays.registry.Get( "Oberon" );
			IF disp # NIL THEN
				context.error.String( "Oberon is already running, only one instance is allowed" ); context.error.Ln
			ELSE
				OberonDisplay.Install( context );
				GETPROCEDURE( "Oberon-System", "Init", proc );
				IF proc = NIL  THEN  context.error.String( "Oberon command 'System.Init' not found" ); context.error.Ln  END
			END;
		END;
		IF proc # NIL THEN  proc  END
	END Start;

END Oberon.

Oberon.Start Oberon 0x0 ~	(* Oberon full screen *)

Oberon.Start Oberon 900x700 10 20  ~

System.Free Oberon ~
