MODULE DiskBenchmark; (** AUTHOR "staubesv"; PURPOSE "Simple block device benchmark"; *)
(**
 * Usage:
 *
 *	DiskBenchmark.Bench ~ will start benchmark with default parameters (only read)
 *	WMPartitions.Open ~ will open the graphical front-end. This benchmark can be found in Partitions -> Benchmark
 *
 * History:
 *
 *	01.12.2005	History started (staubesv)
 *	12.12.2005	Open/Close Disks.Device moved to PartitionsLib.Operation (staubesv)
 *	16.12.2005	Added doRead parameter (staubesv)
 *)

IMPORT
	Streams, Commands, Random, Kernel, Disks, Partitions, Lib := PartitionsLib, Strings;

CONST
	(* Allow write tests -> very, very dangerous!!! *)
	AllowWrite = TRUE;

TYPE
	DiskBench* = OBJECT(Lib.Operation)
	VAR
		(* parameters *)
		doRandom : BOOLEAN; 		(* Perform random block benchmark? *)
		doSequential : BOOLEAN; 	(* Perform sequential block benchmark? *)
		doRead : BOOLEAN; 		(* Perform read benchmarks ? *)
		doWrite : BOOLEAN; 		(* Perform write benchmarks? *)
		nbrOfBlocks : LONGINT;		(* Number of blocks used in random block benchmark *)
		blocksizes : SET;				(* Which block sizes should be benchmarked? *)

		(* progress status *)
		cur : HUGEINT; 				(* how many sectors have been processed *)
		max : HUGEINT;				(* how many sectors must be processed in total *)

		(* AosDiskdevice information *)
		start : LONGINT;			 	(* First sector in partition *)
		size : LONGINT;				(* partition size in sectors *)

		buffer : POINTER TO ARRAY OF CHAR;
		random : Random.Generator;

		PROCEDURE SetParameters*(doRandom, doSequential, doRead, doWrite : BOOLEAN; nbrOfBlocks : LONGINT; blocksizes : SET);
		BEGIN
			SELF.doRandom := doRandom; SELF.doSequential := doSequential; SELF.doRead := doRead;
			IF ~AllowWrite THEN doWrite := FALSE; ELSE SELF.doWrite := doWrite; END;
			SELF.nbrOfBlocks := nbrOfBlocks; SELF.blocksizes := blocksizes;
		END SetParameters;

		PROCEDURE ValidParameters*() : BOOLEAN;
		BEGIN
			IF ~doRead & ~doWrite THEN ReportError("Wrong Parameter: Neither read nor write benchmark?"); RETURN FALSE; END;
			IF doRandom & (nbrOfBlocks <= 0) THEN ReportError("Wrong Parameter: nbrOfBlocks < 1"); RETURN FALSE; END;
			IF blocksizes = {} THEN ReportError("Wrong Parameter: No blocksize selected"); RETURN FALSE; END;
			IF doWrite THEN locktype := Lib.WriterLock; ELSE locktype := Lib.ReaderLock; END;
			RETURN TRUE;
		END ValidParameters;

		PROCEDURE GetNbrOfSectors(blocksize : LONGINT) : LONGINT;
		VAR result : LONGINT;
		BEGIN
			result := -1;
			IF blocksize MOD disk.device.blockSize = 0 THEN result := blocksize DIV disk.device.blockSize; END;
			RETURN result;
		END GetNbrOfSectors;

		PROCEDURE DoOperation*;
		VAR sectors, blocksize, maxBlocksize, i : LONGINT;
		BEGIN
			(* General information *)
			info.String("Benchmark settings: "); info.Ln;
			info.String("    Random: ");
			IF doRandom THEN info.String("Yes ("); info.Int(nbrOfBlocks, 0); info.String(" blocks per blocksize) "); info.Ln;
			ELSE info.String("No"); info.Ln;
			END;
			info.String("    Sequential: "); IF doSequential THEN info.String("Yes"); ELSE info.String("No"); END; info.Ln;
			info.String("    Read Tests: "); IF doRead THEN info.String("Yes"); ELSE info.String("No"); END; info.Ln;
			info.String("    Write Tests: ");
			IF doWrite THEN
				 info.String("Yes");
				 IF ~AllowWrite THEN info.String(" (But disabled in DiskBenchmark.DoWrite)"); END;
			ELSE
				info.String("No");
			END; info.Ln;
			info.String("    Device sector size: "); info.Int(disk.device.blockSize, 0); info.Ln; info.Ln;
			info.String("Benchmark results: "); info.Ln;

			start := disk.table[partition].start; size := disk.table[partition].size;
			(* Compute amount of work to be done in number of sectors to be read/written (for progress status) *)
			cur := 0; max := 0; blocksize := 512;
			FOR i := 0 TO MAX(SET) DO
				IF i IN blocksizes THEN
					sectors := GetNbrOfSectors(blocksize);
					IF sectors > 0 THEN
						IF doRandom THEN max := max + nbrOfBlocks * sectors; END;
						IF doSequential THEN max := max + (size DIV sectors) * sectors; END;
					END;
					IF blocksize > maxBlocksize THEN maxBlocksize := blocksize; END;
				END;
				blocksize := blocksize * 2;
			END;
			IF doWrite & doRead THEN max := max * 2; END;

			(* Allocate buffer on heap which can hold the largest transfer used in the test *)
			NEW(buffer, maxBlocksize);

			IF alive & doRandom THEN
				NEW(random); random.InitSeed(Kernel.GetTicks());
				blocksize := 512; i := 0;
				LOOP
					IF i IN blocksizes THEN
						IF doRead THEN PerformRandomBench(Disks.Read, nbrOfBlocks, blocksize); END;
						IF doWrite THEN PerformRandomBench(Disks.Write, nbrOfBlocks, blocksize); END;
					END;
					blocksize := blocksize * 2;
					INC(i);
					IF ~alive OR (i > MAX(SET)) THEN EXIT; END;
				END;
			END;

			IF alive & doSequential THEN
				blocksize := 512; i := 0;
				LOOP
					IF i IN blocksizes THEN
						IF doRead THEN PerformSequentialBench(Disks.Read, blocksize); END;
						IF doWrite THEN PerformSequentialBench(Disks.Write, blocksize); END;
					END;
					blocksize := blocksize * 2;
					INC(i);
					IF ~alive OR (i > MAX(SET)) THEN EXIT; END;
				END;
			END;

			result.String("Benchmark on partition "); result.String(diskpartString);
			IF alive THEN
				result.String(" finished.");
			ELSE
				result.String(" aborted.");
			END;
		END DoOperation;

		(* 	Read/Write 'nbrOfBlocks' of the specified 'blocksize' *)
		PROCEDURE PerformRandomBench(mode, nbrOfBlocks, blocksize : LONGINT);
		VAR
			string :Lib.String;
			block, sectors : LONGINT;
			nbrOfBytes : HUGEINT;
			avgDuration : REAL;
			milliTimer : Kernel.MilliTimer;
			time : LONGINT;
			i : LONGINT; res : WORD;
			temp : ARRAY 256 OF CHAR;
		BEGIN
			ASSERT((mode = Disks.Read) OR (mode = Disks.Write));
			ASSERT(random # NIL);
			IF blocksize MOD disk.device.blockSize = 0 THEN
				sectors := blocksize DIV disk.device.blockSize;
				string := "Random Block ";
				IF mode = Disks.Read THEN Strings.Append(string, "Read Test (");
				ELSE Strings.Append(string, "Write Test (");
				END;
				WriteB(blocksize, temp); Strings.Append(string, temp); Strings.Append(string, ")");
				SetStatus(state.status, string, 0, cur, max, TRUE);
				(* Perform benchmark for a single block size *)
				Kernel.SetTimer(milliTimer, 0);
				i := 1;
				LOOP
					block := random.Dice(size - sectors);
					disk.device.Transfer(mode, start + block, sectors, buffer^, 0, res);
					IF res # Disks.Ok THEN Lib.GetTransferError(disk.device, mode, start + block, res, temp); ReportError(temp); END;
					cur := cur + sectors;
					SetCurrentProgress(cur);
					INC(i);
					IF (i > nbrOfBlocks) OR (res # Disks.Ok) OR ~alive THEN EXIT; END;
				END;
				(* Evaluation *)
				IF alive THEN (* benchmark has not been aborted *)
					time := Kernel.Elapsed(milliTimer); (* duration of test in milliseconds *)
					IF time <= 0 THEN time := 1; END; (* prevent division by zero *)
					nbrOfBytes := blocksize * nbrOfBlocks; (* bytes read/write in this time period *)
					info.String(string); info.String(": ");
					WriteK(ENTIER(nbrOfBytes / 1024 / (time / 1000)), temp); info.String(temp); info.String("/s");
					avgDuration := time / nbrOfBlocks;
					info.String(" (Avg. "); info.Int(ENTIER(avgDuration), 0); info.Char("."); info.Int(ENTIER(100*(avgDuration - ENTIER(avgDuration))), 0);
					info.String("ms per block)"); info.Ln;
				END;
			ELSE
				info.String("Skip "); WriteB(blocksize, temp); info.String(temp); info.String(" test: Blocksize is not multiple of sector size"); info.Ln;
			END;
		END PerformRandomBench;

		(* Sequentially Read/Write all blocks of the block device using 'blocksize' blocks *)
		PROCEDURE PerformSequentialBench(mode, blocksize : LONGINT);
		VAR
			string : Lib.String;
			block, sectors : LONGINT;
			nbrOfBytes : HUGEINT;
			milliTimer : Kernel.MilliTimer;
			time : LONGINT;
			i : LONGINT; res : WORD;
			temp : ARRAY 256 OF CHAR;
		BEGIN
			ASSERT((mode = Disks.Read) OR (mode = Disks.Write));
			IF blocksize MOD disk.device.blockSize = 0 THEN
				sectors := blocksize DIV disk.device.blockSize;
				string := "Sequential Block";
				IF mode = Disks.Read THEN Strings.Append(string, "Read Test (");
				ELSE Strings.Append(string, "Write Test (");
				END;
				WriteB(blocksize, temp); Strings.Append(string, temp); Strings.Append(string, ")");
				SetStatus(state.status, string, 0, cur, max, TRUE);
				(* Perform benchmark for a single block size *)
				Kernel.SetTimer(milliTimer, 0);
				i := 0; block := 0;
				LOOP
					block := i * sectors;
					IF block + sectors > size THEN EXIT; END;
					disk.device.Transfer(mode, start + block, sectors, buffer^, 0, res);
					IF res # Disks.Ok THEN Lib.GetTransferError(disk.device, mode, start + block, res, temp); ReportError(temp); END;
					cur := cur + sectors;
					SetCurrentProgress(cur);
					INC(i);
					IF (res # Disks.Ok) OR ~alive THEN alive := FALSE; EXIT; END;
				END;
				(* Evaluation *)
				IF alive THEN (* benchmark has not been aborted *)
					time := Kernel.Elapsed(milliTimer); (* duration of test in milliseconds *)
					nbrOfBytes := (i+1) * blocksize; (* bytes read/write in this time period *)
					info.String(string); info.String(": ");
					WriteK(ENTIER(nbrOfBytes / 1024 / (time / 1000)), temp); info.String(temp); info.String("/s"); info.Ln;
				END;
			ELSE
				info.String("Skip "); WriteB(blocksize, temp); info.String(temp); info.String(" test: Blocksize is not multiple of sector size"); info.Ln;
			END;
		END PerformSequentialBench;

		PROCEDURE WriteB*(k: LONGINT; VAR string: ARRAY OF CHAR);
		VAR suffix: ARRAY 3 OF CHAR;
		BEGIN
			IF k < 1024 THEN suffix := "B";
			ELSE k := k DIV 1024; suffix := "KB";
			END;
			Strings.IntToStr(SHORT(k), string); Strings.Append(string, suffix);
		END WriteB;

		PROCEDURE WriteK*(k: LONGINT; VAR string: ARRAY OF CHAR);
		VAR suffix: ARRAY 3 OF CHAR;
		BEGIN
			IF k < 100* 1024 THEN suffix := "KB";
			ELSE k := k DIV 1024; suffix := "MB";
			END;
			Strings.IntToStr(k, string); Strings.Append(string, suffix);
		END WriteK;

		PROCEDURE &Init*(disk :Lib.Disk; partition : LONGINT; out : Streams.Writer);
		BEGIN
			Init^(disk, partition, out);
			name := "DiskBenchmark"; desc := "Perform disk benchmark on partition"; locktype := Lib.WriterLock;
		END Init;

	END DiskBench;

(** Perform a benchmark on partition *)
PROCEDURE Bench*(context : Commands.Context); (** dev#part *)
VAR
 	selection : Lib.Selection;
 	bench : DiskBench;
BEGIN
	IF Partitions.GetSelection(context, FALSE, selection) THEN
		NEW(bench, selection.disk, selection.partition, context.out);
		bench.SetParameters(TRUE, TRUE, TRUE, FALSE, 100, {0..11});
		bench.SetStart;
		context.out.String("Partitions: UID "); context.out.Int(bench.uid, 0); context.out.String(": Started Benchmark on ");
		context.out.String(selection.disk.device.name); context.out.Char("#"); context.out.Int(selection.partition, 0); context.out.Ln;
	ELSE (* skip; error written to <w> by ScanOpenPart *)
	END;
END Bench;

END DiskBenchmark.

DiskBenchmark.Bench USB2#1 ~  System.Free DiskBenchmark ~

Partitions.ShowOps ~
Partitions.ShowOps detail ~
