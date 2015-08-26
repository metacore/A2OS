MODULE DisplayLinear;

IMPORT CPU, Machine, Displays, Plugins;

CONST Width = 1024;
CONST Height = 768;
CONST Depth = 24;

CONST Mailbox = 3F00B880H; Base = 0H; Status = 18H; Write = 20H;

TYPE FrameBuffer = RECORD
	width, height: SIZE;
	virtualWidth, virtualHeight: SIZE;
	pitch: SIZE;
	depth: SIZE;
	xOffset, yOffset: SIZE;
	address: ADDRESS;
	size: SIZE;
	cmap: ARRAY 256 OF SHORTINT;
END;

VAR display: Displays.Display;
VAR frameBuffer {ALIGNED (16)}: FrameBuffer; 

PROCEDURE Send (channel: SIZE; value: WORD);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	WHILE 31 IN CPU.ReadMask (Mailbox + Status) DO END;
	CPU.WriteWord (Mailbox + Write, value + channel);
END Send;

PROCEDURE Receive (channel: SIZE): WORD;
VAR value: WORD;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	REPEAT
		WHILE 30 IN CPU.ReadMask (Mailbox + Status) DO END;
		value := CPU.ReadWord (Mailbox + Base);
	UNTIL value MOD 16 = channel;
	RETURN value DIV 16 * 16;
END Receive;

PROCEDURE Install*;
END Install;

PROCEDURE Initialize;
VAR result: LONGINT;
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

	REPEAT
		Send (1, ADDRESS OF frameBuffer + 40000000H);
		result := Receive (1);
	UNTIL (result = 0) & (frameBuffer.address # NIL);

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
