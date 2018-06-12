MODULE TestDMA;

IMPORT Trace, Machine, Random, DMA;
VAR
	g: Random.Generator;
	w: DMA.Writer;
	r: DMA.Reader;
	src, dst: POINTER TO ARRAY 2048 + 16 OF CHAR;
	len, size, burst, i, srcOfs, dstOfs: LONGINT;
	errors, ovf1, ovf2: BOOLEAN;

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
	size := 1024;
	burst := 64;
	NEW(g);
	NEW(src);
	NEW(dst);

	srcOfs := Align(ADDRESSOF(src[0]), 8);
	(*dstOfs := Align(ADDRESSOF(dst[0]), 8);*)

	(*FOR srcOfs := 0 TO 7 DO*)
		FOR dstOfs := 0 TO 7 DO
			Trace.String(":: Transfer:	"); Trace.Address(ADDRESSOF(src[srcOfs]));
			Trace.String(" => "); Trace.Address(ADDRESSOF(dst[dstOfs])); Trace.Ln;
			Trace.String(" => src ofs:	"); Trace.Int(srcOfs, 0); Trace.Ln;
			Trace.String(" => dst ofs:	"); Trace.Int(dstOfs, 0); Trace.Ln;

			FOR i := 0 TO LEN(src) - 1 DO src[i] := CHR(g.Dice(100H)) END;
			FOR i := 0 TO LEN(dst) - 1 DO dst[i] := 0X END;
			Machine.FlushDCacheRange(ADDRESSOF(src[0]), LEN(src));
			Machine.FlushDCacheRange(ADDRESSOF(dst[0]), LEN(dst));

			(*DMA.OpenWriter(w, size, burst, ADDRESSOF(dst[dstOfs]), TRUE);
			w.Bytes(src^, srcOfs, size);*)
			DMA.OpenReader(r, size, burst, ADDRESSOF(src[srcOfs]), TRUE);
			r.Bytes(dst^, dstOfs, size, len);
			(*DMA.controller.channels[0].Await;*)

			Machine.InvalidateDCacheRange(ADDRESSOF(dst[0]), LEN(dst));

			errors := FALSE;
			FOR i := 0 TO size - 1 DO
				IF src[i + srcOfs] # dst[i + dstOfs] THEN
					IF ~errors THEN
						errors:= TRUE;
						Trace.StringLn(" -> FOUND TRANSFER ERROR:");
					END;
					Trace.String("	Difference:	"); Trace.Int(i, 3); Trace.String("	"); Trace.Hex(ORD(src[i + srcOfs]), -2); Trace.String("	"); Trace.Hex(ORD(dst[i + dstOfs]), -2); Trace.Ln
				END
			END;

			ovf1 := FALSE;
			FOR i := 0 TO dstOfs - 1 DO
				IF dst[i] # 0X THEN
					IF ~ovf1 THEN
						ovf1 := TRUE;
						Trace.StringLn(" -> FOUND TRANSFER OVERFLOW:")
					END;
					Trace.String("	pos, val:	"); Trace.Int(i, 3); Trace.String("	"); Trace.Hex(ORD(dst[i]), -2); Trace.Ln
				END
			END;

			ovf2 := FALSE;
			FOR i := dstOfs + size TO LEN(dst) - 1 DO
				IF dst[i] # 0X THEN
					IF ~ovf2 THEN
						ovf2 := TRUE;
						Trace.StringLn(" -> FOUND TRANSFER OVERFLOW:")
					END;
					Trace.String("	pos, val:	"); Trace.Int(i, 3); Trace.String("	"); Trace.Hex(ORD(dst[i]), -2); Trace.Ln
				END
			END;
			IF ~(errors OR ovf1 OR ovf2) THEN
				Trace.StringLn(" -> NO ERROR FOUND")
			END;
			Trace.Ln
		END
	(*END*)
END TestDMA.

Compiler.Compile -b=ARM --traceModule=Trace --objectFile=Generic --initLocals
	Timothee/ARM.A2/ARM.Streams.Mod 
	Timothee/ARM.A2/ARM.Math.Mod
	Random.Mod
	Timothee/ARM.A2/DMA330.Mod
	Timothee/ARM.A2/Zynq.DMA.Mod
	Timothee/ARM.A2/TestDMA.Mod
~

StaticLinker.Link --fileName=Test.Bin --displacement=100000H -a
	Initializer Runtime Platform FPE64 ARMRuntime Trace Uart Machine
	Heaps Modules Objects Kernel
	Streams
	Math Random
	DMA330 DMA
	TestDMA
~

