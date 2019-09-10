MODULE UsbVarTdAllocTest; (** AUTHOR "Timothée Martiel"; PURPOSE "Testing for UsbTdAllocator"; *)

IMPORT Kernel, Commands, UsbVarTdAlloc;

CONST
	Nb = 1024 * 32;

	(**
	 * Measure average allocation and freeing speed for the size 16.
	 * Usage:
	 * 		UsbTdAllocatorTest.Benchmark {size} ~
	 *)
	PROCEDURE Benchmark * (context: Commands.Context);
	VAR
		tds: ARRAY Nb OF ADDRESS;
		t: Kernel.MilliTimer;
		alloc: UsbVarTdAlloc.Allocator;
		i, size, time: SIGNED32;
	BEGIN
		NEW(alloc, 4096, 32);
		context.out.String("Page Size:	  4096");
		context.out.Ln;
		context.out.String("Block Size:	    32");
		context.out.Ln;
		context.out.String("Repetitions: ");
		context.out.Int(Nb, 0);
		context.out.Ln;
		FOR size := 128 TO 32 BY -32 DO
			context.out.String("TD Size = ");
			context.out.Int(size, 0);
			context.out.Ln;
			context.out.String("Allocating TDs");
			Kernel.SetTimer(t, 30000);
			FOR i := 0 TO Nb - 1 DO
				tds[i] := alloc.Allocate(size);
			END;
			time := Kernel.Elapsed(t);
			context.out.String("... done");
			context.out.Ln;
			context.out.String("elapsed time: ");
			context.out.Int(time, 0);
			context.out.Ln;
			context.out.Update;

			context.out.String("Freeing TDs");

			Kernel.SetTimer(t, 30000);
			FOR i := 0 TO Nb - 1 DO
				alloc.Free(tds[i], size);
			END;
			time := Kernel.Elapsed(t);
			context.out.String("... done");
			context.out.Ln;
			context.out.String("elapsed time: ");
			context.out.Int(time, 0);
			context.out.Ln;
			context.out.Update
		END
	END Benchmark;

	(**
	 * Measure average allocation and freeing speed for the size 16.
	 * Usage:
	 * 		UsbTdAllocatorTest.Benchmark {size} ~
	 *)
	PROCEDURE Test * (context: Commands.Context);
	VAR
		tds: ARRAY Nb OF ADDRESS;
		t: Kernel.MilliTimer;
		alloc: UsbVarTdAlloc.Allocator;
		i, size, time: SIGNED32;
	BEGIN
		NEW(alloc, 4096, 32);
		context.out.String("Page Size:	  4096");
		context.out.Ln;
		context.out.String("Block Size:	    32");
		context.out.Ln;
		context.out.String("Repetitions: ");
		context.out.Int(Nb, 0);
		context.out.Ln;
		FOR size := 128 TO 32 BY -32 DO
			context.out.String("TD Size = ");
			context.out.Int(size, 0);
			context.out.Ln;
			context.out.String("Allocating TDs");
			Kernel.SetTimer(t, 30000);
			FOR i := 0 TO Nb - 1 DO
				tds[i] := alloc.Allocate(size);
				ASSERT(tds[i] MOD 32 = 0);
			END;
			time := Kernel.Elapsed(t);
			context.out.String("... done");
			context.out.Ln;
			context.out.String("elapsed time: ");
			context.out.Int(time, 0);
			context.out.Ln;
			context.out.Update;

			context.out.String("Freeing TDs");

			Kernel.SetTimer(t, 30000);
			FOR i := 0 TO Nb - 1 DO
				alloc.Free(tds[i], size);
			END;
			time := Kernel.Elapsed(t);
			context.out.String("... done");
			context.out.Ln;
			context.out.String("elapsed time: ");
			context.out.Int(time, 0);
			context.out.Ln;
			context.out.Update
		END
	END Test;
END UsbVarTdAllocTest.

UsbVarTdAllocTest.Benchmark ~
UsbVarTdAllocTest.Test ~
SystemTools.Free UsbVarTdAllocTest UsbVarTdAlloc ~
Compiler.Compile -b=AMD
	basel/USB/UsbVarTdAlloc.Mod
	basel/USB/UsbVarTdAllocTest.Mod
~