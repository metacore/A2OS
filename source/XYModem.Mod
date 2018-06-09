MODULE XYModem; (** AUTHOR "ejz"; PURPOSE "X- and Y-Modem protocol implementation"; *)

IMPORT SYSTEM, Objects, Kernel, Streams, Files, Serials, Strings, Commands;

CONST
	SOH = 01X; STX = 02X; EOT = 04X; ACK = 06X; EOF = 1AX; NAK = 15X; CAN = 18X; C = 43X;
	XModem* = 0; XModem1K* = 1; YModem* = 2;

	DoYield = TRUE;

TYPE

	Modem* = OBJECT
	VAR
		W: Streams.Writer; R: Streams.Reader;
		F: Files.File;
		mode: LONGINT; (* XModem, XModem1K, YModem *)
		timeout: LONGINT;
		data: ARRAY 1024 OF CHAR;
		error: ARRAY 64 OF CHAR;
		done, fail: BOOLEAN;

		bytesProcessed-, totalBytes- : LONGINT;

		PROCEDURE & Init*(W: Streams.Writer; R: Streams.Reader; F: Files.File; mode: LONGINT);
		BEGIN
			SELF.W := W; SELF.R := R;
			SELF.F := F; SELF.mode := mode; error := ""; done := FALSE
		END Init;

		PROCEDURE IsDone*() : BOOLEAN;
		BEGIN
			RETURN done;
		END IsDone;

		PROCEDURE Await*(VAR err: ARRAY OF CHAR);
		BEGIN {EXCLUSIVE}
			AWAIT(done); COPY(error, err)
		END Await;

		PROCEDURE AwaitF*(VAR F: Files.File; VAR err: ARRAY OF CHAR);
		BEGIN {EXCLUSIVE}
			ASSERT(mode = YModem);
			AWAIT(done);
			F := SELF.F; COPY(error, err)
		END AwaitF;

		PROCEDURE Stop;
		BEGIN {EXCLUSIVE}
			done := TRUE
		END Stop;

		PROCEDURE Read(VAR ch: CHAR): BOOLEAN;
		VAR n: LONGINT; milliTimer : Kernel.MilliTimer;
		BEGIN
			Kernel.SetTimer(milliTimer, timeout);
			REPEAT
				n := R.Available();
				IF DoYield & (n = 0) THEN Objects.Yield; END;
			UNTIL (n > 0) OR Kernel.Expired(milliTimer);
			IF n = 0 THEN
				error := "timeout"; ch := 0X; RETURN FALSE
			END;
			R.Char(ch); RETURN R.res = Streams.Ok
		END Read;

	END Modem;

