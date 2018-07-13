MODULE UsbMouse;  (** AUTHOR "staubesv"; PURPOSE "USB Mouse Driver"; *)
(**
 * Bluebottle USB Mouse Driver (HID boot protocol)
 *
 * Usage:
 *	UsbMouse.Install ~ loads this driver
 *	SystemTools.Free UsbMouse ~ unloads this driver
 *
 *	The HID boot protocol for USB mice supports 3 buttons and 2 axes.
 *
 * References:
 *	Device Class Definition for Human Interface Devices (HID), Version 1.11, 27.06.2001, www.usb.org
 *
 * History:
 *	01.12.2005	Added MouseSpeed & MouseAcceleration (staubesv)
 *	10.10.2006	Adapted to UsbHid (staubesv)
 *	28.02.2007	Removed mouse wheel hack since new HID driver can correctly handle it (staubesv)
 *)

IMPORT SYSTEM, KernelLog, Modules, Inputs, Usbdi, UsbHid;

CONST

	Name = "UsbMouse";
	Description = "HID boot protocol mouse driver";

	(* Mouse Configuration *)
	MouseSpeed = 50;
	MouseAcceleration = 0;

	Debug = TRUE;

TYPE

	MouseDriver= OBJECT (UsbHid.HidDriver);
	VAR
		buffer : Usbdi.BufferPtr;
		pipe : Usbdi.Pipe;

		lastDx, lastDy : LONGINT;
		accelX, accelY : REAL;

		PROCEDURE HandleEvent(status : Usbdi.Status; actLen : LONGINT);
		VAR mm : Inputs.MouseMsg; dx, dy : LONGINT;
		BEGIN
			IF (status = Usbdi.Ok) OR ((status = Usbdi.ShortPacket) & (actLen >= 3))  THEN
				dx := SYSTEM.VAL(SHORTINT, buffer[1]);
				dy := SYSTEM.VAL(SHORTINT, buffer[2]);

				accelX := 1.0 + ABS(dx - lastDx) / 128 * MouseAcceleration;
				accelY := 1.0 + ABS(dy - lastDy) / 128 * MouseAcceleration;

				lastDx := dx;
				lastDy := dy;

				mm.dx :=ENTIER(MouseSpeed / 50.0 *  dx * accelX);
				mm.dy := ENTIER(MouseSpeed / 50.0 * dy * accelY);

				IF (SYSTEM.VAL(SET, buffer[0]) * {0}) # {} THEN mm.keys := mm.keys + {0}; END;
				IF (SYSTEM.VAL(SET, buffer[0]) * {1}) # {} THEN mm.keys := mm.keys + {2}; END;
				IF (SYSTEM.VAL(SET, buffer[0]) * {2}) # {} THEN mm.keys := mm.keys + {1}; END;

				Inputs.mouse.Handle(mm);
				status := pipe.Transfer(pipe.maxPacketSize, 0, buffer);
			ELSE
				IF status = Usbdi.Stalled THEN
					IF pipe.ClearHalt() THEN
						IF Debug THEN KernelLog.String("UsbMouse: Stall on Interrupt Pipe cleared."); KernelLog.Ln; END;
						status := pipe.Transfer(pipe.maxPacketSize, 0, buffer); (* ignore status *)
					ELSE
						IF Debug THEN KernelLog.String("UsbMouse: Couldn't clear stall on interrupt pipe. Abort."); KernelLog.Ln; END;
						device.FreePipe(pipe);
					END;
				END;
			END;
		END HandleEvent;

		PROCEDURE Connect() : BOOLEAN;
		VAR endpoint, i : LONGINT; status : Usbdi.Status;
		BEGIN
			(* Set the HID boot protocol *)
			IF SetProtocol(UsbHid.BootProtocol) = FALSE THEN
				IF Debug THEN KernelLog.String("UsbMouse: Error: Cannot set boot protocol."); KernelLog.Ln; END;
				RETURN FALSE
			END;

			(* Look for the first interrupt IN endpoint of this device *)
			LOOP
				IF i >= LEN(interface.endpoints) THEN EXIT; END;
				IF interface.endpoints[i].type = Usbdi.InterruptIn THEN
					endpoint := interface.endpoints[i].bEndpointAddress;
					EXIT;
				END;
				INC(i);
			END;

			IF endpoint = 0 THEN
				IF Debug THEN KernelLog.String("UsbMouse: No interrupt IN endpoint found."); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			pipe := device.GetPipe(endpoint);
			IF pipe = NIL THEN RETURN FALSE END;

			NEW(buffer, pipe.maxPacketSize);

			pipe.SetTimeout(0);
			pipe.SetCompletionHandler(HandleEvent);

			status := pipe.Transfer(pipe.maxPacketSize, 0, buffer); (* ignore res *)
			RETURN TRUE;
		END Connect;

		PROCEDURE Disconnect;
		BEGIN
			KernelLog.String("USB mouse disconnected."); KernelLog.Ln;
		END Disconnect;

	END MouseDriver;

PROCEDURE Probe(dev : Usbdi.UsbDevice; id : Usbdi.InterfaceDescriptor) : Usbdi.Driver;
VAR driver : MouseDriver;
BEGIN
	IF id.bInterfaceClass # 3 THEN RETURN NIL END; (* HID class *)
	IF id.bInterfaceSubClass # 1 THEN RETURN NIL END; (* Boot protocol subclass *)
	IF id.bInterfaceProtocol # 2 THEN RETURN NIL END; (* Mouse *)
	NEW(driver); RETURN driver;
END Probe;

PROCEDURE Install*;
END Install;

PROCEDURE Cleanup;
BEGIN
	Usbdi.drivers.Remove(Name);
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	Usbdi.drivers.Add(Probe, Name, Description, 10)
END UsbMouse.

UsbMouse.Install ~  SystemTools.Free UsbMouse ~ 