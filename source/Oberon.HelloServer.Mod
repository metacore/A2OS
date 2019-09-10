MODULE HelloServer IN Oberon;

	IMPORT Modules, NetSystem, Input, Texts, Oberon;

	CONST
		TimePort = 1300;

	VAR
		W: Texts.Writer;
		C: NetSystem.Connection;
		task: Oberon.Task;


	PROCEDURE Handle(C: NetSystem.Connection);
		VAR
			newC: NetSystem.Connection;
			res, remPort: SIGNED16;
			remIP: NetSystem.IPAdr;
			name: ARRAY 128 OF CHAR;
	BEGIN
		NetSystem.Accept(C, newC, res);
		IF res = NetSystem.done THEN
			NetSystem.GetPartner(newC, remIP, remPort);
			NetSystem.GetName(remIP, name);
			Texts.WriteString(W, "Connection from ");
			Texts.WriteString(W, name); Texts.Write(W, ":");
			Texts.WriteInt(W, LONG(remPort) MOD 10000H, 1); Texts.WriteLn(W);
			Texts.Append(Oberon.Log, W.buf);
			NetSystem.WriteString(newC, "Hello World!");
			NetSystem.CloseConnection(newC);
		END
	END Handle;

	PROCEDURE Serve(task: Oberon.Task);
	BEGIN
		IF NetSystem.Requested(C) THEN Handle(C) END;
		task.time := Oberon.Time() + Input.TimeUnit DIV 5
	END Serve;


	PROCEDURE Start*;
		VAR
			res: SIGNED16;
	BEGIN
		IF task = NIL THEN
			NetSystem.OpenConnection(C, TimePort, NetSystem.anyIP, NetSystem.anyport, res);
			IF res = NetSystem.done THEN
				NEW(task);  task.time := 0;  task.safe := FALSE;  task.handle := Serve;  Oberon.Install(task);
				Texts.WriteString(W, "server started")
			ELSE
				Texts.WriteString(W, "can not start server")
			END;
			Texts.WriteLn(W);  Texts.Append(Oberon.Log, W.buf)
		END
	END Start;


	PROCEDURE Stop*;
	BEGIN
		IF task # NIL THEN
			Oberon.Remove(task);  task := NIL;
			NetSystem.CloseConnection(C);
			Texts.WriteString(W, "server stopped");  Texts.WriteLn(W);
			Texts.Append(Oberon.Log, W.buf)
		END
	END Stop;


BEGIN
	Texts.OpenWriter(W);
	Modules.InstallTermHandler(Stop)
END HelloServer.


HelloServer.Start		HelloServer.Stop
