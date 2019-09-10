MODULE OEBAutoServers;
(**
	AUTHOR Timothée Martiel, 05/2016
	PURPOSE Automatic deployment server
*)

IMPORT
	Modules, KernelLog, Strings, Streams,
	OEBInterfaces, OEBServers;

CONST
	Name			= "Auto";
	Type			= "Automatic Server";

	StateStopped	= 0;
	StateActive		= 1;
	StateKilled		= 3;

	MaxEvents		= 128;

	Trace			= OEBInterfaces.Trace;

TYPE
	Event * = RECORD
		event: SIGNED32;
		session: OEBInterfaces.Session;
		interface: OEBInterfaces.Interface;
	END;

	Plan = POINTER TO RECORD
		guid: SIGNED32;
		cmds: Command;
		next: Plan;
	END;

	Command = POINTER TO RECORD
		str: ARRAY 1024 OF CHAR;
		next: Command;
	END;

	SessionHandler = OBJECT
	VAR
		server: Server;
		event: Event;
		handle, kill: BOOLEAN;

		PROCEDURE & Init (server: Server);
		BEGIN
			SELF.server := server
		END Init;

		PROCEDURE Handle (CONST event: Event);
		BEGIN {EXCLUSIVE}
			ASSERT(~handle);
			SELF.event := event;
			handle := TRUE
		END Handle;

		PROCEDURE Ready (): BOOLEAN;
		BEGIN {EXCLUSIVE}
			RETURN ~handle
		END Ready;

		PROCEDURE Kill;
		BEGIN {EXCLUSIVE}
			kill := TRUE
		END Kill;

		(** Actual event handler *)
		PROCEDURE DoHandle;
		VAR
			plan: Plan;
		BEGIN
			IF event.event = OEBInterfaces.EventEnter THEN
				IF Trace THEN
					server.EnterTrace;
					KernelLog.String("Accepted new session '");
					KernelLog.String(event.interface.name);
					KernelLog.String("/");
					KernelLog.String(event.session.name);
					KernelLog.String("'");
					server.ExitTrace
				END;
				plan := FindPlan(event.session.guid);
				IF plan # NIL THEN ExecuteCommands(event.interface, event.session, plan) END
			ELSIF Trace THEN
				server.EnterTrace;
				KernelLog.String("Session '");
				KernelLog.String(event.interface.name);
				KernelLog.String("/");
				KernelLog.String(event.session.name);
				KernelLog.String("'");
				server.ExitTrace
			END;
			BEGIN {EXCLUSIVE} handle := FALSE END;
		END DoHandle;

		PROCEDURE FindPlan (guid: SIGNED32): Plan;
		VAR
			plan: Plan;
		BEGIN
			plan := server.plans;
			WHILE (plan # NIL) & (plan.guid # guid) DO plan := plan.next END;
			TRACE(plan, server.default);
			IF plan = NIL THEN RETURN server.default END;
			RETURN plan
		END FindPlan;

		PROCEDURE ExecuteCommands (interface: OEBInterfaces.Interface; session: OEBInterfaces.Session; plan: Plan);
		VAR
			cmd: Command;
			reply: ARRAY 128 OF CHAR;
		BEGIN
			cmd := plan.cmds;
			WHILE (cmd # NIL) & interface.Command(session, cmd.str, reply) DO
				IF Trace THEN
					server.EnterTrace;
					KernelLog.String(event.interface.name);
					KernelLog.String("/");
					KernelLog.String(event.session.name);
					KernelLog.String(": CMD ");
					KernelLog.String(cmd.str);
					KernelLog.String(" => REPLY ");
					KernelLog.String(reply);
					server.ExitTrace
				END;
				cmd := cmd.next
			END;
			IF cmd # NIL THEN
				IF Trace THEN
					server.EnterTrace;
					KernelLog.String(event.interface.name);
					KernelLog.String("/");
					KernelLog.String(event.session.name);
					KernelLog.String(": ");
					KernelLog.String(reply);
					KernelLog.String(" IN COMMAND ");
					KernelLog.String(cmd.str);
					server.ExitTrace
				END;
				event.session.Close;
			END
		END ExecuteCommands;

	BEGIN {ACTIVE}
		LOOP
			BEGIN {EXCLUSIVE} AWAIT(handle OR kill) END;
			IF (server.State() = StateKilled) OR kill THEN EXIT END;
			DoHandle
		END;
	END SessionHandler;

	(**
		Automatic server.
		An automatic server is initialized with a set of commands.
		For each new session, the bootloader immediately executes the commands in order
		and stops at the end or when a command fails.
	*)
	Server * = OBJECT (OEBServers.Server)
	VAR
		plans: Plan;										(** plan for a specific GUID *)
		default: Plan;										(** default plan *)
		state: SIGNED32;									(** server state *)
		handlers: ARRAY MaxEvents OF SessionHandler;	(** Pool of handlers *)

		(**
			Initializes a server with the commands to execute. In 'program', each command is separated by a newline character.
			Program can describe several plans:

				program := {guid_plan} [plan].
				gui_plan := 'GUID' guid 'PLAN' {command}.
				plan := 'PLAN' {command}.
		*)
		PROCEDURE & Init * (reader: Streams.Reader);
		VAR
			name: ARRAY 128 OF CHAR;
			i: SIGNED32;
			plan: Plan;
		BEGIN
			name := Name;
			Strings.AppendInt(name, next);
			INC(next);
			InitServer(name, Type);

			LOOP
				plan := ParsePlan(reader);
				IF plan = NIL THEN EXIT END;

				IF plan.guid = 0 THEN
					IF Trace THEN
						EnterTrace;
						KernelLog.String('new default plan');
						ExitTrace
					END;
					default := plan
				ELSE
					IF Trace THEN
						EnterTrace;
						KernelLog.String('new plan for GUID ');
						KernelLog.Int(plan.guid, 0);
						ExitTrace
					END;
					plan.next := plans;
					plans := plan
				END
			END;
			FOR i := 0 TO MaxEvents - 1 DO
				NEW(handlers[i], SELF)
			END
		END Init;

		(** Event handling: notifies the server process *)
		PROCEDURE Handle * (event: SIGNED32; interface: OEBInterfaces.Interface; session: OEBInterfaces.Session);
		VAR
			e: Event;
			i: SIGNED32;
		BEGIN {EXCLUSIVE}
			e.event := event;
			e.session := session;
			e.interface := interface;
			WHILE (i < MaxEvents) & ~handlers[i].Ready() DO INC(i) END;
			ASSERT(i < MaxEvents);
			handlers[i].Handle(e)
		END Handle;

		PROCEDURE Start *;
		BEGIN
			BEGIN {EXCLUSIVE}
				state := StateActive
			END;
			Start^
		END Start;

		PROCEDURE Stop *;
		BEGIN
			BEGIN {EXCLUSIVE}
				state := StateStopped
			END;
			Stop^;
		END Stop;

		PROCEDURE Kill *;
		VAR
			i: SIGNED32;
		BEGIN
			BEGIN {EXCLUSIVE}
				state := StateKilled
			END;
			FOR i := 0 TO MaxEvents - 1 DO handlers[i].Kill END;
			Kill^;
			EnterTrace;
			KernelLog.String("stopped");
			ExitTrace
		END Kill;

		PROCEDURE State * (): SIGNED32;
		BEGIN {EXCLUSIVE}
			RETURN state
		END State;

	END Server;

	Factory = OBJECT (OEBServers.Factory)
		PROCEDURE NewServer (CONST param: ARRAY OF CHAR): OEBServers.Server;
		VAR
			server: Server;
			reader: Streams.StringReader;
		BEGIN
			NEW(reader, LEN(param));
			reader.Set(param);
			NEW(server, reader);
			RETURN server
		END NewServer;
	END Factory;

VAR
	factory: Factory;
	next: SIGNED32;

	PROCEDURE ParsePlan (reader: Streams.Reader): Plan;
	VAR
		plan: Plan;
		token: ARRAY 1024 OF CHAR;
		cmd: Command;
		guid: SIGNED32;
	BEGIN
		IF ~reader.GetString(token) THEN RETURN NIL END;
		TRACE(token);
		IF token = "GUID" THEN
			(* GUID-specific token *)
			IF ~reader.GetInteger(guid, TRUE) THEN RETURN NIL END;
			IF ~reader.GetString(token) THEN RETURN NIL END;
		END;
		TRACE(token);
		IF token # "PLAN" THEN RETURN NIL END;
		NEW(plan);
		plan.guid := guid;

		LOOP
			reader.SkipWhitespace;
			reader.Ln(token);
			TRACE(token);
			Strings.TrimWS(token);
			TRACE(token);
			IF token = "END" THEN EXIT
			ELSIF token = "" THEN RETURN NIL END;
			IF cmd = NIL THEN
				NEW(cmd);
				plan.cmds := cmd
			ELSE
				NEW(cmd.next);
				cmd := cmd.next
			END;
			COPY(token, cmd.str)
		END;
		RETURN plan
	END ParsePlan;

	PROCEDURE Cleanup;
	BEGIN
		OEBServers.Unregister(factory)
	END Cleanup;

BEGIN
	NEW(factory);
	OEBServers.Register("Auto", factory);
	Modules.InstallTermHandler(Cleanup)
END OEBAutoServers.
