MODULE UsbDriverLoader; (** AUTHOR "staubesv"; PURPOSE "Driver lookup interface for USB software"; *)
(**
 * This interface has a single purpose: It enables the USB system software to access the DriverDatabase services without
 * importing the required modules. The idea is the keep the USB boot file (AosUSB.Bin) small. The USB system software will be
 * notified when the driver lookup service is enabled. This will force a USB enumeration so that devices that already have been
 * connected to the bus before the service was available are checked for matching device drivers one more time.
 *
 * History:
 *
 *	07.12.2005	First release (staubesv)
 *	03.05.2006	Added lookup service enable notification mechanism (staubesv)
 *)

CONST
	USB = 1; (* MUST be the same as DriverDatabase.USB *)

TYPE
	InstallDeviceDriver* = PROCEDURE {DELEGATE} (type, vendorID, deviceID, revision : SIGNED32) : BOOLEAN;
	InstallClassDriver* = PROCEDURE {DELEGATE} (type, class, subclass, protocol, revision : SIGNED32) : BOOLEAN;

	Listener* = PROCEDURE {DELEGATE};

VAR
	installDeviceDriver : InstallDeviceDriver;
	installClassDriver : InstallClassDriver;

	listener : Listener;

(** Look for a device driver for the specified device and load it if available *)
PROCEDURE LoadDeviceDriver*(vendorID, deviceID, revision : SIGNED32) : BOOLEAN;
BEGIN {EXCLUSIVE}
	IF installDeviceDriver # NIL THEN
		RETURN installDeviceDriver(USB, vendorID, deviceID, revision);
	END;
	RETURN FALSE;
END LoadDeviceDriver;

(** Look for a class driver for the specified device and load it if available *)
PROCEDURE LoadClassDriver*(class, subclass, protocol, revision : SIGNED32) : BOOLEAN;
BEGIN {EXCLUSIVE}
	IF installClassDriver # NIL THEN
		RETURN installClassDriver(USB, class, subclass, protocol, revision);
	END;
	RETURN FALSE;
END LoadClassDriver;

(** Will be called by DriverDatabase.Mod *)
PROCEDURE SetLoaders*(dd : InstallDeviceDriver; cd : InstallClassDriver);
BEGIN {EXCLUSIVE}
	installDeviceDriver := dd; installClassDriver := cd;
	IF listener # NIL THEN listener(); END;
END SetLoaders;

(** The registered procedure will be called when SetLoaders is called to notifiy the client about the
possible availability of more device drivers. The installed listener MUST be decoupled using a separate thread *)
PROCEDURE SetListener*(l : Listener);
BEGIN {EXCLUSIVE}
	listener := l;
END SetListener;

END UsbDriverLoader.
