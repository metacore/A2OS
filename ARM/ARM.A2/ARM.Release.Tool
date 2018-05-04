# Release Tool for Zynq boards.
HEADER
	VERSION "1.0"
END

BUILDS
	ZynqStatic {
		INCLUDE "ARM NATIVE ZYNQ A2 STATIC"
		COMPILER "Compiler.Compile"
		COMPILEOPTIONS "-p=ARMA2 --objectFile=Generic --newObjectFile --mergeSections --useFPU32 --useFPU64"
		TARGET "ARM"
		EXTENSION "Gof"
		SYMBOLEXTENSION "Sym"
		LINKER "StaticLinker.Link --fileName=A2.Bin --displacement=100000H -a"
		LINKEROPTIONS ""
		EXCLUDEPACKAGES ""
		PATH ""
		DISABLED "FALSE"
	}

	ZynqDynamic {
		INCLUDE "ARM NATIVE ZYNQ A2 DYNAMIC"
		COMPILER "Compiler.Compile"
		COMPILEOPTIONS "-p=ARMA2 --objectFile=Generic --newObjectFile --mergeSections --useFPU32 --useFPU64"
		TARGET "ARM"
		EXTENSION "Gof"
		SYMBOLEXTENSION "Sym"
		LINKER "StaticLinker.Link --fileName=A2.Bin --displacement=100000H -a"
		LINKEROPTIONS ""
		EXCLUDEPACKAGES ""
		PATH ""
		DISABLED "FALSE"
	}
END

## System Core
PACKAGE Kernel ARCHIVE "Kernel.zip" SOURCE "KernelSrc.zip" DESCRIPTION "A2 Kernel"
	ARM { ZYNQ:/ARM.Runtime.Mod ZYNQ:/ARM.Initializer.Mod }
	ZYNQ { ZYNQ:/Zynq.ARM.Platform.Mod }
	ARM { ARM.FPE64.Mod ARM.ARMRuntime.Mod }
	Trace.Mod
	STATIC { ZYNQ:/Static.BootConfig.Mod }
	DYNAMIC { ZYNQ:/Dynamic.BootConfig.Mod }

	ZYNQ {
		# Trace using PS UART
		ZYNQ:/Zynq.PsUartMin.Mod
		ZYNQ:/Zynq.PsTraceDevice.Mod

		ZYNQ:/Zynq.PrivateWatchdog.Mod
		ZYNQ:/ARM.Machine.Mod
	}
	Heaps.Mod
	NATIVE { Generic.Modules.Mod }
	ARM {
		ZYNQ:/ARM.Objects.Mod
		ZYNQ:/ARM.Kernel.Mod
	}
	ZYNQ {
		ZYNQ:/Zynq.PsUartInterrupts.Mod
		ZYNQ:/Zynq.PsUart.Mod
	}
END

PACKAGE System ARCHIVE "System.zip" SOURCE "SystemSrc.zip" DESCRIPTION "System"
	KernelLog.Mod
	Plugins.Mod Streams.Mod Pipes.Mod Commands.Mod
	ARM { ARM.Reals.Mod }
	# Temporary dummy driver for RTC
	ARM { ZYNQ:Clock.Mod }
	Dates.Mod
	Strings.Mod
	Files.Mod
	Disks.Mod
	Generic.Reflection.Mod
	TrapWriters.Mod
	ARM { ARM.Traps.Mod }
	Locks.Mod
	Options.Mod
	ZYNQ { ZYNQ:Zynq.PsConfig.Mod }
	ZYNQ:/Timer.Mod
END

PACKAGE SD ARCHIVE "SD.zip" SOURCE "SDSrc.zip" DESCRIPTION "SD Disk driver"
	ZYNQ { ZYNQ:/SdEnvironment.Mod }
	ZYNQ:/Sd.Mod
	ZYNQ:/SdDisks.Mod
	ZYNQ { ZYNQ:/Zynq.SdControllers.Mod }
END

PACKAGE Math ARCHIVE "Math.zip" SOURCE "MathSrc.zip" DESCRIPTION "Math utilities"
	ARM {
		ARM.Math.Mod
		ARM.MathL.Mod
	}
	ComplexNumbers.Mod
	ARM {
		ZYNQ:/ARM.FoxArrayBase.Mod
	}
	Random.Mod
