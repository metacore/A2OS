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

	XID* = ADDRESS;

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
				x*, y*, xRoot*, yRoot*, state*, button*: WORD;
				sameScreen: Bool
			END;
	KeyEvent* = RECORD
				typ*: WORD;
				serial*: LONGWORD;
				sendEvent*: Bool;
				display*: DisplayPtr;
				window*, root*, subwindow*: Window;
				time*: Time;
				x*, y*, xRoot*, yRoot*: WORD;
				state*: WORDSET;
				keycode*: WORD;
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

	Data40 * = ARRAY 5 OF LONGWORD; (* max of these is 40 bytes*)
	Data40b* = ARRAY 20 OF CHAR; (* 20x 8 bits *)
	Data40s* = ARRAY 10 OF INTEGER; (* 10x 16 bits *)
	Data40l* = ARRAY 5 OF LONGINT; (* 5x 32 bits *)

	ClientMessageEvent * = RECORD
		typ* : WORD;
		serial* : LONGWORD(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		window* : Window;
		messageType* : Atom;
		format* : WORD;
		data*: Data40;
			(* any of these, union
			b* : ARRAY 20 OF CHAR;
			s* : ARRAY 10 OF INTEGER;
			l* : ARRAY 5 OF LONGINT;
			*)
	END;

	ConfigureEvent * = RECORD
		typ* : WORD;
		serial* : LONGWORD(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		event* : Window;
		window* : Window;
		x*, y* : WORD;
		width*, height* : WORD;
		borderWidth* : WORD;
		above* : Window;
		overrideRedirect* : BOOLEAN;
	END;



	ErrorEventPtr* = POINTER {UNSAFE,UNTRACED} TO ErrorEvent;
	ErrorHandler* = PROCEDURE ( d: DisplayPtr;  err: ErrorEventPtr; p3, p4: LONGINT ): LONGINT;
	IOErrorHandler = PROCEDURE ( d: DisplayPtr; p2, p3, p4: LONGINT ): LONGINT;

	PChar* = POINTER TO ARRAY OF CHAR;

	VisualInfoPtr*  = POINTER {UNSAFE, UNTRACED} TO VisualInfo;

TYPE
	XSetWindowAttributes* = RECORD
		backgroundPixmap*: Pixmap; (* background, None, or ParentRelative *)
		backgroundPixel*: LONGWORD;(* background pixel *)
		borderPixmap*: Pixmap;    (* border of the window or CopyFromParent *)
		borderPixel*: LONGWORD;(* border pixel value *)
		bitGravity*: WORD;         (* one of bit gravity values *)
		winGravity*: WORD;         (* one of the window gravity values *)
		backingStore*: WORD;       (* NotUseful, WhenMapped, Always *)
		backingPlanes*: LONGWORD;(* planes to be preserved if possible *)
		backingPixel*: LONGWORD;(* value to use in restoring planes *)
		saveUnder*: BOOLEAN;         (* should bits under be saved? (popups) *)
		eventMask*:  LONGWORD;         (* set of events that should be saved *)
		doNotPropagateMask*: LONGWORD;(* set of events that should not propagate *)
		overrideRedirect*: BOOLEAN;  (* boolean value for override_redirect *)
		colormap*: Colormap;       (* color map to be associated with window *)
		cursor*: Cursor ;           (* cursor to be displayed (or None) *)
	END ;

	XWindowAttributes* = RECORD
		x*, y*: WORD;			(* location of window *)
		width*, height*: WORD;		(* width and height of window *)
		borderWidth*: WORD;			(* border width of window *)
		depth*: WORD;			(* depth of window *)
		visual* : VisualPtr;			(* the associated visual structure *)
		root* : Window;				(* root of screen containing window *)
		class*: WORD;			(* InputOutput, InputOnly*)
		bitGravity*: WORD;			(* one of the bit gravity values *)
		winGravity*: WORD;			(* one of the window gravity values *)
		backingStore*: WORD;		(* NotUseful, WhenMapped, Always *)
		backingPlanes*: LONGWORD;		(* planes to be preserved if possible *)
		backingPixel*: LONGWORD;		(* value to be used when restoring planes *)
		saveUnder*: BOOLEAN;			(* boolean, should bits under be saved? *)
		colormap*: Colormap;			(* color map to be associated with window *)
		mapInstalled*: BOOLEAN;		(* boolean, is color map currently installed*)
		mapState*: WORD;		(* IsUnmapped, IsUnviewable, IsViewable *)
		allEventMasks*: LONGWORD;		(* set of events all people have interest in*)
		yourEventMask*: LONGWORD;		(* my event mask *)
		doNotPropagateMask*: LONGWORD;	(* set of events that should not propagate *)
		overrideRedirect*: BOOLEAN;		(* boolean value for override-redirect *)
		screen*: ADDRESS; (*X11.Screen;*)			(* back pointer to correct screen *)
	END;

	(* Data structure for host setting; getting routines. *)
	TYPE XHostAddress* = RECORD
			family* : WORD;		(* for example FamilyInternet *)
			length* : WORD;		(* length of address, in bytes *)
			address*: ADDRESS;		(* pointer to where to find the bytes *)
		END;

	(* Data structure for ServerFamilyInterpreted addresses in host routines *)
	TYPE XServerInterpretedAddress* = RECORD
			typelength*: WORD;		(* length of type string, in bytes *)
			valuelength*: WORD;	(* length of value string, in bytes *)
			type*: ADDRESS;		(* pointer to where to find the type string *)
			value*: ADDRESS;		(* pointer to where to find the address *)
		END;


	(* Data structure for XReconfigureWindow *)
	TYPE XWindowChanges * = RECORD
			x*, y*: WORD;
			width*, height* : WORD;
	 	   	borderWidth*: WORD;
			sibling* : Window;
	 	   	stackMode*: WORD;
		END;


	(* new version containing base_width, base_height, and win_gravity fields;
	  used with WM_NORMAL_HINTS.
	 *)
	TYPE DataAspect*=RECORD
			x*: WORD;	(* numerator *)
			y*: WORD;	(* denominator *)
		END;

	TYPE XSizeHints* = RECORD
			flags*: LONGWORD;	(* marks which fields in this structure are defined *) (* HUGEINT ?*)
			x*, y*: WORD;		(* obsolete for new window mgrs, but clients *)
			width*, height*: WORD;	(* should set so old wm's don't mess up *)
			minWidth*, minHeight*: WORD;
			maxWidth*, maxHeight*: WORD;
			widthInc*, heightInc*: WORD;
			maxAspect*, minAspect*: DataAspect;
			baseWidth*, baseHeight*: WORD;		(* added by ICCCM version 1 *)
			winGravity*: WORD;			(* added by ICCCM version 1 *)
		END;

	(*  The next block of definitions are for window manager properties that
	  clients and applications use for communication. *)

	(* flags argument in size hints *)
	CONST
		USPosition * =  1H; (* user specified x, y *)
		USSize * =   2H; (* user specified width, height *)
		PPosition * =  4H; (* program specified position *)
		PSize * =   8H; (* program specified size *)
		PMinSize * =   10H; (* program specified minimum size *)
		PMaxSize * =   20H; (* program specified maximum size *)
		PResizeInc * =   40H; (* program specified resize increments *)
		PAspect * =   80H; (* program specified min and max aspect ratios *)
		PBaseSize * =   100H; (* program specified base for incrementing *)
		PWinGravity * =  200H; (* program specified window gravity *)

CONST
(* Action for EWMH client messages *)
	NET_WM_STATE_REMOVE* = 0;
	NET_WM_STATE_ADD* =1;
	NET_WM_STATE_TOGGLE* = 2;

	(*! ----------FONTS, from Xutil.h ------------------ *)

TYPE

	(* Extensions need a way to hang private data on some structures.
	called to free private storage
		free_private_proc* = PROCEDURE (extension: ExtData): LONGINT;*)

	ExtData* = POINTER {UNTRACED, UNSAFE} TO ExtDataDesc;
	ExtDataDesc* = RECORD
		number*: WORD;		(* number returned by XRegisterExtension *)
		next*: ExtData;	(* next item on list of data for structure *)
		free_private*: ADDRESS;	(* called to free private storage *)
		extension* : ExtData;
		private_data*: ADDRESS;	(* data private to this extension. *)
	END;

	(* per character font metric information. *)
	CharStruct* = RECORD
		lbearing*: INTEGER;	(* origin to left edge of raster *)
		rbearing*: INTEGER;	(* origin to right edge of raster *)
		width*: INTEGER;		(* advance to next char's origin *)
		ascent*: INTEGER;		(* baseline to top edge of raster *)
		descent*: INTEGER;	(* baseline to bottom edge of raster *)
		attributes*: INTEGER;	(* per char flags (not predefined) *)
	END;

	(* To allow arbitrary information with fonts, there are additional properties returned. *)
	FontProp* = RECORD
		name*: Atom;
		card32*: LONGWORD;
	END;

	FontStruct* = POINTER  {UNTRACED, UNSAFE} TO FontStructDesc;
	FontStructDesc* = RECORD
		ext_data*: ExtData;	(* hook for extension to hang data *)
		fid*: Font;            (* Font id for this font *)
		direction*: WORD;	(* hint about direction the font is painted *)
		min_char_or_byte2*: WORD;(* first character *)
		max_char_or_byte2*: WORD;(* last character *)
		min_byte1*: WORD;	(* first row that exists *)
		max_byte1*: WORD;	(* last row that exists *)
		all_chars_exist*: Bool;(* flag if all characters have non-zero size*)
		default_char*: WORD;	(* char to print for undefined character *)
		n_properties*: WORD;   (* how many properties there are *)
		properties*: ADDRESS; (*POINTER TO ARRAY OF FontProp; *)	(* pointer to array of additional properties*)
		min_bounds*: CharStruct;	(* minimum bounds over all existing char*)
		max_bounds*: CharStruct;	(* maximum bounds over all existing char*)
		per_char*: ADDRESS; (*POINTER TO ARRAY OF CharStruct;*)	(* first_char to last_char information *)
		ascent*: WORD;		(* log. extent above baseline for spacing *)
		descent*: WORD;	(* log. descent below baseline for spacing *)
	END;


	(* new structure for manipulating TEXT properties; used with WM_NAME,
		WM_ICON_NAME, WM_CLIENT_MACHINE, and WM_COMMAND. *)
	XTextProperty* = RECORD
		value*: ADDRESS;		(* same as Property routines *)
		encoding*: Atom;		(* prop type *)
		format*: WORD;	(* prop data format: 8, 16, or 32 *)
		nitems*: LONGWORD;	(* number of data items in value *)
	END;

(*! ------------------- ends  Xutil.h ----------- *)

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
	NoEventMask* = 0H;  KeyPressMask* = 1H; KeyReleaseMask* = 2H;
	ButtonPressMask* = 4H;  ButtonReleaseMask* = 8H;  EnterWindowMask* = 10H;
	LeaveWindowMask* = 20H;  PointerMotionMask* = 40H;  PointerMotionHintMask* = 80H;
	Button1MotionMask* = 100H; Button2MotionMask* = 200H; Button3MotionMask* = 400H;
	Button4MotionMask* = 800H;  Button5MotionMask* = 1000H;  ButtonMotionMask* = 2000H;
	KeymapStateMask* = 4000H; ExposureMask* = 8000H; VisibilityChangeMask* = 10000H;
	StructureNotifyMask* = 20000H; ResizeRedirectMask* = 40000H; SubstructureNotifyMask* = 80000H;
	SubstructureRedirectMask* = 100000H; FocusChangeMask * = 200000H; PropertyChangeMask* = 400000H;
	ColormapChangeMask* = 800000H; OwnerGrabButtonMask* = 1000000H;
	(* event modes:  <X11/Xlib.h> *)
	QueuedAlready* = 0;  QueuedAfterReading* = 1;  QueuedAfterFlush* = 2;
	(* focus revert modes: <X11/X.h> *)
	RevertToParent* = 2;
	(* buttons: *)
	Button1* = 1;  Button2* = 2;  Button3* = 3; Button4* = 4; Button5* = 5;

	Button1Mask* = 8; Button2Mask* = 9; Button3Mask* = 10; Button4Mask* = 11; Button5Mask* = 12;
	(* image format: *)
	XYBitmap* = 0;  XYPixmap* = 1;  ZPixmap* = 2;
	(* special keys: <X11/keysymdef.h> *)
	(* cursor shapes: <X11/cursorfont.h> *)
	XCleftptr* = 132;
	(* atoms: <X11/Xatom.h> *)
	XAPRIMARY* = 1;  XASTRING* = 31;
	(* Cursor control & motion *)
	(* X11/keysymdef.h *)
CONST

	XK_Home* = 	0FF50H;
	XK_Left* = 	0FF51H;  (* Move left, left arrow *)
	XK_Up* = 	0FF52H;  (* Move up, up arrow *)
	XK_Right* = 	0FF53H;  (* Move right, right arrow *)
	XK_Down* = 	0FF54H;  (* Move down, down arrow *)
	XK_Prior* = 	0FF55H;  (* Prior, previous *)
	XK_Page_Up* = 	0FF55H;
	XK_Next* = 	0FF56H;  (* Next *)
	XK_Page_Down* = 0FF56H;
	XK_End* = 	0FF57H;  (* EOL *)
	XK_Begin* = 	0FF58H;  (* BOL *)

	XK_Escape* = 0FF1BH;
	XK_F1* =0FFBEH;

	(*  X11/X.h *)
(* ****************************************************************
                       RESERVED RESOURCE AND CONSTANT DEFINITIONS
**************************************************************** *)

	ParentRelative* = 1;	(* background pixmap in CreateWindow
					    and ChangeWindowAttributes *)
	CopyFromParent* = 0;	(* border pixmap in CreateWindow
					       and ChangeWindowAttributes
					   special VisualID and special window
					       class passed to CreateWindow *)
	PointerWindow* = 0;	(* destination window in SendEvent *)
	InputFocus* = 1;	(* destination window in SendEvent *)
	PointerRoot* = 1;	(* focus window in SetInputFocus *)
	AnyPropertyType* = 0;	(* special Atom, passed to GetProperty *)
	AnyKey* = 0;	(* special Key Code, passed to GrabKey *)
	AnyButton* = 0;	(* special Button Code, passed to GrabButton *)
	AllTemporary* = 0;	(* special Resource ID passed to KillClient *)
	CurrentTime* = 0;	(* special Time *)
	NoSymbol* = 0;	(* special KeySym *)


	(* EVENT DEFINITIONS
	  Input Event Masks. Used as event-mask window attribute and as arguments
	   to Grab requests.  Not to be confused with event names. *)

CONST

	(* Event names.  Used in "type" field in XEvent structures.  Not to be
	confused with event masks above.  They start from 2 because 0 and 1
	are reserved in the protocol for errors and replies. *)

CONST

	EnterNotify* = 7; LeaveNotify* =8;  KeymapNotify* = 11;VisibilityNotify* = 15;
	CreateNotify* = 16; DestroyNotify* = 17;
	MapRequest* = 20;  ReparentNotify* = 21; ConfigureNotify* = 22; ConfigureRequest* = 23;
	GravityNotify* = 24; ResizeRequest* =	25; CirculateNotify* = 26; CirculateRequest* = 27;
	LASTEvent* =		36;	 (* must be bigger than any event # *)


	(* Key masks. Used as modifiers to GrabButton and GrabKey, results of QueryPointer,
	state in various key-, mouse-, and button-related events. *)

	ShiftMask* = 0;  LockMask* = 1;  ControlMask* = 2;
	Mod1Mask* = 3;  Mod2Mask* = 4;  Mod3Mask* = 5;
	Mod4Mask* = 6;   Mod5Mask* = 7;

	(* modifier names.  Used to build a SetModifierMapping request or
	to read a GetModifierMapping request.  These correspond to the
	masks defined above. *)
	ShiftMapIndex* =	0;  LockMapIndex* = 1; ControlMapIndex* = 2;
	Mod1MapIndex* =	3; Mod2MapIndex* = 4; Mod3MapIndex* = 5;
	Mod4MapIndex* =	6; Mod5MapIndex* = 7;

	AnyModifier* = 15;  (* used in GrabButton, GrabKey *)

	(* button names. Used as arguments to GrabButton and as detail in ButtonPress
	and ButtonRelease events.  Not to be confused with button masks above.
	Note that 0 is already defined above as "AnyButton".  *)


	(* Notify modes *)
	NotifyNormal* = 0; NotifyGrab* = 1; NotifyUngrab* = 2; NotifyWhileGrabbed* =	3;

	NotifyHint* = 1; (* for MotionNotify events *)

	(* Notify detail *)
	NotifyAncestor* = 0; NotifyVirtual* = 1; NotifyInferior* = 2; NotifyNonlinear* = 3;
	NotifyNonlinearVirtual* = 4; NotifyPointer* = 5; NotifyPointerRoot* = 6;
	NotifyDetailNone* = 7;

	(* Visibility notify *)
	VisibilityUnobscured* =  0; VisibilityPartiallyObscured* = 1; VisibilityFullyObscured* = 2;

	(* Circulation request *)
	PlaceOnTop* = 0; PlaceOnBottom* = 1;

	(* protocol families *)
	FamilyInternet* = 0; (* IPv4 *)  FamilyDECnet* = 1;  FamilyChaos* = 2; FamilyInternet6* = 6; (* IPv6 *)

	(* authentication families not tied to a specific protocol *)
	FamilyServerInterpreted* = 5;

	(* Property notification *)
	PropertyNewValue* = 0;  PropertyDelete* = 1;

	(* Color Map notification *)
	ColormapUninstalled* = 0; ColormapInstalled* = 1;

	(* GrabPointer, GrabButton, GrabKeyboard, GrabKey Modes *)
	GrabModeSync* = 0;  GrabModeAsync* = 1;

	(* GrabPointer, GrabKeyboard reply status *)
	GrabSuccess* = 0; AlreadyGrabbed* = 1; GrabInvalidTime* = 2; GrabNotViewable* = 3; GrabFrozen* = 4;

	(* AllowEvents modes *)
	AsyncPointer* = 0; SyncPointer* = 1; ReplayPointer* = 2; AsyncKeyboard* = 3;
	SyncKeyboard* = 4; ReplayKeyboard* = 5; AsyncBoth* = 6; SyncBoth* = 7;

	(* Used in SetInputFocus, GetInputFocus *)
	RevertToNone* = None;  RevertToPointerRoot* = PointerRoot;



(* ****************************************************************
						 ERROR CODES
 **************************************************************** *)

CONST
	Success* =	 0; (* everything's okay *)
	BadRequest* = 1; (* bad request code *)
	BadValue* =	   2;	(* int parameter out of range *)
	BadWindow* = 3; (* parameter not a Window *)
	BadPixmap* =	4; (* parameter not a Pixmap *)
	BadAtom* = 5; (* parameter not an Atom *)
	BadCursor* = 6; (* parameter not a Cursor *)
	BadFont* = 7; (* parameter not a Font *)
	BadMatch* = 8; (* parameter mismatch *)
	BadDrawable* = 9; (* parameter not a Pixmap or Window *)
	BadAccess* = 10; (* depending on context:
				 - key/button already grabbed
				 - attempt to free an illegal
				   cmap entry
				- attempt to store into a read-only
				   color map entry.
				- attempt to modify the access control
				   list from other than the local host.
				*)
	BadAlloc* = 11; (* insufficient resources *)
	BadColor* = 12; (* no such colormap *)
	BadGC* = 13; (* parameter not a GC *)
	BadIDChoice* = 14; (* choice not in range or already used *)
	BadName* = 15; (* font or color name doesn't exist *)
	BadLength* = 16;	(* Request length incorrect *)
	BadImplementation* = 17;	(* server is defective *)

	FirstExtensionError* = 128;
	LastExtensionError* = 255;


(* ****************************************************************
						 WINDOW DEFINITIONS
 **************************************************************** *)

	(*  Window classes used by CreateWindow *)
	(* Note that CopyFromParent is already defined as 0 above *)
	InputOutput* = 1; InputOnly* = 2;

	(* Window attributes for CreateWindow and ChangeWindowAttributes *)
	CWBackPixmap* = 1H; CWBackPixel* = 2H; CWBorderPixmap* = 4H; CWBorderPixel* = 8H;
	CWBitGravity* = 10H; CWWinGravity* = 20H; CWBackingStore* = 40H;  CWBackingPlanes* = 80;
	CWBackingPixel* = 100H; CWOverrideRedirect* = 200H; CWSaveUnder* =400H; CWEventMask* =800H;
	CWDontPropagate* =1000H; CWColormap* = 2000H; CWCursor* =4000H;

	(* ConfigureWindow structure *)
	CWX* = 1H;  CWY* = 2H; CWWidth* = 4H; CWHeight* = 8H; CWBorderWidth* = 10H;
	CWSibling* = 20H; CWStackMode* = 40H;

	(* Bit Gravity *)
	ForgetGravity* = 0; NorthWestGravity* = 1; NorthGravity* = 2; NorthEastGravity* = 3;
	WestGravity* = 4; CenterGravity *= 5; EastGravity* = 6; SouthWestGravity* = 7;
	SouthGravity* = 8; SouthEastGravity* = 9; StaticGravity* = 10;

	(* Window gravity + bit gravity above *)
	UnmapGravity* = 0;

	(* Used in CreateWindow for backing-store hint *)
	NotUseful* = 0; WhenMapped* = 1; Always*= 2;

	(* Used in GetWindowAttributes reply *)
	IsUnmapped* = 0; IsUnviewable* = 1; IsViewable*= 2;

	(* Used in ChangeSaveSet *)
	SetModeInsert* = 0; SetModeDelete* = 1;

	(* Used in ChangeCloseDownMode *)
	DestroyAll* = 0; RetainPermanent* = 1; RetainTemporary* = 2;

	(* Window stacking method (in configureWindow) *)
	Above* =  0; Below* =1; TopIf* = 2; BottomIf* = 3; Opposite* = 4;

	(* Circulation direction *)
	RaiseLowest* = 0; LowerHighest* = 1;

	(* Property modes *)
	PropModePrepend* = 1; PropModeAppend * = 2;



(* ****************************************************************
                                             FONTS
************************************************************* *)
(* used in QueryFont -- draw direction *)
	FontLeftToRight* = 0;
	FontRightToLeft* = 1;
	FontChange* = 255;


(* ****************************************************************
                                      KEYBOARD/POINTER STUFF
 **************************************************************** *)

	AutoRepeatModeOff*= 0; AutoRepeatModeOn* = 1; AutoRepeatModeDefault* = 2;

	LedModeOff* = 0; LedModeOn* = 1;

	(* masks for ChangeKeyboardControl *)
	KBKeyClickPercent* =  1H;  KBBellPercent* =  2H; KBBellPitch* =  4H; 	KBBellDuration* =  8H;
	KBLed* =  10H; KBLedMode* =  20H; KBKey* =  40H; KBAutoRepeatMode* =  80;

	MappingSuccess* = 0; MappingBusy* = 1; MappingFailed* = 2;
	MappingModifier* = 0; MappingKeyboard* = 1; MappingPointer* = 2;

(* ****************************************************************
                                              SCREEN SAVER STUFF
 **************************************************************** *)
  DontPreferBlanking* = 0; PreferBlanking* = 1; DefaultBlanking* = 2;
  DisableScreenSaver* = 0; DisableScreenInterval* = 0;
  DontAllowExposures* = 0; AllowExposures* = 1; DefaultExposures* =2;

(* for ForceScreenSaver *)
  ScreenSaverReset* = 0; ScreenSaverActive* = 1;

(* ****************************************************************
                             HOSTS AND CONNECTIONS
 **************************************************************** *)

	(* for ChangeHosts *)
	HostInsert* = 0; HostDelete* = 1;

	(* for ChangeAccessControl *)
	EnableAccess* = 1; DisableAccess* = 0;


	(* Byte order  used in imageByteOrder and bitmapBitOrder *)
	LSBFirst* = 0; MSBFirst* = 1;


(* ****************************************************************
						ATOMS  <X11/Xatom.h>
 **************************************************************** *)

	(* Do not change!  Changing this file implies a protocol change! *)
	XA_PRIMARY * = 1;  XA_SECONDARY * = 2;  XA_ARC * = 3;  XA_ATOM * = 4;  XA_BITMAP * = 5;
	XA_CARDINAL * = 6;  XA_COLORMAP * = 7;  XA_CURSOR * = 8;  XA_CUT_BUFFER0 * = 9;
	XA_CUT_BUFFER1 * = 10;  XA_CUT_BUFFER2 * = 11;  XA_CUT_BUFFER3 * = 12;  XA_CUT_BUFFER4 * = 13;
	XA_CUT_BUFFER5 * = 14;  XA_CUT_BUFFER6 * = 15;  XA_CUT_BUFFER7 * = 16;  XA_DRAWABLE * = 17;
	XA_FONT * = 18;  XA_INTEGER * = 19;  XA_PIXMAP * = 20;  XA_POINT * = 21;  XA_RECTANGLE * = 22;
	XA_RESOURCE_MANAGER * = 23;  XA_RGB_COLOR_MAP * = 24;  XA_RGB_BEST_MAP * = 25;
	XA_RGB_BLUE_MAP * = 26;  XA_RGB_DEFAULT_MAP * = 27;  XA_RGB_GRAY_MAP * = 28;
	XA_RGB_GREEN_MAP * = 29;  XA_RGB_RED_MAP * = 30;  XA_STRING * = 31;  XA_VISUALID * = 32;
	XA_WINDOW * = 33;  XA_WM_COMMAND * = 34;  XA_WM_HINTS * = 35;  XA_WM_CLIENT_MACHINE * = 36;
	XA_WM_ICON_NAME * = 37;  XA_WM_ICON_SIZE * = 38;  XA_WM_NAME * = 39;  XA_WM_NORMAL_HINTS * = 40;
	XA_WM_SIZE_HINTS * = 41;  XA_WM_ZOOM_HINTS * = 42;  XA_MIN_SPACE * = 43;  XA_NORM_SPACE * = 44;
	XA_MAX_SPACE * = 45;  XA_END_SPACE * = 46;  XA_SUPERSCRIPT_X * = 47;  XA_SUPERSCRIPT_Y * = 48;
	XA_SUBSCRIPT_X * = 49;  XA_SUBSCRIPT_Y * = 50;  XA_UNDERLINE_POSITION * = 51;  XA_UNDERLINE_THICKNESS * = 52;
	XA_STRIKEOUT_ASCENT * = 53;  XA_STRIKEOUT_DESCENT * = 54;  XA_ITALIC_ANGLE * = 55;
	XA_X_HEIGHT * = 56;  XA_QUAD_WIDTH * = 57;  XA_WEIGHT * = 58;  XA_POINT_SIZE * = 59;
	XA_RESOLUTION * = 60;  XA_COPYRIGHT * = 61;  XA_NOTICE * = 62;  XA_FONT_NAME * = 63;
	XA_FAMILY_NAME * = 64;  XA_FULL_NAME * = 65;  XA_CAP_HEIGHT * = 66;  XA_WM_CLASS * = 67;
	XA_WM_TRANSIENT_FOR * = 68;  XA_LAST_PREDEFINED * = 68;

(* ****************************************************************
			CURSORS  <X11/Xcursorfont.h>
 **************************************************************** *)
CONST
	 XC_num_glyphs* = 154;
	 XC_X_cursor* = 0;  XC_arrow* = 2;  XC_based_arrow_down* = 4; XC_based_arrow_up* = 6;
	 XC_boat* = 8; XC_bogosity* = 10; XC_bottom_left_corner* = 12; XC_bottom_right_corner* = 14;
	 XC_bottom_side* = 16; XC_bottom_tee* = 18; XC_box_spiral* = 20; XC_center_ptr* = 22;
	 XC_circle* = 24; XC_clock* = 26; XC_coffee_mug* = 28; XC_cross* = 30; XC_cross_reverse* = 32;
	 XC_crosshair* = 34; XC_diamond_cross* = 36; XC_dot* = 38; XC_dotbox* = 40; XC_double_arrow* = 42;
	 XC_draft_large* = 44; XC_draft_small* = 46; XC_draped_box* = 48; XC_exchange* = 50;
	 XC_fleur* = 52; XC_gobbler* = 54; XC_gumby* = 56; XC_hand1* = 58; XC_hand2* = 60;
	 XC_heart* = 62; XC_icon* = 64; XC_iron_cross* = 66; XC_left_ptr* = 68; XC_left_side* = 70;
	 XC_left_tee* = 72; XC_leftbutton* = 74; XC_ll_angle* = 76; XC_lr_angle* = 78; XC_man* = 80;
	 XC_middlebutton* = 82; XC_mouse* = 84; XC_pencil* = 86; XC_pirate* = 88; XC_plus* = 90;
	 XC_question_arrow* = 92; XC_right_ptr* = 94; XC_right_side* = 96; XC_right_tee* = 98;
	 XC_rightbutton* = 100; XC_rtl_logo* = 102; XC_sailboat* = 104; XC_sb_down_arrow* = 106;
	 XC_sb_h_double_arrow* = 108; XC_sb_left_arrow* = 110; XC_sb_right_arrow* = 112;
	 XC_sb_up_arrow* = 114; XC_sb_v_double_arrow* = 116; XC_shuttle* = 118; XC_sizing* = 120;
	 XC_spider* = 122; XC_spraycan* = 124; XC_star* = 126; XC_target* = 128; XC_tcross* = 130;
	 XC_top_left_arrow* = 132; XC_top_left_corner* = 134; XC_top_right_corner* = 136;
	 XC_top_side* = 138; XC_top_tee* = 140; XC_trek* = 142; XC_ul_angle* = 144;
	 XC_umbrella* = 146; XC_ur_angle* = 148; XC_watch* = 150; XC_xterm* = 152;

(* *********************************************** *)
	(* X11/Xlib.h*)
(* *********************************************** *)
TYPE
	Status* = WORD;


VAR
	ErrorText*: Buffer;
	ErrorFlag*: BOOLEAN;  lastEventTime*: Time;  ioErrors: INTEGER;


VAR
	(* Xlib calls: *)
	OpenDisplay-:			PROCEDURE {C} ( CONST name: ARRAY OF CHAR ): DisplayPtr;
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
	LookupString-:			PROCEDURE {C} ( VAR event: KeyEvent;  VAR buf: ARRAY OF CHAR;  bufsize: WORD;
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
	GetErrorText-:			PROCEDURE {C} ( d: DisplayPtr;  errcode: WORD; VAR buf: ARRAY OF CHAR; length: WORD );
	StoreBytes-:				PROCEDURE {C} ( d: DisplayPtr;  bytes: ADDRESS; nbytes: WORD );
	FetchBytes-:			PROCEDURE {C} ( d: DisplayPtr;  VAR nbytes: WORD ): ADDRESS;
	SetSelectionOwner-:	PROCEDURE {C} ( d: DisplayPtr;  selection: Atom;  owner: Window;  time: Time );
	GetSelectionOwner-:	PROCEDURE {C} ( d: DisplayPtr;  selection: Atom ): Window;
	InternAtom-:				PROCEDURE {C} ( d: DisplayPtr;  CONST name: ARRAY OF CHAR;  onlyifexists: Bool ): Atom;
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

	CloseDisplay- : PROCEDURE {C} (display:DisplayPtr): WORD;
	CreateWindow- : PROCEDURE {C} (display: DisplayPtr; parent: Window; x, y: WORD; width, height, borderWidth, depth, class: WORD; visual: VisualPtr; valuemask: LONGWORD;  VAR attributes: XSetWindowAttributes ): Window;
	DestroyWindow-: PROCEDURE {C}(display:DisplayPtr; win: Window): WORD;
	DisplayWidthMM-: PROCEDURE {C} (d: DisplayPtr; screen: WORD ): WORD;
	FreeColormap- : PROCEDURE {C} (display: DisplayPtr; colormap: Colormap);
	FreeCursor- : PROCEDURE {C} (display: DisplayPtr;  cursor: Cursor);
	XGetAtomName- : PROCEDURE {C} (display: DisplayPtr; atom: Atom): ADDRESS;
	GetWindowAttributes- : PROCEDURE {C} (display: DisplayPtr; win: Window; VAR attr: XWindowAttributes): Status;


	GrabKeyboard-: PROCEDURE {C} (display: DisplayPtr; grabwindow: Window; ownerevents: Bool; pointermode, keyboardmode: WORD; time: Time): WORD;
	GrabPointer-: PROCEDURE {C} (display:DisplayPtr; grabwindow: Window; ownerevents: Bool; eventmask: WORD; pointermode, keyboardmode: WORD; confineto: Window; cursor: Cursor; time: Time): WORD;
	LookupKeysym- : PROCEDURE {C} (CONST event: KeyEvent; index: WORD): KeySym;
	MapWindow- : PROCEDURE {C} (display: DisplayPtr; win: Window);
	Pending- : PROCEDURE {C} (display: DisplayPtr): WORD;
	RaiseWindow-: PROCEDURE {C}(display: DisplayPtr; win: Window);
	RootWindow-: PROCEDURE {C}(display: DisplayPtr; screen: WORD): Window;

	SetNormalHints-: PROCEDURE {C} (d: DisplayPtr; w: Window; VAR hints: XSizeHints);
	GetNormalHints-: PROCEDURE {C} (d: DisplayPtr; w: Window; VAR hints: XSizeHints): Status;

	SetStandardProperties-: PROCEDURE {C} (display: DisplayPtr; w: Window; CONST winName: ARRAY OF CHAR;
							CONST iconName: ARRAY OF CHAR; iconpixmap: Pixmap;  argv: ADDRESS; argc: WORD; VAR hints: XSizeHints);
	SetWMProtocols-: PROCEDURE {C} (display: DisplayPtr; win: Window; protocols: ADDRESS (* ARRAY OF Atoms *); count: WORD): Status;
	UnmapWindow- : PROCEDURE {C} (display: DisplayPtr; win: Window);


	(* cut and paste delegates *)
	SendSelection*:	 PROCEDURE {DELEGATE} (VAR event: SelectionRequestEvent );
	ReceiveSelection*:  PROCEDURE {DELEGATE} (VAR event: SelectionEvent );
	ClearSelection*: PROCEDURE {DELEGATE} ;

	CheckTypedEvent-: PROCEDURE {C} (display: DisplayPtr; eventType: WORD; VAR event: Event): Bool;
	CheckMaskEvent-: PROCEDURE {C} (display: DisplayPtr; eventMask: LONGWORD; VAR event: Event): Bool;

	CheckTypedWindowEvent-: PROCEDURE {C} (display: DisplayPtr; window: Window; eventType: WORD; VAR event: Event): Bool;
	CheckWindowEvent-: PROCEDURE {C} (display: DisplayPtr; window: Window; eventMask: LONGWORD; VAR event: Event): Bool;

	(* Font *)
	LoadQueryFont-: PROCEDURE {C} (display: DisplayPtr; name: ADDRESS): FontStruct;
	QueryFont- : PROCEDURE {C} (display: DisplayPtr; name: XID): FontStruct;

	KeycodeToKeysym-: PROCEDURE {C} (disp: DisplayPtr; keycode: WORD; index: WORD): KeySym;
	KeysymToKeycode-: PROCEDURE {C} (disp: DisplayPtr; keysym: KeySym): WORD;

	XKeysymToString-  : PROCEDURE {C} (keysym: KeySym): ADDRESS;

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
		Unix.Dlsym( xlib, "XCloseDisplay", ADDRESSOF( CloseDisplay));
		Unix.Dlsym( xlib, "XCreateWindow", ADDRESSOF( CreateWindow));
		Unix.Dlsym( xlib, "XDestroyWindow", ADDRESSOF( DestroyWindow));
		Unix.Dlsym( xlib, "XDisplayWidthMM", ADDRESSOF( DisplayWidthMM));
		Unix.Dlsym( xlib, "XFreeColormap", ADDRESSOF( FreeColormap));
		Unix.Dlsym( xlib, "XFreeCursor", ADDRESSOF( FreeCursor));
		Unix.Dlsym( xlib, "XGetAtomName", ADDRESSOF( XGetAtomName));
		Unix.Dlsym( xlib, "XGetNormalHints", ADDRESSOF( GetNormalHints));
		Unix.Dlsym( xlib, "XGetWindowAttributes", ADDRESSOF( GetWindowAttributes));
		Unix.Dlsym( xlib, "XGetWindowProperty", ADDRESSOF( GetWindowProperty));
		Unix.Dlsym( xlib, "XGrabKeyboard", ADDRESSOF( GrabKeyboard));
		Unix.Dlsym( xlib, "XGrabPointer", ADDRESSOF( GrabPointer));
		Unix.Dlsym( xlib, "XLookupKeysym", ADDRESSOF( LookupKeysym));
		Unix.Dlsym( xlib, "XLookupString", ADDRESSOF( LookupString));
		Unix.Dlsym( xlib, "XMapWindow", ADDRESSOF( MapWindow));
		Unix.Dlsym( xlib, "XUnmapWindow", ADDRESSOF( UnmapWindow));
		Unix.Dlsym( xlib, "XPending", ADDRESSOF( Pending));
		Unix.Dlsym( xlib, "XRaiseWindow", ADDRESSOF( RaiseWindow));
		Unix.Dlsym( xlib, "XRootWindow", ADDRESSOF( RootWindow));
		Unix.Dlsym( xlib, "XSendEvent", ADDRESSOF( SendEvent));
		Unix.Dlsym( xlib, "XSetNormalHints", ADDRESSOF( SetNormalHints));
		Unix.Dlsym( xlib, "XSetStandardProperties", ADDRESSOF( SetStandardProperties));
		Unix.Dlsym( xlib, "XSetWMProtocols", ADDRESSOF( SetWMProtocols));
		Unix.Dlsym( xlib, "XStoreName", ADDRESSOF( StoreName));
		Unix.Dlsym( xlib, "XWarpPointer", ADDRESSOF( WarpPointer));
		Unix.Dlsym( xlib, "XCheckTypedEvent", ADDRESSOF( CheckTypedEvent));
		Unix.Dlsym( xlib, "XCheckMaskEvent", ADDRESSOF( CheckMaskEvent));
		Unix.Dlsym( xlib, "XCheckTypedWindowEvent", ADDRESSOF( CheckTypedWindowEvent));
		Unix.Dlsym( xlib, "XCheckWindowEvent", ADDRESSOF( CheckWindowEvent));
		Unix.Dlsym(xlib, 'XLoadQueryFont', ADDRESSOF( LoadQueryFont));
		Unix.Dlsym(xlib, 'XQueryFont', ADDRESSOF( QueryFont));
		Unix.Dlsym(xlib, "XKeycodeToKeysym", ADDRESSOF(KeycodeToKeysym));
		Unix.Dlsym(xlib, "XKeysymToKeycode", ADDRESSOF(KeysymToKeycode));
		Unix.Dlsym(xlib, "XKeysymToString", ADDRESSOF(XKeysymToString));

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
		LOOP END;
		RETURN 0
	END MyIOErrorHandler;

BEGIN
	ioErrors := 0;  LinkToX;  ErrorFlag := FALSE;

	(* Oberon procedures cannot be used as callback procedures because of
		incompatibilities between the PPC Oberon ABI and the PPC SYSV ABI.
		PPC Oberon follows the old MAC and IBM AIX ABI *)
	Unix.InitXErrorHandlers( MyErrorHandler, MyIOErrorHandler );
END X11.
