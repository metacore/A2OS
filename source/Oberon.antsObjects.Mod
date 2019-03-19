MODULE antsObjects IN Oberon;   (** fof  **)
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




IMPORT vyPort, Objects, vyBase, vyLinks, Files, Gadgets, vyName, antsCommands, antsBasicGadgets, Desktops, Columbus,
	SYSTEM, Oberon, Display, BasicGadgets, vyHostTexts, Links, Texts, Documents, Attributes, TextGadgets, Input,
	antsToolbox, aM := antsMessages, Strings, Types, vyCommandMenus, vyEvents;

TYPE
	Index* = LONGINT;

	tObject* = POINTER TO tObjectDesc;
	tObjectDesc* = RECORD (vyBase.ObjDesc)
		all: vyLinks.Link
	END;

	PAConsistTrafoProc* = PROCEDURE ( o: Objects.Object );
	(*= conversion from Img To Array and vice versa*)

	tlinkList* = POINTER TO tlinkListDesc;
	tlinkListDesc* = RECORD
		name*: vyName.tNameArray;
		obj*: Objects.Object;
		host*: Objects.Object;
		next*: tlinkList
	END;

	UpdateTask = POINTER TO UpdateTaskDesc;
	UpdateTaskDesc = RECORD (Oberon.TaskDesc)
		nexttime: LONGINT;
		t: Texts.Text;
		pos: LONGINT;
		D: Documents.Document;
		l: vyLinks.Link
	END;

CONST
	classBoolean* = "Boolean";  classInteger* = "Integer";  classReal* = "Real";  classString* = "String";  classUnknown* = "Unknown";

