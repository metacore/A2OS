MODULE UsbStorageBoot; (** AUTHOR "staubesv"; PURPOSE "USB mass storage boot driver"; *)
(**
 * This modules was built to support a smaller USB mass storage device driver to keep to boot file small. It registers
 * the USB mass storage bulk-only device driver at the USB driver manager. This driver will be assigned to exactly
 * one USB mass storage device.
 * The user can set the "SerialNumber" config string to the Boot device's serial number to make sure that the driver
 * is assigned to the correct USB mass storage device in case that multiple USB mass storage devices are connected.
 *)

IMPORT
	Machine, KernelLog, Disks, Plugins,
	UsbUtilities, Usb, Usbdi, Base := UsbStorageBase, BOT := UsbStorageBot;

CONST

	Name = "UsbStorageBoot";
	Description = "USB Mass Storage Boot Driver";
	Priority = 10;

	(* This driver blocks until a device named DefaultBootDevice is made accessible (put into Disks.registry).	*)
	BootDeviceName = "USB0";

VAR
	(* Driver should only be assigned to one device *)
	assigned : BOOLEAN;

	(** 	Serial number of USB mass storage boot device. Can be specified as config string and is used to identify the
		boot device in case that multiple mass storage devices are connected *)
	serialNumber : UsbUtilities.AsciiString;

PROCEDURE Probe(dev : Usbdi.UsbDevice; id : Usbdi.InterfaceDescriptor) : Usbdi.Driver;
VAR
	protocol, i : SIGNED32;
	bulkInEndpoint, bulkOutEndpoint  : SIGNED32;
	bot : BOT.BulkOnlyTransport;
	description : Usbdi.Description;
	driver : Base.StorageDriver;
BEGIN {EXCLUSIVE}
	IF assigned THEN RETURN NIL; END;

	(* Is it a bulk-only transport USB Mass Storage Class device ? *)
	IF id.bInterfaceClass # 8 THEN RETURN NIL END;
	IF id.bInterfaceProtocol # 50H THEN RETURN NIL; END;

	IF ~IsBootDevice(dev.descriptor(Usb.DeviceDescriptor)) THEN RETURN NIL; END;

	CASE id.bInterfaceSubClass OF
		1 : protocol := Base.ProtocolRBC; description := "Usb Reduced Block Command Drive";
		|2 : protocol := Base.Protocol8020; description := "Usb SFF8020i ATAPI device";
		|3 : protocol := Base.ProtocolQIC157; description := "Usb QIC-157 Tape device";
		|4 : protocol := Base.ProtocolUFI; description := "Usb UFI Floppy drive";
		|5 : protocol := Base.Protocol8070; description := "Usb SFF8070i ATAPI device";
		|6 : protocol := Base.ProtocolUTS; description := "Usb Transparent SCSI device";
	ELSE
		RETURN NIL; (* Protocol not supported *)
	END;

	(* now parse all endpoints *)
	IF (id.bNumEndpoints # 2) & (id.bNumEndpoints # 3) THEN RETURN NIL END;

	FOR i := 0 TO id.bNumEndpoints - 1 DO
		IF id.endpoints[i].type = Usbdi.BulkOut THEN
			bulkOutEndpoint := id.endpoints[i].bEndpointAddress;
		ELSIF id.endpoints[i].type = Usbdi.BulkIn THEN
			bulkInEndpoint := id.endpoints[i].bEndpointAddress;
		END;
	END;

	IF (bulkInEndpoint = 0) OR (bulkOutEndpoint = 0) THEN RETURN NIL END;

	NEW(bot); driver := bot;

	driver.bulkIn := bulkInEndpoint;
	driver.bulkOut := bulkOutEndpoint;
	driver.transportProtocol := protocol;
	driver.transportMethod := Base.MethodBulkOnly;
	driver.description := description;
	assigned := TRUE;
	RETURN driver;
END Probe;

(* Block until storage device BootDev has been added to Disks.registry if booting from USB storage device *)
PROCEDURE WaitForBootDevice;
VAR ignore : Plugins.Plugin;
BEGIN
	KernelLog.Enter;
	KernelLog.String("UsbStorageBoot: Booting from USB. Awaiting device "); KernelLog.String(BootDeviceName); KernelLog.String("...");
	KernelLog.Exit;
	ignore :=  Disks.registry.Await(BootDeviceName);
	KernelLog.Enter;
	KernelLog.String("UsbStorageBoot: Boot device "); KernelLog.String(BootDeviceName); KernelLog.String(" connected.");
	KernelLog.Exit;
END WaitForBootDevice;

(* 	If the user has specified the serial number of the device he wants the system to boot from, return TRUE if the
	serial number of the currenlty checked device matches that serial number. Return FALSE otherwise. *)
PROCEDURE IsBootDevice(descriptor : Usb.DeviceDescriptor) : BOOLEAN;
BEGIN
	RETURN (serialNumber^ = "") OR
		((serialNumber^ # "") & (descriptor.sSerialNumber # NIL) & (descriptor.sSerialNumber^ = serialNumber^));
END IsBootDevice;

PROCEDURE GetBootConfiguration;
VAR string : ARRAY 128 OF CHAR;
BEGIN
	string := ""; Machine.GetConfig("SerialNumber", string);
	serialNumber := UsbUtilities.NewString(string);
	IF (serialNumber^ # "") THEN
		KernelLog.Enter;
		KernelLog.String("UsbStorageBoot: Boot device serial number: "); KernelLog.String(serialNumber^);
		KernelLog.Exit;
	END;
END GetBootConfiguration;

PROCEDURE Install*;
END Install;

BEGIN
	GetBootConfiguration;
	Usbdi.drivers.Add(Probe, Name, Description, Priority);
	WaitForBootDevice;
END UsbStorageBoot.

UsbStorageBoot.Install ~  System.Free UsbStorageBoot ~
