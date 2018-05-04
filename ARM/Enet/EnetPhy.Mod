MODULE EnetPhy;
(**
	AUTHOR: Alexey Morozov, HighDim GmbH, 2015
	PURPOSE: Ethernet networking stack, PHY management
*)

IMPORT
	S := SYSTEM, EnetTiming, EnetBase;

TYPE
	Int8 = EnetBase.Int8;
	Int16 = EnetBase.Int16;
	Int = EnetBase.Int;
	UInt = EnetBase.UInt;

CONST

	InvalidPhyAddr* = 0xFF; (** Invalid PHY address *)

	(**
		Generic MII registers.
	*)
	MII_BMCR* = 0x00; (** Basic mode control register *)
	MII_BMSR* = 0x01; (** Basic mode status register *)
	MII_PHYSID1* = 0x02; (** PHYS ID 1 *)
	MII_PHYSID2* = 0x03; (** PHYS ID 2 *)
	MII_ADVERTISE* = 0x04; (** Advertisement control reg *)
	MII_LPA* = 0x05; (** Link partner ability reg *)
	MII_EXPANSION* = 0x06; (** Expansion register *)
	MII_CTRL1000* = 0x09; (** 1000BASE-T control *)
	MII_STAT1000* = 0x0a; (** 1000BASE-T status *)
	MII_ESTATUS* = 0x0f; (** Extended Status *)
	MII_DCOUNTER* = 0x12; (** Disconnect counter *)
	MII_FCSCOUNTER* = 0x13; (** False carrier counter *)
	MII_NWAYTEST* = 0x14; (** N-way auto-neg test reg *)
	MII_RERRCOUNTER* = 0x15; (** Receive error counter *)
	MII_SREVISION* = 0x16; (** Silicon revision *)
	MII_RESV1* = 0x17; (** Reserved *)
	MII_LBRERROR* = 0x18; (** Lpback, rx, bypass error *)
	MII_PHYADDR* = 0x19; (** PHY address *)
	MII_RESV2* = 0x1a; (** Reserved *)
	MII_TPISTATUS* = 0x1b; (** TPI status for 10mbps *)
	MII_NCONFIG* = 0x1c; (** Network interface config *)

	(** Basic mode control register. *)
	BMCR_RESV* = 0x003f; (** Reserved *)
	BMCR_SPEED1000* = 0x0040; (** MSB of Speed (1000) *)
	BMCR_CTST* = 0x0080; (** Collision test *)
	BMCR_FULLDPLX* = 0x0100; (** Full duplex *)
	BMCR_ANRESTART* = 0x0200; (** Auto negotiation restart *)
	BMCR_ISOLATE* = 0x0400; (** Disconnect DP83840 from MII *)
	BMCR_PDOWN* = 0x0800; (** Powerdown the DP83840 *)
	BMCR_ANENABLE* = 0x1000; (** Enable auto negotiation *)
	BMCR_SPEED100* = 0x2000; (** Select 100Mbps *)
	BMCR_LOOPBACK* = 0x4000; (** TXD loopback bits *)
	BMCR_RESET* = 0x8000; (** Reset the DP83840 *)

	(** Basic mode status register. *)
	BMSR_ERCAP* = 0x0001; (** Ext-reg capability *)
	BMSR_JCD* = 0x0002; (** Jabber detected *)
	BMSR_LSTATUS* = 0x0004; (** Link status *)
	BMSR_ANEGCAPABLE* = 0x0008; (** Able to do auto-negotiation *)
	BMSR_RFAULT* = 0x0010; (** Remote fault detected *)
	BMSR_ANEGCOMPLETE* = 0x0020; (** Auto-negotiation complete *)
	BMSR_RESV* = 0x00c0; (** Reserved *)
	BMSR_ESTATEN* = 0x0100; (** Extended Status in R15 *)
	BMSR_100FULL2* = 0x0200; (** Can do 100BASE-T2 HDX *)
	BMSR_100HALF2* = 0x0400; (** Can do 100BASE-T2 FDX *)
	BMSR_10HALF* = 0x0800; (** Can do 10mbps, half-duplex *)
	BMSR_10FULL* = 0x1000; (** Can do 10mbps, full-duplex *)
	BMSR_100HALF* = 0x2000; (** Can do 100mbps, half-duplex *)
	BMSR_100FULL* = 0x4000; (** Can do 100mbps, full-duplex *)
	BMSR_100BASE4* = 0x8000; (** Can do 100mbps, 4k packets *)

	(** Advertisement control register. *)
	ADVERTISE_SLCT* = 0x001f; (** Selector bits *)
	ADVERTISE_CSMA* = 0x0001; (** Only selector supported *)
	ADVERTISE_10HALF* = 0x0020; (** Try for 10mbps half-duplex *)
	ADVERTISE_1000XFULL* = 0x0020; (** Try for 1000BASE-X full-duplex *)
	ADVERTISE_10FULL* = 0x0040; (** Try for 10mbps full-duplex *)
	ADVERTISE_1000XHALF* = 0x0040; (** Try for 1000BASE-X half-duplex *)
	ADVERTISE_100HALF* = 0x0080; (** Try for 100mbps half-duplex *)
	ADVERTISE_1000XPAUSE* = 0x0080; (** Try for 1000BASE-X pause *)
	ADVERTISE_100FULL* = 0x0100; (** Try for 100mbps full-duplex *)
	ADVERTISE_1000XPSE_ASYM* = 0x0100; (** Try for 1000BASE-X asym pause *)
	ADVERTISE_100BASE4* = 0x0200; (** Try for 100mbps 4k packets *)
	ADVERTISE_PAUSE_CAP* = 0x0400; (** Try for pause *)
	ADVERTISE_PAUSE_ASYM* = 0x0800; (** Try for asymetric pause *)
	ADVERTISE_RESV* = 0x1000; (** Reserved *)
	ADVERTISE_RFAULT* = 0x2000; (** Say we can detect faults *)
	ADVERTISE_LPACK* = 0x4000; (** Ack link partners response *)
	ADVERTISE_NPAGE* = 0x8000; (** Next page bit *)

	ADVERTISE_FULL* = ADVERTISE_100FULL + ADVERTISE_10FULL + ADVERTISE_CSMA;
	ADVERTISE_ALL* = ADVERTISE_10HALF + ADVERTISE_10FULL + ADVERTISE_100HALF + ADVERTISE_100FULL;

	(** Link partner ability register. *)
	LPA_SLCT* = 0x001f; (** Same as advertise selector *)
	LPA_10HALF* = 0x0020; (** Can do 10mbps half-duplex *)
	LPA_1000XFULL* = 0x0020; (** Can do 1000BASE-X full-duplex *)
	LPA_10FULL* = 0x0040; (** Can do 10mbps full-duplex *)
	LPA_1000XHALF* = 0x0040; (** Can do 1000BASE-X half-duplex *)
	LPA_100HALF* = 0x0080; (** Can do 100mbps half-duplex *)
	LPA_1000XPAUSE* = 0x0080; (** Can do 1000BASE-X pause *)
	LPA_100FULL* = 0x0100; (** Can do 100mbps full-duplex *)
	LPA_1000XPAUSE_ASYM* = 0x0100; (** Can do 1000BASE-X pause asym *)
	LPA_100BASE4* = 0x0200; (** Can do 100mbps 4k packets *)
	LPA_PAUSE_CAP* = 0x0400; (** Can pause *)
	LPA_PAUSE_ASYM* = 0x0800; (** Can pause asymetrically *)
	LPA_RESV* = 0x1000; (** Reserved *)
	LPA_RFAULT* = 0x2000; (** Link partner faulted *)
	LPA_LPACK* = 0x4000; (** Link partner acked us *)
	LPA_NPAGE* = 0x8000; (** Next page bit *)

	LPA_DUPLEX* = LPA_10FULL + LPA_100FULL;
	LPA_100* = LPA_100FULL + LPA_100HALF + LPA_100BASE4;

	(** Expansion register for auto-negotiation. *)
	EXPANSION_NWAY* = 0x0001; (** Can do N-way auto-nego *)
	EXPANSION_LCWP* = 0x0002; (** Got new RX page code word *)
	EXPANSION_ENABLENPAGE* = 0x0004; (** This enables npage words *)
	EXPANSION_NPCAPABLE* = 0x0008; (** Link partner supports npage *)
	EXPANSION_MFAULTS* = 0x0010; (** Multiple faults detected *)
	EXPANSION_RESV* = 0xffe0; (** Reserved *)

	ESTATUS_1000_TFULL* = 0x2000; (** Can do 1000BT Full *)
	ESTATUS_1000_THALF* = 0x1000; (** Can do 1000BT Half *)

	(** N-way test register. *)
	NWAYTEST_RESV1* = 0x00ff; (** Reserved *)
	NWAYTEST_LOOPBACK* = 0x0100; (** Enable loopback for N-way *)
	NWAYTEST_RESV2* = 0xfe00; (** Reserved *)

	(** 1000BASE-T Control register *)
	ADVERTISE_1000FULL* = 0x0200; (** Advertise 1000BASE-T full duplex *)
	ADVERTISE_1000HALF* = 0x0100; (** Advertise 1000BASE-T half duplex *)

	(** 1000BASE-T Status register *)
	LPA_1000LOCALRXOK* = 0x2000; (** Link partner local receiver status *)
	LPA_1000REMRXOK* = 0x1000; (** Link partner remote receiver status *)
	LPA_1000FULL* = 0x0800; (** Link partner 1000BASE-T full duplex *)
	LPA_1000HALF* = 0x0400; (** Link partner 1000BASE-T half duplex *)
	
	(**
		Detect PHY device

		phyAddr: retuned PHY address (EnetBase.InvalidPhyAddr in case if no PHY found)
		allowZeroPhyAddr: TRUE to allow the use of PHY address 0
		res: error code
	*)
	PROCEDURE DetectPhy*(dev: EnetBase.LinkDevice; VAR phyAddr: UInt; allowZeroPhyAddr: BOOLEAN; VAR res: Int): BOOLEAN;
	VAR
		minAddr: UInt;
		d1, d2: UInt;
	BEGIN
		(*
			PHY address 0 cannot be used when multiple PHY's a sitting on the same MDIO serial bus.
			This address is reserved for broadcasting and can work only for writing (e.g. a command to
			reset multiple PHY's at the same time). Reading from this address will lead to contention on the bus.
		*)
		IF allowZeroPhyAddr THEN minAddr := 0; ELSE minAddr := 1; END;

		phyAddr := 32;
		REPEAT
			DEC(phyAddr);
			IF ~dev.phyRead(dev,phyAddr,MII_PHYSID1,d1,res) OR ~dev.phyRead(dev,phyAddr,MII_PHYSID2,d2,res) THEN
				phyAddr := InvalidPhyAddr;
				RETURN FALSE;
			END;
			IF (d1 # 0xFFFF) & (d2 # 0xFFFF) THEN
				res := 0;
				RETURN TRUE;
			END;
		UNTIL phyAddr = minAddr;

		phyAddr := InvalidPhyAddr;
		res := EnetBase.ErrPhyNotDetected;
		RETURN FALSE;
	END DetectPhy;

	(**
		Reset a PHY device
	*)
	PROCEDURE ResetPhy*(dev: EnetBase.LinkDevice; phyAddr: UInt; timeoutInMs: EnetTiming.Time; VAR res: Int): BOOLEAN;
	VAR
		d: UInt;
		t: EnetTiming.Timer;
	BEGIN
		IF ~dev.phyRead(dev,phyAddr,MII_BMCR,d,res) THEN RETURN FALSE; END;
		d := S.MSK(d,-BMCR_RESET-1) + BMCR_RESET;
		IF ~dev.phyWrite(dev,phyAddr,MII_BMCR,d,res) THEN RETURN FALSE; END;

		EnetTiming.SetTimerMilli(t,timeoutInMs);
		EnetTiming.StartTimer(t);
		REPEAT
			IF ~dev.phyRead(dev,phyAddr,MII_BMCR,d,res) THEN RETURN FALSE; END;
		UNTIL (S.MSK(d,BMCR_RESET) = 0) OR EnetTiming.IsTimerExpired(t);

		IF S.MSK(d,BMCR_RESET) = 0 THEN
			res := 0;
			RETURN TRUE;
		ELSE
			res := EnetBase.ErrTimeoutExpired;
			RETURN FALSE;
		END;
	END ResetPhy;

END EnetPhy.
