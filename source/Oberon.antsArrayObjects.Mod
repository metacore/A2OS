MODULE antsArrayObjects IN Oberon;   (*  fof   **)
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



(*** 2 dim Arrays wrapped in a Voyager object *)
IMPORT vyBase, vyInteger, vyLongint, vyLongreal, Objects, antsCommands, antsToolbox, vyCommandMenus, vyRectangles,
	antsPictCoordinate, Links, Attributes, Files, vyName, vyHostTexts, antsObjects, vyLongrealVec, antsReadWrite, vyLinks,
	vyStrings := vyHostStrings, antsArrays, Input, vyTracking, aM := antsMessages, antsFiles;

CONST

TYPE

	tINTEGERArray* = antsArrays.I2d;  tLONGINTArray* = antsArrays.L2d;  tLONGREALArray* = antsArrays.X2d;

	tObject* = POINTER TO tObjectDesc;
	tObjectDesc* = RECORD (vyBase.ObjDesc);
		w*, h*: LONGINT
	END;

	tINTEGERObject* = POINTER TO tINTEGERObjectDesc;
	tINTEGERObjectDesc* = RECORD (tObjectDesc)
		A*, Cache*: tINTEGERArray;
		depth*: LONGINT
	END;

	tLONGINTObject* = POINTER TO tLONGINTObjectDesc;
	tLONGINTObjectDesc* = RECORD (tObjectDesc)
		A*, Cache*: tLONGINTArray;
		depth*: LONGINT
	END;

	tLONGREALObject* = POINTER TO tLONGREALObjectDesc;
	tLONGREALObjectDesc* = RECORD (tObjectDesc)
		A*, Cache*: tLONGREALArray;
		depth*: LONGREAL
	END;

CONST

