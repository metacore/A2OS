MODULE Sd;
(**
	AUTHOR Timothée Martiel, 2015
	PURPOSE SD Card Host Controller Driver
*)

IMPORT
	SYSTEM, SdEnvironment, Log := SdEnvironment;

CONST
	BlockSize * = 512;
	InitialClockFrequency * = 400000; (* Hz *)

	(* Commands *) (*! Do not change values *)
	CMD_GO_IDLE_STATE * = 0; (** CMD0 bc [31:0] stuff bits - *)
	CMD_ALL_SEND_CID * = 2; (** CMD2 bcr [31:0] stuff bits R2 *)
	CMD_SEND_RELATIVE_ADDR * = 3; (** CMD3 bcr [31:0] stuff bits R6 *)
	CMD_SET_DSR * = 4; (** CMD4 bc [31:16] DSR [15:0] stuff bits - *)
	CMD_IO_SEND_OP_COND * = 5; (** CMD5 ?? [31:25] stuff bits [24] switch 1.8V request [23:0] I/O OCR R4 *)
	CMD_SWITCH_FUNC * = 6; (** CMD6 adtc [31] Mode 0:Check function 1:Switch function [30:24] reserved (All '0') [23:20] reserved for function group 6 (0h or Fh) [19:16] reserved for function group 5 (0h or Fh) [15:12] function group 4 for current limit [11:8] funciton group 3 for drive strength [7:4] function group 2 for command system [3:0] function group 1 for access mode R1 *)
	CMD_SELECT_DESELECT_CARD * = 7; (** CMD7 ac [31:16] RCA [15:0] stuff bits R1b (only from the selected card) *)
	CMD_SEND_IF_COND * = 8; (** CMD8 bcr [31:12] reserved bits [11:8] supply voltage(VHS) [7:0]check pattern R7 *)
	CMD_SEND_CSD * = 9; (** CMD9 ac [31:16] RCA [15:0] stuff bits R2 *)
	CMD_SEND_CID * = 10; (** CMD10 ac [31:16] RCA [15:0] stuff bits R2 *)
	CMD_VOLTAGE_SWITCH * = 11; (** CMD11 ac [31:0] reserved bits (all 0) R1 *)
	CMD_STOP_TRANSMISSION * = 12; (** CMD12 ac [31:0] stuff bits R1b *)
	CMD_SEND_STATUS * = 13; (** CMD13 ac [31:16] RCA [15:0] stuff bits R1 *)
	CMD_GO_INACTIVE_STATE * = 15; (** CMD15 ac [31:16] RCA [15:0] reserved bits - *)
	CMD_SET_BLOCKLEN * = 16; (** CMD16 ac [31:0] block length R1 *)
	CMD_READ_SINGLE_BLOCK * = 17; (** CMD17 adtc [31:0] data address2 R1 *)
	CMD_READ_MULTIPLE_BLOCK * = 18; (** CMD18 adtc [31:0] data address2 R1 *)
	CMD_SEND_TUNING_BLOCK * = 19; (** CMD19 adtc [31:0] reserved bits (all 0) R1 *)
	CMD_SPEED_CLASS_CONTROL * = 20; (** CMD20 ac [31:28]Speed Class Control [27:0] Reserved (all-0) R1b *)
	CMD_SET_BLOCK_COUNT * = 23; (** CMD23 ac [31:0] Block Count R1 *)
	CMD_WRITE_BLOCK * = 24; (** CMD24 adtc [31:0] data address2 R1 *)
	CMD_WRITE_MULTIPLE_BLOCK * = 25; (** CMD25 adtc [31:0] data address2 R1 *)
	CMD_PROGRAM_CSD * = 27; (** CMD27 adtc [31:0] stuff bits R1 *)
	CMD_SET_WRITE_PROT * = 28; (** CMD28 ac [31:0] data address2 R1b *)
	CMD_CLR_WRITE_PROT * = 29; (** CMD29 ac [31:0] data address2 R1b *)
	CMD_SEND_WRITE_PROT * = 30; (** CMD30 adtc [31:0] write protect data address2 R1 *)
	CMD_ERASE_WR_BLK_START * = 32; (** CMD32 ac [31:0] data address1 R1 *)
	CMD_ERASE_WR_BLK_END * = 33; (** CMD33 ac [31:0] data address1 R1 *)
	CMD_ERASE * = 38; (** CMD38 ac [31:0] stuff bits R1b *)
	CMD_LOCK_UNLOCK * = 42; (** CMD42 adtc [31:0] Reserved bits (Set all 0) R1 *)
	CMD_APP_CMD * = 55; (** CMD55 ac [31:16] RCA [15:0] stuff bits R1 *)
	CMD_GEN_CMD * = 56; (** CMD56 adtc [31:1] stuff bits. [0] RD/WR R1 *)

	(** Application Commands *) (*! Do Not Change Values *)
	ACMD_SET_BUS_WIDTH * = 6; (** ACMD6 ac [31:2] stuff bits [1:0] bus width R1 *)
	ACMD_SD_STATUS * = 13; (** ACMD13 adtc [31:0] stuff bits R1 *)
	ACMD_SEND_NUM_WR_BLOCKS * = 22; (** ACMD22 adtc [31:0] stuff bits R1 *)
	ACMD_SET_WR_BLK_ERASE_COUNT * = 23; (** ACMD23 ac [31:23] stuff bits [22:0] Number of blocks R1 *)
	ACMD_SD_SEND_OP_COND * = 41; (** ACMD41 bcr [31]reserved bit [30] HCS(OCR[30]) [29] reserved for eSD [28] XPC [27:25] reserved bits [24] S18R [23:0] VDD Voltage Window(OCR[23:0]) R3 *)
	ACMD_SET_CLR_CARD_DETECT * = 42; (** ACMD42 ac [31:1] stuff bits [0] set_cd R1 *)
	ACMD_SEND_SCR * = 51; (** ACMD51 adtc [31:0] stuff bits R1 *)

	(** Errors *)
	ErrorNone * = 0; (** No error *)
	ErrorCmdTimeout * = 1; (** Timeout on command line *)
	ErrorCmdCrc * = 2; (** CRC error on command line *)
	ErrorDatTimeout * = 3; (** Timeout on data line *)
	ErrorDatCrc * = 4; (** CRC error on data line *)
	ErrorNoCard * = 5; (** No card present *)
	ErrorCard * = 6; (** Card failed to perform operation *)
	ErrorUnrecoverable * = 7; (** Host controller in an unrecoverable state *)
	ErrorInvalidParameters * = 8; (** Invalid parameters *)

	(** Card Versions: maximal SD physical layer specifications version supported by the card *)
	Version1 * = 0; (** v1.00 or v1.01 *)
	Version1p1 * = 1; (** v1.10 *)
	Version2 * = 2; (** v2.00 *)
	Version3 * = 3; (** v3.01 *)
	Version4 * = 4; (** v4.10 *)
	Version5 * = 5; (** v5.10 *)
	Version6 * =6; (** v6.0 *)

	(** Card Type *)
	TypeNone * = 0; (** Unknow *)
	TypeSDSC * = 1; (** SD standard capacity - physical specs v1.0 or v1.1, limited to 2 GB *)
	TypeSDHC * = 2; (** SD High Capacity - 2 GB to 32 GB *)
	TypeSDXC * = 3; (** SD Extended Capacity - 32 GB to 2 TB *)

	(** Card Events *)
	OnInitialization * = 0;
	OnRemoval * = 1;
	OnReadComplete * = 2;
	OnWriteComplete * = 3;

	(** Command Record Flags *)
	FlagData * = 0;
	FlagRead * = 1;
	FlagAutoCmd12 * = 2;
	FlagAutoCmd23 * = 3;
	FlagMultipleBlockTx * = 4;
	FlagCountBlocks * = 5;
	FlagAbort * = 7;
	FlagApplicationCmd * = 8;
	FlagIgnoreIllegalCmd * = 9;

	(** Response Types *) (*! Do not change values *)
	ResponseNone	 * = -1;
	ResponseR1 * = 0;
	ResponseR1b * = 1;
	ResponseR2 * = 2;
	ResponseR3 * = 3;
	ResponseR4 * = 4;
	ResponseR5 * = 5;
	ResponseR5b * = 6;
	ResponseR6 * = 7;
	ResponseR7 * = 8;

	(** Host Controller States *)
	HcOperational * = 0; (** Host controller is operational *)
	HcConfiguring * = 1; (** Host controller is waiting for configuration input *)
	HcError * = 2; (** Error occurred *)

	(** Card States *)
	CardIdle = 0;
	CardReady = 1;
	CardIdentification = 2;
	CardStandby = 3;
	CardTransfer = 4;
	CardData = 5;
	CardReceive = 6;
	CardProgram = 7;
	CardDisabled = 8;

	(** Operation modes *)
	OpCpu = 0;
	OpSdma = 1;
	OpAdma = 2;

	(* Present State bits *)
	PresentState_CommandInhibitCmd = 0;
	PresentState_CommandInhibitDat = 1;
	PresentState_DatLineActive = 2;
	PresentState_RetuningRequest = 3;
	PresentState_WriteTransferActive = 8;
	PresentState_ReadTransferActive = 9;
	PresentState_BufferWriteEnable = 10;
	PresentState_BufferReadEnable = 11;
	PresentState_CardInserted = 16;
	PresentState_CardStateStable = 17;
	PresentState_CardDetectPinLevel = 18;
	PresentState_WriteProtectSwitchPinLevel = 19;
	PresentState_CmdLineSignalLevel = 24;
	PresentState_DatLineSignalLevelOfs = 20;
	PresentState_DatLineSignalLevelMask = {20 .. 23};

	(* Interrupt Status, Status Enable, Signal Enable bits *)
	Interrupt_Normal_CommandComplete = 0;
	Interrupt_Normal_TransferComplete = 1;
	Interrupt_Normal_BlockGapEvent = 2;
	Interrupt_Normal_DmaInterrupt = 3;
	Interrupt_Normal_BufferWriteReady = 4;
	Interrupt_Normal_BufferReadReady = 5;
	Interrupt_Normal_CardInsertion = 6;
	Interrupt_Normal_CardRemoval = 7;
	Interrupt_Normal_CardInterrupt = 8;
	Interrupt_Normal_IntA = 9;
	Interrupt_Normal_IntB = 10;
	Interrupt_Normal_IntC = 11;
	Interrupt_Normal_RetuningEvent = 12;
	Interrupt_Normal_ErrorInterrupt = 15;
	Interrupt_Error_CommandTimeout = 16;
	Interrupt_Error_CommandCrc = 17;
	Interrupt_Error_CommandEndBit = 18;
	Interrupt_Error_CommandIndex = 19;
	Interrupt_Error_DataTimeout = 20;
	Interrupt_Error_DataCrc = 21;
	Interrupt_Error_DataEndBit = 22;
	Interrupt_Error_CurrentLimit = 23;
	Interrupt_Error_AutoCmd12 = 24;
	Interrupt_Error_Adma = 25;
	Interrupt_Error_Tuning = 26;
	Interrupt_Normal_All = {Interrupt_Normal_CommandComplete, Interrupt_Normal_TransferComplete, Interrupt_Normal_BlockGapEvent, Interrupt_Normal_DmaInterrupt,
									Interrupt_Normal_BufferWriteReady, Interrupt_Normal_BufferReadReady, Interrupt_Normal_CardInsertion, Interrupt_Normal_CardRemoval,
									Interrupt_Normal_CardInterrupt, Interrupt_Normal_IntA, Interrupt_Normal_IntB, Interrupt_Normal_IntC, Interrupt_Normal_RetuningEvent,
									Interrupt_Normal_ErrorInterrupt};
	Interrupt_Error_All = {Interrupt_Error_CommandTimeout, Interrupt_Error_CommandCrc, Interrupt_Error_CommandEndBit,
									Interrupt_Error_CommandIndex, Interrupt_Error_DataTimeout, Interrupt_Error_DataCrc, Interrupt_Error_DataEndBit, Interrupt_Error_CurrentLimit,
									Interrupt_Error_AutoCmd12, Interrupt_Error_Adma, Interrupt_Error_Tuning};
	Interrupt_All = Interrupt_Normal_All + Interrupt_Error_All;

	(* Transfer Mode Register bits *)
	TransferMode_DmaEnable = 0;
	TransferMode_BlockCountEnable = 1;
	TransferMode_AutoCmdOfs = 2;
	TransferMode_AutoCmdMask = {2 .. 3};
	TransferMode_DataTxDirection = 4;
	TransferMode_MultipleBlocks = 5;
	TransferMode_AutoCmd_None = {};
	TransferMode_AutoCmd_Cmd12 = {2};
	TransferMode_AutoCmd_Cmd23 = {3};

	(* Command Register bits *)
	Command_ResponseTypeOffset = 0;
	Command_CrcCheckEnable = 3;
	Command_IndexCheckEnable = 4;
	Command_DataPresent = 5;
	Command_CommandTypeOffset = 6;
	Command_CommandTypeMask = {6 .. 7};
	Command_CommandIndexOffset = 8;
	Command_CommandIndexMask = {8 .. 13};

	Command_ResponseType_None = 0;
	Command_ResponseType_136b = 1;
	Command_ResponseType_48b = 2;
	Command_ResponseType_48bBusy = 3;

	(* Capabilities Register *)
	(* Low Word *)
	Capabilities_TimeoutClockFrequencyOfs = 0;
	Capabilities_TimeoutClockFrequencyMask = {0 .. 5};
	Capabilities_TimeoutClockUnit = 7;
	Capabilities_BaseClockFreqSdOfs = 8;
	Capabilities_BaseClockFreqSdMask = {8 .. 15};
	Capabilities_MaxBlockLenOfs = 16;
	Capabilities_MaxBlockLenMask = {16 .. 17};
	Capabilities_8BitEmbedded = 18;
	Capabilities_ADMA2 = 19;
	Capabilities_HighSpeed = 21;
	Capabilities_SDMA = 22;
	Capabilities_SuspendResume = 23;
	Capabilities_Voltage33 = 24;
	Capabilities_Voltage30 = 25;
	Capabilities_Voltage18 = 26;
	Capabilities_64BitBus = 28;
	Capabilities_AsyncInterrupt = 29;
	Capabilities_SlotTypeOfs = 30;
	Capabilities_SlotTypeMask = {30 .. 31};
	(* High Word *)
	Capabilities_SDR50 = 0;
	Capabilities_SDR104 = 1;
	Capabilities_DDR50 = 2;
	Capabilities_DriverTypeA = 4;
	Capabilities_DriverTypeC = 5;
	Capabilities_DriverTypeD = 6;
	Capabilities_TimerCountRetuningOfs = 8;
	Capabilities_TimerCountRetuningMask = {8 .. 11};
	Capabilities_TuningSDR50 = 13;
	Capabilities_RetuningModesOfs = 14;
	Capabilities_RetuningModesMask = {14 .. 15};
	Capabilities_ClockMultiplierOfs = 16;
	Capabilities_ClockMultiplierMask = {16 .. 23};
	(* Patterns *)
	Capabilities_SlotType_Removable = {};
	Capabilities_SlotType_Embedded = {30};
	Capabilities_SlotType_SharedBus = {31};

	(* Host Control 1 register values *)
	HostControl1_LedControl = 0;
	HostControl1_DataTransferWidth = 1;
	HostControl1_HighSpeedEnable = 2;
	HostControl1_DmaSelectOfs = 3;
	HostControl1_DmaSelectMask = {3 .. 4};
	HostControl1_ExtendedDataTxWidth = 5;
	HostControl1_CardDetectTestLevel = 6;
	HostControl1_CardDetectSignalSelection = 7;
	HostControl1_DmaSelect_Sdma = {};
	HostControl1_DmaSelect_32Adma = {4};

	(* SoftwareReset register values *)
	SoftwareResetAll = 1;
	SoftwareResetCmd = 2;
	SoftwareResetDat = 4;

	(* Clock Control register values *)
	ClockControl_InternalClockEnable = 0;
	ClockControl_InternalClockState = 1;
	ClockControl_SdClockEnable = 2;
	ClockControl_ClockGeneratorSelect = 5;
	ClockControl_SdClockFreqUpperOfs = 6;
	ClockControl_SdClockFreqUpperMask = {6, 7};
	ClockControl_SdClockFreqOfs = 8;
	ClockControl_SdClockFreqMask = {8 .. 15};

	(* Power Control register values *)
	PowerControl_SDBusPower* = 0;
	PowerControl_SDBusVoltageOfs = 1;
	PowerControl_SDBusVoltageMask = {1 .. 3};
	PowerControl_SDBusVoltage_18 = {1, 3};
	PowerControl_SDBusVoltage_30 = {2, 3};
	PowerControl_SDBusVoltage_33 = {1, 2, 3};

	(* Host Controller Version *)
	HostControllerVersion_SpecificationMask = {0 .. 7};
	HostControllerVersion_VendorOfs = 8;
	HostControllerVersion_VendorMask = {8 .. 15};


	(* SD Status fields *)
	SdStatus_FuleSupport = 312;
	SdStatus_DiscardSupport = 313;
	SdStatus_PerformanceEnhanceOfs = 335;
	SdStatus_PerformanceEnhanceWidth = 8;
	SdStatus_AppPerfClassOfs = 336;
	SdStatus_AppPerfClassWidth = 4;
	SdStatus_SusAddrOfs = 346;
	SdStatus_SusAddrWidth = 22;
	SdStatus_VscAuSizeOfs = 368;
	SdStatus_VscAuSizeWidth = 10;
	SdStatus_VideoSpeedClassOfs = 384;
	SdStatus_VideoSpeedClassWidth = 8;
	SdStatus_UhsAuSizeOfs =  392;
	SdStatus_UhsAuSizeWidth = 4;
	SdStatus_UhsSpeedGradeOfs = 396;
	SdStatus_UhsSpeedGradeWidth = 4;
	SdStatus_EraseOffsetOfs = 400;
	SdStatus_EraseOffsetWidth = 2;
	SdStatus_EraseTimeoutOfs = 402;
	SdStatus_EraseTimeoutWidth = 6;
	SdStatus_EraseSizeOfs = 408;
	SdStatus_EraseSizeWidth = 16;
	SdStatus_AuSizeOfs = 428;
	SdStatus_AuSizeWidth = 4;
	SdStatus_PerformanceMoveOfs = 432;
	SdStatus_PerformanceMoveWidth = 8;
	SdStatus_SpeedClassOfs = 440;
	SdStatus_SpeedClassWidth = 8;
	SdStatus_SizeOfProtectedAreaOfs = 448;
	SdStatus_SizeOfProtectedAreaWidth = 32;
	SdStatus_SdCardTypeOfs = 480;
	SdStatus_SdCardTypeWidth = 16;
	SdStatus_SecuredMode = 509;
	SdStatus_DatBusWidthOfs = 510;
	SdStatus_DatBusWidthWidth = 2;

	(* Card Status register -- R1 *)
	CardStatus_AkeSpecError = 3;
	CardStatus_AppCmd = 5;
	CardStatus_ReadyForData = 8;
	CardStatus_CurrentStateOffset = 9;
	CardStatus_CurrentStateMask = {9 .. 12};
	CardStatus_EraseReset = 13;
	CardStatus_CardEccDisable = 14;
	CardStatus_WpEraseSkip = 15;
	CardStatus_CsdOverwrite = 16;
	CardStatus_Error = 19;
	CardStatus_CcError = 20;
	CardStatus_CardEccFailed = 21;
	CardStatus_IllegalCommand = 22;
	CardStatus_ComCrcError = 23;
	CardStatus_LockUnlockFailed = 24;
	CardStatus_CardIsLocked = 25;
	CardStatus_WpViolation = 26;
	CardStatus_EraseParam = 27;
	CardStatus_EraseSeqError = 28;
	CardStatus_BlockLenError = 29;
	CardStatus_AddressError = 30;
	CardStatus_OutOfRange = 31;

	(* OCR Registers *)
	CardOcr_Vdd27_28 = 15;
	CardOcr_Vdd28_29 = 16;
	CardOcr_Vdd29_30 = 17;
	CardOcr_Vdd30_31 = 18;
	CardOcr_Vdd31_32 = 19;
	CardOcr_Vdd32_33 = 20;
	CardOcr_Vdd33_34 = 21;
	CardOcr_Vdd34_35 = 22;
	CardOcr_Vdd35_36 = 23;
	CardOcr_S18A = 24;
	CardOcr_UHS2CardStatus = 29;
	CardOcr_CardCapacityStatus = 30;
	CardOcr_PowerUpStatus = 31;

	(* CID Register *)
	CardCid_ManufacturerIdOfs = 112;
	CardCid_ManufacturerIdWidth = 8;
	CardCid_OEM_ApplicationIdOfs = 96;
	CardCid_OEM_ApplicationIdWidth = 16;
	CardCid_ProductNameOfs = 56;
	CardCid_ProductNameWidth = 40;
	CardCid_ProductRevisionOfs = 48;
	CardCid_ProductRevisionWidth = 8;
	CardCid_ProductSerialNbOfs = 16;
	CardCid_ProductSerialNbWidth = 32;
	CardCid_ProductManufacturingDateOfs = 0;
	CardCid_ProductManufacturingDateWidth = 12;

	(* CSD Register. This excludes the CRC7 of the specifications. *)
	CardCsd_FileFormatOfs = 2;
	CardCsd_FileFormatWidth = 2;
	CardCsd_TmpWriteProtect = 4;
	CardCsd_PermWriteProtect = 5;
	CardCsd_Copy = 6;
	CardCsd_FileFormatGrp = 7;
	CardCsd_WriteBlPartial = 13;
	CardCsd_WriteBlLenOfs = 14;
	CardCsd_WriteBlLenWidth = 4;
	CardCsd_R2wFactorOfs = 18;
	CardCsd_R2wFactorWidth = 3;
	CardCsd_WpGrpEnable = 23;
	CardCsd_WpGrpSizeOfs = 24;
	CardCsd_WpGrpSizeWidth = 7;
	CardCsd_SectorSizeOfs = 31;
	CardCsd_SectorSizeWidth = 7;
	CardCsd_EraseBlkEn = 38;
	CardCsd_CSizeMultOfs1 = 39; (** V1 *)
	CardCsd_CSizeMultWidth1 = 3; (** V1 *)
	CardCsd_VddWCurrMaxOfs1 = 42; (** V1 *)
	CardCsd_VddWCurrMaxWidth1 = 3; (** V1 *)
	CardCsd_VddWCurrMinOfs1 = 45; (** V1 *)
	CardCsd_VddWCurrMinWidth1 = 3; (** V1 *)
	CardCsd_VddRCurrMaxOfs1 = 48; (** V1 *)
	CardCsd_VddRCurrMaxWidth1 = 3; (** V1 *)
	CardCsd_VddRCurrMinOfs1 = 51; (** V1 *)
	CardCsd_VdddRCurrMaxWidth1 = 3; (** V1 *)
	CardCsd_CSizeOfs1 = 54; (** V1 *)
	CardCsd_CSizeWidth1 = 12; (** V1 *)
	CardCsd_CSizeOfs2 = 40; (** V2 *)
	CardCsd_CSizeWidth2 = 22; (** V2 *)
	CardCsd_DsrImp = 68;
	CardCsd_ReadBlkMisalign = 69;
	CardCsd_WriteBlkMisalign = 70;
	CardCsd_ReadBlPartial = 71;
	CardCsd_ReadBlLenOfs = 72;
	CardCsd_ReadBlLenWidth = 4;
	CardCsd_CccOfs = 76;
	CardCsd_CccWidth = 12;
	CardCsd_TranSpeedOfs = 88;
	CardCsd_TranSpeedWidth = 8;
	CardCsd_NsacOfs = 96;
	CardCsd_NsacWidth = 8;
	CardCsd_TaacOfs = 104;
	CardCsd_TaacWidth = 8;
	CardCsd_CsdStructureOfs = 118;
	CardCsd_CsdStructureWidth = 2;

	(* SCR Register *)
	CardScr_CommandSupportOfs = 32;
	CardScr_CommandSupportWidth = 4;
	CardScr_SpecVXOfs = 38;
	CardScr_SpecVXWidth = 4;
	CardScr_SpecV4 = 42;
	CardScr_ExtendedSecurityOfs = 43;
	CardScr_ExtendedSecurityWidth = 4;
	CardScr_SpecV3 = 47;
	CardScr_BusWidthsOfs = 48;
	CardScr_BusWidthsWidth = 4;
	CardScr_SecurityOfs = 52;
	CardScr_SecurityWidth = 3;
	CardScr_DataStateAfterErase = 55;
	CardScr_SpecVersionOfs = 56;
	CardScr_SpecVersionWidth = 4;
	CardScr_StructureOfs = 60;
	CardScr_StructureWidth = 4;

	(* SCR register fields values *)
	CardScr_SpecVX_v5 = 1;
	CardScr_SpecVX_v6 = 2;

	(* Card categories, used in SD status card type *)
	CategoryRW * = 0;
	CategoryRO * = 1;
	CategoryOTP * = 2;

	(* Performance enhancing features, used in perfEnhance in SD status *)
	PerformanceCardMaintenance * = 0; (** Card supports card-initiated maintenance *)
	PerformanceHostMaintenance * = 1; (** Card supports host-initiated maintenance *)
	PerformanceCache * = 2; (** Card supports internal caching *)
	PerformanceQueue * =3; (** Card supports command queue *)

	(* Transfer options *)
	TxDma = TRUE; (** Use DMA for transfers on all hosts that support it *)
	TxBufferSize = 4096; (** Buffer size used for DMA transfers *)
	TxBufferAlign = 32; (** Alignment requirement on DMA buffer: here cache line size of ARM *)

	(* ADMA2 flags *) (*! Do not change values *)
	Adma2Valid = 0; (** Valid entry *)
	Adma2End = 1; (** Last entry *)
	Adma2Int = 2; (** Entry generates interrupt on completion *)
	Adma2Nop = {}; (** No-operation, just continue to next *)
	Adma2Trans = {5}; (** Transfer descriptor *)
	Adma2Link = {4, 5}; (** Link descriptor *)
	Adma2ActMask = {4, 5}; (** Mask for Nop, Trans and Link *)

	(* Timeout values *)
	TimeoutCardInit = 100; (** Timeout used in card initialization, ms *)
	TimeoutReadFactor = 100; (** Timeout factor on typical read time (according to CSD) *)
	TimeoutReadFix = 100; (** Maximal read timeout in ms. To be used unconditionally with SDHC *)
	TimeoutWriteFactor = 100; (** Timeout factor on typical write time (according to CSD) *)
	TimeoutWriteFix = 250; (** Maximal write timeout in ms. To be used unconditionally with SDHC *)
	TimeoutErase = 250; (** Typical timeout per erased block, ms *)

	DefaultTimeout = 1000; (* Default timeout for blocking, in ms *)

	(* Multi-threading *)
	Synchronize * = FALSE (*TRUE*); (** Do we need to take care of concurrency? *)

	(* Tracing options for debugging *)
	EnableTraceCmd* = FALSE;
	EnableTrace* = FALSE;

