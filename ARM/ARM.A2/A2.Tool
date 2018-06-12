A2 on ARM

Author: Timothée Martiel

For the A2 kernel, there are 2 ARM-specific modules: Machine and Objects.
Files:
	ARM.Machine.Mod
	ARM.Objects.Mod

Since the ARM backend now uses generic object files, the module Runtime is needed.

Modules FPE64 and ARMRuntime are needed and were taken from Minos.

For Zynq/ZedBoard targets, the compilation line is:

Compiler.Compile -b=ARM --traceModule=Trace
	(* Zynq specific initialization *)
	basel/ARM.A2/Initializer.Zynq.Mod

	basel/ARM.A2/Runtime.Mod

	(* ARM runtime & early communication *)
	basel/ARM.A2/Zynq.ARM.Platform.Mod basel/ARM.A2/FPE64.Mod basel/ARM.A2/ARM.ARMRuntime.Mod basel/ARM.A2/Trace.Mod
	basel/ARM.A2/Zynq.Uart.Mod

	(* Core kernel *)
	(*basel/ARM.A2/ARM.Machine.Mod*)
	basel/ARM.A2/TrapHandling.ARM.Machine.Mod
	basel/ARM.A2/Heaps.Mod oc/Generic.Modules.Mod basel/ARM.A2/Objects.Mod basel/ARM.A2/Kernel.Mod
~

Compiler.Compile -b=ARM --traceModule=Trace --initLocals
	(* Interactive shell on UART *)
	basel/ARM.A2/KernelLog.Mod basel/ARM.A2/ARM.Streams.Mod Commands.Mod basel/ARM.A2/ARM.Reals.Mod Clock.Mod Dates.Mod Strings.Mod Pipes.Mod Files.Mod Shell.Mod
	basel/ARM.A2/ShellController.Mod
