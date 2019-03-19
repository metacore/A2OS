MODULE vyCommandMenus IN Oberon;   (** fof  , functionality from ANTS 020625 **)
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


(* (c)  F.Friedrich *)

IMPORT vyTracking, vyEvents, vyGraphBase, Objects, Strings, vyName, vyBase, Input, vyPortability;

TYPE
	PROC = PROCEDURE;

	List* = POINTER TO ListDesc;
	ListDesc* = RECORD (vyTracking.ListDesc)
		command*: PROC;
		obj*: Objects.Object
	END;

	enumProc* = PROCEDURE ( name: ARRAY OF CHAR;  cmd: PROC;  obj: Objects.Object );

	enumMsg* = RECORD (Objects.ObjMsg)
		Enum*: enumProc;
		EnumSender*: enumProc;
		mode*: INTEGER;
		x*, y*: INTEGER
	END;

CONST
	emptyLine* = "______________________________";  click* = 0;  select* = 1;

VAR
	dynamic*: List;  msg*: enumMsg;  res*: vyTracking.List;  recentx*, recenty*: INTEGER;  noWait*: BOOLEAN;  current*: List;
	currentmode*: INTEGER;

	PROCEDURE GetCopy( l: List ): List;
	VAR new, temp, t: List;
	BEGIN
		NEW( new );  temp := new;  temp.command := l.command;  COPY( l.name, temp.name );  temp.obj := l.obj;
		IF l.next # NIL THEN l := l.next( List ) ELSE l := NIL END;
		WHILE (l # NIL ) DO
			NEW( t );  temp.next := t;  temp := t;  temp.command := l.command;  temp.obj := l.obj;  COPY( l.name, temp.name );
			IF l.next # NIL THEN l := l.next( List ) ELSE l := NIL END
		END;
		RETURN new
	END GetCopy;

	PROCEDURE Add*( VAR l: List;  command: PROC;  name: ARRAY OF CHAR );
	VAR newl, oldl: List;
	BEGIN
		oldl := l;
		IF l = NIL THEN NEW( l );  l.command := command;  COPY( name, l.name ) ELSE
			WHILE oldl.next # NIL DO oldl := oldl.next( List ) END;
			NEW( newl );  oldl.next := newl;  newl.command := command;  COPY( name, newl.name )
		END
	END Add;

	PROCEDURE Prev( VAR l: List;  command: PROC;  name: ARRAY OF CHAR );
	VAR list: List;
	BEGIN
		NEW( list );  list.command := command;  COPY( name, list.name );  list.next := l;  l := list
	END Prev;

	PROCEDURE AddGeneric( name: ARRAY OF CHAR;  cmd: PROC;  obj: Objects.Object );
	BEGIN
		Prev( dynamic, cmd, name )
	END AddGeneric;

	PROCEDURE AddSender( name: ARRAY OF CHAR;  cmd: PROC;  obj: Objects.Object );
	VAR objname, temp: ARRAY 128 OF CHAR;
	BEGIN
		objname := "______(";
		IF (name = "") & (obj # NIL ) THEN
			IF obj IS vyBase.Object THEN
				WITH obj: vyBase.Object DO vyName.GetObjId( obj, temp )
				END;
			ELSE
			END
		ELSE COPY( name, temp )
		END;
		Strings.Append( objname, temp );  Strings.Append( objname, ")______" );
		IF temp = "" THEN objname := emptyLine END;
		Prev( dynamic, cmd, objname )
	END AddSender;

	PROCEDURE Init*( VAR l: List;  atx, aty: INTEGER );
	BEGIN
		msg.Enum := AddGeneric;  msg.EnumSender := AddSender;
		IF l # NIL THEN dynamic := GetCopy( l ) ELSE dynamic := NIL END;
		msg.x := atx;  msg.y := aty
		(* AddGeneric("- - - - - - - - - - - - -",nothing,NIL);  *)
	END Init;

	PROCEDURE Ask*( obj: Objects.Object );
	BEGIN
		IF obj # NIL THEN
			IF obj.handle # NIL THEN obj.handle( obj, msg ) END
		END
	END Ask;

	PROCEDURE Wait*;
	VAR keys: SET;  x, y: INTEGER;
	BEGIN
		IF noWait THEN RETURN END;
		Input.Mouse( keys, x, y );
		WHILE (keys # {}) DO
			Input.Mouse( keys, x, y );
			IF ~vyPortability.DisplayAvailable() THEN  (* Display not available*) RETURN END
		END

	END Wait;

	PROCEDURE ExecuteListedCommand*( atx, aty: INTEGER;  VAR event: vyEvents.EventMsg;  from: List );
	BEGIN
		noWait := FALSE;
		IF from = NIL THEN RETURN END;
		vyGraphBase.SetStyle( vyGraphBase.defaultStyle );  vyTracking.ScrollList( from, atx, aty, res );
		(* Input.Mouse(keys,x,y); WHILE (keys#{}) DO Input.Mouse(keys,x,y); END; *)
		recentx := atx;  recenty := aty;
		IF res # NIL THEN
			IF res( List ).command # NIL THEN res( List ).command() END
		END
	END ExecuteListedCommand;

	PROCEDURE Execute*( atx, aty: INTEGER );
	VAR event: vyEvents.EventMsg;
	BEGIN
		ExecuteListedCommand( atx, aty, event, dynamic )
	END Execute;

END vyCommandMenus.
