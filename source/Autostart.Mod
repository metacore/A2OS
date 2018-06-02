(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Autostart; (** AUTHOR "be"; PURPOSE "Execute the commands in the Autostart section of Configuration.XML"; *)

IMPORT XML, XMLObjects, Commands, Configuration, KernelLog;

CONST
	Trace = TRUE;

PROCEDURE Run*;
VAR enum: XMLObjects.Enumerator; p: ANY; e: XML.Element; value: XML.String;
	autostart : XML.Element;
	msg: ARRAY 128 OF CHAR; res: WORD;
BEGIN
	autostart := Configuration.GetSection("Autostart");
	IF autostart # NIL THEN
		enum := autostart.GetContents();
		WHILE enum.HasMoreElements() DO
			p := enum.GetNext();
			IF p IS XML.Element THEN
				e := p(XML.Element); value := e.GetAttributeValue("value");
				IF (value^ # "") THEN
					IF Trace THEN KernelLog.String("Autostart: executing "); KernelLog.String(value^); KernelLog.Ln END;
					Commands.Call(value^, {Commands.Wait}, res, msg);
					IF (res # 0) THEN
						KernelLog.String("Autostart: error executing "); KernelLog.String(value^); KernelLog.String(": ");
						IF (msg # "") THEN KernelLog.String(msg)
						ELSE KernelLog.String("res = "); KernelLog.Int(res, 0)
						END;
						KernelLog.Ln
					END
				END
			END
		END
	END;
END Run;

END Autostart.

System.Free Autostart ~

EditTools.OpenAscii Configuration.XML~
Configuration.Init

Aos.Call Autostart.Run ~
