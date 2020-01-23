MODULE StatisticsRandom; (** AUTHOR "Patrick Hunziker"; PURPOSE ""; *)

IMPORT StatisticsBase, Random, Mathe:=MathL, Reals;

TYPE Datatype=StatisticsBase.Datatype;

(* random number with gaussian distribution with mean=zero, variance*)
PROCEDURE Gaussian*(variance:Datatype):Datatype;
VAR res:Datatype;
BEGIN
	res:=Mathe.sqrt(-2*variance * Mathe.ln(1-rand.Uniform()));
	IF ~Reals.IsNaNL(res) THEN RETURN res
	ELSE RETURN 0
	END;
END Gaussian;

VAR
	rand:Random.Generator;
BEGIN
	NEW(rand);
END StatisticsRandom.

