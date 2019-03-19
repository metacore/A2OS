MODULE antsTextures IN Oberon;  	(** fof  **)
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




(* a) Modelclass
0) manual
1) interactive
(
2) interactive + estimation
3) interactive + estimation + aic
)
b) Estimate Model Class PMLE+AIC.
0) manual parameters
1) interactive zooming
2) sliding windows -> ARRAY based representation, view by new color palette
c) Estimate on Windows , PMLE
1) interactive zooming
*)


IMPORT Objects, vyBase, antsArrayObjects, antsCommands, vyRectangles, aM := antsMessages,  vyLinks, antsMDimDiscreteIsingS, antsRegions, antsKernel, antsNeighbourhoods;

TYPE

	(*
	tClass*= POINTER TO tClassDesc;
	tClassDesc*= RECORD (vyBase.ObjDesc)
	models: vyLinks.Link;
	modelcount: INTEGER;
	END;
	*)

	tArrayChain* = POINTER TO tArrayChainDesc;
	tArrayChainDesc* = RECORD
		A: POINTER TO ARRAY OF ARRAY OF LONGREAL;
		msize: INTEGER;
		next: tArrayChain
	END;

	(*
	PROCEDURE Handler* (o: Objects.Object;   VAR M: Objects.ObjMsg);
	VAR version: INTEGER;
	BEGIN
	WITH o: tClass DO
	WITH M: Objects.AttrMsg DO
	IF M.id = Objects.enum THEN
	M.Enum("Gen");   M.Enum("x");  M.Enum("y"); M.Enum("w"); M.Enum("h");     vyBase.objecthandle(o, M)
	ELSIF  M.id = Objects.get THEN
	IF M.name = "Gen"THEN
	COPY('antsTextures.Gen', M.s);   M.class := Objects.String;    M.res := 0;   RETURN
	ELSIF M.name = "count"THEN
	M.class := Objects.Int;   M.res := 0;   M.i := o.modelcount;
	ELSE vyBase.objecthandle(o, M)
	END
	ELSIF M.id = Objects.set THEN
	vyBase.objecthandle(o, M)
	ELSE vyBase.objecthandle(o, M)
	END;
	| M: Objects.FileMsg DO
	IF M.id = Objects.load THEN
	Files.ReadInt(M.R,version);
	vyBase.objecthandle(o, M);
	ELSIF M.id = Objects.store THEN
	Files.WriteInt(M.R,0);
	vyBase.objecthandle(o, M);
	END
	ELSE
	vyBase.objecthandle(o, M)
	END
	END;  (* tVector*)
	END Handler;

	PROCEDURE Gen*;
	VAR m: tClass;
	BEGIN
	NEW(m);   m.modelcount := 0; m.handle := Handler;    Objects.NewObj := m;   antsObjects.Register(m)
	END Gen;

	PROCEDURE New*;
	VAR l: antsCommands.tScanList;     name: vyName.tNameArray;
	isotropic: BOOLEAN;      size: LONGINT; r: tClass;
	BEGIN
	l := antsCommands.ScanFromPar();
	IF antsCommands.ExpectNameFromKeyword(l, "name", 1, name) THEN
	Gen;
	r := Objects.NewObj(tClass);
	vyName.RegisterNamed(r, name)
	END
	END New;

	PROCEDURE Add*;
	VAR l: antsCommands.tScanList;     name: vyName.tNameArray;
	isotropic: BOOLEAN;      size: LONGINT; r: tClass;  obj1,obj2: vyBase.Object; c: tClass;
	BEGIN
	l := antsCommands.ScanFromPar();
	IF antsCommands.ExpectObjectFromKeyword(l, "name", 1, obj1)
	& antsCommands.ExpectObjectFromKeyword(l, "model", 1, obj2)
	THEN
	c := obj1(tClass);
	vyLinks.InsertObj(c.models,obj2);
	INC(c.modelcount);
	aM.S("antsTextures: Model added ");
	END
	END Add;
	*)


PROCEDURE Try*;
	VAR A: antsArrayObjects.tINTEGERObject;   m: antsMDimDiscreteIsingS.tModel;   link: vyLinks.Link;    (* c: tClass; *)region: antsRegions.tRegion;
	l: antsCommands.tScanList;     obj1: vyBase.Object;   i: LONGINT;   T: antsNeighbourhoods.NeighbourTable;
	c: antsKernel.Kernel;
BEGIN
	l := antsCommands.ScanFromPar("name=OBJ");
	IF
		antsCommands.ExpectObjectFromKeyword(l, "name",  obj1)
		THEN
		c := obj1(antsKernel.Kernel);
		link := c.ModelClass;
		antsRegions.Gen;   region := Objects.NewObj(antsRegions.tRegion);
		antsRegions.DoSelectRegion(region);
		A := antsRegions.A;
		i := 0;
		WHILE link # NIL DO
			m := link.obj(antsMDimDiscreteIsingS.tModel);
			m.region := region;
			aM.SI("Testing Model Nr ", i);
			INC(i);
			antsMDimDiscreteIsingS.PseudoLikPrepare(A, m, T);
			aM.SR("Value : ", antsMDimDiscreteIsingS.PseudoLik(T, m, TRUE));
			link := link.link
		END
	END
