MODULE antsVectors IN Oberon;
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




IMPORT vyBase, vyLinks, Objects, Files, antsObjects, antsCommands, vyName, aM := antsMessages;

TYPE
	Container* = POINTER TO ContainerDesc;
	ContainerDesc* = RECORD (vyBase.ObjDesc)
		vectors*: vyLinks.Link;
		num*: SIGNED32
	END;

	PROCEDURE HandleAttributes( o: Container;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.enum THEN M.Enum( "Gen" );  vyBase.objecthandle( o, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'antsVectors.Gen', M.s );  M.class := Objects.String;  M.res := 0 ELSE vyBase.objecthandle( o, M ) END
		ELSIF M.id = Objects.set THEN vyBase.objecthandle( o, M )
		ELSE vyBase.objecthandle( o, M )
		END
	END HandleAttributes;

	PROCEDURE FrameLinks( F: Container;  VAR M: Objects.LinkMsg );
	BEGIN
		vyLinks.DoHandleLinks( F.vectors, "Vector", M )
	END FrameLinks;

	PROCEDURE HandleFileMsg( obj: Container;  VAR msg: Objects.FileMsg );
	VAR version: SIGNED16;
	BEGIN
		IF msg.id = Objects.load THEN
			Files.ReadInt( msg.R, version );  vyBase.objecthandle( obj, msg );  vyLinks.LoadLinks( msg.R, obj.lib, obj.vectors );
			Files.ReadLInt( msg.R, obj.num )
		ELSIF msg.id = Objects.store THEN
			Files.WriteInt( msg.R, 0 );  vyBase.objecthandle( obj, msg );  vyLinks.StoreLinks( msg.R, obj.lib, obj.vectors );
			Files.WriteLInt( msg.R, obj.num )
		ELSE vyBase.objecthandle( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR link: vyLinks.Link;
	BEGIN
		WITH obj: Container DO
			IF msg IS Objects.AttrMsg THEN
				WITH msg: Objects.AttrMsg DO HandleAttributes( obj, msg )
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO HandleFileMsg( obj, msg );
				END;
			ELSIF msg IS Objects.LinkMsg THEN
				WITH msg: Objects.LinkMsg DO FrameLinks( obj, msg )
				END;
			ELSIF msg IS Objects.BindMsg THEN
				WITH msg: Objects.BindMsg DO
					IF obj.lib # msg.lib THEN vyLinks.BindLinks( obj.vectors, msg ) END;
					vyBase.objecthandle( obj, msg );
				END;
			ELSIF msg IS vyBase.UpdateMessage THEN
				WITH msg: vyBase.UpdateMessage DO
					link := obj.vectors;
					WHILE link # NIL DO vyBase.Update( link.obj );  link := link.link END
				END;
			ELSE vyBase.objecthandle( obj, msg )
			END
		END
	END Handler;

	PROCEDURE GetVector*( c: Container;  num: SIGNED32 ): vyBase.tVector;
	VAR i: SIGNED32;  list: vyLinks.Link;
	BEGIN
		i := 0;  list := c.vectors;
		WHILE list # NIL DO
			IF i = num THEN
				IF list.obj = NIL THEN RETURN NIL ELSE RETURN list.obj( vyBase.tVector ) END
			END;
			list := list.link;  INC( i )
		END;
		RETURN NIL
	END GetVector;

	PROCEDURE InsertVector*( c: Container;  v: vyBase.Object );
	BEGIN
		vyLinks.InsertObj( c.vectors, v );  vyBase.Subscribe( c, v );  INC( c.num )
	END InsertVector;

	PROCEDURE Gen*;
	VAR c: Container;
	BEGIN
		aM.cmd;
		NEW( c );  c.handle := Handler;  c.num := 0;  Objects.NewObj := c (* c.bindcount := 0; *)
	END Gen;

	PROCEDURE New*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  obj: Container;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) THEN
			Gen;  obj := Objects.NewObj( Container );  vyName.RegisterNamed( obj, name );  antsObjects.Register( obj )
		END
	END New;

	PROCEDURE Add*;
	VAR l: antsCommands.tScanList;  obj, vect: vyBase.Object;  i: SIGNED16;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ [vect={OBJ}]" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN
			i := 2;
			WHILE antsCommands.GetObjectFromKeyword( l, "vect", vect ) DO
				WITH obj: Container DO InsertVector( obj, vect )
				END;
				INC( i )
			END
		END
	END Add;

BEGIN
	aM.launch
END antsVectors.
System.Free antsVectors ~


antsFctVector.NewVec v1 100 ~
antsFctVector.NewVec v2 v1 ~
antsVectors.New container ~
antsVectors.Add container v1 v2 ~
Voyager.Show container as antsObjectView ~
