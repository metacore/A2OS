MODULE EnetEmacPs7;
(**
	AUTHOR: Alexey Morozov, HighDim GmbH, 2015
	PURPOSE: Ethernet networking stack, interface for Xilinx Processing System 7 Ethernet MAC device
*)

IMPORT
	S := SYSTEM, Platform, EnetEnvironment, EnetTiming, EnetBase, EnetPhy, Trace := EnetTrace;

CONST
	GemBaseAddr0 = ADDRESS(0xE000B000);
	GemBaseAddr1 = ADDRESS(0xE000C000); (* Base addresses for GEM controllers *)

	EnableTrace = TRUE;

	LinkAutonegoTimeout* = 5000; (** link autonegotiation timeout in milliseconds *)

TYPE
	Int8 = EnetBase.Int8;
	Int16 = EnetBase.Int16;

	Int = EnetBase.Int;
	UInt = EnetBase.UInt;
	ResultCode = EnetBase.ResultCode;

CONST

	(**
		Supported MDIO divisor values
	*)
	MDC_DIV_8 = 0;
	MDC_DIV_16 = 1;
	MDC_DIV_32 = 2;
	MDC_DIV_48 = 3;
	MDC_DIV_64 = 4;
	MDC_DIV_96 = 5;
	MDC_DIV_128 = 6;
	MDC_DIV_224 = 7;

	MdioDivisor0* = MDC_DIV_224;
	MdioDivisor1* = MDC_DIV_224; (** MDIO divisor values for both GEM controllers (PHY hardware-specific) *)

	AllowZeroPhyAddr0* = FALSE;
	AllowZeroPhyAddr1* = FALSE; (** TRUE if PHY address 0 is allowed (can be only in the case of a single PHY) for both GEM controllers (PHY hardware-specific) *)

	(*
		Internally used constants
	*)
	DataCacheLineSize = 32; (* data cache line size in bytes *)
	RX_BUF_SIZE = 1536; (** Specify the receive buffer size in bytes, 64, 128, ... 10240 *)
	RX_BUF_UNIT = 64; (** Number of receive buffer bytes as a unit, this is HW setup *)

	(**
		network control register bit definitions
	*)
	NWCTRL_FLUSH_DPRAM_MASK = 0x00040000; (** Flush a packet from Rx SRAM *)
	NWCTRL_ZEROPAUSETX_MASK = 0x00000800; (** Transmit zero quantum pause frame *)
	NWCTRL_PAUSETX_MASK = 0x00000800; (** Transmit pause frame *)
	NWCTRL_HALTTX_MASK = 0x00000400; (** Halt transmission after current frame *)
	NWCTRL_STARTTX_MASK = 0x00000200; (** Start tx (tx_go) *)
	NWCTRL_STATWEN_MASK = 0x00000080; (** Enable writing to stat counters *)
	NWCTRL_STATINC_MASK = 0x00000040; (** Increment statistic registers *)
	NWCTRL_STATCLR_MASK = 0x00000020; (** Clear statistic registers *)
	NWCTRL_MDEN_MASK = 0x00000010; (** Enable MDIO port *)
	NWCTRL_TXEN_MASK = 0x00000008; (** Enable transmit *)
	NWCTRL_RXEN_MASK = 0x00000004; (** Enable receive *)
	NWCTRL_RXTXDIS_MASK = 0xFFFFFFF3; (** Disable both transmit and receiver *)
	NWCTRL_LOOPEN_MASK = 0x00000002; (** local loopback *)
	NWCTRL_DEFAULT_VALUE = 0x00000030; (** value of the register to be set at reset (NWCTRL_STATCLR_MASK | NWCTRL_MDEN_MASK) & ~NWCTRL_LOOPEN_MASK *)

	(**
		network configuration register bit definitions
	*)
	NWCFG_BADPREAMBEN_MASK = 0x20000000; (** disable rejection of non-standard preamble *)
	NWCFG_IPDSTRETCH_MASK = 0x10000000; (** enable transmit IPG *)
	NWCFG_FCSIGNORE_MASK = 0x04000000; (** disable rejection of FCS error *)
	NWCFG_HDRXEN_MASK = 0x02000000; (** RX half duplex *)
	NWCFG_RXCHKSUMEN_MASK = 0x01000000; (** enable RX checksum offload *)
	NWCFG_PAUSECOPYDI_MASK = 0x00800000; (** Do not copy pause Frames to memory *)
	NWCFG_MDC_SHIFT_MASK = 18; (** shift bits for MDC *)
	NWCFG_MDCCLKDIV_MASK = 0x001C0000; (** MDC Mask PCLK divisor *)
	NWCFG_INV_MDCCLKDIV_MASK = 0xFFE3FFFF; (** Inverted mask for MDC Mask PCLK divisor *)
	NWCFG_FCSREM_MASK = 0x00020000; (** Discard FCS from received frames *)
	NWCFG_LENGTHERRDSCRD_MASK = 0x00010000; (** RX length error discard *)
	NWCFG_RXOFFS_MASK = 0x0000C000; (** RX buffer offset *)
	NWCFG_PAUSEEN_MASK = 0x00002000; (** Enable pause RX *)
	NWCFG_RETRYTESTEN_MASK = 0x00001000; (** Retry test *)
	NWCFG_EXTADDRMATCHEN_MASK = 0x00000200; (** External address match enable *)
	NWCFG_1000_MASK = 0x00000400; (** 1000 Mbps *)
	NWCFG_1536RXEN_MASK = 0x00000100; (** Enable 1536 byte frames reception *)
	NWCFG_UCASTHASHEN_MASK = 0x00000080; (** Receive unicast hash frames *)
	NWCFG_MCASTHASHEN_MASK = 0x00000040; (** Receive multicast hash frames *)
	NWCFG_BCASTDI_MASK = 0x00000020; (** Do not receive broadcast frames *)
	NWCFG_COPYALLEN_MASK = 0x00000010; (** Copy all frames *)
	NWCFG_JUMBO_MASK = 0x00000008; (** Jumbo frames *)
	NWCFG_NVLANDISC_MASK = 0x00000004; (** Receive only VLAN frames *)
	NWCFG_FDEN_MASK = 0x00000002; (** full duplex *)
	NWCFG_100_MASK = 0x00000001; (** 100 Mbps *)
	NWCFG_RESET_MASK = 0x00080000; (** reset value *)

	(**
		network status register bit definitaions
	*)
	NWSR_MDIOIDLE_MASK = 0x00000004; (** PHY management idle *)
	NWSR_MDIO_MASK = 0x00000002; (** Status of mdio_in *)

	(**
		DMA control register bit definitions
	*)
	DMACR_RXBUF_MASK = 0x00FF0000; (** Mask bit for RX buffer size *)
	DMACR_RXBUF_SHIFT = 16; (** Shift bit for RX buffer size *)
	DMACR_TCPCKSUM_MASK = 0x00000800; (** enable/disable TX checksum offload *)
	DMACR_TXSIZE_MASK = 0x00000400; (** TX buffer memory size *)
	DMACR_RXSIZE_MASK = 0x00000300; (** RX buffer memory size *)
	DMACR_ENDIAN_MASK = 0x00000080; (** endian configuration *)
	DMACR_BLENGTH_MASK = 0x0000001F; (** buffer burst length *)
	DMACR_SINGLE_AHB_BURST = 0x00000001; (** single AHB bursts *)
	DMACR_INCR4_AHB_BURST = 0x00000004; (** 4 bytes AHB bursts *)
	DMACR_INCR8_AHB_BURST = 0x00000008; (** 8 bytes AHB bursts *)
	DMACR_INCR16_AHB_BURST = 0x00000010; (** 16 bytes AHB bursts *)

	(**
		transmit status register bit definitions
	*)
	TXSR_HRESPNOK_MASK = 0x00000100; (** Transmit hresp not OK *)
	TXSR_URUN_MASK = 0x00000040; (** Transmit underrun *)
	TXSR_TXCOMPL_MASK = 0x00000020; (** Transmit completed OK *)
	TXSR_BUFEXH_MASK = 0x00000010; (** Transmit buffs exhausted mid frame *)
	TXSR_TXGO_MASK = 0x00000008; (** Status of go flag *)
	TXSR_RXOVR_MASK = 0x00000004; (** Retry limit exceeded *)
	TXSR_FRAMERX_MASK = 0x00000002; (** Collision tx frame *)
	TXSR_USEDREAD_MASK = 0x00000001; (** TX buffer used bit set *)

	TXSR_ERROR_MASK = TXSR_HRESPNOK_MASK + TXSR_URUN_MASK + TXSR_BUFEXH_MASK + TXSR_RXOVR_MASK + TXSR_FRAMERX_MASK + TXSR_USEDREAD_MASK;


	(**
		receive status register bit definitions
	*)
	RXSR_HRESPNOK_MASK = 0x00000008; (** Receive hresp not OK *)
	RXSR_RXOVR_MASK = 0x00000004; (** Receive overrun *)
	RXSR_FRAMERX_MASK = 0x00000002; (** Frame received OK *)
	RXSR_BUFFNA_MASK = 0x00000001; (** RX buffer used bit set *)

	RXSR_ERROR_MASK = RXSR_HRESPNOK_MASK + RXSR_RXOVR_MASK + RXSR_BUFFNA_MASK;

	(**
		interrupts bit definitions Bits definitions are same in ISR_OFFSET, IER_OFFSET, IDR_OFFSET, and IMR_OFFSET
	*)
	IXR_PTPPSTX_MASK = 0x02000000; (** PTP Psync transmitted *)
	IXR_PTPPDRTX_MASK = 0x01000000; (** PTP Pdelay_req transmitted *)
	IXR_PTPSTX_MASK = 0x00800000; (** PTP Sync transmitted *)
	IXR_PTPDRTX_MASK = 0x00400000; (** PTP Delay_req transmitted *)
	IXR_PTPPSRX_MASK = 0x00200000; (** PTP Psync received *)
	IXR_PTPPDRRX_MASK = 0x00100000; (** PTP Pdelay_req received *)
	IXR_PTPSRX_MASK = 0x00080000; (** PTP Sync received *)
	IXR_PTPDRRX_MASK = 0x00040000; (** PTP Delay_req received *)
	IXR_PAUSETX_MASK = 0x00004000; (** Pause frame transmitted *)
	IXR_PAUSEZERO_MASK = 0x00002000; (** Pause time has reached zero *)
	IXR_PAUSENZERO_MASK = 0x00001000; (** Pause frame received *)
	IXR_HRESPNOK_MASK = 0x00000800; (** hresp not ok *)
	IXR_RXOVR_MASK = 0x00000400; (** Receive overrun occurred *)
	IXR_TXCOMPL_MASK = 0x00000080; (** Frame transmitted ok *)
	IXR_TXEXH_MASK = 0x00000040; (** Transmit err occurred or no buffers*)
	IXR_RETRY_MASK = 0x00000020; (** Retry limit exceeded *)
	IXR_URUN_MASK = 0x00000010; (** Transmit underrun *)
	IXR_TXUSED_MASK = 0x00000008; (** Tx buffer used bit read *)
	IXR_RXUSED_MASK = 0x00000004; (** Rx buffer used bit read *)
	IXR_FRAMERX_MASK = 0x00000002; (** Frame received ok *)
	IXR_MGMNT_MASK = 0x00000001; (** PHY management complete *)
	IXR_ALL_MASK = 0x00007FFF; (** Everything! *)

	IXR_TX_ERR_MASK = IXR_TXEXH_MASK + IXR_RETRY_MASK + IXR_URUN_MASK (*+ IXR_TXUSED_MASK*);
	IXR_RX_ERR_MASK = IXR_HRESPNOK_MASK + IXR_RXUSED_MASK + IXR_RXOVR_MASK;

	(**
		PHY Maintenance bit definitions
	*)
	PHYMNTNC_OP_MASK = 0x40020000; (** operation mask bits *)
	PHYMNTNC_OP_R_MASK = 0x20000000; (** read operation *)
	PHYMNTNC_OP_W_MASK = 0x10000000; (** write operation *)
	PHYMNTNC_ADDR_MASK = 0x0F800000; (** Address bits *)
	PHYMNTNC_REG_MASK = 0x007C0000; (** register bits *)
	PHYMNTNC_DATA_MASK = 0x00000FFF; (** data bits *)
	PHYMNTNC_PHYAD_SHIFT_MASK = 23; (** Shift bits for PHYAD *)
	PHYMNTNC_PHREG_SHIFT_MASK = 18; (** Shift bits for PHREG *)

	(**
		Transmit buffer descriptor status words offset
	*)
	BD_ADDR_OFFSET = 0x00000000; (** word 0/addr of BDs *)
	BD_STAT_OFFSET = 0x00000004; (** word 1/status of BDs *)

	(**
		Transmit buffer descriptor status words bit positions.

		Transmit buffer descriptor consists of two 32-bit registers,
		the first - word0 contains a 32-bit address pointing to the location of
		the transmit data.

		The following register - word1, consists of various information to control
		the XEmacPs transmit process.  After transmit, this is updated with status
		information, whether the frame was transmitted OK or why it had failed.
	*)
	TXBUF_USED_MASK = 0x80000000; (** Used bit. *)
	TXBUF_WRAP_MASK = 0x40000000; (** Wrap bit, last descriptor *)
	TXBUF_RETRY_MASK = 0x20000000; (** Retry limit exceeded *)
	TXBUF_URUN_MASK = 0x10000000; (** Transmit underrun occurred *)
	TXBUF_EXH_MASK = 0x08000000; (** Buffers exhausted *)
	TXBUF_TCP_MASK = 0x04000000; (** Late collision. *)
	TXBUF_NOCRC_MASK = 0x00010000; (** No CRC *)
	TXBUF_LAST_MASK = 0x00008000; (** Last buffer *)
	TXBUF_LEN_MASK = 0x00003FFF; (** Mask for length field *)

	(**
		Receive buffer descriptor status words bit positions.

		Receive buffer descriptor consists of two 32-bit registers,
		the first - word0 contains a 32-bit word aligned address pointing to the
		address of the buffer. The lower two bits make up the wrap bit indicating
		the last descriptor and the ownership bit to indicate it has been used by
		the XEmacPs.

		The following register - word1, contains status information regarding why
		the frame was received (the filter match condition) as well as other
		useful info.
	*)
	RXBUF_BCAST_MASK = 0x80000000; (** Broadcast frame *)
	RXBUF_MULTIHASH_MASK = 0x40000000; (** Multicast hashed frame *)
	RXBUF_UNIHASH_MASK = 0x20000000; (** Unicast hashed frame *)
	RXBUF_EXH_MASK = 0x08000000; (** buffer exhausted *)
	RXBUF_AMATCH_MASK = 0x06000000; (** Specific address matched *)
	RXBUF_IDFOUND_MASK = 0x01000000; (** Type ID matched *)
	RXBUF_IDMATCH_MASK = 0x00C00000; (** ID matched mask *)
	RXBUF_VLAN_MASK = 0x00200000; (** VLAN tagged *)
	RXBUF_PRI_MASK = 0x00100000; (** Priority tagged *)
	RXBUF_VPRI_MASK = 0x000E0000; (** Vlan priority *)
	RXBUF_CFI_MASK = 0x00010000; (** CFI frame *)
	RXBUF_EOF_MASK = 0x00008000; (** End of frame. *)
	RXBUF_SOF_MASK = 0x00004000; (** Start of frame. *)
	RXBUF_LEN_MASK = 0x00001FFF; (** Mask for length field *)
	RXBUF_WRAP_MASK = 0x00000002; (** Wrap bit, last BD *)
	RXBUF_NEW_MASK = 0x00000001; (** Used bit.. *)
	RXBUF_ADD_MASK = 0xFFFFFFFC; (** Mask for address *)


	(**
		Link device configuration options
	*)

	Promisc* = 0; (** Accept all incoming packets. This option defaults to disabled (cleared)  *)
	Frame1536* = 1; (** Frame larger than 1516 support for Tx & Rx. This option defaults to disabled (cleared) *)
	Vlan* = 2; (** VLAN Rx & Tx frame support. This option defaults to disabled (cleared) *)
	FlowControl* = 4; (** Enable recognition of flow control frames on Rx. This option defaults to enabled (set) *)
	FcsStrip* = 5; (** Strip FCS and PAD from incoming frames. Note: PAD from VLAN frames is not stripped. This option defaults to enabled (set) *)
	FcsInsert* = 6; (** Generate FCS field and add PAD automatically for outgoing frames. This option defaults to disabled (cleared) *)
	LenTypeErr* = 7; (** Enable Length/TYPE error checking for incoming frames. When this option is set, the MAC will filter frames that have a mismatched TYPE/length field
							and if REPORT_RXERR is set, the user is notified when these TYPEs of frames are encountered. When this option is cleared, the MAC will
							allow these TYPEs of frames to be received. This option defaults to disabled (cleared)
						*)
	TransmitterEnable* = 8; (** Enable the transmitter. This option defaults to enabled (set) *)
	ReceiverEnable* = 9; (** Enable the receiver. This option defaults to enabled (set) *)
	Broadcast* = 10; (** Allow reception of the broadcast address. This option defaults to enabled (set) *)
	Multicast* = 11; (** Allows reception of multicast addresses programmed into hash. This option defaults to disabled (clear) *)
	RxChksumEnable* = 12; (** Enable the RX checksum offload. This option defaults to enabled (set) *)
	TxChksumEnable* = 13; (** Enable the TX checksum offload. This option defaults to enabled (set) *)

	DefaultOptions* = {Promisc, FlowControl, FcsInsert, FcsStrip, Broadcast, LenTypeErr, RxChksumEnable, TxChksumEnable, TransmitterEnable, ReceiverEnable};

	GemIrq0 = 54;
	GemIrq1 = 77; (* Interrupt number for GEM0 and GEM1 respectively *)

