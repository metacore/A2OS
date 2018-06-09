MODULE UsbHidUP; (** AUTHOR "ottigerm"; PURPOSE "HID Items usage pages" *)
(**
 * Bluebottle USB HID Items Usage Pages for Generic Desktop Controls, Keyboard/Keypad and Button
 *
 * This module decodes usages for usage pages:
 *	Generic Desktop Controls
 *	Keyboard/Keypad
 *	Led
 *	Button
 *	Consumer
 *
 * References:
 *	USB, HID Usage Tables, 21.01.2005 Version 1.12
 *
 * Overview:
 *	Generic Desktop Controls(01H)	p. HID Usage Tables
 *	Keyboard/Keypad(07H)			p. HID Usage Tables
 *	Led(08H)						p. HID Usage Tables
 *	Button(09H)					p. HID Usage Tables
 *	Consumer(0CH)					p. HID Usage Tables
 *
 * History:
 *
 *	22.01.2007 Version 1.0
 *)

IMPORT KernelLog;

CONST

	(** Usage Pages overtaken from HID Usage Tables*)
	GenericDesktopPage* 	= 01H;
	KeyboardPage*			= 06H;
	KeypadPage*			= 07H; (*Same as KeyboardPage*)
	LedPage*				= 08H;
	ButtonPage* 			= 09H;
	ConsumerPage*			= 0CH;

(* print out the decoded usage for usage page Generic Desktop
 * 	param 	pos, usage of the usage page Generic Desktop
 *)
PROCEDURE PrintGenericDesktop(pos: LONGINT);
BEGIN
	(*Generic Desktop Page (0x01)*)
	CASE pos OF
		|00H: KernelLog.String("Undefined" );
		|01H: KernelLog.String("Pointer" );
		|02H: KernelLog.String("Mouse" );
		|03H: KernelLog.String("Reserved" );
		|04H: KernelLog.String("Joystick" );
		|05H: KernelLog.String("Game Pad" );
		|06H: KernelLog.String("Keyboard" );
		|07H: KernelLog.String("Keypad" );
		|08H: KernelLog.String("Multi-axis Controller" );
		|09H: KernelLog.String("Tablet PC System Controls" );
		(*|0A-2FH: KernelLog.String("Reserved" );*)
		|30H: KernelLog.String("X" );
		|31H: KernelLog.String("Y" );
		|32H: KernelLog.String("Z" );
		|33H: KernelLog.String("Rx" );
		|34H: KernelLog.String("Ry" );
		|35H: KernelLog.String("Rz" );
		|36H: KernelLog.String("Slider" );
		|37H: KernelLog.String("Dial" );
		|38H: KernelLog.String("Wheel" );
		|39H: KernelLog.String("Hat switch" );
		|3AH: KernelLog.String("Counted Buffer" );
		|3BH: KernelLog.String("Byte Count" );
		|3CH: KernelLog.String("Motion Wakeup" );
		|3DH: KernelLog.String("Start" );
		|3EH: KernelLog.String("Select" );
		|3FH: KernelLog.String("Reserved" );
		|40H: KernelLog.String("Vx" );
		|41H: KernelLog.String("Vy" );
		|42H: KernelLog.String("Vz" );
		|43H: KernelLog.String("Vbrx" );
		|44H: KernelLog.String("Vbry" );
		|45H: KernelLog.String("Vbrz" );
		|46H: KernelLog.String("Vno" );
		|47H: KernelLog.String("Feature Notification" );
		|48H: KernelLog.String("Resolution Multiplier DV" );
		(*|49-7FH: KernelLog.String("Reserved" );*)
		|80H: KernelLog.String("System Control" );
		|81H: KernelLog.String("System Power Down" );
		|82H: KernelLog.String("System Sleep" );
		|83H: KernelLog.String("System Wake Up" );
		|84H: KernelLog.String("System Context Menu" );
		|85H: KernelLog.String("System Main Menu" );
		|86H: KernelLog.String("System App Menu" );
		|87H: KernelLog.String("System Menu Help" );
		|88H: KernelLog.String("System Menu Exit" );
		|89H: KernelLog.String("System Menu Select" );
		|8AH: KernelLog.String("System Menu Right" );
		|8BH: KernelLog.String("System Menu Left" );
		|8CH: KernelLog.String("System Menu Up" );
		|8DH: KernelLog.String("System Menu Down" );
		|8EH: KernelLog.String("System Cold Restart" );
		|8FH: KernelLog.String("System Warm Restart" );
		|90H: KernelLog.String("D-pad Up" );
		|91H: KernelLog.String("D-pad Down" );
		|92H: KernelLog.String("D-pad Right" );
		|93H: KernelLog.String("D-pad Left" );
		(*|94-9FH: KernelLog.String("Reserved" );*)
		|0A0H: KernelLog.String("System Dock" );
		|0A1H: KernelLog.String("System Undock" );
		|0A2H: KernelLog.String("System Setup" );
		|0A3H: KernelLog.String("System Break" );
		|0A4H: KernelLog.String("System Debugger Break" );
		|0A5H: KernelLog.String("Application Break" );
		|0A6H: KernelLog.String("Application Debugger Break" );
		|0A7H: KernelLog.String("System Speaker Mute" );
		|0A8H: KernelLog.String("System Hibernate" );
		(*|A9-AFH: KernelLog.String("Reserved" );*)
		|0B0H: KernelLog.String("System Display Invert" );
		|0B1H: KernelLog.String("System Display Internal" );
		|0B2H: KernelLog.String("System Display External" );
		|0B3H: KernelLog.String("System Display Both" );
		|0B4H: KernelLog.String("System Display Dual" );
		|0B5H: KernelLog.String("System Display Toggle Int/Ext" );
		|0B6H: KernelLog.String("System Display Swap Primary/Secondary" );
		|0B7H: KernelLog.String("System Display LCD Autoscale" );
		ELSE KernelLog.String("Reserved");
	END;
END PrintGenericDesktop;

(* Print out the decoded usage for usage page Keyboard
 * 	param 	pos, usage of the usage page Keyboard
 *)
