## initial remarks / caveats
	TextUtilities imports WMGraphics, 
	WMGraphics can block when WMDefaultFont is not loaded. Make sure to link WMDefaultFont into images requiring WMGraphics that should work without module loading
	Modules that must be loaded during startup must be linked before IOShell / Bootconsole, respectively

WIN32G -- 32-bit windows a2 using generic object files
=================================

	## Compile all files ##
		Release.Build WinAosNewObjectFile ~
	
	## Link A2.exe (bootconsole for graphical OS) ##
		StaticLinker.Link --fileFormat=PE32 --fileName=A2.exe --extension=GofW --displacement=401000H  
			Runtime Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands Files WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection  GenericLoader  BootConsole ~		

	## command line shell 
	StaticLinker.Link  --fileFormat=PE32CUI --fileName=oberon.exe --extension=GofW --displacement=401000H 
		Runtime Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands Files  WinFS Clock Dates Reals Strings 
		Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection GenericLoader WinTrace StdIO  
		Traps RelativeFileSystem WMDefaultFont SystemTools StdIOShell ~

	## Command line shell including compiler (and linker) ##
		StaticLinker.Link  --fileFormat=PE32CUI --fileName=oberon.exe --extension=GofW --displacement=401000H 
			Runtime Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands Files  WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection GenericLoader WinTrace 
			StdIO  Traps RelativeFileSystem SystemTools FSTools StdIOShell Shell StaticLinker Compiler FoxOberonFrontend FoxARMBackend FoxAMDBackend ~

FSTools.CloseFiles oberon.exe ~

Compiler.Compile -p=Win32G
Runtime.Mod Trace.Mod Generic.Win32.Kernel32.Mod Win32.Machine.Mod Heaps.Mod 
Generic.Modules.Mod Win32.Objects.Mod Win32.Kernel.Mod KernelLog.Mod Plugins.Mod Streams.Mod Pipes.Mod 
Commands.Mod In.Mod Out.Mod I386.Reals.Mod Generic.Reflection.Mod TrapWriters.Mod CRC.Mod 
SystemVersion.Mod Win32.Traps.Mod Win32.WinTrace.Mod Win32.StdIO.Mod Locks.Mod Win32.Clock.Mod 
Disks.Mod Files.Mod Dates.Mod Strings.Mod UTF8Strings.Mod FileTrapWriter.Mod Caches.Mod 
DiskVolumes.Mod OldDiskVolumes.Mod RAMVolumes.Mod DiskFS.Mod OldDiskFS.Mod OberonFS.Mod 
FATVolumes.Mod FATFiles.Mod ISO9660Volumes.Mod ISO9660Files.Mod Win32.User32.Mod Win32.WinTrace.Mod 
Win32.ODBC.Mod Win32.Shell32.Mod Win32.SQL.Mod Win32.WinFS.Mod RelativeFileSystem.Mod BitSets.Mod 
Diagnostics.Mod StringPool.Mod ObjectFile.Mod GenericLinker.Mod GenericLoader.Mod BootConsole.Mod 
Shell.Mod StdIOShell.Mod ~

SystemTools.FreeDownTo FoxIntermediateBackend ~

LINUX32G -- 32 bit linux a2 using generic object files
================================

	Release.Build -b Linux32G ~
	
	## X11 bootconsole ##
		StaticLinker.Link -p=Linux32G Runtime Trace Glue Unix Machine Heaps Modules Objects Kernel 
		KernelLog  Streams Commands Pipes StdIO TrapWriters Reflection Traps Files UnixFiles Clock Dates 
		Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker   GenericLoader  BootConsole ~
	
	## Command line shell including compiler (and linker) ##
		StaticLinker.Link -p=Linux32G 
			Runtime Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog  Streams Commands Pipes StdIO 
			TrapWriters Reflection Traps Files UnixFiles Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker   GenericLoader  SystemTools StdIOShell 
			Shell StaticLinker Compiler FoxOberonFrontend FoxARMBackend FoxAMDBackend ~


