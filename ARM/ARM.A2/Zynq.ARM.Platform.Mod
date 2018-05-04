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
	(* ===== MPCORE registers and related devices ===== *)
	PrivateWatchdogIrq * = 30;
	PrivateWatchdogDisableKey0 * = 12345678H;
	PrivateWatchdogDisableKey1 * = 87654321H;

	MpcoreBase* = ADDRESS(0F8F00000H);
	ICDDCR* = MpcoreBase + 1000H; (* distributor control register *)
	ICDICFR* = MpcoreBase + 1C00H; (* interrupt configuration register *)
	ICCICR* = MpcoreBase + 0100H;  (* cpu interface control register *)
	ICCPMR* = MpcoreBase + 0104H; (* interrupt priority mask register *)
	ICCEOIR* = MpcoreBase + 0110H; (* end of interrupt register *)
	ICDIPTR* = MpcoreBase + 1800H; (* interrupt processor target registers *)
	ICDIPR* =   MpcoreBase + 1400H; (* interrupt priority registers *)
	ICDICER* =  MpcoreBase + 1180H; (* interrupt clear enable register *)
	ICDISER* = MpcoreBase + 1100H; (* interrupt set enable register *)
	ICDISPR* = MpcoreBase + 1200H; (* set pending register *)
	ICDICPR* = MpcoreBase + 1280H; (* clear pending register *)
	ICCIAR* = MpcoreBase + 10CH; (* Interrupt Ackknowledge Register *)
	ICCBPR* = MpcoreBase + 108H; (* Binary Point Register *)
	GlobalTimerCounterRegister0* = MpcoreBase + 200H;
	GlobalTimerCounterRegister1* = MpcoreBase + 204H;
	GlobalTimerControlRegister* = MpcoreBase + 208H;
	GlobalTimerInterruptStatusRegister* = MpcoreBase+ 20CH;
	ComparatorValueRegister0* = MpcoreBase + 210H;
	ComparatorValueRegister1* = MpcoreBase + 214H;
	AutoIncrementRegister* = MpcoreBase + 218H;

	PrivateLoadValueRegister* = MpcoreBase + 600H;
	PrivateTimerCounterRegister* = MpcoreBase + 604H;
	PrivateTimerControlRegister* = MpcoreBase + 608H;
	PrivateTimerInterruptStatusRegister* = MpcoreBase+ 60CH;

	SCUControlReg* = MpcoreBase;

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
	SlcrBase* = 0xF8000000; (** Base address for System Level Control (SLCR) registers *)
	SlcrLockKey* = 0x767B; (** SLCR lock key; write this value to SLCR_LOCK register to disable writing to SLCR registers *)
	SlcrUnlockKey* = 0xDF0D; (** SLCR unlock key; write this value to SLCR_UNLOCK register to enable writing to SLCR registers *)

	(* ===== System Watchdog registers ===== *)
	SWDTBase = ADDRESS(0'F800'5000H);

	(* ===== Device Configuration registers ===== *)
	DevCfgBase * = 0F8007000H;					(** Base address of the devcfg registers *)
	DevCfgDmaPlAdr * = ADDRESS(0FFFFFFFFH);	(** Devcfg DMA address of the PL *)
	DevCfgMctrlOffset * = 80H;						(** Offset of the MCTRL register; needed for early initialization in zynq bootloader *)
	DevCfgMctrlPsVersionOfs * = 28;
	DevCfgMctrlPsVersion10 * = 0;
	DevCfgMctrlPsVersion20 * = 1;
	DevCfgMctrlPsVersion30 * = 2;
	DevCfgMctrlPsVersion31 * = 3;

	(* ===== AXI interfaces ===== *)
	MasterAxiGp0Base* = 07F000000H; (** base address for Master AXI General Purpose interface 0 *)
	MasterAxiGp1Base* = 0BF000000H; (** base address for Master AXI General Purpose interface 1 *)

	(* ===== GPIO Registers ===== *)
	GpioBase * = ADDRESS(0E000A000H); (** Base address of GPIO registers *)
	GpioData * = GpioBase + 40H; (** Base address of GPIO data registers *)
	GpioBankNb * = 4; (** Number of GPIO banks *)
	GpioBank * = [GpioBase + 204H, GpioBase + 244H, GpioBase + 284H, GpioBase + 2C4H]; (** Base address of GPIO bank control registers *)

	(* ===== UART ===== *)
	UartBase* = [ADDRESS(0E0000000H),ADDRESS(0E0001000H)]; (* base address for all UART controllers present in the system *)
	UartModemPinsConnected* = [FALSE,FALSE];
	UartIrq * = [59,82];

	(* ===== USB ===== *)
	UsbNb * = 2; (** Number of USB controllers *)
	UsbBase * = [ADDRESS(0E0002100H), ADDRESS(0E0003100H)]; (** Base addresses of USB controllers: CAPLENGTH must be at offset 0. *)
	UsbIrq * = [53, 76]; (** USB IRQs *)

	(* ===== SD ===== *)
	SdNb * = 2;
	SdBase * = [ADDRESS(0E0100000H), ADDRESS(0E0101000H)];
	SdIrq * = [56, 79];

	RAMCore * = 100000H;
	RAMLogicalLow * = 0H;
	RAMLogicalHigh * = ADDRESS(10000000H);
	RAMDiskBase * = 100000H;
	RAMDiskSize * = 140 * 1024;
	OFSBlockSize * = 4096;
	HostPort * = '';
	ModRoot * = 21318H;

