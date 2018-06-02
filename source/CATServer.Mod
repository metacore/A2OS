MODULE CATServer; (** AUTHOR "TF"; PURPOSE "Cluster Administration Tool server"; *)

IMPORT
	Modules, Streams, TCP,  TCPServices, AosLog := TFLog, Performance;


CONST CATPort = 9999;
TYPE
	CATAgent = OBJECT (TCPServices.Agent)
		VAR in: Streams.Reader; out: Streams.Writer;
			token : ARRAY 16 OF CHAR;
			x : LONGINT;
	BEGIN {ACTIVE}
		(* open streams *)
		Streams.OpenReader(in, client.Receive);
		Streams.OpenWriter(out, client.Send);
		LOOP
			in.Token(token); in.SkipLn; IF in.res # 0 THEN EXIT END;
			IF token = "getOS" THEN out.String("Aos"); out.Ln; out.Update
			ELSIF token = "getLoad" THEN
				x := ENTIER(Performance.load[0] * 100 + 0.5);
				out.Int(x DIV 100, 3); out.Char(".");out.Int(x DIV 10 MOD 10, 1); out.Int(x MOD 10, 1);
				out.Ln; out.Update
			ELSE out.String("not implemented"); out.Ln; out.Update
			END;
			IF out.res # 0 THEN EXIT END
		END;
		Terminate
	END CATAgent;

VAR cat : TCPServices.Service;
		log : AosLog.Log;

PROCEDURE NewCATAgent(c: TCP.Connection; s: TCPServices.Service): TCPServices.Agent;
VAR a: CATAgent;
BEGIN
	NEW(a, c, s); RETURN a
END NewCATAgent;


PROCEDURE Start*;
VAR res : WORD;
BEGIN
	IF cat = NIL THEN
		NEW(cat, CATPort, NewCATAgent, res);
		log.Enter; log.TimeStamp; log.String("Started"); log.Exit
	END;
END Start;

PROCEDURE Stop*;
BEGIN
	IF cat # NIL THEN
		cat.Stop; cat := NIL;
		log.Enter; log.TimeStamp; log.String("Stopped"); log.Exit
	END;
END Stop;

PROCEDURE Cleanup;
BEGIN
	Stop;
	log.Close()
END Cleanup;

BEGIN
	NEW(log, "CAT Server"); log.SetLogToOut(TRUE);
	Modules.InstallTermHandler(Cleanup)
END CATServer.


Aos.Call CATServer.Start~
System.Free CATServer ~