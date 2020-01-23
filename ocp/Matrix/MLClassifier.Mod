MODULE MLClassifier;   (**  AUTHOR "Patrick Hunziker"; PURPOSE "Machine Learning Base";  **)

IMPORT MatrixBase;

TYPE
	Datatype* = FLOAT64;
	Vector* = MatrixBase.Vector;
	Matrix* = MatrixBase.Matrix;

TYPE
	Classifier* = OBJECT

		(** classify one instance *)
		PROCEDURE Classify*( CONST Features: Vector ): Vector;
		END Classify;

	END Classifier;

TYPE
	LearningMachine* = OBJECT (Classifier)

		PROCEDURE Learn*( CONST Samples, Targets: Matrix );   (* sample matrix m*n: [m=samples,n=features]; target matrix m*p [m= samples, p=classes]*)
		END Learn;

	END LearningMachine;

END MLClassifier.


fofPC.Compile *
OFormatter.Format *