# Compile the compiler
oc/Fox.Tool

# full build (old object file)
FSTools.DeleteFiles bin/* ~
FSTools.CreateDirectory bin/ ~
Release.Build
	-f=Timothee/USB/Release.Tool --path="bin/" --build --zip
	--exclude="Oberon OberonGadgets OberonApplications OberonDocumentation OberonVoyager OberonAnts"
	A2 ~

# full build (new object file)
FSTools.DeleteFiles bin/* ~
FSTools.CreateDirectory bin/ ~
Release.Build
	-f=Timothee/USB/Release.Tool --path="bin/" --build --zip
	A2NewObjectFile ~


# Create image for bootable USB  (A2USB.img)
SystemTools.DoCommands

	Compiler.Compile --objectFile=Generic --mergeSections -b=AMD --objectFileExtension=.Gox --symbolFileExtension=.Syx --destPath=bin/
		UsbDebug.Mod

		(* NEW *)
		Timothee/USB/UsbBuffers.Mod
		Timothee/USB/Usbdi.Mod
		Timothee/USB/UsbHcdi.Mod
		Timothee/USB/UsbVarTdAlloc.Mod
		Timothee/USB/UsbEhci.Mod

		UsbEhciPCI.Mod
		UsbDriverLoader.Mod
		UsbUtilities.Mod
		Timothee/USB/Usb.Mod
		Timothee/USB/UsbHubDriver.Mod
		Timothee/USB/UsbInfo.Mod
	~

		PCAAMD64.Assemble OBLUnreal.Asm ~
		PartitionsLib.SetBootLoaderFile OBLUnreal.Bin ~
		PCAAMD64.Assemble BootManager.Asm ~
		BootManager.Split BootManager.Bin ~
		SystemTools.Timer start ~

		FSTools.DeleteFiles Timothee/USB/A2USB.img ~

		VirtualDisks.Create Timothee/USB/A2USB.img 400000 512 ~
		VirtualDisks.Install -b=512 VDISK0 Timothee/USB/A2USB.img ~

		StaticLinker.Link
		    --fileName=bin/USB.bin
		    --extension=Gox
		    --displacement=0100000H
		    --path="bin/"
		    Runtime Trace Machine Heaps Modules Objects Kernel
		    KernelLog Streams Reflection  TrapWriters Traps  Plugins
		    UsbDriverLoader UsbBuffers Locks Usbdi UsbDebug UsbHcdi UsbUtilities Usb UsbHubDriver UsbVarTdAlloc UsbEhci PCI UsbEhciPCI UsbInfo
		    Disks Commands
		    UsbStorageBase UsbStorageBot UsbStorageBoot
		    Reals Clock Dates Strings  Caches Files DiskVolumes DiskFS
		    Diagnostics FoxProfiler BitSets StringPool ObjectFile GenericLinker GenericLoader BootConsole
		~
		
		StaticLinker.Link
			--fileName=bin/IDE.Bin
			--extension=Gox
			--displacement=0100000H
		    --path="bin/"
			Runtime Trace Machine Heaps Modules Objects Kernel 
			KernelLog Plugins Streams Commands Reals 
			Reflection TrapWriters Traps Locks PCI Clock MemCache Disks Files 
			ATADisks DiskVolumes DiskFS
			Dates Strings UTF8Strings  Caches
			Diagnostics BitSets ObjectFile GenericLinker StringPool GenericLoader 
			Loader BootConsole	~


		(* Partitions.WriteMBR VDISK0#0 OBEMBR.Bin ~ *)
		Partitions.InstallBootManager VDISK0#0 BootManagerMBR.Bin BootManagerTail.Bin ~
		Partitions.Create VDISK0#1 76 200 ~
		(* Partitions.Activate VDISK0#1 ~ *)

		Partitions.Format VDISK0#1 AosFS -1 bin/IDE.Bin ~ (* -1 makes sure that actual boot file size is taken as offset for AosFS *)
		FSTools.Mount TEMP AosFS VDISK0#1 ~

		ZipTool.ExtractAll --prefix=TEMP: --sourcePath=bin/ --overwrite --silent
			Kernel.zip System.zip Drivers.zip ApplicationsMini.zip Applications.zip Compiler.zip
			GuiApplicationsMini.zip GuiApplications.zip Fun.zip Contributions.zip Build.zip
			ScreenFonts.zip
		
			CompilerSrc.zip KernelSrc.zip SystemSrc.zip DriversSrc.zip ApplicationsMiniSrc.zip ApplicationsSrc.zip GuiApplicationsMiniSrc.zip GuiApplicationsSrc.zip FunSrc.zip BuildSrc.zip
			~

		FSTools.Watch TEMP ~
		FSTools.Unmount TEMP ~

		Partitions.SetConfig VDISK0#1
			TraceMode="5"
			TracePort="1"
			TraceBPS="115200"
			BootVol1="AOS AosFS IDE0#1"
			AosFS="DiskVolumes.New DiskFS.NewFS"
			CacheSize="1000"
			ExtMemSize="512"
			MaxProcs="-1"
			ATADetect="other"
			Init="144"
			Boot="DisplayLinear.Install"
			Boot1="Keyboard.Install;MousePS2.Install"
			Boot2="DriverDatabase.Enable;UsbHubDriver.Install;UsbEhciPCI.Install"
			Boot3="UsbMouse.Install"
			Boot4="WindowManager.Install"
			Boot5="Autostart.Run"
			ObjectFileExtension =".Gox"
~

		VirtualDisks.Uninstall VDISK0 ~

		SystemTools.Show USB image build time:  ~ SystemTools.Timer elapsed ~

		FSTools.CloseFiles Timothee/USB/A2USB.img ~

		SystemTools.Ln ~
		SystemTools.Show "Done!"~
~






VirtualDisks.Install VDISK0 Timothee/USB/A2USB.img ~
WinDisks.Install E: RW ~
FSTools.Mount EXT AosFS PhysicalDrive1#1 ~
FSTools.Unmount EXT ~

SystemTools.DoCommands
	Partitions.FileToPartition PhysicalDrive1#0 Timothee/USB/A2USB.img 0 400000 ~
	Partitions.SetConfig PhysicalDrive1#1
		TraceMode="1"
		TraceMem="0"
		TracePort="1"
		TraceBPS="115200"
		BootVol1="AOS AosFS USB0#1"
		AosFS="DiskVolumes.New DiskFS.NewFS"
		CacheSize="1000"
		ExtMemSize="512"
		MaxProcs="-1"
		ATADetect="other"
		Init="117"
		Boot="FileTracer.Install;UsbVideo.Install"
	~
	WinDisks.Uninstall "PhysicalDrive1" ~
~


VirtualDisks.Install -b=512 VDISK0 TL.img ~
FSTools.Mount TEMP AosFS VDISK0#1 ~
FSTools.Unmount TEMP ~
VirtualDisks.Uninstall VDISK0 ~
================= Default Linker Command 1 =================
		Linker.Link \Pbin/ \.Obx bin/USB.Bin 0100000H 100000H Kernel  Traps
			UsbHubDriver UsbTouchscreen UsbEhci UsbEhciPCI UsbUhci UsbStorageBoot UsbInfo
			DiskVolumes DiskFS
			Loader BootConsole ~

================= Default Partition Config ====================
		Partitions.SetConfig PhysicalDrive1#1
			TraceMode="1"
			TraceMem="0"
			TracePort="1"
			TraceBPS="115200"
			BootVol1="AOS AosFS USB0#1"
			AosFS="DiskVolumes.New DiskFS.NewFS"
			CacheSize="1000"
			ExtMemSize="512"
			MaxProcs="-1"
			ATADetect="other"
			Init="161"
			Boot="DisplayLinear.Install"
			Boot1="Keyboard.Install"
			Boot2="DriverDatabase.Enable;UsbHubDriver.Install;UsbEhciPCI.Install;UsbUhci.Install;UsbOhci.Install"
			Boot3="UsbMouse.Install;UsbHid.Install"
~
 			Boot4="WindowManager.Install"
			Boot5="Autostart.Run"
			~

=== Test Configuration to get tracing on screen at boot time ===
WinDisks.Install F: RW ~
Partitions.SetConfig PhysicalDrive1#1
	TraceMode="1"
	TraceMem="0"
	TracePort="1"
	TraceBPS="115200"
	BootVol1="AOS AosFS USB0#1"
	AosFS="DiskVolumes.New DiskFS.NewFS"
	CacheSize="1000"
	ExtMemSize="512"
	MaxProcs="-1"
	ATADetect="other"
	Init="117"
	Boot="FileTracer.Install;UsbVideo.Install"
~
	WinDisks.Uninstall "PhysicalDrive1" ~

	TraceDelay="10000"
Partitions.SetConfig PhysicalDrive1#1
	TraceMode="0"
	TracePort="1"
	TraceBPS="115200"
	BootVol1="AOS AosFS USB0#1"
	AosFS="DiskVolumes.New DiskFS.NewFS"
	CacheSize="1000"
	ExtMemSize="512"
	MaxProcs="-1"
	ATADetect="other"
	Init="161"
	Boot="DisplayLinear.Install"
	Boot1="Keyboard.Install"
	Boot2="DriverDatabase.Enable;UsbHubDriver.Install;UsbEhciPCI.Install;UsbUhci.Install;UsbOhci.Install"
	Boot3="UsbMouse.Install;UsbVideo.Install"
	Boot4="WindowManager.Install"
	Boot5="Autostart.Run"
~
