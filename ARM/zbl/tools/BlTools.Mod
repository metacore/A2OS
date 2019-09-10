MODULE BlTools;
(**
	AUTHOR Timothée Martiel, 01/2016
	PURPOSE Command interface to Bootloader
*)

IMPORT
	Commands, Files, Streams, Strings,
	CryptoHashes, CryptoUtils,
	TFTPServer,
	BlCommands;

CONST
	ArgError * = 1;
	ExecError * = 2;

TYPE
	Resource = POINTER TO RECORD
		file, resource: ARRAY 256 OF CHAR;
		next: Resource
	END;

VAR
	session: BlCommands.Session;
	resources: Resource;

	(** StartSession (ip address | 'UART') *)
	PROCEDURE StartSession * (context: Commands.Context);
	VAR
		udp: BlCommands.UdpSession;
		uart: BlCommands.UartSession;
		arg: ARRAY 32 OF CHAR;
		uartPort: SIGNED32;
	BEGIN
		IF context.arg.GetString(arg) THEN
			IF arg = 'UART' THEN
				IF ~context.arg.GetInteger(uartPort, FALSE) THEN
					context.error.String("Error: expected COM port number");
					context.error.Ln;
					context.result := 1;
					RETURN
				END;
				NEW(uart, uartPort);
				session := uart;
				context.out.String("Session established");
				context.out.Ln
			ELSE
				TFTPServer.Stop;
				NEW(udp, arg);
				IF udp # NIL THEN
					TRACE(udp);
					session := udp;
					resources := NIL;
					context.out.String("Session established");
					context.out.Ln
				ELSE
					context.error.String("Error: invalid IP address");
					context.error.Ln;
					context.result := ArgError
				END
			END
		ELSE
			context.error.String("Error: expected IP address or 'UART'");
			context.error.Ln;
			context.result := ArgError
		END
	END StartSession;

	PROCEDURE StopSession * (context : Commands.Context);
	BEGIN
		session.Close;
		context.out.String("Session stopped");
		context.out.Ln
	END StopSession;

	(** Load filename resourcename ~ *)
	PROCEDURE Load * (context : Commands.Context);
	VAR
		file, resource: ARRAY 256 OF CHAR;
		r: Resource;
	BEGIN
		IF session = NIL THEN
			context.error.String("Error: no session started yet. Please call BlTools.SelectBoard first");
			context.error.Ln;
			RETURN
		END;

		IF context.arg.GetString(file) THEN
			IF context.arg.GetString(resource) THEN
				IF session.Load(file, resource) THEN
					context.out.String(resource);
					NEW(r);
					COPY(file, r.file);
					COPY(resource, r.resource);
					r.next := resources;
					resources := r;
					context.out.String(" loaded");
					context.out.Ln
				ELSE
					context.error.String(session.ack);
					context.error.Ln;
					context.result := ExecError
				END
			ELSE
				context.error.String("Error: expected resource name");
				context.error.Ln;
				context.result := ArgError
			END
		ELSE
			context.error.String("Error: expected file name");
			context.error.Ln;
			context.result := ArgError
		END
	END Load;

	(** Program resource destination [options] ~ *)
	PROCEDURE Program * (context : Commands.Context);
	VAR
		resource, dest: ARRAY 256 OF CHAR;
		mem: BlCommands.MemoryDest;
		zfpga: BlCommands.ZynqFpgaDest;
		file: BlCommands.FileDest;
		i: SIGNED32;
	BEGIN
		IF context.arg.GetString(resource) THEN
			IF context.arg.GetString(dest) THEN
				IF dest = "ZynqFpga" THEN
					IF session.Program(resource, zfpga) THEN
						context.out.String("Programming FPGA done");
						context.out.Ln
					ELSE
						context.error.String(session.ack);
						context.error.Ln;
						context.result := ExecError
					END
				ELSIF dest = "memory" THEN
					IF context.arg.GetInteger(mem.address, TRUE) THEN
						WHILE context.arg.GetInteger(i, TRUE) DO INCL(mem.cpus, i) END;
						IF session.Program(resource, mem) THEN
							context.out.String("Programming ARM done");
							context.out.Ln
						ELSE
							context.error.String(session.ack);
							context.error.Ln;
							context.result := ExecError
						END
					ELSE
						context.error.String("Error: expected load address");
						context.error.Ln;
						context.result := ArgError
					END
				ELSIF dest = "file" THEN
					IF context.arg.GetString(file.name) THEN
						IF session.Program(resource, file) THEN
							context.out.String("Programming file done");
							context.out.Ln
						ELSE
							context.error.String(session.ack);
							context.error.Ln;
							context.result := ExecError
						END
					ELSE
						context.error.String("Error: expected file name");
						context.error.Ln;
						context.result := ArgError
					END
				ELSE
					context.error.String("Error: unknown destination '");
					context.error.String(dest);
					context.error.String("'.");
					context.error.Ln;
					context.result := ArgError
				END
			ELSE
				context.error.String("Error: expected destination");
				context.error.Ln;
				context.result := ArgError
			END
		ELSE
			context.error.String("Error: expected resource name");
			context.error.Ln;
			context.result := ArgError
		END
	END Program;

	(** Check resource algorithm *)
	PROCEDURE Check * (context : Commands.Context);
	VAR
		buffer: ARRAY 1024 OF CHAR;
		reference, resource: ARRAY 256 OF CHAR;
		algorithm, hashName: ARRAY 32 OF CHAR;
		hash: CryptoHashes.Hash;
		file: Files.File;
		reader: Files.Reader;
		r: Resource;
		len: SIZE;
	BEGIN
		IF context.arg.GetString(resource) THEN
			IF context.arg.GetString(algorithm) THEN
				(* Get hash object *)
				hashName := "Crypto";
				Strings.Append(hashName, algorithm);
				hash := CryptoHashes.NewHash(hashName);
				IF hash = NIL THEN
					context.error.String("Error: unknown hash algorithm: ");
					context.error.String(algorithm);
					context.error.String(' (module ');
					context.error.String(hashName);
					context.error.String(' not found)');
					context.error.Ln;
					context.result := ArgError;
					RETURN
				END;

				(* Get & read file *)
				r := resources;
				WHILE (r # NIL) & (r.resource # resource) DO r := r.next END;
				IF r = NIL THEN
					context.error.String("Error: could not find the resource: ");
					context.error.String(resource);
					context.error.Ln;
					context.result := ArgError;
					RETURN
				END;
				file := Files.Old(r.file);
				IF file = NIL THEN
					context.error.String("Error: could not open file ");
					context.error.String(r.file);
					context.error.Ln;
					context.result := ArgError;
					RETURN
				END;
				Files.OpenReader(reader, file, 0);
				IF reader = NIL THEN
					context.error.String("Error: could not read file ");
					context.error.String(r.file);
					context.error.Ln;
					context.result := ArgError;
					RETURN
				END;

				hash.Initialize;
				WHILE reader.res = Streams.Ok DO
					reader.Bytes(buffer, 0, LEN(buffer), len);
					hash.Update(buffer, 0, len)
				END;
				hash.GetHash(buffer, 0);
				CryptoUtils.Bin2Hex(buffer, 0, reference, 0, hash.size);

				(* Send command *)
				IF session.Check(resource, algorithm, reference) THEN
					context.out.String("Hash check succeeded");
					context.out.Ln
				ELSE
					context.error.String(session.ack);
					context.error.Ln;
					context.result := ExecError
				END
			ELSE
				context.error.String("Error: expected algorithm name");
				context.error.Ln;
				context.result := ArgError
			END
		ELSE
			context.error.String("Error: expected resource name");
			context.error.Ln;
			context.result := ArgError
		END
	END Check;

	PROCEDURE Save * (context: Commands.Context);
	VAR
		resource: ARRAY 256 OF CHAR;
	BEGIN
		IF ~context.arg.GetString(resource) THEN
			context.error.String("Error: expected resource name");
			context.error.Ln;
			context.result := ArgError;
			RETURN
		END;

		IF session.Save(resource) THEN
			context.out.String("Resource saved");
			context.out.Ln;
		ELSE
			context.error.String(session.ack);
			context.error.Ln;
			context.result := ExecError
		END;
	END Save;

	PROCEDURE Start * (context : Commands.Context);
	BEGIN
		IF session.Start() THEN
			context.out.String("Application started");
			context.out.Ln
		ELSE
			context.error.String(session.ack);
			context.error.Ln;
			context.result := ExecError
		END
	END Start;

	PROCEDURE Mount * (context: Commands.Context);
	VAR
		prefix, disk: ARRAY 128 OF CHAR;
		partition: SIGNED32;
	BEGIN
		IF ~context.arg.GetString(prefix) THEN
			context.error.String("Error: expected prefix");
			context.error.Ln;
			context.result := ExecError;
			RETURN
		END;
		IF ~context.arg.GetString(disk) THEN
			context.error.String("Error: expected disk name");
			context.error.Ln;
			context.result := ExecError;
			RETURN
		END;
		IF ~context.arg.GetInteger(partition, FALSE) THEN
			context.error.String("Error: expected partition id");
			context.error.Ln;
			context.result := ExecError;
			RETURN
		END;

		IF session.Mount(prefix, disk, partition) THEN
			context.out.String(disk);
			context.out.Char('#');
			context.out.Int(partition, 0);
			context.out.String(" mounted as ");
			context.out.String(prefix);
			context.out.Ln
		ELSE
			context.error.String(session.ack);
			context.error.Ln;
			context.result := ExecError
		END
	END Mount;

	(** SetSource protocol [options] ~ *)
	PROCEDURE SetSource * (context : Commands.Context);
	VAR
		protocol: ARRAY 32 OF CHAR;
		tftp: BlCommands.TftpSource;
	BEGIN
		IF session = NIL THEN
			context.error.String("Error: no session started yet. Please call BlTools.SelectBoard first");
			context.error.Ln;
			RETURN
		END;

		IF context.arg.GetString(protocol) THEN
			IF protocol = "TFTP" THEN
				IF context.arg.GetString(tftp.host) THEN
					IF session.SetSource(tftp) THEN
						TFTPServer.Start;
						context.out.String("Data source set");
						context.out.Ln
					ELSE
						context.error.String(session.ack);
						context.error.Ln;
						context.result := ExecError
					END
				ELSE
					context.error.String("Error: expected hostname");
					context.error.Ln;
					context.result := ArgError
				END
			ELSE
				context.error.String("Error: unknown protocol '");
				context.error.String(protocol);
				context.error.String("'.");
				context.error.Ln;
				context.result := ArgError
			END
		ELSE
			context.error.String("Error: expected protocol name");
			context.error.Ln;
			context.result := ArgError
		END
	END SetSource;

	(* SetInput (UDP|UART|file) ~ *)
	PROCEDURE SetInput*(context : Commands.Context);
	VAR
		input: ARRAY 256 OF CHAR;
	BEGIN
		IF context.arg.GetString(input) THEN
			IF session.SetInput(input) THEN
				context.out.String("Change input done");
				context.out.Ln
			ELSE
				context.out.String(session.ack);
				context.out.Ln;
				context.result := ExecError
			END
		ELSE
			context.out.String("Error: expected input");
			context.out.Ln;
			context.result := ArgError
		END
	END SetInput;

	PROCEDURE Timeout*(context: Commands.Context);
	VAR
		time: SIGNED32;
	BEGIN
		IF context.arg.GetInteger(time, FALSE) THEN
			IF session.SetTimeout(time) THEN
				context.out.String("Timeout set");
				context.out.Ln
			ELSE
				context.out.String(session.ack);
				context.out.Ln;
				context.result := ExecError
			END
		ELSE
			context.out.String("Error: Expected timeout value");
			context.out.Ln
		END
	END Timeout;

	PROCEDURE Reset * (context: Commands.Context);
	BEGIN
		IF session.Reset() THEN
			context.out.String("Bootloader reset");
			context.out.Ln
		ELSE
			context.error.String(session.ack);
			context.error.Ln;
			context.result := ExecError
		END
	END Reset;

	PROCEDURE Command * (context: Commands.Context);
	VAR
		cmd: ARRAY 1024 OF CHAR;
		len: SIZE;
	BEGIN
		context.arg.Bytes(cmd, 0, context.arg.Available(), len);
		IF session.ExecuteCommand(cmd) THEN
			context.out.String("Command ");
			context.out.String(cmd);
			context.out.String(" successful");
			context.out.Ln
		ELSE
			context.out.String(session.ack);
			context.out.Ln;
			context.result := ExecError
		END
	END Command;

	PROCEDURE Deploy * (context : Commands.Context);
	BEGIN
		
	END Deploy;
END BlTools.
TFTPServer.Start
SystemTools.DoCommands
	BlTools.StartSession 10.3.34.8 ~
	BlTools.SetSource TFTP 10.3.34.145 ~

	BlTools.Load TestFifo.bin bs ~
	BlTools.Check bs MD5 ~
	BlTools.Program bs ZynqFpga ~

	BlTools.Load A2.Bin a2 ~
	BlTools.Check a2 MD5 ~
	BlTools.Program a2 memory 100000H 0 1 ~
	BlTools.Program a3 ZynqFpga ~
	BlTools.Start ~
	BlTools.StopSession ~
~
SystemTools.DoCommands
	BlTools.StartSession 10.3.34.8 ~
	BlTools.SetSource TFTP 10.3.34.145 ~
	BlTools.Load A2.Bin a2 ~
	BlTools.Check a2 MD5 ~
	BlTools.Program a2 memory 100000H 0 1 ~
	BlTools.Start ~
	BlTools.StopSession ~
~
BlTools.SetInput UART ~

SystemTools.DoCommands
	BlTools.StartSession 10.3.34.8 ~
	BlTools.SetSource TFTP 10.3.34.145 ~
	BlTools.Timeout 1 ~
	BlTools.StopSession ~
~
