MODULE Clipboard; (** AUTHOR "ALEX"; PURPOSE "Windows clipboard interface"; *)

IMPORT SYSTEM, Kernel32, User32, KernelLog, Modules, Texts, TextUtilities, HostClipboard;

CONST
	CR = 0DX; LF = 0AX;

(** Copy text of Windows clipboard to text *)
PROCEDURE GetFromClipboard(text : Texts.Text);
CONST CR = 0x0D; LF = 0x0A;
VAR
	clipboardData: POINTER{ UNSAFE, UNTRACED } TO ARRAY OF UNSIGNED16;
	clipboardPos := 0, linePos := 0, clipboardLen := 0: SIZE;
	ch : UNSIGNED16;
	lineBuffer: POINTER TO ARRAY OF Texts.Char32;
BEGIN
	ASSERT((text # NIL) & (text.HasWriteLock()));
	IF User32.OpenClipboard(Kernel32.NULL) # Kernel32.False THEN
		clipboardData := User32.GetClipboardData(User32.CFUnicodeText);
		IF clipboardData # Kernel32.NULL THEN
		(* copy clipboard data into internal buffer and unlock clipboard data *)
			clipboardData := Kernel32.GlobalLock( clipboardData );
			WHILE clipboardData[ clipboardLen ] # 0 DO INC( clipboardLen ); END;
			NEW( lineBuffer, clipboardLen + 1 );
			WHILE clipboardPos < clipboardLen DO
				ch := clipboardData[ clipboardPos ]; INC( clipboardPos );
			(* CRLF -> LF *)
				IF ( ch = CR ) THEN
					ch := LF;
					IF ( clipboardPos <= clipboardLen ) & ( clipboardData[ clipboardPos ] = LF ) THEN
						INC( clipboardPos );
					END;
				END;
			(* accept codepoint *)
				lineBuffer[ linePos ] := ch; INC( linePos );
			END;
			IGNORE Kernel32.GlobalUnlock( clipboardData );

			IF linePos # 0 THEN
				lineBuffer[ linePos ] := 0;
				text.Delete( 0, text.GetLength( ));
				text.InsertUCS32( text.GetLength( ), lineBuffer^ );
			END;
		END;
	END;
FINALLY
	IGNORE User32.CloseClipboard( );
END GetFromClipboard;

(** Copy text to Windows clipboard *)
PROCEDURE PutToClipboard(text : Texts.Text);
VAR
	hMem: Kernel32.HGLOBAL; adr: ADDRESS;
	chBuff: POINTER TO ARRAY OF CHAR;
	size,requiredSize: SIZE;
	ind: SIZE;
BEGIN
	ASSERT((text # NIL) & (text.HasReadLock()));
	IF User32.OpenClipboard(Kernel32.NULL) # Kernel32.False THEN
		IGNORE User32.EmptyClipboard ();
		size := text.GetLength();
		NEW(chBuff, size + 1);
		(* UTF-8 encoding. String is truncated in case of multi-byte encoded characters! *)
		TextUtilities.TextToStr(text, chBuff^);
		ind := 0; requiredSize := size + 1;
		WHILE ind < size  DO
			IF chBuff^[ind] = LF THEN INC(requiredSize); END; (* transform LF into CRLF *)
			INC(ind);
		END;
		hMem := Kernel32.GlobalAlloc({Kernel32.GMemMoveable, Kernel32.GMemDDEShare}, requiredSize);
		adr := Kernel32.GlobalLock(hMem);
		ind := 0;
		WHILE ind < size  DO
			IF chBuff^[ind] = LF THEN (* transform LF into CRLF *)
				SYSTEM.PUT8(adr, CR); INC(adr);
			END;
			SYSTEM.PUT(adr, chBuff^[ind]); INC(adr); INC(ind);
		END;
		SYSTEM.PUT(adr, 0X);
		IGNORE Kernel32.GlobalUnlock(hMem);
		hMem := User32.SetClipboardData(User32.CFText, hMem);
	END;
	IGNORE User32.CloseClipboard();
END PutToClipboard;

PROCEDURE ClipboardChanged(sender, data : ANY);
BEGIN
	Texts.clipboard.AcquireRead;
	PutToClipboard(Texts.clipboard);
	Texts.clipboard.ReleaseRead;
END ClipboardChanged;

PROCEDURE Install*;
BEGIN
	KernelLog.Enter; KernelLog.String("WindowsClipboard: Registered clipboard at host clipboard interface."); KernelLog.Exit;
END Install;

PROCEDURE Cleanup;
BEGIN
	Texts.clipboard.onTextChanged.Remove(ClipboardChanged);
	HostClipboard.SetHandlers(NIL, NIL);
	KernelLog.Enter; KernelLog.String("WindowsClipboard: Unregistered clipboard at host clipboard interface."); KernelLog.Exit;
END Cleanup;

BEGIN
	(* register with AosText clipboard *)
	Texts.clipboard.onTextChanged.Add(ClipboardChanged);
	HostClipboard.SetHandlers(GetFromClipboard, PutToClipboard);
	Modules.InstallTermHandler(Cleanup)
END Clipboard.

Clipboard.Install ~

System.Free Clipboard ~