END

PACKAGE SystemTools ARCHIVE "SystemTools.zip" SOURCE "SystemToolsSrc.zip" DESCRIPTION "System and FS Commands"
	Configuration.XML
	UTF8Strings.Mod DynamicStrings.Mod XMLObjects.Mod XML.Mod XMLScanner.Mod XMLParser.Mod Configuration.Mod
	FSTools.Mod

	ProcessInfo0.Mod ProcessInfo.Mod CRC.Mod SystemVersion.Mod SystemTools.Mod
END

## Drivers
PACKAGE Network ARCHIVE "Network.zip" SOURCE "NetworkSrc.zip" DESCRIPTION "Networking"
	ActiveTimers.Mod
	ARM { ARM.Network.Mod }
	ZYNQ { ZYNQ:/Zynq.XEmac.Mod }
	ARM { ARM.IP.Mod ARM.IPv4.Mod }
	TCP.Mod IPv6.Mod ICMP.Mod UDP.Mod DNS.Mod
	ZYNQ { ZYNQ:/StaticInterface.Mod }
END

PACKAGE FpgaDisplay ARCHIVE "FpgaDisplay.zip" SOURCE "FpgaDisplaySrc.zip" DESCRIPTION "FPGA Framebuffer display driver"
	Displays.Mod
	ZYNQ {
		ActiveCells/AcDrivers/Zynq.AcAxisIo.Mod
		ActiveCells/AcDrivers/AcStreamVideoOut.Mod
		ActiveCells/AcDrivers/AcAxiDma.Mod
		ZYNQ:/Zynq.DisplayLinear.Mod
	}
END

PACKAGE Usb ARCHIVE "Usb.zip" SOURCE "UsbSrc.zip" DESCRIPTION "USB"
	UsbDebug.Mod

	USB:/UsbBuffers.Mod
	USB:/Usbdi.Mod
	USB:/UsbHcdi.Mod
	USB:/UsbVarTdAlloc.Mod

	#USB:/I386.UsbBuffers.Mod
	#Usbdi.Mod
	#UsbHcdi.Mod
	#UsbEhci.Mod

	UsbDriverLoader.Mod
	UsbUtilities.Mod
	USB:/Usb.Mod
	USB:/UsbHubDriver.Mod
	USB:/UsbEhci.Mod
	ZYNQ { ZYNQ:/Zynq.Gpio.Mod ZYNQ:/Zynq.UsbEhciPhy.Mod ZYNQ:/UsbEhciZynq.Mod }
	UsbInfo.Mod

	USB:/UsbStorageBase.Mod USB:/UsbStorageCbi.Mod USB:/UsbStorageBot.Mod USB:/UsbStorageScm.Mod UsbStorage.Mod
	UsbStorageBoot.Mod

	USB:UsbHid.Mod
	Inputs.Mod
	UsbHidErrors.Mod
	UsbHidUP.Mod
	UsbHidParserExt.Mod
	UsbHidReport.Mod
	UsbHidParser.Mod
	ARM { ZYNQ:/ARM.UsbKeyboard.Mod }
	Joysticks.Mod
	USB:UsbHidDriver.Mod
	UsbTouchscreen.Mod
	#UsbVideoDesc.Mod UsbVideo.Mod
END

PACKAGE BootConsole ARCHIVE "BootConsole.zip" SOURCE "BootConsoleSrc.zip" DESCRIPTION "Boot console that installs base system from boot config"
	Caches.Mod DiskVolumes.Mod DiskFS.Mod
	BitSets.Mod StringPool.Mod ObjectFile.Mod Diagnostics.Mod GenericLinker.Mod GenericLoader.Mod
	BootConsole.Mod
END

PACKAGE DMA ARCHIVE "DMA.zip" SOURCE "DMASrc.zip" DESCRIPTION "DMA"
	ZYNQ {
		ZYNQ:/DMA330.Mod
		ZYNQ:/DMA330ProgramWriter.Mod
	}
END

## Plugin services
PACKAGE FS ARCHIVE "FS.zip" SOURCE "FSSrc.zip" DESCRIPTION "Additional file systems"
	FATVolumes.Mod FATFiles.Mod
	Caches.Mod DiskFS.Mod DiskVolumes.Mod

	RelativeFileSystem.Mod
	#SambaClient.Mod

	FileTrapWriter.Mod
