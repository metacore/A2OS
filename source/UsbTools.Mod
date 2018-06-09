MODULE UsbTools; (** AUTHOR "staubesv"; PURPOSE "USB Tools"; *)
(**
 * Usage:
 *
 *	UsbTools.Mount prefix alias [volpar] ["|" fspar] ~ 				Starts a thread that waits for the disk device to become accessible and then mounts it.
 *																	(non-blocking)
 *																	Example: UsbTools.Mount USBDrive AosFS USB0#1 ~
 *
 *
 *	UsbTools.BlockingMount prefix alias [volpar] ["|" fspar] ~ 		Waits for the disk device to become accessible and then mounts it. Should not be used by a user.
 *																	(blocking)
 *																	Example: UsbTools.BlockingMount USBDrive AosFS USB0#1 ~
 *
 *	UsbTools.AwaitAndExecute devicename commandlist ~		Starts a thread that waits for the disk device to become accessible and then executes the commands.
 *																	(non-blocking)
 *																	Example: UsbTools.AwaitAndExecute USB0 FSTools.Mount USBDrive AosFS USB0#1+PET.Open USBDrive:/PET.Mod ~
 *
 *	UsbTools.AwaitAndExecute0 devicename commandlist ~		Waits for the disk device to become accessible and then executes the commands. Not for users.
 *																	(blocking)
 *																	Example: UsbTools.AwaitAndExecute0 USB0 FSTools.Mount USBDrive AosFS USB0#1~
 *
 *	System.Free UsbTools ~
 *
 * History:
 *
 *	28.06.2006	First release (staubesv)
 *)

IMPORT
	KernelLog, Commands, Plugins, Disks, FSTools;

CONST

	CommandSeparator = "+";

(** Starts a thread that first waits until the device to be mounted becomes accessible and then mounts it *)
PROCEDURE Mount*(context : Commands.Context); (** prefix alias [volpar] ["|" fspar] ~ *)
VAR msg : ARRAY 8 OF CHAR; res : WORD;
BEGIN
	Commands.Activate("UsbTools.BlockingMount", context, {}, res, msg); (* ignore result *)
END Mount;

(** Waits for the device to be mounted and then try to mount it *)
PROCEDURE BlockingMount*(context : Commands.Context); (** prefix alias [volpar] ["|" fspar] ~ *)
VAR
	plugin : Plugins.Plugin;
	devicename, string : ARRAY 128 OF CHAR;
BEGIN
	(* Skip the first two parameters *)
	context.arg.SkipWhitespace; context.arg.String(string);
	context.arg.SkipWhitespace; context.arg.String(string);

	(* read dev#part string *)
	context.arg.SkipWhitespace; context.arg.String(string);

	IF ExtractDevicename(string, devicename) THEN

		IF (context.arg.CanSetPos()) THEN
			context.arg.SetPos(0);

			KernelLog.Enter; KernelLog.String("UsbTools: Waiting for USB device "); KernelLog.String(devicename); KernelLog.Exit;
			plugin := Disks.registry.Await(devicename);
			KernelLog.Enter; KernelLog.String("UsbTools: Device "); KernelLog.String(devicename); KernelLog.String(" connected."); KernelLog.Exit;

			FSTools.Mount(context);
		ELSE context.error.String("UsbTools.BlockingMount: Argument stream expected to support SetPos."); context.error.Ln;
		END;
	ELSE context.error.String("UsbTools.BlockingMount: Could not extract device name"); context.error.Ln;
	END;
END BlockingMount;

(** Waits for the specified disk device and then execute the commands *)
PROCEDURE AwaitAndExecute*(context : Commands.Context); (** devicename commandlist ~ *)
VAR msg : ARRAY 8 OF CHAR; res : WORD;
BEGIN
	Commands.Activate("UsbTools.AwaitAndExecute0", context, {}, res, msg); (* ignore result *)
END AwaitAndExecute;

(** Waits for the specified disk device and then execute the commands. Note: Does NOT mount the device. *)
PROCEDURE AwaitAndExecute0*(context : Commands.Context); (** devicename commandlist ~ *)
VAR
	devicename, msg : ARRAY 128 OF CHAR;
	commandList : POINTER TO ARRAY OF CHAR;
	plugin : Plugins.Plugin;
	i, size, len, res : LONGINT;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(devicename);

	KernelLog.Enter; KernelLog.String("UsbTools: Waiting for USB device "); KernelLog.String(devicename); KernelLog.Exit;
	plugin := Disks.registry.Await(devicename);
	KernelLog.Enter; KernelLog.String("UsbTools: Device "); KernelLog.String(devicename); KernelLog.String(" connected."); KernelLog.Exit;

	(* read and copy command list *)
	context.arg.SkipWhitespace;
	size := context.arg.Available();
	IF size > 0 THEN
		NEW(commandList, size + 1);
		context.arg.Bytes(commandList^, 0, size, len);
		FOR i := 0 TO size DO IF commandList[i] = CommandSeparator THEN commandList[i] := ";"; END; END;

		commandList^[size] := 0X;

		Commands.Call(commandList^, {}, res, msg);
		IF res # Commands.Ok THEN
			KernelLog.Enter;
			KernelLog.String("UsbTools: AwaitAndExecute: Command execution error, res: "); KernelLog.Int(res, 0);
			KernelLog.String(" ("); KernelLog.String(msg); KernelLog.String(")");
			KernelLog.Exit;
		END;
	END;
END AwaitAndExecute0;

PROCEDURE ExtractDevicename(CONST devpart : ARRAY OF CHAR; VAR devicename : ARRAY OF CHAR) : BOOLEAN;
VAR i : LONGINT;
BEGIN
	WHILE (i < LEN(devpart)) & (devpart[i] # "#") & (i < LEN(devicename)) DO
		devicename[i] := devpart[i];
		INC(i);
	END;
	RETURN (i < LEN(devpart)) & (devpart[i] = "#");
END ExtractDevicename;

END UsbTools.

UsbTools.Mount USB AosFS USB0#1 ~		System.Free UsbTools ~
