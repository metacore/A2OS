(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE ISO9660Volumes;	(* AUTHOR "?/be"; PURPOSE "ISO 9660 volume (ported from Native Oberon)" *)

(** non-portable *)

	IMPORT
		KernelLog, Plugins, Disks, Files;

	CONST
		debug = FALSE; getBlockDebug = FALSE;

	CONST	(* svr *)
		SS = 2048;	(* sector size *)
		MaxRetries = 10;

	TYPE
		Volume* = OBJECT (Files.Volume)
		VAR
			dev-: Disks.Device;
			bpc: SIGNED32;	(* bytes per sector *)
			spc: SIGNED32;	(* sectors per cluster *)

			PROCEDURE Finalize*;
			VAR res: INTEGER;
			BEGIN {EXCLUSIVE}
				IF debug THEN KernelLog.String("Entering OFSISO9660Volumes.Finalize"); KernelLog.Ln END;
				EXCL(dev.flags, Disks.Mounted);
				dev.Close(res)
			END Finalize;

			PROCEDURE Available*(): SIGNED32;
			BEGIN
				RETURN 0
			END Available;

			PROCEDURE GetBlock*(adr: SIGNED32; VAR blk: ARRAY OF CHAR);
			VAR res: INTEGER; i: SIGNED32;
			BEGIN {EXCLUSIVE}
				ASSERT(dev # NIL, 101);
				i := 0;
				REPEAT
					dev.Transfer(Disks.Read, adr, 1, blk, 0, res);
					INC(i)
				UNTIL (res = 0) OR (i >= MaxRetries);
				IF getBlockDebug & (i > 1) THEN KernelLog.String("GetBlock; "); KernelLog.Int(i, 0); KernelLog.String(" retries"); KernelLog.Ln END;
				ASSERT(res = 0, 102)
			END GetBlock;

			PROCEDURE AllocBlock*(hint: Files.Address; VAR adr: Files.Address);
			BEGIN HALT(301)
			END AllocBlock;

			PROCEDURE FreeBlock*(adr: Files.Address);
			BEGIN HALT(301)
			END FreeBlock;

			PROCEDURE MarkBlock*(adr: Files.Address);
			BEGIN HALT(301)
			END MarkBlock;

			PROCEDURE Marked*(adr: Files.Address): BOOLEAN;
			BEGIN HALT(301)
			END Marked;
		END Volume;

PROCEDURE GetISO9660Volume(p: Files.Parameters; dev: Disks.Device);
VAR vol: Volume; b: ARRAY SS OF CHAR;
BEGIN
	NEW(vol); vol.flags := {}; vol.dev := dev;
	INCL(vol.flags, Files.ReadOnly); INCL(vol.flags, Files.Removable);
	vol.bpc := SS; vol.spc := 1;
	vol.GetBlock(16, b); (* dummy; necessary after disc change *)
	COPY(vol.dev.name, vol.name);
	vol.blockSize := vol.bpc;
	IF debug THEN
		KernelLog.String("GetISO9660Volume"); KernelLog.Ln;
		KernelLog.String("  spc="); KernelLog.Int(vol.spc, 0); KernelLog.String("  bpc="); KernelLog.Int(vol.bpc, 0); KernelLog.Ln
	END;
	p.vol := vol
END GetISO9660Volume;

(** Generate a new ISO9660 volume object. Files.Par: device [# part (ignored)] *)
PROCEDURE New*(context : Files.Parameters);
VAR
	name: Plugins.Name;  i, ignore: SIGNED32; res: INTEGER;
	table: Plugins.Table; dev: Disks.Device;
BEGIN
	context.vol := NIL;
	Files.GetDevPart(context.arg, name, ignore);
	IF (name # "") THEN
		Disks.registry.GetAll(table);
		IF (table # NIL) THEN
			context.out.String("ISO9660Volumes: Device ");  context.out.String(name);

			i := 0; WHILE (i # LEN(table)) & (table[i].name # name) DO INC(i) END;
			IF (i < LEN(table)) THEN
				dev := table[i](Disks.Device);
				dev.Open(res);
				IF (res = Disks.Ok) THEN
					IF ~(Disks.Mounted IN dev.table[0].flags) THEN
						GetISO9660Volume(context, dev);
					ELSE context.error.String(" already mounted")
					END;

					IF (context.vol = NIL) THEN
						dev.Close(res) (* close again - ignore res *)
					END
				ELSE context.error.String(" cannot open device"); context.error.Ln;
				END
			ELSE context.error.String(" not found"); context.error.Ln;
			END;
		END
	END;
END New;

END ISO9660Volumes.

OFSTools.Mount TEST "IDE1.0" OFSISO9660Volumes.New OFSN2KFiles.NewFS
OFSTools.Mount A "Diskette0" OFSISO9660Volumes.New OFSN2KFiles.NewFS
OFSTools.Unmount ^ TEST A


System.Free OFSISO9660Volumes ~