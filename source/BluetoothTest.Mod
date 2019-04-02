MODULE BluetoothTest; (** AUTHOR "mt"; PURPOSE "Testing BluetoothHCI"; *)

IMPORT
	SYSTEM, KernelLog, Commands, Streams, Modules, Serials, Plugins, Usb, Bluetooth, BluetoothUSB,
	HCI := BluetoothHCI, L2CAP := BluetoothL2CAP, Strings;

TYPE
	Ident = ARRAY 32 OF CHAR;

	Device = OBJECT
	VAR
		next: Device;
		ident: Ident;
		port: Serials.Port;
		tl: Bluetooth.TransportLayer;
		hci: HCI.HCI;
		l2cap: L2CAP.L2CAP;

		PROCEDURE HCIEnumerator(l: HCI.Link; par: ANY): BOOLEAN;
		VAR i: LONGINT;
		BEGIN
			KernelLog.String("  connection to "); FOR i := 0 TO Bluetooth.BDAddrLen-1 DO KernelLog.Hex(ORD(l.remote[i]), -2) END;
			KernelLog.String("; handle "); KernelLog.Int(l.handle, 0); KernelLog.Ln;
			RETURN TRUE
		END HCIEnumerator;

		PROCEDURE ListHCIConnections;
		BEGIN
			KernelLog.String("Device '"); KernelLog.String(ident); KernelLog.String("': active connections:"); KernelLog.Ln;
			hci.EnumerateLinks(HCIEnumerator, NIL);
			KernelLog.String("done."); KernelLog.Ln
		END ListHCIConnections;

		PROCEDURE InitL2CAP;
		VAR res: WORD;
		BEGIN
			IF (l2cap # NIL) THEN CloseL2CAP END;
			(* NEW(l2cap, hci, res); *)
			NEW(l2cap);
			IF (res = 0) THEN
				l2cap.EventIndication(L2CAP.EConnectInd, ConnectIndication, res); ASSERT(res = 0);
				l2cap.EventIndication(L2CAP.EConfigInd, ConfigIndication, res); ASSERT(res= 0);
				l2cap.EventIndication(L2CAP.EDisconnectInd, DisconnectIndication, res); ASSERT(res = 0);
				l2cap.EventIndication(L2CAP.EQoSViolationInd, QoSViolationIndication, res); ASSERT(res = 0);

				KernelLog.String("L2CAP initialized")
			ELSE l2cap := NIL; KernelLog.String("failed to initialize L2CAP: res = "); KernelLog.Int(res, 0)
			END
		END InitL2CAP;

		PROCEDURE CloseL2CAP;
		BEGIN
			IF (l2cap # NIL) THEN l2cap := NIL; KernelLog.String("L2CAP closed")
			ELSE KernelLog.String("L2CAP not available")
			END
		END CloseL2CAP;

		PROCEDURE ConnectIndication(indication: L2CAP.Indication);
		VAR res: WORD;
		BEGIN
			KernelLog.String(ident); KernelLog.String(": connect indication!!!"); KernelLog.Ln;
			WITH indication: L2CAP.ConnectInd DO
				l2cap.ConnectResponse(indication.bdAddr, indication.ident, indication.c.sid, 0, 0, res);
				IF (res # 0) THEN KernelLog.String("cannot send connection response!"); KernelLog.Ln END
			END
		END ConnectIndication;

		PROCEDURE ConfigIndication(indication: L2CAP.Indication);
		VAR res: WORD;
		BEGIN
			WITH indication: L2CAP.ConfigInd DO
				KernelLog.String(ident); KernelLog.String(": configuration indication:"); KernelLog.Ln;
				KernelLog.String("  outMTU: "); KernelLog.Int(indication.outMTU, 0); KernelLog.Ln;
				KernelLog.String("  inFlow: "); KernelLog.Int(indication.inFlow, 0); KernelLog.Ln;
				KernelLog.String("  inFlushTO: "); KernelLog.Int(indication.inFlushTO, 0); KernelLog.Ln;

				l2cap.ConfigurationResponse(indication.c.sid, indication.ident, 0, 0, res);
				IF (res # 0) THEN KernelLog.String("cannot send configuration response!"); KernelLog.Ln END
			END
		END ConfigIndication;

		PROCEDURE DisconnectIndication(indication: L2CAP.Indication);
		BEGIN
			KernelLog.String(ident); KernelLog.String(": disconnect indication!!!"); KernelLog.Ln
		END DisconnectIndication;

		PROCEDURE QoSViolationIndication(indication: L2CAP.Indication);
		BEGIN
			KernelLog.String(ident); KernelLog.String(": QoS violation indication!!!"); KernelLog.Ln
		END QoSViolationIndication;

		PROCEDURE SendString(cid: LONGINT; VAR str: ARRAY OF CHAR);
		VAR buf: POINTER TO ARRAY OF CHAR; i, len: LONGINT; res: WORD;
		BEGIN
			NEW(buf,LEN(str)+2);
			WHILE (str[i] # 0X) DO buf[i] := str[i]; INC(i) END;
			buf[i] := 0AX; INC(i);
			l2cap.Write(cid, 0, i, buf^ ,len, res);
			IF (len # i) THEN KernelLog.String("Warning: cannot send all data"); KernelLog.Ln
			ELSIF (res # 0) THEN KernelLog.String("Warning: cannot send (res = "); KernelLog.Int(res, 0); KernelLog.Char(")"); KernelLog.Ln
			END
		END SendString;

		PROCEDURE Poll(cid: LONGINT; size: INTEGER; VAR off: INTEGER; VAR data: ARRAY OF CHAR);
		VAR buf: ARRAY 256 OF CHAR; i, res, len: LONGINT;
		BEGIN
			REPEAT
				l2cap.Read(cid, LEN(buf), buf, res, len);
				IF (res = 0) THEN
					FOR i := 0 TO len-1 DO KernelLog.Char(buf[i]) END
				END
			UNTIL (res # 0)
		END Poll;

		PROCEDURE PollBytes(cid: LONGINT; size: INTEGER; VAR off: INTEGER; VAR data: ARRAY OF CHAR);
		VAR buf: ARRAY 256 OF CHAR; i, res, len: LONGINT;
		BEGIN
			REPEAT
				l2cap.Read(cid, LEN(buf), buf, res, len);
				KernelLog.Char("[");
				IF (res = 0) THEN
					FOR i := 0 TO len-1 DO KernelLog.Hex(ORD(buf[i]), -2); KernelLog.Char(" ") END
				END;
				KernelLog.Char("]")
			UNTIL (res # 0)
		END PollBytes;
	END Device;

VAR
	devices: Device;

PROCEDURE Add(d: Device);
BEGIN
	d.next := devices.next; devices.next := d
END Add;

PROCEDURE Remove(d: Device);
VAR p,q: Device;
BEGIN
	p := devices.next; q := devices;
	WHILE (p # NIL) & (p # d) DO q := p; p := p.next END;
	IF (p # NIL) THEN q.next := p.next END
END Remove;

PROCEDURE Find(ident: ARRAY OF CHAR): Device;
VAR p: Device;
BEGIN
	p := devices.next;
	WHILE (p # NIL) & (p.ident # ident) DO p := p.next END;
	RETURN p
END Find;

(* For USB *)
PROCEDURE Open*(context : Commands.Context);
VAR
	device : Device;
	tl : BluetoothUSB.UsbTransportLayer; devicename, ident : Ident; plugin : Plugins.Plugin;
BEGIN {EXCLUSIVE}
	IF context.arg.GetString(devicename) & context.arg.GetString(ident) THEN
		plugin := Usb.usbDrivers.Get(devicename);
		IF (plugin # NIL) THEN
			IF (Find(ident) = NIL) THEN
				NEW(device); device.ident := ident;
				NEW(tl, devicename, NIL, NIL); device.tl := tl;
				NEW(device.hci, tl);
				device.hci.OnInquiry := InquiryResult;
				(*
				d.hci.OnReceiveACLData := ReceiveData;
				*)
				Add(device);
				context.out.String("Device '"); context.out.String(ident); context.out.String("' on ");
				context.out.String(devicename); context.out.String(" connected.");
				context.out.Ln;
			ELSE
				context.error.String("Device '"); context.error.String(ident); context.error.String("' already present.");
				context.error.Ln;
			END;
		ELSE
			context.error.String("Bluetooth USB device '"); context.error.String(devicename);
			context.error.String("' not found."); context.error.Ln;
		END;
	ELSE
		context.error.String("Expected <UsbDeviceName> <DeviceName> parameters."); context.error.Ln;
	END;
END Open;

(* For UART
PROCEDURE Open*(context : Commands.Context);
VAR
	ident: Ident; d: Device;
	portNo, bps, data, parity, stop, res: LONGINT;
	tl: BluetoothUART.TransportLayer;
BEGIN
	context.arg.GetString(ident);
	context.arg.GetInteger(portNo, FALSE);
	context.arg.GetInteger(bps, FALSE);
	context.arg.GetInteger(data, FALSE);
	context.arg.GetInteger(parity, FALSE);
	context.arg.GetInteger(stop, FALSE);
	IF (context.arg.res = Streams.Ok) THEN
		IF Find(ident) = NIL THEN
			NEW(d); d.ident := ident;
			NEW(d.port, portNo-1, bps, data, parity, stop, res);
			IF (res = 0) THEN
				NEW(d.tl, ident, d.port.Send, d.port.Receive);
				NEW(d.hci, d.tl);
				d.hci.OnInquiry := InquiryResult;
				(*
				d.hci.OnReceiveACLData := ReceiveData;
				*)
				Add(d);
				context.out.String("Device '"); context.out.String(ident); context.out.String("' ready.");
				context.out.Ln;
			ELSE
				context.error.String("Cannot open com port."); context.error.Ln;
			END
		ELSE context.out.String("Device '"); context.out.String(ident); context.out.String("' already present.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END Open;
*)

PROCEDURE Close*(context : Commands.Context);
VAR ident: Ident; d: Device;
BEGIN
	IF context.arg.GetString(ident) THEN
		d := Find(ident);
		IF (d # NIL) THEN
			d.hci.Close;
			d.port.Close;
			Remove(d);
			context.out.String("Device '"); context.out.String(ident); context.out.String("' removed."); context.out.Ln;
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END Close;

PROCEDURE TraceMode*(context : Commands.Context);
VAR ident: Ident; c: CHAR; d: Device;
BEGIN
	IF context.arg.GetString(ident) & context.arg.GetChar(c) THEN
		d := Find(ident);
		IF (d # NIL) THEN
			c := CAP(c);
		(*	d.tl.TraceSend := (c="T") OR (c="B");
			d.tl.TraceReceive := (c="R") OR (c="B");

			context.out.String("Device '"); context.out.String(ident); context.out.String("': tracing mode = ");
			IF d.tl.TraceSend THEN context.out.Char("T") END;
			IF d.tl.TraceReceive THEN context.out.Char("R") END; *)
			context.out.Ln;
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END TraceMode;

PROCEDURE ReadLocalName*(context : Commands.Context);
VAR
	ident: Ident; d: Device;
	event: Bluetooth.EventPacket; pending: BOOLEAN; res: WORD; i: LONGINT;
BEGIN
	IF context.arg.GetString(ident) THEN
		d := Find(ident);
		IF (d # NIL) THEN
			context.out.String("Reading local name..."); context.out.Ln;
			d.hci.SendCommand(HCI.ogfControl, HCI.ocfReadLocalName, "", 0, event, pending, res);
			IF (res = 0) & ~pending THEN
				context.out.String("  success: '");
				i := 0;
				WHILE (i < 248) & (event.params[4+i] # 0X) DO
					context.out.Char(event.params[4+i]);
					INC(i)
				END;
				context.out.Char("'"); context.out.Ln;
			ELSE
				context.out.String("  failed; res = "); context.out.Int(res, 0); context.out.Ln;
			END
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END ReadLocalName;

PROCEDURE ChangeLocalName*(context : Commands.Context);
VAR
	ident: Ident; d: Device;
	name: ARRAY 248 OF CHAR; event: Bluetooth.EventPacket; pending: BOOLEAN; res : WORD;
BEGIN
	IF context.arg.GetString(ident) & context.arg.GetString(name) THEN
		d := Find(ident);
		IF (d # NIL) THEN
			context.out.String("Changing local name to '"); context.out.String(name); context.out.String("'..."); context.out.Ln;
			d.hci.SendCommand(HCI.ogfControl, HCI.ocfChangeLocalName, name, 248, event, pending, res);
			IF (res = 0) & ~pending THEN
				context.out.String("  success")
			ELSE
				context.out.String("  failed; res = "); context.out.Int(res, 0)
			END;
			context.out.Ln;
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END ChangeLocalName;

PROCEDURE ReadClassOfDevice*(context : Commands.Context);
VAR
	ident: Ident; d: Device;
	event: Bluetooth.EventPacket; pending: BOOLEAN; res: WORD; i: LONGINT;
BEGIN
	IF context.arg.GetString(ident) THEN
		d := Find(ident);
		IF (d # NIL) THEN
			context.out.String("Reading class of device..."); context.out.Ln;
			d.hci.SendCommand(HCI.ogfControl, HCI.ocfReadClassOfDevice, "", 0, event, pending, res);
			IF (res = 0) & ~pending THEN
				context.out.String("  success; class of device = ");
				FOR i := 0 TO Bluetooth.DeviceClassLen-1 DO
					context.out.Hex(ORD(event.params[4+i]), -2); context.out.Char(" ")
				END
			ELSE context.out.String("  failed; res = "); context.out.Int(res, 0)
			END
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END ReadClassOfDevice;

PROCEDURE WriteClassOfDevice*(context : Commands.Context);
VAR
	ident: Ident; d: Device;
	event: Bluetooth.EventPacket; pending: BOOLEAN; res: WORD;  i: LONGINT; cod: Bluetooth.DeviceClass;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(ident); context.arg.SkipWhitespace;
	FOR i := 0 TO LEN(cod)-1 DO cod[i] := HexToChar(context.arg.Get(), context.arg.Get()) END;
	IF (context.arg.res = Streams.Ok) THEN
		d := Find(ident);
		IF (d # NIL) THEN
			context.out.String("Writing class of device..."); context.out.Ln;
			d.hci.SendCommand(HCI.ogfControl, HCI.ocfWriteClassOfDevice, cod, 3, event, pending, res);
			IF (res = 0) & ~pending THEN context.out.String("  success")
			ELSE context.out.String("  failed; res = "); context.out.Int(res, 0)
			END
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END WriteClassOfDevice;

PROCEDURE Reset*(context : Commands.Context);
VAR ident: Ident; d: Device; res: WORD;
BEGIN
	IF context.arg.GetString(ident) THEN
		d := Find(ident);
		IF (d # NIL) THEN
			context.out.String("Sending reset...");
			res := d.hci.Reset();
			context.out.String("res = "); context.out.Int(res, 0)
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END Reset;

PROCEDURE ReadScanEnable*(context : Commands.Context);
VAR
	ident: Ident; d: Device;
	res: WORD; event: Bluetooth.EventPacket; pending: BOOLEAN;
BEGIN
	IF context.arg.GetString(ident) THEN
		d := Find(ident);
		IF (d # NIL) THEN
			context.out.String("Reading scan mode...");
			d.hci.SendCommand(HCI.ogfControl, HCI.ocfReadScanEnable, "", 0, event, pending, res);
			IF (res = 0) THEN
				context.out.String("ok"); context.out.Ln;
				CASE ORD(event.params[4]) OF
				| 0: context.out.String("  no scans enabled")
				| 1: context.out.String("  inquiry scan enabled, page scan disabled")
				| 2: context.out.String("  inquiry scan disabled, page scan enabled")
				| 3: context.out.String("  inquiry scan enabled, page scan enabled")
				ELSE context.out.String("  invalid code: "); context.out.Int(ORD(event.params[4]), 0)
				END
			ELSE context.out.String("error, res = "); context.out.Int(res, 0)
			END
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END ReadScanEnable;

PROCEDURE WriteScanEnable*(context : Commands.Context);
VAR
	ident: Ident; d: Device;
	res: WORD;  scanMode: LONGINT; param: ARRAY 1 OF CHAR; event: Bluetooth.EventPacket; pending: BOOLEAN;
BEGIN
	IF context.arg.GetString(ident) & context.arg.GetInteger(scanMode, TRUE) THEN
		IF (0 <= scanMode) & (scanMode <= 3) THEN
			d := Find(ident);
			IF (d # NIL) THEN
				context.out.String("Sending write scan enable...");
				param[0] := CHR(scanMode);
				d.hci.SendCommand(HCI.ogfControl, HCI.ocfWriteScanEnable, param, 1, event, pending, res);
				context.out.String("res = "); context.out.Int(res, 0)
			ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
			END
		ELSE context.out.String("Invalid parameters")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END WriteScanEnable;

PROCEDURE SetFilter*(context : Commands.Context);
VAR
	ident: Ident; d: Device;
	cond: ARRAY 1 OF CHAR; res: WORD;
BEGIN
	IF context.arg.GetString(ident) THEN
		d := Find(ident);
		IF (d # NIL) THEN
			context.out.String("Sending SetEventFilter...");
			cond[0] := HCI.EFCSAAOn;
			res := d.hci.SetEventFilter(HCI.EFConnectionSetup, HCI.EFCSAll, cond);
			context.out.String("res = "); context.out.Int(res, 0)
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END SetFilter;

PROCEDURE ReadPageScanActivity*(context : Commands.Context);
VAR
	ident: Ident; d: Device;
	interval, window: LONGINT; res: WORD; pending: BOOLEAN; event: Bluetooth.EventPacket; intStr, winStr: ARRAY 16 OF CHAR;
BEGIN
	IF context.arg.GetString(ident) THEN
		d := Find(ident);
		IF (d # NIL) THEN
			context.out.String("Reading page scan activity...");
			d.hci.SendCommand(HCI.ogfControl, HCI.ocfReadPageScanActivity, "", 0, event, pending, res);
			context.out.String("done."); context.out.Ln;
			IF (res = 0) THEN
				interval := ORD(event.params[4])+LONG(ORD(event.params[5]))*100H;
				window := ORD(event.params[6])+LONG(ORD(event.params[7]))*100H;
				Strings.FloatToStr(interval*0.625, 6, 2, 0, intStr);
				Strings.FloatToStr(window*0.625, 6, 2, 0, winStr);
				context.out.String("  interval: "); context.out.Int(interval, 0); context.out.String("*0.625ms = "); context.out.String(intStr); context.out.String("ms"); context.out.Ln;
				context.out.String("  window: "); context.out.Int(window, 0); context.out.String("*0.625ms = "); context.out.String(winStr); context.out.String("ms"); context.out.Ln
			ELSE
				context.out.String("  Error: res = "); context.out.Int(res, 0)
			END
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END ReadPageScanActivity;

PROCEDURE WritePageScanActivity*(context : Commands.Context);
VAR
	ident: Ident; d: Device;
	interval, window: LONGINT; res: WORD; pending: BOOLEAN; event: Bluetooth.EventPacket; param: ARRAY 4 OF CHAR;
BEGIN
	IF context.arg.GetString(ident) & context.arg.GetInteger(interval, TRUE) & context.arg.GetInteger(window, TRUE) THEN
		d := Find(ident);
		IF (d # NIL) THEN
			IF (12H <= interval) & (interval <= 1000H) & (12H <= window) & (window <= 1000H) THEN
				context.out.String("Writing page scan activity...");
				param[0] := CHR(interval MOD 100H); param[1] := CHR(interval DIV 100H);
				param[2] := CHR(window MOD 100H); param[3] := CHR(window DIV 100H);
				d.hci.SendCommand(HCI.ogfControl, HCI.ocfWritePageScanActivity, param, 4, event, pending, res);
				context.out.String("done."); context.out.Ln;
				IF (res = 0) THEN
				ELSE
					context.out.String("  Error: res = "); context.out.Int(res, 0)
				END
			ELSE
				context.out.String("Invalid parameters. Values range from 0012H to 1000H")
			END
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END WritePageScanActivity;

PROCEDURE ReadInquiryScanActivity*(context : Commands.Context);
VAR
	ident: Ident; d: Device;
	interval, window: LONGINT; res: WORD; pending: BOOLEAN; event: Bluetooth.EventPacket; intStr, winStr: ARRAY 16 OF CHAR;
BEGIN
	IF context.arg.GetString(ident) THEN
		d := Find(ident);
		IF (d # NIL) THEN
			context.out.String("Reading inquiry scan activity...");
			d.hci.SendCommand(HCI.ogfControl, HCI.ocfReadInquiryScanActivity, "", 0, event, pending, res);
			context.out.String("done."); context.out.Ln;
			IF (res = 0) THEN
				interval := ORD(event.params[4])+LONG(ORD(event.params[5]))*100H;
				window := ORD(event.params[6])+LONG(ORD(event.params[7]))*100H;
				Strings.FloatToStr(interval*0.625, 6, 2, 0, intStr);
				Strings.FloatToStr(window*0.625, 6, 2, 0, winStr);
				context.out.String("  interval: "); context.out.Int(interval, 0); context.out.String("*0.625ms = "); context.out.String(intStr); context.out.String("ms"); context.out.Ln;
				context.out.String("  window: "); context.out.Int(window, 0); context.out.String("*0.625ms = "); context.out.String(winStr); context.out.String("ms"); context.out.Ln
			ELSE
				context.out.String("  Error: res = "); context.out.Int(res, 0)
			END
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END ReadInquiryScanActivity;

PROCEDURE WriteInquiryScanActivity*(context : Commands.Context);
VAR
	ident: Ident; d: Device;
	interval, window: LONGINT; res: WORD; pending: BOOLEAN; event: Bluetooth.EventPacket; param: ARRAY 4 OF CHAR;
BEGIN
	IF context.arg.GetString(ident) & context.arg.GetInteger(interval, TRUE) & context.arg.GetInteger(window, TRUE) THEN
		d := Find(ident);
		IF (d # NIL) THEN
			IF (12H <= interval) & (interval <= 1000H) & (12H <= window) & (window <= 1000H) THEN
				context.out.String("Writing inquiry scan activity...");
				param[0] := CHR(interval MOD 100H); param[1] := CHR(interval DIV 100H);
				param[2] := CHR(window MOD 100H); param[3] := CHR(window DIV 100H);
				d.hci.SendCommand(HCI.ogfControl, HCI.ocfWriteInquiryScanActivity, param, 4, event, pending, res);
				context.out.String("done."); context.out.Ln;
				IF (res = 0) THEN
				ELSE
					context.out.String("  Error: res = "); context.out.Int(res, 0)
				END
			ELSE
				context.out.String("Invalid parameters. Values range from 0012H to 1000H")
			END
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END WriteInquiryScanActivity;

PROCEDURE Inquiry*(context : Commands.Context);
VAR
	ident: Ident; d: Device; lap: ARRAY 3 OF CHAR;
	params: ARRAY 5 OF CHAR; event: Bluetooth.EventPacket; pending: BOOLEAN;
	length, numResponses, i: LONGINT; res: WORD;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(ident); context.arg.SkipWhitespace;
	FOR i := 0 TO LEN(lap)-1 DO lap[i] := HexToChar(context.arg.Get(), context.arg.Get()) END;
	context.arg.SkipWhitespace; context.arg.Int(length, TRUE);
	context.arg.SkipWhitespace; context.arg.Int(numResponses, TRUE);
	IF (context.arg.res = Streams.Ok) THEN
		IF (0 < length) & (length <= 30H) & (0 <= numResponses) & (numResponses < 100H) THEN
			d := Find(ident);
			IF (d # NIL) THEN
				context.out.String("Sending inquiry command..."); context.out.Ln;
				params[0] := lap[2]; params[1] := lap[1]; params[2] := lap[0];
				params[3] := CHR(length); params[4] := CHR(numResponses);
				d.hci.SendCommand(HCI.ogfLinkControl, HCI.ocfInquiry, params, 5, event, pending, res);
				IF (res = 0) THEN context.out.String("  inquiry process started")
				ELSE context.out.String("  failed")
				END
			ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
			END
		ELSE context.out.String("Wrong parameters.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END Inquiry;

PROCEDURE InquiryResult(sender: HCI.HCI; bdAddr: Bluetooth.BDAddr; deviceClass: Bluetooth.DeviceClass;
		psRepMode, psPeriodMode, psMode, clockOffset: LONGINT);
VAR k: LONGINT;
BEGIN
	KernelLog.Enter;
	KernelLog.String("Inquiry Result: "); KernelLog.Ln;
	KernelLog.String("  remote: ");
		FOR k := 0 TO Bluetooth.BDAddrLen-1 DO KernelLog.Hex(ORD(bdAddr[k]), -2); KernelLog.Char(" ") END;
		KernelLog.Ln;
	KernelLog.String("  class of device: ");
		FOR k := 0 TO Bluetooth.DeviceClassLen-1 DO KernelLog.Hex(ORD(deviceClass[k]), -2); KernelLog.Char(" "); END;
		KernelLog.Ln;
	KernelLog.String("  page scan repetition mode: "); KernelLog.Int(psRepMode, 0); KernelLog.Ln;
	KernelLog.String("  page scan period mode: "); KernelLog.Int(psPeriodMode, 0); KernelLog.Ln;
	KernelLog.String("  page scan mode: "); KernelLog.Int(psMode, 0); KernelLog.Ln;
	KernelLog.String("  clock offset: "); KernelLog.Int(clockOffset, 0);
	KernelLog.Exit
END InquiryResult;

PROCEDURE Val(ch: CHAR): LONGINT;
BEGIN
	IF ("0" <= ch) & (ch <= "9") THEN RETURN ORD(ch) - ORD("0")
	ELSIF ("A" <= ch) & (ch <= "F") THEN RETURN ORD(ch) - ORD("A")+10
	ELSIF ("a" <= ch) & (ch <= "f")  THEN RETURN ORD(ch) - ORD("a")+10
	ELSE RETURN -1
	END
END Val;

PROCEDURE HexToChar(v1, v2: CHAR): CHAR;
VAR val1, val2: LONGINT;
BEGIN
	val1 := Val(v1); val2 := Val(v2);
	IF (val1 # -1) & (val2 # -1) THEN RETURN CHR(val1*10H+val2)
	ELSE RETURN 0X
	END
END HexToChar;

PROCEDURE ConnectTo*(context : Commands.Context);
VAR
	ident: Ident; d: Device;
	remote: Bluetooth.BDAddr; i , offset: LONGINT; res: WORD;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(ident); context.arg.SkipWhitespace;
	FOR i := 0 TO LEN(remote)-1 DO remote[i] := HexToChar(context.arg.Get(), context.arg.Get()) END;
	context.arg.SkipWhitespace; context.arg.Int(offset, TRUE);
	IF (context.arg.res = Streams.Ok) THEN
		d := Find(ident);
		IF (d # NIL) THEN
			context.out.String("Connecting to "); FOR i := 0 TO LEN(remote)-1 DO context.out.Hex(ORD(remote[i]), -2) END; context.out.String("...");
			res := d.hci.CreateConnection(remote, offset);
			IF (res = 0) THEN context.out.String("success.")
			ELSE context.out.String("failed; error code = "); context.out.Hex(res, -2)
			END
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END ConnectTo;

PROCEDURE Supported(out : Streams.Writer; feature: ARRAY OF CHAR; s: SET; bit: LONGINT);
BEGIN
	out.String("  "); out.String(feature); out.String(": ");
	IF (bit IN s) THEN out.String("yes") ELSE out.String("no") END;
	out.Ln
END Supported;

PROCEDURE ReadLocalSupportedFeatures*(context : Commands.Context);
VAR
	ident: Ident; d: Device;
	res: WORD; event: Bluetooth.EventPacket; pending: BOOLEAN;
	s: SET;
BEGIN
	IF context.arg.GetString(ident) THEN
		d := Find(ident);
		IF (d # NIL) THEN
			context.out.String("Reading local supported features... ");
			d.hci.SendCommand(HCI.ogfInformational, HCI.ocfReadLocalSupportedFeatures, "", 0, event, pending, res);

			IF (res = 0) THEN
				context.out.String("success."); context.out.Ln;
				(* byte 0 *)
				s := SYSTEM.VAL(SET, event.params[4]);
				Supported(context.out, "3-slot packets", s, 0);
				Supported(context.out, "5-slot packets", s, 1);
				Supported(context.out, "encryption", s, 2);
				Supported(context.out, "slot offset", s, 3);
				Supported(context.out, "timing accuracy", s, 4);
				Supported(context.out, "switch", s, 5);
				Supported(context.out, "hold mode", s, 6);
				Supported(context.out, "sniff mode", s, 7);

				(* byte 1 *)
				s := SYSTEM.VAL(SET, event.params[5]);
				Supported(context.out, "park mode", s, 0);
				Supported(context.out, "RSSI", s, 1);
				Supported(context.out, "channel quality driven data rate", s, 2);
				Supported(context.out, "SCO link", s, 3);
				Supported(context.out, "HV2 packets", s, 4);
				Supported(context.out, "HV3 packets", s, 5);
				Supported(context.out, "u-law log", s, 6);
				Supported(context.out, "A-law log", s, 7);

				(* byte 2 *)
				s := SYSTEM.VAL(SET, event.params[6]);
				Supported(context.out, "CVSD", s, 0);
				Supported(context.out, "paging scheme", s, 2);
				Supported(context.out, "power control", s, 3);
				context.out.String("  transparent SCO data: "); context.out.Int(ORD(event.params[6]) DIV 10H, 0); context.out.Ln;
				context.out.Ln;
			ELSE context.out.String("failed; error code = "); context.out.Hex(res, -2)
			END
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END ReadLocalSupportedFeatures;

PROCEDURE ListHCIConnections*(context : Commands.Context);
VAR ident: Ident; d: Device;
BEGIN
	IF (context.arg.res = Streams.Ok) THEN
		d := Find(ident);
		IF (d # NIL) THEN
			d.ListHCIConnections
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END ListHCIConnections;

PROCEDURE ReadClockOffset*(context : Commands.Context);
VAR
	ident: Ident; d: Device;
	handle: LONGINT; res: WORD; event: Bluetooth.EventPacket; pending: BOOLEAN; param: ARRAY 2 OF CHAR;
BEGIN
	IF context.arg.GetString(ident) & context.arg.GetInteger(handle, TRUE) THEN
		d := Find(ident);
		IF (d # NIL) THEN
			context.out.String("Reading clock offset for handle "); context.out.Int(handle, 0); context.out.String("... "); context.out.Ln;
			param[0] := CHR(handle MOD 100H); param[1] := CHR(handle DIV 100H MOD 100H);
			d.hci.SendCommand(HCI.ogfLinkControl, HCI.ocfReadClockOffset, param, 2, event, pending, res);
			IF (res = 0) THEN
				context.out.String("  waiting for response..."); context.out.Ln;
				d.hci.GetEvent(3000, event, res);
				IF (res = 0) THEN
					IF (event.code = 01CX) THEN
						res := ORD(event.params[0]);
						IF (res = 0) THEN
							handle := ORD(event.params[1])+LONG(ORD(event.params[2]))*100H;
							res := ORD(event.params[3])+LONG(ORD(event.params[4]))*100H;
							context.out.String("  success: clock offset for handle "); context.out.Hex(handle, -4); context.out.String(" is "); context.out.Int(res, 0)
						ELSE context.out.String("  failed; reason = "); context.out.Hex(res, -2)
						END
					ELSE context.out.String("  failed; wrong event ("); context.out.Hex(ORD(event.code), -2); context.out.String("X)")
					END
				ELSE context.out.String("  failed; error code = "); context.out.Hex(res, -2)
				END
			ELSE context.out.String("failed; error code = "); context.out.Hex(res, -2)
			END
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END ReadClockOffset;

PROCEDURE SendACL*(context : Commands.Context);
VAR
	ident: Ident; d: Device;
	data: ARRAY 256 OF CHAR; i, handle, cid: LONGINT; res: WORD; c1, c2: CHAR;
	l: HCI.Link;
BEGIN
	IF context.arg.GetString(ident) & context.arg.GetInteger(handle, FALSE) & context.arg.GetInteger(cid, FALSE) THEN
		context.arg.SkipWhitespace;
		d := Find(ident);
		IF (d # NIL) THEN
			i := 4;
			WHILE (context.arg.res = Streams.Ok) DO
				c1 := context.arg.Get(); c2 := context.arg.Get();
				IF (context.arg.res = Streams.Ok) THEN
					data[i] := HexToChar(c1, c2);
					INC(i)
				END
			END;

			data[0] := CHR((i-4) MOD 100H); data[1] := CHR((i-4) DIV 100H);	(* length *)
			data[2] := CHR(cid MOD 100H); data[3] := CHR(cid DIV 100H);

			context.out.String("Sending ACL data on link "); context.out.Int(handle, 0); context.out.String("...");
			l := d.hci.FindLink(handle, "");
			IF (l # NIL) THEN
				res := l.SendACL(HCI.pbfFirst, HCI.bfPointToPoint, data, 0, i);
				IF (res = 0) THEN context.out.String("success")
				ELSE context.out.String("failed; error code = "); context.out.Hex(res, -2)
				END
			ELSE context.out.String("link not found.")
			END
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END SendACL;

PROCEDURE ReceiveData(handle, pb, bc, len: LONGINT; VAR data: ARRAY OF CHAR);
VAR i: LONGINT;
BEGIN
	KernelLog.String("Data received: ");
	FOR i := 0 TO len-1 DO KernelLog.Hex(ORD(data[i]), -2); KernelLog.Char(" ") END;
	KernelLog.Ln
END ReceiveData;

PROCEDURE TestStringToParam*(context : Commands.Context);
(*
VAR i, len: LONGINT; param: ARRAY 256 OF CHAR;
BEGIN
	par := p(AosCommands.Parameters);

	Bluetooth.StringToParam(par.str^, param, len);

	FOR i := 0 TO len-1 DO
		KernelLog.Hex(ORD(param[i]), -2); KernelLog.Char(" ")
	END;
	KernelLog.Ln;

	RETURN NIL
*)
END TestStringToParam;

PROCEDURE ReadBDAddr*(context : Commands.Context);
VAR
	ident: Ident; d: Device;
	res: WORD; i: LONGINT; bdAddr: Bluetooth.BDAddr;
BEGIN
	IF context.arg.GetString(ident) THEN
		d := Find(ident);
		IF (d # NIL) THEN
			res := d.hci.ReadBDAddr(bdAddr);

			IF (res = 0) THEN
				context.out.String("BDAddr = ");
				FOR i := 0 TO Bluetooth.BDAddrLen-1 DO context.out.Hex(ORD(bdAddr[i]), -2) END
			ELSE
				context.out.String("error (res = "); context.out.Int(res, 0); context.out.Char(")")
			END
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END ReadBDAddr;

(*********************************************************************
															L2CAP
**********************************************************************)

PROCEDURE L2CAPInit*(context : Commands.Context);
VAR ident: Ident; d: Device;
BEGIN
	IF context.arg.GetString(ident) THEN
		d := Find(ident);
		IF (d # NIL) THEN
			L2CAP.InitL2CAP(d.hci);
			d.InitL2CAP
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END L2CAPInit;

PROCEDURE L2CAPClose*(context : Commands.Context);
VAR ident: Ident; d: Device;
BEGIN
	IF context.arg.GetString(ident) THEN
		d := Find(ident);
		IF (d # NIL) THEN
			d.CloseL2CAP
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END L2CAPClose;

PROCEDURE L2CAPConnect*(context : Commands.Context);
VAR
	ident: Ident; d: Device;
	remote: Bluetooth.BDAddr; i, lcid, status: LONGINT; res: WORD;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(ident); context.arg.SkipWhitespace;
	FOR i := 0 TO LEN(remote)-1 DO remote[i] := HexToChar(context.arg.Get(), context.arg.Get()) END;

	IF (context.arg.res = Streams.Ok) THEN
		d := Find(ident);
		IF (d # NIL) THEN
			IF (d.l2cap # NIL) THEN
				context.out.String("Connecting to "); FOR i := 0 TO LEN(remote)-1 DO context.out.Hex(ORD(remote[i]), -2) END; context.out.String("..."); context.out.Ln;
				d.l2cap.Connect(L2CAP.psmSDP, remote, lcid, res, status);
				IF (res = 0) THEN
					context.out.String("connected."); context.out.Ln;
					context.out.String("  channel ID = "); context.out.Int(lcid, 0); context.out.Ln
				ELSE context.out.String("failed; error code = "); context.out.Hex(res, -2)
				END
			ELSE context.out.String("L2CAP not initialized.")
			END
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END L2CAPConnect;

PROCEDURE L2CAPConfigure*(context : Commands.Context);
VAR
	ident: Ident; d: Device;
	cid, mtu, flushTO, flow, linkTO: LONGINT; res: WORD;
BEGIN
	IF context.arg.GetString(ident) & context.arg.GetInteger(cid, TRUE) & context.arg.GetInteger(mtu, TRUE) &
		context.arg.GetInteger(flushTO, TRUE) & context.arg.GetInteger(linkTO, TRUE) THEN
		d := Find(ident);
		IF (d # NIL) THEN
			IF (d.l2cap # NIL) THEN
				context.out.String("Configuring channel "); context.out.Int(cid, 0); context.out.String("..."); context.out.Ln;
				d.l2cap.Configure(cid, mtu, flow, flushTO, linkTO, res);
				IF (res = 0) THEN
					context.out.String("ok, channel is open")
				ELSE
					context.out.String("nope, res = "); context.out.Int(res, 0)
				END;
				context.out.Ln
			ELSE context.out.String("L2CAP not initialized.")
			END
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END L2CAPConfigure;

PROCEDURE L2CAPPollChannel*(context : Commands.Context);
VAR ident: Ident; d: Device; cid, mode: LONGINT;
BEGIN
	IF context.arg.GetString(ident) & context.arg.GetInteger(cid, TRUE) & context.arg.GetInteger(mode, TRUE) THEN
		d := Find(ident);
		IF (d # NIL) THEN
			IF (d.l2cap # NIL) THEN
				IF mode = 1 THEN (* d.PollBytes(cid) *)
				ELSE(*  d.Poll(cid) *)
				END
			ELSE context.out.String("L2CAP not initialized.")
			END
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END L2CAPPollChannel;

PROCEDURE L2CAPSendString*(context : Commands.Context);
VAR
	ident: Ident; d: Device;
	cid: LONGINT; str: ARRAY 65536 OF CHAR; i: LONGINT;
BEGIN
	IF context.arg.GetString(ident) & context.arg.GetInteger(cid, TRUE) & context.arg.GetString(str) THEN
		d := Find(ident);
		IF (d # NIL) THEN
			IF (d.l2cap # NIL) THEN
				i := 0; WHILE (str[i] # 0X) DO INC(i) END;
				context.out.String("Length = "); context.out.Int(i, 0); context.out.Ln;
				d.SendString(cid, str);
			ELSE context.out.String("L2CAP not initialized.")
			END
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END L2CAPSendString;

PROCEDURE L2CAPPing*(context : Commands.Context);
VAR
	ident: Ident; d: Device;
	remote: Bluetooth.BDAddr; i, len, res: LONGINT; data: ARRAY 32 OF CHAR;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(ident); context.arg.SkipWhitespace;
	FOR i := 0 TO LEN(remote)-1 DO remote[i] := HexToChar(context.arg.Get(), context.arg.Get()) END;

	IF (context.arg.res = Streams.Ok) THEN
		d := Find(ident);
		IF (d # NIL) THEN
			IF (d.l2cap # NIL) THEN
				context.out.String("Pinging "); FOR i := 0 TO LEN(remote)-1 DO context.out.Hex(ORD(remote[i]), -2) END; context.out.String("..."); context.out.Ln;
				d.l2cap.Ping(remote, data, len, res);
				IF (res = 0) THEN
					context.out.String("success."); context.out.Ln;
				ELSE context.out.String("failed; error code = "); context.out.Hex(res, -2)
				END
			ELSE context.out.String("L2CAP not initialized.")
			END
		ELSE context.out.String("No such device '"); context.out.String(ident); context.out.String("'.")
		END
	ELSE context.out.String("Syntax error.")
	END;
	context.out.Ln;
END L2CAPPing;

PROCEDURE Cleanup;
VAR d: Device;
BEGIN
	d := devices.next;
	IF (d # NIL) THEN
		KernelLog.String("Automatic shutdown: ");
		WHILE (d # NIL) DO
			KernelLog.String(d.ident); KernelLog.Char(" ");
			d.hci.Close;
			d.port.Close;
			d := d.next
		END;
		KernelLog.Ln
	END;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	NEW(devices); (* dummy head *)
END BluetoothTest.

(*

BluetoothHCI.Mod


System.Free BluetoothTest BluetoothL2CAP BluetoothHCI BluetoothUART BluetoothUSB Bluetooth~
System.Free BluetoothTest~

System.ListPlugins ~

BluetoothTest.Open UsbBluetooth00 BTTest ~

BluetoothTest.Reset BTTest ~

**** HCI level ****
BluetoothTest.ReadLocalName BTTest ~
BluetoothTest.ChangeLocalName BTTest aRealName ~
BluetoothTest.ReadClassOfDevice BTTest ~
BluetoothTest.WriteClassOfDevice BTTest 040420 ~
BluetoothTest.ReadBDAddr BTTest ~
BluetoothTest.ReadLocalSupportedFeatures BTTest ~

BluetoothTest.ReadScanEnable BTTest ~
BluetoothTest.WriteScanEnable BTTest 03 ~
BluetoothTest.ReadPageScanActivity BTTest ~
BluetoothTest.WritePageScanActivity BTTest 1024 25 ~
BluetoothTest.ReadInquiryScanActivity BTTest ~
BluetoothTest.WriteInquiryScanActivity BTTest 0801H 013H ~

BluetoothTest.Inquiry BTTest  9E8B33 08H 0 ~


BluetoothTest.ListHCIConnections BTTest ~	Aos.Call BluetoothTest.ListHCIConnections huga ~


Configuration.DoCommands
Aos.Call \w BluetoothTest.Open BTTest 1 57600 8 0 1~
Aos.Call \w BluetoothTest.L2CAPInit BTTest ~
Aos.Call \w BluetoothTest.WriteScanEnable BTTest 03~
Aos.Call \w BluetoothTest.SetFilter BTTest ~
~
Configuration.DoCommands
Aos.Call \w BluetoothTest.Open huga 2 57600 8 0 1~
Aos.Call \w BluetoothTest.L2CAPInit huga ~
Aos.Call \w BluetoothTest.WriteScanEnable huga 03~
Aos.Call \w BluetoothTest.SetFilter huga ~
~

Aos.Call BluetoothTest.L2CAPConnect BTTest  4578ACD90A00 ~
Aos.Call BluetoothTest.L2CAPPing BTTest 820914378000 ~
Aos.Call BluetoothTest.L2CAPConnect BTTest 94CB16378000 ~
Aos.Call BluetoothTest.L2CAPConfigure BTTest 3 16384 0 0 ~
Aos.Call BluetoothTest.L2CAPPollChannel BTTest 3 1 ~
Aos.Call BluetoothTest.L2CAPSendString BTTest 3 hello-philipp ~
 ~

Configuration.DoCommands
Aos.Call \w BluetoothTest.Reset BTTest ~
Aos.Call \w BluetoothTest.Reset huga ~
Aos.Call \w BluetoothTest.Close BTTest ~
Aos.Call \w BluetoothTest.Close huga ~
System.Free BluetoothTest V24IO V24 BTConnector BluetoothL2CAP BluetoothStream BluetoothHCI BluetoothUART Bluetooth~
~

**** open device ****
Aos.Call BluetoothTest.Open BTTest 1 57600 8 0 1~	Aos.Call BluetoothTest.Open huga 2 57600 8 0 1 R~
Aos.Call BluetoothTest.Close BTTest ~	Aos.Call BluetoothTest.Close huga ~
Aos.Call BluetoothTest.TraceMode BTTest T ~	Aos.Call BluetoothTest.TraceMode huga R ~

**** L2CAP ****
Aos.Call BluetoothTest.L2CAPInit BTTest ~	Aos.Call BluetoothTest.L2CAPInit huga ~
Aos.Call BluetoothTest.L2CAPClose BTTest ~	Aos.Call BluetoothTest.L2CAPClose huga ~

Aos.Call BluetoothTest.L2CAPPing BTTest 820914378000 ~
Aos.Call BluetoothTest.L2CAPPing BTTest CB0814378000 ~
Aos.Call BluetoothTest.L2CAPPing BTTest 6BF257DC1000 ~
Aos.Call BluetoothTest.L2CAPPing BTTest 98CB16378000 ~
Aos.Call BluetoothTest.L2CAPSendInfoReq BTTest 820914378000 ~
Aos.Call BluetoothTest.L2CAPConnect BTTest 95CB16378000 ~
Aos.Call BluetoothTest.L2CAPConnect BTTest 6BF257DC1000 ~
Aos.Call BluetoothTest.L2CAPConnect BTTest 65B316378000 ~
Aos.Call BluetoothTest.L2CAPConnect BTTest 820914378000 ~
Aos.Call BluetoothTest.L2CAPConnect BTTest BFA1EE378000 ~
Aos.Call BluetoothTest.L2CAPConfigure BTTest 3 1200 0 0 ~

**** HCI level ****
Aos.Call BluetoothTest.ReadLocalName BTTest ~	Aos.Call BluetoothTest.ReadLocalName huga ~
Aos.Call BluetoothTest.ChangeLocalName BTTest romiro ~	Aos.Call BluetoothTest.ChangeLocalName huga huga ~
Aos.Call BluetoothTest.ReadClassOfDevice BTTest ~	Aos.Call BluetoothTest.ReadClassOfDevice huga ~
Aos.Call BluetoothTest.WriteClassOfDevice BTTest 040420 ~	Aos.Call BluetoothTest.WriteClassOfDevice huga 040420 ~
Aos.Call BluetoothTest.ReadBDAddr BTTest ~	Aos.Call BluetoothTest.ReadBDAddr huga ~
Aos.Call BluetoothTest.ReadLocalSupportedFeatures BTTest ~	Aos.Call BluetoothTest.ReadLocalSupportedFeatures huga ~

Aos.Call BluetoothTest.ReadScanEnable BTTest ~	Aos.Call BluetoothTest.ReadScanEnable huga ~
Aos.Call BluetoothTest.WriteScanEnable BTTest 03 ~	Aos.Call BluetoothTest.WriteScanEnable huga 03 ~
Aos.Call BluetoothTest.ReadPageScanActivity BTTest ~	Aos.Call BluetoothTest.ReadPageScanActivity huga ~
Aos.Call BluetoothTest.WritePageScanActivity BTTest 1024 25~	Aos.Call BluetoothTest.WritePageScanActivity huga 4096 20~
Aos.Call BluetoothTest.ReadInquiryScanActivity BTTest ~	Aos.Call BluetoothTest.ReadInquiryScanActivity huga ~
Aos.Call BluetoothTest.WriteInquiryScanActivity BTTest 0801H 013H~	Aos.Call BluetoothTest.WriteInquiryScanActivity huga ~

Aos.Call BluetoothTest.Inquiry BTTest 9E8B33 08H 0~	Aos.Call BluetoothTest.Inquiry huga 9E8B33 08H 0~


Aos.Call BluetoothTest.ListHCIConnections BTTest ~	Aos.Call BluetoothTest.ListHCIConnections huga ~

Aos.Call BluetoothTest.Reset BTTest ~	Aos.Call BluetoothTest.Reset huga ~
Aos.Call BluetoothTest.WriteScanEnable BTTest 03~	Aos.Call BluetoothTest.WriteScanEnable huga 03~
Aos.Call BluetoothTest.SetFilter BTTest ~	Aos.Call BluetoothTest.SetFilter huga ~
Aos.Call BluetoothTest.ConnectTo BTTest 95CB16378000 0~	Aos.Call BluetoothTest.ConnectTo huga CB0814378000 0~
Aos.Call BluetoothTest.ConnectTo BTTest BFA1EE378000 0~	Aos.Call BluetoothTest.ConnectTo huga 96CB16378000 0~
Aos.Call BluetoothTest.ConnectTo BTTest CB0814378000 0~
Aos.Call BluetoothTest.ConnectTo BTTest 820914378000 0~

Aos.Call BluetoothTest.ReadClockOffset BTTest 2 ~	Aos.Call BluetoothTest.ReadClockOffset huga 1 ~
Aos.Call BluetoothTest.SendACL BTTest 1 0 414243444546~	Aos.Call BluetoothTest.SendACL huga 1 0 01~

Aos.Call BluetoothTest.TestStringToParam 00 01 02 FF 04 05 06~
*)