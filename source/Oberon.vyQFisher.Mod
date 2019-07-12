MODULE vyQFisher IN Oberon;
(* Copyright notice:

This file is part of Voyager
Copyright (C) 1993-2002 Project Voyager, StatLab Heidelberg ; (C) 1993-2002 G. Sawitzki et al.

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

Copy of the GNU Lesser General Public License can be found in the file COPYING.TXT
Report any problems as soon as possible to voyager@statlab.uni-heidelberg.de
*)


(* gs 25.2.94 *)
IMPORT MathL IN A2, Texts, In, vyBase, vyHostTexts;
TYPE
	Stattyp* = RECORD
		Count*: INTEGER;
		Mean*: LONGREAL;
		Ssq*: LONGREAL
	END;

	VAR w: vyBase.TextsWriter;


	(******************  Comment  ****************************
	Version1.1
	Statistical Papers (1986),Vol27,No1

	QFISHER computes the percentage point of the
	F-dist.function.

	Formal Parameters:
	Input:N,M degrees of freedom:N,M>0;
	Percentage,given percentagevalue:0<=Percentage<=1;
	Output: QFISHER,if an error is detecded then QFISHER:=NaN(BADPROB).


	**********************************************************)

	PROCEDURE Qfisher* (N, M: INTEGER;
Percentage: LONGREAL; VAR ErrCode: INTEGER): LONGREAL;
CONST
	Accuracy = 1.0E-6;
	K1 = 2.30753;
	K2 = 0.27061;
	K3 = 0.99229;
	K4 = 0.04481;
	cNoErr = 0;
	cBadprob = 1;

VAR
	A, B, C, Psq, V, T: LONGREAL;
	E, Up, Help: LONGREAL;

PROCEDURE Sqr (x: LONGREAL): LONGREAL;
BEGIN
	RETURN x * x
END Sqr;

(**************** Comment *****************************************
Version 1.1

Algorithm 322, Com.of the ACM,(Feb.1968),Vol11,No2

PFFISHER computes the probability integral for
Fisher's F-distribution with integralbound x.

Formal Parameters:
Input:n,m degrees of freedom:n,m>0;
x integralbound:x>0;
Output:PFFISHER,if an error is detecded then PFFISHER=NaN(cBadprob).
Accuracy=1.0E-6.

********************************************************************)

PROCEDURE Pffisher (N, M: INTEGER;
X: LONGREAL; VAR Err: INTEGER): LONGREAL;

VAR
	A, B, I, J: INTEGER;
	W, Y, Z, D, P: LONGREAL;

BEGIN (*PFFISHER*)
	Err := cNoErr;
	(*check valid degrees of freedom*)
	IF ((M <= 0) OR (N <= 0) OR (X < 0.0)) THEN
		Err := cBadprob;  RETURN 0
	ELSE
		(*extreme value*)
		IF (X = 0.0) THEN RETURN 0.0
		ELSIF X >= MAX(REAL) THEN RETURN 1.0
		ELSE
			(*real approximation*)


			IF ODD(N) THEN A := 1 ELSE  A := 2 END;
			IF ODD(M) THEN  B := 1 ELSE  B := 2 END;

			W := X * N / M;
			Z := 1.0 / (1.0 + W);

			IF ODD(N) THEN
				IF ODD(M) THEN
					P := MathL.sqrt(W);   Y := 0.3183098862;
					D := Y * Z / P;  P := 2.0 * Y * MathL.arctan(P)
				ELSE
					P := MathL.sqrt(W * Z); D := 0.5 * P * Z / W
				END (* ODD M *)
			ELSE
				IF ODD(M) THEN
					P := MathL.sqrt(Z);   D := 0.5 * Z * P;   P := 1 - P
				ELSE
					D := Z * Z;  P := W * Z
				END (* ODD M *)
			END; (* ODD N *)
			Y := 2.0 * W / Z;
			J := B + 2;

			IF ODD(N) THEN
				WHILE J <= M DO
					D := (1.0 + A / (J - 2)) * D * Z;   P := P + D * Y / (J - 1);
					INC(J); INC(J)
				END
			ELSE
				WHILE J <= M DO
					D := (1.0 + A / (J - 2)) * D * Z;   P := (P + W) * Z;
					INC(J); INC(J)
				END
			END;
			Y := W * Z;
			Z := 2.0 / Z;
			B := M - 2;
			I := A + 2;
			WHILE I <= N DO
				J := I + B;
				D := Y * D * J / (I - 2);
				P := P - Z * D / J;
				INC(I); INC(I)
			END
		END
	END;
	RETURN P

END  Pffisher;  (*PFFISHER*)

(* $ I --- End of PFFISHER.IPAS --- *)

