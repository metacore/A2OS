MODULE MLKernelMeans;
(**
	DESCRIPTION:
		Simple classifier based on kernelized clusterization.
		For linear kernel it is equivalent to classification using distances to the means of 2 clusters.
	AUTHOR:
		Alexey Morozov
*)

IMPORT
	ErrorBase, MLBase, MLKernels, ExtraSort, Strings;

TYPE
	Scalar = MLBase.Scalar;
	Vector = MLBase.Vector;
	Matrix = MLBase.Matrix;

	(*
		Kernel means classifier
	*)
	Classifier* = OBJECT(MLBase.LearningMachine)
	VAR
		kernType-: INTEGER;
		kernParams-: Vector;
		C: Scalar;
		X1, X2: Matrix;

		PROCEDURE &Init;
		BEGIN
			(* by default use linear kernel *)
			kernType := MLKernels.Linear;
		END Init;

		(*
			DESCRIPTION:
				Classification of a single input vector [nDims]
			INPUTS:
				input - vector to classify
			OUTPUT:
				class label (0 or 1)
		*)
		PROCEDURE Classify*(CONST input: Vector): Scalar;
		BEGIN
			RETURN EvaluateScalar(input);
		END Classify;

		(*
			DESCRIPTION:
				Classification of a set of input vectors [nSamples x nDims]
			INPUTS:
				input - vectors to classify
			OUTPUT:
				class labels for each vector from the input set (0 or 1) [nSamples]
		*)
		PROCEDURE ClassifyMultiple*(CONST input: Matrix): Vector;
		BEGIN
			RETURN EvaluateScalarN(input);
		END ClassifyMultiple;


		(*
			DESCRIPTION:
				Classification of a set of input vectors [nSamples x nDims]
			INPUTS:
				input - vectors to classify
			OUTPUT:
				class labels for each vector from the input set (0 or 1) [nSamples]
		*)
		PROCEDURE EvaluateScalarN(CONST input: Matrix): Vector;
		VAR
			i: SIZE;
			K: Matrix;
			labels: Vector;
		BEGIN
			IF isTrained THEN
				K := MLKernels.KernelMtx(X2,input,kernType,kernParams);
				labels := ColSum(K)/LEN(X2,0);
				K := MLKernels.KernelMtx(X1,input,kernType,kernParams);
				labels := labels - ColSum(K)/LEN(X1,0);
				labels := labels + C;

				FOR i := 0 TO LEN(labels,0)-1 DO
					IF labels[i] < 0 THEN labels[i] := 0; ELSE labels[i] := 1; END;
				END;
			ELSE
				Error('EvaluateScalarN','classifier is not learned!');
			END;

			RETURN labels;
		END EvaluateScalarN;

		(*
			DESCRIPTION:
				Set kernel used for classification
			INPUTS:
				kernType - kernel type code
				kernParams - array of kernel parameters
			REMARKS:
				after you set a new type of kernel you must redo learning of the classifier!
		*)
		PROCEDURE SetKernel*(kernType: INTEGER; CONST kernParams: Vector);
		BEGIN
			isTrained := FALSE; (* reset classifier *)

			SELF.kernType := kernType;
			SELF.kernParams := kernParams;
		END SetKernel;


		(*
			DESCRIPTION:
				Learning the classifier
			INPUTS:
				X - set of feature vectors [ nSamples x nDims ]
				labels for each feature vector [ nSamples ]
			OUTPUT:
				Classification label (-1, 1)
		*)
		PROCEDURE Learn*(CONST input: Matrix; CONST labels: Vector);
		BEGIN
			LearnScalarN(input,labels);
		END Learn;

		(*
			DESCRIPTION:
				Learning the classifier
			INPUTS:
				X - set of feature vectors [ nSamples x nDims ]
				labels - label for each feature vector [ nSamples ]
		*)
		PROCEDURE LearnScalarN(CONST input: Matrix; CONST labels: Vector);
		VAR
			i, n1, n2: SIZE;
			ind: ARRAY [*] OF SIZE;
			y: Vector;
			K: Matrix;
			C1, C2: Scalar;
		BEGIN
			IF LEN(input,0) = LEN(labels) THEN

				IF (labels >= 0) & (labels <= 1) THEN

					(* sort labels and after the data *)
					y := labels;
					ExtraSort.QuickSortExLR(y,ind);

					(* find first element >= 1 *)
					i := 0;
					WHILE (i < LEN(y)) & (y[i] < 1) DO INC(i); END;

					(* number of samples for each class *)
					n1 := i; n2 := LEN(y,0)-i;

					IF (n1 > 2) & (n2 > 2) & ((n1 - n2) < MAX(n1,n2) DIV 2) THEN (* check data sizes for sufficiency *)

						NEW(X1,n1,LEN(input,1)); NEW(X2,n2,LEN(input,1));
						FOR i := 0 TO n1-1 DO X1[i] := input[ind[i]]; END;
						FOR i := 0 TO n2-1 DO X2[i] := input[ind[i+n1]]; END;

						K := MLKernels.KernelMtx(X1,X1,kernType,kernParams);

						C1 := SUM(K)/(n1*n1);
						K := MLKernels.KernelMtx(X2,X2,kernType,kernParams);

						C2 := SUM(K)/(n2*n2);

						C := 0.5*(C1 - C2);

						isTrained := TRUE;
					ELSE
						Error('LearnLabels','one of the classes has too few samples!');
					END;
				ELSE
					Error('LearnLabels','invalid class labels! (must be zeros or ones)');
				END;
			ELSE
				Error('LearnLabels','inputs have incompatible sizes!');
			END;
		END LearnScalarN;

		(*
			DESCRIPTION:
				local error handler
		*)
		PROCEDURE Error(CONST errLocation, errText: ARRAY OF CHAR);
		VAR
			location: ErrorBase.ERRSTR;
		BEGIN
			location := 'MLKernelMeans.Classifier.';
			Strings.Concat(location,errLocation,location);
			ErrorBase.Error(location,errText);
		END Error;

	END Classifier;

VAR

	(*
		sum over columns
	*)
	PROCEDURE ColSum(CONST X: Matrix): Vector;
	VAR
		i: SIZE;
		x: Vector;
	BEGIN
		x := X[0];
		FOR i := 1 TO LEN(X,0)-1 DO
			x := x + X[i];
		END;

		RETURN x;
	END ColSum;

END MLKernelMeans.
