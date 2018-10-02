MODULE BluetoothHCI;	(** AUTHOR "be"; PURPOSE "Bluetooth HCI driver"; *)

IMPORT KernelLog, Bluetooth;

CONST

	Trace = FALSE;
	TraceReceive = FALSE;
	TraceSend = FALSE;


	ModuleName = "[BTHCI]";
	TraceHCI = FALSE;
	TraceLink = FALSE;


	(* Timeouts (in ms) *)
	Timeout = 1000;
	ConnectionTimeout = 10000;

	(**--- HCI Command Packets OGF and OCF ---*)

	(** Link Control Commands *)
	ogfLinkControl* = 01H;	(** OGF, OCFs follow *)
		ocfInquiry* = 0001H;
		ocfInquiryCancel* = 0002H;
		ocfPeriodicInquiryMode* = 0003H;
		ocfExitPeriodicInquiryMode* = 0004H;
		ocfCreateConnection* = 0005H;
		ocfDisconnect* = 0006H;
		ocfAddSCOConnection* = 0007H;
		ocfAcceptConnectionRequest* = 0009H;
		ocfRejectConnectionRequest* = 000AH;
		ocfLinkKeyRequestReply* = 000BH;
		ocfLinkKeyRequestNegativeReply* = 000CH;
		ocfPINCodeRequestReply* = 000DH;
		ocfPINCodeRequestNegativeReply* = 000EH;
		ocfChangeConnectionPacketType* = 000FH;
		ocfAuthenticationRequested* = 0011H;
		ocfSetConnectionEncryption* = 0013H;
		ocfChangeConnectionLinkKey* = 0015H;
		ocfMasterLinkKey* = 0017H;
		ocfRemoteNameRequest* = 0019H;
		ocfReadRemoteSupportedFeatures* = 001BH;
		ocfReadRemoteVersionInformation* = 001DH;
		ocfReadClockOffset* = 001FH;

	(** Link Policy Commands *)
	ogfLinkPolicy* = 02H;	(** OGF, OCFs follow *)
		ocfHoldMode* = 0001H;
		ocfSniffMode* = 0003H;
		ocfExitSniffMode* = 0004H;
		ocfParkMode* = 0005H;
		ocfExitParkMode* = 0006H;
		ocfQoSSetup* = 0007H;
		ocfRoleDiscovery* = 0009H;
		ocfSwitchRole* = 000BH;
		ocfReadLinkPolicySettings* = 000CH;
		ocfWriteLinkPolicySettings* = 000DH;

	(** Host Controller & Baseband Commands *)
	ogfControl* = 03H;	(** OGF, OCFs follow *)
		ocfSetEventMask* = 0001H;
		ocfReset* = 0003H;
		ocfSetEventFilter* = 0005H;
		ocfFlush* = 0008H;
		ocfReadPINType* = 0009H;
		ocfWritePINType* = 000AH;
		ocfCreateNewUnitKey* = 000BH;
		ocfReadStoredLinkKey* = 000DH;
		ocfWriteStoredLinkKey* = 0011H;
		ocfDeleteStoredLinkKey* = 0012H;
		ocfChangeLocalName* = 0013H;
		ocfReadLocalName* = 0014H;
		ocfReadConnectionAcceptTimeout* = 0015H;
		ocfWriteConnectionAcceptTimeout* = 0016H;
		ocfReadPageTimeout* = 0017H;
		ocfWritePageTimeout* = 0018H;
		ocfReadScanEnable* = 0019H;
		ocfWriteScanEnable* = 001AH;
		ocfReadPageScanActivity* = 001BH;
		ocfWritePageScanActivity* = 001CH;
		ocfReadInquiryScanActivity* = 001DH;
		ocfWriteInquiryScanActivity* = 001EH;
		ocfReadAuthenticationEnable* = 001FH;
		ocfWriteAuthenticationEnable* = 0020H;
		ocfReadEncryptionMode* = 0021H;
		ocfWriteEncryptionMode* = 0022H;
		ocfReadClassOfDevice* = 0023H;
		ocfWriteClassOfDevice* = 0024H;
		ocfReadVoiceSetting* = 0025H;
		ocfWriteVoiceSetting* = 0026H;
		ocfReadAutomaticFlushTimeout* = 0027H;
		ocfWriteAutomaticFlushTimeout* = 0028H;
		ocfReadNumBroadcastRetrans* = 0029H;
		ocfWriteNumBroadcastRetrans* = 002AH;
		ocfReadHoldModeActivity* = 002BH;
		ocfWriteHoldModeActivity* = 002CH;
		ocfReadTransmitPowerLevel* = 002DH;
		ocfReadSCOFlowControlEnable* = 002EH;
		ocfWriteSCOFlowControlEnable* = 002FH;
		ocfSetHostCtrlToHostFlowCtrl* = 0031H;
		ocfHostBufferSize* = 0033H;
		ocfHostNumberOfCompletedPackets* = 0035H;
		ocfReadLinkSupervisionTimeout* = 0036H;
		ocfWriteLinkSupervisionTimeout* = 0037H;
		ocfReadNumberOfSupportedIAC* = 0038H;
		ocfReadCurrentIACLAP* = 0039H;
		ocfWriteCurrentIACLAP* = 003AH;
		ocfReadPageScanPeriodMode* = 003BH;
		ocfWritePageScanPeriodMode* = 003CH;
		ocfReadPageScanMode* = 003DH;
		ocfWritePageScanMode* = 003EH;

	(** Informational Parameters *)
	ogfInformational* = 04H;	(** OGF, OCFs follow *)
		ocfReadLocalVersionInformation* = 0001H;
		ocfReadLocalSupportedFeatures* = 0003H;
		ocfReadBufferSize* = 0005H;
		ocfReadCountryCode* = 0007H;
		ocfReadBDAddr* = 0009H;

	(** Status Parameters *)
	ogfStatus* = 05H;	(** OGF, OCFs follow *)
		ocfReadFailedContactCounter* = 0001H;
		ocfResetFailedContactCounter* = 0002H;
		ocfGetLinkQuality* = 0003H;
		ocfHCIReadRSSI* = 0005H;

	(** Ericsson Parameters *)
	ogfEricsson* = 03FH;
		ocfSetUARTBaudRate* = 0009H;

	(**--- ACL flags (see spec chapter 4.4.3) ---*)
	(** Packet Boundary Flag (PBF) *)
	pbfFirst* = 2;	(** first packet of higher layer message *)
	pbfContinuing* = 1;	(** continuing fragment packet of higher layer message *)

	(** Broadcast Flag (BF) *)
	bfPointToPoint* = 0;	(** point to point *)
	bfActive* = 1;	(** active broadcast *)
	bfPiconet* = 2;	(** piconet broadcast *)

	(** HCI Events *)
	EInquiryComplete* = 01X;	(** params: Status *)
	EInquiryResult* = 02X; (** params: see spec chapter 5.2.2, p. 728 *)
	EConnectionComplete* = 03X; (** params: Status, Connection_Handle (2 bytes), BD_Addr (6 bytes), Link_Type, Encryption_Mode *)
	EDisconnectionComplete* = 05X; (** params: Status, Connection_Handle (2 bytes), Reason *)
	EReadRemoteVersionInfoComplete* = 0CX;
	ECmdComplete* = 0EX; (** params: Num_HCI_Commands, Command_Opcode (2 bytes), Return_Parameters *)
	ECmdStatus* = 0FX;	(** params: Status, Num_HCI_Commands, Command-Opcode (2 bytes) *)
	ENofCompletedPackets* = 13X;
	EMaxSlotsChange* = 1BX;
	EPageScanRepModeChange* = 20X;

