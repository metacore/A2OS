MODULE TCPTools; (** AUTHOR "staubesv"; PURPOSE "Some utilitiy commands for TCP"; *)

IMPORT
	Streams, Commands, Files, IP, TCP, DNS;

CONST
	BufferSize = 4096;

(** Send a file to hostname:port. This can be used to send a PS file to a PS capable network printer (use port 9100) *)
PROCEDURE SendFile*(context : Commands.Context); (** hostname port filename ~ *)
VAR
	hostname, adrStr : ARRAY 256 OF CHAR; ipAdr : IP.Adr; port, res : LONGINT;
	filename : Files.FileName; file : Files.File; reader : Files.Reader;
	offset, len : LONGINT;
	buffer : POINTER TO ARRAY OF CHAR;
	connection : TCP.Connection;
	writer : Streams.Writer;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(hostname);
	context.arg.SkipWhitespace; context.arg.Int(port, FALSE);
	context.arg.SkipWhitespace; context.arg.String(filename);
	DNS.HostByName(hostname, ipAdr, res);
	IF (res = DNS.Ok) THEN
		IP.AdrToStr(ipAdr, adrStr);
		NEW(connection);
		connection.Open(TCP.NilPort, ipAdr, port, res);
		IF (res = TCP.Ok) THEN
			NEW(writer, connection.Send, BufferSize);
			context.out.String("Connected to "); context.out.String(adrStr); context.out.String(":"); context.out.Int(port, 0);
			context.out.Ln;
			file := Files.Old(filename);
			IF (file # NIL) THEN
				context.out.String("Sending file "); context.out.String(filename); context.out.String(" ... ");
				NEW(buffer, BufferSize);
				NEW(reader, file, 0);
				offset := 0;
				reader.Bytes(buffer^, offset, BufferSize, len);
				WHILE (len > 0) DO
					writer.Bytes(buffer^, 0, len);
					INC(offset, BufferSize);
					reader.Bytes(buffer^, 0, BufferSize, len);
				END;
				writer.Update;
				context.out.String("done."); context.out.Ln;
			ELSE
				context.error.String("Could not open file "); context.error.String(filename); context.error.Ln;
			END;
			connection.Close;
		ELSE
			context.error.String("Could not open connection to server "); context.error.String(hostname);
			context.error.String(" ("); context.error.String(adrStr); context.error.String(":"); context.error.Int(port, 0);
			context.error.String("), res: "); context.error.Int(res, 0); context.error.Ln;
		END;
	ELSE
		context.error.String("Could not resolve hostname '"); context.error.String(hostname);
		context.error.String("', res: "); context.error.Int(res, 0); context.error.Ln;
	END;
END SendFile;

END TCPTools.

TCPTools.SendFile 129.132.134.254 9100 test.ps ~

System.Free TCPTools ~

