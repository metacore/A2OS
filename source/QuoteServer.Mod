MODULE QuoteServer; (** AUTHOR "be"; PURPOSE "Quote of the day server"; *)
(**
 * Quote of the Day (RFC 865) TCP service.
 *)

IMPORT Modules, Machine, Commands, TCP, TCPServices, Streams, Files;

CONST
	QuotePort = 17;

	Ok = TCP.Ok;
	CR = 0DX;
	LF = 0AX;

	DefaultQuoteFile = "Quotes.txt";
	MaxQuoteLen = 511;

TYPE
	QuoteAgent = OBJECT (TCPServices.Agent)
	VAR q: Quote; w: Streams.Writer;

	BEGIN {ACTIVE}
		Machine.AtomicInc(Nrequests);
		q := NextQuote();
		ASSERT(q # NIL);
		Streams.OpenWriter(w, client.Send);
		w.String(q.msg); w.Update;
		Terminate
	END QuoteAgent;

	Quote = POINTER TO RECORD
		msg: ARRAY MaxQuoteLen OF CHAR;
		len: LONGINT;
		next: Quote;
	END;

VAR
	quoteService: TCPServices.Service;
	quotes: Quote;
	NnofQuotes-, Nrequests-: LONGINT;

PROCEDURE NewQuoteAgent(c: TCP.Connection; s: TCPServices.Service): TCPServices.Agent;
VAR q: QuoteAgent;
BEGIN
	NEW(q, c, s); RETURN q
END NewQuoteAgent;

PROCEDURE NextQuote(): Quote;
BEGIN {EXCLUSIVE}
	quotes := quotes.next;
	RETURN quotes
END NextQuote;

PROCEDURE ReadQuotesX(filename : ARRAY OF CHAR; context : Commands.Context);
VAR
	f: Files.File; r: Files.Reader; str: ARRAY MaxQuoteLen OF CHAR;
	q: Quote; pos: LONGINT;

	PROCEDURE Skip;
	BEGIN
		WHILE (str[0] = "#") & (r.res = Ok) DO r.Ln(str) END
	END Skip;

	PROCEDURE Append;
	VAR i: LONGINT;
	BEGIN
		WHILE (pos < MaxQuoteLen-2) & (str[i] # 0X) DO q.msg[pos] := str[i]; INC(pos); INC(i) END;
		q.msg[pos] := CR; INC(pos);
		q.msg[pos] := LF; INC(pos)
	END Append;

BEGIN
	context.out.String("QuoteServer: Reading quotes from file "); context.out.String(filename); context.out.String("... ");
	f := Files.Old(filename);
	quotes := NIL; NnofQuotes := 0;
	IF (f # NIL) THEN
		Files.OpenReader(r, f, 0);
		r.Ln(str);
		Skip;
		WHILE (r.res = Ok) DO
			INC(NnofQuotes);
			NEW(q); q.next := quotes; quotes := q;
			q.msg := ""; pos := 0;
			REPEAT
				Append;
				r.Ln(str)
			UNTIL (str[0] = "#") OR (r.res # Ok);
			Skip
		END;
		IF (quotes # NIL) THEN (* form a ring *)
			q := quotes;
			WHILE (q.next # NIL) DO q := q.next END;
			q.next := quotes
		END;
		context.out.Int(NnofQuotes, 0); context.out.String(" quotes read."); context.out.Ln;
	ELSE
		context.error.String("file not found ("); context.error.String(filename); context.error.Char(")"); context.error.Ln;
	END;
END ReadQuotesX;

PROCEDURE StartService(context : Commands.Context);
VAR res : WORD;
BEGIN
	IF (NnofQuotes > 0) THEN
		NEW(quoteService, QuotePort, NewQuoteAgent, res);
		IF (quoteService # NIL) THEN
			Nrequests := 0;
			context.out.String("QuoteServer: Service installed."); context.out.Ln;
		ELSE
			context.error.String("QuoteServer: Port not available. System.Free QuoteServer ~ and try again."); context.error.Ln;
		END
	ELSE context.error.String("QuoteServer: No quotes available, service not installed."); context.error.Ln;
	END;
END StartService;

PROCEDURE ReadQuotes*(context : Commands.Context); (** filename ~ *)
VAR filename : ARRAY 256 OF CHAR;
BEGIN {EXCLUSIVE}
	IF context.arg.GetString(filename) THEN
		ReadQuotesX(filename, context);
	ELSE
		context.error.String("QuoteServer: Expected filename parameter."); context.error.Ln;
	END;
END ReadQuotes;

PROCEDURE Open*(context : Commands.Context); (** [filename] ~ *)
VAR filename : ARRAY 256 OF CHAR;
BEGIN {EXCLUSIVE}
	IF ~context.arg.GetString(filename) THEN filename := DefaultQuoteFile; END;
	IF quoteService = NIL THEN
		IF quotes = NIL THEN
			ReadQuotesX(filename, context);
		END;
		StartService(context);
	ELSE
		context.out.String("QuoteServer: Server already running."); context.out.Ln;
	END;
END Open;

PROCEDURE Close*(context : Commands.Context); (** ~ *)
BEGIN
	Cleanup;
	context.out.String("QuoteServer: Server closed."); context.out.Ln;
END Close;

PROCEDURE Cleanup;
BEGIN  {EXCLUSIVE}
	IF quoteService # NIL THEN
		quoteService.Stop; quoteService := NIL;
	END;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END QuoteServer.

QuoteServer.Open ~ 	SystemTools.Free QuoteServer ~ 	PET.Open Quotes.txt ~
QuoteServer.Open Quotes.txt ~
QuoteServer.ReadQuotes Quotes.txt ~