TYPE
	
	(** System Level Control (SLCR) registers definition *)
	SlcrRegisters* = POINTER{UNSAFE,UNTRACED} TO RECORD
		SCL*: LONGINT; (** 0x00000000 32 rw 0x00000000 Secure Configuration Lock *)
		SLCR_LOCK*: LONGINT; (** 0x00000004 32 wo 0x00000000 SLCR Write Protection Lock *)
		SLCR_UNLOCK*: LONGINT; (** 0x00000008 32 wo 0x00000000 SLCR Write Protection Unlock *)
		SLCR_LOCKSTA-: LONGINT; (** 0x0000000C 32 ro 0x00000001 SLCR Write Protection Status *)
		padding0: ARRAY 60 OF LONGINT;
		ARM_PLL_CTRL*: LONGINT; (** 0x00000100 32 rw 0x0001A008 ARM PLL Control *)
		DDR_PLL_CTRL*: LONGINT; (** 0x00000104 32 rw 0x0001A008 DDR PLL Control *)
		IO_PLL_CTRL*: LONGINT; (** 0x00000108 32 rw 0x0001A008 IO PLL Control *)
		PLL_STATUS-: LONGINT; (** 0x0000010C 32 ro 0x0000003F PLL Status *)
		ARM_PLL_CFG*: LONGINT; (** 0x00000110 32 rw 0x00177EA0 ARM PLL Configuration *)
		DDR_PLL_CFG*: LONGINT; (** 0x00000114 32 rw 0x00177EA0 DDR PLL Configuration *)
		IO_PLL_CFG*: LONGINT; (** 0x00000118 32 rw 0x00177EA0 IO PLL Configuration *)
		padding01: LONGINT;
		ARM_CLK_CTRL*: LONGINT; (** 0x00000120 32 rw 0x1F000400 CPU Clock Control *)
		DDR_CLK_CTRL*: LONGINT; (** 0x00000124 32 rw 0x18400003 DDR Clock Control *)
		DCI_CLK_CTRL*: LONGINT; (** 0x00000128 32 rw 0x01E03201 DCI clock control *)
		APER_CLK_CTRL*: LONGINT; (** 0x0000012C 32 rw 0x01FFCCCD AMBA Peripheral Clock Control *)
		USB0_CLK_CTRL*: LONGINT; (** 0x00000130 32 rw 0x00101941 USB 0 ULPI Clock Control *)
		USB1_CLK_CTRL*: LONGINT; (** 0x00000134 32 rw 0x00101941 USB 1 ULPI Clock Control *)
		GEM0_RCLK_CTRL*: LONGINT; (** 0x00000138 32 rw 0x00000001 GigE 0 Rx Clock and Rx Signals Select *)
		GEM1_RCLK_CTRL*: LONGINT; (** 0x0000013C 32 rw 0x00000001 GigE 1 Rx Clock and Rx Signals Select *)
		GEM0_CLK_CTRL*: LONGINT; (** 0x00000140 32 rw 0x00003C01 GigE 0 Ref Clock Control *)
		GEM1_CLK_CTRL*: LONGINT; (** 0x00000144 32 rw 0x00003C01 GigE 1 Ref Clock Control *)
		SMC_CLK_CTRL*: LONGINT; (** 0x00000148 32 rw 0x00003C21 SMC Ref Clock Control *)
		LQSPI_CLK_CTRL*: LONGINT; (** 0x0000014C 32 rw 0x00002821 Quad SPI Ref Clock Control *)
		SDIO_CLK_CTRL*: LONGINT; (** 0x00000150 32 rw 0x00001E03 SDIO Ref Clock Control *)
		UART_CLK_CTRL*: LONGINT; (** 0x00000154 32 rw 0x00003F03 UART Ref Clock Control *)
		SPI_CLK_CTRL*: LONGINT; (** 0x00000158 32 rw 0x00003F03 SPI Ref Clock Control *)
		CAN_CLK_CTRL*: LONGINT; (** 0x0000015C 32 rw 0x00501903 CAN Ref Clock Control *)
		CAN_MIOCLK_CTRL*: LONGINT; (** 0x00000160 32 rw 0x00000000 CAN MIO Clock Control *)
		DBG_CLK_CTRL*: LONGINT; (** 0x00000164 32 rw 0x00000F03 SoC Debug Clock Control *)
		PCAP_CLK_CTRL*: LONGINT; (** 0x00000168 32 rw 0x00000F01 PCAP Clock Control *)
		TOPSW_CLK_CTRL*: LONGINT; (** 0x0000016C 32 rw 0x00000000 Central Interconnect Clock Control *)
		FPGA0_CLK_CTRL*: LONGINT; (** 0x00000170 32 rw 0x00101800 PL Clock 0 Output control *)
		FPGA0_THR_CTRL*: LONGINT; (** 0x00000174 32 rw 0x00000000 PL Clock 0 Throttle control *)
		FPGA0_THR_CNT*: LONGINT; (** 0x00000178 32 rw 0x00000000 PL Clock 0 Throttle Count control *)
		FPGA0_THR_STA-: LONGINT; (** 0x0000017C 32 ro 0x00010000 PL Clock 0 Throttle Status read *)
		FPGA1_CLK_CTRL*: LONGINT; (** 0x00000180 32 rw 0x00101800 PL Clock 1 Output control *)
		FPGA1_THR_CTRL*: LONGINT; (** 0x00000184 32 rw 0x00000000 PL Clock 1 Throttle control *)
		FPGA1_THR_CNT*: LONGINT; (** 0x00000188 32 rw 0x00000000 PL Clock 1 Throttle Count *)
		FPGA1_THR_STA-: LONGINT; (** 0x0000018C 32 ro 0x00010000 PL Clock 1 Throttle Status control *)
		FPGA2_CLK_CTRL*: LONGINT; (** 0x00000190 32 rw 0x00101800 PL Clock 2 output control *)
		FPGA2_THR_CTRL*: LONGINT; (** 0x00000194 32 rw 0x00000000 PL Clock 2 Throttle Control *)
		FPGA2_THR_CNT*: LONGINT; (** 0x00000198 32 rw 0x00000000 PL Clock 2 Throttle Count *)
		FPGA2_THR_STA-: LONGINT; (** 0x0000019C 32 ro 0x00010000 PL Clock 2 Throttle Status *)
		FPGA3_CLK_CTRL*: LONGINT; (** 0x000001A0 32 rw 0x00101800 PL Clock 3 output control *)
		FPGA3_THR_CTRL*: LONGINT; (** 0x000001A4 32 rw 0x00000000 PL Clock 3 Throttle Control *)
		FPGA3_THR_CNT*: LONGINT; (** 0x000001A8 32 rw 0x00000000 PL Clock 3 Throttle Count *)
		FPGA3_THR_STA-: LONGINT; (** 0x000001AC 32 ro 0x00010000 PL Clock 3 Throttle Status *)
		padding1: ARRAY 5 OF LONGINT;
		CLK_621_TRUE*: LONGINT; (** 0x000001C4 32 rw 0x00000001 CPU Clock Ratio Mode select *)
		padding2: ARRAY 14 OF LONGINT;
		PSS_RST_CTRL*: LONGINT; (** 0x00000200 32 rw 0x00000000 PS Software Reset Control *)
		DDR_RST_CTRL*: LONGINT; (** 0x00000204 32 rw 0x00000000 DDR Software Reset Control *)
		TOPSW_RST_CTRL*: LONGINT; (** 0x00000208 32 rw 0x00000000 Central Interconnect Reset Control *)
		DMAC_RST_CTRL*: LONGINT; (** 0x0000020C 32 rw 0x00000000 DMAC Software Reset Control *)
		USB_RST_CTRL*: LONGINT; (** 0x00000210 32 rw 0x00000000 USB Software Reset Control *)
		GEM_RST_CTRL*: LONGINT; (** 0x00000214 32 rw 0x00000000 Gigabit Ethernet SW Reset Control *)
		SDIO_RST_CTRL*: LONGINT; (** 0x00000218 32 rw 0x00000000 SDIO Software Reset Control *)
		SPI_RST_CTRL*: LONGINT; (** 0x0000021C 32 rw 0x00000000 SPI Software Reset Control *)
		CAN_RST_CTRL*: LONGINT; (** 0x00000220 32 rw 0x00000000 CAN Software Reset Control *)
		I2C_RST_CTRL*: LONGINT; (** 0x00000224 32 rw 0x00000000 I2C Software Reset Control *)
		UART_RST_CTRL*: LONGINT; (** 0x00000228 32 rw 0x00000000 UART Software Reset Control *)
		GPIO_RST_CTRL*: LONGINT; (** 0x0000022C 32 rw 0x00000000 GPIO Software Reset Control *)
		LQSPI_RST_CTRL*: LONGINT; (** 0x00000230 32 rw 0x00000000 Quad SPI Software Reset Control *)
		SMC_RST_CTRL*: LONGINT; (** 0x00000234 32 rw 0x00000000 SMC Software Reset Control *)
		OCM_RST_CTRL*: LONGINT; (** 0x00000238 32 rw 0x00000000 OCM Software Reset Control *)
		padding3: LONGINT;
		FPGA_RST_CTRL*: SET; (** 0x00000240 32 rw 0x01F33F0F FPGA Software Reset Control *)
		A9_CPU_RST_CTRL*: LONGINT; (** 0x00000244 32 rw 0x00000000 CPU Reset and Clock control *)
		padding4: LONGINT;
		RS_AWDT_CTRL*: LONGINT; (** 0x0000024C 32 rw 0x00000000 Watchdog Timer Reset Control *)
		padding5: ARRAY 2 OF LONGINT;
		REBOOT_STATUS*: LONGINT; (** 0x00000258 32 rw 0x00400000 Reboot Status, persistent *)
		BOOT_MODE*: LONGINT; (** 0x0000025C 32 mixed x Boot Mode Strapping Pins *)
		padding6: ARRAY 40 OF LONGINT;
		APU_CTRL*: LONGINT; (** 0x00000300 32 rw 0x00000000 APU Control *)
		WDT_CLK_SEL*: LONGINT; (** 0x00000304 32 rw 0x00000000 SWDT clock source select *)
		padding7: ARRAY 78 OF LONGINT;
		TZ_DMA_NS*: LONGINT; (** 0x00000440 32 rw 0x00000000 DMAC TrustZone Config *)
		TZ_DMA_IRQ_NS*: LONGINT; (** 0x00000444 32 rw 0x00000000 DMAC TrustZone Config for Interrupts *)
		TZ_DMA_PERIPH_NS*: LONGINT; (** 0x00000448 32 rw 0x00000000 DMAC TrustZone Config for Peripherals *)
		padding8: ARRAY 57 OF LONGINT;
		PSS_IDCODE-: LONGINT; (** 0x00000530 32 ro x PS IDCODE *)
		padding9: ARRAY 51 OF LONGINT;
		DDR_URGENT*: LONGINT; (** 0x00000600 32 rw 0x00000000 DDR Urgent Control *)
		padding10: ARRAY 2 OF LONGINT;
		DDR_CAL_START*: LONGINT; (** 0x0000060C 32 mixed 0x00000000 DDR Calibration Start Triggers *)
		padding11: LONGINT;
		DDR_REF_START*: LONGINT; (** 0x00000614 32 mixed 0x00000000 DDR Refresh Start Triggers *)
		DDR_CMD_STA*: LONGINT; (** 0x00000618 32 mixed 0x00000000 DDR Command Store Status *)
		DDR_URGENT_SEL*: LONGINT; (** 0x0000061C 32 rw 0x00000000 DDR Urgent Select *)
		DDR_DFI_STATUS*: LONGINT; (** 0x00000620 32 mixed 0x00000000 DDR DFI status *)
		padding12: ARRAY 55 OF LONGINT;
		MIO_PIN_00*: LONGINT; (** 0x00000700 32 rw 0x00001601 MIO Pin 0 Control *)
		MIO_PIN_01*: LONGINT; (** 0x00000704 32 rw 0x00001601 MIO Pin 1 Control *)
		MIO_PIN_02*: LONGINT; (** 0x00000708 32 rw 0x00000601 MIO Pin 2 Control *)
		MIO_PIN_03*: LONGINT; (** 0x0000070C 32 rw 0x00000601 MIO Pin 3 Control *)
		MIO_PIN_04*: LONGINT; (** 0x00000710 32 rw 0x00000601 MIO Pin 4 Control *)
		MIO_PIN_05*: LONGINT; (** 0x00000714 32 rw 0x00000601 MIO Pin 5 Control *)
		MIO_PIN_06*: LONGINT; (** 0x00000718 32 rw 0x00000601 MIO Pin 6 Control *)
		MIO_PIN_07*: LONGINT; (** 0x0000071C 32 rw 0x00000601 MIO Pin 7 Control *)
		MIO_PIN_08*: LONGINT; (** 0x00000720 32 rw 0x00000601 MIO Pin 8 Control *)
		MIO_PIN_09*: LONGINT; (** 0x00000724 32 rw 0x00001601 MIO Pin 9 Control *)
		MIO_PIN_10*: LONGINT; (** 0x00000728 32 rw 0x00001601 MIO Pin 10 Control *)
		MIO_PIN_11*: LONGINT; (** 0x0000072C 32 rw 0x00001601 MIO Pin 11 Control *)
		MIO_PIN_12*: LONGINT; (** 0x00000730 32 rw 0x00001601 MIO Pin 12 Control *)
		MIO_PIN_13*: LONGINT; (** 0x00000734 32 rw 0x00001601 MIO Pin 13 Control *)
		MIO_PIN_14*: LONGINT; (** 0x00000738 32 rw 0x00001601 MIO Pin 14 Control *)
		MIO_PIN_15*: LONGINT; (** 0x0000073C 32 rw 0x00001601 MIO Pin 15 Control *)
		MIO_PIN_16*: LONGINT; (** 0x00000740 32 rw 0x00001601 MIO Pin 16 Control *)
		MIO_PIN_17*: LONGINT; (** 0x00000744 32 rw 0x00001601 MIO Pin 17 Control *)
		MIO_PIN_18*: LONGINT; (** 0x00000748 32 rw 0x00001601 MIO Pin 18 Control *)
		MIO_PIN_19*: LONGINT; (** 0x0000074C 32 rw 0x00001601 MIO Pin 19 Control *)
		MIO_PIN_20*: LONGINT; (** 0x00000750 32 rw 0x00001601 MIO Pin 20 Control *)
		MIO_PIN_21*: LONGINT; (** 0x00000754 32 rw 0x00001601 MIO Pin 21 Control *)
		MIO_PIN_22*: LONGINT; (** 0x00000758 32 rw 0x00001601 MIO Pin 22 Control *)
		MIO_PIN_23*: LONGINT; (** 0x0000075C 32 rw 0x00001601 MIO Pin 23 Control *)
		MIO_PIN_24*: LONGINT; (** 0x00000760 32 rw 0x00001601 MIO Pin 24 Control *)
		MIO_PIN_25*: LONGINT; (** 0x00000764 32 rw 0x00001601 MIO Pin 25 Control *)
		MIO_PIN_26*: LONGINT; (** 0x00000768 32 rw 0x00001601 MIO Pin 26 Control *)
		MIO_PIN_27*: LONGINT; (** 0x0000076C 32 rw 0x00001601 MIO Pin 27 Control *)
		MIO_PIN_28*: LONGINT; (** 0x00000770 32 rw 0x00001601 MIO Pin 28 Control *)
		MIO_PIN_29*: LONGINT; (** 0x00000774 32 rw 0x00001601 MIO Pin 29 Control *)
		MIO_PIN_30*: LONGINT; (** 0x00000778 32 rw 0x00001601 MIO Pin 30 Control *)
		MIO_PIN_31*: LONGINT; (** 0x0000077C 32 rw 0x00001601 MIO Pin 31 Control *)
		MIO_PIN_32*: LONGINT; (** 0x00000780 32 rw 0x00001601 MIO Pin 32 Control *)
		MIO_PIN_33*: LONGINT; (** 0x00000784 32 rw 0x00001601 MIO Pin 33 Control *)
		MIO_PIN_34*: LONGINT; (** 0x00000788 32 rw 0x00001601 MIO Pin 34 Control *)
		MIO_PIN_35*: LONGINT; (** 0x0000078C 32 rw 0x00001601 MIO Pin 35 Control *)
		MIO_PIN_36*: LONGINT; (** 0x00000790 32 rw 0x00001601 MIO Pin 36 Control *)
		MIO_PIN_37*: LONGINT; (** 0x00000794 32 rw 0x00001601 MIO Pin 37 Control *)
		MIO_PIN_38*: LONGINT; (** 0x00000798 32 rw 0x00001601 MIO Pin 38 Control *)
		MIO_PIN_39*: LONGINT; (** 0x0000079C 32 rw 0x00001601 MIO Pin 39 Control *)
		MIO_PIN_40*: LONGINT; (** 0x000007A0 32 rw 0x00001601 MIO Pin 40 Control *)
		MIO_PIN_41*: LONGINT; (** 0x000007A4 32 rw 0x00001601 MIO Pin 41 Control *)
		MIO_PIN_42*: LONGINT; (** 0x000007A8 32 rw 0x00001601 MIO Pin 42 Control *)
		MIO_PIN_43*: LONGINT; (** 0x000007AC 32 rw 0x00001601 MIO Pin 43 Control *)
		MIO_PIN_44*: LONGINT; (** 0x000007B0 32 rw 0x00001601 MIO Pin 44 Control *)
		MIO_PIN_45*: LONGINT; (** 0x000007B4 32 rw 0x00001601 MIO Pin 45 Control *)
		MIO_PIN_46*: LONGINT; (** 0x000007B8 32 rw 0x00001601 MIO Pin 46 Control *)
		MIO_PIN_47*: LONGINT; (** 0x000007BC 32 rw 0x00001601 MIO Pin 47 Control *)
		MIO_PIN_48*: LONGINT; (** 0x000007C0 32 rw 0x00001601 MIO Pin 48 Control *)
		MIO_PIN_49*: LONGINT; (** 0x000007C4 32 rw 0x00001601 MIO Pin 49 Control *)
		MIO_PIN_50*: LONGINT; (** 0x000007C8 32 rw 0x00001601 MIO Pin 50 Control *)
		MIO_PIN_51*: LONGINT; (** 0x000007CC 32 rw 0x00001601 MIO Pin 51 Control *)
		MIO_PIN_52*: LONGINT; (** 0x000007D0 32 rw 0x00001601 MIO Pin 52 Control *)
		MIO_PIN_53*: LONGINT; (** 0x000007D4 32 rw 0x00001601 MIO Pin 53 Control *)
		padding13: ARRAY 11 OF LONGINT;
		MIO_LOOPBACK*: LONGINT; (** 0x00000804 32 rw 0x00000000 Loopback function within MIO *)
		padding14: LONGINT;
		MIO_MST_TRI0*: LONGINT; (** 0x0000080C 32 rw 0xFFFFFFFF MIO pin Tri-state Enables, 31:0 *)
		MIO_MST_TRI1*: LONGINT; (** 0x00000810 32 rw 0x003FFFFF MIO pin Tri-state Enables, 53:32 *)
		padding15: ARRAY 7 OF LONGINT;
		SD0_WP_CD_SEL*: LONGINT; (** 0x00000830 32 rw 0x00000000 SDIO 0 WP CD select *)
		SD1_WP_CD_SEL*: LONGINT; (** 0x00000834 32 rw 0x00000000 SDIO 1 WP CD select *)
		padding16: ARRAY 50 OF LONGINT;
		LVL_SHFTR_EN*: LONGINT; (** 0x00000900 32 rw 0x00000000 Level Shifters Enable *)
		padding17: ARRAY 3 OF LONGINT;
		OCM_CFG*: LONGINT; (** 0x00000910 32 rw 0x00000000 OCM Address Mapping *)
		padding18: ARRAY 66 OF LONGINT;
		Reserved*: LONGINT; (** 0x00000A1C 32 rw 0x00010101 Reserved *)
		padding19: ARRAY 56 OF LONGINT;
		GPIOB_CTRL*: LONGINT; (** 0x00000B00 32 rw 0x00000000 PS IO Buffer Control *)
		GPIOB_CFG_CMOS18*: LONGINT; (** 0x00000B04 32 rw 0x00000000 MIO GPIOB CMOS 1.8V config *)
		GPIOB_CFG_CMOS25*: LONGINT; (** 0x00000B08 32 rw 0x00000000 MIO GPIOB CMOS 2.5V config *)
		GPIOB_CFG_CMOS33*: LONGINT; (** 0x00000B0C 32 rw 0x00000000 MIO GPIOB CMOS 3.3V config *)
		padding20: LONGINT;
		GPIOB_CFG_HSTL*: LONGINT; (** 0x00000B14 32 rw 0x00000000 MIO GPIOB HSTL config *)
		GPIOB_DRVR_BIAS_CTRL*: LONGINT; (** 0x00000B18 32 mixed 0x00000000 MIO GPIOB Driver Bias Control *)
		padding21: ARRAY 9 OF LONGINT;
		DDRIOB_ADDR0*: LONGINT; (** 0x00000B40 32 rw 0x00000800 DDR IOB Config for A[14:0], CKE and DRST_B *)
		DDRIOB_ADDR1*: LONGINT; (** 0x00000B44 32 rw 0x00000800 DDR IOB Config for BA[2:0], ODT, CS_B, WE_B, RAS_B and CAS_B *)
		DDRIOB_DATA0*: LONGINT; (** 0x00000B48 32 rw 0x00000800 DDR IOB Config for Data 15:0 *)
		DDRIOB_DATA1*: LONGINT; (** 0x00000B4C 32 rw 0x00000800 DDR IOB Config for Data 31:16 *)
		DDRIOB_DIFF0*: LONGINT; (** 0x00000B50 32 rw 0x00000800 DDR IOB Config for DQS 1:0 *)
		DDRIOB_DIFF1*: LONGINT; (** 0x00000B54 32 rw 0x00000800 DDR IOB Config for DQS 3:2 *)
		DDRIOB_CLOCK*: LONGINT; (** 0x00000B58 32 rw 0x00000800 DDR IOB Config for Clock Output *)
		DDRIOB_DRIVE_SLEW_ADDR*: LONGINT; (** 0x00000B5C 32 rw 0x00000000 Drive and Slew controls for Address and Command pins of the DDR Interface *)
		DDRIOB_DRIVE_SLEW_DATA*: LONGINT; (** 0x00000B60 32 rw 0x00000000 Drive and Slew controls for DQ pins of the DDR Interface *)
		DDRIOB_DRIVE_SLEW_DIFF*: LONGINT; (** 0x00000B64 32 rw 0x00000000 Drive and Slew controls for DQS pins of the DDR Interface *)
		DDRIOB_DRIVE_SLEW_CLOCK*: LONGINT; (** 0x00000B68 32 rw 0x00000000 Drive and Slew controls for Clock pins of the DDR Interface *)
		DDRIOB_DDR_CTRL*: LONGINT; (** 0x00000B6C 32 rw 0x00000000 DDR IOB Buffer Control *)
		DDRIOB_DCI_CTRL*: LONGINT; (** 0x00000B70 32 rw 0x00000020 DDR IOB DCI Config *)
		DDRIOB_DCI_STATUS*: LONGINT; (** 0x00000B74 32 mixed 0x00000000 DDR IO Buffer DCI Status *)
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
		UNLOCK *: LONGINT;				(** 034H 32 rw 00000000 Unlock Register *)
		padding0: ARRAY 18 OF LONGINT;	(** padding: 038H to 080H *)
		MCTRL *: LONGINT;					(** 080H 32 mixed xxxxxxxxH Miscellanous Control Register *)
		padding1: ARRAY 31 OF LONGINT;	(** padding: 084H to 100H *)
		XADCIF_CFG *,							(** 100H 32 rw 00001114H XADC Interface Configuration *)
		XADCIF_INT_STS *,						(** 104H 32 mixed 00000200H XADC Interface Interrupt Status *)
		XADCIF_INT_MASK *,					(** 108H 32 rw FFFFFFFFH XADC Interface Interrupt Mask *)
		XADCIF_MSTS *,						(** 10CH 32 ro 00000500H XADC Interface Miscellanous Status Register *)
		XADCIF_CMDFIFO *,					(** 110H 32 wo 00000000H XADC Interface Command FIFO Register *)
		XADCIF_RDFIFO *,						(** 114H 32 ro 00000000H XADC Interface Data FIFO Register *)
		XADCIF_MCTL *: LONGINT;			(** 118H 32 rw 00000010H XADC Interface Miscellanous Control Register *)
	END;

	MpcoreRegisters * = POINTER {UNSAFE, UNTRACED} TO RECORD
		SCU_CONTROL_REGISTER * {ALIGNED(1)}: LONGINT; (* 0x00000000 32 rw 0x00000002 SCU Control Register *)
		SCU_CONFIGURATION_REGISTER * {ALIGNED(1)}: LONGINT; (* 0x00000004 32 ro 0x00000501 SCU Configuration Register *)
		SCU_CPU_Power_Status_Register * {ALIGNED(1)}: LONGINT; (* 0x00000008 32 rw 0x00000000 SCU CPU Power Status Register *)
		SCU_Invalidate_All_Registers_in_Secure_State * {ALIGNED(1)}: LONGINT; (* 0x0000000C 32 wo 0x00000000 SCU Invalidate All Registers in Secure State *)
		padd0 {ALIGNED(1)}: ARRAY 48 OF CHAR;
		Filtering_Start_Address_Register * {ALIGNED(1)}: LONGINT; (* 0x00000040 32 rw 0x00100000 Filtering Start Address Register *)
		Filtering_End_Address_Register * {ALIGNED(1)}: LONGINT; (* 0x00000044 32 rw 0x00000000 Defined by FILTEREND input *)
		padd1 {ALIGNED(1)}: ARRAY 8 OF CHAR;
		SCU_Access_Control_Register_SAC * {ALIGNED(1)}: LONGINT; (* 0x00000050 32 rw 0x0000000F SCU Access Control (SAC) Register *)
		SCU_Non_secure_Access_Control_Register * {ALIGNED(1)}: LONGINT; (* 0x00000054 32 ro 0x00000000 SCU Non-secure Access Control Register SNSAC *)
		padd2 {ALIGNED(1)}: ARRAY 168 OF CHAR;
		ICCICR * {ALIGNED(1)}: LONGINT; (* 0x00000100 32 rw 0x00000000 CPU Interface Control Register *)
		ICCPMR * {ALIGNED(1)}: LONGINT; (* 0x00000104 32 rw 0x00000000 Interrupt Priority Mask Register *)
		ICCBPR * {ALIGNED(1)}: LONGINT; (* 0x00000108 32 rw 0x00000002 Binary Point Register *)
		ICCIAR * {ALIGNED(1)}: LONGINT; (* 0x0000010C 32 rw 0x000003FF Interrupt Acknowledge Register *)
		ICCEOIR * {ALIGNED(1)}: LONGINT; (* 0x00000110 32 rw 0x00000000 End Of Interrupt Register *)
		ICCRPR * {ALIGNED(1)}: LONGINT; (* 0x00000114 32 rw 0x000000FF Running Priority Register *)
		ICCHPIR * {ALIGNED(1)}: LONGINT; (* 0x00000118 32 rw 0x000003FF Highest Pending Interrupt Register *)
		ICCABPR * {ALIGNED(1)}: LONGINT; (* 0x0000011C 32 rw 0x00000003 Aliased Non-secure Binary Point Register *)
		padd3 {ALIGNED(1)}: ARRAY 220 OF CHAR;
		ICCIDR * {ALIGNED(1)}: LONGINT; (* 0x000001FC 32 ro 0x3901243B CPU Interface Implementer Identification Register *)
		Global_Timer_Counter_Register0 * {ALIGNED(1)}: LONGINT; (* 0x00000200 32 rw 0x00000000 Global Timer Counter Register 0 *)
		Global_Timer_Counter_Register1 * {ALIGNED(1)}: LONGINT; (* 0x00000204 32 rw 0x00000000 Global Timer Counter Register 1 *)
		Global_Timer_Control_Register * {ALIGNED(1)}: LONGINT; (* 0x00000208 32 rw 0x00000000 Global Timer Control Register *)
		Global_Timer_Interrupt_Status_Register * {ALIGNED(1)}: LONGINT; (* 0x0000020C 32 rw 0x00000000 Global Timer Interrupt Status Register *)
		Comparator_Value_Register0 * {ALIGNED(1)}: LONGINT; (* 0x00000210 32 rw 0x00000000 Comparator Value Register_0 *)
		Comparator_Value_Register1 * {ALIGNED(1)}: LONGINT; (* 0x00000214 32 rw 0x00000000 Comparator Value Register_1 *)
		Auto_increment_Register * {ALIGNED(1)}: LONGINT; (* 0x00000218 32 rw 0x00000000 Auto-increment Register *)
		padd4 {ALIGNED(1)}: ARRAY 996 OF CHAR;
		Private_Timer_Load_Register * {ALIGNED(1)}: LONGINT; (* 0x00000600 32 rw 0x00000000 Private Timer Load Register *)
		Private_Timer_Counter_Register * {ALIGNED(1)}: LONGINT; (* 0x00000604 32 rw 0x00000000 Private Timer Counter Register *)
		Private_Timer_Control_Register * {ALIGNED(1)}: LONGINT; (* 0x00000608 32 rw 0x00000000 Private Timer Control Register *)
		Private_Timer_Interrupt_Status_Register * {ALIGNED(1)}: LONGINT; (* 0x0000060C 32 rw 0x00000000 Private Timer Interrupt Status Register *)
		padd5 {ALIGNED(1)}: ARRAY 16 OF CHAR;
		Watchdog_Load_Register * {ALIGNED(1)}: LONGINT; (* 0x00000620 32 rw 0x00000000 Watchdog Load Register *)
		Watchdog_Counter_Register * {ALIGNED(1)}: LONGINT; (* 0x00000624 32 rw 0x00000000 Watchdog Counter Register *)
		Watchdog_Control_Register * {ALIGNED(1)}: LONGINT; (* 0x00000628 32 rw 0x00000000 Watchdog Control Register *)
		Watchdog_Interrupt_Status_Register * {ALIGNED(1)}: LONGINT; (* 0x0000062C 32 rw 0x00000000 Watchdog Interrupt Status Register *)
		Watchdog_Reset_Status_Register * {ALIGNED(1)}: LONGINT; (* 0x00000630 32 rw 0x00000000 Watchdog Reset Status Register *)
		Watchdog_Disable_Register * {ALIGNED(1)}: LONGINT; (* 0x00000634 32 rw 0x00000000 Watchdog Disable Register *)
		padd6 {ALIGNED(1)}: ARRAY 2504 OF CHAR;
		ICDDCR * {ALIGNED(1)}: LONGINT; (* 0x00001000 32 rw 0x00000000 Distributor Control Register *)
		ICDICTR * {ALIGNED(1)}: LONGINT; (* 0x00001004 32 ro 0x0000FC22 Interrupt Controller Type Register *)
		ICDIIDR * {ALIGNED(1)}: LONGINT; (* 0x00001008 32 ro 0x0102043B Distributor Implementer Identification Register *)
		padd7 {ALIGNED(1)}: ARRAY 116 OF CHAR;
		ICDISR0 * {ALIGNED(1)}: LONGINT; (* 0x00001080 32 rw 0x00000000 Interrupt Security Register_0 *)
		ICDISR1 * {ALIGNED(1)}: LONGINT; (* 0x00001084 32 rw 0x00000000 Interrupt Security Register_1 *)
		ICDISR2 * {ALIGNED(1)}: LONGINT; (* 0x00001088 32 rw 0x00000000 Interrupt Security Register_2 *)
		padd8 {ALIGNED(1)}: ARRAY 116 OF CHAR;
		ICDISER0 * {ALIGNED(1)}: LONGINT; (* 0x00001100 32 rw 0x0000FFFF Interrupt Set-enable Register 0 *)
		ICDISER1 * {ALIGNED(1)}: LONGINT; (* 0x00001104 32 rw 0x00000000 Interrupt Set-enable Register 1 *)
		ICDISER2 * {ALIGNED(1)}: LONGINT; (* 0x00001108 32 rw 0x00000000 Interrupt Set-enable Register 2 *)
		padd9 {ALIGNED(1)}: ARRAY 116 OF CHAR;
		ICDICER0 * {ALIGNED(1)}: LONGINT; (* 0x00001180 32 rw 0x0000FFFF Interrupt Clear-Enable Register 0 *)
		ICDICER1 * {ALIGNED(1)}: LONGINT; (* 0x00001184 32 rw 0x00000000 Interrupt Clear-Enable Register 1 *)
		ICDICER2 * {ALIGNED(1)}: LONGINT; (* 0x00001188 32 rw 0x00000000 Interrupt Clear-Enable Register 2 *)
		padd10 {ALIGNED(1)}: ARRAY 116 OF CHAR;
		ICDISPR0 * {ALIGNED(1)}: LONGINT; (* 0x00001200 32 rw 0x00000000 Interrupt Set-pending Register_0 *)
		ICDISPR1 * {ALIGNED(1)}: LONGINT; (* 0x00001204 32 rw 0x00000000 Interrupt Set-pending Register_1 *)
		ICDISPR2 * {ALIGNED(1)}: LONGINT; (* 0x00001208 32 rw 0x00000000 Interrupt Set-pending Register_2 *)
		padd11 {ALIGNED(1)}: ARRAY 116 OF CHAR;
		ICDICPR0 * {ALIGNED(1)}: LONGINT; (* 0x00001280 32 rw 0x00000000 Interrupt Clear-Pending Register_0 *)
		ICDICPR1 * {ALIGNED(1)}: LONGINT; (* 0x00001284 32 rw 0x00000000 Interrupt Clear-Pending Register_1 *)
		ICDICPR2 * {ALIGNED(1)}: LONGINT; (* 0x00001288 32 rw 0x00000000 Interrupt Clear-Pending Register_2 *)
		padd12 {ALIGNED(1)}: ARRAY 116 OF CHAR;
		ICDABR0 * {ALIGNED(1)}: LONGINT; (* 0x00001300 32 rw 0x00000000 Active Bit register_0 *)
		ICDABR1 * {ALIGNED(1)}: LONGINT; (* 0x00001304 32 rw 0x00000000 Active Bit register_1 *)
		ICDABR2 * {ALIGNED(1)}: LONGINT; (* 0x00001308 32 rw 0x00000000 Active Bit register_2 *)
		padd13 {ALIGNED(1)}: ARRAY 244 OF CHAR;
		ICDIPR0 * {ALIGNED(1)}: LONGINT; (* 0x00001400 32 rw 0x00000000 Interrupt Priority Register_0 *)
		ICDIPR1 * {ALIGNED(1)}: LONGINT; (* 0x00001404 32 rw 0x00000000 Interrupt Priority Register_1 *)
		ICDIPR2 * {ALIGNED(1)}: LONGINT; (* 0x00001408 32 rw 0x00000000 Interrupt Priority Register_2 *)
		ICDIPR3 * {ALIGNED(1)}: LONGINT; (* 0x0000140C 32 rw 0x00000000 Interrupt Priority Register_3 *)
		ICDIPR4 * {ALIGNED(1)}: LONGINT; (* 0x00001410 32 rw 0x00000000 Interrupt Priority Register_4 *)
		ICDIPR5 * {ALIGNED(1)}: LONGINT; (* 0x00001414 32 rw 0x00000000 Interrupt Priority Register_5 *)
		ICDIPR6 * {ALIGNED(1)}: LONGINT; (* 0x00001418 32 rw 0x00000000 Interrupt Priority Register_6 *)
		ICDIPR7 * {ALIGNED(1)}: LONGINT; (* 0x0000141C 32 rw 0x00000000 Interrupt Priority Register_7 *)
		ICDIPR8 * {ALIGNED(1)}: LONGINT; (* 0x00001420 32 rw 0x00000000 Interrupt Priority Register_8 *)
		ICDIPR9 * {ALIGNED(1)}: LONGINT; (* 0x00001424 32 rw 0x00000000 Interrupt Priority Register_9 *)
		ICDIPR10 * {ALIGNED(1)}: LONGINT; (* 0x00001428 32 rw 0x00000000 Interrupt Priority Register_10 *)
		ICDIPR11 * {ALIGNED(1)}: LONGINT; (* 0x0000142C 32 rw 0x00000000 Interrupt Priority Register_11 *)
		ICDIPR12 * {ALIGNED(1)}: LONGINT; (* 0x00001430 32 rw 0x00000000 Interrupt Priority Register_12 *)
		ICDIPR13 * {ALIGNED(1)}: LONGINT; (* 0x00001434 32 rw 0x00000000 Interrupt Priority Register_13 *)
		ICDIPR14 * {ALIGNED(1)}: LONGINT; (* 0x00001438 32 rw 0x00000000 Interrupt Priority Register_14 *)
		ICDIPR15 * {ALIGNED(1)}: LONGINT; (* 0x0000143C 32 rw 0x00000000 Interrupt Priority Register_15 *)
		ICDIPR16 * {ALIGNED(1)}: LONGINT; (* 0x00001440 32 rw 0x00000000 Interrupt Priority Register_16 *)
		ICDIPR17 * {ALIGNED(1)}: LONGINT; (* 0x00001444 32 rw 0x00000000 Interrupt Priority Register_17 *)
		ICDIPR18 * {ALIGNED(1)}: LONGINT; (* 0x00001448 32 rw 0x00000000 Interrupt Priority Register_18 *)
		ICDIPR19 * {ALIGNED(1)}: LONGINT; (* 0x0000144C 32 rw 0x00000000 Interrupt Priority Register_19 *)
		ICDIPR20 * {ALIGNED(1)}: LONGINT; (* 0x00001450 32 rw 0x00000000 Interrupt Priority Register_20 *)
		ICDIPR21 * {ALIGNED(1)}: LONGINT; (* 0x00001454 32 rw 0x00000000 Interrupt Priority Register_21 *)
		ICDIPR22 * {ALIGNED(1)}: LONGINT; (* 0x00001458 32 rw 0x00000000 Interrupt Priority Register_22 *)
		ICDIPR23 * {ALIGNED(1)}: LONGINT; (* 0x0000145C 32 rw 0x00000000 Interrupt Priority Register_23 *)
		padd14 {ALIGNED(1)}: ARRAY 928 OF CHAR;
		ICDIPTR0 * {ALIGNED(1)}: LONGINT; (* 0x00001800 32 ro 0x01010101 Interrupt Processor Targets Register 0 *)
		ICDIPTR1 * {ALIGNED(1)}: LONGINT; (* 0x00001804 32 ro 0x01010101 Interrupt Processor Targets Register 1 *)
		ICDIPTR2 * {ALIGNED(1)}: LONGINT; (* 0x00001808 32 ro 0x01010101 Interrupt Processor Targets Register 2 *)
		ICDIPTR3 * {ALIGNED(1)}: LONGINT; (* 0x0000180C 32 ro 0x01010101 Interrupt Processor Targets Register 3 *)
		ICDIPTR4 * {ALIGNED(1)}: LONGINT; (* 0x00001810 32 rw 0x00000000 Interrupt Processor Targets Register 4 *)
		ICDIPTR5 * {ALIGNED(1)}: LONGINT; (* 0x00001814 32 ro 0x00000000 Interrupt Processor Targets Register 5 *)
		ICDIPTR6 * {ALIGNED(1)}: LONGINT; (* 0x00001818 32 ro 0x01000000 Interrupt Processor Targets Register 6 *)
		ICDIPTR7 * {ALIGNED(1)}: LONGINT; (* 0x0000181C 32 ro 0x01010101 Interrupt Processor Targets Register 7 *)
		ICDIPTR8 * {ALIGNED(1)}: LONGINT; (* 0x00001820 32 rw 0x00000000 Interrupt Processor Targets Register 8 *)
		ICDIPTR9 * {ALIGNED(1)}: LONGINT; (* 0x00001824 32 rw 0x00000000 Interrupt Processor Targets Register 9 *)
		ICDIPTR10 * {ALIGNED(1)}: LONGINT; (* 0x00001828 32 rw 0x00000000 Interrupt Processor Targets Register 10 *)
		ICDIPTR11 * {ALIGNED(1)}: LONGINT; (* 0x0000182C 32 rw 0x00000000 Interrupt Processor Targets Register 11 *)
		ICDIPTR12 * {ALIGNED(1)}: LONGINT; (* 0x00001830 32 rw 0x00000000 Interrupt Processor Targets Register 12 *)
		ICDIPTR13 * {ALIGNED(1)}: LONGINT; (* 0x00001834 32 rw 0x00000000 Interrupt Processor Targets Register 13 *)
		ICDIPTR14 * {ALIGNED(1)}: LONGINT; (* 0x00001838 32 rw 0x00000000 Interrupt Processor Targets Register 14 *)
		ICDIPTR15 * {ALIGNED(1)}: LONGINT; (* 0x0000183C 32 rw 0x00000000 Interrupt Processor Targets Register 15 *)
		ICDIPTR16 * {ALIGNED(1)}: LONGINT; (* 0x00001840 32 rw 0x00000000 Interrupt Processor Targets Register 16 *)
		ICDIPTR17 * {ALIGNED(1)}: LONGINT; (* 0x00001844 32 rw 0x00000000 Interrupt Processor Targets Register 17 *)
		ICDIPTR18 * {ALIGNED(1)}: LONGINT; (* 0x00001848 32 rw 0x00000000 Interrupt Processor Targets Register 18 *)
		ICDIPTR19 * {ALIGNED(1)}: LONGINT; (* 0x0000184C 32 rw 0x00000000 Interrupt Processor Targets Register 19 *)
		ICDIPTR20 * {ALIGNED(1)}: LONGINT; (* 0x00001850 32 rw 0x00000000 Interrupt Processor Targets Register 20 *)
		ICDIPTR21 * {ALIGNED(1)}: LONGINT; (* 0x00001854 32 rw 0x00000000 Interrupt Processor Targets Register 21 *)
		ICDIPTR22 * {ALIGNED(1)}: LONGINT; (* 0x00001858 32 rw 0x00000000 Interrupt Processor Targets Register 22 *)
		ICDIPTR23 * {ALIGNED(1)}: LONGINT; (* 0x0000185C 32 rw 0x00000000 Interrupt Processor Targets Register 23 *)
		padd15 {ALIGNED(1)}: ARRAY 928 OF CHAR;
		ICDICFR0 * {ALIGNED(1)}: LONGINT; (* 0x00001C00 32 ro 0xAAAAAAAA Interrupt Configuration Register 0 *)
		ICDICFR1 * {ALIGNED(1)}: LONGINT; (* 0x00001C04 32 rw 0x7DC00000 Interrupt Configuration Register 1 *)
		ICDICFR2 * {ALIGNED(1)}: LONGINT; (* 0x00001C08 32 rw 0x55555555 Interrupt Configuration Register 2 *)
		ICDICFR3 * {ALIGNED(1)}: LONGINT; (* 0x00001C0C 32 rw 0x55555555 Interrupt Configuration Register 3 *)
		ICDICFR4 * {ALIGNED(1)}: LONGINT; (* 0x00001C10 32 rw 0x55555555 Interrupt Configuration Register 4 *)
		ICDICFR5 * {ALIGNED(1)}: LONGINT; (* 0x00001C14 32 rw 0x55555555 Interrupt Configuration Register 5 *)
		padd16 {ALIGNED(1)}: ARRAY 232 OF CHAR;
		ppi_status * {ALIGNED(1)}: LONGINT; (* 0x00001D00 32 ro 0x00000000 PPI Status Register *)
		spi_status_0 * {ALIGNED(1)}: LONGINT; (* 0x00001D04 32 ro 0x00000000 SPI Status Register 0 *)
		spi_status_1 * {ALIGNED(1)}: LONGINT; (* 0x00001D08 32 ro 0x00000000 SPI Status Register 1 *)
		padd17 {ALIGNED(1)}: ARRAY 500 OF CHAR;
		ICDSGIR * {ALIGNED(1)}: LONGINT; (* 0x00001F00 32 rw 0x00000000 Software Generated Interrupt Register *)
		padd18 {ALIGNED(1)}: ARRAY 204 OF CHAR;
		ICPIDR4 * {ALIGNED(1)}: LONGINT; (* 0x00001FD0 32 rw 0x00000004 Peripheral ID4 *)
		ICPIDR5 * {ALIGNED(1)}: LONGINT; (* 0x00001FD4 32 rw 0x00000000 Peripheral ID5 *)
		ICPIDR6 * {ALIGNED(1)}: LONGINT; (* 0x00001FD8 32 rw 0x00000000 Peripheral ID6 *)
		ICPIDR7 * {ALIGNED(1)}: LONGINT; (* 0x00001FDC 32 rw 0x00000000 Peripheral ID7 *)
		ICPIDR0 * {ALIGNED(1)}: LONGINT; (* 0x00001FE0 32 rw 0x00000090 Peripheral ID0 *)
		ICPIDR1 * {ALIGNED(1)}: LONGINT; (* 0x00001FE4 32 rw 0x000000B3 Peripheral ID1 *)
		ICPIDR2 * {ALIGNED(1)}: LONGINT; (* 0x00001FE8 32 rw 0x0000001B Peripheral ID2 *)
		ICPIDR3 * {ALIGNED(1)}: LONGINT; (* 0x00001FEC 32 rw 0x00000000 Peripheral ID3 *)
		ICCIDR0 * {ALIGNED(1)}: LONGINT; (* 0x00001FF0 32 rw 0x0000000D Component ID0 *)
		ICCIDR1 * {ALIGNED(1)}: LONGINT; (* 0x00001FF4 32 rw 0x000000F0 Component ID1 *)
		ICCIDR2 * {ALIGNED(1)}: LONGINT; (* 0x00001FF8 32 rw 0x00000005 Component ID2 *)
		ICCIDR3 * {ALIGNED(1)}: LONGINT; (* 0x00001FFC 32 rw 0x000000B1 Component ID3 *)
	END;

	SWDTRegisters * = POINTER {UNSAFE, UNTRACED} TO RECORD
		XWDTPS_ZMR_OFFSET * {ALIGNED(1)}: LONGINT; (* 0x00000000 24 mixed 0x000001C0 WD zero mode register *)
		XWDTPS_CCR_OFFSET * {ALIGNED(1)}: LONGINT; (* 0x00000004 26 mixed 0x00003FFC Counter Control Register *)
		XWDTPS_RESTART_OFFSET * {ALIGNED(1)}: LONGINT; (* 0x00000008 16 wo 0x00000000 Restart key register - this not a real register as no data is stored *)
		XWDTPS_SR_OFFSET * {ALIGNED(1)}: LONGINT; (* 0x0000000C 1 ro 0x00000000 Status Register *)
	END;

VAR
	slcr*: SlcrRegisters; (** System Level Control (SLCR) registers set *)
	devcfg*: DevCfgRegisters; (** Device Configuration (Devcfg) register set *)
	mpcore*: MpcoreRegisters; (** Cortex-A9 multiprocessor extensions (MPCore) register set *)
	swdt*: SWDTRegisters; (** System watchdog (SWDT) register set *)

BEGIN
	slcr := SlcrBase;
	devcfg := DevCfgBase;
	mpcore := MpcoreBase;
	swdt := SWDTBase;
END Platform.