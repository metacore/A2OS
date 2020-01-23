MODULE IPMonitor; (** AUTHOR "Patrick Hunziker"; PURPOSE "simple network sniffer"; *)
(* may require running A2 as administrator for certain tasks*)

IMPORT WSock32, Streams, Commands,IP, Modules, Network, Strings, Kernel;

CONST 
	MaxIPPacketSize=64*1024;
	Trace=TRUE;
	Tab=09X;

TYPE 	DatagramHandler*=PROCEDURE{DELEGATE}(interface: IP.Interface; CONST datagram: ARRAY OF CHAR; len:LONGINT);

		(*filter a datagram. TRUE signals that the datagram is to be handled.*)
TYPE 	Filter*=PROCEDURE {DELEGATE}(interface: IP.Interface; CONST datagram: ARRAY OF CHAR; len:LONGINT):BOOLEAN;

TYPE Monitor*= OBJECT
	VAR socket:WSock32.Socket;
		dest: WSock32.sockaddrIn;
		hostname: ARRAY 256 OF CHAR;
		(*local: WSock32.PHostent;*)
		buffer: ARRAY MaxIPPacketSize OF CHAR;
		from: WSock32.sockaddrIn; (*ARRAY 1024 OF CHAR;*)
		fromLen,len:LONGINT;
		trace, alive:BOOLEAN;
		out, error:Streams.Writer;
		adr:IP.Adr;
		handlePacket: DatagramHandler;
		filter: Filter;
		interface: IP.Interface;
		id:LONGINT;
		err:LONGINT;
		src,dst:LONGINT;
		
		(* interface=NIL implies currently default interface, but should include all interfaces *)
		PROCEDURE &Init*(interface: IP.Interface; datagramHandler:DatagramHandler; filter:Filter; out, error:Streams.Writer);
		VAR  cmd, nRead,res:LONGINT; 
			str: ARRAY 128 OF CHAR; resStr:ARRAY 0 OF CHAR;
		BEGIN
			handlePacket:=datagramHandler;
			SELF.interface:=interface;
			SELF.filter:=filter;
			SELF.error:=error;
			SELF.out:=out;
			trace:=Trace;

			socket:=WSock32.socket(WSock32.AFINet, WSock32.SockRaw, WSock32.IPProtoIP);(*low-level access. requires administrator privileges in newer Windows versions*)
			IF (socket#WSock32.InvalidSocket ) THEN 
				pool.Add( SELF, SELF.Finalize )
			ELSE
				IF error#NIL THEN error.String("socket=NIL"); error.Ln; error.Update; END;
				RETURN 
			END;
			
			res:=WSock32.gethostname(hostname, LEN(hostname)); 
			IF trace & (out#NIL) THEN out.String("hostname: "); out.String(hostname); out.Int(res,0); out.Ln; out.Update END;

			adr:=interface.localAdr;
			IF trace& (out#NIL) THEN IP.AdrToStr(adr,str); out.String("interface IP: "); out.String(str); out.Ln; out.Update; END;
			
			dest.sinFamily:=WSock32.AFINet;
			dest.sinPort:=0;
			dest.sinAddr:=adr.ipv4Adr;
			WSock32.bind(socket,dest, SIZEOF(WSock32.sockaddrIn));
			
			(* tell interface to receive all packet types*)
			cmd:=1;
			WSock32.WSAIoctl(socket, WSock32.SIORcvAll, cmd, SIZEOF(LONGINT), resStr, 0, nRead,0, 0); 
			alive:=TRUE;
			id:=nInterfaces; INC(nInterfaces);
		END Init;
		
		PROCEDURE Finalize( ptr: ANY );
		VAR res: LONGINT;
		BEGIN {EXCLUSIVE}
			alive:=FALSE;
			IF socket # WSock32.InvalidSocket THEN
				res := WSock32.shutdown( socket, WSock32.SDboth );
				res := WSock32.closesocket( socket );
				socket := WSock32.InvalidSocket;
			END;
			
		END Finalize;
		
	BEGIN{ACTIVE}
		WHILE alive DO
			fromLen:=1024;
			len:=WSock32.recvfrom(socket,buffer,LEN(buffer),0,from,fromLen); 
			IF len#WSock32.SocketError THEN 
				IF (filter=NIL) OR filter(interface, buffer, len) THEN
					handlePacket(interface, buffer, len);
					(*
					src:= Network.GetNet4(buffer, 0);
					dst:= Network.GetNet4(buffer, 4);
					Network.PutNet4(buffer,0,dst);
					Network.PutNet4(buffer,4,src); 
					err := WSock32.send( socket, buffer[0], len, {} )
					*)
				END;
			ELSE 
				IF error#NIL THEN error.String("?"); error.Update; END;
			END;
		END;
	END Monitor;


VAR 
	monitor:Monitor;
	pool*: Kernel.FinalizedCollection;
	log:Streams.Writer;
	nInterfaces:LONGINT;
	
(*default datagram handler*)
PROCEDURE DefaultHandler(interface: IP.Interface; CONST datagram: ARRAY OF CHAR; readLen:LONGINT); (*! not thread safe yet*)
CONST IdentifyInterface=TRUE;
VAR 
	src,dst,str: ARRAY 16 OF CHAR; 
	version, ipHeadLen, protocol, length:LONGINT;
BEGIN
	IF ORD(datagram[0]) DIV 16 # IP.IPv4 THEN HALT(200) END; (*Not yet implemented*)
	protocol:=ORD(datagram[9]);
	
	IF IdentifyInterface & (interface#NIL) THEN (*identify the incoming interface*)
		IP.AdrToStr(interface.localAdr,str);
		log.String("("); log.String(str); log.String(")"); log.Char(Tab);
	END;
	
	CASE protocol OF (*wikipedia: List_of_IP_protocol_numbers*)
		| 1: log.String("ICMP"); log.Char(Tab)
		| 2: log.String("IGMP" );log.Char(Tab) 
		| 6: log.String("TCP "); log.Char(Tab)
		| 17: log.String("UDP "); log.Char(Tab)
	ELSE log.Int(protocol,6); log.Char(Tab)
	END;
	
	version:=ORD(datagram[0]) DIV 16; log.Int(version,4); log.Char(Tab);
	ipHeadLen:= 4 * (ORD(datagram[0]) MOD 16); log.Int(ipHeadLen,4);log.Char(Tab);
	
	length:= Network.GetNet2(datagram, 2); log.Int(length,8); log.Char(Tab);
	
	IpToStr(datagram,12,src);
	IpToStr(datagram,16,dst);
	log.String(src); log.Char(Tab); log.String("=>") ; log.Char(Tab); 
	log.String(dst); log.Char(Tab);
	
	CASE protocol OF (*wikipedia: List_of_IP_protocol_numbers*)
		| 1: (*ICMP);*) log.Int(ORD(datagram[24]),0);
		| 2:(* IGMP); *)
		| 6: (*TCP); *)log.Int(Network.GetNet2(datagram,ipHeadLen),6);log.String("=>");log.Int(Network.GetNet2(datagram,ipHeadLen+2),6); log.Char(Tab); 
						(*window size*) log.Int(Network.GetNet2(datagram,ipHeadLen+14),8); log.Char(Tab);
						(*sequence number*) log.Int(Network.GetNet4(datagram, ipHeadLen+4),12);
		| 17: (*UDP);*) log.Int(Network.GetNet2(datagram,ipHeadLen),6);log.String("=>");log.Int(Network.GetNet2(datagram,ipHeadLen+2),6); log.Char(Tab); 
						(*packet size*) log.Int(Network.GetNet2(datagram,ipHeadLen+4),8);
	ELSE log.Int(protocol,0); 
	END;
	log.Ln; log.Update;