PROCEDURE PrintKeyboardPage(pos: LONGINT);
BEGIN
	(*Keyboard/Keypad Page (0x07)*)
	CASE pos OF
		|00H: KernelLog.String("Reserved (no event indicated)" );
		|01H: KernelLog.String("Keyboard ErrorRollOver" );
		|02H: KernelLog.String("Keyboard POSTFail" );
		|03H: KernelLog.String("Keyboard ErrorUndefined" );
		|04H: KernelLog.String("Keyboard a and A" );
		|05H: KernelLog.String("Keyboard b and B" );
		|06H: KernelLog.String("Keyboard c and C" );
		|07H: KernelLog.String("Keyboard d and D" );
		|08H: KernelLog.String("Keyboard e and E" );
		|09H: KernelLog.String("Keyboard f and F" );
		|0AH: KernelLog.String("Keyboard g and G" );
		|0BH: KernelLog.String("Keyboard h and H" );
		|0CH: KernelLog.String("Keyboard i and I" );
		|0DH: KernelLog.String("Keyboard j and J" );
		|0EH: KernelLog.String("Keyboard k and K" );
		|0FH: KernelLog.String("Keyboard l and L" );
		|10H: KernelLog.String("Keyboard m and M" );
		|11H: KernelLog.String("Keyboard n and N" );
		|12H: KernelLog.String("Keyboard o and O" );
		|13H: KernelLog.String("Keyboard p and P" );
		|14H: KernelLog.String("Keyboard q and Q" );
		|15H: KernelLog.String("Keyboard r and R" );
		|16H: KernelLog.String("Keyboard s and S" );
		|17H: KernelLog.String("Keyboard t and T" );
		|18H: KernelLog.String("Keyboard u and U" );
		|19H: KernelLog.String("Keyboard v and V" );
		|1AH: KernelLog.String("Keyboard w and W" );
		|1BH: KernelLog.String("Keyboard x and X" );
		|1CH: KernelLog.String("Keyboard y and Y" );
		|1DH: KernelLog.String("Keyboard z and Z" );
		|1EH: KernelLog.String("Keyboard 1 and !" );
		|1FH: KernelLog.String("Keyboard 2 and @");
		|20H: KernelLog.String("Keyboard 3 and #");
		|21H: KernelLog.String("Keyboard 4 and $");
		|22H: KernelLog.String("Keyboard 5 and %");
		|23H: KernelLog.String("Keyboard 6 and ^");
		|24H: KernelLog.String("Keyboard 7 and &");
		|25H: KernelLog.String("Keyboard 8 and *");
		|26H: KernelLog.String("Keyboard 9 and (");
		|27H: KernelLog.String("Keyboard 0 and )" );
		|28H: KernelLog.String("Keyboard Return (ENTER)" );
		|29H: KernelLog.String("Keyboard ESCAPE" );
		|2AH: KernelLog.String("Keyboard DELETE (Backspace)" );
		|2BH: KernelLog.String("Keyboard Tab" );
		|2CH: KernelLog.String("Keyboard Spacebar" );
		|2DH: KernelLog.String("Keyboard - and (underscore)" );
		|2EH: KernelLog.String("Keyboard = and +");
		|2FH: KernelLog.String("Keyboard [ and {");
		|30H: KernelLog.String("Keyboard ] and }");
		|31H: KernelLog.String("Keyboard \ and |");
		|32H: KernelLog.String("Keyboard Non-US # and ~");
		|33H: KernelLog.String("Keyboard ; and :" );
		|34H: KernelLog.String("Keyboard ");
		|35H: KernelLog.String("Keyboard Grave Accent and Tilde" );
		|36H: KernelLog.String("Keyboard, and <");
		|37H: KernelLog.String("Keyboard . and >");
		|38H: KernelLog.String("Keyboard / and ?" );
		|39H: KernelLog.String("Keyboard Caps Lock" );
		|3AH: KernelLog.String("Keyboard F1" );
		|3BH: KernelLog.String("Keyboard F2" );
		|3CH: KernelLog.String("Keyboard F3" );
		|3DH: KernelLog.String("Keyboard F4" );
		|3EH: KernelLog.String("Keyboard F5" );
		|3FH: KernelLog.String("Keyboard F6" );
		|40H: KernelLog.String("Keyboard F7" );
		|41H: KernelLog.String("Keyboard F8" );
		|42H: KernelLog.String("Keyboard F9" );
		|43H: KernelLog.String("Keyboard F10" );
		|44H: KernelLog.String("Keyboard F11" );
		|45H: KernelLog.String("Keyboard F12" );
		|46H: KernelLog.String("Keyboard PrintScreen" );
		|47H: KernelLog.String("Keyboard Scroll Lock" );
		|48H: KernelLog.String("Keyboard Pause" );
		|49H: KernelLog.String("Keyboard Insert" );
		|4AH: KernelLog.String("Keyboard Home" );
		|4BH: KernelLog.String("Keyboard PageUp" );
		|4CH: KernelLog.String("Keyboard Delete Forward" );
		|4DH: KernelLog.String("Keyboard End" );
		|4EH: KernelLog.String("Keyboard PageDown" );
		|4FH: KernelLog.String("Keyboard RightArrow" );
		|50H: KernelLog.String("Keyboard LeftArrow" );
		|51H: KernelLog.String("Keyboard DownArrow" );
		|52H: KernelLog.String("Keyboard UpArrow" );
		|53H: KernelLog.String("Keypad Num Lock and Clear" );
		|54H: KernelLog.String("Keypad /");
		|55H: KernelLog.String("Keypad *");
		|56H: KernelLog.String("Keypad -");
		|57H: KernelLog.String("Keypad +");
		|58H: KernelLog.String("Keypad ENTER" );
		|59H: KernelLog.String("Keypad 1 and End" );
		|5AH: KernelLog.String("Keypad 2 and Down Arrow" );
		|5BH: KernelLog.String("Keypad 3 and PageDn" );
		|5CH: KernelLog.String("Keypad 4 and Left Arrow" );
		|5DH: KernelLog.String("Keypad 5" );
		|5EH: KernelLog.String("Keypad 6 and Right Arrow" );
		|5FH: KernelLog.String("Keypad 7 and Home" );
		|60H: KernelLog.String("Keypad 8 and Up Arrow" );
		|61H: KernelLog.String("Keypad 9 and PageU");
		|62H: KernelLog.String("Keypad 0 and Insert" );
		|63H: KernelLog.String("Keypad . and Delete" );
		|64H: KernelLog.String("Keyboard Non-US \ and |");
		|65H: KernelLog.String("Keyboard Application" );
		|66H: KernelLog.String("Keyboard Power" );
		|67H: KernelLog.String("Keypad =");
		|68H: KernelLog.String("Keyboard F13" );
		|69H: KernelLog.String("Keyboard F14" );
		|6AH: KernelLog.String("Keyboard F15" );
		|6BH: KernelLog.String("Keyboard F16" );
		|6CH: KernelLog.String("Keyboard F17" );
		|6DH: KernelLog.String("Keyboard F18" );
		|6EH: KernelLog.String("Keyboard F19" );
		|6FH: KernelLog.String("Keyboard F20" );
		|70H: KernelLog.String("Keyboard F21" );
		|71H: KernelLog.String("Keyboard F22" );
		|72H: KernelLog.String("Keyboard F23" );
		|73H: KernelLog.String("Keyboard F24" );
		|74H: KernelLog.String("Keyboard Execute" );
		|75H: KernelLog.String("Keyboard Help" );
		|76H: KernelLog.String("Keyboard Menu" );
		|77H: KernelLog.String("Keyboard Select" );
		|78H: KernelLog.String("Keyboard Stop" );
		|79H: KernelLog.String("Keyboard Again" );
		|7AH: KernelLog.String("Keyboard Undo" );
		|7BH: KernelLog.String("Keyboard Cut" );
		|7CH: KernelLog.String("Keyboard Copy" );
		|7DH: KernelLog.String("Keyboard Paste" );
		|7EH: KernelLog.String("Keyboard Find" );
		|7FH: KernelLog.String("Keyboard Mute" );
		|80H: KernelLog.String("Keyboard Volume Up" );
		|81H: KernelLog.String("Keyboard Volume Down" );
		|82H: KernelLog.String("Keyboard Locking Caps Lock" );
		|83H: KernelLog.String("Keyboard Locking Num Lock" );
		|84H: KernelLog.String("Keyboard Locking Scroll Lock" );
		|85H: KernelLog.String("Keypad Comma" );
		|86H: KernelLog.String("Keypad Equal Sign" );
		|87H: KernelLog.String("Keyboard International1" );
		|88H: KernelLog.String("Keyboard International2" );
		|89H: KernelLog.String("Keyboard International3" );
		|8AH: KernelLog.String("Keyboard International4" );
		|8BH: KernelLog.String("Keyboard International5" );
		|8CH: KernelLog.String("Keyboard International6" );
		|8DH: KernelLog.String("Keyboard International7" );
		|8EH: KernelLog.String("Keyboard International8" );
		|8FH: KernelLog.String("Keyboard International9" );
		|90H: KernelLog.String("Keyboard LANG1" );
		|91H: KernelLog.String("Keyboard LANG2" );
		|92H: KernelLog.String("Keyboard LANG3" );
		|93H: KernelLog.String("Keyboard LANG4" );
		|94H: KernelLog.String("Keyboard LANG5" );
		|95H: KernelLog.String("Keyboard LANG6" );
		|96H: KernelLog.String("Keyboard LANG7" );
		|97H: KernelLog.String("Keyboard LANG8" );
		|98H: KernelLog.String("Keyboard LANG9" );
		|99H: KernelLog.String("Keyboard Alternate Erase" );
		|9AH: KernelLog.String("Keyboard SysReq/Attention" );
		|9BH: KernelLog.String("Keyboard Cancel" );
		|9CH: KernelLog.String("Keyboard Clear" );
		|9DH: KernelLog.String("Keyboard Prior" );
		|9EH: KernelLog.String("Keyboard Return" );
		|9FH: KernelLog.String("Keyboard Separator" );
		|0A0H: KernelLog.String("Keyboard Out" );
		|0A1H: KernelLog.String("Keyboard Oper" );
		|0A2H: KernelLog.String("Keyboard Clear/Again" );
		|0A3H: KernelLog.String("Keyboard CrSel/Props" );
		|0A4H: KernelLog.String("Keyboard ExSel" );
		(*|0A5-CFH: KernelLog.String("Reserved" );*)
		|0B0H: KernelLog.String("Keypad 00" );
		|0B1H: KernelLog.String("Keypad 000" );
		|0B2H: KernelLog.String("Thousands Separator" );
		|0B3H: KernelLog.String("Decimal Separator" );
		|0B4H: KernelLog.String("Currency Unit" );
		|0B5H: KernelLog.String("Currency Sub-unit" );
		|0B6H: KernelLog.String("Keypad (");
		|0B7H: KernelLog.String("Keypad )" );
		|0B8H: KernelLog.String("Keypad {");
		|0B9H: KernelLog.String("Keypad }");
		|0BAH: KernelLog.String("Keypad Tab" );
		|0BBH: KernelLog.String("Keypad Backspace" );
		|0BCH: KernelLog.String("Keypad A" );
		|0BDH: KernelLog.String("Keypad B" );
		|0BEH: KernelLog.String("Keypad C" );
		|0BFH: KernelLog.String("Keypad D" );
		|0C0H: KernelLog.String("Keypad E" );
		|0C1H: KernelLog.String("Keypad F" );
		|0C2H: KernelLog.String("Keypad XOR" );
		|0C3H: KernelLog.String("Keypad ^");
		|0C4H: KernelLog.String("Keypad %");
		|0C5H: KernelLog.String("Keypad <");
		|0C6H: KernelLog.String("Keypad >");
		|0C7H: KernelLog.String("Keypad &");
		|0C8H: KernelLog.String("Keypad &&");
		|0C9H: KernelLog.String("Keypad |");
		|0CAH: KernelLog.String("Keypad ||");
		|0CBH: KernelLog.String("Keypad :" );
		|0CCH: KernelLog.String("Keypad #");
		|0CDH: KernelLog.String("Keypad Space" );
		|0CEH: KernelLog.String("Keypad @");
		|0CFH: KernelLog.String("Keypad !" );
		|0D0H: KernelLog.String("Keypad Memory Store" );
		|0D1H: KernelLog.String("Keypad Memory Recall" );
		|0D2H: KernelLog.String("Keypad Memory Clear" );
		|0D3H: KernelLog.String("Keypad Memory Add" );
		|0D4H: KernelLog.String("Keypad Memory Subtract" );
		|0D5H: KernelLog.String("Keypad Memory Multiply" );
		|0D6H: KernelLog.String("Keypad Memory Divide" );
		|0D7H: KernelLog.String("Keypad +/-");
		|0D8H: KernelLog.String("Keypad Clear" );
		|0D9H: KernelLog.String("Keypad Clear Entry" );
		|0DAH: KernelLog.String("Keypad Binary" );
		|0DBH: KernelLog.String("Keypad Octal" );
		|0DCH: KernelLog.String("Keypad Decimal" );
		|0DDH: KernelLog.String("Keypad Hexadecimal" );
		(*|0DE-DFH: KernelLog.String("Reserved" );*)
		|0E0H: KernelLog.String("Keyboard LeftControl" );
		|0E1H: KernelLog.String("Keyboard LeftShift" );
		|0E2H: KernelLog.String("Keyboard LeftAlt" );
		|0E3H: KernelLog.String("Keyboard Left GUI" );
		|0E4H: KernelLog.String("Keyboard RightControl" );
		|0E5H: KernelLog.String("Keyboard RightShift" );
		|0E6H: KernelLog.String("Keyboard RightAlt" );
		|0E7H: KernelLog.String("Keyboard Right GUI" );
		ELSE KernelLog.String("Reserved");
	END;
