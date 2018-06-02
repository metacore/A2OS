MODULE BluetoothUART;	(** AUTHOR "be"; PURPOSE "HCI UART transport layer"; *)

IMPORT
	KernelLog, Streams, Bluetooth, Objects;

(* HCI command packet format (RS-232)
	| 01X | opcode (2bytes) | total parameter length | par0 | ... | parN |; and opcode = OGF (6bit) || OCF (10bit)

	HCI ACL data packet format (RS-232)
	| 02X |

	HCI SCO data packet format (RS-232)
	| 03X |

	HCI event packet format (RS-232)
	| 04X | Event Code | total parameter length | par0 | ... | parN |

	Error message packed format (RS-232)
	| 05X |

	Negotiation packet format (RS-232)
	| 06X |
*)

CONST

(*
	TraceSend = FALSE;
	TraceReceive = FALSE;
*)

	ModuleName = "[BTUART]";

	uartCommand = 01X;
	uartACLData = 02X;
	uartSCOData = 03X;
	uartEvent = 04X;

TYPE

	TransportLayer* = OBJECT(Bluetooth.TransportLayer)

		VAR
			TraceReceive*, TraceSend*: BOOLEAN;
			dead-: BOOLEAN;

		PROCEDURE &Init*(name: ARRAY OF CHAR; sender: Streams.Sender; receiver: Streams.Receiver);
		BEGIN
			Init^(name, sender, receiver);
			NEW(out, sender, 512); NEW(in, receiver, 512);
			dead := FALSE;
			TraceReceive := FALSE;	TraceSend := FALSE;
		END Init;

		PROCEDURE Close*;
		BEGIN {EXCLUSIVE}
			dead := TRUE
		END Close;

		PROCEDURE IsOpen*() :BOOLEAN;
		BEGIN {EXCLUSIVE}
			RETURN ~dead;
		END IsOpen;

		PROCEDURE ReadACLPacket() : Bluetooth.Packet;
		VAR acl: Bluetooth.ACLPacket; i : LONGINT;
		BEGIN
			NEW(acl);
			i := ORD(in.Get()) + ORD(in.Get())*100H;
			acl.handle := i  MOD 1000H;
			acl.PB := (i DIV 1000H) MOD 4;
			acl.BC := (i DIV 4000H) MOD 4;
			acl.len := ORD(in.Get()) + ORD(in.Get())*100H;
			(*ASSERT(acl.len <= Bluetooth.MaxACLDataLen);*)
			IF (acl.len > Bluetooth.MaxACLDataLen) THEN
				KernelLog.String(ModuleName);
				KernelLog.String("TransportLayer.ReadACLPacket: acl.len > Bluetooth.MaxACLDataLen");
				KernelLog.Ln;
				KernelLog.String("acl.len= "); KernelLog.Int(acl.len, 0);
				KernelLog.String("; BluetoothMaxACLDataLen= "); KernelLog.Int(Bluetooth.MaxACLDataLen, 0);
				KernelLog.String("; in.res= 0x"); KernelLog.Hex(in.res, -2);
				KernelLog.Ln;
				RETURN NIL;
			END;
			FOR i := 0 TO acl.len-1 DO
				acl.data[i] := in.Get();
			END;
			IF (in.res # 0) THEN
				KernelLog.String(ModuleName);
				KernelLog.String("TransportLayer.ReadACLPacket: UART failure; in.res= 0x"); KernelLog.Hex(in.res, -2);
				KernelLog.Ln;
				RETURN NIL;
			END;
			IF TraceReceive THEN
				KernelLog.String(ModuleName);
				KernelLog.String("TransportLayer.ReadACLPacket: reading ACL data");
				KernelLog.Ln;
				KernelLog.String("handle= 0x");KernelLog.Hex(acl.handle,-2);
				KernelLog.String("; packet boundary= 0x");KernelLog.Hex(acl.PB,-2);
				KernelLog.String("; broadcast= 0x"); KernelLog.Hex(acl.BC,-2);
				KernelLog.String("; payload length= 0x"); KernelLog.Int(acl.len,0);
				KernelLog.String("; acl.data= ");
				FOR i := 0 TO  acl.len-1 DO
					KernelLog.String(" 0x"); KernelLog.Hex(ORD(acl.data[i]),-2);
				END;
				KernelLog.Ln;
			END;
			RETURN acl;
		END ReadACLPacket;

		PROCEDURE ReadSCOPacket() : Bluetooth.Packet;
		VAR sco: Bluetooth.SCOPacket; i : LONGINT;
		BEGIN
			KernelLog.String(ModuleName);
			KernelLog.String("TransportLayer.ReadSCOPacket: uartSCOData received!! continue ....");
			KernelLog.Ln;
			NEW(sco);
			i := ORD(in.Get()) + ORD(in.Get())*100H;
			sco.handle := i MOD 1000H;
			sco.len := ORD(in.Get());
			(*ASSERT(sco.len <= Bluetooth.MaxSCODataLen);*)
			IF (sco.len > Bluetooth.MaxSCODataLen) THEN
				KernelLog.String(ModuleName);
				KernelLog.String("TransportLayer.ReadSCOPacket: sco.len > Bluetooth.MaxSCODataLen");
				KernelLog.Ln;
				KernelLog.String("sco.len= "); KernelLog.Int(sco.len, 0);
				KernelLog.String("; BluetoothMaxACLDataLen= "); KernelLog.Int(Bluetooth.MaxSCODataLen, 0);
				KernelLog.String("; in.res= 0x"); KernelLog.Hex(in.res, -2);
				KernelLog.Ln;
				RETURN NIL;
			END;
			FOR i := 0 TO sco.len-1 DO
				sco.data[i] := in.Get();
			END;
			IF (in.res # 0) THEN
				KernelLog.String(ModuleName);
				KernelLog.String("TransportLayer.ReadSCOPacket: UART failure; in.res= 0x"); KernelLog.Hex(in.res, -2);
				KernelLog.Ln;
				RETURN NIL;
			END;
			IF TraceReceive THEN
				KernelLog.String(ModuleName);
				KernelLog.String("TransportLayer.ReadSCOPacket: reading SCO data");
				KernelLog.Ln;
				KernelLog.String("handle= 0x");KernelLog.Hex(sco.handle,-2);
				KernelLog.String(" payload length= 0x"); KernelLog.Int(sco.len,0);
				KernelLog.String("; sco.data= ");
				FOR i := 0 TO sco.len-1 DO
					KernelLog.String(" 0x"); KernelLog.Hex(ORD(sco.data[i]),-2);
				END;
				KernelLog.Ln;
			END;
			RETURN sco;
		END ReadSCOPacket;

		PROCEDURE ReadEventPacket() : Bluetooth.Packet;
		VAR event: Bluetooth.EventPacket; i : LONGINT;
		BEGIN
			NEW(event);
			event.code :=in. Get();
			event.paramLen := ORD(in.Get());
			(*ASSERT(event.paramLen < Bluetooth.MaxEventParamLen);*)
			IF (event.paramLen > Bluetooth.MaxEventParamLen) THEN
				KernelLog.String(ModuleName);
				KernelLog.String("TransportLayer.ReadEventPacket: paramLen > MaxParamLen");
				KernelLog.Ln;
				KernelLog.String("paramLen= "); KernelLog.Int(event.paramLen, 0);
				KernelLog.String("; MaxParamLen= "); KernelLog.Int(Bluetooth.MaxEventParamLen, 0);
				KernelLog.String("; in.res= 0x"); KernelLog.Hex(in.res, -2);
				KernelLog.Ln;
			END;
			FOR i := 0 TO event.paramLen-1 DO
				event.params[i] := in.Get();
			END;
			IF (in.res # 0) THEN
				KernelLog.String(ModuleName);
				KernelLog.String("TransportLayer.ReadEventPacket: UART failure; in.res= 0x"); KernelLog.Hex(in.res, -2);
				KernelLog.Ln;
				RETURN NIL;
			END;
			IF TraceReceive THEN
				KernelLog.String(ModuleName);
				KernelLog.String("TransportLayer.ReadEventPacket: reading event Data");
				KernelLog.Ln;
				KernelLog.String("event.code = 0x"); KernelLog.Hex(ORD(event.code),-2);
				KernelLog.String("; event.paramLen= "); KernelLog.Int(event.paramLen,0);
				KernelLog.String("; event.params= ");
				FOR i := 0 TO event.paramLen-1 DO
					KernelLog.String(" 0x"); KernelLog.Hex(ORD(event.params[i]),-2);
				END;
				KernelLog.Ln;
			END;
			RETURN event;
		END ReadEventPacket;

		PROCEDURE ReadUnknownPacket() : Bluetooth.Packet;
		VAR unknown: Bluetooth.UnknownPacket; ch : CHAR;
		BEGIN
			KernelLog.String(ModuleName);
			KernelLog.String("TransportLayer.ReadUnknownPacket: unknown/invalid packet ch= 0x"); KernelLog.Hex(ORD(ch),-2);
			KernelLog.String("; in.res= 0x"); KernelLog.Hex(in.res, -2);
			KernelLog.String("; in.Available()= "); KernelLog.Int(in.Available(), 0);
			KernelLog.Ln;
			NEW(unknown);
			unknown.len := 0;
			WHILE ((in.Available() > 0) & (in.res = 0)) DO
				IF(unknown.len < Bluetooth.MaxUnknownDataLen) THEN
					unknown.data[unknown.len] := in.Get();
					KernelLog.String("unknown.data["); KernelLog.Int(unknown.len,0); KernelLog.String("]= 0x");
					KernelLog.Hex(ORD(unknown.data[unknown.len]),-2);
					KernelLog.String("; in.res= 0x"); KernelLog.Hex(in.res, -2);
					KernelLog.Ln;
					INC(unknown.len);
				ELSE
					ch := in.Get();
					KernelLog.String("discard ch= 0x"); KernelLog.Hex(ORD(ch),-2);
					KernelLog.String("; in.res= 0x"); KernelLog.Hex(in.res, -2);
					KernelLog.Ln;
				END;
			END;
			RETURN unknown;
		END ReadUnknownPacket;


		PROCEDURE Read;
		VAR
			ch: CHAR;
			queue: Bluetooth.Queue;
			packet: Bluetooth.Packet;
		BEGIN
			ch := in.Get();
			IF (in.res # 0) THEN
				KernelLog.String(ModuleName);
				KernelLog.String("TransportLayer.Read: UART failure in.res= 0x"); KernelLog.Hex(in.res, -2);
				KernelLog.String("; closing layer");
				KernelLog.Ln;
				Close;
				RETURN;
			END;
			IF (ch = uartCommand) THEN 	(* HCI command packet *)
				(*HALT(100)	(* not sent by host controller *)*)
				KernelLog.String(ModuleName);
				KernelLog.String("TransportLayer.Read: uartCommand received! closing layer");
				KernelLog.Ln;
				Close;
				RETURN;
			ELSIF (ch = uartACLData) THEN	(* HCI ACL data packet *)
				packet := ReadACLPacket();
				queue := sink[Bluetooth.ACL];
			ELSIF (ch = uartSCOData) THEN	(* HCI SCO data packet *)
				packet := ReadSCOPacket();
				queue := sink[Bluetooth.SCO];
			ELSIF (ch = uartEvent) THEN		(* HCI event packet *)
				packet := ReadEventPacket();
				queue := sink[Bluetooth.Event];
			ELSE 							(* unknown/invalid packet *)
				packet := ReadUnknownPacket();
				queue := sink[Bluetooth.Default];
			END;
			IF (packet = NIL) THEN
				KernelLog.String(ModuleName);
				KernelLog.String("TransportLayer.Read: error while reading packet; ch= "); KernelLog.Char(ch);
				KernelLog.String("; in.res= "); KernelLog.Int(in.res, 0);
				KernelLog.String("; closing layer");
				KernelLog.Ln;
				Close;
				RETURN;
			ELSE
				queue.Add(packet);
			END;
			IF TraceReceive THEN
				KernelLog.String(ModuleName);
				KernelLog.String("TransportLayer.Read done.");
				KernelLog.String(" in.Available()= "); KernelLog.Int(in.Available(), 0);
				KernelLog.Ln;
			END;
		END Read;

		PROCEDURE GetPacketType(type: LONGINT; VAR c: CHAR): BOOLEAN;
		VAR res: BOOLEAN;
		BEGIN
			res := TRUE;
			CASE type OF
				| Bluetooth.Command: c := uartCommand
				| Bluetooth.ACL: c := uartACLData
				| Bluetooth.SCO: c := uartSCOData
				ELSE res := FALSE
			END;
			RETURN res
		END GetPacketType;

		PROCEDURE Send*(type: LONGINT; VAR data: ARRAY OF CHAR; ofs, len: LONGINT; VAR res: WORD);
		VAR  pt: CHAR; i: LONGINT;
		BEGIN {EXCLUSIVE}
			IF ~GetPacketType(type, pt) THEN
				KernelLog.String(ModuleName);
				KernelLog.String("TransportLayer.Send: wrong packet type= 0x"); KernelLog.Hex(type,-2);
				KernelLog.Ln;
				res := Bluetooth.ErrInvalidParameters;
				RETURN
			END;
			IF TraceSend THEN
				KernelLog.String(ModuleName);
				KernelLog.String("TransportLayer.Send: packet type= 0x"); KernelLog.Hex(ORD(pt), -2);
				FOR i := 0 TO len-1 DO
					KernelLog.Char(" ");
					KernelLog.Hex(ORD(data[ofs+i]), -2);
				END;
				KernelLog.Ln
			END;
			out.Char(pt); out.Bytes(data, ofs, len); out.Update;
			res := out.res
		END Send;

		PROCEDURE Send1H*(type: LONGINT; VAR hdr: ARRAY OF CHAR; hdrlen: LONGINT; VAR data: ARRAY OF CHAR; ofs, len: LONGINT; VAR res: WORD);
		VAR pt: CHAR; i: LONGINT;
		BEGIN
			IF ~GetPacketType(type, pt) THEN
				KernelLog.String(ModuleName);
				KernelLog.String("TransportLayer.Send1H: wrong packet type= 0x"); KernelLog.Hex(type,-2);
				KernelLog.Ln;
				res := Bluetooth.ErrInvalidParameters;
				RETURN
			END;
			IF TraceSend THEN
				KernelLog.String(ModuleName);
				KernelLog.String("TransportLayer.Send1H: packet type= 0x"); KernelLog.Hex(ORD(pt), -2);
				FOR i := 0 TO hdrlen-1 DO
					 KernelLog.Char(" "); KernelLog.Hex(ORD(hdr[i]), -2);
				END;
				FOR i := 0 TO len-1 DO
					KernelLog.Char(" "); KernelLog.Hex(ORD(data[ofs+i]), -2);
				END;
				KernelLog.Ln
			END;
			out.Char(pt); out.Bytes(hdr, 0, hdrlen); out.Bytes(data, ofs, len); out.Update;
			res := out.res
		END Send1H;

		PROCEDURE Send2H*(type: LONGINT; VAR hdr1: ARRAY OF CHAR; hdr1len: LONGINT;
								VAR hdr2: ARRAY OF CHAR; hdr2len: LONGINT;
								VAR data: ARRAY OF CHAR; ofs, len: LONGINT; VAR res: WORD);
		VAR pt: CHAR; i: LONGINT;
		BEGIN
			IF ~GetPacketType(type, pt) THEN
				KernelLog.String(ModuleName);
				KernelLog.String("TransportLayer.Send2H: wrong packet type= 0x"); KernelLog.Hex(type,-2);
				KernelLog.Ln;
				res := Bluetooth.ErrInvalidParameters;
				RETURN
			END;
			IF TraceSend THEN
				KernelLog.String(ModuleName);
				KernelLog.String("TransportLayer.Send2H: packet type= 0x"); KernelLog.Hex(ORD(pt), -2);
				FOR i := 0 TO hdr1len-1 DO
					 KernelLog.Char(" "); KernelLog.Hex(ORD(hdr1[i]), -2);
				END;
				FOR i := 0 TO hdr2len-1 DO
					KernelLog.Char(" "); KernelLog.Hex(ORD(hdr2[ofs+i]), -2);
				END;
				FOR i := 0 TO len-1 DO
					KernelLog.Char(" "); KernelLog.Hex(ORD(data[ofs+i]), -2);
				END;
				KernelLog.Ln
			END;
			out.Char(pt); out.Bytes(hdr1, 0, hdr1len); out.Bytes(hdr2, 0, hdr2len); out.Bytes(data, ofs, len); out.Update;
			res := out.res
		END Send2H;

	BEGIN {ACTIVE}
		Objects.SetPriority(3);
		REPEAT
			Read;
		UNTIL dead
	END TransportLayer;

END BluetoothUART.