TYPE
	(** Command execution procedure *)
	CommandProcedure * = PROCEDURE (VAR command: Command; VAR result: WORD): BOOLEAN;
	(** Data command execution procedure *)
	TransferProcedure * = PROCEDURE (VAR command: Command; VAR data: ARRAY OF SYSTEM.BYTE; ofs, len: LONGINT; VAR result: WORD): BOOLEAN;
	(** Procedure called to wait for interrupt. mask specifies which interrupts are expected, timeout is in ms. Returns FALSE if timeout occurred *)
	Blocker * = PROCEDURE {DELEGATE} (hc: HostController; mask: SET; timeout: LONGINT): BOOLEAN;

	(**
		SD Host controller descriptor.
	*)
	HostController * = POINTER TO HostControllerDesc;
	HostControllerDesc * = RECORD
		state -, (** HC state *)
		version -: LONGINT; (** Specifications version *)

		execute -: CommandProcedure; (** Method to execute commands *)
		transfer -: TransferProcedure; (** Method to execute data commands *)
		acquire *, release *: PROCEDURE {DELEGATE}; (** Procedures used for locking *)

		baseFrequency, (** Base hc clock frequency *)
		frequency, (** Bus frequency *)
		timeoutFrequency: HUGEINT; (** Timeout clock frequency *)
		lastRca: LONGINT; (** Last RCA selected by the controller. *)

		handle: EventHandler; (** Card event handler *)
		handlerParam: ANY; (** Parameter of the eventHandler *)
		block: Blocker; (** Procedure called to wait for interrupts *)

		regs-: HcRegisters; (** Memory-mapped I/O registers *)
		cards: Card; (** List of cards on this HC *)
		next: HostController; (** Linked list of controllers for interrupt handling *)
		desc{ALIGNED(32)}: ARRAY 32 OF HUGEINT; (** DMA descriptor *)
	END;

	(**
		Command record.
		This record type is used to describe a command and its result.
		To execute a command, fill in the fields 'hc', 'command', 'argument', 'responseType'.
		If the command uses the DAT line or is an application command, setup then necessary flags.
		If the command is an application command, you also need to specify the RCA for CMD55.
		After command execution, you can read the command response in the 'response' field. Use the
		'GetR*' procedures to extract all information from this field in a convenient way.
	*)
	Command * = RECORD
		hc *: HostController; (** Host controller on which the command is executed *)
		rca *, (** Optional RCA parameter. Required only for ACMDs *)
		command *, (** Command number *)
		argument *, (** Command argument *)
		responseType *, (** Response type *)
		blockSize *, (** Block size for read, write or erase *)
		dataTimeout *: LONGINT; (** Timeout value used for data line *)
		flags *: SET; (** Command flags *)
		response *: ARRAY 4 OF LONGINT; (** Response *)
	END;

	(** SWITCH_FUNC returned status *)
	SwitchFuncStatus * = RECORD
		current -: LONGINT; (** Current for specified config *)
		functionGroups -: ARRAY 6 OF SET; (** Supported function in each group *)
		functionStatus -: ARRAY 6 OF LONGINT; (** Function status *)
	END;

	(** Card event handler. 'card' is the card for which an event is reported (can be a new card object) and 'event' is one of 'On*' constants *)
	EventHandler * = PROCEDURE {DELEGATE} (card: Card; event: LONGINT; param: ANY);

	(** Host controller registers *)
	HcRegisters * = POINTER {UNSAFE,UNTRACED} TO RECORD
		SDMASystemAddress * {ALIGNED(1)}: LONGINT; (** offset = 0H *)
		BlockSize * {ALIGNED(1)}, (** offset = 4H *)
		BlockCount * {ALIGNED(1)}: INTEGER; (** offset = 6H *)
		Argument1 * {ALIGNED(1)}: LONGINT; (** offset = 8H *)
		TransferMode * {ALIGNED(1)}, (** offset = 0CH *)
		Command * {ALIGNED(1)}: INTEGER; (** offset = 0EH *)
		Response * {ALIGNED(1)}: ARRAY 4 OF LONGINT; (** offset = 10H *)
		BufferData * {ALIGNED(1)}: LONGINT;
		PresentState * {ALIGNED(1)}: SET;
		HostControl1 * {ALIGNED(1)},
		PowerControl * {ALIGNED(1)},
		BlockGapControl * {ALIGNED(1)},
		WakeupControl * {ALIGNED(1)}: SHORTINT;
		ClockControl * {ALIGNED(1)}: INTEGER;
		TimeoutControl * {ALIGNED(1)},
		SoftwareReset * {ALIGNED(1)}: SHORTINT;
		InterruptStatus * {ALIGNED(1)},
		InterruptStatusEnable * {ALIGNED(1)},
		InterruptSignalEnable * {ALIGNED(1)}: SET;
		AutoCmdErrorStatus * {ALIGNED(1)},
		HostControl2 * {ALIGNED(1)}: INTEGER;
		Capabilities * {ALIGNED(1)}: ARRAY 2 OF SET;
		MaximumCurrentCapabilities * {ALIGNED(1)}: HUGEINT;
		ForceEventAutoCmdErrorStatus * {ALIGNED(1)},
		ForceEventErrorInterruptStatus * {ALIGNED(1)}: INTEGER;
		AdmaErrorStatus * {ALIGNED(1)}: SHORTINT;
		padding0 * {ALIGNED(1)}: ARRAY 3 OF SHORTINT;
		AdmaSystemAddress * {ALIGNED(1)}: HUGEINT;
		PresetValues * {ALIGNED(1)}: ARRAY 8 OF INTEGER;
		padding1 * {ALIGNED(1)}: ARRAY 28 OF LONGINT;
		SharedBusControl * {ALIGNED(1)}: LONGINT;
		padding2 * {ALIGNED(1)}: ARRAY 6 OF LONGINT;
		SlotInterruptStatus * {ALIGNED(1)},
		HostControllerVersion * {ALIGNED(1)}: INTEGER;
	END;

