MODULE Display;   (** fof , source Win32.Windows.Mod+Win32.Displays.Mod+Windows.Display.Mod+Win32.Viewers.Mod **)

IMPORT SYSTEM, Environment, Activities, Counters, Kernel32, User32, Modules, KernelLog, GDI32, Displays, Strings,
	AosInputs := Inputs, Commands, Objects,WinFS, Options;

CONST
	dbgDisableReleaseMsg = TRUE;

CONST
	WMSetup = User32.WMUser + 1;  WMCreateWindow = User32.WMUser + 2;
	(* Windows, WinMenus: User32.WMUser .. User32.WMUser+9
			NetSystem: User32.WMUser+10 .. User32.WMUser+19
			NPPlugIns: User32.WMUser+20 .. User32.WMUser+29
			OLE*: User32.WMUser+30 .. User32.WMUser+39 *)
	IDFirstAccelCmd = 0;   (* addAccel *)
	IDFirstMenuCmd* = 64;   (** first ID to be used by menus (see: WinMenus) *)
	Insert = 0A0X;  Delete = 0A1X;  Backspace = 07FX;  Home = 0A8X;  End = 0A9X;  PageUp = 0A2X;  PageDown = 0A3X;
	Up = 0C1X;  Down = 0C2X;  Right = 0C3X;  Left = 0C4X;   (* cursor keys *) Enter = 0DX;  F1 = 0A4X;  F2 = 0A5X;
	F3 = 0A6X;  F4 = 0A7X;  F5 = 0F5X;  F6 = 0F6X;  F7 = 0F7X;  F8 = 0F8X;  F9 = 0F9X;  F10 = 0FAX;  F11 = 0FBX;  F12 = 0FCX;
	update = 0;  dummy = 1;  minimized = 2;  external = 3;  control = 4;  maximized = 5;  MaxAccel = 32;  MaxCmd = 128;
	ML = 0;  MM = 1;  MR = 2;  MX = 3;  WHEEL = 31;  GWLWindow* = 0;  GWLControl* = 4;  SHIFT* = 0;  CTRL* = 1;
	ALT* = 2;   (** constants for KeyState *)
	create* = 0;  remove* = 1;   (** display has been created or destroyed *)
	restore* = 2;  suspend* = 3;   (** display has been minimized or restored *)
	redraw* = 4;  resize* = 5;   (** display needs redraw *)
	print* = 6;   (** print the display in the give context *)
	focus* = 7;  defocus* = 8;   (** display got or lost the keyboard focus *)
	consume* = 9;  track* = 10;   (** keyboard or mouse data available *)
	dupdate* = 11;   (** notification, that an object has been updated *)
	execute* = 12;   (** request to execute a command *)
	quit* = 13;   (** notification, that the Event service is shutdown *)
	ping* = 14;   (** checks whether the event dispatcher (Oberon.Loop) is running *)
	wheel* = 15;   (** mouse wheel *)
	get* = 0;  set* = 1;

	pressed = 15;  toggled = 0;

	letWindowsHandleTheBuffer = FALSE;

CONST
	kPageUp = User32.VKPrior;  kPageDown = User32.VKNext;  kEnd = User32.VKEnd;  kHome = User32.VKHome;
	kLeft = User32.VKLeft;  kRight = User32.VKRight;  kUp = User32.VKUp;  kDown = User32.VKDown;
	kInsert = User32.VKInsert;  kDelete = User32.VKDelete;  kF1 = User32.VKF1;  kF2 = User32.VKF2;  kF3 = User32.VKF3;
	kF4 = User32.VKF4;  kF5 = User32.VKF5;  kF6 = User32.VKF6;  kF7 = User32.VKF7;  kF8 = User32.VKF8;  kF9 = User32.VKF9;
	kF10 = User32.VKF10;  kF11 = User32.VKF11;  kF12 = User32.VKF12;  kCtrl = 17;  kAlt = 18;  kWindows = 91;  kShift = 16;
	kMenu = 93;  kNumlock = 144;  kEnter = 13;  kPAdd = 107;  kPMinus = 109;  kPDiv = 111;  kPMult = 106;  kPause = 19;
	kCapsLock = 20;  kEscape = 27;  kTab = 9;  kReturn = User32.VKReturn;
	VK0 = 030H; VK9 = 39H;

	VKMenu = 18;
	VKScroll = 145;
	VKLShift = 160;  VKRShift = 161;   VKLCtrl = 162; VKRCtrl = 163; VKLMenu = 164; VKRMenu = 165;
	VKLWin = 05BH; VKRWin = 05CH;

	SMCXFullscreen = 16;  SMCYFullscreen = 17;  SMCYScreen = 1;  SMCXScreen = 0;  MODWin = 8;

	WMHOTKEY = 786;

	Sizemaximized = 2;  Sizeminimized = 1;  Sizerestored = 0;

	WindowTitle = "WinAOS (Cooperative)";

	WM_DEVICECHANGE = 0219H;

	DBT_CONFIGCHANGECANCELED = 00019H  ;
	DBT_CONFIGCHANGED =00018H  ;
	DBT_CUSTOMEVENT =08006H ;
	DBT_DEVICEARRIVAL =08000H  ;
	DBT_DEVICEQUERYREMOVE =08001H  ;
	DBT_DEVICEQUERYREMOVEFAILED = 08002H  ;
	DBT_DEVICEREMOVECOMPLETE = 08004H  ;
	DBT_DEVICEREMOVEPENDING = 08003H  ;
	DBT_DEVICETYPESPECIFIC =08005H ;
	DBT_DEVNODES_CHANGED = 00007H ;
	DBT_QUERYCHANGECONFIG =  00017H;
	DBT_USERDEFINED = 0FFFFH ;

	DBT_DEVTYP_VOLUME = 00002H;

TYPE

	DEV_BROADCAST_HDR  = RECORD
		dbch_size: SIGNED32;
		dbch_devicetype: SIGNED32 ;
		dbch_reserved: SIGNED32;
	END;
	DEV_BROADCAST_HDRP  = POINTER  TO DEV_BROADCAST_HDR;

	DEV_BROADCAST_VOLUME = RECORD   (DEV_BROADCAST_HDR)
		dbcv_unitmask: SET;
		dbcv_flags: SIGNED16;
		padding: SIGNED16;
	END;
	DEV_BROADCAST_VOLUMEP= POINTER TO DEV_BROADCAST_VOLUME;

	Inputs = RECORD
		keys: SET;
		X, Y, Z, dx, dy: SIGNED32;
		flags: SET;
	END;
	(** The BITMAPINFO structure defines the dimensions and color information for a Win32 DIB. *)


	BitmapInfo* = RECORD
		bmiHeader*: GDI32.BitmapInfoHeader;
		colors: ARRAY 3 OF SIGNED32;
		(* old: colors: ANY;  *)
	END;

	Window = POINTER TO RECORD
		hWnd: User32.HWND;   (** handle of this window *)
		hWndParent: User32.HWND;   (** handle of the parent window, = hWnd for document windows *)
		hDC: User32.HDC;

		width, height: SIGNED32;   (** current size *)

		defWindowProc: User32.WndProc;   (** default window procedure for all messages not handled here *)
		windowRect: User32.Rect;
		state: SET (* update, dummy, minimized, external, control *) ;
		link: Window;

		bmp: GDI32.HBitmap;
		bmadr: SIGNED32;

		bmphdc: User32.HDC;
		track: Inputs;
		pal: POINTER TO ARRAY OF GDI32.PaletteEntry;
		dx, dy: SIGNED32;
		hBrush: GDI32.HBrush;
		frame: BOOLEAN;

		processor: Activities.Activity;
	END;

	DisplayProc* = PROCEDURE ( disp: Window );
	PaintProc* = PROCEDURE ( disp: Window;  x, y, w, h: SIGNED32 );

	CreateStruct = POINTER TO RECORD
		win: Window;
		finished: BOOLEAN;
		className: ARRAY 32 OF CHAR;
		style: SET;
		x, y, w, h: SIGNED32;
		hMenu: User32.HMenu
	END;

	(** handler called for registered window messages *)
	WindowHandlerProc* = PROCEDURE {WINAPI} ( win: Window;  uMsg: SIGNED32;  wParam: User32.WParam;
																					  lParam: User32.LParam ): User32.LResult;
	Display = OBJECT (Displays.Display) (* only one instance of this object allowed ! *)

		PROCEDURE Transfer*( VAR buf: ARRAY OF CHAR;  ofs, stride, x, y, w, h: SIZE; op: SIGNED32 );
		BEGIN

			IF letWindowsHandleTheBuffer THEN
				IF op = Displays.set THEN
					ToMemory( root, buf, ofs, stride, x, y, w, h );  ToWindow( root, x, y, w, h, root.dx, root.dy );
				ELSE FromMemory( root, buf, ofs, stride, x, y, w, h );
				END;
			ELSE
				IF root.bmadr = 0 THEN GetDC( root ) END;
				InitFrameBuffer( root.bmadr, disp.width * disp.height * format, disp.width * disp.format);  Transfer^( buf, ofs, stride, x, y, w, h, op );
				IF Displays.reverse THEN
					IF op = Displays.set THEN ToWindow( root, disp.width-x-w,disp.height-y-h, w, h, root.dx, root.dy );  END;
				ELSE
					IF op = Displays.set THEN ToWindow( root, x, y, w, h, root.dx, root.dy );  END;
				END;
			END;

		END Transfer;

	END Display;

VAR
	dummyClass, windowClass: User32.WndClassEx;
	dummyClassName, windowClassName, controlClassName, windowTitle : ARRAY 32 OF CHAR;
	nWindows: SIGNED32;  aControlWinClass: SIGNED32;  fixedFrameX, fixedFrameY, frameX, frameY, captionY, menuY: SIGNED32;
	hCurrentCursor, hAlternativeCursor: User32.HCursor;  capture, hook, mouse: Window;  kioskmode*: BOOLEAN;
	dummyWin*: Window;
	ISOToOberon: ARRAY 256 OF CHAR;
	moduleCS: Kernel32.CriticalSection;  root: Window;
	bmi: RECORD
		info: BitmapInfo;
		pal: ARRAY 256 OF GDI32.ColorRef
	END;
	disp: Display;
	format* : SIGNED8;

	KeyHandled: BOOLEAN;

	fullscreen: BOOLEAN;   (*ALEX 2005.11.30*)

	closeRequests: SIGNED32;

	PROCEDURE CreateHWND( create: CreateStruct );
	VAR str: ARRAY 32 OF CHAR;
		ret: Kernel32.BOOL;
	BEGIN
		str := "";
		create.win.hWnd :=
			User32.CreateWindowEx( 0, create.className, str, create.style, create.x, create.y, create.w, create.h,
													   create.win.hWndParent, create.hMenu, Kernel32.hInstance,
													   SYSTEM.VAL( User32.LParam, create ) );
		IF User32.WSMaximize IN create.style THEN
			INCL( create.win.state, maximized );  ret := User32.ShowWindow( create.win.hWnd, User32.SWShowMaximized )
		ELSIF User32.WSVisible IN create.style THEN ret := User32.ShowWindow( create.win.hWnd, User32.SWShow )
		END;
		IF create.win.hWndParent = Kernel32.NULL THEN create.win.hWndParent := create.win.hWnd END;
	END CreateHWND;

	(* wParam contains the virtual key code
	 	lParam: {0..15}: Key repeat count, {16..23}: Scan code, {24}: Extended-key flag, {25..28}: Reserved,
	 	{29}: Context code (1 if ALT was down, 0 otherwise), {30}: Previous key-state flag, {31}: Transition-state flag *)
	PROCEDURE DecomposeKeyEvent( wParam, lParam: SIGNED32;  VAR ch: CHAR;  VAR key: SIGNED32;  char: BOOLEAN );
	VAR scancode: SIGNED32;  previous: SIGNED32;  repeat: SIGNED32;  extended: BOOLEAN;
	BEGIN
		repeat := lParam MOD ASH( 1, 16 );  scancode := ASH( lParam, -16 ) MOD ASH( 1, 8 );  extended := ODD( ASH( lParam, -24 ) );
		previous := ASH( lParam, -30 ) MOD 2;

		key := 0;  ch := 0X;

		CASE wParam OF
		| kEnter:
				IF extended THEN key := AosInputs.KsKPEnter ELSE key := AosInputs.KsReturn END; ch := Enter;
		| kPageUp:
				key := AosInputs.KsPageUp; ch := PageUp (* if ~extended then on numerical pad *)
		| kPageDown:
				key := AosInputs.KsPageDown;  ch := PageDown;
		| kEnd:
				key := AosInputs.KsEnd;  ch := End;
		| kHome:
				key := AosInputs.KsHome;  ch := Home;
		| kLeft:
				key := AosInputs.KsLeft;  ch := Left;
		| kRight:
				key := AosInputs.KsRight;  ch := Right;
		| kUp:
				key := AosInputs.KsUp;  ch := Up;
		| kDown:
				key := AosInputs.KsDown;  ch := Down;
		| kInsert:
				key := AosInputs.KsInsert;  ch := Insert;
		| kDelete:
				key := AosInputs.KsDelete;  ch := Delete;
		| kF1:
				key := AosInputs.KsF1;  ch := F1;
		| kF2:
				key := AosInputs.KsF2;  ch := F2;
		| kF3:
				key := AosInputs.KsF3;  ch := F3;
		| kF4:
				key := AosInputs.KsF4;  ch := F4;
		| kF5:
				key := AosInputs.KsF5;  ch := F5;
		| kF6:
				key := AosInputs.KsF6;  ch := F6;
		| kF7:
				key := AosInputs.KsF7;  ch := F7;
		| kF8:
				key := AosInputs.KsF8;  ch := F8;
		| kF9:
				key := AosInputs.KsF9;  ch := F9;
		| kF10:
				key := AosInputs.KsF10;  ch := F10;
		| kF11:
				key := AosInputs.KsF11;  ch := F11;
		| kF12:
				key := AosInputs.KsF12;  ch := F12;
		| kCtrl:
				IF extended THEN key := AosInputs.KsControlR ELSE key := AosInputs.KsControlL END;
		| kAlt:
				IF extended THEN key := AosInputs.KsAltR ELSE key := AosInputs.KsAltL END;
		| kMenu:
				key := AosInputs.KsMenu;
		| kNumlock:
				key := AosInputs.KsNumLock
		| kShift:
				IF extended THEN key := AosInputs.KsShiftR ELSE key := AosInputs.KsShiftL END;
		| kPause:
				key := AosInputs.KsPause
		| kCapsLock:
				key := AosInputs.KsCapsLock;
		| kEscape:
				key := AosInputs.KsEscape;
		| kTab:
				key := AosInputs.KsTab;  ch := 09X;
		| User32.VKBack:
				key := AosInputs.KsBackSpace; ch := Backspace;
		ELSE
			IF char THEN GetChar( wParam, lParam, ch, key ); END;
		END;
	END DecomposeKeyEvent;

	PROCEDURE GetChar( wParam, lParam: SIGNED32;  VAR ch: CHAR;  VAR key: SIGNED32 );
	BEGIN
		ch := ISOToOberon[wParam]; key := ORD( ch );
	END GetChar;

	PROCEDURE GetKeyState( key: SIGNED32;  what: SIGNED16 ): BOOLEAN;
	VAR state: SIGNED16;
	BEGIN
		state := User32.GetKeyState( key );  RETURN what IN SYSTEM.VAL( SET, state );
	END GetKeyState;

