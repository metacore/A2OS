MODULE ShellSerial; (** AUTHOR "staubesv/be" PURPOSE "Serial port utilities for shell"; *)
(**
 * Note: Based on code of "be"
 *
 * Usage:
 *
 *	ShellSerial.Open [portNbr BitsPerSecond DataBits Parity StopBits] ~ opens a shell listening to serial port <portNbr>
 *
 *	ShellSerial.YReceive [[filename] portNbr BitsPerSecond DataBits Parity StopBits Prompt] ~
 *	ShellSerial.XReceive [[filename] portNbr BitsPerSecond DataBits Parity StopBits Prompt] ~
 *
 *	Whereas
 *		Parity = "odd"|"even"|"mark"|"space"|"no"
 *		StopBits = "1"|"1.5"|"2"
 *
 * Examples:
 *
 *	ShellSerial.Open 1 115200 no 1 8 ~
 *	ShellSerial.YReceive ~
 *	ShellSerial.XReceive ~
 *
 * History:
 *
 *	25.06.2007	First release (staubesv)
 *)

IMPORT
	Modules, Kernel, Commands, Streams, (*Strings,*) Files, Serials, Shell, Objects, XYModem;

CONST
	BufferSize = 1024;

	DefaultPrompt = "SHELL>";

VAR
	shells : ARRAY Serials.MaxPorts + 1 OF Shell.Shell;

PROCEDURE Yield(): BOOLEAN;
BEGIN
	Objects.Yield();
	RETURN TRUE;
END Yield;

PROCEDURE ModemReceive(context : Commands.Context; modemMode: SIGNED32); (** [[filename] portNbr BitsPerSecond DataBits Parity StopBits] ~ *)
VAR
	fileName : Files.FileName;
	length: SIGNED32;
	port : Serials.Port; portNbr, bps, data, parity, stop: SIGNED32; res : INTEGER;
	isOpen0 : BOOLEAN;
	bps0, data0, parity0, stop0 : SIGNED32;
	w : Streams.Writer; r : Streams.Reader;
	isTracePort: BOOLEAN;
	params: SET;
	i, receiveRes: SIGNED32;
