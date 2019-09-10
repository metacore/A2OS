(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)
(* modified to obtain correct host name (*alm 11/11/2004*) *)

MODULE NetSystem IN Oberon; (** portable *)	(* pjm *)

(* A Portable Oberon Interface to the Internet Protocols. *)

IMPORT SYSTEM, Modules IN A2, IP IN A2, UDP IN A2, TCP IN A2, DNS IN A2,
	Kernel, Input, Texts, Oberon, Strings, Fonts;

CONST
	CloseTimeout = 5000;	(* ms to wait for Close to finish *)

	anyport* = 0;	(** any port value *)

(** result values *)
	done* = 0;	(** everything went ok *)
	error* = 1;	(** failure occured *)

(** return values of procedure State *)
	closed* = 0;	(** connection is closed (neither sending nor receiving) *)
	listening* = 1;	(** passive connection is listening for a request *)
	in* = 2;	(** receiving only *)
	out* = 3;	(** sending only *)
	inout* = 4;	(** sending and receiving is possible *)
	waitCon* =  5;	(** still waiting to be connected *)
	errorCon* =  6;	(** connecting failed *)

	CR = 0DX;  LF = 0AX;

TYPE
	Connection* = POINTER TO ConnectionDesc;	(** handle for TCP connections *)
	ConnectionDesc* = RECORD
		res*: SIGNED16;	(** result of last operation on a connection (error indication) *)
		pcb: TCP.Connection
	END;

	IPAdr* = IP.Adr; (** IP address in network byte order! *)

	Socket* = POINTER TO SocketDesc;	(** handle for UDP "connections" *)
	SocketDesc* = RECORD
		res*: SIGNED16;	(** result of last operation on a connection (error indication) *)
		pcb: UDP.Socket
	END;

	Password = POINTER TO PasswordDesc;
	PasswordDesc = RECORD
		service, user, host, passwd: ARRAY 64 OF CHAR;
		next: Password
	END;

	Bytes = ARRAY MAX(SIGNED32) OF CHAR;

VAR
	int*: IP.Interface;
	anyIP*: IPAdr;	(** "NIL" ip-number *)
	allIP*: IPAdr;	(** broadcast ip-number *)
	hostIP*: IPAdr;	(** main ip-number of local machine *)
	hostName*: ARRAY 64 OF CHAR;	(** main name of local machine *)
	crlf: ARRAY 2 OF CHAR;
	started: BOOLEAN;
	passwords: Password;
	w: Texts.Writer;
	state: ARRAY TCP.NumStates OF SIGNED16;

(** -- Adressing/Naming section. *)

(** Convert a dotted IP address string (e.g. "1.2.3.4") to an IPAdr value. *)

PROCEDURE ToHost* (num: ARRAY OF CHAR; VAR adr: IPAdr; VAR done: BOOLEAN);
BEGIN
	adr := IP.StrToAdr(num);
	done := ~IP.IsNilAdr(adr);
END ToHost;

(** Convert an IPAdr value to a dotted IP address string. *)

PROCEDURE ToNum*(adr: IPAdr; VAR num: ARRAY OF CHAR);
BEGIN
	IP.AdrToStr(adr, num)
END ToNum;

(** GetIP delivers the ip-number of a named host. If a symbolic name is given, it will be resolved by use of domain name servers. *)

PROCEDURE GetIP*(name: ARRAY OF CHAR; VAR adr: IPAdr);
VAR res: INTEGER;
BEGIN
	adr := IP.StrToAdr(name);
	IF IP.IsNilAdr(adr) THEN
		IF started THEN
			DNS.HostByName(name, adr, res);
			IF res # 0 THEN adr := IP.NilAdr END
		END
	END
END GetIP;

(** GetName is the reverse of GetIP. Given an ip-number, it delivers the name of a host. *)

