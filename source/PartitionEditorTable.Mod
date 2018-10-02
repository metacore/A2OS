MODULE PartitionEditorTable; (** AUTHOR "staubesv"; PURPOSE "Partition Table Abstraction"; *)

IMPORT
	KernelLog, Plugins, Disks;

CONST
	Ok* = Disks.Ok;
	DeviceNotFound* = 98;
	BlocksizeNotSupported* = 99;
	NoSignature* = 100;

	PartitionTableOffset = 01BEH;
	EntrySize = 16; (* bytes *)

	BlockSize = 512;

	(* procedure Changed: changeType parameter encoding *)
	SizeChanged* = 1;
	StartLbaChanged* = 2;
	StartChsChanged* = 3;
	EndLbaChanged* = 4;
	EndChsChanged* = 5;

TYPE

	Buffer* = ARRAY BlockSize OF CHAR;

	Block* = RECORD
		lba* : LONGINT;
		cylinder*, head*, sector* : LONGINT;
	END;

	(** Datastructure representing a slot of a partition table *)
	Partition* = RECORD
		flag* : CHAR;
		type* : LONGINT;
		start*, end* : Block; (* note: end.lba is not stored in the partition table *)
		size* : LONGINT;
	END;

	PartitionTable* = ARRAY 4 OF Partition;

	DiskGeometry = RECORD
		cylinders, headsPerCylinder, sectorsPerTrack : LONGINT;
	END;

