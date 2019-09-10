MODULE WMArmenianIME; (** AUTHOR "tf"; PURPOSE "Write armenian characters"; *)

IMPORT
	WMInputMethods, Texts, KernelLog;

CONST
	imeName* = "Armenian";

TYPE
	IME* = OBJECT(WMInputMethods.IME)


		(* Map characters from US-Keyboard to  armenian keyboard *)
		PROCEDURE KeyEvent*(ucs : SIZE; flags : SET; keysym : SIZE);
		BEGIN
			CASE ucs OF
			(* unshifted *)
				(* top row : `1234567890-=\ *)
				| 60H : InsertChar(0000055DH) (**)
				| 31H : InsertChar(00000567H) (**)
				| 32H : InsertChar(00000569H) (**)
				| 33H : InsertChar(00000583H) (**)
				| 34H : InsertChar(00000571H) (**)
				| 35H : InsertChar(0000057BH) (**)
				| 36H : InsertChar(00000582H) (**)
				| 37H : InsertChar(00000587H) (**)
				| 38H : InsertChar(0000057CH) (**)
				| 39H : InsertChar(00000579H) (**)
				| 30H : InsertChar(00000573H) (**)
				| 2DH : InsertChar(0000044DH) (*-*)
				| 3DH : InsertChar(0000056AH) (**)
				| 5CH : InsertChar(00000577H) (**)

				(* first row: qwertyuiop[] *)
				| 71H : InsertChar(00000584H) (**)
				| 77H : InsertChar(00000578H) (**)
				| 65H : InsertChar(00000565H) (**)
				| 72H : InsertChar(00000580H) (**)
				| 74H : InsertChar(0000057FH) (**)
				| 79H : InsertChar(00000568H) (**)
				| 75H : InsertChar(00000582H) (**)
				| 69H : InsertChar(0000056BH) (**)
				| 6FH : InsertChar(00000585H) (**)
				| 70H : InsertChar(0000057AH) (**)
				| 5BH : InsertChar(0000056DH) (**)
				| 5DH : InsertChar(0000056EH) (**)

				(* second row : asdfghjkl;' *)
				| 61H : InsertChar(00000561H) (**)
				| 73H : InsertChar(0000057DH) (**)
				| 64H : InsertChar(00000564H) (**)
				| 66H : InsertChar(00000586H) (**)
				| 67H : InsertChar(00000563H) (**)
				| 68H : InsertChar(00000570H) (**)
				| 6AH : InsertChar(00000575H) (**)
				| 6BH : InsertChar(0000056FH) (**)
				| 6CH : InsertChar(0000056CH) (**)
				| 3BH : InsertChar(00000436H) (*;*)
				| 27H : InsertChar(0000044DH) (*'*)

				(* third row : zxcvbnm,./;' *)
				| 7AH : InsertChar(00000566H) (**)
				| 78H : InsertChar(00000572H) (**)
				| 63H : InsertChar(00000581H) (**)
				| 76H : InsertChar(0000057EH) (**)
				| 62H : InsertChar(00000562H) (**)
				| 6EH : InsertChar(00000576H) (**)
				| 6DH : InsertChar(00000574H) (**)
				| 2CH : InsertChar(00000431H) (*,*)
				| 2EH : InsertChar(0000044EH) (*.*)
				| 2FH : InsertChar(0000002EH) (*/*)
			(* shifted *)
				(* top row : ~!@#$%^&*()_+| *)
				| 7EH : InsertChar(0000055CH) (**)
				| 21H : InsertChar(00000537H) (**)
				| 40H : InsertChar(00000539H) (**)
				| 23H : InsertChar(00000553H) (**)
				| 24H : InsertChar(00000541H) (**)
				| 25H : InsertChar(0000054BH) (**)
				| 5EH : InsertChar(00000552H) (**)
				| 26H : InsertChar(00000587H) (**)
				| 2AH : InsertChar(0000054CH) (**)
				| 28H : InsertChar(00000549H) (**)
				| 29H : InsertChar(00000543H) (**)
				| 5FH : InsertChar(0000044DH) (*-*)
				| 2BH : InsertChar(0000053AH) (**)
				| 7CH : InsertChar(00000547H) (**)

				(* first row: QWERTYUIOP{} *)
				| 51H : InsertChar(00000553H) (**)
				| 57H : InsertChar(00000548H) (**)
				| 45H : InsertChar(00000535H) (**)
				| 52H : InsertChar(00000550H) (**)
				| 54H : InsertChar(0000054FH) (**)
				| 59H : InsertChar(00000538H) (**)
				| 55H : InsertChar(00000552H) (**)
				| 49H : InsertChar(0000053BH) (**)
				| 4FH : InsertChar(00000555H) (**)
				| 50H : InsertChar(0000054AH) (**)
				| 7BH : InsertChar(0000053DH) (**)
				| 7DH : InsertChar(0000053EH) (**)

				(* second row : ASDFGHJKL:"| *)
				| 41H : InsertChar(00000531H) (**)
				| 53H : InsertChar(0000054DH) (**)
				| 44H : InsertChar(00000534H) (**)
				| 46H : InsertChar(00000556H) (**)
				| 47H : InsertChar(00000533H) (**)
				| 48H : InsertChar(00000540H) (**)
				| 4AH : InsertChar(00000545H) (**)
				| 4BH : InsertChar(0000053FH) (**)
				| 4CH : InsertChar(0000053CH) (**)
(*				| 2AH : InsertChar(00000416H) (*:*)
*)				| 22H : InsertChar(0000042DH) (*"*)
(*				| 7CH : InsertChar(0000002FH) (*|*)
*)
				(* third row : ZXCVBNM<>? *)
				| 5AH : InsertChar(00000536H) (**)
				| 58H : InsertChar(00000542H) (**)
				| 43H : InsertChar(00000551H) (**)
				| 56H : InsertChar(0000054EH) (**)
				| 42H : InsertChar(00000532H) (**)
				| 4EH : InsertChar(00000546H) (**)
				| 4DH : InsertChar(00000544H) (**)
				| 3CH : InsertChar(00000559H) (*«*)
				| 3EH : InsertChar(0000042EH) (*»*)
				| 3FH : InsertChar(0000055EH) (**)
			ELSE
				InsertChar(ucs)
			END
		END KeyEvent;

	END IME;

PROCEDURE Install*;
VAR ime : IME;
BEGIN
	NEW(ime);
	WMInputMethods.InstallIME(ime);
END Install;

(* helper procedure for development : return the UCS code of a selected character in a text *)
PROCEDURE SelectedCharToUCS*;
VAR r : Texts.TextReader;
	selectionText: Texts.Text;
	ucs : SIGNED32;
	from, to : Texts.TextPosition;
BEGIN
	IF Texts.GetLastSelection(selectionText, from, to) THEN
		selectionText.AcquireRead;
		NEW(r, selectionText);
		r.SetPosition(MIN(from.GetPosition(), to.GetPosition()));
		r.ReadCh(ucs);
		selectionText.ReleaseRead;
		KernelLog.String("InsertChar("); KernelLog.Hex(ucs, 0); KernelLog.String("H) (**)"); KernelLog.Ln;
	END;
END SelectedCharToUCS;



END WMArmenianIME.Install~
System.Free WMArmenianIME~
WMArmenianIME.SelectedCharToUCS ~

WMKeyCode.Open ~
