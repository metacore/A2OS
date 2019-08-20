MODULE WMArabicIME; (** AUTHOR "gubsermi"; PURPOSE "Write arabic characters"; *)

IMPORT
	Strings, WMInputMethods, Texts, KernelLog;

CONST
	imeName* = "Arabic";

TYPE
	IME* = OBJECT(WMInputMethods.IME)

		PROCEDURE GetName*() : Strings.String;
		BEGIN
			RETURN Strings.NewString(imeName);
		END GetName;

		(* Map characters from US-Keyboard to arabic keyboard *)
		PROCEDURE KeyEvent*(ucs : SIZE; flags : SET; keysym : SIZE);
		VAR multiChar : ARRAY 2 OF LONGINT;
		BEGIN
			CASE ucs OF
			(* unshifted *)
				(* numeric row: `1234567890-= *)
				| 60H : InsertChar(00000630H) (*`*)
				| 31H : InsertChar(00000661H) (*1*)
				| 32H : InsertChar(00000662H) (*2*)
				| 33H : InsertChar(00000663H) (*3*)
				| 34H : InsertChar(00000664H) (*4*)
				| 35H : InsertChar(00000665H) (*5*)
				| 36H : InsertChar(00000666H) (*6*)
				| 37H : InsertChar(00000667H) (*7*)
				| 38H : InsertChar(00000668H) (*8*)
				| 39H : InsertChar(00000669H) (*9*)
				| 30H : InsertChar(00000660H) (*0*)
				(* first row: qwertyuiop[] *)
				| 71H : InsertChar(00000636H) (*q*)
				| 77H : InsertChar(00000635H) (*w*)
				| 65H : InsertChar(0000062BH) (*e*)
				| 72H : InsertChar(00000642H) (*r*)
				| 74H : InsertChar(00000641H) (*t*)
				| 79H : InsertChar(0000063AH) (*y*)
				| 75H : InsertChar(00000639H) (*u*)
				| 69H : InsertChar(00000647H) (*i*)
				| 6FH : InsertChar(0000062EH) (*o*)
				| 70H : InsertChar(0000062DH) (*p*)
				| 5BH : InsertChar(0000062CH) (*[*)
				| 5DH : InsertChar(0000062FH) (*]*)
				(* second row : asdfghjkl;' *)
				| 61H : InsertChar(00000634H) (*a*)
				| 73H : InsertChar(00000633H) (*s*)
				| 64H : InsertChar(0000064AH) (*d*)
				| 66H : InsertChar(00000628H) (*f*)
				| 67H : InsertChar(00000644H) (*g*)
				| 68H : InsertChar(00000627H) (*h*)
				| 6AH : InsertChar(0000062AH) (*j*)
				| 6BH : InsertChar(00000646H) (*k*)
				| 6CH : InsertChar(00000645H) (*l*)
				| 3BH : InsertChar(00000643H) (*;*)
				| 27H : InsertChar(00000637H) (*'*)
				(* third row : zxcvbnm,./;' *)
				| 7AH : InsertChar(00000626H) (*z*)
				| 78H : InsertChar(00000621H) (*x*)
				| 63H : InsertChar(00000624H) (*c*)
				| 76H : InsertChar(00000631H) (*v*)
				| 62H : multiChar[0] := 644H;
						multiChar[1] := 627H;
						InsertMultiChar(multiChar);
				| 6EH : InsertChar(00000649H) (*n*)
				| 6DH : InsertChar(00000629H) (*m*)
				| 2CH : InsertChar(00000648H) (*,*)
				| 2EH : InsertChar(00000632H) (*.*)
				| 2FH : InsertChar(00000638H) (*/*)
			(* shifted *)
				(* numeric row: ~!@#$%^&*()_+ *)
				| 7EH : InsertChar(00000651H) (*~*)
				(* first row: QWERTYUIOP{} *)
				| 51H : InsertChar(0000064EH) (*Q*)
				| 57H : InsertChar(0000064BH) (*W*)
				| 45H : InsertChar(0000064FH) (*E*)
				| 52H : InsertChar(0000064CH) (*R*)
				| 54H : multiChar[0] := 644H;
						multiChar[1] := 625H;
						InsertMultiChar(multiChar);
				| 59H : InsertChar(00000625H) (*Y*)
				| 55H : InsertChar(00000060H) (*U*)
				| 49H : InsertChar(000000F7H) (*I*)
				| 4FH : InsertChar(000000D7H) (*O*)
				| 50H : InsertChar(0000061BH) (*P*)
				| 7BH : InsertChar(0000003CH) (*{*)
				| 7DH : InsertChar(0000003EH) (*}*)
				(* second row : ASDFGHJKL:"| *)
				| 41H : InsertChar(00000650H) (*A*)
				| 53H : InsertChar(0000064DH) (*S*)
				| 44H : InsertChar(0000005BH) (*D*)
				| 46H : InsertChar(0000005DH) (*F*)
				| 47H : multiChar[0] := 644H;
						multiChar[1] := 623H;
						InsertMultiChar(multiChar);
				| 48H : InsertChar(00000623H) (*H*)
				| 4AH : InsertChar(00000640H) (*J*)
				| 4BH : InsertChar(0000060CH) (*K*)
				| 4CH : InsertChar(0000002FH) (*L*)
				(* third row : ZXCVBNM<>? *)
				| 5AH : InsertChar(0000007EH) (*Z*)
				| 58H : InsertChar(00000652H) (*X*)
				| 43H : InsertChar(0000007BH) (*C*)
				| 56H : InsertChar(0000007DH) (*V*)
				| 42H : multiChar[0] := 644H;
						multiChar[1] := 622H;
						InsertMultiChar(multiChar);
				| 4EH : InsertChar(00000622H) (*N*)
				| 4DH : InsertChar(00000027H) (*M*)
				| 3CH : InsertChar(0000002CH) (*<*)
				| 3EH : InsertChar(0000002EH) (*>*)
				| 3FH : InsertChar(0000061FH) (*?*)
			ELSE
				InsertChar(ucs)
			END
		END KeyEvent;

	END IME;

(* installs the Arabic IME *)
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
	ucs : LONGINT;
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



END WMArabicIME.Install~
System.Free WMArabicIME~
WMArabicIME.SelectedCharToUCS ~

WMKeyCode.Open ~

