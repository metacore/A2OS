MODULE Sd;
(**
	AUTHOR Timothée Martiel, 2015
	PURPOSE SD Card Host Controller Driver
*)

IMPORT
	SYSTEM,
	SdEnvironment;

CONST
	BlockSize *									= 512;
	InitialClockFrequency *					= 400000;	(* Hz *)

	(* Commands *) (*! Do not change values *)
	CMD_GO_IDLE_STATE *					= 0;	(** CMD0 bc [31:0] stuff bits - *)
	CMD_ALL_SEND_CID *						= 2;	(** CMD2 bcr [31:0] stuff bits R2 *)
	CMD_SEND_RELATIVE_ADDR *			= 3;	(** CMD3 bcr [31:0] stuff bits R6 *)
	CMD_SET_DSR *							= 4;	(** CMD4 bc [31:16] DSR [15:0] stuff bits - *)
	CMD_IO_SEND_OP_COND *				= 5;	(** CMD5 ?? [31:25] stuff bits [24] switch 1.8V request [23:0] I/O OCR R4 *)
	CMD_SWITCH_FUNC *						= 6;	(** CMD6 adtc [31] Mode 0:Check function 1:Switch function [30:24] reserved (All '0') [23:20] reserved for function group 6 (0h or Fh) [19:16] reserved for function group 5 (0h or Fh) [15:12] function group 4 for current limit [11:8] funciton group 3 for drive strength [7:4] function group 2 for command system [3:0] function group 1 for access mode R1 *)
	CMD_SELECT_DESELECT_CARD *			= 7;	(** CMD7 ac [31:16] RCA [15:0] stuff bits R1b (only from the selected card) *)
	CMD_SEND_IF_COND *					= 8;	(** CMD8 bcr [31:12] reserved bits [11:8] supply voltage(VHS) [7:0]check pattern R7 *)
	CMD_SEND_CSD *							= 9;	(** CMD9 ac [31:16] RCA [15:0] stuff bits R2 *)
	CMD_SEND_CID *							= 10;	(** CMD10 ac [31:16] RCA [15:0] stuff bits R2 *)
	CMD_VOLTAGE_SWITCH *					= 11;	(** CMD11 ac [31:0] reserved bits (all 0) R1 *)
	CMD_STOP_TRANSMISSION *				= 12;	(** CMD12 ac [31:0] stuff bits R1b *)
	CMD_SEND_STATUS *						= 13;	(** CMD13 ac [31:16] RCA [15:0] stuff bits R1 *)
	CMD_GO_INACTIVE_STATE *				= 15;	(** CMD15 ac [31:16] RCA [15:0] reserved bits - *)
	CMD_SET_BLOCKLEN *					= 16;	(** CMD16 ac [31:0] block length R1 *)
	CMD_READ_SINGLE_BLOCK *				= 17;	(** CMD17 adtc [31:0] data address2 R1 *)
	CMD_READ_MULTIPLE_BLOCK *			= 18;	(** CMD18 adtc [31:0] data address2 R1 *)
	CMD_SEND_TUNING_BLOCK *				= 19;	(** CMD19 adtc [31:0] reserved bits (all 0) R1 *)
	CMD_SPEED_CLASS_CONTROL *			= 20;	(** CMD20 ac [31:28]Speed Class Control [27:0] Reserved (all-0) R1b *)
	CMD_SET_BLOCK_COUNT *				= 23;	(** CMD23 ac [31:0] Block Count R1 *)
	CMD_WRITE_BLOCK *						= 24;	(** CMD24 adtc [31:0] data address2 R1 *)
	CMD_WRITE_MULTIPLE_BLOCK *			= 25;	(** CMD25 adtc [31:0] data address2 R1 *)
	CMD_PROGRAM_CSD *					= 27;	(** CMD27 adtc [31:0] stuff bits R1 *)
	CMD_SET_WRITE_PROT *					= 28;	(** CMD28 ac [31:0] data address2 R1b *)
	CMD_CLR_WRITE_PROT *					= 29;	(** CMD29 ac [31:0] data address2 R1b *)
	CMD_SEND_WRITE_PROT *				= 30;	(** CMD30 adtc [31:0] write protect data address2 R1 *)
	CMD_ERASE_WR_BLK_START *				= 32;	(** CMD32 ac [31:0] data address1 R1 *)
	CMD_ERASE_WR_BLK_END *				= 33;	(** CMD33 ac [31:0] data address1 R1 *)
	CMD_ERASE *								= 38;	(** CMD38 ac [31:0] stuff bits R1b *)
	CMD_LOCK_UNLOCK *						= 42;	(** CMD42 adtc [31:0] Reserved bits (Set all 0) R1 *)
	CMD_APP_CMD *							= 55;	(** CMD55 ac [31:16] RCA [15:0] stuff bits R1 *)
	CMD_GEN_CMD *							= 56;	(** CMD56 adtc [31:1] stuff bits. [0] RD/WR R1 *)

	(** Application Commands *) (*! Do Not Change Values *)
	ACMD_SET_BUS_WIDTH *					= 6;	(** ACMD6 ac [31:2] stuff bits [1:0] bus width R1 *)
	ACMD_SD_STATUS *						= 13;	(** ACMD13 adtc [31:0] stuff bits R1 *)
	ACMD_SEND_NUM_WR_BLOCKS *			= 22;	(** ACMD22 adtc [31:0] stuff bits R1 *)
	ACMD_SET_WR_BLK_ERASE_COUNT *		= 23;	(** ACMD23 ac [31:23] stuff bits [22:0] Number of blocks R1 *)
	ACMD_SD_SEND_OP_COND *				= 41;	(** ACMD41 bcr [31]reserved bit [30] HCS(OCR[30]) [29] reserved for eSD [28] XPC [27:25] reserved bits [24] S18R [23:0] VDD Voltage Window(OCR[23:0]) R3 *)
	ACMD_SET_CLR_CARD_DETECT *			= 42;	(** ACMD42 ac [31:1] stuff bits [0] set_cd R1 *)
	ACMD_SEND_SCR *						= 51;	(** ACMD51 adtc [31:0] stuff bits R1 *)

	(** Errors *)
	ErrorNone *								= 0;
	ErrorCmdTimeout *						= 1;
	ErrorCmdCrc *								= 2;
	ErrorDatTimeout *						= 3;
	ErrorDatCrc *								= 4;
	ErrorNoCard *								= 5;
	ErrorCard *								= 6;
	ErrorUnrecoverable *						= 7;
	ErrorInvalidParameters *					= 8;

	(** Card Versions *)
	Version1 *									= 0;	(** v1.00 or v1.01 *)
	Version1p1 *								= 1;	(** v1.10 *)
	Version2 *									= 2;	(** v2.00 *)
	Version3 *									= 3;	(** v3.00 *)
	(** Card Type *)
	TypeNone *								= 0;
	TypeSDSC *								= 1;
	TypeSDHC *								= 2;
	TypeSDXC *								= 3;

	(** Card Events *)
	OnInitialization *							= 0;
	OnRemoval *								= 1;
	OnReadComplete *						= 2;
	OnWriteComplete *						= 3;

	(** Command Record Flags *)
	FlagData *									= 0;
	FlagRead *									= 1;
	FlagAutoCmd12 *							= 2;
	FlagAutoCmd23 *							= 3;
	FlagMultipleBlockTx *						= 4;
	FlagCountBlocks *							= 5;
	FlagUseDma *								= 6;
	FlagAbort *								= 7;
	FlagApplicationCmd *						= 8;
	FlagIgnoreIllegalCmd *					= 9;

	(** Response Types *) (*! Do not change values *)
	ResponseNone	 *							= -1;
	ResponseR1 *								= 0;
	ResponseR1b *							= 1;
	ResponseR2 *								= 2;
	ResponseR3 *								= 3;
	ResponseR4 *								= 4;
	ResponseR5 *								= 5;
	ResponseR5b *							= 6;
	ResponseR6 *								= 7;
	ResponseR7 *								= 8;

	(** Card States *)
	CardIdle									= 0;
	CardReady									= 1;
	CardIdentification							= 2;
	CardStandby								= 3;
	CardTransfer								= 4;
	CardData									= 5;
	CardReceive								= 6;
	CardProgram								= 7;
	CardDisabled								= 8;

	(** Operation modes *)
	OpCpu										= 0;
	OpSdma									= 1;
	OpAdma									= 2;

	(* Present State bits *)
	PresentState_CommandInhibitCmd		= 0;
	PresentState_CommandInhibitDat			= 1;
	PresentState_DatLineActive					= 2;
	PresentState_RetuningRequest				= 3;
	PresentState_WriteTransferActive			= 8;
	PresentState_ReadTransferActive			= 9;
	PresentState_BufferWriteEnable			= 10;
	PresentState_BufferReadEnable			= 11;
	PresentState_CardInserted					= 16;
	PresentState_CardStateStable				= 17;
	PresentState_CardDetectPinLevel			= 18;
	PresentState_WriteProtectSwitchPinLevel	= 19;
	PresentState_CmdLineSignalLevel			= 24;
	PresentState_DatLineSignalLevelOfs		= 20;
	PresentState_DatLineSignalLevelMask		= {20 .. 23};

	(* Interrupt Status, Status Enable, Signal Enable bits *)
	Interrupt_Normal_CommandComplete		= 0;
	Interrupt_Normal_TransferComplete		= 1;
	Interrupt_Normal_BlockGapEvent			= 2;
	Interrupt_Normal_DmaInterrupt			= 3;
	Interrupt_Normal_BufferWriteReady		= 4;
	Interrupt_Normal_BufferReadReady		= 5;
	Interrupt_Normal_CardInsertion			= 6;
	Interrupt_Normal_CardRemoval			= 7;
	Interrupt_Normal_CardInterrupt			= 8;
	Interrupt_Normal_IntA						= 9;
	Interrupt_Normal_IntB						= 10;
	Interrupt_Normal_IntC						= 11;
	Interrupt_Normal_RetuningEvent			= 12;
	Interrupt_Normal_ErrorInterrupt			= 15;
	Interrupt_Error_CommandTimeout			= 16;
	Interrupt_Error_CommandCrc				= 17;
	Interrupt_Error_CommandEndBit			= 18;
	Interrupt_Error_CommandIndex			= 19;
	Interrupt_Error_DataTimeout				= 20;
	Interrupt_Error_DataCrc						= 21;
	Interrupt_Error_DataEndBit					= 22;
	Interrupt_Error_CurrentLimit				= 23;
	Interrupt_Error_AutoCmd12				= 24;
	Interrupt_Error_Adma						= 25;
	Interrupt_Error_Tuning						= 26;
	Interrupt_Normal_All						= {Interrupt_Normal_CommandComplete, Interrupt_Normal_TransferComplete, Interrupt_Normal_BlockGapEvent, Interrupt_Normal_DmaInterrupt,
													Interrupt_Normal_BufferWriteReady, Interrupt_Normal_BufferReadReady, Interrupt_Normal_CardInsertion, Interrupt_Normal_CardRemoval,
													Interrupt_Normal_CardInterrupt, Interrupt_Normal_IntA, Interrupt_Normal_IntB, Interrupt_Normal_IntC, Interrupt_Normal_RetuningEvent,
													Interrupt_Normal_ErrorInterrupt};
	Interrupt_Error_All							= {Interrupt_Error_CommandTimeout, Interrupt_Error_CommandCrc, Interrupt_Error_CommandEndBit,
													Interrupt_Error_CommandIndex, Interrupt_Error_DataTimeout, Interrupt_Error_DataCrc, Interrupt_Error_DataEndBit, Interrupt_Error_CurrentLimit,
													Interrupt_Error_AutoCmd12, Interrupt_Error_Adma, Interrupt_Error_Tuning};
	Interrupt_All								= Interrupt_Normal_All + Interrupt_Error_All;

	(* Transfer Mode Register bits *)
	TransferMode_DmaEnable					= 0;
	TransferMode_BlockCountEnable			= 1;
	TransferMode_AutoCmdOfs				= 2;
	TransferMode_AutoCmdMask				= {2 .. 3};
	TransferMode_DataTxDirection			= 4;
	TransferMode_MultipleBlocks				= 5;
	TransferMode_AutoCmd_None				= {};
	TransferMode_AutoCmd_Cmd12			= {2};
	TransferMode_AutoCmd_Cmd23			= {3};

	(* Command Register bits *)
	Command_ResponseTypeOffset			= 0;
	Command_CrcCheckEnable				= 3;
	Command_IndexCheckEnable				= 4;
	Command_DataPresent					= 5;
	Command_CommandTypeOffset			= 6;
	Command_CommandTypeMask			= {6 .. 7};
	Command_CommandIndexOffset			= 8;
	Command_CommandIndexMask			= {8 .. 13};

	Command_ResponseType_None			= 0;
	Command_ResponseType_136b			= 1;
	Command_ResponseType_48b				= 2;
	Command_ResponseType_48bBusy		= 3;

	(* Capabilities Register *)
	(* Low Word *)
	Capabilities_TimeoutClockFrequencyOfs	= 0;
	Capabilities_TimeoutClockFrequencyMask	= {0 .. 5};
	Capabilities_TimeoutClockUnit				= 7;
	Capabilities_BaseClockFreqSdOfs			= 8;
	Capabilities_BaseClockFreqSdMask			= {8 .. 15};
	Capabilities_MaxBlockLenOfs				= 16;
	Capabilities_MaxBlockLenMask			= {16 .. 17};
	Capabilities_8BitEmbedded				= 18;
	Capabilities_ADMA2						= 19;
	Capabilities_HighSpeed						= 21;
	Capabilities_SDMA							= 22;
	Capabilities_SuspendResume				= 23;
	Capabilities_Voltage33						= 24;
	Capabilities_Voltage30						= 25;
	Capabilities_Voltage18						= 26;
	Capabilities_64BitBus						= 28;
	Capabilities_AsyncInterrupt					= 29;
	Capabilities_SlotTypeOfs					= 30;
	Capabilities_SlotTypeMask					= {30 .. 31};
	(* High Word *)
	Capabilities_SDR50							= 0;
	Capabilities_SDR104						= 1;
	Capabilities_DDR50						= 2;
	Capabilities_DriverTypeA					= 4;
	Capabilities_DriverTypeC					= 5;
	Capabilities_DriverTypeD					= 6;
	Capabilities_TimerCountRetuningOfs		= 8;
	Capabilities_TimerCountRetuningMask	= {8 .. 11};
	Capabilities_TuningSDR50					= 13;
	Capabilities_RetuningModesOfs			= 14;
	Capabilities_RetuningModesMask			= {14 .. 15};
	Capabilities_ClockMultiplierOfs			= 16;
	Capabilities_ClockMultiplierMask			= {16 .. 23};
	(* Patterns *)
	Capabilities_SlotType_Removable			= {};
	Capabilities_SlotType_Embedded			= {30};
	Capabilities_SlotType_SharedBus			= {31};

	(* Host Control 1 register values *)
	HostControl1_LedControl					= 0;
	HostControl1_DataWidthTransfer			= 1;
	HostControl1_HighSpeedEnable			= 2;
	HostControl1_DmaSelectOfs				= 3;
	HostControl1_DmaSelectMask				= {3 .. 4};
	HostControl1_ExtendedDataTxWidth		= 5;
	HostControl1_CardDetectTestLevel			= 6;
	HostControl1_CardDetectSignalSelection	= 7;
	HostControl1_DmaSelect_Sdma			= {};
	HostControl1_DmaSelect_32Adma			= {4};

	(* SoftwareReset register values *)
	SoftwareResetAll							= 1;
	SoftwareResetCmd							= 2;
	SoftwareResetDat							= 4;

	(* Clock Control register values *)
	ClockControl_InternalClockEnable			= 0;
	ClockControl_InternalClockState			= 1;
	ClockControl_SdClockEnable				= 2;
	ClockControl_ClockGeneratorSelect		= 5;
	ClockControl_SdClockFreqUpperOfs		= 6;
	ClockControl_SdClockFreqUpperMask		= {6, 7};
	ClockControl_SdClockFreqOfs				= 8;
	ClockControl_SdClockFreqMask			= {8 .. 15};

	(* Power Control register values *)
	PowerControl_SDBusPower				= 0;
	PowerControl_SDBusVoltageOfs			= 1;
	PowerControl_SDBusVoltageMask			= {1 .. 3};
	PowerControl_SDBusVoltage_18			= {1, 3};
	PowerControl_SDBusVoltage_30			= {2, 3};
	PowerControl_SDBusVoltage_33			= {1, 2, 3};

	(* Host Controller Version *)
	HostControllerVersion_SpecificationMask	= {0 .. 7};
	HostControllerVersion_VendorOfs			= 8;
	HostControllerVersion_VendorMask		= {8 .. 15};

	(* Card Status register -- R1 *)
	CardStatus_AkeSpecError					= 3;
	CardStatus_AppCmd						= 5;
	CardStatus_ReadyForData					= 8;
	CardStatus_CurrentStateOffset				= 9;
	CardStatus_CurrentStateMask				= {9 .. 12};
	CardStatus_EraseReset						= 13;
	CardStatus_CardEccDisable					= 14;
	CardStatus_WpEraseSkip					= 15;
	CardStatus_CsdOverwrite					= 16;
	CardStatus_Error							= 19;
	CardStatus_CcError							= 20;
	CardStatus_CardEccFailed					= 21;
	CardStatus_IllegalCommand				= 22;
	CardStatus_ComCrcError					= 23;
	CardStatus_LockUnlockFailed				= 24;
	CardStatus_CardIsLocked					= 25;
	CardStatus_WpViolation					= 26;
	CardStatus_EraseParam					= 27;
	CardStatus_EraseSeqError					= 28;
	CardStatus_BlockLenError					= 29;
	CardStatus_AddressError					= 30;
	CardStatus_OutOfRange					= 31;

	(* OCR Registers *)
	CardOcr_Vdd27_28							= 15;
	CardOcr_Vdd28_29							= 16;
	CardOcr_Vdd29_30							= 17;
	CardOcr_Vdd30_31							= 18;
	CardOcr_Vdd31_32							= 19;
	CardOcr_Vdd32_33							= 20;
	CardOcr_Vdd33_34							= 21;
	CardOcr_Vdd34_35							= 22;
	CardOcr_Vdd35_36							= 23;
	CardOcr_S18A								= 24;
	CardOcr_CardCapacityStatus				= 30;
	CardOcr_PowerUpStatus					= 31;

	(* CSD Register. This excludes the CRC7 of the specifications. *)
	CardCsd_FileFormatOfs					= 2;
	CardCsd_FileFormatWidth					= 2;
	CardCsd_TmpWriteProtect					= 4;
	CardCsd_PermWriteProtect					= 5;
	CardCsd_Copy								= 6;
	CardCsd_FileFormatGrp					= 7;
	CardCsd_WriteBlPartial						= 13;
	CardCsd_WriteBlLenOfs					= 14;
	CardCsd_WriteBlLenWidth					= 4;
	CardCsd_R2wFactorOfs						= 18;
	CardCsd_R2wFactorWidth					= 3;
	CardCsd_WpGrpEnable					= 23;
	CardCsd_WpGrpSizeOfs					= 24;
	CardCsd_WpGrpSizeWidth					= 7;
	CardCsd_SectorSizeOfs						= 31;
	CardCsd_SectorSizeWidth					= 7;
	CardCsd_EraseBlkEn						= 38;
	CardCsd_CSizeMultOfs1					= 39;	(** V1 *)
	CardCsd_CSizeMultWidth1					= 3;	(** V1 *)
	CardCsd_VddWCurrMaxOfs1				= 42;	(** V1 *)
	CardCsd_VddWCurrMaxWidth1			= 3;	(** V1 *)
	CardCsd_VddWCurrMinOfs1				= 45;	(** V1 *)
	CardCsd_VddWCurrMinWidth1			= 3;	(** V1 *)
	CardCsd_VddRCurrMaxOfs1				= 48;	(** V1 *)
	CardCsd_VddRCurrMaxWidth1				= 3;	(** V1 *)
	CardCsd_VddRCurrMinOfs1				= 51;	(** V1 *)
	CardCsd_VdddRCurrMaxWidth1			= 3;	(** V1 *)
	CardCsd_CSizeOfs1							= 54;	(** V1 *)
	CardCsd_CSizeWidth1						= 12;	(** V1 *)
	CardCsd_CSizeOfs2							= 40;	(** V2 *)
	CardCsd_CSizeWidth2						= 22;	(** V2 *)
	CardCsd_DsrImp							= 68;
	CardCsd_ReadBlkMisalign					= 69;
	CardCsd_WriteBlkMisalign					= 70;
	CardCsd_ReadBlPartial						= 71;
	CardCsd_ReadBlLenOfs						= 72;
	CardCsd_ReadBlLenWidth					= 4;
	CardCsd_CccOfs							= 76;
	CardCsd_CccWidth							= 12;
	CardCsd_TranSpeedOfs					= 88;
	CardCsd_TranSpeedWidth					= 8;
	CardCsd_NsacOfs							= 96;
	CardCsd_NsacWidth						= 8;
	CardCsd_TaacOfs							= 104;
	CardCsd_TaacWidth						= 8;
	CardCsd_CsdStructureOfs					= 118;
	CardCsd_CsdStructureWidth				= 2;

	(* SCR Register *)
	CardScr_CommandSupportOfs				= 32;
	CardScr_CommandSupportWidth			= 2;
	CardScr_ExtendedSecurityOfs				= 43;
	CardScr_ExtendedSecurityWidth			= 4;
	CardScr_SpecV3								= 47;
	CardScr_SdBusWidthsOfs					= 48;
	CardScr_SdBusWidthsWidth				= 4;
	CardScr_SecurityOfs						= 52;
	CardScr_SecurityWidth						= 3;
	CardScr_DataStateAfterErase				= 55;
	CardScr_SdSpecVersionOfs					= 56;
	CardScr_SdSpecVersionWidth				= 4;
	CardScr_StructureOfs						= 60;
	CardScr_StructureWidth					= 4;

	(* SCR register fields values *)
	CardScr_SdBusWidths_1					= 0;
	CardScr_SdBusWidths_4					= 2;

	(* Transfer options *)
	TxDma										= TRUE;	(** Use DMA for transfers on all hosts that support it *)
	TxBufferSize								= 4096;		(** Buffer size used for DMA transfers *)
	TxBufferAlign								= 32;		(** Alignment requirement on DMA buffer: here cache line size of ARM *)

	(* Multi-threading *)
	Synchronize *								= FALSE;	(** Do we need to take care of concurrency? *)

	(* Tracing options for debugging *)
	TraceCmd									= FALSE;
	Trace										= FALSE;

