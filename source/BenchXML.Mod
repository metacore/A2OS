MODULE BenchXML; (** AUTHOR "staubesv"; PURPOSE "Simple XML parser benchmark"; *)

IMPORT
	KernelLog, Streams, Modules, Commands, Options, Dates, Strings, Files, XML, XMLScanner, XMLParser;

CONST
	DefaultNofTimes = 1000;
	DefaultNofWorkers = 1;

	Waiting = 0;
	Working = 1;
	Terminating = 2;
	Terminated = 3;

TYPE

	Worker = OBJECT
	VAR
		file : Files.File;

		pooling : SET;
		nofTimes : LONGINT;
		state : LONGINT;

		PROCEDURE &Init*(file : Files.File; nofTimes : LONGINT; pooling : SET);
		BEGIN
			ASSERT((file # NIL) & (nofTimes > 0));
			SELF.file := file;
			SELF.nofTimes := nofTimes;
			SELF.pooling := pooling;
			state := Waiting;
		END Init;

		PROCEDURE Start;
		BEGIN {EXCLUSIVE}
			IF (state < Terminating) THEN
				state := Working;
			END;
		END Start;

		PROCEDURE Terminate;
		BEGIN {EXCLUSIVE}
			IF (state # Terminated) THEN state := Terminating; END;
			AWAIT(state = Terminated);
		END Terminate;

		PROCEDURE Parse;
		VAR document : XML.Document; i : LONGINT;
		BEGIN
			i := 0;
			WHILE ~error & (i < nofTimes) & (state = Working) DO
				document := ParseFile(file, pooling);
				INC(i);
			END;
		END Parse;

	BEGIN {ACTIVE}
		BEGIN {EXCLUSIVE} AWAIT((state = Working) OR (state = Terminating)); END;
		IF (state = Working) THEN
			Parse;
		END;
		DecrementNofActiveWorkers;
		BEGIN {EXCLUSIVE} state := Terminated; END;
	END Worker;

VAR
	error : BOOLEAN;
	workers : POINTER TO ARRAY OF Worker;
	nofActiveWorkers : LONGINT;

PROCEDURE DecrementNofActiveWorkers;
BEGIN {EXCLUSIVE}
	DEC(nofActiveWorkers);
END DecrementNofActiveWorkers;

PROCEDURE ParseFile(file : Files.File; pooling : SET) : XML.Document;
VAR
	reader : Files.Reader;
	scanner : XMLScanner.Scanner;
	parser : XMLParser.Parser;
BEGIN
	ASSERT(file # NIL);
	NEW(reader, file, 0);
	NEW(scanner, reader);
	scanner.SetStringPooling(pooling);
	NEW(parser, scanner);
	parser.reportError := DefaultReportError;
	RETURN parser.Parse();
END ParseFile;

PROCEDURE BenchParser*(context : Commands.Context); (** [Options] filename ~ *)
VAR
	filename : Files.FileName; options : Options.Options;
	file : Files.File;
	i, nofTimes, nofWorkers : LONGINT;
	pooling : SET;
	start, end : Dates.DateTime;
	nofDays, nofHours, nofMinutes, nofSeconds : LONGINT;
BEGIN {EXCLUSIVE} (* protects global variable error *)
	NEW(options);
	options.Add("n", "nofTimes", Options.Integer);
	options.Add("p", "pooling", Options.Flag);
	options.Add("w", "workers", Options.Integer);
	IF options.Parse(context.arg, context.error) THEN
		IF context.arg.GetString(filename) THEN
			IF ~options.GetInteger("nofTimes", nofTimes) OR (nofTimes <= 0) THEN nofTimes := DefaultNofTimes; END;
			IF ~options.GetInteger("workers", nofWorkers) OR (nofWorkers <= 0) THEN nofWorkers := DefaultNofWorkers; END;
			IF ~options.GetFlag("pooling") THEN pooling := {}; ELSE pooling := {0..31}; END;
			IF (nofTimes MOD nofWorkers = 0) THEN
				ASSERT(nofTimes # 0);
				ASSERT(nofWorkers > 0);
				file := Files.Old(filename);
				IF (file # NIL) THEN
					context.out.String("Parsing file "); context.out.String(filename); context.out.String(" "); context.out.Int(nofTimes, 0); context.out.String(" times ");
					context.out.String(" using "); context.out.Int(nofWorkers, 0); context.out.String(" worker threads ...");
					context.out.Update;
					NEW(workers, nofWorkers);
					nofTimes := nofTimes DIV nofWorkers;
					nofActiveWorkers := nofWorkers;
					FOR i := 0 TO nofWorkers - 1 DO NEW(workers[i], file, nofTimes, pooling); END;
					start := Dates.Now();
					FOR i := 0 TO nofWorkers - 1 DO workers[i].Start; END;
					error := FALSE;
					AWAIT(nofActiveWorkers = 0);
					workers := NIL;
					end := Dates.Now();
					Dates.TimeDifference(start, end, nofDays, nofHours, nofMinutes, nofSeconds);
					nofSeconds := ToSeconds(nofDays, nofHours, nofMinutes, nofSeconds);
					context.out.String("done in "); Strings.ShowTimeDifference(start, end, context.out);
					context.out.String(" (");
					context.out.FloatFix(nofSeconds / (nofTimes * nofWorkers), 8, 3, 0);
					context.out.String(")"); context.out.Ln;
				ELSE
					context.error.String("File "); context.error.String(filename); context.error.String(" not found.");
					context.error.Ln;
				END;
			ELSE
				context.error.String("Parameter error: nofTimes MOD nofWorkers # 0"); context.error.Ln;
			END;
		ELSE
			ShowUsage(context.error);
		END;
	END;
END BenchParser;

PROCEDURE ToSeconds(nofDays, nofHours, nofMinutes, nofSeconds : LONGINT) : LONGINT;
BEGIN
	RETURN (86400 * nofDays + 3600 * nofHours + 60 * nofMinutes + nofSeconds);
END ToSeconds;

PROCEDURE DefaultReportError(pos, line, col: Streams.Position; CONST msg: ARRAY OF CHAR);
BEGIN
	error := TRUE;
	KernelLog.Enter; KernelLog.Char(CHR(9H)); KernelLog.Char(CHR(9H)); KernelLog.String("pos "); KernelLog.Int(pos, 6);
	KernelLog.String(", line "); KernelLog.Int(line, 0); KernelLog.String(", col "); KernelLog.Int(col, 0);
	KernelLog.String("    "); KernelLog.String(msg); KernelLog.Exit;
END DefaultReportError;

PROCEDURE ShowUsage(out : Streams.Writer);
BEGIN
	ASSERT(out # NIL);
	out.String("Usage: BenchXML.Bench [Options] filename ~"); out.Ln;
END ShowUsage;

PROCEDURE Cleanup;
VAR i : SIZE;
BEGIN
	IF (workers # NIL) THEN
		FOR i := 0 TO LEN(workers)-1 DO
			workers[i].Terminate;
		END;
		workers := NIL;
	END;
END Cleanup;

BEGIN
	workers := NIL;
	Modules.InstallTermHandler(Cleanup);
END BenchXML.

System.DoCommands
	BenchXML.BenchParser --nofTimes=16 Test.XML ~
	BenchXML.BenchParser --nofTimes=16 --workers=2 Test.XML ~
	BenchXML.BenchParser --nofTimes=16 --workers=4 Test.XML ~
	BenchXML.BenchParser --nofTimes=16 --workers=8 Test.XML ~
~

System.DoCommands
	BenchXML.BenchParser --nofTimes=16 --pooling Test.XML ~
	BenchXML.BenchParser --nofTimes=16 --workers=2 --pooling Test.XML ~
	BenchXML.BenchParser --nofTimes=16 --workers=4 --pooling Test.XML ~
	BenchXML.BenchParser --nofTimes=16 --workers=8 --pooling Test.XML ~
~

System.Free BenchXML ~