CONST
	(** WriteScanEnable *)
	SENoScan* = 00X;
	SEInquiry* = 01X;
	SEPage* = 02X;
	SEInquiryPage* = 03X;

	(** SetEventFilter *)
	(** filter types *)
	EFClear* = 00X;
	EFInquiryResult* = 01X;
	EFConnectionSetup* = 02X;

	(** connection types for EFInquiryResult *)
	EFIRNewDevice* = 00X;	(** requires no condition *)
	EFIRClass* = 01X;	(** requires 'class of device' (3 bytes) and 'class of device mask' (3 bytes) *)
	EFIRAddr* = 02X;	(** requires 'bd_addr' (6 bytes) *)

	(** connection types for EFConnectionSetup *)
	EFCSAll* = 00X;	(** requires 'auto accept flag' (1 byte) *)
	EFCSClass* = 01X;	(** requires 'class of device' (3 bytes), 'class of device mask' (3 bytes) and 'auto accept flag' (1 byte) *)
	EFCSAddr* = 02X;	(** requires 'bd_addr' (6 bytes) and 'auto accept flag' (1 byte) *)

	(** 'auto accept flag' for EFConnectionSetup *)
	EFCSAAOff* = 01X;	(** auto accept is off *)
	EFCSAAOn* = 02X;	(** auto accept is on, role switch is off *)
	EFCSAAOnRoleSwitch* = 03X;	(** auto accept is on, role switch is on *)


CONST
	(** link states *)
	lsUp* = 0;
	lsDown* = 1;


