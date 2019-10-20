MODULE Clipboard; (** AUTHOR "ALEX"; PURPOSE "Windows clipboard interface"; *)

IMPORT SYSTEM, Kernel32, User32, KernelLog, Modules, Texts, TextUtilities, HostClipboard;

CONST CR = 0x0D; LF = 0x0A;

TYPE
	StringBuilder = OBJECT
	VAR
		length: SIZE;
		data: POINTER TO ARRAY OF UNSIGNED16;

		PROCEDURE &Init*( initialSize: SIZE );
		BEGIN
			IF initialSize < 260 THEN initialSize := 260 END;
			NEW( data, initialSize );
			length := 0;
		END Init;

		PROCEDURE Clear*;
		BEGIN
			data[ 0 ] := 0;
			length := 0
		END Clear;

		PROCEDURE AddChar*( codePoint: UNSIGNED16 );
		VAR i, newLength: SIZE; newData: POINTER TO ARRAY OF UNSIGNED16;
		BEGIN
			IF length + 2 >= LEN( data ) THEN
				newLength := length + MAX( 16, length DIV 10 );
				NEW( newData, newLength );
				FOR i := 0 TO length - 1 DO newData[ i ] := data[ i ]; END;
				data := newData;
			END;
			data[ length ] := codePoint;
			INC( length );
			data[ length ] := 0;
		END AddChar;

		PROCEDURE GetLength*( ) : SIZE;
		BEGIN
			RETURN length
		END GetLength;

		PROCEDURE GetString*( ): POINTER TO ARRAY OF UNSIGNED16;
		BEGIN
			RETURN data
		END GetString;

	END StringBuilder;

(** Copy text of Windows clipboard to text *)
PROCEDURE GetFromClipboard( text : Texts.Text );
VAR
	clipboardData: POINTER { UNSAFE, UNTRACED } TO ARRAY OF UNSIGNED16;
	textBuffer: POINTER TO ARRAY OF Texts.Char32;
	clipboardPos := 0, textPos := 0, clipboardLen := 0: SIZE;
	codePoint: UNSIGNED16;
BEGIN
	ASSERT((text # NIL) & (text.HasWriteLock()));
	IF User32.OpenClipboard(Kernel32.NULL) # Kernel32.False THEN
		clipboardData := User32.GetClipboardData(User32.CFUnicodeText);
		IF clipboardData # Kernel32.NULL THEN
		(* copy clipboard data into internal buffer and unlock clipboard data *)
			clipboardData := Kernel32.GlobalLock( clipboardData );
			WHILE clipboardData[ clipboardLen ] # 0 DO INC( clipboardLen ); END;
			NEW( textBuffer, clipboardLen + 1 );

			WHILE clipboardPos < clipboardLen DO
				codePoint := clipboardData[ clipboardPos ]; INC( clipboardPos );
			(* CRLF -> LF *)
				IF ( codePoint = CR ) THEN
					codePoint := LF;
					IF ( clipboardPos < clipboardLen ) & ( clipboardData[ clipboardPos ] = LF ) THEN
						INC( clipboardPos );
					END;
				END;
			(* accept codepoint *)
				textBuffer[ textPos ] := codePoint; INC( textPos );
			END;
			IGNORE Kernel32.GlobalUnlock( clipboardData );
		END;
	END;
	IGNORE User32.CloseClipboard( );

	IF textPos # 0 THEN
		textBuffer[ textPos ] := 0;
		text.Delete( 0, text.GetLength( ));
		text.InsertUCS32( text.GetLength( ), textBuffer^ );
	END;
END GetFromClipboard;

(** Copy text to Windows clipboard *)
PROCEDURE PutToClipboard(text : Texts.Text);
VAR
	clipboardData: POINTER { UNSAFE, UNTRACED } TO ARRAY OF UNSIGNED16;
	textBuffer: POINTER TO ARRAY OF UNSIGNED16;
	builder: StringBuilder;
	r: Texts.TextReader;
	textPos := 0, textLen: SIZE;
	codePoint := 0: Texts.Char32;

BEGIN
	ASSERT(( text # NIL ) & ( text.HasReadLock( )));
	textLen := text.GetLength( );
	IF textLen > 0 THEN
		NEW( builder, textLen );
		NEW( r, text );
		WHILE ( textPos < textLen ) DO
			r.ReadCh( codePoint );
			IF ( codePoint > 0 ) THEN
				IF codePoint = LF THEN (* CRLF *)
					builder.AddChar( CR );
				END;
				builder.AddChar( codePoint( UNSIGNED16 ));
			END;
			INC( textPos );
		END;

		textBuffer := builder.GetString( );
		textLen := builder.GetLength( );

		IF User32.OpenClipboard( Kernel32.NULL ) # Kernel32.False THEN
			IGNORE User32.EmptyClipboard( );
			clipboardData := Kernel32.GlobalAlloc( { Kernel32.GMemMoveable, Kernel32.GMemDDEShare }, 2 *( textLen + 1 ));
			clipboardData := Kernel32.GlobalLock( clipboardData );

			textPos := 0;
			WHILE textPos < textLen DO
				clipboardData[ textPos ] := textBuffer[ textPos ];
				INC( textPos );
			END;
			clipboardData[ textPos ] := 0;
			IGNORE Kernel32.GlobalUnlock( clipboardData );
			clipboardData := User32.SetClipboardData(User32.CFUnicodeText, clipboardData );
		END;
		IGNORE User32.CloseClipboard( );
	END;
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
