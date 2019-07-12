MODULE RegisterRFW; (** AUTHOR "TF"; PURPOSE "Simple CGI registration form saver"; *)

IMPORT
	Streams, WebHTTP, HTTPSupport, WebCGI, Files, KernelLog, Dates, Strings;


PROCEDURE AppendData(filename : ARRAY OF CHAR; r : HTTPSupport.HTTPRequest);
VAR
	i : LONGINT; p : ANY;
	var: HTTPSupport.HTTPVariable;
	f : Files.File;
	w : Files.Writer;
	date : ARRAY 64 OF CHAR;
BEGIN {EXCLUSIVE}
	f := Files.Old(filename);
	IF f = NIL THEN f := Files.New(filename); Files.Register(f) END;
	Files.OpenWriter(w, f, f.Length());
	w.String("!BEGIN"); w.Ln;
	Strings.FormatDateTime("yyyy.mm.dd hh:nn:ss", Dates.Now(), date);
	w.String(date); w.Ln;
	r.variables.Lock;
	FOR i := 0 TO r.variables.GetCount() - 1 DO
		p := r.variables.GetItem(i); var := p(HTTPSupport.HTTPVariable);
		w.String(var.name); w.String("="); w.String(var.value);  w.Ln;
	END;
	r.variables.Unlock;
	w.String("!END"); w.Ln;
	w.Update;
	f.Update;
END AppendData;

PROCEDURE RegisterRFW4*(context : WebCGI.CGIContext);
VAR
	r : HTTPSupport.HTTPRequest;
	i : LONGINT; p : ANY;
	var: HTTPSupport.HTTPVariable;
	w : Streams.Writer;
	chunker : WebHTTP.ChunkedOutStream;

	errors : BOOLEAN;

	PROCEDURE Check(name : ARRAY OF CHAR);
	VAR var: HTTPSupport.HTTPVariable;
	BEGIN
		var := r.GetVariableByName(name);
		IF (var = NIL) OR (var.value= "") THEN
			errors := TRUE;
			w.String('<p><font color="#FF0000" size="7"><blink>!</blink></font>');
			w.String("Das Feld "); w.String(name); w.String(" fehlt.");
			w.String('<font color="#FF0000" size="7"><blink>!</blink></font></p>');
		END
	END Check;


BEGIN
(* reply *)
	NEW(chunker, w, context.w, context.request.header, context.reply);
	context.reply.statuscode := WebHTTP.OK;
	WebHTTP.SendResponseHeader(context.reply, context.w);
	w.String("<html><head><title>Register</title></head>");
	w.String("<body>");

(* data evaluation *)

	r := context.request;

	errors := FALSE;
	Check("PNr");
	Check("Name");
	Check("Vorname");
	Check("Strasse");
	Check("PLZOrt");
	Check("Land");

	IF ~errors THEN
		AppendData("RFW4Regs.dat", r);
		KernelLog.String("New registration in RFW4Regs.dat"); KernelLog.Ln;

		w.String("Sie k&ouml;nnen den Webbrowser jetzt beenden um mit Raily zu arbeiten. <br/>");
		w.String("Die folgenden Daten wurden gespeichert:<br/><br/>");

		r.variables.Lock;
		FOR i := 0 TO r.variables.GetCount() - 1 DO
			p := r.variables.GetItem(i); var := p(HTTPSupport.HTTPVariable);
			w.String(var.name); w.String(" = ");  w.String(var.value);  w.String("<br/>");
		END;
		r.variables.Unlock
	ELSE
		AppendData("RFW4Incomplete.dat", r);
		KernelLog.String("New partial registration in RFW4Incomplete.dat"); KernelLog.Ln;
		w.String("Bitte druecken Sie auf  Zurueck in Ihrem Browser und geben Sie die fehlenden Informationen ein.<br/>");
	END;

	w.String("</body></html>");
	w.Ln; w.Update;
	chunker.Close;
END RegisterRFW4;

PROCEDURE RegisterRFW3*(context : WebCGI.CGIContext);
VAR
	r : HTTPSupport.HTTPRequest;
	i : LONGINT; p : ANY;
	var: HTTPSupport.HTTPVariable;
	w : Streams.Writer;
	chunker : WebHTTP.ChunkedOutStream;

	errors : BOOLEAN;

	PROCEDURE Check(name : ARRAY OF CHAR);
	VAR var: HTTPSupport.HTTPVariable;
	BEGIN
		var := r.GetVariableByName(name);
		IF (var = NIL) OR (var.value= "") THEN
			errors := TRUE;
			w.String('<p><font color="#FF0000" size="7"><blink>!</blink></font>');
			w.String("Das Feld "); w.String(name); w.String(" fehlt.");
			w.String('<font color="#FF0000" size="7"><blink>!</blink></font></p>');
		END
	END Check;


BEGIN
(* reply *)
	NEW(chunker, w, context.w, context.request.header, context.reply);
	context.reply.statuscode := WebHTTP.OK;
	WebHTTP.SendResponseHeader(context.reply, context.w);
	w.String("<html><head><title>Register</title></head>");
	w.String("<body>");

(* data evaluation *)

	r := context.request;

	errors := FALSE;
	Check("PNr");
	Check("Name");
	Check("Vorname");
	Check("Strasse");
	Check("PLZOrt");
	Check("Land");

	IF ~errors THEN
		AppendData("RFW3Regs.dat", r);
		KernelLog.String("New registration in RFW3Regs.dat"); KernelLog.Ln;

		w.String("Sie k&ouml;nnen den Webbrowser jetzt beenden um mit Raily zu arbeiten. <br/>");
		w.String("Die folgenden Daten wurden gespeichert:<br/><br/>");

		r.variables.Lock;
		FOR i := 0 TO r.variables.GetCount() - 1 DO
			p := r.variables.GetItem(i); var := p(HTTPSupport.HTTPVariable);
			w.String(var.name); w.String(" = ");  w.String(var.value);  w.String("<br/>");
		END;
		r.variables.Unlock
	ELSE
		AppendData("RFW3Incomplete.dat", r);
		KernelLog.String("New partial registration in RFW3Incomplete.dat"); KernelLog.Ln;
		w.String("Bitte druecken Sie auf  Zurueck in Ihrem Browser und geben Sie die fehlenden Informationen ein.<br/>");
	END;

	w.String("</body></html>");
	w.Ln; w.Update;
	chunker.Close;
END RegisterRFW3;

END RegisterRFW.

System.Free RegisterRFW ~