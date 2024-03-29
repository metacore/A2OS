all: oberon
commit: Self\ Compilation Compilation\ Tests Execution\ Tests builds

.PHONY: all commit Self\ Compilation Compilation\ Tests Execution\ Tests builds build clean
MAKEFLAGS += --no-builtin-rules --no-builtin-variables
.SUFFIXES: # delete the default suffixes

tool = $(if $(wildcard oberon), ./oberon, ./original)
platforms = Bios32 Bios64 Zynq Win32 Win64 Linux32 Linux64 LinuxARM Darwin32 Darwin64 Solaris32 Solaris64 \
	Bios32C RPiC ZynqC Win32C Linux32C Linux64C

target = Linux64
pltfrm = Unix64
object = .GofUu
symbol = .SymUu

# module dependencies

modules: source/Release.Tool
	@AOSPATH=source ./original Release.Build --list $(target) | tr -d '\r' | grep "^[^ ]\+\.Mod\s" | tr -d ' ' > $@

dependencies: modules source/*.Mod
	@./original DependencyWalker.Walk --define=UNIX,AMD64 --fileExtension=$(object) $(addprefix source/, $(shell sort -u modules)) DependencyWalker.Mod | tr -d '\r' | grep "^.\+\$(object):" > $@

-include dependencies
FoxArrayBase$(object): ComplexNumbers$(object)

%$(object):
	@$(tool) Compiler.Compile -p=$(pltfrm) --objectFileExtension=$(object) --symbolFileExtension=$(symbol) $(if $<, $<, $(error no target for $@))

# Fox Compiler

oberon: $(addsuffix $(object), Builtins Trace Glue Unix Machine Heaps Modules Objects RealConversions Streams Kernel Reflection KernelLog TrapWriters Commands Pipes StdIO Traps Files UnixFiles BitSets StringPool Diagnostics Reals Clock Strings Dates ObjectFile GenericLinker Loader WMRectangles CLUTs Plugins Displays Raster UTF8Strings WMRasterScale SoundDevices XMLObjects DynamicStrings XML XMLScanner XMLParser Configuration Inflate CRC Unzip WMEvents Locks FP1616 Texts Archives Codecs WMGraphics WMDefaultFont Options StdIOShell Shell ProcessInfo0 ProcessInfo SystemVersion System Debugging FoxBasic FoxScanner FoxSyntaxTree FoxGlobal FoxParser FoxFingerprinter FoxPrintout FoxFormats FoxSemanticChecker FoxSections FoxBinaryCode FoxBackend FoxFrontend Compiler FoxOberonFrontend FoxIntermediateCode FoxInterfaceComparison FoxTextualSymbolFile FoxIntermediateBackend FoxAMD64InstructionSet FoxAMD64Assembler FoxGenericObjectFile FoxCodeGenerators FoxAMDBackend FoxDisassembler FoxARMInstructionSet FoxAssembler FoxARMAssembler FoxARMBackend FoxTestBackend MathL Math ComplexNumbers FoxArrayBase FoxArrayBaseOptimized Localization Repositories UnicodeProperties TextUtilities TestSuite Versioning CompilerInterface FoxTest Linker DependencyWalker ReleaseThreadPool Zlib ZlibBuffers ZlibInflate ZlibReaders ZlibDeflate ZlibWriters Zip Release)
	@$(tool) Linker.Link -p=$(target) --extension=$(object) --fileName=$@ $+ && chmod +x $@
# grep ":processing\s$" oberon.log | grep "^[^:]\+" -o | tr '\n' ' '

Self\ Compilation: $(addsuffix $(object), Compiler CompilerInterface FoxA2Interface FoxActiveCells FoxAMD64Assembler FoxAMD64InstructionSet FoxAMDBackend FoxARMAssembler FoxARMBackend FoxARMInstructionSet FoxArrayBase FoxArrayBaseOptimized FoxAssembler FoxBackend FoxBasic FoxBinaryCode FoxCodeGenerators FoxCSharpFrontend FoxCSharpParser FoxCSharpScanner FoxDisassembler FoxDocumentationBackend FoxDocumentationHtml FoxDocumentationParser FoxDocumentationPrinter FoxDocumentationScanner FoxDocumentationTree FoxFingerprinter FoxFormats FoxFrontend FoxGenericObjectFile FoxGlobal FoxHardware FoxInterfaceComparison FoxIntermediateAssembler FoxIntermediateBackend FoxIntermediateCode FoxIntermediateLinker FoxIntermediateObjectFile FoxIntermediateParser FoxInterpreter FoxInterpreterBackend FoxInterpreterSymbols FoxMinosObjectFile FoxOberonFrontend FoxParser FoxPrintout FoxProfiler FoxProgTools FoxScanner FoxSections FoxSemanticChecker FoxSyntaxTree FoxTest FoxTestBackend FoxTextualSymbolFile FoxTranspilerBackend FoxTRMAssembler FoxTRMBackend FoxTRMInstructionSet TextCompiler)
# grep "^\(Fox\|Compiler\|TextCompiler\)" modules | sed 's/\.Mod//g' | sort | tr '\n' ' '

Compilation\ Tests: Oberon.Compilation.Test.Diff

Oberon.Compilation.Test.Diff: oberon source/Oberon.Compilation.Test
	@./oberon FoxTest.Compile source/Oberon.Compilation.Test

Execution\ Tests: Oberon.Execution.Test.Diff

Oberon.Execution.Test.Diff: oberon source/Oberon.Execution.Test
	@./oberon FoxTest.Compile --prolog=\"Compiler.Compile --symbolFileExtension=$(symbol) TesterInput.txt\" source/Oberon.Execution.Test

# A2 Builds

builds:
	@make $(foreach platform,$(platforms),&& make build platform=$(platform))

ifdef platform

build: $(if $(filter $(platforms), $(platform)), $(platform), $(error invalid platform))

$(platform): oberon source/Release.Tool $(addprefix source/, $(shell AOSPATH=source ./original Release.Build --list $(platform) | tr -d '\r' | grep "^[^ ]\+\.Mod\s" | tr -d ' '))
	@rm -rf $@ && mkdir $@
	@AOSPATH=source ./oberon Release.Build --path=$@/ --build $(platform) || (rm -rf $@ && false)

else

build:
	$(error undefined platform)

endif

# utilities

original: oberon
	@cp oberon $@

clean:
	@rm -f modules dependencies oberon *$(symbol) *$(object) *.Log *.log
	@rm -rf $(platforms)
