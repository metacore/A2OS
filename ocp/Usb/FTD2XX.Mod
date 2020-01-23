MODULE FTD2XX; (** AUTHOR "fnecati"; PURPOSE "FTDI USB/Serial interface for WinAos/LinuxAos"; *)
IMPORT SYSTEM, HostLibs, Modules, KernelLog;

CONST
#IF UNIX THEN	
	libname="/usr/local/lib/libftd2xx.so";
#ELSIF WIN THEN 
	libname="ftd2xx.dll"
#END

VAR
	lib: HostLibs.LibHandle;
	
(*	 
	 Module Name: ftd2xx.h,  version 1.3.6
	 Abstract:Native USB device driver for FTDI FT232x, FT245x, FT2232x and FT4232x devices
	 FTD2XX library definitions
	 Environment: user mode
*)
	
CONST 
	MAX_NUM_DEVICES* = 50;

TYPE 
	DWORD* = UNSIGNED32; (* 4bytes *)
	ULONG* = UNSIGNED32; (* 4 bytes *)
	USHORT* = UNSIGNED16; (* 2 bytes *)

	UCHAR* = UNSIGNED8; (* unsigned *)
	PCHAR* = POINTER TO ARRAY OF CHAR;
	PVOID* = ADDRESS;
	HANDLE* = UNSIGNED32;

	INT* = SIGNED32;
	UINT* = UNSIGNED32; (* 4 bytes *)

	LPVOID* = PVOID;
	
	OVERLAPPED* = RECORD 
		Internal* : DWORD;
		InternalHigh* : DWORD;
		Offset* : DWORD;
		OffsetHigh* : DWORD;
		hEvent* : HANDLE;
	END;
	LPOVERLAPPED* = POINTER TO OVERLAPPED;

	(* Modem Status Flags *)
CONST
	MS_CTS_ON* = 00010H;
	MS_DSR_ON* = 00020H;
	MS_RING_ON* = 00040H;
	MS_RLSD_ON* = 00080H;
	
	(* Error Flags *)
	
	CE_RXOVER* = 00001H;  (* Receive Queue overflow *)
	CE_OVERRUN* = 00002H;  (* Receive Overrun Error *)
	CE_RXPARITY* = 00004H;  (* Receive Parity Error *)
	CE_FRAME* = 00008H;  (* Receive Framing error *)
	CE_BREAK* = 00010H;  (* Break Detected *)
	CE_TXFULL* = 00100H;  (* TX Queue is full *)
	CE_PTO* = 00200H;  (* LPTx Timeout *)
	CE_IOE* = 00400H;  (* LPTx I/O Error *)
	CE_DNS* = 00800H;  (* LPTx Device not selected *)
	CE_OOP* = 01000H;  (* LPTx Out-Of-Paper *)
	CE_MODE* = 08000H; (* Requested mode unsupported *)

	INVALID_HANDLE_VALUE* = 0FFFFFFFFH;

(*	TYPE _EVENT_HANDLE* = RECORD 
		eCondVar: pthread_cond_t;
		eMutex: pthread_mutex_t;
		iVar: SIGNED16;
	END;
	TYPE EVENT_HANDLE* = _EVENT_HANDLE;
*)
	
TYPE 
	STATUS* = ULONG;

	(* Device status *)
