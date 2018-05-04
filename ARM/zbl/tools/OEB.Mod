MODULE OEB;
(**
	AUTHOR Timothée Martiel, 05/2016
	PURPOSE Commands for controlling OEB Host servers
*)

IMPORT
	Commands, Options, Streams, Strings, FoxBasic, Files,
	OEBInterfaces, OEBServers,
	OEBInteractiveServers, OEBLoopbackInterfaces;

CONST
	ShellRunning * = 0;
	ShellClosed * = 1;

	MaxCmdLen* = 1024;

TYPE
	Shell * = OBJECT
	CONST
		HistorySize = 128;
		PromptSymbol = "% ";

		CR = 0DX; LF = 0AX; TAB = 9X;
		Backspace = 08X;
		Space = 20X;
		Delete = 7FX;
		Escape = 1BX;

		EscapeChar1 = Escape;
		EscapeChar2 = '[';

		(* Non-ASCII characters *)
		CursorUp = 0C1X;
		CursorDown = 0C2X;

	VAR
		in: Streams.Reader;
		out: Streams.Writer;
		server: OEBInteractiveServers.Server;
		session: OEBInterfaces.Session;
		history: POINTER TO ARRAY OF ARRAY 128 OF CHAR;
		prompt: ARRAY 128 OF CHAR;
		id, state: LONGINT;
		pos, tail: LONGINT; (* history positions *)

		PROCEDURE & Init * (sid, id: LONGINT; in: Streams.Reader; out: Streams.Writer; VAR res: LONGINT);
		VAR
			s: OEBServers.Server;
		BEGIN
			SELF.in := in;
			SELF.out := out;
			SELF.id := id;
			s := servers.Get(sid)(OEBServers.Server);
			IF ~(s IS OEBInteractiveServers.Server) THEN
				res := 1;
				RETURN
			END;
			server := s(OEBInteractiveServers.Server);
			session := server.GetSession(id);
			COPY(session.name, prompt);
			Strings.Append(prompt, PromptSymbol);
			NEW(history, HistorySize);
		END Init;

		PROCEDURE Close *;
		BEGIN {EXCLUSIVE}
			state := ShellClosed
		END Close;

		PROCEDURE State * (): LONGINT;
		BEGIN {EXCLUSIVE}
			RETURN state
		END State;

		(* Taken from Shell.Mod *)
		PROCEDURE DeleteStringFromDisplay(CONST x : ARRAY OF CHAR);
		VAR i, len : LONGINT;
		BEGIN
			len := Strings.Length(x);
			FOR i :=	 0 TO len-1 DO out.Char(Backspace); END;
			FOR i :=	 0 TO len-1 DO out.Char(Space); END;
			FOR i :=	 0 TO len-1 DO out.Char(Backspace); END;
		END DeleteStringFromDisplay;

		(* Taken from Shell.Mod *)
		PROCEDURE ReadCommand(VAR command : ARRAY OF CHAR);
		VAR
			ch: CHAR;
			currentIndex : LONGINT;

			PROCEDURE IsAsciiCharacter(ch : CHAR) : BOOLEAN;
			BEGIN
				RETURN ORD(ch) <= 127;
			END IsAsciiCharacter;

			PROCEDURE IsControlCharacter(ch : CHAR) : BOOLEAN;
			BEGIN
				RETURN ORD(ch) < 32;
			END IsControlCharacter;

			PROCEDURE HandleEscapeSequence;
			BEGIN
				ch := in.Get();
				ch := CHR(ORD(ch)+128);

				IF (ch = CursorDown) OR (ch = CursorUp) THEN (* Command History Keys *)

					command[currentIndex+1] := 0X;
					DeleteStringFromDisplay(command);

					IF ch = CursorUp THEN
						DEC(pos)
					ELSE
						INC(pos)
					END;
					COPY(history[pos], command);
					currentIndex := Strings.Length(command)-1;
					IF (command # "") THEN out.String(command); out.Update; END;
				ELSE
					(* ignore escaped character *)
				END;
			END HandleEscapeSequence;

		BEGIN
			command := ""; currentIndex := -1;

			LOOP
				ch := in.Get();

				IF IsAsciiCharacter(ch) THEN

					IF IsControlCharacter(ch) OR (ch = Delete) THEN

						IF (ch = CR) OR (ch = LF) OR (ch = Streams.EOT) OR (in.res # Streams.Ok) THEN
							EXIT

						ELSIF (ch = Backspace) OR (ch = Delete)THEN
							IF currentIndex >= 0 THEN (* There is a character at the left of the cursor *)
								command[currentIndex] := 0X;
								DEC(currentIndex);
								out.Char(Backspace); out.Char(Space); out.Char(Backspace); out.Update;
							END;
						ELSIF (ORD(ch) = 03H) THEN
						(*	IF runner # NIL THEN AosActive.TerminateThis(runner); END; *)
						ELSIF (ch = EscapeChar1) THEN (* Escape sequence *)
							IF in.Peek() = EscapeChar2 THEN ch := in.Get(); HandleEscapeSequence;
							ELSIF in.Peek () = Escape THEN
								command[currentIndex+1] := 0X;
								DeleteStringFromDisplay (command); out.Update;
								ch := in.Get (); command := ""; currentIndex := -1;
							END;
						ELSE
							(* ignore other control characters *)
						END;

					ELSE
						IF currentIndex <= LEN(command) - 2 (* Always need space for 0X *) THEN
							INC(currentIndex);
							command[currentIndex] := ch;
							out.Char(ch); out.Update
						END;
					END;

				ELSE
					(* ignore non-ascii characters *)
				END;
			END;

			command[currentIndex+1] := 0X;

			IF ch = CR THEN
				IF (in.Available() > 0) & (in.Peek() = LF) THEN ch := in.Get() END;
				out.Ln; out.Update
			END;
		END ReadCommand;

		PROCEDURE ExecuteCommand;
		VAR
			reply: ARRAY 128 OF CHAR;
			res: LONGINT;
		BEGIN
			res := server.ExecuteCommand(id, history[tail MOD HistorySize], reply);
			out.Ln;
			out.String(reply);
			out.Ln
		END ExecuteCommand;

		PROCEDURE Run;
		BEGIN
			WHILE State() = ShellRunning DO
				out.String(prompt);
				out.Update;
				ReadCommand(history[tail]);
				ExecuteCommand;
				INC(tail);
				tail := tail MOD HistorySize;
				pos := tail;
			END;
		END Run;

	BEGIN {ACTIVE}
		Run
	END Shell;

	(* New Interface *)
VAR
	servers: FoxBasic.List;

	(**
		OEB.NewServer --type=string [...] ~
	*)
	PROCEDURE NewServer * (context : Commands.Context);
	VAR
		param: POINTER TO ARRAY OF CHAR;
		type: ARRAY 128 OF CHAR;
		len: LONGINT;
		opt: Options.Options;
		s: OEBServers.Server;
	BEGIN
		NEW(opt);
		opt.Add('t', "type", Options.String);
		IF ~opt.Parse(context.arg, context.error) THEN
			context.result := 1;
			RETURN
		END;

		IF opt.GetString("type", type) THEN
			context.arg.SkipWhitespace;
			NEW(param, context.arg.Available() + 1);
			context.arg.Bytes(param^, 0, LEN(param) - 1, len);
			ASSERT(len = LEN(param) - 1);
			s := OEBServers.NewServer(type, param^);
			servers.Add(s);

			context.out.String("New server created with id #");
			context.out.Int(servers.IndexOf(s), 0);
			context.out.Ln
		ELSE
			context.error.String("Error: missing --type option");
			context.error.Ln;
			context.result := 2;
			RETURN
		END
	END NewServer;

	(**
		OEB.Server [--show] [--start] [--stop] [-a|--all] {#} ~
	*)
	PROCEDURE Server*(context : Commands.Context);
	VAR
		opt: Options.Options;
		server: OEBServers.Server;
		ids: FoxBasic.IntegerList;
		i, s: LONGINT;
		all, kill, show, start, stop: BOOLEAN;
	BEGIN
		NEW(opt);
		opt.Add('a', "all", Options.Flag);
		opt.Add(0X, "kill", Options.Flag);
		opt.Add(0X, "show", Options.Flag);
		opt.Add(0X, "start", Options.Flag);
		opt.Add(0X, "stop", Options.Flag);
		IF ~opt.Parse(context.arg, context.error) THEN
			context.result := 1;
			RETURN
		END;
		all := opt.GetFlag("all");
		kill := opt.GetFlag("kill");
		show := opt.GetFlag("show");
		start := opt.GetFlag("start");
		stop := opt.GetFlag("stop");
		IF start & stop OR start & kill OR kill & stop THEN
			context.error.String("Error: can only do one of start, stop and kill");
			context.error.Ln;
			context.result := 2;
			RETURN
		END;

		NEW(ids, 16);
		IF ~all THEN
			WHILE context.arg.GetInteger(s, FALSE) DO ids.Add(s) END;
		END;

		IF all & (servers.Length() = 0) THEN
			context.out.String("No Server");
			context.out.Ln;
			RETURN
		END;

		FOR i := 0 TO servers.Length() - 1 DO
			IF all OR ids.Contains(i) THEN
				server := servers.Get(i)(OEBServers.Server);
				IF show THEN ShowServer(server, i, context.out); context.out.Ln END;
				IF start THEN server.Start END;
				IF stop THEN server.Stop END;
				IF kill THEN server.Kill END;
				ids.Remove(i);
			END
		END;
		FOR i := 0 TO ids.Length() - 1 DO
			context.error.String("Error: server #");
			context.error.Int(ids.Get(i), 0);
			context.error.String(" does not exist");
			context.error.Ln;
			context.result := 3;
		END
	END Server;

	(**
		OEB.NewInterface --type=Udp --server=# netmask ~
		OEB.NewInterface --type=Serial --server=# {port} ~
		OEB.NewInterface --type=Loopback --server=# guid ~
	*)
	PROCEDURE NewInterface*(context : Commands.Context);
	VAR
		opt: Options.Options;
		itf: OEBInterfaces.Interface;
		param: POINTER TO ARRAY OF CHAR;
		type: ARRAY 128 OF CHAR;
		id, len: LONGINT;
	BEGIN
		NEW(opt);
		opt.Add('t', "type", Options.String);
		opt.Add('s', "server", Options.Integer);
		IF ~opt.Parse(context.arg, context.error) THEN
			context.result := 1;
			RETURN
		END;

		IF ~opt.GetString("type", type) THEN
			context.error.String("Error: missing interface type");
			context.error.Ln;
			context.result := 2;
			RETURN
		END;
		IF ~opt.GetInteger("server", id) THEN
			context.error.String("Error: missing server #");
			context.error.Ln;
			context.result := 3;
			RETURN
		END;
		IF (id > servers.Length()) OR (servers.Get(id) = NIL) THEN
			context.error.String("Error: server #");
			context.error.Int(id, 0);
			context.error.String(" does not exist");
			context.error.Ln;
			context.result := 4;
			RETURN
		END;

		(*IF type = "Udp" THEN
			NEW(udp);
			itf := udp
		ELSIF type = "Serial" THEN
			NEW(ser);
			itf := ser
		ELSIF type = "Loopback" THEN
			NEW(lb);
			itf := lb
		END;*)
		context.arg.SkipWhitespace;
		NEW(param, context.arg.Available() + 1);
		context.arg.Bytes(param^, 0, LEN(param) - 1, len);
		ASSERT(len = LEN(param) - 1);
		itf := OEBInterfaces.NewInterface(type, param^);
		servers.Get(id)(OEBServers.Server).AddInterface(itf)
	END NewInterface;

	(**
		OEB.Interface --show --start --stop --kill --connect --disconnect --server=# [--all] {#} ~
		connect and disconnect for loopbacks only
	*)
	PROCEDURE Interface*(context : Commands.Context);
	VAR
		opt: Options.Options;
		server: OEBServers.Server;
		itf: OEBInterfaces.Interface;
		ids: FoxBasic.IntegerList;
		sid, id: LONGINT;
		all, connect, disconnect, kill, show, start, stop: BOOLEAN;
	BEGIN
		NEW(opt);
		opt.Add('a', "all", Options.Flag);
		opt.Add(0X, "connect", Options.Flag);
		opt.Add(0X, "disconnect", Options.Flag);
		opt.Add(0X, "kill", Options.Flag);
		opt.Add(0X, "show", Options.Flag);
		opt.Add(0X, "start", Options.Flag);
		opt.Add(0X, "stop", Options.Flag);
		opt.Add('s', "server", Options.Integer);
		IF ~opt.Parse(context.arg, context.out) THEN
			context.result := 1;
			RETURN
		END;
		all := opt.GetFlag("all");
		connect := opt.GetFlag("connect");
		disconnect := opt.GetFlag("disconnect");
		kill := opt.GetFlag("kill");
		show := opt.GetFlag("show");
		start := opt.GetFlag("start");
		stop := opt.GetFlag("stop");
		IF start & kill OR start & stop OR kill & stop THEN
			context.error.String("Error: cannot do more than 1 of these operations: start, stop, kill");
			context.error.Ln;
			context.result := 2;
			RETURN
		END;
		IF connect & disconnect THEN
			context.error.String("Error: cannot connect and disconnect at the same time");
			context.error.Ln;
			context.result := 6;
			RETURN
		END;

		IF ~opt.GetInteger("server", sid) THEN
			context.error.String("Error: no server specified");
			context.error.Ln;
			context.result := 3;
			RETURN
		END;
		IF (sid >= servers.Length()) OR (servers.Get(sid) = NIL) THEN
			context.error.String("Error: server not found");
			context.error.Ln;
			context.result := 4;
			RETURN
		END;
		server := servers.Get(sid)(OEBServers.Server);

		NEW(ids, 16);
		IF ~all THEN
			WHILE context.arg.GetInteger(id, FALSE) DO ids.Add(id) END
		END;

		id := 0;
		itf := server.interfaces;
		IF all & (itf = NIL) THEN
			context.out.String("No Interfaces");
			context.out.Ln;
			RETURN
		END;
		WHILE (itf # NIL) DO
			IF all OR ids.Contains(id) THEN
				IF show THEN ShowInterface(itf, sid, id, context.out); context.out.Ln END;
				IF connect & (itf IS OEBLoopbackInterfaces.Interface) THEN itf(OEBLoopbackInterfaces.Interface).Connect END;
				IF disconnect & (itf IS OEBLoopbackInterfaces.Interface) THEN itf(OEBLoopbackInterfaces.Interface).Disconnect END;
				IF start THEN itf.Start END;
				IF stop THEN itf.Stop END;
				IF kill THEN itf.Kill END
			END;
			ids.Remove(id);
			itf := itf.next;
			INC(id)
		END;
		FOR id := 0 TO ids.Length() - 1 DO
			context.error.String("Error: could not find interface #");
			context.error.Int(ids.Get(id), 0);
			context.error.Ln;
			context.result := 5
		END
	END Interface;

	(**
		OEB.ListSessions --all {server#} ~
	*)
	PROCEDURE ListSessions*(context : Commands.Context);
	VAR
		opt: Options.Options;
		sids: FoxBasic.IntegerList;
		server: OEBServers.Server;
		itf: OEBInterfaces.Interface;
		session: OEBInterfaces.Session;
		id, sid: LONGINT;
		all: BOOLEAN;
	BEGIN
		NEW(opt);
		opt.Add('a', "all", Options.Flag);
		IF ~opt.Parse(context.arg, context.error) THEN
			context.result := 1;
			RETURN
		END;

		all := opt.GetFlag("all");
		NEW(sids, 16);
		IF ~all THEN
			WHILE context.arg.GetInteger(sid, FALSE) DO sids.Add(sid) END
		END;

		FOR sid := 0 TO servers.Length() - 1 DO
			IF all OR sids.Contains(sid) THEN
				server := servers.Get(sid)(OEBServers.Server);
				itf := server.interfaces;
				WHILE itf # NIL DO
					session := itf.sessions;
					WHILE session # NIL DO
						ShowSession(server, session, sid, id, context.out);
						context.out.Ln;
						session := session.next;
						INC(id)
					END;
					itf := itf.next
				END
			END
		END;
	END ListSessions;

	(**
		OEB.Session --show [--close] [--guid=#] [--id=# --server=#] [name] ~
	*)
	PROCEDURE Session*(context : Commands.Context);
	BEGIN

	END Session;

	(*
		Execute "deployfile" command which performs a combination of "load" and "deploy file" commands 

		Remark: it is assumed that command string is whitespace trimmed
	*)
	PROCEDURE DeployFile(server: OEBInteractiveServers.Server; id: LONGINT; CONST command: ARRAY OF CHAR; VAR reply: ARRAY OF CHAR): LONGINT;
	VAR
		fileName, resourceName: Files.FileName;
		path: ARRAY 2 OF CHAR;
		cmd, str: ARRAY MaxCmdLen OF CHAR;
		res: LONGINT;

		PROCEDURE ErrorInvalidFormat(): LONGINT;
		BEGIN
			reply := "invalid command format";
			RETURN OEBInteractiveServers.CommandError;
		END ErrorInvalidFormat;

		PROCEDURE GetFileName(VAR cmd: ARRAY OF CHAR; VAR fileName: ARRAY OF CHAR): BOOLEAN;
		VAR
			ch: CHAR;
			k, m: LONGINT;
		BEGIN
			Strings.TrimWS(cmd);
			IF cmd[0] = 0X THEN RETURN FALSE; END;

			ch := cmd[0];
			IF (ch = "'") OR (ch = '"') THEN
				Strings.Delete(cmd,0,1);
			ELSE
				ch := " "; (* use space as the file name delimeter *)
			END;

			k := Strings.Find(cmd,0,ch);
			IF (ch # " ") & ((k <= 0) OR (cmd[k] # ch)) THEN
				RETURN FALSE;
			END;
			IF k < 0 THEN
				COPY(cmd,fileName);
			ELSE
				Strings.Copy(cmd,0,k,fileName);
				Strings.Delete(cmd,0,k+1);
			END;

			RETURN TRUE;
		END GetFileName;

	BEGIN
		COPY(command,cmd);
		Strings.Delete(cmd,0,10); (* remove "deployfile" *)
		IF ~GetFileName(cmd,fileName) THEN RETURN ErrorInvalidFormat(); END;
		Files.SplitPath(fileName,path,resourceName);

		Strings.Concat('load "',fileName,str); Strings.Concat(str,'" "',str); Strings.Concat(str,resourceName,str); Strings.Concat(str,'"',str);
		res := server.ExecuteCommand(id, str, reply); IF res # 0 THEN RETURN res; END;

		IF ~GetFileName(cmd,fileName) THEN RETURN ErrorInvalidFormat(); END;
		Strings.Concat('deploy "',resourceName,str); Strings.Concat(str,'" file "',str); Strings.Concat(str,fileName,str); Strings.Concat(str,'"',str);
		res := server.ExecuteCommand(id, str, reply); IF res # 0 THEN RETURN res; END;
		
		res := server.ExecuteCommand(id, "flush", reply); IF res # 0 THEN RETURN res; END;
		Strings.Concat("OK: ",command,reply);
		RETURN 0;
	END DeployFile;

	(**
		OEB.Command --id=# --server=# {command \n} ~
	*)
	PROCEDURE Command*(context : Commands.Context);
	VAR
		opt: Options.Options;
		server: OEBServers.Server;
		cmd, reply: ARRAY MaxCmdLen OF CHAR;
		sid, id, len, res: LONGINT;
	BEGIN
		NEW(opt);
		opt.Add('i', "id", Options.Integer);
		opt.Add('s', "server", Options.Integer);
		IF ~opt.Parse(context.arg, context.error) THEN
			context.result := 1;
			RETURN
		END;

		IF ~opt.GetInteger("server", sid) THEN
			context.result := 2;
			context.error.String("Error: missing server id");
			context.error.Ln;
			RETURN
		END;
		IF ~opt.GetInteger("id", id) THEN
			context.result := 3;
			context.error.String("Error: missing session id");
			context.error.Ln;
			RETURN
		END;

		IF (sid >= servers.Length()) OR (servers.Get(sid) = NIL) THEN
			context.result := 4;
			context.error.String("Error: invalid server #");
			context.error.Ln;
			RETURN
		END;
		server := servers.Get(sid)(OEBServers.Server);
		IF ~(server IS OEBInteractiveServers.Server) THEN
			context.result := 5;
			context.error.String("Error: cannot execute a command on this server");
			context.error.Ln;
			RETURN
		END;
		WITH server: OEBInteractiveServers.Server DO
			IF server.GetSession(id) = NIL THEN
				context.result := 6;
				context.error.String("Error: session does not exist on this server");
				context.error.Ln;
				RETURN
			END;
			context.arg.SkipWhitespace;
			IF context.arg.Available() = 0 THEN
				context.result := 7;
				context.error.String("Error: command string parameter is empty"); 
				context.error.Ln;
				RETURN;
			END;
			REPEAT
				context.arg.Ln(cmd); Strings.TrimWS(cmd);
				IF cmd[0] = 0X THEN RETURN; END;
				IF Strings.StartsWith2("deployfile",cmd) THEN
					res := DeployFile(server,id,cmd,reply);
				ELSE
					res := server.ExecuteCommand(id, cmd, reply);
				END;
				IF res = 0 THEN
					context.out.String("Server #");
					context.out.Int(sid, 0);
					context.out.String(" session #");
					context.out.Int(id, 0);
					context.out.String(" ");
					context.out.String(reply);
					context.out.Ln;
					context.out.Update;
				ELSE
					context.result := 8;
					context.error.String("Error: Server #");
					context.error.Int(sid, 0);
					context.error.String(" session #");
					context.error.Int(id, 0);
					context.error.String(" ");
					context.error.String(reply);
					context.error.Ln;
					RETURN;
				END;
			UNTIL (context.arg.res # 0) OR (context.arg.Available() = 0);
		END
	END Command;

	PROCEDURE ShowServer (server: OEBServers.Server; id: LONGINT; out: Streams.Writer);
	BEGIN
		out.String("Server #");
		out.Int(id, 0);
		out.String(" (");
		out.String(server.type);
		out.String(")");
	END ShowServer;

	PROCEDURE ShowInterface (itf: OEBInterfaces.Interface; sid, id: LONGINT; out: Streams.Writer);
	BEGIN
		out.String("Interface #");
		out.Int(id, 0);
		out.String(" (");
		out.String(itf.type);
		out.String(") (on server #");
		out.Int(sid, 0);
		out.String(")	[");
		CASE itf.State() OF
			 OEBInterfaces.StateInit: out.String("INITIALIZED")
			|OEBInterfaces.StateActive: out.String("ACTIVE")
			|OEBInterfaces.StateStopped: out.String("PAUSED")
			|OEBInterfaces.StateDead: out.String("STOPPED")
			|OEBInterfaces.StateDie: out.String("STOPPING")
		END;
		IF itf IS OEBLoopbackInterfaces.Interface THEN
			out.String(", ");
			IF ~itf(OEBLoopbackInterfaces.Interface).Connected() THEN
				out.String("DIS")
			END;
			out.String("CONNECTED")
		END;
		out.String("]");
	END ShowInterface;

	PROCEDURE ShowSession (server: OEBServers.Server; session: OEBInterfaces.Session; sid, id: LONGINT; out: Streams.Writer);
	BEGIN
		out.String("Session #");
		out.Int(id, 0);
		out.String(" ");
		out.String(session.name);
		out.String(" (GUID = ");
		out.String("NIY");
		out.String(")	[");
		CASE session.State() OF
			 OEBInterfaces.SessionOpen: out.String("OPEN")
			|OEBInterfaces.SessionWaiting: out.String("DEPLOYING")
			|OEBInterfaces.SessionClosed: out.String("CLOSED")
			|OEBInterfaces.SessionError: out.String("ERROR")
		END;
		out.String("]")
	END ShowSession;

BEGIN
	NEW(servers, 16)
END OEB.

UDP.ToggleTrace ~

SystemTools.CollectGarbage ~

SystemTools.FreeDownTo WSock32 ~
SystemTools.FreeDownTo OEBInterfaces ~
SystemTools.ListPlugins ~

TFTPServer.Start

OEB.NewServer --type=Auto
	GUID
		1234567H
	PLAN
		setsource TFTP 10.3.34.145
		load A2.Bin a2
		load bs.bin bs
		program a2 memory 100000H 0 1
		program bs ZynqFpga
		program config A2Config
	END
	PLAN
		setsource TFTP 10.3.34.145
		load A2.Bin a2
		program a2 memory 100000H 0 1
		program config A2Config
		start
	END
~

OEB.NewServer --type=Interactive ~
OEB.Server --kill --all ~
OEB.NewInterface --type=Loopback --server=0 19088743 ~
OEB.NewInterface --type=Udp --server=0 10.3.34.0 ~
OEB.Interface --kill --server=0 --all ~
OEB.ListSessions 0 ~
OEB.Session --show --server=0 --id=0 --close ~
OEB.Command --server=0 --id=0 reset~

OEB.Command --server=0 --id=0 program init.log file _:init.txt.log~
OEB.Command --server=0 --id=0 setinput init.txt blah~

OEB.Command --server=0 --id=0 setsource TFTP  10.3.34.145~
OEB.Command --server=0 --id=0 load Bootloader.arm Bootloader.arm~
OEB.Command --server=0 --id=0 save Bootloader.arm~
OEB.Command --server=0 --id=0 reset~