MODULE Serials; (** AUTHOR "afi"; PURPOSE "Generic serial communication ports driver"; *)
(**
 * Designed to support serial communication via the conventional RS232-type serial communication ports COM1 to COM8 and
 * via a USB port with a USB to serial adapter. Hot plug-in of the device is possible. For that reason, devices  are registered/unregistered
 * by procedures located in this module.
 *
 * Usage:
 *
 *	Serials.Show ~	displays a list of all available serial ports
 *
 *	Serials.CloseAllPorts ~ forces closing all serials ports
 *
 * History:
 *
 *	20.01.2006	First Release (afi)
 *	14.06.2006	Fixed Port.Send, introduced result value for Port.SendChar, implemented termination handler, cleanup (staubesv)
 *	26.06.2006	Added charactersSent, characterReceived for tracking (staubesv)
 *	04.08.2006	Removed SetPortState from Port interface (staubesv)
 *)

IMPORT Streams, Modules, KernelLog, Commands, Machine, Trace;

CONST
	Verbose = TRUE;

	MaxPorts* = 64;

	(** Parity *)
	ParNo* = 0;  ParOdd* = 1;  ParEven* = 2;  ParMark* = 3;  ParSpace* = 4;

	(** Stop bits *)
	Stop1* = 1;  Stop2* = 2;  Stop1dot5* = 3;

	(* Serial port default settings *)
	DefaultBPS = 115200; DefaultDataBits = 8; DefaultParity = ParNo; DefaultStop = Stop1;

	(** Modem control lines *)
	DTR* = 0;  RTS* = 1;	(** output *)
	Break* = 2;	(** input/output - Bit 6 in LCR *)
	DSR* = 3;  CTS* = 4;  RI* = 5;  DCD* = 6;	(** input *)

	(** Receive error diagnostic *)
	OverrunError* = 10;
	ParityError* = 11;
	FramingError* = 12;
	BreakInterrupt* = 13;

	(** Error conditions *)
	Ok* =  0;
	Closed* = -1;
	TransportError* = -2;  (** Error on transport layer, e.g. USB error in RS-232 over USB *)
	TimeoutExpired* = -3; (** Timeout expired *)

	(** Errors for Port.Open procedure *)
	PortInUse* =  1; NoSuchPort* =  2; WrongBPS* =  3; WrongData* =  4; WrongParity* =  5; WrongStop* =  6;

TYPE

	Port* = OBJECT (Streams.Connection);
	VAR
		name- : ARRAY 6 OF CHAR;
		description- : ARRAY 128 OF CHAR;

		(** Characters sent/read since port has been opened. Consider these fields read-only! *)
		charactersSent*, charactersReceived* : LONGINT;

		PROCEDURE Open* (bps, data, parity, stop : LONGINT; VAR res: WORD);
		END Open;

		PROCEDURE Close* ;
		END Close;

		PROCEDURE SendChar* (ch: CHAR; VAR res : WORD);
		END SendChar;

		(** Send len characters from buf to output, starting at ofs. res is non-zero on error. *)
		PROCEDURE Send*(CONST buf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: WORD);
		VAR i : LONGINT;
		BEGIN
			i := 0;
			WHILE i < len DO
				SendChar(buf[ofs + i], res);
				IF res # Ok THEN RETURN END;
				INC(i)
			END
		END Send;

		PROCEDURE ReceiveChar* (VAR ch: CHAR; VAR res: WORD);
		END ReceiveChar;

		(** Receive size characters into buf, starting at ofs and return the effective number of bytes read in len.
			Wait until at least min bytes (possibly zero) are available. res is non-zero on error. *)
		PROCEDURE Receive*(VAR buf: ARRAY OF CHAR; ofs, size, min: LONGINT; VAR len, res: LONGINT);
		VAR ch: CHAR;
		BEGIN
			len := 0;
			res := Ok;
			WHILE (len < min) DO
				ReceiveChar(ch, res);
				IF res # Ok THEN RETURN END;
				buf[ofs + len] := ch;
				INC(len);
			END;
			WHILE (Available() > 0) & (len < size) DO
				ReceiveChar(ch, res);
				IF res # Ok THEN RETURN END;
				buf[ofs + len] := ch;
				INC(len)
			END;
		END Receive;

		PROCEDURE Available*(): LONGINT;
		END Available;

		(** Get the port state: state (open, closed), speed in bps, no. of data bits, parity, stop bit length. *)
		PROCEDURE GetPortState*(VAR openstat : BOOLEAN; VAR bps, data, parity, stop : LONGINT);
		END GetPortState;

		(** Clear the specified modem control lines.  s may contain DTR, RTS & Break. *)
		PROCEDURE ClearMC*(s: SET);
		END ClearMC;

		(** Set the specified modem control lines.  s may contain DTR, RTS & Break. *)
		PROCEDURE SetMC*(s: SET);
		END SetMC;

		(** Return the state of the specified modem control lines. s contains
			the current state of DSR, CTS, RI, DCD & Break Interrupt. *)
		PROCEDURE GetMC*(VAR s: SET);
		END GetMC;

		(** Setup receive timeout (maximum time allowed to elapse before arrival of the next data byte) in ms.
			Use timeout <= 0 to disable receive timeout handling  *)
		PROCEDURE SetReceiveTimeout*(timeout: LONGINT);
		END SetReceiveTimeout;

		PROCEDURE Show*;
		BEGIN
			KernelLog.String(name); KernelLog.String(" ("); KernelLog.String(description); KernelLog.String(")");
		END Show;

	END Port;