VAR
	obj-: tObject;  antsObjects: vyLinks.Link;  currobj: Objects.Object;  currcount: LONGINT;
	currName: ARRAY 64 OF ARRAY 32 OF CHAR;
	(* gen-: vyRanBase.tRandom; *)
	linklist*, curlinklist: tlinkList;  found: BOOLEAN;

	PROCEDURE Bind*( obj: Objects.Object;  VAR msg: Objects.BindMsg );
	BEGIN
		IF (obj # NIL ) & (msg.lib # obj.lib) THEN
			(* Gadgets.BindObj(obj,msg.lib); *)
			IF obj.handle # NIL THEN obj.handle( obj, msg )
			ELSE
				Gadgets.BindObj( obj, msg.lib );   (*!!! fof 010419 changed !! *)
			END;
			obj.lib := msg.lib
		END
	END Bind;

	PROCEDURE Clear*;
	BEGIN
		aM.vS( "antsObjects.Clear" );  antsObjects := obj.all;  obj.all := NIL;  vyBase.Update( obj )
	END Clear;

	PROCEDURE UndoClear*;
	BEGIN
		obj.all := antsObjects;  vyBase.Update( obj )
	END UndoClear;

	PROCEDURE Update*;
	BEGIN
		aM.vS( "antsObjects.Update, uses antsObjects.obj" );  vyBase.Update( obj )
	END Update;

	PROCEDURE Register*( o: vyBase.Object );
	BEGIN
		vyLinks.InsertObjOnce( obj.all, o );  vyBase.Update( obj )
	END Register;

	PROCEDURE vyRegister*( o: vyBase.Object );
	BEGIN
		Register( o );  vyBase.register( o )
	END vyRegister;

	PROCEDURE DeRegister*( o: vyBase.Object );
	BEGIN
		vyLinks.DeleteLink( obj.all, o )
	END DeRegister;

	PROCEDURE StoreF( VAR R: Files.Rider;  o: tObject );
	BEGIN
		Files.WriteInt( R, 0 )
	END StoreF;

	PROCEDURE LoadF( VAR R: Files.Rider;  o: tObject );
	VAR version: INTEGER;
	BEGIN
		Files.ReadInt( R, version )
	END LoadF;

	PROCEDURE HandleLinkMsg( l: vyLinks.Link;  name: ARRAY OF CHAR;  VAR M: Objects.LinkMsg );
	VAR lname: ARRAY 256 OF CHAR;
		i: LONGINT;
	BEGIN
		IF M.id = Objects.enum THEN
			i := 1;
			WHILE l # NIL DO vyLinks.SeqName( name, ":", i, lname );  M.Enum( lname );  l := l.link;  INC( i ) END
		ELSIF M.id = Objects.get THEN
			vyLinks.NameToSeq( M.name, ":", lname, i );
			IF lname = name THEN
				WHILE i > 1 DO l := l.link;  DEC( i ) END;
				M.obj := l.obj;  M.res := 0
			END
		END
	END HandleLinkMsg;

	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	BEGIN
		WITH o: tObject DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.enum THEN M.Enum( "Gen" );  vyBase.objecthandle( o, M )
					ELSIF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( 'antsObjects.Gen', M.s );  M.class := Objects.String;  M.res := 0;  RETURN ELSE vyBase.objecthandle( o, M ) END
					ELSE vyBase.objecthandle( o, M )
					END;
				END;
			ELSIF M IS Objects.LinkMsg THEN
				WITH M: Objects.LinkMsg DO
					IF o.all # NIL THEN HandleLinkMsg( o.all, "Obj", M ) END;
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					IF M.id = Objects.load THEN vyBase.objecthandle( o, M );  LoadF( M.R, o )
					ELSIF M.id = Objects.store THEN vyBase.objecthandle( o, M );  StoreF( M.R, o )
					END;
				END;
			ELSIF M IS Objects.BindMsg THEN
				WITH M: Objects.BindMsg DO
					IF M.lib # o.lib THEN vyBase.objecthandle( o, M );  vyLinks.BindLinks( o.all, M ) END
				END;
			ELSE vyBase.objecthandle( o, M )
			END
		END  (* tVector*)
	END Handler;

	PROCEDURE Gen*;
	BEGIN
		aM.cmd;  Objects.NewObj := obj;
	END Gen;

	PROCEDURE UnSubscribe*;
	VAR l: antsCommands.tScanList;  obj, user: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "in=OBJ user=OBJ" );
		IF antsCommands.ExpectObjectFromKeyword( l, "in", obj ) & antsCommands.ExpectObjectFromKeyword( l, "user", user ) THEN
			vyBase.UnSubscribe( obj, user )
		END
	END UnSubscribe;

	PROCEDURE Subscribe*;
	VAR l: antsCommands.tScanList;  obj, user: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "in=OBJ user=OBJ" );
		IF antsCommands.ExpectObjectFromKeyword( l, "in", obj ) & antsCommands.ExpectObjectFromKeyword( l, "user", user ) THEN
			vyBase.Subscribe( obj, user )
		END
	END Subscribe;

	PROCEDURE BasicModel*( obj: Objects.Object;  attribute: ARRAY OF CHAR;  VAR class: ARRAY OF CHAR ): Objects.Object;
	VAR model: Objects.Object;
	BEGIN
		antsBasicGadgets.NewModelLinked( obj, attribute );  model := Objects.NewObj;
		IF model = NIL THEN COPY( classUnknown, class )
		ELSIF model IS BasicGadgets.Boolean THEN COPY( classBoolean, class )
		ELSIF model IS BasicGadgets.Integer THEN COPY( classInteger, class )
		ELSIF model IS BasicGadgets.Real THEN COPY( classReal, class )
		ELSIF model IS BasicGadgets.String THEN COPY( classString, class )
		END;
		RETURN model
	END BasicModel;

	PROCEDURE GadgetToModel*( gen: ARRAY OF CHAR;  model: Objects.Object );
	VAR msg: Objects.LinkMsg;  TF: Objects.Object;
	BEGIN
		TF := Gadgets.CreateObject( gen );  msg.id := Objects.set;  msg.obj := model;  COPY( "Model", msg.name );  msg.res := -1;
		TF.handle( TF, msg );
		IF TF IS Display.Frame THEN
			WITH TF: Display.Frame DO TF.W := 100;  vyHostTexts.InsertGadget( TF )
			END;
		ELSE
		END
	END GadgetToModel;

	PROCEDURE SetLnk*;
	VAR obj, link: vyBase.Object;
		name: ARRAY 128 OF CHAR;
	BEGIN
		antsCommands.InitScan( "obj=OBJ link=OBJ name=NAME" );
		IF antsCommands.ExpectObject( "obj", obj ) & antsCommands.ExpectObject( "link", link ) & antsCommands.ExpectName( "name", name ) THEN
			Links.SetLink( obj, name, link );  aM.S( "antsObjects: link set" )
		END
	END SetLnk;

	PROCEDURE DeleteLnk*;
	VAR obj: vyBase.Object;
		name: ARRAY 128 OF CHAR;
	BEGIN
		antsCommands.InitScan( "obj=OBJ name=NAME" );
		IF antsCommands.ExpectObject( "obj", obj ) & antsCommands.ExpectName( "name", name ) THEN
			Links.DeleteLink( obj.link, name );  aM.S( "antsObjects: link deleted" )
		END
	END DeleteLnk;

	PROCEDURE WriteAttribute*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;
		attribute, class: ARRAY 32 OF CHAR;
		model: Objects.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "obj=OBJ attr=NAME" );
		IF antsCommands.ExpectObjectFromKeyword( l, "obj", obj ) & antsCommands.ExpectStringFromKeyword( l, "attr", attribute ) THEN
			model := BasicModel( obj, attribute, class );
			IF class = classBoolean THEN GadgetToModel( "BasicGadgets.NewCheckBox", model ) ELSE GadgetToModel( "TextFields.NewTextField", model ) END;
			aM.vSS( "antsObjects.WrittenAttribute: ", attribute );
		END
	END WriteAttribute;

	PROCEDURE SetAttribute*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;  obj1: Objects.Object;
		attribute, name, class: ARRAY 32 OF CHAR;
		model: Objects.Object;  num: LONGINT;  real: LONGREAL;
		string: ARRAY 256 OF CHAR;
	BEGIN
		l := antsCommands.ScanFromPar( "[obj=OBJ | obj=NAME] attr=NAME val=(INT|REAL|STR) ~#use obj=LAYER or obj=PICTURE for last opened graphics" );
		IF ~antsCommands.GetObjectFromKeyword( l, "obj", obj ) THEN
			l.spos := 1;  aM.vS( "antsObjects: no object" );
			IF antsCommands.ExpectNameFromKeyword( l, "obj", name ) THEN
				IF name = "LAYER" THEN obj := vyPort.FocusLayer();  obj1 := obj
				ELSIF name = "PICTURE" THEN obj1 := vyPort.GetFocusPicture()
				ELSE aM.vS( "antsObjects: no object, did you mean LAYER or PICTURE ?" );
				END
			ELSE RETURN
			END
		ELSE obj1 := obj
		END;
		l.spos := 2;
		IF antsCommands.ExpectStringFromKeyword( l, "attr", attribute ) THEN
			model := BasicModel( obj, attribute, class );
			IF class = classInteger THEN
				aM.vS( "antsObjects: Attribute IS INTEGER" );  l.spos := 3;
				IF antsCommands.ExpectNumberFromKeyword( l, "val", num ) THEN Attributes.SetInt( obj1, attribute, num ) END
			ELSIF class = classReal THEN
				aM.vS( "antsObjects: Attribute IS REAL" );  l.spos := 3;
				IF antsCommands.ExpectRealFromKeyword( l, "val", real ) THEN Attributes.SetLongReal( obj1, attribute, real ) END
			ELSIF class = classString THEN
				aM.vS( "antsObjects: Attribute IS String" );  l.spos := 3;
				IF antsCommands.ExpectStringFromKeyword( l, "val", string ) THEN Attributes.SetString( obj1, attribute, string ) END
			ELSIF class = classBoolean THEN
				aM.vS( "antsObjects: Attribute IS Boolean" );  l.spos := 3;
				IF antsCommands.ExpectStringFromKeyword( l, "val", string ) THEN
					Strings.Upper( string, string );
					IF (string = "FALSE") OR (string = "NO") THEN Attributes.SetBool( obj1, attribute, FALSE )
					ELSIF (string = "TRUE") OR (string = "YES") THEN Attributes.SetBool( obj1, attribute, TRUE )
					ELSE aM.eS( "antsObjects: attribute boolean, write TRUE or YES or FALSE or NO !" )
					END
				END
			ELSE aM.eS( "antsObjects: unknown class" )
			END;
			IF obj IS vyBase.Object THEN
				WITH obj: vyBase.Object DO vyBase.Update( obj )
				END;
			ELSE Gadgets.Update( obj )
			END;
		END
	END SetAttribute;

	PROCEDURE EnumInsertGadget( CONST A: ARRAY OF CHAR );
	VAR class: ARRAY 32 OF CHAR;
		model: Objects.Object;  i: LONGINT;
	BEGIN
		FOR i := 0 TO currcount - 1 DO
			IF A = currName[i] THEN RETURN END
		END;
		COPY( A, class );  model := BasicModel( currobj, A, class );
		IF model # NIL THEN
			IF class = classBoolean THEN GadgetToModel( "BasicGadgets.NewCheckBox", model ) ELSE GadgetToModel( "TextFields.NewTextField", model ) END;
			vyHostTexts.MsgSS( " : ", A )

		END
	END EnumInsertGadget;

	PROCEDURE EnumBaseNames( CONST A: ARRAY OF CHAR );
	BEGIN
		COPY( A, currName[currcount] );  INC( currcount )
	END EnumBaseNames;

	PROCEDURE DoAllFields*( obj: Objects.Object;  nobasic: BOOLEAN );
	VAR enummsg: Objects.AttrMsg;  o: Display.Frame;  text: Objects.Object;  cmsg, c2msg: Oberon.CaretMsg;

	BEGIN

		c2msg.id := Oberon.get;  c2msg.F := NIL;  Display.Broadcast( c2msg );  TextGadgets.NewNote;
		o := Objects.NewObj( Display.Frame );  o.W := 200;  o.H := 250;  vyHostTexts.InsertGadget( o );
		(* Gadgets.Integrate(o); *)
		Links.GetLink( o, "Model", text );  cmsg.id := Oberon.set;  cmsg.car := o( Display.Frame );  cmsg.text := text( Texts.Text );
		cmsg.pos := 0;  cmsg.F := o( Display.Frame );  Display.Broadcast( cmsg );

		currobj := obj;
		IF obj IS vyBase.Object THEN
			IF nobasic THEN
				enummsg.Enum := EnumBaseNames;  enummsg.res := -1;  enummsg.id := Objects.enum;  currcount := 1;
				currName[0] := "Gen";
				IF obj IS vyPort.tLayer THEN vyPort.LayerHandler( obj, enummsg ) ELSE vyBase.objecthandle( obj, enummsg ) END
			END
		END;
		enummsg.Enum := EnumInsertGadget;  enummsg.res := -1;  enummsg.id := Objects.enum;
		obj.handle( obj, enummsg );  vyHostTexts.AppendToLog( vyHostTexts.w );
		IF c2msg.text # NIL THEN c2msg.id := Oberon.set;  INC( c2msg.pos );  Display.Broadcast( c2msg ) ELSE Oberon.Defocus END
	END DoAllFields;

	PROCEDURE WriteAttributes*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "obj=OBJ" );
		IF antsCommands.ExpectObjectFromKeyword( l, "obj", obj ) THEN DoAllFields( obj, antsCommands.FindKeyword( l, "nobase" ) ) END
	END WriteAttributes;


