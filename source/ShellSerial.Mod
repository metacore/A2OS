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
	Modules, Kernel, Commands, Streams, (*Strings,*) Files, Serials, Shell, XYModem;

CONST
	BufferSize = 1024;

	DefaultPrompt = "SHELL>";

VAR
	shells : ARRAY Serials.MaxPorts + 1 OF Shell.Shell;

PROCEDURE ModemReceive(context : Commands.Context; modemMode: LONGINT); (** [[filename] portNbr BitsPerSecond DataBits Parity StopBits] ~ *)
VAR
	name : Files.FileName; file : Files.File;
	port : Serials.Port; portNbr, bps, data, parity, stop, res : LONGINT; params: SET;
	isOpen0 : BOOLEAN;
	bps0, data0, parity0, stop0 : LONGINT;
	recv : XYModem.Receiver; awaitF : BOOLEAN;
	w : Streams.Writer; r : Streams.Reader;
	error: ARRAY 64 OF CHAR;
	isTracePort: BOOLEAN;
BEGIN
	IF ~context.arg.GetString(name) THEN
		context.result := 1;
		context.error.String("Invalid port settings, res="); context.error.Int(res,0); context.error.Ln;
		RETURN;
	END;
	
	Serials.GetPortParameters(context.arg, portNbr, bps, data, parity, stop, params, res);
	IF res # 0 THEN
		context.result := 2;
		context.error.String("Invalid port settings, res="); context.error.Int(res,0); context.error.Ln;
		RETURN;
	END;

	port := Serials.GetPort(portNbr);
	IF port = NIL THEN
		context.result := 3;
		context.error.String("Cannot find port "); context.error.Int(portNbr, 0); context.error.Ln;
		RETURN;
	END;

	port.GetPortState(isOpen0, bps0, data0, parity0, stop0);

	(* disable tracing over the selected port *)
	IF Serials.IsTracePort(port) THEN
		isTracePort := TRUE;
		Serials.SetTracePort(-1,0,0,0,0, res);
	END;

	port.Close;
	port.Open(bps, data, parity, stop, res);
	IF res # Serials.Ok THEN
		
		context.result := 4;
		
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

	IF (modemMode = XYModem.XModem) OR (modemMode = XYModem.XModem1K) THEN
		context.out.String("XReceive ");
	ELSE
		context.out.String("YReceive ");
	END;

	context.out.String(name); context.out.Ln;
	IF name # "" THEN
		file := Files.New(name); awaitF := FALSE
	ELSE
		file := NIL; awaitF := TRUE
	END;

	NEW(w, port.Send, BufferSize); NEW(r, port.Receive, BufferSize);
	NEW(recv, w, r, file, modemMode);
	IF ~awaitF THEN
		recv.Await(error)
	ELSE
		recv.AwaitF(file, error)
	END;

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

	IF error # "" THEN
		context.result := 5;
		context.error.String(" "); context.error.String(error)
	ELSE
		Files.Register(file);
		IF awaitF THEN
			file.GetName(name);
			context.out.String("  "); context.out.String(name);
			context.out.String(" ("); context.out.Int(file.Length(), 0); context.out.String(" Bytes"); context.out.String(")");
		END;
		context.out.String(" done.");
		context.out.Ln;
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

PROCEDURE Wait(ms: LONGINT);
VAR timer: Kernel.Timer;
BEGIN
	NEW(timer); timer.Sleep(ms);
END Wait;

(*PROCEDURE GetSerialPortParameters(context : Commands.Context; VAR port, bps, data, parity, stop: LONGINT): BOOLEAN;
VAR str : ARRAY 32 OF CHAR;
BEGIN
	bps := DefaultBPS; data := DefaultDataBits; parity := DefaultParity; stop := DefaultStop;

	IF ~context.arg.GetInteger(port,FALSE) THEN
		context.result := 1;
		context.error.String("port number not specified"); context.error.Ln();
		RETURN FALSE
	END;

	IF (port < 1) OR (port > Serials.MaxPorts) THEN
		context.result := 2;
		context.error.String("wrong port number"); context.error.Ln();
		RETURN FALSE
	END;

	IF ~context.arg.GetInteger(bps, FALSE) THEN
		RETURN TRUE;
	END;

	IF ~context.arg.GetInteger(data, FALSE) THEN
		RETURN TRUE;
	END;

	IF ~context.arg.GetString(str) THEN
		RETURN TRUE;
	END;

	IF str = "odd" THEN
		parity := Serials.ParOdd
	ELSIF str = "even" THEN
		parity := Serials.ParEven
	ELSIF str = "mark" THEN
		parity := Serials.ParMark
	ELSIF str = "space" THEN
		parity := Serials.ParSpace
	ELSIF str # "no" THEN
		context.result := 3;
		context.error.String("wrong parity"); context.error.Ln();
		RETURN FALSE
	END;

	IF ~context.arg.GetString(str) THEN
		RETURN TRUE;
	END;

	IF str = "1.5" THEN
		stop := Serials.Stop1dot5
	ELSIF str = "2" THEN
		stop := Serials.Stop2
	ELSIF str # "1" THEN
		context.result := 4;
		context.error.String("wrong stop bits"); context.error.Ln();
		RETURN FALSE
	END;

	RETURN TRUE
END GetSerialPortParameters;*)

(** Open a shell listening on the specified <portNbr> *)
PROCEDURE Open*(context : Commands.Context); (** [portNbr BitsPerSecond DataBits Parity StopBits Prompt] ~ *)
VAR
	port : Serials.Port; portNbr, bps, data, parity, stop, res : LONGINT; params: SET;
	prompt: ARRAY 32 OF CHAR;
	w : Streams.Writer; r : Streams.Reader;
BEGIN {EXCLUSIVE}
	Serials.GetPortParameters(context.arg, portNbr, bps, data, parity, stop, params, res);
	IF res # 0 THEN
		context.result := 1;
		context.error.String("Invalid port settings, res="); context.error.Int(res,0); context.error.Ln;
		RETURN;
	END;

	port := Serials.GetPort(portNbr);
	IF port # NIL THEN
		IF shells[portNbr-1] # NIL THEN
			shells[portNbr-1].Exit; shells[portNbr-1].AwaitDeath;
			shells[portNbr-1] := NIL;
			port.Close;
		END;
		port.Open(bps, data, parity, stop, res);
		IF (res = Serials.Ok) THEN
			NEW(w, port.Send, BufferSize); NEW(r, port.Receive, BufferSize);
			IF ~context.arg.GetString(prompt) THEN prompt := DefaultPrompt; END;
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
	i, res : LONGINT;
	isOpen0, isTracePort : BOOLEAN;
	bps0, data0, parity0, stop0 : LONGINT;
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
