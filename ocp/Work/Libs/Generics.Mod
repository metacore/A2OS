MODULE Generics;

(** AUTHOR "Yaroslav Romanchenko (SAGE) http://sage.com.ua/";
	PURPOSE "Almost generic containers"; *)

(** Almost generic containers was developed with main goal to bring to A2 the generic
	containers. Second goal was the zero memory overhead. It means that containers
	MUST support static RECORD types without need of additional pointers allocation.
	This automatically means support for pointer and object types, but, they should be
	wrapped into RECORDs, that is cheap and doesn't incrase memory overhead.
	This goal was riched by array-based approach for all of the containers.
	Almost generic, means here that it's as simple to obtain needed container
	for given type as to perform copy-paste operation with minimal further changes.
	Minimal means here, that as minimum, only proper constructor with array generator
	procedure needs to be written.
	Optionally, typed variants of interface methods may be added for real
	look and feel of genericity :) (see containers for simple types as example).
	Main goal was riched, but, at cost of speed. This cost is less for simple
	stacks and vectors, and bigger for more complex structures as trees.
	General approach to get assumption of this cost is to realise complexity of
	algorythms for maintainance of corresponding data structures and multiply it
	to fact that this maintainance and genericity are implemented by
	memory-to-memory copying operations.

	So, this facts is good to know before use of this containers. Anyway, library
	considered to be good enough for fast prototyping purposes and for porting
	algorythms that massively use generic data structures (C++ STL).
	As further recomended step after your algorythms considered to be working is
	to hand rewrite most critical of used data containers - it's again almost
	copy-paste operation, 	but, with more further changes this time.

*)

IMPORT
	SYSTEM, Commands, Random, Strings, UTF8Strings, Array1dBytes, KernelLog;

CONST
	(* Initial size of containers *)
	INITIAL_SIZE* = 16;