VAR
	(** List of all host controllers *)
	hcs: HostController;

	(** Statistics *)
	NbyteRead -,
	NbyteWritten -,
	Nread -,
	Nwrite -: HUGEINT;
	Tread -,
	Twrite -: HUGEINT;
	start, stop: HUGEINT;

	(* ==================== Host Controller (Low-Level) Interface ==================== *)
	(**
		Create an host controller descriptor and initializes it with the given info.
		'baseAddress' is the base address of the IO registers.
		'extClockFreq' is an optional external clock frequency. It is used iff the host controller has no information about its clock frequency.
		'handler' is the event handler and 'param' is user parameter.
	*)
	PROCEDURE InitHostController * (hc: HostController; baseAddress: ADDRESS)(*: HostController*);
	VAR
		val: LONGINT;
	BEGIN
		hc.regs := baseAddress;
		IF ~Reset(hc, TRUE, TRUE) THEN (*RETURN NIL*) END;
		hc.baseFrequency := LSH(SYSTEM.VAL(LONGINT, hc.regs.Capabilities[0] * Capabilities_BaseClockFreqSdMask), -Capabilities_BaseClockFreqSdOfs);
		hc.timeoutFrequency := LSH(SYSTEM.VAL(LONGINT, hc.regs.Capabilities[0] * Capabilities_TimeoutClockFrequencyMask), -Capabilities_TimeoutClockFrequencyOfs) * 1000;
		IF Capabilities_TimeoutClockUnit IN hc.regs.Capabilities[0] THEN hc.timeoutFrequency := hc.timeoutFrequency * 1000 END;
		(*SetBusClock(hc, InitialClockFrequency);
		SetTimeout(hc, 100);*)

		(* Power select 3.3V bus voltage *)
		hc.regs.PowerControl :=  SYSTEM.VAL(SHORTINT, PowerControl_SDBusVoltage_33 + {PowerControl_SDBusPower});

		(* Enable All Interrupts *)
		hc.regs.InterruptStatusEnable := Interrupt_All;
		hc.regs.InterruptSignalEnable := {Interrupt_Normal_CardInsertion, Interrupt_Normal_CardRemoval};
		hc.regs.BlockGapControl := 0;

		val := LONGINT(hc.regs.HostControllerVersion);
		hc.version := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, val) * HostControllerVersion_SpecificationMask) + 1;

		IF EnableTrace THEN
			Log.String("[SD] New Host Controller v");
			Log.Int(hc.version, 0);
			Log.String(" at ");
			Log.Address(baseAddress);
			Log.Ln;
			PrintCapabilities(hc);
		END;

		IF Synchronize THEN SdEnvironment.GetLock(hc.acquire, hc.release) END;

		(* Select method according to DMA support *)
		IF TxDma THEN
			IF (Capabilities_ADMA2 IN hc.regs.Capabilities[0]) THEN
				hc.transfer := ExecuteAdmaCommand;
				hc.regs.HostControl1 := SYSTEM.VAL(SHORTINT, SYSTEM.VAL(SET, LONGINT(hc.regs.HostControl1)) + HostControl1_DmaSelect_32Adma);
			ELSE
				(*! ADMA1 and SDMA are not implemented yet *)
				hc.transfer := ExecuteDataCommand
			END
		ELSE
			hc.transfer := ExecuteDataCommand
		END;
		hc.execute := ExecuteCommand;
		hc.block := SpinBlock; (* Use spin block by default *)

		IF (hc.baseFrequency = 0) OR (hc.timeoutFrequency = 0) THEN
			hc.state := HcConfiguring
		ELSE
			hc.state := HcOperational
		END;

		(* If there is a card already, initialize it *)
		(*IF (PresentState_CardInserted IN hc.regs.PresentState) & (PresentState_CardStateStable IN hc.regs.PresentState) THEN
			NEW(hc.cards);
			IF InitCard(hc, hc.cards, result) & (hc.handle # NIL) THEN
				hc.handle(hc.cards, OnInitialization, hc.handlerParam)
			ELSIF hc.handle # NIL THEN
				Log.String("[SD] Could not initialize inserted card: error ");
				Log.Int(result, 0);
				Log.Ln;
			END
		END;*)

		hc.next := hcs;
		hcs := hc;
	END InitHostController;

	(** Set external clock for a host controller. Host state must be HcConfiguring. bus is the SD bus clock frequency, timeout is the timeout clock frequency. *)
	PROCEDURE SetExternalClock * (hc: HostController; bus, timeout: HUGEINT; VAR result: WORD): BOOLEAN;
	BEGIN
		IF hc.state # HcConfiguring THEN
			result := ErrorInvalidParameters;
			RETURN FALSE
		END;
		hc.baseFrequency := bus;
		hc.timeoutFrequency := timeout;
		hc.state := HcOperational;
		RETURN TRUE
	END SetExternalClock;

	(** Set an event handler for a host controller *)
	PROCEDURE SetEventHandler * (hc: HostController; handler: EventHandler; param: ANY);
	VAR
		result: WORD;
	BEGIN
		hc.handle := handler;
		hc.handlerParam := param;

		(* Handle events if necessary *)
		IF (PresentState_CardInserted IN hc.regs.PresentState) & (PresentState_CardStateStable IN hc.regs.PresentState) THEN
			NEW(hc.cards);
			IF InitCard(hc, hc.cards, result) & (hc.handle # NIL) THEN
				hc.handle(hc.cards, OnInitialization, hc.handlerParam)
			ELSIF hc.handle # NIL THEN
				Log.String("[SD] Could not initialize inserted card: error ");
				Log.Int(result, 0);
				Log.Ln;
			END
		END;
	END SetEventHandler;

	(** Change the wait for interrupt method *)
	PROCEDURE SetBlocker * (hc: HostController; blocker: Blocker);
	BEGIN
		hc.block := blocker
	END SetBlocker;

	(** Turns the busy LED on or off *)
	PROCEDURE SetLedState * (hc: HostController; on: BOOLEAN);
	VAR
		reg: SET;
	BEGIN
		reg := SYSTEM.VAL(SET, hc.regs.HostControl1);
		IF on THEN
			INCL(reg, HostControl1_LedControl)
		ELSE
			EXCL(reg, HostControl1_LedControl)
		END;
		hc.regs.HostControl1 := SYSTEM.VAL(SHORTINT, reg)
	END SetLedState;

	(** Get the state of the busy LED *)
	PROCEDURE GetLedState * (hc: HostController): BOOLEAN;
	BEGIN
		RETURN HostControl1_LedControl IN SYSTEM.VAL(SET, hc.regs.HostControl1)
	END GetLedState;

	(**
		Execute the command 'command', without data transfer. If you need data transfer, use 'ExecuteDataCommand'.
		Performs all necessary steps for executing a command:
			o Runs CMD55 if command is an application command
			o Execute the command
			o Wait for response
	*)
	PROCEDURE ExecuteCommand (VAR command: Command; VAR result: WORD): BOOLEAN;
	VAR
		status, r1: SET;
	BEGIN
		IF Synchronize THEN command.hc.acquire END;
		result := ErrorNone;
		(* Check Parameters *)
		IF {FlagData, FlagRead, FlagAutoCmd12, FlagAutoCmd23, FlagMultipleBlockTx, FlagCountBlocks} * command.flags # {} THEN
			result := ErrorInvalidParameters;
			IF Synchronize THEN command.hc.release END;
			RETURN FALSE
		END;

		IF (FlagApplicationCmd IN command.flags) THEN
			IF ~StartCommand(command.hc, CMD_APP_CMD, LSH(command.rca, 16), ResponseR1, FlagRead IN command.flags, FALSE, FALSE, FALSE, status, result) THEN
				IF Synchronize THEN command.hc.release END;
				RETURN FALSE
			END;
			r1 := GetR1(command);
			IF EnableTrace THEN PrintCardStatus(r1) END;
			IF ~(FlagIgnoreIllegalCmd IN command.flags) & (CardStatus_Error IN r1) THEN
				result := ErrorCard;
				IF Synchronize THEN command.hc.release END;
				RETURN FALSE
			END
		END;

		IF ~StartCommand(
				command.hc, command.command, command.argument, command.responseType, FlagRead IN command.flags, FALSE,
				FALSE (*command.responseType = ResponseR1b*), FlagAbort IN command.flags, status, result) THEN
			IF Synchronize THEN command.hc.release END;
			RETURN FALSE
		END;
		GetResponse(command.hc, command.responseType, command.response);
		IF command.command = CMD_SELECT_DESELECT_CARD THEN
			command.hc.lastRca := LSH(command.argument, -16)
		ELSIF command.command = CMD_GO_IDLE_STATE THEN
			command.hc.lastRca := 0
		END;
		IF Synchronize THEN command.hc.release END;
		RETURN TRUE
	END ExecuteCommand;

	(**
		Execute command with data transfer using CPU.
		Data is read from/written to [data[ofs], data[ofs + len]).
	*)
	PROCEDURE ExecuteDataCommand (VAR command: Command; VAR data: ARRAY OF SYSTEM.BYTE; ofs, len: LONGINT; VAR result: WORD): BOOLEAN;
	TYPE
		DataBytes = ARRAY 4 OF CHAR;
	VAR
		tmp: DataBytes;
		i, stepLen: LONGINT;
		hc: HostController;
		r1, status, mask: SET;
	BEGIN
		ASSERT(ofs + len <= LEN(data), 7);
		result := ErrorNone;
		IF ~(FlagData IN command.flags) THEN
			result := ErrorInvalidParameters;
			RETURN FALSE
		END;
		hc := command.hc;

		IF Synchronize THEN hc.acquire END;
		(* Set timeout *)
		SetTimeout(hc, command.dataTimeout);
		(*IF (*~Reset(hc, TRUE, FALSE) OR*) ~Reset(hc, FALSE, TRUE) THEN
			result := ErrorCard;
			IF Synchronize THEN hc.release END;
			RETURN FALSE
		END;*)

		IF (FlagApplicationCmd IN command.flags) THEN
			IF ~StartCommand(hc, CMD_APP_CMD, LSH(command.rca, 16), ResponseR1, FlagRead IN command.flags, FALSE, FALSE, FALSE, status, result) THEN
				IF Synchronize THEN hc.release END;
				RETURN FALSE
			END;
			r1 := SYSTEM.VAL(SET, command.response[0]);
			IF CardStatus_Error IN r1 THEN
				IF Synchronize THEN hc.release END;
				RETURN FALSE
			END;
			IF EnableTrace THEN
				Log.String("[SD] CMD55 Status:");
				Log.Ln;
				PrintCardStatus(r1)
			END
		END;

		(* 1 *)
		IF ~(FlagApplicationCmd IN command.flags) &
				((command.command = CMD_READ_SINGLE_BLOCK) OR (command.command = CMD_READ_MULTIPLE_BLOCK) OR
				(command.command = CMD_WRITE_BLOCK) OR (command.command = CMD_WRITE_MULTIPLE_BLOCK) OR
				(command.command = 53)(* SDIO Command *)) THEN
			IF len <= BlockSize THEN
				hc.regs.BlockSize := INTEGER(len);
				hc.regs.BlockCount := 1
			ELSE
				hc.regs.BlockSize := BlockSize;
				hc.regs.BlockCount := INTEGER(len DIV BlockSize)
			END;

			IF EnableTrace THEN
				Log.String("[SD] ");
				IF FlagRead IN command.flags THEN Log.String("Read")
				ELSE Log.String("Write") END;
				Log.String(" parameters:"); Log.Ln;
				Log.String("[SD] 	Block Size = "); Log.Int(hc.regs.BlockSize, 0); Log.Ln;
				Log.String("[SD] 	Block Count = "); Log.Int(hc.regs.BlockCount, 0); Log.Ln;
				Log.String("[SD] 	CMD"); Log.Int(command.command, 0); Log.Ln;
				Log.String("[SD] 	Argument = "); Log.Address(command.argument); Log.Ln
			END
		END;

		(* 3 - 8 *)
		IF FlagRead IN command.flags THEN
			(*REPEAT UNTIL (Interrupt_Normal_BufferReadReady IN hc.regs.InterruptStatus) OR (Interrupt_Normal_ErrorInterrupt IN hc.regs.InterruptStatus)*)
			mask := {Interrupt_Normal_BufferReadReady, Interrupt_Normal_ErrorInterrupt}
		ELSE
			(*REPEAT UNTIL (Interrupt_Normal_BufferWriteReady IN hc.regs.InterruptStatus) OR (Interrupt_Normal_ErrorInterrupt IN hc.regs.InterruptStatus)*)
			mask := {Interrupt_Normal_BufferWriteReady, Interrupt_Normal_ErrorInterrupt}
		END;

		IF ~StartCommand(hc, command.command, command.argument, ResponseR1, FlagRead IN command.flags, FALSE, TRUE, FALSE, status, result) THEN RETURN FALSE END;
		r1 := SYSTEM.VAL(SET, command.response[0]);
		IF CardStatus_Error IN r1 THEN
			IF Synchronize THEN hc.release END;
			RETURN FALSE
		END;
		IF EnableTrace THEN PrintCardStatus(r1) END;
		WHILE len > 0 DO
			(* 14 *)
			IF ~hc.block(hc, mask, command.dataTimeout * 1000) THEN
				Log.String("[SD] Error: interrupt timeout");
				Log.Ln;
				RETURN FALSE
			END;
			status := hc.regs.InterruptStatus;

			IF Interrupt_Normal_ErrorInterrupt IN hc.regs.InterruptStatus THEN
				IF ErrorRecovery(hc, result, status) THEN END;
				IF Interrupt_Error_DataTimeout IN status THEN
					result := ErrorDatTimeout
				ELSIF Interrupt_Error_DataCrc IN status THEN
					result := ErrorDatCrc
				ELSIF Interrupt_Error_DataEndBit IN status THEN
					result := ErrorCard
				END;
				IF Synchronize THEN hc.release END;
				RETURN FALSE
			END;
			(* 15 *)
			(*INCL(hc.regs.InterruptStatus, Interrupt_Normal_BufferReadReady);*)
			hc.regs.InterruptStatus := {Interrupt_Normal_BufferReadReady};

			(* 16 *)
			stepLen := MIN(BlockSize, len);
			IF FlagRead IN command.flags THEN
				FOR i := 0 TO stepLen - 1 BY 4 DO
					SYSTEM.PUT32(ADDRESSOF(data[ofs + i]), hc.regs.BufferData);
					(*SYSTEM.VAL(LONGINT, tmp) := hc.regs.BufferData;
					SYSTEM.VAL(DataBytes, data[ofs + i]) := tmp*)
				END
			ELSE
				FOR i := 0 TO stepLen - 1 BY 4 DO
					tmp := SYSTEM.VAL(DataBytes, data[ofs + i]);
					hc.regs.BufferData := SYSTEM.VAL(LONGINT, tmp);
				END
			END;
			(* 17 *)
			INC(ofs, stepLen);
			DEC(len, stepLen)
		END;

		(* 18 -> Not infinite block *)
		(*REPEAT UNTIL Interrupt_Normal_TransferComplete IN hc.regs.InterruptStatus;*)
		IF ~hc.block(hc, {Interrupt_Normal_TransferComplete}, command.dataTimeout * 1000) THEN
			Log.String("[SD] Error: timeout interrupt");
			Log.Ln;
			RETURN FALSE
		END;
		(* 19 *)
		(*INCL(hc.regs.InterruptStatus, Interrupt_Normal_TransferComplete);*)
		hc.regs.InterruptStatus := {Interrupt_Normal_TransferComplete};

		(*DEC(hc.regs.ClockControl, LSH(1, ClockControl_SdClockEnable));
		hc.regs.SoftwareReset := SYSTEM.VAL(SHORTINT, {SoftwareResetCmd, SoftwareResetDat});
		REPEAT UNTIL hc.regs.SoftwareReset = 0;
		INC(hc.regs.ClockControl, LSH(1, ClockControl_SdClockEnable));*)

		IF Synchronize THEN hc.release END;
		RETURN TRUE (*Reset(hc, TRUE, FALSE) & Reset(hc, FALSE, TRUE)*)
	END ExecuteDataCommand;

	(**
		Execute Command with data transfers using ADMA.
		command: ADMA command
		data, ofs, len: Buffer
		result: error code
	*)
	PROCEDURE ExecuteAdmaCommand (VAR command: Command; VAR data: ARRAY OF SYSTEM.BYTE; ofs, len: LONGINT; VAR result: WORD): BOOLEAN;
	VAR
		tt: SdEnvironment.Time;
		hc: HostController;
		r1, status, flags: SET;
		address, a: ADDRESS;
		blocks, blockSize, desc, txlen, l, tx: LONGINT;
		padd: BOOLEAN; (* Padd transfer to next block length? *)

		PROCEDURE WriteAdma2Desc (address: ADDRESS; len: LONGINT; flags: SET): HUGEINT;
		BEGIN
			IF EnableTrace THEN
				Log.String("[SD] ADMA2 Entry; address = "); Log.Hex(address, -8); Log.String(", size = "); Log.Int(len, 0);
				Log.String(", flags = ");
				IF flags * Adma2ActMask = Adma2Nop THEN Log.String("NOP ")
				ELSIF flags * Adma2ActMask = Adma2Trans THEN Log.String("TRANS ")
				ELSIF flags * Adma2ActMask = Adma2Link THEN Log.String("LINK ")
				END;
				IF Adma2Valid IN flags THEN Log.String("VALID ") END;
				IF Adma2End IN flags THEN Log.String("END ") END;
				IF Adma2Int IN flags THEN Log.String("INT ") END;
				Log.Ln
			END;
			ASSERT(address MOD 4 = 0);
			ASSERT((len > 0) OR (flags * Adma2ActMask # Adma2Trans));
			RETURN LSH(HUGEINT(address), 32) + LSH(len MOD 65536, 16) + SYSTEM.VAL(LONGINT, flags)
		END WriteAdma2Desc;

	BEGIN
		result := ErrorNone;
		hc := command.hc;
		IF Synchronize THEN hc.acquire END;

		(* Setup descriptors *)
		address := ADDRESSOF(data[ofs]);
		(*IF ~(FlagRead IN command.flags) THEN*) SdEnvironment.FlushDCacheRange(address, len); (*END;*)
		txlen := len;
		flags := Adma2Trans + {Adma2Valid};
		padd := FALSE; (*(len > BlockSize) & (len MOD BlockSize # 0);*)
		l := len;
		a := address;
		WHILE l > 0 DO
			IF ~padd & (l <= 65536) THEN flags := flags + {Adma2End, Adma2Int} END;
			tx := MIN(l, 65536);
			hc.desc[desc] := WriteAdma2Desc(a, tx, flags);
			DEC(l, tx);
			INC(a, tx);
			INC(desc);
		END;
		(*hc.desc[desc] := WriteAdma2Desc(0, 0, {Adma2Valid, Adma2End, Adma2Int} + Adma2Nop); INC(desc);*)
		SdEnvironment.FlushDCacheRange(ADDRESSOF(hc.desc[0]), (desc + 1) * 8);

		(* Reset command and data lines *)
		IF (*~Reset(hc, TRUE, FALSE) OR*) ~Reset(hc, FALSE, TRUE) THEN
			result := ErrorCard;
			IF Synchronize THEN hc.release END;
			RETURN FALSE
		END;

		(* 1 *)
		hc.regs.AdmaSystemAddress := ADDRESSOF(hc.desc[0]);

		IF (FlagApplicationCmd IN command.flags) THEN
			IF ~StartCommand(command.hc, CMD_APP_CMD, LSH(command.rca, 16), ResponseR1, FlagRead IN command.flags, FALSE, FALSE, FALSE, status, result) THEN
				IF Synchronize THEN hc.release END;
				RETURN FALSE
			END;
			r1 := SYSTEM.VAL(SET, command.response[0]);
			IF EnableTrace THEN
				Log.String("[SD] CMD55 Status:");
				Log.Ln;
				PrintCardStatus(r1)
			END;
			IF CardStatus_Error IN r1 THEN
				result := ErrorCard;
				IF Synchronize THEN hc.release END;
				RETURN FALSE
			END
		END;

		(* 2-3 *)
		IF command.blockSize = 0 THEN
			blockSize := BlockSize
		ELSE
			blockSize := command.blockSize
		END;
		IF FlagData IN command.flags THEN
			IF txlen <= blockSize THEN
				hc.regs.BlockSize := INTEGER(txlen);
				hc.regs.BlockCount := 1;
				blocks := 1
			ELSE
				hc.regs.BlockSize := INTEGER(blockSize);
				blocks := txlen DIV blockSize;
				hc.regs.BlockCount := INTEGER(blocks)
			END;

			(* Set data timeout *)
			ASSERT(command.dataTimeout > 0);
			SetTimeout(hc, command.dataTimeout);

			IF EnableTrace THEN
				Log.String("[SD] ");
				IF FlagRead IN command.flags THEN Log.String("Read")
				ELSE Log.String("Write") END;
				Log.String(" parameters:"); Log.Ln;
				Log.String("[SD] 	Block Size = "); Log.Int(hc.regs.BlockSize, 0); Log.Ln;
				Log.String("[SD] 	Block Count = "); Log.Int(hc.regs.BlockCount, 0); Log.Ln;
				Log.String("[SD] 	CMD"); Log.Int(command.command, 0); Log.Ln;
				Log.String("[SD] 	Argument = "); Log.Address(command.argument); Log.Ln
			END
		END;

		status := hc.regs.InterruptStatus;
		ASSERT({Interrupt_Normal_TransferComplete, Interrupt_Normal_ErrorInterrupt} * status = {});
		(*!start := SdEnvironment.GetTimeCounter();*)
		IF ~StartCommand(command.hc, command.command, command.argument, command.responseType, FlagRead IN command.flags, TRUE, TRUE, FALSE, status, result) THEN
			IF Synchronize THEN hc.release END;
			RETURN FALSE
		END;
		r1 := SYSTEM.VAL(SET, command.response[0]);
		IF CardStatus_Error IN r1 THEN
			result := ErrorCard;
			IF Synchronize THEN hc.release END;
			RETURN FALSE
		END;
		IF EnableTrace THEN PrintCardStatus(r1) END;

		(*t := SdEnvironment.GetTimeCounter();
		tt := t + SdEnvironment.FromMilli(1000);*)
		(*WHILE ({Interrupt_Normal_TransferComplete, Interrupt_Normal_ErrorInterrupt, Interrupt_Error_Adma} * status = {}) (*& (SdEnvironment.GetTimeCounter() <= tt)*) DO
			status := hc.regs.InterruptStatus
		END;*)
		(*IF SdEnvironment.GetTimeCounter() > tt(*{Interrupt_Normal_TransferComplete, Interrupt_Normal_ErrorInterrupt} * status = {}*) THEN*)
		IF ~hc.block(hc, {Interrupt_Normal_TransferComplete, Interrupt_Normal_ErrorInterrupt}, command.dataTimeout * 1000) THEN
			Log.String("[SD] Error: timeout has expired!"); Log.Ln;
			PrintHcRegisters(hc.regs);
			IF Synchronize THEN hc.release END;
			HALT(512);
			RETURN FALSE;
		END;
		(*!stop := SdEnvironment.GetTimeCounter();*)
		status := hc.regs.InterruptStatus;

		IF Interrupt_Normal_ErrorInterrupt IN status THEN
			IF ErrorRecovery(hc, result, status) THEN END;
			IF Interrupt_Error_DataTimeout IN status THEN
				result := ErrorDatTimeout;
				IF ~Reset(hc, FALSE, TRUE) THEN END
			ELSIF Interrupt_Error_DataCrc IN status THEN
				result := ErrorDatCrc
			ELSIF Interrupt_Error_DataEndBit IN status THEN
				result := ErrorCard
			ELSIF Interrupt_Error_Adma IN status THEN
				HALT(182)
			END;
			IF Synchronize THEN hc.release END;
			RETURN FALSE
		END;
		hc.regs.InterruptStatus := status;
		IF FlagRead IN command.flags THEN
			SdEnvironment.InvalidateDCacheRange(address, len)
		END;
		(*!IF FlagRead IN command.flags THEN
			INC(Tread, stop - start);
		ELSE
			INC(Twrite, stop - start);
		END;*)
		IF Synchronize THEN hc.release END;
		RETURN TRUE
	END ExecuteAdmaCommand;

	(** Get the response registers in 'response' *)
	PROCEDURE GetResponse (hc: HostController; responseType: LONGINT; VAR response: ARRAY 4 OF LONGINT);
	BEGIN
		response := hc.regs.Response
	END GetResponse;

	(** Issue an SD Card Transaction. [Simplified specs. 3.7.1.1 pp. 106-108] *)
	PROCEDURE StartCommand (hc: HostController; cmd, argument, responseType: LONGINT; read, dma, busy, abort: BOOLEAN; VAR status: SET; VAR result: WORD): BOOLEAN;
	VAR
		t: HUGEINT;
		reg: LONGINT;
		flags, txFlags: SET;
	BEGIN
		IF EnableTraceCmd THEN
			Log.String("[SD] Sending Command CMD"); Log.Int(cmd, 0); Log.Ln;
			Log.String("[SD]	Argument: "); Log.Hex(argument, -8); Log.Ln
		END;

		(* 1 *)
		t := SdEnvironment.GetTimeCounter() + SdEnvironment.FromMilli(1000);
		WHILE (PresentState_CommandInhibitCmd IN hc.regs.PresentState) & (t > SdEnvironment.GetTimeCounter()) DO END;
		IF t < SdEnvironment.GetTimeCounter() THEN
			Log.String("[SD] Timeout error in StartCommand (1)");
			Log.Ln;
			PrintHcRegisters(hc);
			RETURN FALSE
		END;

		(* 2 *)
		IF busy THEN
			(* 3 *)
			IF ~abort THEN
				(* 4 *)
				t := SdEnvironment.GetTimeCounter() + SdEnvironment.FromMilli(1000);
				WHILE (PresentState_CommandInhibitDat IN hc.regs.PresentState) & (t > SdEnvironment.GetTimeCounter()) DO END;
				IF t < SdEnvironment.GetTimeCounter() THEN
					Log.String("[SD] Timeout error in StartCommand (2)");
					Log.Ln;
					PrintHcRegisters(hc);
					RETURN FALSE
				END;
			END
		END;

		(* 5 *)
		hc.regs.Argument1 := argument;

		(* 6 *)
		(* The response type determines the response-type and CRC/Index checks enabling *)
		CASE responseType OF
			 ResponseNone:
			 	reg := Command_ResponseType_None;
			 	IF EnableTraceCmd THEN
			 		Log.String("[SD]	No Response Expected");
				 	Log.Ln
				 END
			|ResponseR1, ResponseR5, ResponseR6, ResponseR7:
				reg := Command_ResponseType_48b;
				flags := {Command_CrcCheckEnable, Command_IndexCheckEnable};
				IF EnableTraceCmd THEN
					Log.String("[SD]	48 Bit Response"); Log.Ln;
					Log.String("[SD]	Enabling CRC Check and Index Check"); Log.Ln
				END
			|ResponseR3, ResponseR4:
				reg := Command_ResponseType_48b;
				IF EnableTraceCmd THEN Log.String("[SD]	48 Bit Response"); Log.Ln END
			|ResponseR1b, ResponseR5b:
				reg := Command_ResponseType_48bBusy;
				flags := {Command_CrcCheckEnable, Command_IndexCheckEnable};
				IF EnableTraceCmd THEN
					Log.String("[SD]	48 Bit Response"); Log.Ln;
					Log.String("[SD]	Enabling Index Check"); Log.Ln
				END
			|ResponseR2:
				reg := Command_ResponseType_136b;
				flags := {Command_CrcCheckEnable};
				IF EnableTraceCmd THEN
					Log.String("[SD]	136 Bit Response"); Log.Ln;
					Log.String("[SD]	Enabling Command CRC Check"); Log.Ln
				END
		END;

		(* Command determines data-enable *)
		IF busy THEN
			INCL(flags, Command_DataPresent);
			IF EnableTraceCmd THEN Log.String("[SD]	Using DAT Line"); Log.Ln END;

			txFlags := {};
			IF (*(cmd = CMD_READ_SINGLE_BLOCK) OR (cmd = CMD_READ_MULTIPLE_BLOCK) OR (cmd = ACMD_SEND_SCR)*) read THEN
				IF EnableTraceCmd THEN Log.String("[SD] 	Data Read"); Log.Ln END;
				INCL(txFlags, TransferMode_DataTxDirection)
			ELSIF EnableTraceCmd THEN
				Log.String("[SD] 	Data Write");
				Log.Ln
			END;
			IF (cmd = CMD_READ_MULTIPLE_BLOCK) OR (cmd = CMD_WRITE_MULTIPLE_BLOCK) THEN
				IF EnableTraceCmd THEN Log.String("[SD] 	Multiple blocks: using Auto CMD12 & activating block count"); Log.Ln END;
				txFlags := txFlags + TransferMode_AutoCmd_Cmd12 + {TransferMode_MultipleBlocks, TransferMode_BlockCountEnable}
			ELSIF EnableTraceCmd THEN
				Log.String("[SD] 	Single Block");
				Log.Ln
			END;
			IF dma THEN INCL(txFlags, TransferMode_DmaEnable) END;
			hc.regs.TransferMode := SYSTEM.VAL(INTEGER, txFlags)
		END;
		hc.regs.Command := SYSTEM.VAL(INTEGER, SYSTEM.VAL(SET, reg + LSH(cmd, Command_CommandIndexOffset)) + flags);

		(* 7 *)
		RETURN WaitForCompletion(hc, ~abort, status, result)
		(* Steps 7, 8 and 9 of WaitForCompletion have to be done by caller *)
	END StartCommand;

	(**
		Perform error recovery as specified by the triggered error interrupts.
		Returns an error code (result) and the interrupt status register before recovery (status)
	*)
	PROCEDURE ErrorRecovery (hc: HostController; VAR result: WORD; VAR status: SET): BOOLEAN;
	BEGIN
		(* 1 is done *)
		status := hc.regs.InterruptStatus;
		hc.regs.InterruptStatusEnable := {0 .. 14};
		EXCL(hc.regs.InterruptStatusEnable, Interrupt_Normal_ErrorInterrupt);
		EXCL(hc.regs.InterruptStatusEnable, Interrupt_Normal_ErrorInterrupt);
		EXCL(hc.regs.InterruptStatusEnable, Interrupt_Normal_ErrorInterrupt);

		(* 2 *)
		IF (Interrupt_Error_CommandTimeout IN status) OR (Interrupt_Error_CommandCrc IN status) OR (Interrupt_Error_CommandEndBit IN status)
				OR (Interrupt_Error_CommandIndex IN status) THEN
			(* 3 & 4 *)
			IF ~Reset(hc, TRUE, FALSE) THEN
				result := ErrorUnrecoverable;
				RETURN FALSE
			END
		END;

		(* 5 *)
		IF Interrupt_Error_DataTimeout IN status THEN
			Log.String("[SD]	Got data timeout error"); Log.Ln
		END;
		IF (Interrupt_Error_DataTimeout IN status) OR (Interrupt_Error_DataCrc IN status) OR (Interrupt_Error_DataEndBit IN status) THEN
			(* 6 & 7 *)
			IF ~Reset(hc, FALSE, TRUE) THEN
				result := ErrorUnrecoverable;
				RETURN FALSE
			END
		END;

		(* 8 & 9 *)
		hc.regs.InterruptStatus := status;

		(* 10 & 11 *)
		(*IF ~Command(hc, CMD_STOP_TRANSMISSION, 0, ResponseR1b, FALSE, TRUE, result) THEN
			(* 12 *)
			IF (Interrupt_Error_CommandTimeout IN status) OR (Interrupt_Error_CommandCrc IN status) OR (Interrupt_Error_CommandEndBit IN status)
					OR (Interrupt_Error_CommandIndex IN status) THEN
				TRACE('CMD12 CMD LINE ERROR');
				result := ErrorUnrecoverable;
				RETURN FALSE
			END;
			(* 13 *)
			IF ~WaitForTransfer(hc, result) THEN
				result := ErrorUnrecoverable;
				RETURN FALSE
			END;
			TRACE(hc.regs.BufferData);
		END;
		(* 15 *)
		IF hc.regs.PresentState * PresentState_DatLineSignalLevelMask # PresentState_DatLineSignalLevelMask THEN
			TRACE('CMD12 DAT LINE ERROR');
			result := ErrorUnrecoverable;
			RETURN FALSE
		END;*)
		hc.regs.InterruptStatusEnable := {0 .. 31};
		INCL(hc.regs.InterruptStatusEnable, Interrupt_Normal_ErrorInterrupt);
		result := ErrorNone;
		RETURN TRUE
	END ErrorRecovery;

	(** Wait for completion of an SD command [Simplified specs. 3.7.1.2 pp. 109-110 *)
	PROCEDURE WaitForCompletion (hc: HostController; tryRecover: BOOLEAN; 	VAR status: SET; VAR result: WORD): BOOLEAN;
	BEGIN
		result := ErrorNone;

		(* 1 *)
		IF ~hc.block(hc, {Interrupt_Normal_CommandComplete, Interrupt_Normal_ErrorInterrupt}, DefaultTimeout) THEN
			Log.String("[SD] Timeout while waiting for completion");
			Log.Ln;
			PrintHcRegisters(hc);
			RETURN FALSE
		END;
		status := hc.regs.InterruptStatus;

		IF Interrupt_Normal_ErrorInterrupt IN status THEN
			IF ~tryRecover THEN
				hc.regs.InterruptStatus := status;
				result := ErrorUnrecoverable;
				RETURN Reset(hc, TRUE, FALSE) & Reset(hc, FALSE, TRUE)
			END;
			IF ~ErrorRecovery(hc, result, status) THEN RETURN FALSE END;
			IF Interrupt_Error_CommandTimeout IN status THEN
				IF EnableTraceCmd THEN Log.String("[SD] 	Timeout in command"); Log.Ln END;
				result := ErrorCmdTimeout;
				IF ~Reset(hc, TRUE, FALSE) THEN END;
			ELSIF Interrupt_Error_CommandCrc IN status THEN
				result := ErrorCmdCrc;
			ELSE
				result := ErrorCard;
			END;
			RETURN FALSE
		END;

		(* 2 *)
		hc.regs.InterruptStatus := {Interrupt_Normal_CommandComplete};

		IF EnableTraceCmd THEN Log.String("[SD] 	Command successful"); Log.Ln END;
		RETURN TRUE
	END WaitForCompletion;

	(** Wait for transfer complete interrupt *)
	PROCEDURE WaitForTransfer (hc: HostController; VAR result: WORD): BOOLEAN;
	VAR
		status: SET;
	BEGIN
		(* 5 *)
		IF ~hc.block(hc, {Interrupt_Normal_TransferComplete, Interrupt_Normal_ErrorInterrupt}, DefaultTimeout) THEN
			Log.String("[SD] Timeout failed in WaitForTransfer");
			RETURN FALSE;
		END;
		(*REPEAT UNTIL (Interrupt_Normal_TransferComplete IN hc.regs.InterruptStatus) OR (Interrupt_Normal_ErrorInterrupt IN hc.regs.InterruptStatus);*)
		status := hc.regs.InterruptStatus;

		IF Interrupt_Normal_ErrorInterrupt IN hc.regs.InterruptStatus THEN
			IF ~ErrorRecovery(hc, result, status) THEN RETURN FALSE END;
			result := ErrorCard;
			RETURN FALSE
		END;

		(* 6 *)
		(*INCL(hc.regs.InterruptStatus, Interrupt_Normal_TransferComplete)*)
		hc.regs.InterruptStatus := {Interrupt_Normal_TransferComplete}
	END WaitForTransfer;

	PROCEDURE SpinBlock (hc: HostController; mask: SET; timeout: LONGINT): BOOLEAN;
	VAR
		deadline: SdEnvironment.Time;
	BEGIN
		deadline := SdEnvironment.GetTimeCounter() + SdEnvironment.FromMilli(timeout);
		REPEAT UNTIL (mask * hc.regs.InterruptStatus # {}) OR (SdEnvironment.GetTimeCounter() > deadline);
		RETURN mask * hc.regs.InterruptStatus # {}
	END SpinBlock;

	(** Sends CMD7 if necessary to select the given card *)
	PROCEDURE SelectCard * (hc: HostController; card: LONGINT; VAR result: WORD): BOOLEAN;
	VAR
		command: Command;
		status: SET;
	BEGIN
		result := ErrorNone;
		IF hc.lastRca = card THEN
			IF EnableTrace THEN
				Log.String("[SD] Card Already Selected");
				Log.Ln
			END;
			RETURN TRUE
		END;

		IF EnableTrace THEN Log.String("[SD] Selecting Card "); Log.Int(card, 0); Log.Ln END;
		command.hc := hc;
		command.command := CMD_SELECT_DESELECT_CARD;
		command.argument := LSH(card, 16);
		command.responseType := ResponseR1b;
		IF ~hc.execute(command, result) THEN RETURN FALSE END;
		status := GetR1(command);
		IF CardStatus_Error IN status THEN result := ErrorCard; RETURN FALSE END;
		RETURN TRUE
	END SelectCard;

	(** Deselects all cards *)
	PROCEDURE DeselectCards * (hc: HostController; VAR result: WORD): BOOLEAN;
	VAR
		command: Command;
		ignoreRes: WORD;
		ignoreBool: BOOLEAN;
	BEGIN
		result := ErrorNone;
		IF hc.lastRca = 0 THEN
			IF EnableTrace THEN Log.String("[SD] No card selected"); Log.Ln END;
			RETURN TRUE
		END;

		IF EnableTrace THEN Log.String("[SD] Deselecting cards"); Log.Ln END;
		command.hc := hc;
		command.command := CMD_SELECT_DESELECT_CARD;
		command.responseType := ResponseR1b;
		ignoreBool := hc.execute(command, ignoreRes);
		hc.lastRca := 0;
		RETURN TRUE
	END DeselectCards;

	(** Read response R1 or R1b from command record *)
	PROCEDURE GetR1 * (CONST command: Command): SET;
	VAR
		idx: LONGINT;
	BEGIN
		idx := 0;
		(*IF (FlagAutoCmd12 IN command.flags) OR (FlagAutoCmd23 IN command.flags) THEN
			idx := 3
		END;*)
		RETURN SYSTEM.VAL(SET, command.response[idx])
	END GetR1;

	(** Read response R2 from command record *)
	PROCEDURE GetR2 * (CONST command: Command; VAR response: ARRAY OF LONGINT);
	VAR
		i: LONGINT;
	BEGIN
		FOR i := 0 TO 3 DO
			response[i] := command.response[i]
		END
	END GetR2;

	(** Read response R3 from command record *)
	PROCEDURE GetR3 * (CONST command: Command): LONGINT;
	BEGIN
		RETURN command.response[0]
	END GetR3;

	(** Read response R4 from command record *)
	PROCEDURE GetR4 * (CONST command: Command): LONGINT;
	BEGIN
		RETURN command.response[0]
	END GetR4;

	(** Read response R5 from command record *)
	PROCEDURE GetR5 * (CONST command: Command): LONGINT;
	BEGIN
		RETURN command.response[0]
	END GetR5;

	(** Read response R6 from command record *)
	PROCEDURE GetR6 * (CONST command: Command): LONGINT;
	BEGIN
		RETURN command.response[0]
	END GetR6;

	(** Read response R7 from command record *)
	PROCEDURE GetR7 * (CONST command: Command): LONGINT;
	BEGIN
		RETURN command.response[0]
	END GetR7;

	(** Reset command and/or data lines of a host controller *)
	PROCEDURE Reset (hc: HostController; cmd, dat: BOOLEAN): BOOLEAN;
	VAR
		val: SHORTINT;
	BEGIN
		IF cmd & dat THEN
			val := SoftwareResetAll
		ELSIF cmd THEN
			val := SoftwareResetCmd
		ELSIF dat THEN
			val := SoftwareResetDat
		ELSE
			RETURN FALSE
		END;
		hc.regs.SoftwareReset := val;
		REPEAT
		UNTIL hc.regs.SoftwareReset # val;
		RETURN TRUE
	END Reset;

	(** Set host controller bust clock *)
	PROCEDURE SetBusClock (hc: HostController; freq: LONGINT);
	VAR
		val: LONGINT;
	BEGIN
		hc.regs.ClockControl := 0;

		IF freq < hc.baseFrequency THEN

			val := 1;
			WHILE (val < 8) & (LSH(hc.baseFrequency,-val) > freq) DO
				INC(val);
			END;

			IF EnableTrace THEN
				Log.String(" [SD] baseFreq=");
				Log.Int(hc.baseFrequency, 0);
				Log.String(", val=");
				Log.Int(val, 0);
				Log.Ln
			END;

			hc.regs.ClockControl := INTEGER(LSH(LSH(LONGINT(1), val-1), 8) + SYSTEM.VAL(INTEGER, {ClockControl_InternalClockEnable}));
			hc.frequency := LSH(hc.baseFrequency, -val);
		ELSE
			hc.regs.ClockControl := SYSTEM.VAL(INTEGER, {ClockControl_InternalClockEnable});
			hc.frequency := hc.baseFrequency;
		END;

		REPEAT val := hc.regs.ClockControl UNTIL ClockControl_InternalClockState IN SYSTEM.VAL(SET, val);
		val := hc.regs.ClockControl;
		hc.regs.ClockControl := SYSTEM.VAL(INTEGER, SYSTEM.VAL(SET, val) + {ClockControl_SdClockEnable});
		IF EnableTrace THEN
			Log.String("[SD] Selecting Bus Clock Frequency: ");
			Log.Int(hc.frequency, 0); Log.String(" Hz");
			Log.Ln
		END;
	END SetBusClock;

	(** Set host controller data timeout, in ms *)
	PROCEDURE SetTimeout (hc: HostController; timeout: LONGINT);
	VAR
		ratio, val: LONGINT;
	BEGIN
		EXCL(hc.regs.InterruptStatusEnable, Interrupt_Error_DataTimeout);
		ratio := LSH(LONGINT(hc.timeoutFrequency * timeout DIV 1000), -13);
		val := 0;
		WHILE (val < 15) & (LSH(LONGINT(1), val) < ratio) DO INC(val) END;
		ASSERT(LSH(LONGINT(1), val) >= ratio);
		hc.regs.TimeoutControl := SYSTEM.VAL(SHORTINT, val);
		INCL(hc.regs.InterruptStatusEnable, Interrupt_Error_DataTimeout)
	END SetTimeout;

	(** Set the data bus width for a given RCA. *)
	PROCEDURE SetBusWidth (hc: HostController; card: Card; width: LONGINT; VAR result: WORD): BOOLEAN;
	VAR
		command: Command;
		val: LONGINT;
	BEGIN
		IF ~SelectCard(card.hc, card.rca, result) THEN RETURN FALSE END;

		(*command.hc := card.hc;
		command.command := ACMD_SET_CLR_CARD_DETECT;
		command.argument := 0;
		command.responseType := ResponseR1;
		command.flags := {FlagApplicationCmd};
		command.rca := card.rca;
		IF ~ExecuteCommand(command, result) THEN RETURN FALSE END;*)

		(* 1 *)
		EXCL(hc.regs.InterruptStatusEnable, Interrupt_Normal_CardInterrupt);

		(* 2: driver supports SD cards only *)
		(* 3: not implemented *)

		(* 4 *)
		command.command := ACMD_SET_BUS_WIDTH;
		CASE width OF
			 1: command.argument := 0
			|4: command.argument := 2
		END;
		command.hc := hc;
		command.rca := card.rca;
		command.flags := {FlagApplicationCmd};
		command.responseType := ResponseR1;
		IF ~ExecuteCommand(command, result) THEN RETURN FALSE END;

		(* 5 *)
		val := hc.regs.HostControl1;
		CASE width OF
			 1: EXCL(SYSTEM.VAL(SET, val), HostControl1_DataTransferWidth)
			|4: INCL(SYSTEM.VAL(SET, val), HostControl1_DataTransferWidth)
		END;
		hc.regs.HostControl1 := SHORTINT(val);

		(* 6: SD card only *)
		(* 8 *)
		INCL(hc.regs.InterruptStatusEnable, Interrupt_Normal_CardInterrupt);
		RETURN TRUE
	END SetBusWidth;

	(** Executes a switch function command *)
	PROCEDURE SwitchFunc (card: Card; switch: BOOLEAN; funcs: ARRAY 6 OF LONGINT; VAR sts: SwitchFuncStatus; VAR res: WORD): BOOLEAN;
	VAR
		status: ARRAY 64 OF CHAR;
		command: Command;

		PROCEDURE GetStatus (CONST status: ARRAY OF CHAR; VAR sts: SwitchFuncStatus);
		VAR
			i: LONGINT;
		BEGIN
			sts.current := LONGINT(ORD(status[0])) * 100H + LONGINT(ORD(status[1]));
			FOR i := 0 TO 5 DO
				sts.functionGroups[i] := SYSTEM.VAL(SET, LONGINT(ORD(status[2 + 2 * (5 - i)])) * 100H + LONGINT(ORD(status[1 + 2 + 2 * (5 - i)])))
			END;
			FOR i := 0 TO 5 BY 2 DO
				sts.functionStatus[i] := ORD(status[14 + 2 - i DIV 2]) MOD 10H;
				sts.functionStatus[i + 1] := ORD(status[14 + 2 - i DIV 2]) DIV 10H
			END;
		END GetStatus;

	BEGIN
		IF ~SelectCard(card.hc, card.rca, res) THEN RETURN FALSE END;
		command.hc := card.hc;
		command.command := CMD_SWITCH_FUNC;
		command.responseType := ResponseR1;
		command.argument := (funcs[0] MOD 10H) + 10H * (funcs[1] MOD 10H) + 100H * (funcs[2] MOD 10H) + 1000H * (funcs[3] MOD 10H) + 10000H * (funcs[4] MOD 10H) + 100000H * (funcs[5] MOD 10H);
		IF switch THEN INCL(SYSTEM.VAL(SET, command.argument), 31) END;
		command.flags := {FlagRead, FlagData};
		command.dataTimeout := card.readTimeout;
		IF ~card.hc.transfer(command, status, 0, 64, res) THEN RETURN FALSE END;
		GetStatus(status, sts);
		RETURN TRUE
	END SwitchFunc;

	(** Outputs the switch function status on the log *)
	PROCEDURE PrintSwitchFuncStatus(CONST status: SwitchFuncStatus);
	VAR
		i: LONGINT;
	BEGIN
		Log.String("Switch Func Status");
		Log.Ln;
		Log.String("Current = ");
		IF status.current = 0 THEN
			Log.String("ERROR")
		ELSE
			Log.Int(status.current, 0);
			Log.String(" mA");
			Log.Ln
		END;
		FOR i := 0 TO 5 DO
			Log.String("Function Group #");
			Log.Int(i, 0);
			Log.String(": functions = ");
			Log.Set(status.functionGroups[i]);
			Log.String(", status = ");
			CASE status.functionStatus[i] OF
				 0: Log.String("switchable")
				|1: Log.String("switched")
				|0FH: Log.String("ERROR")
			END;
			Log.Ln
		END
	END PrintSwitchFuncStatus;

	(** Interrupt handler *)
	PROCEDURE HandleInterrupt * (hc: HostController);
	VAR
		card: Card;
		result: WORD;
		interruptStatus: SET;
	BEGIN
		interruptStatus := hc.regs.InterruptStatus;

		(*IF {Interrupt_Normal_TransferComplete, Interrupt_Normal_ErrorInterrupt} * interruptStatus # {} THEN
			BEGIN {EXCLUSIVE} continue := TRUE END;
			RETURN
		END;*)

		(*!TODO: make interrupt handling as quick as possible - handle all events in SdControllers asynchronously! *)
		IF Interrupt_Normal_CardInsertion IN interruptStatus THEN
			hc.regs.InterruptStatus := {Interrupt_Normal_CardInsertion};
			IF EnableTrace THEN Log.String("[SD] Card Insertion"); Log.Ln END;
			NEW(card);
			IF InitCard(hc, card, result) & (hc.handle # NIL) THEN
				hc.handle(card, OnInitialization, hc.handlerParam)
			ELSIF EnableTrace THEN
				Log.String("[SD] Could not initialize card"); Log.Ln
			END
		ELSIF Interrupt_Normal_CardRemoval IN interruptStatus THEN
			hc.regs.InterruptStatus := {Interrupt_Normal_CardRemoval};
			IF EnableTrace THEN Log.String("[SD] Card Removal"); Log.Ln END;
			card := hc.cards;
			IF hc.handle # NIL THEN hc.handle(card, OnRemoval, hc.handlerParam) END;
			hc.cards := hc.cards.next
		END;
	END HandleInterrupt;

(* ==================== Card (High-Level) Interface ==================== *)
TYPE
	(** Card descriptor *)
	Card * = POINTER TO CardDesc;
	CardDesc * = RECORD
		state -, (** Card state. Currently not used *)
		rca -: LONGINT; (** Card RCA *)
		cid -: Cid; (** CID *)
		csd -: Csd; (** CSD *)
		scr -: Scr; (** SCR *)
		sdStatus -: SdStatus; (** Current SD status for this card *)
		hc -: HostController; (** Host controller on which the card is attached *)
		acquire *, release *: PROCEDURE {DELEGATE}; (** Used for synchronization *)
		readTimeout, (** Read timeout computed for this card, in ms *)
		writeTimeout, (** Write timeout computed for this card, in ms *)
		eraseTimeout: LONGINT; (** Erase timeout computed for this card, in ms *)
		next: Card; (** Internal linked list of cards attached to the same HC *)
	END;

	(** SD Status *)
	SdStatus * = RECORD
		dataBusWidth -: LONGINT; (** Number of DAT bus lines currently used by card *)
		securedMode -: BOOLEAN; (** Is card in secured mode? *)
		cardType -: LONGINT; (** Card type, one of Category* *)
		sizeProtArea -: HUGEINT; (** Size of the protected area, in bytes *)
		perfMove -: LONGINT; (** Performance of move, in MB/s. 0 means 'sequential write', 255 means 'infinity' *)
		eraseSize -: LONGINT; (** Numbers of AUs erased at a time. 0 means not supported *)
		eraseTimeout -: LONGINT; (** Erase timeout value in second, per erase unit. 0 means not supported *)
		eraseOffset -: LONGINT; (** Fixed timeout for erase timeout, in second *)
		speedClass -: LONGINT; (** 3.x V speed class: 0 is 'unknown', 2, 4, 6 or 10 *)
		auSize -: LONGINT; (** AU size for 3.x V *)
		uhsSpeedGrade -: LONGINT; (** UHS speed grade: 0 is 'not supported', 1 or 3 *)
		uhsAuSize -: LONGINT; (** AU size in UHS mode *)
		vscSpeedClass -: LONGINT; (** Video mode speed class: 0 is 'not supported', 6, 10, 30, 60 or 90 *)
		vscAuSize -: LONGINT; (** AU size in video mode *)
		suspensionAdr -: LONGINT; (** Current suspension address, in blocks. See CMD20 *)
		appPerfClass -: LONGINT; (** Application performance class: 0 is 'not supported', 1 or 2 *)
		perfEnhance -: SET; (** Performance enhancing features of the card. Contains Performance* *)
		commandQueueDepth -: LONGINT; (** Command queue depth. Valid only if PerformanceCommandQueue IN perfEnhance *)
		discardSupport -: BOOLEAN; (** Card supports discard? *)
		fuleSupport -: BOOLEAN; (** card supports FULE? *)
	END;

	(** Card Identification register *)
	Cid * = RECORD
		manufacturingDate -: RECORD (** Manufacturing date, with year and month *)
			year -,
			month -: LONGINT
		END;
		productSerialNumber -: ADDRESS; (** Serial number *)
		productRevision -: RECORD (** Revision n.m *)
			n-, m-: LONGINT
		END;
		productName -: ARRAY 6 OF CHAR; (** Product name *)
		oemId -: ARRAY 3 OF CHAR; (** OEM/Application ID *)
		manufacturerId -: LONGINT; (** Manufacturer identifier *)
	END;

	(* Card Registers *)
	Csd * = RECORD
		(* Card properties *)
		capacity -: HUGEINT; (** Card capacity in bytes *)
		commandClasses -: SET; (** Command classes supported by the card *)

		(* Timing info *)
		r2w -: LONGINT; (** Read to write time factor = read time / write time *)
		taac -: REAL; (** Asynchronous access time, in s *)
		nsac -: LONGINT; (** Worst-case clock dependent access time, in clock cycles *)
		txSpeed -: LONGINT; (** Max transfer speed in bit/s *)

		(* Block read properties *)
		partialRead -,
		misalignedRead -: BOOLEAN;
		readBlockSize -: LONGINT;

		(* Block write properties *)
		partialWrite -,
		misalignedWrite -: BOOLEAN;
		writeBlockSize -: LONGINT;
	END;

	(** SCR register *)
	Scr * = RECORD
		version -, (** Card physical spec. version: one of Version* *)
		security -: LONGINT; (** Card security type: one of Type* *)
		busWidth -: SET; (** Bus widths supported by the card *)
		commandSupport -: SET; (** Supported commands *)
	END;

	(**
		Initializes a new card on the host controller.
		Executes all commands until either an error occurs or the card is ready for data transfers.
	*)
	PROCEDURE InitCard * (hc: HostController; card: Card; VAR result: WORD): BOOLEAN;
	VAR
		response: LONGINT;
		status: SET;
		f8, sdio: BOOLEAN;
		command: Command;
	BEGIN
		SetBusClock(hc, InitialClockFrequency);

		FOR response := 0 TO 10000000 DO END;
		command.hc := hc;

		(* 1 *)
		command.command := CMD_GO_IDLE_STATE;
		command.argument := 0;
		command.responseType := ResponseNone;
		command.flags := {};
		IF ~ExecuteCommand(command, result) THEN RETURN FALSE END;
		(* 2 *)
		command.command := CMD_SEND_IF_COND;
		command.argument := 1AAH;
		command.responseType := ResponseR7;
		command.flags := {};
		IF ~ExecuteCommand(command, result) THEN RETURN FALSE END;
		(* 3 *)
		response := GetR7(command);
		IF response # 1AAH THEN
			result := ErrorCard;
			RETURN FALSE
		END;
		f8 := TRUE;

		(* 5 *)
		command.command := CMD_IO_SEND_OP_COND;
		command.argument := 0;
		command.responseType := ResponseR4;
		command.flags := {};
		IF ~ExecuteCommand(command, result) & (result = ErrorCmdTimeout) THEN
			sdio := FALSE;
			result := ErrorNone;
			IF ~Reset(hc ,TRUE, FALSE) THEN RETURN FALSE END;
		ELSIF result # ErrorNone THEN
			RETURN FALSE
		ELSE
			sdio := TRUE;
		END;
		IF EnableTrace THEN Log.String("[SD] Card is SDIO: "); Log.Boolean(sdio); Log.Ln END;

		(* 6 *)
		IF sdio THEN
			(*! NOT IMPLEMENTED YET *)
			HALT(100);
			(* 7 *)
			(*IF ~StartCommand(hc, CMD_IO_SEND_OP_COND, 800H, ResponseR4, FALSE, FALSE, res) THEN
				RETURN FALSE
			END;
			RETURN TRUE*)
		END;

		(* A *)
		(* 12 & 19 *)
		command.command := ACMD_SD_SEND_OP_COND;
		command.argument := 0;
		command.responseType := ResponseR3;
		command.flags := {FlagApplicationCmd, FlagIgnoreIllegalCmd};
		IF ~ExecuteCommand(command, result) THEN RETURN FALSE END;
		response := GetR3(command);
		IF EnableTrace THEN
			Log.String("[SD] VDD: Ranges Supported by Card:"); Log.Ln;
			IF CardOcr_Vdd27_28 IN SYSTEM.VAL(SET, response) THEN Log.String("[SD] 	2.7 - 2.8 V"); Log.Ln END;
			IF CardOcr_Vdd28_29 IN SYSTEM.VAL(SET, response) THEN Log.String("[SD] 	2.8 - 2.9 V"); Log.Ln END;
			IF CardOcr_Vdd29_30 IN SYSTEM.VAL(SET, response) THEN Log.String("[SD] 	2.9 - 3.0 V"); Log.Ln END;
			IF CardOcr_Vdd30_31 IN SYSTEM.VAL(SET, response) THEN Log.String("[SD] 	3.0 - 3.1 V"); Log.Ln END;
			IF CardOcr_Vdd31_32 IN SYSTEM.VAL(SET, response) THEN Log.String("[SD] 	3.1 - 3.2 V"); Log.Ln END;
			IF CardOcr_Vdd32_33 IN SYSTEM.VAL(SET, response) THEN Log.String("[SD] 	3.2 - 3.3 V"); Log.Ln END;
			IF CardOcr_Vdd33_34 IN SYSTEM.VAL(SET, response) THEN Log.String("[SD] 	3.3 - 3.4 V"); Log.Ln END;
			IF CardOcr_Vdd34_35 IN SYSTEM.VAL(SET, response) THEN Log.String("[SD] 	3.4 - 3.5 V"); Log.Ln END;
			IF CardOcr_Vdd35_36 IN SYSTEM.VAL(SET, response) THEN Log.String("[SD] 	3.5 - 3.6 V"); Log.Ln END
		END;

		status := {30};
		IF Capabilities_Voltage30 IN hc.regs.Capabilities[0] THEN
			IF EnableTrace THEN Log.String("[SD] Selecting 3.0 V"); Log.Ln END;
			INCL(status, CardOcr_Vdd30_31)
		ELSIF Capabilities_Voltage33 IN hc.regs.Capabilities[0] THEN
			IF EnableTrace THEN Log.String("[SD] Selecting 3.3 V"); Log.Ln END;
			INCL(status, CardOcr_Vdd32_33)
		END;

		command.command := ACMD_SD_SEND_OP_COND;
		command.argument := SYSTEM.VAL(LONGINT, status);
		command.responseType := ResponseR3;
		command.flags := {FlagApplicationCmd, FlagIgnoreIllegalCmd};
		REPEAT
			IF ~ExecuteCommand(command, result) THEN RETURN FALSE END;
			status := SYSTEM.VAL(SET, GetR3(command));
		UNTIL (CardOcr_PowerUpStatus IN status);
		IF EnableTrace & (CardOcr_S18A IN status) THEN
			Log.String("[SD] Card supports 1.8V");
			Log.Ln
		END;
		IF f8 & (CardOcr_CardCapacityStatus IN status) THEN
			IF EnableTrace THEN Log.String("[SD] Card: SDHC or SDXC") END;
			card.scr.security := TypeSDHC
		ELSIF f8 THEN
			IF EnableTrace THEN Log.String("[SD] Card: SDSC v2 or v3") END;
			card.scr.security := TypeSDSC
		ELSE
			IF EnableTrace THEN Log.String("[SD] Card: SDSC v1.0 or v1.1") END;
			card.scr.security := TypeSDSC
		END;
		IF EnableTrace THEN Log.Ln END;

		(* 32 *)
		command.command := CMD_ALL_SEND_CID;
		command.argument := 0;
		command.responseType := ResponseR2;
		command.flags := {};
		IF ~ExecuteCommand(command, result) THEN RETURN FALSE END;
		DecodeCid(command.response, card.cid);
		PrintCardCid(card.cid);

		(* 33 *)
		command.command := CMD_SEND_RELATIVE_ADDR;
		command.argument := 0;
		command.responseType := ResponseR6;
		command.flags := {};
		REPEAT
			IF ~ExecuteCommand(command, result) THEN RETURN FALSE END;
			card.rca := LSH(GetR6(command), -16)
		UNTIL card.rca # 0;
		IF EnableTrace THEN Log.String("[SD] New Card with RCA: "); Log.Hex(card.rca, -4); Log.Ln END;
		status := SYSTEM.VAL(SET, GetR6(command));
		status := status * {0 .. 15};
		(* status is a modified CardStatus: reform corresponding card status *)
		IF 15 IN status THEN EXCL(status, 15); INCL(status, 23) END;
		IF 14 IN status THEN EXCL(status, 14); INCL(status, 22) END;
		IF 13 IN status THEN EXCL(status, 13); INCL(status, 19) END;
		IF EnableTrace THEN PrintCardStatus(status) END;
		card.hc := hc;
		card.next := hc.cards;
		hc.cards := card;
		IF Synchronize THEN SdEnvironment.GetLock(card.acquire, card.release) END;

		(* Get Additional card registers: CSD *)
		IF ~ReadCsd(card, result) THEN RETURN FALSE END;

		SetBusClock(hc, card.csd.txSpeed);
		(* Reasonable default timeout values, later rewritten with the ones given by the card *)
		card.readTimeout := 100;
		card.writeTimeout := 250;
		card.eraseTimeout := 250;

		(*IF ~Reset(hc, TRUE, FALSE) OR ~Reset(hc, FALSE, TRUE) THEN RETURN FALSE END;*)
		IF ~ReadScr(card, result) THEN RETURN FALSE END;
		ComputeTimeouts(card);

		IF (card.scr.version >= Version1p1) THEN
			IF EnableTrace THEN
				Log.String("[SD] Enabling high-speed mode");
				Log.Ln
			END;
			IF ~SelectSpeedMode(card, TRUE, result) THEN RETURN FALSE END;
			IF EnableTrace THEN
				Log.String("[SD] High-speed mode enabled");
				Log.Ln
			END;

			(* Get CSD again: transfer speed might have changed *)
			IF ~ReadCsd(card, result) THEN RETURN FALSE END;
			ComputeTimeouts(card);
			SetBusClock(hc, card.csd.txSpeed)
		END;

		IF 4 IN card.scr.busWidth THEN

			IF EnableTrace THEN
				Log.String("[SD] Changing bus width to 4 bits");
				Log.Ln
			END;

			IF ~SetBusWidth(card.hc, card, 4, result) THEN RETURN FALSE END;
			IF EnableTrace THEN
				Log.String("[SD] Bus width changed");
				Log.Ln
			END
		END;
		IF ~Reset(hc, TRUE, FALSE) OR ~Reset(hc, FALSE, TRUE) THEN RETURN FALSE END;
		GetSdStatus(card);

		(*ResetStatistics; NEW(testbuf);
		FOR response := 1 TO 100 DO
			IF ~Read(card, 33554432, LEN(testbuf), testbuf^, 0, result) THEN RETURN FALSE END;
			IF ~Write(card, 33554432, LEN(testbuf), testbuf^, 0, result) THEN RETURN FALSE END;
		END;
		Statistics(Commands.GetContext());
		HALT(512);*)
		RETURN TRUE
	END InitCard;

	(** Write 'data[ofs, ofs + len)' to 'card', starting at block 'firstBlock'. *)
	PROCEDURE Write * (card: Card; firstBlock, len: LONGINT; VAR data: ARRAY OF SYSTEM.BYTE; ofs: LONGINT; VAR result: WORD): BOOLEAN;
	VAR
		command: Command;
		start, stop: HUGEINT;
		ret: BOOLEAN;
	BEGIN
		result := ErrorNone;
		IF Synchronize THEN card.acquire END;
		start := SdEnvironment.GetTimeCounter();
		IF ~SelectCard(card.hc, card.rca, result) THEN
			IF Synchronize THEN card.release END;
			RETURN FALSE
		END;

		command.hc := card.hc;
		command.rca := card.rca;

		(* Pre-erase blocks *)
		command.command := ACMD_SET_WR_BLK_ERASE_COUNT;
		command.flags := {FlagApplicationCmd};
		command.responseType := ResponseR1;
		command.argument := (len + BlockSize - 1) DIV BlockSize;
		IF ~ExecuteCommand(command, result) THEN
			IF Synchronize THEN card.release END;
			RETURN FALSE
		END;

		command.argument := firstBlock;
		command.responseType := ResponseR1;
		command.flags := {FlagData};
		command.dataTimeout := card.writeTimeout;
		command.blockSize := card.csd.writeBlockSize;
		IF len > card.csd.writeBlockSize THEN
			INCL(command.flags, FlagMultipleBlockTx);
			INCL(command.flags, FlagCountBlocks);
			INCL(command.flags, FlagAutoCmd12);
			command.command := CMD_WRITE_MULTIPLE_BLOCK;
		ELSE
			command.command := CMD_WRITE_BLOCK
		END;
		ret := command.hc.transfer(command, data, ofs, len, result);
		stop := SdEnvironment.GetTimeCounter();
		IF Synchronize THEN card.release END;
		IF ret THEN
			INC(Nwrite);
			INC(NbyteWritten, len);
			INC(Twrite, stop - start)
		END;
		RETURN ret
	END Write;

	(** Read 'len' bytes starting from 'firstBlock' of 'card' to 'data[ofs, ofs + len)' *)
	PROCEDURE Read * (card: Card; firstBlock, len: LONGINT; VAR data: ARRAY OF SYSTEM.BYTE; ofs: LONGINT; VAR result: WORD): BOOLEAN;
	VAR
		command: Command;
		start, stop: HUGEINT;
		ret: BOOLEAN;
	BEGIN
		IF Synchronize THEN card.acquire END;
		start := SdEnvironment.GetTimeCounter();
		IF ~SelectCard(card.hc, card.rca, result) THEN
			IF Synchronize THEN card.release END;
			RETURN FALSE
		END;

		command.hc := card.hc;
		command.argument := firstBlock;
		command.responseType := ResponseR1;
		(*command.flags := {FlagData, FlagRead};*)
		command.rca := card.rca;
		command.dataTimeout := card.readTimeout;
		command.blockSize := card.csd.readBlockSize;
		IF len > card.csd.readBlockSize THEN
			command.flags := {FlagData, FlagRead, FlagMultipleBlockTx, FlagCountBlocks, FlagAutoCmd12};
			(*INCL(command.flags, FlagMultipleBlockTx);
			INCL(command.flags, FlagCountBlocks);
			INCL(command.flags, FlagAutoCmd12);*)
			command.command := CMD_READ_MULTIPLE_BLOCK
		ELSE
			command.flags := {FlagData, FlagRead};
			command.command := CMD_READ_SINGLE_BLOCK
		END;
		ret := command.hc.transfer(command, data, ofs, len, result) & ~(CardStatus_Error IN GetR1(command));
		stop := SdEnvironment.GetTimeCounter();
		IF Synchronize THEN card.release END;
		IF ret THEN
			INC(Nread);
			INC(NbyteRead, len);
			INC(Tread, stop - start)
		END;
		RETURN ret
	END Read;

	(** Erase blocks [block, block + num) on specified card. *)
	PROCEDURE Erase * (card: Card; block, num: LONGINT; VAR result: WORD): BOOLEAN;
	VAR
		command: Command;
		r1: SET;
	BEGIN
		command.hc := card.hc;
		command.flags := {};
		command.rca := card.rca;
		command.dataTimeout := card.eraseTimeout;

		command.responseType := ResponseR1;
		command.argument := block;
		command.command := CMD_ERASE_WR_BLK_START;
		IF ~ExecuteCommand(command, result) & (CardStatus_Error IN GetR1(command)) THEN RETURN FALSE END;

		command.argument := block + num - 1;
		command.command := CMD_ERASE_WR_BLK_END;
		IF ~ExecuteCommand(command, result) & (CardStatus_Error IN GetR1(command)) THEN RETURN FALSE END;

		command.argument := 0;
		command.command := CMD_ERASE;
		command.responseType := ResponseR1b;
		IF ~ExecuteCommand(command, result) & (CardStatus_Error IN GetR1(command)) THEN RETURN FALSE END;

		(*WHILE 20 IN card.hc.regs.PresentState DO END;*)
		command.command := CMD_SEND_STATUS;
		command.responseType := ResponseR1;
		REPEAT
			IF ~ExecuteCommand(command, result) THEN RETURN FALSE END;
			r1 := GetR1(command);
			IF CardStatus_Error IN r1 THEN RETURN FALSE END
		UNTIL CardStatus_ReadyForData IN r1;
		RETURN TRUE
	END Erase;

	PROCEDURE ReadCsd (card: Card; VAR result: WORD): BOOLEAN;
	VAR
		command: Command;
		csd: ARRAY 4 OF LONGINT;
	BEGIN
		result := ErrorNone;
		IF ~DeselectCards(card.hc, result) THEN RETURN FALSE END;

		command.hc := card.hc;
		command.command := CMD_SEND_CSD;
		command.argument := LSH(card.rca, 16);
		command.responseType := ResponseR2;
		command.flags := {};
		IF ~ExecuteCommand(command, result) THEN RETURN FALSE END;
		GetR2(command, csd);
		DecodeCsd(csd, card.csd);
		IF EnableTrace THEN
			PrintCardCsd(csd);
			Log.String("[SD] Card Capacity: ");
			PrintSize(card.csd.capacity);
			Log.Ln;
			Log.String("[SD] Bus frequency: "); Log.Int(card.csd.txSpeed, 0); Log.String(" Hz"); Log.Ln
		END;
		RETURN TRUE
	END ReadCsd;

	(** Read the SD card Configuration Register of a card *)
	PROCEDURE ReadScr (card: Card; VAR result: WORD): BOOLEAN;
	VAR
		command: Command;
		ofs: LONGINT;
		scr: ARRAY 8 OF CHAR;
	BEGIN
		IF ~SelectCard(card.hc, card.rca, result) THEN RETURN FALSE END;

		(*
			disconnect the pull-up resistor on D3 line (important for high-speed mode with 4 lines)
		*)
		(*command.hc := card.hc;
		command.command := ACMD_SET_CLR_CARD_DETECT;
		command.argument := 0;
		command.responseType := ResponseR1;
		command.flags := {FlagApplicationCmd};
		command.rca := card.rca;
		IF ~ExecuteCommand(command, result) THEN RETURN FALSE END;*)

		(* Get Card Register: SCR *)
		command.hc := card.hc;
		command.command := ACMD_SEND_SCR;
		command.argument := 0;
		command.responseType := ResponseR1;
		command.flags := {FlagApplicationCmd, FlagData, FlagRead};
		command.rca := card.rca;
		command.dataTimeout := card.readTimeout;
		(*ofs := 32 - ADDRESSOF(scr[0]) MOD 32;*)
		IF ~card.hc.transfer(command, scr, ofs, 8, result) THEN RETURN FALSE END;
		IF CardStatus_Error IN GetR1(command) THEN result := ErrorCard; RETURN FALSE END;
		DecodeScr(scr, ofs, card.scr);
		IF EnableTrace THEN PrintCardScr(card.scr) END;
		RETURN TRUE
	END ReadScr;

	PROCEDURE GetSdStatus (card: Card);
	TYPE Bitfield = ARRAY 16 OF LONGINT;
	VAR
		status: ARRAY 64 OF CHAR;
		command: Command;
		ignore: WORD;
		bitfield: POINTER {UNSAFE,UNTRACED} TO Bitfield;
		c: CHAR;
		i: LONGINT;
	BEGIN
		ASSERT(SelectCard(card.hc, card.rca, ignore));
		command.hc := card.hc;
		command.rca := card.rca;
		command.command := ACMD_SD_STATUS;
		command.flags := {FlagApplicationCmd, FlagData, FlagRead};
		command.responseType := ResponseR1;
		command.dataTimeout := card.readTimeout;
		IF ~card.hc.transfer(command, status, 0, LEN(status), ignore) THEN RETURN END;

		FOR i := 0 TO LEN(status) DIV 2 DO
			c := status[i];
			status[i] := status[LEN(status) - 1 - i];
			status[LEN(status) - 1 - i] := c
		END;

		bitfield := ADDRESSOF(status[0]);
		DecodeSdStatus(bitfield^, card.sdStatus);
		PrintSdStatus(card.sdStatus);
	END GetSdStatus;

	PROCEDURE GetCid (card: Card);
	VAR
		cid: Cid;
		command: Command;
		res: WORD;
	BEGIN
		IF ~DeselectCards(card.hc, res) THEN HALT(512) END;
		command.hc := card.hc;
		command.command := CMD_SEND_CID;
		command.argument := LSH(card.rca, 16);
		command.flags := {};
		command.responseType := ResponseR2;
		IF ~ExecuteCommand(command, res) THEN HALT(512) END;
		DecodeCid(command.response, cid);
		PrintCardCid(cid)
	END GetCid;

	(**
		Computes data timeouts for read, write and erase operations according to SD specifications.
		Stores them in card.readTimeout, writeTimeout, eraseTimeout.
	*)
	PROCEDURE ComputeTimeouts (card: Card);
	VAR
		readTime: LONGINT;
	BEGIN
		(*
			Read timeout is the lower of:
				o	(CSD.TAAC + CSD.NSAC / busfreq * 100) * TimeoutReadFactor
				o	TimeoutReadFix
			for a normal SD card and
				TimeoutReadFix
			for a SDHC card.

			Write timeout is very similar to read timeout, except that (CSD.TAAC + CSD.NSAC) * CSD.R2W is used.
		*)
		IF card.scr.version >= TypeSDHC THEN
			card.readTimeout := TimeoutReadFix;
			card.writeTimeout := TimeoutWriteFix
		ELSE
			readTime := 100 * LONGINT((card.csd.taac + REAL(card.csd.nsac * 100) / REAL(card.hc.frequency)) * 1000.0);
			card.readTimeout := MIN(readTime, TimeoutReadFix);
			card.writeTimeout := MIN(readTime * card.csd.r2w, TimeoutWriteFix);
		END;
		card.eraseTimeout := TimeoutErase;

		IF EnableTrace THEN
			Log.String("[SD] Read timeout = "); Log.Int(card.readTimeout, 0); Log.String(" ms"); Log.Ln;
			Log.String("[SD] Write timeout = "); Log.Int(card.writeTimeout, 0); Log.String(" ms"); Log.Ln;
			Log.String("[SD] Erase timeout = "); Log.Int(card.eraseTimeout, 0); Log.String(" ms"); Log.Ln
		END
	END ComputeTimeouts;

	(** Select card speed mode. It is necessary to set it to high in order to use higher bus clock frequencies. *)
	PROCEDURE SelectSpeedMode(card: Card; high: BOOLEAN; VAR res: WORD): BOOLEAN;
	VAR
		funcs: ARRAY 6 OF LONGINT;
		status: SwitchFuncStatus;
		val: SET;
	BEGIN
		funcs[0] := 1;
		IF ~SwitchFunc(card, FALSE, funcs, status, res) THEN RETURN FALSE END;
		IF EnableTrace THEN
			Log.String("[SD] Select speed, before:");
			Log.Ln;
			PrintSwitchFuncStatus(status)
		END;
		IF ~(1 IN status.functionGroups[0]) THEN
			Log.String("[SD] HIGH-SPEED MODE NOT SUPPORTED");
			Log.Ln;
			RETURN TRUE
		END;
		IF ~SwitchFunc(card, TRUE, funcs, status, res) THEN RETURN FALSE END;
		IF EnableTrace THEN
			Log.String("[SD] Select speed, after:");
			Log.Ln;
			PrintSwitchFuncStatus(status)
		END;
		val := SYSTEM.VAL(SET, LONGINT(card.hc.regs.HostControl1));
		IF high THEN
			INCL(val, HostControl1_HighSpeedEnable)
		ELSE
			EXCL(val, HostControl1_HighSpeedEnable)
		END;
		card.hc.regs.HostControl1 := SYSTEM.VAL(SHORTINT, val);
		RETURN TRUE
	END SelectSpeedMode;

	PROCEDURE DecodeSdStatus (CONST raw: ARRAY OF LONGINT; VAR status: SdStatus);
	VAR
		val: LONGINT;
	BEGIN
		val := ReadBitfield(raw, SdStatus_DatBusWidthOfs, SdStatus_DatBusWidthWidth);
		CASE val OF
			 0: status.dataBusWidth := 1
			|2: status.dataBusWidth := 4
		ELSE
			status.dataBusWidth := 0
		END;
		status.securedMode := ReadBit(raw, SdStatus_SecuredMode);
		val := ReadBitfield(raw, SdStatus_SdCardTypeOfs, SdStatus_SdCardTypeWidth);
		CASE val OF
			 0: status.cardType := CategoryRW
			|1: status.cardType := CategoryRO
			|2: status.cardType := CategoryOTP
		END;
		status.sizeProtArea := ReadBitfield(raw, SdStatus_SizeOfProtectedAreaOfs, SdStatus_SizeOfProtectedAreaWidth);
		(*! TODO: multiply sizeProtArea by MULT * BLOCK_LEN if SDSC *)
		val := ReadBitfield(raw, SdStatus_SpeedClassOfs, SdStatus_SpeedClassWidth);
		CASE val OF
			 0 .. 3: status.speedClass := 2 * val
			|4: status.speedClass := 10
		END;
		status.perfMove := ReadBitfield(raw, SdStatus_PerformanceMoveOfs, SdStatus_PerformanceMoveWidth);
		status.auSize := ReadBitfield(raw, SdStatus_AuSizeOfs, SdStatus_AuSizeWidth) * 16 * 1024;
		status.eraseSize := ReadBitfield(raw, SdStatus_EraseSizeOfs, SdStatus_EraseSizeWidth);
		status.eraseTimeout := ReadBitfield(raw, SdStatus_EraseTimeoutOfs, SdStatus_EraseTimeoutWidth);
		status.eraseOffset := ReadBitfield(raw, SdStatus_EraseOffsetOfs, SdStatus_EraseOffsetWidth);
		val := ReadBitfield(raw, SdStatus_UhsSpeedGradeOfs, SdStatus_UhsSpeedGradeWidth);
		CASE val OF
			0, 1, 3: status.uhsSpeedGrade := val
		END;
		status.uhsAuSize := ReadBitfield(raw, SdStatus_UhsAuSizeOfs, SdStatus_UhsAuSizeWidth) * 1024 * 1024;
		status.vscSpeedClass := ReadBitfield(raw, SdStatus_VideoSpeedClassOfs, SdStatus_VideoSpeedClassWidth);
		status.vscAuSize := ReadBitfield(raw, SdStatus_VscAuSizeOfs, SdStatus_VscAuSizeWidth) * 1024 * 1024;
		status.suspensionAdr := ReadBitfield(raw, SdStatus_SusAddrOfs, SdStatus_SusAddrWidth);
		status.appPerfClass := ReadBitfield(raw, SdStatus_AppPerfClassOfs, SdStatus_AppPerfClassWidth);
		val := ReadBitfield(raw, SdStatus_PerformanceEnhanceOfs, SdStatus_PerformanceEnhanceWidth);
		status.perfEnhance := SYSTEM.VAL(SET, val) * {PerformanceCardMaintenance .. PerformanceCache};
		IF SYSTEM.VAL(SET, val) * {3 .. MAX(SET)} # {} THEN
			INCL(status.perfEnhance, PerformanceQueue);
			status.commandQueueDepth := LSH(val, -3) + 1
		END;
		status.discardSupport := ReadBit(raw, SdStatus_DiscardSupport);
		status.fuleSupport := ReadBit(raw, SdStatus_FuleSupport)
	END DecodeSdStatus;

	PROCEDURE DecodeCid (CONST raw: ARRAY OF LONGINT; VAR cid: Cid);
	VAR
		val: LONGINT;
	BEGIN
		val := ReadBitfield(raw, CardCid_ProductManufacturingDateOfs, CardCid_ProductManufacturingDateWidth);
		cid.manufacturingDate.year := val DIV 10H + 2000;
		cid.manufacturingDate.month := val MOD 10H;
		cid.productSerialNumber := SYSTEM.VAL(ADDRESS, ReadBitfield(raw, CardCid_ProductSerialNbOfs, CardCid_ProductSerialNbWidth));
		val := ReadBitfield(raw, CardCid_ProductRevisionOfs, CardCid_ProductRevisionWidth);
		cid.productRevision.n := val DIV 10H;
		cid.productRevision.m := val MOD 10H;
		SYSTEM.MOVE(ADDRESSOF(raw[0]) + CardCid_ProductNameOfs DIV 8, ADDRESSOF(cid.productName), CardCid_ProductNameWidth DIV 8);
		SYSTEM.MOVE(ADDRESSOF(raw[0]) + CardCid_OEM_ApplicationIdOfs DIV 8, ADDRESSOF(cid.oemId), CardCid_OEM_ApplicationIdWidth DIV 8);
		cid.manufacturerId := ReadBitfield(raw, CardCid_ManufacturerIdOfs, CardCid_ManufacturerIdWidth)
	END DecodeCid;

	(** Fills a Csd record from the raw csd bytes *)
	PROCEDURE DecodeCsd (CONST raw: ARRAY OF LONGINT; VAR csd: Csd);
	VAR
		sizeMult, val, version: LONGINT;
		real: REAL;
	BEGIN
		version := ReadBitfield(raw, CardCsd_CsdStructureOfs, CardCsd_CsdStructureWidth) + 1;

		IF version = 1 THEN
			sizeMult := LSH(LONGINT(2), ReadBitfield(raw, CardCsd_CSizeMultOfs1, CardCsd_CSizeMultWidth1));
			csd.capacity := sizeMult * (1 + ReadBitfield(raw, CardCsd_CSizeOfs1, CardCsd_CSizeWidth1)) * 512;
		ELSE
			csd.capacity := 512 * 1024 * (HUGEINT(ReadBitfield(raw, CardCsd_CSizeOfs2, CardCsd_CSizeWidth2)) + 1);
		END;

		csd.commandClasses := SYSTEM.VAL(SET, ReadBitfield(raw, CardCsd_CccOfs, CardCsd_CccWidth));
		csd.nsac := ReadBitfield(raw, CardCsd_NsacOfs, CardCsd_NsacWidth) * 100;

		val := ReadBitfield(raw, CardCsd_R2wFactorOfs, CardCsd_R2wFactorWidth);
		IF val >= 6 THEN
			csd.r2w := 0
		ELSE
			csd.r2w := LSH(LONGINT(1), val);
		END;

		val := ReadBitfield(raw, CardCsd_TranSpeedOfs, CardCsd_TranSpeedWidth);
		CASE val DIV 8 OF
			 1: csd.txSpeed := 10
			|2: csd.txSpeed := 12
			|3: csd.txSpeed := 13
			|4: csd.txSpeed := 15
			|5: csd.txSpeed := 20
			|6: csd.txSpeed := 25
			|7: csd.txSpeed := 30
			|8: csd.txSpeed := 35
			|9: csd.txSpeed := 40
			|10: csd.txSpeed := 45
			|11: csd.txSpeed := 50
			|12: csd.txSpeed := 55
			|13: csd.txSpeed := 60
			|14: csd.txSpeed := 70
			|15: csd.txSpeed := 80
		ELSE
			csd.txSpeed := 00
		END;
		csd.txSpeed := csd.txSpeed * 100;
		CASE val MOD 8 OF
			 0: csd.txSpeed := csd.txSpeed * 100
			|1: csd.txSpeed := csd.txSpeed * 1000
			|2: csd.txSpeed := csd.txSpeed * 10000
			|3: csd.txSpeed := csd.txSpeed * 100000
		END;

		val := ReadBitfield(raw, CardCsd_TaacOfs, CardCsd_TaacWidth);
		CASE val DIV 8 OF
			 1: real := 1.0
			|2: real := 1.2
			|3: real := 1.3
			|4: real := 1.5
			|5: real := 2.0
			|6: real := 2.5
			|7: real := 3.0
			|8: real := 3.5
			|9: real := 4.0
			|10: real := 4.5
			|11: real := 5.0
			|12: real := 5.5
			|13: real := 6.0
			|14: real := 7.0
			|15: real := 8.0
		ELSE
			real := 0.0
		END;
		CASE val MOD 8 OF
			 0: real := real * 1.0E-9
			|1: real := real * 1.0E-8
			|2: real := real * 1.0E-7
			|3: real := real * 1.0E-6
			|4: real := real * 1.0E-5
			|5: real := real * 1.0E-4
			|6: real := real * 1.0E-3
			|7: real := real * 1.0E-2
		END;
		csd.taac := real;

		csd.partialRead := ReadBitfield(raw, CardCsd_ReadBlPartial, 1) = 1;
		csd.misalignedRead := ReadBitfield(raw, CardCsd_ReadBlkMisalign, 1) = 1;
		val := ReadBitfield(raw, CardCsd_ReadBlLenOfs, CardCsd_ReadBlLenWidth);
		IF (val <= 8) OR (val >= 12) THEN
			csd.readBlockSize := BlockSize
		ELSE
			csd.readBlockSize := LSH(LONGINT(1), val)
		END;

		csd.partialWrite := ReadBitfield(raw, CardCsd_WriteBlPartial, 1) = 1;
		csd.misalignedWrite := ReadBitfield(raw, CardCsd_WriteBlkMisalign, 1) = 1;
		val := ReadBitfield(raw, CardCsd_WriteBlLenOfs, CardCsd_WriteBlLenWidth);
		IF (val <= 8) OR (val >= 12) THEN
			csd.writeBlockSize := BlockSize
		ELSE
			csd.writeBlockSize := LSH(LONGINT(1), val)
		END
	END DecodeCsd;

	(** Fills a SCR record from raw data bytes *)
	PROCEDURE DecodeScr (CONST raw: ARRAY OF CHAR; ofs: LONGINT; VAR scr: Scr);
	TYPE
		Array = ARRAY 8 OF CHAR;
	VAR
		bfield: ARRAY 2 OF LONGINT;
		i: LONGINT;
		val: SET;
	BEGIN
		FOR i := 0 TO 7 DO SYSTEM.VAL(Array, bfield)[7-i] := raw[ofs + i] END;
		IF ReadBitfield(bfield, CardScr_StructureOfs, CardScr_StructureWidth) # 0 THEN RETURN END;
		scr.version := ReadBitfield(bfield, CardScr_SpecVersionOfs, CardScr_SpecVersionWidth);
		IF ReadBitfield(bfield, CardScr_SpecV3, 1) # 0 THEN scr.version := Version3 END;
		IF ReadBitfield(bfield, CardScr_SpecV4, 1) # 0 THEN scr.version := Version4 END;
		i := ReadBitfield(bfield, CardScr_SpecVXOfs, CardScr_SpecVXWidth);
		IF i = CardScr_SpecVX_v5 THEN scr.version := Version5
		ELSIF i = CardScr_SpecVX_v6 THEN scr.version := Version6
		END;

		CASE ReadBitfield(bfield, CardScr_SecurityOfs, CardScr_SecurityWidth) OF
			 0: scr.security := TypeNone
			|2: scr.security := TypeSDSC
			|3: scr.security := TypeSDHC
			|4: scr.security := TypeSDXC
		END;
		val := SYSTEM.VAL(SET, ReadBitfield(bfield, CardScr_BusWidthsOfs, CardScr_BusWidthsWidth));
		FOR i := 0 TO MAX(SET) - 1 DO
			IF i IN val THEN
				INCL(scr.busWidth, LSH(LONGINT(1), i))
			END
		END
	END DecodeScr;

	(**
		Print the state of all Host Controller registers
	*)
	PROCEDURE PrintHcRegisters * (regs: HcRegisters);
	BEGIN
		IF EnableTrace THEN
			Log.String("[SD] HC registers status:"); Log.Ln;
			Log.String("[SD] 	SDMASystemAddress: 0x"); Log.Hex(regs.SDMASystemAddress,-SIZEOF(LONGINT)*2); Log.Ln;
			Log.String("[SD] 	BlockSize: 0x"); Log.Hex(regs.BlockSize,-SIZEOF(INTEGER)*2); Log.Ln;
			Log.String("[SD] 	BlockCount: 0x"); Log.Hex(regs.BlockCount,-SIZEOF(INTEGER)*2); Log.Ln;
			Log.String("[SD] 	Argument1: 0x"); Log.Hex(regs.Argument1,-SIZEOF(LONGINT)*2); Log.Ln;
			Log.String("[SD] 	TransferMode: 0x"); Log.Hex(regs.TransferMode,-SIZEOF(INTEGER)*2); Log.Ln;
			Log.String("[SD] 	Command: 0x"); Log.Hex(regs.Command,-SIZEOF(INTEGER)*2); Log.Ln;

			Log.String("[SD] 	Response: 0x");
			Log.Hex(regs.Response[0],-SIZEOF(LONGINT)*2); Log.String(" 0x");
			Log.Hex(regs.Response[1],-SIZEOF(LONGINT)*2); Log.String(" 0x");
			Log.Hex(regs.Response[2],-SIZEOF(LONGINT)*2); Log.String(" 0x");
			Log.Hex(regs.Response[3],-SIZEOF(LONGINT)*2); Log.Ln;

			Log.String("[SD] 	BufferData: 0x"); Log.Hex(regs.BufferData,-SIZEOF(LONGINT)*2); Log.Ln;
			Log.String("[SD] 	PresentState: "); Log.Set(regs.PresentState); Log.Ln;
			Log.String("[SD] 	HostControl1: 0x"); Log.Hex(regs.HostControl1,-SIZEOF(SHORTINT)*2); Log.Ln;
			Log.String("[SD] 	PowerControl: 0x"); Log.Hex(regs.PowerControl,-SIZEOF(SHORTINT)*2); Log.Ln;
			Log.String("[SD] 	BlockGapControl: 0x"); Log.Hex(regs.BlockGapControl,-SIZEOF(SHORTINT)*2); Log.Ln;
			Log.String("[SD] 	WakeupControl: 0x"); Log.Hex(regs.WakeupControl,-SIZEOF(SHORTINT)*2); Log.Ln;
			Log.String("[SD] 	ClockControl: 0x"); Log.Hex(regs.ClockControl,-SIZEOF(INTEGER)*2); Log.Ln;
			Log.String("[SD] 	TimeoutControl: 0x"); Log.Hex(regs.TimeoutControl,-SIZEOF(SHORTINT)*2); Log.Ln;
			Log.String("[SD] 	SoftwareReset: 0x"); Log.Hex(regs.SoftwareReset,-SIZEOF(SHORTINT)*2); Log.Ln;
			Log.String("[SD] 	InterruptStatus: "); Log.Set(regs.InterruptStatus); Log.Ln;
			Log.String("[SD] 	InterruptStatusEnable: "); Log.Set(regs.InterruptStatusEnable); Log.Ln;
			Log.String("[SD] 	InterruptSignalEnable: "); Log.Set(regs.InterruptSignalEnable); Log.Ln;
			Log.String("[SD] 	AutoCmdErrorStatus: 0x"); Log.Hex(regs.AutoCmdErrorStatus,-SIZEOF(INTEGER)*2); Log.Ln;
			Log.String("[SD] 	HostControl2: 0x"); Log.Hex(regs.HostControl2,-SIZEOF(INTEGER)*2); Log.Ln;

			Log.String("[SD] 	Capabilities: ");
			Log.Set(regs.Capabilities[0]); Log.String(" ");
			Log.Set(regs.Capabilities[1]); Log.Ln;

			(*Log.String("[SD] 	MaximumCurrentCapabilities: 0x"); Log.Hex(regs.MaximumCurrentCapabilities,-SIZEOF(HUGEINT)*2); Log.Ln;
			Log.String("[SD] 	ForceEventAutoCmdErrorStatus: 0x"); Log.Hex(regs.ForceEventAutoCmdErrorStatus,-SIZEOF(INTEGER)*2); Log.Ln;
			Log.String("[SD] 	ForceEventErrorInterruptStatus: 0x"); Log.Hex(regs.ForceEventErrorInterruptStatus,-SIZEOF(INTEGER)*2); Log.Ln;
			Log.String("[SD] 	AdmaErrorStatus: 0x"); Log.Hex(regs.AdmaErrorStatus,-SIZEOF(SHORTINT)*2); Log.Ln;
			Log.String("[SD] 	AdmaSystemAddress: 0x"); Log.Hex(regs.AdmaSystemAddress,-SIZEOF(HUGEINT)*2); Log.Ln;*)

			Log.String("[SD] 	PresetValues: 0x");
			Log.Hex(regs.PresetValues[0],-SIZEOF(INTEGER)*2); Log.String(" 0x");
			Log.Hex(regs.PresetValues[1],-SIZEOF(INTEGER)*2); Log.String(" 0x");
			Log.Hex(regs.PresetValues[2],-SIZEOF(INTEGER)*2); Log.String(" 0x");
			Log.Hex(regs.PresetValues[3],-SIZEOF(INTEGER)*2); Log.String(" 0x");
			Log.Hex(regs.PresetValues[4],-SIZEOF(INTEGER)*2); Log.String(" 0x");
			Log.Hex(regs.PresetValues[5],-SIZEOF(INTEGER)*2); Log.String(" 0x");
			Log.Hex(regs.PresetValues[6],-SIZEOF(INTEGER)*2); Log.String(" 0x");
			Log.Hex(regs.PresetValues[7],-SIZEOF(INTEGER)*2); Log.Ln;

			Log.String("[SD] 	SharedBusControl: 0x"); Log.Hex(regs.SharedBusControl,-SIZEOF(LONGINT)*2); Log.Ln;
			Log.String("[SD] 	SlotInterruptStatus: 0x"); Log.Hex(regs.SlotInterruptStatus,-SIZEOF(INTEGER)*2); Log.Ln;
			Log.String("[SD] 	HostControllerVersion: 0x"); Log.Hex(regs.HostControllerVersion,-SIZEOF(INTEGER)*2); Log.Ln
		END
	END PrintHcRegisters;

	(** Outputs the capabilities of a host controller on the log. *)
	PROCEDURE PrintCapabilities * (hc: HostController);
	VAR
		c0, c1: SET;
	BEGIN
		IF EnableTrace THEN
			c0 := hc.regs.Capabilities[0];
			c1 := hc.regs.Capabilities[1];
			Log.String("[SD] "); Log.String("Host Capabilities:"); Log.Ln;
			Log.String("[SD] "); Log.String("	Timeout Clock Frequency: ");
			IF c0 * Capabilities_TimeoutClockFrequencyMask = {} THEN
				Log.String("Unknown")
			ELSE
				Log.Int(SYSTEM.VAL(LONGINT, c0 * Capabilities_TimeoutClockFrequencyMask), 0);
				IF Capabilities_TimeoutClockUnit IN c0 THEN
					Log.String(" MHz")
				ELSE
					Log.String(" kHz")
				END
			END;
			Log.Ln;

			Log.String("[SD] "); Log.String("	Base Clock Frequency: ");
			IF c0 * Capabilities_BaseClockFreqSdMask = {} THEN
				Log.String("Unknown")
			ELSE
				Log.Int(LSH(SYSTEM.VAL(LONGINT, c0 * Capabilities_BaseClockFreqSdMask), -Capabilities_BaseClockFreqSdOfs), 0)
			END;
			Log.Ln;

			Log.String("[SD] "); Log.String("	Max Block Length: ");
			Log.Int(512 * (1 + LSH(SYSTEM.VAL(LONGINT, c0 * Capabilities_MaxBlockLenMask), -Capabilities_MaxBlockLenOfs)), 0);
			Log.String(" B");
			Log.Ln;

			Log.String("[SD] "); Log.String("	8 Bit Support for Embedded Device: ");
			Log.Boolean(Capabilities_8BitEmbedded IN c0);
			Log.Ln;

			Log.String("[SD] "); Log.String("	Support for ADMA2: ");
			Log.Boolean(Capabilities_ADMA2 IN c0);
			Log.Ln;

			Log.String("[SD] "); Log.String("	Support for High Speed: ");
			Log.Boolean(Capabilities_HighSpeed IN c0);
			Log.Ln;

			Log.String("[SD] "); Log.String("	Support for SDMA: ");
			Log.Boolean(Capabilities_SDMA IN c0);
			Log.Ln;

			Log.String("[SD] "); Log.String("	Support for Suspend/Resume: ");
			Log.Boolean(Capabilities_SuspendResume IN c0);
			Log.Ln;

			Log.String("[SD] "); Log.String("	Voltage Support for 3.3 V: ");
			Log.Boolean(Capabilities_Voltage33 IN c0);
			Log.Ln;

			Log.String("[SD] "); Log.String("	Voltage Support for 3.0 V: ");
			Log.Boolean(Capabilities_Voltage30 IN c0);
			Log.Ln;

			Log.String("[SD] "); Log.String("	Voltage Support for 1.8 V: ");
			Log.Boolean(Capabilities_Voltage18 IN c0);
			Log.Ln;

			Log.String("[SD] "); Log.String("	Support for 64 Bit Bus: ");
			Log.Boolean(Capabilities_64BitBus IN c0);
			Log.Ln;

			Log.String("[SD] "); Log.String("	Support for Asynchronous Interrupts: ");
			Log.Boolean(Capabilities_AsyncInterrupt IN c0);
			Log.Ln;

			Log.String("[SD] "); Log.String("	Slot Type: ");
			IF c0 * Capabilities_SlotTypeMask = Capabilities_SlotType_Removable THEN
				Log.String("Removable Card Slot")
			ELSIF c0 * Capabilities_SlotTypeMask = Capabilities_SlotType_Embedded THEN
				Log.String("Embedded Slot for One Device")
			ELSIF c0 * Capabilities_SlotTypeMask = Capabilities_SlotType_SharedBus THEN
				Log.String("Shared Bus Slot")
			END;
			Log.Ln;

			IF hc.version = 3 THEN
				Log.String("[SD] "); Log.String("	Support for SDR50: ");
				Log.Boolean(Capabilities_SDR50 IN c1);
				Log.Ln;

				Log.String("[SD] "); Log.String("	Support for SDR104: ");
				Log.Boolean(Capabilities_SDR104 IN c1);
				Log.Ln;

				Log.String("[SD] "); Log.String("	Support for DDR50: ");
				Log.Boolean(Capabilities_DDR50 IN c1);
				Log.Ln;

				Log.String("[SD] "); Log.String("	Support for Driver Type A: ");
				Log.Boolean(Capabilities_DriverTypeA IN c1);
				Log.Ln;

				Log.String("[SD] "); Log.String("	Support for Driver Type C: ");
				Log.Boolean(Capabilities_DriverTypeC IN c1);
				Log.Ln;

				Log.String("[SD] "); Log.String("	Support for Driver Type D: ");
				Log.Boolean(Capabilities_DriverTypeD IN c1);
				Log.Ln;

				Log.String("[SD] "); Log.String("	Timer Count for Retuning: ");
				IF c1 * Capabilities_TimerCountRetuningMask = Capabilities_TimerCountRetuningMask THEN
					Log.String("Unknown")
				ELSIF c1 * Capabilities_TimerCountRetuningMask = {} THEN
					Log.String("Disabled")
				ELSE
					Log.Int(LSH(LONGINT(1), LSH(SYSTEM.VAL(LONGINT, c1 * Capabilities_TimerCountRetuningMask), -Capabilities_TimerCountRetuningOfs)), 0);
					Log.String(" s")
				END;
				Log.Ln;

				Log.String("[SD] "); Log.String("	SDR50 Requires Retuning: ");
				Log.Boolean(Capabilities_TuningSDR50 IN c1);
				Log.Ln;

				Log.String("[SD] "); Log.String("	Retuning Mode: ");
				Log.Int(LSH(SYSTEM.VAL(LONGINT, c1 * Capabilities_RetuningModesMask), -Capabilities_RetuningModesOfs), 0);
				Log.Ln;

				Log.String("[SD] "); Log.String("	Clock Multiplier: ");
				IF c1 * Capabilities_ClockMultiplierMask = {} THEN
					Log.String("Not Supported")
				ELSE
					Log.Int(LSH(SYSTEM.VAL(LONGINT, c1 * Capabilities_ClockMultiplierMask), -Capabilities_ClockMultiplierOfs) + 1, 0)
				END;
				Log.Ln
			END
		END
	END PrintCapabilities;

	(** Print a card status response on the log. *)
	PROCEDURE PrintCardStatus * (status: SET);
	BEGIN
		IF EnableTrace THEN
			Log.String("[SD] Card Status:"); Log.Ln;
			Log.String("[SD]	AKE Error: "); Log.Boolean(CardStatus_AkeSpecError IN status); Log.Ln;
			Log.String("[SD]	App Command: "); Log.Boolean(CardStatus_AppCmd IN status); Log.Ln;
			Log.String("[SD]	Ready For Data: "); Log.Boolean(CardStatus_ReadyForData IN status); Log.Ln;
			Log.String("[SD]	Card State: ");
			CASE LSH(SYSTEM.VAL(LONGINT, status * CardStatus_CurrentStateMask), -CardStatus_CurrentStateOffset) OF
				 CardIdle: Log.String("Idle")
				|CardReady: Log.String("Ready")
				|CardIdentification: Log.String("Identification")
				|CardStandby: Log.String("Standby")
				|CardTransfer: Log.String("Transfer")
				|CardData: Log.String("Sending Data")
				|CardReceive: Log.String("Receiving Data")
				|CardProgram: Log.String("Programming")
				|CardDisabled: Log.String("Disabled")
			END;
			Log.Ln;
			Log.String("[SD]	Erase Reset: "); Log.Boolean(CardStatus_EraseReset IN status); Log.Ln;
			Log.String("[SD]	Internal ECC Enable: "); Log.Boolean(CardStatus_CardEccDisable IN status); Log.Ln;
			Log.String("[SD]	Write_Protection Erase Skip: "); Log.Boolean(CardStatus_WpEraseSkip IN status); Log.Ln;
			Log.String("[SD]	CSD Overwrite: "); Log.Boolean(CardStatus_CsdOverwrite IN status); Log.Ln;
			Log.String("[SD]	Error: "); Log.Boolean(CardStatus_Error IN status); Log.Ln;
			Log.String("[SD]	Card Controller Error: "); Log.Boolean(CardStatus_CcError IN status); Log.Ln;
			Log.String("[SD]	Card ECC Failed: "); Log.Boolean(CardStatus_CardEccFailed IN status); Log.Ln;
			Log.String("[SD]	Illegal Command: "); Log.Boolean(CardStatus_IllegalCommand IN status); Log.Ln;
			Log.String("[SD]	Command CRC Error: "); Log.Boolean(CardStatus_ComCrcError IN status); Log.Ln;
			Log.String("[SD]	Lock/Unlock Failed: "); Log.Boolean(CardStatus_LockUnlockFailed IN status); Log.Ln;
			Log.String("[SD]	Card is Locked: "); Log.Boolean(CardStatus_CardIsLocked IN status); Log.Ln;
			Log.String("[SD]	Write-Protection Violation: "); Log.Boolean(CardStatus_WpViolation IN status); Log.Ln;
			Log.String("[SD]	Invalid Erase Parameters: "); Log.Boolean(CardStatus_EraseParam IN status); Log.Ln;
			Log.String("[SD]	Erase Sequence Error: "); Log.Boolean(CardStatus_EraseSeqError IN status); Log.Ln;
			Log.String("[SD]	Block Length Error: "); Log.Boolean(CardStatus_BlockLenError IN status); Log.Ln;
			Log.String("[SD]	Address Error: "); Log.Boolean(CardStatus_AddressError IN status); Log.Ln;
			Log.String("[SD]	Argument Out of Range: "); Log.Boolean(CardStatus_OutOfRange IN status); Log.Ln
		END
	END PrintCardStatus;

	(** Print SD Status record *)
	PROCEDURE PrintSdStatus * (status: SdStatus);
	BEGIN
		IF EnableTrace THEN
			Log.String("[SD] SD Status"); Log.Ln;
			Log.String("[SD]	data bus width: "); Log.Int(status.dataBusWidth, 0); Log.Ln;
			Log.String("[SD]	secured mode enabled: "); Log.Boolean(status.securedMode); Log.Ln;
			Log.String("[SD]	cardType: ");
			CASE status.cardType OF
				 CategoryRW: Log.String("normal RW card")
				|CategoryRO: Log.String("read-only card")
				|CategoryOTP: Log.String("one-time programmable card")
			END; Log.Ln;
			Log.String("[SD]	size of protected area: "); PrintSize(status.sizeProtArea); Log.Ln;
			Log.String("[SD]	move performance: ");
			CASE status.perfMove OF
				 0: Log.String("sequential write")
				|255: Log.String("infinite")
			ELSE
				Log.Int(status.perfMove, 0);
				Log.String(" MB/s")
			END; Log.Ln;
			Log.String("[SD]	erase size: "); Log.Int(status.eraseSize, 0); Log.String(" AUs"); Log.Ln;
			Log.String("[SD]	erase timeout: ");
			IF status.eraseTimeout = 0 THEN
				Log.String("not supported")
			ELSE
				Log.Int(status.eraseTimeout, 0); Log.String(" s")
			END; Log.Ln;
			Log.String("[SD]	erase timeout offset: "); Log.Int(status.eraseOffset, 0); Log.String(" s"); Log.Ln;
			Log.String("[SD]	speed class: "); Log.Int(status.speedClass, 0); Log.Ln;
			Log.String("[SD]	AU size: "); PrintSize(status.auSize); Log.Ln;
			Log.String("[SD]	UHS speed grade: "); Log.Int(status.uhsSpeedGrade, 0); Log.Ln;
			Log.String("[SD]	UHS AU size: "); PrintSize(status.uhsAuSize); Log.Ln;
			Log.String("[SD]	video speed class: "); Log.Int(status.vscSpeedClass, 0); Log.Ln;
			Log.String("[SD]	VSC AU size: "); PrintSize(status.vscAuSize); Log.Ln;
			Log.String("[SD]	suspension address: "); Log.Int(status.suspensionAdr, 0); Log.Ln;
			Log.String("[SD]	application performance class: ");
			IF status.appPerfClass = 0 THEN
				Log.String("not supported")
			ELSE
				Log.String("A");
				Log.Int(status.appPerfClass, 0)
			END; Log.Ln;
			Log.String("[SD]	performance enhance: ");
			IF status.perfEnhance = {} THEN Log.String("none") END;
			IF PerformanceCardMaintenance IN status.perfEnhance THEN Log.String("card-initiated maintenance; ") END;
			IF PerformanceHostMaintenance IN status.perfEnhance THEN Log.String("host-initiated maintenance; ") END;
			IF PerformanceCache IN status.perfEnhance THEN Log.String("cache; ") END;
			IF PerformanceQueue IN status.perfEnhance THEN
				Log.String("command queue;"); Log.Ln;
				Log.String("[SD]	command queue depth: ");
				Log.Int(status.commandQueueDepth, 0)
			END; Log.Ln;
			Log.String("[SD]	discard supported: "); Log.Boolean(status.discardSupport); Log.Ln;
			Log.String("[SD]	FULE supported: "); Log.Boolean(status.fuleSupport); Log.Ln
		END
	END PrintSdStatus;

	(** Print the CID of a card to the log. *)
	PROCEDURE PrintCardCid * (cid: Cid);
	BEGIN
		IF EnableTrace THEN
			Log.String("[SD] CID"); Log.Ln;
			Log.String("[SD]	manufacturing date: "); Log.Int(cid.manufacturingDate.month, 0); Log.String("/"); Log.Int(cid.manufacturingDate.year, 0); Log.Ln;
			Log.String("[SD]	product serial number: "); Log.Int(cid.productSerialNumber, 0); Log.Ln;
			Log.String("[SD]	product revision: "); Log.Int(cid.productRevision.n, 0); Log.String("."); Log.Int(cid.productRevision.m, 0); Log.Ln;
			Log.String("[SD]	product name: "); Log.String(cid.productName); Log.Ln;
			Log.String("[SD]	OEM/application id: "); Log.String(cid.oemId); Log.Ln;
			Log.String("[SD]	manufacturer id: "); Log.Int(cid.manufacturerId, 0); Log.Ln
		END
	END PrintCardCid;

	(** Print the CSD of a card to the log. *)
	PROCEDURE PrintCardCsd * (CONST csd: ARRAY OF LONGINT);
	VAR
		cap: HUGEINT;
		val, version, sizeMult: LONGINT;
	BEGIN
		IF EnableTrace THEN
			version := ReadBitfield(csd, CardCsd_CsdStructureOfs, CardCsd_CsdStructureWidth) + 1;
			Log.String("[SD] "); Log.String("Card CSD:"); Log.Ln;
			Log.String("[SD] "); Log.String("	Version: "); Log.Int(version, 0); Log.Ln;

			(* Common Fields *)
			Log.String("[SD] "); Log.String("	File Format: ");
			val := ReadBitfield(csd, CardCsd_FileFormatOfs, CardCsd_FileFormatWidth);
			IF ReadBitfield(csd, CardCsd_FileFormatGrp, 1) = 1 THEN
				Log.String("Unknown Value (");
				Log.Int(val, 0);
				Log.String(")")
			ELSIF val = 0 THEN
				Log.String("Hard-disk file system with partition table")
			ELSIF val = 1 THEN
				Log.String("FAT")
			ELSIF val = 2 THEN
				Log.String("Universal File Format")
			ELSE
				Log.String("Other")
			END;
			Log.Ln;

			Log.String("[SD] "); Log.String("	Temporary Write Protection: "); Log.Boolean(ReadBitfield(csd, CardCsd_TmpWriteProtect, 1) = 1); Log.Ln;
			Log.String("[SD] "); Log.String("	Permanent Write Protection: "); Log.Boolean(ReadBitfield(csd, CardCsd_PermWriteProtect, 1) = 1); Log.Ln;
			Log.String("[SD] "); Log.String("	Copy: "); Log.Boolean(ReadBitfield(csd, CardCsd_Copy, 1) = 1); Log.Ln;
			Log.String("[SD] "); Log.String("	Partial Block Write: "); Log.Boolean(ReadBitfield(csd, CardCsd_WriteBlPartial, 1) = 1); Log.Ln;
			Log.String("[SD] "); Log.String("	Maximum Write Block Length: ");
			val := ReadBitfield(csd, CardCsd_WriteBlLenOfs, CardCsd_WriteBlLenWidth);
			IF (val <= 8) OR (val >= 12) THEN
				Log.String("Unknown Value (");
				Log.Int(val, 0);
				Log.String(")")
			ELSE
				Log.Int(LSH(LONGINT(1), val), 0);
			END;
			Log.Ln;
			Log.String("[SD] "); Log.String("	Block Program Time / Block Read Time: ");
			val := ReadBitfield(csd, CardCsd_R2wFactorOfs, CardCsd_R2wFactorWidth);
			IF val >= 6 THEN
				Log.String("Unknown Value (");
				Log.Int(val, 0);
				Log.String(")")
			ELSE
				Log.Int(LSH(LONGINT(1), val), 0);
			END;
			Log.Ln;
			Log.String("[SD] "); Log.String("	Group Write Protection: "); Log.Boolean(ReadBitfield(csd, CardCsd_WpGrpEnable, 1) = 1); Log.Ln;
			Log.String("[SD] "); Log.String("	WpGrpSize: "); Log.Int(ReadBitfield(csd, CardCsd_WpGrpSizeOfs, CardCsd_WpGrpSizeWidth) + 1, 0); Log.String(" sectors"); Log.Ln;
			Log.String("[SD] "); Log.String("	Sector Size: "); Log.Int(ReadBitfield(csd, CardCsd_SectorSizeOfs, CardCsd_SectorSizeWidth) + 1, 0); Log.Ln;
			Log.String("[SD] "); Log.String("	Erase Block Enable: "); Log.Boolean(ReadBitfield(csd, CardCsd_EraseBlkEn, 1) = 1); Log.Ln;

			IF version = 1 THEN
				sizeMult := LSH(LONGINT(2), ReadBitfield(csd, CardCsd_CSizeMultOfs1, CardCsd_CSizeMultWidth1));
				cap := sizeMult * (1 + ReadBitfield(csd, CardCsd_CSizeOfs1, CardCsd_CSizeWidth1)) * 512;
			ELSE
				cap := 512 * 1024 * (HUGEINT(ReadBitfield(csd, CardCsd_CSizeOfs2, CardCsd_CSizeWidth2)) + 1);
			END;
			Log.String("[SD] "); Log.String("	Card Capacity: "); Log.Int(cap, 0); Log.String(" B"); Log.Ln;
			Log.String("[SD] "); Log.String("	DSR Implemented: "); Log.Boolean(ReadBitfield(csd, CardCsd_DsrImp, 1) = 1); Log.Ln;
			Log.String("[SD] "); Log.String("	Misaligned Block Read: "); Log.Boolean(ReadBitfield(csd, CardCsd_ReadBlkMisalign, 1) = 1); Log.Ln;
			Log.String("[SD] "); Log.String("	Misaligned Block Write: "); Log.Boolean(ReadBitfield(csd, CardCsd_WriteBlkMisalign, 1) = 1); Log.Ln;
			Log.String("[SD] "); Log.String("	Partial Block Read: "); Log.Boolean(ReadBitfield(csd, CardCsd_ReadBlPartial, 1) = 1); Log.Ln;
			(*ASSERT(ReadBitfield(csd, CardCsd_ReadBlPartial, 1) = 1);*)
			Log.String("[SD] "); Log.String("	Maximal Block Read Length: ");
			val := ReadBitfield(csd, CardCsd_ReadBlLenOfs, CardCsd_ReadBlLenWidth);
			IF (val <= 8) OR (val >= 12) THEN
				Log.String("Unknown Value (");
				Log.Int(val, 0);
				Log.String(")")
			ELSE
				Log.Int(LSH(LONGINT(1), val), 0); Log.String(" B")
			END;
			Log.Ln;
			Log.String("[SD] "); Log.String("	Supported Command Classes: "); Log.Set(SYSTEM.VAL(SET, ReadBitfield(csd, CardCsd_CccOfs, CardCsd_CccWidth))); Log.Ln;
			Log.String("[SD] "); Log.String("	Transfer Speed: ");
			val := ReadBitfield(csd, CardCsd_TranSpeedOfs, CardCsd_TranSpeedWidth);
			CASE val DIV 8 OF
				 1: Log.String("1.0")
				|2: Log.String("1.2")
				|3: Log.String("1.3")
				|4: Log.String("1.5")
				|5: Log.String("2.0")
				|6: Log.String("2.0")
				|7: Log.String("2.5")
				|8: Log.String("3.5")
				|9: Log.String("4.0")
				|10: Log.String("4.5")
				|11: Log.String("5.0")
				|12: Log.String("5.5")
				|13: Log.String("6.0")
				|14: Log.String("7.0")
				|15: Log.String("8.0")
			ELSE
				Log.String("Unknown Value (");
				Log.Int(val, 0);
				Log.String(")")
			END;
			Log.String(" * 1");
			CASE val MOD 8 OF
				 0: Log.String("00 k")
				|1: Log.String(" M")
				|2: Log.String("0 M")
				|3: Log.String("00 M")
			END;
			Log.String("Bit/s");
			Log.Ln;

			Log.String("[SD] "); Log.String("	Clock-Dependent Access Time: "); Log.Int(ReadBitfield(csd, CardCsd_NsacOfs, CardCsd_NsacWidth) * 100, 0); Log.String("000 clock cycles"); Log.Ln;
			Log.String("[SD] "); Log.String("	Asynchronous Access Time: ");
			val := ReadBitfield(csd, CardCsd_TaacOfs, CardCsd_TaacWidth);
			CASE val DIV 8 OF
				 1: Log.String("1.0")
				|2: Log.String("1.2")
				|3: Log.String("1.3")
				|4: Log.String("1.5")
				|5: Log.String("2.0")
				|6: Log.String("2.5")
				|7: Log.String("3.0")
				|8: Log.String("3.5")
				|9: Log.String("4.0")
				|10: Log.String("4.5")
				|11: Log.String("5.0")
				|12: Log.String("5.5")
				|13: Log.String("6.0")
				|14: Log.String("7.0")
				|15: Log.String("8.0")
			ELSE
				Log.String("Unknown Value (");
				Log.Int(val, 0);
				Log.String(")")
			END;
			Log.String(" * 1");
			CASE val MOD 8 OF
				 0: Log.String(" ns")
				|1: Log.String("0 ns")
				|2: Log.String("00 ns")
				|3: Log.String(" microsecond")
				|4: Log.String("0 microsecond")
				|5: Log.String("00 microsecond")
				|6: Log.String(" ms")
				|7: Log.String("0 ms")
			END;
			Log.Ln
		END
	END PrintCardCsd;

	PROCEDURE PrintCardScr * (CONST scr: Scr);
	VAR i: LONGINT;
	BEGIN
		IF EnableTrace THEN
			Log.String("[SD] Card SCR"); Log.Ln;
			Log.String("[SD]	physical layer version: ");
			CASE scr.version OF
				 Version1: Log.String("1")
				|Version1p1: Log.String("1.1")
				|Version2: Log.String("2")
				|Version3: Log.String("3")
				|Version4: Log.String("4")
				|Version5: Log.String("5")
				|Version6: Log.String("6")
			ELSE
				Log.String("unknown")
			END;
			Log.Ln;
			Log.String("[SD]	security support: ");
			CASE scr.security OF
				 TypeNone: Log.String("none")
				|TypeSDSC: Log.String("SDSC")
				|TypeSDHC: Log.String("SDHC")
				|TypeSDXC: Log.String("SDXC")
			END;
			Log.Ln;
			Log.String("[SD]	supported bus widths: "); Log.Set(scr.busWidth); Log.Ln
		END
	END PrintCardScr;

	(** Helper to write a size in a human-readable format *)
	PROCEDURE PrintSize (size: HUGEINT);
	VAR
		prefix: ARRAY 8 OF CHAR;
		i: LONGINT;

	BEGIN
		IF size < 1024 THEN
			Log.Int(size, 0);
			Log.String(" ")
		ELSE
			prefix := 'kMGT';
			i := 0;
			size := size DIV 1024;
			WHILE size > 1024 DO
				size := size DIV 1024;
				INC(i)
			END;
			Log.Int(size, 0);
			Log.String(" ");
			Log.Char(prefix[i])
		END;
		Log.String("B")
	END PrintSize;

	(**
		Helper procedure to read bit fields in a wide register.
			field: large bitfield
			ofs: offset of first bit to extract
			width: number of bits to extract
		Returns the bits as a LONGINT.
	*)
	PROCEDURE ReadBitfield (CONST field: ARRAY OF LONGINT; ofs, width: LONGINT): LONGINT;
	VAR
		adr, bits: ADDRESS;
	BEGIN
		ASSERT(ofs MOD 8 + width <= 32);
		adr := ADDRESSOF(field[0]) + ofs DIV 8;
		bits := SYSTEM.GET8(adr) MOD 100H;
		IF ofs MOD 8 + width > 8 THEN
			bits := bits + LSH(ADDRESS(SYSTEM.GET8(adr + 1)) MOD 100H, 8);
		END;
		IF ofs MOD 8 + width > 16 THEN
			bits := bits + LSH(ADDRESS(SYSTEM.GET8(adr + 2)) MOD 100H, 16);
		END;
		IF ofs MOD 8 + width > 24 THEN
			bits := bits + LSH(ADDRESS(SYSTEM.GET8(adr + 3)) MOD 100H, 24)
		END;
		RETURN SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(bits, -(ofs MOD 8))) * {0 .. width - 1})
	END ReadBitfield;

	PROCEDURE ReadBit (CONST field: ARRAY OF LONGINT; bit: LONGINT): BOOLEAN;
	BEGIN
		RETURN SYSTEM.VAL(BOOLEAN, LSH(SYSTEM.GET8(ADDRESSOF(field[0])) + bit DIV 8, -(bit MOD 8)))
	END ReadBit;

	PROCEDURE ResetStatistics *;
	BEGIN
		NbyteRead := 0;
		Nread := 0;
		Tread := 0;
		NbyteWritten := 0;
		Nwrite := 0;
		Twrite := 0
	END ResetStatistics;
END Sd.