END PrintKeyboardPage;

(* print out the decoded usage for usage page Led
 * 	param 	pos, usage of the usage page Led
 *)
PROCEDURE PrintLedPage(pos: LONGINT);
BEGIN
	(*LEDPage (0x08)*)
	CASE pos OF
		00H:  KernelLog.String("Undefined");
		|01H: KernelLog.String("Num Lock");
		|02H: KernelLog.String(" Caps Lock");
		|03H: KernelLog.String(" Scroll Lock");
		|04H: KernelLog.String(" Compose");
		|05H: KernelLog.String(" Kana");
		|06H: KernelLog.String(" Power");
		|07H: KernelLog.String(" Shift");
		|08H: KernelLog.String(" Do Not Disturb");
		|09H: KernelLog.String(" Mute");
		|0AH: KernelLog.String(" Tone Enable");
		|0BH: KernelLog.String(" High Cut Filter");
		|0CH: KernelLog.String(" Low Cut Filter");
		|0DH: KernelLog.String(" Equalizer Enable");
		|0EH: KernelLog.String(" Sound Field On");
		|0FH: KernelLog.String(" Surround On");
		|10H: KernelLog.String(" Repeat");
		|11H: KernelLog.String(" Stereo");
		|12H: KernelLog.String(" Sampling Rate Detect");
		|13H: KernelLog.String(" Spinning");
		|14H: KernelLog.String(" CAV");
		|15H: KernelLog.String(" CLV");
		|16H: KernelLog.String(" Recording Format Detect");
		|17H: KernelLog.String(" Off-Hook");
		|18H: KernelLog.String(" Ring");
		|19H: KernelLog.String(" Message Waiting");
		|1AH: KernelLog.String(" Data Mode");
		|1BH: KernelLog.String(" Battery Operation");
		|1CH: KernelLog.String(" Battery OK");
		|1DH: KernelLog.String(" Battery Low");
		|1EH: KernelLog.String(" Speaker");
		|1FH: KernelLog.String(" Head Set");
		|20H: KernelLog.String(" Hold");
		|21H: KernelLog.String(" Microphone");
		|22H: KernelLog.String(" Coverage");
		|23H: KernelLog.String(" Night Mode");
		|24H: KernelLog.String(" Send Calls");
		|25H: KernelLog.String(" Call Pickup");
		|26H: KernelLog.String(" Conference");
		|27H: KernelLog.String(" Stand-by");
		|28H: KernelLog.String(" Camera On");
		|29H: KernelLog.String(" Camera Off");
		|2AH: KernelLog.String(" On-Line");
		|2BH: KernelLog.String(" Off-Line");
		|2CH: KernelLog.String(" Busy");
		|2DH: KernelLog.String(" Ready");
		|2EH: KernelLog.String(" Paper-Out");
		|2FH: KernelLog.String(" Paper-Jam");
		|30H: KernelLog.String(" Remote");
		|31H: KernelLog.String(" Forward");
		|32H: KernelLog.String(" Reverse");
		|33H: KernelLog.String(" Stop");
		|34H: KernelLog.String(" Rewind");
		|35H: KernelLog.String(" Fast Forward");
		|36H: KernelLog.String(" Play");
		|37H: KernelLog.String(" Pause");
		|38H: KernelLog.String(" Record");
		|39H: KernelLog.String(" Error");
		|3AH: KernelLog.String(" Usage Selected Indicator");
		|3BH: KernelLog.String(" Usage In Use Indicator");
		|3CH: KernelLog.String(" Usage Multi Mode Indicator");
		|3DH: KernelLog.String(" Indicator On");
		|3EH: KernelLog.String(" Indicator Flash");
		|3FH: KernelLog.String(" Indicator Slow Blink");
		|40H: KernelLog.String(" Indicator Fast Blink");
		|41H: KernelLog.String(" Indicator Off");
		|42H: KernelLog.String(" Flash On Time");
		|43H: KernelLog.String(" Slow Blink On Time");
		|44H: KernelLog.String(" Slow Blink Off Time");
		|45H: KernelLog.String(" Fast Blink On Time");
		|46H: KernelLog.String(" Fast Blink Off Time");
		|47H: KernelLog.String(" Usage Indicator Color");
		|48H: KernelLog.String(" Indicator Red");
		|49H: KernelLog.String(" Indicator Green");
		|4AH: KernelLog.String(" Indicator Amber");
		|4BH: KernelLog.String(" Generic Indicator");
		|4CH: KernelLog.String(" System Suspend");
		|4DH: KernelLog.String(" External Power Connected");
	ELSE
		KernelLog.String("Reserved ");
	END;
