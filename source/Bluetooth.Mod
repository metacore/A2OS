MODULE Bluetooth;	(** AUTHOR "be"; PURPOSE "Core Bluetooth types/functions"; *)

IMPORT
	Objects, Streams;

(**---- general Bluetooth types ----*)

CONST
	(** Result codes. res > 0: command specific error *)
	Ok* = 0;
	ErrTimeout* = -1;
	ErrInvalidPacket* = -2;
	ErrInvalidEvent* = -3;
	ErrInvalidParameters* = -4;
	ErrSendError* = -5;

	BDAddrLen* = 6;	(** length of Bluetooth device address *)
	DeviceClassLen* = 3;	(** length of Bluetooth class of device *)

TYPE
	BDAddr* = ARRAY BDAddrLen OF CHAR;	(** Bluetooth device address *)
	DeviceClass* = ARRAY DeviceClassLen OF CHAR;	(** Bluetooth class of device *)

(**---- HCI packet queue ----*)
CONST
	(** queue types *)
	Default* = 0;	(** default queue *)
	Command* = 1;	(** command queue *)
	ACL* = 2;	(** ACL data packet queue *)
	SCO* = 3;	(** SCO data packet queue *)
	Event* = 4;	(** HCI event queue *)
	Error* = 5;	(** error queue *)
	Negotiation* = 6;	(** negotiation queue *)
	NumQueues = 7;

	MaxACLDataLen* = 256;
	MaxSCODataLen* = 256;
	MaxEventParamLen* = 256;
	MaxUnknownDataLen* = 256;
	MaxLen* = 256;

