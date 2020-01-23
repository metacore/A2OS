MODULE MLTest;
(**
	DESCRIPTION:
		Testing module for "Machine Learning" library

	AUTHOR:
		Alexey Morozov
**)

IMPORT
	MLBase, MLKernels, MLKernelMeans, MLRidgeRegression, TensorIO, Out:=KernelLog, Streams, ExtraTime, ExtraRandom;

TYPE
	INT = SIGNED32;
	Scalar = MLBase.Scalar;
	Vector = MLBase.Vector;
	Matrix = MLBase.Matrix;

VAR
	w: Streams.Writer;

	PROCEDURE ClassificationError(CONST est, ref: Vector): Scalar;
	VAR
		i: INT;
		error: Scalar;
	BEGIN
		error := 0;
		FOR i := 0 TO LEN(est)-1 DO
			IF est[i] # ref[i] THEN error := error + 1; END;
		END;
		RETURN error/LEN(est);
	END ClassificationError;


	(*
		Test kernel means implementation
	*)
	PROCEDURE TestKernelMeans*;
	VAR
		i: INT;
		X: Matrix;
		XL, XT: Matrix;
		class: MLKernelMeans.Classifier;
		y, yl, yt: Vector;
		t: ExtraTime.Timer;
		trainErr, testErr: Scalar;
	BEGIN

		NEW(t);

		Out.String('******* Classification of breast cancer data *******'); Out.Ln; Out.Ln;

		X := TensorIO.FLoadLR('breast-cancer.dat',[683, 11]);

		y := X[*,0];
		FOR i := 0 TO LEN(y,0)-1 DO
			IF y[i] < 0 THEN y[i] := 0; ELSE y[i] := 1; END;
		END;
		XL := X[0..299,1..MAX]; yl := y[0..299];
		XT := X[300..MAX,1..MAX]; yt := y[300..MAX];

		NEW(class);

		Out.String('linear kernel:'); Out.Ln;

		t.tic;
		class.Learn(XL,yl);
		t.disptoc('Learning time: ');

		t.tic;
		trainErr := ClassificationError(class.ClassifyMultiple(XL),yl);
		t.disptoc('train evaluation time: ');

		t.tic;
		testErr := ClassificationError(class.ClassifyMultiple(XT),yt);
		t.disptoc('test evaluation time: ');

		w.String('empirical risk: '); w.FloatFix(trainErr,0,6,0); w.Ln; w.Update;
		w.String('true risk approximation: '); w.FloatFix(testErr,0,6,0); w.Ln; w.Update;
		Out.Ln; Out.Ln;

		(*--- polynomial ---*)

		Out.String('polynomial kernel:'); Out.Ln;
		class.SetKernel(MLKernels.Poly,[1, 2]);

		t.tic;
		class.Learn(XL,yl);
		t.disptoc('Learning time: ');

		t.tic;
		trainErr := ClassificationError(class.ClassifyMultiple(XL),yl);
		t.disptoc('train evaluation time: ');

		t.tic;
		testErr := ClassificationError(class.ClassifyMultiple(XT),yt);
		t.disptoc('test evaluation time: ');

		w.String('empirical risk: '); w.FloatFix(trainErr,0,6,0); w.Ln; w.Update;
		w.String('true risk approximation: '); w.FloatFix(testErr,0,6,0); w.Ln; w.Update;
		Out.Ln; Out.Ln;

		(*--- Gaussian kernel ---*)

		Out.String('Gaussian kernel:'); Out.Ln;
		class.SetKernel(MLKernels.Gauss,[3]);

		t.tic;
		class.Learn(XL,yl);
		t.disptoc('Learning time: ');

		t.tic;
		trainErr := ClassificationError(class.ClassifyMultiple(XL),yl);
		t.disptoc('train evaluation time: ');

		t.tic;
		testErr := ClassificationError(class.ClassifyMultiple(XT),yt);
		t.disptoc('test evaluation time: ');

		w.String('empirical risk: '); w.FloatFix(trainErr,0,6,0); w.Ln; w.Update;
		w.String('true risk approximation: '); w.FloatFix(testErr,0,6,0); w.Ln; w.Update;
		Out.Ln; Out.Ln;

		Out.Ln;
		Out.String('******* Classification of USPS handwritten digits (0 and 1) *******'); Out.Ln; Out.Ln;

		X := TensorIO.FLoadLR('USPS01.dat',[2128, 785]);

		y := X[*,0];

		FOR i := 0 TO LEN(y)-1 DO
			IF y[i] < 0 THEN y[i] := 0; ELSE y[i] := 1; END;
		END;
		XL := X[0..299,1..MAX]; yl := y[0..299];
		XT := X[300..MAX,1..MAX]; yt := y[300..MAX];

		Out.String('linear kernel:'); Out.Ln;

		class.SetKernel(MLKernels.Linear,[0]);

		t.tic;
		class.Learn(XL,yl);
		t.disptoc('Learning time: ');

		t.tic;
		trainErr := ClassificationError(class.ClassifyMultiple(XL),yl);
		t.disptoc('train evaluation time: ');

		t.tic;
		testErr := ClassificationError(class.ClassifyMultiple(XT),yt);
		t.disptoc('test evaluation time: ');

		w.String('empirical risk: '); w.FloatFix(trainErr,0,6,0); w.Ln; w.Update;
		w.String('true risk approximation: '); w.FloatFix(testErr,0,6,0); w.Ln; w.Update;
		Out.Ln; Out.Ln;

		(*--- polynomial kernel ---*)

		Out.String('polynomial kernel:'); Out.Ln;
		class.SetKernel(MLKernels.Poly,[1, 2]);

		t.tic;
		class.Learn(XL,yl);
		t.disptoc('Learning time: ');

		t.tic;
		trainErr := ClassificationError(class.ClassifyMultiple(XL),yl);
		t.disptoc('train evaluation time: ');

		t.tic;
		testErr := ClassificationError(class.ClassifyMultiple(XT),yt);
		t.disptoc('test evaluation time: ');

		w.String('empirical risk: '); w.FloatFix(trainErr,0,6,0); w.Ln; w.Update;
		w.String('true risk approximation: '); w.FloatFix(testErr,0,6,0); w.Ln; w.Update;
		Out.Ln; Out.Ln;

		(*--- Gaussian kernel ---*)

		Out.String('Gaussian kernel:'); Out.Ln;
		class.SetKernel(MLKernels.Gauss,[3]);

		t.tic;
		class.Learn(XL,yl);
		t.disptoc('Learning time: ');

		t.tic;
		trainErr := ClassificationError(class.ClassifyMultiple(XL),yl);
		t.disptoc('train evaluation time: ');

		t.tic;
		testErr := ClassificationError(class.ClassifyMultiple(XT),yt);
		t.disptoc('test evaluation time: ');

		w.String('empirical risk: '); w.FloatFix(trainErr,0,6,0); w.Ln; w.Update;
		w.String('true risk approximation: '); w.FloatFix(testErr,0,6,0); w.Ln; w.Update;
		Out.Ln; Out.Ln;

		Out.String('Done!'); Out.Ln;

	END TestKernelMeans;

	(*
		Test ridge regression implementation
	*)
	PROCEDURE TestRidgeRegression*;
	VAR
		i, N: INT;
		dx: Scalar;
		XL, XT: Matrix;
		x0, y0, yl, y1, y2: Vector;
		ind, sz: ARRAY [*] OF INT;
		regressor: MLRidgeRegression.Regressor;
		t: ExtraTime.Timer;
	BEGIN
		N := 2000; (* number of points for test evaluation *)

		NEW(t);

		Out.String('******* 1D regression *******'); Out.Ln; Out.Ln;
		NEW(x0,N); NEW(y0,N);

		(* generate x0 := -10:0.01:10; y0 := a3*x0^3 + a2*x0^2 + a1*x0 + a0 *)
		x0[0] := -10; dx := 20.0/N;
		FOR i := 1 TO LEN(x0)-1 DO
			x0[i] := x0[i-1] + dx;
			y0[i] := 0.1*x0[i]*x0[i]*x0[i] + 0.2*x0[i]*x0[i] - 0.3*x0[i] + 1;
		END;

		(* add noise to the data *)
		NEW(sz,1); sz[0] := LEN(y0);
		y0 := y0 + ExtraRandom.UniformLR(0.0,1.0,sz);
		x0 := x0/10;


		(* take some random points from (x0,y0) *)
		sz[0] := 100;
		ind := ENTIER(ExtraRandom.UniformLR(0,N,sz)); (* [100] gives a TRAP during compilation!!! *)

		(* data for learning *)
		NEW(XL,N DIV 10,1); NEW(yl, N DIV 10);
		FOR i := 0 TO LEN(ind)-1 DO
			XL[i,0] := x0[ind[i]];
			yl[i] := y0[ind[i]];
		END;

		NEW(XT,N,1); XT[*,0] := x0;

		NEW(regressor);
		regressor.SetRegularization(0.01);

		Out.String('linear kernel:'); Out.Ln;

		t.tic;
		regressor.Learn(XL,yl);
		t.disptoc('Learning time: ');

		t.tic;
		y1 := regressor.EvaluateScalarN(XL);
		t.disptoc('train evaluation time: ');

		t.tic;
		y2 := regressor.EvaluateScalarN(XT);
		t.disptoc('test evaluation time: ');
		Out.Ln;

		Out.String('polynomial kernel:'); Out.Ln;

		regressor.SetKernel(MLKernels.Poly,[1, 3]);

		t.tic;
		regressor.Learn(XL,yl);
		t.disptoc('Learning time: ');

		t.tic;
		y1 := regressor.EvaluateScalarN(XL);
		t.disptoc('train evaluation time: ');

		t.tic;
		y2 := regressor.EvaluateScalarN(XT);
		t.disptoc('test evaluation time: ');
		Out.Ln;


		Out.String('Gaussian kernel:'); Out.Ln;

		regressor.SetKernel(MLKernels.Gauss,[0.3]);

		t.tic;
		regressor.Learn(XL,yl);
		t.disptoc('Learning time: ');

		t.tic;
		y1 := regressor.EvaluateScalarN(XL);
		t.disptoc('train evaluation time: ');

		t.tic;
		y2 := regressor.EvaluateScalarN(XT);
		t.disptoc('test evaluation time: ');

		Out.String('Done!'); Out.Ln;
	END TestRidgeRegression;


BEGIN
	Streams.OpenWriter(w,Out.Send);
END MLTest.

MLTest.TestKernelMeans ~

MLTest.TestRidgeRegression ~