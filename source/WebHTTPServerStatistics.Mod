MODULE WebHTTPServerStatistics; (** AUTHOR "staubesv"; PURPOSE "Simple WebHTTP server link hit counter"; *)
(* No tricks variant. Much room for optimizations. *)

IMPORT
	Machine, Modules, Kernel, Streams, Commands, WebHTTP, WebHTTPServer;

TYPE

	Link = OBJECT
	VAR
		host : ARRAY 256 OF CHAR;
		uri : ARRAY 1024 OF CHAR;
		hits : SIGNED32;
		next : Link;

		PROCEDURE Hit;
		BEGIN
			Machine.AtomicInc(hits);
		END Hit;

		PROCEDURE ToStream(out : Streams.Writer);
		BEGIN {EXCLUSIVE}
			ASSERT(out # NIL);
			out.String(host); out.String(uri); out.String(": "); out.Int(hits, 0); out.Ln;
		END ToStream;

		PROCEDURE &Init*(CONST host, uri : ARRAY OF CHAR);
		BEGIN
			COPY(host, SELF.host);
			COPY(uri, SELF.uri);
			hits := 0;
			next := NIL;
		END Init;

	END Link;

VAR
	links : Link;

(** Note: Don't take any locks here!! Unoptimized!! *)
PROCEDURE Listener(request : WebHTTP.RequestHeader; response : WebHTTP.ResponseHeader);
VAR link : Link;
BEGIN
	link := links.next;
	WHILE (link # NIL) DO
		IF (request.host = link.host) & (request.uri = link.uri) THEN link.Hit; END;
		link := link.next;
	END;
END Listener;

PROCEDURE AddURI*(context : Commands.Context); (* host uri ~ *)
VAR
	host : ARRAY 256 OF CHAR; uri : ARRAY 1024 OF CHAR;
	link : Link;
BEGIN
	IF context.arg.GetString(host) & context.arg.GetString(uri) THEN
		NEW(link, host, uri);
		BEGIN {EXCLUSIVE}
			link.next := links.next;
			links.next := link;
		END;
		context.out.String("Added "); context.out.String(host); context.out.String(uri); context.out.Ln;
	ELSE
		context.error.String("Expected host and uri parameters"); context.error.Ln;
	END;
END AddURI;

(** Show hit statistics *)
PROCEDURE Show*(context : Commands.Context);
VAR link : Link;
BEGIN
	context.out.String("Hit statistics: "); context.out.Ln;
	IF (links.next # NIL) THEN
		link := links.next;
		WHILE (link # NIL) DO
			link.ToStream(context.out); context.out.Update;
			link := link.next;
		END;
	ELSE
		context.out.String("No URIs registered"); context.out.Ln;
	END;
END Show;

PROCEDURE Cleanup;
VAR timer : Kernel.Timer;
BEGIN
	WebHTTPServer.listener := NIL;
	NEW(timer); timer.Sleep(500);
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	NEW(links, "Head of List", "");
	WebHTTPServer.listener := Listener;
END WebHTTPServerStatistics.

WebHTTPServerStatistics.AddURI powerbottle.inf.ethz.ch /index.html~

WebHTTPServerStatistics.Show ~

System.Free WebHTTPServerStatistics ~
