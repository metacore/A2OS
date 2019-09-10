MODULE TCPPortLog; (** AUTHOR "TF"; PURPOSE "TCP port logger"; *)

IMPORT
	Clock, KernelLog, Modules, Network, IP, TCP;

TYPE
	TimeDate = RECORD h, m, s, day,month,year: SIGNED32 END;

PROCEDURE GetTime(VAR dt: TimeDate);
BEGIN
	Clock.Get(dt.h, dt.year);
	dt.s := dt.h MOD 64; dt.h := dt.h DIV 64;
	dt.m := dt.h MOD 64; dt.h := dt.h DIV 64;
	dt.h := dt.h MOD 24;
	dt.day := dt.year MOD 32; dt.year := dt.year DIV 32;
	dt.month := dt.year MOD 16; dt.year := dt.year DIV 16;
	INC(dt.year, 1900)
END GetTime;

PROCEDURE IntToStr(v, len: SIGNED32; VAR s: ARRAY OF CHAR; VAR pos: SIGNED32);
VAR i: SIGNED32;
BEGIN
	FOR i := 1 TO len DO s[pos+len-i] := CHR(ORD("0")+v MOD 10); v := v DIV 10 END;
	INC(pos, len)
END IntToStr;

PROCEDURE TimeDateToStr(dt: TimeDate; VAR s: ARRAY OF CHAR);
VAR p: SIGNED32;
BEGIN
	IntToStr(dt.day, 2, s, p); s[p] := "."; INC(p);
	IntToStr(dt.month, 2, s, p); s[p] := "."; INC(p);
	IntToStr(dt.year, 2, s, p); s[p] := " "; INC(p);
	IntToStr(dt.h, 2, s, p); s[p] := ":"; INC(p);
	IntToStr(dt.m, 2, s, p); s[p] := ":"; INC(p);
	IntToStr(dt.s, 2, s, p); s[p] := 0X
END TimeDateToStr;

PROCEDURE DumpListener(fip: IP.Adr; buffer: Network.Buffer);
VAR fport, lport, flags: SIGNED32; time: TimeDate; adrStr, timeStr: ARRAY 32 OF CHAR;
BEGIN
	GetTime(time); TimeDateToStr(time, timeStr);
	fport := Network.GetNet2(buffer.data, buffer.ofs);
	lport := Network.GetNet2(buffer.data, buffer.ofs+2);
	flags := ORD(buffer.data[buffer.ofs+13]);
	IP.AdrToStr(fip, adrStr);
	KernelLog.Enter;  KernelLog.String(timeStr);
	KernelLog.String(" Rejected TCP segment to port "); KernelLog.Int(lport, 1); KernelLog.String(" from "); KernelLog.String(adrStr);
	KernelLog.String(":"); KernelLog.Int(fport, 1); KernelLog.String(" {");
	IF ODD(ASH(flags, -7)) THEN KernelLog.String(" res7") END;
	IF ODD(ASH(flags, -6)) THEN KernelLog.String(" res6") END;
	IF ODD(ASH(flags, -5)) THEN KernelLog.String(" URG") END;
	IF ODD(ASH(flags, -4)) THEN KernelLog.String(" ACK") END;
	IF ODD(ASH(flags, -3)) THEN KernelLog.String(" PSH") END;
	IF ODD(ASH(flags, -2)) THEN KernelLog.String(" RST") END;
	IF ODD(ASH(flags, -1)) THEN KernelLog.String(" SYN") END;
	IF ODD(flags) THEN KernelLog.String(" FIN") END;
	KernelLog.String(" } ");
	KernelLog.Exit
END DumpListener;

PROCEDURE Install*;
BEGIN
	TCP.SetDefaultListener(DumpListener);
	KernelLog.Enter; KernelLog.String("Default TCP port listener installed"); KernelLog.Exit
END Install;

PROCEDURE Remove*;
BEGIN
	TCP.SetDefaultListener(NIL);
	KernelLog.Enter; KernelLog.String("Default TCP port listener removed"); KernelLog.Exit
END Remove;

BEGIN
	Modules.InstallTermHandler(Remove)
END TCPPortLog.

TCPPortLog.Install

