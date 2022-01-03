<?xml version="1.0" encoding="UTF-8"?>
<?bluebottle format version="0.1" ?>
<?xml-stylesheet type="text/xsl" href="http://bluebottle.ethz.ch/bluebottle.xsl" ?>
<Text>
<Span style="Comment"><![CDATA[# LinuxARM
# Monday, January 3, 2022  13:59:24
# This file has been automatically generated using Release.Mod.
# Red colors indicate that a module imports SYSTEM.
]]></Span><Span style="Bold"><![CDATA[System.DoCommands
]]></Span><Span style="Normal"><![CDATA[System.Timer start ~
Compiler.Compile -p=UnixARM --destPath=NewAos/
]]></Span><Span style="Stupid"><![CDATA[ARM.FPE64.Mod ARM.Builtins.Mod Trace.Mod Linux.Glue.Mod Linux.Unix.Mod 
Unix.Machine.Mod Heaps.Mod Modules.Mod Unix.Objects.Mod ]]></Span><Span style="Normal"><![CDATA[Unix.Kernel.Mod ]]></Span><Span style="Stupid"><![CDATA[RealConversions.Mod ]]></Span><Span style="Normal"><![CDATA[
Strings.Mod UTF8Strings.Mod ]]></Span><Span style="Stupid"><![CDATA[KernelLog.Mod ]]></Span><Span style="Normal"><![CDATA[Plugins.Mod ]]></Span><Span style="Stupid"><![CDATA[Streams.Mod ]]></Span><Span style="Normal"><![CDATA[Pipes.Mod Commands.Mod In.Mod 
Out.Mod ]]></Span><Span style="Stupid"><![CDATA[ARM.Reals.Mod Reflection.Mod ]]></Span><Span style="Normal"><![CDATA[TrapWriters.Mod ]]></Span><Span style="Stupid"><![CDATA[CRC.Mod ]]></Span><Span style="Normal"><![CDATA[SystemVersion.Mod ]]></Span><Span style="Stupid"><![CDATA[Unix.StdIO.Mod 
Unix.Traps.Mod ]]></Span><Span style="Normal"><![CDATA[Locks.Mod Unix.Clock.Mod ]]></Span><Span style="Stupid"><![CDATA[Disks.Mod DiskCaches.Mod Files.Mod ]]></Span><Span style="Normal"><![CDATA[Dates.Mod Options.Mod 
FileTrapWriter.Mod Caches.Mod ]]></Span><Span style="Stupid"><![CDATA[DiskVolumes.Mod OldDiskVolumes.Mod RAMVolumes.Mod DiskFS.Mod OldDiskFS.Mod 
OberonFS.Mod FATVolumes.Mod FATFiles.Mod ]]></Span><Span style="Normal"><![CDATA[ISO9660Volumes.Mod ]]></Span><Span style="Stupid"><![CDATA[ISO9660Files.Mod Unix.UnixFiles.Mod ]]></Span><Span style="Normal"><![CDATA[
RelativeFileSystem.Mod ]]></Span><Span style="Stupid"><![CDATA[BitSets.Mod ]]></Span><Span style="Normal"><![CDATA[Diagnostics.Mod ]]></Span><Span style="Stupid"><![CDATA[StringPool.Mod ]]></Span><Span style="Normal"><![CDATA[ObjectFile.Mod ]]></Span><Span style="Stupid"><![CDATA[GenericLinker.Mod 
Loader.Mod Unix.BootConsole.Mod ]]></Span><Span style="Normal"><![CDATA[Shell.Mod StdIOShell.Mod ]]></Span><Span style="Stupid"><![CDATA[Displays.Mod ]]></Span><Span style="Normal"><![CDATA[Inputs.Mod Events.Mod 
EventsUtils.Mod EventsKernelLog.Mod EventsFileLog.Mod EventsMemoryLog.Mod ]]></Span><Span style="Stupid"><![CDATA[DynamicStrings.Mod ]]></Span><Span style="Normal"><![CDATA[
XMLObjects.Mod XML.Mod XMLScanner.Mod XMLParser.Mod Configuration.Mod FileHandlers.Mod ]]></Span><Span style="Stupid"><![CDATA[Network.Mod ]]></Span><Span style="Normal"><![CDATA[
ActiveTimers.Mod ]]></Span><Span style="Stupid"><![CDATA[Unix.IP.Mod Unix.Sockets.Mod ]]></Span><Span style="Normal"><![CDATA[Unix.TCP.Mod Unix.UDP.Mod ]]></Span><Span style="Stupid"><![CDATA[Unix.DNS.Mod ]]></Span><Span style="Normal"><![CDATA[UnixBinary.Mod 
Serials.Mod SoundDevices.Mod Joysticks.Mod ]]></Span><Span style="Stupid"><![CDATA[TVDriver.Mod ]]></Span><Span style="Normal"><![CDATA[GenericCollections.Mod ]]></Span><Span style="Stupid"><![CDATA[VirtualDisks.Mod ]]></Span><Span style="Normal"><![CDATA[
DisplayNull.Mod Unix.V24.Mod ]]></Span><Span style="Stupid"><![CDATA[Unix.OpenAL.Mod OpenALSound.Mod StringPool.Mod ]]></Span><Span style="Normal"><![CDATA[Diagnostics.Mod ]]></Span><Span style="Stupid"><![CDATA[
Debugging.Mod BitSets.Mod ]]></Span><Span style="Normal"><![CDATA[ObjectFile.Mod ]]></Span><Span style="Stupid"><![CDATA[GenericLinker.Mod ]]></Span><Span style="Normal"><![CDATA[Linker.Mod ]]></Span><Span style="Stupid"><![CDATA[FoxBasic.Mod ]]></Span><Span style="Normal"><![CDATA[FoxProgTools.Mod 
FoxScanner.Mod FoxCSharpScanner.Mod FoxSyntaxTree.Mod FoxGlobal.Mod ]]></Span><Span style="Stupid"><![CDATA[FoxActiveCells.Mod ]]></Span><Span style="Normal"><![CDATA[
FoxHardware.Mod FoxFormats.Mod ]]></Span><Span style="Stupid"><![CDATA[FoxFingerprinter.Mod FoxPrintout.Mod ]]></Span><Span style="Normal"><![CDATA[FoxParser.Mod 
FoxCSharpParser.Mod ]]></Span><Span style="Stupid"><![CDATA[FoxSemanticChecker.Mod ]]></Span><Span style="Normal"><![CDATA[FoxSections.Mod ]]></Span><Span style="Stupid"><![CDATA[FoxBinaryCode.Mod ]]></Span><Span style="Normal"><![CDATA[FoxBackend.Mod 
FoxFrontend.Mod Compiler.Mod FoxOberonFrontend.Mod FoxCSharpFrontend.Mod FoxInterfaceComparison.Mod 
FoxTextualSymbolFile.Mod FoxIntermediateCode.Mod ]]></Span><Span style="Stupid"><![CDATA[FoxIntermediateBackend.Mod ]]></Span><Span style="Normal"><![CDATA[FoxCodeGenerators.Mod 
FoxGenericObjectFile.Mod FoxAMD64InstructionSet.Mod ]]></Span><Span style="Stupid"><![CDATA[FoxAMD64Assembler.Mod ]]></Span><Span style="Normal"><![CDATA[FoxAMDBackend.Mod ]]></Span><Span style="Stupid"><![CDATA[FoxAssembler.Mod ]]></Span><Span style="Normal"><![CDATA[
FoxIntermediateAssembler.Mod FoxDisassembler.Mod FoxARMInstructionSet.Mod FoxARMAssembler.Mod ]]></Span><Span style="Stupid"><![CDATA[FoxARMBackend.Mod 
FoxMinosObjectFile.Mod ]]></Span><Span style="Normal"><![CDATA[FoxIntermediateParser.Mod FoxIntermediateObjectFile.Mod FoxIntermediateLinker.Mod 
FoxTRMInstructionSet.Mod FoxTRMAssembler.Mod ]]></Span><Span style="Stupid"><![CDATA[FoxTRMBackend.Mod FoxInterpreterBackend.Mod ]]></Span><Span style="Normal"><![CDATA[
FoxTranspilerBackend.Mod FoxDocumentationScanner.Mod FoxDocumentationTree.Mod FoxDocumentationPrinter.Mod ]]></Span><Span style="Stupid"><![CDATA[
FoxDocumentationHtml.Mod ]]></Span><Span style="Normal"><![CDATA[FoxDocumentationParser.Mod FoxDocumentationBackend.Mod FoxTestBackend.Mod ]]></Span><Span style="Stupid"><![CDATA[
FoxProfiler.Mod Math.Mod MathL.Mod ]]></Span><Span style="Normal"><![CDATA[ComplexNumbers.Mod ]]></Span><Span style="Stupid"><![CDATA[FoxArrayBase.Mod ]]></Span><Span style="Normal"><![CDATA[PersistentObjects.Mod ]]></Span><Span style="Stupid"><![CDATA[
FoxInterpreterSymbols.Mod FoxInterpreter.Mod ]]></Span><Span style="Normal"><![CDATA[MinosLinker.Mod ]]></Span><Span style="Stupid"><![CDATA[StreamUtilities.Mod ]]></Span><Span style="Normal"><![CDATA[Errors.Mod 
Unix.ProcessInfo0.Mod ]]></Span><Span style="Stupid"><![CDATA[ProcessInfo.Mod ]]></Span><Span style="Normal"><![CDATA[System.Mod Reboot.Mod Unix.PrecisionTimer.Mod ]]></Span><Span style="Stupid"><![CDATA[Unix.HostLibs.Mod ]]></Span><Span style="Normal"><![CDATA[
Stopwatch.Mod ]]></Span><Span style="Stupid"><![CDATA[Math.Mod MathL.Mod Random.Mod ]]></Span><Span style="Normal"><![CDATA[Drand48.Mod SerialsVirtual.Mod Autostart.Mod FSTools.Mod 
UpTime.Mod CLUTs.Mod ]]></Span><Span style="Stupid"><![CDATA[Raster.Mod ]]></Span><Span style="Normal"><![CDATA[Localization.Mod Archives.Mod WMRectangles.Mod WMEvents.Mod 
Repositories.Mod FP1616.Mod Texts.Mod UndoManager.Mod ]]></Span><Span style="Stupid"><![CDATA[CRC.Mod Inflate.Mod ]]></Span><Span style="Normal"><![CDATA[Unzip.Mod ZipFS.Mod Codecs.Mod 
UnicodeProperties.Mod ContextualDependency.Mod UnicodeBidirectionality.Mod ]]></Span><Span style="Stupid"><![CDATA[ARM.WMRasterScale.Mod ]]></Span><Span style="Normal"><![CDATA[
WMGraphics.Mod ]]></Span><Span style="Stupid"><![CDATA[WMGraphicsSmooth.Mod ]]></Span><Span style="Normal"><![CDATA[TextUtilities.Mod Types.Mod Models.Mod WMProperties.Mod ]]></Span><Span style="Stupid"><![CDATA[
WMMessages.Mod ]]></Span><Span style="Normal"><![CDATA[WMWindowManager.Mod WMGraphicUtilities.Mod WMDropTarget.Mod WMComponents.Mod 
KernelLogger.Mod CompilerInterface.Mod TextCompiler.Mod ]]></Span><Span style="Stupid"><![CDATA[PCDebug.Mod PCM.Mod ]]></Span><Span style="Normal"><![CDATA[PCS.Mod ]]></Span><Span style="Stupid"><![CDATA[PCT.Mod PCBT.Mod ]]></Span><Span style="Normal"><![CDATA[
PCLIR.Mod ]]></Span><Span style="Stupid"><![CDATA[PCO.Mod PCG386.Mod PCC.Mod ]]></Span><Span style="Normal"><![CDATA[PCV.Mod PCArrays.Mod ]]></Span><Span style="Stupid"><![CDATA[PCB.Mod PCP.Mod PCA386.Mod PCOM.Mod 
PCOF.Mod PCOFPE.Mod ]]></Span><Span style="Normal"><![CDATA[PC.Mod ]]></Span><Span style="Stupid"><![CDATA[PCOARM.Mod PCARMCP.Mod ]]></Span><Span style="Normal"><![CDATA[PCARMRegisters.Mod ]]></Span><Span style="Stupid"><![CDATA[PCAARM.Mod PCGARM.Mod ]]></Span><Span style="Normal"><![CDATA[
ASMAMD64.Mod ]]></Span><Span style="Stupid"><![CDATA[PCAAMD64.Mod PCGAMD64.Mod ]]></Span><Span style="Normal"><![CDATA[WhitespaceRemover.Mod HostClipboard.Mod Tar.Mod ]]></Span><Span style="Stupid"><![CDATA[Zlib.Mod 
ZlibBuffers.Mod ZlibDeflate.Mod ZlibInflate.Mod ]]></Span><Span style="Normal"><![CDATA[ZlibWriters.Mod ZlibReaders.Mod Zip.Mod ZipTool.Mod ]]></Span><Span style="Stupid"><![CDATA[
BIT.Mod PNGDecoder.Mod ]]></Span><Span style="Normal"><![CDATA[BMPCodec.Mod GIFCodec.Mod ]]></Span><Span style="Stupid"><![CDATA[JPEGDecoder.Mod JPEGEncoder.Mod ]]></Span><Span style="Normal"><![CDATA[
AnimationCodec.Mod PartitionsLib.Mod ]]></Span><Span style="Stupid"><![CDATA[FATScavenger.Mod ]]></Span><Span style="Normal"><![CDATA[Partitions.Mod DiskTests.Mod DiskBenchmark.Mod 
PartitionEditorTable.Mod ]]></Span><Span style="Stupid"><![CDATA[Unix.HierarchicalProfiler0.Mod HierarchicalProfiler.Mod ]]></Span><Span style="Normal"><![CDATA[FTPClient.Mod ]]></Span><Span style="Stupid"><![CDATA[XYModem.Mod ]]></Span><Span style="Normal"><![CDATA[
Shell.Mod ShellSerial.Mod Installer.Mod CryptoBigNumbers.Mod CryptoBase64.Mod ]]></Span><Span style="Stupid"><![CDATA[CryptoUtils.Mod ]]></Span><Span style="Normal"><![CDATA[
CryptoCiphers.Mod CryptoARC4.Mod CryptoDES.Mod CryptoDES3.Mod CryptoHashes.Mod CryptoMD5.Mod 
CryptoSHA1.Mod CryptoSHA256.Mod ]]></Span><Span style="Stupid"><![CDATA[CryptoKeccakF1600.Mod ]]></Span><Span style="Normal"><![CDATA[CryptoKeccakSponge.Mod CryptoSHA3.Mod 
CryptoCSPRNG.Mod CryptoPrimes.Mod CryptoDSA.Mod CryptoDiffieHellman.Mod CryptoAES.Mod 
CryptoBlowfish.Mod CryptoTwofish.Mod CryptoCAST.Mod CryptoHMAC.Mod CryptoIDEA.Mod CryptoRSA.Mod 
CryptoStreams.Mod CryptoFortuna.Mod CryptoFortunaRng.Mod Checksum.Mod Fido.Mod A2Sequencers.Mod ]]></Span><Span style="Stupid"><![CDATA[
PictImages.Mod ]]></Span><Span style="Normal"><![CDATA[V24Tracer.Mod XMLGeneratorSchema.Mod CSS2.Mod CSS2Scanner.Mod CSS2Parser.Mod 
RAWPrinter.Mod LPR.Mod ASN1.Mod PKCS1.Mod X509.Mod TLS.Mod TCPServices.Mod TestServer.Mod TCPTools.Mod 
IPBandwidth.Mod Windows.Performance.Mod Bin2Hex.Mod BinToCode.Mod Base64.Mod ]]></Span><Span style="Stupid"><![CDATA[DisplayGTF.Mod ]]></Span><Span style="Normal"><![CDATA[GZip.Mod 
ShellCommands.Mod Telnet.Mod ]]></Span><Span style="Stupid"><![CDATA[TFClasses.Mod ]]></Span><Span style="Normal"><![CDATA[Mail.Mod SMTPClient.Mod TFLog.Mod WebHTTP.Mod 
WebHTTPClient.Mod WebHTTPTools.Mod WebHTTPServer.Mod WebHTTPServerTools.Mod WebSSMPPlugin.Mod 
WebHTTPServerStatistics.Mod WebSockets.Mod POP3Client.Mod RFC865Client.Mod QuoteServer.Mod ]]></Span><Span style="Stupid"><![CDATA[RfsConnection.Mod 
RfsClientProxy.Mod RfsFS.Mod ]]></Span><Span style="Normal"><![CDATA[TFTP.Mod TFTPServer.Mod ]]></Span><Span style="Stupid"><![CDATA[TFTPFS.Mod FTPFS.Mod ]]></Span><Span style="Normal"><![CDATA[WebFTPServer.Mod ]]></Span><Span style="Stupid"><![CDATA[XModem.Mod ]]></Span><Span style="Normal"><![CDATA[
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
W3dClusterWatch.Mod Snow.Mod MenuEdit.Mod PresentViewer.Mod TestSuite.Mod PCTest.Mod Versioning.Mod 
FoxTest.Mod TestFiles.Mod BenchTCP.Mod TestDates.Mod ]]></Span><Span style="Stupid"><![CDATA[TestStrings.Mod ]]></Span><Span style="Normal"><![CDATA[BenchXML.Mod 
BenchSyntaxHighlighter.Mod CryptoTestBigNumbers.Mod CryptoTestCiphers.Mod CryptoTestDH.Mod CryptoTestDSA.Mod 
CryptoTestHMAC.Mod CryptoTestHashes.Mod CryptoTestRSA.Mod BeepTest.Mod JoysticksTest.Mod TestMenu.Mod 
PieTest.Mod TestTrees.Mod TestComponentDragDrop.Mod ComponentInfo.Mod TestComponents.Mod 
TestXMLPlugins.Mod HelloWorld.Mod HelloWorld1.Mod HelloWorld2.Mod HelloWorld3.Mod Example1.Mod 
Example2.Mod Example3.Mod Example4.Mod Example5.Mod Example6.Mod Example7.Mod Example8.Mod 
ExampleTextWriter.Mod JavaLocks.Mod WebAccounts.Mod WebForum.Mod ExerciseGroups.Mod ]]></Span><Span style="Stupid"><![CDATA[IsoImages.Mod ]]></Span><Span style="Normal"><![CDATA[
ReleaseThreadPool.Mod Release.Mod PETReleaseTree.Mod BootManager.Mod Sage.UDPChatBase.Mod 
Sage.UDPChatServer.Mod Sage.UDPChatClient.Mod CyrillicUtilities.Mod YMF754Util.Mod ]]></Span><Span style="Stupid"><![CDATA[SambaClient.Mod 
SambaServer.Mod ]]></Span><Span style="Normal"><![CDATA[MenuPages.Mod ]]></Span><Span style="Stupid"><![CDATA[RasterPixelFormats.Mod ]]></Span><Span style="Normal"><![CDATA[WMOverlay.Mod PrettyPrint.Mod BitStreams.Mod 
NextPrime.Mod MoveToFront.Mod BWHCompressor.Mod OZip3.Mod NbrInt8.Mod NbrInt16.Mod NbrInt32.Mod 
NbrInt64.Mod NbrInt.Mod NbrRat.Mod NbrRe32.Mod NbrRe64.Mod NbrRe.Mod NbrCplx.Mod NbrStrings.Mod ]]></Span><Span style="Stupid"><![CDATA[
DataErrors.Mod ]]></Span><Span style="Normal"><![CDATA[DataIO.Mod Data.Mod DataStacks.Mod DataQueues.Mod DataLists.Mod DataTrees.Mod 
MathInt.Mod MathRat.Mod MathReSeries.Mod MathRe.Mod MathCplxSeries.Mod MathCplx.Mod MathCbrt.Mod 
MathErf.Mod MathGamma.Mod CalcFn.Mod CalcD1.Mod CalcD2.Mod CalcD3.Mod CalcD4.Mod CalcGauss.Mod 
MathMitLef.Mod CalcConvolution.Mod CalcGrunwald.Mod CalcDiethelm.Mod WPM.Mod AlmSmtpReceiver.Mod 
WMFontCCGConverter.Mod WebCGI.Mod RegisterRFW.Mod WebBimbodot.Mod TFWebForum.Mod PDF.Mod AFM.Mod 
PDFExample.Mod Visualizer.Mod ReleaseVisualizerScanner.Mod ReleaseVisualizer.Mod OdUtil.Mod 
OdXml.Mod OdCond.Mod OdAuthBase.Mod OdAuth.Mod OdClient.Mod ]]></Span><Span style="Stupid"><![CDATA[OdVCSBase.Mod ]]></Span><Span style="Normal"><![CDATA[SVNArgument.Mod 
SVNOutput.Mod SVNUtil.Mod SVNAdmin.Mod OdSvn.Mod SVNWebDAV.Mod SVN.Mod 
~
System.Show Time elapsed: ~ System.Ln ~
System.Timer elapsed ~ System.Ln ~
~]]></Span>

</Text>