(** dependent layers get position on top *)
	PROCEDURE DependentToFront*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;  msg: vyPort.UpMsg;
	BEGIN
		l := antsCommands.ScanFromPar( "obj=OBJECT" );
		IF antsCommands.ExpectObjectFromKeyword( l, "obj", obj ) THEN vyBase.ForUsersHandle( obj, msg ) END
	END DependentToFront;

	PROCEDURE vyObjects*;
	BEGIN
		vyBase.Register := vyRegister
	END vyObjects;

	PROCEDURE GetLink*( o: Objects.Object;  name: ARRAY OF CHAR ): Objects.Object;
	VAR link: Objects.Object;
	BEGIN
		link := NIL;  Links.GetLink( o, name, link );  RETURN link
	END GetLink;

	PROCEDURE SetLink*( link: Objects.Object;  o: Objects.Object;  name: ARRAY OF CHAR );
	BEGIN
		Links.SetLink( o, name, link )
	END SetLink;

(*
PROCEDURE SetGen* (ngen: vyRanBase.tRandom);
BEGIN
gen := ngen;
END SetGen;
*)

	PROCEDURE ListInspect*;
	VAR context, obj: Objects.Object;
	BEGIN
		aM.vS( "antsObjects.ListInspect" );  context := Gadgets.executorObj;  Links.GetLink( context, "Model", obj );  Columbus.InspectObj( obj )
	END ListInspect;

	PROCEDURE ListView*;
	VAR context, obj: Objects.Object;  link: vyLinks.Link;
	BEGIN
		aM.vS( "antsObjects.ListView" );  vyCommandMenus.Wait();  context := Gadgets.executorObj;  Links.GetLink( context, "Model", obj );
		vyLinks.InsertObj( link, obj( vyBase.Object ) );  vyBase.Show( link, 1, "antsPlots" )
	END ListView;

	PROCEDURE ListAttributes*;
	VAR context, obj: Objects.Object;
	BEGIN
		aM.vS( "antsObjects.ListAttributes" );  context := Gadgets.executorObj;  Links.GetLink( context, "Model", obj );  DoAllFields( obj, FALSE )
	END ListAttributes;

	PROCEDURE ListList*;
	VAR l: vyCommandMenus.List;  keys: SET;  x, y: INTEGER;  event: vyEvents.EventMsg;
	BEGIN
		vyCommandMenus.Add( l, ListInspect, "Inspect" );  vyCommandMenus.Add( l, ListAttributes, "View Attributes" );
		vyCommandMenus.Add( l, ListView, "View as ... " );  Input.Mouse( keys, x, y );
		vyCommandMenus.ExecuteListedCommand( x, y, event, l )
	END ListList;

	PROCEDURE EnumLinks( CONST name: ARRAY OF CHAR );
	BEGIN
		NEW( curlinklist.next );  curlinklist := curlinklist.next;  Links.GetLink( currobj, name, curlinklist.obj );
		curlinklist.host := currobj;  COPY( name, curlinklist.name )
	END EnumLinks;

	PROCEDURE MakeLinkList*;
	VAR l: vyLinks.Link;  msg: Objects.LinkMsg;
	BEGIN
		aM.vS( "antsObjects.MakeLinkList; results in antsObjects.curlinklist" );  l := vyBase.GetLastInThread( vyBase.currentThread );  NEW( linklist );  curlinklist := linklist;
		WHILE (l # NIL ) DO
			IF l.obj # NIL THEN
				currobj := l.obj;  msg.id := Objects.enum;  msg.Enum := EnumLinks;
				IF currobj.handle # NIL THEN currobj.handle( currobj, msg ) END;
			END;
			l := l.link
		END
	END MakeLinkList;

	PROCEDURE DoFindContext( obj: Objects.Object;  objname: ARRAY OF CHAR;  up, down: BOOLEAN );
	VAR name: ARRAY 256 OF CHAR;
		list: tlinkList;
	BEGIN
		aM.dSS( "antsObjects: Finding Context ------ ", objname );  list := linklist.next;
		WHILE (list # NIL ) DO
			IF list.host = obj THEN
				IF down THEN aM.dSS( "antsObjects: >>> ", list.name );  DoFindContext( list.obj, list.name, FALSE , TRUE ) END
			ELSIF list.obj = obj THEN
				IF up THEN
					Attributes.GetString( list.host, "Name", name );  aM.dSS( "antsObjects: <<<", name );  aM.dSS( "antsObjects: -as- ", list.name );
					DoFindContext( list.host, name, TRUE , FALSE )
				END
			END;
			list := list.next
		END
	END DoFindContext;

	PROCEDURE FindContext*;
	VAR obj: vyBase.Object;
	BEGIN
		aM.vS( "antsObjects.FindContext, set messages to debug mode to watch." );  antsCommands.InitScan( "object=OBJ" );
		IF antsCommands.ExpectObject( "object", obj ) THEN MakeLinkList();  DoFindContext( obj, "root", TRUE , TRUE ) END
	END FindContext;

	PROCEDURE TempHandle( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	BEGIN
		IF msg IS Display.FrameMsg THEN
			WITH msg: Display.FrameMsg DO found := TRUE
			END;
		ELSE
		END
	END TempHandle;

	PROCEDURE WriteObject( VAR w: Texts.Writer;  o: Objects.Object );
	VAR obj, TF, model: Objects.Object;
		name, gen, timestamp: ARRAY 64 OF CHAR;
		id: LONGINT;
		class: ARRAY 64 OF CHAR;
		t: Types.Type;
	BEGIN
		obj := Gadgets.CreateObject( "RefGadgets.NewFrame" );
		IF o.handle # NIL THEN Links.SetLink( obj, "Value", o );  Links.SetLink( obj, "Model", o ) END;
		Attributes.SetString( obj, "Cmd", "antsObjects.ListList" );  Texts.WriteObj( w, obj );  obj.lib := o.lib;

		IF o.handle = NIL THEN
			name := "NO HANDLER";  gen := "NO HANDLER:";  timestamp := "";  id := 0;  model := NIL;
			IF o IS vyBase.Object THEN vyName.AppendObjId( o( vyBase.Object ), gen ) END
		ELSE

			Attributes.GetString( o, "Name", name );  Attributes.GetString( o, "Gen", gen );  Attributes.GetString( o, "TimeStamp", timestamp );
			Attributes.GetInt( o, "ObjectId", id );

			model := BasicModel( o, "Name", class )
		END;
		TF := Gadgets.CreateObject( "TextFields.NewTextField" );  Links.SetLink( TF, "Model", model );  Links.SetLink( TF, "Value", o );  TF.lib := o.lib;
		TF( Gadgets.Frame ).W := 130;  TF( Gadgets.Frame ).H := 20;  Texts.WriteObj( w, TF );  Texts.Write( w, 09X );
		Texts.WriteString( w, gen );  Texts.Write( w, 09X );  t := Types.TypeOf( o );
		IF t # NIL THEN Texts.WriteString( w, t.mod.name );  Texts.WriteString( w, "." );  Texts.WriteString( w, t.name );  END;
		Texts.Write( w, 09X );  Texts.WriteInt( w, id, 5 );  Texts.Write( w, 09X );  Texts.WriteInt( w, ADDRESSOF( o.lib^ ), 5 );
		Texts.Write( w, 09X );  Texts.WriteString( w, timestamp );

		Texts.WriteLn( w )
	END WriteObject;

	PROCEDURE UpdateT( t: Oberon.Task );
	VAR time: LONGINT;  f: Display.Frame;  orighandle: Objects.Handler;  msg: Display.FrameMsg;  l: vyLinks.Link;  w: Texts.Writer;

	BEGIN
		WITH t: UpdateTask DO
			time := Oberon.Time();
			IF t.nexttime - time < 0 THEN Texts.OpenWriter( w );

				f := t.D;  orighandle := f.handle;  f.handle := TempHandle;  found := FALSE;
				msg.F := f;   (* msg.device := Display.screen;  msg.id := Display.full;  *) msg.res := -1;  Display.Broadcast( msg );
				f.handle := orighandle;
				IF ~found THEN aM.vS( "antsObjects: Objects-Document closed " );  Oberon.Remove( t );  RETURN END;

				t.nexttime := time + Input.TimeUnit;   (* one second to wait *)  t.time := t.nexttime;
				l := vyBase.GetLastInThread( vyBase.currentThread );
				IF t.l # l THEN
					WHILE (l # NIL ) & (l # t.l) DO WriteObject( w, l.obj );  l := l.link END;
					aM.vS( "antsObjects: new object in base" );  t.l := vyBase.GetLastInThread( vyBase.currentThread )
				END;
				Texts.Insert( t.t, t.pos, w.buf )
			END
		END
	END UpdateT;

	PROCEDURE ListBaseObjects*;
	VAR l: vyLinks.Link;  t: Texts.Text;  D: Documents.Document;  w: Texts.Writer;  s: TextGadgets.Style;  task: UpdateTask;
	BEGIN
		aM.vS( "antsObjects.ListBaseObjects, viewing current objects." );  D := Documents.Open( "CurrentObjects" );
		IF (D # NIL ) & (D.dsc # NIL ) & (D.dsc IS TextGadgets.Frame) THEN
			Desktops.ShowDoc( D );  t := D.dsc( TextGadgets.Frame ).text;  Texts.OpenWriter( w );

			s := TextGadgets.newStyle();  Attributes.SetString( s, "Tabs", "200,400,600,650" );  Attributes.SetInt( s, "Width", 1000 );
			l := vyBase.GetLastInThread( vyBase.currentThread );  NEW( task );  Texts.WriteObj( w, s );  Texts.WriteString( w, "Name" );
			Texts.Write( w, 09X );  Texts.WriteString( w, "Generator" );  Texts.Write( w, 09X );  Texts.WriteString( w, "Type" );
			Texts.Write( w, 09X );  Texts.WriteString( w, "IdNr" );  Texts.Write( w, 09X );  Texts.WriteString( w, "Lib" );
			Texts.Write( w, 09X );  Texts.WriteString( w, "TimeStamp" );  Texts.WriteLn( w );  Texts.WriteLn( w );  Texts.Append( t, w.buf );
			task.pos := t.len;
			WHILE l # NIL DO
				IF l.obj # NIL THEN WriteObject( w, l.obj ) END;
				l := l.link
			END;
			Texts.Append( t, w.buf );
			(*Attributes.SetBool(D.dsc,"Locked",TRUE); *)
			task.nexttime := Oberon.Time();  task.D := D;  task.t := t;  task.l := vyBase.GetLastInThread( vyBase.currentThread );
			task.handle := UpdateT;  task.time := Oberon.Time();  Oberon.Install( task )
		END
	END ListBaseObjects;

	PROCEDURE ListThese*;
	VAR l: vyLinks.Link;  t: Texts.Text;  D: Documents.Document;  w: Texts.Writer;  s: TextGadgets.Style;  gobj: Objects.Object;
	BEGIN
		gobj := Gadgets.executorObj;  D := Documents.Open( "ObjectsInContext" );
		IF (D # NIL ) & (D.dsc # NIL ) & (D.dsc IS TextGadgets.Frame) THEN
			Desktops.ShowDoc( D );  t := D.dsc( TextGadgets.Frame ).text;  Texts.OpenWriter( w );

			s := TextGadgets.newStyle();  Attributes.SetString( s, "Tabs", "200,350,400" );  Attributes.SetInt( s, "Width", 1000 );
			l := vyBase.GetLastInThread( vyBase.currentThread );  Texts.WriteObj( w, s );  Texts.WriteString( w, "Name" );
			Texts.Write( w, 09X );  Texts.WriteString( w, "Generator" );  Texts.Write( w, 09X );  Texts.WriteString( w, "IdNr" );
			Texts.Write( w, 09X );  Texts.WriteString( w, "Lib" );  Texts.Write( w, 09X );  Texts.WriteString( w, "TimeStamp" );
			Texts.WriteLn( w );  Texts.WriteLn( w );  Texts.Append( t, w.buf );
			WHILE l # NIL DO
				IF l.obj # NIL THEN
					IF l.obj.lib = gobj.lib THEN WriteObject( w, l.obj ) END
				END;
				l := l.link
			END;
			Texts.Append( t, w.buf )
		END
	END ListThese;

	PROCEDURE NewEmptyObject*;
	VAR obj: vyBase.Object;
		name: ARRAY 256 OF CHAR;
	BEGIN
		antsCommands.InitScan( "name=NAME" );
		IF antsCommands.ExpectName( "name", name ) THEN
			vyBase.NewObj;  obj := Objects.NewObj( vyBase.Object );  vyName.RegisterNamed( obj, name );
			aM.vSS( "antsObjects: created new placeholder object with name", name );
		END
	END NewEmptyObject;

	PROCEDURE Startup*;
	END Startup;


(*
PROCEDURE ":="* (VAR obj: vyBase.Object; name: ARRAY OF CHAR);
BEGIN
obj := vyName.FindObj(name);
END ":=";

PROCEDURE ":="* (VAR  name: ARRAY OF CHAR; obj : vyBase.Object);
BEGIN
vyName.GetObjId(obj,name);
END ":=";

PROCEDURE "+"* (name: vyName.tNameArray; obj: vyBase.Object): vyName.tNameArray;
BEGIN
vyName.AppendObjId(obj,name); RETURN name;
END "+";
*)

BEGIN
	aM.launch;  NEW( obj );  obj.handle := Handler;  Gen;  vyName.RegisterNamed( obj, "antsObjects" );  obj.all := NIL;
	(*
	vyRanParksMiller.Install(); (* global initialization of random generator, use gen IN all procedures.*)
	gen := vyRanBase.RandomGenerator;
	*)
	(* antsSecurity.Init; *) antsToolbox.Launch;
END antsObjects.

antsObjects.vyObjects ~

antsObjects.UnSubscribe > in model > source sampler ~

antsObjects.TextField testf Mapping ~
antsObjects.AllFields testf ~

antsFunctions.Define > name testf ~

System.Free antsFunctions * ~
Voyager.Show testf as antsFctEdit ~
System.Free antsObjectView

ants / antsFunctions.Mod

System.Free antsObjects ~
antsObjects.ListBaseObjects ~

antsObjects.FindContext f3Chain ~

Voyager.Show >debug ants as antsDependency
antsDependency.Show ants >debug ~
