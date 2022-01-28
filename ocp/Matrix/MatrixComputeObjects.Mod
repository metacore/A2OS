MODULE MatrixComputeObjects; (** AUTHOR "Patrick Hunziker"; PURPOSE "Active Objects for Computation"; *)

IMPORT MatrixBase, SYSTEM, Objects, Streams, KernelLog;

TYPE Notifier* = PROCEDURE {DELEGATE};
	Computor*= PROCEDURE {DELEGATE};


TYPE
	Datatype=MatrixBase.Datatype;
	Matrix=MatrixBase.Matrix;
	Vector=MatrixBase.Vector;
	Array= ARRAY [?] OF Datatype;
	Scalar=Datatype;

	ComputeObject*= OBJECT
		VAR
			Notify*,Cleanup: Notifier;
			Writer*: Streams.Writer;
			CService:ComputeAgent;
			ready, wait*, done*: BOOLEAN;
			priority*: SIGNED32;
			next: ComputeObject;
			result: ARRAY 16 OF CHAR;
		PROCEDURE compute*; END compute; (*prototype*)
		PROCEDURE computeDistributed*; END computeDistributed; (*prototype*)
		PROCEDURE Go; BEGIN {EXCLUSIVE} wait:=FALSE; END Go;
		PROCEDURE WaitReady*; BEGIN {EXCLUSIVE} AWAIT(done) END WaitReady;
	BEGIN {ACTIVE}
			BEGIN{EXCLUSIVE} AWAIT(~wait) END;
			INC(objects); INC(cumulobjects); (*debug*)
			(*Objects.SetPriority(priority);*)
			compute;
			IF Notify#NIL THEN Notify END;
			IF Cleanup#NIL THEN Cleanup END;
			DEC(objects);
			BEGIN {EXCLUSIVE} done:=TRUE; END;
	END ComputeObject;

