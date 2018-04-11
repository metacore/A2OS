all: oberon

.PHONY: all compiler execution compilation execution clean
MAKEFLAGS += --no-builtin-rules --no-builtin-variables
.SUFFIXES: # delete the default suffixes

tool := $(if $(wildcard oberon), ./oberon, ./original)
platforms := Linux32G Linux64G Darwin32G Solaris32G Win32G Win64G

# module dependencies

modules: source/Release.Tool
	@env AOSPATH=source ./original Release.Build --list Linux32G | tr -d '\r' | grep "^[^ ]\+\.Mod\s" | tr -d ' ' > $@

dependencies: modules source/*.Mod
	@./original DependencyWalker.Walk --fileExtension=.GofU $(addprefix source/, $(shell sort -u modules)) DependencyWalker.Mod | tr -d '\r' | grep "^.\+\.GofU:" > $@

-include dependencies
Trace.GofU Streams.GofU: Runtime.GofU
FoxArrayBase.GofU: ComplexNumbers.GofU

%.GofU:
	@$(tool) compile $(if $<, $<, $(error no target for $@))

# targets

oberon: $(addsuffix .GofU, Runtime Trace Glue Unix Machine Heaps Modules Objects Streams Kernel Reflection KernelLog TrapWriters Commands Pipes StdIO Traps Files UnixFiles BitSets StringPool ObjectFile Diagnostics Reals Clock Dates Strings GenericLinker GenericLoader WMRectangles CLUTs Plugins Displays Raster UTF8Strings WMRasterScale SoundDevices XMLObjects DynamicStrings XML XMLScanner XMLParser Configuration Inflate CRC Unzip WMEvents Locks FP1616 Texts Archives Codecs WMGraphics WMDefaultFont StdIOShell Shell Options ProcessInfo0 ProcessInfo SystemVersion SystemTools Debugging FoxBasic FoxScanner FoxSyntaxTree FoxGlobal FoxParser FoxFingerPrinter FoxPrintout FoxFormats FoxSemanticChecker FoxBackend FoxFrontend Compiler FoxOberonFrontend FoxSections FoxBinaryCode FoxIntermediateCode FoxInterfaceComparison FoxTextualSymbolFile FoxIntermediateBackend FoxAMD64InstructionSet FoxAMD64Assembler FoxBinarySymbolFile FoxBinaryObjectFile FoxCodeGenerators FoxAMDBackend FoxGenericObjectFile Math MathL ComplexNumbers FoxArrayBase StaticLinker DependencyWalker Localization Repositories UnicodeProperties TextUtilities ReleaseThreadPool Zlib ZlibBuffers ZlibInflate ZlibReaders ZlibDeflate ZlibWriters Zip CompilerInterface Release)
	@$(tool) StaticLinker.Link -p=Linux32G --fileName=$@ Runtime Traps UnixFiles GenericLoader WMDefaultFont StdIOShell Shell SystemTools Compiler FoxOberonFrontend FoxAMDBackend FoxGenericObjectFile FoxArrayBase StaticLinker DependencyWalker Release && chmod +x $@
# grep ":processing\s$" oberon.log | grep "^[^:]\+" -o | tr '\n' ' '

compiler: $(addsuffix .GofU, FoxA2Interface FoxActiveCells FoxAMD64Assembler FoxAMD64InstructionSet FoxAMDBackend FoxARMAssembler FoxARMBackend FoxARMInstructionSet FoxArrayBase FoxAssembler FoxBackend FoxBasic FoxBinaryCode FoxBinaryObjectFile FoxBinarySymbolFile FoxCodeGenerators Compiler FoxCSharpFrontend FoxCSharpParser FoxCSharpScanner FoxDisassembler FoxDocumentationBackend FoxDocumentationHtml FoxDocumentationParser FoxDocumentationPrinter FoxDocumentationScanner FoxDocumentationTree FoxFingerPrinter FoxFormats FoxFrontend FoxGenericObjectFile FoxGlobal FoxHardware FoxInterfaceComparison FoxIntermediateAssembler FoxIntermediateBackend FoxIntermediateCode FoxIntermediateLinker FoxIntermediateObjectFile FoxIntermediateParser FoxInterpreterBackend FoxMinosObjectFile FoxOberonFrontend FoxParser FoxPrintout FoxProfiler FoxProgTools FoxScanner FoxSections FoxSemanticChecker FoxSyntaxTree FoxTest TextCompiler FoxTextualSymbolFile FoxTranspilerBackend FoxTRMAssembler FoxTRMBackend FoxTRMInstructionSet)
# grep "^Fox" modules | sed 's/\.Mod//g' | tr '\n' ' '

compilation: Oberon.Compilation.Test.Diff

Oberon.Compilation.Test.Diff: oberon FoxTest.GofU source/Oberon.Compilation.Test
	@./oberon FoxTest.Compile source/Oberon.Compilation.Test

execution: Oberon.Execution.Test.Diff

Oberon.Execution.Test.Diff: oberon FoxTest.GofU source/Oberon.Execution.Test
	@./oberon FoxTest.Compile source/Oberon.Execution.Test

ifdef platform

.PHONY: build
build: $(if $(filter $(platforms), $(platform)), $(platform), $(error invalid platform))

$(platform): oberon source/Release.Tool $(addprefix source/, $(shell env AOSPATH=source ./original Release.Build --list $(platform) | tr -d '\r' | grep "^[^ ]\+\.Mod\s" | tr -d ' '))
	@rm -rf $@ && mkdir $@
	@env AOSPATH=source ./oberon Release.Build --path=$@/ --build $(platform) || (rm -rf $@ && false)

endif

# utilities

original: oberon
	@cp oberon $@

clean:
	@rm -f modules dependencies oberon *.SymU *.GofU *.Log *.log
	@rm -rf $(platforms)
