MODULE DMA330ProgramWriter; (** AUTHOR "Timothée Martiel"; PURPOSE "Intermediate-level DMA interface for Zynq"; *)

IMPORT SYSTEM, KernelLog, DMA330;

CONST
	(* Status values *)
	(** No error *)
	Ok * = 0;
	(** Invalid burst size *)
	InvalidBurstSize * = 1;
	(** Invalid burst count *)
	InvalidBurstCount * = 2;
	(** Address must be aligned on burst size *)
	RequireAlignedAddress * = 3;
	(** Program must be generated first *)
	RequireProgramGeneration * = 4;
	(** Program must be bound to channel first *)
	RequireChannelBinding * = 5;
	(** Program must be initialized first *)
	RequireProgramInit * = 6;
	(** Specified channel is invalid *)
	InvalidChannel * = 7;
	(** Internal driver error *)
	InternalError * = 8;
	(** Both block sizes are 0, which is forbidden *)
	InvalidBlockSizes * = 9;
	(** MFIFO could not perform operation *)
	MfifoErr * = 12; (*! Do not change *)
	(** MFIFO lockup *)
	LockupErr * = 31; (*! Do not change *)

	(** Number of channels available *)
	MaxChannels * = 8;

	(** Burst parameters *)
	DefaultBurstCount = 16;
	DefaultBurstSize = 8;
	MaxBurstCount = 16;
	MaxBurstSize = 16;

	(* Program States *)
	(** Program was initialized *)
	Initialized = 1;
	Programmed = 2;
	(** Program was instanciated with src and dst addresses *)
	Instanciated = 3;
	(** Program was bound to a channel *)
	Bound = 4;

	(* Alignment properties *)
	None = 0;
	Dst = 1;
	Src = 2;

	(** Debugging and tracing output *)
	Trace = FALSE;
TYPE
	(**
		DMA Program.
	*)
	Program * = RECORD
		programs: ARRAY MaxBurstSize OF RewritableProgram;
		src, dst: ADDRESS;
		active, align, burstSize -, burstCount -, channel -, dstBlockSize, dstStridingSize, srcBlockSize, srcStridingSize, size: SIGNED32;
		state: SET;
	END;

	(**
		Handler type for DMA completion. 'status' indicates the if an error occurred. 'param' is a user-specified parameter.
	*)
	Handler * = PROCEDURE {DELEGATE} (status: SIGNED32; param: ANY);

	HandlerDesc = RECORD
		handler: Handler;
		param: ANY
	END;

	(** Extension of the hardware-specific program to support addresses and event rewriting *)
	RewritableProgram = RECORD (DMA330.Program)
		dstOfs, sevOfs, srcOfs: SIGNED32;
		created: BOOLEAN;
	END;