END

PACKAGE Profiler ARCHIVE "Profiler.zip" SOURCE "ProfilerSrc.zip" DESCRIPTION "Fox profiler"
	FoxProfiler.Mod
END

## UI
PACKAGE Shell ARCHIVE "Shell.zip" SOURCE "ShellSrc.zip" DESCRIPTION "Interactive UART shell"
	Shell.Alias
	Shell.Mod
	Serials.Mod
	ZYNQ:/Zynq.PsSerials.Mod
	ActiveCells/AcDrivers/AcUarts.Mod
	ActiveCells/AcDrivers/AcSerials.Mod
	XYModem.Mod
	ShellSerial.Mod
END

PACKAGE GUI ARCHIVE "GUI.zip" SOURCE "GUISrc.zip" DESCRIPTION "GUI & WindowManager"
	Debugging.Mod
	CLUTs.Mod Displays.Mod DisplayNull.Mod
	ARM { ZYNQ:/ARM.Raster.Mod }
	WMMessages.Mod WMRectangles.Mod
	ARM { ZYNQ:/ARM.WMRasterScale.Mod }
	WMEvents.Mod SoundDevices.Mod FP1616.Mod Texts.Mod Inflate.Mod CRC.Mod
	Unzip.Mod Archives.Mod Codecs.Mod Localization.Mod Repositories.Mod Events.Mod

	UnicodeProperties.Mod
	WMGraphics.Mod WMDefaultFont.Mod WMGraphicsSmooth.Mod
	
	BMPCodec.Mod

	TextUtilities.Mod Types.Mod Models.Mod
	WMWindowManager.Mod WMProperties.Mod WMDropTarget.Mod Inputs.Mod WMComponents.Mod
	WMGraphicUtilities.Mod WMFontManager.Mod WMDefaultWindows.Mod WindowManager.Mod

	WMStandardComponents.Mod WMPopups.Mod PositionDebugging.Mod
	WMTabComponents.Mod MainMenu.Mod
	UndoManager.Mod HostClipboard.Mod Diagnostics.Mod SyntaxHighlighter.Mod FileHandlers.Mod
	WMPieMenu.Mod UnicodeBidirectionality.Mod
	
	WMProgressComponents.Mod

	ContextualDependency.Mod WMTextView.Mod
	WMInputMethods.Mod WMEditors.Mod WMDialogs.Mod Beep.Mod

	WMRestorable.Mod

	WMTrees.Mod WMGrids.Mod WMStringGrids.Mod WMMacros.Mod WMSearchComponents.Mod WMDocumentEditor.Mod
	Notepad.Mod WMSystemComponents.Mod WMFileManager.Mod

	Tar.Mod WMNavigate.Mod WMUtilities.Mod PNGDecoder.Mod WMOberonFonts.Mod

	OpenTypeInt.Mod OpenTypeScan.Mod OpenType.Mod WMOTFonts.Mod

	KernelLogger.Mod WMKernelLog.Mod

	WMPicView.Mod

	WMMenus.Mod WMColorComponents.Mod WMDropDownLists.Mod WMScrollableComponents.Mod WMInspectionComponents.Mod ComponentViewer.Mod
	WMInspector.Mod

	WMTrapWriter.Mod
	StartMenu.Mod

	AutoStart.Mod

	# Resources
	Aos.Par AosDefault.Pal aqua.skin ArabicContext.xml Authorization.html Auto.dsk Backdrop.Pict BackdropList.XML Bart.Pict benevento.ttf Black.Pal bluebottle.xsl BluebottlePic0.png BluePlastic.skin Bows.Pict Bricks.Pict CapoTest1.2.zip Cards.Pict Cells.Pict City.poly cjkfont.bfnt
	Clouds.jp2 Clouds.Pict Clown.Pict Cluster.XML cnErrors.XML Coco.Report.ps code.css Coins.Pict Colors.rep CompileCommand.Tool ComponentStyle.XML CoordSys.Shape Courier10.Pr3.Fnt Courier10.Pr6.Fnt Courier10.Scn.Fnt Courier12.Pr3.Fnt Courier12.Pr6.Fnt Courier12.Scn.Fnt Courier8.Pr3.Fnt Courier8.Pr6.Fnt
	Courier8.Scn.Fnt Crochet.Pict Cube.poly Dark.Pal DecoderRes.zip Default.Pal Default.Pict DefaultTextStyles.XML Demo.Content.XML Demo.Layout.XML Demo.Style.XML Demos.rep Distance.Shape DriverDatabase.XML ElevatorStyle.XML Errors.XML Evening.jp2 Example.poly FigureExample.Cwd flags.avi Flock.Pict
	Fractal.Pict Gadgets.Pict Gadgets.poly GfxHowto.html GfxOverview.html GfxProlog.ps glass.skin Grapes.Pict Greek10.Pr3.Fnt Greek10.Scn.Fnt Greek12.Pr3.Fnt Greek12.Scn.Fnt Greek14.Pr3.Fnt Greek14.Scn.Fnt Greek16.Pr3.Fnt Greek16.Scn.Fnt Greek20.Pr3.Fnt Greek20.Scn.Fnt Greek24.Pr3.Fnt Greek24.Scn.Fnt GUIPat.tar
	HotKeys.XML icons.tar IMAPIcons.tar InstallerPackages.XML jiret.ttf Light.Pal Macros.XML Marble.Pict mars.png Math10.Pr3.Fnt Math10.Pr6.Fnt Math10.Scn.Fnt Math12.Pr3.Fnt Math12.Pr6.Fnt Math12.Scn.Fnt Math14.Pr3.Fnt Math14.Pr6.Fnt Math14.Scn.Fnt Math16.Pr3.Fnt Math16.Pr6.Fnt Math16.Scn.Fnt
	Math20.Pr3.Fnt Math20.Pr6.Fnt Math20.Scn.Fnt Math24.Pr3.Fnt Math24.Pr6.Fnt Math24.Scn.Fnt Menu.XML MenuPage00.XML MenuPage10.XML MenuPage20.XML MenuPage30.XML MenuPage40.XML MenuPage50.XML MenuPage60.XML MenuPage70.XML MenuPage80.XML MenuPage90.XML MineSweeperBD.Pict Models.rep ModuleTreesIcons.tar Molecules.Pict
	Navigation.rep next.png NGon.Shape Oberon10.Pr3.Fnt Oberon10.Pr6.Fnt Oberon10.Scn.Fnt Oberon10b.Pr3.Fnt Oberon10b.Pr6.Fnt Oberon10b.Scn.Fnt Oberon10i.Pr3.Fnt Oberon10i.Pr6.Fnt Oberon10i.Scn.Fnt Oberon12.Pr3.Fnt Oberon12.Pr6.Fnt Oberon12.Scn.Fnt Oberon12b.Pr3.Fnt Oberon12b.Pr6.Fnt Oberon12b.Scn.Fnt Oberon12i.Pr3.Fnt Oberon12i.Pr6.Fnt Oberon12i.Scn.Fnt
	Oberon14.Pr3.Fnt Oberon14.Pr6.Fnt Oberon14.Scn.Fnt Oberon14b.Pr3.Fnt Oberon14b.Pr6.Fnt Oberon14b.Scn.Fnt Oberon14i.Pr3.Fnt Oberon14i.Pr6.Fnt Oberon14i.Scn.Fnt Oberon16.Pr3.Fnt Oberon16.Pr6.Fnt Oberon16.Scn.Fnt Oberon16b.Pr3.Fnt Oberon16b.Pr6.Fnt Oberon16b.Scn.Fnt Oberon16i.Pr3.Fnt Oberon16i.Pr6.Fnt Oberon16i.Scn.Fnt Oberon20.Pr3.Fnt Oberon20.Pr6.Fnt Oberon20.Scn.Fnt
	Oberon20b.Pr3.Fnt Oberon20b.Pr6.Fnt Oberon20b.Scn.Fnt Oberon20i.Pr3.Fnt Oberon20i.Pr6.Fnt Oberon20i.Scn.Fnt Oberon24.Pr3.Fnt Oberon24.Pr6.Fnt Oberon24.Scn.Fnt Oberon24b.Pr3.Fnt Oberon24b.Pr6.Fnt Oberon24b.Scn.Fnt Oberon24i.Pr3.Fnt Oberon24i.Pr6.Fnt Oberon24i.Scn.Fnt Oberon8.Pr3.Fnt Oberon8.Pr6.Fnt Oberon8.Scn.Fnt Oberon8b.Pr3.Fnt Oberon8b.Pr6.Fnt Oberon8b.Scn.Fnt
	Oberon8i.Pr3.Fnt Oberon8i.Pr6.Fnt Oberon8i.Scn.Fnt OberonReport.html Parser.FRM pci.ids Pebbles.Pict PETIcons.tar Philus10.Scn.Fnt Philus10b.Scn.Fnt Philus12.Scn.Fnt Philus12b.Scn.Fnt pklook.skin Plasma.Pict present.tar PrettyPrintHighlighter.XML prev.png PTMono.ttf PTMonoB.ttf PTSans.ttf PTSansB.ttf
	PTSansBI.ttf PTSansCaption.ttf PTSansCaptionB.ttf PTSansI.ttf PTSansNarrow.ttf PTSansNarrowB.ttf PTSerif.ttf PTSerifB.ttf PTSerifBI.ttf PTSerifCaption.ttf PTSerifCaptionI.ttf PTSerifI.ttf public.ActiveObjects.ssmp public.form.html public.info.ssmp public.Memory.ssmp public.System.ssmp public.WebServer.ssmp Rainbow.jp2 Rect2.Shape recticle.png
	redlook.skin refresh.png Rename.TFMailConfig.XML reptile.skin RetoWMSlideshow.XML Room.poly SaasFee.jpg Save.Configuration.XML SaveLife.gif SaveLife.html Scanner.FRM Scheme.Init Shanghai.Scn.Fnt Shapes.rep SkinConfig.XML SkinList.XML SlideShowData.tar Sphere.poly Spirals.Pict Standard.rep StartMenu.rep stijn.skin
	stijnbw.skin stucki01.svg stucki02.svg Surface.Pict Syntax10.Pr3.Fnt Syntax10.Scn.Fnt Syntax10b.Pr3.Fnt Syntax10b.Scn.Fnt Syntax10i.Pr3.Fnt Syntax10i.Scn.Fnt Syntax10m.Pr3.Fnt Syntax10m.Scn.Fnt Syntax12.Pr3.Fnt Syntax12.Scn.Fnt Syntax12b.Pr3.Fnt Syntax12b.Scn.Fnt Syntax12i.Pr3.Fnt Syntax12i.Scn.Fnt Syntax12m.Pr3.Fnt Syntax12m.Scn.Fnt Syntax14.Pr3.Fnt
	Syntax14.Scn.Fnt Syntax14b.Pr3.Fnt Syntax14b.Scn.Fnt Syntax14i.Pr3.Fnt Syntax14i.Scn.Fnt Syntax14m.Pr3.Fnt Syntax14m.Scn.Fnt Syntax16.Pr3.Fnt Syntax16.Scn.Fnt Syntax16b.Pr3.Fnt Syntax16b.Scn.Fnt Syntax16i.Pr3.Fnt Syntax16i.Scn.Fnt Syntax16m.Pr3.Fnt Syntax16m.Scn.Fnt Syntax20.Pr3.Fnt Syntax20.Scn.Fnt Syntax20b.Pr3.Fnt Syntax20b.Scn.Fnt Syntax20i.Pr3.Fnt Syntax20i.Scn.Fnt
	Syntax20m.Pr3.Fnt
	Syntax20m.Scn.Fnt
	Syntax24.Pr3.Fnt
	Syntax24.Scn.Fnt
	Syntax24b.Pr3.Fnt
	Syntax24b.Scn.Fnt
	Syntax24i.Pr3.Fnt
	Syntax24i.Scn.Fnt
	Syntax24m.Pr3.Fnt
	Syntax24m.Scn.Fnt
	Syntax8.Pr3.Fnt
	Syntax8.Scn.Fnt
	Syntax8b.Pr3.Fnt
	Syntax8b.Scn.Fnt
	Syntax8i.Pr3.Fnt
	Syntax8i.Scn.Fnt
	Syntax8m.Pr3.Fnt
	Syntax8m.Scn.Fnt
	SyntaxHighlighter.XML
	System.rep
	System3F1.Graphic
	System3F2.Graphic
	System3F3.Graphic
	System3F4.Graphic
	System3F5.Graphic
	System3F6.Graphic
	System3F7.Graphic
	teletext.bfnt
	TeletextServer.zip
	TestContext.xml
	Tetra.poly
	Textils.Pict
	Threads.Pict
	traditional.skin
	Tree.poly
	Tree1.Pict
	Trees.Pict
	TVChannels.XML
	Vera.ttf
	VeraBd.ttf
	VeraBI.ttf
	VeraI.ttf
	VeraMo.ttf
	VeraMoBd.ttf
	VeraMoBI.ttf
	VeraMoI.ttf
	VeraSe.ttf
	VeraSeBd.ttf
	Vinci.Init
	W3dClusterWatchIcons.tar
	W3dMenu.XML
	W3dMenuIcons.tar
	White.Pal
	winxp.skin
	WMBuilder.tar
	WMBunnyImages.tar
	WMClockImages.tar
	WMIcons.tar
	WMInspector.tar
	WMInstaller.tar
	WMOverlay.tar
	WMPerfMonAlerts.XML
	WMRepositories.tar
	WMTaskScheduler.tar
	WMUsbInfo.tar
	X29Plane.poly
	XMas.poly
	xmas.skin
	xmas04.tar
	XmasMenu.XML
	YinYang.Shape
	ZeroSkin.zip
