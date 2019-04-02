(* Aubrey McIntosh, Ph.D.  Jan 21, 2003
 *	This code may be distributed under the same terms and conditions as the Bluebottle operating system
 *	from ETH, Zürich.
 *
 *	RFC 821 Receiver module.  Listen on port 25, put messages and envelopes into files.
 *
 *	Hand modified Coco-R output.
 *	The scanner differs from the Coco provided scanner.
 *
 *	This code is a result of hand merging a working but poorly designed prototype,
 *	AosSMTPReceiver1.Mod, and the Coco output.
 *
 *	Jan 21, 2003 21:53 CST:	The merge is essentially complete, the scanner has not been
 *	written, a code walk through has not been done. i.e. major omissions may exist.
 *	Jan 23, 2003 16:35 CST:	Accepted first message.
 *	Jan 25, 2003  20:00:  Have log files.  Capture raw data sendmail sends here.
 *	Jan 26, 2003  20:00:  Place onto alternate path:  FAT:/Mail/<message name>
 *	Feb 1, 2003	0.1.28	Add Logging: flood of connections from 160.94.128.45
 *    Feb 11, 2003 0.1.29  Test whether DNS extension is on name when writing message id.
 *    Feb 18, 2003 0.1.33  Limit total number of connections.  Place diagnostics in log.
 *		accept core.inf.ethz.ch always.
 *	Feb 19, 2003 0.1.34	Add diagnostic test for EOF condition.
 *		0.1.38	Fix error where 1st of many messages is dropped (overwritten?)
 *	Feb 23, 2003
 *		0.1.40	Reconcile behavior of emwac and the .Rcp file format.
 *	Mar 16, 2003
 *		0.1.41	Make file name initialization more robust.
 *    Mar 31, 2003  The program seems to hang if the remote sender does not issue QUIT.
 *    Jan 3, 2004  Name changed to AlmSMTPReceiver for release to BlueBottle community.
 *        Changes 0.1.42 appear lost in move.
 *	Sept 21, 2004	Initialise config file on first execution.  Use AOS filesystem names.

 (* Initial SMTP handshake *)
		BEGIN {EXCLUSIVE}
			TakeNumber;
			AdvanceNumber
		END;
		OpenLog;
		LOOP	(*Parse SMTP*)
			OpenMail;
			IF Finished THEN EXIT END
			BEGIN {EXCLUSIVE}
				TakeNumber;
				AdvanceNumber
			END
		END

 *
 *
 *	To Do:
 *		Make robust.  E.g. HALT is not good error recovery.
 *		Integrate with Frey's Abstract Mail
 *		Produce message and broadcast mechanism.  E.g., for use in poping up display when VIP
 *			sends message.
 *
 *)

MODULE AlmSmtpReceiver;

IMPORT DNS, Files, Streams, IP, Modules, KernelLog, TCP, TCPServices, Dates, Strings;

CONST
(* Some of the configurable items. *)
	AlmSmtpReceiverPort = 25; (* Well, semi-configurable. *)

	MaxActive = 3+1;
	ID = "BlueBottle Receiver ";
	Version = "MailBottle (0.2.00.16)";
	Rcp = ".Rcp";
	Msg = ".Msg";
	Log = ".Log";
	ConfigFileName = "mail.config";
	ToDisk = TRUE; (* Debug *)
	DebugMsg = FALSE;
	RcptInFileName = TRUE;
	MaxUserName = 11;
	Prefix = "In."; (*Administer must create this manually.*)
	AlwaysAccept = "129.132.178.196";

(* End of these configurable items. *)

(* Constants for the Scanner *)
CONST
	EOF = 0X;
	maxLexLen = 127;
	noSym = 13;
(* Types for the Scanner *)
TYPE
	ErrorProc* = PROCEDURE (n: INTEGER);
	StartTable = ARRAY 128 OF INTEGER;
(* Variables for the Scanner *)
VAR
	errors*: INTEGER;	(*number of errors detected*)
	lasterror* : INTEGER;
	charcount : LONGINT;
	getCalls : LONGINT;
	start: StartTable;	(*start state for every character*)
	Pattern, Ack : ARRAY 6 OF CHAR;
	active : LONGINT;

CONST
	maxP				= 13;
	maxT				= 13;
	nrSets = 3;

	setSize = 32;	nSets = (maxT DIV setSize) + 1;

	SyEol	= 1;
	SyCopy	= 2;
	SyHelo	=3;
	SyQuit	=4;
	SyNoop	=5;
	SyRset	=6;
	SyData	=7;
	SyDot	=8;
	SyRcpt	=9;
	SyTo	=10;
	SyMail	=11;
	SyFrom	=12;
	SyTimeout = 14;

	Tab = 09X;
	LF = 0AX;
	CR = 0DX;

TYPE
	SymbolSet = ARRAY nSets OF SET;


