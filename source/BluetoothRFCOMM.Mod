MODULE BluetoothRFCOMM;

IMPORT

	S := SYSTEM,
	BluetoothL2CAP,
	Bluetooth,
	Streams,
	KernelLog;

CONST

	ModuleName = "[BTRFCOMM]";
	TraceBuffer = FALSE;
	TraceChannel = FALSE;
	TraceControlChannel = TRUE;
	TraceRFCOMM = FALSE;

	(* Frame Types *)
	SABMFRAME 	= 	02FH;
	UAFRAME		= 	063H;
	DMFRAME		= 	00FH;
	DISCFRAME		= 	043H;
	UIHFRAME		= 	0EFH;

	(* DLC  states *)
	DISCONNECTED		= 	0;
	CONNECTING		=	1;
	NEGOTIATING		=	2;
	CONNECTED		=	3;
	DISCONNECTING	=	4;

	MAXBUFSIZE		=	1024;

TYPE

	Buffer = OBJECT

		VAR
			maxBufSize : LONGINT;
			fifoBuffer : POINTER TO ARRAY OF CHAR;
			head, tail : LONGINT;
			dead : BOOLEAN;

		PROCEDURE &Init*(maxBufSize : LONGINT);
		BEGIN
			SELF.maxBufSize := maxBufSize;
			NEW(fifoBuffer,maxBufSize);
			head := 0; tail := 0;
			dead := FALSE;
		END Init;

		PROCEDURE Close;
		BEGIN {EXCLUSIVE}
			dead := TRUE;
		END Close;

		PROCEDURE Get(VAR ch : CHAR; VAR result : WORD);
		BEGIN {EXCLUSIVE}
			IF TraceBuffer THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Buffer.Get: Await ... head = "); KernelLog.Int(head,0);
				KernelLog.String(" tail = "); KernelLog.Int(tail,0);
				KernelLog.Ln;
			END;
			AWAIT((tail # head) OR dead);
			IF(tail#head) THEN
				ch := fifoBuffer[head];
				head := (head +1) MOD maxBufSize ;
				result := 0;
			ELSE (* dead *)
				KernelLog.String(ModuleName);
				KernelLog.String("Buffer.Get: error.");
				KernelLog.Ln;
				result := -1;
			END;
			IF TraceBuffer THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Buffer.Get: done. result = "); KernelLog.Hex(result,-2);
				KernelLog.Ln;
			END;
		END Get;

		PROCEDURE Put(ch : CHAR; VAR result : LONGINT);
		BEGIN {EXCLUSIVE}
			IF((tail+1) MOD MAXBUFSIZE # head) THEN
				fifoBuffer[tail] := ch;
				tail := (tail +1) MOD maxBufSize ;
				result := 0;
			ELSE (* overflow *)
				KernelLog.String(ModuleName);
				KernelLog.String("Buffer.Get: overflow.");
				result := -1;
			END;
		END Put;

		PROCEDURE IsFull() : BOOLEAN;
		BEGIN {EXCLUSIVE}
			IF((tail+1) MOD maxBufSize # head) THEN
				RETURN FALSE;
			ELSE
				RETURN TRUE;
			END;
		END IsFull;

		PROCEDURE IsEmpty() : BOOLEAN;
		BEGIN {EXCLUSIVE}
			IF(tail # head) THEN
				RETURN FALSE;
			ELSE
				RETURN TRUE;
			END;
		END IsEmpty;

		PROCEDURE Dump;
		VAR
			h,t,elements : LONGINT;
		BEGIN {EXCLUSIVE}
			h := head MOD maxBufSize;
			t := tail MOD maxBufSize;
			IF h<=t THEN
				elements := t-h;
			ELSE
				elements := t-h+maxBufSize;
			END;
			KernelLog.String(ModuleName);
			KernelLog.String("Buffer.Dump:"); KernelLog.Ln;
			KernelLog.String("buffer size = "); KernelLog.Int(maxBufSize,0);
			KernelLog.String(" head pos = "); KernelLog.Int(h,0);
			KernelLog.String(" tail pos = "); KernelLog.Int(t,0);
			KernelLog.String(" #elements = "); KernelLog.Int(elements,0);
			KernelLog.Ln;
			WHILE(h < t) DO
				KernelLog.Hex(ORD(fifoBuffer[h]),-2); KernelLog.String(" ");
				h := (h+1) MOD maxBufSize;
			END;
			KernelLog.Ln;
		END Dump;

	END Buffer;

	(* ------------------------------------------------------------------------------ *)

	Channel = OBJECT

		VAR

			dlci : LONGINT;
			state : LONGINT;
			rfcomm : RFCOMM;
			receiveBuffer : Buffer;

		(* --------------------------------------------- *)

		PROCEDURE &Init*(rfcomm : RFCOMM; dlci : LONGINT);

		BEGIN

			SELF.rfcomm := rfcomm;
			SELF.dlci := dlci;
			SetState(DISCONNECTED);

			NEW(receiveBuffer,MAXBUFSIZE);

		END Init;

		(* --------------------------------------------- *)

		PROCEDURE Close;
		BEGIN

			SetState(DISCONNECTED);
			receiveBuffer.Close();

		END Close;

		(* --------------------------------------------- *)

		PROCEDURE SetState(state : LONGINT);
		BEGIN {EXCLUSIVE}

			SELF.state := state;

		END SetState;

		(* --------------------------------------------- *)

		PROCEDURE W4State(state : LONGINT) : LONGINT;
		BEGIN {EXCLUSIVE}

			AWAIT((SELF.state = state) OR (SELF.state = DISCONNECTED));

			RETURN SELF.state;

		END W4State;


		(* --------------------------------------------- *)

		PROCEDURE SendSABM;
		VAR
			frame : ARRAY 4 OF CHAR;
		BEGIN

			IF (state =  DISCONNECTED) THEN

				frame[0] := CHR(dlci*4+3);						(* address:  xxxx xx11; EA & C bit set *)
				frame[1] := CHR(BITLOR(SABMFRAME,010H)); 	(* control; SABM Frame  P bit set *)
				frame[2] := CHR(01H); 							(* length:    0000 0001; Length = 0, EA bit set *)
				frame[3] := CalculateFCS(frame,3);				(* FCS; calculate over address control and lenght *)

				rfcomm.SendFrame(frame,4);

				SetState(CONNECTING);

			END;

		END SendSABM;

		(* --------------------------------------------- *)

		PROCEDURE SendDISC;
		VAR
			frame : ARRAY 4 OF CHAR;
		BEGIN

			IF(state # DISCONNECTED) THEN

				frame[0] := CHR(dlci*4+3);						(* address:  xxxx xx11; EA & C bit set *)
				frame[1] := CHR(BITLOR(DISCFRAME,010H)); 	(* control; DISC Frame  P bit set *)
				frame[2] := CHR(01H); 							(* length:    0000 0001; Length = 0, EA bit set *)
				frame[3] := CalculateFCS(frame,3);				(* FCS; calculate over address control and lenght *)

				rfcomm.SendFrame(frame,4);

				SetState(DISCONNECTING);

			END;

		END SendDISC;

		(* --------------------------------------------- *)

		PROCEDURE SendUA;
		VAR
			frame : ARRAY 4 OF CHAR;
		BEGIN

			frame[0] := CHR(dlci*4+3);						(* address:  xxxx xx11; EA & C bit set *)
			frame[1] := CHR(BITLOR(UAFRAME,010H)); 		(* control; UA Frame  F bit set *)
			frame[2] := CHR(01H); 							(* length:    0000 0001; Length = 0, EA bit set *)
			frame[3] := CalculateFCS(frame,3);				(* FCS; calculate over address control and lenght *)

			rfcomm.SendFrame(frame,4);

		END SendUA;

		(* --------------------------------------------- *)

		PROCEDURE SendDM;
		VAR
			frame : ARRAY 4 OF CHAR;
		BEGIN

			frame[0] := CHR(dlci*4+3);						(* address:  xxxx xx11; EA & C bit set *)
			frame[1] := CHR(BITLOR(DMFRAME,010H)); 		(* control; DM Frame  F bit set *)
			frame[2] := CHR(01H); 							(* length:    0000 0001; Length = 0, EA bit set *)
			frame[3] := CalculateFCS(frame,3);				(* FCS; calculate over address control and lenght *)

			rfcomm.SendFrame(frame,4);

		END SendDM;

		(* --------------------------------------------- *)


		PROCEDURE SendUIH(info : ARRAY OF CHAR; infoLength : LONGINT);
		VAR
			frame : ARRAY 131 OF CHAR;
			i : LONGINT;
		BEGIN

			ASSERT(infoLength < 128);

			frame[0] := CHR(dlci * 4 + 3);					(* address:  xxxx xx11; EA & C/R bit set *)
			frame[1] := CHR(UIHFRAME);						(* control; UIH Frame  P bit not set *)
			frame[2] := CHR(infoLength * 2 +1);		 		(* length; EA bit set *)

			FOR i := 0 TO infoLength-1 DO					(* information *)

				frame[3+i] := info[i];

			END;

			frame[infoLength+3] := CalculateFCS(frame,2);	(* FCS; calculate over address and control *)

			rfcomm.SendFrame(frame,infoLength + 4);

		END SendUIH;

		(* --------------------------------------------- *)

		PROCEDURE ReceiveSABM;
		BEGIN

			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.ReceiveSABM: dlci = "); KernelLog.Hex(dlci,-2);
				KernelLog.Ln;
			END;

			SendDM(); (* TO DO: accept connections *)

		END ReceiveSABM;

		(* --------------------------------------------- *)

		PROCEDURE ReceiveUA;
		BEGIN

			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.ReceiveUA: dlci = "); KernelLog.Hex(dlci,-2);
				KernelLog.Ln;
			END;

			IF(state = CONNECTING) THEN

				SetState(CONNECTED);

			ELSIF(state = DISCONNECTING) THEN

				Close();

			END;

		END ReceiveUA;

		(* --------------------------------------------- *)

		PROCEDURE ReceiveDM;
		BEGIN

			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.ReceiveDM: dlci = "); KernelLog.Hex(dlci,-2);
				KernelLog.Ln;
			END;

			Close();

		END ReceiveDM;

		(* --------------------------------------------- *)

		PROCEDURE ReceiveDISC;
		BEGIN

			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.ReceiveDISC: dlci = "); KernelLog.Hex(dlci,-2);
				KernelLog.Ln;
			END;

			IF(state = DISCONNECTED) THEN

				SendDM();

			ELSE

				SendUA();

			END;

			Close();

		END ReceiveDISC;

		(* --------------------------------------------- *)

		PROCEDURE ReceiveUIH(frame : ARRAY OF CHAR; frameLength : LONGINT);

		VAR

			infoLength : LONGINT;
			result : LONGINT;
			i : LONGINT;

		BEGIN

			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.ReceiveUIH: dlci = "); KernelLog.Hex(dlci,-2);
				KernelLog.String(" infoLength = "); KernelLog.Int((ORD(frame[2]) - 1) DIV 2,0);
				KernelLog.Ln;
			END;

			IF (state = CONNECTED) THEN

				infoLength := (ORD(frame[2]) - 1) DIV 2;

				ASSERT(infoLength < 128);	(* TO DO: accept larger frames *)

				FOR i:= 0 TO infoLength-1 DO

					IF (~receiveBuffer.IsFull()) THEN

						receiveBuffer.Put(frame[3+i],result);
						ASSERT(result = 0);

					ELSE

						(* TO DO: overflow *)

						KernelLog.String(ModuleName);
						KernelLog.String("Channel.ReceiveUIH: dlci = "); KernelLog.Hex(dlci,-2);
						KernelLog.String(" buffer overflow!");
						KernelLog.Ln;

					END;


				END;

			END;

		END ReceiveUIH;

		(* --------------------------------------------- *)

		PROCEDURE CalculateFCS(data : ARRAY OF CHAR; length : LONGINT) : CHAR;
		VAR
			fcs : CHAR;
			i : LONGINT;
		BEGIN
			fcs := CHR(0FFH);
			i := 0;
			WHILE (length >  0) DO
				fcs := crcTable[ORD(BITCXOR(fcs,data[i]))];
				INC(i); DEC(length)
			END;
			RETURN CHR(0FFH - ORD(fcs));
		END CalculateFCS;

		(* --------------------------------------------- *)

		PROCEDURE Sender(CONST buf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: WORD);

		VAR
			info : ARRAY 127 OF CHAR;
			infoLength : LONGINT;
			i : LONGINT;

		BEGIN

			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.Sender: dlci = "); KernelLog.Hex(dlci,-2);
				KernelLog.Ln;
			END;

			i := 0;

			WHILE(i < len) DO

				infoLength := 0;

				WHILE((infoLength < LEN(info)) & (i < len)) DO

					info[infoLength] := buf[i+ofs];
					INC(infoLength); INC(i);

				END;

				SendUIH(info,infoLength);

			END;

		END Sender;

		(* --------------------------------------------- *)

		PROCEDURE Receiver(VAR buf: ARRAY OF CHAR; ofs, size, min: LONGINT; VAR len: LONGINT; VAR res: WORD);

		BEGIN

			IF TraceChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("Channel.Receiver: dlci = "); KernelLog.Hex(dlci,-2);
				KernelLog.Ln;
			END;

			len := 0;
			res := 0;

			WHILE((len < min) & (res = 0)) DO

				receiveBuffer.Get(buf[ofs+len],res);
				INC(len);
			END;
			WHILE((len < size) & (~receiveBuffer.IsEmpty()) & (res = 0)) DO

				receiveBuffer.Get(buf[ofs+len],res);
				INC(len);

			END;

		END Receiver;

		(* --------------------------------------------- *)

	END Channel;

	(* ------------------------------------------------------------------------------ *)

	ControlChannel = OBJECT (Channel)

		(* TO DO *)

		PROCEDURE ReceiveUIH(info : ARRAY OF CHAR; length : LONGINT);
		BEGIN

			IF TraceControlChannel THEN
				KernelLog.String(ModuleName);
				KernelLog.String("ControlChannel.ReceiveUIH: multiplexer control command received.");
				KernelLog.Ln;
			END;

		END ReceiveUIH;

	END ControlChannel;

	(* ------------------------------------------------------------------------------ *)

	(* RFCOMM API *)

	RFCOMM* = OBJECT

		VAR
			l2capLayer : BluetoothL2CAP.L2CAP;
			l2capCID : LONGINT;
			l2capConfReqReceived : BOOLEAN;
			l2capOpen : BOOLEAN;
			rfcommOpen : BOOLEAN;
			channelList : ARRAY 62 OF Channel;
			ok : BOOLEAN;

		PROCEDURE &Init*(l2capLayer : BluetoothL2CAP.L2CAP);
		VAR
			result : WORD;
			controlChannel : ControlChannel;
			i : LONGINT;
		BEGIN
			NEW(controlChannel,SELF,i);
			channelList[0] := controlChannel;
			FOR i := 1 TO 61 DO
				NEW(channelList[i],SELF,i);
			END;
			SELF.l2capLayer := l2capLayer;
			SetL2CAPOpen(FALSE);
			SetL2CAPConfReqReceived(FALSE);
			l2capLayer.EventIndication(BluetoothL2CAP.EConfigInd,L2CAPConfigIndication,result);
			ASSERT(result = 0);
			l2capLayer.EventIndication(BluetoothL2CAP.EDisconnectInd,L2CAPDisconnectIndication,result);
			ASSERT(result = 0);
			SetRFCOMMOpen(TRUE);
		END Init;

		PROCEDURE GetL2CAPLayer*() : BluetoothL2CAP.L2CAP;
		BEGIN
			RETURN l2capLayer;
		END GetL2CAPLayer;

		PROCEDURE Start*(bdAddr: Bluetooth.BDAddr; VAR result : WORD);
		VAR
			status : LONGINT;
			inMTU, outFlushTO : LONGINT;
			outFlow,linkTO : LONGINT;
			ok : BOOLEAN;
		BEGIN
			l2capLayer.Connect(BluetoothL2CAP.psmRFCOMM,bdAddr,l2capCID,result,status);
			IF (result # 0) THEN
				IF TraceRFCOMM THEN
					KernelLog.String(ModuleName);
					KernelLog.String("RFCOMM.Start: L2CAP connection failed. result = "); KernelLog.Hex(result,-2);
					KernelLog.Ln();
				END;
			ELSE
				inMTU := Bluetooth.MaxACLDataLen;
				outFlushTO := 0FFFFH;
				IF TraceRFCOMM THEN
					KernelLog.String(ModuleName);
					KernelLog.String("RFCOMM.Start: configure L2CAP channel: MTU = "); KernelLog.Int(inMTU,0);
					KernelLog.String(" Flow = "); KernelLog.Int(outFlow,0);
					KernelLog.String(" FlushTo = "); KernelLog.Int(outFlushTO,0);
					KernelLog.String(" ...");
					KernelLog.Ln;
				END;
				l2capLayer.Configure(l2capCID,inMTU,outFlow,outFlushTO,linkTO,result);
				IF (result #  0) THEN

						KernelLog.String(ModuleName);
						KernelLog.String("RFCOMM.Start: L2CAP configuration failed. result = "); KernelLog.Hex(result,-2);
						KernelLog.Ln();

				ELSE
					IF TraceRFCOMM THEN
						KernelLog.String(ModuleName);
						KernelLog.String("RFCOMM.Start: configuration done. result = "); KernelLog.Hex(result,-2);
						KernelLog.String(" MTU = "); KernelLog.Int(inMTU,0);
						KernelLog.String(" Flow = "); KernelLog.Int(outFlow,0);
						KernelLog.String(" FlushTo = "); KernelLog.Int(outFlushTO,0);
						KernelLog.Ln;
					END;
					ok := W4L2CAPConfReqReceived();
					IF(ok) THEN
						SetL2CAPOpen(TRUE);
						channelList[0].SendSABM();
					ELSE
						result := -1;
					END;
				END;
			END;
		END Start;

		PROCEDURE Close*(VAR result : LONGINT);
		VAR i : LONGINT;
		BEGIN
			IF TraceRFCOMM THEN
				KernelLog.String(ModuleName);
				KernelLog.String("RFCOMM.Close: ...");
				KernelLog.Ln;
			END;

			IF ~rfcommOpen THEN
				IF TraceRFCOMM THEN
					KernelLog.String(ModuleName);
					KernelLog.String("RFCOMM.Close: already close");
					KernelLog.Ln;
				END;
				RETURN;
			END;

			FOR i:= 0 TO 61 DO
				channelList[i].SendDISC();
				channelList[i].Close();
			END;
			result := 0;
			IF(l2capOpen) THEN
				l2capLayer.Disconnect(l2capCID,result);
				IF (result #  0) THEN
					IF TraceRFCOMM THEN
						KernelLog.String(ModuleName);
						KernelLog.String("RFCOMM.Close: l2capLayer.Disconnect failed. result = "); KernelLog.Hex(result,-2);
						KernelLog.Ln();
					END;
				END;
				SetL2CAPOpen(FALSE);
				SetL2CAPConfReqReceived(FALSE);
			END;
			l2capLayer.Close;
			SetRFCOMMOpen(FALSE);
			IF TraceRFCOMM THEN
				KernelLog.String(ModuleName);
				KernelLog.String("RFCOMM.Close: done. result =  "); KernelLog.Int(result,0);
				KernelLog.Ln;
			END;
		END Close;

		PROCEDURE EstablishChannel*(serverChannel : LONGINT; VAR result : LONGINT);
		VAR
			state : LONGINT;
		BEGIN
			channelList[serverChannel * 2].SendSABM();
			state := channelList[serverChannel * 2].W4State(CONNECTED);
			IF state = CONNECTED THEN
				result := 0;
			ELSE
				result := -1;
			END;
		END EstablishChannel;

		PROCEDURE ReleaseChannel*(serverChannel : LONGINT; VAR result : LONGINT);
		VAR
			state : LONGINT;
		BEGIN
			channelList[serverChannel*2].SendDISC();
			state := channelList[serverChannel * 2].W4State(DISCONNECTED);
			IF state = DISCONNECTED THEN
				result := 0;
			ELSE
				result := -1;
			END;
		END ReleaseChannel;

		PROCEDURE SendInformation*(serverChannel : LONGINT; info : ARRAY OF CHAR; infoLength : LONGINT);
		VAR
			result : WORD;
		BEGIN
			channelList[serverChannel * 2].Sender(info,0,infoLength,TRUE,result);
		END SendInformation;

		PROCEDURE ReceiveInformation*(serverChannel : LONGINT; VAR info : ARRAY OF CHAR; VAR infoLength : LONGINT);
		VAR
			result : WORD;
		BEGIN
			channelList[serverChannel * 2].Receiver(info,0,LEN(info),1,infoLength,result);
		END ReceiveInformation;

		PROCEDURE GetSender*(serverChannel : LONGINT) : Streams.Sender;
		BEGIN
			RETURN channelList[serverChannel * 2].Sender;
		END GetSender;

		PROCEDURE GetReceiver*(serverChannel : LONGINT) : Streams.Receiver;
		BEGIN
			RETURN channelList[serverChannel * 2].Receiver;
		END GetReceiver;

		PROCEDURE SetRFCOMMOpen(state : BOOLEAN);
		BEGIN {EXCLUSIVE}
			rfcommOpen := state;
		END SetRFCOMMOpen;

		PROCEDURE SetL2CAPConfReqReceived(state : BOOLEAN);
		BEGIN {EXCLUSIVE}
			l2capConfReqReceived := state;
		END SetL2CAPConfReqReceived;

		PROCEDURE W4L2CAPConfReqReceived() : BOOLEAN;
		BEGIN {EXCLUSIVE}
			AWAIT(l2capConfReqReceived OR ~rfcommOpen);
			IF(rfcommOpen) THEN
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END;
		END W4L2CAPConfReqReceived;

		PROCEDURE SetL2CAPOpen(state: BOOLEAN);
		BEGIN {EXCLUSIVE}
			l2capOpen := state;
		END SetL2CAPOpen;

		PROCEDURE W4L2CAPOpen() : BOOLEAN;
		BEGIN {EXCLUSIVE}
			AWAIT(l2capOpen OR ~rfcommOpen);
			IF(rfcommOpen) THEN
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END;
		END W4L2CAPOpen;

		PROCEDURE L2CAPConnectIndication(indication: BluetoothL2CAP.Indication);
		BEGIN
			KernelLog.String(ModuleName);
			KernelLog.String("RFCOMM.L2CAPConnectIndication: ignore!");
			KernelLog.Ln;
		END L2CAPConnectIndication;

		PROCEDURE L2CAPDisconnectIndication(indication: BluetoothL2CAP.Indication);
		VAR
			result : LONGINT;
		BEGIN
			KernelLog.String(ModuleName);
			KernelLog.String("RFCOMM.L2CAPDisconnectIndication:  shutdown RFCOMM");
			KernelLog.Ln;
			Close(result);
		END L2CAPDisconnectIndication;

		PROCEDURE L2CAPConfigIndication(inParam : BluetoothL2CAP.Indication);
		VAR
			result : WORD;
		BEGIN
			WITH inParam : BluetoothL2CAP.ConfigInd DO
				IF TraceRFCOMM THEN
					KernelLog.String(ModuleName);
					KernelLog.String("RFCOMM.L2CAPConfigIndication: ..."); KernelLog.Ln;
					KernelLog.String("cid = "); KernelLog.Int(inParam.c.sid,0);
					KernelLog.String(" ident = "); KernelLog.Int(ORD(inParam.ident),0);
					KernelLog.String(" MTU = "); KernelLog.Int(inParam.outMTU,0);
					KernelLog.String(" FlushTO = "); KernelLog.Int(inParam.inFlushTO,0);
					KernelLog.Ln;
				END;
				l2capLayer.ConfigurationResponse(inParam.c.sid,inParam.ident,inParam.outMTU,
													inParam.inFlushTO,result);
			END;
			SetL2CAPConfReqReceived(TRUE);
		END L2CAPConfigIndication;

		PROCEDURE SendFrame(frame : ARRAY OF CHAR;length : LONGINT);
		VAR
			size : LONGINT;
			result : WORD;
			i : LONGINT;
		BEGIN
			IF TraceRFCOMM THEN
				KernelLog.String(ModuleName);
				KernelLog.String("RFCOMM.SendFrame: data size = "); KernelLog.Int(length,0);
				KernelLog.Ln;
				FOR i := 0 TO length-1 DO
					 KernelLog.Hex(ORD(frame[i]), -2); KernelLog.String(" " );
				END;
				KernelLog.Ln;
			END;
			IF(l2capOpen = TRUE) THEN
				l2capLayer.Write(l2capCID,0,length,frame,size,result);
			END;
			IF (result # 0) THEN
				KernelLog.String(ModuleName);
				KernelLog.String("RFCOMM.SendFrame: l2cap.Write failed. result =  "); KernelLog.Int(result,0);
				KernelLog.Ln;
			END;
		END SendFrame;

		PROCEDURE ReceiveFrame;
		VAR
			buffer : ARRAY 512 OF CHAR;
			i : LONGINT;
			result,size : LONGINT;
			frameType : LONGINT;
			dlci : LONGINT;
		BEGIN
			REPEAT
				l2capLayer.Read(l2capCID,LEN(buffer),buffer,result,size);
				IF (result = 0) THEN
					IF TraceRFCOMM THEN
						KernelLog.String(ModuleName);
						KernelLog.String("RFCOMM.ReceiveFrame: data size = "); KernelLog.Int(size,0);
						KernelLog.Ln;
						FOR i := 0 TO size-1 DO
							 KernelLog.Hex(ORD(buffer[i]), -2); KernelLog.String(" " );
						END;
						KernelLog.Ln;
					END;
					dlci := ORD(buffer[0]) DIV 4;
					frameType := BITLAND(ORD(buffer[1]),0EFH);
					IF (frameType =	SABMFRAME) THEN
						channelList[dlci].ReceiveSABM();
					ELSIF(frameType = UAFRAME) THEN
						channelList[dlci].ReceiveUA();
					ELSIF(frameType = DMFRAME) THEN
						channelList[dlci].ReceiveDM();
					ELSIF(frameType = DISCFRAME) THEN
						channelList[dlci].ReceiveDISC();
					ELSIF(frameType = UIHFRAME) THEN
						channelList[dlci].ReceiveUIH(buffer,size);
					ELSE
						KernelLog.String("unknown frame! "); KernelLog.Hex(frameType,-2);
						KernelLog.String(" DLCI = "); KernelLog.Hex(dlci,-2);
						KernelLog.Ln;
					END;
				ELSE
					KernelLog.String(ModuleName);
					KernelLog.String("RFCOMM.ReceiveFrame: l2cap.Read failed. result =  "); KernelLog.Int(result,0);
					KernelLog.Ln;
				END;
			UNTIL (result # 0);
		END ReceiveFrame;

	BEGIN {ACTIVE}
		IF TraceRFCOMM THEN
			KernelLog.String(ModuleName);
			KernelLog.String("RFCOMM: {ACTIVE}  ...");
			KernelLog.Ln;
		END;
		ok := W4L2CAPOpen();
		IF(ok) THEN
			ReceiveFrame();
		END;
		IF TraceRFCOMM THEN
			KernelLog.String(ModuleName);
			KernelLog.String("RFCOMM: {ACTIVE} done.");
			KernelLog.Ln;
		END;
	END RFCOMM;

(* ------------------------------------------------------------------------ *)

VAR

	crcTable: ARRAY 256 OF CHAR;

(* ------------------------------------------------------------------------ *)

PROCEDURE CreateCRCTable;
VAR
	i,j : LONGINT;
	pol,data,sr : CHAR;
	op1,op2,op3 : CHAR;
BEGIN
	pol := CHR(224);
	FOR j := 0 TO 255 DO
		sr := CHR(0);
		data :=  CHR(j);
		FOR i := 0 TO 7 DO
			op1 := BITCAND(data,CHR(1));
			op2 := BITCAND(sr,CHR(1));
			op3 := BITCXOR(op1,op2);
			sr := CHR(ORD(sr) DIV 2);
			IF (op3 #CHR( 0)) THEN
				sr := BITCXOR(sr,pol);
			END;
			data := CHR(ORD(data) DIV 2);
			sr := BITCAND(sr,CHR(255));
		END;
		crcTable[j] := sr;
	END;
END CreateCRCTable;

(* ------------------------------------------------------------------------ *)
	PROCEDURE BITLOR(x, y: LONGINT): LONGINT;
	BEGIN RETURN S.VAL(LONGINT, S.VAL(SET, x) + S.VAL(SET, y))
	END BITLOR;

	PROCEDURE BITCAND(x, y: CHAR): CHAR;
	BEGIN RETURN CHR(S.VAL(LONGINT, S.VAL(SET, LONG(ORD(x))) * S.VAL(SET, LONG(ORD(y)))))
	END BITCAND;
	PROCEDURE BITCXOR(x, y: CHAR): CHAR;
	BEGIN RETURN CHR(S.VAL(LONGINT, S.VAL(SET, LONG(ORD(x))) / S.VAL(SET, LONG(ORD(y)))))
	END BITCXOR;
	PROCEDURE BITLAND(x, y: LONGINT): LONGINT;
	BEGIN RETURN S.VAL(LONGINT, S.VAL(SET, x) * S.VAL(SET, y))
	END BITLAND;

BEGIN
	CreateCRCTable();
END BluetoothRFCOMM.
