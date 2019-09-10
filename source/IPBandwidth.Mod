MODULE IPBandwidth;	(** AUTHOR "negelef"; PURPOSE "Bandwidth measurement on IP networks."; *)

IMPORT Commands, Diagnostics, Kernel, Options, Streams, DNS, IP, TCP, UDP;

CONST DefaultPort = 5772;
CONST DefaultDuration = 10;

TYPE Link = OBJECT

	VAR context: Commands.Context;
	VAR diagnostics: Diagnostics.StreamDiagnostics;
	VAR hostname: DNS.Name;
	VAR port, result: INTEGER;
	VAR address: IP.Adr;
	VAR buffer: ARRAY 65000 OF CHAR;

	PROCEDURE &Initialize (context: Commands.Context);
	BEGIN
		SELF.context := context;
		NEW (diagnostics, context.error);
	END Initialize;

	PROCEDURE Send;
	VAR sent: SIZE;
	BEGIN
		IF ~context.arg.GetString (hostname) THEN
			context.result := Commands.CommandParseError; RETURN;
		END;
		DNS.HostByName (hostname, address, result);
		IF result # DNS.Ok THEN
			diagnostics.Error (hostname, port, "failed to resolve");
			context.result := Commands.CommandError; RETURN;
		END;
		IF ~context.arg.GetInteger (port, FALSE) THEN
			port := DefaultPort;
		END;

		Connect;
		IF result # Streams.Ok THEN
			diagnostics.Error (hostname, port, "failed to connect to server");
			context.result := Commands.CommandError; RETURN;
		END;

		sent := 0;
		context.out.String ("Sending data..."); context.out.Ln; context.out.Update;
		WHILE ReceiveBytes () = 0 DO
			INC (sent, SendBytes ());
			IF result # Streams.Ok THEN
				Close;
				diagnostics.Error (hostname, port, "failed to send");
				context.result := Commands.CommandError; RETURN;
			END;
		END;

		Close;
		context.out.String ("Sent "); context.out.Size (sent); context.out.String (" bytes"); context.out.Ln; context.out.Update;
	END Send;

	PROCEDURE Receive;
	VAR duration, ticks: INTEGER; received: SIZE;
	BEGIN
		hostname := "server";
		IF ~context.arg.GetInteger (duration, FALSE) THEN
			duration := DefaultDuration;
		END;
		IF ~context.arg.GetInteger (port, FALSE) THEN
			port := DefaultPort;
		END;

		Listen;
		IF result # Streams.Ok THEN
			diagnostics.Error (hostname, port, "failed to connect to client");
			context.result := Commands.CommandError; RETURN;
		END;

		received := 0; ticks := 0;
		context.out.String ("Receiving data..."); context.out.Ln; context.out.Update;
		LOOP
			INC (received, ReceiveBytes ());
			IF result # Streams.Ok THEN
				Close;
				diagnostics.Error (hostname, port, "failed to receive");
				context.result := Commands.CommandError; RETURN;
			END;
			IF ticks = 0 THEN
				IF received # 0 THEN ticks := Kernel.GetTicks () + Kernel.second * duration END;
			ELSE
				IF Kernel.GetTicks () - ticks >= 0 THEN EXIT END;
			END;
		END;

		Close;
		context.out.String ("Received "); context.out.Size (received); context.out.String (" bytes in ");
		context.out.Int (duration, 0); context.out.String (" seconds"); context.out.Ln;
		context.out.String ("Bandwidth: "); context.out.FloatFix (received / (1000000 * duration), 0, 3, 0);
		context.out.String (" MB/s"); context.out.Ln; context.out.Update;
	END Receive;

	PROCEDURE Connect;
	BEGIN HALT (1001);
	END Connect;

	PROCEDURE Listen;
	BEGIN HALT (1001);
	END Listen;

	PROCEDURE SendBytes (): SIZE;
	BEGIN HALT (1001);
	END SendBytes;

	PROCEDURE ReceiveBytes (): SIZE;
	BEGIN HALT (1001);
	END ReceiveBytes;

	PROCEDURE Close;
	BEGIN HALT (1001);
	END Close;

END Link;

TYPE TCPLink = OBJECT (Link)

	VAR service, connection: TCP.Connection;

	PROCEDURE Connect;
	BEGIN
		NEW (connection);
		connection.Open (TCP.NilPort, address, port, result);
	END Connect;

	PROCEDURE Listen;
	BEGIN
		NEW (service);
		service.Open (port, IP.NilAdr, TCP.NilPort, result);
		IF result = TCP.Ok THEN
			context.out.String ("Waiting for client..."); context.out.Ln; context.out.Update;
			service.Accept (connection, result);
		END;
	END Listen;

	PROCEDURE SendBytes (): SIZE;
	BEGIN
		connection.Send (buffer, 0, LEN (buffer), FALSE, result);
		RETURN LEN (buffer);
	END SendBytes;

	PROCEDURE ReceiveBytes (): SIZE;
	VAR received: SIZE;
	BEGIN
		IF connection.Available () # 0 THEN
			connection.Receive (buffer, 0, LEN (buffer), 1, received, result);
			IF result = TCP.Ok THEN RETURN received END;
		END;
		RETURN 0;
	END ReceiveBytes;

	PROCEDURE Close;
	BEGIN
		connection.Close;
		IF service # NIL THEN service.Close END;
	END Close;

END TCPLink;

TYPE UDPLink = OBJECT (Link)

	VAR socket: UDP.Socket;

	PROCEDURE Connect;
	BEGIN
		NEW (socket, UDP.NilPort, result);
	END Connect;

	PROCEDURE Listen;
	BEGIN
		NEW (socket, port, result);
	END Listen;

	PROCEDURE SendBytes (): SIZE;
	BEGIN
		socket.Send (address, port, buffer, 0, LEN (buffer), result);
		RETURN LEN (buffer);
	END SendBytes;

	PROCEDURE ReceiveBytes (): SIZE;
	VAR address: IP.Adr; port: INTEGER; received: SIZE;
	BEGIN
		socket.Receive (buffer, 0, LEN (buffer), 0, address, port, received, result);
		IF result = UDP.Ok THEN RETURN received END;
		IF result = UDP.Timeout THEN result := UDP.Ok END;
		RETURN 0;
	END ReceiveBytes;

	PROCEDURE Close;
	BEGIN socket.Close;
	END Close;

END UDPLink;

(** Synposis: hostname [port] *)
PROCEDURE SendTCP* (context: Commands.Context);
VAR link: TCPLink;
BEGIN
	NEW (link, context);
	link.Send;
END SendTCP;

(** Synposis: [duration] [port] *)
PROCEDURE ReceiveTCP* (context: Commands.Context);
VAR link: TCPLink; client: TCP.Connection;
BEGIN
	NEW (link, context);
	link.Receive;
END ReceiveTCP;

(** Synposis: hostname [port] *)
PROCEDURE SendUDP* (context: Commands.Context);
VAR link: UDPLink;
BEGIN
	NEW (link, context);
	link.Send;
END SendUDP;

(** Synposis: [duration] [port] *)
PROCEDURE ReceiveUDP* (context: Commands.Context);
VAR link: UDPLink;
BEGIN
	NEW (link, context);
	link.Receive;
END ReceiveUDP;

END IPBandwidth.
