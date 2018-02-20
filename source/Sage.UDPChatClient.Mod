MODULE UDPChatClient; (** AUTHOR "SAGE"; PURPOSE "UDP Chat Client" *)

IMPORT
	Base := UDPChatBase, UDP, IP, DNS,
	Dates, Strings,
	WMStandardComponents, WMComponents, WM := WMWindowManager,
	WMDialogs, WMEditors, WMRectangles,
	Modules, Texts, UTF8Strings, Inputs, Kernel, Events;

CONST
	serverStr = "127.0.0.1";

	branchInit					= 0;
	branchPacketReceive	= 1;
	branchVersionCheck	= 2;
	branchPacketHandle	= 3;
	branchEnd					= 4;
	branchTerminated		= 5;

	moduleName = "UDPChatClient";

	(* Event classification as in Events.XML *)
	EventClass = 3; (* UDP Chat *)
	EventSubclass = 3; (* UDP Chat Client *)

	(* Window size at application startup *)
	WindowWidth = 40 * 12;
	WindowHeight = 30 * 12;

TYPE

	msg = ARRAY 1500 OF CHAR; (* Maximum allowed message length caused by Network MTU limit *)

	String = Strings.String;

	Instance = OBJECT
	VAR
		next: Instance;

		chat: ChatWindow;
		server: ARRAY 256 OF CHAR;
		CRLF: ARRAY 3 OF CHAR;

		login: ARRAY 9 OF CHAR;
		password, passwordConfirm: ARRAY 33 OF CHAR;
		shortName, fullName, eMail: ARRAY 65 OF CHAR;

		uin, res: LONGINT;
		dt: Dates.DateTime;

		keepAliveTimer: Kernel.MilliTimer;

		s: UDP.Socket;
		serverIP, ip: IP.Adr;
		running, terminated, onLine: BOOLEAN;

		str1, str2: ARRAY 256 OF CHAR;

		branch, command, seqNum, messageType, inSeqNum, outSeqNum: INTEGER;
		senderUin, receiverUin, port, len, receiveBufOffset: LONGINT;
		sendBuf-: Base.Buffer;

		receiveBuf, message, string: String;

		userInfos: Base.List;
		userInfo: Base.UserInfo;

		ACKReqList: Base.List;
		ACKReq: Base.ACKRec;

		csa: Texts.CharacterStyleArray;
		psa: Texts.ParagraphStyleArray;

	PROCEDURE &New*;
	BEGIN

		(* Chain the previous instance(s) to this new one, for guaranteed cleanup. *)
		next := instances;
		instances := SELF
	END New;

	PROCEDURE Finalize;
	BEGIN

		IF chat # NIL THEN chat.Close END;

		running := FALSE;

		BEGIN {EXCLUSIVE}
			AWAIT (terminated)
		END;

		FreeInstance (SELF);

	END Finalize;

	PROCEDURE Client_ACK (seqNum: INTEGER; uin: LONGINT; sendBuf: Base.Buffer;
		s: UDP.Socket; ip: IP.Adr);
	VAR
		res: LONGINT;
		string: String;
	BEGIN {EXCLUSIVE}
		Base.ClientPacketInit (Base.ACK, seqNum, uin, sendBuf);
		string := sendBuf.GetString ();
		s.Send (ip, Base.serverPort, string^, 0, sendBuf.GetLength (), res);
	END Client_ACK;

	PROCEDURE Client_NewUserReg (password, shortName, fullName, eMail: ARRAY OF CHAR;
		VAR seqNum: INTEGER; sendBuf: Base.Buffer;
		s: UDP.Socket; ip: IP.Adr);
	VAR
		len, res: LONGINT;
		string: String;
	BEGIN {EXCLUSIVE}
		Base.ClientPacketInit (Base.NEW_USER_REG, seqNum, 0, sendBuf);

		NEW (ACKReq);
		ACKReq.seqNum := seqNum;
		ACKReqList.Add (ACKReq);

		INC (seqNum);

		len := Strings.Length (password) + 1;
		sendBuf.AddInt (len, 2);
		sendBuf.Add (password, 0, len, TRUE, res);

		len := Strings.Length (shortName) + 1;
		sendBuf.AddInt (len, 2);
		sendBuf.Add (shortName, 0, len, TRUE, res);

		len := Strings.Length (fullName) + 1;
		sendBuf.AddInt (len, 2);
		sendBuf.Add (fullName, 0, len, TRUE, res);

		len := Strings.Length (eMail) + 1;
		sendBuf.AddInt (len, 2);
		sendBuf.Add (eMail, 0, len, TRUE, res);

		string := sendBuf.GetString ();
		s.Send (ip, Base.serverPort, string^, 0, sendBuf.GetLength (), res);
	END Client_NewUserReg;

	PROCEDURE Client_Login (password: ARRAY OF CHAR;
		VAR seqNum: INTEGER; uin: LONGINT; sendBuf: Base.Buffer;
		s: UDP.Socket; ip: IP.Adr);
	VAR
		len, res: LONGINT;
		string: String;
	BEGIN {EXCLUSIVE}
		Base.ClientPacketInit (Base.LOGIN, seqNum, uin, sendBuf);

		NEW (ACKReq);
		ACKReq.seqNum := seqNum;
		ACKReqList.Add (ACKReq);

		INC (seqNum);

		len := Strings.Length (password) + 1;
		sendBuf.AddInt (len, 2);
		sendBuf.Add (password, 0, len, TRUE, res);

		string := sendBuf.GetString ();
		s.Send (ip, Base.serverPort, string^, 0, sendBuf.GetLength (), res);
	END Client_Login;

	PROCEDURE Client_InfoReq (userUIN: LONGINT; VAR seqNum: INTEGER;
		uin: LONGINT; sendBuf: Base.Buffer;
		s: UDP.Socket; ip: IP.Adr);
	VAR
		res: LONGINT;
		string: String;
	BEGIN {EXCLUSIVE}
		Base.ClientPacketInit (Base.INFO_REQ, seqNum, uin, sendBuf);

		NEW (ACKReq);
		ACKReq.seqNum := seqNum;
		ACKReqList.Add (ACKReq);

		INC (seqNum);

		sendBuf.AddInt (userUIN, 4);

		string := sendBuf.GetString ();
		s.Send (ip, Base.serverPort, string^, 0, sendBuf.GetLength (), res);
	END Client_InfoReq;

	PROCEDURE Client_SendMessage (
		userUIN: LONGINT; messageType: INTEGER; message: String;
		VAR seqNum: INTEGER; uin: LONGINT; sendBuf: Base.Buffer;
		s: UDP.Socket; ip: IP.Adr);
	VAR
		string: String;
		len, res: LONGINT;
	BEGIN {EXCLUSIVE}
		Base.ClientPacketInit (Base.SEND_MESSAGE, seqNum, uin, sendBuf);

		NEW (ACKReq);
		ACKReq.seqNum := seqNum;
		ACKReqList.Add (ACKReq);

		INC (seqNum);

		sendBuf.AddInt (userUIN, 4);

		sendBuf.AddInt (messageType, 2);

		(*
		len := Strings.Length (message^) + 1;
		*)
		len := LEN (message^);

		sendBuf.AddInt (len, 2);
		sendBuf.Add (message^, 0, len, TRUE, res);

		string := sendBuf.GetString ();
		s.Send (serverIP, Base.serverPort, string^, 0, sendBuf.GetLength (), res);
	END Client_SendMessage;

	PROCEDURE Client_SendTextCode (code: String;
		VAR seqNum: INTEGER; uin: LONGINT; sendBuf: Base.Buffer;
		s: UDP.Socket; ip: IP.Adr);
	VAR
		string: String;
		len, res: LONGINT;
	BEGIN {EXCLUSIVE}
		Base.ClientPacketInit (Base.SEND_TEXT_CODE, seqNum, uin, sendBuf);

		NEW (ACKReq);
		ACKReq.seqNum := seqNum;
		ACKReqList.Add (ACKReq);

		INC (seqNum);

		len := Strings.Length (code^) + 1;
		sendBuf.AddInt (len, 2);
		sendBuf.Add (code^, 0, len, TRUE, res);

		string := sendBuf.GetString ();
		s.Send (serverIP, Base.serverPort, string^, 0, sendBuf.GetLength (), res);
	END Client_SendTextCode;

	PROCEDURE Client_KeepAlive (VAR seqNum: INTEGER; uin: LONGINT; sendBuf: Base.Buffer;
		s: UDP.Socket; ip: IP.Adr);
	VAR
		res: LONGINT;
		string: String;
	BEGIN {EXCLUSIVE}
		Base.ClientPacketInit (Base.KEEP_ALIVE, seqNum, uin, sendBuf);

		NEW (ACKReq);
		ACKReq.seqNum := seqNum;
		ACKReqList.Add (ACKReq);

		INC (seqNum);

		string := sendBuf.GetString ();
		s.Send (ip, Base.serverPort, string^, 0, sendBuf.GetLength (), res);
	END Client_KeepAlive;

	PROCEDURE FindUserInfo (list: Base.List; uin: LONGINT): Base.UserInfo;
	VAR
		i: LONGINT;
		u: Base.UserInfo;
		ptr: ANY;
	BEGIN
		i := 0;
		WHILE i < list.GetCount () DO
			ptr := list.GetItem (i);
			u := ptr (Base.UserInfo);
			IF uin = u.uin THEN
				RETURN u;
			END;
			INC (i);
		END;
		RETURN NIL;
	END FindUserInfo;

	PROCEDURE Log (type, code : SHORTINT; msg: ARRAY OF CHAR; showOnKernelLog : BOOLEAN);
	VAR message : Events.Message;
	BEGIN
		COPY(msg, message);
		Events.AddEvent(moduleName, type, EventClass, EventSubclass, code, message, showOnKernelLog);
	END Log;

	BEGIN {ACTIVE}

		branch := branchInit;

		REPEAT

			CASE branch OF
			| branchInit:

				server := serverStr;
				running := FALSE;
				terminated := TRUE;
				onLine := FALSE;

				branch := branchEnd;

				csa := Texts.GetCharacterStyleArray ();
				psa := Texts.GetParagraphStyleArray ();

				res := WMDialogs.QueryString ("Server", server);

				IF res = WMDialogs.ResOk THEN

					DNS.HostByName (server, serverIP, res);

					IF res # DNS.Ok THEN

						Log (Events.Error, 0, "host name not found!", TRUE);

						serverIP := IP.StrToAdr (server);

						IF IP.IsNilAdr (serverIP) THEN

							Log (Events.Error, 0, "IP address not valid!", TRUE);

						END;

					END;

					IF ~IP.IsNilAdr (serverIP) THEN

						CRLF[0] := 0DX;
						CRLF[1] := 0AX;
						CRLF[2] := 0X;

						NEW (s, UDP.NilPort, res);

						NEW (receiveBuf, Base.MaxUDPDataLen);
						NEW (sendBuf, 0);
						NEW (ACKReqList);

						running := TRUE;
						terminated := FALSE;
						onLine := FALSE;

						inSeqNum := -1;
						outSeqNum := 1;

						res := WMDialogs.Message (WMDialogs.TQuestion, "Chat Client", "Get new User ID?",
							{WMDialogs.ResYes, WMDialogs.ResNo});

						CASE res OF
						| WMDialogs.ResYes:

							res := WMDialogs.QueryUserInfo ("Register new user",
								shortName, fullName, eMail, password, passwordConfirm);

							IF res = WMDialogs.ResOk THEN

								IF (shortName # "") &
									(password # "") &
									(password = passwordConfirm) THEN

									Client_NewUserReg (password, shortName, fullName,
										eMail, outSeqNum, sendBuf, s, serverIP);

									branch := branchPacketReceive;

								END;

							END;

						| WMDialogs.ResNo:

							res := WMDialogs.QueryLogin ("Login", login, password);

							IF res = WMDialogs.ResOk THEN

								Strings.StrToInt (login, uin);

								IF uin # 0 THEN

									NEW (chat, SELF);
									Client_Login (password, outSeqNum, uin,
										sendBuf, s, serverIP);

									branch := branchPacketReceive;

								END;

							END;

						ELSE

						END;

					END;

				END;

			| branchPacketReceive:

				IF running THEN

					s.Receive (receiveBuf^, 0, Base.MaxUDPDataLen, 1, ip, port, len, res);

					IF (res = UDP.Ok) & (len > 0) THEN

						receiveBufOffset := 0;

						branch := branchVersionCheck;

					ELSE

						branch := branchPacketReceive;

					END;

					IF onLine THEN
						IF Kernel.Expired (keepAliveTimer) THEN
							Client_KeepAlive (outSeqNum, uin, sendBuf, s, serverIP);
							Kernel.SetTimer (keepAliveTimer, Base.clientKeepAliveInterval);
						END;
					END;

				ELSE

					branch := branchEnd;

				END;

			| branchVersionCheck:

				IF Base.BufGetInt (receiveBuf, receiveBufOffset) = Base.VERSION THEN

					branch := branchPacketHandle;

				ELSE

					branch := branchPacketReceive;

				END;

			| branchPacketHandle:

				command := Base.BufGetInt (receiveBuf, receiveBufOffset);
				seqNum := Base.BufGetInt (receiveBuf, receiveBufOffset);

				Strings.IntToStr (seqNum, str1);
				Strings.Concat (" SeqNum: ", str1, str1);
				Strings.Concat (str1, " Command: ", str1);

				Strings.IntToStr (uin, str2);
				Strings.Concat ("User ID: ", str2, str2);
				Strings.Concat (str2, str1, str1);

				Base.CommandDecode (command, str2);
				Strings.Concat (str1, str2, str1);

				Log (Events.Information, 0, str1, FALSE);

				IF onLine THEN

					CASE command OF
					| Base.ACK:

						IF Base.SeqNumInACKList (ACKReqList, seqNum, ACKReq) THEN

							ACKReqList.Remove (ACKReq);

						END;

					| Base.INFO_REPLY:

						IF Base.SeqNumInACKList (ACKReqList, seqNum, ACKReq) THEN

							ACKReqList.Remove (ACKReq);

							receiverUin := Base.BufGetLInt (receiveBuf, receiveBufOffset);

							userInfo := FindUserInfo (userInfos, receiverUin);
							IF userInfo = NIL THEN
								NEW (userInfo);
								userInfos.Add (userInfo);
								userInfo.uin := receiverUin;
							END;

							string := Base.BufGetString (receiveBuf, receiveBufOffset);
							COPY (string^, userInfo.shortName);

							Strings.IntToStr (receiverUin, str1);
							Strings.Concat ("User with User ID: #", str1, str1);
							Strings.Concat (str1, " now known as '", str1);
							Strings.Concat (str1, userInfo.shortName, str1);
							Strings.Concat (str1, "'", str1);
							Strings.Concat (CRLF, str1, str1);

							chat.Append (Strings.NewString (str1), csa[8], psa[1]);

						END;

					ELSE (* CASE *)

						IF Base.isNextSeqNum (seqNum, inSeqNum) THEN

							inSeqNum := seqNum;

							Client_ACK (inSeqNum, uin, sendBuf, s, serverIP);

							CASE command OF
							| Base.USER_ONLINE:

								receiverUin := Base.BufGetLInt (receiveBuf, receiveBufOffset);

								Strings.IntToStr (receiverUin, str1);
								Strings.Concat ("User with User ID: #", str1, str1);

								userInfo := FindUserInfo (userInfos, receiverUin);
								IF userInfo = NIL THEN
									Client_InfoReq (receiverUin, outSeqNum, uin, sendBuf, s, serverIP);
								ELSE
									Strings.Concat (str1, " known as '", str1);
									Strings.Concat (str1, userInfo.shortName, str1);
									Strings.Concat (str1, "'", str1);
								END;

								Strings.Concat (str1, " is ON-LINE!", str1);
								Strings.Concat (CRLF, str1, str1);

								chat.Append (Strings.NewString (str1), csa[8], psa[1]);

							| Base.USER_OFFLINE:

								receiverUin := Base.BufGetLInt (receiveBuf, receiveBufOffset);
								Strings.IntToStr (receiverUin, str1);
								Strings.Concat ("User with User ID: #", str1, str1);

								userInfo := FindUserInfo (userInfos, receiverUin);
								IF userInfo # NIL THEN
									Strings.Concat (str1, " known as '", str1);
									Strings.Concat (str1, userInfo.shortName, str1);
									Strings.Concat (str1, "'", str1);
								END;

								Strings.Concat (str1, " is OFF-LINE!", str1);
								Strings.Concat (CRLF, str1, str1);

								chat.Append (Strings.NewString (str1), csa[8], psa[1]);

							| Base.RECEIVE_MESSAGE:

								senderUin := Base.BufGetLInt (receiveBuf, receiveBufOffset);

								dt.year := Base.BufGetInt (receiveBuf, receiveBufOffset);
								dt.month := Base.BufGetSInt (receiveBuf, receiveBufOffset);
								dt.day := Base.BufGetSInt (receiveBuf, receiveBufOffset);
								dt.hour := Base.BufGetSInt (receiveBuf, receiveBufOffset);
								dt.minute := Base.BufGetSInt (receiveBuf, receiveBufOffset);
								dt.second := 0;

								messageType := Base.BufGetInt (receiveBuf, receiveBufOffset);

								message := Base.BufGetString (receiveBuf, receiveBufOffset);

								CASE messageType OF
								| Base.MESSAGE_TYPE_NORMAL:

									userInfo := FindUserInfo (userInfos, senderUin);
									IF userInfo = NIL THEN
										Strings.IntToStr (senderUin, str1);
										Strings.Concat ("#", str1, str1);
									ELSE
										COPY (userInfo.shortName, str1);
									END;

									Strings.Concat (CRLF, str1, str1);
									chat.Append (Strings.NewString (str1), csa[1], psa[0]);

									Strings.FormatDateTime ("yyyy.mm.dd hh:nn:ss", dt, str1);
									Strings.Concat (" (", str1, str1);
									Strings.Concat (str1, ")", str1);
									chat.Append (Strings.NewString (str1), csa[3], psa[0]);

									message := Strings.ConcatToNew (CRLF, message^);

									chat.Append (message, csa[0], psa[0]);

								| Base.MESSAGE_TYPE_URL:

								| Base.MESSAGE_TYPE_DATA:
									chat.Append (Strings.NewString ("data"), csa[0], psa[0]);
								ELSE

								END;

							ELSE

							END;

						END;

					END;

					branch := branchPacketReceive;

				ELSE

					IF Base.SeqNumInACKList (ACKReqList, seqNum, ACKReq) THEN

						ACKReqList.Remove (ACKReq);

						CASE command OF
						| Base.LOGIN_REPLY:

							NEW (userInfos);

							onLine := TRUE;

							Kernel.SetTimer (keepAliveTimer, Base.clientKeepAliveInterval);

							Client_InfoReq (uin, outSeqNum, uin, sendBuf, s, serverIP);

						| Base.NEW_USER_REPLY:

							uin := Base.BufGetLInt (receiveBuf, receiveBufOffset);

							Strings.IntToStr (uin, login);
							Strings.Concat ("Remember your User ID: ", login, str1);

							WMDialogs.Information ("New user registered", str1);

							res := WMDialogs.QueryLogin ("Login", login, password);
							IF res = WMDialogs.ResOk THEN
								Strings.StrToInt (login, uin);

								IF uin # 0 THEN

									NEW (chat, SELF);
									Client_Login (password, outSeqNum, uin, sendBuf, s, serverIP);

								END;

							END;

						ELSE

						END;

					END;

					branch := branchPacketReceive;

				END;

			| branchEnd:

				BEGIN {EXCLUSIVE}
					terminated := TRUE
				END;

				branch := branchTerminated;

			ELSE

			END;

		UNTIL branch = branchTerminated;

	END Instance;

	ChatWindow = OBJECT (WMComponents.FormWindow)
	VAR
		instance: Instance;
		editSend*, editChat*: WMEditors.Editor;
		buttonSend: WMStandardComponents.Button;

		PROCEDURE Close*;
		BEGIN
			Close^;
			IF instance.onLine THEN
				instance.Client_SendTextCode (Strings.NewString("USER_DISCONNECTED"),
					instance.outSeqNum, instance.uin, instance.sendBuf, instance.s, instance.serverIP);
			END;
		END Close;

		PROCEDURE KeyEvent*(ucs: LONGINT; flags: SET; keysym: LONGINT);
		BEGIN
			IF Inputs.Release IN flags THEN RETURN END;
			IF (keysym = 0FF0DH) & (flags * Inputs.Ctrl # {})  THEN (* Ctrl + Enter *)
				SendClick (SELF, NIL);
			END;
		END KeyEvent;

		PROCEDURE Append (message: String; cs: Texts.CharacterStyle; ps: Texts.ParagraphStyle);
		VAR
			len, idx: LONGINT;
			ucs32: Texts.PUCS32String;
		BEGIN

			NEW (ucs32, Strings.Length (message^) + 1);
			idx := 0;
			UTF8Strings.UTF8toUnicode (message^, ucs32^, idx);

			editChat.text.AcquireRead;
			len := editChat.text.GetLength ();
			editChat.text.ReleaseRead;

			editChat.text.AcquireWrite;
			editChat.text.InsertUCS32 (len, ucs32^);
			editChat.text.SetCharacterStyle (len, idx-1, cs);
			editChat.text.SetParagraphStyle (len+2, idx-3, ps);
			editChat.text.ReleaseWrite;

			editChat.tv.End (TRUE, FALSE);

		END Append;

		PROCEDURE SendClick (sender, data:ANY);
		VAR
			message: msg;
			string: String;
		BEGIN

			editSend.text.AcquireRead;

			(*
			NEW (string, editSend.text.GetLength () * 2 + 1); (* GetLength () returns nuber of characters, not bytes!!! *)
			editSend.GetAsString (string^); (* text that appears in string are in UTF8 encoding *)
			*)

			editSend.GetAsString (message);
			NEW (string, Strings.Length (message) + 1);
			COPY (message, string^);

			editSend.text.ReleaseRead;

			editSend.SetAsString ("");
			IF instance.onLine THEN
				instance.Client_SendMessage (
					0, Base.MESSAGE_TYPE_NORMAL, string, instance.outSeqNum, instance.uin,
					instance.sendBuf, instance.s, instance.serverIP);
			END;

		END SendClick;

		PROCEDURE CreateForm (): WMComponents.VisualComponent;
		VAR
			panel, sendPanel, buttonPanel: WMStandardComponents.Panel;
			resizerV : WMStandardComponents.Resizer;
			manager: WM.WindowManager;
			windowStyle: WM.WindowStyle;
		BEGIN
			manager := WM.GetDefaultManager ();
			windowStyle := manager.GetStyle ();

			NEW (panel);
			panel.bounds.SetExtents (WindowWidth, WindowHeight);
			panel.fillColor.Set (windowStyle.bgColor);
			panel.takesFocus.Set (FALSE);

			NEW(buttonPanel);
			buttonPanel.alignment.Set(WMComponents.AlignBottom); buttonPanel.bounds.SetHeight(20);
			buttonPanel.bearing.Set(WMRectangles.MakeRect(12, 0, 12, 12));
			panel.AddContent(buttonPanel);

			NEW (buttonSend); buttonSend.caption.SetAOC ("Send");
			buttonSend.alignment.Set(WMComponents.AlignRight);
			buttonSend.onClick.Add (SendClick);
			buttonPanel.AddContent (buttonSend);

			NEW(sendPanel);
			sendPanel.alignment.Set(WMComponents.AlignBottom); sendPanel.bounds.SetHeight(5 * 12 + 20);
			sendPanel.fillColor.Set(windowStyle.bgColor);
			panel.AddContent(sendPanel);

			NEW(resizerV);
			resizerV.alignment.Set(WMComponents.AlignTop);
			resizerV.bounds.SetHeight(4);
			sendPanel.AddContent(resizerV);

			NEW (editSend);
			editSend.tv.defaultTextColor.Set (windowStyle.fgColor);
			editSend.tv.defaultTextBgColor.Set (windowStyle.bgColor);
			editSend.bearing.Set(WMRectangles.MakeRect(12, 12, 12, 12));
			editSend.alignment.Set(WMComponents.AlignClient);
			editSend.multiLine.Set (TRUE); editSend.tv.borders.Set (WMRectangles.MakeRect(5, 2, 3, 2));
			editSend.tv.showBorder.Set (TRUE);
			sendPanel.AddContent (editSend);

			NEW (editChat);
			editChat.tv.defaultTextColor.Set (windowStyle.fgColor);
			editChat.tv.defaultTextBgColor.Set (windowStyle.bgColor);
			editChat.bearing.Set(WMRectangles.MakeRect(12, 12, 12,12));
			editChat.alignment.Set(WMComponents.AlignClient);
			editChat.readOnly.Set (TRUE);
			editChat.multiLine.Set (TRUE); editChat.tv.borders.Set (WMRectangles.MakeRect (5, 2, 3, 2));
			editChat.tv.showBorder.Set (TRUE);
			panel.AddContent(editChat);

			RETURN panel
		END CreateForm;

		PROCEDURE &New *(inst: Instance);
		VAR
			vc: WMComponents.VisualComponent;
			vp: WM.ViewPort;
			i, j: LONGINT;
			str: ARRAY 128 OF CHAR;
		BEGIN

			instance := inst;

			vc := CreateForm ();
			i := vc.bounds.GetWidth ();
			j := vc.bounds.GetHeight ();
			Init (i, j, FALSE);
			SetContent (vc);

			vp := WM.GetDefaultView ();

			WM.AddWindow (SELF,
				(ENTIER (vp.range.r - vp.range.l) - i) DIV 2,
				(ENTIER (vp.range.b - vp.range.t) - j) DIV 2);

			COPY ("Chat - ", str);
			Strings.Append (str, instance.login);
			SetTitle (WM.NewString (str));

		END New;

	END ChatWindow;

VAR
	instances: Instance;

(* Remove the instance from the linked list *)
PROCEDURE FreeInstance (free: Instance);
VAR
	instance: Instance;
BEGIN
	IF free = instances THEN		(* the element to free is the first in list *)
		instances := instances.next
	ELSE
		instance := instances;
		WHILE (instance # NIL) & (instance.next # free) DO
			instance := instance.next
		END;
		IF instance # NIL THEN			(* not yet at the end of the chain: unchain it*)
			instance.next := free.next
		END
	END
END FreeInstance;

PROCEDURE Open*;
VAR
	instance: Instance;
BEGIN
	NEW (instance);
END Open;

PROCEDURE Cleanup;
BEGIN
	WHILE instances # NIL DO
		instances.Finalize ();
	END
END Cleanup;

BEGIN
	Modules.InstallTermHandler (Cleanup);
END UDPChatClient.

SystemTools.Free UDPChatClient ~	UDPChatClient.Open ~