CONST 
	OK* = 0; 
	INVALID_HANDLE* = 1; 
	DEVICE_NOT_FOUND* = 2; 
	DEVICE_NOT_OPENED* = 3; 
	IO_ERROR* = 4; 
	INSUFFICIENT_RESOURCES* = 5; 
	INVALID_PARAMETER* = 6; 
	INVALID_BAUD_RATE* = 7; 	(* 7 *)
		
	DEVICE_NOT_OPENED_FOR_ERASE* = 8; 
	DEVICE_NOT_OPENED_FOR_WRITE* = 9; 
	FAILED_TO_WRITE_DEVICE* = 10; 
	EEPROM_READ_FAILED* = 11; 
	EEPROM_WRITE_FAILED* = 12; 
	EEPROM_ERASE_FAILED* = 13; 
	EEPROM_NOT_PRESENT* = 14; 
	EEPROM_NOT_PROGRAMMED* = 15; 
	INVALID_ARGS* = 16; 
	NOT_SUPPORTED* = 17; 
	OTHER_ERROR* = 18; 	
	
	(* OpenEx Flags *)
	OPEN_BY_SERIAL_NUMBER* = 1;
	OPEN_BY_DESCRIPTION* = 2;
	OPEN_BY_LOCATION* = 4;
	
	(* ListDevices Flags (used in conjunction with OpenEx Flags *)
	LIST_NUMBER_ONLY* = 080000000H;
	LIST_BY_INDEX* = 040000000H;
	LIST_ALL* = 020000000H;
	LIST_MASK* = LIST_NUMBER_ONLY + LIST_BY_INDEX + LIST_ALL;
	
	(* Baud Rates *)
	BAUD_300* = 300;
	BAUD_600* = 600;
	BAUD_1200* = 1200;
	BAUD_2400* = 2400;
	BAUD_4800* = 4800;
	BAUD_9600* = 9600;
	BAUD_14400* = 14400;
	BAUD_19200* = 19200;
	BAUD_38400* = 38400;
	BAUD_57600* = 57600;
	BAUD_115200* = 115200;
	BAUD_230400* = 230400;
	BAUD_460800* = 460800;
	BAUD_921600* = 921600;
	
	(* Word Lengths *)
	BITS_8* = 8;
	BITS_7* = 7;
	
	(* Stop Bits *)
	STOP_BITS_1* = 0;
	STOP_BITS_2* = 2;

	(* Parity *)	
	PARITY_NONE* = 0;
	PARITY_ODD* = 1;
	PARITY_EVEN* = 2;
	PARITY_MARK* = 3;
	PARITY_SPACE* = 4;

	(* Flow Control *)	
	FLOW_NONE* = 00000H;
	FLOW_RTS_CTS* = 00100H;
	FLOW_DTR_DSR* = 00200H;
	FLOW_XON_XOFF* = 00400H;

	(* Purge rx and tx buffers *)	
	PURGE_RX* = 1;
	PURGE_TX* = 2;

	(* Events *)
TYPE 
	PEVENT_HANDLER* = PROCEDURE {PlatformCC} (a: DWORD; b: DWORD);
CONST	
	EVENT_RXCHAR* = 1;
	EVENT_MODEM_STATUS* = 2;
	EVENT_LINE_STATUS* = 4;
	
	(* Timeouts *)
	DEFAULT_RX_TIMEOUT* = 300;
	DEFAULT_TX_TIMEOUT* = 300;
	
	(* Device types *)
TYPE DEVICE* = ULONG;
CONST	
	DEVICE_BM* = 0; 
	DEVICE_AM* = 1; 
	DEVICE_100AX* = 2; 
	DEVICE_UNKNOWN* = 3; 
	DEVICE_2232C* = 4; 
	DEVICE_232R* = 5; 
	DEVICE_2232H* = 6; 
	DEVICE_4232H* = 7; 
	DEVICE_232H* = 8; 
	DEVICE_X_SERIES* = 9;
	DEVICE_4222H_0* = 10;
	DEVICE_4222H_1_2* =11;
	DEVICE_4222H_3* = 12;
	DEVICE_4222_PROG* = 13;
		
	(* Bit Modes *)
	BITMODE_RESET* = 000H;
	BITMODE_ASYNC_BITBANG* = 001H;
	BITMODE_MPSSE* = 002H;
	BITMODE_SYNC_BITBANG* = 004H;
	BITMODE_MCU_HOST* = 008H;
	BITMODE_FAST_SERIAL* = 010H;
	BITMODE_CBUS_BITBANG* = 020H;
	BITMODE_SYNC_FIFO* = 040H;
	
	(* FT232R CBUS Options EEPROM values *)
	FT_232R_CBUS_TXDEN* = 000H;	(* Tx Data Enable *)
	FT_232R_CBUS_PWRON* = 001H;	(* Power On *)
	FT_232R_CBUS_RXLED* = 002H;	(* Rx LED *)
	FT_232R_CBUS_TXLED* = 003H;	(* Tx LED *)
	FT_232R_CBUS_TXRXLED* = 004H;	(* Tx and Rx LED *)
	FT_232R_CBUS_SLEEP* = 005H;	(* Sleep *)
	FT_232R_CBUS_CLK48* = 006H;	(* 48MHz clock *)
	FT_232R_CBUS_CLK24* = 007H;	(* 24MHz clock *)
	FT_232R_CBUS_CLK12* = 008H;	(* 12MHz clock *)
	FT_232R_CBUS_CLK6* = 009H;	(* 6MHz clock *)
	FT_232R_CBUS_IOMODE* = 00AH;	(* IO Mode for CBUS bit-bang *)
	FT_232R_CBUS_BITBANG_WR* = 00BH;	(* Bit-bang write strobe *)
	FT_232R_CBUS_BITBANG_RD* = 00CH;	(* Bit-bang read strobe *)
	
	(* FT232H CBUS Options EEPROM values *)
	FT_232H_CBUS_TRISTATE* = 000H;	(* Tristate *)
	FT_232H_CBUS_TXLED* = 001H;	(* Tx LED *)
	FT_232H_CBUS_RXLED* = 002H;	(* Rx LED *)
	FT_232H_CBUS_TXRXLED* = 003H;	(* Tx and Rx LED *)
	FT_232H_CBUS_PWREN* = 004H;	(* Power Enable *)
	FT_232H_CBUS_SLEEP* = 005H;	(* Sleep *)
	FT_232H_CBUS_DRIVE_0* = 006H;	(* Drive pin to logic 0 *)
	FT_232H_CBUS_DRIVE_1* = 007H;	(* Drive pin to logic 1 *)
	FT_232H_CBUS_IOMODE* = 008H;	(* IO Mode for CBUS bit-bang *)
	FT_232H_CBUS_TXDEN* = 009H;	(* Tx Data Enable *)
	FT_232H_CBUS_CLK30* = 00AH;	(* 30MHz clock *)
	FT_232H_CBUS_CLK15* = 00BH;	(* 15MHz clock *)
	FT_232H_CBUS_CLK7_5* = 00CH;	(* 7.5MHz clock *)
	

VAR
	Open- : PROCEDURE {PlatformCC} (deviceNumber: DWORD; VAR pHandle: HANDLE): STATUS;
	OpenEx- :	PROCEDURE {PlatformCC} (pArg1: ADDRESS; Flags: DWORD; VAR pHandle: HANDLE): STATUS;
	ListDevices- : PROCEDURE {PlatformCC} (pArg1, pArg2: PVOID; Flags: DWORD): STATUS;
	SetVIDPID- : PROCEDURE {PlatformCC} (dwVID, dwPID: DWORD): STATUS;
	GetVIDPID- : PROCEDURE {PlatformCC} (VAR pdwVID, pdwPID: DWORD): STATUS;
	Close- : PROCEDURE {PlatformCC} (ftHandle: HANDLE): STATUS;
(*	Read- : PROCEDURE {PlatformCC} (ftHandle: HANDLE; lpBuffer: LPVOID; nBufferSize: DWORD; VAR lpBytesReturned: DWORD): STATUS;
	Write- : PROCEDURE {PlatformCC} (ftHandle: HANDLE; lpBuffer: LPVOID; nBufferSize: DWORD; VAR lpBytesWritten: DWORD): STATUS;
*)	
	Read- : PROCEDURE {PlatformCC} (ftHandle: HANDLE; VAR lpBuffer: ARRAY OF SYSTEM.BYTE; nBufferSize: DWORD; VAR lpBytesReturned: DWORD): STATUS;
	Write- : PROCEDURE {PlatformCC} (ftHandle: HANDLE; lpBuffer: ARRAY OF SYSTEM.BYTE; nBufferSize: DWORD; VAR lpBytesWritten: DWORD): STATUS;
	
	IoCtl- :	 PROCEDURE {PlatformCC} (ftHandle: HANDLE;
								dwIoControlCode: DWORD;
								lpInBuf: LPVOID;
								nInBufSize: DWORD;
								lpOutBuf: LPVOID;
								nOutBufSize: DWORD;
								lpBytesReturned: DWORD;
								VAR  lpOverlapped: LPOVERLAPPED): STATUS;
	
	SetBaudRate- : PROCEDURE {PlatformCC} (ftHandle: HANDLE; BaudRate: ULONG): STATUS;
	SetDivisor- : PROCEDURE {PlatformCC} (ftHandle: HANDLE; Divisor: USHORT): STATUS;
	SetDataCharacteristics- : PROCEDURE {PlatformCC} (ftHandle: HANDLE; WordLength, StopBits, Parity: UCHAR): STATUS;
	SetFlowControl- : PROCEDURE {PlatformCC} (ftHandle: HANDLE; FlowControl: USHORT; XonChar,XoffChar: UCHAR): STATUS;
	ResetDevice- : PROCEDURE {PlatformCC} (ftHandle: HANDLE): STATUS;
	SetDtr- : PROCEDURE {PlatformCC} (ftHandle: HANDLE): STATUS;
	ClrDtr- : PROCEDURE {PlatformCC} (ftHandle: HANDLE): STATUS;
	SetRts- : PROCEDURE {PlatformCC} (ftHandle: HANDLE): STATUS;
	ClrRts- : PROCEDURE {PlatformCC} (ftHandle: HANDLE): STATUS;
	GetModemStatus- : PROCEDURE {PlatformCC} (ftHandle: HANDLE; VAR pModemStatus: ULONG): STATUS;
	SetChars- : PROCEDURE {PlatformCC} (ftHandle: HANDLE; EventChar, EventCharEnabled, ErrorChar, ErrorCharEnabled: UCHAR): STATUS;
	Purge- : PROCEDURE {PlatformCC} (ftHandle: HANDLE; Mask: ULONG): STATUS;
	SetTimeouts- : PROCEDURE {PlatformCC} (ftHandle: HANDLE; ReadTimeout, WriteTimeout: ULONG): STATUS;
	GetQueueStatus- : PROCEDURE {PlatformCC} (ftHandle: HANDLE; VAR dwRxBytes: DWORD): STATUS;
	GetQueueStatusEx- : PROCEDURE {PlatformCC} (ftHandle: HANDLE; VAR dwRxBytes: DWORD): STATUS;
	SetEventNotification- : PROCEDURE {PlatformCC} (ftHandle: HANDLE; Mask: DWORD; Param: PVOID): STATUS;
	GetStatus- : PROCEDURE {PlatformCC} (ftHandle: HANDLE; VAR dwRxBytes, dwTxBytes, dwEventDWord: DWORD): STATUS;
	SetBreakOn- : PROCEDURE {PlatformCC} (ftHandle: HANDLE): STATUS;
	SetBreakOff- : PROCEDURE {PlatformCC} (ftHandle: HANDLE): STATUS;
	SetWaitMask- : PROCEDURE {PlatformCC} (ftHandle: HANDLE; Mask: DWORD): STATUS;
	WaitOnMask- : PROCEDURE {PlatformCC} (ftHandle: HANDLE; VAR Mask: DWORD): STATUS;
	GetEventStatus- : PROCEDURE {PlatformCC} (ftHandle: HANDLE; VAR dwEventDWord: DWORD): STATUS;
	ReadEE- : PROCEDURE {PlatformCC} (ftHandle: HANDLE; dwWordOffset: DWORD; VAR lpwValue: DWORD): STATUS;
	WriteEE- : PROCEDURE {PlatformCC} (ftHandle: HANDLE; dwWordOffset: DWORD; wValue: UNSIGNED16): STATUS;
	EraseEE- : PROCEDURE {PlatformCC} (ftHandle: HANDLE): STATUS;


	(* structure to hold program data for Program function *)
	
	TYPE PROGRAM_DATA* = RECORD 
		
		Signature1* : DWORD;	(* Header - must be 00000000H *)
		
		Signature2* : DWORD;	(* Header - must be 0ffffffffH *)
		Version* : DWORD;			(* Header - PROGRAM_DATA version *)
		(*        0 = original *)
		(*        1 = FT2232C extensions *)
		(* 			2 = FT232R extensions *)
		(* 			3 = FT2232H extensions *)
		(* 			4 = FT4232H extensions *)
		(* 			5 = FT232H extensions *)
		VendorId* : UNSIGNED16;				(* 0x0403 *)
		ProductId* : UNSIGNED16;				(* 0x6001 *)
		Manufacturer* : POINTER {UNSAFE} TO ARRAY 256 OF CHAR;			(* "FTDI" *)
		ManufacturerId* : POINTER {UNSAFE} TO ARRAY 256 OF CHAR;		(* "FT" *)
		Description* : POINTER {UNSAFE} TO ARRAY 256 OF CHAR;			(* "USB HS Serial Converter" *)
		SerialNumber* : POINTER {UNSAFE} TO ARRAY 256 OF CHAR;			(* "FT000001" if fixed, or NULL *)
		MaxPower* : UNSIGNED16;				(* 0 < MaxPower <= 500 *)
		PnP* : UNSIGNED16;					(* 0 = disabled, 1 = enabled *)
		SelfPowered* : UNSIGNED16;			(* 0 = bus powered, 1 = self powered *)
		RemoteWakeup* : UNSIGNED16;			(* 0 = not capable, 1 = capable *)
		
		(* Rev4 (FT232B) extensions *)
		
		Rev4* : UCHAR;					(* non-zero if Rev4 chip, zero otherwise *)
		IsoIn* : UCHAR;				(* non-zero if in endpoint is isochronous *)
		IsoOut* : UCHAR;				(* non-zero if out endpoint is isochronous *)
		PullDownEnable* : UCHAR;		(* non-zero if pull down enabled *)
		SerNumEnable* : UCHAR;			(* non-zero if serial number to be used *)
		USBVersionEnable* : UCHAR;	(* non-zero if chip uses USBVersion *)
		USBVersion* : UNSIGNED16;	(* BCD (0x0200* => USB2) *)
		
		(* Rev 5 (FT2232) extensions *)
		
		Rev5* : UCHAR;					(* non-zero if Rev5 chip, zero otherwise *)
		IsoInA* : UCHAR;				(* non-zero if in endpoint is isochronous *)
		IsoInB* : UCHAR;				(* non-zero if in endpoint is isochronous *)
		IsoOutA* : UCHAR;				(* non-zero if out endpoint is isochronous *)
		IsoOutB* : UCHAR;				(* non-zero if out endpoint is isochronous *)
		PullDownEnable5* : UCHAR;	(* non-zero if pull down enabled *)
		SerNumEnable5* : UCHAR;		(* non-zero if serial number to be used *)
		USBVersionEnable5* : UCHAR;	(* non-zero if chip uses USBVersion *)
		USBVersion5* : UNSIGNED16;	(* BCD (0x0200* => USB2) *)
		AIsHighCurrent* : UCHAR;	(* non-zero if interface is high current *)
		BIsHighCurrent* : UCHAR;	(* non-zero if interface is high current *)
		IFAIsFifo* : UCHAR;			(* non-zero if interface is 245 FIFO *)
		IFAIsFifoTar* : UCHAR;		(* non-zero if interface is 245 FIFO CPU target *)
		IFAIsFastSer* : UCHAR;		(* non-zero if interface is Fast serial *)
		AIsVCP* : UCHAR;				(* non-zero if interface is to use VCP drivers *)
		IFBIsFifo* : UCHAR;			(* non-zero if interface is 245 FIFO *)
		IFBIsFifoTar* : UCHAR;		(* non-zero if interface is 245 FIFO CPU target *)
		IFBIsFastSer* : UCHAR;		(* non-zero if interface is Fast serial *)
		BIsVCP* : UCHAR;				(* non-zero if interface is to use VCP drivers *)
		
		(* Rev 6 (FT232R) extensions *)
		
		UseExtOsc* : UCHAR;				(* Use External Oscillator *)
		HighDriveIOs* : UCHAR;			(* High Drive I/Os *)
		EndpointSize* : UCHAR;			(* Endpoint size *)
		PullDownEnableR* : UCHAR;	(* non-zero if pull down enabled *)
		SerNumEnableR* : UCHAR;	(* non-zero if serial number to be used *)
		InvertTXD* : UCHAR;			(* non-zero if invert TXD *)
		InvertRXD* : UCHAR;			(* non-zero if invert RXD *)
		InvertRTS* : UCHAR;			(* non-zero if invert RTS *)
		InvertCTS* : UCHAR;			(* non-zero if invert CTS *)
		InvertDTR* : UCHAR;			(* non-zero if invert DTR *)
		InvertDSR* : UCHAR;			(* non-zero if invert DSR *)
		InvertDCD* : UCHAR;			(* non-zero if invert DCD *)
		InvertRI* : UCHAR;			(* non-zero if invert RI *)
		Cbus0* : UCHAR;				(* Cbus Mux control *)
		Cbus1* : UCHAR;				(* Cbus Mux control *)
		Cbus2* : UCHAR;				(* Cbus Mux control *)
		Cbus3* : UCHAR;				(* Cbus Mux control *)
		Cbus4* : UCHAR;				(* Cbus Mux control *)
		RIsD2XX* : UCHAR;				(* non-zero if using D2XX drivers *)
		
		(* Rev 7 (FT2232H) Extensions *)
		
		PullDownEnable7* : UCHAR;		(* non-zero if pull down enabled *)
		SerNumEnable7* : UCHAR;		(* non-zero if serial number to be used *)
		ALSlowSlew* : UCHAR;			(* non-zero if AL pins have slow slew *)
		ALSchmittInput* : UCHAR;		(* non-zero if AL pins are Schmitt input *)
		ALDriveCurrent* : UCHAR;		(* valid values are 4mA, 8mA, 12mA, 16mA *)
		AHSlowSlew* : UCHAR;			(* non-zero if AH pins have slow slew *)
		AHSchmittInput* : UCHAR;		(* non-zero if AH pins are Schmitt input *)
		AHDriveCurrent* : UCHAR;		(* valid values are 4mA, 8mA, 12mA, 16mA *)
		BLSlowSlew* : UCHAR;			(* non-zero if BL pins have slow slew *)
		BLSchmittInput* : UCHAR;		(* non-zero if BL pins are Schmitt input *)
		BLDriveCurrent* : UCHAR;		(* valid values are 4mA, 8mA, 12mA, 16mA *)
		BHSlowSlew* : UCHAR;			(* non-zero if BH pins have slow slew *)
		BHSchmittInput* : UCHAR;		(* non-zero if BH pins are Schmitt input *)
		BHDriveCurrent* : UCHAR;		(* valid values are 4mA, 8mA, 12mA, 16mA *)
		IFAIsFifo7* : UCHAR;			(* non-zero if interface is 245 FIFO *)
		IFAIsFifoTar7* : UCHAR;		(* non-zero if interface is 245 FIFO CPU target *)
		IFAIsFastSer7* : UCHAR;		(* non-zero if interface is Fast serial *)
		AIsVCP7* : UCHAR;					(* non-zero if interface is to use VCP drivers *)
		IFBIsFifo7* : UCHAR;			(* non-zero if interface is 245 FIFO *)
		IFBIsFifoTar7* : UCHAR;		(* non-zero if interface is 245 FIFO CPU target *)
		IFBIsFastSer7* : UCHAR;		(* non-zero if interface is Fast serial *)
		BIsVCP7* : UCHAR;					(* non-zero if interface is to use VCP drivers *)
		PowerSaveEnable* : UCHAR;	(* non-zero if using BCBUS7 to save power for self-powered designs *)
		
		(* Rev 8 (FT4232H) Extensions *)
		
		PullDownEnable8* : UCHAR;	(* non-zero if pull down enabled *)
		SerNumEnable8* : UCHAR;		(* non-zero if serial number to be used *)
		ASlowSlew* : UCHAR;				(* non-zero if AL pins have slow slew *)
		ASchmittInput* : UCHAR;		(* non-zero if AL pins are Schmitt input *)
		ADriveCurrent* : UCHAR;		(* valid values are 4mA, 8mA, 12mA, 16mA *)
		BSlowSlew* : UCHAR;				(* non-zero if AH pins have slow slew *)
		BSchmittInput* : UCHAR;		(* non-zero if AH pins are Schmitt input *)
		BDriveCurrent* : UCHAR;		(* valid values are 4mA, 8mA, 12mA, 16mA *)
		CSlowSlew* : UCHAR;				(* non-zero if BL pins have slow slew *)
		CSchmittInput* : UCHAR;		(* non-zero if BL pins are Schmitt input *)
		CDriveCurrent* : UCHAR;		(* valid values are 4mA, 8mA, 12mA, 16mA *)
		DSlowSlew* : UCHAR;				(* non-zero if BH pins have slow slew *)
		DSchmittInput* : UCHAR;		(* non-zero if BH pins are Schmitt input *)
		DDriveCurrent* : UCHAR;		(* valid values are 4mA, 8mA, 12mA, 16mA *)
		ARIIsTXDEN* : UCHAR;			(* non-zero if port A uses RI as RS485 TXDEN *)
		BRIIsTXDEN* : UCHAR;			(* non-zero if port B uses RI as RS485 TXDEN *)
		CRIIsTXDEN* : UCHAR;			(* non-zero if port C uses RI as RS485 TXDEN *)
		DRIIsTXDEN* : UCHAR;			(* non-zero if port D uses RI as RS485 TXDEN *)
		AIsVCP8* : UCHAR;					(* non-zero if interface is to use VCP drivers *)
		BIsVCP8* : UCHAR;					(* non-zero if interface is to use VCP drivers *)
		CIsVCP8* : UCHAR;					(* non-zero if interface is to use VCP drivers *)
		DIsVCP8* : UCHAR;					(* non-zero if interface is to use VCP drivers *)
		
		(* Rev 9 (FT232H) Extensions *)
		
		PullDownEnableH* : UCHAR;	(* non-zero if pull down enabled *)
		SerNumEnableH* : UCHAR;		(* non-zero if serial number to be used *)
		ACSlowSlewH* : UCHAR;			(* non-zero if AC pins have slow slew *)
		ACSchmittInputH* : UCHAR;	(* non-zero if AC pins are Schmitt input *)
		ACDriveCurrentH* : UCHAR;	(* valid values are 4mA, 8mA, 12mA, 16mA *)
		ADSlowSlewH* : UCHAR;			(* non-zero if AD pins have slow slew *)
		ADSchmittInputH* : UCHAR;	(* non-zero if AD pins are Schmitt input *)
		ADDriveCurrentH* : UCHAR;	(* valid values are 4mA, 8mA, 12mA, 16mA *)
		Cbus0H* : UCHAR;				(* Cbus Mux control *)
		Cbus1H* : UCHAR;				(* Cbus Mux control *)
		Cbus2H* : UCHAR;				(* Cbus Mux control *)
		Cbus3H* : UCHAR;				(* Cbus Mux control *)
		Cbus4H* : UCHAR;				(* Cbus Mux control *)
		Cbus5H* : UCHAR;				(* Cbus Mux control *)
		Cbus6H* : UCHAR;				(* Cbus Mux control *)
		Cbus7H* : UCHAR;				(* Cbus Mux control *)
		Cbus8H* : UCHAR;				(* Cbus Mux control *)
		Cbus9H* : UCHAR;				(* Cbus Mux control *)
		IsFifoH* : UCHAR;				(* non-zero if interface is 245 FIFO *)
		IsFifoTarH* : UCHAR;		(* non-zero if interface is 245 FIFO CPU target *)
		IsFastSerH* : UCHAR;		(* non-zero if interface is Fast serial *)
		IsFT1248H* : UCHAR;			(* non-zero if interface is FT1248 *)
		FT1248CpolH* : UCHAR;		(* FT1248 clock polarity - clock idle high (1) or clock idle low (0) *)
		FT1248LsbH* : UCHAR;		(* FT1248 data is LSB (1) or MSB (0) *)
		FT1248FlowControlH* : UCHAR;	(* FT1248 flow control enable *)
		IsVCPH* : UCHAR;				(* non-zero if interface is to use VCP drivers *)
		PowerSaveEnableH* : UCHAR;	(* non-zero if using ACBUS7 to save power for self-powered designs *)
	END;

	PPROGRAM_DATA* = POINTER {UNSAFE} TO PROGRAM_DATA;
	



(* ---------------------------------------------------- *)

(*
	
	PROCEDURE EE_Program (ftHandle: HANDLE; VAR pData: PPROGRAM_DATA): STATUS;
	
	PROCEDURE EE_ProgramEx (
									ftHandle: HANDLE; 
									VAR lpData: PPROGRAM_DATA; 
									VAR Manufacturer: ARRAY OF CHAR; 
									VAR ManufacturerId: ARRAY OF CHAR; 
									VAR Description: ARRAY OF CHAR; 
									VAR SerialNumber: ARRAY OF CHAR): STATUS;
	
	PROCEDURE EE_Read (ftHandle: HANDLE; VAR pData: PPROGRAM_DATA): STATUS; 
	
	PROCEDURE EE_ReadEx (ftHandle: HANDLE; 
									VAR lpData: PPROGRAM_DATA; 
									VAR Manufacturer: ARRAY OF CHAR; 
									VAR ManufacturerId: ARRAY OF CHAR; 
									VAR Description: ARRAY OF CHAR; 
									VAR SerialNumber: ARRAY OF CHAR): STATUS;
	
	PROCEDURE EE_UASize (ftHandle: HANDLE; VAR lpdwSize: LPDWORD): STATUS;
	
	PROCEDURE EE_UAWrite (
									ftHandle: HANDLE; 
									VAR pucData: PUCHAR; 
									dwDataLen: DWORD): STATUS;
	
	PROCEDURE EE_UARead (
									ftHandle: HANDLE; 
									VAR pucData: PUCHAR; 
									dwDataLen: DWORD; 
									VAR lpdwBytesRead: LPDWORD): STATUS;
	
	PROCEDURE SetLatencyTimer (
									ftHandle: HANDLE; 
									ucLatency: UCHAR): STATUS;
	
	PROCEDURE GetLatencyTimer (
									ftHandle: HANDLE; 
									VAR pucLatency: PUCHAR): STATUS;
	
	PROCEDURE SetBitMode (
									ftHandle: HANDLE; 
									ucMask: UCHAR; 
									ucEnable: UCHAR): STATUS;
	
	PROCEDURE GetBitMode (
									ftHandle: HANDLE; 
									VAR pucMode: PUCHAR): STATUS;
	
	PROCEDURE SetUSBParameters (
									ftHandle: HANDLE; 
									ulInTransferSize: ULONG; 
									ulOutTransferSize: ULONG): STATUS;
	
	PROCEDURE GetDeviceInfo (
									ftHandle: HANDLE; 
									VAR lpftDevice: DEVICE; 
									VAR lpdwID: LPDWORD; 
									SerialNumber: PCHAR; 
									Description: PCHAR; 
									Dummy: LPVOID): STATUS;
	
	PROCEDURE GetDeviceLocId (
									ftHandle: HANDLE; 
									VAR lpdwLocId: LPDWORD): STATUS;
	
	PROCEDURE StopInTask (
									ftHandle: HANDLE): STATUS;
	
	PROCEDURE RestartInTask (
									ftHandle: HANDLE): STATUS;
	
	PROCEDURE SetResetPipeRetryCount (
									ftHandle: HANDLE; 
									dwCount: DWORD): STATUS;
	
	PROCEDURE ResetPort (
									ftHandle: HANDLE): STATUS;
	
	PROCEDURE CyclePort (
									ftHandle: HANDLE): STATUS;
	
	
	(* Win32-type functions *)
	


	PROCEDURE W32_CreateFile (
									lpszName: LPCSTR; 
									dwAccess: DWORD; 
									dwShareMode: DWORD; 
									VAR lpSecurityAttributes: LPSECURITY_ATTRIBUTES; 
									dwCreate: DWORD; 
									dwAttrsAndFlags: DWORD; 
									hTemplate: HANDLE): STATUS;
	
	PROCEDURE W32_CloseHandle (ftHandle: HANDLE): STATUS;
	
	PROCEDURE W32_ReadFile (
									ftHandle: HANDLE; 
									lpBuffer: LPVOID; 
									nBufferSize: DWORD; 
									VAR lpBytesReturned: LPDWORD; 
									VAR lpOverlapped: LPOVERLAPPED): STATUS;
	
	PROCEDURE W32_WriteFile (
									ftHandle: HANDLE; 
									lpBuffer: LPVOID; 
									nBufferSize: DWORD; 
									VAR lpBytesWritten: LPDWORD; 
									VAR lpOverlapped: LPOVERLAPPED): STATUS;
	
	PROCEDURE W32_GetLastError (ftHandle: HANDLE): STATUS;
	
	PROCEDURE W32_GetOverlappedResult (
									ftHandle: HANDLE; 
									VAR lpOverlapped: LPOVERLAPPED; 
									VAR lpdwBytesTransferred: LPDWORD; 
									bWait: BOOL): STATUS;
	
	PROCEDURE W32_CancelIo (ftHandle: HANDLE): STATUS;
	
	
	
	(* Win32 COMM API type functions *)
	
	TYPE FTCOMSTAT* = RECORD 
		fCtsHold: 0..1 (* 1 Bits Wide *);
		fDsrHold: 0..1 (* 1 Bits Wide *);
		fRlsdHold: 0..1 (* 1 Bits Wide *);
		fXoffHold: 0..1 (* 1 Bits Wide *);
		fXoffSent: 0..1 (* 1 Bits Wide *);
		fEof: 0..1 (* 1 Bits Wide *);
		fTxim: 0..1 (* 1 Bits Wide *);
		fReserved: 0..33554431 (* 25 Bits Wide *);
		cbInQue: DWORD;
		cbOutQue: DWORD;
	END;
	LPFTCOMSTAT* = POINTER TO FTCOMSTAT;
	
	FTDCB* = RECORD 
		DCBlength: DWORD;      (* sizeof(FTDCB)                   *)
		BaudRate: DWORD;       (* Baudrate at which running       *)
		fBinary: 0..1 (* 1 Bits Wide *);     (* Binary Mode (skip EOF check)    *)
		fParity: 0..1 (* 1 Bits Wide *);     (* Enable parity checking          *)
		fOutxCtsFlow: 0..1 (* 1 Bits Wide *); (* CTS handshaking on output       *)
		fOutxDsrFlow: 0..1 (* 1 Bits Wide *); (* DSR handshaking on output       *)
		fDtrControl: 0..3 (* 2 Bits Wide *);  (* DTR Flow control                *)
		fDsrSensitivity: 0..1 (* 1 Bits Wide *); (* DSR Sensitivity              *)
		fTXContinueOnXoff: 0..1 (* 1 Bits Wide *); (* Continue TX when Xoff sent *)
		fOutX: 0..1 (* 1 Bits Wide *);       (* Enable output X-ON/X-OFF        *)
		fInX: 0..1 (* 1 Bits Wide *);        (* Enable input X-ON/X-OFF         *)
		fErrorChar: 0..1 (* 1 Bits Wide *);  (* Enable Err Replacement          *)
		fNull: 0..1 (* 1 Bits Wide *);       (* Enable Null stripping           *)
		fRtsControl: 0..3 (* 2 Bits Wide *);  (* Rts Flow control                *)
		fAbortOnError: 0..1 (* 1 Bits Wide *); (* Abort all reads and writes on Error *)
		fDummy2: 0..131071 (* 17 Bits Wide *);     (* Reserved                        *)
		wReserved: UNSIGNED16;       (* Not currently used              *)
		XonLim: UNSIGNED16;          (* Transmit X-ON threshold         *)
		XoffLim: UNSIGNED16;         (* Transmit X-OFF threshold        *)
		ByteSize: BYTE;        (* Number of bits/byte, 4-8        *)
		Parity: BYTE;          (* 0-4=None,Odd,Even,Mark,Space    *)
		StopBits: BYTE;        (* 0,1,2* = 1, 1.5, 2               *)
		XonChar: CHAR;         (* Tx and Rx X-ON character        *)
		XoffChar: CHAR;        (* Tx and Rx X-OFF character       *)
		ErrorChar: CHAR;       (* Error replacement char          *)
		EofChar: CHAR;         (* End of Input character          *)
		EvtChar: CHAR;         (* Received Event character        *)
		wReserved1: UNSIGNED16;      (* Fill for now.                   *)
	END;
	LPFTDCB* = POINTER TO FTDCB;
	
	FTTIMEOUTS* = RECORD 
		ReadIntervalTimeout: DWORD;          (* Maximum time between read chars. *)
		ReadTotalTimeoutMultiplier: DWORD;   (* Multiplier of characters.        *)
		ReadTotalTimeoutConstant: DWORD;     (* Constant in milliseconds.        *)
		WriteTotalTimeoutMultiplier: DWORD;  (* Multiplier of characters.        *)
		WriteTotalTimeoutConstant: DWORD;    (* Constant in milliseconds.        *)
	END;
	LPFTTIMEOUTS* = POINTER TO FTTIMEOUTS;
	
	
	PROCEDURE W32_ClearCommBreak (
									ftHandle: HANDLE): STATUS;
	
	PROCEDURE W32_ClearCommError (
									ftHandle: HANDLE; 
									VAR lpdwErrors: LPDWORD; 
									VAR lpftComstat: LPFTCOMSTAT): STATUS;
	
	PROCEDURE W32_EscapeCommFunction (
									ftHandle: HANDLE; 
									dwFunc: DWORD): STATUS;
	
	PROCEDURE W32_GetCommModemStatus (
									ftHandle: HANDLE; 
									VAR lpdwModemStatus: LPDWORD): STATUS;
	
	PROCEDURE W32_GetCommState (
									ftHandle: HANDLE; 
									VAR lpftDcb: LPFTDCB): STATUS;
	
	PROCEDURE W32_GetCommTimeouts (
									ftHandle: HANDLE; 
									VAR pTimeouts: FTTIMEOUTS): STATUS;
	
	PROCEDURE W32_PurgeComm (
									ftHandle: HANDLE; 
									dwMask: DWORD): STATUS;
	
	PROCEDURE W32_SetCommBreak (
									ftHandle: HANDLE): STATUS;
	
	PROCEDURE W32_SetCommMask (
									ftHandle: HANDLE; 
									ulEventMask: ULONG): STATUS;
	
	PROCEDURE W32_SetCommState (
									ftHandle: HANDLE; 
									VAR lpftDcb: LPFTDCB): STATUS;
	
	PROCEDURE W32_SetCommTimeouts (
									ftHandle: HANDLE; 
									VAR pTimeouts: FTTIMEOUTS): STATUS;
	
	PROCEDURE W32_SetupComm (
									ftHandle: HANDLE; 
									dwReadBufferSize: DWORD; 
									dwWriteBufferSize: DWORD): STATUS;
	
	PROCEDURE W32_WaitCommEvent (
									ftHandle: HANDLE; 
									VAR pulEvent: PULONG; 
									VAR lpOverlapped: LPOVERLAPPED): STATUS;
	
*)
	(* Device information *)
TYPE 
	DEVICE_LIST_INFO_NODE* = RECORD 
		Flags*: ULONG;
		zType*: ULONG;
		ID*: ULONG;
		LocId*: DWORD;
		SerialNumber*: ARRAY 16 OF CHAR;
		Description*: ARRAY 64 OF CHAR;
		ftHandle*: HANDLE;
	END;
	
	(* Device information flags *)
CONST 
	FLAGS_OPENED* = 1;
	FLAGS_HISPEED* = 2;

VAR
	CreateDeviceInfoList- : PROCEDURE {PlatformCC} (VAR lpdwNumDevs: DWORD): STATUS;
		
	GetDeviceInfoList- :  PROCEDURE {PlatformCC} (VAR pDest: ARRAY OF DEVICE_LIST_INFO_NODE ; 
						VAR lpdwNumDevs: DWORD): STATUS;
		
	GetDeviceInfoDetail- : PROCEDURE {PlatformCC} (dwIndex: DWORD; VAR lpdwFlags, 
						lpdwType,  
						lpdwID, 
						lpdwLocId: DWORD; 
						lpSerialNumber: LPVOID; 
						lpDescription: LPVOID; 
						VAR pftHandle: HANDLE): STATUS;
		
		
		 
		 (*! Version information, Windows??? *)
(*		 
	GetDriverVersion- : PROCEDURE {PlatformCC}  (ftHandle: HANDLE; VAR lpdwVersion: DWORD): STATUS;
		
	GetLibraryVersion- : PROCEDURE {PlatformCC} (VAR lpdwVersion: LDWORD): STATUS;
*)		
		 

CONST
	(* Events *)
	EV_RXCHAR* = 00001H;  (* Any Character received *)
	EV_RXFLAG* = 00002H;  (* Received certain character *)
	EV_TXEMPTY* = 00004H;  (* Transmitt Queue Empty *)
	EV_CTS* = 00008H;  (* CTS changed state *)
	EV_DSR* = 00010H;  (* DSR changed state *)
	EV_RLSD* = 00020H;  (* RLSD changed state *)
	EV_BREAK* = 00040H;  (* BREAK received *)
	EV_ERR* = 00080H;  (* Line status error occurred *)
	EV_RING* = 00100H;  (* Ring signal detected *)
	EV_PERR* = 00200H;  (* Printer error occured *)
	EV_RX80FULL* = 00400H;  (* Receive buffer is 80 percent full *)
	EV_EVENT1* = 00800H;  (* Provider specific event 1 *)
	EV_EVENT2* = 01000H;  (* Provider specific event 2 *)

	(* Escape Functions *)
	SETXOFF* = 1;       (* Simulate XOFF received *)
	SETXON* = 2;       (* Simulate XON received *)
	SETRTS* = 3;       (* Set RTS high *)
	CLRRTS* = 4;       (* Set RTS low *)
	SETDTR* = 5;       (* Set DTR high *)
	CLRDTR* = 6;       (* Set DTR low *)
	RESETDEV* = 7;       (* Reset device if possible *)
	SETBREAK* = 8;       (* Set the device break line. *)
	CLRBREAK* = 9;       (* Clear the device break line. *)

	(* PURGE function flags. *)
	PURGE_TXABORT* = 00001H;  (* Kill the pending/current writes to the comm port. *)
	PURGE_RXABORT* = 00002H;  (* Kill the pending/current reads to the comm port. *)
	PURGE_TXCLEAR* = 00004H;  (* Kill the transmit queue if there. *)
	PURGE_RXCLEAR* = 00008H;  (* Kill the typeahead buffer if there. *)
		
(* ============================== *)	
VAR
	numberOfDevices-: ULONG;
	devInfo- : POINTER TO ARRAY OF DEVICE_LIST_INFO_NODE;
(* ============================== *)


PROCEDURE PrintError*(CONST errStr: ARRAY OF CHAR; portStatus : ULONG);
VAR s: ARRAY 64 OF CHAR;
BEGIN
	IF portStatus # OK THEN
		CASE portStatus OF
		INVALID_HANDLE : s := ' - Invalid handle...';
		| DEVICE_NOT_FOUND : s := ' - Device not found...';
		| DEVICE_NOT_OPENED : s := ' - Device not opened...';
		| IO_ERROR : s := ' - General IO error...';
		| INSUFFICIENT_RESOURCES : s := ' - Insufficient resources...';
		| INVALID_PARAMETER : s := ' - Invalid parameter...';
		| INVALID_BAUD_RATE : s := ' - Invalid baud rate...';
		| DEVICE_NOT_OPENED_FOR_ERASE : s := ' Device not opened for erase...';
		| DEVICE_NOT_OPENED_FOR_WRITE : s := ' Device not opened for write...';
		| FAILED_TO_WRITE_DEVICE : s := ' - Failed to write...';
		| EEPROM_READ_FAILED : s := ' - EEPROM read failed...';
		| EEPROM_WRITE_FAILED : s := ' - EEPROM write failed...';
		| EEPROM_ERASE_FAILED : s := ' - EEPROM erase failed...';
		| EEPROM_NOT_PRESENT : s := ' - EEPROM not present...';
		| EEPROM_NOT_PROGRAMMED : s := ' - EEPROM not programmed...';
		| INVALID_ARGS : s := ' - Invalid arguments...';
		| OTHER_ERROR : s := ' - Other error ...';
		ELSE
			s := ' - Other error ...';   
		END;

		KernelLog.String(errStr); 
		KernelLog.Int(portStatus, 0); KernelLog.String(" : "); KernelLog.String(s);  KernelLog.Ln;
	END;	
END PrintError;

PROCEDURE GetProcAddress*( lib: HostLibs.LibHandle; CONST procName: ARRAY OF CHAR; adr: ADDRESS );
VAR res: BOOLEAN;
BEGIN
	res := HostLibs.GetProcedure(lib,  procName, adr);
END GetProcAddress;

PROCEDURE Init();
VAR res: BOOLEAN;
BEGIN
	res := HostLibs.LoadLibrary(libname, lib);
	ASSERT(res , 100);
	
	(* load functions *)

	GetProcAddress(lib, 'FT_Open',  ADDRESSOF( Open ));
	GetProcAddress(lib, 'FT_OpenEx',  ADDRESSOF( OpenEx ));
	GetProcAddress(lib, 'FT_ListDevices',  ADDRESSOF( ListDevices ));
	GetProcAddress(lib, 'FT_SetVIDPID',  ADDRESSOF( SetVIDPID ));
	GetProcAddress(lib, 'FT_GetVIDPID',  ADDRESSOF( GetVIDPID ));
	
	GetProcAddress(lib, 'FT_Close',  ADDRESSOF( Close ));
	GetProcAddress(lib, 'FT_Read',  ADDRESSOF( Read ));
	GetProcAddress(lib, 'FT_Write',  ADDRESSOF( Write ));
	GetProcAddress(lib, 'FT_IoCtl',  ADDRESSOF( IoCtl ));
          
	GetProcAddress(lib, 'FT_SetBaudRate',  ADDRESSOF( SetBaudRate ));
	GetProcAddress(lib, 'FT_SetDivisor',  ADDRESSOF( SetDivisor ));
	GetProcAddress(lib, 'FT_SetDataCharacteristics',  ADDRESSOF( SetDataCharacteristics ));
	GetProcAddress(lib, 'FT_SetFlowControl',  ADDRESSOF( SetFlowControl ));
	GetProcAddress(lib, 'FT_ResetDevice',  ADDRESSOF( ResetDevice ));
	GetProcAddress(lib, 'FT_SetDtr',  ADDRESSOF( SetDtr ));
	GetProcAddress(lib, 'FT_ClrDtr',  ADDRESSOF( ClrDtr ));
	GetProcAddress(lib, 'FT_SetRts',  ADDRESSOF( SetRts ));
	GetProcAddress(lib, 'FT_ClrRts',  ADDRESSOF( ClrRts ));
	GetProcAddress(lib, 'FT_GetModemStatus',  ADDRESSOF( GetModemStatus ));
	
	GetProcAddress(lib, 'FT_SetChars',  ADDRESSOF( SetChars ));
	GetProcAddress(lib, 'FT_Purge',  ADDRESSOF( Purge ));	
	GetProcAddress(lib, 'FT_SetTimeouts',  ADDRESSOF( SetTimeouts ));

	GetProcAddress(lib, 'FT_GetQueueStatus',  ADDRESSOF( GetQueueStatus ));
	GetProcAddress(lib, 'FT_GetQueueStatusEx',  ADDRESSOF( GetQueueStatusEx ));
	GetProcAddress(lib, 'FT_SetEventNotification',  ADDRESSOF( SetEventNotification ));
	GetProcAddress(lib, 'FT_GetStatus',  ADDRESSOF( GetStatus ));
			
	GetProcAddress(lib, 'FT_SetBreakOn',  ADDRESSOF( SetBreakOn ));
	GetProcAddress(lib, 'FT_SetBreakOff',  ADDRESSOF( SetBreakOff ));
	GetProcAddress(lib, 'FT_SetWaitMask',  ADDRESSOF( SetWaitMask ));
	GetProcAddress(lib, 'FT_WaitOnMask',  ADDRESSOF( WaitOnMask ));
	GetProcAddress(lib, 'FT_GetEventStatus',  ADDRESSOF( GetEventStatus ));


	GetProcAddress(lib, 'FT_ReadEE',  ADDRESSOF( ReadEE ));
	GetProcAddress(lib, 'FT_WriteEE',  ADDRESSOF( WriteEE ));
	GetProcAddress(lib, 'FT_EraseEE',  ADDRESSOF( EraseEE ));

(*	
	GetProcAddress(lib, 'FT_GetDeviceInfo',  ADDRESSOF( GetDeviceInfo ));
	GetProcAddress(lib, 'FT_SetResetPipeRetryCount',  ADDRESSOF( SetResetPipeRetryCount ));
	
	GetProcAddress(lib, 'FT_StopInTask',  ADDRESSOF( StopInTask ));
	GetProcAddress(lib, 'FT_RestartInTask',  ADDRESSOF( RestartInTask ));
	GetProcAddress(lib, 'FT_ResetPort',  ADDRESSOF( ResetPort ));
	GetProcAddress(lib, 'FT_CyclePort',  ADDRESSOF( CyclePort ));
*)
	GetProcAddress(lib, 'FT_CreateDeviceInfoList',  ADDRESSOF( CreateDeviceInfoList ));
	GetProcAddress(lib, 'FT_GetDeviceInfoList',  ADDRESSOF( GetDeviceInfoList ));
	GetProcAddress(lib, 'FT_GetDeviceInfoDetail',  ADDRESSOF( GetDeviceInfoDetail ));

	
	(* windows *)
(*	GetProcAddress(lib, 'FT_GetDriverVersion',  ADDRESSOF( GetDriverVersion ));
	GetProcAddress(lib, 'FT_GetLibraryVersion',  ADDRESSOF( GetLibraryVersion ));
*)	
	(* EEPROM functions *)
	KernelLog.String(libname); KernelLog.String(" library loaded.."); KernelLog.Ln;
END Init;

PROCEDURE Cleanup();
VAR res: BOOLEAN; 
BEGIN
 IF lib # NIL THEN 
 	res := HostLibs.FreeLibrary(lib);
 END;
END Cleanup;

PROCEDURE InitFtdiDevices*;
VAR ftStatus: HANDLE; i: ULONG;
BEGIN	
	ftStatus := CreateDeviceInfoList(numberOfDevices);
	IF  ftStatus # OK THEN
		PrintError("Error: ListDevices: ", ftStatus);
	END;
	ASSERT(ftStatus = OK, 210);

	KernelLog.String("numberOfDevices= "); KernelLog.Int(numberOfDevices, 0); KernelLog.Ln; 
	ASSERT(numberOfDevices > 0 , 211);
	NEW(devInfo, numberOfDevices);

	ftStatus := GetDeviceInfoList(devInfo^, numberOfDevices);
	IF ftStatus = OK THEN
		FOR i:=0 TO numberOfDevices-1 DO
			KernelLog.String("------------------------------"); KernelLog.Ln; 
			KernelLog.String("Device "); 	KernelLog.Int(i, 0); KernelLog.String(": "); KernelLog.Ln; 
			KernelLog.String("Flags= "); KernelLog.Int(devInfo[i].Flags, 0); KernelLog.Ln; 
			KernelLog.String("zType= "); KernelLog.Int(devInfo[i].zType, 0); KernelLog.Ln; 
			KernelLog.String("ID= "); KernelLog.Int(devInfo[i].ID, 0); KernelLog.Ln; 
			KernelLog.String("LocId= "); KernelLog.Int(devInfo[i].LocId, 0); KernelLog.Ln; 
			KernelLog.String("SerialNumber= "); KernelLog.String(devInfo[i].SerialNumber); KernelLog.Ln; 
			KernelLog.String("Description= "); KernelLog.String(devInfo[i].Description); KernelLog.Ln; 
			KernelLog.String("ftHandle= "); KernelLog.Int(devInfo[i].ftHandle, 0); KernelLog.Ln; 
				
		END;
	ELSE
		PrintError("Error: GetDeviceInfoList: ", ftStatus);
	END;

	ASSERT(ftStatus = OK, 212);
END InitFtdiDevices;

(*
(* required on linux *)
PROCEDURE Setvidpid();
VAR ftStatus: STATUS;
BEGIN
	ftStatus := SetVIDPID(0403H, 0FAF0H); (*! required for  linux, disable for windows *) 	
	IF  ftStatus # OK THEN
		PrintError("Error: SetVIDPID : ", ftStatus);		
	END;
	ASSERT(ftStatus = OK, 209);
END Setvidpid;
*)

BEGIN
	Init;
	InitFtdiDevices();
	Modules.InstallTermHandler(Cleanup);		
END FTD2XX.
