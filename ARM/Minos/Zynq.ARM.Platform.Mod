MODULE Platform;
(** Zynq platform-specific constants for A2.
	Author: Timothee Martiel
*)

CONST
	(* ===== Units ===== *)
	k *		= 1024;
	M *	= k * k;
	G *		= k * k * k;

	(* Maximum number of CPUs for that platform *)
	MaxCpuNb * = 2;

	(* ===== Physical Memory Layout ===== *)
	DDRStart * = 0;
	OCMStart * = 0;
	OCMSize * = 192 * k;
	IOStart * = 1 * G;
	IOSize * = 3040 * M;

	(* ===== Registers ===== *)
	MpcoreBaseAdr* = ADDRESS(0F8F00000H);
	ICDDCR* = MpcoreBaseAdr + 1000H; (* distributor control register *)
	ICDICFR* = MpcoreBaseAdr + 1C00H; (* interrupt configuration register *)
	ICCICR* = MpcoreBaseAdr + 0100H;  (* cpu interface control register *)
	ICCPMR* = MpcoreBaseAdr + 0104H; (* interrupt priority mask register *)
	ICCEOIR* = MpcoreBaseAdr + 0110H; (* end of interrupt register *)
	ICDIPTR* = MpcoreBaseAdr + 1800H; (* interrupt processor target registers *)
	ICDIPR* =   MpcoreBaseAdr + 1400H; (* interrupt priority registers *)
	ICDICER* =  MpcoreBaseAdr + 1180H; (* interrupt clear enable register *)
	ICDISER* = MpcoreBaseAdr + 1100H; (* interrupt set enable register *)
	ICDISPR* = MpcoreBaseAdr + 1200H; (* set pending register *)
	ICDICPR* = MpcoreBaseAdr + 1280H; (* clear pending register *)
	ICCIAR* = MpcoreBaseAdr + 10CH; (* Interrupt Ackknowledge Register *)
	ICCBPR* = MpcoreBaseAdr + 108H; (* Binary Point Register *)
	GlobalTimerCounterRegister0* = MpcoreBaseAdr + 200H;
	GlobalTimerCounterRegister1* = MpcoreBaseAdr + 204H;
	GlobalTimerControlRegister* = MpcoreBaseAdr + 208H;
	GlobalTimerInterruptStatusRegister* = MpcoreBaseAdr+ 20CH;
	ComparatorValueRegister0* = MpcoreBaseAdr + 210H;
	ComparatorValueRegister1* = MpcoreBaseAdr + 214H;
	AutoIncrementRegister* = MpcoreBaseAdr + 218H;

	PrivateLoadValueRegister* = MpcoreBaseAdr + 600H;
	PrivateTimerCounterRegister* = MpcoreBaseAdr + 604H;
	PrivateTimerControlRegister* = MpcoreBaseAdr + 608H;
	PrivateTimerInterruptStatusRegister* = MpcoreBaseAdr+ 60CH;

	SCUControlReg* = MpcoreBaseAdr;

	(* Interrupt constants *)
	(*! TODO: USEFUL? *)
	ICIP* = (* TODO *) 0H;
	ICMR* = (* TODO *) 0H;
	ICLR* = (* TODO *) 0H;
	InterruptVectors* = 0H;
	FIQMode* 		= 11H;   (* Fast Interrupt Mode *)
	IRQMode* 		= 12H;   (* Interrupt Mode *)
	SVCMode* 		= 13H;   (* SuperVisorMode *)
	UndefMode*	= 1BH;   (* Undefined instruction mode *)
	UserMode* 		= 10H;   (* User mode *)
	AbortMode* 	= 17H;   (* Abort mode *)
	SystemMode*	= 1FH;
	(* Exceptions *)
	FIQDisabled* 	= 40H;   (* Fast interrupts disabled globally *)
	IRQDisabled* 	= 80H;   (* Interrupts disabled globally *)
	
	(* ===== System Level Control register access ===== *)
	SlcrBaseAdr* = 0xF8000000; (** Base address for System Level Control (SLCR) registers *)
	SlcrLockKey* = 0x767B; (** SLCR lock key; write this value to SLCR_LOCK register to disable writing to SLCR registers *)
	SlcrUnlockKey* = 0xDF0D; (** SLCR unlock key; write this value to SLCR_UNLOCK register to enable writing to SLCR registers *)

	(* ===== Device Configuration registers ===== *)
	DevCfgBaseAdr * = 0F8007000H;		(** Base address of the devcfg registers *)
	DevCfgDmaPlAdr * = ADDRESS(0FFFFFFFFH);	(** Devcfg DMA address of the PL *)

	(* ===== AXI interfaces ===== *)
	MasterAxiGp0BaseAdr* = 07F000000H; (** base address for Master AXI General Purpose interface 0 *)
	MasterAxiGp1BaseAdr* = 0BF000000H; (** base address for Master AXI General Purpose interface 1 *)

	(* ===== GPIO Registers ===== *)
	GpioBase * = ADDRESS(0E000A000H); (** Base address of GPIO registers *)
	GpioData * = GpioBase + 40H; (** Base address of GPIO data registers *)
	GpioBankNb * = 4; (** Number of GPIO banks *)
	GpioBank * = [GpioBase + 204H, GpioBase + 244H, GpioBase + 284H, GpioBase + 2C4H]; (** Base address of GPIO bank control registers *)

	(* ===== UART ===== *)
	UartBaseAddr* = [ADDRESS(0E0000000H),ADDRESS(0E0001000H)]; (* base address for all UART controllers present in the system *)
	UartModemPinsConnected* = [FALSE,FALSE];
	
	(* ===== QSPI ===== *)
	QspiBase* = [ADDRESS(0xE000D000)];

	(* ===== USB ===== *)
	UsbNb * = 2; (** Number of USB controllers *)
	UsbBase * = [ADDRESS(0E0002100H), ADDRESS(0E0003100H)]; (** Base addresses of USB controllers: CAPLENGTH must be at offset 0. *)
	UsbIrq * = [53, 76]; (** USB IRQs *)

