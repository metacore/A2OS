MODULE RFC865Client;	(** AUTHOR "TF"; PURPOSE "Get a quote from a RFC865 compliant server"; *)

IMPORT
	Commands, IP, DNS, TCP, Streams;

CONST QuotePort = 17;

PROCEDURE GetQuote*(context : Commands.Context);
VAR
	connection : TCP.Connection;
	serverName : ARRAY 32 OF CHAR;
	line : ARRAY 513 OF CHAR;
	serverIP: IP.Adr;
	res : WORD;
	reader : Streams.Reader;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(serverName);

	(* perform a DNS lookup *)
	DNS.HostByName(serverName, serverIP, res);
	IF res # 0 THEN (* If the result is not 0, the DNS lookup has failed *)
		context.error.String("Host not found."); context.error.Ln;
		RETURN
	END;

	(* Print the IP address ... *)
	IP.AdrToStr(serverIP, line);
	context.out.String("Server found at "); context.out.String(line); context.out.Ln;

	(* Open a connection to the serverIP *)
	NEW(connection);
	(* Set the local port to IP.NilPort because we dont care.
	The system will fill in an available local port *)
	connection.Open(TCP.NilPort, serverIP, QuotePort, res);
	IF res # 0 THEN (* If the result is not 0, the connection failed *)
		context.error.String("Could not connect to host."); context.error.Ln;
		RETURN
	END;

	(* Open a reader stream on the connection receiver *)
	Streams.OpenReader(reader, connection.Receive);
	REPEAT
		reader.Ln(line);
		context.out.String(line); context.out.Ln
	UNTIL reader.res # 0;
	connection.Close;
END GetQuote;

END RFC865Client.


System.Free RFC865Client ~
System.OpenKernelLog
Aos.Call RFC865Client.GetQuote bluebottle.ethz.ch ~