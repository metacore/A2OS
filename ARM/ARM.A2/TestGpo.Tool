A2 on ARM


For Zynq/ZedBoard targets, the compilation line is:

Compiler.Compile -b=ARM --traceModule=Trace --objectFile=Generic --destPath=arm.bin
	ARM.A2/Initializer.Zynq.Mod

	ARM.A2/Runtime.Mod

	ARM.A2/Zynq.ARM.Platform.Mod
	ARM.A2/FPE64.Mod
	ARM.A2/ARM.ARMRuntime.Mod
	ARM.A2/Trace.Mod
	ARM.A2/Zynq.Uart.orig.Mod

	ARM.A2/ARM.Machine.Mod
	ARM.A2/Heaps.Mod
	oc/Generic.Modules.Mod
	ARM.A2/Objects.Mod
	ARM.A2/Kernel.Mod

	ARM.A2/TestGPO.Mod
~

StaticLinker.Link --fileName=Test.Bin --displacement=100000H -a --path=arm.bin
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

	TestGpo
~
V24.Scan 
WMV24Component.Open 15 115200 8 1 none ~

/!\ NOTE that the Initializer module, which provides processor and chip initialization is linked before Runtime.
The reason for that is that Initializer does some sensitive operations, like setting up a stack, that do not mix
well with the automatic inclusion of a call to Runtime.Publish. Therefore Runtime IMPORTS Initializer.

Moreover, the TCL initialization and interrupt vectors form a second, smaller executable for the Zynq/ZedBoard platforms,
as the main image is loaded in external memory. You can generate it as follows:

Compiler.Compile -b=ARM --metaData=simple --destPath=arm.bin
	ARM.A2/Initializer.TCL.Zynq.Mod
~

StaticLinker.Link --fileName=Init.Bin --displacement=0H -sa --path=arm.bin
	ZynqInitializer
~

FoxARMInstructionSet.Disassemble Test.Bin -a=00013DEB4H ~
FoxARMInstructionSet.Disassemble Test.Bin ~
Test.Log

FoxARMInstructionSet.Disassemble Init.Bin -a=40H ~

Compiler.Compile -b=TRM --objectFile=Intermediate --activeCells 
oc/TRM.TRMRuntime.Mod
oc/TRM.Heaps.Mdf
Fox/AxisChannels.Mod
Fox/Engines.Mdf
ARM.A2/TestGpo.Mdf
~

ActiveCellsComponents.AddPath "ActiveCells-HWL"~

ActiveCellsComponents.BuildHardware --target="ActiveCells-HWL/Zedboard-Hybrid.achc.xml" --outputPath="TestGpo" TestGpo ~
