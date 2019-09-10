(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Pipes; (** AUTHOR "pjm"; PURPOSE "Simple pipe object"; *)
(* 2003.07.23 no tricks variant but working *)

CONST
	Ok = 0;
	Closed = 4201;

TYPE
		(** A pipe is a bounded buffer that can be used as an Streams Reader and Writer.  Everything sent to the sink can be read from the source. *)
	Pipe* = OBJECT
		VAR
			head, num: SIZE;
			buffer: POINTER TO ARRAY OF CHAR;
			closed: BOOLEAN;

		(** return the number of bytes that can be read without blocking *)
		PROCEDURE Available*() : SIZE;
		BEGIN
			RETURN num
		END Available;

		PROCEDURE Send*(CONST buf: ARRAY OF CHAR; ofs, len: SIZE; propagate : BOOLEAN; VAR res: INTEGER);
		BEGIN
			ASSERT(len >= 0);
			BEGIN {EXCLUSIVE}
				LOOP
					IF len = 0 THEN res := Ok; EXIT END;
					AWAIT((num < LEN(buffer)) OR closed);
					IF closed THEN
						res := Closed; EXIT
					ELSIF num < LEN(buffer) THEN
						buffer[(head+num) MOD LEN(buffer)] := buf[ofs];
						INC(ofs); INC(num); DEC(len)
					END
				END
			END
		END Send;

		PROCEDURE Receive*(VAR buf: ARRAY OF CHAR; ofs, size, min: SIZE; VAR len: SIZE; VAR res: INTEGER);
		BEGIN
			ASSERT((size > 0) & (min <= size) & (min >= 0));
			len := 0;
			BEGIN {EXCLUSIVE}
				LOOP
					IF min > 0 THEN AWAIT((num > 0) OR closed) END;	(* wait until some data available *)
					IF num > 0 THEN
						buf[ofs] := buffer[head];
						head := (head + 1) MOD LEN(buffer);
						DEC(num); INC(ofs); INC(len); DEC(min); DEC(size)
					ELSIF closed THEN
						res := Closed; EXIT
					END;
					IF (num = 0) & (min <= 0) OR (size = 0) THEN res := Ok; EXIT END
				END
			END
		END Receive;

		PROCEDURE &Init*(size: SIZE);
		BEGIN
			head := 0; num := 0;
			IF (buffer = NIL) OR (LEN(buffer) # size) THEN
				NEW( buffer, size );
			END;
			closed := FALSE
		END Init;

		PROCEDURE Close*;
		BEGIN {EXCLUSIVE}
			closed := TRUE
		END Close;

	END Pipe;

(** Any stream input procedure or method. Identical to the definition in Streams.Mod, but I don't want to import that here*)
TYPE	Receiver* = PROCEDURE {DELEGATE} ( VAR buf: ARRAY OF CHAR;  ofs, size, min: SIZE;  VAR len: SIZE; VAR res: INTEGER );
(*makes a decoupled copy of a receiver*)
(*internally it's a pipe that automatically reads the input in a continuous loop*)
TYPE ReadDecoupler*= OBJECT
	VAR
		pipe: Pipe;
		inputReceiver: Receiver;
		smallbuf: ARRAY[128] OF CHAR;
		len: SIZE;
		res: INTEGER;

	PROCEDURE &InitReadDecoupler*(inputReceiver: Receiver);
	BEGIN
		NEW(pipe,128);
		SELF.inputReceiver:=inputReceiver;
	END InitReadDecoupler;

	PROCEDURE Receive*(VAR buf: ARRAY OF CHAR; ofs, size, min: SIZE; VAR len: SIZE; VAR res: INTEGER);
	BEGIN
		pipe.Receive(buf,ofs,size,min,len,res);
	END Receive;

BEGIN{ACTIVE}

		LOOP
			(*todo: check res, if inputReceiver throws anything but 'OK' exit the loop*)
			inputReceiver(smallbuf, 0, 128, 1, len, res); (*read at least 1 byte into the small buffer*)
			pipe.Send(smallbuf, 0, len, FALSE, res);   (*feed the amount read (usually 1 entire line) into the pipe to cross threads*)
		END;
END ReadDecoupler;

END Pipes.
