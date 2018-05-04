# Minos Release Tool
# AUTHOR: Timothée Martiel
# DATE: 12/2015

# FSTools.Mount MINOS RelativeFileSystem /work/EthMinos/minos ~
# Release.Build -f="MINOS:/Minos.Tool" Default ~
# FSTools.Unmount MINOS ~

HEADER
	VERSION "1.0"
END

BUILDS
	
	Default {
		INCLUDE "ZYNQ FPGA"
		COMPILER "Compiler.Compile"
		COMPILEOPTIONS "--metaData=simple --objectFile=Minos"
		TARGET "ARM"
		LINKER "StaticLinker.Link"
		LINKEROPTIONS "--fileName=A2.Bin --displacement=310000H --extension=.arm -a"
		EXCLUDEPACKAGES ""
		PATH ""
		DISABLED "FALSE"
	}

END

PACKAGE Init ARCHIVE "Init.zip" SOURCE "InitSrc.zip" DESCRIPTION "Hardware Initialization"
	
	ZYNQ {
		MINOS:/HAL/zynq/Zynq.Platform.Mos
		MINOS:/HAL/zynq/Generic.Board.Mos
		MINOS:/HAL/zynq/Generic.TclInit.Mos
		MINOS:/HAL/zynq/Zynq.Initializer.Mos
	}

	ARM.FPE64.Mod
	ARM.ARMRuntime.Mod
	MINOS:/Trace.Mos
	MINOS:/Bit.Mos
	MINOS:/Utils.Mos

	ZYNQ {
		MINOS:/HAL/zynq/Zynq.Clocks.Mos
	}

	MINOS:/KernelUtils.Mos

	ZYNQ {
		MINOS:/HAL/zynq/Zynq.PrivateTimer.Mos
		
		MINOS:/HAL/zynq/Zynq.UartMin.Mos
		MINOS:/HAL/zynq/Zynq.Caches.Mos
		MINOS:/HAL/zynq/Zynq.Memory.Mos
	}

	MINOS:/MemoryMapping.Mos

	ZYNQ {
		MINOS:/HAL/zynq/Zynq.Interrupts.Mos
		MINOS:/HAL/zynq/Zynq.GlobalTimer.Mos
		MINOS:/HAL/zynq/Zynq.Reset.Mos
	}
END

PACKAGE Heaps ARCHIVE "Heaps.zip" SOURCE "HeapsSrc.zip" DESCRIPTION "Heap Implementations"
	MINOS:/Heaps.Mos
	MINOS:/UncachedHeaps.Mos
END

PACKAGE Log ARCHIVE "Log.zip" SOURCE "LogSrc.zip" DESCRIPTION "Logger"
	MINOS:/Log.Mos
END

PACKAGE Fpga ARCHIVE "Fpga.zip" SOURCE "FpgaSrc.zip" DESCRIPTION "HAL for FPGA"
	ZYNQ {
		MINOS:/HAL/ct/CoreFPGA.Mos
		MINOS:/HAL/ct/Fpga.Sbus.Mos
		MINOS:/HAL/ct/Fpga.PlUart.Mos
		MINOS:/HAL/ct/IoExpander.Mos
		MINOS:/HAL/ct/UartControl.Mos
	}
END

PACKAGE Kernel ARCHIVE "Kernel.zip" SOURCE "KernelSrc.zip" DESCRIPTION "Kernel"
	ZYNQ { MINOS:/HAL/ct/Fpga.IoControl.Mos }
	MINOS:/Kernel.Mos
END

PACKAGE String ARCHIVE "String.zip" SOURCE "StringSrc.zip" DESCRIPTION "String"
	MINOS:/Strings.Mos
END

PACKAGE Devices ARCHIVE "Devices.zip" SOURCE "DevicesSrc.zip" DESCRIPTION "Device Abstraction"
	MINOS:/Device.Mos
END

PACKAGE Uarts ARCHIVE "Uart" SOURCE "UartSrc.zip" DESCRIPTION "Uart drivers"
	MINOS:/UartConstants.Mos
	ZYNQ { MINOS:/HAL/zynq/Zynq.Uart.Mos }
	FPGA { MINOS:/HAL/ct/PlUart.Mos }
	
	MINOS:/SerialLog.Mos
END

PACKAGE Fs ARCHIVE "Fs.zip" SOURCE "FsSrc.zip" DESCRIPTION "File System"
	MINOS:/OFS.Mos
	MINOS:/OFSRamVolumes.Mos
	MINOS:/Disks.Mos
	MINOS:/OFSDiskVolumes.Mos		
	MINOS:/OFSCacheVolumes.Mos

	MINOS:/HAL/zynq/Zynq.SdEnvironment.Mos
	MINOS:/Sd.Mod
	MINOS:SdDisks.Mos
	MINOS:/HAL/zynq/Zynq.SdControllers.Mod
END

PACKAGE FileTools ARCHIVE "FileTools.zip" SOURCE "FileToolsSrc.zip" DESCRIPTION "File Tools"
	MINOS:/Tools.Mos
END

PACKAGE Modules ARCHIVE "Modules.zip" SOURCE "ModulesSrc.zip" DESCRIPTION "Dynamic Module Loading"
	MINOS:/Modules.Mos
END

PACKAGE Streams ARCHIVE "Streams.zip" SOURCE "StreamsSrc.zip" DESCRIPTION "Stream abstraction"
	MINOS:/StreamReaders.Mos
	MINOS:/StreamWriters.Mos
END

PACKAGE Scheduler ARCHIVE "Scheduler.zip" SOURCE "SchedulerSrc.zip" DESCRIPTION "Scheduler"
	
	MINOS:/XML.Mos
	MINOS:/Minos.Mos
	
	ZYNQ {
		MINOS:/HAL/ct/BoardMonitor.Mos

		MINOS:/HAL/zynq/Zynq.Uart.Task.Mos
		MINOS:/HAL/zynq/Zynq.Uart.Loader.Mos

		MINOS:/HAL/ct/PlUart.Task.Mos
	}

	MINOS:/ProcessMonitor.Mos
	MINOS:/StartUp.Mos

END