END Try;
(*
PROCEDURE GoThrough*;
VAR A: antsArrayObjects.tObject; m: antsMDimDiscreteIsingS.tModel; link: vyLinks.Link;  (* c: tClass; *) region: antsRegions.tRegion;
l: antsCommands.tScanList;   obj1,obj2: vyBase.Object; i: INTEGER; min,val: LONGREAL; mini: INTEGER;
y,x: INTEGER;
B : antsArrayObjects.tObject;
c: antsKernel.Kernel;
BEGIN
l := antsCommands.ScanFromPar();
IF
antsCommands.ExpectObjectFromKeyword(l, "name", obj1)
THEN
c := obj1(tClass);
link := c.models;
antsRegions.Gen; region := Objects.NewObj(antsRegions.tRegion);
A := antsRegions.A;
antsRegions.DoSelectRegion(region);
B:= antsArrayObjects.NewObject(A.w,A.h,c.modelcount);
FOR y := 0 TO SHORT(A.h-1) DO
FOR x := 0 TO SHORT(A.w-1) DO
region.y := y-region.h DIV 2;
region.x := x-region.w DIV 2;
i := 0;
min := MAX(LONGREAL);
link := c.models;
WHILE link # NIL DO
m := link.obj(antsMDimDiscreteIsingS.tModel);
m.region := region;
(* aM.SI("Testing Model Nr ",i);
aM.SR("Value : ",antsMDimDiscreteIsingS.PseudoLik(A,m,TRUE)); *)
val := antsMDimDiscreteIsingS.PseudoLik(A,m,TRUE);
IF (-val) < min THEN min := (-val); mini := i; END;
INC(i);
link := link.link;
END;
B.A[y,x] := mini;
END;
END;
vyBase.Update(B);
link := NIL; vyLinks.InsertObj(link,B); vyBase.Show(link,1,"antsViews");
END;
END GoThrough;
*)

PROCEDURE GoThroughSel*;
	VAR A: antsArrayObjects.tINTEGERObject;   m: antsMDimDiscreteIsingS.tModel;   link: vyLinks.Link;    (* c: tClass; *)region: antsRegions.tRegion;
	l: antsCommands.tScanList;     obj1: vyBase.Object;   i: INTEGER;   min, val: LONGREAL;   mini: INTEGER;   size, to, curs: LONGINT;
	y, x: INTEGER;   ty, tx: LONGINT;
	B : antsArrayObjects.tINTEGERObject;   tac, taccur: tArrayChain;
	c: antsKernel.Kernel;
BEGIN
	l := antsCommands.ScanFromPar("name=OBJ size=INT [to=INT]");
	IF
		antsCommands.ExpectObjectFromKeyword(l, "name", obj1) & antsCommands.ExpectNumberFromKeyword(l, "size", size)
		THEN
		IF antsCommands.FindKeyword(l, "to") THEN
			IF antsCommands.ExpectNumberFromKeyword(l, "to", to) THEN ELSE to := size END
		ELSE to := size END;
		c := obj1(antsKernel.Kernel);
		link := c.ModelClass;
		antsRegions.Gen;   region := Objects.NewObj(antsRegions.tRegion);
		antsRegions.DoSelectRegion(region);
		A := antsRegions.A;
		vyRectangles.RectIntersection(region.x, region.y, region.w, region.h, 0, 0, SHORT(A.w), SHORT(A.h));
		link := c.ModelClass;    NEW(tac);   taccur := tac;
		WHILE link # NIL DO
			NEW(taccur.A, region.h, region.w);
			m := link.obj(antsMDimDiscreteIsingS.tModel);
			m.region := region;

			taccur.msize := SHORT(m.dim);
			antsMDimDiscreteIsingS.PseudoLikTab(A, m, taccur.A^);
			link := link.link;
			IF link # NIL THEN NEW(taccur.next);   taccur := taccur.next END
		END;

		FOR curs :=  size TO to DO
			B := antsArrayObjects.NewINTEGERObject(region.w, region.h, c.ModelClassCount);

			FOR y := 0 TO SHORT(region.h - 1) DO
				FOR x := 0 TO SHORT(region.w - 1) DO
					i := 0;
					min := MAX(LONGREAL);
					taccur := tac;
					WHILE taccur # NIL DO
						val := 0;
						FOR ty := y - (curs DIV 2) TO y + (curs DIV 2) DO
							FOR tx := x - (curs DIV 2) TO x + (curs DIV 2) DO
								val := val + taccur.A[ty MOD region.h, tx MOD region.w]
							END
						END;
						(* AIC Criterion : *)
						val := val - taccur.msize;
						(* end AIC Criterion *)
						(*
						val := val /(curs DIV 2 + curs DIV 2 +1)/(curs DIV 2 + curs DIV 2 +1) ;
						*)
						(*= Normalization of the Likelihood *)
						(*val := val-taccur.msize;*)
						(* i.e. AIC IS sum of pseudolikelihoods in points normalized by num of point - dimension of model *)
						(* why does it work better for low dimensions, when dimension of model is normalized too ?? *)
						(* unklar. *)(* AIC gewinnt bei kleinen Datenmengen zu gunsten des kleinsten Modells, klar, nur das kann die kleinen
						Datenmengen hinreichend beschreiben. AIC sollte also erst greifen, wenn die Punktmenge "modellgröße" hat ?
						*)
						IF (- val) < min THEN min := (- val);   mini := i  END;
						INC(i);
						taccur := taccur.next
					END;
					B.A[y, x] := mini
				END
			END;
			vyBase.Update(B);
			link := NIL;   vyLinks.InsertObj(link, B);   vyBase.Show(link, 1, "antsViews")
		END
	END
