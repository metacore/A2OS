MODULE antsArrayStatistics IN Oberon;   (** fof  **)
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




IMPORT vyBase, antsObjects, antsArrayObjects, Objects, Files, Gadgets, antsCommands, vyName, vyLongrealVec,
	aM := antsMessages, antsRegions;

TYPE
	tObject* = POINTER TO tObjectDesc;
	tObjectDesc* = RECORD (vyBase.ObjDesc)
		from*: antsArrayObjects.tINTEGERObject;
		coocurrence*: antsArrayObjects.tINTEGERObject;
		histogram*: vyBase.tVector
	END;

	PROCEDURE Sync( o: tObject );
	VAR x, y, x0, y0, w0, h0, x1, y1, w1, h1, fy, fx: LONGINT;  from, to: antsArrayObjects.tINTEGERArray;  max: LONGINT;  ival: LONGINT;
	BEGIN
		x0 := 0;  y0 := 0;  w0 := o.from.w;  h0 := o.from.h;  from := o.from.A;  max := 2;

		antsArrayObjects.ChangeSize( o.coocurrence, o.from.depth, o.from.depth );  x1 := 0;  y1 := 0;  w1 := o.coocurrence.w;
		h1 := o.coocurrence.h;  to := o.coocurrence.A;

		(* vyLongrealVec.SetLen(o.histogram,o.from.depth); *)

		vyLongrealVec.SetLen( o.histogram, 0 );
		FOR y := y1 TO y1 + h1 - 1 DO
			FOR x := x1 TO x1 + w1 - 1 DO to[y, x] := 0 END
		END;

		FOR y := y0 TO y0 + h0 - 1 DO
			FOR x := x0 TO x0 + w0 - 1 DO
				fy := from[y, x];  fx := from[y, (x + 1) MOD o.from.w];  ival := to[fy, fx];
				IF ival < 0 THEN INC( ival, 65536 ) END;
				INC( ival );
				IF ival > max THEN max := ival END;
				to[fy, fx] := SHORT( ival );  vyLongrealVec.Append( from[y, x], o.histogram )
				(*
			vyLongrealVec.Set(vyLongrealVec.Get(o.histogram,fy)+1,o.histogram,fy);
			*)
			END
		END;

		aM.SI( "Max Value found: ", max );  o.coocurrence.depth := max + 1

	END Sync;

	PROCEDURE HandleAttributes( o: tObject;  VAR M: Objects.AttrMsg );
	BEGIN
		vyBase.objecthandle( o, M )
	END HandleAttributes;

	PROCEDURE HandleLinks( F: tObject;  VAR M: Objects.LinkMsg );
	BEGIN
		IF M.id = Objects.enum THEN vyBase.objecthandle( F, M )
		ELSIF M.id = Objects.get THEN vyBase.objecthandle( F, M )
		ELSE vyBase.objecthandle( F, M )
		END
	END HandleLinks;

	PROCEDURE HandleBind( obj: tObject;  VAR msg: Objects.BindMsg );
	BEGIN
		IF msg.lib # obj.lib THEN vyBase.objecthandle( obj, msg );  antsObjects.Bind( obj, msg );  antsObjects.Bind( obj, msg ) END
	END HandleBind;

	PROCEDURE Store( VAR R: Files.Rider;  s: tObject );
	BEGIN
		Files.WriteInt( R, 0 );  Gadgets.WriteRef( R, s.lib, s.from );  Gadgets.WriteRef( R, s.lib, s.coocurrence );
		Gadgets.WriteRef( R, s.lib, s.histogram )
	END Store;

	PROCEDURE Load( VAR R: Files.Rider;  s: tObject );
	VAR objsub: Objects.Object;  version: INTEGER;
	BEGIN
		Files.ReadInt( R, version );  Gadgets.ReadRef( R, s.lib, objsub );
		IF objsub # NIL THEN s.from := objsub( antsArrayObjects.tINTEGERObject ) END;
		Gadgets.ReadRef( R, s.lib, objsub );
		IF objsub # NIL THEN s.coocurrence := objsub( antsArrayObjects.tINTEGERObject ) END;
		Gadgets.ReadRef( R, s.lib, objsub );
		IF objsub # NIL THEN s.histogram := objsub( vyBase.tVector ) END
	END Load;

	PROCEDURE HandleFileMsg( o: tObject;  VAR msg: Objects.FileMsg );
	BEGIN
		vyBase.objecthandle( o, msg );
		IF msg.id = Objects.load THEN Load( msg.R, o )
		ELSIF msg.id = Objects.store THEN Store( msg.R, o )
		END
	END HandleFileMsg;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	BEGIN
		WITH obj: tObject DO
			IF msg IS vyBase.UpdateMessage THEN
				WITH msg: vyBase.UpdateMessage DO vyBase.Update( obj );
				END;
			ELSIF msg IS Objects.AttrMsg THEN
				WITH msg: Objects.AttrMsg DO HandleAttributes( obj, msg )
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO HandleFileMsg( obj, msg )
				END;
			ELSIF msg IS Objects.LinkMsg THEN
				WITH msg: Objects.LinkMsg DO HandleLinks( obj, msg )
				END;
			ELSIF msg IS Objects.BindMsg THEN
				WITH msg: Objects.BindMsg DO HandleBind( obj, msg )
				END;
			ELSE vyBase.objecthandle( obj, msg )
			END
		END
	END Handler;

	PROCEDURE Gen*;
	VAR s: tObject;
	BEGIN
		NEW( s );  s.handle := Handler;  Objects.NewObj := s
	END Gen;

	PROCEDURE New*;
	VAR obj: vyBase.Object;  s: tObject;
		name: ARRAY 256 OF CHAR;
	BEGIN
		antsCommands.InitScan( "name=NAME from=OBJ" );
		IF antsCommands.ExpectName( "name", name ) & antsCommands.ExpectObject( "from", obj ) THEN
			WITH obj: antsArrayObjects.tINTEGERObject DO
				Gen;  s := Objects.NewObj( tObject );  s.from := obj;  vyName.RegisterNamed( s, name );
				vyBase.Subscribe( s, obj );  s.coocurrence := antsArrayObjects.NewINTEGERObject( 2, 2, 2 );
				vyName.RegisterNamed( s.coocurrence, "Coocurrence" );  s.histogram := vyLongrealVec.New( 1 );
				vyName.RegisterNamed( s.histogram, "Histogram" );  Sync( s );  aM.SS( "Created new static Statistic: ", name )
			END
		END
	END New;

	PROCEDURE NewFromRegion*;
	VAR A: antsArrayObjects.tINTEGERObject;  region: antsRegions.tRegion;  s: tObject;
		name: ARRAY 256 OF CHAR;
		x, y, w, h: LONGINT;
	BEGIN
		antsCommands.InitScan( "name=NAME" );
		IF antsCommands.ExpectName( "name", name ) THEN
			antsRegions.Gen;  region := Objects.NewObj( antsRegions.tRegion );  antsRegions.DoSelectRegion( region );
			IF ~region.valid THEN RETURN END;
			A := antsRegions.A;

			IF A # NIL THEN
				antsRegions.Get( region, A, x, y, w, h );  Gen;  s := Objects.NewObj( tObject );
				s.from := antsArrayObjects.NewINTEGERObject( w, h, A.depth );
				antsArrayObjects.CopyII( A.A, s.from.A, x, y, w, h, 0, 0 );  vyName.RegisterNamed( s, name );
				vyBase.Subscribe( s, s.from );  s.coocurrence := antsArrayObjects.NewINTEGERObject( 2, 2, 2 );
				vyName.RegisterNamed( s.coocurrence, "Coocurrence" );  s.histogram := vyLongrealVec.New( 1 );
				vyName.RegisterNamed( s.histogram, "Histogram" );  Sync( s );  aM.SS( "Created new static Statistic: ", name )

			END
		END

	END NewFromRegion;

