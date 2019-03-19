MODULE antsToolbox IN Oberon;   (* fof   **)
(* Copyright notice:

This file is part of AntsInFields
Copyright (C) 1997-2002, Felix Friedrich

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

Copy of the GNU Lesser General Public License can be found in the file COPYING.TXT
Report any problems as soon as possible to ants@AntsInFields.de
*)

IMPORT Pictures, Images, Files, Objects, Oberon, vyHostTexts, vyDisplay2d, PictConverters, antsCommands, vyRectangles,
	Display, SYSTEM, vyPort, vyLinks, Gadgets, vyParser, Input, vyTracking, Texts, Strings, Modules, vyHost, vyBase,
	vyCommandMenus, Links, TextDocs, antsTexts, GIF, vyHostStrings, aM := antsMessages, Effects, antsEffects, Attributes,
	Documents, Desktops, vyName, fofAutomatic, antsPortability, Types;

TYPE
	tBuffer* = RECORD
		X, Y, W, H: INTEGER;
		x, y: INTEGER;   (* origin *)
		buf: Images.Image;
		img: Images.Image
	END;

	hist = POINTER TO histDesc;
	histDesc = RECORD
		D: Documents.Document;
		next: hist;
		name: ARRAY 128 OF CHAR
	END;

	GetCoordMsg* = RECORD (Objects.ObjMsg)
		x*, y*: INTEGER;
		xr*, yr*: LONGREAL;
		w*, h*: LONGINT;
		layer*: vyPort.tLayer;
		update*: BOOLEAN;
		a*: vyBase.Object
	END;
	FileFinalize* = PROCEDURE ( VAR f: Files.File;  name: ARRAY OF CHAR );
	ObjProc* = PROCEDURE ( x, y: LONGINT;  a: Objects.Object;  link: Objects.Object );

VAR
	finalize: FileFinalize;
	suffix: ARRAY 32 OF CHAR;
	imgconversions: POINTER TO ARRAY OF ARRAY 64 OF CHAR;
	pictconversions: POINTER TO ARRAY OF ARRAY 64 OF CHAR;
	tempX, tempY: INTEGER;  lastframe: Display.Frame;  oldhh: PROCEDURE ( VAR D: Documents.Document );
	dhist: hist;
	history: hist;   (* for ReplaceDoc *)
	(*! if you intend to write or read pictures or images within a context in your application
	do ALWAYS use the standard handler mechanism, this mechanism is intended for portability of images only *)
	LoadedObject*: Objects.Object;  open: antsPortability.openFileDialog;  store: antsPortability.storeFileDialog;
	currentDialog: antsPortability.dialog;  task: Oberon.Task;  gPict: Pictures.Picture;  dlink: Objects.Object;

	PROCEDURE ViewLayer*( VAR f: vyPort.Frame;  VAR p: vyPort.Picture;  l: vyPort.tLayer;  VAR c: Objects.Object );
	VAR insertport, insertpicture: BOOLEAN;
	VAR cmsg: Display.ConsumeMsg;
	BEGIN
		insertport := FALSE;  insertpicture := FALSE;
		IF f = NIL THEN insertport := TRUE END;
		IF p = NIL THEN insertpicture := TRUE ELSE insertport := FALSE END;
		IF c = NIL THEN
			IF p = NIL THEN RETURN END;
			c := p.gcontext
		END;
		IF insertport THEN f := vyPort.InsertNewFrame( 0, 0 ) END;
		IF insertpicture THEN
			p := vyPort.NewP( c( vyBase.Object ) );  cmsg.id := Display.drop;  cmsg.u := 0;  cmsg.v := 0;  cmsg.F := f;
			cmsg.res := -1;  cmsg.obj := p;  Display.Broadcast( cmsg );
		END;
		vyPort.AddLayer( p, l )
	END ViewLayer;

(** initialize picture from map **)
	PROCEDURE ImageToPict*( img: Images.Image;  pict: Pictures.Picture );
	VAR i, y, r, g, b, a, x, w: INTEGER;  pal: Images.Palette;  fmt: Images.Format;
		byte: ARRAY 256 OF CHAR;
		int: ARRAY 256 OF INTEGER;
	BEGIN
		Pictures.Create( pict, img.width, img.height, 8 );   (* uses display palette *)
		IF img.fmt.pal # NIL THEN  (* modify picture palette *)
			i := 0;  pal := img.fmt.pal;
			WHILE i < pal.used DO Images.GetRGBA( pal.col[i], r, g, b, a );  Pictures.SetColor( pict, i, r, g, b );  INC( i ) END;
			Images.InitPaletteFormat( fmt, pal )
		ELSE fmt := Images.D8
		END;
		y := 0;
		WHILE y < img.height DO
			x := 0;
			WHILE x < img.width DO
				w := img.width - x;
				IF w > 256 THEN w := 256 END;
				Images.GetPixels( img, x, y, w, fmt, byte, Images.SrcCopy );
				FOR i := 0 TO w - 1 DO int[i] := ORD( byte[i] ) END;
				Pictures.PutLine( pict, int, x, y, w );  INC( x, w )
			END;
			INC( y )
		END
	END ImageToPict;

	(*

(** initialize picture from map **)
PROCEDURE ImageToPict* (img: Images.Image;    pict: Pictures.Picture);
VAR
	i, y, r, g, b, a, x, w: INTEGER;    pal: Images.Palette;    fmt: Images.Format;    byte: ARRAY 256 OF CHAR;
	int: ARRAY 256 OF INTEGER; pix: Images.Pixel;
BEGIN
	Pictures.Create(pict, img.width, img.height, 8);   	(* uses display palette *)
	IF img.fmt.pal # NIL THEN	(* modify picture palette *)
		aM.S("ImageToPict: Use image palette");
		pal := img.fmt.pal;
	ELSE
		aM.S("Creating image palette x ");
		NEW(pal); 	(*	Images.ComputePalette(img,pal,0,256,8); *)
		Images.InitPalette(pal,256,32);
		FOR i := 0 TO 15 DO
			Display.GetColor(i,r,g,b);
			Images.SetRGBA(pal.col[i],r,g,b,255);
		END;
		FOR i := 16 TO 255 DO
			r := SHORT(ENTIER((i-16) / (255-16) * 255)); g := r; b := r;
			Images.SetRGBA(pal.col[i],r,g,b,255);
		END;
		Images.InitPalette(pal,256,32);
	END;
		i := 0;
		WHILE i < pal.used DO
			Images.GetRGBA(pal.col[i], r, g, b, a);
			Pictures.SetColor(pict, i, r, g, b);
			INC(i)
		END;
		Images.InitPaletteFormat(fmt, pal);
	y := 0;
	WHILE y < img.height DO
		x := 0;
		WHILE x < img.width DO
			(*
			Images.Get(img,x,y,pix, Images.SrcCopy);
			Images.GetRGBA(pix,r,g,b,a);
			Pictures.Dot(pict,Images.PaletteIndex(pal,r,g,b),x,y, 0);
			*)

			w := img.width - x;
			IF w > 256 THEN w := 256 END;
			Images.GetPixels(img, x, y, w, fmt, byte, Images.SrcCopy);
			FOR i := 0 TO w - 1 DO
				int[i] := ORD(byte[i])
			END;
			Pictures.PutLine(pict, int, x, y, w);
			INC(x, w)
			(*
			INC(x);
			*)
		END;
		INC(y)
	END
END ImageToPict;
*)

