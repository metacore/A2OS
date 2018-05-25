

FSTools.Mount ZBL RelativeFileSystem HDCT/zbl~

Compiler.Compile -p=Win32

TFTPServer.Mod
ZBL:/tools/OEBInterfaces.Mod
ZBL:/tools/OEBLoopbackInterfaces.Mod
ZBL:/tools/OEBSerialInterfaces.Mod
ZBL:/tools/OEBUdpInterfaces.Mod
ZBL:/tools/OEBServers.Mod
ZBL:/tools/OEBInteractiveServers.Mod
ZBL:/tools/OEBAutoServers.Mod
ZBL:/tools/OEB.Mod
~