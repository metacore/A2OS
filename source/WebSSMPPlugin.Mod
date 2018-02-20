(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE WebSSMPPlugin; (** AUTHOR "tf/be"; PURPOSE "SSMP: Server-Side Modified Pages"; *)

(* HTTPPlugin for ServerSide Modified Pages *)

IMPORT
		Streams, Commands, Classes := TFClasses, Strings, Files, WebHTTP, WebHTTPServer;

CONST
	MaxServiceNameSize* = 32;
	PluginName = "SSMP-Plugin";

TYPE
	SSMPMethod* = PROCEDURE {DELEGATE}(VAR request : WebHTTP.RequestHeader; VAR in : Streams.Reader; VAR out : Streams.Writer);

	ServiceInfo = OBJECT
	VAR
		name : ARRAY MaxServiceNameSize OF CHAR;
		service : SSMPMethod;
	END ServiceInfo;

	SSMPPlugin = OBJECT(WebHTTPServer.HTTPPlugin)
		PROCEDURE &Init*(CONST name: WebHTTPServer.Name);
		BEGIN
			Init^(PluginName)
		END Init;

		PROCEDURE CanHandle*(host: WebHTTPServer.Host; VAR request: WebHTTP.RequestHeader; secure : BOOLEAN): BOOLEAN;
		VAR name, ext: ARRAY 16 OF CHAR;
		BEGIN
			Files.SplitExtension(request.uri, name, ext);
			Strings.UpperCase(ext);
			RETURN (ext = "SSMP") & ((request.method = WebHTTP.GetM) OR (request.method = WebHTTP.HeadM))
		END CanHandle;

		PROCEDURE Handle*(host: WebHTTPServer.Host; VAR request: WebHTTP.RequestHeader; VAR reply: WebHTTP.ResponseHeader;
			VAR in: Streams.Reader; VAR out: Streams.Writer);
		VAR f: Files.File; chunker: WebHTTP.ChunkedOutStream; w: Streams.Writer;
		BEGIN
			WebHTTP.SetAdditionalFieldValue(request.additionalFields, "If-Modified-Since", " ");
			LocateResource(host, request, reply, f);
			WebHTTPServer.GetDefaultResponseHeader(request, reply);
			NEW(chunker, w, out, request, reply);
			IF (f # NIL) THEN
				WebHTTP.SendResponseHeader(reply, out);
				IF (request.method = WebHTTP.GetM) THEN
					WriteFile(request, w, f);
					chunker.Close
				END
			ELSE
				reply.statuscode := WebHTTP.NotFound;
				WebHTTP.SendResponseHeader(reply, out);
				IF (request.method = WebHTTP.GetM) THEN
					w.String("<html><head><title>404 - Not Found</title></head>");
					w.String("<body>HTTP 404 - File Not Found<hr><address>");
					w.String(WebHTTPServer.ServerVersion); w.String("</address></body></html>");
					w.Ln; w.Update;
					chunker.Close
				END
			END
		END Handle;
	END SSMPPlugin;

VAR services : Classes.List;

PROCEDURE ExecuteService(CONST name : ARRAY OF CHAR; VAR request : WebHTTP.RequestHeader; in : Streams.Reader; out : Streams.Writer);
VAR i : LONGINT;
	o : ANY; info : ServiceInfo;
BEGIN
	services.Lock;
	FOR i := 0 TO services.GetCount() - 1 DO
		o := services.GetItem(i); info := o(ServiceInfo);
		IF info.name = name THEN info.service(request, in, out); services.Unlock; RETURN END;
	END;
	services.Unlock;
	out.String("<B>Service not available ("); out.String(name); out.String(")</B>")
END ExecuteService;

PROCEDURE WriteFile*(VAR request: WebHTTP.RequestHeader; VAR s: Streams.Writer; f: Files.File);
VAR r: Files.Reader; ch: CHAR; serviceName: ARRAY MaxServiceNameSize OF CHAR;
BEGIN
	Files.OpenReader(r, f, 0);
	LOOP
		ch := r.Get();
		IF r.res # 0 THEN EXIT END;
		IF ch = "&" THEN
			IF r.Peek() = "&" THEN
				ch := r.Get();
				r.Token(serviceName);
				ExecuteService(serviceName, request, r, s)
			ELSE s.Char(ch)
			END
		ELSE s.Char(ch)
		END
	END;
	s.Update
END WriteFile;

PROCEDURE RegisterMethod*(CONST name: ARRAY OF CHAR; handler : SSMPMethod);
VAR new : ServiceInfo;
BEGIN {EXCLUSIVE}
	NEW(new); COPY(name, new.name); new.service := handler; services.Add(new)
END RegisterMethod;

PROCEDURE UnregisterMethod*(CONST name: ARRAY OF CHAR);
VAR i : LONGINT; o, h : ANY;
BEGIN {EXCLUSIVE}
	services.Lock;
	FOR i := 0 TO services.GetCount() - 1 DO
		o := services.GetItem(i); IF o(ServiceInfo).name = name THEN h := o(ServiceInfo) END;
	END;
	services.Unlock;
	IF h # NIL THEN services.Remove(h) END
END UnregisterMethod;

PROCEDURE Install*(context : Commands.Context); (** [{host}]. Host may include wildcards. *)
VAR
	host: ARRAY 1024 OF CHAR;
	hl: WebHTTPServer.HostList; ssmpPlugin: SSMPPlugin;
BEGIN
	NEW(ssmpPlugin, PluginName);

	REPEAT
		context.arg.SkipWhitespace; context.arg.String(host);
		Strings.Trim(host, " ");

		hl := WebHTTPServer.FindHosts(host);
		IF (hl # NIL) THEN
			WHILE (hl # NIL) DO
				hl.host.AddPlugin(ssmpPlugin);
				context.out.String(PluginName); context.out.String(" added to ");
				IF (hl.host.name = "") THEN context.out.String("default host")
				ELSE context.out.String(hl.host.name)
				END;
				context.out.Ln;
				hl := hl.next
			END
		ELSE
			context.out.String("Host '"); context.out.String(host); context.out.String("' not found."); context.out.Ln
		END
	UNTIL (context.arg.res # Streams.Ok);
END Install;

BEGIN
	NEW(services)
END WebSSMPPlugin.


System.Free WebSSMPPlugin ~

Aos.Call WebSSMPPlugin.Install eth20853 ~
Aos.Call WebSSMPPlugin.Uninstall ~ TODO