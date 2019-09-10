(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Partitions IN Oberon; (** non-portable *)
(** AUTHOR "pjm"; PURPOSE "Partitioning and formatting tool"; *)

(* Partitioning and formatting tool for N2KFS and AosFS. *)

IMPORT Kernel, Modules, Disks, Files, Fonts, Texts, Input, Oberon, In;

CONST
	Trace = TRUE;
	ShowReserved = FALSE;	(* Show reserved space in partitions *)

	BS = 512;
	BootLoaderName = "OBL.Bin";
	BootFileName = "IDE.Bin";
	MinPartSize = 64;	(* absolute minimum number of sectors in Oberon partition *)

	N2KSS = 2048;
	N2KBPS = N2KSS DIV BS;
	N2KDirMark = SIGNED32(9B1EA38DH);

	AosSSLog2 = 12;
	AosSS = ASH(1, AosSSLog2);
	AosBPS = AosSS DIV BS;
	AosSF = 29;
	AosSTS = 128;
	AosXS = AosSS DIV 4;
	AosHS = 568;
	AosDirMark = SIGNED32(9B1EA38DH);

	AosType = 76;
	NativeType1 = 79;
	NativeType2 = 80;

	FSID = 21534F41H;
	FSID0 = 5245424FH;
	FSIDOBL = 44494449H;
	FSVer = 2;
	FSRes = 640*1024 DIV BS;	(* default blocks reserved for boot file *)

	LoaderSize = 4;	(* size of OBL.Bin in blocks *)

	Read = Disks.Read; Write = Disks.Write;

	Ok = Disks.Ok;

	NumFlop = 2;

	MaxConfig = 2000;	(* less than tsize*BS *)

	WholeDisk = 256;
	FreeSpace = -1;
	ReservedSpace = -2;

	NoSpaceAvailable = 9001;
	CoreMismatch = 9002;	(* core file on disk does not match *)
	CoreChecksumError = 9003;	(* core file checksum mismatch *)
	OutOfSlots = 9004;	(* out of primary partition slots *)
	PartitionTooSmall = 9005;	(* partition too small to create *)
	Interrupted = MAX(SIGNED32);

	DisketteLimit = 2880;	(* if device has <= this many sectors, assume it is a diskette without partition table *)

TYPE
	ConfigTable = POINTER TO ARRAY OF CHAR;

VAR
	w: Texts.Writer;
	hex: ARRAY 17 OF CHAR;
	safe: BOOLEAN;

(*
	OBL variables (in boot block)

	ofs	size	description
	00	03	?,?,?
	03	06	"OBERON"
	09	01	?
	0A	01	flag (if 0, start config string editor, otherwise, bits 0-4 tested with shift bits from BIOS)
	0B	02	?
	0D	01	?
	0E	02	reserved blocks
	10	01	config table size in blocks
	11	02	?
	13	02	total blocks (or 0)
	15	01	?
	16	02	?
	18	02	blocks per track
	1A	02	heads
	1C	04	boot block number
	20	04	total blocks (if 13 is 0)
	24	01	drive number (0, 1 for floppy, 80H, 81H, ... for hard disk)

	AosFS Table Format (in boot block)

	New (post 14.03.00)
	1F0H	4	fileSystemOfs (in 512-byte blocks, relative to this block)
	1F4H	4	fileSystemSize (in sectors, aka volume blocks)
	1F8H	4	id = 21534F41H ("AOS!")
	1FCH	1	version = 1X
	1FDH	1	sectorSizeLog2 = 12 (4096)
	1FEH	1	bootID0 = 055X
	1FFH	1	bootID1 = 0AAX

	Old (pre 14.03.00)
	1E0H	4	fileSystemOfs (in blocks, relative to this block)
	1E4H	4	fileSystemSize (in sectors)
	1E8H	16	volumeName (0X-terminated)
	1F8H	4	id = 5245424FH ("OBER")
	1FCH	1	version = 1X
	1FDH	1	sectorSizeLog2 = 12 (4096)
	1FEH	1	bootID0 = 055X
	1FFH	1	bootID1 = 0AAX

	Partition layout (N2KFS and AosFS overlayed)

	block	description
	0..3	OBL.Bin (4 blocks)
		<-- LoaderSize
	4..7	Config table (size from 10H)
		<-- start of BootFile
		<-- reserved blocks pointer (from 0EH)
	x..	N2KFS
		<-- fileSystemOfs pointer (from 1F0H)
	y..	AosFS
*)

(* Write partition type *)

PROCEDURE WriteType(VAR w: Texts.Writer; type: SIGNED32);
VAR s: ARRAY 40 OF CHAR;
BEGIN
(* list from Linux fdisk, Microsoft Partitioning Summary (Q69912), Hal Landis' list & Jacques Eloff, http://home.global.co.za/~eloffjl/parcodes.html *)
	CASE type OF
		|001H: s := "DOS FAT12"
		|002H: s := "Xenix root"
		|003H: s := "Xenix usr"
		|004H: s := "DOS FAT16 < 32M"
		|005H: s := "Extended"
		|006H: s := "DOS FAT16 >= 32M"
		|007H: s := "NTFS, HPFS, QNX, Adv. Unix"
		|008H: s := "AIX boot, SplitDrive, QNX qny"
		|009H: s := "AIX data, Coherent swap, QNX qnz"
		|00AH: s := "OS/2 BM, Coherent swap"
		|00BH: s := "Win 95/98, FAT32"
		|00CH: s := "Win 95/98, FAT32 LBA"

		|00EH: s := "DOS FAT16 LBA"
		|00FH: s := "Extended LBA"
		|010H: s := "Opus"
		|011H: s := "OS/2 BM: Hidden FAT12"
		|012H: s := "Xenix, SCO, Compaq diag."
		|013H: s := "Xenix, SCO"
		|014H: s := "OS/2 BM: Hidden FAT16 < 32M"

		|016H: s := "OS/2 BM: Hidden FAT16 >= 32M"
		|017H: s := "OS/2 BM: Hidden IFS"
		|018H: s := "AST Windows"
		|019H: s := "Interactive Unix, SCO"

		|024H: s := "NEC DOS"
		|028H..029H: s := "THEOS"

		|038H..039H: s := "THEOS"

		|03CH: s := "PQMagic recovery"

		|040H: s := "Venix 80286"
		|041H: s := "Linux/Minix, DR-DOS"
		|042H: s := "SFS, Linux swap, DR-DOS"
		|043H: s := "Linux fs, DR-DOS"

		|04CH: s := "Native Oberon, Aos"
		|04DH: s := "Switcherland or QNX Posix"
		|04EH: s := "Active or QNX Posix"
		|04FH: s := "Native Oberon or QNX Posix"
		|050H: s := "Native Oberon alt. or Lynx RTOS, DM"
		|051H: s := "Novell Netware, Ontrack Ext, DM6 Aux 1"
		|052H: s := "Microport SysV/AT, CP/M"
		|053H: s := "DM6 Aux 3"
		|054H: s := "NTFS, DM6"
		|055H: s := "EZ-Drive, DM"
		|056H: s := "Golden Bow, DM"

		|05CH: s := "Priam EDisk, DM"
		|05DH..05EH: s := "QNX"

		|061H: s := "SpeedStor"
		|062H: s := "Pick"
		|063H: s := "GNU HURD, Mach, Sys V/386, ISC UNIX"
		|064H: s := "Novell Netware 286"
		|065H: s := "Novell Netware 386"
		|066H..69H: s := "Novell Netware"
		|070H: s := "Disk Secure Multi-Boot"

		|072H: s := "Pick"
		|073H: s := "Unix, SCO"
		|074H: s := "Novell Netware"
		|075H: s := "PC/IX"

		|077H..079H: s := "QNX 4.x"
		|080H: s := "Minix <= 1.4a"
		|081H: s := "Minix > 1.4b, old Linux, Mitax DM"
		|082H: s := "Linux swap"
		|083H: s := "Linux fs"
		|084H: s := "OS/2 Hidden C: drive"
		|085H: s := "Linux ext"
		|086H..087H: s := "NTFS volume"

		|093H..094H: s := "Amoeba"

		|0A0H: s := "IBM Thinkpad hibernation"

		|0A5H: s := "BSD i386"

		|0A7H: s := "NeXTSTEP 486"

		|0B5H: s := "FreeBSD"

		|0B7H: s := "BSDI fs"
		|0B8H: s := "BSDI swap"

		|0C0H: s := "CTOS"
		|0C1H: s := "DRDOS/sec FAT12"

		|0C4H: s := "DRDOS/sec FAT16 < 32M"
		|0C6H: s := "DRDOS/sec FAT16 >= 32M"
		|0C7H: s := "Syrinx"

		|0CBH: s := "CP/M, DR"

		|0CDH: s := "CTOS, Mem"

		|0D0H: s := "CTOS"

		|0DBH: s := "CP/M, Concurrent CP/M, DOS, CTOS"

		|0DDH: s := "CTOS, Mem"

		|0DFH: s := "Datafusion"

		|0E1H: s := "DOS access, SpeedStor FAT12 ext"
		|0E2H: s := "Gneiss"
		|0E3H: s := "DOS R/O, SpeedStor, Oberon old"
		|0E4H: s := "SpeedStor FAT16 ext"

		|0F1H: s := "SpeedStor"
		|0F2H: s := "DOS 3.3 secondary"

		|0F4H: s := "SpeedStor large"

		|0FEH: s := "SpeedStor > 1024 cyl, LANstep"
		|0FFH: s := "Xenix BBT"
		|WholeDisk: s := "(Whole disk)"
		|FreeSpace: s := "(Free)"
		|ReservedSpace: s := "(Reserved)"	(* boot records, alignment, test track *)
		ELSE s := "Unknown"
	END;

	Texts.WriteString(w, s);
(*
	IF s = "" THEN
		Texts.WriteString(w, "Type "); Texts.WriteInt(w, type, 1)
	END
*)
END WriteType;

PROCEDURE WriteErrorMsg(VAR w: Texts.Writer; res: INTEGER);
BEGIN
	IF res = Disks.MediaChanged THEN
		Texts.WriteString(w, "media changed")
	ELSIF res = Disks.WriteProtected THEN
		Texts.WriteString(w, "write-protected")
	ELSIF res = Disks.Unsupported THEN
		Texts.WriteString(w, "unsupported")
	ELSIF res = Disks.DeviceInUse THEN
		Texts.WriteString(w, "device in use")
	ELSIF res = Disks.MediaMissing THEN
		Texts.WriteString(w, "no media")
	ELSIF res = NoSpaceAvailable THEN
		Texts.WriteString(w, "no space for bootfile")
	ELSIF res = OutOfSlots THEN
		Texts.WriteString(w, "no primary partition slots")
	ELSE
		Texts.WriteString(w, "error "); Texts.WriteInt(w, res, 1)
	END
END WriteErrorMsg;

PROCEDURE WriteTransferError(VAR w: Texts.Writer; dev: Disks.Device; op, start, res: SIGNED32);
BEGIN
	CASE op OF
		Read: Texts.WriteString(w, "Read")
		|Write: Texts.WriteString(w, "Write")
		ELSE Texts.WriteString(w, "I/O")
	END;
	Texts.WriteString(w, " on "); Texts.WriteString(w, dev.name);
	Texts.Write(w, ":"); Texts.WriteInt(w, start, 1);
	Texts.WriteString(w, " failed, ");
	WriteErrorMsg(w, res)
END WriteTransferError;

PROCEDURE IsDOS(type: SIGNED32): BOOLEAN;	(* see FATFiles.IsDOS *)
BEGIN
	RETURN FALSE	(* FATFiles no longer used *)
	(*RETURN (type = 1) OR (type = 4) OR (type = 6)	(* DOS partition *)*)
END IsDOS;

PROCEDURE WriteK(VAR W: Texts.Writer; k: SIGNED32);
VAR suffix: CHAR;
BEGIN
	IF k < 10*1024 THEN suffix := "K"
	ELSIF k < 10*1024*1024 THEN suffix := "M"; k := k DIV 1024
	ELSE suffix := "G"; k := k DIV (1024*1024)
	END;
	Texts.WriteInt(W, k, 1); Texts.Write(W, suffix); Texts.Write(W, "B")
END WriteK;

PROCEDURE Progress(t: Texts.Text; now, max: SIGNED32; VAR next: SIGNED32);
CONST Inc = 10;
VAR pc: SIGNED32;
BEGIN
	IF next = 0 THEN Texts.WriteString(w, "%:") END;
	pc := now*100 DIV max;
	WHILE pc >= next DO
		Texts.Write(w, " "); Texts.WriteInt(w, next, 1); Texts.Append(t, w.buf);
		INC(next, Inc)
	END
END Progress;

PROCEDURE UserInterrupt(VAR ch: CHAR): BOOLEAN;
BEGIN
	IF Input.Available() # 0 THEN
		ch := CHR(27);
		WHILE Input.Available() # 0 DO Input.Read(ch) END;
		RETURN TRUE
	ELSE
		RETURN FALSE
	END
END UserInterrupt;

PROCEDURE ShowDevice(VAR w: Texts.Writer; d: Disks.Device; verbose: BOOLEAN; VAR res: INTEGER);
VAR size: SIGNED32; geo: Disks.GetGeometryMsg;
BEGIN
	Texts.WriteString(w, "Disk: "); Texts.WriteString(w, d.name);
	d.getSize(d, size, res);
	IF res = Disks.MediaChanged THEN d.getSize(d, size, res) END;	(* we didn't use Open, so retry *)
	Texts.WriteString(w, ", ");
	IF res = Ok THEN
		WriteK(w, ENTIER(size * 1.0 * d.blockSize / 1024));
		IF verbose THEN
			Texts.WriteString(w, " = "); Texts.WriteInt(w, size, 1);
			Texts.WriteString(w, " * "); Texts.WriteInt(w, d.blockSize, 1)
		END
	ELSE
		Texts.WriteString(w, "GetSize: "); WriteErrorMsg(w, res)
	END;
	IF Disks.Removable IN d.flags THEN Texts.WriteString(w, ", removable") END;
	IF Disks.ReadOnly IN d.flags THEN Texts.WriteString(w, ", read-only") END;
	IF verbose THEN
		IF res # Disks.MediaMissing THEN
			Texts.WriteString(w, ", ");
			d.handle(d, geo, res);
			IF res = Ok THEN
				Texts.WriteString(w, "CHS: "); Texts.WriteInt(w, geo.cyls, 1);
				Texts.Write(w, "*"); Texts.WriteInt(w, geo.hds, 1);
				Texts.Write(w, "*"); Texts.WriteInt(w, geo.spt, 1)
			ELSE
				Texts.WriteString(w, "GetCHS: "); WriteErrorMsg(w, res)
			END
		END
	END;
	IF d.desc # "" THEN
		Texts.WriteString(w, ", "); Texts.WriteString(w, d.desc)
	END;
	IF verbose THEN
		Texts.WriteString(w, ", mntcnt="); Texts.WriteInt(w, d.openCount, 1)
	END;
	Texts.WriteLn(w)
END ShowDevice;

PROCEDURE WritePart(VAR w: Texts.Writer; dev: Disks.Device; part: SIGNED32);
BEGIN
	ASSERT((part >= 0) & (part <= 99));
	Texts.WriteString(w, dev.name); Texts.Write(w, "#");
	Texts.Write(w, CHR(48 + part DIV 10)); Texts.Write(w, CHR(48 + part MOD 10));
	Texts.Write(w, " ")
END WritePart;

PROCEDURE WriteTable(VAR w: Texts.Writer; d: Disks.Device; table: Disks.PartitionTable; verbose: BOOLEAN; VAR dosnum: SIGNED32);
VAR j: SIGNED32; r: FLOAT64;
BEGIN
	FOR j := 0 TO LEN(table)(SIGNED32)-1 DO
		r := (table[j].size * 1.0D0 * d.blockSize) / (1024*1024);	(* M *)
		WritePart(w, d, j);
		Texts.SetFont(w, Fonts.This("Courier10.Scn.Fnt"));
		IF verbose THEN
			Texts.WriteInt(w, table[j].start, 10);
			Texts.WriteInt(w, table[j].size, 10)
		END;
		IF r < 10 THEN Texts.WriteLongRealFix(w, r, 6, 1, 0)
		ELSE Texts.WriteInt(w, ENTIER(r), 6)
		END;
		Texts.WriteString(w, "MB ");
		IF (table[j].type >= 1) & (table[j].type <= 255) THEN
			Texts.WriteInt(w, table[j].type, 3)
		ELSE
			Texts.WriteString(w, "---")
		END;
		Texts.Write(w, " ");
		Texts.SetFont(w, Fonts.Default);
		IF (j # 0) & ~(Disks.Primary IN table[j].flags) THEN Texts.Write(w, "|") END;	(* logical drive *)
		IF Disks.Boot IN table[j].flags THEN Texts.WriteString(w, "* ") END;	(* bootable *)
		IF IsDOS(table[j].type) THEN
			Texts.Write(w, CHR(ORD("a")+dosnum)); Texts.WriteString(w, ":/ ");
			INC(dosnum)
		END;
		WriteType(w, table[j].type);
		IF verbose THEN
			(*IF Disks.Primary IN table[j].flags THEN Texts.WriteString(w, " [primary]") END;*)
			(*IF Disks.Boot IN table[j].flags THEN Texts.WriteString(w, " [boot]") END;*)
			IF Disks.Mounted IN table[j].flags THEN Texts.WriteString(w, " [mounted]") END
		END;
		Texts.WriteLn(w)
	END
END WriteTable;

(* Get geometry from partition table, if possible. *)

PROCEDURE GetTableGeometry(dev: Disks.Device; VAR hds, spt: SIGNED32): BOOLEAN;
VAR buf: ARRAY BS OF CHAR; res, p, hd, sec, i: SIGNED32; ok: BOOLEAN;
BEGIN
	ok := FALSE;
	ASSERT(dev.blockSize = BS);
	dev.transfer(dev, Disks.Read, 0, 1, buf, 0, res);
	IF (res = Ok) & (buf[510] = 055X) & (buf[511] = 0AAX) & (buf[01BEH+4] = 055X) THEN	(* EZDrive *)
		dev.transfer(dev, Disks.Read, 1, 1, buf, 0, res)	(* read sector 1 *)
	END;
	IF (res = Ok) & (buf[510] = 055X) & (buf[511] = 0AAX) THEN	(* valid partition table *)
		hds := -1;
		FOR i := 0 TO 3 DO	(* find end head and sector for each valid primary partition *)
			p := 01BEH + 16*i;
			IF buf[p+4] # 0X THEN	(* partition i in use *)
				hd := ORD(buf[p+5]); 	(* end head *)
				sec := ORD(buf[p+6]) MOD 64;	(* end sector *)
				IF hds = -1 THEN
					hds := hd+1; spt := sec; ok := TRUE	(* first partition found *)
				ELSIF (hds = hd+1) & (spt = sec) THEN
					(* skip *)
				ELSE
					ok := FALSE	(* inconsistent table *)
				END
			END
		END
	END;
	IF ~ok THEN hds := 0; spt := 0 END;
	RETURN ok
END GetTableGeometry;

(* Get drive geometry and adjust it. *)

PROCEDURE GetGeometry(dev: Disks.Device; VAR geo: Disks.GetGeometryMsg; VAR res: INTEGER);
VAR thds, tspt, dsize: SIGNED32; org: Disks.GetGeometryMsg;
BEGIN
	dev.handle(dev, geo, res);
	IF res # Ok THEN
		IF Trace THEN
			Kernel.WriteString("Partitions: GetGeometry result "); Kernel.WriteInt(res, 1); Kernel.WriteLn
		END;
		IF dev.blockSize = BS THEN	(* try getSize instead *)
			dev.getSize(dev, dsize, res);
			IF res = Ok THEN
				geo.cyls := 1; geo.hds := 1; geo.spt := dsize	(* fake it *)
			END
		END
	END;
	IF (res = Ok) & (dev.blockSize = BS) THEN	(* adjust geometry *)
		org := geo; dsize := geo.cyls*geo.hds*geo.spt;
		IF GetTableGeometry(dev, thds, tspt) THEN	(* adjust geometry to partition table *)
			geo.cyls := dsize DIV (thds*tspt);
			geo.hds := thds; geo.spt := tspt
		ELSIF (geo.cyls > 1024) OR (geo.hds > 255) OR (geo.spt > 63) THEN
			(* modify the parameters to be inside BIOS limits (for boot loader) *)
			(* BIOS limits: 1024 cylinders (0-1023), 255 heads (0-254), 63 sectors (1-63) (max size 8032M) *)
			geo.hds := 1; geo.spt := 63;
			REPEAT	(* try 2, 4, 8, 16, 32, 64, 128 and 255 heads *)
				geo.hds := geo.hds*2;
				geo.cyls := dsize DIV (geo.hds*geo.spt)
			UNTIL (geo.cyls <= 1023) OR (geo.hds = 256);
			IF geo.hds = 256 THEN geo.hds := 255; geo.cyls := dsize DIV (geo.hds*geo.spt) END
		ELSE
			(* skip - ok *)
		END;
		IF Trace THEN
			IF (org.cyls # geo.cyls) OR (org.hds # geo.hds) OR (org.spt # geo.spt) THEN
				Kernel.WriteString("Partitions: "); Kernel.WriteString(dev.name);
				Kernel.WriteChar(" ");
				Kernel.WriteInt(org.cyls, 1); Kernel.WriteChar("*");
				Kernel.WriteInt(org.hds, 1); Kernel.WriteChar("*");
				Kernel.WriteInt(org.spt, 1); Kernel.WriteChar("=");
				Kernel.WriteInt(dsize, 1); Kernel.WriteString(" -> ");
				Kernel.WriteInt(geo.cyls, 1); Kernel.WriteChar("*");
				Kernel.WriteInt(geo.hds, 1); Kernel.WriteChar("*");
				Kernel.WriteInt(geo.spt, 1); Kernel.WriteChar("=");
				Kernel.WriteInt(geo.cyls*geo.hds*geo.spt, 1); Kernel.WriteLn
			END
		END
	END
END GetGeometry;

PROCEDURE Extended(type: SIGNED32): BOOLEAN;
BEGIN
	RETURN (type = 5) OR (type = 15)
END Extended;

(* Add a free partition entry at the end (to keep partition numbers the same) *)

PROCEDURE NewFree(type: SIGNED32; VAR table: Disks.PartitionTable; start, size, ptblock: SIGNED32; flags: SET);
VAR j: SIGNED32; p: Disks.Partition; new: Disks.PartitionTable;
BEGIN
	p.type := type; p.start := start; p.size := size; p.flags := flags;
	p.ptblock := ptblock; p.ptoffset := 0;	(* find free ptoffset later *)
	NEW(new, LEN(table)+1); j := 0;
	WHILE j # LEN(table) DO new[j] := table[j]; INC(j) END;
	new[j] := p; table := new
END NewFree;

PROCEDURE FindFreePrimary(VAR table: Disks.PartitionTable; spt, hds: SIGNED32);
VAR i, g, t, max, start, end, prevstart, nextstart: SIGNED32;
BEGIN
	start := spt; g := hds * spt;	(* skip first track *)
	max := table[0].size - g;	(* reserve one cylinder at end of disk *)
	FOR i := 1 TO LEN(table)(SIGNED32)-1 DO	(* find overlapping partition, if any *)
		IF (Disks.Primary IN table[i].flags) & (table[i].start <= start) & (start < table[i].start+table[i].size) THEN
			start := table[i].start	(* start search at this partition instead *)
		END
	END;
	LOOP
		prevstart := start; end := MAX(SIGNED32);
		FOR i := 1 TO LEN(table)(SIGNED32)-1 DO	(* find first partition start after or on start *)
			IF (Disks.Primary IN table[i].flags) & (table[i].start >= start) & (table[i].start < end) THEN
				end := table[i].start	(* free space ends at this start position *)
			END
		END;
		IF end > max THEN end := max END;	(* clip to end of disk *)
			(* {start..end-1 is free} *)
		IF start # spt THEN INC(start, (-start) MOD g) END;	(* start on cylinder boundary (except first) *)
		DEC(end, end MOD g);	(* end on cylinder boundary *)
			(* {start..end-1 is free and aligned} *)
		IF end-start > 0 THEN NewFree(FreeSpace, table, start, end-start, 0, {Disks.Primary}) END;
		nextstart := MAX(SIGNED32);
		FOR i := 1 TO LEN(table)(SIGNED32)-1 DO	(* find first partition end after prevstart *)
			IF Disks.Primary IN table[i].flags THEN
				t := table[i].start+table[i].size-1;
				IF (t > prevstart) & (t < nextstart) THEN nextstart := t END
			END
		END;
		IF nextstart = MAX(SIGNED32) THEN
			EXIT	(* no more partitions end after prevstart *)
		ELSE
			start := nextstart+1
		END
	END
END FindFreePrimary;

PROCEDURE FindFreeExtended(VAR table: Disks.PartitionTable; spt, hds: SIGNED32);
VAR i, g, t, max, start, end, prevstart, nextstart: SIGNED32;
BEGIN
	t := -1; i := 1;
	WHILE i < LEN(table)(SIGNED32) DO
		IF Extended(table[i].type) THEN
			ASSERT(t = -1); t := i	(* at most one extended partition allowed *)
		END;
		INC(i)
	END;
	IF t # -1 THEN
		start := table[t].start; g := hds * spt; max := start + table[t].size;
		LOOP
			prevstart := start; end := MAX(SIGNED32);
			FOR i := 1 TO LEN(table)(SIGNED32)-1 DO	(* find first partition start after or on start *)
				IF ~(Disks.Primary IN table[i].flags) & (table[i].start >= start) & (table[i].start < end) THEN
					end := table[i].start
				END
			END;
			IF end > max THEN end := max END;
				(* {start..end-1 is free} *)
			IF start MOD g # spt THEN
				INC(start, (-start) MOD g + spt)	(* start on cylinder boundary, second head *)
			END;
			DEC(end, end MOD g);	(* end on cylinder boundary *)
				(* {start..end-1 is free and aligned} *)
			IF end-start > 0 THEN NewFree(FreeSpace, table, start, end-start, start-spt, {}) END;
			nextstart := MAX(SIGNED32);
			FOR i := 1 TO LEN(table)(SIGNED32)-1 DO	(* find first partition end after prevstart *)
				IF ~(Disks.Primary IN table[i].flags) THEN
					t := table[i].start+table[i].size-1;
					IF (t > prevstart) & (t < nextstart) THEN nextstart := t END
				END
			END;
			IF nextstart = MAX(SIGNED32) THEN
				EXIT	(* no more partitions end after prevstart *)
			ELSE
				start := nextstart+1
			END
		END
	END
END FindFreeExtended;

PROCEDURE FindReserved(VAR table: Disks.PartitionTable);
VAR i, t, max, start, end, prevstart, nextstart: SIGNED32;
BEGIN
	 IF ShowReserved THEN
		start := 0; max := table[0].size;
		LOOP
			prevstart := start; end := MAX(SIGNED32);
			FOR i := 1 TO LEN(table)(SIGNED32)-1 DO	(* find first partition start after or on start *)
				IF (table[i].start >= start) & (table[i].start < end) THEN
					end := table[i].start	(* free space ends at this start position *)
				END
			END;
			IF end > max THEN end := max END;	(* clip to end of disk *)
				(* {start..end-1 is free} *)
			IF end-start > 0 THEN NewFree(ReservedSpace, table, start, end-start, 0, {Disks.Primary}) END;
			nextstart := MAX(SIGNED32);
			FOR i := 1 TO LEN(table)(SIGNED32)-1 DO	(* find first partition end after prevstart *)
				t := table[i].start+table[i].size-1;
				IF (t > prevstart) & (t < nextstart) THEN nextstart := t END
			END;
			IF nextstart = MAX(SIGNED32) THEN
				EXIT	(* no more partitions end after prevstart *)
			ELSE
				start := nextstart+1
			END
		END
	END
END FindReserved;

(* Return TRUE iff partition i contains sector x. *)

PROCEDURE Contains(table: Disks.PartitionTable; i, x: SIGNED32): BOOLEAN;
BEGIN
	RETURN (table[i].start <= x) & (x < table[i].start + table[i].size)
END Contains;

PROCEDURE PartitionsOverlap(table: Disks.PartitionTable; i, j: SIGNED32): BOOLEAN;
BEGIN
	RETURN Contains(table, i, table[j].start) OR Contains(table, i, table[j].start+table[j].size-1)
		OR Contains(table, j, table[i].start) OR Contains(table, j, table[i].start+table[i].size-1)
END PartitionsOverlap;

PROCEDURE CheckTable(dev: Disks.Device; table: Disks.PartitionTable): BOOLEAN;
VAR i, j, ext: SIGNED32;
BEGIN
	ext := -1;
		(* check all partitions for size, and presence of at most one extended partition *)
	FOR i := 0 TO LEN(table)(SIGNED32)-1 DO
		IF (table[i].start < 0) OR (table[i].size < 0) OR (table[i].start+table[i].size < 0) THEN
			Texts.WriteString(w, "Warning: "); WritePart(w, dev, i);
			Texts.WriteString(w, "too large"); Texts.WriteLn(w);
			RETURN FALSE
		END;
		IF Extended(table[i].type) THEN
			IF ext # -1 THEN
				Texts.WriteString(w, "Error: "); WritePart(w, dev, ext);
				Texts.WriteString(w, "and "); WritePart(w, dev, i);
				Texts.WriteString(w, "are both extended"); Texts.WriteLn(w);
				RETURN FALSE
			END;
			ext := i
		END
	END;
		(* check all primary partitions and logical drives for overlap *)
	FOR i := 1 TO LEN(table)(SIGNED32)-1 DO
		IF Disks.Primary IN table[i].flags THEN	(* primary partition *)
			FOR j := 1 TO LEN(table)(SIGNED32)-1 DO
				IF (i # j) & (Disks.Primary IN table[j].flags) & PartitionsOverlap(table, i, j) THEN
					Texts.WriteString(w, "Error: "); WritePart(w, dev, i);
					Texts.WriteString(w, "and "); WritePart(w, dev, j);
					Texts.WriteString(w, "overlap"); Texts.WriteLn(w);
					RETURN FALSE	(* primary partitions can not overlap *)
				END
			END
		ELSE	(* logical drive in extended partition *)
			FOR j := 1 TO LEN(table)(SIGNED32)-1 DO
				IF (i # j) & (j # ext) & PartitionsOverlap(table, i, j) THEN
					Texts.WriteString(w, "Error: "); WritePart(w, dev, i);
					Texts.WriteString(w, "and "); WritePart(w, dev, j);
					Texts.WriteString(w, "overlap"); Texts.WriteLn(w);
					RETURN FALSE	(* logical drives can not overlap any other partition, except the extended partition *)
				END
			END
		END
	END;
	RETURN TRUE
END CheckTable;

(* Find free space on the disk and insert placeholder partitions (table is reallocated). *)

PROCEDURE FindFreeSpace(dev: Disks.Device; VAR table: Disks.PartitionTable; spt, hds: SIGNED32);
BEGIN
	ASSERT((hds > 0) & (spt > 0) & (table[0].start = 0));
	IF CheckTable(dev, table) THEN
		FindFreePrimary(table, spt, hds);
		FindFreeExtended(table, spt, hds);
		IF ShowReserved THEN FindReserved(table) END
	END
END FindFreeSpace;

PROCEDURE Show*;	(** ["detail"] ~ *)
VAR
	dev: Disks.DeviceTable; table: Disks.PartitionTable; i: SIZE; res, dosnum: SIGNED32; t: Texts.Text;
	d: Disks.Device; verbose: BOOLEAN; par: ARRAY 32 OF CHAR; geo: Disks.GetGeometryMsg;
BEGIN
	In.Open; In.String(par);
	verbose := In.Done & (par = "detail");
	Disks.GetRegistered(dev);
	IF dev # NIL THEN
		dosnum := NumFlop;
		FOR i := 0 TO LEN(dev)-1 DO
			d := dev[i]; ShowDevice(w, d, verbose, res);
			IF res # Disks.MediaMissing THEN
				Disks.UpdatePartitionTable(d, res); table := d.table;
				IF ((res = Ok) OR (res = Disks.DeviceInUse)) & (table # NIL) THEN
					IF TRUE (*res = Ok*) THEN
						GetGeometry(d, geo, res);
						IF (res = Ok) & (d.blockSize = BS) & (geo.cyls * geo.hds * geo.spt > DisketteLimit) THEN
							FindFreeSpace(d, table, geo.spt, geo.hds)	(* possibly re-allocate table *)
						END
					END;
					WriteTable(w, d, table, verbose, dosnum)
				ELSE
					Texts.WriteString(w, "ReadPartitions: "); WriteErrorMsg(w, res); Texts.WriteLn(w)
				END
			END;
			Texts.WriteLn(w)
		END;
		NEW(t); Texts.Open(t, ""); Texts.Append(t, w.buf);
		Oberon.OpenText("Partitions.Text", t, 400, 400)
	ELSE
		Texts.WriteString(w, "No devices found"); Texts.WriteLn(w);
		Texts.Append(Oberon.Log, w.buf)
	END
END Show;

PROCEDURE Put2(VAR b: ARRAY OF CHAR; i, val: SIGNED32);
BEGIN
	ASSERT((val >= 0) & (val < 10000H));
	b[i] := CHR(val MOD 100H);
	b[i+1] := CHR(ASH(val, -8) MOD 100H)
END Put2;

PROCEDURE Put4(VAR b: ARRAY OF CHAR; i, val: SIGNED32);
BEGIN
	b[i] := CHR(val MOD 100H);
	b[i+1] := CHR(ASH(val, -8) MOD 100H);
	b[i+2] := CHR(ASH(val, -16) MOD 100H);
	b[i+3] := CHR(ASH(val, -24) MOD 100H)
END Put4;

PROCEDURE Get2(VAR b: ARRAY OF CHAR; i: SIGNED32): SIGNED32;
BEGIN
	RETURN ORD(b[i]) + ASH(ORD(b[i+1]), 8)
END Get2;

PROCEDURE Get4(VAR b: ARRAY OF CHAR; i: SIGNED32): SIGNED32;
BEGIN
	RETURN ORD(b[i]) + ASH(ORD(b[i+1]), 8) + ASH(ORD(b[i+2]), 16) + ASH(ORD(b[i+3]), 24)
END Get4;

(* Decide heuristically which BIOS drive number to use when booting from the specified device. *)

PROCEDURE GetDriveNum(dev: Disks.Device): CHAR;
VAR d: CHAR;
BEGIN
		(* for removable media, assume the BIOS drive number is 0H, otherwise 80H. *)
	IF Disks.Removable IN dev.flags THEN d := 0X ELSE d := 80X END;
	RETURN d
END GetDriveNum;

(* Write the OBL boot loader and an empty config table to disk. *)

PROCEDURE InitOBL(dev: Disks.Device; part, flag: SIGNED32; VAR res: INTEGER);
CONST Size = LoaderSize*BS;
VAR
	b: ARRAY Size OF CHAR; i, tsize, rsize, lsize: SIGNED32;
	f: Files.File; r: Files.Rider; geo: Disks.GetGeometryMsg;
	size : SIGNED32;
BEGIN
	ASSERT(dev.blockSize = BS);
	GetGeometry(dev, geo, res);
	IF res = Ok THEN
		f := Files.Old(BootLoaderName); Files.Set(r, f, 0);
		ASSERT((f # NIL) & (Files.Length(f) <= Size));	(* assume boot file is present and small enough *)
		Files.ReadBytes(r, b, Files.Length(f));
		ASSERT(r.res = 0);
		ASSERT(Get4(b, 1F8H) = FSIDOBL);	(* new OBL.Bin *)
			(* get parameters from boot loader *)
		rsize := Get2(b, 0EH); tsize := ORD(b[10H]);
		ASSERT((rsize-tsize)*BS = Files.Length(f));	(* check boot loader size *)
		lsize := Files.Length(f) DIV BS;
		ASSERT(lsize = LoaderSize);
			(* set parameters in boot loader *)
		dev.getSize(dev, size, res);
(*		IF ~(Disks.Removable IN dev.flags) THEN	(* Windows 2000 workaround *) *)
		IF (size > DisketteLimit) THEN (* Windows 2000 workaround *)
			Put2(b, 0BH, 0);	(* bytes per sector *)
			b[0DH] := 0X;	(* sectors per cluster *)
			Put2(b, 11H, 0);	(* root directory size *)
			b[15H] := 0X;	(* media type *)
			Put2(b, 16H, 0)	(* sectors per FAT *)
		END;
		IF dev.table[part].size < 10000H THEN
			Put2(b, 13H, dev.table[part].size)
		ELSE
			Put2(b, 13H, 0)
		END;
		Put4(b, 20H, dev.table[part].size);
		Put2(b, 18H, geo.spt);
		Put2(b, 1AH, geo.hds);
		Put4(b, 1CH, dev.table[part].start);	(* boot sector *)
		b[24H] := GetDriveNum(dev);	(* drive *)
		b[0AH] := CHR(flag);	(* flag *)
			(* now write the boot loader to disk *)
		dev.transfer(dev, Write, dev.table[part].start, lsize, b, 0, res);
		IF res = Ok THEN	(* write an empty table *)
			FOR i := 0 TO BS-1 DO b[i] := 0FFX END;
			i := 0;
			WHILE (i < tsize) & (res = Ok) DO
				dev.transfer(dev, Write, dev.table[part].start + lsize + i, 1, b, 0, res);
				INC(i)
			END
		END
	END
END InitOBL;

(* Initialize the Aos file system in a partition. See AosFiles.Volume.Init *)

PROCEDURE InitAosFS(dev: Disks.Device; part, fsres, flag: SIGNED32; VAR res: INTEGER);
VAR fssize, i, j, ofs, size, x, fsofs: SIGNED32; b: ARRAY BS OF CHAR;
BEGIN
	ofs := dev.table[part].start; size := dev.table[part].size;
	ASSERT(dev.blockSize = BS);
	fsofs := fsres + LoaderSize+4;
	ASSERT((fsofs >= LoaderSize+4) & (fsofs <= size));
	fssize := (size-fsofs) DIV AosBPS;
	ASSERT(fssize > MinPartSize);
	InitOBL(dev, part, flag, res);
	IF res = Ok THEN
		dev.transfer(dev, Read, ofs, 1, b, 0, res);
		IF res = Ok THEN	(* init AosFS table *)
			ASSERT((b[1FEH] = 55X) & (b[1FFH] = 0AAX));
			Put4(b, 1F0H, fsofs); Put4(b, 1F4H, fssize); Put4(b, 1F8H, FSID);
			b[1FCH] := CHR(FSVer); b[1FDH] := CHR(AosSSLog2);
			dev.transfer(dev, Write, ofs, 1, b, 0, res);
			IF res = Ok THEN
				i := 0;
				WHILE (i # AosBPS) & (res = Ok) DO
					FOR j := 0 TO BS-1 DO b[j] := 0X END;
					IF i = 0 THEN
						b[0] := CHR(AosDirMark MOD 100H);
						b[1] := CHR(AosDirMark DIV 100H MOD 100H);
						b[2] := CHR(AosDirMark DIV 10000H MOD 100H);
						b[3] := CHR(AosDirMark DIV 1000000H MOD 100H)
					END;
					x := ofs + fsofs + i; dev.transfer(dev, Write, x, 1, b, 0, res);
					IF res # Ok THEN WriteTransferError(w, dev, Write, x, res) END;
					INC(i)
				END;
				IF res = Ok THEN	(* invalidate map *)
					FOR j := 0 TO BS-1 DO b[j] := 0X END;
					x := ofs + fsofs + (fssize-1)*AosBPS; dev.transfer(dev, Write, x, 1, b, 0, res);
					IF res # Ok THEN WriteTransferError(w, dev, Write, x, res) END
				END
			ELSE
				WriteTransferError(w, dev, Write, ofs, res)
			END
		ELSE
			dev.transfer(dev, Read, ofs, 1, b, 0, res)
		END
	ELSE
		Texts.WriteString(w, "InitOBL: "); WriteErrorMsg(w, res)
	END;
	IF res # Ok THEN Texts.WriteLn(w); Texts.Append(Oberon.Log, w.buf) END
END InitAosFS;

(* Initialize the Native file system in a partition. *)

PROCEDURE InitNativeFS(dev: Disks.Device; part, fsres, flag: SIGNED32; VAR res: INTEGER);
VAR ofs, size, fssize, fsofs, startfs, i: SIGNED32; b: ARRAY N2KSS*2 OF CHAR;
BEGIN
	ofs := dev.table[part].start; size := dev.table[part].size;
	ASSERT(dev.blockSize = BS);
	fsofs := fsres + LoaderSize+4;
	ASSERT((fsofs >= LoaderSize+4) & (fsofs <= size));
	fssize := (size-fsofs) DIV N2KBPS;
	ASSERT(fssize > MinPartSize);
	InitOBL(dev, part, flag, res);
	IF res # Ok THEN
		Texts.WriteString(w, "InitLoader: "); WriteErrorMsg(w, res)
	ELSE
		dev.transfer(dev, Read, dev.table[part].start, 1, b, 0, res);
		IF res # Ok THEN
			WriteTransferError(w, dev, Read, dev.table[part].start, res)
		ELSE
			ASSERT((b[1FEH] = 55X) & (b[1FFH] = 0AAX));
			Put2(b, 0EH, fsofs);	(* reserved *)
			dev.transfer(dev, Write, dev.table[part].start, 1, b, 0, res);	(* update reserved *)
			IF res # Ok THEN
				WriteTransferError(w, dev, Write, dev.table[part].start, res)
			ELSE
				FOR i := 0 TO N2KSS*2-1 DO b[i] := 0X END;
				Put4(b, 0, N2KDirMark);
				startfs := dev.table[part].start + fsofs;
				dev.transfer(dev, Write, startfs, N2KBPS*2, b, 0, res);
				IF res = Ok THEN
					Put4(b, 0, 0);	(* invalidate map mark *)
					dev.transfer(dev, Write, startfs + (fssize-1)*N2KBPS, N2KBPS, b, 0, res);
					IF res # Ok THEN WriteTransferError(w, dev, Write, startfs + (fssize-1)*N2KBPS, res) END
				ELSE
					WriteTransferError(w, dev, Write, startfs, res)
				END
			END
		END
	END;
	IF res # Ok THEN Texts.WriteLn(w); Texts.Append(Oberon.Log, w.buf) END
END InitNativeFS;

(* Check if an Oberon file system is present on a partition. Returns 0 if no Oberon file system found, 1 for a Native file system, 2 for an old Aos file system and 3 for a new Aos file system. *)

PROCEDURE DetectFS(dev: Disks.Device; part: SIGNED32): SIGNED32;
VAR b: ARRAY BS OF CHAR; res, fs: SIGNED32;
BEGIN
	ASSERT(dev.blockSize = BS);
	fs := 0; dev.transfer(dev, Read, dev.table[part].start, 1, b, 0, res);
	IF res = Ok THEN
		IF (b[1FEH] = 055X) & (b[1FFH] = 0AAX) THEN
			b[0] := "x"; b[1] := "x"; b[2] := "x"; b[9] := 0X;
			IF Get4(b, 1F8H) = FSID THEN fs := 3
			ELSIF Get4(b, 1F8H) = FSID0 THEN fs := 2
			ELSIF b = "xxxOBERON" THEN fs := 1
			ELSE (* skip *)
			END
		ELSE (* skip *)
		END
	END;
	RETURN fs
END DetectFS;

PROCEDURE CheckDiskette(name: ARRAY OF CHAR);
VAR m: Modules.Module; c: Modules.Command;
BEGIN
	name[8] := 0X;	(* assume large enough *)
	IF name = "Diskette" THEN
		m := Modules.ThisMod("Diskettes");
		IF m # NIL THEN
			c := Modules.ThisCommand(m, "Install");
			IF c # NIL THEN c() END
		END
	END
END CheckDiskette;

(* Scan command line for a device/partition specification and open the specified partition. *)

PROCEDURE ScanOpenPart(VAR dev: Disks.Device; check: BOOLEAN; VAR part: SIGNED32);	(* dev#part *)
VAR devtable: Disks.DeviceTable; i, res, num: SIGNED32; name: ARRAY 32 OF CHAR; ch: CHAR;
BEGIN
	dev := NIL; part := -1;
	In.Open; In.Name(name); In.Char(ch); In.LongInt(num);
	IF In.Done & (num >= 0) & (ch = "#") THEN
		CheckDiskette(name);
		Disks.GetRegistered(devtable);
		IF devtable # NIL THEN
			i := 0; WHILE (i # LEN(devtable)) & (devtable[i].name # name) DO INC(i) END;
			IF i # LEN(devtable) THEN
				Disks.Open(devtable[i], res);
				IF res = Ok THEN
					IF (num < LEN(devtable[i].table)) OR ~check THEN
						dev := devtable[i]; part := num
					ELSE
						Texts.WriteString(w, "Partition not found");
						Disks.Close(devtable[i], res)	(* ignore res *)
					END
				ELSE
					Texts.WriteString(w, devtable[i].name);
					Texts.WriteString(w, " Open: "); WriteErrorMsg(w, res)
				END
			ELSE
				Texts.WriteString(w, name); Texts.WriteString(w, " not found")
			END
		ELSE
			Texts.WriteString(w, "No devices found")
		END
	ELSE
		Texts.WriteString(w, "Expected parameters: dev#part")
	END;
	IF dev = NIL THEN	(* error occurred *)
		Texts.WriteLn(w); Texts.Append(Oberon.Log, w.buf)
	END
END ScanOpenPart;

(* Pseudo-random number. *)

PROCEDURE Random (VAR seed: SIGNED32; N :SIGNED32): SIGNED32;
BEGIN
		(* this is not a good one, but ok for this purpose *)
	seed := (seed + 773) * 13 MOD 9999991;
	RETURN seed MOD N
END Random;

PROCEDURE CheckPartition(dev: Disks.Device; part: SIGNED32; VAR res: INTEGER);
CONST Size = 16*512; Max = 50;
VAR
	start, size, i, j, pr, seed, len, ticks, t0, t1, date: SIGNED32;
	ch: CHAR; buf: ARRAY Size OF CHAR; maxblocks: SIGNED32;
BEGIN
	maxblocks := Size DIV dev.blockSize; ASSERT(maxblocks > 0);
	WritePart(w, dev, part); Texts.WriteString(w, "checking...");
	Texts.WriteLn(w); Texts.WriteString(w, "Rnd ");
	start := dev.table[part].start; size := dev.table[part].size;
	seed := 8872365; j := 0; pr := 0; res := Ok;
	WHILE (j # Max) & (res = Ok) DO
		Progress(Oberon.Log, j, Max, pr);
		i := Random(seed, size);
		dev.transfer(dev, Read, start + i, 1, buf, 0, res);
		IF res # Ok THEN WriteTransferError(w, dev, Read, start + i, res) END;
		INC(j);
		IF UserInterrupt(ch) THEN
			Texts.WriteString(w, " interrupted"); res := Interrupted
		END
	END;
	IF res = Ok THEN
		Progress(Oberon.Log, j, Max, pr);
		Texts.WriteLn(w); Texts.WriteString(w, "Seq ");
		i := 0; pr := 0;
		ticks := Input.Time(); Oberon.GetClock(t0, date);
		WHILE (i < size) & (res = Ok) DO
			Progress(Oberon.Log, i, size, pr);
			len := maxblocks;
			IF len > size-i THEN len := size-i END;
			dev.transfer(dev, Read, start + i, len, buf, 0, res);
			IF res # Ok THEN WriteTransferError(w, dev, Read, start + i, res) END;
			INC(i, len);
			IF UserInterrupt(ch) THEN
				Texts.WriteString(w, " interrupted"); res := Interrupted
			END
		END;
		Progress(Oberon.Log, i, size, pr);
		IF (res = Ok) OR (res = Interrupted) THEN
			ticks := Input.Time() - ticks;
			Oberon.GetClock(t1, date);	(* ignore midnight *)
			IF i = size THEN
				Texts.WriteLn(w); Texts.WriteString(w, "No problems detected")	(* no trap *)
			END;
			IF (ticks # 0) & (i # 0) THEN
				Texts.WriteLn(w); Texts.WriteInt(w, i DIV 2, 1);
				Texts.WriteString(w, "k read in ");
				Texts.WriteInt(w, ticks DIV Input.TimeUnit, 1);
				Texts.WriteString(w, "s (");
				t0 := (t0 DIV 4096 MOD 32*60 + t0 DIV 64 MOD 64)*60 + t0 MOD 64;	(* s *)
				t1 := (t1 DIV 4096 MOD 32*60 + t1 DIV 64 MOD 64)*60 + t1 MOD 64;	(* s *)
				Texts.WriteInt(w, t1 - t0, 1);
				Texts.WriteString(w, "s) => ");
				Texts.WriteInt(w, (i DIV 2)*Input.TimeUnit DIV ticks, 1);
				Texts.WriteString(w, "KB/s")
			END
		END
	END;
	Texts.WriteLn(w); Texts.Append(Oberon.Log, w.buf);
	IF (res = Interrupted) & (ch # CHR(27)) THEN res := Ok END
END CheckPartition;

(* Read OBL variables from the specified partition. *)

PROCEDURE GetVars(dev: Disks.Device; part: SIGNED32; VAR tsize, reserved, fsOfs, res: SIGNED32);
VAR b: ARRAY BS OF CHAR;
BEGIN
	ASSERT(dev.blockSize = BS);
	dev.transfer(dev, Read, dev.table[part].start, 1, b, 0, res);
	IF res = Ok THEN
		b[0] := "x"; b[1] := "x"; b[2] := "x"; b[9] := 0X;
		ASSERT(b = "xxxOBERON");	(* OBL present *)
		tsize := ORD(b[10H]); ASSERT(tsize > 0);
		reserved := Get2(b, 0EH); ASSERT(reserved >= LoaderSize + tsize);
		IF Get4(b, 1F8H) = FSID THEN fsOfs := Get4(b, 1F0H) ELSE fsOfs := reserved END
	END
END GetVars;

(* Read a config table from the specified partition. *)

PROCEDURE GetTable(dev: Disks.Device; part: SIGNED32; VAR table: ConfigTable; VAR res: INTEGER);
VAR tsize, reserved, fsOfs: SIGNED32;
BEGIN
	table := NIL; GetVars(dev, part, tsize, reserved, fsOfs, res);
	IF res = Ok THEN
		NEW(table, tsize*BS);
		dev.transfer(dev, Read, dev.table[part].start + LoaderSize, tsize, table^, 0, res)
	END
END GetTable;

(* Overwrite the config table on the specified partition. *)

PROCEDURE PutTable(dev: Disks.Device; part: SIGNED32; table: ConfigTable; VAR res: INTEGER);
VAR tsize, reserved, fsOfs: SIGNED32;
BEGIN
	GetVars(dev, part, tsize, reserved, fsOfs, res);
	IF res = Ok THEN
		ASSERT(tsize*BS = LEN(table^));	(* same size *)
		dev.transfer(dev, Write, dev.table[part].start + LoaderSize, tsize, table^, 0, res)
	END
END PutTable;

(* Find the next occurance of the specified entry type in the config table. *)

PROCEDURE FindEntry(table: ConfigTable; i, type: SIGNED32): SIGNED32;
VAR t: SIGNED32;
BEGIN
	LOOP
		t := Get4(table^, i);
		IF t = type THEN RETURN i
		ELSIF t = -1 THEN RETURN -1
		ELSE INC(i, Get4(table^, i+4))
		END
	END
END FindEntry;

(* Add an entry to the end of the table. *)

PROCEDURE AddEntry(table: ConfigTable; type, dsize: SIGNED32; VAR data: ARRAY OF CHAR);
VAR i, j, size: SIGNED32;
BEGIN
	ASSERT(dsize >= 0);
	i := FindEntry(table, 0, -1);	(* find end of table *)
	size := (dsize+3) DIV 4 * 4 + 8;
	Put4(table^, i, type); Put4(table^, i+4, size);
	j := 0; WHILE j # dsize DO table[i+8+j] := data[j]; INC(j) END;
	WHILE j MOD 4 # 0 DO table[i+8+j] := 0X; INC(j) END;
	Put4(table^, i+size, -1)
END AddEntry;

(* Delete the specified entry. *)

PROCEDURE DeleteEntry(table: ConfigTable; i: SIGNED32);
VAR j: SIZE; s: SIGNED32;
BEGIN
	ASSERT(Get4(table^, i) # -1);	(* can not delete end marker *)
	s := Get4(table^, i+4);
	FOR j := i TO LEN(table^)-s-1 DO table[j] := table[j+s] END
END DeleteEntry;

(* Write the specified file to the device, starting at block pos. *)

PROCEDURE WriteFile(f: Files.File; dev: Disks.Device; pos: SIGNED32; VAR sum, res: SIGNED32);
CONST Size = 32;
VAR buf: ARRAY Size*BS OF CHAR; r: Files.Rider; n, num: SIGNED32;
BEGIN
	ASSERT(dev.blockSize = BS);
	Files.Set(r, f, 0); num := (Files.Length(f)+BS-1) DIV BS; sum := 0;
	LOOP
		IF num <= 0 THEN EXIT END;
		Files.ReadBytes(r, buf, Size*BS);
		n := Size*BS - r.res;
		WHILE n MOD BS # 0 DO buf[n] := 0X; INC(n) END;
		ASSERT((n > 0) & (n <= num*BS));
		dev.transfer(dev, Write, pos, n DIV BS, buf, 0, res);
		IF res # Ok THEN EXIT END;
		DEC(num, n DIV BS); INC(pos, n DIV BS);
		REPEAT DEC(n); sum := (sum + ORD(buf[n])) MOD 100H UNTIL n = 0
	END;
	sum := (-sum) MOD 100H
END WriteFile;

PROCEDURE CheckFile(f: Files.File; dev: Disks.Device; pos: SIGNED32; sum: SIGNED32; VAR res: INTEGER);
CONST Size = 32;
VAR buf1, buf2: ARRAY Size*BS OF CHAR; r: Files.Rider; n, num, i: SIGNED32;
BEGIN
	ASSERT(dev.blockSize = BS);
	Files.Set(r, f, 0); num := (Files.Length(f)+BS-1) DIV BS;
	LOOP
		IF num <= 0 THEN EXIT END;
		Files.ReadBytes(r, buf1, Size*BS);
		n := Size*BS - r.res;
		WHILE n MOD BS # 0 DO buf1[n] := 0X; INC(n) END;
		ASSERT((n > 0) & (n <= num*BS));
		dev.transfer(dev, Read, pos, n DIV BS, buf2, 0, res);
		IF res # Ok THEN EXIT END;
		i := 0;
		WHILE i # n DO
			IF buf1[i] # buf2[i] THEN res := CoreMismatch; EXIT END;
			INC(i)
		END;
		DEC(num, n DIV BS); INC(pos, n DIV BS);
		REPEAT DEC(n); sum := (sum + ORD(buf2[n])) MOD 100H UNTIL n = 0
	END;
	IF (res = Ok) & (sum # 0) THEN res := CoreChecksumError END;
(*
	IF res # Ok THEN
		Kernel.WriteMemory(ADDRESSOF(buf1[i])-64, 128);
		Kernel.WriteMemory(ADDRESSOF(buf2[i])-64, 128);
		HALT(MAX(SIGNED16))
	END
*)
END CheckFile;

(* Write a boot file on the specified partition. *)

PROCEDURE InitBootFile(dev: Disks.Device; part: SIGNED32; f: Files.File; VAR res: INTEGER);
CONST Frag = 7; LoadAdr = 1000H; StartAdr = 1000H; Frags = 1;
VAR table: ConfigTable; i, tsize, reserved, fsOfs, sum, start: SIGNED32; data: ARRAY 12+8*Frags OF CHAR;
BEGIN
	GetTable(dev, part, table, res);
	IF res = Ok THEN
		LOOP
			i := FindEntry(table, 0, Frag);
			IF i < 0 THEN EXIT END;
			DeleteEntry(table, i)
		END;
		GetVars(dev, part, tsize, reserved, fsOfs, res);
		IF res = Ok THEN
			start := LoaderSize+tsize;
			IF (fsOfs-start)*BS >= Files.Length(f) THEN
				WriteFile(f, dev, dev.table[part].start + start, sum, res);
				IF res = Ok THEN CheckFile(f, dev, dev.table[part].start + start, sum, res) END;
				IF res = Ok THEN
					Put4(data, 0, LoadAdr); Put4(data, 4, Frags + ASH(sum, 16));
					Put4(data, 8, StartAdr); Put4(data, 12, 0);	(* pos relative to start *)
					Put4(data, 16, (Files.Length(f)+BS-1) DIV BS);
					AddEntry(table, Frag, LEN(data), data);
					PutTable(dev, part, table, res)
				END
			ELSE
				res := NoSpaceAvailable	(* not enough space available for boot file *)
			END
		END
	END
END InitBootFile;

PROCEDURE NativeType(type: SIGNED32): BOOLEAN;
BEGIN
	RETURN (type = NativeType1) OR (type = NativeType2) OR (type = AosType)
END NativeType;

(* Format a partition with an N2KFS or AosFS. *)

PROCEDURE Format*;	(** dev#part [ "AosFS" | "NatFS" | "NatFS2" [ FSRes [ BootFile [ Flag ] ] ] ] ~ *)
VAR dev: Disks.Device; part, type, res, fs, fsres, flag, size: SIGNED32; name: ARRAY 32 OF CHAR; done: BOOLEAN; f: Files.File;
BEGIN
	ScanOpenPart(dev, TRUE, part); done := FALSE;
	IF dev # NIL THEN
		In.Name(name);
		IF ~In.Done THEN name[0] := 0X END;
		IF (name = "NatFS") OR (name = "NatFS1") THEN type := NativeType1
		ELSIF name = "NatFS2" THEN type := NativeType2
		ELSE type := AosType
		END;
		IF ((part = 0) & (LEN(dev.table) = 1)) OR NativeType(dev.table[part].type) THEN
			IF ~(Disks.Mounted IN dev.table[part].flags) THEN
				IF dev.blockSize = BS THEN
					fs := DetectFS(dev, part);
					IF fs # 0 THEN
						WritePart(w, dev, part); Texts.WriteString(w, "has an Oberon file system"); Texts.WriteLn(w)
					END;
					IF ~safe OR (fs = 0) THEN
						dev.getSize(dev, size, res);
						IF (res # Ok) OR (size > DisketteLimit) THEN CheckPartition(dev, part, res) END;
						IF res = Ok THEN
							In.LongInt(fsres);
							IF ~In.Done OR (fsres = -2) THEN fsres := FSRes END;
							In.String(name);
							IF ~In.Done THEN name := BootFileName END;
							f := Files.Old(name);
							IF (f # NIL) OR (fsres # -1) THEN
								IF fsres = -1 THEN fsres := (Files.Length(f)+BS-1) DIV BS END;
								In.LongInt(flag);
								IF ~In.Done THEN flag := 1FH END;
								Texts.WriteString(w, "Reserving "); WriteK(w, fsres*BS DIV 1024);
								Texts.WriteString(w, " for boot file"); Texts.WriteLn(w);
								CASE type OF
									AosType: InitAosFS(dev, part, fsres, flag, res)
									|NativeType1, NativeType2: InitNativeFS(dev, part, fsres, flag, res)
								END;
								IF res = Ok THEN
									IF f # NIL THEN
										InitBootFile(dev, part, f, res);
										IF res = Ok THEN done := TRUE
										ELSE Texts.WriteString(w, "InitBootFile: "); WriteErrorMsg(w, res); Texts.WriteLn(w)
										END
									ELSE
										IF name # "" THEN
											Texts.WriteString(w, "Warning: "); Texts.WriteString(w, name);
											Texts.WriteString(w, " missing - partition not bootable"); Texts.WriteLn(w)
										END;
										done := TRUE
									END
								ELSE (* skip - error message already written *)
								END
							ELSE
								Texts.WriteString(w, name); Texts.WriteString(w, " missing"); Texts.WriteLn(w)
							END
						ELSE
							IF res # Interrupted THEN
								WritePart(w, dev, part); Texts.WriteString(w, "has errors"); Texts.WriteLn(w)
							END
						END
					ELSE
						Texts.WriteString(w, "  To reformat this partition, execute"); Texts.WriteLn(w);
						Texts.WriteString(w, "  Partitions.Unsafe and try again"); Texts.WriteLn(w)
					END
				ELSE
					WritePart(w, dev, part); Texts.WriteString(w, "has unsupported block size ");
					Texts.WriteInt(w, dev.blockSize, 1); Texts.WriteLn(w)
				END
			ELSE
				WritePart(w, dev, part); Texts.WriteString(w, "is mounted"); Texts.WriteLn(w)
			END
		ELSE
			WritePart(w, dev, part);
			IF part = 0 THEN Texts.WriteString(w, "has partitions")
			ELSE Texts.WriteString(w, "bad type "); Texts.WriteInt(w, dev.table[part].type, 1)
			END;
			Texts.WriteLn(w)
		END;
		WritePart(w, dev, part); Texts.WriteString(w, "format ");
		IF ~done THEN Texts.WriteString(w, "un") END;
		Texts.WriteString(w, "successful"); Texts.WriteLn(w);
		Texts.Append(Oberon.Log, w.buf);
		Disks.Close(dev, res)	(* ignore res *)
	END
END Format;

(* Update the boot file in an existing Oberon partition. *)

PROCEDURE UpdateBootFile*;	(** dev#part [ BootFile ] ~ *)
VAR dev: Disks.Device; part, res, fs: SIGNED32; name: ARRAY 32 OF CHAR; done: BOOLEAN; f: Files.File;
BEGIN
	ScanOpenPart(dev, TRUE, part); done := FALSE;
	IF dev # NIL THEN
		IF dev.blockSize = BS THEN
			fs := DetectFS(dev, part);
			IF fs # 0 THEN
				In.String(name);
				IF ~In.Done THEN name := BootFileName END;
				f := Files.Old(name);
				IF f # NIL THEN
					InitBootFile(dev, part, f, res);
					IF res = Ok THEN done := TRUE
					ELSE Texts.WriteString(w, "InitBootFile: "); WriteErrorMsg(w, res); Texts.WriteLn(w)
					END
				ELSE
					Texts.WriteString(w, name); Texts.WriteString(w, " missing"); Texts.WriteLn(w)
				END
			ELSE
				WritePart(w, dev, part); Texts.WriteString(w, "is not Oberon-formatted"); Texts.WriteLn(w)
			END
		ELSE
			WritePart(w, dev, part); Texts.WriteString(w, "has unsupported block size ");
			Texts.WriteInt(w, dev.blockSize, 1); Texts.WriteLn(w)
		END;
		WritePart(w, dev, part); Texts.WriteString(w, "update ");
		IF ~done THEN Texts.WriteString(w, "un") END;
		Texts.WriteString(w, "successful"); Texts.WriteLn(w);
		Texts.Append(Oberon.Log, w.buf);
		Disks.Close(dev, res)	(* ignore res *)
	END
END UpdateBootFile;

PROCEDURE GetConfig*;	(** dev#part | ^ *)
VAR dev: Disks.Device; part, res, i: SIGNED32; table: ConfigTable; t: Texts.Text; ch: CHAR;
BEGIN
	ScanOpenPart(dev, TRUE, part);
	IF dev # NIL THEN
		GetTable(dev, part, table, res);
		IF res = Ok THEN
			Texts.WriteString(w, "Partitions.SetConfig "); WritePart(w, dev, part); Texts.WriteLn(w);
			i := FindEntry(table, 0, 8);
			IF i >= 0 THEN
				INC(i, 8);
				WHILE table[i] # 0X DO
					Texts.WriteString(w, "  ");
					REPEAT Texts.Write(w, table[i]); INC(i) UNTIL table[i] = 0X;
					Texts.Write(w, "="); Texts.Write(w, 22X);
					LOOP
						INC(i); ch := table[i];
						IF ch = 0X THEN EXIT END;
						IF (ch >= " ") & (ch < 7FX) THEN
							Texts.Write(w, ch)
						ELSE
							Texts.Write(w, "%"); Texts.Write(w, hex[ORD(ch) DIV 10H]);
							Texts.Write(w, hex[ORD(ch) MOD 10H])
						END
					END;
					Texts.Write(w, 22X); Texts.WriteLn(w);
					INC(i)
				END
			END;
			Texts.WriteString(w, "~")
		ELSE
			Texts.WriteString(w, "GetTable: "); WriteErrorMsg(w, res)
		END;
		Texts.WriteLn(w);
		IF res = Ok THEN
			NEW(t); Texts.Open(t, ""); Texts.Append(t, w.buf);
			Oberon.OpenText("Config.Text", t, 400, 400)
		ELSE
			Texts.Append(Oberon.Log, w.buf)
		END;
		Disks.Close(dev, res)	(* ignore res *)
	END
END GetConfig;

PROCEDURE IsHex(ch: CHAR): BOOLEAN;
BEGIN
	RETURN (ch >= "0") & (ch <= "9") OR (CAP(ch) >= "A") & (CAP(ch) <= "F")
END IsHex;

PROCEDURE HexVal(ch: CHAR): SIGNED32;
BEGIN
	CASE ch OF
		"0".."9": RETURN ORD(ch)-ORD("0")
		|"A".."F": RETURN ORD(ch)-ORD("A")+10
		|"a".."f": RETURN ORD(ch)-ORD("a")+10
	END
END HexVal;

PROCEDURE UnQuote(VAR config: ARRAY OF CHAR; VAR len: SIGNED32);
VAR i, j: SIGNED32;
BEGIN
	i := 0;
	WHILE i < len DO
		IF (config[i] = "%") & IsHex(config[i+1]) & IsHex(config[i+2]) THEN
			config[i] := CHR(HexVal(config[i+1])*10H + HexVal(config[i+2]));
			ASSERT(config[i] # 0X);
			FOR j := i+1 TO len-1 DO config[j] := config[j+2] END;
			DEC(len, 2)
		ELSE
			INC(i)
		END
	END
END UnQuote;

(* Parse the configuration strings on the command line and add them to the config table. *)

PROCEDURE ParseConfig(table: ConfigTable): BOOLEAN;
VAR config: ARRAY MaxConfig OF CHAR; i: SIGNED32; ch: CHAR;
BEGIN
	i := 0;
	LOOP
		REPEAT
			REPEAT In.Char(ch) UNTIL ~In.Done OR (ch > " ");
			IF In.Done & (ch = "#") THEN
				REPEAT In.Char(ch) UNTIL ~In.Done OR (ch = 0DX)
			END;
			IF ~In.Done THEN EXIT END
		UNTIL ch # 0DX;
		IF ch = "~" THEN
			config[i] := 0X; INC(i);
			UnQuote(config, i);
			AddEntry(table, 8, i, config);
			EXIT
		END;
		REPEAT config[i] := ch; INC(i); In.Char(ch) UNTIL ~In.Done OR (ch <= " ") OR (ch = "=") OR (ch = 22X);
		WHILE In.Done & (ch > 0X) & (ch <= " ") DO In.Char(ch) END;
		IF ~In.Done OR (ch # "=") THEN In.Done := FALSE; EXIT END;
		config[i] := 0X; INC(i);
		In.Char(ch); WHILE In.Done & (ch > 0X) & (ch <= " ") DO In.Char(ch) END;
		IF ~In.Done OR (ch # 22X) THEN In.Done := FALSE; EXIT END;
		In.Char(ch);
		WHILE In.Done & (ch # 22X) & (ch >= " ") DO config[i] := ch; INC(i); In.Char(ch) END;
		IF ~In.Done OR (ch # 22X) THEN In.Done := FALSE; EXIT END;
		config[i] := 0X; INC(i)
	END;
	RETURN In.Done
END ParseConfig;

PROCEDURE SetConfig*;	(** dev#part { str = "val" } ~ *)
VAR dev: Disks.Device; part, res, i: SIGNED32; table: ConfigTable;
BEGIN
	ScanOpenPart(dev, TRUE, part);
	IF dev # NIL THEN
		WritePart(w, dev, part);
		GetTable(dev, part, table, res);
		IF res = Ok THEN
			LOOP
				i := FindEntry(table, 0, 8);
				IF i < 0 THEN EXIT END;
				DeleteEntry(table, i)
			END;
			IF ParseConfig(table) THEN
				PutTable(dev, part, table, res);
				IF res = Ok THEN Texts.WriteString(w, "config written")
				ELSE Texts.WriteString(w, "PutTable: "); WriteErrorMsg(w, res)
				END
			ELSE Texts.WriteString(w, "syntax error")
			END
		ELSE
			Texts.WriteString(w, "GetTable: "); WriteErrorMsg(w, res)
		END;
		Texts.WriteLn(w); Texts.Append(Oberon.Log, w.buf);
		Disks.Close(dev, res)	(* ignore res *)
	END
END SetConfig;

PROCEDURE Check*;	(** dev#part | ^ *)
VAR dev: Disks.Device; part, res: SIGNED32;
BEGIN
	ScanOpenPart(dev, TRUE, part);
	IF dev # NIL THEN
		CheckPartition(dev, part, res);	(* ignore res *)
		Disks.Close(dev, res)	(* ignore res *)
	END
END Check;

PROCEDURE ChangePartType(dev: Disks.Device; part: SIGNED32; oldtype, newtype: SIGNED32; VAR res: INTEGER);
VAR b: ARRAY BS OF CHAR; e: SIGNED32;
BEGIN
	ASSERT(dev.table[part].type = oldtype);
	ASSERT(dev.blockSize = BS);
	dev.transfer(dev, Read, dev.table[part].ptblock, 1, b, 0, res);
	IF res = Ok THEN
		e := dev.table[part].ptoffset;
		ASSERT((e >= 01BEH) & (e <= 01BEH+16*3));	(* too strict, but good for now *)
		ASSERT((ORD(b[e+4]) = oldtype) & (b[510] = 055X) & (b[511] = 0AAX));
		ASSERT((newtype > 0) & (newtype < 256));
		b[e+4] := CHR(newtype);
		dev.transfer(dev, Write, dev.table[part].ptblock, 1, b, 0, res);
		IF res = Ok THEN
			dev.table[part].type := newtype
		END
	END
END ChangePartType;

PROCEDURE ChangeType*;	(** dev#part oldtype newtype ~ *)
VAR dev: Disks.Device; part, oldtype, newtype, res: SIGNED32;
BEGIN
	ScanOpenPart(dev, TRUE, part);
	IF dev # NIL THEN
		In.LongInt(oldtype); In.LongInt(newtype);
		IF In.Done & (newtype > 0) & (newtype < 256) THEN
			WritePart(w, dev, part);
			IF dev.table[part].type = oldtype THEN
				ChangePartType(dev, part, oldtype, newtype, res);
				IF res = Ok THEN
					Texts.WriteString(w, "changed to type "); Texts.WriteInt(w, newtype, 1)
				ELSE
					WriteErrorMsg(w, res)
				END
			ELSE
				Texts.WriteString(w, "wrong partition type ");
				Texts.WriteInt(w, dev.table[part].type, 1)
			END
		ELSE
			Texts.WriteString(w, "Expected parameters: oldtype newtype")
		END;
		Texts.WriteLn(w); Texts.Append(Oberon.Log, w.buf);
		Disks.Close(dev, res)	(* ignore res *)
	END
END ChangeType;

PROCEDURE DeletePrimary(dev: Disks.Device; part: SIGNED32; type: SIGNED32; VAR res: INTEGER);
VAR b: ARRAY BS OF CHAR; e, i: SIGNED32;
BEGIN
	ASSERT(dev.table[part].type = type);
	ASSERT(dev.blockSize = BS);
	ASSERT(dev.table[part].ptblock = 0);	(* primary partition entry is in MBR *)
	dev.transfer(dev, Read, 0, 1, b, 0, res);
	IF res = Ok THEN
		e := dev.table[part].ptoffset;
		ASSERT((e >= 01BEH) & (e <= 01BEH+16*3));	(* too strict, but good for now *)
		ASSERT((ORD(b[e+4]) = type) & (b[510] = 055X) & (b[511] = 0AAX));
		FOR i := 0 TO 15 DO b[e+i] := 0X END;
		dev.transfer(dev, Write, 0, 1, b, 0, res)
	END
END DeletePrimary;

PROCEDURE Delete*;	(** dev#part type ~ *)
VAR dev: Disks.Device; part, type, res: SIGNED32;
BEGIN
	ScanOpenPart(dev, TRUE, part);
	IF dev # NIL THEN
		In.LongInt(type);
		IF In.Done & (type > 0) & (type < 256) THEN
			IF dev.openCount = 1 THEN	(* only "mounted" once, so ok to change names *)
				WritePart(w, dev, part);
				IF (dev.blockSize = BS) & (dev.table[part].type = type) THEN
					IF Disks.Primary IN dev.table[part].flags THEN
						DeletePrimary(dev, part, type, res);
						IF res = Ok THEN
							Texts.WriteString(w, "deleted, use Partitions.Show")
						ELSE
							WriteErrorMsg(w, res)
						END
					ELSE
						Texts.WriteString(w, "not a primary partition")
					END
				ELSE
					Texts.WriteString(w, "wrong partition type ");
					Texts.WriteInt(w, dev.table[part].type, 1)
				END
			ELSE
				Texts.WriteString(w, dev.name);
				Texts.WriteString(w, " contains mounted partitions")
			END
		ELSE
			Texts.WriteString(w, "Expected parameter: type")
		END;
		Texts.WriteLn(w); Texts.Append(Oberon.Log, w.buf);
		Disks.Close(dev, res)	(* ignore res *)
	END
END Delete;

PROCEDURE CreatePrimary(dev: Disks.Device; table: Disks.PartitionTable; part, size, spt, hds, type: SIGNED32; VAR res: INTEGER);
VAR i, e, t, start, end: SIGNED32; buf: ARRAY BS OF CHAR;
BEGIN
	ASSERT(dev.blockSize = BS);
	ASSERT(table[part].type = FreeSpace);
	ASSERT(table[part].ptblock = 0);	(* primary partition entry is in MBR *)
	dev.transfer(dev, Disks.Read, 0, 1, buf, 0, res);
	IF res = Ok THEN
		ASSERT((buf[510] = 055X) & (buf[511] = 0AAX));	(* MBR signature *)
			(* find first free slot *)
		e := -1;
		FOR i := 0 TO 3 DO
			IF (e = -1) & (Get4(buf, 01BEH + 16*i + 12) = 0) THEN	(* size is 0 *)
				e := 01BEH + 16*i
			END
		END;
		IF e # -1 THEN	(* found free slot *)
			start := table[part].start;
			INC(size, (-(start+size)) MOD (hds*spt));	(* round end up to cylinder boundary *)
			IF size > table[part].size THEN size := table[part].size END;	(* clip size down to max *)
			IF size >= MinPartSize THEN	(* create the entry *)
				end := start + size - 1;
				buf[e] := 0X;	(* not bootable *)
				buf[e+1] := CHR((start DIV spt) MOD hds);
				t := start DIV (spt*hds);
				IF t > 1023 THEN t := 1023 END;
				buf[e+2] := CHR(ASH(ASH(t, -8), 6) + (start MOD spt) + 1);
				buf[e+3] := CHR(t MOD 256);
				buf[e+4] := CHR(type);
				buf[e+5] := CHR((end DIV spt) MOD hds);
				t := end DIV (spt*hds);
				IF t > 1023 THEN t := 1023 END;
				buf[e+6] := CHR(ASH(ASH(t, -8), 6) + (end MOD spt) + 1);
				buf[e+7] := CHR(t MOD 256);
				Put4(buf, e+8, start);
				Put4(buf, e+12, size);
					(* write the MBR *)
				dev.transfer(dev, Disks.Write, 0, 1, buf, 0, res)
			ELSE
				res := PartitionTooSmall
			END
		ELSE
			res := OutOfSlots
		END
	END
END CreatePrimary;

PROCEDURE Create*;	(** dev#part sizeMB ~ *)
VAR
	dev: Disks.Device; part, size, res: SIGNED32; table: Disks.PartitionTable; geo: Disks.GetGeometryMsg;
BEGIN
	ScanOpenPart(dev, FALSE, part);
	IF dev # NIL THEN
		In.LongInt(size);
		IF In.Done THEN
			IF dev.openCount = 1 THEN	(* only "mounted" once, so ok to change names *)
				table := dev.table;
				GetGeometry(dev, geo, res);
				IF (res = Ok) & (dev.blockSize = BS) & (geo.cyls * geo.hds * geo.spt > DisketteLimit) THEN
					FindFreeSpace(dev, table, geo.spt, geo.hds);	(* possibly re-allocate table *)
					IF (part < LEN(table^)) & (table[part].type = FreeSpace) THEN
						IF (Disks.Primary IN table[part].flags) THEN
							CreatePrimary(dev, table, part, size*1024*(1024 DIV BS), geo.spt, geo.hds, AosType, res);
							IF res = Ok THEN
								Texts.WriteString(w, "Partition created, use Partitions.Show")
							ELSE
								Texts.WriteString(w, "CreatePrimary: "); WriteErrorMsg(w, res)
							END
						ELSE
							Texts.WriteString(w, "Can only create primary partitions")
						END
					ELSE
						Texts.WriteString(w, "Specified partition not free")
					END
				ELSE
					Texts.WriteString(w, "GetGeometry: "); WriteErrorMsg(w, res)
				END
			ELSE
				Texts.WriteString(w, dev.name);
				Texts.WriteString(w, " contains mounted partitions")
			END
		END;
		Texts.WriteLn(w); Texts.Append(Oberon.Log, w.buf);
		Disks.Close(dev, res)	(* ignore res *)
	END
END Create;

PROCEDURE SetFlag(on: BOOLEAN);	(* dev#part ~ *)
VAR dev: Disks.Device; part, res, e: SIGNED32; b: ARRAY BS OF CHAR; mod: BOOLEAN;
BEGIN
	ScanOpenPart(dev, TRUE, part);
	IF (dev # NIL) & (dev.blockSize = BS) THEN
		WritePart(w, dev, part);
		dev.transfer(dev, Read, dev.table[part].ptblock, 1, b, 0, res);
		IF res = Ok THEN
			ASSERT((b[510] = 055X) & (b[511] = 0AAX));
			e := dev.table[part].ptoffset;
			IF (e >= 01BEH) & (e <= 01BEH+16*3) THEN
				mod := FALSE;
				IF on & (b[e] = 0X) THEN b[e] := 80X; mod := TRUE
				ELSIF ~on & ((b[e] >= 80X) & (b[e] <= 81X)) THEN b[e] := 0X; mod := TRUE
				END;
				IF mod THEN
					dev.transfer(dev, Write, dev.table[part].ptblock, 1, b, 0, res);
					IF res = Ok THEN
						IF on THEN
							INCL(dev.table[part].flags, Disks.Boot);
							Texts.WriteString(w, "activated")
						ELSE
							EXCL(dev.table[part].flags, Disks.Boot);
							Texts.WriteString(w, "deactivated")
						END
					ELSE
						WriteErrorMsg(w, res)
					END
				ELSE
					IF on THEN
						Texts.WriteString(w, "already active")
					ELSE
						Texts.WriteString(w, "already inactive")
					END
				END
			ELSE
				Texts.WriteString(w, "not a valid partition")
			END
		ELSE
			WriteErrorMsg(w, res)
		END;
		Texts.WriteLn(w); Texts.Append(Oberon.Log, w.buf);
		Disks.Close(dev, res)	(* ignore res *)
	END
END SetFlag;

PROCEDURE Activate*;	(** dev#part ~ *)
BEGIN
	SetFlag(TRUE)
END Activate;

PROCEDURE Deactivate*;	(** dev#part ~ *)
BEGIN
	SetFlag(FALSE)
END Deactivate;

PROCEDURE FileToPartition*;	(** dev#part name [block numblocks] ~ *)
CONST Size = 32*BS;
VAR
	dev: Disks.Device; part, res, pos, num, pr, i, ofs, size: SIGNED32; name: ARRAY 64 OF CHAR;
	f: Files.File; r: Files.Rider; buf: ARRAY Size OF CHAR; ch: CHAR;
BEGIN
	ScanOpenPart(dev, TRUE, part);
	IF dev # NIL THEN
		In.Name(name);
		IF In.Done THEN
			f := Files.Old(name);
			IF f # NIL THEN
				ASSERT(dev.blockSize = BS);	(* fix later *)
				In.LongInt(ofs);
				IF In.Done THEN
					In.LongInt(size);
					IF ~In.Done THEN
						Texts.WriteString(w, "Parameters: dev#part name [block numblocks] ~");
						Texts.WriteLn(w);
						Texts.Append(Oberon.Log, w.buf);
						size := 0
					END;
					IF size < 0 THEN size := MAX(SIGNED32) END	(* use complete partition *)
				ELSE
					ofs := 0; size := MAX(SIGNED32)
				END;
				IF size > 0 THEN
					num := (Files.Length(f)+BS-1) DIV BS - ofs;
					IF size > num THEN size := num END;
					Files.Set(r, f, 0); pos := dev.table[part].start + ofs;
					Texts.WriteString(w, "Copying... "); Texts.Append(Oberon.Log, w.buf);
					i := 0; pr := 0;
					LOOP
						Progress(Oberon.Log, i, size, pr);
						Files.ReadBytes(r, buf, Size);
						num := Size - r.res;
						IF num = 0 THEN EXIT END;
						WHILE num MOD BS # 0 DO buf[num] := 0X; INC(num) END;
						num := num DIV BS;
						IF UserInterrupt(ch) THEN Texts.WriteString(w, " interrupted"); EXIT END;
						dev.transfer(dev, Write, pos, num, buf, 0, res);
						IF res # Ok THEN Texts.WriteLn(w); WriteTransferError(w, dev, Write, pos, res); EXIT END;
						INC(i, num); INC(pos, num)
					END;
					Texts.Write(w, " "); Texts.WriteInt(w, i, 1); Texts.WriteString(w, " blocks")
				END
			ELSE
				Texts.WriteString(w, name); Texts.WriteString(w, " not found")
			END;
			Texts.WriteLn(w)
		END;
		Texts.Append(Oberon.Log, w.buf);
		Disks.Close(dev, res)	(* ignore res *)
	END
END FileToPartition;

PROCEDURE PartitionToFile*;	(** dev#part name [block numblocks] ~ *)
CONST Size = 32*BS;
VAR
	dev: Disks.Device; part, res, pos, num, pr, i, ofs, size: SIGNED32; name: ARRAY 64 OF CHAR;
	f: Files.File; r: Files.Rider; buf: ARRAY Size OF CHAR; ch: CHAR;
BEGIN
	ScanOpenPart(dev, TRUE, part);
	IF dev # NIL THEN
		In.Name(name);
		IF In.Done THEN
			f := Files.New(name);
			IF f # NIL THEN
				ASSERT(dev.blockSize = BS);	(* fix later *)
				In.LongInt(ofs);
				IF In.Done THEN
					In.LongInt(size);
					IF ~In.Done THEN
						Texts.WriteString(w, "Parameters: dev#part name [block numblocks] ~");
						Texts.WriteLn(w);
						Texts.Append(Oberon.Log, w.buf);
						size := 0
					END;
					IF size < 0 THEN size := MAX(SIGNED32) END	(* use complete partition *)
				ELSE
					ofs := 0; size := MAX(SIGNED32)
				END;
				IF size > 0 THEN
					IF ofs + size > dev.table[part].size THEN size := dev.table[part].size - ofs END;
					Files.Set(r, f, 0); pos := dev.table[part].start + ofs;
					Texts.WriteString(w, "Copying... "); Texts.Append(Oberon.Log, w.buf);
					i := 0; pr := 0;
					LOOP
						Progress(Oberon.Log, i, size, pr);
						num := Size DIV BS;
						IF num > size-i THEN num := size-i END;
						IF num = 0 THEN EXIT END;
						dev.transfer(dev, Read, pos, num, buf, 0, res);
						IF res # Ok THEN Texts.WriteLn(w); WriteTransferError(w, dev, Read, pos, res); EXIT END;
						IF UserInterrupt(ch) THEN Texts.WriteString(w, " interrupted"); EXIT END;
						Files.WriteBytes(r, buf, num*BS); ASSERT(r.res = 0);
						INC(i, num); INC(pos, num)
					END;
					Texts.Write(w, " "); Texts.WriteInt(w, i, 1); Texts.WriteString(w, " blocks");
					Files.Register(f)
				END
			ELSE
				Texts.WriteString(w, name); Texts.WriteString(w, " invalid name")
			END;
			Texts.WriteLn(w)
		END;
		Texts.Append(Oberon.Log, w.buf);
		Disks.Close(dev, res)	(* ignore res *)
	END
END PartitionToFile;

PROCEDURE WriteMBR*;	(** dev#0 name ~ *)
VAR
	dev: Disks.Device; part, res, i: SIGNED32; name: ARRAY 64 OF CHAR;
	f: Files.File; r: Files.Rider; buf1, buf2: ARRAY BS OF CHAR;
BEGIN
	ScanOpenPart(dev, TRUE, part);
	IF dev # NIL THEN
		In.Name(name);
		IF In.Done & (part = 0) & (dev.blockSize = BS) THEN
			f := Files.Old(name);
			IF f # NIL THEN
				Files.Set(r, f, 0);
				Files.ReadBytes(r, buf1, BS);
				IF (r.res = 0) & (buf1[01FEH] = 055X) & (buf1[01FFH] = 0AAX) & (Files.Length(f) = BS) THEN
					dev.transfer(dev, Read, 0, 1, buf2, 0, res);
					IF res = Ok THEN
						FOR i := 01BEH TO 01FDH DO buf1[i] := buf2[i] END;	(* copy partition table *)
						dev.transfer(dev, Write, 0, 1, buf1, 0, res)
					END;
					IF res = Ok THEN
						Texts.WriteString(w, name); Texts.WriteString(w, " written to MBR")
					ELSE
						WriteTransferError(w, dev, Read, 0, res)
					END
				ELSE
					Texts.WriteString(w, name); Texts.WriteString(w, " does not contain MBR")
				END
			ELSE
				Texts.WriteString(w, name); Texts.WriteString(w, " not found")
			END;
			Texts.WriteLn(w)
		END;
		Texts.Append(Oberon.Log, w.buf);
		Disks.Close(dev, res)	(* ignore res *)
	END
END WriteMBR;

(* Overwrite the existing boot loader with the new one, leaving critical data untouched. *)

PROCEDURE UpdateOBL(dev: Disks.Device; part: SIGNED32; f: Files.File; VAR res: INTEGER);
CONST Size = LoaderSize*BS;
VAR
	b, bnew: ARRAY Size OF CHAR; i, tsize, rsize, lsize: SIGNED32;
	r: Files.Rider;
BEGIN
	ASSERT(dev.blockSize = BS);
	IF res = Ok THEN
		Files.Set(r, f, 0);
		ASSERT((f # NIL) & (Files.Length(f) <= Size));	(* assume boot file is present and small enough *)
		Files.ReadBytes(r, bnew, Files.Length(f));
		ASSERT(r.res = 0);
		lsize := Files.Length(f) DIV BS;
		dev.transfer(dev, Read, dev.table[part].start, lsize, b, 0, res);
		ASSERT(Get4(b, 1F8H) = FSID);	(* OBL.Bin signature 'AOS!' *)
			(* get parameters from boot loader *)
		rsize := Get2(b, 0EH); tsize := ORD(b[10H]);
		ASSERT((rsize-tsize)*BS = Files.Length(f));	(* check boot loader size *)
		lsize := Files.Length(f) DIV BS;
		ASSERT(lsize = LoaderSize);
			(* set parameters in boot loader *)
		FOR i := 0H TO 2H DO
			b[i] := bnew[i]
		END;
		(* Leave the data from 3H to 24H untouched: info on the partition position and size
			i.e. the BPB or BIOS Parameter Block - see comments "OBL variables" *)
		FOR i := 25H TO 1EFH DO
			b[i] := bnew[i]
		END;
		(* Leave the data from 1F0H to 1FFH untouched: info on the file sytem
			see comments "AosFS Table Format" *)
		FOR i := 200H TO Size-1 DO
			b[i] := bnew[i]
		END;
			(* now write the boot loader back to disk *)
		dev.transfer(dev, Write, dev.table[part].start, lsize, b, 0, res);
		(* The configuration table is left as is. It is up to the user to specify
		a new Init string (3 hexadecimal characters) suitable for the graphic card. *)
	END
END UpdateOBL;

(** Update the boot loader OBL in an existing AosFS partition,
replacing it by the new BBL handling the Init string differently.
The BBL must imperatively have the same size, 4 blocks, as the OBL.
The same BBL is applicable to all AosFS partitions. *)

PROCEDURE UpdateBootLoader*;	(** dev#part BootLoader ~ *)
VAR dev: Disks.Device; part, res, fs: SIGNED32; name: ARRAY 32 OF CHAR; done: BOOLEAN; f: Files.File;
BEGIN
	ScanOpenPart(dev, TRUE, part); done := FALSE;
	IF dev # NIL THEN
		IF dev.blockSize = BS THEN
			fs := DetectFS(dev, part);
			IF fs = 3 THEN
				In.String(name);
				f := Files.Old(name);
				IF f # NIL THEN
					UpdateOBL(dev, part, f, res);
					IF res = Ok THEN done := TRUE
					ELSE Texts.WriteString(w, "UpdateOBL: "); WriteErrorMsg(w, res); Texts.WriteLn(w)
					END
				ELSE
					Texts.WriteString(w, "Name"); Texts.WriteString(w, " missing"); Texts.WriteLn(w)
				END
			ELSE
				WritePart(w, dev, part); Texts.WriteString(w, "is not AosFS-formatted"); Texts.WriteLn(w)
			END
		ELSE
			WritePart(w, dev, part); Texts.WriteString(w, "has unsupported block size ");
			Texts.WriteInt(w, dev.blockSize, 1); Texts.WriteLn(w)
		END;
		WritePart(w, dev, part); Texts.WriteString(w, "update ");
		IF ~done THEN Texts.WriteString(w, "un") END;
		Texts.WriteString(w, "successful"); Texts.WriteLn(w);
		Texts.Append(Oberon.Log, w.buf);
		Disks.Close(dev, res)	(* ignore res *)
	END
END UpdateBootLoader;

PROCEDURE WriteHex(VAR wr: Texts.Writer; x, w: SIGNED32);
VAR buf: ARRAY 10 OF CHAR; i, j: SIGNED32;
BEGIN
	IF w >= 0 THEN j := 8 ELSE j := 2; w := -w END;
	FOR i := j+1 TO w DO Texts.Write(wr, " ") END;
	FOR i := j-1 TO 0 BY -1 DO
		buf[i] := CHR(x MOD 10H + 48);
		IF buf[i] > "9" THEN
			buf[i] := CHR(ORD(buf[i]) - 48 + 65 - 10)
		END;
		x := x DIV 10H
	END;
	buf[j] := 0X;
	Texts.WriteString(wr, buf)
END WriteHex;

PROCEDURE WriteHexDump(VAR w: Texts.Writer; VAR buf: ARRAY OF CHAR; ofs, size, base: SIGNED32);
VAR i: SIGNED32; ch: CHAR;
BEGIN
	WHILE ofs < size DO
		WriteHex(w, base+ofs, 8);
		FOR i := 0 TO 15 DO
			IF ofs+i < size THEN WriteHex(w, ORD(buf[ofs+i]), -3)
			ELSE Texts.WriteString(w, "   ")
			END
		END;
		Texts.Write(w, " ");
		FOR i := 0 TO 15 DO
			IF ofs+i < size THEN
				ch := buf[ofs+i];
				IF (ch < " ") OR (ch > 7EX) THEN ch := "." END
			ELSE
				ch := " "
			END;
			Texts.Write(w, ch)
		END;
		Texts.WriteLn(w);
		INC(ofs, 16)
	END
END WriteHexDump;

PROCEDURE ShowBlocks*;	(** dev#part block [numblocks] ~ *)
VAR
	dev: Disks.Device; part, pos, num, res: SIGNED32; buf: POINTER TO ARRAY OF CHAR;
	t: Texts.Text; ch: CHAR;
BEGIN
	ScanOpenPart(dev, TRUE, part);
	IF dev # NIL THEN
		In.LongInt(pos);
		IF In.Done THEN
			In.LongInt(num);
			IF ~In.Done THEN num := 1 END;
			NEW(buf, dev.blockSize);
			NEW(t); Texts.Open(t, "");
			Oberon.OpenText("ShowBlocks.Text", t, 400, 400);
			Texts.SetFont(w, Fonts.This("Courier10.Scn.Fnt"));
			LOOP
				IF num <= 0 THEN EXIT END;
				dev.transfer(dev, Read, dev.table[part].start + pos, 1, buf^, 0, res);
				IF res # Ok THEN WriteTransferError(w, dev, Read, pos, res); Texts.WriteLn(w); EXIT END;
				WritePart(w, dev, part); Texts.WriteInt(w, pos, 1); Texts.WriteLn(w);
				WriteHexDump(w, buf^, 0, dev.blockSize, 0);
				Texts.Append(t, w.buf);
				INC(pos); DEC(num);
				IF UserInterrupt(ch) THEN
					Texts.WriteString(w, "interrupted"); Texts.WriteLn(w); EXIT
				END
			END;
			Texts.Append(t, w.buf);
			Texts.SetFont(w, Fonts.Default)
		END;
		Disks.Close(dev, res)	(* ignore res *)
	END
END ShowBlocks;

PROCEDURE Unsafe*;	(** ~ *)
BEGIN
	safe := FALSE;
	Texts.WriteString(w, "Now in UNSAFE mode!"); Texts.WriteLn(w);
	Texts.Append(Oberon.Log, w.buf)
END Unsafe;

PROCEDURE Safe*;	(** ~ *)
BEGIN
	safe := TRUE;
	Texts.WriteString(w, "Now in safe mode"); Texts.WriteLn(w);
	Texts.Append(Oberon.Log, w.buf)
END Safe;

PROCEDURE ShowAosFSLimits*;	(** ~ *)
CONST Unit = 1024*1024*1024;
BEGIN
	Texts.WriteString(w, "Aos file system limits with ");
	Texts.WriteInt(w, AosSS, 1);
	Texts.WriteString(w, " byte sectors");
	Texts.WriteLn(w);
	Texts.WriteLongRealFix(w, 1.0D0*MAX(SIGNED32)/Unit, 1, 2, 0);
	Texts.WriteString(w, "Gb positioning limit in file because of 31 bit Set & Pos parameters");
	Texts.WriteLn(w);
	Texts.WriteLongRealFix(w, ((1.0D0*AosXS*AosXS+AosSTS)*AosSS-AosHS)/Unit, 1, 2, 0);
	Texts.WriteString(w, "Gb file size limit because of triple index structure");
	Texts.WriteLn(w);
	Texts.WriteLongRealFix(w, 1.0D0*MAX(SIGNED32)/AosSF*AosSS/Unit, 1, 2, 0);
	Texts.WriteString(w, "Gb volume size limit because of sector factor ");
	Texts.WriteInt(w, AosSF, 1); Texts.WriteLn(w);
	Texts.WriteLongRealFix(w, (1.0D0*MAX(SIGNED32)+1)*AosSS/Unit, 1, 2, 0);
	Texts.WriteString(w, "Gb file size limit because of 31 bit apos field");
	Texts.WriteLn(w);
	Texts.Append(Oberon.Log, w.buf)
END ShowAosFSLimits;

PROCEDURE Eject*;	(** dev ~ *)
VAR devtable: Disks.DeviceTable; i, res: SIGNED32; name: ARRAY 32 OF CHAR; msg: Disks.EjectMsg;
BEGIN
	res := -1;
	In.Open; In.Name(name);
	IF In.Done THEN
		Disks.GetRegistered(devtable);
		IF devtable # NIL THEN
			i := 0; WHILE (i # LEN(devtable)) & (devtable[i].name # name) DO INC(i) END;
			IF i # LEN(devtable) THEN
				devtable[i].handle(devtable[i], msg, res);
				IF res # Ok THEN
					Texts.WriteString(w, devtable[i].name);
					Texts.WriteString(w, " eject: "); WriteErrorMsg(w, res)
				END
			ELSE
				Texts.WriteString(w, name); Texts.WriteString(w, " not found")
			END
		ELSE
			Texts.WriteString(w, "No devices found")
		END
	ELSE
		Texts.WriteString(w, "Expected parameters: dev")
	END;
	IF res # Ok THEN	(* error occurred *)
		Texts.WriteLn(w); Texts.Append(Oberon.Log, w.buf)
	END
END Eject;

BEGIN
	Texts.OpenWriter(w);
	safe := TRUE; hex := "0123456789ABCDEF"
END Partitions.

Partition.Tool

System.Free Partitions ~

Partitions.ShowAosFSLimits

!Partitions.ChangeType IDE2#5 77 76 ~
!Partitions.ChangeType IDE3#1 76 6 ~
!Partitions.ChangeType IDE2#2 77 76 ~

!Partitions.Format IDE2#02 AosFS ~
!Partitions.Format Diskette0#0 NatFS ~
!Partitions.Format IDE3#1 NatFS ~
!Partitions.Format IDE2#2 AosFS ~

Partitions.Check IDE2#5
Partitions.Check IDE3#1
Partitions.Check IDE1#0
Partitions.Check Diskette0#0

Partitions.ShowBlocks IDE2#02 0 ~
Partitions.ShowBlocks IDE2#02 2 3 ~
Partitions.ShowBlocks Diskette0#0 0 2 ~

DOS.Directory d:/

FileDisks.Open SYS:Temp 2880 80 2 18 ~
Partitions.Format SYS:Temp#0 NatFS Temp0.bin -1 ~
OFSTools.Mount A NatFS SYS:Temp
System.CopyFiles Oberon0.tgz => A:Oberon0.tgz system.arc => A:system.arc ~
OFSTools.Unmount A
FileDisks.Close SYS:Temp ~

Partitions.PartitionToFile Diskette0#0 SYS:Temp ~
Partitions.FileToPartition Diskette0#0 SYS:Temp ~

Partitions.PartitionToFile IDE3#01 SYS:Temp 50 ~

Partitions.SetConfig Diskette0#0 Init="b81200cd10bb003fb80110cd10" TracePort="1" TraceBPS="38400" ~

FileDisks.Open SYS:Temp ~
Partitions.GetConfig SYS:oberon0.dsk#0
 ~
OFSTools.Mount TEST NatFS Diskette0#0 ~
OFSTools.Unmount TEST
FileDisks.Close SYS:Temp ~
System.CopyFiles Partitions.Obj => TEST:Partitions.Obj ~

1 ScanOpenPart check blockSize and Mounted
1 *File* operations for blockSize # BS

Partitions.Check Diskette0#0 ~

Partitions.Show ~
Partitions.Show detail ~

Partitions.Create IDE2#6 50