END GoThroughSel;

BEGIN aM.launch;
END antsTextures.

(*! keep cache of PseudoLik in all Points -> interactive features do need speed !
cache into region ??
array as VARPAR for Psdudolik. requires memory of size
#models * #array * 8 (LONGREAL)
(e.g. 80 Megs for 10 Models and Array Size 1000*1000
10 Models of size 200*200 3.2 Megs.
*)


Builder.Compile \Ns2
ants / antsMDimDiscreteIsingS.Mod
ants / antsTextures.Mod
~


System.Free antsTextures ~

fofAutomatic.Do
antsArrayObjects.New f3Array 100 100 6 ~
antsArrayPictures.New f3Pict f3Array ~
Voyager.Show f3Pict as antsPictureViews ~
antsFunctions.Define > name f3Function > from - 12 > to 12 > step 1 > lower 0 > upper 1 ~
antsFunctions.Set > name f3Function > function "x*x"~ (lambda, gamma)
antsKernel.Define f3Kernel ~
antsKernel.AttachArray > sampler f3Kernel > array f3Array ~
antsMC.New f3Chain ~
antsMC.Add f3Chain f3Kernel  ~~
antsRegions.New myRegion ~
~

fofAutomatic.Do
antsNeighbourhoods.New > name parameter > size 1 > nonisotropic ~
antsInteractivePar.Show > name parameter    ~
antsMDimDiscreteIsingS.NewModel > name Model > par parameter  > function f3Function ~
antsKernel.AttachAddModel > sampler f3Kernel > model Model ~
antsModels.AttachRegion > model Model > region myRegion ~
~

fofAutomatic.Do
antsNeighbourhoods.New > name parameter > size 3 > nonisotropic ~
antsInteractivePar.Show > name parameter    ~
antsMDimDiscreteIsingS.NewModel > name Model > par parameter  > function f3Function  ~
antsKernel.AttachAddModel > sampler f3Kernel > model Model ~
antsModels.AttachRegion > model Model > region myRegion ~
~
fofAutomatic.Do
antsNeighbourhoods.New > name parameter > size 5 > nonisotropic ~
antsInteractivePar.Show > name parameter    ~
antsMDimDiscreteIsingS.NewModel > name Model > par parameter  > function f3Function  ~
antsKernel.AttachAddModel > sampler f3Kernel > model Model ~
antsModels.AttachRegion > model Model > region myRegion ~
~
fofAutomatic.Do
antsNeighbourhoods.New > name parameter > size 5 > isotropic ~
antsInteractivePar.Show > name parameter    ~
antsMDimDiscreteIsingS.NewModel > name Model > par parameter  > function f3Function  ~
antsKernel.AttachAddModel > sampler f3Kernel > model Model ~
antsModels.AttachRegion > model Model > region myRegion ~
~

fofAutomatic.Do
antsRegions.SelectRegion myRegion ~
fofAutomatic.Do > interactive
antsMC.Forward f3Chain 1 1 ~
~

antsRegions.New > name myRegion ~
antsGibbs.AttachRegion > model Model > region myRegion ~
antsRegions.SelectRegion myRegion ~
antsGibbs.StepOnR > sampler Sampler  > times 10
~

antsGibbs.Step > sampler Sampler > times 10 ~

antsTextures.New > name myTexture ~
antsTextures.Add > name myTexture > model Model ~
antsTextures.Try > name myTexture ~
antsTextures.GoThrough > name myTexture ~
antsTextures.GoThroughSel > name f3Kernel  > size 1 > to 12 ~


 # yXd #




Voyager.Show Model as antsDependency ~
