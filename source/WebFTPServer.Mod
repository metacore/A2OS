(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE WebFTPServer;	(** AUTHOR "be"; PURPOSE "FTP Server" *)

(* based on a first version by prk *)

IMPORT
	Kernel, Modules, IP, TCP, TCPServices, Objects, Commands,
	Streams, Files,KernelLog, Dates, Strings;

CONST
	moduleName = "WebFTPServer: ";

	LogFile = "FTP.Log";
	PathDelimiter = Files.PathDelimiter;

	CmdLen = 32;
	LineLen = 1024;

	UserFile = "WebFTPUsers.dat";	(* user file *)

	BufSize = 16*1024; (* internal buffer size, used for file transfer *)
	dirLen = 1024;		(* Maximum length of a filename (including FS-prefix, root and working directory) *)
	nameLen = 32;		(* Maximum length of username *)
	pwdLen = 32;		  (* Maximum length of password *)
	CR = 0DX; LF = 0AX; Tab = 09X;

	(* Timeout & max subsequent error count*)
	Timeout = 900*1000;	(* [ms] timeout on control connection *)
	PasvTimeout = 60*1000; (* [ms] timeout on passive connections *)
	MaxErrors = 10;			(* control connection is closed after 'MaxErrors' consecutive requests that did produce a 2** result code *)

	(* Ports *)
	FTPControlPort = 21;
	FTPDataPort = 20;

	(* Session types *)
	ASCII = 0; (* type A *)
	IMAGE = 1; (* type I *)

	(* Connection Modes *)
	Active = 0;
	Passive = 1;

	(* States *)
	Ok = 0; RNFR = 1; REST = 2;

	(* Default Messages *)
	(* message classes:
		1**: positive preliminary reply
		2**: positive completion reply
		3**: postitive intermediate reply
		4**: transient negative completion reply
		5**: permanent negative completion reply
	*)

	Msg215 = "UNIX";
	Msg220 = "Aos FTP Server ready.";
	Msg221 = "Goodbye.";
	Msg226 = "Closing data connection.";
	Msg230 = "User logged in, proceed.";
	Msg350 = "Requested file action pending further information.";
	Msg425 = "Can't open data connection.";
	Msg500 = ": not understood.";	(* add to offending command *)
	Msg504 = "Command not implemented for that parameter.";
	Msg530 = "Please login with USER and PASS.";
	Msg553 = "File name not allowed.";
	NoPermissionMsg = "No permission.";

	(* permissions *)
	read = 0; (* can read the files - bit 0 *)
	write = 1; (* can write the files - bit 1 *)
	passwrq = 2; (* password required - bit 2 *)
	mailpwd = 3; (* password is e-mail address - bit 3 *)

TYPE
	User = POINTER TO RECORD
		name: ARRAY nameLen OF CHAR;
		password, currentlogins, maxlogins: LONGINT;
		permissions: SET;
		root: ARRAY dirLen OF CHAR;
		next: User;
	END;

	LogEntry = RECORD
		user: ARRAY nameLen OF CHAR;
		ip: IP.Adr;
		method: ARRAY 16 OF CHAR;
		uri: ARRAY 1024 OF CHAR;
		status: LONGINT;
		result: WORD;
		pending: BOOLEAN;
	END;

	FTPAgent = OBJECT (TCPServices.Agent)
		VAR
			running: BOOLEAN;
			in: Streams.Reader;
			out: Streams.Writer;
			dataAdr: IP.Adr; dataPort: LONGINT;
			timeout, pasvTimeout: Objects.Timer;
			line: ARRAY LineLen OF CHAR;
			cmd: ARRAY CmdLen OF CHAR;
			logged, quit: BOOLEAN;
			user: User;
			type: SHORTINT;
			workDir: ARRAY dirLen OF CHAR;
			rnfrName: ARRAY dirLen OF CHAR;	(* RNFR parameter *)
			state: LONGINT;	(* one of: Ok, RNFR, REST *)
			mode: LONGINT;	(* one of: Active, Passive *)
			consecutiveErrors: LONGINT;	(* count of consecutive invalid commands *)
			restMarker: LONGINT;	(* position in file where next file transfer should start. *)
			pasvListener: TCP.Connection;
			logEntry: LogEntry;

		PROCEDURE TimeoutHandler;
		BEGIN
			logEntry.pending := TRUE;
			COPY("TIMEOUT", logEntry.method); logEntry.uri := "";
			SendMessage(421, "Timeout, closing control connection.");
			IF (pasvListener # NIL) & (pasvListener.state = TCP.Established) THEN pasvListener.Close END;
			client.Close
		END TimeoutHandler;

		PROCEDURE PasvTimeoutHandler;
		BEGIN
			pasvListener.Close
		END PasvTimeoutHandler;

		PROCEDURE ReadCommand(VAR cmd, param: ARRAY OF CHAR);
		VAR i,l: LONGINT; c: CHAR;
		BEGIN
			Objects.SetTimeout(timeout, TimeoutHandler, Timeout);
			in.SkipSpaces;
			i := 0; l := LEN(cmd)-1; c := in.Peek();
			WHILE (i < l) & (c # " ") & (c # CR) & (c # LF) & (in.res = Streams.Ok) DO
				cmd[i] := CAP(in.Get()); INC(i);
				c := in.Peek()
			END;
			cmd[i] := 0X;

			WHILE (c = " ") & (in.res = Streams.Ok) DO c := in.Get(); c := in.Peek() END;

			i := 0; l := LEN(param)-1;
			WHILE (i < l) & (c # CR) & (c # LF) & (in.res = Streams.Ok) DO
				param[i] := in.Get(); INC(i);
				c := in.Peek()
			END;
			param[i] := 0X;
			in.SkipLn();
			Objects.CancelTimeout(timeout)
		END ReadCommand;

		PROCEDURE SendString(str: ARRAY OF CHAR);
		BEGIN
			out.String(str); out.Ln(); out.Update
		END SendString;

		PROCEDURE SendMessage(code: LONGINT; msg: ARRAY OF CHAR);
		BEGIN
			IF logEntry.pending THEN
				logEntry.status := code;W3CLog(logEntry);
				logEntry.result := 0; logEntry.pending := FALSE
			END;
			out.Int(code, 0);out.String(" "); out.String(msg); out.Ln;
			out.Update
		END SendMessage;

		PROCEDURE GetWorkingDirMsg(VAR msg: ARRAY OF CHAR);
		BEGIN
			IF (user.root # "") & (workDir = "") THEN COPY('"/" is current directory.', msg)
			ELSE
				IF (user.root # "") THEN Strings.Concat('"/', workDir, msg)
				ELSE Strings.Concat('"', workDir, msg)
				END;
				Strings.Append(msg, '" is current directory.')
			END
		END GetWorkingDirMsg;

		PROCEDURE GetDirectories(name: ARRAY OF CHAR; VAR usr, system: ARRAY OF CHAR);
		BEGIN
			ComposeDirectory(workDir, name, usr);
			Strings.Concat(user.root, usr, system)
		END GetDirectories;

		PROCEDURE CheckDirectory(name: ARRAY OF CHAR): BOOLEAN;
		VAR prefix: Files.Prefix; path: ARRAY dirLen OF CHAR;
		BEGIN
			Strings.Concat(user.root, name, name); Strings.TrimRight(name, PathDelimiter);
			Files.SplitName(path, prefix, path);
			IF (prefix = "") OR (Files.This(prefix) # NIL) THEN
				RETURN (path = "") OR (Files.Old(name) # NIL)
			ELSE
				RETURN FALSE	(* file system not found *)
			END
		END CheckDirectory;

		PROCEDURE Directory(name: ARRAY OF CHAR; full: BOOLEAN);
		VAR data: TCP.Connection; w: Streams.Writer; e: Files.Enumerator; t: Kernel.MilliTimer;
			prefix: Files.Prefix; str: ARRAY 20 OF CHAR; date, size, time: LONGINT; res: WORD; flags: SET; c: CHAR;
			split: BOOLEAN;
		BEGIN
			SendMessage(150, "Opening ASCII mode data connection for file list.");
			IF (mode = Active) THEN
				NEW(data); data.Open(FTPDataPort, dataAdr, dataPort, res);
				dataAdr := client.fip; dataPort := FTPDataPort	(*default*)
			ELSE
				ASSERT((pasvListener # NIL) & (pasvListener.state = TCP.Listen));
				Objects.SetTimeout(pasvTimeout, PasvTimeoutHandler, PasvTimeout);
				pasvListener.Accept(data, res);
				pasvListener.Close;
				Objects.CancelTimeout(pasvTimeout);
				mode := Active
			END;
			logEntry.result := res;
			IF res # TCP.Ok THEN
				SendMessage(425, Msg425)
			ELSE
				ComposeDirectory(workDir, name, name); Strings.Concat(user.root, name, name);
				IF (name = "") THEN split := FALSE ELSE split := TRUE END; (* remove prefix & path only if we are not on root level *)

				IF full THEN flags := {Files.EnumSize, Files.EnumTime} ELSE flags := {} END;
				NEW(e); e.Open(name, flags);
				Streams.OpenWriter(w, data.Send);

				WHILE e.GetEntry(name, flags, time, date, size) DO
					IF split THEN Files.SplitPath(name, prefix, name) END;	(* remove prefix & path *)
					IF full THEN
						(* format: <flags:10>" "<type:3>" "<user:8>" "<group:8>" "<size:8>" "<month:3>" "<day:2>" "<time:5>" "<filename> *)
						IF (Files.Directory IN flags) THEN c := "d" ELSE c := "-" END;
						w.Char(c);
						w.String("rw-rw-rw-");
						w.String("   1 Aos      Aos      ");
						w.Int(size, 8);
						Strings.FormatDateTime(" mmm dd hh:nn ", Dates.OberonToDateTime(date, time), str);
						w.String(str)
					END;
					w.String(name); w.Ln;
				END;
				w.Update;
				SendMessage(226, Msg226);
				e.Close;
				IF (data.state # TCP.Established) THEN	(* clients may hang if the data connection is closed before it is established *)
					Kernel.SetTimer(t, 1000);
					WHILE (data.state # TCP.Established) & ~Kernel.Expired(t) DO
						Objects.Yield
					END
				END;
				data.Close
			END
		END Directory;

		PROCEDURE Size(name: ARRAY OF CHAR);
		VAR filename: ARRAY dirLen OF CHAR; f: Files.File;
		BEGIN
			ComposeDirectory(workDir, name, name);
			Strings.Concat(user.root, name, filename);
			f := Files.Old(filename);

			IF (f = NIL) THEN
				Strings.Append(name, ": file not found."); SendMessage(550, name)
			ELSE
				Strings.IntToStr(f.Length(), name); SendMessage(213, name)
			END
		END Size;

		PROCEDURE WaitEstablished(c: TCP.Connection);
		VAR t: Kernel.MilliTimer;
		BEGIN
			IF (c.state # TCP.Established) THEN
				Kernel.SetTimer(t, 500);
				WHILE (c.state # TCP.Established) & ~Kernel.Expired(t) DO
					Objects.Yield
				END
			END
		END WaitEstablished;

		PROCEDURE Retrieve(name: ARRAY OF CHAR; marker: LONGINT);
		VAR data: TCP.Connection; w: Streams.Writer; f: Files.File; r: Files.Reader;
			filename, msg: ARRAY dirLen OF CHAR; res: WORD;
		BEGIN
			IF (type = ASCII) THEN COPY("ASCII", msg) ELSE COPY("Binary", msg) END;
			Strings.Append(msg, " data connection for "); Strings.Append(msg, name);
			logEntry.pending := FALSE;
			SendMessage(150, msg);
			logEntry.pending := TRUE;
			IF (mode = Active) THEN
				NEW(data); data.Open(FTPDataPort, dataAdr, dataPort, res);
				dataAdr := client.fip; dataPort := FTPDataPort;	(*default*)
			ELSE
				ASSERT((pasvListener # NIL) & (pasvListener.state = TCP.Listen));
				Objects.SetTimeout(pasvTimeout, PasvTimeoutHandler, PasvTimeout);
				pasvListener.Accept(data, res);
				pasvListener.Close;
				Objects.CancelTimeout(pasvTimeout);
				mode := Active
			END;
			logEntry.result := res;
			IF res # TCP.Ok THEN
				SendMessage(425, Msg425)
			ELSE
				ComposeDirectory(workDir, name, name);
				Strings.Concat(user.root, name, filename);

				Streams.OpenWriter(w, data.Send);
				f := Files.Old(filename);

				WaitEstablished(data);	(* clients may hang if the data connection is closed before it is established *)

				IF f = NIL THEN
					Strings.Append(name, ": file not found."); SendMessage(550, name);
				ELSIF (Files.Directory IN f.flags) THEN
					Strings.Append(name, ": is a directory."); SendMessage(550, name)
				ELSE
					Files.OpenReader(r, f, marker);
					IF (type = ASCII) THEN ASCIITransfer(r, w)
					ELSE BinaryTransfer(r, w)
					END;
					IncreaseSent(f.Length());
					SendMessage(226, "Transfer complete.")
				END;

				data.Close
			END
		END Retrieve;

		PROCEDURE Store(name: ARRAY OF CHAR; marker: LONGINT);
		VAR data: TCP.Connection; r: Streams.Reader; f: Files.File; w: Files.Writer;
			filename, msg: ARRAY dirLen OF CHAR; res: WORD;
		BEGIN
			IF (type = ASCII) THEN COPY("ASCII", msg) ELSE COPY("Binary", msg) END;
			Strings.Append(msg, " data connection for "); Strings.Append(msg, name);
			logEntry.pending := FALSE;
			SendMessage(150, msg);
			logEntry.pending := TRUE;
			IF (mode = Active) THEN
				NEW(data); data.Open(FTPDataPort, dataAdr, dataPort, res);
				dataAdr := client.fip; dataPort := FTPDataPort	(*default*)
			ELSE
				ASSERT((pasvListener # NIL) & (pasvListener.state = TCP.Listen));
				Objects.SetTimeout(pasvTimeout, PasvTimeoutHandler, PasvTimeout);
				pasvListener.Accept(data, res);
				pasvListener.Close;
				Objects.CancelTimeout(pasvTimeout);
				mode := Active
			END;
			logEntry.result := res;
			IF res # TCP.Ok THEN
				SendMessage(425, Msg425)
			ELSE
				ComposeDirectory(workDir, name, name);
				Strings.Concat(user.root, name, filename);

				Streams.OpenReader(r, data.Receive);
				IF (marker = -1) THEN (* append *)
					f := Files.Old(filename);
					marker := f.Length()
				ELSIF (marker > 0) THEN (* restart *)
					f := Files.Old(filename)
				ELSE
					f := Files.New(filename);
					IF (f # NIL) THEN Files.Register(f) END
				END;

				WaitEstablished(data); 	(* clients may hang if the data connection is closed before it is established *)

				IF f = NIL THEN
					SendMessage(553, Msg553)
				ELSE
					Files.OpenWriter(w, f, marker);
					IF (type = ASCII) THEN ASCIITransfer(r, w)
					ELSE BinaryTransfer(r, w)
					END;
					f.Update();
					IncreaseReceived(f.Length());
					SendMessage(226, Msg226)
				END;

				data.Close
			END
		END Store;

		PROCEDURE Execute(VAR cmd, param: ARRAY OF CHAR);
		VAR
			tmp, filename, str: ARRAY dirLen OF CHAR;
			i, code, lastState: LONGINT; res: WORD;

		BEGIN
			lastState := state; state := Ok;

			COPY(cmd, logEntry.method); COPY(param, logEntry.uri); logEntry.pending := TRUE;

			code := 550; COPY("Requested action not taken.", str);

			IF shutdown THEN
				code := 421; COPY("Server shutting down, closing control connection.", str);
				quit := TRUE
			ELSIF cmd = "USER" THEN
				COPY(param, logEntry.user);
				user := FindUser(param);
				IF (user # NIL) THEN
					IF UserLogin(user) THEN
						Strings.Concat("Password required for ", param, str); Strings.Append(str, ".");
						code := 331;
						workDir[0] := 0X;
						IF (passwrq IN user.permissions) THEN
							IF (mailpwd IN user.permissions) THEN
								str := "Anonymous access allowed, send identity (e-mail name) as password."
							END
						ELSE code := 230; COPY(Msg230, str); logged := TRUE
						END
					ELSE
						user := NIL; code := 421; COPY("Too many users.", str)
					END
				ELSE
					code := 530; Strings.Concat("Unknown user ", param, str); Strings.Append(str, ".")
				END
			ELSIF cmd = "PASS" THEN
				code := 530; COPY(Msg530, str);
				IF (user # NIL) & (user.name # "") THEN
					IF (mailpwd IN user.permissions) THEN	(* password = e-mail address *)
						IF Strings.Match("?*@?*.?*", param) THEN code := 230; COPY(Msg230, str); logged := TRUE END
					ELSE
						logEntry.uri := ""; (* do not log password *)
						IF (Code(param) = user.password) THEN
							code := 230; COPY(Msg230, str); logged := TRUE
						END
					END
				END
			ELSIF cmd = "QUIT" THEN
				code := 221; COPY(Msg221, str); quit := TRUE
			ELSIF cmd = "NOOP" THEN
				code := 220; COPY(Msg220, str)
			ELSIF logged THEN (* these commands are only available if the user is logged in *)
				IF cmd = "CWD" THEN	(* change working directory  *)
					ComposeDirectory(workDir, param, tmp);
					IF CheckDirectory(tmp) THEN
						COPY(tmp, workDir);
						IF (workDir # "") THEN Files.ForceTrailingDelimiter(workDir) END;
						code := 250; GetWorkingDirMsg(str)
					ELSE
						code := 550; Strings.Concat(param, ": no such file or directory.", str)
					END
				ELSIF (cmd = "CDUP") OR (cmd = "XCUP") THEN	(* change to parent directory *)
					ComposeDirectory(workDir, "..", workDir);
					IF (workDir # "") THEN Files.ForceTrailingDelimiter(workDir) END;
					code := 212; GetWorkingDirMsg(str)
				ELSIF (cmd = "PWD") OR (cmd = "XPWD") THEN (* print working directory *)
					code := 257; GetWorkingDirMsg(str)
				ELSIF (cmd = "MKD") OR (cmd = "XMKD") THEN
					IF (write IN user.permissions) THEN
						GetDirectories(param, tmp, filename);

						Files.CreateDirectory(filename, res);
						logEntry.result := res;
						IF (res = 0) THEN
							code := 257; Strings.Concat('"', tmp, str); Strings.Append(str, '": directory successfully created.')
						ELSE
							code := 550; Strings.Concat(tmp, ": failed to create directory", str)
						END
					ELSE
						code := 550; COPY(NoPermissionMsg, str)
					END
				ELSIF (cmd = "RMD") OR (cmd = "XRMD") THEN
					IF (write IN user.permissions) THEN
						GetDirectories(param, tmp, filename);

						Files.RemoveDirectory(filename, FALSE, res);
						logEntry.result := res;
						IF (res = 0) THEN
							code := 257; Strings.Concat('"', tmp, str); Strings.Append(str, '": directory successfully deleted.')
						ELSE code := 550; Strings.Concat(tmp, ": failed to delete directory", str)
						END
					ELSE
						code := 550; COPY(NoPermissionMsg, str)
					END
				ELSIF cmd = "DELE" THEN
					IF (write IN user.permissions) THEN
						GetDirectories(param, tmp, filename);

						Files.Delete(filename, res);
						logEntry.result := res;
						IF (res = 0) THEN code := 200; Strings.Concat('"', tmp, str); Strings.Append(str, '" deleted.')
						ELSE code := 450; Strings.Concat(tmp, ": cannot delete file.", str)
						END
					ELSE
						code := 550; COPY(NoPermissionMsg, str)
					END
				ELSIF cmd = "PASV" THEN
					mode := Passive;
					NEW(pasvListener);
					pasvListener.Open(TCP.NilPort, IP.NilAdr, TCP.NilPort, res);
					logEntry.result := res;
					IF (res = IP.Ok) THEN
						IP.AdrToStr(client.int.localAdr, str);
						i := 0; WHILE (str[i] # 0X) DO IF (str[i] = ".") THEN str[i] := "," END; INC(i) END;
						str[i] := ","; str[i+1] := 0X;
						Strings.IntToStr(pasvListener.lport DIV 100H, tmp);
						Strings.Append(str, tmp); Strings.Append(str, ",");
						Strings.IntToStr(pasvListener.lport MOD 100H, tmp);
						Strings.Append(str, tmp);
						Strings.Concat("Entering Passive Mode (", str, str);
						Strings.Append(str, ")");
						code := 227
					ELSE	(* 425 is not an official reply, but the only one that makes sense *)
						code := 425; COPY("Can't open data connection.", str)
					END
				ELSIF cmd = "EPSV" THEN
					mode := Passive;
					NEW(pasvListener);
					pasvListener.Open(TCP.NilPort, IP.NilAdr, TCP.NilPort, res);
					logEntry.result := res;
					IF (res = IP.Ok) THEN
						str := "";
						Strings.IntToStr(pasvListener.lport, tmp);
						Strings.Append(str, "Entering Extended Passive Mode (|||");
						Strings.Append(str, tmp);
						Strings.Append(str, "|)");
						code := 229;
					ELSE
						code := 500; COPY("Can't open data connection.", str)
					END
				ELSIF cmd = "SYST" THEN
					code := 215; COPY(Msg215, str)
				ELSIF cmd = "TYPE" THEN
					IF (param = "A") OR (param = "I") THEN
						IF (param = "A") THEN type := ASCII
						ELSE type := IMAGE
						END;
						code := 200; Strings.Concat("Type set to ", param, str)
					ELSE
						code := 504; COPY(Msg504, str)
					END
				ELSIF (cmd = "NLST") OR (cmd = "LIST") THEN
					IF (read IN user.permissions) THEN
						Directory(param, (cmd="LIST")); code := -1
					ELSE
						code := 550; COPY(NoPermissionMsg, str)
					END
				ELSIF cmd = "PORT" THEN
					SplitPort(param, dataAdr, dataPort);
					code := 200; COPY("PORT command successful.", str)
				ELSIF cmd = "EPRT" THEN
					SplitEPRT(param, dataAdr, dataPort);
					code := 200; COPY("EPRT command successful.", str);
				ELSIF cmd = "SIZE" THEN
					IF (read IN user.permissions) THEN
						Size(param); code := -1
					ELSE
						code := 550; COPY(NoPermissionMsg, str)
					END
				ELSIF cmd = "REST" THEN
					Strings.StrToInt(param, restMarker);	(* traps on invalid strings *)
					IF (restMarker < 0) THEN restMarker := 0 END;
					state := REST;
					code := 350; COPY(Msg350, str)
				ELSIF cmd = "RETR" THEN
					IF (read IN user.permissions) THEN
						IF (lastState # REST) THEN restMarker := 0 END;
						Retrieve(param, restMarker); code := -1
					ELSE
						code := 550; COPY(NoPermissionMsg, str)
					END
				ELSIF cmd = "STOR" THEN
					IF (write IN user.permissions) THEN
						IF (lastState # REST) THEN restMarker := 0 END;
						Store(param, restMarker); code := -1
					ELSE
						code := 550; COPY(NoPermissionMsg, str)
					END
				ELSIF cmd = "APPE" THEN
					IF (write IN user.permissions) THEN
						Store(param, -1); code := -1
					ELSE
						code := 550; COPY(NoPermissionMsg, str)
					END
				ELSIF cmd = "RNFR" THEN
					IF (write IN user.permissions) THEN
						IF (Strings.Pos(PathDelimiter, param) = -1) THEN	(* path in filename not allowed *)
							GetDirectories(param, tmp, rnfrName);

							IF (Files.Old(rnfrName) # NIL) THEN
								state := RNFR;
								code := 350; COPY("File found, send new name.", str);
							ELSE
								code := 550; Strings.Concat(param, ": file not found.", str)
							END
						ELSE
							code := 550; Strings.Concat(param, ": invalid filename.", str)
						END
					ELSE
						code := 550; COPY(NoPermissionMsg, str)
					END
				ELSIF cmd = "RNTO" THEN
					IF (lastState = RNFR) THEN
						IF (Strings.Pos(PathDelimiter, param) = -1) THEN	(* path in filename not allowed *)
							Files.SplitPath(rnfrName, filename, tmp);
							IF (Strings.Pos(":", filename) = -1) THEN
								Strings.Append(filename, ":");
							ELSE
								Strings.Append(filename, "/");
							END;
							Strings.Append(filename, param);
							Files.Rename(rnfrName, filename, res);
							logEntry.result := res;
							IF (res = 0) THEN
								code := 250; Strings.Concat(param, ": successfully renamed.", str)
							ELSE
								code := 550; Strings.Concat(param, ": renaming failed.", str)
							END
						ELSE
							code := 550; Strings.Concat(param, ": invalid filename.", str)
						END
					ELSE
						code := 530; COPY("Bad sequence of commands.", str)
					END
				ELSIF (cmd = "SITE") THEN
					Strings.UpperCase(param);

					IF (param = "HELP") THEN
						SendString("214-The following SITE commands are recognized (* =>'s unimplemented).");
						SendString(" HELP");
						code := 214; COPY("HELP command successful.", str)
					ELSE
						code := 500; Strings.Concat("SITE ", param, str); Strings.Concat(str, Msg500, str)
					END
				ELSE
					code := 500; Strings.Concat(param, Msg500, str)
				END
			END;
			IF (code > 0) THEN SendMessage(code, str) END;

			IF (code < 200) OR (code >= 300) THEN (* error or positive preliminary/intermediate reply *)
				INC(consecutiveErrors);
				IF (consecutiveErrors = MaxErrors) THEN quit := TRUE END
			ELSE
				consecutiveErrors := 0
			END
		END Execute;

	BEGIN {ACTIVE, SAFE}
		IF ~running THEN
			running := TRUE;
			NEW(timeout); Objects.SetTimeout(timeout, TimeoutHandler, Timeout);
			NEW(pasvTimeout);
			logged := FALSE; quit := FALSE; consecutiveErrors := 0; type := IMAGE;
			dataAdr := client.fip; dataPort := FTPDataPort;	(*default*)
			logEntry.user := ""; logEntry.ip := client.fip; logEntry.pending := FALSE;
			Streams.OpenReader(in, client.Receive); Streams.OpenWriter(out, client.Send);
			SendMessage(220, Msg220);
			LOOP
				ReadCommand(cmd, line);
				IF (in.res # Streams.Ok) THEN EXIT END;
				Execute(cmd, line);
				IF (in.res # Streams.Ok) OR quit THEN EXIT END
			END
		ELSE
			(* trapped & restarted *)
			IF (client.state = TCP.Established) & (out.res = Streams.Ok) THEN
				logEntry.pending := TRUE;
				SendMessage(550, "Server Error")
			END
		END;

		IF (pasvListener # NIL) & (pasvListener.state = TCP.Listen) THEN pasvListener.Close END;
		IncreaseReceived(client.rcvnxt-client.irs); IncreaseSent(client.sndnxt-client.iss);
		IncreaseActive(-1);
		UserLogout(user);
		FlushLog;
		Terminate
	END FTPAgent;

VAR
	Hex: ARRAY 16 OF CHAR;
	ftp : TCPServices.Service;
	users: User;
	shutdown: BOOLEAN; (* shutdown flag *)
	w3cf: Files.File;
	w3cw: Streams.Writer;
	(** statistical counters. #bytes sent/received := NMebiBX * 2**20 + NbytesX *)
	NclientsTotal*, NclientsActive*, NMebiBReceived*, NMebiBSent*, NbytesReceived*, NbytesSent*: LONGINT;

(* --------- statisitcal counter handling --------------*)
PROCEDURE IncreaseSent(delta: LONGINT);
BEGIN {EXCLUSIVE}
	(* wp: delta >= 0 *)
	ASSERT(delta >= 0);
	NbytesSent := NbytesSent + delta;
	NMebiBSent := NMebiBSent + NbytesSent DIV 100000H;
	NbytesSent := NbytesSent MOD 100000H
END IncreaseSent;

PROCEDURE IncreaseReceived(delta: LONGINT);
BEGIN {EXCLUSIVE}
	(* wp: delta >= 0 *)
	ASSERT(delta >= 0);
	NbytesReceived := NbytesReceived + delta;
	NMebiBReceived := NMebiBReceived + NbytesReceived DIV 100000H;
	NbytesReceived := NbytesReceived MOD 100000H
END IncreaseReceived;

PROCEDURE IncreaseActive(delta: LONGINT);
BEGIN {EXCLUSIVE}
	NclientsActive := NclientsActive + delta
END IncreaseActive;

(* ------------- Helper Phunctions ----------------- *)

PROCEDURE IsDigit(ch: CHAR): BOOLEAN;
BEGIN
	RETURN (ch >= "0") & (ch <= "9")
END IsDigit;

PROCEDURE StrToInt(str: ARRAY OF CHAR; VAR val: LONGINT);
VAR i, d: LONGINT; neg: BOOLEAN;
BEGIN
	i := 0;
	WHILE (str[i] # 0X) & (str[i] <= " ") DO INC(i) END;
	IF str[i] = "-" THEN
		neg := TRUE; INC(i);
		WHILE (str[i] # 0X) & (str[i] <= " ") DO INC(i) END
	ELSE neg := FALSE END;
	val := 0;
	WHILE (str[i] # 0X) & (str[i] >= "0") & (str[i] <= "9") DO
		d := ORD(str[i])-ORD("0");
		IF val <= ((MAX(LONGINT)-d) DIV 10) THEN val := 10*val+d ELSE HALT(99) END;
		INC(i)
	END;
	IF neg THEN val := -val END
END StrToInt;

PROCEDURE StrToIntPos(VAR str: ARRAY OF CHAR; VAR i: INTEGER): LONGINT;
VAR noStr: ARRAY 16 OF CHAR;
		j: LONGINT;
BEGIN
	WHILE (str[i] # 0X) & (str[i] <= " ") DO INC(i) END;
	j := 0;
	IF str[i] = "-" THEN
		noStr[j] := str[i];
		INC(j); INC(i);
		WHILE (str[i] # 0X) & (str[i] <= " ") DO INC(i) END
	END;
	WHILE IsDigit(str[i]) DO noStr[j] := str[i]; INC(j); INC(i) END;
	noStr[j] := 0X;
	StrToInt(noStr, j);
	RETURN j
END StrToIntPos;

PROCEDURE SplitPort(parm: ARRAY OF CHAR;  VAR adr: IP.Adr;  VAR port: LONGINT);
	VAR pos: INTEGER; i, n: LONGINT;
BEGIN
	pos := 0;
	FOR i := 0 TO 3 DO n := StrToIntPos(parm, pos); parm[pos] := '.'; INC(pos) END;
	parm[pos-1] := 0X;
	adr := IP.StrToAdr(parm);
	port := StrToIntPos(parm, pos)*256; INC(pos);
	port := port+StrToIntPos(parm, pos)
END SplitPort;


(* Parses the EPRT command *)
PROCEDURE SplitEPRT(param: ARRAY OF CHAR; VAR adr: IP.Adr; VAR port: LONGINT);
VAR
	i: LONGINT;
	protocol: LONGINT;
	tempString: ARRAY 128 OF CHAR;
	j: LONGINT;

BEGIN
	(* read protocol *)
	i := 0;
	WHILE (i < LEN(param)) & (param[i] # "|") DO
		INC(i);
	END;
	IF i < LEN(param) THEN
		protocol := ORD(param[i+1]) - ORD("0");
	END;

	(* parse IP address *)
	i := i+3;
	j := i;
	WHILE (i < LEN(param)) & ((param[i] # "|") & (param[i] # "%")) DO
		INC(i);
	END;
	IF i < LEN(param) THEN
		Strings.Copy(param, j, i-j, tempString);
	END;
	adr := IP.StrToAdr(tempString);

	(* port *)
	IF param[i] = "%" THEN
		WHILE (i < LEN(param)) & (param[i] # "|") DO
			INC(i);
		END;
	END;
	IF i < LEN(param) THEN
		INC(i);
		j := i;
		WHILE (i < LEN(param)) & (param[i] # "|") DO
			INC(i);
		END;
		IF i < LEN(param) THEN
			Strings.Copy(param, j, i-j, tempString);
			StrToInt(tempString, port);
		END;
	END;
END SplitEPRT;


PROCEDURE BinaryTransfer(r: Streams.Reader;  w: Streams.Writer);
VAR buf: ARRAY BufSize OF CHAR; len: LONGINT;
BEGIN
	REPEAT
		r.Bytes(buf, 0, BufSize, len); w.Bytes(buf, 0, len);
	UNTIL r.res # 0;
	w.Update
END BinaryTransfer;

PROCEDURE ASCIITransfer(r: Streams.Reader; w: Streams.Writer);
VAR buf: ARRAY BufSize OF CHAR; i, len: LONGINT; c: CHAR;
BEGIN
	REPEAT
		r.Bytes(buf, 0, BufSize, len);
		i := 0;
		WHILE (i < len) DO
			c := buf[i];
			IF (c = CR) THEN (* ignore CR *)
			ELSIF (c = LF) THEN w.Ln
			ELSE w.Char(c)
			END;
			INC(i)
		END
	UNTIL (r.res # 0);
	w.Update
END ASCIITransfer;

PROCEDURE Code(VAR s: ARRAY OF CHAR): LONGINT;
VAR i: INTEGER; a, b, c: LONGINT;
BEGIN
	a := 0; b := 0; i := 0;
	WHILE s[i] # 0X DO
		c := b; b := a; a := (c MOD 509 + 1) * 127 + ORD(s[i]);
		INC(i)
	END;
	IF b >= 32768 THEN b := b - 65536 END;
	RETURN b * 65536 + a
END Code;

PROCEDURE ComposeDirectory(path, name: ARRAY OF CHAR; VAR res: ARRAY OF CHAR);
VAR
	prefix: Files.Prefix; tmp: ARRAY dirLen OF CHAR; p: LONGINT;
	absolute : BOOLEAN;
BEGIN
	COPY(path, res); absolute :=  PathDelimiter = name[0];
	Strings.TrimRight(res, PathDelimiter);
	Strings.TrimRight(name, PathDelimiter);

	Files.SplitName(name, prefix, tmp);
	IF (prefix # "") OR absolute THEN (* absolute path *)
		COPY(name, res); Strings.TrimLeft(res, PathDelimiter)
	ELSE (* relative path *)
		WHILE (name # "") DO
			p := Strings.Pos(PathDelimiter, name);
			IF (p >= 0) THEN
				Strings.Copy(name, 0, p, tmp);
				Strings.Delete(name, 0, p+1)
			ELSE
				COPY(name, tmp); name[0] := 0X
			END;

			IF (tmp = ".") THEN
			ELSIF (tmp = "..") THEN
				COPY(res, tmp); Strings.TrimRight(tmp, PathDelimiter); Strings.TrimRight(tmp, ":");
				IF (Files.This(tmp) # NIL) THEN (* it's a prefix *)
					COPY("", res)
				ELSE
					Files.SplitPath(res, res, tmp); Strings.TrimRight(res, PathDelimiter)
				END
			ELSE
				IF (res # "") THEN Strings.Append(res, PathDelimiter) END;
				Strings.Append(res, tmp)
			END
		END
	END
END ComposeDirectory;

(** ------------- TCP Service Handling ----------------- *)

PROCEDURE NewFTPAgent(c: TCP.Connection; s: TCPServices.Service): TCPServices.Agent;
VAR a: FTPAgent;
BEGIN
	INC(NclientsTotal); INC(NclientsActive);
	NEW(a, c, s); RETURN a
END NewFTPAgent;

PROCEDURE Start*(context : Commands.Context); (** ["\l:" log file] *)
VAR c, opt: CHAR; str, log: ARRAY 1024 OF CHAR;	res : WORD;
BEGIN
	IF ftp = NIL THEN
		COPY(LogFile, log);
		context.arg.SkipWhitespace;
		LOOP
			c := context.arg.Get();
			IF (c # "\") THEN EXIT END;

			opt := CAP(context.arg.Get());
			c := context.arg.Get();
			IF (c # ":") THEN EXIT END;

			context.arg.SkipWhitespace;
			context.arg.String(str);
			context.arg.SkipWhitespace;

			CASE opt OF
			| "L": COPY(str, log)
			ELSE EXIT
			END
		END;

		LoadUsers(users);
		shutdown := FALSE;
		NclientsTotal := 0; NclientsActive := 0; NbytesReceived := 0; NbytesSent := 0;
		OpenW3CLog(log);
		NEW(ftp, FTPControlPort, NewFTPAgent, res);
		IF (res = TCPServices.Ok) THEN
			KernelLog.Enter; KernelLog.String("WebFTPServer started"); KernelLog.Exit;
			context.out.String("WebFTPServer started"); context.out.Ln;
		ELSE
			context.error.String("WebFTPServer not started, res: "); context.error.Int(res, 0); context.error.Ln;
		END;
	ELSE
		context.out.String("WebFTPServer is already running."); context.out.Ln;
	END;
END Start;

PROCEDURE Stop*(context : Commands.Context);
BEGIN
	IF ftp # NIL THEN
		shutdown := TRUE;
		ftp.Stop; ftp := NIL;
		KernelLog.Enter; KernelLog.String("WebFTPServer closed"); KernelLog.Exit;
		IF (context # NIL) THEN context.out.String("WebFTPServer closed."); context.out.Ln; END;
	ELSE
		IF (context # NIL) THEN context.out.String("WebFTPServer is not running."); context.out.Ln; END;
	END;
END Stop;

(** ------------- User Handling ----------------- *)

(** Adds a user to the user file. Syntax:
	Aos.Call FTPServer.AddUser <name> <password> <max concurrent logins> <permissions> [<root>] ~

		name = string, may not contain spaces
		password = string, must be enquoted if it contains spaces
		max concurrent logins = integer. if = -1 then any number of concurrent logins are allowed
		permissions = ["R"]["W"]["P"["M"]];
			R = user has read permissions
			W = user has write permissions
			P = user must supply a password
			M = password is an e-mail address
		root = valid file system prefix, may include a path (if it does, do not forget the trailing backslash!)
*)
PROCEDURE AddUser*(context : Commands.Context);
VAR
	username, permissions: ARRAY nameLen OF CHAR; root: ARRAY dirLen OF CHAR;
	password: ARRAY pwdLen+1 OF CHAR;
	user: User; i, maxlogins: LONGINT;
BEGIN {EXCLUSIVE}
	context.arg.SkipWhitespace;
	context.arg.Token(username); context.arg.SkipWhitespace;
	context.arg.String(password); context.arg.SkipWhitespace;
	context.arg.Int(maxlogins, FALSE); context.arg.SkipWhitespace;
	context.arg.Token(permissions); context.arg.SkipWhitespace;
	context.arg.String(root);

	IF (username # "") & (password # "") & (maxlogins # 0) & (permissions # "") THEN
		IF (FindUser(username) = NIL) THEN
			NEW(user);
			COPY(username, user.name); user.password := Code(password); user.maxlogins := maxlogins;
			user.permissions := {}; COPY(root, user.root);

			i := 0;
			WHILE (permissions[i] # 0X) DO
				IF (CAP(permissions[i]) = "R") THEN INCL(user.permissions, read)
				ELSIF (CAP(permissions[i]) = "W") THEN INCL(user.permissions, write)
				ELSIF (CAP(permissions[i]) = "P") THEN INCL(user.permissions, passwrq)
				ELSIF (CAP(permissions[i]) = "M") THEN INCL(user.permissions, mailpwd)
				ELSE
					context.error.String("AddUser: Invalid permissions"); context.error.Ln;
					RETURN;
				END;
				INC(i)
			END;

			user.next := users; users := user;
			StoreUsers(users, context);

			context.out.String(moduleName); context.out.String("User '"); context.out.String(username);
			context.out.String("' added. Max concurrent logins = ");
			IF (user.maxlogins < 0) THEN context.out.String("unlimited") ELSE context.out.Int(user.maxlogins, 0) END;
			context.out.String("; permissions = "); context.out.String(permissions); context.out.String(", root = '"); context.out.String(root);
			context.out.Char("'"); context.out.Ln;
		ELSE
			context.error.String(moduleName); context.error.String("User '"); context.error.String(username); context.error.String("' already exists.");
			context.error.Ln;
		END
	ELSE
		context.error.String(moduleName);
		context.error.String("Expected parameters: <username> <password> <maxlogins> <permissions>"); context.error.Ln;
	END;
END AddUser;

(** Removes a user from the user file. Syntax:
	Aos.Call FTPServer.RemoveUser <name>  ~

		name = string, may not contain spaces
*)

PROCEDURE RemoveUser*(context : Commands.Context);
VAR prev, u: User; name: ARRAY nameLen OF CHAR; nofRemovals : LONGINT;
BEGIN {EXCLUSIVE}
	context.arg.SkipWhitespace; context.arg.Token(name);
	IF (name # "") THEN
		context.out.String(moduleName); context.out.String("Removing user '"); context.out.String(name); context.out.String("'... ");
		context.out.Update;
		nofRemovals := 0;
		u := users; prev := NIL;
		WHILE (u # NIL) DO
			IF (u.name = name) THEN
				INC(nofRemovals);
				IF (prev = NIL) THEN users := u.next
				ELSE prev.next := u.next
				END
			END;
			prev := u; u := u.next
		END;
		IF (nofRemovals = 1) THEN
			context.out.String("done.");
		ELSIF (nofRemovals > 1) THEN
			context.out.String(" removed "); context.out.Int(nofRemovals, 0); context.out.String(" times, done.");
		ELSE
			context.out.String(" user not found.");
		END;
		context.out.Ln;
		StoreUsers(users, context)
	ELSE
		context.error.String("RemoveUser: invalid parameters"); context.error.Ln;
	END;
END RemoveUser;

PROCEDURE ListUsers*(context : Commands.Context);
VAR user: User;
BEGIN {EXCLUSIVE}
	context.out.String(moduleName); context.out.String("Registered users:"); context.out.Ln;
	IF (users # NIL) THEN
		user := users;
		WHILE (user # NIL) DO
			context.out.String("  "); context.out.String(user.name);
			IF (passwrq IN user.permissions) THEN context.out.String("; password-protected login") END;
			IF (mailpwd IN user.permissions) THEN context.out.String("; password = e-mail address") END;
			context.out.Ln;
			context.out.String("    currently active: "); context.out.Int(user.currentlogins, 0);
			context.out.String("; max logins: ");
			IF (user.maxlogins < 0) THEN context.out.String("unlimited") ELSE context.out.Int(user.maxlogins, 0) END;
			context.out.Ln;
			context.out.String("    root = '"); context.out.String(user.root); context.out.String("'; permissions: ");
			IF (read IN user.permissions) THEN context.out.Char("R") END;
			IF (write IN user.permissions) THEN context.out.Char("W") END;
			context.out.Ln;
			user := user.next
		END
	ELSE
		context.out.String("no users"); context.out.Ln;
	END;
END ListUsers;

PROCEDURE LoadUsers(VAR users: User);
VAR u: User; f: Files.File; r: Files.Reader;
BEGIN
	users := NIL;
	f := Files.Old(UserFile);
	IF (f # NIL) THEN
		Files.OpenReader(r, f, 0);
		WHILE (r.res = Streams.Ok) DO
			NEW(u);
			r.RawString(u.name); r.RawLInt(u.password); r.RawLInt(u.maxlogins);
			r.RawSet(u.permissions); r.RawString(u.root);
			IF (r.res = Streams.Ok) THEN
				u.next := users;
				users := u
			END
		END
	END
END LoadUsers;

PROCEDURE StoreUsers(users: User; context : Commands.Context);
VAR f: Files.File; w: Files.Writer;
BEGIN
	f := Files.New(UserFile);
	IF (f # NIL) THEN
		Files.OpenWriter(w, f, 0);
		WHILE (w.res = Streams.Ok) & (users # NIL) DO
			w.RawString(users.name); w.RawLInt(users.password); w.RawLInt(users.maxlogins);
			w.RawSet(users.permissions); w.RawString(users.root);
			users := users.next
		END;
		IF (w.res = Streams.Ok) THEN
			w.Update;
			Files.Register(f)
		END
	ELSE
		context.error.String(moduleName); context.error.String("can't write user file"); context.error.Ln;
	END
END StoreUsers;

PROCEDURE FindUser(name: ARRAY OF CHAR): User;
VAR u: User;
BEGIN
	u := users;
	WHILE (u # NIL) & (u.name # name) DO u := u.next END;
	RETURN u
END FindUser;

PROCEDURE UserLogin(user: User): BOOLEAN;
BEGIN {EXCLUSIVE}
	IF (user # NIL) & ((user.currentlogins < user.maxlogins) OR (user.maxlogins = -1)) THEN
		INC(user.currentlogins);
		RETURN TRUE
	ELSE
		RETURN FALSE
	END
END UserLogin;

PROCEDURE UserLogout(user: User);
BEGIN {EXCLUSIVE}
	IF (user # NIL) THEN
		IF (user.currentlogins > 0) THEN
			DEC(user.currentlogins)
		ELSE
			KernelLog.Enter; KernelLog.String(moduleName); KernelLog.String("warning: user count <= 0. user: "); KernelLog.String(user.name);
			KernelLog.String("; #active: "); KernelLog.Int(user.currentlogins, 0); KernelLog.Exit
		END
	END
END UserLogout;

(* ------------- Logging ----------------- *)
PROCEDURE OpenW3CLog(fn: ARRAY OF CHAR);
VAR w : Files.Writer;
BEGIN
	w3cf := Files.Old(fn);
	IF w3cf = NIL THEN
		w3cf := Files.New(fn);
		IF (w3cf # NIL) THEN
			Files.OpenWriter(w, w3cf, 0);
			w.String("#Version: 1.0"); w.Ln;
			w.String("#Fields: date"); w.Char(Tab);
			w.String("time"); w.Char(Tab);
			w.String("x-user"); w.Char(Tab);
			w.String("c-ip"); w.Char(Tab);
			w.String("cs-method"); w.Char(Tab);
			w.String("cs-uri"); w.Char(Tab);
			w.String("sc-status"); w.Char(Tab);
			w.String("x-result");
			w.Ln;
			w.Update;
			Files.Register(w3cf)
		ELSE
			KernelLog.Enter; KernelLog.String(moduleName); KernelLog.String("cannot open log file '"); KernelLog.String(fn); KernelLog.Char("'"); KernelLog.Exit
		END
	ELSE
		Files.OpenWriter(w, w3cf, w3cf.Length())
	END;
	w3cw := w;
END OpenW3CLog;

PROCEDURE W3CLog(e: LogEntry);
VAR s: ARRAY 36 OF CHAR;

	PROCEDURE ToURI(ascii: ARRAY OF CHAR; VAR uri: ARRAY OF CHAR); (* cf. RFC 1738 *)
	VAR i,k,l: LONGINT; c: CHAR;
	BEGIN
		i := 0; k := 0; l := LEN(uri)-1;
		WHILE (k < l) & (ascii[i] # 0X) DO
			c := ascii[i];
			IF (("A" <= CAP(c)) & (CAP(c) <= "Z")) OR (("0" <= c) & (c <= "9")) OR
				(c = "$") OR (c = "-") OR (c = "_") OR (c = ".") OR (c = "+") OR
				(c = "!") OR (c = "*") OR (c = "'") OR (c = "(") OR (c = ")") OR (c = ",")
			THEN
				uri[k] := c; INC(k)
			ELSIF (k < l-2) THEN
				uri[k] := "%"; INC(k);
				uri[k] := Hex[ORD(c) DIV 10H]; INC(k);
				uri[k] := Hex[ORD(c) MOD 10H]; INC(k)
			ELSE
				ascii[i+1] := 0X	(* abort, uri too short *)
			END;
			INC(i)
		END;
		uri[k] := 0X
	END ToURI;

BEGIN {EXCLUSIVE}
	IF (w3cf = NIL) THEN RETURN END;
	Strings.FormatDateTime("yyyy-mm-dd", Dates.Now(), s);
	w3cw.String(s); w3cw.Char(Tab);
	Strings.FormatDateTime("hh:nn:ss", Dates.Now(), s);
	w3cw.String(s); w3cw.Char(Tab);
	w3cw.String(e.user); w3cw.Char(Tab);
	IP.AdrToStr(e.ip, s);
	w3cw.String(s); w3cw.Char(Tab);
	w3cw.String(e.method); w3cw.Char(Tab);
	ToURI(e.uri, e.uri);
	w3cw.String(e.uri); w3cw.Char(Tab);
	Strings.IntToStr(e.status, s);
	w3cw.String(s);  w3cw.Char(Tab);
	Strings.IntToStr(e.result, s);
	w3cw.String(s);
	w3cw.Ln
END W3CLog;

PROCEDURE FlushLog*;
BEGIN {EXCLUSIVE}
	IF (w3cf # NIL) THEN
		w3cw.Update; w3cf.Update
	END
END FlushLog;

PROCEDURE Cleanup;
BEGIN
	Stop(NIL);
END Cleanup;

BEGIN
	Hex[0] := "0"; Hex[1] := "1"; Hex[2] := "2"; Hex[3] := "3";
	Hex[4] := "4"; Hex[5] := "5"; Hex[6] := "6"; Hex[7] := "7";
	Hex[8] := "8"; Hex[9] := "9"; Hex[10] := "A"; Hex[11] := "B";
	Hex[12] := "C"; Hex[13] := "D"; Hex[14] := "2"; Hex[15] := "E";
	Modules.InstallTermHandler(Cleanup)
END WebFTPServer.


Aos.Call WebFTPServer.Start ~\l:FAT:/logs/FTP.Log~
Aos.Call WebFTPServer.Stop
NetTracker.CloseAll
System.Free WebFTPServer ~
ET.OpenAscii FTP.Log ~


Aos.Call WebFTPServer.AddUser user password -1 rwp  FAT:~
Aos.Call WebFTPServer.AddUser anonymous none 3 rwpm FAT:/ftproot/ ~
Aos.Call WebFTPServer.RemoveUser begger ~
Aos.Call WebFTPServer.ListUsers

System.DeleteFiles WebFTPUsers.dat ~  	deletes all users
