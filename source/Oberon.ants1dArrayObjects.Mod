MODULE ants1dArrayObjects IN Oberon;   (*  fof   **)
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




(*** 1 dim Arrays wrapped in a Voyager object *)
IMPORT vyBase, vyInteger, Objects, antsCommands, vyRanBase, vyRandom, Files, vyName, vyHostTexts, antsObjects, SYSTEM,
	vyLongrealVec, antsArrays, aM := antsMessages;

CONST

TYPE
	tRArray* = antsArrays.X1d;  tLArray* = antsArrays.L1d;

	(** Common object type *)
	tArray* = antsArrays.I1d;   (*= common type for 1d-Fields *)

	tObject* = POINTER TO tObjectDesc;
	tObjectDesc* = RECORD (vyBase.ObjDesc);
		w*, depth*: SIGNED32;
		A*: tArray;
		ACache*: tArray
	END;

CONST
	defaultdepth = 2;

VAR
	newobject-: tObject;  RandomR-: tRArray;  RandomL-: tLArray;

	PROCEDURE RandomRC( w: SIGNED32 );
	BEGIN
		IF (RandomR = NIL ) OR (LEN( RandomR^ ) < w) THEN NEW( RandomR, w );  aM.dS( "New RandomR" );  END
	END RandomRC;

	PROCEDURE RandomLC( w: SIGNED32 );
	BEGIN
		IF (RandomL = NIL ) OR (LEN( RandomL^ ) < w) THEN NEW( RandomL, w );  aM.dS( "New RandomR" );  END
	END RandomLC;

	PROCEDURE UniformR*( w: SIGNED32 );
	VAR gen: vyRanBase.tRandom;
	BEGIN
		RandomRC( w );  gen := vyRanBase.RandomGenerator;  gen.GetRandomUVX( gen, w, RandomR^, 0 )
	END UniformR;

	PROCEDURE UniformL*( w, top: SIGNED32 );
	VAR gen: vyRanBase.tRandom;
	BEGIN
		RandomLC( w );  gen := vyRanBase.RandomGenerator;  gen.GetRandomLV( gen, top, w, RandomL^, 0 )
	END UniformL;

	PROCEDURE UniformA*( A: tArray;  top: SIGNED32;  x, w: SIGNED32 );
	VAR adri, adrl, adrw: SIGNED32;  val: SIGNED32;
	CONST stepi = SIZEOF( SIGNED16 );  stepl = SIZEOF( SIGNED32 );
	BEGIN
		UniformL( w, top );  adri := ADDRESSOF( A[x] );  adrl := ADDRESSOF( RandomL[0] );  adrw := adri + w * stepi;
		WHILE (adri < adrw) DO SYSTEM.GET( adrl, val );  SYSTEM.PUT( adri, SHORT( val ) );  INC( adri, stepi );  INC( adrl, stepl ) END
	END UniformA;

	PROCEDURE UniformO*( o: tObject );
	BEGIN
		IF o # NIL THEN UniformA( o.A, o.depth, 0, o.w ) END
	END UniformO;

	PROCEDURE FillA*( A: tArray;  val: SIGNED16;  x, w: SIGNED32 );
	VAR adr, adrw: SIGNED32;
	CONST step = SIZEOF( SIGNED16 );
	BEGIN
		adr := ADDRESSOF( A[x] );  adrw := adr + w * step;
		WHILE (adr < adrw) DO SYSTEM.PUT( adr, val );  INC( adr, step ) END
	END FillA;

	PROCEDURE FillO*( o: tObject;  val: SIGNED16 );
	BEGIN
		FillA( o.A, val, 0, o.w )
	END FillO;

	PROCEDURE Init*( o: tObject );
	BEGIN
		o.handle := Handler;  o.depth := defaultdepth
	END Init;

	PROCEDURE Gen*;
	BEGIN
		aM.dS( "ants1dArrayObjects.Gen" );  NEW( newobject );  Init( newobject );  Objects.NewObj := newobject;  antsObjects.Register( newobject )
	END Gen;

	PROCEDURE Refresh*( obj: vyBase.Object );
	(*= whenever updated a picture or array in an ViewedArray enviroment use this update procedure with
	obj = changed object, update will be forwarded to any users of obj *)
	VAR msg: vyBase.UpdateMessage;
	BEGIN
		obj.handle( obj, msg )
	END Refresh;

	PROCEDURE SetDepth*( obj: tObject;  depth: SIGNED32 );
	(*= Set depth of an object. While any connected objects become consistent with respect to their depth, you will have to
	call Update(obj) to get a consistent array - picture connection. *)
	VAR olddepth: SIGNED32;  x: SIGNED32;
	BEGIN
		ASSERT ( obj # NIL , 100 );
		ASSERT ( depth > 1, 101 );
		WITH obj: tObject DO
			IF obj.depth # depth THEN
				olddepth := obj.depth - 1;
				obj.depth := depth;   (*! rescale !! *)
				depth := depth - 1;
				FOR x := 0 TO obj.w - 1 DO obj.A[x] := SHORT( ENTIER( obj.A[x] / olddepth * depth + 0.5 ) ) END;
				vyBase.Update( obj )
			END
		END
	END SetDepth;

	PROCEDURE EmbedArray*( A: tArray;  o: tObject );
	BEGIN
		o.A := A;  o.w := LEN( A^ );  Refresh( o )
	END EmbedArray;

	PROCEDURE NewArray*( w: SIGNED32 ): tArray;
	VAR a: tArray;
	BEGIN
		ASSERT ( w > 0, 100 );
		NEW( a, w );  FillA( a, 0, 0, w );  RETURN a
	END NewArray;

	PROCEDURE NewObject*( w, d: SIGNED32 ): tObject;
	(*= create a new instance of an array within an array object *)
	VAR a: tArray;  A: tObject;
	BEGIN
		a := NewArray( w );  Gen;  A := newobject;  Init( A );  A.depth := d;  EmbedArray( a, A );  RETURN A
	END NewObject;

	PROCEDURE Min( x, y: SIGNED32 ): SIGNED32;
	BEGIN
		IF x < y THEN RETURN x ELSE RETURN y END
	END Min;

	PROCEDURE ChangeSize( o: tObject;  w: SIGNED32 );
	VAR oldarray: tArray;  oldw: SIGNED16;
	BEGIN
		oldw := SHORT( o.w );
		IF (w # o.w) THEN  (* ? preserve pict / array when shrinked ? *)
			oldarray := o.A;
			IF oldarray # NIL THEN o.A := NewArray( w );  vyInteger.Copy( Min( SHORT( w ), oldw ), oldarray^, 0, o.A^, 0 ) END;
			o.w := w
		END;
		vyHostTexts.NoteSI( vyHostTexts.cWarning, "ants1dArrayObjects Warning: Changed PictSize ", w )
	END ChangeSize;

	PROCEDURE HandleAttributes( o: tObject;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.enum THEN
			M.Enum( "Gen" );  M.Enum( "w" );  M.Enum( "h" );  M.Enum( "depth" );  M.Enum( "ConsistencyProc" );  M.Enum( "changed" );  M.Enum( "ARRAY" );
			vyBase.objecthandle( o, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'ants1dArrayObjects.Gen', M.s );  M.class := Objects.String;  M.res := 0
			ELSIF M.name = "w" THEN M.class := Objects.Int;  M.i := o.w;  M.res := 0
			ELSIF M.name = "depth" THEN M.class := Objects.Int;  M.i := o.depth;  M.res := 0
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
				IF M.class = Objects.Int THEN ChangeSize( o, SHORT( M.i ) );  vyBase.Update( o );  M.res := 0 END
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
	VAR i: SIGNED32;
	BEGIN
		IF A = NIL THEN Files.WriteBool( R, FALSE )
		ELSE
			Files.WriteBool( R, TRUE );  Files.WriteLInt( R, LEN( A^ ) );
			FOR i := 0 TO LEN( A^ ) - 1 DO Files.WriteInt( R, A[i] ) END
		END
	END StoreA;

	PROCEDURE LoadA( VAR R: Files.Rider ): tArray;
	VAR bool: BOOLEAN;  i: SIGNED32;  maxi: SIGNED32;  A: tArray;
	BEGIN
		Files.ReadBool( R, bool );
		IF bool = FALSE THEN RETURN NIL END;
		Files.ReadLInt( R, maxi );  NEW( A, maxi );
		FOR i := 0 TO maxi - 1 DO Files.ReadInt( R, A[i] ) END;
		RETURN A
	END LoadA;

	PROCEDURE HandleFileMsg( obj: tObject;  VAR msg: Objects.FileMsg );
	VAR w, depth: SIGNED32;  version: SIGNED16;
		(*! store Picts as GIF for color preserving or store colors *)
	BEGIN
		IF msg.id = Objects.load THEN
			Files.ReadInt( msg.R, version );  vyBase.objecthandle( obj, msg );  Files.ReadLInt( msg.R, w );
			Files.ReadLInt( msg.R, depth );  obj.A := LoadA( msg.R );  obj.w := w;  obj.depth := depth
		ELSIF msg.id = Objects.store THEN
			Files.WriteInt( msg.R, 0 );  vyBase.objecthandle( obj, msg );  Files.WriteLInt( msg.R, obj.w );
			Files.WriteLInt( msg.R, obj.depth );  StoreA( msg.R, obj.A )
		ELSE vyBase.objecthandle( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE CopyArrayPart( from, to: tObject );
	BEGIN
		IF (from.A = NIL ) THEN RETURN END;
		IF to.A = NIL THEN to.A := NewArray( from.w ) END;
		ASSERT ( from.w = to.w );
		vyInteger.Copy( from.w, from.A^, 0, to.A^, 0 );  Refresh( to )
	END CopyArrayPart;

	PROCEDURE CopyObject*( from, to: tObject );
	VAR M: Objects.CopyMsg;
	BEGIN
		M.id := Objects.deep;  vyBase.CopyObject( M, from, to );  to.handle := from.handle;  to.w := from.w;
		to.depth := from.depth;  to.A := NIL;  CopyArrayPart( from, to )
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
		l := antsCommands.ScanFromPar( "name=OBJ to=(NAME|OBJECT) ~# copy 1dData <name> to <to>" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) & antsCommands.ExpectNameFromKeyword( l, "to", name ) THEN
			WITH obj: tObject DO
				find := vyName.FindObj( name );
				IF find = NIL THEN A := ObjectCopy( obj );  vyName.RegisterNamed( A, name )
				ELSE CopyObject( obj, find( tObject ) );  vyBase.Update( find )
				END
			END
		END
	END Copy;

	PROCEDURE New*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  w, d: SIGNED32;  obj: tObject;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME w=INT depth=INT ~# create new instance of <name> with len <w>" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectNumberFromKeyword( l, "w", w ) &
		    antsCommands.ExpectNumberFromKeyword( l, "depth", d ) THEN
			obj := NewObject( w, d );  vyName.RegisterNamed( obj, name )
		END
	END New;

	PROCEDURE FromVec*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  depth, i: SIGNED32;  obj: tObject;  aobj, bobj: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME from=OBJ [depth=INT] # copy vec to new object  <name>" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectObjectFromKeyword( l, "from", bobj ) THEN
			IF ~antsCommands.GetNumberFromKeyword( l, "depth", depth ) THEN depth := MAX( SIGNED16 ) END;
			WITH bobj: vyLongrealVec.tVector DO
				aobj := vyName.FindObj( name );
				IF aobj = NIL THEN obj := NewObject( vyLongrealVec.Len( bobj ), depth );  vyName.RegisterNamed( obj, name )
				ELSE
					obj := aobj( tObject );
					IF obj( tObject ).w # vyLongrealVec.Len( bobj ) THEN ChangeSize( obj( tObject ), vyLongrealVec.Len( bobj ) ) END;
					IF depth # MAX( SIGNED16 ) THEN SetDepth( obj( tObject ), depth ) END
				END;
				FOR i := 0 TO vyLongrealVec.Len( bobj ) - 1 DO obj( tObject ).A[i] := SHORT( ENTIER( vyLongrealVec.Get( bobj, i ) + 0.5 ) ) END;
				vyBase.Update( obj )
			END
		END
	END FromVec;

	PROCEDURE Uniform*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ ~# noise <name> with uniform distribution on its integers" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN
			IF obj IS tObject THEN
				WITH obj: tObject DO UniformO( obj );  vyBase.Update( obj )
				END;
			ELSE
			END
		END
	END Uniform;

	PROCEDURE Channel*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;  p: FLOAT64;  x: SIGNED32;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ p=FLOAT32 ~# Add channel noise to data <name> with prob. p " );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) & antsCommands.ExpectRealFromKeyword( l, "p", p ) THEN
			IF obj IS tObject THEN
				WITH obj: tObject DO
					UniformR( obj.w );
					FOR x := 0 TO obj.w - 1 DO
						IF RandomR[x] < p THEN obj.A[x] := 1 - obj.A[x] END
					END;
					vyBase.Update( obj )
				END;
			ELSE
			END
		END
	END Channel;

	PROCEDURE AddNoise*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;  p: FLOAT64;  x: SIGNED32;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJECT p=FLOAT32 # Add (rounded) gaussian noise with var. <p> to data <name>" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) & antsCommands.ExpectRealFromKeyword( l, "p", p ) THEN
			IF obj IS tObject THEN
				WITH obj: tObject DO
					FOR x := 0 TO obj.w - 1 DO
						obj.A[x] := SHORT( ENTIER( obj.A[x] + vyRandom.Gauss( 0, p ) ) );
						IF obj.A[x] < 0 THEN obj.A[x] := 0
						ELSIF obj.A[x] >= obj.depth THEN obj.A[x] := SHORT( obj.depth - 1 )
						END
					END;
					vyBase.Update( obj )
				END;
			ELSE
			END
		END
	END AddNoise;

BEGIN
	aM.launch;
END ants1dArrayObjects.

fofAutomatic.Do
antsFunctions.Define  myfunction ~
antsFctVector.NewVec myvec 255 ~
antsFctVector.New trans myfunction myvec~
antsFctEdit.Show myfunction 0 1 0.01~
Voyager.Show myvec as antsPointPlot~
ants1dArrayObjects.FromVec array myvec ~
ants1dArrayVectors.New arrayview array ~
Voyager.Show  arrayviewVec as antsPointPlot ~
Voyager.Show myfunction as antsObjectView ~