VAR
	(* 	In this array the RS232-type COM ports are registered in the first 8 array elements.
		USB ports equipped with a USB to serial adapter are registered in the next 8 array elements. *)
	ports : ARRAY MaxPorts OF Port;

	tracePort: Port;
	traceChar0: Trace.CharProc;

(** At the disposal of the USB driver modules for hot plug-in of a device. *)
PROCEDURE RegisterPort* (port : Port; CONST description : ARRAY OF CHAR);
VAR name : ARRAY 6 OF CHAR; portNumber : LONGINT;
BEGIN {EXCLUSIVE}
	ASSERT(port # NIL);
	portNumber := 9;
	WHILE (portNumber < LEN(ports)) & (ports[portNumber-1] # NIL) DO INC(portNumber); END;
	IF portNumber < LEN(ports) THEN
		ports[portNumber-1] := port;
		name := "COM";
		IF portNumber < 10 THEN
			name[3] := CHR(ORD("0") + portNumber);
		ELSE
			name[3] := CHR(ORD("0") + portNumber DIV 10);
			name[4] := CHR(ORD("0") + portNumber MOD 10);
		END;
		COPY(name, port.name);
		COPY(description, port.description);
		IF Verbose THEN KernelLog.String("Serials: "); port.Show; KernelLog.String(" is now available."); KernelLog.Ln; END;
	ELSE
		KernelLog.String("Serials: Could not register port: No free slots."); KernelLog.Ln;
	END;
END RegisterPort;

(** At the disposal of the USB driver modules for hot plug-in of a device. *)
PROCEDURE UnRegisterPort* (port : Port);
VAR i : LONGINT;
BEGIN {EXCLUSIVE}
	i := 0; WHILE (i < LEN(ports)) & (ports[i] # port) DO INC(i); END;
	IF i < LEN(ports) THEN
		ports[i].Close;
		ports[i] := NIL;
		IF Verbose THEN KernelLog.String("Serials: "); port.Show; KernelLog.String(" has been removed."); KernelLog.Ln; END;
	ELSE
		KernelLog.String("Serials: Warning: UnRegisterPort: Port not found."); KernelLog.Ln;
	END;
END UnRegisterPort;

(**	COM1 to COM8 are reserved for RS-232 / V24 communication ports. Other ports will be named COM9, COM9 and so on as needed.
	The idea is that the onboard COM ports get the same port numbers as in the BIOS *)
PROCEDURE RegisterOnboardPort*(portNumber : LONGINT; port : Port; CONST name, description : ARRAY OF CHAR);
BEGIN {EXCLUSIVE}
	IF (portNumber >= 1) & (portNumber <= LEN(ports)) & (ports[portNumber-1] = NIL) THEN
		ports[portNumber-1] := port;
		COPY(name, port.name);
		COPY(description, port.description);
		IF Verbose THEN KernelLog.String("Serials: "); port.Show; KernelLog.String(" is now available."); KernelLog.Ln; END;
	ELSE
		KernelLog.String("Serials: Warning; Could not register onboard port."); KernelLog.Ln;
	END;
END RegisterOnboardPort;

PROCEDURE GetPort* (portNumber : LONGINT) : Port;
VAR port : Port;
BEGIN {EXCLUSIVE}
	IF (portNumber >= 1) & (portNumber <= LEN(ports)) & (ports[portNumber-1] # NIL) THEN
		port := ports[portNumber-1];
	END;
	RETURN port;
END GetPort;

PROCEDURE TraceChar(ch: CHAR);
VAR res: WORD;
BEGIN
	IF tracePort # NIL THEN
		tracePort.SendChar(ch, res);
	END;
END TraceChar;

(**
	Setup serial port for kernel trace output

	portNumber: serial port number, or 0 to disable trace output, or a negative value for rolling back to the initial trace output configuration
	bps, data, parity, stop: serial port settings
*)
PROCEDURE SetTracePort*(portNumber: LONGINT; bps, data, parity, stop: LONGINT; VAR res: WORD);
VAR
	isOpen0: BOOLEAN;
	bps0, data0, parity0, stop0 : LONGINT;
	res1: LONGINT;
	port: Port;
BEGIN{EXCLUSIVE}
	res := 0;
	IF (portNumber >= 1) & (portNumber <= LEN(ports)) & (ports[portNumber-1] # NIL) THEN

		port := ports[portNumber-1];

		port.GetPortState(isOpen0, bps0, data0, parity0, stop0);

		(* do not close the port if the current port settings match *)
		IF ~isOpen0 OR (bps0 # bps) OR (data0 # data) OR (parity0 # parity) OR (stop0 # stop) THEN
			port.Close;
			port.Open(bps, data, parity, stop, res);
			IF res # 0 THEN
				IF isOpen0 THEN port.Open(bps0, data0, parity0, stop0, res1); END;
				RETURN;
			END;
		END;

		IF Trace.Char # TraceChar THEN
			traceChar0 := Trace.Char;
		END;
		tracePort := port;
		Trace.Char := TraceChar;

	ELSIF portNumber = 0 THEN
		tracePort := NIL;
		IF Trace.Char # TraceChar THEN
			traceChar0 := Trace.Char;
		END;
		Trace.Char := TraceChar;
	ELSIF portNumber < 0 THEN
		IF traceChar0 # NIL THEN
			Trace.Char := traceChar0;
			tracePort := NIL;
			traceChar0 := NIL;
		END;
	ELSE
		res := NoSuchPort;
	END;
END SetTracePort;

(** Returns TRUE if a given port is currently used for kernel trace output *)
PROCEDURE IsTracePort*(port: Port): BOOLEAN;
BEGIN
	RETURN (tracePort # NIL) & (port = tracePort);
END IsTracePort;

(**
	Get serial port parameters from an input stream

	The format of the stream is expected to be as [portNumber bps data parity stop] exactly in this predefined order;

	portNumber is obligatory parameter, the othe parameters are optional; if not specified they will be assigned to
	default values (DefaultBPS, DefaultDataBits, DefaultParity, DefaultStop)

	The format of parity and stop parameters is as follows:

		parity = "odd"|"even"|"mark"|"space"|"no"
		stop = "1"|"1.5"|"2"

	params: set of parameters specified by the user (0-bps, 1-data, 2-parity, 3-stop)
	res: error code, 0 in case of success
*)
PROCEDURE GetPortParameters*(r: Streams.Reader; VAR portNumber, bps, data, parity, stop: LONGINT; VAR params: SET; VAR res: WORD);
VAR
	str : ARRAY 32 OF CHAR;
	d: LONGINT;
BEGIN
	res := 0;

	IF ~r.GetInteger(portNumber,FALSE) OR (GetPort(portNumber) = NIL) THEN
		res := NoSuchPort;
		RETURN;
	END;

	params := {};
	bps := DefaultBPS; data := DefaultDataBits; parity := DefaultParity; stop := DefaultStop;

	IF r.GetInteger(d, FALSE) THEN
		bps := d; INCL(params,0);
	ELSE RETURN;
	END;

	IF r.GetInteger(d, FALSE) THEN
		data := d; INCL(params,1);
	ELSE RETURN;
	END;

	IF ~r.GetString(str) THEN
		RETURN;
	END;

	IF str = "odd" THEN
		parity := ParOdd
	ELSIF str = "even" THEN
		parity := ParEven
	ELSIF str = "mark" THEN
		parity := ParMark
	ELSIF str = "space" THEN
		parity := ParSpace
	ELSIF str # "no" THEN
		res := WrongParity;
		RETURN;
	END;

	INCL(params,2);

	IF ~r.GetString(str) THEN
		RETURN;
	END;

	IF str = "1.5" THEN
		stop := Stop1dot5
	ELSIF str = "2" THEN
		stop := Stop2
	ELSIF str # "1" THEN
		res := WrongStop;
		RETURN;
	END;

	INCL(params,3);
END GetPortParameters;

(**
	Setup trace over a given serial port

	SetTrace portNumber bps data parity stop~

	portNumber: serial port number, or 0 to disable trace output, or a negative value for rolling back to the initial trace output configuration
*)
PROCEDURE SetTrace*(context: Commands.Context);
VAR
	portNumber, bps, data, parity, stop, res: LONGINT; params: SET;
BEGIN
	GetPortParameters(context.arg, portNumber, bps, data, parity, stop, params, res);
	IF (portNumber > 0) & (res # 0) THEN
		context.result := 1;
		context.error.String("Invalid port settings, res="); context.error.Int(res,0); context.error.Ln;
		RETURN;
	END;

	SetTracePort(portNumber, bps, data, parity, stop, res);
	IF res # 0 THEN
		context.result := 2;
		context.error.String("Failed to setup trace port, res="); context.error.Int(res,0); context.error.Ln;
	END;
END SetTrace;

PROCEDURE Show*(context : Commands.Context);
VAR port : Port; noPortsAvailable : BOOLEAN; i : LONGINT;
BEGIN {EXCLUSIVE}
	noPortsAvailable := TRUE;
	context.out.String("Serials: "); context.out.Ln;
	FOR i := 0 TO LEN(ports)-1 DO
		port := ports[i];
		IF port # NIL THEN
			noPortsAvailable := FALSE;
			context.out.String(port.name); context.out.Char(9X); context.out.String(port.description); context.out.Ln;
		END;
	END;
	IF noPortsAvailable THEN context.out.String("No serial ports found."); END;
	context.out.Ln;
END Show;

(** Test serial ports COM1 and if present COM2 with the generic driver *)
PROCEDURE Test*(context : Commands.Context);
VAR
	result : LONGINT;
	portgotten : Port;
BEGIN
	context.out.String ("Testing availability of COM1 and COM2."); context.out.Ln;
	context.out.String ("Testing COM1: ");
	portgotten := GetPort (1);
	IF portgotten # NIL THEN
		portgotten.Open (4800, 8, 2, 2, result);
		portgotten.Close ();
		context.out.String ("available, result="); context.out.Int(result, 0); context.out.Ln;
		context.out.String ("Testing COM2: ");
		portgotten := GetPort (2);
		IF portgotten # NIL THEN
			portgotten.Open (9600, 8, 2, 2, result);
			portgotten.Close ();
			context.out.String ("available, result="); context.out.Int(result, 0); context.out.Ln
		ELSE
			context.out.String ("Could not get port 2"); context.out.Ln
		END
	ELSE
		context.out.String ("Could not get port 1"); context.out.Ln;
		context.out.String ("Not testing COM2 as it is likely not to work either."); context.out.Ln;
	END;
END Test;

(** Close all serial ports *)
PROCEDURE CloseAllPorts*(context : Commands.Context);
VAR portNbr : LONGINT;
BEGIN {EXCLUSIVE}
	FOR portNbr := 0 TO LEN(ports)-1 DO
		IF ports[portNbr] # NIL THEN
			ports[portNbr].Close;
		END;
	END;
	IF (context # NIL) THEN context.out.String("All serial ports closed"); context.out.Ln; END;
END CloseAllPorts;

PROCEDURE Cleanup;
BEGIN
	CloseAllPorts(NIL);
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END Serials.

System.Free V24 Serials ~

V24.Install ~
Serials.Test ~
Serials.Show ~