END

PACKAGE Compiler ARCHIVE "Compiler.zip" SOURCE "CompilerSrc.zip" DESCRIPTION "Active Oberon Compiler"
	# this package should be moved before any GUI part (dependencies must be removed in Backend)

	StringPool.Mod Diagnostics.Mod Debugging.Mod
	CompilerInterface.Mod

	Fox.Tool
	BitSets.Mod ObjectFile.Mod GenericLinker.Mod StaticLinker.Mod
	FoxBasic.Mod  FoxProgTools.Mod  FoxScanner.Mod FoxCSharpScanner.Mod FoxSyntaxTree.Mod FoxGlobal.Mod
	FoxFormats.Mod 	FoxFingerPrinter.Mod FoxPrintout.Mod
	FoxParser.Mod FoxCSharpParser.Mod  FoxSemanticChecker.Mod
	FoxBackend.Mod FoxSections.Mod
	FoxFrontend.Mod
	FoxCompiler.Mod
	FoxOberonFrontend.Mod FoxCSharpFrontend.Mod
  	FoxInterfaceComparison.Mod FoxTextualSymbolFile.Mod FoxBinarySymbolFile.Mod
	FoxBinaryCode.Mod FoxIntermediateCode.Mod FoxIntermediateBackend.Mod FoxCodeGenerators.Mod
	FoxBinaryObjectFile.Mod FoxGenericObjectFile.Mod
	FoxAMD64InstructionSet.Mod FoxAMD64Assembler.Mod FoxAMDBackend.Mod
	FoxAssembler.Mod FoxIntermediateAssembler.Mod FoxDisassembler.Mod
	FoxARMInstructionSet.Mod FoxARMAssembler.Mod FoxARMBackend.Mod	FoxMinosObjectFile.Mod
	FoxIntermediateParser.Mod FoxIntermediateObjectFile.Mod FoxIntermediateLinker.Mod
	FoxTRMInstructionSet.Mod FoxTRMAssembler.Mod FoxTRMBackend.Mod
	FoxInterpreterBackend.Mod FoxTranspilerBackend.Mod
	FoxDocumentationScanner.Mod FoxDocumentationTree.Mod FoxDocumentationPrinter.Mod FoxDocumentationHtml.Mod
	FoxDocumentationParser.Mod FoxDocumentationBackend.Mod

	FoxTRMTools.Mod
	ActiveCellsRuntime.mod
	ActiveCellsRunner.mod

	FoxProfiler.Mod
	FoxTextCompiler.Mod FoxA2Interface.Mod Versioning.Mod TestSuite.Mod FoxTest.Mod

	PersistentObjects.Mod FoxInterpreterSymbols.Mod FoxInterpreter.Mod
	InterpreterShell.Mod WMInterpreterShell.Mod
