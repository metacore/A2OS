MODULE BluetoothL2CAP;	(** AUTHOR "be"; PURPOSE "Bluetooth L2CAP driver"; *)

IMPORT
		KernelLog, Objects, Bluetooth, HCI := BluetoothHCI;

CONST
(*
	Trace = FALSE;
	TraceRead = FALSE;
	TraceSignallingChannel = FALSE;
	TraceReassembler = FALSE;
	TraceChannelManager = FALSE;
	TraceHCIEvents = FALSE;
	TraceL2CAPEventHandling = FALSE;

	Trace = TRUE;
	TraceRead = TRUE;
	TraceSignallingChannel = TRUE;
	TraceReassembler = TRUE;
	TraceChannelManager = TRUE;
	TraceHCIEvents = FALSE;
	TraceL2CAPEventHandling = TRUE;
*)


	TraceChannel = FALSE;
	TraceChannelManager = FALSE;
	TraceHCIManager = TRUE;
	TraceL2CAP = FALSE;
	TracePacketBuffer = FALSE;
	TraceReassembler = FALSE;
	TraceSignallingChannel = FALSE;

	ModuleName = "[BTL2CAP]";

	Error* = -1;

TYPE

	(** event types *)
	Event* = LONGINT;

CONST

	(**----- event indication -----*)

	EConnectInd* = 1;		(** connection indication event  *)
	EConfigInd* = 2;			(** configuration indication event *)
	EDisconnectInd* = 3;	(** disconnection indication event *)
	EQoSViolationInd* = 4;	(** QoS violation indication event *)
	MinEventIndication = EConnectInd;
	MaxEventIndication = EQoSViolationInd;

	(** Protocol/Service Multiplexor (PSM) *)
	psmSDP* = 1;	(** service discovery protocol *)
	psmRFCOMM* = 3;	(** RFCOMM *)
	psmTCP* = 5;	(** telephony control protocol *)

	MaxPacketQueue = 256;

TYPE

	(** callback parameters *)
	Indication* = POINTER TO RECORD 	(** base type for indication parameters *)
		c-: Channel;		(** channel *)
		ident-: CHAR;	(* identifier of request *)
	END;

	ConnectInd* = POINTER TO RECORD(Indication)	(** parameter for connection indication events *)
		bdAddr*: Bluetooth.BDAddr;	(** Bluetooth device address *)
		cid*: LONGINT;				(** channel ID *)
		psm*: LONGINT;				(** protocol/service multiplexor *)
	END;

	ConfigInd* = POINTER TO RECORD(Indication)	(** parameter for configuration indication events *)
		cid*: LONGINT;			(** channel ID *)
		outMTU*: LONGINT;		(** outgoing MTU information *)
		inFlow*: LONGINT;		(** incoming flow information *)
		inFlushTO*: LONGINT	(** incoming flush timeout *)
	END;

	DisconnectInd* = POINTER TO RECORD(Indication)	(** parameter for desconnection indication events *)
		cid*: LONGINT	(** channel ID *)
	END;

	QoSViolationInd* = POINTER TO RECORD(Indication)	(** parameter for QoS violation indication events *)
		bdAddr*: Bluetooth.BDAddr	(** Bluetooth device address *)
	END;

	(** callback type *)
	EventIndicationCallback* = PROCEDURE {DELEGATE} (indication: Indication);


	(**----- additional types -----*)

	(** list of group members *)
	GroupMembers* = POINTER TO ARRAY OF Bluetooth.BDAddr;

CONST

	MinCID = 3;			(* 0: reserved, 1: signalling channel, 2: connection-less channel *)
	MaxCIDs = 1024;

	ConnectTimeout = 10000;
	RTXTimeout = 5000;
	MaxTries = 3;

	(* L2CAP channel states *)
	Closed = 0; (* !! 1 or 0 ?? !! mm  *)
	W4L2CAPConnectRsp = 1;
	W4L2CAConnectRsp = 2;
	Config = 3; Open = 4;
	W4L2CAPDisconnectRsp = 5;
	W4L2CADisconnectRsp = 6;

	cidSignalling = 1;	(* CID of signalling channel *)
	cidConnectionless = 2;	(* CID of connectionless channel *)

	(* signals *)
	sigCommandReject = 01X;
	sigConnectionReq = 02X;
	sigConnectionResp = 03X;
	sigConfigureReq = 04X;
	sigConfigureResp = 05X;
	sigDisconnectionReq = 06X;
	sigDisconnectionResp = 07X;
	sigEchoReq = 08X;
	sigEchoResp = 09X;
	sigInformationReq = 0AX;
	sigInformationResp = 0BX;

	(* configuration options *)
	optMTU = 01X;
	optFlushTO = 02X;
	optQoS = 03X;

