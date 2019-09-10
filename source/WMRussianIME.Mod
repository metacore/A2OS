MODULE WMRussianIME; (** AUTHOR "tf"; PURPOSE "Write cyrillic characters"; *)

IMPORT
	Strings, WMInputMethods, Texts, KernelLog;

CONST
	imeName* = "Russian";

TYPE
	IME* = OBJECT(WMInputMethods.IME)

		PROCEDURE GetName*() : Strings.String;
		BEGIN
			RETURN Strings.NewString(imeName);
		END GetName;

		(* Map characters from US-Keyboard to  cyrillic keyboard *)
		PROCEDURE KeyEvent*(ucs : SIZE; flags : SET; keysym : SIZE);
		BEGIN
			CASE ucs OF
			(* unshifted *)
				| 60H : InsertChar(00000451H) (*`*)
				(* first row: qwertyuiop[] *)
				| 71H : InsertChar(00000439H) (*q*)
				| 77H : InsertChar(00000446H) (*w*)

				| 65H : InsertChar(00000443H) (*e*)
				| 72H : InsertChar(0000043AH) (*r*)
				| 74H : InsertChar(00000435H) (*t*)
				| 79H : InsertChar(0000043DH) (*y*)
				| 75H : InsertChar(00000433H) (*u*)
				| 69H : InsertChar(00000448H) (*i*)
				| 6FH : InsertChar(00000449H) (*o*)
				| 70H : InsertChar(00000437H) (*p*)
				| 5BH : InsertChar(00000445H) (*[*)
				| 5DH : InsertChar(0000044AH) (*]*)
				(* second row : asdfghjkl;' *)
				| 61H : InsertChar(00000444H) (*a*)
				| 73H : InsertChar(0000044BH) (*s*)
				| 64H : InsertChar(00000432H) (*d*)
				| 66H : InsertChar(00000430H) (*f*)
				| 67H : InsertChar(0000043FH) (*g*)
				| 68H : InsertChar(00000440H) (*h*)
				| 6AH : InsertChar(0000043EH) (*j*)
				| 6BH : InsertChar(0000043BH) (*k*)
				| 6CH : InsertChar(00000434H) (*l*)
				| 3BH : InsertChar(00000436H) (*;*)
				| 27H : InsertChar(0000044DH) (*'*)
				(* third row : zxcvbnm,./;' *)
				| 7AH : InsertChar(0000044FH) (*z*)
				| 78H : InsertChar(00000447H) (*x*)
				| 63H : InsertChar(00000441H) (*c*)
				| 76H : InsertChar(0000043CH) (*v*)
				| 62H : InsertChar(00000438H) (*b*)
				| 6EH : InsertChar(00000442H) (*n*)
				| 6DH : InsertChar(0000044CH) (*m*)
				| 2CH : InsertChar(00000431H) (*,*)
				| 2EH : InsertChar(0000044EH) (*.*)
				| 2FH : InsertChar(0000002EH) (*/*)
			(* shifted *)
				| 7EH : InsertChar(00000401H) (*~*)
				| 40H : InsertChar(00000022H) (**@*)
				| 23H : InsertChar(00002116H) (**#*)
				| 24H : InsertChar(0000003BH) (*$*)
				| 5EH : InsertChar(0000003AH) (*^*)
				| 26H : InsertChar(0000003FH) (*&*)
				(* first row: QWERTYUIOP{} *)
				| 51H : InsertChar(00000419H) (*Q*)
				| 57H : InsertChar(00000426H) (*W*)
				| 45H : InsertChar(00000423H) (*E*)
				| 52H : InsertChar(0000041AH) (*R*)
				| 54H : InsertChar(00000415H) (*T*)
				| 59H : InsertChar(0000041DH) (*Y*)
				| 55H : InsertChar(00000413H) (*U*)
				| 49H : InsertChar(00000428H) (*I*)
				| 4FH : InsertChar(00000429H) (*O*)
				| 50H : InsertChar(00000417H) (*P*)
				| 7BH : InsertChar(00000425H) (*{*)
				| 7DH : InsertChar(0000042AH) (*}*)
				(* second row : ASDFGHJKL:"| *)
				| 41H : InsertChar(00000424H) (*A*)
				| 53H : InsertChar(0000042BH) (*S*)
				| 44H : InsertChar(00000412H) (*D*)
				| 46H : InsertChar(00000410H) (*F*)
				| 47H : InsertChar(0000041FH) (*G*)
				| 48H : InsertChar(00000420H) (*H*)
				| 4AH : InsertChar(0000041EH) (*J*)
				| 4BH : InsertChar(0000041BH) (*K*)
				| 4CH : InsertChar(00000414H) (*L*)
				| 3AH : InsertChar(00000416H) (*:*)
				| 22H : InsertChar(0000042DH) (*"*)
				| 7CH : InsertChar(0000002FH) (*|*)
				(* third row : ZXCVBNM<>? *)
				| 5AH : InsertChar(0000042FH) (*Z*)
				| 58H : InsertChar(00000427H) (*X*)
				| 43H : InsertChar(00000421H) (*C*)
				| 56H : InsertChar(0000041CH) (*V*)
				| 42H : InsertChar(00000418H) (*B*)
				| 4EH : InsertChar(00000422H) (*N*)
				| 4DH : InsertChar(0000042CH) (*M*)
				| 3CH : InsertChar(00000411H) (*<*)
				| 3EH : InsertChar(0000042EH) (*>*)
				| 3FH : InsertChar(0000002CH) (*?*)
			ELSE
				InsertChar(ucs)
			END
		END KeyEvent;

	END IME;

(* installs the Russian IME *)
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

END WMRussianIME.Install~
System.Free WMRussianIME~

WMRussianIME.SelectedCharToUCS ~

WMKeyCode.Open ~
