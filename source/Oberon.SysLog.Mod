MODULE SysLog IN Oberon;	(* pjm *)

(* Unix-like Syslog server for Oberon. *)

IMPORT Modules, Input, Texts, Oberon, NetSystem;

CONST
	Port = 514;
	BufSize = 2048;
	MinHz = 1;
	MaxHz = 50;

VAR
	task: Oberon.Task;
	sock: NetSystem.Socket;
	w: Texts.Writer;
	hz: SIGNED32;

PROCEDURE WriteLog(VAR w: Texts.Writer; VAR buf: ARRAY OF CHAR; len: SIGNED32);
VAR i, t, d: SIGNED32; ch: CHAR;
BEGIN
	Oberon.GetClock(t, d);
	Texts.WriteString(w, "SysLog"); Texts.WriteDate(w, t, d); Texts.Write(w, " ");
	FOR i := 0 TO len-1 DO
		ch := buf[i];
		IF (ch >= " ") & (ch < 7FX) THEN
			Texts.Write(w, ch)
		ELSE
			Texts.Write(w, "["); Texts.WriteInt(w, ORD(ch), 1); Texts.Write(w, "]")
		END
	END;
	Texts.WriteLn(w)
END WriteLog;

PROCEDURE WriteLogString(VAR w: Texts.Writer; s: ARRAY OF CHAR);
VAR len: SIGNED32;
BEGIN
	len := 0; WHILE s[len] # 0X DO INC(len) END;
	WriteLog(w, s, len)
END WriteLogString;

PROCEDURE Logger(me: Oberon.Task);
VAR ip: NetSystem.IPAdr; port: SIGNED16; len: SIGNED32; buf: ARRAY BufSize OF CHAR;
BEGIN
	IF NetSystem.AvailableDG(sock) # 0 THEN
		len := BufSize;
		NetSystem.ReceiveDG(sock, ip, port, 0, len, buf);
		WriteLog(w, buf, len);
		Texts.Append(Oberon.Log, w.buf);
		hz := MaxHz
	ELSE
		IF hz > MinHz THEN DEC(hz) END
	END;
	me.time := Input.Time() + Input.TimeUnit DIV hz
END Logger;

PROCEDURE Start*;
VAR res: SIGNED16;
BEGIN
	IF task = NIL THEN
		NetSystem.OpenSocket(sock, Port, res);
		IF res = NetSystem.done THEN
			hz := MinHz;
			NEW(task); task.handle := Logger; task.safe := FALSE;
			task.time := Input.Time();
			Oberon.Install(task);
			WriteLogString(w, "Started")
		ELSE
			WriteLogString(w, "Can not open socket")
		END
	ELSE
		WriteLogString(w, "Running")
	END;
	Texts.Append(Oberon.Log, w.buf)
END Start;

PROCEDURE Stop*;
BEGIN
	IF task # NIL THEN
		Oberon.Remove(task); task := NIL;
		NetSystem.CloseSocket(sock);
		WriteLogString(w, "Stopped")
	ELSE
		WriteLogString(w, "Not running")
	END;
	Texts.Append(Oberon.Log, w.buf)
END Stop;

BEGIN
	Texts.OpenWriter(w);
	Modules.InstallTermHandler(Stop);
	task := NIL
END SysLog.

System.Free SysLog ~

SysLog.Start
SysLog.Stop

System.State SysLog