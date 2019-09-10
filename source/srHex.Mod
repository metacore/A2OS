MODULE srHex;
IMPORT srBase;

TYPE SREAL=srBase.SREAL;

CONST
	Z = 0.866;
	W = 1/2;
	S = 2*Z;
	TY = 2*Z;
	TX = 3;
	E = 0.1;

PROCEDURE hexize*(x,y: SREAL):BOOLEAN;
BEGIN
	x := ABS(x); y := ABS(y);
	IF x >=TX THEN RETURN(FALSE) END;
	 (*REPEAT
		x := x-TX;
	UNTIL x < TX END; *)
	IF y > TY THEN RETURN(TRUE) END; (*REPEAT
		y := y-TY;
	UNTIL y < TY END; *)
	IF x < W THEN
		IF ABS(y - Z) < E THEN
			RETURN(TRUE)
		END;
		RETURN(FALSE);
	ELSIF x < 2*W THEN
			IF y < Z THEN
				IF ABS(y - (2*Z -S*x)) < E THEN RETURN(TRUE) END; RETURN(FALSE);
			ELSE
				IF ABS(y - S*x) < E THEN RETURN(TRUE) END; RETURN(FALSE);
			END
	ELSIF x < 4*W THEN
		IF (y < E) OR ((TY-y) < E) THEN RETURN(TRUE) END; RETURN(FALSE);
	ELSIF x < 5*W THEN
		IF y < Z THEN
			IF ABS(y - (S*x - 4*Z)) < E THEN RETURN(TRUE) END; RETURN(FALSE);
		ELSE
			IF ABS(y -( 6*Z - S*x)) < E THEN RETURN(TRUE) END; RETURN(FALSE);
		END
	ELSE (* x > 5*w *)
		IF ABS(y - Z) < E THEN RETURN(TRUE) END; RETURN(FALSE);
	END;
	RETURN(FALSE);
END hexize;

PROCEDURE hexize2*(x,y: SREAL):SREAL;
VAR
	ix,jy: SIGNED32;
BEGIN
	x := ABS(x); y := ABS(y);
	ix := ENTIER(x); jy := ENTIER(y);
	IF x > TX THEN x:= x-ix END;
	IF y > TY THEN y := y-jy END;
	IF x < W THEN
		RETURN(ABS(y - Z))
	ELSIF x < 2*W THEN
			IF y < Z THEN
				RETURN(ABS(y - (2*Z -S*x)))
			ELSE
				RETURN(ABS(y - S*x))
			END
	ELSIF x < 4*W THEN
		IF y < Z THEN
				RETURN(ABS(y))
			ELSE
				RETURN(ABS(TY-y))
			END
	ELSIF x < 5*W THEN
		IF y < Z THEN
			RETURN( ABS(y - (S*x - 4*Z)) )
		ELSE
		RETURN(ABS(y -( 6*Z - S*x)))
			END
	ELSE (* x > 5*w *)
		RETURN(ABS(y - Z) )
	END;
END hexize2;


END srHex.

RETURN(   )