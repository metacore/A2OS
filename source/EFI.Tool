**************** 32 BIT ********************

** Loader * *

System.DoCommands
Compiler.Compile --bits=32 --traceModule=Trace
	I386.Builtins.Mod Trace.Mod EFI.Mod I386.EFIMachine.Mod EFITrace.Mod EFIFileProtocol.Mod EFISimpleFS.Mod
	EFILoadedImage.Mod EFIGraphicsOutput.Mod EFILib.Mod EFIGraphicalConsole.Mod EFIA2Loader.Mod
~
Linker.Link --fileName=E:/felix.svn/qemu/disk/A2Loader.efi --fileFormat=EFI32 --displacement=401000H
	Builtins Trace EFI EFIMachine EFITrace EFISimpleFS  EFIFileProtocol EFILoadedImage EFIGraphicsOutput EFILib 
	 EFIGraphicalConsole EFIA2Loader~
~

** Kernel Image **

System.DoCommands
Compiler.Compile --mergeSections -b=AMD --bits=32 --objectFileExtension=.Gox --symbolFileExtension=.Syx --traceModule=Trace
	I386.Builtins.Mod Trace.Mod EFI.I386.Machine.Mod EFIGraphicalConsole.Mod StartConsole.Mod Heaps.Mod Modules.Mod 
	BIOS.Objects.Mod Kernel.Mod KernelLog.Mod Plugins.Mod Streams.Mod Pipes.Mod Commands.Mod I386.Reals.Mod 
	Reflection.Mod TrapWriters.Mod CRC.Mod SystemVersion.Mod BIOS.I386.Traps.Mod Locks.Mod BIOS.PCI.Mod 
	BIOS.Clock.Mod BIOS.MemCache.Mod Disks.Mod Files.Mod Dates.Mod Strings.Mod UTF8Strings.Mod 
	FileTrapWriter.Mod Caches.Mod DiskVolumes.Mod OldDiskVolumes.Mod RAMVolumes.Mod DiskFS.Mod OldDiskFS.Mod 
	OberonFS.Mod FATVolumes.Mod FATFiles.Mod ISO9660Volumes.Mod ISO9660Files.Mod 
	RelativeFileSystem.Mod Loader.Mod BitSets.Mod Diagnostics.Mod StringPool.Mod ObjectFile.Mod 
	GenericLinker.Mod Loader.Mod BootConsole.Mod

~

Linker.Link
	--fileName=E:/felix.svn/qemu/disk/IDE.Bin
	--extension=Gox
	--displacement=0100000H
	--path="./"
	Builtins Trace Machine EFIGraphicalConsole StartConsole Heaps Modules Objects Kernel 
	KernelLog Streams Reflection  TrapWriters Traps  Plugins
	Diagnostics BitSets StringPool ObjectFile Reals Clock Dates Strings GenericLinker 
	Commands
	Files Loader BootConsole 
	~
~

**************** 64 BIT ********************
System.FreeDownTo FoxIntermediateBackend ~


	Compiler.Compile -b=AMD --bits=64 --objectFileExtension=.Gos --symbolFileExtension=.Sys --traceModule=Trace
	--trace=* -i StartConsole.Mod ~
~


** Loader **
~
System.DoCommands
Compiler.Compile --bits=64 --traceModule=Trace
	AMD64.Builtins.Mod Trace.Mod EFI.Mod AMD64.EFIMachine.Mod EFITrace.Mod EFIFileProtocol.Mod EFISimpleFS.Mod
	EFILoadedImage.Mod EFIGraphicsOutput.Mod EFILib.Mod EFIGraphicalConsole.Mod EFIA2Loader.Mod
~
Linker.Link --fileName=E:/felix.svn/qemu/disk/A2Loader.efi --fileFormat=EFI64 --displacement=401000H
	Builtins Trace EFI EFIMachine EFITrace EFISimpleFS  EFIFileProtocol EFILoadedImage EFIGraphicsOutput EFILib 
	 EFIGraphicalConsole EFIA2Loader
~
~

** Kernel Image **
	