(** initialize image from picture by copying picture contents **)
	PROCEDURE PictToImage*( pict: Pictures.Picture;  img: Images.Image );
	VAR idx, max, dr, dg, db, pr, pg, pb, y, x0, x1: INTEGER;  default: BOOLEAN;  pal: Images.Palette;  fmt: Images.Format;  adr: LONGINT;
	BEGIN
		(* check if palette matches fixed palette *)
		idx := 0;  max := SHORT( ASH( 1, pict.depth ) );  default := TRUE;
		WHILE (idx < max) & default DO
			Display.GetColor( idx, dr, dg, db );  Pictures.GetColor( pict, idx, pr, pg, pb );
			default := (dr = pr) & (dg = pg) & (db = pb);  INC( idx )
		END;

		IF default OR (max = 2) THEN  (* use display palette format *)
			Images.Create( img, pict.width, pict.height, Images.D8 )
		ELSE  (* initialize specific palette *)
			NEW( pal );  idx := 0;
			WHILE idx < max DO Pictures.GetColor( pict, idx, pr, pg, pb );  Images.SetRGB( pal.col[idx], pr, pg, pb );  INC( idx ) END;
			Images.InitPalette( pal, max, 4 );  Images.InitPaletteFormat( fmt, pal );
			Images.Create( img, pict.width, pict.height, fmt )
		END;

		(* get picture contents *)
		y := 0;  adr := img.adr;
		WHILE y < pict.height DO
			x0 := 0;
			WHILE x0 < pict.width DO
				x1 := x0;  Pictures.GetRun( pict, idx, x1, y );
				IF (max = 2) & (idx = 1) THEN idx := 15 END;
				REPEAT SYSTEM.PUT( adr, CHR( idx ) );  INC( adr );  INC( x0 ) UNTIL x0 = x1
			END;
			INC( y )
		END
	END PictToImage;

	PROCEDURE Install*( name: ARRAY OF CHAR );
	VAR Mn, Pn: ARRAY 256 OF CHAR;
		M: Modules.Module;  P: Modules.Command;
	BEGIN
		SplitName( name, Mn, Pn );
		IF Pn = "" THEN
			M := Modules.ThisMod( Pn );
			IF M # NIL THEN aM.SS( "antsToolbox:Installed ", Mn ) ELSE aM.eSS( "antsToolbox:Tried to install but failed: ", Mn ) END;
		ELSE
			P := Modules.ThisCommand( M, Pn );
			IF P # NIL THEN P;  aM.SS( "antsToolbox:Installed", name );  ELSE aM.eSS( "antsToolbox:Tried to install but failed:", name );  END;
		END;
	END Install;

	PROCEDURE InstallConverter( name: ARRAY OF CHAR ): BOOLEAN;
	VAR res: INTEGER;
	BEGIN
		res := -1;  Oberon.Call( name, Oberon.Par, FALSE , res );
		IF res = 0 THEN RETURN TRUE ELSE aM.eSS( "antsToolbox:Could not execute: ", name );  RETURN FALSE END
	END InstallConverter;

	PROCEDURE LoadPicture0( VAR pict: Pictures.Picture;  R: Files.Rider;  VAR done: BOOLEAN );
	VAR msg: Objects.FileMsg;  i: LONGINT;  id: INTEGER;  pos: LONGINT;
	BEGIN
		IF pict = NIL THEN Pictures.NewPicture;  pict := Objects.NewObj( Pictures.Picture ) ELSE Objects.NewObj := pict END;
		msg.R := R;  msg.id := Objects.load;  msg.len := 0;  done := FALSE;  i := 0;  pos := Files.Pos( msg.R );
		Files.ReadInt( msg.R, id );  Files.Set( msg.R, Files.Base( msg.R ), pos );
		IF id = Pictures.PictFileId THEN
			Pictures.Handle( pict, msg );  msg.len := Files.Pos( msg.R );
			IF msg.len > 0 THEN done := TRUE;  RETURN END
		END;
		WHILE i < LEN( pictconversions^ ) DO
			IF InstallConverter( pictconversions[i] ) THEN
				pict.handle( pict, msg );
				IF msg.len > 0 THEN done := TRUE;  RETURN END
			END;
			INC( i )
		END
	END LoadPicture0;

	PROCEDURE LoadGIF*( VAR pict: Pictures.Picture;  fname: ARRAY OF CHAR;  VAR done: BOOLEAN );
	VAR file: Files.File;  R: Files.Rider;
	BEGIN
		file := Files.Old( fname );
		IF file = NIL THEN aM.eSS( "antsToolbox: File does not exist: ", fname );  done := FALSE;  RETURN END;
		Files.Set( R, file, 0 );
		IF pict = NIL THEN Pictures.NewPicture;  pict := Objects.NewObj( Pictures.Picture ) ELSE Objects.NewObj := pict END;
		GIF.Load( R, 0, FALSE , pict );  done := ~(pict.depth = 0)
	END LoadGIF;

	PROCEDURE LoadPicture*( VAR pict: Pictures.Picture;  fname: ARRAY OF CHAR;  VAR done: BOOLEAN );
	VAR file: Files.File;  R: Files.Rider;
	BEGIN
		file := Files.Old( fname );
		IF file = NIL THEN aM.eSS( "antsToolbox: File does not exist: ", fname );  done := FALSE;  RETURN END;
		Files.Set( R, file, 0 );  LoadPicture0( pict, R, done )
	END LoadPicture;

	PROCEDURE LoadImage*( VAR image: Images.Image;  fname: ARRAY OF CHAR;  VAR done: BOOLEAN );
	VAR file: Files.File;  i: LONGINT;  pict: Pictures.Picture;
	BEGIN
		done := FALSE;  file := Files.Old( fname );
		IF file = NIL THEN aM.eSS( "antsToolbox: File does not exist: ", fname );  done := FALSE;  RETURN END;
		IF image = NIL THEN Images.New;  image := Objects.NewObj( Images.Image ) END;
		Images.Load( image, fname, done );
		IF done = FALSE THEN  (* now try it yourself *)
			i := 0;
			WHILE (i < LEN( imgconversions^ )) DO
				IF InstallConverter( imgconversions[i] ) THEN
					Images.LoadProc( image, fname, done );
					IF done = TRUE THEN image.handle := Images.Handle;  RETURN END
				END;
				INC( i )
			END
		END;
		IF done = FALSE THEN  (* now try pict based *)
			pict := NIL;  LoadPicture( pict, fname, done );
			IF done THEN PictToImage( pict, image ) END
		END;
		image.handle := Images.Handle
	END LoadImage;

