# This script is used to generate a mini (not minimal) WinA2 64 (WinA2Mini64.zip)

System.DoCommands

System.Timer start ~

System.Show Create ramdisk and format with FAT file system... ~ System.Ln ~
VirtualDisks.InstallRamdisk RAMDISK 240000 ~
Partitions.WriteMBR RAMDISK#0 OBEMBR.Bin ~
Partitions.Create RAMDISK#1 12 1000 ~
Partitions.Format RAMDISK#1 FatFS  ~
FSTools.Mount WINA2 FatFS RAMDISK#1 ~

System.Ln ~ System.Show Create WinA2 directory structure... ~
FSTools.CreateDirectory WINA2:/WinA2Mini64 ~
FSTools.CreateDirectory WINA2:/WinA2Mini64/bin ~
FSTools.CreateDirectory WINA2:/WinA2Mini64/source ~
FSTools.CreateDirectory WINA2:/WinA2Mini64/data ~
FSTools.CreateDirectory WINA2:/WinA2Mini64/fonts ~
FSTools.CreateDirectory WINA2:/WinA2Mini64/work ~
System.Show Done. ~ System.Ln ~

System.Ln ~ System.Show Create build directory and build WinA2... ~ System.Ln ~
Release.Build
	--path="WINA2:/WinA2Mini64/bin/" --build --zip --zipMethod=0
	--exclude="Applications GuiApplications Education EFI Fun Testing Contributions Oberon OberonGadgets OberonApplications OberonDocumentation OberonVoyager OberonAnts CjkFonts Pr3Fonts Pr6Fonts"
	Win64
~

System.Ln ~ System.Show Extracting data ... ~ System.Ln ~
ZipTool.ExtractAll --prefix=WINA2:/WinA2Mini64/data/ --sourcePath=WINA2:/WinA2Mini64/bin/ --overwrite -d --silent
	ApplicationsMini.zip Build.zip Compiler.zip Drivers.zip GuiApplicationsMini.zip
	Kernel.zip System.zip
~

