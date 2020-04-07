MODULE Sockets;	(** AUTHOR "G.F.";  PURPOSE "Interface to Unix sockets" *)

(* derived from NetBase.Mod,  BD / 13.2.96 *)

(*	1998.04.27	g.f.	Linux PPC version	*)
(*	1099.05.17	g.f.	adapted to Threads	*)
(*	1999.11.22	g.f.	Solaris x86 version	*)
(*	2000.02.18	g.f.	adapted to Solaris 8	*)
(*	2001.01.06	g.f.	[c] - flag for new compiler	*)
(*	2007.07.06	g.f.	IP address format converted to IP.Adr *)
(*  	2020.04.06  PDR     perror on socket failure*)

IMPORT S := SYSTEM, Unix, Trace, IP;

CONST

	(*listen *)
	Backlog = 5;		(* max number of pending connections *)

TYPE
	SocketAdr* = POINTER TO RECORD
		family*		: SIGNED16;
		port*		: SIGNED16;	(* in network byte order! *)
	END;

	SocketAdrV4* = POINTER TO RECORD (SocketAdr)
		v4Adr*		: SIGNED32;
		zero*		: ARRAY 8 OF CHAR
	END;

	SocketAdrV6* = POINTER TO RECORD (SocketAdr)
		flowinfo*	: SIGNED32;
		v6Adr*		: ARRAY 16 OF CHAR;
		scopeId*	: SIGNED32;
		srcId*		: SIGNED32
	END;

	NameBuf = POINTER TO RECORD
		buf: ARRAY 64 OF CHAR
	END;

	SocketOption = RECORD END;
	Length = INTEGER;

	Linger = RECORD (SocketOption)
		onoff	: SIGNED32;
		linger	: SIGNED32;
	END;

	Switch = RECORD (SocketOption)
		onoff	: SIGNED32
	END;

