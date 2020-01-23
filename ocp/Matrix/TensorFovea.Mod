MODULE TensorFovea; (** AUTHOR "Patrick Hunziker"; PURPOSE "Foveal data patterns with central high res and peripheral blur"; *)

(* 
currently foveal image structure is a small 2*2 core of inner blocks (each block has "block size" >=1 pixels ), 
surrounded by multiple concentric shells of 12 blocks of same size as inner block => doubling side length at each shell.
this i stored in a [nLayers, nShells, 12] or [nLayers, 2*nShells, 12], or [nShells, 12] or [2*nShells, 12] format.
in this format, 
shift up/down of the data is equivalent to scaling about the center,
move left/right of the data is equivalent to approximate rotation around the center.
*)

IMPORT Random, Files, Commands, WMMatrix, WMGraphics, MatrixRaster, WMArrayPanel;

TYPE Datatype* = FLOAT64;
TYPE Array* = ARRAY [?] OF Datatype;
	Tensor*=Array;
	Matrix* = ARRAY [*,*] OF Datatype;
	Image* = Array ; (** foveal images have high central resolution and peripheral blur. They are stored as with size 12 in the last dimension due to special structure *)
	ArrayFunction*= PROCEDURE{DELEGATE}(CONST m:Array): Datatype;

VAR rand:Random.Generator; 
	oldName: Files.FileName;

PROCEDURE Prod(CONST a: ARRAY [*] OF SIZE): SIZE;
VAR count, i:SIZE;
BEGIN
	count:=a[0];
	FOR i:=1 TO LEN(a,0)-1 DO count:=count*a[i] END;
	RETURN count
END Prod;

PROCEDURE Mean(CONST m: Array):Datatype;
BEGIN
	IF Prod(LEN(m))=0 THEN RETURN 0
	ELSE	RETURN SUM(m)/Prod(LEN(m))
	END;
END Mean;

PROCEDURE Max(CONST m: Array):Datatype;
BEGIN
	IF Prod(LEN(m))=0 THEN RETURN 0
	ELSE	RETURN MAX(m)
	END;
END Max;

PROCEDURE Sample(CONST m: Array):Datatype;
VAR x,y: SIGNED32;
BEGIN
	IF LEN(m,1)<=1 THEN x:=0 ELSE x:=rand.Dice(SIGNED32(LEN(m,1))) END; 
	IF LEN(m,0)<=1 THEN y:=0 ELSE y:=rand.Dice(SIGNED32(LEN(m,0))) END;
	IF LEN(m,1)*LEN(m,0)>0 THEN RETURN m[y, x] ELSE RETURN 0 END;(*catch zero size subblocks*)
END Sample;

PROCEDURE Gridpoints(CONST m: Array):Datatype;
VAR x,y: SIZE;
BEGIN
	IF LEN(m,1)*LEN(m,0)>0 THEN RETURN m[0, 0] ELSE RETURN 0 END;(*catch zero size subblocks*)
END Gridpoints;


PROCEDURE GetFovea*(CONST m:Matrix; centerX,centerY: SIZE; innerBlockSize, shells: SIGNED32): Matrix; (* *)
VAR img: Image; i, x,y, len, slen:SIZE;
BEGIN
	NEW(img, shells+1, 12); (* blocks*)
	len:=innerBlockSize; (*inner block has four quadrants, each of them has size= len*len, ...*)
	slen:=len DIV 2;
	x:=centerX;
	y:=centerY;
	img[0, 0..2]:=Mean(m[y..y+len-1, x-len..x-1]); (* rotating from 9 o clock, clockwise*)
	img[0, 3..5]:=Mean(m[y..y+len-1, x..x+len-1]); 
	img[0, 6..8]:=Mean(m[y-len..y-1, x..x+len-1]); 
	img[0, 9..11]:=Mean(m[y-len..y-1, x-len..x-1]); (* core *)(*to do: blocks instead of fixed pixel size*)
	FOR i:=0 TO shells-1 DO
		img[i+1, 0] := Mean(m[y+0*len..y+1*len-1, x-2*len..x-1*len-1]); (* performance: could substitute Mean() by simple sampling *)
		img[i+1, 1] := Mean(m[y+1*len..y+2*len-1, x-2*len..x-1*len-1]);
		img[i+1, 2] := Mean(m[y+1*len..y+2*len-1, x-1*len..x+0*len-1]);
		img[i+1, 3] := Mean(m[y+1*len..y+2*len-1, x+0*len..x+1*len-1]);
		img[i+1, 4] := Mean(m[y+1*len..y+2*len-1, x+1*len..x+2*len-1]);
		img[i+1, 5] := Mean(m[y+0*len..y+1*len-1, x+1*len..x+2*len-1]);
		img[i+1, 6] := Mean(m[y-1*len..y+0*len-1, x+1*len..x+2*len-1]);
		img[i+1, 7] := Mean(m[y-2*len..y-1*len-1, x+1*len..x+2*len-1]);
		img[i+1, 8] := Mean(m[y-2*len..y-1*len-1, x+0*len..x+1*len-1]);
		img[i+1, 9] := Mean(m[y-2*len..y-1*len-1, x-1*len..x+0*len-1]);
		img[i+1,10] := Mean(m[y-2*len..y-1*len-1, x-2*len..x-1*len-1]);
		img[i+1,11] := Mean(m[y-1*len..y+0*len-1, x-2*len..x-1*len-1]);

		len:=len*2;
		slen:=len DIV 2
	END;
	RETURN img
END GetFovea;

