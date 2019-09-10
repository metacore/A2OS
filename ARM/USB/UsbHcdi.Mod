MODULE UsbHcdi; (** AUTHOR "staubesv"; PURPOSE "USB Host Controller Driver Interface (HCDI)" *)
(**
 * Bluebottle USB Host Controller Driver Interface
 *
 * This is the hardware abstraction layer which enables the USB Bus Driver / Hub Driver to handle all USB Host Controller
 * in a unique way.
 *
 * Overview:
 *
 *	HcdInterface	Interface of the hardware-specific operations to be implemented by specific USB Host Controller drivers
 *	Hcd(Interface)	Implementation of hardware-independent functionality common to all USB Host Controllers
 *	TransferToken	Generic representation of a USB data transfer. Used as interface between pipes and host controller drivers
 *	Pipe			Implementation of logical communication channel between client software (i.e. device driver) and a device
 *					endpoint.
 *
 * USB host controllers are controlled by operational registers and the host controller communication area in system memory.
 *
 * In the general design of the USB stack, device drivers use Pipe objects to communicate with a device. The Pipe in turn calls the
 * host controller driver to schedule the USB transfer. This module implements the interface layer between a Pipe object and an
 * HCD (host controller driver) object. The main concept of this interface is the TransferToken record, which generically represents
 * transfers.
 *
 * For USB communication, a HCD presents 3 procedures:
 *		- Schedule				execute a transfer
 *		- Cancel				cancel a pending transfer
 *		- UpdatePipeStatus	update status for all transfers of a pipe
 *
 * 3 more procedures are used for bookkeeping related to transfers:
 *		- RegisterPipe			register a pipe to the host controller. A pipe cannot transfer data before being registered
 *		- UnregisterPipe		unregister a pipe from the host controller. A pipe cannot transfer data after being deregistered
 *		- CheckPipePolicy		validates the policy of an isochronous pipe. An isochronous pipe cannot transfer data before its policy being validated
 *
 * History:
 *
 *	24.11.2005	History started (staubesv)
 *	29.11.2005	Introduced Notifier object and moved corresponding code from HC drivers to Hcd (staubesv)
 *	12.12.2005	More options for HcdManager.Show, use exception handling for critical calls (staubesv)
 *	13.12.2005	Fixed critical bug in RemoveQH, some cleanup (staubesv)
 *	15.12.2005	Added pipe.CheckBuffer, removed Pipe.pid field (staubesv)
 *	06.01.2006	Check whether USB device has been disconnected in Pipe transfer routines (staubesv)
 *	09.01.2006	Added TraceControlData trace option (staubesv)
 *	11.01.2006	Removed Hcd.GetPortCount, Hcd.RestartPipe, Pipe.Restart (staubesv)
 *	12.01.2006	Implemented software scatter/gather mechanism for pipes (staubesv)
 *	12.01.2006	Implemented transfer completion notification via interrupts (staubesv)
 *	16.01.2006	Bugfix: Pipe.Clearhalt request must use endpoint address instead of endpoint number (staubesv)
 *	17.01.2006	Use less memory for the TD buffer of the default pipe (staubesv)
 *	24.01.2006	Removed offset parameter for control transfer buffer (staubesv)
 *	25.01.2006	Unified Pipe.ControlTranfer & Pipe.Transfer, introduced TransferCompletion object (staubesv)
 *	26.01.2006	Don't return failure codes in Hcd.GetPipe, just NIL if allocation fails (staubesv)
 *	01.02.2006	Removed HcdManager, use Plugins mechanis instead (staubesv)
 *	01.03.2006	Fixed broken control out transfers (staubesv)
 *	28.06.2006	Removed procedure PrintHex (use KernelLog.Hex instead),
 *				fixed UnRegisterHostControllers so it only removes the Controllers with the provided description (staubesv)
 *	03.06.2006	HcdInterface.UpdatePipe removed (staubesv)
 *	03.08.2006	Introduced HcdInterface.LinkTDsAllowed procedure (staubesv)
 *	05.01.2007	Separatly trace shortpackets/other errors, each pipe has now a own thread that's used to call its completion handler (staubesv)
 *	XX.04.2015	Introduced TransferToken as the interface between Pipe and HCD (tmartiel)
 *	XX.06.2015	Moved all scatter-gather management to actual HCD implementations (tmartiel)
 * TODOs:
 *	- nicer design of pipes (message pipe / stream pipe)
 *	- move pipes in separate module?
 *	- Should control transfers also use IOC completion? No.
 * 	- Timeout handling: Fix: Transfer could still complete when a timeout occurs
 *)

IMPORT SYSTEM, KernelLog, Machine, Plugins, Modules, Kernel, Objects, Locks, UsbBuffers, Usbdi, Debug := UsbDebug;