TYPE

	PChar = POINTER TO ARRAY OF CHAR;

	(* ----------------------------------------------------------------------------------------- *)


	(* L2CAP packet *)
	Packet = POINTER TO RECORD
		next: Packet;
		link: HCI.Link;			(* packet comes from this link *)
		cid, len: LONGINT;
		data: PChar;
	END;

	PacketBuffer = OBJECT

		VAR
			head, num: LONGINT;
			closed: BOOLEAN;
			buffer: POINTER TO ARRAY OF Packet;

		PROCEDURE Append(x: Packet);
		BEGIN {EXCLUSIVE}
			AWAIT((num # LEN(buffer)) OR closed);
			buffer[(head+num) MOD LEN(buffer)] := x;
			IF num > 100 THEN KernelLog.String("!") END;
			INC(num)
		END Append;

		PROCEDURE Remove(): Packet;
		VAR x: Packet;
		BEGIN {EXCLUSIVE}
			AWAIT((num # 0) OR closed);
			x := buffer[head];
			head := (head+1) MOD LEN(buffer);
			DEC(num);
			RETURN x
		END Remove;

		PROCEDURE &Init*(n: LONGINT);
		BEGIN
			head := 0; num := 0; closed := FALSE; NEW(buffer, n)
		END Init;

		PROCEDURE Close;
		BEGIN {EXCLUSIVE}
			closed := TRUE
		END Close;

	END PacketBuffer;

	(* ----------------------------------------------------------------------------------------- *)

	Channel* = OBJECT	(** L2CAP channel *)

		VAR
			next: Channel;
			l2cap: L2CAP;
			link: HCI.Link;
			psm-, mtu: LONGINT;
			sid-, did-: LONGINT;	(** CIDs (local & remote) (channel identifier, range: 00040H..0FFFFH) *)
			state-: LONGINT;		(* channel state (Closed...W2L2CADisconnectRsp) *)

			t: Objects.Timer;
			reply, timeout: BOOLEAN;
			(*
			readers: LONGINT;
			readerData: Packet;
			*)
			packetBuffer: PacketBuffer;

		PROCEDURE &Init*(l2cap: L2CAP; link: HCI.Link; cid: LONGINT);
		BEGIN
			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.Init: ...");
				KernelLog.Ln
			END;
			SELF.l2cap := l2cap; SELF.link := link; sid := cid; state := Closed; mtu := l2cap.aclMTU;
			(*readers := 0; readerData := NIL;*)
			NEW(packetBuffer, MaxPacketQueue);
			NEW(t); reply := FALSE; timeout := FALSE;
			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.Init: done. CID = "); KernelLog.Int(sid,0);
				KernelLog.Ln
			END;
		END Init;

		PROCEDURE Close;
		BEGIN {EXCLUSIVE}
			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.Close: ... CID = "); KernelLog.Int(sid,0);
				KernelLog.Ln;
			END;
			packetBuffer.Close();
			state := Closed;
			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.Close: done. CID = "); KernelLog.Int(sid,0);
				KernelLog.Ln;
			END;
		END Close;

		PROCEDURE Timeout;
		BEGIN {EXCLUSIVE}
			timeout := TRUE
		END Timeout;

		PROCEDURE SetRTXTimer(ms: LONGINT);
		BEGIN
			Objects.SetTimeout(t, Timeout, ms)
		END SetRTXTimer;

		PROCEDURE Connect(psm: LONGINT; VAR status: LONGINT): WORD;
		VAR
			cmd: ARRAY 8 OF CHAR;
			ofs, n: LONGINT; res: WORD;
			tmp: LONGINT;
			sc: SignallingChannel;
			identifier: CHAR;
			response: Response;
		BEGIN {EXCLUSIVE}
			ASSERT(state = Closed);
			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.Connect (CID = "); KernelLog.Int(sid,0); KernelLog.String(") ...");
				KernelLog.Ln
			END;
			sc := l2cap.channelManager.GetSignallingChannel();
			ASSERT(sc # NIL);
			(* send connection request (first 4 bytes must be left free) *)
			cmd[4] := CHR(psm MOD 100H); cmd[5] := CHR(psm DIV 100H);	(* PSM *)
			cmd[6] := CHR(sid MOD 100H); cmd[7] := CHR(sid DIV 100H);		(* CID *)
			identifier := sc.GetIdentifier();
			state := W4L2CAConnectRsp;
			n := 0;
			REPEAT
				INC(n);
				IF TraceChannel THEN
					KernelLog.String(ModuleName);
					KernelLog.String("Channel.Connect: req #"); KernelLog.Int(n,0);
					KernelLog.String(" psm=  "); KernelLog.Hex(psm,-2);
					KernelLog.String(" source CID=  "); KernelLog.Hex(sid,-2);
					KernelLog.Ln;
				END;
				res := sc.Signal(link, sigConnectionReq, identifier, cmd, 4);
				IF TraceChannel THEN
					KernelLog.String(ModuleName);
					KernelLog.String("Channel.Connect: request send, waiting for reply...");
					KernelLog.Ln;
				END;
				sc.WaitForReply(identifier, n*RTXTimeout, response)
			UNTIL ((response # NIL) OR (n = MaxTries) OR (state = Closed));
			IF (response # NIL) THEN
				IF (response.code = sigConnectionResp) THEN
					ofs := response.ofs;
					did := ORD(response.data[ofs]) + LONG(ORD(response.data[ofs+1]))*100H;
					tmp := ORD(response.data[ofs+2])+LONG(ORD(response.data[ofs+3]))*100H;
					IF (sid # tmp) THEN
						KernelLog.String(ModuleName);
						KernelLog.String("Channel.Connect: Warning! Wrong SID in connect response: sid = "); KernelLog.Hex(sid, 0);
						KernelLog.String("; got "); KernelLog.Hex(tmp, 0); KernelLog.Ln;
						KernelLog.String("  did = "); KernelLog.Hex(did, 0); KernelLog.Ln
					END;
					res := ORD(response.data[ofs+4])+LONG(ORD(response.data[ofs+5]))*100H;
					IF (res = 0001H) THEN (* result = Pending *)
						status := ORD(response.data[ofs+6])+LONG(ORD(response.data[ofs+7]))*100H
					ELSE
						status := 0;
					END;
					state := Config;	(* TODO: check!!! *)
					IF TraceChannel THEN
						KernelLog.String(ModuleName);
						KernelLog.String("Channel.Connect: done.");
						KernelLog.String(" destination CID= "); KernelLog.Hex(did, -2);
						KernelLog.String(" source CID= "); KernelLog.Hex(sid, -2);
						KernelLog.String(" result= "); KernelLog.Hex(res,-2);
						KernelLog.String(" status=  "); KernelLog.Hex(status,-2);
						KernelLog.Ln;
					END;
					RETURN res
				ELSE
					KernelLog.String(ModuleName);
					KernelLog.String("Channel.Connect: connection request failed (wrong response)");
					KernelLog.Ln;
					RETURN Error
				END
			ELSE (* timeout *)

					KernelLog.String(ModuleName);
					KernelLog.String("Channel.Connect: connection request failed (no response or channel closed)");
					KernelLog.Ln;

				state := Closed; packetBuffer.Close;
				RETURN Error
			END

		END Connect;

		PROCEDURE ConnectResponse(identifier: CHAR; response, status: LONGINT): WORD;
		VAR cmd: ARRAY 12 OF CHAR; res: WORD; sc: SignallingChannel;
		BEGIN {EXCLUSIVE}
			ASSERT(state = W4L2CAConnectRsp);
			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.ConnectResponse: sid = "); KernelLog.Hex(sid, 0); KernelLog.String("; did = "); KernelLog.Hex(did, 0); KernelLog.Ln
			END;
			sc := l2cap.channelManager.GetSignallingChannel();
			ASSERT(sc # NIL);
			IF TraceChannel THEN
				KernelLog.String("    sending connection request on signalling channel"); KernelLog.Ln;
				KernelLog.String("  sid = "); KernelLog.Hex(sid, 0); KernelLog.String("; did = "); KernelLog.Hex(did, 0); KernelLog.Ln
			END;
			(* send connection response (first 4 bytes must be left free) *)
			cmd[4] := CHR(sid MOD 100H); cmd[5] := CHR(sid DIV 100H);	(* our cid (remote CID viewed from the remote side) *)
			cmd[6] := CHR(did MOD 100H); cmd[7] := CHR(did DIV 100H);	(* remote cid (local CID viewed from the remote side) *)
			cmd[8] := CHR(response MOD 100H); cmd[9] := CHR(response DIV 100H);	(* response code *)
			cmd[10] := CHR(status MOD 100H); cmd[11] := CHR(status DIV 100H);	(* status code *)

			res := sc.Signal(link, sigConnectionResp, identifier, cmd, 8);
			IF (res = 0) THEN state := Config
			ELSE state := Closed; packetBuffer.Close
			END;
			IF TraceChannel THEN KernelLog.String("      connection response sent."); KernelLog.Ln END;
			RETURN res
		END ConnectResponse;

		PROCEDURE Configure(VAR inMTU, outFlow, outFlushTO: LONGINT; linkTO: LONGINT): WORD;
		(* linkTO is not used!! mazda *)
		VAR

			cmd: ARRAY 48 OF CHAR;
			ofs, pos, n, value: LONGINT; res: WORD;
			tmp: LONGINT;
			sc: SignallingChannel; identifier, type: CHAR;
			response: Response;

		BEGIN

			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.Configure (CID = "); KernelLog.Int(sid,0); KernelLog.String(") ...");
				KernelLog.Ln
			END;

			sc := l2cap.channelManager.GetSignallingChannel();
			ASSERT(sc # NIL);

			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.Configure: sending configuration request. ");
				KernelLog.Ln;
			END;

			(* send configuration request (first 4 bytes must be left free) *)
			cmd[4] := CHR(did MOD 100H); cmd[5] := CHR(did DIV 100H);	(* remote CID *)
			cmd[6] := 0X; cmd[7] := 0X;	(* flags (no continuation packet) *)
			pos := 8;
			PutOption(optMTU, inMTU, cmd, pos);
			PutOption(optFlushTO, outFlushTO, cmd, pos);
			PutOption(optQoS, outFlow, cmd, pos);
			identifier := sc.GetIdentifier();

			n := 0;
			REPEAT
				INC(n);
				IF TraceChannel THEN
					KernelLog.String(ModuleName);
					KernelLog.String("Channel.Configure: req #"); KernelLog.Int(n,0);
					KernelLog.Ln;
				END;
				res := sc.Signal(link, sigConfigureReq, identifier, cmd, pos-4); (* pos includes the 4 header bytes *)
				IF TraceChannel THEN
					KernelLog.String(ModuleName);
					KernelLog.String("Channel.Configure: request send, waiting for reply...");
					KernelLog.Ln
				END;
				sc.WaitForReply(identifier, n*RTXTimeout, response)
			UNTIL (response # NIL) OR (n = MaxTries);

			IF (response # NIL) THEN
				IF (response.code = sigConfigureResp) THEN
					ofs := response.ofs;
					tmp := ORD(response.data[ofs])+LONG(ORD(response.data[ofs+1]))*100H;
					IF (sid # tmp) THEN
						KernelLog.String("Warning: wrong SID in connect response: sid = "); KernelLog.Hex(sid, 0);
						KernelLog.String("; got "); KernelLog.Hex(tmp, 0); KernelLog.Ln;
						KernelLog.String("  did = "); KernelLog.Hex(did, 0); KernelLog.Ln
					END;
					IF (response.data[ofs+2] # 0X) OR (response.data[ofs+3] # 0X) THEN
						KernelLog.String("Warning: continuation flag set; not supported!"); KernelLog.Ln
					END;
					res := ORD(response.data[ofs+4])+LONG(ORD(response.data[ofs+5]))*100H;
					pos := ofs+6;
					WHILE (pos < response.length) & (type # 0FFX) DO
						GetOption(response.data^, pos, type, value);
						CASE type OF
						| optMTU: inMTU := value; mtu := value
						| optFlushTO: outFlushTO := value
						ELSE
						END
					END;
					IF TraceChannel THEN
						KernelLog.String(ModuleName);
						KernelLog.String("Channel.Configure: done. ");
						KernelLog.Ln
					END;
					state := Open;	(* TODO: check config values *)
					RETURN 0
				ELSE
					IF TraceChannel THEN
						KernelLog.String(ModuleName);
						KernelLog.String("Channel.Configure: failed (wrong reply code "); KernelLog.Hex(ORD(response.code), -2);
						KernelLog.Char(")"); KernelLog.Ln
					END;
					RETURN 2	(* unacceptable parameters *)
				END
			ELSE (* timeout *)
				IF TraceChannel THEN
					KernelLog.String(ModuleName);
					KernelLog.String("Channel.Configure: failed (no response)"); KernelLog.Ln;
				END;
				state := Closed; packetBuffer.Close;
				RETURN Error
			END
		END Configure;

		PROCEDURE ConfigurationResponse(identifier: CHAR; outMTU, inFlow: LONGINT): WORD;

		VAR
			cmd: ARRAY 48 OF CHAR;
			pos: LONGINT; res: WORD;
			sc: SignallingChannel;

		BEGIN

			ASSERT((state = Config) OR (state = Open));

			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.ConfigurationResponse (CID = "); KernelLog.Int(sid,0); KernelLog.String(") ...");
				KernelLog.Ln
			END;

			sc := l2cap.channelManager.GetSignallingChannel();
			ASSERT(sc # NIL);

			(* send configuration response (first 4 bytes must be left free) *)
			cmd[4] := CHR(did MOD 100H); cmd[5] := CHR(did DIV 100H);	(* remote cid (local CID viewed from the remote side) *)
			cmd[6] := 00X; cmd[7] := 00X;	(* flags (no continuation packet) *)
			cmd[8] := 00X; cmd[9] := 00X;	(* result = 0... *)
			pos := 10;
			IF (outMTU > 0) THEN PutOption(optMTU, outMTU, cmd, pos) END;
			IF (inFlow > 0) THEN PutOption(optQoS, inFlow, cmd, pos) END;

			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.ConfigurationResponse: sending response on signalling channel"); KernelLog.Ln;
				KernelLog.String(" Source CID = "); KernelLog.Hex(did, 0);
				KernelLog.String(" Flags = 0");
				KernelLog.String(" Result = 0");
				KernelLog.String(" Config = -");
				KernelLog.Ln
			END;

			res := sc.Signal(link, sigConfigureResp, identifier, cmd, pos-4); (* pos includes the 4 header bytes *)
			IF (res = 0) THEN
				state := Open
			ELSE
				state := Closed;
				packetBuffer.Close
			END;

			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.ConfigurationResponse: done. res = "); KernelLog.Int(res,0);
				KernelLog.Ln
			END;

			RETURN res

		END ConfigurationResponse;

		PROCEDURE Disconnect(): LONGINT;

		VAR
			sc: SignallingChannel;
			cmd: ARRAY 8 OF CHAR;
			identifier: CHAR;
			response: Response;
			ofs, rsid, rdid: LONGINT; res: WORD;

		BEGIN
			IF state = Closed THEN
				IF TraceChannel THEN
					KernelLog.String(ModuleName);
					KernelLog.String("Disconnect: channel already closed"); KernelLog.Ln END;
				RETURN 0
			END;
			ASSERT((state = Config) OR (state = Open));

			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.Disconnect: sid = "); KernelLog.Hex(sid, -2); KernelLog.String("; did = "); KernelLog.Hex(did, -2);
				KernelLog.Ln
			END;
			sc := l2cap.channelManager.GetSignallingChannel();
			ASSERT(sc # NIL);

			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("    sending disconnection request on signalling channel"); KernelLog.Ln
			END;
			(* send disconnection request (first 4 bytes must be left free) *)
			cmd[4] := CHR(did MOD 100H); cmd[5] := CHR(did DIV 100H);	(* remote CID *)
			cmd[6] := CHR(sid MOD 100H); cmd[7] := CHR(sid DIV 100H);	(* CID *)
			identifier := sc.GetIdentifier();

			state := W4L2CADisconnectRsp;
			res := sc.Signal(link, sigDisconnectionReq, identifier, cmd, 4);
			sc.WaitForReply(identifier, RTXTimeout, response);

			(*state := Closed; packetBuffer.Close;*)
			Close();

			IF (response # NIL) THEN
				IF (response.code = sigDisconnectionResp) THEN
					ofs := response.ofs;
					rdid := ORD(response.data[ofs])+LONG(ORD(response.data[ofs+1]))*100H;
					rsid := ORD(response.data[ofs+2])+LONG(ORD(response.data[ofs+3]))*100H;
					IF (sid = rsid) & (did = rdid) THEN
						RETURN 0	(* ok *)
					ELSE
						KernelLog.String(ModuleName);
						KernelLog.String("Channel.Disconnect: error: sid # rsid or did # rdid");
						KernelLog.Ln;
					END;
				ELSE
					KernelLog.String(ModuleName);
					KernelLog.String("Channel.Disconnect: error: wrong response.code");
					KernelLog.Ln;
				END;
			ELSE
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.Disconnect: error: response = NIL");
				KernelLog.Ln;
			END;
			RETURN 0EEEEH	(* disconnection timeout *)
		END Disconnect;

		(** sends an L2CAP packet over ACL *)
		PROCEDURE Send(VAR data: ARRAY OF CHAR; ofs, len: LONGINT): WORD;

		VAR
			hdr: ARRAY 4 OF CHAR;
			count: LONGINT; res: WORD;

		BEGIN {EXCLUSIVE}

			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.Send (CID = "); KernelLog.Int(sid,0); KernelLog.String(") ...");
				KernelLog.Ln
			END;

			ASSERT((0 <= len) & (len < 10000H));

			hdr[0] := CHR(len MOD 100H); hdr[1] := CHR(len DIV 100H);
			hdr[2] := CHR(did MOD 100H); hdr[3] := CHR(did DIV 100H);

			count := Min(Bluetooth.MaxACLDataLen - 4, len); (* Min(l2cap.aclMTU - 4, len); *)
			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.Send: first packet (payload: "); KernelLog.Int(count, 0); KernelLog.String(" bytes)");
				KernelLog.Ln
			END;
			res := link.SendACLH(HCI.pbfFirst, HCI.bfPointToPoint, hdr, 4, data, ofs, count);
			IF (res # 0) THEN
				RETURN res
			END;

			DEC(len, count); INC(ofs, count);
			WHILE (len > 0) DO
				count := Min(Bluetooth.MaxACLDataLen, len); (* Min(l2cap.aclMTU, len); *)
				IF TraceChannel THEN
					KernelLog.String(ModuleName);
					KernelLog.String("Channel.Send: continuing packet (payload: "); KernelLog.Int(count, 0); KernelLog.String(" bytes)");
					KernelLog.Ln
				END;
				res := link.SendACL(HCI.pbfContinuing, HCI.bfPointToPoint, data, ofs, count);
				IF (res # 0) THEN RETURN res END;
				DEC(len, count); INC(ofs, count)
			END;

			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.Send: done.");
				KernelLog.Ln
			END;

			RETURN res

		END Send;

		(* receive an L2CAP packet *)
		PROCEDURE Receive(p: Packet);
		BEGIN (*{EXCLUSIVE}*)

			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.Receive: (CID = "); KernelLog.Int(sid,0); KernelLog.String(") ...");
				KernelLog.Ln
			END;
			(*
			IF (readers > 0) THEN (* if no readers are available, drop the data *)
				IF TraceRead THEN
					KernelLog.String("Channel "); KernelLog.Hex(sid, 0); KernelLog.String(": received data!"); KernelLog.Ln
				END;
				readerData := p
			ELSE
				KernelLog.String("Warning: channel "); KernelLog.Hex(sid, 0); KernelLog.String(" is dropping data"); KernelLog.Ln
			END
			*)
			packetBuffer.Append(p);
			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.Receive: done.");
				KernelLog.Ln
			END;
		END Receive;

		PROCEDURE Write*(VAR buffer: ARRAY OF CHAR; ofs, len: LONGINT; VAR size: LONGINT): WORD;

		VAR
			res: WORD;

		BEGIN

			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.Write: (CID = "); KernelLog.Hex(sid,-2);
				KernelLog.String(" mtu = "); KernelLog.Int(mtu,0);
				KernelLog.String(") ...");
				KernelLog.Ln;
			END;

			IF mtu = 0 THEN
				KernelLog.Ln; KernelLog.Ln; KernelLog.String("**** Warning: MTU = 0 ****"); KernelLog.Ln; KernelLog.Ln; KernelLog.Ln;
				mtu := 1000H
			END;
			len := Min(len, mtu);
			res := Send(buffer, ofs, len);
			IF (res = 0) THEN
				size := len
			ELSE
				size := 0
			END;

			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.Write: done.");
				KernelLog.Ln
			END;

			RETURN res
		END Write;

		PROCEDURE Read*(VAR buffer: ARRAY OF CHAR; min: LONGINT; VAR size: LONGINT): LONGINT;
		VAR i: LONGINT;
			p: Packet;
		BEGIN (*{EXCLUSIVE}*)
			(*INC(readers);*)
			size := 0;
			(*WHILE (size < min) & (state = Open) DO*)
				IF TraceChannel THEN
					KernelLog.String(ModuleName);
					KernelLog.String("Channel.Read: (CID = "); KernelLog.Hex(sid,-2); KernelLog.String(") ...");
					 KernelLog.Ln;
				END;
				(*AWAIT((readerData # NIL) OR (state # Open));
				IF (readerData # NIL) & (state = Open) THEN*)
				(*
				IF TraceChannel THEN
					KernelLog.String("Channel.Read (cid"); KernelLog.Hex(sid, 0); KernelLog.String("): got data"); KernelLog.Ln;
					KernelLog.String("  pos = "); KernelLog.Int(size, 0);
						(*KernelLog.String("; readerData.len = "); KernelLog.Int(readerData.len, 0); *)
						KernelLog.String("; min = "); KernelLog.Int(min, 0); KernelLog.Ln
				END;
				*)
					(*
					FOR i := 0 TO Min(readerData.len, min-size)-1 DO
						buffer[size] := readerData.data[i]; INC(size)
					END;
					readerData := NIL
					*)
					p := packetBuffer.Remove();
					IF ~packetBuffer.closed THEN
						size := p.len;
						FOR i := 0 TO size-1 DO
							buffer[i] := p.data[i]
						END
					ELSE
						size := 0
					END
				(*ELSIF TraceRead THEN
					KernelLog.String("Channel.Read (cid"); KernelLog.Hex(sid, 0); KernelLog.String("): failed to get data"); KernelLog.Ln
				END*);
			(*END;*)
			(*DEC(readers);*)
			IF (state = Open) THEN
				IF TraceChannel THEN
					KernelLog.String(ModuleName);
					KernelLog.String("Channel.Read: (CID = "); KernelLog.Hex(sid, -2); KernelLog.String(") done.");
					 KernelLog.Ln;
				END;
				RETURN 0
			ELSE
				IF TraceChannel THEN
					KernelLog.String("Channel.Read (CID = "); KernelLog.Hex(sid, -2); KernelLog.String("): returning failure!"); KernelLog.Ln END;
				RETURN 1
			END
		END Read;

	END Channel;

	(* ----------------------------------------------------------------------------------------- *)

	(* packet type for a signalling *)
	SignalPacket = POINTER TO RECORD
		link: HCI.Link;	(* signal comes from this link *)
		code: CHAR;
		identifier: CHAR;
		length: LONGINT;
		data: PChar;
		ofs: LONGINT;
	END;

	Request = POINTER TO RECORD(SignalPacket) (* code one of sig*Req *)
		next: Request;
	END;

	Response = POINTER TO RECORD(SignalPacket) (* code one of sig*Resp *)
	END;

	(* signalling channel (cid 0001H) *)
	SignallingChannel = OBJECT(Channel)

		VAR
			dead: BOOLEAN;
			identifier: CHAR;
			timeout: Bluetooth.IDTimer;
			response: Response;
			firstReq, lastReq: Request;

		PROCEDURE &Init*(l2cap: L2CAP; link: HCI.Link; cid: LONGINT);
		BEGIN
			IF TraceSignallingChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("SignallingChannel.Init: ... ");
				KernelLog.Ln
			END;
			Init^(l2cap, link, cid); sid := 1; did := 1;
			IF TraceSignallingChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("SignallingChannel.Init: done.");
				KernelLog.Ln
			END;
		END Init;

		PROCEDURE Close;
		BEGIN {EXCLUSIVE}
			IF TraceSignallingChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("SignallingChannel.Close: ...");
				KernelLog.Ln;
			END;
			dead := TRUE;
			IF TraceSignallingChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("SignallingChannel.Close: done.");
				KernelLog.Ln;
			END;
		END Close;

		(* return the next identifier (c.f. SignalPacket.identifier) *)
		PROCEDURE GetIdentifier(): CHAR;
		VAR c: CHAR;
		BEGIN {EXCLUSIVE}
			c := identifier;
			identifier := CHR((ORD(identifier)+1) MOD 100H);
			RETURN c
		END GetIdentifier;

		(* signal an remote L2CAP entity using link *)
		(* LEN(command) must be >= 4 and the first 4 bytes of command MUST be left free *)
		PROCEDURE Signal(link: HCI.Link; code, identifier: CHAR; command: ARRAY OF CHAR; len: LONGINT): WORD;

		VAR
				res : WORD;

		BEGIN (* {EXCLUSIVE} TODO *)

			IF TraceSignallingChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("SignallingChannel.Signal: command code = "); KernelLog.Hex(ORD(code), -2);
				KernelLog.String("; identifier = "); KernelLog.Hex(ORD(identifier), -2);
				KernelLog.String("; length = "); KernelLog.Int(len, 0); KernelLog.String(" ... ");
				KernelLog.Ln
			END;

			ASSERT((LEN(command) >= 4) & (command[0] = 0X) & (command[1] = 0X) & (command[2] = 0X) & (command[3] = 0X));
			ASSERT((0 <= len) & (len < 1000H));

			command[0] := code; command[1] := identifier;
			command[2] := CHR(len MOD 100H); command[3] := CHR(len DIV 100H);

			SELF.link := link;
(*
			IF TraceSignallingChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("SignallingChannel.Signal: sending command:");
				KernelLog.Ln;
				FOR i:=0 TO len+4-1 DO
					KernelLog.Hex(ORD(command[i]),-2); KernelLog.String(" ");
				END;
				KernelLog.Ln;
			END;
*)
			res := Send(command,0,len+4);

			IF TraceSignallingChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("SignallingChannel.Signal: done.");
				KernelLog.Ln
			END;

			RETURN res;

		END Signal;

		(* receive and parse a signalling packet *)
		PROCEDURE Receive(p: Packet);
		VAR
			pos: LONGINT; res: WORD;
			c: CHAR;
			s: SignalPacket;
			request: Request;
			reply: ARRAY 8 OF CHAR;
			ch: Channel;
		BEGIN

			IF TraceSignallingChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("SignallingChannel.Receive ... ");
				KernelLog.Ln
			END;

			pos := 0;
			WHILE (pos < p.len) DO

				c := p.data[pos];

				IF (c = sigConnectionReq) OR (c = sigConfigureReq) OR
					(c = sigDisconnectionReq) OR (c = sigEchoReq) OR (c = sigInformationReq)
				THEN
					NEW(request); s := request
				ELSIF (c = sigConnectionResp) OR (c = sigConfigureResp) OR (c = sigDisconnectionResp) OR
					(c = sigEchoResp) OR (c = sigInformationResp) OR (c = sigCommandReject)
				THEN
					NEW(response); s := response
				ELSE
					(* hmmm....this is not good *)
					KernelLog.String(ModuleName);
					KernelLog.String("SignallingChannel.Receive: invalid command ("); KernelLog.Hex(ORD(c),-2); KernelLog.String("X)");
					KernelLog.Ln;
					RETURN
				END;

				s.link := p.link;
				s.code := c;
				s.identifier := p.data[pos+1];
				s.length := ORD(p.data[pos+2])+LONG(ORD(p.data[pos+3]))*100H;
				s.data := p.data;
				s.ofs := pos + 4;

				IF TraceSignallingChannel THEN
					KernelLog.String(ModuleName);
					KernelLog.String("SignallingChannel.Receive: command code = "); KernelLog.Hex(ORD(s.code), -2);
					KernelLog.String(" identifier = "); KernelLog.Hex(ORD(p.data[pos+1]), -2);
					KernelLog.Ln;
(*
					FOR i:=0 TO p.len-1 DO
						 KernelLog.Hex(ORD(p.data[i]),-2); KernelLog.String(" ");
					END;
					KernelLog.Ln;
*)
				END;

				IF (s IS Response) THEN

					BEGIN {EXCLUSIVE}
					(* this will activate the one process waiting for this identifier, or if not process is waiting, drop it *)
						IF TraceSignallingChannel THEN
							KernelLog.String(ModuleName);
							KernelLog.String("SignallingChannel.Receive: {EXCLUSIVE} got response, setting identifier (");
							 KernelLog.Int(ORD(p.data[pos+1]),0); KernelLog.String(") ...");
							KernelLog.Ln
						END;
						response.identifier := p.data[pos+1];
						IF TraceSignallingChannel THEN
							KernelLog.String(ModuleName);
							KernelLog.String("SignallingChannel.Receive: {EXCLUSIVE} identifier set.");
							KernelLog.Ln
						END;
					END

				ELSE (* s IS Request *)

					ASSERT(s IS Request);

					(* reply to Echo and Information requests, queue other requests *)
					IF (request.code = sigEchoReq) THEN
						IF TraceSignallingChannel THEN
							KernelLog.String(ModuleName);
							KernelLog.String("SignallingChannel.Receive: got echo request, sending echo reply");
							KernelLog.Ln
						END;
						res := Signal(request.link, sigEchoResp, request.identifier, reply, 0)	(* ignore result *)
					ELSIF (request.code = sigInformationReq) THEN
						IF TraceSignallingChannel THEN
							KernelLog.String(ModuleName);
							KernelLog.String("SignallingChannel.Receive: got information request, sending information reply");
							KernelLog.Ln
						END;
						reply[4] := request.data[request.ofs]; reply[5] := request.data[request.ofs+1];	(* InfoType: same as request *)
						reply[6] := 01X; reply[7] := 00X;	(* not supported *)
						res := Signal(request.link, sigInformationResp, request.identifier, reply, 4)	(* ignore result *)
					ELSE


						IF (request.code = sigDisconnectionReq) THEN
							IF TraceSignallingChannel THEN
								KernelLog.String(ModuleName);
								KernelLog.String("SignallingChannel.Receive: got disconnection request, sending disconnection reply"); KernelLog.Ln
							END;
							ch := l2cap.channelManager.FindChannel(ORD(request.data[request.ofs])+LONG(ORD(request.data[request.ofs+1]))*100H);
							IF (ch # NIL) THEN
								ch.state := Closed; ch.packetBuffer.Close;
								reply[4] := request.data[request.ofs+2]; reply[5] := request.data[request.ofs+3];
								reply[6] := request.data[request.ofs]; reply[7] := request.data[request.ofs+1];
								res := Signal(request.link, sigDisconnectionResp, request.identifier, reply, 4);	(* ignore result *)
							ELSE request := NIL	(* discard request *)
							END
						END;

						IF (request # NIL) THEN
							IF TraceSignallingChannel THEN
								KernelLog.String(ModuleName);
								KernelLog.String("SignallingChannel.Receive: queueing request..."); KernelLog.Ln
							END;
							QueueRequest(request);
						END;

					END;

				END; (* s IS Request *)

				INC(pos, 4+s.length);

			END; (* WHILE *)

			IF TraceSignallingChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("SignallingChannel.Receive: done."); KernelLog.Ln
			END;

		END Receive;

		PROCEDURE TimeoutHandler(timer: Bluetooth.IDTimer);

		BEGIN {EXCLUSIVE}

			timeout := timer

		END TimeoutHandler;

		(* wait for a reply to a signalling packet with identifier from a remote L2CAP entity *)
		PROCEDURE WaitForReply(identifier: CHAR; wait: LONGINT; VAR r: Response);
		VAR
			idTimer: Bluetooth.IDTimer;
		BEGIN {EXCLUSIVE}
			IF TraceSignallingChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("SignallingChannel.WaitForReply: {EXCLUSIVE} await (identifier = ");
				KernelLog.Int(ORD(identifier),0); KernelLog.String(") ...."); KernelLog.Ln
			END;

			NEW(idTimer, TimeoutHandler, wait);
			AWAIT(((response # NIL) & (response.identifier = identifier)) OR (timeout = idTimer) OR dead);

			r := response; response := NIL;

			IF TraceSignallingChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("SignallingChannel.WaitForReply: {EXCLUSIVE} done."); KernelLog.Ln
			END;
		END WaitForReply;

		(* request queue for the local L2CAP entity *)
		PROCEDURE QueueRequest(request: Request);

		BEGIN {EXCLUSIVE}

			IF TraceSignallingChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("SignallingChannel.QueueRequest: {EXCLUSIVE} ...."); KernelLog.Ln
			END;

			IF (lastReq = NIL) THEN firstReq := request; lastReq := request
			ELSE lastReq.next := request; lastReq := request
			END;

			IF TraceSignallingChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("SignallingChannel.QueueRequest: {EXCLUSIVE} done."); KernelLog.Ln
			END;

		END QueueRequest;

		PROCEDURE GetRequest(): Request;
		VAR r: Request;
		BEGIN {EXCLUSIVE}
			IF TraceSignallingChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("SignallingChannel.GetRequest: ...."); KernelLog.Ln;
			END;
			AWAIT((firstReq # NIL) OR dead);
			IF ~dead THEN
				r := firstReq; firstReq := firstReq.next;
				IF (firstReq = NIL) THEN lastReq := NIL END
			END;
			IF TraceSignallingChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("SignallingChannel.GetRequest: done."); KernelLog.Ln
			END;
			RETURN r;
		END GetRequest;

	END SignallingChannel;

	(* ----------------------------------------------------------------------------------------- *)

	(* L2CAP data packet reassembly and multiplexing *)
	Reassembler = OBJECT

		VAR
			l2cap: L2CAP;
			packet: Packet;
			tail:Packet;
			pos: LONGINT;
			packetList: Packet;
			dead: BOOLEAN;
			packetListLength : LONGINT;

		PROCEDURE &Init*(l2cap: L2CAP);
		BEGIN
			IF TraceReassembler THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Reassembler.Init: ...");
				KernelLog.Ln
			END;
			SELF.l2cap := l2cap; packet := NIL; pos := 0; packetList := NIL; dead := FALSE;
			tail := NIL; packetListLength := 0;
			IF TraceReassembler THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Reassembler.Init: done.");
				KernelLog.Ln
			END;
		END Init;

		PROCEDURE Close;
		BEGIN {EXCLUSIVE}
			IF TraceReassembler THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Reassembler.Close: ...");
				KernelLog.Ln;
			END;
			dead := TRUE;
			IF TraceReassembler THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Reassembler.Close: done.");
				KernelLog.Ln;
			END;
		END Close;

		(* called by the HCI layer upon reception of an ACL data packet *)
		PROCEDURE ReceiveData(link: HCI.Link; acl: Bluetooth.ACLPacket);
		VAR i: LONGINT;
		BEGIN

			IF TraceReassembler THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Reassembler.ReceiveData (called by the HCI layer [Link.OnReceiveACLData]): ...");
				KernelLog.Ln
			END;

			IF (acl.PB = HCI.pbfFirst) THEN

				NEW(packet); packet.link := link;
				GetL2CAPHeader(acl.data, packet.cid, packet.len);
				NEW(packet.data, packet.len);

				pos := 0;
				FOR i := 4 TO acl.len-1 DO
					packet.data[pos] := acl.data[i];
					INC(pos);
				END;

				IF TraceReassembler THEN
					KernelLog.String(ModuleName);
					KernelLog.String("Reassembler.ReceiveData: first packet: cid="); KernelLog.Int(packet.cid, 0);
					KernelLog.String("; length = "); KernelLog.Int(packet.len, 0); KernelLog.String("; payload received: "); KernelLog.Int(pos, 0);
					KernelLog.Ln
				END

			ELSE (* acl.PB = HCI.pbfContinuing *)

				FOR i := 0 TO acl.len-1 DO
					packet.data[pos] := acl.data[i];
					INC(pos);
				END;

				IF TraceReassembler THEN
					KernelLog.String(ModuleName);
					KernelLog.String("Reassembler.ReceiveData: continuing packet: cid="); KernelLog.Int(packet.cid, 0);
					KernelLog.String("; length = "); KernelLog.Int(packet.len, 0); KernelLog.String("; payload received: "); KernelLog.Int(pos, 0);
					KernelLog.Ln
				END
			END;

			IF (packet.len <= pos) THEN (* complete *)
				IF TraceReassembler THEN
					KernelLog.String(ModuleName);
					KernelLog.String("Reassembler.ReceiveData: packet complete");
					KernelLog.Ln
				END;
				AddPacket(packet)
			END;

			IF TraceReassembler THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Reassembler.ReceiveData: done.");
				KernelLog.String("(pos = "); KernelLog.Int(pos,0);
				 KernelLog.String("; packet.len = "); KernelLog.Int(packet.len,0);
				 KernelLog.String(")");
				KernelLog.Ln
			END;

		END ReceiveData;

		PROCEDURE AddPacket(p: Packet);

		BEGIN {EXCLUSIVE}

			IF TraceReassembler THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Reassembler.AddPacket: {EXCLUSIVE} .... packetListLength = ");
				KernelLog.Int(packetListLength,0);
				KernelLog.Ln
			END;

			(*
				(* TODO: insert at the end.... *)
				packet.next := packetList; packetList := packet;
			*)

			IF (packetList = NIL) THEN
				p.next := NIL;
				packetList := p;
				tail := p;
			ELSE
				p.next := NIL;
				tail.next := p;
				tail := p;
			END;

			INC(packetListLength);

			IF TraceReassembler THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Reassembler.AddPacket: {EXCLUSIVE} done. packetListLength = ");
				KernelLog.Int(packetListLength,0);
				KernelLog.Ln
			END;

		END AddPacket;

		PROCEDURE GetPacket(): Packet;
		VAR p: Packet;
		BEGIN {EXCLUSIVE}
			IF TraceReassembler THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Reassembler.GetPacket: {EXCLUSIVE} await .... packetListLength = ");
				KernelLog.Int(packetListLength,0);
				KernelLog.Ln
			END;
			AWAIT((packetList # NIL) OR dead);
			IF (packetList # NIL) THEN
				p := packetList; packetList := packetList.next;
				DEC(packetListLength);
			ELSE
				p := NIL
			END;
			IF TraceReassembler THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Reassembler.GetPacket: {EXCLUSIVE} done. packetListLength = ");
				KernelLog.Int(packetListLength,0);
				KernelLog.Ln
			END;
			RETURN p
		END GetPacket;

		(* activity: wait for a (complete) L2CAP packet and send it to the corresponding channel *)
		PROCEDURE Run;
		VAR
			p: Packet; c: Channel;
		BEGIN
			REPEAT
				IF TraceReassembler THEN
					KernelLog.String(ModuleName);
					KernelLog.String("Reassembler.Run: {ACTIVE} waiting for L2CAP packets ... "); KernelLog.Ln;
				END;
				p := GetPacket();
				IF (p # NIL) THEN
					IF TraceReassembler THEN
						KernelLog.String(ModuleName);
						KernelLog.String("Reassembler.Run: {ACTIVE} packet received. Pass it to the receiving channel ...");
						KernelLog.Ln;
					END;
					c := l2cap.channelManager.FindChannel(p.cid);
					IF (c # NIL) THEN
						c.Receive(p);
					ELSE
						IF TraceReassembler THEN
							KernelLog.String(ModuleName);
							KernelLog.String("Reassembler.Run: {ACTIVE} no receiving channel (cid = "); KernelLog.Int(packet.cid, 0); KernelLog.Char(")");
							KernelLog.Ln;
						END
					END;
				END;
				IF TraceReassembler THEN
					KernelLog.String(ModuleName);
					KernelLog.String("Reassembler.Run: {ACTIVE} L2CAP packet processed."); KernelLog.Ln;
				END
			UNTIL dead;
		END Run;

	BEGIN {ACTIVE}
		(*Objects.SetPriority(4);*)
		IF TraceReassembler THEN
			KernelLog.String(ModuleName);
			KernelLog.String("Reassembler: {ACTIVE} ...");
			KernelLog.Ln;
		END;
		Run;
		IF TraceReassembler THEN
			KernelLog.String(ModuleName);
			KernelLog.String("Reassembler: {ACTIVE} done.");
			KernelLog.Ln
		END;
	END Reassembler;


	(* ----------------------------------------------------------------------------------------- *)


	(* manages channels, the CID pool and supports searching for channels with a specific CID *)
	ChannelManager = OBJECT
		VAR
			l2cap: L2CAP;
			channels: Channel;
			numChannels: LONGINT;
			cidPool: ARRAY (MaxCIDs DIV 32) OF SET;
			nextCID: LONGINT;

		PROCEDURE &Init*(l2cap: L2CAP);
		VAR sc: SignallingChannel;
		BEGIN

			IF TraceChannelManager THEN
				KernelLog.String(ModuleName);
				KernelLog.String("ChannelManager.Init: ...");
				 KernelLog.Ln
			END;

			SELF.l2cap := l2cap;
			NEW(sc, l2cap, NIL, cidSignalling);	(* signalling channel *)
			channels := sc;
			numChannels := 1;
			nextCID := MinCID;

			IF TraceChannelManager THEN
				KernelLog.String(ModuleName);
				KernelLog.String("ChannelManager.Init: done.");
				KernelLog.Ln
			END;

		END Init;

		(* get the next CID *)
		PROCEDURE AllocCID(): LONGINT;
		VAR oldCID: LONGINT;
		BEGIN (* [EXCLUSIVE] *)
			oldCID := nextCID;
			WHILE ((nextCID MOD 32) IN cidPool[nextCID DIV 32]) DO
				nextCID := (nextCID+1) MOD MaxCIDs;
				IF (nextCID = 0) THEN nextCID := MinCID END;
				IF (nextCID = oldCID) THEN RETURN -1 END;
			END;
			INCL(cidPool[nextCID DIV 32], nextCID MOD 32);
			RETURN nextCID
		END AllocCID;

		(* free a CID *)
		PROCEDURE FreeCID(cid: LONGINT);
		BEGIN (* [EXCLUSIVE] *)
			ASSERT((cid MOD 32) IN cidPool[cid DIV 32]);
			EXCL(cidPool[cid DIV 32], cid MOD 32)
		END FreeCID;

		(* reset everything *)
		PROCEDURE Reset;
		VAR i: LONGINT;
		BEGIN {EXCLUSIVE}
			IF TraceChannelManager THEN
				KernelLog.String(ModuleName);
				KernelLog.String("ChannelManager.Reset");
				KernelLog.Ln
			END;
			channels.next := NIL;
			numChannels := 1;
			FOR i := 0 TO (MaxCIDs DIV 32)-1 DO cidPool[i] := {} END;
			nextCID := MinCID
		END Reset;

		(* returns a new channel with a unique CID. 'link' is the link used to send data to the remote channel endpoint *)
		PROCEDURE AddChannel(l2cap: L2CAP; link: HCI.Link): Channel;

		VAR

			c: Channel; cid: LONGINT;

		BEGIN {EXCLUSIVE}

			IF TraceChannelManager THEN
				KernelLog.String(ModuleName);
				KernelLog.String("ChannelManager.AddChannel: {EXCLUSIVE} ...");
				KernelLog.Ln
			END;

			cid := AllocCID();
			IF (cid # -1) THEN
				NEW(c, l2cap, link, cid);
				c.next := channels.next; channels.next := c; INC(numChannels)
			END;

			IF TraceChannelManager THEN
				KernelLog.String(ModuleName);
				KernelLog.String("ChannelManager.AddChannel: {EXCLUSIVE} done. CID = "); KernelLog.Hex(cid,0);
				KernelLog.Ln
			END;

			RETURN c

		END AddChannel;

		(* close a channel *)
		PROCEDURE RemoveChannel(c: Channel);
		VAR p,q: Channel;
		BEGIN {EXCLUSIVE}
			IF TraceChannelManager THEN
				KernelLog.String("{ChannelManager.RemoveChannel: cid = "); KernelLog.Hex(c.sid, 0); KernelLog.Char("}"); KernelLog.Ln
			END;
			p := channels.next; q := channels;
			WHILE (p # NIL) & (p # c) DO q := p; p := p.next END;
			IF (p # NIL) THEN
				FreeCID(p.sid);
				q.next := p.next; DEC(numChannels)
			END
		END RemoveChannel;

		(* find a channel with a specific CID *)
		PROCEDURE FindChannel(cid: LONGINT): Channel;
		VAR c: Channel;
		BEGIN {EXCLUSIVE}
			c := channels;
			WHILE (c # NIL) & (c.sid # cid) DO
				c := c.next
			END;
			RETURN c
		END FindChannel;

		(* get the signalling channel *)
		PROCEDURE GetSignallingChannel(): SignallingChannel;
		VAR c: Channel;
		BEGIN
			c := FindChannel(cidSignalling);
			IF (c # NIL) & (c IS SignallingChannel) THEN RETURN c(SignallingChannel)
			ELSE RETURN NIL
			END
		END GetSignallingChannel;

	END ChannelManager;

	(* handles connection/disconnection events from the HCI layer and can wait for a connection event *)
	HCIManager* = OBJECT
		VAR
			hci : HCI.HCI;
			expiredTimer: Bluetooth.IDTimer;
			newLink: HCI.Link;
			l2caps : L2CAP;

		PROCEDURE &Init*(hci : HCI.HCI);
		BEGIN
			IF TraceHCIManager THEN
				KernelLog.String(ModuleName);
				KernelLog.String("HCIManager.Init: ...");
				KernelLog.Ln
			END;
			SELF.hci := hci;
			hci.OnConnect := Connect;
			hci.OnDisconnect := Disconnect;
			NEW(l2caps);	(* dummy head *)
			l2caps.next := NIL;
			IF TraceHCIManager THEN
				KernelLog.String(ModuleName);
				KernelLog.String("HCIManager.Init: done.");
				KernelLog.Ln
			END;
		END Init;

		PROCEDURE CreateACLConnection*(l2cap : L2CAP;bdAddr : Bluetooth.BDAddr;VAR result : WORD);
		VAR link : HCI.Link;
		BEGIN
			result := hci.CreateConnection(bdAddr, 0);
			IF (result # 0) THEN
				IF TraceHCIManager THEN
					KernelLog.String(ModuleName);
					KernelLog.String("HCIManager.CreateACLConnection: hci.CreateConnection failed! res = "); KernelLog.Hex(result, -2);
					KernelLog.Ln;
				END;
				RETURN;
			END;

			link := AwaitACLConnection(bdAddr);
			IF (link = NIL) THEN
				result :=  0EEEEH; (* timeout *)
				RETURN;
			END;

			link.OnReceiveACLData := l2cap.reassembler.ReceiveData;
			l2cap.link := link;
			l2cap.next := l2caps.next;
			l2caps.next := l2cap;

		END CreateACLConnection;

		PROCEDURE ReleaseACLConnection*(link:HCI.Link;VAR result:WORD);
		BEGIN
			ASSERT(link # NIL);
			result := hci.Disconnect(link.handle,013H);
			IF (result # 0) THEN
				IF TraceHCIManager THEN
					KernelLog.String(ModuleName);
					KernelLog.String("HCIManager.ReleaseACLConnection: hci.Disconnect failed! res = "); KernelLog.Hex(result, -2);
					KernelLog.Ln;
				END;
			END;
		END ReleaseACLConnection;

		PROCEDURE AcceptACLConnection*(l2cap : L2CAP;bdAddr : Bluetooth.BDAddr;VAR result : WORD);
		VAR link : HCI.Link;
		BEGIN
			link := AwaitACLConnection(bdAddr);
			IF (link = NIL) THEN
				result :=  0EEEEH; (* timeout *)
				RETURN;
			END;
			result := 0;
			link.OnReceiveACLData := l2cap.reassembler.ReceiveData;
			l2cap.link := link;
			l2cap.next := l2caps.next;
			l2caps.next := l2cap;
		END AcceptACLConnection;

		(*----- lower layer events -----*)
		PROCEDURE Connect(sender: HCI.HCI; link: HCI.Link; res: WORD);
		BEGIN {EXCLUSIVE}
			IF (res = 0) THEN
				IF TraceHCIManager THEN
					KernelLog.String(ModuleName);
					KernelLog.String("HCIManager.Connect: got a new link. handle = "); KernelLog.Int(link.handle,0);
					KernelLog.Ln
				END;
				newLink := link
			ELSE
				IF TraceHCIManager THEN
					KernelLog.String(ModuleName);
					KernelLog.String("HCIManager.Connect:  failed! res = 0x"); KernelLog.Hex(res, -2);
					KernelLog.Ln
				END;
			END;
		END Connect;

		PROCEDURE Disconnect(sender: HCI.HCI; link: HCI.Link; res: WORD);
		VAR p,q : L2CAP;
		BEGIN {EXCLUSIVE}
			IF TraceHCIManager THEN
				KernelLog.String(ModuleName);
				KernelLog.String("HCIManager.Disconnect: ");
				KernelLog.Ln;
				IF(link # NIL) THEN
					KernelLog.String("link.handle = "); KernelLog.Int(link.handle,0);
					KernelLog.String(" link.reason = 0x"); KernelLog.Hex(link.reason,-2);
				ELSE
					KernelLog.String("link is NIL");
				END;
				KernelLog.String(" res = 0x"); KernelLog.Hex(res, -2);
				KernelLog.Ln
			END;
			IF(res = 0) THEN
				p := l2caps.next; q := l2caps;
				WHILE (p # NIL) & (p.link.handle # link.handle) DO
					q := p; p := p.next
				END;
				IF (p # NIL) THEN
					p.link := NIL;
					p.Close();
					q.next := p.next;
					IF (p.linkDisconnectHandler # NIL) THEN p.linkDisconnectHandler(link.remote) END
				END;
			END;
		END Disconnect;

		(*------ connection handling ------*)
		PROCEDURE TimeoutHandler(sender: Bluetooth.IDTimer);
		BEGIN {EXCLUSIVE}
			expiredTimer := sender
		END TimeoutHandler;

		PROCEDURE AwaitACLConnection(bdAddr: Bluetooth.BDAddr): HCI.Link;
		VAR
			idTimer: Bluetooth.IDTimer;
			l : HCI.Link;
			i : LONGINT;
		BEGIN {EXCLUSIVE}
			NEW(idTimer, TimeoutHandler, ConnectTimeout);
			AWAIT(((newLink # NIL) & (newLink.remote = bdAddr)) OR (expiredTimer = idTimer));
			IF (expiredTimer = idTimer) THEN
				IF TraceHCIManager THEN
					KernelLog.String(ModuleName);
					KernelLog.String("HCIManager.AwaitACLConnection: timeout. bdAddr = ");
					FOR i:=0 TO Bluetooth.BDAddrLen-1 DO
						KernelLog.Hex(ORD(bdAddr[i]), -2);
					END;
					KernelLog.Ln;
				END;
				RETURN NIL
			ELSE
				l := newLink;
				newLink := NIL;
				RETURN l;
			END
		END AwaitACLConnection;

	END HCIManager;

	OnACLLinkDisconnect* = PROCEDURE {DELEGATE} (bdAddr : Bluetooth.BDAddr);

	(* L2CAP interface *)
	L2CAP* = OBJECT
		VAR
			bdAddr-: Bluetooth.BDAddr;		(** BD Addr of local device *)
			aclMTU, scoMTU, aclNumPackets, scoNumPackets: LONGINT;	(* limitations of local device *)
			indications: ARRAY MaxEventIndication-MinEventIndication+1 OF EventIndicationCallback;
			reassembler: Reassembler;
			channelManager-: ChannelManager;
			signallingChannel: SignallingChannel;
			dead: BOOLEAN;
			next : L2CAP;
			link : HCI.Link;
			linkDisconnectHandler* : OnACLLinkDisconnect;

		PROCEDURE &Init*;
		VAR i: LONGINT;
		BEGIN
			IF TraceL2CAP THEN
				KernelLog.String(ModuleName);
				KernelLog.String("L2CAP.Init: ...");
				KernelLog.Ln;
			END;
			bdAddr := hciManager.hci.bdAddr;
			aclMTU := hciManager.hci.aclMTU; aclNumPackets := hciManager.hci.aclNumPackets;
			scoMTU := hciManager.hci.scoMTU; scoNumPackets := hciManager.hci.scoNumPackets;
			link := NIL;
			NEW(channelManager, SELF);
			signallingChannel := channelManager.GetSignallingChannel();
			NEW(reassembler, SELF);
			IF TraceL2CAP THEN
				KernelLog.String(ModuleName);
				KernelLog.String("L2CAP.Init: done.");
				KernelLog.String(" Addr: "); FOR i := 0 TO Bluetooth.BDAddrLen-1 DO KernelLog.Hex(ORD(bdAddr[i]), -2) END;
				KernelLog.String("; ACL length: "); KernelLog.Int(aclMTU, 0);
				KernelLog.String("; SCO length: "); KernelLog.Int(scoMTU, 0);
				KernelLog.String("; ACL packets: "); KernelLog.Int(aclNumPackets, 0);
				KernelLog.String("; SCO packets: "); KernelLog.Int(scoNumPackets, 0);
				KernelLog.Ln;
			END
		END Init;


		(*----- L2CAP interface -----*)

		(** request a callback when the selected indication event occurs *)
		PROCEDURE EventIndication*(event: Event; callback: EventIndicationCallback; VAR result: WORD);
		BEGIN
			IF (MinEventIndication <= event) & (event <= MaxEventIndication) THEN
				indications[event-MinEventIndication] := callback;
				result := 0
			ELSE
				result := 1
			END
		END EventIndication;

		(** initiates the sending of a L2CAP_ConnectReq message and blocks until a corresponding L2CA_ConnectCfm(Neg)
			or L2CA_TimeoutInd event is received.
		*)
		PROCEDURE Connect*(psm: LONGINT; bdAddr: Bluetooth.BDAddr; VAR lcid: LONGINT; VAR result: WORD; VAR status: LONGINT);
		VAR
			c: Channel;
		BEGIN
			IF TraceL2CAP THEN
				KernelLog.String(ModuleName);
				KernelLog.String("L2CAP.Connect: ...");
				KernelLog.Ln
			 END;
			lcid := 0; result := 0; status := 0;
			IF (link = NIL) THEN (* create ACL connection first *)
				IF TraceL2CAP THEN
					KernelLog.String(ModuleName);
					KernelLog.String("L2CAP.Connect: no link on HCI layer; creating link  ...");
					KernelLog.Ln;
				END;
				hciManager.CreateACLConnection(SELF,bdAddr,result);
				IF (result # 0) THEN
					IF TraceL2CAP THEN
						KernelLog.String(ModuleName);
						KernelLog.String("L2CAP.Connect: hciManager.CreateConnection failed!");
						KernelLog.Ln;
					END;
					RETURN
				END;
				IF TraceL2CAP THEN
					KernelLog.String(ModuleName);
					KernelLog.String("L2CAP.Connect: HCI link established.");
					KernelLog.Ln
				END;
			END;

			c := channelManager.AddChannel(SELF, link);
			IF TraceL2CAP THEN
				KernelLog.String(ModuleName);
				KernelLog.String("L2CAP.Connect: connecting the new channel ...");
				KernelLog.Ln
			END;
			result := c.Connect(psm, status);
			IF (result = 0) OR (result = 1) THEN
				lcid := c.sid;
				IF TraceL2CAP THEN
					KernelLog.String(ModuleName);
					KernelLog.String("L2CAP.Connect: done. CID = ");
					KernelLog.Hex(lcid,-2);
					KernelLog.Ln
				END;
			ELSE
				channelManager.RemoveChannel(c);

					KernelLog.String(ModuleName);
					KernelLog.String("L2CAP.Connect: faild! result= 0x"); KernelLog.Hex(result,-2);
					KernelLog.Ln

			END
		END Connect;

		(** issues a response to a connection request event indication *)
		PROCEDURE ConnectResponse*(bdAddr: Bluetooth.BDAddr; identifier : CHAR; lcid, response, status: LONGINT; VAR result: WORD);
		VAR c: Channel;
		BEGIN
			c := channelManager.FindChannel(lcid);
			IF (c # NIL) & (c.link.remote = bdAddr) THEN
				result := c.ConnectResponse(identifier, response, status);
				IF result # 0 THEN KernelLog.String("response sent but something went wrong"); KernelLog.Ln; END;
			ELSE
				KernelLog.String("channel not found"); KernelLog.Ln;
				result := 1	(* invalid lcid *)
			END
		END ConnectResponse;

		(** initiates the sending of a L2CAP_ConfigReq message and blocks until a corresponding L2CA_ConfigCfm(Neg)
			or L2CA_Timeout event is received.
			inMTU, outFlow and outFlushTO: input/output parameters
		*)
		PROCEDURE Configure*(cid: LONGINT; VAR inMTU, outFlow, outFlushTO: LONGINT; linkTO: LONGINT; VAR result: WORD);
		VAR c: Channel;
		BEGIN
			IF TraceL2CAP THEN
				KernelLog.String(ModuleName);
				KernelLog.String("L2CAP.Configure: MTU = "); KernelLog.Int(inMTU,0);
				KernelLog.String(" Flow = "); KernelLog.Int(outFlow,0);
				KernelLog.String(" FlushTo = "); KernelLog.Int(outFlushTO,0);
				KernelLog.String(" ...");
				KernelLog.Ln;
			END;
			c := channelManager.FindChannel(cid);
			IF (c # NIL) THEN
				result := c.Configure(inMTU, outFlow, outFlushTO, linkTO)
			ELSE
				result := 1	(* invalid cid *)
			END;
			IF TraceL2CAP THEN
				KernelLog.String(ModuleName);
				KernelLog.String("L2CAP.Configure: done. result = "); KernelLog.Int(result,0);
				KernelLog.String("; MTU = "); KernelLog.Int(inMTU,0);
				KernelLog.String(" Flow = "); KernelLog.Int(outFlow,0);
				KernelLog.String(" FlushTo = "); KernelLog.Int(outFlushTO,0);
				KernelLog.Ln;
			END;
		END Configure;

		(** issues a response to a configuration request event indication *)
		PROCEDURE ConfigurationResponse*(cid: LONGINT; identifier: CHAR; outMTU, inFlow: LONGINT; VAR result: WORD);
		VAR c: Channel;
		BEGIN
			IF TraceL2CAP THEN
				KernelLog.String(ModuleName);
				KernelLog.String("L2CAP.ConfigurationResponse: ...");
				KernelLog.Ln;
			END;
			c := channelManager.FindChannel(cid);
			IF (c # NIL) THEN
				result := c.ConfigurationResponse(identifier, outMTU, inFlow)
			ELSE
				result := 3	(* invalid cid *)
			END;
			IF TraceL2CAP THEN
				KernelLog.String(ModuleName);
				KernelLog.String("L2CAP.ConfigurationResponse: done. result = "); KernelLog.Int(result,0);
				KernelLog.Ln;
			END;
		END ConfigurationResponse;

		(** initiates the sending of a L2CAP_DisconnectReq message and blocks until a corresponding L2CA_DisconnectRsp
			or L2CA_TimeoutInd event is received.
		*)
		PROCEDURE Disconnect*(cid: LONGINT; VAR result: LONGINT);
		VAR
			chan : Channel;
		BEGIN
			IF TraceL2CAP THEN
				KernelLog.String(ModuleName);
				KernelLog.String("L2CAP.Disconnect: ...");
				KernelLog.Ln
			 END;
			 chan := channelManager.FindChannel(cid);
			 IF (chan # NIL) THEN
				 result := chan.Disconnect();
				 (*chan.Close();*)
				channelManager.RemoveChannel(chan);
			ELSE
				result := 1	(* invalid cid *)
			END;
			 IF TraceL2CAP THEN
				KernelLog.String(ModuleName);
				KernelLog.String("L2CAP.Disconnect: done. result = "); KernelLog.Hex(result,-2);
				KernelLog.Ln
			 END;
		END Disconnect;

		PROCEDURE DisconnectResponse*(identifier : CHAR; lcid, response, status: LONGINT; VAR result: LONGINT);
		VAR c: Channel;
		BEGIN
			c := channelManager.FindChannel(lcid);
			IF (c # NIL)  THEN
				result := -1; (* Some work TO DO *)
			ELSE
				KernelLog.String(ModuleName);
				KernelLog.String("channel not found"); KernelLog.Ln;
				result := 1	(* invalid lcid *)
			END
		END DisconnectResponse;

		(** requests the transfer of data across the channel. If the length of the data exceeds the outMTU then only the first
			outMTU bytes are sent.
		*)
		PROCEDURE Write*(cid, ofs, length: LONGINT; VAR buffer: ARRAY OF CHAR; VAR size: LONGINT; VAR result: WORD);
		VAR c: Channel;
		BEGIN

			IF TraceL2CAP THEN
				KernelLog.String(ModuleName);
				KernelLog.String("L2CAP.Write: ...");
				KernelLog.Ln;
			END;
			c := channelManager.FindChannel(cid);
			IF (c # NIL) THEN
				(*
					result := c.Send(buffer, length, size)
				*)
				result := c.Write(buffer, ofs, length, size)
			ELSE
				result := 3	(* invalid cid *)
			END;
			IF TraceL2CAP THEN
				KernelLog.String(ModuleName);
				KernelLog.String("L2CAP.Write: done. result = "); KernelLog.Int(result,0);
				KernelLog.Ln;
			END;
		END Write;

		(** reqests for reception of data. This reqest returns when data is available or the link is terminated. The data returned
			represents a single L2CAP payload. If the payload is bigger than the buffer, the remainder of the payload will be discarded.
		*)
		PROCEDURE Read*(cid, length: LONGINT; VAR buffer: ARRAY OF CHAR; VAR result, N: LONGINT);
		VAR c: Channel;
		BEGIN
			IF TraceL2CAP THEN
				KernelLog.String(ModuleName);
				KernelLog.String("L2CAP.Read: ... ");
				KernelLog.Ln;
			END;
			c := channelManager.FindChannel(cid);
			IF (c # NIL) THEN
				result := c.Read(buffer, length, N)
			ELSE
				result := 3	(* invalid cid *)
			END;
			IF TraceL2CAP THEN
				KernelLog.String(ModuleName);
				KernelLog.String("L2CAP.Read: done. result = "); KernelLog.Int(result,0);
				KernelLog.Ln;
			END;
		END Read;

		(** requests the creation of a cid to represent a logical connection to multiple devices. *)
		PROCEDURE GroupCreate*(psm: LONGINT; VAR cid: LONGINT);
		END GroupCreate;

		(** closes a group. *)
		PROCEDURE GroupClose*(cid: LONGINT; VAR result: LONGINT);
		END GroupClose;

		(** request the addiction of a member to a group. *)
		PROCEDURE GroupAddMember*(cid: LONGINT; bdAddr: Bluetooth.BDAddr; VAR result: LONGINT);
		END GroupAddMember;

		(** reqest the removal of a member from a group. *)
		PROCEDURE GroupRemoveMember*(cid: LONGINT; bdAddr: Bluetooth.BDAddr; VAR result: LONGINT);
		END GroupRemoveMember;

		(** request a report of the members of a group *)
		PROCEDURE GetGroupMembership*(cid: LONGINT; VAR result: LONGINT; VAR bdAddrList: GroupMembers);
		END GetGroupMembership;

		(** initiates a L2CA_EchoReq message and receives the corresponding L2CAP_EchoRsp message.
			echoData and length are input/output parameters
		*)
		PROCEDURE Ping*(bdAddr: Bluetooth.BDAddr; VAR echoData: ARRAY OF CHAR; VAR length, result: LONGINT);
(*
		VAR l: HCI.Link; data: ARRAY 4 OF CHAR; i: LONGINT; id: CHAR; response: Response;
		BEGIN
			IF TraceL2CAP THEN KernelLog.String("L2CAP.Ping"); KernelLog.Ln END;

			l := hci.FindLink(-1, bdAddr);
			IF (l # NIL) THEN
				id := signallingChannel.GetIdentifier();
				result := signallingChannel.Signal(l, sigEchoReq, id, data, 0);
				IF (result = 0) THEN
					signallingChannel.WaitForReply(id, RTXTimeout, response);
					IF (response # NIL) THEN
						result := 0;
						length := Min(response.length, LEN(echoData));
						FOR i := 0 TO length-1 DO echoData[i] := response.data[response.ofs+i] END
					ELSE
						result := 1	(* Ping timeout *)
					END
				END
			ELSE
				IF TraceL2CAP THEN KernelLog.String("  no link on HCI layer, exiting"); KernelLog.Ln END;
				result := -1
			END
*)
		END Ping;

		(** initiates a L2CA_InfoReq message and receives the corresponding L2CAP_InfoRsp message. *)
		PROCEDURE GetInfo*(bdAddr: Bluetooth.BDAddr; infoType: LONGINT; VAR result, size: LONGINT; VAR infoData: ARRAY OF CHAR);
(*
		VAR l: HCI.Link; data: ARRAY 6 OF CHAR; i, it: LONGINT; id: CHAR; response: Response;
		BEGIN
			ASSERT((0 <= infoType) & (infoType < 10000H));
			IF TraceL2CAP THEN KernelLog.String("L2CAP.GetInfo"); KernelLog.Ln END;

			l := hci.FindLink(-1, bdAddr);
			IF (l # NIL) THEN
				id := signallingChannel.GetIdentifier();
				data[4] := CHR(infoType MOD 100H); data[5] := CHR(infoType DIV 100H);
				result := signallingChannel.Signal(l, sigInformationReq, id, data, 2);
				IF (result = 0) THEN
					signallingChannel.WaitForReply(id, RTXTimeout, response);
					IF (response # NIL) THEN
						it := ORD(response.data[response.ofs])+LONG(ORD(response.data[response.ofs+1]))*100H;
						IF (infoType = it) THEN
							result := ORD(response.data[response.ofs+2])+LONG(ORD(response.data[response.ofs+3]))*100H;
							size := Min(response.length-4, LEN(infoData));
							FOR i := 0 TO size-1 DO infoData[i] := response.data[response.ofs+4+i] END
						ELSE
							result := 1	(* wrong infoType in reply *)
						END
					ELSE
						result := 3	(* GetInfo timeout *)
					END
				END
			ELSE
				IF TraceL2CAP THEN KernelLog.String("  no link on HCI layer, exiting"); KernelLog.Ln END;
				result := -1
			END
*)
		END GetInfo;

		(** general request to disable the reception of connectionless packets. *)
		PROCEDURE DisableConnectionlessTraffic*(psm: LONGINT; VAR result: LONGINT);
		END DisableConnectionlessTraffic;

		(** general request to enable the reception of connectionless packets. *)
		PROCEDURE EnableConnectionlessTraffic*(psm: LONGINT; VAR result: WORD);
		END EnableConnectionlessTraffic;

		PROCEDURE Close*;
		VAR
			c: Channel;
			result: WORD; i: LONGINT;
		BEGIN {EXCLUSIVE}
			IF TraceL2CAP THEN
				KernelLog.String(ModuleName);
				KernelLog.String("L2CAP.Close:  ...");
				KernelLog.Ln;
			END;
			IF (~dead) THEN
				FOR i := MinCID TO MaxCIDs  DO
					c := channelManager.FindChannel(i);
					IF (c # NIL) THEN
						c.Close();
						channelManager.RemoveChannel(c);
					END;
				END;
				dead := TRUE;
				signallingChannel.Close();
				reassembler.Close();
				IF (link # NIL) THEN
					hciManager.ReleaseACLConnection(link,result);
				END;
				IF TraceL2CAP THEN
					KernelLog.String(ModuleName);
					KernelLog.String("L2CAP.Close: done. result = ");KernelLog.Int(result,0);
					KernelLog.Ln;
				END;
			ELSE
				IF TraceL2CAP THEN
					KernelLog.String(ModuleName);
					KernelLog.String("L2CAP.Close: done. dead = TRUE; already closed ?");
					KernelLog.Ln;
				END;
			END;
		END Close;

		PROCEDURE GetLinkHandle*() : LONGINT;
		BEGIN
			RETURN link.handle;
		END GetLinkHandle;

		PROCEDURE L2CAConnectInd(request : Request);
		VAR
			indication: EventIndicationCallback;
			connectInd: ConnectInd;
			bdStr: ARRAY 32 OF CHAR;
		BEGIN
			IF TraceL2CAP THEN
				Bluetooth.CharArrayToString(request.link.remote, 0, Bluetooth.BDAddrLen, bdStr);
				KernelLog.String(ModuleName);
				KernelLog.String("L2CAP.L2CAConnectInd: request from "); KernelLog.String(bdStr);
				KernelLog.String(" ... ");
				KernelLog.Ln
			END;
			indication := indications[EConnectInd-MinEventIndication];
			IF (indication # NIL) THEN
				NEW(connectInd);
				connectInd.bdAddr := request.link.remote;
				connectInd.cid := ORD(request.data[request.ofs+2])+LONG(ORD(request.data[request.ofs+3]))*100H;
				connectInd.psm := ORD(request.data[request.ofs])+LONG(ORD(request.data[request.ofs+1]))*100H;
				connectInd.ident := request.identifier;
				connectInd.c := channelManager.AddChannel(SELF, request.link);
				connectInd.c.did := connectInd.cid;
				connectInd.c.psm := connectInd.psm;
				connectInd.c.state := W4L2CAConnectRsp;
				indication(connectInd);
			END;
			IF TraceL2CAP THEN
				KernelLog.String(ModuleName);
				KernelLog.String("L2CAP.L2CAConnectInd: done.");
				KernelLog.Ln
			END
		END L2CAConnectInd;


		PROCEDURE L2CAConfigInd(request : Request);
		VAR
			indication: EventIndicationCallback;
			configureInd: ConfigInd;
			pos, value: LONGINT;
			option: CHAR;
			bdStr: ARRAY 32 OF CHAR;
		BEGIN
			IF TraceL2CAP THEN
				Bluetooth.CharArrayToString(request.link.remote, 0, Bluetooth.BDAddrLen, bdStr);
				KernelLog.String(ModuleName);
				KernelLog.String("L2CAP.L2CAConfigInd: request from "); KernelLog.String(bdStr);
				KernelLog.String(" ... ");
				KernelLog.Ln
			END;
			indication := indications[EConfigInd-MinEventIndication];
			IF (indication # NIL) THEN
				NEW(configureInd);
				configureInd.cid := ORD(request.data[request.ofs])+LONG(ORD(request.data[request.ofs+1]))*100H;
				configureInd.c := channelManager.FindChannel(configureInd.cid);
				configureInd.ident := request.identifier;
				(* request.data[ofs+2:ofs+3]: flags (ignore for now) *)
				pos := request.ofs+4;
				WHILE (pos < request.ofs+request.length) DO
					GetOption(request.data^, pos, option, value);
						CASE option OF
						| optMTU: configureInd.outMTU := value; configureInd.c.mtu := value
						| optFlushTO: configureInd.inFlushTO := value
						| optQoS: (* ignore for now *)
						ELSE
							KernelLog.String(ModuleName);
							KernelLog.String("L2CAP.L2CAConfigInd: error in configuration request (option= 0x");
							KernelLog.Hex(ORD(option), -2); KernelLog.String(")"); KernelLog.Ln;
						END
				END;
				indication(configureInd);
			END;
			IF TraceL2CAP THEN
				KernelLog.String(ModuleName);
				KernelLog.String("L2CAP.L2CAConfigInd: done.");
				KernelLog.Ln
			END
		END L2CAConfigInd;

		PROCEDURE L2CADisconnectInd(request : Request);
		VAR
			indication: EventIndicationCallback;
			disconnectInd: DisconnectInd;
			bdStr: ARRAY 32 OF CHAR;
		BEGIN
			IF TraceL2CAP THEN
				Bluetooth.CharArrayToString(request.link.remote, 0, Bluetooth.BDAddrLen, bdStr);
				KernelLog.String(ModuleName);
				KernelLog.String("L2CAP.L2CADisconnectInd: request from "); KernelLog.String(bdStr);
				KernelLog.String(" ... ");
				KernelLog.Ln
			END;
			indication := indications[EDisconnectInd-MinEventIndication];
			IF (indication # NIL) THEN
				NEW(disconnectInd);
				disconnectInd.cid := ORD(request.data[request.ofs])+LONG(ORD(request.data[request.ofs+1]))*100H;
				disconnectInd.c := channelManager.FindChannel(disconnectInd.cid);
				indication(disconnectInd);
			END;
			IF TraceL2CAP THEN
				KernelLog.String(ModuleName);
				KernelLog.String("L2CAP.L2CADisconnectInd: done.");
				KernelLog.Ln
			END
		END L2CADisconnectInd;

		(*----- event handling -----*)
		PROCEDURE Run;
		VAR
			request: Request;
			bdStr: ARRAY 32 OF CHAR;
		BEGIN
			REPEAT
				request := signallingChannel.GetRequest();

				IF (request # NIL) THEN
					CASE request.code OF
					| sigConnectionReq:
						L2CAConnectInd(request);
					| sigConfigureReq:
						L2CAConfigInd(request);
					| sigDisconnectionReq:
						L2CADisconnectInd(request);
					ELSE
						Bluetooth.CharArrayToString(request.link.remote, 0, Bluetooth.BDAddrLen, bdStr);
						KernelLog.String(ModuleName);
						KernelLog.String("L2CAP.Run: request from "); KernelLog.String(bdStr);
						KernelLog.String(" not supported; request.code= 0x"); KernelLog.Hex(ORD(request.code),-2);
						KernelLog.Ln;
					END;
				ELSE
					KernelLog.String(ModuleName);
					KernelLog.String("L2CAP.Run: request = NIL"); KernelLog.String(bdStr);
					KernelLog.Ln;
				END;
			UNTIL dead;

		END Run;

	BEGIN {ACTIVE}
		IF TraceL2CAP THEN
			KernelLog.String(ModuleName);
			KernelLog.String("L2CAP: {ACTIVE}:  ...");
			KernelLog.Ln;
		END;
		Run;
		IF TraceL2CAP THEN
			KernelLog.String(ModuleName);
			KernelLog.String("L2CAP: {ACTIVE}: done. ");
			KernelLog.Ln;
		END;
	END L2CAP;

VAR
	hciManager : HCIManager;


PROCEDURE PutOption(option: CHAR; value: LONGINT; VAR data: ARRAY OF CHAR; VAR pos: LONGINT);
VAR i: LONGINT;
BEGIN
	data[pos] := option; INC(pos);
	CASE option OF
	| optMTU:
		data[pos] := 02X; INC(pos); (* length *)
		data[pos] := CHR(value MOD 100H); data[pos+1] := CHR(value DIV 100H MOD 100H); INC(pos, 2)

	| optFlushTO:
		data[pos] := 02X; INC(pos); (* length *)
		data[pos] := CHR(value MOD 100H); data[pos+1] := CHR(value DIV 100H MOD 100H); INC(pos, 2)

	| optQoS:
		data[pos] := 16X; INC(pos); (* length *)
		data[pos] := 0X; INC(pos);	(* flags *)
		data[pos] := 01X; INC(pos);	(* service type 1: best effort *)
		(* replaced data[pos] with data[i] mm *)
		FOR i := pos TO pos+12 DO data[i] := 0X END; INC(pos, 12); (* token rate & bucket, peak bandwith = 0 *)
		FOR i := pos TO pos+8 DO data[i] := 0FFX END; INC(pos, 8)	(* latency, delay variation = 0FFFFFFFFH *)
	END
END PutOption;

PROCEDURE GetOption(VAR data: ARRAY OF CHAR; VAR pos: LONGINT; VAR option: CHAR; VAR value: LONGINT);
BEGIN
	option := data[pos]; INC(pos, 2);	(* skip length field *)
	CASE option OF
	| optMTU, optFlushTO:
		value := ORD(data[pos])+LONG(ORD(data[pos+1]))*100H; INC(pos, 2)

	| optQoS:
		INC(pos, 16H);	(* ignored *)
	ELSE option := 0FFX	(* error *)
	END
END GetOption;

PROCEDURE GetL2CAPHeader(VAR data: ARRAY OF CHAR; VAR cid, len: LONGINT);
BEGIN
	len := LONG(ORD(data[1]))*100H + ORD(data[0]);
	cid := LONG(ORD(data[3]))*100H + ORD(data[2])
END GetL2CAPHeader;

(*
PROCEDURE SetL2CAPHeader(cid, len: LONGINT; VAR data: ARRAY OF CHAR);
BEGIN
	ASSERT((0 <= len) & (len < 10000H));
	ASSERT((0 <= cid) & (cid < 10000H));

	data[0] := CHR(len MOD 100H); data[1] := CHR(len DIV 100H);
	data[2] := CHR(cid MOD 100H); data[3] := CHR(cid DIV 100H)
END SetL2CAPHeader;
*)

PROCEDURE Min(a,b: LONGINT): LONGINT;
BEGIN
	IF (a <= b) THEN RETURN a
	ELSE RETURN b
	END
END Min;

PROCEDURE InitL2CAP*(hci : HCI.HCI);
BEGIN
	NEW(hciManager,hci);
END InitL2CAP;

PROCEDURE GetHCIManager*() : HCIManager;
BEGIN
	RETURN hciManager;
END GetHCIManager;

PROCEDURE GetHCILayer*() : HCI.HCI;
BEGIN
	IF hciManager = NIL THEN
		RETURN NIL;
	ELSE
		RETURN hciManager.hci
	END;
END GetHCILayer;

END BluetoothL2CAP.