(*

PROCEDURE LoadImageName*;
VAR img: Images.Image;  done : BOOLEAN;
BEGIN
FileDir.ChangeDirectory(work,done);
aM.eSS(""loading: ",open.name);
LoadImage(img,open.name,done);
finish(img);
END LoadImageName;

PROCEDURE LoadPictureName*;
VAR picture: Pictures.Picture; done: BOOLEAN;
BEGIN
FileDir.ChangeDirectory(work,done);
aM.eSS(""loading: ",open.name);
LoadPicture(picture,open.name,done);
finish(picture);
END LoadPictureName;

PROCEDURE LoadImageDialoged* (f: Finish);
BEGIN
FileDir.GetWorkingDirectory(work);
finish := f;
open.name := "";
WinMenus.EmptyFilter(open.filter);
WinMenus.AddFilter(open.filter,"Images","*.GIF;*.JPG;*.JPEG");
open.cmd := "antsToolbox.LoadImageName";
WinMenus.ShowDialog(open,FALSE);
END LoadImageDialoged;

PROCEDURE LoadPictureDialoged* (f: Finish);
BEGIN
FileDir.GetWorkingDirectory(work);
finish := f;
open.name := "";
WinMenus.EmptyFilter(open.filter);
WinMenus.AddFilter(open.filter,"Images","*.GIF;*.JPG;*.JPEG");
open.cmd := "antsToolbox.LoadPictureName";
WinMenus.ShowDialog(open,FALSE);
END LoadPictureDialoged;
*)


	PROCEDURE StorePictAsGIF*( pict: Pictures.Picture;  R: Files.Rider );
	BEGIN
		PictConverters.Pict2GIF( pict, R )
	END StorePictAsGIF;

	PROCEDURE StoreImageAsGIF*( img: Images.Image;  R: Files.Rider );
	VAR pict: Pictures.Picture;
	BEGIN
		Pictures.NewPicture;  pict := Objects.NewObj( Pictures.Picture );  ImageToPict( img, pict );  StorePictAsGIF( pict, R )
	END StoreImageAsGIF;

	PROCEDURE InitConversions;
	BEGIN
		NEW( imgconversions, 5 );  imgconversions[0] := "PictImages.Install";  imgconversions[1] := "BMPImages.Install";  imgconversions[2] := "GIFImages.Install";  imgconversions[3] := "PSDImages.Install";
		imgconversions[4] := "JPEGImages.Install";  NEW( pictconversions, 11 );  pictconversions[0] := "BMP.InitPicture";  pictconversions[1] := "GIF.InitPicture";  pictconversions[2] := "ICO.InitPicture";
		pictconversions[3] := "IFF.InitPicture";  pictconversions[4] := "JPEG.InitPicture";  pictconversions[5] := "PCX.InitPicture";  pictconversions[6] := "PPM.InitPicture";  pictconversions[7] := "PSD.InitPicture";
		pictconversions[8] := "TGA.InitPicture";  pictconversions[9] := "XBM.InitPicture";  pictconversions[10] := "XPM.InitPicture"
	END InitConversions;

	PROCEDURE SplitName*( VAR name, MName, PName: ARRAY OF CHAR );
	VAR i, j: LONGINT;
	BEGIN
		i := 0;
		WHILE name[i] # "." DO MName[i] := name[i];  INC( i ) END;
		MName[i] := 0X;  INC( i );  j := 0;
		WHILE name[i] # 0X DO PName[j] := name[i];  INC( i );  INC( j ) END;
		PName[j] := 0X
	END SplitName;

	PROCEDURE GetLayerXY*( x, y: INTEGER;  VAR pict: vyPort.Picture ): vyLinks.Link;
	(** get Layer on pos x,y and set coordinate system *)
	VAR llist: vyLinks.Link;  frame: Display.Frame;  u, v: INTEGER;  cRgnMsg: vyDisplay2d.CoordRgnMessage;
		cSetMsg: vyDisplay2d.CoordSetMessage;  X, Y, W, H: INTEGER;

	BEGIN
		Gadgets.ThisFrame( x, y, frame, u, v );
		IF frame = NIL THEN RETURN NIL END;
		IF frame IS vyPort.Picture THEN
			WITH frame: vyPort.Picture DO
				pict := frame;  vyPort.GetPictureScreenRegion( frame, X, Y, W, H );
				IF (frame.gcontext # NIL ) & (frame.gcontext.handle # NIL ) THEN
					cRgnMsg.X := X;  cRgnMsg.Y := Y;  cRgnMsg.W := W;  cRgnMsg.H := H;  cRgnMsg.dlink := frame;
					cSetMsg.dlink := frame;  frame.gcontext.handle( frame.gcontext, cSetMsg );
					frame.gcontext.handle( frame.gcontext, cRgnMsg )
				END;
				llist := frame( vyPort.Picture ).vylinks
			END;
		ELSE llist := NIL
		END;
		RETURN llist
	END GetLayerXY;

	PROCEDURE FrontLayerXY*( x, y: INTEGER;  VAR pict: vyPort.Picture ): vyPort.tLayer;
	VAR llist: vyLinks.Link;
	BEGIN
		llist := GetLayerXY( x, y, pict );
		IF llist = NIL THEN RETURN NIL END;
		WHILE llist.link # NIL DO llist := llist.link END;
		IF (llist.obj # NIL ) & (llist.obj IS vyPort.tLayer) THEN RETURN llist.obj( vyPort.tLayer ) ELSE aM.SISI( "There is no layer at x=", x, ", y=", y );  RETURN NIL END
	END FrontLayerXY;

	PROCEDURE MsgToXY*( x, y: INTEGER;  VAR msg: Objects.ObjMsg );
	VAR layer: vyPort.tLayer;  port: vyPort.Picture;
	BEGIN
		layer := FrontLayerXY( x, y, port );
		IF layer = NIL THEN aM.vS( "no layer." );  END;
		IF layer # NIL THEN layer.handle( layer, msg ) END;
		IF msg IS GetCoordMsg THEN
			WITH msg: GetCoordMsg DO msg.layer := layer
			END;
		ELSE
		END
	END MsgToXY;

	PROCEDURE SplitNameM( str: ARRAY OF CHAR;  VAR mod: Modules.Module;  VAR name: ARRAY OF CHAR );
	VAR i, j: LONGINT;  done: BOOLEAN;
	BEGIN
		done := FALSE;  i := 0;  j := 0;
		WHILE str[i] # 0X DO
			IF (~done) & (str[i] = ".") THEN done := TRUE;  str[i] := 0X;  j := 0
			ELSIF str[i] = ":" THEN
				mod := NIL;  name[0] := 0X;  RETURN  (* to avoid filename handling of str *)
			ELSE name[j] := str[i];  INC( j )
			END;
			INC( i )
		END;
		IF j >= i THEN j := 0 END;
		name[j] := 0X;  mod := Modules.ThisMod( str )
	END SplitNameM;

	PROCEDURE GetType*( type: ARRAY OF CHAR ): antsPortability.Type;
	VAR t2: ARRAY 256 OF CHAR;
		mod: Modules.Module;
	BEGIN
		SplitNameM( type, mod, t2 );
		IF mod = NIL THEN RETURN NIL END;
		RETURN antsPortability.TypesThis( mod, t2 )
	END GetType;

	PROCEDURE IsType*( obj: ANY;  t: antsPortability.Type ): BOOLEAN;
	VAR levelt, levelo: INTEGER;  to: antsPortability.Type;
	BEGIN
		to := antsPortability.TypesTypeOf( obj );
		IF to = t THEN RETURN TRUE END;
		levelt := antsPortability.TypesLevelOf( t );  levelo := antsPortability.TypesLevelOf( to );
		IF levelt >= levelo THEN RETURN FALSE
		ELSIF antsPortability.TypesBaseOf( to, levelt ) = t THEN RETURN TRUE
		ELSE RETURN FALSE
		END
	END IsType;

	PROCEDURE TypedLayer*( llist: vyLinks.Link;  type: ARRAY OF CHAR ): Objects.Object;
	VAR obj: Objects.Object;  t: antsPortability.Type;
	BEGIN
		obj := NIL;  t := GetType( type );
		IF t = NIL THEN RETURN NIL END;
		WHILE (llist # NIL ) DO
			IF (llist.obj # NIL ) & (IsType( llist.obj, t )) THEN obj := llist.obj END;
			llist := llist.link
		END;
		RETURN obj
	END TypedLayer;

	PROCEDURE TypedLayerXY*( x, y: INTEGER;  type: ARRAY OF CHAR;  VAR pict: vyPort.Picture ): vyPort.tLayer;
	VAR obj: Objects.Object;
	BEGIN
		obj := TypedLayer( GetLayerXY( x, y, pict ), type );
		IF obj = NIL THEN RETURN NIL ELSE RETURN obj( vyPort.tLayer ) END
	END TypedLayerXY;

	PROCEDURE MsgToTypedXY*( x, y: INTEGER;  VAR msg: Objects.ObjMsg;  type: ARRAY OF CHAR );
	VAR obj: Objects.Object;  pict: vyPort.Picture;
	BEGIN
		obj := TypedLayerXY( x, y, type, pict );
		IF obj # NIL THEN obj.handle( obj, msg ) END
	END MsgToTypedXY;

	PROCEDURE SelectFrame*( ): Display.Frame;
	VAR keys: SET;  x, y, dx, dy: INTEGER;  frame: Display.Frame;
	VAR u, v: INTEGER;  M: Display.LocateMsg;
	BEGIN
		aM.vS( "antsToolbox.SelectFrame: move mouse to destination frame and click" );  Input.Mouse( keys, x, y );  vyTracking.HelpAt( x, y, "move mouse to destination and click" );
		vyTracking.TrackMouseCont( keys, dx, dy, Effects.PointHand );  vyTracking.HelpEnd;
		(*MyEffects.FramedString(x+10,y,"Syntax.10.Scn.Fnt","Select Frame!",dx,dy);   *)
		M.X := dx;  M.Y := dy;  M.F := NIL;  M.loc := NIL;  Display.Broadcast( M );  frame := M.loc;  u := M.u;  v := M.v;
		(*Gadgets.ThisFrame(dx, dy, frame, u, v);*) dlink := M.dlink;  RETURN frame
	END SelectFrame;

	PROCEDURE SetSize*;
	VAR S: Attributes.Scanner;  M: Display.SelectMsg;  obj: Objects.Object;  A: Objects.AttrMsg;  W, H: LONGINT;
	BEGIN
		antsCommands.InitScan( "W=NUMBER H=NUMBER" );
		IF antsCommands.ExpectNumber( "W", W ) & antsCommands.ExpectNumber( "H", H ) THEN
			M.id := Display.get;  M.F := NIL;  M.sel := NIL;  M.obj := NIL;  M.time := -1;  Display.Broadcast( M );

			IF M.time # -1 THEN
				obj := M.obj;
				IF obj IS Display.Frame THEN
					WITH obj: Display.Frame DO Gadgets.ModifySize( obj, SHORT( W ), SHORT( H ) );
					END;
				ELSE
				END;
			ELSE aM.eS( "No selection" );
			END
		END
	END SetSize;

	PROCEDURE CopyCoordinates*;
	VAR frame1, frame2: Display.Frame;  obj1, obj2: Objects.Object;  x, y, w, h: LONGREAL;  keys: SET;  X, Y: INTEGER;  type: Types.Type;
	BEGIN
		antsCommands.InitScan( "[>X] [>Y]" );  aM.S( "Select source" );  frame1 := SelectFrame();  obj1 := dlink;
		REPEAT Input.Mouse( keys, X, Y );  UNTIL keys = {};
		aM.S( "Select destination" );  frame2 := SelectFrame();  obj2 := dlink;  aM.S( "ok." );
		IF obj1 # NIL THEN type := Types.TypeOf( obj1 );  aM.S( type.name );  END;
		WITH frame1: vyPort.Picture DO
			WITH frame2: vyPort.Picture DO
				Attributes.GetLongReal( frame1, "x2d", x );  Attributes.GetLongReal( frame1, "y2d", y );
				Attributes.GetLongReal( frame1, "w2d", w );  Attributes.GetLongReal( frame1, "h2d", h );

				IF antsCommands.Find( "X" ) THEN Attributes.SetLongReal( frame2, "x2d", x );  Attributes.SetLongReal( frame2, "w2d", w );
				END;
				IF antsCommands.Find( "Y" ) THEN Attributes.SetLongReal( frame2, "y2d", y );  Attributes.SetLongReal( frame2, "h2d", h );  END;
				IF antsCommands.Find( "S" ) THEN
					IF (obj1 # NIL ) & (obj1 IS vyPort.Frame) & (obj2 # NIL ) & (obj2 IS vyPort.Frame) THEN
						aM.S( "source and destination have a container port, I modify the size of that" );  Gadgets.ModifySize( obj2( vyPort.Frame ), obj1( vyPort.Frame ).W, obj1( vyPort.Frame ).H );
					ELSE Gadgets.ModifySize( frame2, frame1.W, frame1.H );
					END;
				END;
				Gadgets.Update( frame2 );
			END;
		END;
	END CopyCoordinates;

	PROCEDURE GetDisplay( X, Y, W, H: INTEGER ): Images.Image;
	VAR img: Images.Image;
	BEGIN
		NEW( img );  Images.Create( img, W, H, Images.DisplayFormat );
		Display.TransferBlock( img.mem^, 0, img.bpr, X, Y, W, H, Display.get );  RETURN img
	END GetDisplay;

	PROCEDURE TempHandle( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	BEGIN
		IF msg IS Display.DisplayMsg THEN
			WITH msg: Display.DisplayMsg DO tempX := msg.x;  tempY := msg.y
			END;
		ELSE
		END
	END TempHandle;

	PROCEDURE DoFrameToGIF*( f: Display.Frame;  name: ARRAY OF CHAR );
	VAR F: Files.File;  R: Files.Rider;  X, Y, W, H: INTEGER;  img: Images.Image;  picture: Pictures.Picture;  msg: Display.DisplayMsg;
		orighandle: Objects.Handler;  atmsg: Objects.AttrMsg;  w: LONGINT;  b: BOOLEAN;  done: BOOLEAN;
	BEGIN
		orighandle := f.handle;  f.handle := TempHandle;  msg.F := f;  msg.device := Display.screen;  msg.id := Display.full;
		msg.res := -1;  Display.Broadcast( msg );  f.handle := orighandle;  X := f.X + tempX;  Y := f.Y + tempY;  W := f.W;
		H := f.H;
		IF f IS vyPort.Picture THEN
			WITH f: vyPort.Picture DO
				atmsg.id := Objects.get;  atmsg.name := "hdr";  atmsg.res := -1;  f.handle( f, atmsg );  b := atmsg.b;
				atmsg.id := Objects.set;  atmsg.b := FALSE;  atmsg.res := -1;  f.handle( f, atmsg );  atmsg.id := Objects.get;
				atmsg.name := "borderW";  atmsg.res := -1;  f.handle( f, atmsg );  w := atmsg.i;  atmsg.id := Objects.set;  atmsg.i := 0;
				atmsg.res := -1;  f.handle( f, atmsg );  img := GetDisplay( X, Y, W, H );  msg.res := -1;  Display.Broadcast( msg );
				atmsg.id := Objects.set;  atmsg.b := b;  atmsg.name := "hdr";  atmsg.class := Objects.Bool;  atmsg.res := -1;
				f.handle( f, atmsg );  atmsg.id := Objects.set;  atmsg.i := w;  atmsg.name := "borderW";  atmsg.class := Objects.Int;
				atmsg.res := -1;  f.handle( f, atmsg );  msg.res := -1;  Display.Broadcast( msg )
			END;
		ELSE img := GetDisplay( X, Y, W, H )
		END;
		NEW( picture );  ImageToPict( img, picture );
		IF name # "" THEN
			aM.S( "trying images.Store" );  Images.Store( img, name, done );
			IF ~done THEN
				F := Files.New( name );  Files.Set( R, F, 0 );  PictConverters.Pict2GIF( picture, R );
				(*
		vyPort.StorePictAsGIF(f, R);
		INSERT DisplayGrabbing and Storing here.
		*)
				Files.Register( F );  Files.Close( F )
			END;
		ELSE gPict := picture
		END
	END DoFrameToGIF;

	PROCEDURE MakefileName*( prefix, suffix: ARRAY OF CHAR;  VAR name: ARRAY OF CHAR );
	VAR i: INTEGER;
	BEGIN
		COPY( prefix, name );  vyHostStrings.Append( name, "." );  vyHostStrings.Append( name, suffix );
		IF Files.Old( name ) # NIL THEN
			i := 0;
			REPEAT
				INC( i );  COPY( prefix, name );  vyHostStrings.Append( name, "." );
				IF i < 10 THEN vyHostStrings.Append( name, "000" )
				ELSIF i < 100 THEN vyHostStrings.Append( name, "00" )
				ELSIF i < 1000 THEN vyHostStrings.Append( name, "0" )
				END;
				vyHostStrings.AppendInt( i, 0, name );  vyHostStrings.Append( name, "." );  vyHostStrings.Append( name, suffix )
			UNTIL (Files.Old( name ) = NIL )
		END
	END MakefileName;

	PROCEDURE Adjust( VAR x, y, w, h: INTEGER );
	BEGIN
		IF w < 0 THEN x := x + w;  w := -w END;
		IF h < 0 THEN y := y + h;  h := -h END
	END Adjust;

	PROCEDURE OpenBigBuffer( VAR buf: tBuffer;  x, y, w, h: INTEGER );
	BEGIN
		buf.x := x;  buf.y := y;  Adjust( x, y, w, h );
		(* opens a buffer x-50,y-50,w+100,h+100 *)
		IF (buf.W < w + 160) OR (buf.H < h + 160) THEN
			buf.X := x - 80;  buf.Y := y - 80;  buf.W := w + 160;  buf.H := h + 160;
			vyRectangles.RectIntersection( buf.X, buf.Y, buf.W, buf.H, 0, 0, Display.Width, Display.Height );  NEW( buf.img );
			Images.Create( buf.img, buf.W, buf.H, Images.DisplayFormat );  NEW( buf.buf );
			Images.Create( buf.buf, buf.W, buf.H, Images.DisplayFormat )
		ELSE buf.X := x - 80;  buf.Y := y - 80
		END;
		Display.TransferBlock( buf.buf.mem^, 0, buf.buf.bpr, buf.X, buf.Y, buf.W, buf.H, Display.get )
	END OpenBigBuffer;

	PROCEDURE CloseBuffer( buf: tBuffer );
	BEGIN
		Display.TransferBlock( buf.buf.mem^, 0, buf.buf.bpr, buf.X, buf.Y, buf.W, buf.H, Display.set )
	END CloseBuffer;

	PROCEDURE WriteBufferImg( buf: tBuffer );
	BEGIN
		Display.TransferBlock( buf.img.mem^, 0, buf.img.bpr, buf.X, buf.Y, buf.W, buf.H, Display.set )
	END WriteBufferImg;

	PROCEDURE GetBufRect( buf: tBuffer;  x, y, w, h: INTEGER;  VAR X, Y, W, H: INTEGER );
	BEGIN
		Adjust( x, y, w, h );  X := x - buf.X;  Y := y - buf.Y;  W := w;  H := h
	END GetBufRect;

	PROCEDURE CheckBuffer( VAR buf: tBuffer;  x, y, w, h: INTEGER );
	BEGIN
		IF ~vyRectangles.RectInRect( x, y, w, h, buf.X, buf.Y, buf.W, buf.H ) THEN
			CloseBuffer( buf );  OpenBigBuffer( buf, x, y, w, h )
		END;
		buf.x := x;  buf.y := y;  Images.Copy( buf.buf, buf.img, 0, 0, buf.W, buf.H, 0, 0, Images.SrcCopy )
	END CheckBuffer;

	PROCEDURE ZoomRect*( r, g, b: INTEGER;  x, y, w, h: INTEGER;  VAR dx, dy: INTEGER );
	VAR pix: Images.Pixel;  X, Y, W, H, cw, ch: INTEGER;  keys, keys0: SET;  x0, y0, x1, y1, xOld, yOld: INTEGER;  buf: tBuffer;  up: BOOLEAN;  alpha: INTEGER;
		cur: antsPortability.display;
	BEGIN
		cur := antsPortability.GetCurrentDisplay();  up := TRUE;  OpenBigBuffer( buf, x, y, w, h );

		Input.Mouse( keys0, x0, y0 );  xOld := x0;  yOld := y0;  x1 := x0;  y1 := y0;  keys := keys0;
		Images.SetRGBA( pix, r, g, b, alpha );

		WHILE (keys = keys0) DO
			IF ((x1 # xOld) OR (y1 # yOld)) THEN
				cw := x1 - x0;  ch := y1 - y0;  CheckBuffer( buf, x, y, cw, ch );  GetBufRect( buf, x, y, cw, ch, X, Y, W, H );
				IF (X >= 0) & (Y >= 0) & (W > 0) & (H > 0) THEN Images.Fill( buf.img, X, Y, X + W, Y + H, pix, Images.SrcOverDst ) END;
				WriteBufferImg( buf );  xOld := x1;  yOld := y1
			ELSE
				CheckBuffer( buf, x, y, cw, ch );  GetBufRect( buf, x, y, cw, ch, X, Y, W, H );
				IF up THEN
					INC( alpha, 5 );
					IF alpha > 200 THEN alpha := 200;  up := FALSE END
				ELSE
					DEC( alpha, 5 );
					IF alpha < 100 THEN alpha := 100;  up := TRUE END
				END;
				Images.SetRGBA( pix, r, g, b, alpha );
				IF (X >= 0) & (Y >= 0) & (W > 0) & (H > 0) THEN Images.Fill( buf.img, X, Y, X + W, Y + H, pix, Images.SrcOverDst ) END;
				WriteBufferImg( buf )
			END;

			Input.Mouse( keys, x1, y1 )
		END;
		CloseBuffer( buf );  dx := x1 - x0;  dy := y1 - y0;  antsPortability.SetCurrentDisplay( cur )
	END ZoomRect;

	PROCEDURE HistoryHook( VAR D: Documents.Document );
	VAR h: hist;
	BEGIN
		IF D # NIL THEN NEW( h );  h.D := D;  COPY( D.name, h.name );  h.next := dhist;  dhist := h;  END;
		IF oldhh # NIL THEN oldhh( D ) END
	END HistoryHook;

	PROCEDURE LoadAlpha*( VAR img: Images.Image;  name: ARRAY OF CHAR;  VAR done: BOOLEAN );
	VAR alpha: Pictures.Picture;  y, x: INTEGER;  nimg: Images.Image;  pix: Images.Pixel;  r, g, b, a, a1: INTEGER;
	BEGIN
		LoadGIF( alpha, name, done );
		IF ~done THEN aM.SS( "couldn not find Alpha-Channel:", name );  RETURN END;
		IF ~(alpha.width = img.width) & (alpha.height = img.height) THEN aM.S( "alpha channel not the same dimensions, stopping" );  done := FALSE;  RETURN END;
		IF img.fmt.code # Images.BGRA8888.code THEN
			NEW( nimg );  Images.Create( nimg, img.width, img.height, Images.BGRA8888 )
		ELSE nimg := img
		END;

		FOR y := 0 TO img.height - 1 DO
			FOR x := 0 TO img.width - 1 DO
				Images.Get( img, x, y, pix, Images.SrcCopy );  Images.GetRGBA( pix, r, g, b, a );  a1 := Pictures.Get( alpha, x, y );
				Images.SetRGBA( pix, r, g, b, a1 );  Images.Put( nimg, x, y, pix, Images.SrcCopy );
			END;
		END;
		img := nimg;  done := TRUE;
	END LoadAlpha;

	PROCEDURE Launch*;
	VAR pict: Images.Image;  done: BOOLEAN;  x, y: INTEGER;  w, h: LONGINT;
	BEGIN
		RETURN;
		aM.eS( "" );  aM.eS( " -----------------------------------------------" );  aM.eS( "  Launching AntsInFields" );  aM.eS( "  Simulation and Inference on Gibbs Fields" );  aM.eS( "  Version a1.03" );  aM.eS( "  (c) 1997-2002, Felix Friedrich, see antsCopyright.Text" );  aM.eS( "  www.AntsInFields.de  ---  ants@AntsInFields.de" );  aM.eS( " -----------------------------------------------" );  aM.eS( "" );

		LoadImage( pict, "antsStartup.GIF", done );
		IF done THEN
			LoadAlpha( pict, "antsStartupAlpha.GIF", done );  w := pict.width;  h := pict.height;  x := Display.Width DIV 2 - SHORT( w ) DIV 2;
			y := Display.Height DIV 2 - SHORT( h ) DIV 2;  antsEffects.Launch( pict, x, y, SHORT( w ), SHORT( h ) );
		ELSE aM.eS( "antsToolbox: could not load startup picture antsStartup.GIF" )
		END
	END Launch;

	PROCEDURE Ants*;
	BEGIN
		antsEffects.Ants( 0, 0, Display.Width, Display.Height, 1000, 500 )
	END Ants;

	PROCEDURE FrameToGIF*;
	VAR name, prefix, suffix: ARRAY 32 OF CHAR;
		pict: Display.Frame;
	BEGIN
		aM.vS( "antsToolbox.FrameToGIF" );  COPY( "GIF", suffix );  antsCommands.InitScan( "[filename=STR] [>old] #~ default filename IS STR" );
		(*! implement vyParser.String (w/o name convention for voyager) *)
		IF (antsCommands.GetString( "filename", name )) THEN prefix := name;  ELSE prefix := "antsPict" END;

		MakefileName( prefix, suffix, name );  aM.SS( "antsToolbox: Store Frame as GIF :", name );
		IF antsCommands.Find( "old" ) THEN pict := lastframe ELSE pict := SelectFrame();  lastframe := pict END;
		IF pict = NIL THEN aM.usage( "antsToolbox.FrameToGIF", "antsToolbox: chose frame by clicking on it after calling FrameToGIF" );  RETURN END;
		DoFrameToGIF( pict, name );
	END FrameToGIF;

	PROCEDURE FrameToGIF2*;
	VAR name, prefix, suffix: ARRAY 32 OF CHAR;
		pict: Display.Frame;
	BEGIN
		aM.vS( "antsToolbox.FrameToGIF" );  COPY( "GIF", suffix );  antsCommands.InitScan( "[filename=STR] [>old] #~ default filename IS STR" );
		(*! implement vyParser.String (w/o name convention for voyager) *)
		IF (antsCommands.GetString( "filename", name )) THEN
			aM.SS( "antsToolbox: Store Frame as GIF :", name );
			IF antsCommands.Find( "old" ) THEN pict := lastframe ELSE pict := SelectFrame();  lastframe := pict END;
			IF pict = NIL THEN aM.usage( "antsToolbox.FrameToGIF", "antsToolbox: chose frame by clicking on it after calling FrameToGIF" );  RETURN END;
			DoFrameToGIF( pict, name );
		END;
	END FrameToGIF2;

	PROCEDURE InteractiveGetCoordinates*( VAR xr, yr: LONGREAL;  VAR wr, hr: LONGREAL );
	VAR keys: SET;  x, y, dx, dy: INTEGER;  msg: GetCoordMsg;
	BEGIN
		Input.Mouse( keys, x, y );

		dx := x;  dy := y;  vyTracking.HelpAt( x, y, "move mouse to dest and click" );  vyTracking.TrackMouseCont( keys, dx, dy, Effects.PointHand );
		vyTracking.HelpEnd();
		(* one display only *)
		msg.x := dx;  msg.y := dy;  msg.update := TRUE;  MsgToXY( dx, dy, msg );  xr := msg.xr;  yr := msg.yr;  wr := msg.w;
		hr := msg.h
	END InteractiveGetCoordinates;

	PROCEDURE InteractiveMsg*( VAR msg: Objects.ObjMsg );
	VAR keys: SET;  x, y, dx, dy: INTEGER;
	BEGIN
		Input.Mouse( keys, x, y );  dx := x;  dy := y;
		vyTracking.HelpAt( x, y, "move mouse to destination and click" );   (* only if not in help *)
		vyTracking.TrackMouseCont( keys, dx, dy, Effects.PointHand );  vyTracking.HelpEnd;

		MsgToXY( dx, dy, msg );

	END InteractiveMsg;

	PROCEDURE Test*;
	VAR xr, yr, wr, hr: LONGREAL;
	BEGIN
		InteractiveGetCoordinates( xr, yr, wr, hr );  aM.SRSR( "Returned: ", xr, " ", yr );  aM.SI( "Position is : ", ENTIER( ENTIER( yr ) * hr + ENTIER( xr ) ) )
	END Test;

	PROCEDURE ShowFrame*;
	VAR context, obj: Objects.Object;
		name: ARRAY 256 OF CHAR;
	BEGIN
		Oberon.Defocus;  aM.vS( "antsToolbox.ShowFrame" );  antsCommands.InitScan( "[name=NAME]" );  context := Gadgets.executorObj;
		Links.GetLink( context, "Frame", obj );
		IF obj # NIL THEN
			vyHostTexts.InsertGadget( obj );
			IF antsCommands.GetString( "name", name ) THEN aM.dSS( "antsToolbox: NameOpened ", name );  NameOpened( name ) END
		END
	END ShowFrame;

	PROCEDURE CountMultipleObj*( name: ARRAY OF CHAR ): LONGINT;
	VAR link: vyLinks.Link;  count: LONGINT;
	BEGIN
		link := vyName.FindMultObj( name );  count := 0;
		WHILE (link # NIL ) DO INC( count );  link := link.link END;
		RETURN count
	END CountMultipleObj;

	PROCEDURE SetDocName*( d: Documents.Document;  name: ARRAY OF CHAR );
	VAR unm: Desktops.UpdateNameMsg;
	BEGIN
		COPY( name, d.name );  unm.obj := vyHostTexts.NewDocument;  Display.Broadcast( unm )
	END SetDocName;

	PROCEDURE NameOpened*( name: ARRAY OF CHAR );
	BEGIN
		IF vyHostTexts.NewDocument = NIL THEN RETURN END;
		SetDocName( vyHostTexts.NewDocument, name )
	END NameOpened;

	PROCEDURE NameOpenedWId*( name: ARRAY OF CHAR;  obj: vyBase.Object );
	VAR myname, id: ARRAY 256 OF CHAR;
	BEGIN
		IF vyHostTexts.NewDocument = NIL THEN RETURN END;
		IF obj # NIL THEN vyName.GetObjId( obj, id ) ELSE id := "" END;
		COPY( name, myname );  vyHostStrings.Append( myname, " (" );  vyHostStrings.Append( myname, id );
		vyHostStrings.Append( myname, ")" );  SetDocName( vyHostTexts.NewDocument, myname )
	END NameOpenedWId;

	PROCEDURE StartDisplayHelp*( s: ARRAY OF CHAR );
	BEGIN
		aM.dS( "antsToolbox.StartDisplayHelp" );  vyTracking.Help( s )
	END StartDisplayHelp;

	PROCEDURE EndDisplayHelp*;
	BEGIN
		aM.dS( "EndDisplayHelp" );  vyTracking.HelpEnd
	END EndDisplayHelp;

	PROCEDURE CheckSuffix( VAR name: ARRAY OF CHAR;  suffix: ARRAY OF CHAR );   (* checks if suffix in name, if no suffix, stdsuffix will be appended *)
	VAR i, start: LONGINT;
	BEGIN
		i := 0;  start := 0;
		WHILE (name[i] # 0X) DO
			IF name[i] = antsPortability.PathChar THEN start := i END;
			INC( i );
		END;
		i := start;
		WHILE (name[i] # 0X) DO
			IF name[i] = "." THEN RETURN END;
			INC( i )
		END;
		Strings.Append( name, "." );  Strings.Append( name, suffix )
	END CheckSuffix;

	PROCEDURE FinalizeFile*;
	VAR f: Files.File;  done: BOOLEAN;
		filename: ARRAY 256 OF CHAR;
	BEGIN
		aM.dS( "antsToolbox: finalizing file" );  antsPortability.FinishDialog;
		IF currentDialog = open THEN
			IF open.name # "" THEN
				f := Files.Old( open.name );
				IF f # NIL THEN
					finalize( f, open.name );
					IF f # NIL THEN Files.Close( f ) END
				END
			END
		ELSIF currentDialog = store THEN
			IF store.name # "" THEN
				COPY( store.name, filename );  CheckSuffix( filename, suffix );  f := Files.New( filename );
				IF f # NIL THEN
					aM.SS( "Storing ", filename );  finalize( f, filename );
					IF f # NIL THEN Files.Register( f );  Files.Close( f ) END;
					aM.S( "done." );
				ELSE aM.SS( "Sorry, cannot open ", filename );
				END;
			END
		END;
		fofAutomatic.stopped := NIL;
		IF task # NIL THEN Oberon.Install( task );  task := NIL END
	END FinalizeFile;

	PROCEDURE FileOpen*( p: FileFinalize;  filtername, filter: ARRAY OF CHAR );
	BEGIN
		open.context := Desktops.CurDoc( Gadgets.context );  finalize := p;  open.name := "";
		antsPortability.EmptyFilter( open );  antsPortability.AddFilter( open, filtername, filter );
		antsPortability.AddFilter( open, "All", "*.*" );  open.cmd := "antsToolbox.FinalizeFile";  currentDialog := open;
		fofAutomatic.stopped := fofAutomatic.current;  task := fofAutomatic.current;
		IF task # NIL THEN Oberon.Remove( task ) END;
		vyCommandMenus.Wait();  antsPortability.ShowDialog( open )
	END FileOpen;

	PROCEDURE FileStore*( p: FileFinalize;  filtername, filter, stdsuffix, name: ARRAY OF CHAR );
	BEGIN
		store.context := Desktops.CurDoc( Gadgets.context );  finalize := p;  COPY( stdsuffix, suffix );  COPY( name, store.name );
		antsPortability.EmptyFilter( store );  antsPortability.AddFilter( store, filtername, filter );  store.cmd := "antsToolbox.FinalizeFile";
		currentDialog := store;  fofAutomatic.stopped := fofAutomatic.current;  task := fofAutomatic.current;
		vyCommandMenus.Wait();
		IF task # NIL THEN Oberon.Remove( task ) END;
		antsPortability.ShowDialog( store )
	END FileStore;

	PROCEDURE finpg( VAR f: Files.File;  fname: ARRAY OF CHAR );
	VAR R: Files.Rider;
	BEGIN
		IF f = NIL THEN aM.SS( "Could not open file", fname );  RETURN END;
		Files.Set( R, f, 0 );  PictConverters.Pict2GIF( gPict, R )
		(*
	vyPort.StorePictAsGIF(f, R);
	INSERT DisplayGrabbing and Storing here.
	*)
	END finpg;

	PROCEDURE FocusPictToGIF*;
	VAR name: ARRAY 256 OF CHAR;
	BEGIN
		aM.vS( "antsToolbox.FocusPictToGIF" );  antsPortability.SetMousePointDisplay;  DoFrameToGIF( vyPort.focusPicture, "" );  MakefileName( "antsPortPicture", "GIF", name );
		aM.vSS( "antsToolbox: FileName = ", name );  FileStore( finpg, "GIF Image", "*.GIF", "GIF", name )
	END FocusPictToGIF;

	PROCEDURE Test2*;
	BEGIN
		FileOpen( NIL , "*.*", "*.*" )
	END Test2;

	PROCEDURE SetCoords*;
	VAR x, y, w, h: LONGREAL;  frame: Display.Frame;  context: Objects.Object;  o: Objects.Object;
	BEGIN
		context := Gadgets.executorObj;  Links.GetLink( context, "x", o );  Attributes.GetLongReal( o, "Value", (x) );
		Links.GetLink( context, "y", o );  Attributes.GetLongReal( o, "Value", (y) );  Links.GetLink( context, "w", o );
		Attributes.GetLongReal( o, "Value", (w) );  Links.GetLink( context, "h", o );  Attributes.GetLongReal( o, "Value", (h) );

		aM.vS( "antsToolbox.SetCoords" );  aM.vSRSR( "antsToolbox: x= ", x, "y= ", y );  aM.vSRSR( "antsToolbox: w= ", w, "h= ", h );

		frame := SelectFrame();
		IF (frame = NIL ) OR (~(frame IS vyPort.Picture)) THEN RETURN END;
		WITH frame: vyPort.Picture DO
			Attributes.SetLongReal( frame, "x2d", x );  Attributes.SetLongReal( frame, "y2d", y );  Attributes.SetLongReal( frame, "w2d", w );
			Attributes.SetLongReal( frame, "h2d", h )
		END
	END SetCoords;

	PROCEDURE GetCoords*;
	VAR x, y, w, h: LONGREAL;  frame: Display.Frame;
	VAR o: Objects.Object;  context: Objects.Object;
	BEGIN
		aM.vS( "antsToolbox.GetCoords" );  context := Gadgets.executorObj;  frame := SelectFrame();
		IF (frame = NIL ) OR (~(frame IS vyPort.Picture)) THEN RETURN END;
		Attributes.GetLongReal( frame, "x2d", x );  Attributes.GetLongReal( frame, "y2d", y );  Attributes.GetLongReal( frame, "w2d", w );
		Attributes.GetLongReal( frame, "h2d", h );  aM.vSRSR( "antsToolbox: x2d = ", x, " y2d = ", y );  aM.vSRSR( "antsToolbox: w2d = ", w, " h2d = ", h );

		Links.GetLink( context, "x", o );  Attributes.SetLongReal( o, "Value", (x) );  Gadgets.Update( o );

		Links.GetLink( context, "y", o );  Attributes.SetLongReal( o, "Value", (y) );  Gadgets.Update( o );

		Links.GetLink( context, "w", o );  Attributes.SetLongReal( o, "Value", (w) );  Gadgets.Update( o );

		Links.GetLink( context, "h", o );  Attributes.SetLongReal( o, "Value", (h) );  Gadgets.Update( o );  Gadgets.Update( o )

	END GetCoords;

	PROCEDURE InteractiveGetArray*( ): vyBase.Object;
	VAR msg: GetCoordMsg;  o: vyBase.Object;  keys: SET;  xm, ym: INTEGER;
	BEGIN
		msg.layer := NIL;  msg.update := FALSE;  Input.Mouse( keys, xm, ym );  vyTracking.HelpAt( xm, ym, "Click on array to take" );
		InteractiveMsg( msg );  Input.Mouse( keys, xm, ym );  msg.layer := NIL;  MsgToTypedXY( xm, ym, msg, "antsViews.tLayerDesc" );
		IF msg.layer # NIL THEN o := msg.a END;
		vyTracking.HelpEnd;  RETURN o
	END InteractiveGetArray;

	PROCEDURE InteractiveGetVector*( ): vyBase.Object;
	VAR la: vyPort.tLayer;  msg: GetCoordMsg;  keys: SET;  xm, ym: INTEGER;  pict: vyPort.Picture;
	BEGIN
		msg.layer := NIL;  msg.update := FALSE;  InteractiveMsg( msg );  Input.Mouse( keys, xm, ym );
		la := TypedLayerXY( xm, ym, "vyScatter1.tLayerDesc", pict );
		IF la = NIL THEN la := TypedLayerXY( xm, ym, "vyLinePlot.tLayerDesc", pict ) END;
		IF la = NIL THEN la := TypedLayerXY( xm, ym, "antsPointPlot.tLayerDesc", pict ) END;
		IF la = NIL THEN la := TypedLayerXY( xm, ym, "antsPointPlot.tLayerDesc", pict ) END;
		IF la # NIL THEN RETURN la.x ELSE RETURN NIL END

	END InteractiveGetVector;

	PROCEDURE Search*;
	BEGIN
		Oberon.Defocus;  TextDocs.Search
	END Search;

	PROCEDURE ReplaceTextPart*;
	VAR name, filename: ARRAY 128 OF CHAR;
		C, T: Texts.Text;  B: Texts.Buffer;  F: Files.File;  len: LONGINT;  pos0: LONGINT;
		begpat, endpat: ARRAY 32 OF CHAR;
		W: Texts.Writer;

	BEGIN
		aM.vS( "antsToolbox.ReplaceTextPart" );  Texts.OpenWriter( W );

		antsCommands.InitScan( "replaceText=STR begpat=STR endpat=STR {STR} " );
		IF antsCommands.ExpectString( "replaceText", name ) & antsCommands.ExpectString( "begpat", begpat ) &
		    antsCommands.ExpectString( "endpat", endpat ) THEN
			NEW( C );  Texts.Open( C, name );  NEW( B );  Texts.OpenBuf( B );  Texts.Save( C, 0, C.len, B );

			WHILE (antsCommands.GetString( "", filename )) DO
				Texts.WriteString( W, filename );  Texts.Append( Oberon.Log, W.buf );  NEW( T );  Texts.Open( T, filename );
				pos0 := 0;
				IF ~antsTexts.ReplaceTextPart( T, begpat, endpat, B, pos0 ) THEN Texts.WriteString( W, " no pattern found" )
				ELSE Texts.Save( C, 0, C.len, B )
				END;
				Texts.WriteLn( W );  Texts.Append( Oberon.Log, W.buf );
				(* Oberon.OpenText("title", T, 100, 100);*)
				F := Files.New( filename );  len := 0;  Texts.Store( T, F, 0, len );  Files.Register( F )

			END
		END

	END ReplaceTextPart;
(* Interaktive Routine zum Anzeigen der Zeilen und Spalten eines 2d-Bildes *)
	PROCEDURE InteractiveDo*( objects: Objects.Object;  objproc: ObjProc );
	VAR msg: GetCoordMsg;  x, y: LONGINT;  o: Objects.Object;  xm, ym: INTEGER;  keys: SET;  layer: Objects.Object;
		coords: ARRAY 64 OF CHAR;
	BEGIN
		x := MAX( LONGINT );  y := MAX( LONGINT );  msg.layer := NIL;  msg.update := TRUE;  InteractiveMsg( msg );  layer := msg.layer;
		Input.Mouse( keys, xm, ym );  msg.x := MAX( INTEGER );  msg.y := MAX( INTEGER );
		WHILE (keys # {}) DO
			IF (msg.x # xm) OR (msg.y # ym) THEN
				msg.x := xm;  msg.y := ym;  msg.update := FALSE;  msg.layer := NIL;  MsgToTypedXY( xm, ym, msg, "antsViews.tLayerDesc" );
				IF msg.layer # layer THEN msg.update := TRUE;  MsgToTypedXY( xm, ym, msg, "antsViews.tLayerDesc" );  layer := msg.layer END;

				IF (msg.a # NIL ) THEN
					x := ENTIER( msg.xr );  y := ENTIER( msg.yr );  o := msg.a;
					IF (0 <= x) & (0 <= y) THEN objproc( x, y, o, objects ) END;
					coords := "coords: x= ";  vyHostStrings.AppendInt( x, 0, coords );  vyHostStrings.Append( coords, "; y= " );
					vyHostStrings.AppendInt( y, 0, coords )
				ELSE coords := "move mouse on image layer"
				END;

				vyTracking.HelpEnd();  vyTracking.HelpAt( xm, ym + 20, coords )
			END;
			Input.Mouse( keys, xm, ym )
		END;
		vyTracking.HelpEnd();
		IF y # MAX( LONGINT ) THEN aM.SISI( "Row = ", y, "Col = ", x ) ELSE aM.S( "Hmm? Nothing selected." ) END
	END InteractiveDo;

	PROCEDURE ThisToHistory( this: Documents.Document;  VAR history: hist );
	VAR lookup: hist;
	BEGIN
		lookup := history;
		WHILE (lookup # NIL ) DO
			IF lookup.D = this THEN aM.dS( "Document already in history" );  RETURN END;
			lookup := lookup.next;
		END;
		lookup := history;  NEW( history );  history.next := lookup;  history.D := this;  COPY( this.name, history.name );
	END ThisToHistory;

	PROCEDURE FindDoc( history: hist;  VAR name: ARRAY OF CHAR ): Documents.Document;
	VAR lookup: hist;
		name1, name2: ARRAY 256 OF CHAR;
	BEGIN
		antsPortability.FileDirRelFileName( name, name1 );  lookup := history;
		WHILE (lookup # NIL ) DO
			antsPortability.FileDirRelFileName( lookup.name, name2 );
			IF antsPortability.FileDirSameName( name1, name2 ) THEN aM.dS( "antsToolbox.FindDoc, found." );  RETURN lookup.D END;
			lookup := lookup.next;
		END;
		RETURN NIL;
	END FindDoc;

	PROCEDURE ReplaceDoc*;
	VAR text: Texts.Text;  pos: LONGINT;  obj: Objects.Object;
		name: ARRAY 256 OF CHAR;
		d: Documents.Document;  S: Attributes.Scanner;
	BEGIN
		text := Oberon.Par.text;  pos := Oberon.Par.pos;  Attributes.OpenScanner( S, Oberon.Par.text, Oberon.Par.pos );
		Attributes.Scan( S );
		IF (S.class = Attributes.Name) OR (S.class = Attributes.String) THEN COPY( S.s, name );  END;
		obj := Gadgets.context;
		WHILE (obj # NIL ) & ~(obj IS Documents.Document) DO obj := obj.dlink END;
		IF obj = NIL THEN aM.eS( "antsToolbox.ReplaceDoc: cannot find context document" );  RETURN;  ELSE aM.dSS( "antsToolbox.ReplaceDoc: found ", obj( Documents.Document ).name );  END;
		ThisToHistory( obj( Documents.Document ), history );  d := FindDoc( history, name );
		IF d # NIL THEN Desktops.ReplaceCurrentDoc( d )
		ELSE Oberon.Par.pos := pos;  Oberon.Par.text := text;  Desktops.ReplaceDoc;
		END;
	END ReplaceDoc;

BEGIN
	aM.launch;  InitConversions;  dhist := NIL;  oldhh := NIL;
	(* oldhh := Documents.historyHook; *)
	Documents.historyHook := HistoryHook;  NEW( open );  NEW( store )
END antsToolbox.

antsToolbox.FrameToGIF  ~
System.Free antsToolbox ~

antsToolbox.Test ~
antsToolbox.ReplaceDoc ~

antsArrayPictures.Load > name myname > fname "Zebra.GIF" > show ~
antsViews.Show myname ~
vyHostPrint.EPS test.eps ~
vyHostPrint.PS test.ps ~
Voyager.Random 20 ~
Voyager.Show @ ~

(* mathematica file formats:
first column: enumeration
general matrix read procedure with defaults (selectable)
*)

antsToolbox.TestOverlay ~
antsToolbox.OpenDoc test ~
antsToolbox.Launch

antsToolbox.FocusPictToGIF ~

antsToolbox.SendMouseEvent ~

antsToolbox.ReplaceTextPart Copyright.vy "(* crtag""*)"
ants / src / antsToolbox.Mod
~


(*

PROCEDURE OpenDocOnce (win: BOOLEAN);
	VAR name: ARRAY 128 OF CHAR;   h: hist;   	S: Attributes.Scanner;   f: Display.Frame;   msg: Display.DisplayMsg;
	orighandle: Objects.Handler;   t: Texts.Text;   m, o, c: Objects.Object;   caption, cmd: ARRAY 256 OF CHAR;
	sc: Texts.Scanner;   lib: Objects.Library;   ref : INTEGER;    B: Objects.BindMsg;

BEGIN
	name[0] := 0X;
	Attributes.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
	Attributes.Scan(S);
	IF (S.class = Attributes.Name) OR (S.class = Attributes.String) THEN
		COPY(S.s, name);
		IF FileDir.FindFile(name, name, TRUE) THEN
			h := dhist;
			WHILE (h # NIL) DO
				IF FileDir.SameName(h.name, name) THEN
					f := h.D;
					orighandle := f.handle;
					f.handle := TempHandle;
					tempX := - 123;   tempY := - 123;
					msg.F := f;    msg.device := Display.screen;    msg.id := Display.full;    msg.res := - 1;
					Display.Broadcast(msg);
					f.handle := orighandle;
					IF (tempX # - 123) OR (tempY # - 123) THEN aM.S("Document already opend");    RETURN
					END
				END;
				h := h.next
			END
		END;
		IF win THEN

			Strings.Append(name, ".Menu");
			vyHost.GetNamedText(name, t);

			m := Gadgets.FindPublicObj("WinMenus.PanelDocs.NewDoc");
			o := m;
			c := Gadgets.Clone(m, TRUE);
			IF (t # NIL) & (m # NIL) THEN
				m := WinMenus.AppendMenu(m(WinMenus.Popup), "Ants");
				WinMenus.AppendItem(m(WinMenus.Popup), "Colors", "antsToolbox.OpenWinDoc ants/antsColors.Panel");
				WinMenus.AppendItem(m(WinMenus.Popup), "Objects", "antsObjects.ListBaseObjects");
				WinMenus.AppendItem(m(WinMenus.Popup), "Graphics", "antsToolbox.OpenWinDoc vy/doc.vyS3/vyGraphics.Panel");

				Texts.OpenScanner(sc, t, 0);
				Texts.Scan(sc);
				WHILE ~(sc.eot) DO
					COPY(sc.s, caption);
					Texts.Scan(sc);
					COPY(sc.s, cmd);
					WinMenus.AppendItem(m(WinMenus.Popup), caption, cmd);
					Texts.Scan(sc)
				END;
				Desktops.OpenWinDoc;
				(* now restoring old menu by setting clone as referenced object .. *)
				lib := o.lib;   ref := o.ref;
				Objects.PutName(lib.dict, ref, "");   lib.FreeObj(lib, ref);
				B.lib := lib;
				c.handle(c, B);
				Gadgets.NameObj(c, "PanelDocs.NewDoc");
				Objects.PutName(lib.dict, c.ref, "PanelDocs.NewDoc")

			ELSE
				Desktops.OpenWinDoc
			END
		ELSE
			Desktops.OpenDoc
		END
	END
END OpenDocOnce;

PROCEDURE OpenWinDoc*;
BEGIN
	OpenDocOnce(TRUE)
END OpenWinDoc;

PROCEDURE OpenDoc*;
BEGIN
	OpenDocOnce(FALSE)
END OpenDoc;

*)