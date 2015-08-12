MODULE DisplayLinear;

IMPORT CPU, Displays, Plugins;

CONST Width = 1024;
CONST Height = 768;
CONST Depth = 24;

CONST Mailbox = 2000B880H;

TYPE FrameBuffer = RECORD
	width, height: SIZE;
	virtualWidth, virtualHeight: SIZE;
	pitch: SIZE;
	depth: SIZE;
	xOffset, yOffset: SIZE;
	address: ADDRESS;
	size: SIZE;
END;

VAR display: Displays.Display;

PROCEDURE Send (channel: SIZE; value: WORD);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	WHILE 31 IN CPU.ReadMask (Mailbox + 18H) DO END;
	CPU.WriteWord (Mailbox + 20H, value + channel);
	WHILE 31 IN CPU.ReadMask (Mailbox + 18H) DO END;
END Send;

PROCEDURE Receive (channel: SIZE): WORD;
VAR value: WORD;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	REPEAT
		WHILE 30 IN CPU.ReadMask (Mailbox + 18H) DO END;
		value := CPU.ReadWord (Mailbox + 00H);
	UNTIL value MOD 16 = channel;
	RETURN value DIV 16 * 16;
VAR frameBuffer: FrameBuffer; result: LONGINT;
BEGIN
	frameBuffer.width := Width;
	frameBuffer.height := Height;
	frameBuffer.depth := Depth;
	frameBuffer.virtualWidth := frameBuffer.width;
	frameBuffer.virtualHeight := frameBuffer.height;
	frameBuffer.pitch := 0;
	frameBuffer.xOffset := 0;
	frameBuffer.yOffset := 0;
	frameBuffer.address := NIL;
	frameBuffer.size := 0;
	Send (1, ADDRESS OF frameBuffer + 40000000H);
	ASSERT (Receive(1) = 0);
	Machine.Fill32(frameBuffer.address, frameBuffer.size, 0);

	NEW(display);
	display.width := frameBuffer.width;
	display.height := frameBuffer.height;
	display.offscreen := 0;
	display.format := frameBuffer.depth DIV 8;
	display.unit := 10000;
	display.InitFrameBuffer(frameBuffer.address, frameBuffer.size, frameBuffer.width * frameBuffer.depth DIV 8 + frameBuffer.pitch);
	display.desc := "Linear framebuffer driver for Raspberry Pi";
	Displays.registry.Add(display, result);
	ASSERT(result = Plugins.Ok);
END Receive;

PROCEDURE Install*;
END Install;

PROCEDURE Initialize;
VAR frameBuffer: FrameBuffer; result: LONGINT;
BEGIN
	frameBuffer.width := Width;
	frameBuffer.height := Height;
	frameBuffer.depth := Depth;
	frameBuffer.virtualWidth := frameBuffer.width;
	frameBuffer.virtualHeight := frameBuffer.height;
	frameBuffer.pitch := 0;
	frameBuffer.xOffset := 0;
	frameBuffer.yOffset := 0;
	frameBuffer.address := NIL;
	frameBuffer.size := 0;
	Send (1, ADDRESS OF frameBuffer + 40000000H);
	ASSERT (Receive(1) = 0);
	Machine.Fill32(frameBuffer.address, frameBuffer.size, 0);

	NEW(display);
	display.width := frameBuffer.width;
	display.height := frameBuffer.height;
	display.offscreen := 0;
	display.format := frameBuffer.depth DIV 8;
	display.unit := 10000;
	display.InitFrameBuffer(frameBuffer.address, frameBuffer.size, frameBuffer.width * frameBuffer.depth DIV 8 + frameBuffer.pitch);
	display.desc := "Linear framebuffer driver for Raspberry Pi";
	Displays.registry.Add(display, result);
	ASSERT(result = Plugins.Ok);
END Initialize;

BEGIN
	Initialize;
END DisplayLinear.
