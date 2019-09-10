MODULE FTPClient;	(** AUTHOR "TF"; PURPOSE "FTP client services"; *)

IMPORT Streams, Kernel, Objects, IP, DNS, TCP, Strings, KernelLog;

CONST
	ResOk = 0;
	ResFailed = 1;
	ResAlreadyOpen = 2;
	ResServerNotFound = 3;
	ResNoConnection = 4;
	ResUserPassError = 5;
	ResServerNotReady = 6;
	ResServerFailed = 7;

	FileActionOk = 250; CommandOk = 200; DataConnectionOpen = 125; FileStatusOk = 150;
	EnterPassword = 330; NeedPassword = 331; PathNameCreated = 257; UserLoggedIn = 230;

	ActvTimeout = 60 * 1000;
	Debug = FALSE;

TYPE
	FTPEntry* = OBJECT
	VAR
		full* : ARRAY 331 OF CHAR;
		flags* : ARRAY 11 OF CHAR;
		type* : ARRAY 4 OF CHAR;
		user*, group*, size* : ARRAY 9 OF CHAR;
		d0*, d1*, d2* : ARRAY 13 OF CHAR;
		filename* : ARRAY 256 OF CHAR;
		visible* : BOOLEAN;
	END FTPEntry;

	FTPListing* = POINTER TO ARRAY OF FTPEntry;

	(** FTP client object must be used by a single process *)
	FTPClient* = OBJECT
	VAR
		open : BOOLEAN;
		busy : BOOLEAN;
		connection : TCP.Connection; (* control connection to the server *)
		dataCon : TCP.Connection;
		dataIP : IP.Adr;
		dataPort : SIGNED32;
		w : Streams.Writer; (* writer oo the control connection *)
		r : Streams.Reader; (* reader on the control connection *)
		msg- : ARRAY 4096 OF CHAR;
		code : SIGNED32;
		passiveTransfer : BOOLEAN;
		actvListener : TCP.Connection;
		actvTimeout : Objects.Timer;

		listing- : FTPListing;
		nofEntries- : SIZE;

		PROCEDURE &Init*;
		BEGIN
			NEW(actvTimeout)
		END Init;


		PROCEDURE Open*(CONST host, user, password : ARRAY OF CHAR; port : SIGNED32; VAR res : INTEGER);
		VAR fadr : IP.Adr;
		BEGIN {EXCLUSIVE}
			res := 0;
			busy := FALSE; open := FALSE;
			IF open THEN res := ResAlreadyOpen; RETURN END;
			DNS.HostByName(host, fadr, res);
			IF res = DNS.Ok THEN
				NEW(connection);
				connection.Open(TCP.NilPort, fadr, port, res);
				IF res = TCP.Ok THEN
					Streams.OpenWriter(w, connection.Send);
					Streams.OpenReader(r, connection.Receive);
					ReadResponse(code, msg);
					IF (code >= 200) & (code < 300) THEN
						IF Login(user, password) THEN open := TRUE;
							(* Set binary transfer mode - anything else seems useless *)
							w.String("TYPE I"); w.Ln; w.Update;
							ReadResponse(code, msg);
							IF code # CommandOk THEN res := ResServerFailed END
						ELSE res := ResUserPassError
						END
					ELSE res := ResServerNotReady
					END
				ELSE res := ResNoConnection
				END;
				IF ~open THEN connection.Close(); w := NIL; r := NIL END
			ELSE res := ResServerNotFound
			END
		END Open;

		PROCEDURE Login(CONST user, password : ARRAY OF CHAR) : BOOLEAN;
		BEGIN
			w.String("USER "); w.String(user); w.Ln; w.Update;
			ReadResponse(code, msg);
			IF (code = EnterPassword) OR (code = NeedPassword) THEN
				w.String("PASS "); w.String(password); w.Ln; w.Update;
				ReadResponse(code, msg);
				IF (code = UserLoggedIn) OR (code = EnterPassword) (* why ? *) THEN
					RETURN TRUE
				ELSE
					RETURN FALSE
				END
			ELSIF code = UserLoggedIn THEN RETURN TRUE
			ELSE RETURN FALSE
			END
		END Login;

		PROCEDURE ReadResponse(VAR code : SIGNED32; VAR reply : ARRAY OF CHAR);
		VAR temp : ARRAY 1024 OF CHAR; tcode: ARRAY 4 OF CHAR; t : SIGNED32;
			stop : BOOLEAN;
		BEGIN
			r.Int(code, FALSE); COPY("", reply);
			IF r.Peek() = "-" THEN (* multi line response *)
				stop := FALSE;
				REPEAT
					r.Ln(temp); Strings.Append(reply, temp); tcode[0] := CHR(10); tcode[1] := 0X;
					Strings.Append(reply, tcode);
					tcode[0] := temp[0]; tcode[1] := temp[1]; tcode[2] := temp[2]; tcode[3] := 0X;
					Strings.StrToInt(tcode, t);
					IF (t = code) & (temp[3] # "-") THEN stop := TRUE END;
				UNTIL stop OR (r.res # 0)
			ELSE
				r.Ln(temp); Strings.Append(reply, temp);
			END;
		END ReadResponse;

		PROCEDURE Close*(VAR res : INTEGER);
		BEGIN
			w.String("QUIT"); w.Ln; w.Update;
			ReadResponse(code, msg);
			IF (code >= 200) & (code < 300) THEN res := 0 ELSE res := code END;
			connection.Close; w := NIL; r := NIL;
			open := FALSE
		END Close;

		PROCEDURE IsAlive*() : BOOLEAN;
		VAR state: SIGNED32;
		BEGIN
			state := connection.state;
			IF (state IN TCP.ClosedStates) OR (state = 5) THEN RETURN FALSE
			ELSE RETURN TRUE END
		END IsAlive;

		PROCEDURE IsNum(ch : CHAR) : BOOLEAN;
		BEGIN
			RETURN (ch >= '0') & (ch <='9')
		END IsNum;

		PROCEDURE GetDataConnection( VAR res : INTEGER);
		VAR ch : CHAR; i, j : SIZE; ipstr : ARRAY 16 OF CHAR; p0, p1, port : SIGNED32;
			str : ARRAY 32 OF CHAR;

			PROCEDURE Fail;
			BEGIN
				res := -1; r.SkipLn
			END Fail;

		BEGIN
			IF passiveTransfer THEN
				w.String("PASV"); w.Ln; w.Update;
				r.Int(code, FALSE);
				IF Debug THEN
					KernelLog.String("PASV");
					KernelLog.String("code = "); KernelLog.Int(code, 0); KernelLog.Ln;
				END;
			END;

			IF passiveTransfer & (code >= 200) & (code < 300) THEN
				(* search for a number *)
				REPEAT ch := r.Get() UNTIL IsNum(ch) OR (r.res # 0);
				IF r.res # 0 THEN Fail; RETURN END;
				(* read ip adr *)
				j := 0; i := 0;
				WHILE (r.res = 0) & (j < 4) DO
					IF ch = "," THEN ch := "."; INC(j) END;
					KernelLog.Char(ch);
					IF j < 4 THEN ipstr[i] := ch; INC(i); ch := r.Get()  END
				END;
				ipstr[i] := 0X;
				IF Debug THEN
					KernelLog.String("ipstr = "); KernelLog.String(ipstr); KernelLog.Ln;
				END;
				IF r.res # 0 THEN Fail; RETURN END;

				(* read the port *)
				r.Int(p0, FALSE); ch := r.Get();
				IF ch # "," THEN Fail; RETURN END;
				r.Int(p1, FALSE);
				r.SkipLn;
				port := p0 * 256 + p1;
				IF Debug THEN
					KernelLog.String(ipstr); KernelLog.Ln;
					KernelLog.Int(port, 0); KernelLog.Ln;
				END;
				dataIP := IP.StrToAdr(ipstr);
				dataPort := port;
			ELSE
				IF passiveTransfer THEN r.SkipLn END; (* skip the negative reply message to PASV *)
				passiveTransfer := FALSE;
				(* trying to find an unused local tcp port within the limits of FTP *)
				NEW(actvListener);
				actvListener.Open(TCP.NilPort, IP.NilAdr, TCP.NilPort, res);
				IP.AdrToStr(connection.int.localAdr, str);
				i := 0; WHILE (str[i] # 0X) DO IF (str[i] = ".") THEN str[i] := "," END; INC(i) END;
				str[i] := ","; str[i+1] := 0X;
				w.String("PORT ");
				w.String(str);
				w.Int(actvListener.lport DIV 100H, 0);
				w.Char(",");
				w.Int(actvListener.lport MOD 100H, 0);
				w.Ln; w.Update;
				ReadResponse(code, msg);
				IF Debug THEN
					KernelLog.String("code = "); KernelLog.Int(code, 0); KernelLog.Ln;
					KernelLog.String("msg = "); KernelLog.String(msg); KernelLog.Ln;
				END;
			END
		END GetDataConnection;

		PROCEDURE ActvTimeoutHandler;
		BEGIN
			actvListener.Close
		END ActvTimeoutHandler;

		PROCEDURE WaitEstablished(c: TCP.Connection);
		VAR t: Kernel.MilliTimer;
		BEGIN
			ASSERT(c # NIL);
			IF (c.state # TCP.Established) THEN
				Kernel.SetTimer(t, 500);
				WHILE (c.state # TCP.Established) & ~Kernel.Expired(t) DO
					Objects.Yield
				END
			END
		END WaitEstablished;

		PROCEDURE OpenDataConnection(VAR connection : TCP.Connection; VAR res : INTEGER);
		BEGIN
			IF passiveTransfer THEN
				NEW(connection); connection.Open(TCP.NilPort, dataIP, dataPort, res)
			ELSE
				Objects.SetTimeout(actvTimeout, ActvTimeoutHandler, ActvTimeout);
				actvListener.Accept(connection, res);
				IF Debug THEN
					KernelLog.String("res = "); KernelLog.Int(res, 0); KernelLog.Ln;
				END;
				Objects.CancelTimeout(actvTimeout);
				actvListener.Close;
				IF (res = TCP.Ok) THEN
					WaitEstablished(connection);
				END;
				IF Debug THEN
					KernelLog.String("Active connection established"); KernelLog.Ln;
				END
			END
		END OpenDataConnection;

		PROCEDURE OpenPut*(CONST remoteName : ARRAY OF CHAR; VAR outw : Streams.Writer; VAR res : INTEGER);
		BEGIN
			IF ~open OR busy THEN res := -2; RETURN END;
			GetDataConnection(res);
			IF res # 0 THEN RETURN END;

			w.String("STOR "); w.String(remoteName); w.Ln; w.Update;
			ReadResponse(code, msg);
			IF Debug THEN
				KernelLog.String("code = "); KernelLog.Int(code, 0); KernelLog.Ln;
				KernelLog.String("msg = "); KernelLog.String(msg); KernelLog.Ln;
			END;
			IF (code = FileStatusOk) OR (code = FileActionOk) OR (code = DataConnectionOpen)  THEN
				OpenDataConnection(dataCon, res);
				IF Debug THEN
					KernelLog.String("ODC");  KernelLog.String("res = "); KernelLog.Int(res, 0); KernelLog.Ln;
				END;
				IF res = 0 THEN
					busy := TRUE;
					Streams.OpenWriter(outw, dataCon.Send)
				END
			ELSE res := -1
			END
		END OpenPut;

		PROCEDURE ClosePut*(VAR res : INTEGER);
		BEGIN
			busy := FALSE;
			IF dataCon # NIL THEN
				dataCon.Close;
				dataCon := NIL
			END;
			ReadResponse(code, msg);
			IF (code >= 200) & (code < 300) THEN res := 0 ELSE res := code END;
			IF Debug THEN
				KernelLog.String("Result after close put"); KernelLog.Ln;
				KernelLog.String("code = "); KernelLog.Int(code, 0); KernelLog.Ln;
				KernelLog.String("msg = "); KernelLog.String(msg); KernelLog.Ln
			END
		END ClosePut;

		PROCEDURE OpenGet*(CONST remoteName : ARRAY OF CHAR; VAR r : Streams.Reader; VAR res : INTEGER);
		BEGIN
			IF ~open OR busy THEN res := -2; RETURN END;
			busy := TRUE;
			GetDataConnection(res);
			IF res # 0 THEN RETURN END;

			w.String("RETR "); w.String(remoteName); w.Ln; w.Update;
			ReadResponse(code, msg);
			IF Debug THEN
				KernelLog.String("code = "); KernelLog.Int(code, 0); KernelLog.Ln;
				KernelLog.String("msg = "); KernelLog.String(msg); KernelLog.Ln;
			END;
			IF (code = FileStatusOk) OR (code = FileActionOk) OR (code = DataConnectionOpen)  THEN
				OpenDataConnection(dataCon, res);
				IF Debug THEN
					KernelLog.String("ODC");  KernelLog.String("res = "); KernelLog.Int(res, 0); KernelLog.Ln;
				END;
				IF res = 0 THEN
					Streams.OpenReader(r, dataCon.Receive)
				END
			ELSE res := -1
			END
		END OpenGet;

		PROCEDURE CloseGet*(VAR res : INTEGER);
		BEGIN
			IF dataCon # NIL THEN
				dataCon.Close;
				dataCon := NIL
			END;
			busy := FALSE;
			ReadResponse(code, msg);
			IF (code >= 200) & (code < 300) THEN res := 0 ELSE res := code END;
			IF Debug THEN
				KernelLog.String("Result after close get"); KernelLog.Ln;
				KernelLog.String("code = "); KernelLog.Int(code, 0); KernelLog.Ln;
				KernelLog.String("msg = "); KernelLog.String(msg); KernelLog.Ln
			END
		END CloseGet;

		PROCEDURE DeleteFile*(CONST remoteName : ARRAY OF CHAR; VAR res : INTEGER);
		BEGIN
			IF ~open OR busy THEN res := -2; RETURN END;
			w.String("DELE "); w.String(remoteName); w.Ln; w.Update;
			ReadResponse(code, msg);
			IF (code >= 200) & (code <300) THEN res := ResOk ELSE res := ResFailed END
		END DeleteFile;

		PROCEDURE ChangeDir*(CONST dir : ARRAY OF CHAR; VAR res : INTEGER);
		BEGIN
			IF ~open OR busy THEN res := -2; RETURN END;
			w.String("CWD "); w.String(dir); w.Ln; w.Update;
			ReadResponse(code, msg);
			IF (code >= 200) & (code <300) THEN res := ResOk ELSE res := ResFailed END
		END ChangeDir;

		PROCEDURE MakeDir*(CONST dir : ARRAY OF CHAR; VAR res : INTEGER);
		BEGIN
			IF ~open OR busy THEN res := -2; RETURN END;
			w.String("MKD "); w.String(dir); w.Ln; w.Update;
			ReadResponse(code, msg);
			IF (code >= 200) & (code <300) THEN res := ResOk ELSE res := ResFailed END
		END MakeDir;

		PROCEDURE RemoveDir*(CONST dir : ARRAY OF CHAR; VAR res : INTEGER);
		BEGIN
			IF ~open OR busy THEN res := -2; RETURN END;
			w.String("RMD "); w.String(dir); w.Ln; w.Update;
			ReadResponse(code, msg);
			IF (code >= 200) & (code <300) THEN res := ResOk ELSE res := ResFailed END
		END RemoveDir;

		PROCEDURE RenameFile*(CONST currentName, newName : ARRAY OF CHAR; VAR res : INTEGER);
		BEGIN
			IF ~open OR busy THEN res := -2; RETURN END;
			w.String("RNFR "); w.String(currentName); w.Ln; w.Update;
			ReadResponse(code, msg);
			IF (code = 350) THEN
				w.String("RNTO "); w.String(newName); w.Ln; w.Update;
				ReadResponse(code, msg);
				IF code = 250 THEN res := ResOk
				ELSE res := ResFailed
				END
			ELSE res := ResFailed
			END
		END RenameFile;

		PROCEDURE EnumerateNames*;
		VAR
			res : INTEGER;
			r : Streams.Reader; s, filename : ARRAY 256 OF CHAR;
			flags : ARRAY 11 OF CHAR;
			type : ARRAY 4 OF CHAR;
			user, group, size : ARRAY 9 OF CHAR;
			d0, d1, d2: ARRAY 13 OF CHAR;
			sr : Streams.StringReader;
			entry : FTPEntry;

		BEGIN
			IF ~open OR busy THEN res := -2; RETURN END;
			IF Debug THEN
				KernelLog.String("Enumerate Dir"); KernelLog.Ln;
			END;
			GetDataConnection(res);
			IF res # 0 THEN RETURN END;
			w.String("NLST"); w.Ln; w.Update;
			ReadResponse(code, msg);
			IF Debug THEN
				KernelLog.String("code = "); KernelLog.Int(code, 0); KernelLog.Ln;
				KernelLog.String("msg = "); KernelLog.String(msg); KernelLog.Ln;
			END;
			IF (code = FileStatusOk) OR (code = FileActionOk) OR (code = DataConnectionOpen)  THEN
				IF Debug THEN
					KernelLog.String("Open data connection"); KernelLog.Ln;
				END;
				OpenDataConnection(dataCon, res);
				IF Debug THEN
					KernelLog.String("ODC");  KernelLog.String("res = "); KernelLog.Int(res, 0); KernelLog.Ln;
				END;
				IF res = 0 THEN
					Streams.OpenReader(r, dataCon.Receive);
					NEW(sr, 256); NEW(listing, 16); nofEntries := 0;
					REPEAT
						r.Ln(s);
						IF r.res = 0 THEN
							sr.Set(s); NEW(entry);

							COPY("", flags);
							COPY("", type);
							COPY("", user);
							COPY("", group);
							COPY("", size);
							COPY("", d0);
							COPY("", d1);
							COPY("", d2);
							sr.Ln(filename);

							COPY(flags, entry.flags);
							COPY(type, entry.type);
							COPY(user, entry.user);
							COPY(group, entry.group);
							COPY(size, entry.size);
							COPY(d0, entry.d0);
							COPY(d1, entry.d1);
							COPY(d2, entry.d2);
							COPY(filename, entry.filename);
							COPY(s, entry.full);
							AddFTPEntryToListing(entry);

(*							IF Debug THEN
								KernelLog.String("flags = "); KernelLog.String(flags); KernelLog.Ln;
								KernelLog.String("type = "); KernelLog.String(type); KernelLog.Ln;
								KernelLog.String("user = "); KernelLog.String(user); KernelLog.Ln;
								KernelLog.String("group = "); KernelLog.String(group); KernelLog.Ln;
								KernelLog.String("size = "); KernelLog.String(size); KernelLog.Ln;
								KernelLog.String("date = "); KernelLog.String(d0); KernelLog.String(d1);KernelLog.String(d2);KernelLog.Ln;
								KernelLog.String("filename = "); KernelLog.String(filename); KernelLog.Ln;
								KernelLog.Ln;
							END
*)						END
					UNTIL r.res # 0
				END;
				IF (dataCon # NIL) THEN dataCon.Close; END;

				ReadResponse(code, msg);
				IF Debug THEN
					KernelLog.String("Result after Dir"); KernelLog.Ln;
					KernelLog.String("code = "); KernelLog.Int(code, 0); KernelLog.Ln;
					KernelLog.String("msg = "); KernelLog.String(msg); KernelLog.Ln;
				END
			ELSE res := ResFailed
			END;
			dataCon := NIL
		END EnumerateNames;

		PROCEDURE EnumerateDir*(CONST args : ARRAY OF CHAR);
		VAR  res : INTEGER;
			r : Streams.Reader; s, filename : ARRAY 256 OF CHAR;
			flags : ARRAY 11 OF CHAR;
			type : ARRAY 4 OF CHAR;
			user, group, size : ARRAY 9 OF CHAR;
			d0, d1, d2: ARRAY 13 OF CHAR;
			sr : Streams.StringReader;
			entry : FTPEntry;
			ch : CHAR;

(*
			PROCEDURE FixLengthStr(r : Streams.Reader; len : SIZE; VAR s : ARRAY OF CHAR);
			VAR i : SIZE;
			BEGIN
				WHILE (len > 0) & (r.res = 0) DO
					s[i] := r.Get();
					DEC(len); INC(i)
				END;
				s[i] := 0X
			END FixLengthStr;
*)

		BEGIN
			IF ~open OR busy THEN res := -2; RETURN END;
			IF Debug THEN
				KernelLog.String("Enumerate Dir"); KernelLog.Ln;
			END;
			GetDataConnection(res);
			IF res # 0 THEN RETURN END;
			w.String("LIST");
			IF args # "" THEN w.String(" "); w.String(args) END;
			w.Ln; w.Update;
			ReadResponse(code, msg);
			IF Debug THEN
				KernelLog.String("code = "); KernelLog.Int(code, 0); KernelLog.Ln;
				KernelLog.String("msg = "); KernelLog.String(msg); KernelLog.Ln;
			END;
			IF (code = FileStatusOk) OR (code = FileActionOk) OR (code = DataConnectionOpen)  THEN
				IF Debug THEN
					KernelLog.String("Open data connection"); KernelLog.Ln;
				END;
				OpenDataConnection(dataCon, res);
				IF Debug THEN
					KernelLog.String("ODC");  KernelLog.String("res = "); KernelLog.Int(res, 0); KernelLog.Ln;
				END;
				IF res = 0 THEN
					Streams.OpenReader(r, dataCon.Receive);
					NEW(sr, 256); NEW(listing, 16); nofEntries := 0;
					REPEAT
						r.Ln(s);
						IF r.res = 0 THEN
							sr.Set(s); NEW(entry);
(*							KernelLog.String("s = "); KernelLog.String(s); KernelLog.Ln;

							FixLengthStr(sr, 10, flags); sr.SkipBytes(1);
							FixLengthStr(sr, 3, type); sr.SkipBytes(1);
							FixLengthStr(sr, 8, user); sr.SkipBytes(1);
							FixLengthStr(sr, 8, group); sr.SkipBytes(1);
							FixLengthStr(sr, 8, size); sr.SkipBytes(1);
							FixLengthStr(sr, 12, date); sr.SkipBytes(1); *)

							ch := sr.Peek();
							IF  (ch = "-") OR (ch = "d") OR (ch = "l") THEN (* unix *)
								sr.Token(flags); sr.SkipWhitespace;
								sr.Token(type); sr.SkipWhitespace;
								sr.Token(user); sr.SkipWhitespace;
								sr.Token(group); sr.SkipWhitespace;
								sr.Token(size); sr.SkipWhitespace;
								sr.Token(d0); sr.SkipWhitespace;
								sr.Token(d1); sr.SkipWhitespace;
								sr.Token(d2); sr.SkipWhitespace;

								sr.Ln(filename);
							ELSE (* windows *)
								COPY("", type);
								COPY("", user);
								COPY("", group);
								COPY("", size);
								COPY("", d2);
								sr.Token(d0); sr.SkipWhitespace;
								sr.Token(d1); sr.SkipWhitespace;
								sr.Token(flags); sr.SkipWhitespace;
								sr.Ln(filename);
								IF flags # "<DIR>" THEN COPY(flags, size); COPY("", flags)	END
							END;

							COPY(flags, entry.flags);
							COPY(type, entry.type);
							COPY(user, entry.user);
							COPY(group, entry.group);
							COPY(size, entry.size);
							COPY(d0, entry.d0);
							COPY(d1, entry.d1);
							COPY(d2, entry.d2);
							COPY(filename, entry.filename);
							COPY(s, entry.full);
							AddFTPEntryToListing(entry);

(*							IF Debug THEN
								KernelLog.String("flags = "); KernelLog.String(flags); KernelLog.Ln;
								KernelLog.String("type = "); KernelLog.String(type); KernelLog.Ln;
								KernelLog.String("user = "); KernelLog.String(user); KernelLog.Ln;
								KernelLog.String("group = "); KernelLog.String(group); KernelLog.Ln;
								KernelLog.String("size = "); KernelLog.String(size); KernelLog.Ln;
								KernelLog.String("date = "); KernelLog.String(d0); KernelLog.String(d1);KernelLog.String(d2);KernelLog.Ln;
								KernelLog.String("filename = "); KernelLog.String(filename); KernelLog.Ln;
								KernelLog.Ln;
							END
*)						END
					UNTIL r.res # 0
				END;
				IF (dataCon # NIL) THEN dataCon.Close; END;

				ReadResponse(code, msg);
				IF Debug THEN
					KernelLog.String("Result after Dir"); KernelLog.Ln;
					KernelLog.String("code = "); KernelLog.Int(code, 0); KernelLog.Ln;
					KernelLog.String("msg = "); KernelLog.String(msg); KernelLog.Ln;
				END
			ELSE res := ResFailed
			END;
			dataCon := NIL
		END EnumerateDir;

		PROCEDURE AddFTPEntryToListing(entry : FTPEntry);
		VAR newList : FTPListing;
			i : SIZE;
		BEGIN
			INC(nofEntries);
			IF (nofEntries > LEN(listing)) THEN
				NEW(newList, LEN(listing)*2);
				FOR i := 0 TO LEN(listing)-1 DO newList[i] := listing[i] END;
				listing := newList;
			END;
			listing[nofEntries-1] := entry;
		END AddFTPEntryToListing;

		PROCEDURE GetCurrentDir*(VAR dir : ARRAY OF CHAR; VAR res : INTEGER);
		VAR p : SIZE;
		BEGIN
			IF ~open OR busy THEN res := -2; RETURN END;
			w.String("PWD"); w.Ln; w.Update;
			ReadResponse(code, msg);
			KernelLog.String("msg = "); KernelLog.String(msg); KernelLog.Ln;
			IF code = PathNameCreated THEN
				COPY(msg, dir);
				p := Strings.Pos('"', dir);
				IF p >= 0 THEN
					Strings.Delete(dir, 0, p + 1);
					p := Strings.Pos('"', dir); Strings.Delete(dir, p, Strings.Length(dir) - p)
				ELSE
					p := Strings.Pos(' ', dir); Strings.Delete(dir, p, Strings.Length(dir) - p)
				END
			ELSE COPY("", dir); res := ResFailed
			END;
		END GetCurrentDir;

		PROCEDURE Raw*(CONST cmd : ARRAY OF CHAR; VAR res : INTEGER);
		VAR extMsg : ARRAY 4096 OF CHAR;
			command : ARRAY 32 OF CHAR; arguments : ARRAY 512 OF CHAR;
		BEGIN
			IF ~open OR busy THEN res := -2; RETURN END;
			SplitCommand(cmd, command, arguments);
			Strings.LowerCase(command);
			IF command = "list" THEN EnumerateDir(arguments)
			ELSE
				w.String(cmd); w.Ln; w.Update;
				ReadResponse(code, extMsg);
				KernelLog.String("code = "); KernelLog.Int(code, 0);
				KernelLog.String(" , msg = "); KernelLog.String(extMsg); KernelLog.Ln
			END;
			res := 0
		END Raw;

		PROCEDURE SplitCommand(CONST cmd : ARRAY OF CHAR; VAR command, args : ARRAY OF CHAR);
		VAR sr : Streams.StringReader;
		BEGIN
			NEW(sr, 512);
			sr.Set(cmd);
			sr.Token(command); sr.SkipWhitespace;
			sr.Ln(args);
		END SplitCommand;

	END FTPClient;

END FTPClient.

System.Free FTPClient~

Color Codes
Highlight
Types and Procedures
Lock Acquire / Lock Release
Preferred notation (comment)
Unsafe / Temporary / Stupid / requires attention
Permanent Comment
Assertion
Debug

