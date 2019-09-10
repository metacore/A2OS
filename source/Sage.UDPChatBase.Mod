MODULE UDPChatBase; (** AUTHOR "SAGE"; PURPOSE "UDP Chat base" *)

IMPORT
	Kernel, Strings, IO := Streams, IP, FS := Files;

CONST

	serverPort*				= 14000;
	UserFile					= "Sage.UDPChatUsers.dat";	(* user file *)

	clientKeepAliveInterval* = 20000;
	clientKeepAliveAwait* = clientKeepAliveInterval * 3 + clientKeepAliveInterval DIV 2;

	UDPHdrLen = 8;
	MaxUDPDataLen* = 10000H - UDPHdrLen;

	VERSION*				= 0002H; (* Identifies the packet as an ICQ packet *)

	ACK*					= 000AH; (* Acknowledgement *)

	SEND_MESSAGE*		= 010EH; (* Send message through server (to offline user) *)
	LOGIN*					= 03E8H; (* Login on server *)
	CONTACT_LIST*			= 0406H; (* Inform the server of my contact list *)
	SEARCH_UIN*			= 041AH; (* Search for user using his/her UIN *)
	SEARCH_USER*			= 0424H; (* Search for user using his/her name or e-mail *)
	KEEP_ALIVE*			= 042EH; (* Sent to indicate connection is still up *)
	SEND_TEXT_CODE*		= 0438H; (* Send special message to server as text *)
	LOGIN_1*				= 044CH; (* Sent during login *)
	INFO_REQ*				= 0460H; (* Request basic information about a user *)
	EXT_INFO_REQ*			= 046AH; (* Request extended information about a user *)
	CHANGE_PASSWORD*	= 049CH; (* Change the user's password *)
	STATUS_CHANGE*		= 04D8H; (* User has changed online status (Away etc) *)
	LOGIN_2*				= 0528H; (* Sent during login *)

	UPDATE_INFO*			= 050AH; (* Update my basic information *)
	UPDATE_EXT_INFO*		= 04B0H; (* Update my extended information *)
	ADD_TO_LIST*			= 053CH; (* Add user to my contact list *)
	REQ_ADD_TO_LIST*		= 0456H; (* Request authorization to add to contact list *)
	QUERY_SERVERS*		= 04BAH; (* Query the server about address to other servers *)
	QUERY_ADDONS*		= 04C4H; (* Query the server about globally defined add-ons *)
	NEW_USER_1*			= 04ECH; (* Ask for permission to add a new user *)
	NEW_USER_REG*		= 03FCH; (* Register a new user *)
	NEW_USER_INFO*		= 04A6H; (* Send basic information about a new user *)
	CMD_X1*				= 0442H; (* *Unknown *)
	MSG_TO_NEW_USER*	= 0456H; (* Send a message to a user not on my contact list
				(this one is also used to request permission to add someone with 'authorize'
				status to your contact list)
				*)

	LOGIN_REPLY*			= 005AH; (* Login reply *)
	USER_ONLINE*			= 006EH; (* User on contact list is online/has changed online status *)
	USER_OFFLINE*			= 0078H; (* User on contact list has gone offline *)
	USER_FOUND*			= 008CH; (* User record found matching search criteria *)
	RECEIVE_MESSAGE*		= 00DCH; (* Message sent while offline/through server *)
	END_OF_SEARCH*		= 00A0H; (* No more USER_FOUND will be sent *)
	INFO_REPLY*			= 0118H; (* Return basic information about a user *)
	EXT_INFO_REPLY*		= 0122H; (* Return extended information about a user *)
	STATUS_UPDATE*		= 01A4H; (* User on contact list has changed online status (Away etc) *)

	REPLY_X1*				= 021CH; (* *Unknown (returned during login) *)
	REPLY_X2*				= 00E6H; (* *Unknown (confirm my UIN?) *)
	UPDATE_REPLY*			= 01E0H; (* Confirmation of basic information update *)
	UPDATE_EXT_REPLY*		= 00C8H; (* Confirmation of extended information update *)
	NEW_USER_UIN*		= 0046H; (* Confirmation of creation of new user and newly assigned UIN *)
	NEW_USER_REPLY*		= 00B4H; (* Confirmation of new user basic information *)
	QUERY_REPLY*			= 0082H; (* Response to QUERY_SEVERS or QUERY_ADDONS *)
	SYSTEM_MESSAGE*		= 01C2H; (* System message with URL'ed button *)

	MESSAGE_TYPE_NORMAL* = 0001H; (*the message is a normal message*)
	MESSAGE_TYPE_URL* = 0004H; (*the message is an URL, and actually consists of two parts,
											separated by the code FE.
											The first part is the description of the URL, and the second part is the
											actual URL.*)
	MESSAGE_TYPE_DATA* = 0008H;

TYPE

	String = Strings.String;

	ACKRec* = POINTER TO RECORD
		seqNum*: SIGNED16;
	END;

	Client* = OBJECT
	VAR
		ip*: IP.Adr;
		port*: SIGNED32;
		inSeqNum*, outSeqNum*: SIGNED16;
		uin*: SIGNED32;

		keepAliveTimer*: Kernel.MilliTimer;

		ACKList-: List;

	PROCEDURE &New*;
	BEGIN
		NEW (ACKList);
	END New;

	PROCEDURE Finalize*;
	BEGIN
		ACKList.Clear;
	END Finalize;

	END Client;

	UserInfo* = POINTER TO RECORD
		uin*: SIGNED32;
		shortName*, fullName*, eMail*: ARRAY 65 OF CHAR;
	END;

	User* = POINTER TO RECORD (UserInfo)
		password*: SIGNED32;
	END;

	Users* = OBJECT
	VAR
		list: List;
		lastUIN: SIGNED32;

		PROCEDURE &New*;
		BEGIN
			(* Reading of passwords *)
			NEW (list);
			lastUIN := 1000;
			Load;
		END New;

		PROCEDURE Load;
		VAR
			u: User;
			f: FS.File;
			r: FS.Reader;
		BEGIN
			f := FS.Old (UserFile);
			IF f # NIL THEN
				FS.OpenReader (r, f, 0);
				WHILE r.res = IO.Ok DO
					NEW (u);
					r.RawLInt (u.uin);
					r.RawLInt (u.password);
					r.RawString (u.shortName);
					r.RawString (u.fullName);
					r.RawString (u.eMail);
					IF r.res = IO.Ok THEN
						IF u.uin > lastUIN THEN
							lastUIN := u.uin
						END;
						list.Add (u);
					END;
				END;
			END;
		END Load;

		PROCEDURE Store*;
		VAR
			f: FS.File; w: FS.Writer;
			i: SIGNED32;
			u: User;
			ptr: ANY;
		BEGIN
			IF list.GetCount () > 0 THEN
				f := FS.New (UserFile);
				IF (f # NIL) THEN
					FS.OpenWriter(w, f, 0);
					i := 0;
					WHILE (w.res = IO.Ok) & (i < list.GetCount ())  DO
						ptr := list.GetItem (i);
						u := ptr (User);
						w.RawLInt(u.uin);
						w.RawLInt(u.password);
						w.RawString(u.shortName);
						w.RawString(u.fullName);
						w.RawString(u.eMail);
						INC (i);
					END;
					IF w.res = IO.Ok THEN
						w.Update;
						FS.Register (f)
					END
				END
			END
		END Store;

		PROCEDURE Add* (password, shortName, fullName, eMail: String): User;
		VAR
			u: User;
		BEGIN
			NEW (u);
			INC (lastUIN);
			u.uin := lastUIN;
			u.password := Code (password^);
			COPY (shortName^, u.shortName);
			COPY (fullName^, u.fullName);
			COPY (eMail^, u.eMail);
			list.Add (u);
			RETURN u;
		END Add;

		PROCEDURE Find* (uin: SIGNED32): User;
		VAR
			i: SIGNED32;
			u: User;
			ptr: ANY;
		BEGIN
			i := 0;
			WHILE i < list.GetCount () DO
				ptr := list.GetItem (i);
				u := ptr (User);
				IF uin = u.uin THEN
					RETURN u;
				END;
				INC (i);
			END;
			RETURN NIL;
		END Find;

		PROCEDURE PasswordCorrect* (uin: SIGNED32; password: String): BOOLEAN;
		VAR
			u: User;
		BEGIN
			u := Find (uin);
			IF u # NIL THEN
				IF Code (password^) = u.password THEN
					RETURN TRUE;
				END;
			END;
			RETURN FALSE;
		END PasswordCorrect;

	END Users;

	Buffer* = OBJECT (Strings.Buffer)
		PROCEDURE AddInt* (n, len: SIZE);
		VAR
			i: SIZE;
			b: SIZE; res: INTEGER;
			s: ARRAY 4 OF CHAR;
		BEGIN
			ASSERT (len <= 4);
			i := 0; b := 1;
			WHILE i < len DO
				s[i] := CHR (n DIV b);
				b := b * 100H;
				INC (i);
			END;
			Add (s, 0, len, TRUE, res)
		END AddInt;
	END Buffer;

	PArray = POINTER TO ARRAY OF ANY;

	(** Lockable Object List. *)
	List* = OBJECT
	VAR
		list: PArray;
		count: SIGNED32;
		readLock: SIGNED32;

		PROCEDURE &New*;
		BEGIN
			NEW (list, 8); readLock := 0
		END New;

		(** return the number of objects in the list. If count is used for indexing elements (e.g. FOR - Loop)
			in a multi-process situation, the process calling the GetCount method should call Lock before
			GetCount and Unlock after the last use of an index based on GetCount *)
		PROCEDURE GetCount*() : SIGNED32;
		BEGIN
			RETURN count
		END GetCount;

		PROCEDURE Grow;
		VAR
			old: PArray;
			i: SIGNED32;
		BEGIN
			old := list;
			NEW (list, LEN(list) * 2);
			FOR i := 0 TO count - 1 DO list[i] := old[i] END;
		END Grow;

		(** Add an object to the list. Add may block if number of calls to Lock is bigger than the number of calls
		to Unlock *)
		PROCEDURE Add*(x : ANY);
		BEGIN {EXCLUSIVE}
			AWAIT (readLock = 0);
			IF count = LEN (list) THEN Grow END;
			list[count] := x;
			INC (count)
		END Add;

		(** return the index of an object. In a multi-process situation, the process calling the IndexOf method
			should call Lock before IndexOf and Unlock after the last use of an index based on IndexOf.
			If the object is not found, -1 is returned *)
		PROCEDURE IndexOf * (x : ANY) : SIGNED32;
		VAR
			i: SIGNED32;
		BEGIN
			i := 0 ; WHILE i < count DO IF list[i] = x THEN RETURN i END; INC(i) END;
			RETURN -1
		END IndexOf;

		(** Remove an object from the list. Remove may block if number of calls to Lock is bigger than
		the number of calls to Unlock *)
		PROCEDURE Remove* (x : ANY);
		VAR
			i: SIGNED32;
		BEGIN {EXCLUSIVE}
			AWAIT (readLock = 0);
			i:=0; WHILE (i < count) & (list[i] # x) DO INC(i) END;
			IF i < count THEN
				WHILE (i < count - 1) DO list[i] := list[i + 1]; INC(i) END;
				DEC(count);
				list[count] := NIL
			END
		END Remove;

		(** Removes all objects from the list. Clear may block if number of calls to Lock is bigger than
		the number of calls to Unlock *)
		PROCEDURE Clear*;
		VAR
			i: SIGNED32;
		BEGIN {EXCLUSIVE}
			AWAIT(readLock = 0);
			FOR i := 0 TO count - 1 DO list[i] := NIL END;
			count := 0
		END Clear;

		(** return an object based on an index. In a multi-process situation, GetItem is only safe in a locked
		region Lock / Unlock *)
		PROCEDURE GetItem* (i: SIGNED32) : ANY;
		BEGIN
			ASSERT ((i >= 0) & (i < count), 101);
			RETURN list[i]
		END GetItem;

		(** Lock previousents modifications to the list. All calls to Lock must be followed by a call to Unlock.
		Lock can be nested*)
		PROCEDURE Lock*;
		BEGIN {EXCLUSIVE}
			INC(readLock); ASSERT(readLock > 0)
		END Lock;

		(** Unlock removes one modification lock. All calls to Unlock must be preceeded by a call to Lock. *)
		PROCEDURE Unlock*;
		BEGIN {EXCLUSIVE}
			DEC(readLock); ASSERT(readLock >= 0)
		END Unlock;
	END List;

	(*IntervalTimer* = OBJECT (WMComponents.Component)
	VAR
		running, terminated: BOOLEAN;
		interval: SIGNED32;
		t: Kernel.Timer;
		onTimer- : WMEvents.EventSource;

		PROCEDURE &Init;
		BEGIN
			Init^;
			NEW (t);
			interval := 500;

			(* event *)
			NEW (onTimer, SELF, GSonTimer, GSonTimerInfo, SELF.StringToCompCommand);
			events.Add (onTimer);

			BEGIN {EXCLUSIVE}
				running := TRUE
			END;
		END Init;

		PROCEDURE SetInterval* (i: SIGNED32);
		BEGIN
			BEGIN {EXCLUSIVE}
				interval := i
			END;
		END SetInterval;

		PROCEDURE Finalize*;
		BEGIN
			Finalize^;
			running := FALSE;
			t.Wakeup;
			BEGIN {EXCLUSIVE}
				AWAIT (terminated)
			END;
		END Finalize;

	BEGIN {ACTIVE}
		BEGIN {EXCLUSIVE}
			AWAIT (running)
		END;
		terminated := FALSE;
		WHILE running DO
			onTimer.Call (NIL);
			t.Sleep (interval);
		END;
		BEGIN {EXCLUSIVE}
			terminated := TRUE
		END;
	END IntervalTimer;*)

(*VAR
	GSonTimer, GSonTimerInfo: String;*)

	(*PROCEDURE Init;
	BEGIN
		GSonTimer := Strings.NewString("onTimer");
		GSonTimerInfo := Strings.NewString("Is called when timer ticks");
	END Init;*)

PROCEDURE Code (s: ARRAY OF CHAR): SIGNED32;
VAR
	i: SIGNED16; a, b, c: SIGNED32;
BEGIN
	a := 0; b := 0; i := 0;
	WHILE s[i] # 0X DO
		c := b; b := a; a := (c MOD 509 + 1) * 127 + ORD(s[i]);
		INC(i)
	END;
	IF b >= 32768 THEN b := b - 65536 END;
	RETURN b * 65536 + a
END Code;

PROCEDURE ServerPacketInit* (command, seqnum: SIGNED16; buf: Buffer);
BEGIN
	buf.Clear;
	buf.AddInt (VERSION, 2);
	buf.AddInt (command, 2);
	buf.AddInt (seqnum, 2);
END ServerPacketInit;

PROCEDURE ClientPacketInit* (command, seqnum: SIGNED16; uin: SIGNED32; buf: Buffer);
BEGIN
	ServerPacketInit (command, seqnum, buf);
	buf.AddInt (uin, 4);
END ClientPacketInit;

PROCEDURE BufGetSInt* (buf: String; VAR receiveBufOffset: SIGNED32): SIGNED16;
VAR
	n: SIGNED16;
BEGIN
	n := ORD (buf^[receiveBufOffset]);
	INC (receiveBufOffset);
	RETURN n;
END BufGetSInt;

PROCEDURE BufGetInt* (buf: String; VAR receiveBufOffset: SIGNED32): SIGNED16;
VAR
	b, n, i: SIGNED16;
BEGIN
	i := 0; b := 1; n := 0;
	WHILE i < 2 DO
		INC (n, ORD (buf^[receiveBufOffset + i]) * b);
		b := b * 100H;
		INC (i);
	END;
	INC (receiveBufOffset, 2);
	RETURN n;
END BufGetInt;

PROCEDURE BufGetLInt* (buf: String; VAR receiveBufOffset: SIGNED32): SIGNED32;
VAR
	i: SIGNED16;
	b, n: SIGNED32;
BEGIN
	i := 0; b := 1; n := 0;
	WHILE i < 4 DO
		INC (n, ORD (buf^[receiveBufOffset + i]) * b);
		b := b * 100H;
		INC (i);
	END;
	INC (receiveBufOffset, 4);
	RETURN n;
END BufGetLInt;

PROCEDURE BufGetString* (buf: String; VAR receiveBufOffset: SIGNED32): String;
VAR
	len: SIGNED32;
	string: String;
BEGIN
	len := BufGetInt (buf, receiveBufOffset);
	NEW (string, len);
	Strings.Copy (buf^, receiveBufOffset, len, string^);
	INC (receiveBufOffset, len);
	RETURN string;
END BufGetString;

PROCEDURE isNextSeqNum* (current, previous: SIGNED16): BOOLEAN;
BEGIN
	IF (previous < current) OR ((previous > current) & (previous > 0) & (current < 0))  THEN
		RETURN TRUE;
	ELSE
		RETURN FALSE;
	END;
END isNextSeqNum;

PROCEDURE SeqNumInACKList* (reqList: List; seqNum: SIGNED16;
	VAR req: ACKRec): BOOLEAN;
VAR
	i: SIGNED32;
	ptr: ANY;
BEGIN
	i := 0;
	WHILE i < reqList.GetCount () DO
		ptr := reqList.GetItem (i);
		req := ptr (ACKRec);
		IF seqNum = req.seqNum THEN
			RETURN TRUE;
		END;
		INC (i);
	END;
	RETURN FALSE;
END SeqNumInACKList;

PROCEDURE CommandDecode* (command: SIGNED16; VAR str: ARRAY OF CHAR);
BEGIN

	CASE command OF
	| ACK: str := "ACK";

	| SEND_MESSAGE: str := "SEND_MESSAGE";
	| LOGIN: str := "LOGIN";
	| KEEP_ALIVE: str := "KEEP_ALIVE";
	| SEND_TEXT_CODE: str := "SEND_TEXT_CODE";
	| INFO_REQ: str := "INFO_REQ";
	| NEW_USER_REG: str := "NEW_USER_REG";

	| LOGIN_REPLY: str := "LOGIN_REPLY";
	| USER_ONLINE: str := "USER_ONLINE";
	| USER_OFFLINE: str := "USER_OFFLINE";
	| RECEIVE_MESSAGE: str := "RECEIVE_MESSAGE";
	| INFO_REPLY: str := "INFO_REPLY";
	| NEW_USER_REPLY: str := "NEW_USER_REPLY";
	ELSE
		str := "Unknown";
	END;

END CommandDecode;

(* BEGIN *)
	(*Init;*)

END UDPChatBase.
