MODULE antsHierarchicPotts2d IN Oberon;                                  	(** kjw  **)
(* Copyright notice:

This file is part of AntsInFields
Copyright (C) 1997-2002, Felix Friedrich

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
Report any problems as soon as possible to ants@AntsInFields.de
*)



(*
(c) Katrin Wicker, 2002
(c) Felix Friedrich, 2002
*)

(*
antsArrayObjects.LoadDialoged pgmarray >show ~ (* loads and shows image *)
antsSecurity.Call antsHierarchicPotts2d.ApplyInteractively gamma = 0.2  minwidth = 0  maxwidth = 10 ~ (* Applies hierarchical Potts model to full array *)
antsSecurity.Call antsHierarchicPotts2d.ApplyInteractively gamma = 0.2  minwidth = 0  maxwidth = 10 >region ~ (* Applies hierarchical Potts model to region *)
antsSecurity.Call antsHierarchicPotts2d.OnDirectory inDirectory = "ants/pgmData" outDirectory = "ants/pgmOut" gamma = 0.5 minWidth = 0 maxWidth = 3 ~
(* applies hierarchical Potts model to all PGM files in Directory ants/phmData and stores results in ants/pgmOut *)

(* test: *)
antsSecurity.Call antsHierarchicPotts2d.OnDirectory inDirectory = "katrin/fromPotts" outDirectory = "katrin/toPotts" gamma = 0.5 minWidth = 0 maxWidth = 3 ~
*)

IMPORT antsToolbox, antsArrayObjects, Strings := vyHostStrings, antsCommands, vyBase,vyLongrealVec,
	Input,  Oberon,  vyLongreal, antsRegions,   antsSecurity, antsPortability,
	antsBellman, antsArrays, antsReadWrite,  antsPlots, aM := antsMessages;

VAR
	globalStat: antsBellman.Statistic;
	globalGamma: LONGREAL;
	globaly1, globaly2: LONGINT;
	globalRstern: antsArrays.I1d;      globalBellman: antsArrays.X1d;
	globalMinWeite, globalMaxWeite: LONGINT;
	inDirectory, outDirectory: ARRAY 256 OF CHAR;

	(* Interaktive Routine zum Anwenden des Minimierers auf Array oder Teil davon per Mausklick *)
PROCEDURE ApplyInteractively*;
VAR   		A: antsArrayObjects.tObject;            		r: antsRegions.tRegion;            		gamma: LONGREAL;
	w, h, minweit, maxweit, 			this, last: LONGINT;
	Aorig, Aorigtr, APott1, Apotttr, APott2: antsArrayObjects.tLONGREALArray;
	lengths: BOOLEAN;
