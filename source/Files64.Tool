# 1)
Compiler.Compile  Streams64.Mod Files64.Mod Windows.HostFiles64.Mod RelativeFiles64.Mod FSTools64.Mod ~

# 2)
# WINAOS generic
	Linker.Link --fileFormat=PE32 --fileName=A2.exe --extension=GofW --displacement=401000H  Builtins Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Streams64 Commands Files Files64 WinFS HostFiles64 Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection  Loader  BootConsole ~
# 	Command line shell:
	Linker.Link  --fileFormat=PE32CUI --fileName=oberon.exe --extension=GofW --displacement=401000H Builtins Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Streams64 Commands Files  Files64 WinFS HostFiles64 Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection Loader WinTrace StdIO  Traps RelativeFileSystem WMDefaultFont System StdIOShell ~

# 3)
Edit Configuration.XML :
- ADD: 	<Setting name="RelativeFiles64" value="NIL;RelativeFiles64.NewFS"/> into <Section name="Files">

# 4)
Edit aosg.ini
- ADD ( for exaple ): Boot6 = FSTools64.Mount WORK RelativeFiles64 ./
