MODULE TFSMTPServer;	(** AUTHOR "TF"; PURPOSE "Forward any emails received to one or more email addresses"; *)

IMPORT
		KernelLog, Modules, Streams, Files, IP, TCP, TCPServices, Dates, Strings, SMTPClient, TFClasses,
		XML, XMLScanner, XMLParser, XMLObjects, Configuration;

TYPE
	DomainName = ARRAY 128 OF CHAR;
	String = Strings.String;
	Line = OBJECT VAR s :String END Line;

	Message = OBJECT
	VAR
		fromIP : IP.Adr;
		fromDomain : DomainName;
		timestamp : ARRAY 64 OF CHAR;
		data : TFClasses.List;

		PROCEDURE &Init*;
		BEGIN
			NEW(data);
			Strings.FormatDateTime("yyyy.mm.dd hh:nn:ss", Dates.Now(), timestamp);
		END Init;

		PROCEDURE AddLine(CONST x : ARRAY OF CHAR);
		VAR l : SIZE; s : String; line : Line;
		BEGIN
			l := Strings.Length(x) + 1; NEW(s, l); COPY(x, s^); NEW(line); line.s := s; data.Add(line);
		END AddLine;
	END Message;

	Account = OBJECT
	VAR userName : String;
		mailAliases : TFClasses.List;
		forwardAddress : String;

		PROCEDURE &Init*;
		BEGIN
			NEW(mailAliases);
		END Init;

		PROCEDURE AddAlias(s : String);
		VAR l : Line;
		BEGIN
			Strings.LowerCase(s^);
			NEW(l); l.s := s; mailAliases.Add(l)
		END AddAlias;

		PROCEDURE IsAlias(CONST s : ARRAY OF CHAR) : BOOLEAN;
		VAR i : SIZE; p : ANY;
			isAlias : BOOLEAN;
		BEGIN
			mailAliases.Lock;
			isAlias := FALSE;
			FOR i := 0 TO mailAliases.GetCount() - 1 DO
				p := mailAliases.GetItem(i);
				IF (p # NIL) & (p IS Line) & (p(Line).s # NIL) & (Strings.Match(p(Line).s^, s)) THEN isAlias := TRUE END
			END;
			mailAliases.Unlock;
			RETURN isAlias
		END IsAlias;

		PROCEDURE DumpAccount;
		VAR i : SIZE; p : ANY;
		BEGIN
			KernelLog.String("Account : "); KernelLog.String(userName^); KernelLog.Ln;
			KernelLog.String("Aliases :");
			mailAliases.Lock;
			FOR i := 0 TO mailAliases.GetCount() - 1 DO
				p := mailAliases.GetItem(i);
				IF (p # NIL) & (p IS Line) & (p(Line).s # NIL)  THEN KernelLog.String(p(Line).s^); KernelLog.Ln END
			END;
			mailAliases.Unlock;

			KernelLog.String("Forward address : ");
			IF forwardAddress # NIL THEN KernelLog.String(forwardAddress^)
			ELSE KernelLog.String("<not set>")
			END;
			KernelLog.Ln;
			KernelLog.Ln;
		END DumpAccount;

		PROCEDURE SaveMessage(m : Message) : BOOLEAN;
		VAR path, filePath : ARRAY 256 OF CHAR;
			f : Files.File; w : Files.Writer;
			i : SIZE; res: WORD; p : ANY;
		BEGIN
			COPY(mailPath^, path);
			Strings.Append(path, "/"); Strings.Append(path, userName^);
			COPY(path, filePath);
			Strings.Append(filePath, "/mailbox.txt");
			f := Files.Old(filePath);
			IF f = NIL THEN Files.CreateDirectory(path, res);
				f := Files.New(filePath);
			END;
			IF f # NIL THEN
				Files.OpenWriter(w, f, f.Length());
				(* append mail *)
				m.data.Lock;
				FOR i := 0 TO m.data.GetCount() - 1 DO
					p := m.data.GetItem(i);
					IF (p # NIL) & (p IS Line) & (p(Line).s # NIL)  THEN w.String(p(Line).s^); w.Ln END
				END;
				m.data.Unlock;
				w.Update;
				Files.Register(f);
				RETURN TRUE;
			ELSE
				RETURN FALSE
			END;
		END SaveMessage;

		PROCEDURE Forward(m : Message; CONST sender : ARRAY OF CHAR) : BOOLEAN;
		VAR smtpSession : SMTPClient.SMTPSession; p : ANY;
			res: WORD; i : SIZE;
		BEGIN
			NEW(smtpSession);
			smtpSession.Open(mailRelay, mailHost, 25, res);
			IF res # 0 THEN
				KernelLog.String("Could not forward... SMTP - Relay is not available"); KernelLog.Ln;
				RETURN FALSE
			END;
			IF smtpSession.StartMailFrom(sender) & smtpSession.SendTo(forwardAddress^) & smtpSession.StartData() THEN
				m.data.Lock;
				FOR i := 0 TO m.data.GetCount() - 1 DO
					p := m.data.GetItem(i);
					IF (p # NIL) & (p IS Line) & (p(Line).s # NIL)  THEN smtpSession.SendRawLine(p(Line).s^) END
				END;
				m.data.Unlock;
				IF ~smtpSession.FinishSendRaw() THEN
					KernelLog.String("could not forward message"); KernelLog.Ln;
					smtpSession.Close;
					RETURN FALSE
				END;
				smtpSession.Close;
			END;
			RETURN TRUE
		END Forward;

		(* must be exclusive *)
		PROCEDURE ReceiveMessage(m : Message; CONST sender: ARRAY OF CHAR) : BOOLEAN;
		VAR ok : BOOLEAN;
		BEGIN { EXCLUSIVE }
			KernelLog.String("====");
			KernelLog.String("Recieved message to account "); KernelLog.String(userName^); KernelLog.Ln;
			ok := SaveMessage(m);
			IF (forwardAddress # NIL) & (forwardAddress^ # "") THEN ok := ok & Forward(m, sender) END;
			RETURN ok
		END ReceiveMessage;
	END Account;

	SMTPAgent* = OBJECT (TCPServices.Agent)
	VAR quit : BOOLEAN;
			id : ARRAY 1024 OF CHAR;
			domain, sender, token : ARRAY 64 OF CHAR;
			in: Streams.Reader; out: Streams.Writer;
			isSpam: BOOLEAN;
			recipients : TFClasses.List;
			message : Message;

		PROCEDURE AddRecipient(VAR x : ARRAY OF CHAR);
		VAR l, p : SIZE; s : String; line : Line;
		BEGIN
			p := Strings.Pos("<", x); IF p >= 0 THEN Strings.Delete(x, 0, p + 1) END; Strings.TrimRight(x, ">");
			l := Strings.Length(x) + 1 ; IF l = 1 THEN RETURN END;
			NEW(s, l); COPY(x, s^); NEW(line); line.s := s; recipients.Add(line)
		END AddRecipient;

		PROCEDURE Reply(code: LONGINT; CONST text1, text2 : ARRAY OF CHAR);
		BEGIN
			out.Int(code, 3);  out.String(" "); out.String(text1); out.String(" "); out.String(text2);
			out.Ln; out.Update
		END Reply;

		PROCEDURE Init():BOOLEAN;
		BEGIN
			in.Token(token);
			IF EqualsI(token, "HELO") THEN in.SkipSpaces; in.Ln(domain);
				Reply(250, id, "");
				RETURN TRUE
			ELSIF EqualsI(token, "QUIT") THEN in.SkipLn; quit := TRUE; RETURN FALSE
			ELSIF EqualsI(token, "NOOP") THEN in.SkipLn; Reply(250, "ok", ""); RETURN FALSE
			END;
			Reply(500,  "Command unrecognized", token); in.SkipLn;
			RETURN FALSE
		END Init;

		PROCEDURE From():BOOLEAN;
		BEGIN
			in.Token(token);
			IF EqualsI(token, "MAIL") THEN
				in.SkipSpaces; in.Ln(sender);
				Reply(250, sender, "...Sender ok");
				RETURN TRUE
			ELSIF EqualsI(token, "QUIT") THEN in.SkipLn; quit := TRUE; RETURN FALSE
			ELSIF EqualsI(token, "NOOP") THEN in.SkipLn; Reply(250, "ok", ""); RETURN FALSE
			END;
			Reply(500,  "Command unrecognized", token); in.SkipLn;
			RETURN FALSE
		END From;

		PROCEDURE Rcpt():BOOLEAN;
		VAR recipient : ARRAY 1024 OF CHAR; errcount : LONGINT;
		BEGIN
			errcount := 0; isSpam:=TRUE;
			LOOP
				in.Token(token);
				IF in.res # 0 THEN quit := TRUE; RETURN FALSE END;
				IF EqualsI(token, "RCPT") THEN
					in.SkipSpaces; in.Ln(recipient);
					Strings.LowerCase(recipient);
					AddRecipient(recipient);
					Reply(250, recipient, "...Recipient ok"); errcount := 0;
				ELSIF EqualsI(token, "QUIT") THEN in.SkipLn; quit := TRUE; RETURN FALSE
				ELSIF EqualsI(token, "RSET") THEN in.SkipLn; Reply(250, "Reset state", ""); RETURN FALSE
				ELSIF EqualsI(token, "NOOP") THEN in.SkipLn; Reply(250, "ok", ""); errcount := 0;
				ELSIF EqualsI(token, "DATA") THEN in.SkipLn; Reply(354, "Start mail input; end with <CRLF>.<CRLF>", "");
					RETURN TRUE
				ELSE Reply(500,  "Command unrecognized", token); in.SkipLn;
					INC(errcount); IF errcount = 5 THEN RETURN FALSE END;
				END
			END
		END Rcpt;

		PROCEDURE Data():BOOLEAN;
		VAR line : ARRAY 1024 OF CHAR;
		BEGIN
			NEW(message);
			REPEAT
				in.Ln(line);
				message.AddLine(line)
			UNTIL (line = ".") OR (in.res # 0);
			RETURN in.res = 0
		END Data;

		PROCEDURE SaveLostMessage(m : Message) : BOOLEAN;
		VAR path, filePath : ARRAY 256 OF CHAR;
			f : Files.File; w : Files.Writer;
			i : SIZE; res: WORD; p : ANY;
		BEGIN
			COPY(mailPath^, path);
			Strings.Append(path, "/"); Strings.Append(path, "lost");
			COPY(path, filePath);
			Strings.Append(filePath, "/mailbox.txt");
			f := Files.Old(filePath);
			IF f = NIL THEN Files.CreateDirectory(path, res);
				f := Files.New(filePath);
			END;
			IF f # NIL THEN
				Files.OpenWriter(w, f, f.Length());
				(* append mail *)
				m.data.Lock;
				FOR i := 0 TO m.data.GetCount() - 1 DO
					p := m.data.GetItem(i);
					IF (p # NIL) & (p IS Line) & (p(Line).s # NIL)  THEN w.String(p(Line).s^); w.Ln END
				END;
				m.data.Unlock;
				w.Update;
				Files.Register(f);
				RETURN TRUE;
			ELSE
				RETURN FALSE
			END;
		END SaveLostMessage;

		PROCEDURE DeliverMessage() : BOOLEAN;
		VAR i, j : SIZE; ap, sp : ANY;
			isReceiver : BOOLEAN;
			ok : BOOLEAN;
			lost : BOOLEAN;
		BEGIN
			ok := TRUE; lost := TRUE;
			recipients.Lock;
			accounts.Lock;
			FOR i := 0 TO accounts.GetCount() - 1 DO
				ap := accounts.GetItem(i);
				IF (ap # NIL) & (ap IS Account) THEN
					isReceiver := FALSE;
					FOR j := 0 TO recipients.GetCount() - 1 DO
						sp := recipients.GetItem(j);
						IF (sp # NIL) & (sp IS Line) & (sp(Line).s # NIL) & (ap(Account).IsAlias(sp(Line).s^)) THEN isReceiver := TRUE END
					END;
					IF isReceiver THEN
						IF ~ap(Account).ReceiveMessage(message, sender) THEN ok := FALSE ELSE lost := FALSE END
					END
				END;
			END;
			accounts.Unlock;
			recipients.Unlock;
			IF lost THEN
				recipients.Lock;
				KernelLog.String("Lost message to "); KernelLog.Ln;
				FOR j := 0 TO recipients.GetCount() - 1 DO
					sp := recipients.GetItem(j);
					IF (sp # NIL) & (sp IS Line) & (sp(Line).s # NIL) THEN KernelLog.String(sp(Line).s^); KernelLog.Ln END;
				END;
				IF SaveLostMessage(message) THEN KernelLog.String("Saved. in lost messages"); KernelLog.Ln END;
				KernelLog.Ln; KernelLog.Ln;
				recipients.Unlock;
			END;
			RETURN ok
		END DeliverMessage;

	BEGIN {ACTIVE}
		id := "Bimbo SMPT Server";
		(* open streams *)
		Streams.OpenReader(in, client.Receive);
		Streams.OpenWriter(out, client.Send);

		(* read request *)
		quit := FALSE;
		Reply(220, id, "Simple Mail Transfer Service Ready");
		REPEAT UNTIL Init() OR quit OR (in.res # 0) OR (out.res # 0);
		REPEAT
			IF ~quit THEN REPEAT UNTIL From() OR quit OR (in.res # 0) OR (out.res # 0) END;
			IF ~quit THEN
				message := NIL;
				NEW(recipients);
				IF Rcpt() THEN
					IF Data() THEN
						IF DeliverMessage() THEN Reply(250, id, "ok") ELSE Reply(500, id, "internal failure"); quit := TRUE END;
					ELSE Reply(550, id, "Failure"); quit := TRUE
					END
				END
			END
		UNTIL quit;
		IF quit THEN Reply(221, id, "Service closing transmission channel") END;
		client.Close();
		Terminate
	END SMTPAgent;

VAR smtp : TCPServices.Service;
	accounts : TFClasses.List;
	mailPath : String;
	mailRelay, mailHost : ARRAY 64 OF CHAR;
	mailConfig : XML.Document;
	errors : BOOLEAN;

PROCEDURE EqualsI(CONST buf, with: ARRAY OF CHAR): BOOLEAN;
VAR j: LONGINT;
BEGIN
	j := 0; WHILE (with[j] # 0X) & (CAP(buf[j]) = CAP(with[j])) DO INC(j) END;
	RETURN CAP(with[j]) = CAP(buf[j])
END EqualsI;

PROCEDURE NewSMTPAgent(c: TCP.Connection; s: TCPServices.Service): TCPServices.Agent;
VAR a: SMTPAgent;
BEGIN
	NEW(a, c, s); RETURN a
END NewSMTPAgent;

PROCEDURE TrapHandler(pos, line, row: Streams.Position; CONST msg: ARRAY OF CHAR);
BEGIN
	KernelLog.String("Mail config error at pos "); KernelLog.Int(pos, 0); KernelLog.Ln;
	errors := TRUE
END TrapHandler;

PROCEDURE LoadSettings(CONST filename : ARRAY OF CHAR) : BOOLEAN;
VAR f: Files.File; scanner: XMLScanner.Scanner; parser: XMLParser.Parser;
	reader: Files.Reader;
BEGIN {EXCLUSIVE}
	errors := FALSE;
	f := Files.Old(filename);
	IF f # NIL THEN
		NEW(reader, f, 0);
		NEW(scanner, reader); NEW(parser, scanner); parser.reportError := TrapHandler; mailConfig := parser.Parse();
		IF errors  THEN KernelLog.String("Mail config file contains errors."); KernelLog.Ln; RETURN FALSE END
	ELSE KernelLog.String("Mail config file not found : "); KernelLog.String(filename); KernelLog.Ln; RETURN FALSE
	END;
	RETURN TRUE
END LoadSettings;

PROCEDURE CreateAccounts;
VAR acc, aliases, e : XML.Element;
		p : ANY; enum, enumAlias: XMLObjects.Enumerator;
		a : Account;
		acs : TFClasses.List;
BEGIN
	NEW(acs);
	acc := Configuration.GetSection("Accounts");
	IF acc # NIL THEN
		enum := acc.GetContents();
		WHILE enum.HasMoreElements() DO
			p := enum.GetNext();
			IF p IS XML.Element THEN
				e := p(XML.Element);
				NEW(a);
				a.userName := e.GetAttributeValue("name");
				a.forwardAddress := e.GetAttributeValue("forward");
				aliases := Configuration.GetNamedElement(e, "Section", "Aliases");
				enumAlias := aliases.GetContents();
				WHILE enumAlias.HasMoreElements() DO
					p := enumAlias.GetNext();
					IF (p # NIL) & (p IS XML.Element) THEN
						e := p(XML.Element);
						a.AddAlias(e.GetAttributeValue("name"));
					END
				END;
				a.DumpAccount;
				acs.Add(a);
			END
		END;
	END;
	accounts := acs
END CreateAccounts;

PROCEDURE Start*;
VAR e: XML.Element; a: XML.Attribute; s : String; res : WORD;
BEGIN
	IF smtp = NIL THEN
		IF LoadSettings("TFMailConfig.XML") THEN
			CreateAccounts;
			e := Configuration.GetNamedElement(mailConfig.GetRoot(), "Setting", "path");
			IF (e # NIL) THEN a := e.GetAttribute("value"); IF a # NIL THEN mailPath := a.GetValue() END END;

			e := Configuration.GetNamedElement(mailConfig.GetRoot(), "Setting", "relay");
			IF (e # NIL) THEN a := e.GetAttribute("value"); IF a # NIL THEN s := a.GetValue() END; IF s # NIL THEN COPY(s^, mailRelay) END END;

			e := Configuration.GetNamedElement(mailConfig.GetRoot(), "Setting", "host");
			IF (e # NIL) THEN a := e.GetAttribute("value"); IF a # NIL THEN s := a.GetValue() END; IF s # NIL THEN COPY(s^, mailHost) END END;


			IF mailPath = NIL THEN NEW(mailPath, 2) END;
			Strings.TrimRight(mailPath^, "/");
			NEW(smtp, 25, NewSMTPAgent, res);
			KernelLog.String("TFSMTPServer started:"); KernelLog.Ln;
			KernelLog.String(" mail directory ");KernelLog.String(mailPath^); KernelLog.Ln;
		ELSE
			KernelLog.String("TFMailConfig.XML not correct, not started"); KernelLog.Ln
		END
	ELSE
		KernelLog.String("Already running."); KernelLog.Ln
	END;
END Start;

PROCEDURE Stop*;
BEGIN
	IF smtp # NIL THEN
		smtp.Stop(); smtp := NIL;
		KernelLog.String("Bimbo SMTP server stopped"); KernelLog.Ln;
	END;
END Stop;

PROCEDURE Cleanup;
BEGIN
	Stop;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END TFSMTPServer.


EditTools.OpenAscii TFMailConfig.XML
System.Free TFSMTPServer ~
Aos.Call TFSMTPServer.Start
