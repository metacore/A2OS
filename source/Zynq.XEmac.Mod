MODULE XEmac; (** AUTHOR "Timothee Martiel"; PURPOSE "Zynq7000 Ethernet Controller Driver"; *)
(** 2014.08.26		Adapted the driver for Minos to A2 *)

IMPORT SYSTEM, Machine, Objects, Kernel, KernelLog, Network, Commands, Modules, Plugins;

CONST
	Trace = FALSE;

	IRQ = 54;

	(* Directions in ErrorHandler *)
	Send = 1X;
	Recv = 2X;

	(* Link speed detect modes *)
	LinkSpeedAutodetect = 0;
	LinkSpeed10 = 1;
	LinkSpeed100 = 2;
	LinkSpeed1000 = 3;
	LinkSpeedMode = LinkSpeedAutodetect;

	(* state *)
	IsReady = 11111111H;
	IsStarted = 22222222H;

	(* Buffer descriptors *)
   	BdSize = 8;
	RxBdCount = 512;
	TxBdCount = 512;
	BdAdrOffset = 0H;
	BdStatOffset = 4H;

	BufSize = 1536;

	ZeroMAC = SYSTEM.VAL(Network.LinkAdr, [0X, 0X, 0X, 0X, 0X, 0X, 0X, 0X]);

	MaxTypeId = 4;

	(* Options *)
	(**
	 * Accept all incoming packets.
	 * This option defaults to disabled (cleared)
	 *)
	Promisc = 0;
	(**
	 * Frame larger than 1516 support for Tx & Rx.
	 * This option defaults to disabled (cleared)
	 *)
	Frame1536 = 1;(* 00000002H; *)
	(**
	 * VLAN Rx & Tx frame support.
	 * This option defaults to disabled (cleared)
	 *)
	Vlan = 2;(* 00000004H; *)
	(**
	 * Enable recognition of flow control frames on Rx
	 * This option defaults to enabled (set)
	 *)
	FlowControl = 4;(* 00000010H; *)
	(**
	 * Strip FCS and PAD from incoming frames. Note: PAD from VLAN frames is not
	 * stripped.
	 * This option defaults to enabled (set)
	 *)
	FcsStrip = 5;(* 00000020H; *)
	(**
	 * Generate FCS field and add PAD automatically for outgoing frames.
	 * This option defaults to disabled (cleared)
	 *)
	FcsInsert = 6;(* 00000040H; *)
	(**
	 * Enable Length/TYPE error checking for incoming frames. When this option is
	 * set, the MAC will filter frames that have a mismatched TYPE/length field
	 * and if REPORT_RXERR is set, the user is notified when these
	 * TYPEs of frames are encountered. When this option is cleared, the MAC will
	 * allow these TYPEs of frames to be received.
	 *
	 * This option defaults to disabled (cleared)
	 *)
	LenTypeErr = 7;(* 00000080H; *)
	(**
	 * Enable the transmitter.
	 * This option defaults to enabled (set)
	 *)
	TransmitterEnable = 8;(* 00000100H; *)
	(**
	 * Enable the receiver
	 * This option defaults to enabled (set)
	 *)
	ReceiverEnable = 9;(*00000200H *);
	(**
	 * Allow reception of the broadcast address
	 * This option defaults to enabled (set)
	 *)
	Broadcast = 10;(* 00000400H; *)
	(**
	 * Allows reception of multicast addresses programmed into hash
	 * This option defaults to disabled (clear)
	 *)
	Multicast = 11;(* 00000800H; *)
	(**
	 * Enable the RX checksum offload
	 * This option defaults to enabled (set)
	 *)
	RxChksumEnable = 12;(* 00001000H; *)
	(**
	 * Enable the TX checksum offload
	 * This option defaults to enabled (set)
	 *)
	TxChksumEnable = 13;(* 00002000H; *)
	Defaults = {Promisc, FlowControl, FcsInsert, FcsStrip, Broadcast, LenTypeErr, TransmitterEnable, ReceiverEnable, RxChksumEnable, TxChksumEnable};

	(* Register relative addresses *)
	Nwctrl = 0H;
	Nwcfg = 4H;
	Nwsr = 8H;
	Dmacr = 10H;
	Txsr = 14H;
	Rxqbase = 18H;
	Txqbase = 1CH;
	Rxsr = 20H;
	Isr = 24H;
	Ier = 28H;
	Idr = 2CH;
	Imr = 30H;
	PhyMntnc = 34H;
	Rxpause = 38H;
	Txpause = 3CH;
	HashL = 80H;
	HashH = 84H;
	Last = 1B4H;
	Laddr1l = 88H;
	Laddr1h = 8CH;
	Laddr2l = 90H;
	Laddr2h = 94H;
	Laddr3l = 98H;
	Laddr3h = 9CH;
	Laddr4l = 0A0H;
	Laddr4h = 0A4H;
	Match1 = 0A8H;
	Match2 = 0ACH;
	Match3 = 0B0H;
	Match4 = 0B4H;
	Stretch = 0BCH;
	OctTxL = 100H;
	OctTxH = 104H;
	Txcnt = 108H;
	Txbccnt = 10CH;
	Txmccnt = 110H;
	Txpausecnt = 114H;
	Tx64cnt = 118H;
	Tx65cnt = 11CH;
	Tx128cnt = 120H;
	Tx256cnt = 124H;
	Tx512cnt = 128H;
	Tx1024cnt = 12CH;
	Tx1519cnt = 130H;
	Txuruncnt = 134H;
	Snglcollcnt = 138H;
	Multicollcnt = 13CH;
	Excesscollcnt = 140H;
	Latecollcnt = 144H;
	Txdefercnt = 148H;
	Txcsensecnt = 14CH;
	Octrxl = 150H;
	Octrxh = 154H;
	Rxcnt = 158H;
	Rxbroadcnt = 15CH;
	Rxmulticnt = 160H;
	Rxpausecnt = 164H;
	Rx64cnt = 168H;
	Rx65cnt = 16CH;
	Rx128cnt = 170H;
	Rx256cnt = 174H;
	Rx512cnt = 178H;
	Rx1024cnt = 17CH;
	Rx1519cnt = 180H;
	Rxundrcnt = 184H;
	Rxovrcnt = 188H;
	Rxjabcnt = 18CH;
	Rxfcscnt = 190H;
	Rxlengthcnt = 194H;
	Rxsymbcnt = 198H;
	Rxaligncnt = 19CH;
	Rxreserrcnt = 1A0H;
	Rxorcnt = 1A4H;
	Rxipccnt = 1A8H;
	Rxtcpccnt = 1ACH;
	Rxudpccnt = 1B0H;
	C1588_sec = 1D0H;
	C1588_nanosec = 1D4H;
	C1588_adj = 1D8H;
	C1588_inc = 1DCH;
	Ptp_txsec = 1E0H;
	Ptp_txnanosec = 1E4H;
	Ptp_rxsec = 1E8H;
	Ptp_rxnanosec = 1ECH;
	Ptpp_txsec = 1F0H;
	Ptpp_txnanosec = 1F4H;
	Ptpp_rxsec = 1F8H;
	Ptpp_rxnanosec = 1FCH;

	(** Masks and bits *)
	DmacrRxBuf = {16 .. 23};
	DmacrRxBufShift = 16;
	DmacrTcpChksum = 11;
	DmacrTxSize = 10;
	DmacrRxSize = {8, 9};
	DmacrEndian = 7;
	DmacrBlength = {0 .. 4};
	DmacrSingleAhbBurst = 0;
	DmacrIncr4AhbBurst = 2;
	DmacrIncr8AhbBurst = 3;
	DmacrIncr16AhbBurst = 4;

	IxrPtppstx = 25;
	IxrPtppdrtx = 24;
	IxrPtpstx = 23;
	IxrPtpdrtx = 22;

	IxrPtppsrx = 21;
	IxrPtppdrrx = 20;
	IxrPtpsrx = 19;
	IxrPtpdrrx = 18;

	IxrPauseTx = 14;
	IxrPauseZero = 13;
	IxrPauseNzero = 12;
	IxrHrespnOk = 11;
	IxrRxOvr = 10;

	IxrTxCompl = 7;
	IxrTxExh = 6;
	IxrRetry = 5;
	IxrUrun = 4;

	IxrTxUsed = 3;
	IxrRxUsed = 2;
	IxrFrameRx = 1;
	IxrMgmnt = 0;

	IxrAll = {0 .. 14};
	IxrTxErr = {IxrTxExh, IxrRetry, IxrUrun, IxrTxUsed};
	IxrRxErr = {IxrHrespnOk, IxrRxUsed, IxrRxOvr};

	LaddrMach = {0 .. 31};

	NwcfgBadpreambEn = 29;
	NwcfgIpdStretch = 28;
	NwcfgFcsIgnore = 26;
	NwcfgHdRxEn = 25;
	NwcfgRxChkSumEn = 24;
	NwcfgPauseCopyDi = 23;
	NwcfgMdcShift = 18;
	NwcfgMdcClkDiv = {18 .. 20};
	NwcfgFcsRem = 17;
	NwcfgLengthErrDscrd = 16;
	Nwcfg1000 = 10;
	Nwcfg100 = 0;
	NwcfgUcastHashEn = 7;
	NwcfgFdEn = 1;
	Nwcfg1536RxEn = 8;
	NwcfgNvlanDisc = 2;
	NwcfgPauseEn = 13;
	NwcfgCopyAllEn = 4;
	NwcfgBcastDi = 5;
	NwcfgMcastHashEn = 6;

	NwctrlZeroPauseTx = {11};
	NwctrlPauseTx = {11};
	NwctrlHaltTx = {10};
	NwctrlStartTx = {9};
	NwctrlStatwen = {7};
	NwctrlStatinc = {6};
	NwctrlStatclr = {5};
	NwctrlMdEn = {4};
	NwctrlTxEn = {3};
	NwctrlRxEn = {2};
	NwctrlLoopEn = {1};

	NwsrMdio = 1;
	NwsrMdioIdle = 2;

	PhyMntncOp = {17, 30};
	PhyMntncOpR = {29};
	PhyMntncOpW = {28};
	PhyMntncAddR = {23 .. 27};
	PhyMntncReg = {18 .. 22};
	PhyMntncData = {0 .. 15};
	PhyMntncPhyAdShift = 23;
	PhyMntncPhRegShift = 18;

	RxsrHrespnok = 3;
	RxsrRxOvr = 2;
	RxsrFrameRx = 1;
	RxsrBuffna = 0;
	RxsrError = 13;

	RxBufBcast = 31;
	RxBufMultiHash = 30;
	RxBufUniHash = 29;
	RxBufExh = 28;
	RxBufAMatch = {25,26};
	RxBufIDfound = 24;
	RxBufIDmatch = {22,23};
	RxBufVlan = 21;
	RxBufPri = 20;
	RxBufVpri = {17..19};
	RxBufCfi = 16;
	RxBufEof = 15;
	RxBufSof = 14;
	RxBufLen = {0 .. 13};
	RxBufWrap = 1;
	RxBufNew = 0;
	RxBufAdd = {2 .. 31};
	RxBufSize = 1536;
	RxBufUnit = 64;

	TxBufUsed = 31;
	TxBufWrap = 30;
	TxBufRetry = 29;
	TxBufUrun = 28;
	TxBufExh = 27;
	TxBufTcp = 26;
	TxBufNocrc = 16;
	TxBufLast = 15;
	TxBufLen = {0 .. 13};

	TxsrHrespnok = 8;
	TxsrUrun = 6;
	TxsrTxCompl = 5;
	TxsrBufExh = 4;
	TxsrTxGo = 3;
	TxsrRxOvr = 2;
	TxsrFrameRx = 1;
	TxsrUsedRead = 0;
	TxsrError = {TxsrHrespnok, TxsrUrun, TxsrBufExh, TxsrRxOvr, TxsrFrameRx, TxsrUsedRead};

	(** Clock divisors *)
	MdcDiv8 = 0;
	MdcDiv16 = 1;
	MdcDiv32 = 2;
	MdcDiv48 = 3;
	MdcDiv64 = 4;
	MdcDiv96 = 5;
	MdcDiv128 = 6;
	MdcDiv224 = 7;

	(* Phy return state *)
	EmacMiiReadError = 1003;
	EmacMiiBusy = 1004;
	Success = 0;
	Failure = 1;
	DeviceIsStarted = 5;
	DeviceIsStopped = 6;

	(* Phy registers *)
	IeeeControlReg = 0;
	IeeeStatusReg = 1;
	IeeeAutonegoAdvertiseReg = 4;
	IeeePartnerAbilities1Reg = 5;
	Ieee1000AdvertiseReg = 9;
	IeeePartnerAbilities3Reg = 10;
	IeeeCopperSpecificControlReg = 16;
	IeeeSpecificStatusReg = 17;
	IeeeCopperSpecificStatusReg2 = 19;
	IeeeControlRegMac = 21;
	IeeePageAddressRegister = 22;

	(* Phy bits and masks *)
	Advertise10Half = 5;
	Advertise10Full = 6;
	Advertise100Half = 7;
	Advertise100Full = 8;
	Advertise100 = {Advertise100Full, Advertise100Half};
	Advertise10 = {Advertise10Full, Advertise10Half};
	Advertise1000 = {8, 9};

	IeeeCtrl1GbpsLinkspeed = 2040H;
	IeeeCtrlLinkSpeed = {6};
	IeeeCtrlLinkSpeed1000M = {6};
	IeeeCtrlLinkSpeed100M = {13};
	IeeeCtrlLinkSpeed10M = {};
	IeeeCtrlReset = {15};
	IeeeCtrlAutonegotiateEnable = {12};
	IeeeStatAutonegotiateCapable = {3};
	IeeeStatAutonegotiateComplete = {5};
	IeeeStatAutonegotiateRestart = {9};
	IeeeStat1gbpsExtensions = {8};
	IeeeAn1Ability = {5 .. 12};
	IeeeAn3Ability1Gbps = {10 .. 11};
	IeeeAn1Ability100Mbps = {7 .. 9};
	IeeeAn1Ability10Mbps = {5 .. 6};
	IeeeRgmiiTxRxClockDelayed = {4 .. 5};

	IeeeAsymmetricPause = {11};
	IeeePause = {10};
	IeeeAutonegError = {15};

	PhyDetectReg = 1;
	PhyDetect = {3, 11, 12};

