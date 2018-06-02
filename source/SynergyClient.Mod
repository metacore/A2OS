MODULE SynergyClient; (** AUTHOR "thomas.frey@alumni.ethz.ch"; PURPOSE "Synergy Client"; *)
(* 2007.08.26
	Limitations:
		* Only supports Mouse and Keyboard for now
		* Not all key combinations are understood correctly
		* I took the protocol information from looking at the network traffic with Ethereal because i did not find a clean spec and was
			too lazy to dig through the source code at http://synergy2.sourceforge.net/ . So dont take it as "according to spec".
*)
IMPORT
	Modules, Objects, Commands, Streams, IP, TCP, DNS, KernelLog, Strings, Inputs,  WMWindowManager, WMMessages;

CONST
	DebugKeyboard = FALSE;

TYPE
	SynergyClient = OBJECT
	VAR in : Streams.Reader;
		out : Streams.Writer;
		connection : TCP.Connection;
		packet : ARRAY 2048 OF CHAR;
		errors : BOOLEAN;
		manager : WMWindowManager.WindowManager;
		originator : WMWindowManager.ViewPort;
		mouseKeys : SET;
		mouseX, mouseY : LONGINT;
		running : BOOLEAN;
		screenName : ARRAY 128 OF CHAR;

		lastKeysym, lastUcs : LONGINT;

		PROCEDURE &New*(conn : TCP.Connection; sName : ARRAY OF CHAR);
		BEGIN
			running := TRUE;
			connection := conn;
			COPY(sName, screenName);
			NEW(in, connection.Receive, 1024);
			NEW(out, connection.Send, 1024);
			manager := WMWindowManager.GetDefaultManager();
			originator := WMWindowManager.GetDefaultView(); (* make synergy events appear as coming from the default view. *)
		END New;

		PROCEDURE GetPacket16(pos : LONGINT) : LONGINT;
		VAR int16 : INTEGER;
		BEGIN
			int16 := ORD(packet[pos]) * 256 + ORD(packet[pos + 1]);
			RETURN int16
		END GetPacket16;

		PROCEDURE GetPacket32(pos : LONGINT) : LONGINT;
		VAR int32 : LONGINT;
		BEGIN
			int32 := ORD(packet[pos]) * 1000000H + ORD(packet[pos + 1]) * 10000H + ORD(packet[pos + 2]) * 100H + ORD(packet[pos + 3]);
			RETURN int32
		END GetPacket32;

		PROCEDURE SendClientHello(screenName : ARRAY OF CHAR);
		VAR strLen : LONGINT;
		BEGIN {EXCLUSIVE}
			strLen := Strings.Length(screenName);
			out.Net32(11 + 4 + strLen);
			out.String("Synergy");
			out.Net16(1);
			out.Net16(3);
			out.Net32(strLen);
			out.String(screenName);
			out.Update
		END SendClientHello;

		PROCEDURE SendDINF(left, top, width, height, wrap, pointerX, pointerY : LONGINT);
		BEGIN  {EXCLUSIVE}
			out.Net32(4 + 7 * 2);
			out.String("DINF");
			out.Net16(left); out.Net16(top); out.Net16(width); out.Net16(height);
			out.Net16(wrap);
			out.Net16(pointerX); out.Net16(pointerY);
			out.Update
		END SendDINF;

		PROCEDURE SendNOP;
		BEGIN  {EXCLUSIVE}
			out.Net32(4);
			out.String("CNOP");
			out.Update
		END SendNOP;

		PROCEDURE MouseEvent(x, y, dz: LONGINT; keys : SET);
		VAR msg : WMMessages.Message;
		BEGIN
			msg.originator := originator;
			msg.msgType := WMMessages.MsgPointer;
			msg.x := x; msg.y := y;
			msg.dz := dz;
			msg.flags := keys;
			IF manager # NIL THEN IF manager.sequencer.Add(msg) THEN END END;
		END MouseEvent;

		PROCEDURE KeyEvent(ucs: LONGINT; flags : SET; keysym : LONGINT);
		VAR msg : WMMessages.Message;
		BEGIN
			msg.originator := originator;
			msg.msgType := WMMessages.MsgKey;
			msg.x := ucs;
			msg.y := keysym;
			msg.flags := flags;
			IF manager.sequencer.Add(msg) THEN END;
		END KeyEvent;

		PROCEDURE ConvertKey(keyId, keyMask, keyButton : LONGINT; VAR ucs: LONGINT; VAR flags : SET; VAR keysym : LONGINT; down : BOOLEAN);
		BEGIN
			IF down THEN flags := {} ELSE flags := {Inputs.Release} END;
			IF keyMask MOD 2 = 1 THEN (* shift is pressed *)
				flags := flags + Inputs.Shift
			END;
			IF (keyMask DIV 2)  MOD 2 = 1 THEN (* ctrl is pressed *)
				flags := flags + Inputs.Ctrl
			END;
			IF (keyMask DIV 4)  MOD 2 = 1 THEN (* alt is pressed *)
				flags := flags + Inputs.Alt
			END;

			IF (keyMask DIV 16)  MOD 2 = 1 THEN (* meta is pressed *)
				flags := flags + Inputs.Meta
			END;

			IF keyId > 0 THEN
				ucs := keyId; keysym := keyId;
				IF Inputs.Ctrl * flags # {}  THEN
					IF (CAP(CHR(ucs)) >= "A") & (CAP(CHR(ucs)) <= "Z") THEN keysym := ORD(CAP(CHR(ucs))) - 64; ucs := 0 END
				END

			ELSE
				CASE keyButton OF
					|1 : keysym := lastKeysym; ucs := lastUcs
					|14 : keysym := 0FF08H; ucs := 07FH
					|15 : keysym := 0FF09H; ucs := 09H; (* tab *)
					|28 : keysym := 0FF0DH; ucs := 0DH;
					|42 : keysym := 0FFE1H; ucs := 0H; (* shift *)
					|29 : keysym := 0FFE3H; ucs := 0H; (* ctrl *)
					|56 : keysym := 0FFFFH; ucs := 0H; (* alt *)
					|58 : keysym := 0FFFFH; ucs := 0H; (* Scroll Lock *)
					|331: keysym := 0FF51H; ucs := 0C4H; (* cursor left *)
					|333: keysym := 0FF53H; ucs := 0C3H; (* cursor right *)
					|328: keysym := 0FF52H; ucs := 0C1H; (* cursor up *)
					|336: keysym := 0FF54H; ucs := 0C2H; (* cursor down *)
					|327: keysym := 0FF50H; ucs := 0A8H; (* cursor home *)
					|329: keysym := 0FF55H; ucs := 0A2H; (* cursor PgUp *)
					|337: keysym := 0FF56H; ucs := 0A3H; (* cursor PgDn *)
					|335: keysym := 0FF57H; ucs := 0A9H; (* cursor End *)
					|339: keysym := 0FFFFH; ucs := 0A1H; (* Delete *)
					|349: keysym := 0FF67H; ucs := 0; (* meta ? menu *)
					|347: keysym := 0FF67H; ucs := 0; (* meta ? real *)
				ELSE
					IF DebugKeyboard THEN
						KernelLog.String("keyId= "); KernelLog.Int(keyId, 0);
						KernelLog.String("keyMask= "); KernelLog.Int(keyMask, 0);
						KernelLog.String("keyButton= "); KernelLog.Int(keyButton, 0); KernelLog.Ln;
					END;
					keysym := 0H; ucs := 0H
				END
			END;
			lastKeysym := keysym; lastUcs := ucs
		END ConvertKey;

		PROCEDURE Loop;
		VAR
			packetLength, i, len : LONGINT;
			packetType : ARRAY 5 OF CHAR;

			x, dz, w, h : LONGINT;
			keyId, keyMask, keyButton : LONGINT;

			ucs, keysym : LONGINT;
			flags : SET;

		BEGIN
			KernelLog.String("Synergy Client : connected to server."); KernelLog.Ln;
			errors := FALSE;
			WHILE ~errors & (in.res = 0) DO
				packetLength := in.Net32();
				in.Bytes(packet, 0, packetLength, len);
				IF len # packetLength THEN errors := TRUE
				ELSE
					FOR i := 0 TO 3 DO packetType[i] := packet[i] END; packetType[4] := 0X;
					IF packetType = "Syne" THEN
						SendClientHello(screenName)
					ELSIF packetType = "QINF" THEN (* request for screen information ? *)
						w := ENTIER(originator.range.r - originator.range.l);
						h := ENTIER(originator.range.b - originator.range.t);
						SendDINF(0, 0, w, h, 0, 100, 100)
					ELSIF packetType = "EUNK" THEN (* probably the screen is not known on the server... add it and try again*)
						KernelLog.String("probably the screen is not known on the synergy server... add it and try again"); KernelLog.Ln;
					ELSIF packetType = "CROP" THEN (* client reset options... what options ?? *)
					ELSIF packetType = "DSOP" THEN (* set some options *)
					ELSIF packetType = "CIAK" THEN (* ack the resolution settings *)
					ELSIF packetType = "CALV" THEN (* Is  the client still alive ?  say CNOP(E) ;-) *)
						SendNOP
					ELSIF packetType = "CINN" THEN (* client enter... we got the pointer *)
						mouseX := GetPacket16(4); mouseY := GetPacket16(6);
						SendNOP
					ELSIF packetType = "COUT" THEN (* ... we lost the pointer *)
					ELSIF packetType = "DCLP" THEN (* Something with the clipboard *)
					ELSIF packetType = "DMMV" THEN (* Mouse move *)
						mouseX := GetPacket16(4); mouseY := GetPacket16(6);
						MouseEvent(mouseX, mouseY, 0, mouseKeys);
						SendNOP
					ELSIF packetType = "DMDN" THEN (* Mouse down *)
						x := ORD(packet[4]);
						IF (x >= 1) & (x <= 3) THEN INCL(mouseKeys, x - 1) END;
						MouseEvent(mouseX, mouseY, 0, mouseKeys);
						SendNOP
					ELSIF packetType = "DMUP" THEN (* Mouse up *)
						x := ORD(packet[4]);
						IF (x >= 1) & (x <= 3) THEN EXCL(mouseKeys, x - 1) END;
						MouseEvent(mouseX, mouseY, 0, mouseKeys);
						SendNOP
					ELSIF packetType = "DMWM" THEN (* Scroll wheel *)
						x := GetPacket32(4);
						IF x < 0 THEN dz := 1 ELSE dz := -1 END;
						MouseEvent(mouseX, mouseY, dz, mouseKeys);
						SendNOP
					ELSIF (packetType = "DKDN") OR (packetType = "DKRP")  THEN (* KeyDown *)
						keyId := GetPacket16(4); keyMask := GetPacket16(6); keyButton := GetPacket16(8);
						flags := {};
						ConvertKey(keyId, keyMask, keyButton, ucs, flags, keysym, TRUE);
						KeyEvent(ucs, flags, keysym);
						SendNOP
					ELSIF packetType = "DKUP" THEN (* KeyUp *)
						keyId := GetPacket16(4); keyMask := GetPacket16(6); keyButton := GetPacket16(8);
						ConvertKey(keyId, keyMask, keyButton, ucs, flags, keysym, FALSE);
						keysym := 0FFFFH; ucs := 0;
						KeyEvent(ucs, flags, keysym);
						SendNOP
					ELSE
						KernelLog.String("packetType= "); KernelLog.String(packetType); KernelLog.Ln;
					END
				END
			END;

			running := FALSE;
			KernelLog.String("Synergy client stopped"); KernelLog.Ln
		END Loop;

	BEGIN {ACTIVE}
		Loop;
	END SynergyClient;

