MODULE vyXYPlane IN Oberon;
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


(*		(c) Project Voyager, StatLab Heidelberg
			(c) F.Friedrich, StatLab Heidelberg

*)

(*
	HALT codes:
	200: Bitmap could not be generated, (too little heap ?)
	201: Region for x,y in Dot(x,y,mode) : 0<=x,y<=1 offended
	202: Bitmap layer could not be found, set focus to your bitmap port or generate new.
	203: Array x and y in Scatter(x,y) and Line(x,y) must have same length.
*)

(* caution: be careful with using System.Free on Voyager files when there are ports "running"*)

IMPORT Objects, Display, vyName, vyBase, vyRealVec, vyHostDisplay := vyGraphBase, vyEvents, vyDisplay2d, vyPort,
	vyBitmaps, vyCharts, vyScatter2;

CONST
	idversion* = "vyXYPlane v0r0d0";
	BLACK = 15;   (*! check usage. replace by FGColor ? *)
TYPE
	BMPLayer = POINTER TO BMPLayerDesc;
	BMPLayerDesc = RECORD (vyPort.tLayerDesc)
		Bitmap*: vyBitmaps.tBitmap;
	END;
	identifymsg = RECORD (vyEvents.EventMsg) END;
	Pattern* = POINTER TO PatternDesc;
	PatternDesc = RECORD
		img: ARRAY 10 OF SET;
		w, h: INTEGER;
	END;
