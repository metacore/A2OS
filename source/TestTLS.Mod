MODULE TestTLS;
(* Timothée Martiel 2014: test TLS server and client functionalities*)

IMPORT KernelLog, TLS, Commands, IP, TCP, Streams, WebHTTP, DNS, TFLog, Strings;

CONST
	ErrIllegalURL* = -1;
	ErrNotConnected* = -2;
	ErrIllegalResponse* = -3;

VAR
	server, client: TLS.Connection;
	log:TFLog.Log;

	PROCEDURE StartServer*(context: Commands.Context);
	VAR
		res: INTEGER;
	BEGIN
		server := TLS.GetConnection();
		server.Open(123, IP.NilAdr, TCP.NilPort, res)
	END StartServer;

	PROCEDURE StopServer*(context: Commands.Context);
	BEGIN
		server.Close
	END StopServer;

	PROCEDURE OpenClient*(lport:SIGNED32; fadr:IP.Adr; fport:SIGNED32; VAR res:INTEGER);
	BEGIN
		client := TLS.GetConnection();
		client.Open(lport, fadr, fport, res);
		client.AwaitStateNotEqual(TLS.ClientHandshake);

		IF client.State() = TCP.Established THEN
			KernelLog.String("TLS Client Connection Opened"); KernelLog.Ln;
		END
	END OpenClient;


	PROCEDURE StartClient*(context: Commands.Context);
	VAR res:INTEGER;
	BEGIN
		OpenClient(TCP.NilPort, IP.StrToAdr("127.0.0.1"), 443, res);
	END StartClient;

	PROCEDURE StopClient*;
	BEGIN
		IF client#NIL THEN
			client.Close;
			client:=NIL;
		END;
	END StopClient;


	PROCEDURE Get*(context:Commands.Context);
		VAR
			requestHeader: WebHTTP.RequestHeader;
			responseHeader: WebHTTP.ResponseHeader;
			w : Streams.Writer; r : Streams.Reader;
			x : WebHTTP.AdditionalField;
			host : ARRAY 128 OF CHAR;
			url, path : ARRAY 2048 OF CHAR;
			port : SIGNED32;
			fadr: IP.Adr;
			dechunk: WebHTTP.ChunkedInStream;
			lin : WebHTTP.LimitedInStream;
			success:BOOLEAN;
			res:INTEGER;
			out:Streams.Reader;
			ch:CHAR;
		BEGIN
			requestHeader.referer := "";
			requestHeader.useragent := "A2 https client";
			requestHeader.maj := 1;
			requestHeader.min := 1;
			success:=context.arg.GetString(url);

			StopClient;
			IF WebHTTP.SplitHTTPAdr(url, host, path, port) THEN
				DNS.HostByName(host, fadr, res);
				IF res = DNS.Ok THEN

					OpenClient(TCP.NilPort, fadr, port, res);
					IF res#0 THEN context.out.String("connection failed"); context.out.Ln; context.out.Update; RETURN END;

					Streams.OpenWriter(w, client.Send); Streams.OpenReader(r, client.Receive);

					IF path="" THEN path:="/" END;
					WebHTTP.WriteRequestLine(w, requestHeader.maj, requestHeader.min, WebHTTP.GetM, path, host);
					WebHTTP.WriteRequestLine(context.out, requestHeader.maj, requestHeader.min, WebHTTP.GetM, path, host);

					IF requestHeader.referer # "" THEN w.String("Referer: "); w.String(requestHeader.referer); w.Ln() END;
					IF requestHeader.useragent # "" THEN w.String("User-Agent: "); w.String(requestHeader.useragent); w.Ln() END;
					IF requestHeader.accept # "" THEN w.String("Accept: "); w.String(requestHeader.accept); w.Ln() END;
					x := requestHeader.additionalFields;
					WHILE x # NIL DO
						w.String(x.key);  w.Char(" "); w.String(x.value);w.Ln();

						x := x.next
					END;
					w.Ln(); w.Update();

					WebHTTP.ParseReply(r, responseHeader, res, log);
					WebHTTP.LogResponseHeader(log,responseHeader);

					IF (Strings.Pos("hunked", responseHeader.transferencoding) > 0) THEN NEW(dechunk, r, out)
					ELSIF responseHeader.contentlength >= 0 THEN NEW(lin, r, out, responseHeader.contentlength)
					ELSE out := r
					END;

					res := 0;
					x := responseHeader.additionalFields;
					WHILE x # NIL DO
						x := x.next
					END;

					context.out.String("Response:"); context.out.Ln;

					LOOP
						ch:=out.Get();
						IF out.res#Streams.Ok THEN EXIT END;
						context.out.Char(ch);
					END;
					context.out.Ln;
					context.out.String("TestTLS.Get done");
				END;
			ELSE
				res := ErrIllegalURL
			END;
			context.out.Update;
		END Get;

BEGIN
	NEW(log,"https client:"); log.SetLogToOut(TRUE);
END TestTLS.

Compiler.Compile
	ASN1.Mod
	X509.Mod
	PKCS1.Mod
	TLS.Mod
	~


TestTLS.StartServer ~
TestTLS.StopServer ~

WebHTTPServerTools.Start \r:httproot \l:HTTP.Log \s:on ~ (* start HTTPS server*)
WebHTTPServerTools.Stop ~

TestTLS.Get https://127.0.0.1/index.html ~ (* access the local server via loopback*)
TestTLS.Get http://127.0.0.1:80/index.html ~ (* access the local server via loopback*)
TestTLS.Get https://www.google.com/ ~
TestTLS.Get https://discognosis.highdim.com/index.html ~
TestTLS.Get https://discognosis.highdim.com/ ~
TestTLS.Get http://discognosis.highdim.com/ ~
TestTLS.Get https://startpage.com ~
TestTLS.Get https://www.archlinux.org ~
TestTLS.Get https://www.ethz.ch/de.html ~
TestTLS.Get https://www.duckduckgo.com ~
TestTLS.Get https://127.0.0.1:4433/

TestTLS.StartClient ~
TestTLS.StopClient ~

System.FreeDownTo TCP ~

WebHTTPServerTools.ListHosts ~