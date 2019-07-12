MODULE UsbEhci; (** AUTHOR "staubesv"; PURPOSE "USB Enhanced Host Controller Driver"; *)
(**
 * Bluebottle USB Enhanced Host Controller Driver
 * Implements the UsbHcdi host controller driver interface (HCDI)
 *
 * Usage:
 *
 * This module provides the core implementation of the EHCI driver. Finding EHCI controllers was moved to a separate
 * module to increase flexibility. If your EHCI controller is accessible with PCI, the command:
 * 		UsbEhciPCI.Install ~
 * will install EHCI drivers as needed. To remove them, simply uninstall Ehci modules:
 * 		System.Free UsbEhciPCI UsbEhci ~
 *
 * In other cases, specific modules can be written, that will instanciate drivers as needed.
 *
 * References:
 *	Enhanced Host Controller Interface Specification for Universal Serial Bus, Rev. 1.0
 *
 * Notes:
 * - 64bit control data structures: This driver doesn`t support real 64bit operation. If the host controller indicates 64bit capabilities, i.e. all
 *   pointers used for control data structures as qTd, QHs and buffers are 64bit memory addresses, the upper 32bit of the address are just set to zero
 *   to selected the 0..4GB segment.
 *
 * TODOs:
 * - FSTN save path pointers
 * - use sparse tree for more fine granular scheduling
 * - implement isochronous transfers
 *	- DataToggle would not work for Control Transfers spanning multiple TDs
 *
 * History:
 *
 *	24.11.2005	First release (staubesv)
 * 	15.12.2005	Moved buffer checks to UsbHcdi.Mod (staubesv)
 *	05.01.2006	Fixed EnhancedHostController.DeleteTranfer (staubesv)
 *	10.01.2006	H/W scatter/gather support implemented, fixed bug when sending > 16KB blocks (staubesv)
 *	16.01.2006	FlushPCI added (staubesv)
 *	08.01.2006	Added ScheduleOn, more safe TD unlinked/QH removal (staubesv)
 *	01.03.2006	Fixed critical bug in CreateTDList (staubesv)
 *	02.03.2006 	Implemented port indicator control (staubesv)
 *	03.04.2006	Improved interrupt sharing (staubesv)
 *	05.04.2006	Fixed BIOS-to-OS handoff (staubesv)
 *	28.06.2006	Use KernelLog.Hex instead of UsbHcdi.PrintHex (staubesv)
 *	30.06.2006	Bugfix in InitFramelist: Also reset QH structure for isochronousQH, fixed bug when removing periodic QHs (staubesv)
 *	03.06.2006	UpdatePipe removed (staubesv)
 *	04.06.2006 	Allow LinkTD to automatically clear halt condition (staubesv)
 *	20.07.2006	Release HC ownership when HC driver is shutdown, introduced OverrideHcOwnership constant (staubesv)
 *	03.08.2006	Adapted to UsbHcdi, fixed control transfer > 1TD (staubesv)
 *	13.11.2006	UpdatePipeStatus: Set pipe.status to Usbdi.Stalled when a stall is detected (staubesv)
 *)

IMPORT SYSTEM, KernelLog, Machine, Kernel, Objects, Modules, Locks, UsbHcdi, Usbdi, Debug := UsbDebug, UsbVarTdAlloc, UsbBuffers;

CONST

	Description * = "USB Enhanced Host Controller";

	(* Some configuration stuff *)
	HcInterruptThreshold = 01H; (* Maximum rate at which the host controller will issue interrupts (in microframes, 125 microseconds) *)
	HcFrameListSize = 1024;

	(** Size of TD buffers *)
	TdBufferSize = 4096;

	ScatterGatherListSize = 4200; (* Number of entries in scatter/gather list -> limits the maximum transfer size *)

	(* How many transaction of a single queue head in the asynchronous schedule list is the host controller allowed to execute
	within a micro-frame? Valid values: [0..3] (0 disables the feature).  Will only be set if the HC supports the Asynchronous Schedule Park Mode. Higher values
	should result in higher performance. *)
	HcAsyncParkModeCount = 3;

	(* Host Controller Capability Registers *)
	HcCapLength = 00H;
	HcCapHciVersion = 02H;
	HcCapSparams = 04H;
	HcCapCparams * = 08H;
	HcCapPortroute = 0CH;

	(* Host Controller Operational Registers *)
	HcUsbCmd * = 00H;
	HcUsbSts * = 04H;
	HcUsbIntr * = 08H;
	HcFrIndex * = 0CH;
	HcCtrlDsSegment * = 10H;
	HcPeriodicListBase * = 14H;
	HcAsyncListAddr * = 18H;
	HcConfigFlag * = 40H;
	HcPortSc * = 44H;

	(* HcUsbCmd register fields *)
	CmdInterruptThreshold * = {16..23};
	CmdAsyncSchedParkMode * = {11};
	CmdAsyncSchedParkCount * = {8..9};
	CmdLightHcReset * = {7}; (* Note: optional *)
	CmdAsyncAdvDoorbell * = {6};
	CmdAsyncSchedEnable * = {5};
	CmdPeriodicSchedEnable * = {4};
	CmdFrameListSize * = {2 .. 3};
	CmdHcReset * = {1};
	CmdRunStop * = {0};
	CmdReserved * = {10} + {12..15} + {24..31};

	(* HcUsbSts register fields *)
	StsAsyncSchedule * = {15};
	StsPeriodicSchedule * = {14};
	StsReclamation * = {13};
	StsHcHalted * = {12};
	(* HcUsbSts & HcUsbIntr common fields *)
	StsAsyncAdvance * = {5};
	StsHostSystemError * = {4};
	StsFrameListRollover * = {3};
	StsPortChange * = {2};
	StsUsbError * = {1};
	StsUsbInterrupt * = {0};

	(* Port Status & Control register, EHCIspec p. 26-30 *)
	PscWakeOnOvercurrent = {22};
	PscWakeOnDisconnect = {21};
	PscWakeOnConnect = {20};
	PscTestControl = {16..19};
	PscIndicatorControl = {14..15};
	PscPortOwner = {13};
	PscPortPower * = {12};
	PscLineStatus = {10..11};
	PscPortReset = {8};
	PscSuspend = {7};
	PscForcePortResume = {6};
	PscOvercurrentChange = {5};
	PscOvercurrentActive = {4};
	PscPortEnableChange = {3};
	PscPortEnable *= {2};
	PscConnectStatusChange = {1};
	PscCurrentConnectStatus = {0};
	PscReserved = {9} + {23..31};
	PscChangeMask = {1, 3, 5};

	(* Queue Element Transfer Descriptor; must be 32byte aligned *)
	(* Offsets *)
	QtdNextQtdPointer = 00H;
	QtdAltNextQtdPointer = 04H;
	QtdToken = 08H;
	QtdBufferPtr0 = 0CH;
	QtdBufferPtr1 = 10H;
	QtdBufferPtr2 = 14H;
	QtdBufferPtr3 = 18H;
	QtdBufferPtr4 = 1CH;
	QtdExtBufferPtr0 = 20H;
	QtdExtBufferPtr1 = 24H;
	QtdExtBufferPtr2 = 28H;
	QtdExtBufferPtr3 = 2CH;
	QtdExtBufferPtr4 = 30H;
	(* Masks *)
	QtdTerminate = {0};
	QtdBufferPtr = {12..31};

	(* qTD Token *)
	QtdDataToggle = {31};
	QtdBytesToTransfer = {16..30};
	QtdIoc = {15}; (* Interrupt on complete *)
	QtdCurrentPage = {12..14};
	QtdErrorCounter = {10..11};
	QtdPidCode = {8..9};
	QtdStatus = {0..7};

	(* Isochronous Transfer Descriptor *)
	ItdNextLinkPointer = 00H;
	ItdTransaction0 = 04H;
	ItdBufferPtr0 = 024H;
	ItdBufferPtr1 = 028H;
	ItdBufferPtr2 = 02CH;
	ItdExtBufferPtr0 = 40H;

	(* ITD Transaction *)
	ItdTransactionStatus = {28..31};
	ItdTransactionLength = {16..27};
	ItdTransactionIoc = {15};
	ItdTransactionPg = {12..14};
	ItdTransactionOffset = {0..11};

	(* ITD Buffer Pointers *)
	ItdBufferPtr = {12..31};
	(* ItdBufferPtr0 *)
	ItdEndPt = {8..11};
	ItdReserved = {7};
	ItdDevAdr = {0..6};
	(* ItdBufferPtr1 *)
	ItdIn = {11};
	ItdMaxPacketSize = {0..10};
	(* ItdBufferPtr2 *)
	ItdMult = {0..1};

	(* ITD Transaction Status *)
	ItdStatus = {28..31};
	ItdActive = {31};
	ItdDataBufferError = {30};
	ItdBabbleDetected = {29};
	ItdTransactionError = {28};

	(* Queue Head *)
	(* Offsets *)
	QhHorizontalLinkPointer = 00H;
	QhEpCapabilities1 = 04H;
	QhEpCapabilities2 = 08H;
	QhCurrentQtdPointer = 0CH;
	QhNextQtdPointer = 10H;
	QhAltNextQtdPointer = 14H;
	QhQtdToken = 18H;
	QhBufferPointer0 = 1CH;
	QhBufferPointer1 = 20H;
	QhBufferPointer2 = 24H;
	QhBufferPointer3 = 28H;
	QhBufferPointer4 = 2CH;
	QhExtBufferPointer0 = 30H;
	QhExtBufferPointer1 = 34H;
	QhExtBufferPointer2 = 38H;
	QhExtBufferPointer3 = 3CH;
	QhExtBufferPointer4 = 40H;

	(* Masks *)
	(* Queue Head Horizontal Link Pointer *)
	QhTyp = {1..2};
	QhTypItd = 0;
	QhTypQh = 1;
	QhTypSitd = 2;
	QhTypFstn = 3; (* Frame span traversal node *)
	QhTerminate = {0};

	(* Queue Head Endpoint Capabilities *)
	(* Dword 1 *)
	QhNakCountReload = {28..31};
	QhControlEndpointFlag = {27};
	QhMaxPacketLen = {16..26};
	QhHeadOfReclamation = {15};
	QhDataToggleControl = {14};
	QhEndpointSpeed = {12..13};
	QhEndpointNbr = {8..11};
	QhInactivate = {7};
	QhDeviceAddress = {0..6};
	(* Dword 2 *)
	QhMultiplier = {30..31}; (* High-Bandwidth Pipe Muliplier *)
	QhPortNbr = {23..29};
	QhHubAddr = {16..22};
	QhSplitCMask = {8..15};
	QhSMask = {0..7};

	(* Periodic Frame Span Traversal Node (FSTN) *)
	(* FSTN offsets *)
	FstnNormalPathLinkPointer = 0;
	FstnBackPathLinkPointer = 4;

	(* Status fields of qTD Token *)
	TdActive = {7}; (* If set, the HC will process the qTD *)
	TdHalted = {6}; (* Caused by babble, error counter transition from one to zero or STALL handshake. Will also clear TdActive. *)
	TdDataBufferError = {5}; (* Buffer overrun or underrun *)
	TdBabbleDetected = {4}; (* Babble. Will also set TdHalted *)
	TdTransactionError = {3}; (* No valid response from device during status update (Timeout, CRC errir, PID wrong...) *)
	TdMissedMicroFrame = {2};
	TdSplitTransactionState = {1};
	TdPingState = {0};

	(* Periodic Frame Span Traversal Node *)
	FstnNormalPathLink = 00H;
	FstnBackPathLink = 04H;

	(* Packet Identifier codes *)
	PidOut = 0;
	PidIn = 1;
	PidSetup = 2;

	PageSize = 4096;

	Polling = FALSE;

TYPE
	Qh = POINTER {UNSAFE,UNTRACED} TO RECORD
		horizontalLink: Qh;
		epCapabilities: ARRAY 2 OF LONGINT;
		current, next, alternate: ADDRESS;
		token: LONGINT;
		buffers: ARRAY 5 OF LONGINT;
		(** For 64bits datastructures *)
		extBuffers: ARRAY 5 OF LONGINT;
	END;

	Qtd = POINTER {UNSAFE,UNTRACED} TO RECORD
		next, alternateNext: ADDRESS;
		token: LONGINT;
		buffers: ARRAY 5 OF LONGINT;
		(** For 64bits datastructures *)
		extBuffers: ARRAY 5 OF LONGINT;
	END;

	Itd = POINTER {UNSAFE,UNTRACED} TO RECORD
		next: ADDRESS;
		transactions: ARRAY 8 OF LONGINT;
		buffers: ARRAY 7 OF LONGINT;
	END;

	EnhancedHostController * = OBJECT (UsbHcdi.Hcd)
	VAR
		(** Framelist array. Aligned on 4096, at max 4096 B long *)
		framelist *: UsbHcdi.AlignedMemSpace;
		(** Number of 4 B elements actually used in the framelist *)
		framelistSize: LONGINT;
		(** Lock for syncrhonizing framelist operations *)
		framelistLock: Locks.Lock;
		(** Offset for safe modification of the framelist. Do not modify the framelist less than 1 + framelistOfs of the HC current position. *)
		framelistOfs: LONGINT;

		pwcr * : LONGINT; (* Port Wake Capability Register; Not implemented by device if pwcr = 0 *)

		(* Information from Host Controller Capability Registers *)
		(* HCSPARAMS - Structural Parameters *)
		capDebugPortNumber : LONGINT; 	(* 0: n/a, other: number of debug port (0-15)*)
		capPortIndicators : BOOLEAN; 		(* Do the ports support port indicator control? *)
		capNbrOfCompanionHc : LONGINT; 	(* How many companion host controllers are present (0-15) *)
		capPortsPerCompanion : LONGINT; 	(* Number of ports supported per companion host controller *)
		capPortRoutingRules : BOOLEAN; 	(* Port routing rules *)
		capPortPowerControl : BOOLEAN; 	(* Does the HC support Port Power Control? *)
		capNbrOfPorts : LONGINT; 			(* Number of physical downstream ports implemented by this host controller *)
		(* HCCPARAMS - Capability Parameters *)
		capIsoSchedThreshold : LONGINT; 	(* Isochronous Schedule Threshold *)
		capAsynchSchedPark : BOOLEAN; 	(* Does the controller support the park feature for high-speed transfers? *)
		capProgrammableFLG : BOOLEAN; 	(* FALSE: use default (1024); TRUE: Frame List size is programmable *)
		cap64bit : BOOLEAN; 				(* 32 / 64 bit memory pointers in the data structures *)

		(* EHCI Extended Capabilities Pointer. Used in relation with USB legacy support *)
		eecp : LONGINT;

		(* The size of control data structures is dependent on whether the HC uses 32bit or 64bit address pointers as indicated
		by the cap64bit field *)
		sizeQtd, alignQtd : LONGINT;
		sizeQh, alignQh : LONGINT;
		sizeItd, alignItd: LONGINT;

		(* HC Companion Port Route Descriptor, NIL of not available.
		If the capPortRoutingRules is TRUE, the HC provides a description of which port is routed to
		which companion HC.  *)
		hcportroute : POINTER TO ARRAY OF LONGINT;

		(* queue heads *)
		isochronousQh* : LONGINT;
		interruptQh : POINTER TO ARRAY 11 OF LONGINT;

		(* this array will provide the 16byte aligned TD's for controlTD, bulkTD, isochronousTD and interruptTD[] *)
		qhlist : UsbHcdi.AlignedMemSpace;

		(** Allocator for TD and QH datastructures *)
		allocator: UsbVarTdAlloc.Allocator;

		(* The Asynchronous Advance Doorbell interrupt is always enabled by this driver. Since the interrupt handler will
		clear the bit that were set when it was invoked, it sets hcHandshake to TRUE, so its sticky *)
		hcHandshake * : BOOLEAN;

		(* Set of all currently enabled interrupts *)
		interruptsEnabled * : SET;
		handler: Handler;

		(** Enable power for the specified port *)
		PROCEDURE EnablePortPower*(port : LONGINT);
		VAR status : SET;
		BEGIN
			status := SYSTEM.VAL(SET, SYSTEM.GET32(ports[port]));
			SYSTEM.PUT32(ports[port], status - PscChangeMask + PscPortPower); FlushPCI;
		END EnablePortPower;

		(** Disable power for the specified port *)
		PROCEDURE DisablePortPower*(port : LONGINT);
		VAR status : SET;
		BEGIN
			status := SYSTEM.VAL(SET, SYSTEM.GET32(ports[port]));
			SYSTEM.PUT32(ports[port], status - PscChangeMask - PscPortPower); FlushPCI;
		END DisablePortPower;

		(** Enable the specified port.
		 	The EHCI host controllers do not explicitly support a port enable command. The port will be automatically enabled
		 	by the host controller after a port reset, if a high-speed capable device is attached to it *)
		PROCEDURE ResetAndEnablePort*(port : LONGINT) : BOOLEAN;
		VAR status : SET; mtimer : Kernel.MilliTimer;
		BEGIN
			status := SYSTEM.VAL(SET, SYSTEM.GET32(ports[port]));
			SYSTEM.PUT32(ports[port], status - PscChangeMask + PscPortReset - PscPortEnable); FlushPCI;
			Wait(UsbHcdi.PortResetTime); (* >= 10ms, USBspec *)
			SYSTEM.PUT32(ports[port], status - PscChangeMask - PscPortReset); FlushPCI;
			Wait(2+1); (* 2ms recovery interval according EHCIspec, p. 28 *)
			(* The host controller should have automatically enabled this port *)
			Kernel.SetTimer(mtimer, UsbHcdi.PortEnableTimeout);
			REPEAT
				status := SYSTEM.VAL(SET, SYSTEM.GET32(ports[port]));
			UNTIL (status * PscPortEnable # {}) OR Kernel.Expired(mtimer);
			RETURN status * PscPortEnable # {};
		END ResetAndEnablePort;

		(** Disable the specified port. *)
		PROCEDURE DisablePort*(port : LONGINT);
		VAR status : SET;
		BEGIN
			status := SYSTEM.VAL(SET, SYSTEM.GET32(ports[port]));
			SYSTEM.PUT32(ports[port], status - PscChangeMask- PscPortEnable);
			FlushPCI;
		END DisablePort;

		(** Suspend the specified port (selective suspend). *)
		PROCEDURE SuspendPort*(port : LONGINT) : BOOLEAN;
		VAR status : SET;
		BEGIN
			status := SYSTEM.VAL(SET, SYSTEM.GET32(ports[port]));
			IF (status * PscPortEnable # {}) & (status * PscPortOwner = {}) THEN
				SYSTEM.PUT32(ports[port], status - PscChangeMask + PscSuspend);
				FlushPCI;
				RETURN TRUE;
			END;
			RETURN FALSE;
		END SuspendPort;

		(** Resume a selectively suspended port. *)
		PROCEDURE ResumePort*(port : LONGINT) : BOOLEAN;
		VAR status : SET; timer : Kernel.Timer;
		BEGIN
			status := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
			IF status * CmdRunStop = {} THEN
				(* HC must be running when resume a port. Otherwise, the device would automatically re-renter
				the suspended mode in 10 ms *)
				SYSTEM.PUT32(iobase + HcUsbCmd, status + CmdRunStop);
				FlushPCI;
			END;
			status := SYSTEM.VAL(SET, SYSTEM.GET32(ports[port]));
			IF (status * PscSuspend # {}) & (status * PscPortOwner = {}) THEN
				SYSTEM.PUT32(ports[port], status - PscChangeMask + PscForcePortResume);
				FlushPCI;
				NEW(timer); timer.Sleep(20); (* EHCI p. 60 *)
				SYSTEM.PUT32(ports[port], status - PscChangeMask - PscForcePortResume);
				FlushPCI;
			END;
			RETURN SYSTEM.VAL(SET, SYSTEM.GET32(ports[port])) * PscSuspend = {};
			(* TODO: write 1 to PORTSC Force resume bit if port is suspended; first wait 10ms (EHCIp59)*)
		END ResumePort;

		(** Suspend all ports and then stop the host controller. *)
		PROCEDURE Suspend*;
		VAR dword : SET; i : LONGINT; ignore : BOOLEAN;
		BEGIN
			(* Suspend all individual ports *)
			FOR i := 0 TO portCount - 1 DO ignore := SuspendPort(i); END;
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd)); (* Stop HC *)
			SYSTEM.PUT32(iobase + HcUsbCmd, dword - CmdRunStop);
			FlushPCI;
			(* Put HC in lower device state via the PCI power management interface *)
		END Suspend;

		(** Restart the host controller and selectively resume all suspended ports.  *)
		PROCEDURE Resume*() : BOOLEAN;
		VAR dword : SET; i : LONGINT; res : BOOLEAN;
		BEGIN
			(* Re-start the HC *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
			SYSTEM.PUT32(iobase + HcUsbCmd, dword + CmdRunStop);
			FlushPCI;
			(* Resume all individual ports *)
			res := TRUE;
			FOR i := 0 TO portCount - 1 DO
				IF ~ResumePort(i) THEN res := FALSE; END;
			END;
			RETURN res;
		END Resume;

		(**
		 * Get the status of the specified port.
		 * Registers which indicate status changes are reset by GetPortStatus.
		 * Note: UsbHcdi.HighSpeed will only be correctly set when the port is enabled. The hub driver
		 * takes care of this special behaviour by getting the port status again after it has enabled the port.
		 * @param port Port to get the status of
		 * @return Port status
		 *)
		PROCEDURE GetPortStatus*(port : LONGINT; ack : BOOLEAN) : SET;
		VAR status, s : SET;
		BEGIN
			s := SYSTEM.VAL(SET, SYSTEM.GET32(ports[port]));
			(* Clear all bits that reported a change event; the correspondig register are R/WC *)
			IF ack & ((s * PscChangeMask) # {}) THEN SYSTEM.PUT32(ports[port], s); END;  FlushPCI;
			status := {};
			IF s * PscCurrentConnectStatus # {} THEN status := status + UsbHcdi.PortStatusDevicePresent; END;
			IF s * PscPortEnable # {} THEN status := status + UsbHcdi.PortStatusEnabled END;
			IF s * PscSuspend # {} THEN status := status + UsbHcdi.PortStatusSuspended END;
			IF s * PscOvercurrentActive # {} THEN status := status + UsbHcdi.PortStatusOverCurrent END;
			IF s * PscPortReset # {} THEN status := status + UsbHcdi.PortStatusReset END;
			IF s * PscPortPower # {} THEN status := status + UsbHcdi.PortStatusPowered END;
			IF s * PscConnectStatusChange # {} THEN status := status + UsbHcdi.PortStatusConnectChange END;
			IF s * PscPortEnableChange # {} THEN status := status + UsbHcdi.PortStatusEnabledChange END;
			IF s * PscOvercurrentChange # {} THEN status := status + UsbHcdi.PortStatusOverCurrentChange END;
			IF s * PscTestControl # {} THEN status := status + UsbHcdi.PortStatusTestControl END;
			IF s * PscIndicatorControl # {} THEN status := status + UsbHcdi.PortStatusIndicatorControl END;
			IF s * PscWakeOnOvercurrent # {} THEN status := status + UsbHcdi.PortStatusWakeOnOvercurrent; END;
			IF s * PscWakeOnDisconnect # {} THEN status := status + UsbHcdi.PortStatusWakeOnDisconnect; END;
			IF s * PscWakeOnConnect # {} THEN status := status + UsbHcdi.PortStatusWakeOnConnect; END;
			IF s * PscPortOwner # {} THEN status := status + UsbHcdi.PortStatusPortOwner; END;
			(* When a device is attached to a port of the root hub, the hub driver will try to reset and enable the port.
			The EHCI HC only enables the port if the connected device is a high-speed device which is determined during
			the reset. So if a device is attached to the port, the port is not in reset and it's enabled, it is a high-speed device *)
			IF (s * PscPortEnable = {}) & (s * PscCurrentConnectStatus # {}) & (s * PscPortPower # {}) & (s * {10} # {}) THEN (* Lowspeed device connected *)
				status := status + UsbHcdi.PortStatusLowSpeed;
			ELSIF (s * PscCurrentConnectStatus # {}) & (s * PscPortReset = {}) & (s * PscPortEnable # {}) THEN
				status := status + UsbHcdi.PortStatusHighSpeed;
			END;
			RETURN status;
		END GetPortStatus;

		PROCEDURE HasCompanion*(): BOOLEAN;
		BEGIN
			RETURN TRUE
		END HasCompanion;

		(** Route the specified port to a companion host controller if supported. *)
		PROCEDURE RoutePortToCompanion*(port : LONGINT);
		VAR dword : SET;
		BEGIN
			(* Assert ports are not globally routed to companion controllers *)
			ASSERT(SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcConfigFlag)) * {0} # {});
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(ports[port]));
			SYSTEM.PUT32(ports[port], dword - PscChangeMask + PscPortOwner); FlushPCI;
		END RoutePortToCompanion;

		(** Indicate a port state using the port indicators *)
		PROCEDURE IndicatePort*(port, indicate : LONGINT);
		VAR indicators, dword : SET;
		BEGIN
			IF indicate = UsbHcdi.Amber THEN indicators := {14};
			ELSIF indicate = UsbHcdi.Green THEN indicators := {15};
			ELSE indicators := {};
			END;
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(ports[port]));
			dword := dword - PscIndicatorControl + indicators;
			SYSTEM.PUT32(ports[port], dword); FlushPCI;
		END IndicatePort;

		(**	Return the current frame number.
		 	The micro-frame number is incremented each micro-frame, i.e. per 125us. There are 8 micro-frames per frame *)
		PROCEDURE GetFrameNumber*() : INTEGER;
		BEGIN
			RETURN SYSTEM.VAL(INTEGER, SYSTEM.VAL(SET, LSH(SYSTEM.GET32(iobase + HcFrIndex), -3)) * {0..10});
		END GetFrameNumber;

		(*
		 * Contruct the queue head of the specified pipe.
		 * Fill in the following DWORDs into pipe.descriptors[0]:
		 * - Queue Head Endpoint Capabilities 1
		 * - Queue Head Endpoint Capabilities 2
		 * - Current qTD Pointer
		 * - Next qTD Pointer, Alternate Next qTD Pointer, qTD Token & all five qTD Buffer Pointers
		 * The Queue Head Horizontal Link Pointer will be set by InsertPipeQH
		 * @param pipe
		 *)
		PROCEDURE BuildQueueHead * (pipe : UsbHcdi.Pipe);
		VAR
			qh: Qh;
			dword: SET;
			nakRL, multi, mmask: LONGINT;
		BEGIN
			ASSERT(pipe.maxPacketSize <= 1024); (* Maximum allowed packet size *)

			(*
			pipe.descriptors[0] := Align(pipe.descriptors[0], alignQh);
			pipe.tdBase := pipe.descriptors[0] + alignQh;;
			*)
			(*
			IF ~CheckBoundary(pipe.descriptors[0], sizeQh) THEN
				INC(pipe.descriptors[0], sizeQh);
				INC(pipe.tdBase, sizeQh)
			END;
			*)
			ASSERT(pipe.descriptors[0] # 0);
			qh := pipe.descriptors[0];

			(* Queue Head Horizontal Link Pointer is not set here *)
			(* Queue Head Endpoint Capabilities 1 *)
			nakRL := 3;
			IF pipe.type = UsbHcdi.PipeInterrupt THEN nakRL := 0; END; (* EHCIspec, p.83 *)

			dword := LSH(SYSTEM.VAL(SET, nakRL), 28) * QhNakCountReload;
			IF (pipe.speed # UsbHcdi.HighSpeed) & (pipe.type = UsbHcdi.PipeControl) THEN
				dword := dword + QhControlEndpointFlag;
			END;
			IF pipe.type = UsbHcdi.PipeControl THEN dword := dword  + QhDataToggleControl;  END;
			dword := dword + LSH(SYSTEM.VAL(SET, pipe.maxPacketSize), 16) * QhMaxPacketLen;
			IF (pipe.speed = UsbHcdi.LowSpeed) THEN (* EPS - endpoint speed *)
				dword := dword + {12}; (* Low-speed endpoint *)
			ELSIF (pipe.speed = UsbHcdi.FullSpeed) THEN
				(* Do nothing; Full-speed endpoint *)
			ELSIF (pipe.speed = UsbHcdi.HighSpeed) THEN
				dword := dword + {13}; (* High-speed endpoint *)
			ELSE
				HALT(99);
			END;
			dword := dword + LSH(SYSTEM.VAL(SET, pipe.endpoint), 8) * QhEndpointNbr;
			dword := dword + SYSTEM.VAL(SET, pipe.address) * QhDeviceAddress;
			qh.epCapabilities[0] := SYSTEM.VAL(LONGINT, dword);

			(* Queue Head Endpoint Capabilities 2 *)
			multi := 1; (* TODO: How many transactions per frame for high-speed isochronous and interrupts transfer are allowed? *)
			dword := LSH(SYSTEM.VAL(SET, multi), 30) * QhMultiplier;

			IF ((pipe.speed = UsbHcdi.LowSpeed) OR (pipe.speed = UsbHcdi.FullSpeed)) & (pipe.ttAddress # 0) THEN
				(* Hub port and address for split transaction *)
				dword := dword + LSH(SYSTEM.VAL(SET, pipe.ttAddress), 16) * QhHubAddr;
				dword := dword + LSH(SYSTEM.VAL(SET, pipe.ttPort + 1), 23) * QhPortNbr;

				IF pipe.type = UsbHcdi.PipeInterrupt THEN
					(* In which micro-frames the HC should issue Complete Split tokens *)
					dword := dword + LSH({2..6}, 8) * QhSplitCMask;
				END;
			END;

			mmask := 1;
			IF (pipe.type = UsbHcdi.PipeInterrupt) OR (pipe.type = UsbHcdi.PipeIsochronous) THEN
				dword := dword + SYSTEM.VAL(SET, mmask)  * QhSMask;
			END;
			qh.epCapabilities[1] := SYSTEM.VAL(LONGINT, dword);

			qh.current := 0;

			(* Zero-out the queue head transfer overlay *)
			qh.next := SYSTEM.VAL(LONGINT, QhTerminate);
			qh.alternate := SYSTEM.VAL(LONGINT, QhTerminate);
			qh.token := 0;

			qh.buffers[0] := 0;
			qh.buffers[1] := 0;
			qh.buffers[2] := 0;
			qh.buffers[3] := 0;
			qh.buffers[4] := 0;
			IF cap64bit THEN
				qh.extBuffers[0] := 0;
				qh.extBuffers[1] := 0;
				qh.extBuffers[2] := 0;
				qh.extBuffers[3] := 0;
				qh.extBuffers[4] := 0
			END;
		END BuildQueueHead;

		(** Build a Queue Head for the specified pipe and insert it into the host controller schedule. *)
		PROCEDURE InsertQH (pipe : UsbHcdi.Pipe) (*: BOOLEAN*);
		VAR
			new, curr: Qh;
			adr, asyncListAddr, queue: LONGINT;
			dword: SET;
		BEGIN (*{EXCLUSIVE}*) (* Call from exclusive sections only *)
			ASSERT(state = UsbHcdi.Initialized);
			ASSERT((pipe.maxPacketSize > 0));
			ASSERT(pipe # NIL);
			ASSERT((pipe.type = UsbHcdi.PipeControl) OR (pipe.type = UsbHcdi.PipeBulk)
				OR (pipe.type = UsbHcdi.PipeInterrupt));

			(* Build a new QH *)
			(*pipe.descriptorLock.Acquire;*)
			(*ASSERT(pipe.descriptors = NIL);
			NEW(pipe.descriptors, 1);*)
			pipe.descriptors[0] := allocator.Allocate(sizeQh);
			AssertAlignment(pipe.descriptors[0], alignQh);
			BuildQueueHead(pipe);
			(*pipe.descriptorLock.Release;*)
			(*ShowQueueHead(pipe.descriptors[0], 0, cap64bit);*)

			(* Insert bulk and control QHs into circular QH list. *)
			new := pipe.descriptors[0];
			IF (pipe.type = UsbHcdi.PipeControl) OR (pipe.type = UsbHcdi.PipeBulk) THEN
				(* Insert into the asynchronous schedule list *)
				asyncListAddr := SYSTEM.GET32(iobase + HcAsyncListAddr);
				IF asyncListAddr = 0 THEN (* Not queue heads in the list yet *)
					(* Since the address is obviously invalid, the asynchronous schedule mustn't be enabled *)
					ASSERT(SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts)) * StsAsyncSchedule = {});
					new.horizontalLink := QhHorizontalLink(new, QhTypQh, FALSE);
					(* If the asynchronous schedule is enabled, exactly one queue head MUST have the H-bit set. *)
					dword := SYSTEM.VAL(SET, new.epCapabilities[0]) + QhHeadOfReclamation;
					new.epCapabilities[0] := SYSTEM.VAL(LONGINT, dword);
					(*Machine.FlushDCacheRange(new, sizeQh);*)
					(*ShowQueueHead(new, 0, cap64bit);*)

					(* Insert the queue head into the schedule list and activate the asynchronous schedule *)
					SYSTEM.PUT32(iobase + HcAsyncListAddr, new); FlushPCI;
					IF ~ScheduleOn(CmdAsyncSchedEnable, TRUE) & (Debug.Level >= Debug.Errors) THEN Show("Failed to enable async schedule."); KernelLog.Ln; END;
				ELSE
					ASSERT(SYSTEM.VAL(SET, asyncListAddr) * {0..4} = {}); (* 32byte alignment *)
					curr := asyncListAddr;
					new.horizontalLink := curr.horizontalLink;
					(*Machine.FlushDCacheRange(new, sizeQh);*)

					(* Insert the newly created queue head into the asynchronous schedule list. *)
					curr.horizontalLink := QhHorizontalLink(new, QhTypQh, FALSE);
					(*Machine.FlushDCacheRange(curr, sizeQh);*)
				END;
			ELSE (* pipe is interrupt *)
				curr := SYSTEM.VAL(Qh, pipe.queue);
				new := pipe.descriptors[0];
				new.horizontalLink := curr.horizontalLink;
				(*SYSTEM.PUT32(pipe.qh + QhHorizontalLinkPointer, adr);*)
				curr.horizontalLink := SYSTEM.VAL(ADDRESS, new) + SYSTEM.VAL(LONGINT, {1} - {2});
				(*SYSTEM.PUT32(pipe.queue + QhHorizontalLinkPointer, pipe.qh + SYSTEM.VAL(LONGINT, {1} - {2}));*)
				(*Machine.FlushDCacheRange(SYSTEM.VAL(ADDRESS, new), sizeQh);
				Machine.FlushDCacheRange(pipe.queue, sizeQh);*)
				(* Enable the periodic list if necessary *)
				dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts));
				IF dword * StsPeriodicSchedule = {} THEN
					IF ~ScheduleOn(CmdPeriodicSchedEnable, TRUE) THEN
						IF Debug.Level >= Debug.Errors THEN Show("Could not enable periodic schedule."); KernelLog.Ln; END;
					END;
				END;
			END;
			IF Debug.Trace & Debug.traceQueuing THEN Show("Inserted QH at "); KernelLog.Address(pipe.descriptors[0]); KernelLog.Ln END;
			(*Machine.FlushDCacheRange(pipe.descriptors[0], sizeQh)*)
		END InsertQH;

		(* Enable/Disable the periodic or asynchronous schedule. *)
		PROCEDURE ScheduleOn(cmd : SET; on : BOOLEAN) : BOOLEAN;
		VAR dword, sts : SET; mtimer : Kernel.MilliTimer;
		BEGIN (* Caller must hold obj lock *)
			ASSERT((cmd = CmdPeriodicSchedEnable) OR (cmd = CmdAsyncSchedEnable));
			IF Debug.Trace & Debug.traceQueuing THEN
				IF on THEN Show("Enabling"); ELSE Show("Disabling"); END;
				IF cmd = CmdAsyncSchedEnable THEN KernelLog.String(" asynchronous schedule."); ELSE KernelLog.String(" periodic schedule."); END;
				KernelLog.Ln;
			END;
			IF cmd = CmdAsyncSchedEnable THEN sts := StsAsyncSchedule; ELSE sts := StsPeriodicSchedule; END;
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
			ASSERT(dword * cmd = LSH(SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts)) * sts, -10)); (* HcUsbCmd & HcUsbSts in consistent state *)
			IF on THEN dword := dword + cmd; ELSE dword := dword - cmd; END;
			SYSTEM.PUT32(iobase + HcUsbCmd, dword); FlushPCI;

			(* Wait until the HC reaches the desired state *)
			Kernel.SetTimer(mtimer, 500);
			WHILE ~Kernel.Expired(mtimer) & ((SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts)) * sts # {}) # on) DO
				Objects.Yield;
			END;
			RETURN (SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts)) * sts # {}) = on;
		END ScheduleOn;

		(*
		 * Remove a queue head data structure from the host controller's asynchronous schedule.
		 * The asynchronous schedule is a circular linked list of queue heads. At least one queue heads has
		 * the H-bit (Head of asynchronous schedule list) set which is used by the host controller to detect
		 * empty list conditions. There are two cases when we remove a queue head:
		 * 1) It is the only queue head in the list. In this case, we disabled the asynchronous schedule execution and
		 *     and remove the queue head then.
		 * 2) There are other queue heads in the list. If the queue head to be removed is the head of the list, we
		 *      need to set the H-bit for another queue head.
		 *
		 * Precondition: TDs are already removed from the QH, QH is inactive
		 *)
		 PROCEDURE RemoveAsyncQH(pipe : UsbHcdi.Pipe);
		 VAR
		 	(*start, cur, prev  : LONGINT; dword : SET;*)
		 	start, curr, prev: Qh;
		 	dword: SET;
		 BEGIN (* Caller must hold obj lock *)
			prev := SYSTEM.GET32(iobase + HcAsyncListAddr);
			ASSERT((SYSTEM.VAL(ADDRESS, prev) # 0) & (SYSTEM.VAL(SET, prev) * {0..4} = {}));
			(*Machine.InvalidateDCacheRange(SYSTEM.VAL(ADDRESS, prev), sizeQh);*)
			prev := prev.horizontalLink;
			ASSERT((SYSTEM.VAL(SET, prev) * {1} # {}) & (SYSTEM.VAL(SET, prev) * QhTerminate = {})); (* Pointer references queue head *)
			prev := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, prev) * {5..31});
			(*Machine.InvalidateDCacheRange(prev, sizeQh);*)
			curr := prev.horizontalLink;
			ASSERT((SYSTEM.VAL(SET, curr) * {1} # {}) & (SYSTEM.VAL(SET, curr) * QhTerminate  =  {})); (* Pointer references queue head *)
			curr := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, curr) * {5..31});
			(*Machine.InvalidateDCacheRange(curr, sizeQh);*)

			(* prev is the address of the queue head that points to the queue head with the address cur *)
			IF curr = prev THEN (* Only one queue head in the list *)
				ASSERT(SYSTEM.VAL(SET, curr.epCapabilities[0]) * QhHeadOfReclamation # {});
				(*ASSERT(SYSTEM.VAL(SET, curr.token) * TdActive = {});*)
				IF curr = pipe.descriptors[0] THEN (* just disable asynchronous schedule *)
					IF ScheduleOn(CmdAsyncSchedEnable, FALSE) THEN
						SYSTEM.PUT32(iobase + HcAsyncListAddr, 0); FlushPCI; (* Mark as invalid. *)
						(* Free the queue head *)
						(*pipe.descriptorLock.Acquire;*)
						pipe.descriptors := NIL;
						(*pipe.descriptorLock.Release;*)
						allocator.Free(curr, sizeQh)
					ELSIF Debug.Level >= Debug.Errors  THEN Show("Could not disable async schedule."); KernelLog.Ln;
					END;
				ELSIF Debug.Level >= Debug.Warnings THEN Show("Failed to remove QH from asynchronous schedule: QH not found."); KernelLog.Ln;
				END;
			ELSE (* Find and remove the queue head in the list *)
				(* Search the queue head that references the queue head to be removed *)
				start := curr;
				LOOP
					dword := SYSTEM.VAL(SET, curr.horizontalLink);
					ASSERT(dword * QhTerminate = {}); (* Circular lists don't terminate *)
					ASSERT(dword * {1} # {}); (* Pointer references queue head *)
					ASSERT(dword * {2..4} = {}); (* qTD pointers must be 32byte aligned *)
					prev := curr;
					curr := SYSTEM.VAL(LONGINT, dword * {5..31});
					IF curr = pipe.descriptors[0] THEN (* QH found *) EXIT; END;
					IF curr = start THEN (* list completely searched but QH not found *) EXIT; END;
					(*Machine.InvalidateDCacheRange(curr, sizeQh);*)
				END;

				IF curr = pipe.descriptors[0] THEN (* Found the queue head. prev is pointing to it *)
					(* If we remove the head of reclamation, elect a new one *)
					IF SYSTEM.VAL(SET, curr.epCapabilities[0]) * QhHeadOfReclamation # {} THEN
						IF Debug.Trace & Debug.traceQueuing THEN Show("Electing new head of reclamation."); KernelLog.Ln; END;
						dword := SYSTEM.VAL(SET, prev.epCapabilities[0]);
						prev.epCapabilities[0] := SYSTEM.VAL(LONGINT, dword + QhHeadOfReclamation);
					END;
					(* Remove QH from asynchronous list and inforam host controller *)
					prev.horizontalLink := curr.horizontalLink;
					(*Machine.FlushDCacheRange(prev, sizeQh);*)

					(* Free QH *)
					(*pipe.descriptorLock.Acquire;*)
					pipe.descriptors := NIL;
					(*pipe.descriptorLock.Release;*)
					allocator.Free(curr, sizeQh)
				ELSIF Debug.Level >= Debug.Warnings THEN Show("Failed to remove QH from asynchronous list: QH not found."); KernelLog.Ln;
				END;
				(* Before we may free the pipe ressources, we have to make sure that the HC has no cached references to the structure 	*)
				(* we just removed. 																									*)
				IF ~HcHandshake() THEN
					IF Debug.Level >= Debug.Errors THEN Show("UsbEhci: Serious error: HC handshake failed."); KernelLog.Ln; END;
				END;
			END;
			IF Debug.Trace & Debug.traceQueuing THEN Show("Removed QH at "); KernelLog.Address(curr); KernelLog.Ln; END;
		 END RemoveAsyncQH;

	 	(*
	 	 * Inform the host controller that we removed something from the asynchronous schedule list. This is
		 * necessary since the HC could have cached a copy of the pointer to the queue head we've just removed.
		 *)
		PROCEDURE HcHandshake() : BOOLEAN;
		VAR dword : SET; mtimer : Kernel.MilliTimer; result : BOOLEAN;
		BEGIN (* caller holds object lock *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts));
			ASSERT(dword * StsAsyncSchedule # {}); (* HC behaviour undefined if ringing doorbell while async schedule is off *)
			hcHandshake := FALSE;
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
			SYSTEM.PUT32(iobase + HcUsbCmd, dword + CmdAsyncAdvDoorbell); FlushPCI;
			Kernel.SetTimer(mtimer, 500);
			WHILE ~Kernel.Expired(mtimer) & (SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd)) * CmdAsyncAdvDoorbell # {}) DO
				Objects.Yield;
			END;
			result := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd)) * CmdAsyncAdvDoorbell = {}; (* The HC should have cleared the bit *)
			IF Debug.Trace & Debug.traceQueuing THEN
				Show("HC handshake "); IF result THEN KernelLog.String("succeeded."); ELSE KernelLog.String("failed."); END; KernelLog.Ln;
			END;
			RETURN result;
		END HcHandshake;

		PROCEDURE RemovePeriodicQH(pipe : UsbHcdi.Pipe);
		VAR
			timer : Kernel.Timer;
			cur, temp : Qh;
			next : SET;
		BEGIN (* caller must hold obj lock *)
			IF pipe.descriptors[0] = 0 THEN RETURN; END;
			cur := pipe.descriptors[0];
			LOOP
				(*Machine.InvalidateDCacheRange(cur, sizeQh);*)
				next := SYSTEM.VAL(SET, cur.horizontalLink);
				IF next * {5..31} = SYSTEM.VAL(SET, pipe.descriptors[0]) * {5..31} THEN (* found *)
					temp := SYSTEM.GET32(pipe.descriptors[0] + QhHorizontalLinkPointer);
					cur .horizontalLink := temp;
					(*Machine.FlushDCacheRange(cur, sizeQh);)*)
					IF Debug.Trace & Debug.traceQueuing THEN KernelLog.String("UsbEhci: Deleted Interrupt Pipe QH."); KernelLog.Ln; END;
					NEW(timer); timer.Sleep(10); (* HC has still access to QH, wait > 1ms *)
					EXIT;
				ELSIF next * QhTerminate # {} THEN (* not found, reached end of list *)
					IF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbEhci: Could not delete interrupt QH -> QH not found."); KernelLog.Ln; END;
					EXIT;
				ELSE
					cur := SYSTEM.VAL(LONGINT, next * {5..31});
				END;
			END;
			IF Debug.Trace & Debug.traceQueuing THEN Show("Removed QH at "); KernelLog.Hex(pipe.descriptors[0], 8); KernelLog.Ln; END;
		END RemovePeriodicQH;

		(** Remove the pipe's queue head from the host controller schedule *)
		PROCEDURE RemoveQH (pipe : UsbHcdi.Pipe);
		BEGIN (*{EXCLUSIVE}*)
			IF Debug.Trace & Debug.traceQueuing THEN Show("Removing QH at "); KernelLog.Hex(pipe.descriptors[0], 8); KernelLog.Ln; END;
			(* Assume that no transfer is in progress for this pipe *)

			(* Then remove the pipe's queue head from the host controller schedule *)
			IF (pipe.type = UsbHcdi.PipeControl) OR (pipe.type = UsbHcdi.PipeBulk) THEN
				RemoveAsyncQH(pipe);
			ELSIF pipe.type = UsbHcdi.PipeInterrupt THEN
				RemovePeriodicQH(pipe);
			END;
		END RemoveQH;

		(*(** Checks whether TDs may be linked to the pipe's QH *)
		PROCEDURE LinkTDsAllowed*(pipe : UsbHcdi.Pipe) : BOOLEAN;
		VAR dword : SET;
		BEGIN {EXCLUSIVE}
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.descriptors[0] + QhQtdToken));
			IF dword * TdActive # {} THEN
				IF Debug.Level >= Debug.Errors THEN Show("LinkTDs: ERROR: PIPE IS STILL ACTIVE!!!!"); KernelLog.Ln; END;
				pipe.status := Usbdi.Error; pipe.errors := pipe.errors + UsbHcdi.LinkTDsFailed;
				RETURN FALSE;
			END;
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.descriptors[0] + QhNextQtdPointer));
			IF dword * QhTerminate = {} THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbEhci: LinkTDs: Overwriten valid pointer ?!?"); KernelLog.Ln; END;
				pipe.status := Usbdi.Error; pipe.errors := pipe.errors + UsbHcdi.LinkTDsFailed;
				RETURN FALSE;
			END;
			RETURN TRUE;
		END LinkTDsAllowed;

		(* Insert the TD list <td> into the queue (ED) <queue> *)
		PROCEDURE LinkTDs*(pipe : UsbHcdi.Pipe;  qtd : Machine.Address32);
		VAR dword : SET;
		BEGIN {EXCLUSIVE}
			ASSERT(SYSTEM.VAL(SET, qtd) * {0..4} = {}); (* 32byte alignment *)
			(* Pipe must be inactive... *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.descriptors[0] + QhQtdToken));
			IF dword * TdHalted # {} THEN
				IF Debug.Trace & Debug.tracePipes THEN Show("LinkTDs: Automatically clear halt condition"); KernelLog.Ln; END;
				ClearHalt(pipe);
			END;

			SYSTEM.PUT32(pipe.descriptors[0] + QhNextQtdPointer, qtd);
			(*Machine.FlushDCacheRange(pipe.descriptors[0], sizeQh);
			Machine.FlushDCacheRange(qtd, sizeQtd);*)
			IF SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts)) * StsAsyncSchedule = {} THEN
				dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
				IF dword * CmdAsyncSchedEnable = {} THEN
					IF ~ScheduleOn(CmdAsyncSchedEnable, TRUE) & (Debug.Level >= Debug.Errors) THEN Show("Failed to re-enabled async schedule."); KernelLog.Ln; END;
				END;
			END;
		END LinkTDs;*)

		(** Remove all transfer descriptors from the pipe's queue head *)
		PROCEDURE UnlinkTDs (transfer: UsbHcdi.TransferToken);
		VAR
			i, len: LONGINT;
			dword: SET;
			timer: Kernel.Timer;
			prev, qtd: Qtd;
			qh: Qh;
			mtimer : Kernel.MilliTimer;
		BEGIN (*{EXCLUSIVE}*)
			(*IF pipe.firstTD = 0 THEN RETURN END; (* pipe has not yet been used *)*)
			(* We must inactivate all qTD of the queue head... *)

			(* we should wait until the transaction overlay is also inactive *)
			qh := transfer.pipe.descriptors[0];
			Kernel.SetTimer(mtimer, 2000);
			(*Machine.InvalidateDCacheRange(qh, sizeQh);*)
			dword := SYSTEM.VAL(SET, qh.token);
			WHILE ~Kernel.Expired(mtimer) & (dword  * TdActive # {}) DO
				(*Machine.InvalidateDCacheRange(qh, sizeQh);*)
				dword := SYSTEM.VAL(SET, qh.token);
				Objects.Yield;
			END;
			IF dword * TdActive # {} THEN
				IF Debug.Level >= Debug.Errors THEN Show("Transaction overlay indicates active transfer!"); KernelLog.Ln; END;
			END;

			len := LEN(transfer.tds);

			WHILE (i < len) & (transfer.tds[i] # 0) DO
				qtd := transfer.tds[i];
				AssertAlignment(qtd, alignQtd);
				(*Machine.InvalidateDCacheRange(qtd, sizeQtd);*)
				dword := SYSTEM.VAL(SET, qtd.token);
				allocator.Free(qtd, sizeQtd);
				INC(i)
			END;

			qh.next := SYSTEM.VAL(LONGINT, QhTerminate);
			qh.alternate := SYSTEM.VAL(LONGINT, QhTerminate);
			IF transfer.len > 0 THEN
				Machine.InvalidateDCacheRange(transfer.buffer, transfer.len)
			END;
		END UnlinkTDs;

		(* Remove ITDs from framelist and free them *)
		PROCEDURE UnlinkIso (transfer: UsbHcdi.TransferToken);
		VAR
			i, count: LONGINT;
			hcFrame: ADDRESS;
			itd: Itd;
		BEGIN
			(*ShowFramelist(ADDRESSOF(framelist.data[framelist.base]), framelistSize, LSH(SYSTEM.GET32(iobase + HcFrIndex), -3) MOD framelistSize, FALSE);
			Objects.Yield;*)
			WHILE transfer.tds[count] # 0 DO INC(count) END;
			(* Make sure that HC will not process the ITDs during our work *)
			(*TRACE('Unlink acquire FL');*)
			(*!framelistLock.Acquire;*)
			REPEAT
				hcFrame := ADDRESSOF(framelist.data[framelist.base]) + (LSH(SYSTEM.GET32(iobase + HcFrIndex), -3) MOD framelistSize) * 4;
				(*KernelLog.Enter; KernelLog.String("Unlink waiting for HC"); KernelLog.Exit;*)
			UNTIL (hcFrame + 3 < transfer.tds[0]) OR (hcFrame >= transfer.tds[count]);

			(*KernelLog.Enter; KernelLog.String("Unlink at "); KernelLog.Int((transfer.tds[0] - ADDRESSOF(framelist.data[framelist.base])) DIV 4, 0); KernelLog.String(", HC: "); KernelLog.Int(LSH(SYSTEM.GET32(iobase + HcFrIndex), -3) MOD framelistSize, 0); KernelLog.Exit;*)
			WHILE transfer.tds[i] # 0 DO
				itd := SYSTEM.GET32(transfer.tds[i]);
				ASSERT(SYSTEM.VAL(ADDRESS, itd) MOD 32 = 0);
				ASSERT(SYSTEM.VAL(ADDRESS, itd) DIV 32 # 0);
				SYSTEM.PUT32(transfer.tds[i], itd.next);
				allocator.Free(itd, sizeItd);
				INC(i)
			END;
			(*Machine.FlushDCacheRange(ADDRESSOF(framelist.data[framelist.base]), framelistSize * 4);*)
			(*ShowFramelist(ADDRESSOF(framelist.data[framelist.base]), framelistSize, LSH(SYSTEM.GET32(iobase + HcFrIndex), -3) MOD framelistSize, FALSE);*)
			(*KernelLog.Enter; KernelLog.String("Unlinked"); KernelLog.Exit;*)
			(*!framelistLock.Release;*)
			(*TRACE('Unlink release FL');*)
		END UnlinkIso;

		(*
		 * Clears the Halt bit in the pipe's queue head and removes any qTD from the pipe.
		 * Note that this only makes sense if the Halt feature of the USB device is also cleared used the ClearFeature standard
		 * request. This procedure here only changes the pipe's queue head.
		 *)
		PROCEDURE ClearHalt(pipe : UsbHcdi.Pipe);
		VAR
			qh: Qh;
			dword : SET;
		BEGIN
			qh := pipe.descriptors[0];
			(*Machine.InvalidateDCacheRange(qh, sizeQh);*)
			dword := SYSTEM.VAL(SET, qh.token);
			IF dword * TdHalted # {} THEN
				qh.current := 0;
				(* Zero-out the queue head transfer overlay *)
				qh.next := SYSTEM.VAL(LONGINT, QhTerminate);
				qh.alternate := SYSTEM.VAL(LONGINT, QhTerminate);
				qh.token := 0;
				qh.buffers[0] := 0;
				qh.buffers[1] := 0;
				qh.buffers[2] := 0;
				qh.buffers[3] := 0;
				qh.buffers[4] := 0;
				IF cap64bit THEN
					qh.extBuffers[0] := 0;
					qh.extBuffers[1] := 0;
					qh.extBuffers[2] := 0;
					qh.extBuffers[3] := 0;
					qh.extBuffers[4] := 0;
				END;
				(*Machine.FlushDCacheRange(qh, sizeQh)*)
			ELSIF Debug.Level >= Debug.Warnings THEN Show("Tried to clear a non-halted pipe."); KernelLog.Ln;
			END;
		END ClearHalt;

		PROCEDURE Schedule * (transfer: UsbHcdi.TransferToken);
		BEGIN
			(* Checks *)
			ASSERT(transfer # NIL);
			ASSERT(transfer.pipe # NIL);
			CASE transfer.pipe.type OF
				 UsbHcdi.PipeControl, UsbHcdi.PipeBulk:
					ScheduleAperiodic(transfer)
				|UsbHcdi.PipeIsochronous:
					ScheduleIso(transfer)
				|UsbHcdi.PipeInterrupt:
					(*ScheduleInterrupt(transfer)*)
					ScheduleAperiodic(transfer)
			ELSE
				(* Unknown pipe type *)
				ASSERT((transfer.pipe.type = UsbHcdi.PipeControl) OR (transfer.pipe.type = UsbHcdi.PipeIsochronous)
					OR (transfer.pipe.type = UsbHcdi.PipeBulk) OR (transfer.pipe.type = UsbHcdi.PipeInterrupt));
			END;
		END Schedule;

		(**
		 * Cancel scheduled transfer.
		 * Tries to cancel a scheduled transfer. Fails if transfer is completed or active.
		 *)
		PROCEDURE Cancel * (transfer: UsbHcdi.TransferToken): BOOLEAN;
		BEGIN (*{EXCLUSIVE}*) HALT(301) (* abstract *)
		END Cancel;

		(**
		 * Checks that a periodic pipe policy is allowed for this HCD. Returns FALSE if the policy
		 * requires too much bandwidth, TRUE if the policy is schedulable.
		 *)
		PROCEDURE CheckPipePolicy * (interval, size: LONGINT): BOOLEAN;
		BEGIN
			RETURN TRUE
		END CheckPipePolicy;

		(**
		 * Some HCDIs require some pipe creations to be notified to them. This procedure is called whenever a new
		 * pipe is created, so that the HCDI can take the necessary actions. This is needed, e.g. for bulk and control pipes
		 * on EHCI: we build one qh per pipe.
		 *)
		PROCEDURE RegisterPipe * (pipe: UsbHcdi.Pipe);
		BEGIN (* Call only from exclusive sections *)
			CASE pipe.type OF
				 UsbHcdi.PipeControl, UsbHcdi.PipeBulk:
				 	NEW(pipe.descriptors, 1);
					InsertQH(pipe)
				|UsbHcdi.PipeIsochronous: (* nothing to do *)
				|UsbHcdi.PipeInterrupt:
					IF pipe.irqInterval = 1 THEN (* 1ms queue *)
						pipe.queue := interruptQh[0];
					ELSIF pipe.irqInterval < 4 THEN (* 2ms queue *)
						pipe.queue := interruptQh[1];
					ELSIF pipe.irqInterval < 8 THEN (* 4ms queue *)
						pipe.queue := interruptQh[2];
					ELSIF pipe.irqInterval < 16 THEN (* 8ms queue *)
						pipe.queue := interruptQh[3];
					ELSIF pipe.irqInterval < 32 THEN (* 16ms queue *)
						pipe.queue := interruptQh[4];
					ELSE
						pipe.queue := interruptQh[5]; (* 32 ms queue *)
					END;
					NEW(pipe.descriptors, 2);
					InsertQH(pipe);
					pipe.descriptors[1] := allocator.Allocate(sizeItd)
			ELSE
				(* Unknown pipe type *)
				ASSERT((pipe.type = UsbHcdi.PipeControl) OR (pipe.type = UsbHcdi.PipeIsochronous)
					OR (pipe.type = UsbHcdi.PipeBulk) OR (pipe.type = UsbHcdi.PipeInterrupt))
			END
		END RegisterPipe;

		(**
		 * Some HCDIs require some pipe freeing to be notified to them. This procedure is called whenever a pipe is freed,
		 * so that the HCDI can take necessary steps. This is needed e.g. for bulk and control pipes on EHCI, so that the
		 * controller can remove the queue head.
		 *)
		PROCEDURE UnregisterPipe * (pipe: UsbHcdi.Pipe);
		BEGIN
			CASE pipe.type OF
				 UsbHcdi.PipeControl, UsbHcdi.PipeBulk, UsbHcdi.PipeInterrupt:
					RemoveQH(pipe)
				|UsbHcdi.PipeIsochronous:
			ELSE
				(* Unknown pipe type *)
				ASSERT((pipe.type = UsbHcdi.PipeControl) OR (pipe.type = UsbHcdi.PipeIsochronous)
					OR (pipe.type = UsbHcdi.PipeBulk) OR (pipe.type = UsbHcdi.PipeInterrupt))
			END
		END UnregisterPipe;

(*
		(**
		 * Put the specified control transfer into the host controller's schedule.
		 * USB Control Transfers use a three stage protocol:
		 *  - stage 1: control setup transaction
		 *  - stage 2: optional data stage
		 *  - stage 3: status transaction
		 * For high-speed devices, the PING protocol must be used for OUT transactions in the data stage and status stage.
		 *
		 *
		 * @param pipe
		 * @param direction Direction of the control transfer (UsbHcdi.In (device-to-host) | UsbHcdi.Out (host-to-device))
		 * @param msg Control message
		 * @param bufferlen Number of bytes transmitted/received in the data stage
		 * @param buffer Buffer where to get/put the specified number of bytes
		 *)
		PROCEDURE ScheduleControl*(pipe : UsbHcdi.Pipe; direction : LONGINT; msg : UsbHcdi.ControlMessage;  bufferLen : LONGINT; VAR buffer : Usbdi.Buffer);
		VAR
			qtd : Machine.Address32;
			dword : SET;
			ranges : ARRAY ScatterGatherListSize OF Machine.Range;
			numRanges : LONGINT;
		BEGIN
			(*Machine.FlushDCacheRange(ADDRESSOF(buffer[0]), bufferLen);*)
			(* pipe.tdBase = pipe.descriptors[0] + 32 in UsbHcdi *)
(*			pipe.firstTD := pipe.tdBase;
			ASSERT(pipe.firstTD = pipe.descriptors[0] + alignQh);
*)
			pipe.firstTD := pipe.tdBase - 32 + alignQh;
			AssertAlignment(pipe.firstTD, alignQtd);
			ASSERT(SYSTEM.VAL(SET, pipe.firstTD) * {0..4} = {}); (* qTDs must be 32byte aligned *)
			ASSERT(pipe.firstTD MOD alignQtd = 0);

			IF (pipe.speed = UsbHcdi.LowSpeed) OR (pipe.speed = UsbHcdi.FullSpeed) THEN
				IF pipe.maxRetries = 0 THEN
					(* For low-speed and full-speed devices, the value 0 is not allowed *)
					pipe.maxRetries := 3;
				END;
			END;

			(* Stage1: Control setup transaction *)
			qtd := pipe.firstTD;
			ASSERT((qtd + sizeQtd - 1 <= ADDRESSOF(pipe.tdBuffer[pipe.tdBufferLen-1])));

			AssertAlignment(qtd+sizeQtd, alignQtd);
			SYSTEM.PUT32(qtd + QtdNextQtdPointer, qtd + sizeQtd);
			SYSTEM.PUT32(qtd + QtdAltNextQtdPointer, QtdTerminate); (* Mark Alternate Next qTD Pointer as invalid *)

			dword := LSH(SYSTEM.VAL(SET, pipe.maxRetries), 10) * QtdErrorCounter; (* DataToggle = FALSE; Current Page = 0; no IOC *)
			dword := dword + LSH(SYSTEM.VAL(SET, 8), 16) * QtdBytesToTransfer; (* 8byte control message *)
			dword := dword + LSH(SYSTEM.VAL(SET, PidSetup), 8) * QtdPidCode + TdActive;
			SYSTEM.PUT32(qtd + QtdToken, dword);

			Machine.TranslateVirtual(ADDRESSOF(msg[0]), 8, numRanges, ranges);
			IF numRanges = 0 THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbEhci: ScheduleControl: Scatter/Gather list too small."); KernelLog.Ln; END;
				pipe.status := Usbdi.Error; pipe.errors := pipe.errors + UsbHcdi.TransferTooLarge; RETURN;
			END;

			(* The HC will access the next buffer pointer when the buffer crosses a physical page... *)
			SYSTEM.PUT32(qtd + QtdBufferPtr0, ranges[0].adr);
			IF numRanges > 1 THEN (* buffer is across page boundaries *)
				SYSTEM.PUT32(qtd + QtdBufferPtr1, ranges[1].adr)
			ELSE
				SYSTEM.PUT32(qtd + QtdBufferPtr1, 0);
			END;
			SYSTEM.PUT32(qtd + QtdBufferPtr2, 0);
			SYSTEM.PUT32(qtd + QtdBufferPtr3, 0);
			SYSTEM.PUT32(qtd + QtdBufferPtr4, 0);
			IF cap64bit THEN
				SYSTEM.PUT32(qtd + QtdExtBufferPtr0, 0);
				SYSTEM.PUT32(qtd + QtdExtBufferPtr1, 0);
				SYSTEM.PUT32(qtd + QtdExtBufferPtr2, 0);
				SYSTEM.PUT32(qtd + QtdExtBufferPtr3, 0);
				SYSTEM.PUT32(qtd + QtdExtBufferPtr4, 0);
			END;
			Machine.FlushDCacheRange(qtd, sizeQtd);

			(* Setup phase always starts with dataToggle = FALSE, so now it must be TRUE *)
			pipe.dataToggle := TRUE;

			(* Stage 2: Optional data stage *)
			IF bufferLen # 0 THEN
				IF ~CreateTDList(pipe, direction, bufferLen, 0, buffer, qtd + sizeQtd, qtd, TRUE) THEN
					pipe.status := Usbdi.Error; pipe.errors := UsbHcdi.Internal; RETURN;
				END;
			END;

			Machine.FlushDCacheRange(qtd, sizeQtd);
			qtd := qtd + sizeQtd;
			AssertAlignment(qtd, alignQtd);
			IF qtd + sizeQtd - 1 > ADDRESSOF(pipe.tdBuffer[pipe.tdBufferLen-1]) THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbEhci: TD buffer too small."); KernelLog.Ln; END;
				pipe.status := Usbdi.Error; pipe.errors := pipe.errors + UsbHcdi.OutOfTDs; RETURN;
			END;

			(* stage 3: status: build status TD *)

			SYSTEM.PUT32(qtd + QtdNextQtdPointer, QtdTerminate); (* Last qTD in chain *)
			SYSTEM.PUT32(qtd + QtdAltNextQtdPointer, QtdTerminate); (* Mark Alternate Next qTD Pointer as invalid *)

			dword := QtdDataToggle + TdActive; (* dataToggle always TRUE and set ind TD in status stage; CC = not accessed *)

			IF (direction = UsbHcdi.Out) OR (bufferLen = 0) THEN
				dword := dword + LSH(SYSTEM.VAL(SET, PidIn), 8);
			ELSE
				dword := dword + LSH(SYSTEM.VAL(SET, PidOut), 8);
				IF pipe.speed = UsbHcdi.HighSpeed THEN (* Do PING protocol *)
					dword := dword + TdPingState;
				END;
			END;
			dword := dword + LSH(SYSTEM.VAL(SET, pipe.maxRetries), 10) * QtdErrorCounter;
			IF pipe.ioc THEN dword := dword + QtdIoc; END; (* Set interrupt on completion bit *)
			SYSTEM.PUT32(qtd + QtdToken, dword);

			SYSTEM.PUT32(qtd + QtdBufferPtr0, 0);
			SYSTEM.PUT32(qtd + QtdBufferPtr1, 0);
			SYSTEM.PUT32(qtd + QtdBufferPtr2, 0);
			SYSTEM.PUT32(qtd + QtdBufferPtr3, 0);
			SYSTEM.PUT32(qtd + QtdBufferPtr4, 0);
			IF cap64bit THEN
				SYSTEM.PUT32(qtd + QtdExtBufferPtr0, 0);
				SYSTEM.PUT32(qtd + QtdExtBufferPtr1, 0);
				SYSTEM.PUT32(qtd + QtdExtBufferPtr2, 0);
				SYSTEM.PUT32(qtd + QtdExtBufferPtr3, 0);
				SYSTEM.PUT32(qtd + QtdExtBufferPtr4, 0);
			END;

			Machine.FlushDCacheRange(ADDRESSOF(msg[0]), LEN(msg));
			Machine.FlushDCacheRange(ADDRESSOF(buffer[0]), bufferLen);
			Machine.FlushDCacheRange(qtd, sizeQtd);
			pipe.lastTD := qtd;
		END ScheduleControl;

		PROCEDURE Schedule*(pipe : UsbHcdi.Pipe; bufferLen, offset: LONGINT; VAR buffer: Usbdi.Buffer);
		VAR dword : SET;
		BEGIN
			Machine.FlushDCacheRange(ADDRESSOF(buffer[offset]), bufferLen);
			SYSTEM.PUT32(pipe.descriptors[0] + QhCurrentQtdPointer, 0);
(*			pipe.firstTD := pipe.tdBase;
			ASSERT(pipe.firstTD = pipe.descriptors[0] + alignQh);
*)
			pipe.firstTD :=  pipe.tdBase - 32 + alignQh;

			AssertAlignment(pipe.firstTD, alignQtd);
			ASSERT(pipe.firstTD MOD alignQtd = 0);
			ASSERT(SYSTEM.VAL(SET, pipe.firstTD) * {0..4} = {}); (* qTDs must be 32byte aligned *)

			IF ~CreateTDList(pipe, pipe.direction, bufferLen, offset, buffer, pipe.firstTD, pipe.lastTD, FALSE) THEN
				pipe.status := Usbdi.Error; pipe.errors := pipe.errors + UsbHcdi.LinkTDsFailed; RETURN;
			END;

			SYSTEM.PUT32(pipe.lastTD + QtdNextQtdPointer, QhTerminate);
			IF pipe.ioc THEN
				dword := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.lastTD + QtdToken));
				dword := dword + QtdIoc;
				SYSTEM.PUT32(pipe.lastTD + QtdToken, dword);
			END;
		END Schedule;
*)
		(** Creates qTDs for the transfer and append them to the qtd list of the corresponding pipe. *)
		PROCEDURE ScheduleAperiodic (transfer: UsbHcdi.TransferToken);
		VAR
			qh: Qh;
			first, last: Qtd;
			curr: Qtd;
			dword: SET;
			i, count: LONGINT;
		BEGIN {EXCLUSIVE}
			(*transfer.pipe.transferLock.Acquire;*)
			IF transfer.len > 0 THEN
				Machine.FlushDCacheRange(transfer.buffer, transfer.len)
			END;
			qh := transfer.pipe.descriptors[0];
			ASSERT(SYSTEM.VAL(ADDRESS, qh) # 0);
			AssertAlignment(qh, alignQh);

			(*IF ~ScheduleOn(CmdAsyncSchedEnable, FALSE) THEN TRACE('BOOOOOOOOOOOOOOOOOOOOOOP') ELSE (*TRACE('YOUHOU')*) END;*)
			IF transfer.pipe.type = UsbHcdi.PipeControl THEN
				CreateControlTDs(transfer.pipe, transfer.pipe.direction, transfer.message, transfer.buffer, transfer.len, first, last, count)
			ELSE
				CreateQTDList(transfer.pipe, transfer.pipe.direction, transfer.len, transfer.buffer, first, last, count, FALSE)
			END;

			(* last is the end of the new qTD list: mark its next link as invalid *)
			last.next := SYSTEM.VAL(LONGINT, QtdTerminate);
			IF transfer.pipe.ioc THEN
				dword := SYSTEM.VAL(SET, last.token) + QtdIoc;
				last.token := SYSTEM.VAL(LONGINT, dword)
			END;
			(*Machine.FlushDCacheRange(last, sizeQtd);*)

			(* Find the last qtd for the queue head and append the list 'first' to them. Acquire the pipe descriptor lock for that. *)
			(*transfer.pipe.descriptorLock.Acquire;*)
			(*IF ~ScheduleOn(CmdAsyncSchedEnable, FALSE) THEN
				(*TRACE('BEEEEEEEEEP')*)
			END;*)
			(*Machine.InvalidateDCacheRange(qh, sizeQh);*)
			dword := SYSTEM.VAL(SET, qh.token);
			IF dword * TdHalted # {} THEN
				IF Debug.Trace & Debug.tracePipes THEN Show("LinkTDs: Automatically clear halt condition"); KernelLog.Ln; END;
				ClearHalt(transfer.pipe);
			END;
			REPEAT UNTIL (SYSTEM.VAL(SET, qh.token) * TdActive = {}) OR (SYSTEM.GET32(iobase + HcAsyncListAddr) # qh);
			(*IF dword * TdActive # {} THEN Show("Schedule: pipe is active"); KernelLog.Ln; ShowQueueHead(qh, qh.current, cap64bit); Wait(10000) END;*)
			IF (SYSTEM.VAL(SET, qh.next) * QhTerminate # {}) OR (qh.next = 0) THEN
				qh.next := first
			ELSE
				curr := qh.next;
				WHILE (SYSTEM.VAL(SET, curr.next) - QhTerminate # {}) & (QhTerminate * SYSTEM.VAL(SET, curr.next) = {}) DO
					curr := curr.next
				END;
				curr.next := first;
			END;
			(*IF dword * TdActive # {} THEN Show("Schedule: pipe is active"); KernelLog.Ln; ShowQueueHead(qh, qh.next, cap64bit); LOOP END END;*)
			(*KernelLog.String("========================================================="); KernelLog.Ln;
			TRACE(transfer.len);*)
			(*ShowQueueHead(qh, first, cap64bit);*)
			IF ~ScheduleOn(CmdAsyncSchedEnable, TRUE) THEN
				KernelLog.Enter;
				KernelLog.String("UsbEhci: could not enable ansynchronous scheduling");
				KernelLog.Exit
			END;

			(* Update transfer info with tds *)
			i := 0;
			curr := first;
			WHILE i < count DO
				ASSERT(SYSTEM.VAL(SET, curr) * QtdTerminate = {});
				transfer.tds[i] := curr;
				curr := curr.next;
				INC(i)
			END;
			ASSERT(i = count);
			ASSERT(SYSTEM.VAL(SET, curr) * QtdTerminate # {});
			transfer.status := Usbdi.InProgress;

			(* if pipe supports toggle, toggle *)
			IF (transfer.pipe.type = UsbHcdi.PipeBulk) OR (transfer.pipe.type = UsbHcdi.PipeInterrupt) THEN
				IF transfer.pipe.dataToggle THEN
					transfer.pipe.dataToggle := FALSE
				ELSE
					transfer.pipe.dataToggle := TRUE
				END
			END
		END ScheduleAperiodic;

		(** Create TDs for a control pipe request *)
		PROCEDURE CreateControlTDs (pipe: UsbHcdi.Pipe; direction: LONGINT; msg: UsbHcdi.ControlMessage; buffer: (*ARRAY OF CHAR*) ADDRESS; len: LONGINT;VAR firstTD, lastTD: Qtd; VAR tdCount: LONGINT);
		VAR
			curr, next, last: Qtd;
			dword: SET;
			ranges: POINTER TO ARRAY OF Machine.Range;
			count, i, numRanges: LONGINT;
		BEGIN
			IF (pipe.speed = UsbHcdi.LowSpeed) OR (pipe.speed = UsbHcdi.FullSpeed) THEN
				IF pipe.maxRetries = 0 THEN
					(* For low-speed and full-speed devices, the value 0 is not allowed *)
					pipe.maxRetries := 3;
				END;
			END;

			(* Stage1: Control setup transaction *)
			firstTD := allocator.Allocate(sizeQtd);
			curr := firstTD;
			AssertAlignment(curr, alignQtd);

			curr.alternateNext := SYSTEM.VAL(LONGINT, QtdTerminate); (* Mark Alternate Next qTD Pointer as invalid *)

			dword := LSH(SYSTEM.VAL(SET, pipe.maxRetries), 10) * QtdErrorCounter; (* DataToggle = FALSE; Current Page = 0; no IOC *)
			dword := dword + LSH(SYSTEM.VAL(SET, 8), 16) * QtdBytesToTransfer; (* 8byte control message *)
			dword := dword + LSH(SYSTEM.VAL(SET, PidSetup), 8) * QtdPidCode + TdActive;
			curr.token := SYSTEM.VAL(LONGINT, dword);

			i := (LEN(msg) DIV PageSize) + 1;
			REPEAT
				NEW(ranges, i);
				Machine.TranslateVirtual(UsbBuffers.GetDataAddress(msg), 8, numRanges, ranges^);
				INC(i)
			UNTIL numRanges # 0;

			(* The HC will access the next buffer pointer when the buffer crosses a physical page... *)
			curr.buffers[0] := ranges[0].adr;
			IF numRanges > 1 THEN (* buffer is across page boundaries *)
				curr.buffers[1] := ranges[1].adr
			ELSE
				curr.buffers[1] := 0
			END;
			curr.buffers[2] := 0;
			curr.buffers[3] := 0;
			curr.buffers[4] := 0;
			(*SYSTEM.PUT32(qtd + QtdBufferPtr2, 0);
			SYSTEM.PUT32(qtd + QtdBufferPtr3, 0);
			SYSTEM.PUT32(qtd + QtdBufferPtr4, 0);*)
			IF cap64bit THEN
				curr.extBuffers[0] := 0;
				curr.extBuffers[1] := 0;
				curr.extBuffers[2] := 0;
				curr.extBuffers[3] := 0;
				curr.extBuffers[4] := 0;
				(*SYSTEM.PUT32(qtd + QtdExtBufferPtr0, 0);
				SYSTEM.PUT32(qtd + QtdExtBufferPtr1, 0);
				SYSTEM.PUT32(qtd + QtdExtBufferPtr2, 0);
				SYSTEM.PUT32(qtd + QtdExtBufferPtr3, 0);
				SYSTEM.PUT32(qtd + QtdExtBufferPtr4, 0);*)
			END;
			(*Machine.FlushDCacheRange(curr, sizeQtd);*)

			(* Setup phase always starts with dataToggle = FALSE, so now it must be TRUE *)
			pipe.dataToggle := TRUE;

			(* Stage 2: Optional data stage *)
			IF len # 0 THEN
				CreateQTDList(pipe, direction, len, buffer, next, last, count, TRUE)
			END;
			IF count = 0 THEN
				last := curr
			ELSE
				curr.next := next;
				(*Machine.FlushDCacheRange(curr, sizeQtd)*)
			END;

			curr := allocator.Allocate(sizeQtd);
			last.next := curr;
			(*Machine.FlushDCacheRange(last, sizeQtd);*)
			AssertAlignment(curr, alignQtd);

			(* stage 3: status: build status TD *)
			curr.next := SYSTEM.VAL(LONGINT, QtdTerminate);
			curr.alternateNext := SYSTEM.VAL(LONGINT, QtdTerminate);

			dword := QtdDataToggle + TdActive; (* dataToggle always TRUE and set ind TD in status stage; CC = not accessed *)

			IF (direction = UsbHcdi.Out) OR (len = 0) THEN
				dword := dword + LSH(SYSTEM.VAL(SET, PidIn), 8);
			ELSE
				dword := dword + LSH(SYSTEM.VAL(SET, PidOut), 8);
				(*TRACE(pipe.speed);*)
				(*IF pipe.speed = UsbHcdi.HighSpeed THEN (* Do PING protocol *)
					dword := dword + TdPingState;
				END;*)
			END;
			dword := dword + LSH(SYSTEM.VAL(SET, pipe.maxRetries), 10) * QtdErrorCounter;
			IF pipe.ioc THEN dword := dword + QtdIoc; END; (* Set interrupt on completion bit *)
			curr.token := SYSTEM.VAL(LONGINT, dword);

			curr.buffers[0] := 0;
			curr.buffers[1] := 0;
			curr.buffers[2] := 0;
			curr.buffers[3] := 0;
			curr.buffers[4] := 0;
			IF cap64bit THEN
				curr.extBuffers[0] := 0;
				curr.extBuffers[1] := 0;
				curr.extBuffers[2] := 0;
				curr.extBuffers[3] := 0;
				curr.extBuffers[4] := 0;
			END;

			Machine.FlushDCacheRange(UsbBuffers.GetDataAddress(msg), LEN(msg));
			(*Machine.FlushDCacheRange(buffer, len);*)
			(*Machine.FlushDCacheRange(curr, sizeQtd);*)
			lastTD := curr;
			tdCount := count + 2
		END CreateControlTDs;

		(** Create qTD list *)
		PROCEDURE CreateQTDList (pipe: UsbHcdi.Pipe; direction, len: LONGINT; buffer: ADDRESS; VAR firstTD, lastTD: Qtd; VAR tdCount: LONGINT; tdToggle: BOOLEAN);
		VAR
			prev, qtd: Qtd;
			restlen, curlen, temp: LONGINT;
			i, j: LONGINT;
			dword: SET;
			numRanges, idx, offset: LONGINT;
			sgList: POINTER TO ARRAY OF Machine.Range;
			buf: ADDRESS;
			t: HUGEINT;
		BEGIN
			ASSERT((pipe.maxRetries >= 0) & (pipe.maxRetries <= 3));

			Machine.FlushDCacheRange(buffer, len);
			j := (len DIV PageSize) + 1;
			REPEAT
				NEW(sgList, j);
				Machine.TranslateVirtual(buffer, len, numRanges, sgList^);
				INC(j, 1)
			UNTIL numRanges # 0;

			(*KernelLog.Enter; KernelLog.Address(buffer); KernelLog.String(" -> "); KernelLog.Address(sgList[0].adr); KernelLog.Exit;*)

			idx := 0;
			offset := 0;		(* offset from last qTD (must fill multiples of packetSize into qTD buffers) *)
			curlen := 0; 		(* amount of data that is transferred in a single qTD *)
			restlen := len;	(* total amount of data to be transferred *)
			firstTD := 0;
			lastTD := 0;
			tdCount := 0;
			buf := sgList[idx].adr + offset;

			WHILE restlen > 0 DO (* build qTD chain *)
				(*TRACE(restlen);*)
				(* allocate the next qTD of the chain *)
				qtd := allocator.Allocate(sizeQtd);
				IF SYSTEM.VAL(ADDRESS, prev) = 0 THEN
					firstTD := qtd
				ELSE
					buf := GetNextPhysicalPage(sgList^, idx, buf);
					prev.next := qtd;
					(*Machine.FlushDCacheRange(prev, sizeQtd)*)
				END;

				(* Each qTD has four buffer pointers. Each buffer is 4K. The buffer must be virtually contiguous but may be				*)
				(* physically non-contiguous. The HC detects crossings of page boundaries and increments the current buffer pointer. 	*)
				qtd.buffers[0] := buf;

				curlen := PageSize - LONGINT(buf MOD PageSize);
				(*TRACE(curlen);*)
				IF curlen > restlen THEN (* No other buffer pointers needed, fits into the first page *)
					curlen := restlen;
				END;
				(*TRACE(curlen);*)
				ASSERT(curlen > 0);

				restlen := restlen - curlen; offset := 0;
				(*TRACE(restlen);*)

				(* Fill in the other 4 buffer pointers *)
				FOR j := 1 TO 4 DO
					IF restlen <= 0 THEN
						(*TRACE(0);*)
						qtd.buffers[j] := 0;
					ELSE
						IF j = 4 THEN (* last buffer available in this qTD *)
							temp := PageSize - ((curlen + PageSize) MOD pipe.maxPacketSize); (* data that fits into the last buffer (max) *)
							IF restlen > temp THEN
								(* The HC will issues USB transaction at pipe.maxPacketSize granularity. If this is not the 			*)
								(* last qTD of this qTD chain, curlen must be multiple of pipe.maxPacketSize. If the last qTD of this	*)
								(* chain was not a multiple of pipe.maxPacketSize, the device will send more data (since we 		*)
								(* requested more data) and the HC thinks it's a babble.											*)
								curlen := curlen + temp; restlen := restlen - temp; offset := temp;
								(*TRACE(curlen);*)
								buf := GetNextPhysicalPage(sgList^, idx, buf);
								ASSERT(buf MOD PageSize = 0);
								qtd.buffers[j] := buf;
								IF temp < PageSize THEN
									DEC(buf, PageSize - temp)
								END;
							ELSE (* this is the last qTD in chains *)
								curlen := curlen + restlen; restlen := 0;
								(*TRACE(curlen);*)
								buf := GetNextPhysicalPage(sgList^, idx, buf);
								ASSERT(buf MOD PageSize = 0);
								qtd.buffers[j] := buf
							END;
						ELSE
							IF restlen > PageSize THEN
								(*TRACE(curlen);*)
								curlen := curlen + PageSize; restlen := restlen - PageSize;
							ELSE
								(*TRACE(curlen);*)
								curlen := curlen + restlen; restlen := 0;
							END;
							buf := GetNextPhysicalPage(sgList^, idx, buf);
							ASSERT(buf MOD PageSize = 0);
							qtd.buffers[j] := buf;
						END
					END
				END;

				IF cap64bit THEN
					qtd.extBuffers[0] := 0;
					qtd.extBuffers[1] := 0;
					qtd.extBuffers[2] := 0;
					qtd.extBuffers[3] := 0;
					qtd.extBuffers[4] := 0;
				END;

				qtd.alternateNext := SYSTEM.VAL(LONGINT, QtdTerminate); (* Mark Alternate Next qTD Pointer as invalid *)

				(*TRACE(curlen);*)
				ASSERT(curlen <= 5000H); (* Maximum allowed value for a single qTD: 5*4KB *)

				dword := TdActive;
				dword := dword + LSH(SYSTEM.VAL(SET, pipe.maxRetries), 10) * QtdErrorCounter;  (* Current Page=0 *)
				(*TRACE(dword);*)
				dword := dword + LSH(SYSTEM.VAL(SET, curlen), 16) * QtdBytesToTransfer;
				(*TRACE(dword);*)

				IF tdToggle THEN
					IF pipe.dataToggle THEN	dword := dword + QtdDataToggle; END;

					(* Calculate datatoggle value for next TD *)
					IF (curlen DIV pipe.maxPacketSize) MOD 2 # 0 THEN
						pipe.dataToggle := ~pipe.dataToggle;
					END;
				END;

				IF direction = UsbHcdi.In  THEN
					dword := dword + LSH(SYSTEM.VAL(SET, PidIn), 8);
				ELSIF direction = UsbHcdi.Out THEN
					dword := dword + LSH(SYSTEM.VAL(SET, PidOut), 8);
					IF pipe.speed = UsbHcdi.HighSpeed THEN (* Do PING protocol *)
						dword := dword + TdPingState;
					END;
				END;
				(*TRACE(dword);*)

				qtd.token := SYSTEM.VAL(LONGINT, dword);
				(*TRACE(SYSTEM.VAL(SET, qtd.token));*)
				(*Machine.FlushDCacheRange(qtd, sizeQtd);*)
				prev := qtd;
				INC(tdCount)
			END;

			lastTD := qtd;
		END CreateQTDList;

		PROCEDURE ScheduleIso (transfer: UsbHcdi.TransferToken);
		VAR
			sgList: ARRAY 1024 OF Machine.Range;
			itds: ARRAY UsbHcdi.MaxTDs OF ADDRESS;
			first, last, itd: Itd;
			adr, currBuf, currOfs, currRange, currTrans, i, itdTxSize, j,
			numFrames, numRanges, remLen, transSize: LONGINT;
			fridx, interval, frame: LONGINT;
			firstEntry: ADDRESS;
			dword: SET;
		BEGIN
			Machine.TranslateVirtual(transfer.buffer, transfer.len, numRanges, sgList);
			Machine.FlushDCacheRange(transfer.buffer, transfer.len);
			IF numRanges = 0 THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbEhci: Schedule: Scatter/Gather list too small"); KernelLog.Ln; END;
				transfer.pipe.status := Usbdi.Error; transfer.pipe.errors := transfer.pipe.errors + UsbHcdi.TransferTooLarge;
			END;

			(* Compute transfer parameters *)
			remLen := transfer.len;

			(*KernelLog.String(":: Iso TX size: "); KernelLog.Int(transfer.len, 0); KernelLog.Ln;
			KernelLog.String(":: iTD Size: "); KernelLog.Int(sizeItd, 0); KernelLog.Ln;*)

			(* Prepare iTDs *)
			first := allocator.Allocate(sizeItd);
			itd := first;
			IF itd = ADDRESS(0) THEN
				KernelLog.String("ITD = 0, ABORTING");
				KernelLog.Ln;
				ASSERT(itd # ADDRESS(0))
			END;

			numFrames := 0;
			currRange := 0;
			currOfs := sgList[currRange].adr MOD 4096;
			adr := sgList[currRange].adr - sgList[currRange].adr MOD 4096;
			REPEAT
				itdTxSize := 0;
				currBuf := 0;
				currTrans := 0;

				itd.buffers[currBuf] := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, adr) * ItdBufferPtr);

				(* iTD transactions *)
				WHILE (remLen > 0) & (currTrans < 8) DO
					(* Compute buffer offset and buffer page *)
					IF currOfs >= 4096 THEN
						(* Buffer offset overflow, allocate new buffer *)
						currOfs := currOfs MOD 4096;
						INC(currBuf);

						INC(adr, 4096);
						IF adr >= sgList[currRange].adr + sgList[currRange].size THEN
							INC(currRange);
							adr := sgList[currRange].adr - sgList[currRange].adr MOD 4096
						END;
						dword := SYSTEM.VAL(SET, adr) * ItdBufferPtr;
						itd.buffers[currBuf] := SYSTEM.VAL(LONGINT, dword)
					END;

					(* Compute transaction size and evaluate need for IOC *)
					transSize := transfer.pipe.maxPacketSize * transfer.pipe.mult;
					dword := {};
					IF remLen <= transSize THEN
						(* Last transaction: transfer remaining bytes and set IOC *)
						transSize := remLen;
						dword := ItdTransactionIoc
					END;

					(* Write transaction *)
					dword := dword + ItdActive + SYSTEM.VAL(SET, LSH(transSize, 16)) + SYSTEM.VAL(SET, LSH(currBuf, 12)) * {12 .. 14} + SYSTEM.VAL(SET, currOfs) * {0 .. 11};
					itd.transactions[currTrans] := SYSTEM.VAL(LONGINT, dword);

					INC(itdTxSize, transSize);
					DEC(remLen, transSize);
					INC(currOfs, transSize);
					INC(currTrans)

					(*;KernelLog.String(":: iTD "); KernelLog.Int((itd - pipe.firstTD) DIV sizeItd, 0);
					(*KernelLog.String(" :: Transaction "); KernelLog.Int(currTrans, 0);
					KernelLog.String(" :: TX Size "); KernelLog.Int(transSize, 0);
					KernelLog.String(" :: Remaining "); KernelLog.Int(remLen, 0);*) KernelLog.Ln;*)

				END;

				(* First buffer is always used.
				 * This buffer can be the same as the last buffer of the previous iTD or the next physical page,
				 * depending on the overflow condition of currOfs. *)
				IF currOfs >= 4096 THEN
					(* Buffer offset overflow, allocate new buffer *)
					currOfs := currOfs MOD 4096;
					INC(currBuf);

					INC(adr, 4096);
					IF adr >= sgList[currRange].adr + sgList[currRange].size THEN
						INC(currRange);
						adr := sgList[currRange].adr - sgList[currRange].adr MOD 4096
					END;
					IF currBuf < 7 THEN
						dword := SYSTEM.VAL(SET, adr) * ItdBufferPtr;
						itd.buffers[currBuf] := SYSTEM.VAL(LONGINT, dword);
					END
				END;

				(* Next Link *)
				dword := {0};
				itd.next := 1(*SYSTEM.VAL(LONGINT, dword)*);

				(* iTD endpoint parameters *)
				dword := SYSTEM.VAL(SET, itd.buffers[0]);
				dword := dword * ItdBufferPtr + SYSTEM.VAL(SET, LSH(transfer.pipe.endpoint, 8)) * {8 .. 11} + SYSTEM.VAL(SET, transfer.pipe.address) * {0 .. 6};
				itd.buffers[0] := SYSTEM.VAL(LONGINT, dword);
				dword := SYSTEM.VAL(SET, itd.buffers[1]);
				dword := dword * ItdBufferPtr + SYSTEM.VAL(SET, transfer.pipe.maxPacketSize) * {0 .. 10};
				IF transfer.pipe.direction = UsbHcdi.In THEN INCL(dword, 11) END;
				itd.buffers[1] := SYSTEM.VAL(LONGINT, dword);
				dword := SYSTEM.VAL(SET, itd.buffers[2]);
				dword := dword * ItdBufferPtr + SYSTEM.VAL(SET, transfer.pipe.mult) * {0 .. 1};
				itd.buffers[2] := SYSTEM.VAL(LONGINT, dword);

				(*Machine.FlushDCacheRange(itd, sizeItd);*)
				(*ShowItd(itd, 0);
				TRACE(SYSTEM.GET32(iobase + HcPeriodicListBase));*)
				itds[numFrames] := itd;
				INC(numFrames);
				IF remLen > 0 THEN
					itd := allocator.Allocate(sizeItd);
				END;
			UNTIL (remLen = 0) OR (numFrames = framelistSize);

			IF (*numFrames >= framelistSize*) remLen > 0 THEN
				KernelLog.String("UsbEhci: cannot schedule more than 1 frame list (");
				KernelLog.Int(framelistSize, 0);
				KernelLog.String(" iTDs) at a time. Transfer is too big.");
				KernelLog.Ln;
				ASSERT(remLen = 0)
			END;

			last := itd;

			(*KernelLog.String("Number of iTDs:	"); KernelLog.Int(numFrames, 0); KernelLog.Ln;
			KernelLog.String("Total tx size:	"); KernelLog.Int(transfer.len, 0); KernelLog.Ln;*)

			(**TRACE('Sched acquire FL');*)
			(*framelistLock.Acquire;*)
			(*IF ~ScheduleOn(CmdPeriodicSchedEnable, FALSE) THEN TRACE('BOOOOOOOOOOOOOOOOOOOOOOP') ELSE (*TRACE('YOUHOU')*) END;*)
			(* Link iTDs: find next framelist offset *)
			(*!interval := LSH(1, pipe.irqInterval) DIV 8;
			IF interval = 0 THEN interval := 1 END;*)
			BEGIN {EXCLUSIVE}
				interval := 1;
				frame := framelist.base;
				(* We must put the iTDs at this offset from the base of the periodic frame list: current index + 1 for uncertainty + 1 to get the next *)
				SYSTEM.GET(iobase + HcFrIndex, fridx);
				(*TRACE(fridx, LSH(fridx, -3) MOD framelistSize);*)
				fridx := (LSH(fridx, -3) MOD framelistSize) + 1 + framelistOfs + 2;
				firstEntry := ADDRESSOF(framelist.data[frame + fridx]);
				(*TRACE(SYSTEM.GET32(iobase + HcPeriodicListBase), ADDRESSOF(framelist.data[framelist.base]));*)

				(* Insert iTDs *)
				(*TRACE(fridx);*)
				(*ShowFramelist(ADDRESSOF(framelist.data[framelist.base]), framelistSize, LSH(SYSTEM.GET32(iobase + HcFrIndex), -3) MOD framelistSize, FALSE);*)
				(*KernelLog.Enter; KernelLog.String("Link HC: "); KernelLog.Int(fridx - 3 - framelistOfs, 0); KernelLog.Exit;*)
				FOR i := 0 TO numFrames - 1 DO
					itd := itds[i];
					ASSERT(SYSTEM.VAL(ADDRESS, itd) # 0);
					fridx := fridx MOD framelistSize;

					(* Get the next free entry *)
					WHILE framelist.data[frame + fridx] MOD 8 = 0 DO fridx := (fridx + interval) MOD framelistSize END;

					(*ShowItd(itd, 0);*)
					(* Not an itd entry *)
					itd.next := framelist.data[frame + fridx];
					(*KernelLog.Enter; KernelLog.String("Link at "); KernelLog.Int(fridx, 0); KernelLog.Exit;*)
					(*SYSTEM.PUT32(frame + 4 * fridx, SYSTEM.VAL(SET, itd) * {5 .. 31}); (* Typ = 00 and T = 0 *)*)
					framelist.data[frame + fridx] := SYSTEM.VAL(ADDRESS, itd);

					(* Store the address of the framelist entry instead of ITD directly *)
					transfer.tds[i] := ADDRESSOF(framelist.data[frame + fridx]);
					INC(fridx, interval)
				END;
			END;
			(*lastEntry := ADDRESSOF(framelist.data[frame + fridx + 1]);*)
			(*framelistLock.Release;*)
			(*Machine.FlushDCacheRange(ADDRESSOF(framelist.data[frame]), framelistSize * 4);*)
			(*TRACE('Sched release FL');*)

			(*ShowFramelist(ADDRESSOF(framelist.data[framelist.base]), framelistSize, LSH(SYSTEM.GET32(iobase + HcFrIndex), -3) MOD framelistSize, FALSE);*)

			IF SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts)) * StsPeriodicSchedule = {} THEN
				(*TRACE('PERIODIC SCHEDULE DISABLED');*)
				dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
				IF dword * CmdPeriodicSchedEnable = {} THEN
					IF ~ScheduleOn(CmdPeriodicSchedEnable, TRUE) & (Debug.Level >= Debug.Errors) THEN Show("Failed to re-enable periodic schedule."); KernelLog.Ln; END;
				END
			END;
			transfer.status := Usbdi.InProgress;

			(*KernelLog.Enter; KernelLog.String(":: Entered iTDs at frame #"); KernelLog.Int(frame, 0); KernelLog.Ln;*)
			(*KernelLog.String(":: Isochronous Scheduling Threshold: "); KernelLog.Int(frameListOfs, 0); KernelLog.Exit;*)
		END ScheduleIso;

		(** Schedule an interrupt transfer: create an iTD, link to QH from it and place it in framelist. *)
		PROCEDURE ScheduleInterrupt (transfer: UsbHcdi.TransferToken);
		VAR
			itd: Itd;
			qh: Qh;
			frame, fridx: LONGINT;
		BEGIN
			(*itd := transfer.pipe.descriptors[1];*)
			qh := transfer.pipe.descriptors[0];

			(*itd.next := QhHorizontalLink(qh, QhTypQh, FALSE);*)

			frame := framelist.base;
			(* We must put the iTDs at this offset from the base of the periodic frame list: current index + 1 for uncertainty + 1 to get the next *)
			fridx := SYSTEM.GET32(iobase + HcFrIndex);
			fridx := (LSH(fridx, -3) MOD framelistSize) + 1 + framelistOfs;
			framelist.data[frame + fridx] := QhHorizontalLink(qh, QhTypQh, FALSE);
		END ScheduleInterrupt;

		PROCEDURE InterruptHandler;
		VAR s  : SET;
		BEGIN
			IF Debug.Stats THEN INC(NnofInterrupts); END;
			IF state >= UsbHcdi.Initialized THEN
				s := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts)) * interruptsEnabled;
				(* Reset interrupt status register (Write clear)*)
				SYSTEM.PUT32(iobase + HcUsbSts, s (** {0..5}*)); FlushPCI;
				handler.Handle(s)
			END
		END InterruptHandler;

		PROCEDURE DoHandleInterrupt (s: SET);
		BEGIN (* Works without being exclusive *)
			IF s # {} THEN
				IF Debug.Stats THEN INC(NnofInterruptsHandled); END;
				IF Debug.Trace & Debug.traceInterrupts THEN
					Show("Interrupt: "); ShowInterrupts(s); KernelLog.Ln;
				END;

				IF s * StsAsyncAdvance # {} THEN hcHandshake := TRUE; END;
				IF s * StsHostSystemError # {} THEN
					 Show("Serious error. Please restart the EHCI driver:");
					 IF SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts)) * StsHcHalted # {} THEN
					 	KernelLog.String(" [HC halted]");
					 	SetState(UsbHcdi.Halted);
					 END;
					 KernelLog.Ln;
				END;
				IF s * StsFrameListRollover # {} THEN END;
				IF s * StsPortChange # {} THEN
					(* TODO: If wake-up, time 20ms, poll PscSuspend... enable HC if necessary*)
					IF statusChangeHandler # NIL THEN  statusChangeHandler(Usbdi.Ok, 0); END;
				END;
				IF (s * (StsUsbError + StsUsbInterrupt) # {}) OR (19 IN s) THEN (* USB Interrupt occured: can be IOC or ShortPacketInt *)
					NotifyCompletionHandlers;
				END;
			END;
		END DoHandleInterrupt;

		(* re-evaluate the status of the pipe's qh (endpoint descriptor) and its TD list *)
		PROCEDURE UpdatePipeStatus * (pipe : UsbHcdi.Pipe);
		BEGIN
			CASE pipe.type OF
				 UsbHcdi.PipeControl, UsbHcdi.PipeBulk, UsbHcdi.PipeInterrupt:
					UpdatePipeStatusAsync(pipe)
				|UsbHcdi.PipeIsochronous:
					UpdatePipeStatusIso(pipe)
			ELSE
				(* Unknown pipe type *)
				HALT(8)
			END
		END UpdatePipeStatus;

		PROCEDURE UpdatePipeStatusAsync (pipe: UsbHcdi.Pipe);
		CONST
			MaxLoops = 10000;
		VAR
			qh: Qh;
			after, before, qtd: Qtd;
			transfer: UsbHcdi.TransferToken;
			s, errors: SET;
			i, restLen, len: LONGINT;
			loop: LONGINT;
			active: BOOLEAN;
		BEGIN {EXCLUSIVE}
			FlushPCI;
			(* First look up active bit in the QH tranfer overlay *)
			qh := pipe.descriptors[0];
			(*Machine.InvalidateDCacheRange(qh, sizeQh);*)
			(*s := SYSTEM.VAL(SET, qh.token);
			(*ShowQueueHead(qh, 0, cap64bit); Wait(100);*)
			IF (s * TdActive # {}) & (s * (TdHalted + TdDataBufferError + TdBabbleDetected + TdTransactionError + TdMissedMicroFrame) = {}) THEN
				(* The HC hasn't yet executed the transaction *)
				RETURN
			END;*)
			(*!
				Disabling scheduling here leads to problems: some of the transfers does not get finished!
			*)
			(*REPEAT UNTIL (SYSTEM.VAL(SET, qh.token) * TdActive = {}) OR (SYSTEM.GET32(iobase + HcAsyncListAddr) # qh);*)
			(*qh.token := SYSTEM.VAL(LONGINT, s - TdActive);*)

			(*ASSERT(pipe.transferLock # NIL);*)
			(*pipe.transferLock.Acquire;*)
			transfer := pipe.transfers;
			WHILE transfer # NIL DO
				errors := UsbHcdi.NoErrors;
				active := FALSE;
				IF transfer.status = Usbdi.InProgress THEN
					i := -1;
					WHILE transfer.tds[i + 1] # 0 DO INC(i) END;
					ASSERT(i >= 0);
					qtd := transfer.tds[i];
					IF SYSTEM.VAL(SET, qtd.token) * TdActive # {} THEN
						i := 0;
						(* Examine only transfers that are in progress *)
						WHILE (i < LEN(transfer.tds)) & (transfer.tds[i] # 0) & ~active & (errors = UsbHcdi.NoErrors) DO
							qtd := transfer.tds[i];
							AssertAlignment(qtd, alignQtd);
							(*Machine.InvalidateDCacheRange(qtd, sizeQtd);*)

							s := SYSTEM.VAL(SET, qtd.token) * QtdStatus - TdPingState - TdSplitTransactionState;
							IF s * TdActive # {} THEN
								(* qTD is still active, no errors so far: skip to next transfer *)
								active := TRUE
							END;
							(* At least one error occured *)
							IF s * TdHalted # {} THEN errors := errors + UsbHcdi.Stalled; END;
							IF s * TdDataBufferError # {} THEN errors := errors + UsbHcdi.Databuffer; END;
							IF s * TdBabbleDetected # {} THEN errors := errors + UsbHcdi.Babble; END;
							IF s * TdTransactionError # {} THEN errors := errors + UsbHcdi.CrcTimeout; END;
							IF s * TdMissedMicroFrame # {} THEN errors := errors + UsbHcdi.Internal; END;

							IF ~active & (transfer.len > 0) THEN
								(* Data had to be transfered... *)
								(* The host controller decrements the Total Bytes To Transfer field according the amount of data it did
								transfer. If this field has not the value zero, the host controller did not transfer all data. If there is no
								error reported, this is a short packet condition, which can be okay. *)

								(* len bytes should have been transfered for this TD *)
								len := SYSTEM.VAL(LONGINT, LSH(SYSTEM.VAL(SET, qtd.token) * QtdBytesToTransfer, -16));

								IF (len # 0) THEN (* Short packet *)
									restLen := restLen + len;
								END
							END;
							INC(i)
						END
					END;

					IF active THEN
						(* no update for this transfer: still active *)
					ELSE
						transfer.errors := errors;
						IF errors # UsbHcdi.NoErrors THEN
							transfer.transfered := transfer.len - restLen;
							IF errors * UsbHcdi.Stalled # {} THEN
								transfer.status := Usbdi.Stalled;
							ELSE
								transfer.status := Usbdi.Error;
							END;
						ELSE
							IF restLen = 0 THEN
								transfer.transfered:= transfer.len;
								transfer.status := Usbdi.Ok;
							ELSE
								transfer.transfered := transfer.len - restLen;
								transfer.status := Usbdi.ShortPacket;
								transfer.errors := transfer.errors + UsbHcdi.ShortPacket;
							END
						END;
						(* transfer finished, unlink its TDs *)
						UnlinkTDs(transfer);
					END
				END;
				(*TRACE(pipe, pipe.transferLock, transfer, transfer.next);*)
				transfer := transfer.next
			END;
			(*pipe.transferLock.ReleaseRead;*)

			(*Machine.InvalidateDCacheRange(pipe.descriptors[0], sizeQh);*)
			s := SYSTEM.VAL(SET, qh.token);
			IF s * TdHalted # {} THEN
				ClearHalt(pipe);
			END;

		END UpdatePipeStatusAsync;

		(*
		PROCEDURE UpdatePipeStatusInterrupt (pipe: UsbHcdi.Pipe);
		VAR
			qh: Qh;
			transfer: UsbHcdi.TransferToken;
			s, errors: SET;
			restLen, len: LONGINT;
			active, error: BOOLEAN;
		BEGIN
			FlushPCI;
			(* First look up active bit in the QH tranfer overlay *)
			qh := pipe.descriptors[0];
			Machine.InvalidateDCacheRange(qh, sizeQh);
			s := SYSTEM.VAL(SET, qh.token);
			(*ShowQueueHead(qh, 0, cap64bit); Wait(1000);*)
			IF s * TdActive # {}  THEN  (* The HC hasn't yet executed the transaction *) RETURN; END;

			errors := UsbHcdi.NoErrors;

			s := SYSTEM.VAL(SET, qh.token) * QtdStatus - TdPingState - TdSplitTransactionState;
			IF s = {} THEN
				(* No errors occured *)
			ELSIF s * TdActive # {} THEN
				(* qTD is still active, no errors so far: skip to next transfer *)
				active := TRUE
			ELSE
				(* At least one error occured *)
				IF s * TdHalted # {} THEN errors := errors + UsbHcdi.Stalled; END;
				IF s * TdDataBufferError # {} THEN errors := errors + UsbHcdi.Databuffer; END;
				IF s * TdBabbleDetected # {} THEN errors := errors + UsbHcdi.Babble; END;
				IF s * TdTransactionError # {} THEN errors := errors + UsbHcdi.CrcTimeout; END;
				IF s * TdMissedMicroFrame # {} THEN errors := errors + UsbHcdi.Internal; END;
				error := TRUE
			END;

			IF ~active & (transfer.len > 0) THEN
				(* Data had to be transfered... *)
				(* The host controller decrements the Total Bytes To Transfer field according the amount of data it did
				transfer. If this field has not the value zero, the host controller did not transfer all data. If there is no
				error reported, this is a short packet condition, which can be okay. *)

				(* len bytes should have been transfered for this TD *)
				len := SYSTEM.VAL(LONGINT, LSH(SYSTEM.VAL(SET, qh.token) * QtdBytesToTransfer, -16));

				IF (len # 0) THEN (* Short packet *)
					restLen := restLen + len;
				END
			END;

			transfer.errors := errors;
			IF error THEN
				transfer.transfered := transfer.len - restLen;
				IF errors * UsbHcdi.Stalled # {} THEN
					transfer.status := Usbdi.Stalled;
				ELSE
					transfer.status := Usbdi.Error;
				END
			ELSE
				IF restLen = 0 THEN
					transfer.transfered:= transfer.len;
					transfer.status := Usbdi.Ok;
				ELSE
					transfer.transfered := transfer.len - restLen;
					transfer.status := Usbdi.ShortPacket;
					transfer.errors := transfer.errors + UsbHcdi.ShortPacket;
				END
			END;
		END UpdatePipeStatusInterrupt;
		*)

		PROCEDURE UpdatePipeStatusIso (pipe: UsbHcdi.Pipe);
		VAR
			transfer: UsbHcdi.TransferToken;
			itd: Itd;
			dword, errors: SET;
			len, tx, totalItd, activeItd: LONGINT;
			active: BOOLEAN;
		BEGIN
			(*ShowFramelist(ADDRESSOF(framelist.data[framelist.base]), framelistSize, LSH(SYSTEM.GET32(iobase + HcFrIndex), -3) MOD framelistSize, TRUE);*)
			(*TRACE('Update acquire Tk Read');*)
			(*pipe.transferLock.AcquireRead;
			framelistLock.Acquire;*)
			transfer := pipe.transfers;
			WHILE (transfer # NIL) DO
				IF transfer.status = Usbdi.InProgress THEN
					errors := {};
					len := 0;
					tx := 0;
					totalItd := 0;
					activeItd := 0;
					active := FALSE;
					(*TRACE('Update acquire FL');*)
					WHILE (totalItd < UsbHcdi.MaxTDs) & (transfer.tds[totalItd] # ADDRESS(0)) (*& (transfer.tds[totalItd] # ADDRESS(1))*) DO
						ASSERT(transfer.tds[totalItd] # ADDRESS(1));
						itd := SYSTEM.GET32(transfer.tds[totalItd]);
						(*(*! TRACE *)KernelLog.Enter; KernelLog.String('Update '); KernelLog.Address(itd); KernelLog.Char(' '); KernelLog.Int(SYSTEM.VAL(ADDRESS, itd) MOD 32, 0);
						KernelLog.Char(' '); KernelLog.Int(SYSTEM.VAL(ADDRESS, itd) DIV 32, 0); KernelLog.Exit;*)
						ASSERT(SYSTEM.VAL(ADDRESS, itd) MOD 32 = 0);
						ASSERT(SYSTEM.VAL(ADDRESS, itd) DIV 32 # 0);
						(*Machine.InvalidateDCacheRange(itd, sizeItd);*)
						FOR tx := 0 TO 7 DO
							dword := SYSTEM.VAL(SET, itd.transactions[tx]);
							IF ItdActive * dword = {} THEN
								(* Transaction finished, examine *)
								errors := errors + dword * ItdTransactionStatus;
								INC(len, LSH(SYSTEM.VAL(LONGINT, dword * ItdTransactionLength), -16));
							ELSE
								active := TRUE;
							END
						END;
						INC(totalItd);
					END;
					(*TRACE('Update release FL');*)
					(*KernelLog.Ln;*)
					IF errors # {} THEN
						(*ShowItd(itd, 8);*)
						IF ItdDataBufferError * errors # {} THEN
							transfer.errors := transfer.errors + UsbHcdi.Databuffer
						END;
						IF ItdBabbleDetected * errors # {} THEN
							transfer.errors := transfer.errors + UsbHcdi.Babble
						END;
						transfer.status := Usbdi.Error;
						IF ItdTransactionError * errors # {} THEN
							transfer.errors := transfer.errors + UsbHcdi.Stalled;
							transfer.status := Usbdi.Stalled
						END;
						BEGIN {EXCLUSIVE}
							UnlinkIso(transfer)
						END
					ELSIF ~active THEN
						IF len = transfer.len THEN
							transfer.transfered := transfer.len;
							transfer.status := Usbdi.Ok
						ELSE
							transfer.transfered := len;
							transfer.status := Usbdi.ShortPacket;
							transfer.errors := pipe.errors + UsbHcdi.ShortPacket;
						END;
						BEGIN {EXCLUSIVE}
							UnlinkIso(transfer)
						END
					ELSE
						(*transfer.transfered := len*)
					END
				END;
				transfer := transfer.next;
			END;
			(*framelistLock.Release;
			pipe.transferLock.ReleaseRead;*)
			(*TRACE('Update release Tk Read');*)
			(*TRACE(activeItd, totalItd)*)
		END UpdatePipeStatusIso;

		(* Reset the host controller. Note: This will NOT assert reset on the USB downstream ports. *)
		PROCEDURE HardwareReset * () : BOOLEAN;
		CONST MaxWaits = 1000; (* Timeout in milliseconds the HC must have completed the reset command *)
		VAR dword : SET; i : LONGINT;
		BEGIN
			(* Host software mustn't reset the host controller when it's running. Stop it and ... *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
			SYSTEM.PUT32(iobase + HcUsbCmd, dword - CmdRunStop); FlushPCI;
			(* ... wait until the HC is halted.*)
			i := 1; dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts));
			WHILE (dword * StsHcHalted = {}) & (i <= MaxWaits) DO
				dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts));
				INC(i); Wait(1);
			END;

			IF dword * StsHcHalted = {} THEN (* HC did not stop *) RETURN FALSE; END;

			(* Do the actual reset operation *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
			SYSTEM.PUT32(iobase + HcUsbCmd, dword + CmdHcReset); FlushPCI;

			(* The host controller should clear the HCRESET bit when it has finished resetting *)
			FOR i := 1 TO MaxWaits DO
				dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
				IF dword * CmdHcReset = {} THEN
					RETURN TRUE;
				END;
				Wait(1);
			END;
			RETURN FALSE;
		END HardwareReset;

		(* HC moves to UsbSuspend state und almost all operational registers are reset.
  		Does not affect the root hub and its downstream ports *)
		PROCEDURE SoftwareReset*() : BOOLEAN;
		BEGIN
			(* TODO: Implement *)
			RETURN FALSE;
		END SoftwareReset;

		(* Initialization of the data structures of the Host Controller Communication Area *)
		PROCEDURE InitFrameList(): BOOLEAN;
		VAR fstn, i, k, j, shift : LONGINT;
		BEGIN
			(* Host controller interface data structures should not cross page-boundaries... 32 byte alignment.
			These queue heads are used as skeleton and never contain any qTDs. *)
			qhlist := UsbHcdi.GetAlignedMemSpace(2048, 4096);
			framelist := UsbHcdi.GetAlignedMemSpace(4096, 4096); (* Must be 4K aligned *)
			framelist := UsbHcdi.GetAlignedMemSpace(1024*1024, 1024*1024); (* Must be 4K aligned *)
			Machine.DisableDCacheRange(ADDRESSOF(framelist.data[framelist.base]), 1024*1024);
			IF capIsoSchedThreshold >= 8 THEN
				framelistOfs := capIsoSchedThreshold MOD 8
			ELSIF capIsoSchedThreshold > 0 THEN
				framelistOfs := 1
			ELSE
				framelistOfs := 0
			END;

			(* Mark all entries of the framelist as invalid *)
			FOR i := 0 TO 1024 - 1 DO
				framelist.data[framelist.base + i] := 1
			END;

			(* Set up QHs. 11 Interrupt QHs and the isochronousQh + fstn *)
			shift := sizeQh DIV 4; ASSERT(sizeQh MOD 4 = 0);
			FOR i := 0 TO 12 DO
				qhlist.data[qhlist.base + i*shift + (QhEpCapabilities1 DIV 4)] := 0;
				qhlist.data[qhlist.base + i*shift + (QhEpCapabilities2 DIV 4)] := 0;
				qhlist.data[qhlist.base + i*shift + (QhQtdToken DIV 4)] := 0;
				qhlist.data[qhlist.base + i*shift + (QhCurrentQtdPointer DIV 4)] := 0;
				qhlist.data[qhlist.base + i*shift + (QhNextQtdPointer DIV 4)] := 1; (* Pointer not valid *)
				qhlist.data[qhlist.base + i*shift + (QhAltNextQtdPointer DIV 4)] := 1; (* Pointer not valid *)
				FOR j := 0 TO 4 DO
					qhlist.data[qhlist.base + i*shift + (QhBufferPointer0 DIV 4) + j] := 0;
				END;
				IF cap64bit THEN
					FOR j := 0 TO 4 DO
						qhlist.data[qhlist.base + i*shift + (QhExtBufferPointer0 DIV 4) + j] := 0;
					END;
				END;
			END;

			(* Addresses of queue heads *)
			NEW(interruptQh);
			FOR i := 0 TO 10 DO interruptQh[i] := Machine.Ensure32BitAddress (ADDRESSOF(qhlist.data[qhlist.base]) + i*sizeQh); END;
			fstn := interruptQh[10] + sizeQh; (* Actually 8 bytes *)
			isochronousQh := fstn + sizeQh;

			FOR i := 10 TO 2 BY -1 DO
				SYSTEM.PUT32(interruptQh[i] + QhHorizontalLinkPointer, interruptQh[i-1] + LSH(QhTypQh, 1));
			END;

			(* Link restore indicator. InterruptQh[1] points to FSTN points to InterruptQh[0] *)
			SYSTEM.PUT32(interruptQh[1] + QhHorizontalLinkPointer, fstn + LSH(QhTypFstn, 1));
			SYSTEM.PUT32(fstn + FstnNormalPathLinkPointer, interruptQh[0] + LSH(QhTypQh, 1));
			SYSTEM.PUT32(fstn + FstnBackPathLinkPointer, QhTerminate); (* Indicates restore indicator *)

			(* Interrupt Qh for 1ms points to isochronousQh *)
			SYSTEM.PUT32(interruptQh[0] + QhHorizontalLinkPointer, isochronousQh + LSH(QhTypQh, 1));
			SYSTEM.PUT32(isochronousQh + QhHorizontalLinkPointer, QhTerminate);

			(* tree structure:
			    interrupt[0]: 1ms    interrupt[1]: 2ms    interrupt[2]: 4ms    interrupt[3]: 8ms    interrupt[4]: 16ms	    interrupt[5]: 32ms  *)

			(* => end of queue 10 points to 9, end of 8 points to 7 , ..., end of 1 points to 0 *)
			(* => if we start at queue 10, then we will pass all others too; if we start at 9 then we will pass all queues < 9, too etc.*)

			(* queue 0 executes 1024x, queue 1 executes 512x, queue 2 executes 256x,  queue 3 executes 128x*)
			(* queue 4 executes 64x, queue 5 executes 32x, queue 6 executes 16x,  queue 7 executes 8x*)
			(* queue 8 executes 4x, queue 9 executes 2x, queue 10 executes 1x *)

			(* What does the following mean? => We count the 1's (starting at lsb) until we pass a zero *)
			(* This count gives the queue number for a given slot *)

			FOR i := 0 TO 1023 DO (* i is slot number, we want to calc the queue number (k) for this slot *)
				k := 0; j := i;
				LOOP
					IF (SYSTEM.VAL(SET, j) * {0}) = {} THEN EXIT; END;
					INC(k); j := j DIV 2;
				END;
				framelist.data[framelist.base + i] := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, interruptQh[k]) + {1});
				(*Machine.FlushDCacheRange(ADDRESSOF(framelist.data[framelist.base]), 4096);*)
			END;
			RETURN TRUE;
		END InitFrameList;

		(* Initializes the host controller and builds up the data structures of the HCCA.
		 * @param iobase I/O base address (virtual, pointing to capability register at offset 0)
		 * @param int Interrupt Line
		 * @return TRUE if initialization succeeded, FALSE otherwise
		 *)
		PROCEDURE Init * (iobase , irq  :  LONGINT) : BOOLEAN;
		VAR
			reg  : LONGINT;
			dword : SET; qword : HUGEINT;
			ignore : BOOLEAN;
			i : LONGINT;
		BEGIN
			IF Debug.Trace & Debug.traceInit THEN KernelLog.String("UsbEhci: Starting host controller initialization..."); KernelLog.Ln; END;
			SELF.iobase := iobase; SELF.irq := irq;
			isHighSpeed := TRUE;  DMAchaining := TRUE; sgListSize := ScatterGatherListSize;

			(* Read in the Host Controller Capability Registers *)
			(* Get and check EHCI revision *)
			reg := SYSTEM.GET16(iobase + HcCapHciVersion);
			IF reg # 0100H THEN
				KernelLog.String("UsbEhci: Revision of EHCI Programming Interface not supported."); KernelLog.Ln;
				RETURN FALSE;
			END;

			(* Get and parse the HC structural parameters register (HCSPARAM) *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcCapSparams));
			capDebugPortNumber := SYSTEM.VAL(LONGINT, LSH(dword * {20..31}, -20));
			IF dword * {16} # {} THEN capPortIndicators := TRUE; ELSE capPortIndicators := FALSE; END;
			capNbrOfCompanionHc := SYSTEM.VAL(LONGINT, LSH(dword * {12..15}, -12));
			capPortsPerCompanion := SYSTEM.VAL(LONGINT, LSH(dword * {8..11}, -8));
			IF dword * {7} # {} THEN capPortRoutingRules := TRUE; ELSE capPortRoutingRules := FALSE; END;
			IF dword * {4} # {} THEN capPortPowerControl := TRUE; ELSE capPortPowerControl := FALSE; END;
			capNbrOfPorts  := SYSTEM.VAL(LONGINT, dword * {0..3});

			(* Get and parse the HC capability parameters register (HCCPARAM) *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcCapCparams));
			capIsoSchedThreshold := SYSTEM.VAL(LONGINT, LSH(dword * {4..7}, -4));
			IF dword * {2} # {} THEN capAsynchSchedPark := TRUE; ELSE capAsynchSchedPark := FALSE; END;
			IF dword * {1} # {} THEN capProgrammableFLG := TRUE; ELSE capProgrammableFLG := FALSE; END;
			IF dword * {0} # {} THEN cap64bit := TRUE; ELSE cap64bit := FALSE; END;
			(* Get the EHCI Extended Capabilities Pointer (EECP) *)
			eecp := SYSTEM.VAL(LONGINT, LSH(SYSTEM.VAL(SET, dword) * {8..15}, - 8));

			(* Get HC companion port route description (60bits, 4bits per port *)
			IF capPortRoutingRules THEN (* HC companion port route description available *)
				qword := SYSTEM.GET32(iobase + HcCapPortroute);
				qword := qword + LSH(SYSTEM.GET32(iobase + HcCapPortroute + 4), 32);
				NEW(hcportroute, 16);
				FOR i := 0 TO 15 DO
					hcportroute[i] := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(qword, -i)) * {0..3});
				END;
			END;

			(* Program the framelist size *)
			IF capProgrammableFLG THEN (* Size of frame list can be programmed... use constant value *)
				(* TODO: Programm it *)
				dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
				dword := dword - CmdFrameListSize - {15};
				SYSTEM.PUT32(iobase + HcUsbCmd, dword);
				framelistSize := 1024;
			ELSE
				framelistSize := 1024 (*LSH(SYSTEM.VAL(LONGINT, dword * {2 .. 3}), -2)*);
				(*IF 15 IN dword THEN INC(framelistSize, 4) END;*)
			END;
			IF Debug.Trace & Debug.traceInit THEN
				KernelLog.String("UsbEhci: Set frame list size to "); KernelLog.Int(framelistSize, 0);
				KernelLog.String(" elements."); KernelLog.Ln;
			END;

			(* Build the emulated hub descriptor *)
			dword := {};
			NEW(hubDescriptor, 8);
			hubDescriptor[0] := CHR(7);
			hubDescriptor[1] := CHR(29H); (* Hub Descriptor *)
			hubDescriptor[2] := CHR(capNbrOfPorts);
			IF capPortPowerControl THEN (* If power control is available, EHCI root hubs always provide per port power control *)
				dword := dword + {0};
			ELSE (* No power switching implemented *)
				dword := dword + {1};
			END;
			dword := dword + {3}; (* EHCI root hubs always provide per port overcurrent protection *)
			IF capPortIndicators THEN (* Port indicator control support available *) dword := dword + {7}; END;
			hubDescriptor[3] := CHR(SYSTEM.VAL(LONGINT, dword));
			hubDescriptor[4] := CHR(0); (* Reserved *)
			hubDescriptor[5] := CHR(10); (* 20ms Power on to power good *)
			hubDescriptor[6] := CHR(0); (* Root hubs don't draw current from the USB *)

			(* The Host Controller Capability Registers are readonly so we don't need further access to them and set
			iobase to the base of the Host Controller Operational Registers *)
			iobase := iobase + SYSTEM.GET8(iobase + HcCapLength);
			SELF.iobase := iobase;

			(* Calculate offset from iobase of the port status/controll register for each port *)
			portCount := capNbrOfPorts;
			NEW(ports, portCount);
			FOR i := 0 TO portCount - 1 DO ports[i] := iobase + HcPortSc + i*4; END;

			IF ~HardwareReset() THEN RETURN FALSE; END;

			(* Bluebottle does not yet support 64bit address space. Set the 4GB segment selector for the control data structures to zero. *)
			SYSTEM.PUT32(iobase + HcCtrlDsSegment, 0);

			(* Note that the control data structures must finally be 32byte aligned. Since they occupy subsequent memory location when
			associated with pipes, the value are rounded up to the next value for which value MOD 32 = 0 holds. *)
			IF cap64bit THEN
				sizeQh := 96; (* Actually: 68 Bytes *)
				sizeQtd := 64; (* Actually: 52 Bytes *)
				sizeItd := 96;
				(*alignQh := 128;
				alignQtd := 64;*)
			ELSE
				sizeQh := 64; (* Actually: 48 Byte *)
				sizeQtd := 32;
				sizeItd := 64;
				(*alignQh := 64;
				alignQtd := 32;*)
			END;
			(* Allocation scheme takes care of 4kB page crossing *)
			alignQh := 32;
			alignQtd := 32;
			alignItd := 32;

			IF ~InitFrameList() THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbEhci: Initialization of HCCA failed."); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			(* If the Asynchronous Schedule Park Mode is not available or not enabled, the host controller must not
			 * execute more than one bus transaction per queue head, per traversal of the asynchronous schedule. If it
			 * is enabled, the host controller may execute Asynchronous Schedule Park Mode Count transaction if the
			 * endpoint belongs to a high-speed device. Results in better bus utilization. *)
			IF capAsynchSchedPark THEN
				ASSERT((HcAsyncParkModeCount >= 0) & (HcAsyncParkModeCount < 4));
				dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
				IF HcAsyncParkModeCount = 0 THEN (* Disable Asynchronous Schedule Park Mode *)
					dword := dword - CmdAsyncSchedParkMode;
				ELSE (* Enable Asynchronous Schedule Park Mode and set its count field in USBCMD *)
					dword := dword + LSH(SYSTEM.VAL(SET, HcAsyncParkModeCount), 8) * CmdAsyncSchedParkCount;
					dword := dword + CmdAsyncSchedParkMode;
				END;
				SYSTEM.PUT32(iobase + HcUsbCmd, dword);
			END;

			(* Set interrupt threshold *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
			dword := dword - {16 .. 23};
			IF ((HcInterruptThreshold#01H) & (HcInterruptThreshold#02H) & (HcInterruptThreshold#04H) & (HcInterruptThreshold#08H)
			    & (HcInterruptThreshold#10H) & (HcInterruptThreshold#20H) & (HcInterruptThreshold#40H)) THEN
				(* Wrong parameter value... use default *)
				IF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbEhci: Interrupt Threshold value invalid... using default setting."); KernelLog.Ln; END;
				dword := dword + SYSTEM.VAL(SET, LSH(08H, 16)) * {16..23};
			ELSE
				dword := dword + SYSTEM.VAL(SET, LSH(HcInterruptThreshold, 16)) *  {16..23};
			END;
			SYSTEM.PUT32(iobase + HcUsbCmd, dword); FlushPCI;

			(* Try to start the host controller *)
			IF Start() = FALSE THEN (* ERROR: Couldn't start the host controller. Controller was probably not correctly initialized. *)
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbEhci: Couldn't start host controller."); KernelLog.Ln; END;
				ignore := HardwareReset();
				RETURN FALSE;
			END;

			RETURN TRUE;
		END Init;

		(* PCI writes may be posted. A read forces posted writes to be flushed before the read transaction is proceeded. *)
		PROCEDURE FlushPCI *;
		VAR ignore : LONGINT;
		BEGIN
			ignore := SYSTEM.GET32(iobase + HcUsbSts);
		END FlushPCI;

		(* Release the HC ownership semaphore; eecp is the EHCI Extended Capability Pointer *)
		PROCEDURE ReleaseHcOwnerShip(bus, device, function, eecp : LONGINT);
		END ReleaseHcOwnerShip;

		(*
		 * Start the host controller.
		 * This will:
		 * - enable interrupts for the host controller and install a interrupt handler
		 * - set the addresses for the periodic and asynchronous lists
		 * - turn the host controller on
		 * - route all ports to the EHCI controller
		 * - power on all ports of the root hub
	  	 *)
		PROCEDURE Start * ():BOOLEAN;
		VAR dword : SET;
		TYPE
			IRQPoller = OBJECT (* support polling i/o IRQ -- for testing *)
				VAR handler: PROCEDURE {DELEGATE}; timer: Kernel.Timer;

				PROCEDURE & Init* (h: PROCEDURE {DELEGATE});
				BEGIN
					handler := h;
					NEW(timer);
				END Init;

			BEGIN{ACTIVE}
				LOOP
					handler();
					timer.Sleep(100);
				END;
			END IRQPoller;
		VAR is: IRQPoller;
		BEGIN
			IF Debug.Trace & Debug.traceInit THEN KernelLog.String("UsbEhci: Starting host controller... "); KernelLog.Ln; END;
			(* Enable Interrupts *)

			IF Polling THEN
				NEW(is, InterruptHandler)
			ELSE
			END;
			Objects.InstallHandler(InterruptHandler, Machine.IRQ0+irq);

			(* Clear interrupts *)
			SYSTEM.PUT32(iobase + HcUsbSts, 0);

			(* Enable all interrupts except the frame list rollover interrupt *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbIntr));
			interruptsEnabled := dword + {0..5}  - StsFrameListRollover;
			SYSTEM.PUT32(iobase + HcUsbIntr, interruptsEnabled);

			(* Set Addresses for queue heads *)
			SYSTEM.PUT32(iobase + HcPeriodicListBase, ADDRESSOF(framelist.data[framelist.base]));
			SYSTEM.PUT32(iobase + HcAsyncListAddr, 0); (* Invalid address -> list empty *)

			(* Start controller *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
			dword := dword + CmdRunStop;
			SYSTEM.PUT32(iobase + HcUsbCmd, dword); FlushPCI;
			SetState(UsbHcdi.Operational);

			(* Route all ports to this EHCI host controller *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcConfigFlag));
			dword := dword + {0};
			SYSTEM.PUT32(iobase + HcConfigFlag, dword); FlushPCI;

			SetState(UsbHcdi.Initialized);
			RETURN TRUE;
		END Start;

		PROCEDURE &Default*(bus, device, function : LONGINT);
		BEGIN
			Default^(bus, device, function); (* The high-speed default pipe uses 64byte maxPacketSize0 *)
			pipes[0, 0, 0].maxPacketSize := 64;
			NEW(allocator, 4096, 32);
			NEW(framelistLock);
			NEW(handler, SELF)
		END Default;

		PROCEDURE Cleanup;
		BEGIN
			IF state >= UsbHcdi.Initialized THEN Objects.RemoveHandler(InterruptHandler, Machine.IRQ0 + irq); END;
			Cleanup^;
			IF ~HardwareReset() THEN
				IF Debug.Level >= Debug.Errors THEN Show("Host controller reset failed."); KernelLog.Ln; END;
			END;
			(* Release ownership of host controller *)
			ReleaseHcOwnerShip(bus, device, function, eecp);
			(* Unmap the HC's operational registers *)
			Machine.UnmapPhysical(iobase, 4096);
			handler.Stop
		END Cleanup;

		(** Displays the host controller's data struture on KernelLog *)
		PROCEDURE ShowSchedule*;
		CONST MaxIterations =21;
		VAR dword : SET; first, cur : LONGINT; i, ms : LONGINT;
		BEGIN
			IF Debug.Trace THEN
				KernelLog.String("Host Controller Data Structures for ");
				KernelLog.String(name);
				KernelLog.String(" ("); KernelLog.String(desc); KernelLog.String("):"); KernelLog.Ln;
				KernelLog.String("Periodic Schedule: "); KernelLog.Ln;
				IF SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts)) * StsPeriodicSchedule = {} THEN
					KernelLog.String("Periodic schedule is disabled."); KernelLog.Ln;
				END;

				KernelLog.String("*** Isochronous schedule: "); KernelLog.Ln;
				IF SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts)) * StsPeriodicSchedule # {} THEN
					ShowFramelist(ADDRESSOF(framelist.data[framelist.base]), framelistSize, LSH(SYSTEM.GET32(iobase + HcFrIndex), -3) MOD framelistSize, TRUE)
				ELSE
					KernelLog.String("Periodic schedule is not enabled"); KernelLog.Ln
				END;

				KernelLog.String("*** Asynchronous list: "); KernelLog.Ln;
				IF SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts)) * StsAsyncSchedule # {} THEN
					first := SYSTEM.GET32(iobase + HcAsyncListAddr);
					IF (SYSTEM.VAL(SET, first) * {0..4} = {}) & (first # 0) THEN
						first := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, first) * {5..31});
						ShowQueueHead(first, 0, cap64bit);
						i := 0; cur := first;
						LOOP
							cur := SYSTEM.GET32(cur + QhHorizontalLinkPointer);
							IF (SYSTEM.VAL(SET, cur) * {2..4} # {}) OR (SYSTEM.VAL(SET, cur) * {1} = {}) THEN
								KernelLog.String("Error: Queue head horizontal link pointer is invalid."); KernelLog.Ln;
								EXIT;
							END;
							cur := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, cur) * {5..31});
							IF (cur = first) OR (i >= MaxIterations) THEN EXIT END;

							ShowQueueHead(cur, 0, cap64bit);
							INC(i);
						END;
						IF i >= MaxIterations THEN
							KernelLog.String("MaxIterations reached. Aborting..."); KernelLog.Ln;
						END;
					ELSE KernelLog.String("Error: Asynchronous Schedule List address is invalid.");
					END;
				ELSE KernelLog.String("Asynchronous Schedule is disabled.");
				END;
				KernelLog.Ln;
			END;
		END ShowSchedule;

		PROCEDURE ShowPipe*(pipe : UsbHcdi.Pipe);
		VAR
			qh: Qh;
		BEGIN
			IF pipe.descriptors # NIL THEN
				qh := SYSTEM.VAL(Qh, pipe.descriptors[0]);
				IF (qh.next # 0) & (SYSTEM.VAL(SET, qh.next) * QhTerminate = {}) THEN
					KernelLog.String("QH and qTD link:"); KernelLog.Ln;
					ShowQueueHead(qh, qh.next, cap64bit)
				ELSIF (qh.current # 0) & (SYSTEM.VAL(SET, qh.current) * QhTerminate = {}) THEN
					KernelLog.String("QH and current qTD:"); KernelLog.Ln;
					ShowQueueHead(qh, qh.current, cap64bit)
				ELSE
					KernelLog.String("QH with no scheduled qTD:"); KernelLog.Ln;
					ShowQueueHead(qh, 0, cap64bit)
				END
			END
		END ShowPipe;

		(* Show some information on this host controller on KernelLog *)
		PROCEDURE Diag;
		VAR dword : SET;
		BEGIN
			IF Debug.Trace THEN
			Diag^;
			(* Host Controller structural capabilities *)
			KernelLog.String("  HC Structural Parameters: "); KernelLog.Ln;
			KernelLog.String("    Nbr of ports: "); KernelLog.Int(capNbrOfPorts, 0);
			KernelLog.String(", Debug port: ");
			IF capDebugPortNumber # 0 THEN KernelLog.Int(capDebugPortNumber, 0); ELSE KernelLog.String("n/a"); END;
			KernelLog.Ln;
			KernelLog.String("    Per port power control: ");
			IF capPortPowerControl THEN KernelLog.String("Yes"); ELSE KernelLog.String("No"); END;
			KernelLog.String(", Port indicator control: ");
			IF capPortIndicators THEN KernelLog.String("Available"); ELSE KernelLog.String("n/a"); END;
			KernelLog.Ln;
			KernelLog.String("    Nbr of companion HCs: "); KernelLog.Int(capNbrOfCompanionHc, 0);
			KernelLog.String(", Ports per companion: "); KernelLog.Int(capPortsPerCompanion, 0);
			KernelLog.String(", Port routing rules: ");
			IF capPortRoutingRules THEN KernelLog.String("Available"); ELSE KernelLog.String("n/a"); END;
			KernelLog.Ln;
			(* Host Controller capability parameters *)
			KernelLog.String("  HC Capablilty Parameters:"); KernelLog.Ln;
			KernelLog.String("    64bit Data Structures: "); IF cap64bit THEN KernelLog.String("Yes"); ELSE KernelLog.String("No"); END;
			KernelLog.String(", Async Schedule Park Mode support: ");  IF capAsynchSchedPark THEN KernelLog.String("Yes"); ELSE KernelLog.String("No"); END;
			KernelLog.Ln;
			KernelLog.String("    Programmable Frame List Size: "); IF capAsynchSchedPark THEN KernelLog.String("Yes"); ELSE KernelLog.String("No"); END;
			KernelLog.String(", Isochronous Scheduling Threshold: "); KernelLog.Int(capIsoSchedThreshold, 0);
			KernelLog.Ln;
			(* Host Controller Command Register *)
			KernelLog.String("  HC Command Register: "); KernelLog.Ln;
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
			KernelLog.String("    Interrupt Threshold: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * {16..23}, -16)), 0);
			KernelLog.String(", Async Schedule Park Mode: ");
			IF dword * {11} # {} THEN
				KernelLog.String("Enabled ("); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * {8..9}, -8)), 0); KernelLog.Char(")");
			ELSE
				KernelLog.String("Disabled");
			END;
			KernelLog.String(", Frame List Size: ");
			CASE SYSTEM.VAL(LONGINT, LSH(dword * {2..3}, -2)) OF
			 	0: KernelLog.String("1024");
			 	|1: KernelLog.String("512");
			 	|2: KernelLog.String("256");
			 	|3: KernelLog.String("Reserved");
			 END;
			KernelLog.Ln;
			(* Host Controller Status information *)
			KernelLog.String("  HC Status Register:"); KernelLog.Ln;
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts));
			KernelLog.String("      Asynchronous Schedule: ");
			IF dword * StsAsyncSchedule # {} THEN KernelLog.String("Enabled"); ELSE KernelLog.String("Disabled"); END;
			KernelLog.String(", Periodic Schedule: ");
			IF dword * StsPeriodicSchedule # {} THEN KernelLog.String("Enabled"); ELSE KernelLog.String("Disabled"); END;
			KernelLog.String("  ");
			IF dword * StsReclamation # {} THEN KernelLog.String("[Reclamation]"); END;
			IF dword * StsHcHalted # {} THEN KernelLog.String("[HcHalted]"); END;
			KernelLog.Ln;
			KernelLog.String("      Interrupt Status: "); ShowInterrupts(dword); KernelLog.Ln;
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbIntr));
			KernelLog.String("      Interrupts Enabled: "); ShowInterrupts(dword); KernelLog.Ln;
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
			KernelLog.String("    HC operation: ");
			IF dword * {0} # {} THEN KernelLog.String("Running"); ELSE KernelLog.String("Stopped"); END;
			KernelLog.Ln;
			END;
		END Diag;

		PROCEDURE Show * (CONST txt : ARRAY OF CHAR);
		BEGIN
			KernelLog.String("UsbEhci: "); KernelLog.String(name); KernelLog.String(" ("); KernelLog.String(desc); KernelLog.String("): ");
			KernelLog.String(txt);
		END Show;

		PROCEDURE ShowHcFl;
		BEGIN
		 	ShowFramelist(ADDRESSOF(framelist.data[framelist.base]), framelistSize, LSH(SYSTEM.GET32(iobase + HcFrIndex), -3) MOD framelistSize, FALSE)
		 END ShowHcFl;
	END EnhancedHostController;


	Handler = OBJECT
	VAR
		hc: EnhancedHostController;
		handle, active, trapped, next: BOOLEAN;
		interrupts: SET;

		PROCEDURE & Init (hc: EnhancedHostController);
		BEGIN
			SELF.hc := hc;
			active := TRUE
		END Init;

		PROCEDURE Handle (interrupts: SET);
		BEGIN {EXCLUSIVE}
			IF next THEN
				(*KernelLog.Enter; KernelLog.String("HANDLER: merging"); KernelLog.Exit;*)
				SELF.interrupts := SELF.interrupts + interrupts
			ELSE
				IF handle THEN
					(*KernelLog.Enter; KernelLog.String("HANDLER: buffering"); KernelLog.Exit;*)
					next := TRUE
				ELSE
					(*KernelLog.Enter; KernelLog.String("HANDLER: handling"); KernelLog.Exit;*)
					handle := TRUE
				END;
				SELF.interrupts := interrupts
			END;
		END Handle;

		PROCEDURE Stop;
		BEGIN {EXCLUSIVE}
			active := FALSE
		END Stop;

	BEGIN {ACTIVE, SAFE}
		IF trapped THEN
			hc.Show("WARNING: interrupt handler trapped");
			KernelLog.Ln
		END;
		trapped := TRUE;
		handle := FALSE;
		LOOP
			BEGIN {EXCLUSIVE}
				AWAIT(~active OR handle);
				IF ~active THEN EXIT END;
			END;
			hc.DoHandleInterrupt(interrupts);
			BEGIN {EXCLUSIVE}
				(*KernelLog.Enter; KernelLog.String("HANDLER: done -- "); KernelLog.Boolean(handle); KernelLog.String(", "); KernelLog.Boolean(next); KernelLog.Exit;*)
				handle := next;
				next := FALSE
			END;
		END
	END Handler;

PROCEDURE AssertAlignment(desc: ADDRESS; alignment: SIZE);
BEGIN
	ASSERT(desc MOD alignment = 0);
END AssertAlignment;

(**
 * Computes the address of the next 4kB page in the page sequence sgList.
 *
 * Return the physical page of size 4kB which is right after the physical address (adr + size) in the page ranges sgList.
 * idx is the page index of adr in sgList. When returning, idx indexes the sgList entry containing the return value.
 *)
PROCEDURE GetNextPhysicalPage (CONST sgList: ARRAY OF Machine.Range; VAR idx: LONGINT; adr: ADDRESS): ADDRESS;
BEGIN
	IF adr + PageSize - adr MOD PageSize >= sgList[idx].adr + sgList[idx].size THEN
		(* Next Page beginning not in the current range: use the next range *)
		INC(idx);
		ASSERT(idx < LEN(sgList));
		RETURN sgList[idx].adr
	ELSE
		(* Align to next page size *)
		RETURN adr + (-adr) MOD PageSize
	END;
END GetNextPhysicalPage;

PROCEDURE AdvancePhysBuf (CONST sgList: ARRAY OF Machine.Range; VAR idx: LONGINT; adr: ADDRESS; size: LONGINT): ADDRESS;
VAR
	next: LONGINT;
BEGIN
	next := adr + size;
	WHILE next - sgList[idx].adr > sgList[idx].size DO
		(* Range continues into next buffer *)
		DEC(size, sgList[idx].size);
		INC(idx);
		next := sgList[idx].adr + size
	END;
	RETURN next
END AdvancePhysBuf;

PROCEDURE Indent(spaces : LONGINT);
VAR i : LONGINT;
BEGIN
	FOR i := 1 TO spaces DO KernelLog.Char(" "); END;
END Indent;

(*
 * Display a textual representation of a queue head data structure and its associated qTD.
 * @param qh Virtual memory address of queue head
 * @param firstQtd First qTD of this queue. If 0, the qTD chain will not be shown
 *)
PROCEDURE ShowQueueHead(qh, firstQtd : ADDRESS; cap64bit : BOOLEAN);
CONST MaxChainLen = 32;
VAR
	dword : SET;
	val, chainlen : LONGINT;

	PROCEDURE ShowQhTyp(qh : LONGINT);
	BEGIN
		IF Debug.Trace THEN
		val := SYSTEM.VAL(LONGINT, LSH(SYSTEM.VAL(SET, qh) * QhTyp, -1));
		IF val = 0 THEN KernelLog.String("Isochronous Tranfers Desriptor");
		ELSIF val = 1 THEN KernelLog.String("Queue Head");
		ELSIF val = 2 THEN KernelLog.String("Split Transaction Isochronous Transfer Descriptor");
		ELSIF val = 3 THEN KernelLog.String("Frame Span Traversal Node");
		END;
		END;
	END ShowQhTyp;

BEGIN
	IF Debug.Trace THEN
	KernelLog.String("EHCI data structure at "); KernelLog.Address(qh); KernelLog.String(": ");
	ShowQhTyp(qh); KernelLog.String(" ");

	IF qh = 0 THEN KernelLog.String("Error: QH pointer = 0"); KernelLog.Ln;RETURN;
	ELSIF SYSTEM.VAL(SET, qh) * {0..4} # {} THEN KernelLog.String("Error: Not aligned"); KernelLog.Ln; RETURN;
	END;
	KernelLog.Ln;

	KernelLog.String("    Endpoint Capabilities 1: ");
	dword := SYSTEM.VAL(SET, SYSTEM.GET32(qh + QhEpCapabilities1));
	KernelLog.String(" DeviceAddr: "); KernelLog.Int(SYSTEM.VAL(LONGINT, dword * QhDeviceAddress), 0);
	KernelLog.String(", Endpoint: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * QhEndpointNbr, -8)), 0);
	KernelLog.String(", Speed: "); val := SYSTEM.VAL(LONGINT, LSH(dword * QhEndpointSpeed, -12));
	IF val = 0 THEN KernelLog.String("FullSpeed");
	ELSIF val = 1 THEN KernelLog.String("LowSpeed");
	ELSIF val = 2 THEN  KernelLog.String("HighSpeed");
	ELSE KernelLog.String("ERROR: Not set correctly");
	END;
	KernelLog.String(", MaxPacketSize: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * QhMaxPacketLen, -16)), 0);
	KernelLog.String(", NakRL: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * QhNakCountReload, -28)), 0);

	KernelLog.String(", Flags: ");
	IF dword * QhControlEndpointFlag # {} THEN	KernelLog.String("[ControlEp]"); END;
	IF dword * QhDataToggleControl # {} THEN KernelLog.String("[DataToggleControl]"); END;
	IF dword * QhHeadOfReclamation  # {} THEN KernelLog.String("[Head]"); END;
	IF dword * QhInactivate # {} THEN KernelLog.String("[Inactivate]"); END;
	KernelLog.Ln;

	KernelLog.String("    Endpoint Capabilities 2: ");
	dword := SYSTEM.VAL(SET, SYSTEM.GET32(qh + QhEpCapabilities2));
	KernelLog.String("Mult: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * QhMultiplier, -30)), 0);
	KernelLog.String(", HubAddr: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * QhHubAddr, -16)), 0);
	KernelLog.String(", HubPort: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * QhPortNbr, -23)), 0);
	KernelLog.String(", SplitCMask: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * QhSplitCMask, -8)), 0);
	KernelLog.String(", QhSMask: "); KernelLog.Int(SYSTEM.VAL(LONGINT, dword * QhSMask), 0);
	KernelLog.Ln;

	KernelLog.String("    Queue Head Horizontal Link Pointer: ");
	dword := SYSTEM.VAL(SET, SYSTEM.GET32(qh + QhHorizontalLinkPointer));
	IF dword * QhTerminate # {} THEN
		KernelLog.String("Invalid ("); KernelLog.Address(SYSTEM.VAL(LONGINT, dword)); KernelLog.String("H)");
	ELSE
		KernelLog.Address(SYSTEM.VAL(LONGINT, dword * {5..31}));
		KernelLog.String(" ("); ShowQhTyp(SYSTEM.VAL(LONGINT, dword)); KernelLog.String(")");
	END;
	KernelLog.Ln;

	dword := SYSTEM.VAL(SET, SYSTEM.GET32(qh + QhCurrentQtdPointer));
	KernelLog.String("    Current qTD Pointer: "); KernelLog.Address(SYSTEM.VAL(LONGINT, dword));
	KernelLog.String(", Next qTD Pointer: "); KernelLog.Address(SYSTEM.GET32(qh + QhNextQtdPointer));
	KernelLog.Ln;

	KernelLog.String("    Transfer overlay: "); KernelLog.Ln;
	ShowQtd(qh+ QhNextQtdPointer, 8, cap64bit, TRUE); KernelLog.Ln;

	IF firstQtd # 0 THEN (* show qTD chain *)
		KernelLog.String("    qTD chain:"); KernelLog.Ln;
		IF SYSTEM.VAL(SET, firstQtd) * {0..4} # {} THEN
			KernelLog.String("        qTD Pointer not 32byte aligned!"); KernelLog.Ln;
		ELSE
			chainlen := 0;
			WHILE(SYSTEM.VAL(SET, firstQtd) * QhTerminate = {}) & (chainlen < MaxChainLen) DO
				INC(chainlen);
				ShowQtd(firstQtd, 8, cap64bit, FALSE); KernelLog.Ln;
				(* Get next qTD *)
				dword := SYSTEM.VAL(SET, SYSTEM.GET32(firstQtd + QtdNextQtdPointer));
				IF dword * {1..4} # {} THEN
					KernelLog.String("        Alignment error!"); KernelLog.Ln;
					chainlen := MaxChainLen; (* abort *)
				ELSIF dword * QhTerminate # {} THEN
					KernelLog.String("        End of Chain"); KernelLog.Ln;
					chainlen := MaxChainLen; (* abort *)
				ELSE
					firstQtd := SYSTEM.VAL(LONGINT, dword * {5..31});
				END;
			END;
		END;
	END;
	END;
END ShowQueueHead;

PROCEDURE ShowQtd(adr: ADDRESS; spaces: LONGINT; cap64bit, overlay: BOOLEAN);
VAR
	i, val: LONGINT;
	dword: SET;
	qtd: Qtd;
BEGIN
	IF Debug.Trace THEN
		qtd := adr;
		Indent(spaces);
		KernelLog.String("qTD at "); KernelLog.Address(qtd);  KernelLog.String(": ");

		IF SYSTEM.VAL(SET, qtd) * {0..3} # {} THEN
			(* Regular qTDs are 32byte aligned. We allow 16byte alignment for the transfer overlay area *)
			KernelLog.String("Not 16byte aligned... aborting."); KernelLog.Ln; RETURN;
		ELSIF adr = 0 THEN
			KernelLog.String("Address = 0?"); KernelLog.Ln; RETURN;
		END;
		KernelLog.Ln;

		Indent(spaces+ 4);
		KernelLog.String("qTD Token: ");
		dword := SYSTEM.VAL(SET, qtd.token);
		KernelLog.String("Pid: ");
		val := SYSTEM.VAL(LONGINT, LSH(dword * QtdPidCode, -8));
		IF val = PidSetup THEN KernelLog.String("SETUP");
		ELSIF val = PidIn THEN KernelLog.String("IN");
		ELSIF val = PidOut THEN KernelLog.String("OUT");
		ELSE KernelLog.String("PID ERROR!");
		END;

		KernelLog.String(", DataToggle: ");
		IF dword * QtdDataToggle # {} THEN KernelLog.String("DATA1"); ELSE  KernelLog.String("DATA0"); END;

		KernelLog.String(", Bytes to transfer: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * QtdBytesToTransfer, -16)), 0);
		KernelLog.String(", IOC: "); IF dword * QtdIoc # {} THEN KernelLog.String("Yes"); ELSE KernelLog.String("No"); END;
		KernelLog.String(", CERR: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * QtdErrorCounter, -10)) ,0);
		KernelLog.Ln;

		Indent(spaces + 4);
		KernelLog.String("qTD Token Status: ");
		dword := dword * QtdStatus;
		IF dword * TdActive # {} THEN KernelLog.String("[Active]"); END;
		IF dword * TdHalted # {} THEN KernelLog.String("[Halted]"); END;
		IF dword * TdDataBufferError # {} THEN KernelLog.String("[DataBufferError]"); END;
		IF dword * TdBabbleDetected # {} THEN KernelLog.String("[BabbleDetected]"); END;
		IF dword * TdTransactionError # {} THEN KernelLog.String("[TransactionError]"); END;
		IF dword * TdMissedMicroFrame # {} THEN KernelLog.String("[MissedMicroFrame]"); END;
		IF dword * TdSplitTransactionState # {} THEN KernelLog.String("[SplitTransactionState]"); END;
		IF dword * TdPingState # {} THEN KernelLog.String("[PingState]"); END;
		KernelLog.Ln;

		Indent(spaces + 4); KernelLog.String("Buffer information:");KernelLog.Ln;
		Indent(spaces + 8); KernelLog.String("Current Buffer: ");
		KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * QtdCurrentPage, -12)), 0);
		IF SYSTEM.VAL(SET, qtd) * {4} # {} THEN (* Should be transfer overlay since not 32byte aligned *)
			KernelLog.String(", Nak counter: ");
			KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(SYSTEM.VAL(SET, qtd.next) * {1..3}, -1)), 0);
		END;
		KernelLog.Ln;
		FOR i := 0 TO 4 DO
			val := qtd.buffers[i];
			Indent(spaces + 8);
			KernelLog.String("Buffer Pointer "); KernelLog.Int(i, 0); KernelLog.String(": "); KernelLog.Address(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, val) * {12..31}));

			val := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, val) * {0..11});
			IF i = 0 THEN
				KernelLog.String("   Current Offset: "); KernelLog.Hex(val, 8);
			ELSIF overlay & (i = 1) THEN
				KernelLog.String("   C-prog-mask: "); KernelLog.Hex(val, 8);
			ELSIF overlay & (i = 2) THEN
				KernelLog.String("   S-Bytes / Frametag: "); KernelLog.Hex(val, 8);
			END;

			KernelLog.Ln;
		END;

		IF cap64bit THEN
			FOR i := 0 TO 4 DO
				val := qtd.extBuffers[i];
				Indent(spaces + 8);
				KernelLog.String("   ExtBufferPointer"); KernelLog.Int(i, 0); KernelLog.String(": "); KernelLog.Address(val); KernelLog.Ln;
			END;
		END;

		Indent(spaces + 4); KernelLog.String("Alternate Next qTD Pointer: ");
		dword := SYSTEM.VAL(SET, (*SYSTEM.GET32(adr + QtdNextQtdPointer)*) qtd.alternateNext);
		IF dword * QhTerminate # {} THEN
			KernelLog.String("Invalid ("); KernelLog.Address(SYSTEM.VAL(LONGINT, dword)); KernelLog.String(")");
		ELSIF dword * {1..3} # {} THEN
			KernelLog.String("Alignment Error ("); KernelLog.Address(SYSTEM.VAL(LONGINT, dword)); KernelLog.String(")");
		ELSE
			KernelLog.Address(SYSTEM.VAL(LONGINT, dword));
		END;
		KernelLog.Ln;

		(*val := SYSTEM.VAL(ADDRESS, qtd);*)
		Indent(spaces + 4);
		KernelLog.String("Next qTD Pointer: ");
		dword := SYSTEM.VAL(SET, qtd.next);
		(*SYSTEM.GET(SYSTEM.VAL(ADDRESS, qtd) + QtdNextQtdPointer, dword);*)
		IF dword * QhTerminate # {} THEN
			KernelLog.String("Invalid ("); KernelLog.Address(SYSTEM.VAL(LONGINT, dword)); KernelLog.String(")");
			qtd := 0;
		ELSIF dword * {1..3} # {} THEN
			KernelLog.String("Alignment Error ("); KernelLog.Address(SYSTEM.VAL(LONGINT, dword)); KernelLog.String(")");
			qtd := 0;
		ELSE
			KernelLog.Address(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, dword) * {5..31}));
			qtd := SYSTEM.VAL(LONGINT, dword * {5..31});
		END;
		KernelLog.Ln;
	END;
END ShowQtd;

(*
PROCEDURE ShowItd(adr : LONGINT);
VAR dword : SET; i : LONGINT;
BEGIN
	IF Debug.Trace THEN
	KernelLog.String("UsbEhci: ITD at address "); KernelLog.Hex(adr, 8); KernelLog.Ln;
	Indent(4);
	dword := SYSTEM.VAL(SET, SYSTEM.GET32(adr));
	KernelLog.String("Next Link Pointer: "); KernelLog.Hex(SYSTEM.VAL(LONGINT, dword * {5..31}), 8);
	IF dword * {0} = {} THEN KernelLog.String(" [VALID]"); ELSE KernelLog.String("[INVALID]"); END;
	KernelLog.String(", Typ: ");
	CASE SYSTEM.VAL(LONGINT, LSH(dword * {1..2}, -1)) OF
		0: KernelLog.String("iTD");
		|1 : KernelLog.String("QH");
		|2 : KernelLog.String("siTD");
		|3 : KernelLog.String("FSTN");
	END;
	dword := SYSTEM.VAL(SET, SYSTEM.GET32(adr + 24H));
	KernelLog.String(", Device Address: "); KernelLog.Int(SYSTEM.VAL(LONGINT, dword * {0..6}), 0);
	KernelLog.String(", Endpoint: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * {8..11}, -7)), 0);
	dword := SYSTEM.VAL(SET, SYSTEM.GET32(adr + 28H));
	KernelLog.String(" MaxPacket: "); KernelLog.Int(SYSTEM.VAL(LONGINT, dword * {0..10}), 0);
	IF dword * {11} # {} THEN KernelLog.String(" [IN]"); ELSE KernelLog.String(" [OUT]"); END;
	dword := SYSTEM.VAL(SET, SYSTEM.GET32(adr + 2CH));
	KernelLog.String(", MULT: "); KernelLog.Int(SYSTEM.VAL(LONGINT, dword * {0..1}), 0);
	KernelLog.Ln;
	FOR i := 0 TO 7 DO
		Indent(4);
		dword := SYSTEM.VAL(SET, SYSTEM.GET32(adr + (i+1) * 4));
		KernelLog.String("Transaction "); KernelLog.Int(i, 0); KernelLog.String(": ");
		KernelLog.String("Status: ");
		IF dword * ItdStatus # {} THEN
			IF dword * ItdActive # {} THEN KernelLog.String("[ACTIVE]"); END;
			IF dword * ItdDataBufferError # {} THEN KernelLog.String("[DataBufferError]"); END;
			IF dword * ItdBabbleDetected # {} THEN KernelLog.String("[Babble]"); END;
			IF dword * ItdTransactionError # {} THEN KernelLog.String("[TransactionError]"); END;
		ELSE
			KernelLog.String("[Done]");
		END;

		KernelLog.String(" Length: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * {16..27}, -16)), 0);
		KernelLog.String(", PG: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * {12..14}, -12)), 0);
		KernelLog.String(", Offset: "); KernelLog.Int(SYSTEM.VAL(LONGINT, dword * {0..11}), 0);
		IF dword * {15} # {} THEN KernelLog.String(" [IOC]"); END;
		KernelLog.Ln;
	END;
	FOR i := 0 TO 6 DO
		Indent(4);
		dword := SYSTEM.VAL(SET, SYSTEM.GET32(adr + 24H + i*4));
		KernelLog.String("Buffer Pointer Page "); KernelLog.Int(i, 0); KernelLog.String(": ");
		KernelLog.Hex(SYSTEM.VAL(LONGINT, dword * {12..31}), 8);
		KernelLog.Ln;
	END;
	END;
END ShowItd;
*)

PROCEDURE ShowInterrupts * (s : SET);
BEGIN
	IF Debug.Trace THEN
	IF s * StsAsyncAdvance # {} THEN KernelLog.String("[AsyncAdvance]"); END;
	IF s * StsHostSystemError # {} THEN KernelLog.String("[HostSystemError]"); END;
	IF s * StsFrameListRollover # {} THEN KernelLog.String("[FrameListRollover]"); END;
	IF s * StsPortChange # {} THEN KernelLog.String("[PortChange]"); END;
	IF s * StsUsbError # {} THEN KernelLog.String("[UsbError]"); END;
	IF s * StsUsbInterrupt # {} THEN KernelLog.String("[UsbInterrupt]"); END;
	END;
END ShowInterrupts;

PROCEDURE ShowItd (adr: ADDRESS; space: LONGINT);
VAR
	dword: SET;
	i: LONGINT;
BEGIN
	IF Debug.Trace THEN
		Indent(space);
		IF adr = 0 THEN
			KernelLog.String("UsbEhci: iTD at address 0, invalid address, aborting");
			KernelLog.Ln;
			RETURN
		END;
		KernelLog.String("UsbEhci: iTD at address "); KernelLog.Address(adr); KernelLog.Ln;

		dword := SYSTEM.VAL(SET, SYSTEM.GET32(adr + ItdNextLinkPointer));
		Indent(space + 4);
		KernelLog.String("Next Link Pointer: "); KernelLog.Address(SYSTEM.VAL(ADDRESS, dword));
		IF 0 IN dword THEN KernelLog.String(" [INVALID]") END;
		KernelLog.String(", Type: ");
		CASE SYSTEM.VAL(LONGINT, dword * {1 .. 2}) DIV 2 OF
			 0: KernelLog.String("iTD")
			|1: KernelLog.String("QH")
			|2: KernelLog.String("siTD")
			|3: KernelLog.String("FSTN")
		END;
		KernelLog.Ln;

		FOR i := 0 TO 7 DO
			Indent(space + 4);
			KernelLog.String("Transaction "); KernelLog.Int(i, 0); KernelLog.String(": ");

			dword := SYSTEM.VAL(SET, SYSTEM.GET32(adr + ItdTransaction0 + 4 * i));
			KernelLog.String("TX Length "); KernelLog.Int(SYSTEM.VAL(LONGINT, dword * {16 .. 27}) DIV 10000H, 0);
			KernelLog.String(", Page select "); KernelLog.Int(SYSTEM.VAL(LONGINT, dword * {12 .. 14}) DIV	1000H, 0);
			KernelLog.String(", Tx offset "); KernelLog.Int(SYSTEM.VAL(LONGINT, dword * {0 .. 11}), 0);
			IF 15 IN dword THEN KernelLog.String(" [IOC]") END;

			IF 30 IN dword THEN KernelLog.String(" [DATA BUFFER ERROR]") END;
			IF 29 IN dword THEN KernelLog.String(" [BABBLE]") END;
			IF 28 IN dword THEN KernelLog.String(" [ERROR]") END;
			IF 31 IN dword THEN KernelLog.String(" [ACTIVE]") ELSE KernelLog.String(" [INACTIVE]") END;
			KernelLog.Ln
		END;

		Indent(space + 4);
		KernelLog.String("Buffer pointer 0: ");
		dword := SYSTEM.VAL(SET, SYSTEM.GET32(adr + ItdBufferPtr0));
		KernelLog.String(" address "); KernelLog.Address(SYSTEM.VAL(ADDRESS, dword * {12 .. 31}));
		KernelLog.String(", endpoint "); KernelLog.Int(SYSTEM.VAL(LONGINT, dword * {8 .. 11}) DIV 100H, 0);
		KernelLog.String(", dev address "); KernelLog.Int(SYSTEM.VAL(LONGINT, dword * {0 .. 6}), 0);
		KernelLog.Ln;

		Indent(space + 4);
		KernelLog.String("Buffer pointer 1: ");
		dword := SYSTEM.VAL(SET, SYSTEM.GET32(adr + ItdBufferPtr1));
		KernelLog.String(" address "); KernelLog.Address(SYSTEM.VAL(ADDRESS, dword * {12 .. 31}));
		KernelLog.String(", max packet size "); KernelLog.Int(SYSTEM.VAL(LONGINT, dword * {0 .. 10}), 0);
		IF 11 IN dword THEN KernelLog.String(" [IN]") ELSE KernelLog.String(" [OUT]") END;
		KernelLog.Ln;

		Indent(space + 4);
		KernelLog.String("Buffer pointer 2: ");
		dword := SYSTEM.VAL(SET, SYSTEM.GET32(adr + ItdBufferPtr2));
		KernelLog.String(" address "); KernelLog.Address(SYSTEM.VAL(ADDRESS, dword * {12 .. 31}));
		KernelLog.String(", multi "); KernelLog.Int(SYSTEM.VAL(LONGINT, dword * {0 .. 1}), 0); KernelLog.String("x");
		KernelLog.Ln;

		FOR i := 3 TO 6 DO
			Indent(space + 4);
			KernelLog.String("Buffer pointer "); KernelLog.Int(i, 0); KernelLog.String(": ");
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(adr + ItdBufferPtr0 + 4 * i));
			KernelLog.String(" address "); KernelLog.Address(SYSTEM.VAL(ADDRESS, dword * {12 .. 31}));
			KernelLog.Ln
		END
	END
END ShowItd;

(** Prints the Framelist and its content. 'framelist' is the base address of the framelist, 'size' is the number of elements in the framelist. If 'expand's is TRUE, ITDs and QHs are also shown. *)
PROCEDURE ShowFramelist (framelist: ADDRESS; size, hc: LONGINT; expand: BOOLEAN);
VAR
	i, entry: LONGINT;
BEGIN
	FOR i := 0 TO size - 1 DO
		entry := SYSTEM.GET32(framelist + 4 * i);
		KernelLog.String("Frame entry "); KernelLog.Int(i, 4);
		KernelLog.String(" at "); KernelLog.Address(framelist + 4 * i);
		KernelLog.String(":	"); KernelLog.Hex(entry, -8);
		IF (hc # -1) & (i = hc) THEN KernelLog.String(" <- HC") END;
		KernelLog.Ln;
		IF expand & ~ODD(entry) THEN
			ShowItd(entry, 4)
		END
	END;
END ShowFramelist;

(**
 * Helper procedure to build a QH horizontal link field.
 * Creates a horizontal link pointer field pointing to 'qh', with type 'type'.
 * Link is marked as invalid if terminate is TRUE.
 *)
PROCEDURE QhHorizontalLink (qh: ADDRESS; type: LONGINT; terminate: BOOLEAN): LONGINT;
VAR
	dword: SET;
BEGIN
	IF terminate THEN
		dword := QhTerminate
	END;
	dword := dword + SYSTEM.VAL(SET, qh) + SYSTEM.VAL(SET, LSH(type, 1));
	RETURN SYSTEM.VAL(LONGINT, dword)
END QhHorizontalLink;

(* Called when this module is unloaded. Unregister all EnhancedHostController objects *)
PROCEDURE Cleanup;
BEGIN
	UsbHcdi.UnRegisterHostControllers(Description);
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END UsbEhci.

UsbEhci.Install ~  System.Free UsbEhci ~