TYPE
	(** Interface for data command execute method of host controller *)
	CommandExecuter * = PROCEDURE (CONST command: Command; VAR data: ARRAY OF CHAR; ofs, len: SIGNED32; VAR result: SIGNED32): BOOLEAN;

	(**
		SD Host controller descriptor.
	*)
	HostController * = POINTER TO HostControllerDesc;
	HostControllerDesc * = RECORD
		baseFrequency -,					(** Base hc clock frequency *)
		frequency -,						(** Bus frequency *)
		timeoutFreq,						(** Timeout clock frequency *)
		state -,								(** HC state *)
		version -: SIGNED32;				(** Specifications version *)
		execute -: CommandExecuter;	(** Method to execute command with data transmission *)
		opmode,							(** Host controller operation mode for data transfers *)
		lastRca: SIGNED32;					(** Last RCA selected by the controller. *)
		acquire *, release *: PROCEDURE {DELEGATE};
		handle: EventHandler;				(** Card event handler *)
		handlerParam: ANY;				(** Parameter of the eventHandler *)
		regs: HcRegisters;					(** Memory-mapped I/O registers *)
		cards: Card;						(** List of cards on this HC *)
		next: HostController;				(** Linked list of controllers for interrupt handling *)
		dmaBuf: POINTER TO ARRAY OF CHAR;
		dmaBufAdr: ADDRESS;
		desc: ARRAY 5 OF SIGNED64;					(** DMA descriptor *)
		descOfs: SIGNED32;
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
		hc *: HostController;					(** Host controller on which the command is executed *)
		rca *,									(** Optional RCA parameter. Required only for ACMDs *)
		command *,							(** Command number *)
		argument *,							(** Command argument *)
		responseType *: SIGNED32;			(** Response type *)
		flags *: SET;							(** Command flags *)
		response *: ARRAY 4 OF SIGNED32;	(** Response *)
	END;

	(** Card descriptor *)
	Card * = POINTER TO CardDesc;
	CardDesc * = RECORD
		state -,									(** Card state. Currently not used *)
		(*type -,									(** Type of card. One of 'Type*' constants *)*)
		rca -: SIGNED32;						(** Card RCA *)
		cid: ARRAY 4 OF SIGNED32;			(** Raw CID *)
		csd -: Csd;								(** CSD *)
		scr -: Scr;								(** SCR *)
		ocr: SET;								(** Raw OCR *)
		hc -: HostController;					(** Host controller on which the card is attached *)
		next: Card;								(** Internal linked list of cards attached to the same HC *)
		acquire *, release *: PROCEDURE {DELEGATE};
	END;

	(* Card Registers *)
	Csd * = RECORD
		(* Card properties *)
		capacity *: SIGNED64;							(** Card capacity in bytes *)
		sectorSize *: SIGNED32;						(** Size of a sector in bytes *)
		commandClasses *: SET;						(** Command classes supported by the card *)

		(* Timing info *)
		r2w *: SIGNED32;								(** Read to write time factor = read time / write time *)
		taac *: FLOAT32;									(** Asynchronous access time, in s *)
		nsac *: SIGNED32;								(** Worst-case clock dependent access time, in clock cycles *)
		txSpeed *: SIGNED32;							(** Max transfer speed in bit/s *)
	END;

	(** SCR register *)
	Scr * = RECORD
		version *,										(** Card physical spec. version: one of Version* *)
		security *: SIGNED32;							(** Card security type: one of Type* *)
		busWidth *: SET;								(** Bus widths supported by the card *)
	END;

	(** SWITCH_FUNC returned status *)
	SwitchFuncStatus * = RECORD
		current *: SIGNED32;							(** Current for specified config *)
		functionGroups *: ARRAY 6 OF SET;			(** Supported function in each group *)
		functionStatus *: ARRAY 6 OF SIGNED32;	(** Function status *)
	END;

	(** Card event handler. 'card' is the card for which an event is reported (can be a new card object) and 'event' is one of 'On*' constants *)
	EventHandler * = PROCEDURE {DELEGATE} (card: Card; event: SIGNED32; param: ANY);

	(** Host controller registers *)
	HcRegisters = POINTER {UNSAFE,UNTRACED} TO RECORD
		SDMASystemAddress {ALIGNED(1)}: SIGNED32;				(** offset = 0H *)
		BlockSize {ALIGNED(1)},										(** offset = 4H *)
		BlockCount {ALIGNED(1)}: SIGNED16;							(** offset = 6H *)
		Argument1 {ALIGNED(1)}: SIGNED32;							(** offset = 8H *)
		TransferMode {ALIGNED(1)},									(** offset = 0CH *)
		Command {ALIGNED(1)}: SIGNED16;							(** offset = 0EH *)
		Response {ALIGNED(1)}: ARRAY 4 OF SIGNED32;			(** offset = 10H *)
		BufferData {ALIGNED(1)}: SIGNED32;
		PresentState {ALIGNED(1)}: SET;
		HostControl1 {ALIGNED(1)},
		PowerControl {ALIGNED(1)},
		BlockGapControl {ALIGNED(1)},
		WakeupControl {ALIGNED(1)}: SIGNED8;
		ClockControl {ALIGNED(1)}: SIGNED16;
		TimeoutControl {ALIGNED(1)},
		SoftwareReset {ALIGNED(1)}: SIGNED8;
		InterruptStatus {ALIGNED(1)},
		InterruptStatusEnable {ALIGNED(1)},
		InterruptSignalEnable {ALIGNED(1)}: SET;
		AutoCmdErrorStatus {ALIGNED(1)},
		HostControl2 {ALIGNED(1)}: SIGNED16;
		Capabilities {ALIGNED(1)}: ARRAY 2 OF SET;
		MaximumCurrentCapabilities {ALIGNED(1)}: SIGNED64;
		ForceEventAutoCmdErrorStatus {ALIGNED(1)},
		ForceEventErrorInterruptStatus {ALIGNED(1)}: SIGNED16;
		AdmaErrorStatus {ALIGNED(1)}: SIGNED8;
		padding0 {ALIGNED(1)}: ARRAY 3 OF SIGNED8;
		AdmaSystemAddress {ALIGNED(1)}: SIGNED64;
		PresetValues {ALIGNED(1)}: ARRAY 8 OF SIGNED16;
		padding1 {ALIGNED(1)}: ARRAY 28 OF SIGNED32;
		SharedBusControl {ALIGNED(1)}: SIGNED32;
		padding2 {ALIGNED(1)}: ARRAY 6 OF SIGNED32;
		SlotInterruptStatus {ALIGNED(1)},
		HostControllerVersion {ALIGNED(1)}: SIGNED16;
	END;