TYPE

	Sender* = OBJECT (Modem)

		PROCEDURE YHeader(): LONGINT;
		VAR fullname, name, pathname, path: Files.FileName; prefix : ARRAY Files.PrefixLength OF CHAR; len, i, j: LONGINT; ch: CHAR;
		BEGIN
			F.GetName(fullname); len := F.Length();
			Files.SplitName(fullname, prefix, pathname);
			Files.SplitPath(pathname, path, name);

			i := 0; j := 0; ch := name[0];
			WHILE ch # 0X DO
				IF ch = ":" THEN j := 0 ELSE data[j] := ch; INC(j) END;
				INC(i); ch := name[i]
			END;
			data[j] := 0X; INC(j);
			Strings.IntToStr(len, name);
			i := 0; ch := name[0];
			WHILE ch # 0X DO
				data[j] := ch; INC(j); INC(i); ch := name[i]
			END;
			IF j < 128 THEN len := 128 ELSE len := 1024 END;
			ASSERT(j < len);
			WHILE j < len DO data[j] := 0X; INC(j) END;
			RETURN len
		END YHeader;

		PROCEDURE SendFile;
		VAR fR: Files.Reader; len, blkn, blk, i, retry: LONGINT; start, ch: CHAR;

			PROCEDURE SendData;
			VAR crc: LONGINT;
			BEGIN
				W.Char(start); W.Char(CHR(blk)); W.Char(CHR(255-blk));
				W.Bytes(data, 0, blkn); crc := CRC16(data, blkn);
				W.Char(CHR(crc DIV 256)); W.Char(CHR(crc MOD 256));
				W.Update();
				IF Read(ch) THEN
					IF ch # ACK THEN
						IF (ch = NAK) & (retry < 5) THEN
							INC(retry)
						ELSE
							fail := TRUE; error := "expected ACK"
						END
					ELSE
						blk := (blk + 1) MOD 256; retry := 0
					END
				ELSE
					fail := TRUE
				END
			END SendData;

		BEGIN
			timeout := 5000;
			i := 0; REPEAT INC(i) UNTIL Read(ch) OR (i > 10);
			IF ch = C THEN
				error := ""
			ELSIF ch # 0X THEN
				error := "expected C"; RETURN
			ELSE
				RETURN
			END;
			timeout := 10000;
			IF mode = YModem THEN
				IF YHeader() > 128 THEN start := STX; blkn := 1024 ELSE start := SOH; blkn := 128 END;
				blk := 0; SendData();
				IF ~(Read(ch) & (ch = C)) THEN error := "expected C"; RETURN END
			END;
			Files.OpenReader(fR, F, 0); len := F.Length(); totalBytes := len;
			fail := FALSE; retry := 0; blk := 1; start := STX; blkn := 1024;
			REPEAT
				IF retry = 0 THEN
					IF (mode = XModem) OR (len < (1024-128)) THEN start := SOH; blkn := 128 END;
					fR.Bytes(data, 0, blkn, i); DEC(len, blkn); INC(bytesProcessed, i);
					IF (fR.res # Streams.Ok) OR (i < blkn) THEN
						WHILE i < blkn DO data[i] := EOF; INC(i) END
					END
				END;
				SendData();
			UNTIL (fR.res # Streams.Ok) OR fail;
			IF ~fail THEN
				W.Char(EOT); W.Update();
				IF mode = YModem THEN
					IF Read(ch) & ((ch = ACK) OR (ch = NAK)) THEN
						W.Char(EOT); W.Update();
						IF Read(ch) & ((ch = ACK) OR (ch = C)) THEN
							IF (ch = C) OR (Read(ch) & (ch = C)) THEN
								start := SOH; blkn := 128; blk := 0;
								i := 0; WHILE i < blkn DO data[i] := 0X; INC(i) END;
								SendData()
							END
						END
					END
				ELSE
					IF Read(ch) & (ch = ACK) THEN END
				END
			ELSE
				W.Char(CAN); W.Update()
			END
		END SendFile;

	BEGIN {ACTIVE}
		SendFile(); Stop()
	END Sender;

	Receiver* = OBJECT (Modem)

		PROCEDURE YHeader(len: LONGINT; VAR name: ARRAY OF CHAR; VAR size: LONGINT);
		VAR i, j: LONGINT; str: ARRAY 12 OF CHAR; ch: CHAR;
		BEGIN
			size := MAX(LONGINT);
			i := 0; j := 0; ch := data[0];
			WHILE (i < len) & (ch # 0X) DO
				name[j] := ch; INC(j); INC(i); ch := data[i]
			END;
			name[j] := 0X; INC(i);
			IF (i < len) & IsDigit(data[i]) THEN
				j := 0; ch := data[i];
				WHILE (i < len) & IsDigit(data[i]) DO
					str[j] := ch; INC(j); INC(i); ch := data[i]
				END;
				str[j] := 0X; Strings.StrToInt(str, size)
			END
		END YHeader;

		PROCEDURE ReceiveFile;
		VAR name: Files.FileName; fW: Files.Writer; len, blkn, i: LONGINT; ch, ch2: CHAR;

			PROCEDURE ReceiveData(): BOOLEAN;
			VAR len, crc, crcr: LONGINT;
			BEGIN
				R.Bytes(data, 0, blkn, len); fail := (R.res # Streams.Ok) OR (len # blkn);
				IF ~fail THEN
					IF Read(ch) & Read(ch2) THEN
						crcr := 256*LONG(ORD(ch)) + LONG(ORD(ch2));
						crc := CRC16(data, blkn);
						IF crc = crcr THEN
							W.Char(ACK); W.Update(); i := (i + 1) MOD 256;
							RETURN TRUE
						ELSE
							W.Char(NAK); W.Update()
						END
					ELSE
						fail := TRUE
					END
				ELSE
					error := "receive data failed"
				END;
				RETURN FALSE
			END ReceiveData;

		BEGIN
			timeout := 5000;
			i := 0; REPEAT W.Char(C); W.Update(); INC(i) UNTIL Read(ch) OR (i > 10);
			IF ch # 0X THEN error := "" END; len := MAX(LONGINT);
			IF F # NIL THEN
				Files.OpenWriter(fW, F, 0)
			ELSIF mode # YModem THEN
				error := "invalid file handle"; RETURN
			ELSE
				fW := NIL
			END;
			timeout := 10000;
			fail := FALSE; i := 1;
			WHILE ~fail & ((ch = SOH) OR (ch = STX)) DO
				IF ch = SOH THEN blkn := 128 ELSIF ch = STX THEN blkn := 1024 END;
				IF Read(ch) & Read(ch2) THEN
					IF (i = ORD(ch)) & (ORD(ch) = (255-ORD(ch2))) THEN
						IF fW = NIL THEN
							W.Char(CAN); W.Update();
							error := "invalid file handle"; RETURN
						END;
						IF ReceiveData() THEN
							IF len < blkn THEN blkn := len END;
							fW.Bytes(data, 0, blkn); DEC(len, blkn);
							INC(bytesProcessed, blkn);
						END
					ELSIF (i = 1) & (ch = 0X) & (ch2 = 0FFX) & (mode = YModem) THEN
						IF ReceiveData() THEN
							YHeader(blkn, name, len); W.Char(C); W.Update();
							IF F = NIL THEN F := Files.New(name); Files.OpenWriter(fW, F, 0) END
						END;
						i := 1
					ELSE
						fail := TRUE; error := "wrong block number"
					END;
					IF ~fail THEN fail := ~Read(ch) END
				ELSE
					fail := TRUE
				END
			END;
			IF ~fail & ((ch = EOT) OR (ch = CAN)) THEN
				IF ch = EOT THEN
					IF mode = YModem THEN
						W.Char(NAK); W.Update();
						IF Read(ch) & (ch = EOT) THEN
							W.Char(ACK); W.Char(C); W.Update();
							IF Read(ch) & (ch = SOH) THEN
								IF Read(ch) & Read(ch2) THEN
									(* end of single file transfer *)
									ASSERT((ch = 0X) & (ch2 = 0FFX));
									blkn := 128; fail := ~ReceiveData();
									ASSERT(data[0] = 0X)
								END
							END
						END
					ELSE
						W.Char(ACK); W.Update()
					END;
					error := ""; fW.Update()
				ELSE
					W.Char(ACK); W.Update();
					error := "transfer aborted"
				END
			ELSE
				W.Char(CAN); W.Update();
				IF error = "" THEN error := "wrong block header" END
			END
		END ReceiveFile;

	BEGIN {ACTIVE}
		ReceiveFile(); Stop()
	END Receiver;

PROCEDURE IsDigit(ch: CHAR): BOOLEAN;
BEGIN
	RETURN (ch >= "0") & (ch <= "9")
END IsDigit;

PROCEDURE CRC16(VAR buf: ARRAY OF CHAR; len: LONGINT): LONGINT;
VAR i, k, crc: LONGINT;
BEGIN
	crc := 0; i := 0;
	WHILE i < len DO
		crc := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, crc) / SYSTEM.VAL(SET, LONG(ORD(buf[i]))*LONG(100H)));
		k := 0;
		WHILE k < 8 DO
			IF (15 IN SYSTEM.VAL(SET, crc)) THEN
				crc := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, crc*2) / SYSTEM.VAL(SET, 1021H))
			ELSE
				crc := crc*2
			END;
			INC(k)
		END;
		INC(i)
	END;
	RETURN crc MOD 10000H
