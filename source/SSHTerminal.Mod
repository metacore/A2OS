MODULE SSHTerminal; 	(* GF  10.12.2020 *)

(* derived from WMVT100.Mod by ejz, modified to use an SSH connection instead of telnet *)


IMPORT
	Kernel, Commands, Files, Inputs, Streams, Log := KernelLog, Beep,
	WMWindowManager, WMComponents, WMStandardComponents, WMG := WMGraphics,
	WMMessages, WMEditors, WMRectangles, 
	
	SSHAuthorize, SSHChannels;

CONST
	TerminalWidth = 80;
	TerminalHeight = 24;

	Border = 2; BoxW = 8; BoxH = 18;

	Left = 0; Right = 2;
	Underscore = 0; Blink = 1;
	CursorKeyMode = 0; AppKeypadMode = 1; AutoWrapMode = 2;

	ESC = 1BX; DEL = 07FX; CR = 0DX; NL = 0AX;
	
	DefLogin = "SSH.DefaultLogin"
	
VAR 
	lastHostname, lastUsername: ARRAY 64 OF CHAR;

TYPE
	SSHChannel = SSHChannels.Channel;
	
	WindowCloser = PROCEDURE {DELEGATE};
	
	Attribute = POINTER TO RECORD
		fnt: WMG.Font;
		bg, fg: WMG.Color;
		special: SET (* 0: underscore *)
	END;

	Char = RECORD
		attr: Attribute;
		char: SIGNED32
	END;

	Data = POINTER TO ARRAY OF Char;

	Line = POINTER TO RECORD
		data: Data;
		t, b: SIZE;
		next: Line
	END;

	Position = RECORD
		line: Line; ofs: SIZE
	END;



	Frame = OBJECT (WMComponents.VisualComponent)
		VAR
			rows, cols, boxW, boxH, dX, dY: SIZE;
			chan: SSHChannel;
			w: Streams.Writer;
			mode: SET;
			windowCloser: WindowCloser;

			first, top: Line; bg: WMG.Color;
			scrollTop, scrollBottom: Line;
			scrollBegin, scrollEnd: SIZE;

			tabs: POINTER TO ARRAY OF BOOLEAN;
			attr: Attribute;
			cursor: Position;
			old:	RECORD
						attr: Attribute;
						offs: SIZE;
						row: SIZE
					END;
			sel:	RECORD
						beg, end: Position
					END;



			PROCEDURE GetCol(): SIZE;
			BEGIN {EXCLUSIVE}
				RETURN cursor.ofs
			END GetCol;

			PROCEDURE GetRow(): SIZE;
			VAR l: Line; row: SIZE;
			BEGIN {EXCLUSIVE}
				l := top;  row := 0;
				WHILE l # cursor.line DO
					l := l.next; INC( row )
				END;
				RETURN row
			END GetRow;


			PROCEDURE GetNewLine(): Line;
			VAR line: Line; i: SIZE; ch: Char;
			BEGIN
				NEW( line ); line.next := NIL;
				NEW( line.data, cols );
				ch.attr := attr; ch.char := 0;
				FOR i := 0 TO cols - 1 DO  line.data[i] := ch  END;
				RETURN line
			END GetNewLine;


			PROCEDURE AppendLine( pred: Line ): Line;
			VAR line: Line;
			BEGIN
				line := GetNewLine();
				IF pred # NIL THEN
					line.next := pred.next;
					pred.next := line;
					IF pred.b >= dY THEN  line.t := pred.b  ELSE  line.t := dY  END
				ELSE
					line.t := dY;
				END;
				line.b := line.t + boxH;
				RETURN line
			END AppendLine;



			PROCEDURE UpdateBox(line: Line; ofs: SIZE);
			VAR update: WMG.Rectangle;
			BEGIN
				update.l := dX + ofs*boxW; update.r := update.l + boxW;
				update.t := line.t; update.b := line.b;
				InvalidateRect(update)
			END UpdateBox;

			PROCEDURE UpdateRect(al, bl: Line; aofs, bofs: SIZE; cur: SET);
			VAR tl: Line; tofs: SIZE; update: WMG.Rectangle; swapl, swapo: BOOLEAN;
			BEGIN
				swapl := FALSE; swapo := FALSE;
				IF al # bl THEN
					tl := al;
					WHILE (tl # NIL) & (tl # bl) DO
						tl := tl.next
					END;
					IF tl = NIL THEN swapl := TRUE; tl := al; al := bl; bl := tl END
				END;
				IF aofs > bofs THEN swapo := TRUE; tofs := aofs; aofs := bofs; bofs := tofs END;
				update.l := dX + aofs*boxW; update.r := dX + bofs*boxW + boxW;
				update.t := al.t; update.b := bl.b;
				IF cur # {} THEN
					IF 1 IN cur THEN
						IF swapl THEN cursor.line := bl ELSE cursor.line := al END
					ELSIF 2 IN cur THEN
						IF swapl THEN cursor.line := al ELSE cursor.line := bl END
					END;
					IF 3 IN cur THEN
						IF swapo THEN cursor.ofs := bofs ELSE cursor.ofs := aofs END
					ELSIF 4 IN cur THEN
						IF swapo THEN cursor.ofs := aofs ELSE cursor.ofs := bofs END
					END
				END;
				InvalidateRect(update)
			END UpdateRect;

			PROCEDURE UpdateAll;
			VAR update: WMG.Rectangle;
			BEGIN
				update.l := 0; update.r := bounds.GetWidth();
				update.t := 0; update.b := bounds.GetHeight();
				InvalidateRect(update)
			END UpdateAll;


			PROCEDURE WriteChars( CONST buf: ARRAY OF CHAR; n: SIZE);
			VAR prev, l: Line; i, ofs: SIZE; wrap: BOOLEAN;
			BEGIN {EXCLUSIVE}
				wrap := FALSE;
				l := cursor.line;  ofs := cursor.ofs;  i := 0;
				LOOP
					WHILE (i < n) & (ofs < cols) DO
						l.data[ofs].attr := attr;
						l.data[ofs].char := ORD( buf[i] );
						INC( ofs ); INC( i )
					END;
					IF (i < n) & (AutoWrapMode IN mode) THEN
						prev := l;  l := l.next;  ofs := 0;  wrap := TRUE;
						IF l = NIL THEN
							l := AppendLine( prev )
						END
					ELSE
						EXIT
					END
				END;
				IF wrap THEN
					cursor.ofs := ofs;
					UpdateRect( cursor.line, l, 0, cols-1, {2} )
				ELSE
					UpdateRect( cursor.line, l, cursor.ofs, ofs, {4} )
				END
			END WriteChars;



			PROCEDURE Delete;
			VAR l: Line; ofs: SIZE;
			BEGIN {EXCLUSIVE}
				l := cursor.line;  ofs := cursor.ofs;
				IF ofs > 0 THEN
					DEC( ofs );
					l.data[ofs].attr := attr;
					l.data[ofs].char := 0;
					UpdateRect( l, l, ofs, cursor.ofs, {3} )
				END
			END Delete;


			PROCEDURE GetLine( n: SIZE ): Line;
			VAR line: Line;
			BEGIN
				line := top;
				WHILE (n > 0) & (line # NIL) DO  line := line.next;  DEC( n )  END;
				RETURN line
			END GetLine;

			PROCEDURE GetLastLine( ): Line;
			VAR line: Line;
			BEGIN
				line := top;
				WHILE line.next # NIL DO  line := line.next  END;
				RETURN line
			END GetLastLine;


			PROCEDURE SetScrollRegion;
			BEGIN
				scrollTop := GetLine( scrollBegin );
				scrollBottom := GetLine( scrollEnd );
			END SetScrollRegion;

			PROCEDURE Goto( row, col: SIZE );
			VAR l: Line; hl, lines: SIZE;
			BEGIN {EXCLUSIVE}
				IF col < 0 THEN  col := 0  ELSIF col >= cols THEN  col := cols - 1  END;

				l := first;  hl := 1;
				WHILE l # top DO  INC( hl );  l := l.next  END;
				WHILE hl > 512 DO  first := first.next;  DEC( hl )  END;	(* limit history *)
				lines := 1;

				WHILE row > 0 DO
					IF l.next = NIL THEN
						l := AppendLine( l );
					ELSE
						l := l.next
					END;
					DEC( row );  INC( lines )
				END;

				IF lines > rows THEN
					top := top.next;
					cursor.line := l; cursor.ofs := 0;
					UpdateAll()
				ELSE
					UpdateRect( cursor.line, l, cursor.ofs, col, {2, 4} )
				END;
				SetScrollRegion;
				SetOffsets;
			END Goto;


			PROCEDURE SetOffsets;
			VAR l: Line; y: SIZE;
			BEGIN
				l := top; y := dY;
				REPEAT
					l.t := y;  INC( y, BoxH );  l.b := y;
					l := l.next
				UNTIL l = NIL
			END SetOffsets;


			PROCEDURE MoveLines( down: BOOLEAN );
			VAR prev, l, newtop: Line;
			BEGIN
				l := first; prev := NIL;
				WHILE l # scrollTop DO  prev := l;  l := l.next  END;
				IF down THEN
					l := GetNewLine( );
					l.next := scrollTop;
					IF prev # NIL THEN
						prev.next := l;
						IF top = scrollTop THEN top := l  END
					ELSE  first := l;  top := l
					END;
					WHILE (l # scrollBottom) & (l.next # NIL) DO  prev := l; l := l.next  END;
					prev.next := l.next; (* unlink bottom line *)
				ELSE	(* up *)
					WHILE (l # scrollBottom) & (l.next # NIL) DO  l := l.next  END;
					l := AppendLine( l );
					newtop := scrollTop.next;
					prev.next := newtop;	(* unlink top line *)
					IF top = scrollTop THEN  top := newtop  END;
					IF first = scrollTop THEN  first := newtop  END;
				END;
				SetScrollRegion;
				SetOffsets
			END MoveLines;

			PROCEDURE Scroll( down: BOOLEAN );
			BEGIN {EXCLUSIVE}
				MoveLines( down );
				IF down THEN
					cursor.line := scrollTop; cursor.ofs := 0;
					UpdateAll
				ELSE
					cursor.line := scrollBottom; cursor.ofs := 0;
					UpdateAll
				END
			END Scroll;


			PROCEDURE SetMargins( beg, end: SIZE );
			BEGIN {EXCLUSIVE}
				scrollBegin := beg - 1;
				scrollEnd := end - 1 ;
				SetScrollRegion
			END SetMargins;


			PROCEDURE RightTab;
			VAR l: Line; ofs: SIZE; char: Char;
			BEGIN {EXCLUSIVE}
				char.attr := attr; char.char := 020H;
				l := cursor.line;  ofs := cursor.ofs + 1;
				WHILE (ofs < cols) & ~tabs[ofs] DO
					l.data[ofs] := char;  INC( ofs )
				END;
				IF ofs = cursor.ofs THEN  RETURN  END;
				UpdateRect( l, l, cursor.ofs, ofs, {4} )
			END RightTab;

			PROCEDURE EraseLine( l: Line; from, to: SIZE );
			VAR i: SIZE;
			BEGIN
				i := from;
				WHILE i <= to DO
					l.data[i].attr := attr;  l.data[i].char := 0;
					INC( i )
				END
			END EraseLine;

			PROCEDURE Erase( mode: CHAR;  CONST par: ARRAY OF SIGNED32;  n: SIZE );
			BEGIN {EXCLUSIVE}
				CASE mode OF
				|"J":
					sel.beg.line := NIL;
					top := GetLastLine();
					cursor.line := top; cursor.ofs := 0;
					EraseLine( top, 0, cols-1 );
					UpdateAll();
					SetScrollRegion;
				|"K":
					IF n = 0 THEN
						EraseLine( cursor.line, cursor.ofs, cols-1 );
						UpdateRect( cursor.line, cursor.line, cursor.ofs, cols-1, {} )
					ELSIF (n = 1) & (par[0] = 1) THEN
						EraseLine( cursor.line, 0, cursor.ofs );
						UpdateRect( cursor.line, cursor.line, 0, cursor.ofs, {} )
					ELSIF (n = 1) & (par[0] = 2) THEN
						EraseLine( cursor.line, 0, cols-1 );
						UpdateRect( cursor.line, cursor.line, 0, cols-1, {} )
					END
				END
			END Erase;

			PROCEDURE NewAttr;
			VAR f: Files.File;
			BEGIN
				NEW(attr); attr.special := {};
				f := Files.Old( "PTMono_bd.ttf" );
				IF f # NIL THEN
					attr.fnt := WMG.GetFont( "PTMono", 13, {0} )
				ELSE
					attr.fnt := WMG.GetFont( "Courier", 12, {} )
				END;
				attr.bg := WMG.RGBAToColor( 255, 255, 255, 255 );
				attr.fg := WMG.RGBAToColor( 0, 0, 0, 255 )
			END NewAttr;

			PROCEDURE Bright;
			VAR style: SET;
			BEGIN
				style := attr.fnt.style;
				IF ~(WMG.FontBold IN style) THEN
					INCL( style, WMG.FontBold );
					attr.fnt := WMG.GetFont( attr.fnt.name, attr.fnt.size, style )
				ELSE
					(* Log.String("Bright"); Log.Ln() *)
				END 
			END Bright;

			PROCEDURE Dim;
			VAR style: SET;
			BEGIN
				style := attr.fnt.style;
				IF WMG.FontBold IN style THEN
					EXCL( style, WMG.FontBold );
					attr.fnt := WMG.GetFont( attr.fnt.name, attr.fnt.size, style )
				ELSE
					(* Log.String("Dim"); Log.Ln()	*)
				END
			END Dim;

			PROCEDURE SetAttributes( CONST attrs: ARRAY OF SIGNED32; n: SIZE );
			VAR c: WMG.Color; i: SIZE;
			BEGIN {EXCLUSIVE}
				NewAttr();
				i := 0;
				WHILE i < n DO
					CASE attrs[i] OF
					|0: (* Reset *) NewAttr()
					|1: (* Bright *) Bright()
					|2: (* Dim *) Dim()
					|4: (* Underscore *) INCL( attr.special, Underscore )
					|5: (* Blink *) INCL( attr.special, Blink )
					|7: (* Reverse *) c := attr.bg; attr.bg := attr.fg; attr.fg := c
					|8: (* Hidden *) attr.fg := attr.bg
					ELSE
						Log.String("attr "); Log.Int(attrs[i], 0); Log.Ln()
					END;
					INC(i)
				END
			END SetAttributes;

			PROCEDURE Draw*( canvas: WMG.Canvas );
			VAR
				l: Line; i, j, dy, bottom: SIZE; attr: Attribute; char: Char;
				box: WMG.Rectangle;
			BEGIN {EXCLUSIVE}
				canvas.Fill( canvas.clipRect, bg, WMG.ModeCopy );
				l := first;
				WHILE l # top DO
					l.t := MIN(SIGNED16); l.b := MIN(SIGNED16); l := l.next
				END;
				attr := NIL; bottom := dY + rows*boxH;
				box.t := dY; box.b := dY + boxH; j := 0;

				WHILE (l # NIL) & (j < rows) & (box.b <= bottom) DO
					l.t := box.t; l.b := box.b;
					box.l := dX; box.r := dX + boxW; i := 0;
					WHILE i < cols DO
						char := l.data[i];
						IF char.attr # attr THEN
							attr := char.attr;
							canvas.SetColor( attr.fg );
							canvas.SetFont( attr.fnt );
							dy := attr.fnt.GetDescent()
						END;
						IF attr.bg # bg THEN
							canvas.Fill( box, attr.bg, WMG.ModeCopy )
						END;
						IF char.char # 0 THEN
							attr.fnt.RenderChar( canvas, box.l, box.b-dy, char.char )
						END;
						IF Underscore IN attr.special THEN
							canvas.Line( box.l, box.b-dy+1, box.r-1, box.b-dy+1, attr.fg, WMG.ModeCopy )
						END;
						INC( i ); INC( box.l, boxW ); INC( box.r, boxW )
					END;
					INC( j ); l := l.next;
					INC( box.t, boxH ); INC( box.b, boxH )
				END;

				WHILE l # NIL DO
					l.t := MAX(SIGNED16); l.b := MAX(SIGNED16); l := l.next
				END;

				IF hasFocus & (cursor.ofs >= 0) & (cursor.ofs < cols) THEN
					l := cursor.line; box.t := l.t; box.b := l.b;
					IF box.t < box.b THEN
						box.l := dX + cursor.ofs*boxW; box.r := box.l + boxW;
						canvas.Fill( box, WMG.RGBAToColor( 255, 0, 0, 192 ), WMG.ModeSrcOverDst )
					ELSE
						FocusLost
					END
				END;
				IF sel.beg.line # NIL THEN
					IF sel.beg.line = sel.end.line THEN
						box.l := dX + sel.beg.ofs * boxW; box.r := dX + sel.end.ofs * boxW + boxW;
						box.t := sel.beg.line.t; box.b := sel.end.line.b;
						canvas.Fill( box, WMG.RGBAToColor( 0, 0, 255, 32 ), WMG.ModeSrcOverDst )
					ELSE
						box.l := dX + sel.beg.ofs * boxW; box.r := dX + cols * boxW;
						box.t := sel.beg.line.t; box.b := sel.beg.line.b;
						canvas.Fill( box, WMG.RGBAToColor( 0, 0, 255, 32 ), WMG.ModeSrcOverDst );
						l := sel.beg.line.next;
						WHILE l # sel.end.line DO
							box.l := dX; box.r := dX + cols * boxW;
							box.t := l.t; box.b := l.b;
							canvas.Fill( box, WMG.RGBAToColor( 0, 0, 255, 32 ), WMG.ModeSrcOverDst );
							l := l.next
						END;
						box.l := dX; box.r := dX + sel.end.ofs * boxW + boxW;
						box.t := sel.end.line.t; box.b := sel.end.line.b;
						canvas.Fill( box, WMG.RGBAToColor( 0, 0, 255, 32 ), WMG.ModeSrcOverDst )
					END
				END
			END Draw;

			PROCEDURE MoveCursor( dr, dc: SIZE );
			VAR col, currrow: SIZE;
			BEGIN
				col := GetCol() + dc;
				IF col < 0 THEN  col := 0  END;
				currrow := GetRow();
				IF (currrow = scrollEnd) & (dr > 0) THEN
					IF currrow < rows - 1 THEN  Scroll( FALSE );  Goto( currrow, col )
					ELSE Goto( currrow + 1, col )
					END
				ELSIF (currrow = scrollBegin) & (dr < 0) THEN  Scroll( TRUE );  Goto( currrow, col )
				ELSE  Goto( currrow + dr, col )
				END
			END MoveCursor;

			PROCEDURE ESCSequence( ch: CHAR; r: Streams.Reader );
			VAR
				par: ARRAY 4 OF SIGNED32; i, n: SIZE;
			BEGIN
				r.Char( ch );
				IF ch = "[" THEN
					ch := r.Peek(); n := 0;
					IF ch = "?" THEN
						r.Char( ch ); ch := r.Peek();
						IF (ch >= "0") & (ch <= "9") THEN
							REPEAT
								r.Int( par[n], FALSE );  INC( n );
								r.Char( ch )
							UNTIL (n >= 4) OR (ch # " ")
						END
					ELSIF (ch >= "0") & (ch <= "9") THEN
						REPEAT
							r.Int( par[n], FALSE ); INC( n );
							r.Char( ch )
						UNTIL (n >= 4) OR (ch # ";")
					ELSE
ASSERT( ch < DEL );
						r.Char( ch )
					END;
					CASE ch OF
					|"A":
						IF n = 1 THEN  MoveCursor( -par[0], 0 )  ELSE  MoveCursor( -1, 0 )  END
					|"B":
						IF n = 1 THEN  MoveCursor( par[0], 0 )  ELSE  MoveCursor( 1, 0 )  END
					|"C":
						IF n = 1 THEN  MoveCursor( 0, par[0] )  ELSE  MoveCursor( 0, 1 )  END
					|"D":
						IF n = 1 THEN  MoveCursor( 0, -par[0] )  ELSE  MoveCursor( 0, -1 )  END
					|"H":
						IF n = 2 THEN  Goto( par[0] - 1, par[1] - 1 )  ELSE  Goto( 0, 0 )  END
					|"J", "K":
						Erase( ch, par, n )
					|"h":
						IF n = 1 THEN
							IF par[0] = 1 THEN  INCL( mode, CursorKeyMode )
							ELSIF par[0] = 7 THEN  INCL( mode, AutoWrapMode )
							END
						END
					|"l":
						IF n = 1 THEN
							IF par[0] = 1 THEN  EXCL( mode, CursorKeyMode )
							ELSIF par[0] = 7 THEN  EXCL( mode, AutoWrapMode )
							END
						END
					|"m":
						SetAttributes( par, n )
					| "r":
						SetMargins( par[0], par[1] )
					ELSE
Log.Ln;  Log.String( "got unknown sequence ESC [ " );
i := 0;
WHILE i < n DO
	Log.Int( par[i], 0 );  INC( i );
	IF i < n THEN  Log.String( " ; " )  END
END;
Log.Char( ch );  Log.Ln;
					END
				ELSE
					CASE ch OF
					|"7":
						old.attr := attr;
						old.offs := GetCol();
						old.row := GetRow()
					|"8":
						IF r.Peek( ) = '#' THEN  r.Char( ch )
						ELSE  attr := old.attr;  Goto( old.row, old.offs )
						END
					|"=":
						INCL( mode, AppKeypadMode )
					|">":
						EXCL( mode, AppKeypadMode )
					|"D":
						IF GetRow() = scrollEnd THEN  Scroll( FALSE )
						ELSE  Goto( GetRow() + 1, GetCol() )
						END
					|"M":
						IF GetRow() = scrollBegin THEN  Scroll( TRUE )
						ELSE  Goto( GetRow() - 1, GetCol() )
						END
					ELSE
Log.String("got unknown sequence ESC ");
IF (ch >= ' ') & (ch <= '~') THEN  Log.Char( "'" ); Log.Char( ch ); Log.Char( "'" )
ELSE  Log.Hex( ORD( ch ), 2 ); Log.Char( 'X' )
END;
Log.Ln;
					END
				END
			END ESCSequence;


			PROCEDURE Consume( ch: CHAR; r: Streams.Reader );
			VAR buf: ARRAY 256 OF CHAR; i, n: SIZE;
			BEGIN
				CASE ch OF
				|  0X: (* NUL *)
				|07X: Beep.Beep( 1000 )
				|08X: MoveCursor( 0, -1 )
				|09X: RightTab()
				|NL, 0BX, 0CX:
					MoveCursor( 1, -1000 )
				|CR:
					IF r.Peek() = NL THEN
						r.Char( ch );
						MoveCursor( 1, -1000 )
					ELSE
						MoveCursor( 0, -1000 )
					END
				|ESC: ESCSequence( ch, r )
				|DEL: Delete()
				ELSE (* iso-8859-1 *)
					buf[0] := ch;  i := 1;  n := r.Available();
					IF n > 0 THEN
						IF n > 127 THEN  n := 127  END;
						ch := r.Peek();
						WHILE (n > 0) & (ch >= ' ') & (ch <= '~') DO
							r.Char( ch ); DEC( n );
							buf[i] := ch; INC( i );
							IF n > 0 THEN  ch := r.Peek()  END
						END
					END;
					WriteChars( buf, i )
				END
			END Consume;


			PROCEDURE FocusReceived*;
			BEGIN
				FocusReceived^();
				UpdateBox( cursor.line, cursor.ofs )
			END FocusReceived;

			PROCEDURE FocusLost*;
			BEGIN
				FocusLost^();
				UpdateBox( cursor.line, cursor.ofs )
			END FocusLost;

			PROCEDURE LocateBox( x, y: SIZE; VAR pos: Position );
			VAR l: Line; ofs, i: SIZE;
			BEGIN
				IF x < dX THEN x := dX ELSIF x >= (dX + cols*boxW) THEN x := dX + cols*boxW-1 END;
				IF y < dY THEN y := dY ELSIF y >= (dY + rows*boxH) THEN y := dY + rows*boxH-1 END;
				pos.line := NIL; pos.ofs := -1;
				l := top;
				WHILE (l # NIL) & ~((l.t <= y) & (l.b > y)) DO
					l := l.next
				END;
				IF l # NIL THEN
					ofs := 0; i := dX;
					WHILE (ofs < cols) & ~((i <= x) & ((i+boxW) > x)) DO
						INC(ofs); INC(i, boxW)
					END;
					IF ofs < cols THEN
						pos.line := l; pos.ofs := ofs
					END
				END
			END LocateBox;



			PROCEDURE PointerDown*( x, y: SIZE; keys: SET );
			BEGIN
				IF (Left IN keys) & hasFocus THEN
					LocateBox( x, y, sel.beg );  sel.end := sel.beg
				ELSIF Right IN keys THEN
					ToWMCoordinates(x, y, x, y);
				ELSE
					sel.beg.line := NIL;  sel.beg.ofs := -1;
					sel.end := sel.beg
				END;
				UpdateAll()
			END PointerDown;

			PROCEDURE PointerMove*( x, y: SIZE; keys: SET );
			VAR pos: Position;
			BEGIN
				IF (Left IN keys) & (sel.beg.line # NIL) THEN
					LocateBox(x, y, pos);
					IF pos.line # NIL THEN
						IF pos.line.t > sel.beg.line.t THEN
							sel.end := pos
						ELSIF (pos.line = sel.beg.line) & (pos.ofs >= sel.beg.ofs) THEN
							sel.end := pos
						END;
						UpdateAll()
					END
				END
			END PointerMove;


			PROCEDURE PointerUp*( x, y: SIZE; keys: SET );
			END PointerUp;

			PROCEDURE CursorKey( keySym: SIZE );
			BEGIN
				w.Char( ESC );
				IF CursorKeyMode IN mode THEN  w.Char( "O" )
				ELSE  w.Char( "[" )
				END;
				CASE keySym OF
				|0FF51H: w.Char( "D" )
				|0FF52H: w.Char( "A" )
				|0FF53H: w.Char( "C" )
				|0FF54H: w.Char( "B" )
				ELSE
				END;
				w.Update()
			END CursorKey;

			PROCEDURE KeyEvent*( ucs: SIZE; flags: SET; VAR keySym: SIZE );
			BEGIN
				IF chan = NIL THEN  RETURN  END;

				IF ~(Inputs.Release IN flags) & hasFocus THEN
					IF (keySym DIV 256) = 0 THEN
						w.Char( CHR( keySym ) );  w.Update()
					ELSIF (keySym DIV 256) = 0FFH THEN
						CASE keySym OF
						|0FF51H .. 0FF54H:
							CursorKey(keySym)
						|0FF50H: (* Home *)
						|0FF55H: (* PgUp *)
						|0FF56H: (* PgDown *)
						|0FF57H: (* End *)
						|0FF63H: (* Insert *)
						|0FFFFH: (* Delete *)
						|0FF08H:
							w.Char( DEL );  w.Update()
						|0FF09H:
							w.Char( 9X );  w.Update()
						|0FF0DH:
							w.Char( CR );  w.Update()
						|0FF1BH:
							w.Char( ESC );  w.Update()
						|0FF8DH:
							IF AppKeypadMode IN mode THEN
								w.Char( ESC ); w.Char( "O" ); w.Char( "M" )
							ELSE
								w.Char( CR )
							END;
							w.Update()
						ELSE
						END
					END
				END
			END KeyEvent;

			PROCEDURE Handle*( VAR m : WMMessages.Message );
			BEGIN
				IF m.msgType = WMMessages.MsgKey THEN
					IF m.y MOD 256 = 9 THEN  KeyEvent( m.x, m.flags, m.y )
					ELSE  Handle^( m )
					END;
				ELSE Handle^( m )
				END
			END Handle;


			PROCEDURE resized;
			VAR l: Line; W, H, c, r, i: SIZE; d: Data; ch: Char;
			BEGIN {EXCLUSIVE}
				W := bounds.GetWidth() - 2*Border;
				H := bounds.GetHeight() - 2*Border;
				c := W DIV BoxW; r := H DIV BoxH;
				boxW := W DIV c; boxH := H DIV r;
				dX := Border + (W - c*boxW) DIV 2;
				dY := Border + (H - r*boxH) DIV 2;

				SetOffsets;
				IF c # cols THEN
					ch.attr := attr;  ch.char := 0;
					l := first;
					WHILE l # NIL DO
						NEW( d, c );  i := 0;
						WHILE (i < c) & (i < cols) DO  d[i] := l.data[i];  INC( i )  END;
						WHILE i < c DO  d[i] := ch;  INC( i )  END;
						l.data := d; l := l.next
					END
				END;
				IF (c # cols) OR (r # rows) THEN
					IF cursor.ofs >= c THEN  cursor.ofs := c - 1  END;
					l := cursor.line;
					IF l.b > (dY + r*boxH) THEN
						i := (l.b - (dY + r*boxH)) DIV boxH;
						l := top.next;
						WHILE (l # NIL) & (i > 0) DO  top := l;  l := l.next;  DEC( i )  END
					END;
					IF (rows # r) & (scrollEnd = rows - 1) THEN
						scrollEnd := r - 1;  scrollBottom := GetLine( r )
					END;
					sel.beg.line := NIL;  cols := c;  rows := r;
				END;
			END resized;

			PROCEDURE Resized*;
			BEGIN
				Resized^();
				resized();
				IF chan # NIL THEN  chan.WindowChange( cols, rows )  END
			END Resized;

			PROCEDURE Initialize*;
			BEGIN
				Initialize^();
				Resized;
				takesFocus.Set( TRUE );
				Invalidate()
			END Initialize;

			PROCEDURE SetChannel( c: SSHChannel );
			BEGIN {EXCLUSIVE}
				chan := c;
				Streams.OpenWriter( w, chan.Send );	
				mode := {};
				chan.WindowChange( cols, rows )
			END SetChannel;	
			
			
			PROCEDURE &New*( col, row: SIZE; wc: WindowCloser );
			VAR i: SIZE;
			BEGIN
				Init();
				windowCloser := wc;
				rows := row;  cols := col;
				NewAttr();
				bg := WMG.RGBAToColor( 255, 255, 255, 255 );
				first := AppendLine( NIL );
				top := first;
				scrollBegin := 0;  scrollEnd := rows - 1;
				SetScrollRegion;
				cursor.line := top;  cursor.ofs := 0;
				boxW := 0;  boxH := 0;  dX := 0;  dY := 0;
				NEW( tabs, cols + 1 );
				tabs[0] := FALSE;  i := 1;
				WHILE i <= cols DO  tabs[i] := (i MOD 8) = 0;  INC( i )  END;
			END New;

			PROCEDURE Setup;
			BEGIN {EXCLUSIVE}
				AWAIT( chan # NIL );
			END Setup;
			
			PROCEDURE ChannelReader;
			VAR ch: CHAR;
				r: Streams.Reader;
			BEGIN
				Streams.OpenReader( r, chan.Receive );
				r.Char( ch ); 
				WHILE ch # 0X DO
					Consume( ch, r );
					r.Char( ch );
				END;
			END ChannelReader;

		BEGIN {ACTIVE}
			Setup();
			ChannelReader;
			windowCloser( )
		END Frame;

	
		Window = OBJECT( WMComponents.FormWindow )
		VAR
			toolbar: WMStandardComponents.Panel;
			address, user: WMEditors.Editor;
			connect, help : WMStandardComponents.Button;

			sshConn: SSHAuthorize.Connection;
			channel: SSHChannel;
			frame: Frame;

			PROCEDURE &New;
			VAR vc: WMComponents.VisualComponent;
			BEGIN
				vc := CreateForm();
				Init( vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE );
				SetContent( vc );
				SetTitle( WMWindowManager.NewString( "SSH Terminal" ) );
				WMWindowManager.DefaultAddWindow( SELF )
			END New;


			PROCEDURE CreateForm( ): WMComponents.VisualComponent;
			VAR
				panel: WMStandardComponents.Panel;
				label : WMStandardComponents.Label;
			BEGIN
				NEW( panel );
					panel.bounds.SetWidth( 2*Border + TerminalWidth*BoxW );
					panel.bounds.SetHeight( 2*Border + TerminalHeight*BoxH + 20 );
					panel.fillColor.Set( SIGNED32( 0FFFFFFFFH ) );

				NEW( toolbar );
					toolbar.bounds.SetHeight( 20 );
					toolbar.alignment.Set( WMComponents.AlignTop );
					toolbar.fillColor.Set( SIGNED32( 0CCCCCCFFH ) );

				NEW( label );
					label.bounds.SetWidth( 40 );
					label.alignment.Set( WMComponents.AlignLeft );
					label.caption.SetAOC( "Host" );
					label.textColor.Set( 0000000FFH );
				toolbar.AddContent(label);

				NEW( address );
					address.bounds.SetWidth( 250 );
					address.alignment.Set( WMComponents.AlignLeft );
					address.tv.textAlignV.Set(WMG.AlignCenter);
					address.multiLine.Set( FALSE );
					address.fillColor.Set( SIGNED32( 0FFFFFFFFH ) );
					address.tv.showBorder.Set( TRUE );
					address.tv.borders.Set( WMRectangles.MakeRect( 3,3,1,1 ) );
					address.onEnter.Add( ConnectHandler );
					address.SetAsString( lastHostname );
				toolbar.AddContent( address );

				NEW( label );
					label.bounds.SetWidth( 40 );
					label.alignment.Set( WMComponents.AlignLeft );
					label.caption.SetAOC( "User" );
					label.textColor.Set( 0000000FFH );
				toolbar.AddContent( label );

				NEW( user );
					user.bounds.SetWidth( 100 );
					user.alignment.Set( WMComponents.AlignLeft );
					user.tv.textAlignV.Set(WMG.AlignCenter);
					user.multiLine.Set( FALSE );
					user.fillColor.Set( SIGNED32( 0FFFFFFFFH ) );
					user.tv.showBorder.Set( TRUE );
					user.tv.borders.Set( WMRectangles.MakeRect( 3,3,1,1 ) );
					user.onEnter.Add( ConnectHandler );
					user.SetAsString( lastUsername );
				toolbar.AddContent( user );


				NEW( connect );
					connect.bounds.SetWidth( 100 );
					connect.alignment.Set( WMComponents.AlignLeft );
					connect.caption.SetAOC( "Connect" );
					connect.onClick.Add( ConnectHandler );
				toolbar.AddContent( connect );

				NEW( help );
					help.bounds.SetWidth( 100 );
					help.alignment.Set( WMComponents.AlignRight );
					help.caption.SetAOC( " Help " );
					help.onClick.Add( HelpHandler );

				toolbar.AddContent( help );
				panel.AddContent( toolbar );

				NEW( frame, TerminalWidth, TerminalHeight, Close );
				frame.alignment.Set( WMComponents.AlignClient );
				panel.AddContent( frame );
				Init( panel.bounds.GetWidth(), panel.bounds.GetHeight(), FALSE );

				RETURN panel
			END CreateForm;


			PROCEDURE Connected( ): BOOLEAN;
			BEGIN
				RETURN (channel # NIL) & (channel.state = SSHChannels.Open)
			END Connected;


			PROCEDURE ConnectHandler( sender, data: ANY );
			VAR host, uid: ARRAY 64 OF CHAR;
			BEGIN
				address.GetAsString( host );
				IF host = "" THEN
					Beep.Beep( 1000 );
					Log.String( "no hostname specified" ); Log.Ln;  RETURN 
				END;
				COPY( host, lastHostname );
				user.GetAsString( uid );
				IF uid = "" THEN
					Beep.Beep( 1000 );
					Log.String( "user name missing" ); Log.Ln;  RETURN 
				END;
				COPY( uid, lastUsername );
				IF Connected() THEN
					Beep.Beep( 1000 );
					Log.String( "already connected" ); Log.Ln;  RETURN 
				END;
				SetDefaultLogin( host, uid );

				sshConn := SSHAuthorize.OpenConnection( host, uid );
				IF sshConn # NIL THEN
					channel := SSHChannels.OpenSession( sshConn, TRUE (*interactive *) );
					IF channel # NIL THEN 
						frame.SetChannel( channel );
					ELSE
						sshConn.Disconnect( 11, "" );
					END
				END
			END ConnectHandler;

			PROCEDURE HelpHandler( sender, data: ANY );
			VAR res: INTEGER; msg: ARRAY 128 OF CHAR;
			BEGIN
				Commands.Call( "PAR Notepad.Open SSH.Tool ~", {}, res, msg );
				IF res # Commands.Ok THEN  Log.String( msg ); Log.Ln  END;
			END HelpHandler;


			PROCEDURE Close*;
			VAR timer: Kernel.Timer;
			BEGIN
				IF sshConn # NIL THEN  
					NEW( timer ); 
					IF Connected( ) THEN  channel.Close  END;
					sshConn.Disconnect( 11, "bye bye" );
					timer.Sleep( 200 );
				END;
				Close^
			END Close;

	END Window;

	PROCEDURE GetDefaultLogin;
	VAR f: Files.File; r: Files.Reader;
	BEGIN
		f := Files.Old( DefLogin );
		IF f # NIL THEN
			Files.OpenReader( r, f, 0 );
			IGNORE r.GetString( lastHostname );
			IGNORE r.GetString( lastUsername )
		END
	END GetDefaultLogin;
	
	PROCEDURE SetDefaultLogin( CONST host, uid: ARRAY OF CHAR );
	VAR f: Files.File; w: Files.Writer;
	BEGIN
		f := Files.New( DefLogin ); Files.OpenWriter( w, f, 0 );
		w.String( host ); w.Char( ' ' ); w.String( uid ); w.Ln;
		w.Update;
		Files.Register( f ); f.Close
	END SetDefaultLogin;

	PROCEDURE Open*;
	VAR inst: Window;
	BEGIN
		GetDefaultLogin;
		NEW( inst );
	END Open;

BEGIN
	lastHostname := "x02.math.uni-bremen.de";
	lastUsername := "fld"
END SSHTerminal.



SSHGlobals.SetDebug 1 ~

SSHTerminal.Open ~

System.Free SSH SSHTerminal~



home, end, delete, insert, pageup, pagedown

emacs
pine
pico
lynx

