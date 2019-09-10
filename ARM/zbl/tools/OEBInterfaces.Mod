MODULE OEBInterfaces;
(**
	AUTHOR Timothée Martiel, 05/2016
	PURPOSE Abstract communication interfaces for the OEB host framework
*)

IMPORT Modules, Kernel, KernelLog, Plugins, Strings;

CONST
	(* Events *)
	EventEnter *			= 0;
	EventLeave *			= 1;

	(* Interface State *)
	StateInit *				= 0;	(** Interface ready to work *)
	StateActive *			= 1;	(** Interface running *)
	StateStopped *		= 2;	(** Interface paused *)
	StateDead *			= 3;	(** Interface down *)
	StateDie *				= 4;	(** Request interface shutdown *)

	(* Session State *)
	SessionOpen *			= 0;
	SessionWaiting *		= 1;
	SessionClosed *		= 2;
	SessionError *			= 3;

	CR *					= 0DX;
	LF *					= 0AX;

	(* Broadcast messages *)
	BcastHeader			= "INFO: *";	(** String prepended to all broadcast messages, identifying them *)
	BcastEntering			= "*Enter";	(** Message announcing availability of bootloader on that communication channel *)
	BcastLeaving			= "*Leave";	(** Message announcing that the bootloader leaves this channel *)

	CommandTimeout	= 15000;

	Module				= "OEB Interfaces";
	Trace *					= TRUE;

