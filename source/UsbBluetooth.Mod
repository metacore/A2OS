MODULE  UsbBluetooth; (** AUTHOR "staubesv"; PURPOSE "USB device driver for USB bluetooth dongles"; *)
(**
 * This Module implements
 *	a) A USB bluetooth dongle driver
 *	b) Bluetooth USB Transport Layer
 *
 * Usage:
 *	UsbBluetooth.Install ~ loads this driver
 *	System.Free UsbBluetooth ~ unloads it
 *
 * History:
 *
 *	01.12.2005	Adapted to new USB system software, renamed procedure Init to Install, removed obsolete imports  (staubesv)
 *	12.12.2005	Adapted to new USBDI (staubesv)
 *	05.07.2006	Adapted to Usbdi (staubesv)
 *)

IMPORT KernelLog, Modules, Usbdi;

CONST

	Name = "UsbBluetooth";
	Description = "USB bluetooth dongle driver";

	Debug = FALSE;

TYPE

	Handler = PROCEDURE {DELEGATE} (packet : Usbdi.Buffer; actLen : LONGINT);

TYPE

	BluetoothDriver* = OBJECT (Usbdi.Driver)
	VAR
		eventIn, aclIn, aclOut, defaultpipe : Usbdi.Pipe;
		hciEvent : Usbdi.BufferPtr;
		aclData : Usbdi.BufferPtr;
		eventHandler, aclHandler : Handler;
		status : Usbdi.Status;

		PROCEDURE Connect*():BOOLEAN;
		VAR interruptInAdr, bulkInAdr, bulkOutAdr : LONGINT;
		BEGIN
			(* get the USB pipes *)
			defaultpipe := device.GetPipe(0);
			IF defaultpipe = NIL THEN
				IF Debug THEN KernelLog.String("UsbBluetooth: Error: Couldn't get default control pipe."); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			IF ~GetEndpointAddresses(interruptInAdr, bulkInAdr, bulkOutAdr, interface.endpoints^) THEN
				IF Debug THEN KernelLog.String("UsbBluetooth: Error: Endpoint expectations not met."); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			eventIn := device.GetPipe(interruptInAdr);
			IF eventIn = NIL THEN
				IF Debug THEN KernelLog.String("UsbBluetooth: Error: Couldn't get interrupt in pipe."); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			aclIn := device.GetPipe(bulkInAdr);
			aclOut := device.GetPipe(bulkOutAdr);
			IF (aclIn = NIL) OR (aclOut = NIL) THEN
				IF Debug THEN KernelLog.String("UsbBluetooth: Error: Couldn't get bulk in/out pipes."); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			(* register pipe handlers and setup IN transfers *)
			eventIn.SetCompletionHandler(HciEventHandler);
			eventIn.SetTimeout(0);
			status := eventIn.Transfer(16, 0, hciEvent^);

			aclIn.SetCompletionHandler(ReadACL);
			aclIn.SetTimeout(0); (* non-blocking *)
			status := aclIn.Transfer(64, 0, aclData^);

			RETURN TRUE;
		END Connect;

		PROCEDURE Disconnect*;
		BEGIN
			KernelLog.String("USB Blueetooth dongle "); KernelLog.String(name); KernelLog.String(" disconnected."); KernelLog.Ln;
		END Disconnect;

		PROCEDURE SendACL*(VAR buf: ARRAY OF CHAR; ofs, len: LONGINT; VAR res : WORD);
		VAR
			buffer : Usbdi.BufferPtr;
			status : Usbdi.Status;
			i : LONGINT;
		BEGIN
			NEW(buffer, len); FOR i:=0 TO len-1 DO	buffer[i] := buf[i]; END;
			status := aclOut.Transfer(len, ofs, buffer^);
			IF (status = Usbdi.Ok) OR (status = Usbdi.ShortPacket) THEN res := 0; ELSE res := 1; END;
		END SendACL;

		PROCEDURE ReadACL*(status : Usbdi.Status; actLen : LONGINT);
		BEGIN
			IF Debug THEN KernelLog.String("UsbBluetooth: Received data ACL In Pipe."); KernelLog.Ln;END;
			IF (status = Usbdi.Ok) OR ((status = Usbdi.ShortPacket) & (actLen > 0)) THEN (* received ACL data *)
				IF aclHandler # NIL THEN aclHandler(aclData^, actLen); END;
				status := aclIn.Transfer(64, 0, aclData^); (* ignore result *)
			END;
		END ReadACL;

		PROCEDURE SendCommand*(buf: ARRAY OF CHAR; ofs, len: LONGINT; VAR res: WORD);
		VAR
			buffer : Usbdi.BufferPtr;
			status : Usbdi.Status;
			i : LONGINT;
		BEGIN
			NEW(buffer, len); FOR i:=0 TO len-1 DO buffer[i] := buf[i]; END;
			status :=defaultpipe.Request(Usbdi.ToDevice  + Usbdi.Class + Usbdi.Endpoint, 0, 0, 0, len, buffer^);
			IF (status = Usbdi.Ok) OR (status = Usbdi.ShortPacket) THEN res := 0; ELSE res := 1; END;
		END SendCommand;

		PROCEDURE SetEventHandler*(proc : Handler);
		BEGIN
			eventHandler:=proc;
		END SetEventHandler;

		PROCEDURE SetAclHandler*(proc: Handler);
		BEGIN
			aclHandler:=proc;
		END SetAclHandler;

		PROCEDURE HciEventHandler(status : Usbdi.Status; actLen : LONGINT);
		BEGIN
			IF (status = Usbdi.Ok) OR ((status = Usbdi.ShortPacket) & (actLen > 0)) THEN
				IF eventHandler # NIL THEN eventHandler(hciEvent^, actLen); END;
				status := eventIn.Transfer(16, 0, hciEvent^);
			ELSE
				IF Debug THEN KernelLog.String("UsbBluetooth: HCI Event Handling: Error."); KernelLog.Ln; END;
			END;
		END HciEventHandler;

		PROCEDURE &Init*;
		BEGIN
			NEW(hciEvent, 16);
			NEW(aclData, 64);
		END Init;

	END BluetoothDriver;