TYPE
	Link* = OBJECT	(** HCI link *)
		VAR
			next: Link;
			hci : HCI;
			state*: LONGINT;			(** link state *)
			remote*: Bluetooth.BDAddr;	(** remote device *)
			handle-: LONGINT;			(** connection handle *)
			type*: LONGINT;			(** connection type *)
			encryption*: LONGINT;		(** encryption mode *)
			reason*: LONGINT;			(** error code (depends on state) *)
			nofPackets-: LONGINT;		(** number of completed (transmitted or flushed) packets *)

			OnReceiveACLData*: ReceiveACLDataEvent;

		PROCEDURE &Init*(hci : HCI; remote: Bluetooth.BDAddr; handle: LONGINT);
		BEGIN
			ASSERT((0000H <= handle) & (handle <= 0EFFH));
			SELF.hci := hci; SELF.remote := remote; SELF.handle := handle;
			IF TraceLink THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Link.Init: handle =  "); KernelLog.Int(handle,0);
				KernelLog.Ln;
			END;
		END Init;

		(** send ACL data.
			PBF: packet boundary flag
			BF: broadcast flag
		*)
		PROCEDURE SendACL*(PBF, BF: LONGINT; VAR data: ARRAY OF CHAR; ofs, len: LONGINT): LONGINT;
		VAR v: LONGINT; res: WORD; aclhdr: ARRAY 4 OF CHAR;
		BEGIN
			ASSERT((pbfContinuing <= PBF) & (PBF <= pbfFirst));
			ASSERT((bfPointToPoint <= BF) & (BF <= bfPiconet));
			ASSERT((0 < len) & (len < 10000H));

			v := handle + PBF*1000H + BF*4000H;
			aclhdr[0] := CHR(v MOD 100H); aclhdr[1] := CHR(v DIV 100H);
			aclhdr[2] := CHR(len MOD 100H); aclhdr[3] := CHR(len DIV 100H);

			hci.tl.Send1H(Bluetooth.ACL, aclhdr, 4, data, ofs, len, res);

			IF TraceLink THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Link.SendACL: handle =  "); KernelLog.Int(handle,0);
				KernelLog.Ln;
			END;
			RETURN res
		END SendACL;

		PROCEDURE SendACLH*(PBF, BF: LONGINT; VAR hdr: ARRAY OF CHAR; hdrlen: LONGINT; VAR data: ARRAY OF CHAR; ofs, len: LONGINT): LONGINT;
		VAR v, totlen: LONGINT; res: WORD; aclhdr: ARRAY 4 OF CHAR;
		BEGIN
			totlen := len + hdrlen;
			ASSERT((pbfContinuing <= PBF) & (PBF <= pbfFirst));
			ASSERT((bfPointToPoint <= BF) & (BF <= bfPiconet));
			ASSERT((0 < totlen) & (totlen < 10000H));

			v := handle + PBF*1000H + BF*4000H;
			aclhdr[0] := CHR(v MOD 100H); aclhdr[1] := CHR(v DIV 100H);
			aclhdr[2] := CHR(totlen MOD 100H); aclhdr[3] := CHR(totlen DIV 100H);

			hci.tl.Send2H(Bluetooth.ACL, aclhdr, 4, hdr, hdrlen, data, ofs, len, res);

			IF TraceLink THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Link.SendACLH: handle =  "); KernelLog.Int(handle,0);
				KernelLog.Ln;
			END;
			RETURN res
		END SendACLH;

		PROCEDURE ACLDataReceived(acl: Bluetooth.ACLPacket);
		BEGIN
			IF TraceLink THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Link.ACLDataReceived: handle =  "); KernelLog.Int(handle,0);
				KernelLog.Ln;
			END;
			IF (OnReceiveACLData # NIL) THEN OnReceiveACLData(SELF, acl) END
		END ACLDataReceived;
	END Link;

	(* stupid Paco does not allow this definition before 'Link' *)
	ReceiveACLDataEvent* = PROCEDURE {DELEGATE} (sender: Link; acl: Bluetooth.ACLPacket);

	LinkEnumPar = POINTER TO RECORD
		handle: LONGINT;
		remote: Bluetooth.BDAddr;
		link: Link
	END;

	LinkEnumerator* = PROCEDURE {DELEGATE} (l: Link; par: ANY): BOOLEAN;	(** return TRUE if the enumeration should be continued *)

	LinkManager = OBJECT
		VAR
			links: Link;
			numLinks: LONGINT;

		PROCEDURE &Init*;
		BEGIN
			NEW(links, NIL,"", 0);	(* dummy head *)
			links.handle := -1;
			numLinks := 0
		END Init;

		PROCEDURE Reset;
		BEGIN
			links.next := NIL;
			numLinks := 0
		END Reset;

		PROCEDURE AddLink*(l: Link);
		BEGIN {EXCLUSIVE}
			l.next := links.next; links.next := l; INC(numLinks)
		END AddLink;

		PROCEDURE RemoveLink*(l: Link);
		VAR p,q: Link;
		BEGIN {EXCLUSIVE}
			p := links.next; q := links;
			WHILE (p # NIL) & (p # l) DO q := p; p := p.next END;
			IF (p # NIL) THEN q.next := p.next; DEC(numLinks) END
		END RemoveLink;

		PROCEDURE FindLink*(handle: LONGINT): Link;
		VAR l: Link;
		BEGIN {EXCLUSIVE}
			l := links.next;
			WHILE (l # NIL) & (l.handle # handle) DO l := l.next END;
			RETURN l
		END FindLink;

		PROCEDURE Enumerate(callback: LinkEnumerator; par: ANY);
		VAR l: Link; la: POINTER TO ARRAY OF Link; i: LONGINT;
		BEGIN
			NEW(la, numLinks);
			BEGIN {EXCLUSIVE}
				l := links.next;
				FOR i := 0 TO numLinks-1 DO la[i] := l; l := l.next END
			END;
			i := 0;
			WHILE (i < numLinks) & (callback(la[i], par)) DO
				INC(i)
			END
		END Enumerate;
	END LinkManager;

	HCI* = OBJECT
		VAR
			tl: Bluetooth.TransportLayer;
			aclQueue, eventQueue-: Bluetooth.Queue;
			linkManager*: LinkManager;

			(** info *)
			bdAddr-: Bluetooth.BDAddr;	(* device address *)
			aclMTU-, scoMTU-, aclNumPackets-, scoNumPackets-: LONGINT; (* MTUs and max. # of packets for ACL/SCO connections *)

			(** events *)
			OnConnectionComplete* : ConnectionComplete;
			OnDisconnectionComplete* : DisconnectionComplete;
			OnInquiryComplete* : InquiryComplete;
			OnConnect*: ConnectionEvent;
			OnDisconnect*: ConnectionEvent;
			OnInquiry*: InquiryEvent;
			OnEvent*: GeneralEvent;
			OnError*: ErrorEvent;

		PROCEDURE &Init*(transportLayer: Bluetooth.TransportLayer);
		VAR q: Bluetooth.Queue;
		BEGIN
			tl := transportLayer;
			NEW(linkManager);

			NEW(eventQueue); tl.SetSink(Bluetooth.Event, eventQueue);
			eventQueue.RegisterPacketFilter(EricssonFilter, EricssonHandler);
			eventQueue.RegisterPacketFilter(EventFilter, EventHandler);

			NEW(aclQueue); tl.SetSink(Bluetooth.ACL, aclQueue);
			aclQueue.RegisterPacketFilter(ACLFilter, ACLHandler);

			q := tl.GetSink(Bluetooth.Default);
			q.RegisterPacketFilter(ErrorFilter, ErrorHandler);
		END Init;

		PROCEDURE Close*;
		BEGIN {EXCLUSIVE}
			IF TraceHCI THEN
				KernelLog.String(ModuleName); KernelLog.String("HCI.Close: ...");
				KernelLog.Ln;
			END;
			tl.Close;
			eventQueue.Close; aclQueue.Close;
			IF TraceHCI THEN
				KernelLog.String(ModuleName); KernelLog.String("HCI.Close: done.");
				KernelLog.Ln;
			END;
		END Close;

		(** initialize the module, get BDADDR, MTUs, etc *)
		PROCEDURE Initialize*(): LONGINT;
		VAR res: WORD;
		BEGIN
			IF TraceHCI THEN
				KernelLog.String(ModuleName);
				KernelLog.String("HCI.Initialize: ...");
				KernelLog.Ln;
			END;
			res := Reset();
			IF (res # 0) THEN
				KernelLog.String(ModuleName);
				KernelLog.String("HCI.Initialize: Reset failed. res = 0x"); KernelLog.Hex(res,-2);
				KernelLog.Ln;
				RETURN res
			END;
			res := ReadBDAddr(bdAddr);
			IF (res # 0) THEN
				KernelLog.String(ModuleName);
				KernelLog.String("HCI.Initialize: ReadBDaddr failed. res = 0x"); KernelLog.Hex(res,-2);
				KernelLog.Ln;
				RETURN res
			END;
			res := ReadBufferSize(aclMTU, scoMTU, aclNumPackets, scoNumPackets);
			IF TraceHCI THEN
				KernelLog.String(ModuleName);
				KernelLog.String("HCI.Initialize: done. ReadBufferSize res = "); KernelLog.Int(res,0);
				KernelLog.Ln;
			END;
			RETURN res;
		END Initialize;

		(** enumerate all active links. par is passed back to the callback procedure *)
		PROCEDURE EnumerateLinks*(enumCallback: LinkEnumerator; par: ANY);
		BEGIN
			linkManager.Enumerate(enumCallback, par)
		END EnumerateLinks;

		(** find a link. If 'handle'=-1, the first link to 'remote' is returned *)
		PROCEDURE FindLinkCallback(l: Link; par: ANY): BOOLEAN;
		BEGIN
			WITH par: LinkEnumPar DO
				IF (par.handle # -1) THEN
					IF (par.handle = l.handle) THEN par.link := l END
				ELSE
					IF (par.remote = l.remote) THEN par.link := l END
				END;
				RETURN par.link = NIL
			END
		END FindLinkCallback;

		PROCEDURE FindLink*(handle: LONGINT; remote: Bluetooth.BDAddr): Link;
		VAR lep: LinkEnumPar;
		BEGIN
			NEW(lep); lep.handle := handle; lep.remote := remote; lep.link := NIL;
			linkManager.Enumerate(FindLinkCallback, lep);
			RETURN lep.link
		END FindLink;

		(** send a HCI command. Return values:
				res: result code
				pending: TRUE if the command is pending
				packet: reply packet from BT host (may be NIL)
		*)
		PROCEDURE SendCommand*(OGF, OCF: LONGINT; params: ARRAY OF CHAR; len: LONGINT;
										VAR packet: Bluetooth.EventPacket;
										 VAR pending: BOOLEAN;
										 VAR res: WORD);
		BEGIN {EXCLUSIVE}
			InSendCommand(OGF, OCF, params, len, packet, pending, res)
		END SendCommand;

		PROCEDURE InSendCommand(OGF, OCF: LONGINT; params: ARRAY OF CHAR; len: LONGINT;
										VAR packet: Bluetooth.EventPacket;
										VAR pending: BOOLEAN;
										VAR res: WORD);
		VAR
			cmd: POINTER TO ARRAY  OF CHAR; i: LONGINT;
		BEGIN (* EXCLUSIVE *)
			NEW(cmd,3+len);
			IF TraceHCI THEN
				KernelLog.String(ModuleName);
				KernelLog.String("HCI.InSendCommand: OGF= 0x"); KernelLog.Hex(OGF,-2);
				KernelLog.String(" OCF= 0x"); KernelLog.Hex(OCF,-2);
				KernelLog.String(" params= ");
				FOR i := 0 TO len-1 DO
					KernelLog.String("0x"); KernelLog.Hex(ORD(params[i]), -2);
				END;
				KernelLog.String(" ..."); KernelLog.Ln;
			END;
			pending := FALSE;
			ComposeCommandHeader(OGF, OCF, len, cmd^);
			FOR i := 0 TO len-1 DO cmd[3+i] := params[i] END;
			tl.Send(Bluetooth.Command, cmd^, 0, 3+len, res);
			IF (res = 0) THEN
				GetEvent(Timeout,packet,res);
				IF (res = 0) THEN
					IF (packet.code = ECmdComplete) & (packet.paramLen >= 3) &
						(packet.params[1] = cmd[0]) & (packet.params[2] = cmd[1]) THEN
							(* in BT V1.1 all commands that return a command complete event have 'status' (0 = ok)
								as the first parameter. *)
						res := ORD(packet.params[3]);
						(* hack... *)
						IF (OGF = ogfControl) & (OCF = ocfReset) & (res = 0) THEN
							linkManager.Reset
						END;
					ELSIF (packet.code = ECmdStatus) & (packet.paramLen >= 3) &
							(packet.params[2] = cmd[0]) & (packet.params[3] = cmd[1]) THEN
						res := ORD(packet.params[0]);
						pending := TRUE;
					ELSE
						res := Bluetooth.ErrInvalidEvent;
						IF TraceHCI THEN
							KernelLog.String(ModuleName);
							KernelLog.String("HCI.InSendCommand: invalid event received:"); KernelLog.Ln;
							KernelLog.String("  event code: "); KernelLog.Hex(ORD(packet.code), -2); KernelLog.Ln;
							KernelLog.String("  parameters: ");
							FOR i := 0 TO packet.paramLen-1 DO
								KernelLog.Hex(ORD(packet.params[i]), -2); KernelLog.Char(" ")
							END;
							KernelLog.Ln;
						END;
					END;
					IF TraceHCI THEN
						KernelLog.String(ModuleName);
						KernelLog.String("HCI.InSendCommand: event received. event code = 0x"); KernelLog.Hex(ORD(packet.code), -2);
						KernelLog.String(" result =  0x"); KernelLog.Hex(res,-2);
						KernelLog.String(" pending = "); IF pending THEN KernelLog.String("TRUE"); ELSE KernelLog.String("FALSE"); END;
						KernelLog.Ln;
					END;
				ELSE
					KernelLog.String(ModuleName);
					KernelLog.String("HCI.InSendCommand: GetEvent failed. res = 0x"); KernelLog.Hex(res,-2);
					KernelLog.Ln;
				END;
			ELSE
				KernelLog.String(ModuleName);
				KernelLog.String("HCI.InSendCommand: tl.Send failed. res =  0x"); KernelLog.Hex(res,-2);
				KernelLog.Ln;
			END;
			IF TraceHCI THEN
				KernelLog.String(ModuleName);
				KernelLog.String("HCI.InSendCommand: done.");
				KernelLog.Ln;
			END;
		END InSendCommand;

		PROCEDURE GetEvent*(timeout: LONGINT; VAR event: Bluetooth.EventPacket; VAR res: WORD);
		VAR p: Bluetooth.Packet;
		BEGIN
			IF TraceHCI THEN
				KernelLog.String(ModuleName);
				KernelLog.String("HCI.GetEvent: ...");
				KernelLog.Ln;
			END;
			eventQueue.Get(p, timeout, res);
			IF (res = 0) THEN
				IF (p IS Bluetooth.EventPacket) THEN
					event := p(Bluetooth.EventPacket);
				ELSE
					IF TraceHCI THEN
						KernelLog.String(ModuleName);
						KernelLog.String("HCI.GetEvent: wrong packet received");
						KernelLog.Ln;
					END;
					res := Bluetooth.ErrInvalidPacket;
				END
			ELSE
				IF TraceHCI THEN
					KernelLog.String(ModuleName);
					KernelLog.String("HCI.GetEvent: eventQueue.Get failed. res = 0x"); KernelLog.Hex(res,-2);
					KernelLog.Ln;
				END;
			END;
			IF TraceHCI THEN
				KernelLog.String(ModuleName);
				KernelLog.String("HCI.GetEvent: done.");
				KernelLog.Ln;
			END;
		END GetEvent;

		(**--- often used HCI commands ---*)

		(* ------- link controller  commands -------- *)

		PROCEDURE Inquiry*(lap : LONGINT;inquiryLength : LONGINT; numResponses : LONGINT) : LONGINT;
		VAR
			par: ARRAY 5 OF CHAR;
			event: Bluetooth.EventPacket;
			pending: BOOLEAN;
			res: WORD;
		BEGIN
			par[0] := CHR(lap MOD 100H);
			par[1] := CHR((lap DIV 100H) MOD 100H);
			par[2] := CHR(lap DIV 10000H);
			par[3] := CHR(inquiryLength);
			par[4] := CHR(numResponses);
			InSendCommand(ogfLinkControl,ocfInquiry,par,5,event,pending,res);
			RETURN res;
		END Inquiry;

		PROCEDURE CreateConnection*(bdAddr: Bluetooth.BDAddr; clkofs: LONGINT): LONGINT;
		(* TODO: parameters!!! *)
		VAR
			par: ARRAY 13 OF CHAR;
			event: Bluetooth.EventPacket;
			pending: BOOLEAN;
			i: LONGINT; res: WORD;
		BEGIN
			FOR i := 0 TO Bluetooth.BDAddrLen-1 DO par[i] := bdAddr[i] END;
			par[6] := 08X; par[7] := 00X;	(* packet type: DM1 only *)
			par[8] := 00X;	(* page scan repetition mode: R0 *)
			par[9] := 00X;	(* page scan mode: mandatory page scan mode *)
			par[10] := CHR(clkofs MOD 100H); par[11] := CHR(clkofs DIV 100H MOD 100H);	(* clock offset *)
			par[12] := 00X;	(* allow role switch: local device master, no role switch *)
			InSendCommand(ogfLinkControl, ocfCreateConnection, par, 13, event, pending, res);
			RETURN res
		END CreateConnection;

		PROCEDURE Disconnect*(linkHandle,reason : LONGINT) : LONGINT;
		VAR
			par: ARRAY 3 OF CHAR;
			event: Bluetooth.EventPacket;
			pending: BOOLEAN;
			res: WORD;
		BEGIN
			par[0] := CHR(linkHandle MOD 100H);
			par[1] := CHR(linkHandle DIV 100H);
			par[2] := CHR(reason);
			InSendCommand(ogfLinkControl,ocfDisconnect,par,3,event,pending, res);
			RETURN res;
		END Disconnect;

		(* ------- host controller & bas band commands -------- *)

		PROCEDURE SetEventMask*(eventMask : LONGINT) : LONGINT;
		VAR
			par : ARRAY 8 OF CHAR;
			res: WORD;
			event: Bluetooth.EventPacket;
			pending: BOOLEAN;
		BEGIN
			(* TO DO *)
			par[0] := CHR(eventMask MOD 100H); eventMask := eventMask DIV 100H;
			par[1] := CHR(eventMask MOD 100H); eventMask := eventMask DIV 100H;
			par[2] := CHR(eventMask MOD 100H); eventMask := eventMask DIV 100H;
			par[3] := CHR(eventMask);

			InSendCommand(ogfControl, ocfSetEventMask, par, 8, event, pending, res);
			RETURN res;
		END SetEventMask;


		PROCEDURE Reset*(): LONGINT;
		VAR
			pending: BOOLEAN;
			event: Bluetooth.EventPacket;
			res: WORD;
		BEGIN
			IF TraceHCI THEN
				KernelLog.String(ModuleName);
				KernelLog.String("HCI.Reset: ..."); KernelLog.Ln;
			END;
			eventQueue.Clear;
			InSendCommand(ogfControl, ocfReset, "", 0, event, pending, res);
			IF pending & (res = 0) THEN res := Bluetooth.Error END;
			IF TraceHCI THEN
				KernelLog.String(ModuleName);
				KernelLog.String("HCI.Reset: done. res = "); KernelLog.Int(res,0); KernelLog.Ln;
			END;
			RETURN res
		END Reset;

		PROCEDURE SetEventFilter*(type, conditionType: CHAR; condition: ARRAY OF CHAR): LONGINT;
		VAR
			par: ARRAY 9 OF CHAR;
			i, len: LONGINT; res: WORD;
			event: Bluetooth.EventPacket;
			pending: BOOLEAN;
		BEGIN
			res := Bluetooth.ErrInvalidParameters;
			CASE type OF
			| EFClear: len := 1
			| EFInquiryResult:
				CASE conditionType OF
				| EFIRNewDevice: len := 2
				| EFIRClass: len := 8
				| EFIRAddr: len := 8
				ELSE RETURN res
				END
			| EFConnectionSetup:
				CASE conditionType OF
				| EFCSAll: len := 3
				| EFCSClass: len := 9
				| EFCSAddr: len := 9
				ELSE RETURN res
				END
			ELSE RETURN res
			END;

			par[0] := type;
			par[1] := conditionType;
			FOR i := 0 TO len-3 DO par[2+i] := condition[i] END;

			InSendCommand(ogfControl, ocfSetEventFilter, par, len, event, pending, res);
			IF pending & (res = 0) THEN res := Bluetooth.Error END;
			RETURN res
		END SetEventFilter;

		PROCEDURE WriteScanEnable*(mode: CHAR): LONGINT;
		VAR
			par: ARRAY 1 OF CHAR;
			pending: BOOLEAN;
			event: Bluetooth.EventPacket;
			res: WORD;
		BEGIN
			par[0] := mode;
			InSendCommand(ogfControl, ocfWriteScanEnable, par, 1, event, pending, res);
			IF pending & (res = 0) THEN res := Bluetooth.Error END;
			RETURN res
		END WriteScanEnable;


		PROCEDURE ReadScanEnable*(VAR scanEnable : CHAR) : LONGINT;
		VAR
			pending: BOOLEAN;
			event: Bluetooth.EventPacket;
			res : WORD;
		BEGIN
			InSendCommand(ogfControl,ocfReadScanEnable,"",0,event,pending,res);
			scanEnable := event.params[4];
			IF pending & (res = 0) THEN res := Bluetooth.Error END;
			RETURN res;
		END ReadScanEnable;

		PROCEDURE WriteLinkSupervisionTimeout*(inHandle, linkTimeout : LONGINT) : LONGINT;
		VAR
			par: ARRAY 4 OF CHAR;
			pending: BOOLEAN;
			event: Bluetooth.EventPacket;
			res : WORD;
			outHandle : LONGINT;
		BEGIN
			par[0] := CHR(inHandle MOD 100H);
			par[1] := CHR(inHandle DIV 100H);
			par[2] := CHR(linkTimeout MOD 100H);
			par[3] := CHR(linkTimeout DIV 100H);
			InSendCommand(ogfControl,ocfWriteLinkSupervisionTimeout,par,4,event,pending,res);
			IF pending THEN
				KernelLog.String(ModuleName);
				KernelLog.String("HCI.WriteLinkSupervisonTimout: pending! - res = "); KernelLog.Int(res,0);
				KernelLog.Ln;
				res := Bluetooth.ErrInvalidEvent;
			ELSIF (res = 0) THEN
				outHandle := (ORD(event.params[4]) + ORD(event.params[5]) * 100H) MOD 1000H;
				IF(outHandle # inHandle) THEN
					KernelLog.String(ModuleName);
					KernelLog.String("HCI.WriteLinkSupervisonTimout: error ?! - outHandle = "); KernelLog.Int(outHandle,0);
					KernelLog.String("; inHandle = "); KernelLog.Int(inHandle,0);
					KernelLog.Ln;
				END;
			END;
			RETURN res;
		END WriteLinkSupervisionTimeout;

		PROCEDURE ReadLinkSupervisionTimeout*(inHandle : LONGINT; VAR linkTimeout : LONGINT) : LONGINT;
		VAR
			par: ARRAY 2 OF CHAR;
			pending: BOOLEAN;
			event: Bluetooth.EventPacket;
			res : WORD;
			outHandle : LONGINT;
		BEGIN
			par[0] := CHR(inHandle MOD 100H);
			par[1] := CHR(inHandle DIV 100H);
			InSendCommand(ogfControl,ocfReadLinkSupervisionTimeout,par,2,event,pending,res);
			IF pending THEN
				KernelLog.String(ModuleName);
				KernelLog.String("HCI.ReadLinkSupervisonTimout: pending! - res = "); KernelLog.Int(res,0);
				KernelLog.Ln;
				res := Bluetooth.ErrInvalidEvent;
			ELSIF (res = 0) THEN
				outHandle := (ORD(event.params[4]) + ORD(event.params[5]) * 100H) MOD 1000H;
				IF(outHandle # inHandle) THEN
					KernelLog.String(ModuleName);
					KernelLog.String("HCI.ReadLinkSupervisonTimout: error ?! - outHandle = "); KernelLog.Int(outHandle,0);
					KernelLog.String("; inHandle = "); KernelLog.Int(inHandle,0);
					KernelLog.Ln;
				ELSE
					linkTimeout := ORD(event.params[6]) + ORD(event.params[7]) * 100H;
				END;
			END;
			RETURN res;
		END ReadLinkSupervisionTimeout;

		(* ------- Erricsson  paramters -------- *)

		PROCEDURE EricssonSetUARTBaudRate*(baudRate : CHAR):LONGINT;
		VAR
			par: ARRAY 1 OF CHAR;
			pending: BOOLEAN;
			event: Bluetooth.EventPacket;
			res : WORD;
		BEGIN
			par[0] := baudRate;
			InSendCommand(ogfEricsson,ocfSetUARTBaudRate,par,LEN(par),event,pending,res);
			IF pending THEN
				KernelLog.String(ModuleName);
				KernelLog.String("HCI.EricssonSetUARTBaudRate: pending! - res = "); KernelLog.Int(res,0);
				KernelLog.Ln;
			END;
			IF pending & (res = 0) THEN res := Bluetooth.Error END;
			RETURN res;
		END EricssonSetUARTBaudRate;

		(* ------- Informational paramters -------- *)

		PROCEDURE ReadBDAddr*(VAR bdAddr: Bluetooth.BDAddr): LONGINT;
		VAR
			event: Bluetooth.EventPacket;
			pending: BOOLEAN;
			res: WORD; i: LONGINT;
		BEGIN
			IF TraceHCI THEN
				KernelLog.String(ModuleName);
				KernelLog.String("HCI.ReadBDAddr: ...");
				KernelLog.Ln;
			END;
			InSendCommand(ogfInformational, ocfReadBDAddr, "", 0, event, pending, res);
			IF pending THEN res := Bluetooth.ErrInvalidEvent
			ELSIF (res = 0) THEN
				FOR i := 0 TO Bluetooth.BDAddrLen-1 DO bdAddr[i] := event.params[4+i] END;
			END;
			IF TraceHCI THEN
				KernelLog.String(ModuleName);
				KernelLog.String("HCI.ReadBDAddr: done. res = "); KernelLog.Int(res,0);
				KernelLog.Ln;
			END;
			RETURN res
		END ReadBDAddr;

		PROCEDURE ReadBufferSize*(VAR aclMaxLen, scoMaxLen, aclNumPackets, scoNumPackets: LONGINT): LONGINT;
		VAR
			event: Bluetooth.EventPacket;
			pending: BOOLEAN;
			res: WORD;
		BEGIN
			InSendCommand(ogfInformational, ocfReadBufferSize, "", 0, event, pending, res);
			IF pending THEN res := Bluetooth.ErrInvalidEvent
			ELSIF (res = 0) THEN
				aclMaxLen := ORD(event.params[5])*100H+ORD(event.params[4]);
				scoMaxLen := ORD(event.params[6]);
				aclNumPackets := ORD(event.params[8])*100H+ORD(event.params[7]);
				scoNumPackets := ORD(event.params[10])*100H+ORD(event.params[9])
			END;
			RETURN res
		END ReadBufferSize;


		(*--- HCI event handling ---*)
		PROCEDURE EventFilter(packet: Bluetooth.Packet): BOOLEAN;
		VAR event: Bluetooth.EventPacket; ec: CHAR;
		BEGIN
			event := packet(Bluetooth.EventPacket); ec := event.code;
			RETURN
				(ec = EConnectionComplete)
				OR (ec = EDisconnectionComplete)
				OR 	(ec = EInquiryResult)
				OR (ec = EInquiryComplete)
				OR (ec = ENofCompletedPackets)
				OR 	(ec = EMaxSlotsChange)
				OR 	(ec = EPageScanRepModeChange)
				OR (* status event to indicate host is ready *)
				((ec = ECmdStatus) & (event.params[0] = 0X) & (event.params[2] = 0X) & (event.params[3] = 0X))
				OR	(* command event to indicate host is ready *)
				((ec = ECmdComplete) & (event.params[1] = 0X) & (event.params[2] = 0X))
		END EventFilter;

		PROCEDURE EventHandler(packet: Bluetooth.Packet);
		VAR
			event: Bluetooth.EventPacket;
			i : LONGINT;
		BEGIN
			event := packet(Bluetooth.EventPacket);
			IF TraceHCI THEN
				KernelLog.String(ModuleName);
				KernelLog.String("HCI.EventHandler: event.code = 0x"); KernelLog.Hex(ORD(event.code),-2);
				KernelLog.String(" ..."); KernelLog.Ln;
			END;
			IF (event.code = EConnectionComplete) THEN
				EventConnectionCompleteOLD(event);
			ELSIF (event.code = EDisconnectionComplete) THEN
				EventDisconnectionCompleteOLD(event);
			ELSIF (event.code = EInquiryResult) THEN
				EventInquiryResult(event);
			ELSIF (event.code = ENofCompletedPackets) THEN
				EventNumOfCompletedPackets(event);
			ELSIF (event.code = EInquiryComplete) THEN
				EventInquiryComplete(event);
			ELSIF (event.code = EMaxSlotsChange) THEN
				EventMaxSlotsChange(event);
			ELSIF (event.code = EPageScanRepModeChange) THEN
				EventPageScanRepModeChange(event);
			ELSIF ((event.code = ECmdStatus) OR (event.code = ECmdComplete)) THEN
				(* ignore - indicates that the host is ready *)
			ELSE
				KernelLog.String(ModuleName);
				KernelLog.String("HCI.EventHandler: unhandled event ! event.code = 0x");
				KernelLog.Hex(ORD(event.code),-2);  KernelLog.String(" params:"); KernelLog.Ln;
				FOR i:= 0 TO event.paramLen-1 DO
					KernelLog.Hex(ORD(event.params[i]),-2); KernelLog.String(" ");
				END;
				KernelLog.Ln;
			END;
			IF TraceHCI THEN
				KernelLog.String(ModuleName);
				KernelLog.String("HCI.EventHandler: done."); KernelLog.Ln;
			END;
		END EventHandler;


		PROCEDURE EventInquiryComplete(event: Bluetooth.EventPacket);
		VAR
			status : LONGINT;
		BEGIN
			status := ORD(event.params[0]);
			IF (OnInquiryComplete # NIL) THEN
				OnInquiryComplete(SELF,status);
			END;
		END EventInquiryComplete;

		PROCEDURE EventInquiryResult(event: Bluetooth.EventPacket);
		VAR
			nr,psrm, pspm, psm, co: LONGINT;
			bdAddr : Bluetooth.BDAddr;
			class : Bluetooth.DeviceClass;
			i,k,ofs : LONGINT;
		BEGIN
			IF (OnInquiry # NIL) THEN
				i := 0; nr := ORD(event.params[0]);
				WHILE (i < nr) DO
					ofs := 1 + i*14;
					FOR k := 0 TO Bluetooth.BDAddrLen-1 DO
						bdAddr[k] := event.params[ofs+k]
					END;
					psrm := ORD(event.params[ofs+6]);
					pspm := ORD(event.params[ofs+7]);
					psm := ORD(event.params[ofs+8]);
					FOR k := 0 TO Bluetooth.DeviceClassLen-1 DO
						class[k] := event.params[ofs+9+k]
					END;
					co := ORD(event.params[ofs+12])+LONG(ORD(event.params[ofs+13]))*100H;
					OnInquiry(SELF,bdAddr,class,psrm,pspm,psm,co);
					INC(i);
				END;
			END;
		END EventInquiryResult;


		PROCEDURE EventConnectionComplete(event: Bluetooth.EventPacket);
		VAR
			status,handle : LONGINT;
			bdAddr : Bluetooth.BDAddr;
			linkType ,encryMode: LONGINT;
			i : LONGINT;
		BEGIN
			status := ORD(event.params[0]);
			handle := (ORD(event.params[2])*100H + ORD(event.params[1])) MOD 1000H;
			FOR i := 0 TO Bluetooth.BDAddrLen-1 DO
				bdAddr[i] := event.params[3+i]
			END;
			linkType := ORD(event.params[9]);
			encryMode := ORD(event.params[10]);
			IF TraceHCI THEN
				KernelLog.String(ModuleName);
				KernelLog.String("HCI.EventConnectionComplete: status = 0x"); KernelLog.Hex(status,-2);
				KernelLog.String("; handle = "); KernelLog.Int(handle,0); KernelLog.String("; bdAddr = ");
				FOR i:= 0 TO Bluetooth.BDAddrLen-1 DO
					KernelLog.Hex(ORD(bdAddr[i]),-2);
				END;
				KernelLog.String("; linkType = "); KernelLog.Int(linkType,0);
				KernelLog.String("; encryptionMode = "); KernelLog.Int(encryMode,0);
				KernelLog.Ln;
			END;
			IF (OnConnectionComplete # NIL) THEN
				OnConnectionComplete(SELF,status,handle,bdAddr,linkType,encryMode);
			END;
		END EventConnectionComplete;

		PROCEDURE EventDisconnectionComplete(event: Bluetooth.EventPacket);
		VAR
			status,handle,reason : LONGINT;
		BEGIN
			status := ORD(event.params[0]);
			handle := (ORD(event.params[2])*100H + ORD(event.params[1])) MOD 1000H;
			reason :=  ORD(event.params[3]);
			IF TraceHCI THEN
				KernelLog.String(ModuleName);
				KernelLog.String("HCI.EventDisconnectionComplete: status = 0x"); KernelLog.Hex(status,-2);
				KernelLog.String("; handle = "); KernelLog.Int(handle,0);
				KernelLog.String("; reason = 0x"); KernelLog.Hex(reason,-2);
				KernelLog.Ln;
			END;
			IF (OnDisconnectionComplete # NIL) THEN
				OnDisconnectionComplete(SELF,status,handle,reason);
			END;
		END EventDisconnectionComplete;

		PROCEDURE EventConnectionCompleteOLD(event: Bluetooth.EventPacket);
		VAR
			status,handle,i : LONGINT;
			bdAddr : Bluetooth.BDAddr;
			link : Link;
		BEGIN
			status := ORD(event.params[0]);
			IF (status = 0) THEN
				handle := (ORD(event.params[2])*100H + ORD(event.params[1])) MOD 1000H;
				FOR i := 0 TO Bluetooth.BDAddrLen-1 DO
					bdAddr[i] := event.params[3+i]
				END;
				link := linkManager.FindLink(handle);
				IF (link = NIL) THEN
					NEW(link,SELF, bdAddr,handle);
					linkManager.AddLink(link);
				END;
				link.state := lsUp;
				link.type := ORD(event.params[9]);
				link.encryption := ORD(event.params[10]);

				IF TraceHCI THEN
					KernelLog.String(ModuleName);
					KernelLog.String("HCI.EventConnectionCompleteOLD: status = 0x"); KernelLog.Hex(status,-2);
					KernelLog.String("; handle = "); KernelLog.Int(link.handle,0); KernelLog.String("; bdAddr = ");
					FOR i:= 0 TO Bluetooth.BDAddrLen-1 DO
						KernelLog.Hex(ORD(bdAddr[i]),-2);
					END;
					KernelLog.String("; linkType = "); KernelLog.Int(link.type,0);
					KernelLog.String("; encryptionMode = "); KernelLog.Int(link.encryption,0);
					KernelLog.Ln;
				END;
			ELSE
				handle := -1; link := NIL;
				IF TraceHCI THEN
					KernelLog.String(ModuleName);
					KernelLog.String("HCI.EventConnectionCompleteOLD: status = 0x"); KernelLog.Hex(status,-2);KernelLog.Ln;
				END;
			END;
			IF (OnConnect # NIL) THEN
				OnConnect(SELF,link,status)
			END;
		END EventConnectionCompleteOLD;

		PROCEDURE EventDisconnectionCompleteOLD(event: Bluetooth.EventPacket);
		VAR
			status,handle : LONGINT;
			link : Link;
		BEGIN
			status := ORD(event.params[0]);
			IF (status = 0) THEN
				handle := (ORD(event.params[2])*100H + ORD(event.params[1])) MOD 1000H;
				link := linkManager.FindLink(handle);
				IF (link # NIL) THEN
					link.state := lsDown;
					link.reason :=  ORD(event.params[3]);
					linkManager.RemoveLink(link);
				END;
				IF TraceHCI THEN
					KernelLog.String(ModuleName);
					KernelLog.String("HCI.EventDisconnectionCompleteOLD: status = 0x"); KernelLog.Hex(status,-2);
					KernelLog.String("; handle = "); KernelLog.Int(handle,0);
					KernelLog.String("; reason = 0x"); KernelLog.Hex(link.reason,-2);
					KernelLog.Ln;
				END;
			ELSE
				link := NIL;
				IF TraceHCI THEN
					KernelLog.String(ModuleName);
					KernelLog.String("HCI.EventDisconnectionCompleteOLD: status = 0x"); KernelLog.Hex(status,-2);KernelLog.Ln;
				END;
			END;
			IF (OnDisconnect # NIL) THEN
				OnDisconnect(SELF,link,status)
			END;
		END EventDisconnectionCompleteOLD;

		PROCEDURE EventNumOfCompletedPackets(event: Bluetooth.EventPacket);
		VAR
			numOfHandles,handle,numOfCompletedPackets : LONGINT;
			link : Link;
			ofs,i : LONGINT;
		BEGIN
			i := 0; numOfHandles := ORD(event.params[0]);
			WHILE (i < numOfHandles) DO
				ofs := 1 + i*4;
				handle := (ORD(event.params[ofs])+LONG(ORD(event.params[ofs+1]))*100H) MOD 1000H;
				numOfCompletedPackets := ORD(event.params[ofs+2])+LONG(ORD(event.params[ofs+3]))*100H;
				link := linkManager.FindLink(handle);
				IF (link # NIL) THEN
					INC(link.nofPackets, numOfCompletedPackets);
				END;
				INC(i);
			END;
		END EventNumOfCompletedPackets;

		PROCEDURE EventMaxSlotsChange(event: Bluetooth.EventPacket);
		VAR
			handle,maxSlots : LONGINT;
		BEGIN
			handle := (ORD(event.params[1])*100H + ORD(event.params[0])) MOD 1000H;
			maxSlots := ORD(event.params[2]);
			KernelLog.String(ModuleName);
			KernelLog.String("EventMaxSlotsChange:  handle = "); KernelLog.Int(handle,0);
			KernelLog.String(" max slots = "); KernelLog.Int(maxSlots,0);
			KernelLog.Ln
		END EventMaxSlotsChange;

		PROCEDURE EventPageScanRepModeChange(event: Bluetooth.EventPacket);
		VAR
			i : LONGINT;
		BEGIN
			KernelLog.String(ModuleName);
			KernelLog.String("EventPageScanRepititionModeChange:  bdAddr = ");
			FOR i := 0 TO Bluetooth.BDAddrLen-1 DO
				KernelLog.Hex(ORD(event.params[i]),-2);
			END;
			KernelLog.String(" mode = R"); KernelLog.Int(ORD(event.params[Bluetooth.BDAddrLen]),0);
			KernelLog.Ln
		END EventPageScanRepModeChange;


		PROCEDURE EricssonFilter(packet: Bluetooth.Packet): BOOLEAN;
		BEGIN RETURN packet(Bluetooth.EventPacket).code = 0FFX
		END EricssonFilter;

		PROCEDURE EricssonHandler(packet: Bluetooth.Packet);
		VAR event: Bluetooth.EventPacket; i: LONGINT;
		BEGIN
			event := packet(Bluetooth.EventPacket);
			KernelLog.Enter;
			CASE event.params[0] OF
				| 01X: KernelLog.String("Ericsson OSE crash")
				| 04X: KernelLog.String("Ericsson OSE pool event")
				| 06X: KernelLog.String("Message from Ericsson module on TL '"); KernelLog.String(tl.name); KernelLog.String("': ");
							FOR i := 0 TO ORD(event.params[1])-1 DO KernelLog.Char(event.params[2+i]) END;
				ELSE KernelLog.String("unknown Ericsson event")
			END;
			KernelLog.Exit
		END EricssonHandler;


		PROCEDURE ACLFilter(packet: Bluetooth.Packet): BOOLEAN;
		BEGIN RETURN TRUE
		END ACLFilter;

		PROCEDURE ACLHandler(packet: Bluetooth.Packet);
		VAR acl: Bluetooth.ACLPacket; l: Link;
		BEGIN
			IF TraceHCI THEN
				KernelLog.String(ModuleName);
				KernelLog.String("HCI.ACLHandler: ..."); KernelLog.Ln;
			END;
			acl := packet(Bluetooth.ACLPacket);
			l := linkManager.FindLink(acl.handle);
			IF (l # NIL) THEN l.ACLDataReceived(acl) END;
			IF TraceHCI THEN
				KernelLog.String(ModuleName);
				KernelLog.String("HCI.ACLHandler: done."); KernelLog.Ln;
			END;
		END ACLHandler;

		PROCEDURE ErrorFilter(packet: Bluetooth.Packet): BOOLEAN;
		BEGIN RETURN (packet IS Bluetooth.UnknownPacket)
		END ErrorFilter;

		PROCEDURE ErrorHandler(packet: Bluetooth.Packet);
		BEGIN
			IF (OnError # NIL) THEN
				OnError(packet)
			END
		END ErrorHandler;
	END HCI;

	ConnectionComplete* = PROCEDURE {DELEGATE} (sender: HCI; status, handle: LONGINT;
														bdAddr: Bluetooth.BDAddr; linkType, encryMode: LONGINT);
	DisconnectionComplete* = PROCEDURE {DELEGATE} (sender : HCI; status,handle,reason : LONGINT);
	InquiryComplete* = PROCEDURE {DELEGATE} (sender: HCI; status: LONGINT);

	ConnectionEvent* = PROCEDURE{DELEGATE} (sender: HCI; link: Link; res: WORD);
	(*OnReceiveACLDataEvent* = PROCEDURE{DELEGATE} (link: Link; acl: Bluetooth.ACLPacket); *)
		(*handle, PB, PC, len: LONGINT; VAR data: ARRAY OF CHAR);*)
	InquiryEvent* = PROCEDURE {DELEGATE} (sender: HCI; bdAddr: Bluetooth.BDAddr; deviceClass: Bluetooth.DeviceClass;
		psRepMode, psPeriodMode, psMode, clockOffset: LONGINT);
	GeneralEvent* = PROCEDURE {DELEGATE} (sender: HCI; event: Bluetooth.EventPacket);
	ErrorEvent* = PROCEDURE{DELEGATE} (packet: Bluetooth.Packet);


(** composes a HCI command packet header *)
PROCEDURE ComposeCommandHeader*(OGF, OCF, paramLen: LONGINT; VAR command: ARRAY OF CHAR);
BEGIN
	ASSERT((0 <= OGF) & (OGF <= 03FH));
	ASSERT((0 <= OCF) & (OCF <= 03FFH));
	ASSERT((0 <= paramLen) & (paramLen <= 0FFH));

	command[0] := CHR(OCF MOD 100H);
	command[1] := CHR(OCF DIV 100H + OGF*4);
	command[2] := CHR(paramLen)
END ComposeCommandHeader;




END BluetoothHCI.
