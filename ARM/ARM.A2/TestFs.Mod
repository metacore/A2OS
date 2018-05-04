MODULE TestFs;

IMPORT
	SYSTEM, Random, Files, Kernel, Commands, FoxBasic;

TYPE

	Writer  = OBJECT
	VAR
		id: LONGINT;
		file: Files.File;
		fw: Files.Writer;
		fileSize: LONGINT;
		byteCount: LONGINT;
		rndData, rndUpdate: Random.Generator;

		tStart: Kernel.MilliTimer;

		run := FALSE, exited := FALSE: BOOLEAN;

		PROCEDURE &InitWriter(id: LONGINT; CONST fileName: ARRAY OF CHAR; fileSize: LONGINT);
		BEGIN

			file := Files.New(fileName);
			ASSERT(file # NIL);
			Files.Register(file);

			Files.OpenWriter(fw,file,0);

			NEW(rndData);
			rndData.InitSeed(id);

			NEW(rndUpdate);
			rndUpdate.InitSeed(-id);

			SELF.id := id;
			SELF.fileSize := fileSize;

			run := TRUE;
		END InitWriter;

		PROCEDURE Exit;
		BEGIN{EXCLUSIVE}
			run := FALSE;
			AWAIT(exited);
		END Exit;

		PROCEDURE Start;
		BEGIN {EXCLUSIVE}
			run := TRUE
		END Start;

		PROCEDURE Pause;
		BEGIN {EXCLUSIVE}
			run := FALSE
		END Pause;

		PROCEDURE Running (): BOOLEAN;
		BEGIN {EXCLUSIVE}
			RETURN run
		END Running;

		PROCEDURE Exited (): BOOLEAN;
		BEGIN {EXCLUSIVE}
			RETURN exited
		END Exited;

		PROCEDURE Loop1;
		VAR
			v: LONGINT;
		BEGIN
			WHILE run & (byteCount < fileSize) DO
				v := rndData.Dice(256);
				fw.Char(CHR(v));
				INC(byteCount);
				IF rndUpdate.Dice(4096) = 0 THEN (* Files.DefaultWriterSize *)
					fw.Update;
				END;
			END;

			fw.Update;
			run := FALSE;
		END Loop1;

		PROCEDURE Loop2;
		TYPE
			Char4 = ARRAY 4 OF CHAR;
		VAR
			buf: ARRAY 4096 OF CHAR; (* Files.DefaultWriterSize *)
			v: LONGINT;
			i: LONGINT;
		BEGIN
			WHILE run & (byteCount < fileSize) & (fw.res = 0) DO
				FOR i := 0 TO LEN(buf)-1 BY 4 DO
					v := rndData.Integer();
					SYSTEM.MOVE(ADDRESSOF(v),ADDRESSOF(buf[i]),SIZEOF(LONGINT));
				END;
				fw.Bytes(buf,0,LEN(buf));
				fw.Update;
				INC(byteCount,LEN(buf));
			END;

			run := FALSE;

			IF fw.res # 0 THEN
				TRACE("TestFs writer",id,"stopped due to a writer error",fw.res);
			END;
		END Loop2;

	BEGIN{ACTIVE}
		Kernel.SetTimer(tStart,0);

		Loop1;

	FINALLY
		BEGIN{EXCLUSIVE}
			exited := TRUE;
		END;
	END Writer;

	(* High-level reader activity *)
	Reader = OBJECT
	VAR
		id: LONGINT;
		file: Files.File;
		reader: Files.Reader;
		rndData: Random.Generator;
		byteCount: LONGINT;
		run, exited: BOOLEAN;

		tStart: Kernel.MilliTimer;

		PROCEDURE & Init*(id: LONGINT; CONST filename: ARRAY OF CHAR);
		BEGIN
			SELF.id := id;
			file := Files.Old(filename);
			ASSERT(file # NIL);
			Files.OpenReader(reader, file, 0);
			ASSERT(reader # NIL);
			NEW(rndData);
			rndData.InitSeed(id);
			run := TRUE;
		END Init;

		PROCEDURE Exit;
		BEGIN {EXCLUSIVE}
			run := FALSE;
			AWAIT(exited);
		END Exit;

		PROCEDURE Start;
		BEGIN {EXCLUSIVE}
			run := TRUE
		END Start;

		PROCEDURE Pause;
		BEGIN {EXCLUSIVE}
			run := FALSE
		END Pause;

		PROCEDURE Running (): BOOLEAN;
		BEGIN {EXCLUSIVE}
			RETURN run
		END Running;

		PROCEDURE Exited (): BOOLEAN;
		BEGIN {EXCLUSIVE}
			RETURN exited
		END Exited;

		PROCEDURE Loop;
		VAR
			buf: ARRAY 4096 OF CHAR;
			i, len: LONGINT;
		BEGIN
			WHILE run & (reader.res = 0) DO
				reader.Bytes(buf, 0, LEN(buf), len);
				INC(byteCount, len);
				FOR i := 0 TO len - 1 DO ASSERT(ORD(buf[i]) = rndData.Dice(256)); END;
			END
		END Loop;

	BEGIN {ACTIVE}
		Kernel.SetTimer(tStart, 0);
		Loop;
	FINALLY
		BEGIN {EXCLUSIVE}
			exited := TRUE;
		END;
	END Reader;

VAR
	writers: FoxBasic.List;
	readers: FoxBasic.List;

	(**
		Start id fileName fileSize ~
	*)
	PROCEDURE StartWriter*(ctx: Commands.Context);
	VAR
		id: LONGINT;
		fileName: Files.FileName;
		fileSize: LONGINT;
		w: Writer;
		i: LONGINT;
	BEGIN{EXCLUSIVE}
		IF ~ctx.arg.GetInteger(id,FALSE) THEN ctx.result := 1; RETURN; END;
		IF ~ctx.arg.GetString(fileName) THEN ctx.result := 1; RETURN;END;
		IF ~ctx.arg.GetInteger(fileSize,FALSE) THEN ctx.result := 1; RETURN; END;

		i := 0;
		WHILE (i < writers.Length()) & (writers.Get(i)(Writer).id # id) DO
			INC(i);
		END;

		IF i < writers.Length() THEN
			ctx.error.String("TestFs writer with ID "); ctx.error.Int(id,0); ctx.error.String(" already running"); ctx.error.Ln;
			ctx.result := 1;
			RETURN;
		END;

		NEW(w,id,fileName,fileSize);

		writers.Add(w);

		ctx.out.String("Started TestFs writer with ID "); ctx.out.Int(id,0);
		ctx.out.String(", fileName='"); ctx.out.String(fileName);
		ctx.out.String("', fileSize="); ctx.out.Int(fileSize,0); ctx.out.Ln;
	END StartWriter;

	(* ID *)
	PROCEDURE StopWriter*(ctx: Commands.Context);
	VAR
		id: LONGINT;
		i: LONGINT;
	BEGIN{EXCLUSIVE}
		IF ~ctx.arg.GetInteger(id,FALSE) THEN ctx.result := 1; RETURN; END;

		i := 0;
		WHILE (i < writers.Length()) & (writers.Get(i)(Writer).id # id) DO
			INC(i);
		END;

		IF i < writers.Length() THEN
			writers.Get(i)(Writer).Exit;
			writers.RemoveByIndex(i);
			ctx.out.String("Stopped TestFs writer with ID "); ctx.out.Int(id,0); ctx.out.Ln;
		ELSE
			ctx.error.String("TestFs writer with ID "); ctx.error.Int(id,0); ctx.error.String(" not found"); ctx.error.Ln;
			ctx.result := 1;
			RETURN;
		END;
	END StopWriter;

	(**
		ReportWriter id ~
	*)
	PROCEDURE ReportWriter*(ctx: Commands.Context);
	VAR
		id: LONGINT;
		i: LONGINT;
		w: Writer;
		speed: REAL;
	BEGIN{EXCLUSIVE}
		IF ~ctx.arg.GetInteger(id,FALSE) THEN ctx.result := 1; RETURN; END;

		i := 0;
		WHILE (i < writers.Length()) & (writers.Get(i)(Writer).id # id) DO
			INC(i);
		END;

		IF i < writers.Length() THEN
			w := writers.Get(i)(Writer);
			ctx.out.String("byteCount="); ctx.out.Int(w.byteCount,0); ctx.out.Ln;

			speed := 1000.0 * REAL(w.byteCount) / Kernel.Elapsed(w.tStart);
			ctx.out.String("overall speed="); ctx.out.FloatFix(speed,0,5,0); ctx.out.String(" bytes/s"); ctx.out.Ln;
			ctx.out.String("status: ");
			IF w.Exited() THEN
				ctx.out.String("Finished");
			ELSIF w.Running() THEN
				ctx.out.String("Running");
			ELSE
				ctx.out.String("Paused");
			END;
			ctx.out.Ln;
		ELSE
			ctx.error.String("TestFs writer with ID "); ctx.error.Int(id,0); ctx.error.String(" not found"); ctx.error.Ln;
			ctx.result := 1;
			RETURN;
		END;

	END ReportWriter;

	PROCEDURE StartReader*(context : Commands.Context);
	VAR
		name: Files.FileName;
		r: Reader;
		id: LONGINT;
		i: LONGINT;
	BEGIN {EXCLUSIVE}
		IF ~context.arg.GetInteger(id, FALSE) THEN context.result := 1; RETURN; END;
		IF ~context.arg.GetString(name) THEN context.result := 1; RETURN; END;

		WHILE (i < readers.Length()) & (readers.Get(i)(Reader).id # id) DO INC(i); END;
		IF i < readers.Length() THEN
			context.error.String("TestFs reader with ID ");
			context.error.Int(id, 0);
			context.error.String(" already running.");
			context.error.Ln;
			context.result := 1;
			RETURN;
		END;
		NEW(r, id, name);
		readers.Add(r);

		context.out.String("Added TestFs reader with ID ");
		context.out.Int(id, 0);
		context.out.String(", filename='");
		context.out.String(name);
		context.out.String("'");
		context.out.Ln;
	END StartReader;

	PROCEDURE StopReader*(context : Commands.Context);
	VAR
		r: Reader;
		id: LONGINT;
		i: LONGINT;
	BEGIN {EXCLUSIVE}
		IF ~context.arg.GetInteger(id, FALSE) THEN context.result := 1; RETURN; END;

		WHILE (i < readers.Length()) & (readers.Get(i)(Reader).id # id) DO INC(i); END;
		IF i = readers.Length() THEN
			context.error.String("TestFs reader with ID ");
			context.error.Int(id, 0);
			context.error.String(" is not running");
			context.error.Ln;
			context.result := 1;
			RETURN;
		END;

		r := readers.Get(i)(Reader);
		r.Exit;
		readers.RemoveByIndex(i);

		context.out.String("TestFs reader ");
		context.out.Int(id, 0);
		context.out.String(" stopped");
		context.out.Ln;
	END StopReader;

	PROCEDURE ReportReader*(context : Commands.Context);
	VAR
		r: Reader;
		id: LONGINT;
		i: LONGINT;
		bytes: LONGINT;
		speed: LONGREAL;
	BEGIN {EXCLUSIVE}
		IF ~context.arg.GetInteger(id, FALSE) THEN context.result := 1; RETURN; END;
		WHILE (i < readers.Length()) & (readers.Get(i)(Reader).id # id) DO INC(i); END;
		IF i = readers.Length() THEN
			context.error.String("TestFs reader with ID ");
			context.error.Int(id, 0);
			context.error.String(" is not running");
			context.error.Ln;
			context.result := 1;
			RETURN;
		END;
		r := readers.Get(i)(Reader);
		bytes := r.byteCount;
		speed := 1000.0 * bytes / Kernel.Elapsed(r.tStart);

		context.out.String("byte count="); context.out.Int(r.byteCount, 0); context.out.Ln;
		context.out.String("overall speed="); context.out.FloatFix(speed,0,5,0); context.out.Ln;
		context.out.String("status: ");
		IF r.Exited() THEN
			context.out.String("Finished");
		ELSIF r.Running() THEN
			context.out.String("Running");
		ELSE
			context.out.String("Paused");
		END;
		context.out.Ln;
	END ReportReader;

BEGIN
	NEW(writers,8);
	NEW(readers, 8);
END TestFs.

SystemTools.DoCommands
	TFTPServer.Start ~
	OEB.NewServer --type=Auto
		PLAN
			setsource TFTP 10.3.34.188
			mount A2 SD0 3
			load A2.Bin a2
			load build/TestFs.Gof t
			deploy t file A2:TestFs.Gof
			setinput auto.txt
		END
	~
	(*OEB.NewServer --type=Interactive ~*)
	OEB.NewInterface --type=Udp --server=0 ~
	OEB.Server --start --all ~
	OEB.Interface --start --all --server=0 ~
~
SystemTools.DoCommands
	TFTPServer.Start ~
	OEB.NewServer --type=Interactive ~
	OEB.NewInterface --type=Udp --server=0 ~
	OEB.Server --start --all ~
	OEB.Interface --start --all --server=0 ~
~

StaticLinker.Link --fileName=A2.Bin --displacement=100000H -a --path=build/
	Runtime Initializer Platform FPE64 ARMRuntime Trace BootConfig Uart Machine Heaps Modules Objects Kernel KernelLog Plugins
	Streams Pipes Commands Reals Clock Dates Strings Files Disks Reflection TrapWriters Traps Locks Options PsConfig SdEnvironment
	Sd SdDisks SdControllers Caches DiskVolumes DiskFS BitSets StringPool ObjectFile Diagnostics GenericLinker GenericLoader
	BootConsole
~

OEB.Command --server=0 --id=0
	setsource TFTP 10.3.34.188
	mount A2 SD0 3
	load A2.Bin a2
	save a2
	setinput auto.txt
~
	save a2
~

OEB.Command --server=0 --id=0
	setsource TFTP 10.3.34.188
	mount A2 SD0 3
	deployfile build/TestFs.Gof A2:TestFs.Gof
~

OEB.Command --server=0 --id=0
	start
~

OEB.Command --server=0 --id=0
	setinput auto.txt
~

OEB.Command --server=0 --id=0
	reset
~

OEB.Interface --show --all --server=0 ~
OEB.Server --show --all ~
OEB.Session --show --all ~
OEB.Server --kill --all ~
SystemTools.FreeDownTo OEBInterfaces ~
SystemTools.FreeDownTo UDP ~

mount DATA AosFS SD0#4 '|' N

TestFs.StartWriter 1234567 DATA:TestFs-123457.dat 1000000000
TestFs.StartWriter 7654321 DATA:TestFs-7654321.dat 1000000000


TestFs.StartReader 1234567 DATA:TestFs-123457.dat 1000000000
TestFs.StartReader 7654321 DATA:TestFs-7654321.dat

TestFs.ReportWriter 1234567
TestFs.ReportWriter 7654321
TestFs.ReportReader 1234567
TestFs.ReportReader 1234567
asd