TYPE

	(** Abstract item for use with Queue, DEQue, Vector and Heap *)
	Item* = RECORD
	END;

	(* Pointer to Item is base type for use in comparers *)
	PItem* = POINTER TO Item;

	(** Abstract tree item for use with AA-tree,
		it backward type-compatible with Queue, DEQue and Vector
		containers, but, take additional care about comparer
		function compatibility
	*)
	TreeItem* = RECORD(Item)
		left, right: LONGINT;
		level{ALIGNED(1)}: INTEGER;
	END;

	(* Type for use in Tree constrictor parameters *)
	PTreeItem* = POINTER TO TreeItem;

	LessComparer = PROCEDURE {DELEGATE} (pA, pB: PItem): BOOLEAN;

	(** Abstract container *)
	Container = OBJECT
	VAR

		(* Size of one item *)
		iItemSize: LONGINT;
		
		(* Size of base container (array)  *)
		iSize: LONGINT;
		(* Untyped pointer to array *)
		pArray: ANY;
		(* Address of array *)
		addrArray: ADDRESS;
		
		(* Abstract method for array construction. Should be implemented in derived object *) 
		PROCEDURE ArrayConstruct*(iArraySize: LONGINT; VAR pArray: ANY; VAR addrArray: ADDRESS);
		BEGIN
			HALT(100)
		END ArrayConstruct;

		PROCEDURE &NewContainer*(iItemSize: LONGINT);
		BEGIN
			ASSERT(iItemSize > 0);
			SELF.iItemSize := iItemSize;
			iSize := INITIAL_SIZE;
			ArrayConstruct(iSize, pArray, addrArray);
			Clear
		END NewContainer;

		PROCEDURE Grow*;
		VAR
			pOld: ANY;
			addrOld: ADDRESS;
			iOldSize: LONGINT;
		BEGIN
			pOld := pArray;
			addrOld := addrArray;
			iOldSize := iSize;
			iSize := iSize * 2;
			ArrayConstruct(iSize, pArray, addrArray);
			SYSTEM.MOVE(addrOld, addrArray, iOldSize * iItemSize)
		END Grow;

		(* Abstract *)		
		PROCEDURE Clear*;
		END Clear;

	END Container;

	(* Simple Queue or LIFO stack *)
	Queue* = OBJECT(Container)
	VAR
		iPos: LONGINT;

		PROCEDURE Clear*;
		BEGIN
			iPos := 0
		END Clear;

		PROCEDURE Count*(): LONGINT;
		BEGIN
			RETURN iPos
		END Count;

		PROCEDURE PushInternal*(CONST item: Item);
		BEGIN
			IF iPos = iSize THEN
				Grow
			END;
			SYSTEM.MOVE(ADDRESSOF(item), addrArray + iPos * iItemSize, iItemSize);
			INC(iPos)
		END PushInternal;

		PROCEDURE PopInternal*(VAR item: Item): BOOLEAN;
		BEGIN
			IF iPos # 0 THEN
				DEC(iPos);
				SYSTEM.MOVE(addrArray + iPos * iItemSize, ADDRESSOF(item), iItemSize);
				RETURN TRUE
			ELSE
				RETURN FALSE
			END
		END PopInternal;

		PROCEDURE TopInternal*(VAR item: Item): BOOLEAN;
		BEGIN
			IF iPos # 0 THEN
				SYSTEM.MOVE(addrArray + (iPos - 1) * iItemSize, ADDRESSOF(item), iItemSize);
				RETURN TRUE
			ELSE
				RETURN FALSE
			END
		END TopInternal;

	END Queue;

	(* Double Ended Queue or FIFO stack *)
	DEQue* = OBJECT(Container)
	VAR
		iHead, iTail: LONGINT;

		PROCEDURE Clear*;
		BEGIN
			iHead := 0;
			iTail := 0
		END Clear;

		PROCEDURE Count*(): LONGINT;
		BEGIN
			RETURN iTail - iHead
		END Count;

		PROCEDURE Grow*;
		VAR
			pOld: ANY;
			addrOld: ADDRESS;
			iCount, i: LONGINT;
		BEGIN
			iCount := iTail - iHead;
			IF iCount = 0 THEN (* DEQue is empty, reset... *)
				iHead := 0; iTail := 0;
				RETURN
			END;
			IF iCount * 2 > iSize THEN (* must grow *)
				pOld := pArray;
				addrOld := addrArray;
				iSize := iSize * 2;
				ArrayConstruct(iSize, pArray, addrArray);
				SYSTEM.MOVE(addrOld + iHead * iItemSize, addrArray, iCount * iItemSize)
			ELSE (* may for now simply shift *)
				FOR i := 0 TO iCount - 1 DO
					SYSTEM.MOVE(addrArray + (iHead + i) * iItemSize,
						addrArray + i * iItemSize, iItemSize)
				END
			END;
			iHead := 0; iTail := iCount
		END Grow;

		PROCEDURE PushInternal*(CONST item: Item);
		BEGIN
			IF iTail = iSize THEN
				Grow
			END;
			SYSTEM.MOVE(ADDRESSOF(item), addrArray + iTail * iItemSize, iItemSize);
			INC(iTail)
		END PushInternal;

		PROCEDURE PopInternal*(VAR item: Item): BOOLEAN;
		BEGIN
			IF iHead # iTail THEN
				SYSTEM.MOVE(addrArray + iHead * iItemSize, ADDRESSOF(item), iItemSize);
				INC(iHead);
				RETURN TRUE
			ELSE
				RETURN FALSE
			END
		END PopInternal;

		PROCEDURE TopInternal*(VAR item: Item): BOOLEAN;
		BEGIN
			IF iHead # iTail THEN
				SYSTEM.MOVE(addrArray + iHead * iItemSize, ADDRESSOF(item), iItemSize);
				RETURN TRUE
			ELSE
				RETURN FALSE
			END
		END TopInternal;

	END DEQue;

	Vector* = OBJECT(Container)
	CONST	
		(* Sorted by default (comp shouldn't be NIL!) *)
		SORTED* = 0;
		(* Prevents from inserting of duplicate value *)
		NO_DUPLICATES* = 1;
	VAR
		iPos: LONGINT;

		pCompA, pCompB: PItem;
		comp: LessComparer;

		bSorted: BOOLEAN;

		(* Options *)
		bNoDuplicates: BOOLEAN;

		(* temporary Item storage for Swap operation during sorting *)
		bufTempItem: POINTER TO ARRAY OF CHAR;

		PROCEDURE &NewVector*(iItemSize: LONGINT; pCompA, pCompB: PItem; comp: LessComparer; options: SET);
		BEGIN
			NewContainer(iItemSize);
			SELF.pCompA := pCompA;
			SELF.pCompB := pCompB;
			SELF.comp := comp;
			bNoDuplicates := {NO_DUPLICATES} * options # {};
			bSorted := {SORTED} * options # {};
			ASSERT(~bSorted OR (bSorted & (comp # NIL) & (pCompA # NIL) & (pCompB # NIL)));
			NEW(bufTempItem, iItemSize)
		END NewVector;

		PROCEDURE Clear*;
		BEGIN
			iPos := 0
		END Clear;

		PROCEDURE Count*(): LONGINT;
		BEGIN
			RETURN iPos
		END Count;

		PROCEDURE GetSorted*(): BOOLEAN;
		BEGIN
			RETURN bSorted
		END GetSorted;

		PROCEDURE SetSorted*(b: BOOLEAN);
		BEGIN
			ASSERT((comp # NIL) & (pCompA # NIL) & (pCompB # NIL));
			IF bSorted = b THEN
				RETURN
			END;
			bSorted := b;
			IF ~bSorted OR (iPos = 0) THEN
				RETURN
			END;
			QuickSort(0, iPos - 1)
		END SetSorted;

		PROCEDURE QuickSort(l, r: LONGINT);
		VAR
			i, j, x: LONGINT;
			addrI, addrJ, addrX: ADDRESS;
		BEGIN
			REPEAT
				i := l;
				j := r;
				x := l + (r - l) DIV 2;
				REPEAT
					addrI := addrArray + i * iItemSize;
					addrJ := addrArray + j * iItemSize;
					addrX := addrArray + x * iItemSize;
					WHILE less(addrI, addrX) DO
						INC(i);
						INC(addrI, iItemSize)
					END;
					WHILE less(addrX, addrJ) DO
						DEC(j);
						DEC(addrJ, iItemSize)
					END;
					IF i <= j THEN
						(* Swap i'th and j'th element *)
						SYSTEM.MOVE(addrI, ADDRESSOF(bufTempItem^[0]), iItemSize);
						SYSTEM.MOVE(addrJ, addrI, iItemSize);
						SYSTEM.MOVE(ADDRESSOF(bufTempItem^[0]), addrJ, iItemSize);
						IF x = i THEN
							x := j
						ELSIF x = j THEN
							x := i
						END;
						INC(i);
						DEC(j)
					END
				UNTIL i > j;
				IF l < j THEN
					QuickSort(l, j)
				END;
				l := i
			UNTIL i >= r
		END QuickSort;

		PROCEDURE less(addrCompA, addrCompB: ADDRESS): BOOLEAN;
		BEGIN
			SYSTEM.MOVE(addrCompA, ADDRESSOF(pCompA^), iItemSize);
			SYSTEM.MOVE(addrCompB, ADDRESSOF(pCompB^), iItemSize);
			RETURN comp(pCompA, pCompB)
		END less;

		PROCEDURE IndexOfInternal*(VAR x: Item): LONGINT;
		VAR
			pos: LONGINT;
			bFound: BOOLEAN;
		BEGIN
			ASSERT((comp # NIL) & (pCompA # NIL) & (pCompB # NIL));
			IF bSorted THEN
				pos := FindPosition(x, bFound);
				IF bFound THEN
					RETURN pos
				ELSE
					RETURN -1
				END
			ELSE
				RETURN FindSequentially(x)
			END
		END IndexOfInternal;

		(** Add an object to the list. Add may block if number of
			calls to Lock is bigger than the number of calls to Unlock *)
		PROCEDURE AddInternal*(VAR x: Item): LONGINT;
		VAR
			pos: LONGINT;
		BEGIN
			IF bSorted THEN
				(* Only Addition is possible. Just Add into sorted array *)
				pos := AddUnlocked(x)
			ELSE
				(* Append to unsorted array *)
				IF bNoDuplicates THEN
					ASSERT(FindSequentially(x) = -1)
				END;
				IF iPos = iSize THEN
					Grow
				END;
				(* Put x at Count position *)
				SYSTEM.MOVE(ADDRESSOF(x), addrArray + iPos * iItemSize, iItemSize);
				pos := iPos;
				INC(iPos)
			END;
			RETURN pos
		END AddInternal;

		PROCEDURE GetInternal*(pos: LONGINT; VAR x: Item);
		BEGIN
			ASSERT((pos >= 0) & (pos < iPos), 101);
			SYSTEM.MOVE(addrArray + pos * iItemSize, ADDRESSOF(x), iItemSize)
		END GetInternal;

		PROCEDURE SetInternal*(pos: LONGINT; VAR x: Item);
		BEGIN
			ASSERT((pos >= 0) & (pos < iPos), 101);
			SYSTEM.MOVE(ADDRESSOF(x), addrArray + pos * iItemSize, iItemSize)
		END SetInternal;

		PROCEDURE InsertInternal*(pos: LONGINT; VAR x: Item);
		VAR
			i, posDummy: LONGINT;
			adrSrc: ADDRESS;
		BEGIN
			ASSERT((pos >= 0) & (pos < iPos), 101);
			IF bSorted THEN
				(* Only Addition is possible. Just Add into sorted array *)
				posDummy := AddUnlocked(x)
			ELSE
				(* Insert to unsorted array *)
				IF bNoDuplicates THEN
					ASSERT(FindSequentially(x) = -1)
				END;
				IF iPos = iSize THEN
					Grow
				END;
				i := iPos - 1;
				adrSrc := addrArray + i * iItemSize;
				WHILE i >= pos DO
					(*array[i + 1] := array[i];*)
					SYSTEM.MOVE(adrSrc, adrSrc + iItemSize, iItemSize);
					DEC(adrSrc, iItemSize);
					DEC(i)
				END;
				(* Put x at pos position *)
				SYSTEM.MOVE(ADDRESSOF(x), addrArray + pos * iItemSize, iItemSize);
				INC(iPos)
			END
		END InsertInternal;

		(** Remove an object from the list. Remove may block if number of calls to Lock is bigger than the number of calls to Unlock *)
		PROCEDURE Remove*(pos: LONGINT);
		VAR
			i: LONGINT;
			adrSrc: ADDRESS;
		BEGIN
			ASSERT((pos >= 0) & (pos < iPos), 101);
			i := pos;
			adrSrc := addrArray + (i + 1) * iItemSize;
			WHILE i < iPos - 1 DO
				(*array[i] := array[i + 1];*)
				SYSTEM.MOVE(adrSrc, adrSrc - iItemSize, iItemSize);
				INC(adrSrc, iItemSize);
				INC(i)
			END;
			DEC(iPos)
		END Remove;

		PROCEDURE FindSequentially(VAR x: Item): LONGINT;
		VAR
			i: LONGINT;
			addrI, addrX: ADDRESS;
		BEGIN
			i := 0;
			addrI := addrArray;
			addrX := ADDRESSOF(x);
			WHILE i < iPos DO
				IF ~less(addrI, addrX) & ~less(addrX, addrI) THEN
					RETURN i
				END;
				INC(i);
				INC(addrI, iItemSize)
			END;
			RETURN -1
		END FindSequentially;

		(* Binary search *)
		PROCEDURE FindPosition(VAR x: Item; VAR bFound: BOOLEAN): LONGINT;
		VAR
			lower, middle, upper: LONGINT;
			addrMiddle: ADDRESS;
		BEGIN
			bFound := FALSE;
			IF iPos = 0 THEN RETURN 0 END;
			lower := 0;
			upper := iPos - 1;
			WHILE lower <= upper DO
				middle := lower + (upper - lower) DIV 2;
				addrMiddle := addrArray + middle * iItemSize;
				IF less(addrMiddle, ADDRESSOF(x)) THEN
					(* array[middle] < x *)
					lower := middle + 1
				ELSIF less(ADDRESSOF(x), addrMiddle) THEN
					(* x < array[middle] *)
					upper := middle - 1
				ELSE
					(* array[middle] = x *)
					bFound := TRUE;
					RETURN middle
				END;
			END;
			IF lower <= upper THEN
				RETURN upper
			ELSE
				RETURN lower
			END;
		END FindPosition;

		PROCEDURE AddUnlocked(VAR x: Item): LONGINT;
		VAR
			pos, i: LONGINT;
			bFound: BOOLEAN;
			adrSrc: ADDRESS;
		BEGIN
			pos := FindPosition(x, bFound);
			IF bNoDuplicates THEN
				ASSERT(~bFound)
			END;
			IF iPos = iSize THEN
				Grow
			END;
			i := iPos - 1;
			adrSrc := addrArray + i * iItemSize;
			WHILE i >= pos DO
				(*array[i + 1] := array[i];*)
				SYSTEM.MOVE(adrSrc, adrSrc + iItemSize, iItemSize);
				DEC(adrSrc, iItemSize);
				DEC(i)
			END;
			(* Put x at pos position *)
			SYSTEM.MOVE(ADDRESSOF(x), addrArray + pos * iItemSize, iItemSize);
			INC(iPos);
			RETURN pos
		END AddUnlocked;

		PROCEDURE IsEmpty*(): BOOLEAN;
		BEGIN
			RETURN iPos = 0
		END IsEmpty;

	END Vector;

	(** AA-tree (Arne Andersson, "Balanced Trees Made Simple", 1993) *)
	Tree* = OBJECT(Container)
	CONST
		OFFS_LEFT = 0;
		OFFS_RIGHT = OFFS_LEFT + SIZEOF(LONGINT);
		OFFS_LEVEL = OFFS_RIGHT + SIZEOF(LONGINT);
		OFFS_ALL = OFFS_LEVEL + SIZEOF(INTEGER);
	VAR
		iPos: LONGINT;

		(* stack for freed cells *)
		queue: LongintQueue;

		pCompA, pCompB: PItem;
		less: LessComparer;

		root, bottom, deleted, last: LONGINT;

		iterator: TreeIterator;

		PROCEDURE &NewTree*(iItemSize: LONGINT; pCompA, pCompB: PTreeItem; less: LessComparer);
		BEGIN
			ASSERT((less # NIL) & (pCompA # NIL) & (pCompB # NIL));
			NEW(queue);
			NewContainer(iItemSize);
			SELF.pCompA := pCompA;
			SELF.pCompB := pCompB;
			SELF.less := less
		END NewTree;

		PROCEDURE Clear*;
		BEGIN
			(* 0 cell is reserved for 'bottom' sentinel *)
			iPos := 1;
			(* Clear sentinel cell *)
			Array1dBytes.FillB(addrArray, 0, iItemSize);
			bottom := 0;
			deleted := bottom;
			root := bottom;
			queue.Clear
		END Clear;

		PROCEDURE Count*(): LONGINT;
		BEGIN
			RETURN iPos - 1 - queue.Count()
		END Count;
		
		PROCEDURE IsEmpty*(): BOOLEAN;
		BEGIN
			RETURN Count() = 0
		END IsEmpty;

		PROCEDURE Skew(addrNodeIndex: ADDRESS);
		VAR
			addrNode, addrLeft: ADDRESS;
			node, left: LONGINT;
			nodeLevel, leftLevel: INTEGER;
		BEGIN
			(* IF a[a[node].left].level = a[node].level THEN *)

			node := SYSTEM.GET32(addrNodeIndex);
			addrNode := addrArray + node * iItemSize;
			nodeLevel := SYSTEM.GET16(addrNode + OFFS_LEVEL);

			left := SYSTEM.GET32(addrNode);
			addrLeft := addrArray + left * iItemSize;
			leftLevel := SYSTEM.GET16(addrLeft + OFFS_LEVEL);

			IF leftLevel = nodeLevel THEN
				(* rotate right *)

				(*temp := node;
				node := a[node].left;*)
				SYSTEM.PUT(addrNodeIndex, left);
				(*a[temp].left := a[node].right;*)
				SYSTEM.PUT(addrNode, SYSTEM.GET32(addrLeft + OFFS_RIGHT));
				(*a[node].right := temp*)
				SYSTEM.PUT(addrLeft + OFFS_RIGHT, node)

			END
		END Skew;

		PROCEDURE Split(addrNodeIndex: ADDRESS);
		VAR
			addrNode, addrRight1: ADDRESS;
			node, right1, right2: LONGINT;
			nodeLevel, right2Level: INTEGER;
		BEGIN
			(*IF a[a[a[node].right].right].level = a[node].level THEN*)
			node := SYSTEM.GET32(addrNodeIndex);
			addrNode := addrArray + node * iItemSize;
			nodeLevel := SYSTEM.GET16(addrNode + OFFS_LEVEL);

			right1 := SYSTEM.GET32(addrNode + OFFS_RIGHT);
			addrRight1 := addrArray + right1 * iItemSize;

			right2 := SYSTEM.GET32(addrRight1 + OFFS_RIGHT);
			right2Level := SYSTEM.GET16(addrArray + right2 * iItemSize + OFFS_LEVEL);

			IF right2Level = nodeLevel THEN
				(* rotate left *)

				(*temp := node;
				node := a[node].right;*)
				SYSTEM.PUT(addrNodeIndex, right1);
				(*a[temp].right := a[node].left;*)
				SYSTEM.PUT(addrNode + OFFS_RIGHT, SYSTEM.GET32(addrRight1));
				(*a[node].left := temp;*)
				SYSTEM.PUT(addrRight1, node);
				(*Inc(a[node].level)*)
				SYSTEM.PUT(addrRight1 + OFFS_LEVEL, SYSTEM.GET16(addrRight1 + OFFS_LEVEL) + 1)

			END
		END Split;

		PROCEDURE InsertInternal*(VAR x: TreeItem);
		VAR
			ok: BOOLEAN;
			addrX, addrNode: ADDRESS;
			nodeNew: LONGINT;

			PROCEDURE InsertRecursive(addrNodeIndex: ADDRESS);
			VAR
				node: LONGINT;
			BEGIN
				node := SYSTEM.GET32(addrNodeIndex);
				IF node = bottom THEN
					node := nodeNew;
					SYSTEM.PUT(addrNodeIndex, node);
					x.left := bottom;
					x.right := bottom;
					x.level := 1;
					(* Copy all fields of extended record *)
					SYSTEM.MOVE(addrX, addrArray + node * iItemSize, iItemSize);
					ok := TRUE
				ELSE
					addrNode := addrArray + node * iItemSize;
					(* Here we can copy only information beyond base fields *)
					SYSTEM.MOVE(addrNode + OFFS_ALL, ADDRESSOF(pCompB^) + OFFS_ALL, iItemSize - OFFS_ALL);
					IF less(pCompA, pCompB) THEN
						InsertRecursive((*a[node].left*)addrNode)
					ELSIF less(pCompB, pCompA) THEN
						InsertRecursive((*a[node].right*)addrNode + OFFS_RIGHT)
					ELSE
						ok := FALSE
					END;
					IF ok THEN
						Skew(addrNodeIndex);
						Split(addrNodeIndex)
					END
				END
			END InsertRecursive;

		BEGIN
			ok := FALSE;
			addrX := ADDRESSOF(x);
			(* Here we can copy only information beyond base fields *)
			SYSTEM.MOVE(addrX + OFFS_ALL, ADDRESSOF(pCompA^) + OFFS_ALL, iItemSize - OFFS_ALL);
			(*! Allocate new node in array before recursion to ensure
				that array's growth will not occur inside recursion *)
			nodeNew := NewNode();
			InsertRecursive(ADDRESSOF(root));
			ASSERT(ok)
		END InsertInternal;

		PROCEDURE ContainsInternal*(VAR x: TreeItem): BOOLEAN;
		VAR
			contains: BOOLEAN;
			addrX, addrNode: ADDRESS;

			PROCEDURE ContainsRecursive(addrNodeIndex: ADDRESS);
			VAR
				node: LONGINT;
			BEGIN
				node := SYSTEM.GET32(addrNodeIndex);
				IF ~contains & (node # bottom) THEN
					addrNode := addrArray + node * iItemSize;
					(* Here we can copy only information beyond base fields *)
					SYSTEM.MOVE(addrNode + OFFS_ALL, ADDRESSOF(pCompB^) + OFFS_ALL, iItemSize - OFFS_ALL);
					IF less(pCompA, pCompB) THEN
						ContainsRecursive((*node.left*)addrNode)
					ELSIF less(pCompB, pCompA) THEN
						ContainsRecursive((*node.right*)addrNode + OFFS_RIGHT)
					ELSE
						contains := TRUE
					END
				END
			END ContainsRecursive;

		BEGIN
			contains := FALSE;
			addrX := ADDRESSOF(x);
			(* Here we can copy only information beyond base fields *)
			SYSTEM.MOVE(addrX + OFFS_ALL, ADDRESSOF(pCompA^) + OFFS_ALL, iItemSize - OFFS_ALL);
			ContainsRecursive(ADDRESSOF(root));
			RETURN contains
		END ContainsInternal;

		PROCEDURE GetInternal*(VAR x: TreeItem);
		VAR
			ok: BOOLEAN;
			addrX, addrNode: ADDRESS;

			PROCEDURE GetRecursive(addrNodeIndex: ADDRESS);
			VAR
				node: LONGINT;
			BEGIN
				node := SYSTEM.GET32(addrNodeIndex);
				IF ~ok & (node # bottom) THEN
					addrNode := addrArray + node * iItemSize;
					(* Here we can copy only information beyond base fields *)
					SYSTEM.MOVE(addrX + OFFS_ALL, ADDRESSOF(pCompA^) + OFFS_ALL, iItemSize - OFFS_ALL);
					SYSTEM.MOVE(addrNode + OFFS_ALL, ADDRESSOF(pCompB^) + OFFS_ALL, iItemSize - OFFS_ALL);
					IF less(pCompA, pCompB) THEN
						GetRecursive((*node.left*)addrNode)
					ELSIF less(pCompB, pCompA) THEN
						GetRecursive((*node.right*)addrNode + OFFS_RIGHT)
					ELSE
						ok := TRUE;
						SYSTEM.MOVE(addrNode + OFFS_ALL, addrX + OFFS_ALL, iItemSize - OFFS_ALL)
					END
				END
			END GetRecursive;

		BEGIN
			ok := FALSE;
			addrX := ADDRESSOF(x);
			GetRecursive(ADDRESSOF(root));
			ASSERT(ok)
		END GetInternal;

		PROCEDURE DeleteInternal*(VAR x: TreeItem);
		VAR
			ok: BOOLEAN;
			addrX, addrNode, addrDeleted: ADDRESS;

			PROCEDURE DeleteRecursive(addrNodeIndex: ADDRESS);
			VAR
				node, left, right1: LONGINT;
				nodeLevel, leftLevel, right1Level: INTEGER;
			BEGIN
				ok := FALSE;
				node := SYSTEM.GET32(addrNodeIndex);
				IF node # bottom THEN

					(* 1: Search down the tree and
						set pointers last and deleted *)
					last := node;
					addrNode := addrArray + node * iItemSize;

					(* Here we can copy only information beyond base fields *)
					SYSTEM.MOVE(addrNode + OFFS_ALL, ADDRESSOF(pCompB^) + OFFS_ALL, iItemSize - OFFS_ALL);

					(*IF x.key < a[node].key THEN*)
					IF less(pCompA, pCompB) THEN
						DeleteRecursive((*a[node].left*)addrNode)
					ELSE
						deleted := node;
						DeleteRecursive((*a[node].right*)addrNode + OFFS_RIGHT)
					END;

					(* 2: At the bottom of the tree we
						remove the element (if it is present) *)
					node := SYSTEM.GET32(addrNodeIndex);
					addrNode := addrArray + node * iItemSize;

					addrDeleted := addrArray + deleted * iItemSize;

					(* Here we can copy only information beyond base fields *)
					SYSTEM.MOVE(addrDeleted + OFFS_ALL, ADDRESSOF(pCompB^) + OFFS_ALL, iItemSize - OFFS_ALL);
					IF (node = last) & (deleted # bottom) &
						(*~(key < a[deleted].key) & ~(a[deleted].key < key)*)
						(~less(pCompA, pCompB) & ~less(pCompB, pCompA)) (* x.key = deleted.key *)
					THEN
						(*a[deleted].key := a[node].key;*)
						SYSTEM.MOVE(addrNode + OFFS_ALL, addrDeleted + OFFS_ALL, iItemSize - OFFS_ALL);
						deleted := bottom;
						(*node := a[node].right;*)
						SYSTEM.PUT(addrNodeIndex, SYSTEM.GET32(addrNode + OFFS_RIGHT));
						ok := TRUE

					(* 3: On the way back, we rebalance *)
					ELSE

						nodeLevel := SYSTEM.GET16(addrNode + OFFS_LEVEL);

						left := SYSTEM.GET32(addrNode);
						leftLevel := SYSTEM.GET16(addrArray + left * iItemSize + OFFS_LEVEL);

						right1 := SYSTEM.GET32(addrNode + OFFS_RIGHT);
						right1Level := SYSTEM.GET16(addrArray + right1 * iItemSize + OFFS_LEVEL);

						(*IF (a[a[node].left].level < a[node].level - 1) OR
							(a[a[node].right].level < a[node].level - 1) THEN*)
						IF (leftLevel < nodeLevel - 1) OR
							(right1Level < nodeLevel - 1)
						THEN

							(*a[node].level := a[node].level - 1;*)
							DEC(nodeLevel);
							SYSTEM.PUT(addrNode + OFFS_LEVEL, nodeLevel);

							(*IF a[a[node].right].level > a[node].level THEN*)
							IF right1Level > nodeLevel THEN
								(*a[a[node].right].level := a[node].level*)
								SYSTEM.PUT(addrArray + right1 * iItemSize + OFFS_LEVEL, nodeLevel)
							END;

							Skew((*node*)addrNodeIndex);
							node := SYSTEM.GET32(addrNodeIndex);
							addrNode := addrArray + node * iItemSize;
							Skew((*a[node].right*)addrNode + OFFS_RIGHT);
							Skew((*a[a[node].right].right*)addrArray + SYSTEM.GET32(addrNode + OFFS_RIGHT) * iItemSize + OFFS_RIGHT);
							Split((*node*)addrNodeIndex);
							node := SYSTEM.GET32(addrNodeIndex);
							addrNode := addrArray + node * iItemSize;
							Split((*a[node].right*)addrNode + OFFS_RIGHT)

						END
					END
				END
			END DeleteRecursive;

		BEGIN
			ok := FALSE;
			addrX := ADDRESSOF(x);
			(* Here we can copy only information beyond base fields *)
			SYSTEM.MOVE(addrX + OFFS_ALL, ADDRESSOF(pCompA^) + OFFS_ALL, iItemSize - OFFS_ALL);
			DeleteRecursive(ADDRESSOF(root));
			IF ok THEN
				FreeNode(last)
			END;
			ASSERT(ok)
		END DeleteInternal;

		PROCEDURE Iterator*(): TreeIterator;
		BEGIN
			IF iterator = NIL THEN
				NEW(iterator, SELF)
			END;
			RETURN iterator
		END Iterator;

		PROCEDURE NewNode(): LONGINT;
		VAR
			iNode: LONGINT;
		BEGIN
			(* First of all look into stack *)
			IF queue.Pop(iNode) THEN
				RETURN iNode
			END;
			IF iPos = iSize THEN
				Grow
			END;
			iNode := iPos;
			INC(iPos);
			RETURN iNode
		END NewNode;

		PROCEDURE FreeNode(iNode: LONGINT);
		BEGIN
			IF iNode = iPos - 1 THEN
				(* Node is the last allocated node in array *)
				DEC(iPos)
			ELSE
				queue.Push(iNode);
				Array1dBytes.FillB(addrArray + iNode * iItemSize, 0, iItemSize);
			END
		END FreeNode;

	END Tree;

	TreeIterator* = OBJECT
	VAR
		tree: Tree;
		iPos, iCnt: LONGINT;

		PROCEDURE &Init*(tree: Tree);
		BEGIN
			SELF.tree := tree;
			iPos := -1;
			iCnt := 0
		END Init;

		PROCEDURE Reset*;
		BEGIN
			iPos := -1;
			iCnt := 0
		END Reset;

		PROCEDURE NextPos(VAR i: LONGINT): BOOLEAN;
		VAR
			bRes: BOOLEAN;
		BEGIN
			bRes := FALSE;
			i := iPos;
			REPEAT
				INC(i)
			UNTIL (i >= tree.iSize) OR
				(SYSTEM.GET32(tree.addrArray + i * tree.iItemSize + tree.OFFS_LEVEL) > 0);
			bRes := (i < tree.iSize) & (iCnt + 1 <= tree.Count());
			RETURN bRes
		END NextPos;

		PROCEDURE HasNext*(): BOOLEAN;
		VAR
			iDummy: LONGINT;
		BEGIN
			RETURN NextPos(iDummy)
		END HasNext;

		PROCEDURE GetNext*(VAR item: TreeItem): BOOLEAN;
		VAR
			bRes: BOOLEAN;
			i: LONGINT;
		BEGIN
			bRes := FALSE;
			IF NextPos(i) THEN
				iPos := i;
				INC(iCnt);
				bRes := TRUE;
				SYSTEM.MOVE(tree.addrArray + i * tree.iItemSize + tree.OFFS_ALL,
					ADDRESSOF(item) + tree.OFFS_ALL, tree.iItemSize - tree.OFFS_ALL)
			END;
			RETURN bRes
		END GetNext;

	END TreeIterator;

	(** AA-tree (Arne Andersson, "Balanced Trees Made Simple", 1993) *)
	NativeLongintSet* = OBJECT
	VAR
		a, old: POINTER TO ARRAY OF LongintSetItem;
		iSize, iPos: LONGINT;

		(* stack for freed cells *)
		queue: LongintQueue;

		root, bottom, deleted, last: LONGINT;

		PROCEDURE &Init*;
		BEGIN
			iSize := INITIAL_SIZE;
			NEW(a, iSize);
			NEW(queue);

			iPos := 1; (* 0 cell is reserved for 'bottom' sentinel *)

			(* Clear sentinel cell *)
			Array1dBytes.FillB(ADDRESSOF(a^[0]), 0, SIZEOF(LongintSetItem));

			bottom := 0;
			deleted := bottom;
			root := bottom

		END Init;

		PROCEDURE Count*(): LONGINT;
		BEGIN
			RETURN iPos - 1 - queue.Count()
		END Count;

		PROCEDURE Skew(VAR node: LONGINT);
		VAR
			temp: LONGINT;
		BEGIN
			IF a[a[node].left].level = a[node].level THEN
				(* rotate right *)
				temp := node;
				node := a[node].left;
				a[temp].left := a[node].right;
				a[node].right := temp
			END
		END Skew;

		PROCEDURE Split(VAR node: LONGINT);
		VAR
			temp: LONGINT;
		BEGIN
			IF a[a[a[node].right].right].level = a[node].level THEN
				(* rotate left *)
				temp := node;
				node := a[node].right;
				a[temp].right := a[node].left;
				a[node].left := temp;
				INC(a[node].level)
			END
		END Split;

		PROCEDURE Insert*(key: LONGINT);
		VAR
			ok: BOOLEAN;
			nodeNew: LONGINT;

			PROCEDURE InsertRecursive(VAR node: LONGINT);
			BEGIN
				IF node = bottom THEN
					node := nodeNew;
					a[node].left := bottom;
					a[node].right := bottom;
					a[node].level := 1;
					a[node].key := key;
					ok := TRUE
				ELSE
					IF key < a[node].key THEN
						InsertRecursive(a[node].left)
					ELSIF a[node].key < key THEN
						InsertRecursive(a[node].right)
					ELSE
						ok := FALSE
					END;
					IF ok THEN
						Skew(node);
						Split(node)
					END
				END
			END InsertRecursive;

		BEGIN
			ok := FALSE;
			(*! Allocate new node in array before recursion to ensure
				that array's growth will not occur inside recursion *)
			nodeNew := NewNode();
			InsertRecursive(root);
			ASSERT(ok)
		END Insert;

		PROCEDURE Contains*(key: LONGINT): BOOLEAN;
		VAR
			contains: BOOLEAN;

			PROCEDURE ContainsRecursive(VAR node: LONGINT);
			BEGIN
				IF ~contains & (node # bottom) THEN
					IF key < a[node].key THEN
						ContainsRecursive(a[node].left)
					ELSIF a[node].key < key THEN
						ContainsRecursive(a[node].right)
					ELSE
						contains := TRUE
					END
				END
			END ContainsRecursive;

		BEGIN
			contains := FALSE;
			ContainsRecursive(root);
			RETURN contains
		END Contains;

		PROCEDURE Delete*(key: LONGINT);
		VAR
			ok: BOOLEAN;

			PROCEDURE DeleteRecursive(VAR node: LONGINT);
			BEGIN
				ok := FALSE;
				IF node # bottom THEN


					(* 1: Search down the tree and
						set pointers last and deleted *)
					last := node;
					IF key < a[node].key THEN
						DeleteRecursive(a[node].left)
					ELSE
						deleted := node;
						DeleteRecursive(a[node].right)
					END;


					(* 2: At the bottom of the tree we
						remove the element (if it is present) *)
					IF (node = last) & (deleted # bottom) &
						(~(key < a[deleted].key) & ~(a[deleted].key < key)) (* x = deleted.key *)
					THEN

						a[deleted].key := a[node].key;
						deleted := bottom;
						node := a[node].right;
						ok := TRUE


					(* 3: On the way back, we rebalance *)
					ELSIF (a[a[node].left].level < a[node].level - 1) OR
						(a[a[node].right].level < a[node].level - 1)
					THEN


						a[node].level := a[node].level - 1;
						IF a[a[node].right].level > a[node].level THEN
							a[a[node].right].level := a[node].level
						END;

						Skew(node);
						Skew(a[node].right);
						Skew(a[a[node].right].right);
						Split(node);
						Split(a[node].right)

					END
				END
			END DeleteRecursive;

		BEGIN
			ok := FALSE;
			DeleteRecursive(root);
			IF ok THEN
				FreeNode(last);
			END;
			ASSERT(ok)
		END Delete;

		PROCEDURE NewNode(): LONGINT;
		VAR
			iNode: LONGINT;
		BEGIN
			(* First of all look into stack *)
			IF queue.Pop(iNode) THEN
				RETURN iNode
			END;
			IF iPos = iSize THEN
				(* Grow *)
				old := a;
				iSize := iSize * 2;
				NEW(a, iSize);
				SYSTEM.MOVE(ADDRESSOF(old^[0]), ADDRESSOF(a^[0]), iPos * SIZEOF(LongintSetItem))
			END;
			iNode := iPos;
			INC(iPos);
			RETURN iNode
		END NewNode;

		PROCEDURE FreeNode(iNode: LONGINT);
		BEGIN
			IF iNode = iPos - 1 THEN
				(* Node is the last allocated node in array *)
				DEC(iPos)
			ELSE
				queue.Push(iNode)
			END
		END FreeNode;

	END NativeLongintSet;

	(** Binary heap *)
	Heap* = OBJECT(Container)
	VAR
		iPos: LONGINT;

		pCompA, pCompB: PItem;
		comp: LessComparer;

		(* temporary cell storage *)
		bufTempItem: POINTER TO ARRAY OF CHAR;

		PROCEDURE Clear*;
		BEGIN
			iPos := 0
		END Clear;

		PROCEDURE &NewHeap*(iItemSize: LONGINT; pCompA, pCompB: PItem; comp: LessComparer);
		BEGIN
			NewContainer(iItemSize);
			SELF.pCompA := pCompA;
			SELF.pCompB := pCompB;
			SELF.comp := comp;
			NEW(bufTempItem, iItemSize)
		END NewHeap;

		PROCEDURE Count*(): LONGINT;
		BEGIN
			RETURN iPos
		END Count;

		PROCEDURE less(addrCompA, addrCompB: ADDRESS): BOOLEAN;
		BEGIN
			SYSTEM.MOVE(addrCompA, ADDRESSOF(pCompA^), iItemSize);
			SYSTEM.MOVE(addrCompB, ADDRESSOF(pCompB^), iItemSize);
			RETURN comp(pCompA, pCompB)
		END less;

		PROCEDURE AddInternal*(VAR x: Item);
		VAR
			i, pos: LONGINT;
			addrI, addrPos: ADDRESS;
		BEGIN
			IF iPos + 1 = iSize THEN
				Grow
			END;
			INC(iPos);
			(* Put x at iPos position *)
			SYSTEM.MOVE(ADDRESSOF(x), addrArray + iPos * iItemSize, iItemSize);
			pos := iPos;
			LOOP
				i := pos DIV 2;
				addrI := addrArray + i * iItemSize;
				addrPos := addrArray + pos * iItemSize;
				IF (i > 0) & less(addrPos, addrI) THEN
					(*tmp := array[i];
					array[i] := array[pos];
					array[pos] := tmp;*)
					SYSTEM.MOVE(addrI, ADDRESSOF(bufTempItem^[0]), iItemSize);
					SYSTEM.MOVE(addrPos, addrI, iItemSize);
					SYSTEM.MOVE(ADDRESSOF(bufTempItem^[0]), addrPos, iItemSize);
					pos := i
				ELSE EXIT END;
				IF pos = 1 THEN EXIT END
			END
		END AddInternal;

		PROCEDURE FindSequentially(VAR x: Item): LONGINT;
		VAR
			i: LONGINT;
			addrI, addrX: ADDRESS;
		BEGIN
			i := 1;
			addrI := addrArray + i * iItemSize;
			addrX := ADDRESSOF(x);
			WHILE (i <= iPos) & (less(addrI, addrX) OR less(addrX, addrI)) DO
				INC(i);
				INC(addrI, iItemSize)
			END;
			IF i <= iPos THEN
				RETURN i
			ELSE
				RETURN -1
			END
		END FindSequentially;

		PROCEDURE UpdateInternal*(VAR x: Item);
		VAR
			pos: LONGINT;
			i: LONGINT;
			addrI, addrPos: ADDRESS;
		BEGIN
			pos := FindSequentially(x);
			IF pos > 0 THEN
				LOOP
					i := pos DIV 2;
					addrI := addrArray + i * iItemSize;
					addrPos := addrArray + pos * iItemSize;
					IF (i > 0) & less(addrPos, addrI) THEN
						(*tmp := array[i];
						array[i] := array[pos];
						array[pos] := tmp;*)
						SYSTEM.MOVE(addrI, ADDRESSOF(bufTempItem^[0]), iItemSize);
						SYSTEM.MOVE(addrPos, addrI, iItemSize);
						SYSTEM.MOVE(ADDRESSOF(bufTempItem^[0]), addrPos, iItemSize);
						pos := i
					ELSE EXIT END;
					IF pos = 1 THEN EXIT END
				END
			END
		END UpdateInternal;

		(** Remove an object from the list. Remove may block if number of calls to Lock is bigger than the number of calls to Unlock *)
		PROCEDURE RemoveInternal*(VAR x: Item): BOOLEAN;
		VAR
			i1, i2, u, v: LONGINT;
			addrPos, addrU, addrV, addrI1, addrI2: ADDRESS;
		BEGIN
			IF iPos > 0 THEN
				v := 1;

				addrV := addrArray + v * iItemSize;
				addrPos := addrArray + iPos * iItemSize;

				(*x := array[v];*)
				SYSTEM.MOVE(addrV, ADDRESSOF(x), iItemSize);
				(*array[v] := array[iPos];*)
				SYSTEM.MOVE(addrPos, addrV, iItemSize);
				(*array[iPos] := NIL;*)
				Array1dBytes.FillB(addrPos, 0, iItemSize);
				DEC(iPos);
				LOOP
					u := v;
					i1 := 2 * u;
					i2 := 2 * u + 1;

					addrU := addrArray + u * iItemSize;
					addrI1 := addrArray + i1 * iItemSize;

					IF i2 <= iPos THEN

						IF (*compare(array[u], array[i1]) >= 0*)
							~less(addrU, addrI1)
						THEN v := i1 END;

						addrV := addrArray + v * iItemSize;
						addrI2 := addrArray + i2 * iItemSize;

						IF (*compare(array[v], array[i2]) >= 0*)
							~less(addrV, addrI2)
						THEN v := i2 END

					ELSIF i1 <= iPos THEN

						IF (*compare(array[u], array[i1]) >= 0*)
							~less(addrU, addrI1)
						THEN v := i1 END

					END;
					IF u # v THEN

						addrV := addrArray + v * iItemSize;

						(*tmp := array[u];
						array[u] := array[v];
						array[v] := tmp*)

						SYSTEM.MOVE(addrU, ADDRESSOF(bufTempItem^[0]), iItemSize);
						SYSTEM.MOVE(addrV, addrU, iItemSize);
						SYSTEM.MOVE(ADDRESSOF(bufTempItem^[0]), addrV, iItemSize)

					ELSE EXIT END
				END;
				RETURN TRUE
			ELSE
				RETURN FALSE
			END
		END RemoveInternal;

	END Heap;

	LongintItem* = RECORD(Item)
		value*: LONGINT
	END;

	LongintItems* = POINTER TO ARRAY OF LongintItem;

	LongintSetItem* = RECORD(TreeItem)
		key*: LONGINT
	END;

	LongintSetItems* = POINTER TO ARRAY OF LongintSetItem;

	LongintQueue* = OBJECT(Queue)
	VAR
		array: LongintItems;

		PROCEDURE &New*;
		BEGIN
			NewContainer(SIZEOF(LongintItem))
		END New;

		PROCEDURE ArrayConstruct(iArraySize: LONGINT; VAR pArray: ANY; VAR addrArray: ADDRESS);
		BEGIN
			NEW(array, iArraySize); pArray := array; addrArray := ADDRESSOF(array^[0])
		END ArrayConstruct;

		PROCEDURE Push*(value: LONGINT);
		VAR
			item: LongintItem;
		BEGIN
			item.value := value;
			PushInternal(item)
		END Push;

		PROCEDURE Pop*(VAR value: LONGINT): BOOLEAN;
		VAR
			item: LongintItem;
			bRes: BOOLEAN;
		BEGIN
			bRes := PopInternal(item);
			value := item.value;
			RETURN bRes
		END Pop;

		PROCEDURE Top*(VAR value: LONGINT): BOOLEAN;
		VAR
			item: LongintItem;
			bRes: BOOLEAN;
		BEGIN
			bRes := TopInternal(item);
			value := item.value;
			RETURN bRes
		END Top;

	END LongintQueue;

	LongintDEQue* = OBJECT(DEQue)
	VAR
		array: LongintItems;

		PROCEDURE &New*;
		BEGIN
			NewContainer(SIZEOF(LongintItem))
		END New;

		PROCEDURE ArrayConstruct(iArraySize: LONGINT; VAR pArray: ANY; VAR addrArray: ADDRESS);
		BEGIN
			NEW(array, iArraySize); pArray := array; addrArray := ADDRESSOF(array^[0])
		END ArrayConstruct;

		PROCEDURE Push*(value: LONGINT);
		VAR
			item: LongintItem;
		BEGIN
			item.value := value;
			PushInternal(item)
		END Push;

		PROCEDURE Pop*(VAR value: LONGINT): BOOLEAN;
		VAR
			item: LongintItem;
			bRes: BOOLEAN;
		BEGIN
			bRes := PopInternal(item);
			value := item.value;
			RETURN bRes
		END Pop;

		PROCEDURE Top*(VAR value: LONGINT): BOOLEAN;
		VAR
			item: LongintItem;
			bRes: BOOLEAN;
		BEGIN
			bRes := TopInternal(item);
			value := item.value;
			RETURN bRes
		END Top;

	END LongintDEQue;

	LongintVector* = OBJECT(Vector)
	VAR
		array: LongintItems;

		PROCEDURE &New*(options: SET);
		VAR
			pCompA, pCompB: POINTER TO LongintItem;
		BEGIN
			NEW(pCompA);
			NEW(pCompB);
			NewVector(SIZEOF(LongintItem), pCompA, pCompB, LongintItemLess, options)
		END New;

		PROCEDURE ArrayConstruct(iArraySize: LONGINT; VAR pArray: ANY; VAR addrArray: ADDRESS);
		BEGIN
			NEW(array, iArraySize); pArray := array; addrArray := ADDRESSOF(array^[0])
		END ArrayConstruct;

		PROCEDURE Add*(value: LONGINT): LONGINT;
		VAR
			item: LongintItem;
		BEGIN
			item.value := value;
			RETURN AddInternal(item)
		END Add;

		PROCEDURE Insert*(pos: LONGINT; value: LONGINT);
		VAR
			item: LongintItem;
		BEGIN
			item.value := value;
			InsertInternal(pos, item)
		END Insert;

		PROCEDURE IndexOf*(value: LONGINT): LONGINT;
		VAR
			item: LongintItem;
		BEGIN
			item.value := value;
			RETURN IndexOfInternal(item)
		END IndexOf;

		PROCEDURE Get*(pos: LONGINT): LONGINT;
		VAR
			item: LongintItem;
		BEGIN
			GetInternal(pos, item);
			RETURN item.value
		END Get;

		PROCEDURE Set*(pos: LONGINT; value: LONGINT);
		VAR
			item: LongintItem;
		BEGIN
			item.value := value;
			SetInternal(pos, item)
		END Set;

	END LongintVector;

	LongintSet* = OBJECT(Tree)
	VAR
		array: LongintSetItems;

		PROCEDURE &New*;
		VAR
			pCompA, pCompB: POINTER TO LongintSetItem;
		BEGIN
			NEW(pCompA);
			NEW(pCompB);
			NewTree(SIZEOF(LongintSetItem), pCompA, pCompB, LongintSetItemLess)
		END New;

		PROCEDURE ArrayConstruct(iArraySize: LONGINT; VAR pArray: ANY; VAR addrArray: ADDRESS);
		BEGIN
			NEW(array, iArraySize); pArray := array; addrArray := ADDRESSOF(array^[0])
		END ArrayConstruct;

		PROCEDURE Insert*(key: LONGINT);
		VAR
			item: LongintSetItem;
		BEGIN
			item.key := key;
			InsertInternal(item)
		END Insert;

		PROCEDURE Contains*(key: LONGINT): BOOLEAN;
		VAR
			item: LongintSetItem;
		BEGIN
			item.key := key;
			RETURN ContainsInternal(item)
		END Contains;

		PROCEDURE Delete*(key: LONGINT);
		VAR
			item: LongintSetItem;
		BEGIN
			item.key := key;
			DeleteInternal(item)
		END Delete;

	END LongintSet;

	LongintVectorItem* = RECORD(Item)
		value*: LongintVector
	END;

	LongintVectorItems* = POINTER TO ARRAY OF LongintVectorItem;

	LongintVectorSetItem* = RECORD(TreeItem)
		key*: LongintVector
	END;

	LongintVectorSetItems* = POINTER TO ARRAY OF LongintVectorSetItem;

	LongintVectorVector* = OBJECT(Vector)
	VAR
		array: LongintVectorItems;

		PROCEDURE &New*(options: SET);
		VAR
			pCompA, pCompB: POINTER TO LongintVectorItem;
		BEGIN
			NEW(pCompA);
			NEW(pCompB);
			NewVector(SIZEOF(LongintVectorItem), pCompA, pCompB, LongintVectorItemLess, options)
		END New;

		PROCEDURE ArrayConstruct(iArraySize: LONGINT; VAR pArray: ANY; VAR addrArray: ADDRESS);
		BEGIN
			NEW(array, iArraySize); pArray := array; addrArray := ADDRESSOF(array^[0])
		END ArrayConstruct;

		PROCEDURE Add*(value: LongintVector): LONGINT;
		VAR
			item: LongintVectorItem;
		BEGIN
			item.value := value;
			RETURN AddInternal(item)
		END Add;

		PROCEDURE Insert*(pos: LONGINT; value: LongintVector);
		VAR
			item: LongintVectorItem;
		BEGIN
			item.value := value;
			InsertInternal(pos, item)
		END Insert;

		PROCEDURE IndexOf*(value: LongintVector): LONGINT;
		VAR
			item: LongintVectorItem;
		BEGIN
			item.value := value ;
			RETURN IndexOfInternal(item)
		END IndexOf;

		PROCEDURE Get*(pos: LONGINT): LongintVector;
		VAR
			item: LongintVectorItem;
		BEGIN
			GetInternal(pos, item);
			RETURN item.value
		END Get;

		PROCEDURE Set*(pos: LONGINT; value: LongintVector);
		VAR
			item: LongintVectorItem;
		BEGIN
			item.value := value;
			SetInternal(pos, item)
		END Set;

	END LongintVectorVector;

	LongintVectorSet* = OBJECT(Tree)
	VAR
		array: LongintVectorSetItems;

		PROCEDURE &New*;
		VAR
			pCompA, pCompB: POINTER TO LongintVectorSetItem;
		BEGIN
			NEW(pCompA);
			NEW(pCompB);
			NewTree(SIZEOF(LongintVectorSetItem), pCompA, pCompB, LongintVectorSetItemLess)
		END New;

		PROCEDURE ArrayConstruct(iArraySize: LONGINT; VAR pArray: ANY; VAR addrArray: ADDRESS);
		BEGIN
			NEW(array, iArraySize); pArray := array; addrArray := ADDRESSOF(array^[0])
		END ArrayConstruct;
		
		PROCEDURE Insert*(key: LongintVector);
		VAR
			item: LongintVectorSetItem;
		BEGIN
			item.key := key;
			InsertInternal(item)
		END Insert;

		PROCEDURE Contains*(key: LongintVector): BOOLEAN;
		VAR
			item: LongintVectorSetItem;
		BEGIN
			item.key := key;
			RETURN ContainsInternal(item)
		END Contains;

		PROCEDURE Delete*(key: LongintVector);
		VAR
			item: LongintVectorSetItem;
		BEGIN
			item.key := key;
			DeleteInternal(item)
		END Delete;

	END LongintVectorSet;

	String = Strings.String;
	AOC* = ARRAY OF CHAR;

	StringItem* = RECORD(Item)
		value*: String
	END;

	StringItems* = POINTER TO ARRAY OF StringItem;

	StringSetItem* = RECORD(TreeItem)
		key*: String
	END;

	StringSetItems* = POINTER TO ARRAY OF StringSetItem;

	StringQueue* = OBJECT(Queue)
	VAR
		array: StringItems;

		PROCEDURE &New*;
		BEGIN
			NewContainer(SIZEOF(StringItem))
		END New;

		PROCEDURE ArrayConstruct(iArraySize: LONGINT; VAR pArray: ANY; VAR addrArray: ADDRESS);
		BEGIN
			NEW(array, iArraySize); pArray := array; addrArray := ADDRESSOF(array^[0])
		END ArrayConstruct;

		PROCEDURE Push*(value: String);
		VAR
			item: StringItem;
		BEGIN
			item.value := value;
			PushInternal(item)
		END Push;

		PROCEDURE Pop*(VAR value: String): BOOLEAN;
		VAR
			item: StringItem;
			bRes: BOOLEAN;
		BEGIN
			bRes := PopInternal(item);
			value := item.value;
			RETURN bRes
		END Pop;

		PROCEDURE Top*(VAR value: String): BOOLEAN;
		VAR
			item: StringItem;
			bRes: BOOLEAN;
		BEGIN
			bRes := TopInternal(item);
			value := item.value;
			RETURN bRes
		END Top;

	END StringQueue;

	StringDEQue* = OBJECT(DEQue)
	VAR
		array: LongintItems;

		PROCEDURE &New*;
		BEGIN
			NewContainer(SIZEOF(StringItem))
		END New;

		PROCEDURE ArrayConstruct(iArraySize: LONGINT; VAR pArray: ANY; VAR addrArray: ADDRESS);
		BEGIN
			NEW(array, iArraySize); pArray := array; addrArray := ADDRESSOF(array^[0])
		END ArrayConstruct;

		PROCEDURE Push*(value: String);
		VAR
			item: StringItem;
		BEGIN
			item.value := value;
			PushInternal(item)
		END Push;

		PROCEDURE Pop*(VAR value: String): BOOLEAN;
		VAR
			item: StringItem;
			bRes: BOOLEAN;
		BEGIN
			bRes := PopInternal(item);
			value := item.value;
			RETURN bRes
		END Pop;

		PROCEDURE Top*(VAR value: String): BOOLEAN;
		VAR
			item: StringItem;
			bRes: BOOLEAN;
		BEGIN
			bRes := TopInternal(item);
			value := item.value;
			RETURN bRes
		END Top;

	END StringDEQue;

	StringVector* = OBJECT(Vector)
	VAR
		array: StringItems;

		PROCEDURE &New*(options: SET);
		VAR
			pCompA, pCompB: POINTER TO StringItem;
		BEGIN
			NEW(pCompA);
			NEW(pCompB);
			NewVector(SIZEOF(StringItem), pCompA, pCompB, StringItemLess, options)
		END New;

		PROCEDURE ArrayConstruct(iArraySize: LONGINT; VAR pArray: ANY; VAR addrArray: ADDRESS);
		BEGIN
			NEW(array, iArraySize); pArray := array; addrArray := ADDRESSOF(array^[0])
		END ArrayConstruct;

		PROCEDURE Add*(value: String): LONGINT;
		VAR
			item: StringItem;
		BEGIN
			item.value := value;
			RETURN AddInternal(item)
		END Add;

		PROCEDURE Insert*(pos: LONGINT; value: String);
		VAR
			item: StringItem;
		BEGIN
			item.value := value;
			InsertInternal(pos, item)
		END Insert;

		PROCEDURE IndexOf*(value: String): LONGINT;
		VAR
			item: StringItem;
		BEGIN
			item.value :=value ;
			RETURN IndexOfInternal(item)
		END IndexOf;

		PROCEDURE Get*(pos: LONGINT): String;
		VAR
			item: StringItem;
		BEGIN
			GetInternal(pos, item);
			RETURN item.value
		END Get;

		PROCEDURE Set*(pos: LONGINT; value: String);
		VAR
			item: StringItem;
		BEGIN
			item.value := value;
			SetInternal(pos, item)
		END Set;

	END StringVector;

	StringSet* = OBJECT(Tree)
	VAR
		array: StringSetItems;

		PROCEDURE &New*;
		VAR
			pCompA, pCompB: POINTER TO StringSetItem;
		BEGIN
			NEW(pCompA);
			NEW(pCompB);
			NewTree(SIZEOF(StringSetItem), pCompA, pCompB, StringSetItemLess)
		END New;

		PROCEDURE ArrayConstruct(iArraySize: LONGINT; VAR pArray: ANY; VAR addrArray: ADDRESS);
		BEGIN
			NEW(array, iArraySize); pArray := array; addrArray := ADDRESSOF(array^[0])
		END ArrayConstruct;

		PROCEDURE Insert*(key: String);
		VAR
			item: StringSetItem;
		BEGIN
			item.key := key;
			InsertInternal(item)
		END Insert;

		PROCEDURE InsertAOC*(CONST key: AOC);
		VAR
			item: StringSetItem;
		BEGIN
			item.key := Strings.NewString(key);
			InsertInternal(item)
		END InsertAOC;

		PROCEDURE Contains*(key: String): BOOLEAN;
		VAR
			item: StringSetItem;
		BEGIN
			item.key := key;
			RETURN ContainsInternal(item)
		END Contains;

		PROCEDURE ContainsAOC*(CONST key: AOC): BOOLEAN;
		VAR
			item: StringSetItem;
		BEGIN
			item.key := Strings.NewString(key);
			RETURN ContainsInternal(item)
		END ContainsAOC;

		PROCEDURE Delete*(key: String);
		VAR
			item: StringSetItem;
		BEGIN
			item.key := key;
			DeleteInternal(item)
		END Delete;

		PROCEDURE DeleteAOC*(CONST key: AOC);
		VAR
			item: StringSetItem;
		BEGIN
			item.key := Strings.NewString(key);
			DeleteInternal(item)
		END DeleteAOC;

	END StringSet;

	ObjectMapItem* = RECORD(StringSetItem)
		obj*: ANY
	END;

	ObjectMapItems* = POINTER TO ARRAY OF ObjectMapItem;

	ObjectMap* = OBJECT(Tree)
	VAR
		array: ObjectMapItems;

		PROCEDURE &New*;
		VAR
			pCompA, pCompB: POINTER TO ObjectMapItem;
		BEGIN
			NEW(pCompA);
			NEW(pCompB);
			NewTree(SIZEOF(ObjectMapItem), pCompA, pCompB, StringSetItemLess)
		END New;

		PROCEDURE ArrayConstruct(iArraySize: LONGINT; VAR pArray: ANY; VAR addrArray: ADDRESS);
		BEGIN
			NEW(array, iArraySize); pArray := array; addrArray := ADDRESSOF(array^[0])
		END ArrayConstruct;

		PROCEDURE Insert*(key: String; obj: ANY);
		VAR
			item: ObjectMapItem;
		BEGIN
			item.key := key;
			item.obj := obj;
			InsertInternal(item)
		END Insert;

		PROCEDURE InsertAOC*(CONST key: AOC; obj: ANY);
		VAR
			item: ObjectMapItem;
		BEGIN
			item.key := Strings.NewString(key);
			item.obj := obj;
			InsertInternal(item)
		END InsertAOC;

		PROCEDURE Contains*(key: String): BOOLEAN;
		VAR
			item: ObjectMapItem;
		BEGIN
			item.key := key;
			RETURN ContainsInternal(item)
		END Contains;

		PROCEDURE ContainsAOC*(CONST key: AOC): BOOLEAN;
		VAR
			item: ObjectMapItem;
		BEGIN
			item.key := Strings.NewString(key);
			RETURN ContainsInternal(item)
		END ContainsAOC;

		PROCEDURE Get*(key: String): ANY;
		VAR
			item: ObjectMapItem;
		BEGIN
			item.key := key;
			GetInternal(item);
			RETURN item.obj
		END Get;

		PROCEDURE GetAOC*(CONST key: AOC): ANY;
		VAR
			item: ObjectMapItem;
		BEGIN
			item.key := Strings.NewString(key);
			GetInternal(item);
			RETURN item.obj
		END GetAOC;

		PROCEDURE Delete*(key: String);
		VAR
			item: ObjectMapItem;
		BEGIN
			item.key := key;
			DeleteInternal(item)
		END Delete;

		PROCEDURE DeleteAOC*(CONST key: AOC);
		VAR
			item: ObjectMapItem;
		BEGIN
			item.key := Strings.NewString(key);
			DeleteInternal(item)
		END DeleteAOC;

	END ObjectMap;

	PROCEDURE LongintItemLess*(pA, pB: PItem): BOOLEAN;
	BEGIN
		RETURN pA^(LongintItem).value < pB^(LongintItem).value
	END LongintItemLess;

	PROCEDURE LongintSetItemLess*(pA, pB: PItem): BOOLEAN;
	BEGIN
		RETURN pA^(LongintSetItem).key < pB^(LongintSetItem).key
	END LongintSetItemLess;

	PROCEDURE StringItemLess*(pA, pB: PItem): BOOLEAN;
	BEGIN
		RETURN UTF8Strings.Compare(pA^(StringItem).value^,
			pB^(StringItem).value^) < 0
	END StringItemLess;

	PROCEDURE StringSetItemLess*(pA, pB: PItem): BOOLEAN;
	BEGIN
		RETURN UTF8Strings.Compare(pA^(StringSetItem).key^,
			pB^(StringSetItem).key^) < 0
	END StringSetItemLess;

	PROCEDURE CompareLongintVectors*(left, right: LongintVector): LONGINT;
	VAR
		n, i, nRes: LONGINT;
	BEGIN
		n := MIN(left.Count(), right.Count());
		IF n = 0 THEN
			IF left.Count() > 0 THEN
				RETURN 1
			ELSIF right.Count() > 0 THEN
				RETURN -1
			ELSE
				RETURN 0
			END
		ELSE
			i := 0; nRes := 0;
			WHILE (i < n) & (nRes = 0) DO
				IF left.Get(i) < right.Get(i) THEN
					nRes := -1
				ELSIF left.Get(i) > right.Get(i) THEN
					nRes := 1
				ELSE
					nRes := 0
				END;
				INC(i)
			END;
			IF nRes # 0 THEN
				RETURN nRes
			ELSIF left.Count() > n THEN
				RETURN 1
			ELSIF right.Count() > n THEN
				RETURN -1
			ELSE
				RETURN 0
			END
		END
	END CompareLongintVectors;

	PROCEDURE LongintVectorItemLess*(pA, pB: PItem): BOOLEAN;
	BEGIN
		RETURN CompareLongintVectors(pA^(LongintVectorItem).value,
			pB^(LongintVectorItem).value) < 0
	END LongintVectorItemLess;

	PROCEDURE LongintVectorSetItemLess*(pA, pB: PItem): BOOLEAN;
	BEGIN
		RETURN CompareLongintVectors(pA^(LongintVectorSetItem).key,
			pB^(LongintVectorSetItem).key) < 0
	END LongintVectorSetItemLess;

	PROCEDURE TestStacks*(context: Commands.Context);
	VAR
		queue: LongintQueue;
		deque: LongintDEQue;

		iIn, iOut: LONGINT;
		rand: Random.Generator;
		i, j, n: LONGINT;

		PROCEDURE PushInfo(n: LONGINT);
		BEGIN
			KernelLog.String("push keys: ");
			KernelLog.Int(iIn, 0);
			KernelLog.String("..");
			KernelLog.Int(iIn + n - 1, 0);
			KernelLog.Ln
		END PushInfo;

		PROCEDURE PopInfo(n: LONGINT);
		BEGIN
			KernelLog.String("try to pop ");
			KernelLog.Int(n, 0);
			KernelLog.String(" elements, output: ")
		END PopInfo;

		PROCEDURE PopAllInfo(n: LONGINT);
		BEGIN
			KernelLog.String("try to pop all ");
			KernelLog.Int(n, 0);
			KernelLog.String(" elements, output: ")
		END PopAllInfo;

	BEGIN

		NEW(rand);

		KernelLog.String("LIFO stack: ");
		KernelLog.Ln;
		iIn := 0;
		NEW(queue);
		FOR i := 0 TO 9 DO
			n := rand.Dice(11) + 1;
			PushInfo(n);
			FOR j := 0 TO n - 1 DO
				queue.Push(iIn); INC(iIn)
			END;
			n := rand.Dice(10) + 1;
			PopInfo(n);
			FOR j := 0 TO n - 1 DO
				IF queue.Pop(iOut) THEN
					KernelLog.Int(iOut, 0); KernelLog.Char(' ')
				END
			END;
			KernelLog.Ln
		END;
		PopAllInfo(queue.Count());
		FOR i := 0 TO queue.Count() - 1 DO
			IF queue.Pop(iOut) THEN
				KernelLog.Int(iOut, 0); KernelLog.Char(' ')
			END
		END;
		KernelLog.Ln;

		KernelLog.Ln;
		KernelLog.String("FIFO stack: ");
		KernelLog.Ln;
		iIn := 0;
		NEW(deque);
		FOR i := 0 TO 9 DO
			n := rand.Dice(11) + 1;
			PushInfo(n);
			FOR j := 0 TO n - 1 DO
				deque.Push(iIn); INC(iIn)
			END;
			n := rand.Dice(10) + 1;
			PopInfo(n);
			FOR j := 0 TO n - 1 DO
				IF deque.Pop(iOut) THEN
					KernelLog.Int(iOut, 0); KernelLog.Char(' ')
				END
			END;
			KernelLog.Ln
		END;
		PopAllInfo(deque.Count());
		FOR i := 0 TO deque.Count() - 1 DO
			IF deque.Pop(iOut) THEN
				KernelLog.Int(iOut, 0); KernelLog.Char(' ')
			END
		END;
		KernelLog.Ln

	END TestStacks;

	PROCEDURE TestVectors*(context : Commands.Context);
	CONST
		N = 1000000;
	VAR
		vLong: LongintVector;
		i, j, posDummy: LONGINT;
	BEGIN

		context.out.Ln;
		
		context.out.Int(vLong.SORTED, 0);
		context.out.Ln;
		context.out.Int(vLong.NO_DUPLICATES, 0);
		context.out.Ln;
		context.out.Ln;

		NEW(vLong, {});
		FOR i := 0 TO N - 1 DO
			posDummy := vLong.Add(N - 1 - i)
		END;

		vLong.SetSorted(TRUE);

		vLong.Remove(vLong.IndexOf(2));
		vLong.Remove(vLong.IndexOf(4));
		vLong.Remove(vLong.IndexOf(6));
		vLong.Remove(vLong.IndexOf(11));
		vLong.Remove(vLong.IndexOf(13));
		vLong.Remove(vLong.IndexOf(15));

		FOR i := 0 TO 25 DO
			j := vLong.IndexOf(i);
			context.out.Int(i, 0);
			IF j >= 0 THEN
				context.out.String(" located at pos: "); context.out.Int(j, 0)
			ELSE
				context.out.String(" not found")
			END;
			context.out.Ln
		END;

		context.out.Ln;

	END TestVectors;

	PROCEDURE TreeTest*(context: Commands.Context);
	CONST
		N = 100000;
	VAR
		vectorLong: LongintVector;
		treeLong: LongintSet;
		rand: Random.Generator;
		i, n, dummyPos: LONGINT;
		bOk: BOOLEAN;
	BEGIN

		NEW(rand);

		(* Inserting *)
		NEW(treeLong);
		FOR i := 0 TO N - 1 DO
			treeLong.Insert(i)
		END;

		(* Is Count correct *)
		bOk := treeLong.Count() = N;

		IF bOk THEN
			context.out.String("Tree is Ok")
		ELSE
			context.out.String("Tree isn't Ok")
		END;
		context.out.Ln;

		(* All of inserted keys are present? *)
		i := 0;
		WHILE bOk & (i < N) DO
			bOk := treeLong.Contains(i);
			INC(i)
		END;

		IF bOk THEN
			context.out.String("Tree is Ok")
		ELSE
			context.out.String("Tree isn't Ok")
		END;
		context.out.Ln;

		(* Make list of some candidates for removal *)
		NEW(vectorLong, {});
		FOR i := 0 TO N DIV 100 - 1 DO
			n := rand.Dice(N);
			IF vectorLong.IndexOf(n) = -1 THEN
				dummyPos := vectorLong.Add(n)
			END
		END;
		vectorLong.SetSorted(TRUE);

		(* Remove candidates by list *)
		FOR i := 0 TO vectorLong.Count() - 1 DO
			treeLong.Delete(vectorLong.Get(i))
		END;

		(* Check if Contains still works correctly *)
		i := 0;
		WHILE bOk & (i < N) DO
			bOk := ((vectorLong.IndexOf(i) = -1) & treeLong.Contains(i)) OR
				(~(vectorLong.IndexOf(i) = -1) & ~treeLong.Contains(i));
			INC(i)
		END;

		IF bOk THEN
			context.out.String("Tree is Ok")
		ELSE
			context.out.String("Tree isn't Ok")
		END;

		context.out.Ln

	END TreeTest;
	
	PROCEDURE TreeIteratorTest*(context: Commands.Context);
	VAR
		treeLong: LongintSet;
		treeIterator: TreeIterator;
		item: LongintSetItem;
		i: LONGINT;
	BEGIN

		NEW(treeLong);
		NEW(treeIterator, treeLong);

		FOR i := 0 TO 9 DO
			treeLong.Insert(i)
		END;
		treeLong.Delete(3);
		treeLong.Delete(5);
		FOR i := 10 TO 19 DO
			treeLong.Insert(i)
		END;
		treeLong.Delete(7);
		treeLong.Delete(11);
		treeLong.Delete(14);

		treeIterator.Reset;
		WHILE treeIterator.GetNext(item) DO
			context.out.Int(item.key, 0); context.out.Char(' ');
			IF treeIterator.HasNext() THEN
				context.out.String("has more")
			ELSE
				context.out.String("this one was the last")
			END;
			context.out.Ln
		END

	END TreeIteratorTest;

(*

	PROCEDURE TestTrees*(context: Commands.Context);
	CONST
		N = 10;
		N_TESTS = 5;
	VAR
		vLong: LongintVector;
		i, j, posDummy: LONGINT;
		treeLong: LongintSet;
		item: LongintSetItem;
		t: HUGEINT;
		str: ARRAY 32 OF CHAR;
	BEGIN
		context.out.Ln;

(*
		t := PreciseTimer.GetTicks();
		FOR j := 0 TO N_TESTS - 1 DO
			NEW(vLong, {});
			FOR i := 0 TO N - 1 DO
				posDummy := vLong.Add(N - 1 - i)
			END;
			vLong.SetSorted(TRUE)
		END;
		t := PreciseTimer.GetTicks() - t;
		Strings.FloatToStr(PreciseTimer.GetTime(t) / N_TESTS, 0, 6, 0, str);
		context.out.String("Vector time: "); context.out.String(str);

		context.out.Ln;

		t := PreciseTimer.GetTicks();
		FOR j := 0 TO N_TESTS - 1 DO
			NEW(treeLong);
			FOR i := 0 TO N - 1 DO
				item.key := i;
				treeLong.Insert(item)
			END;
		END;


		t := PreciseTimer.GetTicks() - t;
		Strings.FloatToStr(PreciseTimer.GetTime(t) / N_TESTS, 0, 6, 0, str);
		context.out.String("Tree time: "); context.out.String(str);

		context.out.Ln;

		t := PreciseTimer.GetTicks();
		FOR j := 0 TO N_TESTS - 1 DO
			NEW(nativeTreeLong);
			FOR i := 0 TO N - 1 DO
				nativeTreeLong.Insert(i);
			END;
		END;
		t := PreciseTimer.GetTicks() - t;
		Strings.FloatToStr(PreciseTimer.GetTime(t) / N_TESTS, 0, 6, 0, str);
		context.out.String("Native tree time: "); context.out.String(str);

*)

		NEW(treeLong);
		FOR i := 0 TO N - 1 DO
			treeLong.Insert(i)
		END;

		context.out.String("root: "); context.out.Int(treeLong.root, 0); context.out.Ln;
		FOR i := 1 TO treeLong.Count() DO
			context.out.Int(i, 0); context.out.String(": ");
			treeLong.Get(i, item);
			context.out.String("left: "); context.out.Int(item.left, 0); context.out.Char(' ');
			context.out.String("right: "); context.out.Int(item.right, 0); context.out.Char(' ');
			context.out.String("level: "); context.out.Int(item.level, 0); context.out.Char(' ');
			context.out.String("key: "); context.out.Int(item.key, 0); context.out.Ln
		END;
		context.out.Ln;

		treeLong.Delete(6);

		context.out.String("root: "); context.out.Int(treeLong.root, 0); context.out.Ln;
		FOR i := 1 TO treeLong.Count() + 1 DO
			context.out.Int(i, 0); context.out.String(": ");
			treeLong.Get(i, item);
			context.out.String("left: "); context.out.Int(item.left, 0); context.out.Char(' ');
			context.out.String("right: "); context.out.Int(item.right, 0); context.out.Char(' ');
			context.out.String("level: "); context.out.Int(item.level, 0); context.out.Char(' ');
			context.out.String("key: "); context.out.Int(item.key, 0); context.out.Ln
		END;
		context.out.Ln;


		context.out.String("done");
		context.out.Ln;
		context.out.Update

	END TestTrees;
	*)

BEGIN

END Generics.

Generics.TestStacks ~
Generics.TestVectors ~
Generics.TreeTest ~
Generics.TreeIteratorTest ~

System.Free Generics ~
