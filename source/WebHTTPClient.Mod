(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE WebHTTPClient; (** AUTHOR "TF"; PURPOSE "HTTP client"; *)

IMPORT
	TFLog, Streams, Strings, IP, DNS, TCP, TLS, WebHTTP, Modules;

VAR log : TFLog.Log;

CONST Ok* = 0;

TYPE
	ContentReader * = OBJECT (Streams.Reader)
	VAR
		in: Streams.Reader;
		encoding: ARRAY 64 OF CHAR;
		length: SIZE;

		PROCEDURE & InitContentReader * (in: Streams.Reader; CONST h: WebHTTP.ResponseHeader);
		VAR
			token: ARRAY 64 OF CHAR;
			res: INTEGER;
		BEGIN
			InitReader(Receive, 1024);
			SELF.in := in;
			COPY(h.transferencoding, encoding);
			IF (encoding # "") & Strings.Match("chunked", encoding) THEN
				in.SkipSpaces(); in.Token(token); Strings.HexStrToSize(token, length, res); in.SkipLn();
			ELSE
				length := h.contentlength;
			END;
		END InitContentReader;

		PROCEDURE Receive * (VAR buf: ARRAY OF CHAR;  ofs, size, min: SIZE;  VAR len: SIZE; VAR res: INTEGER);
		VAR
			token: ARRAY 16 OF CHAR;
			i, total: SIGNED32; r: INTEGER;
			ch: CHAR;
		BEGIN
			IF (encoding # "") & Strings.Match("chunked", encoding) THEN
				WHILE (length # 0) & (in.res = Streams.Ok) DO
					WHILE (total < size) & (i < length) DO
						in.Char(ch);
						buf[ofs + total] := ch;
						INC(i);
						INC(total)
					END;
					i := 0;
					in.SkipLn;in.SkipSpaces; in.Token(token); Strings.HexStrToSize(token, length, r); in.SkipLn;
				END;
				len := total
			ELSE
				IF length >= 0 THEN
					WHILE (i < size) & (i < length) DO in.Char(ch);  buf[ofs + i] := ch; INC(i) END;
					DEC(length, i);
				ELSE
					WHILE (in.res = Streams.Ok) & (i < size) DO in.Char(ch); buf[ofs + i] := ch; INC(i) END;
				END;
				len := i
			END;
			IF len < min THEN
				res := Streams.EOF
			ELSE
				res := Streams.Ok
			END
		END Receive;
	END ContentReader;

PROCEDURE Head*(CONST url : ARRAY OF CHAR; VAR con : TCP.Connection; VAR header: WebHTTP.ResponseHeader; VAR res : INTEGER);
VAR
	host : ARRAY 128 OF CHAR;
	path : ARRAY 256 OF CHAR;
	port : SIGNED32;
	fadr : IP.Adr;
	w : Streams.Writer;
	r : Streams.Reader;
BEGIN
	IF WebHTTP.SplitHTTPAdr(url, host, path, port) THEN
		IF path = "" THEN path := "/" END;
		DNS.HostByName(host, fadr, res);
		IF res = DNS.Ok THEN
			IF  con = NIL THEN NEW(con); con.Open(TCP.NilPort, fadr, port, res); END;
			IF res = TCP.Ok THEN
				Streams.OpenWriter(w, con.Send);
				Streams.OpenReader(r, con.Receive);
				WebHTTP.WriteRequestLine(w, 1, 1, WebHTTP.HeadM, path, host); w.Ln(); w.Update();
				WebHTTP.ParseReply(r, header, res, log);
				IF res = WebHTTP.OK THEN res := Ok END;
				con.Close
			ELSE
				log.Enter; log.String("Head could not connect to  : "); log.String(host); log.Exit
			END
		ELSE
			log.Enter; log.String("Host not found : "); log.String(host); log.Exit
		END;
	END;
END Head;

(** The HTTP versions is ignored and set to 1.0; uri and host are ignored and taken from the url parameter *)
PROCEDURE Get*(CONST url : ARRAY OF CHAR; VAR rHeader : WebHTTP.RequestHeader;
								VAR con : TCP.Connection; VAR header: WebHTTP.ResponseHeader; VAR out : Streams.Reader; VAR res : INTEGER);
VAR
	host : ARRAY 128 OF CHAR;
	path : ARRAY 256 OF CHAR;
	port : SIGNED32;
	fadr : IP.Adr;
	w : Streams.Writer;
	x : WebHTTP.AdditionalField;
	tls: TLS.Connection;
BEGIN
	IF WebHTTP.SplitHTTPAdr(url, host, path, port) THEN
		IF path = "" THEN path := "/" END;
		DNS.HostByName(host, fadr, res);
		IF res = DNS.Ok THEN
			IF  con = NIL THEN
				IF port = WebHTTP.HTTPPort THEN
					NEW(con);
				ELSE
					NEW(tls);
					con := tls;
				END;
				con.Open(TCP.NilPort, fadr, port, res);
			END;
			IF res = TCP.Ok THEN
				Streams.OpenWriter(w, con.Send);
				Streams.OpenReader(out, con.Receive);
				WebHTTP.WriteRequestLine(w, 1, 0, WebHTTP.GetM, path, host);

				IF rHeader.referer # "" THEN w.String("Referer: "); w.String(rHeader.referer); w.Ln() END;
				IF rHeader.useragent # "" THEN w.String("User-Agent: "); w.String(rHeader.useragent); w.Ln() END;
				IF rHeader.accept # "" THEN w.String("Accept: "); w.String(rHeader.accept); w.Ln() END;
				x := rHeader.additionalFields;

				WHILE x # NIL DO
					w.String(x.key);  w.Char(" "); w.String(x.value);w.Ln();
					x := x.next
				END;
				w.Ln(); w.Update();

				WebHTTP.ParseReply(out, header, res, log);

				WebHTTP.LogResponseHeader(log, header);

				IF res = WebHTTP.OK THEN res := Ok END;
			ELSE
				log.Enter; log.String("Get could not connect to  : "); log.String(host); log.Exit
			END
		ELSE
			log.Enter; log.String("Host not found : "); log.String(host); log.Exit
		END;
	END
END Get;

PROCEDURE CleanUp;
BEGIN
	log.Close
END CleanUp;

BEGIN
	NEW(log, "HTTP Client");
	log.SetLogToOut(FALSE);
	Modules.InstallTermHandler(CleanUp)
END WebHTTPClient.