END DefaultHandler;

PROCEDURE IpToStr(CONST datagram: ARRAY OF CHAR; pos: LONGINT; VAR s: ARRAY OF CHAR);
VAR s0: ARRAY 4 OF CHAR;
BEGIN
	Strings.IntToStr(ORD(datagram[pos]),s); Strings.Append(s,".");
	Strings.IntToStr(ORD(datagram[pos+1]),s0); Strings.Append(s,s0); Strings.Append(s,"."); 
	Strings.IntToStr(ORD(datagram[pos+2]),s0); Strings.Append(s,s0); Strings.Append(s,".");
	Strings.IntToStr(ORD(datagram[pos+3]),s0); Strings.Append(s,s0) 
END IpToStr;

PROCEDURE 	Start*(context:Commands.Context);
VAR interface: IP.Interface
BEGIN
	IF TRUE THEN
		NEW(monitor, IP.default, DefaultHandler, NIL, context.out, context.out);
	END;
	interface:=IP.default.next;
	WHILE TRUE & (interface#NIL) DO (*parallel readout not yet thread safe*)
		NEW(monitor, interface, DefaultHandler, NIL, context.error, context.error);
		interface:=interface.next;
	END;
	log:=context.out;
END Start;

PROCEDURE Stop*;
BEGIN
	pool.Enumerate( Finalize )
END Stop;

PROCEDURE Finalize( obj: ANY;  VAR cont: BOOLEAN );
BEGIN
	obj( Monitor ).Finalize( obj );  cont := TRUE
END Finalize;

BEGIN
	NEW( pool ); 
	Modules.InstallTermHandler(Stop)
END IPMonitor.

IPMonitor.Start~
IPMonitor.Stop~  

SystemTools.FreeDownTo WSock32 ~