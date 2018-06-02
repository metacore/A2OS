MODULE RAWPrinter; (** AUTHOR "dk"; PURPOSE "Printing Raw to Port 9100"; *)
	IMPORT Files, Streams,  IP, TCP, DNS;

	CONST
		DefConPort = 9100;

		(*Errors*)
		FILENOTFOUND = -1;
		HOSTNOTFOUND = -2;
		READERNIL = -3;
		OK = 0;


	PROCEDURE PrintFile*(CONST printer, fn: ARRAY OF CHAR; VAR res : WORD);
	VAR
		fileReader : Files.Reader;
		file : Files.File;
	BEGIN
		file := Files.Old(fn);
		IF (file # NIL) THEN
		   Files.OpenReader(fileReader, file, 0);
		   PrintStream(printer, fileReader, res);
		ELSE
			res := FILENOTFOUND;
		END;
	END PrintFile;


	PROCEDURE PrintStream*(CONST printer : ARRAY OF CHAR; reader : Streams.Reader; VAR res : WORD);
		VAR
			writer: Streams.Writer;
			buf : ARRAY 10000 OF CHAR;
			conn : TCP.Connection;
			fadr: IP.Adr;
			connres, len : LONGINT;
	BEGIN
		 DNS.HostByName(printer, fadr, connres);
		IF res = DNS.Ok THEN
			NEW(conn); conn.Open(TCP.NilPort, fadr, DefConPort, connres);
			Streams.OpenWriter(writer, conn.Send);
			IF connres = TCP.Ok THEN
				IF reader # NIL THEN
					WHILE reader.res = Streams.Ok DO
						reader.Bytes(buf, 0, LEN(buf), len);
						writer.Bytes(buf, 0, len);
					END;
					writer.Update();
					conn.Close();
					res := OK;
				ELSE
					res := READERNIL;
				END;
			ELSE
				res := HOSTNOTFOUND;
			END;
		END;

	END PrintStream;



END RAWPrinter.


Usage:


PROCEDURE PrintTest1*();
VAR
	res : WORD;
BEGIN
	RAWPrinter.PrintFile("129.132.134.122", "test.ps", res);
	KernelLog.String("Printing res : "); KernelLog.Int(res, 5); KernelLog.Ln;
END PrintTest1;


PROCEDURE PrintTest2*();
VAR
	file : Files.File;
	res : WORD;
	reader : Files.Reader;
BEGIN
	file := Files.Old("test.ps");
	Files.OpenReader(reader, file, 0);
	RAWPrinter.PrintStream("129.132.134.122", reader,res);
	KernelLog.String("Printing res : "); KernelLog.Int(res, 5); KernelLog.Ln;
END PrintTest2;
