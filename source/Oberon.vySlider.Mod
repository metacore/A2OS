MODULE vySlider IN Oberon;   (*vs 0.0a1 md   09.08.95 *)
(* Copyright notice:

This file is part of Voyager
Copyright (C) 1993-2002 Project Voyager, StatLab Heidelberg ; (C) 1993-2002 G. Sawitzki et al.

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
Report any problems as soon as possible to voyager@statlab.uni-heidelberg.de
*)


(* 	(c) Project Voyager, StatLab Heidelberg
(c) M. Diller, StatLab Heidelberg
*)

(*= the slider.to get more information about the slider, see: :vy:vySlider.Info.Text *)

(*	history:
9.8.95 md 0.0a1	alpha version
26.1.95 md 0.0d16	cleaned
27.10.94 md 0.0d14	adaped to the renamed vyHostDisplay & vyPictures
------  new enumeration  --------
25.07.94 md 0.2d2
25.07.94 md 0.2d1	changed for the use of the new patterns
22.07.94 md 0.2d0	changed for the use of the VoyagerBase.tObjects
13.07.94 md 0.0d2	disconnect the slider definition from the existenz of
a coordinatesystem
11.07.94 md 0.0d1	rlx, lx, rx, rrx, by, sx, sy for caching the control location
of the slider
09.07.94 md 0.0d0	created
*)

(*!		copy a slider in another port
visual numeric value control
CLIPPING
PATTERN
connect the slider.value with the variable and ensure an update
*)

IMPORT Files, Objects, Display, vyHostStrings, vyHostTexts, vyParser, vyBase, vyName, vyRectangles,
	vyHostDisplay := vyGraphBase, vyTracking, vyPort, vyEvents;

CONST
	idversion* = "vySlider v0r0a2";
	buttomWidth = 12;  buttomHeight = 12;   (* size of the buttoms *)
	slideWidth = 20;  slideHeight = 10;   (* size of the slide *)
	(* default localisation of the slider *)
	leftMargin = 10;  rightMargin = 10;  bottomMargin = 10;  up = 0;  down = 1;
	(* color const *)
	grey1 = 12;

TYPE
	tSlider* = POINTER TO tSliderDesc;
	tSliderDesc* = RECORD (vyPort.tLayerDesc)
		Xr, Yr, Wr, Hr: INTEGER;   (* relative to the host picture *)
		X, Y, W, H: INTEGER;
		barBegin, barEnd, pos: INTEGER;   (* location of the bar & slide relative to the rect (X, Y, W, H) *)
		rlx, lx, rx, rrx, by, sx, sy: INTEGER;   (* caching the buttoms location relative to the rect (X, Y, W, H)*)
		min, max, value-: REAL;
		ticks: INTEGER;
		cmd: ARRAY 64 OF CHAR
	END;