END CRC16;

PROCEDURE GetPars(context :Commands.Context; VAR name: ARRAY OF CHAR; VAR port, bps, parity, stop: LONGINT): BOOLEAN;
BEGIN
	port := 0; bps := 115200; parity := Serials.ParNo; stop := Serials.Stop1;
	IF context.arg.GetString(name) & IsDigit(name[0]) THEN
		Strings.StrToInt(name, port);
		context.arg.SkipWhitespace; context.arg.Int(bps, FALSE);
		context.arg.SkipWhitespace; context.arg.String(name);
		IF name = "odd" THEN
			parity := Serials.ParOdd
		ELSIF name = "even" THEN
			parity := Serials.ParEven
		ELSIF name = "mark" THEN
			parity := Serials.ParMark
		ELSIF name = "space" THEN
			parity := Serials.ParSpace
		ELSIF name # "no" THEN
			context.error.String("wrong parity"); context.error.Ln();
			RETURN FALSE
		END;
		context.arg.SkipWhitespace; context.arg.String(name);
		IF name = "1.5" THEN
			stop := Serials.Stop1dot5
		ELSIF name = "2" THEN
			stop := Serials.Stop2
		ELSIF name # "1" THEN
			context.error.String("wrong stop bits"); context.error.Ln();
			RETURN FALSE
		END;
		context.arg.SkipWhitespace; context.arg.String(name);
	END;
	RETURN TRUE
