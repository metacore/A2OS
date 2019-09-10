(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE DataTrees;   (** AUTHOR "adf"; PURPOSE "Binary tree for storing Data.Datum"; *)

(* Refs:  N. Wirth, Algorithms and Data Structures, Prentice-Hall, 1986, Sec. 4.5.
			 C. Lins, The Modula-2 Software Component Library, Vol. 3, Springer-Verlag, 1989, Chp. 6. *)

IMPORT NbrInt, DataErrors, DataIO, Data;

CONST
	slantLeft = 9;  level = 10;  slantRight = 11;  SHALLOW = 0;  DEEP = 1;
	(** The version used when reading/writing a tree to file. *)
	VERSION* = 1;

TYPE
	Node = OBJECT
	VAR balance: NbrInt.Integer;
		left, right: Node;
		datum: Data.Datum;

		PROCEDURE & Initialize*;
		BEGIN
			balance := level;  left := NIL;  right := NIL;  datum := NIL
		END Initialize;

		PROCEDURE Attach( datum: Data.Datum;  depth: NbrInt.Integer );
		BEGIN
			IF depth = SHALLOW THEN SELF.datum := datum
			ELSIF depth = DEEP THEN datum.Copy( SELF.datum )
			END
		END Attach;

	END Node;

	(** Used to navigate a tree for the purpose of extracting and updating information. *)
	Rider* = OBJECT
	VAR root, node: Node;
		(** Is the rider at the end-of-tree for the left branch? *)
		eotl-,
		(** Is the rider at the end-of-tree for the right branch? *)
		eotr-: BOOLEAN;

		PROCEDURE & Initialize*;
		BEGIN
			root := NIL;  node := NIL;  eotl := TRUE;  eotr := TRUE
		END Initialize;

		PROCEDURE EOT;
		BEGIN
			IF node # NIL THEN
				IF node.left # NIL THEN eotl := FALSE ELSE eotl := TRUE END;
				IF node.right # NIL THEN eotr := FALSE ELSE eotr := TRUE END
			ELSE eotl := TRUE;  eotr := TRUE
			END
		END EOT;

	(** Moves the rider to its default position. *)
		PROCEDURE Home*;
		BEGIN {EXCLUSIVE}
			node := root;  EOT
		END Home;

	(** Moves the rider to the left node, provided eotl = FALSE. *)
		PROCEDURE Left*;
		BEGIN
			IF ~eotl THEN
				BEGIN {EXCLUSIVE}
					node := node.left;  EOT
				END
			END
		END Left;

	(** Moves the rider to the right node, provided eotr = FALSE. *)
		PROCEDURE Right*;
		BEGIN
			IF ~eotr THEN
				BEGIN {EXCLUSIVE}
					node := node.right;  EOT
				END
			END
		END Right;

	(** Returns a copy of the datum held by the tree at the rider's current position. *)
		PROCEDURE Get*( ): Data.Datum;
		VAR datum: Data.Datum;
		BEGIN
			IF node # NIL THEN
				IF node.datum # NIL THEN node.datum.Copy( datum ) ELSE datum := NIL END
			ELSE datum := NIL
			END;
			RETURN datum
		END Get;

	(** Returns a pointer to the datum held by the tree at the rider's current position. *)
		PROCEDURE Inspect*( ): Data.Datum;
		BEGIN
			IF node # NIL THEN RETURN node.datum ELSE RETURN NIL END
		END Inspect;

		PROCEDURE Find( key: Data.Key;  VAR found: BOOLEAN );
		(* Call Find from within an EXCLUSIVE block. *)
		VAR testDatum: Data.Datum;

			PROCEDURE FindIt( n: Node );
			BEGIN
				IF n # NIL THEN
					IF testDatum > n.datum THEN FindIt( n.right )
					ELSIF testDatum < n.datum THEN FindIt( n.left )
					ELSE node := n;  EOT;  found := TRUE
					END
				ELSE found := FALSE
				END
			END FindIt;

		BEGIN
			NEW( testDatum );  testDatum.SetKey( key );  FindIt( root )
		END Find;

	(** Extracts a copy of that datum with key 'key', provided it exists; otherwise NIL is returned. *)
		PROCEDURE Retrieve*( key: Data.Key ): Data.Datum;
		VAR found: BOOLEAN;
		BEGIN {EXCLUSIVE}
			Find( key, found );
			IF found THEN RETURN Get() ELSE RETURN NIL END
		END Retrieve;

	(** Exchanges a datum held by the tree with that of 'new',  provided their keys are equal. *)
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

	(**  Type Tree is an AVL (Adelson-Velskii-Landis) balanced binary tree that is DataIO.PlugIn registered.  *)
	Tree* = OBJECT
	VAR entries-: NbrInt.Integer;
		rider-: Rider;

		PROCEDURE & Initialize*;
		BEGIN
			(* Intialize the local data. *)
			entries := 0;  NEW( rider )
		END Initialize;

		PROCEDURE Copy*( VAR copy: Tree );
		VAR copyLevel, height: NbrInt.Integer;

			PROCEDURE CopyAt( node: Node;  thisLevel: NbrInt.Integer );
			VAR ignor: BOOLEAN;
			BEGIN
				IF node # NIL THEN
					IF thisLevel < copyLevel THEN
						NbrInt.Inc( thisLevel );  CopyAt( node.left, thisLevel );  CopyAt( node.right, thisLevel )
					ELSE copy.Put( node.datum, DEEP, ignor )
					END
				END
			END CopyAt;

		BEGIN
			NEW( copy );
			(* Make a deep copy of the local data to obj. *)
			height := Height();
			IF height > 0 THEN
				(* Copy the data level-by-level to minimize tree rebalancing. *)
				FOR copyLevel := 1 TO height DO CopyAt( rider.root, 1 ) END
			END;
			copy.rider.Home
		END Copy;

		PROCEDURE Read*( R: DataIO.Reader );
		VAR ignor: BOOLEAN;  i, len: NbrInt.Integer;  obj: OBJECT;  datum: Data.Datum;
		BEGIN
			R.Integer( len );  NEW( rider );
			IF len > 0 THEN
				FOR i := 1 TO len DO R.Object( obj );  datum := obj( Data.Datum );  Put( datum, SHALLOW, ignor ) END
			ELSE  (* This tree is empty. *)
			END;
			rider.Home
		END Read;

		PROCEDURE Write*( W: DataIO.Writer );
		VAR storeLevel: NbrInt.Integer;

			PROCEDURE StoreNode( node: Node;  thisLevel: NbrInt.Integer );
			BEGIN
				IF node # NIL THEN
					IF thisLevel < storeLevel THEN
						NbrInt.Inc( thisLevel );  StoreNode( node.left, thisLevel );  StoreNode( node.right, thisLevel )
					ELSE W.Object( node.datum )
					END
				END
			END StoreNode;

		BEGIN
			W.Integer( entries );
			FOR storeLevel := 1 TO Height() DO StoreNode( rider.root, 1 ) END
		END Write;

	(** Attempts to remove an existing datum with identifier  key  from the tree. *)
		PROCEDURE Delete*( key: Data.Key;  VAR successful: BOOLEAN );
		VAR heightChanged: BOOLEAN;  delete: Node;  testDatum: Data.Datum;

			PROCEDURE Remove( VAR node: Node;  VAR htChanged: BOOLEAN );

				PROCEDURE Extract( VAR n: Node;  VAR changed: BOOLEAN );
				BEGIN
					IF n.right # NIL THEN
						Extract( n.right, changed );
						IF changed THEN ShrinkRight( rider, n, changed ) END
					ELSE  (* Assign the data structure to be deleted to the delete node. *)
						delete.datum := n.datum;  delete := n;  n := n.left;  changed := TRUE
					END
				END Extract;

			BEGIN
				IF node = NIL THEN  (* Key not found. *)
					successful := FALSE
				ELSE  (* Search for the key. *)
					IF testDatum < node.datum THEN
						Remove( node.left, htChanged );
						IF htChanged THEN ShrinkLeft( rider, node, htChanged ) END
					ELSIF testDatum > node.datum THEN
						Remove( node.right, htChanged );
						IF htChanged THEN ShrinkRight( rider, node, htChanged ) END
					ELSE  (* The key has been found.  Delete the entry. *)
						delete := node;
						IF delete.right = NIL THEN node := delete.left;  htChanged := TRUE
						ELSIF delete.left = NIL THEN node := delete.right;  htChanged := TRUE
						ELSE  (* Neither decendant is NIL.  Rotate on the heavier side. *)
							Extract( delete.left, htChanged );
							IF htChanged THEN ShrinkLeft( rider, node, htChanged ) END
						END;
						successful := TRUE
					END
				END
			END Remove;

		BEGIN
			heightChanged := FALSE;  NEW( delete );  NEW( testDatum );  testDatum.SetKey( key );
			BEGIN {EXCLUSIVE}
				Remove( rider.root, heightChanged );
				IF successful THEN NbrInt.Dec( entries );  delete.datum := NIL END
			END;
			rider.Home
		END Delete;

	(** Introduces a new datum into the tree, provided that its key is unique. *)
		PROCEDURE Put( datum: Data.Datum;  depth: NbrInt.Integer;  VAR successful: BOOLEAN );
		(* Call Put from within an EXCLUSIVE block. *)
		VAR heightChanged: BOOLEAN;  firstNode: Node;

			PROCEDURE Place( VAR node: Node;  VAR htChanged: BOOLEAN );
			BEGIN
				IF node = NIL THEN NEW( node );  node.Attach( datum, depth );  htChanged := TRUE;  successful := TRUE
				ELSIF datum < node.datum THEN
					Place( node.left, htChanged );
					IF htChanged THEN GrowLeft( rider, node, htChanged ) END
				ELSIF datum > node.datum THEN
					Place( node.right, htChanged );
					IF htChanged THEN GrowRight( rider, node, htChanged ) END
				ELSE  (* An entry already exits with this key. *)
					successful := FALSE
				END
			END Place;

		BEGIN
			IF datum # NIL THEN
				IF rider.root = NIL THEN NEW( firstNode );  firstNode.Attach( datum, depth );  rider.root := firstNode;  successful := TRUE
				ELSE heightChanged := FALSE;  Place( rider.root, heightChanged )
				END
			ELSE successful := FALSE
			END;
			IF successful THEN NbrInt.Inc( entries ) END;
			rider.node := rider.root;  rider.EOT
		END Put;

		PROCEDURE Insert*( datum: Data.Datum;  VAR successful: BOOLEAN );
		BEGIN {EXCLUSIVE}
			Put( datum, DEEP, successful )
		END Insert;

	(** Returns the verticle height of the tree.  A returned value of 0 means the tree is empty. *)
		PROCEDURE Height*( ): NbrInt.Integer;
		VAR height: NbrInt.Integer;

			PROCEDURE CountLevels( node: Node;  thisLevel: NbrInt.Integer );
			BEGIN
				IF node # NIL THEN
					IF thisLevel > height THEN height := thisLevel END;
					NbrInt.Inc( thisLevel );  CountLevels( node.left, thisLevel );  CountLevels( node.right, thisLevel )
				END
			END CountLevels;

		BEGIN
			height := 0;  CountLevels( rider.root, 1 );  RETURN height
		END Height;

	END Tree;

	(* Local procedures. *)
	PROCEDURE SingleLL( VAR node: Node );
	VAR n: Node;
	BEGIN
		n := node.left;  node.left := n.right;  n.right := node;  node := n
		(* Node balances are set in the Grow and Shrink routines because they are different for these cases. *)
	END SingleLL;

	PROCEDURE SingleRR( VAR node: Node );
	VAR n: Node;
	BEGIN
		n := node.right;  node.right := n.left;  n.left := node;  node := n
		(* Node balances are set in the Grow and Shrink routines because they are different for these cases. *)
	END SingleRR;

	PROCEDURE DoubleLR( VAR node: Node );
	VAR n1, n2: Node;
	BEGIN
		n1 := node.left;  n2 := n1.right;  n1.right := n2.left;  n2.left := n1;  node.left := n2.right;  n2.right := node;
		IF n2.balance = slantLeft THEN node.balance := slantRight ELSE node.balance := level END;
		IF n2.balance = slantRight THEN n1.balance := slantLeft ELSE n1.balance := level END;
		n2.balance := level;  node := n2
	END DoubleLR;

	PROCEDURE DoubleRL( VAR node: Node );
	VAR n1, n2: Node;
	BEGIN
		n1 := node.right;  n2 := n1.left;  n1.left := n2.right;  n2.right := n1;  node.right := n2.left;  n2.left := node;
		IF n2.balance = slantRight THEN node.balance := slantLeft ELSE node.balance := level END;
		IF n2.balance = slantLeft THEN n1.balance := slantRight ELSE n1.balance := level END;
		n2.balance := level;  node := n2
	END DoubleRL;

	PROCEDURE GrowLeft( VAR rider: Rider;  VAR node: Node;  VAR htChanged: BOOLEAN );
	BEGIN
		CASE node.balance OF
		| slantRight:
				node.balance := level;  htChanged := FALSE
		| level:
				node.balance := slantLeft
		| slantLeft:
				IF node.left.balance = slantLeft THEN SingleLL( node );  node.balance := level;  node.right.balance := level
				ELSE DoubleLR( node )
				END;
				htChanged := FALSE;
				IF rider.root = node.right THEN rider.root := node END
		END
	END GrowLeft;

	PROCEDURE GrowRight( VAR rider: Rider;  VAR node: Node;  VAR htChanged: BOOLEAN );
	BEGIN
		CASE node.balance OF
		| slantLeft:
				node.balance := level;  htChanged := FALSE
		| level:
				node.balance := slantRight
		| slantRight:
				IF node.right.balance = slantRight THEN SingleRR( node );  node.balance := level;  node.left.balance := level
				ELSE DoubleRL( node )
				END;
				htChanged := FALSE;
				IF rider.root = node.left THEN rider.root := node END
		END
	END GrowRight;

	PROCEDURE ShrinkLeft( VAR rider: Rider;  VAR node: Node;  VAR htChanged: BOOLEAN );
	BEGIN
		CASE node.balance OF
		| slantLeft:
				node.balance := level
		| level:
				node.balance := slantRight;  htChanged := FALSE
		| slantRight:
				IF node.right.balance = slantLeft THEN DoubleRL( node )
				ELSE
					SingleRR( node );
					IF node.balance = level THEN node.left.balance := slantRight;  node.balance := slantLeft;  htChanged := FALSE
					ELSE node.balance := level;  node.left.balance := level
					END
				END;
				IF rider.root = node.left THEN rider.root := node END
		END
	END ShrinkLeft;

	PROCEDURE ShrinkRight( VAR rider: Rider;  VAR node: Node;  VAR htChanged: BOOLEAN );
	BEGIN
		CASE node.balance OF
		| slantRight:
				node.balance := level
		| level:
				node.balance := slantLeft;  htChanged := FALSE
		| slantLeft:
				IF node.left.balance = slantRight THEN DoubleLR( node )
				ELSE
					SingleLL( node );
					IF node.balance = level THEN node.right.balance := slantLeft;  node.balance := slantRight;  htChanged := FALSE
					ELSE node.balance := level;  node.right.balance := level
					END
				END;
				IF rider.root = node.right THEN rider.root := node END
		END
	END ShrinkRight;

(* The procedures needed to register type Tree so that its instances can be made persistent. *)

	PROCEDURE LoadObj( R: DataIO.Reader;  VAR obj: OBJECT );
	VAR version: SIGNED8;  ver: NbrInt.Integer;  new: Tree;
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
	VAR old: Tree;
	BEGIN
		IF obj = NIL THEN W.RawSInt( -1 ) ELSE W.RawSInt( VERSION );  old := obj( Tree );  old.Write( W ) END
	END StoreObj;

	PROCEDURE Register;
	VAR anInstanceOf: Tree;
	BEGIN
		NEW( anInstanceOf );  DataIO.PlugIn( anInstanceOf, LoadObj, StoreObj )
	END Register;

(** Load and Store are procedures for external use that read/write an instance of Tree from/to a file. *)
	PROCEDURE Load*( R: DataIO.Reader;  VAR obj: Tree );
	VAR ptr: OBJECT;
	BEGIN
		R.Object( ptr );  obj := ptr( Tree )
	END Load;

	PROCEDURE Store*( W: DataIO.Writer;  obj: Tree );
	BEGIN
		W.Object( obj )
	END Store;

BEGIN
	Register
END DataTrees.