TYPE
	Packet* = POINTER TO RECORD	(** generic packet type *)
		next: Packet
	END;

	ACLPacket* = POINTER TO RECORD(Packet)	(** ACL packet, see specs chapter 4.4.3 *)
		handle*,	(** connection handle *)
		PB*, 	(** packet boundary flag *)
		BC*, 	(** broadcast flag *)
		len*: LONGINT;	(** length of data, in bytes *)
		data*: ARRAY MaxACLDataLen OF CHAR	(** data *)
	END;

	SCOPacket* = POINTER TO RECORD(Packet)	(** SCO packet, see specs chapter 4.4.3 *)
		handle*,	(** connection handle *)
		len*: LONGINT;	(** length of data, in bytes *)
		data*: ARRAY MaxSCODataLen OF CHAR	(** data *)
	END;

	EventPacket* = POINTER TO RECORD(Packet)	(** HCI event packet, see specs chapter 4.4.2 *)
		code*: CHAR;	(** event code *)
		paramLen*: LONGINT;	(** parameter length, in bytes *)
		params*: ARRAY MaxEventParamLen OF CHAR	(** parameter values *)
	END;

	UnknownPacket* = POINTER TO RECORD(Packet) (** unknown packet...should not happen ;-) *)
		len*: LONGINT;	(** length of data, in bytes *)
		data*: ARRAY MaxUnknownDataLen OF CHAR	(** data *)
	END;

	(** packet filter/notifier: the filter is called first and should return quickly. If it returns TRUE the
		correspoding notifier will be called *)
	PacketFilter* = PROCEDURE{DELEGATE} (packet: Packet): BOOLEAN;
	PacketNotify* = PROCEDURE{DELEGATE} (packet: Packet);

	Filter = POINTER TO RECORD
		filter: PacketFilter;
		notify: PacketNotify;
		next: Filter
	END;

	(** used if we need to know which timer has expired *)
	IDTimer* = OBJECT
		VAR
			t: Objects.Timer;
			handler: IDTimerHandler;

		PROCEDURE &Init*(handler: IDTimerHandler; timeout: LONGINT);
		BEGIN
			SELF.handler := handler; NEW(t);
			Objects.SetTimeout(t, TimeoutHandler, timeout)
		END Init;

		PROCEDURE Cancel*;
		BEGIN {EXCLUSIVE} Objects.CancelTimeout(t)
		END Cancel;

		PROCEDURE TimeoutHandler;
		BEGIN {EXCLUSIVE} handler(SELF)
		END TimeoutHandler;
	END IDTimer;

	IDTimerHandler* = PROCEDURE {DELEGATE} (sender: IDTimer);

	(** packet queue *)
	Queue* = OBJECT
		VAR
			head, tail: Packet;
			filters: Filter;
			dead: BOOLEAN;
			expired: IDTimer;
			getNext: Packet;
			inGetNext: LONGINT;

		PROCEDURE &Init*;
		BEGIN
			inGetNext := 0; dead := FALSE;
			NEW(filters)	(* dummy head *)
		END Init;

		(** closes a queue and aborts any pending 'Get' requests *)
		PROCEDURE Close*;
		BEGIN {EXCLUSIVE}
			dead := TRUE
		END Close;

		(** clears the queue *)
		PROCEDURE Clear*;
		BEGIN {EXCLUSIVE}
			head := NIL; tail := NIL
		END Clear;

		(** add a packet to the queue *)
		PROCEDURE Add*(packet: Packet);
		BEGIN
			IF ~CheckPacketFilters(packet) THEN	(* packet filters are priorized *)
				BEGIN {EXCLUSIVE}
					IF (tail # NIL) THEN tail.next := packet; tail := packet
					ELSE head := packet; tail := packet
					END
				END
			END
		END Add;

		PROCEDURE HandleTimeout(sender: IDTimer);
		BEGIN {EXCLUSIVE} expired := sender
		END HandleTimeout;

		(** blocks until a HCI packet is available or a timeout occurs. Packet filters are priorized over the Get request *)
		PROCEDURE Get*(VAR p: Packet; timeout: LONGINT; VAR res: WORD);
		VAR timer: IDTimer;
		BEGIN {EXCLUSIVE}
			IF (head = NIL) THEN
				NEW(timer, HandleTimeout, timeout);
				AWAIT((head # NIL) OR (expired = timer) OR dead);
				IF (expired # timer) THEN timer.Cancel END
			END;
			IF (head # NIL) THEN
				p := head; head := head.next;
				IF (head = NIL) THEN tail := NIL END;
				p.next := NIL; res := 0
			ELSE
				p := NIL; res := ErrTimeout
			END
		END Get;

		(** blocks until the next HCI packet is available or a timeout occurs. Packet filters are priorized over the
			GetNext request.
		*)
		PROCEDURE GetNextFilter(p: Packet): BOOLEAN;
		BEGIN
			RETURN TRUE
		END GetNextFilter;

		PROCEDURE GetNextHandler(p: Packet);
		BEGIN
			getNext := p
		END GetNextHandler;

		(* naaa...won't work. besser: filter rein, der alles frisst, dann wieder rausnehmen *)
		PROCEDURE GetNext*(VAR p: Packet; timeout: LONGINT; VAR res: WORD);
		VAR f: Filter; timer: IDTimer;
		BEGIN {EXCLUSIVE}
			(* lock *)
			AWAIT(inGetNext = 0); INC(inGetNext);

			getNext := NIL;

			(* plug-in greedy filter *)
			NEW(f); f.filter := GetNextFilter; f.notify := GetNextHandler;
			f.next := filters.next; filters.next := f;

			NEW(timer, HandleTimeout, timeout);
			AWAIT((getNext # NIL) OR (expired = timer) OR dead);

			(* remove greedy filter *)
			filters.next := f.next;

			IF (getNext # NIL) THEN p := getNext; res := 0
			ELSE p := NIL; res := ErrTimeout
			END;

			(* unlock *)
			DEC(inGetNext)
		END GetNext;

		(** registers a packet filter/handler. Multiple filters/handlers may be registered *)
		PROCEDURE RegisterPacketFilter*(filter: PacketFilter; notify: PacketNotify);
		VAR f: Filter;
		BEGIN {EXCLUSIVE}
			NEW(f); f.filter := filter; f.notify := notify;
			f.next := filters.next; filters.next := f
		END RegisterPacketFilter;

		(** removes a registered filter/handler. *)
		PROCEDURE UnregisterPacketFilter*(notify: PacketNotify);
		VAR p,q: Filter;
		BEGIN {EXCLUSIVE}
			q := filters.next; p := filters;
			WHILE (q # NIL) DO
				IF (q.notify = notify) THEN
					p.next := q.next
				END;
				q := q.next
			END
		END UnregisterPacketFilter;

		(* checks if a packet filter/handler wants to handle the packet *)
		PROCEDURE CheckPacketFilters(packet: Packet): BOOLEAN;
		VAR f: Filter; notify: PacketNotify; res: BOOLEAN;
		BEGIN
			res := FALSE;
			BEGIN {EXCLUSIVE}
				notify := NIL;
				f := filters.next;
				WHILE (f # NIL) DO
					IF f.filter(packet) THEN res := TRUE; notify := f.notify; f := NIL
					ELSE f := f.next
					END
				END
			END;
			IF (notify # NIL) THEN notify(packet) END;
			RETURN res
		END CheckPacketFilters;
	END Queue;

	(**---- abstract transport layer ----*)
	TransportLayer* = OBJECT
		VAR
			name-: ARRAY 32 OF CHAR;
			out*: Streams.Writer;
			in*: Streams.Reader;
			sink-: ARRAY NumQueues OF Queue;

		PROCEDURE &Init*(name: ARRAY OF CHAR; sender: Streams.Sender; receiver: Streams.Receiver);
		VAR q: Queue;
		BEGIN
			COPY(name, SELF.name);
			NEW(q); sink[Default] := q	(* install default queue *)
		END Init;

		(** close the transport layer *)
		PROCEDURE Close*;
		END Close;

		(** install a queue for certain HCI packet types *)
		PROCEDURE SetSink*(type: LONGINT; queue: Queue);
		BEGIN {EXCLUSIVE}
			sink[type] := queue
		END SetSink;

		(** get the queue for certain HCI packet types *)
		PROCEDURE GetSink*(type: LONGINT): Queue;
		BEGIN {EXCLUSIVE}
			RETURN sink[type]
		END GetSink;

		(** send a HCI packet *)
		PROCEDURE Send*(type: LONGINT; VAR data: ARRAY OF CHAR; ofs, len: LONGINT; VAR res: WORD);
		BEGIN
			HALT(301)
		END Send;

		PROCEDURE Send1H*(type: LONGINT; VAR hdr: ARRAY OF CHAR; hdrlen: LONGINT; VAR data: ARRAY OF CHAR; ofs, len: LONGINT; VAR res: WORD);
		BEGIN
			HALT(301)
		END Send1H;

		PROCEDURE Send2H*(type: LONGINT; VAR hdr1: ARRAY OF CHAR; hdr1len: LONGINT;
								VAR hdr2: ARRAY OF CHAR; hdr2len: LONGINT;
								VAR data: ARRAY OF CHAR; ofs, len: LONGINT; VAR res: WORD);
		BEGIN
			HALT(301)
		END Send2H;
	END TransportLayer;

(** transforms 'character string' into an array of char.
	string = char { " " char } 0X.
	char = hexdigit hexdigit.
	hexdigit = "0"|..|"9"|"A"|..|"F".
*)
PROCEDURE StringToParam*(string: ARRAY OF CHAR; VAR param: ARRAY OF CHAR; VAR len: LONGINT);
VAR i, h, l: LONGINT; error: BOOLEAN;

	PROCEDURE Value(c: CHAR): LONGINT;
	BEGIN
		IF ("0" <= c) & (c <= "9") THEN RETURN ORD(c)-ORD("0")
		ELSE
			c := CAP(c);
			IF ("A" <= c) & (c <= "F") THEN RETURN ORD(c)-ORD("A")+10 END
		END;
		RETURN -1
	END Value;

BEGIN
	i := 0; len := 0; error := FALSE;
	WHILE ~error & (string[i] # 0X) DO
		h := Value(string[i]); l := Value(string[i+1]);
		IF (h # -1) & (l # -1) THEN
			param[len] := CHR(h*10H+l); INC(len);
			INC(i, 2);
			IF (string[i] # 0X) THEN
				IF (string[i] = " ") THEN INC(i)
				ELSE error := TRUE; len := 0
				END
			END
		ELSE error := TRUE; len := 0
		END
	END;
	param[len] := 0X
END StringToParam;


PROCEDURE CharArrayToString*(buf: ARRAY OF CHAR; ofs, len: LONGINT; VAR string: ARRAY OF CHAR);
VAR i, pos, maxLen: LONGINT; c: CHAR;

	PROCEDURE Char(v: LONGINT): CHAR;
	BEGIN
		ASSERT((0 <= v) & (v < 10H));
		IF (v < 10) THEN RETURN CHR(ORD("0") + v)
		ELSE RETURN CHR(ORD("A") + v - 10)
		END
	END Char;

BEGIN
	i := 0; pos := 0; maxLen := LEN(string)-1-3;
	WHILE (i < len) & (pos < maxLen) DO
		c := buf[ofs+i];
		string[pos] := Char(ORD(c) DIV 10H); INC(pos);
		string[pos] := Char(ORD(c) MOD 10H); INC(pos);
		string[pos] := " "; INC(pos);
		INC(i)
	END;
	string[pos] := 0X
END CharArrayToString;


END Bluetooth.