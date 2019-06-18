(* ETH Oberon, Copyright 2000 ETH Zürich Institut für Computersysteme, ETH Zentrum, CH-8092 Zürich.
Refer to the general ETH Oberon System license contract available at: http://www.oberon.ethz.ch/ *)

MODULE KbdMouse;   (* g.f.	9.7.07 *)


(* replacement for the keyboard and mouse drivers in the Unix ports *)

IMPORT Machine, S := SYSTEM, Inputs, Plugins, X11, Displays, XDisplay, Commands, Objects;

#IF COOP THEN
	IMPORT Environment;
#END

CONST
	ML = 0;  MM = 1;  MR = 2;

	ModeSwitch = 13;

	MetaMask = { X11.Mod4Mask, ModeSwitch };


VAR
	event: X11.Event;  xbuttons: SET32;
	compstatus: X11.ComposeStatus;

	disp: XDisplay.Display;

	MMseen, MRseen: BOOLEAN;

TYPE
	Poll = OBJECT
		BEGIN {ACTIVE, SAFE,PRIORITY(Objects.High - 1)}
			LOOP
				Objects.Sleep( 15 );  PollXQueue;
				#IF COOP THEN
					IF Environment.status # Environment.Running THEN EXIT END;
				#END
			END
		END Poll;

VAR
	poll: Poll; keySymbol: ARRAY 256 OF LONGINT;

	PROCEDURE TerminateA2;
	VAR
		res: WORD;
		s: ARRAY 256 OF CHAR;
	BEGIN
		Commands.Call( "WMTerminator.Shutdown", {}, res, s );
	END TerminateA2;

	PROCEDURE CheckAlternateKeys( VAR mb: SET );
	BEGIN
		IF ~MMseen & (X11.ControlMask IN xbuttons) THEN INCL( mb, MM ) END;
		IF ~MRseen & (X11.Mod1Mask IN xbuttons) THEN INCL( mb, MR ) END
	END CheckAlternateKeys;


	PROCEDURE SendMouseMsg( x, y, dz: LONGINT; xbuttons: SET32 );
	VAR mm: Inputs.AbsMouseMsg;
	BEGIN
		Machine.Release( Machine.X11 );
		mm.keys := {};
		mm.x := x;  mm.y := y;  mm.dz := dz;
		IF X11.Button1Mask IN xbuttons THEN  INCL( mm.keys, ML )  END;
		IF X11.Button2Mask IN xbuttons THEN  INCL( mm.keys, MM );  MMseen := TRUE  END;
		IF X11.Button3Mask IN xbuttons THEN  INCL( mm.keys, MR );  MRseen := TRUE  END;
		IF ~(MMseen & MRseen) THEN  CheckAlternateKeys( mm.keys )  END;
		Inputs.mouse.Handle( mm );
		Machine.Acquire( Machine.X11 ); 
	END SendMouseMsg;

	PROCEDURE SendKeyboardMsg( km: Inputs.KeyboardMsg );
	BEGIN
		Machine.Release( Machine.X11 );
		Inputs.keyboard.Handle( km );
		Machine.Acquire( Machine.X11 ); 
	END SendKeyboardMsg;

	PROCEDURE PollXQueue;
	CONST bufsize = 20;
	VAR keycount, xr, yr, x, y, dz, i: LONGINT;
		rw, cw: X11.Window;
		keysym: X11.KeySym;  xd: X11.DisplayPtr;
		newxbuttons, bdiff: SET32;
		km: Inputs.KeyboardMsg;
		kp : X11.KeyEvent;
		be : X11.ButtonEvent;
		em: X11.ExposeEvent;
		cm : X11.ClientMessageEvent;
		cn: X11.ConfigureEvent;
		events: LONGINT;
		buffer: ARRAY bufsize OF CHAR;
	BEGIN
		xd := disp.xdisp;
		Machine.Acquire( Machine.X11 );
		X11.Synchronize(xd, X11.True);
		events := X11.Pending( xd );
		Machine.Release( Machine.X11 ); 
		WHILE events > 0 DO
			Machine.Acquire( Machine.X11 );
			X11.NextEvent( xd, event );
			CASE event.typ OF
			| X11.KeyPress: kp := S.VAL( X11.KeyEvent, event );
					X11.lastEventTime := kp.time;
					keycount := X11.LookupString( kp, buffer, bufsize, keysym, compstatus );
					X11.QueryPointer( xd, event.window, rw, cw, xr, yr, x, y, newxbuttons );

					IF keycount = 0 THEN
						bdiff := newxbuttons / xbuttons;  xbuttons := newxbuttons;
						km.ch := 0X;
						IF X11.ShiftMask IN bdiff THEN km.keysym := Inputs.KsShiftL
						ELSIF X11.ControlMask IN bdiff THEN
							km.keysym := Inputs.KsControlL;
							IF ~MMseen THEN  SendMouseMsg( x, y, 0, xbuttons )  END
						ELSIF X11.Mod1Mask IN bdiff THEN
							km.keysym := Inputs.KsAltL;
							IF ~MRseen THEN SendMouseMsg( x, y, 0, xbuttons )  END
						ELSIF MetaMask*bdiff # {} THEN km.keysym := Inputs.KsMetaL
						ELSIF X11.Mod5Mask IN bdiff THEN km.keysym := Inputs.KsAltR
						ELSIF keysym = 0FE20H THEN  (* handle Shift-Tab key *)
							km.keysym := Inputs.KsTab; km.ch :=09X
						ELSE
							km.keysym := LONGINT(keysym);
						END;
						km.flags := KeyState( );
						SendKeyboardMsg( km )
					ELSE
						IF (X11.ControlMask IN kp.state) & (keysym = 32) THEN (* check Ctrl-space *)
							km.ch := CHR( keysym );  km.flags := KeyState( );
							km.keysym := LONGINT(keysym);
							SendKeyboardMsg( km ); (* IME keys *)
						ELSE
							xbuttons := newxbuttons;  i := 0;
							WHILE i < keycount DO
								km.ch := buffer[i];
								IF km.ch = 0F1X THEN  km.ch := 0A4X
								ELSIF km.ch = 0F2X THEN km.ch := 0A5X
								END;
								km.keysym := keySymbol[ORD( km.ch )];
								km.flags := KeyState( );
								SendKeyboardMsg( km );
								INC( i )
							END
						END;
					END;
			| X11.KeyRelease: kp := S.VAL(X11.KeyEvent, event);
					X11.lastEventTime := kp.time;
					X11.QueryPointer( xd, event.window, rw, cw, xr, yr, x, y, newxbuttons );
					bdiff := newxbuttons / xbuttons;  xbuttons := newxbuttons;
					IF bdiff # {} THEN
						km.ch := 0X;
						IF X11.ShiftMask IN bdiff THEN km.keysym := Inputs.KsShiftL
						ELSIF X11.ControlMask IN bdiff THEN
							km.keysym := Inputs.KsControlL;
							IF ~MMseen THEN  SendMouseMsg( x, y, 0, xbuttons )  END
						ELSIF X11.Mod1Mask IN bdiff THEN
							km.keysym := Inputs.KsAltL;
							IF ~MRseen THEN SendMouseMsg( x, y, 0, xbuttons )  END
						ELSIF MetaMask*bdiff # {} THEN km.keysym := Inputs.KsMetaL
						ELSIF X11.Mod5Mask IN bdiff THEN km.keysym := Inputs.KsAltR
						END;
						km.flags := KeyState( ) + {Inputs.Release};
						SendKeyboardMsg( km )
					END
			| X11.ButtonPress: be := S.VAL(X11.ButtonEvent, event);
					X11.lastEventTime := be.time;
					dz := 0;
					CASE be.button OF
					| X11.Button1:  INCL( xbuttons, X11.Button1Mask )
					| X11.Button2:  INCL( xbuttons, X11.Button2Mask )
					| X11.Button3:  INCL( xbuttons, X11.Button3Mask )
					| X11.Button4: dz := -1
					| X11.Button5: dz := +1
					ELSE  (* ignore *)
					END;
					SendMouseMsg( be.x, be.y, dz, xbuttons )
			| X11.ButtonRelease: be := S.VAL(X11.ButtonEvent, event);
					X11.lastEventTime := be.time;
					CASE be.button OF
					| X11.Button1:  EXCL( xbuttons, X11.Button1Mask )
					| X11.Button2:  EXCL( xbuttons, X11.Button2Mask )
					| X11.Button3:  EXCL( xbuttons, X11.Button3Mask )
					ELSE  (* ignore *)
					END;
					SendMouseMsg( be.x, be.y, 0, xbuttons )
			| X11.MotionNotify:
					X11.QueryPointer( xd, event.window, rw, cw, xr, yr, x, y, xbuttons );
					SendMouseMsg( x, y, 0, xbuttons )
			| X11.Expose, X11.GraphicsExpose:
					em := S.VAL( X11.ExposeEvent, event );
					IF em.count = 0 THEN  (* wait until last message*)
						(* Let DisplayRefresher handle this *)
						km.keysym := 0FFC6H;
						SendKeyboardMsg( km );
					END;
			| X11.NoExpose:
			| X11.MappingNotify:
					X11.RefreshKeyboardMapping( ADDRESSOF( event ) )
			| X11.ClientMessage:
					cm := S.VAL( X11.ClientMessageEvent, event );
					IF  cm.data[0] = disp.wmDelete THEN
						(* shutdown *)
						Machine.Release( Machine.X11 );
						TerminateA2;
						RETURN;
					(*	Modules.Shutdown( Modules.Reboot ); *)
					END;
			| X11.UnmapNotify:
			| X11.MapNotify:
			| X11.SelectionClear:
					IF X11.ClearSelection # NIL THEN X11.ClearSelection(); END
			| X11.SelectionNotify:
					IF X11.ReceiveSelection # NIL THEN
						Machine.Release( Machine.X11 );
						X11.ReceiveSelection( S.VAL( X11.SelectionEvent, event ) );
						Machine.Acquire( Machine.X11 );
					END
			| X11.SelectionRequest:
					IF X11.SendSelection # NIL THEN
						Machine.Release( Machine.X11 );
						X11.SendSelection( S.VAL( X11.SelectionRequestEvent, event ) );
						Machine.Acquire( Machine.X11 )
					END
			| X11.ConfigureNotify:  cn := S.VAL(X11.ConfigureEvent, event);
			ELSE
				(* ignore *)
			END;
			events := X11.Pending( xd );
			Machine.Release( Machine.X11 );
		END;
	END PollXQueue;

	(* Returns wether key (SHIFT, CTRL or ALT) is pressed *)
	PROCEDURE KeyState( ): SET;
	VAR keys: SET;
	BEGIN
		keys := {};
		IF X11.ShiftMask IN xbuttons THEN  INCL( keys, Inputs.LeftShift )  END;
		IF X11.ControlMask IN xbuttons THEN  INCL( keys, Inputs.LeftCtrl )  END;
		IF X11.Mod1Mask IN xbuttons THEN  INCL( keys, Inputs.LeftAlt )  END;
		IF MetaMask*xbuttons # {} THEN  INCL( keys, Inputs.LeftMeta )  END;
		IF X11.Mod5Mask IN xbuttons THEN  INCL( keys, Inputs.RightAlt )  END;
		RETURN keys
	END KeyState;


	PROCEDURE Keysym( CONST str: ARRAY OF CHAR ): X11.KeySym;
	BEGIN
		RETURN X11.StringToKeysym( ADDRESSOF( str ) )
	END Keysym;

	PROCEDURE DisableMouseEmulation*;
	BEGIN
		MMseen := TRUE; MRseen := TRUE;
	END DisableMouseEmulation;


	PROCEDURE Init*;
	VAR FK: ARRAY 8 OF CHAR;
		n, i, k: LONGINT;  modifiers: X11.Modifiers;
		shift, control, meta, alt, capslock, numlock: X11.KeySym;


		PROCEDURE Rebind( CONST keystr: ARRAY OF CHAR;  nofmod: LONGINT;  key: CHAR );
		VAR newkeystr: ARRAY 8 OF CHAR;
			oldkeysym: X11.KeySym;
		BEGIN
			Machine.Acquire( Machine.X11 );
			oldkeysym := Keysym( keystr );
			newkeystr[0] := key;  newkeystr[1] := 0X;
			X11.RebindKeysym( disp.xdisp, oldkeysym, modifiers, nofmod, ADDRESSOF( newkeystr ), 1 );
			Machine.Release( Machine.X11 )
		END Rebind;

		PROCEDURE Rebind4( CONST keyString: ARRAY OF CHAR;  n: LONGINT;  key: CHAR );
		BEGIN
			Rebind( keyString, n, key );
			modifiers[n] := shift;  Rebind( keyString, n + 1, key );
			modifiers[n] := control;  Rebind( keyString, n + 1, key );
			modifiers[n + 1] := shift;  Rebind( keyString, n + 2, key );
		END Rebind4;

	BEGIN
		MMseen := FALSE;  MRseen := FALSE;


		Machine.Acquire( Machine.X11 );
		X11.SelectInput( disp.xdisp, disp.primary,
						  X11.ExposureMask + X11.ButtonPressMask + X11.OwnerGrabButtonMask +
						  X11.ButtonReleaseMask + X11.PointerMotionHintMask + X11.PointerMotionMask +
						  X11.KeyPressMask + X11.KeyReleaseMask + X11.StructureNotifyMask );
	 	shift := Keysym( "Shift_L" );  control := Keysym( "Control_L" );
		meta := Keysym( "Meta-L" );  alt := Keysym( "Alt_L" );
		capslock := Keysym( "Caps_Lock" );  numlock := Keysym( "Num_Lock" );
		Machine.Release( Machine.X11 );

		modifiers[0] := shift;
		Rebind( "Pause", 1, 0ADX );   (* SHIFT-BREAK *)

		modifiers[0] := control;	Rebind( "Return", 1, 0AX );
		   modifiers[1] := numlock;	Rebind( "Return", 2, 0AX );
		   modifiers[1] := capslock;	Rebind( "Return", 2, 0AX );
			modifiers[2] := numlock;	Rebind( "Return", 3, 0AX );


		FOR k := 0 TO 4 DO
			CASE k OF
			| 0:   n := 0;
			| 1:   modifiers[0] := meta;  n := 1;
			| 2:   modifiers[0] := capslock;  n := 1
			| 3:   modifiers[0] := numlock;  n := 1
			| 4:   modifiers[0] := capslock;  modifiers[1] := numlock;  n := 2
			END;
			i := 0;  FK := "F0";
			WHILE i < 10 DO FK[1] := CHR( ORD( "0" ) + i );  Rebind4( FK, n, CHR( 0F0H + i ) );  INC( i ) END;
			i := 10;  FK := "F10";
			WHILE i <= 12 DO FK[2] := CHR( ORD( "0" ) + i - 10 );  Rebind4( FK, n, CHR( 0F0H + i ) );  INC( i ) END;

			Rebind4( "BackSpace", n, 7FX );
			Rebind4( "Delete", n, 0A1X );
			Rebind4( "Escape", n, 1BX );
			Rebind4( "Up", n, 0C1X );  Rebind4( "Down", n, 0C2X );
			Rebind4( "Left", n, 0C4X );  Rebind4( "Right", n, 0C3X );
			IF k < 3 THEN
				(* do not for NumLock on *)
				Rebind4( "KP_Up", n, 0C1X );  Rebind4( "KP_Down", n, 0C2X );
				Rebind4( "KP_Left", n, 0C4X );  Rebind4( "KP_Right", n, 0C3X );
			END;
			Rebind4( "Prior", n, 0A2X );  Rebind4( "KP_Prior", n, 0A2X );
			Rebind4( "Next", n, 0A3X );  Rebind4( "KP_Next", n, 0A3X );
			Rebind4( "Insert", n, 0A0X );
			Rebind4( "Home", n, 0A8X );  Rebind4( "KP_Home", n, 0A8X );
			Rebind4( "End", n, 0A9X );  Rebind4( "KP_End", n, 0A9X );
		END;


		(* special keyboard: *)
		modifiers[0] := shift;  modifiers[1] := meta;
		FOR i := 0 TO 2 DO
			Rebind( "aacute", i, 094X );
			Rebind( "agrave", i, 08BX );
			Rebind( "Adiaeresis", i, 080X );		Rebind( "adiaeresis", i, 083X );
			Rebind( "acircumflex", i, 086X );
			Rebind( "eacute", i, 090X );
			Rebind( "egrave", i, 08CX );
			Rebind( "ediaeresis", i, 091X );
			Rebind( "ecircumflex", i, 087X );
			Rebind( "igrave", i, 08DX );
			Rebind( "idiaeresis", i, 092X );
			Rebind( "icircumflex", i, 088X );
			Rebind( "ograve", i, 08EX );
			Rebind( "Odiaeresis", i, 081X );		Rebind( "odiaeresis", i, 084X );
			Rebind( "ocircumflex", i, 089X );
			Rebind( "ugrave", i, 08FX );
			Rebind( "Udiaeresis", i, 082X );		Rebind( "udiaeresis", i, 085X );
			Rebind( "ucircumflex", i, 08AX );
			Rebind( "ccedilla", i, 093X );
			Rebind( "ntilde", i, 095X );
			Rebind( "ssharp", i, 096X );

			Rebind( "idotless", i, 0FDX);
			Rebind( "Iabovedot", i, 0DDX);
			Rebind( "gbreve", i, 0F0X );
			Rebind( "Gbreve", i, 0D0X );
			Rebind( "scedilla", i, 0FEX );
			Rebind( "Scedilla", i, 0DEX );
		END;

		InitKeysym;

		NEW( poll );
	END Init;

	PROCEDURE InitKeysym;
	VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO 255 DO keySymbol[i] := i END;
		keySymbol[07FH] := Inputs.KsBackSpace;
		keySymbol[009H] := Inputs.KsTab;
		keySymbol[00AH] := Inputs.KsReturn;
		keySymbol[00DH] := Inputs.KsReturn;

		keySymbol[0C1H] := Inputs.KsUp;
		keySymbol[0C2H] := Inputs.KsDown;
		keySymbol[0C3H] := Inputs.KsRight;
		keySymbol[0C4H] := Inputs.KsLeft;

		keySymbol[0A0H] := Inputs.KsInsert;
		keySymbol[0A1H] := Inputs.KsDelete;
		keySymbol[0A2H] := Inputs.KsPageUp;
		keySymbol[0A3H] := Inputs.KsPageDown;
		keySymbol[0A8H] := Inputs.KsHome;
		keySymbol[0A9H] := Inputs.KsEnd;
		keySymbol[01BH] := Inputs.KsEscape;

		FOR i := 0F1H TO 0FCH DO keySymbol[i] := 0FFBEH + (i - 0F1H) END;
		keySymbol[0A4H] := Inputs.KsF1;
		keySymbol[0A5H] := Inputs.KsF2;
	END InitKeysym;

	PROCEDURE GetXDisplay;
	VAR p: Plugins.Plugin;
	BEGIN
		p := Displays.registry.Await( "XDisplay" );  disp := p( XDisplay.Display )
	END GetXDisplay;
	
BEGIN
	ASSERT( S.VAL( LONGINT, {0} ) = 1 );
	GetXDisplay;
END KbdMouse.


(** Remark:

1. Keyboard character codes correspond to the ASCII character set. Some other important codes are:

	SHIFT-BREAK	0ADX
	BREAK	0ACX
	F1 ... F12	0F1X ... 0FCX
	UP ARROW	0C1X
	RIGHT ARROW	0C3X
	DOWN ARROW	0C2X
	LEFT ARROW	0C4X
	INSERT	0A0X
	DELETE	0A1X
	PAGE-UP	0A2X
	PAGE-DOWN	0A3X

	some none ascii character get mapped to UTF8:
	ä, Ä	131, 128
	ö, Ö	132, 129
	ü, Ü	133, 130
	ß	150
	. . .

*)