TYPE

	(** Gigabit Ethernet Controller (GEM) registers definition *)
	GemRegisters* = POINTER{UNSAFE,UNTRACED} TO RECORD
		net_ctrl*: UInt; (** 0x00000000 32 mixed 0x00000000 Network Control *)
		net_cfg*: UInt; (** 0x00000004 32 rw 0x00080000 Network Configuration *)
		net_status*: UInt; (** 0x00000008 32 ro x Network Status *)
		padding0: UInt;
		dma_cfg*: UInt; (** 0x00000010 32 mixed 0x00020784 DMA Configuration *)
		tx_status*: UInt; (** 0x00000014 32 mixed 0x00000000 Transmit Status *)
		rx_qbar*: UInt; (** 0x00000018 32 mixed 0x00000000 Receive Buffer Queue Base Address *)
		tx_qbar*: UInt; (** 0x0000001C 32 mixed 0x00000000 Transmit Buffer Queue Base Address *)
		rx_status*: UInt; (** 0x00000020 32 mixed 0x00000000 Receive Status *)
		intr_status*: UInt; (** 0x00000024 32 mixed 0x00000000 Interrupt Status *)
		intr_en*: UInt; (** 0x00000028 32 wo x Interrupt Enable *)
		intr_dis*: UInt; (** 0x0000002C 32 wo x Interrupt Disable *)
		intr_mask*: UInt; (** 0x00000030 32 mixed x Interrupt Mask Status *)
		phy_maint*: UInt; (** 0x00000034 32 rw 0x00000000 PHY Maintenance *)
		rx_pauseq*: UInt; (** 0x00000038 32 ro 0x00000000 Received Pause Quantum *)
		tx_pauseq*: UInt; (** 0x0000003C 32 rw 0x0000FFFF Transmit Pause Quantum *)
		padding1: ARRAY 16 OF UInt;
		hash_bot*: UInt; (** 0x00000080 32 rw 0x00000000 Hash Register Bottom [31:0] *)
		hash_top*: UInt; (** 0x00000084 32 rw 0x00000000 Hash Register Top [63:32] *)
		spec_addr1_bot*: UInt; (** 0x00000088 32 rw 0x00000000 Specific Address 1 Bottom [31:0] *)
		spec_addr1_top*: UInt; (** 0x0000008C 32 mixed 0x00000000 Specific Address 1 Top [47:32] *)
		spec_addr2_bot*: UInt; (** 0x00000090 32 rw 0x00000000 Specific Address 2 Bottom [31:0] *)
		spec_addr2_top*: UInt; (** 0x00000094 32 mixed 0x00000000 Specific Address 2 Top [47:32] *)
		spec_addr3_bot*: UInt; (** 0x00000098 32 rw 0x00000000 Specific Address 3 Bottom [31:0] *)
		spec_addr3_top*: UInt; (** 0x0000009C 32 mixed 0x00000000 Specific Address 3 Top [47:32] *)
		spec_addr4_bot*: UInt; (** 0x000000A0 32 rw 0x00000000 Specific Address 4 Bottom [31:0] *)
		spec_addr4_top*: UInt; (** 0x000000A4 32 mixed 0x00000000 Specific Address 4 Top [47:32] *)
		type_id_match1*: UInt; (** 0x000000A8 32 mixed 0x00000000 Type ID Match 1 *)
		type_id_match2*: UInt; (** 0x000000AC 32 mixed 0x00000000 Type ID Match 2 *)
		type_id_match3*: UInt; (** 0x000000B0 32 mixed 0x00000000 Type ID Match 3 *)
		type_id_match4*: UInt; (** 0x000000B4 32 mixed 0x00000000 Type ID Match 4 *)
		wake_on_lan*: UInt; (** 0x000000B8 32 mixed 0x00000000 Wake on LAN Register *)
		ipg_stretch*: UInt; (** 0x000000BC 32 mixed 0x00000000 IPG stretch register *)
		stacked_vlan*: UInt; (** 0x000000C0 32 mixed 0x00000000 Stacked VLAN Register *)
		tx_pfc_pause*: UInt; (** 0x000000C4 32 mixed 0x00000000 Transmit PFC Pause Register *)
		spec_addr1_mask_bot*: UInt; (** 0x000000C8 32 rw 0x00000000 Specific Address Mask 1 Bottom [31:0] *)
		spec_addr1_mask_top*: UInt; (** 0x000000CC 32 mixed 0x00000000 Specific Address Mask 1 Top [47:32] *)
		padding2: ARRAY 11 OF UInt;
		module_id*: UInt; (** 0x000000FC 32 ro 0x00020118 Module ID *)
		octets_tx_bot*: UInt; (** 0x00000100 32 ro 0x00000000 Octets transmitted [31:0] (in frames without error) *)
		octets_tx_top*: UInt; (** 0x00000104 32 ro 0x00000000 Octets transmitted [47:32] (in frames without error) *)
		frames_tx*: UInt; (** 0x00000108 32 ro 0x00000000 Frames Transmitted *)
		broadcast_frames_tx*: UInt; (** 0x0000010C 32 ro 0x00000000 Broadcast frames Tx *)
		multi_frames_tx*: UInt; (* 0x00000110 32 ro 0x00000000 Multicast frames Tx *)
		pause_frames_tx*: UInt; (** 0x00000114 32 ro 0x00000000 Pause frames Tx *)
		frames_64b_tx*: UInt; (** 0x00000118 32 ro 0x00000000 Frames Tx, 64-byte length *)
		frames_65to127b_tx*: UInt; (** 0x0000011C 32 ro 0x00000000 Frames Tx, 65 to 127-byte length *)
		frames_128to255b_tx*: UInt; (** 0x00000120 32 ro 0x00000000 Frames Tx, 128 to 255-byte length *)
		frames_256to511b_tx*: UInt; (** 0x00000124 32 ro 0x00000000 Frames Tx, 256 to 511-byte length *)
		frames_512to1023b_tx*: UInt; (** 0x00000128 32 ro 0x00000000 Frames Tx, 512 to 1023-byte length *)
		frames_1024to1518b_tx*: UInt; (** 0x0000012C 32 ro 0x00000000 Frame Tx, 1024 to 1518-byte length *)
		padding3: UInt;
		tx_under_runs*: UInt; (** 0x00000134 32 ro 0x00000000 Transmit under runs *)
		single_collisn_frames*: UInt; (** 0x00000138 32 ro 0x00000000 Single Collision Frames *)
		multi_collisn_frames*: UInt; (** 0x0000013C 32 ro 0x00000000 Multiple Collision Frames excessive_collisns 0x00000140 32 ro 0x00000000 Excessive Collisions *)
		padding4: UInt;
		late_collisns*: UInt; (** 0x00000144 32 ro 0x00000000 Late Collisions *)
		deferred_tx_frames*: UInt; (** 0x00000148 32 ro 0x00000000 Deferred Transmission Frames *)
		carrier_sense_errs*: UInt; (** 0x0000014C 32 ro 0x00000000 Carrier Sense Errors. *)
		octets_rx_bot*: UInt; (** 0x00000150 32 ro 0x00000000 Octets Received [31:0] *)
		octets_rx_top*: UInt; (** 0x00000154 32 ro 0x00000000 Octets Received [47:32] *)
		frames_rx*: UInt; (** 0x00000158 32 ro 0x00000000 Frames Received *)
		bdcast_fames_rx*: UInt; (** 0x0000015C 32 ro 0x00000000 Broadcast Frames Rx *)
		multi_frames_rx*: UInt; (** 0x00000160 32 ro 0x00000000 Multicast Frames Rx *)
		pause_rx*: UInt; (** 0x00000164 32 ro 0x00000000 Pause Frames Rx *)
		frames_64b_rx*: UInt; (** 0x00000168 32 ro 0x00000000 Frames Rx, 64-byte length *)
		frames_65to127b_rx*: UInt; (** 0x0000016C 32 ro 0x00000000 Frames Rx, 65 to 127-byte length *)
		frames_128to255b_rx*: UInt; (** 0x00000170 32 ro 0x00000000 Frames Rx, 128 to 255-byte length *)
		frames_256to511b_rx*: UInt; (** 0x00000174 32 ro 0x00000000 Frames Rx, 256 to 511-byte length *)
		frames_512to1023b_rx*: UInt; (** 0x00000178 32 ro 0x00000000 Frames Rx, 512 to 1023-byte length *)
		frames_1024to1518b_rx*: UInt; (** 0x0000017C 32 ro 0x00000000 Frames Rx, 1024 to 1518-byte length *)
		padding5: UInt;
		undersz_rx*: UInt; (** 0x00000184 32 ro 0x00000000 Undersize frames received *)
		oversz_rx*: UInt; (** 0x00000188 32 ro 0x00000000 Oversize frames received *)
		jab_rx*: UInt; (** 0x0000018C 32 ro 0x00000000 Jabbers received *)
		fcs_errors*: UInt; (** 0x00000190 32 ro 0x00000000 Frame check sequence errors *)
		length_field_errors*: UInt; (** 0x00000194 32 ro 0x00000000 Length field frame errors *)
		rx_symbol_errors*: UInt; (** 0x00000198 32 ro 0x00000000 Receive symbol errors *)
		align_errors*: UInt; (** 0x0000019C 32 ro 0x00000000 Alignment errors *)
		rx_resource_errors*: UInt; (** 0x000001A0 32 ro 0x00000000 Receive resource errors *)
		rx_overrun_errors*: UInt; (** 0x000001A4 32 ro 0x00000000 Receive overrun errors *)
		ip_hdr_csum_errors*: UInt; (** 0x000001A8 32 ro 0x00000000 IP header checksum errors *)
		tcp_csum_errors*: UInt; (** 0x000001AC 32 ro 0x00000000 TCP checksum errors *)
		udp_csum_errors*: UInt; (** 0x000001B0 32 ro 0x00000000 UDP checksum error *)
		padding6: ARRAY 5 OF UInt;
		timer_strobe_s*: UInt; (** 0x000001C8 32 rw 0x00000000 1588 timer sync strobe seconds *)
		timer_strobe_ns*: UInt; (** 0x000001CC 32 mixed 0x00000000 1588 timer sync strobe nanoseconds *)
		timer_s*: UInt; (** 0x000001D0 32 rw 0x00000000 1588 timer seconds *)
		timer_ns*: UInt; (** 0x000001D4 32 mixed 0x00000000 1588 timer nanoseconds *)
		timer_adjust*: UInt; (** 0x000001D8 32 mixed 0x00000000 1588 timer adjust *)
		timer_incr*: UInt; (** 0x000001DC 32 mixed 0x00000000 1588 timer increment *)
		ptp_tx_s*: UInt; (** 0x000001E0 32 ro 0x00000000 PTP event frame transmitted seconds *)
		ptp_tx_ns*: UInt; (** 0x000001E4 32 ro 0x00000000 PTP event frame transmitted nanoseconds *)
		ptp_rx_s*: UInt; (** 0x000001E8 32 ro 0x00000000 PTP event frame received seconds *)
		ptp_rx_ns*: UInt; (** 0x000001EC 32 ro 0x00000000 PTP event frame received nanoseconds. *)
		ptp_peer_tx_s*: UInt; (** 0x000001F0 32 ro 0x00000000 PTP peer event frame transmitted seconds *)
		ptp_peer_tx_ns*: UInt; (** 0x000001F4 32 ro 0x00000000 PTP peer event frame transmitted nanoseconds *)
		ptp_peer_rx_s*: UInt; (** 0x000001F8 32 ro 0x00000000 PTP peer event frame received seconds *)
		ptp_peer_rx_ns*: UInt; (** 0x000001FC 32 ro 0x00000000 PTP peer event frame received nanoseconds. *)
		padding7: ARRAY 33 OF UInt;
		design_cfg2*: UInt; (** 0x00000284 32 ro x Design Configuration 2 *)
		design_cfg3*: UInt; (** 0x00000288 32 ro 0x00000000 Design Configuration 3 *)
		design_cfg4*: UInt; (** 0x0000028C 32 ro 0x00000000 Design Configuration 4 *)
		design_cfg5*: UInt; (** 0x00000290 32 ro x Design Configuration 5 *)
	END;

	(* DMA RX/TX buffer descriptor *)
	DmaBufDesc = RECORD
		w0: UInt; (* word 0 *)
		w1: UInt; (* word 1 *)
	END;

	(* RX/TX buffer descriptor used for handling by LinkDevice *)
	BufDesc = POINTER TO RECORD
		dmaBd: POINTER{UNSAFE,UNTRACED} TO DmaBufDesc; (* DMA buffer descriptor *)
		packet: EnetBase.Packet; (* attached packet *)
		next: BufDesc; (* reference to the next BufDesc element in the ring *)
	END;

	(**
		Xilinx EMAC PS7 Ethernet link device
	*)
	LinkDevice* = POINTER TO LinkDeviceDesc;
	LinkDeviceDesc* = RECORD(EnetBase.LinkDeviceDesc)
		id*: Int;
		regs*: GemRegisters; (** GEM controller registers *)
		phyAddr*: UInt;

		options: SET; (* device options *)

		dmaBdMem: EnetEnvironment.UncachedMemDesc(*POINTER TO ARRAY OF CHAR*); (* memory space for storing buffer descriptors *)

		rxBdRing, txBdRing: POINTER TO ARRAY OF BufDesc; (* RX/TX buffer descriptor rings *)
		rxBdRingStart, rxBdRingEnd, lastRxBd: BufDesc;
		txBdRingStart, txBdRingEnd, firstTxBd, lastTxBd: BufDesc;
		txBdRingFull, txBdRingEmpty: BOOLEAN; (* TRUE if all TX buffer descriptor ring is full *)

		recvPackets0: EnetBase.PacketFifo; (* internal buffer of received packets which will undergo data cache invalidation *)

		lastRecvFrmCount: UInt;

		sendTimeoutTimer: EnetTiming.Timer;
	END;

	Packet = POINTER TO PacketDesc;
	PacketDesc= RECORD(EnetBase.PacketDesc)
		txTaskHandler: EnetBase.TaskHandler; (* completion result for a transmitted packet *)
		numParts: Int; (* number of parts *)
		partAddr: ARRAY 128 OF ADDRESS; (* payload address in case of a splitted packet *)
		partLen: ARRAY 128 OF Int;
	END;

