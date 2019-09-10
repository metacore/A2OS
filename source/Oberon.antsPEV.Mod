MODULE antsPEV IN Oberon;   (** fof  **)
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



 (*= This module provides the translation procedures for binary 2d fields to be used in antsPictArray -  any element of the field may take on values -1 or 1  -, a uniform random iid sampling procedure ("salt and pepper") using vyRandom.Uniform and two procedures for easier acces to new pictures / arrays based on the translation proposed here. *)

IMPORT antsArrayObjects, vyBase, Objects, Gadgets, Files, vyHostStrings, antsViews, vyName, antsCommands, aM := antsMessages;

TYPE

	tField* = POINTER TO tFieldDesc;
	tFieldDesc* = RECORD (vyBase.ObjDesc);
		A*: antsArrayObjects.tINTEGERObject;   (* Array *)
		Aorig*: antsArrayObjects.tINTEGERObject;
		Eh*, Ev*: antsArrayObjects.tINTEGERObject;   (* edges hor and ver *)
		V*: antsArrayObjects.tINTEGERObject;   (* vertices *)
		w*, h*: SIGNED32
	END;

	tArray* = antsArrayObjects.tObject;

	Operation* = PROCEDURE ( F: tField;  y, x: SIGNED32 );

	(*
	Coords: * Pixel, |- Edge,+ Vertice


	(*
	0    0    1     1	2     2

	2  	+    -    +     -
	1  	|    *	 |	 *
	1  	+    -	+	 -
	0  	|    *	 | 	*
	0	  +    -    +     -
	*)



	Pixel-Edge-Pixel-Nachbarschaften:

	*  p4

	-  e4

	* p1	|e1		*		| e2	*	p2

	-  e3

	* p3

	Edge-Pixel-Vertice-Nachbarschaften:

	+ v2

	* p1		|		* p2

	+ v1


	* p2

	+ v1		-		+ v2

	* p1

	Vertice-Edge-Nachbarschaften:

	| e4

	- e1		+		- e2

	| e3

	Edge-Edge Neighbourhood

	| e4	-e8	| e6
	-e1		-		-e2
	| e3	-e7	| e5



	| e2
	- e5				- e6
	| e7		|		-|e8
	- e3				- e4
	| e1
	*)
	PROCEDURE DoUniform*( F: tField );
	BEGIN
		antsArrayObjects.UniformO( F.A );  antsArrayObjects.UniformO( F.Eh );  antsArrayObjects.UniformO( F.Ev );
		antsArrayObjects.UniformO( F.V )
	END DoUniform;

	PROCEDURE EGetENeighboursV*( F: tField;  y, x: SIGNED32;  VAR e, p1, p2: SIGNED16 );
	BEGIN
		(*
	(*
	0    0    1     1	2     2

	2  	+    -    +     -
	1  	|    *	 |	 *
	1  	+    -	+	 -
	0  	|    *	 | 	*
	0	  +    -    +     -
	*)
	*)


		e := F.Ev.A[y, x];  p1 := F.A.A[y, x];  p2 := F.A.A[y, (x - 1) MOD F.w]
	END EGetENeighboursV;

	PROCEDURE EGetENeighboursH*( F: tField;  y, x: SIGNED32;  VAR e, p1, p2: SIGNED16 );
	BEGIN
		e := F.Eh.A[y, x];  p1 := F.A.A[y, x];  p2 := F.A.A[(y - 1) MOD F.h, x]
	END EGetENeighboursH;

	PROCEDURE EGetPNeighbours*( F: tField;  y, x: SIGNED32;  VAR p, p1, p2, p3, p4, e1, e2, e3, e4: SIGNED16 );
	VAR w, h: SIGNED32;
		(*
	0    0    1     1	2     2
	2  	+    -    +     -
	1  	|    *	 |	 *
	1  	+    -	+	 -
	0  	|    *	 | 	*
	0	  +    -    +     -
	*)
	BEGIN
		w := F.w;  h := F.h;  p := F.A.A[y, x];  p1 := F.A.A[y, (x - 1) MOD w];  p2 := F.A.A[y, (x + 1) MOD w];
		p3 := F.A.A[(y - 1) MOD h, x];  p4 := F.A.A[(y + 1) MOD h, x];  e1 := F.Ev.A[y, x];  e2 := F.Ev.A[y, (x + 1) MOD w];
		e3 := F.Eh.A[y, x];  e4 := F.Eh.A[(y + 1) MOD h, x]
	END EGetPNeighbours;

	PROCEDURE ESetPNeighbours*( F: tField;  y, x: SIGNED32;  p, p1, p2, p3, p4, e1, e2, e3, e4: SIGNED16 );
	VAR w, h: SIGNED32;
	BEGIN
		w := F.w;  h := F.h;  F.A.A[y, x] := p;  F.A.A[y, (x - 1) MOD w] := p1;  F.A.A[y, (x + 1) MOD w] := p2;
		F.A.A[(y - 1) MOD h, x] := p3;  F.A.A[(y + 1) MOD h, x] := p4;  F.Ev.A[y, x] := e1;  F.Ev.A[y, (x + 1) MOD w] := e2;
		F.Eh.A[y, x] := e3;  F.Eh.A[(y + 1) MOD h, x] := e4
	END ESetPNeighbours;

	PROCEDURE EEdgeBetween*( F: tField;  y, x, y2, x2: SIGNED32 ): BOOLEAN;
	BEGIN
		IF y > y2 THEN RETURN F.Ev.A[y, x] = 1
		ELSIF y < y2 THEN RETURN F.Ev.A[(y + 1) MOD F.h, x] = 1
		ELSE
			IF x > x2 THEN RETURN F.Eh.A[y, x] = 1
			ELSIF x < x2 THEN RETURN F.Eh.A[y, (x + 1) MOD F.w] = 1
			ELSE
			END
		END
	END EEdgeBetween;

	PROCEDURE EVGetENeighboursH*( F: tField;  y, x: SIGNED32;  VAR e, p1, p2, v1, v2: SIGNED16 );
	BEGIN
		EGetENeighboursH( F, y, x, e, p1, p2 );  v1 := F.V.A[y, x];  v2 := F.V.A[y, (x + 1) MOD F.w]
	END EVGetENeighboursH;

	PROCEDURE EVGetENeighboursV*( F: tField;  y, x: SIGNED32;  VAR e, p1, p2, v1, v2: SIGNED16 );
	BEGIN
		EGetENeighboursH( F, y, x, e, p1, p2 );  v1 := F.V.A[y, x];  v2 := F.V.A[(y + 1) MOD F.h, x]
	END EVGetENeighboursV;

	PROCEDURE EVGetVNeighbours*( F: tField;  y, x: SIGNED32;  VAR v, e1, e2, e3, e4: SIGNED16 );
	BEGIN
		v := F.V.A[y, x];  e1 := F.Eh.A[y, (x - 1) MOD F.w];  e2 := F.Eh.A[y, x];  e3 := F.Ev.A[(y - 1) MOD F.h, x];  e4 := F.Ev.A[y, x]
	END EVGetVNeighbours;

	PROCEDURE E2GetENeighboursH*( F: tField;  y, x: SIGNED32;  VAR e, e1, e2, e3, e4, e5, e6, e7, e8: SIGNED16 );
	VAR w, h: SIGNED32;
	BEGIN
		w := F.w;  h := F.h;  e := F.Eh.A[y, x];  e1 := F.Eh.A[y, (x - 1) MOD w];  e2 := F.Eh.A[y, (x + 1) MOD w];
		e3 := F.Ev.A[(y - 1) MOD h, x];  e4 := F.Ev.A[y, x];  e5 := F.Ev.A[(y - 1) MOD h, (x + 1) MOD w];
		e6 := F.Ev.A[y, (x + 1) MOD w];  e7 := F.Eh.A[(y - 1) MOD h, x];  e8 := F.Eh.A[(y + 1) MOD h, x]
	END E2GetENeighboursH;

	PROCEDURE E2GetENeighboursV*( F: tField;  y, x: SIGNED32;  VAR e, e1, e2, e3, e4, e5, e6, e7, e8: SIGNED16 );
	VAR w, h: SIGNED32;
	BEGIN
		w := F.w;  h := F.h;  e := F.Ev.A[y, x];  e1 := F.Ev.A[(y - 1) MOD h, x];  e2 := F.Ev.A[(y + 1) MOD h, x];
		e3 := F.Eh.A[y, (x - 1) MOD w];  e4 := F.Eh.A[y, x];  e5 := F.Eh.A[(y + 1) MOD h, (x - 1) MOD w];
		e6 := F.Eh.A[(y + 1) MOD h, x];  e7 := F.Ev.A[y, (x - 1) MOD w];  e8 := F.Ev.A[y, (x + 1) MOD w]
	END E2GetENeighboursV;

	PROCEDURE ForAllDo*( F: tField;  O: Operation );
	VAR x, y: SIGNED32;
	BEGIN
		FOR y := 0 TO F.h - 1 DO
			FOR x := 0 TO F.w - 1 DO O( F, y, x ) END
		END
	END ForAllDo;

	PROCEDURE Gen*;
	VAR f: tField;
	BEGIN
		aM.cmd;  NEW( f );  f.handle := Handler;  f.w := 0;  f.h := 0;  Objects.NewObj := f
	END Gen;

	PROCEDURE HandleFileMsg( obj: tField;  VAR msg: Objects.FileMsg );
	VAR objsub: Objects.Object;  version: SIGNED16;

	BEGIN
		IF msg.id = Objects.load THEN
			Files.ReadInt( msg.R, version );  vyBase.objecthandle( obj, msg );  Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF objsub # NIL THEN obj.A := objsub( antsArrayObjects.tINTEGERObject ) END;
			Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF objsub # NIL THEN obj.Ev := objsub( antsArrayObjects.tINTEGERObject ) END;
			Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF objsub # NIL THEN obj.Eh := objsub( antsArrayObjects.tINTEGERObject ) END;
			Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF objsub # NIL THEN obj.V := objsub( antsArrayObjects.tINTEGERObject ) END;
			Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF objsub # NIL THEN obj.Aorig := objsub( antsArrayObjects.tINTEGERObject ) END;
			Files.ReadLInt( msg.R, obj.w );  Files.ReadLInt( msg.R, obj.h )
		ELSIF msg.id = Objects.store THEN
			Files.WriteInt( msg.R, 0 );  vyBase.objecthandle( obj, msg );  Gadgets.WriteRef( msg.R, obj.lib, obj.A );
			Gadgets.WriteRef( msg.R, obj.lib, obj.Ev );  Gadgets.WriteRef( msg.R, obj.lib, obj.Eh );
			Gadgets.WriteRef( msg.R, obj.lib, obj.V );  Gadgets.WriteRef( msg.R, obj.lib, obj.Aorig );
			Files.WriteLInt( msg.R, obj.w );  Files.WriteLInt( msg.R, obj.h )
		ELSE vyBase.objecthandle( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE HandleAttributes( obj: tField;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.enum THEN M.Enum( "Gen" );  M.Enum( "w" );  M.Enum( "h" );  vyBase.objecthandle( obj, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'antsPEV.Gen', M.s );  M.class := Objects.String;  M.res := 0
			ELSIF M.name = "w" THEN M.i := obj.w;  M.class := Objects.Int;  M.res := 0
			ELSIF M.name = "h" THEN M.i := obj.h;  M.class := Objects.Int;  M.res := 0
			ELSE vyBase.objecthandle( obj, M )
			END
		ELSIF M.id = Objects.set THEN vyBase.objecthandle( obj, M )
		ELSE vyBase.objecthandle( obj, M )
		END
	END HandleAttributes;

	PROCEDURE HandleLinks( obj: tField;  VAR msg: Objects.LinkMsg );
	BEGIN
		IF (msg.id = Objects.enum) THEN
			msg.Enum( "Array" );  msg.Enum( "EdgesH" );  msg.Enum( "EdgesV" );  msg.Enum( "Vertices" );  msg.Enum( "Original" );  vyBase.objecthandle( obj, msg )
		ELSIF (msg.id = Objects.get) THEN
			IF msg.name = "Array" THEN msg.obj := obj.A;  msg.res := 0
			ELSIF msg.name = "EdgesH" THEN msg.obj := obj.Eh;  msg.res := 0
			ELSIF msg.name = "EdgesV" THEN msg.obj := obj.Ev;  msg.res := 0
			ELSIF msg.name = "Vertices" THEN msg.obj := obj.V;  msg.res := 0
			ELSIF msg.name = "Original" THEN msg.obj := obj.Aorig;  msg.res := 0
			ELSE vyBase.objecthandle( obj, msg )
			END
		ELSE vyBase.objecthandle( obj, msg )
		END
	END HandleLinks;

	PROCEDURE Bind( o: Objects.Object;  VAR M: Objects.BindMsg );
	BEGIN
		IF (o # NIL ) & (M.lib # o.lib) THEN
			Gadgets.BindObj( o, M.lib );
			IF o.handle # NIL THEN o.handle( o, M ) END
		END
	END Bind;

	PROCEDURE Handler*( o: Objects.Object;  VAR msg: Objects.ObjMsg );   (*= layer handling, responsible for messages and vyPort event handling *)
	VAR field: tField;
	BEGIN
		field := o( tField );
		IF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO HandleAttributes( field, msg )
			END;
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO HandleLinks( field, msg )
			END;
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				HandleFileMsg( field, msg )
				(*
		| msg: antsGibbs.NewSampleMsg DO vyBase.ForUsersHandle(field.Eh,msg); vyBase.ForUsersHandle(field.Ev,msg);
		| msg: antsGibbs.InitSampleMsg DO vyBase.ForUsersHandle(field.Eh,msg); vyBase.ForUsersHandle(field.Ev,msg);
		*)
			END;
		ELSIF msg IS Objects.BindMsg THEN
			WITH msg: Objects.BindMsg DO
				IF msg.lib # field.lib THEN
					vyBase.objecthandle( field, msg );  Bind( field.Aorig, msg );  Bind( field.A, msg );  Bind( field.Ev, msg );
					Bind( field.Eh, msg );  Bind( field.V, msg )
				END;
			END;
		ELSIF msg IS vyBase.UpdateMessage THEN
			WITH msg: vyBase.UpdateMessage DO
				vyBase.Update( field );  vyBase.ForUsersHandle( field.Eh, msg );  vyBase.ForUsersHandle( field.Ev, msg )
			END;
		ELSE
		END
	END Handler;

	PROCEDURE Insert( F: tField;  Aorig, A, Ev, Eh, V: antsArrayObjects.tINTEGERObject );
	VAR name, name2: vyName.tNameArray;
	BEGIN
		vyName.GetObjId( F, name );
		IF A # NIL THEN name2 := name;  vyHostStrings.Append( name2, "A" );  vyName.RegisterNamed( A, name2 ) END;
		IF Ev # NIL THEN name2 := name;  vyHostStrings.Append( name2, "Ev" );  vyName.RegisterNamed( Ev, name2 ) END;
		IF Eh # NIL THEN name2 := name;  vyHostStrings.Append( name2, "Eh" );  vyName.RegisterNamed( Eh, name2 ) END;
		IF V # NIL THEN name2 := name;  vyHostStrings.Append( name2, "V" );  vyName.RegisterNamed( V, name2 ) END;
		IF Aorig # NIL THEN name2 := name;  vyHostStrings.Append( name2, "Orig" );  vyName.RegisterNamed( Aorig, name2 ) END;
		F.Aorig := Aorig;  F.A := A;  F.Eh := Eh;  F.Ev := Ev;  F.V := V;  F.w := A.w;  F.h := A.h;  vyBase.Subscribe( F, A );
		vyBase.Subscribe( F, Ev );  vyBase.Subscribe( F, Eh );  vyBase.Subscribe( F, V );  vyBase.Update( F.A )
	END Insert;

	PROCEDURE New*( w, h, d: SIGNED32;  name: vyName.tNameArray ): tField;
	VAR Aorig, A, Ev, Eh, V: antsArrayObjects.tINTEGERObject;  F: tField;
	BEGIN
		Aorig := NIL;  A := antsArrayObjects.NewINTEGERObject( w, h, d );
		Ev := antsArrayObjects.NewINTEGERObject( w, h, 2 );  Eh := antsArrayObjects.NewINTEGERObject( w, h, 2 );
		V := antsArrayObjects.NewINTEGERObject( w, h, 2 );  Gen;  F := Objects.NewObj( tField );
		vyName.RegisterNamed( F, name );  Insert( F, Aorig, A, Ev, Eh, V );  RETURN F
	END New;

	PROCEDURE NewField*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  F: tField;  pixels: vyBase.Object;
		A, Aorig: antsArrayObjects.tINTEGERObject;  Eh, Ev, V, pixx: antsArrayObjects.tINTEGERObject;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME from=OBJ " );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectObjectFromKeyword( l, "from", pixels ) THEN
			pixx := pixels( antsArrayObjects.tINTEGERObject );

			NEW( A );  antsArrayObjects.CopyObject( pixx, A );  antsArrayObjects.SetDepth( A, pixx.depth );  NEW( Aorig );
			antsArrayObjects.CopyObject( pixx, Aorig );  antsArrayObjects.SetDepth( Aorig, pixx.depth );

			Eh := antsArrayObjects.NewINTEGERObject( A.w, A.h, 2 );
			Ev := antsArrayObjects.NewINTEGERObject( A.w, A.h, 2 );
			V := antsArrayObjects.NewINTEGERObject( A.w, A.h, 2 );  Gen;  F := Objects.NewObj( tField );
			vyName.RegisterNamed( F, name );  Insert( F, Aorig, A, Ev, Eh, V )
		END
	END NewField;

	PROCEDURE FieldHasChanged*( F: tField );
	BEGIN
		vyBase.Update( F.A );  vyBase.Update( F.Ev );  vyBase.Update( F.Eh );  vyBase.Update( F.V )
	END FieldHasChanged;

	PROCEDURE DoShow*( F: tField );
	BEGIN
		IF F.A # NIL THEN antsViews.DoShow( F.A ) END;
		IF F.Eh # NIL THEN F.Eh.A[0, 0] := 1;  F.Eh.A[0, 1] := 1;  F.Eh.A[1, 0] := 1;  antsViews.DoShow( F.Eh ) END;
		IF F.Ev # NIL THEN F.Ev.A[0, 0] := 1;  F.Ev.A[0, 1] := 1;  F.Ev.A[1, 0] := 1;  antsViews.DoShow( F.Ev ) END;
		IF F.V # NIL THEN F.V.A[0, 0] := 1;  F.V.A[0, 1] := 1;  F.V.A[1, 0] := 1;  antsViews.DoShow( F.V ) END
	END DoShow;

	PROCEDURE ShowField*;
	VAR F: tField;  l: antsCommands.tScanList;  obj: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN F := obj( tField );  DoShow( F ) END
	END ShowField;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;
	BEGIN
		data := vyBase.NextParObj();
		WHILE (data # NIL ) DO DoShow( data( tField ) );  data := vyBase.NextParObj() END
	END ShowP;

BEGIN
	aM.launch;
END antsPEV.

antsPictLoader.Panel

antsPEV.NewField name=Field from=myArray ~
Voyager.Show FieldA  as antsViews ~
Voyager.Show FieldEv  as antsViews ~
Voyager.Show FieldEh as antsViews ~
Voyager.Show FieldOrig as antsViews ~
~

antsKernel.AttachArray f7Kernel  Field  ~ (* array "Field" wird an den Kern f7Kernel angehängt *)
~
fofAutomatic.Do
antsArrayObjects.Copy name= FieldEv to= MeanFieldEv ~
antsArrayObjects.Copy name= FieldEh to= MeanFieldEh ~
antsArrayObjects.Copy name= FieldA to= MeanFieldA ~

antsMeanArray.New name=MeanTrafo1 src=FieldEv dest=MeanFieldEv ~
antsMeanArray.New name=MeanTrafo2 src=FieldEh dest=MeanFieldEh ~
Voyager.Show MeanFieldEv  as antsViews ~
Voyager.Show MeanFieldEh as antsViews ~
~
fofAutomatic.Do
antsMC.Init f7Chain ~ (* Initalisiere Markov Kette *)
antsMeanArray.Init MeanTrafo1
antsMeanArray.Init MeanTrafo2
~
fofAutomatic.Do >interactive >secure
antsMC.Forward f7Chain 1 1 ~
~