END PrintLedPage;

(* print out the decoded usage for usage page Button
 *	param 	pos, usage of the usage page Button
 *)
PROCEDURE PrintButtonPage(pos: LONGINT);
BEGIN
	(*Button Page (0x09)*)
	CASE pos OF
		00H: KernelLog.String("No button pressed" );
		|01H: KernelLog.String("Button 1 (primary/trigger)" );
		|02H: KernelLog.String("Button 2 (secondary)" );
		|03H: KernelLog.String("Button 3 (tertiary)" );
		|04H: KernelLog.String("Button 4");
		(*|FFFFH: KernelLog.String("Button 65535");*)
		ELSE
			KernelLog.String("Button "); KernelLog.Int(pos,0);
	END;
END PrintButtonPage;

(* print out the decoded usage for usage page Consumer
 *	param 	pos, usage of the usage page Consumer
 *)
PROCEDURE PrintConsumerPage(pos: LONGINT);
BEGIN
	(*Consumer Page (0x0C)*)
	CASE pos OF
		00H: KernelLog.String("Unassigned");
		|01H: KernelLog.String("Consumer Control");
		|02H: KernelLog.String("Numeric Key Pad");
		|03H: KernelLog.String("Programmable Buttons");
		|04H: KernelLog.String("Microphone");
		|05H: KernelLog.String("Headphone");
		|06H: KernelLog.String("Graphic Equalizer");
		(*|07-1F Reserved*)
		|20H: KernelLog.String("+10");
		|21H: KernelLog.String("+100");
		|22H: KernelLog.String(" AM/PM");
		(*|23-3F Reserved*)
		|30H: KernelLog.String(" Power");
		|31H: KernelLog.String(" Reset");
		|32H: KernelLog.String(" Sleep");
		|33H: KernelLog.String(" Sleep After");
		|34H: KernelLog.String(" Sleep Mode");
		|35H: KernelLog.String(" Illumination");
		|36H: KernelLog.String(" Function Buttons");
		(*|37-3F Reserved*)
		|40H: KernelLog.String("Menu");
		|41H: KernelLog.String(" Menu Pick");
		|42H: KernelLog.String(" Menu Up");
		|43H: KernelLog.String(" Menu Down");
		|44H: KernelLog.String(" Menu Left");
		|45H: KernelLog.String(" Menu Right");
		|46H: KernelLog.String(" Menu Escape");
		|47H: KernelLog.String(" Menu Value Increase");
		|48H: KernelLog.String(" Menu Value Decrease");
		(*|49-5F Reserved*)
		|60H: KernelLog.String(" Data On Screen");
		|61H: KernelLog.String(" Closed Caption");
		|62H: KernelLog.String(" Closed Caption Select");
		|63H: KernelLog.String(" VCR/TV ");
		|64H: KernelLog.String(" Broadcast Mode");
		|65H: KernelLog.String(" Snapshot");
		|66H: KernelLog.String(" Stil");
		(*|67-7F Reserved*)
		|80H: KernelLog.String(" Selection");
		|81H: KernelLog.String(" Assign Selection");
		|82H: KernelLog.String(" Mode Step");
		|83H: KernelLog.String(" Recall Last");
		|84H: KernelLog.String(" Enter Channel");
		|85H: KernelLog.String(" Order Movie");
		|86H: KernelLog.String(" Channel LC");
		|87H: KernelLog.String(" Media Selection");
		|88H: KernelLog.String(" Media Select Computer ");
		|89H: KernelLog.String(" Media Select TV");
		|8AH: KernelLog.String(" Media Select WWW");
		|8BH: KernelLog.String(" Media Select DVD");
		|8CH: KernelLog.String(" Media Select Telephone");
		|8DH: KernelLog.String(" Media Select Program Guide");
		|8EH: KernelLog.String(" Media Select Video Phone");
		|8FH: KernelLog.String(" Media Select Games");
		|90H: KernelLog.String(" Media Select Messages");
		|91H: KernelLog.String(" Media Select CD");
		|92H: KernelLog.String(" Media Select VCR");
		|93H: KernelLog.String(" Media Select Tuner");
		|94H: KernelLog.String(" Quit");
		|95H: KernelLog.String(" Help");
		|96H: KernelLog.String(" Media Select Tape");
		|97H: KernelLog.String(" Media Select Cable");
		|98H: KernelLog.String(" Media Select Satellite");
		|99H: KernelLog.String(" Media Select Security");
		|9AH: KernelLog.String(" Media Select Home");
		|9BH: KernelLog.String(" Media Select Call");
		|9CH: KernelLog.String(" Channel Increment");
		|9DH: KernelLog.String(" Channel Decrement");
		|9EH: KernelLog.String(" Media Select SAP");
		|9FH: KernelLog.String(" Reserved");
		|0A0H: KernelLog.String(" VCR Plus");
		|0A1H: KernelLog.String(" Once");
		|0A2H: KernelLog.String(" Daily");
		|0A3H: KernelLog.String(" Weekly");
		|0A4H: KernelLog.String(" Monthly");
		(*|0A5-AF Reserved*)
		|0B0H: KernelLog.String(" Play");
		|0B1H: KernelLog.String(" Pause");
		|0B2H: KernelLog.String(" Record");
		|0B3H: KernelLog.String(" Fast Forward");
		|0B4H: KernelLog.String(" Rewind");
		|0B5H: KernelLog.String(" Scan Next Track");
		|0B6H: KernelLog.String(" Scan Previous Track");
		|0B7H: KernelLog.String(" Stop OSC");
		|0B8H: KernelLog.String(" Eject OSC");
		|0B9H: KernelLog.String(" Random Play");
		|0BAH: KernelLog.String(" Select Disc");
		|0BBH: KernelLog.String(" Enter Disc");
		|0BCH: KernelLog.String(" Repeat");
		|0BDH: KernelLog.String(" Tracking");
		|0BEH: KernelLog.String(" Track Normal");
		|0BFH: KernelLog.String(" Slow Tracking");
		|0C0H: KernelLog.String(" Frame Forward");
		|0C1H: KernelLog.String(" Frame Back");
		|0C2H: KernelLog.String(" Mark OSC");
		|0C3H: KernelLog.String(" Clear Mark");
		|0C4H: KernelLog.String(" Repeat From Mark");
		|0C5H: KernelLog.String(" Return To Mark");
		|0C6H: KernelLog.String(" Search Mark Forward");
		|0C7H: KernelLog.String(" Search Mark Backwards");
		|0C8H: KernelLog.String(" Counter Reset");
		|0C9H: KernelLog.String(" Show Counter");
		|0CAH: KernelLog.String(" Tracking Increment");
		|0CBH: KernelLog.String(" Tracking Decrement");
		|0CCH: KernelLog.String(" Stop/Eject");
		|0CDH: KernelLog.String(" Play/Pause");
		|0CEH: KernelLog.String(" Play/Skip");
		(*|0CF-DF Reserved*)
		|0E0H: KernelLog.String(" Volume");
		|0E1H: KernelLog.String(" Balance");
		|0E2H: KernelLog.String(" Mute");
		|0E3H: KernelLog.String(" Bass");
		|0E4H: KernelLog.String(" Treble");
		|0E5H: KernelLog.String(" Bass Boost");
		|0E6H: KernelLog.String(" Surround Mode");
		|0E7H: KernelLog.String(" Loudness");
		|0E8H: KernelLog.String(" MPX");
		|0E9H: KernelLog.String(" Volume Increment");
		|0EAH: KernelLog.String(" Volume Decrement");
		(*|0EB-EF Reserved*)
		|0F0H: KernelLog.String(" Speed Select");
		|0F1H: KernelLog.String(" Playback Speed");
		|0F2H: KernelLog.String(" Standard Play");
		|0F3H: KernelLog.String(" Long Play");
		|0F4H: KernelLog.String(" Extended Play");
		|0F5H: KernelLog.String(" Slow");
		(*|0F6-FF Reserved*)
		|100H: KernelLog.String(" Fan Enable");
		|101H: KernelLog.String(" Fan Speed");
		|102H: KernelLog.String(" Light Enable");
		|103H: KernelLog.String(" Light Illumination Level");
		|104H: KernelLog.String(" Climate Control Enable");
		|105H: KernelLog.String(" Room Temperature");
		|106H: KernelLog.String(" Security Enable");
		|107H: KernelLog.String(" Fire Alarm");
		|108H: KernelLog.String(" Police Alarm");
		|109H: KernelLog.String(" Proximity");
		|10AH: KernelLog.String(" Motion");
		|10BH: KernelLog.String(" Duress Alarm");
		|10CH: KernelLog.String(" Holdup Alarm");
		|10DH: KernelLog.String(" Medical Alarm");
		(*|10E-14F Reserved*)
		|150H: KernelLog.String(" Balance Right");
		|151H: KernelLog.String(" Balance Left");
		|152H: KernelLog.String(" Bass Increment");
		|153H: KernelLog.String(" Bass Decrement");
		|154H: KernelLog.String(" Treble Increment");
		|155H: KernelLog.String(" Treble Decrement");
		(*156-15F Reserved*)
		|160H: KernelLog.String(" Speaker System");
		|161H: KernelLog.String(" Channel Left");
		|162H: KernelLog.String(" Channel Right");
		|163H: KernelLog.String(" Channel Center");
		|164H: KernelLog.String(" Channel Front");
		|165H: KernelLog.String(" Channel Center Front");
		|166H: KernelLog.String(" Channel Side");
		|167H: KernelLog.String(" Channel Surround");
		|168H: KernelLog.String(" Channel Low Frequency");
		(*|16B-16F Reserved*)
		|170H: KernelLog.String(" Sub-channel");
		|171H: KernelLog.String(" Sub-channel Increment");
		|172H: KernelLog.String(" Sub-channel Decrement");
		|173H: KernelLog.String(" Alternate Audio Increment");
		|174H: KernelLog.String(" Alternate Audio Decrement");
		(*|175-17F Reserved*)
		|180H: KernelLog.String(" Application Launch Buttons");
		|181H: KernelLog.String(" AL Launch Button Configuration");
		|182H: KernelLog.String(" AL Programmable Button");
		|183H: KernelLog.String(" AL Consumer Control");
		|184H: KernelLog.String(" AL Word Processor");
		|185H: KernelLog.String(" AL Text Editor");
		|186H: KernelLog.String(" AL Spreadsheet");
		|187H: KernelLog.String(" AL Graphics Editor");
		|188H: KernelLog.String(" AL Presentation App");
		|189H: KernelLog.String(" AL Database App");
		|18AH: KernelLog.String(" AL Email Reader");
		|18BH: KernelLog.String(" AL Newsreader");
		|18CH: KernelLog.String(" AL Voicemail");
		|18DH: KernelLog.String(" AL Contacts/Address Book");
		|18EH: KernelLog.String(" AL Calendar/Schedule");
		|18FH: KernelLog.String(" AL Task/Project Manager");
		|190H: KernelLog.String(" AL Log/Journal/Timecard");
		|191H: KernelLog.String(" AL Checkbook/Finance");
		|192H: KernelLog.String(" AL Calculator");
		|193H: KernelLog.String(" AL A/V Capture/Playback");
		|194H: KernelLog.String(" AL Local Machine Browser");
		|195H: KernelLog.String(" AL LAN/WAN Browser");
		|196H: KernelLog.String(" AL Internet Browser");
		|197H: KernelLog.String(" AL Remote Networking/ISP");
		|198H: KernelLog.String(" AL Network Conference");
		|199H: KernelLog.String(" AL Network Chat");
		|19AH: KernelLog.String(" AL Telephony/Dialer");
		|19BH: KernelLog.String(" AL Logon");
		|19CH: KernelLog.String(" AL Logoff");
		|19DH: KernelLog.String(" AL Logon/Logoff");
		|19EH: KernelLog.String(" AL Terminal Lock/Screensaver");
		|19FH: KernelLog.String(" AL Control Panel");
		|1A0H: KernelLog.String(" AL Command Line Processor/Run");
		|1A1H: KernelLog.String(" AL Process/Task Manager");
		|1A2H: KernelLog.String(" AL Select Task/Application");
		|1A3H: KernelLog.String(" AL Next Task/Application");
		|1A4H: KernelLog.String(" AL Previous Task/Application");
		|1A5H: KernelLog.String(" AL Preemptive Halt");
		|1A6H: KernelLog.String(" AL Integrated Help Center");
		|1A7H: KernelLog.String(" AL Documents");
		|1A8H: KernelLog.String(" AL Thesaurus");
		|1A9H: KernelLog.String(" AL Dictionary");
		|1AAH: KernelLog.String(" AL Desktop");
		|1ABH: KernelLog.String(" AL Spell Check");
		|1ACH: KernelLog.String(" AL Grammar Check");
		|1ADH: KernelLog.String(" AL Wireless Status");
		|1AEH: KernelLog.String(" AL Keyboard Layout");
		|1AFH: KernelLog.String(" AL Virusu Protection");
		|1B0H: KernelLog.String(" AL Encryption");
		|1B1H: KernelLog.String(" AL Screen Saver");
		|1B2H: KernelLog.String(" AL Alarms");
		|1B3H: KernelLog.String(" AL Clock");
		|1B4H: KernelLog.String(" AL File Browser");
		|1B5H: KernelLog.String(" AL Power Status");
		|1B6H: KernelLog.String(" AL Image Browser");
		|1B7H: KernelLog.String(" AL Audio Browser");
		|1B8H: KernelLog.String(" AL Movie Browser");
		|1B9H: KernelLog.String(" AL Digital Rights Manager");
		|1BAH: KernelLog.String(" AL Digital Wallet");
		(*|1BB Reserved*)
		|1BCH: KernelLog.String(" AL Instant Messaging");
		|1BDH: KernelLog.String(" AL OEM Features/ Tips/Tutorial");
		|1BEH: KernelLog.String(" AL OEM Help");
		|1BFH: KernelLog.String(" AL Online Community");
		|1C0H: KernelLog.String(" AL Entertainment Content");
		|1C1H: KernelLog.String(" AL Online Shopping Browser");
		|1C2H: KernelLog.String(" AL SmartCard Information/Help");
		|1C3H: KernelLog.String(" AL Market Monitor/Finance");
		|1C4H: KernelLog.String(" AL Customized Corporate News");
		|1C5H: KernelLog.String(" AL Online Activity Browser");
		|1C6H: KernelLog.String(" AL Research/Search Browser");
		|1C7H: KernelLog.String(" AL Audio Player");
		(*|1C8-1FF Reserved*)
		|200H: KernelLog.String(" Generic GUI Application");
		|201H: KernelLog.String(" AC New");
		|202H: KernelLog.String(" AC Open");
		|203H: KernelLog.String(" AC Close");
		|204H: KernelLog.String(" AC Exit");
		|205H: KernelLog.String(" AC Maximize");
		|206H: KernelLog.String(" AC Minimize");
		|207H: KernelLog.String(" AC Save");
		|208H: KernelLog.String(" AC Print");
		|209H: KernelLog.String(" AC Properties");
		|21AH: KernelLog.String(" AC Undo");
		|21BH: KernelLog.String(" AC Copy");
		|21CH: KernelLog.String(" AC Cut");
		|21DH: KernelLog.String(" AC Paste");
		|21EH: KernelLog.String(" AC Select All");
		|21FH: KernelLog.String(" AC Find");
		|220H: KernelLog.String(" AC Find and Replace");
		|221H: KernelLog.String(" AC Search");
		|222H: KernelLog.String(" AC Go To");
		|223H: KernelLog.String(" AC Home");
		|224H: KernelLog.String(" AC Back");
		|225H: KernelLog.String(" AC Forward");
		|226H: KernelLog.String(" AC Stop");
		|227H: KernelLog.String(" AC Refresh");
		|228H: KernelLog.String(" AC Previous Link");
		|229H: KernelLog.String(" AC Next Link");
		|22AH: KernelLog.String(" AC Bookmarks");
		|22BH: KernelLog.String(" AC History");
		|22CH: KernelLog.String(" AC Subscriptions");
		|22DH: KernelLog.String(" AC Zoom In");
		|22EH: KernelLog.String(" AC Zoom Out");
		|22FH: KernelLog.String(" AC Zoom");
		|230H: KernelLog.String(" AC Full Screen View");
		|231H: KernelLog.String(" AC Normal View");
		|232H: KernelLog.String(" AC View Toggle");
		|233H: KernelLog.String(" AC Scroll Up");
		|234H: KernelLog.String(" AC Scroll Down");
		|235H: KernelLog.String(" AC Scroll");
		|236H: KernelLog.String(" AC Pan Left");
		|237H: KernelLog.String(" AC Pan Right");
		|238H: KernelLog.String(" AC Pan");
		|239H: KernelLog.String(" AC New Window");
		|23AH: KernelLog.String(" AC Tile Horizontally");
		|23BH: KernelLog.String(" AC Tile Vertically");
		|23CH: KernelLog.String(" AC Format");
		|23DH: KernelLog.String(" AC Edit");
		|23EH: KernelLog.String(" AC Bold");
		|23FH: KernelLog.String(" AC Italics");
		|240H: KernelLog.String(" AC Underline");
		|241H: KernelLog.String(" AC Strikethrough");
		|242H: KernelLog.String(" AC Subscript");
		|243H: KernelLog.String(" AC Superscript");
		|244H: KernelLog.String(" AC All Caps");
		|245H: KernelLog.String(" AC Rotate");
		|246H: KernelLog.String(" AC Resize");
		|247H: KernelLog.String(" AC Flip horizontal");
		|248H: KernelLog.String(" AC Flip Vertical");
		|249H: KernelLog.String(" AC Mirror Horizontal");
		|24AH: KernelLog.String(" AC Mirror Vertical");
		|24BH: KernelLog.String(" AC Font Select");
		|24CH: KernelLog.String(" AC Font Color");
		|24DH: KernelLog.String(" AC Font Size");
		|24EH: KernelLog.String(" AC Justify Left");
		|24FH: KernelLog.String(" AC Justify Center H");
		|250H: KernelLog.String(" AC Justify Right");
		|251H: KernelLog.String(" AC Justify Block H");
		|252H: KernelLog.String(" AC Justify Top");
		|253H: KernelLog.String(" AC Justify Center V");
		|254H: KernelLog.String(" AC Justify Bottom");
		|255H: KernelLog.String(" AC Justify Block V");
		|256H: KernelLog.String(" AC Indent Decrease");
		|257H: KernelLog.String(" AC Indent Increase");
		|258H: KernelLog.String(" AC Numbered List");
		|259H: KernelLog.String(" AC Restart Numbering");
		|25AH: KernelLog.String(" AC Bulleted List");
		|25BH: KernelLog.String(" AC Promote");
		|25CH: KernelLog.String(" AC Demote");
		|25DH: KernelLog.String(" AC Yes");
		|25EH: KernelLog.String(" AC No");
		|25FH: KernelLog.String(" AC Cancel");
		|260H: KernelLog.String(" AC Catalog");
		|261H: KernelLog.String(" AC Buy/Checkout");
		|262H: KernelLog.String(" AC Add to Cart");
		|263H: KernelLog.String(" AC Expand");
		|264H: KernelLog.String(" AC Expand All");
		|265H: KernelLog.String(" AC Collapse");
		|266H: KernelLog.String(" AC Collapse All");
		|267H: KernelLog.String(" AC Print Preview");
		|268H: KernelLog.String(" AC Paste Special");
		|269H: KernelLog.String(" AC Insert Mode");
		|26AH: KernelLog.String(" AC Delete");
		|26BH: KernelLog.String(" AC Lock");
		|26CH: KernelLog.String(" AC Unlock");
		|26DH: KernelLog.String(" AC Protect");
		|26EH: KernelLog.String(" AC Unprotect");
		|26FH: KernelLog.String(" AC Attach Comment");
		|270H: KernelLog.String(" AC Delete Comment");
		|271H: KernelLog.String(" AC View Comment");
		|272H: KernelLog.String(" AC Select Word");
		|273H: KernelLog.String(" AC Select Sentence");
		|274H: KernelLog.String(" AC Select Paragraph");
		|275H: KernelLog.String(" AC Select Column");
		|276H: KernelLog.String(" AC Select Row");
		|277H: KernelLog.String(" AC Select Table");
		|278H: KernelLog.String(" AC Select Object");
		|279H: KernelLog.String(" AC Redo/Repeat");
		|27AH: KernelLog.String(" AC Sort");
		|27BH: KernelLog.String(" AC Sort Ascending");
		|27CH: KernelLog.String(" AC Sort Descending");
		|27DH: KernelLog.String(" AC Filter");
		|27EH: KernelLog.String(" AC Set Clock");
		|27FH: KernelLog.String(" AC View Clock");
		|280H: KernelLog.String(" AC Select Time Zone");
		|281H: KernelLog.String(" AC Edit Time Zones");
		|282H: KernelLog.String(" AC Set Alarm");
		|283H: KernelLog.String(" AC Clear Alarm");
		|284H: KernelLog.String(" AC Snooze Alarm");
		|285H: KernelLog.String(" AC Reset Alarm");
		|286H: KernelLog.String(" AC Synchronize");
		|287H: KernelLog.String(" AC Send/Receive");
		|288H: KernelLog.String(" AC Send To");
		|289H: KernelLog.String(" AC Reply");
		|28AH: KernelLog.String(" AC Reply All");
		|28BH: KernelLog.String(" AC Forward Msg");
		|28CH: KernelLog.String(" AC Send");
		|28DH: KernelLog.String(" AC Attach File");
		|28EH: KernelLog.String(" AC Upload");
		|28FH: KernelLog.String(" AC Download (Save Target As)");
		|290H: KernelLog.String(" AC Set Borders");
		|291H: KernelLog.String(" AC Insert Row");
		|292H: KernelLog.String(" AC Insert Column");
		|293H: KernelLog.String(" AC Insert File");
		|294H: KernelLog.String(" AC Insert Picture");
		|295H: KernelLog.String(" AC Insert Object");
		|296H: KernelLog.String(" AC Insert Symbol");
		|297H: KernelLog.String(" AC Save and Close");
		|298H: KernelLog.String(" AC Rename");
		|299H: KernelLog.String(" AC Merge");
		|29AH: KernelLog.String(" AC Split");
		|29BH: KernelLog.String(" AC Disribute Horizontally");
		|29CH: KernelLog.String(" AC Distribute Vertically");
		(*|29D-FFFF Reserved*)
	ELSE
		KernelLog.String("Reserved");
	END;
