MODULE Test; (** AUTHOR "Timothée Martiel"; PURPOSE "DMA Automatic tests. Require FIFO on PL."; *)

IMPORT Trace, Machine, Kernel, KernelLog, Strings, Random, PsConfig, AcAxisIo, DMA330ProgramWriter;

CONST
	Busy = -1;
	Passed = 0;
	Failed = 1;
	Error = 2;
	Timeout = 3;

	MaxTests = 128;

TYPE
	Test = PROCEDURE (param: ANY): BOOLEAN;

	Trigger = OBJECT
	VAR
		timer: Kernel.Timer;
		timeout: LONGINT;
		status *: LONGINT;

		PROCEDURE & InitTrigger;
		BEGIN
			NEW(timer)
		END InitTrigger;

		PROCEDURE Start * (timeout: LONGINT);
		BEGIN {EXCLUSIVE}
			SELF.timeout := timeout;
			status := Busy
		END Start;

		PROCEDURE SetStatus * (status: LONGINT);
		BEGIN {EXCLUSIVE}
			SELF.status := status
		END SetStatus;

		PROCEDURE Trigger * (): LONGINT;
		BEGIN {EXCLUSIVE}
			AWAIT(status # Busy);
			RETURN status
		END Trigger;

	BEGIN {ACTIVE}
		LOOP
			BEGIN {EXCLUSIVE} AWAIT(status = Busy) END;
			IF timeout # 0 THEN
				timer.Sleep(timeout);
				BEGIN {EXCLUSIVE} status := Timeout END
			ELSE
				BEGIN {EXCLUSIVE} AWAIT(status # Busy) END
			END
		END
	END Trigger;

	Tester = OBJECT (Trigger)
	VAR
		test: LONGINT;

		PROCEDURE Execute;
		BEGIN
			FOR test := 0 TO testNb - 1 DO ExecuteTest(30000) END
		END Execute;

		PROCEDURE ExecuteTest(timeout: LONGINT);
		BEGIN
			KernelLog.String("========== Begin test "); KernelLog.String(names[test]); KernelLog.String(" =========="); KernelLog.Ln;
			(*Start(timeout);*)
			results[test] := Trigger();
			ResetPl;
			KernelLog.String("########### End test "); KernelLog.String(names[test]); KernelLog.String(" ###########"); KernelLog.Ln
		END ExecuteTest;

		PROCEDURE DoTest;
		BEGIN
			IF tests[test](params[test]) THEN
				SetStatus(Passed)
			ELSE
				SetStatus(Failed)
			END
		FINALLY
			SetStatus(Error)
		END DoTest;

	BEGIN {ACTIVE}
		LOOP
			BEGIN {EXCLUSIVE} AWAIT(status = Busy) END;
			DoTest
		END
	END Tester;

	Notifier = OBJECT
	VAR
		params: ANY;
		count, result: LONGINT;

		PROCEDURE Await(param: ANY): LONGINT;
		BEGIN {EXCLUSIVE}
			AWAIT((count = 1)); (* & ((param = NIL) OR (param = params)));*)
			(*TRACE('notified', count);*)
			DEC(count);
			RETURN result
		END Await;

		PROCEDURE Notify (status: LONGINT; param: ANY);
		BEGIN {EXCLUSIVE}
			result := status;
			params := param;
			INC(count)
			(*;TRACE('notifying', count)*)
		END Notify;
	(*BEGIN {ACTIVE}
		BEGIN {EXCLUSIVE} done := TRUE END;
		LOOP
			BEGIN {EXCLUSIVE} AWAIT(~done) END;
			LOOP
				TRACE(output.ready, input.available)
			END
		END*)
	END Notifier;

	ChannelId = POINTER TO RECORD channel: LONGINT END;
	MemToMemParams = POINTER TO MemToMemDesc;
	MemToMemDesc = RECORD
		size, alignment: LONGINT;
	END;

VAR
	tests: ARRAY MaxTests OF Test;
	params: ARRAY MaxTests OF ANY;
	names: ARRAY MaxTests, 128 OF CHAR;
	results: ARRAY MaxTests OF LONGINT;
	testNb: LONGINT;
	notifier: Notifier;
	rng: Random.Generator;
	parameter: MemToMemParams;
	output: AcAxisIo.Output;
	input: AcAxisIo.Input;
	freq: HUGEINT;
	res: LONGINT;

	PROCEDURE Execute *;
	VAR
		tester: Tester;
		i, len, total, passed, failed, errors, test: LONGINT;
	BEGIN
		(* display width *)
		len := 80;
		KernelLog.String("Executing DMA tests...");
		KernelLog.Ln;
		NEW(tester);
		tester.Execute;
		KernelLog.String("done");
		KernelLog.Ln;
		KernelLog.String("Results:");
		KernelLog.Ln;

		FOR test := 0 TO testNb - 1 DO
			INC(total);
			KernelLog.String("    ");
			KernelLog.String(names[test]);
			FOR i := 8 + 7 TO len - Strings.Length(names[test]) - 1 DO
				KernelLog.Char(' ')
			END;
			CASE results[test] OF
				 Passed:
					INC(passed);
					KernelLog.String(" Passed")
				|Failed:
					INC(failed);
					KernelLog.String(" Failed")
				|Error:
					INC(errors);
					KernelLog.String("  Error")
				|Timeout:
					INC(errors);
					KernelLog.String ("Timeout")
			END;
			KernelLog.Ln;
		END;
		KernelLog.Ln;
		KernelLog.String("Summary:"); KernelLog.Ln;
		KernelLog.String("	total:	"); KernelLog.Int(total, 0); KernelLog.Ln;
		KernelLog.String("	passed:	"); KernelLog.Int(passed, 0); KernelLog.Char('/'); KernelLog.Int(total, 0); KernelLog.Ln;
		KernelLog.String("	failed:	"); KernelLog.Int(failed, 0); KernelLog.Char('/'); KernelLog.Int(total, 0); KernelLog.Ln;
		KernelLog.String("	error:	"); KernelLog.Int(errors, 0); KernelLog.Char('/'); KernelLog.Int(total, 0); KernelLog.Ln
	END Execute;

	PROCEDURE AddTest * (test: PROCEDURE (param: ANY): BOOLEAN; param: ANY; CONST name: ARRAY OF CHAR);
	BEGIN
		tests[testNb] := test;
		params[testNb] := param;
		COPY(name, names[testNb]);
		INC(testNb)
	END AddTest;

	PROCEDURE CheckMemToMem (CONST src: ARRAY OF CHAR; srcOfs: LONGINT; CONST dst: ARRAY OF CHAR; dstOfs, len: LONGINT): BOOLEAN;
	VAR
		i: LONGINT;
		result: BOOLEAN;
	BEGIN
		result := TRUE;
		FOR i := 0 TO dstOfs - 1 DO
			IF dst[i] # 0X THEN KernelLog.String("Overflow at "); KernelLog.Int(i, 0); KernelLog.Ln; result := FALSE END
		END;
		FOR i := 0 TO len - 1 DO
			IF dst[dstOfs + i] # src[srcOfs + i] THEN KernelLog.String("Mismatch at "); KernelLog.Int(i, 0); KernelLog.Ln; result := FALSE END
		END;
		FOR i := dstOfs + len TO LEN(dst) - 1 DO
			IF dst[i] # 0X THEN KernelLog.String("Overflow at "); KernelLog.Int(i, 0); KernelLog.Ln; result := FALSE END
		END;
		RETURN result
	END CheckMemToMem;

	PROCEDURE TestHeapToHeap (param: ANY): BOOLEAN;
	VAR
		tstart, tstop: HUGEINT;
		program: DMA330ProgramWriter.Program;
		txParams: MemToMemParams;
		src, dst: POINTER TO ARRAY OF CHAR;
		srcOfs, dstOfs: ADDRESS;
		i, status: LONGINT;
	BEGIN
		txParams := param(MemToMemParams);

		NEW(src, 2 * txParams.size + 2 * 8 (*txParams.alignment*));
		NEW(dst, 2 * txParams.size + 2 * 8 (*txParams.alignment*));

		srcOfs := (*txParams.alignment*)8 - ADDRESSOF(src[txParams.size DIV 2]) MOD (*txParams.alignment*) 8 + txParams.alignment;
		dstOfs := (*txParams.alignment*)8 - ADDRESSOF(dst[txParams.size DIV 2]) MOD (*txParams.alignment*) 8;

		FOR i := 0 TO LEN(src) - 1 DO
			src[i] := CHR(rng.Dice(100H))
		END;
		Machine.FlushDCacheRange(ADDRESSOF(src[0]), LEN(src));
		Machine.FlushDCacheRange(ADDRESSOF(dst[0]), LEN(dst));

		DMA330ProgramWriter.InitProgram(program);
		IF ~DMA330ProgramWriter.Generate(program, ADDRESSOF(src[srcOfs]), txParams.size, 0, ADDRESSOF(dst[dstOfs]), txParams.size, 0, txParams.size, status) THEN
			KernelLog.String("Error programming DMA: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		IF ~DMA330ProgramWriter.BindToChannel(program, 1, status) THEN
			KernelLog.String("Error binding DMA program to channel 0: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		tstart := Machine.GetTimer();
		IF ~DMA330ProgramWriter.Execute(program, notifier.Notify, NIL, status) THEN
			KernelLog.String("Error starting DMA program: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;
		status := notifier.Await(NIL);
		tstop := Machine.GetTimer();
		IF status # DMA330ProgramWriter.Ok THEN
			KernelLog.String("Error in DMA program execution: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;
		Machine.InvalidateDCacheRange(ADDRESSOF(dst[0]), LEN(dst));
		KernelLog.String("Total transfer time = "); KernelLog.Int(tstop - tstart, 0); KernelLog.Ln;

		RETURN CheckMemToMem(src^, srcOfs, dst^, dstOfs, txParams.size)
	END TestHeapToHeap;

	PROCEDURE TestStackToStack (param: ANY): BOOLEAN;
	CONST
		MaxTxSize = 4096;
		MaxAlign = 4096;
	VAR
		program: DMA330ProgramWriter.Program;
		txParams: MemToMemParams;
		src, dst: ARRAY MaxTxSize + MaxAlign OF CHAR;
		srcOfs, dstOfs: ADDRESS;
		i, status: LONGINT;
	BEGIN
		txParams := param(MemToMemParams);

		srcOfs := txParams.alignment - ADDRESSOF(src[0]) MOD txParams.alignment;
		dstOfs := txParams.alignment - ADDRESSOF(dst[0]) MOD txParams.alignment;

		FOR i := 0 TO LEN(src) - 1 DO
			src[i] := CHR(rng.Dice(100H))
		END;
		Machine.FlushDCacheRange(ADDRESSOF(src[0]), LEN(src));
		Machine.FlushDCacheRange(ADDRESSOF(dst[0]), LEN(dst));

		DMA330ProgramWriter.InitProgram(program);
		IF ~DMA330ProgramWriter.Generate(program, ADDRESSOF(src[srcOfs]), txParams.size, 0, ADDRESSOF(dst[dstOfs]), txParams.size, 0, txParams.size, status) THEN
			KernelLog.String("Error programming DMA: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		IF ~DMA330ProgramWriter.BindToChannel(program, 0, status) THEN
			KernelLog.String("Error binding DMA program to channel 0: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		IF ~DMA330ProgramWriter.Execute(program, notifier.Notify, NIL, status) THEN
			KernelLog.String("Error starting DMA program: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;
		status := notifier.Await(NIL);
		IF status # DMA330ProgramWriter.Ok THEN
			KernelLog.String("Error in DMA program execution: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;
		Machine.InvalidateDCacheRange(ADDRESSOF(dst[0]), LEN(dst));

		RETURN CheckMemToMem(src, srcOfs, dst, dstOfs, txParams.size)
	END TestStackToStack;

	PROCEDURE TestHeapSimultaneous (param: ANY): BOOLEAN;
	VAR
		program1, program2: DMA330ProgramWriter.Program;
		channel1, channel2: ChannelId;
		txParams: MemToMemParams;
		src1, src2, dst1, dst2: POINTER TO ARRAY OF CHAR;
		srcOfs1, srcOfs2, dstOfs1, dstOfs2: ADDRESS;
		i, status: LONGINT;
	BEGIN
		txParams := param(MemToMemParams);
		NEW(src1, txParams.size + txParams.alignment);
		NEW(dst1, txParams.size + txParams.alignment);
		NEW(src2, txParams.size + txParams.alignment);
		NEW(dst2, txParams.size + txParams.alignment);
		NEW(channel1);
		NEW(channel2);

		channel1.channel := 0;
		channel2.channel := 1;

		srcOfs1 := txParams.alignment - ADDRESSOF(src1[0]) MOD txParams.alignment;
		dstOfs1 := txParams.alignment - ADDRESSOF(dst1[0]) MOD txParams.alignment;
		srcOfs2 := txParams.alignment - ADDRESSOF(src2[0]) MOD txParams.alignment;
		dstOfs2 := txParams.alignment - ADDRESSOF(dst2[0]) MOD txParams.alignment;

		FOR i := 0 TO LEN(src1) - 1 DO
			src1[i] := CHR(rng.Dice(100H))
		END;
		FOR i := 0 TO LEN(src2) - 1 DO
			src2[i] := CHR(rng.Dice(100H))
		END;
		Machine.FlushDCacheRange(ADDRESSOF(src1[0]), LEN(src1));
		Machine.FlushDCacheRange(ADDRESSOF(dst1[0]), LEN(dst1));
		Machine.FlushDCacheRange(ADDRESSOF(src2[0]), LEN(src2));
		Machine.FlushDCacheRange(ADDRESSOF(dst2[0]), LEN(dst2));

		DMA330ProgramWriter.InitProgram(program1);
		IF ~DMA330ProgramWriter.SetBurstParameters(program1, 16, 4, status) THEN
			KernelLog.String("Error setting burst parameters: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;
		IF ~DMA330ProgramWriter.Generate(program1, ADDRESSOF(src1[srcOfs1]), txParams.size, 0, ADDRESSOF(dst1[dstOfs1]), txParams.size, 0, txParams.size, status) THEN
			KernelLog.String("Error programming DMA: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		IF ~DMA330ProgramWriter.BindToChannel(program1, channel1.channel, status) THEN
			KernelLog.String("Error binding DMA program to channel 0: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		DMA330ProgramWriter.InitProgram(program2);
		IF ~DMA330ProgramWriter.SetBurstParameters(program2, 16, 4, status) THEN
			KernelLog.String("Error setting burst parameters: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;
		IF ~DMA330ProgramWriter.Generate(program2, ADDRESSOF(src2[srcOfs2]), txParams.size, 0, ADDRESSOF(dst2[dstOfs2]), txParams.size, 0, txParams.size, status) THEN
			KernelLog.String("Error programming DMA: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		IF ~DMA330ProgramWriter.BindToChannel(program2, channel2.channel, status) THEN
			KernelLog.String("Error binding DMA program to channel 0: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		IF ~DMA330ProgramWriter.Execute(program1, notifier.Notify, channel1, status) THEN
			KernelLog.String("Error starting DMA program: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		IF ~DMA330ProgramWriter.Execute(program2, notifier.Notify, channel2, status) THEN
			KernelLog.String("Error starting DMA program: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		status := notifier.Await(NIL);
		IF status # DMA330ProgramWriter.Ok THEN
			KernelLog.String("Error in DMA program execution: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		status := notifier.Await(NIL);
		IF status # DMA330ProgramWriter.Ok THEN
			KernelLog.String("Error in DMA program execution: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		Machine.InvalidateDCacheRange(ADDRESSOF(dst1[0]), LEN(dst1));
		Machine.InvalidateDCacheRange(ADDRESSOF(dst2[0]), LEN(dst2));

		RETURN CheckMemToMem(src1^, srcOfs1, dst1^, dstOfs1, txParams.size) & CheckMemToMem(src2^, srcOfs2, dst2^, dstOfs2, txParams.size)
	END TestHeapSimultaneous;

	PROCEDURE TestPlFifoSequential (param: ANY): BOOLEAN;
	VAR
		program: DMA330ProgramWriter.Program;
		txParams: MemToMemParams;
		src, dst: POINTER TO ARRAY OF CHAR;
		srcOfs, dstOfs: ADDRESS;
		i, status: LONGINT;
	BEGIN
		txParams := param(MemToMemParams);
		NEW(src, txParams.size + txParams.alignment);
		NEW(dst, txParams.size + txParams.alignment);

		srcOfs := txParams.alignment - ADDRESSOF(src[0]) MOD txParams.alignment;
		dstOfs := txParams.alignment - ADDRESSOF(dst[0]) MOD txParams.alignment;

		FOR i := 0 TO LEN(src) - 1 DO
			src[i] := CHR(rng.Dice(100H))
		END;
		Machine.FlushDCacheRange(ADDRESSOF(src[0]), LEN(src));
		Machine.FlushDCacheRange(ADDRESSOF(dst[0]), LEN(dst));

		DMA330ProgramWriter.InitProgram(program);
		IF ~DMA330ProgramWriter.SetBurstParameters(program, 16, 4, status) THEN
			KernelLog.String("Error setting burst parameters: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		IF ~DMA330ProgramWriter.Generate(program, ADDRESSOF(src[srcOfs]), txParams.size, 0, ADDRESSOF(output.data), 0, 0, txParams.size, status) THEN
			KernelLog.String("Error programming DMA: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		IF ~DMA330ProgramWriter.BindToChannel(program, 0, status) THEN
			KernelLog.String("Error binding DMA program to channel 0: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		IF ~DMA330ProgramWriter.Execute(program, notifier.Notify, NIL, status) THEN
			KernelLog.String("Error starting DMA program: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		status := notifier.Await(NIL);
		IF status # DMA330ProgramWriter.Ok THEN
			KernelLog.String("Error in DMA program execution: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		DMA330ProgramWriter.InitProgram(program);
		IF ~DMA330ProgramWriter.SetBurstParameters(program, 16, 4, status) THEN
			KernelLog.String("Error setting burst parameters: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		IF ~DMA330ProgramWriter.Generate(program, ADDRESSOF(input.data), 0, 0, ADDRESSOF(dst[dstOfs]), txParams.size, 0, txParams.size, status) THEN
			KernelLog.String("Error programming DMA: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		IF ~DMA330ProgramWriter.BindToChannel(program, 0, status) THEN
			KernelLog.String("Error binding DMA program to channel 0: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		IF ~DMA330ProgramWriter.Execute(program, notifier.Notify, NIL, status) THEN
			KernelLog.String("Error starting DMA program: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		status := notifier.Await(NIL);
		IF status # DMA330ProgramWriter.Ok THEN
			KernelLog.String("Error in DMA program execution: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		Machine.InvalidateDCacheRange(ADDRESSOF(dst[0]), LEN(dst));

		RETURN CheckMemToMem(src^, srcOfs, dst^, dstOfs, txParams.size)
	END TestPlFifoSequential;

	PROCEDURE TestPlFifoSimultaneous (param: ANY): BOOLEAN;
	VAR
		tstart, tstop: HUGEINT;
		programWr, programRd: DMA330ProgramWriter.Program;
		channelWr, channelRd: ChannelId;
		txParams: MemToMemParams;
		src, dst: POINTER TO ARRAY OF CHAR;
		srcOfs, dstOfs: ADDRESS;
		i, status: LONGINT;
	BEGIN
		txParams := param(MemToMemParams);
		NEW(src, txParams.size + txParams.alignment);
		NEW(dst, txParams.size + txParams.alignment);
		NEW(channelWr);
		NEW(channelRd);

		channelWr.channel := 0;
		channelRd.channel := 1;

		srcOfs := txParams.alignment - ADDRESSOF(src[0]) MOD txParams.alignment;
		dstOfs := txParams.alignment - ADDRESSOF(dst[0]) MOD txParams.alignment;

		FOR i := 0 TO LEN(src) - 1 DO
			src[i] := CHR(rng.Dice(100H))
		END;
		Machine.FlushDCacheRange(ADDRESSOF(src[0]), LEN(src));
		Machine.FlushDCacheRange(ADDRESSOF(dst[0]), LEN(dst));

		DMA330ProgramWriter.InitProgram(programWr);
		IF ~DMA330ProgramWriter.SetBurstParameters(programWr, 4, 4, status) THEN
			KernelLog.String("Error setting burst parameters: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;
		IF ~DMA330ProgramWriter.Generate(programWr, ADDRESSOF(src[srcOfs]), txParams.size, 0, ADDRESSOF(output.data), 0, 0, txParams.size, status) THEN
			KernelLog.String("Error programming DMA: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		IF ~DMA330ProgramWriter.BindToChannel(programWr, 0, status) THEN
			KernelLog.String("Error binding DMA program to channel 0: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		DMA330ProgramWriter.InitProgram(programRd);
		IF ~DMA330ProgramWriter.SetBurstParameters(programRd, 4, 4, status) THEN
			KernelLog.String("Error setting burst parameters: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		IF ~DMA330ProgramWriter.Generate(programRd, ADDRESSOF(input.data), 0, 0, ADDRESSOF(dst[dstOfs]), txParams.size, 0, txParams.size, status) THEN
			KernelLog.String("Error programming DMA: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		IF ~DMA330ProgramWriter.BindToChannel(programRd, 1, status) THEN
			KernelLog.String("Error binding DMA program to channel 1: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		IF ~DMA330ProgramWriter.Execute(programWr, notifier.Notify, channelWr, status) THEN
			KernelLog.String("Error starting DMA program: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		tstart := Machine.GetTimer();
		IF ~DMA330ProgramWriter.Execute(programRd, notifier.Notify, channelRd, status) THEN
			KernelLog.String("Error starting DMA program: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		status := notifier.Await(NIL);
		IF status # DMA330ProgramWriter.Ok THEN
			KernelLog.String("Error in DMA program execution: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		status := notifier.Await(NIL);
		tstop := Machine.GetTimer();
		IF status # DMA330ProgramWriter.Ok THEN
			KernelLog.String("Error in DMA program execution: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		KernelLog.String("Read time = "); KernelLog.Int(tstop - tstart, 0); KernelLog.Ln;

		Machine.InvalidateDCacheRange(ADDRESSOF(dst[0]), LEN(dst));

		RETURN CheckMemToMem(src^, srcOfs, dst^, dstOfs, txParams.size)
	END TestPlFifoSimultaneous;

	PROCEDURE TestPlFifoFill (ignore: ANY): BOOLEAN;
	CONST
		size = 16 * 1024;
		alignment = 8;
	VAR
		program: DMA330ProgramWriter.Program;
		src: POINTER TO ARRAY OF CHAR;
		srcOfs: ADDRESS;
		i, status: LONGINT;
	BEGIN
		NEW(src, size + alignment);
		srcOfs := alignment - ADDRESSOF(src[0]) MOD alignment;

		FOR i := 0 TO size - 1 DO
			src[i] := CHR(rng.Dice(100H))
		END;
		Machine.FlushDCacheRange(ADDRESSOF(src[0]), LEN(src));

		DMA330ProgramWriter.InitProgram(program);
		IF ~DMA330ProgramWriter.SetBurstParameters(program, 16, 4, status) THEN
			KernelLog.String("Error setting burst parameters: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		IF ~DMA330ProgramWriter.Generate(program, ADDRESSOF(src[srcOfs]), size, 0, ADDRESSOF(output.data), 0, 0, size, status) THEN
			KernelLog.String("Error programming DMA: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		IF ~DMA330ProgramWriter.BindToChannel(program, 0, status) THEN
			KernelLog.String("Error binding DMA program to channel 0: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		FOR i := 1 TO 8 DO
			IF ~DMA330ProgramWriter.Execute(program, notifier.Notify, NIL, status) THEN
				KernelLog.String("Error starting DMA program: "); KernelLog.Int(status, 0); KernelLog.Ln;
				RETURN FALSE
			END;
			status := notifier.Await(NIL);
			IF status # DMA330ProgramWriter.Ok THEN
				KernelLog.String("Error in DMA program execution: "); KernelLog.Int(status, 0); KernelLog.Ln;
				RETURN FALSE
			END
		END;

		output.data := 1234ABCDH;
		RETURN ~output.ready & input.available
	END TestPlFifoFill;

	PROCEDURE TestPlFifoEmpty (param: ANY): BOOLEAN;
	CONST
		size = 16 * 1024;
		alignment = 8;
	VAR
		program: DMA330ProgramWriter.Program;
		dst: POINTER TO ARRAY OF CHAR;
		dstOfs: ADDRESS;
		i, status: LONGINT;
	BEGIN
		NEW(dst, size + alignment);
		dstOfs := alignment - ADDRESSOF(dst[0]) MOD alignment;

		FOR i := 0 TO 32 * 1024 DO
			output.data := i + 1
		END;
		ASSERT(~output.ready & input.available);

		Machine.FlushDCacheRange(ADDRESSOF(dst[0]), LEN(dst));

		DMA330ProgramWriter.InitProgram(program);
		IF ~DMA330ProgramWriter.SetBurstParameters(program, 16, 4, status) THEN
			KernelLog.String("Error setting burst parameters: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		IF ~DMA330ProgramWriter.Generate(program, ADDRESSOF(input.data), 0, 0, ADDRESSOF(dst[dstOfs]), size, 0, size, status) THEN
			KernelLog.String("Error programming DMA: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		IF ~DMA330ProgramWriter.BindToChannel(program, 0, status) THEN
			KernelLog.String("Error binding DMA program to channel 0: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		FOR i := 1 TO 8 DO
			IF ~DMA330ProgramWriter.Execute(program, notifier.Notify, NIL, status) THEN
				KernelLog.String("Error starting DMA program: "); KernelLog.Int(status, 0); KernelLog.Ln;
				RETURN FALSE
			END;
			status := notifier.Await(NIL);
			IF status # DMA330ProgramWriter.Ok THEN
				KernelLog.String("Error in DMA program execution: "); KernelLog.Int(status, 0); KernelLog.Ln;
				RETURN FALSE
			END
		END;
		i := input.data;

		RETURN ~input.available & output.ready
	END TestPlFifoEmpty;

	PROCEDURE TestTimeFifoEmpty (ignored: ANY): BOOLEAN;
	CONST
		size = 4 * 32 * 1024;
		alignment = 8;
	VAR
		tstart, tstop: HUGEINT;
		program: DMA330ProgramWriter.Program;
		dst: POINTER TO ARRAY OF CHAR;
		dstOfs: ADDRESS;
		i, status: LONGINT;
	BEGIN
		NEW(dst, size + alignment);
		dstOfs := alignment - ADDRESSOF(dst[0]) MOD alignment;

		FOR i := 1 TO 32 * 1024 DO
			output.data := i + 1
		END;

		Machine.FlushDCacheRange(ADDRESSOF(dst[0]), LEN(dst));

		DMA330ProgramWriter.InitProgram(program);
		IF ~DMA330ProgramWriter.SetBurstParameters(program, 16, 4, status) THEN
			KernelLog.String("Error setting burst parameters: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		IF ~DMA330ProgramWriter.Generate(program, ADDRESSOF(input.data), 0, 0, ADDRESSOF(dst[dstOfs]), size, 0, size, status) THEN
			KernelLog.String("Error programming DMA: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		IF ~DMA330ProgramWriter.BindToChannel(program, 0, status) THEN
			KernelLog.String("Error binding DMA program to channel 0: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;

		tstart := Machine.GetTimer();
		IF ~DMA330ProgramWriter.Execute(program, notifier.Notify, NIL, status) THEN
			KernelLog.String("Error starting DMA program: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;
		status := notifier.Await(NIL);
		tstop := Machine.GetTimer();
		IF status # DMA330ProgramWriter.Ok THEN
			KernelLog.String("Error in DMA program execution: "); KernelLog.Int(status, 0); KernelLog.Ln;
			RETURN FALSE
		END;
		KernelLog.String("Total transfer time = "); KernelLog.Int(tstop - tstart, 0); KernelLog.String("; Accepted limit = "); KernelLog.Int(100 * 32 * 1024 * 333000000 DIV freq DIV 80, 0); KernelLog.Ln;

		RETURN tstop - tstart <=  100 * 32 * 1024 * 333000000 DIV freq DIV 80 (* Test pass for performance >= 80% of max theoretical *)
	END TestTimeFifoEmpty;

	PROCEDURE InitPl;
	VAR
		res: LONGINT;
	BEGIN
		freq := PsConfig.GetPllClockFrequency(PsConfig.IoPll,res);
		Trace.String("IO PLL frequency is "); Trace.Int(freq,0); Trace.StringLn(" Hz");
		Trace.String("Initial FPGA clock 0 frequency is "); Trace.Int(PsConfig.GetPlClockFrequency(0,res),0); Trace.StringLn(" Hz");
		ASSERT(PsConfig.SetPlResets({0,1,2,3},res));
		IF PsConfig.SetPlClock(0,PsConfig.IoPll,9,1,res) THEN
			Trace.String("FPGA clock 0 frequency has been changed to "); Trace.Int(PsConfig.GetPlClockFrequency(0,res),0); Trace.StringLn(" Hz");
		ELSE Trace.String("Error while setting FPGA clock 0 frequency, res="); Trace.Int(res,0); Trace.Ln;
		END;

		output := AcAxisIo.GetOutput(0,0);
		input := AcAxisIo.GetInput(0,0);

		ResetPl
	END InitPl;

	PROCEDURE ResetPl;
	VAR
		t: HUGEINT;
		res: LONGINT;
	BEGIN
		(* Reset PL *)
		ASSERT(PsConfig.SetPlResets({0,1,2,3},res));
		t := Kernel.GetTicks();
		WHILE Kernel.GetTicks() - t < 1 DO END;
		ASSERT(PsConfig.SetPlResets({},res));
	END ResetPl;

	PROCEDURE CpuTest (ignored: ANY): BOOLEAN;
	VAR k: LONGINT;
	BEGIN
		FOR k := 1 TO 32768+1 DO
			output.data := k;
		END;
		IF output.ready OR ~input.available THEN
			RETURN FALSE
		END;

		FOR k := 1 TO 32768+1 DO
			IF input.data # k THEN RETURN FALSE END
		END;
		RETURN TRUE
	END CpuTest;

	PROCEDURE TimeoutTest (ignored: ANY): BOOLEAN;
	VAR
		t: Kernel.MilliTimer;
	BEGIN
		Kernel.SetTimer(t, 60000);
		REPEAT UNTIL Kernel.Expired(t);
		RETURN TRUE
	END TimeoutTest;

BEGIN
	(*AddTest(TimeoutTest, NIL, "Timeout test");*)

	(* Tests: Heap -> Heap, aligned *)
	(*NEW(parameter); parameter.size := 1024; parameter.alignment := 1;
	AddTest(TestHeapToHeap, parameter, "Heap Aligned -> Heap MOD 1, 1kB");
	NEW(parameter); parameter.size := 1024; parameter.alignment := 3;
	AddTest(TestHeapToHeap, parameter, "Heap Aligned -> Heap MOD 3, 1kB");
	NEW(parameter); parameter.size := 1024; parameter.alignment := 5;
	AddTest(TestHeapToHeap, parameter, "Heap Aligned -> Heap MOD 5, 1kB");
	NEW(parameter); parameter.size := 1024; parameter.alignment := 7;
	AddTest(TestHeapToHeap, parameter, "Heap Aligned -> Heap MOD 7, 1kB");
	NEW(parameter); parameter.size := 1024; parameter.alignment := 2;
	AddTest(TestHeapToHeap, parameter, "Heap Aligned -> Heap MOD 2, 1kB");
	NEW(parameter); parameter.size := 1024; parameter.alignment := 4;
	AddTest(TestHeapToHeap, parameter, "Heap Aligned -> Heap MOD 4, 1kB");
	NEW(parameter); parameter.size := 1024; parameter.alignment := 6;
	AddTest(TestHeapToHeap, parameter, "Heap Aligned -> Heap MOD 6, 1kB");
	AddTest(TestStackToStack, parameter, "Stack Aligned -> Stack Aligned, 1kB");
	NEW(parameter); parameter.size := 2048; parameter.alignment := 8;
	AddTest(TestHeapToHeap, parameter, "Heap Aligned -> Heap Aligned, 2kB");
	AddTest(TestStackToStack, parameter, "Stack Aligned -> Stack Aligned, 2kB");
	NEW(parameter); parameter.size := 3072; parameter.alignment := 8;
	AddTest(TestHeapToHeap, parameter, "Heap Aligned -> Heap Aligned, 3kB");
	AddTest(TestStackToStack, parameter, "Stack Aligned -> Stack Aligned, 3kB");
	NEW(parameter); parameter.size := 4096; parameter.alignment := 8;
	AddTest(TestHeapToHeap, parameter, "Heap Aligned -> Heap Aligned, 4kB");
	AddTest(TestStackToStack, parameter, "Stack Aligned -> Stack Aligned, 4kB");
	NEW(parameter); parameter.size := 512; parameter.alignment := 8;
	AddTest(TestHeapToHeap, parameter, "Heap Aligned -> Heap Aligned, 512B");
	AddTest(TestStackToStack, parameter, "Stack Aligned -> Stack Aligned, 512B");
	NEW(parameter); parameter.size := 1536; parameter.alignment := 8;
	AddTest(TestHeapToHeap, parameter, "Heap Aligned -> Heap Aligned, 1.5kB");
	AddTest(TestStackToStack, parameter, "Stack Aligned -> Stack Aligned, 1.5kB");
	NEW(parameter); parameter.size := 2560; parameter.alignment := 8;
	AddTest(TestHeapToHeap, parameter, "Heap Aligned -> Heap Aligned, 2.5kB");
	AddTest(TestStackToStack, parameter, "Stack Aligned -> Stack Aligned, 2.5kB");
	NEW(parameter); parameter.size := 3584; parameter.alignment := 8;
	AddTest(TestHeapToHeap, parameter, "Heap Aligned -> Heap Aligned, 3.5kB");
	AddTest(TestStackToStack, parameter, "Stack Aligned -> Stack Aligned, 3.5kB");

	NEW(parameter); parameter.size := 32 * 1024; parameter.alignment := 8;
	AddTest(TestHeapToHeap, parameter, "Heap Aligned -> Heap Aligned, 32kB");
	NEW(parameter); parameter.size := 64 * 1024; parameter.alignment := 8;
	AddTest(TestHeapToHeap, parameter, "Heap Aligned -> Heap Aligned, 64kB");
	AddTest(TestHeapSimultaneous, parameter, "Heap Aligned -> Heap Aligned, 2 times, 64kB");
	NEW(parameter); parameter.size := 4 * 1024 * 1024; parameter.alignment := 8;
	AddTest(TestHeapToHeap, parameter, "Heap Aligned -> Heap Aligned, 4MB");

	NEW(parameter); parameter.size := 16 * 1024 * 1024; parameter.alignment := 8;
	AddTest(TestHeapToHeap, parameter, "Heap Aligned -> Heap Aligned, 16MB");
	NEW(parameter); parameter.size := (32 * 1024 + 1) * 4; parameter.alignment := 8;
	AddTest(TestHeapToHeap, parameter, "Heap Aligned -> Heap Aligned, 32k + 1W");*)

	(* Fifo tests *)
	(*AddTest(CpuTest, NIL, "Fill and empty PL Fifo with CPU");*)
	(*AddTest(TestPlFifoFill, NIL, "Fill PL FIFO");
	AddTest(TestPlFifoEmpty, NIL, "Empty PL FIFO");
	(*NEW(parameter); parameter.size := 1024; parameter.alignment := 1;
	AddTest(TestPlFifoSequential, parameter, "Heap over PL FIFO, sequential, 1kB");*)
	NEW(parameter); parameter.size := 4 * 1024; parameter.alignment := 8;
	AddTest(TestPlFifoSequential, parameter, "Heap over PL FIFO, sequential, 4kB");
	NEW(parameter); parameter.size := 8 * 1024; parameter.alignment := 8;
	AddTest(TestPlFifoSequential, parameter, "Heap over PL FIFO, sequential, 8kB");
	NEW(parameter); parameter.size := 32 * 1024; parameter.alignment := 8;
	AddTest(TestPlFifoSequential, parameter, "Heap over PL FIFO, sequential, 32kB");
	NEW(parameter); parameter.size := 4 * 32 * 1024; parameter.alignment := 8;
	AddTest(TestPlFifoSequential, parameter, "Heap over PL FIFO, sequential, 4 * 32kB");
	NEW(parameter); parameter.size := 1024; parameter.alignment := 8;
	AddTest(TestPlFifoSimultaneous, parameter, "Heap over PL FIFO, simultaneous, 1kB");
	NEW(parameter); parameter.size := 4 * 1024; parameter.alignment := 8;
	AddTest(TestPlFifoSimultaneous, parameter, "Heap over PL FIFO, simultaneous, 4kB");
	NEW(parameter); parameter.size := 32 * 1024; parameter.alignment := 8;
	AddTest(TestPlFifoSimultaneous, parameter, "Heap over PL FIFO, simultaneous, 32kB");
	NEW(parameter); parameter.size := 64 * 1024; parameter.alignment := 8;
	AddTest(TestPlFifoSimultaneous, parameter, "Heap over PL FIFO, simultaneous, 64kB");
	NEW(parameter); parameter.size := 32 * 4 * 1024; parameter.alignment := 8;
	AddTest(TestPlFifoSimultaneous, parameter, "Heap over PL FIFO, simultaneous, 32kW");
	AddTest(TestPlFifoSimultaneous, parameter, "Heap over PL FIFO, simultaneous, 32kW, take 2");
	NEW(parameter); parameter.size := 1 * 1024 * 1024; parameter.alignment := 8;
	AddTest(TestPlFifoSimultaneous, parameter, "Heap over PL FIFO, simultaneous, 1MB");*)

	(*AddTest(TestTimeFifoEmpty, NIL, "FIFO Empty time");*)

	InitPl;
	(*NEW(notifier);
	NEW(rng)*)
	IF TestPlFifoEmpty(NIL) THEN END;
END Test.

FSTools.CreateFile -c -r Replacements.tmp
BootConfig.CpuNb = 1;
~
Release.Build -b -f=ARM.Release.Tool -o="--traceModule=Trace --noInitLocals" --only="Kernel" ZynqA2 ~
Release.Build -b -f=ARM.Release.Tool -o="--traceModule=Trace --replacements=Replacements.tmp --noInitLocals" --only="Kernel" ZynqA2 ~
Release.Build -b -f=ARM.Release.Tool -o="--traceModule=Trace" --only="System Random UsbCore Shell" ZynqA2 ~
Release.Build -l -f=ARM.Release.Tool --only="Kernel System Random UsbCore Shell" ZynqA2 ~

SystemTools.DoCommands
	Compiler.Compile -b=ARM --objectFile=Generic --mergeSections
		Zynq.PsConfig.Mod
		TestFifo/Zynq.AcAxisIo.Mod
		DMA330.Mod
		DMA330ProgramWriter.Mod
		DMAProgramWriterTest.Mod
	~

	StaticLinker.Link --fileName=Test.Bin --displacement=100000H -a
		Runtime Initializer Platform FPE64 ARMRuntime Trace BootConfig Uart Machine Heaps Modules Objects 
		Kernel KernelLog Plugins Streams Pipes Commands Reals Clock Dates Strings Files Disks Reflection 
		TrapWriters Traps Locks Options Timer Shell ShellController Math Random DMA330 DMA330ProgramWriter PsConfig AcAxisIo Test
	~
~
	StaticLinker.Link --fileName=Test.Bin --displacement=100000H -a
		Runtime Initializer Platform FPE64 ARMRuntime Trace BootConfig Uart Machine Heaps Modules Objects 
		Kernel KernelLog Plugins Streams Pipes Commands Reals Clock Dates Strings Files Disks Reflection 
		TrapWriters Traps Locks Options Timer Shell Math Random DMA330 DMA330ProgramWriter PsConfig AcAxisIo Test Test2
	~


setsource TFTP 10.3.34.145
load TestFifo.bin fpga
load Test.Bin memory 100000H
start 100000H

setsource TFTP 10.3.34.145
load Test.Bin memory 100000H
start 100000H