VAR
	client : SynergyClient;

PROCEDURE Connect*(context : Commands.Context);
VAR
	serverIP : IP.Adr;
	res : WORD;
	connection : TCP.Connection;
	server, screenName : ARRAY 128 OF CHAR;
BEGIN
	(* server *)
	IF ~context.arg.GetString(server) OR ~context.arg.GetString(screenName) THEN
		context.out.String('Start with SynergyClient.Connect "ServerName" "ScreenName" ~'); context.out.Ln;
		RETURN;
	END;

	IF client = NIL THEN
		DNS.HostByName(server, serverIP, res);
		NEW(connection);
		connection.Open(TCP.NilPort, serverIP, 24800, res);
		IF res = 0 THEN
			NEW(client, connection, screenName);
			context.out.String("Connection established"); context.out.Ln;
		ELSE
			context.out.String("Could not connect to server."); context.out.Ln
		END
	ELSE
		context.out.String("Already connected."); context.out.Ln;
	END;
END Connect;

PROCEDURE Close*(context : Commands.Context);
BEGIN
	IF client # NIL THEN
		client.connection.Close();
		context.out.String("Connection closed"); context.out.Ln;
		client := NIL;
	END;
END Close;

PROCEDURE Cleanup;
VAR i : LONGINT;
BEGIN
	IF client # NIL THEN
		client.connection.Close();
		i := 0; WHILE (i < 1000) & client.running DO Objects.Yield; INC(i) END
	END
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END SynergyClient.

SystemTools.Free SynergyClient ~
SynergyClient.Connect "192.168.0.3" "Bluebottle" ~
SynergyClient.Close ~