BEGIN
	aM.launch;
END antsArrayStatistics.

antsArrayStatistics.New stat myArray  ~
antsArrayPictures16.New CoocurencePict Coocurrence ~
Voyager.Show CoocurencePict as antsPictureViews ~

Voyager.Show Coocurrence as antsPictureViews ~
antsArrayStatistics.New stat  f5Array  ~

vySurface.SetRendering    smoothLighting ~
ants3D.MakeMatrixFromArray > from Coocurrence > name Matrix > x 0 > y 0 > w 32 > h 32
ants3D.ScaleMatrix Matrix 0.5 ~


Coocurence 3d Plot

fofAutomatic.Do
antsArrayStatistics.NewFromRegion test ~
ants3D.MakeMatrixFromArray > from Coocurrence > name Matrix ~
Voyager.Show Matrix as Surface ~
~

Greyscale Histogram

fofAutomatic.Do
antsArrayStatistics.NewFromRegion test ~
Voyager.Show Histogram as Histogram ~
vyHistogram.SetOffsetWidth 0.5 1
vyScale.Insert
~
Coocurence  2d Plot

fofAutomatic.Do
antsArrayStatistics.NewFromRegion test ~
antsArrayPictures16.New CoocurencePict Coocurrence ~
Voyager.Show CoocurencePict as antsPictureViews ~
antsViews.fix
~



Voyager.Show Matrix as Surface ~
Voyager.Show Histogram as Histogram ~


vyScale.Insert


vyScale.Insert

System.Free vySurface vyPolyWorld  vyPHIGS3D  ~

