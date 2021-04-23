(**
	AUTHOR: Alexey Morozov
	PURPOSE: Fortuna cryptographic pseudorandom generator for A2
*)
MODULE CryptoFortunaRng;

IMPORT
	Fortuna := CryptoFortuna,
	Machine, Kernel, Objects, Clock, Heaps, Random, Strings, Files, Modules, Streams, Commands,
	KernelLog;

CONST
	CollectEntropyIntervalMs* = 1000; (** entropy collection interval in ms *)

TYPE
	(* Entropy source procedure type *)
	EntropySource = PROCEDURE{DELEGATE}(timeSinceLastCallMs: SIGNED32; VAR data: ARRAY OF CHAR; VAR dataLen: SIZE);

	(* Entropy source descriptor *)
	EntropySourceDesc = RECORD
		name: ARRAY 64 OF CHAR;
		source: EntropySource;
		lastCollectTime: SIGNED32; (* time since last source data collection in ms *)

		file: Files.File;
		writer: Streams.Writer;
	END;

	(* A2 system entropy collector *)
	EntropyCollector = OBJECT
	VAR
		systemTimePrev := 0: INTEGER;
		objectsNumReadyPrev := 0: INTEGER;
		currentProcessTimePrev := 0: INTEGER;
		heapsUsagePrev := 0: INTEGER;
		heapsAllocStatsPrev := 0: INTEGER;
		heapsCallCountStatsPrev := 0: INTEGER;
		heapsObjCountStatsPrev := 0: INTEGER;
		heapsGcTimeStatsPrev := 0: INTEGER;
		heapsSweepTimeStatsPrev := 0: INTEGER;

		sources: ARRAY 256 OF EntropySourceDesc;
		numSources: SIZE;
		permutedSourceInds: Fortuna.Permutation; (* pseudorandom permutation of entropy source indexing *)

		storing: BOOLEAN; (* TRUE if storing entropy data to files *)

		generators: Generator; (* linked list of generators to be fed with entropy data *)

		rand: Random.Generator;

		alive: BOOLEAN;
		timer: Kernel.Timer;

		PROCEDURE &Init();

			(* Register an entropy source. Source number will be assigned later *)
			PROCEDURE AddSource(CONST name: ARRAY OF CHAR; source: EntropySource);
			BEGIN
				COPY(name, sources[numSources].name);
				sources[numSources].source := source;
				sources[numSources].lastCollectTime := Kernel.GetTicks() - 60000;
				INC(numSources);
			END AddSource;

		BEGIN
			ASSERT(~alive & (timer = NIL));

			NEW(timer);

			AddSource("MachineTimer", MachineTimerSource);
			AddSource("SystemTime", SystemTimeSource);

			AddSource("ObjectsNumReady", ObjectsNumReadySource);
			AddSource("CurrentProcessTime", CurrentProcessTimeSource);

			AddSource("HeapsUsage", HeapsUsageSource);
			IF Heaps.Stats THEN
				AddSource("HeapsAllocStats", HeapsAllocStatsSource);
				AddSource("HeapsCallCountStats", HeapsCallCountStatsSource);
				AddSource("HeapsObjCountStats", HeapsObjCountStatsSource);
				AddSource("HeapsGcTimeStats", HeapsGcTimeStatsSource);
				AddSource("HeapsSweepTimeStats", HeapsSweepTimeStatsSource);
			END;

			AddSource("Rand", RandSource);

			NEW(rand);
			(*! rand will be reseeded with entropy data in the active body to avoid slow module loading *)
			rand.InitSeed(SIGNED32(Machine.GetTimer()));

			(* pseudorandom permutation of source indices *)
			permutedSourceInds.Init(rand.Integer, numSources);

			alive := TRUE;
		END Init;

		(* Seed pseudorandom generator that will be used as an additional source of randomness *)
		PROCEDURE SeedRand();
		VAR
			buf: ARRAY 32 OF CHAR;
			crc: Fortuna.Crc32;
			seed: SIGNED32;
		BEGIN
			(* inject some randomness *)
			VAR t := Machine.GetTimer();
			Kernel.GC;
			timer.Sleep(SIGNED32(100 + (Machine.GetTimer() MOD 128))); (* scheduling could add some randomness *)
			t := Machine.GetTimer() - t;

			(* collect entropy data and use it for seed computation *)
			crc.Init;
			VAR k := 0: SIZE;
			WHILE k < numSources DO
				VAR n := 0: SIZE;
				sources[k].source(MAX(SIGNED32), buf, n);
				IF n # 0 THEN
					sources[k].lastCollectTime := Kernel.GetTicks();
					crc(buf, 0, n);
				END;
				INC(k);
			END;
			seed := SIGNED32(crc.Get());
			rand.InitSeed(seed);
		END SeedRand;

		(* Seed the very first Fortuna generator instance *)
		PROCEDURE SeedFirstGenerator(gen: Generator);
		VAR
			k, m, n: SIZE;
			buf: ARRAY Fortuna.MinPoolSize OF CHAR;
		BEGIN
			(*
				Preinitialize the accumulator with pseudorandom data.
				Make sure each pool gets Fortuna.MinPoolSize bytes of data to make the generator ready for use.
			*)
			FOR k := 0 TO Fortuna.NumPools-1 DO
				m := 0;
				WHILE m < Fortuna.MinPoolSize DO
					n := 0;
					RandSource(0, buf, n);
					ASSERT(n # 0);
					(* assign source numbers in some non-static way *)
					VAR sourceNum := INTEGER(gen.sourceNums.Get(k MOD numSources));
					gen.FeedEntropy(sourceNum, buf, 0, n);
					INC(m, n);
				END;
			END;

			ASSERT(gen.accumulator.IsReady(0));
		END SeedFirstGenerator;

		PROCEDURE AppendInt16(value: INTEGER; VAR valuePrev: INTEGER; VAR data: ARRAY OF CHAR; VAR dataOffs: SIZE);
		BEGIN
			IF value # valuePrev THEN
				Fortuna.Int16ToBytes(value, data, dataOffs);
				valuePrev := value;
			END;
		END AppendInt16;

		PROCEDURE MachineTimerSource(timeSinceLastCallMs: SIGNED32; VAR data: ARRAY OF CHAR; VAR dataLen: SIZE);
		BEGIN
			dataLen := 0;
			(* 3 leats (quickest) bytes of the CPU counter *)
			Fortuna.Int24ToBytes(SIGNED32(Machine.GetTimer()), data, dataLen);
		END MachineTimerSource;

		PROCEDURE SystemTimeSource(timeSinceLastCallMs: SIGNED32; VAR data: ARRAY OF CHAR; VAR dataLen: SIZE);
		VAR time, date: SIGNED32;
		BEGIN
			(*
				Sources should only include the unpredictable data in each event.
				For example, timing information can be represented by the two or four least significant bytes of an accurate timer.
				There is no point including the day, month, and year. It is safe to assume that the attacker knows those.
			*)
			dataLen := 0;
			Clock.Get(time, date);
			AppendInt16(INTEGER(date+time), systemTimePrev, data, dataLen);
		END SystemTimeSource;

		PROCEDURE ObjectsNumReadySource(timeSinceLastCallMs: SIGNED32; VAR data: ARRAY OF CHAR; VAR dataLen: SIZE);
		BEGIN
			dataLen := 0;
			AppendInt16(INTEGER(Objects.NumReady()), objectsNumReadyPrev, data, dataLen);
		END ObjectsNumReadySource;

		PROCEDURE CurrentProcessTimeSource(timeSinceLastCallMs: SIGNED32; VAR data: ARRAY OF CHAR; VAR dataLen: SIZE);
		BEGIN
			dataLen := 0;
			AppendInt16(INTEGER(Objects.CurrentProcessTime()), currentProcessTimePrev, data, dataLen);
		END CurrentProcessTimeSource;

		PROCEDURE HeapsUsageSource(timeSinceLastCallMs: SIGNED32; VAR data: ARRAY OF CHAR; VAR dataLen: SIZE);
		VAR total, free, largest: SIZE;
		BEGIN
			dataLen := 0;
			IF timeSinceLastCallMs >= 1000 THEN (*! getting heaps info is a slow operation -> do not do it often! *)
				Heaps.GetHeapInfo(total, free, largest);
				AppendInt16(INTEGER(total-free+largest), heapsUsagePrev, data, dataLen);
			END;
		END HeapsUsageSource;

		PROCEDURE HeapsAllocStatsSource(timeSinceLastCallMs: SIGNED32; VAR data: ARRAY OF CHAR; VAR dataLen: SIZE);
		BEGIN
			dataLen := 0;
			AppendInt16(INTEGER(Heaps.NnewBytes), heapsAllocStatsPrev, data, dataLen);
		END HeapsAllocStatsSource;

		PROCEDURE HeapsCallCountStatsSource(timeSinceLastCallMs: SIGNED32; VAR data: ARRAY OF CHAR; VAR dataLen: SIZE);
		BEGIN
			dataLen := 0;
			AppendInt16(INTEGER(Heaps.Ngc+Heaps.NgcSweeps+Heaps.Nmark+Heaps.Nnew), heapsCallCountStatsPrev, data, dataLen);
		END HeapsCallCountStatsSource;

		PROCEDURE HeapsObjCountStatsSource(timeSinceLastCallMs: SIGNED32; VAR data: ARRAY OF CHAR; VAR dataLen: SIZE);
		BEGIN
			dataLen := 0;
			AppendInt16(INTEGER(Heaps.Nmarked+Heaps.NfinalizeAlive+Heaps.NfinalizeDead), heapsObjCountStatsPrev, data, dataLen);
		END HeapsObjCountStatsSource;

		PROCEDURE HeapsGcTimeStatsSource(timeSinceLastCallMs: SIGNED32; VAR data: ARRAY OF CHAR; VAR dataLen: SIZE);
		BEGIN
			dataLen := 0;
			AppendInt16(INTEGER(Heaps.NgcCyclesAllRuns+Heaps.NgcCyclesMax), heapsGcTimeStatsPrev, data, dataLen);
		END HeapsGcTimeStatsSource;

		PROCEDURE HeapsSweepTimeStatsSource(timeSinceLastCallMs: SIGNED32; VAR data: ARRAY OF CHAR; VAR dataLen: SIZE);
		BEGIN
			dataLen := 0;
			AppendInt16(INTEGER(Heaps.NgcSweepTime+Heaps.NgcSweepMax), heapsSweepTimeStatsPrev, data, dataLen);
		END HeapsSweepTimeStatsSource;

		(* randomness source based on a pseudorandom generator *)
		PROCEDURE RandSource(timeSinceLastCallMs: SIGNED32; VAR data: ARRAY OF CHAR; VAR dataLen: SIZE);
		BEGIN
			Fortuna.Int32ToBytes(rand.Integer(), data, dataLen);
		END RandSource;

		PROCEDURE RegisterGenerator(gen: Generator);
		BEGIN{EXCLUSIVE}
			ASSERT(gen.prev = NIL);
			ASSERT(gen.next = NIL);

			(*! per-generator dynamic pseudorandom assignment of entropy source numbers *)
			gen.sourceNums.Init(rand.Integer, numSources);

			IF generators # NIL THEN
				generators.next := gen;
				gen.prev := generators;
			ELSE
				generators := gen;
				SeedFirstGenerator(gen);
			END;
		END RegisterGenerator;

		PROCEDURE UnregisterGenerator(gen: Generator);
		BEGIN{EXCLUSIVE}
			ASSERT(generators # NIL);
			IF gen.prev # NIL THEN
				IF gen.next # NIL THEN
					gen.prev.next := gen.next;
					gen.next.prev := gen.prev;
				ELSE
					gen.prev.next := NIL;
				END;
			ELSE
				ASSERT(gen = generators);
				generators := generators.next;
			END;
			gen.prev := NIL;
			gen.next := NIL;
			KernelLog.Enter; KernelLog.String("unregistered an instance of Fortuna generator"); KernelLog.Exit;
		END UnregisterGenerator;

		PROCEDURE CollectEntropy();
		VAR buf: ARRAY 32 OF CHAR;

			PROCEDURE CollectFromSource(VAR source: EntropySourceDesc; sourceIndex: INTEGER);
			BEGIN
				VAR timeSinceLastCollect := Kernel.GetTicks() - source.lastCollectTime;
				VAR dataLen := 0: SIZE;
				source.source(timeSinceLastCollect, buf, dataLen);
				IF dataLen # 0 THEN
					source.lastCollectTime := Kernel.GetTicks();
					VAR gen := generators;
					WHILE gen # NIL DO
						gen.FeedEntropy(INTEGER(gen.sourceNums.Get(sourceIndex)), buf, 0, dataLen);
						gen := gen.next;
					END;
					IF storing & (source.writer # NIL) THEN
						source.writer.Bytes(buf, 0, dataLen);
						source.writer.Update;
					END;
				END;
			FINALLY (*! continue looping through the sources even if trapped here *)
			END CollectFromSource;

		BEGIN{EXCLUSIVE}
			IF generators # NIL THEN
				VAR k := 0: SIZE;
				WHILE k < numSources DO
					VAR sourceIndex := INTEGER(permutedSourceInds.Get(k));
					CollectFromSource(sources[sourceIndex], sourceIndex);
					INC(k);
				END;
			END;
		END CollectEntropy;

		(** Start storing entropy source data to files with a given filename prefix *)
		PROCEDURE StartStoring*(): BOOLEAN;
		VAR
			fileName: Files.FileName;
			k: SIZE;

			PROCEDURE SetupSourceStoring(VAR source: EntropySourceDesc);
			VAR
				file: Files.File;
				writer: Files.Writer;
			BEGIN
				Strings.Concat("FortunaEntropy-", source.name, fileName);
				file := Files.New(fileName); ASSERT(file # NIL);
				Files.Register(file);
				Files.OpenWriter(writer, file, 0);
				source.file := file;
				source.writer := writer;
			END SetupSourceStoring;

		BEGIN{EXCLUSIVE}
			IF storing THEN RETURN FALSE; END;
			FOR k := 0 TO numSources-1 DO
				SetupSourceStoring(sources[k]);
			END;
			storing := TRUE;
			RETURN TRUE;
		END StartStoring;

		(* Stop storing entropy sources data *)
		PROCEDURE StopStoring(): BOOLEAN;
		VAR k: SIZE;
		BEGIN{EXCLUSIVE}
			IF storing THEN
				storing := FALSE;
				FOR k := 0 TO numSources-1 DO
					IF sources[k].file # NIL THEN
						sources[k].writer.Update;
						sources[k].file.Close;
						sources[k].writer := NIL;
						sources[k].file := NIL;
					END;
				END;
				RETURN TRUE;
			ELSE RETURN FALSE;
			END;
		END StopStoring;

		PROCEDURE Exit();
		BEGIN{EXCLUSIVE}
			generators := NIL;
			alive := FALSE;
			timer.Wakeup;
		END Exit;

	BEGIN{ACTIVE}

		SeedRand;

		WHILE alive DO
			CollectEntropy;
			timer.Sleep(CollectEntropyIntervalMs);
		END;

		KernelLog.Enter; KernelLog.String("Fortuna entropy collector exited"); KernelLog.Exit;
	END EntropyCollector;

	(** Fortuna pseudorandom generator for cryptographic applications

			Remarks: access to the object is thread-safe
	*)
	Generator* = OBJECT
	VAR
		accumulator: Fortuna.Accumulator;
		collector: Fortuna.EntropyCollector;

		sourceNums: Fortuna.Permutation; (* pseudorandomly permuted source numbers (used by the EntropyCollector) *)
		prev: Generator; (* reference to the previous instance in the linked list of generators (used by the EntropyCollector) *)
		next: Generator; (* reference to the next instance in the linked list of generators (used by the EntropyCollector) *)

		(* Private initializer of the Fortuna generator

			gen : an already existing instance of the Fortuna generator to be used for the new instance seeding; NIL for the very first generator instance
		*)
		PROCEDURE &Init(CONST gen: Generator);
		VAR
			k, m: SIZE;
			buf: ARRAY Fortuna.MaxRandomEventDataLen OF CHAR;
		BEGIN
			accumulator.Init;
			collector.Init;

			entropyCollector.RegisterGenerator(SELF);
			finalizedCollection.Add(SELF, finalizedCollection.FinalizeObject);

			IF gen # NIL THEN
				(*
					Preinitialize the generator with the output of an already existing generator instance.
					Make sure each pool gets Fortuna.MinPoolSize bytes of data to make the generator ready for use.
				*)
				FOR k := 0 TO Fortuna.NumPools-1 DO
					m := 0;
					WHILE m < Fortuna.MinPoolSize DO
						gen.Generate(buf, 0, Fortuna.MaxRandomEventDataLen);
						(* assign source numbers in some non-static way *)
						VAR sourceNum := INTEGER(sourceNums.Get(k MOD entropyCollector.numSources));
						FeedEntropy(sourceNum, buf, 0, Fortuna.MaxRandomEventDataLen);
						INC(m, Fortuna.MaxRandomEventDataLen);
					END;
				END;
			END;
		END Init;

		(* Feed data from an entropy source into the generator's accumulator *)
		PROCEDURE FeedEntropy(sourceNum: INTEGER; CONST data: ARRAY OF CHAR; dataOffs, dataLen: SIZE);
		BEGIN{EXCLUSIVE}
			collector.Collect(accumulator, sourceNum, data, dataOffs, dataLen);
		END FeedEntropy;

		(** Create a new instance of the Fortuna generator *)
		PROCEDURE NewInstance*(): Generator;
		BEGIN
			RESULT := NEW Generator(SELF);
			RETURN RESULT;
		END NewInstance;

		(** Generate pseudorandom data (thread-safe)

			data : output data array
			dataOffs : offset in the output array
			dataLen : requested amount of data in bytes
		*)
		PROCEDURE Generate*(VAR data: ARRAY OF CHAR; dataOffs, dataLen: SIZE);
		BEGIN{EXCLUSIVE}
			ASSERT(entropyCollector.alive);
			accumulator.Generate(Kernel.GetTicks(), data, dataOffs, dataLen);
		END Generate;

		(* Finalizer of the object called just before the object destruction *)
		PROCEDURE Finalizer;
		BEGIN
			IF entropyCollector # NIL THEN
				entropyCollector.UnregisterGenerator(SELF);
			END;
		END Finalizer;

	END Generator;

	FinalizedCollection = OBJECT(Kernel.FinalizedCollection)

		PROCEDURE FinalizeObject(obj: ANY);
		BEGIN
			obj(Generator).Finalizer;
		FINALLY
		END FinalizeObject;

		PROCEDURE FinalizeEnumerator(obj: ANY; VAR cont: BOOLEAN);
		BEGIN
			FinalizeObject(obj);
		FINALLY
			cont := TRUE;
		END FinalizeEnumerator;

		(* Cleanup all object which were not finalized automatically by the GC *)
		PROCEDURE Cleanup();
		BEGIN
			EnumerateN(FinalizeEnumerator);
		END Cleanup;

	END FinalizedCollection;

VAR
	generator-: Generator;

	entropyCollector: EntropyCollector;
	finalizedCollection: FinalizedCollection;
	
	(** Generate pseudorandom data (thread-safe) *)
	PROCEDURE Generate*(VAR data: ARRAY OF CHAR; dataOffs, dataLen: SIZE);
	BEGIN
		generator.Generate(data, dataOffs, dataLen);
	END Generate;
	
	(** Create a new instance of Fortuna generator (thread-safe) *)
	PROCEDURE NewGenerator*(): Generator;
	BEGIN
		RETURN generator.NewInstance();
	END NewGenerator;

	(** Start storing collected entropy data into files (useful for verification of selected entropy sources) *)
	PROCEDURE StartStoringEntropy*(ctx: Commands.Context);
	BEGIN
		IF entropyCollector.StartStoring() THEN
			ctx.out.String("started storing Fortuna entropy data"); ctx.out.Ln;
		ELSE
			ctx.error.String("Fortuna entropy data storing has been already started"); ctx.error.Ln;
		END;
	END StartStoringEntropy;

	(** Stop storing collected entropy data *)
	PROCEDURE StopStoringEntropy*(ctx: Commands.Context);
	BEGIN
		IF entropyCollector.StopStoring() THEN
			ctx.out.String("stopped storing Fortuna entropy data"); ctx.out.Ln;
		END;
	END StopStoringEntropy;

	PROCEDURE TerminateMod;
	BEGIN
		IF entropyCollector # NIL THEN entropyCollector.Exit; entropyCollector := NIL; END;
		finalizedCollection.Cleanup;
	END TerminateMod;

BEGIN
	NEW(finalizedCollection);
	NEW(entropyCollector);
	NEW(generator, NIL);
	Modules.InstallTermHandler(TerminateMod);
END CryptoFortunaRng.

