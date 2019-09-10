MODULE Shell; (** AUTHOR "be"; PURPOSE "Simple command shell" **)
(**
 * Simple echo-based command shell.
 *
 * History:
 *
 *	16.05.2006	Added command history, backspace key handling, factored out serial port related code into ShellSerials.Mod (staubesv)
 *
 *)

IMPORT Modules, Commands, Streams, Pipes, Strings, Files;

CONST
	(* Notify procedure command codes *)
	ExitShell* = 1;
	Clear* = 2;

	Version = "Shell v1.0";

	DefaultAliasFile = "Shell.Alias";

	NestingLevelIndicator = ">";

	MaxLen = 4096;
	CmdLen = 64;
	ParamLen = MaxLen;
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

	(* symbols *)
	start = {};
	inputFile = {0};	 			(* 01H *)
	pipe = {1};					(* 02H *)
	outputFile = {2};				(* 04H *)
	outputFileAppend = {3};		(* 08H *)
	ampersand = {4};			(* 10H *)
	whitespace = {5};			(* 20H *)
	eoln = {6};					(* 40H *)
	char = {7};					(* 80H *)
	EndOfParam = pipe + inputFile + outputFile + outputFileAppend + ampersand + eoln;

	(* errors *)
	ErrFileNotFound = 1;
	ErrInvalidFilename = 2;
	ErrAlreadyPiped = 3;
	ErrPipeAtBeginning = 4;
	ErrInvalidCommand = 5;
	ErrEolnExpected = 6;

