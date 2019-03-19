MODULE antsScriptObjects IN Oberon;   (** fof  **)
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

IMPORT Gadgets, Objects, Display, Oberon, Texts, Fonts, Files, Links, Attributes, Strings, aM := antsMessages;

TYPE

	ObjList = POINTER TO ObjListDesc;   (* List of Objects in a text *)
	ObjListDesc = RECORD
		obj: Objects.Object;
		pos: LONGINT;
		next: ObjList
	END;

	Object = POINTER TO ObjectDesc;   (* this object is set as Link "CmdObject" in a Object etc. *)
	ObjectDesc = RECORD (Gadgets.ObjDesc)
		tobjlist: ObjList;   (* extract base objects from text before storing *)
		(* text is set as Links.Link *)
	END;

	TaskAfterStore = POINTER TO TaskAfterStoreDesc;
	TaskAfterStoreDesc = RECORD (Oberon.TaskDesc);
		b: Object
	END;

CONST
	cmdLinkName = "CmdTextObject";  cmdTextName = "CommandText";  cmdFileName = "antsCommandText.Text";
VAR
	editmode*: BOOLEAN;

	PROCEDURE OpenCommandText( b: Object;  name: ARRAY OF CHAR;  cmd: ARRAY OF CHAR );
	VAR obj: Objects.Object;  text: Texts.Text;
		string: ARRAY 256 OF CHAR;
		w: Texts.Writer;
	BEGIN
		Links.GetLink( b, cmdTextName, obj );
		IF (obj = NIL ) OR (~(obj IS Texts.Text)) THEN
			NEW( text );  Texts.Open( text, cmdFileName );  Links.SetLink( b, cmdTextName, text );  text.lib := b.lib;
			IF cmd # "" THEN
				Texts.OpenWriter( w );  Texts.WriteString( w, cmd );  Texts.WriteLn( w );  Texts.Insert( text, 0, w.buf )
			END
		ELSE text := obj( Texts.Text )
		END;
		IF cmd = "" THEN
			string := "Command (";  Strings.Append( string, name );  Strings.Append( string, ")" );  Oberon.OpenText( string, text, 400, 300 );
			editmode := FALSE
		END
	END OpenCommandText;

	PROCEDURE ConvertText( text: Texts.Text;  VAR ntext: Texts.Text );
	VAR sc: Attributes.Reader;  w: Texts.Writer;  ch: CHAR;  obj: Objects.Object;
	BEGIN
		aM.dS( "antsScriptObjects: converting text" );  NEW( ntext );  Texts.OpenWriter( w );  Attributes.OpenReader( sc, text, 0 );  Attributes.Read( sc, ch );
		WHILE (~sc.eot) DO
			IF ~(sc.lib IS Fonts.Font) THEN sc.lib.GetObj( sc.lib, ORD( ch ), obj );  Texts.WriteObj( w, obj ) ELSE Texts.Write( w, ch ) END;
			Attributes.Read( sc, ch )
		END;
		Texts.Open( ntext, "nothing" );  Texts.Append( ntext, w.buf );  ntext.lib := text.lib;
		IF editmode THEN Oberon.OpenText( "orig", text, 100, 100 );  Oberon.OpenText( "changed", ntext, 100, 100 ) END
	END ConvertText;

	PROCEDURE ExecuteCommandText( b: Object;  VAR context: Objects.Object );
	VAR obj: Objects.Object;  text: Texts.Text;  sc: Texts.Scanner;  res: INTEGER;  ntext: Texts.Text;
	BEGIN
		Gadgets.context := context;  Links.GetLink( b, cmdTextName, obj );
		IF (obj # NIL ) & (obj IS Texts.Text) THEN text := obj( Texts.Text )
		ELSE NEW( text );  Texts.Open( text, cmdFileName );  Links.SetLink( b, cmdTextName, text );  text.lib := b.lib
		END;
		ConvertText( text, ntext );
		IF ~editmode THEN
			Texts.OpenScanner( sc, ntext, 0 );  Texts.Scan( sc );
			IF sc.class = Texts.Name THEN
				Oberon.Par.text := ntext;  Oberon.Par.pos := Texts.Pos( sc ) - 1;  Gadgets.executorObj := b;
				Oberon.Call( sc.s, Oberon.Par, FALSE , res )
			ELSE OpenCommandText( b, "(clicked)", "" )
			END
		ELSE editmode := FALSE
		END
	END ExecuteCommandText;

	PROCEDURE FindObj( VAR sc: Texts.Finder;  VAR pos: LONGINT;  VAR obj: Objects.Object ): BOOLEAN;
	BEGIN
		pos := sc.pos;  Texts.FindObj( sc, obj );
		IF obj # NIL THEN RETURN TRUE ELSE RETURN FALSE END
	END FindObj;

	PROCEDURE ComeBack( t: Oberon.Task );
	BEGIN
		WITH t: TaskAfterStore DO RestoreTextList( t.b )
		END;
		Oberon.Remove( t )
	END ComeBack;

(** SetTextLibs:
All Objects.Object from executable text are bound to lib and deleted from text, since text opens new libraries and binds objects NEWLY
Here: objects get deleted and bound to outer context before storig, when finished storing they get reconstructed in the text, this is done with a
Oberon.Task , since storing of the text is done by its library out of this module afterwards, background task was the only way to guarantee execution
after storing.
when loading the document, a text without objects gets loaded, they are inserted after loading "by hand" (i.e. by loading them seperatley in LoadObjectList)
All that complicated stuff is done since antsCommandList can handle objects as reference on objects as input (to prevent from multiple reference in the name space).
*)

	PROCEDURE SetTextLibs( b: Object;  lib: Objects.Library );
	VAR obj: Objects.Object;  text: Texts.Text;  finder: Texts.Finder;  list: ObjList;  pos: LONGINT;  temp: ObjList;  task: TaskAfterStore;
	BEGIN
		IF b.tobjlist = NIL THEN
			aM.dS( "antsScriptObjects: Extracting objects from text" );  Links.GetLink( b, cmdTextName, obj );
			IF (obj # NIL ) & (obj IS Texts.Text) THEN
				text := obj( Texts.Text );  Texts.OpenFinder( finder, text, 0 );
				WHILE (FindObj( finder, pos, obj )) DO
					(* check if command object ? for now we simply take all objects and bind them with button *)
					temp := list;  NEW( list );  list.next := temp;

					list.obj := obj;  list.pos := pos;  Texts.Delete( text, pos, pos + 1 );  Gadgets.BindObj( obj, lib );
					Texts.OpenFinder( finder, text, pos )
				END
			END;
			b.tobjlist := list;  NEW( task );  task.b := b;  task.time := Oberon.Time();  task.handle := ComeBack;  aM.dS( "antsScriptObjects: Installing restore-task" );
			Oberon.Install( task )
		ELSE
			list := b.tobjlist;
			WHILE (list # NIL ) DO
				IF list.obj # NIL THEN Gadgets.BindObj( list.obj, lib ) END;
				list := list.next;
			END;
		END;
	END SetTextLibs;

	PROCEDURE RestoreTextList( F: Object );
	VAR list: ObjList;  W: Texts.Writer;  obj: Objects.Object;  text: Texts.Text;
	BEGIN
		IF F.tobjlist = NIL THEN RETURN END;
		aM.dS( "antsScriptObjects: Restoring objects from text" );  Links.GetLink( F, cmdTextName, obj );
		IF (obj # NIL ) & (obj IS Texts.Text) THEN text := obj( Texts.Text ) ELSE RETURN END;

		Texts.OpenWriter( W );

		list := F.tobjlist;
		WHILE (list # NIL ) DO
			IF list.obj # NIL THEN Texts.WriteObj( W, list.obj );  Texts.Insert( text, list.pos, W.buf );  END;
			list := list.next
		END;
		F.tobjlist := NIL;
	END RestoreTextList;

	PROCEDURE WriteTextList( VAR F: Object;  VAR M: Objects.FileMsg );
	VAR list: ObjList;
	BEGIN
		list := F.tobjlist;
		WHILE (list # NIL ) DO Files.WriteLInt( M.R, list.pos );  Gadgets.WriteRef( M.R, F.lib, list.obj );  list := list.next END;
		Files.WriteLInt( M.R, -1 )
	END WriteTextList;

	PROCEDURE LoadTextList( VAR F: Object;  VAR M: Objects.FileMsg );
	VAR pos: LONGINT;  list, temp: ObjList;
	BEGIN
		aM.dS( "Loading Text List" );  Files.ReadLInt( M.R, pos );
		WHILE (pos >= 0) DO

			IF temp = NIL THEN NEW( temp );  list := temp
			ELSE NEW( list.next );  list := list.next
			END;

			list.pos := pos;  Gadgets.ReadRef( M.R, F.lib, list.obj );  Files.ReadLInt( M.R, pos )
		END;
		F.tobjlist := temp
	END LoadTextList;

	PROCEDURE CopyText*( VAR M: Objects.CopyMsg;  from, to: Object );
	VAR id: INTEGER;  obj: Objects.Object;
	BEGIN
		(*
	IF M.id = Objects.deep THEN RETURN END;
	id := M.id;
	Links.GetLink(from, cmdTextName, obj);
	IF (obj # NIL) & (obj IS Texts.Text) THEN
		M.id := Objects.deep;
		obj.handle(obj,M);
		obj := M.obj;
		M.id := id;
		Links.SetLink(to,cmdTextName, obj);
	END;
	*)
		Links.GetLink( from, cmdTextName, obj );  Links.SetLink( to, cmdTextName, obj );
	END CopyText;

	PROCEDURE CopyButton*( VAR M: Objects.CopyMsg;  from, to: Object );
	BEGIN
		aM.dS( "CopyScriptObject" );  Gadgets.CopyObject( M, from, to );
		(*
	CopyText(M,from,to);
	*)
	END CopyButton;

	PROCEDURE ObjectHandler*( F: Objects.Object;  VAR M: Objects.ObjMsg );
	VAR ver: LONGINT;  F2: Object;
	BEGIN
		WITH F: Object DO
			IF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					IF M.id = Objects.store THEN Files.WriteNum( M.R, 0 );  Gadgets.objecthandle( F, M );  WriteTextList( F, M )
					ELSIF M.id = Objects.load THEN
						Files.ReadNum( M.R, ver );  Gadgets.objecthandle( F, M );  LoadTextList( F, M );  RestoreTextList( F )
					END
				END
			ELSIF M IS Objects.BindMsg THEN SetTextLibs( F, M( Objects.BindMsg ).lib );  Gadgets.objecthandle( F, M )
			ELSIF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF (M.id = Objects.get) & (M.name = "Gen") THEN M.class := Objects.String;  COPY( "antsScriptObjects.New", M.s );  M.res := 0
					ELSE Gadgets.objecthandle( F, M )
					END
				END

			ELSIF M IS Objects.CopyMsg THEN
				WITH M: Objects.CopyMsg DO
					IF M.stamp = F.stamp THEN M.obj := F.dlink;
					ELSE NEW( F2 );  F.stamp := M.stamp;  F.dlink := F2;  CopyButton( M, F, F2 );  M.obj := F2
					END
				END

			ELSE Gadgets.objecthandle( F, M )
			END
		END
	END ObjectHandler;

	PROCEDURE New*;
	VAR F: Object;
	BEGIN
		NEW( F );  F.handle := ObjectHandler;  Objects.NewObj := F
	END New;

	PROCEDURE Edit*;
	VAR name: ARRAY 256 OF CHAR;
		MOS: Display.SelectMsg;  o, o2: Objects.Object;
	BEGIN
		MOS.id := Display.get;  MOS.time := -1;  MOS.F := NIL;  MOS.obj := NIL;  Display.Broadcast( MOS );  o := MOS.obj;
		WHILE (o # NIL ) DO
			IF o IS Gadgets.Frame THEN
				WITH o: Gadgets.Frame DO
					aM.vS( "antsScriptObjects: found Gadgets.Frame" );  Links.GetLink( o, cmdLinkName, o2 );
					IF o2 # NIL THEN
						IF o2 IS Object THEN
							WITH o2: Object DO
								name := "";  Attributes.GetString( o, "Caption", name );
								IF name = "" THEN Attributes.GetString( o, "Name", name ) END;
								aM.vS( "antsScriptObjects: Opening command text" );  OpenCommandText( o2, name, "" )
							END;
						ELSE
						END
					END
				END;
			ELSE
			END;
			o := NIL
		END
	END Edit;

	PROCEDURE LinkSelection*;
	VAR obj: Objects.Object;
		cmdstring, name: ARRAY 256 OF CHAR;
		MOS: Display.SelectMsg;  o: Objects.Object;
	BEGIN
		MOS.id := Display.get;  MOS.time := -1;  MOS.F := NIL;  MOS.obj := NIL;  Display.Broadcast( MOS );  o := MOS.obj;
		WHILE (o # NIL ) DO
			IF o IS Gadgets.Frame THEN
				WITH o: Gadgets.Frame DO
					aM.vS( "antsScriptObjects: taking object" );  Links.GetLink( o, cmdLinkName, obj );
					IF obj = NIL THEN
						Attributes.GetString( o, "Cmd", cmdstring );  aM.SS( "antsScriptObjects: transferring", cmdstring );  New;  obj := Objects.NewObj( Object );
						Links.SetLink( o, cmdLinkName, obj );  name := "";  Attributes.GetString( o, "Caption", name );
						IF name = "" THEN Attributes.GetString( o, "Name", name ) END;
						OpenCommandText( obj( Object ), name, cmdstring );  Attributes.SetString( o, "Cmd", "antsScriptObjects.ExecuteCmdLink" );  aM.vSS( "Replaced cmd by ", "antsScriptObjects.ExecuteCmdLink" );
					END
				END;
			ELSE
			END;
			o := o.slink
		END
	END LinkSelection;

	PROCEDURE UnLinkSelection*;
	VAR o, text, obj: Objects.Object;  i: LONGINT;
		cmdstring: ARRAY 256 OF CHAR;
		MOS: Display.SelectMsg;  R: Texts.Reader;  ch: CHAR;
	BEGIN
		MOS.id := Display.get;  MOS.time := -1;  MOS.F := NIL;  MOS.obj := NIL;  Display.Broadcast( MOS );  o := MOS.obj;
		WHILE (o # NIL ) DO
			IF o IS Gadgets.Frame THEN
				WITH o: Gadgets.Frame DO
					aM.vS( "antsScriptObjects: Found object" );  Links.GetLink( o, cmdLinkName, obj );
					IF obj # NIL THEN
						WITH obj: Object DO
							aM.vS( "antsScriptObjects: Object has ScriptObject" );  Links.GetLink( obj, cmdTextName, text );
							IF text # NIL THEN
								WITH text: Texts.Text DO
									Texts.OpenReader( R, text, 0 );  Texts.Read( R, ch );  i := 0;
									WHILE (~R.eot) & (ch # 0DX) DO cmdstring[i] := ch;  INC( i );  Texts.Read( R, ch ) END;
									cmdstring[i] := 0X;  aM.vS( "antsScriptObjects: unlinked Object" );  aM.vSS( "antsScriptObjects: replacing cmd by ", cmdstring );  Attributes.SetString( o, "Cmd", cmdstring );
									Links.SetLink( o, cmdLinkName, NIL )
								END
							END
						END
					END
				END;
			ELSE
			END;
			o := o.slink
		END
	END UnLinkSelection;

	PROCEDURE ExecuteCmdLink*;
	VAR context, obj: Objects.Object;
	BEGIN
		context := Gadgets.executorObj;  obj := NIL;  Links.GetLink( context, cmdLinkName, obj );
		IF (obj # NIL ) & (obj IS Object) THEN aM.dS( "antsScriptObjects:Execute command Link" );  ExecuteCommandText( obj( Object ), Gadgets.context ) END
	END ExecuteCmdLink;

	PROCEDURE Debug*;
	BEGIN
		editmode := TRUE;  aM.S( "antsScriptObjects.DebugMode, next click will command texts" );
	END Debug;

BEGIN
	editmode := FALSE;
END antsScriptObjects.

to change buttons: Select Button(s), then execute:
antsScriptObjects.LinkSelection ~

to edit buttons: Select ONE Button, then execute
antsScriptObjects.Edit  ~





only for emergency:
antsScriptObjects.UnLinkSelection ~
antsScriptObjects.editmode := TRUE;