PROCEDURE GetName* (IP: IPAdr; VAR name: ARRAY OF CHAR);
VAR res: INTEGER;
BEGIN
	IF started THEN
		DNS.HostByNumber(IP, name, res)
	ELSE
		res := -1
	END;
	IF res # DNS.Ok THEN name[0] := 0X END
END GetName;

(** -- TCP section. *)

(** OpenConnection opens a connection. locPort, remPort, remIP are contained in the quadrupel <locIP, remIP, locPort, remPort> which determines a connection uniquely. As locIP is always the current machine, it is omitted. If remPort is equal to anyport or remIP is equal to anyIP, a passive connection will be opened. After execution, C is a brand new connection. res indicates any error. *)

PROCEDURE OpenConnection* (VAR C: Connection; locPort: SIGNED16; remIP: IPAdr; remPort: SIGNED16; VAR res: SIGNED16);
BEGIN
	AsyncOpenConnection(C, locPort, remIP, remPort, res);
	IF res = done THEN
		LOOP
			CASE State(C) OF
				closed, errorCon:
					res := error; C.res := res; EXIT
				|listening, in, out, inout:
					EXIT
				|waitCon:
					(* skip *)
			END
		END
	END
END OpenConnection;

(** Like OpenConnection, but this procedure may return immediately and delay the actual opening of the connection.  In this case State() should be checked to wait for the connection status to change from waitCon. *)

PROCEDURE AsyncOpenConnection*(VAR C: Connection; locPort: SIGNED16; remIP: IPAdr; remPort:SIGNED16; VAR res: SIGNED16);
VAR err: SIGNED32;
BEGIN
	NEW(C); NEW(C.pcb);
	C.pcb.Open(LONG(locPort) MOD 10000H, remIP, LONG(remPort) MOD 10000H, err);
	IF err = 0 THEN
		(*Kernel.WriteString("pcb="); Kernel.WriteHex(SYSTEM.VAL(SIGNED32, C.pcb), 8); Kernel.WriteLn;*)
		Kernel.RegisterObject(C, Cleanup, FALSE);
		res := done
	ELSE
		C.pcb := NIL;
		res := error
	END;
	C.res := res
END AsyncOpenConnection;

(** Close the connection. Connection can not be used for send operations afterwards. *)

PROCEDURE CloseConnection* (C: Connection);
VAR err: SIGNED32;
BEGIN
	IF C.pcb # NIL THEN
		C.pcb.Close();
		C.pcb.AwaitState(TCP.ClosedStates, {}, CloseTimeout, err);
		IF err # 0 THEN C.res := error END;
		C.pcb := NIL
	END
END CloseConnection;

(** Discard the connection. Connection can not be used afterwards. *)

PROCEDURE DiscardConnection* (C: Connection);	(** non-portable *)
VAR err: SIGNED32;
BEGIN
	IF C.pcb # NIL THEN
		C.pcb.Discard();
		C.pcb.AwaitState(TCP.ClosedStates, {}, CloseTimeout, err);
		IF err # 0 THEN C.res := error END;
		C.pcb := NIL
	END
END DiscardConnection;

PROCEDURE Cleanup(c: ANY);
(*VAR s: ARRAY 20 OF CHAR;*)
BEGIN
	WITH c: Connection DO
		IF c.pcb # NIL THEN
			(*IF Trace THEN
				KernelLog.String("NetSystem: Cleanup ");
				ToNum(SYSTEM.VAL(IPAdr, c.port.rip), s);  KernelLog.String(s);
				KernelLog.Char(":");  KernelLog.Int(c.port.rport, 1);
				KernelLog.Ln
			END;*)
			CloseConnection(c); c.pcb := NIL
		END
	END
END Cleanup;