PROCEDURE GetEndpointAddresses(VAR interruptIn, bulkIn, bulkOut : LONGINT; CONST endpoints : ARRAY OF Usbdi.EndpointDescriptor) : BOOLEAN;
VAR i : LONGINT;
BEGIN
	interruptIn := 0; bulkIn := 0; bulkOut := 0;
	IF (LEN(endpoints) # 3) THEN RETURN FALSE; END;
	FOR i := 0 TO 2 DO
		IF (endpoints[i].type = Usbdi.InterruptIn) THEN interruptIn := endpoints[i].bEndpointAddress;
		ELSIF (endpoints[i].type = Usbdi.BulkIn) THEN bulkIn := endpoints[i].bEndpointAddress;
		ELSIF (endpoints[i].type = Usbdi.BulkOut) THEN bulkOut := endpoints[i].bEndpointAddress;
		END;
	END;
	RETURN (interruptIn # 0) & (bulkIn # 0) & (bulkOut # 0);
END GetEndpointAddresses;

PROCEDURE Probe(dev : Usbdi.UsbDevice; id : Usbdi.InterfaceDescriptor) : Usbdi.Driver;
VAR driver : BluetoothDriver; ignore : LONGINT;
BEGIN
	(* check whether the probed device is a supported USB bluetooth dongle *)
	IF id.bInterfaceClass # 224 THEN RETURN NIL END; (* Wireless Controller *)
	IF id.bInterfaceSubClass # 1 THEN RETURN NIL END; (* Bluetooth Programming Interface *)
	IF id.bInterfaceProtocol # 1 THEN RETURN NIL END;

	(* We expect an interrupt IN, a bulk IN and a bulk out endpoint *)
	IF id.bNumEndpoints # 3 THEN RETURN NIL; END;

	IF ~GetEndpointAddresses(ignore, ignore, ignore, id.endpoints^) THEN RETURN NIL; END;

	KernelLog.String("USB bluetooth dongle found."); KernelLog.Ln;
	NEW(driver);
	RETURN driver;
END Probe;

PROCEDURE Install*;
(* load module *)
END Install;

PROCEDURE Cleanup;
BEGIN
	Usbdi.drivers.Remove(Name);
END Cleanup;

BEGIN
	Usbdi.drivers.Add(Probe, Name, Description,10);
	Modules.InstallTermHandler(Cleanup);
END UsbBluetooth.

System.Free UsbBluetooth ~  UsbBluetooth.Install ~