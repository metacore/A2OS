(** AUTHOR "Yaroslav Romanchenko"; PURPOSE "Base Generic Collections"; *)

(*

	Module implements the base generic collection objects:
		
		Queue - simple (L)ast (I)n (F)irst (O)ut stack;
		
		DEQue - Double Ended Queue or (F)irst (I)n (F)irst (O)ut stack;
		
		Vector - simple linear container with possibilities of out of order elements' insertions and removal.
			Also sorting and searching of elements are supported.
	
	Parameters of this module are:
		
		T - any type;
		
		Less - procedure, that returns result of "less than" comparison,
			with signature "(l, r: T): BOOLEAN". Less procedure are present
			mostly for Vector's sorting and searching functionality.
		
*)

MODULE GenericCollections(TYPE T, CONST Less);

CONST
	(* Initial size of containers *)
	INITIAL_SIZE* = 16;

TYPE
	(** Abstract container *)
	Container* = OBJECT

		PROCEDURE Count*(): SIZE;
		BEGIN HALT(301)
		END Count;
		
		PROCEDURE Empty*(): BOOLEAN;
		BEGIN HALT(301)
		END Empty;
		
		PROCEDURE Reset*();
		BEGIN HALT(301)
		END Reset;
		
	END Container;
	
	PArrayT* = POINTER TO ARRAY OF T;

	(** Abstract Linear Container, based on dynamic array of T *)
	LinearContainer* = OBJECT(Container)
	VAR
		m_iSize : SIZE;
		m_pArray : PArrayT;
		
		PROCEDURE Grow();
		VAR
			pOldArray : PArrayT;
			iOldSize, i : SIZE;
		BEGIN
			pOldArray := m_pArray;
			iOldSize := m_iSize;
			m_iSize := m_iSize * 2;
			NewStorage;
			FOR i := 0 TO iOldSize - 1 DO
				m_pArray[i] := pOldArray[i]
			END
		END Grow;
		
		PROCEDURE &New*();
		BEGIN
			m_iSize := INITIAL_SIZE;
			NewStorage;
			Reset
		END New;
		
		(** Allocation of new storage of size set in m_iSize *)
		PROCEDURE NewStorage();
		BEGIN
			NEW(m_pArray, m_iSize)
		END NewStorage;
		
	END LinearContainer;
	
	(** Abstract stack *)
	Stack* = OBJECT(LinearContainer)

		PROCEDURE Pop*(VAR t: T): BOOLEAN;
		BEGIN HALT(301)
		END Pop;

		PROCEDURE Push*(CONST t: T);
		BEGIN HALT(301)
		END Push;

		PROCEDURE Top*(VAR t: T): BOOLEAN;
		BEGIN HALT(301)
		END Top;
		
	END Stack;

	(** Simple Queue or LIFO stack *)
	Queue* = OBJECT(Stack)
	VAR
		m_iPos: SIZE;

		PROCEDURE Reset*();
		BEGIN
			m_iPos := 0
		END Reset;

		PROCEDURE Count*(): SIZE;
		BEGIN
			RETURN m_iPos
		END Count;
		
		PROCEDURE Empty*(): BOOLEAN;
		BEGIN
			RETURN m_iPos = 0
		END Empty;
		
		PROCEDURE Pop*(VAR t: T): BOOLEAN;
		VAR
			bOk: BOOLEAN;
		BEGIN
			bOk := m_iPos # 0;
			IF bOk THEN
				DEC(m_iPos); t := m_pArray[m_iPos]
			END;
			RETURN bOk
		END Pop;

		PROCEDURE Push*(CONST t: T);
		BEGIN
			IF m_iPos = m_iSize THEN Grow END;
			m_pArray[m_iPos] := t;
			INC(m_iPos)
		END Push;

		PROCEDURE Top*(VAR t: T): BOOLEAN;
		VAR
			bOk: BOOLEAN;
		BEGIN
			bOk := m_iPos # 0;
			IF bOk THEN t := m_pArray[m_iPos - 1] END;
			RETURN bOk
		END Top;

	END Queue;
	
	(** Double Ended Queue or FIFO stack *)
	DEQue* = OBJECT(Stack)
	VAR
		m_iHead, m_iTail: SIZE;

		PROCEDURE Reset*();
		BEGIN
			m_iHead := 0;
			m_iTail := 0
		END Reset;

		PROCEDURE Count*(): SIZE;
		BEGIN
			RETURN m_iTail - m_iHead
		END Count;
		
		PROCEDURE Empty*(): BOOLEAN;
		BEGIN
			RETURN m_iTail - m_iHead = 0
		END Empty;

		PROCEDURE Grow();
		VAR
			iCount, i: SIZE;
		BEGIN
			iCount := m_iTail - m_iHead;
			IF iCount = 0 THEN
				(* DEQue is empty, simply reset... *)
				m_iHead := 0; m_iTail := 0
			ELSIF iCount * 2 > m_iSize THEN
				(* Must grow, call default implementation *)
				Grow^
			ELSE
				(* may for now simply shift,
					to move free space to the end *)
				FOR i := 0 TO iCount - 1 DO
					m_pArray[i] := m_pArray[m_iHead + i]
				END;
				m_iHead := 0; m_iTail := iCount
			END
		END Grow;

		PROCEDURE Pop*(VAR t: T): BOOLEAN;
		VAR
			bOk: BOOLEAN;
		BEGIN
			bOk := m_iHead # m_iTail;
			IF m_iHead # m_iTail THEN
				t := m_pArray[m_iHead]; INC(m_iHead)
			END;
			RETURN bOk
		END Pop;
		
		PROCEDURE Push*(CONST t: T);
		BEGIN
			IF m_iTail = m_iSize THEN Grow END;
			m_pArray[m_iTail] := t;
			INC(m_iTail)
		END Push;

		PROCEDURE Top*(VAR t: T): BOOLEAN;
		VAR
			bOk: BOOLEAN;
		BEGIN
			bOk := m_iHead # m_iTail;
			IF bOk THEN t := m_pArray[m_iHead] END;
			RETURN bOk
		END Top;

	END DEQue;

	Vector* = OBJECT(LinearContainer)
	VAR
		m_iPos: SIZE;
		f_bSorted: BOOLEAN;
		
		PROCEDURE Add*(CONST t: T): SIZE;
		VAR
			pos: SIZE;
		BEGIN
			(* Append as to unsorted array *)
			f_bSorted := FALSE;
			IF m_iPos = m_iSize THEN Grow END;
			pos := m_iPos;
			m_pArray[pos] := t;
			INC(m_iPos);
			RETURN pos
		END Add;

		PROCEDURE Reset*();
		BEGIN
			f_bSorted := FALSE;
			m_iPos := 0
		END Reset;

		PROCEDURE Count*(): SIZE;
		BEGIN
			RETURN m_iPos
		END Count;
		
		PROCEDURE Empty*(): BOOLEAN;
		BEGIN
			RETURN m_iPos = 0
		END Empty;
		
		PROCEDURE FindBinary(CONST t: T; VAR bFound: BOOLEAN): SIZE;
		VAR
			lower, middle, upper: SIZE;
		BEGIN
			bFound := FALSE;
			IF m_iPos = 0 THEN RETURN 0 END;
			lower := 0;
			upper := m_iPos - 1;
			WHILE lower <= upper DO
				middle := lower + (upper - lower) DIV 2;
				IF Less(m_pArray[middle], t) THEN
					lower := middle + 1
				ELSIF Less(t, m_pArray[middle]) THEN
					upper := middle - 1
				ELSE
					bFound := TRUE;
					RETURN middle
				END;
			END;
			IF lower <= upper THEN
				RETURN upper
			ELSE
				RETURN lower
			END;
		END FindBinary;

		PROCEDURE FindSequentially(CONST t: T): SIZE;
		VAR
			i: SIZE;
		BEGIN
			i := 0;
			WHILE i < m_iPos DO
				IF ~Less(m_pArray[i], t) & ~Less(t, m_pArray[i]) THEN
					RETURN i
				END;
				INC(i)
			END;
			RETURN -1
		END FindSequentially;
		
		PROCEDURE Get*(pos: SIZE; VAR t: T);
		BEGIN
			ASSERT((pos >= 0) & (pos < m_iPos), 101);
			t := m_pArray[pos]
		END Get;

		PROCEDURE GetSorted*(): BOOLEAN;
		BEGIN
			RETURN f_bSorted
		END GetSorted;
		
		PROCEDURE IndexOf*(CONST t: T): SIZE;
		VAR
			pos: SIZE;
			bFound: BOOLEAN;
		BEGIN
			IF f_bSorted THEN
				pos := FindBinary(t, bFound);
				IF bFound THEN
					RETURN pos
				ELSE
					RETURN -1
				END
			ELSE
				RETURN FindSequentially(t)
			END
		END IndexOf;

		PROCEDURE Insert*(pos: SIZE; CONST t: T);
		VAR
			iSrc: SIZE;
		BEGIN
			ASSERT((pos >= 0) & (pos < m_iPos), 101);
			(* Insert as to unsorted array *)
			f_bSorted := FALSE;
			IF m_iPos = m_iSize THEN
				Grow
			END;
			(* Shift content of array *)
			iSrc := m_iPos - 1;
			WHILE iSrc >= pos DO
				m_pArray[iSrc + 1] := m_pArray[iSrc];
				DEC(iSrc)
			END;
			(* Put t at pos position *)
			m_pArray[pos] := t;
			INC(m_iPos)
		END Insert;
		
		PROCEDURE QuickSort(l, r: SIZE);
		VAR
			i, j, x: SIZE;
			t: T;
		BEGIN
			REPEAT
				i := l;
				j := r;
				x := l + (r - l) DIV 2;
				REPEAT
					WHILE Less(m_pArray[i], m_pArray[x]) DO
						INC(i)
					END;
					WHILE Less(m_pArray[x], m_pArray[j]) DO
						DEC(j)
					END;
					IF i <= j THEN
						(* Swap i'th and j'th element *)
						t := m_pArray[i];
						m_pArray[i] := m_pArray[j];
						m_pArray[j] := t;
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

		PROCEDURE Remove*(index: SIZE);
		VAR
			iDst: SIZE;
		BEGIN
			ASSERT((index >= 0) & (index < m_iPos), 101);
			(* Shift content of array *)
			iDst := index;
			WHILE iDst < m_iPos - 1 DO
				m_pArray[iDst] := m_pArray[iDst + 1];
				INC(iDst)
			END;
			DEC(m_iPos)
		END Remove;

		PROCEDURE Set*(index: SIZE; CONST t: T);
		BEGIN
			ASSERT((index >= 0) & (index < m_iPos), 101);
			m_pArray[index] := t
		END Set;

		PROCEDURE SetSorted*(bValue: BOOLEAN);
		BEGIN
			IF f_bSorted = bValue THEN
				RETURN
			END;
			f_bSorted := bValue;
			IF ~f_bSorted OR (m_iPos = 0) THEN
				RETURN
			END;
			QuickSort(0, m_iPos - 1)
		END SetSorted;

	END Vector;
	
BEGIN
	
END GenericCollections.