(** Indicates whether there exists a remote machine which wants to connect to the local one. This Procedure is only useful 	on passive connections. For active connections (State(C) # listen), it always delivers FALSE. *)

PROCEDURE Requested* (C: Connection): BOOLEAN;
BEGIN
	RETURN (C.pcb # NIL) & C.pcb.Requested()
END Requested;

(** Procedure accepts a new waiting, active connection (newC) on a passive one (State(C) = listen). If no connection is 	waiting, accept blocks until there is one or an error occurs. If C is not a passive connection, Accept does nothing but res is set to Done. *)

PROCEDURE Accept* (C: Connection; VAR newC: Connection; VAR res: SIGNED16);
VAR client: TCP.Connection; err: SIGNED32;
BEGIN
	C.pcb.Accept(client, err);
	IF err = 0 THEN
		NEW(newC); newC.pcb := client;
		Kernel.RegisterObject(newC, Cleanup, FALSE);
		newC.res := done; res := done
	ELSE
		newC := NIL; res := error
	END
END Accept;

(** Procedure returns the state of a connection (see constant section).  Even if a connection is closed, data can still be available in the local buffer. *)

PROCEDURE State* (C: Connection): SIGNED16;
BEGIN
	IF C.pcb # NIL THEN RETURN state[C.pcb.State()] ELSE RETURN closed END
END State;

(** Returns the number of bytes which may be read without blocking. *)

PROCEDURE Available* (C: Connection): SIGNED32;
BEGIN
	RETURN C.pcb.Available()
END Available;

(** Blocking read a single byte. *)

PROCEDURE Read* (C: Connection; VAR ch: CHAR);
VAR len: SIZE; res: INTEGER; buf: ARRAY 1 OF CHAR;
BEGIN
	C.pcb.Receive(buf, 0, 1, 1, len, res);
	IF (res = 0) & (len = 1) THEN ch := buf[0] ELSE C.res := error; ch := 0X END
END Read;

(** Blocking read len bytes of data (beginning at pos in buf) to buf. *)

PROCEDURE ReadBytes* (C: Connection; pos, len: SIGNED32; VAR buf: ARRAY OF SYSTEM.BYTE);
VAR read: SIZE; res: INTEGER;
BEGIN
	ASSERT(pos+len <= LEN(buf));	(* index check *)
	C.pcb.Receive(SYSTEM.VAL(Bytes, buf), pos, len, len, read, res);
	IF (res = 0) & (len = read) THEN (* skip *) ELSE C.res := error END
END ReadBytes;

(** Blocking read two bytes in network byte ordering. *)

PROCEDURE ReadInt* (C: Connection; VAR x: SIGNED16);
VAR buf: ARRAY 2 OF CHAR; res: INTEGER; len: SIZE;
BEGIN
	C.pcb.Receive(buf, 0, 2, 2, len, res);
	IF (res = 0) & (len = 2) THEN
		x := ORD(buf[0])*100H + ORD(buf[1])
	ELSE
		x := 0; C.res := error
	END
END ReadInt;

(** Blocking read four bytes in network byte ordering. *)

PROCEDURE ReadLInt* (C: Connection; VAR x: SIGNED32);
VAR buf: ARRAY 4 OF CHAR; res: INTEGER; len: SIZE;
BEGIN
	C.pcb.Receive(buf, 0, 4, 4, len, res);
	IF (res = 0) & (len = 4) THEN
		x := ORD(buf[0])*1000000H + ORD(buf[1])*10000H + ORD(buf[2])*100H + ORD(buf[3])
	ELSE
		x := 0; C.res := error
	END
END ReadLInt;

(** Blocking read a string terminated by ( [CR]LF | 0X ). *)

PROCEDURE ReadString* (C: Connection; VAR s: ARRAY OF CHAR);
VAR i: SIGNED32; ch: CHAR;
BEGIN
	i := 0;
	LOOP
		Read(C, ch);
		IF (ch = LF) OR (ch = 0X) THEN EXIT END;
		s[i] := ch; INC(i)
	END;
	IF (ch = LF) & (i > 0) & (s[i-1] = CR) THEN s[i-1] := 0X ELSE s[i] := 0X END
END ReadString;

(** Blocking write a single byte to C. *)

PROCEDURE Write* (C: Connection; ch: CHAR);
VAR res: INTEGER; buf: ARRAY 1 OF CHAR;
BEGIN
	buf[0] := ch;
	C.pcb.Send(buf, 0, 1, FALSE, res);
	IF res = 0 THEN (* skip *) ELSE C.res := error END
END Write;

(** Blocking write len bytes of data (beginning at pos in buf) to C. *)

PROCEDURE WriteBytes* (C: Connection; pos, len: SIGNED32; VAR buf: ARRAY OF SYSTEM.BYTE);
VAR res: INTEGER;
BEGIN
	ASSERT(pos+len <= LEN(buf));
	C.pcb.Send(SYSTEM.VAL(Bytes, buf), pos, len, FALSE, res);
	IF res = 0 THEN (* skip *) ELSE C.res := error END
END WriteBytes;

(** Blocking write two bytes in network byte ordering to C. *)

PROCEDURE WriteInt* (C: Connection; x: SIGNED16);
VAR res: INTEGER; buf: ARRAY 2 OF CHAR;
BEGIN
	buf[0] := CHR(x DIV 100H MOD 100H); buf[1] := CHR(x MOD 100H);
	C.pcb.Send(buf, 0, 2, FALSE, res);
	IF res = 0 THEN (* skip *) ELSE C.res := error END
END WriteInt;

(** Blocking write four bytes in network byte ordering to C. *)

PROCEDURE WriteLInt* (C: Connection; x: SIGNED32);
VAR res: INTEGER; buf: ARRAY 4 OF CHAR;
BEGIN
	buf[0] := CHR(x DIV 1000000H MOD 100H); buf[1] := CHR(x DIV 10000H MOD 100H);
	buf[2] := CHR(x DIV 100H MOD 100H); buf[3] := CHR(x MOD 100H);
	C.pcb.Send(buf, 0, 4, FALSE, res);
	IF res = 0 THEN (* skip *) ELSE C.res := error END
END WriteLInt;

(** Blocking write a string without "0X" and terminated by "CRLF" to C. *)

PROCEDURE WriteString* (C: Connection; s: ARRAY OF CHAR);
VAR i, res: SIGNED32;
BEGIN
	i := 0; WHILE s[i] # 0X DO INC(i) END;
	C.pcb.Send(s, 0, i, FALSE, res);
	IF res = 0 THEN
		C.pcb.Send(crlf, 0, 2, FALSE, res);
		IF res = 0 THEN (* skip *) ELSE C.res := error END
	ELSE
		C.res := error
	END
END WriteString;

(** Procedure delivers the ip-number and port number of a connection's remote partner. *)

PROCEDURE GetPartner* (C: Connection; VAR remIP: IPAdr; VAR remPort: SIGNED16);
BEGIN
	IF C.pcb # NIL THEN
		remIP := C.pcb.fip; remPort := SHORT(C.pcb.fport)
	ELSE
		remIP := anyIP; remPort := anyport
	END
END GetPartner;

(** -- UDP section. *)

(* Datagram oriented communication *)

(** Opens a socket which is dedicated to datagram services. locPort is registered to receive datagrams from any port and any host. *)

PROCEDURE OpenSocket* (VAR S: Socket; locPort: SIGNED16; VAR res: SIGNED16);
VAR err: SIGNED32;
BEGIN
	NEW(S); NEW(S.pcb, LONG(locPort) MOD 10000H, err);
	IF err = 0 THEN res := done ELSE S.pcb := NIL; res := error END;
	S.res := res
END OpenSocket;

(** Closes the socket. You can not receive datagrams anymore. *)

PROCEDURE CloseSocket* (S: Socket);
BEGIN
	S.pcb.Close;
	S.pcb := NIL; S.res := done
END CloseSocket;

(** Sends len bytes of data (beginning at pos in buf) to the host specified by remIP and remPort. *)

PROCEDURE SendDG* (S: Socket; remIP: IPAdr; remPort: SIGNED16; pos, len: SIGNED32; VAR buf: ARRAY OF SYSTEM.BYTE);
VAR res: INTEGER;
BEGIN
	ASSERT(pos+len <= LEN(buf));	(* index check *)
	S.pcb.Send(remIP, LONG(remPort) MOD 10000H, SYSTEM.VAL(Bytes, buf), pos, len, res);
	IF res = 0 THEN S.res := done ELSE S.res := error END
END SendDG;

(** Stores an entire datagram in buf beginning at pos. On success (S.res = done), remIP and remPort indicate the sender, 	len indicates the length of valid data. *)

PROCEDURE ReceiveDG*(S: Socket; VAR remIP: IPAdr; VAR remPort: SIGNED16; pos: SIGNED32; VAR len: SIGNED32;
	VAR buf: ARRAY OF SYSTEM.BYTE);
VAR res, fport: SIGNED32; length: SIZE;
BEGIN
	ASSERT(pos+len <= LEN(buf));	(* index check *)
	S.pcb.Receive(SYSTEM.VAL(Bytes, buf), pos, len, 0, remIP, fport, length, res);
	remPort := SHORT(fport);
	IF res = 0 THEN S.res := done; len := length(SIGNED32) ELSE S.res := error; len := -1 END
END ReceiveDG;

(** Returns the size of the first available datagram on the socket. *)

PROCEDURE AvailableDG* (S: Socket): SIGNED32;
BEGIN
	RETURN 0
END AvailableDG;

(* Conversions *)

(** Write 2 bytes in network byte ordering to buf[pos]. *)

PROCEDURE PutInt* (VAR buf: ARRAY OF SYSTEM.BYTE; pos: SIGNED16; x: SIGNED16);
BEGIN
	buf[pos] := CHR(x DIV 100H MOD 100H);
	buf[pos+1] := CHR(x MOD 100H)
END PutInt;

(** Write 4 bytes in network byte ordering to buf[pos]. *)

PROCEDURE PutLInt* (VAR buf: ARRAY OF SYSTEM.BYTE; pos: SIGNED16; x: SIGNED32);
BEGIN
	buf[pos] := CHR(x DIV 1000000H MOD 100H);
	buf[pos+1] := CHR(x DIV 10000H MOD 100H);
	buf[pos+2] := CHR(x DIV 100H MOD 100H);
	buf[pos+3] := CHR(x MOD 100H)
END PutLInt;

(** Read 2 bytes in network byte ordering from buf[pos]. *)

PROCEDURE GetInt* (VAR buf: ARRAY OF SYSTEM.BYTE; pos: SIGNED16; VAR x: SIGNED16);
BEGIN
	x := ORD(buf[pos])*100H + ORD(buf[pos+1])
END GetInt;

(** Read 4 bytes in network byte ordering from buf[pos]. *)

PROCEDURE GetLInt* (VAR buf: ARRAY OF SYSTEM.BYTE; pos: SIGNED16; VAR x: SIGNED32);
BEGIN
	x := ORD(buf[pos])*1000000H + ORD(buf[pos+1])*10000H + ORD(buf[pos+2])*100H + ORD(buf[pos+3])
END GetLInt;

(** -- Passwords section. *)

PROCEDURE WriteURL(VAR service, user, host: ARRAY OF CHAR);
BEGIN
	Texts.WriteString(w, "NetSystem.SetUser ");  Texts.WriteString(w, service);
	Texts.Write(w, ":");  Texts.WriteString(w, user);  Texts.Write(w, "@");
	Texts.WriteString(w, host);  Texts.WriteString(w, " ~"); Texts.WriteLn(w)
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
				IF ch # CHR(13) THEN Texts.WriteLn(w) END
			END;
			WriteURL(service, user, host);  Texts.Append(Oberon.Log, w.buf)
		END;
		COPY("", user); COPY("", password)
	END
END GetPassword;

(** Remove password for user using service on host. *)

PROCEDURE DelPassword*(service, user, host: ARRAY OF CHAR);
	VAR ppass, pass: Password;
BEGIN
	Strings.Lower(service, service);  Strings.Lower(host, host);
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

(** Command NetSystem.SetUser { service ":" ["//"] [ user [ ":" password ] "@" ] host [ "/" ] } "~" <enter password>
		If password is not specified in-line, prompts for the password for the (service, host, user) triple.
		The (service, host, user, password) 4-tuple is stored in memory for retrieval with GetPassword.
		Multiple identical passwords may be set with one command. *)

PROCEDURE SetUser*;
	VAR
		R: Texts.Reader;
		service, usr, host, pwd, entered: ARRAY 64 OF CHAR;
		ok, verbose: BOOLEAN;
		ch: CHAR;
		pass: Password;

	PROCEDURE Next(VAR str: ARRAY OF CHAR);
		VAR i: SIGNED32;
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

	PROCEDURE InputStr(prompt: ARRAY OF CHAR; show: BOOLEAN; VAR str: ARRAY OF CHAR);
		VAR i: SIGNED32; ch: CHAR;
	BEGIN
		Texts.SetColor(w, 1); Texts.WriteString(w, prompt); Texts.SetColor(w, 15);
		Texts.Append(Oberon.Log, w.buf);
		Input.Read (ch); i := 0;
		WHILE (ch # 0DX) & (ch # 1AX)  DO
			IF ch = 7FX THEN
				IF i > 0 THEN
					Texts.Delete(Oberon.Log, Oberon.Log.len-1, Oberon.Log.len);
					DEC(i)
				END
			ELSE
				IF show THEN Texts.Write(w, ch) ELSE Texts.Write(w, "*") END;
				Texts.Append(Oberon.Log, w.buf);
				str[i] := ch;  INC(i)
			END;
			Input.Read (ch)
		END;
		IF ch # 0DX THEN i := 0 END;
		str[i] := 0X;
		Texts.WriteLn(w);  Texts.Append(Oberon.Log, w.buf)
	END InputStr;

	PROCEDURE Replace(p: Password);
	VAR q, prev: Password;  msg: ARRAY 12 OF CHAR;
	BEGIN
		q := passwords;  prev := NIL;
		WHILE (q # NIL) & ~((q.service = p.service) & (q.host = p.host) & (q.user = p.user)) DO
			prev := q;  q := q.next
		END;
		IF q # NIL THEN	(* password exists, delete old one first *)
			IF prev = NIL THEN passwords := passwords.next
			ELSE prev.next := q.next
			END;
			msg := "replaced"
		ELSE
			msg := "set"
		END;
		p.next := passwords;  passwords := p;
		IF verbose THEN
			Texts.WriteString(w, p.service);  Texts.Write(w, ":");
			Texts.WriteString(w, p.user);  Texts.Write(w, "@");  Texts.WriteString(w, p.host);
			Texts.WriteString(w, " password ");  Texts.WriteString(w, msg);
			Texts.WriteLn(w);  Texts.Append(Oberon.Log, w.buf)
		END
	END Replace;

BEGIN
	Texts.OpenReader(R, Oberon.Par.text, Oberon.Par.pos);
	ok := TRUE;  entered[0] := 0X;  verbose := FALSE;
	WHILE ~R.eot & ok DO
		ok := FALSE;  Next(service);
		IF service = "\v" THEN verbose := TRUE; Next(service) END;
		Strings.Lower(service, service);
		IF ch = ":" THEN
			Next(usr);
			IF ch = ":" THEN	(* password specified in-line *)
				Next(pwd);
				IF ch = "@" THEN Next(host) ELSE COPY(pwd, host); pwd[0] := 0X END
			ELSIF ch = "@" THEN	(* no password specified in-line *)
				pwd[0] := 0X; Next(host)
			ELSE	(* no user or password specified *)
				COPY(usr, host); usr[0] := 0X; pwd[0] := 0X
			END;
			Strings.Lower(host, host);
			IF host[0] # 0X THEN
				IF (usr[0] = 0X) OR ((pwd[0] = 0X) & (entered[0] = 0X)) THEN
					Texts.WriteString(w, service);  Texts.WriteString(w, "://");
					IF usr[0] # 0X THEN Texts.WriteString(w, usr); Texts.Write(w, "@") END;
					Texts.WriteString(w, host);  Texts.WriteLn(w)
				END;
				IF usr[0] = 0X THEN	(* no user specified, prompt *)
					InputStr("Enter user name: ", TRUE, usr);
					IF usr[0] = 0X THEN RETURN END
				END;
				IF pwd[0] = 0X THEN	(* no pwd specified *)
					IF entered[0] = 0X THEN	(* prompt first time *)
						InputStr("Enter password: ", FALSE, entered);
						IF entered[0] = 0X THEN RETURN END	(* esc *)
					END;
					pwd := entered
				END;
				NEW(pass);  COPY(service, pass.service); COPY(host, pass.host);
				COPY(usr, pass.user);  COPY(pwd, pass.passwd);
				Replace(pass);  ok := TRUE
			END
		END
	END
END SetUser;

(** Command NetSystem.ClearUser ~  Clear all passwords from memory. *)

PROCEDURE ClearUser*;
BEGIN
	passwords := NIL
END ClearUser;

(** Command NetSystem.Start ~  Start up NetSystem. *)

PROCEDURE Start*;
BEGIN
	IF ~started THEN
		started := TRUE;
		IF IP.default # NIL THEN
			hostIP := IP.default.localAdr;
		END;
	END
END Start;

(** Command NetSystem.Stop ~  Shut down NetSystem. *)

PROCEDURE Stop*;
BEGIN
	IF started THEN
		hostName := ""; hostIP := IP.NilAdr;
		started := FALSE;
		Texts.WriteString(w, "NetSystem stopped");
		Texts.WriteLn(w); Texts.Append(Oberon.Log, w.buf)
	END
END Stop;

PROCEDURE WriteIPPortAdr(VAR w: Texts.Writer; adr: IP.Adr; port: SIGNED32);
VAR s: ARRAY 16 OF CHAR; i, j: SIGNED32;
BEGIN
	IP.AdrToStr(adr, s);
	i := 0; WHILE s[i] # 0X DO Texts.Write(w, s[i]); INC(i) END;
	IF port # -1 THEN
		Texts.Write(w, ":"); INC(i);
		Strings.IntToStr(port, s);
		j:= 0; WHILE s[j] # 0X DO Texts.Write(w, s[j]); INC(j); INC(i) END;
		j := 21
	ELSE
		j := 16
	END;
	WHILE i < j DO Texts.Write(w, " "); INC(i) END
END WriteIPPortAdr;

BEGIN
	state[TCP.Closed] := closed; state[TCP.Listen] := listening; state[TCP.SynSent] := waitCon;
	state[TCP.SynReceived] := inout; state[TCP.Established] := inout;
	state[TCP.CloseWait] := out; state[TCP.FinWait1] := inout; state[TCP.Closing] := closed;
	state[TCP.LastAck] := closed; state[TCP.FinWait2] := inout; state[TCP.TimeWait] := closed;
	anyIP := IP.NilAdr;
	allIP.usedProtocol := IP.IPv4;
	allIP.ipv4Adr := SIGNED32(0FFFFFFFFH);
	crlf[0] := CR; crlf[1] := LF;
	started := FALSE; hostName := "";
	Texts.OpenWriter(w); passwords := NIL;
	Start;
	Modules.InstallTermHandler(Stop)
END NetSystem.
