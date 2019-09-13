(*
	The following build commands assumes that the ARM folder is reachable from the search path.
	If this is not the case replace all ARM/ by full qualified path to folder ARM/
*)


FSTools.CreateDirectory build/ ~

System.DoCommands

(* Cleanup bootloader-specific files *)
FSTools.DeleteFiles -i -s WORK:*.Syb WORK:*.arm WORK:Init.Bin WORK:Zbl.Bin WORK:BOOT.BIN ~

(*
	Build everything required for the bootloader
*)

(* 2. Build Host Tools *)
(* 2.1. Compilation Tools *)
Compiler.Compile --mergeSections
	ARM/zbl/tools/ZynqTools.Mod
	MinosLinker.Mod
~

(* 2.2. Command Tools *)
Compiler.Compile --mergeSections
	TFTPServer.Mod
	ARM/zbl/tools/BlCommands.Mod
	ARM/zbl/tools/BlTools.Mod
~

(* 3. Compile Bootloader
The bootloader is composed of 3 parts:
	- the bootstrap image, which will load the actual bootloader application
	- the bootloader core, which implements the command mechanism
	- additional feature modules, which implement transfer protocols, programming destinations and checksum algorithms
*)
(* 3.2. Build Bootstrap Image *)
(* The first step does not depend on the board. *)
Compiler.Compile -p=ARMA2 --metaData=simple
	ARM/zbl/Boot.Mos
~
Linker.Link --fileName=Init.Bin --displacement=0H -a
	Boot
~
Release.Build -b -f=ARM/zbl/BootloaderRelease.Tool --only=Bootstrap CoraZ7_07S ~

MinosLinker.Link Init.Bin 0H Zbl.Bin
Platform Board TclInit ZynqInitializer FPE64 Builtins PsUartMin Trace TraceDevice Caches Memory 
MemoryMapping Interrupts Bit Clocks KernelUtils GlobalTimer Kernel Utils Strings Heaps OFS Modules 
SdEnvironment Sd Disks SdDisks SdControllers OFSDiskVolumes Bootstrap ~

ZynqTools.GenerateBootROM Zbl.Bin ~

(* 3.3. Build Bootloader Core *)
Release.Build -f=ARM/zbl/BootloaderRelease.Tool --build --only='EnetMinos Enet Bootloader' CoraZ7_07S ~

(* 3.4. Build Additional Features *)
(* Additional packages give more features to the bootloader. Available packages: *)

(* o A2 Boot Configuration Programmer *)
Release.Build -b -f=ARM/zbl/BootloaderRelease.Tool --only=A2ConfigProgrammer CoraZ7_07S ~

(* o TFTP Loader *)
Release.Build -b -f=ARM/zbl/BootloaderRelease.Tool --only=TFTPLoader CoraZ7_07S ~

(* o XMODEM loader *)
Release.Build -b -f=ARM/zbl/BootloaderRelease.Tool --only=XModemLoader CoraZ7_07S ~

(* o ZYNQ-7000 FPGA Programmer *)
Release.Build -b -f=ARM/zbl/BootloaderRelease.Tool --only=ZynqFpgaProgrammer CoraZ7_07S ~

(* o MD5 Checksum *)
Release.Build -b -f=ARM/zbl/BootloaderRelease.Tool --only=MD5Checksum CoraZ7_07S ~

