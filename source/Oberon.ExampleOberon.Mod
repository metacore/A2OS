MODULE ExampleOberon IN Oberon;	(* pjm *)
(** AUTHOR "pjm"; PURPOSE "How to use Oberon modules from an active object"; *)

IMPORT AosKernel := Kernel IN A2, Texts, Oberon, Kernel;

TYPE
	Example = OBJECT
		VAR i: SIGNED32; w: Texts.Writer; t: Texts.Text; timer: AosKernel.Timer;
	BEGIN {ACTIVE}
		NEW(timer);
		Kernel.LockOberon;
		Texts.OpenWriter(w);
		NEW(t); Texts.Open(t, "");
		Oberon.OpenText("Example", t, 200, 200);
		Kernel.UnlockOberon;
		FOR i := 1 TO 10 DO
			Kernel.LockOberon;
			Texts.WriteString(w, "Example "); Texts.WriteInt(w, i, 1); Texts.WriteLn(w);
			Texts.Append(t, w.buf);
			Kernel.UnlockOberon;
			timer.Sleep(1000)
		END
	END Example;

PROCEDURE Test*;
VAR e: Example;
BEGIN
	NEW(e);
END Test;

END ExampleOberon.

System.Free ExampleOberon ~

Aos.Call ExampleOberon.Test
