(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

(* UDPExample.Mod, ejz

	This module illustrates how to use the UDP based part of NetSystem.
	A command DNS is implemented, which does a DNS look up. *)

MODULE UDPExample IN Oberon;	(** portable *)
	IMPORT Input, Strings, NetSystem, Texts, Oberon;

	CONST
	(* your local DNS server *)
		DNSHost = "129.132.98.11"; DNSPort = 53;
		TimeOut =  10;

	VAR
		W: Texts.Writer;

(* Write str to buf using the DNS encoding scheme. *)
	PROCEDURE PutString(VAR buf: ARRAY OF CHAR; VAR pos: SIGNED16; str: ARRAY OF CHAR);
		VAR p, i, j: SIGNED16;
	BEGIN
		i := 0; j := 0;
		WHILE str[j] # 0X DO
			p := pos; INC(pos); j := i;
			WHILE (str[j] # 0X) & (str[j] # ".") DO
				buf[pos] := str[j];
				INC(j); INC(pos)
			END;
			buf[p] := CHR(j-i);
			IF str[j] = "." THEN INC(j); i := j END
		END;
		buf[pos] := CHR(0); INC(pos)
	END PutString;

(* Read a str from buf and decode it. *)
	PROCEDURE GetString(VAR buf: ARRAY OF CHAR; VAR pos: SIGNED16; VAR str: ARRAY OF CHAR);
		VAR
			s: ARRAY 1024 OF CHAR;
			n, n0, i, ptr: SIGNED16;
	BEGIN
		i := 0;
		n := ORD(buf[pos]); INC(pos);
		WHILE n > 0 DO
			IF n < 64 THEN
				WHILE n > 0 DO
					str[i] := buf[pos];
					INC(i); DEC(n); INC(pos)
				END;
				n := ORD(buf[pos]); INC(pos);
				IF n > 0 THEN str[i] := "."; INC(i) END;
				str[i] := 0X
			ELSE (* pointer field *)
				n0 := ORD(buf[pos]); INC(pos);
				ptr := n0+256*(n MOD 64); n := 0;
				GetString(buf, ptr, s);
				str[i] := 0X; Strings.Append(str, s)
			END
		END
	END GetString;

(** UDPExample.DNS name
	Look up DNS information on name. *)
	PROCEDURE DNS*;
		VAR
			Sc: Texts.Scanner;
			S: NetSystem.Socket;
			IP, remIP: NetSystem.IPAdr;
			buf, name, num: ARRAY 1024 OF CHAR;
			len, ttl: SIGNED32;
			pos, res, res2, remPort, i, type, class, rLen: SIGNED16;
	BEGIN
		Texts.OpenScanner(Sc, Oberon.Par.text, Oberon.Par.pos);
		Texts.Scan(Sc);
		IF Sc.class = Texts.Name THEN
		(* put together a request packet *)
			pos := 0;
			NetSystem.PutInt(buf, pos, 0); INC(pos, 2); (* id *)
			NetSystem.PutInt(buf, pos, 0); INC(pos, 2); (* flags *)
			NetSystem.PutInt(buf, pos, 1); INC(pos, 2); (* number of questions *)
			NetSystem.PutInt(buf, pos, 0); INC(pos, 2);
			NetSystem.PutInt(buf, pos, 0); INC(pos, 2);
			NetSystem.PutInt(buf, pos, 0); INC(pos, 2);
			PutString(buf, pos, Sc.s);
			NetSystem.PutInt(buf, pos, 1); INC(pos, 2); (* query type *)
			NetSystem.PutInt(buf, pos, 1); INC(pos, 2); (* query class *)
		(* allocate a new socket *)
			NetSystem.OpenSocket(S, DNSPort, res);
		(* send the packet to the DNS server DNSHost:DNSPort *)
			NetSystem.GetIP(DNSHost, IP);
			NetSystem.SendDG(S, IP, DNSPort, 0, pos, buf);
		(* wait for a response packet *)
			len := NetSystem.AvailableDG(S); ttl := Input.Time()+TimeOut*Input.TimeUnit;
			WHILE (len <= 0) & (Input.Time() - ttl < 0) DO
				len := NetSystem.AvailableDG(S)
			END;
			IF len > 0 THEN
		(* read the response packet *)
				NetSystem.ReceiveDG(S, remIP, remPort, 0, len, buf);
		(* release the socket *)
				NetSystem.CloseSocket(S);
		(* decode the response packet *)
				NetSystem.GetInt(buf, 8, res); NetSystem.GetInt(buf, 10, res2);
				FOR i := 1 TO res+res2 DO
					GetString(buf, pos, name);
					NetSystem.GetInt(buf, pos, type); INC(pos, 2);
					NetSystem.GetInt(buf, pos, class); INC(pos, 2);
					CASE type OF
						1: Texts.WriteString(W, "ip address")
						|2: Texts.WriteString(W, "name server")
						|5: Texts.WriteString(W, "canonical name")
						|13: Texts.WriteString(W, "host info")
					ELSE
						Texts.WriteString(W, "unknown type "); Texts.WriteInt(W, type, 0);
					END;
					Texts.WriteString(W, " for "); Texts.WriteString(W, name); Texts.WriteString(W, " is ");
					NetSystem.GetLInt(buf, pos, ttl); INC(pos, 4);
					NetSystem.GetInt(buf, pos, rLen); INC(pos, 2);
					IF class # 1 THEN
						Texts.WriteString(W, "unknown class "); Texts.WriteInt(W, type, 0)
					ELSIF (type = 1) & (rLen = 4) THEN
(* Can only be used with IPv4!!
						NetSystem.GetLInt(buf, pos, IP);
						IP := ORD(buf[pos+3]);
						IP := ASH(IP, 8)+ORD(buf[pos+2]);
						IP := ASH(IP, 8)+ORD(buf[pos+1]);
						IP := ASH(IP, 8)+ORD(buf[pos]);
*)						NetSystem.GetLInt(buf, pos, IP.ipv4Adr);
						IP.ipv4Adr := ORD(buf[pos+3]);
						IP.ipv4Adr := ASH(IP.ipv4Adr, 8)+ORD(buf[pos+2]);
						IP.ipv4Adr := ASH(IP.ipv4Adr, 8)+ORD(buf[pos+1]);
						IP.ipv4Adr := ASH(IP.ipv4Adr, 8)+ORD(buf[pos]);
						NetSystem.ToNum(IP, num);
						Texts.WriteString(W, num); INC(pos, 4)
					ELSE
						GetString(buf, pos, num);
						Texts.WriteString(W, num)
					END;
					Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
				END
			ELSE
				Texts.WriteString(W, "time out"); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
			END
		END
	END DNS;

BEGIN
	Texts.OpenWriter(W)
END UDPExample.

UDPExample.DNS NS.INTERNIC.NET
UDPExample.DNS www.microsoft.com
UDPExample.DNS prost.inf.ethz.ch
