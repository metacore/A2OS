MODULE UsbStorageCbi;  (** AUTHOR "cplattner/staubesv"; PURPOSE " CB/I transport layer of USB mass storage driver"; *)
(**
 * References:
 *
 *	- 	[1] Universal Serial Bus Mass Storage Class Control/Bulk/Interrupt (CBI) Transport, Revision 1.1, June 23, 2003
 *		www.usb.org
 *
 * History:
 *
 *	09.02.2006	First release (staubesv)
 *	05.07.2006	Adapted to Usbdi (staubesv)
 *	07.08.2006	Cleanups, improved error case in transport, fixed transfer offset ignored  (staubesv)
 *)

IMPORT
	KernelLog,
	Base := UsbStorageBase, Usbdi, Debug := UsbDebug;

CONST

	(* Interrupt Data Block coding, 3.4.3.1.1 in [1] *)
	Pass = 0;
	Fail = 1;
	PhaseError = 2;
	PersistentFailure = 3;

TYPE

	(** USB Mass Storage Class Control/Bulk/Interrupt (CBI) and Control/Bulk (CB) transport layer *)
	CBITransport* = OBJECT(Base.StorageDriver);

		(**
		 * The Accept Device-Specific Command class-specific request is uses by the CBI Command Transport
		 * Protocol to send a command block from a host to a device.
		 * @param cmdLen Length of the command
		 * @param cmd Command
		 * @param timeout in milliseconds
		 * @return transport status of command block
		 *)
		PROCEDURE  AcceptCommand(cmd : Usbdi.Buffer; cmdlen, timeout : LONGINT) : Usbdi.Status;
		BEGIN
			ASSERT(LEN(cmd) >= cmdlen);
			defaultPipe.SetTimeout(timeout);
			RETURN device.Request(Usbdi.ToDevice + Usbdi.Class + Usbdi.Interface, 0, 0, interface.bInterfaceNumber, cmdlen, cmd);
		END AcceptCommand;

		PROCEDURE Reset*(timeout : LONGINT) : LONGINT;
		VAR buffer, interruptData : Usbdi.BufferPtr; status : Usbdi.Status; i : LONGINT;
		BEGIN
			IF Debug.Trace & Debug.traceScRequests THEN KernelLog.String("UsbStorageCbi: Sending CB/I reset ControlTransfer"); KernelLog.Ln; END;
			NEW(buffer, 12);
			buffer[0] := CHR(1DH);
			buffer[1] := CHR(4);
			FOR i := 2 TO 11 DO buffer[i] := CHR(255) END;
			status := AcceptCommand(buffer, 12, timeout);
			IF (status = Usbdi.Disconnected) THEN
				RETURN Base.ResDisconnected;
			ELSIF (status # Usbdi.Ok) THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorageCbi: Failure on TransportCB/I-Reset Control"); KernelLog.Ln; END;
				RETURN Base.ResFatalError;
			END;
			IF transportMethod = Base.MethodCBI THEN
				IF Debug.Trace & Debug.traceScRequests THEN KernelLog.String("UsbStorageCbi: Sending CB/I reset InterruptTransfer"); KernelLog.Ln; END;
				NEW(interruptData, 8);
				interruptPipe.SetTimeout(timeout);
				status := interruptPipe.Transfer(2, 0, interruptData);
				IF status = Usbdi.Stalled THEN
					IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorageCbi: Stall on TransportCB/I-Reset Interrupt"); KernelLog.Ln; END;
					IF ~interruptPipe.ClearHalt() THEN RETURN Base.ResError END;
					IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorageCbi: Failure on TransportCB/I-Reset clear halt on Interruptpipe"); KernelLog.Ln; END;
					RETURN Base.ResFatalError;
				ELSIF status = Usbdi.InProgress THEN
					IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorageCbi: Timeout on TransportCB/I-Reset Interrupt"); KernelLog.Ln; END;
					RETURN Base.ResTimeout;
				ELSIF status = Usbdi.Disconnected THEN
					RETURN Base.ResDisconnected;
				ELSIF status # Usbdi.Ok THEN
					IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorageCbi: Failure on TransportCB/I-Reset Interrupt"); KernelLog.Ln; END;
					RETURN Base.ResFatalError;
				END;
			END;
			(* After a Command Block Reset, the Stall condition and data toggle of the device's endpoints are undefined (2.2 in [1]) *)
			IF ~bulkInPipe.ClearHalt() OR ~bulkOutPipe.ClearHalt() THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorageCbi: Failure on CB/I reset ClearHalt"); KernelLog.Ln; END;
				RETURN Base.ResFatalError;
			END;
			IF Debug.Trace & Debug.traceScRequests THEN KernelLog.String("UsbStorageCbi: CB/I reset OK"); KernelLog.Ln; END;
			RETURN Base.ResOk;
		END Reset;

		PROCEDURE Transport*(cmd : ARRAY OF CHAR; cmdlen : LONGINT; dir : SET;
			VAR buffer : ARRAY OF CHAR; ofs, bufferlen : LONGINT; VAR tlen : LONGINT; timeout : LONGINT) : LONGINT;
		VAR status : Usbdi.Status;	 interruptData : Usbdi.BufferPtr; blockStatus : LONGINT;
			b, c: Usbdi.BufferPtr; i: LONGINT;
		BEGIN
			IF Debug.Trace & Debug.traceScTransfers THEN KernelLog.String("UsbStorageCbi: Sending TransportCB/I Control"); KernelLog.Ln; END;
			NEW(c, cmdlen);
			FOR i := 0 TO cmdlen - 1 DO c[i] := cmd[i] END;
			NEW(b, bufferlen);
			FOR i := 0 TO bufferlen - 1 DO b[i] := buffer[ofs + i] END;
			status := AcceptCommand(c, cmdlen, timeout);
			IF status = Usbdi.Stalled THEN
				IF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbStorageCbi: Stall on TransportCB/I Control"); KernelLog.Ln; END;
				RETURN Base.ResError; (* sense device *)
			ELSIF status = Usbdi.InProgress THEN
				IF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbStorageCbi: Timeout on TransportCB/I Control"); KernelLog.Ln; END;
				RETURN Base.ResTimeout;
			ELSIF status = Usbdi.Disconnected THEN
				RETURN Base.ResDisconnected;
			ELSIF status # Usbdi.Ok THEN
				IF Debug.Level >= Debug.Warnings THEN
					KernelLog.String("UsbStorageCbi: Failure on TransportCB/I Control, status :"); KernelLog.Int(status, 0); KernelLog.Ln;
				END;
				RETURN Base.ResError; (* sense device *)
			END;

			IF (bufferlen # 0) THEN

				IF dir = Base.DataIn THEN
					IF Debug.Trace & Debug.traceScTransfers THEN
						KernelLog.String("UsbStorageCbi: Get "); KernelLog.Int(bufferlen, 0); KernelLog.String(" bytes from device"); KernelLog.Ln;
					END;
					bulkInPipe.SetTimeout(timeout);
					status := bulkInPipe.Transfer(bufferlen, ofs, b);
					tlen := bulkInPipe.GetActLen();
				ELSIF dir = Base.DataOut THEN
					IF Debug.Trace & Debug.traceScTransfers THEN
						KernelLog.String("UsbStorageCbi: Send "); KernelLog.Int(bufferlen, 0); KernelLog.String(" bytes to device"); KernelLog.Ln;
					END;
					bulkOutPipe.SetTimeout(timeout);
					status := bulkOutPipe.Transfer(bufferlen, ofs, b);
					tlen := bulkOutPipe.GetActLen();
				ELSE HALT(303);
				END;

				IF status = Usbdi.Stalled THEN
					IF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbStorageCbi: Stall on TransportCB/I Bulk"); KernelLog.Ln; END;
					IF ((dir = Base.DataIn) & ~bulkInPipe.ClearHalt()) OR ((dir = Base.DataOut) & ~bulkOutPipe.ClearHalt()) THEN
						IF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbStorage: Failure on TransportCB/I clear halt on Bulkpipe"); KernelLog.Ln; END;
						RETURN Base.ResFatalError
					END;
					RETURN Base.ResError; (* sense device *)
				ELSIF status = Usbdi.InProgress THEN
					IF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbStorageCbi: Timeout on TransportCB/I Bulk"); KernelLog.Ln; END;
					RETURN Base.ResTimeout;
				ELSIF status = Usbdi.Disconnected THEN
					RETURN Base.ResDisconnected;
				ELSIF status # Usbdi.Ok THEN
					IF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbStorageCbi: Failure on TransportCB/I Bulk"); KernelLog.Ln; END;
					RETURN Base.ResError; (* sense device *)
				END;
			ELSE
				tlen := 0;
			END;

			IF transportMethod = Base.MethodCBI THEN
				IF Debug.Trace & Debug.traceScRequests THEN KernelLog.String("UsbStorageCbi: Sending TransportCB/I Interrupt"); KernelLog.Ln; END;

				NEW(interruptData, 2);
				interruptPipe.SetTimeout(timeout);
				status := interruptPipe.Transfer(2, 0, interruptData);

				IF status = Usbdi.Stalled THEN
					IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorageCbi: Stall on TransportCB/I Interrupt"); KernelLog.Ln; END;
					IF interruptPipe.ClearHalt() THEN RETURN Base.ResError END;
					IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorageCbi: Failure on TransportCB/I clear halt on Interruptpipe"); KernelLog.Ln; END;
					RETURN Base.ResFatalError
				ELSIF status = Usbdi.InProgress THEN
					IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorageCbi: Timeout on TransportCB/I Interrupt"); KernelLog.Ln; END;
					RETURN Base.ResTimeout;
				ELSIF status = Usbdi.Disconnected THEN
					RETURN Base.ResDisconnected;
				ELSIF status # Usbdi.Ok THEN
					IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorageCbi: Failure on TransportCB/I Interrupt"); KernelLog.Ln; END;
					RETURN Base.ResFatalError;
				END;

				IF (transportProtocol = Base.ProtocolUFI) THEN
					IF (cmd[0] = 12X) OR (cmd[0] = 03X) THEN
						(* UFI Inquiry + Sense do not change the sense data, so we cannot be sure that those commands succeded!!! *)
						(* just go on and hope the best! *)
					ELSIF (interruptData[0] # 0X) THEN
						IF Debug.Level >= Debug.Errors THEN
							KernelLog.String("UsbStorageCbi: Error on CBI/UFI, asc = "); KernelLog.Hex(ORD(interruptData[0]), 0);
							KernelLog.String(" ascq = "); KernelLog.Hex(ORD(interruptData[1]), 0); KernelLog.Ln;
						END;
						RETURN Base.ResSenseError; (* just retry *)
					END;
					(* go on *)
				ELSIF interruptData[0] # 0X THEN
					IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorageCbi: CBI returned invalid interupt data block"); KernelLog.Ln; END;
					RETURN Base.ResSenseError; (* try to recover by manual sensing *)
				ELSE
					(* Command completion interrupt. Error handling according 3.4.3.1.1. in [1] *)
					blockStatus := ORD(interruptData[1]) MOD 4;
					CASE blockStatus OF
						|Pass: (* command status ok *)
						|Fail: RETURN Base.ResError;
						|PhaseError: RETURN Base.ResFatalError; (* reset device *)
						|PersistentFailure: RETURN Base.ResSenseError; (* request sense *)
					ELSE
						HALT(99);
					END;
				END;
			END;
			IF tlen # bufferlen THEN RETURN Base.ResShortTransfer; END;
			RETURN Base.ResOk;
		END Transport;

		PROCEDURE &Init*;
		BEGIN
			Init^;
		END Init;

	END CBITransport;

END UsbStorageCbi.
