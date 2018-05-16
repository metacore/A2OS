# 1)
Compiler.Compile  Streams64.Mod Files64.Mod Win32.HostFiles64.Mod RelativeFiles64.Mod FSTools64.Mod ~

# 2)
# WINAOS generic
	StaticLinker.Link --fileFormat=PE32 --fileName=A2.exe --extension=GofW --displacement=401000H  Runtime Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Streams64 Commands Files Files64 WinFS HostFiles64 Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection  GenericLoader  BootConsole ~
# 	Command line shell:
	StaticLinker.Link  --fileFormat=PE32CUI --fileName=oberon.exe --extension=GofW --displacement=401000H Runtime Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Streams64 Commands Files  Files64 WinFS HostFiles64 Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection GenericLoader WinTrace StdIO  Traps RelativeFileSystem WMDefaultFont SystemTools StdIOShell ~

# 3)
Edit Configuration.XML :
- ADD: 	<Setting name="RelativeFiles64" value="NIL;RelativeFiles64.NewFS"/> into <Section name="Files">

# 4)
Edit aosg.ini
- ADD ( for exaple ): Boot6 = FSTools64.Mount WORK RelativeFiles64 ./
