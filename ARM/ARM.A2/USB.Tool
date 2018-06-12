To compile the A2 kernel, see A2.Tool.

Compiler.Compile -b=ARM --traceModule=Trace --initLocals
	basel/ARM.A2/KernelLog.Mod

	(* Non-USB modules needed for the HID Driver *)
	basel/ARM.A2/ARM.Streams.Mod Commands.Mod Clock.Mod Dates.Mod basel/ARM.A2/ARM.Reals.Mod Strings.Mod Files.Mod

	(* USB Stack *)
	Plugins.Mod UsbDebug.Mod Usbdi.Mod UsbHcdi.Mod
	UsbEhci.Mod basel/ARM.A2/UsbEhciZynq.Mod
	(*basel/ARM.A2/UsbEhci.Mod*)
	UsbDriverLoader.Mod
	UsbUtilities.Mod Usb.Mod UsbHubDriver.Mod UsbHid.Mod DriverDatabase.Mod UsbInfo.Mod

	(* USB HID driver modules *)
	Inputs.Mod UsbHidErrors.Mod UsbHidUP.Mod UsbHidParserExt.Mod UsbHidReport.Mod UsbHidParser.Mod
	basel/ARM.A2/ARM.UsbKeyboard.Mod Joysticks.Mod UsbHidDriver.Mod

	(* USB storage driver modules *)
	Disks.Mod UsbStorageBase.Mod UsbStorageCbi.Mod UsbStorageBot.Mod UsbStorageScm.Mod UsbStorage.Mod

	(* USB Bluetooth modules *)
	UsbBluetooth.Mod

	(* Bluetooth modules *)
	Bluetooth.Mod BluetoothHCI.Mod BluetoothL2CAP.Mod BluetoothRFCOMM.Mod BluetoothUART.Mod BluetoothUSB.Mod
	Serials.Mod BluetoothTest.Mod
~

Compiler.Compile -b=ARM --traceModule=Trace --initLocals
	(* Video modules *)
	basel/ARM.A2/UsbVideoDesc.Mod
	basel/ARM.A2/UsbVideo.Mod
~

Compiler.Compile -b=ARM --traceModule=Trace --initLocals
	Caches.Mod DiskVolumes.Mod
~

StaticLinker.Link --fileName=Test.Bin --displacement=100000H -a
	Initializer Runtime Platform FPE64 ARMRuntime Trace Uart Machine
	Heaps Modules Objects Kernel

	KernelLog Streams Commands Clock Dates Reals Strings Files

	Plugins UsbDebug Usbdi UsbHcdi UsbEhci UsbEhciZynq

	UsbDriverLoader UsbUtilities Usb UsbHubDriver UsbHid UsbInfo

	UsbVideoDesc UsbVideo

	UsbBluetooth Bluetooth BluetoothHCI BluetoothL2CAP BluetoothRFCOMM
	BluetoothUART BluetoothUSB Serials BluetoothTest

	Disks UsbStorageBase UsbStorageCbi UsbStorageBot UsbStorageScm UsbStorage

	Pipes Shell ShellController
~
	Inputs UsbHidErrors UsbHidUP UsbHidParserExt UsbHidReport UsbHidParser
	UsbKeyboard Joysticks UsbHidDriver
~


=======================================
For testing the EHCI controller on the ZedBoard, here is a simple initialization module:

Compiler.Compile -b=ARM --traceModule=Trace --initLocals
	basel/ARM.A2/TestUsbEhci.Mod
	basel/ARM.A2/USBTestWatcher.Mod
~

StaticLinker.Link --fileName=Test.Bin --displacement=100000H -a
	Initializer
	Runtime
	Platform
	FPE64
	ARMRuntime
	Trace
	Uart
	Machine
	Heaps
	Modules
	Objects
	Kernel

	UsbEhci
~
	USBTestWatcher
~

=======================================
FoxARMInstructionSet.Disassemble Test.Bin -a=1EA044H ~
