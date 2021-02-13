<?xml version="1.0" encoding="UTF-8"?>
<?bluebottle format version="0.1" ?>
<?xml-stylesheet type="text/xsl" href="http://bluebottle.ethz.ch/bluebottle.xsl" ?>
<Text>
<Span style="Comment"><![CDATA[# Linux64
# Saturday, February 13, 2021  16:25:51
# This file has been automatically generated using Release.Mod.
# Red colors indicate that a module imports SYSTEM.
]]></Span><Span style="Bold"><![CDATA[System.DoCommands
]]></Span><Span style="Normal"><![CDATA[System.Timer start ~
Compiler.Compile -p=Unix64 --destPath=NewAos/
]]></Span><Span style="Stupid"><![CDATA[AMD64.Builtins.Mod Trace.Mod Linux.Glue.Mod Linux.Unix.Mod Unix.Machine.Mod Heaps.Mod 
Modules.Mod Unix.Objects.Mod ]]></Span><Span style="Normal"><![CDATA[Unix.Kernel.Mod ]]></Span><Span style="Stupid"><![CDATA[KernelLog.Mod ]]></Span><Span style="Normal"><![CDATA[Plugins.Mod ]]></Span><Span style="Stupid"><![CDATA[RealConversions.Mod 
Streams.Mod ]]></Span><Span style="Normal"><![CDATA[Pipes.Mod Commands.Mod In.Mod Out.Mod ]]></Span><Span style="Stupid"><![CDATA[AMD64.Reals.Mod Reflection.Mod ]]></Span><Span style="Normal"><![CDATA[TrapWriters.Mod ]]></Span><Span style="Stupid"><![CDATA[
CRC.Mod ]]></Span><Span style="Normal"><![CDATA[SystemVersion.Mod ]]></Span><Span style="Stupid"><![CDATA[Unix.StdIO.Mod Unix.Traps.Mod ]]></Span><Span style="Normal"><![CDATA[Locks.Mod Unix.Clock.Mod ]]></Span><Span style="Stupid"><![CDATA[Disks.Mod 
DiskCaches.Mod Files.Mod ]]></Span><Span style="Normal"><![CDATA[Dates.Mod Strings.Mod UTF8Strings.Mod FileTrapWriter.Mod Caches.Mod ]]></Span><Span style="Stupid"><![CDATA[
DiskVolumes.Mod OldDiskVolumes.Mod RAMVolumes.Mod DiskFS.Mod OldDiskFS.Mod OberonFS.Mod 
FATVolumes.Mod FATFiles.Mod ]]></Span><Span style="Normal"><![CDATA[ISO9660Volumes.Mod ]]></Span><Span style="Stupid"><![CDATA[ISO9660Files.Mod Unix.UnixFiles.Mod ]]></Span><Span style="Normal"><![CDATA[
RelativeFileSystem.Mod ]]></Span><Span style="Stupid"><![CDATA[BitSets.Mod ]]></Span><Span style="Normal"><![CDATA[Diagnostics.Mod ]]></Span><Span style="Stupid"><![CDATA[StringPool.Mod ]]></Span><Span style="Normal"><![CDATA[ObjectFile.Mod ]]></Span><Span style="Stupid"><![CDATA[GenericLinker.Mod 
Loader.Mod Unix.BootConsole.Mod ]]></Span><Span style="Normal"><![CDATA[Shell.Mod StdIOShell.Mod ]]></Span><Span style="Stupid"><![CDATA[Displays.Mod ]]></Span><Span style="Normal"><![CDATA[Inputs.Mod Options.Mod 
Events.Mod EventsUtils.Mod EventsKernelLog.Mod EventsFileLog.Mod EventsMemoryLog.Mod ]]></Span><Span style="Stupid"><![CDATA[
DynamicStrings.Mod ]]></Span><Span style="Normal"><![CDATA[XMLObjects.Mod XML.Mod XMLScanner.Mod XMLParser.Mod Configuration.Mod 
FileHandlers.Mod ]]></Span><Span style="Stupid"><![CDATA[Network.Mod ]]></Span><Span style="Normal"><![CDATA[ActiveTimers.Mod ]]></Span><Span style="Stupid"><![CDATA[Unix.IP.Mod Unix.Sockets.Mod ]]></Span><Span style="Normal"><![CDATA[Unix.TCP.Mod Unix.UDP.Mod ]]></Span><Span style="Stupid"><![CDATA[
Unix.DNS.Mod ]]></Span><Span style="Normal"><![CDATA[UnixBinary.Mod Serials.Mod SoundDevices.Mod Joysticks.Mod ]]></Span><Span style="Stupid"><![CDATA[TVDriver.Mod ]]></Span><Span style="Normal"><![CDATA[
GenericCollections.Mod ]]></Span><Span style="Stupid"><![CDATA[VirtualDisks.Mod ]]></Span><Span style="Normal"><![CDATA[DisplayNull.Mod Unix.V24.Mod ]]></Span><Span style="Stupid"><![CDATA[Unix.OpenAL.Mod OpenALSound.Mod 
StringPool.Mod ]]></Span><Span style="Normal"><![CDATA[Diagnostics.Mod ]]></Span><Span style="Stupid"><![CDATA[Debugging.Mod BitSets.Mod ]]></Span><Span style="Normal"><![CDATA[ObjectFile.Mod ]]></Span><Span style="Stupid"><![CDATA[GenericLinker.Mod ]]></Span><Span style="Normal"><![CDATA[Linker.Mod ]]></Span><Span style="Stupid"><![CDATA[
FoxBasic.Mod ]]></Span><Span style="Normal"><![CDATA[FoxProgTools.Mod FoxScanner.Mod FoxCSharpScanner.Mod FoxSyntaxTree.Mod FoxGlobal.Mod ]]></Span><Span style="Stupid"><![CDATA[
FoxActiveCells.Mod ]]></Span><Span style="Normal"><![CDATA[FoxHardware.Mod FoxFormats.Mod ]]></Span><Span style="Stupid"><![CDATA[FoxFingerprinter.Mod FoxPrintout.Mod ]]></Span><Span style="Normal"><![CDATA[FoxParser.Mod 
FoxCSharpParser.Mod ]]></Span><Span style="Stupid"><![CDATA[FoxSemanticChecker.Mod ]]></Span><Span style="Normal"><![CDATA[FoxSections.Mod ]]></Span><Span style="Stupid"><![CDATA[FoxBinaryCode.Mod ]]></Span><Span style="Normal"><![CDATA[FoxBackend.Mod 
FoxFrontend.Mod Compiler.Mod FoxOberonFrontend.Mod FoxCSharpFrontend.Mod FoxInterfaceComparison.Mod 
FoxTextualSymbolFile.Mod FoxIntermediateCode.Mod ]]></Span><Span style="Stupid"><![CDATA[FoxIntermediateBackend.Mod ]]></Span><Span style="Normal"><![CDATA[FoxCodeGenerators.Mod 
FoxGenericObjectFile.Mod FoxAMD64InstructionSet.Mod ]]></Span><Span style="Stupid"><![CDATA[FoxAMD64Assembler.Mod ]]></Span><Span style="Normal"><![CDATA[FoxAMDBackend.Mod ]]></Span><Span style="Stupid"><![CDATA[FoxAssembler.Mod ]]></Span><Span style="Normal"><![CDATA[
FoxIntermediateAssembler.Mod FoxDisassembler.Mod FoxARMInstructionSet.Mod FoxARMAssembler.Mod ]]></Span><Span style="Stupid"><![CDATA[FoxARMBackend.Mod 
FoxMinosObjectFile.Mod ]]></Span><Span style="Normal"><![CDATA[FoxIntermediateParser.Mod FoxIntermediateObjectFile.Mod FoxIntermediateLinker.Mod 
FoxTRMInstructionSet.Mod FoxTRMAssembler.Mod ]]></Span><Span style="Stupid"><![CDATA[FoxTRMBackend.Mod FoxInterpreterBackend.Mod ]]></Span><Span style="Normal"><![CDATA[
FoxTranspilerBackend.Mod FoxDocumentationScanner.Mod FoxDocumentationTree.Mod FoxDocumentationPrinter.Mod ]]></Span><Span style="Stupid"><![CDATA[
FoxDocumentationHtml.Mod ]]></Span><Span style="Normal"><![CDATA[FoxDocumentationParser.Mod FoxDocumentationBackend.Mod FoxTestBackend.Mod ]]></Span><Span style="Stupid"><![CDATA[
FoxProfiler.Mod Math.Mod MathL.Mod ]]></Span><Span style="Normal"><![CDATA[ComplexNumbers.Mod ]]></Span><Span style="Stupid"><![CDATA[FoxArrayBase.Mod 
AMD64.FoxArrayBaseOptimized.Mod ]]></Span><Span style="Normal"><![CDATA[PersistentObjects.Mod ]]></Span><Span style="Stupid"><![CDATA[FoxInterpreterSymbols.Mod FoxInterpreter.Mod ]]></Span><Span style="Normal"><![CDATA[MinosLinker.Mod ]]></Span><Span style="Stupid"><![CDATA[
StreamUtilities.Mod ]]></Span><Span style="Normal"><![CDATA[Errors.Mod Unix.ProcessInfo0.Mod ]]></Span><Span style="Stupid"><![CDATA[ProcessInfo.Mod ]]></Span><Span style="Normal"><![CDATA[System.Mod Reboot.Mod 
Unix.PrecisionTimer.Mod ]]></Span><Span style="Stupid"><![CDATA[Unix.HostLibs.Mod ]]></Span><Span style="Normal"><![CDATA[Stopwatch.Mod ]]></Span><Span style="Stupid"><![CDATA[Math.Mod MathL.Mod Random.Mod ]]></Span><Span style="Normal"><![CDATA[Drand48.Mod ]]></Span><Span style="Stupid"><![CDATA[
AMD64.Shortreal.Mod ]]></Span><Span style="Normal"><![CDATA[SerialsVirtual.Mod Autostart.Mod FSTools.Mod UpTime.Mod CLUTs.Mod ]]></Span><Span style="Stupid"><![CDATA[Raster.Mod ]]></Span><Span style="Normal"><![CDATA[
Localization.Mod Archives.Mod WMRectangles.Mod WMEvents.Mod Repositories.Mod FP1616.Mod Texts.Mod 
UndoManager.Mod ]]></Span><Span style="Stupid"><![CDATA[CRC.Mod Inflate.Mod ]]></Span><Span style="Normal"><![CDATA[Unzip.Mod ZipFS.Mod Codecs.Mod UnicodeProperties.Mod 
ContextualDependency.Mod UnicodeBidirectionality.Mod ]]></Span><Span style="Stupid"><![CDATA[AMD64.WMRasterScale.Mod ]]></Span><Span style="Normal"><![CDATA[WMGraphics.Mod ]]></Span><Span style="Stupid"><![CDATA[
WMGraphicsSmooth.Mod ]]></Span><Span style="Normal"><![CDATA[TextUtilities.Mod Types.Mod Models.Mod WMProperties.Mod ]]></Span><Span style="Stupid"><![CDATA[WMMessages.Mod ]]></Span><Span style="Normal"><![CDATA[
WMWindowManager.Mod WMGraphicUtilities.Mod WMDropTarget.Mod WMComponents.Mod KernelLogger.Mod 
CompilerInterface.Mod TextCompiler.Mod ]]></Span><Span style="Stupid"><![CDATA[PCDebug.Mod PCM.Mod ]]></Span><Span style="Normal"><![CDATA[PCS.Mod ]]></Span><Span style="Stupid"><![CDATA[PCT.Mod PCBT.Mod ]]></Span><Span style="Normal"><![CDATA[PCLIR.Mod ]]></Span><Span style="Stupid"><![CDATA[PCO.Mod 
PCG386.Mod PCC.Mod ]]></Span><Span style="Normal"><![CDATA[PCV.Mod PCArrays.Mod ]]></Span><Span style="Stupid"><![CDATA[PCB.Mod PCP.Mod PCA386.Mod PCOM.Mod PCOF.Mod PCOFPE.Mod ]]></Span><Span style="Normal"><![CDATA[
PC.Mod ]]></Span><Span style="Stupid"><![CDATA[PCOARM.Mod PCARMCP.Mod ]]></Span><Span style="Normal"><![CDATA[PCARMRegisters.Mod ]]></Span><Span style="Stupid"><![CDATA[PCAARM.Mod PCGARM.Mod ]]></Span><Span style="Normal"><![CDATA[ASMAMD64.Mod ]]></Span><Span style="Stupid"><![CDATA[
PCAAMD64.Mod PCGAMD64.Mod ]]></Span><Span style="Normal"><![CDATA[WhitespaceRemover.Mod HostClipboard.Mod Tar.Mod ]]></Span><Span style="Stupid"><![CDATA[Zlib.Mod ZlibBuffers.Mod 
ZlibDeflate.Mod ZlibInflate.Mod ]]></Span><Span style="Normal"><![CDATA[ZlibWriters.Mod ZlibReaders.Mod Zip.Mod ZipTool.Mod ]]></Span><Span style="Stupid"><![CDATA[BIT.Mod 
PNGDecoder.Mod ]]></Span><Span style="Normal"><![CDATA[BMPCodec.Mod GIFCodec.Mod ]]></Span><Span style="Stupid"><![CDATA[JPEGDecoder.Mod ]]></Span><Span style="Normal"><![CDATA[AnimationCodec.Mod PartitionsLib.Mod ]]></Span><Span style="Stupid"><![CDATA[
FATScavenger.Mod ]]></Span><Span style="Normal"><![CDATA[Partitions.Mod DiskTests.Mod DiskBenchmark.Mod PartitionEditorTable.Mod ]]></Span><Span style="Stupid"><![CDATA[
Unix.HierarchicalProfiler0.Mod HierarchicalProfiler.Mod ]]></Span><Span style="Normal"><![CDATA[FTPClient.Mod ]]></Span><Span style="Stupid"><![CDATA[XYModem.Mod ]]></Span><Span style="Normal"><![CDATA[Shell.Mod ShellSerial.Mod 
Installer.Mod CryptoBigNumbers.Mod CryptoBase64.Mod ]]></Span><Span style="Stupid"><![CDATA[CryptoUtils.Mod ]]></Span><Span style="Normal"><![CDATA[CryptoCiphers.Mod 
CryptoARC4.Mod CryptoDES.Mod CryptoDES3.Mod CryptoHashes.Mod CryptoMD5.Mod CryptoSHA1.Mod 
CryptoSHA256.Mod ]]></Span><Span style="Stupid"><![CDATA[CryptoKeccakF1600.Mod ]]></Span><Span style="Normal"><![CDATA[CryptoKeccakSponge.Mod CryptoSHA3.Mod CryptoCSPRNG.Mod 
CryptoPrimes.Mod CryptoDSA.Mod CryptoDiffieHellman.Mod CryptoAES.Mod CryptoBlowfish.Mod 
CryptoTwofish.Mod CryptoCAST.Mod CryptoHMAC.Mod CryptoIDEA.Mod CryptoRSA.Mod CryptoStreams.Mod 
Checksum.Mod Fido.Mod ]]></Span><Span style="Stupid"><![CDATA[CPUID.Mod ]]></Span><Span style="Normal"><![CDATA[A2Sequencers.Mod ]]></Span><Span style="Stupid"><![CDATA[PictImages.Mod ]]></Span><Span style="Normal"><![CDATA[V24Tracer.Mod 
XMLGeneratorSchema.Mod CSS2.Mod CSS2Scanner.Mod CSS2Parser.Mod RAWPrinter.Mod LPR.Mod ASN1.Mod PKCS1.Mod 
X509.Mod TLS.Mod TCPServices.Mod TestServer.Mod TCPTools.Mod IPBandwidth.Mod 
Windows.Performance.Mod Bin2Hex.Mod BinToCode.Mod Base64.Mod ]]></Span><Span style="Stupid"><![CDATA[DisplayGTF.Mod ]]></Span><Span style="Normal"><![CDATA[GZip.Mod ShellCommands.Mod 
Telnet.Mod ]]></Span><Span style="Stupid"><![CDATA[TFClasses.Mod ]]></Span><Span style="Normal"><![CDATA[Mail.Mod SMTPClient.Mod TFLog.Mod WebHTTP.Mod WebHTTPClient.Mod 
WebHTTPTools.Mod WebHTTPServer.Mod WebHTTPServerTools.Mod WebSSMPPlugin.Mod 
WebHTTPServerStatistics.Mod POP3Client.Mod RFC865Client.Mod QuoteServer.Mod ]]></Span><Span style="Stupid"><![CDATA[RfsConnection.Mod RfsClientProxy.Mod 
RfsFS.Mod ]]></Span><Span style="Normal"><![CDATA[TFTP.Mod TFTPServer.Mod ]]></Span><Span style="Stupid"><![CDATA[TFTPFS.Mod FTPFS.Mod ]]></Span><Span style="Normal"><![CDATA[WebFTPServer.Mod ]]></Span><Span style="Stupid"><![CDATA[XModem.Mod ]]></Span><Span style="Normal"><![CDATA[
SearchTools.Mod DiffLib.Mod TextConverter.Mod TaskScheduler.Mod FTP.Mod DES.Mod ]]></Span><Span style="Stupid"><![CDATA[VNCServer.Mod 
WAVCodec.Mod MP3Decoder.Mod IDCT.Mod ]]></Span><Span style="Normal"><![CDATA[MPEGTables.Mod ]]></Span><Span style="Stupid"><![CDATA[MPEGUtilities.Mod MPEGVideoDecoder.Mod AVI.Mod 
DivXTypes.Mod DivXHelper.Mod DivXDecoder.Mod JPEG2000DecoderUtil.Mod JPEG2000DecoderCS.Mod 
JPEG2000Decoder.Mod MD5.Mod ]]></Span><Span style="Normal"><![CDATA[HTTPSupport.Mod HTTPSession.Mod DynamicWebpage.Mod DynamicWebpagePlugin.Mod 
PrevalenceSystem.Mod WMDropTarget.Mod GenericSort.Mod WebStd.Mod WebComplex.Mod WMCharCodes.Mod 
HTMLScanner.Mod HTMLParser.Mod NewHTTPClient.Mod UnihanParser.Mod CSV.Mod ColorModels.Mod 
WMDefaultWindows.Mod WMDefaultFont.Mod WMFontManager.Mod WMOberonFonts.Mod WMCCGFonts.Mod 
WMBitmapFont.Mod OpenTypeInt.Mod OpenTypeScan.Mod OpenType.Mod ]]></Span><Span style="Stupid"><![CDATA[OpenTypeFonts.Mod ]]></Span><Span style="Normal"><![CDATA[WMOTFonts.Mod ]]></Span><Span style="Stupid"><![CDATA[
OberonFonts.Mod ]]></Span><Span style="Normal"><![CDATA[WindowManager.Mod Unix.X11.Mod ]]></Span><Span style="Stupid"><![CDATA[Unix.XDisplay.Mod ]]></Span><Span style="Normal"><![CDATA[Unix.Beep.Mod ]]></Span><Span style="Stupid"><![CDATA[Unix.KbdMouse.Mod 
Unix.Clipboard.Mod ]]></Span><Span style="Normal"><![CDATA[Unix.Display.Mod Attributes.Mod WMStandardComponents.Mod WMProgressComponents.Mod 
WMShapes.Mod WMFigures.Mod WMScrollableComponents.Mod WMPieMenu.Mod WMPopups.Mod 
PositionDebugging.Mod SyntaxHighlighter.Mod WMTextView.Mod WMInputMethods.Mod WMEditors.Mod 
WMSearchComponents.Mod WMMacros.Mod WMGrids.Mod WMStringGrids.Mod WMTrees.Mod WMMixer.Mod 
WMTabComponents.Mod WMColorComponents.Mod WMAnimations.Mod WMDropDownLists.Mod WMRestorable.Mod 
WMApplications.Mod WMDialogs.Mod WMTerminator.Mod WMDocumentEditor.Mod WMErrors.Mod WMOSD.Mod 
WMArchives.Mod WMCharMap.Mod WMUnicodeMarkerTool.Mod Unix.DisplayRefresher.Mod ModuleParser.Mod 
ModuleTrees.Mod WMXMLTree.Mod WMDiagnostics.Mod PETTrees.Mod PETModuleTree.Mod PETXMLTree.Mod PET.Mod 
WMArabicIME.Mod WMArmenianIME.Mod WMHebrewIME.Mod WMPinyinIME.Mod WMRussianIME.Mod 
WMUkrainianIME.Mod WMEthiopicIME.Mod WMUnicodeIME.Mod WMInputMethodTool.Mod WMUtilities.Mod 
WMTrapWriter.Mod FoxA2Interface.Mod WMMenus.Mod WMDiagramComponents.Mod MainMenu.Mod StartMenu.Mod 
MenuPages.Mod HotKeys.Mod WMNavigate.Mod WMNavigator.Mod WMDesktops.Mod Notepad.Mod 
WMSystemComponents.Mod WMFileManager.Mod WMSearchTool.Mod WMFTPClient.Mod SkinLanguage.Mod FNHistories.Mod 
SkinEngine.Mod ]]></Span><Span style="Stupid"><![CDATA[WMProcessInfo.Mod ]]></Span><Span style="Normal"><![CDATA[WMObjectTracker.Mod WMKernelLog.Mod WMEventLog.Mod 
WMPartitionsComponents.Mod WMPartitions.Mod PartitionEditorComponents.Mod PartitionEditor.Mod MultiLogger.Mod ]]></Span><Span style="Stupid"><![CDATA[
MemoryReader.Mod Decoder.Mod ]]></Span><Span style="Normal"><![CDATA[I386Decoder.Mod ]]></Span><Span style="Stupid"><![CDATA[ARMDecoder.Mod AMD64Decoder.Mod ]]></Span><Span style="Normal"><![CDATA[WMTextTool.Mod 
WMPerfMonPlugins.Mod WMPerfMonAlerts.Mod WMPerfMonAlertsUtils.Mod Unix.WMPerfMonPluginCpu.Mod 
Unix.WMPerfMonPluginMemory.Mod WMPerfMonPluginProcesses.Mod WMPerfMonPluginSerials.Mod WMPerfMonPluginNetwork.Mod 
WMPerfMonPluginDisks.Mod WMPerfMonPluginPerfMon.Mod WMPerfMonPluginEvents.Mod WMPerfMonPluginMessages.Mod 
WMPerfMonComponents.Mod WMPerfMonTabSystem.Mod WMPerfMonTabAlerts.Mod WMPerfMon.Mod WMClock.Mod 
WMCalendar.Mod WMV24Component.Mod WMShell.Mod WMProfiler.Mod SSHGlobals.Mod SSHPackets.Mod 
SSHKeys.Mod SSHTransport.Mod SSHAuthorize.Mod SSHChannels.Mod SSHTerminal.Mod SSH.Mod 
TFStringPool.Mod BimboScanner.Mod TFTypeSys.Mod TFDumpTS.Mod TFScopeTools.Mod TFCheck.Mod 
TFAOParser.Mod TFModuleTrees.Mod TFPET.Mod ]]></Span><Span style="Stupid"><![CDATA[TFClasses.Mod ]]></Span><Span style="Normal"><![CDATA[TFDocGenerator.Mod TFXRef.Mod 
CharacterLineup.Mod WMDesktopIcons.Mod WMTextStyleTool.Mod WMVNCView.Mod ]]></Span><Span style="Stupid"><![CDATA[VNC.Mod ]]></Span><Span style="Normal"><![CDATA[WMVT100.Mod 
SkinEditor.Mod Looks.Mod WMSkinLoader.Mod WMBackdropLoader.Mod ]]></Span><Span style="Stupid"><![CDATA[WMInspectionComponents.Mod ]]></Span><Span style="Normal"><![CDATA[
WMInspector.Mod WMRepositories.Mod WMBuilder.Mod WMBuilderTransformer.Mod CyberbitNetInstall.Mod 
WMDiff.Mod WMTaskScheduler.Mod IMAPUtilities.Mod IMAP.Mod IMAPClient.Mod RMSMTP.Mod IMAPGUI.Mod 
WMPerfMonPluginHTTPServer.Mod WMPerfMonPluginQuoteServer.Mod WMPerfMonPluginVNCServer.Mod 
WMPerfMonPluginExample.Mod ]]></Span><Span style="Stupid"><![CDATA[WMModuleState.Mod ]]></Span><Span style="Normal"><![CDATA[WMKeyCode.Mod WMPicView.Mod ComponentViewer.Mod WMScreenShot.Mod 
WMBackdrop.Mod WMLanguageSwitcher.Mod WMInstaller.Mod ]]></Span><Span style="Stupid"><![CDATA[HotKeysCommands.Mod ]]></Span><Span style="Normal"><![CDATA[SynergyClient.Mod ]]></Span><Span style="Stupid"><![CDATA[
WMTransitions.Mod ]]></Span><Span style="Normal"><![CDATA[MediaPlayer.Mod Presentation.Mod MP3Player.Mod WMPlayer.Mod WAVRecorder.Mod ]]></Span><Span style="Stupid"><![CDATA[
OGGUtilities.Mod OGGVorbisPlayer.Mod ]]></Span><Span style="Normal"><![CDATA[WMOGGPlayer.Mod DTPData.Mod DTPUtilities.Mod DTPView.Mod 
DTPEditor.Mod DTPText.Mod DTPRect.Mod DTPImage.Mod GfxMatrix.Mod ]]></Span><Span style="Stupid"><![CDATA[GfxImages.Mod ]]></Span><Span style="Normal"><![CDATA[GfxPaths.Mod 
GfxRegions.Mod ]]></Span><Span style="Stupid"><![CDATA[GfxFonts.Mod ]]></Span><Span style="Normal"><![CDATA[Gfx.Mod GfxRaster.Mod GfxBuffer.Mod WMGraphicsGfx.Mod CSS2Properties.Mod 
XMLComponents.Mod XMLStyle.Mod XMLLoader.Mod SVGUtilities.Mod SVGColors.Mod SVGMatrix.Mod SVG.Mod 
SVGGradients.Mod SVGFilters.Mod SVGRenderer.Mod SVGLoader.Mod SVGDecoder.Mod WebBrowserComponents.Mod 
XMLTransformer.Mod HTMLTransformer.Mod WebBrowserPanel.Mod WebBrowser.Mod MailStorage.Mod BimboMail.Mod ]]></Span><Span style="Stupid"><![CDATA[
DebugLog.Mod ]]></Span><Span style="Normal"><![CDATA[WMJoysticks.Mod WMImageGrid.Mod WMSimpleGraphs.Mod WMTetris.Mod VNCTetrisServer.Mod 
Bimso.Mod WMScribble.Mod WMGraphicsDemo.Mod SortDemo.Mod FractalDemo.Mod WMBunny.Mod 
TuringCoatWnd.Mod W3dVectors.Mod W3dMatrix.Mod W3dGeometry.Mod W3dAbstractWorld.Mod 
W3dObjectGenerator.Mod ]]></Span><Span style="Stupid"><![CDATA[W3dRasterizer.Mod ]]></Span><Span style="Normal"><![CDATA[W3dWorld.Mod W3dExplorer.Mod W3dMenu.Mod CATServer.Mod 
W3dClusterWatch.Mod WMSlideshow.Mod Snow.Mod MenuEdit.Mod PresentViewer.Mod TestSuite.Mod PCTest.Mod 
Versioning.Mod FoxTest.Mod TestFiles.Mod BenchTCP.Mod TestDates.Mod ]]></Span><Span style="Stupid"><![CDATA[TestStrings.Mod ]]></Span><Span style="Normal"><![CDATA[BenchXML.Mod 
BenchSyntaxHighlighter.Mod CryptoTestBigNumbers.Mod CryptoTestCiphers.Mod CryptoTestDH.Mod CryptoTestDSA.Mod 
CryptoTestHMAC.Mod CryptoTestHashes.Mod CryptoTestRSA.Mod BeepTest.Mod JoysticksTest.Mod TestMenu.Mod 
PieTest.Mod TestTrees.Mod TestComponentDragDrop.Mod ComponentInfo.Mod TestComponents.Mod 
TestXMLPlugins.Mod HelloWorld.Mod HelloWorld1.Mod HelloWorld2.Mod HelloWorld3.Mod Example1.Mod 
Example2.Mod Example3.Mod Example4.Mod Example5.Mod Example6.Mod Example7.Mod Example8.Mod 
ExampleTextWriter.Mod JavaLocks.Mod WebAccounts.Mod WebForum.Mod ExerciseGroups.Mod ]]></Span><Span style="Stupid"><![CDATA[IsoImages.Mod ]]></Span><Span style="Normal"><![CDATA[
ReleaseThreadPool.Mod Release.Mod PETReleaseTree.Mod BootManager.Mod ]]></Span><Span style="Stupid"><![CDATA[EFI.Mod AMD64.EFIMachine.Mod 
EFIBlockIO.Mod EFIDiskIO.Mod EFIFileProtocol.Mod EFISimpleFS.Mod EFILoadedImage.Mod 
EFIGraphicsOutput.Mod ]]></Span><Span style="Normal"><![CDATA[EFITrace.Mod ]]></Span><Span style="Stupid"><![CDATA[EFILib.Mod EFITest.Mod EFIGraphicalConsole.Mod EFIA2Loader.Mod ]]></Span><Span style="Normal"><![CDATA[
Sage.UDPChatBase.Mod Sage.UDPChatServer.Mod Sage.UDPChatClient.Mod CyrillicUtilities.Mod YMF754Util.Mod ]]></Span><Span style="Stupid"><![CDATA[
SambaClient.Mod SambaServer.Mod ]]></Span><Span style="Normal"><![CDATA[srBase.Mod srRayEngine.Mod srMath.Mod ]]></Span><Span style="Stupid"><![CDATA[srE.Mod ]]></Span><Span style="Normal"><![CDATA[srGL.Mod srHex.Mod 
srImage.Mod srVoxel.Mod srVoxel2.Mod srVoxel3.Mod srVolShader.Mod srVoxel4.Mod srVoxel5.Mod 
srM2Space.Mod srM3Space.Mod srM5Space.Mod srM6Space.Mod srRastermovie.Mod srTexVox.Mod 
srThermoCell.Mod srTree.Mod sr3DTexture.Mod srLifeVox.Mod srRotaVox.Mod srvoxels.Mod srRender.Mod 
MenuPages.Mod ]]></Span><Span style="Stupid"><![CDATA[RasterPixelFormats.Mod ]]></Span><Span style="Normal"><![CDATA[WMOverlay.Mod PrettyPrint.Mod BitStreams.Mod NextPrime.Mod 
MoveToFront.Mod BWHCompressor.Mod OZip3.Mod NbrInt8.Mod NbrInt16.Mod NbrInt32.Mod NbrInt64.Mod 
NbrInt.Mod NbrRat.Mod NbrRe32.Mod NbrRe64.Mod NbrRe.Mod NbrCplx.Mod NbrStrings.Mod ]]></Span><Span style="Stupid"><![CDATA[DataErrors.Mod ]]></Span><Span style="Normal"><![CDATA[
DataIO.Mod Data.Mod DataStacks.Mod DataQueues.Mod DataLists.Mod DataTrees.Mod MathInt.Mod 
MathRat.Mod MathReSeries.Mod MathRe.Mod MathCplxSeries.Mod MathCplx.Mod MathCbrt.Mod MathErf.Mod 
MathGamma.Mod CalcFn.Mod CalcD1.Mod CalcD2.Mod CalcD3.Mod CalcD4.Mod CalcGauss.Mod MathMitLef.Mod 
CalcConvolution.Mod CalcGrunwald.Mod CalcDiethelm.Mod WPM.Mod AlmSmtpReceiver.Mod WMFontCCGConverter.Mod 
WebCGI.Mod RegisterRFW.Mod WebBimbodot.Mod TFWebForum.Mod PDF.Mod AFM.Mod PDFExample.Mod 
Visualizer.Mod ReleaseVisualizerScanner.Mod ReleaseVisualizer.Mod OdUtil.Mod OdXml.Mod OdCond.Mod 
OdAuthBase.Mod OdAuth.Mod OdClient.Mod ]]></Span><Span style="Stupid"><![CDATA[OdVCSBase.Mod ]]></Span><Span style="Normal"><![CDATA[SVNArgument.Mod SVNOutput.Mod SVNUtil.Mod 
SVNAdmin.Mod OdSvn.Mod SVNWebDAV.Mod SVN.Mod Oberon.Kernel.Mod Oberon.Modules.Mod 
Oberon.FileDir.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.Files.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.Disks.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.Objects.Mod ]]></Span><Span style="Normal"><![CDATA[OberonInput.Mod ]]></Span><Span style="Stupid"><![CDATA[
OberonDisplay.Mod Oberon.Display.Mod Oberon.Input.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.Viewers.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.Fonts.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.Mod 
Oberon.Texts.Mod Oberon.Oberon.Mod Oberon.MenuViewers.Mod Oberon.TextFrames.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.System.Mod ]]></Span><Span style="Normal"><![CDATA[
Oberon.In.Mod Oberon.Out.Mod Oberon.Dates.Mod Oberon.Strings.Mod ]]></Span><Span style="Stupid"><![CDATA[AMD64.Oberon.Bitmaps.Mod 
Oberon.Pictures.Mod Oberon.RandomNumbers.Mod Oberon.V24.Mod ]]></Span><Span style="Normal"><![CDATA[Unix.Oberon.Printer.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.OPM.Mod ]]></Span><Span style="Normal"><![CDATA[
Oberon.OPS.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.OPT.Mod Oberon.OPB.Mod Oberon.OPA.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.OPP.Mod Oberon.OPO.Mod ]]></Span><Span style="Stupid"><![CDATA[
Oberon.OPL.Mod Oberon.OPC.Mod Oberon.OPV.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.Compiler.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.OPAData.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.Edit.Mod 
Oberon.Styles.Mod Oberon.ScriptFrames.Mod Oberon.Script.Mod Oberon.Partitions.Mod Oberon.Browser.Mod ]]></Span><Span style="Stupid"><![CDATA[
Oberon.FATFiles.Mod Oberon.DOS.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.Hello.Mod Oberon.PSPrinter.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.HPLaserPrinter.Mod 
Oberon.HPPCL.Mod Unix.Oberon.UnixPrinter.Mod Unix.Oberon.NetSystem.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.HelloServer.Mod 
Oberon.Terminals.Mod Oberon.TerminalFrames.Mod Oberon.Telnet.Mod Oberon.TextMail.Mod Oberon.FTP.Mod 
Oberon.XYplane.Mod Oberon.IFS.Mod Oberon.ET.Mod Oberon.Menu.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.Decoder.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.V24Log.Mod 
Oberon.SysLog.Mod Oberon.ZlibWriters.Mod Oberon.ZlibReaders.Mod Oberon.Zip.Mod Oberon.ZipTool.Mod 
Oberon.GZWriters.Mod Oberon.GZReaders.Mod Oberon.GZip.Mod Oberon.TGZ.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.PCARMDecoder.Mod ]]></Span><Span style="Normal"><![CDATA[
Oberon.Aos.Mod Oberon.OFSTools.Mod Oberon.CleanupFiles.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.FATTools.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.Colors.Mod 
Oberon.Display3.Mod Oberon.Effects.Mod Oberon.Printer3.Mod Oberon.Attributes.Mod Oberon.Links.Mod 
Oberon.Gadgets.Mod Oberon.BasicGadgets.Mod Oberon.TextFields.Mod Oberon.ListRiders.Mod 
Oberon.ListModels.Mod Oberon.ListDags.Mod Oberon.ListGadgets.Mod Oberon.Lists.Mod Oberon.Panels.Mod 
Oberon.TextGadgets0.Mod Oberon.TextGadgets.Mod Oberon.BasicFigures.Mod Oberon.Scrollbars.Mod 
Oberon.Directories.Mod Oberon.Clocks.Mod Oberon.Organizers.Mod Oberon.Complex.Mod Oberon.SetGadgets.Mod 
Oberon.TimeStamps.Mod Oberon.Gages.Mod Oberon.AudioGadgets.Mod Oberon.ProgressMeters.Mod ]]></Span><Span style="Stupid"><![CDATA[
Oberon.Sisiphus.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.Documents.Mod Oberon.Views.Mod Oberon.Desktops.Mod Oberon.TextDocs.Mod 
Oberon.PanelDocs.Mod Oberon.Icons.Mod Oberon.ColorTools.Mod Oberon.NamePlates.Mod Oberon.Navigators.Mod 
Oberon.NoteBooks.Mod Oberon.Finder.Mod Oberon.GadgetsIn.Mod Oberon.GadgetsOut.Mod Oberon.ScrollViews.Mod 
Oberon.RefGadgets.Mod Oberon.Columbus.Mod Oberon.ObjExplorer.Mod Oberon.Compress.Mod 
Oberon.CompressCrypt.Mod Oberon.AsciiCoder.Mod Oberon.Base64.Mod Oberon.UUDecoder.Mod Oberon.BinHex.Mod 
Oberon.Rot13.Mod Oberon.Tar.Mod Oberon.QuotedPrintable.Mod Oberon.Builder.Mod Oberon.Watson0.Mod 
Oberon.Watson.Mod Oberon.EditTools.Mod Oberon.Outlines.Mod Oberon.OFormatterIO.Mod 
Oberon.OFormatter.Mod Oberon.StyleGadgets.Mod Oberon.ScriptGadgets.Mod Oberon.Rembrandt0.Mod 
Oberon.Rembrandt.Mod Oberon.RembrandtDocs.Mod Oberon.RembrandtTools.Mod Oberon.ErrorGadgets.Mod 
Oberon.PC.Mod ]]></Span><Span style="Stupid"><![CDATA[Unix.Oberon.Clipboard.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.JPEG.Mod Oberon.GIF.Mod Oberon.XBM.Mod 
Oberon.BMP.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.ICO.Mod Oberon.PCX.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.TGA.Mod Oberon.IFF.Mod Oberon.ColorModels.Mod 
Oberon.XPM.Mod Oberon.PPM.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.PSD.Mod Oberon.Images.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.ImageGadgets.Mod 
Oberon.ImageDocs.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.PictImages.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.BMPImages.Mod Oberon.JPEGImages.Mod ]]></Span><Span style="Stupid"><![CDATA[
Oberon.GIFImages.Mod Oberon.PSDImages.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.ColorGadgets.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.PCXImages.Mod ]]></Span><Span style="Normal"><![CDATA[
Oberon.ColorWells.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.Streams.Mod Oberon.TextStreams.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.BTrees.Mod Oberon.MIME.Mod 
Oberon.HyperDocs.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.NetTools.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.PasswordFields.Mod Oberon.HyperDocTools.Mod 
Oberon.OutStub.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.Mail.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.FTPDocs.Mod Oberon.Finger.Mod Oberon.News.Mod 
Oberon.Gopher.Mod Oberon.TerminalGadgets.Mod Oberon.TelnetGadgets.Mod Oberon.HTTPDocs0.Mod 
Oberon.HTMLDocs.Mod Oberon.HTTPDocs.Mod Oberon.HTMLForms.Mod Oberon.HTMLImages.Mod 
Oberon.HTMLTables.Mod Oberon.ZipDocs.Mod Oberon.Packages.Mod Oberon.PlugIns.Mod Oberon.HTMLPlugIns.Mod 
Oberon.Copyright.Mod Oberon.FileDisks.Mod Oberon.OTInt.Mod Oberon.OTScan.Mod Oberon.OType.Mod ]]></Span><Span style="Stupid"><![CDATA[
Oberon.OTFonts.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.GfxMatrix.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.GfxImages.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.GfxPaths.Mod Oberon.GfxRegions.Mod 
Oberon.GfxFonts0.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.GfxFonts.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.Gfx.Mod Oberon.GfxRaster.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.GfxPrinter.Mod ]]></Span><Span style="Normal"><![CDATA[
Oberon.GfxBuffer.Mod Oberon.GfxDisplay.Mod Oberon.GfxPS.Mod Oberon.GfxOType.Mod Oberon.GfxPKFonts.Mod 
Oberon.GfxTest.Mod Oberon.GfxDemo.Mod Oberon.Leonardo.Mod Oberon.LeoFrames.Mod Oberon.LeoTools.Mod 
Oberon.LeoDocs.Mod Oberon.LeoPanels.Mod Oberon.LeoLists.Mod Oberon.LeoPens.Mod Oberon.LeoOutliners.Mod 
Oberon.LeoPenEditors.Mod Oberon.LeoPaths.Mod Oberon.LeoPathEditors.Mod Oberon.LeoSplines.Mod 
Oberon.LeoSplineEditors.Mod Oberon.LeoCaptions.Mod Oberon.LeoCaptionEditors.Mod Oberon.LeoBasic.Mod 
Oberon.LeoBasicEditors.Mod Oberon.LeoImages.Mod Oberon.LeoImageEditors.Mod Oberon.LeoDraw.Mod 
Oberon.Scheme.Mod Oberon.SchemeOps.Mod Oberon.Vinci.Mod Oberon.VinciGadgets.Mod Oberon.VinciDocs.Mod 
Oberon.VinciShapes.Mod Oberon.VinciPens.Mod Oberon.VinciEditors.Mod Oberon.TextPopups.Mod 
Oberon.V24Gadgets.Mod Oberon.Hex.Mod Oberon.Conversions.Mod Oberon.HPCalc.Mod Oberon.EditKeys.Mod 
Oberon.Find.Mod Oberon.TeXTools.Mod Oberon.SaveScreen.Mod Oberon.SaveTiles.Mod 
Oberon.SaveParticles.Mod Oberon.SaveDecay.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.SaveSisyphus.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.SaveSwarm.Mod 
Oberon.SavePoints.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.MakePoints.Mod Oberon.SaveLife.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.SaveArt.Mod Oberon.DayTime.Mod 
Oberon.Backdrops.Mod Oberon.LayoutPanels0.Mod Oberon.LayoutPanels.Mod Oberon.Layouts.Mod 
Oberon.LayLaS.Mod Oberon.LayLa.Mod Oberon.LayLa2S.Mod Oberon.LayLa2.Mod Oberon.LayLaDemo.Mod 
Oberon.Books0.Mod Oberon.Books.Mod Oberon.BooksHelp.Mod Oberon.BookDocs.Mod Oberon.BookCompiler.Mod 
Oberon.Sets.Mod Oberon.CRS.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.CRT.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.CRA.Mod Oberon.CRX.Mod Oberon.CRP.Mod 
Oberon.Coco.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.FontEditor.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.ASCIITab.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.Magnifier.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.Cards.Mod 
Oberon.Solitaire.Mod Oberon.Spider.Mod Oberon.Freecell.Mod Oberon.MineSweeper.Mod Oberon.Sokoban.Mod 
Oberon.Scramble.Mod Oberon.Shanghai.Mod Oberon.Tetris.Mod Oberon.Asteroids.Mod Oberon.HTML.Mod 
Oberon.WTS.Mod Oberon.WTSFold.Mod Oberon.WTSPict.Mod Oberon.WTSStamp.Mod Oberon.WTSDraw.Mod ]]></Span><Span style="Stupid"><![CDATA[
Oberon.CUSM.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.DiffGadgets.Mod Oberon.Diff.Mod Oberon.Sort.Mod Oberon.RXA.Mod Oberon.RX.Mod 
Oberon.PictConverters.Mod Oberon.PS.Mod Oberon.Histogram.Mod Oberon.MultiMail.Mod Oberon.Calc.Mod 
Oberon.Calculator.Mod ]]></Span><Span style="Stupid"><![CDATA[Oberon.CalculatorGadgets.Mod ]]></Span><Span style="Normal"><![CDATA[Oberon.DBF.Mod Oberon.DBFDump.Mod Oberon.Swarm.Mod 
Oberon.DVIFiles.Mod Oberon.DVIViewers.Mod Oberon.DVIDocs.Mod Oberon.ColorSystem.Mod Oberon.PhonePad.Mod 
Oberon.Plotter.Mod Oberon.Plot.Mod Oberon.Lissajous.Mod Oberon.Graphs.Mod Oberon.Diagrams.Mod 
Oberon.Simulator.Mod Oberon.Popups.Mod Oberon.BartSimpson.Mod Oberon.Cups.Mod Oberon.Examples.Mod 
Oberon.Examples1.Mod Oberon.OpenDemo.Mod Oberon.OpenDemo2.Mod Oberon.ExampleOberon.Mod 
Oberon.Suitcases.Mod Oberon.Skeleton.Mod Oberon.ViewSkeleton.Mod Oberon.ColorDriver.Mod 
Oberon.DocumentSkeleton.Mod Oberon.Portraits.Mod Oberon.Reminders.Mod Oberon.TaskExample.Mod 
Oberon.TCPExample.Mod 
~
System.Show Time elapsed: ~ System.Ln ~
System.Timer elapsed ~ System.Ln ~
~]]></Span>

</Text>