END PrintConsumerPage;

(*print out the decoded usage for a usage page
 *	param	page,	usage page
 *		 	pos, 	usage of the usage page [page]
 *)
PROCEDURE PrintUsagePage*(page, pos: LONGINT);
BEGIN
	CASE page OF
		|GenericDesktopPage: 	PrintGenericDesktop(pos);
		|KeyboardPage:			PrintKeyboardPage(pos);
		|KeypadPage:			PrintKeyboardPage(pos);
		|LedPage:				PrintLedPage(pos);
		|ButtonPage:			PrintButtonPage(pos);
		|ConsumerPage:			PrintConsumerPage(pos);
	ELSE
		KernelLog.String("NO IMPLEMENTATION FOR USAGE PAGE(");KernelLog.Int(page,0); KernelLog.String(") USAGE(");KernelLog.Int(pos,1); KernelLog.String(")");
	END;
END PrintUsagePage;

PROCEDURE PrintUsagePageName*(page: LONGINT);
BEGIN
	CASE page OF
		|GenericDesktopPage: 	KernelLog.String("GenericDesktop");
		|KeyboardPage:			KernelLog.String("KeyboardPage");
		|KeypadPage:			KernelLog.String("KeypadPage");
		|LedPage:				KernelLog.String("LedPage");
		|ButtonPage:			KernelLog.String("ButtonPage");
		|ConsumerPage:			KernelLog.String("ConsumerPage");
	ELSE
		KernelLog.String("n/a");
	END;
END PrintUsagePageName;

END UsbHidUP.

System.Free UsbHidUP~