VAR
	socket		: PROCEDURE {C} ( af, typ, protocol: INTEGER ): INTEGER;
	setsockopt	: PROCEDURE {C} ( s: INTEGER; level, optname: INTEGER; VAR opt: SocketOption; optlen: Length): INTEGER;
	accept		: PROCEDURE {C} ( s: INTEGER; adrPtr: ADDRESS; VAR adrlen: Length ): INTEGER;
	bind		: PROCEDURE {C} ( s: INTEGER; adr: SocketAdr; adrlen: Length ): INTEGER;
	connect		: PROCEDURE {C} ( s: INTEGER; adr: SocketAdr; adrlen: Length ): INTEGER;
	listen		: PROCEDURE {C} ( s: INTEGER; backlog: INTEGER ): INTEGER;
	recv		: PROCEDURE {C} ( s: INTEGER; buf: ADDRESS; len: SIZE; flags: INTEGER ): SIZE;
	send		: PROCEDURE {C} ( s: INTEGER; buf: ADDRESS; len: SIZE; flags: INTEGER ): SIZE;
	recvfrom	: PROCEDURE {C} ( s: INTEGER; buf: ADDRESS; len: SIZE; flags: INTEGER; from: NameBuf; VAR flen: Length ): SIZE;
	sendto		: PROCEDURE {C} ( s: INTEGER; buf: ADDRESS; len: SIZE; flags: INTEGER; to: SocketAdr; tolen: Length ): SIZE;
	shutdown	: PROCEDURE {C} ( s: INTEGER; how: INTEGER ): INTEGER;

	getpeername	: PROCEDURE {C} ( s: INTEGER; adr: NameBuf; VAR adrlen: Length ): INTEGER;
	getsockname	: PROCEDURE {C} ( s: INTEGER; adr: NameBuf; VAR adrlen: Length ): INTEGER;

	htonl	: PROCEDURE {C} ( hostlong	: UNSIGNED32 ): UNSIGNED32;
	htons	: PROCEDURE {C} ( hostshort	: UNSIGNED16 ): UNSIGNED16;
	ntohl	: PROCEDURE {C} ( netlong	: UNSIGNED32 ): UNSIGNED32;
	ntohs	: PROCEDURE {C} ( netshort	: UNSIGNED16 ): UNSIGNED16;

	PROCEDURE NewSocketAdr*( ip: IP.Adr; port: SIGNED32 ): SocketAdr;
	VAR sadr4: SocketAdrV4;  sadr6: SocketAdrV6; i: SIZE;
	BEGIN
		CASE ip.usedProtocol OF
		| -1:
			NEW( sadr4 );
				sadr4.family := Unix.AFINET;
				sadr4.port := IntToNet( SHORT( port ) );
				sadr4.v4Adr := 0;
			RETURN sadr4
		| IP.IPv4:
			NEW( sadr4 );
				sadr4.family := Unix.AFINET;
				sadr4.port := IntToNet( SHORT( port ) );
				sadr4.v4Adr := ip.ipv4Adr;
			RETURN sadr4
		| IP.IPv6:
			NEW( sadr6 );
				sadr6.family := Unix.AFINET6;
				sadr6.port := IntToNet( SHORT( port ) );
				sadr6.flowinfo := 0;
				FOR i := 0 TO 15 DO  sadr6.v6Adr[i] := ip.ipv6Adr[i]  END;
				sadr6.scopeId := 0;
				sadr6.srcId := 0;
			RETURN sadr6
		ELSE
			HALT( 99 )
		END
	END NewSocketAdr;

	PROCEDURE SockAdrToIPAdr*( sadr: SocketAdr ): IP.Adr;
	VAR ip: IP.Adr;  i: SIZE;
	BEGIN
		IF sadr IS SocketAdrV4 THEN
			ip.usedProtocol := IP.IPv4;
			ip.ipv4Adr := sadr(SocketAdrV4).v4Adr;
			ip.ipv6Adr := ""
		ELSE
			ip.usedProtocol := IP.IPv6;
			ip.ipv4Adr := 0;
			FOR i := 0 TO 15 DO
				ip.ipv6Adr[i] := sadr(SocketAdrV6).v6Adr[i]
			END
		END;
		RETURN ip
	END SockAdrToIPAdr;

	PROCEDURE GetPortNumber*( sadr: SocketAdr ): SIGNED32;
	VAR port: SIGNED32;
	BEGIN
		port := NetToInt( sadr.port );
		IF port < 0 THEN port := port + 10000H END;
		RETURN port
	END GetPortNumber;

	PROCEDURE BufToSocketAdr( CONST buf: ARRAY OF CHAR; len: INTEGER ): SocketAdr;
	VAR adr4: SocketAdrV4; adr6: SocketAdrV6;
	BEGIN
		IF len = Unix.SockAddrSizeV4 THEN
			NEW( adr4 );
			S.MOVE( ADDRESSOF( buf ), ADDRESSOF( adr4^), len );
			RETURN adr4
		ELSE
			NEW( adr6 );
			S.MOVE( ADDRESSOF( buf ), ADDRESSOF( adr6^), len );
			RETURN adr6
		END
	END BufToSocketAdr;

	PROCEDURE Accept*( s: INTEGER ): INTEGER;
	VAR len: Length; err, new: INTEGER;
	BEGIN
		len := 0;
		REPEAT
			new := accept( s, 0, len );
			IF new < 0 THEN  err := Unix.errno()  END
		UNTIL (new > 0) OR (err # Unix.EINTR);
		IF new < 0 THEN  Unix.Perror( "Sockets.Accept" )  END;
		RETURN new
	END Accept;

	PROCEDURE Bind*( s: INTEGER; addr: SocketAdr): BOOLEAN;
	VAR err: INTEGER; len: Length;
	BEGIN
		IF addr.family = Unix.AFINET THEN  len := Unix.SockAddrSizeV4  ELSE  len := Unix.SockAddrSizeV6  END;
		err:= bind( s, addr, len );
		RETURN err = 0
	END Bind;

	PROCEDURE Close*( s: INTEGER );
	BEGIN
		IGNORE shutdown( s, Unix.ShutRDWR );
		IGNORE Unix.close( s );
	END Close;

	PROCEDURE Connect*( s: INTEGER; addr: SocketAdr ): BOOLEAN;
	VAR err: INTEGER; len: Length;
	BEGIN
		IF addr.family = Unix.AFINET THEN  len := Unix.SockAddrSizeV4  ELSE  len := Unix.SockAddrSizeV6  END;
		err:= connect( s, addr, len );
		IF err = 0 THEN
			RETURN TRUE
		ELSE
			Unix.Perror( "Sockets.Connect: " );
			RETURN FALSE
		END;
		RETURN err = 0
	END Connect;

	PROCEDURE GetSockName*( s: INTEGER ): SocketAdr;
	VAR len: Length; err: INTEGER; buf: NameBuf;
	BEGIN
		NEW( buf );  len := 64;
		err := getsockname( s, buf, len );
		IF err = 0 THEN
			RETURN BufToSocketAdr( buf.buf, len )
		ELSE
			Unix.Perror( "Sockets.GetSockName" );
			RETURN NIL
		END
	END GetSockName;

	PROCEDURE GetPeerName*( s: INTEGER ): SocketAdr;
	VAR err: INTEGER; len: Length; buf: NameBuf;
	BEGIN
		NEW( buf );  len := 64;
		err:= getpeername( s, buf, len );
		IF err = 0 THEN
			RETURN BufToSocketAdr( buf.buf, len )
		ELSE
			Unix.Perror( "Sockets.GetPeerName" );
			RETURN NIL
		END
	END GetPeerName;

	PROCEDURE Listen*( s: INTEGER ): BOOLEAN;
	VAR err: INTEGER;
	BEGIN
		err := listen( s, Backlog );
		RETURN err = 0
	END Listen;

	PROCEDURE Recv*( s: INTEGER; VAR buf: ARRAY OF CHAR; pos: SIZE; VAR len: SIZE; flags: INTEGER ): BOOLEAN;
	VAR res: SIZE; err: INTEGER;
	BEGIN
		REPEAT
			res := recv( s, ADDRESSOF( buf[pos] ), len, flags );
			IF res < 0 THEN  err := Unix.errno()  END
		UNTIL (res >= 0) OR (err # Unix.EINTR);
		IF err >= 0 THEN
			len:= res;  RETURN TRUE
		ELSE
			Unix.Perror( "Sockets.Recv" );
			len:= 0;  RETURN FALSE
		END
	END Recv;

	PROCEDURE Send*( s: INTEGER; CONST buf: ARRAY OF CHAR; pos: SIZE; VAR len: SIZE ): BOOLEAN;
	VAR err: SIZE;
	BEGIN
		ASSERT( LEN(buf)-pos >= len );
		err := send( s, ADDRESSOF( buf[pos] ), len, 0 );
		IF err >= 0 THEN
			len := err;  RETURN TRUE
		ELSE
			Unix.Perror( "Sockets.Send" );
			len := 0;  RETURN FALSE
		END
	END Send;

	PROCEDURE RecvFrom*( s: INTEGER; VAR from: SocketAdr;
						VAR buf: ARRAY OF CHAR; pos: SIZE;  VAR len: SIZE ): BOOLEAN;
	VAR res: SIZE; err, size: INTEGER; nbuf: NameBuf;
	BEGIN
		NEW( nbuf ); size := 64;
		REPEAT
			res := recvfrom( s, ADDRESSOF(buf[pos]), LEN( buf ) - pos, 0, nbuf, size );
			IF res < 0 THEN  err := Unix.errno()  END
		UNTIL (res >= 0) OR (err # Unix.EINTR);
		IF res >= 0 THEN
			from := BufToSocketAdr( nbuf.buf, size );
			len := res;  RETURN TRUE
		ELSE
			Unix.Perror( "Sockets.RecvFrom" );
			len := 0;  RETURN FALSE
		END
	END RecvFrom;

	PROCEDURE SendTo*( s: INTEGER;  dest: SocketAdr;  CONST buf: ARRAY OF CHAR;  pos, len: SIZE ): BOOLEAN;
	VAR err: SIZE; size: Length;
	BEGIN
		ASSERT( LEN(buf) - pos >= len );
		IF dest.family = Unix.AFINET THEN  size := Unix.SockAddrSizeV4  ELSE  size := Unix.SockAddrSizeV6  END;
		err:= sendto( s, ADDRESSOF( buf[pos] ), len, 0, dest, size );
		IF err >= 0 THEN
			RETURN TRUE
		ELSE
			Unix.Perror( "Sockets.SendTo" );
			RETURN FALSE
		END
	END SendTo;

	PROCEDURE Socket* ( af, typ, protocol: INTEGER ): INTEGER;
	VAR s: INTEGER;
	BEGIN
		s := socket( af, typ, protocol );
	        IF s = -1 THEN
        	    Unix.Perror( "Sockets.Socket" )
	        END; 
		RETURN s
	END Socket;

	PROCEDURE Available*( s: INTEGER ): SIGNED32;
	VAR available, err: INTEGER;
	BEGIN
		available := 0;
		err := Unix.ioctl( s, Unix.FioNRead, ADDRESSOF( available ) );
		IF err = 0 THEN
			RETURN available
		ELSE
			Unix.Perror( "Sockets.Available (ioctl)" );
			RETURN -1
		END
	END Available;

	PROCEDURE Requested*( s: INTEGER ): BOOLEAN;
	CONST
		SLen = Unix.FdSetLen;
		SetBits = SIZEOF( SET32 ) * 8;
	VAR
		res, i: INTEGER;
		readfds: Unix.FdSet;
		timeout: Unix.Timeval;
	BEGIN
		timeout.sec := 0; timeout.usec := 0;
		FOR i := 0 TO SLen - 1  DO readfds[i] := {} END;
		INCL( readfds[s DIV SetBits],  s MOD SetBits );
		res := Unix.select( s+1, ADDRESSOF( readfds ), 0, 0, timeout );
		RETURN res > 0
	END Requested;

	PROCEDURE AwaitPacket*( s: INTEGER; ms: SIGNED32 ): BOOLEAN;
	CONST
		SLen = Unix.FdSetLen;
		SetBits = SIZEOF( SET32 ) * 8;
	VAR
		res, err, i: INTEGER;
		readfds: Unix.FdSet;
		timeout: Unix.Timeval;
	BEGIN
		timeout.sec := ms DIV 1000;  ms := ms MOD 1000;
		timeout.usec := 1000*ms;
		FOR i := 0 TO SLen - 1  DO readfds[i] := {} END;
		INCL( readfds[s DIV SetBits],  s MOD SetBits );
		REPEAT
			res := Unix.select( s+1, ADDRESSOF( readfds ), 0, 0, timeout );
			IF res < 0 THEN  err := Unix.errno()  END
		UNTIL (res >= 0) OR (err # Unix.EINTR);
		RETURN res > 0
	END AwaitPacket;

	PROCEDURE SetLinger* ( s: INTEGER ): BOOLEAN;
	VAR
		linger: Linger;
		err: INTEGER;
	BEGIN
		linger.onoff := 1;  linger.linger := 1;
		err := setsockopt( s, Unix.SoLSocket, Unix.SoLinger, linger, SIZE OF Linger);
		IF err # 0 THEN  Unix.Perror(  "Sockets.SetLinger (setsockopt)" )  END;
		RETURN err = 0
	END SetLinger;

	PROCEDURE KeepAlive* ( s: INTEGER; enable: BOOLEAN ): BOOLEAN;
	VAR
		opt: Switch;
		err: INTEGER;
	BEGIN
		IF enable THEN  opt.onoff := 1  ELSE  opt.onoff := 0  END;
		err := setsockopt( s, Unix.SoLSocket, Unix.SoKeepAlive, opt, SIZE OF Switch );
		IF err # 0 THEN  Unix.Perror(  "Sockets.KeepAlive (setsockopt)" )  END;
		RETURN err = 0
	END KeepAlive;

	PROCEDURE NoDelay* ( s: INTEGER; enable: BOOLEAN ): BOOLEAN;
	VAR
		opt: Switch;
		err: INTEGER;
	BEGIN
		IF enable THEN  opt.onoff := 1  ELSE  opt.onoff := 0  END;
		err := setsockopt( s, Unix.IpProtoTCP, Unix.SoNoDelay, opt, SIZE OF Switch );
		IF err # 0 THEN  Unix.Perror(  "Sockets.NoDelay (setsockopt)" )  END;
		RETURN err = 0
	END NoDelay;

	PROCEDURE NetToInt* (x: SIGNED16): SIGNED16;
	BEGIN
		RETURN SIGNED16(ntohs(x))
	END NetToInt;

	PROCEDURE IntToNet* (x: SIGNED16): SIGNED16;
	BEGIN
		RETURN SIGNED16(htons(x))
	END IntToNet;

	PROCEDURE NetToLInt* (x: SIGNED32): SIGNED32;
	BEGIN
		RETURN SIGNED32(ntohl(x))
	END NetToLInt;

	PROCEDURE LIntToNet* (x: SIGNED32): SIGNED32;
	BEGIN
		RETURN SIGNED32(htonl(x))
	END LIntToNet;

	PROCEDURE Init;
	VAR slib: ADDRESS;
	BEGIN
		IF Unix.Version = "Solaris" THEN
			slib := Unix.Dlopen( "libsocket.so.1", 2 );
			IF slib = 0 THEN  slib := Unix.Dlopen( "libsocket.so", 2 )  END;
			IF slib = 0 THEN  Trace.StringLn( "Unix.Dlopen( 'libsocket.so' ) failed")  END;
		ELSE
			slib := Unix.libc
		END;
		Unix.Dlsym( slib, "accept", ADDRESSOF( accept ) );
		Unix.Dlsym( slib, "bind", ADDRESSOF( bind ) );
		Unix.Dlsym( slib, "connect", ADDRESSOF( connect ) );
		Unix.Dlsym( slib, "shutdown", ADDRESSOF( shutdown ) );
		Unix.Dlsym( slib, "getpeername", ADDRESSOF( getpeername ) );
		Unix.Dlsym( slib, "htonl", ADDRESSOF( htonl ) );
		Unix.Dlsym( slib, "htons", ADDRESSOF( htons ) );
		Unix.Dlsym( slib, "listen", ADDRESSOF( listen ) );
		Unix.Dlsym( slib, "ntohl", ADDRESSOF( ntohl ) );
		Unix.Dlsym( slib, "ntohs", ADDRESSOF( ntohs ) );
		Unix.Dlsym( slib, "recv", ADDRESSOF( recv ) );
		Unix.Dlsym( slib, "recvfrom", ADDRESSOF( recvfrom ) );
		Unix.Dlsym( slib, "send", ADDRESSOF( send ) );
		Unix.Dlsym( slib, "sendto", ADDRESSOF( sendto ) );
		Unix.Dlsym( slib, "setsockopt", ADDRESSOF( setsockopt ) );
		Unix.Dlsym( slib, "socket", ADDRESSOF( socket ) );
		Unix.Dlsym( slib, "getsockname", ADDRESSOF( getsockname ) );
	END Init;

BEGIN
	Init
END Sockets.
