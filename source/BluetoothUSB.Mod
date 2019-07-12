MODULE BluetoothUSB; (** AUTHOR "staubesv"; PURPOSE "HCI USB Transport Layer"; *)
(**
 *
 * History:
 *
 *	01.12.2005 Cleanup (staubesv)
 *)

IMPORT KernelLog, Streams, Plugins, Bluetooth, UsbBluetooth, Usb, Usbdi;

TYPE

	UsbTransportLayer* = OBJECT(Bluetooth.TransportLayer)
	VAR
		driver : UsbBluetooth.BluetoothDriver;
		TraceReceive*, TraceSend*: BOOLEAN;

		event : Bluetooth.EventPacket; (* for EventHandler, must be global *)

		eventExpectedParams : LONGINT; (* expected length of parameters in bytes *)
		eventParamOffset : LONGINT;

		acl: Bluetooth.ACLPacket;
		aclExpectedParams : LONGINT; (* expected length of parameters in bytes *)
		aclParamOffset : LONGINT;

		PROCEDURE &Init*(name: ARRAY OF CHAR; sender: Streams.Sender; receiver: Streams.Receiver);
		VAR plugin : Plugins.Plugin;
		BEGIN
			Init^(name,NIL,NIL);
			TraceSend := FALSE; TraceReceive := FALSE;
			plugin := Usb.usbDrivers.Get(name);
			IF plugin = NIL THEN
				KernelLog.String("UsbBluetooth: "); KernelLog.String(name); KernelLog.String(" no found."); KernelLog.Ln;
			ELSE
				driver:=plugin(UsbBluetooth.BluetoothDriver);
				driver.SetEventHandler(EventHandler);
				driver.SetAclHandler(ReadACL);
			END;
		END Init;

		PROCEDURE Init2*(name: ARRAY OF CHAR): BOOLEAN;
		VAR plugin : Plugins.Plugin;
		BEGIN
			(* provisorisch *)
			TraceSend:=TRUE; TraceReceive:=TRUE;
			plugin := Usb.usbDrivers.Get(name);
			IF plugin=NIL THEN
				KernelLog.String("UsbBluetooth: "); KernelLog.String(name); KernelLog.String(" no found."); KernelLog.Ln;
				RETURN FALSE;
			END;
			driver := plugin(UsbBluetooth.BluetoothDriver);
			driver.SetEventHandler(EventHandler);
			driver.SetAclHandler(ReadACL);
			RETURN TRUE;
		END Init2;

		PROCEDURE Close*;
		END Close;

		(** receives HCI event packet fragments (each fragment 16 bytes)  and enters them into the event queue *)
		PROCEDURE EventHandler(packet : Usbdi.Buffer; actLen : LONGINT);
		VAR
			i : LONGINT;
			eventQueue : Bluetooth.Queue;

			PROCEDURE DeliverPacket;
			BEGIN
				ASSERT((event#NIL));
				IF TraceReceive THEN KernelLog.String("UsbBluetooth: EventHandler: Packet added to event queue.");
				KernelLog.Ln; KernelLog.Ln;
				END;
				eventQueue := sink[Bluetooth.Event];
				eventQueue.Add(event);
				eventParamOffset:=0; eventExpectedParams:=0;
				event:=NIL;
			END DeliverPacket;

		BEGIN
			IF TraceReceive THEN
				KernelLog.String("UsbBluetooth: ") ; KernelLog.String(driver.name);
				KernelLog.String(": EventHandler: Incoming: "); KernelLog.Int(actLen, 0); KernelLog.String(" Byte(s): ");
				KernelLog.Ln;
			END;
			IF event=NIL THEN (* should be the beginning of a new event packet *)

				IF TraceReceive THEN
					KernelLog.String("New packet: "); ShowEvent(ORD(packet[0]));
					KernelLog.String(", "); KernelLog.Int(ORD(packet[1]), 0); KernelLog.String(" Byte(s) params:  ");
					FOR i := 0 TO actLen-1 DO KernelLog.Hex(ORD(packet[i]), -2); KernelLog.Char(" ") END;
					(* if the packet contains status information, display it as text ... *)
					i := ORD(packet[0]);
					IF (i = 01H) OR (i=03H) OR ((i >= 05H) & (i<=0DH)) OR (i=0FH) OR (i=12H) OR (i=14H) OR (i=1CH) OR (i=1DH) THEN
						KernelLog.String("Status : "); ShowErrorCode(ORD(packet[2]));
					END;
					KernelLog.Ln;
				END;
				NEW(event);
				event.code:=packet[0];
				event.paramLen := ORD(packet[1]);
				ASSERT(event.paramLen < Bluetooth.MaxEventParamLen);
				IF event.paramLen>14 THEN (* there will be more fragments of this event packet *)
					eventExpectedParams := event.paramLen-14 ;
					ASSERT(actLen=16);
					FOR i:=0 TO 13 DO event.params[i] := packet[2+i]; END;
					eventParamOffset := 16;

				ELSE (* cool! parameters fit into this packet *)
					ASSERT(actLen=2+event.paramLen);
					FOR i:=0 TO event.paramLen-1 DO event.params[i]:=packet[2+i]; END;
					DeliverPacket;
				END;

			ELSE (* next fragment of packet *)

				IF TraceReceive THEN
					KernelLog.String("Fragment: "); FOR i := 0 TO LEN(packet)-1 DO KernelLog.Hex(ORD(packet[i]), -2); KernelLog.Char(" ") END;KernelLog.Ln;
				END;
				IF eventExpectedParams <= 16 THEN (* fits in this packet *)
					ASSERT(actLen=eventExpectedParams);
					FOR i:=0 TO eventExpectedParams-1 DO event.params[eventParamOffset+i]:=packet[i];END;
					DeliverPacket;
				ELSE (* there will be at least on more packet *)
					ASSERT(actLen=16);
					eventExpectedParams:=eventExpectedParams-16;
					eventParamOffset:=eventParamOffset+16;
					FOR i:=0 TO 15 DO event.params[eventParamOffset+i]:=packet[i]; END;
				END;
			END;
		END EventHandler;

		PROCEDURE ReadACL(packet : Usbdi.Buffer; actLen : LONGINT);
		VAR
			queue: Bluetooth.Queue;
			i: LONGINT;

			PROCEDURE DeliverPacket;
			BEGIN
				ASSERT(acl#NIL);
				queue := sink[Bluetooth.ACL];
				queue.Add(acl);
				aclParamOffset:=0; aclExpectedParams:=0;
				acl:=NIL;
			END DeliverPacket;

		BEGIN
			IF TraceReceive THEN KernelLog.String("UsbBluetooth: Device "); KernelLog.String(name); KernelLog.String(" receives ACL: "); END;
			IF acl=NIL THEN (* should be the beginning of a new acl packet *)

				NEW(acl);
				i := ORD(packet[0]) + ORD(packet[1])*100H;
				acl.handle := i MOD 1000H;
				acl.PB := (i DIV 1000H) MOD 4;
				acl.BC := (i DIV 4000H) MOD 4;
				acl.len := ORD(packet[2]) + ORD(packet[3])*100H;
				ASSERT(acl.len <= Bluetooth.MaxACLDataLen);
				IF TraceReceive THEN
					KernelLog.String("New Packet: "); KernelLog.Int(acl.len, 0); KernelLog.String(" Byte(s): ");
					FOR i:=0 TO actLen-1 DO KernelLog.Hex(ORD(packet[i]),-2); KernelLog.Char(" "); END;
					KernelLog.Ln;
				END;

				IF acl.len>60 THEN (* there will be more fragments of this ACL packet *)
					aclExpectedParams := acl.len-60 ;
					ASSERT(actLen=64);
					FOR i:=0 TO 59 DO acl.data[i] := packet[4+i]; END;
					aclParamOffset := 64;

				ELSE (* cool. parameters fit into this packet *)
					ASSERT(actLen=4+acl.len);
					FOR i:=0 TO acl.len-1 DO acl.data[i]:=packet[4+i]; END;
					DeliverPacket;
				END;

			ELSE (* next fragment of packet *)

				IF TraceReceive THEN
					KernelLog.String("Fragment: "); FOR i:=0 TO actLen-1 DO KernelLog.Hex(ORD(packet[i]),-2); KernelLog.Char(" "); END;
					KernelLog.Ln;
				END;
				IF aclExpectedParams <= 64 THEN (* fits in this packet *)
					ASSERT(actLen=aclExpectedParams);
					FOR i:=0 TO aclExpectedParams-1 DO acl.data[aclParamOffset+i]:=packet[i];END;
					DeliverPacket;
				ELSE (* there will be at least on more packet *)
					ASSERT(actLen=64);
					FOR i:=0 TO 63 DO acl.data[aclParamOffset+i]:=packet[i]; END;
					aclExpectedParams:=aclExpectedParams-64;
					aclParamOffset:=aclParamOffset+64;
				END;
			END;
		END ReadACL;

		PROCEDURE Send*(type: LONGINT; VAR data: ARRAY OF CHAR; ofs, len: LONGINT; VAR res: WORD);
		VAR  i: LONGINT;
		BEGIN {EXCLUSIVE}
			IF TraceSend THEN
				KernelLog.Ln;
				KernelLog.String("UsbBluetooth: Send: "); KernelLog.String(name); KernelLog.String(": ");
				KernelLog.Hex(type, -2); KernelLog.Char(" ");
				FOR i := 0 TO len-1 DO KernelLog.Hex(ORD(data[ofs+i]), -2); KernelLog.Char(" ") END;
				KernelLog.Ln;
			END;
			CASE type OF
				| Bluetooth.Command:   driver.SendCommand(data, ofs, len, res);
				| Bluetooth.ACL: driver.SendACL(data, ofs, len, res);
				(* Bluetooth.Event cannot be send to the host controller; Bluetooth.SCO would require isochronous USB transfers, which
				are not yet implemented *)
			ELSE
				IF TraceSend THEN KernelLog.String("wrong packet type"); KernelLog.Ln; END;
				res := Bluetooth.ErrInvalidParameters;
			END;
		END Send;

		PROCEDURE Send1H*(type: LONGINT; VAR hdr: ARRAY OF CHAR; hdrlen: LONGINT; VAR data: ARRAY OF CHAR; ofs, len: LONGINT; VAR res: WORD);
		VAR  i: LONGINT; buffer : POINTER TO ARRAY OF CHAR; bufferLen : LONGINT;
		BEGIN
			IF TraceSend THEN
				KernelLog.Ln;
				KernelLog.String("UsbBluetooth: "); KernelLog.String(name); KernelLog.String(": Send1H:");
				KernelLog.String(" HdrLen: "); KernelLog.Int(hdrlen, 0); KernelLog.String(" DataLen: "); KernelLog.Int(len, 0);
				KernelLog.String(" DataOfs: "); KernelLog.Int(ofs, 0); KernelLog.String(" Type: "); KernelLog.Hex(type, -2);
				KernelLog.String(" Hdr: "); FOR i := 0 TO hdrlen-1 DO KernelLog.Hex(ORD(hdr[i]), -2); KernelLog.Char(" ") END;
				KernelLog.String(" Data: "); FOR i := 0 TO len-1 DO KernelLog.Hex(ORD(data[ofs+i]), -2); KernelLog.Char(" ") END;
				KernelLog.Ln
			END;
			bufferLen := hdrlen + len;
			NEW(buffer,bufferLen);

			FOR i:=0 TO hdrlen-1 DO buffer[i]:=hdr[i]; END;
			FOR i:=0 TO len-1 DO buffer[i+hdrlen]:=data[ofs+i]; END;

			CASE type OF
				| Bluetooth.Command:   driver.SendCommand(buffer^, 0, bufferLen, res);
				| Bluetooth.ACL: driver.SendACL(buffer^, 0, bufferLen, res);
				(* Bluetooth.Event cannot be send to the host controller; Bluetooth.SCO would require isochronous USB transfers, which
				are not yet implemented *)
			ELSE
				IF TraceSend THEN KernelLog.String("wrong packet type"); KernelLog.Ln; END;
				res:=Bluetooth.ErrInvalidParameters;
			END;
		END Send1H;

		PROCEDURE Send2H*(type: LONGINT; VAR hdr1: ARRAY OF CHAR; hdr1len: LONGINT;
				VAR hdr2: ARRAY OF CHAR; hdr2len: LONGINT; VAR data: ARRAY OF CHAR; ofs, len: LONGINT; VAR res: WORD);
		VAR
			i: LONGINT;
			buffer : POINTER TO ARRAY OF CHAR;
			bufferLen : LONGINT;
		BEGIN
			IF TraceSend THEN
				KernelLog.String("UsbBluetooth: Send2H: "); KernelLog.String(name); KernelLog.String(": ");
				KernelLog.Hex(type, -2); KernelLog.Char(" ");
				FOR i := 0 TO hdr1len-1 DO KernelLog.Hex(ORD(hdr1[i]), -2); KernelLog.Char(" ") END;
				FOR i := 0 TO hdr2len-1 DO KernelLog.Hex(ORD(hdr2[i]), -2); KernelLog.Char(" ") END;
				FOR i := 0 TO len-1 DO KernelLog.Hex(ORD(data[ofs+i]), -2); KernelLog.Char(" ") END;
				KernelLog.Ln
			END;
			bufferLen:=hdr1len+hdr2len+len;
			NEW(buffer,bufferLen);

			FOR i:=0 TO hdr1len-1 DO buffer[i]:=hdr1[i]; END;
			FOR i:=0 TO hdr2len-1 DO buffer[hdr1len+i]:=hdr2[i]; END;
			FOR i:=0 TO len-1 DO buffer[i+hdr1len+hdr2len]:=data[ofs+i]; END;

			CASE type OF
				| Bluetooth.Command:   driver.SendCommand(buffer^, 0, bufferLen, res);
				| Bluetooth.ACL: driver.SendACL(buffer^, 0, bufferLen, res);
				(* Bluetooth.Event cannot be send to the host controller; Bluetooth.SCO would require isochronous USB transfers, which
				are not yet implemented *)
			ELSE
				IF TraceSend THEN KernelLog.String("wrong packet type"); KernelLog.Ln; END;
				res := Bluetooth.ErrInvalidParameters;
			END;
		END Send2H;

	END UsbTransportLayer;

PROCEDURE ShowEvent(event : LONGINT);
BEGIN
	CASE event OF
		 01H: KernelLog.String("Inquiry Compete");
		|02H: KernelLog.String("Inquiry Result");
		|03H: KernelLog.String("Connection Complete");
		|04H: KernelLog.String("Connection Request");
		|05H: KernelLog.String("Disconnection Complete");
		|06H: KernelLog.String("Authentication Complete");
		|07H: KernelLog.String("Remote Name Request Complete");
		|08H: KernelLog.String("Encryption Change");
		|09H: KernelLog.String("Change Connection Link Key Complete");
		|0AH: KernelLog.String("Master Link Key Complete");
		|0BH: KernelLog.String("Read Remote Supported Features Complete");
		|0CH: KernelLog.String("Read Remote Version Information Complete");
		|0DH: KernelLog.String("QoS Setup Complete");
		|0EH: KernelLog.String("Command Complete");
		|0FH: KernelLog.String("Command Status");
		|10H: KernelLog.String("Hardware Error");
		|11H: KernelLog.String("Flush Occured");
		|12H: KernelLog.String("Role Change");
		|13H: KernelLog.String("Number Of Completed Packets");
		|14H: KernelLog.String("Mode Change");
		|15H: KernelLog.String("Return Link Keys");
		|16H: KernelLog.String("PIN Code Request");
		|17H: KernelLog.String("Link Key Request");
		|18H: KernelLog.String("Link Key Notification");
		|19H: KernelLog.String("Loopback Command");
		|1AH: KernelLog.String("Data Buffer Overflow");
		|1BH: KernelLog.String("Max Slots Change");
		|1CH: KernelLog.String("Read Clock Offset Complete");
		|1DH: KernelLog.String("Connection Packet Type Changed");
		|1EH: KernelLog.String("QoS Violation");
		|1FH: KernelLog.String("Page Scan Mode Change");
		|20H: KernelLog.String("Page Scan Repetition Mode Change");
		|0FEH: KernelLog.String("Bluetooth Logo Testing");
		|0FFH: KernelLog.String("Vendor-specific");
	ELSE
		KernelLog.String("Unkown");
	END;
END ShowEvent;

PROCEDURE ShowErrorCode(errorcode : LONGINT);
BEGIN
	CASE errorcode OF
		00H: KernelLog.String("OK");
		| 01H: KernelLog.String("Unknown HCI Command");
		| 02H: KernelLog.String("No Connection");
		| 03H: KernelLog.String("Hardware Failure");
		| 04H: KernelLog.String("Page Timeout");
		| 05H: KernelLog.String("Authentication Failure");
		| 06H: KernelLog.String("Key Missing");
		| 07H: KernelLog.String("Memory Full");
		| 08H: KernelLog.String("Connection Timeout");
		| 09H: KernelLog.String("Max Number Of Connections");
		| 0AH: KernelLog.String("Max Number Of SCO Connection To A Device");
		| 0BH: KernelLog.String("ACL Connection Already Exists");
		| 0CH: KernelLog.String("Command Disallowed");
		| 0DH: KernelLog.String("Host Rejected due to limited resources");
		| 0EH: KernelLog.String("Host Rejected due to security reasons");
		| 0FH: KernelLog.String("Host Rejected (Remote Device is personal device)");
		| 10H: KernelLog.String("Host Timeout");
		| 11H: KernelLog.String("Unsupported Feature or Parameter Value");
		| 12H: KernelLog.String("Invalid HCI Command Parameters");
		| 13H: KernelLog.String("Other End Terminated Connection (User ended connection)");
		| 14H: KernelLog.String("Other End Terminated Connection (Low Resources)");
		| 15H: KernelLog.String("Other End Terminated Connection (About to Power Off)");
		| 16H: KernelLog.String("Connection Terminated by Local Host");
		| 17H: KernelLog.String("Repeated Attempts");
		| 18H: KernelLog.String("Pairing Not Allowd");
		| 19H: KernelLog.String("Unknown LMP PDU");
		| 1AH: KernelLog.String("Unsupported Remote Feature");
		| 1BH: KernelLog.String("SCO Offset Rejected");
		| 1CH: KernelLog.String("SCO Interval Rejected");
		| 1DH: KernelLog.String("SCO Airmode Rejected");
		| 1EH: KernelLog.String("Invalid LMP Parameters");
		| 1FH: KernelLog.String("Unspecified Error");
		| 20H: KernelLog.String("Unsupported LMP Parameter Value");
		| 21H: KernelLog.String("Role Change Not Allowed");
		| 22H: KernelLog.String("LMP Response Timeout");
		| 23H: KernelLog.String("LMP Error Transaction Collision");
		| 24H: KernelLog.String("LMP PDU Not Allowed");
		| 25H: KernelLog.String("Encryption Mode Not Acceptable");
		| 26H: KernelLog.String("Unit Key Used");
		| 27H: KernelLog.String("QoS is Not Supported");
		| 28H: KernelLog.String("Instant Passed");
		| 29H: KernelLog.String("Pairing with Unit Key Not Supported");
		| 2AH..0FFH: KernelLog.String("Reserved for Future Use");
	ELSE
		KernelLog.String("Unknown");
	END;
END ShowErrorCode;

END BluetoothUSB.