(* Common base handler for all variants of windows provided by this module. *)
	PROCEDURE DummyHandler( win: Window;  uMsg: SIGNED32;  wParam: User32.WParam;  lParam: User32.LParam ): User32.LResult;
	VAR res: User32.LResult; proc: User32.WndProc; hhWnd: ADDRESS;  ret: Kernel32.BOOL;
	BEGIN
		IF (uMsg = User32.WMDestroy) & ~(external IN win.state) THEN
			EXCL( win.state, update );  DEC( nWindows );
			IF (nWindows = 1) & (dummyWin # NIL ) THEN  (* only dummyWin left *)
				IF win = dummyWin THEN dummyWin := NIL END;
				IF res > 1 THEN RETURN 0 END
			ELSIF nWindows >= 1 THEN  (* other windows left *)
				RETURN 0
			END;
			User32.PostQuitMessage( 0 )
		ELSIF uMsg = User32.WMClose THEN
			EXCL( win.state, update );
			IF hook = win THEN HandleFocus( win, User32.WMKillFocus, 0 );  END;
			IF mouse = win THEN mouse := NIL END;
			IF root = win THEN root := NIL END;
			IF capture = win THEN ret := User32.ReleaseCapture();  capture := NIL END;
			IF Objects.oberonLoop = NIL THEN Modules.Shutdown( Modules.PowerDown );  END;
			(*		win.getDC := GetDC;  win.releaseDC := ReleaseDC; *)
			win.hDC := -1;   (* ??? *)
			IF ~(external IN win.state) THEN ret := User32.DestroyWindow( win.hWnd );  win.hWnd := Kernel32.NULL END
		ELSIF uMsg = WMCreateWindow THEN CreateHWND( SYSTEM.VAL( CreateStruct, lParam ) )
		ELSE proc := win.defWindowProc;  hhWnd := SYSTEM.VAL( ANY, win.hWnd );
			ASSERT ( proc # NIL );
			RETURN win.defWindowProc( win.hWnd, uMsg, wParam, lParam )
		END;
		RETURN 0
	END DummyHandler;

	PROCEDURE HandleFocus( win: Window;  uMsg: SIGNED32;  wParam: User32.WParam );
	BEGIN
		IF (uMsg = User32.WMSetFocus) & (hook # win) THEN
			Kernel32.Sleep( 0 );   (* ????????????????????? *)
		ELSIF uMsg = User32.WMKillFocus THEN

			IF wParam # Kernel32.NULL THEN
				IF wParam = win.hWnd THEN RETURN END;
			END;
		END
	END HandleFocus;

(** add a new display to the list of installed displays *)
	PROCEDURE Add( disp: Window;  noView: BOOLEAN );
	BEGIN
		Kernel32.EnterCriticalSection( moduleCS );  disp.link := root;  root := disp;  Kernel32.LeaveCriticalSection( moduleCS )
	END Add;

	PROCEDURE SetupWin( win: Window );
	VAR rect: User32.Rect;  ret: Kernel32.BOOL;
	BEGIN
		ret := User32.GetWindowRect( win.hWnd, win.windowRect );  ret := User32.GetClientRect( win.hWnd, rect );
		win.width := rect.right - rect.left;  win.height := rect.bottom - rect.top;  Add( win, FALSE );
		IF User32.GetFocus() = win.hWnd THEN HandleFocus( win, User32.WMSetFocus, 0 ) END;
	END SetupWin;

	PROCEDURE {WINAPI} DummyProc( hwnd: User32.HWND;  uMsg: SIGNED32;  wParam: User32.WParam;
															  lParam: User32.LParam ): User32.LResult;
	VAR win: Window;  create: CreateStruct;  ret: Kernel32.BOOL;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		Environment.RestoreActivity;
		win := SYSTEM.VAL( Window, User32.GetWindowLong( hwnd, GWLWindow ) );

		IF win # NIL THEN RETURN DummyHandler( win, uMsg, wParam, lParam )
		ELSIF uMsg = User32.WMCreate THEN
			SYSTEM.GET( lParam, create );  wParam := SYSTEM.VAL( User32.WParam, create );
			lParam := SYSTEM.VAL( User32.LParam, create.win );
			ret := User32.PostMessage( hwnd, WMSetup, wParam, lParam )
		ELSIF uMsg = WMSetup THEN
			win := SYSTEM.VAL( Window, lParam );  ret := User32.SetWindowLong( hwnd, GWLWindow, lParam );
			create := SYSTEM.VAL( CreateStruct, wParam );
			IF ~(dummy IN win.state) THEN SetupWin( win ) ELSE Add( win, TRUE ) END;
			IF ~(external IN win.state) THEN INC( nWindows ) END;
			BEGIN{EXCLUSIVE}
				create.finished := TRUE
			END;
		END;
		RETURN User32.DefWindowProc( hwnd, uMsg, wParam, lParam )
	END DummyProc;

	PROCEDURE ChangeCursor;
	VAR point: User32.Point;  ret: Kernel32.BOOL;
	BEGIN
		ret := User32.GetCursorPos( point );  ret := User32.SetCursor( hCurrentCursor );
		IF hCurrentCursor = Kernel32.NULL THEN
			REPEAT UNTIL User32.ShowCursor( Kernel32.False ) < 0
		ELSIF hCurrentCursor # Kernel32.NULL THEN
			REPEAT UNTIL User32.ShowCursor( Kernel32.True ) >= 0
		END;
		INC( point.x );  INC( point.y );  ret := User32.SetCursorPos( point.x, point.y );  DEC( point.x );  DEC( point.y );
		ret := User32.SetCursorPos( point.x, point.y )
	END ChangeCursor;

	PROCEDURE SetCursor( hCursor: User32.HCursor );
	BEGIN
		IF hCurrentCursor # hCursor THEN hCurrentCursor := hCursor;  ChangeCursor() END
	END SetCursor;

	PROCEDURE HandleMouse( win: Window;  uMsg: SIGNED32;  wParam: User32.WParam;  lParam: User32.LParam );
	VAR m: AosInputs.AbsMouseMsg;  oldx, oldy: SIGNED32;  keys: SET; ret: Kernel32.BOOL;
	BEGIN
		(* User32.SetCursor(hCurrentCursor);*)
		oldx := win.track.X;  oldy := win.track.Y;
		win.track.X := SIGNED32( lParam MOD ASH( 1, 16 ) ) - win.dx;
		win.track.Y := SIGNED32( (* win.height-*) ASH( lParam, -16 ) - 1 ) - win.dy;
		m.x := win.track.X;  m.y := win.track.Y;  m.z := win.track.Z;

		m.dx := 0;  m.dy := 0;  m.dz := 0;

		IF (m.x <= 0) THEN m.dx := win.track.dx - 2;
		ELSIF (m.x >= MIN( win.width, disp.width ) - 1) THEN m.x := disp.width - 1;  m.dx := win.track.dx + 2;
		END;

		IF (m.y <= 0) THEN m.dy := win.track.dy - 2;
		ELSIF (m.y >= MIN( win.height, disp.height ) - 1) THEN m.y := disp.height - 1;  m.dy := win.track.dy + 2;
		END;

		win.track.dx := m.dx;  win.track.dy := m.dy;

		IF (m.dx # 0) OR (m.dy # 0) THEN ret := User32.SetCursor( hAlternativeCursor );
		ELSE ret := User32.SetCursor( hCurrentCursor )
		END;

		keys := win.track.keys;
		CASE uMsg OF
		User32.WMLButtonDown:
				INCL( keys, ML )
		| User32.WMLButtonUp:
				EXCL( keys, ML )
		| User32.WMMButtonDown:
				INCL( keys, MM )
		| User32.WMMButtonUp:
				EXCL( keys, MM )
		| User32.WMRButtonDown:
				INCL( keys, MR )
		| User32.WMRButtonUp:
				EXCL( keys, MR )
		| User32.WMXButtonDown:
				INCL( keys, MX )
		| User32.WMXButtonUp:
				EXCL( keys, MX )
		| User32.WMMouseWheel:
				IF SIGNED32( ASH( wParam, -16 ) ) > 0 THEN m.dz := -1 ELSE m.dz := 1 END;
				m.x := oldx;  m.y := oldy;  win.track.X := oldx;  win.track.Y := oldy;
				(* strange: if wheel used, then coordinates are not realtive to windows -> use coordinates of last event, fof *)
		ELSE
		END;

		IF (keys # {}) & (capture # win) THEN ret := User32.SetCapture( win.hWnd );  capture := win
		ELSIF (keys = {}) & (capture # NIL ) THEN ret := User32.ReleaseCapture();  capture := NIL
		END;
		win.track.keys := keys;  m.keys := keys;

		AosInputs.mouse.Handle( m );
	END HandleMouse;

	(* Get the state of CTRL, ALT and SHIFT keys *)
	PROCEDURE GetKeyFlags(VAR flags : SET);
	BEGIN
		flags := {};
		IF GetKeyState( VKLShift, pressed ) THEN INCL( flags, AosInputs.LeftShift );  END;
		IF GetKeyState( VKRShift, pressed ) THEN INCL( flags, AosInputs.RightShift );  END;
		IF GetKeyState( VKLCtrl, pressed ) THEN INCL( flags, AosInputs.LeftCtrl ); END;
		IF GetKeyState( VKRCtrl, pressed ) THEN INCL( flags, AosInputs.RightCtrl ); END;
		IF GetKeyState( VKLMenu, pressed ) THEN INCL( flags, AosInputs.LeftAlt ); END;
		IF GetKeyState( VKRMenu, pressed ) THEN INCL( flags, AosInputs.RightAlt ); END;
		IF GetKeyState( VKLWin, pressed) THEN INCL(flags, AosInputs.LeftMeta); END;
		IF GetKeyState( VKRWin, pressed) THEN INCL(flags, AosInputs.RightMeta); END;
	END GetKeyFlags;

(* default handler for WMChar messages *)
	PROCEDURE HandleChar( win: Window;  wParam: User32.WParam;  lParam: User32.LParam );
	VAR ch: CHAR;  msg: AosInputs.KeyboardMsg;  key: SIGNED32;
	BEGIN
		GetChar( wParam, lParam, ch, key );
		GetKeyFlags(msg.flags);
		msg.ch := ch;  msg.keysym := key;
		(*
		KernelLog.String("HandleChar, ch, keysm="); KernelLog.Int(ORD(ch),10); KernelLog.Hex(msg.keysym,10); KernelLog.String(","); KernelLog.Bits(msg.flags,0,32); KernelLog.Ln;
		*)

		IF  (*ch # 0X*) TRUE THEN
			lParam := lParam MOD ASH( 1, 16 );
			WHILE lParam > 0 DO AosInputs.keyboard.Handle( msg );
				(* Displays.WriteChar(win, ch); *)
				DEC( lParam )
			END
		END
	END HandleChar;

(* default handler for WMKeyDown or WMKeyUp messages *)
	PROCEDURE HandleKey( win: Window;  wParam: User32.WParam;  lParam: User32.LParam );
	VAR ch: CHAR;  msg: AosInputs.KeyboardMsg;  key : SIGNED32; rect: User32.Rect;  ret: Kernel32.BOOL;
	BEGIN
		DecomposeKeyEvent( wParam, lParam, ch, key, FALSE );

		IF  (key = AosInputs.KsF8) & (maximized IN win.state) & ~fullscreen (*ALEX 2005.11.30*) THEN
			IF win.frame THEN
				ret :=
					User32.SetWindowLong( win.hWnd, User32.GWLStyle,
															 SYSTEM.VAL( SIGNED32, SYSTEM.VAL( SET, User32.GetWindowLong( win.hWnd, User32.GWLStyle ) ) + SYSTEM.VAL( SET, 12582912 (* WScaption *) ) ) );
				ret := User32.GetWindowRect( win.hWnd, rect );
				ret :=
					User32.SetWindowRgn( win.hWnd,
														    GDI32.CreateRectRgn( rect.left, rect.bottom, rect.right, rect.top (* +User32.GetSystemMetrics(User32.SMCYCaption) *) ),
														    1 );

			ELSE
				ret :=
					User32.SetWindowLong( win.hWnd, User32.GWLStyle,
															 SYSTEM.VAL( SIGNED32, SYSTEM.VAL( SET, User32.GetWindowLong( win.hWnd, User32.GWLStyle ) ) - SYSTEM.VAL( SET, 12582912 (* WScaption *) ) ) );

				ret := User32.GetWindowRect( win.hWnd, rect );
				ret :=
					User32.SetWindowRgn( win.hWnd,
														    GDI32.CreateRectRgn( rect.left, rect.bottom, rect.right, rect.top (* -User32.GetSystemMetrics(User32.SMCYCaption)*) ),
														    1 );

			END;
			win.frame := ~win.frame;  RETURN;
		END;

		GetKeyFlags(msg.flags);
		IF (msg.flags * AosInputs.Ctrl # {}) & (msg.flags * AosInputs.Alt = {}) & (VK0 <= wParam) & (wParam <= VK9) THEN
			(* Same behaviour as AOS *)
			ch := CHR(wParam); key := wParam;
		END;

		IF (AosInputs.LeftAlt IN msg.flags) & (AosInputs.LeftShift IN msg.flags) THEN
			INCL(win.track.flags, AosInputs.LeftMeta);
		END;

		CASE key OF
		| AosInputs.KsMenu:
				INCL( win.track.flags, AosInputs.LeftMeta );
		| AosInputs.KsF9:
				INCL( win.track.flags, AosInputs.RightMeta );
		| AosInputs.KsF1:
				INCL( win.track.flags, AosInputs.LeftMeta );
		ELSE
		END;
		msg.flags := msg.flags + win.track.flags;  msg.ch := ch;  msg.keysym := key;

		(* ch := TranslateKey(wParam, FALSE);  *)
		(*IF ch # 0X THEN*)
		lParam := lParam MOD ASH( 1, 16 );
		IF (msg.keysym # 0) OR (msg.ch # 0X)  THEN
			(*
		KernelLog.String("HandleKey, ch, keysm="); KernelLog.Int(ORD(ch),10); KernelLog.Hex(msg.keysym,10); KernelLog.Bits(msg.flags,0,32); KernelLog.Ln;
		*)

			KeyHandled := TRUE;
			WHILE lParam > 0 DO AosInputs.keyboard.Handle( msg );
				(*Displays.WriteChar(win, ch); *) DEC( lParam )
			END;

		ELSE KeyHandled := FALSE;
		END;
	END HandleKey;

	(* default handler for WMKeyDown or WMKeyUp messages *)
	PROCEDURE HandleKeyUp( win: Window;  wParam: User32.WParam;  lParam: User32.LParam );
	VAR ch: CHAR;  msg: AosInputs.KeyboardMsg; key : SIGNED32;
	BEGIN
		DecomposeKeyEvent( wParam, lParam, ch, key, TRUE );
		GetKeyFlags(msg.flags);

		IF ~((AosInputs.LeftAlt IN msg.flags) & (AosInputs.LeftShift IN msg.flags)) THEN
			EXCL(win.track.flags, AosInputs.LeftMeta);
		END;

		CASE key OF
		| AosInputs.KsMenu:
				EXCL( win.track.flags, AosInputs.LeftMeta );
		| AosInputs.KsF9:
				EXCL( win.track.flags, AosInputs.RightMeta );
		| AosInputs.KsF1:
				EXCL( win.track.flags, AosInputs.LeftMeta );
		ELSE
		END;
		msg.flags := msg.flags + win.track.flags + {AosInputs.Release};  msg.ch := ch;  msg.keysym := key;

		IF dbgDisableReleaseMsg THEN msg.ch := 0X;  msg.keysym := AosInputs.KsNil; END;

		AosInputs.keyboard.Handle( msg );
	END HandleKeyUp;

	PROCEDURE SetDocRect( win: Window;  resize: BOOLEAN );
	VAR rect: User32.Rect;  ret: Kernel32.BOOL;
	BEGIN
		IF ~(minimized IN win.state) THEN
			IF resize THEN ret := User32.GetWindowRect( win.hWnd, win.windowRect )
			ELSE
				ret := User32.GetWindowRect( win.hWnd, rect );
				win.windowRect.right := rect.left + (win.windowRect.right - win.windowRect.left);
				win.windowRect.left := rect.left;
				win.windowRect.bottom := rect.top + (win.windowRect.bottom - win.windowRect.top);
				win.windowRect.top := rect.top
			END;
		END;
	END SetDocRect;

	PROCEDURE UpdateDisplay( win: Window;  id: SIGNED32;  lParam: User32.LParam;  wParam: User32.WParam );
	VAR x, y, w, h, dx, dy, bw, bh: SIGNED32;  hOldBr: GDI32.HBrush;  ret: Kernel32.BOOL;
	BEGIN
		IF ~(minimized IN win.state) THEN
			IF id = resize THEN win.width := lParam MOD ASH( 1, 16 );  win.height := lParam DIV ASH( 1, 16 );  SetDocRect( win, TRUE ) END;
			ret := User32.ValidateRect( win.hWnd, NIL );
			IF win.hDC = 0 THEN GetDC( win );  END;

			IF win.hBrush = 0 THEN
				win.hBrush := GDI32.CreateSolidBrush( GDI32.RGB( 100, 0, 0 ) );
				hOldBr := GDI32.SelectObject( win.hDC, win.hBrush );
			END;

			w := win.width;  h := win.height;
			IF disp.width < w THEN  (* fill rest with color *)
				dx := (w - disp.width) DIV 2;  bw := disp.width;  ret := GDI32.PatBlt( win.hDC, 0, 0, dx, h, GDI32.PatCopy );
				ret := GDI32.PatBlt( win.hDC, w - dx, 0, dx, h, GDI32.PatCopy );
			ELSE bw := w;
			END;

			IF disp.height < h THEN  (* fill rest with color *)
				dy := (h - disp.height) DIV 2;  bh := disp.height;  ret := GDI32.PatBlt( win.hDC, 0, 0, w, dy, GDI32.PatCopy );
				ret := GDI32.PatBlt( win.hDC, 0, h - dy, w, dy, GDI32.PatCopy );
			ELSE bh := h;
			END;

			hOldBr := GDI32.SelectObject( win.hDC, hOldBr );

			(* IF win.fullScreen THEN dy := dy- User32.GetSystemMetrics(User32.SMCYCaption); END; *)

			win.dx := dx;  win.dy := dy;  ToWindow( win, x, y, bw, bh, dx, dy );

		END
	END UpdateDisplay;

	PROCEDURE FromMemory( win: Window;  VAR buf: ARRAY OF CHAR;  ofs, stride, x, y, w, h: SIZE );
	END FromMemory;

	PROCEDURE ToMemory( win: Window;  VAR buf: ARRAY OF CHAR;  ofs, stride, x, y, w, h: SIZE );
	VAR adr: ADDRESS;  hDC: User32.HDC;  ret: Kernel32.BOOL;
	BEGIN
		hDC := win.bmphdc;   (*  hDC := win.hDC; (* writes to screen*) *)
		bmi.info.bmiHeader.biWidth := SIGNED32(stride) DIV format (* w *) ;  bmi.info.bmiHeader.biHeight := -SIGNED32(h);   (* top-down *)
		adr := ADDRESSOF( buf[ofs] );

		ret :=
			GDI32.SetDIBitsToDevice( hDC, SIGNED32(x), SIGNED32(y), SIGNED32(w), SIGNED32(h), 0, 0, 0, SIGNED32(h), adr, SYSTEM.VAL( GDI32.BitmapInfo, bmi.info ),
													   GDI32.DIBPalColors )
		(*	ELSE
			bmi.info.bmiHeader.biHeight := 1;

			WHILE h > 0 DO
				ret :=
					GDI32.SetDIBitsToDevice( hDC, x, y, w, 1, 0, 0, 0, 1, adr, SYSTEM.VAL( GDI32.BitmapInfo, bmi.info ),
															   GDI32.DIBPalColors );
				INC( adr, stride );  DEC( h );  INC( y )
			END;

		END;
		*)
	END ToMemory;

	PROCEDURE ToWindow*( win: Window;  x, y, w, h: SIZE;  dx, dy: SIGNED32 );
	VAR ret: Kernel32.BOOL;
	BEGIN
		IF traceDisplay THEN
			ret := GDI32.BitBlt( win.hDC (* = destination *) , SIGNED32(x) + dx, SIGNED32(y) + dy, SIGNED32(w), SIGNED32(h), win.bmphdc (* source *) , SIGNED32(x), SIGNED32(y), GDI32.NotSrcCopy );
			Kernel32.Sleep(50);
		END;
		ret := GDI32.BitBlt( win.hDC (* = destination *) , SIGNED32(x) + dx, SIGNED32(y) + dy, SIGNED32(w), SIGNED32(h), win.bmphdc (* source *) , SIGNED32(x), SIGNED32(y), GDI32.SrcCopy );
	END ToWindow;

	PROCEDURE GetMinMaxInfo( win: Window;  lParam: User32.LParam ): BOOLEAN;
	VAR mm: User32.MinMaxInfo;
	BEGIN
		SYSTEM.MOVE( lParam, ADDRESSOF( mm ), SIZEOF( User32.MinMaxInfo ) );  mm.ptMaxSize.x := disp.width;
		mm.ptMaxSize.y := disp.height;  mm.ptMaxTrackSize := mm.ptMaxSize;  RETURN TRUE;
	END GetMinMaxInfo;

	PROCEDURE Minimize( win: Window );
	BEGIN
		INCL( win.state, minimized );  EXCL( win.state, maximized );
	END Minimize;

	PROCEDURE Maximize( win: Window );
	BEGIN
		EXCL( win.state, minimized );  INCL( win.state, maximized );
	END Maximize;

	PROCEDURE Restore( win: Window );
	BEGIN
		EXCL( win.state, minimized );  EXCL( win.state, maximized );
	END Restore;

	PROCEDURE PosChanging( win: Window;  lParam: User32.LParam );
	VAR pos: User32.WindowPos;
	BEGIN
		SYSTEM.MOVE( lParam, ADDRESSOF( pos ), SIZEOF( User32.WindowPos ) );
		IF ~(User32.SWPNoMove IN pos.flags) THEN
			IF (pos.x < -disp.width) & (pos.y < -disp.height) THEN Minimize( win )
			ELSIF (pos.x >= 0) & (pos.y >= 0) THEN Restore( win )
			END
		END;
		(* Viewers.sorted := FALSE*)
	END PosChanging;

(** Common base handler for all visual windows (document or control) provided by this module. *)
	PROCEDURE WindowHandler( win: Window;  uMsg: SIGNED32;  wParam: User32.WParam;
													  lParam: User32.LParam ): User32.LResult;

	VAR handled: BOOLEAN; ret: Kernel32.BOOL;

		closer: OBJECT (* to call a close request in an A2 thread, otherwise finalization does not work etc. *)
		BEGIN{ACTIVE}
			Modules.Shutdown(Modules.PowerDown);
			User32.PostQuitMessage(0);
		END;
	BEGIN
		IF update IN win.state THEN
			handled := TRUE;
			IF uMsg < User32.WMKeyFirst THEN
				CASE uMsg OF
				User32.WMMove:
						SetDocRect( win, FALSE )
				| User32.WMSize:
						IF wParam = User32.SizeMaximized THEN Maximize( win );  UpdateDisplay( win, resize, lParam, wParam );
						ELSIF wParam = User32.SizeMinimized THEN Minimize( win );
						ELSIF wParam = User32.SizeRestored THEN Restore( win );  UpdateDisplay( win, resize, lParam, wParam );
						END;
				| User32.WMPaint:
						UpdateDisplay( win, redraw, lParam, wParam );
				| User32.WMMouseActivate:
						IF (hook = NIL ) OR ((lParam MOD 65536) # (User32.HTClient)) THEN ret := User32.SetFocus( win.hWnd ) END;
						RETURN User32.MANoActivate
				| User32.WMGetMinMaxInfo:
						handled := GetMinMaxInfo( win, lParam )
				| User32.WMWindowPosChanging:
						handled := GetMinMaxInfo( win, lParam );  PosChanging( win, lParam );  handled := FALSE
				| User32.WMSetFocus, User32.WMKillFocus:
						HandleFocus( win, uMsg, wParam )
				| User32.WMClose:
						IF closeRequests < 3 THEN
							NEW(closer); INC(closeRequests);
						ELSE
							Modules.Shutdown(Modules.PowerDown);
							User32.PostQuitMessage( 0 ) (*ALEX 2005.12.13 added this line*)
						END;
				ELSE handled := FALSE
				END
			ELSIF (User32.WMKeyFirst <= uMsg) & (uMsg <= User32.WMKeyLast) THEN
				CASE uMsg OF
				| User32.WMKeyDown:
						HandleKey( win, wParam, lParam);
				| User32.WMKeyUp:
						HandleKeyUp( win, wParam, lParam );
				| User32.WMChar:
						IF ~KeyHandled THEN
							HandleChar( win, wParam, lParam )
						END;
				| User32.WMSysKeyDown: HandleKey(win, wParam, lParam);
				| User32.WMSysKeyUp: HandleKeyUp(win, wParam, lParam);
				ELSE handled := FALSE;
				END;
			ELSIF (User32.WMMouseFirst <= uMsg) & (uMsg <= User32.WMMouseLast) THEN
				HandleMouse( win, uMsg, wParam, lParam )
			ELSE handled := FALSE
			END
		ELSE handled := FALSE
		END;
		IF ~handled THEN RETURN DummyHandler( win, uMsg, wParam, lParam ) ELSE RETURN 0 END
	END WindowHandler;

	PROCEDURE {WINAPI} WindowProc( hwnd: User32.HWND;  uMsg: SIGNED32;  wParam: User32.WParam;
															    lParam: User32.LParam ): User32.LResult;
	VAR win {UNTRACED}: Window;  dbh {UNTRACED}: DEV_BROADCAST_HDRP; dbv  {UNTRACED}: DEV_BROADCAST_VOLUMEP; i: SIGNED32;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		Environment.RestoreActivity;
		IF uMsg = WM_DEVICECHANGE THEN
			IF wParam = DBT_DEVICEARRIVAL THEN
				dbh := SYSTEM.VAL(DEV_BROADCAST_HDRP,lParam);
				IF dbh.dbch_devicetype = DBT_DEVTYP_VOLUME THEN
					dbv := SYSTEM.VAL(DEV_BROADCAST_VOLUMEP,lParam);
					WinFS.DeviceNotification(wParam,dbv.dbcv_unitmask);
				END;
			ELSIF wParam = DBT_DEVICEREMOVECOMPLETE THEN
				dbh := SYSTEM.VAL(DEV_BROADCAST_HDRP,lParam);
				IF dbh.dbch_devicetype = DBT_DEVTYP_VOLUME THEN
					dbv := SYSTEM.VAL(DEV_BROADCAST_VOLUMEP,lParam);
					WinFS.DeviceNotification(wParam,dbv.dbcv_unitmask);
				END;
			END;
		END;

		win := SYSTEM.VAL( Window, User32.GetWindowLong( hwnd, GWLWindow ) );
		IF win # NIL THEN RETURN WindowHandler( win, uMsg, wParam, lParam )
		ELSE RETURN DummyProc( hwnd, uMsg, wParam, lParam )
		END
	END WindowProc;
(** Implementation of GetDC for all visual windows (document or control) provided by this module. *)
	PROCEDURE GetDC( win: Window );
	VAR oldhbm: GDI32.HBitmap;  ret: SIGNED32;
	BEGIN
		IF win.hWnd # Kernel32.NULL THEN
			win.hDC := User32.GetDC( win.hWnd );

			IF letWindowsHandleTheBuffer THEN
				win.bmp := GDI32.CreateCompatibleBitmap( win.hDC, disp.width, disp.height );
				win.bmphdc := GDI32.CreateCompatibleDC( win.hDC );  oldhbm := GDI32.SelectObject( win.bmphdc, win.bmp );
				NEW( win.pal, 1024 );  ret := GDI32.GetSystemPaletteEntries( win.hDC, 0, 1024, win.pal^ )
			ELSE win.bmphdc := GDI32.CreateCompatibleDC( win.hDC );

				win.bmadr := 0;

				bmi.info.bmiHeader.biSizeImage := disp.width * disp.height * format;  bmi.info.bmiHeader.biWidth := disp.width;
				bmi.info.bmiHeader.biHeight := -disp.height;   (* top-down *)

				win.bmp :=
					GDI32.CreateDIBSection( win.hDC, SYSTEM.VAL( GDI32.BitmapInfo, bmi.info ), GDI32.DIBRGBColors,
															  win.bmadr, 0, 0 );
				ASSERT ( win.bmadr # 0 );
				oldhbm := GDI32.SelectObject( win.bmphdc, win.bmp );


				(*oldhbm := GDI32.SelectObject( win.bmphdc, win.bmp );  *)
				NEW( win.pal, 1024 );  ret := GDI32.GetSystemPaletteEntries( win.hDC, 0, 1024, win.pal^ )
			END;

		ELSE win.hDC := Kernel32.NULL
		END;
		(*
	depth := GDI32.GetDeviceCaps(win.hDC, GDI32.BitsPixel);
	*)
		(*	IF disp = root THEN 	Msg2(TRUE,"RegisterHotkey:",User32.RegisterHotKey(disp.hWnd,100,MODWin,65),0);  END;  *)

	END GetDC;


(** Install a externaly created window in the display space.
		You must already have set up the fields:
		handle, getDC, releaseDC, hWnd and defWindowProc *)
	PROCEDURE InstallW( win: Window;  ctrl: BOOLEAN );
	VAR h: User32.HWND;
	BEGIN
		INCL( win.state, external );
		IF ctrl THEN INCL( win.state, control ) END;
		h := win.hWnd;
		WHILE h # Kernel32.NULL DO win.hWndParent := h;  h := User32.GetParent( h ) END;
		SetupWin( win )
	END InstallW;

(** Initialize the fields of a new Window instance with default values.
		You must call this procedure whenever you alloc a new Window instance
		or an extension of it. *)
	PROCEDURE Init( win: Window );
	BEGIN
		(*
		Viewers.InitWindow(win);
		win.viewer := NIL;
		win.getDC := Displays.GetDC; win.releaseDC := Displays.ReleaseDC;
		*)
		win.defWindowProc := User32.DefWindowProc;  win.windowRect.left := 0;  win.windowRect.right := 0;
		win.windowRect.top := 0;  win.windowRect.bottom := 0;  win.state := {update}
	END Init;

	PROCEDURE RegisterClasses;
	VAR str: ARRAY 32 OF CHAR;
		ret: Kernel32.ATOM;
	BEGIN
		dummyClass.cbSize := SIZEOF( User32.WndClassEx );  dummyClass.style := {};  dummyClass.lpfnWndProc := DummyProc;
		dummyClass.cbClsExtra := 0;  dummyClass.cbWndExtra := 4;  dummyClass.hInstance := Kernel32.hInstance;
		dummyClass.hIcon := Kernel32.NULL;  dummyClass.hIconSm := Kernel32.NULL;  dummyClass.hCursor := Kernel32.NULL;
		dummyClass.hbrBackground := Kernel32.NULL;  dummyClass.lpszMenuName := Kernel32.NULL;
		dummyClass.lpszClassName := SYSTEM.VAL( Kernel32.LPSTR, ADDRESSOF( dummyClassName ) );
		ret := User32.RegisterClassEx( dummyClass );

		windowClass.cbSize := SIZEOF( User32.WndClassEx );
		windowClass.style := {7};   (* Cs_parentdc: SIGNED16 is 128  = 2^7 *)
		windowClass.lpfnWndProc := WindowProc;  windowClass.cbClsExtra := 0;  windowClass.cbWndExtra := 4;
		windowClass.hInstance := Kernel32.hInstance;  str := "Console";  windowClass.hIcon := User32.LoadIcon( Kernel32.hInstance, str );
		str := "Console.Small";  windowClass.hIconSm := User32.LoadIcon( Kernel32.hInstance, str );  windowClass.hCursor := Kernel32.NULL;
		windowClass.hbrBackground := Kernel32.NULL;  windowClass.lpszMenuName := Kernel32.NULL;
		windowClass.lpszClassName := SYSTEM.VAL( Kernel32.LPSTR, ADDRESSOF( windowClassName ) );
		ret := User32.RegisterClassEx( windowClass )
	END RegisterClasses;

	PROCEDURE UnregisterClasses;
	VAR ret: Kernel32.BOOL;
	BEGIN
		ret := User32.UnregisterClass( dummyClassName, Kernel32.hInstance );
		ret := User32.UnregisterClass( windowClassName, Kernel32.hInstance )
	END UnregisterClasses;

	PROCEDURE FirstWindow( ): Window;
	VAR disp: Window;  w: Window;
	BEGIN
		w := NIL;  disp := root;
		WHILE (w = NIL ) & (disp # NIL ) DO
			IF disp IS Window THEN
				w := disp( Window );
				IF (w.hWnd = Kernel32.NULL) OR (~(update IN w.state) & ~(dummy IN w.state)) OR (external IN w.state) THEN
					w := NIL
				END
			END;
			disp := disp.link
		END;
		RETURN w
	END FirstWindow;

	PROCEDURE {WINAPI} WindowThread (create {UNTRACED}: ANY): SIGNED32;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		Kernel32.InstallExceptionHandler;
		Activities.CallVirtual (MessageLoop, create, create(CreateStruct).win.processor);
		RETURN 0;
	END WindowThread;

	PROCEDURE MessageLoop (c: ADDRESS);
	VAR activity: Activities.Activity; create: CreateStruct;
	VAR msg: User32.Msg;  i: SIGNED32; mode: SIGNED32;
	BEGIN
		create := SYSTEM.VAL (CreateStruct, c);
		KernelLog.String( "Display: Initialize message dispatcher..." );  KernelLog.Ln;
		RegisterClasses();  CreateHWND( create );  create := NIL;
		KernelLog.String( "Display: Start message dispatching" ); KernelLog.Ln;
		REPEAT
			i := User32.GetMessage( msg, 0, 0, 0 );
			IF i = 0 THEN
			ELSIF i # -1 THEN
				IF ( msg.message = User32.WMKeyDown ) THEN
					(* Translate virtual key code  to character. This generates a WMChar message if translation succeeds. Since
					AOS doesn't allow ALT-Printable-Keys combinations, we don't translate User32.WMSysKeyDown messages
					that would generate WMSysChar messages *)
					IGNORE User32.TranslateMessage( msg );
				END;
				IGNORE User32.DispatchMessage( msg )
			END;
		UNTIL (i = 0) OR (Environment.status # 0);
		UnregisterClasses();
		Counters.Dec (Activities.awaiting);
	END MessageLoop;

	PROCEDURE CreateWin( create: CreateStruct );
	VAR  hThread: Kernel32.HANDLE; theWin: Window; ret: Kernel32.BOOL;
	BEGIN
		IF nWindows <= 0 THEN
			Counters.Inc (Activities.awaiting);
			create.win.processor := Activities.CreateVirtualProcessor ();
			IGNORE Kernel32.CreateThread (NIL, 0, WindowThread, create, {}, NIL);
			root := create.win;
		ELSE
			theWin := FirstWindow();
			ret := User32.PostMessage( theWin.hWnd, WMCreateWindow, 0, SYSTEM.VAL( User32.LParam, create ) )
		END;
		BEGIN {EXCLUSIVE}
			AWAIT(create.finished)
		END;
	END CreateWin;

	PROCEDURE {WINAPI} ControlWindowProc( hwnd: User32.HWND;  uMsg: SIGNED32;  wParam: User32.WParam;
																		    lParam: User32.LParam ): User32.LResult;
	VAR win: Window;  ret: Kernel32.BOOL;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		Environment.RestoreActivity;
		win := SYSTEM.VAL( Window, User32.GetWindowLong( hwnd, GWLWindow ) );
		IF win # NIL THEN RETURN WindowHandler( win, uMsg, wParam, lParam )
		ELSIF uMsg = User32.WMCreate THEN
			SYSTEM.GET( lParam, win );  win.hWnd := hwnd;
			ret := User32.SetWindowLong( hwnd, GWLWindow, SYSTEM.VAL( SIGNED32, win ) );  InstallW( win, TRUE );  RETURN 0
		ELSE RETURN DummyProc(hwnd,uMsg,wParam,lParam);
		END
	END ControlWindowProc;

	PROCEDURE {WINAPI} UnregisterControlWinClass;
	VAR ret: Kernel32.BOOL;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		IF aControlWinClass # Kernel32.NULL THEN
			ret := User32.UnregisterClass( controlClassName, Kernel32.hInstance );  aControlWinClass := Kernel32.NULL
		END
	END UnregisterControlWinClass;

	PROCEDURE InitMod;
	VAR  (*  path: FileDir.FileName;*) i: SIGNED32;
		str: ARRAY 32 OF CHAR;
	BEGIN
		fixedFrameX := User32.GetSystemMetrics( User32.SMCXFixedFrame );
		fixedFrameY := User32.GetSystemMetrics( User32.SMCYFixedFrame );
		frameX := User32.GetSystemMetrics( User32.SMCXFrame );  frameY := User32.GetSystemMetrics( User32.SMCYFrame );
		captionY := User32.GetSystemMetrics( User32.SMCYCaption );
		menuY := User32.GetSystemMetrics( User32.SMCYMenu );  capture := NIL;  hook := NIL;  mouse := NIL;
		(* winMain := NIL; *) nWindows := 0;  str := "PointCircle";
		hCurrentCursor := User32.LoadCursor( Kernel32.hInstance, str );   (* Kernel32.NULL;  *);
		str := "Cross";  hAlternativeCursor := User32.LoadCursor( Kernel32.hInstance, str );  dummyClassName := "Aos.Dummy.Class";
		windowClassName := "Aos.Window.Class";  controlClassName := "Aos.ControlWindow.Class";  aControlWinClass := Kernel32.NULL;  kioskmode := FALSE;
		Kernel32.InitializeCriticalSection( moduleCS );
		(*
		nAccel := 0; Registry.OberonPath("HotKeys", path);
		Registry.EnumerateKeyValue(Registry.CurrentUser, path, AddRegHotKeys); (* done in Oberon.Mod, needs configuration Oberon.Text *)
		*)
		dummyWin := NIL;
		FOR i := 0 TO 255 DO ISOToOberon[i] := CHR( i );  END;
		ISOToOberon[146] := CHR( 39 );  ISOToOberon[160] := CHR( 32 );  ISOToOberon[162] := CHR( 99 );
		ISOToOberon[166] := CHR( 124 );  ISOToOberon[168] := CHR( 34 );  ISOToOberon[169] := CHR( 99 );  ISOToOberon[170] := CHR( 97 );
		ISOToOberon[171] := CHR( 60 );  ISOToOberon[173] := CHR( 45 );  ISOToOberon[174] := CHR( 114 );  ISOToOberon[175] := CHR( 45 );
		ISOToOberon[176] := CHR( 111 );  ISOToOberon[178] := CHR( 50 );  ISOToOberon[179] := CHR( 51 );  ISOToOberon[180] := CHR( 39 );
		ISOToOberon[183] := CHR( 46 );  ISOToOberon[185] := CHR( 49 );  ISOToOberon[186] := CHR( 48 );  ISOToOberon[187] := CHR( 62 );
		ISOToOberon[192] := CHR( 65 );  ISOToOberon[193] := CHR( 65 );  ISOToOberon[194] := CHR( 65 );  ISOToOberon[195] := CHR( 65 );
		ISOToOberon[196] := CHR( 128 );  ISOToOberon[197] := CHR( 65 );  ISOToOberon[198] := CHR( 65 );  ISOToOberon[199] := CHR( 67 );
		ISOToOberon[200] := CHR( 69 );  ISOToOberon[201] := CHR( 69 );  ISOToOberon[202] := CHR( 69 );  ISOToOberon[203] := CHR( 69 );
		ISOToOberon[204] := CHR( 73 );  ISOToOberon[205] := CHR( 73 );  ISOToOberon[206] := CHR( 73 );  ISOToOberon[207] := CHR( 73 );
		ISOToOberon[208] := CHR( 68 );  ISOToOberon[209] := CHR( 78 );  ISOToOberon[210] := CHR( 79 );  ISOToOberon[211] := CHR( 79 );
		ISOToOberon[212] := CHR( 79 );  ISOToOberon[213] := CHR( 79 );  ISOToOberon[214] := CHR( 129 );  ISOToOberon[215] := CHR( 42 );
		ISOToOberon[216] := CHR( 79 );  ISOToOberon[217] := CHR( 85 );  ISOToOberon[218] := CHR( 85 );  ISOToOberon[219] := CHR( 85 );
		ISOToOberon[220] := CHR( 130 );  ISOToOberon[221] := CHR( 89 );  ISOToOberon[222] := CHR( 80 );
		ISOToOberon[223] := CHR( 150 );  ISOToOberon[224] := CHR( 139 );  ISOToOberon[225] := CHR( 148 );
		ISOToOberon[226] := CHR( 134 );  ISOToOberon[227] := CHR( 97 );  ISOToOberon[228] := CHR( 131 );
		ISOToOberon[229] := CHR( 97 );  ISOToOberon[230] := CHR( 97 );  ISOToOberon[231] := CHR( 147 );
		ISOToOberon[232] := CHR( 140 );  ISOToOberon[233] := CHR( 144 );  ISOToOberon[234] := CHR( 135 );
		ISOToOberon[235] := CHR( 145 );  ISOToOberon[236] := CHR( 141 );  ISOToOberon[237] := CHR( 105 );
		ISOToOberon[238] := CHR( 136 );  ISOToOberon[239] := CHR( 146 );  ISOToOberon[240] := CHR( 100 );
		ISOToOberon[241] := CHR( 149 );  ISOToOberon[242] := CHR( 142 );  ISOToOberon[243] := CHR( 111 );
		ISOToOberon[244] := CHR( 137 );  ISOToOberon[245] := CHR( 111 );  ISOToOberon[246] := CHR( 132 );
		ISOToOberon[248] := CHR( 111 );  ISOToOberon[249] := CHR( 143 );  ISOToOberon[250] := CHR( 117 );
		ISOToOberon[251] := CHR( 138 );  ISOToOberon[252] := CHR( 133 );  ISOToOberon[253] := CHR( 121 );
		ISOToOberon[254] := CHR( 112 );  ISOToOberon[255] := CHR( 121 );

		InitBMI;
		COPY(WindowTitle, windowTitle);
	END InitMod;

	PROCEDURE DisableCursor*;
	BEGIN
		hCurrentCursor := Kernel32.NULL
	END DisableCursor;


	PROCEDURE InitBMI;
	BEGIN
		bmi.info.bmiHeader.biSize := SIZEOF( GDI32.BitmapInfoHeader );  bmi.info.bmiHeader.biWidth := 0;
		bmi.info.bmiHeader.biHeight := 0;  bmi.info.bmiHeader.biPlanes := 1;  bmi.info.bmiHeader.biBitCount := (format * 8);
		bmi.info.bmiHeader.biCompression := GDI32.BIRGB;  bmi.info.bmiHeader.biSizeImage := 0;
		bmi.info.bmiHeader.biXPelsPerMeter := 0;  bmi.info.bmiHeader.biYPelsPerMeter := 0;
		IF format > 1 THEN bmi.info.bmiHeader.biClrUsed := 0;  bmi.info.bmiHeader.biClrImportant := 0
		ELSE bmi.info.bmiHeader.biClrUsed := 256;  bmi.info.bmiHeader.biClrImportant := 256;
		END;
		IF format = Displays.color565 THEN
			bmi.info.bmiHeader.biCompression := 3;   (*: BIBITFIELDS *)
			bmi.info.colors[0] := 15 * 16 * 16 * 16 + 8 * 16 * 16;  bmi.info.colors[1] := 14 * 16 + 7 * 16 * 16;
			bmi.info.colors[2] := 15 + 16;
		END;
	END InitBMI;

	PROCEDURE Shutdown;
	VAR disp: Window;
	BEGIN
		(*
		disp := Displays.root;
		WHILE disp # NIL DO
			IF disp IS Window THEN
				WITH disp: Window DO
					IF disp.hWnd # Kernel32.NULL THEN
						User32.PostMessage(disp.hWnd, User32.WMClose, 0, 0)
					END
				END
			END;
			disp := disp.link
		END;
		IF dummyWin # NIL THEN
			User32.PostMessage(dummyWin.hWnd, User32.WMClose, 0, 0)
		END;
		*)
		UnregisterControlWinClass()
	END Shutdown;

	PROCEDURE DoInstall( w, h, left, top: SIGNED32 );
	VAR ts: ARRAY 16 OF CHAR;
		res: INTEGER;  create: CreateStruct;  win: Window;  hMenu: User32.HMenu;  x, y: SIGNED32;
	VAR border: SIGNED32;  rect: User32.Rect;   (*ALEX 2005.11.30*)

		hDC: User32.HDC;

	CONST SMCYMaximized = 62;  SMCXMaximized = 61;
	BEGIN
		IF disp = NIL THEN
			NEW( win );  Init( win );  hMenu := Kernel32.NULL;  RegisterClasses();  NEW( create );  create.win := win;
			create.hMenu := hMenu;
			IF ~fullscreen THEN
				create.style :=
					{User32.WSMinimizeBox, User32.WSMaximizeBox, User32.WSSysMenu, User32.WSVisible, User32.WSBorder, User32.WSThickFrame};
				x := User32.CWUseDefault;  y := User32.CWUseDefault;  COPY( windowClassName, create.className );  border := 0;
				IF h = 0 THEN
					h := User32.GetSystemMetrics( SMCYMaximized ) - captionY - 2 * frameY;
					IF w = 0 THEN
						w := User32.GetSystemMetrics( SMCXMaximized ) - 2 * frameX;
						create.style := create.style + {User32.WSMaximize};
					END;
				ELSE
					h := h - captionY - 2 * frameY;
					IF (w # 0) THEN
						w := w - 2 * frameX;
					END;
				END;
				IF w = 0 THEN w := User32.GetSystemMetrics( SMCXMaximized ) - 2 * frameX;  END;
				create.w := w + 2 * frameX;  create.h := h  + captionY + 2*frameY;
				create.x := x;  create.y := y;

				IF (left # 0) THEN
					create.x := left; create.y := top;
				END;
			ELSE
				create.style := {};  x := User32.CWUseDefault;  y := User32.CWUseDefault;
				COPY( windowClassName, create.className );  border := 0;  h := User32.GetSystemMetrics( SMCYScreen );
				w := User32.GetSystemMetrics( SMCXScreen );  create.style := create.style + {User32.WSMaximize};
				create.x := x;  create.y := y;  create.w := w;  create.h := h + captionY;
			END;

			NEW( disp );  disp.width := w;  disp.height := h;  disp.format := format;  disp.desc := "Display driver (";  Strings.IntToStr( disp.width, ts );
			Strings.Append( disp.desc, ts );  Strings.Append( disp.desc, "x" );  Strings.IntToStr( disp.height, ts );
			Strings.Append( disp.desc, ts );  Strings.Append( disp.desc, "x" );  Strings.IntToStr( disp.format, ts );
			Strings.Append( disp.desc, ts );  Strings.Append( disp.desc, ")" );  create.finished := FALSE;
			CreateWin( create );
			IGNORE User32.SetWindowText(root.hWnd, windowTitle);
			IGNORE User32.BringWindowToTop( root.hWnd );
			IGNORE User32.SetForegroundWindow( root.hWnd );
			Displays.registry.Add( disp, res );
			ASSERT ( res = 0 );
			IF fullscreen THEN
				res :=
					User32.SetWindowLong( win.hWnd, User32.GWLStyle,
															 SYSTEM.VAL( SIGNED32, SYSTEM.VAL( SET, User32.GetWindowLong( win.hWnd, User32.GWLStyle ) ) - SYSTEM.VAL( SET, 12582912 (* WScaption *) ) ) );

				res := User32.GetWindowRect( win.hWnd, rect );
				res := User32.SetWindowRgn( win.hWnd, GDI32.CreateRectRgn( rect.left, rect.bottom, rect.right, rect.top ), 1 );
				win.frame := TRUE
			END

		ELSIF root = NIL THEN w := disp.width;  h := disp.height;

			NEW( win );  Init( win );  hMenu := Kernel32.NULL;  RegisterClasses();  NEW( create );  create.win := win;
			create.hMenu := hMenu;
			create.style :=
				{User32.WSMinimizeBox, User32.WSMaximizeBox,  User32.WSSysMenu,  User32.WSVisible, User32.WSBorder, User32.WSThickFrame};
			x := User32.CWUseDefault;  y := User32.CWUseDefault;  COPY( windowClassName, create.className );  create.x := x;
			create.y := y;  create.w := w;  create.h := h + User32.GetSystemMetrics( User32.SMCYCaption );
			create.finished := FALSE;
			CreateWin( create );
			IGNORE User32.SetWindowText(root.hWnd, windowTitle);
			IGNORE User32.BringWindowToTop( root.hWnd );  disp.Update;
			IGNORE User32.SetForegroundWindow( root.hWnd );
		ELSE
			KernelLog.Enter;  KernelLog.String( "Display: Display already open, window still open" );  KernelLog.Exit;
			IF minimized IN root.state THEN IGNORE User32.ShowWindow( root.hWnd, User32.SWRestore );  END;

			IGNORE User32.BringWindowToTop( root.hWnd );
			IGNORE User32.SetForegroundWindow( root.hWnd );
		END;

		hDC := User32.GetDC(0);
		disp.unit := GDI32.GetDeviceCaps(hDC,GDI32.LogPixelsX);
		disp.unit := ENTIER((36000.0*disp.unit)/25.4);
		IGNORE User32.ReleaseDC(0,hDC);
	END DoInstall;

	PROCEDURE Install*(context : Commands.Context); (** ["H"] [ width [height] ] ["FULLSCREEN"] [ x [y] ] *)
	VAR x,y,w,h : SIGNED32; options: Options.Options;
	BEGIN
		NEW(options);
		options.Add("b","bits16",Options.Flag);
		options.Add("f","fullscreen",Options.Flag);
		options.Add("w","width",Options.Integer);
		options.Add("h","height",Options.Integer);
		options.Add("x","xOffset",Options.Integer);
		options.Add("y","yOffset",Options.Integer);
		options.Add("n","noMouseCursor",Options.Flag);
		IF ~options.Parse(context.arg, context.error) THEN
			w := 0; h := 0; x := 0; y := 0;
		ELSE
			IF options.GetFlag("b") THEN format := Displays.color565; InitBMI END;
			fullscreen := options.GetFlag("f");
			IF ~options.GetInteger("x", x) THEN x := 0 END;
			IF ~options.GetInteger("y", y) THEN y := 0 END;
			IF ~options.GetInteger("w", w) THEN w := 0 END;
			IF ~options.GetInteger("h", h) THEN h := 0 END;
			IF options.GetFlag("n") THEN DisableCursor END;
		END;
		closeRequests := 0;

		DoInstall( w, h, x, y);
	END Install;

VAR traceDisplay: BOOLEAN;
	PROCEDURE TraceDisplay*;
	BEGIN
		traceDisplay := ~traceDisplay;
	END TraceDisplay;


BEGIN
	traceDisplay := FALSE;
	format := Displays.color8888;
	InitMod();  Modules.InstallTermHandler( Shutdown );  KeyHandled := FALSE;
END Display.

Aos.Call Display.Install 1024 768 ~
Aos.Call Display.Install  ~
Aos.Call WindowManager.Install
Aos.Call MM.Open Menu.XML ~



(* window constants :

indexing
description: "Window message (WM) constants."
status: "See notice at end of class."
date: "$Date: 2001/11/12 17:58:05 $"
revision: "$Revision: 1.3 $"
class interface
WEL_WM_CONSTANTS
feature -- Access
Wm_activate: SIGNED16 is 6
-- Declared in Windows as WM_ACTIVATE
Wm_activateapp: SIGNED16 is 28
-- Declared in Windows as WM_ACTIVATEAPP
Wm_afxfirst: SIGNED16 is 864
-- Declared in Windows as WM_AFXFIRST
Wm_afxlast: SIGNED16 is 895
-- Declared in Windows as WM_AFXLAST
Wm_app: SIGNED16 is 32768
-- Declared in Windows as WM_APP
Wm_appcommand: SIGNED16 is 793
-- Declared in Windows as WM_APPCOMMAND
Wm_askcbformatname: SIGNED16 is 780
-- Declared in Windows as WM_ASKCBFORMATNAME
Wm_canceljournal: SIGNED16 is 75
-- Declared in Windows as WM_CANCELJOURNAL
Wm_cancelmode: SIGNED16 is 31
-- Declared in Windows as WM_CANCELMODE
Wm_capturechanged: SIGNED16 is 533
-- Declared in Windows as WM_CAPTURECHANGED
Wm_changecbchain: SIGNED16 is 781
-- Declared in Windows as WM_CHANGECBCHAIN
Wm_changeuistate: SIGNED16 is 295
-- Declared in Windows as WM_CHANGEUISTATE
Wm_char: SIGNED16 is 258
-- Declared in Windows as WM_CHAR
Wm_chartoitem: SIGNED16 is 47
-- Declared in Windows as WM_CHARTOITEM
Wm_childactivate: SIGNED16 is 34
-- Declared in Windows as WM_CHILDACTIVATE
Wm_clear: SIGNED16 is 771
-- Declared in Windows as WM_CLEAR
Wm_close: SIGNED16 is 16
-- Declared in Windows as WM_CLOSE
Wm_command: SIGNED16 is 273
-- Declared in Windows as WM_COMMAND
Wm_commnotify: SIGNED16 is 68
-- Declared in Windows as WM_COMMNOTIFY
Wm_compacting: SIGNED16 is 65
-- Declared in Windows as WM_COMPACTING
Wm_compareitem: SIGNED16 is 57
-- Declared in Windows as WM_COMPAREITEM
Wm_contextmenu: SIGNED16 is 123
-- Declared in Windows as WM_CONTEXTMENU
Wm_copy: SIGNED16 is 769
-- Declared in Windows as WM_COPY
Wm_copydata: SIGNED16 is 74
-- Declared in Windows as WM_COPYDATA
Wm_create: SIGNED16 is 1
-- Declared in Windows as WM_CREATE
Wm_cut: SIGNED16 is 768
-- Declared in Windows as WM_CUT
Wm_deadchar: SIGNED16 is 259
-- Declared in Windows as WM_DEADCHAR
Wm_deleteitem: SIGNED16 is 45
-- Declared in Windows as WM_DELETEITEM
Wm_destroy: SIGNED16 is 2
-- Declared in Windows as WM_DESTROY
Wm_destroyclipboard: SIGNED16 is 775
-- Declared in Windows as WM_DESTROYCLIPBOARD
Wm_devicechange: SIGNED16 is 537
-- Declared in Windows as WM_DEVICECHANGE
Wm_devmodechange: SIGNED16 is 27
-- Declared in Windows as WM_DEVMODECHANGE
Wm_displaychange: SIGNED16 is 126
-- Declared in Windows as WM_DISPLAYCHANGE
Wm_drawclipboard: SIGNED16 is 776
-- Declared in Windows as WM_DRAWCLIPBOARD
Wm_drawitem: SIGNED16 is 43
-- Declared in Windows as WM_DRAWITEM
Wm_dropfiles: SIGNED16 is 563
-- Declared in Windows as WM_DROPFILES
Wm_enable: SIGNED16 is 10
-- Declared in Windows as WM_ENABLE
Wm_endsession: SIGNED16 is 22
-- Declared in Windows as WM_ENDSESSION
Wm_enteridle: SIGNED16 is 289
-- Declared in Windows as WM_ENTERIDLE
Wm_entermenuloop: SIGNED16 is 529
-- Declared in Windows as WM_ENTERMENULOOP
Wm_entersizemove: SIGNED16 is 561
-- Declared in Windows as WM_ENTERSIZEOFMOVE
Wm_erasebkgnd: SIGNED16 is 20
-- Declared in Windows as WM_ERASEBKGND
Wm_exitmenuloop: SIGNED16 is 530
-- Declared in Windows as WM_EXITMENULOOP
Wm_exitsizemove: SIGNED16 is 562
-- Declared in Windows as WM_EXITSIZEOFMOVE
Wm_fontchange: SIGNED16 is 29
-- Declared in Windows as WM_FONTCHANGE
Wm_getdlgcode: SIGNED16 is 135
-- Declared in Windows as WM_GETDLGCODE
Wm_getfont: SIGNED16 is 49
-- Declared in Windows as WM_GETFONT
Wm_gethotkey: SIGNED16 is 51
-- Declared in Windows as WM_GETHOTKEY
Wm_geticon: SIGNED16 is 127
-- Declared in Windows as WM_GETICON
Wm_getminmaxinfo: SIGNED16 is 36
-- Declared in Windows as WM_GETMINMAXINFO
Wm_getobject: SIGNED16 is 61
-- Declared in Windows as WM_GETOBJECT
Wm_gettext: SIGNED16 is 13
-- Declared in Windows as WM_GETTEXT
Wm_gettextlength: SIGNED16 is 14
-- Declared in Windows as WM_GETTEXTLENGTH
Wm_handheldfirst: SIGNED16 is 856
-- Declared in Windows as WM_HANDHELDFIRST
Wm_handheldlast: SIGNED16 is 863
-- Declared in Windows as WM_HANDHELDLAST
Wm_help: SIGNED16 is 83
-- Declared in Windows as WM_HELP
Wm_hotkey: SIGNED16 is 786
-- Declared in Windows as WM_HOTKEY
Wm_hscroll: SIGNED16 is 276
-- Declared in Windows as WM_HSCROLL
Wm_hscrollclipboard: SIGNED16 is 782
-- Declared in Windows as WM_HSCROLLCLIPBOARD
Wm_iconerasebkgnd: SIGNED16 is 39
-- Declared in Windows as WM_ICONERASEBKGND
Wm_ime_char: SIGNED16 is 646
-- Declared in Windows as WM_IME_CHAR
Wm_ime_composition: SIGNED16 is 271
-- Declared in Windows as WM_IME_COMPOSITION
Wm_ime_compositionfull: SIGNED16 is 644
-- Declared in Windows as WM_IME_COMPOSITIONFULL
Wm_ime_control: SIGNED16 is 643
-- Declared in Windows as WM_IME_CONTROL
Wm_ime_endcomposition: SIGNED16 is 270
-- Declared in Windows as WM_IME_ENDCOMPOSITION
Wm_ime_keydown: SIGNED16 is 656
-- Declared in Windows as WM_IME_KEYDOWN
wm_ime_keylast: SIGNED16
-- Declared in Windows as WM_IME_KEYLAST
Wm_ime_keyup: SIGNED16 is 657
-- Declared in Windows as WM_IME_KEYUP
Wm_ime_notify: SIGNED16 is 642
-- Declared in Windows as WM_IME_NOTIFY
Wm_ime_request: SIGNED16 is 648
-- Declared in Windows as WM_IME_REQUEST
Wm_ime_select: SIGNED16 is 645
-- Declared in Windows as WM_IME_SELECT
Wm_ime_setcontext: SIGNED16 is 641
-- Declared in Windows as WM_IME_SETCONTEXT
Wm_ime_startcomposition: SIGNED16 is 269
-- Declared in Windows as WM_IME_STARTCOMPOSITION
Wm_initdialog: SIGNED16 is 272
-- Declared in Windows as WM_INITDIALOG
Wm_initmenu: SIGNED16 is 278
-- Declared in Windows as WM_INITMENU
Wm_initmenupopup: SIGNED16 is 279
-- Declared in Windows as WM_INITMENUPOPUP
Wm_inputlangchange: SIGNED16 is 81
-- Declared in Windows as WM_INPUTLANGCHANGE
Wm_inputlangchangerequest: SIGNED16 is 80
-- Declared in Windows as WM_INPUTLANGCHANGEREQUEST
Wm_keydown: SIGNED16 is 256
-- Declared in Windows as WM_KEYDOWN
Wm_keyfirst: SIGNED16 is 256
-- Declared in Windows as WM_KEYFIRST
wm_keylast: SIGNED16
-- Declared in Windows as WM_KEYLAST
Wm_keyup: SIGNED16 is 257
-- Declared in Windows as WM_KEYUP
Wm_killfocus: SIGNED16 is 8
-- Declared in Windows as WM_KILLFOCUS
Wm_lbuttondblclk: SIGNED16 is 515
-- Declared in Windows as WM_LBUTTONDBLCLK
Wm_lbuttondown: SIGNED16 is 513
-- Declared in Windows as WM_LBUTTONDOWN
Wm_lbuttonup: SIGNED16 is 514
-- Declared in Windows as WM_LBUTTONUP
Wm_mbuttondblclk: SIGNED16 is 521
-- Declared in Windows as WM_MBUTTONDBLCLK
Wm_mbuttondown: SIGNED16 is 519
-- Declared in Windows as WM_MBUTTONDOWN
Wm_mbuttonup: SIGNED16 is 520
-- Declared in Windows as WM_MBUTTONUP
Wm_mdiactivate: SIGNED16 is 546
-- Declared in Windows as WM_MDIACTIVATE
Wm_mdicascade: SIGNED16 is 551
-- Declared in Windows as WM_MDICASCADE
Wm_mdicreate: SIGNED16 is 544
-- Declared in Windows as WM_MDICREATE
Wm_mdidestroy: SIGNED16 is 545
-- Declared in Windows as WM_MDIDESTROY
Wm_mdigetactive: SIGNED16 is 553
-- Declared in Windows as WM_MDIGETACTIVE
Wm_mdiiconarrange: SIGNED16 is 552
-- Declared in Windows as WM_MDIICONARRANGE
Wm_mdimaximize: SIGNED16 is 549
-- Declared in Windows as WM_MDIMAXIMIZE
Wm_mdinext: SIGNED16 is 548
-- Declared in Windows as WM_MDINEXT
Wm_mdirefreshmenu: SIGNED16 is 564
-- Declared in Windows as WM_MDIREFRESHMENU
Wm_mdirestore: SIGNED16 is 547
-- Declared in Windows as WM_MDIRESTORE
Wm_mdisetmenu: SIGNED16 is 560
-- Declared in Windows as WM_MDISETMENU
Wm_mditile: SIGNED16 is 550
-- Declared in Windows as WM_MDITILE
Wm_measureitem: SIGNED16 is 44
-- Declared in Windows as WM_MEASUREITEM
Wm_menuchar: SIGNED16 is 288
-- Declared in Windows as WM_MENUCHAR
Wm_menucommand: SIGNED16 is 294
-- Declared in Windows as WM_MENUCOMMAND
Wm_menudrag: SIGNED16 is 291
-- Declared in Windows as WM_MENUDRAG
Wm_menugetobject: SIGNED16 is 292
-- Declared in Windows as WM_MENUGETOBJECT
Wm_menurbuttonup: SIGNED16 is 290
-- Declared in Windows as WM_MENURBUTTONUP
Wm_menuselect: SIGNED16 is 287
-- Declared in Windows as WM_MENUSELECT
Wm_mouseactivate: SIGNED16 is 33
-- Declared in Windows as WM_MOUSEACTIVATE
Wm_mousefirst: SIGNED16 is 512
-- Declared in Windows as WM_MOUSEFIRST
Wm_mousehover: SIGNED16 is 673
-- Require Windows98, Windows NT 4.0 or later
-- Declared in Windows as WM_MOUSEHOVER
wm_mouselast: SIGNED16
-- Declared in Windows as WM_MOUSELAST
Wm_mouseleave: SIGNED16 is 675
-- Require Windows98, Windows NT 4.0 or later
-- Declared in Windows as WM_MOUSELEAVE
Wm_mousemove: SIGNED16 is 512
-- Declared in Windows as WM_MOUSEMOVE
Wm_mousewheel: SIGNED16 is 522
-- Declared in Windows as WM_MOUSEWHEEL
Wm_move: SIGNED16 is 3
-- Declared in Windows as WM_MOVE
Wm_moving: SIGNED16 is 534
-- Declared in Windows as WM_MOVING
Wm_ncactivate: SIGNED16 is 134
-- Declared in Windows as WM_NCACTIVATE
Wm_nccalcsize: SIGNED16 is 131
-- Declared in Windows as WM_NCCALCSIZEOF
Wm_nccreate: SIGNED16 is 129
-- Declared in Windows as WM_NCCREATE
Wm_ncdestroy: SIGNED16 is 130
-- Declared in Windows as WM_NCDESTROY
Wm_nchittest: SIGNED16 is 132
-- Declared in Windows as WM_NCHITTEST
Wm_nclbuttondblclk: SIGNED16 is 163
-- Declared in Windows as WM_NCLBUTTONDBLCLK
Wm_nclbuttondown: SIGNED16 is 161
-- Declared in Windows as WM_NCLBUTTONDOWN
Wm_nclbuttonup: SIGNED16 is 162
-- Declared in Windows as WM_NCLBUTTONUP
Wm_ncmbuttondblclk: SIGNED16 is 169
-- Declared in Windows as WM_NCMBUTTONDBLCLK
Wm_ncmbuttondown: SIGNED16 is 167
-- Declared in Windows as WM_NCMBUTTONDOWN
Wm_ncmbuttonup: SIGNED16 is 168
-- Declared in Windows as WM_NCMBUTTONUP
Wm_ncmousehover: SIGNED16 is 672
-- Require Windows98, Windows NT 5.0 or later
-- Declared in Windows as WM_NCMOUSEHOVER
Wm_ncmouseleave: SIGNED16 is 674
-- Require Windows98, Windows NT 5.0 or later
-- Declared in Windows as WM_NCMOUSELEAVE
Wm_ncmousemove: SIGNED16 is 160
-- Declared in Windows as WM_NCMOUSEMOVE
Wm_ncpaint: SIGNED16 is 133
-- Declared in Windows as WM_NCPAINT
Wm_ncrbuttondblclk: SIGNED16 is 166
-- Declared in Windows as WM_NCRBUTTONDBLCLK
Wm_ncrbuttondown: SIGNED16 is 164
-- Declared in Windows as WM_NCRBUTTONDOWN
Wm_ncrbuttonup: SIGNED16 is 165
-- Declared in Windows as WM_NCRBUTTONUP
Wm_ncxbuttondblclk: SIGNED16 is 173
-- Declared in Windows as WM_NCXBUTTONDBLCLK
Wm_ncxbuttondown: SIGNED16 is 171
-- Declared in Windows as WM_NCXBUTTONDOWN
Wm_ncxbuttonup: SIGNED16 is 172
-- Declared in Windows as WM_NCXBUTTONUP
Wm_nextdlgctl: SIGNED16 is 40
-- Declared in Windows as WM_NEXTDLGCTL
Wm_nextmenu: SIGNED16 is 531
-- Declared in Windows as WM_NEXTMENU
Wm_notify: SIGNED16 is 78
-- Declared in Windows as WM_NOTIFY
Wm_notifyformat: SIGNED16 is 85
-- Declared in Windows as WM_NOTIFYFORMAT
Wm_null: SIGNED16 is 0
-- Declared in Windows as WM_NULL
Wm_paint: SIGNED16 is 15
-- Declared in Windows as WM_PAINT
Wm_paintclipboard: SIGNED16 is 777
-- Declared in Windows as WM_PAINTCLIPBOARD
Wm_painticon: SIGNED16 is 38
-- Declared in Windows as WM_PAINTICON
Wm_palettechanged: SIGNED16 is 785
-- Declared in Windows as WM_PALETTECHANGED
Wm_paletteischanging: SIGNED16 is 784
-- Declared in Windows as WM_PALETTEISCHANGING
Wm_parentnotify: SIGNED16 is 528
-- Declared in Windows as WM_PARENTNOTIFY
Wm_paste: SIGNED16 is 770
-- Declared in Windows as WM_PASTE
Wm_penwinfirst: SIGNED16 is 896
-- Declared in Windows as WM_PENWINFIRST
Wm_penwinlast: SIGNED16 is 911
-- Declared in Windows as WM_PENWINLAST
Wm_power: SIGNED16 is 72
-- Declared in Windows as WM_POWER
Wm_powerbroadcast: SIGNED16 is 536
-- Declared in Windows as WM_POWERBROADCAST
Wm_print: SIGNED16 is 791
-- Declared in Windows as WM_PRINT
Wm_printclient: SIGNED16 is 792
-- Declared in Windows as WM_PRINTCLIENT
Wm_querydragicon: SIGNED16 is 55
-- Declared in Windows as WM_QUERYDRAGICON
Wm_queryendsession: SIGNED16 is 17
-- Declared in Windows as WM_QUERYENDSESSION
Wm_querynewpalette: SIGNED16 is 783
-- Declared in Windows as WM_QUERYNEWPALETTE
Wm_queryopen: SIGNED16 is 19
-- Declared in Windows as WM_QUERYOPEN
Wm_queryuistate: SIGNED16 is 297
-- Declared in Windows as WM_QUERYUISTATE
Wm_queuesync: SIGNED16 is 35
-- Declared in Windows as WM_QUEUESYNC
Wm_quit: SIGNED16 is 18
-- Declared in Windows as WM_QUIT
Wm_rbuttondblclk: SIGNED16 is 518
-- Declared in Windows as WM_RBUTTONDBLCLK
Wm_rbuttondown: SIGNED16 is 516
-- Declared in Windows as WM_RBUTTONDOWN
Wm_rbuttonup: SIGNED16 is 517
-- Declared in Windows as WM_RBUTTONUP
Wm_renderallformats: SIGNED16 is 774
-- Declared in Windows as WM_RENDERALLFORMATS
Wm_renderformat: SIGNED16 is 773
-- Declared in Windows as WM_RENDERFORMAT
Wm_setcursor: SIGNED16 is 32
-- Declared in Windows as WM_SETCURSOR
Wm_setfocus: SIGNED16 is 7
-- Declared in Windows as WM_SETFOCUS
Wm_setfont: SIGNED16 is 48
-- Declared in Windows as WM_SETFONT
Wm_sethotkey: SIGNED16 is 50
-- Declared in Windows as WM_SETHOTKEY
Wm_seticon: SIGNED16 is 128
-- Declared in Windows as WM_SETICON
Wm_setredraw: SIGNED16 is 11
-- Declared in Windows as WM_SETREDRAW
Wm_settext: SIGNED16 is 12
-- Declared in Windows as WM_SETTEXT
Wm_settingchange: SIGNED16 is 26
-- Declared in Windows as WM_WININICHANGE
-- Was declared in WEL_WM_CONSTANTS as synonym of wm_wininichange.
Wm_showwindow: SIGNED16 is 24
-- Declared in Windows as WM_SHOWWINDOW
Wm_size: SIGNED16 is 5
-- Declared in Windows as WM_SIZEOF
Wm_sizeclipboard: SIGNED16 is 779
-- Declared in Windows as WM_SIZEOFCLIPBOARD
Wm_sizing: SIGNED16 is 532
-- Declared in Windows as WM_SIZING
Wm_spoolerstatus: SIGNED16 is 42
-- Declared in Windows as WM_SPOOLERSTATUS
Wm_stylechanged: SIGNED16 is 125
-- Declared in Windows as WM_STYLECHANGED
Wm_stylechanging: SIGNED16 is 124
-- Declared in Windows as WM_STYLECHANGING
Wm_syncpaint: SIGNED16 is 136
-- Declared in Windows as WM_SYNCPAINT
Wm_syschar: SIGNED16 is 262
-- Declared in Windows as WM_SYSCHAR
Wm_syscolorchange: SIGNED16 is 21
-- Declared in Windows as WM_SYSCOLORCHANGE
Wm_syscommand: SIGNED16 is 274
-- Declared in Windows as WM_SYSCOMMAND
Wm_sysdeadchar: SIGNED16 is 263
-- Declared in Windows as WM_SYSDEADCHAR
Wm_syskeydown: SIGNED16 is 260
-- Declared in Windows as WM_SYSKEYDOWN
Wm_syskeyup: SIGNED16 is 261
-- Declared in Windows as WM_SYSKEYUP
Wm_tcard: SIGNED16 is 82
-- Declared in Windows as WM_TCARD
Wm_timechange: SIGNED16 is 30
-- Declared in Windows as WM_TIMECHANGE
Wm_timer: SIGNED16 is 275
-- Declared in Windows as WM_TIMER
Wm_undo: SIGNED16 is 772
-- Declared in Windows as WM_UNDO
Wm_uninitmenupopup: SIGNED16 is 293
-- Declared in Windows as WM_UNINITMENUPOPUP
Wm_updateuistate: SIGNED16 is 296
-- Declared in Windows as WM_UPDATEUISTATE
Wm_user: SIGNED16 is 1024
-- Declared in Windows as WM_USER
Wm_userchanged: SIGNED16 is 84
-- Declared in Windows as WM_USERCHANGED
Wm_vkeytoitem: SIGNED16 is 46
-- Declared in Windows as WM_VKEYTOITEM
Wm_vscroll: SIGNED16 is 277
-- Declared in Windows as WM_VSCROLL
Wm_vscrollclipboard: SIGNED16 is 778
-- Declared in Windows as WM_VSCROLLCLIPBOARD
Wm_windowposchanged: SIGNED16 is 71
-- Declared in Windows as WM_WINDOWPOSCHANGED
Wm_windowposchanging: SIGNED16 is 70
-- Declared in Windows as WM_WINDOWPOSCHANGING
Wm_wininichange: SIGNED16 is 26
-- Declared in Windows as WM_WININICHANGE
-- Was declared in WEL_WM_CONSTANTS as synonym of wm_settingchange.
Wm_xbuttondblclk: SIGNED16 is 525
-- Declared in Windows as WM_XBUTTONDBLCLK
Wm_xbuttondown: SIGNED16 is 523
-- Declared in Windows as WM_XBUTTONDOWN
Wm_xbuttonup: SIGNED16 is 524
-- Declared in Windows as WM_XBUTTONUP

invariant
-- from ANY
reflexive_equality: standard_is_equal (Current)
reflexive_conformance: conforms_to (Current)
end -- class WEL_WM_CONSTANTS


WM Key down
Parameters
wParam
Specifies the virtual-key code of the nonsystem key.
lParam
Specifies the repeat count, scan code, extended-key flag, context code, previous key-state flag, and transition-state flag, as shown in the following table.

0-15
Specifies the repeat count for the current message. The value is the number of times the keystroke is autorepeated as a result of the user holding down the key.
If the keystroke is held long enough, multiple messages are sent. However, the repeat count is not cumulative.

16-23
Specifies the scan code. The value depends on the OEM.
24
Specifies whether the key is an extended key, such as the right-hand ALT and CTRL keys that appear on an enhanced 101- or 102-key keyboard. The value is 1 if it is an extended key; otherwise, it is 0.
25-28
Reserved; do not use.
29
Specifies the context code. The value is always 0 for a WM_KEYDOWN message.
30
Specifies the previous key state. The value is 1 if the key is down before the message is sent, or it is zero if the key is up.
31
Specifies the transition state. The value is always zero for a WM_KEYDOWN message.

wm key up
wParam
Specifies the virtual-key code of the nonsystem key.
lParam
Specifies the repeat count, scan code, extended-key flag, context code, previous key-state flag, and transition-state flag, as shown in the following table. 0-15
Specifies the repeat count for the current message. The value is the number of times the keystroke is autorepeated as a result of the user holding down the key. The repeat count is always one for a WM_KEYUP message.

16-23
Specifies the scan code. The value depends on the OEM.
24
Specifies whether the key is an extended key, such as the right-hand ALT and CTRL keys that appear on an enhanced 101- or 102-key keyboard. The value is 1 if it is an extended key; otherwise, it is 0.
25-28
Reserved; do not use.
29
Specifies the context code. The value is always 0 for a WM_KEYUP message.
30
Specifies the previous key state. The value is always 1 for a WM_KEYUP message.
31
Specifies the transition state. The value is always 1 for a WM_KEYUP message.

indexing
	description: "Virtual Key code (VK) constants."
	status: "See notice at end of class."
	date: "$Date: 2001/11/12 17:58:05 $"
	revision: "$Revision: 1.3 $"

class interface
	WEL_VK_CONSTANTS

feature -- Access

	Vk_0: SIGNED16 is 48

	Vk_1: SIGNED16 is 49

	Vk_2: SIGNED16 is 50

	Vk_3: SIGNED16 is 51

	Vk_4: SIGNED16 is 52

	Vk_5: SIGNED16 is 53

	Vk_6: SIGNED16 is 54

	Vk_7: SIGNED16 is 55

	Vk_8: SIGNED16 is 56

	Vk_9: SIGNED16 is 57
			-- Vk_a thru Vk_z are the same as their ASCII equivalents: 'A' thru 'Z'.

	Vk_a: SIGNED16 is 65

	Vk_add: SIGNED16 is 107
			-- Declared in Windows as VK_ADD

	Vk_b: SIGNED16 is 66

	Vk_back: SIGNED16 is 8
			-- Declared in Windows as VK_BACK

	Vk_c: SIGNED16 is 67

	Vk_cancel: SIGNED16 is 3
			-- Declared in Windows as VK_CANCEL

	Vk_capital: SIGNED16 is 20
			-- Declared in Windows as VK_CAPITAL

	Vk_clear: SIGNED16 is 12
			-- Declared in Windows as VK_CLEAR

	Vk_control: SIGNED16 is 17
			-- Declared in Windows as VK_CONTROL

	Vk_d: SIGNED16 is 68

	Vk_decimal: SIGNED16 is 110
			-- Declared in Windows as VK_DECIMAL

	Vk_delete: SIGNED16 is 46
			-- Declared in Windows as VK_DELETE

	Vk_divide: SIGNED16 is 111
			-- Declared in Windows as VK_DIVIDE

	Vk_down: SIGNED16 is 40
			-- Declared in Windows as VK_DOWN

	Vk_e: SIGNED16 is 69

	Vk_end: SIGNED16 is 35
			-- Declared in Windows as VK_END

	Vk_escape: SIGNED16 is 27
			-- Declared in Windows as VK_ESCAPE

	Vk_execute: SIGNED16 is 43
			-- Declared in Windows as VK_EXECUTE

	Vk_f: SIGNED16 is 70

	Vk_f1: SIGNED16 is 112
			-- Declared in Windows as VK_F1

	Vk_f10: SIGNED16 is 121
			-- Declared in Windows as VK_F10

	Vk_f11: SIGNED16 is 122
			-- Declared in Windows as VK_F11

	Vk_f12: SIGNED16 is 123
			-- Declared in Windows as VK_F12

	Vk_f13: SIGNED16 is 124
			-- Declared in Windows as VK_F13

	Vk_f14: SIGNED16 is 125
			-- Declared in Windows as VK_F14

	Vk_f15: SIGNED16 is 126
			-- Declared in Windows as VK_F15

	Vk_f16: SIGNED16 is 127
			-- Declared in Windows as VK_F16

	Vk_f17: SIGNED16 is 128
			-- Declared in Windows as VK_F17

	Vk_f18: SIGNED16 is 129
			-- Declared in Windows as VK_F18

	Vk_f19: SIGNED16 is 130
			-- Declared in Windows as VK_F19

	Vk_f2: SIGNED16 is 113
			-- Declared in Windows as VK_F2

	Vk_f20: SIGNED16 is 131
			-- Declared in Windows as VK_F20

	Vk_f21: SIGNED16 is 132
			-- Declared in Windows as VK_F21

	Vk_f22: SIGNED16 is 133
			-- Declared in Windows as VK_F22

	Vk_f23: SIGNED16 is 134
			-- Declared in Windows as VK_F23

	Vk_f24: SIGNED16 is 135
			-- Declared in Windows as VK_F24

	Vk_f3: SIGNED16 is 114
			-- Declared in Windows as VK_F3

	Vk_f4: SIGNED16 is 115
			-- Declared in Windows as VK_F4

	Vk_f5: SIGNED16 is 116
			-- Declared in Windows as VK_F5

	Vk_f6: SIGNED16 is 117
			-- Declared in Windows as VK_F6

	Vk_f7: SIGNED16 is 118
			-- Declared in Windows as VK_F7

	Vk_f8: SIGNED16 is 119
			-- Declared in Windows as VK_F8

	Vk_f9: SIGNED16 is 120
			-- Declared in Windows as VK_F9

	Vk_g: SIGNED16 is 71

	Vk_h: SIGNED16 is 72

	Vk_help: SIGNED16 is 47
			-- Declared in Windows as VK_HELP

	Vk_home: SIGNED16 is 36
			-- Declared in Windows as VK_HOME

	Vk_i: SIGNED16 is 73

	Vk_insert: SIGNED16 is 45
			-- Declared in Windows as VK_INSERT

	Vk_j: SIGNED16 is 74

	Vk_k: SIGNED16 is 75

	Vk_l: SIGNED16 is 76

	Vk_lbutton: SIGNED16 is 1
			-- Declared in Windows as VK_LBUTTON

	Vk_lcontrol: SIGNED16 is 162
			-- Declared in Windows as VK_LCONTROL

	Vk_left: SIGNED16 is 37
			-- Declared in Windows as VK_LEFT

	Vk_lmenu: SIGNED16 is 164
			-- Declared in Windows as VK_LMENU

	Vk_lshift: SIGNED16 is 160
			-- Declared in Windows as VK_LSHIFT

	Vk_m: SIGNED16 is 77

	Vk_mbutton: SIGNED16 is 4
			-- Declared in Windows as VK_MBUTTON

	Vk_menu: SIGNED16 is 18
			-- Declared in Windows as VK_MENU

	Vk_multiply: SIGNED16 is 106
			-- Declared in Windows as VK_MULTIPLY

	Vk_n: SIGNED16 is 78

	Vk_next: SIGNED16 is 34
			-- Declared in Windows as VK_NEXT

	Vk_numlock: SIGNED16 is 144
			-- Declared in Windows as VK_NUMLOCK

	Vk_numpad0: SIGNED16 is 96
			-- Declared in Windows as VK_NUMPAD0

	Vk_numpad1: SIGNED16 is 97
			-- Declared in Windows as VK_NUMPAD1

	Vk_numpad2: SIGNED16 is 98
			-- Declared in Windows as VK_NUMPAD2

	Vk_numpad3: SIGNED16 is 99
			-- Declared in Windows as VK_NUMPAD3

	Vk_numpad4: SIGNED16 is 100
			-- Declared in Windows as VK_NUMPAD4

	Vk_numpad5: SIGNED16 is 101
			-- Declared in Windows as VK_NUMPAD5

	Vk_numpad6: SIGNED16 is 102
			-- Declared in Windows as VK_NUMPAD6

	Vk_numpad7: SIGNED16 is 103
			-- Declared in Windows as VK_NUMPAD7

	Vk_numpad8: SIGNED16 is 104
			-- Declared in Windows as VK_NUMPAD8

	Vk_numpad9: SIGNED16 is 105
			-- Declared in Windows as VK_NUMPAD9

	Vk_o: SIGNED16 is 79

	Vk_p: SIGNED16 is 80

	Vk_pause: SIGNED16 is 19
			-- Declared in Windows as VK_PAUSE

	Vk_print: SIGNED16 is 42
			-- Declared in Windows as VK_PRINT

	Vk_prior: SIGNED16 is 33
			-- Declared in Windows as VK_PRIOR

	Vk_q: SIGNED16 is 81

	Vk_r: SIGNED16 is 82

	Vk_rbutton: SIGNED16 is 2
			-- Declared in Windows as VK_RBUTTON

	Vk_rcontrol: SIGNED16 is 163
			-- Declared in Windows as VK_RCONTROL

	Vk_return: SIGNED16 is 13
			-- Declared in Windows as VK_RETURN

	Vk_right: SIGNED16 is 39
			-- Declared in Windows as VK_RIGHT

	Vk_rmenu: SIGNED16 is 165
			-- Declared in Windows as VK_RMENU
			-- Vk_0 thru Vk_9 are the same as their ASCII equivalents: '0' thru '9'.

	Vk_rshift: SIGNED16 is 161
			-- Declared in Windows as VK_RSHIFT

	Vk_s: SIGNED16 is 83

	Vk_scroll: SIGNED16 is 145
			-- Declared in Windows as VK_SCROLL

	Vk_select: SIGNED16 is 41
			-- Declared in Windows as VK_SELECT

	Vk_separator: SIGNED16 is 108
			-- Declared in Windows as VK_SEPARATOR

	Vk_shift: SIGNED16 is 16
			-- Declared in Windows as VK_SHIFT

	Vk_snapshot: SIGNED16 is 44nn
			-- Declared in Windows as VK_SNAPSHOT

	Vk_space: SIGNED16 is 32
			-- Declared in Windows as VK_SPACE

	Vk_subtract: SIGNED16 is 109
			-- Declared in Windows as VK_SUBTRACT

	Vk_t: SIGNED16 is 84

	Vk_tab: SIGNED16 is 9
			-- Declared in Windows as VK_TAB

	Vk_u: SIGNED16 is 85

	Vk_up: SIGNED16 is 38
			-- Declared in Windows as VK_UP

	Vk_v: SIGNED16 is 86

	Vk_w: SIGNED16 is 87

	Vk_x: SIGNED16 is 88

	Vk_y: SIGNED16 is 89

	Vk_z: SIGNED16 is 90

invariant

Sm_cmetrics: SIGNED16 is 76
Sm_cxborder: SIGNED16 is 5
Sm_cxcursor: SIGNED16 is 13
Sm_cxdlgframe: SIGNED16 is 7
Sm_cxdoubleclk: SIGNED16 is 36
Sm_cxframe: SIGNED16 is 32
Sm_cxfullscreen: SIGNED16 is 16
Sm_cxhscroll: SIGNED16 is 21
Sm_cxhthumb: SIGNED16 is 10
Sm_cxicon: SIGNED16 is 11
Sm_cxiconspacing: SIGNED16 is 38
Sm_cxmaximized: SIGNED16 is 61
Sm_cxmin: SIGNED16 is 28
Sm_cxmintrack: SIGNED16 is 34
Sm_cxscreen: SIGNED16 is 0
Sm_cxsize: SIGNED16 is 30
Sm_cxvscroll: SIGNED16 is 2
Sm_cyborder: SIGNED16 is 6
Sm_cycaption: SIGNED16 is 4
Sm_cycursor: SIGNED16 is 14
Sm_cydlgframe: SIGNED16 is 8
Sm_cydoubleclk: SIGNED16 is 37
Sm_cyframe: SIGNED16 is 33
Sm_cyfullscreen: SIGNED16 is 17
Sm_cyhscroll: SIGNED16 is 3
Sm_cyicon: SIGNED16 is 12
Sm_cyiconspacing: SIGNED16 is 39
Sm_cykanjiwindow: SIGNED16 is 18
Sm_cymaximized: SIGNED16 is 62
Sm_cymenu: SIGNED16 is 15
Sm_cymin: SIGNED16 is 29
Sm_cymintrack: SIGNED16 is 35
Sm_cyscreen: SIGNED16 is 1
Sm_cysize: SIGNED16 is 31
Sm_cyvscroll: SIGNED16 is 20
Sm_cyvthumb: SIGNED16 is 9
Sm_dbcsenabled: SIGNED16 is 42
Sm_debug: SIGNED16 is 22
Sm_menudropalignment: SIGNED16 is 40
Sm_mousepresent: SIGNED16 is 19
Sm_penwindows: SIGNED16 is 41
Sm_reserved1: SIGNED16 is 24
Sm_reserved2: SIGNED16 is 25
Sm_reserved3: SIGNED16 is 26
Sm_reserved4: SIGNED16 is 27
Sm_swapbutton: SIGNED16 is 23

indexing
description: "Window style (WS) constants."
status: "See notice at end of class."
date: "$Date: 2001/11/12 17:58:06 $"
revision: "$Revision: 1.3 $"
class interface
WEL_WS_CONSTANTS
feature -- Miscellaneous
Cw_usedefault: SIGNED16 is -2147483648
-- Declared in Windows as CW_USEDEFAULT

feature -- Basic window types
Ws_child: SIGNED16 is 1073741824
-- Declared in Windows as WS_CHILD
Ws_overlapped: SIGNED16 is 0
-- Declared in Windows as WS_OVERLAPPED
-- Was declared in WEL_WS_CONSTANTS as synonym of ws_tiled.
Ws_popup: SIGNED16 is -2147483648
-- Declared in Windows as WS_POPUP
Ws_tiled: SIGNED16 is 0
-- Declared in Windows as WS_OVERLAPPED
-- Was declared in WEL_WS_CONSTANTS as synonym of ws_overlapped.

feature -- Clipping styles
Ws_clipchildren: SIGNED16 is 33554432
-- Declared in Windows as WS_CLIPCHILDREN
Ws_clipsiblings: SIGNED16 is 67108864
-- Declared in Windows as WS_CLIPSIBLINGS

feature -- Common window styles
Ws_childwindow: SIGNED16 is 1073741824
-- Declared in Windows as WS_CHILDWINDOW
Ws_overlappedwindow: SIGNED16 is 13565952
-- Declared in Windows as WS_OVERLAPPEDWINDOW
-- Was declared in WEL_WS_CONSTANTS as synonym of ws_tiledwindow.
Ws_popupwindow: SIGNED16 is -2138570752
-- Declared in Windows as WS_POPUPWINDOW
Ws_tiledwindow: SIGNED16 is 13565952
-- Declared in Windows as WS_OVERLAPPEDWINDOW
-- Was declared in WEL_WS_CONSTANTS as synonym of ws_overlappedwindow.

feature -- Control window styles
Ws_group: SIGNED16 is 131072
-- Declared in Windows as WS_GROUP
Ws_tabstop: SIGNED16 is 65536
-- Declared in Windows as WS_TABSTOP

feature -- Extended window styles
Ws_ex_acceptfiles: SIGNED16 is 16
-- Declared in Windows as WS_EX_ACCEPTFILES
Ws_ex_clientedge: SIGNED16 is 512
-- Declared in Windows as WS_EX_CLIENTEDGE
Ws_ex_contexthelp: SIGNED16 is 1024
-- Declared in Windows as WS_EX_CONTEXTHELP
Ws_ex_controlparent: SIGNED16 is 65536
-- Declared in Windows as WS_EX_CONTROLPARENT
Ws_ex_dlgmodalframe: SIGNED16 is 1
-- Declared in Windows as WS_EX_DLGMODALFRAME
Ws_ex_left: SIGNED16 is 0
-- Declared in Windows as WS_EX_LEFT
Ws_ex_leftscrollbar: SIGNED16 is 16384
-- Declared in Windows as WS_EX_LEFTSCROLLBAR
Ws_ex_ltrreading: SIGNED16 is 0
-- Declared in Windows as WS_EX_LTRREADING
Ws_ex_mdichild: SIGNED16 is 64
-- Declared in Windows as WS_EX_MDICHILD
Ws_ex_noparentnotify: SIGNED16 is 4
-- Declared in Windows as WS_EX_NOPARENTNOTIFY
Ws_ex_overlappedwindow: SIGNED16 is 768
-- Declared in Windows as WS_EX_OVERLAPPEDWINDOW
Ws_ex_palettewindow: SIGNED16 is 392
-- Declared in Windows as WS_EX_PALETTEWINDOW
Ws_ex_right: SIGNED16 is 4096
-- Declared in Windows as WS_EX_RIGHT
Ws_ex_rightscrollbar: SIGNED16 is 0
-- Declared in Windows as WS_EX_RIGHTSCROLLBAR
Ws_ex_rtlreading: SIGNED16 is 8192
-- Declared in Windows as WS_EX_RTLREADING
Ws_ex_staticedge: SIGNED16 is 131072
-- Declared in Windows as WS_EX_STATICEDGE
Ws_ex_toolwindow: SIGNED16 is 128
-- Declared in Windows as WS_EX_TOOLWINDOW
Ws_ex_topmost: SIGNED16 is 8
-- Declared in Windows as WS_EX_TOPMOST
Ws_ex_transparent: SIGNED16 is 32
-- Declared in Windows as WS_EX_TRANSPARENT
Ws_ex_windowedge: SIGNED16 is 256
-- Declared in Windows as WS_EX_WINDOWEDGE

feature -- Generic window states
Ws_disabled: SIGNED16 is 134217728
-- Declared in Windows as WS_DISABLED
Ws_visible: SIGNED16 is 268435456
-- Declared in Windows as WS_VISIBLE

feature -- Main window states
Ws_iconic: SIGNED16 is 536870912
-- Declared in Windows as WS_MINIMIZE
-- Was declared in WEL_WS_CONSTANTS as synonym of ws_minimize.
Ws_maximize: SIGNED16 is 16777216
-- Declared in Windows as WS_MAXIMIZE
Ws_minimize: SIGNED16 is 536870912
-- Declared in Windows as WS_MINIMIZE
-- Was declared in WEL_WS_CONSTANTS as synonym of ws_iconic.

feature -- Main window styles
Ws_border: SIGNED16 is 8388608
-- Declared in Windows as WS_BORDER
Ws_caption: SIGNED16 is 12582912
-- Declared in Windows as WS_CAPTION
Ws_dlgframe: SIGNED16 is 4194304
-- Declared in Windows as WS_DLGFRAME
Ws_hscroll: SIGNED16 is 1048576
-- Declared in Windows as WS_HSCROLL
Ws_maximizebox: SIGNED16 is 65536
-- Declared in Windows as WS_MAXIMIZEBOX
Ws_minimizebox: SIGNED16 is 131072
-- Declared in Windows as WS_MINIMIZEBOX
Ws_sizebox: SIGNED16 is 262144
-- Declared in Windows as WS_THICKFRAME
-- Was declared in WEL_WS_CONSTANTS as synonym of ws_thickframe.
Ws_sysmenu: SIGNED16 is 524288
-- Declared in Windows as WS_SYSMENU
Ws_thickframe: SIGNED16 is 262144
-- Declared in Windows as WS_THICKFRAME
-- Was declared in WEL_WS_CONSTANTS as synonym of ws_sizebox.
Ws_vscroll: SIGNED16 is 2097152
-- Declared in Windows as WS_VSCROLL

invariant
-- from ANY
reflexive_equality: standard_is_equal (Current)
reflexive_conformance: conforms_to (Current)
end -- class WEL_WS_CONSTANTS

indexing
description: "Size (SIZEOF) constants."
status: "See notice at end of class."
date: "$Date: 2001/11/12 17:58:04 $"
revision: "$Revision: 1.3 $"
class interface
WEL_SIZEOF_CONSTANTS
feature -- Access
Size_maxhide: SIGNED16 is 4
-- Declared in Windows as SIZEOF_MAXHIDE
Size_maximized: SIGNED16 is 2
-- Declared in Windows as SIZEOF_MAXIMIZED
Size_maxshow: SIGNED16 is 3
-- Declared in Windows as SIZEOF_MAXSHOW
Size_minimized: SIGNED16 is 1
-- Declared in Windows as SIZEOF_MINIMIZED
Size_restored: SIGNED16 is 0
-- Declared in Windows as SIZEOF_RESTORED

invariant
-- from ANY
reflexive_equality: standard_is_equal (Current)
reflexive_conformance: conforms_to (Current)
end -- class WEL_SIZEOF_CONSTANTS


SetPriorityClass

The SetPriorityClass function sets the priority class for the specified process. This value together with the priority value of each thread of the process determines each thread's base priority level.

BOOLSetPriorityClass(HANDLEhProcess, DWORDdwPriorityClass);

Parameters
hProcess
[in] Handle to the process. The handle must have the PROCESS_SET_INFORMATION access right. For more information, see Process Security and Access Rights.

dwPriorityClass
[in] Priority class for the process. This parameter can be one of the following values. Priority
Meaning
ABOVE_NORMAL_PRIORITY_CLASS
Process that has priority above NORMAL_PRIORITY_CLASS but below HIGH_PRIORITY_CLASS.
Windows NT and Windows Me/98/95:  This value is not supported.

BELOW_NORMAL_PRIORITY_CLASS
Process that has priority above IDLE_PRIORITY_CLASS but below NORMAL_PRIORITY_CLASS.
Windows NT and Windows Me/98/95:  This value is not supported.

HIGH_PRIORITY_CLASS
Process that performs time-critical tasks that must be executed immediately. The threads of the process preempt the threads of normal or idle priority class processes. An example is the Task List, which must respond quickly when called by the user, regardless of the load on the operating system. Use extreme care when using the high-priority class, because a high-priority class application can use nearly all available CPU time.
IDLE_PRIORITY_CLASS
Process whose threads run only when the system is idle. The threads of the process are preempted by the threads of any process running in a higher priority class. An example is a screen saver. The idle-priority class is inherited by child processes.
NORMAL_PRIORITY_CLASS
Process with no special scheduling needs.
REALTIME_PRIORITY_CLASS
Process that has the highest possible priority. The threads of the process preempt the threads of all other processes, including operating system processes performing important tasks. For example, a real-time process that executes for more than a very brief interval can cause disk caches not to flush or cause the mouse to be unresponsive.



Return Values
If the function succeeds, the return value is nonzero.
If the function fails, the return value is zero. To get extended error information, call GetLastError.
Remarks
Every thread has a base priority level determined by the thread's priority value and the priority class of its process. The system uses the base priority level of all executable threads to determine which thread gets the next slice of CPU time. The SetThreadPriority function enables setting the base priority level of a thread relative to the priority class of its process. For more information, see Scheduling Priorities.
Requirements
Client: Included in Windows XP, Windows 2000 Professional, Windows NT Workstation, Windows Me, Windows 98, and Windows 95.
Server: Included in Windows Server 2003, Windows 2000 Server, and Windows NT Server.
Header: Declared in Winbase.h; include Windows.h.
Library: Use Kernel32.lib.

See Also
CreateProcess, CreateThread, GetPriorityClass, GetThreadPriority, Process and Thread Functions, Processes and Threads Overview, SetThreadPriority

   Normal_Priority_Class   : constant := 16#00000020#;
   Idle_Priority_Class     : constant := 16#00000040#;
   High_Priority_Class     : constant := 16#00000080#;
   Realtime_Priority_Class : constant := 16#00000100#; hex numbers !

   ' Flags returned by LocalFlags (in addition to LMEM_DISCARDABLE)
Const LMEM_DISCARDED = &H4000
Const LMEM_LOCKCOUNT = &HFF
'  dwCreationFlag values
Const DEBUG_PROCESS = &H1
Const DEBUG_ONLY_THIS_PROCESS = &H2
Const CREATE_SUSPENDED = &H4
Const DETACHED_PROCESS = &H8
Const CREATE_NEW_CONSOLE = &H10
Const NORMAL_PRIORITY_CLASS = &H20
Const IDLE_PRIORITY_CLASS = &H40
Const HIGH_PRIORITY_CLASS = &H80
Const REALTIME_PRIORITY_CLASS = &H100
*)
