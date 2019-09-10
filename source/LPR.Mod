MODULE LPR; (* AUTHOR "ejz"; PURPOSE "RFC 1179" *)

	IMPORT Files, Streams,  TCP, DNS, IP, Configuration, Strings;

	CONST
		DefConPort = 515;
		BegLocPort = 721;
		EndLocPort = 731;
		LF = 0AX;
		CR = 0DX;
		DefaultEmail = "oberonuser@ethz.ch";

		(*Errors*)
		OK = 0;
		FILENOTFOUND = -1;
		HOSTNOTFOUND = -2;
		READERNIL = -3;
		SENDCONTROLFILEFAILED = -4;
		RECEIVECONTROLFILEFAILED = -5;
		SENDDATAFILEFAILED= -6;
		RECEIVEDATAFILEFAILED= -7;
		RECEIVEPRINTJOBFAILED= -8;
		NOTCONNECTED=-9;


	VAR
		jobNr: SIGNED16;





	PROCEDURE Print*(CONST host, queue, docName, email: ARRAY OF CHAR; banner, mail: BOOLEAN; data : Streams.Reader;  size: Streams.Position;  VAR res : INTEGER);
		VAR
			dataFile, controlFile: ARRAY 64 OF CHAR;
			nrStr: ARRAY 8 OF CHAR;
			state: CHAR;
			controlfile : Strings.Buffer;
			controlfileWriter : Streams.Writer;
			reader: Streams.Reader;
			writer: Streams.Writer;
			fadr: IP.Adr;
			locport: SIGNED16;
			connres: INTEGER; len : SIZE;
			conn: TCP.Connection;
			buf : ARRAY 10000 OF CHAR;
	BEGIN
		DNS.HostByName(host, fadr, connres);
		IF connres = DNS.Ok THEN
			locport := BegLocPort;
			REPEAT
				NEW(conn); conn.Open(locport, fadr, DefConPort, connres);
				INC(locport)
			UNTIL (connres = TCP.Ok) OR (locport > EndLocPort);
			IF connres = TCP.Ok THEN
				IF data # NIL THEN
					Streams.OpenReader(reader, conn.Receive);
					Streams.OpenWriter(writer, conn.Send);
					INC(jobNr);
					IF jobNr >= 1000 THEN
						jobNr := 100
					END;
					Strings.IntToStr(jobNr, nrStr);
					COPY("dfA",dataFile);
					Strings.Append(dataFile, nrStr);
					Strings.Append(dataFile, host);
					COPY("cfA", controlFile);
					Strings.Append(controlFile, nrStr);
					Strings.Append(controlFile, host);


					writer.Char(02X); writer.String(queue);writer.Char(LF);(* receive a print job *)
					writer.Update();
					state := 0FFX; state := reader.Get();
					IF (state = 0X) & (reader.res = Streams.Ok) THEN

						Strings.IntToStr(size + 1, nrStr);
						writer.Char( 03X); writer.String(nrStr); writer.Char(" "); writer.String(dataFile); writer.Char(LF);(* receive data file *)
						writer.Update();
						state := 0FFX; state := reader.Get();
						IF (state = 0X) & (reader.res = Streams.Ok) THEN
							WHILE data.res = Streams.Ok DO
								data.Bytes(buf, 0, LEN(buf), len);
								writer.Bytes(buf, 0, len);
							END;
							writer.Char(LF); writer.Char(0X);
							writer.Update();
							state := 0FFX; state := reader.Get();
							IF (state = 0X)& (reader.res = Streams.Ok) THEN

								NEW(controlfile,100000);
								controlfileWriter := controlfile.GetWriter();

								controlfileWriter.Char("H");controlfileWriter.String(host); controlfileWriter.Char(LF);

								controlfileWriter.Char("P"); controlfileWriter.String(email); controlfileWriter.Char(LF);(* user identification *)

								IF mail THEN (* send mail when job has finished *)
									controlfileWriter.Char("M"); controlfileWriter.String(email); controlfileWriter.Char(LF);(* user identification *) (* user identification *)
								END;

								IF docName # "" THEN
									controlfileWriter.Char("J");controlfileWriter.String(docName);controlfileWriter.Char(LF);(* job name *)
								END;

								IF banner THEN
									controlfileWriter.Char("L"); controlfileWriter.String(email); controlfileWriter.Char(LF);(* banner page *)
								END;

								controlfileWriter.Char("l");controlfileWriter.String(dataFile);controlfileWriter.Char(LF);(* print file direct *)

								controlfileWriter.Char("U");controlfileWriter.String(dataFile);controlfileWriter.Char(LF);(* unlink data file *)

								controlfileWriter.Char("N");controlfileWriter.String(docName);controlfileWriter.Char(LF);(* name of source file *)


								Strings.IntToStr(controlfile.GetLength(), nrStr);
								writer.Char( 02X); writer.String(nrStr); writer.Char( " "); writer.String(controlFile);writer.Char( LF);(* receive control file *)
								writer.Update();
								state := 0FFX; state := reader.Get();
								IF (state = 0X) & (reader.res = Streams.Ok)  THEN
									controlfile.Write(writer); writer.Char(0X);
									writer.Update();
									conn.Close();
									state := 0FFX; state := reader.Get();
									IF (state = 0X)  THEN
										res := OK;
									ELSE
										res := SENDCONTROLFILEFAILED;
									END
								ELSE
									res := RECEIVECONTROLFILEFAILED;
								END
							ELSE
								res := SENDDATAFILEFAILED;
							END
						ELSE
							res :=  RECEIVEDATAFILEFAILED;
						END
					ELSE
						res := RECEIVEPRINTJOBFAILED
					END;
				ELSE
					res := READERNIL;
				END;
			ELSE
				res := NOTCONNECTED;
			END;
		ELSE
			res := HOSTNOTFOUND;
		END;
	END Print;