System.Ln ~ System.Show Removing object files from data folder... ~ System.Ln ~
FSTools.DeleteFiles --silent WINA2:/WinA2Mini64/data/*.GofWw ~
FSTools.DeleteFiles --silent WINA2:/WinA2Mini64/data/*.SymWw ~

System.Ln ~ System.Show Extracting sources ... ~ System.Ln ~
ZipTool.ExtractAll --prefix=WINA2:/WinA2Mini64/source/ --sourcePath=WINA2:/WinA2Mini64/bin/ --overwrite -d --silent
	ApplicationsMiniSrc.zip BuildSrc.zip CompilerSrc.zip DriversSrc.zip GuiApplicationsMiniSrc.zip
	KernelSrc.zip SystemSrc.zip
~
System.Ln ~ System.Show Extracting  fonts ... ~ System.Ln ~
ZipTool.ExtractAll --prefix=WINA2:/WinA2Mini64/fonts/ --sourcePath=WINA2:/WinA2Mini64/bin/ --overwrite -d --silent
	ScreenFonts.zip TrueTypeFonts.zip
~

System.Ln ~ System.Show Delete ZIP archives from work folder... ~ System.Ln ~
FSTools.DeleteFiles --silent WINA2:/WinA2Mini64/bin/*.zip ~

FSTools.CopyFiles WINA2:/WinA2Mini64/data/cjkfont.bfnt => WINA2:/WinA2Mini64/fonts/cjkfont.bfnt ~
FSTools.DeleteFiles WINA2:/WinA2Mini64/data/cjkfont.bfnt ~

System.Ln ~ System.Show Generate menu pages... ~ System.Ln ~

FSTools.DeleteFiles --silent WINA2:/WinA2Mini64/data/MenuPage*.XML ~

MenuPages.Generate WINA2:/WinA2Mini64/data/MenuPage00.XML Docu
	Tutorial "Notepad.Open Tutorial.Text"
	ChineseTutorial "Notepad.Open cn.PrgInOberon.txt"
~
MenuPages.Generate WINA2:/WinA2Mini64/data/MenuPage10.XML System
	Configuration "PET.Open Configuration.XML"
	Log WMKernelLog.Open
	Macros "PET.Open Macros.XML"
	HotKeys "PET.Open HotKeys.XML"
	Clock WMClock.Open
	Calendar WMCalendar.Open
	"Save Desktop" "WMRestorable.Store Auto.dsk;SkinEngine.SetCurrentAsDefault;StartMenu.ClosePopup"
	" " " "
	Reboot "System.Reboot" 0FF000080H 0FF0000FFH
	Shutdown "System.PowerDown" 0FF000080H 0FF0000FFH
~
MenuPages.Generate WINA2:/WinA2Mini64/data/MenuPage20.XML Files
	Files WMFileManager.Open
~
MenuPages.Generate WINA2:/WinA2Mini64/data/MenuPage30.XML Tools
	Search WMSearchTool.Open
	Archiver WMArchives.Open
	FTP WMFTPClient.Open
	Terminal WMV24Component.Open
	Console WMShell.Open
	SSH SSHClient.Open
~
MenuPages.Generate WINA2:/WinA2Mini64/data/MenuPage40.XML Edit
	Text Notepad.Open
	Styles "WMTextTool.Open;StartMenu.ClosePopup"
	"Input Methods" "WMInputMethodTool.Open;StartMenu.ClosePopup"
	"Unicode Markers" "WMUnicodeMarkerTool.Open;StartMenu.ClosePopup"
	"Unicode Map" WMCharMap.Open
~
MenuPages.Generate WINA2:/WinA2Mini64/data/MenuPage50.XML Develop
	IDE PET.Open
	" " " "
	Rebuild "PET.Open Windows.BuildMini64.Tool"
~

MenuPages.Generate WINA2:/WinA2Mini64/data/MenuPage60.XML Apps
~

MenuPages.Generate WINA2:/WinA2Mini64/data/MenuPage70.XML Inspect
	Objects WMObjectTracker.Open
	Profiler WMProfiler.Open
	TCPTraffic WMTCPTracker.Open
	Events WMEventLog.Open
~

MenuPages.Generate WINA2:/WinA2Mini64/data/MenuPage80.XML Demos
~

MenuPages.Generate WINA2:/WinA2Mini64/data/MenuPage90.XML Looks
~

System.Ln ~ System.Show Copy content to WinA2 folder... ~ System.Ln ~
FSTools.CopyFiles
	license.txt => WINA2:/WinA2Mini64/license.txt
~
System.Show Linking A2.exe ... ~ System.Ln ~
Linker.Link --path=WINA2:/WinA2Mini64/bin/ --fileFormat=PE64 --fileName=WINA2:/WinA2Mini64/A2.exe --extension=GofWw --displacement=401000H
	Builtins Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands Files WinFS Clock Dates Reals Strings
	Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection Loader BootConsole ~		

FSTools.CreateFile -c -r WINA2:/WinA2Mini64/work/Auto.dsk
<Desktop>
	<Window name="WMKernelLog" loader="WMKernelLog.Restore" l="12" t="96" r="652" b="516" flags="{0..2}"/>
	<Window name="FileManager" loader="WMFileManager.Restore" l="678" t="98" r="1496" b="765" flags="{0..2}"/>
</Desktop>
~

FSTools.CreateFile -c -r WINA2:/WinA2Mini64/aosg.ini
	[Configuration]
	Paths.Search=work;bin;source;data;fonts;
	Paths.Work = Work
	Oberon = Oberon.Text
	Boot  = Traps.Install
	Boot1 = FileTrapWriter.Install
	Boot2 = Display.Install  --fullscreen
	Boot3 = WindowManager.Install
	Boot4 = Clipboard.Install
	Boot5 = FSTools.Mount WORK RelativeFileSystem ./
	Boot7 = Autostart.Run
	Boot8 = Heaps.SetMetaData
	Boot9 = Kernel.GC
	ObjectFileExtension=.GofWw
	Trace=File
	TraceModules=0
	TraceCommands=1
	TraceBoot=0
	EnableReturnBlocks=0
	EnableFreeLists=0
~

FSTools.DeleteFiles -i WinA2Mini64.zip ~

System.Ln ~ System.Show Creating archive WinA2Mini64.zip... WAIT, PLEASE! ~

FSTools.Enumerate -s WINA2:/WinA2Mini64/*.*
	ZipTool.Add -r --silent  WinA2Mini64.zip <#filename#>
~
System.Ln ~ System.Show Done ~ System.Ln ~

FSTools.Unmount WINA2 ~
VirtualDisks.Uninstall RAMDISK ~

System.Show Time elapsed: ~ System.Ln ~
System.Timer elapsed ~ System.Ln ~

~~~~


