MODULE VNCController; (** AUTHOR "Timothée Martiel, 2014/11"; PURPOSE "Basic VNC Server configuration and startup"; *)

IMPORT
	KernelLog := Trace,
	Commands, Streams,
	WMVNCView;

VAR
	context: Commands.Context;
	r: Streams.StringReader;
	w: Streams.Writer;
	params: ARRAY 1024 OF CHAR;
	res: LONGINT;
	msg: ARRAY 1024 OF CHAR;

BEGIN
	params := 'AOS "a" 5000 0 0 1024 768';
	NEW(r, 1024);
	r.Set(params);
	Streams.OpenWriter(w, KernelLog.Send);
	NEW(context, NIL, r, w, NIL, NIL);
	Commands.Activate('WMVNCView.Install', context, {}, res, msg);
	IF res # Commands.Ok THEN KernelLog.String(msg); KernelLog.Ln END;
END VNCController.