CONST

	(** Bluebottle specific hub port status bits. Not all (root) hubs do support all of the possible status bits *)
	PortStatusDevicePresent* = {0}; 			(** USB device is attached to the port (only visible when port is powered) *)
	PortStatusEnabled* = {1}; 				(** The port is enabled *)
	PortStatusLowSpeed* = {2}; 				(** Connected device is a low-speed device *)
	PortStatusFullSpeed* = {3}; 				(** Connected device is a full-speed device *)
	PortStatusHighSpeed* = {4}; 			(** Connected device is a high-speed device *)
	PortStatusReset* = {5}; 					(** The port is current resetting *)
	PortStatusError* = {6}; 					(** The status request failed. *)
	PortStatusConnectChange* = {7};		(** The connection status of the port has changed *)
	PortStatusSuspended* = {8}; 			(** The port is suspended *)
	PortStatusOverCurrent* = {9}; 			(** There is an overcurrent condition on this port *)
	PortStatusPowered* = {10}; 				(** The port is powered *)
	PortStatusEnabledChange* = {11}; 		(** The enabled/disabled status has changed *)
	PortStatusSuspendChange* = {12}; 		(** The suspended status has changed *)
	PortStatusOverCurrentChange* = {13}; 	(** The overcurrent status has changed *)
	PortStatusResetChange* = {14}; 			(** The reset status has changed *)
	PortStatusWakeOnOvercurrent* = {15}; 	(** Overcurrent conditions are a wake-up event *)
	PortStatusWakeOnDisconnect* = {16}; 	(** Device disconnection is a wake-up event *)
	PortStatusWakeOnConnect* = {17}; 		(** Device connection is a wake-up event *)
	PortStatusTestControl* = {18}; 			(** The port is in test mode *)
	PortStatusIndicatorControl* = {19}; 		(** The port supports control of its status indicator LEDs *)
	PortStatusPortOwner* = {20}; 			(** The port is owned by the high-speed controller (only EHCI HCs) *)

	(** Pipe.errors coding. Gives more detailed transfer completion status than Pipe.status *)
	NoErrors* = {};							(** No errors occured *)
	ShortPacket* = {1};						(** Device transferred less data than requested *)
	Stalled* = {2};							(** Stall condition *)
	InProgress* = {3};						(** Transfer is still in progress (timeout for blocking transfers) *)
	Nak* = {4};								(** [UHCI] Device NAKed transfer *)
	Crc* = {5};								(** [OHCI] CRC error *)
	Timeout* = {6};							(** [OHCI] USB protocol timeout *)
	CrcTimeout* = {7};						(** [UHCI] CRC or Timeout error *)
	BitStuff* = {8};							(** Bitstuffing error *)
	Databuffer* = {9};						(** Databuffer error *)
	Babble* = {10};							(** Babble: Device sent more data than requested -> serious error! *)
	UnexpectedPid* = {13};					(** [OHCI] Unexpected PID *)
	PidCheckFailure* = {15};					(** [OHCI] PID check failure *)
	DataToggleMismatch* = {16};			(** [OHCI] Datatoggle mismatch *)
	DeviceNotResponding* = {17};			(** [OHCI] Device did not respond *)
	(** Pipe.errors HCDI level errors *)
	LinkTDsFailed* = {18};					(** Could not link TDs to QH since there are already linked TDs *)
	OutOfTDs* = {19};						(** No more TDs available for transfer scheduling *)
	Internal* = {11};							(** HCDI level error *)
	TransferTooLarge* = {14};				(** HCDI level error: Transfer is too large, respectively SG list is too small *)
	Disconnected* = {12};					(** Device has been disconnected *)

	(** Coding of ORD(PipePolicy.type) field *)
	PipeControl* =  0;
	PipeIsochronous* = 1;
	PipeBulk* = 2;
	PipeInterrupt* = 3;

	(* Host controller states *)
	Undefined* = 0;
	Initialized* = 1;
	Operational* = 2;
	Suspended* = 3;
	Resuming* = 4;
	Halted* = 5;
	Shutdown* = 6;

	(* USB transfer modes *)
	LowSpeed* = 0;
	FullSpeed* = 1;
	HighSpeed* = 2;

	(** Direction field for control transfers / pipes *)
	In* = 0;		(* Device-to-Host *)
	Out* = 1;	(* Host-to-Device *)

	(** HcCapabilities powerSwitching, overCurrentDetection field values *)
	NotAvailable* = 0; (* MUST be 0 *)
	Global* = 1; (* MUST be 1 *)
	PerPort* = 2; (* MUST be 2 *)

	(* Port indicator colors. Don't change values! *)
	Automatic* = 0;
	Amber* = 1;
	Green* = 2;
	Off* = 3;

	(** Timing [milliseconds] *)
	PortResetTime* = 10 + 20; (* "The duration of the Resetting state is nominally 10 ms to 20 ms (10 ms is preferred)", USB2.0spec Chapter 11.5.1.5 *)

	(** After a port reset, the hub should enable the port within this time *)
	PortEnableTimeout* = 20;  (* ms *)

	 (* Wait for at least 100ms to allow completion of insertion process and for power at the device to become stable. USB 2.0spec Chapter 9.1.2 *)
	PortInsertionTime* = 100 + 50;

	(* SetAddress recovery interval of 2ms, USB2.0spec Chapter 9.2.6.3 *)
	AddressRecoveryTime* = 2 + 10;

	(* Minimum time the root hub must assert the reset signal on its downstream ports *)
	RootHubResetTime* = 100; (* >= 50 ms, USB2.0spec, p. 282  *)

	(* Minimum time the HC must stay in suspend state once entered *)
	MinSuspendTime* = 8; (* >= 5ms, OHCI specification p. 44 *)

	StateDisconnected* = -1; (* MUST be equal to Usb.StateDisconnected *)

	(** Max number of TDs per transfer *)
	MaxTDs* = 1024;

TYPE

	(** Aligned memory space. Use data[base] as first entry. *)
	AlignedMemSpace* = POINTER TO RECORD
		data- : POINTER TO ARRAY OF SIGNED32;
		base- : ADDRESS;
	END;

	(** Emulated hub descriptor for supporting root hub emulation *)
	HubDescriptor* = POINTER TO ARRAY OF CHAR;

	(* Used for reporting root hub status and root hub port status changes *)
	StatusChangeHandler* = PROCEDURE {DELEGATE} (status : Usbdi.Status; actLen : SIGNED32);

	(* Packet for message pipe transfers *)
	ControlMessage* = (*RECORD ofs*: SIGNED32; value*: POINTER TO ARRAY 8 + 32 OF CHAR; END;*) Usbdi.BufferPtr;

TYPE

	(* The HcdInterface defines the interface that must be implemented by the Host Controller Drivers *)
	HcdInterface = OBJECT(Plugins.Plugin)

		(** Root Hub Control *)

		(* Port numbers: 0.. nbrOfPorts-1 *)

		(**
		 * Enable power for the specified port.
		 * It is the hub driver that is responsible for waiting the PwrOn2PwrGood time after enabling a port.
		 * The actual result is depending on the kind of power switching the root hub implements:
		 * - Per port: Enable power for the specified port
		 * - Ganged: One call will enable power for all ports, independent on the specified port number
		 * - None: The hub driver will not call this procedure
		 * @param port Port to enable power for
		 *)
		PROCEDURE EnablePortPower*(port : SIGNED32);
		BEGIN HALT(301); END EnablePortPower;

		(**
		 * Disable power for the specified port.
		 * The actual result is depending on the kind of power switching the root hub implements:
		 * - Per port: Disable power for the specified port
		 * - Ganged: One call will disable power for all ports, independent on the specified port number
		 * - None: The hub driver will not call this procedure
		 * @param port Port to disable power for
		 *)
		PROCEDURE DisablePortPower*(port : SIGNED32);
		BEGIN HALT(301); END DisablePortPower;

		(**	Reset and then enable the specified port.
			Resets the port, waits until reset is complete, enables the port and then returns. The client
			(HubDriver) is responsible for waiting after the port is enabled *)

		PROCEDURE ResetAndEnablePort*(port : SIGNED32) : BOOLEAN;
		BEGIN HALT(301); RETURN FALSE; END ResetAndEnablePort; (* abstract *)

		(** Disable the specified port. *)
		PROCEDURE DisablePort*(port: SIGNED32);
		BEGIN HALT(301); END DisablePort; (* abstract *)

		(** Suspend the specified port *)
		PROCEDURE SuspendPort*(port: SIGNED32) : BOOLEAN;
		BEGIN
			IF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbHcdi: Port suspending not supported."); KernelLog.Ln; END;
			RETURN FALSE;
		END SuspendPort;

		(** Resume the specified port *)
		PROCEDURE ResumePort*(port: SIGNED32) : BOOLEAN;
		BEGIN
			IF Debug.Level >= Debug.Warnings  THEN KernelLog.String("UsbHcdi: Port resuming not supported."); KernelLog.Ln; END;
			RETURN FALSE;
		END ResumePort;

		(**
		 * Get the status of the specified port.
		 * @param port Port to get status from
		 * @param ack Ackknowlegde status bits that are set
		 * @return Port status
		 *)
		PROCEDURE GetPortStatus*(port : SIGNED32; ack : BOOLEAN) : SET;
		BEGIN HALT(301); RETURN {}; END GetPortStatus; (* abstract *)

		(** Indicate a port state using the port indicators *)
		PROCEDURE IndicatePort*(port, indicate : SIGNED32);
		BEGIN
			IF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbHcdi: Port indicator control not supported."); KernelLog.Ln; END;
		END IndicatePort;

		(**
		 * Does the controller has a companion for lower-speed devices?
		 * Not having a companion means that lower-speed devices can be connected directly to the root hub
		 * and won't use a transaction translator.
		 *)
		PROCEDURE HasCompanion*(): BOOLEAN;
		BEGIN
			RETURN FALSE
		END HasCompanion;

		(** Route the specified port to a companion host controller if supported. *)
		PROCEDURE RoutePortToCompanion*(port : SIGNED32);
		BEGIN
			IF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbHcdi: Port routing not supported."); KernelLog.Ln; END;
		END RoutePortToCompanion;

		(** Updates the status field of the USB transfer request <req> *)
		PROCEDURE UpdatePipeStatus*(pipe : Pipe);
		BEGIN HALT(301); END UpdatePipeStatus; (* abstract *)

		(** Clear halt bit if pipe is stalled. The TDs associated to the pipe will be removed from the queue *)
		PROCEDURE ClearHalt*(pipe : Pipe);
		BEGIN HALT(301); END ClearHalt; (* abstract *)

		(**
		 * Schedule a transfer on this hcd.
		 * Will block until the transfer is effectively handed to hardware.
		 * Does not wait for transfer completion.
		 *)
		PROCEDURE Schedule * (transfer: TransferToken);
		BEGIN HALT(301) (* abstract *)
		END Schedule;

		(**
		 * Cancel scheduled transfer.
		 * Tries to cancel a scheduled transfer. Fails if transfer is completed or active.
		 *)
		PROCEDURE Cancel * (transfer: TransferToken): BOOLEAN;
		BEGIN HALT(301) (* abstract *)
		END Cancel;

		(**
		 * Checks that a periodic pipe policy is allowed for this HCD. Returns FALSE if the policy
		 * requires too much bandwidth, TRUE if the policy is schedulable.
		 *)
		PROCEDURE CheckPipePolicy * (interval, size: SIGNED32): BOOLEAN;
		BEGIN HALT(301) (* abstract *)
		END CheckPipePolicy;

		(**
		 * Some HCDIs require some pipe creations to be notified to them. This procedure is called whenever a new
		 * pipe is created, so that the HCDI can take the necessary actions. This is needed, e.g. for bulk and control pipes
		 * on EHCI: we build one qh per pipe.
		 *)
		PROCEDURE RegisterPipe * (pipe: Pipe);
		BEGIN HALT(301) (* abstract *)
		END RegisterPipe;

		(**
		 * Some HCDIs require some pipe freeing to be notified to them. This procedure is called whenever a pipe is freed,
		 * so that the HCDI can take necessary steps. This is needed e.g. for bulk and control pipes on EHCI, so that the
		 * controller can remove the queue head.
		 *)
		PROCEDURE UnregisterPipe * (pipe: Pipe);
		BEGIN HALT(301) (* abstract *)
		END UnregisterPipe;

		(** Debug interface *)

		(** Show the specified queue head / endpoint descriptor *)
		PROCEDURE ShowQH*(qh, firstTD : ADDRESS);
		BEGIN
			IF Debug.Level >= Debug.Warnings THEN KernelLog.String("QH/TD diagnostics not implemented."); KernelLog.Ln; END;
		END ShowQH;

		(** Show the data structures associated with the specified pipe *)
		PROCEDURE ShowPipe*(pipe : Pipe);
		BEGIN
			IF Debug.Level >= Debug.Warnings THEN KernelLog.String("Pipe diagnostics not implemented."); KernelLog.Ln; END;
		END ShowPipe;

		(** Show the host controller's scheduling data structure *)
		PROCEDURE ShowSchedule*;
		BEGIN
			IF Debug.Level >= Debug.Warnings THEN KernelLog.String("Schedule diagnostics not implemented."); KernelLog.Ln; END;
		END ShowSchedule;

	END HcdInterface;

	(** Implements hardware-independent functionality of USB Host Controllers *)
	Hcd* = OBJECT(HcdInterface)
	VAR
		(* Host controller configuration data - Consider this fields as read-only. *)
		iobase*: Machine.Address32;
		irq* : SIGNED32;
		portCount* : SIGNED32;
		ports* : POINTER TO ARRAY OF Machine.Address32;  (* addresses of the Port Status Control registers  *)

		(* PCI specific *)
		bus-, device-, function- : SIGNED32;

		(* HC capabilities (consider read-only) *)
		DMAchaining* : BOOLEAN; 	(* Can the HC do H/W scatter/gather? *)
		sgListSize* : SIGNED32; 		(* How many entries shall the SG list support? Only valid if DMAchaining is TRUE. *)
		isHighSpeed* : BOOLEAN;	(* Does this host controller support high-speed transfer mode? *)

		(* Emulated hub device descriptor *)
		hubDescriptor* : HubDescriptor;

		(* current state of the host controller (Undefined|Initialized|Operational|Suspended|Resuming|Error) *)
		state- : SIGNED32;

		(* Procedure called when the status of the root hub port changes *)
		statusChangeHandler- : StatusChangeHandler;

		(* pipes[deviceaddress][direction][endpoint],  [0][0][0] is the dummy default control pipe 	*)
		(* control pipes (bidirectional) are stored as they had dir In (0)							*)
		pipes- : ARRAY 128 OF ARRAY 2 OF ARRAY 16 OF Pipe;

		(* These pipes have an handler associated which should be called when the pipe's transfer is finished 		*)
		(* The Default Pipe (Address 0, ep 0) of the controller is used as list head but has no completion handler	*)
		notifyPipes- : Pipe;

		(* Keeps track which UDB device addresses are in use. *)
		adrRange : ARRAY 128 OF BOOLEAN;


		(* Per USB lock *)
		buslock : SIGNED32;

		(* For the Wait procedure *)
		timer : Kernel.Timer;

		(* Performance monitoring *)
		NbytesTransfered- : SIGNED64;

		(* HC statistics *)
		NnofTransfers-,
		NnofBulkTransfers-, NnofControlTransfers-, NnofInterruptTransfers-, NnofIsochronousTransfers-,
		NnofUnknownTransfers-,
		NnofInterrupts*, NnofInterruptsHandled* : SIGNED32;

		(** Bus Locking *)

		(** Lock this bus *)
		PROCEDURE Acquire*;
		BEGIN {EXCLUSIVE}
			AWAIT(buslock <= 0); buslock := 1;
		END Acquire;

		(** Unlock this bus *)
		PROCEDURE Release*;
		BEGIN {EXCLUSIVE}
			DEC(buslock);
		END Release;

		(** Set the state of the HC *)
		PROCEDURE SetState*(state : SIGNED32);
		BEGIN {EXCLUSIVE}
			SELF.state := state;
		END SetState;

		(** Root hub control *)

		(**
		 * Return the emulated hub device descriptor.
		 * To be controllable by the hub driver, root hubs emulate a USB hub devices. This procedure returns
		 * the emulated hub descriptor to communicate the root hubs facilities.
		 *)
		PROCEDURE GetHubDescriptor*() : HubDescriptor;
		BEGIN
			IF Debug.StrongChecks THEN ASSERT(hubDescriptor # NIL); END;
			RETURN hubDescriptor;
		END GetHubDescriptor;

		(** Set the emulated hub device descriptor. *)
		 PROCEDURE SetHubDescriptor*(hd : HubDescriptor);
		 BEGIN
		 	IF Debug.StrongChecks THEN ASSERT((hd # NIL) & (LEN(hd) >= 8)); END;
		 	hubDescriptor := hd;
		 END SetHubDescriptor;

		(**
		 * Install a handler for root hub port status changes.
		 * Some host controller can report changes of the port status registers via interrupts. If this is not
		 * supported, the hub driver must poll the root hub for port status changes.
		 * @param handler to be called when root hub port status changes occus
		 * @return TRUE, if root hub support status change notifications, FALSE otherwise.
		 *)
		PROCEDURE SetStatusChangeHandler*(handler : StatusChangeHandler) : BOOLEAN;
		BEGIN
			statusChangeHandler := handler; RETURN TRUE;
		END SetStatusChangeHandler;

		(** Add an interrupt handler. The handler is called, when a IOC interrupt occurs and the pipe.status field is changed	*)
		PROCEDURE AddCompletionHandler*(pipe : Pipe);
		VAR temp : Pipe;
		BEGIN {EXCLUSIVE}
			IF Debug.Trace & Debug.tracePipes THEN
				KernelLog.String("UsbHcdi: Adding completion handler for pipe (Adr: "); KernelLog.Int(pipe.address, 0);
				KernelLog.String(", ep: "); KernelLog.Int(pipe.endpoint, 0); KernelLog.String(")"); KernelLog.Ln;
			END;
			temp := notifyPipes;
			WHILE(temp.next # NIL) & (temp.next # pipe) DO temp := temp.next; END;
			IF temp.next = NIL THEN
				temp.next := pipe;
			ELSIF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbHcdi: Warning: Procedure was already registered as interrupt handler"); KernelLog.Ln;
			END;
		END AddCompletionHandler;

		(** Remove an interrupt handler. The head of this list is always the control pipe for the default address. *)
		PROCEDURE RemoveCompletionHandler*(pipe : Pipe);
		VAR temp : Pipe;
		BEGIN (* only to be called from exclusive regions !! *)
			IF Debug.Trace & Debug.tracePipes & (ADDRESSOF(pipe) > 10H)  THEN
				KernelLog.String("UsbHcdi: Removing completion handler for pipe (Adr: "); KernelLog.Int(pipe.address, 0);
				KernelLog.String(", ep: "); KernelLog.Int(pipe.endpoint, 0); KernelLog.String(")"); KernelLog.Ln;
			END;
			(* Never remove the default address control pipe *)
			(*pipe.transferLock.AcquireWrite;*)
			pipe.irqActive := FALSE;
			(*pipe.transferLock.ReleaseWrite;*)
			temp := notifyPipes;
			WHILE (temp.next # NIL) & (temp.next # pipe) DO temp := temp.next; END;
			IF temp.next # NIL THEN (* delete pipe in list *)
				 temp.next := temp.next.next;
			ELSIF Debug.Level >= Debug.Warnings THEN
				KernelLog.String("UsbHcdi: Warning: Could not remove interrupt handler (not found)"); KernelLog.Ln;
			END;
		END RemoveCompletionHandler;

		PROCEDURE NotifyCompletionHandlers *;
		VAR
			pipe: Pipe;
			transfer: TransferToken;
			status, actLen: SIGNED32;
			irqActive: BOOLEAN;
		BEGIN (* concurrent insertion/removal of completion handlers is allowed *)
			pipe := notifyPipes.next; (* notifyPipes is the Default Pipe (address 0, ep 0), skip it *)
			WHILE pipe # NIL DO
				pipe.lock.Acquire;
				irqActive := pipe.irqActive;
				IF irqActive & (pipe.mode = Usbdi.MinCpu) THEN
					UpdatePipeStatus(pipe);
					(* For all transfers, if finished, call completion notifier *)
					transfer := pipe.transfers;
					WHILE transfer # NIL DO
						IF (transfer.status # Usbdi.InProgress) & (pipe.device.state # StateDisconnected) THEN
							IF Debug.Trace & Debug.traceIoc THEN
								KernelLog.String("UsbHcdi: Notify pipe adr: "); KernelLog.Int(pipe.address, 0);
								KernelLog.String(", ep: "); KernelLog.Int(pipe.endpoint, 0); KernelLog.String(": "); ShowErrors(pipe.errors); KernelLog.Ln;
							END;
							IF Debug.Trace & (transfer.status # Usbdi.Ok) THEN
								IF (transfer.status = Usbdi.ShortPacket) THEN
									IF Debug.traceShortPackets THEN pipe.Show(TRUE); KernelLog.Ln; END;
								ELSE
									IF Debug.traceFailed THEN pipe.Show(TRUE); KernelLog.Ln; END;
								END;
							END;
							IF Debug.PerformanceMonitoring THEN
								IF (transfer.status = Usbdi.Ok) OR (transfer.status = Usbdi.ShortPacket) THEN
									(* should be protected *)
									INC(NbytesTransfered, pipe.actLen);
								END;
							END;
							status := transfer.status;
							actLen := transfer.transfered;
							pipe.CleanupTransfer(transfer);
							IF pipe.mode = Usbdi.MinCpu THEN pipe.completion.SetDone END;
							IF pipe.completionHandlerCaller # NIL THEN pipe.completionHandlerCaller.Call(status, actLen); END;
							transfer := pipe.transfers;
						ELSE
							transfer := transfer.next;
						END;
					END;
					IF pipe.transfers = NIL THEN
						(* No transfers scheduled: deactivate irq notifications *)
						pipe.irqActive := FALSE
					END;
				END;
				pipe.lock.Release;
				pipe := pipe.next;
			END;
		END NotifyCompletionHandlers;

		(* The default pipe (adr 0, ep 0) is only used to communicate with devices as long they are not in the addressed state. *)
		PROCEDURE GetDefaultPipe*(speed, ttPort, ttAddress : SIGNED32; device : Usbdi.UsbDevice) : Pipe;
		VAR pipe : Pipe;
		BEGIN {EXCLUSIVE}
			IF Debug.StrongChecks THEN ASSERT(pipes[0, 0, 0] # NIL); END; (* dummy default pipe is always present *)
			pipe := pipes[0, 0, 0];
			pipe.speed := speed;
			pipe.device := device;
			pipe.completion.device := device;
			pipe.ttPort := ttPort;
			pipe.ttAddress := ttAddress;
			IF (isHighSpeed) & (speed = HighSpeed) THEN
				pipe.maxPacketSize := 64;
			ELSE
				pipe.maxPacketSize := 8;
			END;
			(*IF ~InsertQH(pipe) THEN pipe := NIL; END;*)
			RegisterPipe(pipe);
			RETURN pipe;
		END GetDefaultPipe;

		(** USB Pipe Handling *)

		PROCEDURE GetPipe*(deviceAddress, endpointNbr : SIGNED32; VAR pipe : Pipe);
		BEGIN {EXCLUSIVE}
			IF Debug.StrongChecks THEN
				ASSERT((deviceAddress > 0) & (deviceAddress < 128));  (* valid USB device address *)
				ASSERT((endpointNbr MOD 16 >=  0) & (endpointNbr MOD 16 < 16)); (* valid endpoint number *)
				ASSERT((pipe # NIL) & (pipe.direction = In) OR (pipe.direction = Out));
			END;
			IF pipes[deviceAddress, pipe.direction, endpointNbr MOD 16] # NIL THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbHcdi: GetPipe: Pipe already in use."); KernelLog.Ln; END;
				pipe := NIL; RETURN;
			END;
			(* Allocate the TD buffers  *)
			(*pipe.tdBufferLen := (TDsPerPipe+1)* 16 + 128;
			NEW(pipe.tdBuffer, pipe.tdBufferLen);*)
			IF Debug.StrongChecks THEN
				(*testaddr := Machine.PhysicalAdr(ADDRESSOF(pipe.tdBuffer[0]), pipe.tdBufferLen);
				IF testaddr = Machine.NilAdr THEN
					KernelLog.String("UsbHcdi: GetPipe: Allocated buffer not physically contiguous"); KernelLog.Ln;
					pipe := NIL; RETURN;
				END;*)
			END;
			(* TD's must be 32byte aligned for EHCI, 16byte aligned for UHCI & OHCI data structures*)
			(* currently max qh size is below 128 bytes for EHCI, so a queue head will not cross page boundaries *)
			(*pipe.qh := Align(ADDRESS OF pipe.tdBuffer[0], 128);
			pipe.tdBase := pipe.qh + 32;
			ASSERT((pipe.qh >= ADDRESSOF(pipe.tdBuffer[0])) & (pipe.tdBase <= ADDRESSOF(pipe.tdBuffer[pipe.tdBufferLen-1])));*)
			RegisterPipe(pipe);
			(*IF ~InsertQH(pipe) THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbHcdi: GetPipe: InsertQH failed."); KernelLog.Ln; END;
				pipe := NIL; RETURN;
			END;*)
			pipes[deviceAddress, pipe.direction, endpointNbr MOD 16] := pipe;
			IF Debug.Trace & Debug.tracePipes THEN
				KernelLog.String("UsbHcdi: GetPipe: ");
				CASE pipe.type OF
					|PipeControl: KernelLog.String("Control");
					|PipeBulk: KernelLog.String("Bulk");
					|PipeInterrupt: KernelLog.String("Interrupt");
					|PipeIsochronous: KernelLog.String("Isochronous");
				ELSE
					KernelLog.String("Unknown");
				END;
				IF pipe.direction = In THEN KernelLog.String(" IN Pipe, ");
				ELSIF pipe.direction = Out THEN KernelLog.String(" OUT Pipe, ");
				ELSE KernelLog.String("Unknown direction Pipe, ");
				END;
				KernelLog.String(" Adr: "); KernelLog.Int(deviceAddress, 0);
				KernelLog.String(" Ep: "); KernelLog.Int(endpointNbr, 0);
				KernelLog.String(" established"); KernelLog.Ln;
			END;
		END GetPipe;

		PROCEDURE FreePipe*(pipe : Pipe);
		BEGIN {EXCLUSIVE}
			FreePipeInternal(pipe);
		END FreePipe;

		PROCEDURE FreePipeInternal(pipe : Pipe);
		BEGIN (* only call from exclusive regions *)
			(*TRACE('FreePipeInternal');*)
			IF pipe.address = 0 THEN
				(*IF pipe.qh # 0 THEN RemoveQH(pipe); END;*)
				UnregisterPipe(pipe);
				IF Debug.Trace & Debug.tracePipes THEN KernelLog.String("UsbHcdi: Default pipe at adr 0 freed up."); KernelLog.Ln; END;
			ELSIF pipes[pipe.address, pipe.direction, pipe.endpoint MOD 16] # NIL THEN
				(* De-install interrupt handler if present *)
				IF pipe.ioc THEN RemoveCompletionHandler(pipe); END;
				(* Kill completion handler caller if present *)
				IF pipe.completionHandlerCaller # NIL THEN pipe.completionHandlerCaller.Terminate; END;
				(* Remove the pipe's queue head from the host controller's schedule *)
				(*IF pipe.qh # 0 THEN RemoveQH(pipe); END;*)
				UnregisterPipe(pipe);
				(* Never free the dummy default pipe *)
				pipes[pipe.address, pipe.direction, pipe.endpoint MOD 16] := NIL;
				IF Debug.Trace & Debug.tracePipes THEN
					KernelLog.String("UsbHcdi: FreePipe:"); KernelLog.String(" Adr: "); KernelLog.Int(pipe.address, 0);
					KernelLog.String(" Ep: "); KernelLog.Int(pipe.endpoint, 0); KernelLog.String(" freed up."); KernelLog.Ln;
				END;
			ELSE (* Pipe not known by host controller *)
				IF Debug.Level >= Debug.Warnings THEN
					KernelLog.String("UsbHcdi: FreePipe: Can't free pipe... pipe not known by host controller ADR: ");
					IF pipe # NIL THEN
						KernelLog.Int(pipe.address, 0); KernelLog.String(", ep: "); KernelLog.Int(pipe.endpoint, 0);
						KernelLog.String(", dir: "); KernelLog.Int(pipe.direction, 0);
					ELSE
						KernelLog.String("NIL");
					END;
					KernelLog.Ln;
				END;
			END;
			(*TRACE('END FreePipeInternal');*)
		END FreePipeInternal;

		(** Free all pipes of the device with the address adr *)
		PROCEDURE FreeAll*(adr : SIGNED32);
		VAR i, j : SIGNED32;
		BEGIN {EXCLUSIVE}
			IF Debug.StrongChecks THEN ASSERT((adr >= 0) & (adr < 128)); END;
			IF adr = 0 THEN RETURN (* Emulated hub device has no pipes *) END;
			IF state = Shutdown THEN RETURN; END; (* Since the controller has been resetted, removing QHs would trap *)
			FOR i := 0 TO 15 DO
				FOR j := 0 TO 1 DO
					IF pipes[adr, j, i] # NIL THEN
						FreePipeInternal(pipes[adr, j , i]);
					END;
				END;
			END;
		END FreeAll;

		(** Returns a unused address and marks it as used; address 0 is the default address, to
		 * which unaddressed USB devices at enabled endpoints will respond.  *)
		PROCEDURE GetFreeAddress*() : SIGNED32;
		VAR adr : SIGNED32;
		BEGIN {EXCLUSIVE}
			FOR adr := 1 TO 127 DO
				IF adrRange[adr] = FALSE THEN adrRange[adr] := TRUE; RETURN adr; END;
			END;
			RETURN 0;
		END GetFreeAddress;

		(** Marks the address <adr> as free *)
		PROCEDURE FreeAddress*(adr : SIGNED32);
		BEGIN {EXCLUSIVE}
			adrRange[adr] := FALSE;
		END FreeAddress;

		(** Helper: Wait for the specified number of milliseconds *)
		PROCEDURE Wait*(ms : SIGNED32);
		BEGIN
			timer.Sleep(ms);
		END Wait;

		PROCEDURE Cleanup*;
		BEGIN
			SetState(Shutdown); timer.Wakeup;
		END Cleanup;

		PROCEDURE &Default*(bus, device, function : SIGNED32);
		VAR pipe : Pipe; i : SIGNED32;
		BEGIN
			SELF.bus := bus; SELF.device := device; SELF.function := function;
			NEW(timer);
			FOR i := 0 TO 127 DO adrRange[i] := FALSE; END;
			NEW(pipe, 0, 0, SELF);
			pipe.type := PipeControl; pipe.direction := 0;
			(*pipe.maxPacketSize := 8; (* will be reset to 64 for EHCI HCs by hub driver *) (*! Should maybe be set in specific HCDIs *)*)
			pipe.maxRetries := 3; pipe.timeout := 5000;
			(* okay, now we allocate the TD buffers  *)
			(*pipe.tdBufferLen := (TDsDefaultPipe+1) * 16 + 128; (* max alignment of 128 bytes *)
			NEW(pipe.tdBuffer, pipe.tdBufferLen);*)
			(* TD's must be 32byte aligned for EHCI data structures, 16byte for UHCI & OHCI data structures *)
			(* currently max qh size is below 128 bytes for EHCI, so a queue head will not cross page boundaries *)
			(*pipe.qh := Align(ADDRESS OF pipe.tdBuffer[0], 128);*)
			(*pipe.tdBase := pipe.qh + 32;*)
			IF Debug.StrongChecks THEN
				(*ASSERT(pipe.tdBase >= ADDRESSOF(pipe.tdBuffer[0]));
				ASSERT(pipe.tdBase <= ADDRESSOF(pipe.tdBuffer[pipe.tdBufferLen-1]));*)
			END;
			pipes[0, 0, 0] := pipe;
			notifyPipes := pipe; (* Used as list head only (don't call its completion handler) *)
		END Default;

		(** Show diagnostic of host controller *)
		PROCEDURE Diag*;
		VAR port : SIGNED32; dword : SET;
		BEGIN
			IF Debug.Trace THEN
			KernelLog.String("Diagnostics of "); KernelLog.String(name);
			KernelLog.String(" ("); KernelLog.String(desc); KernelLog.String(")");
			KernelLog.Ln;
			(* PCI information *)
			KernelLog.String("   PCI bus "); KernelLog.Int(bus, 0); KernelLog.String(", device "); KernelLog.Int(device, 0);
			KernelLog.String(", function "); KernelLog.Int(function, 0);
			KernelLog.Ln;
			(* IO base address and Interrupt Line *)
			KernelLog.String("   I/O base "); KernelLog.Hex(iobase, 8); KernelLog.String("H,  Irq: "); KernelLog.Int (irq, 0);
			KernelLog.String(", Int Counter: "); KernelLog.Int(NnofInterrupts, 0);
			KernelLog.Ln;
			(* Port Status *)
			KernelLog.String("   Number of ports: "); KernelLog.Int(portCount, 0); KernelLog.String(", Port status: ");
			KernelLog.Ln;
			FOR port := 0 TO portCount-1 DO
				dword := GetPortStatus(port, FALSE); KernelLog.String("      Port "); KernelLog.Int(port+1, 0); KernelLog.String(": ");
				ShowPortStatus(dword);	KernelLog.Ln;
			END;
			END;
		END Diag;
	END Hcd;

	(**
	 * Abstract transfer descriptor.
	 * These transfer descriptors are used only for interfacing pipes and HCDIs.
	 * A transfer descriptor contains all necessary info for a transfer, in a transfer and hcd independent
	 * structure. This makes a clean and extensible interface between the high-level pipe and the services it
	 * requires from HCDIs.
	 *)
	TransferToken * = POINTER TO RECORD
		(** Pipe associated with the transfer. Provides all pipe-specific information (type, packet size, direction) and completion handler. *)
		pipe *: Pipe;
		(** Transfer buffer. *)
		buffer *: (*POINTER TO ARRAY OF CHAR*) ADDRESS;
		(** ID of the transfer. Unique among all non-completed transfers of a pipe. *)
		id *,
		(** Offset and length of data to send/receive in the transfer buffer. *)
		len *: SIGNED32;
		(** Status information: error, status and total transfered byte count. *)
		errors *: SET;
		status *, transfered *: SIGNED32;
		(** Control message. Used for control transfers only. *)
		message *: ControlMessage;
		(** HCD-specific data structures associated with this transfer. Used by HCDI only. Invalid after transfer completion. *)
		tds *: ARRAY MaxTDs OF ADDRESS;

		(** Chaining of transfer descriptors. *)
		next *: TransferToken;
	END;

TYPE

	(** Used for Interrupt On Completion (IOC) transfer status notification *)
	TransferCompletion = OBJECT
	VAR
		done : BOOLEAN;
		completiontimeout : BOOLEAN;
		timer : Objects.Timer;
		device* : Usbdi.UsbDevice;

		PROCEDURE SetDone;
		BEGIN {EXCLUSIVE}
			done := TRUE;
		END SetDone;

		PROCEDURE SetCompletionTimeout;
		BEGIN {EXCLUSIVE}
			completiontimeout := TRUE;
		END SetCompletionTimeout;

		PROCEDURE AwaitDone(timeout : SIGNED32) : BOOLEAN;
		VAR result : BOOLEAN;
		BEGIN {EXCLUSIVE}
			Objects.SetTimeout(timer, SELF.SetCompletionTimeout, timeout);
			done := FALSE; completiontimeout := FALSE;
			AWAIT(done OR completiontimeout OR (device.state = StateDisconnected));
			Objects.CancelTimeout(timer);
			done := FALSE; result := completiontimeout; completiontimeout := FALSE;
			RETURN ~result;
		END AwaitDone;

		PROCEDURE &New*;
		BEGIN
			NEW(timer);
		END New;

	END TransferCompletion;

TYPE

	(* Thread that calls the completion handler of a pipe (if it has one) *)
	CompletionHandlerCaller = OBJECT
	CONST
		Size = 32;
	VAR
		completionHandler : Usbdi.CompletionHandler;
		pipe : Pipe;
		events: ARRAY Size OF RECORD status, actLen: SIGNED32; END;
		status, actLen: SIGNED32;
		head, len: SIGNED32;
		alive, dead : BOOLEAN;

		PROCEDURE Call (status, actLen: SIGNED32);
		BEGIN {EXCLUSIVE}
			AWAIT(len < Size);
			events[(head + len) MOD Size].status := status;
			events[(head + len) MOD Size].actLen := actLen;
			INC(len);
		END Call;

		PROCEDURE HandleTimeout;
		BEGIN{EXCLUSIVE}
			dead := TRUE;
		END HandleTimeout;

		PROCEDURE Terminate;
		VAR timer:Objects.Timer;
		BEGIN
			BEGIN {EXCLUSIVE} alive := FALSE; END;
			(* release monitor lock *)
			NEW(timer);
			Objects.SetTimeout(timer, HandleTimeout, 100);
			BEGIN {EXCLUSIVE} AWAIT(dead); END;
		END Terminate;

		PROCEDURE &New*(pipe : Pipe; c : Usbdi.CompletionHandler);
		BEGIN
			ASSERT(c # NIL);
			SELF.pipe := pipe;
			completionHandler := c;
			alive := TRUE; dead := FALSE;
		END New;

	BEGIN {ACTIVE}
		WHILE alive DO
			BEGIN {EXCLUSIVE}
				AWAIT((len > 0) OR ~alive);
				status := events[head MOD Size].status;
				actLen := events[head MOD Size].actLen;
				INC(head);
				DEC(len);
			END;
			IF alive THEN
				(* notify the pipe that transfer finished to get transfer results in pipe. *)
				(*pipe.CleanupTransfer(transfer);*)
				completionHandler(status, actLen)
			END;
			(*BEGIN {EXCLUSIVE}
				doCall := FALSE
			END*)
		END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END CompletionHandlerCaller;

TYPE


	(**
	 * USB Communication Pipe
	 * USB communication happens between buffers provided by client software and device endpoints. The association between
	 * a client software buffer and a device endpoint is called pipe.
	 * This is the low-level implementation of a pipe which is used by the host controller drivers. The fields declared here aren't visible
	 * to client software which uses the interface defined by the USB Driver Interface (Usbdi).
	 *
	 * Concurrency:
	 *	- concurrent calls on a pipe must preserve the transfer token list.
	 *)
	Pipe* = OBJECT(Usbdi.Pipe)
	VAR
		(* Device endpoint *)
		address* : SIGNED32; 	(* USB device address *)
		endpoint* : SIGNED32; 	(* Endpoint address *)
		direction* : SIGNED32; 	(* Endpoint direction; Usbdi.In or Usbdi.Out; not used for control transfers *)

		(* Associated host controller & USB device *)
		controller* : Hcd;
		device* : Usbdi.UsbDevice;

		(* Address of hub device that contains the transaction translator we're connected to and port of the TT *)
		(* These fields are duplicate here (also available in Usb.UsbDevice to avoid the import of Usb.Mod in UsbEhci.Mod *)
		ttPort*, ttAddress* : SIGNED32;

		(* Information from endpoint descriptor *)
		type* : SIGNED32; 		(* PipeControl, PipeBulk, PipeInterrupt or PipeIsochronous *)
		irqInterval* : SIGNED32; 	(* Interrupt interval for PipeInterrupt (interrupt transfers) *)
		mult* : SIGNED32; 		(* For high-speed interrupt/isochronous pipes: How many transactions per microframe (1,2 or 3) *)

		(* Pipe specific features *)
		speed* : SIGNED32; 		 	(* LowSpeed, FullSpeed, HighSpeed *)
		dataToggle* : BOOLEAN; 	(* 1bit sequence number *)
(*		hostDelay, hubLsSetup : SIGNED32; (* Delay introduced by host / hub in nanoseconds *)  *)

		(** Transfer list. Manipulate only in EXCLUSIVE regions. *)
		transfers*, lastTransfer*: TransferToken;
		lock *: Locks.Lock;
		(** Next transfer ID to use. Manipulate only in EXCLUSIVE regions. *)
		nextId: SIGNED32;

		(* Periodic pipe policy *)
		sampleInterval, sampleSize: SIGNED32;

		(* Transfer status information *)
		status* : Usbdi.Status	;	(* Status of the last tranfer from/to this endpoint *)
		errors* : SET;
		transferLen* : SIGNED32;		(* Length of the transfer in bytes *)
		actLen* : SIGNED32; 			(* how many bytes did the controller send/receive *)

		(* Buffer for S/W scatter/gather support *)
		sgBuffer : Usbdi.BufferPtr;
		physBufferAdr- : ADDRESS;

		(* Buffer for H/W scatter/gather suport *)
		sgList- : POINTER TO ARRAY OF Machine.Range;

		(* Pipe parameters set by client software *)
		timeout* : SIGNED32;

		(* Data structures 																									*)
		(* For control, bulk and interrupt transfers, each pipe has an associated queue head in the host controllers schedule.		*)
		(* This queue head can be found in the queue <queue>. The actual USB transfers are described as linked list of 			*)
		(* transfer descriptors (TD), which are linked to the pipe`s queue head. 												*)
		queue* : Machine.Address32;
		(*qh* : Machine.Address32;
		firstTD*, lastTD* : Machine.Address32;

		(* Per pipe buffer for transfer descriptors *)
		tdBuffer* : POINTER TO ARRAY OF CHAR;
		tdBufferLen* : SIGNED32;
		tdBase* : Machine.Address32;*)

		(** Holder for controller-specific descriptors that are related to a pipe and not a transfer (e.g. queue heads in EHCI). A lock is provided for synchronization. *)
		descriptors *: POINTER TO ARRAY OF ADDRESS;
		(*descriptorLock *: Locks.Lock;*)

		(* Transfer completion handling related *)
		ioc* : BOOLEAN;  (* interrupt on completion enabled/disabled *)
		completionHandlerCaller* : CompletionHandlerCaller; (* if active & ioc, the procedure interruptHandler will be called if status * ResInProgress = {} *)
		irqActive* : BOOLEAN; (* Should the InterruptHandler be called? *)
		completion- : TransferCompletion;

		(* Pipe management *)
		next* : Pipe;

		(* Control pipes only: 8 Byte message *)
		message : ControlMessage;

		PROCEDURE &New*(adr, ep : SIGNED32; hcd : Hcd);
		BEGIN
			NEW(completion);
			address := adr; endpoint := ep; controller := hcd; status := Usbdi.InProgress;
			(*IF controller.DMAchaining THEN NEW(sgList, controller.sgListSize); END;*)
			(*NEW(descriptorLock);*)
			NEW(lock)
		END New;

		(* For host controllers that do not support DMA chaining, the buffers must be physically contiguous. In Bluebottle, all buffers allocated 	*)
		(* on the heap meet this requirement. Buffers allocated on the stack may, however, be physically non-contiguous. Fortunately, the 		*)
		(* stack size is limited to 128K, so these buffers won't be bigger than 128K.																*)
		(* This procedure...																													*)
		(* 	- 	Returns TRUE and as a side effect copies the client buffer into the scatter/gather buffer for OUT transfers if the specified buffer	*)
		(*		cannot directly be used by the host controller																					*)
		(*	-	Returns FALSE when the client buffer meets the requirement of the host controller hardware									*)
		PROCEDURE NeedSWScatterGather(direction, bufferLen, offset : SIGNED32; VAR buffer : Usbdi.Buffer; VAR doCopy : BOOLEAN) : BOOLEAN;
		VAR adr : ADDRESS;
		BEGIN
			doCopy := FALSE;
			IF bufferLen = 0 THEN RETURN FALSE; END;
			adr := Machine.PhysicalAdr(UsbBuffers.GetDataAddress(buffer), bufferLen);
			IF adr = -1 THEN  (* buffer is not physically contiguous *)
				IF sgBuffer = NIL THEN NEW(sgBuffer, 128*1024); END; (* 128K is stack limit *)
				physBufferAdr := UsbBuffers.GetDataAddress(sgBuffer);
				IF direction = In THEN
					doCopy := TRUE;
				ELSE
					ASSERT(bufferLen <= 128*1024); (* If the buffer is on the heap, we don't reach this code. Stack limit is 128K *)
					Copy(buffer, sgBuffer, offset, 0, bufferLen);
				END;
				RETURN TRUE;
			ELSE
				physBufferAdr := adr;
				RETURN FALSE;
			END;
		END NeedSWScatterGather;

		PROCEDURE Transfer*(bufferLen, offset : SIGNED32; VAR buffer : Usbdi.Buffer) : Usbdi.Status;
		VAR
			copy : BOOLEAN;
			transfer: TransferToken;
		BEGIN
			ASSERT(type # PipeControl);
			ASSERT(LEN(buffer) >= bufferLen + offset);
			IF Debug.Trace & Debug.traceTransfers THEN ShowTransfer(bufferLen, offset); END;

			transfer := GetToken();
			transfer.pipe := SELF;
			IF ~controller.DMAchaining & NeedSWScatterGather(direction, bufferLen, 0, buffer, copy) THEN
				transfer.buffer := UsbBuffers.GetDataAddress(sgBuffer)
			ELSE
				transfer.buffer := UsbBuffers.GetDataAddress(buffer)
			END;
			transfer.len := bufferLen;
			transfer.status := Usbdi.InProgress;
			IF timeout # 0 THEN status := Usbdi.InProgress END;

			lock.Acquire;
			transfer.id := nextId; INC(nextId);
 			IF transfers = NIL THEN
				transfers := transfer
			ELSE
				lastTransfer.next := transfer
			END;
			lastTransfer := transfer;

			IF (timeout = 0) OR (mode = Usbdi.MinCpu) THEN
				irqActive := TRUE
			END;
			lock.Release;
			controller.Schedule(transfer);

			IF timeout = 0 THEN
				RETURN transfer.id
			ELSE
				WaitForCompletion(transfer, buffer, copy);
				RETURN status
			END
		END Transfer;

		(** Waits for the completion of the next transfer. *)
		PROCEDURE WaitForCompletion (transfer: TransferToken; buffer: Usbdi.Buffer; copy: BOOLEAN);
		VAR
			mtimer: Kernel.MilliTimer;
		BEGIN
			ASSERT(timeout # 0);
			Kernel.SetTimer(mtimer, timeout);
			IF mode # Usbdi.MinCpu THEN
				Kernel.SetTimer(mtimer, timeout);
				lock.Acquire;
				LOOP
					IF (transfer.status # Usbdi.InProgress) OR Kernel.Expired(mtimer) OR (device.state = StateDisconnected) THEN EXIT; END;
					controller.UpdatePipeStatus(SELF);
					IF mode = Usbdi.Normal THEN Objects.Yield; END;
				END;
				(* Copy result from transfer to pipe *)
				CleanupTransfer(transfer);
				lock.Release
			ELSE
				IF ~completion.AwaitDone(timeout) THEN
					(* ignore *)
				END;
				(* Transfer cleanup is done in the interrupt handling routine. *)
			END;

			IF Debug.PerformanceMonitoring THEN
				(* access should be protected *)
				INC (controller.NbytesTransfered, actLen);
			END;
			IF copy & (status # Usbdi.InProgress) THEN (* copy data from scatter/gather buffer to client buffer *)
				Copy(sgBuffer, buffer, 0, 0, actLen);
			END;
			IF Debug.Trace & Debug.traceControlData & (type = PipeControl) THEN
				IF transfer.len > 0 THEN ShowData(transfer.buffer, transfer.len); KernelLog.Char(" "); ELSE KernelLog.String("[No Data] "); END;
			END;
			IF Debug.Trace & (Debug.traceTransfers OR Debug.traceControl) THEN ShowStatus(status); KernelLog.Ln; END;
			IF Debug.Trace & (status # Usbdi.Ok) THEN
				IF (status = Usbdi.ShortPacket) THEN
					IF Debug.traceShortPackets THEN Show(TRUE); KernelLog.Ln; END;
				ELSE
					IF Debug.traceFailed THEN Show(TRUE); KernelLog.Ln; END;
				END;
			END;
		END WaitForCompletion;

		(** For control transfers (only for Control Pipes) *)
		PROCEDURE Request*(bmRequestType : SET;  bRequest, wValue, wIndex, wLength : SIGNED32; VAR buffer : Usbdi.Buffer) : Usbdi. Status;
		VAR
			dir, ofs: SIGNED32;
			transfer: TransferToken;
			copy: BOOLEAN;
		BEGIN
			ASSERT(type = PipeControl);
			ASSERT(LEN(buffer) >= wLength);
			ASSERT(buffer # NIL);

			transfer := GetToken();

			(*transferLock.Acquire;*)
			IF transfer.message = NIL THEN NEW(transfer.message, 8); END;
			transfer.message[0] := CHR(SYSTEM.VAL(SIGNED32, bmRequestType));
			transfer.message[1] := CHR(bRequest);
			transfer.message[2] := CHR(wValue);
			transfer.message[3] := CHR(LSH(wValue, -8));
			transfer.message[4] := CHR(wIndex);
			transfer.message[5] := CHR(LSH(wIndex,-8));
			transfer.message[6] := CHR(wLength);
			transfer.message[7] := CHR(LSH(wLength, -8));
			dir := direction;
			IF bmRequestType * Usbdi.ToHost # {} THEN direction := In; ELSE 	direction := Out; END;
			IF Debug.Trace & Debug.traceControl THEN ShowMessage(wLength, direction, transfer.message); END;

			transfer.pipe := SELF;
			IF ~controller.DMAchaining & NeedSWScatterGather(dir, wLength, 0, buffer, copy) THEN
				transfer.buffer := UsbBuffers.GetDataAddress(sgBuffer)
			ELSE
				transfer.buffer := UsbBuffers.GetDataAddress(buffer)
			END;
			transfer.len := wLength;
			transfer.status := Usbdi.InProgress;

			lock.Acquire;
			transfer.id := nextId; INC(nextId);
			(* We do not allow transfer queuing on control pipes, therefore the transfer list shall be empty *)
			ASSERT(transfers = NIL);
			transfers := transfer;
			(*lastTransfer := transfer;*)
			lock.Release;
			controller.Schedule(transfer);

			WaitForCompletion(transfer, buffer, copy);
			direction := dir;
			RETURN status
		END Request;

		PROCEDURE ClearHalt*(): BOOLEAN;
		CONST FsEndpointHalt = 0; SrClearFeature = 1;
		VAR res : BOOLEAN;
		BEGIN
			IF Debug.Trace & Debug.tracePipes THEN
				KernelLog.String("UsbHcdi: Clearhalt Pipe"); KernelLog.String(" Adr: ");KernelLog.Int(address, 0);
				KernelLog.String(" Ep: "); KernelLog.Int(endpoint, 0); KernelLog.Ln;
			END;
			controller.ClearHalt(SELF);
			lock.Acquire;
			transfers := NIL;
			lock.Release;
			res := device.Request(Usbdi.ToDevice + Usbdi.Standard + Usbdi.Endpoint, SrClearFeature, FsEndpointHalt, endpoint, 0, Usbdi.NoData) = Usbdi.Ok;
			IF res THEN dataToggle := FALSE; END;
			RETURN res;
		END ClearHalt;

		PROCEDURE IsHalted*() : BOOLEAN;
		CONST SrGetStatus = 0; Halted = {0};
		VAR buffer : Usbdi.BufferPtr; status : SET;
		BEGIN
			IF Debug.Trace & Debug.tracePipes THEN
				KernelLog.String("UsbHcdi: Get endpoint status for Adr: "); KernelLog.Int(address, 0);
				KernelLog.String(", Ep: "); KernelLog.Int(endpoint, 0); KernelLog.Ln;
			END;
			NEW(buffer, 2);
			IF device.Request(Usbdi.ToHost + Usbdi.Standard + Usbdi.Endpoint, SrGetStatus , 0, endpoint MOD 16, 2, buffer) = Usbdi.Ok THEN
				status := SYSTEM.VAL(SET, ORD(buffer[0]) + ORD(buffer[1])*100H);
				RETURN status * Halted # {};
			END;
			RETURN FALSE;
		END IsHalted;

		PROCEDURE GetActLen*() : SIGNED32;
		BEGIN
			RETURN actLen;
		END GetActLen;

		PROCEDURE SetTimeout*(timeout : SIGNED32);
		BEGIN
			SELF.timeout := timeout;
		END SetTimeout;

		PROCEDURE GetStatus*(VAR len : SIGNED32) : Usbdi.Status;
		BEGIN
			controller.UpdatePipeStatus(SELF); len := actLen;
			RETURN status;
		END GetStatus;

		PROCEDURE SetCompletionHandler*(handler: Usbdi.CompletionHandler);
		BEGIN
			ioc := TRUE; (* set Interrupt On Completion Bit in TD's *)
			mode := Usbdi.MinCpu;
			IF completionHandlerCaller # NIL THEN
				completionHandlerCaller.Terminate;
			END;
			NEW(completionHandlerCaller, SELF, handler);
			controller.AddCompletionHandler(SELF);
		END SetCompletionHandler;

		PROCEDURE GetLastTransactionId * (): SIGNED32;
		BEGIN
		END GetLastTransactionId;

		PROCEDURE CancelTransaction * (id: SIGNED32): BOOLEAN;
		VAR
			tx: TransferToken;
		BEGIN
			tx := transfers;
			WHILE (tx # NIL) & (tx.id # id) DO tx := tx.next END;
			IF (tx = NIL) OR (tx.status = Usbdi.InProgress) THEN
				RETURN FALSE
			ELSE
				RETURN controller.Cancel(tx)
			END
		END CancelTransaction;

		PROCEDURE SetPolicy * (interval, size: SIGNED32): BOOLEAN;
		VAR
			res: BOOLEAN;
		BEGIN
			IF (type = PipeControl) OR (type = PipeBulk) THEN RETURN FALSE END;
			res := controller.CheckPipePolicy(interval, size);
			IF res THEN
				sampleInterval := interval;
				sampleSize := size
			END;
			RETURN res
		END SetPolicy;

		(**
		 * Cleanup a finished transfer.
		 * This is called when a transfer finished.
		 *)
		PROCEDURE CleanupTransfer (transfer: TransferToken);
		VAR
			prev: TransferToken;
			readLocked: BOOLEAN;
		BEGIN
			(*TRACE("Cleanup acquire Tk Write");*)
			(*readLocked := transferLock.HasLock();
			IF ~readLocked THEN transferLock.Acquire END;*)
			(* update pipe status variables *)
			ASSERT(transfer # NIL);
			(*IF type = PipeIsochronous THEN TRACE(transfer, transfer.status, transfer.errors, transfer.transfered) END;*)
			status := transfer.status;
			errors := transfer.errors;
			actLen := transfer.transfered;

			(* remove transfer from list *)
			(*IF type = PipeIsochronous THEN TRACE(transfer, transfers) END;*)
			IF transfer = transfers THEN
				transfers := transfers.next
			ELSE
				prev := transfers;
				WHILE (prev # NIL) & (prev.next # NIL) & (prev.next # transfer) DO
					prev := prev.next
				END;
				ASSERT(prev # NIL);
				ASSERT(prev.next = transfer);
				IF transfers = lastTransfer THEN
					prev.next := NIL;
					lastTransfer := prev
				ELSE
					prev.next := transfer.next
				END
			END;
			(*IF ~readLocked THEN transferLock.Release END;*)
			(*TRACE("Cleanup release Tk Write");*)
			PutToken(transfer)
		END CleanupTransfer;

		(* Display textual representation of the transfer that will be executed. *)
		PROCEDURE ShowTransfer(bufferLen, offset : SIGNED32);
		BEGIN
			IF Debug.Trace THEN
			KernelLog.String("UsbHcdi: ");
			CASE type OF
				PipeControl : KernelLog.String("Control Transfer???:");
				| PipeBulk : KernelLog.String("Bulk Transfer:");
				| PipeInterrupt : KernelLog.String("Interrupt Transfer:");
				| PipeIsochronous : KernelLog.String("Isochronous Transfer:");
			ELSE KernelLog.String("Unknown transfer type");
			END;
			KernelLog.String(" Adr: "); KernelLog.Int(address, 0);
			KernelLog.String(" Endpoint: "); KernelLog.Int(endpoint, 0);
			KernelLog.String(" Length: "); KernelLog.Int(bufferLen, 0); KernelLog.String(" Bytes: ");
			END;
		END ShowTransfer;

		PROCEDURE ShowMessage(bufferLen, direction : SIGNED32; CONST msg : ControlMessage);
		VAR i : SIGNED32;
		BEGIN
			IF Debug.Trace THEN
			KernelLog.String("UsbHcdi: Control Transfer: ");
			IF direction = In THEN KernelLog.String("IN");
			ELSIF direction = Out THEN KernelLog.String("OUT");
			ELSE KernelLog.String("ERROR");
			END;
			KernelLog.String(" Adr: "); KernelLog.Int(address, 0);
			KernelLog.String(" Endpoint: "); KernelLog.Int(endpoint, 0);
			KernelLog.String(" Length: "); KernelLog.Int(bufferLen, 0); KernelLog.String(" Bytes: ");
			KernelLog.String(" CtrlMsg: "); 	FOR i := 0 TO 7 DO KernelLog.Hex(ORD(msg[i]), -2); KernelLog.String(" "); END;
			END;
		END ShowMessage;

		PROCEDURE ShowData (buffer: ADDRESS; len: SIGNED32);
		VAR i : SIGNED32;
		BEGIN
			IF Debug.Trace THEN
			KernelLog.String("[DATA: ");
			FOR i := 0 TO len - 1 DO
				KernelLog.Hex(SYSTEM.GET8(buffer + i), -2);
				IF i < len-1 THEN KernelLog.Char(" "); END;
			END;
			KernelLog.Char("]");
			END;
		END ShowData;

		PROCEDURE Show*(detailed : BOOLEAN);
		BEGIN
			IF Debug.Trace THEN
				CASE type OF
					| PipeControl: KernelLog.String(" Control ");
					| PipeInterrupt : KernelLog.String(" Interrupt ");
					| PipeBulk : KernelLog.String(" Bulk ");
					| PipeIsochronous : KernelLog.String(" Isochronous ");
				ELSE
					KernelLog.String("Unknown("); KernelLog.Int(type, 0); KernelLog.String(") ");
				END;
				CASE direction OF
					| Out: KernelLog.String("OUT");
					| In : KernelLog.String("IN");
				ELSE
					KernelLog.String("IN/OUT");
				END;
				KernelLog.String(" Pipe:"); KernelLog.String(" Adr: "); KernelLog.Int(address, 0); KernelLog.String(" Ep: "); KernelLog.Int(endpoint, 0);
				KernelLog.String(" ");
				IF ioc THEN KernelLog.String("[IOC]"); END;
				IF completionHandlerCaller # NIL THEN KernelLog.String("[Handler]"); END;
				IF irqActive THEN KernelLog.String("[IRQ_ACTIVE]"); END;
				IF speed = LowSpeed THEN KernelLog.String("[LowSpeed]");
				ELSIF speed = FullSpeed THEN KernelLog.String("[FullSpeed]");
				ELSIF speed = HighSpeed THEN KernelLog.String("[HighSpeed]");
				ELSE KernelLog.String("[ERROR: Not speed specified]");
				END;
				KernelLog.Ln;
				(*KernelLog.String("    Queue: "); KernelLog.Hex(queue, 8); KernelLog.String("H");
				KernelLog.String(", QH: "); KernelLog.Hex(qh, 8); KernelLog.String("H");
				KernelLog.String(", firstTD: "); KernelLog.Hex(firstTD, 8); KernelLog.String("H");
				KernelLog.String(", lastTD: "); KernelLog.Hex(lastTD, 8); KernelLog.String("H");
				KernelLog.Ln;*)
				IF detailed THEN
					IF type = PipeInterrupt THEN KernelLog.String("    IRQ Interval: "); KernelLog.Int(irqInterval, 0); KernelLog.String("ms, "); ELSE KernelLog.String("    "); END;
					KernelLog.String("Timeout: "); KernelLog.Int(timeout, 0); KernelLog.String("ms ");
					KernelLog.String(", MaxPacketSize: "); KernelLog.Int(maxPacketSize, 0); KernelLog.String(" Bytes");
					KernelLog.String(", MaxRetries: "); KernelLog.Int(maxRetries, 0);
					KernelLog.String(", Mode: ");
					CASE mode OF
						|Usbdi.Normal: KernelLog.String("Normal");
						|Usbdi.MaxPerformance: KernelLog.String("MaxPerformance");
						|Usbdi.MinCpu: KernelLog.String("MinCPU");
					ELSE
						KernelLog.String("Undefined ("); KernelLog.Int(mode, 0); KernelLog.String(")");
					END;
					KernelLog.String(", Last status: "); ShowStatus(status);
					KernelLog.String(", Last errors: "); ShowErrors(errors); KernelLog.Ln;
				END;
			END;
		END Show;
	END Pipe;

TYPE
	Registry= OBJECT(Plugins.Registry) END Registry;

VAR
	controllerCount : SIGNED32; (* Only used for name creation - does not necessary reflect the actual HC count *)
	controllers- : (*Plugins.*)Registry;

	tokenPool: TransferToken;

(** Copy data from array to array *)
PROCEDURE Copy(VAR from, to: Usbdi.Buffer; fofs, tofs, len: SIGNED32);
BEGIN
	IF Debug.Trace & Debug.traceCopying THEN KernelLog.String("UsbHcdi: SG: Copying "); KernelLog.Int(len, 0); KernelLog.String(" Bytes."); KernelLog.Ln; END;
	IF len > 0 THEN
		ASSERT((fofs+len <= LEN(from)) & (tofs+len <= LEN(to)));
		SYSTEM.MOVE(UsbBuffers.GetDataAddress(from) + fofs, UsbBuffers.GetDataAddress(to) + tofs, len);
	END;
END Copy;

(** Assign a name to the host controller and add it to the controllers registry *)
PROCEDURE RegisterHostController*(hcd : Hcd; CONST description : Plugins.Description);
VAR name : Plugins.Name; res : SIGNED32;
BEGIN {EXCLUSIVE}
	name := "USBHC"; name[5] := CHR(controllerCount + 48); name[6] := 0X;
	hcd.SetName(name); hcd.desc := description;
	(* Register the host controller as AosPlugin *)
	controllers.Add(hcd, res);
	IF res # Plugins.Ok THEN (* ERROR: registering the host controller failed, should not happen *)
		KernelLog.Enter; KernelLog.String("UsbHcdi: Error: Couldn't add host controller to registry."); KernelLog.Exit;
	ELSE
		INC(controllerCount);
	END;
END RegisterHostController;

(** Remove all controllers with the specified description from the controllers registry *)
PROCEDURE UnRegisterHostControllers*(CONST description : Plugins.Description);
VAR table : Plugins.Table; hcd : Hcd; i : SIGNED32;
BEGIN {EXCLUSIVE}
	controllers.GetAll(table);
	IF table # NIL THEN
		FOR i := 0 TO LEN(table)-1 DO
			hcd := table[i] (Hcd);
			IF hcd.desc = description THEN
				hcd.Cleanup;
				controllers.Remove(hcd);
			END;
		END;
	END;
END UnRegisterHostControllers;

PROCEDURE Align*(address: ADDRESS; size: SIGNED32): ADDRESS;
BEGIN
	RETURN address + SIGNED32(-address) MOD size;
END Align;

(**
 * Returns an AlignMemSpace with: memspace.data[memspace.base] is the first, <alignment>-aligned element of an
 * array of LONGINTs of the size <size>;  parameters in bytes; alignmet has to be a power of two
 *)
PROCEDURE GetAlignedMemSpace*(size, alignment : SIGNED32 ) : AlignedMemSpace;
VAR memspace : AlignedMemSpace; base, adr: ADDRESS;  len: SIZE;
BEGIN
	ASSERT(alignment >= 4);
	NEW(memspace);
	len := (size +  alignment) DIV 4;
	NEW(memspace.data, len ); (* so we will definitly find a <alignment>-aligned memory space of the size <size> *)

	adr := ADDRESSOF(memspace.data[0]);
	(* alignment *)
	base := adr + alignment - adr MOD alignment;
	(*base := adr + SIGNED32(-adr) MOD alignment;*)
	ASSERT(base MOD alignment = 0);

	memspace.base := (base - adr) DIV 4;
	ASSERT(ADDRESSOF(memspace.data[memspace.base]) = base);
	RETURN memspace;
END GetAlignedMemSpace;

(** Display textual representation of the USB tranfer status bits defined in Usbdi.Mod  *)
PROCEDURE ShowStatus*(status : Usbdi.Status);
BEGIN
	IF Debug.Trace THEN
	IF status = Usbdi.Ok THEN KernelLog.String("[Ok]"); END;
	IF status = Usbdi.ShortPacket THEN KernelLog.String("[ShortPacket]"); END;
	IF status = Usbdi.Stalled THEN KernelLog.String("[Stalled]"); END;
	IF status = Usbdi.InProgress THEN KernelLog.String("[InProgress]"); END;
	IF status = Usbdi.Error THEN KernelLog.String("[Error]"); END;
	IF status = Usbdi.Disconnected THEN KernelLog.String("[Disconnected]"); END;
	END;
END ShowStatus;

PROCEDURE ShowErrors*(errors : SET);
BEGIN
	IF Debug.Trace THEN
	IF errors = NoErrors THEN KernelLog.String("[NoErrors]"); END;
	IF errors * ShortPacket # {} THEN KernelLog.String("[ShortPacket]"); END;
	IF errors * Stalled # {} THEN KernelLog.String("[Stalled]"); END;
	IF errors * InProgress # {} THEN KernelLog.String("[InProgress]"); END;
	IF errors * Nak # {} THEN KernelLog.String("[Nak]"); END;
	IF errors * Crc # {} THEN KernelLog.String("[Crc]"); END;
	IF errors * Timeout # {} THEN KernelLog.String("[Timeout]"); END;
	IF errors * CrcTimeout # {} THEN KernelLog.String("[CRC/Timeout]"); END;
	IF errors * BitStuff # {} THEN KernelLog.String("[Bitstuff]"); END;
	IF errors * Databuffer # {} THEN KernelLog.String("[Databuffer]"); END;
	IF errors * Babble # {} THEN KernelLog.String("[Babble]"); END;
	IF errors * Internal # {} THEN KernelLog.String("[Internal]"); END;
	IF errors * Disconnected # {} THEN KernelLog.String("[Disconnected]"); END;
	IF errors * UnexpectedPid # {} THEN KernelLog.String("[UnexpectedPid]"); END;
	IF errors * TransferTooLarge # {} THEN KernelLog.String("[TransferTooLarge]"); END;
	IF errors * PidCheckFailure # {} THEN KernelLog.String("[PidCheckFailure]"); END;
	IF errors * DataToggleMismatch # {} THEN KernelLog.String("[DatatoggleMismatch]"); END;
	IF errors * DeviceNotResponding # {} THEN KernelLog.String("[DeviceNotResponding]"); END;
	IF errors * LinkTDsFailed # {} THEN KernelLog.String("[TDLinkError]"); END;
	IF errors * OutOfTDs  # {} THEN KernelLog.String("[OutOfTDs]"); END;
	END;
END ShowErrors;

(** Display textual represenation of the port status bits defined in UsbHcdi.Mod *)
PROCEDURE ShowPortStatus*(status : SET);
BEGIN
	IF Debug.Trace THEN
	IF status * PortStatusEnabled # {} THEN KernelLog.String("[Enabled]"); ELSE KernelLog.String("[Disabled]"); END;
	IF status * PortStatusDevicePresent # {} THEN
		IF status * PortStatusLowSpeed # {} THEN KernelLog.String("[LowSpeed]");
		ELSIF status * PortStatusFullSpeed # {} THEN KernelLog.String("[FullSpeed]");
		ELSIF status * PortStatusHighSpeed # {} THEN KernelLog.String("[HighSpeed]");
		ELSE
			KernelLog.String("[ERROR:Device connected but no speed indication, port enabled?]");
		END;
	END;
	IF status * PortStatusReset # {} THEN KernelLog.String("[Reset]"); END;
	IF status * PortStatusDevicePresent # {} THEN KernelLog.String("[DevicePresent]"); END;
	IF status * PortStatusError # {} THEN KernelLog.String("[Error]"); END;
	IF status * PortStatusConnectChange # {} THEN KernelLog.String("[ConnectChange]"); END;
	IF status * PortStatusSuspended # {} THEN KernelLog.String("[Suspended]"); END;
	IF status * PortStatusOverCurrent # {} THEN KernelLog.String("[OverCurrent]"); END;
	IF status * PortStatusPowered # {} THEN KernelLog.String("[Powered]"); END;
	IF status * PortStatusEnabledChange # {} THEN KernelLog.String("[EnabledChange]"); END;
	IF status * PortStatusSuspendChange # {} THEN KernelLog.String("[SuspendChange]"); END;
	IF status * PortStatusOverCurrentChange # {} THEN KernelLog.String("[OverCurrentChange]"); END;
	IF status * PortStatusWakeOnOvercurrent # {} THEN KernelLog.String("[WakeOnOvercurrent]"); END;
	IF status * PortStatusWakeOnDisconnect # {} THEN KernelLog.String("[WakeOnDisconnect]"); END;
	IF status * PortStatusWakeOnConnect # {} THEN KernelLog.String("[WakeOnConnect]"); END;
	IF status * PortStatusTestControl # {} THEN KernelLog.String("[TestControl]"); END;
	IF status * PortStatusIndicatorControl # {} THEN KernelLog.String("[IndicatorControl]"); END;
	IF status * PortStatusPortOwner # {} THEN KernelLog.String("[PortOwner]"); END;
	END;
END ShowPortStatus;

PROCEDURE GetToken (): TransferToken;
VAR
	token: TransferToken;
	i: SIGNED32;
BEGIN {EXCLUSIVE}
	IF tokenPool = NIL THEN
		NEW(token)
	ELSE
		token := tokenPool;
		tokenPool := tokenPool.next;

		(* Clear token *)
		(*Machine.Fill32(SYSTEM.VAL(ADDRESS, token), SIZEOF(TransferToken), 0)*)
		token.pipe := NIL;
		token.buffer := 0;
		token.id := 0;
		token.len := 0;
		token.errors := {};
		token.status := 0;
		token.transfered := 0;
		(*token.message.value := NIL;*)
		FOR i := 0 TO MaxTDs - 1 DO token.tds[i] := 0 END;
		token.next := NIL
	END;
	RETURN token
END GetToken;

PROCEDURE PutToken (token: TransferToken);
BEGIN {EXCLUSIVE}
	token.next := tokenPool;
	tokenPool := token
END PutToken;

PROCEDURE Cleanup;
BEGIN
	Plugins.main.Remove(controllers);
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	NEW(controllers, "UsbHcdi","USB host controller drivers");
END UsbHcdi.