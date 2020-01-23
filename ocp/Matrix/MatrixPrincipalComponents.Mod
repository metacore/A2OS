MODULE MatrixPrincipalComponents;   (**  AUTHOR "Patrick Hunziker"; PURPOSE "Principal Component Analysis";  **)

IMPORT MatrixBase, MatrixSVD, Util:= MatrixUtilities, MathL;

TYPE
	Datatype = MatrixBase.Datatype;
	Matrix = MatrixBase.Matrix;
	Vector = MatrixBase.Vector;

(*precondition:
see Wikipedia: Principal_Component_Analysis
XT: n rows, each representing one multiparameter observation
	m columns, each representing a parameter
XT needs to have empirical mean of 0, i.e. subtration of mean from each column;
YT: n rows of observations
 	m columns (or M largest components)
*)

TYPE PCA*= OBJECT (MatrixBase.Solver)
	VAR X, U: Matrix; svd: MatrixSVD.Solver;
		Y, YT, SL: Matrix;
		initialized, ytdone:BOOLEAN;
		PROCEDURE &Init*(CONST XT: Matrix);
		BEGIN
			ytdone:=FALSE;
			IF LEN(XT,0)=0 THEN
				initialized:=FALSE; RETURN
			ELSE
				X:=XT`;
				NEW(svd,X);
				svd.SortDescending;
				initialized:=TRUE;
			END;
		END Init;

		(* computing PCA through SVD. as an alternative, see iterative computation, http://http://en.wikipedia.org/wiki/Principal_components_analysis *)
		PROCEDURE PrincipalComponents*():Matrix; (*  returns YT *)
		BEGIN
			ASSERT(initialized);
			IF ytdone THEN RETURN YT
			ELSE
				(*YT:= svd.vt`*svd.w;*)
				YT:= svd.vtSorted`*svd.wSorted;
				ytdone:=TRUE;
				RETURN YT
			END;
		END PrincipalComponents;

		PROCEDURE LargestComponents*(M:SIGNED32): Matrix; (*returns Y with reduced size (not YT ! )*)
		BEGIN
			ASSERT(initialized & (M#0));
			SL:=svd.wSorted[..M-1];
			Y:=SL*svd.vtSorted;
			RETURN Y
		END LargestComponents;

		PROCEDURE Axes*():Matrix; (* principal axes with unit length *)
		VAR axislengths,unit: Vector; nullmatrix: Matrix; i:SIZE; scale: Datatype;
		BEGIN
			IF ~ytdone THEN RETURN nullmatrix END;
			NEW(U, LEN(YT,0), LEN(YT,1));
			NEW(unit, LEN(YT,0)); unit:=1;
			axislengths:=unit*(YT.*YT);
			FOR i:=0 TO LEN(axislengths,0)-1 DO
				IF ABS(axislengths[i]) > 1.0E-6 THEN (*? eps handling can be improved*)
					scale:=1/MathL.sqrt(axislengths[i]);
					U[.., i]:= YT[..,i]*scale;
				ELSE
					U[.., i]:=0;
				END;
			END;
			RETURN U;
		END Axes;

	END PCA;

	PROCEDURE Test*;
	VAR XT: Matrix;
		pca:PCA;
		svd: MatrixSVD.Solver;
		C,U:Matrix;
	BEGIN
		XT:=[[3,1,0,0],[-3,0,1,0],[0,2,0,0],[0,-2,0,1],[0,-1,1,0],[0,0,-1,-1]];
		NEW(pca,XT);
		NEW(svd, XT); svd.SortDescending;
		Util.OutMatrix(XT);
		C:=pca.PrincipalComponents(); (* this is YT *)
		Util.OutMatrix(C);
		Util.OutMatrix(pca.LargestComponents(3)`); (* this is Y, i.e. needs to be transposed compared to above*)
		U:=pca.Axes();
		Util.OutMatrix(U);
		(*Util.OutMatrix(U*U`);*) (*why not orthonormal ?*)
		Util.OutVector( (C.*C)*[1,1,1,1,1,1]);  (*check rowwise variance*)
		Util.OutVector( [1,1,1,1,1,1]*(C.*C)); (*check columnwise variance*)
		Util.OutVector( [1,1,1,1,1,1]*(U.*U)); (*check columnwise unit vector length*)
		
	END Test;

END MatrixPrincipalComponents.

System.Free MatrixPrincipalComponents ~
System.FreeDownTo MatrixUtilities ~
MatrixPrincipalComponents.Test ~
fofPC.Compile \s * ~
fofPC.Compile \f * ~
OFormatter.Format *

