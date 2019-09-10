(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE FileDisks IN Oberon;	(* pjm *)

(* A virtual disk driver based on Files.  Aos Oberon version. *)

IMPORT Disks IN A2, Plugins IN A2, Files, Modules, In, Out;

CONST
	BS = 512;

TYPE
	Device = OBJECT (Disks.Device)
		VAR
			f: Files.File;
			size, cyls, hds, spt: SIGNED32;
			new: BOOLEAN;

		PROCEDURE Transfer*(op, lba, num: SIGNED32; VAR data: ARRAY OF CHAR; ofs: SIZE; VAR res: INTEGER);
		VAR pos, n: SIGNED32; r: Files.Rider;
		BEGIN
			ASSERT(ofs = 0);	(* implementation restriction *)
			IF (op = Disks.Read) OR (op = Disks.Write) THEN
				IF (lba >= 0) & (num >= 0) & ((lba < SELF.size) & (lba+num <= SELF.size)) THEN
					ASSERT(num*SELF.blockSize <= LEN(data)-ofs);	(* range check *)
					pos := lba*SELF.blockSize;
					CASE op OF
						Disks.Read:
							IF pos < Files.Length(SELF.f) THEN	(* inside file *)
								Files.Set(r, SELF.f, pos);
								Files.ReadBytes(r, data, num*SELF.blockSize)	(* fixme: should read at ofs *)
							ELSE
								r.res := num*SELF.blockSize
							END;
							IF r.res # 0 THEN	(* fill rest of block with 0 *)
								pos := num*SELF.blockSize - r.res + SIGNED32(ofs); n := r.res;
								WHILE n # 0 DO data[pos] := 0X; INC(pos); DEC(n) END
							END;
							res := Disks.Ok
						|Disks.Write:
							IF pos > Files.Length(SELF.f) THEN	(* outside file *)
								n := pos - Files.Length(SELF.f);
								Files.Set(r, SELF.f, Files.Length(SELF.f));
								WHILE n > 0 DO Files.Write(r, 0X); DEC(n) END
							END;
							Files.Set(r, SELF.f, pos);
							Files.WriteBytes(r, data, num*SELF.blockSize);	(* fixme: should read at ofs *)
							IF r.res = 0 THEN res := Disks.Ok ELSE res := 2 END
					END	(* CASE *)
				ELSE
					res := 1
				END
			ELSE
				res := Disks.Unsupported
			END
		END Transfer;

		PROCEDURE GetSize*(VAR size, res: SIGNED32);
		BEGIN
			size := SELF.size; res := Disks.Ok
		END GetSize;

		PROCEDURE Handle*(VAR msg: Disks.Message; VAR res: INTEGER);
		BEGIN
			IF (msg IS Disks.GetGeometryMsg) & (SELF.cyls > 0) THEN
				WITH msg: Disks.GetGeometryMsg DO
					msg.cyls := SELF.cyls; msg.hds := SELF.hds; msg.spt := SELF.spt; res := Disks.Ok
				END
			ELSE
				res := Disks.Unsupported
			END
		END Handle;

	END Device;

(** Open a new virtual disk volume in specified file.  If size is specified, a new file of the specified number of blocks is generated.  Afterwards the virtual disk device will be visible with Partitions.Show and can be used like any other device.  The file should preferably be on a boot volume, or otherwise Close must be called before rebooting, to ensure clean shutdown of the virtual device. *)
PROCEDURE Open*;	(** name [size [cyls hds spt] ] ~ *)
VAR name: ARRAY 64 OF CHAR; dev: Device; res: INTEGER;
BEGIN
	In.Open; In.Name(name);
	IF In.Done THEN
		Out.String(name);
		NEW(dev); Disks.InitDevice(dev); dev.blockSize := BS; dev.cyls := -1;
		dev.SetName(name); dev.desc := "Virtual device in a file";
		INCL(dev.flags, Disks.Removable);
		In.LongInt(dev.size);
		dev.new := In.Done;
		IF dev.new THEN
			dev.f := Files.New(name);
			In.LongInt(dev.cyls); In.LongInt(dev.hds); In.LongInt(dev.spt);
			IF ~In.Done THEN dev.cyls := -1 END
		ELSE
			dev.f := Files.Old(name);
			IF (dev.f # NIL) & (Files.Length(dev.f) MOD BS = 0) THEN
				dev.size := Files.Length(dev.f) DIV BS
			ELSE
				dev.f := NIL
			END
		END;
		IF dev.f # NIL THEN
			INCL(dev.flags, Disks.Removable);
			Disks.registry.Add(dev, res);
			IF res # 0 THEN Out.String("Register error "); Out.Int(res, 1); Out.Ln END;
			Out.String(" opened")
		ELSE
			Out.String(" bad file")
		END;
		Out.Ln
	END
END Open;

PROCEDURE Unregister(dev: Device);
VAR n: SIGNED32; r: Files.Rider;
BEGIN
	Disks.registry.Remove(dev);
	Out.String("Closing "); Out.String(dev.name); Out.Char(" ");
	n := dev.size*BS - Files.Length(dev.f);
	IF n > 0 THEN	(* not complete *)
		Files.Set(r, dev.f, Files.Length(dev.f));
		WHILE n > 0 DO Files.Write(r, 0X); DEC(n) END
	END;
	Out.Int(Files.Length(dev.f) DIV 1024, 1); Out.String("KB"); Out.Ln;
	IF dev.new THEN Files.Register(dev.f) ELSE Files.Close(dev.f) END;
	dev.f := NIL
END Unregister;

PROCEDURE Mounted(dev: Disks.Device): BOOLEAN;
VAR i: SIZE;
BEGIN
	IF dev.table # NIL THEN
		FOR i := 0 TO LEN(dev.table)-1 DO
			IF Disks.Mounted IN dev.table[i].flags THEN RETURN TRUE END
		END
	END;
	RETURN FALSE
END Mounted;

(** Close the specified virtual disk device.  Be sure to first unmount any file system that has been mounted on the device, otherwise a trap will appear when the file system is accessed again. *)
PROCEDURE Close*;	(** name *)
VAR name: ARRAY 64 OF CHAR; dev: Plugins.Table; i: SIZE; found: BOOLEAN;
BEGIN
	In.Open; In.Name(name);
	IF In.Done THEN
		found := FALSE;
		Disks.registry.GetAll(dev);
		IF dev # NIL THEN
			FOR i := 0 TO LEN(dev)-1 DO
				IF dev[i].name = name THEN
					IF ~Mounted(dev[i](Device)) THEN
						Unregister(dev[i](Device))
					ELSE
						Out.String(name); Out.String(" has mounted file systems"); Out.Ln
					END;
					found := TRUE
				END
			END
		END;
		IF ~found THEN Out.String(name); Out.String(" not found"); Out.Ln END
	END
END Close;

PROCEDURE Cleanup;
VAR dev: Plugins.Table; i: SIZE;
BEGIN
	Disks.registry.GetAll(dev);
	IF dev # NIL THEN
		FOR i := 0 TO LEN(dev)-1 DO
			IF dev[i] IS Device THEN Unregister(dev[i](Device)) END
		END
	END
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END FileDisks.

FileDisks.Open SYS:oberon0.dsk ~
FileDisks.Close ^

OFSTools.Mount SRC NatFS SYS:oberon0.dsk ~
OFSTools.Unmount SRC

Partitions.Show

System.Free FileDisks ~
