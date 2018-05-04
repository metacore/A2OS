MODULE OEBLoopbackInterfaces;
(**
	AUTHOR Timothée Martiel, 05/2016
	PURPOSE Loopback interface for the OEB Host framework
*)

IMPORT
	Modules, Kernel, KernelLog, Strings,
	OEBInterfaces;

CONST
	Name	= "Loopback";
	Type	= "Loopback Interface";

TYPE
	Interface * = OBJECT (OEBInterfaces.Interface)
	VAR
		cmd: ARRAY 128 OF CHAR;
		timer: Kernel.Timer;
		guid: LONGINT;
		connected, doReply: BOOLEAN;

		PROCEDURE & Init * (guid: LONGINT);
		VAR
			name: ARRAY 128 OF CHAR;
		BEGIN
			name := Name;
			Strings.AppendInt(name, nextId);
			INC(nextId);
			InitInterface(name, Type);
			SELF.guid := guid;
			NEW(timer)
		END Init;

		PROCEDURE Send * (session: OEBInterfaces.Session; CONST cmd: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			IF session # sessions THEN RETURN FALSE
			ELSIF session = NIL THEN RETURN FALSE
			ELSIF doReply THEN RETURN FALSE
			END;
			BEGIN {EXCLUSIVE}
				COPY(cmd, SELF.cmd);
				doReply := TRUE
			END;
			RETURN TRUE
		END Send;

		PROCEDURE Receive * (VAR session: OEBInterfaces.Session; VAR msg: ARRAY OF CHAR): BOOLEAN;
		VAR
			reply: BOOLEAN;
		BEGIN
			BEGIN {EXCLUSIVE}
				reply := doReply
			END;
			IF connected & (sessions = NIL) THEN
				NEW(session, "Loopback");
				session.guid := guid;
				msg := "INFO: Enter"
			ELSIF ~connected & (sessions # NIL) THEN
				session := sessions;
				msg := "INFO: Leave";
			ELSIF reply THEN
				timer.Sleep(1000);
				BEGIN {EXCLUSIVE}
					IF cmd = "fail" THEN
						msg := "ERR: fail"
					ELSE
						msg := "OK: ";
						Strings.Append(msg, cmd);
						doReply := FALSE
					END
				END;
				session := sessions
			END;
			RETURN TRUE
		END Receive;

		PROCEDURE Connect *;
		BEGIN {EXCLUSIVE}
			IF OEBInterfaces.Trace THEN
				KernelLog.Enter;
				KernelLog.String("Connecting...");
				KernelLog.Exit
			END;
			connected := TRUE
		END Connect;

		PROCEDURE Disconnect *;
		BEGIN {EXCLUSIVE}
			IF OEBInterfaces.Trace THEN
				KernelLog.Enter;
				KernelLog.String("Disconnecting...");
				KernelLog.Exit
			END;
			connected := FALSE
		END Disconnect;

		PROCEDURE Connected * (): BOOLEAN;
		BEGIN {EXCLUSIVE}
			RETURN connected
		END Connected;
	END Interface;

	Factory = OBJECT (OEBInterfaces.Factory)
		PROCEDURE NewInterface (CONST param: ARRAY OF CHAR): OEBInterfaces.Interface;
		VAR
			itf: Interface;
			guid: LONGINT;
		BEGIN
			Strings.StrToInt(param, guid);
			NEW(itf, guid);
			RETURN itf
		END NewInterface;
	END Factory;

VAR
	factory: Factory;
	nextId: LONGINT;

	PROCEDURE Cleanup;
	BEGIN
		OEBInterfaces.Unregister(factory)
	END Cleanup;

BEGIN
	NEW(factory);
	OEBInterfaces.Register("Loopback", factory);
	Modules.InstallTermHandler(Cleanup)
END OEBLoopbackInterfaces.
