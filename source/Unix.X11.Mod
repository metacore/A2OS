(* ETH Oberon, Copyright 2000 ETH Zürich Institut für Computersysteme, ETH Zentrum, CH-8092 Zürich.
Refer to the general ETH Oberon System license contract available at: http://www.oberon.ethz.ch/ *)

MODULE X11;   (* 1993-95 / rc *)

(* Oberon interface to X Window System Version 11 *)

(*	1998.06.24	g.f.	 Linux PPC version	*)
(*	1999.04.03	g.f.	 support for Threads added	*)
(*	1999.11.03	g.f.	 Linux x86 version	 *)
(*	2001.01.05	g.f.	 [C] - flag for new compiler *)
(*	2001.08.04	g.f.	 made this module a pure interface to xlib,
						 separated low level Display fumctionality into the new module Displays  *)


IMPORT Trace, Unix, Modules;

TYPE
	Pixmap* = ADDRESS;

	Pattern* = ADDRESS (* = PatternPtr *) ;
	PatternPtr* = POINTER TO PatternDesc;
	PatternDesc* = RECORD
				x*, y*: LONGINT;
				w*, h*: INTEGER;
				pixmap*: Pixmap
			END;

	MetricDesc* = RECORD
				dx*, x*, y*, filler: INTEGER;
				p*: PatternDesc
			END;

	Font* = POINTER TO Bytes;
	Bytes* = RECORD
				metrics*: ARRAY 256 OF MetricDesc;
				xid*: LONGINT
			END;

CONST
	BufferSize* = 512;

TYPE
	Buffer* = ARRAY BufferSize OF CHAR;
	ComposeStatus* = RECORD
					 	opaque: ARRAY 6 OF LONGINT
					   END;
	Modifiers* = ARRAY 8 OF KeySym;

	DisplayPtr* = ADDRESS;
	Window* = ADDRESS;
	Drawable* = ADDRESS;
	GC* = ADDRESS;
	Bool* = WORD;
	Colormap* = ADDRESS;
	Time* = ADDRESS;
	Atom* = ADDRESS;

	VisualID* = ADDRESS;
	Visual* = RECORD
				extData*: ADDRESS;
				visualid*: VisualID;
				class*: WORD;
				redMask*, greenMask*, blueMask*: LONGWORD;
				bitsPerRgb*, mapEntries*: WORD
			END;
	VisualPtr* = POINTER {UNSAFE,UNTRACED} TO Visual;
	VisualInfo* = RECORD
				visual*{UNTRACED}:  VisualPtr;
				visualID*: VisualID;
				screen*, depth*, class*: WORD;
				redmask*, greenmask*, bluemask*: LONGWORD;
				colomapsize*, bitsperrgb*: WORD
			END;
	Color* = RECORD
				pixel*: LONGWORD;
				red*, green*, blue*: INTEGER;
				flags*, pad*: CHAR
			END;
	Point* = RECORD
				x*, y*: INTEGER
			END;
	Rectangle* = RECORD
				x*, y*, w*, h*: INTEGER
			END;
	Cursor* = ADDRESS;  KeySym* = ADDRESS;  KeyCode* = CHAR;
	AnyEvent* = RECORD
				typ*: WORD;
				serial*: LONGWORD;
				sendEvent*: Bool;
				display*: DisplayPtr;
				window*: Window;
			END;
	Event* = RECORD (AnyEvent)
				pad*: ARRAY 192 - SIZE OF AnyEvent OF CHAR;
			END;
	SelectionEvent* = RECORD
				typ*: WORD;
				serial*: LONGWORD;
				sendEvent*: Bool;
				display*: DisplayPtr;
				requestor*: Window;
				selection*, target*, property*: Atom;
				time*: Time
			END;
	SelectionRequestEvent* = RECORD
				typ*: WORD;
				serial*: LONGWORD;
				sendEvent*: Bool;
				display*: DisplayPtr;
				owner*, requestor*: Window;
				selection*, target*, property*: Atom;
				time*: Time
			END;
	ExposeEvent* = RECORD
				typ*: WORD;
				serial*: LONGWORD;
				sendEvent*: Bool;
				display*: DisplayPtr;
				window*: Window;
				x*, y*, width*, height*, count*: WORD;
			END;
	GraphicsExposeEvent* = RECORD
				typ*: WORD;
				serial*: LONGWORD;
				sendEvent*: Bool;
				display*: DisplayPtr;
				drawable*: Drawable;
				x*, y*, width*, height*, count*, majorCode*, minorCode*: WORD;
			END;
	ButtonEvent* = RECORD
				typ*: WORD;
				serial*: LONGWORD;
				sendEvent*: Bool;
				display*: DisplayPtr;
				window*, root*, subwindow*: Window;
				time*: Time;
				x*, y*, xRoot*, yRoot*, state*, button: WORD;
				sameScreen: Bool
			END;
	KeyEvent* = RECORD
				typ*: WORD;
				serial*: LONGWORD;
				sendEvent*: Bool;
				display*: DisplayPtr;
				window*, root*, subwindow*: Window;
				time*: Time;
				x*, y*, xRoot*, yRoot*, state*, keycode*: WORD;
				sameScreen: Bool
			END;

	Image* = ADDRESS;
	ImagePtr* = POINTER {UNSAFE,UNTRACED} TO ImageDesc;
	ImageDesc* = RECORD
				width*, height*: WORD;
				xoffset*, format*: WORD; data*: ADDRESS;
				byteOrder*, bitmapUnit*, bitmapBitOrder*: WORD;
				bitmapPad*, depth*, bytesPerLine*, bitsPerPixel*: WORD;
				redmask*, greenmask*, bluemask*: LONGWORD;
				obdata*, createImage*, destroyImage*, getPixel*, putPixel*, subImage*, addPixel*: ADDRESS
			END;
	ErrorEvent* = RECORD
				typ*: WORD;
				display*: DisplayPtr;
				resourceid*: ADDRESS;
				serial*: LONGWORD;
				errorCode*, requestCode*, minorCode*: CHAR
			END;
	ErrorEventPtr* = POINTER {UNSAFE,UNTRACED} TO ErrorEvent;
	ErrorHandler* = PROCEDURE ( d: DisplayPtr;  err: ErrorEventPtr; p3, p4: LONGINT ): LONGINT;
	IOErrorHandler = PROCEDURE ( d: DisplayPtr; p2, p3, p4: LONGINT ): LONGINT;

CONST
	(* X constants: <X11/X.h> *)
	False* = 0;  True* = 1;  None* = 0;
	(* line styles: *)
	LineSolid* = 0;  LineOnOffDash* = 1;  LineDoubleDash* = 2;
	(* cap styles: *)
	CapNotLast* = 0;  CapButt* = 1;  CapRound* = 2;  CapProjecting* = 3;
	(* join styles: *)
	JoinMiter* = 0;  JoinRound* = 1;  JoinBevel* = 2;
	(* fill styles: *)
	FillSolid* = 0;  FillTiled* = 1;  FillStippled* = 2;  FillOpaqueStippled* = 3;
	(* functions: *)
	GXand* = 1;  GXcopy* = 3;  GXxor* = 6;  GXor* = 7;  GXequiv* = 9;
	(* color flags: *)
	DoRed* = 1;  DoGreen* = 2;  DoBlue* = 4;  DoAll* = DoRed + DoGreen + DoBlue;
	(* for CreateColormap : *)
	AllocNone* = 0;  AllocAll* = 1;
	(* QueryBestSize Class: *)
	CursorShape* = 0;  TileShape* = 1;  StippleShape* = 2;
	(* visual classes: *)
	StaticGray* = 0;  GrayScale* = 1;  StaticColor* = 2;  PseudoColor* = 3;  TrueColor* = 4;  DirectColor* = 5;
	(* arc modes: *)
	ArcChord* = 0;  ArcPieSlice* = 1;
	(* polygone shape: *)
	Complex* = 0;  Nonconvex* = 1;  Convex* = 2;
	(* clip odering and origin: *)
	CoordModeOrigin* = 0;  CoordModePrevious* = 1;  Unsorted* = 0;  YSorted* = 1;  YXSorted* = 2;
	YXBanded* = 3;
	(* property modes: *)
	PropModeReplace* = 0;
	(* events types: *)
	KeyPress* = 2;  KeyRelease* = 3;  ButtonPress* = 4;  ButtonRelease* = 5;  MotionNotify* = 6;
	FocusIn* = 9;  FocusOut* = 10;
	Expose* = 12;  GraphicsExpose* = 13;  NoExpose* = 14;  UnmapNotify* = 18;
	MapNotify* = 19;  PropertyNotify* = 28;  SelectionClear* = 29;  SelectionRequest* = 30;
	SelectionNotify* = 31;  ClientMessage* = 33;  MappingNotify* = 34;
	(* event masks: *)
	KeyPressMask* = 1H;  KeyReleaseMask* = 2H;  ButtonPressMask* = 4H;  ButtonReleaseMask* = 8H;
	PointerMotionMask* = 40H;  PointerMotionHintMask* = 80H;  ButtonMotionMask* = 2000H;
	ExposureMask* = 8000H;  StructureNotifyMask* = 20000H;  FocusChangeMask* = 200000H;
	PropertyChangeMask* = 400000H;  OwnerGrabButtonMask* = 1000000H;
	(* event modes:  <X11/Xlib.h> *)
	QueuedAlready* = 0;  QueuedAfterReading* = 1;  QueuedAfterFlush* = 2;
	(* focus revert modes: <X11/X.h> *)
	RevertToParent* = 2;
	(* buttons: *)
	Button1* = 1;  Button2* = 2;  Button3* = 3;
	Button1Mask* = 100H;  Button2Mask* = 200H;  Button3Mask* = 400H;
	(* image format: *)
	XYBitmap* = 0;  XYPixmap* = 1;  ZPixmap* = 2;
	(* special keys: <X11/keysymdef.h> *)
	(* cursor shapes: <X11/cursorfont.h> *)
	XCleftptr* = 132;
	(* atoms: <X11/Xatom.h> *)
	XAPRIMARY* = 1;  XASTRING* = 31;

VAR
	ErrorText*: Buffer;
	ErrorFlag*: BOOLEAN;  lastEventTime*: Time;  ioErrors: INTEGER;

	(* cut and paste *)
	SendSelection*:			 PROCEDURE ( VAR event: SelectionRequestEvent );
	ReceiveSelection*:		 PROCEDURE ( VAR event: SelectionEvent );
	ClearSelection*:			 PROCEDURE;

VAR
	(* Xlib calls: *)
	OpenDisplay-:			PROCEDURE {C} ( name: ADDRESS ): DisplayPtr;
	DefaultScreen-:			PROCEDURE {C} ( d: DisplayPtr ): WORD;
	DisplayWidth-:			PROCEDURE {C} ( d: DisplayPtr;  screen: WORD ): WORD;
	DisplayHeight-:			PROCEDURE {C} ( d: DisplayPtr;  screen: WORD ): WORD;
	DisplayHeightMM-:		PROCEDURE {C} ( d: DisplayPtr;  screen: WORD ): WORD;
	DefaultDepth-:			PROCEDURE {C} ( d: DisplayPtr;  screen: WORD ): WORD;
	DisplayCells-:			PROCEDURE {C} ( d: DisplayPtr;  screen: WORD ): WORD;
	DisplayPlanes-:			PROCEDURE {C} ( d: DisplayPtr;  screen: WORD ): WORD;
	BlackPixel-:			PROCEDURE {C} ( d: DisplayPtr;  screen: WORD ): LONGWORD;
	WhitePixel-:			PROCEDURE {C} ( d: DisplayPtr;  screen: WORD ): LONGWORD;
	DefaultVisual-:			PROCEDURE {C} ( d: DisplayPtr;  screen: WORD ): ADDRESS;
	DefaultColormap-:		PROCEDURE {C} ( d: DisplayPtr;  screen: WORD ): Colormap;
	DefaultRootWindow-:	PROCEDURE {C} ( d: DisplayPtr ): Window;
	CreateSimpleWindow-:	PROCEDURE {C} ( d: DisplayPtr;  parent: Window;
													x, y, width, height, borderWidth: WORD; border, background: LONGWORD ): Window;
	TranslateCoordinates-:	PROCEDURE {C} ( d: DisplayPtr;  sw, dw: Window;  srcx, srcy: WORD;
													VAR dstx, dsty: WORD;  VAR child: Window );
	MoveResizeWindow-:	PROCEDURE {C} ( d: DisplayPtr;  w: Window;  x, y, width, height: WORD );
	StoreName-,
	SetIconName-:			PROCEDURE {C} ( d: DisplayPtr;  w: Window;  name: ADDRESS );
	SetCommand-:			PROCEDURE {C} ( d: DisplayPtr;  w: Window;  argv: ADDRESS;  argc: WORD );
	MapRaised-,
	LowerWindow-,
	ClearWindow-:			PROCEDURE {C} ( d: DisplayPtr;  w: Window );
	Sync-:					PROCEDURE {C} ( d: DisplayPtr;  discard: Bool );
	Flush-:					PROCEDURE {C} ( d: DisplayPtr );
	StoreColor-:				PROCEDURE {C} ( d: DisplayPtr;  cmap: Colormap;  color: ADDRESS );
	CreateBitmapFromData-:
								PROCEDURE {C} ( d: DisplayPtr;  drawable: Drawable;  data: ADDRESS;
													width, height: WORD ): Pixmap;
	CopyArea-:				PROCEDURE {C} ( d: DisplayPtr;  src, dest: Drawable;  gc: GC;
													srcX, srcY, width, height, destX, destY: WORD );
	CopyPlane-:				PROCEDURE {C} ( d: DisplayPtr;  src, dest: Drawable;  gc: GC;
													srcX, srcY, width, height, destX, destY: WORD; plane: LONGWORD );
	SetStipple-:				PROCEDURE {C} ( d: DisplayPtr;  gc: GC;  stipple: Pixmap );
	SetTSOrigin-:			PROCEDURE {C} ( d: DisplayPtr;  gc: GC;  tsxorigin, tsyorigin: WORD );
	DrawPoint-:				PROCEDURE {C} ( d: DisplayPtr;  w: Drawable;  gc: GC;  x, y: WORD );
	FillRectangle-:			PROCEDURE {C} ( d: DisplayPtr;  w: Drawable;  gc: GC;  x, y, width, height: WORD );
	DrawString-:				PROCEDURE {C} ( d: DisplayPtr;  w: Drawable;  gc: GC;  x, y: WORD; string: ADDRESS; length: WORD );
	CreateGC-:				PROCEDURE {C} ( d: DisplayPtr;  drawable: Drawable;  valueMask: LONGWORD; values: ADDRESS ): GC;
	SetForeground-:			PROCEDURE {C} ( d: DisplayPtr;  gc: GC;  foreground: LONGWORD );
	SetBackground-:			PROCEDURE {C} ( d: DisplayPtr;  gc: GC;  background: LONGWORD );
	SetFunction-:			PROCEDURE {C} ( d: DisplayPtr;  gc: GC;  function: WORD );
	SetFont-:			PROCEDURE {C} ( d: DisplayPtr;  gc: GC;  font: ADDRESS );
	SetFillStyle-:			PROCEDURE {C} ( d: DisplayPtr;  gc: GC;  fill_style: WORD );
	SetPlaneMask-:			PROCEDURE {C} ( d: DisplayPtr;  gc: GC;  mask: LONGWORD );
	SetGraphicsExposures-:
								PROCEDURE {C} ( d: DisplayPtr;  gc: GC;  graphicsExposures: Bool );
	SetLineAttributes-:		PROCEDURE {C} ( d: DisplayPtr;  gc: GC;  lineWidth, lineStyle, capStyle, joinStyle: WORD );
	AllocColorCells-:		PROCEDURE {C} ( d: DisplayPtr;  cmap: Colormap;  contig: Bool;  VAR planeMasks: LONGWORD;
													nplanes: WORD;  VAR pixels: LONGWORD;  ncolors: WORD ): WORD;
	SetWindowBackground-:
								PROCEDURE {C} ( d: DisplayPtr;  w: Window;  pixel: LONGWORD );
	CreateFontCursor-:		PROCEDURE {C} ( d: DisplayPtr;  shape: WORD ): Cursor;
	CreatePixmapCursor-:	PROCEDURE {C} ( d: DisplayPtr;  csource, cmask: Pixmap;
													VAR cfore, cback: Color;  xhot, yhot: WORD ): Cursor;
	RecolorCursor-:			PROCEDURE {C} ( d: DisplayPtr;  curs: Cursor;  cfore, cback: ADDRESS );
	DefineCursor-:			PROCEDURE {C} ( d: DisplayPtr;  w: Window;  curs: Cursor );
	DrawLine-:				PROCEDURE {C} ( d: DisplayPtr;  w: Window;  gc: GC;  x1, y1, x2, y2: WORD );
	SetArcMode-:			PROCEDURE {C} ( d: DisplayPtr;  gc: GC;  arcmode: WORD );
	DrawArc-, FillArc-:		PROCEDURE {C} ( d: DisplayPtr;  w: Window;  gc: GC;
													x, y, width, height, angle1, angle2: WORD );
	FillPolygon-:				PROCEDURE {C} ( d: DisplayPtr;  w: Window;  gc: GC;
													points: ADDRESS; npoints, shape, mode: WORD );
	SetClipMask-:			PROCEDURE {C} ( d: DisplayPtr;  gc: GC;  clipMask: Pixmap );
	SetClipRectangles-:	PROCEDURE {C} ( d: DisplayPtr;  gc: GC;
													clipxorigin, clipyorigin: WORD; rectangles: ADDRESS; n, ordering: WORD );
	ListFonts-:				PROCEDURE {C} ( d: DisplayPtr;  pattern: ADDRESS; maxnames: WORD; VAR count: WORD ): ADDRESS;
	FreeFontNames-:		PROCEDURE {C} ( list: ADDRESS );
	LoadFont-:				PROCEDURE {C} ( d: DisplayPtr;  name: ADDRESS ): WORD;
	SelectInput-:				PROCEDURE {C} ( d: DisplayPtr;  w: Window;  eventMask: LONGWORD );
	NextEvent-:				PROCEDURE {C} ( d: DisplayPtr;  VAR event: Event );
	EventsQueued-:			PROCEDURE {C} ( d: DisplayPtr;  mode: WORD ): WORD;
	SetInputFocus-:			PROCEDURE {C} ( d: DisplayPtr;  focus: Window;  revertTo: WORD;  time: Time );
	LookupString-:			PROCEDURE {C} ( VAR event: Event;  VAR buf: Buffer;  bufsize: WORD;
													VAR keysym: KeySym;  VAR cstat: ComposeStatus ): WORD;
	QueryPointer-:			PROCEDURE {C} ( d: DisplayPtr;  w: Window;  VAR rw, cw: Window;
													VAR xr, yr, xw, yw: WORD; VAR keysButtons: WORDSET );
	RefreshKeyboardMapping-:
								PROCEDURE {C} ( event: ADDRESS );
	Bell-:						PROCEDURE {C} ( d: DisplayPtr;  percent: WORD );
	RebindKeysym-:		PROCEDURE {C} ( d: DisplayPtr;  reboundsym: KeySym;  VAR modlist: Modifiers;
													modlength: WORD;  newstring: ADDRESS;  newlength: WORD );
	StringToKeysym-:		PROCEDURE {C} ( string: ADDRESS ): KeySym;
	CopyColormapAndFree-:
								PROCEDURE {C} ( d: DisplayPtr;  cmap: Colormap ): Colormap;
	CreateColormap-:		PROCEDURE {C} ( d: DisplayPtr;  w: Window;  vis: VisualPtr; alloc: WORD ): Colormap;
	MatchVisualInfo-:		PROCEDURE {C} ( d: DisplayPtr;  screen, depth, class: WORD; VAR vinfo: VisualInfo ): WORD;
	SetWindowColormap-:
								PROCEDURE {C} ( d: DisplayPtr;  w: Window;  cmap: Colormap );
	QueryBestSize-:		PROCEDURE {C} ( d: DisplayPtr;  class: WORD;
													screen: Drawable;  width, height: WORD;  VAR w, h: WORD );
	CreatePixmap-:			PROCEDURE {C} ( d: DisplayPtr;  drawable: Drawable;
													width, height, depth: WORD ): Pixmap;
	FreePixmap-:			PROCEDURE {C} ( d: DisplayPtr;  pixmap: Pixmap );
	CreateImage-:			PROCEDURE {C} ( d: DisplayPtr;  visual: VisualPtr;  depth, format, offset: WORD;
													data: ADDRESS;  width, height, bitmapPad, bytesPerLine: WORD ): Image;
	DestroyImage-:			PROCEDURE {C} ( image: Image );
	SubImage-:				PROCEDURE {C} ( image: Image;  x, y, width, height: WORD ): Image;
	GetImage-:				PROCEDURE {C} ( d: DisplayPtr;  drawable: Drawable;
													x, y, width, height: WORD; planeMask: LONGWORD; format: WORD ): Image;
	GetSubImage-:			PROCEDURE {C} ( d: DisplayPtr;  drawable: Drawable;
													x, y, width, height: WORD; planeMask: LONGWORD; format: WORD;  dstImage: Image;
													dstX, dstY: WORD ): Image;
	PutImage-:				PROCEDURE {C} ( d: DisplayPtr;  drawable: Drawable;  gc: GC;  image: Image;
													srcX, srcY, dstX, dstY, width, height: WORD );
	PutPixel-:				PROCEDURE {C} ( image: Image;  x, y: WORD; pixel: LONGWORD ): WORD;
	GetPixel-:				PROCEDURE {C} ( image: Image;  x, y: WORD ): LONGWORD;
	AddPixel-:				PROCEDURE {C} ( image: Image;  value: LONGWORD );
	Free-:						PROCEDURE {C} ( data: ADDRESS );
(*	SetErrorHandler-:		PROCEDURE {C} ( handler: ErrorHandler );	*)
	GetErrorText-:			PROCEDURE {C} ( d: DisplayPtr;  errcode: WORD; VAR buf: Buffer; length: WORD );
	StoreBytes-:				PROCEDURE {C} ( d: DisplayPtr;  bytes: ADDRESS; nbytes: WORD );
	FetchBytes-:			PROCEDURE {C} ( d: DisplayPtr;  VAR nbytes: WORD ): ADDRESS;
	SetSelectionOwner-:	PROCEDURE {C} ( d: DisplayPtr;  selection: Atom;  owner: Window;  time: Time );
	GetSelectionOwner-:	PROCEDURE {C} ( d: DisplayPtr;  selection: Atom ): Window;
	InternAtom-:				PROCEDURE {C} ( d: DisplayPtr;  name: ADDRESS;  onlyifexists: Bool ): Atom;
	SendEvent-:				PROCEDURE {C} ( d: DisplayPtr;  w: Window;  propagate: Bool;  eventmask: LONGWORD;  event: ADDRESS );
	ConvertSelection-:		PROCEDURE {C} ( d: DisplayPtr;  selection, target, property: Atom;
													requestor: Window;  timestamp: Time );
	ChangeProperty-:		PROCEDURE {C} ( d: DisplayPtr;  w: Window;  property, typ: Atom;
													format, mode: WORD; data: ADDRESS; nelements: WORD );
	GetWindowProperty-:
								PROCEDURE {C} ( d: DisplayPtr;  w: Window;  property: Atom;
													offset, length: LONGWORD;  delete: Bool;  reqtype: Atom;  VAR typ: Atom;
													VAR format: WORD; VAR nitems, bytesafter: LONGWORD;  VAR prop: ADDRESS );
	DeleteProperty-:			PROCEDURE {C} ( d: DisplayPtr;  w: Window;  property: Atom );
	WarpPointer-:			PROCEDURE {C} ( d: DisplayPtr;  srcwin, dstwin: Window;  srcx, srcy, srcw, srch, dstx, dsty: WORD );
	InstallColormap-:		PROCEDURE {C} ( d: DisplayPtr;  cmap: Colormap );
	GetGeometry-:			PROCEDURE {C} ( d: DisplayPtr;  drawable: Drawable; VAR root, x, y, width, height, orderWidth, Depth: WORD );
	ResizeWindow-:			PROCEDURE {C} ( d: DisplayPtr;  w: Window;  x, y: WORD );
	Synchronize-:			PROCEDURE {C} ( d: DisplayPtr;  onoff: Bool );
	AllocColor-:				PROCEDURE {C} ( d: DisplayPtr;  cmap: Colormap;  color: ADDRESS ): WORD;
(*	SetIOErrorHandler-:		PROCEDURE {C} ( handler: IOErrorHandler );	*)
	InitXErrorHandlers-:		PROCEDURE {C} ( eh: ErrorHandler; ioeh: IOErrorHandler );



	PROCEDURE LinkToX;
	VAR xlib: ADDRESS;
	BEGIN
		Unix.LinkToX;
		xlib := Unix.Dlopen( Unix.libX11name, 2 );
		IF xlib = 0 THEN  (* try default version *)
		 xlib := Unix.Dlopen( "libX11.so", 2 )
		END;
		IF xlib = 0 THEN
			Trace.StringLn( "X11.LinkToX:  Unix.Dlopen( libX11.so ) failed " );  Unix.exit( 3 )
		END;

		Unix.Dlsym( xlib, "XOpenDisplay", ADDRESSOF( OpenDisplay ) );
		Unix.Dlsym( xlib, "XDefaultScreen", ADDRESSOF( DefaultScreen ) );
		Unix.Dlsym( xlib, "XDisplayWidth", ADDRESSOF( DisplayWidth ) );
		Unix.Dlsym( xlib, "XDisplayHeight", ADDRESSOF( DisplayHeight ) );
		Unix.Dlsym( xlib, "XDisplayHeightMM", ADDRESSOF( DisplayHeightMM ) );
		Unix.Dlsym( xlib, "XDefaultDepth", ADDRESSOF( DefaultDepth ) );
		Unix.Dlsym( xlib, "XDisplayCells", ADDRESSOF( DisplayCells ) );
		Unix.Dlsym( xlib, "XDisplayPlanes", ADDRESSOF( DisplayPlanes ) );
		Unix.Dlsym( xlib, "XBlackPixel", ADDRESSOF( BlackPixel ) );
		Unix.Dlsym( xlib, "XWhitePixel", ADDRESSOF( WhitePixel ) );
		Unix.Dlsym( xlib, "XDefaultVisual", ADDRESSOF( DefaultVisual ) );
		Unix.Dlsym( xlib, "XDefaultColormap", ADDRESSOF( DefaultColormap ) );
		Unix.Dlsym( xlib, "XDefaultRootWindow", ADDRESSOF( DefaultRootWindow ) );
		Unix.Dlsym( xlib, "XCreateSimpleWindow", ADDRESSOF( CreateSimpleWindow ) );
		Unix.Dlsym( xlib, "XTranslateCoordinates", ADDRESSOF( TranslateCoordinates ) );
		Unix.Dlsym( xlib, "XMoveResizeWindow", ADDRESSOF( MoveResizeWindow ) );
		Unix.Dlsym( xlib, "XStoreName", ADDRESSOF( StoreName ) );
		Unix.Dlsym( xlib, "XSetIconName", ADDRESSOF( SetIconName ) );
		Unix.Dlsym( xlib, "XSetCommand", ADDRESSOF( SetCommand ) );
		Unix.Dlsym( xlib, "XMapRaised", ADDRESSOF( MapRaised ) );
		Unix.Dlsym( xlib, "XLowerWindow", ADDRESSOF( LowerWindow ) );
		Unix.Dlsym( xlib, "XClearWindow", ADDRESSOF( ClearWindow ) );
		Unix.Dlsym( xlib, "XSync", ADDRESSOF( Sync ) );  Unix.Dlsym( xlib, "XFlush", ADDRESSOF( Flush ) );
		Unix.Dlsym( xlib, "XStoreColor", ADDRESSOF( StoreColor ) );
		Unix.Dlsym( xlib, "XCreateBitmapFromData", ADDRESSOF( CreateBitmapFromData ) );
		Unix.Dlsym( xlib, "XCopyArea", ADDRESSOF( CopyArea ) );
		Unix.Dlsym( xlib, "XCopyPlane", ADDRESSOF( CopyPlane ) );
		Unix.Dlsym( xlib, "XSetStipple", ADDRESSOF( SetStipple ) );
		Unix.Dlsym( xlib, "XSetTSOrigin", ADDRESSOF( SetTSOrigin ) );
		Unix.Dlsym( xlib, "XFillRectangle", ADDRESSOF( FillRectangle ) );
		Unix.Dlsym( xlib, "XDrawPoint", ADDRESSOF( DrawPoint ) );
		Unix.Dlsym( xlib, "XDrawString", ADDRESSOF( DrawString ) );
		Unix.Dlsym( xlib, "XCreateGC", ADDRESSOF( CreateGC ) );
		Unix.Dlsym( xlib, "XSetForeground", ADDRESSOF( SetForeground ) );
		Unix.Dlsym( xlib, "XSetBackground", ADDRESSOF( SetBackground ) );
		Unix.Dlsym( xlib, "XSetPlaneMask", ADDRESSOF( SetPlaneMask ) );
		Unix.Dlsym( xlib, "XSetLineAttributes", ADDRESSOF( SetLineAttributes ) );
		Unix.Dlsym( xlib, "XSetFunction", ADDRESSOF( SetFunction ) );
		Unix.Dlsym( xlib, "XSetFont", ADDRESSOF( SetFont ) );
		Unix.Dlsym( xlib, "XSetFillStyle", ADDRESSOF( SetFillStyle ) );
		Unix.Dlsym( xlib, "XSetGraphicsExposures", ADDRESSOF( SetGraphicsExposures ) );
		Unix.Dlsym( xlib, "XAllocColorCells", ADDRESSOF( AllocColorCells ) );
		Unix.Dlsym( xlib, "XSetWindowBackground", ADDRESSOF( SetWindowBackground ) );
		Unix.Dlsym( xlib, "XCreateFontCursor", ADDRESSOF( CreateFontCursor ) );
		Unix.Dlsym( xlib, "XCreatePixmapCursor", ADDRESSOF( CreatePixmapCursor ) );
		Unix.Dlsym( xlib, "XRecolorCursor", ADDRESSOF( RecolorCursor ) );
		Unix.Dlsym( xlib, "XDefineCursor", ADDRESSOF( DefineCursor ) );
		Unix.Dlsym( xlib, "XDrawLine", ADDRESSOF( DrawLine ) );
		Unix.Dlsym( xlib, "XSetArcMode", ADDRESSOF( SetArcMode ) );
		Unix.Dlsym( xlib, "XDrawArc", ADDRESSOF( DrawArc ) );
		Unix.Dlsym( xlib, "XFillArc", ADDRESSOF( FillArc ) );
		Unix.Dlsym( xlib, "XFillPolygon", ADDRESSOF( FillPolygon ) );
		Unix.Dlsym( xlib, "XSetClipMask", ADDRESSOF( SetClipMask ) );
		Unix.Dlsym( xlib, "XSetClipRectangles", ADDRESSOF( SetClipRectangles ) );
		Unix.Dlsym( xlib, "XListFonts", ADDRESSOF( ListFonts ) );
		Unix.Dlsym( xlib, "XFreeFontNames", ADDRESSOF( FreeFontNames ) );
		Unix.Dlsym( xlib, "XLoadFont", ADDRESSOF( LoadFont ) );
		Unix.Dlsym( xlib, "XSelectInput", ADDRESSOF( SelectInput ) );
		Unix.Dlsym( xlib, "XSync", ADDRESSOF( Sync ) );
		Unix.Dlsym( xlib, "XNextEvent", ADDRESSOF( NextEvent ) );
		Unix.Dlsym( xlib, "XEventsQueued", ADDRESSOF( EventsQueued ) );
		Unix.Dlsym( xlib, "XSetInputFocus", ADDRESSOF( SetInputFocus ) );
		Unix.Dlsym( xlib, "XLookupString", ADDRESSOF( LookupString ) );
		Unix.Dlsym( xlib, "XQueryPointer", ADDRESSOF( QueryPointer ) );
		Unix.Dlsym( xlib, "XRefreshKeyboardMapping", ADDRESSOF( RefreshKeyboardMapping ) );
		Unix.Dlsym( xlib, "XBell", ADDRESSOF( Bell ) );
		Unix.Dlsym( xlib, "XRebindKeysym", ADDRESSOF( RebindKeysym ) );
		Unix.Dlsym( xlib, "XStringToKeysym", ADDRESSOF( StringToKeysym ) );
		Unix.Dlsym( xlib, "XCopyColormapAndFree", ADDRESSOF( CopyColormapAndFree ) );
		Unix.Dlsym( xlib, "XCreateColormap", ADDRESSOF( CreateColormap ) );
		Unix.Dlsym( xlib, "XMatchVisualInfo", ADDRESSOF( MatchVisualInfo ) );
		Unix.Dlsym( xlib, "XSetWindowColormap", ADDRESSOF( SetWindowColormap ) );
		Unix.Dlsym( xlib, "XQueryBestSize", ADDRESSOF( QueryBestSize ) );
		Unix.Dlsym( xlib, "XCreatePixmap", ADDRESSOF( CreatePixmap ) );
		Unix.Dlsym( xlib, "XFreePixmap", ADDRESSOF( FreePixmap ) );
		Unix.Dlsym( xlib, "XCreateImage", ADDRESSOF( CreateImage ) );
		Unix.Dlsym( xlib, "XDestroyImage", ADDRESSOF( DestroyImage ) );
		Unix.Dlsym( xlib, "XSubImage", ADDRESSOF( SubImage ) );
		Unix.Dlsym( xlib, "XGetImage", ADDRESSOF( GetImage ) );
		Unix.Dlsym( xlib, "XGetSubImage", ADDRESSOF( GetSubImage ) );
		Unix.Dlsym( xlib, "XPutImage", ADDRESSOF( PutImage ) );
		Unix.Dlsym( xlib, "XPutPixel", ADDRESSOF( PutPixel ) );
		Unix.Dlsym( xlib, "XGetPixel", ADDRESSOF( GetPixel ) );
		Unix.Dlsym( xlib, "XAddPixel", ADDRESSOF( AddPixel ) );
		Unix.Dlsym( xlib, "XFree", ADDRESSOF( Free ) );
	(*	Unix.Dlsym( xlib, "XSetErrorHandler", ADDRESSOF( SetErrorHandler ) )	*)
	(*	Unix.Dlsym( xlib, "XSetIOErrorHandler", ADDRESSOF( SetIOErrorHandler ) );	*)
		Unix.Dlsym( xlib, "XGetErrorText", ADDRESSOF( GetErrorText ) );
		Unix.Dlsym( xlib, "XStoreBytes", ADDRESSOF( StoreBytes ) );
		Unix.Dlsym( xlib, "XFetchBytes", ADDRESSOF( FetchBytes ) );
		Unix.Dlsym( xlib, "XSetSelectionOwner", ADDRESSOF( SetSelectionOwner ) );
		Unix.Dlsym( xlib, "XGetSelectionOwner", ADDRESSOF( GetSelectionOwner ) );
		Unix.Dlsym( xlib, "XInternAtom", ADDRESSOF( InternAtom ) );
		Unix.Dlsym( xlib, "XSendEvent", ADDRESSOF( SendEvent ) );
		Unix.Dlsym( xlib, "XConvertSelection", ADDRESSOF( ConvertSelection ) );
		Unix.Dlsym( xlib, "XChangeProperty", ADDRESSOF( ChangeProperty ) );
		Unix.Dlsym( xlib, "XGetWindowProperty", ADDRESSOF( GetWindowProperty ) );
		Unix.Dlsym( xlib, "XDeleteProperty", ADDRESSOF( DeleteProperty ) );
		Unix.Dlsym( xlib, "XWarpPointer", ADDRESSOF( WarpPointer ) );
		Unix.Dlsym( xlib, "XInstallColormap", ADDRESSOF( InstallColormap ) );
		Unix.Dlsym( xlib, "XGetGeometry", ADDRESSOF( GetGeometry ) );
		Unix.Dlsym( xlib, "XResizeWindow", ADDRESSOF( ResizeWindow ) );
		Unix.Dlsym( xlib, "XSynchronize", ADDRESSOF( Synchronize ) );
		Unix.Dlsym( xlib, "XAllocColor", ADDRESSOF( AllocColor ) );
	END LinkToX;

	PROCEDURE MyErrorHandler( d: DisplayPtr;  err {UNTRACED}: ErrorEventPtr ): LONGINT;
	BEGIN
		ErrorFlag := TRUE;
		GetErrorText( d, ORD( err.errorCode ), ErrorText, BufferSize );
		Trace.StringLn(  ErrorText );
		RETURN 0
	END MyErrorHandler;

	PROCEDURE MyIOErrorHandler( d: DisplayPtr): LONGINT;
	BEGIN
		ErrorFlag := TRUE;  ErrorText := "X11 I/O Error";
		Trace.StringLn( ErrorText );
		INC( ioErrors );
		RETURN 0
	END MyIOErrorHandler;

BEGIN
	ioErrors := 0;  LinkToX;  ErrorFlag := FALSE;

	(*SetIOErrorHandler( MyIOErrorHandler );*)
	(*SetErrorHandler( MyErrorHandler );*)
			(* Oberon procedures cannot be used as callback procedures because of
				incompatibilities between the PPC Oberon ABI and the PPC SYSV ABI.
				PPC Oberon follows the old MAC and IBM AIX ABI *)
	Unix.InitXErrorHandlers( MyErrorHandler, MyIOErrorHandler );
END X11.
