MODULE  UsbSkeleton;  (** AUTHOR "staubesv"; PURPOSE "Skeleton for USB Device Drivers"; *)
(**
 * Skeleton for A2 USB Device Drivers.
 *
 * Steps to write a USB device driver:
 *
 *	-	Implement the Probe procedure
 *	-	Implement the actual device driver
 *
 * For a simple example, see UsbMouse.Mod
 *
 *
 * Getting control:
 * When a USB device is connected to the USB, the USB driver manager will call the Probe procedure of all device drivers it knows
 * (See module body for driver registration). The Probe procedure uses the device descriptor and configuration descriptor to check whether
 * the associated driver can handle the device. If it can, the Probe procedure returns an instance of the USB driver (YourDriver in this example).
 * If an instance of a driver object is returned, the USB driver manager initializes the driver object's field and then calls the Connect procedure.
 * This is the place where you get control over the USB device.
 *)

IMPORT Modules, Usbdi;

CONST

	Name = "Your driver's name";
	Description = "Description of your driver";
	Priority = 10;

TYPE

	YourDriver= OBJECT (Usbdi.Driver)
	(*
	 * Fields inherited from Usbdi.Driver:
	 *	device: 		Provides access to the device descriptors and the pipe mechanism.
	 *	interface:	Descriptor of the interface this driver instance is bound to.
	 *)

		(*	This procedure is called by the USB system software after an instance of this object has been passed to it via the probe procedure.
		 	Typically, the code here sets up the communication pipe(s) use by the driver using device.GetPipe(endpointnumber) *)
		PROCEDURE Connect() : BOOLEAN;
		BEGIN
			RETURN TRUE;
		END Connect;

		(*	This procedure is called by the USB system software when the device is removed or your driver is
		 	unregistered using Usbdi.drivers.Remove(Name).
		 	Note that the USB system software will automatically remove all pipes allocated by this driver *)
		PROCEDURE Disconnect;
		END Disconnect;

	END YourDriver;

(**	The Probe procedure uses the device descriptor and configuration descriptors provided by the device to
	see whether the device can be handled by the device driver. If not, the probe procedure returns NIL, otherwise
	it returns an instance of the device driver object. *)
PROCEDURE Probe(dev : Usbdi.UsbDevice; id : Usbdi.InterfaceDescriptor) : Usbdi.Driver;
VAR driver : YourDriver;
BEGIN
	(* RETURN NIL if device not supported by this USB device driver *)
	NEW(driver);
	RETURN driver;
END Probe;

PROCEDURE Cleanup;
BEGIN
	(* Unregister the driver at the USB driver registry *)
	Usbdi.drivers.Remove(Name);
END Cleanup;

PROCEDURE Install*;
	(* Load the module into memory and execute its body *)
END Install;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	(*	This registers your driver at the USB driver registry. When a device is attached to the USB, the Probe procedures
		of all registered device drivers will be called by the USB driver *)
	Usbdi.drivers.Add(Probe, Name, Description, Priority)
END UsbSkeleton.

UsbSkeleton.Install ~ 	System.Free UsbSkeleton ~