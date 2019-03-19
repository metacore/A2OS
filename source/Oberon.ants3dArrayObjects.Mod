MODULE ants3dArrayObjects IN Oberon;   (*  fof   **)
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



(*** 3 dim Arrays wrapped in a Voyager object *)
IMPORT vyBase, vyInteger, Objects, antsCommands, vyRanBase, MathL IN A2, Gadgets, Files, vyName, vyHostTexts, antsObjects,
	antsArrayObjects, antsArrays, aM := antsMessages;

CONST

TYPE

	(** Common object type *)
	tArray* = antsArrays.I3d;   (*= common type for 2d-Fields *)

	tObject* = POINTER TO tObjectDesc;
	tObjectDesc* = RECORD (vyBase.ObjDesc);
		w*, h*, d*, depth*: LONGINT;
		A*: tArray;
		ACache*: tArray;
		F: antsArrayObjects.tINTEGERObject;
		Fd: LONGINT
	END;

CONST
	defaultdepth = 2;

VAR
	newobject-: tObject;

	PROCEDURE UniformO*( o: tObject );
	VAR gen: vyRanBase.tRandom;
	BEGIN
		gen := vyRanBase.RandomGenerator;
		IF o # NIL THEN
			antsArrays.Uniform3dI( o.A, SHORT( o.depth ) )
			(*
		FOR l := 0 TO o.d-1 DO
		FOR j := 0 TO o.h-1 DO
		FOR i := 0 TO o.w-1 DO
		o.A[l,j,i] := SHORT(gen.GetRandomL(gen,o.depth));
		END;
		END;
		END;
		*)
		END
	END UniformO;

	PROCEDURE ExampleO*( o: tObject );
	VAR l, j, i: LONGINT;  rx, ry, rz, rxx, ryy: LONGREAL;
	BEGIN
		IF o # NIL THEN
			FOR l := 0 TO o.d - 1 DO
				FOR j := 0 TO o.h - 1 DO
					FOR i := 0 TO o.w - 1 DO
						rz := l / o.d;  ry := -1 + j / o.h * 2;  rx := -1 + i / o.w * 2;  rxx := 3 / 4 * (MathL.sin( rz * 2 * MathL.pi ));
						ryy := 3 / 4 * (MathL.cos( rz * 2 * MathL.pi ));
						IF ((rx - rxx) * (rx - rxx) + (ry - ryy) * (ry - ryy)) < 0.16 THEN o.A[l, j, i] := 1;  ELSE o.A[l, j, i] := 0 END;
					END;
				END;
			END;
		END;
	END ExampleO;

	PROCEDURE ExampleOBlock*( o: tObject );
	VAR l, j, i: LONGINT;  rx, ry, rz: LONGREAL;
	BEGIN
		IF o # NIL THEN
			FOR l := 0 TO o.d - 1 DO
				FOR j := 0 TO o.h - 1 DO
					FOR i := 0 TO o.w - 1 DO
						rz := -1 + l / o.d * 2;  ry := -1 + j / o.h * 2;  rx := -1 + i / o.w * 2;
						IF (ABS( rx ) < 0.7) & (ABS( ry ) < 0.7) & (ABS( rz ) < 0.7) THEN o.A[l, j, i] := 1;  ELSE o.A[l, j, i] := 0 END;
					END;
				END;
			END;
		END;
	END ExampleOBlock;

	PROCEDURE ExampleOColumn*( o: tObject );
	VAR l, j, i: LONGINT;  rx, ry, rz: LONGREAL;
	BEGIN
		IF o # NIL THEN
			FOR l := 0 TO o.d - 1 DO
				FOR j := 0 TO o.h - 1 DO
					FOR i := 0 TO o.w - 1 DO
						rz := -1 + l / o.d * 2;  ry := -1 + j / o.h * 2;  rx := -1 + i / o.w * 2;
						IF ABS( ry * ry + rx * rx ) < 0.2 THEN o.A[l, j, i] := 1;  ELSE o.A[l, j, i] := 0 END;
					END;
				END;
			END;
		END;
	END ExampleOColumn;

	PROCEDURE ExampleOBall*( o: tObject );
	VAR l, j, i: LONGINT;  rx, ry, rz: LONGREAL;
	BEGIN
		IF o # NIL THEN
			FOR l := 0 TO o.d - 1 DO
				FOR j := 0 TO o.h - 1 DO
					FOR i := 0 TO o.w - 1 DO
						rz := -1 + l / o.d * 2;  ry := -1 + j / o.h * 2;  rx := -1 + i / o.w * 2;
						IF ABS( ry * ry + rz * rz + rx * rx ) < 0.4 THEN o.A[l, j, i] := 1;  ELSE o.A[l, j, i] := 0 END;
					END;
				END;
			END;
		END;
	END ExampleOBall;

	PROCEDURE Init*( o: tObject );
	BEGIN
		o.handle := Handler;  o.depth := defaultdepth
	END Init;

	PROCEDURE Gen*;
	BEGIN
		NEW( newobject );  Init( newobject );  Objects.NewObj := newobject;  antsObjects.Register( newobject )
	END Gen;

	PROCEDURE Refresh*( obj: vyBase.Object );
	(*= whenever updated a picture or array in an ViewedArray enviroment use this update procedure with
	obj = changed object, update will be forwarded to any users of obj *)
	VAR msg: vyBase.UpdateMessage;
	BEGIN
		obj.handle( obj, msg )
	END Refresh;

	PROCEDURE SetDepth*( obj: tObject;  depth: LONGINT );
	(*= Set depth of an object. While any connected objects become consistent with respect to their depth, you will have to
	call Update(obj) to get a consistent array - picture connection. *)
	VAR olddepth: LONGINT;  y, x, l: LONGINT;
	BEGIN
		ASSERT ( obj # NIL , 100 );
		ASSERT ( depth > 1, 101 );
		WITH obj: tObject DO
			IF obj.depth # depth THEN
				olddepth := obj.depth - 1;
				obj.depth := depth;   (*! rescale !! *)
				depth := depth - 1;
				FOR l := 0 TO obj.d - 1 DO
					FOR y := 0 TO obj.h - 1 DO
						FOR x := 0 TO obj.w - 1 DO obj.A[l, y, x] := SHORT( ENTIER( obj.A[l, y, x] / olddepth * depth + 0.5 ) );  END;
					END;
				END;
				vyBase.Update( obj );
			END;
		END
	END SetDepth;

	PROCEDURE EmbedArray*( A: tArray;  o: tObject );
	BEGIN
		o.A := A;  o.d := LEN( A^ );  o.h := LEN( A[0] );  o.w := LEN( A[0][0] );
		IF o.F # NIL THEN antsArrayObjects.EmbedINTEGERArray( o.A[o.Fd], o.F );  END;
		Refresh( o )
	END EmbedArray;

	PROCEDURE NewArray*( w, h, d: LONGINT ): tArray;
	VAR a: tArray;  i: LONGINT;
	BEGIN
		ASSERT ( w > 0, 100 );
		ASSERT ( h > 0, 101 );
		NEW( a, d );
		FOR i := 0 TO d - 1 DO NEW( a[i], h, w );  END;
		RETURN a
	END NewArray;

	PROCEDURE NewObject*( w, h, d, depth: LONGINT ): tObject;
	(*= create a new instance of an array within an array object *)
	VAR a: tArray;  A: tObject;
	BEGIN
		a := NewArray( w, h, d );  Gen;  A := newobject;  Init( A );  A.depth := depth;  EmbedArray( a, A );  RETURN A
	END NewObject;

	PROCEDURE Min( x, y: INTEGER ): INTEGER;
	BEGIN
		IF x < y THEN RETURN x ELSE RETURN y END
	END Min;

	PROCEDURE ChangeSize( o: tObject;  w, h, d: INTEGER );
	VAR oldarray: tArray;  oldw, oldh, oldd, y, l: INTEGER;
	BEGIN
		oldw := SHORT( o.w );  oldh := SHORT( o.h );  oldd := SHORT( o.d );
		IF (w # o.w) OR (h # o.h) OR (d # o.d) THEN  (* ? preserve pict / array when shrinked ? *)
			oldarray := o.A;

			IF oldarray # NIL THEN
				o.A := NewArray( w, h, d );
				FOR l := 0 TO Min( oldd, d ) - 1 DO
					FOR y := 0 TO Min( oldh, h ) - 1 DO vyInteger.Copy( Min( w, oldw ), oldarray[l, y], 0, o.A[l, y], 0 ) END
				END;
			END;
			o.w := w;  o.h := h;  o.d := d;
		END;
		vyHostTexts.NoteSISI( vyHostTexts.cWarning, "antsArrayObjects Warning: Changed PictSize ", w, " / ", h )
	END ChangeSize;

	PROCEDURE HandleAttributes( o: tObject;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.enum THEN
			M.Enum( "Gen" );  M.Enum( "w" );  M.Enum( "h" );  M.Enum( "d" );  M.Enum( "depth" );  M.Enum( "ConsistencyProc" );  M.Enum( "changed" );  M.Enum( "ViewD" );  M.Enum( "ARRAY" );
			vyBase.objecthandle( o, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'ants3dArrayObjects.Gen', M.s );  M.class := Objects.String;  M.res := 0
			ELSIF M.name = "w" THEN M.class := Objects.Int;  M.i := o.w;  M.res := 0
			ELSIF M.name = "h" THEN M.class := Objects.Int;  M.i := o.h;  M.res := 0
			ELSIF M.name = "d" THEN M.class := Objects.Int;  M.i := o.d;  M.res := 0
			ELSIF M.name = "depth" THEN M.class := Objects.Int;  M.i := o.depth;  M.res := 0
			ELSIF M.name = "ViewD" THEN M.class := Objects.Int;  M.i := o.Fd;  M.res := 0;
			ELSIF M.name = "ARRAY" THEN
				M.class := Objects.String;
				IF o.A = NIL THEN M.s := "NIL" ELSE M.s := "EXISTS" END;
				M.res := 0
			ELSE vyBase.objecthandle( o, M )
			END
		ELSIF M.id = Objects.set THEN
			IF M.name = "depth" THEN
				IF M.class = Objects.Int THEN SetDepth( o, M.i );  M.res := 0 END
			ELSIF M.name = "w" THEN
				IF M.class = Objects.Int THEN ChangeSize( o, SHORT( M.i ), SHORT( o.h ), SHORT( o.d ) );  vyBase.Update( o );  M.res := 0 END
			ELSIF M.name = "h" THEN
				IF M.class = Objects.Int THEN ChangeSize( o, SHORT( o.w ), SHORT( M.i ), SHORT( o.d ) );  vyBase.Update( o );  M.res := 0 END
			ELSIF M.name = "d" THEN
				IF M.class = Objects.Int THEN ChangeSize( o, SHORT( o.w ), SHORT( o.h ), SHORT( M.i ) );  vyBase.Update( o );  M.res := 0 END
			ELSIF M.name = "ViewD" THEN
				IF M.class = Objects.Int THEN
					o.Fd := Min( SHORT( M.i ), SHORT( o.d - 1 ) );
					IF o.F # NIL THEN antsArrayObjects.EmbedINTEGERArray( o.A[o.Fd], o.F );  vyBase.Update( o.F );  END;
				END;
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

	PROCEDURE StoreA( VAR R: Files.Rider;  A: tArray );
	VAR i, j, l: LONGINT;
	BEGIN
		IF A = NIL THEN Files.WriteBool( R, FALSE )
		ELSE
			Files.WriteBool( R, TRUE );  Files.WriteLInt( R, LEN( A^ ) );  Files.WriteLInt( R, LEN( A[0] ) );  Files.WriteLInt( R, LEN( A[0][0] ) );
			FOR l := 0 TO LEN( A^ ) - 1 DO
				FOR i := 0 TO LEN( A[0] ) - 1 DO
					FOR j := 0 TO LEN( A[0, 0] ) - 1 DO Files.WriteInt( R, A[l][i][j] ) END
				END
			END;
		END
	END StoreA;

	PROCEDURE LoadA( VAR R: Files.Rider ): tArray;
	VAR bool: BOOLEAN;  i, j, l: LONGINT;  maxi, maxj, maxl: LONGINT;  A: tArray;
	BEGIN
		Files.ReadBool( R, bool );
		IF bool = FALSE THEN RETURN NIL END;
		Files.ReadLInt( R, maxl );  Files.ReadLInt( R, maxi );  Files.ReadLInt( R, maxj );  A := NewArray( maxj, maxi, maxl );
		FOR l := 0 TO maxl - 1 DO
			FOR i := 0 TO maxi - 1 DO
			(*NEW(A[i], maxj);*)
				FOR j := 0 TO maxj - 1 DO Files.ReadInt( R, A[l][i][j] ) END
			END;
		END;
		RETURN A
	END LoadA;

	PROCEDURE HandleFileMsg( obj: tObject;  VAR msg: Objects.FileMsg );
	VAR w, h, d, depth: LONGINT;  version: INTEGER;  objsub: Objects.Object;
		(*! store Picts as GIF for color preserving or store colors *)
	BEGIN
		IF msg.id = Objects.load THEN
			Files.ReadInt( msg.R, version );  vyBase.objecthandle( obj, msg );  Files.ReadLInt( msg.R, w );
			Files.ReadLInt( msg.R, h );  Files.ReadLInt( msg.R, d );  Files.ReadLInt( msg.R, depth );  obj.A := LoadA( msg.R );
			obj.w := w;  obj.h := h;  obj.depth := depth;  obj.d := d;  Files.ReadLInt( msg.R, obj.Fd );
			Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF objsub # NIL THEN
				obj.F := objsub( antsArrayObjects.tINTEGERObject );
				antsArrayObjects.EmbedINTEGERArray( obj.A[obj.Fd], obj.F );
			END;
		ELSIF msg.id = Objects.store THEN
			Files.WriteInt( msg.R, 0 );  vyBase.objecthandle( obj, msg );  Files.WriteLInt( msg.R, obj.w );
			Files.WriteLInt( msg.R, obj.h );  Files.WriteLInt( msg.R, obj.d );  Files.WriteLInt( msg.R, obj.depth );
			StoreA( msg.R, obj.A );  Files.WriteLInt( msg.R, obj.Fd );  Gadgets.WriteRef( msg.R, obj.lib, obj.F );
		ELSE vyBase.objecthandle( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE CopyArray*( a: tArray;  VAR A: tArray;  sx, sy, sz, w, h, zl, dx, dy, dz: LONGINT );
	VAR y, x, z, x0, y0, z0: LONGINT;
	BEGIN
		IF a = NIL THEN A := NIL;  RETURN END;
		IF (A = NIL ) OR (LEN( A ) < dz + zl) OR (LEN( A[0] ) < dy + h) OR (LEN( A[0][0] ) < dx + w) THEN
			A := NewArray( dy + h, dx + w, dz + zl )
		END;
		FOR z := 0 TO zl - 1 DO
			FOR y := 0 TO h - 1 DO
				FOR x := 0 TO w - 1 DO
					z0 := dz + z;  y0 := dy + y;  x0 := dx + x;   (* windows: not enough registers: simplify expression *)
					A[z0, y0, x0] := a[sz + z, sy + y, sx + x];
				END
			END
		END;

	END CopyArray;

	PROCEDURE CopyArrayPart*( from, to: tObject );
	VAR i, l: LONGINT;
	BEGIN
		IF (from.A = NIL ) THEN RETURN END;
		IF to.A = NIL THEN to.A := NewArray( from.w, from.h, from.d ) END;
		ASSERT ( from.h = to.h, 100 );
		ASSERT ( from.w = to.w );
		ASSERT ( from.d = to.d );
		FOR l := 0 TO from.d - 1 DO
			FOR i := 0 TO from.h - 1 DO vyInteger.Copy( from.w, from.A[l, i], 0, to.A[l, i], 0 ) END;
		END;
		Refresh( to )
	END CopyArrayPart;

	PROCEDURE CopyObject*( from, to: tObject );
	VAR M: Objects.CopyMsg;
	BEGIN
		M.id := Objects.deep;  vyBase.CopyObject( M, from, to );  to.handle := from.handle;  to.w := from.w;  to.h := from.h;
		to.depth := from.depth;  to.d := from.d;  to.A := NIL;  CopyArrayPart( from, to );
	END CopyObject;

	PROCEDURE ObjectCopy( from: tObject ): tObject;
	VAR to: tObject;
	BEGIN
		Gen;  to := newobject;  CopyObject( from, to );  RETURN to
	END ObjectCopy;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR
	BEGIN
		WITH obj: tObject DO
			IF msg IS vyBase.UpdateMessage THEN
				WITH msg: vyBase.UpdateMessage DO
					vyBase.Update( obj );
					IF obj.F # NIL THEN vyBase.Update( obj.F ) END;   (* double update ???, no, ok.*)
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
			ELSIF msg IS Objects.BindMsg THEN
				WITH msg: Objects.BindMsg DO
				(*
			IF obj.bindcount < 4 THEN
			*)
					IF obj.lib # msg.lib THEN vyBase.objecthandle( obj, msg );  antsObjects.Bind( obj.F, msg );  END;
				END;
			ELSIF msg IS Objects.CopyMsg THEN
				WITH msg: Objects.CopyMsg DO
					IF msg.stamp = obj.stamp THEN msg.obj := obj.dlink
					ELSE obj.stamp := msg.stamp;  obj.dlink := ObjectCopy( obj );  msg.obj := obj.dlink;
					END

				END;
			ELSE vyBase.objecthandle( obj, msg )
			END
		END
	END Handler;

	PROCEDURE Copy*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  obj, find: vyBase.Object;  A: tObject;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ [to=OBJ|to=name] # Copy <name> to existing or new <to>" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN
			WITH obj: tObject DO
				IF antsCommands.GetObjectFromKeyword( l, "to", find ) THEN
					CopyObject( obj, find( tObject ) );
					IF (find( tObject ).F) # NIL THEN
						antsArrayObjects.EmbedINTEGERArray( find( tObject ).A[find( tObject ).Fd], find( tObject ).F );
					END;
					vyBase.Update( find );
				ELSE
					IF antsCommands.GetNameFromKeyword( l, "to", name ) THEN
						A := ObjectCopy( obj );  vyName.RegisterNamed( A, name )
					END;
				END;
			END;
		END
	END Copy;

	PROCEDURE New*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  w, h, d, depth: LONGINT;  obj: tObject;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME w=INT h=INT d=INT depth=INT # create new 3d Object <name>" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectNumberFromKeyword( l, "w", w ) &
		    antsCommands.ExpectNumberFromKeyword( l, "h", h ) & antsCommands.ExpectNumberFromKeyword( l, "d", d ) &
		    antsCommands.ExpectNumberFromKeyword( l, "depth", depth ) THEN
			obj := NewObject( w, h, d, depth );  vyName.RegisterNamed( obj, name );
		END;
	END New;

	PROCEDURE Uniform*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ # noise data <name> from uniform distribution on the greyvalues" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN
			IF obj IS tObject THEN
				WITH obj: tObject DO UniformO( obj );  vyBase.Update( obj );
				END;
			ELSE
			END;
		END;
	END Uniform;

	PROCEDURE Channel*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;  p: LONGREAL;  y, x, ll: LONGINT;
		ra: POINTER TO ARRAY OF LONGREAL;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ p=REAL # noise <name> with channel nois, prob = <p>" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) & antsCommands.ExpectRealFromKeyword( l, "p", p ) THEN
			IF obj IS tObject THEN
				WITH obj: tObject DO
					NEW( ra, obj.w );
					FOR ll := 0 TO obj.d - 1 DO
						FOR y := 0 TO obj.h - 1 DO
							antsArrays.Uniform1dX( ra^, 0, obj.w, 1 );
							FOR x := 0 TO obj.w - 1 DO
								IF ra[x] < p THEN obj.A[ll, y, x] := 1 - obj.A[ll, y, x];  END;
							END;
						END;
					END;
					vyBase.Update( obj );
				END;
			ELSE
			END;
		END;
	END Channel;

	PROCEDURE Example*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;
		name: ARRAY 128 OF CHAR;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ [example=NAME] # Make example data example = helix|block|ball|column" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN
			IF obj IS tObject THEN
				WITH obj: tObject DO
					IF antsCommands.GetNameFromKeyword( l, "example", name ) THEN
						IF name = "helix" THEN ExampleO( obj );
						ELSIF name = "block" THEN ExampleOBlock( obj )
						ELSIF name = "ball" THEN ExampleOBall( obj )
						ELSIF name = "column" THEN ExampleOColumn( obj )
						END;
						vyBase.Update( obj );
					ELSE ExampleO( obj );  vyBase.Update( obj );
					END;
				END;
			ELSE
			END;
		END;
	END Example;

	PROCEDURE Attach*;
	VAR l: antsCommands.tScanList;  obj, obj2: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "name= OBJ Array=OBJ # Attach 2-dim object <Array> to 3-dim object <name>" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) & antsCommands.ExpectObjectFromKeyword( l, "Array", obj2 ) THEN
			WITH obj: tObject DO
				obj.F := obj2( antsArrayObjects.tINTEGERObject );  obj.Fd := 0;
				antsArrayObjects.EmbedINTEGERArray( obj.A[0], obj.F );  vyBase.Subscribe( obj, obj.F );  vyBase.Update( obj.F );
			END;
		END;
	END Attach;

	PROCEDURE Next*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "name= OBJ # Take next slide of 3-dim data for 2-dim data <name>" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN
			WITH obj: tObject DO
				INC( obj.Fd );  obj.Fd := obj.Fd MOD obj.d;  antsArrayObjects.EmbedINTEGERArray( obj.A[obj.Fd], obj.F );
				vyBase.Update( obj.F );  Gadgets.Update( obj );
			END;
		END;

	END Next;

BEGIN
	aM.launch;
END ants3dArrayObjects.

fofAutomatic.Do
ants3dArrayObjects.New testarray 40 40 80 2 ~
ants3dArrayViews.Show testarray ~
ants3dArrayObjects.Example testarray ~
~
System.Free ants3dArrayViews antsKernel ants3dBinaryIsingS2 ants3dArrayObjects ~
~
ants3dArrayObjects.Channel testarray 0.01 ~

fofAutomatic.Do
ants3dArrayObjects.New testarray 20 20 80   2 ~
ants3dArrayViews.Show testarray ~
ants3dArrayObjects.Example testarray ~
ants3dArrayObjects.Channel testarray 0.3 ~
ants3dBinaryIsingS2.NewModel > name Model  > h 0.0 > beta 0.50 > penalty 0.3 ~
antsKernel.Define > name Sampler ~
antsKernel.AttachModel > sampler Sampler > model Model ~
antsKernel.AttachArray > sampler Sampler > array testarray ~
antsMC.New chain ~
antsMC.Add chain Sampler ~
~
fofAutomatic.Do > interactive
antsMC.Forward chain 10 1 ~
~
antsMC.Init chain ~
ants / antsKernel.Mod


antsArrayObjects.New film 20 20 2~
ants3dArrayObjects.Attach testarray film ~
antsArrayPictures.New testpict film ~
antsViews.Show testpict ~
fofAutomatic.Do > interactive
ants3dArrayObjects.Next testarray ~
~
fofAutomatic.Do
ants3dArrayObjects.New testarray 20 20 80   2 ~
ants3dArrayViews.Show testarray ~
ants3dArrayObjects.Example testarray ~
~


Test3d.Panel