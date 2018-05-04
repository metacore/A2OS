MODULE OEBSerialInterfaces;
(**
	AUTHOR Timothée Martiel, 05/2016
	PURPOSE OEB Server Interface for Serial devices
*)

IMPORT
	Modules, Strings, Serials, Streams,
	OEBInterfaces;

CONST
	MaxLineSize = 128;

TYPE
	Interface * = OBJECT (OEBInterfaces.Interface)
	VAR
		lines: ARRAY Serials.MaxPorts OF Line;
		readers: ARRAY Serials.MaxPorts OF Streams.Reader;
		writers: ARRAY Serials.MaxPorts OF Streams.Writer;

		PROCEDURE & Init *;
		BEGIN
			InitInterface("Serial", "SerialInterface")
		END Init;

		PROCEDURE Send * (session: OEBInterfaces.Session; CONST cmd: ARRAY OF CHAR): BOOLEAN;
		VAR
			writer: Streams.Writer;
		BEGIN
			writer := writers[session(Session).port];
			writer.String(cmd);
			writer.Char(OEBInterfaces.CR);
			writer.Char(OEBInterfaces.LF);
			writer.Update
		END Send;

		PROCEDURE Receive * (VAR session: OEBInterfaces.Session; VAR msg: ARRAY OF CHAR): BOOLEAN;
		VAR
			serialSession: Session;
			port: Serials.Port;
			p: LONGINT;
			c: CHAR;
		BEGIN
			LOOP
				FOR p := 0 TO Serials.MaxPorts - 1 DO
					IF port # NIL THEN
						LOOP
							IF port.Available() = 0 THEN EXIT END;
							c := readers[p].Get();
							lines[p].buffer[lines[p].tail] := c;
							lines[p].complete := (c = OEBInterfaces.CR) OR (c = OEBInterfaces.LF);
							IF lines[p].complete THEN
								(* Get message, without ending CR or LF *)
								lines[p].buffer[lines[p].tail] := 0X;
								COPY(lines[p].buffer, msg);
								lines[p].tail := 0;
								lines[p].buffer := "";
								lines[p].complete := FALSE;
								IF msg = "INFO: Enter" THEN
									NEW(serialSession, p);
									session := serialSession
								ELSE
									session := sessions;
									WHILE (session # NIL) & (session(Session).port # p) DO session := session.next END
								END
							END;
							INC(lines[p].tail);
						END;
					END
				END
			END
		END Receive;
	END Interface;

	Session * = OBJECT (OEBInterfaces.Session)
	VAR
		port: LONGINT;

		PROCEDURE & Init (port: LONGINT);
		VAR
			name: ARRAY 128 OF CHAR;
		BEGIN
			name := "PORT";
			Strings.AppendInt(name, port);
			InitSession(name);
			SELF.port := port;
		END Init;
	END Session;

	Factory = OBJECT (OEBInterfaces.Factory)
		PROCEDURE NewInterface (CONST param: ARRAY OF CHAR): OEBInterfaces.Interface;
		VAR
			itf: Interface;
		BEGIN
			NEW(itf);
			RETURN itf
		END NewInterface;
	END Factory;

	Line = RECORD
		buffer: ARRAY MaxLineSize OF CHAR;
		tail: LONGINT;
		complete: BOOLEAN;
	END;

VAR
	factory: Factory;

	PROCEDURE Cleanup;
	BEGIN
		OEBInterfaces.Unregister(factory)
	END Cleanup;

BEGIN
	NEW(factory);
	OEBInterfaces.Register("Serial", factory);
	Modules.InstallTermHandler(Cleanup)
END OEBSerialInterfaces.