VAR
	cross*, bigcross*, dot*, bigdot*, circle*, bigcircle*, rhombus*, bigrhombus*, plus*, bigplus*: Pattern;
	PAT: Pattern;

	PROCEDURE Min*( a, b: INTEGER ): INTEGER;
	BEGIN
		IF a < b THEN RETURN a ELSE RETURN b;  END;
	END Min;

	PROCEDURE Max*( a, b: INTEGER ): INTEGER;
	BEGIN
		IF a > b THEN RETURN a ELSE RETURN b;  END;
	END Max;

	PROCEDURE Recall( layer: BMPLayer;  VAR msg: Display.DisplayMsg );
	VAR x, y, x0, y0, x1, y1, w, h: INTEGER;
	BEGIN
		vyPort.GetPictureScreenRegion( msg.dlink( vyPort.Picture ), x0, y0, w, h );
		IF (layer.Bitmap.W < w) OR (layer.Bitmap.H < h) THEN layer.Bitmap := vyBitmaps.ResizedBitmap( layer.Bitmap, w, h );  END;
		y1 := y0 + h - 1;  x1 := x0 + w - 1;
		FOR y := y0 TO y1 DO
			FOR x := x0 TO x1 DO
				IF vyBitmaps.GetAPixel( layer.Bitmap, x - x0, y - y0 ) = 1 THEN
					vyHostDisplay.SetForeColor( BLACK );  vyHostDisplay.PaintRect( x, y, 1, 1 );
				END;
			END;
		END;
	END Recall;

	PROCEDURE Responsible( layer: BMPLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: INTEGER;
	BEGIN
		priority := vyEvents.PrioHigh;
		IF event.priority < priority THEN
			IF event IS identifymsg THEN event.responder := layer;  event.priority := priority END;
		END;
	END Responsible;

	PROCEDURE Copy( source, dest: BMPLayer );
	BEGIN
		dest^ := source^;  vyBitmaps.CopyBitmap( source.Bitmap, dest.Bitmap );
		vyBitmaps.CopyColors( source.Bitmap, dest.Bitmap );
	END Copy;

	PROCEDURE Handler*( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR layer, copy: BMPLayer;
	BEGIN
		layer := o( BMPLayer );
		IF msg IS Display.DisplayMsg THEN
			WITH msg: Display.DisplayMsg DO Recall( layer, msg );
			END;
		ELSIF msg IS vyBase.UpdateMessage THEN
			WITH msg: vyBase.UpdateMessage DO vyPort.UpdateHostPicture( layer, msg );
			END;
		ELSIF msg IS vyEvents.EventMsg THEN
			WITH msg: vyEvents.EventMsg DO
				IF msg.callForResponder THEN Responsible( layer, msg ) END;
			END;
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO NEW( copy );  msg.obj := copy;  Copy( layer, msg.obj( BMPLayer ) );
			END;
		ELSE
		END;
	END Handler;

	PROCEDURE OpenBmpLayer( layer: BMPLayer;  bmp: vyBitmaps.tBitmap );
	BEGIN
		layer.Bitmap := bmp;  vyName.Register( vyName.NameBase, layer, "BMP" );  layer.handle := Handler;
	END OpenBmpLayer;

	PROCEDURE Open*;
	VAR pict: vyPort.Picture;  x, y, w, h: INTEGER;  bmp: vyBitmaps.tBitmap;  layer: BMPLayer;
	BEGIN
		pict := vyPort.InsertNewCPicture( 0, 0, 1, 1, vyDisplay2d.NewC2d( 0, 0, 1, 1 ) );
		vyPort.GetPictureScreenRegion( pict, x, y, w, h );  bmp := vyBitmaps.NewBitmap( w, h, 1, 1 );
		IF bmp = NIL THEN HALT( 200 ) END;
		NEW( layer );  OpenBmpLayer( layer, bmp );  vyPort.OpenLayer( layer, "Bitmap" );
		vyPort.AddLayer( vyPort.GetFocusPicture(), layer );
	END Open;

	PROCEDURE GetBitmapLayer( pict: vyPort.Picture ): BMPLayer;
	VAR msg: identifymsg;
	BEGIN
		pict.handle( pict, msg );
		IF msg.responder = NIL THEN RETURN NIL;  END;
		RETURN msg.responder( BMPLayer );
	END GetBitmapLayer;

	PROCEDURE ClearBmp*;
	VAR layer: BMPLayer;  pict: vyPort.Picture;  x, y, w, h: INTEGER;
	BEGIN
		pict := vyPort.GetFocusPicture();  layer := GetBitmapLayer( pict );  vyPort.GetPictureScreenRegion( pict, x, y, w, h );
		layer.Bitmap := vyBitmaps.NewBitmap( w, h, 1, 1 );  vyPort.RedrawFocusPict;
	END ClearBmp;

	PROCEDURE Dot*( x, y: REAL;  mode: INTEGER );
	VAR i, j: LONGINT;  layer: BMPLayer;  pict: vyPort.Picture;  k, k0, k1, l, l0, l1, x1, y1, w, h: INTEGER;
	BEGIN
		IF (x < 0) OR (x > 1) OR (y < 0) OR (y > 1) THEN HALT( 201 );  END;
		pict := vyPort.GetFocusPicture();  vyPort.GetPictureScreenRegion( pict, x1, y1, w, h );  layer := GetBitmapLayer( pict );
		i := ENTIER( w * x );  j := ENTIER( h * y );
		IF layer = NIL THEN HALT( 202 ) END;
		IF PAT = dot THEN
			CASE mode OF
			1:     vyBitmaps.SetAPixel( layer.Bitmap, i, j, 1 );
			| 0:   vyBitmaps.SetAPixel( layer.Bitmap, i, j, 0 );
			END;
		ELSE
			k0 := Max( 0, SHORT( i - PAT.w DIV 2 ) );  k1 := Min( layer.Bitmap.W - 1, SHORT( i + PAT.w DIV 2 ) );
			l0 := Max( 0, SHORT( j - PAT.h DIV 2 ) );  l1 := Min( layer.Bitmap.H - 1, SHORT( j + PAT.h DIV 2 ) );

			FOR k := k0 TO k1 DO
				FOR l := l0 TO l1 DO
					IF (k - i + PAT.w DIV 2) IN PAT.img[l - j + PAT.h DIV 2] THEN
						CASE mode OF
						1:     vyBitmaps.SetAPixel( layer.Bitmap, k, l, 1 );
						| 0:   vyBitmaps.SetAPixel( layer.Bitmap, k, l, 0 );
						END;
					END;
				END;
			END;
		END;
		vyPort.RedrawFocusPict;
	END Dot;

	PROCEDURE Line*( FromX, FromY, ToX, ToY: REAL;  mode: INTEGER );
	(*! Old Line renamed to PolyLine *)
	VAR i, j, i1, j1: LONGINT;  layer: BMPLayer;  pict: vyPort.Picture;  x1, y1, w, h: INTEGER;
		x, y: REAL;   (*! Hack. remove *)
	BEGIN
		x := FromX;  y := FromY;
		IF (x < 0) OR (x > 1) OR (y < 0) OR (y > 1) THEN HALT( 201 );  END;
		pict := vyPort.GetFocusPicture();  vyPort.GetPictureScreenRegion( pict, x1, y1, w, h );  layer := GetBitmapLayer( pict );
		i := ENTIER( w * x );  j := ENTIER( h * y );  x := ToX;  y := ToY;  i1 := ENTIER( w * x );  j1 := ENTIER( h * y );
		IF layer = NIL THEN HALT( 202 ) END;
		CASE mode OF
		1:     vyBitmaps.SetALine( layer.Bitmap, i, j, i1, j1, 1 );
		| 0:   vyBitmaps.SetALine( layer.Bitmap, i, j, i1, j1, 0 );
		END;
		vyPort.RedrawFocusPict;
	END Line;

	PROCEDURE IsDot*( x, y: REAL ): BOOLEAN;
	VAR mode: INTEGER;  i, j: LONGINT;  layer: BMPLayer;  pict: vyPort.Picture;  x1, y1, w, h: INTEGER;
	BEGIN
		pict := vyPort.GetFocusPicture();  vyPort.GetPictureScreenRegion( pict, x1, y1, w, h );  layer := GetBitmapLayer( pict );
		i := ENTIER( w * x );  j := ENTIER( h * y );
		IF layer = NIL THEN HALT( 202 ) END;
		mode := SHORT( vyBitmaps.GetAPixel( layer.Bitmap, i, j ) );
		CASE mode OF
		1:     RETURN TRUE;
		| 0:   RETURN FALSE;
		END;
	END IsDot;

	PROCEDURE Scatter*( VAR x, y: ARRAY OF REAL );
	VAR data: Objects.Object;  scatter: vyScatter2.tLayer;  xv, yv: vyBase.tVector;
	BEGIN
		IF LEN( x ) # LEN( y ) THEN HALT( 203 ) END;
		xv := vyRealVec.New( LEN( x ) );  vyRealVec.CopyToVec( x, xv, LEN( x ), 0, 0 );  yv := vyRealVec.New( LEN( y ) );
		vyRealVec.CopyToVec( y, yv, LEN( y ), 0, 0 );  NEW( data );  data := xv;  NEW( data.slink );  data.slink := yv;  NEW( scatter );
		vyScatter2.Init( scatter, data );  vyPort.AddLayer( vyPort.GetFocusPicture(), scatter );
	END Scatter;

	PROCEDURE PolyLine*( VAR x, y: ARRAY OF REAL );
	VAR line: vyCharts.tLayer;
	BEGIN
		IF LEN( x ) # LEN( y ) THEN HALT( 203 ) END;
		NEW( line );  line.x := vyRealVec.New( LEN( x ) );  vyRealVec.CopyToVec( x, line.x, LEN( x ), 0, 0 );  line.y := vyRealVec.New( LEN( y ) );
		vyRealVec.CopyToVec( y, line.y, LEN( y ), 0, 0 );  line.handle := vyCharts.Handler;  vyPort.OpenLayer( line, "Lines" );
		vyPort.AddLayer( vyPort.focusPicture, line );
	END PolyLine;

	PROCEDURE InitPattern;
	VAR i: ARRAY 10 OF SET;

		PROCEDURE makepat( VAR pat: Pattern;  w, h: INTEGER;  VAR img: ARRAY OF SET );
		VAR l: INTEGER;
		BEGIN
			NEW( pat );  pat.w := w;  pat.h := h;
			FOR l := 0 TO h DIV 2 DO pat.img[l] := img[l];  pat.img[h - 1 - l] := img[l];  END;
		END makepat;

	BEGIN
		makepat( dot, 3, 3, i );  i[0] := {0, 1, 2};  i[1] := {0, 1, 2};  makepat( bigdot, 3, 3, i );  i[0] := {0, 2};  i[1] := {1};
		makepat( cross, 3, 3, i );  i[0] := {0, 4};  i[1] := {1, 3};  i[2] := {2};  makepat( bigcross, 5, 5, i );  i[0] := {1};
		i[1] := {0, 1, 2};  makepat( plus, 3, 3, i );  i[0] := {2};  i[1] := {2};  i[2] := {0, 1, 2, 3, 4};  makepat( bigplus, 5, 5, i );
		i[0] := {0, 1, 2};  i[1] := {0, 2};  makepat( circle, 3, 3, i );  i[0] := {1, 2, 3};  i[1] := {0, 4};  i[2] := {0, 4};
		makepat( bigcircle, 5, 5, i );  i[0] := {1};  i[1] := {0, 2};  makepat( rhombus, 3, 3, i );  i[0] := {2};  i[1] := {1, 3};
		i[2] := {0, 4};  makepat( bigrhombus, 5, 5, i );  PAT := bigrhombus;
	END InitPattern;

	PROCEDURE SetPattern*( pat: Pattern );
	BEGIN
		PAT := pat;
	END SetPattern;

BEGIN
	InitPattern();
END vyXYPlane.


Testing