(* get a named device, necessary for ReadBlock and WriteBlock *)
PROCEDURE GetDevice(CONST devicename : ARRAY OF CHAR) : Disks.Device;
VAR plugin : Plugins.Plugin;
BEGIN
	plugin := Disks.registry.Get(devicename);
	IF (plugin # NIL) & (plugin IS Disks.Device) THEN
		RETURN plugin (Disks.Device);
	ELSE
		RETURN NIL;
	END;
END GetDevice;

(* Get the disk geometry of a named device *)
PROCEDURE GetDiskGeometry(CONST devicename : ARRAY OF CHAR; VAR diskGeometry : DiskGeometry; VAR res : WORD);
VAR device : Disks.Device; geometry : Disks.GetGeometryMsg; ignore : WORD;
BEGIN
	device := GetDevice(devicename);
	IF (device # NIL) THEN
		device.Open(res);
		IF (res = Disks.Ok) THEN
			device.Handle(geometry, res);
			IF (res = Disks.Ok) THEN
				diskGeometry.cylinders := geometry.cyls;
				diskGeometry.headsPerCylinder := geometry.hds;
				diskGeometry.sectorsPerTrack := geometry.spt;
			END;
			device.Close(ignore);
		END;
	ELSE
		res := DeviceNotFound;
	END;
END GetDiskGeometry;

(* read a block from device with name devicename. Returns with res = Disks.Ok, if successful *)
PROCEDURE ReadBlock*(CONST devicename : ARRAY OF CHAR;  block : LONGINT; VAR buffer: Buffer; VAR res: WORD);
VAR device : Disks.Device; ignore : WORD;
BEGIN
	device := GetDevice(devicename);
	IF (device # NIL) THEN
		IF (device.blockSize = BlockSize) THEN
			device.Open(res);
			IF (res = Ok) THEN
				device.Transfer(Disks.Read, block, 1, buffer, 0, res);
				device.Close(ignore);
			END;
		ELSE
			res := BlocksizeNotSupported;
		END;
	ELSE
		res := DeviceNotFound;
	END;
END ReadBlock;

(* write a block to device with name devicename. Returns with res = Disks.Ok, if successful*)
PROCEDURE WriteBlock*(CONST devicename : ARRAY OF CHAR; block : LONGINT; VAR buffer: Buffer; VAR res: WORD);
VAR device : Disks.Device; ignore : WORD;
BEGIN
	device := GetDevice(devicename);
	IF (device # NIL) THEN
		IF (device.blockSize = BlockSize) THEN
			device.Open(res);
			IF (res = Ok) THEN
				device.Transfer(Disks.Write, block, 1, buffer, 0, res);
				device.Close(ignore);
			END;
		ELSE
			res := BlocksizeNotSupported;
		END;
	ELSE
		res := DeviceNotFound;
	END;
END WriteBlock;

PROCEDURE HasSignature*(CONST buffer : Buffer) : BOOLEAN;
BEGIN
	RETURN (buffer[510] = 055X) & (buffer[511] = 0AAX);
END HasSignature;

PROCEDURE WriteSignature(VAR buffer : Buffer);
BEGIN
	buffer[510] := 055X;
	buffer[511] := 0AAX;
END WriteSignature;

PROCEDURE Get4(CONST buffer : ARRAY OF CHAR;  offset : LONGINT): LONGINT;
BEGIN
	RETURN ORD(buffer[offset]) + ASH(ORD(buffer[offset+1]), 8) +
		ASH(ORD(buffer[offset+2]), 16) + ASH(ORD(buffer[offset+3]), 24)
END Get4;

PROCEDURE Put4(VAR buffer : ARRAY OF CHAR; value, offset : LONGINT);
VAR i : LONGINT;
BEGIN
	FOR i := 0 TO 3 DO
		buffer[offset + i] := CHR(value MOD 256); value := value DIV 256;
	END;
END Put4;

(**	This procedure is called by the Partition Editor when you press the Load button. It should load the block number <block> on the
	device <devicename> and extract the partition table inside if any *)
PROCEDURE LoadPartitionTable*(CONST devicename : ARRAY OF CHAR;  block : LONGINT; VAR res : WORD) : PartitionTable;
VAR pt : PartitionTable; buffer: Buffer;
BEGIN
	Clear(pt);
	ReadBlock(devicename,block,buffer,res);
	IF res = Disks.Ok THEN
		pt := ParseBuffer(buffer,res);
	END;
	RETURN pt;
END LoadPartitionTable;

PROCEDURE ParseBuffer*(CONST buffer : Buffer; VAR res : WORD) : PartitionTable;
VAR pt : PartitionTable; entry, offset : LONGINT;

	PROCEDURE ParseCHS(CONST buffer : Buffer; offset : LONGINT; VAR cylinder, head, sector : LONGINT);
	BEGIN
		head := ORD(buffer[offset]);
		sector := ORD(buffer[offset+1]) MOD 64;
		cylinder := ORD(buffer[offset+2]);
		cylinder := cylinder + ((ORD(buffer[offset+1]) DIV 64) * 256)
	END ParseCHS;

BEGIN
	IF HasSignature(buffer) THEN
		res := Ok;
		FOR entry := 0 TO 3 DO
			offset := PartitionTableOffset + entry * EntrySize;
			pt[entry].flag := buffer[offset + 0];
			ParseCHS(buffer, offset + 1, pt[entry].start.cylinder, pt[entry].start.head, pt[entry].start.sector);
			pt[entry].type := ORD(buffer[offset + 4]);
			ParseCHS(buffer, offset + 5, pt[entry].end.cylinder, pt[entry].end.head, pt[entry].end.sector);
			pt[entry].start.lba := Get4(buffer, offset + 8);
			pt[entry].size := Get4(buffer, offset + 12);
			(* fixup: LBA of end sector *)
			IF (pt[entry].size > 0) THEN
				pt[entry].end.lba := pt[entry].start.lba + pt[entry].size - 1;
			ELSE
				pt[entry].end.lba := 0;
			END;
		END;
	ELSE
		res := NoSignature;
	END;
	RETURN pt;
END ParseBuffer;

(** 	This procedure is called by the Partition Editor when you press the Store button. It shall encode the given partition table <pt>  into a
	512 bytes block and store this block on the named device at block number <block> *)
PROCEDURE StorePartitionTable*(CONST devicename : ARRAY OF CHAR; block : LONGINT; CONST pt : PartitionTable; VAR res : WORD);
VAR buffer : Buffer;
BEGIN
	ReadBlock(devicename,block,buffer,res);
	IF res = Disks.Ok THEN
		WriteToBuffer(pt,buffer);
		WriteBlock(devicename,block,buffer,res);
	END;
END StorePartitionTable;

PROCEDURE WriteToBuffer*(CONST pt : PartitionTable; VAR buffer : Buffer);
VAR entry, offset : LONGINT;

	PROCEDURE WriteChs(VAR buffer : Buffer; offset, cylinder, head, sector : LONGINT);
	BEGIN
		buffer[offset] := CHR(head);
		buffer[offset + 1] := CHR((sector MOD 64) + (cylinder DIV 64) * 64);
		buffer[offset + 2] := CHR(cylinder);
	END WriteChs;

BEGIN
	WriteSignature(buffer);
	FOR entry := 0 TO 3 DO
		offset := PartitionTableOffset + entry * EntrySize;
		buffer[offset + 0] := pt[entry].flag;
		WriteChs(buffer, offset + 1, pt[entry].start.cylinder, pt[entry].start.head, pt[entry].start.sector);
		buffer[offset + 4] := CHR(pt[entry].type);
		WriteChs(buffer, offset + 5, pt[entry].end.cylinder, pt[entry].end.head, pt[entry].end.sector);
		Put4(buffer, pt[entry].start.lba, offset + 8);
		Put4(buffer, pt[entry].size, offset + 12);
	END;
END WriteToBuffer;

PROCEDURE Lba2Chs(lba : LONGINT; VAR c, h, s : LONGINT; geometry : DiskGeometry);
VAR temp : LONGINT;
BEGIN
	c := lba DIV (geometry.headsPerCylinder * geometry.sectorsPerTrack);
	temp := lba MOD (geometry.headsPerCylinder * geometry.sectorsPerTrack);
	h := temp DIV geometry.sectorsPerTrack;
	s := temp MOD geometry.sectorsPerTrack + 1;
END Lba2Chs;

PROCEDURE Chs2Lba(c, h, s : LONGINT; VAR lba : LONGINT; geometry : DiskGeometry);
BEGIN
	lba := ((c * geometry.headsPerCylinder + h) * geometry.sectorsPerTrack) + s - 1;
END Chs2Lba;

(** 	This procedure is called by the Partition Editor when the user presses the enter key on an editor component.
	Dependent of the changeType, we should now fixup all other entries of the provide partition table entry, e.g.
	if the start LBA changed, we should adjust the start CHS and the partition size.
	The Partition Editor will visualize changes we do to the Partition record *)
PROCEDURE Changed*(changeType : LONGINT; VAR partition : Partition; CONST devicename : ARRAY OF CHAR; VAR res : WORD);
VAR diskGeometry : DiskGeometry; geometry : BOOLEAN;
BEGIN
	GetDiskGeometry(devicename, diskGeometry, res);
	IF (res = Ok) THEN
		geometry := TRUE;
		KernelLog.String(devicename); KernelLog.String(": CHS ");
		KernelLog.Int(diskGeometry.cylinders, 0); KernelLog.String(" x "); KernelLog.Int(diskGeometry.headsPerCylinder, 0); KernelLog.String(" x ");
		KernelLog.Int(diskGeometry.sectorsPerTrack, 0); KernelLog.Ln;
	ELSE
		(* if res = Disks.Unsupported, we could try to fake a disk geometry here... *)
		geometry := FALSE;
	END;
	IF (changeType = StartLbaChanged) OR (changeType = EndLbaChanged) THEN
		partition.size := partition.end.lba - partition.start.lba + 1;
		IF geometry THEN
			Lba2Chs(partition.start.lba, partition.start.cylinder, partition.start.head, partition.start.sector, diskGeometry);
			Lba2Chs(partition.end.lba, partition.end.cylinder, partition.end.head, partition.end.sector, diskGeometry);
		END;
	ELSIF (changeType = SizeChanged) THEN
		partition.end.lba := partition.start.lba + partition.size - 1;
		IF geometry THEN
			Lba2Chs(partition.end.lba, partition.end.cylinder, partition.end.head, partition.end.sector, diskGeometry);
		END;
	ELSIF (changeType = StartChsChanged) OR (changeType = EndChsChanged)THEN
		IF geometry THEN
			Chs2Lba(partition.start.cylinder, partition.start.head, partition.start.sector, partition.start.lba, diskGeometry);
			Chs2Lba(partition.end.cylinder, partition.end.head, partition.end.sector, partition.end.lba, diskGeometry);
			partition.size := partition.end.lba - partition.start.lba + 1;
		END;
	END;
	res := Ok;
END Changed;

(** Set all entries the partition table <partitionTable>  to zero, needed by editor component. Can also be used here. *)
PROCEDURE Clear*(VAR partitionTable : PartitionTable);
VAR i : LONGINT;

	PROCEDURE ClearBlock(VAR block : Block);
	BEGIN
		block.lba := 0;
		block.cylinder := 0; block.head := 0; block.sector := 0;
	END ClearBlock;

BEGIN
	FOR i := 0 TO LEN(partitionTable)-1 DO
		partitionTable[i].type := 0;
		partitionTable[i].flag := 0X;
		ClearBlock(partitionTable[i].start);
		ClearBlock(partitionTable[i].end);
	END;
END Clear;

END PartitionEditorTable.
