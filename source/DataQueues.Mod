(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE DataQueues;   (** AUTHOR "adf"; PURPOSE "A FIFO queue."; *)

IMPORT NbrInt, DataErrors, DataIO;

CONST
	VERSION* = 1;   (*  Version number used when reading/writing an instance of Queue to file. *)

TYPE
	Node = POINTER TO RECORD
		prev: Node;
		obj: OBJECT;
	END;

	(** Type Queue is DataIO.PlugIn registered.   The type(s) corresponding to the data inserted into a queue need to
	also be registered via DataIO.PlugIn in order for the whole queue to be persistent. *)
TYPE
	Queue* = OBJECT
	VAR len-: NbrInt.Integer;
		first, last: Node;

		(** Used internally to read data from a file. *)
		PROCEDURE Read*( R: DataIO.Reader );
		VAR i, length: NbrInt.Integer;  p: OBJECT;
		BEGIN {EXCLUSIVE}
			R.Integer( length );
			FOR i := 1 TO length DO R.Object( p );  Push( p ) END
		END Read;

	(** Used internally to write data to a file. *)
		PROCEDURE Write*( W: DataIO.Writer );
		VAR i: NbrInt.Integer;  node: Node;
		BEGIN
			W.Integer( len );  node := last;
			FOR i := 1 TO len DO W.Object( node.obj );  node := node.prev END
		END Write;

	(** Extracts an object from the bottom of the queue. *)
		PROCEDURE Pop*( VAR obj: OBJECT );
		VAR next: Node;
		BEGIN
			IF len > 0 THEN
				obj := last.obj;  last.obj := NIL;
				IF len > 1 THEN next := last;  last := next.prev;  next.prev := NIL ELSE first := NIL;  last := NIL END;
				NbrInt.Dec( len )
			ELSE obj := NIL
			END
		END Pop;

	(** Places an object at the top of the queue. *)
		PROCEDURE Push*( obj: OBJECT );
		VAR node: Node;
		BEGIN
			NEW( node );  node.obj := obj;
			IF first = NIL THEN first := node;  last := node ELSE first.prev := node;  first := node END;
			NbrInt.Inc( len )
		END Push;

	END Queue;

	(* The procedures needed to register type Queue so that its instances can be made persistent. *)

	PROCEDURE LoadObj( R: DataIO.Reader;  VAR obj: OBJECT );
	VAR version: SIGNED8;  ver: NbrInt.Integer;  new: Queue;
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
	VAR old: Queue;
	BEGIN
		IF obj = NIL THEN W.RawSInt( -1 ) ELSE W.RawSInt( VERSION );  old := obj( Queue );  old.Write( W ) END
	END StoreObj;

	PROCEDURE Register;
	VAR anInstanceOf: Queue;
	BEGIN
		NEW( anInstanceOf );  DataIO.PlugIn( anInstanceOf, LoadObj, StoreObj )
	END Register;

(** Load and Store are procedures for external use that read/write an instance of Queue from/to a file. *)
	PROCEDURE Load*( R: DataIO.Reader;  VAR obj: Queue );
	VAR ptr: OBJECT;
	BEGIN
		R.Object( ptr );  obj := ptr( Queue )
	END Load;

	PROCEDURE Store*( W: DataIO.Writer;  obj: Queue );
	BEGIN
		W.Object( obj )
	END Store;

BEGIN
	Register
END DataQueues.