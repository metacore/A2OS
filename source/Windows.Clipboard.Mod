MODULE Clipboard; (** AUTHOR "ALEX"; PURPOSE "Windows clipboard interface"; *)

IMPORT SYSTEM, Kernel32, User32, KernelLog, Modules, Texts, HostClipboard;

CONST
	CR = 0x0D; LF = 0x0A;
	SurrogateOffset = LSH( UNSIGNED32( 0xD800 ), 10 ) + 0xDC00 - 0x10000;
	ReplacementChar = UNSIGNED16( 0xFFFD );
	PortionSize = 1024;

TYPE
	TextPortion = ARRAY PortionSize + 1 OF Texts.Char32;

	UTF16Builder = RECORD { FINAL }
		length: SIZE;
		data: POINTER TO ARRAY OF UNSIGNED16;

		PROCEDURE New( len: SIZE );
		BEGIN
			IF len < 260 THEN len := 260 END;
			NEW( data, len );
			data[ 0 ] := 0;
			length := 0;
		END New;

		PROCEDURE Add( codePoint: UNSIGNED16 );
		VAR i, newLength: SIZE; newData: POINTER TO ARRAY OF UNSIGNED16;
		BEGIN
			IF length >= LEN( data ) THEN
				newLength := length + MAX( 16, length DIV 8 );
				NEW( newData, newLength );
				SYSTEM.MOVE( ADDRESSOF( data[ 0 ] ), ADDRESSOF( newData[ i ] ), length * SIZEOF( UNSIGNED16 ) );
				data := newData;
			END;
			data[ length ] := codePoint;
			INC( length );
		END Add;

	END;

(** Copy text of Windows clipboard to text *)
PROCEDURE GetFromClipboard( text: Texts.Text );
VAR
	clipboard: POINTER { UNSAFE, UNTRACED } TO ARRAY MAX(SIZE) OF UNSIGNED16;
	clipboardPos := 0, portionPos := 0: SIZE;
	codePoint, lead, trail: UNSIGNED32;
	portion: TextPortion;