TYPE
	(** Interface: abstract communication layer over one or several physical channel. *)
	Interface * = OBJECT
	VAR
		name -,							(** Name of the interface instance *)
		type -: ARRAY 128 OF CHAR;		(** Description of the kind of interface *)
		state: SIGNED32;					(** State *)
		handle: Handler;					(** Event handler *)
		sessions -: Session;				(** List of sessions managed by this interface *)
		next *: Interface;

		(** Initializes an interface with a name and a description *)
		PROCEDURE & InitInterface * (CONST name, type: ARRAY 128 OF CHAR);
		BEGIN
			COPY(name, SELF.name);
			COPY(type, SELF.type)
		END InitInterface;

		(** Send a command to a session. The session must be managed by the interface. *)
		PROCEDURE Send * (session: Session; CONST cmd: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			HALT(506); (*! ABSTRACT *)
		END Send;

		(**
			Receive a message on a session. This is called by Update and returns a received message and
			the matching session. A new session must be created if msg is a broadcast enter message.
		*)
		PROCEDURE Receive * (VAR session: Session; VAR msg: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			HALT(506); (*! ABSTRACT *)
		END Receive;

		(** Set the event handler for the interface *)
		PROCEDURE SetHandler * (handler: Handler);
		BEGIN {EXCLUSIVE}
			handle := handler
		END SetHandler;

		(** Start listening on the interface *)
		PROCEDURE Start *;
		BEGIN {EXCLUSIVE}
			IF Trace THEN EnterTrace; KernelLog.String("starting"); ExitTrace END;
			IF state # StateDead THEN state := StateActive END
		END Start;

		(** Pauses listening on the interface *)
		PROCEDURE Stop *;
		BEGIN {EXCLUSIVE}
			IF Trace THEN EnterTrace; KernelLog.String("stopping"); ExitTrace END;
			IF state # StateDead THEN state := StateStopped END
		END Stop;

		(** Definitively stops an interface *)
		PROCEDURE Kill *;
		BEGIN {EXCLUSIVE}
			IF Trace THEN EnterTrace; KernelLog.String("killing"); ExitTrace END;
			state := StateDie;
			AWAIT(state = StateDead)
		END Kill;

		(** Returns the current state *)
		PROCEDURE State * (): SIGNED32;
		BEGIN {EXCLUSIVE}
			RETURN state
		END State;

		(**
			Execute a command 'cmd' for a session. Gives back a message in 'reply'. Returns TRUE if the command succeeded
			(including verifying reply), FALSE otherwise.

			Must not be called from the interface's process.
		*)
		PROCEDURE Command * (session: Session; CONST cmd: ARRAY OF CHAR; VAR reply: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			IF Trace THEN EnterTrace; KernelLog.String("Sending command: "); KernelLog.String(cmd); ExitTrace END;
			BEGIN {EXCLUSIVE}
				IF state # StateActive THEN
					reply := "ERR: interface stopped";
					RETURN FALSE
				END
			END;
			IF session.State() # SessionOpen THEN RETURN FALSE END;
			IF ~Send(session, cmd) THEN
				IF Trace THEN EnterTrace; KernelLog.String("Command '"); KernelLog.String(cmd); KernelLog.String("' failed"); ExitTrace END;
				session.Kill;
				RETURN FALSE
			END;

			Kernel.SetTimer(session.timer, CommandTimeout);
			session.Wait;
			session.AwaitState({SessionOpen, SessionError, SessionClosed});
			CASE session.State() OF
				 SessionOpen:
					(* We got the reply for the command *)
					COPY(session.msg, reply);
					RETURN Check(cmd, reply)
				|SessionClosed:
					(* Session was closed *)
					reply := 'Session closed';
					RETURN FALSE
				|SessionError:
					(* Error occured *)
					reply := 'Session error';
					RETURN FALSE
			END
		END Command;

		PROCEDURE Enumerate * (enumerator: Enumerator);
		VAR
			session: Session;
		BEGIN {EXCLUSIVE}
			session := sessions;
			WHILE session # NIL DO
				enumerator(session);
				session := session.next
			END
		END Enumerate;

		(** Dispatches messages received by the interface. *)
		PROCEDURE Update *;
		VAR
			s, session: Session;
			msg: ARRAY 128 OF CHAR;
		BEGIN
			IF ~Receive(session, msg) THEN Kill END;
			IF session = NIL THEN RETURN END;

			IF Strings.Match(BcastHeader, msg) THEN
				(* Broadcast message *)
				IF Strings.Match(BcastEntering, msg) THEN
					BEGIN {EXCLUSIVE}
						session.next := sessions;
						sessions := session
					END;
					session.Open;
					IF handle # NIL THEN handle(EventEnter, SELF, session) END
				ELSIF Strings.Match(BcastLeaving, msg) THEN
					BEGIN {EXCLUSIVE}
						IF session = sessions THEN
							sessions := sessions.next
						ELSIF sessions # NIL THEN
							s := sessions;
							WHILE s.next # session DO s := s.next END;
							s.next := session.next
						END
					END;
					session.Close;
					IF handle # NIL THEN handle(EventLeave, SELF, session) END
				END
			ELSIF session.State() = SessionWaiting THEN
				(* Session was waiting for message *)
				IF Kernel.Expired(session.timer) THEN
					session.Kill
				ELSE
					COPY(msg, session.msg);
					session.Open
				END
			ELSIF (session.State() = SessionOpen) & (msg = "OK: nop") THEN
				(* Received reply for new session *)
				BEGIN {EXCLUSIVE}
					session.next := sessions;
					sessions := session
				END;
				session.Open;
				IF handle # NIL THEN handle(EventEnter, SELF, session) END
			ELSE
				(* Session was not waiting for message *)
				Kill
			END
		END Update;

		PROCEDURE Check (CONST cmd, reply: ARRAY OF CHAR): BOOLEAN;
		VAR
			expected: ARRAY 128 OF CHAR;
		BEGIN
			expected := "OK: ";
			Strings.Append(expected, cmd);
			RETURN ((cmd = "netinfo") & Strings.Match("OK:*", reply)) OR (Strings.Match(expected, reply))
		END Check;

		PROCEDURE EnterTrace *;
		BEGIN
			IF Trace THEN
				KernelLog.Enter;
				KernelLog.String(Module);
				KernelLog.String(" ");
				KernelLog.String(name);
				KernelLog.String(" ");
				KernelLog.String("(");
				KernelLog.String(type);
				KernelLog.String(")");
				KernelLog.String(": ")
			END
		END EnterTrace;

		PROCEDURE ExitTrace *;
		BEGIN
			KernelLog.Exit
		END ExitTrace;

	BEGIN {ACTIVE}
		BEGIN {EXCLUSIVE} AWAIT(state # StateInit) END;
		LOOP
			BEGIN {EXCLUSIVE}
				AWAIT((state = StateActive) OR (state = StateDie));
				IF state = StateDie THEN EXIT END
			END;
			Update
		END;
		BEGIN {EXCLUSIVE}
			state := StateDead
		END;
	FINALLY
		BEGIN {EXCLUSIVE}
			state := StateDead
		END
	END Interface;

	(** Bootloader instance to deploy on *)
	Session * = OBJECT
	VAR
		msg: ARRAY 1024 OF CHAR;
		name -: ARRAY 128 OF CHAR;
		timer: Kernel.MilliTimer;
		state: SIGNED32;
		guid *: SIGNED32;
		next -: Session;

		PROCEDURE & InitSession * (CONST name: ARRAY OF CHAR);
		BEGIN
			COPY(name, SELF.name)
		END InitSession;

		PROCEDURE State * (): SIGNED32;
		BEGIN {EXCLUSIVE}
			RETURN state
		END State;

		PROCEDURE AwaitState * (state: SET);
		BEGIN {EXCLUSIVE}
			AWAIT(SELF.state IN state)
		END AwaitState;

		PROCEDURE Open *;
		BEGIN {EXCLUSIVE}
			IF state # SessionError THEN state := SessionOpen END
		END Open;

		PROCEDURE Wait *;
		BEGIN {EXCLUSIVE}
			IF state = SessionOpen THEN state := SessionWaiting END
		END Wait;

		PROCEDURE Close *;
		BEGIN {EXCLUSIVE}
			IF state # SessionError THEN state := SessionClosed END
		END Close;

		PROCEDURE Kill *;
		BEGIN {EXCLUSIVE}
			state := SessionError
		END Kill;
	END Session;

	Factory * = OBJECT (Plugins.Plugin)
		PROCEDURE NewInterface * (CONST param: ARRAY OF CHAR): Interface;
		BEGIN
			HALT(555) (* ABSTRACT *)
		END NewInterface;
	END Factory;

	(** Session start and stop event handler *)
	Handler * = PROCEDURE {DELEGATE} (event: SIGNED32; interface: Interface; session: Session);

	Enumerator * = PROCEDURE {DELEGATE} (session: Session);

VAR
	factories: Plugins.Registry;

	PROCEDURE NewInterface * (CONST type, param: ARRAY OF CHAR): Interface;
	VAR
		factory: Factory;
		m: Modules.Module;
		name, msg: ARRAY 128 OF CHAR;
		res: SIGNED32;
	BEGIN
		name := "OEB";
		Strings.Append(name, type);
		Strings.Append(name, "Interfaces");
		m := Modules.ThisModule(name, res, msg);
		IF m = NIL THEN
			COPY(type, name);
			Strings.Append(name, "Interfaces");
			m := Modules.ThisModule(name, res, msg)
		END;

		factory := factories.Get(type)(Factory);
		RETURN factory.NewInterface(param)
	END NewInterface;

	PROCEDURE Register * (CONST type: ARRAY OF CHAR; factory: Factory);
	VAR
		ignore: SIGNED32;
	BEGIN
		factory.SetName(type);
		factories.Add(factory, ignore)
	END Register;

	PROCEDURE Unregister * (factory: Factory);
	BEGIN
		factories.Remove(factory)
	END Unregister;

	PROCEDURE Cleanup;
	BEGIN
		Plugins.main.Remove(factories)
	END Cleanup;

BEGIN
	NEW(factories, "OEB Itf", "OEB Interface Factories");
	Modules.InstallTermHandler(Cleanup)
END OEBInterfaces.
