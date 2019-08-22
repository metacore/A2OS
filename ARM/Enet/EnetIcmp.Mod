MODULE EnetIcmp;
(**
	AUTHOR: Alexey Morozov, HighDim GmbH, 2015
	PURPOSE: Ethernet networking stack, ICMP protocol
*)

IMPORT
	EnetBase, Interfaces := EnetInterfaces;

CONST
	(** ICMP message types *)
	EchoReply* = 0;
	DestinationUnreachable* = 3;
	Redirect* = 5;
	EchoRequest* = 8;
	RouterAdvertisement* = 9;
	RouterSolicitation* = 10;
	TimeExceeded* = 11;
	ParameterProblem* = 12;
	Timestamp* = 13;
	TimestampReply* = 14;
	Photuris* = 40;

TYPE
	(** ICMP echo packet header *)
	IcmpEchoHdr* = RECORD
		type*: EnetBase.Int8;
		code*: EnetBase.Int8;
		checksum*: EnetBase.Int16;
		id*: EnetBase.Int16;
		seq*: EnetBase.Int16;
	END;

	(*
		Handling of an ICMP packet
	*)
	PROCEDURE HandlePacket(intf: EnetBase.Interface; packet: EnetBase.Packet; flags: SET);
	VAR res: EnetBase.ResultCode;
	BEGIN
		CASE packet.icmpHdr.type OF
			|EchoRequest:
				IF packet.ipv4Hdr.dstIpAddr = intf.ipv4Addr.addr[0] THEN (*! reply only if destination address matches *)
					packet.icmpHdr.type := EchoReply;
					INC(packet.icmpHdr.checksum,8); (* modify the checksum according to the changed message type *)
					IF Interfaces.ReplyIp(intf,packet,flags,NIL,res) THEN
					END;
				END;
		ELSE
		END;
	END HandlePacket;

	PROCEDURE Install*(intf: EnetBase.Interface);
	BEGIN
		EnetBase.SetIpPacketHandler(intf,EnetBase.ProtoIcmp,HandlePacket);
	END Install;

END EnetIcmp.
