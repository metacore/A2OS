MODULE MLRidgeRegression;
(**
	DESCRIPTION:
		Data approximation using ridge regression model with kernels

	AUTHOR:
		Alexey Morozov
*)

IMPORT
	MLBase;

TYPE

	Vector = MLBase.Vector;
	Matrix = MLBase.Matrix;

	Regressor* = OBJECT(MLBase.LearningMachine)
	VAR

	END Regressor;

END MLRidgeRegression.