System.DoCommands
	Compiler.Compile -b=AMD --bits=64 --objectFileExtension=.Gos --symbolFileExtension=.Sys --traceModule=Trace
	AMD64.Builtins.Mod Trace.Mod EFI.AMD64.Machine.Mod EFIGraphicalConsole.Mod StartConsole.Mod Heaps.Mod Modules.Mod BIOS.Objects.Mod Kernel.Mod 
	Interfaces.Mod KernelLog.Mod Plugins.Mod Streams.Mod Pipes.Mod Commands.Mod AMD64.Reals.Mod 
	Reflection.Mod TrapWriters.Mod BIOS.AMD64.Traps.Mod Locks.Mod BIOS.PCI.Mod BIOS.Clock.Mod BIOS.MemCache.Mod Disks.Mod Files.Mod 
	Dates.Mod Strings.Mod UTF8Strings.Mod Caches.Mod DiskVolumes.Mod OldDiskVolumes.Mod 
	RAMVolumes.Mod DiskFS.Mod OldDiskFS.Mod OberonFS.Mod FATVolumes.Mod FATFiles.Mod ISO9660Volumes.Mod 
	ISO9660Files.Mod RelativeFileSystem.Mod Loader.Mod BootConsole.Mod BIOS.AMD64.ATADisks.Mod ~
	
	Linker.Link
	--fileName=E:/felix.svn/qemu/disk/IDE.Bin
	--extension=Gos
	--displacement=0100000H
	Builtins Trace Machine EFIGraphicalConsole StartConsole Heaps Modules Objects Kernel 
	KernelLog Plugins Streams Commands Reals 
	Reflection TrapWriters Traps Locks PCI Clock MemCache Disks Files 
	ATADisks
	Dates Strings UTF8Strings Caches   	    
	Loader  BootConsole ~
~


******* config file *******
	PET.Open E:/felix.svn/qemu/disk/Config.txt ~
	
	
TraceMode="4" 
TracePort="1" 
TraceBPS="115200"
CacheSize="1000"
MaxProcs="-1"
ExtMemSize="127"
ATADetect="legacy"
~
BootVol1="AOS AosFS IDE0#1"
AosFS="DiskVolumes.New DiskFS.NewFS"
Boot1="Keyboard.Install;MousePS2.Install"
Boot2="DriverDatabase.Enable;UsbHubDriver.Install;UsbEhci.Install;UsbUhci.Install;UsbOhci.Install"
Boot3="WindowManager.Install"
Boot5="Autostart.Run"
Boot="DisplayLinear.Install"

~~


System.DoCommands
	VirtualDisks.Create A2HDD.img 65520 512 ~
	VirtualDisks.Install -b=512 VDISK0 A2HDD.img ~

	Linker.Link \.Obx IDE.Bin 0100000H 1000H Kernel Traps ATADisks DiskVolumes DiskFS BootConsole ~

	Partitions.WriteMBR VDISK0#0 OBEMBR.Bin ~
	Partitions.InstallBootManager VDISK0#0 ~
	Partitions.Create VDISK0#1 76 32 ~

	Partitions.Format VDISK0#1 AosFS 512 IDE.Bin ~

	Partitions.SetConfig VDISK0#1
		TraceMode="5" TracePort="1" TraceBPS="115200"
		BootVol1="AOS AosFS IDE0#1"
		AosFS="DiskVolumes.New DiskFS.NewFS"
		Boot1="Keyboard.Install;MousePS2.Install"
		Boot2="DriverDatabase.Enable;UsbHubDriver.Install;UsbEhci.Install;UsbUhci.Install;UsbOhci.Install"
		Boot3="WindowManager.Install"
		Boot5="Autostart.Run"
		Boot="DisplayLinear.Install"
		Init=""
		CacheSize="1000"
		~
	VirtualDisks.Uninstall VDISK0 ~
	~
	
	
System.DoCommands
VirtualDisks.Create A2:A2HDD.img 65520 ~
VirtualDisks.Install VDISK A2:A2HDD.img ~
Partitions.InstallBootManager VDISK#0 ~
Partitions.Create VDISK#1 76 31 ~
PCAAMD64.Assemble Bbl.Asm ~
PartitionsLib.SetBootLoaderFile BBL.Bin~
Partitions.Format VDISK#1 AosFS -2 E:/felix.svn/qemu/disk/IDE.Bin~
Partitions.SetConfig VDISK#1
	TraceMode="5" TracePort="1"
	MaxProcs="-1" ATADetect="legacy"
	BootVol1="RAM RamFS 8000 4096"
	BootVol2="CD AosFS #0,R"
	RamFS="RAMVolumes.New DiskFS.NewFS"
	AosFS="DiskVolumes.New DiskFS.NewFS"
	Boot1="Keyboard.Install;MousePS2.Install"
	Boot2="DriverDatabase.Enable;UsbHubDriver.Install;UsbEhci.Install;UsbUhci.Install;UsbOhci.Install"
	Boot3="WindowManager.Install"
	Boot4="Loopback.Install;Ethernet3Com90x.Install;RTL8139.Install;Intel8255x.Install;AM79C970.Install"
	Boot5="Autostart.Run"
	Boot6="InitNetwork.Init"
	Boot="DisplayLinear.Install"
	Init=""
	CacheSize="1000"
	AutoNetConfig="1"
	ATAPIForcePIO="1"
	ExtMemSize="128" ~
VirtualDisks.Uninstall VDISK ~
~