(*
	Build everything required for the A2 on Zynq
*)
FSTools.DeleteFiles -i -s build/* ~

Release.Build -b --path='build/' ZynqKernel ~

Release.Build -b -z --path='build/' --only='System Drivers Compiler ApplicationsMini Applications' Zynq ~

(* Link A2 kernel *)
Linker.Link --fileName=A2.Bin --displacement=100000H -a --path=build/
	Initializer Platform FPE64 Builtins Trace BootConfig PsUartMin TraceDevice PrivateWatchdog Machine Heaps Modules Objects Kernel KernelLog Plugins
	Streams Pipes Commands Reals Clock Dates Strings Files Disks DiskCaches Reflection TrapWriters Traps Locks Options PsConfig SdEnvironment
	Sd SdDisks SdControllers Caches DiskVolumes DiskFS BitSets StringPool ObjectFile Diagnostics GenericLinker Loader
	BootConsole
~

(*
	Compile application-specific code
*)


(* 5. Preparing the Boot SD Card*)
(* The installation is done in a virtual disk that will be copied to the SD card: *)

VirtualDisks.Create build/CoraZ7_07S.ZynqA2.img 819200 512 ~
VirtualDisks.Install -b=512 VDISK0 build/CoraZ7_07S.ZynqA2.img ~

(* First we create the 2 partitions needed by the bootloader: *)
Partitions.WriteMBR VDISK0#0 BootManagerMBR.Bin BootManagerTail.Bin ~
Partitions.Create VDISK0#1 11 64 ~
Partitions.Create VDISK0#2 76 64 ~
Partitions.Format VDISK0#1 FatFS Quick ~
Partitions.Format VDISK0#2 AosFS ~

(* Then we install the bootloader: *)
FSTools.Mount BLFATFS FatFS VDISK0#1 ~
FSTools.Mount BLAOSFS AosFS VDISK0#2 ~

(* Copy Bootstrap Image *)
FSTools.CopyFiles -o WORK:/BOOT.BIN => BLFATFS:/BOOT.BIN ~

(* Copy the bootloader core: *)
FSTools.CopyTo BLAOSFS:/ WORK:/
	Bootloader.arm Checksum.arm Enet.arm EnetArp.arm EnetBase.arm EnetEmacPs7.arm EnetEnvironment.arm EnetIcmp.arm
	EnetInterfaces.arm EnetPhy.arm EnetStreams.arm EnetTftp.arm EnetTiming.arm EnetTrace.arm EnetUdp.arm EnetUdpChannels.arm
	EnetUtils.arm Loader.arm Programmer.arm StreamReaders.arm StreamWriters.arm PsUartInterrupts.arm PsUart.arm UncachedHeap.arm
	OFSStreams.arm PrivateWatchdog.arm XModem.arm XModemLoader.arm
~

(* Boot configuration for the specific hardware *)
FSTools.CreateFile -c -r CoraZ7_07S.bootconfig.txt
CpuNb=1
PsRefClockHz=50000000
CpuClockHz=650000000
UartInputClockHz=100000000
TracePort=1
TraceBPS=115200
ShellSerialPort=1
UsbPhyRstGpio0=46
UsbPhyRstGpio1=-1
UsbEnable0=1
UsbEnable1=0
UsbViewportInit=0
SdClock0=100000000
SdClock1=100000000
SdEnable0=1
SdEnable1=0
DDRSize=536870912
ConfigSize=4096
HeapSize=469762048
KernelLoadAdr=1048576
StackSize=262144
EnableCaching=1
EnableKernelWatchdog=0
EnableFreeLists=0
EnableReturnBlocks=0
TraceHeaps=0
TraceModules=0
TraceInterrupts=0
BootVol1=AOS AosFS SD0#3
AosFS=DiskVolumes.New DiskFS.NewFS
Boot=PsSerials.;ShellSerial.Open 2 1000000 8 no 1 "Zynq A2 > "
Boot1=System.
~

FSTools.CopyFiles -o CoraZ7_07S.bootconfig.txt => BLAOSFS:bootconfig ~

(* Copy additionnal bootloader packages: *)
(* o TFTP: *) FSTools.CopyTo BLAOSFS:/ WORK:/ TFTPLoader.arm ~
(* o ZYNQ-7000 FPGA Programmer: *) FSTools.CopyTo BLAOSFS:/ WORK:/ ZynqFpgaProgrammer.arm ~
(* o MD5 Checksum: *) FSTools.CopyTo BLAOSFS:/ WORK:/ MD5.arm MD5Checksum.arm ~
(* o A2ConfigProgrammer: *) FSTools.CopyTo BLAOSFS:/ WORK:/ A2ConfigProgrammer.arm ~

(* Setup bootloader initialization script *)
FSTools.CreateFile BLAOSFS:/init.txt timeout 3
setinput UART
~

(* Setup bootloader auto script *)
FSTools.CreateFile BLAOSFS:/auto.txt deploy bs ZynqFpga
deploy bootconfig A2Config
deploy a2 memory 100000H 0 1
start
~

FSTools.CopyFiles
	WORK:/A2.Bin => BLAOSFS:/a2
~
FSTools.Unmount BLFATFS ~
FSTools.Unmount BLAOSFS ~

(* Now we create a partition for A2 itself: *)
Partitions.Create VDISK0#3 76 256 ~
Partitions.Format VDISK0#3 AosFS ~
FSTools.Mount ZYNQA2 AosFS VDISK0#3 ~
ZipTool.ExtractAll --prefix=ZYNQA2: --sourcePath=build/ --overwrite --silent
	System.zip Drivers.zip Compiler.zip ApplicationsMini.zip Applications.zip
~

FSTools.Unmount ZYNQA2 ~
VirtualDisks.Uninstall VDISK0 ~

System.Show 'CoraZ7_07S Zynq A2 image has been built!' ~
FSTools.CloseFiles build/CoraZ7_07S.ZynqA2.img ~
~

#
#	Copy all release files to already existing partitions on SD card
#
WinDisks.Install E: RW ~
VirtualDisks.Install -b=512 VDISK0 build/CoraZ7_07S.ZynqA2.img ~

System.DoCommands

FSTools.Mount BOOT FatFS VDISK0#1 ~
FSTools.Mount BL AosFS VDISK0#2 ~
FSTools.Mount AOS AosFS VDISK0#3 ~

FSTools.Mount SDBOOT FatFS PhysicalDrive1#1 ~
FSTools.Mount SDBL AosFS PhysicalDrive1#2 ~
FSTools.Mount SDAOS AosFS PhysicalDrive1#3 ~

FSTools.CopyFiles -o BOOT:*.* => SDBOOT:*.* ~
FSTools.CopyFiles -o BL:*.* => SDBL:*.* ~
FSTools.CopyFiles -o AOS:*.* => SDAOS:*.* ~

FSTools.Unmount BOOT ~
FSTools.Unmount BL ~
FSTools.Unmount AOS ~
FSTools.Unmount SDBOOT ~
FSTools.Unmount SDBL ~
FSTools.Unmount SDAOS ~

(* this is to uninstall Zynq A2 image *)
VirtualDisks.Uninstall VDISK0 ~
WinDisks.Uninstall "PhysicalDrive1" ~
~

#
#	!!! Write the whole release image to SD card !!!
#	!!! MAKE SURE THE RIGHT PhysicalDriveX IS USED !!!
#
Partitions.FileToPartition PhysicalDrive1#0 build/CoraZ7_07S.ZynqA2.img 0 819200 ~

#
# Compiler options for ARM
#
-p=ARMA2 --mergeSections --useFPU32 --useFPU64 --destPath='build/'


#####
# How to initialize the Network interface using Xilinx EMAC controller

XEmac. ~
InitNetwork. ~