BEGIN (*Function QFISHER*)

	IF ((N <= 0) OR (M <= 0)) THEN
		ErrCode := cBadprob;  RETURN 0
	ELSIF ((Percentage < 0) OR (Percentage > 1)) THEN
		ErrCode := cBadprob;  RETURN 0

	ELSIF (*extreme values*)
		Percentage = 0 THEN
		RETURN 0
	ELSIF Percentage = 1 THEN
		RETURN MAX(LONGREAL)

	ELSE
		(*real approximation*)
		B := 0;
		IF (M > 4) THEN

			(*(m>4)*)
			(* approximation of startvalue*)

			Psq := Percentage * Percentage;
			IF (Percentage > 0.5) THEN Psq := (1 - Percentage) * (1 - Percentage) END;
			T := MathL.sqrt(MathL.ln(1 / Psq));
			Up := T - (K1 + K2 * T) / (1.0 + K3 * T + K4 * Sqr(T));
			IF (Percentage < 0.5) THEN Up := - Up END;
			E := M / (M - 2);
			V := Sqr(M);
			V := V * (N + M - 2) / (Sqr(M - 2) * N * (M - 4));
			B := E + Up * MathL.sqrt(2 * V);
			IF B < 0 THEN B := 0 END;
			(*Writeln('b ', B);*)
		END;  (*(m>4)*)

		(* search for startvalues*)
		A := B;
		Help := Pffisher(N, M, B, ErrCode);
		IF (Help < Percentage) THEN

			IF B = 0 THEN B := 0.5 END;
			REPEAT
				B := 2.0 * B;
				Help := Pffisher(N, M, B, ErrCode)

			UNTIL (Help >= Percentage)

		ELSE

			REPEAT
				A := A * 0.5;
				Help := Pffisher(N, M, A, ErrCode)
				(*      Writeln('a ', A, ' help ', Help);*)
			UNTIL (Help < Percentage)
		END;
		(* Newton method*)
		REPEAT
			C := 0.5 * (A + B);
			Help := Pffisher(N, M, C, ErrCode);
			(*  Writeln('c ', C, ' help ', Help);*)
			IF (Help < Percentage) THEN
				A := C
			ELSE
			B := C END;
			Help := ABS(A - B)
		UNTIL (Help < Accuracy);

		RETURN C

	END;  (*real approximation*)

END Qfisher;  (*Function Qfisher*)

PROCEDURE QF*;  VAR N, M: INTEGER; RP: REAL; X, P: LONGREAL; Err: INTEGER;
BEGIN
	In.Open; In.Int(N); In.Int(M); In.Real(RP); P := RP;
	X := Qfisher(N, M, P, Err);
	RP := SHORT(X);
	vyHostTexts.WriteRealFix(w, RP, 8, 4, 4);
	Texts.WriteInt(w, Err, 4);

	Texts.WriteLn(w);
	vyHostTexts.AppendToLog(w)

END QF;

PROCEDURE initstat* (VAR s: Stattyp);
BEGIN
	s.Count := 0; s.Mean := 0; s.Ssq := 0
END initstat;

PROCEDURE Addbistat* (X, Y: LONGREAL;
VAR Xstat, Ystat: Stattyp;
VAR Xyssq: LONGREAL);
	(*Fuction: accumulate (x,y) into the statistics*)
	(*Input: (x,y): new data*)
	(*          xstat,ystat,xyssq: current statistics*)
	(*Output:  xstat,ystat,xyssq: updated statistics*)

	(*Updating by method of provisional means*)
	(*BMDP Statistical Software, Appendix A.2*)
	(*xyssq: sum of (x-xmean)(y-ymean)*)
	(*no checks preformed, count overflow will not be detected*)
	(*you can save updating one 'count' if you want to*)

VAR
	Xdiff, Ydiff: LONGREAL;

BEGIN
	(*update statistics for x*)
	WITH Xstat: Stattyp DO
		INC(Xstat.Count);
		Xdiff := X - Xstat.Mean;
		Xstat.Mean := Xstat.Mean + Xdiff / Xstat.Count;
		Xstat.Ssq := Xstat.Ssq + Xdiff * (X - Xstat.Mean)
	END;
	(*update statistics for y and cross-products*)
	WITH Ystat: Stattyp DO
		INC(Ystat.Count );
		Ydiff := Y - Ystat.Mean;
		Ystat.Mean := Ystat.Mean + Ydiff / Ystat.Count;
		Ystat.Ssq := Ystat.Ssq + Ydiff * (Y - Ystat.Mean);
		Xyssq := Xyssq + Xdiff * (Y - Ystat.Mean)
	END
END Addbistat;

BEGIN
	Texts.OpenWriter(w);
END vyQFisher.