VAR
	channelHandlers: ARRAY MaxChannels OF HandlerDesc;

	(** Initializes a DMA program with default burst sizes and counts. *)
	PROCEDURE InitProgram * (VAR program: Program);
	VAR
		ignore: SIGNED32;
	BEGIN
		ASSERT(SetBurstParameters(program, DefaultBurstCount, DefaultBurstSize, ignore));
		program.state := {Initialized}
	END InitProgram;

	(**
		Overrides the burst parameters for a DMA program. Changes will be applied onyl after a call to Generate.

		DMA transfers data in bursts. Each burst consists of 'count' transfers of 'size' bytes. Depending on the underlying hardware, some
		counts and sizes may lead to more efficient transfers than others.
	*)
	PROCEDURE SetBurstParameters * (VAR program: Program; count, size: SIGNED32; VAR status: SIGNED32): BOOLEAN;
	BEGIN
		IF count > MaxBurstCount THEN
			status := InvalidBurstCount;
			RETURN FALSE
		END;
		IF size > MaxBurstSize THEN
			status := InvalidBurstSize;
			RETURN FALSE
		END;
		program.burstCount := count;
		program.burstSize := size;
		status := Ok;
		RETURN TRUE
	END SetBurstParameters;

	(**
		Generates a program for the specified transfer.

		A DMA transfer always transfers 'len' bytes from a source address 'src' to a destination address 'dst'. The ways data is read from the source or written to the destination depends on the parameters
		'srcBlockSize', 'srcStridingSize' and 'dstBlockSize', 'dstStridingSize' respectively:
			- if '*BlockSize' is 0, the corresponding address is not incremented and all memory transfers are done from/to this address
			- if '*BlockSize' is not 0 and '*StridingSize' is 0, the corresponding address is incremented and the transfer occurs from/to a contiguous memory range of 'len' bytes starting at the address
			- if neither '*BlockSize' nor '*StridingSize' are 0, the transfer occurs from/to a discontinuous range of memory, consisting of contiguous blocks of '*BlockSize' bytes separated by '*StridingSize' bytes.
				So '*BlockSize' bytes are read/written, then '*StridingSize' bytes are skipped and this scheme is repeated until 'len' bytes have been transfered. 'len' must be a multiple of '*BlockSize'.
	*)
	PROCEDURE Generate * (
									VAR program: Program;
									src: ADDRESS; srcBlockSize, srcStridingSize: SIZE;
									dst: ADDRESS; dstBlockSize, dstStridingSize: SIZE;
									len: SIGNED32;
									VAR status: SIGNED32
								): BOOLEAN;
	VAR
		iterations: SIGNED32;
		result: BOOLEAN;
		incSrc, incDst: BOOLEAN;
	BEGIN
		ASSERT((program.align # None) OR (program.active = 0));
		IF program.align = Dst THEN
			ASSERT(dst MOD program.burstSize = program.active)
		ELSIF program.align = Src THEN
			ASSERT(src MOD program.burstSize = program.active)
		ELSIF program.align = None THEN
			IF dst MOD program.burstSize # 0 THEN
				program.active := dst MOD program.burstSize;
				program.align := Dst
			ELSIF src MOD program.burstSize # 0 THEN
				program.active := src MOD program.burstSize;
				program.align := Src
			END
		END;

		DMA330.InitProgram(program.programs[program.active]);
		program.programs[program.active].dstOfs := -1;
		program.programs[program.active].sevOfs := -1;
		program.programs[program.active].srcOfs := -1;

		result := TRUE;
		status := Ok;
		IF (srcBlockSize = 0) & (dstBlockSize = 0) THEN
			(* Transfer from fixed address to fixed address forbidden *)
			status := InvalidBlockSizes;
			result := FALSE
		ELSIF srcBlockSize = 0 THEN
			(* Transfer from fixed address *)
			IF dstStridingSize # 0 THEN
				(*! NOT IMPLEMENTED YET *)
				HALT(505)
			END;
			(*! ASSUMES ALIGNED ADDRESS *)
			ASSERT(dstBlockSize = len);
			incSrc := FALSE;
			incDst := TRUE
		ELSIF dstBlockSize = 0 THEN
			(* Transfer to fixed address *)
			IF srcStridingSize # 0 THEN
				(*! NOT IMPLEMENTED YET *)
				HALT(505)
			END;
			(*! ASSUMES ALIGNED ADDRESS *)
			ASSERT(srcBlockSize = len);
			incSrc := TRUE;
			incDst := FALSE
		ELSIF (srcStridingSize = 0) & (dstStridingSize = 0) THEN
			(* Transfer from cont to cont, aligned *)
			IF Trace THEN
				KernelLog.String("DMA Program Writer: ");
				KernelLog.String("generating aligned, cont -> aligned, cont program; size = ");
				KernelLog.Int(len, 0);
				KernelLog.String("; burst size = ");
				KernelLog.Int(program.burstSize, 0);
				KernelLog.String("; burst count = ");
				KernelLog.Int(program.burstCount, 0);
				KernelLog.Ln;
			END;
			(*! ASSUMES ALIGNED ADDRESSES *)
			ASSERT(srcBlockSize = len);
			ASSERT(dstBlockSize = len);
			incSrc := TRUE;
			incDst := TRUE
		ELSE
			(*! NOT IMPLEMENTED YET *)
			HALT(505);
		END;

		IF ~result THEN
			RETURN FALSE
		ELSIF (srcStridingSize = 0) & (dstStridingSize = 0) THEN
			WriteProgramHeader(program, src, incSrc, program.burstCount, program.burstSize, dst, incDst, program.burstCount, program.burstSize);

			IF (program.active > 0) & (program.align = Src) THEN
				WriteProgramSrcAlign(program, program.active, incSrc, incDst, ~incSrc)
			END;

			iterations := len DIV (program.burstCount * program.burstSize);
			ASSERT(iterations * program.burstCount * program.burstSize = len);
			LOOP
				IF iterations = 0 THEN EXIT END;
				IF iterations > 256 THEN
					iterations := WriteProgramNestedLoop(program, iterations, ~incSrc)
				ELSE
					iterations := WriteProgramLoop(program, iterations, ~incSrc)
				END
			END;

			(* DST alignment *)
			IF (program.active > 0) & (program.align = Dst) THEN
				WriteProgramDstAlign(program, program.active, incSrc, incDst, ~incSrc)
			END;

			program.programs[program.active].created := TRUE;
			INCL(program.state, Programmed)
		END;
		WriteProgramFooter(program);

		program.src := src;
		program.srcBlockSize := srcBlockSize;
		program.srcStridingSize := srcStridingSize;
		program.dst := dst;
		program.dstBlockSize := dstBlockSize;
		program.dstStridingSize := dstStridingSize;
		program.size := len;

		RETURN result
	END Generate;

	(** Changes the destination address of a program to 'adr'. *)
	PROCEDURE SetDst * (VAR program: Program; adr: ADDRESS; VAR status: SIGNED32): BOOLEAN;
	VAR
		offset: SIGNED32;
		result: BOOLEAN;
	BEGIN
		result := TRUE;
		status := Ok;
		program.active := adr MOD program.burstSize;
		ASSERT(program.align # Src);
		IF ~(Initialized IN program.state) THEN
			status := RequireProgramGeneration;
			result := FALSE
		ELSIF program.programs[program.active].created THEN
			program.align := Dst;
			offset := program.programs[program.active].offset;
			program.programs[program.active].offset := program.programs[program.active].dstOfs;
			DMA330.DMAMOV(program.programs[program.active], DMA330.DAR, adr);
			program.programs[program.active].offset := offset
		ELSE
			result := Generate(program, program.src, program.srcBlockSize, program.srcStridingSize, adr, program.dstBlockSize, program.dstStridingSize, program.size, status);
		END;
		RETURN result
	END SetDst;

	(** Changes the source address of a program to 'adr'. *)
	PROCEDURE SetSrc * (VAR program: Program; adr: ADDRESS; VAR status: SIGNED32): BOOLEAN;
	VAR
		offset: SIGNED32;
		result: BOOLEAN;
	BEGIN
		result := TRUE;
		status := Ok;
		program.active := adr MOD program.burstSize;
		IF ~(Initialized IN program.state) THEN
			status := RequireProgramGeneration;
			result := FALSE
		ELSIF program.programs[program.active].created THEN
			offset := program.programs[program.active].offset;
			program.programs[program.active].offset := program.programs[program.active].srcOfs;
			DMA330.DMAMOV(program.programs[program.active], DMA330.SAR, adr);
			program.programs[program.active].offset := offset
		ELSE
			result := Generate(program, program.src, program.srcBlockSize, program.srcStridingSize, adr, program.dstBlockSize, program.dstStridingSize, program.size, status);
		END;
		RETURN result
	END SetSrc;

	(** Binds the program 'prog' to the channel 'channel'. This must be done before program execution. *)
	PROCEDURE BindToChannel * (VAR program: Program; channel: SIGNED32; VAR status: SIGNED32): BOOLEAN;
	VAR
		offset: SIGNED32;
		result: BOOLEAN;
	BEGIN
		result := TRUE;
		IF (channel < 0) OR (channel >= MaxChannels) THEN
			status := InvalidChannel;
			result := FALSE
		ELSIF program.programs[program.active].sevOfs = -1 THEN
			status := RequireProgramGeneration;
			result := FALSE
		ELSE
			program.channel := channel;
			offset := program.programs[program.active].offset;
			program.programs[program.active].offset := program.programs[program.active].sevOfs;
			IF DMA330.TracePrograms THEN KernelLog.String("Rewriting DMASEV:"); KernelLog.Ln END;
			DMA330.DMASEV(program.programs[program.active], channel);
			program.programs[program.active].offset := offset;
		END;
		RETURN result
	END BindToChannel;

	(** Starts executing the program. When the transfer is finished or triggers an error, 'handler' is called with the termination status and 'handlerParam' as parameters. *)
	PROCEDURE Execute * (CONST program: Program; handler: Handler; handlerParam: ANY; VAR status: SIGNED32): BOOLEAN;
	VAR
		channel: SIGNED32;
		result: BOOLEAN;
	BEGIN
		result := TRUE;
		IF ~(Programmed IN program.state) THEN
			status := RequireProgramGeneration;
			result := FALSE
		ELSIF program.channel = -1 THEN
			status := RequireChannelBinding;
			result := FALSE
		ELSE
			channel := program.channel;
			channelHandlers[channel].handler := handler;
			channelHandlers[channel].param := handlerParam;
			DMA330.StartDMAThread(program.programs[program.active], channel);
		END;
		RETURN result
	END Execute;

	(* Handler for normal transfer termination. *)
	PROCEDURE DoneHandler (channel: SIGNED32);
	VAR
		handler: Handler;
	BEGIN
		handler := channelHandlers[channel].handler;
		IF handler # NIL THEN
			handler(Ok, channelHandlers[channel].param)
		END
	END DoneHandler;

	PROCEDURE FaultHandler (channel, fault: SIGNED32);
	VAR
		handler: Handler;
		errors: SET;
		status: SIGNED32;
	BEGIN
		(* Decode error *)
		errors := SYSTEM.VAL(SET, fault);
		IF channel = - 1 THEN
			status := InternalError
		ELSIF MfifoErr IN errors THEN
			status := MfifoErr
		ELSIF LockupErr IN errors THEN
			status := LockupErr
		ELSE
			status := InternalError
		END;

		(* Call handler *)
		handler := channelHandlers[channel].handler;
		IF handler # NIL THEN
			handler(status, channelHandlers[channel].param)
		END
	END FaultHandler;

	(** Writes the CCR, SAR and DAR registers of the channel to the values specified by the parameters. *)
	PROCEDURE WriteProgramHeader (VAR program: Program; src: ADDRESS; incSrc: BOOLEAN; srcBurstCount, srcBurstSize: SIGNED32; dst: ADDRESS; incDst: BOOLEAN; dstBurstCount, dstBurstSize: SIGNED32);
	BEGIN
		IF Trace THEN
			KernelLog.String("DMA Program Writer: ");
			KernelLog.String("program header; src = ");
			KernelLog.Address(src);
			KernelLog.String("; dst = ");
			KernelLog.Address(dst);
			KernelLog.Ln
		END;
		WriteProgramBurstParameters(program, srcBurstCount, srcBurstSize, dstBurstCount, dstBurstSize, incSrc, incDst);
		DMA330.DMAMOV(program.programs[program.active], DMA330.SAR, src);
		DMA330.DMAMOV(program.programs[program.active], DMA330.DAR, dst)
	END WriteProgramHeader;

	PROCEDURE WriteProgramBurstParameters (VAR program: Program; srcBurstCount, srcBurstSize, dstBurstCount, dstBurstSize: SIGNED32; incSrc, incDst: BOOLEAN);
	VAR
		val: SIGNED32;
	BEGIN
		val := DMA330.SB(srcBurstCount) + DMA330.SS(srcBurstSize * 8) + DMA330.DB(dstBurstCount) + DMA330.DS(dstBurstSize * 8);
		IF incSrc THEN INC(val, DMA330.SI) END;
		IF incDst THEN INC(val, DMA330.DI) END;
		DMA330.DMAMOV(program.programs[program.active], DMA330.CCR, val);
	END WriteProgramBurstParameters;

	PROCEDURE WriteProgramNestedLoop (VAR program: Program; iteration: SIGNED32; read: BOOLEAN): SIGNED32;
	VAR
		inner, outer: SIGNED32;
	BEGIN
		outer := 256;
		LOOP
			IF outer = 0 THEN EXIT END;

			inner := iteration DIV outer;
			IF (inner * outer = iteration) & (inner <= 256) THEN EXIT END;
			DEC(outer);
		END;
		IF outer = 0 THEN
			inner := 256;
			outer := MIN(iteration DIV inner, 256)
		END;

		IF Trace THEN
			KernelLog.String("DMA Program Writer: ");
			KernelLog.String("iterations = "); KernelLog.Int(iteration, 0);
			KernelLog.String("; outer iterations = "); KernelLog.Int(outer, 0);
			KernelLog.String("; inner iterations = "); KernelLog.Int(inner, 0);
			KernelLog.Ln
		END;
		
		DMA330.DMALP(program.programs[program.active], outer - 1);
		DMA330.DMALP(program.programs[program.active], inner - 1);
		(*IF read THEN DMA330.DMAWFP(program.programs[program.active], 0, DMA330.Single) END;*)
		DMA330.DMALD(program.programs[program.active], FALSE, FALSE);
		DMA330.DMAST(program.programs[program.active], FALSE, FALSE);
		DMA330.DMALPEND(program.programs[program.active], FALSE, FALSE);
		DMA330.DMALPEND(program.programs[program.active], FALSE, FALSE);
		RETURN iteration - inner * outer
	END WriteProgramNestedLoop;

	PROCEDURE WriteProgramLoop (VAR program: Program; iteration: SIGNED32; read: BOOLEAN): SIGNED32;
	BEGIN
		IF Trace THEN
			KernelLog.String("DMA Program Writer: ");
			KernelLog.String("program loop with ");
			KernelLog.Int(iteration, 0);
			KernelLog.String(" iterations");
			KernelLog.Ln
		END;
		DMA330.DMALP(program.programs[program.active], iteration - 1);
		(*IF read THEN DMA330.DMAWFP(program.programs[program.active], 0, DMA330.Single) END;*)
		DMA330.DMALD(program.programs[program.active], FALSE, FALSE);
		DMA330.DMAST(program.programs[program.active], FALSE, FALSE);
		DMA330.DMALPEND(program.programs[program.active], FALSE, FALSE);
		RETURN 0
	END WriteProgramLoop;

	PROCEDURE WriteProgramSrcAlign (VAR program: Program; align: SIGNED32; incSrc, incDst, read: BOOLEAN);
	VAR
		count, size: SIGNED32;
	BEGIN
		(*IF read THEN DMA330.DMAWFP(program.programs[program.active], 0, DMA330.Single) END;*)
		DMA330.DMALD(program.programs[program.active], FALSE, FALSE);
	END WriteProgramSrcAlign;

	PROCEDURE WriteProgramDstAlign (VAR program: Program; align: SIGNED32; incSrc, incDst, read: BOOLEAN);
	VAR
		count, size: SIGNED32;
	BEGIN
			size := 4;
			LOOP
				count := 16;
				LOOP
					IF count * size = align THEN EXIT END;
					IF count = 1 THEN EXIT END;
					DEC(count)
				END;
				IF count * size = align THEN EXIT END;
				IF size = 1 THEN EXIT END;
				size := size DIV 2
			END;
			IF Trace THEN
				KernelLog.String("DMA Program Writer: ");
				KernelLog.String("compensating destination alignment; count = ");
				KernelLog.Int(count, 0);
				KernelLog.String("; size = ");
				KernelLog.Int(size, 0);
				KernelLog.Ln
			END;
			WriteProgramBurstParameters(program, program.burstCount, program.burstSize, count, size, incSrc, incDst);
			(*IF read THEN DMA330.DMAWFP(program.programs[program.active], 0, DMA330.Single) END;*)
			DMA330.DMALD(program.programs[program.active], FALSE, FALSE);
			DMA330.DMAST(program.programs[program.active], FALSE, FALSE);
			DEC(align, count * size)
		(*END*)
	END WriteProgramDstAlign;

	(** Writes a DMAWMB and a DMASEV(31) in the program *)
	PROCEDURE WriteProgramFooter (VAR program: Program);
	BEGIN
		DMA330.DMAWMB(program.programs[program.active]);
		program.programs[program.active].sevOfs := program.programs[program.active].offset;
		DMA330.DMASEV(program.programs[program.active], 31);
		DMA330.DMAEND(program.programs[program.active])
	END WriteProgramFooter;

BEGIN
	DMA330.InstallDoneHandler(DoneHandler);
	DMA330.InstallFaultHandler(FaultHandler)
END DMA330ProgramWriter.
