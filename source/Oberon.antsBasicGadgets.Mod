MODULE antsBasicGadgets IN Oberon;   (** fof  **)
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




IMPORT BasicGadgets, Objects, Gadgets, Links, aM := antsMessages;

VAR
	valchanged: BOOLEAN;

	PROCEDURE NewInteger*;
	BEGIN
		aM.dS( "antsBasicGadgets.NewInteger" );  BasicGadgets.NewInteger();  Objects.NewObj.handle := Handler
	END NewInteger;

	PROCEDURE NewBoolean*;
	BEGIN
		aM.dS( "antsBasicGadgets.NewBoolean" );  BasicGadgets.NewBoolean();  Objects.NewObj.handle := Handler
	END NewBoolean;

	PROCEDURE NewReal*;
	BEGIN
		aM.dS( "antsBasicGadgets.NewReal" );  BasicGadgets.NewReal();  Objects.NewObj.handle := Handler
	END NewReal;

	PROCEDURE NewString*;
	BEGIN
		aM.dS( "antsBasicGadgets.NewString" );  BasicGadgets.NewString();  Objects.NewObj.handle := Handler
	END NewString;

	PROCEDURE GetObjectName( m: Objects.Object;  VAR name: ARRAY OF CHAR );
	VAR amsg: Objects.AttrMsg;
	BEGIN
		amsg.id := Objects.get;  amsg.name := "Name";  amsg.res := -1;  m.handle( m, amsg );  COPY( amsg.s, name )
	END GetObjectName;

	PROCEDURE Handler*( obj: Objects.Object;  VAR M: Objects.ObjMsg );
	VAR model: Objects.Object;
		name: ARRAY 256 OF CHAR;
		attrmsg: Objects.AttrMsg;
	BEGIN
		IF M IS Objects.AttrMsg THEN
			WITH M: Objects.AttrMsg DO
				IF M.id = Objects.get THEN
					IF M.name = "Gen" THEN
						IF obj IS BasicGadgets.Integer THEN
							WITH obj: BasicGadgets.Integer DO COPY( "antsBasicGadgets.NewInteger", M.s );
							END;
						ELSIF obj IS BasicGadgets.Real THEN
							WITH obj: BasicGadgets.Real DO COPY( "antsBasicGadgets.NewReal", M.s );
							END;
						ELSIF obj IS BasicGadgets.String THEN
							WITH obj: BasicGadgets.String DO COPY( "antsBasicGadgets.NewString", M.s );
							END;
						ELSIF obj IS BasicGadgets.Boolean THEN
							WITH obj: BasicGadgets.Boolean DO COPY( "antsBasicGadgets.NewBoolean", M.s )
							END;
						END;
						M.class := Objects.String;  M.res := 0;  RETURN
					ELSIF M.name = "Value" THEN  (* get value procedure for all standard visual gadgets *)
						Links.GetLink( obj, "antsModel", model );   (* get father model *)
						GetObjectName( obj, M.name );   (* set object name Name to Value Name *)
						IF (model # NIL ) & (model.handle # NIL ) THEN
							model.handle( model, M );   (* handle attribute get message on model i/o this object*)
						ELSE aM.eSS( "Problem with model of", M.name );  aM.eS( "That often happens, when some object could not be loaded" );  aM.eS( "Check if module is compiled, new symbol file of import ??" );
						END;
						IF M.res >= 0 THEN  (* set value to this model, for consistency and for standard gadgets *)
							IF obj IS BasicGadgets.Integer THEN
								WITH obj: BasicGadgets.Integer DO
									IF obj.val = M.i THEN valchanged := FALSE ELSE obj.val := M.i;  END;
								END;
							ELSIF obj IS BasicGadgets.Real THEN
								WITH obj: BasicGadgets.Real DO
									IF obj.val = M.y THEN valchanged := FALSE ELSE obj.val := M.y;  END;
								END;
							ELSIF obj IS BasicGadgets.Boolean THEN
								WITH obj: BasicGadgets.Boolean DO
									IF obj.val = M.b THEN valchanged := FALSE ELSE obj.val := M.b;  END;
								END;
							ELSIF obj IS BasicGadgets.String THEN
								WITH obj: BasicGadgets.String DO
									IF obj.val = M.s THEN valchanged := FALSE ELSE COPY( M.s, obj.val );  aM.dSS( "antsBasicGadgets: newval = ", M.s ) END
								END;
							END
						END;
						obj.stamp := -1;  RETURN
					END
				ELSIF M.id = Objects.set THEN  (* set value procedure must be handled by either this object and antsModel of it *)
					GetObjectName( obj, name );   (* get object name for identification of set in model. object name is value name in antsModel*)
					IF (M.name = "Value") OR (M.name = name) THEN  (* Checkbox writes to Field named by Name entry *)
						M.name := "Value";
						Links.GetLink( obj, "antsModel", model );   (* get father model *)
						IF obj IS BasicGadgets.Integer THEN
							WITH obj: BasicGadgets.Integer DO
								BasicGadgets.IntegerHandler( obj, M );  COPY( name, M.name );  M.id := Objects.set;  M.class := Objects.Int;
								M.i := obj.val;  model.handle( model, M );  aM.vSI( "antsBasicGadgets: newval = ", M.i );

							END;
						ELSIF obj IS BasicGadgets.Real THEN
							WITH obj: BasicGadgets.Real DO
								BasicGadgets.RealHandler( obj, M );  COPY( name, M.name );  M.id := Objects.set;
								M.class := Objects.LongReal;  M.y := obj.val;  model.handle( model, M );  aM.vSR( "antsBasicGadgets: newval = ", M.y );

							END;
						ELSIF obj IS BasicGadgets.Boolean THEN
							WITH obj: BasicGadgets.Boolean DO
								BasicGadgets.BooleanHandler( obj, M );  COPY( name, M.name );  M.res := -1;  M.id := Objects.set;
								M.class := Objects.Bool;  M.b := obj.val;  model.handle( model, M );  aM.vSB( "antsBasicGadgets: newval = ", M.b );

							END;
						ELSIF obj IS BasicGadgets.String THEN
							WITH obj: BasicGadgets.String DO
								BasicGadgets.StringHandler( obj, M );  COPY( name, M.name );  M.id := Objects.set;
								M.class := Objects.String;  COPY( obj.val, M.s );  model.handle( model, M );  aM.vSS( "antsBasicGadgets: newval = ", M.s );

							END;
						END;
						RETURN
					ELSIF M.name = "Name" THEN
					END
				END;

				(*! get and set seems to be ok but update messages are too global now *)
			END;
		ELSIF M IS Gadgets.UpdateMsg THEN
			WITH M: Gadgets.UpdateMsg DO
				Links.GetLink( obj, "antsModel", model );
				IF M.obj = model THEN
					valchanged := TRUE;  attrmsg.name := "Value";  attrmsg.id := Objects.get;  obj.handle( obj, attrmsg );
					IF valchanged THEN Gadgets.Update( obj ) END
				END
			END;
		ELSIF M IS Objects.CopyMsg THEN
			WITH M: Objects.CopyMsg DO
				IF obj IS BasicGadgets.Integer THEN
					WITH obj: BasicGadgets.Integer DO BasicGadgets.IntegerHandler( obj, M );
					END;
				ELSIF obj IS BasicGadgets.Real THEN
					WITH obj: BasicGadgets.Real DO BasicGadgets.RealHandler( obj, M );
					END;
				ELSIF obj IS BasicGadgets.String THEN
					WITH obj: BasicGadgets.String DO BasicGadgets.StringHandler( obj, M );
					END;
				ELSIF obj IS BasicGadgets.Boolean THEN
					WITH obj: BasicGadgets.Boolean DO BasicGadgets.BooleanHandler( obj, M )
					END;
				END;
				Links.GetLink( obj, "antsModel", model );  Links.SetLink( M.obj, "antsModel", model );  RETURN
			END;
		ELSE
		END;
		IF obj IS BasicGadgets.Integer THEN
			WITH obj: BasicGadgets.Integer DO BasicGadgets.IntegerHandler( obj, M );
			END;
		ELSIF obj IS BasicGadgets.Real THEN
			WITH obj: BasicGadgets.Real DO BasicGadgets.RealHandler( obj, M );
			END;
		ELSIF obj IS BasicGadgets.String THEN
			WITH obj: BasicGadgets.String DO BasicGadgets.StringHandler( obj, M );
			END;
		ELSIF obj IS BasicGadgets.Boolean THEN
			WITH obj: BasicGadgets.Boolean DO BasicGadgets.BooleanHandler( obj, M )
			END;
		END
	END Handler;

	PROCEDURE NewModelLinked*( link: Objects.Object;  name: ARRAY OF CHAR );
	(* link model to new basic gadget, basic gadgets name is attribute name of linked model's attribute -> value *)
	VAR amsg: Objects.AttrMsg;  setmsg: Objects.AttrMsg;  linkmsg: Objects.LinkMsg;
	BEGIN
		aM.dS( "antsBasicGadgets.NewModelLinked" );  amsg.id := Objects.get;  COPY( name, amsg.name );  link.handle( link, amsg );
		IF amsg.class = Objects.Int THEN NewInteger
		ELSIF amsg.class = Objects.Real THEN NewReal
		ELSIF amsg.class = Objects.LongReal THEN NewReal
		ELSIF amsg.class = Objects.String THEN NewString
		ELSIF amsg.class = Objects.Bool THEN NewBoolean
		ELSE Objects.NewObj := NIL;  RETURN
		END;

		setmsg.id := Objects.set;  setmsg.class := Objects.String;  COPY( name, setmsg.s );  setmsg.name := "Name";  setmsg.res := -1;
		Objects.NewObj.handle( Objects.NewObj, setmsg );   (* set basic gadgets name to desired attribute name *)
		linkmsg.obj := link;  linkmsg.name := "antsModel";  linkmsg.id := Objects.set;  linkmsg.res := -1;
		Objects.NewObj.handle( Objects.NewObj, linkmsg ) (* set model linked to basic gadget *)
	END NewModelLinked;

BEGIN
	aM.launch;
END antsBasicGadgets.

System.Free antsObjectView antsBasicGadgets ~