BEGIN
	antsCommands.InitScan("gamma=REAL minwidth=INT maxwidth=INT");
	IF  antsCommands.ExpectReal( "gamma", gamma) &
		antsCommands.ExpectNumber( "minwidth",  minweit) &
		antsCommands.ExpectNumber( "maxwidth",  maxweit)

		THEN
	IF antsCommands.Find( "region") THEN NEW(r) ELSE r := NIL END;
		lengths := antsCommands.Find("lengths");
		A := antsRegions.InteractiveGetArray(r);
		IF A # NIL THEN
			WITH A: antsArrayObjects.tINTEGERObject DO
				IF r = NIL THEN
					antsArrayObjects.CopyUnsignedIR(A.A, Aorig, 0, 0, A.w, A.h, 0, 0)
				ELSE
					IF (r.w < 2)OR (r.h < 2) THEN RETURN END;
					antsArrayObjects.CopyUnsignedIR(A.A, Aorig, r.x, r.y, r.w, r.h, 0, 0)
				END;
				w := LEN(Aorig[0]);            		h := LEN(Aorig);

				(* Skalieren gamma mit Median*Median*)
				ScaleMatrix(Aorig^, gamma);
				globalGamma := gamma;

				(* Potts2 auf Matrix Orig mit ssq und median aus Matrix mit kumulativen Summen*)
				(* Originalbild*)
				antsPlots.ShowArray(antsArrayObjects.IntObjR(Aorig, A.depth), "Original Data", FALSE, FALSE);

				antsToolbox.NameOpenedWId("Original Data ", A);

				NEW(Aorigtr, w, h);
				NEW(APott1, h, w);
				NEW(Apotttr, h, w);
				NEW(APott2, w, h);

				last := Oberon.Time();

				MatrixPottsLongreal(Aorig^, APott1^, minweit, maxweit, lengths);
				(* zeigt Potts2 horizontal*)
				antsPlots.ShowArray(antsArrayObjects.IntObjR(APott1, A.depth), "Apott", TRUE, TRUE);

				(*...auf  transponierte Matrix Aorig*)
				Aorigtr := antsArrays.Transpose2dX(Aorig^);
				MatrixPottsLongreal(Aorigtr^, APott2^, minweit, maxweit, lengths);
				Apotttr := antsArrays.Transpose2dX(APott2^);

				this := Oberon.Time();
				aM.vSR("Zeit fuer MatrixPottsLongreal (mit Cum):",(this - last) / Input.TimeUnit);

				(* zeigt Potts2 vertikal*)
				antsPlots.ShowArray(antsArrayObjects.IntObjR(Apotttr, A.depth), "Apott ver", TRUE, TRUE);

				antsToolbox.NameOpenedWId("rows Potts", A);

				(*Summe von Potts2 horizontal und Potts2 vertikal*)
				antsPlots.ShowArray(antsArrayObjects.IntObjR((APott1 + Apotttr) / (2), A.depth), "Apott sum", TRUE, TRUE);
				antsToolbox.NameOpenedWId("Sum of PottsH, PottsV of", A);

				(* ab hier nur für Zeitvergleich *)
				(*
				(* PottstatLongreal, Potts auf Matrix Aorig1 mit statistic (ssq, median)*)
				(*Originalbild*)
				antsPlots.ShowArray(antsArrayObjects.IntObjR(Aorig,A.depth),"Original Data",FALSE,FALSE);
				(*NEW(Aorigtr2, w,h);*)
				NEW(APott3, h, w);
				NEW(Apotttr2, h, w);
				NEW(APott4, w, h);

				last := Oberon.Time();
				PottsStatLongreal(Aorig^, APott3^);
				(*Potts horizontal*)
				antsPlots.ShowArray(antsArrayObjects.IntObjR(APott3,A.depth),"Potts hor",TRUE,TRUE);
				(*fuer transponiert Aorig*)
				PottsStatLongreal(Aorigtr^, APott4^);
				Apotttr2 := katrinMatrix.Transpose(APott4^);

				this := Oberon.Time();
				Out.Ln;    Out.Ln;
				Out.String("Zeit fuer PottsStatLongreal (mit Stat):");
				Out.LongReal((this - last) / Input.TimeUnit, 10);    		Out.Ln;       Out.Ln;

				antsPlots.ShowArray(antsArrayObjects.IntObjR(Apotttr2,A.depth),"APottr2",TRUE,TRUE);
				(*Potts vertikal*)
				antsToolbox.NameOpenedWId("rows Potts2", A);
				antsPlots.ShowArray(antsArrayObjects.IntObjR((APott3 + Apotttr2) / (2),A.depth),"sum",TRUE,TRUE);
				(*Summe von Potts horizontal und Potts vertikal*)
				*)
			END
		END
	END
END ApplyInteractively;

	(* Routine um Minimierer auf ganze Verzeichnisse anzuwenden *)
PROCEDURE PottsFile (in, out: ARRAY OF CHAR;               		minWeite, maxWeite: LONGINT);
VAR A: antsArrayObjects.tLONGREALArray;                o: antsArrayObjects.tINTEGERObject;                AL: antsArrayObjects.tLONGINTArray;                 w, h: LONGINT;
	Aorigtr, APott1, Apotttr, APott2: antsArrayObjects.tLONGREALArray;                       gamma: LONGREAL;
BEGIN
	antsArrayObjects.ReadPGM(o, in);
	IF o = NIL THEN HALT(100) END;
	antsArrayObjects.CopyIR(o.A, A, 0, 0, o.w, o.h, 0, 0);

	(* Potts2 berechnen (wie Testget)... *)
	w := LEN(A[0]);            		h := LEN(A);

	NEW(Aorigtr, w, h);
	NEW(APott1, h, w);
	NEW(Apotttr, h, w);
	NEW(APott2, w, h);

	Aorigtr := antsArrays.Transpose2dX(A^);
	gamma := globalGamma;
	ScaleMatrix(A^, globalGamma);

	MatrixPottsLongreal(A^, APott1^, minWeite, maxWeite, FALSE);
	MatrixPottsLongreal(Aorigtr^, APott2^,  minWeite, maxWeite, FALSE);

	globalGamma := gamma;              (* rücksetzen, da nächstes File denselben Wert benutzt *)

	Apotttr :=  antsArrays.Transpose2dX(APott2^);

	antsArrayObjects.CopyRL((APott1 + Apotttr) / (2), AL, 0, 0, o.w, o.h, 0, 0);
	IF ~antsReadWrite.StorePGM(AL, out, o.depth) THEN END;           (*speichert die Summe von Potts2 horizontal und Potts2 vertikal in out*)
