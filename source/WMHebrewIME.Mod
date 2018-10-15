MODULE WMHebrewIME; (** AUTHOR "gubsermi"; PURPOSE "Write hebrew characters"; *)

IMPORT
	Strings, WMInputMethods, Texts, KernelLog;

CONST
	imeName* = "Hebrew";

TYPE
	IME* = OBJECT(WMInputMethods.IME)

		PROCEDURE GetName*() : Strings.String;
		BEGIN
			RETURN Strings.NewString(imeName);
		END GetName;

		(* Map characters from US-Keyboard to hebrew keyboard *)
		PROCEDURE KeyEvent*(ucs : LONGINT; flags : SET; keysym : LONGINT);
		BEGIN
			CASE ucs OF
			(* unshifted *)
				(* numeric row: `1234567890-= *)
				| 60H : InsertChar(0000003BH) (*`*)
				(* first row: qwertyuiop[] *)
				| 71H : InsertChar(0000002FH) (*q*)
				| 77H : InsertChar(000005F3H) (*w*)
				| 65H : InsertChar(000005E7H) (*e*)
				| 72H : InsertChar(000005E8H) (*r*)
				| 74H : InsertChar(000005D0H) (*t*)
				| 79H : InsertChar(000005D8H) (*y*)
				| 75H : InsertChar(000005D5H) (*u*)
				| 69H : InsertChar(000005DFH) (*i*)
				| 6FH : InsertChar(000005DDH) (*o*)
				| 70H : InsertChar(000005E4H) (*p*)
				(* second row : asdfghjkl;' *)
				| 61H : InsertChar(000005E9H) (*a*)
				| 73H : InsertChar(000005D3H) (*s*)
				| 64H : InsertChar(000005D2H) (*d*)
				| 66H : InsertChar(000005DBH) (*f*)
				| 67H : InsertChar(000005E2H) (*g*)
				| 68H : InsertChar(000005D9H) (*h*)
				| 6AH : InsertChar(000005D7H) (*j*)
				| 6BH : InsertChar(000005DCH) (*k*)
				| 6CH : InsertChar(000005DAH) (*l*)
				| 3BH : InsertChar(000005E3H) (*;*)
				| 27H : InsertChar(0000002CH) (*'*)
				(* third row : zxcvbnm,./;' *)
				| 7AH : InsertChar(000005D6H) (*z*)
				| 78H : InsertChar(000005E1H) (*x*)
				| 63H : InsertChar(000005D1H) (*c*)
				| 76H : InsertChar(000005D4H) (*v*)
				| 62H : InsertChar(000005E0H); (*b*)
				| 6EH : InsertChar(000005DEH) (*n*)
				| 6DH : InsertChar(000005E6H) (*m*)
				| 2CH : InsertChar(000005EAH) (*,*)
				| 2EH : InsertChar(000005E5H) (*.*)
				| 2FH : InsertChar(0000002EH) (*/*)
			(* shifted *)
				| 22H: InsertChar(000005F4H) (*"*)
			ELSE
				InsertChar(ucs)
			END
		END KeyEvent;

	END IME;

(* installs the Hebrew IME *)
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



END WMHebrewIME.Install~
System.Free WMHebrewIME~
WMHebrewIME.SelectedCharToUCS ~

WMKeyCode.Open ~