VAR
	left-, runLeft-, right-, runRight-: vyHostDisplay.tSign;  thisSlider: tSlider;  slink*, dlink*: Objects.Object;

	PROCEDURE Copy( src, dest: tSlider );
	BEGIN
		dest^ := src^;  COPY( src.cmd, dest.cmd )
	END Copy;

	PROCEDURE P2dToP( slider: tSlider;  x: REAL ): INTEGER;
	(*= returns the pixel representing x, relative to the slider rect (X, Y, W, H) *)
	BEGIN
		RETURN slider.barBegin + SHORT( ENTIER( (x - slider.min) * ((slider.barEnd - slider.barBegin) / (slider.max - slider.min)) + 0.5 ) )
	END P2dToP;

	PROCEDURE PToP2d( slider: tSlider;  x: INTEGER ): REAL;
	(*= returns the the value, represented by the pixel x
	(relative to the slider rect (X, Y, W, H) ) *)
	BEGIN
		RETURN slider.min + (x - slider.barBegin) * ((slider.max - slider.min) / (slider.barEnd - slider.barBegin))
	END PToP2d;

	PROCEDURE TrimLocation( slider: tSlider );
	(*= sets barBegin, barEnd, rlx, lx, rx, rrx, by, sx, sy given X, Y, W, H *)
	BEGIN
		slider.rlx := 0;  slider.lx := slider.rlx + buttomWidth;
		slider.barBegin := slider.lx + buttomWidth + (slideWidth DIV 2) + 1;  slider.rrx := slider.W - buttomWidth;
		slider.rx := slider.rrx - buttomWidth;  slider.barEnd := slider.rx - ((slideWidth DIV 2) + 1);
		slider.pos := P2dToP( slider, slider.value );  slider.sx := slider.pos - (slideWidth DIV 2);  slider.by := 0;
		slider.sy := slider.by + 1
	END TrimLocation;

	PROCEDURE IncValue( slider: tSlider;  direction: INTEGER ): REAL;
	(*= calculates the next lower or upper step on the grid, depending of direction
	the identification if the slide is on a grid point is exact only to the resolution of the screen! *)
	VAR dx, ticks, x: REAL;
	BEGIN
		dx := (slider.max - slider.min) / slider.ticks;  ticks := (slider.value - slider.min) / dx;
		IF P2dToP( slider, slider.value ) # P2dToP( slider, slider.min + dx * ticks ) THEN
			IF direction = up THEN x := slider.min + dx * (ENTIER( ticks ) + 1)
			ELSIF direction = down THEN x := slider.min + dx * ENTIER( ticks )
			END
		ELSE
			IF direction = up THEN x := slider.min + dx * (ENTIER( ticks + 0.5 ) + 1)
			ELSIF direction = down THEN x := slider.min + dx * (ENTIER( ticks + 0.5 ) - 1)
			END
		END;
		RETURN x
	END IncValue;

	PROCEDURE DrawSlide( slider: tSlider;  x, y: INTEGER );
	VAR valStr: ARRAY 32 OF CHAR;
		X, Y, W, H, cx, cy, cw, ch: INTEGER;
	BEGIN
		vyHostDisplay.SetDisplayMode( vyHostDisplay.replace );  vyHostDisplay.SetForeColor( 0 );
		vyHostDisplay.PaintRect( x + 1, y + 1, slideWidth - 2, slideHeight - 2 );  vyHostDisplay.SetForeColor( 15 );
		vyHostDisplay.FrameRect( x, y, slideWidth, slideHeight );  vyHostDisplay.GetClipRect( X, Y, W, H );  cx := x;  cy := y;
		cw := slideWidth;  ch := slideHeight;  vyRectangles.RectIntersection( cx, cy, cw, ch, X, Y, W, H );
		(* vyHostDisplay.SetClipRect (cx, cy, cw, ch);*)
		vyHostStrings.AppendRealFix( slider.value, 4, 2, 5, valStr );
		vyHostDisplay.SetStringJustification( vyHostDisplay.left, vyHostDisplay.bottom );
		vyHostDisplay.String( x + 1, y, "Syntax10.Scn.Fnt", valStr );
		(*vyHostDisplay.SetClipRect (X, Y, W, H)*)
	END DrawSlide;

	PROCEDURE Recall( slider: tSlider;  VAR msg: Display.DisplayMsg );
	VAR X0, Y0, W0, H0: INTEGER;

		PROCEDURE DrawBox( x, y: INTEGER;  sgn: vyHostDisplay.tSign );
		BEGIN
			vyHostDisplay.SetForeColor( 0 );  vyHostDisplay.PaintRect( x + 1, y + 1, buttomWidth - 2, buttomWidth - 2 );
			vyHostDisplay.SetForeColor( 15 );  vyHostDisplay.FrameRect( x, y, buttomWidth, buttomWidth );
			vyHostDisplay.FrameRect( x + 2, y + 2, buttomWidth - 4, buttomWidth - 4 );
			vyHostDisplay.PaintPat( x + 3, y + 3, sgn )
		END DrawBox;

	BEGIN
		vyPort.GetPictureScreenRegion( msg.dlink( vyPort.Picture ), X0, Y0, W0, H0 );  X0 := X0 + slider.X;  Y0 := Y0 + slider.Y;

		vyHostDisplay.PaintRect( X0 + 2 * buttomWidth, Y0, slider.W - 4 * buttomWidth, slider.Hr );
		vyHostDisplay.SetForeColor( 15 );  vyHostDisplay.FrameRect( X0, Y0, slider.Wr, slider.Hr );

		vyHostDisplay.SetPatternJustification( vyHostDisplay.left, vyHostDisplay.bottom );
		DrawBox( X0 + slider.rlx, Y0 + slider.by, runLeft );  DrawBox( X0 + slider.lx, Y0 + slider.by, left );
		DrawBox( X0 + slider.rx, Y0 + slider.by, right );  DrawBox( X0 + slider.rrx, Y0 + slider.by, runRight );

		DrawSlide( slider, X0 + slider.sx, Y0 + slider.sy )
	END Recall;

	PROCEDURE Respond( slider: tSlider;  VAR event: vyEvents.EventMsg );
	VAR x0, y0, w0, h0, x, y, w, h, Dx, Dy: INTEGER;  dx: REAL;

		PROCEDURE MoveSlider( slider: tSlider;  x: REAL );
		VAR x0, y0, w0, h0: INTEGER;  res: INTEGER;
			par: ARRAY 32 OF CHAR;
		BEGIN
			vyPort.GetPictureScreenRegion( event.dlink( vyPort.Picture ), x0, y0, w0, h0 );  x0 := x0 + slider.Xr;
			y0 := y0 + slider.Yr;

			IF x < slider.min THEN x := slider.min
			END;
			IF x > slider.max THEN x := slider.max END;

			IF x = slider.value THEN RETURN
			END;

			vyHostDisplay.SetStyle( slider.style );
			vyHostDisplay.PaintRect( x0 + slider.sx, y0 + slider.sy, slideWidth + 1, slideHeight + 1 );

			slider.value := x;  slider.pos := P2dToP( slider, slider.value );  slider.sx := slider.pos - (slideWidth DIV 2);
			DrawSlide( slider, x0 + slider.sx, y0 + slider.sy );
			(**! connection to the variable, which should controlled by the slider*)
			(**! update *)
			(*VoyagerBase.Update (slider);*)
			IF slider.cmd # '' THEN
				vyHostStrings.AppendRealFix( slider.value, 8, 5, 5, par );
				(*vyHostTexts.MsgSS (slider.cmd, par);*)
				vyBase.CallWString( idversion, slider.cmd, par, TRUE , res )
			END
		END MoveSlider;

	BEGIN
		thisSlider := slider;  vyPort.GetPictureScreenRegion( event.dlink( vyPort.Picture ), x0, y0, w0, h0 );
		x0 := x0 + slider.Xr;  y0 := y0 + slider.Yr;

		IF (event.gesture = vyEvents.EvtIdent) & (event.y >= y0 + slider.by) & (event.y <= y0 + slider.by + buttomHeight) THEN
			y := y0 + slider.by + 1;  h := buttomHeight - 2;  w := h;  dx := (slider.max - slider.min) / slider.ticks;
			IF (event.x >= x0 + slider.rlx) & (event.x <= x0 + slider.rlx + buttomWidth) THEN
				(* run left   *)
				x := x0 + slider.rlx + 1;  vyHostDisplay.InvertRect( x, y, w, h );
				WHILE (slider.value > slider.min) DO MoveSlider( slider, IncValue( slider, down ) ) END;
				WHILE event.gesture # vyEvents.EvtEmpty DO vyEvents.GetEvent( event ) END;
				vyHostDisplay.InvertRect( x, y, w, h )
			ELSIF (event.x >= x0 + slider.lx) & (event.x <= x0 + slider.lx + buttomWidth) THEN
				(* left   *)
				x := x0 + slider.lx + 1;  vyHostDisplay.InvertRect( x, y, w, h );  MoveSlider( slider, IncValue( slider, down ) );
				WHILE event.gesture # vyEvents.EvtEmpty DO vyEvents.GetEvent( event ) END;
				vyHostDisplay.InvertRect( x, y, w, h )
			ELSIF (event.x >= x0 + slider.rx) & (event.x <= x0 + slider.rx + buttomWidth) THEN
				(* right   *)
				x := x0 + slider.rx + 1;  vyHostDisplay.InvertRect( x, y, w, h );  MoveSlider( slider, IncValue( slider, up ) );
				WHILE event.gesture # vyEvents.EvtEmpty DO vyEvents.GetEvent( event ) END;
				vyHostDisplay.InvertRect( x, y, w, h )
			ELSIF (event.x >= x0 + slider.rrx) & (event.x <= x0 + slider.rrx + buttomWidth) THEN
				(* run right   *)
				x := x0 + slider.rrx + 1;  vyHostDisplay.InvertRect( x, y, w, h );
				WHILE (slider.value < slider.max) DO MoveSlider( slider, IncValue( slider, up ) ) END;
				WHILE event.gesture # vyEvents.EvtEmpty DO vyEvents.GetEvent( event ) END;
				vyHostDisplay.InvertRect( x, y, w, h )
			ELSIF (event.x >= x0 + slider.sx) & (event.x <= x0 + slider.sx + slideWidth) THEN
				(* slider   *)
				REPEAT
					x := event.x;  vyEvents.GetEvent( event );
					IF (event.gesture = vyEvents.EvtIdent) & (event.x # x) THEN
						vyHostDisplay.FadeCursor;  MoveSlider( slider, PToP2d( slider, event.x - x0 ) );
						vyHostDisplay.DrawCursor( event.x, event.y )
					END
				UNTIL ~(event.gesture = vyEvents.EvtIdent)

			ELSE  (* drag slider   *)
				x := x0;  y := y0;  w := slider.W;  h := slider.H;  vyTracking.Rectangle( x, y, w, h, Dx, Dy );
				IF (Dx # 0) OR (Dy # 0) THEN
					slider.Xr := slider.Xr + Dx;  slider.Y := slider.Yr + Dy;  vyPort.PictureUpdate( event.dlink( vyPort.Picture ) )
				END
			END;
			WHILE event.gesture # vyEvents.EvtEmpty DO vyEvents.GetEvent( event ) END
		END
	END Respond;

	PROCEDURE PointInSlider( x, y: INTEGER;  slider: tSlider;  VAR event: vyEvents.EventMsg ): BOOLEAN;
	VAR X0, Y0, W0, H0: INTEGER;
	BEGIN
		vyPort.GetPictureScreenRegion( event.dlink( vyPort.Picture ), X0, Y0, W0, H0 );  X0 := X0 + slider.Xr;
		Y0 := Y0 + slider.Yr;

		RETURN vyRectangles.PointInRect( x, y, X0, Y0, slider.Wr, slider.Hr )
	END PointInSlider;

	PROCEDURE Responsible( slider: tSlider;  VAR event: vyEvents.EventMsg );
	VAR priority: INTEGER;
	BEGIN
		priority := vyEvents.PrioNone;
		IF (event.gesture = vyEvents.EvtIdent) THEN
			IF PointInSlider( event.x, event.y, slider, event ) THEN priority := vyEvents.PrioHigh END
		END;

		IF event.priority < priority THEN event.responder := slider;  event.priority := priority
		END
	END Responsible;

	PROCEDURE HandleAttributes( obj: tSlider;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'vySlider.Alloc', M.s );  M.class := Objects.String;  M.res := 0
			ELSIF M.name = "value" THEN M.class := Objects.Real;  M.x := obj.value;  M.res := 0
			ELSE vyPort.LayerHandler( obj, M )
			END
		ELSIF M.id = Objects.enum THEN vyPort.LayerHandler( obj, M );  M.Enum( "value" )
		ELSE vyPort.LayerHandler( obj, M )
		END
	END HandleAttributes;

	PROCEDURE Store0( obj: tSlider;  VAR M: Objects.FileMsg );
	BEGIN
		Files.WriteInt( M.R, obj.Xr );  Files.WriteInt( M.R, obj.Yr );  Files.WriteInt( M.R, obj.Wr );  Files.WriteInt( M.R, obj.Hr );
		Files.WriteInt( M.R, obj.X );  Files.WriteInt( M.R, obj.Y );  Files.WriteInt( M.R, obj.W );  Files.WriteInt( M.R, obj.H );
		Files.WriteInt( M.R, obj.barBegin );  Files.WriteInt( M.R, obj.barEnd );  Files.WriteInt( M.R, obj.pos );
		Files.WriteInt( M.R, obj.rlx );  Files.WriteInt( M.R, obj.lx );  Files.WriteInt( M.R, obj.rx );  Files.WriteInt( M.R, obj.rrx );
		Files.WriteInt( M.R, obj.by );  Files.WriteInt( M.R, obj.sx );  Files.WriteInt( M.R, obj.sy );
		Files.WriteReal( M.R, obj.min );  Files.WriteReal( M.R, obj.max );  Files.WriteReal( M.R, obj.value );
		Files.WriteInt( M.R, obj.ticks );  Files.WriteString( M.R, obj.cmd )
	END Store0;

	PROCEDURE Load0( obj: tSlider;  VAR M: Objects.FileMsg );
	BEGIN
		dlink := M.dlink;  Files.ReadInt( M.R, obj.Xr );  Files.ReadInt( M.R, obj.Yr );  Files.ReadInt( M.R, obj.Wr );
		Files.ReadInt( M.R, obj.Hr );  Files.ReadInt( M.R, obj.X );  Files.ReadInt( M.R, obj.Y );  Files.ReadInt( M.R, obj.W );
		Files.ReadInt( M.R, obj.H );  Files.ReadInt( M.R, obj.barBegin );  Files.ReadInt( M.R, obj.barEnd );
		Files.ReadInt( M.R, obj.pos );  Files.ReadInt( M.R, obj.rlx );  Files.ReadInt( M.R, obj.lx );  Files.ReadInt( M.R, obj.rx );
		Files.ReadInt( M.R, obj.rrx );  Files.ReadInt( M.R, obj.by );  Files.ReadInt( M.R, obj.sx );  Files.ReadInt( M.R, obj.sy );
		Files.ReadReal( M.R, obj.min );  Files.ReadReal( M.R, obj.max );  Files.ReadReal( M.R, obj.value );
		Files.ReadInt( M.R, obj.ticks );  Files.ReadString( M.R, obj.cmd )
	END Load0;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	(*vs 0.0a1	md  20.07.94 *)
	VAR copy: tSlider;
	BEGIN
		WITH obj: tSlider DO
			IF msg IS Display.DisplayMsg THEN
				WITH msg: Display.DisplayMsg DO Recall( obj, msg );
				END;
			ELSIF msg IS Objects.CopyMsg THEN
				WITH msg: Objects.CopyMsg DO
					NEW( copy );  msg.obj := copy;  vyPort.LayerHandler( obj, msg );  Copy( obj, msg.obj( tSlider ) );
				END;
			ELSIF msg IS vyEvents.EventMsg THEN
				WITH msg: vyEvents.EventMsg DO
					IF msg.callForResponder THEN Responsible( obj, msg ) ELSE
						IF msg.gesture = vyEvents.EvtSelect THEN  (*Select (slider, msg)*)
						ELSIF msg.gesture = vyEvents.EvtIdent THEN Respond( obj, msg )
						END
					END
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO
					IF msg.id = Objects.load THEN Load0( obj, msg );  vyPort.LayerHandler( obj, msg )
					ELSIF msg.id = Objects.store THEN Store0( obj, msg );  vyPort.LayerHandler( obj, msg )
					ELSE vyPort.LayerHandler( obj, msg )
					END;
				END;
			ELSIF msg IS Objects.AttrMsg THEN
				WITH msg: Objects.AttrMsg DO HandleAttributes( obj, msg )
				END;
			ELSE vyPort.LayerHandler( obj, msg )
			END
		END
	END Handler;

	PROCEDURE Init( F: tSlider );
	BEGIN
		F.handle := Handler
	END Init;

	PROCEDURE Open*( F: tSlider;  picture: vyPort.Picture;  min, max, value: REAL;  ticks: INTEGER );
	VAR x, y, w, h: INTEGER;
	BEGIN
		Init( F );  vyPort.OpenLayer( F, "slider" );  F.style.fcol := grey1;  F.min := min;  F.max := max;  F.ticks := ticks;  F.value := value;
		F.Xr := leftMargin;  F.Yr := bottomMargin;  vyPort.GetPictureScreenRegion( picture, x, y, w, h );
		F.Wr := w - leftMargin - rightMargin;  F.Hr := buttomHeight;  F.by := 0;  F.sy := F.by + 1;  TrimLocation( F );
		thisSlider := F
	END Open;

	PROCEDURE Insert*;
	VAR pict: vyPort.Picture;  from, to, value: REAL;  slider: tSlider;  ticks: LONGINT;

		PROCEDURE GetValues;
		VAR s: vyParser.Scanner;  x: REAL;
		BEGIN
			vyParser.OpenParScanner( s );
			IF vyParser.Real( s, from ) & vyParser.Real( s, to ) & vyParser.Real( s, value ) & vyParser.Number( s, ticks ) THEN
				IF from > to THEN x := from;  from := to;  to := x END;
				IF value < from THEN value := from
				ELSIF value > to THEN value := to
				END
			END
		END GetValues;

	BEGIN
		(*	get and check focused port			  *)
		pict := vyPort.GetFocusPicture();
		IF pict = NIL THEN vyHostTexts.Msg( "vySlider: no picture focused" );  RETURN END;

		(*	get and check the variable names	  *)
		from := 0;  to := 1;  ticks := 50;  value := 0.5;  GetValues;

		(*	add slider to the focus pict	  *)
		NEW( slider );  Open( slider, pict, from, to, value, SHORT( ticks ) );  vyPort.AddLayer( pict, slider );  vyPort.PictureUpdate( pict )
	END Insert;

	PROCEDURE Alloc*;
	VAR layer: tSlider;
	BEGIN
		NEW( layer );  layer.handle := Handler;  Objects.NewObj := layer
	END Alloc;

	PROCEDURE Cmd*;
	(*vs 0.0a1 *)  (* md  14.11.94 *)
	VAR m, sep, c: ARRAY 32 OF CHAR;
		cmd: ARRAY 64 OF CHAR;
		s: vyParser.Scanner;  id: vyName.tNameArray;
	BEGIN
		vyParser.OpenParScanner( s );
		IF ~(vyParser.Name( s, m ) & vyParser.Symbol( s, sep ) & vyParser.Name( s, c )) THEN vyHostTexts.Msg( "syntax error: " );  RETURN END;

		(* 	IF ~((vyScanners.NextToken(s) = vyScanners.ctId) & (vyScanners.GetName(s, m))
	& (vyScanners.NextToken(s) = vyScanners.ctSym) & (vyScanners.GetName(s, sep))
	& (vyScanners.NextToken(s) = vyScanners.ctId) & (vyScanners.GetName(s, c)))THEN
	vyHostTexts.Msg ("syntax error: "); RETURN
	END; *)

		COPY( m, cmd );  vyHostStrings.Append( cmd, sep );  vyHostStrings.Append( cmd, c );  vyHostTexts.Msg( cmd );

		COPY( cmd, thisSlider.cmd );  COPY( "slider: ", id );  vyHostStrings.Append( id, cmd );  vyName.RegisterNamed( thisSlider, id )
	END Cmd;

	PROCEDURE help;
	BEGIN
		vyHostTexts.Msg( "" );  vyHostTexts.Msg( "Slider - help:" );  vyHostTexts.Msg( "Insert:    Syntax: Slider.Insert [<from> <to> [<value> [<ticks>]]]; where" );  vyHostTexts.Msg( "   <from>, <to> defines the range (default: 0 1)," );  vyHostTexts.Msg( "   <value> the starting value" );
		vyHostTexts.Msg( "   and <ticks> the number of steps for as automatic run" );  vyHostTexts.Msg( "" );  vyHostTexts.Msg( "Set:   Syntax: Slider.Set <varName> <value>" );  vyHostTexts.Msg( "   sets the variable <varName> of the first slider found in the focus port" );  vyHostTexts.Msg( "   <varName>: from" );
		vyHostTexts.Msg( "   <varName>: to" );  vyHostTexts.Msg( "   <varName>: value" );  vyHostTexts.Msg( "   <varName>: ticks" )
	END help;

	PROCEDURE Set*;
	VAR s: vyParser.Scanner;  code: vyName.tNameArray;  val: REAL;
	BEGIN
		vyParser.OpenParScanner( s );
		IF ~(vyParser.Name( s, code ) & vyParser.Real( s, val )) THEN help;  RETURN END;

		IF code = "from" THEN thisSlider.min := val
		ELSIF code = "to" THEN thisSlider.max := val
		ELSIF code = "value" THEN
			IF ~(thisSlider.min < val) & (thisSlider.max > val) THEN help;  RETURN END;
			thisSlider.value := val
		ELSIF code = "ticks" THEN thisSlider.ticks := SHORT( ENTIER( val ) )
		END;

		TrimLocation( thisSlider );
		(*!broadcast?	vyPort.PictureUpdate (vyPort.HostPicture (thisSlider))*)
	END Set;

	PROCEDURE Help*;
	BEGIN
		help
	END Help;

	PROCEDURE InitPattern;
	VAR image: ARRAY 9 OF SET;
	BEGIN
		(*	left		  *)
		image[1] := {4, 5};  image[2] := {3, 4};  image[3] := {2, 3};  image[4] := {1, 2};  image[5] := image[3];
		image[6] := image[2];  image[7] := image[1];  left := vyHostDisplay.NewPattern( image, 7, 7, NIL );

		(*	runLeft	  *)
		image[1] := {3, 4, 7};  image[2] := {2, 3, 6, 7};  image[3] := {1, 2, 5, 6, 7};  image[4] := {0, 1, 4, 5, 6, 7};
		image[5] := image[3];  image[6] := image[2];  image[7] := image[1];
		runLeft := vyHostDisplay.NewPattern( image, 7, 7, NIL );

		(*	right		  *)
		image[1] := {1, 2};  image[2] := {2, 3};  image[3] := {3, 4};  image[4] := {4, 5};  image[5] := image[3];
		image[6] := image[2];  image[7] := image[1];  right := vyHostDisplay.NewPattern( image, 7, 7, NIL );

		(*	runRight	  *)
		image[1] := {0, 3, 4};  image[2] := {0, 1, 4, 5};  image[3] := {0, 1, 2, 5, 6};  image[4] := {0, 1, 2, 3, 6, 7};
		image[5] := image[3];  image[6] := image[2];  image[7] := image[1];
		runRight := vyHostDisplay.NewPattern( image, 7, 7, NIL )
	END InitPattern;

BEGIN
	InitPattern;
END vySlider.