END PottsFile;


PROCEDURE FileEnum (path, name: ARRAY OF CHAR;                time, date, size: LONGINT;                attrs: SET);
VAR outname, outlongname: ARRAY 256 OF CHAR;
BEGIN
	(* zusammensetzen: path/name*)
	COPY(name, outname);
	COPY(path, name);               Strings.Append(name, "/");
	Strings.Append(name, outname);
	outname[Strings.Length(outname) - 4] := 0X;
	(* zusammensetzen: outDirectory/name.Potts.PGM*)
	Strings.Append(outname, ".Potts.PGM");
	COPY(outDirectory, outlongname);
	Strings.Append(outlongname, "/");
	Strings.Append(outlongname, outname);
	aM.SS("Applying algorithm to ",name);
	aM.SS(" => ",outlongname);
	PottsFile(name, outlongname, globalMinWeite, globalMaxWeite);
	aM.S("done.")
END FileEnum;

	(* Kommando um Minimierer auf ganze Verzeichnisse von Bildern des Typs PGM anzuwenden *)
PROCEDURE OnDirectory*;
VAR       done: BOOLEAN;               path: ARRAY 256 OF CHAR;
BEGIN
	antsCommands.InitScan("inDirectory=STR outDirectory=STR gamma=REAL minWidth=INT maxWidth=INT");
	IF antsCommands.ExpectString("inDirectory", inDirectory) &
		antsCommands.ExpectString("outDirectory",  outDirectory) &
		antsCommands.ExpectReal( "gamma", globalGamma) &
		antsCommands.ExpectNumber( "minWidth", globalMinWeite) &
		antsCommands.ExpectNumber("maxWidth",  globalMaxWeite) THEN
		antsPortability.GetWorkingDirectory(path);
		antsPortability.ChangeDirectory(inDirectory, done);
		IF ~done THEN antsSecurity.Halt("in Directory not found")        	 END;
		antsPortability.ChangeDirectory(path, done);
		antsPortability.ChangeDirectory(outDirectory, done);
		IF ~done THEN antsSecurity.Halt("out Directory not found") END;
		antsPortability.ChangeDirectory(path, done);
		antsPortability.EnumerateFiles(inDirectory, "*.pgm", FALSE, FileEnum)
	END
END OnDirectory;

	(* gamma + ssq (aus statistic)*)
PROCEDURE Function1d (from, to: LONGINT): LONGREAL;
BEGIN
	RETURN globalStat.s[from, to] + globalGamma
END Function1d;

	(* gamma + ssq (aus Matrix der kumulativen Summen)*)
PROCEDURE CumFunction (from, to: LONGINT): LONGREAL;
BEGIN
	RETURN globalGamma + antsBellman.GetSsq2d(globalStat, from, globaly1, to, globaly2)
END CumFunction;

PROCEDURE MatrixFunction (from, to: LONGINT): LONGREAL;
BEGIN
	globaly1 := from;            		globaly2 := to;
	antsSecurity.SetProgress(SHORT(ENTIER(to / globalStat.N * 100)));

	antsBellman.Bellman(globalRstern, globalBellman, SHORT(LEN(globalStat.m[0])) - 1, 0, MAX(LONGINT), CumFunction, - globalGamma);                (*  frage: setzen wir hier nicht lieber auch minweite und maxweite ein ? *)
	RETURN globalBellman[LEN(globalStat.m[0]) - 1] (* fof 020709, -1 -> -2 *)
END MatrixFunction;

PROCEDURE CumFunction2 (from, to: LONGINT): LONGREAL;
BEGIN
	RETURN globalGamma * (globaly2 - globaly1 + 1) + antsBellman.GetSsq2d(globalStat, from, globaly1, to, globaly2)
END CumFunction2;

PROCEDURE MatrixFunction2 (from, to: LONGINT): LONGREAL;
BEGIN
	globaly1 := from;            		globaly2 := to;
	antsSecurity.SetProgress(SHORT(ENTIER(to / LEN(globalStat.m) * 100)));

	antsBellman.Bellman(globalRstern, globalBellman, SHORT(LEN(globalStat.m[0])) - 1, 0, MAX(LONGINT), CumFunction2, - globalGamma);                (*  frage: setzen wir hier nicht lieber auch minweite und maxweite ein ? *)
	RETURN globalBellman[LEN(globalStat.m[0]) - 1] + globalGamma * LEN(globalStat.m[0])