END

## ENET
PACKAGE Enet ARCHIVE "Enet.zip" SOURCE "EnetSrc.zip" DESCRIPTION "Ethernet stack"
	hdct/Enet/ARM.A2.EnetEnvironment.Mod
	hdct/Enet/EnetTiming.Mod
	ARM { hdct/Enet/EnetUtils.Mod }
	hdct/Enet/EnetTrace.Mod
	hdct/Enet/EnetBase.Mod
	hdct/Enet/EnetInterfaces.Mod
	hdct/Enet/EnetArp.Mod
	hdct/Enet/EnetIcmp.Mod
	hdct/Enet/EnetUdp.Mod
	hdct/Enet/A2.Enet.Mod
	hdct/Enet/EnetPhy.Mod
	ZYNQ { hdct/Enet/Zynq.EnetEmacPs7.Mod }
END

PACKAGE SystemExt ARCHIVE "SystemExt.zip" SOURCE "SystemExtSrc.zip" DESCRIPTION "Various system apps/tools"
	BIT.Mod
	V24.Mod SerialsVirtual.Mod

	OldDiskVolumes.Mod ISO9660Volumes.Mod PartitionsLib.Mod FATScavenger.Mod Partitions.Mod

	ActiveTimers.Mod
END

PACKAGE Crypto ARCHIVE "Crypto.zip" SOURCE "CryptoSrc.zip" DESCRIPTION "Cryptography library"
	CryptoBigNumbers.Mod CryptoBase64.Mod CryptoUtils.Mod CryptoCiphers.Mod CryptoARC4.Mod
	CryptoDES.Mod CryptoDES3.Mod
	CryptoHashes.Mod CryptoMD5.Mod CryptoSHA1.Mod CryptoSHA256.Mod
	CryptoKeccakF1600.Mod CryptoKeccakSponge.Mod CryptoSHA3.Mod CryptoCSPRNG.Mod
	CryptoPrimes.Mod CryptoDSA.Mod CryptoDiffieHellman.Mod
	CryptoAES.Mod
	CryptoBlowfish.Mod
	CryptoTwofish.Mod
	CryptoCAST.Mod
	CryptoHMAC.Mod CryptoIDEA.Mod
	CryptoRSA.Mod
