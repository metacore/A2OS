MODULE BlCommands;
(**
	AUTHOR Timothée Martiel, 01/2016
	PURPOSE Library to control the bootloader.
*)

IMPORT
	Kernel, Strings, Streams,
	Serials,
	IP, UDP;

CONST
	CR = 0DX;
	LF = 0AX;
	CommandPort = 59999;
	CommandTimeout = 100000;

TYPE
	Command = ARRAY 1024 OF CHAR;

	(** Resource source description base record *)
	Source * = RECORD
	END;

	(** Source description record for TFTP protocol *)
	TftpSource * = RECORD (Source)
		host *: ARRAY 32 OF CHAR;
	END;

	Destination * = RECORD
	END;

	ZynqFpgaDest * = RECORD (Destination)
	END;

	MemoryDest * = RECORD (Destination)
		address *: LONGINT;
		cpus *: SET;
	END;

	FileDest * = RECORD (Destination)
		name *: ARRAY 128 OF CHAR;
	END;

	(** Bootloader load session *)
	Session * = OBJECT
	VAR
		ack -: ARRAY 128 OF CHAR;
		next *: Session;

		(** ABSTRACT generic command execution method *)
		PROCEDURE ExecuteCommand * (CONST cmd: ARRAY OF CHAR): BOOLEAN;
		VAR
			ref: Command;
		BEGIN
			ack := '';
			ref := 'OK: ';
			Strings.Append(ref, cmd);
			IF ~SendCommand(cmd, ack) THEN
				RETURN FALSE
			ELSIF ack # ref THEN
				RETURN FALSE
			ELSE
				RETURN TRUE
			END
		END ExecuteCommand;

		PROCEDURE SendCommand (CONST cmd: ARRAY OF CHAR; VAR resp: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			HALT(133)
		END SendCommand;

		PROCEDURE Load * (CONST filename, resourceName: ARRAY OF CHAR): BOOLEAN;
		VAR
			cmd: Command;
		BEGIN
			cmd := "load ";
			Strings.Append(cmd, filename);
			Strings.Append(cmd, " ");
			Strings.Append(cmd, resourceName);
			Strings.AppendChar(cmd, CR);
			Strings.AppendChar(cmd, LF);
			RETURN ExecuteCommand(cmd)
		END Load;

		PROCEDURE Program * (CONST resourceName: ARRAY OF CHAR; CONST destination: Destination): BOOLEAN;
		VAR
			cmd: Command;
			cpu: LONGINT;
		BEGIN
			cmd := "program ";
			Strings.Append(cmd, resourceName);
			IF destination IS ZynqFpgaDest THEN
				Strings.Append(cmd, " ZynqFpga")
			ELSIF destination IS MemoryDest THEN
				WITH destination: MemoryDest DO
					Strings.Append(cmd, " memory ");
					Strings.AppendInt(cmd, destination.address);
					FOR cpu := 0 TO 31 DO
						IF cpu IN destination.cpus THEN
							Strings.Append(cmd, " ");
							Strings.AppendInt(cmd, cpu)
						END
					END
				END
			ELSIF destination IS FileDest THEN
				WITH destination: FileDest DO
					Strings.Append(cmd, " file ");
					Strings.Append(cmd, destination.name)
				END
			ELSE
				RETURN FALSE
			END;
			Strings.AppendChar(cmd, CR);
			Strings.AppendChar(cmd, LF);
			RETURN ExecuteCommand(cmd)
		END Program;

		PROCEDURE Check * (CONST resourceName, algorithm, reference: ARRAY OF CHAR): BOOLEAN;
		VAR
			cmd: Command;
		BEGIN
			cmd := "check ";
			Strings.Append(cmd, resourceName);
			Strings.Append(cmd, " ");
			Strings.Append(cmd, algorithm);
			Strings.Append(cmd, " ");
			Strings.Append(cmd, reference);
			Strings.AppendChar(cmd, CR);
			Strings.AppendChar(cmd, LF);
			RETURN ExecuteCommand(cmd)
		END Check;

		PROCEDURE Save * (CONST resourceName: ARRAY OF CHAR): BOOLEAN;
		VAR
			cmd: Command;
		BEGIN
			cmd := "save ";
			Strings.Append(cmd, resourceName);
			Strings.AppendChar(cmd, CR);
			Strings.AppendChar(cmd, LF);
			RETURN ExecuteCommand(cmd)
		END Save;

		PROCEDURE Start * (): BOOLEAN;
		VAR
			cmd: Command;
		BEGIN
			cmd := "start";
			Strings.AppendChar(cmd, CR);
			Strings.AppendChar(cmd, LF);
			RETURN ExecuteCommand(cmd)
		END Start;

		PROCEDURE Mount * (CONST prefix, disk: ARRAY OF CHAR; partition: LONGINT): BOOLEAN;
		VAR
			cmd: Command;
		BEGIN
			cmd := "mount ";
			Strings.Append(cmd, prefix);
			Strings.AppendChar(cmd, ' ');
			Strings.Append(cmd, disk);
			Strings.AppendChar(cmd, ' ');
			Strings.AppendInt(cmd, partition);
			Strings.AppendChar(cmd, CR);
			Strings.AppendChar(cmd, LF);
			RETURN ExecuteCommand(cmd)
		END Mount;

		PROCEDURE SetSource * (CONST source: Source): BOOLEAN;
		VAR
			cmd: Command;
		BEGIN
			IF source IS TftpSource THEN
				cmd := "setsource TFTP ";
				Strings.Append(cmd, source(TftpSource).host)
			END;
			Strings.AppendChar(cmd, CR);
			Strings.AppendChar(cmd, LF);
			RETURN ExecuteCommand(cmd)
		END SetSource;

		PROCEDURE SetTimeout * (value: LONGINT): BOOLEAN;
		VAR
			cmd: Command;
			val: ARRAY 32 OF CHAR;
		BEGIN
			cmd := "timeout ";
			Strings.IntToStr(value, val);
			Strings.Append(cmd, val);
			Strings.AppendChar(cmd, CR);
			Strings.AppendChar(cmd, LF);
			RETURN ExecuteCommand(cmd)
		END SetTimeout;

		PROCEDURE SetInput * (CONST input: ARRAY OF CHAR): BOOLEAN;
		VAR
			cmd: Command;
		BEGIN
			cmd := "setinput ";
			Strings.Append(cmd, input);
			Strings.AppendChar(cmd, CR);
			Strings.AppendChar(cmd, LF);
			RETURN ExecuteCommand(cmd)
		END SetInput;

		PROCEDURE Reset * (): BOOLEAN;
		VAR
			cmd: Command;
		BEGIN
			cmd := "reset";
			Strings.AppendChar(cmd, CR);
			Strings.AppendChar(cmd, LF);
			RETURN ExecuteCommand(cmd)
		END Reset;

		PROCEDURE Close *;
		BEGIN
		END Close;
	END Session;

	UdpSession * = OBJECT (Session)
	VAR
		target: IP.Adr;
		socket: UDP.Socket;
		port: LONGINT;

		PROCEDURE & InitUdpSession * (CONST board: ARRAY OF CHAR);
		VAR
			res: LONGINT;
		BEGIN
			port := CommandPort;
			target := IP.StrToAdr(board);
			NEW(socket, CommandPort, res);
		END InitUdpSession;

		PROCEDURE SendCommand (CONST cmd: ARRAY OF CHAR; VAR resp: ARRAY OF CHAR): BOOLEAN;
		VAR
			hostAdr: IP.Adr;
			len, hostPort, res: LONGINT;
		BEGIN
			socket.Send(target, port, cmd, 0, Strings.Length(cmd), res);
			socket.Receive(resp, 0, LEN(ack), CommandTimeout, hostAdr, hostPort, len, res);
			resp[len] := 0X;
			IF res # UDP.Ok THEN
				RETURN FALSE
			ELSIF ~IP.AdrsEqual(hostAdr, target) THEN
				RETURN FALSE
			END;
			RETURN TRUE
		END SendCommand;

		PROCEDURE Close *;
		BEGIN
			socket.Close
		END Close;
	END UdpSession;

	UartSession * = OBJECT (Session)
	VAR
		writer: Streams.Writer;
		reader: Streams.Reader;

		PROCEDURE & InitUartSession * (port: LONGINT);
		VAR
			p: Serials.Port;
		BEGIN
			p := Serials.GetPort(port);
			Streams.OpenReader(reader, p.Receive);
			Streams.OpenWriter(writer, p.Send)
		END InitUartSession;

		PROCEDURE SendCommand (CONST cmd: ARRAY OF CHAR; VAR resp: ARRAY OF CHAR): BOOLEAN;
		VAR
			timer: Kernel.MilliTimer;
			done: BOOLEAN;
		BEGIN
			writer.String(cmd);
			writer.Update;
			Kernel.SetTimer(timer, CommandTimeout);
			REPEAT
				done := reader.GetString(resp);
			UNTIL Kernel.Expired(timer) OR done;
			RETURN done
		END SendCommand;
	END UartSession;
END BlCommands.
