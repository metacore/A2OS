MODULE MLBase;
(**
	DESCRIPTION:
		Base types for "Machine Learning" library
	AUTHORS:
		Patrick Hunziker and Alexey Morozov
	VERSION:
		5.4.2008
**)

IMPORT MatrixBase;

TYPE
	Scalar* = MatrixBase.Datatype;
	Vector* = MatrixBase.Vector;
	Matrix* = MatrixBase.Matrix;

	(**		Simple machine accepting input data and giving some output - is base type for all machine learning objects like classifiers, regression, neural networks, SVM's etc *)
	SimpleMachine* = OBJECT

		(** Mapping from vector valued input to scalar output*)
		PROCEDURE EvaluateScalar*(CONST input: Vector): Scalar;
		END EvaluateScalar;

		(**Mapping from vector valued input to a vector valued output*)
		PROCEDURE EvaluateVector*(CONST input: Vector): Vector;
		END EvaluateVector;

		(** Mapping from a multiple set of vector valued inputs to a set of scalar valued outputs		*)
		PROCEDURE EvaluateScalarN*(CONST input: Matrix): Vector;
		END EvaluateScalarN;

		(** Mapping from a multiple set of vector valued inputs to a set of vector valued outputs		*)
		PROCEDURE EvaluateVectorN*(CONST input: Matrix): Matrix;
		END EvaluateVectorN;

	END SimpleMachine;

	(** Machine with learning capability	*)
	LearningMachine* = OBJECT(SimpleMachine)
	VAR
		isTrained*: BOOLEAN; (** TRUE when machine is trained *)

		(** learn mapping from vector valued input to scalar output		*)
		PROCEDURE LearnScalar*(CONST input: Vector; target: Scalar);
		END LearnScalar;

		(** Learn mapping from vector valued input to vector valued output		*)
		PROCEDURE LearnVector*(CONST input: Vector; CONST target: Vector);
		END LearnVector;

		(** 	Learn mapping from a multiple set of vector valued inputs to a set of scalar valued outputs		*)
		PROCEDURE LearnScalarN*(CONST input: Matrix; CONST target: Vector);
		END LearnScalarN;

		(** Mapping from a multiple set of vector valued inputs to a set of vector valued outputs		*)
		PROCEDURE LearnVectorN*(CONST input: Matrix; CONST target: Matrix);
		END LearnVectorN;

	END LearningMachine;


END MLBase.