BEGIN
	IF ~context.arg.GetString(fileName) & (modemMode # XYModem.YModem) THEN
		context.result := Commands.CommandParseError;
		context.error.String("file name is missing"); context.error.Ln;
		RETURN;
	END;

	context.arg.SkipWhitespace;
	IF context.arg.Available() # 0 THEN (* port settings are specified *)
		Serials.GetPortParameters(context.arg, portNbr, bps, data, parity, stop, params, res);
		IF res # 0 THEN
			context.result := Commands.CommandParseError;
			context.error.String("Invalid port settings, res="); context.error.Int(res,0); context.error.Ln;
			RETURN;
		END;
	ELSE
		(*
			if the command context is the same as the context of the currently executed command of a shell
			take that shell port as the port used for data transmission
		*)
		i := 0;
		WHILE (i < LEN(shells)) & ((shells[i] = NIL) OR ~shells[i].IsCurrentCmdContext(context)) DO
			INC(i);
		END;

		IF i < LEN(shells) THEN
			portNbr := i+1;
			bps := -1;
		ELSE
			context.result := Commands.CommandError;
			context.error.String("port number is not specified"); context.error.Ln;
			RETURN;
		END;
	END;

	port := Serials.GetPort(portNbr);
	IF port = NIL THEN
		context.result := Commands.CommandError;
		context.error.String("Cannot find port "); context.error.Int(portNbr, 0); context.error.Ln;
		RETURN;
	END;

	port.GetPortState(isOpen0, bps0, data0, parity0, stop0);
	IF bps = -1 THEN (* using port of a shell *)
		bps := bps0; data := data0; parity := parity0; stop := stop0;
	END;

	(* disable tracing over the selected port *)
	IF Serials.IsTracePort(port) THEN
		isTracePort := TRUE;
		Serials.SetTracePort(0,0,0,0,0, res);
	END;

	port.Close;
	port.Open(bps, data, parity, stop, res);
	IF res # Serials.Ok THEN

		context.result := Commands.CommandError;
		context.error.String("Could not open port "); context.error.Int(portNbr, 0);
		context.error.String(", res="); context.error.Int(res,0);
		context.error.Ln;

		IF isTracePort THEN
			Serials.SetTracePort(portNbr, bps0, data0, parity0, stop0, res);
		ELSIF isOpen0 THEN
			port.Open(bps0, data0, parity0, stop0, res);
		END;

		RETURN;
	END;

	NEW(w, port.Send, 4096); NEW(r, port.Receive, 4096);

	XYModem.Receive(r,w,fileName,modemMode,15000,5000,length,Yield,receiveRes);

	port.Close();

	IF isTracePort THEN
		Serials.SetTracePort(portNbr, bps0, data0, parity0, stop0, res);
		IF res # Serials.Ok THEN
			context.error.String("Warning: could not re-activate trace over port "); context.error.Int(portNbr, 0);
			context.error.String(", res="); context.error.Int(res,0);
			context.error.Ln;
		END;
	ELSIF isOpen0 THEN
		port.Open(bps0, data0, parity0, stop0, res);
		IF res # Serials.Ok THEN
			context.error.String("Warning: could not re-open port "); context.error.Int(portNbr, 0);
			context.error.String(", res="); context.error.Int(res,0);
			context.error.Ln;
		END;
	END;

	Wait(1000); (* Give the port open time so we see the output below *)

	IF receiveRes = 0 THEN
		context.out.String("  "); context.out.String(fileName);
		context.out.String(" ("); context.out.Int(length, 0); context.out.String(" Bytes"); context.out.String(")");

		context.out.String(" done.");
		context.out.Ln;
	ELSE
		context.result := Commands.CommandError;
		context.error.String("error "); context.error.Int(receiveRes,0); context.error.Ln;
	END;
END ModemReceive;

(** Receive a file using X-modem protocol *)
PROCEDURE XReceive*(context : Commands.Context); (** [[filename] portNbr BitsPerSecond DataBits Parity StopBits] ~ *)
BEGIN
	ModemReceive(context,XYModem.XModem);
END XReceive;

(** Receive a file using Y-modem protocol *)
PROCEDURE YReceive*(context : Commands.Context); (** [[filename] portNbr BitsPerSecond DataBits Parity StopBits] ~ *)
BEGIN
	ModemReceive(context,XYModem.YModem);
END YReceive;

(*PROCEDURE IsDigit(ch: CHAR): BOOLEAN;
BEGIN
	RETURN (ch >= "0") & (ch <= "9")
END IsDigit;*)

PROCEDURE Wait(ms: SIGNED32);
VAR timer: Kernel.Timer;
BEGIN
	NEW(timer); timer.Sleep(ms);
END Wait;

(** Open a shell listening on the specified <portNbr> *)
PROCEDURE Open*(context : Commands.Context); (** [portNbr BitsPerSecond DataBits Parity StopBits Prompt] ~ *)
VAR
	port : Serials.Port; portNbr, bps, data, parity, stop: SIGNED32; res : INTEGER;
	prompt: ARRAY 32 OF CHAR;
	w : Streams.Writer; r : Streams.Reader;
	params: SET;
BEGIN {EXCLUSIVE}
	Serials.GetPortParameters(context.arg, portNbr, bps, data, parity, stop, params, res);
	IF res # 0 THEN
		context.result := Commands.CommandError;
		context.error.String("Invalid port settings, res="); context.error.Int(res,0); context.error.Ln;
		RETURN;
	END;

	IF ~context.arg.GetString(prompt) THEN prompt := DefaultPrompt; END;

	port := Serials.GetPort(portNbr);
	IF port # NIL THEN
		port.Close;
		IF shells[portNbr-1] # NIL THEN
			shells[portNbr-1].Exit;
			(*! avoid dead-lock if this command is issued by shells[portNbr-1] *)
			IF ~shells[portNbr-1].IsCurrentCmdContext(context) THEN
				shells[portNbr-1].AwaitDeath;
			END;
			shells[portNbr-1] := NIL;
		END;
		port.Open(bps, data, parity, stop, res);
		IF (res = Serials.Ok) THEN
			NEW(w, port.Send, BufferSize); NEW(r, port.Receive, BufferSize);
			NEW(shells[portNbr-1], r, w, w, TRUE, prompt);
		ELSE
			context.error.String("Shell: could not open port "); context.error.Int(portNbr, 0);
			context.error.String(", res: "); context.error.Int(res, 0); context.error.Ln;
		END;
	ELSE
		context.error.String("Shell: serial port "); context.error.Int(portNbr, 0); context.error.String(" not found."); context.error.Ln;
	END;
END Open;

PROCEDURE Cleanup;
VAR
	port : Serials.Port;
	i: SIGNED32; res : INTEGER;
	isOpen0, isTracePort : BOOLEAN;
	bps0, data0, parity0, stop0 : SIGNED32;
BEGIN
	FOR i := 0 TO LEN(shells)-1 DO
		IF (shells[i] # NIL) THEN
			port := Serials.GetPort(i+1);
			isTracePort := Serials.IsTracePort(port);
			IF port # NIL THEN
				port.GetPortState(isOpen0, bps0, data0, parity0, stop0);
				port.Close;
			END;
			shells[i].Exit;
			(*shells[i].AwaitDeath;*)
			shells[i] := NIL;
			IF isTracePort THEN
				Serials.SetTracePort(i+1, bps0, data0, parity0, stop0, res);
			END;
		END;
	END;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END ShellSerial.
