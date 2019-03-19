MODULE antsHybridObjects IN Oberon;   (**  AUTHOR "fof"; PURPOSE "";  **)

IMPORT vyBase, Objects, Files, aM := antsMessages, Modules IN A2, Types, Strings, Gadgets, antsObjects, vyName;

TYPE
	(* do bind with enumeration, do links with enumeration, do attributes with enumeration *)

	Object* = OBJECT (vyBase.Object)

		PROCEDURE Generator*( VAR name: ARRAY OF CHAR );
		VAR type: Modules.TypeDesc;  commandname: Modules.Name;  command: PROCEDURE;
		BEGIN
			(*trying to guess a name for the generator, standardname: <Modulename>.Gen<TypeName>*)
			type := Types.TypeOf( SELF );  commandname := "Gen";  Strings.Append( commandname, type.name );

			COPY( type.mod.name, name );  Strings.Append( name, "." );  Strings.Append( name, commandname );
			GETPROCEDURE ( type.mod.name, commandname, command);
			IF command = NIL THEN
				aM.eSS( "antsHybridObjects: Failed to find standard generator procedure ", name );  COPY( type.mod.name, name );  Strings.Append( name, "." );  Strings.Append( name, type.name );
				Strings.Append( name, ".Generator(VAR name: ARRAY OF CHAR)" );  aM.eSS( "Please provide this procedure or implement ", name );  COPY( "", name );
			ELSE aM.dSS( "Generator  = ", name );
			END;


		END Generator;

		PROCEDURE & Init*;
		VAR objname: ARRAY 256 OF CHAR;
			type: Modules.TypeDesc;
		BEGIN
			Generator( objname );
			IF objname # "" THEN aM.vSS( "Installing object with generator", objname );  END;
			SELF.handle := HybridObjectHandler;  antsObjects.Register( SELF );
		END Init;

		PROCEDURE Attributes*( VAR M: Objects.AttrMsg );
		END Attributes;

		PROCEDURE Links*( VAR M: Objects.LinkMsg );
		END Links;

		PROCEDURE Store*( VAR R: Files.Rider );
		END Store;

		PROCEDURE Load*( VAR R: Files.Rider );
		END Load;

		PROCEDURE BindObj*( VAR M: Objects.BindMsg;  o: vyBase.Object );
		BEGIN
			WITH M: Objects.BindMsg DO
				IF (o # NIL ) & (M.lib # o.lib) THEN
					Gadgets.BindObj( o, M.lib );
					IF o.handle # NIL THEN o.handle( o, M ) END
				END
			END;
		END BindObj;

		PROCEDURE Bind*( VAR M: Objects.BindMsg );
		END Bind;

		PROCEDURE Update*;
		END Update;

	END Object;
		PROCEDURE HybridObjectHandler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	BEGIN
		WITH o: Object DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					vyBase.objecthandle( o, M );  o.Attributes( M );
					IF M.id = Objects.enum THEN M.Enum( "Gen" );
					ELSIF M.id = Objects.get THEN
						IF M.name = "Gen" THEN o.Generator( M.s );  M.class := Objects.String;  M.res := 0 END;
					END;
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					IF M.id = Objects.load THEN vyBase.objecthandle( o, M );  o.Load( M.R )
					ELSIF M.id = Objects.store THEN vyBase.objecthandle( o, M );  o.Store( M.R )
					END;
				END;
			ELSIF M IS Objects.LinkMsg THEN
				WITH M: Objects.LinkMsg DO o.Links( M );  vyBase.objecthandle( o, M );
				END;
			ELSIF M IS Objects.BindMsg THEN
				WITH M: Objects.BindMsg DO
					IF o.lib # M.lib THEN vyBase.objecthandle( o, M );  o.Bind( M ) END;
				END;
			ELSIF M IS vyBase.UpdateMessage THEN
				WITH M: vyBase.UpdateMessage DO o.Update;  vyBase.Update( o )
				END;
			ELSE vyBase.objecthandle( o, M )
			END
		END
	END HybridObjectHandler;


	PROCEDURE Test*;
	VAR o: Object;
	BEGIN
		NEW( o );  vyName.RegisterNamed( o, "testobj" );
	END Test;

(**
		PROCEDURE GenObject*;
		VAR o: Object;
		BEGIN
			NEW(o); Objects.NewObj := o;
		END GenObject;
*)

END antsHybridObjects.

antsHybridObjects.Test ~
antsMessages.SetMode verbose ~
antsObjects.ListBaseObjects ~~