~
	basel/ARM.A2/HeapTest.Mod

	(* RAM file system *)
	Caches.Mod UTF8Strings.Mod DynamicStrings.Mod XMLObjects.Mod XML.Mod XMLScanner.Mod XMLParser.Mod Configuration.Mod
	Options.Mod Plugins.Mod Disks.Mod (*basel/ARM.A2/*)DiskFS.Mod RAMVolumes.Mod FSTools.Mod
	basel/ARM.A2/RamFsController.Mod DiskVolumes.Mod

	(* Network: FTP server *)
	ActiveTimers.Mod
	basel/ARM.A2/ARM.Network.Mod basel/ARM.A2/Zynq.XEmac.Mod
	basel/ARM.A2/ARM.IP.Mod TCP.Mod basel/ARM.A2/ARM.IPv4.Mod IPv6.Mod ICMP.Mod basel/ARM.A2/StaticInterface.Mod
	basel/ARM.A2/TCPServices.Mod WebFTPServer.Mod

	(* Network: HTTP server *)
	(*TFLog.Mod WebHTTP.Mod TFClasses.Mod WebHTTPServer.Mod*)

	(* Dynamic Linking *)
	BitSets.Mod StringPool.Mod ObjectFile.Mod Diagnostics.Mod GenericLinker.Mod basel/ARM.A2/GenericLoader.Mod
	CRC.Mod ProcessInfo0.Mod Reflection.Mod ProcessInfo.Mod SystemVersion.Mod SystemTools.Mod

	(* FAT FS *)
	FATVolumes.Mod FATFiles.Mod

	(* Samba client *)
	UDP.Mod DNS.Mod Locks.Mod SambaClient.Mod basel/ARM.A2/SambaController.Mod

	(* Some tests *)
	(*basel/ARM.A2/Test.Mod
	basel/ARM.A2/Counter.Mod
	basel/ARM.A2/LLCounter.Mod*)
~

Trap handling:
Compiler.Compile -b=ARM --traceModule=Trace --initLocals (*--trace=* -i*)
	basel/ARM.A2/KernelLog.Mod basel/ARM.A2/ARM.Streams.Mod Reflection.Mod TrapWriters.Mod basel/ARM.A2/ARM.Traps.Mod
~

Compiler.Compile -b=ARM --traceModule=Trace --initLocals basel/ARM.A2/GenericLoader.Mod Test.Mod ~

Dynamically linked modules:
Compiler.Compile -b=ARM --traceModule=Trace --initLocals (*--trace=* -i*)
	Trace.Mod
	KernelLog.Mod
	basel/ARM.A2/Test.Mod
	HeapTest.Mod
~

Compiler.Compile -b=ARM --traceModule=Trace --initLocals (*--trace=* -i*)
	Test.Mod
~


StaticLinker.Link --fileName=Test.Bin --displacement=100000H -a
	Initializer Runtime Platform FPE64 ARMRuntime Trace Uart
	Machine Heaps Modules Objects Kernel
	Test
~

	KernelLog Streams Commands Reals Clock Dates Strings Pipes Files Shell
	Options Plugins

	ActiveTimers
	Network XEmac IP TCP IPv4 IPv6 ICMP StaticInterface

	BitSets StringPool ObjectFile Diagnostics GenericLinker GenericLoader
	CRC ProcessInfo0 Reflection ProcessInfo SystemVersion SystemTools

	UTF8Strings DynamicStrings XML XMLObjects XMLScanner XMLParser

	UDP DNS Locks SambaClient SambaController
	UsbDebug Usbdi UsbHcdi UsbEhci UsbEhciZynq
	UsbDriverLoader UsbUtilities Usb UsbHubDriver UsbHid UsbInfo
	Disks UsbStorageBase UsbStorageCbi UsbStorageBot UsbStorageScm UsbStorage
	DriverDatabase

	ShellController
~
	UNzip Archives Inflate DiskVolumes Localization UTF8Strings FP1616 DynamicStrings Codecs Repositories Configuration Raster WMRectangles WMRasterScale UnicodeProperties Caches FATscavenger FATVolumes FATFiles Texts TextUtilities WMGraphics WMEvents OldDiskVolumes CLUTs Displays DisplayNull SoundDevices XML XMLScanner XMLParser XMLObjects ISO9660Volumes Partitions PartitionsLib


	UTF8Strings DynamicStrings XMLObjects XML XMLScanner XMLParser Configuration
	Options Plugins DiskFS FSTools RAMVolumes RamFsController

	ActiveTimers
	Network XEmac IP TCP IPv4 IPv6 ICMP StaticInterface

	BitSets StringPool ObjectFile Diagnostics GenericLinker GenericLoader
	CRC ProcessInfo0 Reflection ProcessInfo SystemVersion SystemTools

	UDP DNS Locks SambaClient SambaController

	ShellController
~
	ActiveTimers
	Network XEmac IP TCP IPv4 IPv6 ICMP StaticInterface
	TCPServices WebFTPServer
	
	BitSets StringPool ObjectFile Diagnostics GenericLinker GenericLoader
	CRC ProcessInfo0 Reflection ProcessInfo SystemVersion SystemTools

	ShellController
~

V24.Scan 
WMV24Component.Open 15 115200 8 1 none ~

/!\ NOTE that the Initializer module, which provides processor and chip initialization is linked before Runtime.
The reason for that is that Initializer does some sensitive operations, like setting up a stack, that do not mix
well with the automatic inclusion of a call to Runtime.Publish. Therefore Runtime IMPORTS Initializer.

Moreover, the TCL initialization and interrupt vectors form a second, smaller executable for the Zynq/ZedBoard platforms,
as the main image is loaded in external memory. You can generate it as follows:

Compiler.Compile -b=ARM --metaData=simple
	basel/ARM.A2/Initializer.TCL.Zynq.Mod
~

StaticLinker.Link --fileName=Init.Bin --displacement=0H -sa
	ZynqInitializer
~

FoxARMInstructionSet.Disassemble Test.Bin -a=118F00H ~
FoxARMInstructionSet.Disassemble Test.Bin ~
Test.Log

FoxARMInstructionSet.Disassemble ARMRuntime.Gof ~
FoxARMInstructionSet.Disassemble Init.Bin ~

SystemTools.FreeDownTo FoxARMInstructionSet ~

FoxARMInstructionSet.Disassemble Initializer.Gof ~