TYPE
	Buffer = ARRAY BufSize OF CHAR;

	(** Implements the Network.LinkDevice abstract class. *)
	LinkDevice * = OBJECT (Network.LinkDevice)
		VAR
			ctrl: Controller;

		PROCEDURE & Constr * (type, mtu, adrSize: SIGNED32);
		VAR
			i: SIGNED32;
		BEGIN
			Constr^(type, mtu, adrSize);
			FOR i := 0 TO LEN(broadcast) - 1 DO
				broadcast[i] := 0FFX
			END;
		END Constr;

		PROCEDURE Linked * (): SIGNED32;
		BEGIN
			RETURN Network.LinkLinked
		END Linked;

		PROCEDURE DoSend * (dst: Network.LinkAdr; type: SIGNED32; CONST l3hdr, l4hdr, data: ARRAY OF CHAR; h3len, h4len, dofs, dlen: SIGNED32);
		BEGIN
			ctrl.SendFrame(dst, type, l3hdr, l4hdr, data, h3len, h4len, dofs, dlen);
		END DoSend;

		PROCEDURE Finalize * (connected: BOOLEAN);
		BEGIN
			ctrl.Finalize;
			Finalize^(connected);
		END Finalize;
	END LinkDevice;

	(** Ethernet controller driver. *)
	Controller = OBJECT
		VAR
			(** Base of memory-mapped registers *)
			iobase: ADDRESS;
			dev: LinkDevice;
			phy: Phy;
			state, isStarted: SIGNED32;
			speed: SIGNED32;
			timer: Kernel.Timer;
			rxFrames: POINTER TO ARRAY OF Buffer;
			txFrame: Buffer;
			lastRxQBar, lastTxQBar: ADDRESS;
			rxBdBase, txBdBase: ADDRESS;
			options: SET;
			txBdStartAdr, txBdEndAdr, rxBdStartAdr, rxBdEndAdr: ADDRESS;
			kill, start: BOOLEAN;

			(* For DMA interaction *)
			buffer: POINTER TO ARRAY OF CHAR;

			(** Statistics *)
			nbrRxFrames, nbrtxFrames, nbrRxErrors, nbrTxErrors: SIGNED32;

		(** Initializes the controller.
			iobase: base address of the registers
		*)
		PROCEDURE & Init * (iobase: ADDRESS; ld: LinkDevice);
		VAR
			i: SIGNED32;
			reg: SET;
			(* TEST *)arp: ARRAY 28 OF CHAR;
			buf: ARRAY 256 OF Network.Buffer;
		BEGIN
			NEW(timer);
			NEW(rxFrames, RxBdCount);
			options := Defaults;
			SELF.iobase := iobase;
			dev := ld;
			dev.calcChecksum := {Network.ChecksumIP, Network.ChecksumTCP, Network.ChecksumUDP};
			kill := FALSE;
			start := FALSE;
			state := IsReady;
			Reset;

			(* Initialize HW *)
			IF Trace THEN KernelLog.String("Zynq.XEmac: Initializing hardware"); KernelLog.Ln END;
			SetMacAddress(1, SYSTEM.VAL(Network.LinkAdr, [0X, 0AX, 35X, 0X, 1X, 2X, 0X, 0X]));
			SetMdioDivisor(MdcDiv224);
			NEW(phy, iobase);
			speed := phy.linkSpeed;
			IF speed # 1000 THEN
				IF Trace THEN KernelLog.String("XEmac: error in speed initialization."); KernelLog.Ln END;
				RETURN
			END;

			SetOperatingSpeed(speed);

			SYSTEM.GET(iobase + Dmacr, reg);
			INCL(reg, 4);
			SYSTEM.PUT(iobase + Dmacr, reg);

			SetMdioDivisor(MdcDiv224);
			IF Trace THEN KernelLog.String("XEmac: Initializing DMA"); KernelLog.Ln END;
			FOR i := 0 TO 6000000 DO END;

			InitDMA;

			(* preallocate network stack buffers *)
			FOR i := 0 TO LEN(buf,0)-1 DO
				buf[i] := Network.GetNewBuffer();
			END;
			FOR i := 0 TO LEN(buf,0)-1 DO
				Network.ReturnBuffer(buf[i]);
			END;

			IF Trace THEN KernelLog.String("XEmac: Starting controller"); KernelLog.Ln END;
			Start
		END Init;

		(* Terminates the process *)
		PROCEDURE Kill;
		BEGIN {EXCLUSIVE}
			kill := TRUE
		END Kill;

		PROCEDURE Start;
		VAR
			reg: SET;
		BEGIN
			IF Trace THEN KernelLog.String("Starting XEmac"); KernelLog.Ln END;
			IF isStarted = IsStarted THEN RETURN END;
			(* Start DMA *)
			SYSTEM.PUT(iobase + Rxqbase, rxBdBase);
			SYSTEM.PUT(iobase + Txqbase, txBdBase);

			(* Clear any existing interrupt status *)
			SYSTEM.PUT(iobase + Isr, IxrAll);

			(* Optionally enable TX and RX *)
			IF TransmitterEnable IN options THEN
				SYSTEM.GET(iobase + Nwctrl, reg);
				reg := reg + NwctrlTxEn;
				SYSTEM.PUT(iobase + Nwctrl, reg)
			END;
			IF ReceiverEnable IN options THEN
				SYSTEM.GET(iobase + Nwctrl, reg);
				reg := reg + NwctrlRxEn;
				SYSTEM.PUT(iobase + Nwctrl, reg)
			END;

			(* Enable TX and RX interrupts *)
			SYSTEM.PUT(iobase + Ier, (IxrTxErr + IxrRxErr + {IxrTxCompl, IxrFrameRx}) * IxrAll);

			(*BEGIN {EXCLUSIVE}
				start := TRUE
			END;*)
		(*VAR
			reg: SET;
		BEGIN
			SYSTEM.GET(iobase + Nwctrl, reg);
			reg := reg + NwctrlStartTx;
			SYSTEM.PUT(iobase + Nwctrl, reg)*)
		END Start;

		PROCEDURE Stop;
		VAR
			reg: SET;
		BEGIN
			ASSERT(state = IsReady);
			(* Disable all interrupts *)
			SYSTEM.PUT32(iobase + Idr, IxrAll);
			(* Disable TX and RX *)
			SYSTEM.GET(iobase + Nwctrl, reg);
			reg := reg - (NwctrlRxEn + NwctrlTxEn);
			SYSTEM.PUT(iobase + Nwctrl, reg);
			isStarted := 0
		END Stop;

		PROCEDURE Transmit;
		VAR
			reg: SET;
		BEGIN
			IF Trace THEN KernelLog.String("XEmac: transmitting"); KernelLog.Ln END;
			SYSTEM.GET(iobase + Nwctrl, reg);
			reg := reg + NwctrlStartTx;
			SYSTEM.PUT(iobase + Nwctrl, reg)
		END Transmit;

		(** Stop and restart device *)
		PROCEDURE Reset;
		VAR
			i, tmp: SIGNED32;
			reg: SET;
		BEGIN
			IF Trace THEN KernelLog.String("XEmac resetting controller"); KernelLog.Ln END;
			ASSERT(state = IsReady);

			Stop;
			options := Defaults;
			reg := (NwctrlStatclr + NwctrlMdEn) * (-NwctrlLoopEn);
			SYSTEM.PUT(iobase + Nwctrl, reg);

			reg := {};
			INCL(reg, Nwcfg100);
			INCL(reg, NwcfgFdEn);
			INCL(reg, NwcfgUcastHashEn);
			SYSTEM.PUT(iobase + Nwcfg, reg);

			i := RxBufSize DIV RxBufUnit;
			IF RxBufSize MOD RxBufUnit # 0 THEN INC(i) END;
			reg := SYSTEM.VAL(SET, LSH(i, DmacrRxBufShift)) * DmacrRxBuf + DmacrRxSize;
			INCL(reg, DmacrTxSize);
			SYSTEM.PUT(iobase + Dmacr, reg);

			SYSTEM.PUT32(iobase + Txsr, 0);
			SYSTEM.PUT32(iobase + Rxqbase, 0);
			SYSTEM.PUT32(iobase + Txqbase, 0);
			SYSTEM.PUT32(iobase + Rxsr, 0);
			SYSTEM.PUT32(iobase + Idr, IxrAll);

			SYSTEM.GET(iobase + Isr, reg);
			SYSTEM.PUT(iobase + Isr, reg);

			SYSTEM.PUT32(iobase + PhyMntnc, 0);

			ClearHash;

			(* Clear all MAC addresses *)
			FOR i := 1 TO 4 DO
				SetMacAddress(i, ZeroMAC);
				tmp := SetTypeIdCheck(i, 0)
			END;

			(* Clear all counters. *)
			FOR i := 0 TO (Last- OctTxL) DIV 4 - 1 DO
				SYSTEM.GET(iobase + OctTxL + 4 * i, reg)
			END;

			(* Disable receiver. *)
			SYSTEM.GET(iobase + Nwctrl, reg);
			SYSTEM.PUT(iobase + Nwctrl, reg - NwctrlRxEn);

			SetOptions(options - {TransmitterEnable, ReceiverEnable});
			ClearOptions(-options);
		END Reset;

		PROCEDURE ResetDevice;
		VAR
			options: SET;
		BEGIN
			Stop;
			options := SELF.options;
			Reset;
			SetOptions(options);
			ClearOptions(-options)
		END ResetDevice;

		PROCEDURE SendFrame (CONST dst: Network.LinkAdr; type: SIGNED32; CONST l3hdr, l4hdr, data: ARRAY OF CHAR; h3len, h4len, dofs, dlen: SIGNED32);
		VAR
			txLen, offset: SIGNED32;
			bufferAdr, txbd: ADDRESS;
			intsEnabled: BOOLEAN;
			reg: SET;
		BEGIN (*{EXCLUSIVE}*)
			IF Trace THEN KernelLog.String("XEmac: Sending Frame"); KernelLog.Ln END;
			(* Prepare buffer *) (* This part is taken from RTL8169.Mod *)
			txLen := 14 + h3len + h4len + dlen;
			bufferAdr := ADDRESSOF(txFrame[0]);

			(* set destination mac address (first 6 bytes of eth frame) *)
			SYSTEM.MOVE(ADDRESSOF(dst[0]), bufferAdr, 6);
			(*txFrame[0] := dst[0]; txFrame[1] := dst[1]; txFrame[2] := dst[2]; txFrame[3] := dst[3]; txFrame[4] := dst[4]; txFrame[5] := dst[5];*)
			(* set source mac address (6 bytes @ offset 6 of eth frame) *)
			SYSTEM.MOVE(ADDRESSOF(dev.local[0]), bufferAdr + 6, 6);
			(*txFrame[6]:=000X;txFrame[7]:=00AX;txFrame[8]:=035X;txFrame[9]:=000X;txFrame[10]:=001X;txFrame[11]:=002X;*)

			(* set upper layer type, bring type from host to network byte order *)
			SYSTEM.PUT16(bufferAdr + 12, ROT(SYSTEM.VAL(SIGNED16, SHORT(type)), 8));

			(*IF Trace THEN
				KernelLog.Buffer(txFrame, 0, txLen);
				KernelLog.Ln
			END;*)

			offset := 14;
			(* move layer 3 and layer 4 headers, data *)
			IF h3len > 0 THEN
				SYSTEM.MOVE(ADDRESSOF(l3hdr[0]), bufferAdr + offset, h3len);
				INC(offset, h3len);
			END;
			IF h4len > 0 THEN
				SYSTEM.MOVE(ADDRESSOF(l4hdr[0]), bufferAdr + offset, h4len);
				INC(offset, h4len);
			END;
			IF offset + dlen < BufSize THEN
				SYSTEM.MOVE(ADDRESSOF(data[0]) + dofs, bufferAdr + offset, dlen);
				INC(offset, dlen);
			END;

			(* make the frame at least 64 bytes long *)
			WHILE offset < 60 DO
				txFrame[offset] := CHR(0);
				INC(offset);
				INC(txLen)
			END;

			(*IF Trace THEN
				KernelLog.String("Sending frame of length ");
				KernelLog.Int(txLen, 0);
				KernelLog.Ln;
				KernelLog.Memory(bufferAdr, txLen)
			END;*)

			(* Send it with DMA *)
			intsEnabled := Machine.AreInterruptsEnabled();
			Machine.DisableInterrupts;

			SYSTEM.GET(iobase + Txqbase, txbd);
			IF txbd = 0 THEN txbd := txBdStartAdr END;

			Machine.FlushDCacheRange(ADDRESSOF(txFrame[0]), txLen);

			SYSTEM.PUT(txbd + BdAdrOffset, ADDRESSOF(txFrame));
			IF txbd # txBdEndAdr THEN
				SYSTEM.PUT(txbd + BdStatOffset, {TxBufLast} + SYSTEM.VAL(SET, txLen));
			ELSE
				IF Trace THEN KernelLog.String("END OF TXBUFFERS"); KernelLog.Ln END;
				SYSTEM.PUT(txbd + BdStatOffset, {TxBufLast, TxBufWrap} + SYSTEM.VAL(SET, txLen));
			END;

			(* no need to flush/invalidate cache for BD memory space
			Machine.FlushDCacheRange(txbd, BdSize);
			*)

			CODE
				DSB
			END;

			(* Transmit *)
			Transmit;

			IF intsEnabled THEN Machine.EnableInterrupts END;
		END SendFrame;

		(** Called by the polling body. Signals the new frames to the link device *)
		PROCEDURE ReceiveFrame;
		VAR
			currentBd, adr: ADDRESS;
			len, i: SIGNED32;
			reg: SET;
			buf: Network.Buffer;
			type: SIGNED16;
		BEGIN
			(*IF Trace THEN KernelLog.String("Receiving frame"); KernelLog.Ln END;*)
			currentBd := lastRxQBar;
			SYSTEM.GET(currentBd + BdAdrOffset, adr);
			adr := adr - (adr MOD 4);

			SYSTEM.GET(currentBd, reg);
			IF RxBufNew IN reg THEN
				(*IF Trace THEN
					KernelLog.String("Current BD: "); KernelLog.Address(currentBd); KernelLog.Ln;
					KernelLog.String("QBar: "); KernelLog.Address(SYSTEM.GET32(iobase + Rxqbase)); KernelLog.Ln
				END;*)

				IF SYSTEM.GET32(currentBd + 4) = 0 THEN
					SYSTEM.GET(iobase + Nwctrl, reg);
					reg := reg * SET(-NwctrlRxEn);
					SYSTEM.PUT(iobase + Nwctrl, reg);

					SYSTEM.GET(iobase + Nwctrl, reg);
					reg := reg + NwctrlRxEn + {18};
					SYSTEM.PUT(iobase + Nwctrl, reg)
				ELSE
					IF Trace THEN KernelLog.String("Receiving frame"); KernelLog.Ln END;
					SYSTEM.GET(currentBd + BdStatOffset, reg);
					len := SYSTEM.VAL(SIGNED32, reg * RxBufLen);
					(* Invalidate DCache *)
					(* no need to flush/invalidate cache for BD memory space
					Machine.InvalidateDCacheRange(currentBd,BdSize);
					*)
					Machine.InvalidateDCacheRange(adr,len);

					(* Construct Frame *)
					buf := Network.GetNewBuffer(); ASSERT(buf # NIL);
					buf.ofs := 14;
					buf.len := len - 14;
					buf.next := NIL;
					buf.prev := NIL;
					buf.calcChecksum := dev.calcChecksum;

					SYSTEM.MOVE(adr+6,ADDRESSOF(buf.src[0]),6);

					type := SIGNED16(SYSTEM.GET8(adr + 12)) * 100H + SIGNED16(SYSTEM.GET8(adr + 13));
					SYSTEM.MOVE(adr,ADDRESSOF(buf.data[0]),len);
					dev.QueueBuffer(buf, type)
				END
			END;

			IF currentBd = rxBdEndAdr THEN
				SYSTEM.PUT32(currentBd + BdAdrOffset, adr + 2);
				lastRxQBar := rxBdStartAdr
			ELSE
				SYSTEM.PUT32(currentBd + BdAdrOffset, adr);
				INC(lastRxQBar, BdSize)
			END;
			SYSTEM.PUT32(currentBd + BdStatOffset, 0);

			(* no need to flush/invalidate cache for BD memory space
			Machine.FlushDCacheRange(currentBd, BdSize);
			*)
		END ReceiveFrame;

		PROCEDURE SetOptions (opts: SET);
		VAR
			reg, regNetCfg, regNewNetCfg: SET;
		BEGIN
			IF Trace THEN KernelLog.String("XEmac.SetOptions: "); KernelLog.Hex(SYSTEM.VAL(ADDRESS, opts), -8); KernelLog.Ln END;

			ASSERT(state = IsReady);


			(* Many of these options will change the NET_CONFIG registers.
			 * To reduce the amount of IO to the device, group these options here
			 * and change them all at once.
			 *)

			(* Grab current register contents *)
			SYSTEM.GET(iobase + Nwcfg, regNetCfg);
			regNewNetCfg := regNetCfg;
			IF Trace THEN KernelLog.String("regNetCfg="); KernelLog.Hex(SYSTEM.VAL(SIGNED32, regNetCfg), -8); KernelLog.Ln END;
			(*
			 * It is configured to max 1536.
			 *)
			IF Frame1536 IN opts  THEN
				regNewNetCfg := regNewNetCfg + {Nwcfg1536RxEn};
			END;

			(* Turn on VLAN packet only, only VLAN tagged will be accepted *)
			IF Vlan IN opts  THEN
				regNewNetCfg := regNewNetCfg + {NwcfgNvlanDisc};
			END;

			(* Turn on FCS stripping on receive packets *)
			IF FcsStrip IN opts  THEN
				regNewNetCfg := regNewNetCfg + {NwcfgFcsRem};
			END;

			(* Turn on length/type field checking on receive packets *)
			IF LenTypeErr IN opts  THEN
				regNewNetCfg := regNewNetCfg + {NwcfgLengthErrDscrd};
			END;

			(* Turn on flow control *)
			IF FlowControl IN opts  THEN
				regNewNetCfg := regNewNetCfg + {NwcfgPauseEn};
			END;

			(* Turn on promiscuous frame filtering (all frames are received) *)
			IF Promisc IN opts  THEN
				regNewNetCfg := regNewNetCfg + {NwcfgCopyAllEn};
			END;

			(* Allow broadcast address reception *)
			IF Broadcast IN opts  THEN
				regNewNetCfg := regNewNetCfg - {NwcfgBcastDi};
			END;

			(* Allow multicast address filtering *)
			IF Multicast IN opts  THEN
				regNewNetCfg := regNewNetCfg + {NwcfgMcastHashEn};
			END;

			(* enable RX checksum offload *)
			IF RxChksumEnable IN opts  THEN
				regNewNetCfg := regNewNetCfg + {NwcfgRxChkSumEn};
			END;

			(* Officially change the NET_CONFIG registers if it needs to be
			 * modified.
			 *)
			IF regNetCfg # regNewNetCfg THEN
				SYSTEM.PUT(iobase + Nwcfg, regNewNetCfg);
			END;
			IF Trace THEN KernelLog.String("regNewNetCfg="); KernelLog.Hex(SYSTEM.VAL(SIGNED32, regNewNetCfg), -8); KernelLog.Ln END;

			(* Enable TX checksum offload *)
			IF TxChksumEnable IN opts  THEN
				SYSTEM.GET(iobase + Dmacr, reg);
				reg := reg + {DmacrTcpChksum};
				SYSTEM.PUT(iobase + Dmacr, reg);
				IF Trace THEN KernelLog.String("DMACR_OFFSET reg="); KernelLog.Hex(SYSTEM.VAL(SIGNED32, reg), -8); KernelLog.Ln END;
			END;

			(* Enable transmitter *)
			IF TransmitterEnable IN opts  THEN
				SYSTEM.GET(iobase + Nwctrl, reg);
				reg := reg + NwctrlTxEn;
				SYSTEM.PUT(iobase + Nwctrl, reg);
				IF Trace THEN KernelLog.String("NWCTRL_OFFSET reg="); KernelLog.Hex(SYSTEM.VAL(SIGNED32, reg), -8); KernelLog.Ln END;
			END;

			(* Enable receiver *)
			IF ReceiverEnable IN opts  THEN
				SYSTEM.GET(iobase + Nwctrl, reg);
				reg := reg + NwctrlRxEn;
				SYSTEM.PUT(iobase + Nwctrl, reg);
				IF Trace THEN KernelLog.String("NWCTRL_OFFSET reg="); KernelLog.Hex(SYSTEM.VAL(SIGNED32, reg), -8); KernelLog.Ln END;
			END;

			(* The remaining options not handled here are managed elsewhere in the
			 * driver. No register modifications are needed at this time. Reflecting
			 * the option in InstancePtr->Options is good enough for now.
			 *)

			(* Set options word to its new value *)
			SELF.options := SELF.options + opts;
			IF Trace THEN KernelLog.String("SetOptions END "); KernelLog.Address(SYSTEM.VAL(ADDRESS, SELF.options)); KernelLog.Ln END;
		END SetOptions;

		PROCEDURE ClearOptions (opts: SET);
		VAR
			reg, old: SET;
		BEGIN
			IF Trace THEN KernelLog.String("XEmac: Clear Options"); KernelLog.Ln END;

			SYSTEM.GET(iobase + Nwcfg, reg);
			old := reg;

			(*
			 * It is configured to max 1536.
			 *)
			IF Frame1536 IN opts  THEN
				EXCL(reg, Nwcfg1536RxEn);
			END;

			(* Turn off VLAN packet only, only VLAN tagged will be accepted *)
			IF Vlan IN opts  THEN
				EXCL(reg, NwcfgNvlanDisc);
			END;

			(* Turn off FCS stripping on receive packets *)
			IF FcsStrip IN opts  THEN
				EXCL(reg, NwcfgFcsRem);
			END;

			(* Turn off length/type field checking on receive packets *)
			IF LenTypeErr IN opts  THEN
				EXCL(reg, NwcfgLengthErrDscrd);
			END;

			(* Turn off flow control *)
			IF FlowControl IN opts  THEN
				EXCL(reg, NwcfgPauseEn);
			END;

			(* Turn off promiscuous frame filtering (all frames are received) *)
			IF Promisc IN opts  THEN
				EXCL(reg, NwcfgCopyAllEn);
			END;

			(* Forbid broadcast address reception *)
			IF Broadcast IN opts  THEN
				EXCL(reg, NwcfgBcastDi);
			END;

			(* Forbid multicast address filtering *)
			IF Multicast IN opts  THEN
				EXCL(reg, NwcfgMcastHashEn);
			END;

			(* Disable RX checksum offload *)
			IF RxChksumEnable IN opts  THEN
				EXCL(reg, NwcfgRxChkSumEn);
			END;

			(* Officially change the NET_CONFIG registers if it needs to be
			 * modified.
			 *)
			IF reg # old THEN
				SYSTEM.PUT(iobase + Nwcfg, reg);
			END;
			IF Trace THEN KernelLog.String("regNewNetCfg="); KernelLog.Hex(SYSTEM.VAL(SIGNED32, reg), -8); KernelLog.Ln END;

			(* Disable TX checksum offload *)
			IF TxChksumEnable IN opts  THEN
				SYSTEM.GET(iobase + Dmacr, reg);
				EXCL(reg, DmacrTcpChksum);
				SYSTEM.PUT(iobase + Dmacr, reg);
				IF Trace THEN KernelLog.String("DMACR_OFFSET reg="); KernelLog.Hex(SYSTEM.VAL(SIGNED32, reg), -8); KernelLog.Ln END;
			END;

			(* Disable transmitter *)
			IF TransmitterEnable IN opts  THEN
				SYSTEM.GET(iobase + Nwctrl, reg);
				reg := reg * SET(-NwctrlTxEn);
				SYSTEM.PUT(iobase + Nwctrl, reg);
				IF Trace THEN KernelLog.String("NWCTRL_OFFSET reg="); KernelLog.Hex(SYSTEM.VAL(SIGNED32, reg), -8); KernelLog.Ln END;
			END;

			(* Disable receiver *)
			IF ReceiverEnable IN opts  THEN
				SYSTEM.GET(iobase + Nwctrl, reg);
				reg := reg * SET(-NwctrlRxEn);
				SYSTEM.PUT(iobase + Nwctrl, reg);
				IF Trace THEN KernelLog.String("NWCTRL_OFFSET reg="); KernelLog.Hex(SYSTEM.VAL(SIGNED32, reg), -8); KernelLog.Ln END;
			END;

			SELF.options := SELF.options * (-opts);
		END ClearOptions;

		PROCEDURE ClearHash;
		BEGIN
			IF Trace THEN KernelLog.String("XEmac: Clear Hash"); KernelLog.Ln END;
			ASSERT(state = IsReady);
			SYSTEM.PUT32(iobase + HashL, 0);
			SYSTEM.PUT32(iobase + HashH, 0)
		END ClearHash;

		PROCEDURE SetMdioDivisor (divisor: SIGNED32);
			VAR
				reg: SET;
		BEGIN
			ASSERT(state = IsReady);
			(* Only last 3 bits are valid *)
			ASSERT(divisor < 8);

			SYSTEM.GET(iobase + Nwcfg, reg);
			reg := reg * SET(-NwcfgMdcClkDiv);
			reg := reg + SYSTEM.VAL(SET, LSH(divisor, NwcfgMdcShift));
			SYSTEM.PUT(iobase + Nwcfg, reg);
		END SetMdioDivisor;

		PROCEDURE SetOperatingSpeed (speed: SIGNED32);
		VAR
			reg: SET;
		BEGIN
			IF Trace THEN KernelLog.String("XEmac: setting operating speed."); KernelLog.Ln END;
			ASSERT(state = IsReady);
			ASSERT((speed = 10) OR (speed = 100) OR (speed = 1000));

			SYSTEM.GET(iobase + Nwcfg, reg);

			reg := reg - {Nwcfg1000, Nwcfg100};
			CASE speed OF
				 10:
				|100:
					INCL(reg, Nwcfg100)
				|1000:
					INCL(reg, Nwcfg1000)
			END;

			SYSTEM.PUT(iobase + Nwcfg, reg);

			IF Trace THEN KernelLog.String("Waiting for operation speed to stabilize"); KernelLog.Ln END;
			timer.Sleep(1000);
			IF Trace THEN KernelLog.String("XEmac: operating speed set."); KernelLog.Ln END;
		END SetOperatingSpeed;

		(*! TODO: change parameter interface to a more convenient one *)
		PROCEDURE SetMacAddress(index: SIGNED32; mac: Network.LinkAdr);
		VAR
			reg: SET;
		BEGIN
			ASSERT(index > 0);
			DEC(index);
			reg := SYSTEM.VAL(SET, ORD(mac[0]) + LSH(ORD(mac[1]), 8) + LSH(ORD(mac[2]), 16) + LSH(ORD(mac[3]), 24));
			SYSTEM.PUT(iobase + Laddr1l + (index * 8), reg);

			(* There are reserved bits in TOP so don't affect them *)
			SYSTEM.GET(iobase + Laddr1h + (index * 8), reg);
			reg := reg * SET(-LaddrMach) + SYSTEM.VAL(SET, ORD(mac[4]) + LSH(ORD(mac[5]), 8));
			SYSTEM.PUT(iobase + Laddr1h + index * 8, reg);

			dev.local := mac;
			IF Trace THEN
				KernelLog.String("XEmac MAC address set to: ");
				KernelLog.Hex(ORD(mac[0]), -2); KernelLog.String(".");
				KernelLog.Hex(ORD(mac[1]), -2); KernelLog.String(".");
				KernelLog.Hex(ORD(mac[2]), -2); KernelLog.String(".");
				KernelLog.Hex(ORD(mac[3]), -2); KernelLog.String(".");
				KernelLog.Hex(ORD(mac[4]), -2); KernelLog.String(".");
				KernelLog.Hex(ORD(mac[5]), -2); KernelLog.Ln
			END
		END SetMacAddress;

		PROCEDURE SetTypeIdCheck(index, idCheck: SIGNED32): SIGNED32;
		BEGIN
			ASSERT(state = IsReady);
			ASSERT((index > 0) & (index <= MaxTypeId));
			IF isStarted = IsStarted THEN
				RETURN IsStarted
			END;

			SYSTEM.PUT(iobase + Match1 + index * 4, idCheck);
			RETURN Success
		END SetTypeIdCheck;

		PROCEDURE InitDMA;
		CONST
			MB = 1024*1024;
		VAR
			beginAdr, endAdr, adr: ADDRESS;
			reg: SET;
			i: SIGNED32;
		BEGIN
			IF Trace THEN KernelLog.String("XEmac: Starting DMA"); KernelLog.Ln END;

			(*
			NEW(buffer, (RxBdCount + TxBdCount + 20) * BdSize);
			*)

			(* allocate 2 pages (each page is 1 MBytes) of memory in Heaps for mapping one full page uncached
				without affecting any adjacent data *)
			NEW(buffer,2*MB);
			ASSERT((RxBdCount + TxBdCount + 20) * BdSize <= MB);
			beginAdr := ADDRESSOF(buffer[0]);
			beginAdr := beginAdr + (MB - beginAdr MOD MB);
			ASSERT(beginAdr MOD MB = 0);
			Machine.DisableDCacheRange(beginAdr,MB);

			(* setup DMA RX buffer descriptors *)
			rxBdStartAdr := beginAdr;
			endAdr := beginAdr + (RxBdCount - 1) * BdSize;
			rxBdEndAdr := endAdr;
			i := 0;
			adr := beginAdr;
			WHILE adr < endAdr DO
				SYSTEM.PUT32(adr + BdAdrOffset, ADDRESSOF(rxFrames[i][0]));
				INC(adr, BdSize);
				INC(i)
			END;

			SYSTEM.PUT32(adr + BdAdrOffset, ADDRESSOF(rxFrames[i][0]) + 2);
			lastRxQBar := beginAdr;
			rxBdBase := beginAdr;
			CODE
				DSB
			END;

			(* no need to flush/invalidate cache for BD memory space
			(* Flush DCache *)
			Machine.FlushDCacheRange(beginAdr, RxBdCount * BdSize);
			*)

			IF Trace THEN KernelLog.String("XEmac: RX buffers are set up."); KernelLog.Ln END;

			(* setup DMA TX buffer descriptors *)
			beginAdr := endAdr + BdSize;
			txBdStartAdr := beginAdr;
			endAdr := beginAdr + (TxBdCount - 1) * BdSize;
			txBdEndAdr := endAdr;
			adr := beginAdr;
			WHILE adr < endAdr DO
				SYSTEM.PUT32(adr, 0);
				SYSTEM.PUT32(adr + 4, {TxBufUsed});
				INC(adr, BdSize)
			END;
			SYSTEM.PUT32(adr + 4, {TxBufUsed, TxBufWrap});
			lastTxQBar := beginAdr;
			txBdBase := beginAdr;
			CODE
				DSB
			END;

			(* no need to flush/invalidate cache for BD memory space
			(* Flush DCache *)
			Machine.FlushDCacheRange(txBdBase, TxBdCount * BdSize);
			*)

			IF Trace THEN KernelLog.String("XEmac: TX buffers are set up."); KernelLog.Ln END;

			Objects.InstallHandler(SELF.InterruptHandler, IRQ);
			IF Trace THEN KernelLog.String("DMA Initialized"); KernelLog.Ln END
		END InitDMA;

		(**
			Interrupt handler -- tries to handle the maximum number of IRQs
			at once.
		*)
		PROCEDURE InterruptHandler;
		VAR
			regISR, regSR: SET;
		BEGIN
			ASSERT(state = IsReady);

			(* Get and clear interrupts *)
			SYSTEM.GET(iobase + Isr, regISR);
			SYSTEM.PUT(iobase + Isr, regISR);

			(* Transmit complete interrupt *)
			IF IxrTxCompl IN regISR THEN
				SYSTEM.PUT(iobase + Txsr, {TxsrTxCompl, TxsrUsedRead});
				SendHandler
			END;

			(* Receive complete interrupt *)
			IF IxrFrameRx IN regISR THEN
				SYSTEM.PUT(iobase + Rxsr, {RxsrFrameRx, RxsrBuffna});
				ReceiveHandler
			END;

			(* Receive error conditions interrupt *)
			IF IxrRxErr * regISR # {} THEN
				(* Clear Rx status register *)
				SYSTEM.GET(iobase + Rxsr, regSR);
				SYSTEM.PUT(iobase + Rxsr, regSR);
				IF IxrRxUsed IN regISR THEN
					(* Flush a packet from Rx SRAM *)
					SYSTEM.GET(iobase + Nwctrl, regSR);
					SYSTEM.PUT(iobase + Nwctrl, regSR + {18})
				END;
				ErrorHandler(Recv, regSR)
			END;

			(* Transmit error interrupt
				TxCompl also activates TxUsed when asserted: we have to check for a real error.
			*)
			IF (IxrTxErr * regISR # {}) & (~(IxrTxCompl IN regISR)) THEN
				SYSTEM.GET(iobase + Txsr, regSR);
				SYSTEM.PUT(iobase + Txsr, regSR);
				ErrorHandler(Send, regSR)
			END;
		END InterruptHandler;

		PROCEDURE SendHandler;
		VAR
			reg: SET;
			currBdPtr: ADDRESS;
		BEGIN
			IF Trace THEN KernelLog.String("XEmac.SendHandler"); KernelLog.Ln END;
			SYSTEM.GET(iobase + Txsr, reg);
			SYSTEM.PUT(iobase + Txsr, reg);

			LOOP
				currBdPtr := lastTxQBar;
				IF currBdPtr = SYSTEM.GET32(iobase + Txqbase) THEN EXIT END;
				SYSTEM.PUT32(currBdPtr + BdAdrOffset, 0);
				IF currBdPtr = txBdEndAdr THEN
					SYSTEM.PUT(currBdPtr + BdStatOffset, {TxBufUsed, TxBufWrap});
					lastTxQBar := txBdStartAdr
				ELSE
					SYSTEM.PUT(currBdPtr + BdStatOffset, {TxBufUsed});
					INC(lastTxQBar, BdSize)
				END
			END;
			IF Trace THEN KernelLog.String("XEmac.SendHandler END"); KernelLog.Ln END
		END SendHandler;

		PROCEDURE ReceiveHandler;
		(*VAR
			buf: Network.Buffer;
			type: SIGNED32;*)
		VAR
			reg: SET;
			tmp: SIGNED32;
		BEGIN
			IF Trace THEN KernelLog.String("XEmac.ReceiveHandler"); KernelLog.Ln END;
			SYSTEM.GET(iobase + Rxsr, reg);
			SYSTEM.PUT(iobase + Rxsr, reg);

			SYSTEM.GET(iobase + Rxcnt, tmp);
			IF tmp = 0 THEN
				SYSTEM.GET(iobase + Nwctrl, reg);
				reg := reg * SET(-NwctrlRxEn);
				SYSTEM.PUT(iobase + Nwctrl, reg);
				SYSTEM.GET(iobase + Nwctrl, reg);
				reg := reg  + NwctrlRxEn;
				SYSTEM.PUT(iobase + Nwctrl, reg)
			END
		END ReceiveHandler;

		PROCEDURE ErrorHandler (direction: CHAR; errorWord: SET);
		BEGIN
			IF Trace THEN KernelLog.String("XEmac.ErrorHandler: Error while ") END;
			CASE direction OF
				 Send:
				 	KernelLog.String("sending"); KernelLog.Ln;
				 	IF TxsrHrespnok IN errorWord THEN
				 		KernelLog.String("[XEmac ERROR] Transmit DMA error"); KernelLog.Ln
				 	END;
				 	IF TxsrUrun IN errorWord THEN
				 		KernelLog.String("[XEmac ERROR] Transmit underrun"); KernelLog.Ln
				 	END;
				 	IF TxsrBufExh IN errorWord THEN
				 		KernelLog.String("[XEmac ERROR] Transmit buffer exhausted"); KernelLog.Ln
				 	END;
				 	IF TxsrRxOvr IN errorWord THEN
				 		KernelLog.String("[XEmac ERROR] Transmit retry limit exceeded"); KernelLog.Ln
				 	END;
				 	IF TxsrFrameRx IN errorWord THEN
				 		KernelLog.String("[XEmac ERROR] Transmit collision"); KernelLog.Ln
				 	END;
				 	IF TxsrUsedRead IN errorWord THEN
				 		KernelLog.String("[XEmac ERROR] Transmit buffer not available"); KernelLog.Ln;
				 		KernelLog.String("QBar = "); KernelLog.Address(SYSTEM.GET32(iobase + Txqbase)); KernelLog.Ln
				 	END;
				|Recv:
				 	KernelLog.String("receiving"); KernelLog.Ln;
					IF RxsrHrespnok IN errorWord THEN
						KernelLog.String("[XEmac ERROR] Receive DMA error"); KernelLog.Ln
					END;
					IF RxsrRxOvr IN errorWord THEN
						KernelLog.String("[XEmac ERROR] Receive overrun"); KernelLog.Ln
					END;
					IF RxsrBuffna IN errorWord THEN
						KernelLog.String("[XEmac ERROR] Receive buffer not available"); KernelLog.Ln
					END
			END;
			ResetDevice
		END ErrorHandler;

		PROCEDURE SendTestFrame;
		VAR
			txbd: ADDRESS;
			intsEnabled: BOOLEAN;
		BEGIN
			txFrame[0]:=0FFX;txFrame[1]:=0FFX;txFrame[2]:=0FFX;txFrame[3]:=0FFX;txFrame[4]:=0FFX;txFrame[5]:=0FFX;
			txFrame[6]:=000X;txFrame[7]:=00AX;txFrame[8]:=035X;txFrame[9]:=000X;txFrame[10]:=001X;txFrame[11]:=002X;
			txFrame[12]:=008X;txFrame[13]:=006X;txFrame[14]:=000X;txFrame[15]:=001X;
			txFrame[16]:=008X;txFrame[17]:=000X;txFrame[18]:=006X;txFrame[19]:=004X;txFrame[20]:=000X;txFrame[21]:=001X;txFrame[22]:=000X;txFrame[23]:=00AX;
			txFrame[24]:=035X;txFrame[25]:=000X;txFrame[26]:=001X;txFrame[27]:=002X;txFrame[28]:=0C0X;txFrame[29]:=0A8X;txFrame[30]:=001X;txFrame[31]:=00AX;
			txFrame[32]:=000X;txFrame[33]:=000X;txFrame[34]:=000X;txFrame[35]:=000X;txFrame[36]:=000X;txFrame[37]:=000X;txFrame[38]:=0C0X;txFrame[39]:=0A8X;
			txFrame[40]:=001X;txFrame[41]:=00AX;txFrame[42]:=000X;txFrame[43]:=000X;txFrame[44]:=000X;txFrame[45]:=000X;txFrame[46]:=000X;txFrame[47]:=000X;
			txFrame[48]:=001X;txFrame[49]:=00AX;txFrame[50]:=000X;txFrame[51]:=000X;txFrame[52]:=000X;txFrame[53]:=000X;txFrame[54]:=000X;txFrame[55]:=000X;
			txFrame[56]:=001X;txFrame[57]:=00AX;txFrame[58]:=000X;txFrame[59]:=000X;

			KernelLog.String("Sending Test Frame"); KernelLog.Ln;
			KernelLog.Address(ADDRESSOF(txFrame)); KernelLog.Ln;
			KernelLog.Buffer(txFrame, 0, 60);
			(* Send it with DMA *)
			intsEnabled := Machine.AreInterruptsEnabled();
			Machine.DisableInterrupts;

			SYSTEM.GET(iobase + Txqbase, txbd);
			KernelLog.String("SendTestFrame: txbd = "); KernelLog.Address(txbd); KernelLog.Ln;
			IF txbd = 0 THEN txbd := txBdStartAdr END;
			KernelLog.String("SendTestFrame: txbd = "); KernelLog.Address(txbd); KernelLog.Ln;

			Machine.FlushDCacheRange(ADDRESSOF(txFrame), 60);

			SYSTEM.PUT(txbd + BdAdrOffset, ADDRESSOF(txFrame));
			IF txbd # txBdEndAdr THEN
				SYSTEM.PUT(txbd + BdStatOffset, {TxBufLast} + SYSTEM.VAL(SET, 60));
			ELSE
				SYSTEM.PUT(txbd + BdStatOffset, {TxBufLast, TxBufWrap} + SYSTEM.VAL(SET, 60));
			END;

			(* no need to flush/invalidate cache for BD memory space
			Machine.FlushDCacheRange(txbd, BdSize);
			*)

			CODE
				DSB
			END;

			(* Transmit *)
			Transmit;

			IF intsEnabled THEN Machine.EnableInterrupts END;
			IF Trace THEN KernelLog.String("Frame sent"); KernelLog.Ln END
		END SendTestFrame;

		PROCEDURE DumpDBMem(start: ADDRESS; count: SIGNED32);
		VAR
			i: SIGNED32;
		BEGIN
			FOR i := 0 TO count DO
				KernelLog.Address(start); KernelLog.String(":	");
				KernelLog.Address(SYSTEM.GET32(start)); KernelLog.String(" - ");
				INC(start, 4);
				KernelLog.Address(SYSTEM.GET32(start)); KernelLog.Ln;
				INC(start, 4)
			END;
		END DumpDBMem;

		PROCEDURE Finalize;
		BEGIN
			Stop;
			Objects.RemoveHandler(SELF.InterruptHandler, IRQ);
			Network.registry.Remove(dev);
			dev.ctrl := NIL;
			dev := NIL;
		END Finalize;

	BEGIN {ACTIVE}
		(* Receive is done by polling *)
		(*BEGIN {EXCLUSIVE}
			AWAIT(start)
		END;*)
		WHILE dev # NIL DO
			(*BEGIN {EXCLUSIVE}
				IF kill THEN EXIT END
			END;*)
			IF lastRxQBar # SYSTEM.GET32(iobase + Rxqbase) THEN
				ReceiveFrame
			END
		END
	END Controller;

	(** Phy subsystem of the controller. *)
	Phy = OBJECT
	VAR
		iobase, phybase: ADDRESS;
		linkSpeed: SIGNED32;
		timer: Kernel.Timer;

		PROCEDURE & Setup * (iobase: ADDRESS);
		BEGIN
			SELF.iobase := iobase;
			NEW(timer);
			IF LinkSpeedMode = LinkSpeedAutodetect THEN
				linkSpeed := GetIEEEPhySpeed();
				IF linkSpeed = 1000 THEN
					IF Trace THEN KernelLog.String("Autonegociated speed: 1000 MB/s"); KernelLog.Ln END;
					SetUpSLCRDivisors(1000)
				ELSIF linkSpeed = 100 THEN
					IF Trace THEN KernelLog.String("Autonegociated speed: 100 MB/s"); KernelLog.Ln END;
					SetUpSLCRDivisors(100)
				ELSIF linkSpeed = 10 THEN
					IF Trace THEN KernelLog.String("Autonegociated speed: 10 MB/s"); KernelLog.Ln END;
					SetUpSLCRDivisors(10)
				ELSE
					IF Trace THEN KernelLog.String("Defaulting autonegociated speed to 10 MB/s"); KernelLog.Ln END;
					SetUpSLCRDivisors(10)
				END;
				RETURN
			ELSIF LinkSpeedMode = LinkSpeed1000 THEN
				linkSpeed := 1000;
			ELSIF LinkSpeedMode = LinkSpeed100 THEN
				linkSpeed := 100;
			ELSE
				linkSpeed := 10;
			END;
			SetUpSLCRDivisors(linkSpeed);
			ConfigureIEEEPhySpeed(linkSpeed);
			timer.Sleep(1000)
		END Setup;

		PROCEDURE Detect (): ADDRESS;
		VAR
			status, phyReg: SIGNED32;
			phyAdr: ADDRESS;
		BEGIN
			IF Trace THEN KernelLog.String("XEmac: Detecting PHY"); KernelLog.Ln END;
			phyAdr := 31;
			WHILE phyAdr > 0 DO
				status := Read(phyAdr, PhyDetectReg, phyReg);
				IF (phyReg # 0FFFFH) & (SYSTEM.VAL(SET, phyReg) * PhyDetect = PhyDetect) THEN
					IF Trace THEN KernelLog.String("Found PHY at "); KernelLog.Address(phyAdr); KernelLog.Ln END;
					RETURN phyAdr
				END;
				DEC(phyAdr)
			END;
			IF Trace THEN KernelLog.String("PHY not found. Assuming its address is 0"); KernelLog.Ln END;
			RETURN 0
		END Detect;

		PROCEDURE GetIEEEPhySpeed (): SIGNED32;
		VAR
			temp, control, res, status, capabilities: SIGNED32;
			phyAdr: ADDRESS;
		BEGIN
			phyAdr := Detect();
			IF Trace THEN KernelLog.String("Start PHY autonegociation"); KernelLog.Ln END;
			res := Write(phyAdr, IeeePageAddressRegister, 2);
			res := Read(phyAdr, IeeeControlRegMac, control);
			control := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, control) + IeeeRgmiiTxRxClockDelayed);
			res := Write(phyAdr, IeeeControlRegMac, control);

			res := Write(phyAdr, IeeePageAddressRegister, 0);

			res := Read(phyAdr, IeeeAutonegoAdvertiseReg, control);
			control := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, control) + IeeeAsymmetricPause + IeeePause + Advertise100 + Advertise10);
			res := Write(phyAdr, IeeeAutonegoAdvertiseReg, control);

			res := Read(phyAdr, Ieee1000AdvertiseReg, control);
			control := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, control) + Advertise1000);
			res := Write(phyAdr, Ieee1000AdvertiseReg, control);

			res := Write(phyAdr, IeeePageAddressRegister, 0);
			res := Read(phyAdr, IeeeCopperSpecificControlReg, control);
			control := control + LSH(7, 12); (* Max number of gigabit attemps *)
			INCL(SYSTEM.VAL(SET, control), 11); (* Enable dowshift *)
			res := Write(phyAdr, IeeeCopperSpecificControlReg, control);

			res := Read(phyAdr, IeeeControlReg, control);
			control := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, control) + IeeeCtrlAutonegotiateEnable);
			control := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, control) + IeeeStatAutonegotiateRestart);
			res := Write(phyAdr, IeeeControlReg, control);

			res := Read(phyAdr, IeeeControlReg, control);
			control := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, control) + IeeeCtrlReset);
			res := Write(phyAdr, IeeeControlReg, control);

			REPEAT
				IF Trace THEN KernelLog.String("Waiting for PHY reset"); KernelLog.Ln END;
				res := Read(phyAdr, IeeeControlReg, control)
			UNTIL SYSTEM.VAL(SET, control) * IeeeCtrlReset = {};

			IF Trace THEN KernelLog.String("Waiting for PHY to complete autonegotiation"); KernelLog.Ln END;

			res := Read(phyAdr, IeeeStatusReg, status);
			WHILE SYSTEM.VAL(SET, status) * IeeeStatAutonegotiateComplete = {} DO
				timer.Sleep(1000);
				res := Read(phyAdr, IeeeCopperSpecificStatusReg2, temp);
				IF Trace & (SYSTEM.VAL(SET, temp) * IeeeAutonegError # {}) THEN
					KernelLog.String("Autonegotiation error");
					KernelLog.Ln
				END;
				res := Read(phyAdr, IeeeStatusReg, status)
			END;
			IF Trace THEN KernelLog.String("Autonegotiation complete"); KernelLog.Ln END;

			res := Read(phyAdr, IeeeSpecificStatusReg, capabilities);
			IF 15 IN SYSTEM.VAL(SET, capabilities) THEN
				RETURN 1000 (* MB/s *)
			ELSIF 14 IN SYSTEM.VAL(SET, capabilities) THEN
				RETURN 100 (* MB/s *)
			ELSE
				RETURN 10 (* MB/s *)
			END
		END GetIEEEPhySpeed;

		PROCEDURE ConfigureIEEEPhySpeed (speed: SIGNED32);
		VAR
			control, res, wait: SIGNED32;
			phyAdr: ADDRESS;
		BEGIN
			phyAdr := Detect();
			res := Write(phyAdr, IeeePageAddressRegister, 2);
			res := Read(phyAdr, IeeeControlRegMac, control);
			control := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, control) + IeeeRgmiiTxRxClockDelayed);
			res := Write(phyAdr, IeeeControlRegMac, control);

			res := Write(phyAdr, IeeePageAddressRegister, 0);

			res := Read(phyAdr, IeeeAutonegoAdvertiseReg, control);
			control := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, control) + IeeeAsymmetricPause);
			control := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, control) + IeeePause);
			res := Write(phyAdr, IeeeAutonegoAdvertiseReg, control);

			res := Read(phyAdr, IeeeControlReg, control);
			control := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, control) * (-IeeeCtrlLinkSpeed1000M) * (-IeeeCtrlLinkSpeed100M) * (-IeeeCtrlLinkSpeed10M));

			IF linkSpeed = 1000 THEN
				control := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, control) + IeeeCtrlLinkSpeed1000M)
			ELSIF linkSpeed = 100 THEN
				control := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, control) + IeeeCtrlLinkSpeed100M)
				(* Don't advertise PHY speed of 1000 MBPS *)
			ELSIF linkSpeed = 10 THEN
				control := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, control) + IeeeCtrlLinkSpeed10M)
			END;
		END ConfigureIEEEPhySpeed;

		PROCEDURE SetUpSLCRDivisors (div: SIGNED32);
		END SetUpSLCRDivisors;

		PROCEDURE Write (address, register: ADDRESS; data: SIGNED32): SIGNED32;
		VAR
			reg, mgtcr, ipisr: SET;
		BEGIN
			IF Trace THEN KernelLog.String("PHY write"); KernelLog.Ln END;
			SYSTEM.GET(iobase + Nwsr, reg);
			(* Make sure no other PHY operation is currently in progress *)
			IF ~(NwsrMdioIdle IN reg) THEN
				IF Trace THEN KernelLog.String("XEmac Phy write aborted: PHY busy"); KernelLog.Ln END;
				RETURN EmacMiiBusy
			END;

			(* Construct Mgtcr mask for the operation *)
			mgtcr := PhyMntncOp + PhyMntncOpW + SYSTEM.VAL(SET, LSH(phybase, PhyMntncPhyAdShift))
					+ SYSTEM.VAL(SET, LSH(address, PhyMntncPhyAdShift))
					+ SYSTEM.VAL(SET, LSH(register, PhyMntncPhRegShift)) + SYSTEM.VAL(SET,data);
			SYSTEM.PUT(iobase + PhyMntnc, mgtcr);

			REPEAT
				SYSTEM.GET(iobase + Nwsr, ipisr)
			UNTIL NwsrMdioIdle IN ipisr;
			RETURN Success
		END Write;

		PROCEDURE Read (address, register: ADDRESS; VAR data: SIGNED32): SIGNED32;
		VAR
			reg, ipisr, mgtcr: SET;
		BEGIN
			SYSTEM.GET(iobase + Nwsr, reg);
			IF ~(NwsrMdioIdle IN reg) THEN
				IF Trace THEN KernelLog.String("XEmac Phy read aborted: PHY busy"); KernelLog.Ln END;
				RETURN EmacMiiBusy
			END;

			mgtcr := PhyMntncOp + PhyMntncOpR
					+ SYSTEM.VAL(SET, LSH(address, PhyMntncPhyAdShift))
					+ SYSTEM.VAL(SET, LSH(register, PhyMntncPhRegShift));
			SYSTEM.PUT(iobase + PhyMntnc, mgtcr);

			REPEAT
				SYSTEM.GET(iobase + Nwsr, ipisr)
			UNTIL NwsrMdioIdle IN ipisr;
			data := SYSTEM.GET32(iobase + PhyMntnc) MOD 10000H;
			RETURN Success
		END Read;
	END Phy;

PROCEDURE Install* (context: Commands.Context);
VAR ld: LinkDevice; res: INTEGER;
BEGIN {EXCLUSIVE}
	NEW(ld, Network.TypeEthernet, 1500, 6); (*! What is the correct MTU? *)
	ld.SetName("XEmac");
	Network.registry.Add(ld, res);
	IF res # 0 THEN
		context.error.String("failed to install"); context.error.Ln;
		context.result := Commands.CommandError; RETURN;
	END;
	NEW(ld.ctrl, ADDRESS(0E000B000H), ld);
END Install;

PROCEDURE Remove*;
VAR table: Plugins.Table; i: SIZE;
BEGIN {EXCLUSIVE}
	Network.registry.GetAll(table);
	IF table # NIL THEN
		FOR i := 0 TO LEN(table)-1 DO
			IF table[i] IS LinkDevice THEN table[i](LinkDevice).Finalize(TRUE) END
		END
	END;
END Remove;

BEGIN
	Modules.InstallTermHandler(Remove);
END XEmac.