TYPE
	ComputeMMObject*= OBJECT (ComputeObject)
		VAR A,B,C: Matrix;
		PROCEDURE &Init*(CONST A,B: Matrix; VAR C:Matrix; Notify: Notifier; priority: SIGNED32);
		BEGIN
			SELF.A:=ALIAS OF A;
			SELF.B:=ALIAS OF B;
			SELF.C:=ALIAS OF C;
			SELF.Notify:=Notify;
			wait:=FALSE; (*debug*)
			SELF.priority:=MIN(Objects.High,MAX(priority,Objects.Low));
			Objects.SetPriority(SELF.priority);
		END Init;
	END ComputeMMObject;

	Mul* = OBJECT (ComputeMMObject)
		PROCEDURE compute;
		BEGIN
			IF Distributed & (CService#NIL) THEN
				CService.Request("MulMM", LEN(A,0)*LEN(A,1)*LEN(B,1), LEN(A,0)*LEN(A,1)+LEN(B,0)*LEN(B,1), LEN(A,0)*LEN(B,1), Objects.Normal); (*request a compute service with given compute complexity*)
				CService.SetMatrix(A);
				CService.SetMatrix(B);
				CService.GetMatrix(C, result);
					(*to do: handle timeout*)
					(*CAVE: C may not be protected against multiple access because it was allocated with "ZEROCOPY"*)
					(*relies on blocking behaviour  to return only when finished*)
			ELSE C:=A * B (* default / fallback to local computation*)
			END;
		END compute;
	END Mul;

	MulAdd* = OBJECT (ComputeMMObject)
		PROCEDURE compute;
		BEGIN
			C:=C+A*B;
		END compute;
	END MulAdd;

	MulSub* = OBJECT (ComputeMMObject)
		PROCEDURE compute;
		BEGIN
			C:=C-A*B;
		END compute;
	END MulSub;

	MulSub2* = OBJECT (ComputeMMObject)
		VAR
			M1,M2:MulSub2;
			M:MulSub;
			done1,done2:BOOLEAN;
			half,divisor:SIZE;
		PROCEDURE Done1; BEGIN {EXCLUSIVE} done1:=TRUE END Done1;
		PROCEDURE Done2; BEGIN {EXCLUSIVE} done2:=TRUE END Done2;
		PROCEDURE Done12; BEGIN {EXCLUSIVE} done1:=TRUE; done2:=TRUE END Done12;
		PROCEDURE compute;
		BEGIN
			divisor:=16 DIV SIZEOF(Datatype);
			DEC(objects); (*do not count self if task is delegated*)
			IF LEN(A,0)>512 THEN
				half:=LEN(A,0) DIV 2 DIV divisor * divisor; (*maintain 128 Bit alignment of chunks*)
				NEW(M1, A[..half-1], B, C[..half-1], Done1,priority);
				NEW(M2, A[half..], B, C[half..], Done2,MIN(Objects.High,MAX(priority-1,Objects.Low)));
			ELSIF LEN(B,1) >512 THEN
				half:=LEN(B,1) DIV 2 DIV divisor * divisor; (*maintain 128 Bit alignment of chunks*)
				NEW(M1, A, B[..,..half-1], C[..,..half-1], Done1,priority);
				NEW(M2, A, B[..,half..], C[..,half..], Done2,MIN(Objects.High,MAX(priority-1,Objects.Low)));
			ELSE
				NEW(M, A, B, C, Done12,priority);
			END;
			INC(objects);
			BEGIN {EXCLUSIVE} AWAIT(done1 & done2) END;
		END compute;
	END MulSub2;

TYPE
	ComputeMVObject*= OBJECT (ComputeObject) (* for operations of type "Vector := Matrix op Vector" ; *)
		VAR A: Matrix;
		B,C: Vector;
		PROCEDURE &Init*(CONST A: Matrix; CONST B: Vector; VAR C:Vector; Notify: Notifier; priority: SIGNED32);
		BEGIN
			SELF.A:=ALIAS OF A;
			SELF.B:=ALIAS OF B;
			SELF.C:=ALIAS OF C;
			SELF.Notify:=Notify;
			wait:=FALSE; (*debug*)
			SELF.priority:=MIN(Objects.High,MAX(priority,Objects.Low));
		END Init;
	END ComputeMVObject;

	MulMV* = OBJECT (ComputeMVObject)
		PROCEDURE compute;
		BEGIN
			C:=A*B;
		END compute;
	END MulMV;

	SolveMV* = OBJECT (ComputeMVObject)	(*solve linear system of equations Ax=b *)
	END SolveMV;

TYPE
	ComputeMSObject*= OBJECT (ComputeObject) (* for operations of type "Matrix := Op(Matrix,Scalar)" ; *)
		VAR A: Matrix;
		B: Matrix;
		s: Datatype;
		PROCEDURE &Init*(CONST A: Matrix; VAR B: Matrix; s: Datatype; Notify: Notifier; priority: SIGNED32);
		BEGIN
			SELF.A:=ALIAS OF A;
			SELF.B:=ALIAS OF B;
			SELF.s:=s;
			SELF.Notify:=Notify;
			wait:=FALSE; (*debug*)
			SELF.priority:=MIN(Objects.High,MAX(priority,Objects.Low));
		END Init;
	END ComputeMSObject;

	ScaleAddM* = OBJECT (ComputeMSObject)
		PROCEDURE compute;
		BEGIN
			B:=B+s*A;
		END compute;
	END ScaleAddM;

TYPE ComputeQueue=OBJECT
	VAR first, (*linked list of objects waiting to compute*)
		tail: ComputeObject;
		nActive: SIGNED32; (*currently computing processes*)
		maxProcesses: SIGNED32;
	PROCEDURE Add(object:ComputeObject);
	BEGIN {EXCLUSIVE}
		object.next:=first; first:=object;
	END Add;
	PROCEDURE Done;
		BEGIN {EXCLUSIVE} DEC(nActive)
		END Done;
	PROCEDURE ActivatePriority;
	VAR o,this:ComputeObject;
	BEGIN
		BubbleSort;
		o:=first;
		IF first=NIL THEN RETURN
		ELSIF first.next=NIL THEN this:=first; first:=NIL; INC(nActive); this.Cleanup:=Done; this.Go;
		ELSE
			WHILE first.next.next#NIL DO first.next:=first.next.next END;
			this:=first.next;
			first.next:=NIL;
			INC(nActive); this.Cleanup:=Done; this.Go;
		END;
		(*AosOut.String("nActive: "); AosOut.Int(nActive,6); AosOut.Ln; *)
	END ActivatePriority;

	PROCEDURE BubbleSort; (*bubble sorts the highest priority element to the last position*)
	VAR o, dummy:ComputeObject;
	BEGIN
		IF (first=NIL) OR (first.next =NIL) THEN RETURN
		ELSIF first.priority > first.next.priority THEN first.next.next:=first; first:=first.next;
		END;
		o:=first;
		WHILE (o.next#NIL) & (o.next.next#NIL) DO
			IF o.next.priority > o.next.next.priority THEN tail:= o.next.next.next; o.next.next.next:=o.next; o.next:=o.next.next; o.next.next.next:=tail; END;
		END;
	END BubbleSort;

	BEGIN {ACTIVE}
		LOOP
			BEGIN{EXCLUSIVE} AWAIT( (first#NIL) & (nActive < maxProcesses)) END;
			ActivatePriority;
		END;
	END ComputeQueue;



	TYPE ComputeAgent* = OBJECT
		VAR
			W: Streams.Writer; R:Streams.Reader;
			done*:BOOLEAN;

		PROCEDURE &Request*(CONST Operation: ARRAY OF CHAR; Flops, SendSize, RecvSize: SIZE; priority: SIGNED32);
		BEGIN
			(* choose server according to task characteristics *)

		END Request;

		PROCEDURE SetMatrix(CONST M: Matrix);
		VAR r,c:SIZE;
		BEGIN
			W.RawLInt(LEN(M,0)(SIGNED32)); W.RawLInt(LEN(M,1)(SIGNED32));
			FOR r:=0 TO LEN(M,0)-1 DO
				FOR c:=0 TO LEN(M,1)-1 DO
					W.RawLReal(M[r,c])
				END;
			END;
		END SetMatrix;

		PROCEDURE GetMatrix(VAR M:Matrix; VAR code: ARRAY OF CHAR);
		VAR rows,cols,r,c:SIGNED32;
		BEGIN
			R.RawLInt(rows); R.RawLInt(cols);
			IF (LEN(M,0)#rows) OR (LEN(M,1)#cols) THEN NEW(M,rows,cols) END;
			FOR r:=0 TO rows-1 DO
				FOR c:=0 TO cols-1 DO
					R.RawLReal(M[r,c])
				END;
			END;
		END GetMatrix;

	END ComputeAgent;


VAR objects, cumulobjects*: SIGNED32;
	Distributed*:BOOLEAN;


	PROCEDURE WriteM(Writer:Streams.Writer; CONST M:Matrix);
	BEGIN

	END WriteM;

	PROCEDURE ReadM(Writer:Streams.Reader; VAR M:Matrix);
	BEGIN
	END ReadM;

	PROCEDURE Test*;
	VAR A, A0, A1, A2, A3, A4, A5, A6, A7, B, B1, C, C1: Matrix;
		mul:Mul;
		muladd:MulAdd;
		mulsub:MulSub;
		mulsub2:MulSub2;
	BEGIN
		A:=[[1,2,3,4],[1,1,2,2],[1,1,3,3],[2,2,4,4]];
		B:=A;
		C:=A;
		A1:=B*C;
		A0:=A; A0:=0;
		NEW(mul,B,C,A0,NIL,Objects.Normal);

		A2:=A;
		A3:=A;
		A2:=A2+B*C;
		NEW(muladd,B,C, A3,NIL,Objects.Normal);

		A4:=A;
		A5:=A;
		A4:=A4-B*C;
		NEW(mulsub,B,C,A5,NIL,Objects.Normal);

		A6:=A;
		A7:=A;
		A6:=A6-B*C;
		NEW(mulsub2,B,C,A7,NIL,Objects.Normal);

		(*BEGIN{EXCLUSIVE} AWAIT(mul.done & muladd.done & mulsub.done & mulsub2.done) END;*)
		mul.WaitReady; muladd.WaitReady; mulsub.WaitReady; mulsub2.WaitReady;
		KernelLog.String("A"); KernelLog.Int(ENTIER(A+*A),12); KernelLog.Ln;
		KernelLog.String("A0"); KernelLog.Int(ENTIER(A0+*A0),12); KernelLog.Ln;
		KernelLog.String("A1"); KernelLog.Int(ENTIER(A1+*A1),12); KernelLog.Ln;
		KernelLog.String("A2"); KernelLog.Int(ENTIER(A2+*A2),12); KernelLog.Ln;
		KernelLog.String("A3"); KernelLog.Int(ENTIER(A3+*A3),12); KernelLog.Ln;
		KernelLog.String("A4"); KernelLog.Int(ENTIER(A4+*A4),12); KernelLog.Ln;
		KernelLog.String("A5"); KernelLog.Int(ENTIER(A5+*A5),12); KernelLog.Ln;
		KernelLog.String("A6"); KernelLog.Int(ENTIER(A6+*A6),12); KernelLog.Ln;
		KernelLog.String("A7"); KernelLog.Int(ENTIER(A7+*A7),12); KernelLog.Ln;
	END Test;


BEGIN
	objects:=0;
END MatrixComputeObjects.

MatrixComputeObjects.Test ~

SystemTools.FreeDownTo MatrixComputeObjects ~
