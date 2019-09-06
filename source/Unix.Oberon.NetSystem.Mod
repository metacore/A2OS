(* ETH Oberon, Copyright 2000 ETH Zürich Institut für Computersysteme, ETH Zentrum, CH-8092 Zürich.
Refer to the general ETH Oberon System license contract available at: http://www.oberon.ethz.ch/ *)

MODULE NetSystem IN Oberon;


IMPORT S := SYSTEM, IP IN A2, DNS := DNS IN A2, TCP := TCP IN A2,  UDP := UDP IN A2,
		Texts, Oberon, Input, Fonts, Strings, Out;

	CONST
		CR = 0DX; LF = 0AX;

		(* res values *)
		done* = 0;	(*everything went ok*)
		error* = 1;	(*failure occured*)
		timeout* = 2;	(*opening a connection is timed out*)

		(* return values of procedure State *)
		closed* = 0;	(*connection is closed (neither sending nor receiving)*)
		listening* = 1;	(*passive connection is listening for a request*)
		in* = 2;	(*receiving only*)
		out* = 3;	(*sending only*)
		inout* = 4;	(*sending and receiving is possible*)
		waitCon* = 5; (** still waiting for beeing connected *)
		errorCon* = 6; (** connecting failed *)
		undef = -1; (** unknown state *)

		IPAdrLen = 4;

		(* any port value *)
		anyport* = 0;

	TYPE

		IPAdr* = IP.Adr;

		Connection* = TCP.Connection; 	(* TCP-Connection *)


		HostInfo* = POINTER TO HostInfoDesc;  (** handle for asyncrouns GetIP and GetName *)
		HostInfoDesc* = RECORD
			next: HostInfo;
			ip-: IPAdr; (** the ip-number of host name *)
			name-: ARRAY 64 OF CHAR; (** the host name for ip-number *)
			done-, err-, getip: BOOLEAN (** indicating success or failure *)
		END;

		Socket*= UDP.Socket; 	(* UDP-Connection *)


		Password = POINTER TO PasswordDesc;
		PasswordDesc = RECORD
			service, user, host, passwd: ARRAY 64 OF CHAR;
			next: Password
		END;

		Bytes = ARRAY MAX( LONGINT ) OF CHAR;

	VAR
		hostIP* : IPAdr;	(** the ip-number of host name *)
		anyIP*, allIP*: IPAdr;
		hostName*: ARRAY 65 OF CHAR;	(** own machine name *)

		hostInfos: HostInfo;
		passwords: Password;



	PROCEDURE Start*;
	VAR res: WORD;
	BEGIN
		DNS.GetHostName( hostName, res );
		IF res = DNS.Ok  THEN
			DNS.HostByName( hostName, hostIP, res );
		END
	END Start;

	PROCEDURE Stop*;
	BEGIN
	END Stop;


	PROCEDURE ToHost* ( CONST num: ARRAY OF CHAR; VAR adr: IPAdr; VAR done: BOOLEAN );
	BEGIN
		adr := IP.StrToAdr(num);
		done := ~(IP.IsNilAdr(adr))
	END ToHost;

	PROCEDURE ToNum*( adr: IPAdr; VAR num: ARRAY OF CHAR );
	BEGIN
		IP.AdrToStr(adr, num)
	END ToNum;


	PROCEDURE AsyncGetIP*( VAR hostInfo: HostInfo; name: ARRAY OF CHAR );
	VAR res: WORD;
	BEGIN
		NEW( hostInfo ); Strings.Lower( name, name );
		hostInfo.next := NIL; COPY( name, hostInfo.name );
		hostInfo.done := FALSE; hostInfo.err := FALSE;
		IF (name[0] >= "0") & (name[0] <= "9") THEN
			DNS.HostByNumber( hostInfo.ip, name, res );
			hostInfo.err := res # DNS.Ok; hostInfo.done := TRUE
		ELSE
			DNS.HostByName( name, hostInfo.ip, res );	(* human name *)
			IF res = DNS.Ok THEN
				hostInfo.err := FALSE; hostInfo.done := TRUE;
				hostInfo.next := hostInfos;  hostInfos := hostInfo
			ELSE
				hostInfo.err := TRUE
			END
		END;
	END AsyncGetIP;


	PROCEDURE GetIP* ( CONST name: ARRAY OF CHAR;  VAR IP: IPAdr );
	VAR hostInfo: HostInfo;
	BEGIN
		IP := anyIP;
		AsyncGetIP( hostInfo, name );
		IF ~hostInfo.err THEN
			IP := hostInfo.ip
		END
	END GetIP;

	PROCEDURE AsyncGetName*( VAR hostInfo: HostInfo; IP: IPAdr );
	VAR res: WORD;
	BEGIN
			NEW( hostInfo );
			hostInfo.getip := FALSE; hostInfo.next := NIL;
			S.MOVE( ADDRESSOF( IP ), ADDRESSOF( hostInfo.ip ), IPAdrLen );
			hostInfo.done := FALSE; hostInfo.err := FALSE;
			DNS.HostByNumber( hostInfo.ip, hostInfo.name, res );
			IF res = DNS.Ok THEN
				hostInfo.err := FALSE; hostInfo.done := TRUE;
				hostInfo.next := hostInfos; hostInfos := hostInfo
			ELSE
				hostInfo.err := TRUE; hostInfo.name[0]:= 0X
			END
	END AsyncGetName;

	PROCEDURE GetName* ( IP: IPAdr; VAR name: ARRAY OF CHAR );
	VAR hostInfo: HostInfo;
	BEGIN
		COPY("", name);
		AsyncGetName( hostInfo, IP );
		IF ~hostInfo.err THEN
			COPY( hostInfo.name, name )
		END
	END GetName;

	(** Passwords *)

	PROCEDURE WriteURL( CONST service, user, host: ARRAY OF CHAR );
	BEGIN
		Out.String("NetSystem.SetUser ");  Out.String(service);
		Out.Char(":");  Out.String(user);  Out.Char("@");
		Out.String(host);  Out.String(" ~"); Out.Ln
	END WriteURL;

	(** Retrieve the password for user using service on host.  Parameters service, host and user must be specified.
	Parameter user is in/out.  If empty, it returns the first (user,password) pair found, otherwise it returns the
	specified user's password. *)

	PROCEDURE GetPassword*(service, host: ARRAY OF CHAR;  VAR user, password: ARRAY OF CHAR);
	VAR pass: Password;  r: Texts.Reader;  ch: CHAR;
	BEGIN
		Strings.Lower(service, service);  Strings.Lower(host, host);
		pass := passwords;
		WHILE (pass # NIL) & ~((pass.service = service) & (pass.host = host) & ((user = "") OR (pass.user = user))) DO
			pass := pass.next
		END;
		IF pass # NIL THEN
			COPY(pass.user, user);  COPY(pass.passwd, password)
		ELSE
			IF (service # "") & (user # "") THEN
				IF Oberon.Log.len > 0 THEN
					Texts.OpenReader(r, Oberon.Log, Oberon.Log.len-1);
					Texts.Read(r, ch);
					IF ch # CHR(13) THEN Out.Ln END
				END;
				WriteURL(service, user, host);
			END;
			COPY("", user); COPY("", password)
		END
	END GetPassword;

	(** Remove password for user using service on host. *)
	PROCEDURE DelPassword*( CONST pservice, user, phost: ARRAY OF CHAR);
	VAR ppass, pass: Password;
		service, host: ARRAY 64 OF CHAR;
	BEGIN
		Strings.Lower( pservice, service );  Strings.Lower( phost, host );
		ppass := NIL; pass := passwords;
		WHILE (pass # NIL) & ((pass.service # service) & (pass.host # host) & (pass.user # user)) DO
			ppass := pass; pass := pass.next
		END;
		IF pass # NIL THEN
			IF ppass # NIL THEN
				ppass.next := pass.next
			ELSE
				passwords := pass.next
			END
		END
	END DelPassword;

	(** NetSystem.SetUser { service ":" ["//"] user [ ":" password ] "@" host [ "/" ] } "~" password
		If not specified in-line, enter the password for the (service, host, user) triple.
		The (service, host, user, password) 4-tuple is stored in memory for retrieval with GetPassword. *)
	PROCEDURE SetUser*;
		VAR
			R: Texts.Reader;
			service, usr, host, pwd: ARRAY 64 OF CHAR;
			pass, list: Password;
			ok, verbose: BOOLEAN;
			ch: CHAR;

		PROCEDURE Next(VAR str: ARRAY OF CHAR);
		VAR i: LONGINT;
		BEGIN
			Texts.Read(R, ch);
			WHILE ~R.eot & ((ch <= " ") OR (ch = ":") OR (ch = "@") OR (ch = "/") OR ~(R.lib IS Fonts.Font)) DO
				Texts.Read(R, ch)
			END;
			i := 0;
			WHILE ~R.eot & (ch > " ") & (ch # ":") & (ch # "@") & (ch # "/") & (ch # "~") & (R.lib IS Fonts.Font) DO
				str[i] := ch; INC(i); Texts.Read(R, ch)
			END;
			str[i] := 0X
		END Next;

		PROCEDURE ReadPwd;
		VAR i: LONGINT;
		BEGIN
			Out.String("Password: ");
			Input.Read(ch); i := 0;
			WHILE ch > " " DO
				IF ch = 7FX THEN
					IF i > 0 THEN
						Texts.Delete(Oberon.Log, Oberon.Log.len-1, Oberon.Log.len);
						DEC(i)
					END
				ELSE
					Out.Char("*");
					pwd[i] := ch;  INC(i)
				END;
				Input.Read(ch)
			END;
			pwd[i] := 0X;
			Out.Ln;
		END ReadPwd;

		PROCEDURE Replace(p: Password);
		VAR q: Password;
		BEGIN
			q := passwords;
			WHILE (q # NIL) & ~((q.service = p.service) & (q.host = p.host) & (q.user = p.user)) DO
				q := q.next
			END;
			IF verbose THEN
				Out.String(p.service); Out.Char(":");
				Out.String(p.user); Out.Char("@"); Out.String(p.host)
			END;
			IF q = NIL THEN
				p.next := passwords;  passwords := p;
				IF verbose THEN Out.String(" password set") END
			ELSE
				COPY(p.passwd, q.passwd);
				IF verbose THEN Out.String(" password replaced") END
			END;
			IF verbose THEN Out.Ln  END
		END Replace;

	BEGIN
		Texts.OpenReader(R, Oberon.Par.text, Oberon.Par.pos);
		ok := TRUE; verbose := FALSE; list := NIL;
		WHILE ~R.eot & ok DO
			ok := FALSE; Next(service);
			IF service = "\v" THEN verbose := TRUE; Next(service) END;
			Strings.Lower(service, service);
			IF ch = ":" THEN
				Next(usr);
				IF ch = "@" THEN	(* no password specified, prompt for password later *)
					Next(host);  Strings.Lower(host, host);
					IF host # "" THEN
						NEW(pass);  pass.next := list; list := pass;	(* add to temp list *)
						COPY(service, pass.service); COPY(host, pass.host); COPY(usr, pass.user);
						ok := TRUE
					END
				ELSIF ch = ":" THEN	(* password specified in-line *)
					Next(pwd);
					IF ch = "@" THEN
						Next(host);
						IF host # "" THEN
							NEW(pass); COPY(service, pass.service); COPY(host, pass.host);
							COPY(usr, pass.user); COPY(pwd, pass.passwd);
							Replace(pass); ok := TRUE
						END
					END
				END
			END
		END;
		IF list # NIL THEN
			ReadPwd;
			IF ch = CR THEN	(* password entered *)
				WHILE list # NIL DO
					pass := list; list := list.next; COPY(pwd, pass.passwd); Replace(pass)
				END
			END
		END
	END SetUser;

	(** clears all passwords from memory *)
	PROCEDURE ClearUser*;
	BEGIN
		passwords := NIL
	END ClearUser;



(************************************** TCP ****************************************)


	PROCEDURE Available* (conn: Connection): LONGINT;
	BEGIN
		RETURN conn.Available()
	END Available;


	PROCEDURE OpenConnection* ( VAR conn: Connection; locPort: INTEGER; remIP: IPAdr; remPort: INTEGER;
													VAR res: INTEGER );
	VAR r: LONGINT;
	BEGIN
		IF remPort = anyport THEN remIP := anyIP END;
		NEW( conn );
		conn.Open( locPort, remIP, LONG(remPort) MOD 10000H, r );
		IF r = TCP.Ok THEN res := done  ELSE  res := error  END
	END OpenConnection;

	PROCEDURE AsyncOpenConnection* (  VAR conn: Connection; locPort: INTEGER; remIP: IPAdr; remPort: INTEGER;
																 VAR res: INTEGER );
	BEGIN
		OpenConnection( conn, locPort, remIP, remPort, res )
	END AsyncOpenConnection;


	PROCEDURE CloseConnection* ( conn: Connection );
	BEGIN
		IF conn # NIL THEN conn.Close() END
	END CloseConnection;

	PROCEDURE Requested* ( conn: Connection ): BOOLEAN;
	BEGIN
		RETURN (conn.state = listening) & conn.Requested()
	END Requested;

	PROCEDURE Accept* ( conn: Connection; VAR newC: Connection; VAR res: INTEGER );
	VAR r: LONGINT;
	BEGIN
		conn.Accept( newC, r );
		IF r = TCP.Ok THEN res := done  ELSE  res := error  END
	END Accept;

	PROCEDURE State* (conn: Connection): INTEGER;
	BEGIN
		CASE conn.state OF
		| TCP.Closed:		RETURN closed
		| TCP.Listen:			RETURN listening
		| TCP.Established:	RETURN inout
		ELSE
			RETURN undef
		END
	END State;

	PROCEDURE GetPartner* (conn:Connection; VAR remIP: IPAdr; VAR remPort: INTEGER);
	BEGIN
		remIP := conn.fip;
		remPort := SHORT( conn.fport )
	END GetPartner;

	(*----- Read -----*)

	PROCEDURE Read* (conn: Connection; VAR ch: CHAR);
	VAR l: SIZE; r: WORD; bytes: ARRAY 1 OF CHAR;
	BEGIN
		conn.Receive( bytes, 0, 1, 1, l, r );
		ch := bytes[0];
	END Read;

	PROCEDURE ReadBytes* ( conn: Connection; pos, len: LONGINT; VAR buf: ARRAY OF S.BYTE );
	VAR l: SIZE; r: WORD;
	BEGIN
		conn.Receive( S.VAL( Bytes, buf ), pos, len, len, l, r );
	END ReadBytes;

	PROCEDURE ReadBool* (conn: Connection; VAR b: BOOLEAN);
	VAR l: SIZE; r: WORD; bytes: ARRAY 1 OF CHAR;
	BEGIN
		conn.Receive(bytes, 0, 1, 1, l, r );
		b := ODD(ORD(bytes[0]));
	END ReadBool;

	PROCEDURE ReadInt* ( conn: Connection; VAR x: INTEGER );
	VAR buf: ARRAY 4 OF CHAR; len: SIZE; res: WORD;
	BEGIN
		conn.Receive( buf, 0, 2, 2, len, res );
		IF (res = 0) & (len = 2) THEN
			x := ORD(buf[0])*100H + ORD(buf[1])
		ELSE
			x := 0
		END
	END ReadInt;

	PROCEDURE ReadLInt* (conn: Connection; VAR x: LONGINT);
	VAR buf: ARRAY 4 OF CHAR; len: SIZE; res: WORD;
	BEGIN
		conn.Receive( buf, 0, 4, 4, len, res );
		IF (res = 0) & (len = 4) THEN
		x := ORD(buf[0])*1000000H + ORD(buf[1])*10000H + ORD(buf[2])*100H + ORD(buf[3])
		ELSE
			x := 0
		END
	END ReadLInt;

	(** Blocking read a string terminated by ( [CR]LF | 0X ). *)
	PROCEDURE ReadString* (conn: Connection; VAR s: ARRAY OF CHAR);
	VAR
		ch, ch0: CHAR;
		i, l: SIZE; r: WORD;
		bytes: ARRAY 1 OF CHAR;
	BEGIN
		i := -1; ch := 0X;
		REPEAT
			INC( i );
			ch0 := ch;
			conn.Receive( bytes, 0, 1, 1, l, r );
			ch := bytes[0];
			s[i] := ch;
		UNTIL ( r # TCP.Ok) OR (ch = 0X) OR (ch = LF);
		IF (ch = LF) & (ch0 = CR) THEN
			s[i - 1] := 0X
		ELSE s
			[i] := 0X
		END
	END ReadString;

	(*----- Write -----*)

	PROCEDURE Write* (conn: Connection; ch: CHAR);
	VAR r: LONGINT; bytes: ARRAY 1 OF CHAR;
	BEGIN
		bytes[0] := ch;
		conn.Send( bytes, 0, 1, TRUE, r )
	END Write;

	PROCEDURE WriteBytes* (conn: Connection; pos, len: LONGINT; CONST buf: ARRAY OF S.BYTE );
	VAR r: LONGINT;
	BEGIN
		conn.Send( S.VAL( Bytes, buf ), pos, len, TRUE, r)
	END WriteBytes;

	PROCEDURE WriteBool* (conn: Connection; b: BOOLEAN);
	VAR r: LONGINT; bytes: ARRAY 1 OF CHAR;
	BEGIN
		IF b THEN bytes[0] := 1X ELSE bytes[0] := 0X END;
		conn.Send( bytes, 0, 1, TRUE, r )
	END WriteBool;

	PROCEDURE WriteInt* (conn: Connection; x: INTEGER);
	VAR buf: ARRAY 2 OF CHAR; r: LONGINT;
	BEGIN
		buf[0] := CHR(x DIV 100H MOD 100H);
		buf[1] := CHR(x MOD 100H);
		conn.Send( buf, 0, 2, TRUE, r )
	END WriteInt;

	PROCEDURE WriteLInt* (conn: Connection; x: LONGINT);
	VAR buf: ARRAY 4 OF CHAR; r: LONGINT;
	BEGIN
		buf[0] := CHR(x DIV 1000000H MOD 100H);
		buf[1] := CHR(x DIV 10000H MOD 100H);
		buf[2] := CHR(x DIV 100H MOD 100H);
		buf[3] := CHR(x MOD 100H);
		conn.Send( buf, 0, 4, TRUE, r )
	END WriteLInt;

	PROCEDURE WriteString* (conn: Connection; CONST s: ARRAY OF CHAR);
	VAR
		cs: ARRAY 2 OF CHAR;
		i, r: LONGINT;
	BEGIN  i := 0;
		WHILE s[i] # 0X DO  INC( i )  END;
		conn.Send( s, 0, i, FALSE, r);
		cs[0] := CR; cs[1] := LF;
		conn.Send( cs, 0, 2, TRUE, r )
	END WriteString;

(******************************** UDP **************************************)


	PROCEDURE OpenSocket* ( VAR soc: Socket; locPort: INTEGER; VAR res: INTEGER );
	VAR r: LONGINT;
	BEGIN
		NEW( soc, LONG( locPort ) MOD 10000H, r );
		IF r = UDP.Ok THEN res := done  ELSE  res := error  END
	END OpenSocket;

	PROCEDURE CloseSocket* (S: Socket);
	BEGIN
		S.Close();
	END CloseSocket;

	PROCEDURE AvailableDG* (soc: Socket): LONGINT;
	BEGIN
		RETURN 0
	END AvailableDG;

	PROCEDURE SendDG* ( soc: Socket; remIP: IPAdr; remport: INTEGER; pos, len: LONGINT; CONST buf: ARRAY OF S.BYTE );
	VAR res: WORD;
	BEGIN
		soc.Send( remIP, LONG(remport) MOD 10000H, S.VAL( Bytes, buf ), pos, len, res )
	END SendDG;

	PROCEDURE ReceiveDG* ( soc: Socket; VAR remIP: IPAdr; VAR remport: INTEGER;
							pos: LONGINT; VAR len: LONGINT; VAR buf: ARRAY OF S.BYTE );
	VAR res, port: LONGINT; length: SIZE;
	BEGIN
		soc.Receive( S.VAL( Bytes, buf ), pos, len, 0, remIP, port, length, res );
		len := length(LONGINT);
		remport := SHORT( port)
	END ReceiveDG;


	(** Write 2 bytes in network byte ordering to buf[pos]. *)

	PROCEDURE PutInt* (VAR buf: ARRAY OF S.BYTE; pos: INTEGER; x: INTEGER);
	BEGIN
		buf[pos] := CHR(x DIV 100H MOD 100H);
		buf[pos+1] := CHR(x MOD 100H)
	END PutInt;

	(** Write 4 bytes in network byte ordering to buf[pos]. *)

	PROCEDURE PutLInt* (VAR buf: ARRAY OF S.BYTE; pos: INTEGER; x: LONGINT);
	BEGIN
		buf[pos] := CHR(x DIV 1000000H MOD 100H);
		buf[pos+1] := CHR(x DIV 10000H MOD 100H);
		buf[pos+2] := CHR(x DIV 100H MOD 100H);
		buf[pos+3] := CHR(x MOD 100H)
	END PutLInt;

	(** Read 2 bytes in network byte ordering from buf[pos]. *)

	PROCEDURE GetInt* (CONST buf: ARRAY OF S.BYTE; pos: INTEGER; VAR x: INTEGER);
	BEGIN
		x := ORD(buf[pos])*100H +
			ORD(buf[pos+1])
	END GetInt;

	(** Read 4 bytes in network byte ordering from buf[pos]. *)

	PROCEDURE GetLInt* (CONST buf: ARRAY OF S.BYTE; pos: INTEGER; VAR x: LONGINT);
	BEGIN
		x := ORD( buf[pos] )*1000000H +
			ORD( buf[pos+1] )*10000H +
			ORD( buf[pos+2] )*100H +
			ORD( buf[pos+3] )
	END GetLInt;

BEGIN
	anyIP := IP.NilAdr;
	allIP := IP.NilAdr;
	allIP.usedProtocol := IP.IPv4;
	allIP.ipv4Adr := LONGINT( 0FFFFFFFFH );

	passwords := NIL;
	Start
END NetSystem.