BEGIN
	ASSERT(( text # NIL ) & ( text.HasWriteLock( )));
	IF User32.OpenClipboard(Kernel32.NULL) # Kernel32.False THEN
		clipboard := User32.GetClipboardData( User32.CFUnicodeText );
	
		IF clipboard # Kernel32.NULL THEN
			text.Delete( 0, text.GetLength( ));
		
		(* copy clipboard data into internal portion and unlock clipboard data *)
			clipboard := Kernel32.GlobalLock( clipboard );

			WHILE clipboard[ clipboardPos ] # 0 DO
				codePoint := ReplacementChar;
				lead := clipboard[ clipboardPos ];

			(* make unicode *)
				IF IsSingle( lead ) THEN
					INC( clipboardPos );
					IF ( lead = CR ) THEN (* CRLF -> LF *)
						lead := LF;
						IF ( clipboard[ clipboardPos ] = LF ) THEN
							INC( clipboardPos );
						END;
					END;
					codePoint := lead;
				ELSIF IsSurrogateLead( lead ) THEN
					INC( clipboardPos );
					IF ( clipboard[ clipboardPos ] # 0 ) THEN
						trail := clipboard[ clipboardPos ];
						IF IsTrail( trail ) THEN
							codePoint := LSH( lead, 10 ) + trail - SurrogateOffset;
							INC( clipboardPos );
						END;
					END;
				ELSIF clipboardPos > 0 THEN
					trail := clipboard[ clipboardPos - 1 ];
					IF IsLead( trail ) THEN
						codePoint := LSH( trail, 10 ) + lead - SurrogateOffset;
					END;
					INC( clipboardPos );
				END;

			(* accept codePoint *)
				portion[ portionPos ] := Texts.Char32( codePoint );
				INC( portionPos );

			(* sink *)
				IF ( portionPos = PortionSize ) THEN
					portion[ portionPos ] := 0;
					text.InsertUCS32( text.GetLength( ), portion );
					portionPos := 0;
				END;
			END;

			IGNORE Kernel32.GlobalUnlock( clipboard );

			IF ( portionPos # 0 ) THEN
				portion[ portionPos ] := 0;
				text.InsertUCS32( text.GetLength( ), portion );
			END;

		END;
	END;

	IGNORE User32.CloseClipboard( );
END GetFromClipboard;

(** Copy text to Windows clipboard *)
PROCEDURE PutToClipboard( text: Texts.Text );
VAR
	clipboard: POINTER { UNSAFE, UNTRACED } TO ARRAY MAX(SIZE) OF UNSIGNED16;
	builder: UTF16Builder;
	r: Texts.TextReader;
	textLen: SIZE;
	codePoint := 0: Texts.Char32;
BEGIN
	ASSERT(( text # NIL ) & ( text.HasReadLock( )));
	textLen := text.GetLength( );
	IF textLen > 0 THEN
		builder.New( textLen + ( textLen DIV 8 + 2 ));
		NEW( r, text );
		WHILE textLen > 0 DO
			r.ReadCh( codePoint );
			IF codePoint <= 0xFFFF THEN
				IF codePoint = LF THEN (* LF -> CRLF *)
					builder.Add( CR );
				END;
				builder.Add( UNSIGNED16( codePoint ));
			ELSIF codePoint <= 0x10FFFF THEN
				builder.Add( UTF16Lead( codePoint ));
				builder.Add( UTF16Trail( codePoint ));
			ELSE
				builder.Add( ReplacementChar );
			END;
			DEC( textLen );
		END;

		builder.Add( 0 ); builder.Add( 0 ); (* NULLNULL *)

		IF User32.OpenClipboard( Kernel32.NULL ) # Kernel32.False THEN
			IGNORE User32.EmptyClipboard( );
			clipboard := Kernel32.GlobalAlloc( { Kernel32.GMemMoveable, Kernel32.GMemDDEShare }, builder.length * 2 );
			clipboard := Kernel32.GlobalLock( clipboard );

			SYSTEM.MOVE( ADDRESSOF( builder.data[ 0 ] ), clipboard, builder.length * 2 );

			IGNORE Kernel32.GlobalUnlock( clipboard );
			clipboard := User32.SetClipboardData(User32.CFUnicodeText, clipboard );
		END;
		IGNORE User32.CloseClipboard( );
	END;
END PutToClipboard;

PROCEDURE ClipboardChanged( sender, data : ANY );
BEGIN
	Texts.clipboard.AcquireRead;
	PutToClipboard( Texts.clipboard );
	Texts.clipboard.ReleaseRead;
END ClipboardChanged;

PROCEDURE Install*;
BEGIN
	KernelLog.Enter; KernelLog.String( "WindowsClipboard: Registered clipboard at host clipboard interface." ); KernelLog.Exit;
END Install;

PROCEDURE Cleanup;
BEGIN
	Texts.clipboard.onTextChanged.Remove( ClipboardChanged );
	HostClipboard.SetHandlers( NIL, NIL );
	KernelLog.Enter; KernelLog.String( "WindowsClipboard: Unregistered clipboard at host clipboard interface." ); KernelLog.Exit;
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

PROCEDURE - UTF16Lead( c: UNSIGNED32 ): UNSIGNED16;
BEGIN
	RETURN UNSIGNED16( LSH( c, -10 ) + 0xD7C0 );
END UTF16Lead;

PROCEDURE - UTF16Trail( c: UNSIGNED32 ): UNSIGNED16;
BEGIN
	RETURN UNSIGNED16( SET32( c ) * SET32( 0x3FF ) + SET32( 0xDC00 ));
END UTF16Trail;

BEGIN
	(* register with AosText clipboard *)
	Texts.clipboard.onTextChanged.Add( ClipboardChanged );
	HostClipboard.SetHandlers( GetFromClipboard, PutToClipboard );
	Modules.InstallTermHandler( Cleanup );
END Clipboard.

Clipboard.Install ~

System.Free Clipboard ~