VAR
	(** List of all host controllers *)
	hcs: HostController;

	(* ==================== Host Controller (Low-Level) Interface ==================== *)
	(**
		Create an host controller descriptor and initializes it with the given info.
		'baseAddress' is the base address of the IO registers.
		'extClockFreq' is an optional external clock frequency. It is used iff the host controller has no information about its clock frequency.
		'handler' is the event handler and 'param' is user parameter.
	*)
	PROCEDURE New * (baseAddress: ADDRESS; extClockFreq: SIGNED32; handler: EventHandler; param: ANY): HostController;
	VAR
		hc: HostController;
		val, result: SIGNED32;
	BEGIN
		NEW(hc);
		hc.regs := baseAddress;
		hc.handle := handler;
		IF ~Reset(hc, TRUE, TRUE) THEN RETURN NIL END;
		hc.baseFrequency := LSH(SYSTEM.VAL(SIGNED32, hc.regs.Capabilities[0] * Capabilities_BaseClockFreqSdMask), -Capabilities_BaseClockFreqSdOfs);
		IF hc.baseFrequency = 0 THEN
			hc.baseFrequency := extClockFreq
		END;
		hc.timeoutFreq := LSH(SYSTEM.VAL(SIGNED32, hc.regs.Capabilities[0] * Capabilities_TimeoutClockFrequencyMask), -Capabilities_TimeoutClockFrequencyOfs) * 1000;
		IF Capabilities_TimeoutClockUnit IN hc.regs.Capabilities[0] THEN hc.timeoutFreq := hc.timeoutFreq * 1000 END;
		IF hc.timeoutFreq = 0 THEN hc.timeoutFreq := extClockFreq END;
		SetBusClock(hc, InitialClockFrequency);
		SetTimeout(hc, 10);

		(* Power select 3.3V bus voltage *)
		hc.regs.PowerControl :=  SYSTEM.VAL(SIGNED8, PowerControl_SDBusVoltage_33 + {PowerControl_SDBusPower});

		(* Enable All Interrupts *)
		hc.regs.InterruptStatusEnable := Interrupt_All;
		hc.regs.InterruptSignalEnable := {Interrupt_Normal_CardInsertion, Interrupt_Normal_CardRemoval};
		hc.regs.BlockGapControl := 0;

		val := SIGNED32(hc.regs.HostControllerVersion);
		hc.version := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, val) * HostControllerVersion_SpecificationMask) + 1;

		IF Trace THEN
			SdEnvironment.String("[SD] New Host Controller v");
			SdEnvironment.Int(hc.version, 0);
			SdEnvironment.String(" at ");
			SdEnvironment.Address(baseAddress);
			SdEnvironment.Ln;
		END;

		IF Synchronize THEN SdEnvironment.GetLock(hc.acquire, hc.release) END;

		(* Select method according to DMA support *)
		IF TxDma THEN
			IF (Capabilities_ADMA2 IN hc.regs.Capabilities[0]) THEN
				hc.execute := ExecuteAdmaCommand;
				hc.opmode := OpAdma;
				INC(hc.regs.HostControl1, 10H);
				NEW(hc.dmaBuf, TxBufferSize + TxBufferAlign);
				hc.dmaBufAdr := ADDRESSOF(hc.dmaBuf[0]) + (TxBufferAlign) - ADDRESSOF(hc.dmaBuf[0]) MOD (TxBufferAlign);
				hc.descOfs := (TxBufferAlign - ADDRESSOF(hc.desc[0]) MOD TxBufferAlign) DIV SIZEOF(SIGNED64);

				ASSERT(hc.dmaBufAdr MOD TxBufferAlign = 0);
				(*! NOT IMPLEMENTED YET *)(*ELSIF (Capabilities_SDMA IN hc.regs.Capabilities[0]) THEN
				SdEnvironment.String("[SD] Host Controller uses SDMA");
				SdEnvironment.Ln;
				hc.execute := ExecuteAdmaCommand;
				hc.opmode := OpSdma*)
			ELSE
				hc.execute := ExecuteDataCommand;
				hc.opmode := OpCpu
			END
		ELSE
			hc.execute := ExecuteDataCommand;
			hc.opmode := OpCpu
		END;

		(* If there is a card already, initialize it *)
		IF (PresentState_CardInserted IN hc.regs.PresentState) & (PresentState_CardStateStable IN hc.regs.PresentState) THEN
			NEW(hc.cards);
			IF InitCard(hc, hc.cards, result) & (hc.handle # NIL) THEN
				hc.handle(hc.cards, OnInitialization, hc.handlerParam)
			ELSIF hc.handle # NIL THEN
				SdEnvironment.String("[SD] Could not initialize inserted card: error ");
				SdEnvironment.Int(result, 0);
				SdEnvironment.Ln
			END
		END;

		hc.next := hcs;
		hcs := hc;
		RETURN hc
	END New;

	(**
		Execute the command 'command', without data transfer. If you need data transfer, use 'ExecuteDataCommand'.
		Performs all necessary steps for executing a command:
			o Runs CMD55 if command is an application command
			o Execute the command
			o Wait for response
	*)
	PROCEDURE ExecuteCommand * (VAR command: Command; VAR result: SIGNED32): BOOLEAN;
	VAR
		status, r1: SET;
	BEGIN
		IF Synchronize THEN command.hc.acquire END;
		result := ErrorNone;
		(* Check Parameters *)
		IF {FlagData, FlagRead, FlagAutoCmd12, FlagAutoCmd23, FlagMultipleBlockTx, FlagCountBlocks, FlagUseDma} * command.flags # {} THEN
			result := ErrorInvalidParameters;
			IF Synchronize THEN command.hc.release END;
			RETURN FALSE
		END;

		(*IF ~Reset(command.hc, TRUE, FALSE) THEN
			result := ErrorCard;
			IF Synchronize THEN command.hc.release END;
			RETURN FALSE
		END;*)

		IF (FlagApplicationCmd IN command.flags) THEN
			IF ~StartCommand(command.hc, CMD_APP_CMD, LSH(command.rca, 16), ResponseR1, FlagRead IN command.flags, FALSE, FALSE, FALSE, status, result) THEN
				IF Synchronize THEN command.hc.release END;
				RETURN FALSE
			END;
			r1 := GetR1(command);
			IF Trace THEN PrintCardStatus(r1) END;
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
	PROCEDURE ExecuteDataCommand (CONST command: Command; VAR data: ARRAY OF CHAR; ofs, len: SIGNED32; VAR result: SIGNED32): BOOLEAN;
	TYPE
		DataBytes = ARRAY 4 OF CHAR;
	VAR
		tmp: DataBytes;
		i, stepLen: SIGNED32;
		hc: HostController;
		r1, status: SET;
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
		(*SetTimeout(hc, 2);*)
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
			IF Trace THEN
				SdEnvironment.String("[SD] CMD55 Status:");
				SdEnvironment.Ln;
				PrintCardStatus(r1)
			END
		END;

		(* 1 *)
		IF ~(FlagApplicationCmd IN command.flags) &
				((command.command = CMD_READ_SINGLE_BLOCK) OR (command.command = CMD_READ_MULTIPLE_BLOCK) OR
				(command.command = CMD_WRITE_BLOCK) OR (command.command = CMD_WRITE_MULTIPLE_BLOCK) OR
				(command.command = 53)(* SDIO Command *)) THEN
			IF len <= BlockSize THEN
				hc.regs.BlockSize := SIGNED16(len);
				hc.regs.BlockCount := 1
			ELSE
				hc.regs.BlockSize := BlockSize;
				hc.regs.BlockCount := SIGNED16(len DIV BlockSize)
			END;

			IF Trace THEN
				SdEnvironment.String("[SD] ");
				IF FlagRead IN command.flags THEN SdEnvironment.String("Read")
				ELSE SdEnvironment.String("Write") END;
				SdEnvironment.String(" parameters:"); SdEnvironment.Ln;
				SdEnvironment.String("[SD] 	Block Size = "); SdEnvironment.Int(hc.regs.BlockSize, 0); SdEnvironment.Ln;
				SdEnvironment.String("[SD] 	Block Count = "); SdEnvironment.Int(hc.regs.BlockCount, 0); SdEnvironment.Ln;
				SdEnvironment.String("[SD] 	CMD"); SdEnvironment.Int(command.command, 0); SdEnvironment.Ln;
				SdEnvironment.String("[SD] 	Argument = "); SdEnvironment.Address(command.argument); SdEnvironment.Ln
			END
		END;

		(* 3 - 8 *)
		(*IF (hc.regs.BlockSize < BlockSize) THEN
			IF ~StartCommand(hc, CMD_SET_BLOCKLEN, hc.regs.BlockSize, ResponseR1, FALSE, FALSE, result) THEN
				RETURN FALSE
			END
		END;*)
		IF ~StartCommand(hc, command.command, command.argument, ResponseR1, FlagRead IN command.flags, FALSE, TRUE, FALSE, status, result) THEN RETURN FALSE END;
		r1 := SYSTEM.VAL(SET, command.response[0]);
		IF CardStatus_Error IN r1 THEN
			IF Synchronize THEN hc.release END;
			RETURN FALSE
		END;
		IF Trace THEN PrintCardStatus(r1) END;

		WHILE len > 0 DO
			(* 14 *)
			IF FlagRead IN command.flags THEN
				REPEAT UNTIL (Interrupt_Normal_BufferReadReady IN hc.regs.InterruptStatus) OR (Interrupt_Normal_ErrorInterrupt IN hc.regs.InterruptStatus)
			ELSE
				REPEAT UNTIL (Interrupt_Normal_BufferWriteReady IN hc.regs.InterruptStatus) OR (Interrupt_Normal_ErrorInterrupt IN hc.regs.InterruptStatus)
			END;

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
			INCL(hc.regs.InterruptStatus, Interrupt_Normal_BufferReadReady);

			(* 16 *)
			stepLen := MIN(BlockSize, len);
			IF FlagRead IN command.flags THEN
				FOR i := 0 TO stepLen - 1 BY 4 DO
					SYSTEM.PUT32(ADDRESSOF(data[ofs + i]), hc.regs.BufferData);
					(*SYSTEM.VAL(SIGNED32, tmp) := hc.regs.BufferData;
					SYSTEM.VAL(DataBytes, data[ofs + i]) := tmp*)
				END
			ELSE
				FOR i := 0 TO stepLen - 1 BY 4 DO
					tmp := SYSTEM.VAL(DataBytes, data[ofs + i]);
					hc.regs.BufferData := SYSTEM.VAL(SIGNED32, tmp);
				END
			END;
			(* 17 *)
			INC(ofs, stepLen);
			DEC(len, stepLen)
		END;

		(* 18 -> Not infinite block *)
		REPEAT UNTIL Interrupt_Normal_TransferComplete IN hc.regs.InterruptStatus;
		(* 19 *)
		INCL(hc.regs.InterruptStatus, Interrupt_Normal_TransferComplete);

		(*DEC(hc.regs.ClockControl, LSH(1, ClockControl_SdClockEnable));
		hc.regs.SoftwareReset := SYSTEM.VAL(SIGNED8, {SoftwareResetCmd, SoftwareResetDat});
		REPEAT UNTIL hc.regs.SoftwareReset = 0;
		INC(hc.regs.ClockControl, LSH(1, ClockControl_SdClockEnable));*)

		IF Synchronize THEN hc.release END;
		RETURN Reset(hc, TRUE, FALSE) & Reset(hc, FALSE, TRUE)
	END ExecuteDataCommand;

	(**
		Execute Command with data transfers using ADMA
	*)
	PROCEDURE ExecuteAdmaCommand (CONST command: Command; VAR data: ARRAY OF CHAR; ofs, len: SIGNED32; VAR result: SIGNED32): BOOLEAN;
	TYPE
		QWord = ARRAY 2 OF ADDRESS;
	VAR
		(*!DBG*)t: SIGNED64;
		hc: HostController;
		desc: SIGNED64;
		r1, status: SET;
		address: ADDRESS;
	BEGIN
		hc := command.hc;
		(* Setup descriptor *)
		address := (*command.hc.dmaBufAdr*)ADDRESSOF(data[ofs]);
		SYSTEM.VAL(QWord, desc)[1] := address;
		SYSTEM.VAL(QWord, desc)[0] := LSH(len, 16) + 27H;
		hc.desc[hc.descOfs] := desc;
		SdEnvironment.FlushDCacheRange(ADDRESSOF(hc.desc[hc.descOfs]), 8);

		(*IF ~(FlagRead IN command.flags) THEN
			SYSTEM.MOVE(ADDRESSOF(data[ofs]), address, len);
		END;*)
		SdEnvironment.FlushDCacheRange(address, len);

		IF Synchronize THEN hc.acquire END;
		SetTimeout(hc, 10);
		IF ~Reset(hc, TRUE, FALSE) OR ~Reset(hc, FALSE, TRUE) THEN
			result := ErrorCard;
			IF Synchronize THEN hc.release END;
			RETURN FALSE
		END;

		(* 1 *)
		hc.regs.AdmaSystemAddress := ADDRESSOF(hc.desc[hc.descOfs]);

		IF (FlagApplicationCmd IN command.flags) THEN
			IF ~StartCommand(command.hc, CMD_APP_CMD, LSH(command.rca, 16), ResponseR1, FlagRead IN command.flags, FALSE, FALSE, FALSE, status, result) THEN
				IF Synchronize THEN hc.release END;
				RETURN FALSE
			END;
			r1 := SYSTEM.VAL(SET, command.response[0]);
			IF Trace THEN
				SdEnvironment.String("[SD] CMD55 Status:");
				SdEnvironment.Ln;
				PrintCardStatus(r1)
			END;
			IF CardStatus_Error IN r1 THEN
				result := ErrorCard;
				IF Synchronize THEN hc.release END;
				RETURN FALSE
			END
		END;

		(* 2-3 *)
		IF FlagData IN command.flags(*((command.command = CMD_READ_SINGLE_BLOCK) OR (command.command = CMD_READ_MULTIPLE_BLOCK) OR
				(command.command = CMD_WRITE_BLOCK) OR (command.command = CMD_WRITE_MULTIPLE_BLOCK) OR
				(command.command = 53)(* SDIO Command *))*) THEN
			IF len <= BlockSize THEN
				hc.regs.BlockSize := SIGNED16(len);
				hc.regs.BlockCount := 1
			ELSE
				hc.regs.BlockSize := BlockSize;
				hc.regs.BlockCount := SIGNED16(len DIV BlockSize)
			END;

			IF Trace THEN
				SdEnvironment.String("[SD] ");
				IF FlagRead IN command.flags THEN SdEnvironment.String("Read")
				ELSE SdEnvironment.String("Write") END;
				SdEnvironment.String(" parameters:"); SdEnvironment.Ln;
				SdEnvironment.String("[SD] 	Block Size = "); SdEnvironment.Int(hc.regs.BlockSize, 0); SdEnvironment.Ln;
				SdEnvironment.String("[SD] 	Block Count = "); SdEnvironment.Int(hc.regs.BlockCount, 0); SdEnvironment.Ln;
				SdEnvironment.String("[SD] 	CMD"); SdEnvironment.Int(command.command, 0); SdEnvironment.Ln;
				SdEnvironment.String("[SD] 	Argument = "); SdEnvironment.Address(command.argument); SdEnvironment.Ln
			END
		END;

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
		IF Trace THEN PrintCardStatus(r1) END;

		WHILE ~((Interrupt_Normal_TransferComplete IN status) OR (Interrupt_Normal_ErrorInterrupt IN status)) DO
			status := hc.regs.InterruptStatus
		END;
		IF Interrupt_Normal_ErrorInterrupt IN status THEN
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
		hc.regs.InterruptStatus := status;
		IF FlagRead IN command.flags THEN
			SdEnvironment.InvalidateDCacheRange(address, len);
			(*SYSTEM.MOVE(address, ADDRESSOF(data[ofs]), len)*)
		END;
		IF Synchronize THEN hc.release END;
		RETURN TRUE
	END ExecuteAdmaCommand;

	(** Read response R1 or R1b from command record *)
	PROCEDURE GetR1 * (CONST command: Command): SET;
	VAR
		idx: SIGNED32;
	BEGIN
		idx := 0;
		(*IF (FlagAutoCmd12 IN command.flags) OR (FlagAutoCmd23 IN command.flags) THEN
			idx := 3
		END;*)
		RETURN SYSTEM.VAL(SET, command.response[idx])
	END GetR1;

	(** Read response R2 from command record *)
	PROCEDURE GetR2 * (CONST command: Command; VAR response: ARRAY OF SIGNED32);
	VAR
		i: SIGNED32;
	BEGIN
		FOR i := 0 TO 3 DO
			response[i] := command.response[i]
		END
	END GetR2;

	(** Read response R3 from command record *)
	PROCEDURE GetR3 * (CONST command: Command): SIGNED32;
	BEGIN
		RETURN command.response[0]
	END GetR3;

	(** Read response R4 from command record *)
	PROCEDURE GetR4 * (CONST command: Command): SIGNED32;
	BEGIN
		RETURN command.response[0]
	END GetR4;

	(** Read response R5 from command record *)
	PROCEDURE GetR5 * (CONST command: Command): SIGNED32;
	BEGIN
		RETURN command.response[0]
	END GetR5;

	(** Read response R6 from command record *)
	PROCEDURE GetR6 * (CONST command: Command): SIGNED32;
	BEGIN
		RETURN command.response[0]
	END GetR6;

	(** Read response R7 from command record *)
	PROCEDURE GetR7 * (CONST command: Command): SIGNED32;
	BEGIN
		RETURN command.response[0]
	END GetR7;

	PROCEDURE SetEventHandler * (hc: HostController; handler: EventHandler; param: ANY);
	BEGIN
		hc.handle := handler;
		hc.handlerParam := param
	END SetEventHandler;

	(* ==================== Card (High-Level) Interface ==================== *)
	(** Write 'data[ofs, ofs + len)' to 'card', starting at block 'firstBlock'. *)
	PROCEDURE Write * (card: Card; firstBlock, len: SIGNED32; VAR data: ARRAY OF CHAR; ofs: SIGNED32; VAR result: SIGNED32): BOOLEAN;
	VAR
		command: Command;
		ret: BOOLEAN;
		r1: SET;
	BEGIN
		IF Synchronize THEN card.acquire END;
		IF ~SelectCard(card, result) THEN
			IF Synchronize THEN card.release END;
			RETURN FALSE
		END;

		command.hc := card.hc;
		command.argument := firstBlock;
		command.responseType := ResponseR1;
		command.flags := {FlagData};
		command.rca := card.rca;
		IF len > BlockSize THEN
			INCL(command.flags, FlagMultipleBlockTx);
			INCL(command.flags, FlagCountBlocks);
			INCL(command.flags, FlagAutoCmd12);
			command.command := CMD_WRITE_MULTIPLE_BLOCK
		ELSE
			command.command := CMD_WRITE_BLOCK
		END;
		ret := command.hc.execute(command, data, ofs, len, result);
		IF Synchronize THEN card.release END;
		RETURN ret
		(*IF command.hc.execute(command, data, ofs, len, result) & ~(CardStatus_Error IN GetR1(command)) THEN
			command.flags := {};
			command.argument := 0;
			command.command := CMD_SEND_STATUS;
			command.responseType := ResponseR1;
			REPEAT
				IF ~ExecuteCommand(command, result) THEN RETURN FALSE END;
				r1 := GetR1(command);
				IF CardStatus_Error IN r1 THEN RETURN FALSE END
			UNTIL CardStatus_ReadyForData IN r1;
			RETURN TRUE
		ELSE
			RETURN FALSE
		END*)
	END Write;

	(** Read 'len' bytes starting from 'firstBlock' of 'card' to 'data[ofs, ofs + len)' *)
	PROCEDURE Read * (card: Card; firstBlock, len: SIGNED32; VAR data: ARRAY OF CHAR; ofs: SIGNED32; VAR result: SIGNED32): BOOLEAN;
	VAR
		command: Command;
		ret: BOOLEAN;
	BEGIN
		IF Synchronize THEN card.acquire END;
		IF ~SelectCard(card, result) THEN
			IF Synchronize THEN card.release END;
			RETURN FALSE
		END;

		command.hc := card.hc;
		command.argument := firstBlock;
		command.responseType := ResponseR1;
		command.flags := {FlagData, FlagRead};
		command.rca := card.rca;
		IF len > BlockSize THEN
			INCL(command.flags, FlagMultipleBlockTx);
			INCL(command.flags, FlagCountBlocks);
			INCL(command.flags, FlagAutoCmd12);
			command.command := CMD_READ_MULTIPLE_BLOCK
		ELSE
			command.command := CMD_READ_SINGLE_BLOCK
		END;
		ret := command.hc.execute(command, data, ofs, len, result) & ~(CardStatus_Error IN GetR1(command));
		IF Synchronize THEN card.release END;
		RETURN ret
	END Read;

	PROCEDURE Erase * (card: Card; block, num: SIGNED32; VAR result: SIGNED32): BOOLEAN;
	VAR
		command: Command;
		r1: SET;
	BEGIN
		command.hc := card.hc;
		command.flags := {};
		command.rca := card.rca;

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

	PROCEDURE Reset (hc: HostController; cmd, dat: BOOLEAN): BOOLEAN;
	VAR
		val: SIGNED8;
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

	PROCEDURE SetBusClock (hc: HostController; freq: SIGNED32);
	VAR
		divisor, d, val: SIGNED32;
	BEGIN
		hc.regs.ClockControl := 0;
		divisor := hc.baseFrequency DIV freq;
		IF divisor = 0 THEN
			(* requested freq is higher that base freq *)
			divisor := 1
		END;
		IF hc.baseFrequency DIV divisor > freq THEN INC(divisor) END;
		val := 0;
		ASSERT(divisor > 0);
		d := divisor;
		WHILE d # 1 DO
			d := d DIV 2;
			INC(val)
		END;
		IF val >= 8 THEN val := 7 END;
		ASSERT(val < 8);
		(*val := divisor * 2;*)
		hc.regs.ClockControl := SIGNED16(LSH(LSH(SIGNED32(1), val), 8) + SYSTEM.VAL(SIGNED16, {ClockControl_InternalClockEnable}));
		hc.frequency := hc.baseFrequency DIV (LSH(SIGNED32(1), val));
		REPEAT val := hc.regs.ClockControl UNTIL ClockControl_InternalClockState IN SYSTEM.VAL(SET, val);
		val := hc.regs.ClockControl;
		hc.regs.ClockControl := SYSTEM.VAL(SIGNED16, SYSTEM.VAL(SET, val) + {ClockControl_SdClockEnable});
		IF Trace THEN
			SdEnvironment.String("[SD] Selecting Bus Clock Frequency: ");
			SdEnvironment.Int(hc.frequency, 0);
			SdEnvironment.Ln
		END;
		(*SetTimeout(hc, 10); (* 100ms *)*)
	END SetBusClock;

	PROCEDURE SetTimeout (hc: HostController; timeoutFreq: SIGNED32);
	VAR
		ratio, val: SIGNED32;
	BEGIN
		ratio := hc.frequency DIV timeoutFreq DIV 8192;
		val := 0;
		REPEAT
			INC(val);
			ratio := ratio DIV 2
		UNTIL ratio = 0;
		hc.regs.TimeoutControl := SYSTEM.VAL(SIGNED8, val);
	END SetTimeout;

	PROCEDURE SetBusWidth (hc: HostController; rca, width: SIGNED32; VAR result: SIGNED32): BOOLEAN;
	VAR
		command: Command;
		val: SIGNED32;
	BEGIN
		(* 1 *)
		(*EXCL(hc.regs.InterruptStatusEnable, Interrupt_Normal_CardInterrupt);*)

		(* 2: driver supports SD cards only *)
		(* 3: not implemented *)

		(* 4 *)
		command.command := ACMD_SET_BUS_WIDTH;
		CASE width OF
			 1: command.argument := 0
			|4: command.argument := 2
		END;
		command.hc := hc;
		command.rca := rca;
		command.flags := {FlagApplicationCmd};
		command.responseType := ResponseR1;
		IF ~ExecuteCommand(command, result) THEN RETURN FALSE END;

		(* 5 *)
		val := hc.regs.HostControl1;
		CASE width OF
			 1: EXCL(SYSTEM.VAL(SET, val), HostControl1_DataWidthTransfer)
			|4: INCL(SYSTEM.VAL(SET, val), HostControl1_DataWidthTransfer)
		END;
		hc.regs.HostControl1 := SIGNED8(val);

		(* 6: SD card only *)

		(* 8 *)
		(*INCL(hc.regs.InterruptStatusEnable, Interrupt_Normal_CardInterrupt);*)
		RETURN TRUE
	END SetBusWidth;

	PROCEDURE HandleInterrupt * (hc: HostController);
	VAR
		card: Card;
		result: SIGNED32;
	BEGIN
		IF Trace THEN SdEnvironment.String("[SD] Interrupt: "); SdEnvironment.Set(hc.regs.InterruptStatus); SdEnvironment.Ln END;
		IF Interrupt_Normal_CardInsertion IN hc.regs.InterruptStatus THEN
			IF Trace THEN SdEnvironment.String("[SD] Card Insertion"); SdEnvironment.Ln END;
			NEW(card);
			IF InitCard(hc, card, result) & (hc.handle # NIL) THEN
				hc.handle(card, OnInitialization, hc.handlerParam)
			ELSIF Trace THEN
				SdEnvironment.String("[SD] Could not initialize card");
				SdEnvironment.Ln
			END
		ELSIF Interrupt_Normal_CardRemoval IN hc.regs.InterruptStatus THEN
			IF Trace THEN SdEnvironment.String("[SD] Card Removal"); SdEnvironment.Ln END;
			card := hc.cards;
			IF hc.handle #NIL THEN hc.handle(card, OnRemoval, hc.handlerParam) END;
			hc.cards := hc.cards.next
		END;
		hc.regs.InterruptStatus := hc.regs.InterruptStatus
	END HandleInterrupt;

	PROCEDURE InitCard * (hc: HostController; card: Card; VAR result: SIGNED32): BOOLEAN;
	VAR
		csd: ARRAY 4 OF SIGNED32;
		response: SIGNED32;
		status: SET;
		f8, sdio: BOOLEAN;
		command: Command;
		i: SIGNED32;
	BEGIN
		SetBusClock(hc, 400000);

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
		ELSIF result # ErrorNone THEN
			RETURN FALSE
		ELSE
			sdio := TRUE;
		END;
		IF Trace THEN SdEnvironment.String("[SD] Card is SDIO: "); SdEnvironment.Boolean(sdio); SdEnvironment.Ln END;

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
		(*IF ~StartCommand(hc, CMD_APP_CMD, 0, ResponseR1, FALSE, FALSE, res) THEN
			RETURN FALSE
		END;
		IF CardStatus_Error IN Response1(hc) THEN RETURN FALSE END;*)
		IF ~ExecuteCommand(command, result) THEN RETURN FALSE END;
		response := GetR3(command);
		IF Trace THEN
			SdEnvironment.String("[SD] VDD: Ranges Supported by Card:"); SdEnvironment.Ln;
			IF CardOcr_Vdd27_28 IN SYSTEM.VAL(SET, response) THEN SdEnvironment.String("[SD] 	2.7 - 2.8 V"); SdEnvironment.Ln END;
			IF CardOcr_Vdd28_29 IN SYSTEM.VAL(SET, response) THEN SdEnvironment.String("[SD] 	2.8 - 2.9 V"); SdEnvironment.Ln END;
			IF CardOcr_Vdd29_30 IN SYSTEM.VAL(SET, response) THEN SdEnvironment.String("[SD] 	2.9 - 3.0 V"); SdEnvironment.Ln END;
			IF CardOcr_Vdd30_31 IN SYSTEM.VAL(SET, response) THEN SdEnvironment.String("[SD] 	3.0 - 3.1 V"); SdEnvironment.Ln END;
			IF CardOcr_Vdd31_32 IN SYSTEM.VAL(SET, response) THEN SdEnvironment.String("[SD] 	3.1 - 3.2 V"); SdEnvironment.Ln END;
			IF CardOcr_Vdd32_33 IN SYSTEM.VAL(SET, response) THEN SdEnvironment.String("[SD] 	3.2 - 3.3 V"); SdEnvironment.Ln END;
			IF CardOcr_Vdd33_34 IN SYSTEM.VAL(SET, response) THEN SdEnvironment.String("[SD] 	3.3 - 3.4 V"); SdEnvironment.Ln END;
			IF CardOcr_Vdd34_35 IN SYSTEM.VAL(SET, response) THEN SdEnvironment.String("[SD] 	3.4 - 3.5 V"); SdEnvironment.Ln END;
			IF CardOcr_Vdd35_36 IN SYSTEM.VAL(SET, response) THEN SdEnvironment.String("[SD] 	3.5 - 3.6 V"); SdEnvironment.Ln END
		END;

		status := {30};
		IF Capabilities_Voltage30 IN hc.regs.Capabilities[0] THEN
			IF Trace THEN SdEnvironment.String("[SD] Selecting 3.0 V"); SdEnvironment.Ln END;
			INCL(status, CardOcr_Vdd30_31)
		ELSIF Capabilities_Voltage33 IN hc.regs.Capabilities[0] THEN
			IF Trace THEN SdEnvironment.String("[SD] Selecting 3.3 V"); SdEnvironment.Ln END;
			INCL(status, CardOcr_Vdd32_33)
		END;

		command.command := ACMD_SD_SEND_OP_COND;
		command.argument := SYSTEM.VAL(SIGNED32, status);
		command.responseType := ResponseR3;
		command.flags := {FlagApplicationCmd, FlagIgnoreIllegalCmd};
		REPEAT
			IF ~ExecuteCommand(command, result) THEN RETURN FALSE END;
			status := SYSTEM.VAL(SET, GetR3(command));
		UNTIL (CardOcr_PowerUpStatus IN status);
		IF Trace & (CardOcr_S18A IN status) THEN
			SdEnvironment.String("[SD] Card supports 1.8V");
			SdEnvironment.Ln
		END;
		IF f8 & (CardOcr_CardCapacityStatus IN status) THEN
			IF Trace THEN SdEnvironment.String("[SD] Card: SDHC or SDXC") END;
			card.scr.security := TypeSDHC
		ELSIF f8 THEN
			IF Trace THEN SdEnvironment.String("[SD] Card: SDSC v2 or v3") END;
			card.scr.security := TypeSDSC
		ELSE
			IF Trace THEN SdEnvironment.String("[SD] Card: SDSC v1.0 or v1.1") END;
			card.scr.security := TypeSDSC
		END;
		IF Trace THEN SdEnvironment.Ln END;

		(* 32 *)
		command.command := CMD_ALL_SEND_CID;
		command.argument := 0;
		command.responseType := ResponseR2;
		command.flags := {};
		IF ~ExecuteCommand(command, result) THEN RETURN FALSE END;
		GetR2(command, card.cid);

		(* 33 *)
		command.command := CMD_SEND_RELATIVE_ADDR;
		command.argument := 0;
		command.responseType := ResponseR6;
		command.flags := {};
		REPEAT
			IF ~ExecuteCommand(command, result) THEN RETURN FALSE END;
			card.rca := LSH(GetR6(command), -16)
		UNTIL card.rca # 0;
		IF Trace THEN SdEnvironment.String("[SD] New Card with RCA: "); SdEnvironment.Hex(card.rca, -4); SdEnvironment.Ln END;
		status := SYSTEM.VAL(SET, GetR6(command));
		status := status * {0 .. 15};
		(* status is a modified CardStatus: reform corresponding card status *)
		IF 15 IN status THEN EXCL(status, 15); INCL(status, 23) END;
		IF 14 IN status THEN EXCL(status, 14); INCL(status, 22) END;
		IF 13 IN status THEN EXCL(status, 13); INCL(status, 19) END;
		IF Trace THEN PrintCardStatus(status) END;
		card.hc := hc;
		card.next := hc.cards;
		hc.cards := card;
		IF Synchronize THEN SdEnvironment.GetLock(card.acquire, card.release) END;

		(* Get Additional card registers: CSD *)
		command.command := CMD_SEND_CSD;
		command.argument := LSH(card.rca, 16);
		command.responseType := ResponseR2;
		command.flags := {};
		IF ~ExecuteCommand(command, result) THEN RETURN FALSE END;
		GetR2(command, csd);
		GetCsd(csd, card.csd);
		IF Trace THEN
			SdEnvironment.String("[SD] Card Capacity: "); SdEnvironment.Int(card.csd.capacity, 0); SdEnvironment.String(" B"); SdEnvironment.Ln;
			SdEnvironment.String("[SD] Bus frequency: "); SdEnvironment.Int(card.csd.txSpeed, 0); SdEnvironment.String(" Hz"); SdEnvironment.Ln
		END;
		SetBusClock(hc, card.csd.txSpeed);


		IF ~ReadScr(card, result) THEN RETURN FALSE END;

		IF CardScr_SdBusWidths_4 IN card.scr.busWidth THEN
			IF Trace THEN
				SdEnvironment.String("[SD] Changing bus width to 4 bits");
				SdEnvironment.Ln
			END;
			IF ~SetBusWidth(card.hc, card.rca, 4, result) THEN RETURN FALSE END;
			IF Trace THEN
				SdEnvironment.String("[SD] Bus width changed");
				SdEnvironment.Ln
			END
		END;

		IF (card.scr.version >= Version1p1) & SelectSpeedMode(card, TRUE, result) THEN
			(*! Assume card supports 50 MHz clock rate *)
			SetBusClock(hc, 50000000)
		END;
		(*FOR i := 0 TO 10000000H DO END;*)

		(*IF ~Reset(card.hc, TRUE, FALSE) THEN RETURN FALSE END;*)

		(*TRACE('RESET done');*)
		(*FOR i := 0 TO 10000000H DO END;*)

		(* Get Additional card registers: CSD *)
		(*command.command := CMD_SEND_CSD;
		command.argument := LSH(card.rca, 16);
		command.responseType := ResponseR2;
		command.flags := {};
		IF ~ExecuteCommand(command, result) THEN RETURN FALSE END;
		TRACE('command succeeded');
		GetR2(command, csd);
		GetCsd(csd, card.csd);
		IF Trace THEN
			SdEnvironment.String("[SD] Card Capacity: "); SdEnvironment.Int(card.csd.capacity, 0); SdEnvironment.String(" B"); SdEnvironment.Ln;
			SdEnvironment.String("[SD] Bus frequency: "); SdEnvironment.Int(card.csd.txSpeed, 0); SdEnvironment.String(" Hz"); SdEnvironment.Ln
		END;
		TRACE(card.csd.txSpeed);
		SetBusClock(hc, card.csd.txSpeed);*)

		RETURN TRUE
	END InitCard;

	PROCEDURE ReadScr (card: Card; VAR result: SIGNED32): BOOLEAN;
	VAR
		command: Command;
		scr: ARRAY 8 OF CHAR;
	BEGIN
		IF ~SelectCard(card, result) THEN RETURN FALSE END;

		(* Get Card Register: SCR *)
		command.hc := card.hc;
		command.command := ACMD_SEND_SCR;
		command.argument := 0;
		command.responseType := ResponseR1;
		command.flags := {FlagApplicationCmd, FlagData, FlagRead};
		command.rca := card.rca;
		IF ~card.hc.execute(command, scr, 0, 8, result) THEN RETURN FALSE END;
		IF CardStatus_Error IN GetR1(command) THEN result := ErrorCard; RETURN FALSE END;
		GetScr(scr, card.scr);
		RETURN TRUE
	END ReadScr;

	PROCEDURE SwitchFunc (card: Card; switch: BOOLEAN; funcs: ARRAY 6 OF SIGNED32; VAR sts: SwitchFuncStatus; VAR res: SIGNED32): BOOLEAN;
	VAR
		status: ARRAY 64 OF CHAR;
		command: Command;

		PROCEDURE GetStatus (CONST status: ARRAY OF CHAR; VAR sts: SwitchFuncStatus);
		VAR
			i: SIGNED32;
		BEGIN
			sts.current := SIGNED32(ORD(status[0])) * 100H + SIGNED32(ORD(status[1]));
			FOR i := 0 TO 5 DO
				sts.functionGroups[i] := SYSTEM.VAL(SET, SIGNED32(ORD(status[2 + 2 * (5 - i)])) * 100H + SIGNED32(ORD(status[1 + 2 + 2 * (5 - i)])))
			END;
			FOR i := 0 TO 5 BY 2 DO
				sts.functionStatus[i] := ORD(status[14 + 2 - i DIV 2]) MOD 10H;
				sts.functionStatus[i + 1] := ORD(status[14 + 2 - i DIV 2]) DIV 10H
			END;
		END GetStatus;

	BEGIN
		IF ~SelectCard(card, res) THEN RETURN FALSE END;
		command.hc := card.hc;
		command.command := CMD_SWITCH_FUNC;
		command.responseType := ResponseR1;
		command.argument := (funcs[0] MOD 10H) + 10H * (funcs[1] MOD 10H) + 100H * (funcs[2] MOD 10H) + 1000H * (funcs[3] MOD 10H) + 10000H * (funcs[4] MOD 10H) + 100000H * (funcs[5] MOD 10H);
		IF switch THEN INCL(SYSTEM.VAL(SET, command.argument), 31) END;
		command.flags := {FlagRead, FlagData};
		IF ~card.hc.execute(command, status, 0, 64, res) THEN RETURN FALSE END;
		GetStatus(status, sts);
		RETURN TRUE
	END SwitchFunc;

	PROCEDURE PrintSwitchFuncStatus(CONST status: SwitchFuncStatus);
	VAR
		i: SIGNED32;
	BEGIN
		IF Trace THEN
			SdEnvironment.String("Switch Func Status");
			SdEnvironment.Ln;
			SdEnvironment.String("Current = ");
			IF status.current = 0 THEN
				SdEnvironment.String("ERROR")
			ELSE
				SdEnvironment.Int(status.current, 0);
				SdEnvironment.String(" mA");
				SdEnvironment.Ln
			END;
			FOR i := 0 TO 5 DO
				SdEnvironment.String("Function Group #");
				SdEnvironment.Int(i, 0);
				SdEnvironment.String(": functions = ");
				SdEnvironment.Set(status.functionGroups[i]);
				SdEnvironment.String(", status = ");
				CASE status.functionStatus[i] OF
					 0: SdEnvironment.String("switchable")
					|1: SdEnvironment.String("switched")
					|0FH: SdEnvironment.String("ERROR")
				END;
				SdEnvironment.Ln
			END
		END
	END PrintSwitchFuncStatus;

	PROCEDURE SelectSpeedMode(card: Card; high: BOOLEAN; VAR res: SIGNED32): BOOLEAN;
	VAR
		funcs: ARRAY 6 OF SIGNED32;
		status: SwitchFuncStatus;
	BEGIN
		funcs[0] := 1;
		IF ~SwitchFunc(card, FALSE, funcs, status, res) THEN RETURN FALSE END;
		PrintSwitchFuncStatus(status);
		IF ~(1 IN status.functionGroups[0]) THEN
			SdEnvironment.String("[SD] HIGH-SPEED MODE NOT SUPPORTED");
			SdEnvironment.Ln;
			RETURN TRUE
		END;
		IF ~SwitchFunc(card, TRUE, funcs, status, res) THEN RETURN FALSE END;
		PrintSwitchFuncStatus(status);
		RETURN TRUE
	END SelectSpeedMode;

	(** Sends CMD7 if necessary to select the given card *)
	PROCEDURE SelectCard (card: Card; VAR result: SIGNED32): BOOLEAN;
	VAR
		command: Command;
		status: SET;
	BEGIN
		IF card.hc.lastRca = card.rca THEN
			IF Trace THEN
				SdEnvironment.String("[SD] Card Already Selected");
				SdEnvironment.Ln
			END;
			RETURN TRUE
		END;

		IF Trace THEN SdEnvironment.String("[SD] Selecting Card "); SdEnvironment.Int(card.rca, 0); SdEnvironment.Ln END;
		command.hc := card.hc;
		command.command := CMD_SELECT_DESELECT_CARD;
		command.argument := LSH(card.rca, 16);
		command.responseType := ResponseR1b;
		IF ~ExecuteCommand(command, result) THEN RETURN FALSE END;
		status := GetR1(command);
		IF CardStatus_Error IN status THEN result := ErrorCard; RETURN FALSE END;
		RETURN TRUE
	END SelectCard;

	(** Get the response registers in 'response' *)
	PROCEDURE GetResponse (hc: HostController; responseType: SIGNED32; VAR response: ARRAY 4 OF SIGNED32);
	BEGIN
		response := hc.regs.Response
	END GetResponse;

	(** Issue an SD Card Transaction. [Simplified specs. 3.7.1.1 pp. 106-108] *)
	PROCEDURE StartCommand (hc: HostController; cmd, argument, responseType: SIGNED32; read, dma, busy, abort: BOOLEAN; VAR status: SET; VAR result: SIGNED32): BOOLEAN;
	VAR
		reg: SIGNED32;
		flags, txFlags: SET;
	BEGIN
		IF TraceCmd THEN
			SdEnvironment.String("[SD] Sending Command CMD"); SdEnvironment.Int(cmd, 0); SdEnvironment.Ln;
			SdEnvironment.String("[SD]	Argument: "); SdEnvironment.Hex(argument, -8); SdEnvironment.Ln
		END;

		(* 1 *)
		WHILE PresentState_CommandInhibitCmd IN hc.regs.PresentState DO END;

		(* 2 *)
		IF busy THEN
			(* 3 *)
			IF ~abort THEN
				(* 4 *)
				WHILE PresentState_CommandInhibitDat IN hc.regs.PresentState DO END
			END
		END;

		(* 5 *)
		hc.regs.Argument1 := argument;

		(* 6 *)
		(* The response type determines the response-type and CRC/Index checks enabling *)
		CASE responseType OF
			 ResponseNone:
			 	reg := Command_ResponseType_None;
			 	IF TraceCmd THEN
			 		SdEnvironment.String("[SD]	No Response Expected");
				 	SdEnvironment.Ln
				 END
			|ResponseR1, ResponseR5, ResponseR6, ResponseR7:
				reg := Command_ResponseType_48b;
				flags := {Command_CrcCheckEnable, Command_IndexCheckEnable};
				IF TraceCmd THEN
					SdEnvironment.String("[SD]	48 Bit Response"); SdEnvironment.Ln;
					SdEnvironment.String("[SD]	Enabling CRC Check and Index Check"); SdEnvironment.Ln
				END
			|ResponseR3, ResponseR4:
				reg := Command_ResponseType_48b;
				IF TraceCmd THEN SdEnvironment.String("[SD]	48 Bit Response"); SdEnvironment.Ln END
			|ResponseR1b, ResponseR5b:
				reg := Command_ResponseType_48bBusy;
				flags := {Command_CrcCheckEnable, Command_IndexCheckEnable};
				IF TraceCmd THEN
					SdEnvironment.String("[SD]	48 Bit Response"); SdEnvironment.Ln;
					SdEnvironment.String("[SD]	Enabling Index Check"); SdEnvironment.Ln
				END
			|ResponseR2:
				reg := Command_ResponseType_136b;
				flags := {Command_CrcCheckEnable};
				IF TraceCmd THEN
					SdEnvironment.String("[SD]	136 Bit Response"); SdEnvironment.Ln;
					SdEnvironment.String("[SD]	Enabling Command CRC Check"); SdEnvironment.Ln
				END
		END;

		(* Command determines data-enable *)
		IF busy THEN
			INCL(flags, Command_DataPresent);
			IF TraceCmd THEN SdEnvironment.String("[SD]	Using DAT Line"); SdEnvironment.Ln END;

			txFlags := {};
			IF (*(cmd = CMD_READ_SINGLE_BLOCK) OR (cmd = CMD_READ_MULTIPLE_BLOCK) OR (cmd = ACMD_SEND_SCR)*) read THEN
				IF TraceCmd THEN SdEnvironment.String("[SD] 	Data Read"); SdEnvironment.Ln END;
				INCL(txFlags, TransferMode_DataTxDirection)
			ELSIF TraceCmd THEN
				SdEnvironment.String("[SD] 	Data Write");
				SdEnvironment.Ln
			END;
			IF (cmd = CMD_READ_MULTIPLE_BLOCK) OR (cmd = CMD_WRITE_MULTIPLE_BLOCK) THEN
				IF TraceCmd THEN SdEnvironment.String("[SD] 	Multiple blocks: using Auto CMD12 & activating block count"); SdEnvironment.Ln END;
				txFlags := txFlags + TransferMode_AutoCmd_Cmd12 + {TransferMode_MultipleBlocks, TransferMode_BlockCountEnable}
			ELSIF TraceCmd THEN
				SdEnvironment.String("[SD] 	Single Block");
				SdEnvironment.Ln
			END;
			IF dma THEN INCL(txFlags, TransferMode_DmaEnable) END;
			hc.regs.TransferMode := SYSTEM.VAL(SIGNED16, txFlags)
		END;
		hc.regs.Command := SYSTEM.VAL(SIGNED16, SYSTEM.VAL(SET, reg + LSH(cmd, Command_CommandIndexOffset)) + flags);

		(* 7 *)
		RETURN WaitForCompletion(hc, ~abort, status, result)
		(* Steps 7, 8 and 9 of WaitForCompletion have to be done by caller *)
	END StartCommand;

	PROCEDURE ErrorRecovery (hc: HostController; VAR result: SIGNED32; VAR status: SET): BOOLEAN;
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
	PROCEDURE WaitForCompletion (hc: HostController; tryRecover: BOOLEAN; 	VAR status: SET; VAR result: SIGNED32): BOOLEAN;
	BEGIN
		result := ErrorNone;
		(* 1 *)
		REPEAT
			status := hc.regs.InterruptStatus;
		UNTIL (Interrupt_Normal_CommandComplete IN status)
						OR (Interrupt_Normal_ErrorInterrupt IN status);

		IF Interrupt_Normal_ErrorInterrupt IN status THEN
			IF ~tryRecover THEN
				hc.regs.InterruptStatus := status;
				result := ErrorUnrecoverable;
				RETURN FALSE
			END;
			IF ~ErrorRecovery(hc, result, status) THEN RETURN FALSE END;
			IF Interrupt_Error_CommandTimeout IN status THEN
				IF TraceCmd THEN SdEnvironment.String("[SD] 	Timeout in command"); SdEnvironment.Ln END;
				result := ErrorCmdTimeout;
				RETURN FALSE
			ELSIF Interrupt_Error_CommandCrc IN status THEN
				result := ErrorCmdCrc;
				RETURN FALSE
			ELSE
				result := ErrorCard;
				RETURN FALSE
			END
		END;

		(* 2 *)
		IF TraceCmd THEN SdEnvironment.String("[SD] 	Command successful"); SdEnvironment.Ln END;
		INCL(hc.regs.InterruptStatus, Interrupt_Normal_CommandComplete);
		RETURN TRUE
	END WaitForCompletion;

	PROCEDURE WaitForTransfer (hc: HostController; VAR result: SIGNED32): BOOLEAN;
	VAR
		status: SET;
	BEGIN
		(* 5 *)
		REPEAT UNTIL (Interrupt_Normal_TransferComplete IN hc.regs.InterruptStatus) OR (Interrupt_Normal_ErrorInterrupt IN hc.regs.InterruptStatus);

		IF Interrupt_Normal_ErrorInterrupt IN hc.regs.InterruptStatus THEN
			IF ~ErrorRecovery(hc, result, status) THEN RETURN FALSE END;
			result := ErrorCard;
			RETURN FALSE
		END;

		(* 6 *)
		INCL(hc.regs.InterruptStatus, Interrupt_Normal_TransferComplete)
	END WaitForTransfer;

	(** Fills a Csd record from the raw csd bytes *)
	PROCEDURE GetCsd (CONST raw: ARRAY OF SIGNED32; VAR csd: Csd);
	VAR
		sizeMult, val, version: SIGNED32;
		real: FLOAT32;
	BEGIN
		version := ReadBitfield(raw, CardCsd_CsdStructureOfs, CardCsd_CsdStructureWidth) + 1;
		
		IF version = 1 THEN
			sizeMult := LSH(SIGNED32(2), ReadBitfield(raw, CardCsd_CSizeMultOfs1, CardCsd_CSizeMultWidth1));
			csd.capacity := sizeMult * (1 + ReadBitfield(raw, CardCsd_CSizeOfs1, CardCsd_CSizeWidth1)) * 512;
		ELSE
			csd.capacity := 1024 * (SIGNED64(ReadBitfield(raw, CardCsd_CSizeOfs2, CardCsd_CSizeWidth2)) + 1);
		END;

		csd.commandClasses := SYSTEM.VAL(SET, ReadBitfield(raw, CardCsd_CccOfs, CardCsd_CccWidth));
		csd.nsac := ReadBitfield(raw, CardCsd_NsacOfs, CardCsd_NsacWidth) * 100;

		val := ReadBitfield(raw, CardCsd_R2wFactorOfs, CardCsd_R2wFactorWidth);
		IF val >= 6 THEN
			csd.r2w := 0
		ELSE
			csd.r2w := LSH(SIGNED32(1), val);
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
		csd.taac := real
	END GetCsd;

	PROCEDURE GetScr (CONST raw: ARRAY OF CHAR; VAR scr: Scr);
	TYPE
		Array = ARRAY 8 OF CHAR;
	VAR
		bfield: ARRAY 2 OF SIGNED32;
		i: SIGNED32;
	BEGIN
		FOR i := 0 TO 7 DO SYSTEM.VAL(Array, bfield)[7-i] := raw[i] END;
		IF ReadBitfield(bfield, CardScr_StructureOfs, CardScr_StructureWidth) # 0 THEN RETURN END;
		scr.version := ReadBitfield(bfield, CardScr_SdSpecVersionOfs, CardScr_SdSpecVersionWidth);
		IF (scr.version = Version2) & (ReadBitfield(bfield, CardScr_SpecV3, 1) # 0) THEN
			scr.version := Version3
		END;

		CASE ReadBitfield(bfield, CardScr_SecurityOfs, CardScr_SecurityWidth) OF
			 0: scr.security := TypeNone
			|2: scr.security := TypeSDSC
			|3: scr.security := TypeSDHC
			|4: scr.security := TypeSDXC
		END;

		scr.busWidth := SYSTEM.VAL(SET, ReadBitfield(bfield, CardScr_SdBusWidthsOfs, CardScr_SdBusWidthsWidth))
	END GetScr;

	PROCEDURE PrintCapabilities * (hc: HostController);
	VAR
		c0, c1: SET;
	BEGIN
		IF Trace THEN
			c0 := hc.regs.Capabilities[0];
			c1 := hc.regs.Capabilities[1];
			SdEnvironment.String("[SD] "); SdEnvironment.String("Host Capabilities:"); SdEnvironment.Ln;
			SdEnvironment.String("[SD] "); SdEnvironment.String("	Timeout Clock Frequency: ");
			IF c0 * Capabilities_TimeoutClockFrequencyMask = {} THEN
				SdEnvironment.String("Unknown")
			ELSE
				SdEnvironment.Int(SYSTEM.VAL(SIGNED32, c0 * Capabilities_TimeoutClockFrequencyMask), 0);
				IF Capabilities_TimeoutClockUnit IN c0 THEN
					SdEnvironment.String(" MHz")
				ELSE
					SdEnvironment.String(" kHz")
				END
			END;
			SdEnvironment.Ln;

			SdEnvironment.String("[SD] "); SdEnvironment.String("	Base Clock Frequency: ");
			IF c0 * Capabilities_BaseClockFreqSdMask = {} THEN
				SdEnvironment.String("Unknown")
			ELSE
				SdEnvironment.Int(LSH(SYSTEM.VAL(SIGNED32, c0 * Capabilities_BaseClockFreqSdMask), -Capabilities_BaseClockFreqSdOfs), 0)
			END;
			SdEnvironment.Ln;

			SdEnvironment.String("[SD] "); SdEnvironment.String("	Max Block Length: ");
			SdEnvironment.Int(512 * (1 + LSH(SYSTEM.VAL(SIGNED32, c0 * Capabilities_MaxBlockLenMask), -Capabilities_MaxBlockLenOfs)), 0);
			SdEnvironment.String(" B");
			SdEnvironment.Ln;

			SdEnvironment.String("[SD] "); SdEnvironment.String("	8 Bit Support for Embedded Device: ");
			SdEnvironment.Boolean(Capabilities_8BitEmbedded IN c0);
			SdEnvironment.Ln;

			SdEnvironment.String("[SD] "); SdEnvironment.String("	Support for ADMA2: ");
			SdEnvironment.Boolean(Capabilities_ADMA2 IN c0);
			SdEnvironment.Ln;

			SdEnvironment.String("[SD] "); SdEnvironment.String("	Support for High Speed: ");
			SdEnvironment.Boolean(Capabilities_HighSpeed IN c0);
			SdEnvironment.Ln;

			SdEnvironment.String("[SD] "); SdEnvironment.String("	Support for SDMA: ");
			SdEnvironment.Boolean(Capabilities_SDMA IN c0);
			SdEnvironment.Ln;

			SdEnvironment.String("[SD] "); SdEnvironment.String("	Support for Suspend/Resume: ");
			SdEnvironment.Boolean(Capabilities_SuspendResume IN c0);
			SdEnvironment.Ln;

			SdEnvironment.String("[SD] "); SdEnvironment.String("	Voltage Support for 3.3 V: ");
			SdEnvironment.Boolean(Capabilities_Voltage33 IN c0);
			SdEnvironment.Ln;

			SdEnvironment.String("[SD] "); SdEnvironment.String("	Voltage Support for 3.0 V: ");
			SdEnvironment.Boolean(Capabilities_Voltage30 IN c0);
			SdEnvironment.Ln;

			SdEnvironment.String("[SD] "); SdEnvironment.String("	Voltage Support for 1.8 V: ");
			SdEnvironment.Boolean(Capabilities_Voltage18 IN c0);
			SdEnvironment.Ln;

			SdEnvironment.String("[SD] "); SdEnvironment.String("	Support for 64 Bit Bus: ");
			SdEnvironment.Boolean(Capabilities_64BitBus IN c0);
			SdEnvironment.Ln;

			SdEnvironment.String("[SD] "); SdEnvironment.String("	Support for Asynchronous Interrupts: ");
			SdEnvironment.Boolean(Capabilities_AsyncInterrupt IN c0);
			SdEnvironment.Ln;

			SdEnvironment.String("[SD] "); SdEnvironment.String("	Slot Type: ");
			IF c0 * Capabilities_SlotTypeMask = Capabilities_SlotType_Removable THEN
				SdEnvironment.String("Removable Card Slot")
			ELSIF c0 * Capabilities_SlotTypeMask = Capabilities_SlotType_Embedded THEN
				SdEnvironment.String("Embedded Slot for One Device")
			ELSIF c0 * Capabilities_SlotTypeMask = Capabilities_SlotType_SharedBus THEN
				SdEnvironment.String("Shared Bus Slot")
			END;
			SdEnvironment.Ln;

			IF hc.version = 3 THEN
				SdEnvironment.String("[SD] "); SdEnvironment.String("	Support for SDR50: ");
				SdEnvironment.Boolean(Capabilities_SDR50 IN c1);
				SdEnvironment.Ln;

				SdEnvironment.String("[SD] "); SdEnvironment.String("	Support for SDR104: ");
				SdEnvironment.Boolean(Capabilities_SDR104 IN c1);
				SdEnvironment.Ln;

				SdEnvironment.String("[SD] "); SdEnvironment.String("	Support for DDR50: ");
				SdEnvironment.Boolean(Capabilities_DDR50 IN c1);
				SdEnvironment.Ln;

				SdEnvironment.String("[SD] "); SdEnvironment.String("	Support for Driver Type A: ");
				SdEnvironment.Boolean(Capabilities_DriverTypeA IN c1);
				SdEnvironment.Ln;

				SdEnvironment.String("[SD] "); SdEnvironment.String("	Support for Driver Type C: ");
				SdEnvironment.Boolean(Capabilities_DriverTypeC IN c1);
				SdEnvironment.Ln;

				SdEnvironment.String("[SD] "); SdEnvironment.String("	Support for Driver Type D: ");
				SdEnvironment.Boolean(Capabilities_DriverTypeD IN c1);
				SdEnvironment.Ln;

				SdEnvironment.String("[SD] "); SdEnvironment.String("	Timer Count for Retuning: ");
				IF c1 * Capabilities_TimerCountRetuningMask = Capabilities_TimerCountRetuningMask THEN
					SdEnvironment.String("Unknown")
				ELSIF c1 * Capabilities_TimerCountRetuningMask = {} THEN
					SdEnvironment.String("Disabled")
				ELSE
					SdEnvironment.Int(LSH(SIGNED32(1), LSH(SYSTEM.VAL(SIGNED32, c1 * Capabilities_TimerCountRetuningMask), -Capabilities_TimerCountRetuningOfs)), 0);
					SdEnvironment.String(" s")
				END;
				SdEnvironment.Ln;

				SdEnvironment.String("[SD] "); SdEnvironment.String("	SDR50 Requires Retuning: ");
				SdEnvironment.Boolean(Capabilities_TuningSDR50 IN c1);
				SdEnvironment.Ln;

				SdEnvironment.String("[SD] "); SdEnvironment.String("	Retuning Mode: ");
				SdEnvironment.Int(LSH(SYSTEM.VAL(SIGNED32, c1 * Capabilities_RetuningModesMask), -Capabilities_RetuningModesOfs), 0);
				SdEnvironment.Ln;

				SdEnvironment.String("[SD] "); SdEnvironment.String("	Clock Multiplier: ");
				IF c1 * Capabilities_ClockMultiplierMask = {} THEN
					SdEnvironment.String("Not Supported")
				ELSE
					SdEnvironment.Int(LSH(SYSTEM.VAL(SIGNED32, c1 * Capabilities_ClockMultiplierMask), -Capabilities_ClockMultiplierOfs) + 1, 0)
				END;
				SdEnvironment.Ln
			END
		END
	END PrintCapabilities;

	PROCEDURE PrintCardStatus * (status: SET);
	BEGIN
		IF TRUE OR Trace THEN
			SdEnvironment.String("[SD] Card Status:"); SdEnvironment.Ln;
			SdEnvironment.String("[SD]	AKE Error: "); SdEnvironment.Boolean(CardStatus_AkeSpecError IN status); SdEnvironment.Ln;
			SdEnvironment.String("[SD]	App Command: "); SdEnvironment.Boolean(CardStatus_AppCmd IN status); SdEnvironment.Ln;
			SdEnvironment.String("[SD]	Ready For Data: "); SdEnvironment.Boolean(CardStatus_ReadyForData IN status); SdEnvironment.Ln;
			SdEnvironment.String("[SD]	Card State: ");
			CASE LSH(SYSTEM.VAL(SIGNED32, status * CardStatus_CurrentStateMask), -CardStatus_CurrentStateOffset) OF
				 CardIdle: SdEnvironment.String("Idle")
				|CardReady: SdEnvironment.String("Ready")
				|CardIdentification: SdEnvironment.String("Identification")
				|CardStandby: SdEnvironment.String("Standby")
				|CardTransfer: SdEnvironment.String("Transfer")
				|CardData: SdEnvironment.String("Sending Data")
				|CardReceive: SdEnvironment.String("Receiving Data")
				|CardProgram: SdEnvironment.String("Programming")
				|CardDisabled: SdEnvironment.String("Disabled")
			END;
			SdEnvironment.Ln;
			SdEnvironment.String("[SD]	Erase Reset: "); SdEnvironment.Boolean(CardStatus_EraseReset IN status); SdEnvironment.Ln;
			SdEnvironment.String("[SD]	Internal ECC Enable: "); SdEnvironment.Boolean(CardStatus_CardEccDisable IN status); SdEnvironment.Ln;
			SdEnvironment.String("[SD]	Write_Protection Erase Skip: "); SdEnvironment.Boolean(CardStatus_WpEraseSkip IN status); SdEnvironment.Ln;
			SdEnvironment.String("[SD]	CSD Overwrite: "); SdEnvironment.Boolean(CardStatus_CsdOverwrite IN status); SdEnvironment.Ln;
			SdEnvironment.String("[SD]	Error: "); SdEnvironment.Boolean(CardStatus_Error IN status); SdEnvironment.Ln;
			SdEnvironment.String("[SD]	Card Controller Error: "); SdEnvironment.Boolean(CardStatus_CcError IN status); SdEnvironment.Ln;
			SdEnvironment.String("[SD]	Card ECC Failed: "); SdEnvironment.Boolean(CardStatus_CardEccFailed IN status); SdEnvironment.Ln;
			SdEnvironment.String("[SD]	Illegal Command: "); SdEnvironment.Boolean(CardStatus_IllegalCommand IN status); SdEnvironment.Ln;
			SdEnvironment.String("[SD]	Command CRC Error: "); SdEnvironment.Boolean(CardStatus_ComCrcError IN status); SdEnvironment.Ln;
			SdEnvironment.String("[SD]	Lock/Unlock Failed: "); SdEnvironment.Boolean(CardStatus_LockUnlockFailed IN status); SdEnvironment.Ln;
			SdEnvironment.String("[SD]	Card is Locked: "); SdEnvironment.Boolean(CardStatus_CardIsLocked IN status); SdEnvironment.Ln;
			SdEnvironment.String("[SD]	Write-Protection Violation: "); SdEnvironment.Boolean(CardStatus_WpViolation IN status); SdEnvironment.Ln;
			SdEnvironment.String("[SD]	Invalid Erase Parameters: "); SdEnvironment.Boolean(CardStatus_EraseParam IN status); SdEnvironment.Ln;
			SdEnvironment.String("[SD]	Erase Sequence Error: "); SdEnvironment.Boolean(CardStatus_EraseSeqError IN status); SdEnvironment.Ln;
			SdEnvironment.String("[SD]	Block Length Error: "); SdEnvironment.Boolean(CardStatus_BlockLenError IN status); SdEnvironment.Ln;
			SdEnvironment.String("[SD]	Address Error: "); SdEnvironment.Boolean(CardStatus_AddressError IN status); SdEnvironment.Ln;
			SdEnvironment.String("[SD]	Argument Out of Range: "); SdEnvironment.Boolean(CardStatus_OutOfRange IN status); SdEnvironment.Ln
		END
	END PrintCardStatus;

	PROCEDURE PrintCardCsd * (CONST csd: ARRAY OF SIGNED32);
	VAR
		cap: SIGNED64;
		val, version, sizeMult: SIGNED32;
	BEGIN
		IF Trace THEN
			version := ReadBitfield(csd, CardCsd_CsdStructureOfs, CardCsd_CsdStructureWidth) + 1;
			SdEnvironment.String("[SD] "); SdEnvironment.String("Card CSD:"); SdEnvironment.Ln;
			SdEnvironment.String("[SD] "); SdEnvironment.String("	Version: "); SdEnvironment.Int(version, 0); SdEnvironment.Ln;

			(* Common Fields *)
			SdEnvironment.String("[SD] "); SdEnvironment.String("	File Format: ");
			val := ReadBitfield(csd, CardCsd_FileFormatOfs, CardCsd_FileFormatWidth);
			IF ReadBitfield(csd, CardCsd_FileFormatGrp, 1) = 1 THEN
				SdEnvironment.String("Unknown Value (");
				SdEnvironment.Int(val, 0);
				SdEnvironment.String(")")
			ELSIF val = 0 THEN
				SdEnvironment.String("Hard-disk file system with partition table")
			ELSIF val = 1 THEN
				SdEnvironment.String("FAT")
			ELSIF val = 2 THEN
				SdEnvironment.String("Universal File Format")
			ELSE
				SdEnvironment.String("Other")
			END;
			SdEnvironment.Ln;

			SdEnvironment.String("[SD] "); SdEnvironment.String("	Temporary Write Protection: "); SdEnvironment.Boolean(ReadBitfield(csd, CardCsd_TmpWriteProtect, 1) = 1); SdEnvironment.Ln;
			SdEnvironment.String("[SD] "); SdEnvironment.String("	Permanent Write Protection: "); SdEnvironment.Boolean(ReadBitfield(csd, CardCsd_PermWriteProtect, 1) = 1); SdEnvironment.Ln;
			SdEnvironment.String("[SD] "); SdEnvironment.String("	Copy: "); SdEnvironment.Boolean(ReadBitfield(csd, CardCsd_Copy, 1) = 1); SdEnvironment.Ln;
			SdEnvironment.String("[SD] "); SdEnvironment.String("	Partial Block Write: "); SdEnvironment.Boolean(ReadBitfield(csd, CardCsd_WriteBlPartial, 1) = 1); SdEnvironment.Ln;
			SdEnvironment.String("[SD] "); SdEnvironment.String("	Maximum Write Block Length: ");
			val := ReadBitfield(csd, CardCsd_WriteBlLenOfs, CardCsd_WriteBlLenWidth);
			IF (val <= 8) OR (val >= 12) THEN
				SdEnvironment.String("Unknown Value (");
				SdEnvironment.Int(val, 0);
				SdEnvironment.String(")")
			ELSE
				SdEnvironment.Int(LSH(SIGNED32(1), val), 0);
			END;
			SdEnvironment.Ln;
			SdEnvironment.String("[SD] "); SdEnvironment.String("	Block Program Time / Block Read Time: ");
			val := ReadBitfield(csd, CardCsd_R2wFactorOfs, CardCsd_R2wFactorWidth);
			IF val >= 6 THEN
				SdEnvironment.String("Unknown Value (");
				SdEnvironment.Int(val, 0);
				SdEnvironment.String(")")
			ELSE
				SdEnvironment.Int(LSH(SIGNED32(1), val), 0);
			END;
			SdEnvironment.Ln;
			SdEnvironment.String("[SD] "); SdEnvironment.String("	Group Write Protection: "); SdEnvironment.Boolean(ReadBitfield(csd, CardCsd_WpGrpEnable, 1) = 1); SdEnvironment.Ln;
			SdEnvironment.String("[SD] "); SdEnvironment.String("	WpGrpSize: "); SdEnvironment.Int(ReadBitfield(csd, CardCsd_WpGrpSizeOfs, CardCsd_WpGrpSizeWidth) + 1, 0); SdEnvironment.String(" sectors"); SdEnvironment.Ln;
			SdEnvironment.String("[SD] "); SdEnvironment.String("	Sector Size: "); SdEnvironment.Int(ReadBitfield(csd, CardCsd_SectorSizeOfs, CardCsd_SectorSizeWidth) + 1, 0); SdEnvironment.Ln;
			SdEnvironment.String("[SD] "); SdEnvironment.String("	Erase Block Enable: "); SdEnvironment.Boolean(ReadBitfield(csd, CardCsd_EraseBlkEn, 1) = 1); SdEnvironment.Ln;

			IF version = 1 THEN
				sizeMult := LSH(SIGNED32(2), ReadBitfield(csd, CardCsd_CSizeMultOfs1, CardCsd_CSizeMultWidth1));
				cap := sizeMult * (1 + ReadBitfield(csd, CardCsd_CSizeOfs1, CardCsd_CSizeWidth1)) * 512;
			ELSE
				cap := 1024 * (SIGNED64(ReadBitfield(csd, CardCsd_CSizeOfs2, CardCsd_CSizeWidth2)) + 1);
			END;
			SdEnvironment.String("[SD] "); SdEnvironment.String("	Card Capacity: "); SdEnvironment.Int(cap, 0); SdEnvironment.String(" B"); SdEnvironment.Ln;
			SdEnvironment.String("[SD] "); SdEnvironment.String("	DSR Implemented: "); SdEnvironment.Boolean(ReadBitfield(csd, CardCsd_DsrImp, 1) = 1); SdEnvironment.Ln;
			SdEnvironment.String("[SD] "); SdEnvironment.String("	Misaligned Block Read: "); SdEnvironment.Boolean(ReadBitfield(csd, CardCsd_ReadBlkMisalign, 1) = 1); SdEnvironment.Ln;
			SdEnvironment.String("[SD] "); SdEnvironment.String("	Misaligned Block Write: "); SdEnvironment.Boolean(ReadBitfield(csd, CardCsd_WriteBlkMisalign, 1) = 1); SdEnvironment.Ln;
			SdEnvironment.String("[SD] "); SdEnvironment.String("	Partial Block Read: "); SdEnvironment.Boolean(ReadBitfield(csd, CardCsd_ReadBlPartial, 1) = 1); SdEnvironment.Ln;
			(*ASSERT(ReadBitfield(csd, CardCsd_ReadBlPartial, 1) = 1);*)
			SdEnvironment.String("[SD] "); SdEnvironment.String("	Maximal Block Read Length: ");
			val := ReadBitfield(csd, CardCsd_ReadBlLenOfs, CardCsd_ReadBlLenWidth);
			IF (val <= 8) OR (val >= 12) THEN
				SdEnvironment.String("Unknown Value (");
				SdEnvironment.Int(val, 0);
				SdEnvironment.String(")")
			ELSE
				SdEnvironment.Int(LSH(SIGNED32(1), val), 0); SdEnvironment.String(" B")
			END;
			SdEnvironment.Ln;
			SdEnvironment.String("[SD] "); SdEnvironment.String("	Supported Command Classes: "); SdEnvironment.Set(SYSTEM.VAL(SET, ReadBitfield(csd, CardCsd_CccOfs, CardCsd_CccWidth))); SdEnvironment.Ln;
			SdEnvironment.String("[SD] "); SdEnvironment.String("	Transfer Speed: ");
			val := ReadBitfield(csd, CardCsd_TranSpeedOfs, CardCsd_TranSpeedWidth);
			CASE val DIV 8 OF
				 1: SdEnvironment.String("1.0")
				|2: SdEnvironment.String("1.2")
				|3: SdEnvironment.String("1.3")
				|4: SdEnvironment.String("1.5")
				|5: SdEnvironment.String("2.0")
				|6: SdEnvironment.String("2.0")
				|7: SdEnvironment.String("2.5")
				|8: SdEnvironment.String("3.5")
				|9: SdEnvironment.String("4.0")
				|10: SdEnvironment.String("4.5")
				|11: SdEnvironment.String("5.0")
				|12: SdEnvironment.String("5.5")
				|13: SdEnvironment.String("6.0")
				|14: SdEnvironment.String("7.0")
				|15: SdEnvironment.String("8.0")
			ELSE
				SdEnvironment.String("Unknown Value (");
				SdEnvironment.Int(val, 0);
				SdEnvironment.String(")")
			END;
			SdEnvironment.String(" * 1");
			CASE val MOD 8 OF
				 0: SdEnvironment.String("00 k")
				|1: SdEnvironment.String(" M")
				|2: SdEnvironment.String("0 M")
				|3: SdEnvironment.String("00 M")
			END;
			SdEnvironment.String("Bit/s");
			SdEnvironment.Ln;

			SdEnvironment.String("[SD] "); SdEnvironment.String("	Clock-Dependent Access Time: "); SdEnvironment.Int(ReadBitfield(csd, CardCsd_NsacOfs, CardCsd_NsacWidth) * 100, 0); SdEnvironment.String("000 clock cycles"); SdEnvironment.Ln;
			SdEnvironment.String("[SD] "); SdEnvironment.String("	Asynchronous Access Time: ");
			val := ReadBitfield(csd, CardCsd_TaacOfs, CardCsd_TaacWidth);
			CASE val DIV 8 OF
				 1: SdEnvironment.String("1.0")
				|2: SdEnvironment.String("1.2")
				|3: SdEnvironment.String("1.3")
				|4: SdEnvironment.String("1.5")
				|5: SdEnvironment.String("2.0")
				|6: SdEnvironment.String("2.5")
				|7: SdEnvironment.String("3.0")
				|8: SdEnvironment.String("3.5")
				|9: SdEnvironment.String("4.0")
				|10: SdEnvironment.String("4.5")
				|11: SdEnvironment.String("5.0")
				|12: SdEnvironment.String("5.5")
				|13: SdEnvironment.String("6.0")
				|14: SdEnvironment.String("7.0")
				|15: SdEnvironment.String("8.0")
			ELSE
				SdEnvironment.String("Unknown Value (");
				SdEnvironment.Int(val, 0);
				SdEnvironment.String(")")
			END;
			SdEnvironment.String(" * 1");
			CASE val MOD 8 OF
				 0: SdEnvironment.String(" ns")
				|1: SdEnvironment.String("0 ns")
				|2: SdEnvironment.String("00 ns")
				|3: SdEnvironment.String(" microsecond")
				|4: SdEnvironment.String("0 microsecond")
				|5: SdEnvironment.String("00 microsecond")
				|6: SdEnvironment.String(" ms")
				|7: SdEnvironment.String("0 ms")
			END;
			SdEnvironment.Ln;
		END
	END PrintCardCsd;

	PROCEDURE ReadBitfield (CONST field: ARRAY OF SIGNED32; ofs, width: SIGNED32): SIGNED32;
	VAR
		bits: ADDRESS;
	BEGIN
		ASSERT(ofs MOD 8 + width <= 32);
		bits := SYSTEM.GET8(ADDRESSOF(field[0]) + ofs DIV 8);
		IF ofs MOD 8 + width > 8 THEN
			bits := bits + SYSTEM.GET8(ADDRESSOF(field[0]) + ofs DIV 8 + 1) * 100H
		END;
		IF ofs MOD 8 + width > 16 THEN
			bits := bits + SYSTEM.GET8(ADDRESSOF(field[0]) + ofs DIV 8 + 2) * 10000H
		END;
		IF ofs MOD 8 + width > 24 THEN
			bits := bits + SYSTEM.GET8(ADDRESSOF(field[0]) + ofs DIV 8 + 3) * 1000000H
		END;
		RETURN SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, LSH(bits, -(ofs MOD 8))) * {0 .. width - 1})
	END ReadBitfield;
END Sd.