TYPE
	String = ARRAY 128 OF CHAR;
	TokenPtr = POINTER TO Token;
	Token = RECORD s : String; next : TokenPtr END;
	EnvelopePtr = POINTER TO Envelope;
	Envelope = RECORD
			mta, revMta, from : String;
			to : TokenPtr;
		END;

	Message* = RECORD env* : EnvelopePtr; file* :Files.File; END;

	SmtpAgent* = OBJECT (TCPServices.Agent)
	VAR
			ch: CHAR;				(*current input character*)
			res: WORD;
			out: Streams.Writer; in: Streams.Reader;
			log : Files.Writer;
			env : Envelope;
			thisName, verbSy : String;
			finished : BOOLEAN;
			sym: INTEGER;	 (* current input symbol *)
			state : INTEGER;
			badTokens : LONGINT;
			auxString : String;

	(* Support procedures *)
	PROCEDURE GetCh():CHAR;
	VAR ch : CHAR;
	BEGIN
		ch := in.Get();
		log.Char (ch); log.Update;
		RETURN ch
	END GetCh;

	PROCEDURE ConsumeName;
	BEGIN {EXCLUSIVE}
				COPY (nextName, thisName);
				UpdateName (nextName)
	END ConsumeName;

	PROCEDURE AvailableName;
	VAR
		name : String;
		msgFile: Files.File;
	BEGIN
		COPY (Prefix, name);
		AddExt (name, thisName);
		AddExt (name, Log);
		WHILE (Files.Old (name) # NIL)
		DO
			ConsumeName;
			COPY (Prefix, name);
			AddExt (name, thisName);
			AddExt (name, Log);
			msgFile := Files.Old (name);
		END;
	END AvailableName;

	PROCEDURE OpenLog; (*1 file per session.  Name is same as when session opens, i.e., not agree w/ .Msg & .Rcp *)
	VAR
		msgFile: Files.File;
		name : String;
	BEGIN
		COPY (Prefix, name);
		AddExt (name, thisName);
		AddExt (name, Log);
		msgFile := Files.Old (name);
		ToLog0 ("before search."); KernelLog.Exit;
		WHILE msgFile # NIL
		DO
			ToLog0 ("during search."); KernelLog.String (name); KernelLog.Exit;
			ConsumeName;
			COPY (Prefix, name);
			AddExt (name, thisName);
			AddExt (name, Log);
			msgFile := Files.Old (name);
		END;
		ToLog0 ("after search."); KernelLog.Exit;
		msgFile := Files.New (name);
		Files.OpenWriter ( log, msgFile, 0);
		Files.Register (msgFile);
	END OpenLog;

	PROCEDURE ToMemory* (VAR token: ARRAY OF CHAR);
	VAR maxix, ix : LONGINT; trash, next : CHAR;
	BEGIN
		next := in.Peek();
		WHILE (next=" ") OR (next=Tab) DO trash := GetCh (); INC (charcount); next := in.Peek() END;
		maxix := LEN (token)-1;
		WHILE (next#" ") & (next#Tab) & (next#CR) & (next#LF)
		DO
			ch := GetCh (); INC (charcount); next := in.Peek(); (* Jan 23, 2003 v. 0.1.02 *)
			IF ix < maxix
			THEN
				token [ix] := ch;
				INC (ix)
			END
		END;
		token [ix] := 0X;
		Expect (SyCopy)
	END ToMemory;

	PROCEDURE DebugMsg1* (msg : ARRAY OF CHAR);
	BEGIN
		IF DebugMsg
		THEN
			out.String (msg);
			out.Ln;
			out.Update()
		END
	END DebugMsg1;

	PROCEDURE PutStatus1* (msg : ARRAY OF CHAR);
	BEGIN
		Confirm(SyEol);	(*Expect is split to a Confirm / Get pair to let the output occur.*)
		out.String (msg);
		out.Ln;
		out.Update();
		Get
	END PutStatus1;

	PROCEDURE ChangeStatus1* (newsym : INTEGER; msg : ARRAY OF CHAR);
	BEGIN
		Confirm(SyEol);
		sym := newsym;
		out.String (msg);
		out.Ln;
		out.Update();
	END ChangeStatus1;

	PROCEDURE PutStatus2* (msg0, msg1 : ARRAY OF CHAR);
	BEGIN
		Confirm(SyEol);	(*Expect is split to a Confirm / Get pair to let the output occur.*)
		out.String (msg0);
		out.String (msg1);
		out.Ln;
		out.Update;	(* ignore out.res *)
		Get
	END PutStatus2;

	PROCEDURE ChangeStatus2* (newsym : INTEGER; msg0, msg1 : ARRAY OF CHAR);
	BEGIN
		Confirm(SyEol);
		sym := newsym;
		out.String (msg0);
		out.String (msg1);
		out.Ln;
		out.Update;	(* ignore out.res *)
	END ChangeStatus2;

	PROCEDURE AddExt* ( VAR name : String; ext : ARRAY OF CHAR);
		VAR i, j, skipped : INTEGER;
	BEGIN
		i := 0;
		WHILE ( i < LEN(name)-1 ) & ~(name[i] < " ")
		DO
			INC (i)
		END;
		j := 0; skipped := 0;
		WHILE ( i+j < LEN(name)-1 ) & (j<LEN(ext)-1) & (ext[j] # 0X)
		DO
			IF (ext[j] = "<") OR (ext[j] = ">")
			THEN
				INC (j); INC (skipped)
			ELSE
				name[i+j-skipped] := ext[j];
				INC (j)
			END;
		END;
		name[i+j] := 0X
	END AddExt;

	PROCEDURE PutBareName ( name : String; VAR wr : Files.Writer );
		VAR ix : LONGINT; ch : CHAR;
	BEGIN
		ix := 0;
		WHILE (ix<LEN(name)) & (name[ix]#0X)
		DO
			ch := name [ix];
			IF (ch#"<") & (ch#">") THEN wr.Char (ch) END;
			INC (ix)
		END
	END PutBareName;

	PROCEDURE PutEnvelope ( (* not VAR! *) name : String );
	VAR envF : Files.File; ew : Files.Writer; to: TokenPtr;
		msgName, rcpPathName : String;
	BEGIN
		COPY (name, msgName);
		(*
		AddExt (msgName, "@");
		AddExt (msgName, NetSystem.hostName);
		AddExt (msgName, ".");
		AddExt (msgName, DNS.domain);
		 *)

		COPY (Prefix, rcpPathName);
		AddExt (rcpPathName, name); (*alm 9/21/2004*)
		AddExt (rcpPathName, Rcp); (*Name with no prefix*)

		envF := Files.New (rcpPathName);
		(*A trap sometimes happens when here:
		Process:  354 run 0 3 01F159B0:AlmSmtpReceiver.SmtpAgent ATADisks.Interrupt.Wait pc=815 {}

		*)
		Files.OpenWriter ( ew, envF, 0);

		ew.String ("Message-ID: <");
		ew.String (msgName);
		(*
		ew.Char ("@");
		ew.String (DNS.domain);
		*)
		ew.Char (">");
		ew.Ln;

		ew.String ("Return-path: ");
		PutBareName (env.from, ew);
		ew.Ln;

		to := env.to;
		WHILE to # NIL DO
			ew.String ("Recipient: ");
			PutBareName (to.s, ew);
			to := to.next;
			ew.Ln;
		END;

		ew.Update;
		Files.Register (envF);
	END PutEnvelope;

	PROCEDURE UpdateName (VAR s : String);
	VAR i : INTEGER; ch : CHAR; carry : INTEGER;
	BEGIN
		i := 10; (* 10 digits significant in name *)
		carry := 1;
		WHILE (1<=i) & (carry = 1) DO
			ch := CHR (ORD(s[i]) + carry);
			IF '9' < ch
			THEN
				ch := "0";
				carry := 1
			ELSE
				carry := 0
			END;
			s[i] := ch;
			DEC (i)
		END
	END UpdateName;


	(* Begin Parser Productions *)
	PROCEDURE HELO*;
		VAR res : WORD;
	BEGIN
		Confirm(SyHelo);
		sym := SyCopy; ToMemory (env.mta);
		DNS.HostByNumber (SELF.client.fip, env.revMta, res);
		PutStatus2 ("250 Your email is welcome here, ", env.mta);
	END HELO;

	PROCEDURE RSET*;
	BEGIN
		Expect(SyRset);
		env.mta	:= ""; env.from := ""; env.to := NIL;
		PutStatus1 ("250 Requested mail action okay, completed.");
	END RSET;

	PROCEDURE NOOP*;
	BEGIN
		Expect(SyNoop);
		PutStatus1 ("250 Requested mail action okay, completed.");
	END NOOP;

	PROCEDURE QUIT*;
	BEGIN
		Expect(SyQuit);
		finished := TRUE;
		ChangeStatus1 (SyQuit, "221 Goodbye.."); (*Avoid executing another Get.*)
		client.Close();
	END QUIT;

	PROCEDURE RCPT*;
	VAR to : TokenPtr;
	BEGIN
		Expect(SyRcpt);
		Confirm(SyTo);
		NEW (to);
		sym := SyCopy; ToMemory (to.s);
		to.next := env.to; env.to := to;
		PutStatus2 ("250 Recipient okay:  ", to.s);
	END RCPT;

	PROCEDURE Test;
	BEGIN
		IF in.Available() < 1
		THEN HALT( 44 )
		END
	END Test;

	PROCEDURE ToFile(name : String);
	VAR
		msg: Files.File;
		msgWr : Files.Writer;
		ix, testIx : LONGINT;
		receiveTime, remoteIP : String;

		PROCEDURE WriteIPNr( ip : IP.Adr );
			VAR result : WORD; str : ARRAY 128 OF CHAR;
		BEGIN
					IP.AdrToStr(ip, remoteIP);
					msgWr.String (" (");
					msgWr.String (remoteIP);
					DNS.HostByNumber (ip, str, result);
					msgWr.String (" --> ");
					IF result = DNS.Ok
					THEN
						msgWr.String (str)
					ELSE
						msgWr.String ("lookup failed.")
					END;
					msgWr.Char (")");
		END WriteIPNr;

	BEGIN
		AddExt (name, Msg);
		IF ToDisk THEN
			msg := Files.New (name);
			Files.OpenWriter ( msgWr, msg, 0);
			ToLog0 (name);
			KernelLog.Exit;
			Strings.FormatDateTime("www, dd mmm yyyy hh:nn:ss -0600 (CST)", Dates.Now(), receiveTime);
			msgWr.String ("Received: ");
			msgWr.Ln; msgWr.Char (Tab); msgWr.String ("from ");
				msgWr.String (env.mta);
				WriteIPNr(SELF.client.fip);
			msgWr.Ln; msgWr.Char (Tab); msgWr.String ("by ");
				msgWr.String (DNS.domain);
				WriteIPNr(SELF.client.int.localAdr);
			msgWr.Ln; msgWr.Char (Tab);
			msgWr.String ("with ");
			msgWr.String (Version);
			msgWr.String (" id "); msgWr.String (thisName);
				msgWr.Char ("@"); msgWr.String (DNS.domain);
			msgWr.Ln; msgWr.Char (Tab); msgWr.String ("for ");
				 msgWr.String (env.to.s);
			msgWr.Char (Tab); msgWr.String (";  "); msgWr.String (receiveTime);
			msgWr.Ln
		END;
		ch := GetCh (); INC (charcount); (* Read first v 0.1.02 *)
		testIx := 0;
		LOOP
			IF in.res = Streams.EOF
			THEN
				ToLog0 ("EOF on input stream."); KernelLog.Exit; sym := SyEol; EXIT
			END;
			IF ch=Pattern[0]
			THEN
				LOOP
					ch := GetCh (); INC (charcount);
					testIx := 1;
					WHILE (testIx <= 4) & (ch=Pattern[testIx])
					DO
						IF testIx < 4
						THEN
							ch := GetCh ();
							INC (charcount);
						END;
						INC (testIx)
					END;
					IF DebugMsg
					THEN
						FOR ix := 0 TO testIx-1
						DO
							out.Char (Ack[ix])
						END;
						out.Update
					END;
					IF testIx=5
					THEN
						msgWr.Char (CR); msgWr.Char (LF);
						sym := SyEol; (*Have read both "." and CR/LF*)
					ELSE
						FOR ix := 0 TO testIx-1
						DO
							msgWr.Char (Pattern[ix])
						END;
						(* msgWr.Char (ch); *)
						(* testIx := 0 *)
					END;
					EXIT
				END;
				IF testIx=5 THEN EXIT END
			ELSE
				msgWr.Char (ch)
			END;
			IF testIx#0 THEN testIx := 0 (*Start test again at current character.*) ELSE ch := GetCh (); INC (charcount) END
		END ;
		IF DebugMsg THEN out.Char ("!"); out.Update END;
		IF ToDisk THEN msgWr.Update END;
		IF ToDisk THEN Files.Register (msg) END
	END ToFile;

	PROCEDURE DATA* (name : String);
	BEGIN
		Expect(SyData);
		ChangeStatus1 (SyCopy, "354 Send message now, end with CRLF . CRLF");
		sym := SyCopy; ToFile (name);
		Confirm(SyEol);
	END DATA;

	PROCEDURE AddUserToName (VAR thisName : String);
	VAR
		pos : INTEGER;
	BEGIN
			IF RcptInFileName
			THEN
				AddExt ( thisName, "."); (*Preparation for mailbox-in-name interpretation.*)
				pos := 0;
				WHILE (pos < LEN (thisName)) & (thisName [pos] # 0X) DO INC (pos) END;
				AddExt ( thisName, env.to.s); (*Preparation for mailbox-in-name interpretation.*)
				thisName [pos + MaxUserName] := 0X;

				WHILE (pos < LEN (thisName)) & (thisName [pos] # "@")
				DO
					INC (pos)
				END;
				IF pos < LEN (thisName)  THEN thisName [pos] := 0X END;
			END;
	END AddUserToName;

	PROCEDURE MAIL*;
	VAR
		to : TokenPtr;
		pathName : String;
		localSym : INTEGER;	(*to debug*)
	BEGIN
		Expect(SyMail);
		env.from := ""; env.to := NIL;
		Confirm(SyFrom);
		sym := SyCopy; ToMemory (env.from);
		PutStatus2 ("250 Sender okay. ", env.from);
		NEW( to );
		IF StartOf(1) THEN
			reset; IF finished THEN RETURN END;
		ELSIF (sym = SyRcpt) THEN
			RCPT;
			WHILE (sym = SyRcpt) DO
				RCPT;
			END ;
			AddUserToName (thisName);
			COPY (Prefix, pathName);
			AddExt (pathName, thisName);
			AddExt (pathName, Rcp);

			(* alm 3/16/2003 Skips previously used names. *)
			WHILE (Files.Old (pathName) # NIL)
			DO
				ConsumeName;
				AddUserToName (thisName);
				COPY (Prefix, pathName);
				AddExt (pathName, thisName);
				AddExt (pathName, Rcp);
			END;
			COPY (Prefix, pathName);
			AddExt (pathName, thisName);

			IF StartOf(1)	THEN
				reset;
				ToLog0 ("Post RCPT cmd in mail.");
				KernelLog.Exit;
				IF finished THEN RETURN END;
			ELSIF (sym = SyData) THEN
				ToLog0 ("Data cmd in mail.");
				KernelLog.Exit;
				DATA (pathName);
			ELSE Error1(14)
			END ;
		ELSE Error1(15)
		END ;
		PutEnvelope (thisName);
		IF DebugMsg THEN out.Char ("@"); out.Update END;
		localSym := SELF.sym;
		PutStatus2 ("250 Your confirmation number is ", thisName);

		(*  Feb. 22, 2003 *)
		CASE sym OF
			SyQuit : ToLog0 ("Quit detected.")
			| SyMail : ToLog0 ("Mail detected.")
			| SyRset : ToLog0 ("Rset detected.")
			| SyNoop : ToLog0 ("Noop detected.")
			| SyEol : ToLog0 ("dead connection detected.")
		ELSE
			ToLog0 ("Unexpected path in case statement.")
		END;
		KernelLog.Exit;

		IF sym IN {SyMail, SyRset, SyNoop} (*Noop DOES allow more mail in this session.*)
		THEN
			ToLog0 ("update name.");
			ConsumeName;
			KernelLog.Exit
		(* PutRegistry (nextName) *)
		ELSE
			ToLog0 ("Keep existing name.");
			KernelLog.Exit;
			RETURN
		END
	END MAIL;

	PROCEDURE reset;
	BEGIN
		DebugMsg1 ("Entering reset.");
		IF (sym = SyHelo) THEN HELO;
		ELSIF (sym = SyNoop) THEN NOOP;
		ELSIF (sym = SyRset) THEN RSET;
		ELSIF (sym = SyMail) THEN MAIL;
		ELSE Error1(16)
		END ;
		DebugMsg1 ("Exiting reset.")
	END reset;

	PROCEDURE Get;
	BEGIN
		INC (getCalls);
		ch := GetCh (); INC (charcount); (*No characters in buffer on entry.*)
		WHILE (ch=" ") OR (ch=Tab) DO ch := GetCh (); INC (charcount) END;
		IF ch > 7FX THEN ch := " " END;
		IF ("a"<=ch) & (ch<="z") THEN ch := CAP (ch) END;
		state := start[ORD(ch)];
		(*Intercept single character symbols to avoid read-ahead*)
		CASE state OF
			24: sym := SyDot; RETURN
		|	3: IF (CAP(in.Peek()) ="R") THEN (* state := 35; (*does not block across CR LF on legal input.*) *)
					ELSE sym := SyCopy; RETURN
					END;
		ELSE (* Continue with multi character symbols. *)
		END;
		LOOP
			ch := GetCh (); INC (charcount);
			IF ("a"<=ch) & (ch<="z") THEN ch := CAP (ch) END;
			IF state > 0 THEN
				CASE state OF
			|	1: IF (ch=LF) THEN state := 2; sym := SyEol; RETURN
						ELSE sym := noSym; RETURN
						END;
			|	2: HALT (52) (*Avoid look ahead character read*)
			|	3: IF (ch ="R") THEN state := 35;
						ELSE sym := SyCopy; RETURN
						END;
			|	4: IF (ch ="E") THEN state := 5;
						ELSE sym := noSym; RETURN
						END;
			|	5: IF (ch ="L") THEN state := 6;
						ELSE sym := noSym; RETURN
						END;
			|	6: IF (ch ="O") THEN state := 7; sym := SyHelo; RETURN
						ELSE sym := noSym; RETURN
						END;
			|	7: HALT (57) (*Avoid look ahead character read*)
			|	8: IF (ch ="U") THEN state := 9;
						ELSE sym := noSym; RETURN
						END;
			|	9: IF (ch ="I") THEN state := 10;
						ELSE sym := noSym; RETURN
						END;
			| 10: IF (ch ="T") THEN state := 11; sym := SyQuit; RETURN
						ELSE sym := noSym; RETURN
						END;
			| 11: HALT (61) (*Avoid look ahead character read*)
			| 12: IF (ch ="O") THEN state := 13;
						ELSE sym := noSym; RETURN
						END;
			| 13: IF (ch ="O") THEN state := 14;
						ELSE sym := noSym; RETURN
						END;
			| 14: IF (ch ="P") THEN state := 15; sym := SyNoop; RETURN
						ELSE sym := noSym; RETURN
						END;
			| 15: HALT (65) (*Avoid look ahead character read*)
			| 16: IF (ch ="S") THEN state := 17;
						ELSIF (ch ="C") THEN state := 25;
						ELSE sym := noSym; RETURN
						END;
			| 17: IF (ch ="E") THEN state := 18;
						ELSE sym := noSym; RETURN
						END;
			| 18: IF (ch ="T") THEN state := 19; sym := SyRset; RETURN
						ELSE sym := noSym; RETURN
						END;
			| 19: HALT (69) (*Avoid look ahead character read*)
			| 20: IF (ch ="A") THEN state := 21;
						ELSE sym := noSym; RETURN
						END;
			| 21: IF (ch ="T") THEN state := 22;
						ELSE sym := noSym; RETURN
						END;
			| 22: IF (ch ="A") THEN state := 23; sym := SyData; RETURN
						ELSE sym := noSym; RETURN
						END;
			| 23: HALT (73) (*Avoid look ahead character read*)
			| 24: sym := SyDot; HALT(74); RETURN
			| 25: IF (ch ="P") THEN state := 26;
						ELSE sym := noSym; RETURN
						END;
			| 26: IF (ch ="T") THEN state := 27; sym := SyRcpt; RETURN
						ELSE sym := noSym; RETURN
						END;
			| 27: HALT (77) (*Avoid look ahead character read*)
			| 28: IF (ch ="O") THEN state := 29;
						ELSE sym := noSym; RETURN
						END;
			| 29: IF (ch =":") THEN state := 30; sym := SyTo; RETURN
						ELSE sym := noSym; RETURN
						END;
			| 30: HALT (80) (*Avoid look ahead character read*)
			| 31: IF (ch ="A") THEN state := 32;
						ELSE sym := noSym; RETURN
						END;
			| 32: IF (ch ="I") THEN state := 33;
						ELSE sym := noSym; RETURN
						END;
			| 33: IF (ch ="L") THEN state := 34; sym := SyMail; RETURN
						ELSE sym := noSym; RETURN
						END;
			| 34: HALT (84) (*Avoid look ahead character read*)
			| 35: IF (ch ="O") THEN state := 36;
						ELSE sym := noSym; RETURN
						END;
			| 36: IF (ch ="M") THEN state := 37;
						ELSE sym := noSym; RETURN
						END;
			| 37: IF (ch =":") THEN state := 38; sym := SyFrom; RETURN
						ELSE sym := noSym; RETURN
						END;
			| 38: HALT (88) (*Avoid look ahead character read*)
			| 39: sym := 0; ch := 0X; RETURN

				END (*CASE*)
			ELSE sym := noSym; RETURN (*NextCh already done*)
			END; (*IF*)
		END (*LOOP*)
	END Get;

	PROCEDURE ErrMsg(msg : String);
	BEGIN
		KernelLog.String (msg);
	END ErrMsg;

	PROCEDURE Error1(n: INTEGER);
	BEGIN
		INC(errors);
		lasterror := n;
		KernelLog.Enter;
   		CASE n OF
		  | 13: ErrMsg("??? expected")
		  | 14: ErrMsg("invalid MAIL")
		  | 15: ErrMsg("invalid MAIL")
		  | 16: ErrMsg("invalid reset")
		 ELSE END;
		 KernelLog.Exit
		END Error1;

	PROCEDURE Error2 (n, sym: INTEGER);
	BEGIN
		INC(errors);
		lasterror := n;
		KernelLog.Enter;
   		CASE n OF
  		    0: ErrMsg("EOF expected, ")
		  |  1: ErrMsg("Eol expected, ")
		  |  2: ErrMsg("ident expected, ")
		  |  3: ErrMsg("'HELO' expected, ")
		  |  4: ErrMsg("'QUIT' expected, ")
		  |  5: ErrMsg("'NOOP' expected, ")
		  |  6: ErrMsg("'RSET' expected, ")
		  |  7: ErrMsg("'DATA' expected, ")
		  |  8: ErrMsg("'.' expected, ")
		  |  9: ErrMsg("'RCPT' expected, ")
		  | 10: ErrMsg("'TO:' expected, ")
		  | 11: ErrMsg("'MAIL' expected, ")
		  | 12: ErrMsg("'FROM:' expected, ")
		 ELSE END;
   		CASE sym OF
  		    0: ErrMsg("EOF found")
		  |  1: ErrMsg("Eol found")
		  |  2: ErrMsg("ident found")
		  |  3: ErrMsg("'HELO' found")
		  |  4: ErrMsg("'QUIT' found")
		  |  5: ErrMsg("'NOOP' found")
		  |  6: ErrMsg("'RSET' found")
		  |  7: ErrMsg("'DATA' found")
		  |  8: ErrMsg("'.' found")
		  |  9: ErrMsg("'RCPT' found")
		  | 10: ErrMsg("'TO:' found")
		  | 11: ErrMsg("'MAIL' found")
		  | 12: ErrMsg("'FROM:' found")
		 ELSE END;
		 KernelLog.Exit;
		END Error2;

	PROCEDURE Confirm(n: INTEGER);
	BEGIN IF sym = n THEN (* Nothing *) ELSE Error2(n, sym) END
	END Confirm;

	PROCEDURE Expect(n: INTEGER);
	BEGIN IF sym = n THEN Get ELSE Error2(n, sym) END
	END Expect;

	PROCEDURE StartOf(s: INTEGER): BOOLEAN;
		BEGIN RETURN (sym MOD setSize) IN symSet[s, sym DIV setSize]
	END StartOf;

	PROCEDURE Who;
		VAR	ipStr : String;
	BEGIN
			IP.AdrToStr (SELF.client.fip, ipStr);
			KernelLog.String (ipStr);
	END Who;

	PROCEDURE BackStagePass (pass : String) : BOOLEAN;
		VAR ipStr : String; ix: LONGINT;
	BEGIN
		IP.AdrToStr (SELF.client.fip, ipStr);
		ix := 0;
		WHILE (ix<=15) & (ipStr[ix] = pass[ix]) & (ipStr[ix] # 0X)
		DO
			INC (ix)
		END;
		RETURN pass[ix] = 0X
	END BackStagePass;

	BEGIN {ACTIVE}
		BEGIN {EXCLUSIVE}
			INC (active)
		END;
		(* open streams *)
		Streams.OpenReader(in, client.Receive);
		Streams.OpenWriter(out, client.Send);
		IF (active < MaxActive) OR BackStagePass (AlwaysAccept)
		THEN
			ConsumeName;
			finished := FALSE;
			charcount := 0;
			getCalls := 0;
				ToLog0 ("Connection made. ");
				Who;
				KernelLog.Exit;
			Announce(out);
				ToLog0 ("Log open sequence. ");
				KernelLog.Exit;
			OpenLog;
			log.String ("Log file opened on ");
			Strings.FormatDateTime("www, dd mmm yyyy hh:nn:ss -0600 (CST)", Dates.Now(), auxString);
			log.String (auxString);
			log.Ln;
			log.String ("From IP ");
			IP.AdrToStr(SELF.client.fip, auxString);
			log.String (auxString);
			DNS.HostByNumber (SELF.client.fip, auxString, res);
			IF res = DNS.Ok
			THEN
				log.String (" <");
				log.String (auxString);
				log.String ("> ")
			END;
			log.Ln;
				ToLog0 ("Log now open. ");
				KernelLog.Exit;

			(* production Smtp *)
			Get;
			badTokens := 0;

			WHILE ~finished & (badTokens < 100) & (sym#0) DO
				WHILE ~StartOf(2) DO
					out.String ("500 Not implemented"); out.Ln; out.Update;
					ch := GetCh (); WHILE ch # CR DO ch := GetCh () END; ch := GetCh ();
					Get; INC (badTokens);
				END;
				WHILE StartOf(1)
				DO
					reset
				END;
				QUIT
			END
		ELSE
			out.String ("421 PeerGrade.mrs.umn.edu, Service Not Available, Max connections exceeded.");
			out.Ln; out.Update;
			ToLog0 ("Connection rejected, too many connections. ");
			Who;
			KernelLog.Exit
		END;
		Terminate;
		BEGIN {EXCLUSIVE} DEC (active) END;
		ToLog0 ("Connection closed. ");
		Who;
		KernelLog.Exit
	END SmtpAgent;

VAR
	symSet:	ARRAY nrSets OF SymbolSet;
	smtp: TCPServices.Service;
	nextName : String;

	PROCEDURE ToLog0 (msg : String);
	BEGIN
		KernelLog.Enter;
		KernelLog.String (ID);
		KernelLog.String ("  ");
		KernelLog.String (msg);
	END ToLog0;


PROCEDURE InitSmtpSTable;
BEGIN
	start[0]:=39; start[1]:=0; start[2]:=0; start[3]:=0;
	start[4]:=0; start[5]:=0; start[6]:=0; start[7]:=0;
	start[8]:=0; start[9]:=0; start[10]:=0; start[11]:=0;
	start[12]:=0; start[13]:=1; start[14]:=0; start[15]:=0;
	start[16]:=0; start[17]:=0; start[18]:=0; start[19]:=0;
	start[20]:=0; start[21]:=0; start[22]:=0; start[23]:=0;
	start[24]:=0; start[25]:=0; start[26]:=0; start[27]:=0;
	start[28]:=0; start[29]:=0; start[30]:=0; start[31]:=0;
	start[32]:=0; start[33]:=0; start[34]:=0; start[35]:=0;
	start[36]:=0; start[37]:=0; start[38]:=0; start[39]:=0;
	start[40]:=0; start[41]:=0; start[42]:=0; start[43]:=0;
	start[44]:=0; start[45]:=0; start[46]:=24; start[47]:=0;
	start[48]:=0; start[49]:=0; start[50]:=0; start[51]:=0;
	start[52]:=0; start[53]:=0; start[54]:=0; start[55]:=0;
	start[56]:=0; start[57]:=0; start[58]:=0; start[59]:=0;
	start[60]:=0; start[61]:=0; start[62]:=0; start[63]:=0;
	start[64]:=0; start[65]:=0; start[66]:=3; start[67]:=0;
	start[68]:=20; start[69]:=0; start[70]:=3; start[71]:=3;
	start[72]:=4; start[73]:=0; start[74]:=3; start[75]:=3;
	start[76]:=0; start[77]:=31; start[78]:=12; start[79]:=0;
	start[80]:=0; start[81]:=8; start[82]:=16; start[83]:=0;
	start[84]:=28; start[85]:=0; start[86]:=3; start[87]:=3;
	start[88]:=3; start[89]:=3; start[90]:=3; start[91]:=0;
	start[92]:=0; start[93]:=0; start[94]:=0; start[95]:=0;
	start[96]:=0; start[97]:=0; start[98]:=3; start[99]:=0;
	start[100]:=0; start[101]:=0; start[102]:=3; start[103]:=3;
	start[104]:=0; start[105]:=0; start[106]:=3; start[107]:=3;
	start[108]:=0; start[109]:=0; start[110]:=0; start[111]:=0;
	start[112]:=0; start[113]:=0; start[114]:=0; start[115]:=0;
	start[116]:=0; start[117]:=0; start[118]:=3; start[119]:=3;
	start[120]:=3; start[121]:=3; start[122]:=3; start[123]:=0;
	start[124]:=0; start[125]:=0; start[126]:=0; start[127]:=0;
END InitSmtpSTable;

PROCEDURE NewSmtpAgent(c: TCP.Connection; s: TCPServices.Service): TCPServices.Agent;
VAR a: SmtpAgent;
BEGIN
	NEW(a, c, s); RETURN a
END NewSmtpAgent;

(* This should become XML aware. *)
PROCEDURE GetRegistry (VAR filename : String);
VAR regF : Files.File; regR : Files.Reader;
BEGIN
	regF := Files.Old (ConfigFileName);
	IF regF # NIL
	THEN
		Files.OpenReader (regR, regF, 0);
		regR.RawString (filename)
	ELSE
		filename := "D0000000000.Msg";
		regF := Files.New (ConfigFileName);
		Files.Register (regF)
	END;
END GetRegistry;

PROCEDURE PutRegistry (VAR filename : String);
VAR regF : Files.File; regW : Files.Writer;
BEGIN
	regF := Files.Old (ConfigFileName);
	IF regF=NIL THEN regF := Files.New (ConfigFileName); Files.Register (regF)  END;
	Files.OpenWriter (regW, regF, 0);
	regW.RawString (filename);
	regW.Update;
	regF.Update;
END PutRegistry;

PROCEDURE Announce ( VAR out: Streams.Writer);
BEGIN
	out.String ("220 ");
	out.String (DNS.domain);
	out.Char (" ");
	out.String ("SMTP");
	out.Char (" ");
	out.String (ID);
	out.String (Version);
	out.String (" Ready ");
	out.Ln();
	out.Update;
END Announce;

PROCEDURE Open*;
VAR res : WORD;
BEGIN
	IF smtp = NIL THEN
		NEW(smtp, AlmSmtpReceiverPort, NewSmtpAgent, res);
		active := 0;
		GetRegistry (nextName);
		ToLog0 (Version); KernelLog.String(" opened.  Next name: ");
		KernelLog.String (nextName);
		KernelLog.Exit
	END;
END Open;

PROCEDURE Close*;
BEGIN
	IF smtp # NIL THEN
		smtp.Stop(); smtp := NIL;
		PutRegistry (nextName);
		ToLog0 (Version); KernelLog.String(" closed"); KernelLog.Exit
	END;
END Close;

PROCEDURE Cleanup;
BEGIN
	Close;
END Cleanup;



BEGIN
	Pattern[0] := CR;
	Pattern[1] := LF;
	Pattern[2] := ".";
	Pattern[3] := CR;
	Pattern[4] := LF;
	Pattern[5] := 0X;
	Ack[0] := "0";
	Ack[1] := "1";
	Ack[2] := "2";
	Ack[3] := "3";
	Ack[4] := "4";
	Ack[5] := 0X;

	symSet[0, 0] := {0};
	symSet[1, 0] := {SyHelo,SyNoop,SyRset,SyMail};
	symSet[2, 0] := {SyHelo,SyQuit,SyNoop,SyRset,SyMail};
	InitSmtpSTable;
	Modules.InstallTermHandler(Cleanup);
END AlmSmtpReceiver.





AlmSmtpReceiver.Tool
System.Directory FAT:/Mail/Incoming/*\d
System.Directory C0*\d
Aos.Call AlmSmtpReceiver.Open
Aos.Call AlmSmtpReceiver.Close
Aos.Call NetTracker.Open 100 ~
System.Free AlmSmtpReceiver  ~
System.Free AlmSmtpReceiver ~

EditTools.OpenAscii ^
Telnet.Open cda
System.State AlmSmtpReceiver ~
Builder.Compile *
Telnet.Open "sci1355-am.mrs.umn.edu" 27
Colors.Panel
Hex.Open mail.config

	ch =  0000000DX
	charcount = 26
	config = ""
	errors = 0
	lasterror = 0
	nextName = "D0000000101"
	smtp =  022685D0H
	start = 39, 0, 0, 0, 0, 0, 0, 0, 0, 0 ...
	state = 7
	sym = 3


