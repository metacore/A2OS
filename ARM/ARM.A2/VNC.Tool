Commands that have to be run in order to get FTP, VNC, RAMFS working are listed in file:
	basel/ARM.A2/ZynqScript.txt
Note that the command for VNC has to be run for the initialization of module WMStandardComponents, so the module ShellController needs to be linked BEFORE.

Compiler.Compile -b=ARM --traceModule=Trace --objectFile=Generic --initLocals
	basel/ARM.A2/KernelLog.Mod Streams.Mod Commands.Mod basel/ARM.A2/ARM.Reals.Mod Clock.Mod Dates.Mod
	Strings.Mod Options.Mod ActiveTimers.Mod Plugins.Mod basel/ARM.A2/ARM.Network.Mod

	Pipes.Mod Files.Mod Shell.Mod basel/ARM.A2/ShellController.Mod
	
	basel/ARM.A2/ARM.IP.Mod TCP.Mod basel/ARM.A2/ARM.IPv4.Mod IPv6.Mod ICMP.Mod UDP.Mod

	DNS.Mod BIT.Mod DES.Mod CLUTs.Mod Displays.Mod DisplayNull.Mod basel/ARM.A2/ARM.Raster.Mod Reflection.Mod Locks.Mod
	UTF8Strings.Mod WMMessages.Mod WMRectangles.Mod basel/ARM.A2/ARM.WMRasterScale.Mod
	WMEvents.Mod SoundDevices.Mod DynamicStrings.Mod XMLObjects.Mod XML.Mod
	XMLScanner.Mod XMLParser.Mod Configuration.Mod FP1616.Mod Texts.Mod Inflate.Mod CRC.Mod
	Unzip.Mod Archives.Mod Codecs.Mod Localization.Mod Repositories.Mod Events.Mod
	UnicodeProperties.Mod WMGraphics.Mod WMDefaultFont.Mod TextUtilities.Mod Types.Mod Models.Mod
	WMWindowManager.Mod WMProperties.Mod WMDropTarget.Mod Inputs.Mod WMComponents.Mod
	WMGraphicUtilities.Mod WMFontManager.Mod WMDefaultWindows.Mod WindowManager.Mod WMStandardComponents.Mod WMPopups.Mod PositionDebugging.Mod
	WMTabComponents.Mod MainMenu.Mod
	UndoManager.Mod HostClipboard.Mod Diagnostics.Mod SyntaxHighlighter.Mod FileHandlers.Mod
	WMPieMenu.Mod UnicodeBidirectionality.Mod ContextualDependency.Mod WMTextView.Mod
	WMInputMethods.Mod WMEditors.Mod WMDialogs.Mod Beep.Mod basel/ARM.A2/ARM.Math.Mod Random.Mod VNCServer.Mod WMVNCView.Mod

	basel/ARM.A2/VNCController.Mod
~

Compiler.Compile -b=ARM --traceModule=Trace --objectFile=Generic --initLocals
	MainMenu.Mod Tar.Mod WMRestorable.Mod WMNavigate.Mod
	WMUtilities.Mod
	PNGDecoder.Mod
	WMOberonFonts.Mod
~
Compiler.Compile -b=ARM --traceModule=Trace --objectFile=Generic --initLocals WMTrees.Mod WMGrids.Mod WMStringGrids.Mod WMMacros.Mod WMSearchComponents.Mod WMDocumentEditor.Mod Notepad.Mod WMSystemComponents.Mod WMFileManager.Mod ~

StaticLinker.Link --fileName=Test.Bin --displacement=100000H -a
	Initializer Runtime Platform FPE64 ARMRuntime Trace Uart
	Machine Heaps Modules Objects Kernel

	KernelLog Plugins Network
	XEmac

	Streams Commands Reals Clock Dates Options
	Strings ActiveTimers IP TCP IPv4 IPv6 ICMP UDP

	Pipes Shell ShellController

	StaticInterface

	DNS BIT DES
	CLUTs Displays DisplayNull Raster Reflection Locks
	UTF8Strings WMMessages WMRectangles WMRasterScale
	WMEvents SoundDevices DynamicStrings XMLObjects XML
	XMLScanner XMLParser Files Configuration FP1616 Texts Inflate CRC
	Unzip Archives Codecs Localization Repositories Events
	UnicodeProperties WMGraphics WMDefaultFont TextUtilities Types Models
	WMWindowManager WMProperties WMDropTarget Inputs WMComponents
	WMGraphicUtilities WMFontManager WMDefaultWindows WindowManager WMStandardComponents WMPopups PositionDebugging
	WMTabComponents MainMenu
	UndoManager HostClipboard Diagnostics SyntaxHighlighter FileHandlers
	WMPieMenu UnicodeBidirectionality ContextualDependency WMTextView
	WMInputMethods WMEditors WMDialogs Beep Math Random VNCServer WMVNCView
	VNCController
~

Compiler.Compile -b=ARM --traceModule=Trace --objectFile=Generic --initLocals
	basel/ARM.A2/Zynq.XEmac.Mod
	basel/ARM.A2/StaticInterface.Mod
	Test.Mod
~

FoxARMInstructionSet.Disassemble Test.Bin -a=1ED10CH ~
FoxARMInstructionSet.Disassemble Init.Bin ~

WMVNCView.Install AOS "a" 5000 0 0 512 512 ~
WMVNCView.Uninstall ~
VNC.Open 127.0.0.1 "a" 5000 ~
VNC.Open 192.168.1.2 "a" 5000 ~
VNC.Show ~
