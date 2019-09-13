# Oberon Embedded Bootloader Release tool
# (c) Highdim GmbH, 2015-2016
# AUTHOR Timothée Martiel
# To build and use OEB, see the file Bootloader.Tool in the same folder.
HEADER
	VERSION "1.0"
END

IMPORT
	ARM/Minos/Minos.Tool
	ARM/Enet/Enet.Tool
END

BUILDS
	Zedboard  {
		INCLUDE "ZYNQ ZEDBOARD"
		COMPILER "Compiler.Compile"
		COMPILEOPTIONS "-p=Minos --useFPU32 --useFPU64 --metaData=simple --objectFile=Minos --replacements=ARM/zbl/Zedboard.Replacements.txt --symbolFileExtension=.Syb --traceModule=Trace"
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
		COMPILEOPTIONS "-p=Minos --useFPU32 --useFPU64 --metaData=simple --objectFile=Minos --replacements=ARM/zbl/Zybo.Replacements.txt --symbolFileExtension=.Syb --traceModule=Trace"
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
		COMPILEOPTIONS "-p=Minos --useFPU32 --useFPU64 --metaData=simple --objectFile=Minos --replacements=ARM/zbl/KRM.Replacements.txt --symbolFileExtension=.Syb --traceModule=Trace"
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
		COMPILEOPTIONS "-p=Minos --useFPU32 --useFPU64 --metaData=simple --objectFile=Minos --replacements=ARM/zbl/TE0726.Replacements.txt --symbolFileExtension=.Syb --traceModule=Trace"
		TARGET "ARM"
		LINKER "MinosLinker.Link"
		LINKEROPTIONS "Init.Bin 0H Zbl.Bin"
		EXCLUDEPACKAGES "Fpga Scheduler"
		PATH ""
		DISABLED "FALSE"
	}
	
	TE0720 {
		INCLUDE "ZYNQ TE0720"
		COMPILER "Compiler.Compile"
		COMPILEOPTIONS "-p=Minos --useFPU32 --useFPU64 --metaData=simple --objectFile=Minos --replacements=ARM/zbl/TE0720.Replacements.txt --symbolFileExtension=.Syb --traceModule=Trace"
		TARGET "ARM"
		LINKER "MinosLinker.Link"
		LINKEROPTIONS "Init.Bin 0H Zbl.Bin"
		EXCLUDEPACKAGES "Fpga Scheduler"
		PATH ""
		DISABLED "FALSE"
	}
	
	CoraZ7_07S {
		INCLUDE "ZYNQ CoraZ7_07S"
		COMPILER "Compiler.Compile"
		COMPILEOPTIONS "-p=Minos --useFPU32 --useFPU64 --metaData=simple --objectFile=Minos --replacements=ARM/zbl/CoraZ7_07S.Replacements.txt --symbolFileExtension=.Syb --traceModule=Trace"
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
	ARM/Minos/HAL/zynq/Zynq.Platform.Mos
	ARM/zbl/Zynq.Board.Mos

	# Specialization on this file is handled with replacements
	ZEDBOARD { ARM/zbl/Zedboard.TclInit.Mos }
	ZYBO { ARM/zbl/Zybo.TclInit.Mos }
	KRM { ARM/zbl/KRM.TclInit.Mos }
	TE0726 { ARM/zbl/TE0726.TclInit.Mos }
	TE0720 { ARM/zbl/TE0720.TclInit.Mos }
	CoraZ7_07S { ARM/zbl/CoraZ7_07S.TclInit.Mos }

	ARM/Minos/HAL/zynq/Zynq.Initializer.Mos
	ARM.FPE64.Mod
	ARM.Builtins.Mod
	ARM/Minos/Trace.Mos
	Zynq.PsUartMin.Mod
	ARM/zbl/Zynq.TraceDevice.Mos
	ARM/Minos/HAL/zynq/Zynq.Caches.Mos
	ARM/Minos/HAL/zynq/Zynq.Memory.Mos
	ARM/zbl/MemoryMapping.Mos
	ARM/Minos/HAL/zynq/Zynq.Interrupts.Mos
	ARM/Minos/Bit.Mos
	ARM/Minos/HAL/zynq/Zynq.Clocks.Mos
	ARM/Minos/KernelUtils.Mos
	ARM/Minos/HAL/zynq/Zynq.GlobalTimer.Mos
	ARM/zbl/Kernel.Mos
	ARM/Minos/Utils.Mos
	ARM/Minos/Strings.Mos
	ARM/Minos/Heaps.Mos
	ARM/zbl/OFS.Mos
	ARM/zbl/Modules.Mos

	ARM/Minos/HAL/zynq/Zynq.SdEnvironment.Mos
	Sd.Mod
	ARM/zbl/Disks.Mos

	ARM/Minos/SdDisks.Mos
	ARM/Minos/HAL/zynq/Zynq.SdControllers.Mod
	ARM/zbl/OFSDiskVolumes.Mos
	ARM/zbl/Bootstrap.Mos
END

PACKAGE Bootloader ARCHIVE "Bootloader.zip" SOURCE "BootloaderSrc.zip" DESCRIPTION "Bootloader Core"
	ARM/zbl/Zynq.PsUartInterrupts.Mos
	Zynq.PsUart.Mod

	ARM/Minos/OFSStreams.Mos
	Zynq.PrivateWatchdog.Mod

	ARM/zbl/Loader.Mos
	ARM/zbl/Programmer.Mos
	ARM/zbl/Checksum.Mos
	ARM/zbl/Bootloader.Mos
END

#### Additional Loaders ####
PACKAGE TFTPLoader ARCHIVE "TFTPLoader.zip" SOURCE "TFTPLoaderSrc.zip" DESCRIPTION "TFTP Loader Plugin"
	ARM/zbl/TFTPLoader.Mos
END

PACKAGE XModemLoader ARCHIVE "XModemLoader.zip" SOURCE "XModemLoaderSrc.zip" DESCRIPTION "XMODEM Loader Plugin"
	ARM/zbl/XModem.Mos
	ARM/zbl/XModemLoader.Mos
END

#### Additional Programmers ####
PACKAGE ZynqFpgaProgrammer ARCHIVE "ZynqFpgaProgrammer.zip" SOURCE "ZynqFpgaProgrammerSrc.zip" DESCRIPTION "Programmer for Zynq FPGA"
	ARM/zbl/ZynqFpgaProgrammer.Mos
END

PACKAGE A2ConfigProgrammer ARCHIVE "A2ConfigProgrammer.zip" SOURCE "A2ConfigProgrammerSrc.zip" DESCRIPTION "Programmer for A2 BootConfig"
	ARM/zbl/A2ConfigProgrammer.Mos
END

#### Additional Checksums ####
PACKAGE MD5Checksum ARCHIVE "MD5Checksum.zip" SOURCE "MD5ChecksumSrc.zip" DESCRIPTION "MD5 Checksum Algorithm"
	MD5.Mod
	ARM/zbl/MD5Checksum.Mos
END
