MODULE UsbTdAllocatorTest; (** AUTHOR "Timothée Martiel"; PURPOSE "Testing for UsbTdAllocator"; *)

IMPORT Kernel, Commands, UsbVarTdAlloc;

CONST
	Nb = 1024 * 1;
	Size = 32 * 32;

	(**
	 * Measure average allocation and freeing speed for the size 16.
	 * Usage:
	 * 		UsbTdAllocatorTest.Benchmark size ~
	 *)
	PROCEDURE Benchmark * (context: Commands.Context);
	VAR
		tds: ARRAY Nb OF ADDRESS;
		t: Kernel.MilliTimer;
		alloc: UsbVarTdAlloc.Allocator;
		i, size, time: LONGINT;
	BEGIN
		context.out.String("Repetitions: ");
		context.out.Int(Nb, 0);
		context.out.Ln;
		context.out.Update;

		NEW(alloc, 4096, 32);
		context.out.String("Allocating TDs");
		size := 64;

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
	END Benchmark;

	PROCEDURE Test * (context: Commands.Context);
	BEGIN
		context.out.String("Test command");
		context.out.Ln;
		context.out.Update
	END Test;
END UsbTdAllocatorTest.

UsbTdAllocatorTest.Benchmark ~
SystemTools.Free UsbTdAllocatorTest UsbTdAllocator ~
Compiler.Compile -b=ARM --objectFile=Generic --newObjectFile --traceModule=Trace --mergeSections
	basel/USB/UsbVarTdAlloc.Mod
	basel/USB/UsbTdAllocatorTest.Mod
~