END MatrixFunction2;

PROCEDURE statMean (k1, k2: LONGINT): LONGREAL;
BEGIN RETURN globalStat.m[k1, k2]
END statMean;

	(* Berechnen der besten Partition fuer Matrix mit Mittelwert aus den kumulativen Summen*)
PROCEDURE CumWritePartition* (s: antsBellman.Statistic;         VAR   Parti: ARRAY OF ARRAY OF LONGREAL;                   		rstern: antsArrays.I1d;                   		y1, y2: LONGINT);                      VAR k, next, y: LONGINT;                   		mean: LONGREAL;
BEGIN
	k := LEN(s.m[0]) - 1;          (* fof 020709 *)
	WHILE(k > 0) DO
		next := rstern[k];
		mean := antsBellman.GetMean2d(s, next, y1, k - 1, y2);                    (*Mittelwert aus der Matrix der kumulativen Summen*)
		FOR y := y1 TO y2 DO
			vyLongreal.Fill(k - next, Parti[y], next, mean)
		END;
		k := next
	END
END CumWritePartition;

PROCEDURE MatrixWritePartition* (s: antsBellman.Statistic;         VAR Parti: ARRAY OF ARRAY OF LONGREAL;            		rstern: antsArrays.I1d);
VAR k, next: LONGINT;                   		bellmanneu: antsArrays.X1d;                   		rsternneu : antsArrays.I1d;
BEGIN
	k := LEN(s.m) - 1;
	WHILE(k > 0) DO
		next := rstern[k];
		globaly1 := next;                  		globaly2 := k - 1;
		(* fuer jedes Intervall der besten zeilenweise Partition nochmal bellmann...*)
		antsBellman.Bellman(rsternneu, bellmanneu, LEN(s.m[0]) - 1, 0, MAX(LONGINT), CumFunction, - globalGamma);
		(* und die beste Partition*)
		CumWritePartition(s, Parti, rsternneu, globaly1, globaly2);
		k := next
	END
END MatrixWritePartition;


	(* Skalieren von gamma  mit Min und Max von einem Vektor orig*)
PROCEDURE Scale* (VAR orig: ARRAY OF LONGREAL;                  		VAR gamma: LONGREAL);
VAR max, min: LONGREAL;                  		na, minpos, maxpos: LONGINT;
BEGIN
	vyLongreal.MinMax(LEN(orig), orig, 0, min, minpos, max, maxpos, na);
	gamma := gamma * (max - min) * (max - min)
END Scale;

	(* Skalieren von gamma mit Median von Matrix S*)
PROCEDURE ScaleMatrix* (VAR S: ARRAY OF ARRAY OF LONGREAL;                       VAR gamma: LONGREAL);
VAR   median: LONGREAL;
BEGIN
	median := antsArrays.Median2dX(S);                       	(* Median von S*)
	gamma := gamma * median * median
END ScaleMatrix;

	(* Potts auf Matrix Orig mit statistic (ssq, median)*)
PROCEDURE PottsStatLongreal* (VAR Orig, Pott: ARRAY OF ARRAY OF LONGREAL);
VAR i, h, w: LONGINT;           parti: antsArrays.X1d;       		this, last: LONGINT;
BEGIN
	h := LEN(Orig);            		w := LEN(Orig[0]);
	FOR i := 0 TO h - 1 DO
		vyLongreal.Copy(w, Orig[i], 0, Pott[i], 0)
	END;
	last := Oberon.Time();

	FOR i :=  0 TO h - 1 DO
		(*
		DoInitStatistic(globalStat, w);
		UpdateStatistic(Pott[i], globalStat);
		*)
		antsBellman.InitStatistic1d(globalStat, w);
		antsBellman.ComputeMeanStat1d(Pott[i], globalStat);
		antsBellman.Bellman(globalRstern, globalBellman, SHORT(w), 0, MAX(LONGINT), Function1d, - globalGamma);
		antsBellman.Partition(globalRstern, parti, statMean);      vyLongreal.Copy(LEN(parti), parti^, 0, Pott[i], 0)
		(*
		WritePartition(Pott[i], globalRstern, globalStat, w)
		*)
	END;

	this := Oberon.Time();
	aM.vSR("Zeit fuer Bellmann und und WritePartition:",(this - last) / Input.TimeUnit);

