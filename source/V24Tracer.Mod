MODULE V24Tracer; (** AUTHOR "TF/AFI"; PURPOSE "Man in the middle attack for Serial Ports" *)

IMPORT
	Commands, Streams, Modules, KernelLog, Serials;

TYPE
	SerialPortTracer = OBJECT
	VAR
		port : Serials.Port;
		seq : SIGNED32;	(* Sequence number of this serial port tracer *)
		ch : CHAR;
		V24writer : Streams.Writer;	(* Writer used by this serial port tracer *)
		alive : BOOLEAN;
		res : INTEGER;

	PROCEDURE &Init*(seqNo, portNo, bps : SIGNED32);
	BEGIN
		port := Serials.GetPort(portNo);
		IF res = 0 THEN
			port.Open(bps, 8, Serials.ParNo, Serials.Stop1, res);
			Streams.OpenWriter(V24writer, port.Send);
			seq := seqNo
		END;
	END Init;

	PROCEDURE Close;
	BEGIN
		alive := FALSE;
		port.Close()
	END Close;

	BEGIN {ACTIVE}
		alive := TRUE;
		WHILE alive DO
			port.ReceiveChar(ch, res);
			IF res = Serials.Ok THEN
				IF fine THEN	(* Display the origin of each character, its hex value and its printable value *)
					KernelLog.Ln; KernelLog.Int(seq, 0); KernelLog.String(" --> : ");
					KernelLog.Hex(ORD(ch), -2); KernelLog.Char("X");
					IF ORD(ch) > 32 THEN KernelLog.String("   "); KernelLog.Char(ch) END
				ELSE	(* Display a stream of characters with the same origin. In order to obtain this result,
								it is preferable, when a modem is tested, to operate it without echo - use an ATE0 command. *)
					IF seq # activeseq THEN
						activeseq := seq;
						KernelLog.Ln; KernelLog.Int(seq, 0); KernelLog.String(" --> : ")
					END;
					IF ORD(ch) > 32 THEN KernelLog.Char(ch)
					ELSIF (ch = " ") OR (ch = 0DX)OR (ch = 0AX) THEN KernelLog.Char(" ")
					ELSE IF ch # 0AX THEN KernelLog.Hex(ORD(ch), -2); KernelLog.Char("X") END
					END;
				END;
				(* Send the character just received to the other port *)
				tracingport[(seq + 1) MOD 2].V24writer.Char(ch);
				tracingport[(seq + 1) MOD 2].V24writer.Update();
			ELSE
				alive := FALSE;
				KernelLog.String("Character in error "); KernelLog.Char(ch); KernelLog.Int(res, 4); KernelLog.Ln;
			END;
		END;
		KernelLog.String("Tracer "); KernelLog.Int(seq, 0); KernelLog.String(" terminated."); KernelLog.Ln
	END SerialPortTracer;

VAR running, fine : BOOLEAN;
	tracingport : ARRAY 2 OF SerialPortTracer;
	activeseq : SIGNED32;

PROCEDURE SetMode*(context : Commands.Context);
VAR name : ARRAY 100 OF CHAR;
BEGIN
	IF context.arg.GetString(name) & (name = "fine") THEN fine := TRUE ELSE fine := FALSE END;
	context.out.String("Tracing mode "); context.out.String(name); context.out.Ln;
END SetMode;

PROCEDURE Enable*(context : Commands.Context);
VAR inPort, outPort, baud : SIGNED32;
BEGIN
	context.arg.SkipWhitespace; context.arg.Int(inPort, FALSE);
	context.arg.SkipWhitespace; context.arg.Int(outPort, FALSE);
	context.arg.SkipWhitespace; context.arg.Int(baud, FALSE);
	NEW(tracingport[0], 0, inPort, baud);	(* Instantiate 2 active tracers, which will be used in alternance *)
	NEW(tracingport[1], 1, outPort, baud);
	running := TRUE;
	context.out.String("Tracing active ... "); context.out.Ln;
	activeseq := -1;
END Enable;

PROCEDURE Finalize;
END Finalize;

PROCEDURE Disable*;
BEGIN
	tracingport[0].Close();
	tracingport[1].Close();
END Disable;

BEGIN
	fine := TRUE;	(* Default *)
	Modules.InstallTermHandler(Finalize)
END V24Tracer.

Use:
	1. Add the device to be traced to serialport 0
	2. Add the machine that knows the device to serialport 1 (eg. Windows/Linux/Unix/... with driver)
	3. Start the tracer, guessing the connection settings eg. baud rate (coarse mode is better in many cases)
	4. Start using the device
	5. Look at the data in the kernel log
	6. If output looks strange, disable the tracer, reguess the connection settings and goto 3

V24Tracer.Enable 0 1 9600 ~ InPort OutPort bps
V24Tracer.SetMode coarse ~
V24Tracer.SetMode fine ~
V24Tracer.Disable ~
System.Free V24Tracer ~

