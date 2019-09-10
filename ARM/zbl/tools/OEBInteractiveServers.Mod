MODULE OEBInteractiveServers;
(**
	AUTHOR Timothée Martiel, 05/2016
	PURPOSE Interactive deployment server
*)

IMPORT
	Modules, KernelLog, Strings, FoxBasic,
	OEBInterfaces, OEBServers;

CONST
	Ok *					= 0;
	SessionNotFound *	= 1;
	InvalidSessionState *	= 2;
	CommandError *		= 3;

	Name					= "Interactive";
	Type					= "Interactive Server";

TYPE
	Server * = OBJECT (OEBServers.Server)
	VAR
		event: SIGNED32;
		interface: OEBInterfaces.Interface;
		session: OEBInterfaces.Session;
		sessions: FoxBasic.List;
		(*out, error: Streams.Writer;*)
		handle: BOOLEAN;

		PROCEDURE & Init * (*(out, error: Streams.Writer)*);
		VAR
			name: ARRAY 128 OF CHAR;
		BEGIN
			name := Name;
			Strings.AppendInt(name, nextId);
			INC(nextId);
			InitServer(name, Type);
			(*SELF.out := out;
			SELF.error := error*)
			NEW(sessions, 0)
		END Init;

		PROCEDURE Handle * (event: SIGNED32; interface: OEBInterfaces.Interface; session: OEBInterfaces.Session);
		BEGIN {EXCLUSIVE}
			TRACE('RECEIVED', event, interface.name, session.name);
			AWAIT(~handle);
			SELF.event := event;
			SELF.interface := interface;
			SELF.session := session;
			handle := TRUE
		END Handle;

		PROCEDURE DoHandle;
		VAR
			reply: ARRAY 128 OF CHAR;
			info: SessionInfo;
			i: SIGNED32;
		BEGIN
			TRACE(event, session.name, interface.name);
			IF event = OEBInterfaces.EventEnter THEN
				IF sessions.Length() > 0 THEN
					EnterTrace;
					KernelLog.String("Closing previous session");
					ExitTrace;
					sessions.Get(0)(SessionInfo).session.Close;
					sessions.Clear();
				END;
				IF ~interface.Command(session, "nop", reply) THEN
					EnterTrace;
					KernelLog.String("Could not get handle on session ");
					KernelLog.String(interface.name);
					KernelLog.String("/");
					KernelLog.String(session.name);
					KernelLog.String(": ");
					KernelLog.String(reply);
					ExitTrace;
					session.Close;
					BEGIN {EXCLUSIVE}
						handle := FALSE
					END;
					RETURN
				END;
				NEW(info);
				info.session := session;
				info.interface := interface;
				sessions.Add(info);
				EnterTrace;
				KernelLog.String("New session: ");
				KernelLog.String(interface.name);
				KernelLog.String("/");
				KernelLog.String(session.name);
				KernelLog.String(" as ");
				KernelLog.Int(sessions.IndexOf(info), 0);
				ExitTrace
			ELSE
				FOR i := 0 TO sessions.Length() - 1 DO
					info := sessions.Get(i)(SessionInfo);
					IF info.session = session THEN
						sessions.Remove(info);
						KernelLog.Enter;
						KernelLog.String("Removed session: ");
						KernelLog.Int(i, 0);
						KernelLog.String("(");
						KernelLog.String(interface.name);
						KernelLog.String("/");
						KernelLog.String(session.name);
						KernelLog.String(")");
						KernelLog.Exit
					END
				END
			END;
			BEGIN {EXCLUSIVE}
				handle := FALSE
			END
		END DoHandle;

		PROCEDURE GetSession * (id: SIGNED32): OEBInterfaces.Session;
		VAR
			info: SessionInfo;
		BEGIN {EXCLUSIVE}
			info := sessions.Get(id)(SessionInfo);
			IF info = NIL THEN RETURN NIL END;
			RETURN info.session
		END GetSession;

		PROCEDURE GetInterface * (id: SIGNED32): OEBInterfaces.Interface;
		VAR
			info: SessionInfo;
		BEGIN {EXCLUSIVE}
			info := sessions.Get(id)(SessionInfo);
			IF info = NIL THEN RETURN NIL END;
			RETURN info.interface
		END GetInterface;

		PROCEDURE ExecuteCommand * (id: SIGNED32; CONST cmd: ARRAY OF CHAR; VAR msg: ARRAY OF CHAR): SIGNED32;
		VAR
			interface: OEBInterfaces.Interface;
			session: OEBInterfaces.Session;
		BEGIN
			session := GetSession(id);
			TRACE(session, session.State());
			IF session = NIL THEN RETURN SessionNotFound END;
			IF session.State() IN {OEBInterfaces.SessionClosed, OEBInterfaces.SessionError} THEN
				RETURN InvalidSessionState
			END;

			interface := GetInterface(id);
			TRACE(interface);
			ASSERT(interface # NIL);
			IF interface.Command(session, cmd, msg) THEN
				TRACE(msg);
				RETURN Ok
			ELSE
				TRACE(msg);
				RETURN CommandError
			END
		END ExecuteCommand;

	BEGIN {ACTIVE}
		LOOP
			BEGIN {EXCLUSIVE} AWAIT(handle) END;
			DoHandle
		END
	END Server;

	SessionInfo = POINTER TO RECORD
		session: OEBInterfaces.Session;
		interface: OEBInterfaces.Interface;
	END;

	Factory = OBJECT (OEBServers.Factory)
		PROCEDURE NewServer (CONST param: ARRAY OF CHAR): OEBServers.Server;
		VAR
			server: Server;
		BEGIN
			NEW(server);
			RETURN server
		END NewServer;
	END Factory;

VAR
	factory: Factory;
	nextId: SIGNED32;

	PROCEDURE Cleanup;
	BEGIN
		OEBServers.Unregister(factory)
	END Cleanup;

BEGIN
	NEW(factory);
	OEBServers.Register("Interactive", factory);
	Modules.InstallTermHandler(Cleanup)
END OEBInteractiveServers.