VAR
	globalLA: tLONGINTArray;  newobject-: tObject;  globalD: LONGINT;  globalobj: tObject;  loadedobj*: tObject;
	(* RandomR-: tLONGREALArray; RandomL-:tLONGINTArray; 	*)

	ra*: POINTER TO ARRAY OF LONGREAL;
	la*: POINTER TO ARRAY OF LONGINT;
	ia*: POINTER TO ARRAY OF INTEGER;


	(** top is EXCLUSIVE ! i.e. top = 2 => max = 1 *)
	(*
	PROCEDURE Uniform1dR* (VAR a: ARRAY OF LONGREAL; x,w: LONGINT; top: LONGREAL);
	VAR  xx: LONGINT;
	BEGIN
	vyRanBase.RandomUVX(w,a,x);
	IF top #1 THEN
	FOR xx := x TO x+w-1 DO
	a[xx] := a[xx]*top;
	END;
	END;
	END Uniform1dR;

	PROCEDURE Uniform1dL* (VAR a: ARRAY OF LONGINT; x,w: LONGINT; top: LONGINT);
	BEGIN
	vyRanBase.RandomLV(top,TRUE,LEN(a),a,0);
	(*antsRandom.gen.GetRandomLV(antsRandom.gen,top,LEN(a),a,0); *)
	END Uniform1dL;

	PROCEDURE Uniform1dI* (VAR a: ARRAY OF INTEGER; x,w: LONGINT; top: INTEGER);
	VAR xx: LONGINT;
	BEGIN
	IF (la=NIL) OR (LEN(la^)#w) THEN NEW(la,w) END;
	Uniform1dL(la^,0,w,top);
	FOR xx := 0 TO w-1 DO
	a[xx+x] := SHORT(la[xx]);
	END;
	END Uniform1dI;
	*)

(*
	PROCEDURE UniformINTEGERArray* (A: tINTEGERArray; top: INTEGER; x,y,w,h: LONGINT);
	VAR  y0: LONGINT ;
	BEGIN
	FOR y0 := y TO y+h-1 DO
	Uniform1dI(A[y0],x,w,top);
	END;
	END UniformINTEGERArray;

	PROCEDURE UniformLONGINTArray* (A: tLONGINTArray; top: LONGINT; x,y,w,h: LONGINT);
	VAR  y0: LONGINT ;
	BEGIN
	FOR y0 := y TO y+h-1 DO
	Uniform1dL(A[y0],x,w,top);
	END;
	END UniformLONGINTArray;

	PROCEDURE UniformLONGREALArray* (A: tLONGREALArray; top: LONGREAL; x,y,w,h: LONGINT);
	VAR  y0: LONGINT ;
	BEGIN
	FOR y0 := y TO y+h-1 DO
	Uniform1dR(A[y0],x,w,top);
	END;

	END UniformLONGREALArray;
	*)
	PROCEDURE UniformO*( o: tObject );
	BEGIN
		IF o = NIL THEN RETURN END;
		IF o IS tLONGREALObject THEN
			WITH o: tLONGREALObject DO
				antsArrays.Uniform2dX( o.A^, o.depth, 0, 0, o.w, o.h );
				(* UniformLONGREALArray(o.A,o.depth,0,0,o.w,o.h);*)
			END;
		ELSIF o IS tLONGINTObject THEN
			WITH o: tLONGINTObject DO
				antsArrays.Uniform2dL( o.A^, o.depth, 0, 0, o.w, o.h );
				(* UniformLONGINTArray(o.A,o.depth-1,0,0,o.w,o.h); *)
			END;
		ELSIF o IS tINTEGERObject THEN
			WITH o: tINTEGERObject DO
				antsArrays.Uniform2dI( o.A^, SHORT( o.depth ), 0, 0, o.w, o.h );
				(*UniformINTEGERArray(o.A,SHORT(o.depth),0,0,o.w,o.h);*)
			END;
		END
	END UniformO;

	PROCEDURE CopyII*( a: tINTEGERArray;  VAR A: tINTEGERArray;  sx, sy, w, h, dx, dy: LONGINT );
	VAR y, x: LONGINT;
	BEGIN
		IF a = NIL THEN A := NIL;  RETURN END;
		IF (A = NIL ) OR (LEN( A ) < dy + h) OR (LEN( A[0] ) < dx + w) THEN NEW( A, dy + h, dx + w ) END;
		FOR y := 0 TO h - 1 DO
			FOR x := 0 TO w - 1 DO A[dy + y, dx + x] := a[sy + y, sx + x] END
		END
	END CopyII;

	PROCEDURE CopyLI*( a: tLONGINTArray;  VAR A: tINTEGERArray;  sx, sy, w, h, dx, dy: LONGINT );
	VAR y, x: LONGINT;
	BEGIN
		IF a = NIL THEN A := NIL;  RETURN END;
		IF (A = NIL ) OR (LEN( A ) < dy + h) OR (LEN( A[0] ) < dx + w) THEN NEW( A, dy + h, dx + w ) END;
		FOR y := 0 TO h - 1 DO
			FOR x := 0 TO w - 1 DO A[dy + y, dx + x] := SHORT( a[sy + y, sx + x] ) END
		END
	END CopyLI;

	PROCEDURE CopyRI*( a: tLONGREALArray;  VAR A: tINTEGERArray;  sx, sy, w, h, dx, dy: LONGINT );
	VAR y, x: LONGINT;
	BEGIN
		IF a = NIL THEN A := NIL;  RETURN END;
		IF (A = NIL ) OR (LEN( A ) < dy + h) OR (LEN( A[0] ) < dx + w) THEN NEW( A, dy + h, dx + w ) END;
		FOR y := 0 TO h - 1 DO
			FOR x := 0 TO w - 1 DO A[dy + y, dx + x] := SHORT( ENTIER( a[sy + y, sx + x] + 0.5 ) ) END
		END
	END CopyRI;

	PROCEDURE CopyIL*( a: tINTEGERArray;  VAR A: tLONGINTArray;  sx, sy, w, h, dx, dy: LONGINT );
	VAR y, x: LONGINT;
	BEGIN
		IF a = NIL THEN A := NIL;  RETURN END;
		IF (A = NIL ) OR (LEN( A ) < dy + h) OR (LEN( A[0] ) < dx + w) THEN NEW( A, dy + h, dx + w ) END;
		FOR y := 0 TO h - 1 DO
			FOR x := 0 TO w - 1 DO A[dy + y, dx + x] := a[sy + y, sx + x] END
		END
	END CopyIL;

	PROCEDURE CopyUnsignedIL*( a: tINTEGERArray;  VAR A: tLONGINTArray;  sx, sy, w, h, dx, dy: LONGINT );
	VAR y, x: LONGINT;
	BEGIN
		IF a = NIL THEN A := NIL;  RETURN END;
		IF (A = NIL ) OR (LEN( A ) < dy + h) OR (LEN( A[0] ) < dx + w) THEN NEW( A, dy + h, dx + w ) END;
		FOR y := 0 TO h - 1 DO
			FOR x := 0 TO w - 1 DO
				A[y, x] := a[sy + y, sx + x];
				IF A[dy + y, dx + x] < 0 THEN A[y, x] := 2 * MAX( INTEGER ) + A[dy + y, dx + x] END
			END
		END
	END CopyUnsignedIL;

	PROCEDURE CopyLL*( a: tLONGINTArray;  VAR A: tLONGINTArray;  sx, sy, w, h, dx, dy: LONGINT );
	VAR y, x: LONGINT;
	BEGIN
		IF a = NIL THEN A := NIL;  RETURN END;
		IF (A = NIL ) OR (LEN( A ) < dy + h) OR (LEN( A[0] ) < dx + w) THEN NEW( A, dy + h, dx + w ) END;
		FOR y := 0 TO h - 1 DO
			FOR x := 0 TO w - 1 DO A[dy + y, dx + x] := a[sy + y, sx + x] END
		END
	END CopyLL;

	PROCEDURE CopyRL*( a: tLONGREALArray;  VAR A: tLONGINTArray;  sx, sy, w, h, dx, dy: LONGINT );
	VAR y, x: LONGINT;
	BEGIN
		IF a = NIL THEN A := NIL;  RETURN END;
		IF (A = NIL ) OR (LEN( A ) < dy + h) OR (LEN( A[0] ) < dx + w) THEN NEW( A, dy + h, dx + w ) END;
		FOR y := 0 TO h - 1 DO
			FOR x := 0 TO w - 1 DO A[y, x] := ENTIER( a[sy + y, sx + x] + 0.5 ) END
		END
	END CopyRL;

	PROCEDURE CopyIR*( a: tINTEGERArray;  VAR A: tLONGREALArray;  sx, sy, w, h, dx, dy: LONGINT );
	VAR y, x: LONGINT;
	BEGIN
		IF a = NIL THEN A := NIL;  RETURN END;
		IF (A = NIL ) OR (LEN( A ) < dy + h) OR (LEN( A[0] ) < dx + w) THEN NEW( A, dy + h, dx + w ) END;
		FOR y := 0 TO h - 1 DO
			FOR x := 0 TO w - 1 DO A[dy + y, dx + x] := a[sy + y, sx + x] END
		END
	END CopyIR;

	PROCEDURE CopyUnsignedIR*( a: tINTEGERArray;  VAR A: tLONGREALArray;  sx, sy, w, h, dx, dy: LONGINT );
	VAR y, x: LONGINT;
	BEGIN
		IF a = NIL THEN A := NIL;  RETURN END;
		IF (A = NIL ) OR (LEN( A ) < dy + h) OR (LEN( A[0] ) < dx + w) THEN NEW( A, dy + h, dx + w ) END;
		FOR y := 0 TO h - 1 DO
			FOR x := 0 TO w - 1 DO
				A[dy + y, dx + x] := a[sy + y, sx + x];
				IF A[dy + y, dx + x] < 0 THEN A[y, x] := 2 * MAX( INTEGER ) + A[dy + y, dx + x] END
			END
		END
	END CopyUnsignedIR;

	PROCEDURE CopyLR*( a: tLONGINTArray;  VAR A: tLONGREALArray;  sx, sy, w, h, dx, dy: LONGINT );
	VAR y, x: LONGINT;
	BEGIN
		IF a = NIL THEN A := NIL;  RETURN END;
		IF (A = NIL ) OR (LEN( A ) < dy + h) OR (LEN( A[0] ) < dx + w) THEN NEW( A, dy + h, dx + w ) END;
		FOR y := 0 TO h - 1 DO
			FOR x := 0 TO w - 1 DO A[dy + y, dx + x] := a[sy + y, sx + x] END
		END
	END CopyLR;

	PROCEDURE CopyRR*( a: tLONGREALArray;  VAR A: tLONGREALArray;  sx, sy, w, h, dx, dy: LONGINT );
	VAR y, x: LONGINT;
	BEGIN
		IF a = NIL THEN A := NIL;  RETURN END;
		IF (A = NIL ) OR (LEN( A ) < dy + h) OR (LEN( A[0] ) < dx + w) THEN NEW( A, dy + h, dx + w ) END;
		FOR y := 0 TO h - 1 DO
			FOR x := 0 TO w - 1 DO A[dy + y, dx + x] := ENTIER( a[sy + y, sx + x] + 0.5 ) END
		END
	END CopyRR;

	PROCEDURE FillIntArray*( val: INTEGER;  A: tINTEGERArray;  x, y, w, h: LONGINT );
	VAR curline: LONGINT;
	BEGIN
		FOR curline := y TO y + h - 1 DO vyInteger.Fill( w, A[curline], x, val ) END
	END FillIntArray;

	PROCEDURE FillLongintArray*( val: LONGINT;  A: tLONGINTArray;  x, y, w, h: LONGINT );
	VAR curline: LONGINT;
	BEGIN
		FOR curline := y TO y + h - 1 DO vyLongint.Fill( w, A[curline], x, val ) END
	END FillLongintArray;

	PROCEDURE FillLongrealArray*( val: LONGREAL;  A: tLONGREALArray;  x, y, w, h: LONGINT );
	VAR curline: LONGINT;
	BEGIN
		FOR curline := y TO y + h - 1 DO vyLongreal.Fill( w, A[curline], x, val ) END
	END FillLongrealArray;

	OPERATOR "+"*( a, b: tLONGREALArray ): tLONGREALArray;
	VAR y, x: LONGINT;  res: tLONGREALArray;  w, h: LONGINT;
	BEGIN
		IF (a = NIL ) OR (b = NIL ) THEN RETURN NIL END;
		h := Min( LEN( a ), LEN( b ) );  w := Min( LEN( a[0] ), LEN( b[0] ) );  NEW( res, h, w );
		FOR y := 0 TO Min( LEN( a ), LEN( b ) ) - 1 DO vyLongreal.Add( a[y], b[y], res[y], Min( LEN( a[0] ), LEN( b[0] ) ) ) END;
		RETURN res
	END "+";

	OPERATOR "-"*( a, b: tLONGREALArray ): tLONGREALArray;
	VAR y, x: LONGINT;  res: tLONGREALArray;  w, h: LONGINT;
	BEGIN
		IF (a = NIL ) OR (b = NIL ) THEN RETURN NIL END;
		h := Min( LEN( a ), LEN( b ) );  w := Min( LEN( a[0] ), LEN( b[0] ) );  NEW( res, h, w );
		FOR y := 0 TO Min( LEN( a ), LEN( b ) ) - 1 DO vyLongreal.Sub( a[y], b[y], res[y], Min( LEN( a[0] ), LEN( b[0] ) ) ) END;
		RETURN res;
	END "-";

	OPERATOR "*"*( a, b: tLONGREALArray ): tLONGREALArray;
	VAR y, x: LONGINT;  res: tLONGREALArray;  w, h: LONGINT;
	BEGIN
		IF (a = NIL ) OR (b = NIL ) THEN RETURN NIL END;
		h := Min( LEN( a ), LEN( b ) );  w := Min( LEN( a[0] ), LEN( b[0] ) );  NEW( res, h, w );
		FOR y := 0 TO Min( LEN( a ), LEN( b ) ) - 1 DO vyLongreal.Mul( a[y], b[y], res[y], Min( LEN( a[0] ), LEN( b[0] ) ) ) END;
		RETURN res;
	END "*";

	OPERATOR "/"*( a, b: tLONGREALArray ): tLONGREALArray;
	VAR y, x: LONGINT;  res: tLONGREALArray;  w, h: LONGINT;
	BEGIN
		IF (a = NIL ) OR (b = NIL ) THEN RETURN NIL END;
		h := Min( LEN( a ), LEN( b ) );  w := Min( LEN( a[0] ), LEN( b[0] ) );  NEW( res, h, w );
		FOR y := 0 TO Min( LEN( a ), LEN( b ) ) - 1 DO vyLongreal.Div( a[y], b[y], res[y], Min( LEN( a[0] ), LEN( b[0] ) ) ) END;
		RETURN res;
	END "/";

	OPERATOR "+"*( a: tLONGREALArray;  b: LONGREAL ): tLONGREALArray;
	VAR y, x: LONGINT;  res: tLONGREALArray;
	BEGIN
		IF (a = NIL ) THEN RETURN NIL END;
		NEW( res, LEN( a ), LEN( a[0] ) );
		FOR y := 0 TO LEN( a ) - 1 DO vyLongreal.Copy( LEN( a[0] ), a[y], 0, res[y], 0 );  vyLongreal.AddConst( LEN( a[0] ), res[y], 0, b ) END;
		RETURN res;
	END "+";

	OPERATOR "-"*( a: tLONGREALArray;  b: LONGREAL ): tLONGREALArray;
	VAR y, x: LONGINT;  res: tLONGREALArray;
	BEGIN
		IF (a = NIL ) THEN RETURN NIL END;
		NEW( res, LEN( a ), LEN( a[0] ) );
		FOR y := 0 TO LEN( a ) - 1 DO vyLongreal.Copy( LEN( a[0] ), a[y], 0, res[y], 0 );  vyLongreal.SubConst( LEN( a[0] ), res[y], 0, b ) END;
		RETURN res;
	END "-";

	OPERATOR "*"*( a: tLONGREALArray;  b: LONGREAL ): tLONGREALArray;
	VAR y, x: LONGINT;  res: tLONGREALArray;
	BEGIN
		IF (a = NIL ) THEN RETURN NIL END;
		NEW( res, LEN( a ), LEN( a[0] ) );
		FOR y := 0 TO LEN( a ) - 1 DO vyLongreal.Copy( LEN( a[0] ), a[y], 0, res[y], 0 );  vyLongreal.MulConst( LEN( a[0] ), res[y], 0, b ) END;
		RETURN res;
	END "*";

	OPERATOR "/"*( a: tLONGREALArray;  b: LONGREAL ): tLONGREALArray;
	VAR y, x: LONGINT;  res: tLONGREALArray;
	BEGIN
		IF (a = NIL ) THEN RETURN NIL END;
		NEW( res, LEN( a ), LEN( a[0] ) );
		FOR y := 0 TO LEN( a ) - 1 DO vyLongreal.Copy( LEN( a[0] ), a[y], 0, res[y], 0 );  vyLongreal.DivConst( LEN( a[0] ), res[y], 0, b ) END;
		RETURN res;
	END "/";

	OPERATOR "/"*( a: tLONGREALArray;  b: INTEGER ): tLONGREALArray;
	VAR bb: LONGREAL;
	BEGIN
		bb := b;  RETURN a / bb;
	END "/";

	OPERATOR "*"*( a: tLONGREALArray;  b: INTEGER ): tLONGREALArray;
	VAR bb: LONGREAL;
	BEGIN
		bb := b;  RETURN a * bb;
	END "*";

	OPERATOR "+"*( a: tLONGREALArray;  b: INTEGER ): tLONGREALArray;
	VAR bb: LONGREAL;
	BEGIN
		bb := b;  RETURN a + bb;
	END "+";

	OPERATOR "-"*( a: tLONGREALArray;  b: INTEGER ): tLONGREALArray;
	VAR bb: LONGREAL;
	BEGIN
		bb := b;  RETURN a - bb;
	END "-";

	OPERATOR ":="*( VAR a: tLONGREALArray;  b: LONGREAL );
	VAR y, x: LONGINT;  res: tLONGREALArray;
	BEGIN
		IF (a = NIL ) THEN RETURN END;
		NEW( res, LEN( a ), LEN( a[0] ) );
		FOR y := 0 TO LEN( a ) - 1 DO vyLongreal.Fill( LEN( a[0] ), res[y], 0, b ) END;
	END ":=";

	OPERATOR ":="*( VAR o: tObject;  val: INTEGER );
	BEGIN
		IF o IS tLONGREALObject THEN
			WITH o: tLONGREALObject DO FillLongrealArray( val, o.A, 0, 0, o.w, o.h );
			END;
		ELSIF o IS tLONGINTObject THEN
			WITH o: tLONGINTObject DO FillLongintArray( val, o.A, 0, 0, o.w, o.h );
			END;
		ELSIF o IS tINTEGERObject THEN
			WITH o: tINTEGERObject DO FillIntArray( val, o.A, 0, 0, o.w, o.h )
			END;
		END;
	END ":=";

	OPERATOR ":="*( VAR o: tObject;  val: LONGINT );
	BEGIN
		IF o IS tLONGREALObject THEN
			WITH o: tLONGREALObject DO FillLongrealArray( val, o.A, 0, 0, o.w, o.h );
			END;
		ELSIF o IS tLONGINTObject THEN
			WITH o: tLONGINTObject DO FillLongintArray( val, o.A, 0, 0, o.w, o.h );
			END;
		ELSIF o IS tINTEGERObject THEN
			WITH o: tINTEGERObject DO FillIntArray( SHORT( val ), o.A, 0, 0, o.w, o.h )
			END;
		END;
	END ":=";

	OPERATOR ":="*( VAR o: tObject;  val: LONGREAL );
	BEGIN
		WITH o: tLONGREALObject DO FillLongrealArray( val, o.A, 0, 0, o.w, o.h )
		END;
	END ":=";

	PROCEDURE Init*( o: tObject );
	BEGIN
		o.handle := Handler;  antsObjects.Register( o )
	END Init;

	PROCEDURE GenINTEGERObj*;
	VAR obj: tINTEGERObject;
	BEGIN
		aM.cmd;  NEW( obj );  Init( obj );  obj.depth := MAX( INTEGER );  Objects.NewObj := obj
	END GenINTEGERObj;

	PROCEDURE GenLONGINTObj*;
	VAR obj: tLONGINTObject;
	BEGIN
		aM.cmd;  NEW( obj );  Init( obj );  obj.depth := MAX( LONGINT );  Objects.NewObj := obj
	END GenLONGINTObj;

	PROCEDURE GenLONGREALObj*;
	VAR obj: tLONGREALObject;
	BEGIN
		aM.cmd;  NEW( obj );  Init( obj );  obj.depth := MAX( LONGINT );  Objects.NewObj := obj
	END GenLONGREALObj;

	PROCEDURE Gen*;   (* for consistency with older versions *)
	BEGIN
		GenINTEGERObj
	END Gen;

	PROCEDURE Refresh*( obj: vyBase.Object );
	(*= whenever updated a picture or array in an ViewedArray enviroment use this update procedure with
	obj = changed object, update will be forwarded to any users of obj *)
	VAR msg: vyBase.UpdateMessage;
	BEGIN
		obj.handle( obj, msg )
	END Refresh;

	PROCEDURE SetDepth*( obj: tINTEGERObject;  depth: LONGINT );
	(*= Set depth of an object. While any connected objects become consistent with respect to their depth, you will have to
	call Update(obj) to get a consistent array - picture connection. *)
	VAR olddepth: LONGINT;  y, x: LONGINT;  orig: Objects.Object;
	BEGIN
		ASSERT ( obj # NIL , 100 );
		ASSERT ( depth > 1, 101 );
		WITH obj: tINTEGERObject DO
			IF obj.depth # depth THEN
				olddepth := obj.depth - 1;
				obj.depth := depth;   (*! rescale !! *)
				depth := depth - 1;
				FOR y := 0 TO obj.h - 1 DO
					FOR x := 0 TO obj.w - 1 DO obj.A[y, x] := SHORT( ENTIER( obj.A[y, x] / olddepth * depth + 0.5 ) ) END
				END;
				vyBase.Update( obj )
			END;
			Links.GetLink( obj, "orig", orig );
			IF orig # NIL THEN Attributes.SetInt( orig, "depth", obj.depth ) END

		END
	END SetDepth;

	PROCEDURE StoreINTEGERArray( VAR R: Files.Rider;  A: tINTEGERArray );
	VAR RR: antsReadWrite.Rider;
	BEGIN
		IF A = NIL THEN Files.WriteBool( R, FALSE );  RETURN
		ELSE Files.WriteBool( R, TRUE );  NEW(RR); RR.Enter( R );  RR.SetBin;  RR.WriteI2d( A );  RR.Leave( R )
		END
	END StoreINTEGERArray;

	PROCEDURE LoadINTEGERArray( VAR R: Files.Rider ): tINTEGERArray;
	VAR bool: BOOLEAN;  A: tINTEGERArray;  RR: antsReadWrite.Rider;
	BEGIN
		Files.ReadBool( R, bool );
		IF bool = FALSE THEN RETURN NIL END;
		NEW(RR);
		RR.Enter( R );  RR.SetBin;  RR.ReadI2d( A );  RR.Leave( R );  RETURN A
	END LoadINTEGERArray;

	PROCEDURE StoreLONGINTArray( VAR R: Files.Rider;  A: tLONGINTArray );
	VAR RR: antsReadWrite.Rider;
	BEGIN
		IF A = NIL THEN Files.WriteBool( R, FALSE )
		ELSE Files.WriteBool( R, TRUE );  NEW(RR); RR.Enter( R );  RR.SetBin;  RR.WriteL2d( A );  RR.Leave( R )
		END
	END StoreLONGINTArray;

	PROCEDURE LoadLONGINTArray( VAR R: Files.Rider ): tLONGINTArray;
	VAR bool: BOOLEAN;  A: tLONGINTArray;  RR: antsReadWrite.Rider;
	BEGIN
		Files.ReadBool( R, bool );
		IF bool = FALSE THEN RETURN NIL END;
		NEW(RR);
		RR.Enter( R );  RR.SetBin;  RR.ReadL2d( A );  RR.Leave( R );  RETURN A
	END LoadLONGINTArray;

	PROCEDURE StoreLONGREALArray( VAR R: Files.Rider;  A: tLONGREALArray );
	VAR RR: antsReadWrite.Rider;
	BEGIN
		IF A = NIL THEN Files.WriteBool( R, FALSE )
		ELSE Files.WriteBool( R, TRUE );  NEW(RR); RR.Enter( R );  RR.SetBin;  RR.WriteX2d( A );  RR.Leave( R )
		END
	END StoreLONGREALArray;

	PROCEDURE LoadLONGREALArray( VAR R: Files.Rider ): tLONGREALArray;
	VAR bool: BOOLEAN;  A: tLONGREALArray;  RR: antsReadWrite.Rider;
	BEGIN
		Files.ReadBool( R, bool );
		IF bool = FALSE THEN RETURN NIL END;
		NEW(RR); RR.Enter( R );  RR.SetBin;  RR.ReadX2d( A );  RR.Leave( R );  RETURN A
	END LoadLONGREALArray;

	PROCEDURE IntObj*( A: tINTEGERArray;  depth: LONGINT ): tINTEGERObject;
	VAR AA: tINTEGERObject;  W, H: LONGINT;
	BEGIN
		H := LEN( A );  W := LEN( A[0] );  AA := NewINTEGERObject( W, H, depth );  vyName.RegisterNamed( AA, "genericArrayConv" );  SetInt( AA, A );
		RETURN AA
	END IntObj;

	PROCEDURE IntObjR*( A: tLONGREALArray;  depth: LONGINT ): tINTEGERObject;
	VAR AA: tINTEGERObject;  W, H: LONGINT;
	BEGIN
		H := LEN( A );  W := LEN( A[0] );  AA := NewINTEGERObject( W, H, depth );  vyName.RegisterNamed( AA, "genericArrayConv" );
		SetLongreal( AA, A );  RETURN AA
	END IntObjR;

	PROCEDURE IntObjL*( A: tLONGINTArray;  depth: LONGINT ): tINTEGERObject;
	VAR AA: tINTEGERObject;  W, H: LONGINT;
	BEGIN
		H := LEN( A );  W := LEN( A[0] );  AA := NewINTEGERObject( W, H, depth );  vyName.RegisterNamed( AA, "genericArrayConv" );
		SetLongint( AA, A );  RETURN AA
	END IntObjL;

	PROCEDURE LIntObj*( A: tLONGINTArray;  depth: LONGINT ): tLONGINTObject;
	VAR AA: tLONGINTObject;  W, H: LONGINT;
	BEGIN
		H := LEN( A );  W := LEN( A[0] );  AA := NewLONGINTObject( W, H, depth );  vyName.RegisterNamed( AA, "genericArrayConv" );
		SetLongint( AA, A );  RETURN AA
	END LIntObj;

	PROCEDURE RealObj*( A: tLONGREALArray;  depth: LONGINT ): tLONGREALObject;
	VAR AA: tLONGREALObject;  W, H: LONGINT;
	BEGIN
		H := LEN( A );  W := LEN( A[0] );  AA := NewLONGREALObject( W, H, depth );  vyName.RegisterNamed( AA, "genericArrayConv" );
		SetLongreal( AA, A );  RETURN AA
	END RealObj;

	PROCEDURE EmbedINTEGERArray*( A: tINTEGERArray;  o: tINTEGERObject );
	BEGIN
		o.A := A;  o.h := LEN( A^ );  o.w := LEN( A[0] );  Refresh( o )
	END EmbedINTEGERArray;

	PROCEDURE EmbedLONGINTArray*( A: tLONGINTArray;  o: tLONGINTObject );
	BEGIN
		o.A := A;  o.h := LEN( A^ );  o.w := LEN( A[0] );  Refresh( o )
	END EmbedLONGINTArray;

	PROCEDURE EmbedLONGREALArray*( A: tLONGREALArray;  o: tLONGREALObject );
	BEGIN
		o.A := A;  o.h := LEN( A^ );  o.w := LEN( A[0] );  Refresh( o )
	END EmbedLONGREALArray;

	PROCEDURE NewINTEGERArray*( w, h: LONGINT ): tINTEGERArray;
	VAR a: tINTEGERArray;
	BEGIN
		ASSERT ( w > 0, 100 );
		ASSERT ( h > 0, 101 );
		NEW( a, h, w );  FillIntArray( 0, a, 0, 0, w, h );  RETURN a
	END NewINTEGERArray;

	PROCEDURE NewLONGINTArray*( w, h: LONGINT ): tLONGINTArray;
	VAR a: tLONGINTArray;
	BEGIN
		ASSERT ( w > 0, 100 );
		ASSERT ( h > 0, 101 );
		NEW( a, h, w );  FillLongintArray( 0, a, 0, 0, w, h );  RETURN a
	END NewLONGINTArray;

	PROCEDURE NewLONGREALArray*( w, h: LONGINT ): tLONGREALArray;
	VAR a: tLONGREALArray;
	BEGIN
		ASSERT ( w > 0, 100 );
		ASSERT ( h > 0, 101 );
		NEW( a, h, w );  FillLongrealArray( 0, a, 0, 0, w, h );  RETURN a
	END NewLONGREALArray;

	PROCEDURE NewINTEGERObject*( w, h, d: LONGINT ): tINTEGERObject;
	(*= create a new instance of an array within an array object *)
	VAR a: tINTEGERArray;  A: tINTEGERObject;
	BEGIN
		a := NewINTEGERArray( w, h );  GenINTEGERObj;  A := Objects.NewObj( tINTEGERObject );  Init( A );  A.depth := d;
		EmbedINTEGERArray( a, A );  RETURN A
	END NewINTEGERObject;

	PROCEDURE NewLONGINTObject*( w, h, d: LONGINT ): tLONGINTObject;
	(*= create a new instance of an array within an array object *)
	VAR a: tLONGINTArray;  A: tLONGINTObject;
	BEGIN
		a := NewLONGINTArray( w, h );  GenLONGINTObj;  A := Objects.NewObj( tLONGINTObject );  Init( A );  A.depth := d;
		EmbedLONGINTArray( a, A );  RETURN A
	END NewLONGINTObject;

	PROCEDURE NewLONGREALObject*( w, h: LONGINT;  d: LONGREAL ): tLONGREALObject;
	(*= create a new instance of an array within an array object *)
	VAR a: tLONGREALArray;  A: tLONGREALObject;
	BEGIN
		a := NewLONGREALArray( w, h );  GenLONGREALObj;  A := Objects.NewObj( tLONGREALObject );  Init( A );
		A.depth := d;  EmbedLONGREALArray( a, A );  RETURN A
	END NewLONGREALObject;

	PROCEDURE Min( x, y: LONGINT ): LONGINT;
	BEGIN
		IF x < y THEN RETURN x ELSE RETURN y END
	END Min;

	PROCEDURE ChangeSize*( o: tObject;  w, h: LONGINT );
	VAR oldw, oldh, y: LONGINT;  ia: tINTEGERArray;  lia: tLONGINTArray;  lra: tLONGREALArray;
	BEGIN
		oldw := o.w;  oldh := o.h;
		IF (oldw = w) & (oldh = h) THEN RETURN END;
		IF o IS tINTEGERObject THEN
			WITH o: tINTEGERObject DO
				ia := o.A;
				IF ia # NIL THEN
					o.A := NewINTEGERArray( w, h );
					FOR y := 0 TO Min( oldh, h ) - 1 DO vyInteger.Copy( Min( w, oldw ), ia[y], 0, o.A[y], 0 ) END
				END;
				o.w := w;  o.h := h
			END;
		ELSIF o IS tLONGINTObject THEN
			WITH o: tLONGINTObject DO
				lia := o.A;
				IF lia # NIL THEN
					o.A := NewLONGINTArray( w, h );
					FOR y := 0 TO Min( oldh, h ) - 1 DO vyLongint.Copy( Min( w, oldw ), lia[y], 0, o.A[y], 0 ) END
				END;
				o.w := w;  o.h := h
			END;
		ELSIF o IS tLONGREALObject THEN
			WITH o: tLONGREALObject DO
				lra := o.A;
				IF lra # NIL THEN
					o.A := NewLONGREALArray( w, h );
					FOR y := 0 TO Min( oldh, h ) - 1 DO vyLongreal.Copy( Min( w, oldw ), lra[y], 0, o.A[y], 0 ) END
				END;
				o.w := w;  o.h := h
			END;
		END;
		vyHostTexts.NoteSISI( vyHostTexts.cWarning, "antsArrayObjects Warning: Changed PictSize ", w, " / ", h )
	END ChangeSize;

	PROCEDURE HandleAttributes( o: tObject;  VAR M: Objects.AttrMsg );
	VAR maxd: LONGINT;
	BEGIN
		IF M.id = Objects.enum THEN
			M.Enum( "Gen" );  M.Enum( "w" );  M.Enum( "h" );  M.Enum( "depth" );  M.Enum( "ConsistencyProc" );  M.Enum( "changed" );  M.Enum( "ARRAY" );
			vyBase.objecthandle( o, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "Gen" THEN
				IF o IS tINTEGERObject THEN
					WITH o: tINTEGERObject DO COPY( 'antsArrayObjects.GenINTEGERObj', M.s );  M.class := Objects.String;  M.res := 0
					END;
				ELSIF o IS tLONGINTObject THEN
					WITH o: tLONGINTObject DO COPY( 'antsArrayObjects.GenLONGINTObj', M.s );  M.class := Objects.String;  M.res := 0
					END;
				ELSIF o IS tLONGREALObject THEN
					WITH o: tLONGREALObject DO COPY( 'antsArrayObjects.GenLONGREALObj', M.s );  M.class := Objects.String;  M.res := 0
					END;
				END
			ELSIF M.name = "w" THEN M.class := Objects.Int;  M.i := o.w;  M.res := 0
			ELSIF M.name = "h" THEN M.class := Objects.Int;  M.i := o.h;  M.res := 0
			ELSIF M.name = "depth" THEN
				IF o IS tINTEGERObject THEN
					WITH o: tINTEGERObject DO M.class := Objects.Int;  M.i := o.depth;  M.res := 0
					END;
				ELSIF o IS tLONGINTObject THEN
					WITH o: tLONGINTObject DO M.class := Objects.Int;  M.i := o.depth;  M.res := 0
					END;
				ELSIF o IS tLONGREALObject THEN
					WITH o: tLONGREALObject DO M.class := Objects.LongReal;  M.y := o.depth;  M.res := 0
					END;
				END
			ELSIF M.name = "ARRAY" THEN
				M.class := Objects.String;  M.s := "EXISTS";
				IF o IS tINTEGERObject THEN
					WITH o: tINTEGERObject DO
						IF o.A = NIL THEN M.s := "NIL" END;
					END;
				ELSIF o IS tLONGINTObject THEN
					WITH o: tLONGINTObject DO
						IF o.A = NIL THEN M.s := "NIL" END;
					END;
				ELSIF o IS tLONGREALObject THEN
					WITH o: tLONGREALObject DO
						IF o.A = NIL THEN M.s := "NIL" END
					END;
				END;
				M.res := 0
			ELSE vyBase.objecthandle( o, M )
			END
		ELSIF M.id = Objects.set THEN
			IF M.name = "depth" THEN

				IF o IS tINTEGERObject THEN
					WITH o: tINTEGERObject DO
						IF M.class = Objects.Int THEN
							maxd := 0;  Attributes.GetInt( o, "maxDepth", maxd );
							IF maxd > 0 THEN
								IF M.i > maxd THEN M.i := maxd END
							END;
							IF M.i < 2 THEN M.i := 2 END;
							SetDepth( o, M.i );  M.res := 0
						END
					END;
				ELSE
				END
			ELSIF M.name = "w" THEN
				IF M.class = Objects.Int THEN ChangeSize( o, SHORT( M.i ), SHORT( o.h ) );  vyBase.Update( o );  M.res := 0 END
			ELSIF M.name = "h" THEN
				IF M.class = Objects.Int THEN ChangeSize( o, SHORT( o.w ), SHORT( M.i ) );  vyBase.Update( o );  M.res := 0 END
			ELSE vyBase.objecthandle( o, M )
			END
		ELSE vyBase.objecthandle( o, M )
		END
	END HandleAttributes;

	PROCEDURE FrameLinks( F: tObject;  VAR M: Objects.LinkMsg );
	BEGIN
		IF M.id = Objects.enum THEN vyBase.objecthandle( F, M )
		ELSIF M.id = Objects.get THEN vyBase.objecthandle( F, M )
		ELSE vyBase.objecthandle( F, M )
		END
	END FrameLinks;

	PROCEDURE HandleFileMsg( obj: tObject;  VAR msg: Objects.FileMsg );
	VAR w, h, depth: LONGINT;  version: INTEGER;  rdepth: LONGREAL;
		(*! store Picts as GIF for color preserving or store colors *)
	BEGIN
		IF msg.id = Objects.load THEN
			Files.ReadInt( msg.R, version );  vyBase.objecthandle( obj, msg );  Files.ReadLInt( msg.R, w );
			Files.ReadLInt( msg.R, h );  obj.w := w;  obj.h := h;
			IF obj IS tINTEGERObject THEN
				WITH obj: tINTEGERObject DO
					Files.ReadLInt( msg.R, depth );  obj.A := LoadINTEGERArray( msg.R );  obj.depth := depth;
				END;
			ELSIF obj IS tLONGINTObject THEN
				WITH obj: tLONGINTObject DO
					Files.ReadLInt( msg.R, depth );  obj.A := LoadLONGINTArray( msg.R );  obj.depth := depth;
				END;
			ELSIF obj IS tLONGREALObject THEN
				WITH obj: tLONGREALObject DO
					Files.ReadLReal( msg.R, rdepth );  obj.A := LoadLONGREALArray( msg.R );  obj.depth := rdepth
				END;
			END
		ELSIF msg.id = Objects.store THEN
			Files.WriteInt( msg.R, 0 );  vyBase.objecthandle( obj, msg );  Files.WriteLInt( msg.R, obj.w );
			Files.WriteLInt( msg.R, obj.h );
			IF obj IS tINTEGERObject THEN
				WITH obj: tINTEGERObject DO Files.WriteLInt( msg.R, obj.depth );  StoreINTEGERArray( msg.R, obj.A );
				END;
			ELSIF obj IS tLONGINTObject THEN
				WITH obj: tLONGINTObject DO Files.WriteLInt( msg.R, obj.depth );  StoreLONGINTArray( msg.R, obj.A );
				END;
			ELSIF obj IS tLONGREALObject THEN
				WITH obj: tLONGREALObject DO Files.WriteLReal( msg.R, obj.depth );  StoreLONGREALArray( msg.R, obj.A )
				END;
			END
		ELSE vyBase.objecthandle( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE SetLongreal*( A: tObject;  a: tLONGREALArray );
	BEGIN
		IF A IS tLONGREALObject THEN
			WITH A: tLONGREALObject DO CopyRR( a, A.A, 0, 0, A.w, A.h, 0, 0 );
			END;
		ELSIF A IS tLONGINTObject THEN
			WITH A: tLONGINTObject DO CopyRL( a, A.A, 0, 0, A.w, A.h, 0, 0 );
			END;
		ELSIF A IS tINTEGERObject THEN
			WITH A: tINTEGERObject DO CopyRI( a, A.A, 0, 0, A.w, A.h, 0, 0 )
			END;
		END;
		IF a # NIL THEN A.h := LEN( a );  A.w := LEN( a[0] ) END
	END SetLongreal;

	PROCEDURE SetLongint*( A: tObject;  a: tLONGINTArray );
	BEGIN
		IF A IS tLONGINTObject THEN
			WITH A: tLONGINTObject DO CopyLL( a, A.A, 0, 0, A.w, A.h, 0, 0 );
			END;
		ELSIF A IS tLONGREALObject THEN
			WITH A: tLONGREALObject DO CopyLR( a, A.A, 0, 0, A.w, A.h, 0, 0 );
			END;
		ELSIF A IS tINTEGERObject THEN
			WITH A: tINTEGERObject DO CopyLI( a, A.A, 0, 0, A.w, A.h, 0, 0 )
			END;
		END;
		IF a # NIL THEN A.h := LEN( a );  A.w := LEN( a[0] ) END
	END SetLongint;

	PROCEDURE SetInt*( A: tObject;  a: tINTEGERArray );
	BEGIN
		IF A IS tINTEGERObject THEN
			WITH A: tINTEGERObject DO CopyII( a, A.A, 0, 0, A.w, A.h, 0, 0 );
			END;
		ELSIF A IS tLONGINTObject THEN
			WITH A: tLONGINTObject DO CopyIL( a, A.A, 0, 0, A.w, A.h, 0, 0 );
			END;
		ELSIF A IS tLONGREALObject THEN
			WITH A: tLONGREALObject DO CopyIR( a, A.A, 0, 0, A.w, A.h, 0, 0 )
			END;
		END;
		IF a # NIL THEN A.h := LEN( a );  A.w := LEN( a[0] ) END
	END SetInt;

	PROCEDURE CopyArrayPart( from, to: tObject );
	BEGIN
		IF to IS tINTEGERObject THEN
			WITH to: tINTEGERObject DO
				WITH from: tINTEGERObject DO SetInt( to, from.A );  to.depth := from.depth
				END;
			END;
		ELSIF to IS tLONGINTObject THEN
			WITH to: tLONGINTObject DO
				IF from IS tINTEGERObject THEN
					WITH from: tINTEGERObject DO SetInt( to, from.A );  to.depth := from.depth;
					END;
				ELSIF from IS tLONGINTObject THEN
					WITH from: tLONGINTObject DO SetLongint( to, from.A );  to.depth := from.depth
					END;
				END;
			END;
		ELSIF to IS tLONGREALObject THEN
			WITH to: tLONGREALObject DO
				IF from IS tINTEGERObject THEN
					WITH from: tINTEGERObject DO SetInt( to, from.A );  to.depth := from.depth;

					END;
				ELSIF from IS tLONGINTObject THEN
					WITH from: tLONGINTObject DO SetLongint( to, from.A );  to.depth := from.depth;
					END;
				ELSIF from IS tLONGREALObject THEN
					WITH from: tLONGREALObject DO SetLongreal( to, from.A );  to.depth := from.depth
					END;
				END
			END;
		END;
		Refresh( to )
	END CopyArrayPart;

	PROCEDURE CopyObject*( from, to: tObject );
	VAR M: Objects.CopyMsg;
	BEGIN
		M.id := Objects.deep;  vyBase.CopyObject( M, from, to );  to.handle := from.handle;  to.w := from.w;  to.h := from.h;
		CopyArrayPart( from, to )
	END CopyObject;

	PROCEDURE ObjectCopy( from: tObject ): tObject;
	VAR to: tObject;
	BEGIN
		IF from IS tINTEGERObject THEN
			WITH from: tINTEGERObject DO Gen;  to := Objects.NewObj( tObject );
			END;
		ELSIF from IS tLONGINTObject THEN
			WITH from: tLONGINTObject DO GenLONGINTObj;  to := Objects.NewObj( tObject )
			END;
		END;
		CopyObject( from, to );  RETURN to
	END ObjectCopy;

	PROCEDURE upsidedown;
	VAR temp: INTEGER;  y, x: LONGINT;
	BEGIN
		IF globalobj # NIL THEN
			WITH globalobj: tINTEGERObject DO
				FOR y := 0 TO globalobj.h DIV 2 - 1 DO
					FOR x := 0 TO globalobj.w - 1 DO
						temp := globalobj.A[y, x];  globalobj.A[y, x] := globalobj.A[globalobj.h - 1 - y, x];
						globalobj.A[globalobj.h - 1 - y, x] := temp;
					END;
				END;
				vyBase.Update( globalobj );
			END
		END
	END upsidedown;

	PROCEDURE leftsideright;
	VAR temp: INTEGER;  y, x: LONGINT;
	BEGIN
		IF globalobj # NIL THEN
			WITH globalobj: tINTEGERObject DO
				FOR y := 0 TO globalobj.h - 1 DO
					FOR x := 0 TO globalobj.w DIV 2 - 1 DO
						temp := globalobj.A[y, x];  globalobj.A[y, x] := globalobj.A[y, globalobj.w - 1 - x];
						globalobj.A[y, globalobj.w - 1 - x] := temp;
					END;
				END;
				vyBase.Update( globalobj );
			END
		END
	END leftsideright;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR sel: antsPictCoordinate.Selection;
	BEGIN
		WITH obj: tObject DO
			IF msg IS vyBase.UpdateMessage THEN
				WITH msg: vyBase.UpdateMessage DO
					vyBase.Update( obj );   (* double update ???, no, ok.*)
				END;
			ELSIF msg IS Objects.AttrMsg THEN
				WITH msg: Objects.AttrMsg DO HandleAttributes( obj, msg )
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO HandleFileMsg( obj, msg )
				END;
			ELSIF msg IS Objects.LinkMsg THEN
				WITH msg: Objects.LinkMsg DO FrameLinks( obj, msg )
				END;
			ELSIF msg IS vyCommandMenus.enumMsg THEN
				WITH msg: vyCommandMenus.enumMsg DO
					globalobj := obj;  msg.Enum( "Store Array as 16 Bit pseudo PGM", storepgm, obj );  msg.Enum( "Store Array as PGM (Ascii)", storepgmP2, obj );
					msg.Enum( "upside down", upsidedown, obj );  msg.Enum( "leftside right", leftsideright, obj );
					IF (antsPictCoordinate.currentsel # NIL ) THEN
						sel := antsPictCoordinate.currentsel;
						IF ~vyRectangles.EmptyIntersection( sel.px, sel.py, sel.pw, sel.ph, 0, 0, SHORT( obj.w ), SHORT( obj.h ) ) THEN
							msg.Enum( "Store Selection as PGM", storepgmsel, obj );  msg.Enum( "Cut to Selection (!)", cutsel, obj )
						END
					END;
				END;
			ELSIF msg IS Objects.BindMsg THEN
				WITH msg: Objects.BindMsg DO vyBase.objecthandle( obj, msg );
				END;
			ELSIF msg IS Objects.CopyMsg THEN
				WITH msg: Objects.CopyMsg DO
					IF msg.stamp = obj.stamp THEN msg.obj := obj.dlink
					ELSE obj.stamp := msg.stamp;  obj.dlink := ObjectCopy( obj );  msg.obj := obj.dlink
					END

				END;
			ELSE vyBase.objecthandle( obj, msg )
			END
		END
	END Handler;

	PROCEDURE Copy*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  obj, find: vyBase.Object;  A: tObject;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ (to=OBJ|to=NAME) " );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN
			WITH obj: tObject DO
				IF antsCommands.GetObjectFromKeyword( l, "to", find ) THEN CopyObject( obj, find( tObject ) );  vyBase.Update( find )
				ELSIF antsCommands.ExpectNameFromKeyword( l, "to", name ) THEN
					A := ObjectCopy( obj );  vyName.RegisterNamed( A, name )
				END
			END
		END
	END Copy;

	PROCEDURE New*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  w, h, d: LONGINT;  obj: tObject;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME w=INT h=INT depth=INT" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectNumberFromKeyword( l, "w", w ) &
		    antsCommands.ExpectNumberFromKeyword( l, "h", h ) & antsCommands.ExpectNumberFromKeyword( l, "depth", d ) THEN
			obj := NewINTEGERObject( w, h, d );  vyName.RegisterNamed( obj, name )
		END
	END New;

	PROCEDURE Uniform*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN
			IF obj IS tObject THEN
				WITH obj: tObject DO UniformO( obj );  vyBase.Update( obj )
				END;
			ELSE
			END
		END
	END Uniform;

	PROCEDURE Channel*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;  p: LONGREAL;  y, x: LONGINT;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ p=REAL" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) & antsCommands.ExpectRealFromKeyword( l, "p", p ) THEN
			IF obj IS tINTEGERObject THEN
				WITH obj: tINTEGERObject DO
					IF (ra = NIL ) OR (LEN( ra ) # obj.w) THEN NEW( ra, obj.w ) END;
					FOR y := 0 TO obj.h - 1 DO
						antsArrays.Uniform1dX( ra^, 0, obj.w, 1 );
						(* Uniform1dR(ra^,0,obj.w,1); *)
						FOR x := 0 TO obj.w - 1 DO
							IF ra[x] < p THEN obj.A[y, x] := 1 - obj.A[y, x] END
						END
					END;
					vyBase.Update( obj )
				END;
			ELSE
			END
		END
	END Channel;

	PROCEDURE GetRowCol*( x, y: LONGINT;  o: tObject;  col, row: vyBase.tVector );
	VAR val: LONGINT;  i: LONGINT;
	BEGIN
		WITH o: tINTEGERObject DO
			WITH col: vyLongrealVec.tVector DO
				WITH row: vyLongrealVec.tVector DO
					vyLongrealVec.SetLen( col, 0 );  vyLongrealVec.SetLen( row, 0 );
					FOR i := 0 TO o.w - 1 DO
						val := o.A[y, i];
						IF val < 0 THEN val := 65535 + val END;
						vyLongrealVec.Append( val, row )
					END;
					FOR i := 0 TO o.h - 1 DO
						val := o.A[i, x];
						IF val < 0 THEN val := 65535 + val END;
						vyLongrealVec.Append( val, col )
					END
				END
			END
		END
	END GetRowCol;

	PROCEDURE ReadASCII*( VAR o: tINTEGERObject;  fname: ARRAY OF CHAR );
	VAR Matrix: antsArrays.I2d;  rows, columns, y, x: LONGINT;  R: antsReadWrite.Rider;
	BEGIN
		o := NIL;
		IF ~R.Old( fname ) THEN RETURN END;
		R.ReadType;   (* just if type is binary, unexpectedly *)
		(*R.SetAscii;*)
		R.ReadI2d( Matrix );  o := NewINTEGERObject( 1, 1, 10 );  EmbedINTEGERArray( Matrix, o );
		(*
	FOR y := 0 TO rows - 1 DO
		FOR x := 0 TO columns - 1 DO o.A[y, x] := SHORT( ENTIER( Matrix[y, x] + 0.5 ) )
		END
	END
	*)
	END ReadASCII;

	PROCEDURE ReadPGM*( VAR o: tINTEGERObject;  fname: ARRAY OF CHAR );
	VAR A: tLONGINTArray;  h, w, depth: LONGINT;
	BEGIN
		IF ~antsReadWrite.ReadPGM( A, fname, depth ) OR (A = NIL ) THEN o := NIL;  RETURN END;
		w := LEN( A[0] );  h := LEN( A^ );
		IF o = NIL THEN o := NewINTEGERObject( w, h, depth ) END;
		SetLongint( o, A );  o.depth := depth
	END ReadPGM;

	PROCEDURE StorePGMAscii*( A: tINTEGERObject;  VAR FR: Files.Rider );
	VAR R: antsReadWrite.Rider;  x, y: LONGINT;
	BEGIN
		NEW(R); R.Enter( FR );  R.SetAscii;  R.WriteString( "P2" );  R.Write( antsFiles.LF );  R.Write( antsFiles.CR );  R.WriteString( "# by Oberon" );
		R.Write( antsFiles.LF );  R.Write( antsFiles.CR );  R.WriteLInt( A.w );  R.WriteLInt( A.h );  R.Write( antsFiles.LF );
		R.Write( antsFiles.CR );  R.WriteLInt( A.depth - 1 );  R.Write( antsFiles.LF );  R.Write( antsFiles.CR );
		FOR y := A.h - 1 TO 0 BY -1 DO
			FOR x := 0 TO A.w - 1 DO R.WriteInt( A.A[y, x] );  END;
			R.Write( antsFiles.LF );  R.Write( antsFiles.CR );
		END;
		R.Leave( FR );
	END StorePGMAscii;

	PROCEDURE ReadPGMAscii*( VAR A: tINTEGERObject;  VAR FR: Files.Rider ): BOOLEAN;
	VAR name: ARRAY 64 OF CHAR;
		ch: CHAR;  pos: LONGINT;  w, h, d: LONGINT;  x, y: LONGINT;  R: antsFiles.Rider;  int: INTEGER;  lint: LONGINT;
	BEGIN
		NEW(R); R.Enter( FR );  R.SetAscii;  R.ReadString( name );
		IF (R.err) OR (name # "P2") THEN aM.eSS( "could not load PGM Ascii image, header=", name );  RETURN FALSE ELSE aM.S( "Loading PGM Ascii" );  END;

		REPEAT R.Read( ch );
		UNTIL ~antsFiles.WhiteSpace( ch );

		WHILE (ch = "#") DO
			REPEAT R.Read( ch ) UNTIL (ch = antsFiles.CR) OR (ch = antsFiles.LF);
			REPEAT R.Read( ch );  UNTIL ~antsFiles.WhiteSpace( ch );
		END;
		R.SetPos( R.Pos() - 1 );

		R.ReadLInt( w );   (* dimensions *)
		R.ReadLInt( h );  R.ReadLInt( d );

		IF A = NIL THEN A := NewINTEGERObject( w, h, d + 1 );
		ELSE ChangeSize( A, w, h );  SetDepth( A, d + 1 )
		END;

		FOR y := A.h - 1 TO 0 BY -1 DO
			FOR x := 0 TO A.w - 1 DO R.ReadInt( A.A[y, x] );  END;
		END;

		R.Leave( FR );  RETURN TRUE;
	END ReadPGMAscii;

	PROCEDURE finishstore( VAR f: Files.File;  fname: ARRAY OF CHAR );
	BEGIN
		IF f = NIL THEN aM.eS( "antsArrayObjects..finishtore: NO FILE" );  RETURN ELSE Files.Close( f );  Files.Register( f );  f := NIL END;
		IF ~antsReadWrite.StorePGM( globalLA, fname, globalD ) THEN END
	END finishstore;

	PROCEDURE StoreDialoged*( A: tLONGINTArray;  depth: LONGINT;  name: ARRAY OF CHAR );
	BEGIN
		IF A = NIL THEN RETURN END;
		globalLA := A;  globalD := depth;  antsToolbox.FileStore( finishstore, "PGM Images", "*.PGM", "PGM", name )
	END StoreDialoged;

	PROCEDURE StoreDialogedI*( A: tINTEGERArray;  depth: LONGINT;  name: ARRAY OF CHAR );
	BEGIN
		IF A = NIL THEN RETURN END;
		globalLA := NIL;  CopyUnsignedIL( A, globalLA, 0, 0, LEN( A[0] ), LEN( A ), 0, 0 );  StoreDialoged( globalLA, depth, name )
	END StoreDialogedI;

	PROCEDURE GetSel( VAR x, y, w, h: INTEGER );
	VAR sel: antsPictCoordinate.Selection;
	BEGIN
		sel := antsPictCoordinate.currentsel;  w := SHORT( globalobj.w );  h := SHORT( globalobj.h );  x := 0;  y := 0;
		vyRectangles.RectIntersection( x, y, w, h, sel.px, sel.py, sel.pw, sel.ph )
	END GetSel;

	PROCEDURE storepgmsel;
	VAR name: ARRAY 256 OF CHAR;
		x, y, w, h: INTEGER;  A: tINTEGERArray;
	BEGIN
		IF globalobj # NIL THEN
			IF globalobj IS tINTEGERObject THEN
				WITH globalobj: tINTEGERObject DO
					GetSel( x, y, w, h );
					IF ((w > 0) & (h > 0)) THEN
						CopyII( globalobj.A, A, x, y, w, h, 0, 0 );  vyName.GetObjId( globalobj, name );  vyStrings.Append( name, "Sel.PGM" );
						StoreDialogedI( A, globalobj.depth, name )
					END
				END;
			ELSE
			END
		END
	END storepgmsel;

	PROCEDURE cutsel;
	VAR x, y, w, h: INTEGER;  A: tINTEGERArray;
	BEGIN
		IF globalobj # NIL THEN
			WITH globalobj: tINTEGERObject DO
				GetSel( x, y, w, h );
				IF ((w > 0) & (h > 0)) THEN CopyII( globalobj.A, A, x, y, w, h, 0, 0 );  EmbedINTEGERArray( A, globalobj ) END
			END
		END
	END cutsel;

	PROCEDURE storepgm;
	VAR name: ARRAY 256 OF CHAR;
	BEGIN
		IF globalobj # NIL THEN
			IF globalobj IS tINTEGERObject THEN
				WITH globalobj: tINTEGERObject DO
					vyName.GetObjId( globalobj, name );  vyStrings.Append( name, ".PGM" );
					StoreDialogedI( globalobj.A, globalobj.depth, name )
				END;
			ELSE
			END
		END
	END storepgm;

	PROCEDURE finalizepgmP2( VAR F: Files.File;  name: ARRAY OF CHAR );
	VAR R: Files.Rider;
	BEGIN
		IF F = NIL THEN RETURN END;
		Files.Set( R, F, 0 );
		WITH globalobj: tINTEGERObject DO StorePGMAscii( globalobj, R );  Files.Register( F );  Files.Close( F )
		END;
	END finalizepgmP2;

	PROCEDURE storepgmP2;
	VAR name: ARRAY 256 OF CHAR;
		prefix, suffix: ARRAY 256 OF CHAR;
	BEGIN
		IF globalobj # NIL THEN
			IF globalobj IS tINTEGERObject THEN
				WITH globalobj: tINTEGERObject DO
					COPY( "PGM", suffix );  COPY( "Array", prefix );  antsToolbox.MakefileName( prefix, suffix, name );
					antsToolbox.FileStore( finalizepgmP2, "PGM Images", "*.PGM", "PGM", name )
				END;
			ELSE
			END
		END
	END storepgmP2;

	PROCEDURE finishload*( VAR f: Files.File;  fname: ARRAY OF CHAR );
	VAR obj: tINTEGERObject;  o1: vyBase.Object;
		name: ARRAY 256 OF CHAR;
		registered: BOOLEAN;  objlist: vyLinks.Link;
	BEGIN
		IF f = NIL THEN RETURN END;
		registered := FALSE;
		IF antsCommands.ExpectName( "name", name ) THEN
			IF antsCommands.Find( "replace" ) THEN
				o1 := vyName.FindObj( name );
				IF o1 # NIL THEN obj := o1( tINTEGERObject );  registered := TRUE END
			END;
			ReadPGM( obj, fname );
			IF obj = NIL THEN RETURN END;
			IF ~registered THEN vyName.RegisterNamed( obj, name );  antsObjects.Register( obj ) END;
			loadedobj := obj;  vyBase.Update( obj );
			IF antsCommands.Find( "show" ) THEN  (*! fof, unterstütze Gridsize !!!! *)
				vyLinks.InsertObj( objlist, obj );  vyBase.Show( objlist, 1, "antsPictureViews" )
			END
		ELSE loadedobj := NIL
		END
	END finishload;

	PROCEDURE finishload2*( VAR f: Files.File;  fname: ARRAY OF CHAR );
	VAR obj: tINTEGERObject;  o1: vyBase.Object;
		name: ARRAY 256 OF CHAR;
		registered: BOOLEAN;  objlist: vyLinks.Link;
	BEGIN
		IF f = NIL THEN RETURN END;
		registered := FALSE;
		IF antsCommands.ExpectName( "name", name ) THEN
			IF antsCommands.Find( "replace" ) THEN
				o1 := vyName.FindObj( name );
				IF o1 # NIL THEN obj := o1( tINTEGERObject );  registered := TRUE END
			END;
			ReadASCII( obj, fname );
			IF obj = NIL THEN RETURN END;
			IF ~registered THEN vyName.RegisterNamed( obj, name );  antsObjects.Register( obj ) END;
			loadedobj := obj;  vyBase.Update( obj );
			IF antsCommands.Find( "show" ) THEN  (*! fof, unterstütze Gridsize !!!! *)
				vyLinks.InsertObj( objlist, obj );  vyBase.Show( objlist, 1, "antsPictureViews" )
			END
		ELSE loadedobj := NIL
		END
	END finishload2;

	PROCEDURE finishloadP2*( VAR f: Files.File;  fname: ARRAY OF CHAR );
	VAR obj: tINTEGERObject;  o1: vyBase.Object;
		name: ARRAY 256 OF CHAR;
		registered: BOOLEAN;  objlist: vyLinks.Link;  R: Files.Rider;
	BEGIN
		IF f = NIL THEN RETURN END;
		registered := FALSE;
		IF antsCommands.ExpectName( "name", name ) THEN
			IF antsCommands.Find( "replace" ) THEN
				o1 := vyName.FindObj( name );
				IF o1 # NIL THEN obj := o1( tINTEGERObject );  registered := TRUE END
			END;
			Files.Set( R, f, 0 );
			IF ReadPGMAscii( obj, R ) THEN
				IF obj = NIL THEN RETURN END;
				IF ~registered THEN vyName.RegisterNamed( obj, name );  antsObjects.Register( obj ) END;
				loadedobj := obj;  vyBase.Update( obj );
				IF antsCommands.Find( "show" ) THEN  (*! fof, unterstütze Gridsize !!!! *)
					vyLinks.InsertObj( objlist, obj );  vyBase.Show( objlist, 1, "antsPictureViews" )
				END;
			END;
		ELSE loadedobj := NIL
		END
	END finishloadP2;

	PROCEDURE LoadDialoged*;
	BEGIN
		antsCommands.InitScan( "name=NAME [>replace] [>show] # Load an Array dialoged from file" );  antsToolbox.FileOpen( finishload, "PGM Images", "*.PGM" )
	END LoadDialoged;

	PROCEDURE LoadDialogedP2*;
	BEGIN
		antsCommands.InitScan( "name=NAME [>replace] [>show] # Load an Array dialoged from file" );  antsToolbox.FileOpen( finishloadP2, "PGM Images", "*.PGM" )
	END LoadDialogedP2;

	PROCEDURE LoadP2*;
	VAR filename: ARRAY 256 OF CHAR;
		F: Files.File;
	BEGIN
		antsCommands.InitScan( "file= STR name=NAME [>replace] [>show] # Load an Array  from file" );
		IF antsCommands.ExpectString( "file", filename ) THEN F := Files.Old( filename );  finishloadP2( F, filename ) END
	END LoadP2;

	PROCEDURE Load*;
	VAR filename: ARRAY 256 OF CHAR;
		F: Files.File;
	BEGIN
		antsCommands.InitScan( "file= STR name=NAME [>replace] [>show] # Load an Array  from file" );
		IF antsCommands.ExpectString( "file", filename ) THEN F := Files.Old( filename );  finishload( F, filename ) END
	END Load;

	PROCEDURE LoadASCII*;
	VAR filename: ARRAY 256 OF CHAR;
		F: Files.File;
	BEGIN
		antsCommands.InitScan( "file= STR name=NAME [>replace] [>show] # Load an Array  from ASCII file" );
		IF antsCommands.ExpectString( "file", filename ) THEN F := Files.Old( filename );  finishload2( F, filename ) END
	END LoadASCII;

	PROCEDURE LoadDialogedASCII*;
	BEGIN
		antsCommands.InitScan( "name=NAME [>replace] [>show] ~# Load an Array  dialoged from ASCIIfile" );  antsToolbox.FileOpen( finishload2, "ASCII Images", "*.*" )
	END LoadDialogedASCII;

(* Interaktive Routine zum Anzeigen der Zeilen und Spalten eines 2d-Bildes *)
	PROCEDURE InteractiveGetRowCol*( row, col: vyBase.tVector;  r, c: vyBase.Object );
	VAR msg: antsToolbox.GetCoordMsg;  x, y: LONGINT;  o: tObject;  xm, ym: INTEGER;  keys: SET;  layer: Objects.Object;
		coords: ARRAY 64 OF CHAR;
	BEGIN
		x := MAX( LONGINT );  y := MAX( LONGINT );  msg.layer := NIL;  msg.update := TRUE;  antsToolbox.InteractiveMsg( msg );  layer := msg.layer;
		Input.Mouse( keys, xm, ym );  msg.x := MAX( INTEGER );  msg.y := MAX( INTEGER );
		WHILE (keys # {}) DO
			IF (msg.x # xm) OR (msg.y # ym) THEN
				msg.x := xm;  msg.y := ym;  msg.update := FALSE;  msg.layer := NIL;  antsToolbox.MsgToTypedXY( xm, ym, msg, "antsViews.tLayerDesc" );
				IF msg.layer # layer THEN msg.update := TRUE;  antsToolbox.MsgToTypedXY( xm, ym, msg, "antsViews.tLayerDesc" );  layer := msg.layer END;

				IF (msg.a # NIL ) & (msg.a IS tObject) THEN
					x := ENTIER( msg.xr );  y := ENTIER( msg.yr );  o := msg.a( tObject );
					IF (0 <= x) & (0 <= y) & (x < o.w) & (y < o.h) & (row # NIL ) & (col # NIL ) THEN
						GetRowCol( x, y, o, col, row );  vyBase.Update( row );  vyBase.Update( col );
						IF r # NIL THEN r( vyLongrealVec.tLONGREAL ).x := y;  vyBase.Update( r ) END;
						IF c # NIL THEN c( vyLongrealVec.tLONGREAL ).x := x;  vyBase.Update( c ) END
					END;
					coords := "coords: x= ";  vyStrings.AppendInt( x, 0, coords );  vyStrings.Append( coords, "; y= " );  vyStrings.AppendInt( y, 0, coords )
				ELSE coords := "move mouse on image layer"
				END;

				vyTracking.HelpEnd();  vyTracking.HelpAt( xm, ym + 20, coords )
			END;
			Input.Mouse( keys, xm, ym )
		END;
		vyTracking.HelpEnd();
		IF y # MAX( LONGINT ) THEN aM.SISI( "Row = ", y, "Col = ", x ) ELSE aM.S( "Hmm? Nothing selected." ) END
	END InteractiveGetRowCol;

	PROCEDURE RowCol*;
	(* Command to copy interactively chosen row and column into vectors row, col, write row number / column number into r,c (vyLongrealVec.tLONGREAL)
	if not NIL *)
	VAR row, col: vyBase.Object;  r, c: vyBase.Object;
	BEGIN
		antsCommands.InitScan( "row=OBJ col=OBJ [r=OBJ c=OBJ] # get row / col vector interactively." );
		IF antsCommands.ExpectObject( "row", row ) & antsCommands.ExpectObject( "col", col ) THEN
			IF antsCommands.GetObject( "r", r ) & antsCommands.GetObject( "c", c ) THEN ELSE r := NIL;  c := NIL END;
			InteractiveGetRowCol( row( vyBase.tVector ), col( vyBase.tVector ), r, c );  vyBase.Update( row );
			vyBase.Update( col )
		END
	END RowCol;

BEGIN
	aM.launch;
END antsArrayObjects.
System.Recall

antsArrayObjects.Test ~

System.DeleteFiles antsArrayObjects.Obj ~

fofAutomatic.Do
antsArrayObjects.LoadDialoged mamo ~
antsArrayPictures16.New mamobild > from mamo ~
Voyager.Show mamobild as antsPictureViews ~
~

System.Free antsArrayObjects ~

System.Free antsViews antsDiscreteFields antsPictArray ~
ants / antsViews.Mod
antsPictArray.Test Array ~

fofAutomatic.Do
antsArrayObjects.New testarray 100 100 10 ~
antsArrayImages.New testimg testarray ~
Voyager.Show testimg as antsImageViews ~
antsArrayPictures.New testpict testarray ~
Voyager.Show testpict as antsPictureViews ~
antsArrayObjects.Uniform testarray ~
antsObjects.WriteAttributes testarray
~~~~
antsDiscreteIsingS.NewModel > name Model  > h 0.0 > beta 0.3 ~
antsGibbs.DefineGibbsSampler > name Sampler > presteps 0 > steps 100~
antsGibbs.AttachModel > sampler Sampler > model Model ~
antsGibbs.AttachArray > sampler Sampler > array testarray ~
System.Time
antsGibbs.Step > sampler Sampler > times 1 ~
System.Time
~
Voyager.Show testarray as antsArrayViews ~

ants / antsPictureViews.Mod

antsViews.Show testimg  > texture~
antsArrayImages.LoadImg > name bartimg > fname "bart.pict"~
antsArrayPictures.LoadPict > name bartpict > fname "bart.pict"~
antsViews.Show bartimg ~
antsViews.Show bartpict~
antsArrayImages.ToArray > name bartarray > from bartimg > depth 10~
antsArrayPictures.ToArray > name bartarray > from bartpict > depth 10~