TYPE
	CommandsString = POINTER TO RECORD
		prev, next: CommandsString;
		string: ARRAY MaxLen OF CHAR;
	END;

	CommandHistory = OBJECT
	VAR
		first, current: CommandsString;

		PROCEDURE GetNextCommand(VAR cmd : ARRAY OF CHAR);
		BEGIN
			IF first = NIL THEN RETURN END;
			IF current = NIL THEN current := first ELSE current := current.next END;
			COPY(current.string, cmd);
		END GetNextCommand;

		PROCEDURE GetPreviousCommand(VAR cmd : ARRAY OF CHAR);
		BEGIN
			IF first = NIL THEN RETURN END;
			IF current = NIL THEN current := first.prev ELSE current := current.prev END;
			COPY(current.string, cmd);
		END GetPreviousCommand;

		PROCEDURE AddCommand(CONST cmd : ARRAY OF CHAR);
		VAR command: CommandsString;
		BEGIN
			IF (cmd = "") THEN (* Don't add to history *) RETURN; END;
			command := first;
			IF command # NIL THEN
				WHILE (command.string # cmd) & (command.next # first) DO command := command.next END;
				IF command.string # cmd THEN command := NIL END
			END;
			IF command # NIL THEN
				IF first = command THEN first := command.next END;
				command.prev.next := command.next;
				command.next.prev := command.prev;
			ELSE
				NEW (command);
				COPY (cmd, command.string);
			END;
			IF first = NIL THEN
				first := command; first.next := first; first.prev := first
			ELSE
				command.prev := first.prev; command.next := first;
				first.prev.next := command; first.prev := command;
			END;
			current := NIL;
		END AddCommand;

		PROCEDURE &Init*;
		BEGIN first := NIL; current := NIL;
		END Init;

	END CommandHistory;

TYPE

	Command = POINTER TO RECORD
		command: ARRAY CmdLen OF CHAR;			(* command (e.g. <module>"."<command> *)
		parameters: ARRAY ParamLen OF CHAR;	(* parameters *)
		context: Commands.Context;	(* context (in, out & err streams *)
		pipe : Pipes.Pipe;
		next: Command;
	END;

	Alias = POINTER TO RECORD
		alias,
		command: ARRAY CmdLen OF CHAR;
		parameters: ARRAY ParamLen OF CHAR;
		next: Alias;
	END;

	NotifyProcedure* = PROCEDURE {DELEGATE} (command : INTEGER);

TYPE

	Shell* = OBJECT
	VAR
		echo, dead, close: BOOLEAN;
		context: Commands.Context;
		command: ARRAY MaxLen OF CHAR;
		res: INTEGER;
		nestingLevel : SIZE; (* how many shells run in this shell? *)
		aliases: Alias;
		prompt: ARRAY 32 OF CHAR;

		(* Connection to the entry hosting this shell instance *)
		upcall : NotifyProcedure;

		commandHistory : CommandHistory;
		firstCR : CHAR;

		currentCommand: Command;

		PROCEDURE &Init*(in: Streams.Reader; out, err: Streams.Writer; echo: BOOLEAN; CONST prompt: ARRAY OF CHAR);
		BEGIN
			ASSERT((in # NIL) & (out # NIL) & (err # NIL));
			NEW(context, in, NIL, out, err, SELF);
			close := FALSE; dead := FALSE; command[0] := 0X; res := 0; SELF.echo := echo; COPY(prompt, SELF.prompt);
			NEW(commandHistory); firstCR := 0X;
		END Init;

		PROCEDURE Exit*;
		BEGIN
			close := TRUE;
		END Exit;

		PROCEDURE DeleteStringFromDisplay(CONST x : ARRAY OF CHAR);
		VAR i, len : SIZE;
		BEGIN
			len := Strings.Length(x);
			FOR i :=	 0 TO len-1 DO context.out.Char(Backspace); END;
			FOR i :=	 0 TO len-1 DO context.out.Char(Space); END;
			FOR i :=	 0 TO len-1 DO context.out.Char(Backspace); END;
		END DeleteStringFromDisplay;

		PROCEDURE ReadCommand(VAR command : ARRAY OF CHAR): CHAR;
		VAR
			ch: CHAR;
			currentIndex : SIZE;

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
				ch := context.in.Get();
				ch := CHR(ORD(ch)+128);

				IF (ch = CursorDown) OR (ch = CursorUp) THEN (* Command History Keys *)

					command[currentIndex+1] := 0X;
					DeleteStringFromDisplay(command);

					IF ch = CursorUp THEN
						commandHistory.GetPreviousCommand(command);
					ELSE
						commandHistory.GetNextCommand(command);
					END;
					currentIndex := Strings.Length(command)-1;
					IF echo & (command # "") THEN context.out.String(command); context.out.Update; END;
				ELSE
					(* ignore escaped character *)
				END;
			END HandleEscapeSequence;

		BEGIN
			command := ""; currentIndex := -1;

			LOOP
				ch := context.in.Get();

				IF IsAsciiCharacter(ch) THEN

					IF IsControlCharacter(ch) OR (ch = Delete) THEN

						IF (ch = CR) OR (ch = LF) THEN
							(* skip redundant CR and LF to avoid generation of empty commands. This requires peek functionality which doesn't work on the Input stream from an underlying OS, so a decoupler is needed that transforms that into an oberon stream*)
							(* actually: it is much simpler: just memorize the first seen CR or LF and start executing from there *)
							IF firstCR = 0X THEN
								firstCR := ch;
								EXIT;
							ELSIF ch = firstCR THEN
								EXIT
							END;
						ELSIF (ch = Streams.EOT) OR (context.in.res # Streams.Ok) THEN
							EXIT;
						ELSIF (ch = Backspace) OR (ch = Delete)THEN
							IF currentIndex >= 0 THEN (* There is a character at the left of the cursor *)
								command[currentIndex] := 0X;
								DEC(currentIndex);
								IF echo THEN
									context.out.Char(Backspace); context.out.Char(Space); context.out.Char(Backspace); context.out.Update;
								END;
							END;
						ELSIF (ORD(ch) = 03H) THEN
						(*	IF runner # NIL THEN AosActive.TerminateThis(runner); END; *)
						ELSIF (ch = EscapeChar1) THEN (* Escape sequence *)
							IF context.in.Peek() = EscapeChar2 THEN ch := context.in.Get(); HandleEscapeSequence;
							ELSIF context.in.Peek () = Escape THEN
								command[currentIndex+1] := 0X;
								DeleteStringFromDisplay (command); context.out.Update;
								ch := context.in.Get (); command := ""; currentIndex := -1;
							END;
						ELSE
							(* ignore other control characters *)
						END;

					ELSE
						IF currentIndex <= LEN(command) - 2 (* Always need space for 0X *) THEN
							INC(currentIndex);
							command[currentIndex] := ch;
							IF echo THEN context.out.Char(ch); context.out.Update; END;
						END;
					END;

				ELSE
					(* ignore non-ascii characters *)
					IF close OR (context.in.res # Streams.Ok) THEN
						EXIT;
					END;
				END;
			END;
			command[currentIndex+1] := 0X;

			IF (ch = LF) OR (ch =CR)  THEN
				commandHistory.AddCommand(command);

				IF echo THEN context.out.Ln; context.out.Update END
			END;
			RETURN ch;
		END ReadCommand;

		PROCEDURE Parse(VAR cmd: Command; VAR wait: BOOLEAN): INTEGER;
		VAR sym: SET; pos: SIZE; c, next: CHAR;

			PROCEDURE Init;
			BEGIN
				pos := 0; c := 0X; next := command[pos]; sym := start; Scan
			END Init;

			PROCEDURE Scan;
			BEGIN
				IF (sym # eoln) THEN
					c := next; INC(pos); next := command[pos];
					CASE c OF
					| "<": sym := inputFile
					| "|": sym := pipe
					| ">": IF (next = ">") THEN sym := outputFileAppend; INC(pos); next := command[pos]; ELSE sym := outputFile END
					| "&": sym := ampersand
					| " ", 09X: sym := whitespace
					| 0X: sym := eoln
					ELSE sym := char
					END
				END
			END Scan;

			PROCEDURE Match(symbol: SET): BOOLEAN;
			BEGIN IF (symbol = sym) THEN Scan; RETURN TRUE ELSE RETURN FALSE END
			END Match;

			PROCEDURE Skip;
			BEGIN
				WHILE (sym = whitespace) & (sym # eoln) DO Scan END
			END Skip;

			PROCEDURE Token(VAR s: ARRAY OF CHAR; cond: SET): BOOLEAN;
			VAR i: SIZE; quote: BOOLEAN;
			BEGIN
				quote := FALSE;
				WHILE (sym * cond = {}) OR (quote & (sym # eoln)) DO
					s[i] := c; INC(i); IF (c = '"') OR (c = "'") THEN quote := ~quote END; Scan
				END;
				s[i] := 0X;
				RETURN ~quote
			END Token;

			PROCEDURE Cmd(): Command;
			VAR i: SIZE; cmd: Command; arg : Streams.StringReader;
			BEGIN Skip;
				IF (sym = char) THEN
					NEW(cmd);
					i := 0;
					WHILE (sym = char) DO cmd.command[i] := c; INC(i); Scan END; cmd.command[i] := 0X; Skip;
					IF (cmd.command # "") THEN
						IF (sym * EndOfParam = {}) THEN
							IF ~Token(cmd.parameters, EndOfParam) THEN cmd := NIL END
						END;
						REPEAT UNTIL ~ReplaceAlias(cmd);
						NEW(arg, LEN(cmd.parameters)); arg.SetRaw(cmd.parameters, 0, LEN(cmd.parameters));
						NEW(cmd.context, context.in, arg, context.out, context.error, SELF);
					ELSE cmd := NIL	(* invalid command (empty string) *)
					END
				ELSE cmd := NIL
				END;
				RETURN cmd
			END Cmd;

			PROCEDURE CmdLine(VAR command: Command): INTEGER;
			VAR cmd, prev: Command; fn: Files.FileName; f: Files.File; fr: Files.Reader; fw: Files.Writer;
				r: Streams.Reader; w: Streams.Writer; append, piped: BOOLEAN; s: ARRAY 64 OF CHAR;
			BEGIN
				cmd := NIL; prev := NIL; command := NIL; res := 0; piped := FALSE;
				Init;
				REPEAT
					cmd := Cmd();
					IF (cmd # NIL) THEN
						IF (command = NIL) THEN command := cmd END;
						IF piped THEN
							piped := FALSE;
							IF (prev # NIL) THEN
								IF (prev.context.out = context.out) & (cmd.context.in = context.in) THEN
									NEW(prev.pipe, 1024);
									Streams.OpenReader(r, prev.pipe.Receive); Streams.OpenWriter(w, prev.pipe.Send);
									prev.context.Init(r, prev.context.arg, w, prev.context.error, SELF);
									prev.next := cmd
								ELSE  res := ErrAlreadyPiped (* already piped *)
								END
							ELSE res := ErrPipeAtBeginning (* pipe cannot be first symbol *)
							END
						END;

						IF Match(inputFile) THEN (* "<" filename *)
							IF (cmd.context.in = context.in) THEN
								Skip;
								IF Token(fn, SET(-char)) & (fn # "") THEN
									f := Files.Old(fn);
									IF (f # NIL) THEN
										Files.OpenReader(fr, f, 0);
										cmd.context.Init(fr, cmd.context.arg, cmd.context.out, cmd.context.error, SELF)
									ELSE res := ErrFileNotFound (* file not found *)
									END
								ELSE res := ErrInvalidFilename (* invalid filename *)
								END
							ELSE res := ErrAlreadyPiped (* error: already piped *)
							END
						ELSIF Match(pipe) THEN (* "|" command *)
							piped := TRUE
						END;
						prev := cmd
					ELSE res := ErrInvalidCommand (* invalid command *)
					END
				UNTIL (res # 0) OR (cmd = NIL) OR ~piped;
				IF (res = 0) THEN
					IF (sym * (outputFile+outputFileAppend) # {}) THEN (* ">"[">"] filename *)
						append := (sym = outputFileAppend);
						Scan; Skip;
						IF Token (fn, EndOfParam (*-char *)) & (fn # "") THEN
							Skip; f := NIL;
							IF append THEN f := Files.Old(fn) END;
							IF (f = NIL) THEN f := Files.New(fn); Files.Register(f) END;
							IF (f # NIL) THEN
								IF append THEN
									Files.OpenWriter(fw, f, f.Length());
								ELSE
									Files.OpenWriter(fw, f, 0);
								END;
								cmd.context.Init(cmd.context.in, cmd.context.arg, fw, cmd.context.error, SELF);
								fw.Update;
							ELSE res := ErrFileNotFound (* cannot open output file *)
							END
						ELSE res := ErrInvalidFilename (* invalid filename *)
						END
					END
				END;
				IF (res = 0) THEN
					wait := ~Match(ampersand);
					WHILE (sym # eoln) & Match(whitespace) DO END;
					IF ~Match(eoln) THEN res := ErrEolnExpected END (* end of line expected *)
				END;
				IF (res # 0) THEN
					context.error.String("Error at position "); context.error.Int(pos, 0); context.error.String(": ");
					CASE res OF
					| ErrFileNotFound: COPY("file not found.", s)
					| ErrInvalidFilename: COPY("invalid file name.", s)
					| ErrAlreadyPiped: COPY("two input streams.", s)
					| ErrPipeAtBeginning: COPY("syntax error.", s)
					| ErrInvalidCommand: COPY("invalid command.", s)
					| ErrEolnExpected: COPY("too many arguments.", s)
					ELSE COPY("unknown error.", s)
					END;
					context.error.String(s); context.error.Ln; context.error.Update;
					command := NIL
				END;
				RETURN res
			END CmdLine;

		BEGIN
			wait := TRUE;
			RETURN CmdLine(cmd)
		END Parse;

		PROCEDURE ReadAlias(cmd : Command; verbose : BOOLEAN);
		VAR s: ARRAY MaxLen OF CHAR; alias, p, q: Alias; i, k: SIZE; c: CHAR;
		BEGIN
			IF (cmd.parameters # "") THEN
				COPY(cmd.parameters, s);
				NEW(alias);
				i := 0; c := s[i];
				WHILE (c # 0X) & (c # "=") DO alias.alias[i] := c; INC(i); c := s[i] END;
				IF (c = "=") THEN
					k := 0; INC(i); c := s[i];
					WHILE (c # 0X) & (c # " ") & (c # TAB) DO alias.command[k] := c; INC(k); INC(i); c := s[i] END;
				END;

				IF verbose THEN context.out.String(alias.alias); END;
				IF (alias.command # "") THEN (* add an alias *)
					WHILE (c # 0X) & ((c = " ") OR (c = TAB)) DO INC(i); c := s[i] END;
					k := 0;
					WHILE (c # 0X) DO alias.parameters[k] := c; INC(k); INC(i); c := s[i] END;
					p := aliases; q := NIL;
					WHILE (p # NIL) & (p.alias < alias.alias) DO q := p; p := p.next END;
					IF (q = NIL) THEN aliases := alias; aliases.next := p
					ELSE q.next := alias; alias.next := p
					END;
					IF verbose THEN
						context.out.String(" = "); context.out.String(alias.command); context.out.Char(" "); context.out.String(alias.parameters);
					END;
				ELSE (* remove an alias *)
					p := aliases; q := NIL;
					WHILE (p # NIL) & (p.alias < alias.alias) DO q := p; p := p.next END;
					IF (p # NIL) & (p.alias = alias.alias) THEN
						IF (q = NIL) THEN aliases := aliases.next
						ELSE q.next := p.next
						END
					END;
					IF verbose THEN context.out.String(" removed"); END;
				END;
				IF verbose THEN context.out.Ln; END;
			ELSE (* list aliases *)
				p := aliases;
				WHILE (p # NIL) DO
					IF verbose THEN
						context.out.String(p.alias); context.out.String(" = "); context.out.String(p.command); context.out.Char(" ");
						context.out.String(p.parameters); context.out.Ln;
					END;
					p := p.next
				END
			END
		END ReadAlias;

		PROCEDURE ReplaceAlias(cmd: Command): BOOLEAN;
		VAR a: Alias; d, i: SIZE;
		BEGIN
			a := aliases;
			WHILE (a # NIL) & (a.alias < cmd.command) DO a := a.next END;
			IF (a # NIL) & (a.alias = cmd.command) THEN
				COPY(a.command, cmd.command);
				IF (a.parameters # "") THEN
					IF (cmd.parameters = "") THEN COPY(a.parameters, cmd.parameters)
					ELSE
						d := Strings.Length(a.parameters) + 1;
						FOR i := Strings.Length(cmd.parameters) TO 0 BY -1 DO
							cmd.parameters[i+d] := cmd.parameters[i]
						END;
						FOR i := 0 TO d-2 DO cmd.parameters[i] := a.parameters[i] END;
						cmd.parameters[d-1] := " "
					END
				END;
				RETURN TRUE
			ELSE
				RETURN FALSE
			END
		END ReplaceAlias;

		PROCEDURE ShowHelp;
		BEGIN
			context.out.String("--- Help --- "); context.out.Ln;
			context.out.String("alias: Show list of aliases"); context.out.Ln;
			context.out.String("alias 'string'='command': Create alias for command"); context.out.Ln;
			context.out.String("alias 'string': Remove alias"); context.out.Ln;
			context.out.String("batch: start a new instance of Shell"); context.out.Ln;
			context.out.String("clear: Clear screen"); context.out.Ln;
			context.out.String("version: Show BimboShell version"); context.out.Ln;
			context.out.String("help: Show this help text"); context.out.Ln;
			context.out.String("exit: Exit Shell"); context.out.Ln;
			context.out.Update;
		END ShowHelp;

		PROCEDURE Execute(cmd: Command; wait: BOOLEAN; VAR exit: BOOLEAN);
		VAR
			c: Command; flags: SET;
			res : INTEGER; msg: ARRAY MaxLen OF CHAR; oldContext: Commands.Context;
			moduleName, commandName : Modules.Name; errormsg : ARRAY 128 OF CHAR;
		BEGIN
			IF (cmd.command = "alias") THEN
				ReadAlias(cmd, TRUE)
			ELSIF (cmd.command = "loadalias") THEN
				LoadAliasesFromFile(cmd.parameters, TRUE);
			ELSIF (cmd.command = "batch") THEN
				context.out.String(Version); context.out.Ln; context.out.Update;
				oldContext := context; context := cmd.context;
				INC(nestingLevel);
				Run;
				context := oldContext
			ELSIF (cmd.command = "exit") THEN
				DEC(nestingLevel);
				exit := TRUE
			ELSIF (cmd.command = "version") THEN
				context.out.String(Version); context.out.Ln; context.out.Update;
			ELSIF (cmd.command = "help") THEN
				ShowHelp;
			ELSIF (cmd.command = "clear") THEN
				IF upcall # NIL THEN upcall(Clear); END;
			ELSE
				c := cmd; res := 0;
				WHILE (c # NIL) & (res = 0) DO
					IF (c.next = NIL) & wait THEN flags := {Commands.Wait}
					ELSE flags := {}
					END;
					Commands.Split(c.command, moduleName, commandName, res, errormsg);
					IF (res # Commands.Ok) THEN
						context.error.String(errormsg); context.error.Ln;
					ELSE
						currentCommand := c;
						Commands.Activate(c.command, c.context, flags, res, msg);
						currentCommand := NIL;
				(*		IF wait & (cmd.pipe # NIL) THEN
							KernelLog.String("Pipe closed"); KernelLog.Ln;
							cmd.pipe.Close;
						END; *)
						IF (res # 0) THEN
							context.error.String("Error in command: "); context.error.String(cmd.command);
							context.error.String(", params: ");
							IF c.parameters # "" THEN
								context.error.String(c.parameters);
							ELSE
								context.error.String("None");
							END;
							context.error.String(", res: "); context.error.Int(res, 0);
							context.error.String(" ("); context.error.String(msg); context.error.Char(")");
							context.error.Ln
						ELSE c := c.next
						END;
					END;
				END
			END;
			context.out.Update; context.error.Update
		END Execute;

		PROCEDURE Run;
		VAR cmdList: Command; wait, exit: BOOLEAN; i : SIZE; ch: CHAR;
		BEGIN
			exit := FALSE;
			WHILE ~close & ~exit & (context.in.res = Streams.Ok) DO
				IF (prompt # "") THEN
					context.out.String(prompt);
					FOR i := 0 TO nestingLevel-1 DO
						context.out.String(NestingLevelIndicator);
					END;
					context.out.Update
				END;
				ch := ReadCommand(command);
				IF (context.in.res = Streams.Ok) & (command # "") THEN
					IF (Parse(cmdList, wait) = 0) THEN
						Execute(cmdList, wait, exit)
					END
				END;
			END;
			context.out.Update; context.error.Update
		END Run;

		(**
			Returns TRUE if the given context is the context of currently executed command
		*)
		PROCEDURE IsCurrentCmdContext*(context: Commands.Context): BOOLEAN;
		BEGIN
			RETURN context = currentCommand.context;
		END IsCurrentCmdContext;

		PROCEDURE AwaitDeath*;
		BEGIN {EXCLUSIVE}
			AWAIT(dead)
		END AwaitDeath;

		PROCEDURE SetUpcall*(proc : NotifyProcedure);
		BEGIN
			ASSERT((proc # NIL) & (upcall = NIL));
			upcall := proc;
		END SetUpcall;

		PROCEDURE ParseAliases(r : Files.Reader);
		VAR cmd : Command;
		BEGIN
			NEW(cmd);
			LOOP
				cmd.parameters := "";
				r.Ln(cmd.parameters);
				IF r.res # Streams.Ok THEN EXIT; END;
				ReadAlias(cmd, FALSE);
			END;
		END ParseAliases;

		(* Read aliases from specified file. Returns NIL if file not found or parsing failed. *)
		PROCEDURE LoadAliasesFromFile(filename : ARRAY OF CHAR; critical: BOOLEAN);
		VAR in : Files.Reader; f : Files.File;
		BEGIN
			IF filename = "" THEN COPY(DefaultAliasFile, filename); END;
			f := Files.Old(filename);
			IF f # NIL THEN
				Files.OpenReader(in, f, 0);
				IF in # NIL THEN
					context.out.String("Loading aliases from "); context.out.String(filename); context.out.String("...");
					ParseAliases(in);
					context.out.String("done."); context.out.Ln;
				END;
			ELSIF critical THEN
				context.out.String("Loading aliases failed: File "); context.out.String(filename);
				context.out.String(" not found."); context.out.Ln;
			END;
			context.out.Update;
		END LoadAliasesFromFile;

	BEGIN {ACTIVE, SAFE}
		context.out.String(Version); context.out.Ln;
		context.out.String("Enter 'help' if needed"); context.out.Ln;
		LoadAliasesFromFile(DefaultAliasFile, FALSE);
		context.out.Update;
		Run;
		IF (upcall # NIL) THEN upcall(ExitShell); END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END Shell;

	PROCEDURE Start*(context: Commands.Context);
	VAR shell: Shell;
	BEGIN
		NEW(shell, context.in, context.out, context.error, FALSE, ">");
		shell.AwaitDeath()
	END Start;

	PROCEDURE StartEchoed*(context: Commands.Context);
	VAR shell: Shell;
	BEGIN
		NEW(shell, context.in, context.out, context.error, TRUE, ">");
		shell.AwaitDeath()
	END StartEchoed;

END Shell.

System.Free Shell ~

WMShell.Open ~