DARWIN32G -- 32 bit darwin a2 using generic object files
================================

	Release.Build -b Darwin32G ~
	
	## X11 bootconsole ##
		StaticLinker.Link -p=Darwin32G  --path=./NewAos/
				Runtime Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog  Streams Commands Pipes StdIO TrapWriters Reflection 
				Traps Files UnixFiles Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker   GenericLoader  BootConsole ~
		UnixBinary.Build  oberon.bin  ->  A2Core ~


SOLARIS32G -- 32 bit solaris a2 using generic object files
================================

	Release.Build -b Solaris32G ~
	
	## X11 bootconsole ##
		StaticLinker.Link -p=Solaris32G  --path=./NewAos/
				Runtime Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog  Streams Commands Pipes StdIO TrapWriters Reflection 
				Traps Files UnixFiles Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker   GenericLoader  BootConsole ~
		UnixBinary.Build  oberon.bin  ->  A2Core ~


Win64G -- work in progress
================

SystemTools.DoCommands 

Compiler.Compile -b=AMD --bits=64 --objectFile=Generic --newObjectFile  --symbolFile=Textual  --objectFileExtension=.GofWw --symbolFileExtension=.SymWw 
	--traceModule=Trace
	AMD64.Runtime.Mod Trace.Mod Generic.Win64.Kernel32.Mod Win64.Machine.Mod Heaps.Mod Generic.Modules.Mod 
	Win64.Objects.Mod Win32.Kernel.Mod  
	KernelLog.Mod Streams.Mod Commands.Mod Files.Mod Win32.WinFS.Mod Win32.Clock.Mod Dates.Mod 
	AMD64.Reals.Mod Strings.Mod Diagnostics.Mod BitSets.Mod
	StringPool.Mod ObjectFile.Mod GenericLinker.Mod GenericLoader.Mod BootConsole.Mod 
	Win32.WinTrace.Mod Pipes.Mod Win32.StdIO.Mod Shell.Mod StdIOShell.Mod 
	Generic.Reflection.Mod CRC.Mod SystemVersion.Mod Win64.Traps.Mod TrapWriters.Mod
	ProducerConsumer.Mod 
	
	~

StaticLinker.Link --fileFormat=PE64CUI --fileName=A264.exe --extension=GofWw --displacement=401000H  
	Runtime Trace Kernel32 
	Heaps Modules Objects Kernel
	KernelLog Streams Commands Files WinFS Clock Dates Reals Strings Diagnostics BitSets 
	StringPool ObjectFile GenericLinker Reflection  GenericLoader Shell  StdIOShell Traps ~

FSTools.CloseFiles A264.exe  ~
~

	KernelLog Streams Commands Files WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection  GenericLoader  BootConsole ~
	~
	 ConsumerProducer TestBoot ~
	ProducerConsumer.Mod TestBoot.Mod 	

~ BootConsole ~		


FoxGenericObjectFile.Show ConsumerProducer.GofWw ~	

SystemTools.FreeDownTo Compiler ~

Compiler.Compile -b=AMD --bits=64 --objectFile=Generic --newObjectFile  --symbolFile=Textual  --objectFileExtension=.GofWw --symbolFileExtension=.SymWw 
	--traceModule=Trace

Disks.Mod
Locks.Mod 
 UTF8Strings.Mod Displays.Mod Inputs.Mod Options.Mod Events.Mod EventsUtils.Mod 
