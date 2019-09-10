MODULE IMAP; (** AUTHOR "retmeier"; PURPOSE "IMAP Client Library, implements a subset of RFC 2060"; *)

IMPORT DNS, IP, Streams, TCP, Strings, KernelLog, Classes := TFClasses, IMAPUtilities;

CONST
	DEBUG = FALSE;
	DEBUGLEVEL = 1; (* 2 logs full parse list, not recommended :-) *)

	(** state machine constants *)
	DEAD* = -1; (** No Connection *)
	NOAUTH* = 0; (** Connected, but not logged in *)
	AUTH* = 1; (** Logged in *)
	SELECT* = 2; (** Mailbox selected *)

	(* entry structure type constants *)
	LITERAL* = 0;
	STRING* = 1;
	LIST* = 2;
	ATOM* = 3;
	HEADER* = 4;

	(** return values *)
	OK* = 0;
	BAD = 1;
	READBACKERR = 2;
	SENDERR = 3;

TYPE
	String = Strings.String;

	Entry* = POINTER TO RECORD
		data-: String;
		list-: Classes.List;
		type-: SIGNED32;
		command-: ARRAY 40 OF CHAR;
		number-: SIGNED32
	END;

		(* An IMAP Response consists of one or more lines. Each line of an answer is represented with an Entry-Object with
		an attached List (also consisting of Entry-Objects of different Types like Atom, List, String or Literal, representing the
		IMAP return value in internalized version). The command field says of which type the answer is and how it has to be
		parsed. The last command field in the sequence of lines of the IMAP-Answer shows if the command succeeded
		(command = OK) or not (command # OK).. See also RFC 2060. After the syntactical analysis the typed list is further parsed
		semantically by the different procedures. *)


	(** Connection Object represents IMAP Connection/Session *)
	Connection* = OBJECT
		VAR
			in: Streams.Reader;
			out: Streams.Writer;
			tag: SIGNED32;
			state: SIGNED32;
			tagString: ARRAY 80 OF CHAR;
			buffer: ARRAY 80 OF CHAR;
			connection : TCP.Connection;
			capability: Classes.List;
			ret: Classes.List;
			first: BOOLEAN;
			logout: BOOLEAN;

		(** connect to server, works in any state, changes to NOAUTH *)
		PROCEDURE &Init* (VAR host: ARRAY OF CHAR; port: SIGNED32; VAR result: SIGNED32);
		VAR
			ip: IP.Adr;
			res: INTEGER;
			ret: Classes.List;
		BEGIN
			logout := FALSE;
			first := TRUE;
			state := DEAD;

			IF DEBUG THEN KernelLog.String("WELCOME TO IMAP"); KernelLog.Ln 	END;
			DNS.HostByName(host, ip, res);
			IF res = DNS.Ok THEN
				NEW(connection);
				connection.Open(TCP.NilPort, ip, port, res);
				IF res = TCP.Ok THEN
					IF DEBUG THEN 	KernelLog.String("connected..."); KernelLog.Ln; END;
					(* one would assume that a rejected tcp connection would'nt set TCP.Ok... but it does ! *)
					Streams.OpenReader(in, connection.Receive);
					Streams.OpenWriter(out, connection.Send);
					state := NOAUTH;
					IF ReadResponse(ret) THEN
						IF CheckResultCode(ret) THEN
							result := OK;
						ELSE
							IF DEBUG THEN KernelLog.String("STATUS FAILURE"); KernelLog.Ln END;
							state := DEAD;
							result := BAD
						END;
					ELSE
						IF DEBUG THEN KernelLog.String("CONNECT FAILURE OR BYE"); KernelLog.Ln END;
						state := DEAD;
						result := BAD
					END
				END;
			ELSE
				IF DEBUG THEN KernelLog.String("DNS FAILURE"); KernelLog.Ln END;
				state := DEAD;
				result := BAD
			END
		END Init;

		(* build a command with one argument *)
		PROCEDURE MakeOneArgumentCommand(command: ARRAY OF CHAR; VAR argument: ARRAY OF CHAR): String;
		VAR
			buffer: Strings.Buffer;
			w: Streams.Writer;
			arg, string: Strings.String;
		BEGIN
			NEW(buffer, 16);
			w := buffer.GetWriter();
			w.String(command);
			w.String(" ");
			arg := IMAPUtilities.NewString(argument);
			IMAPUtilities.MakeQuotedString(arg);
			w.String(arg^);
			string := buffer.GetString();
			RETURN string;
		END MakeOneArgumentCommand;

		(* build a command with two arguments *)
		PROCEDURE MakeTwoArgumentCommand(command: ARRAY OF CHAR; VAR argument1, argument2: ARRAY OF CHAR): String;
		VAR
			buffer: Strings.Buffer;
			w: Streams.Writer;
			arg, string: String;
		BEGIN
			NEW(buffer, 16);
			w := buffer.GetWriter();
			w.String(command);
			w.String(" ");
			arg := IMAPUtilities.NewString(argument1);
			IMAPUtilities.MakeQuotedString(arg);
			w.String(arg^);
			w.String(" ");
			arg := IMAPUtilities.NewString(argument2);
			IMAPUtilities.MakeQuotedString(arg);
			w.String(arg^);
			string := buffer.GetString();
			RETURN string;
		END MakeTwoArgumentCommand;

		(** login into server, works in NOAUTH, changes to AUTH *)
		PROCEDURE Login*(username: ARRAY OF CHAR; password: ARRAY OF CHAR):SIGNED32;
		VAR
			string: Strings.String;
		BEGIN {EXCLUSIVE}
			IF state # NOAUTH THEN RETURN BAD END;
			string := MakeTwoArgumentCommand("LOGIN", username, password);
			RETURN SendToIMAPServer(string^,ret, AUTH, NOAUTH )
		END Login;

		(** Logout of remote system, changes state to DEAD *)
		PROCEDURE Logout*():SIGNED32;
		VAR
			string: Strings.String;
			value: SIGNED32;
		BEGIN {EXCLUSIVE}
			logout := TRUE;
			string := Strings.NewString("LOGOUT");
			value := SendToIMAPServer(string^,ret, DEAD, DEAD);
			IF connection # NIL THEN
				connection.Close;
				connection := NIL
			END;
			RETURN value
		END Logout;

		(** get current state *)
		PROCEDURE GetCurrentState*():SIGNED32;
		BEGIN {EXCLUSIVE}
			RETURN state
		END GetCurrentState;

		(** remove deleted mails, state stays in SELECT *)
		PROCEDURE Expunge*(VAR ret: Classes.List): SIGNED32;
		BEGIN {EXCLUSIVE}
			RETURN SendToIMAPServer("EXPUNGE",ret,SELECT,SELECT)
		END Expunge;

		(** create mailbox, works in AUTH and SELECT, state not changed *)
		PROCEDURE Create*(mailbox: ARRAY OF CHAR; VAR ret: Classes.List): SIGNED32;
		VAR
			string: Strings.String;
		BEGIN {EXCLUSIVE}
			IF (state # AUTH) & (state # SELECT) THEN RETURN BAD END;
			string := MakeOneArgumentCommand("CREATE", mailbox);
			RETURN SendToIMAPServer(string^,ret,state,state)
		END Create;

		(** delete mailbox, works in AUTH and SELECT, state not changed *)
		PROCEDURE Delete*(mailbox: ARRAY OF CHAR; VAR ret: Classes.List): SIGNED32;
		VAR
			string: Strings.String;
		BEGIN {EXCLUSIVE}
			IF (state # AUTH) & (state # SELECT) THEN RETURN BAD END;
			string := MakeOneArgumentCommand("DELETE", mailbox);
			RETURN SendToIMAPServer(string^,ret,state,state)
		END Delete;

		(** change name of mailbox, works in AUTH and SELECT, state not changed *)
		PROCEDURE Rename*(from, to: ARRAY OF CHAR; VAR ret: Classes.List): SIGNED32;
		VAR
			string: Strings.String;
		BEGIN {EXCLUSIVE}
			IF (state # AUTH) & (state # SELECT) THEN RETURN BAD END;
			string := MakeTwoArgumentCommand("RENAME",from, to);
			RETURN SendToIMAPServer(string^,ret,state,state)
		END Rename;

		(* send select command to server, changes to given mailbox *)
		PROCEDURE Select*(mailbox:ARRAY OF CHAR; VAR ret: Classes.List):SIGNED32;
		VAR
			string: Strings.String;
		BEGIN
			IF (state # AUTH) & (state # SELECT) THEN RETURN BAD END;
			string := MakeOneArgumentCommand("SELECT", mailbox);
			RETURN SendToIMAPServer(string^,ret,SELECT, state)
		END Select;

		(** examine mailbox, works in AUTH and SELECT, state not changed *)
		PROCEDURE Examine*(mailbox: ARRAY OF CHAR): SIGNED32;
		VAR
			string: Strings.String;
		BEGIN {EXCLUSIVE}
			IF (state # AUTH) & (state # SELECT) THEN RETURN BAD END;
			string := MakeOneArgumentCommand("EXAMINE", mailbox);
			RETURN SendToIMAPServer(string^, ret, SELECT, state)
		END Examine;

		(** list the mailboxes, works in in AUTH and SELECT, state not changed *)
		PROCEDURE List*(refName, mailbox: ARRAY OF CHAR; VAR ret: Classes.List):SIGNED32;
		VAR
			string: Strings.String;
		BEGIN {EXCLUSIVE}
			IF(state # AUTH) & (state # SELECT) THEN RETURN BAD END;
			string := MakeTwoArgumentCommand("LIST", refName, mailbox);
			RETURN SendToIMAPServer(string^, ret, state, state)
		END List;

		(** subscribe for mailbox, works in AUTH and SELECT, state not changed *)
		PROCEDURE Subscribe*(mailbox: ARRAY OF CHAR): SIGNED32;
		VAR
			string: Strings.String;
		BEGIN {EXCLUSIVE}
			IF (state # AUTH) & (state # SELECT) THEN RETURN BAD END;
			string := MakeOneArgumentCommand("SUBSCRIBE", mailbox);
			RETURN SendToIMAPServer(string^, ret, state, state)
		END Subscribe;

		(** unsubscribe for mailbox, works in AUTH and SELECT, state not changed *)
		PROCEDURE Unsubscribe*(mailbox: ARRAY OF CHAR): SIGNED32;
		VAR
			string: Strings.String;
		BEGIN {EXCLUSIVE}
			IF (state # AUTH) & (state # SELECT) THEN RETURN BAD END;
			string := MakeOneArgumentCommand("UNSUBSCRIBE", mailbox);
			RETURN SendToIMAPServer(buffer, ret, state, state)
		END Unsubscribe;

		(** appends a message to a mailbox. Works in AUTH and SELECT state *)
		PROCEDURE Append*(VAR mailbox, message: ARRAY OF CHAR; VAR ret: Classes.List): SIGNED32;
		VAR
			buffer: Strings.Buffer;
			w: Streams.Writer;
			path, string: String;
			i: SIZE;
		BEGIN {EXCLUSIVE}
			IF (state # AUTH) & (state # SELECT) THEN RETURN BAD END;
			NEW(buffer, 16);
			w := buffer.GetWriter();
			w.String("APPEND ");
			path := IMAPUtilities.NewString(mailbox);
			IMAPUtilities.MakeQuotedString(path);
			w.String(path^);
			i := IMAPUtilities.StringLength(message);
			w.String(" {");
			w.Int(i,0);
			w.String("}");
			string := buffer.GetString();
			RETURN SendContinuedCommand(string^, message, ret, state, state);
		END Append;

		(** copy specified in "what" to mailbox "to", works in SELECT, state not changed *)
		PROCEDURE UIDCopy*(what, to: ARRAY OF CHAR; VAR ret: Classes.List): SIGNED32;
		VAR
			buffer: Strings.Buffer;
			w: Streams.Writer;
			path,string: Strings.String;
		BEGIN {EXCLUSIVE}
			IF (state # SELECT) THEN RETURN BAD END;
			NEW(buffer, 16);
			w := buffer.GetWriter();
			w.String("UID COPY ");
			w.String(what);
			w.String(" ");
			path := IMAPUtilities.NewString(to);
			IMAPUtilities.MakeQuotedString(path);
			w.String(path^);
			string := buffer.GetString();
			RETURN SendToIMAPServer(string^,ret,state,state)
		END UIDCopy;

		(** close current mailbox *)
		PROCEDURE Close*():SIGNED32;
		BEGIN {EXCLUSIVE}
			COPY("CLOSE",buffer);
			RETURN SendToIMAPServer("CLOSE",ret,AUTH,state)
		END Close;

		(** noop operation, allow the server to send us status updates *)
		(** IMAP sends these from itself every few minutes, works in any state *)
		PROCEDURE Noop*(VAR ret: Classes.List):SIGNED32;
		BEGIN {EXCLUSIVE}
			RETURN SendToIMAPServer("NOOP",ret,state,state)
		END Noop;

		(* send status command to server *)
		PROCEDURE Status*(VAR mailbox, items: ARRAY OF CHAR; VAR ret: Classes.List):SIGNED32;
		VAR
			string: Strings.String;
			buffer: Strings.Buffer;
			w: Streams.Writer;
		BEGIN {EXCLUSIVE}
			IF (state # AUTH) & (state # SELECT) THEN RETURN BAD END;
			NEW(buffer, 16);
			w := buffer.GetWriter();
			string := MakeOneArgumentCommand("STATUS", mailbox);
			w.String(string^);
			w.String(" ");
			w.String(items);
			string := buffer.GetString();
			RETURN SendToIMAPServer(string^,ret,state,state)
		END Status;

		(* Search after criteria, see RFC 2060 *)
		PROCEDURE Search*(CONST criteria: ARRAY OF CHAR; VAR ret: Classes.List): SIGNED32;
		VAR
			buffer: Strings.Buffer;
			w: Streams.Writer;
			string: String;
		BEGIN {EXCLUSIVE}
			IF state # SELECT THEN RETURN BAD END;
			NEW(buffer, 16);
			w := buffer.GetWriter();
			w.String("SEARCH ");
			w.String(criteria);
			string := buffer.GetString();
			RETURN SendToIMAPServer(string^,ret,SELECT,state);
		END Search;

		(* get information about a message from server. information is specified by "items". *)
		PROCEDURE Fetch*(set: ARRAY OF CHAR; items: ARRAY OF CHAR;  VAR ret: Classes.List):SIGNED32;
		VAR
			buffer: Strings.Buffer;
			w: Streams.Writer;
			string: String;
		BEGIN {EXCLUSIVE}
			IF state # SELECT THEN RETURN BAD END;
			NEW(buffer, 16);
			w := buffer.GetWriter();
			w.String("FETCH ");
			w.String(set);
			w.String(" ");
			w.String(items);
			string := buffer.GetString();
			RETURN SendToIMAPServer(string^,ret,SELECT,SELECT)
		END Fetch;

		PROCEDURE UIDFetch*(set: ARRAY OF CHAR; items: ARRAY OF CHAR; VAR ret:Classes.List): SIGNED32;
		VAR
			buffer: Strings.Buffer;
			w: Streams.Writer;
			string: String;
		BEGIN {EXCLUSIVE}
			IF state # SELECT THEN RETURN BAD END;
			NEW(buffer, 16);
			w := buffer.GetWriter();
			w.String("UID FETCH ");
			w.String(set);
			w.String(" ");
			w.String(items);
			string := buffer.GetString();
			RETURN SendToIMAPServer(string^, ret, SELECT, state);
		END UIDFetch;

		(* store a specified flag on the server *)
		PROCEDURE UIDStore*(set: ARRAY OF CHAR; flags: ARRAY OF CHAR; plus: BOOLEAN; VAR ret: Classes.List):SIGNED32;
		VAR
			buffer: Strings.Buffer;
			w: Streams.Writer;
			string: String;
		BEGIN {EXCLUSIVE}
			IF state # SELECT THEN RETURN BAD END;
			NEW(buffer, 16);
			w := buffer.GetWriter();
			w.String("UID STORE ");
			w.String(set);
			IF plus THEN
				w.String(" +FLAGS (");
			ELSE
				w.String(" -FLAGS (");
			END;
			w.String(flags);
			w.String(")");
			string := buffer.GetString();
			RETURN SendToIMAPServer(string^,ret,SELECT,state)
		END UIDStore;

		(* parsing procedures *)

		(* append tag to command string and send it to the sender *)
		PROCEDURE SendIMAPCommand(command: ARRAY OF CHAR): BOOLEAN;
		VAR buffer: ARRAY 10 OF CHAR;
		BEGIN
			INC(tag);
			tagString := "AOS";
			Strings.IntToStr(tag,buffer);
			Strings.Append(tagString,buffer);
			out.String(tagString);out.String(" "); (* construct IMAP Tag and send it out *)
			out.String(command);out.Ln(); (* send command *)
			out.Update();
			IF DEBUG THEN
				KernelLog.String("IMAP: sending to server: <"); KernelLog.String(tagString);
				KernelLog.String(" "); KernelLog.String(command); KernelLog.String(">"); KernelLog.Ln
			END;
			RETURN out.res = Streams.Ok;
		END SendIMAPCommand;

		(* Checks if result code sent by IMAP Server is "OK" *)
		PROCEDURE CheckResultCode(list: Classes.List):BOOLEAN;
		VAR ent: Entry; entP:ANY;
		BEGIN
			entP := list.GetItem(list.GetCount()-1);ent := entP(Entry);
			RETURN ent.command = "OK";
		END CheckResultCode;

		PROCEDURE SendContinuedCommand(VAR command, continuation: ARRAY OF CHAR; VAR ret: Classes.List; newstate, failstate: SIGNED32): SIGNED32;
		BEGIN
			IF state = DEAD THEN RETURN BAD END;
			IF ~SendIMAPCommand(command) THEN
				RETURN SENDERR;
			END;
			IF ~ReadResponse(ret) THEN
				RETURN READBACKERR;
			END;
			IF ~SendContinuation(continuation) THEN
				RETURN SENDERR;
			END;
			IF ~ReadResponse(ret) THEN
				RETURN READBACKERR;
			END;
			IF CheckResultCode(ret) THEN
				state := newstate;
				RETURN OK;
			END;
			state := failstate;
			RETURN BAD;
		END SendContinuedCommand;

		PROCEDURE SendContinuation(VAR continuation: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			out.String(continuation);
			out.Ln();
			out.Update();
			RETURN out.res = Streams.Ok;
		END SendContinuation;

		(* internal send command, send command to server and syntactivally parse the return value of the server, generate
		the parsed Entry-List (see at the top). *)
		PROCEDURE SendToIMAPServer(command: ARRAY OF CHAR; VAR ret: Classes.List; newstate,failstate: SIGNED32):SIGNED32;
		BEGIN
			IF state = DEAD THEN RETURN BAD END; (* nothing to do without connection *)
			IF SendIMAPCommand(command) THEN (* send command to server *)
				IF ReadResponse(ret) THEN (* get and parse answer *)
					IF CheckResultCode(ret) THEN (* is return state = OK? -> go to new state *)
						state := newstate;
						IF DEBUG THEN KernelLog.String(" SUCCESS! state: "); KernelLog.Int(state,4); KernelLog.Ln;
							IF DEBUGLEVEL > 1 THEN DBGList(ret) END;
						END;
						RETURN OK; (* OK *)
					ELSE
						state := failstate; (* not ok -> fail state *)
						IF DEBUG THEN KernelLog.String(" FAILED GetResultCode! state: "); KernelLog.Int(state,4); KernelLog.Ln; END;
						RETURN BAD
					END;
				ELSE (* readback failed *)
					state := failstate;
					IF DEBUG THEN KernelLog.String(" FAILED ReadBack! state: "); KernelLog.Int(state,4); KernelLog.Ln; END;
					RETURN READBACKERR
				END;
			ELSE
				state := failstate;
				IF DEBUG THEN KernelLog.String(" FAILED Send state: "); KernelLog.Int(state,4); KernelLog.Ln; END;
				RETURN SENDERR; (* send failed *)
			END
		END SendToIMAPServer;

		(* Read response from IMAP Server and parse it *)
		PROCEDURE ReadResponse(VAR ret: Classes.List): BOOLEAN;
		VAR
			buffer, tag: String;
			i: SIGNED32;
		BEGIN
			(* Syntax of answer is tag-or-star SP [ number ]  status [SP "["response code"]"] SP text *)
			IF state = DEAD THEN RETURN FALSE END; (* perhaps, the server killed the connection... *)
			NEW(ret);
			REPEAT
				in.SkipWhitespace();
				IF in.res # Streams.Ok THEN
					IF DEBUG THEN KernelLog.String("IMAP: ReadResponse: Read failed at SkipWhiteSpace") END;
					RETURN FALSE
				END;
		        	IF ~ ReadToken(tag) THEN
		        		IF DEBUG THEN KernelLog.String("IMAP: ReadResponse: Read failed at ReadToken") END;
		        		RETURN FALSE;
		        	END;
		        	IF DEBUG THEN KernelLog.String("tag is: "); KernelLog.String(tag^); KernelLog.Ln END;
				IF (tag^ # "+") THEN
					IF ~ ReadUToken(buffer) THEN
						IF DEBUG THEN KernelLog.String("IMAP: ReadResponse: Read failed at ReadUtoken") END;
						RETURN FALSE;
					END;
					(* got number in buffer ?*)
					IF (buffer[0] >="0") & (buffer[0] <= "9") THEN
						Strings.StrToInt(buffer^,i);
						IF ~ ReadUToken(buffer) THEN (* get command *)
							IF DEBUG THEN KernelLog.String("IMAP: ReadResponse: Read failed at ReadUtoken2") END;
							RETURN FALSE;
						END;
						IF ~ Parse(buffer^,i,TRUE,ret) THEN
							IF DEBUG THEN KernelLog.String("IMAP: ReadResponse: Parse failed 1") END;
							RETURN FALSE;
						END;
					ELSE
						 IF ~ Parse(buffer^,-1,FALSE,ret) THEN RETURN FALSE END
					END;
				ELSE
					(* command continuation request response *)
					in.SkipLn();

					RETURN TRUE;
				END;
			UNTIL (tag^ = tagString) OR ((tagString = "") & (tag^ = "*") & (buffer^="OK")) OR (state = DEAD);
			(* IMAP ends a command with the tag except the welcome string ( * OK ) *)
			RETURN TRUE;
		END ReadResponse;

		PROCEDURE Parse(command: ARRAY OF CHAR; num:SIGNED32; numflag:BOOLEAN;
		VAR ret:Classes.List):BOOLEAN;
		(* result of command is given back by ret, all unsoliticed messages received while parsing answers to
		command are handled as SIDE EFFECT *)
		VAR
				dummy: BOOLEAN;
				i: SIGNED32;
				list: Classes.List;
				header, ent: Entry;
				content: Classes.List;
				ent2, ent3: Entry;
		BEGIN
			IF DEBUG THEN KernelLog.String("IMAP: Parse: command is "); KernelLog.String(command); KernelLog.Ln END;
			i := 0;
			NEW(header);
			IF numflag THEN
				header.number := num
			END;
			header.type := HEADER;
			header.data := NIL;
			header.list := NIL;
			COPY(command,header.command);
			ret.Add(header);
			IF ~ReadResponseCode() THEN RETURN FALSE END;

			IF command = "CAPABILITY" THEN (* IMAP Server sends it's capability string, save for later use *)
				WHILE ~in.EOLN() DO
					NEW(ent);
					IF ~ReadAtom(ent.data) THEN RETURN FALSE END;
					IF DEBUG THEN KernelLog.String("IMAP: Parse: Capability: "); KernelLog.String(ent.data^); KernelLog.Ln END;
					in.SkipBytes(1);
					ent.type := ATOM;
					ret.Add(ent);
					capability := ret
				END;

			ELSIF command = "EXISTS" THEN (* IMAP Server sends how many messages there are, also save *)
				RETURN TRUE; (* no need to skip white spaces, we're at the end of the line anyway *)

			ELSIF command = "EXPUNGE" THEN RETURN TRUE;

			ELSIF command = "FETCH" THEN
				NEW(list);
				IF ~ReadList(list) THEN RETURN FALSE END;
				header.list := list;

			ELSIF command = "FLAGS" THEN
				NEW(list);
				IF ~ReadList(list) THEN RETURN FALSE END;
				header.list := list;

			ELSIF command = "RECENT" THEN
				RETURN TRUE; (* already at the end of the line -> return *)

			ELSIF command = "STATUS" THEN
				IF in.Peek() = 22X THEN (* " *)
					IF ~ReadQuotedString(header.data) THEN RETURN FALSE; END;
				ELSE
					IF ~ReadAtom(header.data) THEN RETURN FALSE; END;
				END;
				NEW(list);
				IF ~ReadList(list) THEN RETURN FALSE END;
				header.list := list;
				IF DEBUG THEN DBGList(list) END;

			ELSIF (command = "SORT") OR (command = "SEARCH") THEN
				NEW(list);
					IF in.Peek() # 0DX THEN
						IF ~ReadNumberEnumeration(list) THEN HALT(333); RETURN FALSE END;
					END;
				header.list := list;

			ELSIF command = "BAD" THEN
				IF DEBUG THEN KernelLog.String("IMAP: server said: BAD"); KernelLog.Ln END;
				dummy := NextLine(); (* skip to next line whenever possible *)
				RETURN FALSE;

			ELSIF command = "BYE" THEN
				IF ~logout THEN
					(* kill connection immediatly *)
					state := DEAD;
					IF DEBUG THEN KernelLog.String("IMAP: kicked out by server"); KernelLog.Ln END;
					connection.Close; connection := NIL;
					RETURN FALSE; (* server has closed connection now, so do we... *)

				END;

			ELSIF (command = "LIST")  THEN
				NEW(list);
				IF ~ReadList(list) THEN RETURN FALSE END;
				NEW(ent);
				ent.type := LIST;
				ent.list := list;
				NEW(content);
				content.Add(ent);

				in.SkipWhitespace();
				NEW(ent2);
				IF in.Peek() = 22X THEN
					IF ~ReadQuotedString(ent2.data) THEN RETURN FALSE END;
				ELSIF in.Peek() = "{" THEN
					IF ~ReadLiteral(ent2.data) THEN RETURN FALSE END;
				ELSE
					IF ~ReadAtom(ent2.data) THEN RETURN FALSE END;
				END;
				content.Add(ent2);

				in.SkipWhitespace();
				NEW(ent3);
				IF in.Peek() = 22X THEN
					IF ~ReadQuotedString(ent3.data) THEN RETURN FALSE END;
				ELSIF in.Peek() = "{" THEN
					IF ~ReadLiteral(ent3.data) THEN RETURN FALSE END;
				ELSE
					IF ~ReadAtom(ent3.data) THEN RETURN FALSE END;
				END;
				content.Add(ent3);


				header.list := content;
				header.type := LIST;
				IF DEBUG THEN DBGList(content) END;

			ELSIF (command = "LSUB")   THEN
				KernelLog.String(command);KernelLog.String(": Not yet implemented");KernelLog.Ln;
				HALT(999);

			ELSIF (command = "PREAUTH") THEN
				state := AUTH;

			ELSIF (command = "OK") THEN
			(* no need to do anything... *)

			ELSIF (command = "NO") THEN
				IF DEBUG THEN KernelLog.String("IMAP: server said: NO"); KernelLog.Ln END;
				RETURN FALSE;

			ELSE
				KernelLog.String("IMAP: unknown keyword <<"); KernelLog.String(command);
				KernelLog.String(">>. This is a IMAP parser error..."); KernelLog.Ln;
				RETURN FALSE
			END;

			(* go ahead to next line, skip garbage *)
			IF ~NextLine() THEN RETURN FALSE END;
			RETURN TRUE; (* everything is ok *)
		END Parse;

		(* read text in [] and parse it's content *)
		PROCEDURE ReadResponseCode():BOOLEAN;
		VAR
			command,argument: String;
			argi: SIGNED32;
			list,ret: Classes.List;
			ent: Entry;
		BEGIN
			in.SkipSpaces();
			IF in.res # Streams.Ok THEN
				IF DEBUG THEN 	KernelLog.String("IMAP: ReadResponseCode failed"); KernelLog.Ln; END;
				RETURN FALSE END;
			IF in.Peek() # "[" THEN
				(* no response code *)
					IF DEBUG THEN KernelLog.String("No response code available");KernelLog.Ln; END;
					RETURN TRUE;
			ELSE
				in.SkipBytes(1);
				IF in.res # Streams.Ok THEN RETURN FALSE END;
				IF ~ReadPToken(command) THEN
					IF DEBUG THEN KernelLog.String("IMAP: ReadResponseCode: ReadPToken failed "); KernelLog.Ln; END;
					RETURN FALSE
				END;
				ASSERT(command#NIL,1011);
				in.SkipWhitespace();
				IF in.res # Streams.Ok THEN RETURN FALSE END;

				IF command^ = "ALERT" THEN
					(* not supported and skipped *)
					in.SkipBytes(1);(* ] *)
					in.SkipWhitespace();
					IF in.res # Streams.Ok THEN RETURN FALSE END;
					IF ~ReadText(argument) THEN RETURN FALSE END;
					(* alert message is in argument *)

				ELSIF command^ = "NEWNAME" THEN
					(* not supported, will just skip text... *)
					in.SkipLn();

				ELSIF command^ = "PARSE" THEN
					(* skipped *)
					in.SkipBytes(1);(* ] *)
					in.SkipWhitespace();
					IF ~ReadText(argument) THEN RETURN FALSE END;

				ELSIF command^ = "PERMANENTFLAGS" THEN
					(* store in folder structure *)
					in.SkipWhitespace();
					NEW(list);
					IF ~ReadList(list) THEN RETURN FALSE END;

				ELSIF command^ = "READ-ONLY" THEN

				ELSIF command^ = "READ-WRITE" THEN

				ELSIF command^ = "TRYCREATE" THEN
					(* informational only, just ignore :-*)
					in.SkipLn();

				ELSIF command^ = "UIDVALIDITY" THEN
					IF ~ReadPToken(argument) THEN RETURN FALSE END;
					Strings.StrToInt(argument^,argi);

				ELSIF command^ = "UIDNEXT" THEN
					IF ~ReadPToken(argument) THEN RETURN FALSE END;
					Strings.StrToInt(argument^,argi);

				ELSIF command^ = "UNSEEN" THEN
					IF ~ReadPToken(argument) THEN RETURN FALSE END;
					Strings.StrToInt(argument^,argi);

				ELSIF command^ = "CAPABILITY" THEN
					NEW(ret);
					WHILE (in.Peek() # "]") DO
						NEW(ent);
						IF ~ReadPToken(ent.data) THEN RETURN FALSE END;
						ent.type := ATOM;
						ret.Add(ent)
					END;
				ELSIF command^ = "COPYUID" THEN
					(* ignore *)
					WHILE (in.Get() # "]" ) DO
					END;
				ELSIF command^ = "APPENDUID" THEN
					(* ignore *)
					WHILE (in.Get() # "]" ) DO
					END;

				ELSE
					IF DEBUG THEN
						KernelLog.String("IMAP: ReadResponseCode: unknown response code: ");
						KernelLog.String("->");KernelLog.String(command^);
						KernelLog.String("<-");KernelLog.Ln
					END;
				END
			END;
			RETURN TRUE
		END ReadResponseCode;

		(* skip to next line *)
		PROCEDURE NextLine():BOOLEAN;
		BEGIN
				in.SkipLn();
				RETURN in.res = Streams.Ok;
		END NextLine;

		(* read text until end of line reached *)
		PROCEDURE ReadText(VAR text: String):BOOLEAN;
		VAR
			b: Strings.Buffer;
			w: Streams.Writer;
			c: CHAR;
		BEGIN
			NEW(b, 16);
			w := b.GetWriter();
			WHILE ~in.EOLN() DO (* read until end of line *)
				c := in.Get();
				IF in.res # Streams.Ok THEN RETURN FALSE END;
				IF c ="\" THEN (* escaped char *)
					c := in.Get();
					IF in.res # Streams.Ok THEN RETURN FALSE END
				END;
				w.Char(c);
			END;
			text := b.GetString();
			RETURN TRUE
		END ReadText;

		PROCEDURE ReadNumberEnumeration(VAR list: Classes.List):BOOLEAN;
		VAR
			ent: Entry;
			size: SIGNED32;
		BEGIN
			NEW(ent);
			size := 0;
			in.SkipWhitespace();
			WHILE in.Peek() # 0DX DO
				IF ~ReadAtom(ent.data) THEN KernelLog.String("RNE failed"); RETURN FALSE; END;
				ASSERT(ent.data # NIL, 999);
				list.Add(ent);
				NEW(ent);
				INC(size);
				ASSERT(size < 2500000, 666);
				IF in.Peek() # 0DX THEN
					in.SkipWhitespace();
				END;
			END;
			RETURN size #  0;
		END ReadNumberEnumeration;

		(* read IMAP formatted list *)
		PROCEDURE ReadList(VAR list: Classes.List):BOOLEAN;
		VAR
			ent: Entry;
			nlist: Classes.List;
		BEGIN
			in.SkipSpaces();
			IF ~(in.res=Streams.Ok) THEN RETURN FALSE END;
			IF in.Peek() # "(" THEN RETURN FALSE END; (* list starts with ( *)
			in.SkipBytes(1);
			IF in.res # Streams.Ok THEN RETURN FALSE END;
			ASSERT( in.Peek() # 0DX,1012);

			WHILE in.Peek() # ")" DO (* list ends with ) *)
				NEW(ent);
				in.SkipSpaces();
				IF in.res # Streams.Ok THEN RETURN FALSE END;

				IF in.Peek() = "{" THEN
					IF ~ReadLiteral(ent.data) THEN RETURN FALSE END;
					ent.type :=  LITERAL;
					ent.list := NIL;
				ELSIF in.Peek() = 22X THEN (* " *)
					IF ~ReadQuotedString(ent.data) THEN RETURN FALSE END;
					ent.type := STRING;
					ent.list := NIL;
				ELSIF in.Peek() = "(" THEN
					NEW(nlist);
					IF ~ReadList(nlist) THEN RETURN FALSE END;
					ent.list := nlist;
					ent.data := NIL;
					ent.type := LIST;
				ELSIF in.EOLN() THEN
					RETURN FALSE;
				ELSE
					IF ~ReadAtom(ent.data) THEN RETURN FALSE END;
					ent.type := ATOM;
					ent.list := NIL
				END;
				(* now either " " or ) OR eoln.  *)
				IF in.EOLN() THEN RETURN FALSE END;
				list.Add(ent);
				IF ~in.EOLN() THEN
					in.SkipSpaces();
					IF in.res # Streams.Ok THEN RETURN FALSE END;
				END;
			END;
			IF ~in.EOLN() & (in.Peek() = ")") THEN in.SkipBytes(1) END;
			RETURN in.res = Streams.Ok;
		END ReadList;

		(* read IMAP Literal: zero or more bytes prepended with size in {} *)
		PROCEDURE ReadLiteral(VAR buffer:String): BOOLEAN;
		VAR
			data: ARRAY 80 OF CHAR;
			i,size: SIGNED32; len: SIZE;
		BEGIN
			i := 0;
			ASSERT(in.Peek() = "{",1013);
			in.SkipBytes(1);
			WHILE ((in.Peek() # "}") & ~in.EOLN() & (i<256)) DO
				data[i]:= in.Get();
				INC(i);
			END;
			IF (in.Peek() # "}") THEN RETURN FALSE END;
			Strings.StrToInt(data,size);
			in.SkipLn();
			IF ~(in.res=Streams.Ok) THEN RETURN FALSE END;
			NEW(buffer,size+1);
			in.Bytes(buffer^,0,size,len);
			IF ~(in.res=Streams.Ok) THEN RETURN FALSE END;
			IF size=len THEN
				buffer^[size] := 0X;
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END;
		END ReadLiteral;

		(* read IMAP quoted string: sequence of zero or more 7bit chars, " at each end *)
		PROCEDURE ReadQuotedString(VAR buffer:String): BOOLEAN;
		(* Read Quoted String *)
		VAR
			b: Strings.Buffer;
			w: Streams.Writer;
			c: CHAR;
		BEGIN
			NEW(b, 16);
			w := b.GetWriter();
			ASSERT(in.Peek() = 22X,1014);
			in.SkipBytes(1);
			WHILE ((in.Peek() # 22X) & ~in.EOLN()) DO
				c := in.Get();
				IF ~(in.res=Streams.Ok) THEN RETURN FALSE END;
				IF c="\" THEN (* escaped char *)
					c := in.Get();
					IF ~(in.res=Streams.Ok) THEN RETURN FALSE END;
				END;
				w.Char(c);

			END;
			in.SkipBytes(1);
			IF ~(in.res=Streams.Ok) THEN RETURN FALSE END;
			buffer := b.GetString();
			RETURN TRUE;
		END ReadQuotedString;

		(* read IMAP atom, zero or more nonspecial characters see RFC2060 *)
		PROCEDURE ReadAtom(VAR buffer:String): BOOLEAN;
		VAR
			b: Strings.Buffer;
			w: Streams.Writer;
			end: BOOLEAN;
		BEGIN
			NEW(b, 16);
			w := b.GetWriter();
			IF in.Peek() ="\" THEN RETURN ReadFlag(buffer) END; (* if it starts with an \, it must be a flag... *)
			ASSERT (in.Peek() # 0DX,1015);
			end := FALSE;
			WHILE ((in.Peek() # " ") & ~in.EOLN() & (in.Peek() # "(") & (in.Peek() # ")") & (in.Peek() # "{") & (in.Peek() # "*")
						& (in.Peek() # "%") & (in.Peek() # "\")) DO
				ASSERT (in.Peek() # 0DX,1017);
				w.Char(in.Get());
				IF ~(in.res=Streams.Ok) THEN RETURN FALSE END;
			END;
			buffer := b.GetString();
			RETURN TRUE;
		END ReadAtom;

		PROCEDURE ReadFlag(VAR buffer:String): BOOLEAN;
		(* same for flag *)
		VAR
			b: Strings.Buffer;
			w: Streams.Writer;
			i: SIGNED32;
			end: BOOLEAN;
		BEGIN
			NEW(b, 16);
			w := b.GetWriter();
			ASSERT (in.Peek() # 0DX,1018);
			end := FALSE;
			WHILE ((in.Peek() # " ") & ~in.EOLN() & (in.Peek() # "(") & (in.Peek() # ")") & (in.Peek() # "{")
						& (in.Peek() # "%") & ~ end) DO (* stop chars !!! *)  (*(Streams.Peek(in) # "\") *)

				ASSERT (in.Peek() # 0DX,1020);
				IF ((in.Peek() = "\") & (i>1)) THEN end := TRUE END; (* hack for \atom in flags *)
				w.Char(in.Get());
				IF ~(in.res=Streams.Ok) THEN RETURN FALSE END;
				INC(i);
			END;
			buffer := b.GetString();
			Strings.UpperCase(buffer^);
			RETURN TRUE;
		END ReadFlag;

		(* read token, ended by space *)
		PROCEDURE ReadToken(VAR token: String):BOOLEAN;
		VAR
			b: Strings.Buffer;
			w: Streams.Writer;
			c: CHAR;
			i: SIGNED32;
		BEGIN
			NEW(b,16);
			w := b.GetWriter();
			i := 0;
			in.SkipWhitespace();
			WHILE ((in.Peek() # " ") & (~ in.EOLN())) DO
				ASSERT (in.Peek() # 0DX,1021);
				w.Char(in.Get());
				INC(i);
			END;
			IF ~ in.EOLN() THEN
				c := in.Get(); (* overread space (ignored) *)
			END;
			token := b.GetString();
			RETURN i # 0;
		END ReadToken;

		(* Read token and convert to uppercase *)
		PROCEDURE ReadUToken(VAR resp: String):BOOLEAN;
		BEGIN
			IF ReadToken(resp) THEN
				IMAPUtilities.UpperCase(resp^);
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END
		END ReadUToken;

		(* read token in [] *)
		PROCEDURE ReadPToken(VAR buffer: String):BOOLEAN;
		VAR
			b: Strings.Buffer;
			w: Streams.Writer;
		BEGIN
			NEW(b, 16);
			w := b.GetWriter();

			ASSERT (in.Peek() # 0DX,1022);
			in.SkipWhitespace();
			IF in.res # Streams.Ok THEN RETURN FALSE END;
			WHILE ((in.Peek() # " ") & ~in.EOLN() & (in.Peek() # "]")) DO

				ASSERT (in.Peek() # 0DX,1023);
				w.Char(in.Get());
				IF in.res # Streams.Ok THEN RETURN FALSE END;
			END;
			buffer := b.GetString();
			RETURN TRUE;
		END ReadPToken;

		(* DEBUG Procedures *)

		(* print human readable version of parsed list *)
		PROCEDURE DBGList*(VAR listP: Classes.List);
		VAR
			ent: Entry;
			entP: ANY;
			text: String;
			i: SIZE;
			list: Classes.List;
		BEGIN
			ASSERT(listP # NIL,1024);
			list := listP(Classes.List);
			KernelLog.String("-> processing list:"); KernelLog.Ln;
			FOR i := 0 TO list.GetCount()-1 DO
				entP := list.GetItem(i);ent := entP(Entry);
				IF ent.type=LITERAL THEN
					text := ent.data;
					DBGLiteral(ent.data);
				ELSIF ent.type=STRING THEN
					DBGString(ent.data);
				ELSIF ent.type=ATOM THEN
					DBGAtom(ent.data);
				ELSIF ent.type=LIST THEN
					DBGList(ent.list);
				ELSIF ent.type=HEADER THEN
					KernelLog.String("HEADER");KernelLog.Ln;
					KernelLog.String(ent.command);KernelLog.Ln;
					KernelLog.String("Number");
					KernelLog.Int(ent.number,5);KernelLog.Ln;
					IF ent.list # NIL THEN
						DBGList(ent.list);
					END;
				ELSE
					HALT(1028);
				END;
			END;
			KernelLog.String("<- processing list finished:"); KernelLog.Ln;
		END DBGList;

		PROCEDURE DBGLiteral(VAR text:String);
		VAR
			i,j: SIZE;
		BEGIN
			KernelLog.String("processing Literal:");KernelLog.Ln;
			j := IMAPUtilities.StringLength(text^);
			FOR i := 0 TO j-1 DO
				KernelLog.Char(text^[i]);
			END;
			KernelLog.Ln;
		END DBGLiteral;

		PROCEDURE DBGString(VAR text:String);
		BEGIN
			KernelLog.String("processing String:");KernelLog.Ln;
			KernelLog.String(text^);KernelLog.Ln;
		END DBGString;

		PROCEDURE DBGAtom(VAR text:String);
		BEGIN
			KernelLog.String("processing Atom:");KernelLog.Ln;
			KernelLog.String(text^);KernelLog.Ln;
		END DBGAtom;


	END Connection;


	(* To make IMAP Mail-Compatible, one has to implement following procedure

	PROCEDURE GetMailMessage(message: SIGNED32):Mail.Message;

	one could implement this for full RFC2060 conformance:

	PROCEDURE Authenticate();
	PROCEDURE StartTLS();

	*)

END IMAP.
