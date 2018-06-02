MODULE UDPChatServer; (** AUTHOR "SAGE"; PURPOSE "UDP Chat Server" *)

IMPORT
	Base := UDPChatBase, UDP, IP,
	Dates, Strings, Modules, Kernel, Events;

CONST
	branchInit				= 0;
	branchPacketReceive	= 1;
	branchVersionCheck	= 2;
	branchAuthentication	= 3;
	branchPacketHandle	= 4;
	branchEnd				= 5;
	branchTerminated		= 6;

	moduleName = "UDPChatServer";

	(* Event classification as in Events.XML *)
	EventClass = 3; (* UDP Chat *)
	EventSubclass = 3; (* UDP Chat Server *)

TYPE

	String = Strings.String;

	Instance = OBJECT
	VAR
		s: UDP.Socket;
		dt: Dates.DateTime;
		running, terminated: BOOLEAN;
		ip: IP.Adr;
		branch, command, seqNum, messageType: INTEGER;
		uin, receiverUin, port, len, res, receiveBufOffset: LONGINT;
		user: Base.User;
		users: Base.Users;
		clients: Base.List;
		client, receiver: Base.Client;
		sendBuf: Base.Buffer;
		receiveBuf, password, shortName, fullName, eMail, message, textCode: String;
		str1, str2: ARRAY 256 OF CHAR;
		ACKReq: Base.ACKRec;

	PROCEDURE &New *(udp: UDP.Socket);
	BEGIN
		s := udp
	END New;

	PROCEDURE Destroy;
	BEGIN
		running := FALSE;
		s.Close;
		BEGIN {EXCLUSIVE}
			AWAIT (terminated)
		END;
	END Destroy;

	PROCEDURE FinalizeClients(clients: Base.List);
	VAR
		i: LONGINT;
		p: ANY;
		client: Base.Client;
	BEGIN
		i := 0;
		WHILE i < clients.GetCount () DO
			p := clients.GetItem (i);
			client := p (Base.Client);
			client.Finalize;
			INC (i);
		END;
	END FinalizeClients;

	PROCEDURE FindClient (clients: Base.List;
		uin: LONGINT;
		VAR client: Base.Client): BOOLEAN;
	VAR
		i: LONGINT;
		p: ANY;
	BEGIN
		i := 0;
		WHILE i < clients.GetCount () DO
			p := clients.GetItem (i);
			client := p (Base.Client);
			IF uin = client.uin THEN
				RETURN TRUE;
			END;
			INC (i);
		END;
		RETURN FALSE;
	END FindClient;

	PROCEDURE CheckKeepAlive (clients: Base.List);
	VAR
		i: LONGINT;
		p: ANY;
	BEGIN
		i := 0;
		WHILE i < clients.GetCount () DO
			p := clients.GetItem (i);
			client := p (Base.Client);
			IF Kernel.Expired (client.keepAliveTimer) THEN
				MulticastStatus (clients, client, Base.USER_OFFLINE, sendBuf, s);
				client.Finalize;
				clients.Remove (client);
			END;
			INC (i);
		END;
	END CheckKeepAlive;


	PROCEDURE Server_NewUserReply (ip: IP.Adr; port: LONGINT; uin: LONGINT;
		seqNum: INTEGER; sendBuf: Base.Buffer; s: UDP.Socket);
	VAR
		res: WORD;
		string: String;
	BEGIN {EXCLUSIVE}
		Base.ServerPacketInit (Base.NEW_USER_REPLY, seqNum, sendBuf);

		sendBuf.AddInt (uin, 4);

		string := sendBuf.GetString ();
		s.Send (ip, port, string^, 0, sendBuf.GetLength (), res);
	END Server_NewUserReply;

	PROCEDURE Server_LoginReply (client: Base.Client;
		sendBuf: Base.Buffer; s: UDP.Socket);
	VAR
		res: WORD;
		string: String;
	BEGIN {EXCLUSIVE}
		Base.ServerPacketInit (Base.LOGIN_REPLY, client.inSeqNum, sendBuf);

		sendBuf.AddInt (client.uin, 4);

		string := sendBuf.GetString ();
		s.Send (client.ip, client.port, string^, 0, sendBuf.GetLength (), res);
	END Server_LoginReply;

	PROCEDURE Server_InfoReply (client: Base.Client;
		user: Base.User; sendBuf: Base.Buffer; s: UDP.Socket);
	VAR
		string: String;
		res, len: LONGINT;
	BEGIN {EXCLUSIVE}
		Base.ServerPacketInit (Base.INFO_REPLY, client.inSeqNum, sendBuf);

		sendBuf.AddInt (user.uin, 4);

		len := Strings.Length (user.shortName) + 1;
		sendBuf.AddInt (len, 2);
		sendBuf.Add (user.shortName, 0, len, TRUE, res);

		string := sendBuf.GetString ();
		s.Send (client.ip, client.port, string^, 0, sendBuf.GetLength (), res);
	END Server_InfoReply;

	PROCEDURE Server_ACK (client: Base.Client;
		sendBuf: Base.Buffer; s: UDP.Socket);
	VAR
		res: WORD;
		string: String;
	BEGIN {EXCLUSIVE}
		Base.ServerPacketInit (Base.ACK, client.inSeqNum, sendBuf);

		string := sendBuf.GetString ();
		s.Send (client.ip, client.port, string^, 0, sendBuf.GetLength (), res);
	END Server_ACK;

	PROCEDURE Server_UserStatus (client, receiver: Base.Client;
		status: INTEGER; sendBuf: Base.Buffer; s: UDP.Socket);
	VAR
		res: WORD;
		string: String;
	BEGIN {EXCLUSIVE}
		Base.ServerPacketInit (status, receiver.outSeqNum, sendBuf);

		NEW (ACKReq);
		ACKReq.seqNum := receiver.outSeqNum;
		receiver.ACKList.Add (ACKReq);

		INC (receiver.outSeqNum);

		sendBuf.AddInt (client.uin, 4);

		string := sendBuf.GetString ();
		s.Send (receiver.ip, receiver.port, string^, 0, sendBuf.GetLength (), res);
	END Server_UserStatus;

	PROCEDURE Server_ReceiveMessage (client, receiver: Base.Client; dt: Dates.DateTime;
		messageType: INTEGER; message: String; sendBuf: Base.Buffer; s: UDP.Socket);
	VAR
		string: String;
		res, len: LONGINT;
	BEGIN {EXCLUSIVE}
		Base.ServerPacketInit (Base.RECEIVE_MESSAGE, receiver.outSeqNum, sendBuf);

		NEW (ACKReq);
		ACKReq.seqNum := receiver.outSeqNum;
		receiver.ACKList.Add (ACKReq);

		INC (receiver.outSeqNum);

		sendBuf.AddInt (client.uin, 4);
		sendBuf.AddInt (dt.year, 2);
		sendBuf.AddInt (dt.month, 1);
		sendBuf.AddInt (dt.day, 1);
		sendBuf.AddInt (dt.hour, 1);
		sendBuf.AddInt (dt.minute, 1);

		sendBuf.AddInt (messageType, 2);

		(*
		len := Strings.Length (message^) + 1;
		*)
		len := LEN (message^);

		sendBuf.AddInt (len, 2);
		sendBuf.Add (message^, 0, len, TRUE, res);

		string := sendBuf.GetString ();
		s.Send (receiver.ip, receiver.port, string^, 0, sendBuf.GetLength (), res);
	END Server_ReceiveMessage;

	PROCEDURE MulticastStatus (clients: Base.List;
		client: Base.Client;
		status: INTEGER; sendBuf: Base.Buffer; s: UDP.Socket);
	VAR
		i: LONGINT;
		p: ANY;
		receiver: Base.Client;
	BEGIN
		i := 0;
		WHILE i < clients.GetCount () DO
			p := clients.GetItem (i);
			receiver := p (Base.Client);
			IF client.uin # receiver.uin THEN
				Server_UserStatus (client, receiver, status, sendBuf, s);
				IF status = Base.USER_ONLINE THEN
					Server_UserStatus (receiver, client, status, sendBuf, s);
				END;
			END;
			INC (i);
		END;
	END MulticastStatus;

	PROCEDURE MulticastMessage (clients: Base.List;
		client: Base.Client; dt: Dates.DateTime; messageType: INTEGER; message: String;
		sendBuf: Base.Buffer; s: UDP.Socket);
	VAR
		i: LONGINT;
		p: ANY;
		receiver: Base.Client;
	BEGIN
		i := 0;
		WHILE i < clients.GetCount () DO
			p := clients.GetItem (i);
			receiver := p (Base.Client);
			(*IF client.uin # receiver.uin THEN*)

				Server_ReceiveMessage (client, receiver, dt, messageType, message, sendBuf, s);

			(*END;*)
			INC (i);
		END;
	END MulticastMessage;

	BEGIN {ACTIVE}

		branch := branchInit;

		REPEAT

			CASE branch OF

			| branchInit:

				NEW (receiveBuf, Base.MaxUDPDataLen);
				NEW (sendBuf, 0);
				NEW (clients);

				NEW (users);

				running := TRUE;
				terminated := FALSE;

				branch := branchPacketReceive;

			| branchPacketReceive:

				IF running THEN

					s.Receive (receiveBuf^, 0, Base.MaxUDPDataLen, 1, ip, port, len, res);

					IF (res = UDP.Ok) & (len > 0) THEN

						receiveBufOffset := 0;

						branch := branchVersionCheck;

					END;

					CheckKeepAlive (clients);

				ELSE

					branch := branchEnd;

				END;

			| branchVersionCheck:

				IF Base.BufGetInt (receiveBuf, receiveBufOffset) = Base.VERSION THEN

					branch := branchAuthentication;

				ELSE

					branch := branchPacketReceive;

				END;

			| branchAuthentication:

				command := Base.BufGetInt (receiveBuf, receiveBufOffset);
				seqNum := Base.BufGetInt (receiveBuf, receiveBufOffset);
				uin := Base.BufGetLInt (receiveBuf, receiveBufOffset);

				Strings.IntToStr (seqNum, str1);
				Strings.Concat (" SeqNum: ", str1, str1);
				Strings.Concat (str1, " Command: ", str1);

				Strings.IntToStr (uin, str2);
				Strings.Concat ("User ID: ", str2, str2);
				Strings.Concat (str2, str1, str1);

				Base.CommandDecode (command, str2);
				Strings.Concat (str1, str2, str1);

				Log (Events.Information, 0, str1, FALSE);

				IF FindClient (clients, uin, client) THEN

					(* Additional check *)
					IF (IP.AdrsEqual (client.ip, ip)) & (client.port = port) THEN

						branch := branchPacketHandle;

					ELSE

						branch := branchPacketReceive;

					END;

				ELSE

					CASE command OF
					| Base.LOGIN:

						password := Base.BufGetString (receiveBuf, receiveBufOffset);

						IF users.PasswordCorrect (uin, password) THEN

							NEW (client);
							client.ip := ip;
							client.port := port;
							client.uin := uin;

							client.inSeqNum := seqNum;
							client.outSeqNum := 0;

							Kernel.SetTimer (client.keepAliveTimer, Base.clientKeepAliveAwait);

							clients.Add (client);

							Server_LoginReply (client, sendBuf, s);

							(* Now we will send client status to all other On-Line clients,
							and they statuses to this client *)
							MulticastStatus (clients, client, Base.USER_ONLINE, sendBuf, s);

						END;

					| Base.NEW_USER_REG:

						password := Base.BufGetString (receiveBuf, receiveBufOffset);

						shortName := Base.BufGetString (receiveBuf, receiveBufOffset);

						fullName := Base.BufGetString (receiveBuf, receiveBufOffset);

						eMail := Base.BufGetString (receiveBuf, receiveBufOffset);

						user := users.Add (password, shortName, fullName, eMail);

						Server_NewUserReply (ip, port, user.uin, seqNum, sendBuf, s);

					ELSE

					END;

					branch := branchPacketReceive;

				END;

			| branchPacketHandle:

				IF command = Base.ACK THEN

					IF Base.SeqNumInACKList (client.ACKList, seqNum, ACKReq) THEN

						client.ACKList.Remove (ACKReq);

					END;

				ELSIF Base.isNextSeqNum (seqNum, client.inSeqNum) THEN

					client.inSeqNum := seqNum;

					CASE command OF
					| Base.SEND_MESSAGE:

						Server_ACK (client, sendBuf, s);

						receiverUin := Base.BufGetLInt (receiveBuf, receiveBufOffset);
						messageType := Base.BufGetInt (receiveBuf, receiveBufOffset);
						message := Base.BufGetString (receiveBuf, receiveBufOffset);

						dt := Dates.Now ();

						IF receiverUin = 0 THEN

							MulticastMessage (clients, client, dt, messageType, message, sendBuf, s);

						ELSE

							IF FindClient (clients, receiverUin, receiver) THEN

								Server_ReceiveMessage (client, receiver, dt, messageType, message, sendBuf, s);

							ELSE

								(*
								!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
								*)

							END;

						END;

					| Base.KEEP_ALIVE:

						Server_ACK (client, sendBuf, s);

						Kernel.SetTimer (client.keepAliveTimer, Base.clientKeepAliveAwait);

					| Base.INFO_REQ:

						receiverUin := Base.BufGetLInt (receiveBuf, receiveBufOffset);
						user := users.Find (receiverUin);

						IF user # NIL THEN

							Server_InfoReply (client, user, sendBuf, s);

						END;

					| Base.SEND_TEXT_CODE:

						Server_ACK (client, sendBuf, s);

						textCode := Base.BufGetString (receiveBuf, receiveBufOffset);

						IF textCode^ = "USER_DISCONNECTED" THEN

							MulticastStatus (clients, client, Base.USER_OFFLINE, sendBuf, s);

							clients.Remove (client);

						ELSE

							(*
							!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
							*)

						END;

					ELSE

					END;

				END;

				branch := branchPacketReceive;

			| branchEnd:

				users.Store;
				FinalizeClients (clients);
				clients.Clear;

				BEGIN {EXCLUSIVE}
					terminated := TRUE
				END;

				branch := branchTerminated;

			ELSE

			END;

		UNTIL branch = branchTerminated;

	END Instance;

VAR
	instance: Instance;

PROCEDURE Log (type, code : SHORTINT; msg: ARRAY OF CHAR; showOnKernelLog : BOOLEAN);
VAR message : Events.Message;
BEGIN
	COPY(msg, message);
	Events.AddEvent(moduleName, type, EventClass, EventSubclass, code, message, showOnKernelLog);
END Log;

PROCEDURE Start* ;
VAR
	s: UDP.Socket;
	res: WORD;
	str: ARRAY 256 OF CHAR;
BEGIN
	IF instance = NIL THEN
		NEW (s, Base.serverPort, res);
		IF res = UDP.Ok THEN
			NEW (instance, s);
			Strings.IntToStr (Base.serverPort, str);
			Strings.Concat ("server started on port: ", str, str);
			Log (Events.Information, 0, str, TRUE);
		ELSE
			Log (Events.Error, 0, "server NOT started!", TRUE);
		END;
	END;
END Start;

PROCEDURE Stop*;
BEGIN
	Cleanup;
END Stop;

(** Termination handler. *)
PROCEDURE Cleanup;
BEGIN
	IF instance # NIL THEN

		instance.Destroy;

	END;
END Cleanup;

BEGIN
	Modules.InstallTermHandler (Cleanup);
END UDPChatServer.
