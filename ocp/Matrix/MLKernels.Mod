MODULE MLKernels;
(**
	DESCRIPTION:
		Kernels used for machine learning applications
	AUTHOR:
		Alexey Morozov
**)

IMPORT
	ErrorBase, MatrixBase, Math := MathL, Strings;

CONST
	(* kernel types *)
	Linear* = 0; (* linear kernel, equivalent to inner product *)
	Poly* = 1; (* polynomial kernel - (p + <X1,X2>)^q *)
	Gauss* = 2; (* Gaussian radial basis function - exp[-0.5/(sigma^2)*<X1-X2,X1-X2>] *)
	ThinPlate* = 3; (* thin plate spline *)

TYPE
	Scalar = MatrixBase.Datatype;
	Vector = MatrixBase.Vector;
	Matrix = MatrixBase.Matrix;

	(*
		DESCRIPTION:
			Construction of a kernel matrix
		INPUTS:
			X1, X2 - input data of size nSamples1 x nDims,  nSamples2 x nDims
			kernType - type of the kernel
			kernParams - array of kernel parameters
		OUTPUT:
			Kernel matrix of size nSamples1 x nSamples2
	*)
	PROCEDURE KernelMtx*(CONST X1, X2: Matrix; kernType: INTEGER; CONST kernParams: Vector): Matrix;
	VAR
		i, j: SIZE;
		f: Scalar;

		p, q, sigma, splineOrder: Scalar;

		strErr: Strings.String;

		PROCEDURE CheckArguments(): BOOLEAN;
		BEGIN
			IF LEN(X1,1) = LEN(X2,1) THEN

				CASE kernType OF

					Linear: RETURN TRUE;

					|Poly:
						IF LEN(kernParams) > 1 THEN
							p := kernParams[0];
							q := kernParams[1];

							RETURN TRUE;
						ELSE
							strErr := Strings.NewString('polynomial kernel requires 2 parameters!');
						END;

					|Gauss:
						IF LEN(kernParams) > 0 THEN
							sigma := kernParams[0];
							RETURN TRUE;
						ELSE
							strErr := Strings.NewString('Gaussian kernel requires 1 parameter!');
						END;

					|ThinPlate:
						IF LEN(kernParams) > 0 THEN
							IF (kernParams[0] >= 0) & (kernParams[0] = ENTIER(kernParams[0])) THEN
								splineOrder := kernParams[0];
								RETURN TRUE;
							ELSE
								strErr := Strings.NewString('thin plate spline kernel parameter must be positive integer!');
							END;
						ELSE
							strErr := Strings.NewString('thin plate spline kernel requires 1 parameter!');
						END;
				ELSE
					strErr := Strings.NewString('invalid kernel type code!');
				END;
			ELSE
				strErr := Strings.NewString('input data have incompatible dimensions!');
			END;

			RETURN FALSE;
		END CheckArguments;

	BEGIN

		IF CheckArguments() THEN

			IF (LEN(RESULT,0) # LEN(X1,0)) OR (LEN(RESULT,1) # LEN(X2,0)) THEN
				NEW(RESULT,LEN(X1,0),LEN(X2,0));
			END;

			CASE kernType OF
				Linear:

					RESULT := X1*X2`;

				|Poly:

					RESULT := X1*X2` + p;

					IF (p >= 0) OR ( (q > 0) & (q = ENTIER(q) ) & ~ODD(ENTIER(q)) ) OR (RESULT >= 0) THEN

						FOR i := 0 TO LEN(RESULT,0)-1 DO
							FOR j := 0 TO LEN(RESULT,1)-1 DO
								IF RESULT[i,j] # 0 THEN
									RESULT[i,j] := Math.exp(q*Math.ln(ABS(RESULT[i,j])));
								END;
							END;
						END;
					ELSE
						Error('KernelMtx','fractional power can be computed with only positive values!');
					END;

				|Gauss:
					ComputeNormMatrix(X1,X2,RESULT);

					f := -0.5D0/(sigma*sigma);
					FOR i := 0 TO LEN(RESULT,0)-1 DO
						FOR j := 0 TO LEN(RESULT,1)-1 DO
							RESULT[i,j] := Math.exp(f*RESULT[i,j]);
						END;
					END;

				|ThinPlate:
					ComputeNormMatrix(X1,X2,RESULT);

					IF ODD(ENTIER(splineOrder)) THEN

						FOR i := 0 TO LEN(RESULT,0)-1 DO
							FOR j := 0 TO LEN(RESULT,1)-1 DO
								IF RESULT[i,j] # 0 THEN
									RESULT[i,j] := Math.exp(splineOrder*Math.ln(RESULT[i,j]));
								END;
							END;
						END;
					ELSE

						FOR i := 0 TO LEN(RESULT,0)-1 DO
							FOR j := 0 TO LEN(RESULT,1)-1 DO
								IF RESULT[i,j] # 0 THEN
									f := Math.ln(RESULT[i,j]);
									RESULT[i,j] := Math.exp(splineOrder*f)*f;
								END;
							END;
						END;
					END;
			END;
		ELSE
			Error('KernelMtx',strErr^);
		END;

		RETURN RESULT;
	END KernelMtx;

	(*
		DESCRIPTION:
			Computes a matrix each element of which is Euclidean norm of (X1[i,*] - X2[j,*])
	*)
	PROCEDURE ComputeNormMatrix(CONST X1, X2: ARRAY [*,*] OF Scalar; VAR R: ARRAY [*,*] OF Scalar);
	VAR
		i, j: SIZE;
		tmp: Matrix;
		ones1, ones2: Vector;
	BEGIN
		NEW(ones1,LEN(X1,0)); NEW(ones2,LEN(X1,1));
		ones1 := 1; ones2 := 1;

		FOR i := 0 TO LEN(X2,0)-1 DO
			tmp := X1 ;
			tmp := tmp - ones1 ** X2[i];
			tmp := tmp.*tmp;
			R[*,i] := tmp*ones2;
		END;
	END ComputeNormMatrix;

	(*
		DESCRIPTION:
			local error handler
	*)
	PROCEDURE Error(CONST errLocation, errText: ARRAY OF CHAR);
	VAR
		location: ErrorBase.ERRSTR;
	BEGIN
		location := 'MLKernels.';
		Strings.Concat(location,errLocation,location);
		ErrorBase.Error(location,errText);
	END Error;

END MLKernels.
