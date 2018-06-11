# Oberon Embedded Bootloader Release tool
# (c) Highdim GmbH, 2015-2016
# AUTHOR Timothée Martiel
# To build and use OEB, see the file Bootloader.Tool in the same folder.
HEADER
	VERSION "1.0"
END

IMPORT
	MINOS:/Minos.Tool
	ENET:/Enet.Tool
END

BUILDS
	Zedboard  {
		INCLUDE "ZYNQ ZEDBOARD"
		COMPILER "Compiler.Compile"
		COMPILEOPTIONS "-p=Minos --useFPU64 --metaData=simple --objectFile=Minos --replacements=ZBL:Zedboard.Replacements.txt --symbolFileExtension=.Syb --traceModule=Trace"
		TARGET "ARM"
		LINKER "MinosLinker.Link"
		LINKEROPTIONS "Init.Bin 0H Zbl.Bin"
		EXCLUDEPACKAGES "Fpga Scheduler"
		PATH ""
		DISABLED "FALSE"
	}

	Zybo {
		INCLUDE "ZYNQ ZYBO"
		COMPILER "Compiler.Compile"
		COMPILEOPTIONS "-p=Minos --useFPU64 --metaData=simple --objectFile=Minos --replacements=ZBL:Zybo.Replacements.txt --symbolFileExtension=.Syb --traceModule=Trace"
		TARGET "ARM"
		LINKER "MinosLinker.Link"
		LINKEROPTIONS "Init.Bin 0H Zbl.Bin"
		EXCLUDEPACKAGES "Fpga Scheduler"
		PATH ""
		DISABLED "FALSE"
	}

	KRM {
		INCLUDE "ZYNQ KRM"
		COMPILER "Compiler.Compile"
		COMPILEOPTIONS "-p=Minos --useFPU64 --metaData=simple --objectFile=Minos --replacements=ZBL:KRM.Replacements.txt --symbolFileExtension=.Syb --traceModule=Trace"
		TARGET "ARM"
		LINKER "MinosLinker.Link"
		LINKEROPTIONS "Init.Bin 0H Zbl.Bin"
		EXCLUDEPACKAGES "Fpga Scheduler"
		PATH ""
		DISABLED "FALSE"
	}

	TE0726 {
		INCLUDE "ZYNQ TE0726"
		COMPILER "Compiler.Compile"
		COMPILEOPTIONS "-p=Minos --useFPU64 --metaData=simple --objectFile=Minos --replacements=ZBL:TE0726.Replacements.txt --symbolFileExtension=.Syb --traceModule=Trace"
		TARGET "ARM"
		LINKER "MinosLinker.Link"
		LINKEROPTIONS "Init.Bin 0H Zbl.Bin"
		EXCLUDEPACKAGES "Fpga Scheduler"
		PATH ""
		DISABLED "FALSE"
	}
END

#### Core Packages ####
PACKAGE Bootstrap ARCHIVE "Bootstrap.zip" SOURCE "BootstrapSrc.zip" DESCRIPTION "Static image that loads the bootloader features"
	MINOS:/HAL/zynq/Zynq.Platform.Mos
	ZBL:Zynq.Board.Mos

	# Specialization on this file is handled with replacements
	ZEDBOARD { ZBL:Zedboard.TclInit.Mos }
	ZYBO { ZBL:Zybo.TclInit.Mos }
	KRM { ZBL:KRM.TclInit.Mos }
	TE0726 { ZBL:TE0726.TclInit.Mos }

	MINOS:/HAL/zynq/Zynq.Initializer.Mos
	ARM.FPE64.Mod
	ARM.Builtins.Mod
	MINOS:/Trace.Mos
	ZYNQ:/Zynq.PsUartMin.Mod
	ZBL:Zynq.PsTraceDevice.Mos
	MINOS:/HAL/zynq/Zynq.Caches.Mos
	MINOS:/HAL/zynq/Zynq.Memory.Mos
	ZBL:/MemoryMapping.Mos
	MINOS:/HAL/zynq/Zynq.Interrupts.Mos
	MINOS:/Bit.Mos
	MINOS:/HAL/zynq/Zynq.Clocks.Mos
	MINOS:/KernelUtils.Mos
	MINOS:/HAL/zynq/Zynq.GlobalTimer.Mos
	ZBL:/Kernel.Mos
	MINOS:/Utils.Mos
	MINOS:/Strings.Mos
	MINOS:/Heaps.Mos
	ZBL:/OFS.Mos
	ZBL:/Modules.Mos

	MINOS:/HAL/zynq/Zynq.SdEnvironment.Mos
	ZYNQ:/Sd.Mod
	ZBL:/Disks.Mos

	MINOS:SdDisks.Mos
	MINOS:/HAL/zynq/Zynq.SdControllers.Mod
	ZBL:/OFSDiskVolumes.Mos
	ZBL:/Bootstrap.Mos
END

PACKAGE Bootloader ARCHIVE "Bootloader.zip" SOURCE "BootloaderSrc.zip" DESCRIPTION "Bootloader Core"
	ZBL:Zynq.PsUartInterrupts.Mos
	ZYNQ:/Zynq.PsUart.Mod

	MINOS:OFSStreams.Mos
	ZYNQ:Zynq.PrivateWatchdog.Mod

	ZBL:Loader.Mos
	ZBL:Programmer.Mos
	ZBL:Checksum.Mos
	ZBL:Bootloader.Mos
END

#### Additional Loaders ####
PACKAGE TFTPLoader ARCHIVE "TFTPLoader.zip" SOURCE "TFTPLoaderSrc.zip" DESCRIPTION "TFTP Loader Plugin"
	ZBL:TftpLoader.Mos
END

PACKAGE XModemLoader ARCHIVE "XModemLoader.zip" SOURCE "XModemLoaderSrc.zip" DESCRIPTION "XMODEM Loader Plugin"
	ZBL:XModem.Mos
	ZBL:XModemLoader.Mos
END

#### Additional Programmers ####
PACKAGE ZynqFpgaProgrammer ARCHIVE "ZynqFpgaProgrammer.zip" SOURCE "ZynqFpgaProgrammerSrc.zip" DESCRIPTION "Programmer for Zynq FPGA"
	ZBL:ZynqFpgaProgrammer.Mos
END

PACKAGE A2ConfigProgrammer ARCHIVE "A2ConfigProgrammer.zip" SOURCE "A2ConfigProgrammerSrc.zip" DESCRIPTION "Programmer for A2 BootConfig"
	ZBL:A2ConfigProgrammer.Mos
END

#### Additional Checksums ####
PACKAGE MD5Checksum ARCHIVE "MD5Checksum.zip" SOURCE "MD5ChecksumSrc.zip" DESCRIPTION "MD5 Checksum Algorithm"
	MD5.Mod
	ZBL:MD5Checksum.Mos
END