END GetPars;

PROCEDURE xySend(context : Commands.Context; mode: LONGINT);
VAR
	name: Files.FileName; F: Files.File;
	port: Serials.Port; portn, bps, parity, stop, res: LONGINT;
	send: Sender; error: ARRAY 64 OF CHAR;
	W: Streams.Writer; R: Streams.Reader;
BEGIN
	IF GetPars(context, name, portn, bps, parity, stop) THEN
		context.out.String(name); context.out.Ln;
		F := Files.Old(name);

		port := Serials.GetPort(portn);
		ASSERT(port # NIL);
		port.Open(bps, 8, parity, stop, res);
		ASSERT(res = Serials.Ok);
		Streams.OpenWriter(W, port.Send); Streams.OpenReader(R, port.Receive);
		NEW(send, W, R, F, mode);
		send.Await(error);
		port.Close();

		IF error # "" THEN
			context.error.String("  "); context.error.String(error);
		ELSE
			context.out.String("  done");
		END;
		context.out.Ln;
	END;
END xySend;

PROCEDURE XSend*(context : Commands.Context);
BEGIN
	context.out.String("XSend ");
	xySend(context, XModem)
END XSend;

PROCEDURE XSend1K*(context : Commands.Context);
BEGIN
	context.out.String("XSend1K ");
	xySend(context, XModem1K)
END XSend1K;

PROCEDURE YSend*(context : Commands.Context);
BEGIN
	context.out.String("YSend ");
	xySend(context, YModem)
END YSend;

PROCEDURE xyReceive(context : Commands.Context; mode: LONGINT);
VAR
	name: Files.FileName; F: Files.File;
	port: Serials.Port; portn, bps, parity, stop, res: LONGINT;
	recv: Receiver; error: ARRAY 64 OF CHAR; awaitF: BOOLEAN;
	W: Streams.Writer; R: Streams.Reader;
BEGIN
	IF GetPars(context, name, portn, bps, parity, stop) THEN
		context.out.String(name); context.out.Ln();
		IF name # "" THEN
			F := Files.New(name); awaitF := FALSE
		ELSE
			ASSERT(mode = YModem);
			F := NIL; awaitF := TRUE
		END;

		port := Serials.GetPort(portn);
		ASSERT(port # NIL);
		port.Open(bps, 8, parity, stop, res);
		ASSERT(res = Serials.Ok);
		Streams.OpenWriter(W, port.Send); Streams.OpenReader(R, port.Receive);
		NEW(recv, W, R, F, mode);
		IF ~awaitF THEN
			recv.Await(error)
		ELSE
			recv.AwaitF(F, error)
		END;
		port.Close();

		IF error # "" THEN
			context.error.String("  "); context.error.String(error);
		ELSE
			Files.Register(F);
			IF awaitF THEN
				F.GetName(name);
				context.out.String("  "); context.out.String(name);
			END;
			context.out.String("  done");
		END;
		context.out.Ln;
	END;
END xyReceive;

PROCEDURE XReceive*(context : Commands.Context);
BEGIN
	context.out.String("XReceive ");
	xyReceive(context, XModem)
END XReceive;

PROCEDURE YReceive*(context : Commands.Context);
BEGIN
	context.out.String("YReceive ");
	xyReceive(context, YModem)
END YReceive;

END XYModem.

Aos.Call XYModem.YSend 0 115200 no 1 test.dat ~

Aos.Call XYModem.YReceive 0 115200 no 1 test.dat ~

System.Free XYModem ~
