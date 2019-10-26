MODULE Clipboard; (** AUTHOR "ALEX"; PURPOSE "Windows clipboard interface"; *)

IMPORT SYSTEM, Kernel32, User32, KernelLog, Modules, Texts, HostClipboard;

CONST CR = 0x0D; LF = 0x0A;
CONST UTF16SurrogateOffset = LSH( UNSIGNED32( 0xD800 ), 10 ) + 0xDC00 - 0x10000;
CONST ReplacementChar = UNSIGNED16( 0xFFFD );

TYPE
	StringBuilder = OBJECT
	VAR
		length: SIZE;
		data: POINTER TO ARRAY OF UNSIGNED16;

		PROCEDURE &Init*( initialSize: SIZE );
		BEGIN
			IF initialSize < 260 THEN initialSize := 260 END;
			NEW( data, initialSize );
			data[ 0 ] := 0;
			length := 0;
		END Init;

		PROCEDURE Clear*;
		BEGIN
			data[ 0 ] := 0;
			length := 0;
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
PROCEDURE GetFromClipboard( text: Texts.Text );
VAR
	clipboardData: POINTER { UNSAFE, UNTRACED } TO ARRAY MAX(SIZE) OF UNSIGNED16;
	textBuffer: POINTER TO ARRAY OF Texts.Char32;
	clipboardPos := 0, textPos := 0, clipboardLen := 0: SIZE;
	codePoint, lead, trail: UNSIGNED32;
BEGIN
	ASSERT(( text # NIL ) & ( text.HasWriteLock( )));
	IF User32.OpenClipboard(Kernel32.NULL) # Kernel32.False THEN
		clipboardData := User32.GetClipboardData( User32.CFUnicodeText );
		IF clipboardData # Kernel32.NULL THEN
		(* copy clipboard data into internal buffer and unlock clipboard data *)
			clipboardData := Kernel32.GlobalLock( clipboardData );
			WHILE clipboardData[ clipboardLen ] # 0 DO INC( clipboardLen ); END;
			NEW( textBuffer, clipboardLen + 1 );

			WHILE clipboardPos < clipboardLen DO
				codePoint := ReplacementChar;
				lead := clipboardData[ clipboardPos ];

			(* make unicode *)
				IF IsSingle( lead ) THEN
					codePoint := lead;
					INC( clipboardPos );
				ELSE
					IF IsSurrogateLead( lead ) THEN
						INC( clipboardPos );
						IF ( clipboardPos < clipboardLen ) THEN
							trail := clipboardData[ clipboardPos ];
							IF IsTrail( trail ) THEN
								codePoint := LSH( lead, 10 ) + trail - UTF16SurrogateOffset;
								INC( clipboardPos );
							END;
						END;
					ELSIF clipboardPos > 0 THEN
						trail := clipboardData[ clipboardPos - 1 ];
						IF IsLead( trail ) THEN
							codePoint := LSH( trail, 10 ) + lead - UTF16SurrogateOffset;
						END;
						INC( clipboardPos );
					END;
				END;

			(* CRLF -> LF *)
				IF ( codePoint = CR ) THEN
					codePoint := LF;
					IF ( clipboardPos < clipboardLen ) & ( clipboardData[ clipboardPos ] = LF ) THEN
						INC( clipboardPos );
					END;
				END;

			(* accept codePoint *)
				textBuffer[ textPos ] := Texts.Char32( codePoint );
				INC( textPos );
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
PROCEDURE PutToClipboard( text: Texts.Text );
VAR
	clipboardData: POINTER { UNSAFE, UNTRACED } TO ARRAY MAX(SIZE) OF UNSIGNED16;
	textBuffer: POINTER TO ARRAY OF UNSIGNED16;
	builder: StringBuilder;
	r: Texts.TextReader;
	textPos := 0, textLen: SIZE;
	codePoint := 0: Texts.Char32;
BEGIN
	ASSERT(( text # NIL ) & ( text.HasReadLock( )));
	textLen := text.GetLength( );
	IF textLen > 0 THEN
		NEW( builder, textLen + ( textLen DIV 8 + 1 ));
		NEW( r, text );
		WHILE ( textPos < textLen ) DO
			r.ReadCh( codePoint );
			IF ( codePoint > 0 ) THEN
				IF codePoint = LF THEN (* LF -> CRLF *)
					builder.AddChar( CR );
				END;

				IF codePoint <= 0xFFFF THEN
					builder.AddChar( UNSIGNED16( codePoint ));
				ELSIF codePoint <= 0x10FFFF THEN
					builder.AddChar( UTF16Lead( codePoint ));
					builder.AddChar( UTF16Trail( codePoint ));
				ELSE
					builder.AddChar( ReplacementChar );
				END;
			END;
			INC( textPos );
		END;

		textBuffer := builder.GetString( );
		textLen := builder.GetLength( ) + 1; (* include NULL *)

		IF User32.OpenClipboard( Kernel32.NULL ) # Kernel32.False THEN
			IGNORE User32.EmptyClipboard( );
			clipboardData := Kernel32.GlobalAlloc( { Kernel32.GMemMoveable, Kernel32.GMemDDEShare }, (textLen + 1 )*2 );
			clipboardData := Kernel32.GlobalLock( clipboardData );

			SYSTEM.MOVE( ADDRESSOF( textBuffer[ 0 ] ), clipboardData, ( textLen )*2 ); (* include NULL *)
			clipboardData[ textLen ] := 0; (* NULLNULL *)

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

PROCEDURE - IsSingle( c: UNSIGNED32 ): BOOLEAN;
BEGIN
	RETURN SET32( c ) * SET32( 0xFFFFF800 ) # SET32( 0xD800 );
END IsSingle;

PROCEDURE - IsSurrogateLead( c: UNSIGNED32 ): BOOLEAN;
BEGIN
	RETURN SET32( c ) * SET32( 0x400 ) = { };
END IsSurrogateLead;

PROCEDURE - IsLead( c: UNSIGNED32 ): BOOLEAN; (* D800–DBFF *)
BEGIN
	RETURN SET32( c ) * SET32( 0xFFFFFC00 ) = SET32( 0xD800 );
END IsLead;

PROCEDURE - IsTrail( c: UNSIGNED32 ): BOOLEAN; (* DC00–DFFF *)
BEGIN
	RETURN SET32( c ) * SET32( 0xFFFFFC00 ) = SET32( 0xDC00 );
END IsTrail;

PROCEDURE - UTF16Lead( supplementary: UNSIGNED32 ): UNSIGNED16;
BEGIN
	RETURN UNSIGNED16( LSH( supplementary, -10 ) + 0xD7C0 );
END UTF16Lead;

PROCEDURE - UTF16Trail( supplementary: UNSIGNED32 ): UNSIGNED16;
BEGIN
	RETURN UNSIGNED16( SET32( supplementary ) * SET32( 0x3FF ) + SET32( 0xDC00 ));
END UTF16Trail;

BEGIN
	(* register with AosText clipboard *)
	Texts.clipboard.onTextChanged.Add( ClipboardChanged );
	HostClipboard.SetHandlers( GetFromClipboard, PutToClipboard );
	Modules.InstallTermHandler( Cleanup );
END Clipboard.

Clipboard.Install ~

System.Free Clipboard ~