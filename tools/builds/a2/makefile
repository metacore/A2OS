all: oberon
commit: Self\ Compilation Compilation\ Tests Execution\ Tests builds

.PHONY: all commit Self\ Compilation Compilation\ Tests Execution\ Tests builds build clean
MAKEFLAGS += --no-builtin-rules --no-builtin-variables
.SUFFIXES: # delete the default suffixes

tool := $(if $(wildcard oberon), ./oberon, ./original)
platforms := Bios32 Bios64 Win32 Win64 Linux32 Linux64 Darwin32 Darwin64 Solaris32 Solaris64 \
	Linux32C Linux64C

target := Linux64
pltfrm := Unix64
object := .GofUu
symbol := .SymUu

# module dependencies

modules: source/Release.Tool
	@AOSPATH=source ./original Release.Build --list $(target) | tr -d '\r' | grep "^[^ ]\+\.Mod\s" | tr -d ' ' > $@

dependencies: modules source/*.Mod
	@./original DependencyWalker.Walk --fileExtension=$(object) $(addprefix source/, $(shell sort -u modules)) DependencyWalker.Mod | tr -d '\r' | grep "^.\+\$(object):" > $@

-include dependencies
FoxArrayBase$(object): ComplexNumbers$(object)

%$(object):
	@$(tool) compile -p=$(pltfrm) $(if $<, $<, $(error no target for $@))

# Fox Compiler

oberon: $(addsuffix $(object), Builtins Trace Glue Unix Machine Heaps Modules Objects Streams Kernel Reflection KernelLog TrapWriters Commands Pipes StdIO Traps Files UnixFiles BitSets StringPool ObjectFile Diagnostics Reals Clock Dates Strings GenericLinker Loader WMRectangles CLUTs Plugins Displays Raster UTF8Strings WMRasterScale SoundDevices XMLObjects DynamicStrings XML XMLScanner XMLParser Configuration Inflate CRC Unzip WMEvents Locks FP1616 Texts Archives Codecs WMGraphics WMDefaultFont StdIOShell Shell Options ProcessInfo0 ProcessInfo SystemVersion System Debugging FoxBasic FoxScanner FoxSyntaxTree FoxGlobal FoxParser FoxFingerPrinter FoxPrintout FoxFormats FoxSemanticChecker FoxBackend FoxFrontend Compiler FoxOberonFrontend FoxSections FoxBinaryCode FoxIntermediateCode FoxInterfaceComparison FoxTextualSymbolFile FoxIntermediateBackend FoxAMD64InstructionSet FoxAMD64Assembler FoxCodeGenerators FoxAMDBackend FoxGenericObjectFile Math MathL ComplexNumbers FoxArrayBase FoxArrayBaseOptimized Linker DependencyWalker Localization Repositories UnicodeProperties TextUtilities ReleaseThreadPool Zlib ZlibBuffers ZlibInflate ZlibReaders ZlibDeflate ZlibWriters Zip CompilerInterface Release)
	@$(tool) Linker.Link -p=$(target) --fileName=$@ Builtins Traps UnixFiles Loader WMDefaultFont StdIOShell Shell System Compiler FoxOberonFrontend FoxAMDBackend FoxArrayBase FoxArrayBaseOptimized Linker DependencyWalker Release && chmod +x $@
# grep ":processing\s$" oberon.log | grep "^[^:]\+" -o | tr '\n' ' '

Self\ Compilation: $(addsuffix $(object), FoxA2Interface FoxActiveCells FoxAMD64Assembler FoxAMD64InstructionSet FoxAMDBackend FoxARMAssembler FoxARMBackend FoxARMInstructionSet FoxArrayBase FoxArrayBaseOptimized FoxAssembler FoxBackend FoxBasic FoxBinaryCode FoxCodeGenerators Compiler FoxCSharpFrontend FoxCSharpParser FoxCSharpScanner FoxDisassembler FoxDocumentationBackend FoxDocumentationHtml FoxDocumentationParser FoxDocumentationPrinter FoxDocumentationScanner FoxDocumentationTree FoxFingerPrinter FoxFormats FoxFrontend FoxGenericObjectFile FoxGlobal FoxHardware FoxInterfaceComparison FoxIntermediateAssembler FoxIntermediateBackend FoxIntermediateCode FoxIntermediateLinker FoxIntermediateObjectFile FoxIntermediateParser FoxInterpreterBackend FoxMinosObjectFile FoxOberonFrontend FoxParser FoxPrintout FoxProfiler FoxProgTools FoxScanner FoxSections FoxSemanticChecker FoxSyntaxTree FoxTest TextCompiler FoxTextualSymbolFile FoxTranspilerBackend FoxTRMAssembler FoxTRMBackend FoxTRMInstructionSet)
# grep "^Fox" modules | sed 's/\.Mod//g' | tr '\n' ' '

Compilation\ Tests: Oberon.Compilation.Test.Diff

Oberon.Compilation.Test.Diff: oberon FoxTest$(object) source/Oberon.Compilation.Test
	@./oberon FoxTest.Compile source/Oberon.Compilation.Test

Execution\ Tests: Oberon.Execution.Test.Diff

Oberon.Execution.Test.Diff: oberon FoxTest$(object) source/Oberon.Execution.Test
	@./oberon FoxTest.Compile source/Oberon.Execution.Test

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