PROCEDURE GetFovea2*(CONST m:Matrix; centerX,centerY:SIZE; innerBlockSize, shells: SIGNED32): Matrix; (* *)
VAR img: Image; i, x,y, len, slen:SIZE;
BEGIN
	NEW(img, 2*shells+1, 12); (* subblocks *)
	len:=innerBlockSize;
	slen:=len DIV 2;
	x:=centerX;
	y:=centerY;
	img[0, 0..2]:=Mean(m[y..y+len-1, x-len..x-1]); (* rotating from 9 o clock, clockwise*)
	img[0, 3..5]:=Mean(m[y..y+len-1, x..x+len-1]); 
	img[0, 6..8]:=Mean(m[y-len..y-1, x..x+len-1]); 
	img[0, 9..11]:=Mean(m[y-len..y-1, x-len..x-1]); (* core *)(*to do: blocks instead of fixed pixel size*)
	FOR i:=0 TO shells-1 DO
		
		img[2*i+1, 0] := Mean(m[y+0*len..y+1*len-1, x-2*len+slen..x-1*len-1]); (* performance: could substitute Mean() by simple sampling *)
		img[2*i+1, 1] := Mean(m[y+1*len..y+2*len-1, x-2*len+slen..x-1*len-1]);
		img[2*i+1, 2] := Mean(m[y+1*len..y+1*len+MAX(1,slen)-1, x-1*len..x+0*len-1]);
		img[2*i+1, 3] := Mean(m[y+1*len..y+1*len+MAX(1,slen)-1, x+0*len..x+1*len-1]);
		img[2*i+1, 4] := Mean(m[y+1*len..y+1*len+MAX(1,slen)-1, x+1*len..x+2*len-1]);
		img[2*i+1, 5] := Mean(m[y+0*len..y+1*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
		img[2*i+1, 6] := Mean(m[y-1*len..y+0*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
		img[2*i+1, 7] := Mean(m[y-2*len..y-1*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
		img[2*i+1, 8] := Mean(m[y-2*len+slen..y-1*len-1, x+0*len..x+1*len-1]);
		img[2*i+1, 9] := Mean(m[y-2*len+slen..y-1*len-1, x-1*len..x+0*len-1]);
		img[2*i+1,10] := Mean(m[y-2*len+slen..y-1*len-1, x-2*len..x-1*len-1]); (*! there is some indexing problem here ...*)
		img[2*i+1,11] := Mean(m[y-1*len..y+0*len-1, x-2*len+slen..x-1*len-1]);

		img[2*i+2, 0] := Mean(m[y+0*len..y+1*len-1, x-2*len..x-2*len+MAX(1,slen)-1]); 
		img[2*i+2, 1] := Mean(m[y+1*len..y+2*len-1, x-2*len..x-2*len+MAX(1,slen)-1]);
		img[2*i+2, 2] := Mean(m[y+1*len+slen..y+2*len-1, x-1*len..x+0*len-1]);
		img[2*i+2, 3] := Mean(m[y+1*len+slen..y+2*len-1, x+0*len..x+1*len-1]);
		img[2*i+2, 4] := Mean(m[y+1*len+slen..y+2*len-1, x+1*len..x+2*len-1]);
		img[2*i+2, 5] := Mean(m[y+0*len..y+1*len-1, x+1*len+slen..x+2*len-1]);
		img[2*i+2, 6] := Mean(m[y-1*len..y+0*len-1, x+1*len+slen..x+2*len-1]);
		img[2*i+2, 7] := Mean(m[y-2*len..y-1*len-1, x+1*len+slen..x+2*len-1]);
		img[2*i+2, 8] := Mean(m[y-2*len..y-2*len+MAX(1,slen)-1, x+0*len..x+1*len-1]);
		img[2*i+2, 9] := Mean(m[y-2*len..y-2*len+MAX(1,slen)-1, x-1*len..x+0*len-1]);
		img[2*i+2,10] := Mean(m[y-2*len..y-2*len+MAX(1,slen)-1, x-2*len..x-1*len-1]);
		img[2*i+2,11] := Mean(m[y-1*len..y+0*len-1, x-2*len..x-2*len+MAX(1,slen)-1]);

		len:=len*2;
		slen:=len DIV 2
	END;
	RETURN img
END GetFovea2;

PROCEDURE GetFoveaA2*(CONST m:Tensor; centerX,centerY: SIZE; innerBlockSize, shells: SIGNED32; func: ArrayFunction): Tensor; (*! tbd: which index position is layer index ? *)
VAR img0, img: Tensor; i, x,y, len, slen, layer:SIZE;
BEGIN
	img0:=m;
	ASSERT(DIM(m)=3, 202); (*implementation limitation*)
	NEW(img, LEN(m,0), 2*shells+1, 12); (* subblocks *)
	x:=centerX;
	y:=centerY;
	FOR layer:=0 TO LEN(m,0)-1 DO
		len:=innerBlockSize;
		slen:=len DIV 2;		
		img[layer, 0, 0..2]:=func(m[layer, y..y+len-1, x-len..x-1]); (* rotating from 9 o clock, clockwise*)
		img[layer, 0, 3..5]:=func(m[layer, y..y+len-1, x..x+len-1]); 
		img[layer, 0, 6..8]:=func(m[layer, y-len..y-1, x..x+len-1]); 
		img[layer, 0, 9..11]:=func(m[layer, y-len..y-1, x-len..x-1]); (* core *)(*to do: blocks instead of fixed pixel size*)
		FOR i:=0 TO shells-1 DO	
			img[layer, 2*i+1, 0] := func(m[layer, y+0*len..y+1*len-1, x-2*len+slen..x-1*len-1]); (* performance: could substitute func() by simple sampling *)
			img[layer, 2*i+1, 1] := func(m[layer, y+1*len..y+2*len-1, x-2*len+slen..x-1*len-1]);
			img[layer, 2*i+1, 2] := func(m[layer, y+1*len..y+1*len+MAX(1,slen)-1, x-1*len..x+0*len-1]);
			img[layer, 2*i+1, 3] := func(m[layer, y+1*len..y+1*len+MAX(1,slen)-1, x+0*len..x+1*len-1]);
			img[layer, 2*i+1, 4] := func(m[layer, y+1*len..y+1*len+MAX(1,slen)-1, x+1*len..x+2*len-1]);
			img[layer, 2*i+1, 5] := func(m[layer, y+0*len..y+1*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
			img[layer, 2*i+1, 6] := func(m[layer, y-1*len..y+0*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
			img[layer, 2*i+1, 7] := func(m[layer, y-2*len..y-1*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
			img[layer, 2*i+1, 8] := func(m[layer, y-2*len+slen..y-1*len-1, x+0*len..x+1*len-1]);
			img[layer, 2*i+1, 9] := func(m[layer, y-2*len+slen..y-1*len-1, x-1*len..x+0*len-1]);
			img[layer, 2*i+1,10] := func(m[layer, y-2*len+slen..y-1*len-1, x-2*len..x-1*len-1]); (*! there is some indexing problem here ...*)
			img[layer, 2*i+1,11] := func(m[layer, y-1*len..y+0*len-1, x-2*len+slen..x-1*len-1]);
 
			img[layer, 2*i+2, 0] := func(m[layer, y+0*len..y+1*len-1, x-2*len..x-2*len+MAX(1,slen)-1]); 
			img[layer, 2*i+2, 1] := func(m[layer, y+1*len..y+2*len-1, x-2*len..x-2*len+MAX(1,slen)-1]);
			img[layer, 2*i+2, 2] := func(m[layer, y+1*len+slen..y+2*len-1, x-1*len..x+0*len-1]);
			img[layer, 2*i+2, 3] := func(m[layer, y+1*len+slen..y+2*len-1, x+0*len..x+1*len-1]);
			img[layer, 2*i+2, 4] := func(m[layer, y+1*len+slen..y+2*len-1, x+1*len..x+2*len-1]);
			img[layer, 2*i+2, 5] := func(m[layer, y+0*len..y+1*len-1, x+1*len+slen..x+2*len-1]);
			img[layer, 2*i+2, 6] := func(m[layer, y-1*len..y+0*len-1, x+1*len+slen..x+2*len-1]);
			img[layer, 2*i+2, 7] := func(m[layer, y-2*len..y-1*len-1, x+1*len+slen..x+2*len-1]);
			img[layer, 2*i+2, 8] := func(m[layer, y-2*len..y-2*len+MAX(1,slen)-1, x+0*len..x+1*len-1]);
			img[layer, 2*i+2, 9] := func(m[layer, y-2*len..y-2*len+MAX(1,slen)-1, x-1*len..x+0*len-1]);
			img[layer, 2*i+2,10] := func(m[layer, y-2*len..y-2*len+MAX(1,slen)-1, x-2*len..x-1*len-1]);
			img[layer, 2*i+2,11] := func(m[layer, y-1*len..y+0*len-1, x-2*len..x-2*len+MAX(1,slen)-1]);
			len:=len*2;
			slen:=len DIV 2
		END
	END;
	RETURN img
END GetFoveaA2;

PROCEDURE GetFoveaSampledA2*(CONST m:Tensor; centerX,centerY: SIZE; innerBlockSize, shells: SIGNED32): Tensor; (*! tbd: which index position is layer index ? *)
VAR img0, img: Tensor; i, x,y, len, slen, layer:SIZE;
BEGIN
	img0:=m;
	ASSERT(DIM(m)=3, 202); (*implementation limitation*)
	NEW(img, LEN(m,0), 2*shells+1, 12); (* subblocks *)

	x:=centerX;
	y:=centerY;
	FOR layer:=0 TO LEN(m,0)-1 DO
		len:=innerBlockSize;
		slen:=len DIV 2;		
		img[layer, 0, 0..2]:=Mean(m[layer, y..y+len-1, x-len..x-1]); (* rotating from 9 o clock, clockwise*)
		img[layer, 0, 3..5]:=Mean(m[layer, y..y+len-1, x..x+len-1]); 
		img[layer, 0, 6..8]:=Mean(m[layer, y-len..y-1, x..x+len-1]); 
		img[layer, 0, 9..11]:=Mean(m[layer, y-len..y-1, x-len..x-1]); (* core *)(*to do: blocks instead of fixed pixel size*)
		FOR i:=0 TO shells-1 DO	
			img[layer, 2*i+1, 0] := Sample(m[layer, y+0*len..y+1*len-1, x-2*len+slen..x-1*len-1]);  
			img[layer, 2*i+1, 1] := Sample(m[layer, y+1*len..y+2*len-1, x-2*len+slen..x-1*len-1]);
			img[layer, 2*i+1, 2] := Sample(m[layer, y+1*len..y+1*len+MAX(1,slen)-1, x-1*len..x+0*len-1]);
			img[layer, 2*i+1, 3] := Sample(m[layer, y+1*len..y+1*len+MAX(1,slen)-1, x+0*len..x+1*len-1]);
			img[layer, 2*i+1, 4] := Sample(m[layer, y+1*len..y+1*len+MAX(1,slen)-1, x+1*len..x+2*len-1]);
			img[layer, 2*i+1, 5] := Sample(m[layer, y+0*len..y+1*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
			img[layer, 2*i+1, 6] := Sample(m[layer, y-1*len..y+0*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
			img[layer, 2*i+1, 7] := Sample(m[layer, y-2*len..y-1*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
			img[layer, 2*i+1, 8] := Sample(m[layer, y-2*len+slen..y-1*len-1, x+0*len..x+1*len-1]);
			img[layer, 2*i+1, 9] := Sample(m[layer, y-2*len+slen..y-1*len-1, x-1*len..x+0*len-1]);
			img[layer, 2*i+1,10] := Sample(m[layer, y-2*len+slen..y-1*len-1, x-2*len..x-1*len-1]); (*! there is some indexing problem here ...*)
			img[layer, 2*i+1,11] := Sample(m[layer, y-1*len..y+0*len-1, x-2*len+slen..x-1*len-1]);
 
			img[layer, 2*i+2, 0] := Sample(m[layer, y+0*len..y+1*len-1, x-2*len..x-2*len+MAX(1,slen)-1]); 
			img[layer, 2*i+2, 1] := Sample(m[layer, y+1*len..y+2*len-1, x-2*len..x-2*len+MAX(1,slen)-1]);
			img[layer, 2*i+2, 2] := Sample(m[layer, y+1*len+slen..y+2*len-1, x-1*len..x+0*len-1]);
			img[layer, 2*i+2, 3] := Sample(m[layer, y+1*len+slen..y+2*len-1, x+0*len..x+1*len-1]);
			img[layer, 2*i+2, 4] := Sample(m[layer, y+1*len+slen..y+2*len-1, x+1*len..x+2*len-1]);
			img[layer, 2*i+2, 5] := Sample(m[layer, y+0*len..y+1*len-1, x+1*len+slen..x+2*len-1]);
			img[layer, 2*i+2, 6] := Sample(m[layer, y-1*len..y+0*len-1, x+1*len+slen..x+2*len-1]);
			img[layer, 2*i+2, 7] := Sample(m[layer, y-2*len..y-1*len-1, x+1*len+slen..x+2*len-1]);
			img[layer, 2*i+2, 8] := Sample(m[layer, y-2*len..y-2*len+MAX(1,slen)-1, x+0*len..x+1*len-1]);
			img[layer, 2*i+2, 9] := Sample(m[layer, y-2*len..y-2*len+MAX(1,slen)-1, x-1*len..x+0*len-1]);
			img[layer, 2*i+2,10] := Sample(m[layer, y-2*len..y-2*len+MAX(1,slen)-1, x-2*len..x-1*len-1]);
			img[layer, 2*i+2,11] := Sample(m[layer, y-1*len..y+0*len-1, x-2*len..x-2*len+MAX(1,slen)-1]);
			len:=len*2;
			slen:=len DIV 2
		END
	END;
	RETURN img
END GetFoveaSampledA2;


PROCEDURE GetFoveaSampled2*(CONST m:Matrix; centerX,centerY: SIZE; innerBlockSize, shells: SIGNED32): Matrix; (* *)
VAR img: Image; i, x,y, len, slen:SIZE;
BEGIN
	NEW(img, 2*shells+1, 12); (* subblocks *)
	len:=innerBlockSize;
	slen:=len DIV 2;
	x:=centerX;
	y:=centerY;
	img[0, 0..2]:=Mean(m[y..y+len-1, x-len..x-1]); (* rotating from 9 o clock, clockwise*)
	img[0, 3..5]:=Mean(m[y..y+len-1, x..x+len-1]); 
	img[0, 6..8]:=Mean(m[y-len..y-1, x..x+len-1]); 
	img[0, 9..11]:=Mean(m[y-len..y-1, x-len..x-1]); (* core *)(*to do: blocks instead of fixed pixel size*)
	FOR i:=0 TO shells-1 DO
		
		img[2*i+1, 0] := Sample(m[y+0*len..y+1*len-1, x-2*len+slen..x-1*len-1]); 
		img[2*i+1, 1] := Sample(m[y+1*len..y+2*len-1, x-2*len+slen..x-1*len-1]);
		img[2*i+1, 2] := Sample(m[y+1*len..y+1*len+MAX(1,slen)-1, x-1*len..x+0*len-1]);
		img[2*i+1, 3] := Sample(m[y+1*len..y+1*len+MAX(1,slen)-1, x+0*len..x+1*len-1]);
		img[2*i+1, 4] := Sample(m[y+1*len..y+1*len+MAX(1,slen)-1, x+1*len..x+2*len-1]);
		img[2*i+1, 5] := Sample(m[y+0*len..y+1*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
		img[2*i+1, 6] := Sample(m[y-1*len..y+0*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
		img[2*i+1, 7] := Sample(m[y-2*len..y-1*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
		img[2*i+1, 8] := Sample(m[y-2*len+slen..y-1*len-1, x+0*len..x+1*len-1]);
		img[2*i+1, 9] := Sample(m[y-2*len+slen..y-1*len-1, x-1*len..x+0*len-1]);
		img[2*i+1,10] := Sample(m[y-2*len+slen..y-1*len-1, x-2*len..x-1*len-1]);
		img[2*i+1,11] := Sample(m[y-1*len..y+0*len-1, x-2*len+slen..x-1*len-1]);

		img[2*i+2, 0] := Sample(m[y+0*len..y+1*len-1, x-2*len..x-2*len+MAX(1,slen)-1]); 
		img[2*i+2, 1] := Sample(m[y+1*len..y+2*len-1, x-2*len..x-2*len+MAX(1,slen)-1]);
		img[2*i+2, 2] := Sample(m[y+1*len+slen..y+2*len-1, x-1*len..x+0*len-1]);
		img[2*i+2, 3] := Sample(m[y+1*len+slen..y+2*len-1, x+0*len..x+1*len-1]);
		img[2*i+2, 4] := Sample(m[y+1*len+slen..y+2*len-1, x+1*len..x+2*len-1]);
		img[2*i+2, 5] := Sample(m[y+0*len..y+1*len-1, x+1*len+slen..x+2*len-1]);
		img[2*i+2, 6] := Sample(m[y-1*len..y+0*len-1, x+1*len+slen..x+2*len-1]);
		img[2*i+2, 7] := Sample(m[y-2*len..y-1*len-1, x+1*len+slen..x+2*len-1]);
		img[2*i+2, 8] := Sample(m[y-2*len..y-2*len+MAX(1,slen)-1, x+0*len..x+1*len-1]);
		img[2*i+2, 9] := Sample(m[y-2*len..y-2*len+MAX(1,slen)-1, x-1*len..x+0*len-1]);
		img[2*i+2,10] := Sample(m[y-2*len..y-2*len+MAX(1,slen)-1, x-2*len..x-1*len-1]);
		img[2*i+2,11] := Sample(m[y-1*len..y+0*len-1, x-2*len..x-2*len+MAX(1,slen)-1]);

		len:=len*2;
		slen:=len DIV 2
	END;
	RETURN img
END GetFoveaSampled2;



PROCEDURE GetFoveaSampled*(CONST m:Matrix; centerX,centerY: SIZE; innerBlockSize, shells: SIGNED32): Matrix; (* *)
VAR img: Image; i, x,y, len:SIZE;
BEGIN
	NEW(img, shells+1, 12);
	len:=innerBlockSize;
	x:=centerX;
	y:=centerY;
	img[0, 0..2]:=Sample(m[y..y+len-1, x-len..x-1]); (* rotating from 9 o clock, clockwise*)
	img[0, 3..5]:=Sample(m[y..y+len-1, x..x+len-1]); 
	img[0, 6..8]:=Sample(m[y-len..y-1, x..x+len-1]); 
	img[0, 9..11]:=Sample(m[y-len..y-1, x-len..x-1]); (* core *)(*to do: blocks instead of fixed pixel size*)
	FOR i:=0 TO shells-1 DO
		img[i+1, 0] := Sample(m[y+0*len..y+1*len-1, x-2*len..x-1*len-1]); (* performance: could substitute Mean() by simple sampling *)
		img[i+1, 1] := Sample(m[y+1*len..y+2*len-1, x-2*len..x-1*len-1]);
		img[i+1, 2] := Sample(m[y+1*len..y+2*len-1, x-1*len..x+0*len-1]);
		img[i+1, 3] := Sample(m[y+1*len..y+2*len-1, x+0*len..x+1*len-1]);
		img[i+1, 4] := Sample(m[y+1*len..y+2*len-1, x+1*len..x+2*len-1]);
		img[i+1, 5] := Sample(m[y+0*len..y+1*len-1, x+1*len..x+2*len-1]);
		img[i+1, 6] := Sample(m[y-1*len..y+0*len-1, x+1*len..x+2*len-1]);
		img[i+1, 7] := Sample(m[y-2*len..y-1*len-1, x+1*len..x+2*len-1]);
		img[i+1, 8] := Sample(m[y-2*len..y-1*len-1, x+0*len..x+1*len-1]);
		img[i+1, 9] := Sample(m[y-2*len..y-1*len-1, x-1*len..x+0*len-1]);
		img[i+1,10] := Sample(m[y-2*len..y-1*len-1, x-2*len..x-1*len-1]);
		img[i+1,11] := Sample(m[y-1*len..y+0*len-1, x-2*len..x-1*len-1]);
		len:=len*2;
	END;
	RETURN img
END GetFoveaSampled;

PROCEDURE ReconstructFovea*(CONST img:Matrix; (*centerX,centerY: SIZE; *)innerBlockSize, shells: SIGNED32): Matrix; (* *)
VAR m: Image; i, x,y, len, size:SIGNED32;
BEGIN
	size := 2 * innerBlockSize;
	FOR i:=0 TO shells-1 DO
		size:=size * 2;
	END;
	NEW(m, size, size);
	len:=innerBlockSize;
	x:=size DIV 2;
	y:=size DIV 2;
	m[y..y+len-1, x-len..x-1]:=Mean(img[0, 0..2]); (* rotating from 9 o clock, clockwise*)
	m[y..y+len-1, x..x+len-1]:=Mean(img[0, 3..5]); 
	m[y-len..y-1, x..x+len-1]:=Mean(img[0, 6..8]); 
	m[y-len..y-1, x-len..x-1]:=Mean(img[0, 9..11]); (* core *)(*to do: blocks instead of fixed pixel size*)
	FOR i:=0 TO shells-1 DO
		m[y+0*len..y+1*len-1, x-2*len..x-1*len-1] := img[i+1, 0]; 
		m[y+1*len..y+2*len-1, x-2*len..x-1*len-1] := img[i+1, 1];
		m[y+1*len..y+2*len-1, x-1*len..x+0*len-1] := img[i+1, 2];
		m[y+1*len..y+2*len-1, x+0*len..x+1*len-1] := img[i+1, 3];
		m[y+1*len..y+2*len-1, x+1*len..x+2*len-1] := img[i+1, 4];
		m[y+0*len..y+1*len-1, x+1*len..x+2*len-1] := img[i+1, 5];
		m[y-1*len..y+0*len-1, x+1*len..x+2*len-1] := img[i+1, 6];
		m[y-2*len..y-1*len-1, x+1*len..x+2*len-1] := img[i+1, 7];
		m[y-2*len..y-1*len-1, x+0*len..x+1*len-1] := img[i+1, 8];
		m[y-2*len..y-1*len-1, x-1*len..x+0*len-1] := img[i+1, 9];
		m[y-2*len..y-1*len-1, x-2*len..x-1*len-1] := img[i+1, 10];
		m[y-1*len..y+0*len-1, x-2*len..x-1*len-1] := img[i+1, 11];
		len:=len*2;
	END;
	RETURN m
END ReconstructFovea;

PROCEDURE ReconstructFovea2*(CONST img:Matrix; (*centerX,centerY: SIZE; *)innerBlockSize, shells: SIGNED32): Matrix; (* *)
VAR m: Image; i, x,y, len, slen, size:SIGNED32;
BEGIN
	size := 2 * innerBlockSize;
	FOR i:=0 TO shells-1 DO
		size:=size * 2;
	END;
	NEW(m, size, size);
	len:=innerBlockSize;
	slen:=len DIV 2;
	x:=size DIV 2;
	y:=size DIV 2;
	m[y..y+len-1, x-len..x-1]:=Mean(img[0, 0..2]); (* rotating from 9 o clock, clockwise*)
	m[y..y+len-1, x..x+len-1]:=Mean(img[0, 3..5]); 
	m[y-len..y-1, x..x+len-1]:=Mean(img[0, 6..8]); 
	m[y-len..y-1, x-len..x-1]:=Mean(img[0, 9..11]); (* core *)(*to do: blocks instead of fixed pixel size*)
	FOR i:=0 TO shells-1 DO
		m[y+0*len..y+1*len-1, x-2*len+slen..x-1*len-1] := img[2*i+1, 0]; (* performance: could substitute Mean() by simple sampling *)
		m[y+1*len..y+2*len-1, x-2*len+slen..x-1*len-1] := img[2*i+1, 1];
		m[y+1*len..y+1*len+slen-1, x-1*len..x+0*len-1] := img[2*i+1, 2];
		m[y+1*len..y+1*len+slen-1, x+0*len..x+1*len-1] := img[2*i+1, 3];
		m[y+1*len..y+1*len+slen-1, x+1*len..x+2*len-1] := img[2*i+1, 4];
		m[y+0*len..y+1*len-1, x+1*len..x+1*len+slen-1] := img[2*i+1, 5];
		m[y-1*len..y+0*len-1, x+1*len..x+1*len+slen-1] := img[2*i+1, 6];
		m[y-2*len..y-1*len-1, x+1*len..x+1*len+slen-1] := img[2*i+1, 7];
		m[y-2*len+slen..y-1*len-1, x+0*len..x+1*len-1] := img[2*i+1, 8];
		m[y-2*len+slen..y-1*len-1, x-1*len..x+0*len-1] := img[2*i+1, 9];
		m[y-2*len+slen..y-1*len-1, x-2*len..x-1*len-1] := img[2*i+1, 10];
		m[y-1*len..y+0*len-1, x-2*len+slen..x-1*len-1] := img[2*i+1, 11];      

		m[y+0*len..y+1*len-1, x-2*len..x-2*len+slen-1] := img[2*i+2, 0]; 
		m[y+1*len..y+2*len-1, x-2*len..x-2*len+slen-1] := img[2*i+2, 1];
		m[y+1*len+slen..y+2*len-1, x-1*len..x+0*len-1] := img[2*i+2, 2];
		m[y+1*len+slen..y+2*len-1, x+0*len..x+1*len-1] := img[2*i+2, 3];
		m[y+1*len+slen..y+2*len-1, x+1*len..x+2*len-1] := img[2*i+2, 4];
		m[y+0*len..y+1*len-1, x+1*len+slen..x+2*len-1] := img[2*i+2, 5];
		m[y-1*len..y+0*len-1, x+1*len+slen..x+2*len-1] := img[2*i+2, 6];
		m[y-2*len..y-1*len-1, x+1*len+slen..x+2*len-1] := img[2*i+2, 7];
		m[y-2*len..y-2*len+slen-1, x+0*len..x+1*len-1] := img[2*i+2, 8];
		m[y-2*len..y-2*len+slen-1, x-1*len..x+0*len-1] := img[2*i+2, 9];
		m[y-2*len..y-2*len+slen-1, x-2*len..x-1*len-1] := img[2*i+2, 10];
		m[y-1*len..y+0*len-1, x-2*len..x-2*len+slen-1] := img[2*i+2, 11];
		len:=len*2;
		slen:=len DIV 2;
	END;
	RETURN m
END ReconstructFovea2;

PROCEDURE ReconstructFoveaA2*(CONST img:Tensor; innerBlockSize, shells: SIGNED32): Tensor; (* *)
VAR m: Tensor; i, x,y, len, slen, size, layer:SIZE;
BEGIN
	ASSERT(DIM(img)=3, 202); (*implementation limitation*)
	size := 2 * innerBlockSize;
	FOR i:=0 TO shells-1 DO
		size:=size * 2;
	END;
	NEW(m, LEN(img,0), size, size);
	x:=size DIV 2;
	y:=size DIV 2;
	FOR layer:=0 TO LEN(img,0)-1 DO
		len:=innerBlockSize;
		slen:=len DIV 2;
		m[layer, y..y+len-1, x-len..x-1]:=Mean(img[layer, 0, 0..2]); (* rotating from 9 o clock, clockwise*)
		m[layer, y..y+len-1, x..x+len-1]:=Mean(img[layer, 0, 3..5]); 
		m[layer, y-len..y-1, x..x+len-1]:=Mean(img[layer, 0, 6..8]); 
		m[layer, y-len..y-1, x-len..x-1]:=Mean(img[layer, 0, 9..11]); (* core *)(*to do: blocks instead of fixed pixel size*)
		FOR i:=0 TO shells-1 DO
			m[layer, y+0*len..y+1*len-1, x-2*len+slen..x-1*len-1] := img[layer, 2*i+1, 0]; (* performance: could substitute Mean() by simple sampling *)
			m[layer, y+1*len..y+2*len-1, x-2*len+slen..x-1*len-1] := img[layer, 2*i+1, 1];
			m[layer, y+1*len..y+1*len+slen-1, x-1*len..x+0*len-1] := img[layer, 2*i+1, 2];
			m[layer, y+1*len..y+1*len+slen-1, x+0*len..x+1*len-1] := img[layer, 2*i+1, 3];
			m[layer, y+1*len..y+1*len+slen-1, x+1*len..x+2*len-1] := img[layer, 2*i+1, 4];
			m[layer, y+0*len..y+1*len-1, x+1*len..x+1*len+slen-1] := img[layer, 2*i+1, 5];
			m[layer, y-1*len..y+0*len-1, x+1*len..x+1*len+slen-1] := img[layer, 2*i+1, 6];
			m[layer, y-2*len..y-1*len-1, x+1*len..x+1*len+slen-1] := img[layer, 2*i+1, 7];
			m[layer, y-2*len+slen..y-1*len-1, x+0*len..x+1*len-1] := img[layer, 2*i+1, 8];
			m[layer, y-2*len+slen..y-1*len-1, x-1*len..x+0*len-1] := img[layer, 2*i+1, 9];
			m[layer, y-2*len+slen..y-1*len-1, x-2*len..x-1*len-1] := img[layer, 2*i+1, 10];
			m[layer, y-1*len..y+0*len-1, x-2*len+slen..x-1*len-1] := img[layer, 2*i+1, 11];      

			m[layer, y+0*len..y+1*len-1, x-2*len..x-2*len+slen-1] := img[layer, 2*i+2, 0]; 
			m[layer, y+1*len..y+2*len-1, x-2*len..x-2*len+slen-1] := img[layer, 2*i+2, 1];
			m[layer, y+1*len+slen..y+2*len-1, x-1*len..x+0*len-1] := img[layer, 2*i+2, 2];
			m[layer, y+1*len+slen..y+2*len-1, x+0*len..x+1*len-1] := img[layer, 2*i+2, 3];
			m[layer, y+1*len+slen..y+2*len-1, x+1*len..x+2*len-1] := img[layer, 2*i+2, 4];
			m[layer, y+0*len..y+1*len-1, x+1*len+slen..x+2*len-1] := img[layer, 2*i+2, 5];
			m[layer, y-1*len..y+0*len-1, x+1*len+slen..x+2*len-1] := img[layer, 2*i+2, 6];
			m[layer, y-2*len..y-1*len-1, x+1*len+slen..x+2*len-1] := img[layer, 2*i+2, 7];
			m[layer, y-2*len..y-2*len+slen-1, x+0*len..x+1*len-1] := img[layer, 2*i+2, 8];
			m[layer, y-2*len..y-2*len+slen-1, x-1*len..x+0*len-1] := img[layer, 2*i+2, 9];
			m[layer, y-2*len..y-2*len+slen-1, x-2*len..x-1*len-1] := img[layer, 2*i+2, 10];
			m[layer, y-1*len..y+0*len-1, x-2*len..x-2*len+slen-1] := img[layer, 2*i+2, 11];
			len:=len*2;
			slen:=len DIV 2;
		END;
	END;
	RETURN m
END ReconstructFoveaA2;


PROCEDURE Test*;
VAR img, recon, fovea: Matrix;
	im,fo, re: WMMatrix.Window;
	i:SIZE;
BEGIN
	NEW(img, 512, 512);
	FOR i:=2 TO LEN(img,0)-3 BY 10 DO
		img[i-2..i+2, i-2..i+2] := 1;
	END;
	fovea:=GetFovea(img, 256, 256, 1, 6);
	recon:=ReconstructFovea(fovea, 1, 6);
	NEW(im, img, "data"); im.AddWindow;
	NEW(fo, fovea, "fovea"); fo.AddWindow;
	NEW(re, recon, "recon"); re.AddWindow;
END Test;

PROCEDURE Test0*;
VAR img, recon, fovea: Matrix;
	im,fo, re: WMMatrix.Window;
	i:SIZE;
BEGIN
	NEW(img, 512, 512);
	FOR i:=2 TO LEN(img,0)-3 BY 10 DO
		img[i-2..i+2, i-2..i+2] := 1; 
	END;
	fovea:=GetFovea2(img, 256, 256, 1, 6);
	recon:=ReconstructFovea2(fovea, 1, 6);
	NEW(im, img, "data"); im.AddWindow;
	NEW(fo, fovea, "fovea"); fo.AddWindow;
	NEW(re, recon, "recon"); re.AddWindow;
END Test0;


PROCEDURE TestA*;
VAR img, recon, fovea: Tensor;
	i:SIZE;
BEGIN
	NEW(img, 3, 512, 512);
	FOR i:=2 TO LEN(img,1)-3 BY 10 DO
		img[*,i-2..i+2, i-2..i+2] := 1;
	END;
	img[1,?]:=img[0,?] /2; 
	fovea:=GetFoveaA2(img, 256, 256, 1, 6, Mean);
	recon:=ReconstructFoveaA2(fovea, 1, 6);
	
	WMArrayPanel.AddWindow(img, "img"); 
	WMArrayPanel.AddWindow(fovea, "fovea"); 
	WMArrayPanel.AddWindow(recon, "recon"); 
END TestA;


PROCEDURE Test1*(context:Commands.Context); (* 1 layer, quadratic blocks in periphery*)
VAR 
	raster3 : ARRAY [*,*,*] OF SIGNED16;
	raster, recon, fovea: Matrix;
	im,fo, re: WMMatrix.Window;
	img: WMGraphics.Image;
	len, x, y:SIZE;
	name: Files.FileName;
BEGIN
	IF ~context.arg.GetString(name) THEN COPY("Yellow_Duck.jpg",name) END;
	img:=WMGraphics.LoadImage(name, FALSE);
	MatrixRaster.ImageToArray(img, raster3);
	raster:=raster3[1,*,*];
	len:=LEN(raster,0); 
	x:=len DIV 2 -64 + rand.Dice(128);
	y:=len DIV 2 -64 + rand.Dice(128);
	fovea:=GetFovea(raster, x, y, 1, 7); (* compressed averaging sampling*)
	(*fovea:=GetFoveaSampled(raster, x, y, 2, 6);*) (*compressed random sampling*)
	recon:=ReconstructFovea(fovea, 1, 7);
	IF name#oldName THEN 
		NEW(im, raster, "raster"); im.AddWindow;
		NEW(fo, fovea, "fovea"); fo.AddWindow;
	END;
	NEW(re, recon, "recon"); re.AddWindow;
	COPY(name, oldName);
END Test1;

PROCEDURE Test2*(context:Commands.Context); (* 1 layer, split blocks in pheriphery*)
VAR 
	raster3 : ARRAY [*,*,*] OF SIGNED16;
	raster, recon, fovea: Matrix;
	im,fo, re: WMMatrix.Window;
	img: WMGraphics.Image;
	len, x, y:SIZE;
	name: Files.FileName;
BEGIN
	IF ~context.arg.GetString(name) THEN COPY("Yellow_Duck.jpg",name) END;
	img:=WMGraphics.LoadImage(name, FALSE);
	MatrixRaster.ImageToArray(img, raster3);
	raster:=raster3[1,*,*];
	len:=LEN(raster,0); 
	x:=len DIV 2 -64 + rand.Dice(128);
	y:=len DIV 2 -64 + rand.Dice(128);
	fovea:=GetFovea2(raster, x, y, 1, 7); (* compressed averaging sampling*)
	recon:=ReconstructFovea2(fovea, 1, 7);
	IF name#oldName THEN 
		NEW(im, raster, "raster"); im.AddWindow;
		NEW(fo, fovea, "fovea"); fo.AddWindow;
	END;
	NEW(re, recon, "recon"); re.AddWindow;
	COPY(name, oldName);
END Test2;

PROCEDURE TestA2*(context:Commands.Context); (*n layers, split blocks in periphery. use Mean() of each block for encoding*)
VAR 
	raster3 : ARRAY [*,*,*] OF SIGNED16;
	raster, recon, fovea: Tensor;
	img: WMGraphics.Image;
	blockSize, nShells:SIGNED32; len, x,y, size, i:SIZE;
	name: Files.FileName;
BEGIN
	IF ~context.arg.GetString(name) THEN COPY("Yellow_Duck.jpg",name) END;
	IF ~context.arg.GetInteger(blockSize,FALSE) OR ~context.arg.GetInteger(nShells, FALSE) THEN blockSize:=1; nShells:=7 END;
	img:=WMGraphics.LoadImage(name, FALSE);
	MatrixRaster.ImageToArray(img, raster3);
	raster:=raster3[*,*,*];
	len:=LEN(raster,1); 
	size := 2 * blockSize;
	FOR i:=0 TO nShells-1 DO size:=size * 2 END;
	x:=size DIV 2 + rand.Dice(SIGNED32(LEN(raster,2)-size));
	y:=size DIV 2 + rand.Dice(SIGNED32(LEN(raster,1)-size));
	fovea:=GetFoveaA2(raster, x, y, blockSize, nShells, Mean); (* compressed averaging sampling*)
	recon:=ReconstructFoveaA2(fovea, blockSize, nShells);
	IF name#oldName THEN 
		WMArrayPanel.AddWindow(raster,"raster");
	END;
	WMArrayPanel.AddWindow(fovea, "fovea");
	WMArrayPanel.AddWindow(recon, "recon");
	COPY(name, oldName);
END TestA2;

PROCEDURE TestSampledA2*(context:Commands.Context); (*n layers, split blocks in periphery; sample each block at position [random,random]*)
VAR 
	raster3 : ARRAY [*,*,*] OF SIGNED16;
	raster, recon, fovea: Tensor;
	img: WMGraphics.Image;
	len, x, y:SIZE;
	blockSize, nShells:SIGNED32;
	name: Files.FileName;
BEGIN
	IF ~context.arg.GetString(name) THEN COPY("Yellow_Duck.jpg",name) END;
	IF ~context.arg.GetInteger(blockSize,FALSE) OR ~context.arg.GetInteger(nShells, FALSE) THEN blockSize:=1; nShells:=7 END;
	img:=WMGraphics.LoadImage(name, FALSE);
	MatrixRaster.ImageToArray(img, raster3);
	raster:=raster3[*,*,*];
	len:=LEN(raster,1); 
	x:=LEN(raster,2) DIV 2 -64 + rand.Dice(128);
	y:=LEN(raster,1) DIV 2 -64 + rand.Dice(128);
	fovea:=GetFoveaA2(raster, x, y, blockSize, nShells, Sample); (* compressed averaging sampling*)
	recon:=ReconstructFoveaA2(fovea, blockSize, nShells);
	IF name#oldName THEN 
		WMArrayPanel.AddWindow(raster,"raster");
		WMArrayPanel.AddWindow(fovea, "fovea");
	END;
	WMArrayPanel.AddWindow(recon, "recon");
	COPY(name, oldName);
END TestSampledA2;

PROCEDURE TestGridpointsA2*(context:Commands.Context); (*n layers, split blocks in periphery. Sample at pos[0,0] of each block*)
VAR 
	raster3 : ARRAY [*,*,*] OF SIGNED16;
	raster, recon, fovea: Tensor;
	img: WMGraphics.Image;
	len, x, y:SIZE; blockSize, nShells:SIGNED32;
	name: Files.FileName;
BEGIN
	IF ~context.arg.GetString(name) THEN COPY("Yellow_Duck.jpg",name) END;
	IF ~context.arg.GetInteger(blockSize,FALSE) OR ~context.arg.GetInteger(nShells, FALSE) THEN blockSize:=1; nShells:=7 END;
	img:=WMGraphics.LoadImage(name, FALSE);
	MatrixRaster.ImageToArray(img, raster3);
	raster:=raster3[*,*,*];
	len:=LEN(raster,1); 
	x:=LEN(raster,2) DIV 2 -64 + rand.Dice(128);
	y:=LEN(raster,1) DIV 2 -64 + rand.Dice(128);
	fovea:=GetFoveaA2(raster, x, y, blockSize, nShells, Gridpoints); (* sampling at block positions [0,0]*)
	recon:=ReconstructFoveaA2(fovea, blockSize, nShells);
	IF name#oldName THEN 
		WMArrayPanel.AddWindow(raster,"raster");
		WMArrayPanel.AddWindow(fovea, "fovea");
	END;
	WMArrayPanel.AddWindow(recon, "recon");
	COPY(name, oldName);
END TestGridpointsA2;


PROCEDURE TestSampled2*(context:Commands.Context);
VAR 
	raster3 : ARRAY [*,*,*] OF SIGNED16;
	raster, recon, fovea: Matrix;
	im,fo, re: WMMatrix.Window;
	img: WMGraphics.Image;
	len, x, y:SIZE;
	name: Files.FileName;
BEGIN
	IF ~context.arg.GetString(name) THEN COPY("Yellow_Duck.jpg",name) END;
	img:=WMGraphics.LoadImage(name, FALSE);
	MatrixRaster.ImageToArray(img, raster3);
	raster:=raster3[1,*,*];
	len:=LEN(raster,0); 
	x:=len DIV 2 -64 + rand.Dice(128);
	y:=len DIV 2 -64 + rand.Dice(128);
	fovea:=GetFoveaSampled2(raster, x, y, 2, 6); (*compressed random sampling*)
	recon:=ReconstructFoveaA2(fovea, 2, 6);
	IF name#oldName THEN 
		NEW(im, raster, "raster"); im.AddWindow;
		NEW(fo, fovea, "fovea"); fo.AddWindow;
	END;
	NEW(re, recon, "recon"); re.AddWindow;
	COPY(name, oldName);
END TestSampled2;

PROCEDURE Test3*(context:Commands.Context);
VAR 
	raster3 : ARRAY [*,*,*] OF SIGNED16;
	raster, recon, fovea: Matrix;
	im,fo, re: WMMatrix.Window;
	img: WMGraphics.Image;
	blockSize, domainSize, shells:SIGNED32;
	len, i, x, y:SIZE;
	name: Files.FileName;
	mode: ARRAY 32 OF CHAR;
BEGIN
	IF ~context.arg.GetString(name) THEN COPY("Yellow_Duck.jpg",name) END;
	IF ~context.arg.GetInteger(blockSize, FALSE) THEN blockSize:=1 END;
	IF ~context.arg.GetInteger(shells, FALSE) THEN shells:=6 END;
	IF ~context.arg.GetString(mode) THEN mode:="" END;
	img:=WMGraphics.LoadImage(name, FALSE);
	MatrixRaster.ImageToArray(img, raster3);
	raster:=raster3[1,*,*];
	len:=LEN(raster,0); 
	domainSize:=2*blockSize; 
	FOR i:=0 TO shells-1 DO domainSize:=domainSize*2 END;
	ASSERT(domainSize <= LEN(raster),200);
	
	x:=domainSize DIV 2 + rand.Dice(SIGNED32(LEN(raster,1)-domainSize)); 
	y:=domainSize DIV 2 + rand.Dice(SIGNED32(LEN(raster,0)-domainSize));
	
	IF mode="" THEN fovea:=GetFovea2(raster, x, y, blockSize, shells); (* compressed averaging sampling*)
	ELSE fovea:=GetFoveaSampled2(raster, x, y, blockSize, shells); 
	END;
	recon:=ReconstructFovea2(fovea, blockSize, shells);
	IF name#oldName THEN 
		NEW(im, raster, "raster"); im.AddWindow;
		NEW(fo, fovea, "fovea"); fo.AddWindow;
	END;
	NEW(re, recon, "recon"); re.AddWindow;
	COPY(name, oldName);
END Test3;

BEGIN
	NEW(rand)
END TensorFovea.

TensorFovea.Test ~
TensorFovea.Test0 ~
TensorFovea.TestA ~
TensorFovea.Test1 ~
TensorFovea.Test1 SimpleEye.jpg ~
TensorFovea.Test2 SimpleEye.jpg ~
TensorFovea.Test2 Yellow_Duck.jpg~
TensorFovea.TestA2 Yellow_Duck.jpg 1 8~
TensorFovea.Test2 "C:/Program Files (x86)/A2/HighDim/Code/EyeTracker/EyeDB_Internet/aergaf.jpg"~
TensorFovea.TestSampled2 "C:/Program Files (x86)/A2/HighDim/Code/EyeTracker/EyeDB_Internet/aergaf.jpg"~
TensorFovea.TestA2 "C:/Program Files (x86)/A2/HighDim/Code/EyeTracker/EyeDB_Internet/aergaf.jpg"~
TensorFovea.TestSampledA2 "C:/Program Files (x86)/A2/HighDim/Code/EyeTracker/EyeDB_Internet/aergaf.jpg"~
TensorFovea.TestGridpointsA2 "C:/Program Files (x86)/A2/HighDim/Code/EyeTracker/EyeDB_Internet/aergaf.jpg"~
TensorFovea.Test3 "C:/Program Files (x86)/A2/HighDim/Code/EyeTracker/EyeDB_Internet/aergaf.jpg" 4 5 ~
TensorFovea.Test3 "C:/Program Files (x86)/A2/HighDim/Code/EyeTracker/EyeDB_Internet/aergaf.jpg" 4 5 sampled ~
TensorFovea.TestA2 SaasFee.jpg 3 7~
TensorFovea.TestA2 "C:/Program Files (x86)/A2/HighDim/Code/EyeTracker/EyeDB_Internet/8476656067_ee498cc265_b.jpg" 2 7 ~
TensorFovea.Test3 "C:/Program Files (x86)/A2/HighDim/Code/EyeTracker/EyeDB_Internet/8476656067_ee498cc265_b.jpg" ~

System.FreeDownTo WMMatrix ~ goetzenich
