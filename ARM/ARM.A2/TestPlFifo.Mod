MODULE TestPlFifo;
IMPORT
	Trace, Machine, Kernel, KernelLog,
	PsConfig, AcAxisIo,
	DMA330ProgramWriter;

CONST
	ActDmaFill = 0;
	ActDmaEmpty = 1;
	ActCpuFill = 2;
	ActCpuEmpty = 3;
	ActCautiousFill = 4;
	ActCautiousEmpty = 5;

TYPE
	Notifier = OBJECT
	VAR
		params: ANY;
		count, result: SIGNED32;

		PROCEDURE Await(param: ANY): SIGNED32;
		BEGIN {EXCLUSIVE}
			AWAIT((count = 1)); (* & ((param = NIL) OR (param = params)));*)
			(*TRACE('notified', count);*)
			DEC(count);
			RETURN result
		END Await;

		PROCEDURE Notify (status: SIGNED32; param: ANY);
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

	Controller = OBJECT
	VAR
		action: SIGNED32;
		notifier: Notifier;

		PROCEDURE & Init (action: SIGNED32);
		BEGIN
			SELF.action := action;
			IF action <= ActDmaEmpty THEN NEW(notifier) END
		END Init;

		PROCEDURE EmptyCautious;
		VAR
			k, v: SIGNED32;
		BEGIN
			FOR k := 1 TO 32768+1 DO
				REPEAT UNTIL input.available;
				v := input.data
			END;
			KernelLog.Enter; KernelLog.String("CPU cautious emptying done"); KernelLog.Exit
		END EmptyCautious;

		PROCEDURE FillCautious;
		VAR
			k: SIGNED32;
		BEGIN
			FOR k := 1 TO 32768+1 DO
				REPEAT UNTIL output.ready;
				output.data := k
			END;
			KernelLog.Enter; KernelLog.String("CPU cautious filling done"); KernelLog.Exit
		END FillCautious;

		PROCEDURE EmptyCpu;
		VAR
			k, v: SIGNED32;
		BEGIN
			FOR k := 1 TO 32768+1 DO
				v := input.data
			END;
			KernelLog.Enter; KernelLog.String("CPU emptying done"); KernelLog.Exit
		END EmptyCpu;

		PROCEDURE FillCpu;
		VAR
			k: SIGNED32;
		BEGIN
			FOR k := 1 TO 32768+1 DO
				output.data := k
			END;
			KernelLog.Enter; KernelLog.String("CPU filling done"); KernelLog.Exit
		END FillCpu;

		PROCEDURE FillDma;
		CONST
			size = 16 * 1024;
			alignment = 8;
		VAR
			program: DMA330ProgramWriter.Program;
			src: POINTER TO ARRAY OF CHAR;
			srcOfs: ADDRESS;
			i, status: SIGNED32;
		BEGIN
			NEW(src, size + alignment);
			srcOfs := alignment - ADDRESSOF(src[0]) MOD alignment;

			FOR i := 0 TO size - 1 DO
				src[i] := CHR(i)
			END;
			Machine.FlushDCacheRange(ADDRESSOF(src[0]), LEN(src));

			DMA330ProgramWriter.InitProgram(program);
			IF ~DMA330ProgramWriter.SetBurstParameters(program, 8, 4, status) THEN
				KernelLog.String("Error setting burst parameters: "); KernelLog.Int(status, 0); KernelLog.Ln;
				RETURN
			END;

			IF ~DMA330ProgramWriter.Generate(program, ADDRESSOF(src[srcOfs]), size, 0, ADDRESSOF(output.data), 0, 0, size, status) THEN
				KernelLog.String("Error programming DMA: "); KernelLog.Int(status, 0); KernelLog.Ln;
				RETURN
			END;

			IF ~DMA330ProgramWriter.BindToChannel(program, 1, status) THEN
				KernelLog.String("Error binding DMA program to channel 1: "); KernelLog.Int(status, 0); KernelLog.Ln;
				RETURN
			END;

			FOR i := 1 TO 8 DO
				IF ~DMA330ProgramWriter.Execute(program, notifier.Notify, NIL, status) THEN
					KernelLog.String("Error starting DMA program: "); KernelLog.Int(status, 0); KernelLog.Ln;
					RETURN
				END;
				status := notifier.Await(NIL);
				IF status # DMA330ProgramWriter.Ok THEN
					KernelLog.String("Error in DMA program execution: "); KernelLog.Int(status, 0); KernelLog.Ln;
					RETURN
				END
			END;

			output.data := 1234ABCDH;
			KernelLog.Enter; KernelLog.String("DMA Filling done"); KernelLog.Exit
		END FillDma;

		PROCEDURE EmptyDma;
		CONST
			size = 16 * 1024;
			alignment = 8;
		VAR
			program: DMA330ProgramWriter.Program;
			dst: POINTER TO ARRAY OF CHAR;
			dstOfs: ADDRESS;
			i, status: SIGNED32;
		BEGIN
			NEW(dst, size + alignment);
			dstOfs := alignment - ADDRESSOF(dst[0]) MOD alignment;

			DMA330ProgramWriter.InitProgram(program);
			IF ~DMA330ProgramWriter.SetBurstParameters(program, 8, 4, status) THEN
				KernelLog.String("Error setting burst parameters: "); KernelLog.Int(status, 0); KernelLog.Ln;
				RETURN
			END;

			IF ~DMA330ProgramWriter.Generate(program, ADDRESSOF(input.data), 0, 0, ADDRESSOF(dst[dstOfs]), size, 0, size, status) THEN
				KernelLog.String("Error programming DMA: "); KernelLog.Int(status, 0); KernelLog.Ln;
				RETURN
			END;

			IF ~DMA330ProgramWriter.BindToChannel(program, 0, status) THEN
				KernelLog.String("Error binding DMA program to channel 0: "); KernelLog.Int(status, 0); KernelLog.Ln;
				RETURN
			END;

			FOR i := 1 TO 8 DO
				IF ~DMA330ProgramWriter.Execute(program, notifier.Notify, NIL, status) THEN
					KernelLog.String("Error starting DMA program: "); KernelLog.Int(status, 0); KernelLog.Ln;
					RETURN
				END;
				status := notifier.Await(NIL);
				IF status # DMA330ProgramWriter.Ok THEN
					KernelLog.String("Error in DMA program execution: "); KernelLog.Int(status, 0); KernelLog.Ln;
					RETURN
				END
			END;
			Machine.InvalidateDCacheRange(ADDRESSOF(dst[dstOfs]), size);
			i := input.data;
			KernelLog.Enter; KernelLog.String("DMA emptying done"); KernelLog.Exit
		END EmptyDma;

	BEGIN {ACTIVE}
		CASE action OF
			 ActDmaFill: FillDma
			|ActDmaEmpty: EmptyDma
			|ActCpuFill: FillCpu
			|ActCpuEmpty: EmptyCpu
			|ActCautiousFill: FillCautious
			|ActCautiousEmpty: EmptyCautious
		END
	END Controller;