TYPE
	
	(** System Level Control (SLCR) registers definition *)
	SlcrRegisters* = POINTER{UNSAFE,UNTRACED} TO RECORD
		SCL*: SIGNED32; (** 0x00000000 32 rw 0x00000000 Secure Configuration Lock *)
		SLCR_LOCK*: SIGNED32; (** 0x00000004 32 wo 0x00000000 SLCR Write Protection Lock *)
		SLCR_UNLOCK*: SIGNED32; (** 0x00000008 32 wo 0x00000000 SLCR Write Protection Unlock *)
		SLCR_LOCKSTA-: SIGNED32; (** 0x0000000C 32 ro 0x00000001 SLCR Write Protection Status *)
		padding0: ARRAY 60 OF SIGNED32;
		ARM_PLL_CTRL*: SIGNED32; (** 0x00000100 32 rw 0x0001A008 ARM PLL Control *)
		DDR_PLL_CTRL*: SIGNED32; (** 0x00000104 32 rw 0x0001A008 DDR PLL Control *)
		IO_PLL_CTRL*: SIGNED32; (** 0x00000108 32 rw 0x0001A008 IO PLL Control *)
		PLL_STATUS-: SIGNED32; (** 0x0000010C 32 ro 0x0000003F PLL Status *)
		ARM_PLL_CFG*: SIGNED32; (** 0x00000110 32 rw 0x00177EA0 ARM PLL Configuration *)
		DDR_PLL_CFG*: SIGNED32; (** 0x00000114 32 rw 0x00177EA0 DDR PLL Configuration *)
		IO_PLL_CFG*: SIGNED32; (** 0x00000118 32 rw 0x00177EA0 IO PLL Configuration *)
		padding01: SIGNED32;
		ARM_CLK_CTRL*: SIGNED32; (** 0x00000120 32 rw 0x1F000400 CPU Clock Control *)
		DDR_CLK_CTRL*: SIGNED32; (** 0x00000124 32 rw 0x18400003 DDR Clock Control *)
		DCI_CLK_CTRL*: SIGNED32; (** 0x00000128 32 rw 0x01E03201 DCI clock control *)
		APER_CLK_CTRL*: SIGNED32; (** 0x0000012C 32 rw 0x01FFCCCD AMBA Peripheral Clock Control *)
		USB0_CLK_CTRL*: SIGNED32; (** 0x00000130 32 rw 0x00101941 USB 0 ULPI Clock Control *)
		USB1_CLK_CTRL*: SIGNED32; (** 0x00000134 32 rw 0x00101941 USB 1 ULPI Clock Control *)
		GEM0_RCLK_CTRL*: SIGNED32; (** 0x00000138 32 rw 0x00000001 GigE 0 Rx Clock and Rx Signals Select *)
		GEM1_RCLK_CTRL*: SIGNED32; (** 0x0000013C 32 rw 0x00000001 GigE 1 Rx Clock and Rx Signals Select *)
		GEM0_CLK_CTRL*: SIGNED32; (** 0x00000140 32 rw 0x00003C01 GigE 0 Ref Clock Control *)
		GEM1_CLK_CTRL*: SIGNED32; (** 0x00000144 32 rw 0x00003C01 GigE 1 Ref Clock Control *)
		SMC_CLK_CTRL*: SIGNED32; (** 0x00000148 32 rw 0x00003C21 SMC Ref Clock Control *)
		LQSPI_CLK_CTRL*: SIGNED32; (** 0x0000014C 32 rw 0x00002821 Quad SPI Ref Clock Control *)
		SDIO_CLK_CTRL*: SIGNED32; (** 0x00000150 32 rw 0x00001E03 SDIO Ref Clock Control *)
		UART_CLK_CTRL*: SIGNED32; (** 0x00000154 32 rw 0x00003F03 UART Ref Clock Control *)
		SPI_CLK_CTRL*: SIGNED32; (** 0x00000158 32 rw 0x00003F03 SPI Ref Clock Control *)
		CAN_CLK_CTRL*: SIGNED32; (** 0x0000015C 32 rw 0x00501903 CAN Ref Clock Control *)
		CAN_MIOCLK_CTRL*: SIGNED32; (** 0x00000160 32 rw 0x00000000 CAN MIO Clock Control *)
		DBG_CLK_CTRL*: SIGNED32; (** 0x00000164 32 rw 0x00000F03 SoC Debug Clock Control *)
		PCAP_CLK_CTRL*: SIGNED32; (** 0x00000168 32 rw 0x00000F01 PCAP Clock Control *)
		TOPSW_CLK_CTRL*: SIGNED32; (** 0x0000016C 32 rw 0x00000000 Central Interconnect Clock Control *)
		FPGA0_CLK_CTRL*: SIGNED32; (** 0x00000170 32 rw 0x00101800 PL Clock 0 Output control *)
		FPGA0_THR_CTRL*: SIGNED32; (** 0x00000174 32 rw 0x00000000 PL Clock 0 Throttle control *)
		FPGA0_THR_CNT*: SIGNED32; (** 0x00000178 32 rw 0x00000000 PL Clock 0 Throttle Count control *)
		FPGA0_THR_STA-: SIGNED32; (** 0x0000017C 32 ro 0x00010000 PL Clock 0 Throttle Status read *)
		FPGA1_CLK_CTRL*: SIGNED32; (** 0x00000180 32 rw 0x00101800 PL Clock 1 Output control *)
		FPGA1_THR_CTRL*: SIGNED32; (** 0x00000184 32 rw 0x00000000 PL Clock 1 Throttle control *)
		FPGA1_THR_CNT*: SIGNED32; (** 0x00000188 32 rw 0x00000000 PL Clock 1 Throttle Count *)
		FPGA1_THR_STA-: SIGNED32; (** 0x0000018C 32 ro 0x00010000 PL Clock 1 Throttle Status control *)
		FPGA2_CLK_CTRL*: SIGNED32; (** 0x00000190 32 rw 0x00101800 PL Clock 2 output control *)
		FPGA2_THR_CTRL*: SIGNED32; (** 0x00000194 32 rw 0x00000000 PL Clock 2 Throttle Control *)
		FPGA2_THR_CNT*: SIGNED32; (** 0x00000198 32 rw 0x00000000 PL Clock 2 Throttle Count *)
		FPGA2_THR_STA-: SIGNED32; (** 0x0000019C 32 ro 0x00010000 PL Clock 2 Throttle Status *)
		FPGA3_CLK_CTRL*: SIGNED32; (** 0x000001A0 32 rw 0x00101800 PL Clock 3 output control *)
		FPGA3_THR_CTRL*: SIGNED32; (** 0x000001A4 32 rw 0x00000000 PL Clock 3 Throttle Control *)
		FPGA3_THR_CNT*: SIGNED32; (** 0x000001A8 32 rw 0x00000000 PL Clock 3 Throttle Count *)
		FPGA3_THR_STA-: SIGNED32; (** 0x000001AC 32 ro 0x00010000 PL Clock 3 Throttle Status *)
		padding1: ARRAY 5 OF SIGNED32;
		CLK_621_TRUE*: SIGNED32; (** 0x000001C4 32 rw 0x00000001 CPU Clock Ratio Mode select *)
		padding2: ARRAY 14 OF SIGNED32;
		PSS_RST_CTRL*: SIGNED32; (** 0x00000200 32 rw 0x00000000 PS Software Reset Control *)
		DDR_RST_CTRL*: SIGNED32; (** 0x00000204 32 rw 0x00000000 DDR Software Reset Control *)
		TOPSW_RST_CTRL*: SIGNED32; (** 0x00000208 32 rw 0x00000000 Central Interconnect Reset Control *)
		DMAC_RST_CTRL*: SIGNED32; (** 0x0000020C 32 rw 0x00000000 DMAC Software Reset Control *)
		USB_RST_CTRL*: SIGNED32; (** 0x00000210 32 rw 0x00000000 USB Software Reset Control *)
		GEM_RST_CTRL*: SIGNED32; (** 0x00000214 32 rw 0x00000000 Gigabit Ethernet SW Reset Control *)
		SDIO_RST_CTRL*: SIGNED32; (** 0x00000218 32 rw 0x00000000 SDIO Software Reset Control *)
		SPI_RST_CTRL*: SIGNED32; (** 0x0000021C 32 rw 0x00000000 SPI Software Reset Control *)
		CAN_RST_CTRL*: SIGNED32; (** 0x00000220 32 rw 0x00000000 CAN Software Reset Control *)
		I2C_RST_CTRL*: SIGNED32; (** 0x00000224 32 rw 0x00000000 I2C Software Reset Control *)
		UART_RST_CTRL*: SIGNED32; (** 0x00000228 32 rw 0x00000000 UART Software Reset Control *)
		GPIO_RST_CTRL*: SIGNED32; (** 0x0000022C 32 rw 0x00000000 GPIO Software Reset Control *)
		LQSPI_RST_CTRL*: SIGNED32; (** 0x00000230 32 rw 0x00000000 Quad SPI Software Reset Control *)
		SMC_RST_CTRL*: SIGNED32; (** 0x00000234 32 rw 0x00000000 SMC Software Reset Control *)
		OCM_RST_CTRL*: SIGNED32; (** 0x00000238 32 rw 0x00000000 OCM Software Reset Control *)
		padding3: SIGNED32;
		FPGA_RST_CTRL*: SET; (** 0x00000240 32 rw 0x01F33F0F FPGA Software Reset Control *)
		A9_CPU_RST_CTRL*: SIGNED32; (** 0x00000244 32 rw 0x00000000 CPU Reset and Clock control *)
		padding4: SIGNED32;
		RS_AWDT_CTRL*: SIGNED32; (** 0x0000024C 32 rw 0x00000000 Watchdog Timer Reset Control *)
		padding5: ARRAY 2 OF SIGNED32;
		REBOOT_STATUS*: SIGNED32; (** 0x00000258 32 rw 0x00400000 Reboot Status, persistent *)
		BOOT_MODE*: SIGNED32; (** 0x0000025C 32 mixed x Boot Mode Strapping Pins *)
		padding6: ARRAY 40 OF SIGNED32;
		APU_CTRL*: SIGNED32; (** 0x00000300 32 rw 0x00000000 APU Control *)
		WDT_CLK_SEL*: SIGNED32; (** 0x00000304 32 rw 0x00000000 SWDT clock source select *)
		padding7: ARRAY 78 OF SIGNED32;
		TZ_DMA_NS*: SIGNED32; (** 0x00000440 32 rw 0x00000000 DMAC TrustZone Config *)
		TZ_DMA_IRQ_NS*: SIGNED32; (** 0x00000444 32 rw 0x00000000 DMAC TrustZone Config for Interrupts *)
		TZ_DMA_PERIPH_NS*: SIGNED32; (** 0x00000448 32 rw 0x00000000 DMAC TrustZone Config for Peripherals *)
		padding8: ARRAY 57 OF SIGNED32;
		PSS_IDCODE-: SIGNED32; (** 0x00000530 32 ro x PS IDCODE *)
		padding9: ARRAY 51 OF SIGNED32;
		DDR_URGENT*: SIGNED32; (** 0x00000600 32 rw 0x00000000 DDR Urgent Control *)
		padding10: ARRAY 2 OF SIGNED32;
		DDR_CAL_START*: SIGNED32; (** 0x0000060C 32 mixed 0x00000000 DDR Calibration Start Triggers *)
		padding11: SIGNED32;
		DDR_REF_START*: SIGNED32; (** 0x00000614 32 mixed 0x00000000 DDR Refresh Start Triggers *)
		DDR_CMD_STA*: SIGNED32; (** 0x00000618 32 mixed 0x00000000 DDR Command Store Status *)
		DDR_URGENT_SEL*: SIGNED32; (** 0x0000061C 32 rw 0x00000000 DDR Urgent Select *)
		DDR_DFI_STATUS*: SIGNED32; (** 0x00000620 32 mixed 0x00000000 DDR DFI status *)
		padding12: ARRAY 55 OF SIGNED32;
		MIO_PIN_00*: SIGNED32; (** 0x00000700 32 rw 0x00001601 MIO Pin 0 Control *)
		MIO_PIN_01*: SIGNED32; (** 0x00000704 32 rw 0x00001601 MIO Pin 1 Control *)
		MIO_PIN_02*: SIGNED32; (** 0x00000708 32 rw 0x00000601 MIO Pin 2 Control *)
		MIO_PIN_03*: SIGNED32; (** 0x0000070C 32 rw 0x00000601 MIO Pin 3 Control *)
		MIO_PIN_04*: SIGNED32; (** 0x00000710 32 rw 0x00000601 MIO Pin 4 Control *)
		MIO_PIN_05*: SIGNED32; (** 0x00000714 32 rw 0x00000601 MIO Pin 5 Control *)
		MIO_PIN_06*: SIGNED32; (** 0x00000718 32 rw 0x00000601 MIO Pin 6 Control *)
		MIO_PIN_07*: SIGNED32; (** 0x0000071C 32 rw 0x00000601 MIO Pin 7 Control *)
		MIO_PIN_08*: SIGNED32; (** 0x00000720 32 rw 0x00000601 MIO Pin 8 Control *)
		MIO_PIN_09*: SIGNED32; (** 0x00000724 32 rw 0x00001601 MIO Pin 9 Control *)
		MIO_PIN_10*: SIGNED32; (** 0x00000728 32 rw 0x00001601 MIO Pin 10 Control *)
		MIO_PIN_11*: SIGNED32; (** 0x0000072C 32 rw 0x00001601 MIO Pin 11 Control *)
		MIO_PIN_12*: SIGNED32; (** 0x00000730 32 rw 0x00001601 MIO Pin 12 Control *)
		MIO_PIN_13*: SIGNED32; (** 0x00000734 32 rw 0x00001601 MIO Pin 13 Control *)
		MIO_PIN_14*: SIGNED32; (** 0x00000738 32 rw 0x00001601 MIO Pin 14 Control *)
		MIO_PIN_15*: SIGNED32; (** 0x0000073C 32 rw 0x00001601 MIO Pin 15 Control *)
		MIO_PIN_16*: SIGNED32; (** 0x00000740 32 rw 0x00001601 MIO Pin 16 Control *)
		MIO_PIN_17*: SIGNED32; (** 0x00000744 32 rw 0x00001601 MIO Pin 17 Control *)
		MIO_PIN_18*: SIGNED32; (** 0x00000748 32 rw 0x00001601 MIO Pin 18 Control *)
		MIO_PIN_19*: SIGNED32; (** 0x0000074C 32 rw 0x00001601 MIO Pin 19 Control *)
		MIO_PIN_20*: SIGNED32; (** 0x00000750 32 rw 0x00001601 MIO Pin 20 Control *)
		MIO_PIN_21*: SIGNED32; (** 0x00000754 32 rw 0x00001601 MIO Pin 21 Control *)
		MIO_PIN_22*: SIGNED32; (** 0x00000758 32 rw 0x00001601 MIO Pin 22 Control *)
		MIO_PIN_23*: SIGNED32; (** 0x0000075C 32 rw 0x00001601 MIO Pin 23 Control *)
		MIO_PIN_24*: SIGNED32; (** 0x00000760 32 rw 0x00001601 MIO Pin 24 Control *)
		MIO_PIN_25*: SIGNED32; (** 0x00000764 32 rw 0x00001601 MIO Pin 25 Control *)
		MIO_PIN_26*: SIGNED32; (** 0x00000768 32 rw 0x00001601 MIO Pin 26 Control *)
		MIO_PIN_27*: SIGNED32; (** 0x0000076C 32 rw 0x00001601 MIO Pin 27 Control *)
		MIO_PIN_28*: SIGNED32; (** 0x00000770 32 rw 0x00001601 MIO Pin 28 Control *)
		MIO_PIN_29*: SIGNED32; (** 0x00000774 32 rw 0x00001601 MIO Pin 29 Control *)
		MIO_PIN_30*: SIGNED32; (** 0x00000778 32 rw 0x00001601 MIO Pin 30 Control *)
		MIO_PIN_31*: SIGNED32; (** 0x0000077C 32 rw 0x00001601 MIO Pin 31 Control *)
		MIO_PIN_32*: SIGNED32; (** 0x00000780 32 rw 0x00001601 MIO Pin 32 Control *)
		MIO_PIN_33*: SIGNED32; (** 0x00000784 32 rw 0x00001601 MIO Pin 33 Control *)
		MIO_PIN_34*: SIGNED32; (** 0x00000788 32 rw 0x00001601 MIO Pin 34 Control *)
		MIO_PIN_35*: SIGNED32; (** 0x0000078C 32 rw 0x00001601 MIO Pin 35 Control *)
		MIO_PIN_36*: SIGNED32; (** 0x00000790 32 rw 0x00001601 MIO Pin 36 Control *)
		MIO_PIN_37*: SIGNED32; (** 0x00000794 32 rw 0x00001601 MIO Pin 37 Control *)
		MIO_PIN_38*: SIGNED32; (** 0x00000798 32 rw 0x00001601 MIO Pin 38 Control *)
		MIO_PIN_39*: SIGNED32; (** 0x0000079C 32 rw 0x00001601 MIO Pin 39 Control *)
		MIO_PIN_40*: SIGNED32; (** 0x000007A0 32 rw 0x00001601 MIO Pin 40 Control *)
		MIO_PIN_41*: SIGNED32; (** 0x000007A4 32 rw 0x00001601 MIO Pin 41 Control *)
		MIO_PIN_42*: SIGNED32; (** 0x000007A8 32 rw 0x00001601 MIO Pin 42 Control *)
		MIO_PIN_43*: SIGNED32; (** 0x000007AC 32 rw 0x00001601 MIO Pin 43 Control *)
		MIO_PIN_44*: SIGNED32; (** 0x000007B0 32 rw 0x00001601 MIO Pin 44 Control *)
		MIO_PIN_45*: SIGNED32; (** 0x000007B4 32 rw 0x00001601 MIO Pin 45 Control *)
		MIO_PIN_46*: SIGNED32; (** 0x000007B8 32 rw 0x00001601 MIO Pin 46 Control *)
		MIO_PIN_47*: SIGNED32; (** 0x000007BC 32 rw 0x00001601 MIO Pin 47 Control *)
		MIO_PIN_48*: SIGNED32; (** 0x000007C0 32 rw 0x00001601 MIO Pin 48 Control *)
		MIO_PIN_49*: SIGNED32; (** 0x000007C4 32 rw 0x00001601 MIO Pin 49 Control *)
		MIO_PIN_50*: SIGNED32; (** 0x000007C8 32 rw 0x00001601 MIO Pin 50 Control *)
		MIO_PIN_51*: SIGNED32; (** 0x000007CC 32 rw 0x00001601 MIO Pin 51 Control *)
		MIO_PIN_52*: SIGNED32; (** 0x000007D0 32 rw 0x00001601 MIO Pin 52 Control *)
		MIO_PIN_53*: SIGNED32; (** 0x000007D4 32 rw 0x00001601 MIO Pin 53 Control *)
		padding13: ARRAY 11 OF SIGNED32;
		MIO_LOOPBACK*: SIGNED32; (** 0x00000804 32 rw 0x00000000 Loopback function within MIO *)
		padding14: SIGNED32;
		MIO_MST_TRI0*: SIGNED32; (** 0x0000080C 32 rw 0xFFFFFFFF MIO pin Tri-state Enables, 31:0 *)
		MIO_MST_TRI1*: SIGNED32; (** 0x00000810 32 rw 0x003FFFFF MIO pin Tri-state Enables, 53:32 *)
		padding15: ARRAY 7 OF SIGNED32;
		SD0_WP_CD_SEL*: SIGNED32; (** 0x00000830 32 rw 0x00000000 SDIO 0 WP CD select *)
		SD1_WP_CD_SEL*: SIGNED32; (** 0x00000834 32 rw 0x00000000 SDIO 1 WP CD select *)
		padding16: ARRAY 50 OF SIGNED32;
		LVL_SHFTR_EN*: SIGNED32; (** 0x00000900 32 rw 0x00000000 Level Shifters Enable *)
		padding17: ARRAY 3 OF SIGNED32;
		OCM_CFG*: SIGNED32; (** 0x00000910 32 rw 0x00000000 OCM Address Mapping *)
		padding18: ARRAY 66 OF SIGNED32;
		Reserved*: SIGNED32; (** 0x00000A1C 32 rw 0x00010101 Reserved *)
		padding19: ARRAY 56 OF SIGNED32;
		GPIOB_CTRL*: SIGNED32; (** 0x00000B00 32 rw 0x00000000 PS IO Buffer Control *)
		GPIOB_CFG_CMOS18*: SIGNED32; (** 0x00000B04 32 rw 0x00000000 MIO GPIOB CMOS 1.8V config *)
		GPIOB_CFG_CMOS25*: SIGNED32; (** 0x00000B08 32 rw 0x00000000 MIO GPIOB CMOS 2.5V config *)
		GPIOB_CFG_CMOS33*: SIGNED32; (** 0x00000B0C 32 rw 0x00000000 MIO GPIOB CMOS 3.3V config *)
		padding20: SIGNED32;
		GPIOB_CFG_HSTL*: SIGNED32; (** 0x00000B14 32 rw 0x00000000 MIO GPIOB HSTL config *)
		GPIOB_DRVR_BIAS_CTRL*: SIGNED32; (** 0x00000B18 32 mixed 0x00000000 MIO GPIOB Driver Bias Control *)
		padding21: ARRAY 9 OF SIGNED32;
		DDRIOB_ADDR0*: SIGNED32; (** 0x00000B40 32 rw 0x00000800 DDR IOB Config for A[14:0], CKE and DRST_B *)
		DDRIOB_ADDR1*: SIGNED32; (** 0x00000B44 32 rw 0x00000800 DDR IOB Config for BA[2:0], ODT, CS_B, WE_B, RAS_B and CAS_B *)
		DDRIOB_DATA0*: SIGNED32; (** 0x00000B48 32 rw 0x00000800 DDR IOB Config for Data 15:0 *)
		DDRIOB_DATA1*: SIGNED32; (** 0x00000B4C 32 rw 0x00000800 DDR IOB Config for Data 31:16 *)
		DDRIOB_DIFF0*: SIGNED32; (** 0x00000B50 32 rw 0x00000800 DDR IOB Config for DQS 1:0 *)
		DDRIOB_DIFF1*: SIGNED32; (** 0x00000B54 32 rw 0x00000800 DDR IOB Config for DQS 3:2 *)
		DDRIOB_CLOCK*: SIGNED32; (** 0x00000B58 32 rw 0x00000800 DDR IOB Config for Clock Output *)
		DDRIOB_DRIVE_SLEW_ADDR*: SIGNED32; (** 0x00000B5C 32 rw 0x00000000 Drive and Slew controls for Address and Command pins of the DDR Interface *)
		DDRIOB_DRIVE_SLEW_DATA*: SIGNED32; (** 0x00000B60 32 rw 0x00000000 Drive and Slew controls for DQ pins of the DDR Interface *)
		DDRIOB_DRIVE_SLEW_DIFF*: SIGNED32; (** 0x00000B64 32 rw 0x00000000 Drive and Slew controls for DQS pins of the DDR Interface *)
		DDRIOB_DRIVE_SLEW_CLOCK*: SIGNED32; (** 0x00000B68 32 rw 0x00000000 Drive and Slew controls for Clock pins of the DDR Interface *)
		DDRIOB_DDR_CTRL*: SIGNED32; (** 0x00000B6C 32 rw 0x00000000 DDR IOB Buffer Control *)
		DDRIOB_DCI_CTRL*: SIGNED32; (** 0x00000B70 32 rw 0x00000020 DDR IOB DCI Config *)
		DDRIOB_DCI_STATUS*: SIGNED32; (** 0x00000B74 32 mixed 0x00000000 DDR IO Buffer DCI Status *)
	END;

	(** Device Configuration (Devcfg) register definitions *)
	DevCfgRegisters * = POINTER {UNSAFE,UNTRACED} TO RECORD
		CTRL *,								(** 000H 32 mixed 0C006000H Control Register *)
		LOCK *,								(** 004H 32 mixed 00000000H Lock Register *)
		CFG *,									(** 008H 32 rw 00000508H Configuration Register *)
		INT_STS *,								(** 00CH 32 mixed 00000000H Interrupt Status Register *)
		INT_MASK *,							(** 010H 32 rw FFFFFFFFH Interrupt Mask Register *)
		STATUS *,								(** 014H 32 mixed 40000820H Status Register *)
		DMA_SRC_ADDR *,						(** 018H 32 rw 00000000H DMA Source Address Register *)
		DMA_DST_ADDR *,					(** 01CH 32 rw 00000000H DMA Destination Address Register *)
		DMA_SRC_LEN *,						(** 020H 32 rw 00000000H DMA Source Transfer Length *)
		DMA_DST_LEN *,						(** 024H 32 rw 00000000H DMA Destination Transfer Length *)
		ROM_SHADOW *,						(** 028H 32 wo 00000000H ROM Shadow Register *)
		MULTIBOOT_ADDR *,					(** 02CH 32 rw 00000000H MULTI Boot Address Pointer *)
		SW_ID *,								(** 030H 32 mixed 00000000H Software ID Register *)
		UNLOCK *: SIGNED32;				(** 034H 32 rw 00000000 Unlock Register *)
		padding0: ARRAY 19 OF SIGNED32;	(** padding: 038H to 080H *)
		MCTRL *: SIGNED32;					(** 080H 32 mixed xxxxxxxxH Miscellanous Control Register *)
		padding1: ARRAY 32 OF SIGNED32;	(** padding: 084H to 100H *)
		XADCIF_CFG *,							(** 100H 32 rw 00001114H XADC Interface Configuration *)
		XADCIF_INT_STS *,						(** 104H 32 mixed 00000200H XADC Interface Interrupt Status *)
		XADCIF_INT_MASK *,					(** 108H 32 rw FFFFFFFFH XADC Interface Interrupt Mask *)
		XADCIF_MSTS *,						(** 10CH 32 ro 00000500H XADC Interface Miscellanous Status Register *)
		XADCIF_CMDFIFO *,					(** 110H 32 wo 00000000H XADC Interface Command FIFO Register *)
		XADCIF_RDFIFO *,						(** 114H 32 ro 00000000H XADC Interface Data FIFO Register *)
		XADCIF_MCTL *: SIGNED32;			(** 118H 32 rw 00000010H XADC Interface Miscellanous Control Register *)
	END;

VAR
	slcr*: SlcrRegisters; (** System Level Control (SLCR) registers set *)
	devcfg*: DevCfgRegisters; (** Device Configuration (Devcfg) register set *)

BEGIN
	slcr := SlcrBaseAdr;
	devcfg := DevCfgBaseAdr;
END Platform.