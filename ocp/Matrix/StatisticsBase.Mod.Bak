MODULE StatisticsBase; (** AUTHOR "Patrick Hunziker"; PURPOSE "tools for statistics"; *)

IMPORT MatrixBase, MathL, MatrixUtilities;

TYPE 	
	Matrix*=MatrixBase.Matrix;
	Vector*=MatrixBase.Vector;
	Datatype*=MatrixBase.Datatype;
	Array*=ARRAY[?] OF Datatype;
	
PROCEDURE SameDimension(VAR a:Array; CONST len:ARRAY [*] OF SIZE);
	BEGIN
		IF (DIM(a)#LEN(len,0)) OR (LEN(a)#len) THEN 
			NEW(a,len) 
		END;  
	END SameDimension;
	
PROCEDURE Count*(CONST a: Array):LONGINT;
VAR i:LONGINT; res:LONGINT;
BEGIN
	res:=1;
	FOR i:=0 TO DIM(a)-1 DO
		res:=res*LEN(a,i);
	END;
	RETURN res
END Count;

PROCEDURE Prod*(CONST v: Vector):Datatype;
VAR i:LONGINT; x:Datatype;
BEGIN
	x:=v[0];
	FOR i:=1 TO LEN(v,0)-1 DO x:=x*v[i] END;
	RETURN x;
END Prod;

PROCEDURE ProdS*(CONST v: ARRAY [*] OF SIZE):Datatype;
VAR i:LONGINT; x:SIZE;
BEGIN
	x:=v[0];
	FOR i:=1 TO LEN(v,0)-1 DO x:=x*v[i] END;
	RETURN Datatype(x);
END ProdS;

PROCEDURE Mean*(CONST X: Array): Datatype;
BEGIN
	RETURN SUM(X)/ProdS(LEN(X))
END Mean;

PROCEDURE MeanSquare*(CONST X: Array): Datatype;
BEGIN
	RETURN X+*X / ProdS(LEN(X))
END MeanSquare;

PROCEDURE RMS*(CONST X: Array): Datatype; (*root mean square*)
BEGIN
	RETURN MathL.sqrt(X+*X / ProdS(LEN(X)))
END RMS;

PROCEDURE KSmallest( VAR a: Vector;  n, k: LONGINT ): Datatype;
(** caution: modifies a , Algorithm by N.Wirth / Hoare, cf. N. Wirth: Algorithms & Datastructures. *)
VAR i, j, l, m: LONGINT;  x: Datatype;

	PROCEDURE swap( VAR x, y: Datatype );
	VAR z: LONGREAL;
	BEGIN
		z := x;  x := y;  y := z
	END swap;

BEGIN
	l := 0;  m := n - 1;
	WHILE (l < m) DO
		x := a[k];  i := l;  j := m;
		REPEAT
			WHILE (a[i] < x) DO INC( i ) END;
			WHILE (x < a[j]) DO DEC( j ) END;
			IF i <= j THEN swap( a[i], a[j] );  INC( i );  DEC( j ) END
		UNTIL i > j;
		IF j < k THEN l := i END;
		IF k < i THEN m := j END
	END;
	RETURN a[k]
END KSmallest;

PROCEDURE QSort*(VAR X : Vector);
	PROCEDURE Sort(l, r : LONGINT);
	VAR
		i, j : LONGINT;
		u, v : Datatype;
	BEGIN
		i := l;
		j := r;
		u := X[(l+r) DIV 2];
		REPEAT
			WHILE  (X[i] < u) DO INC(i) END;
			WHILE (u < X[j]) DO DEC(j) END;
			IF i <= j THEN
				v := X[i]; X[i] := X[j]; X[j] := v;
				INC(i); DEC(j);
			 END;
		UNTIL i > j;
		IF l < j THEN Sort(l, j) END;
		IF i < r THEN Sort(i, r) END;
	END Sort;
 BEGIN
	Sort(0, LEN(X,0)-1);
 END QSort;

 PROCEDURE DestructiveMedian*(VAR v1:Vector):Datatype;
 VAR len:LONGINT;
 BEGIN
 	len:=LEN(v1,0);
	IF ODD( len ) THEN RETURN KSmallest( v1, len, len DIV 2 )
	ELSE RETURN (KSmallest( v1, len, len DIV 2 - 1 ) + KSmallest( v1, len, len DIV 2 )) / 2
	END
 END DestructiveMedian;

 PROCEDURE Median*(CONST v:Vector):Datatype;
 VAR v1:Vector;
 BEGIN
 	v1:=v;(* leave original data intact, at the price of memory allocation*)
 	RETURN DestructiveMedian(v1)
 END Median;

 (** variance of dataset *)
 PROCEDURE Variance*(CONST v:Array):Datatype;
 VAR diff:Array;
 BEGIN
 	 diff:=v-Mean(v);
 	 RETURN (diff+*diff) / ProdS(LEN(v))
 END Variance;

 (** of full data *)
 PROCEDURE StandardDeviation*(CONST v:Array): Datatype;
 BEGIN
 	RETURN MathL.sqrt(Variance(v))
 END StandardDeviation;


	(** variance estimated from subset of data, divisor is (N-1)*)
 PROCEDURE EstimatedVariance*(CONST v:Array):Datatype;
 VAR diff:Array;
 BEGIN
 	 diff:=v-Mean(v);
 	 RETURN (diff+*diff) / (ProdS(LEN(v))-1)
 END EstimatedVariance;
 
 (** subset of data , divisor is (N-1)*)
 PROCEDURE EstimatedStandardDeviation*(CONST v:Array): Datatype;
 BEGIN
 	RETURN MathL.sqrt(EstimatedVariance(v))
 END EstimatedStandardDeviation;

 PROCEDURE Skewness*(CONST X : Array) : Datatype;
	VAR
		sigma : Datatype;
		x1: Array;
	BEGIN
		sigma:=StandardDeviation(X);
		x1:=X-Mean(X);
		RETURN  ((x1 .* x1) +* x1) / (sigma*sigma*sigma)/ ProdS(LEN(X))
	END Skewness;

PROCEDURE Kurtosis*(CONST X : Array) : Datatype;
	VAR
		variance: Datatype;
		x1,x2:Array;
	BEGIN
		variance:=Variance(X);
		x1:=X-Mean(X);
		x2:=x1.*x1;
		RETURN (x2 +* x2) / (variance*variance) / ProdS(LEN(X)) - 3;
	END Kurtosis;
	
PROCEDURE Normalize*(CONST a: Array):Array;
VAR N:LONGINT; sd: Datatype;
BEGIN
	N:=Count(a);
	RESULT:=a-SUM(a)/N;
	sd:=MathL.sqrt( RESULT+*RESULT / N);
	IF sd=0 THEN RETURN RESULT
	ELSE RETURN 1/sd * RESULT
	END;
END Normalize;

PROCEDURE NormalizeColumns*(VAR A:Matrix); (*normalizing to mean=0 and SD=1*)
VAR onesR, meanVector,sdVector: Vector; meanMatrix, sdMatrix:Matrix;
BEGIN
	NEW(onesR, LEN(A,0));
	onesR:=1; 
	meanVector := (onesR * A)/LEN(A,0);
	meanMatrix := onesR ** meanVector;
	A:=A-meanMatrix;
	sdVector := MatrixUtilities.ApplyUnaryVec(onesR * (A.*A), MathL.sqrt) / MathL.sqrt(LEN(A,0));
	sdMatrix:= onesR ** sdVector;
	A:= A ./ sdMatrix;
END NormalizeColumns;

(* subtract column mean from each column *)
PROCEDURE ZeroMeanColumns*(VAR A:Matrix);
	VAR onesR, meanVector: Vector; 
BEGIN
	NEW(onesR, LEN(A,0));
	onesR:=1;
	meanVector := (onesR * A)/LEN(A,0);
	A:=A - onesR ** meanVector;
END ZeroMeanColumns;

(*! to do: move the following proc's  to higher level modules - may not be basic statistics  *)
(** SoftMax  of a data vector = Normalized exponential; SUM=1.0
 y[i] = softmax(x[i]) = exp(x[i])/sum(exp(x)) *)
PROCEDURE SoftMax*(VAR x: Array):Array;
	BEGIN
		RESULT :=ALL(x, MathL.exp);
		RESULT:=1/SUM(RESULT) * RESULT;
		RETURN RESULT
END SoftMax;

PROCEDURE Logistic*(X : Datatype) : Datatype;  (* logistic function as nonlinear element for unit response *)
	BEGIN 
		IF X >= 18.3684002848 (*expNegligibleL*) THEN RETURN 1
		ELSIF (-X) > 18.3684002848 (*expNegligibleL*) THEN RETURN 0
		ELSE RETURN 1 / (1 + MathL.exp( -X ));  
		END;  		
	END Logistic;

(**
Normalize input such that input mean(x)=0, input SD(x)=1, then bring to [0..1] using SoftMax sigmoid transform 
 y[i] = softmax(x[i]) = exp(x[i])/sum(exp(x)) *)
PROCEDURE SoftMaxNormalize*(CONST x: Array):Array;
	BEGIN
		RESULT:=Normalize(x);
		RESULT :=ALL(RESULT, Logistic);
		RETURN RESULT
END SoftMaxNormalize;
(*
PROCEDURE Test*;
CONST a=[1,2,3,4]; b=[1,2,2,1]; c=[1,2,3,2]; d=[1,1,2,3,1]
BEGIN
	MatrixUtilities.OutVector([Skewness(a)]);
	MatrixUtilities.OutVector([Skewness(b)]);
	MatrixUtilities.OutVector([Skewness(c)]);
	MatrixUtilities.OutVector([Skewness(d)]);
	MatrixUtilities.OutVector([Kurtosis(a)]);
	MatrixUtilities.OutVector([Kurtosis(b)]);
	MatrixUtilities.OutVector([Kurtosis(c)]);
	MatrixUtilities.OutVector([Kurtosis(d)]);
END Test;
*)

(*
PROCEDURE TestNormalizeColumns*;
VAR A:Matrix;
BEGIN
	A:=[[1,2,3,4],[2,3,4,8],[3,4,5,12],[4,5,6,16]];
	NormalizeColumns(A);
	MatrixUtilities.OutMatrix(A);
END TestNormalizeColumns;
*)

PROCEDURE TestSort*;
VAR v:Vector; zero: Datatype;
BEGIN
	v:=[0, 1, -1/zero, 1/zero, 4,3,2,3,4,5];
	QSort(v);
	MatrixUtilities.OutVector(v);
END TestSort;

PROCEDURE TestMedian*;
VAR v:Vector; zero: Datatype;
BEGIN
	v:=[0, 1, -1/zero, 1/zero, 4,3,2,3,4,5];
	MatrixUtilities.OutVector(v);
	MatrixUtilities.OutVector([Median(v)])
END TestMedian;

PROCEDURE TestSoftMax*;
VAR v,v1:Vector; 
BEGIN
	v:=[0, 1, 2, 3, 4,3,2,3,4,5];
	v1:=Normalize(v);
	MatrixUtilities.OutVector([StandardDeviation(v1)]);
	MatrixUtilities.OutVector([Mean(v1)]);
	v1:=SoftMaxNormalize(v);
	MatrixUtilities.OutVector(v1);
	MatrixUtilities.OutVector([Median(v1)]);
	MatrixUtilities.OutVector([Mean(v1)]);
	MatrixUtilities.OutVector([StandardDeviation(v1)])
END TestSoftMax;

END StatisticsBase.

StatisticsBase.TestSort ~
StatisticsBase.TestMedian ~
StatisticsBase.TestSoftMax ~

System.FreeDownTo StatisticsBase ~
