(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE DayTime IN Oberon;	(* pjm *)

(* daytime client to request current date and time from a daytime server. *)

IMPORT Input, Texts, Oberon, NetSystem, In, IP IN A2;

CONST
	DayTimePort = 13;
	RetryTimeout = 1;	(* in seconds *)
	MaxTries = 3;

VAR
	w: Texts.Writer;

PROCEDURE GetTime(server: ARRAY OF CHAR; VAR time: ARRAY OF CHAR);
VAR s: NetSystem.Socket; res, remport: SIGNED16; adr, remadr: NetSystem.IPAdr; len, target, try: SIGNED32;
BEGIN
	time[0] := 0X;
	NetSystem.OpenSocket(s, NetSystem.anyport, res);
	IF res = NetSystem.done THEN
		NetSystem.GetIP(server, adr);
		IF ~IP.IsNilAdr(adr) THEN
			try := 0;
			LOOP
				time[0] := 0X;
				NetSystem.SendDG(s, adr, DayTimePort, 0, 1, time);
				target := Input.Time() + RetryTimeout * Input.TimeUnit;
				REPEAT
					len := NetSystem.AvailableDG(s)
				UNTIL (len > 0) OR (Input.Time() - target > 0);
				IF len > 0 THEN
						(* if response packet is bigger than time, it will be truncated *)
					NetSystem.ReceiveDG(s, remadr, remport, 0, len, time);
						(* ensure time string is zero-terminated *)
					time[LEN(time)-1] := 0X;
					EXIT
				END;
				INC(try);
				IF try = MaxTries THEN
					COPY("DayTime: Server did not respond", time);
					EXIT
				END
			END
		ELSE
			COPY("DayTime: Server not found", time)
		END;
		NetSystem.CloseSocket(s)
	ELSE
		COPY("DayTime: Can not open socket", time)
	END
END GetTime;

PROCEDURE WriteTime(VAR w: Texts.Writer; time: ARRAY OF CHAR);
VAR i: SIGNED32;
BEGIN
	i := 0; WHILE (time[i] # 0X) & (time[i] # 0DX) & (time[i] # 0AX) DO INC(i) END;
	time[i] := 0X;
	Texts.WriteString(w, time)
END WriteTime;

PROCEDURE Show*;	(** server *)
VAR server, time: ARRAY 64 OF CHAR;
BEGIN
	In.Open; In.String(server);
	IF In.Done THEN
		GetTime(server, time);
		WriteTime(w, time); Texts.WriteLn(w);
		Texts.Append(Oberon.Log, w.buf)
	END
END Show;

PROCEDURE StrToMonth(VAR str: ARRAY OF CHAR): SIGNED32;
BEGIN
	CASE CAP(str[0]) OF
		"J": IF CAP(str[1]) = "A" THEN
					RETURN 1
				ELSIF CAP(str[2]) = "N" THEN
					RETURN 6
				ELSIF CAP(str[2]) = "L" THEN
					RETURN 7
				END
		|"F": RETURN 2
		|"M": IF CAP(str[2]) = "R" THEN
					RETURN 3
				ELSIF CAP(str[2]) = "Y" THEN
					RETURN 5
				END
		|"A": IF CAP(str[1]) = "P" THEN
					RETURN 4
				ELSIF CAP(str[1]) = "U" THEN
					RETURN 8
				END
		|"S": RETURN 9
		|"O": RETURN 10
		|"N": RETURN 11
		|"D": RETURN 12
	ELSE
		RETURN 0
	END
END StrToMonth;

PROCEDURE SetClock*;	(** server *)
VAR pos, day, month, year, hour, minute, second, t, d: SIGNED32; s: Texts.Scanner;
BEGIN
	pos := Oberon.Log.len;
	Show;
	Texts.OpenScanner(s, Oberon.Log, pos);
	Texts.Scan(s);
	IF (s.class = Texts.Name) & (s.s # "DayTime:") THEN
			(* assume response is of form weekday month day hour ":"  minute ":" second year *)
			(* for example: "Thu Nov  4 13:29:09 1999" *)
		Texts.Scan(s); ASSERT(s.class = Texts.Name);
		month := StrToMonth(s.s); ASSERT(month # 0);
		Texts.Scan(s); ASSERT(s.class = Texts.Int);
		day := s.i;
		Texts.Scan(s); ASSERT(s.class = Texts.Int);
		hour := s.i;
		Texts.Scan(s); ASSERT(s.class = Texts.Char);
		Texts.Scan(s); ASSERT(s.class = Texts.Int);
		minute := s.i;
		Texts.Scan(s); ASSERT(s.class = Texts.Char);
		Texts.Scan(s); ASSERT(s.class = Texts.Int);
		second := s.i;
		Texts.Scan(s); ASSERT(s.class = Texts.Int);
		year := s.i-1900;
		t := (hour*64 + minute)*64 + second;
		d := (year*16 + month)*32 + day;
		Oberon.SetClock(t, d);
	END
END SetClock;

BEGIN
	Texts.OpenWriter(w)
END DayTime.

DayTime.Show natsumi.ethz.ch
DayTime.SetClock natsumi.ethz.ch
System.Time
