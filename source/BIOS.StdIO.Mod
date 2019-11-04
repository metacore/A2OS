MODULE StdIO;

IMPORT Inputs, Trace, Pipes, Streams, Commands;

CONST Echo* = TRUE;

TYPE Keyboard = OBJECT (Inputs.Sink)

	VAR pipe: Pipes.Pipe;

	PROCEDURE& InitKeyboard;
	BEGIN NEW (pipe, 1024);
	END InitKeyboard;

	PROCEDURE Handle*(VAR msg: Inputs.Message);
	VAR buffer: ARRAY 1 OF CHAR; result: INTEGER;
	BEGIN {EXCLUSIVE}
		IF (msg IS Inputs.KeyboardMsg) & (msg(Inputs.KeyboardMsg).flags * {Inputs.Release} = {}) THEN
			buffer[0] := msg(Inputs.KeyboardMsg).ch;
			pipe.Send (buffer, 0, 1, FALSE, result);
		END;
	END Handle;

END Keyboard;

VAR keyboard: Keyboard;
VAR arg: Streams.StringReader;
VAR stdin: Streams.Reader;
VAR stdout: Streams.Writer;
VAR env-: Commands.Context;

BEGIN
	NEW (keyboard);
	Inputs.keyboard.Register (keyboard);
	NEW (stdin, keyboard.pipe.Receive, 1);
	NEW (stdout, Trace.Send, 1);
	NEW (arg, 100);
	arg.Set ("kernel");
	NEW( env, stdin, arg, stdout, stdout, NIL );
END StdIO.
