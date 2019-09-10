(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE PCITools IN Oberon;	(* pjm *)

(* based on Linux pci.c and PCI Local Bus Specification Revision 2.0 *)
(* 18.06.2003 (tf) fix for non-continuously numbered device functions *)

IMPORT SYSTEM, PCI IN A2, Texts, Oberon;

CONST
	HdrType = 0EH;

TYPE
	Device = POINTER TO RECORD
		bus: Bus;	(* bus this device is on *)
		sibling: Device;	(* next device on this bus *)
		next, prev: Device;	(* chain of all devices *)
		devfn: SIGNED32;	(* dev = top 5 bits, fn = lower 3 bits *)
		device: SIGNED32;	(* device id *)
		vendor: SIGNED32;	(* vendor id *)
		class: SIGNED32;	(* base, sub, prog-if bytes *)
		irq, pin: SIGNED32
	END;

	Bus = POINTER TO RECORD
		parent: Bus;	(* parent bus this bridge is on *)
		children: Bus;	(* chain of P2P bridges on this bus *)
		next: Bus;	(* chain of all PCI buses *)
		self: Device;	(* bridge device as seen by parent *)
		devices: Device;	(* devices behind this bridge *)
		number: SIGNED32;	(* bus number *)
		primary, secondary: SIGNED32;	(* bridge numbers *)
		subordinate: SIGNED32	(* max number of subordinate buses *)
	END;

VAR
	w: Texts.Writer;
	devices: Device;
	root: Bus;
	data: Texts.Text;

PROCEDURE ReadConfigByte(bus, devfn, ofs: SIGNED32;  VAR val: SIGNED32);
VAR res: INTEGER;
BEGIN
	res := PCI.ReadConfigByte(bus, ASH(devfn, -3) MOD 20H, devfn MOD 8, ofs, val);
	ASSERT(res = PCI.Done)
END ReadConfigByte;

PROCEDURE ReadConfigWord(bus, devfn, ofs: SIGNED32;  VAR val: SIGNED32);
VAR res: INTEGER;
BEGIN
	res := PCI.ReadConfigWord(bus, ASH(devfn, -3) MOD 20H, devfn MOD 8, ofs, val);
	ASSERT(res = PCI.Done)
END ReadConfigWord;

PROCEDURE ReadConfigDword(bus, devfn, ofs: SIGNED32;  VAR val: SIGNED32);
VAR res: INTEGER;
BEGIN
	res := PCI.ReadConfigDword(bus, ASH(devfn, -3) MOD 20H, devfn MOD 8, ofs, val);
	ASSERT(res = PCI.Done)
END ReadConfigDword;

PROCEDURE WriteConfigDword(bus, devfn, ofs, val: SIGNED32);
VAR res: INTEGER;
BEGIN
	res := PCI.WriteConfigDword(bus, ASH(devfn, -3) MOD 20H, devfn MOD 8, ofs, val);
	ASSERT(res = PCI.Done)
END WriteConfigDword;

PROCEDURE ScanBus(VAR bus: Bus): SIGNED32;
VAR devfn, max, x, hdrtype, ht, buses: SIGNED32;  ismulti: BOOLEAN;  dev: Device;  child: Bus;
BEGIN
	max := bus.secondary;  ismulti := FALSE;
	FOR devfn := 0 TO 0FEH DO
		IF (devfn MOD 8 = 0) OR ismulti THEN
			ReadConfigByte(bus.number, devfn, HdrType, hdrtype);
			IF devfn MOD 8 = 0 THEN ismulti := ODD(hdrtype DIV 80H) END;
			ReadConfigDword(bus.number, devfn, PCI.DevReg, x);
			IF (x # -1) & (x # 0) THEN	(* some boards return 0 instead of -1 for empty slot, according to Linux *)
				NEW(dev);
				dev.bus := bus;  dev.devfn := devfn;
				dev.vendor := x MOD 10000H;
				dev.device := ASH(x, -16) MOD 10000H;
				ReadConfigByte(bus.number, devfn, PCI.IntlReg, dev.irq);
				ReadConfigByte(bus.number, devfn, PCI.IntlReg+1, dev.pin);
				ReadConfigDword(bus.number, devfn, PCI.RevIdReg, x);
				dev.class := ASH(x, -8) MOD 1000000H;	(* upper 3 bytes *)
				CASE ASH(dev.class, -8) OF
					604H: ht := 1	(* bridge pci *)
					|607H: ht := 2	(* bridge cardbus *)
					ELSE ht := 0
				END;
				IF ht = hdrtype MOD 80H THEN
					dev.next := devices;  devices := dev;  dev.prev := NIL;
					dev.sibling := bus.devices;  bus.devices := dev;
					IF ASH(dev.class, -8) = 604H THEN	(* bridge pci *)
						NEW(child);
						child.next := bus.children;  bus.children := child;
						child.self := dev;  child.parent := bus;
						INC(max);  child.secondary := max;  child.number := max;
						child.primary := bus.secondary;  child.subordinate := 0FFH;

						ReadConfigDword(bus.number, devfn, 18H, buses);
						IF buses MOD 1000000 # 0 THEN
							child.primary := buses MOD 100H;
							child.secondary := ASH(buses, -8) MOD 100H;
							child.subordinate := ASH(buses, -16) MOD 100H;
							child.number := child.secondary;
							max := ScanBus(child)
						ELSE	(* configure bus numbers for this bridge *)
							Texts.WriteString(w, "PCI: bus numbers not configured");
						END
					END
				ELSE
					Texts.WriteString(w, "PCI: unknown header type ");  Texts.WriteInt(w, bus.number, 1);
					Texts.Write(w, " ");  Texts.WriteInt(w, dev.devfn, 1);
					Texts.Write(w, " ");  Texts.WriteInt(w, dev.vendor, 1);
					Texts.Write(w, " ");  Texts.WriteInt(w, dev.device, 1);
					Texts.Write(w, " ");  Texts.WriteInt(w, dev.class, 1);
					Texts.Write(w, " ");  Texts.WriteInt(w, hdrtype, 1);
					Texts.WriteLn(w)
				END
		(*	ELSE
				ismulti := FALSE *) (* not all functions are continuously numbered *)
			END
		END
	END;
	RETURN max
END ScanBus;

PROCEDURE HexDigit(ch: CHAR): BOOLEAN;
BEGIN
	RETURN (ch >= "0") & (ch <= "9") OR (CAP(ch) >= "A") & (CAP(ch) <= "F")
END HexDigit;

PROCEDURE Read(VAR r: Texts.Reader; VAR ch: CHAR);
BEGIN
	IF r.eot THEN ch := 0X ELSE Texts.Read(r, ch) END
END Read;

PROCEDURE WriteDevice(VAR w: Texts.Writer; class: BOOLEAN; p1, p2, p3: SIGNED32; l1, l2, l3: ARRAY OF CHAR);
VAR r: Texts.Reader; ch: CHAR; level, value: SIGNED32;

	PROCEDURE SkipLine(write: BOOLEAN);
	BEGIN
		WHILE (ch # 0X) & (ch # 0DX) & (ch # 0AX) DO
			IF write THEN Texts.Write(w, ch) END;
			Read(r, ch)
		END;
		REPEAT Read(r, ch) UNTIL (ch # 0DX) & (ch # 0AX)
	END SkipLine;

	PROCEDURE ReadHex(VAR x: SIGNED32);
	BEGIN
		x := 0;
		LOOP
			IF (ch >= "0") & (ch <= "9") THEN
				x := x * 16 + (ORD(ch)-ORD("0"))
			ELSIF (CAP(ch) >= "A") & (CAP(ch) <= "F") THEN
				x := x * 16 + (ORD(CAP(ch))-ORD("A")+10)
			ELSE
				EXIT
			END;
			Read(r, ch)
		END
	END ReadHex;

	PROCEDURE GetLine(VAR level, value: SIGNED32);
	BEGIN
		IF class THEN
			IF ch = "C" THEN Read(r, ch); Read(r, ch) END
		END;
		WHILE (ch # 0X) & (ch # 9X) & ~HexDigit(ch) DO SkipLine(FALSE) END;
		level := 0; WHILE ch = 9X DO INC(level); Read(r, ch) END;
		ReadHex(value);
		WHILE ch = " " DO Read(r, ch) END
	END GetLine;

	PROCEDURE Label(l: ARRAY OF CHAR);
	BEGIN
		Texts.WriteString(w, l); Texts.WriteString(w, ": ")
	END Label;

BEGIN
	Texts.OpenReader(r, data, 0); Read(r, ch);
	IF class THEN
		WHILE (ch # 0X) & (ch # "C") DO SkipLine(FALSE) END
	END;
	LOOP
		GetLine(level, value);
		IF (ch = 0X) OR (level = 0) & (value = p1) THEN EXIT END;
		SkipLine(FALSE)
	END;
	Label(l1);
	IF (ch # 0X) & (level = 0) & (value = p1) THEN
		SkipLine(TRUE); Texts.WriteString(w, ", ");
		LOOP
			GetLine(level, value);
			IF (ch = 0X) OR (level = 0) OR (level = 1) & (value = p2) THEN EXIT END;
			SkipLine(FALSE)
		END;
		Label(l2);
		IF (ch # 0X) & (level = 1) & (value = p2) THEN
			SkipLine(TRUE);
			LOOP
				GetLine(level, value);
				IF (ch = 0X) OR (level < 2) OR (level = 2) & (value = p3) THEN EXIT END;
				SkipLine(FALSE)
			END;
			IF (ch # 0X) & (level = 2) & (value = p3) THEN
				Texts.WriteString(w, ", "); Label(l3); SkipLine(TRUE)
			END
		ELSE
			Texts.WriteString(w, "Unknown")
		END
	ELSE
		Texts.WriteString(w, "Unknown")
	END
END WriteDevice;

PROCEDURE WriteB(VAR w: Texts.Writer; x: SIGNED32);
CONST K = 1024; M = K*K; G = K*M;
VAR mult: CHAR;
BEGIN
	IF x MOD K # 0 THEN
		Texts.WriteInt(w, x, 1)
	ELSE
		IF x MOD M # 0 THEN mult := "K"; x := x DIV K
		ELSIF x MOD G # 0 THEN mult := "M"; x := x DIV M
		ELSE mult := "G"; x := x DIV G
		END;
		Texts.WriteInt(w, x, 1); Texts.Write(w, mult)
	END;
	Texts.Write(w, "B")
END WriteB;

PROCEDURE WriteBase(VAR w: Texts.Writer; bus, devfn, reg: SIGNED32; VAR double: BOOLEAN);
VAR base, basehi, type, size: SIGNED32; mask: SET;
BEGIN
	double := FALSE; basehi := 0; size := 0;
	ReadConfigDword(bus, devfn, reg, base);
	IF base # 0 THEN
		WriteConfigDword(bus, devfn, reg, -1);
		ReadConfigDword(bus, devfn, reg, size);
		WriteConfigDword(bus, devfn, reg, base);
		IF ODD(base) THEN	(* I/O *)
			IF ASH(base, -16) = 0 THEN mask := {2..15} ELSE mask := {2..31} END;
			type := base MOD 4
		ELSE	(* memory *)
			mask := {4..31}; type := base MOD 10H
		END;
		size := SYSTEM.VAL(SIGNED32, -(SYSTEM.VAL(SET, size) * mask))+1;
		size := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, size) * mask);
		IF type MOD 8 = 4 THEN	(* 64-bit *)
			ReadConfigDword(bus, devfn, reg+4, basehi); double := TRUE
		END;
		DEC(base, type);
			(* write *)
		Texts.Write(w, 9X); Texts.Write(w, 9X);
		WriteB(w, size); Texts.Write(w, " ");
		CASE type OF
			0: Texts.WriteString(w, "32-bit memory")
			|1: Texts.WriteString(w, "I/O")
			|4: Texts.WriteString(w, "64-bit memory")
			|8: Texts.WriteString(w, "prefetchable 32-bit memory")
			|12: Texts.WriteString(w, "prefetchable 64-bit memory")
			ELSE Texts.WriteString(w, "type "); Texts.WriteInt(w, type, 1)
		END;
		Texts.WriteString(w, " at");
		IF basehi # 0 THEN Texts.WriteHex(w, basehi) END;
		Texts.WriteHex(w, base); Texts.WriteString(w, " -");
		IF basehi # 0 THEN Texts.WriteHex(w, basehi) END;
		Texts.WriteHex(w, base + size - 1); Texts.WriteLn(w)
	END
END WriteBase;

PROCEDURE WriteDev(VAR w: Texts.Writer;  dev: Device);
VAR bus, devfn, hdrtype, classrev, vendor, device, cmd, status, lastreg, reg, base: SIGNED32; double: BOOLEAN;
BEGIN
	bus := dev.bus.number;  devfn := dev.devfn;
	ReadConfigByte(bus, devfn, HdrType, hdrtype);
	ReadConfigDword(bus, devfn, PCI.RevIdReg, classrev);
	ReadConfigWord(bus, devfn, PCI.DevReg, vendor);
	ReadConfigWord(bus, devfn, PCI.DevReg+2, device);
	ReadConfigWord(bus, devfn, PCI.CmdReg+2, status);
	ReadConfigWord(bus, devfn, PCI.CmdReg, cmd);

	Texts.WriteString(w, "Bus ");  Texts.WriteInt(w, bus, 1);
	Texts.WriteString(w, ", device ");  Texts.WriteInt(w, ASH(devfn, -3) MOD 20H, 1);
	Texts.WriteString(w, ", function ");  Texts.WriteInt(w, devfn MOD 8, 1);
	Texts.WriteString(w, ": class/rev");  Texts.WriteHex(w, classrev);
	Texts.WriteString(w, ", vendor/device");  Texts.WriteHex(w, ASH(vendor, 16) + device);
	Texts.WriteString(w, ", status/cmd");  Texts.WriteHex(w, ASH(status, 16) + cmd);
	Texts.WriteLn(w);

	Texts.Write(w, 9X);
	WriteDevice(w, TRUE, ASH(classrev, -24) MOD 100H, ASH(classrev, -16) MOD 100H, ASH(classrev, -8) MOD 100H,
		"Class", "Sub-class", "ProgIntfc");
	Texts.WriteLn(w); Texts.Write(w, 9X);
	WriteDevice(w, FALSE, vendor, device, -1, "Vendor", "Device", "");
	(*Texts.WriteString(w, " (rev ");  Texts.WriteInt(w, classrev MOD 100H, 1);
	Texts.WriteString(w, ")");*)
	Texts.WriteLn(w);
	IF (dev.irq # 0) OR (dev.pin # 0) THEN
		Texts.Write(w, 9X); Texts.Write(w, 9X);
		Texts.WriteString(w, "IRQ");  Texts.WriteInt(w, dev.irq, 1);
		IF dev.pin # 0 THEN
			Texts.WriteString(w, ", INT");  Texts.Write(w, CHR(ORD("A")+dev.pin-1))
		END;
		Texts.WriteLn(w)
	END;
	CASE hdrtype MOD 80H OF
		0: lastreg := PCI.Adr5Reg
		|1: lastreg := PCI.Adr1Reg
		ELSE lastreg := 0
	END;
	FOR reg := PCI.Adr0Reg TO lastreg BY 4 DO
		WriteBase(w, bus, devfn, reg, double);
		IF double THEN INC(reg, 4) END	(* modifying FOR variable *)
	END;
	IF hdrtype MOD 80H = 0 THEN
		ReadConfigDword(bus, devfn, PCI.ROMReg, base);
		IF base # 0 THEN
			Texts.Write(w, 9X); Texts.Write(w, 9X);
			Texts.WriteString(w, "ROM at");
			Texts.WriteHex(w, base);  Texts.WriteLn(w)
		END
	END;
	Texts.WriteLn(w)
END WriteDev;

(*
PROCEDURE ShowInterrupts;
VAR bus, dev, fkt, res, val, val1, piix, i, m, iobase: SIGNED32;
BEGIN
	Texts.WriteString(w, "Interrupt routing:");  Texts.WriteLn(w);
	IF PCI.FindPCIClassCode(60100H, 0, bus, dev, fkt) = PCI.Done THEN
		res := PCI.ReadConfigWord(bus, dev, fkt, 2, val);  ASSERT(res = PCI.Done);
		IF val = 122EH THEN piix := 1
		ELSIF val = 7000H THEN piix := 3
		ELSIF val = 7110H THEN piix := 4
		ELSE piix := 0
		END;
		IF piix # 0 THEN
			Texts.WriteString(w, "  PIIX");
			IF piix # 1 THEN Texts.WriteInt(w, piix, 1) END;
			Texts.WriteString(w, " rev ");
			res := PCI.ReadConfigByte(bus, dev, fkt, 8, val);  ASSERT(res = PCI.Done);
			Texts.WriteInt(w, val, 1);  Texts.WriteLn(w);
			FOR i := 0 TO 3 DO
				res := PCI.ReadConfigByte(bus, dev, fkt, 60H+i, val);  ASSERT(res = PCI.Done);
				Texts.WriteString(w, "  PIRQ");  Texts.Write(w, CHR(ORD("A")+i));
				IF ODD(val DIV 80H) THEN
					Texts.WriteString(w, " to none")
				ELSE
					Texts.WriteString(w, " to IRQ");  Texts.WriteInt(w, val MOD 10H, 1);
					IF (val MOD 10H) IN {0..2,8,13} THEN Texts.WriteString(w, " (reserved)") END
				END;
				Texts.WriteLn(w)
			END;
			IF piix = 1 THEN m := 1 ELSE m := 0 END;
			FOR i := 0 TO m DO
				res := PCI.ReadConfigByte(bus, dev, fkt, 70H+i, val);  ASSERT(res = PCI.Done);
				Texts.WriteString(w, "  MBIRQ");  Texts.WriteInt(w, i, 1);
				IF ODD(val DIV 80H) THEN
					Texts.WriteString(w, " to none")
				ELSE
					Texts.WriteString(w, " to IRQ");  Texts.WriteInt(w, val MOD 10H, 1);
					IF (val MOD 10H) IN {0..2,8,13} THEN Texts.WriteString(w, " (reserved)") END;
					IF ODD(val DIV 40H) THEN Texts.WriteString(w, " (shared)") END;
					IF (piix # 1) & ODD(val DIV 20H) THEN Texts.WriteString(w, " (IRQ0 enable)") END
				END;
				Texts.WriteLn(w)
			END;
			IF piix # 1 THEN	(* check IO APIC *)
				res := PCI.ReadConfigByte(bus, dev, fkt, 80H, val);  ASSERT(res = PCI.Done);
				ASSERT(~ODD(val DIV 40H));	(* A12 mask = 0 *)
				iobase := 0FEC00000H + ASH(val DIV 4 MOD 10H, 12) + ASH(val MOD 4, 10);
				Kernel.MapPhysical(iobase, 4096, iobase);
				SYSTEM.PUT(iobase, 0X);  SYSTEM.GET(iobase+10H, val);
				Texts.WriteString(w, "  IO APIC ID ");  Texts.WriteInt(w, ASH(val, -24), 1);  Texts.WriteLn(w);
				SYSTEM.PUT(iobase, 1X);  SYSTEM.GET(iobase+10H, val);
				Texts.WriteString(w, "  IO APIC ver");  Texts.WriteHex(w, val);  Texts.WriteLn(w);
				FOR i := 0 TO 23 DO
					Texts.WriteString(w, "  Int");  Texts.WriteInt(w, i, 2);
					SYSTEM.PUT(iobase, CHR(10H+2*i));  SYSTEM.GET(iobase+10H, val);
					SYSTEM.PUT(iobase, CHR(10H+2*i+1));  SYSTEM.GET(iobase+10H, val1);
					Texts.WriteString(w, ", vector ");  Texts.WriteInt(w, val MOD 100H, 1);
					Texts.WriteString(w, ", mode ");  Texts.WriteInt(w, val DIV 100H MOD 8, 1);
					IF ODD(ASH(val, -11)) THEN Texts.WriteString(w, ", logical")
					ELSE Texts.WriteString(w, ", physical")
					END;
					IF ODD(ASH(val, -12)) THEN Texts.WriteString(w, ", pending")
					ELSE Texts.WriteString(w, ", idle")
					END;
					IF ODD(ASH(val, -13)) THEN Texts.WriteString(w, ", active low")
					ELSE Texts.WriteString(w, ", active high")
					END;
					IF ODD(ASH(val, -15)) THEN Texts.WriteString(w, ", level")
					ELSE Texts.WriteString(w, ", edge")
					END;
					IF ODD(ASH(val, -16)) THEN Texts.WriteString(w, ", masked")
					ELSE Texts.WriteString(w, ", unmasked")
					END;
					Texts.WriteString(w, ", dest ");  Texts.WriteInt(w, ASH(val1, -24) MOD 100H, 1);
					Texts.WriteLn(w)
				END
			END
		ELSE
			Texts.WriteString(w, "Unknown device ID");  Texts.WriteHex(w, val);  Texts.WriteLn(w)
		END
	ELSE
		Texts.WriteString(w, "ISA bridge not found");  Texts.WriteLn(w)
	END
END ShowInterrupts;
*)

PROCEDURE Scan*;
VAR dev, prev: Device;  t: Texts.Text;  ver, last, hw, count: SIGNED32;
BEGIN
	IF PCI.PCIPresent(ver, last, hw) = PCI.Done THEN
		devices := NIL;  NEW(root);	(* initialized to all NIL *)
		root.subordinate := ScanBus(root);
		dev := devices; count := 0; prev := NIL;
		WHILE dev # NIL DO
			dev.prev := prev; prev := dev;
			dev := dev.next; INC(count)
		END;
		WHILE prev # NIL DO
			WriteDev(w, prev);
			prev := prev.prev
		END;
		Texts.WriteInt(w, count, 1); Texts.WriteString(w, " devices found"); Texts.WriteLn(w);
		(*ShowInterrupts;*)
		NEW(t);  Texts.Open(t, "");  Texts.Append(t, w.buf);
		Oberon.OpenText("PCIScan.Text", t, 640, 400)
	ELSE
		Texts.WriteString(w, "PCI not present"); Texts.WriteLn(w);
		Texts.Append(Oberon.Log, w.buf)
	END
END Scan;

BEGIN
	Texts.OpenWriter(w);
	NEW(data);  Texts.Open(data, "pci.ids");
	Texts.WriteString(w, "PCITools 12.03.2001"); Texts.WriteLn(w);
	IF data.len = 0 THEN
		Texts.WriteString(w, "No pci.ids => No device details"); Texts.WriteLn(w)
	END;
	Texts.Append(Oberon.Log, w.buf)
END PCITools.

PCITools.Scan
