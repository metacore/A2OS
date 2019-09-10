(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE DataLists;   (** AUTHOR "adf"; PURPOSE "Linked list for storing Data.Datum"; *)

IMPORT NbrInt, DataErrors, DataIO, Data;

CONST
	SHALLOW = 10;  DEEP = 11;
	(** The version used when reading/writing a list to file. *)
	VERSION* = 1;

TYPE
	Node = OBJECT
	VAR prev, next: Node;
		datum: Data.Datum;

		PROCEDURE & Initialize*;
		BEGIN
			prev := NIL;  next := NIL;  datum := NIL
		END Initialize;

		PROCEDURE Attach( datum: Data.Datum;  depth: NbrInt.Integer );
		BEGIN
			IF depth = SHALLOW THEN SELF.datum := datum
			ELSIF depth = DEEP THEN datum.Copy( SELF.datum )
			END
		END Attach;

	END Node;

	(** Used to navigate a list for the purpose of extracting and updating information. *)
	Rider* = OBJECT
	VAR home, node: Node;
		(** Is the rider is at the end-of-list? *)
		eol-: BOOLEAN;

		PROCEDURE & Initialize*;
		BEGIN
			home := NIL;  node := NIL;  eol := TRUE
		END Initialize;

	(** Moves the rider to its default position. *)
		PROCEDURE Home*;
		BEGIN
			IF home # NIL THEN
				BEGIN {EXCLUSIVE}
					node := home;
					IF node.next = NIL THEN eol := TRUE ELSE eol := FALSE END
				END
			END
		END Home;

	(** Decrements the position of the rider by 1, unless it is at home. *)
		PROCEDURE Previous*;
		BEGIN
			IF node # NIL THEN
				BEGIN {EXCLUSIVE}
					IF node.prev # NIL THEN node := node.prev;  eol := FALSE END
				END
			END
		END Previous;

	(** Increments the position of the rider by 1, unless it is at the end-of-list. *)
		PROCEDURE Next*;
		BEGIN
			IF node # NIL THEN
				IF node.next # NIL THEN
					BEGIN {EXCLUSIVE}
						node := node.next;
						IF node.next = NIL THEN eol := TRUE END
					END
				END
			END
		END Next;

	(** Returns a copy of the datum held by the list at the rider's current position. *)
		PROCEDURE Get*( ): Data.Datum;
		VAR datum: Data.Datum;
		BEGIN
			IF node # NIL THEN
				IF node.datum # NIL THEN node.datum.Copy( datum ) ELSE datum := NIL END
			ELSE datum := NIL
			END;
			RETURN datum
		END Get;

	(** Returns a pointer to the datum held by the list at the rider's current position. *)
		PROCEDURE Inspect*( ): Data.Datum;
		BEGIN
			IF node # NIL THEN RETURN node.datum ELSE RETURN NIL END
		END Inspect;

		PROCEDURE Find( key: Data.Key;  VAR found: BOOLEAN );
		(* Call Find from within an EXCLUSIVE block. *)
		VAR saveEol: BOOLEAN;  testDatum: Data.Datum;  saveNode: Node;
		BEGIN
			saveNode := node;  saveEol := eol;  NEW( testDatum );  testDatum.SetKey( key );
			IF node # NIL THEN
				IF testDatum < saveNode.datum THEN
					IF testDatum < home.datum THEN found := FALSE
					ELSIF testDatum = home.datum THEN found := TRUE
					ELSE
						node := home;
						REPEAT node := node.next UNTIL testDatum <= node.datum;
						IF testDatum = node.datum THEN found := TRUE ELSE found := FALSE END
					END
				ELSIF testDatum = saveNode.datum THEN found := TRUE
				ELSE
					LOOP
						node := node.next;
						IF node = NIL THEN found := FALSE;  EXIT END;
						IF testDatum < node.datum THEN found := FALSE;  EXIT END;
						IF testDatum = node.datum THEN found := TRUE;  EXIT END
					END
				END
			ELSE found := FALSE
			END;
			IF found THEN
				IF node.next = NIL THEN eol := TRUE ELSE eol := FALSE END
			ELSE node := saveNode;  eol := saveEol
			END
		END Find;

	(** Extracts a copy of that datum with key 'key', provided it exists; otherwise NIL is returned. *)
		PROCEDURE Retrieve*( key: Data.Key ): Data.Datum;
		VAR found: BOOLEAN;
		BEGIN {EXCLUSIVE}
			Find( key, found );
			IF found THEN RETURN Get() ELSE RETURN NIL END
		END Retrieve;

	(** Exchanges a datum held by the list with that of new, provided their keys are equal. *)
		PROCEDURE Update*( new: Data.Datum;  VAR successful: BOOLEAN );
		VAR key: Data.Key;
		BEGIN
			IF new # NIL THEN new.GetKey( key );
				BEGIN {EXCLUSIVE}
					Find( key, successful );
					IF successful THEN new.Copy( node.datum ) END
				END
			ELSE successful := FALSE
			END
		END Update;

	END Rider;

	(** Type List is a double-linked list that is DataIO.PlugIn registered, i.e., it is persistent. *)
	List* = OBJECT
	VAR len-: NbrInt.Integer;
		rider-: Rider;

		PROCEDURE & Initialize*;
		BEGIN
			(* Intialize the local data. *)
			len := 0;  NEW( rider )
		END Initialize;

		PROCEDURE Copy*( VAR copy: List );
		VAR i: NbrInt.Integer;  prev, new, old: Node;  obj: List;
		BEGIN
			NEW( copy );
			(* Make a deep copy of the local data to 'copy'. *)
			copy.len := len;
			IF len > 0 THEN
				old := rider.home;  NEW( new );  new.Attach( old.datum, DEEP );  copy.rider.home := new;  copy.rider.node := new;
				prev := new;  i := 1;
				WHILE i < len DO
					old := old.next;  NEW( new );  new.Attach( old.datum, DEEP );  prev.next := new;  new.prev := prev;  prev := new;
					NbrInt.Inc( i )
				END
			END;
			obj.rider.Home
		END Copy;

		PROCEDURE Read*( R: DataIO.Reader );
		VAR i: NbrInt.Integer;  prev, new: Node;  datum: Data.Datum;  obj: OBJECT;
		BEGIN
			R.Integer( len );  NEW( rider );
			IF len > 0 THEN
				R.Object( obj );  datum := obj( Data.Datum );  NEW( new );  new.Attach( datum, SHALLOW );  rider.home := new;
				rider.node := new;  prev := new;
				FOR i := 2 TO len DO
					R.Object( obj );  datum := obj( Data.Datum );  NEW( new );  new.Attach( datum, SHALLOW );  prev.next := new;
					new.prev := prev;  prev := new
				END
			ELSE  (* This list is empty. *)
			END;
			rider.Home
		END Read;

		PROCEDURE Write*( W: DataIO.Writer );
		VAR i: NbrInt.Integer;  node: Node;
		BEGIN
			W.Integer( len );  node := rider.home;
			FOR i := 1 TO len DO W.Object( node.datum );  node := node.next END
		END Write;

	(** Attempts to remove an existing datum with identifier  key  from the list. *)
		PROCEDURE Delete*( key: Data.Key;  VAR successful: BOOLEAN );
		VAR prev, remove, next: Node;
		BEGIN {EXCLUSIVE}
			rider.Find( key, successful );
			IF successful THEN
				remove := rider.node;  prev := remove.prev;  next := remove.next;
				(* Extract the node. *)
				IF len = 1 THEN rider.home := NIL;  rider.node := NIL;  rider.eol := TRUE ELSE
					IF prev = NIL THEN next.prev := NIL;  rider.home := next
					ELSIF next = NIL THEN prev.next := NIL
					ELSE prev.next := next;  next.prev := prev
					END
				END;
				NbrInt.Dec( len );
				(* Delete the node. *)
				remove.datum := NIL;  remove.prev := NIL;  remove.next := NIL
			END;
			rider.node := rider.home;
			IF len > 1 THEN rider.eol := FALSE ELSE rider.eol := TRUE END
		END Delete;

	(** Introduces a new  datum  into the list, provided that its key is unique. *)
		PROCEDURE Insert*( datum: Data.Datum;  VAR successful: BOOLEAN );
		VAR prev, new, next: Node;
		BEGIN
			IF datum # NIL THEN
				BEGIN {EXCLUSIVE}
					IF len = 0 THEN
						(* Enter first element into the list. *)
						NEW( new );  new.Attach( datum, DEEP );  rider.home := new;  successful := TRUE
					ELSE
						IF datum < rider.home.datum THEN
							(* Insert the element at the beginning of the list. *)
							NEW( new );  new.Attach( datum, DEEP );  new.next := rider.home;  rider.home.prev := new;
							rider.home := new;  successful := TRUE
						ELSIF datum = rider.home.datum THEN successful := FALSE
						ELSE
							prev := rider.home;
							LOOP
								next := prev.next;
								IF next = NIL THEN
									(* Insert the element at the end of the list. *)
									NEW( new );  new.Attach( datum, DEEP );  prev.next := new;  new.prev := prev;  successful := TRUE;  EXIT
								END;
								IF datum < next.datum THEN
									(* Insert the element into the midsection of the list. *)
									NEW( new );  new.Attach( datum, DEEP );  prev.next := new;  new.prev := prev;  new.next := next;
									next.prev := new;  successful := TRUE;  EXIT
								END;
								IF datum = next.datum THEN successful := FALSE;  EXIT END;
								prev := next
							END
						END
					END;
					IF successful THEN NbrInt.Inc( len ) END
				END
			ELSE successful := FALSE
			END;
			rider.Home
		END Insert;

	END List;


	(* The procedures needed to register type List so that its instances can be made persistent. *)

	PROCEDURE LoadObj( R: DataIO.Reader;  VAR obj: OBJECT );
	VAR version: SIGNED8;  ver: NbrInt.Integer;  new: List;
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
	VAR old: List;
	BEGIN
		IF obj = NIL THEN W.RawSInt( -1 ) ELSE W.RawSInt( VERSION );  old := obj( List );  old.Write( W ) END
	END StoreObj;

	PROCEDURE Register;
	VAR anInstanceOf: List;
	BEGIN
		NEW( anInstanceOf );  DataIO.PlugIn( anInstanceOf, LoadObj, StoreObj )
	END Register;

(** Load and Store are procedures for external use that read/write an instance of List from/to a file. *)
	PROCEDURE Load*( R: DataIO.Reader;  VAR obj: List );
	VAR ptr: OBJECT;
	BEGIN
		R.Object( ptr );  obj := ptr( List )
	END Load;

	PROCEDURE Store*( W: DataIO.Writer;  obj: List );
	BEGIN
		W.Object( obj )
	END Store;

BEGIN
	Register
END DataLists.