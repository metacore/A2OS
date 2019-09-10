(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE DataStacks;   (** AUTHOR "adf"; PURPOSE "A FILO stack"; *)

IMPORT NbrInt, DataErrors, DataIO;

CONST
	VERSION* = 1;   (*  Version number used when reading/writing an instance of Stack to file. *)

TYPE
	Node = POINTER TO RECORD
		next: Node;
		obj: OBJECT;
	END;

	(** Type Stack is DataIO.PlugIn registered.   The type(s) corresponding to the data inserted into a stack need to
		also be registered via DataIO.PlugIn in order for a stack to be persistent. *)
	Stack* = OBJECT
	VAR len-: NbrInt.Integer;
		root: Node;

		(** Used internally to read data from a file. *)
		PROCEDURE Read*( R: DataIO.Reader );
		VAR i, length: NbrInt.Integer;  p: OBJECT;
		BEGIN {EXCLUSIVE}
			R.Integer( length );
			FOR i := 1 TO length DO R.Object( p );  Push( p ) END
		END Read;

	(** Used internally to write data to a file. *)
		PROCEDURE Write*( W: DataIO.Writer );
		VAR i, k: NbrInt.Integer;  node: Node;
		BEGIN
			W.Integer( len );
			FOR i := len TO 1 BY -1 DO
				k := 1;  node := root;
				(* Extract them out in reverse order so that they can be correctly inserted when read. *)
				WHILE k # i DO NbrInt.Inc( k );  node := node.next END;
				W.Object( node.obj )
			END
		END Write;

	(** Extracts an object from the top of the stack. *)
		PROCEDURE Pop*( VAR obj: OBJECT );
		VAR prev: Node;
		BEGIN
			IF len > 0 THEN obj := root.obj;  prev := root;  root := prev.next;  prev.next := NIL;  prev.obj := NIL;  NbrInt.Dec( len )
			ELSE obj := NIL
			END
		END Pop;

	(** Places an object at the top of the stack. *)
		PROCEDURE Push*( obj: OBJECT );
		VAR node: Node;
		BEGIN
			IF obj # NIL THEN NEW( node );  node.obj := obj;  node.next := root;  root := node;  NbrInt.Inc( len ) END
		END Push;

	END Stack;

	(* The procedures needed to register type Stack so that its instances can be made persistent. *)

	PROCEDURE LoadObj( R: DataIO.Reader;  VAR obj: OBJECT );
	VAR version: SIGNED8;  ver: NbrInt.Integer;  new: Stack;
	BEGIN
		R.RawSInt( version );
		IF version = -1 THEN
			obj := NIL  (* Version tag is -1 for NIL. *)
		ELSE
			IF version = VERSION THEN NEW( new );  new.Read( R );  obj := new
					ELSE  (* Encountered an unknown version number. *)
				ver := version;  DataErrors.IntError( ver, "Alien version number encountered." );  HALT( 1000 )
			END
		END
	END LoadObj;

	PROCEDURE StoreObj( W: DataIO.Writer;  obj: OBJECT );
	VAR old: Stack;
	BEGIN
		IF obj = NIL THEN W.RawSInt( -1 ) ELSE W.RawSInt( VERSION );  old := obj( Stack );  old.Write( W ) END
	END StoreObj;

	PROCEDURE Register;
	VAR anInstanceOf: Stack;
	BEGIN
		NEW( anInstanceOf );  DataIO.PlugIn( anInstanceOf, LoadObj, StoreObj )
	END Register;

(** Load and Store are procedures for external use that read/write an instance of Stack from/to a file. *)
	PROCEDURE Load*( R: DataIO.Reader;  VAR obj: Stack );
	VAR ptr: OBJECT;
	BEGIN
		R.Object( ptr );  obj := ptr( Stack )
	END Load;

	PROCEDURE Store*( W: DataIO.Writer;  obj: Stack );
	BEGIN
		W.Object( obj )
	END Store;

BEGIN
	Register
END DataStacks.