VAR
	output: AcAxisIo.Output;
	input: AcAxisIo.Input;

	PROCEDURE InitPl;
	VAR
		freq: SIGNED64;
		res: SIGNED32;
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
		t: SIGNED64;
		res: SIGNED32;
	BEGIN
		(* Reset PL *)
		ASSERT(PsConfig.SetPlResets({0,1,2,3},res));
		t := Kernel.GetTicks();
		WHILE Kernel.GetTicks() - t < 1 DO END;
		ASSERT(PsConfig.SetPlResets({},res));
	END ResetPl;

	PROCEDURE DmaEmpty *;
	VAR
		ctrl: Controller;
	BEGIN
		NEW(ctrl, ActDmaEmpty)
	END DmaEmpty;

	PROCEDURE DmaFill *;
	VAR
		ctrl: Controller;
	BEGIN
		NEW(ctrl, ActDmaFill)
	END DmaFill;

	PROCEDURE Empty *;
	VAR
		ctrl: Controller;
	BEGIN
		NEW(ctrl, ActCpuEmpty)
	END Empty;

	PROCEDURE Fill *;
	VAR
		ctrl: Controller;
	BEGIN
		NEW(ctrl, ActCpuFill)
	END Fill;

	PROCEDURE CautiousEmpty *;
	VAR
		ctrl: Controller;
	BEGIN
		NEW(ctrl, ActCautiousEmpty)
	END CautiousEmpty;

	PROCEDURE CautiousFill *;
	VAR
		ctrl: Controller;
	BEGIN
		NEW(ctrl, ActCautiousFill)
	END CautiousFill;
BEGIN
	InitPl;
END TestPlFifo.

SystemTools.DoCommands
	Compiler.Compile -b=ARM --mergeSections
		Zynq.PsConfig.Mod
		TestFifo/Zynq.AcAxisIo.Mod
		DMA330.Mod
		DMA330ProgramWriter.Mod
		TestPlFifo.Mod
	~

	StaticLinker.Link --fileName=Test.Bin --displacement=100000H -a
		Runtime Initializer Platform FPE64 ARMRuntime Trace BootConfig Uart Machine Heaps Modules Objects 
		Kernel KernelLog Plugins Streams Pipes Commands Reals Clock Dates Strings Files Disks Reflection 
		TrapWriters Traps Locks Options Timer Shell ShellController Math Random DMA330 DMA330ProgramWriter PsConfig AcAxisIo Test
	~
~
Release.Build -f=ARM.Release.Tool -l --only='Kernel System UsbCore DMA Shell' ZynqA2 ~
setsource TFTP 10.3.34.145
load TestFifo.bin fpga
load Test.Bin memory 100000H
start 100000H


