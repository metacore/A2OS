(* Copyright 2005-2006, Markus Heule, ETH Zurich *)

MODULE OSCQueue;  (** AUTHOR "heulemar"; PURPOSE "OpenSoundControl: PriorityQueue with OSCBundles"; *)

(*
	This module contains an queue with OSCBundles. The OSCService uses this queue internally to store OSCBundles for later processing.
	The queue uses an minheap in an array of variable size to store the Bundles.
	Queueing and dequeueing runs in O(log(#queued bundles)).
*)

IMPORT OSC, KernelLog;

CONST
	InitHeapSize = 1024; (* inital size of the array which holds the OSCBundles *)
	Trace* = FALSE;

TYPE
	PacketArray = POINTER TO ARRAY OF OSC.OSCBundle;

	OSCQueue* = OBJECT
		VAR
			q: PacketArray; (* minheap *)
			size: SIGNED32; (* the number of queued elements *)

		PROCEDURE &Init*;
		BEGIN
			NEW(q, InitHeapSize);
			size := 0;
		END Init;

		(* used internally to increase the size of the array holding the minheap. *)
		PROCEDURE grow;
		VAR
			biggerq: PacketArray;
			i: SIZE;
		BEGIN
			NEW(biggerq, 2*LEN(q));
			FOR i:=0 TO LEN(q)-1 DO biggerq[i] := q[i]; END;
			q := biggerq;
		END grow;

		PROCEDURE IsEmpty*(): BOOLEAN;
		BEGIN {EXCLUSIVE}
			RETURN size = 0;
		END IsEmpty;

		(* queues a new bundle *)
		PROCEDURE Queue*(p: OSC.OSCBundle);
		VAR
			element, parent: SIGNED32;
			temp: OSC.OSCBundle;
		BEGIN { EXCLUSIVE }
			IF Trace THEN KernelLog.String('OSCQueue: Insert with bundle: '); KernelLog.Ln; p.dump(0); KernelLog.Ln; END;
			IF size = LEN(q) THEN grow; END;
			q[size] := p; (* insert element at new position *)
			element := size; parent := (element-1) DIV 2;
			INC(size);
			WHILE (element > 0) & q[element].IsBefore(q[parent]) DO (* swap element with parent element to restore heap invariant *)
				temp := q[parent]; q[parent] := q[element]; q[element] := temp;
				element := parent; parent := (element-1) DIV 2;
			END;
			IF Trace THEN KernelLog.String('Insertion at element: '); KernelLog.Int(element, 4); KernelLog.Ln; END;
		END Queue;

		(* returns the bundle with the smalles timestamp without dequeing it *)
		PROCEDURE Peek*(): OSC.OSCBundle;
		BEGIN
			ASSERT(size > 0);
			RETURN q[0];
		END Peek;

		(* returns the bundle with the smalles timestamp and dequeues it *)
		PROCEDURE Dequeue*(): OSC.OSCBundle;
		VAR
			min, temp: OSC.OSCBundle;
			element, left, right: SIGNED32;
		BEGIN { EXCLUSIVE }
			min := q[0];
			q[0] := q[size-1]; DEC(size); (* stores the last element in the free position. the invariant is potentially violated *)
			element := 0; left := 1; right := 2;
			(* restore the heap invariant by swapping the element with the smaller child *)
			WHILE ((size-1) >= right ) & (* there are 2 childs *)
				 (~q[element].IsBefore(q[left]) OR
				 ~q[element].IsBefore(q[right])) DO
				(* lift smaller child *)
				IF q[left].IsBefore(q[right]) THEN
					temp := q[element]; q[element] := q[left]; q[left] := temp;
					element := left;
				ELSE
					temp := q[element]; q[element] := q[right]; q[right] := temp;
					element := right;
				END;
				left := 2*element+1;
				right := 2*element+2;
			END;
			(* there may be only one child *)
			IF ((size-1) = left) & (~q[element].IsBefore(q[left])) THEN
				temp := q[element]; q[element] := q[left]; q[left] := temp;
				element := left;
			END;
			(* heap restored *)
			RETURN min;
		END Dequeue;

		(* checks the invariant of the heap. Used only in the testprocedures of this module *)
		PROCEDURE checkheap(idx: SIGNED32): BOOLEAN;
		VAR
			left, right: SIGNED32;
			res: BOOLEAN;
		BEGIN
			left := idx*2+1; right := idx*2+2;
			IF (left < size) & ~q[idx].IsBeforeEqual(q[left]) THEN RETURN FALSE; END;
			IF (right < size) & ~q[idx].IsBeforeEqual(q[right]) THEN RETURN FALSE; END;
			res := TRUE;
			IF (left < size) THEN res := res & checkheap(left); END;
			IF (right < size) THEN res := res & checkheap(right); END;
			RETURN res;
		END checkheap
	END OSCQueue;

	(* testprocedure *)
	PROCEDURE TestQueue*;
	VAR
		b: OSC.OSCBundle;
		q: OSCQueue;
		tt: OSC.OSCTimeTag;
		i: SIGNED32;
	BEGIN
		NEW(q);
		NEW(tt); tt.Set(10,0); NEW(b, tt, NIL, 0); q.Queue(b);
		IF ~ q.checkheap(0) THEN KernelLog.String('Heapviolation!'); KernelLog.Ln; END;
		NEW(tt); tt.Set(11,0); NEW(b, tt, NIL, 0); q.Queue(b);
		IF ~ q.checkheap(0) THEN KernelLog.String('Heapviolation!'); KernelLog.Ln; END;
		NEW(tt); tt.Set(14,0); NEW(b, tt, NIL, 0); q.Queue(b);
		IF ~ q.checkheap(0) THEN KernelLog.String('Heapviolation!'); KernelLog.Ln; END;
		NEW(tt); tt.Set(12,0); NEW(b, tt, NIL, 0); q.Queue(b);
		IF ~ q.checkheap(0) THEN KernelLog.String('Heapviolation!'); KernelLog.Ln; END;
		NEW(tt); tt.Set(13,100); NEW(b, tt, NIL, 0); q.Queue(b);
		IF ~ q.checkheap(0) THEN KernelLog.String('Heapviolation!'); KernelLog.Ln; END;
		NEW(tt); tt.SetImmediately; NEW(b, tt, NIL, 0); q.Queue(b);
		IF ~ q.checkheap(0) THEN KernelLog.String('Heapviolation!'); KernelLog.Ln; END;
		NEW(tt); tt.Set(13,101); NEW(b, tt, NIL, 0); q.Queue(b);
		IF ~ q.checkheap(0) THEN KernelLog.String('Heapviolation!'); KernelLog.Ln; END;
		NEW(tt); tt.Set(13,99); NEW(b, tt, NIL, 0); q.Queue(b);
		IF ~ q.checkheap(0) THEN KernelLog.String('Heapviolation!'); KernelLog.Ln; END;
		NEW(tt); tt.SetImmediately; NEW(b, tt, NIL, 0); q.Queue(b);
		IF ~ q.checkheap(0) THEN KernelLog.String('Heapviolation!'); KernelLog.Ln;
			FOR i:=0 TO q.size-1 DO q.q[i].dump(0); END; END;
		NEW(tt); tt.Set(9,0); NEW(b, tt, NIL, 0); q.Queue(b);
		IF ~ q.checkheap(0) THEN KernelLog.String('Heapviolation!'); KernelLog.Ln; END;
		NEW(tt); tt.Set(15,0); NEW(b, tt, NIL, 0); q.Queue(b);
		IF ~ q.checkheap(0) THEN KernelLog.String('Heapviolation!'); KernelLog.Ln; END;
		KernelLog.String('size: '); KernelLog.Int(q.size, 4); KernelLog.Ln;
		KernelLog.String('isempty:'); KernelLog.Boolean(q.IsEmpty()); KernelLog.Ln;
		WHILE ~q.IsEmpty() DO
			b := q.Dequeue(); b.dump(0);
			IF ~ q.checkheap(0) THEN KernelLog.String('Heapviolation!'); KernelLog.Ln; END;
		END;
		NEW(q);
		NEW(tt); tt.Set(1,0); NEW(b, tt, NIL, 0); q.Queue(b);
		IF ~ q.checkheap(0) THEN KernelLog.String('Heapviolation!'); KernelLog.Ln; END;
		NEW(tt); tt.Set(3,0); NEW(b, tt, NIL, 0); q.Queue(b);
		IF ~ q.checkheap(0) THEN KernelLog.String('Heapviolation!'); KernelLog.Ln; END;
		NEW(tt); tt.Set(5,0); NEW(b, tt, NIL, 0); q.Queue(b);
		IF ~ q.checkheap(0) THEN KernelLog.String('Heapviolation!'); KernelLog.Ln; END;
		NEW(tt); tt.Set(8,0); NEW(b, tt, NIL, 0); q.Queue(b);
		IF ~ q.checkheap(0) THEN KernelLog.String('Heapviolation!'); KernelLog.Ln; END;
		NEW(tt); tt.Set(10,100); NEW(b, tt, NIL, 0); q.Queue(b);
		IF ~ q.checkheap(0) THEN KernelLog.String('Heapviolation!'); KernelLog.Ln; END;
		KernelLog.String('size: '); KernelLog.Int(q.size, 4); KernelLog.Ln;
		KernelLog.String('isempty:'); KernelLog.Boolean(q.IsEmpty()); KernelLog.Ln;
		WHILE ~q.IsEmpty() DO
			b := q.Dequeue(); b.dump(0);
			IF ~ q.checkheap(0) THEN KernelLog.String('Heapviolation!'); KernelLog.Ln; END;
		END;
		KernelLog.String('TestQueue done');
	END TestQueue;

END OSCQueue.

OSCQueue.TestQueue ~