(** LPRPrinter.ShowJobs queue@host  Display a list of the waiting jobs in the given queue. *)
PROCEDURE ShowJobs*(out: Streams.Writer; CONST host, queue : ARRAY OF CHAR; VAR res: INTEGER);
		VAR
			job: ARRAY 64 OF CHAR;
			connres: INTEGER;
			conn: TCP.Connection;
			reader: Streams.Reader;
			writer: Streams.Writer;
			fadr: IP.Adr;
			locport: SIGNED16;
	BEGIN
		DNS.HostByName(host, fadr, connres);
		IF connres = DNS.Ok THEN
			locport := BegLocPort;
			REPEAT
				NEW(conn); conn.Open(locport, fadr, DefConPort, connres);
				INC(locport)
			UNTIL (connres = TCP.Ok) OR (locport > EndLocPort);
			IF connres = TCP.Ok THEN
				Streams.OpenReader(reader, conn.Receive);
				Streams.OpenWriter(writer, conn.Send);
				writer.Char(04X); (* 03X short, 04X long *) writer.String(queue);writer.Char(LF);
				writer.Update();
				WHILE reader.res = Streams.Ok DO
					reader.Ln(job);
					out.String(job);
				END;
				res := OK;
				conn.Close();
			ELSE
				res := NOTCONNECTED;
			END;
		ELSE
			res := HOSTNOTFOUND;
		END;

	END ShowJobs;

(** LPRPrinter.RemoveJob queue@host [ job-nr ]
		Remove the specified job or all jobs from queue. *)
	PROCEDURE RemoveJob*(CONST host, queue,  email, job: ARRAY OF CHAR; VAR res : INTEGER);
	VAR
		connres: INTEGER;
		conn: TCP.Connection;
		reader: Streams.Reader;
		writer : Streams.Writer;
		fadr: IP.Adr;
		locport: SIGNED16;
	BEGIN
		DNS.HostByName(host, fadr, connres);
		IF connres = DNS.Ok THEN
			locport := BegLocPort;
			REPEAT
				NEW(conn); conn.Open(locport, fadr, DefConPort, connres);
				INC(locport)
			UNTIL (connres = TCP.Ok) OR (locport > EndLocPort);
			IF connres = TCP.Ok THEN
				Streams.OpenReader(reader, conn.Receive);
				Streams.OpenWriter(writer, conn.Send);
				writer.Char(05X);writer.String(queue); writer.Char(" "); writer.String(email); (* remove jobs *)
				IF job # "" THEN
					writer.Char(" ");
					writer.String(job)
				END;
				writer.Char(LF);
				writer.Update();
				res := OK;
				conn.Close();
			ELSE
				res := NOTCONNECTED;
			END;
		ELSE
			res := HOSTNOTFOUND;
		END;
	END RemoveJob;


	PROCEDURE PrintFile*(CONST fn : ARRAY OF CHAR; VAR res : INTEGER);
	VAR
		file : Files.File;
		fileReader : Files.Reader;
		host, queue, email: ARRAY 100 OF CHAR;
		banner, mail : BOOLEAN;
	BEGIN
		file := Files.Old(fn);
		IF (file # NIL) THEN
			Configuration.Get("LPR.host", host, res);
			Configuration.Get("LPR.queue", queue, res);
			Configuration.Get("LPR.email", email, res);
			banner := FALSE;
			mail := FALSE;
			Files.OpenReader(fileReader, file, 0);
			Print(host, queue, "Oberon Document", email,  banner, mail, fileReader, file.Length(), res);
		ELSE
			res := FILENOTFOUND;
		END;
	END PrintFile;

BEGIN
	jobNr := 99;
END LPR.


Usage:

PROCEDURE PrintTest*;
VAR
	res : INTEGER;
BEGIN
	KernelLog.String("Printing....");
	LPR.PrintFile("test.ps", res);
	KernelLog.Int(res, 5); KernelLog.Ln;
END PrintTest;

PROCEDURE PrintTest2*();
VAR
	file : Files.File;
	fileReader : Files.Reader;
	host, queue, email: ARRAY 100 OF CHAR;
	banner, mail : BOOLEAN;
	res : INTEGER;
BEGIN
	file := Files.Old("test.ps");
	IF (file # NIL) THEN
		Files.OpenReader(fileReader, file, 0);
		COPY("129.132.134.122", host);
		COPY("dummyQueue", queue);
		COPY("daniel.keller@inf.ethz.ch", email);
		banner := FALSE;
		mail := FALSE;
		Files.OpenReader(fileReader, file, 0);
		KernelLog.String("Printing....");
		LPR.Print(host, queue, "Oberon Document", email,  banner, mail, fileReader, file.Length(), res);
		KernelLog.Int(res, 5); KernelLog.Ln;
	END;
END PrintTest2;

PROCEDURE ShowJobTest*;
VAR
	out : Streams.Writer;
	host, queue: ARRAY 100 OF CHAR;
	res : INTEGER;
BEGIN
	Streams.OpenWriter(out, KernelLog.Send);
	Configuration.Get("LPR.host", host);
	Configuration.Get("LPR.queue", queue);
	LPR.ShowJobs(out, host, queue, res);
	KernelLog.Int(res, 5); KernelLog.Ln;
END ShowJobTest;

