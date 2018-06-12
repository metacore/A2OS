MODULE TestDMA;

IMPORT SYSTEM, Trace, Machine, Kernel, Random, DMA, MT := MatrixTools, Timer;
CONST
	Size = 64 * 256;

VAR
	g: Random.Generator;
	w: DMA.Writer;
	r: DMA.Reader;
	src, dst: POINTER TO ARRAY Size + 8 OF CHAR;
	(*src, dst: POINTER TO ARRAY Size OF LONGINT;*)
	interm: ARRAY Size OF LONGINT;
	t: Kernel.MilliTimer;
	pOut, pIn: ADDRESS;
	count, burst, i, len, time: LONGINT;

	PROCEDURE Align (address: ADDRESS; align: LONGINT): LONGINT;
	VAR
	BEGIN
		IF align = 8 THEN
			RETURN 8 - address MOD 8
		ELSE
			RETURN 8 - address MOD 8 + align
		END
	END Align;

BEGIN
	burst := 64;
	pOut := 7F000000H;
	pIn := pOut + 8;

	NEW(g);
	NEW(src);
	NEW(dst);

	DMA.OpenWriter(w, Size, burst, pOut, FALSE, 0);
	DMA.OpenReader(r, Size, burst, pIn, FALSE, 1);


		(*SYSTEM.PUT(MT.AxiBaseAddr0 +1*MT.ChanOffset, 0);  (* reset the timer *)
		dmaOut.Update;
		SYSTEM.PUT(MT.AxiBaseAddr0 +1*MT.ChanOffset, 1); (* sample the timer *)
		SYSTEM.GET(MT.AxiBaseAddr0 + 1*MT.ChanOffset+MT.DataOffset, t); (* read timer data*)*)

	FOR i := 0 TO LEN(src) - 1 DO src[i] := CHR(g.Dice(100H)) END;

	(*Kernel.SetTimer(t, 1000);*)
	Timer.Tick;
	w.Bytes(src^, 0, Size);
	(*time := Kernel.Elapsed(t);*)
	(*FOR i := 0 TO Size - 1 BY 4 DO
		interm[i] :=  ORD(src[i]) + (ORD(src[i + 1])) * 100H + ORD(src[i + 2]) * 10000H + (ORD(src[i + 3])) * 1000000H;
		SYSTEM.PUT(pOut, interm[i])
	END;*)

	(*FOR i := 0 TO Size - 1 BY 4 DO
		len := SYSTEM.GET32(pIn);
		dst[i] := CHR(len MOD 100H);
		dst[i + 1] := CHR((len DIV 100H) MOD 100H);
		dst[i + 2] := CHR((len DIV 10000H) MOD 100H);
		dst[i + 3] := CHR((len DIV 1000000H) MOD 100H)
	END;*)
	r.Bytes(dst^, 0, Size, len);
	Timer.Tock(time);
	TRACE(time);
	len := SYSTEM.GET32(pOut);
	TRACE(len);

	count := 0;
	FOR i := 0 TO Size - 1 DO
		(*Trace.String("elt "); Trace.Int(i, 4);
		Trace.String("	");
		Trace.Hex(ORD(src[i]), -2);
		Trace.String("	");
		Trace.Hex(ORD(dst[i]), -2);
		Trace.String("	");
		Trace.Boolean(src[i] = dst[i]);
		Trace.Ln;*)
		IF src[i] # dst[i] THEN INC(count) END;
	END;
	Trace.String(" => Differences: "); Trace.Int(count, 0); Trace.String("/"); Trace.Int(Size, 0); Trace.Ln

	(*FOR i := 0 TO LEN(src) - 1 DO src[i] := g.Integer() END;

	(*w.Bytes(src^, 0, Size);*)
	FOR i := 0 TO Size - 1 DO
		SYSTEM.PUT32(pOut, src[i])
	END;
	(*r.Bytes(dst^, 0, Size, len);*)
	FOR i := 0 TO Size - 1 DO
		dst[i] := SYSTEM.GET32(pIn);
	END;

	count := 0;
	FOR i := 0 TO Size - 1 DO
		Trace.String("elt "); Trace.Int(i, 4); Trace.Ln;
		Trace.String("	");
		Trace.Hex(src[i], -8); Trace.Ln;
		Trace.String("	");
		Trace.Hex(dst[i], -8); Trace.Ln;
		Trace.String("	");
		Trace.Boolean(src[i] = dst[i]);
		Trace.Ln;
		IF src[i] # dst[i] THEN INC(count) END;
	END;
	Trace.String(" => Differences: "); Trace.Int(count, 0); Trace.String("/"); Trace.Int(Size, 0); Trace.Ln*)
END TestDMA.

Compiler.Compile -b=ARM --traceModule=Trace --objectFile=Generic  --initLocals
	basel/ARM.A2/ARM.Streams.Mod 
	basel/ARM.A2/ARM.Math.Mod
	Random.Mod
	basel/ARM.A2/DMA330.Mod
	Timer.Mod
	basel/ARM.A2/Zynq.DMA.Mod
	Locks.Mod
	Zynq.MatrixTools.Mod
	TestDMA2.Mod
~

StaticLinker.Link --fileName=Test.Bin --displacement=100000H -a
	Initializer Runtime Platform FPE64 ARMRuntime Trace Uart Machine
	Heaps Modules Objects Kernel
	Streams KernelLog
	Math Random Locks
	Timer
	DMA330 DMA
	MatrixTools
	TestDMA
~