END PottsStatLongreal;

	(* Potts2 auf Matrix Orig mit ssq und median aus Matrix mit kumulativen Summen*)
PROCEDURE MatrixPottsLongreal* (VAR Orig, Pott: ARRAY OF ARRAY OF LONGREAL;    minweit, maxweit: LONGINT;    lengths: BOOLEAN);
VAR i, h, w: LONGINT;                   	  	(* 	Akum, AkumSq: antsArrayObjects.tLONGREALArray;     *)		this, last: LONGINT;
	Rstern: antsArrays.I1d;                Bellman: antsArrays.X1d;          s: antsBellman.Statistic;
BEGIN
	h := LEN(Orig);                                w := LEN(Orig[0]);
	FOR i := 0 TO h - 1 DO
		vyLongreal.Copy(w, Orig[i], 0, Pott[i], 0)
	END;

	(* Berechnen der Matrix mit kumulativen Summen (Akum) bzw. mit kumulativen Summe der Quadrate (AkumSq)*)
	(*
	NEW(Akum, h + 1, w + 1);
	NEW(AkumSq, h + 1, w + 1);
	*)

	antsBellman.ComputeMeanStat2d(Pott, s);
	(*
	CumSum(Pott, Akum^, AkumSq^);

	(* globale Variablen*)
	globalAkum := Akum;                 globalAkumSq := AkumSq;
	*)
	globalStat := s;

	NEW(globalRstern, w + 1);             		NEW(globalBellman, w + 1);

	last := Oberon.Time();

	IF lengths THEN
		antsBellman.Bellman(Rstern, Bellman, SHORT(h), minweit, maxweit, MatrixFunction2, - globalGamma)
	ELSE
		antsBellman.Bellman(Rstern, Bellman, SHORT(h), minweit, maxweit, MatrixFunction, - globalGamma)
	END;
	MatrixWritePartition(globalStat, Pott, Rstern);

	this := Oberon.Time();
	aM.vSR("Zeit fuer Setbellmann und MatrixWritePartition:",(this - last) / Input.TimeUnit);
END MatrixPottsLongreal;

PROCEDURE PottsToVec*;
VAR          		obj1, obj2, obj3: vyBase.Object;                  		vec1, vec2, vec3: vyLongrealVec.tVector;
	i, N, this, last: LONGINT;                  		rstern: antsArrays.I1d;                  		bellman, maxima, maxima2, data: antsArrays.X1d;                  		gamma: LONGREAL;
BEGIN
	antsCommands.InitScan("data=OBJ rek=OBJ gamma=REAL");
	IF antsCommands.ExpectObject( "data",  obj1) &
		antsCommands.ExpectObject( "rek",  obj2) &
		antsCommands.ExpectReal( "gamma",  gamma)
		THEN
		last := Oberon.Time();

		vec1 := obj1(vyLongrealVec.tVector);
		vec2 := obj2(vyLongrealVec.tVector);

		IF antsCommands.Find( "init") THEN
			(* vektoren mit Eintrag 1*)
			FOR i :=  0 TO  vyLongrealVec.Len(vec1) - 1 DO
				vyLongrealVec.Set(1, vec1, i)
			END;
			FOR i :=  0 TO  vyLongrealVec.Len(vec2) - 1 DO
				vyLongrealVec.Set(1, vec2, i)
			END
		END;

		N := vyLongrealVec.Len(vec1);
		NEW(data, N);
		vyLongrealVec.CopyToArray(vec1, data^);

		antsBellman.InitStatistic1d(globalStat,N);
		IF antsCommands.Find("median") THEN
		antsBellman.ComputeMedianStat1d(data^,globalStat)
		ELSE
		antsBellman.ComputeMeanStat1d(data^,globalStat);
		END;
		globalGamma := gamma;
		antsBellman.Bellman(rstern, bellman, SHORT(N), 0, MAX(LONGINT), Function1d, - globalGamma);

		antsBellman.Partition(rstern,data,statMean);

		vyLongrealVec.SetLen(vec2, N);
		vyLongrealVec.CopyToVec(data^, vec2, N, 0, 0);
		vyBase.Update(vec1);
		vyBase.Update(vec2);
	END
END  PottsToVec;



BEGIN aM.launch;
END antsHierarchicPotts2d.

(* testing *)

