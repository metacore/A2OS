MODULE SdInspect; (** AUTHOR ""; PURPOSE ""; *)

IMPORT
	BootConfig, Commands, KernelLog, Options,
	Sd;

VAR
	hc: Sd.HostController;
	card: Sd.Card;
	result: LONGINT;

	(** SdInspect.Command [-a|--acmd] [-d|--data] [-r|--read] [--auto12] [--auto23] [-m|-multi] [-c|--count] [--dma] cmd arg resp rca [datalen] ~ *)
	PROCEDURE Command * (context: Commands.Context);
	VAR
		rsp: ARRAY 32 OF CHAR;
		opt: Options.Options;
		command: Sd.Command;
		datalen, rca: LONGINT;
		data: POINTER TO ARRAY OF CHAR;
	BEGIN
		NEW(opt);
		opt.Add('d', "data", Options.Flag);
		opt.Add('r', "read", Options.Flag);
		opt.Add(0X, "auto12", Options.Flag);
		opt.Add(0X, "auto23", Options.Flag);
		opt.Add('m', "multi", Options.Flag);
		opt.Add('c', "count", Options.Flag);
		opt.Add(0X, "dma", Options.Flag);
		opt.Add('a', "acmd", Options.Flag);
		IF ~opt.Parse(context.arg, context.error) THEN RETURN END;

		command.hc := hc;
		IF context.arg.GetInteger(command.command, FALSE) THEN
			IF context.arg.GetInteger(command.argument, TRUE) THEN
				IF context.arg.GetString(rsp) THEN
					IF rsp = "R1" THEN
						command.responseType := Sd.ResponseR1
					ELSIF rsp = "R1b" THEN
						command.responseType := Sd.ResponseR1b
					ELSIF rsp = "R2" THEN
						command.responseType := Sd.ResponseR2
					ELSIF rsp = "R3" THEN
						command.responseType := Sd.ResponseR3
					ELSIF rsp = "R4" THEN
						command.responseType := Sd.ResponseR4
					ELSIF rsp = "R5" THEN
						command.responseType := Sd.ResponseR5
					ELSIF rsp = "R6" THEN
						command.responseType := Sd.ResponseR6
					ELSIF rsp = "R7" THEN
						command.responseType := Sd.ResponseR7
					ELSE
						context.error.String("Unknown response type ");
						context.error.String(rsp);
						context.error.Ln;
						RETURN
					END;

					IF context.arg.GetInteger(command.rca, TRUE) THEN
						(* flags *)
						IF opt.GetFlag("read") THEN INCL(command.flags, Sd.FlagRead) END;
						IF opt.GetFlag("auto12") THEN INCL(command.flags, Sd.FlagAutoCmd12) END;
						IF opt.GetFlag("auto23") THEN INCL(command.flags, Sd.FlagAutoCmd23) END;
						IF opt.GetFlag("multi") THEN INCL(command.flags, Sd.FlagMultipleBlockTx) END;
						IF opt.GetFlag("count") THEN INCL(command.flags, Sd.FlagCountBlocks) END;
						IF opt.GetFlag("dma") THEN INCL(command.flags, Sd.FlagUseDma) END;
						IF opt.GetFlag("acmd") THEN INCL(command.flags, Sd.FlagApplicationCmd) END;
						IF opt.GetFlag("data") THEN
							INCL(command.flags, Sd.FlagData);
							IF context.arg.GetInteger(datalen, TRUE) THEN
								NEW(data, datalen);
								IF hc.execute(command, data^, 0, datalen, result) THEN
									context.out.String("Command successful");
									context.out.Ln;
									context.out.Update;
									IF Sd.FlagRead IN command.flags THEN
										KernelLog.String("Data:");
										KernelLog.Ln;
										KernelLog.Buffer(data^, 0, datalen)
									END
								ELSE
									context.out.String("Command failed: ");
									context.out.Int(result, 0);
									context.out.Ln
								END
							ELSE
								context.error.String("Expected data length");
								context.error.Ln
							END
						ELSE
							IF Sd.ExecuteCommand(command, result) THEN
								context.out.String("Command successful");
								context.out.Ln
							ELSE
								context.out.String("Command failed: ");
								context.out.Int(result, 0);
								context.out.Ln
							END
						END;

						context.out.String("Response: ");
						CASE command.responseType OF
							 Sd.ResponseR1, Sd.ResponseR1b:
								context.out.Update;
								Sd.PrintCardStatus(Sd.GetR1(command))
							|Sd.ResponseR2:
								context.out.Hex(command.response[0], -8);
								context.out.Char(' ');
								context.out.Hex(command.response[1], -8);
								context.out.Char(' ');
								context.out.Hex(command.response[2], -8);
								context.out.Char(' ');
								context.out.Hex(command.response[3], -8);
								context.out.Char(' ')
							|Sd.ResponseR3: context.out.Hex(Sd.GetR3(command), -8)
							|Sd.ResponseR4: context.out.Hex(Sd.GetR4(command), -8)
							|Sd.ResponseR5: context.out.Hex(Sd.GetR5(command), -8)
							|Sd.ResponseR6: context.out.Hex(Sd.GetR6(command), -8)
							|Sd.ResponseR7: context.out.Hex(Sd.GetR7(command), -8)
						END;
						context.out.Ln
					ELSE
						context.error.String("Expected RCA");
						context.error.Ln
					END
				ELSE
					context.error.String("Expected response type");
					context.error.Ln
				END
			ELSE
				context.error.String("Expected argument number");
				context.error.Ln
			END
		ELSE
			context.error.String("Expected cmd number");
			context.error.Ln
		END
	END Command;

	PROCEDURE Read *;
	VAR
		data: ARRAY 512 OF CHAR;
		res: LONGINT;
	BEGIN
		IF ~Sd.Read(card, 0, 512, data, 0, res) THEN
			KernelLog.String("Read Failed: ");
			KernelLog.Int(res, 0);
			KernelLog.Ln
		ELSE
			KernelLog.String("Read succeeded");
			KernelLog.Ln;
			KernelLog.Buffer(data, 0, 512)
		END
	END Read;

	PROCEDURE Reads *;
	CONST
		Size = 1024 * 1024;
	VAR
		data: ARRAY Size OF CHAR;
		res: LONGINT;
	BEGIN
		IF ~Sd.Read(card, 0, Size, data, 0, res) THEN
			KernelLog.String("Read Failed: ");
			KernelLog.Int(res, 0);
			KernelLog.Ln
		ELSE
			KernelLog.String("Read succeeded");
			KernelLog.Ln;
			KernelLog.Buffer(data, 0, 512)
		END
	END Reads;

	PROCEDURE Write *;
	VAR
		data: ARRAY 512 OF CHAR;
		res: LONGINT;
	BEGIN
		IF ~Sd.Write(card, 0, 512, data, 0, res) THEN
			KernelLog.String("Write Failed: ");
			KernelLog.Int(res, 0);
			KernelLog.Ln
		ELSE
			KernelLog.String("Write succeeded");
			KernelLog.Ln;
			KernelLog.Buffer(data, 0, 512)
		END
	END Write;

	PROCEDURE Writes *;
	VAR
		data: ARRAY 8 * 512 OF CHAR;
		res: LONGINT;
	BEGIN
		IF ~Sd.Write(card, 0, 8 * 512, data, 0, res) THEN
			KernelLog.String("Write Failed: ");
			KernelLog.Int(res, 0);
			KernelLog.Ln
		ELSE
			KernelLog.String("Write succeeded");
			KernelLog.Ln;
			KernelLog.Buffer(data, 0, 512)
		END
	END Writes;

	PROCEDURE Test *;
	VAR
		command: Sd.Command;
		res: LONGINT;
	BEGIN
		command.hc := hc;
		command.rca := 7;
		command.command := Sd.CMD_SELECT_DESELECT_CARD;
		command.argument := 70000H;
		command.responseType := Sd.ResponseR1b;
		TRACE(Sd.ExecuteCommand(command, res));
		TRACE(res)
	END Test;

BEGIN
	hc := Sd.New(ADDRESS(0E0100000H), BootConfig.GetIntValue("PsRefClockHz"), NIL, NIL);
	NEW(card);
END SdInspect.
