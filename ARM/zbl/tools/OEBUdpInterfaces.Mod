MODULE OEBUdpInterfaces; (** AUTHOR ""; PURPOSE ""; *)

IMPORT
	Modules, KernelLog, IP, UDP, Strings, FoxBasic,
	OEBInterfaces;

CONST
	Port = 5999;
	NopCmd = "nop";

TYPE
	Interface * = OBJECT (OEBInterfaces.Interface)
	VAR
		socket: UDP.Socket;

		PROCEDURE & Init * (CONST param: ARRAY OF CHAR);
		VAR
			res: LONGINT;
		BEGIN
			InitInterface("UDP0", "UDP interface");
			NEW(socket, Port, res);
			IF res = UDP.Ok THEN
				BEGIN{EXCLUSIVE}
					sockets.Add(socket);
				END;
			ELSE
				socket := NIL;
				KernelLog.Enter;
				KernelLog.String("Error opening UDP socket: ");
				KernelLog.Int(res, 0);
				KernelLog.Exit
			END;
		END Init;

		PROCEDURE Send * (session: OEBInterfaces.Session; CONST cmd: ARRAY OF CHAR): BOOLEAN;
		VAR
			c: ARRAY 128 OF CHAR;
			res: LONGINT;
		BEGIN
			COPY(cmd, c);
			Strings.AppendChar(c, OEBInterfaces.CR);
			Strings.AppendChar(c, OEBInterfaces.LF);
			socket.Send(session(Session).address, Port, c, 0, Strings.Length(c), res);
			RETURN res = UDP.Ok
		END Send;

		PROCEDURE Receive * (VAR session: OEBInterfaces.Session; VAR msg: ARRAY OF CHAR): BOOLEAN;
		VAR
			ip: IP.Adr;
			i, len, port, res: LONGINT;
			new: Session;
			adr: ARRAY 128 OF CHAR;
		BEGIN
			socket.Receive(msg, 0, LEN(msg) - 1, -1, ip, port, len, res);
			IF port # Port THEN msg := ''; RETURN TRUE END;
			IF res = UDP.BufferOverflow THEN RETURN FALSE END;
			IF len = 0 THEN RETURN TRUE END;
			WHILE (i < len) & (msg[i] # OEBInterfaces.CR) & (msg[i] # OEBInterfaces.LF) DO INC(i) END;
			msg[i] := 0X;

			IP.AdrToStr(ip, adr);
			IF msg = "INFO: Enter" THEN
				NEW(new, adr);
				new.address := ip;
				session := new
			ELSE
				session := sessions;
				WHILE (session # NIL) & ~IP.AdrsEqual(session(Session).address, ip) DO session := session.next END;
				IF (session = NIL) & ~IsLocalhost(ip) THEN
					(* Create session *)
					NEW(new, adr);
					new.address := ip;
					session := new
				END;
			END;
			RETURN TRUE
		END Receive;

		PROCEDURE Start *;
		VAR
			cmd: ARRAY 32 OF CHAR;
			res: LONGINT;
		BEGIN
			Start^;

			cmd := NopCmd;
			Strings.AppendChar(cmd, OEBInterfaces.CR);
			Strings.AppendChar(cmd, OEBInterfaces.LF);
			socket.Send(IP.StrToAdr("10.3.34.255"), Port, cmd, 0, Strings.Length(cmd), res);
			IF res # UDP.Ok THEN
				KernelLog.Enter;
				KernelLog.String("Could not broadcast 'nop': ");
				KernelLog.Int(res, 0);
				KernelLog.Exit
			END;
		END Start;
		
		PROCEDURE Kill;
		BEGIN
			Kill^;
			IF socket # NIL THEN socket.Close; END;
			BEGIN{EXCLUSIVE}
				sockets.Remove(socket);
			END;
			socket := NIL;
		END Kill;
		
	END Interface;

	Session * = OBJECT (OEBInterfaces.Session)
	VAR
		address: IP.Adr;
	END Session;

	Factory = OBJECT (OEBInterfaces.Factory)
		PROCEDURE NewInterface (CONST param: ARRAY OF CHAR): OEBInterfaces.Interface;
		VAR
			itf: Interface;
		BEGIN
			NEW(itf, param);
			RETURN itf
		END NewInterface;
	END Factory;

VAR
	factory: Factory;
	
	sockets: FoxBasic.List;

	PROCEDURE IsLocalhost (CONST adr: IP.Adr): BOOLEAN;
	VAR
		curr: IP.Interface;
	BEGIN
		curr := IP.interfaces;
		WHILE curr # NIL DO
			IF IP.AdrsEqual(adr, curr.localAdr) THEN RETURN TRUE END;
			curr := curr.next
		END;
		RETURN FALSE
	END IsLocalhost;

	PROCEDURE Cleanup;
	VAR socket: UDP.Socket;
	BEGIN
		OEBInterfaces.Unregister(factory);
		WHILE sockets.Length() > 0 DO
			socket := sockets.Get(0)(UDP.Socket);
			socket.Close;
			sockets.Remove(socket);
		END;
	END Cleanup;

BEGIN
	NEW(factory);
	OEBInterfaces.Register("Udp", factory);
	Modules.InstallTermHandler(Cleanup);
	
	NEW(sockets,8);
END OEBUdpInterfaces.