(*
(* Test fuer Potts auf vektoren*)
PROCEDURE PottsToVec*;
VAR          		obj1, obj2, obj3: vyBase.Object;                		vec1, vec2, vec3: vyLongrealVec.tVector;
i, N, this, last: LONGINT;                		rstern: antsArrays.I1d;                		bellman, maxima, maxima2, data: antsArrays.X1d;                		gamma: LONGREAL;
BEGIN
antsCommands.InitScan();
IF antsCommands.ExpectObject( "meinVektor",  obj1) &
antsCommands.ExpectObject( "zweiterVektor",  obj2) &
(* antsCommands.ExpectObject( "dritterVektor",  obj3) & *)(* to find maxima, testing *)
antsCommands.ExpectReal( "gamma",  gamma)
THEN
last := Oberon.Time();

vec1 := obj1 (vyLongrealVec.tVector);
vec2 := obj2(vyLongrealVec.tVector);
(* vec3 := obj3(vyLongrealVec.tVector);  *)

IF antsCommands.Find( "init") THEN
(* vektoren mit Eintrag 1*)
FOR i :=  0 TO  vyLongrealVec.Len(vec1) - 1 DO
vyLongrealVec.Set(1, vec1, i)
END;
FOR i :=  0 TO  vyLongrealVec.Len(vec2) - 1 DO
vyLongrealVec.Set(1, vec2, i)
END
END;

N := vyLongrealVec.Len(vec1);
NEW(data, N);
vyLongrealVec.CopyToArray(vec1, data^);

antsBellman.InitStatistic1d(globalStat,N);
antsBellman.ComputeMeanStat1d(data^,globalStat);
(*
DoInitStatistic(globalStat, N);
UpdateStatistic(data^, globalStat);
*)

Scale(data^, gamma);

globalGamma := gamma;
antsBellman.Bellman(rstern, bellman, SHORT(N), 0, MAX(LONGINT), Function1d, - globalGamma);

this := Oberon.Time();
IF antsCommands.Find( "time") THEN Out.Ln;         		Out.String("Katrin, time ellapsed :");         		Out.LongReal((this - last) / Input.TimeUnit, 10);         		Out.String(" sec")
END;
antsBellman.Partition(globalRstern,data,statMean);

(* WritePartition(data^, rstern, globalStat, N);       *)
(*
NEW(maxima, N);
NEW(maxima2, N);

FindMaxima(data^, maxima^);
FindMaxima(data^, maxima2^);
*)

vyLongrealVec.SetLen(vec2, N);
vyLongrealVec.CopyToVec(data^, vec2, N, 0, 0);
(*
vyLongrealVec.SetLen(vec3, N);
vyLongrealVec.CopyToVec(maxima^, vec3, N, 0, 0);
*)
vyBase.Update(vec1);
vyBase.Update(vec2);
(*vyBase.Update(vec3)*)
END
END  PottsToVec;
*)

(*
(*Test fuer die kumulativen Summen*)
PROCEDURE Test2*;
VAR sc: antsCommands.tScanList;
VAR i, j: LONGINT;		pos, rows, cols: LONGINT;		VAR A: antsArrayObjects.tLONGREALArray;		B, C: POINTER TO ARRAY OF ARRAY OF LONGREAL;
BEGIN
sc := antsCommands.ScanFromPar();
IF antsCommands.ExpectNumberFromKeyword(sc, "rows", 1, rows) &
antsCommands.ExpectNumberFromKeyword(sc, "columns", 2, cols) THEN
NEW(A, rows, cols);
pos := 0;
FOR j := 0 TO rows-1 DO
FOR i := 0 TO cols-1 DO
IF ~antsCommands.ExpectRealFromKeyword(sc, "", SHORT(3 + pos), A[j, i]) THEN RETURN END;
INC(pos)
END;
END;
katrinMatrix.OutMatrix(A^);

NEW(B, LEN(A), LEN(A[0]));
NEW(C, LEN(A), LEN(A[0]));

FOR i := 0 TO LEN(A)-1 DO
vyLongreal.Copy(LEN(A[0]), A[i], 0, B[i], 0);
END;
(* Test fuer die Matrix der kummulativen Summen*)
CumSum(A^, B^,C^);
katrinMatrix.OutMatrix(B^);
katrinMatrix.OutMatrix(C^);
Out.Ln;
(* Test fuer mean aus der Matrix der kummulativen Summen*)
Out.LongReal(MeanCum(B^, 0, 0, cols-1, 0), 100);
END;
END Test2;
*)