EventsKernelLog.Mod EventsFileLog.Mod EventsMemoryLog.Mod DynamicStrings.Mod XMLObjects.Mod XML.Mod 
XMLScanner.Mod XMLParser.Mod Configuration.Mod FileHandlers.Mod BootShell.Mod ActiveTimers.Mod 
Win32.GDI32.Mod Win32.Display.Mod Win32.WSock32.Mod Win32.Network.Mod Win32.IP.Mod Win32.DNS.Mod 
Win32.UDP.Mod Win32.TCP.Mod Win32.CommandLine.Mod Serials.Mod SoundDevices.Mod Joysticks.Mod 
TVDriver.Mod VirtualDisks.Mod DisplayNull.Mod Win32.V24.Mod Win32.Beep.Mod Win32.WinDisks.Mod 
StringPool.Mod Diagnostics.Mod Debugging.Mod BitSets.Mod ObjectFile.Mod GenericLinker.Mod 
StaticLinker.Mod FoxBasic.Mod FoxProgTools.Mod FoxScanner.Mod FoxCSharpScanner.Mod FoxSyntaxTree.Mod 
FoxGlobal.Mod FoxActiveCells.Mod FoxHardware.Mod FoxFormats.Mod FoxFingerPrinter.Mod 
FoxPrintout.Mod FoxParser.Mod FoxCSharpParser.Mod FoxSemanticChecker.Mod FoxBackend.Mod 
FoxSections.Mod FoxFrontend.Mod FoxCompiler.Mod FoxOberonFrontend.Mod FoxCSharpFrontend.Mod 
FoxInterfaceComparison.Mod FoxTextualSymbolFile.Mod FoxBinarySymbolFile.Mod FoxBinaryCode.Mod 
FoxIntermediateCode.Mod FoxIntermediateBackend.Mod FoxCodeGenerators.Mod FoxBinaryObjectFile.Mod 
FoxGenericObjectFile.Mod FoxAMD64InstructionSet.Mod FoxAMD64Assembler.Mod FoxAMDBackend.Mod FoxAssembler.Mod 
FoxIntermediateAssembler.Mod FoxDisassembler.Mod FoxARMInstructionSet.Mod FoxARMAssembler.Mod FoxARMBackend.Mod 
FoxMinosObjectFile.Mod FoxIntermediateParser.Mod FoxIntermediateObjectFile.Mod FoxIntermediateLinker.Mod 
FoxTRMInstructionSet.Mod FoxTRMAssembler.Mod FoxTRMBackend.Mod FoxInterpreterBackend.Mod 
FoxTranspilerBackend.Mod FoxDocumentationScanner.Mod FoxDocumentationTree.Mod FoxDocumentationPrinter.Mod 
FoxDocumentationHtml.Mod FoxDocumentationParser.Mod FoxDocumentationBackend.Mod FoxProfiler.Mod 
XMM.I386.Math.Mod XMM.I386.MathL.Mod ComplexNumbers.Mod FoxArrayBase.Mod 
I386.FoxArrayBaseOptimized.Mod Errors.Mod ProcessInfo0.Mod ProcessInfo.Mod SystemTools.Mod Reboot.Mod 
Win32.WinApplications.Mod XMM.I386.Math.Mod XMM.I386.MathL.Mod Random.Mod Drand48.Mod SerialsVirtual.Mod 
Autostart.Mod FSTools.Mod UpTime.Mod CLUTs.Mod I386.Raster.Mod Localization.Mod Archives.Mod 
WMRectangles.Mod WMEvents.Mod Repositories.Mod FP1616.Mod Texts.Mod UndoManager.Mod CRC.Mod Inflate.Mod 
Unzip.Mod ZipFS.Mod Codecs.Mod UnicodeProperties.Mod ContextualDependency.Mod 
UnicodeBidirectionality.Mod I386.WMRasterScale.Mod WMGraphics.Mod WMGraphicsSmooth.Mod TextUtilities.Mod 
Types.Mod Models.Mod WMProperties.Mod WMMessages.Mod WMWindowManager.Mod 
WMGraphicUtilities.Mod WMDropTarget.Mod WMComponents.Mod KernelLogger.Mod CompilerInterface.Mod 
FoxTextCompiler.Mod PCDebug.Mod PCM.Mod PCS.Mod PCT.Mod PCBT.Mod PCLIR.Mod PCO.Mod PCG386.Mod PCC.Mod PCV.Mod 
PCArrays.Mod PCB.Mod PCP.Mod PCA386.Mod PCOM.Mod PCOF.Mod PCOFPE.Mod PC.Mod ArrayBase.Mod 
I386.ArrayBaseOptimized.Mod PCOARM.Mod PCARMCP.Mod PCARMRegisters.Mod PCAARM.Mod PCGARM.Mod ASMAMD64.Mod 
PCAAMD64.Mod PCGAMD64.Mod WhitespaceRemover.Mod HostClipboard.Mod Win32.Clipboard.Mod Tar.Mod 
Zlib.Mod ZlibBuffers.Mod ZlibDeflate.Mod ZlibInflate.Mod ZlibWriters.Mod ZlibReaders.Mod 
Zip.Mod ZipTool.Mod BIT.Mod PNGDecoder.Mod BMPCodec.Mod GIFCodec.Mod JPEGDecoder.Mod 
AnimationCodec.Mod PartitionsLib.Mod FATScavenger.Mod Partitions.Mod DiskTests.Mod DiskBenchmark.Mod 
PartitionEditorTable.Mod Win32.HierarchicalProfiler0.Mod HierarchicalProfiler.Mod FTPClient.Mod XYModem.Mod 
Shell.Mod ShellSerial.Mod Installer.Mod CryptoBigNumbers.Mod CryptoBase64.Mod CryptoUtils.Mod 
CryptoCiphers.Mod CryptoARC4.Mod CryptoDES.Mod CryptoDES3.Mod CryptoHashes.Mod CryptoMD5.Mod 
CryptoSHA1.Mod CryptoSHA256.Mod CryptoKeccakF1600.Mod CryptoKeccakSponge.Mod CryptoSHA3.Mod 
CryptoCSPRNG.Mod CryptoPrimes.Mod CryptoDSA.Mod CryptoDiffieHellman.Mod CryptoAES.Mod 
CryptoBlowfish.Mod CryptoTwofish.Mod CryptoCAST.Mod CryptoHMAC.Mod CryptoIDEA.Mod CryptoRSA.Mod 
Checksum.Mod Fido.Mod I386.CPUID.Mod A2Sequencers.Mod PictImages.Mod V24Tracer.Mod 
XMLGeneratorSchema.Mod CSS2.Mod CSS2Scanner.Mod CSS2Parser.Mod RAWPrinter.Mod LPR.Mod ASN1.Mod PKCS1.Mod 
X509.Mod TLS.Mod TCPServices.Mod TestServer.Mod TCPTools.Mod Win32.Performance.Mod Bin2Hex.Mod 
BinToCode.Mod Base64.Mod DisplayGTF.Mod GZip.Mod ShellCommands.Mod Telnet.Mod Info.Mod TFClasses.Mod 
Mail.Mod SMTPClient.Mod TFLog.Mod WebHTTP.Mod WebHTTPClient.Mod WebHTTPTools.Mod 
WebHTTPServer.Mod WebHTTPServerTools.Mod WebSSMPPlugin.Mod WebDefaultSSMP.Mod 
WebHTTPServerStatistics.Mod POP3Client.Mod RFC865Client.Mod QuoteServer.Mod FTPFS.Mod WebFTPServer.Mod XModem.Mod 
SearchTools.Mod DiffLib.Mod TextConverter.Mod TaskScheduler.Mod FTP.Mod DES.Mod VNCServer.Mod 
WAVCodec.Mod MP3Decoder.Mod I386.IDCT.Mod AVI.Mod DivXTypes.Mod I386.DivXHelper.Mod 
I386.DivXDecoder.Mod MPEGTables.Mod I386.MPEGUtilities.Mod MPEGVideoDecoder.Mod JPEG2000DecoderUtil.Mod 
JPEG2000DecoderCS.Mod JPEG2000Decoder.Mod MD5.Mod HTTPSupport.Mod HTTPSession.Mod DynamicWebpage.Mod 
DynamicWebpagePlugin.Mod PrevalenceSystem.Mod WMDropTarget.Mod GenericSort.Mod WebStd.Mod WebComplex.Mod 
WMCharCodes.Mod HTMLScanner.Mod HTMLParser.Mod NewHTTPClient.Mod UnihanParser.Mod CSV.Mod 
ColorModels.Mod WMDefaultWindows.Mod WMDefaultFont.Mod WMFontManager.Mod WMOberonFonts.Mod 
WMCCGFonts.Mod WMBitmapFont.Mod OpenTypeInt.Mod OpenTypeScan.Mod OpenType.Mod OpenTypeFonts.Mod 
WMOTFonts.Mod WindowManager.Mod  ~