VAR
	gem0, gem1: LinkDevice;

	(**
		Get interface for a GEM controller with given ID

		gemId: GEM controller ID (0 or 1)
		rxBdRingLen, txBdRingLen: receive/transmit buffer descriptor ring length
		rxPacketPoolSize, txPacketPoolSize: receive/transmit packet pool size
	*)
	PROCEDURE GetDevice*(gemId: Int; rxBdRingLen, txBdRingLen: Int; rxPacketPoolSize, txPacketPoolSize: Int; VAR device: EnetBase.LinkDevice; VAR res: ResultCode): BOOLEAN;
	VAR
		dev: LinkDevice;
		init: BOOLEAN;
		pool: EnetBase.PacketFifo;
		i: Int;
	BEGIN
		IF (gemId < 0) OR (gemId > 1) THEN
			res := EnetBase.ErrInvalidValue;
			RETURN FALSE;
		END;

		IF rxPacketPoolSize < rxBdRingLen THEN (* RX packet pool cannot be smaller than the RX buffer descriptor ring size *)
			res := EnetBase.ErrInvalidValue;
			RETURN FALSE;
		END;

		IF gemId = 0 THEN
			IF gem0 = NIL THEN NEW(gem0); init := TRUE; END;
			dev := gem0;
		ELSE
			IF gem1 = NIL THEN NEW(gem1); init := TRUE; END;
			dev := gem1;
		END;
		IF init THEN
			dev.id := gemId;
			IF gemId = 0 THEN
				dev.regs := GemBaseAddr0;
			ELSE
				dev.regs := GemBaseAddr1;
			END;
			dev.phyAddr := EnetPhy.InvalidPhyAddr;
			dev.phyWrite := PhyWrite;
			dev.phyRead := PhyRead;
			dev.setMacAddr := SetMacAddr;
			dev.setLinkSpeed := SetLinkSpeed;
			dev.start := Start;
			dev.stop := Stop;
			dev.reset := Reset;
			dev.finalize := Finalize;
			dev.setPacketPayload := SetPacketPayload;
			dev.sendPacket := SendPacket;
			dev.updateRx := UpdateRx;
			dev.updateTx := UpdateTx;

			(*dev.dmaBdMem := NIL;*)
		END;

		(*
			allocate/reallocate RX/TX packet pools if required
		*)
		InitPacketPool(dev.rxPacketPool,rxPacketPoolSize);
		InitPacketPool(dev.txPacketPool,txPacketPoolSize);
		IF (dev.recvPackets = NIL) OR (LEN(dev.recvPackets.packets) # rxPacketPoolSize) THEN
			dev.recvPackets := EnetBase.NewPacketFifo(rxPacketPoolSize);
			dev.recvPackets0 := EnetBase.NewPacketFifo(rxPacketPoolSize);
		END;

		IF ~InitDma(dev,rxBdRingLen,txBdRingLen,res) THEN RETURN FALSE; END;

		IF ~Reset(dev,res) THEN END;

		EnetTiming.SetTimerMilli(dev.sendTimeoutTimer,10);

		device := dev;

		res := 0;
		RETURN TRUE;
	END GetDevice;

	PROCEDURE InitPacketPool(VAR pool: EnetBase.PacketFifo; poolSize: Int);
	VAR
		poolTmp: EnetBase.PacketFifo;
		packet: EnetBase.Packet;
		i: Int;
	BEGIN
		IF (pool = NIL) OR (poolSize # LEN(pool.packets)) THEN

			poolTmp := pool;
			pool := EnetBase.NewPacketFifo(poolSize);

			IF poolTmp # NIL THEN
				WHILE EnetBase.PacketFifoGet(poolTmp,packet) & EnetBase.PacketFifoPut(pool,packet) DO
				END;
			END;
			WHILE pool.count < poolSize DO
				packet := NewPacket();
				packet.ownerPool := pool;
				ASSERT(EnetBase.PacketFifoPut(pool,packet));
			END;

			ASSERT(pool.count = poolSize);
			FOR i := 0 TO poolSize-1 DO
				pool.packets[i].ownedByDev := FALSE;
				pool.packets[i].ownedByUser := FALSE;
			END;

		END;

	END InitPacketPool;

	(**
		Write to an Ethernet PHY device attached to a given GEM controller

		phyAddr: PHY address (5 bit)
		regAddr: register address (5 bit)
		data: data to write to the given register (16 bit)
	*)
	PROCEDURE PhyWrite*(dev: EnetBase.LinkDevice; phyAddr, regAddr, data: UInt; VAR res: ResultCode): BOOLEAN;
	BEGIN
		ASSERT(phyAddr <= 31);
		ASSERT(regAddr <= 31);
		ASSERT(data <= 65535);
		WITH dev : LinkDevice DO
			IF S.MSK(dev.regs.net_status,NWSR_MDIOIDLE_MASK) = 0 THEN res := EnetBase.ErrMdioBusy; RETURN FALSE; END;

			dev.regs.phy_maint := PHYMNTNC_OP_MASK+PHYMNTNC_OP_W_MASK +
										LSH(phyAddr,PHYMNTNC_PHYAD_SHIFT_MASK) +
										LSH(regAddr,PHYMNTNC_PHREG_SHIFT_MASK) +
										data;

			(* wait for completion of the operation *)
			REPEAT UNTIL S.MSK(dev.regs.net_status,NWSR_MDIOIDLE_MASK) # 0;
		END;

		res := 0;
		RETURN TRUE;
	END PhyWrite;

	(**
		Read from an Ethernet PHY device attached to a given GEM controller

		phyAddr: PHY address (5 bit)
		regAddr: register address (5 bit)
		data: data read from the given register (16 bit)
	*)
	PROCEDURE PhyRead*(dev: EnetBase.LinkDevice; phyAddr, regAddr: UInt; VAR data: UInt; VAR res: ResultCode): BOOLEAN;
	BEGIN
		ASSERT(phyAddr <= 31);
		ASSERT(regAddr <= 31);
		WITH dev : LinkDevice DO
			IF S.MSK(dev.regs.net_status,NWSR_MDIOIDLE_MASK) = 0 THEN res := EnetBase.ErrMdioBusy; RETURN FALSE; END;

			dev.regs.phy_maint := PHYMNTNC_OP_MASK+PHYMNTNC_OP_R_MASK +
										LSH(phyAddr,PHYMNTNC_PHYAD_SHIFT_MASK) +
										LSH(regAddr,PHYMNTNC_PHREG_SHIFT_MASK);

			(* wait for completion of the operation *)
			REPEAT UNTIL S.MSK(dev.regs.net_status,NWSR_MDIOIDLE_MASK) # 0;

			data := dev.regs.phy_maint MOD 10000H;
		END;

		res := 0;
		RETURN TRUE;
	END PhyRead;

	(**
		Setup MAC address for a given link device
	*)
	PROCEDURE SetMacAddr*(dev: EnetBase.LinkDevice; CONST macAddr: EnetBase.MacAddr; VAR res: ResultCode): BOOLEAN;
	BEGIN
		IF dev.isActive THEN
			res := EnetBase.ErrCannotDoWhenActive;
			RETURN FALSE;
		END;

		WITH dev : LinkDevice DO
			SetSpecificMacAddr(dev,1,macAddr.addr);
		END;

		dev.macAddr := macAddr;

		res := 0;
		RETURN TRUE;
	END SetMacAddr;

	(**
		Setup link speed for a given device

		speed: link speed in Mbps
	*)
	PROCEDURE SetLinkSpeed*(dev: EnetBase.LinkDevice; CONST speed: ARRAY OF CHAR; fullDuplex: BOOLEAN; VAR res: ResultCode): BOOLEAN;
	BEGIN
		IF dev.isActive THEN
			res := EnetBase.ErrCannotDoWhenActive;
			RETURN FALSE;
		END;

		WITH dev : LinkDevice DO
			(* Configure the PHY *)
			IF speed = EnetBase.LinkSpeedAuto THEN
				IF ~PhyAutonegotiateLink(dev,dev.phyAddr,dev.linkSpeed,fullDuplex,res) THEN
					RETURN FALSE;
				END;
			ELSE
				res := EnetBase.ErrInvalidValue;
				RETURN FALSE;
			END;

			SetControllerSpeed(dev,dev.linkSpeed,fullDuplex);

			COPY(speed,dev.linkSpeed);
			dev.fullDuplex := fullDuplex;
		END;

		res := 0;
		RETURN TRUE;
	END SetLinkSpeed;

	(**
		Setup device-specific options

		options: set of device options to enable, not included options will be disabled
	*)
	PROCEDURE SetOptions*(dev: EnetBase.LinkDevice; optionsPage: Int; options: SET; VAR res: ResultCode): BOOLEAN;
	CONST
		NWCFG_OPTIONS_MASK = NWCFG_1536RXEN_MASK +
										NWCFG_NVLANDISC_MASK +
										NWCFG_FCSREM_MASK +
										NWCFG_LENGTHERRDSCRD_MASK +
										NWCFG_PAUSEEN_MASK +
										NWCFG_COPYALLEN_MASK +
										NWCFG_BCASTDI_MASK +
										NWCFG_MCASTHASHEN_MASK +
										NWCFG_RXCHKSUMEN_MASK;
	VAR
		d: UInt;
	BEGIN
		IF dev.isActive THEN
			res := EnetBase.ErrCannotDoWhenActive;
			RETURN FALSE;
		END;

		WITH dev : LinkDevice DO

			d := 0;

			(* Turn on promiscuous frame filtering (all frames are received) *)
			IF Promisc IN options THEN d := d + NWCFG_COPYALLEN_MASK; END;

			(* It is configured to max 1536 *)
			IF Frame1536 IN options THEN d := d + NWCFG_1536RXEN_MASK; END;

			(* Turn on VLAN packet only, only VLAN tagged will be accepted *)
			IF Vlan IN options THEN d := d + NWCFG_NVLANDISC_MASK; END;

			(* Turn on flow control *)
			IF FlowControl IN options THEN d := d + NWCFG_PAUSEEN_MASK; END;

			(* Turn on FCS stripping on receive packets *)
			IF FcsStrip IN options THEN d := d + NWCFG_FCSREM_MASK; END;

			(* Turn on length/type field checking on receive packets *)
			IF LenTypeErr IN options THEN d := d + NWCFG_LENGTHERRDSCRD_MASK; END;

			(* Allow broadcast address reception *)
			IF ~(Broadcast IN options) THEN d := d + NWCFG_BCASTDI_MASK; END;

			(* Allow multicast address filtering *)
			IF Multicast IN options THEN d := d + NWCFG_MCASTHASHEN_MASK; END;

			(* enable RX checksum offload *)
			IF RxChksumEnable IN options THEN d := d + NWCFG_RXCHKSUMEN_MASK; END;

			(* write all net_cfg options all at once *)
			dev.regs.net_cfg := S.MSK(dev.regs.net_cfg,-NWCFG_OPTIONS_MASK-1) + d;

			(* Enable TX checksum offload *)
			IF TxChksumEnable IN options THEN
				dev.regs.dma_cfg := S.MSK(dev.regs.dma_cfg,-DMACR_TCPCKSUM_MASK-1) + DMACR_TCPCKSUM_MASK;
			ELSE
				dev.regs.dma_cfg := S.MSK(dev.regs.dma_cfg,-DMACR_TCPCKSUM_MASK-1);
			END;

			dev.options := options;

		END;

		res := 0;
		RETURN TRUE;
	END SetOptions;


	(*! (PHY hardware-specific)

		Perform PHY link autonegotiation
	*)
	PROCEDURE PhyAutonegotiateLink(dev: LinkDevice; phyAddr: UInt; VAR speed: ARRAY OF CHAR; VAR fullDuplex: BOOLEAN; VAR res: ResultCode): BOOLEAN;
	CONST
		RGMII_TXRX_CLOCK_DELAYED_MASK = 0x0030;
		MII_ADVERTISE_MASK = EnetPhy.ADVERTISE_PAUSE_CAP+EnetPhy.ADVERTISE_PAUSE_ASYM+EnetPhy.ADVERTISE_ALL;
		MII_CTRL1000_MASK = EnetPhy.ADVERTISE_1000HALF+EnetPhy.ADVERTISE_1000FULL;
		MII_BMCR_MASK = EnetPhy.BMCR_ANENABLE+EnetPhy.BMCR_ANRESTART;
		PAGE_ADDRESS_REGISTER = 22;
		CONTROL_REG_MAC = 21;
		COPPER_SPECIFIC_CONTROL_REG = 16;
		COPPER_SPECIFIC_CONTROL_REG_MASK = LSH(Int16(7),12)+LSH(Int16(1),11); (* max number of gigabit attempts + enable downshift *)
		SPECIFIC_STATUS_REG = 17;
		COPPER_SPECIFIC_STATUS_REG_2 = 19;
		AUTONEG_ERROR_MASK = 0x8000;
	VAR
		d, d1: UInt;
		t: EnetTiming.Timer;
	BEGIN
		speed := "";
		(* configure RX/TX clock delay settings *)
		IF ~PhyWrite(dev,phyAddr,PAGE_ADDRESS_REGISTER,2,res) THEN RETURN FALSE; END; (* select page 2 *)
		IF ~PhyRead(dev,phyAddr,CONTROL_REG_MAC,d,res) THEN RETURN FALSE; END;
		d := S.MSK(d,-Int16(RGMII_TXRX_CLOCK_DELAYED_MASK)-1) + RGMII_TXRX_CLOCK_DELAYED_MASK;
		IF ~PhyWrite(dev,phyAddr,CONTROL_REG_MAC,d,res) THEN RETURN FALSE; END;

		(* advertising 10 Mbps and 100 Mbps *)
		IF ~PhyWrite(dev,phyAddr,PAGE_ADDRESS_REGISTER,0,res) THEN RETURN FALSE; END; (* select page 0 *)
		IF ~PhyRead(dev,phyAddr,EnetPhy.MII_ADVERTISE,d,res) THEN RETURN FALSE; END;
		d := S.MSK(d,-MII_ADVERTISE_MASK-1) + MII_ADVERTISE_MASK;
		IF ~PhyWrite(dev,phyAddr,EnetPhy.MII_ADVERTISE,d,res) THEN RETURN FALSE; END;

		(* advertising 1000 Mbps *)
		IF ~PhyRead(dev,phyAddr,EnetPhy.MII_CTRL1000,d,res) THEN RETURN FALSE; END;
		d := S.MSK(d,-MII_CTRL1000_MASK-1) + MII_CTRL1000_MASK;
		IF ~PhyWrite(dev,phyAddr,EnetPhy.MII_CTRL1000,d,res) THEN RETURN FALSE; END;

		IF ~PhyWrite(dev,phyAddr,PAGE_ADDRESS_REGISTER,0,res) THEN RETURN FALSE; END; (* select page 0 *)
		IF ~PhyRead(dev,phyAddr,COPPER_SPECIFIC_CONTROL_REG,d,res) THEN RETURN FALSE; END;
		d := S.MSK(d,-COPPER_SPECIFIC_CONTROL_REG_MASK-1) + COPPER_SPECIFIC_CONTROL_REG_MASK;
		IF ~PhyWrite(dev,phyAddr,COPPER_SPECIFIC_CONTROL_REG,d,res) THEN RETURN FALSE; END;

		IF ~PhyRead(dev,phyAddr,EnetPhy.MII_BMCR,d,res) THEN RETURN FALSE; END;
		d := S.MSK(d,-MII_BMCR_MASK-1) + MII_BMCR_MASK;
		IF ~PhyWrite(dev,phyAddr,EnetPhy.MII_BMCR,d,res) THEN RETURN FALSE; END;

		IF EnableTrace THEN Trace.StringLn("resetting PHY ..."); END;
		(* resetting PHY *)
		IF ~EnetPhy.ResetPhy(dev,phyAddr,1000,res) THEN RETURN FALSE; END;
		IF EnableTrace THEN Trace.StringLn("PHY has been resetted"); END;

		IF EnableTrace THEN Trace.StringLn("autonegotiating link ..."); END;
		IF ~PhyRead(dev,phyAddr,EnetPhy.MII_BMSR,d,res) THEN RETURN FALSE; END;
		EnetTiming.SetTimerMilli(t,LinkAutonegoTimeout);
		EnetTiming.StartTimer(t);
		WHILE (S.MSK(d,EnetPhy.BMSR_ANEGCOMPLETE) = 0) & ~EnetTiming.IsTimerExpired(t) DO
			EnetTiming.WaitMilli(500);
			IF ~PhyRead(dev,phyAddr,COPPER_SPECIFIC_STATUS_REG_2,d,res) THEN RETURN FALSE; END;
			IF S.MSK(d,AUTONEG_ERROR_MASK) # 0 THEN
				res := EnetBase.ErrSpeedAutonegoFailure;
				RETURN FALSE;
			END;
			IF ~PhyRead(dev,phyAddr,EnetPhy.MII_BMSR,d,res) THEN RETURN FALSE; END;
		END;
		IF S.MSK(d,EnetPhy.BMSR_ANEGCOMPLETE) = 0 THEN
			IF EnableTrace THEN Trace.StringLn("[Error]: timeout has expired!"); END;
			RETURN FALSE;
		END;
		IF EnableTrace THEN Trace.StringLn("link autonegotiation has been completed"); END;

		IF ~PhyRead(dev,phyAddr,SPECIFIC_STATUS_REG,d,res) THEN RETURN FALSE; END;

		IF EnableTrace THEN Trace.StringLn("partner capabilities: " & Trace.Hx(d,4)); END;

		d1 := Int16(LSH(S.MSK(d,0xC000),-14));
		IF d1 = 2 THEN (* 1000 Mbps *)
			speed := EnetBase.Mbps1000;
		ELSIF d1 = 1 THEN (* 100 Mbps *)
			speed := EnetBase.Mbps100;
		ELSE (* 10 Mbps *)
			speed := EnetBase.Mbps10;
		END;

		fullDuplex := S.MSK(d,0x2000) # 0;

		IF EnableTrace THEN Trace.StringLn("link speed is " & speed & ", fullDuplex is " & fullDuplex); END;

		res := 0;
		RETURN TRUE;
	END PhyAutonegotiateLink;

	(**
		Start a given link device
	*)
	PROCEDURE Start*(dev: EnetBase.LinkDevice; VAR res: ResultCode): BOOLEAN;
	VAR d: UInt;
	BEGIN
		IF dev.isActive THEN
			res := 0;
			RETURN TRUE;
		END;
		WITH dev : LinkDevice DO

			dev.lastRecvFrmCount := 0;

			(*
				Prepare DMA for start
			*)
			IF ~ConfigureDma(dev,res) THEN RETURN FALSE; END;
			dev.regs.rx_qbar := S.VAL(ADDRESS,dev.rxBdRingStart.dmaBd);
			dev.regs.tx_qbar := S.VAL(ADDRESS,dev.txBdRingStart.dmaBd);

			(* clear any existing interrupt status *)
			dev.regs.intr_status := IXR_ALL_MASK;

			(*
				Enable interrupts
			*)
			dev.regs.intr_en := IXR_TX_ERR_MASK + IXR_RX_ERR_MASK (*+ IXR_FRAMERX_MASK+ IXR_TXCOMPL_MASK*);
			ASSERT(S.MSK(dev.regs.intr_en,-IXR_ALL_MASK-1) = 0);

			(*
				Optionally enable transmitter and receiver
			*)
			d := 0;
			IF TransmitterEnable IN dev.options THEN d := d + NWCTRL_TXEN_MASK; END;
			IF ReceiverEnable IN dev.options THEN d := d + NWCTRL_RXEN_MASK; END;
			dev.regs.net_ctrl := S.MSK(dev.regs.net_ctrl,NWCTRL_RXTXDIS_MASK) + d;

			dev.isActive := TRUE;
		END;

		res := 0;
		RETURN TRUE;
	END Start;

	(**
		Stop of a given link device
	*)
	PROCEDURE Stop*(dev: EnetBase.LinkDevice; VAR res: ResultCode): BOOLEAN;
	BEGIN
		StopController(dev(LinkDevice));
		dev.isActive := FALSE;
		res := 0;
		RETURN TRUE;
	END Stop;

	(**
		Resetting a given link device
	*)
	PROCEDURE Reset*(dev: EnetBase.LinkDevice; VAR res: ResultCode): BOOLEAN;
	VAR
		allowZeroPhyAddr: BOOLEAN;
	BEGIN
		WITH dev : LinkDevice DO

			StopController(dev);

			IF EnableTrace THEN Trace.StringLn("[-] resetting Xilinx EmacPs7 controller " & dev.id & " ..."); END;
			ResetController(dev);
			dev.isActive := FALSE;
			IF EnableTrace THEN Trace.StringLn("[x] controller has been resetted"); END;

			IF EnableTrace THEN Trace.StringLn("[-] setting up default controller options ..."); END;
			IF ~SetOptions(dev,1,DefaultOptions,res) THEN RETURN FALSE; END;
			IF EnableTrace THEN Trace.StringLn("[x] controller options has been set up"); END;

			IF EnableTrace THEN Trace.StringLn("[-] detecting PHY ..."); END;
			IF dev.id = 0 THEN
				allowZeroPhyAddr := AllowZeroPhyAddr0;
			ELSE
				allowZeroPhyAddr := AllowZeroPhyAddr1;
			END;
			IF ~EnetPhy.DetectPhy(dev,dev.phyAddr,allowZeroPhyAddr,res) THEN RETURN FALSE; END;
			IF EnableTrace THEN Trace.StringLn("[x] PHY found at address 0x" & Trace.Hx(dev.phyAddr,2)); END;

			dev.lastRecvFrmCount := 0;
		END;

		res := 0;
		RETURN TRUE;
	END Reset;

	PROCEDURE Finalize*(dev: EnetBase.LinkDevice; VAR res: ResultCode): BOOLEAN;
	BEGIN
		RETURN Stop(dev,res);
	END Finalize;

	(**
		Update the state of the receive path of a link device
	*)
	PROCEDURE UpdateRx*(dev: EnetBase.LinkDevice; VAR res: ResultCode): BOOLEAN;
	VAR
		packet: EnetBase.Packet;
		intrStatus, rxStatus: UInt;
	BEGIN
		WITH dev : LinkDevice DO
			IF dev.isActive THEN
				ProcessRxBds(dev);
			ELSE
				res := EnetBase.ErrNotActive;
				RETURN FALSE;
			END;
		END;
		res := 0;
		RETURN TRUE;
	END UpdateRx;

	(**
		Update the state of the transmit path of a link device
	*)
	PROCEDURE UpdateTx*(dev: EnetBase.LinkDevice; VAR res: ResultCode): BOOLEAN;
	VAR
		packet: EnetBase.Packet;
		txStatus: UInt;
	BEGIN
		WITH dev : LinkDevice DO
			IF dev.isActive THEN
				ProcessTxBds(dev);
			ELSE
				res := EnetBase.ErrNotActive;
				RETURN FALSE;
			END;
		END;
		res := 0;
		RETURN TRUE;
	END UpdateTx;

	(*
		Stop a given GEM controller
	*)
	PROCEDURE StopController(dev: LinkDevice);
	BEGIN
		(* disable all interrupts *)
		dev.regs.intr_dis := IXR_ALL_MASK;
		(* disable the receiver and transmitter *)
		dev.regs.net_ctrl := S.MSK(dev.regs.net_ctrl,NWCTRL_RXTXDIS_MASK);
	END StopController;

	(*
		Reset a given GEM controller
	*)
	PROCEDURE ResetController(dev: LinkDevice);
	VAR
		d: UInt;
		i: Int;
		t: EnetTiming.Timer;
	BEGIN

		(*
			Initialize the controller
		*)
		(* 1. Clear the Network Control register *)
		dev.regs.net_ctrl := 0;
		(* 2. Clear the Statistics registers *)
		dev.regs.net_ctrl := NWCTRL_STATCLR_MASK;
		(* 3. Clear the Status registers - write a 1 to the Status registers *)
		dev.regs.rx_status := 0x0F;
		dev.regs.tx_status := 0x1FF;
		(* 4. Disable all interrupts *)
		dev.regs.intr_dis := 0x7FFFEFF;
		(* 5. Clear the buffer queues *)
		dev.regs.rx_qbar := 0;
		dev.regs.tx_qbar := 0;

		(*
			Setup the controller to default configuration
		*)
		dev.regs.net_cfg := NWCFG_100_MASK+NWCFG_FDEN_MASK+NWCFG_UCASTHASHEN_MASK;

		IF RX_BUF_SIZE MOD RX_BUF_UNIT # 0 THEN
			d := RX_BUF_SIZE DIV RX_BUF_UNIT;
		ELSE
			d := (RX_BUF_SIZE DIV RX_BUF_UNIT) + 1;
		END;
		dev.regs.dma_cfg := S.MSK(LSH(d,DMACR_RXBUF_SHIFT),DMACR_RXBUF_MASK) + DMACR_RXSIZE_MASK + DMACR_TXSIZE_MASK;

		dev.regs.tx_status := 0;
		dev.regs.rx_status := 0;

		dev.regs.intr_status := dev.regs.intr_status;

		ClearHash(dev);

		(* clear MAC addresses and type ID matching *)
		FOR i := 1 TO 4 DO
			SetSpecificMacAddr(dev,i,EnetBase.NilMacAddr.addr);
			SetTypeIdMatch(dev,i,0,FALSE);
		END;

		(* clear all counters *)
		dev.regs.octets_tx_bot := 0;
		dev.regs.octets_tx_top := 0;
		dev.regs.frames_tx := 0;
		dev.regs.broadcast_frames_tx := 0;
		dev.regs.multi_frames_tx := 0;
		dev.regs.pause_frames_tx := 0;
		dev.regs.frames_64b_tx := 0;
		dev.regs.frames_65to127b_tx := 0;
		dev.regs.frames_128to255b_tx := 0;
		dev.regs.frames_256to511b_tx := 0;
		dev.regs.frames_512to1023b_tx := 0;
		dev.regs.frames_1024to1518b_tx := 0;

		dev.regs.tx_under_runs := 0;
		dev.regs.single_collisn_frames := 0;
		dev.regs.multi_collisn_frames := 0;

		dev.regs.late_collisns := 0;
		dev.regs.deferred_tx_frames := 0;
		dev.regs.carrier_sense_errs := 0;
		dev.regs.octets_rx_bot := 0;
		dev.regs.octets_rx_top := 0;
		dev.regs.frames_rx := 0;
		dev.regs.bdcast_fames_rx := 0;
		dev.regs.multi_frames_rx := 0;
		dev.regs.pause_rx := 0;
		dev.regs.frames_64b_rx := 0;
		dev.regs.frames_65to127b_rx := 0;
		dev.regs.frames_128to255b_rx := 0;
		dev.regs.frames_256to511b_rx := 0;
		dev.regs.frames_512to1023b_rx := 0;
		dev.regs.frames_1024to1518b_rx := 0;

		dev.regs.undersz_rx := 0;
		dev.regs.oversz_rx := 0;
		dev.regs.jab_rx := 0;
		dev.regs.fcs_errors := 0;
		dev.regs.length_field_errors := 0;
		dev.regs.rx_symbol_errors := 0;
		dev.regs.align_errors := 0;
		dev.regs.rx_resource_errors := 0;
		dev.regs.rx_overrun_errors := 0;
		dev.regs.ip_hdr_csum_errors := 0;
		dev.regs.tcp_csum_errors := 0;
		dev.regs.udp_csum_errors := 0;

		dev.regs.net_ctrl := S.MSK(dev.regs.net_ctrl,-NWCTRL_MDEN_MASK-1) + NWCTRL_MDEN_MASK; (* enable MDIO *)
		dev.regs.phy_maint := 0;

		(* setup the speed of MDIO line *)
		IF dev.id = 0 THEN
			SetMdioDivisor(dev,MdioDivisor0);
		ELSE
			SetMdioDivisor(dev,MdioDivisor1);
		END;
		(* wait for some time until MDIO line becomes available *)
		EnetTiming.SetTimerMilli(t,1000);
		EnetTiming.StartTimer(t);
		REPEAT
		UNTIL (S.MSK(dev.regs.net_status,NWSR_MDIOIDLE_MASK) # 0) OR EnetTiming.IsTimerExpired(t);

	END ResetController;

	(*! (PHY hardware-specific)

		Setup GEM controller according to specified link speed and full duplex settings
	*)
	PROCEDURE SetControllerSpeed(dev: LinkDevice; CONST speed: ARRAY OF CHAR; fullDuplex: BOOLEAN);
	CONST
		GEM_SLCR_DIV_MASK = 0xFC0FC0FF;
		(* IO PLL 1000 MHz, div0 = 8, div1 = 1 correspond to clock 125 MHz *)
		GEM_SLCR_1000MBPS_DIV0 = 0x8;
		GEM_SLCR_1000MBPS_DIV1 = 0x1;
		(* IO PLL 1000 MHz, div0 = 8, div1 = 5 correspond to clock 25 MHz *)
		GEM_SLCR_100MBPS_DIV0 = 0x8;
		GEM_SLCR_100MBPS_DIV1 = 0x5;
		(* IO PLL 1000 MHz, div0 = 8, div1 = 50 correspond to clock 2.5 MHz *)
		GEM_SLCR_10MBPS_DIV0 = 0x8;
		GEM_SLCR_10MBPS_DIV1 = 0x50;
	VAR
		d: UInt;
	BEGIN
		(*
			Setup RX/TX clocks
		*)
		IF speed = EnetBase.Mbps1000 THEN d := LSH(GEM_SLCR_1000MBPS_DIV1,20) + LSH(GEM_SLCR_1000MBPS_DIV0,8);
		ELSIF speed = EnetBase.Mbps100 THEN d := LSH(GEM_SLCR_100MBPS_DIV1,20) + LSH(GEM_SLCR_100MBPS_DIV0,8);
		ELSE (* 10 Mbps *)
			ASSERT(speed = EnetBase.Mbps10);
			d := LSH(GEM_SLCR_10MBPS_DIV1,20) + LSH(GEM_SLCR_10MBPS_DIV0,8);
		END;

		Platform.slcr.SLCR_UNLOCK := Platform.SlcrUnlockKey; (* enable writing to SLCR registers *)
		IF dev.id = 0 THEN
			Platform.slcr.GEM0_CLK_CTRL := S.MSK(Platform.slcr.GEM0_CLK_CTRL,GEM_SLCR_DIV_MASK) + d;
		ELSE
			Platform.slcr.GEM1_CLK_CTRL := S.MSK(Platform.slcr.GEM1_CLK_CTRL,GEM_SLCR_DIV_MASK) + d;
		END;
		Platform.slcr.SLCR_LOCK := Platform.SlcrLockKey; (* disable writing to SLCR registers *)

		(*
			Setup net_cfg register according to the link speed and full duplex settings
		*)
		d := S.MSK(dev.regs.net_cfg,-(NWCFG_1000_MASK+NWCFG_100_MASK+NWCFG_FDEN_MASK)-1);

		IF speed = EnetBase.Mbps1000 THEN d := d + NWCFG_1000_MASK;
		ELSIF speed = EnetBase.Mbps100 THEN d := d + NWCFG_100_MASK;
		END;

		IF fullDuplex THEN d := d + NWCFG_FDEN_MASK; END; (* enable full duplex *)

		dev.regs.net_cfg := d;
	END SetControllerSpeed;

	PROCEDURE ClearHash(dev: LinkDevice);
	BEGIN
		dev.regs.hash_bot := 0;
		dev.regs.hash_top := 0;
	END ClearHash;

	(*
		Setup a specific MAC address

		index: index of a specific address to setup (from 1 to 4)
	*)
	PROCEDURE SetSpecificMacAddr(dev: LinkDevice; index: Int; CONST mac: ARRAY 6 OF Int8);
	VAR dl, dh: UInt;
	BEGIN
		ASSERT((index >= 1) & (index <= 4));

		dl := UInt(mac[0]) MOD 100H + (UInt(mac[1]) MOD 100H) * 100H + (UInt(mac[2]) MOD 100H) * 10000H + (UInt(mac[3]) MOD 100H) * 1000000H;
		dh := UInt(mac[4]) MOD 100H + (UInt(mac[5]) MOD 100H) * 100H;
		CASE index OF
			|1:
				dev.regs.spec_addr1_bot := dl;
				dev.regs.spec_addr1_top := S.MSK(dev.regs.spec_addr1_top,0xFFFF0000) + dh; (* keep high 16 reserved bits untouched *)
			|2:
				dev.regs.spec_addr2_bot := dl;
				dev.regs.spec_addr2_top := S.MSK(dev.regs.spec_addr2_top,0xFFFF0000) + dh; (* keep high 16 reserved bits untouched *)
			|3:
				dev.regs.spec_addr3_bot := dl;
				dev.regs.spec_addr3_top := S.MSK(dev.regs.spec_addr3_top,0xFFFF0000) + dh; (* keep high 16 reserved bits untouched *)
			|4:
				dev.regs.spec_addr4_bot := dl;
				dev.regs.spec_addr4_top := S.MSK(dev.regs.spec_addr4_top,0xFFFF0000) + dh; (* keep high 16 reserved bits untouched *)
		END;

	END SetSpecificMacAddr;

	(*
		index: index of a type ID to setup (from 1 to 4)
	*)
	PROCEDURE SetTypeIdMatch(dev: LinkDevice; index: Int; typeId: UInt; enable: BOOLEAN);
	VAR d: UInt;
	BEGIN
		ASSERT((index >= 1) & (index <= 4));

		d := typeId MOD 10000H;
		IF enable THEN d := d +0x80000000; END; (* set bit 31 to enable matching *)

		CASE index OF
			|1: dev.regs.type_id_match1 := d;
			|2: dev.regs.type_id_match2 := d;
			|3: dev.regs.type_id_match3 := d;
			|4: dev.regs.type_id_match4 := d;
		END;
	END SetTypeIdMatch;

	(**

 		Set the MDIO clock divisor.

 		Calculating the divisor:

		               f[HOSTCLK]
		f[MDC] = -----------------
 		           (1 + Divisor) * 2

 		where f[HOSTCLK] is the bus clock frequency in MHz, and f[MDC] is the
 		MDIO clock frequency in MHz to the PHY. Typically, f[MDC] should not
 		exceed 2.5 MHz. Some PHYs can tolerate faster speeds which means faster
 		access. Here is the table to show values to generate MDC,

		000 : divide pclk by   8 (pclk up to  20 MHz)
		001 : divide pclk by  16 (pclk up to  40 MHz)
		010 : divide pclk by  32 (pclk up to  80 MHz)
		011 : divide pclk by  48 (pclk up to 120 MHz)
		100 : divide pclk by  64 (pclk up to 160 MHz)
		101 : divide pclk by  96 (pclk up to 240 MHz)
		110 : divide pclk by 128 (pclk up to 320 MHz)
		111 : divide pclk by 224 (pclk up to 540 MHz)
	*)
	PROCEDURE SetMdioDivisor(dev: LinkDevice; divisor: UInt);
	VAR reg: UInt;
	BEGIN
		ASSERT((divisor >= MDC_DIV_8) & (divisor <= MDC_DIV_224));
		dev.regs.net_cfg := S.MSK(dev.regs.net_cfg,NWCFG_INV_MDCCLKDIV_MASK) + LSH(divisor,NWCFG_MDC_SHIFT_MASK);
	END SetMdioDivisor;

	(**
		Initialize DMA engine of a given GEM device
	*)
	PROCEDURE InitDma(dev: LinkDevice; rxBdRingLen, txBdRingLen: Int; VAR res: LONGINT): BOOLEAN;
	CONST
		MB = 1024*1024; (* one Mega byte *)
	VAR
		packet: EnetBase.Packet;
		bdAddr: ADDRESS;
		i: Int;
	BEGIN
		ASSERT(dev.dmaBdMem.addr = NIL);
		ASSERT((rxBdRingLen+txBdRingLen)*SIZEOF(DmaBufDesc) <= MB);

		EnetEnvironment.AllocateUncachedMemory(MB,dev.dmaBdMem);
		bdAddr := dev.dmaBdMem.addr;
(*
		(*
			allocate 2 pages (each page is 1 MBytes) of memory in Heaps for
			mapping one full page uncached without affecting any adjacent data
		*)
		NEW(dev.dmaBdMem,2*MB);
		bdAddr := ADDRESSOF(dev.dmaBdMem[0]);
		bdAddr := bdAddr + (MB - bdAddr MOD MB); (* align to 1 MB boundary *)
		ASSERT(bdAddr MOD MB = 0);
		Machine.DisableDCacheRange(bdAddr,MB);
*)
		IF EnableTrace THEN Trace.StringLn("bdAddr=0x" & Trace.Hx(bdAddr,8)) END;

		(*
			RX buffer descriptor ring
		*)
		NEW(dev.rxBdRing,rxBdRingLen);
		FOR i := 0 TO rxBdRingLen-1 DO
			NEW(dev.rxBdRing[i]);
			dev.rxBdRing[i].dmaBd := bdAddr;
			dev.rxBdRing[i].packet := NIL;
			INC(bdAddr,SIZEOF(DmaBufDesc));
		END;
		FOR i := 0 TO rxBdRingLen-2 DO
			dev.rxBdRing[i].next := dev.rxBdRing[i+1];
		END;
		dev.rxBdRing[rxBdRingLen-1].next := dev.rxBdRing[0];
		dev.rxBdRingStart := dev.rxBdRing[0];
		dev.rxBdRingEnd := dev.rxBdRing[rxBdRingLen-1];
		dev.lastRxBd := dev.rxBdRingStart;

		(*
			TX buffer descriptor ring
		*)
		NEW(dev.txBdRing,txBdRingLen);
		FOR i := 0 TO txBdRingLen-1 DO
			NEW(dev.txBdRing[i]);
			dev.txBdRing[i].dmaBd := bdAddr;
			dev.txBdRing[i].packet := NIL;
			INC(bdAddr,SIZEOF(DmaBufDesc));
		END;
		FOR i := 0 TO txBdRingLen-2 DO
			dev.txBdRing[i].next := dev.txBdRing[i+1];
		END;
		dev.txBdRing[txBdRingLen-1].next := dev.txBdRing[0];
		dev.txBdRingStart := dev.txBdRing[0];
		dev.txBdRingEnd := dev.txBdRing[txBdRingLen-1];
		dev.firstTxBd := dev.txBdRingStart;
		dev.lastTxBd := dev.txBdRingStart;

		IF dev.id = 0 THEN
			EnetEnvironment.InstallInterruptHandler(InterruptHandlerGem0,GemIrq0);
		ELSE
			EnetEnvironment.InstallInterruptHandler(InterruptHandlerGem1,GemIrq1);
		END;

		res := 0;
		RETURN TRUE;
	END InitDma;

	(*
		Configure DMA engine of a GEM device used just before starting
	*)
	PROCEDURE ConfigureDma(dev: LinkDevice; VAR res: LONGINT): BOOLEAN;
	VAR
		packet: EnetBase.Packet;
		bd: BufDesc;
		i: Int;
	BEGIN

		(* setup AHB burst size to INCR16 for higher performance *)
		dev.regs.dma_cfg := S.MSK(dev.regs.dma_cfg,-DMACR_INCR16_AHB_BURST-1) + DMACR_INCR16_AHB_BURST;

		(*
			move packets from received packet buffers to the RX packet pool
		*)
		WHILE EnetBase.PacketFifoGet(dev.recvPackets0,packet) DO
			ASSERT(~packet.ownedByUser & ~packet.ownedByDev);
			ASSERT(EnetBase.PacketFifoPut(dev.rxPacketPool,packet));
		END;
		WHILE EnetBase.PacketFifoGet(dev.recvPackets,packet) DO
			ASSERT(~packet.ownedByUser & ~packet.ownedByDev);
			ASSERT(EnetBase.PacketFifoPut(dev.rxPacketPool,packet));
		END;

		ASSERT(dev.recvPackets0.count = 0);
		ASSERT(dev.recvPackets.count = 0);

		(*
			assure that all RX BDs have packets assigned
		*)
		FOR i := 0 TO LEN(dev.rxBdRing)-1 DO
			bd := dev.rxBdRing[i];
			IF bd.packet = NIL THEN
				IF EnetBase.PacketFifoGet(dev.rxPacketPool,bd.packet) THEN
					bd.packet.ownedByDev := TRUE;
				ELSE
					IF EnableTrace THEN
						Trace.StringLn("not enough packets in the RX packet pool");
					END;
					res := EnetBase.ErrRxPacketPoolEmpty;
					RETURN FALSE;
				END;
			ELSE
				ASSERT(bd.packet.ownerPool = dev.rxPacketPool);
			END;
			ASSERT(~bd.packet.ownedByUser);
			ASSERT(bd.packet.ownedByDev);
		END;

		i := LEN(dev.rxBdRing) + dev.rxPacketPool.count;
		IF i < LEN(dev.rxPacketPool.packets) THEN
			Trace.StringLn("Warning: RX packet leakage is detected, packet pool size is " & LEN(dev.rxPacketPool.packets) & " while actual number of packets is " & i);
		END;

		(*
			move packets from the TX BD packets to the owner pool (txPacketPool or rxPacketPool)
		*)
		FOR i := 0 TO LEN(dev.txBdRing)-1 DO
			bd := dev.txBdRing[i];
			IF bd.packet # NIL THEN
				bd.packet.ownedByDev := FALSE;
				ASSERT(~bd.packet.ownedByUser);
				ASSERT(EnetBase.PacketFifoPut(bd.packet.ownerPool,bd.packet));
				bd.packet := NIL;
			END;
		END;
		IF dev.txPacketPool.count < LEN(dev.txPacketPool.packets) THEN
			Trace.StringLn("Warning: TX packet leakage is detected, packet pool size is " & LEN(dev.txPacketPool.packets) & " while actual number of packets is " & dev.txPacketPool.count);
		END;

		(*
			initialize RX BDs
		*)
		FOR i := 0 TO LEN(dev.rxBdRing)-1 DO
			bd := dev.rxBdRing[i];
			SetRxBd(dev,bd,S.VAL(ADDRESS,bd.packet.ethFrameHdr));
		END;
		dev.lastRxBd := dev.rxBdRingStart;

		(*
			Initialize TX buffer descriptors
		*)
		FOR i := 0 TO LEN(dev.txBdRing)-1 DO
			SetTxBd(dev,dev.txBdRing[i],0,TXBUF_USED_MASK,FALSE);
		END;
		dev.firstTxBd := dev.txBdRingStart;
		dev.lastTxBd := dev.txBdRingStart;
		dev.txBdRingFull := FALSE;
		dev.txBdRingEmpty := TRUE;

		(* data synchronization barrier *)
		CODE
			DSB
		END;

		res := 0;
		RETURN TRUE;
	END ConfigureDma;

	(* interrupt handler common for both GEM interfaces *)
	PROCEDURE InterruptHandler(dev: LinkDevice);
	VAR intrStatus, rxStatus, txStatus, d: UInt;
	BEGIN
		intrStatus := dev.regs.intr_status;
		dev.regs.intr_status := intrStatus; (* clear interrupt status *)

		(*
			Receive complete interrupt
		*)
		IF S.MSK(intrStatus,IXR_FRAMERX_MASK) # 0 THEN
			(* Clear RX status register RX complete indication but preserve error bits if there is any *)
			dev.regs.rx_status := RXSR_FRAMERX_MASK + RXSR_BUFFNA_MASK;
			(*ReceiveCompleteHandler(dev);*)
		END;

		(*
			Transmit complete interrupt
		*)
		IF S.MSK(intrStatus,IXR_TXCOMPL_MASK) # 0 THEN
			(* Clear TX status register TX complete indication but preserve error bits if there is any *)
			dev.regs.tx_status := TXSR_TXCOMPL_MASK + TXSR_USEDREAD_MASK;
			(*TransmitCompleteHandler(dev);*)
		END;

		(*
			Receive error conditions interrupt
		*)
		IF S.MSK(intrStatus,IXR_RX_ERR_MASK) # 0 THEN

			rxStatus := dev.regs.rx_status;
			dev.regs.rx_status := rxStatus; (* clear RX status *)

			(*
				Fix for CR # 692702. Write to bit 18 of net_ctrl register to flush
				a packet out of Rx SRAM upon an error for receive buffer not available
			*)
			IF S.MSK(intrStatus,IXR_RXUSED_MASK) # 0 THEN
				dev.regs.net_ctrl := S.MSK(dev.regs.net_ctrl,-NWCTRL_FLUSH_DPRAM_MASK-1) + NWCTRL_FLUSH_DPRAM_MASK;
			ELSE
				IF S.MSK(intrStatus,IXR_RXOVR_MASK) # 0 THEN
					Trace.StringLn("RXOVR");
				ELSE
					StopController(dev); dev.isActive := FALSE;
					ShowState;
					ShowRegs;
					Trace.StringLn("Error: rx intr error, intrStatus=0x" & Trace.Hx(intrStatus,8) & ", rxStatus=0x" & Trace.Hx(rxStatus,8) & ", stopped the controller");
				END;
			END;
		END;

		(*
			Transmit error conditions interrupt

			When IXR_TXCOMPL_MASK is flaged, IXR_TXUSED_MASK will be asserted the same time.
			Have to distinguish this bit to handle the real error condition.
		*)

		IF (S.MSK(intrStatus,IXR_TX_ERR_MASK) # 0) & (S.MSK(intrStatus,IXR_TXCOMPL_MASK) = 0) THEN
			txStatus := dev.regs.tx_status;
			dev.regs.tx_status := txStatus; (* clear TX status *)

			IF (S.MSK(intrStatus,IXR_TX_ERR_MASK) = IXR_TXUSED_MASK) & (S.MSK(txStatus,TXSR_TXCOMPL_MASK) # 0) THEN
				(*Trace.StringLn("txused-ok");*)
			ELSE
				StopController(dev); dev.isActive := FALSE;
				ShowState;
				ShowRegs;
				Trace.StringLn("Error: tx intr error, intrStatus=0x" & Trace.Hx(intrStatus,8) & ", txStatus=0x" & Trace.Hx(txStatus,8) & ", stopped the controller");
			END;
		END;
	END InterruptHandler;

	(* GEM0 interrupt handler *)
	PROCEDURE InterruptHandlerGem0();
	BEGIN
		InterruptHandler(gem0);
	END InterruptHandlerGem0;

	(* GEM1 interrupt handler *)
	PROCEDURE InterruptHandlerGem1();
	BEGIN
		InterruptHandler(gem1);
	END InterruptHandlerGem1;

	PROCEDURE ReceiveCompleteHandler(dev: LinkDevice);
	BEGIN
	END ReceiveCompleteHandler;

	PROCEDURE TransmitCompleteHandler(dev: LinkDevice);
	BEGIN
	END TransmitCompleteHandler;

	(*!A workaround for a hardware bug

		The EmacPs has a hardware bug (SI# 692601) on the Rx path for heavy Rx traffic.
		Under heavy Rx traffic because of this bug there are times when the Rx path
		becomes unresponsive. The workaround for it is to check for the Rx path for
		traffic (by reading the stats registers regularly). If the stats register
		does not increment for sometime (proving no Rx traffic), the function resets the Rx data path.
	*)
	PROCEDURE ResetRxPathOnNoRxData(dev: LinkDevice);
	VAR d: UInt;
	BEGIN
		d := dev.regs.frames_rx;
		IF (d = 0) & (dev.lastRecvFrmCount = 0) THEN
			dev.regs.net_ctrl := S.MSK(dev.regs.net_ctrl,-NWCTRL_RXEN_MASK-1); (* disable the receiver *)
			dev.regs.net_ctrl := dev.regs.net_ctrl + NWCTRL_RXEN_MASK; (* enable the receiver *)
		END;
		dev.lastRecvFrmCount := d;
	END ResetRxPathOnNoRxData;

	(*
		Setup a TX buffer descriptor

		dataAddr: data address
	*)
	PROCEDURE SetRxBd(dev: LinkDevice; bd: BufDesc; dataAddr: ADDRESS);
	BEGIN
		bd.dmaBd.w1 := 0; (* clear bd stat *)
		IF bd # dev.rxBdRingEnd THEN bd.dmaBd.w0 := dataAddr;
		ELSE bd.dmaBd.w0 := dataAddr+RXBUF_WRAP_MASK; (* reached the end of the ring - tell the hardware about that by asserting the WRAP flag *)
		END;
	END SetRxBd;

	(*
		Setup a TX buffer descriptor

		dataAddr: data address
		dataLen: data length
		isLast: TRUE for setting LAST flag
	*)
	PROCEDURE SetTxBd(dev: LinkDevice; bd: BufDesc; dataAddr: ADDRESS; dataLen: UInt; isLast: BOOLEAN);
	BEGIN
		IF isLast THEN INC(dataLen,TXBUF_LAST_MASK); END;
		IF bd = dev.txBdRingEnd THEN INC(dataLen,TXBUF_WRAP_MASK);
		ELSIF bd = dev.txBdRingEnd THEN INC(dataLen,TXBUF_WRAP_MASK);
		END;
		bd.dmaBd.w0 := dataAddr;
		bd.dmaBd.w1 := dataLen;
	END SetTxBd;

	(*
		Process receive buffer descriptors
	*)
	PROCEDURE ProcessRxBds(dev: LinkDevice);
	VAR
		dataAddr: ADDRESS;
		dataLen: UInt;
		w0, w1: UInt;
		bd: BufDesc;
		t: EnetTiming.Time;
	BEGIN

		bd := dev.lastRxBd;

		w0 := bd.dmaBd.w0;
		WHILE dev.isActive & (S.MSK(w0,RXBUF_NEW_MASK) # 0) DO (* a received packet has been written to the memory and available for processing by the user *)

			(*t := EnetTiming.getTimeCounter();*)

			dataAddr := S.MSK(w0,0xFFFFFFFC); (* data address: mask out first two bits (corresponds to 4 byte alignment) *)
			w1 := bd.dmaBd.w1;
			IF w1 # 0 THEN
				(* prepare the received packet to be processed by the user *)
				bd.packet.dataLen := S.MSK(w1,RXBUF_LEN_MASK); (* received packet data length *)
				bd.packet.ownedByDev := FALSE;
				ASSERT(~bd.packet.ownedByUser);

				EnetEnvironment.InvalidateDCacheRange(S.VAL(ADDRESS,bd.packet.ethFrameHdr),bd.packet.dataLen); (* since packet data was received by DMA it is necessary to invalidate packet data cache *)
				IF EnetBase.PacketFifoPut(dev.recvPackets,bd.packet) THEN
					IF EnetBase.PacketFifoGet(dev.rxPacketPool,bd.packet) THEN
						dataAddr := S.VAL(ADDRESS,bd.packet.ethFrameHdr);
						bd.packet.ownedByDev := TRUE;
						bd.packet := bd.packet;
					ELSE
						bd.packet := NIL; (* packet was moved to dev.recvPackets *)
						StopController(dev); dev.isActive := FALSE;
						Trace.StringLn("Error: rx packet pool is empty, stopped the controller");
					END;
				ELSE
					bd.packet.ownedByDev := TRUE;
					StopController(dev); dev.isActive := FALSE;
					Trace.StringLn("Error: device internal recv packet fifo is full, stopped the controller");
				END;
			ELSE
				StopController(dev); dev.isActive := FALSE;
				Trace.StringLn("Error: rx bd stat is 0, lastRxBd=0x" & Trace.Hx(S.VAL(ADDRESS,dev.lastRxBd.dmaBd),8) & ", stopped the controller");
			END;

			SetRxBd(dev,bd,dataAddr);

			bd := bd.next;
			w0 := bd.dmaBd.w0;

			(*t := EnetTiming.getTimeCounter() - t; Trace.StringLn("receive: " & t);*)
		END;

		dev.lastRxBd := bd;

	END ProcessRxBds;

	(*
		Process packets assigned to transmit buffer descriptors, which have been already trsnamitted by the hardware
	*)
	PROCEDURE ProcessTxBds(dev: LinkDevice);
	VAR packet: EnetBase.Packet;
	BEGIN

		WHILE dev.isActive & CleanupNextTxBd(dev) DO
		END;

	END ProcessTxBds;

	(**
		Setup packet payload
	*)
	PROCEDURE SetPacketPayload*(dev: EnetBase.LinkDevice; packet: EnetBase.Packet; CONST data: ARRAY OF CHAR; offset: Int; flags: SET; VAR res: LONGINT): BOOLEAN;
	VAR payloadLen: Int;
	BEGIN
		payloadLen := packet.dataLen-packet.payloadOffs;
		ASSERT(offset+payloadLen <= LEN(data));
		IF EnetBase.FlagNoDataCopy IN flags THEN
			packet(Packet).numParts := 2;
			packet(Packet).partAddr[0] := ADDRESSOF(data[offset]);
			packet(Packet).partLen[0] := payloadLen;
		ELSE
			S.MOVE(ADDRESSOF(data[offset]),ADDRESSOF(packet.data[packet.payloadOffs+packet.dataOffs]),payloadLen);
		END;
		res := 0;
		RETURN TRUE;
	END SetPacketPayload;

	(*
		Cleanup next TX buffer descriptor released by the hardware
	*)
	PROCEDURE CleanupNextTxBd(dev: LinkDevice): BOOLEAN;
	VAR
		bd: BufDesc;
		packet: EnetBase.Packet;
	BEGIN
		bd := dev.firstTxBd;

		IF dev.txBdRingEmpty THEN RETURN FALSE; END;

		IF S.MSK(bd.dmaBd.w1,TXBUF_USED_MASK) # 0 THEN (* hardware has released the buffer descriptor *)
			IF bd.packet # NIL THEN
				packet := bd.packet;
				bd.packet := NIL;
				WITH packet : Packet DO

					WHILE packet.numParts > 1 DO (*! account for multiple packet parts *)
						bd := bd.next;
						ASSERT(S.MSK(bd.dmaBd.w1,TXBUF_USED_MASK) = 0);
						SetTxBd(dev,bd,0,TXBUF_USED_MASK,FALSE); (* set USED bit not to let the HW to process this BD *)
						DEC(packet.numParts);
					END;

					packet.ownedByDev := FALSE;

					IF EnetBase.ThreadSafe THEN packet.ownerPool.acquire; END;
					ASSERT(EnetBase.PacketFifoPut(packet.ownerPool,packet));
					IF EnetBase.ThreadSafe THEN packet.ownerPool.release; END;

					(* notify the user about the successfull packet transmission *) (*!TODO: consider to move notification to another place (e.g. putting it into a handler FIFO and executing later) *)
					IF packet.txTaskHandler # NIL THEN
						INC(packet.txTaskHandler.res);
						IF packet.txTaskHandler.handle # NIL THEN
							packet.txTaskHandler.handle(packet.txTaskHandler);
						END;
						packet.txTaskHandler := NIL;
					END;
				END;
			END;
			dev.firstTxBd := bd.next;
			dev.txBdRingFull := FALSE;
			IF dev.firstTxBd = dev.lastTxBd THEN dev.txBdRingEmpty := TRUE; END;
			RETURN TRUE;
		END;

		RETURN FALSE;
	END CleanupNextTxBd;

	(*
		Get a free (already released by the hardware) TX buffer descriptor
	*)
	PROCEDURE GetFreeTxBd(dev: LinkDevice; VAR bd: BufDesc): BOOLEAN;
	BEGIN
		bd := dev.lastTxBd;
		IF ~dev.txBdRingFull THEN
			dev.lastTxBd := bd.next;
			IF dev.lastTxBd = dev.firstTxBd THEN dev.txBdRingFull := TRUE; END;
			dev.txBdRingEmpty := FALSE;
		ELSE
			(* wait until BDs become available or timeout has expired *)
			EnetTiming.StartTimer(dev.sendTimeoutTimer);
			WHILE (S.MSK(bd.dmaBd.w1,TXBUF_USED_MASK) = 0) & ~EnetTiming.IsTimerExpired(dev.sendTimeoutTimer) DO END;
			IF CleanupNextTxBd(dev) THEN
				dev.lastTxBd := bd.next;
				IF dev.lastTxBd = dev.firstTxBd THEN dev.txBdRingFull := TRUE; END;
				dev.txBdRingEmpty := FALSE;
			ELSE
				RETURN FALSE;
			END;
		END;

		ASSERT(S.MSK(bd.dmaBd.w1,TXBUF_USED_MASK) # 0);
		ASSERT(bd.packet = NIL);
		RETURN TRUE;
	END GetFreeTxBd;

	(**
		Send a packet
	*)
	PROCEDURE SendPacket*(dev: EnetBase.LinkDevice; packet: EnetBase.Packet; flags: SET; txTaskHandler: EnetBase.TaskHandler; VAR res: ResultCode): BOOLEAN;
	VAR
		bd0, bd1: BufDesc;
		d0, d1: UInt;
		(*t: EnetTiming.Time;*)
	BEGIN
		IF ~dev.isActive THEN res := EnetBase.ErrNotActive; RETURN FALSE; END;
		(*t := EnetTiming.getTimeCounter();*)

		ASSERT(~packet.ownedByUser);

		WITH dev : LinkDevice DO

			IF ~GetFreeTxBd(dev,bd0) THEN
				Trace.StringLn("Error: no more space in TX BD ring");
				res := EnetBase.ErrOutOfResources;
				RETURN FALSE;
			END;

			IF ~(EnetBase.FlagNoDataCopy IN flags) THEN

				(*! flush data cache before committing the buffer descriptor to the hardware *)
				EnetEnvironment.FlushDCacheRange(S.VAL(ADDRESS,packet.ethFrameHdr),packet.dataLen);

				(* commit BD to the hardware *)
				SetTxBd(dev,bd0,S.VAL(ADDRESS,packet.ethFrameHdr),packet.dataLen,TRUE);
			ELSE (* send header and data using separate buffer descriptors *)

				IF ~GetFreeTxBd(dev,bd1) THEN
					Trace.StringLn("Error: no more space in TX BD ring");
					res := EnetBase.ErrOutOfResources;
					RETURN FALSE;
				END;

				(*! flush data cache before committing the buffer descriptor to the hardware *)
				EnetEnvironment.FlushDCacheRange(S.VAL(ADDRESS,packet.ethFrameHdr),packet.payloadOffs);
				IF ~(EnetBase.FlagNoFlushDCache IN flags) THEN
					EnetEnvironment.FlushDCacheRange(packet(Packet).partAddr[0],packet(Packet).partLen[0]);
				END;

				(* commit the BD to the hardware *)
				SetTxBd(dev,bd1,packet(Packet).partAddr[0],packet(Packet).partLen[0],TRUE); (* write the second BD first, so that HW does not start to transmit *)
				SetTxBd(dev,bd0,S.VAL(ADDRESS,packet.ethFrameHdr),packet.payloadOffs,FALSE);
			END;

			bd0.packet := packet;
			packet.ownedByDev := TRUE;
			packet(Packet).txTaskHandler := txTaskHandler;

			(*
				Make sure all pending memory operations get completed
			*)
			CODE
				DSB
			END;

			(* trigger packet transmission - not a problem to start it while it is still transmitting *)
			dev.regs.net_ctrl := S.MSK(dev.regs.net_ctrl,-NWCTRL_STARTTX_MASK-1) + NWCTRL_STARTTX_MASK;
		END;

		res := EnetBase.OpInProgress; (*! indicate that data has not yet been sent *)
		IF txTaskHandler # NIL THEN
			txTaskHandler.res := 0;
		END;

		(*t := EnetTiming.getTimeCounter() - t; Trace.StringLn("send: " & t);*)

		RETURN TRUE;
	END SendPacket;

	PROCEDURE NewPacket*(): EnetBase.Packet;
	VAR
		packet: Packet;
		addr: ADDRESS;
	BEGIN
		NEW(packet);
		NEW(packet.data,RX_BUF_SIZE+DataCacheLineSize);
		(*! required alignment of 4 bytes for the controller and DataCacheLineSize for the cache manipulation *)
		packet.dataOffs := DataCacheLineSize - ADDRESSOF(packet.data[0]) MOD DataCacheLineSize;
		ASSERT(ADDRESSOF(packet.data[packet.dataOffs]) MOD DataCacheLineSize = 0);
		packet.numParts := 1;
		EnetBase.InitPacket(packet);
		RETURN packet;
	END NewPacket;

	(**
		Show the state of Ethernet controller registers
	*)
	PROCEDURE ShowRegs*;
	VAR dev: LinkDevice;

		PROCEDURE ShowReg(CONST name: ARRAY OF CHAR; regAddr: ADDRESS);
		BEGIN
			Trace.StringLn(name & " (0x" & Trace.Hx(regAddr,8) & "): 0x" & Trace.Hx(S.GET32(regAddr),8));
		END ShowReg;

		PROCEDURE Show(dev: LinkDevice);
		BEGIN
			ShowReg("net_ctrl",ADDRESSOF(dev.regs.net_ctrl)); (** 0x00000000 32 mixed 0x00000000 Network Control *)
			ShowReg("net_cfg",ADDRESSOF(dev.regs.net_cfg)); (** 0x00000004 32 rw 0x00080000 Network Configuration *)
			ShowReg("net_status",ADDRESSOF(dev.regs.net_status)); (** 0x00000008 32 ro x Network Status *)
			ShowReg("dma_cfg",ADDRESSOF(dev.regs.dma_cfg)); (** 0x00000010 32 mixed 0x00020784 DMA Configuration *)
			ShowReg("tx_status",ADDRESSOF(dev.regs.tx_status)); (** 0x00000014 32 mixed 0x00000000 Transmit Status *)
			ShowReg("rx_qbar",ADDRESSOF(dev.regs.rx_qbar)); (** 0x00000018 32 mixed 0x00000000 Receive Buffer Queue Base Address *)
			ShowReg("tx_qbar",ADDRESSOF(dev.regs.tx_qbar)); (** 0x0000001C 32 mixed 0x00000000 Transmit Buffer Queue Base Address *)
			ShowReg("rx_status",ADDRESSOF(dev.regs.rx_status)); (** 0x00000020 32 mixed 0x00000000 Receive Status *)
			ShowReg("intr_status",ADDRESSOF(dev.regs.intr_status)); (** 0x00000024 32 mixed 0x00000000 Interrupt Status *)
			ShowReg("intr_en",ADDRESSOF(dev.regs.intr_en)); (** 0x00000028 32 wo x Interrupt Enable *)
			ShowReg("intr_dis",ADDRESSOF(dev.regs.intr_dis)); (** 0x0000002C 32 wo x Interrupt Disable *)
			ShowReg("intr_mask",ADDRESSOF(dev.regs.intr_mask)); (** 0x00000030 32 mixed x Interrupt Mask Status *)
			ShowReg("phy_maint",ADDRESSOF(dev.regs.phy_maint)); (** 0x00000034 32 rw 0x00000000 PHY Maintenance *)
			ShowReg("rx_pauseq",ADDRESSOF(dev.regs.rx_pauseq)); (** 0x00000038 32 ro 0x00000000 Received Pause Quantum *)
			ShowReg("tx_pauseq",ADDRESSOF(dev.regs.tx_pauseq)); (** 0x0000003C 32 rw 0x0000FFFF Transmit Pause Quantum *)
			ShowReg("hash_bot",ADDRESSOF(dev.regs.hash_bot)); (** 0x00000080 32 rw 0x00000000 Hash Register Bottom [31:0] *)
			ShowReg("hash_top",ADDRESSOF(dev.regs.hash_top)); (** 0x00000084 32 rw 0x00000000 Hash Register Top [63:32] *)
			ShowReg("spec_addr1_bot",ADDRESSOF(dev.regs.spec_addr1_bot)); (** 0x00000088 32 rw 0x00000000 Specific Address 1 Bottom [31:0] *)
			ShowReg("spec_addr1_top",ADDRESSOF(dev.regs.spec_addr1_top)); (** 0x0000008C 32 mixed 0x00000000 Specific Address 1 Top [47:32] *)
			ShowReg("spec_addr2_bot",ADDRESSOF(dev.regs.spec_addr2_bot)); (** 0x00000090 32 rw 0x00000000 Specific Address 2 Bottom [31:0] *)
			ShowReg("spec_addr2_top",ADDRESSOF(dev.regs.spec_addr2_top)); (** 0x00000094 32 mixed 0x00000000 Specific Address 2 Top [47:32] *)
			ShowReg("spec_addr3_bot",ADDRESSOF(dev.regs.spec_addr3_bot)); (** 0x00000098 32 rw 0x00000000 Specific Address 3 Bottom [31:0] *)
			ShowReg("spec_addr3_top",ADDRESSOF(dev.regs.spec_addr3_top)); (** 0x0000009C 32 mixed 0x00000000 Specific Address 3 Top [47:32] *)
			ShowReg("spec_addr4_bot",ADDRESSOF(dev.regs.spec_addr4_bot)); (** 0x000000A0 32 rw 0x00000000 Specific Address 4 Bottom [31:0] *)
			ShowReg("spec_addr4_top",ADDRESSOF(dev.regs.spec_addr4_top)); (** 0x000000A4 32 mixed 0x00000000 Specific Address 4 Top [47:32] *)
			ShowReg("type_id_match1",ADDRESSOF(dev.regs.type_id_match1)); (** 0x000000A8 32 mixed 0x00000000 Type ID Match 1 *)
			ShowReg("type_id_match2",ADDRESSOF(dev.regs.type_id_match2)); (** 0x000000AC 32 mixed 0x00000000 Type ID Match 2 *)
			ShowReg("type_id_match3",ADDRESSOF(dev.regs.type_id_match3)); (** 0x000000B0 32 mixed 0x00000000 Type ID Match 3 *)
			ShowReg("type_id_match4",ADDRESSOF(dev.regs.type_id_match4)); (** 0x000000B4 32 mixed 0x00000000 Type ID Match 4 *)
			ShowReg("wake_on_lan",ADDRESSOF(dev.regs.wake_on_lan)); (** 0x000000B8 32 mixed 0x00000000 Wake on LAN Register *)
			ShowReg("ipg_stretch",ADDRESSOF(dev.regs.ipg_stretch)); (** 0x000000BC 32 mixed 0x00000000 IPG stretch register *)
			ShowReg("stacked_vlan",ADDRESSOF(dev.regs.stacked_vlan)); (** 0x000000C0 32 mixed 0x00000000 Stacked VLAN Register *)
			ShowReg("tx_pfc_pause",ADDRESSOF(dev.regs.tx_pfc_pause)); (** 0x000000C4 32 mixed 0x00000000 Transmit PFC Pause Register *)
			ShowReg("spec_addr1_mask_bot",ADDRESSOF(dev.regs.spec_addr1_mask_bot)); (** 0x000000C8 32 rw 0x00000000 Specific Address Mask 1 Bottom [31:0] *)
			ShowReg("spec_addr1_mask_top",ADDRESSOF(dev.regs.spec_addr1_mask_top)); (** 0x000000CC 32 mixed 0x00000000 Specific Address Mask 1 Top [47:32] *)
			ShowReg("module_id",ADDRESSOF(dev.regs.module_id)); (** 0x000000FC 32 ro 0x00020118 Module ID *)
			ShowReg("octets_tx_bot",ADDRESSOF(dev.regs.octets_tx_bot)); (** 0x00000100 32 ro 0x00000000 Octets transmitted [31:0] (in frames without error) *)
			ShowReg("octets_tx_top",ADDRESSOF(dev.regs.octets_tx_top)); (** 0x00000104 32 ro 0x00000000 Octets transmitted [47:32] (in frames without error) *)
			ShowReg("frames_tx",ADDRESSOF(dev.regs.frames_tx)); (** 0x00000108 32 ro 0x00000000 Frames Transmitted *)
			ShowReg("broadcast_frames_tx",ADDRESSOF(dev.regs.broadcast_frames_tx)); (** 0x0000010C 32 ro 0x00000000 Broadcast frames Tx *)
			ShowReg("multi_frames_tx",ADDRESSOF(dev.regs.multi_frames_tx)); (* 0x00000110 32 ro 0x00000000 Multicast frames Tx *)
			ShowReg("pause_frames_tx",ADDRESSOF(dev.regs.pause_frames_tx)); (** 0x00000114 32 ro 0x00000000 Pause frames Tx *)
			ShowReg("frames_64b_tx",ADDRESSOF(dev.regs.frames_64b_tx)); (** 0x00000118 32 ro 0x00000000 Frames Tx, 64-byte length *)
			ShowReg("frames_65to127b_tx",ADDRESSOF(dev.regs.frames_65to127b_tx)); (** 0x0000011C 32 ro 0x00000000 Frames Tx, 65 to 127-byte length *)
			ShowReg("frames_128to255b_tx",ADDRESSOF(dev.regs.frames_128to255b_tx)); (** 0x00000120 32 ro 0x00000000 Frames Tx, 128 to 255-byte length *)
			ShowReg("frames_256to511b_tx",ADDRESSOF(dev.regs.frames_256to511b_tx)); (** 0x00000124 32 ro 0x00000000 Frames Tx, 256 to 511-byte length *)
			ShowReg("frames_512to1023b_tx",ADDRESSOF(dev.regs.frames_512to1023b_tx)); (** 0x00000128 32 ro 0x00000000 Frames Tx, 512 to 1023-byte length *)
			ShowReg("frames_1024to1518b_tx",ADDRESSOF(dev.regs.frames_1024to1518b_tx)); (** 0x0000012C 32 ro 0x00000000 Frame Tx, 1024 to 1518-byte length *)
			ShowReg("tx_under_runs",ADDRESSOF(dev.regs.tx_under_runs)); (** 0x00000134 32 ro 0x00000000 Transmit under runs *)
			ShowReg("single_collisn_frames",ADDRESSOF(dev.regs.single_collisn_frames)); (** 0x00000138 32 ro 0x00000000 Single Collision Frames *)
			ShowReg("multi_collisn_frames",ADDRESSOF(dev.regs.multi_collisn_frames)); (** 0x0000013C 32 ro 0x00000000 Multiple Collision Frames excessive_collisns 0x00000140 32 ro 0x00000000 Excessive Collisions *)
			ShowReg("late_collisns",ADDRESSOF(dev.regs.late_collisns)); (** 0x00000144 32 ro 0x00000000 Late Collisions *)
			ShowReg("deferred_tx_frames",ADDRESSOF(dev.regs.deferred_tx_frames)); (** 0x00000148 32 ro 0x00000000 Deferred Transmission Frames *)
			ShowReg("carrier_sense_errs",ADDRESSOF(dev.regs.carrier_sense_errs)); (** 0x0000014C 32 ro 0x00000000 Carrier Sense Errors. *)
			ShowReg("octets_rx_bot",ADDRESSOF(dev.regs.octets_rx_bot)); (** 0x00000150 32 ro 0x00000000 Octets Received [31:0] *)
			ShowReg("octets_rx_top",ADDRESSOF(dev.regs.octets_rx_top)); (** 0x00000154 32 ro 0x00000000 Octets Received [47:32] *)
			ShowReg("frames_rx",ADDRESSOF(dev.regs.frames_rx)); (** 0x00000158 32 ro 0x00000000 Frames Received *)
			ShowReg("bdcast_fames_rx",ADDRESSOF(dev.regs.bdcast_fames_rx)); (** 0x0000015C 32 ro 0x00000000 Broadcast Frames Rx *)
			ShowReg("multi_frames_rx",ADDRESSOF(dev.regs.multi_frames_rx)); (** 0x00000160 32 ro 0x00000000 Multicast Frames Rx *)
			ShowReg("pause_rx",ADDRESSOF(dev.regs.pause_rx)); (** 0x00000164 32 ro 0x00000000 Pause Frames Rx *)
			ShowReg("frames_64b_rx",ADDRESSOF(dev.regs.frames_64b_rx)); (** 0x00000168 32 ro 0x00000000 Frames Rx, 64-byte length *)
			ShowReg("frames_65to127b_rx",ADDRESSOF(dev.regs.frames_65to127b_rx)); (** 0x0000016C 32 ro 0x00000000 Frames Rx, 65 to 127-byte length *)
			ShowReg("frames_128to255b_rx",ADDRESSOF(dev.regs.frames_128to255b_rx)); (** 0x00000170 32 ro 0x00000000 Frames Rx, 128 to 255-byte length *)
			ShowReg("frames_256to511b_rx",ADDRESSOF(dev.regs.frames_256to511b_rx)); (** 0x00000174 32 ro 0x00000000 Frames Rx, 256 to 511-byte length *)
			ShowReg("frames_512to1023b_rx",ADDRESSOF(dev.regs.frames_512to1023b_rx)); (** 0x00000178 32 ro 0x00000000 Frames Rx, 512 to 1023-byte length *)
			ShowReg("frames_1024to1518b_rx",ADDRESSOF(dev.regs.frames_1024to1518b_rx)); (** 0x0000017C 32 ro 0x00000000 Frames Rx, 1024 to 1518-byte length *)
			ShowReg("undersz_rx",ADDRESSOF(dev.regs.undersz_rx)); (** 0x00000184 32 ro 0x00000000 Undersize frames received *)
			ShowReg("oversz_rx",ADDRESSOF(dev.regs.oversz_rx)); (** 0x00000188 32 ro 0x00000000 Oversize frames received *)
			ShowReg("jab_rx",ADDRESSOF(dev.regs.jab_rx)); (** 0x0000018C 32 ro 0x00000000 Jabbers received *)
			ShowReg("fcs_errors",ADDRESSOF(dev.regs.fcs_errors)); (** 0x00000190 32 ro 0x00000000 Frame check sequence errors *)
			ShowReg("length_field_errors",ADDRESSOF(dev.regs.length_field_errors)); (** 0x00000194 32 ro 0x00000000 Length field frame errors *)
			ShowReg("rx_symbol_errors",ADDRESSOF(dev.regs.rx_symbol_errors)); (** 0x00000198 32 ro 0x00000000 Receive symbol errors *)
			ShowReg("align_errors",ADDRESSOF(dev.regs.align_errors)); (** 0x0000019C 32 ro 0x00000000 Alignment errors *)
			ShowReg("rx_resource_errors",ADDRESSOF(dev.regs.rx_resource_errors)); (** 0x000001A0 32 ro 0x00000000 Receive resource errors *)
			ShowReg("rx_overrun_errors",ADDRESSOF(dev.regs.rx_overrun_errors)); (** 0x000001A4 32 ro 0x00000000 Receive overrun errors *)
			ShowReg("ip_hdr_csum_errors",ADDRESSOF(dev.regs.ip_hdr_csum_errors)); (** 0x000001A8 32 ro 0x00000000 IP header checksum errors *)
			ShowReg("tcp_csum_errors",ADDRESSOF(dev.regs.tcp_csum_errors)); (** 0x000001AC 32 ro 0x00000000 TCP checksum errors *)
			ShowReg("udp_csum_errors",ADDRESSOF(dev.regs.udp_csum_errors)); (** 0x000001B0 32 ro 0x00000000 UDP checksum error *)
			ShowReg("timer_strobe_s",ADDRESSOF(dev.regs.timer_strobe_s)); (** 0x000001C8 32 rw 0x00000000 1588 timer sync strobe seconds *)
			ShowReg("timer_strobe_ns",ADDRESSOF(dev.regs.timer_strobe_ns)); (** 0x000001CC 32 mixed 0x00000000 1588 timer sync strobe nanoseconds *)
			ShowReg("timer_s",ADDRESSOF(dev.regs.timer_s)); (** 0x000001D0 32 rw 0x00000000 1588 timer seconds *)
			ShowReg("timer_ns",ADDRESSOF(dev.regs.timer_ns)); (** 0x000001D4 32 mixed 0x00000000 1588 timer nanoseconds *)
			ShowReg("timer_adjust",ADDRESSOF(dev.regs.timer_adjust)); (** 0x000001D8 32 mixed 0x00000000 1588 timer adjust *)
			ShowReg("timer_incr",ADDRESSOF(dev.regs.timer_incr)); (** 0x000001DC 32 mixed 0x00000000 1588 timer increment *)
			ShowReg("ptp_tx_s",ADDRESSOF(dev.regs.ptp_tx_s)); (** 0x000001E0 32 ro 0x00000000 PTP event frame transmitted seconds *)
			ShowReg("ptp_tx_ns",ADDRESSOF(dev.regs.ptp_tx_ns)); (** 0x000001E4 32 ro 0x00000000 PTP event frame transmitted nanoseconds *)
			ShowReg("ptp_rx_s",ADDRESSOF(dev.regs.ptp_rx_s)); (** 0x000001E8 32 ro 0x00000000 PTP event frame received seconds *)
			ShowReg("ptp_rx_ns",ADDRESSOF(dev.regs.ptp_rx_ns)); (** 0x000001EC 32 ro 0x00000000 PTP event frame received nanoseconds. *)
			ShowReg("ptp_peer_tx_s",ADDRESSOF(dev.regs.ptp_peer_tx_s)); (** 0x000001F0 32 ro 0x00000000 PTP peer event frame transmitted seconds *)
			ShowReg("ptp_peer_tx_ns",ADDRESSOF(dev.regs.ptp_peer_tx_ns)); (** 0x000001F4 32 ro 0x00000000 PTP peer event frame transmitted nanoseconds *)
			ShowReg("ptp_peer_rx_s",ADDRESSOF(dev.regs.ptp_peer_rx_s)); (** 0x000001F8 32 ro 0x00000000 PTP peer event frame received seconds *)
			ShowReg("ptp_peer_rx_ns",ADDRESSOF(dev.regs.ptp_peer_rx_ns)); (** 0x000001FC 32 ro 0x00000000 PTP peer event frame received nanoseconds. *)
			ShowReg("design_cfg2",ADDRESSOF(dev.regs.design_cfg2)); (** 0x00000284 32 ro x Design Configuration 2 *)
			ShowReg("design_cfg3",ADDRESSOF(dev.regs.design_cfg3)); (** 0x00000288 32 ro 0x00000000 Design Configuration 3 *)
			ShowReg("design_cfg4",ADDRESSOF(dev.regs.design_cfg4)); (** 0x0000028C 32 ro 0x00000000 Design Configuration 4 *)
			ShowReg("design_cfg5",ADDRESSOF(dev.regs.design_cfg5)); (** 0x00000290 32 ro x Design Configuration 5 *)
		END Show;

	BEGIN
		IF gem0 # NIL THEN
			Trace.StringLn("");
			Trace.StringLn("GEM0 registers:");
			Show(gem0);
		END;

		IF gem1 # NIL THEN
			Trace.StringLn("");
			Trace.StringLn("GEM1 registers:");
			Show(gem1);
		END;
	END ShowRegs;

	PROCEDURE ShowState*;

		PROCEDURE Show(dev: LinkDevice);
		BEGIN
			Trace.StringLn("isActive=" & dev.isActive);
			Trace.StringLn("phyAddr=" & Trace.Hx(dev.phyAddr,2));
			Trace.StringLn("linkSpeed=" & dev.linkSpeed);
			Trace.StringLn("fullDuplex=" & dev.fullDuplex);
			Trace.StringLn("");
			Trace.StringLn("rxBdRingStart=0x" & Trace.Hx(S.VAL(ADDRESS,dev.rxBdRingStart.dmaBd),8));
			Trace.StringLn("rxBdRingEnd=0x" & Trace.Hx(S.VAL(ADDRESS,dev.rxBdRingEnd.dmaBd),8));
			Trace.StringLn("lastRxBd=0x" & Trace.Hx(S.VAL(ADDRESS,dev.lastRxBd.dmaBd),8));
			Trace.StringLn("");
			Trace.StringLn("rxPacketPool.size=" & LEN(dev.rxPacketPool.packets));
			Trace.StringLn("rxPacketPool.count=" & dev.rxPacketPool.count);
			Trace.StringLn("rxPacketPool.wrPos=" & dev.rxPacketPool.wrPos);
			Trace.StringLn("rxPacketPool.rdPos=" & dev.rxPacketPool.rdPos);
			Trace.StringLn("");
			Trace.StringLn("recvPackets.size=" & LEN(dev.recvPackets.packets));
			Trace.StringLn("recvPackets.count=" & dev.recvPackets.count);
			Trace.StringLn("recvPackets.wrPos=" & dev.recvPackets.wrPos);
			Trace.StringLn("recvPackets.rdPos=" & dev.recvPackets.rdPos);
			Trace.StringLn("");
			Trace.StringLn("txBdRingStart=0x" & Trace.Hx(S.VAL(ADDRESS,dev.txBdRingStart.dmaBd),8));
			Trace.StringLn("txBdRingEnd=0x" & Trace.Hx(S.VAL(ADDRESS,dev.txBdRingEnd.dmaBd),8));
			Trace.StringLn("firstTxBd=0x" & Trace.Hx(S.VAL(ADDRESS,dev.firstTxBd.dmaBd),8));
			Trace.StringLn("lastTxBd=0x" & Trace.Hx(S.VAL(ADDRESS,dev.lastTxBd.dmaBd),8));
			Trace.StringLn("txBdRingFull=" & dev.txBdRingFull);
			Trace.StringLn("txBdRingEmpty=" & dev.txBdRingEmpty);
			Trace.StringLn("");
			Trace.StringLn("txPacketPool.size=" & LEN(dev.txPacketPool.packets));
			Trace.StringLn("txPacketPool.count=" & dev.txPacketPool.count);
			Trace.StringLn("txPacketPool.wrPos=" & dev.txPacketPool.wrPos);
			Trace.StringLn("txPacketPool.rdPos=" & dev.txPacketPool.rdPos);
		END Show;

	BEGIN
		IF gem0 # NIL THEN
			Trace.StringLn("");
			Trace.StringLn("GEM0 link device state:");
			Show(gem0);
		END;

		IF gem1 # NIL THEN
			Trace.StringLn("");
			Trace.StringLn("GEM1 link device state:");
			Show(gem1);
		END;
	END ShowState;
(*
	(**
		Show the content of a buffer descriptor

		syntax

		ShowRxBd gemId bdType bdAddr

		where

		gemId: GEM controller ID (0 or 1)
		bdType: type of the buffer descriptor ("rx" or "tx")
		bdAddr: buffer descriptor address
	*)
	PROCEDURE ShowBd*(context: Commands.Context);
	VAR
		gemId, addr: Int;
		bdType: ARRAY 8 OF CHAR;
		bdAddr: ADDRESS;
		dev: LinkDevice;
	BEGIN
		IF ~context.arg.GetInteger(gemId,FALSE) OR ~context.arg.GetString(bdType) OR ~context.arg.GetInteger(addr,TRUE) THEN
			context.error.String('GEM controller ID (0 or 1), buffer descriptor type ("rx" or "tx") and buffer descriptor address are required');
			context.result := 1;
			RETURN;
		END;

		IF (gemId < 0) OR (gemId > 1) THEN
			context.error.String("invalid GEM controller ID (0 or 1)");
			context.result := 1;
			RETURN;
		END;

		IF (bdType # "rx") & (bdType # "tx") THEN
			context.error.String('invalid buffer descriptor type ("rx" or "tx")');
			context.result := 1;
			RETURN;
		END;

		IF gemId = 0 THEN dev := gem0; ELSE dev := gem1; END;

		bdAddr := addr;
		IF (bdAddr < S.VAL(ADDRESS,dev.rxBdRingStart.dmaBd)) OR (bdAddr > S.VAL(ADDRESS,dev.rxBdRingEnd.dmaBd)) OR (bdAddr MOD SIZEOF(DmaBufDesc) # 0) THEN
			context.error.String("invalid buffer descriptor address");
			context.result := 1;
			RETURN;
		END;

		Trace.StringLn("BD dword0=0x" & Trace.Hx(S.GET32(bdAddr+BD_ADDR_OFFSET),8));
		Trace.StringLn("BD dword1=0x" & Trace.Hx(S.GET32(bdAddr+BD_STAT_OFFSET),8));
	END ShowBd;
*)
	PROCEDURE InitMod;
	BEGIN

	END InitMod;

BEGIN
	ASSERT(SIZEOF(EnetBase.UInt) = 4);
	InitMod;
END EnetEmacPs7.
