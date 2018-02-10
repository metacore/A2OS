Compiler.Compile -p=Win32G Streams64.Mod Files64.Mod Win32.WinFiles64.Mod RelativeFiles64.Mod FSTools64.Mod ~

# WINAOS generic
	StaticLinker.Link --fileFormat=PE32 --fileName=A2.exe --extension=GofW --displacement=401000H  Runtime Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Streams64 Commands Files Files64 WinFS WinFiles64 Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection  GenericLoader  BootConsole ~
# 	Command line shell:
	StaticLinker.Link  --fileFormat=PE32CUI --fileName=oberon.exe --extension=GofW --displacement=401000H Runtime Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Streams64 Commands Files  Files64 WinFS WinFiles64 Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection GenericLoader WinTrace StdIO  Traps RelativeFileSystem WMDefaultFont SystemTools StdIOShell ~