END

PACKAGE Gfx ARCHIVE "Gfx.zip" SOURCE "GfxSrc.zip" DESCRIPTION "Gfx graphics library"
	GfxMatrix.Mod
	GfxImages.Mod
	GfxPaths.Mod
	GfxRegions.Mod
	GfxFonts.Mod
	Gfx.Mod
	GfxRaster.Mod
	GfxBuffer.Mod
END

PACKAGE Archives ARCHIVE "Archives.zip" SOURCE "ArchivesSrc.zip" DESCRIPTION "Archiving tools"
	Archives.Mod
	Inflate.Mod # decompression on streams
	
	Tar.Mod

	Zlib.Mod ZlibBuffers.Mod ZlibDeflate.Mod ZlibInflate.Mod 	# Zlib
	ZlibWriters.Mod ZlibReaders.Mod Zip.Mod ZipTool.Mod	# Zip FS prk
	
	Unzip.Mod 	# zip file support
	ZipFS.Mod
	GZip.Mod
END

PACKAGE Inga ARCHIVE "Inga.zip" SOURCE "IngaSrc.zip" DESCRIPTION "Interactive Graphics for A2"
	inga/IngaObjects.Mod
	inga/IngaArrays.Mod
	inga/IngaContexts.Mod
	inga/IngaViews.Mod
	inga/IngaContexts2d.Mod
	inga/IngaExampleLayer.Mod
	inga/IngaScale.Mod
	inga/IngaGrid.Mod
	inga/IngaScatter1.Mod
	inga/IngaScatter2.Mod
	inga/IngaLinePlot.Mod
	inga/IngaLine.Mod

	inga/IngaComponents.Mod
	inga/Buffers.Mod
	inga/IngaRealtimePlot.Mod
	inga/IngaTrendPlot.Mod
	inga/IngaValueViewer.Mod

	inga/IngaImShow.Mod

	inga/WMWheelSlider.Mod
	inga/Units.Mod
	inga/HDComponents.Mod
END

