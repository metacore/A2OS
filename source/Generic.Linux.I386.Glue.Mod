(* Minimal ELF header for self contained linux Oberon programs *)
(* Copyright (c) Felix Friedrich, ETH Zürich *)

MODULE Glue; 

IMPORT SYSTEM, Trace;

CONST 
	base* = 08048000H;
	debug* = {};
VAR
	last-: RECORD END; (* empty variable linked to end of kernel *)
	
	baseAdr*: ADDRESS;
	endAdr*: ADDRESS;
	
	dlsym-	: PROCEDURE {C} ( handle: ADDRESS; name: ADDRESS): ADDRESS;
	dlopen-	: PROCEDURE {C} ( pathname: ADDRESS; mode: LONGINT ): ADDRESS;
	dlclose-	: PROCEDURE {C} ( handle: ADDRESS );
	exit-		: PROCEDURE {C} (status: LONGINT);

	stackBottom-	: ADDRESS;	(* of main thread *)


	argc-: WORD; 
	argv-: ADDRESS;
	environ-: ADDRESS;

	PROCEDURE {INITIAL, NOPAF} EntryPoint;
	CODE
		; ELF header
		DB 07FH, 'ELF', 1, 1, 1, 0
		DD 0, 0
		DW 02, 03
		DD 01
		DD entry + base; program entry point
		DD elfheadersize
		DD 0
		DD 0
		DW elfheadersize
		DW 20H
		DW 3 ; #program header table entries
		DW 0
		DW 0
		DW 0

		elfheadersize:

		; program header
		DD 1
		DD 0
		DD base; 
		DD base; 
		DD @last - base; segment size (file)
		DD @last - base; segment size (memory)
		DD 07
		DD 1000H; alignment
		
		; interpreter header
		DD 3
		DD interpretername; interpreter name offset
		DD interpretername + base; interpreter name 
		DD interpretername + base; interpreter name
		DD interpretername_end - interpretername ; interpreter name length
		DD interpretername_end - interpretername ; interpreter name length
		DD 4H
		DD 1H

		; dynamic header
		DD 02H
		DD dynamicsection 
		DD dynamicsection + base
		DD dynamicsection + base
		DD dynamicsection_end - dynamicsection ; size of dynamic section
		DD dynamicsection_end - dynamicsection ; size of dynamic section
		DD 06H
		DD 04H

		dynamicsection:
		DD 05H, base + stringtable
		DD 06H, symboltablebegin + base
		DD 07H, dlsymrelocation + base
		DD 08H, dlsymrelocation_end-dlsymrelocation ; size (relocationtable)
		DD 09H, 0CH
		DD 0AH, stringtable_end - stringtable; size (stringtable)
		DD 0BH, 10H
		
		DD 01H, libname - stringtable; position of libname
		DD 0H, 0H ; sentinel
		dynamicsection_end:		
		
	 	dlsymrelocation:
		DD @dlsym
		DB 01H
		DB 01H, 00H, 00H; index of the symbol
		DD 0H
		dlsymrelocation_end:

		stringtable:
		DB 0H ; sentinel

		libname:
		DB 'libdl.so.2', 0
		
		dlsymname:
		DB 'dlsym', 0
		
		
		stringtable_end:
		
		ALIGN 4
		symboltablebegin:
		DD	0;
		DD	0
		DD	0
		DB	0
		DB	0
		DW 0
		
		; dlsym symbol
		DD dlsymname - stringtable; position of dlsymname
		DD	0
		DD	0
		DB	12H ; info: global + function
		DB 0
		DW	0

		interpretername:
		DB '/lib/ld-linux.so.2', 0
		interpretername_end:

		ALIGN 4

		entry:
	END EntryPoint;

	(*
	PROCEDURE {FINAL} ExitPoint;
	BEGIN
		Trace.String("exiting"); Trace.Ln;
		exit(0);
	END ExitPoint;
	*)

	PROCEDURE {NOPAF} putc*(file: ADDRESS; c: CHAR);
	CODE
		PUSH ECX
		MOV EAX, 4
		MOV EBX, [ESP + 12]
		LEA ECX, [ESP+8]	
		MOV EDX, 1
		INT 80H
		POP ECX
		JNE fail
		MOV EAX, [ESP + 4]
		RET
		fail:
		MOV EAX, -1
		RET
	END putc;

	PROCEDURE Dlsym*(handle: ADDRESS; CONST name: ARRAY OF CHAR; adr: ADDRESS);
	VAR val: ADDRESS;
	BEGIN
		val := dlsym(handle, ADDRESS OF name[0]);
		SYSTEM.PUT32(adr, val);
	END Dlsym;

	PROCEDURE Char(c: CHAR);
	BEGIN
		putc(1, c);
	END Char;
 
	PROCEDURE Init;
	VAR i: LONGINT;
	BEGIN
		baseAdr := ADDRESS OF EntryPoint;
		endAdr := ADDRESS OF last;
		
		Trace.Init;
		Trace.Char := Char;
		
		stackBottom := ADDRESSOF( i ) + 2*SIZEOF(ADDRESS);
		ASSERT(dlsym # NIL);
		Dlsym(0,"dlopen", ADDRESS OF dlopen);
		ASSERT(dlopen # NIL); 
		Dlsym( 0, "dlclose", ADDRESS OF dlclose);
		ASSERT(dlclose # NIL); 
		Dlsym(0,"exit", ADDRESS OF exit);
		ASSERT(exit # NIL);
	END Init;
	
	PROCEDURE {INITIAL,NOPAF} Init0;
	BEGIN
		(*initial stack layout:
			argc at esp
			argv at esp+4
			0 at esp+4+argc*4
			env at esp+4+argc*4+4      =   (2+argc)<<2 + esp*)
		CODE{SYSTEM.i386}
			MOV EAX, [ESP]
			MOV argc, EAX
			LEA EAX, [ESP+4]
			MOV argv, EAX
			MOV EAX, [ESP]
			ADD EAX, 2
			SHL EAX, 2
			ADD EAX, ESP
			MOV environ, EAX
		END;
		Init;
	END Init0;
	
	PROCEDURE Initialize*;
	BEGIN
		(* nothing, only for compatibility *)
	END Initialize;
	

END Glue.



SystemTools.FreeDownTo FoxIntermediateBackend ~

SystemTools.DoCommands
	Compiler.Compile -p=Linux32G
		Runtime.Mod Trace.Mod Generic.Linux.I386.Glue.Mod Generic.Linux.I386.Unix.Mod Generic.Unix.I386.Machine.Mod Heaps.Mod  Generic.Modules.Mod 
		Generic.Unix.Objects.Mod 
		Unix.Kernel.Mod KernelLog.Mod Plugins.Mod Streams.Mod 
		Pipes.Mod Commands.Mod I386.Reals.Mod Generic.Reflection.Mod TrapWriters.Mod CRC.Mod SystemVersion.Mod 
		Unix.StdIO.Mod Generic.Unix.Traps.Mod Locks.Mod Unix.Clock.Mod Disks.Mod Files.Mod Dates.Mod Strings.Mod 
		UTF8Strings.Mod FileTrapWriter.Mod Caches.Mod DiskVolumes.Mod OldDiskVolumes.Mod RAMVolumes.Mod 
		DiskFS.Mod OldDiskFS.Mod OberonFS.Mod FATVolumes.Mod FATFiles.Mod ISO9660Volumes.Mod 
		ISO9660Files.Mod Unix.UnixFiles.Mod RelativeFileSystem.Mod BitSets.Mod StringPool.Mod DIagnostics.Mod 
		ObjectFile.Mod GenericLinker.Mod GenericLoader.Mod Unix.BootConsole.Mod 
	~

	StaticLinker.Link --fileFormat=Raw --fileName=simple_elf --extension=.GofU --displacement=08048000H
		Runtime Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog 
Streams Commands StdIO TrapWriters Traps 
Files UnixFiles Clock Dates Reals Strings Diagnostics 
BitSets StringPool ObjectFile GenericLinker Reflection  GenericLoader  
BootConsole 
 ~

	FSTools.CloseFiles simple_elf ~
~ 

MODULE Test;

IMPORT StdIO, Commands, Streams, Modules;

PROCEDURE Execute(context: Commands.Context);
VAR str, msg: ARRAY 256 OF CHAR;  res: LONGINT;
BEGIN
	IF ~context.arg.GetString(str) THEN RETURN END;
	IF ~context.arg.GetString(str) THEN 
		context.out.String("no command"); context.out.Ln;
		RETURN
	END;
	Commands.Activate(str, context, {Commands.Wait}, res, msg);
END Execute;

BEGIN
	Execute(StdIO.env);
	Modules.Shutdown(1);
END Test.


#	Release.Build --path="../obg/"  WinAosNewObjectFile ~
#	StaticLinker.Link --fileFormat=PE32 --fileName=A2.exe --extension=GofW --displacement=401000H --path="../obg/" 

Runtime Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog 
Streams Commands FIles WinFS Clock Dates Reals Strings Diagnostics 
BitSets StringPool ObjectFile GenericLinker Reflection  GenericLoader  BootConsole ~

FoxGenericObjectFile.Show Machine.GofU ~


# LinuxAos
# Wednesday, September 7, 2016  18:54:57
# This file has been automatically generated using Release.Mod.
# Red colors indicate that a module imports SYSTEM.
SystemTools.DoCommands
SystemTools.Timer start ~
Compiler.Compile  -b=AMD --objectFileExtension=.Obj --symbolFileExtension=.Obj --destPath=NewAos/
Runtime.Mod Trace.Mod Unix.Glue.Mod Linux.I386.Unix.Mod Unix.I386.Machine.Mod 
Unix.Heaps.Mod Modules.Mod Unix.Objects.Mod Unix.Kernel.Mod KernelLog.Mod Plugins.Mod Streams.Mod 
Pipes.Mod Commands.Mod I386.Reals.Mod Reflection.Mod TrapWriters.Mod CRC.Mod SystemVersion.Mod 
Unix.StdIO.Mod Unix.Traps.Mod Locks.Mod Unix.Clock.Mod Disks.Mod Files.Mod Dates.Mod Strings.Mod 
UTF8Strings.Mod FileTrapWriter.Mod Caches.Mod DiskVolumes.Mod OldDiskVolumes.Mod RAMVolumes.Mod 
DiskFS.Mod OldDiskFS.Mod OberonFS.Mod FATVolumes.Mod FATFiles.Mod ISO9660Volumes.Mod 
ISO9660Files.Mod Unix.UnixFiles.Mod RelativeFileSystem.Mod Loader.Mod Unix.BootConsole.Mod

Compiler.Compile -p=Linux32G
Displays.Mod Inputs.Mod Options.Mod Events.Mod EventsUtils.Mod EventsKernelLog.Mod 
EventsFileLog.Mod EventsMemoryLog.Mod DynamicStrings.Mod XMLObjects.Mod XML.Mod XMLScanner.Mod 
XMLParser.Mod Configuration.Mod FileHandlers.Mod BootShell.Mod I386.Network.Mod ActiveTimers.Mod 
Unix.IP.Mod Unix.Sockets.Mod Unix.TCP.Mod Unix.UDP.Mod Unix.DNS.Mod Serials.Mod SoundDevices.Mod 
Joysticks.Mod TVDriver.Mod VirtualDisks.Mod DisplayNull.Mod Unix.V24.Mod Unix.OpenAL.Mod 
OpenALSound.Mod StringPool.Mod Diagnostics.Mod Debugging.Mod BitSets.Mod ObjectFile.Mod 
GenericLinker.Mod StaticLinker.Mod FoxBasic.Mod FoxProgTools.Mod FoxScanner.Mod FoxCSharpScanner.Mod 
FoxSyntaxTree.Mod FoxGlobal.Mod FoxActiveCells.Mod FoxHardware.Mod FoxFormats.Mod FoxPrintout.Mod 
FoxParser.Mod FoxCSharpParser.Mod FoxSemanticChecker.Mod FoxBackend.Mod FoxSections.Mod 
FoxFrontend.Mod FoxOberonFrontend.Mod FoxCSharpFrontend.Mod FoxCompiler.Mod FoxFingerPrinter.Mod 
FoxInterfaceComparison.Mod FoxTextualSymbolFile.Mod FoxBinarySymbolFile.Mod FoxBinaryCode.Mod 
FoxIntermediateCode.Mod FoxIntermediateBackend.Mod FoxCodeGenerators.Mod FoxBinaryObjectFile.Mod 
FoxGenericObjectFile.Mod FoxAMD64InstructionSet.Mod FoxAMD64Assembler.Mod FoxAMDBackend.Mod FoxAssembler.Mod 
FoxIntermediateAssembler.Mod FoxDisassembler.Mod FoxARMInstructionSet.Mod FoxARMAssembler.Mod FoxARMBackend.Mod 
FoxMinosObjectFile.Mod FoxIntermediateParser.Mod FoxIntermediateObjectFile.Mod FoxIntermediateLinker.Mod 
FoxTRMInstructionSet.Mod FoxTRMAssembler.Mod FoxTRMBackend.Mod FoxInterpreterBackend.Mod 
FoxTranspilerBackend.Mod FoxDocumentationScanner.Mod FoxDocumentationTree.Mod FoxDocumentationPrinter.Mod 
FoxDocumentationHtml.Mod FoxDocumentationParser.Mod FoxDocumentationBackend.Mod FoxProfiler.Mod 
XMM.I386.Math.Mod XMM.I386.MathL.Mod FoxArrayBase.Mod I386.FoxArrayBaseOptimized.Mod Errors.Mod 
Unix.ProcessInfo0.Mod ProcessInfo.Mod SystemTools.Mod Reboot.Mod XMM.I386.Math.Mod XMM.I386.MathL.Mod 
Random.Mod Drand48.Mod SerialsVirtual.Mod Autostart.Mod FSTools.Mod UpTime.Mod CLUTs.Mod 
I386.Raster.Mod Localization.Mod Archives.Mod WMRectangles.Mod WMEvents.Mod Repositories.Mod 
FP1616.Mod Texts.Mod UndoManager.Mod CRC.Mod Inflate.Mod Unzip.Mod ZipFS.Mod Codecs.Mod 
UnicodeProperties.Mod ContextualDependency.Mod UnicodeBidirectionality.Mod I386.WMRasterScale.Mod 
WMGraphics.Mod TextUtilities.Mod Types.Mod Models.Mod WMProperties.Mod WMMessages.Mod 
WMWindowManager.Mod WMGraphicUtilities.Mod WMDropTarget.Mod WMComponents.Mod KernelLogger.Mod 
CompilerInterface.Mod FoxTextCompiler.Mod PCDebug.Mod PCM.Mod PCS.Mod PCT.Mod PCBT.Mod PCLIR.Mod PCO.Mod 
PCG386.Mod PCC.Mod PCV.Mod PCArrays.Mod PCB.Mod PCP.Mod PCA386.Mod PCOM.Mod PCOF.Mod PCOFPE.Mod 
PC.Mod PCOARM.Mod PCARMCP.Mod PCARMRegisters.Mod PCAARM.Mod PCGARM.Mod ASMAMD64.Mod 
PCAAMD64.Mod PCGAMD64.Mod WhitespaceRemover.Mod HostClipboard.Mod Tar.Mod Zlib.Mod ZlibBuffers.Mod 
ZlibDeflate.Mod ZlibInflate.Mod ZlibWriters.Mod ZlibReaders.Mod Zip.Mod ZipTool.Mod BIT.Mod 
PNGDecoder.Mod BMPCodec.Mod GIFCodec.Mod JPEGDecoder.Mod AnimationCodec.Mod PartitionsLib.Mod 
FATScavenger.Mod Partitions.Mod DiskTests.Mod DiskBenchmark.Mod PartitionEditorTable.Mod 
FTPClient.Mod XYModem.Mod Shell.Mod ShellSerial.Mod Installer.Mod CryptoBigNumbers.Mod 
CryptoBase64.Mod CryptoUtils.Mod CryptoCiphers.Mod CryptoARC4.Mod CryptoDES.Mod CryptoDES3.Mod 
CryptoHashes.Mod CryptoMD5.Mod CryptoSHA1.Mod CryptoSHA256.Mod CryptoKeccakF1600.Mod 
CryptoKeccakSponge.Mod CryptoSHA3.Mod CryptoCSPRNG.Mod CryptoPrimes.Mod CryptoDSA.Mod 
CryptoDiffieHellman.Mod CryptoAES.Mod CryptoBlowfish.Mod CryptoTwofish.Mod CryptoCAST.Mod CryptoHMAC.Mod 
CryptoIDEA.Mod CryptoRSA.Mod Checksum.Mod Fido.Mod I386.CPUID.Mod A2Sequencers.Mod PictImages.Mod 
V24Tracer.Mod XMLGeneratorSchema.Mod CSS2.Mod CSS2Scanner.Mod CSS2Parser.Mod RAWPrinter.Mod LPR.Mod 
ASN1.Mod PKCS1.Mod X509.Mod TLS.Mod TCPServices.Mod TestServer.Mod TCPTools.Mod 
Win32.Performance.Mod Bin2Hex.Mod BinToCode.Mod Base64.Mod DisplayGTF.Mod GZip.Mod ShellCommands.Mod 
Telnet.Mod TFClasses.Mod Mail.Mod SMTPClient.Mod TFLog.Mod WebHTTP.Mod WebHTTPClient.Mod 
WebHTTPTools.Mod WebHTTPServer.Mod WebHTTPServerTools.Mod WebSSMPPlugin.Mod 
WebHTTPServerStatistics.Mod POP3Client.Mod RFC865Client.Mod QuoteServer.Mod FTPFS.Mod XModem.Mod SearchTools.Mod 
DiffLib.Mod TextConverter.Mod TaskScheduler.Mod FTP.Mod DES.Mod VNCServer.Mod WAVCodec.Mod 
MP3Decoder.Mod I386.IDCT.Mod AVI.Mod DivXTypes.Mod I386.DivXHelper.Mod I386.DivXDecoder.Mod 
MPEGTables.Mod I386.MPEGUtilities.Mod MPEGVideoDecoder.Mod JPEG2000DecoderUtil.Mod 
JPEG2000DecoderCS.Mod JPEG2000Decoder.Mod MD5.Mod HTTPSupport.Mod HTTPSession.Mod DynamicWebpage.Mod 
DynamicWebpagePlugin.Mod PrevalenceSystem.Mod WMDropTarget.Mod GenericSort.Mod WebStd.Mod WebComplex.Mod 
WMCharCodes.Mod HTMLScanner.Mod HTMLParser.Mod NewHTTPClient.Mod UnihanParser.Mod CSV.Mod 
ColorModels.Mod WMDefaultWindows.Mod WMDefaultFont.Mod WMFontManager.Mod WMOberonFonts.Mod 
WMCCGFonts.Mod WMBitmapFont.Mod OpenTypeInt.Mod OpenTypeScan.Mod OpenType.Mod OpenTypeFonts.Mod 
WMOTFonts.Mod WindowManager.Mod Generic.Unix.X11.Mod Unix.X11Api.Mod Unix.XDisplay.Mod Unix.Beep.Mod 
Unix.KbdMouse.Mod Unix.Clipboard.Mod Attributes.Mod WMStandardComponents.Mod WMProgressComponents.Mod 
WMShapes.Mod WMFigures.Mod WMScrollableComponents.Mod WMPieMenu.Mod WMPopups.Mod 
PositionDebugging.Mod SyntaxHighlighter.Mod WMTextView.Mod WMInputMethods.Mod WMEditors.Mod 
WMSearchComponents.Mod WMMacros.Mod WMGrids.Mod WMStringGrids.Mod WMTrees.Mod WMMixer.Mod 
WMTabComponents.Mod WMColorComponents.Mod WMAnimations.Mod WMDropDownLists.Mod WMRestorable.Mod 
WMApplications.Mod WMDialogs.Mod WMDocumentEditor.Mod WMErrors.Mod WMOSD.Mod WMArchives.Mod 
WMCharMap.Mod WMUnicodeMarkerTool.Mod Unix.DisplayRefresher.Mod ModuleParser.Mod ModuleTrees.Mod 
WMXMLTree.Mod WMDiagnostics.Mod PETTrees.Mod PETModuleTree.Mod PETXMLTree.Mod PET.Mod 
WMArabicIME.Mod WMArmenianIME.Mod WMHebrewIME.Mod WMPinyinIME.Mod WMRussianIME.Mod 
WMUkrainianIME.Mod WMEthiopicIME.Mod WMUnicodeIME.Mod WMInputMethodTool.Mod WMUtilities.Mod 
WMTrapWriter.Mod FoxA2Interface.Mod WMMenus.Mod WMDiagramComponents.Mod MainMenu.Mod StartMenu.Mod 
HotKeys.Mod WMNavigate.Mod WMNavigator.Mod WMDesktops.Mod Notepad.Mod WMSystemComponents.Mod 
WMFileManager.Mod WMSearchTool.Mod WMFTPClient.Mod SkinLanguage.Mod FNHistories.Mod SkinEngine.Mod 
WMProcessInfo.Mod WMObjectTracker.Mod WMKernelLog.Mod WMEventLog.Mod WMPartitionsComponents.Mod 
WMPartitions.Mod PartitionEditorComponents.Mod PartitionEditor.Mod MultiLogger.Mod MemoryReader.Mod 
Decoder.Mod I386Decoder.Mod ARMDecoder.Mod AMD64Decoder.Mod WMTextTool.Mod WMPerfMonPlugins.Mod 
WMPerfMonAlerts.Mod WMPerfMonAlertsUtils.Mod Unix.WMPerfMonPluginCpu.Mod 
 WMPerfMonPluginProcesses.Mod WMPerfMonPluginSerials.Mod WMPerfMonPluginNetwork.Mod 
WMPerfMonPluginDisks.Mod WMPerfMonPluginPerfMon.Mod WMPerfMonPluginEvents.Mod WMPerfMonPluginMessages.Mod 
WMPerfMonComponents.Mod WMPerfMonTabSystem.Mod WMPerfMonTabAlerts.Mod WMPerfMon.Mod WMClock.Mod 
WMCalendar.Mod WMV24Component.Mod WMShell.Mod SSHGlobals.Mod SSHKeys.Mod SSHTransport.Mod 
SSHAuthorize.Mod SSH.Mod SSHClient.Mod TFStringPool.Mod BimboScanner.Mod TFTypeSys.Mod TFDumpTS.Mod 
TFScopeTools.Mod TFCheck.Mod TFAOParser.Mod TFModuleTrees.Mod TFPET.Mod TFClasses.Mod 
TFDocGenerator.Mod TFXRef.Mod CharacterLineup.Mod WMDesktopIcons.Mod WMTextStyleTool.Mod WMVNCView.Mod 
VNC.Mod WMVT100.Mod SkinEditor.Mod Looks.Mod WMSkinLoader.Mod WMBackdropLoader.Mod 
WMInspectionComponents.Mod WMInspector.Mod WMRepositories.Mod WMBuilder.Mod WMBuilderTransformer.Mod 
CyberbitNetInstall.Mod WMDiff.Mod WMTaskScheduler.Mod IMAPUtilities.Mod IMAP.Mod IMAPClient.Mod RMSMTP.Mod 
IMAPGUI.Mod WMPerfMonPluginHTTPServer.Mod WMPerfMonPluginQuoteServer.Mod 
WMPerfMonPluginVNCServer.Mod WMPerfMonPluginExample.Mod WMModuleState.Mod WMKeyCode.Mod WMPicView.Mod 
ComponentViewer.Mod WMScreenShot.Mod WMBackdrop.Mod WMInstaller.Mod HotKeysCommands.Mod 
I386.VMWareTools.Mod SynergyClient.Mod I386.WMTransitions.Mod MediaPlayer.Mod Presentation.Mod 
MP3Player.Mod WMPlayer.Mod WAVRecorder.Mod OGGUtilities.Mod OGGVorbisPlayer.Mod WMOGGPlayer.Mod 
DTPData.Mod DTPUtilities.Mod DTPView.Mod DTPEditor.Mod DTPText.Mod DTPRect.Mod DTPImage.Mod 
GfxMatrix.Mod GfxImages.Mod GfxPaths.Mod GfxRegions.Mod GfxFonts.Mod Gfx.Mod GfxRaster.Mod 
GfxBuffer.Mod WMGraphicsGfx.Mod CSS2Properties.Mod XMLComponents.Mod XMLStyle.Mod XMLLoader.Mod 
SVGUtilities.Mod SVGColors.Mod SVGMatrix.Mod SVG.Mod SVGGradients.Mod SVGFilters.Mod SVGRenderer.Mod 
SVGLoader.Mod SVGDecoder.Mod WebBrowserComponents.Mod XMLTransformer.Mod HTMLTransformer.Mod 
WebBrowserPanel.Mod WebBrowser.Mod MailStorage.Mod BimboMail.Mod DebugLog.Mod WMJoysticks.Mod 
WMTetris.Mod VNCTetrisServer.Mod Bimso.Mod WMScribble.Mod SortDemo.Mod FractalDemo.Mod WMBunny.Mod 
TuringCoatWnd.Mod W3dVectors.Mod W3dMatrix.Mod W3dGeometry.Mod W3dAbstractWorld.Mod 
W3dObjectGenerator.Mod W3dRasterizer.Mod W3dWorld.Mod W3dExplorer.Mod W3dMenu.Mod CATServer.Mod 
W3dClusterWatch.Mod WMSlideshow.Mod Snow.Mod MenuEdit.Mod PresentViewer.Mod TestSuite.Mod PCTest.Mod 
Versioning.Mod FoxTest.Mod TestFiles.Mod BenchTCP.Mod TestDates.Mod TestStrings.Mod BenchXML.Mod 
BenchSyntaxHighlighter.Mod CryptoTestBigNumbers.Mod CryptoTestCiphers.Mod CryptoTestDH.Mod CryptoTestDSA.Mod 
CryptoTestHMAC.Mod CryptoTestHashes.Mod CryptoTestRSA.Mod BeepTest.Mod JoysticksTest.Mod TestMenu.Mod 
PieTest.Mod TestTrees.Mod TestComponentDragDrop.Mod ComponentInfo.Mod TestComponents.Mod 
TestXMLPlugins.Mod HelloWorld.Mod HelloWorld1.Mod HelloWorld2.Mod HelloWorld3.Mod Example1.Mod 
Example2.Mod Example3.Mod Example4.Mod Example5.Mod Example6.Mod Example7.Mod Example8.Mod 
ExampleTextWriter.Mod JavaLocks.Mod WebAccounts.Mod WebForum.Mod ExerciseGroups.Mod IsoImages.Mod 
ReleaseThreadPool.Mod Release.Mod PETReleaseTree.Mod Linker0.Mod Linker1.Mod Linker.Mod 
Unix.BootLinkerHeaps.Mod Unix.BootLinkerModules.Mod Unix.BootLinkerLoader.Mod Unix.BootLinker.Mod 
BootManager.Mod EFI.Mod I386.EFIMachine.Mod EFIBlockIO.Mod EFIDiskIO.Mod EFIFileProtocol.Mod 
EFISimpleFS.Mod EFILoadedImage.Mod EFIGraphicsOutput.Mod EFITrace.Mod EFILib.Mod EFITest.Mod 
EFIGraphicalConsole.Mod EFIA2Loader.Mod Sage.UDPChatBase.Mod Sage.UDPChatServer.Mod Sage.UDPChatClient.Mod 
CyrillicUtilities.Mod YMF754Util.Mod SambaClient.Mod SambaServer.Mod srBase.Mod srRayEngine.Mod srMath.Mod 
I386.srE.Mod srGL.Mod srHex.Mod srImage.Mod srVoxel.Mod srVoxel2.Mod srVoxel3.Mod srVolShader.Mod 
srVoxel4.Mod srVoxel5.Mod srM2Space.Mod srM3Space.Mod srM5Space.Mod srM6Space.Mod 
srRastermovie.Mod srTexVox.Mod srThermoCell.Mod srTree.Mod sr3DTexture.Mod srLifeVox.Mod srRotaVox.Mod 
srvoxels.Mod srRender.Mod MenuPages.Mod WMOverlay.Mod PrettyPrint.Mod NbrInt8.Mod NbrInt16.Mod 
NbrInt32.Mod I386.NbrInt64.Mod NbrInt.Mod NbrRat.Mod I386.NbrRe32.Mod I386.NbrRe64.Mod NbrRe.Mod 
NbrCplx.Mod NbrStrings.Mod WPM.Mod AlmSmtpReceiver.Mod WMFontCCGConverter.Mod WebCGI.Mod 
RegisterRFW.Mod WebBimbodot.Mod TFWebForum.Mod PDF.Mod AFM.Mod PDFExample.Mod Visualizer.Mod 
ReleaseVisualizerScanner.Mod ReleaseVisualizer.Mod OdUtil.Mod OdXml.Mod OdCond.Mod OdAuthBase.Mod OdAuth.Mod 
OdClient.Mod OdVCSBase.Mod SVNArgument.Mod SVNOutput.Mod SVNUtil.Mod Oberon.Kernel.Mod 
Oberon.Modules.Mod Oberon.FileDir.Mod Oberon.Files.Mod Oberon.Disks.Mod Oberon.Objects.Mod 
OberonInput.Mod OberonDisplay.Mod Oberon.Display.Mod Oberon.Input.Mod Oberon.Viewers.Mod 
Oberon.Fonts.Mod Oberon.Mod Oberon.Texts.Mod Oberon.Oberon.Mod Oberon.MenuViewers.Mod 
Oberon.TextFrames.Mod Oberon.System.Mod Oberon.In.Mod Oberon.Out.Mod Oberon.Dates.Mod Oberon.Strings.Mod 
I386.Oberon.Bitmaps.Mod Oberon.Pictures.Mod Oberon.RandomNumbers.Mod Oberon.V24.Mod Unix.Oberon.Printer.Mod 
Oberon.OPM.Mod Oberon.OPS.Mod Oberon.OPT.Mod Oberon.OPB.Mod Oberon.OPA.Mod Oberon.OPP.Mod 
Oberon.OPO.Mod Oberon.OPL.Mod Oberon.OPC.Mod Oberon.OPV.Mod Oberon.Compiler.Mod Oberon.OPAData.Mod 
Oberon.Edit.Mod Oberon.Styles.Mod Oberon.ScriptFrames.Mod Oberon.Script.Mod Oberon.Partitions.Mod 
Oberon.Browser.Mod Oberon.FATFiles.Mod Oberon.DOS.Mod Oberon.Hello.Mod Oberon.PSPrinter.Mod 
Oberon.HPLaserPrinter.Mod Oberon.HPPCL.Mod Unix.Oberon.UnixPrinter.Mod Unix.Oberon.NetSystem.Mod 
Oberon.HelloServer.Mod Oberon.Terminals.Mod Oberon.TerminalFrames.Mod Oberon.Telnet.Mod 
Oberon.TextMail.Mod Oberon.FTP.Mod Oberon.XYplane.Mod Oberon.IFS.Mod Oberon.ET.Mod Oberon.Menu.Mod 
Oberon.Decoder.Mod Oberon.V24Log.Mod Oberon.SysLog.Mod Oberon.ZlibWriters.Mod Oberon.ZlibReaders.Mod 
Oberon.Zip.Mod Oberon.ZipTool.Mod Oberon.GZWriters.Mod Oberon.GZReaders.Mod Oberon.GZip.Mod 
Oberon.TGZ.Mod Oberon.PCARMDecoder.Mod Oberon.Aos.Mod Oberon.OFSTools.Mod Oberon.CleanupFiles.Mod 
Oberon.FATTools.Mod Oberon.Colors.Mod Oberon.Display3.Mod Oberon.Effects.Mod Oberon.Printer3.Mod 
Oberon.Attributes.Mod Oberon.Links.Mod Oberon.Gadgets.Mod Oberon.BasicGadgets.Mod Oberon.TextFields.Mod 
Oberon.ListRiders.Mod Oberon.ListModels.Mod Oberon.ListDags.Mod Oberon.ListGadgets.Mod Oberon.Lists.Mod 
Oberon.Panels.Mod Unix.Oberon.TextGadgets0.Mod Unix.Oberon.TextGadgets.Mod Oberon.BasicFigures.Mod 
Unix.Oberon.Scrollbars.Mod Unix.Oberon.TextSBControl.Mod Oberon.Directories.Mod Oberon.Clocks.Mod 
Oberon.Organizers.Mod Oberon.Complex.Mod Oberon.SetGadgets.Mod Oberon.TimeStamps.Mod Oberon.Gages.Mod 
Oberon.AudioGadgets.Mod Oberon.ProgressMeters.Mod Oberon.Sisiphus.Mod Oberon.Documents.Mod Oberon.Views.Mod 
Oberon.Desktops.Mod Unix.Oberon.TextDocs.Mod Oberon.PanelDocs.Mod Oberon.Icons.Mod 
Oberon.ColorTools.Mod Oberon.NamePlates.Mod Oberon.Navigators.Mod Oberon.NoteBooks.Mod Oberon.Finder.Mod 
Oberon.GadgetsIn.Mod Oberon.GadgetsOut.Mod Oberon.ScrollViews.Mod Oberon.RefGadgets.Mod 
Oberon.Columbus.Mod Oberon.ObjExplorer.Mod Oberon.Compress.Mod Oberon.CompressCrypt.Mod 
Oberon.AsciiCoder.Mod Oberon.Base64.Mod Oberon.UUDecoder.Mod Oberon.BinHex.Mod Oberon.Rot13.Mod 
Oberon.Tar.Mod Oberon.QuotedPrintable.Mod Oberon.Builder.Mod Oberon.Watson0.Mod Oberon.Watson.Mod 
Oberon.EditTools.Mod Oberon.Outlines.Mod Oberon.OFormatterIO.Mod Oberon.OFormatter.Mod 
Oberon.StyleGadgets.Mod Oberon.ScriptGadgets.Mod Oberon.Rembrandt0.Mod Oberon.Rembrandt.Mod 
Oberon.RembrandtDocs.Mod Oberon.RembrandtTools.Mod Oberon.ErrorGadgets.Mod Oberon.PC.Mod 
Unix.Oberon.Clipboard.Mod Oberon.JPEG.Mod Oberon.GIF.Mod Oberon.XBM.Mod Oberon.BMP.Mod Oberon.ICO.Mod 
Oberon.PCX.Mod Oberon.TGA.Mod Oberon.IFF.Mod Oberon.ColorModels.Mod Oberon.XPM.Mod Oberon.PPM.Mod 
Oberon.PSD.Mod Oberon.Images.Mod Oberon.ImageGadgets.Mod Oberon.ImageDocs.Mod 
Oberon.PictImages.Mod Oberon.BMPImages.Mod Oberon.JPEGImages.Mod Oberon.GIFImages.Mod 
Oberon.PSDImages.Mod Oberon.ColorGadgets.Mod Oberon.PCXImages.Mod Oberon.ColorWells.Mod 
Oberon.Streams.Mod Oberon.TextStreams.Mod Oberon.BTrees.Mod Oberon.MIME.Mod Oberon.HyperDocs.Mod 
Oberon.NetTools.Mod Oberon.PasswordFields.Mod Oberon.HyperDocTools.Mod Oberon.Mail.Mod 
Oberon.FTPDocs.Mod Oberon.Finger.Mod Oberon.News.Mod Oberon.Gopher.Mod Oberon.TerminalGadgets.Mod 
Oberon.TelnetGadgets.Mod Oberon.HTTPDocs0.Mod Oberon.HTMLDocs.Mod Oberon.HTTPDocs.Mod Oberon.HTMLForms.Mod 
Oberon.HTMLImages.Mod Oberon.HTMLTables.Mod Oberon.ZipDocs.Mod Oberon.Packages.Mod Oberon.PlugIns.Mod 
Oberon.HTMLPlugIns.Mod Oberon.Copyright.Mod Oberon.FileDisks.Mod Oberon.OTInt.Mod Oberon.OTScan.Mod 
Oberon.OType.Mod Oberon.OTFonts.Mod Oberon.GfxMatrix.Mod Oberon.GfxImages.Mod Oberon.GfxPaths.Mod 
Oberon.GfxRegions.Mod Oberon.GfxFonts0.Mod Oberon.GfxFonts.Mod Oberon.Gfx.Mod Oberon.GfxRaster.Mod 
Oberon.GfxPrinter.Mod Oberon.GfxBuffer.Mod Oberon.GfxDisplay.Mod Oberon.GfxPS.Mod Oberon.GfxOType.Mod 
Oberon.GfxPKFonts.Mod Oberon.GfxTest.Mod Oberon.GfxDemo.Mod Oberon.Leonardo.Mod Oberon.LeoFrames.Mod 
Oberon.LeoTools.Mod Oberon.LeoDocs.Mod Oberon.LeoPanels.Mod Oberon.LeoLists.Mod Oberon.LeoPens.Mod 
Oberon.LeoOutliners.Mod Oberon.LeoPenEditors.Mod Oberon.LeoPaths.Mod Oberon.LeoPathEditors.Mod 
Oberon.LeoSplines.Mod Oberon.LeoSplineEditors.Mod Oberon.LeoCaptions.Mod Oberon.LeoCaptionEditors.Mod 
Oberon.LeoBasic.Mod Oberon.LeoBasicEditors.Mod Oberon.LeoImages.Mod Oberon.LeoImageEditors.Mod 
Oberon.LeoDraw.Mod Oberon.Scheme.Mod Oberon.SchemeOps.Mod Oberon.Vinci.Mod Oberon.VinciGadgets.Mod 
Oberon.VinciDocs.Mod Oberon.VinciShapes.Mod Oberon.VinciPens.Mod Oberon.VinciEditors.Mod 
Oberon.TextPopups.Mod Oberon.V24Gadgets.Mod Oberon.Hex.Mod Oberon.Conversions.Mod Oberon.HPCalc.Mod 
Oberon.EditKeys.Mod Oberon.Find.Mod Oberon.TeXTools.Mod Oberon.SaveScreen.Mod Oberon.SaveTiles.Mod 
Oberon.SaveParticles.Mod Oberon.SaveDecay.Mod Oberon.SaveSisyphus.Mod Oberon.SaveSwarm.Mod 
Oberon.SavePoints.Mod Oberon.MakePoints.Mod Oberon.SaveLife.Mod Oberon.SaveArt.Mod Oberon.DayTime.Mod 
Oberon.Backdrops.Mod Oberon.LayoutPanels0.Mod Oberon.LayoutPanels.Mod Oberon.Layouts.Mod 
Oberon.LayLaS.Mod Oberon.LayLa.Mod Oberon.LayLa2S.Mod Oberon.LayLa2.Mod Oberon.LayLaDemo.Mod 
Oberon.Books0.Mod Oberon.Books.Mod Oberon.BooksHelp.Mod Oberon.BookDocs.Mod Oberon.BookCompiler.Mod 
Oberon.Sets.Mod Oberon.CRS.Mod Oberon.CRT.Mod Oberon.CRA.Mod Oberon.CRX.Mod Oberon.CRP.Mod 
Oberon.Coco.Mod Oberon.FontEditor.Mod Oberon.ASCIITab.Mod Oberon.Magnifier.Mod Oberon.Cards.Mod 
Oberon.Solitaire.Mod Oberon.Spider.Mod Oberon.Freecell.Mod Oberon.MineSweeper.Mod Oberon.Sokoban.Mod 
Oberon.Scramble.Mod Oberon.Shanghai.Mod Oberon.Tetris.Mod Oberon.Asteroids.Mod Oberon.HTML.Mod 
Oberon.WTS.Mod Oberon.WTSFold.Mod Oberon.WTSPict.Mod Oberon.WTSStamp.Mod Oberon.WTSDraw.Mod 
Oberon.CUSM.Mod Oberon.DiffGadgets.Mod Oberon.Diff.Mod Oberon.Sort.Mod Oberon.RXA.Mod Oberon.RX.Mod 
Oberon.PictConverters.Mod Oberon.PS.Mod Oberon.Histogram.Mod Oberon.MultiMail.Mod Oberon.Calc.Mod 
Oberon.Calculator.Mod Oberon.CalculatorGadgets.Mod Oberon.DBF.Mod Oberon.DBFDump.Mod Oberon.Swarm.Mod 
Oberon.DVIFiles.Mod Oberon.DVIViewers.Mod Oberon.DVIDocs.Mod Oberon.ColorSystem.Mod Oberon.PhonePad.Mod 
Oberon.Plotter.Mod Oberon.Plot.Mod Oberon.Lissajous.Mod Oberon.Graphs.Mod Oberon.Diagrams.Mod 
Oberon.Simulator.Mod Oberon.Popups.Mod Oberon.BartSimpson.Mod Oberon.Cups.Mod Oberon.Examples.Mod 
Oberon.Examples1.Mod Oberon.OpenDemo.Mod Oberon.OpenDemo2.Mod Oberon.ExampleOberon.Mod 
Oberon.Suitcases.Mod Oberon.Skeleton.Mod Oberon.ViewSkeleton.Mod Oberon.ColorDriver.Mod 
Oberon.DocumentSkeleton.Mod Oberon.Portraits.Mod Oberon.Reminders.Mod Oberon.TaskExample.Mod 
Oberon.TCPExample.Mod 
~
SystemTools.Show Time elapsed: ~ SystemTools.Ln ~
SystemTools.Timer elapsed ~ SystemTools.Ln ~
~