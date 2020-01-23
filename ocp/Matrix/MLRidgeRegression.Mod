MODULE MLRidgeRegression;
(**
	DESCRIPTION:
		Data approximation using ridge regression model with kernel extension (representer theorem for Reproducing Kernel Hilbert Spaces (RKHS))

	AUTHOR:
		Alexey Morozov
*)

IMPORT
	MLBase, MLKernels, ErrorBase, MatrixStandardSolvers, Strings;

TYPE
	Scalar = MLBase.Scalar;
	Vector = MLBase.Vector;
	Matrix = MLBase.Matrix;

	Regressor* = OBJECT(MLBase.LearningMachine)
	VAR
		lambda-: Scalar;
		kernType-: INTEGER;
		kernParams-: Vector;
		X: Matrix;
		alphas: Vector;

		PROCEDURE &Init;
		BEGIN
			kernType := MLKernels.Linear;
			lambda := 1;
		END Init;


		(*
			DESCRIPTION:
				Set kernel used for classification
			INPUTS:
				kernType - kernel type code
				kernParams - array of kernel parameters
			REMARKS:
				after you set a new type of kernel you must redo learning of the regressor!
		*)
		PROCEDURE SetKernel*(kernType: INTEGER; CONST kernParams: Vector);
		BEGIN
			isTrained := FALSE; (* reset classifier *)

			SELF.kernType := kernType;
			SELF.kernParams := kernParams;
		END SetKernel;

		(*
			DESCRIPTION:
				Setup of the regularization parameter
			INPUTS:
				lambda - factor defining tradeoff between quality of data fit and smoothness of the solution
		*)
		PROCEDURE SetRegularization*(lambda: Scalar);
		BEGIN
			SELF.lambda := lambda;
		END SetRegularization;

		(*
			DESCRIPTION:
				Learning input/output relation
			INPUTS:
				X - set of input samples [nSamples x nDims]
				y - output given by supervisor [nSamples]
		*)
		PROCEDURE Learn*(CONST X: Matrix; CONST y: Vector);
		BEGIN
			LearnScalarN(X,y);
		END Learn;

		(*
			DESCRIPTION:
				Learning input/output relation
			INPUTS:
				X - set of input points [nSamples x nDims]
				y - output given by supervisor [nSamples]
		*)
		PROCEDURE LearnScalarN*(CONST X: Matrix; CONST y: Vector);
		VAR
			i: SIZE;
			A: Matrix;
			solver: MatrixStandardSolvers.LU;
		BEGIN
			IF LEN(X,0) = LEN(y) THEN
				(* compose a linear system of equations for finding optimal solution in the form SUM over i {alphas_i K(x_i,x)} *)
				A := MLKernels.KernelMtx(X,X,kernType,kernParams);

				(* add diagonal matrix for regularizing the problem *)
				FOR i := 0 TO LEN(A,0)-1 DO
					A[i,i] := A[i,i] + lambda;
				END;

				IF kernType # MLKernels.ThinPlate THEN
					NEW(solver,A);
					alphas := solver.Solve(y);
					SELF.X := X;
					isTrained := TRUE;
				ELSE
					Error('LearnScalarN','thin plate spline kernel regression is not yet implemented!');
				END;
			ELSE
				Error('LearnScalarN','inputs have incompatible sizes!');
			END;
		END LearnScalarN;

		(*
			DESCRIPTION:
				Evaluating regression function at given single sample
			INPUTS:
				x - input sample [nDims]
			OUTPUT:
				evaluated value
		*)
		PROCEDURE EvaluateScalar*(CONST x: Vector): Scalar;
		VAR
			X1: Matrix;
			y: Vector;
		BEGIN
			(* FIXME: make it more efficient! *)
			NEW(X1,1,LEN(x,0)); X1[0] := x;
			y := EvaluateScalarN(X1);
			RETURN y[0];
		END EvaluateScalar;

		(*
			DESCRIPTION:
				Evaluating regression function at given samples
			INPUTS:
				X - set of input samples [nSamples x nDims]
			OUTPUT:
				evaluated values [nSamples]
		*)
		PROCEDURE EvaluateScalarN*(CONST X: Matrix): Vector;
		VAR
			y: Vector;
			K: Matrix;
		BEGIN
			IF isTrained THEN
				K := MLKernels.KernelMtx(SELF.X,X,kernType,kernParams);
				y := K`*alphas;
			ELSE
				Error('EvaluateScalarN','regressor is not trained!');
			END;

			RETURN y;
		END EvaluateScalarN;

		(*
			DESCRIPTION:
				local error handler
		*)
		PROCEDURE Error(CONST errLocation, errText: ARRAY OF CHAR);
		VAR
			location: ErrorBase.ERRSTR;
		BEGIN
			location := 'MLRidgeRegression.Regressor.';
			Strings.Concat(location,errLocation,location);
			ErrorBase.Error(location,errText);
		END Error;

	END Regressor;

END MLRidgeRegression.
