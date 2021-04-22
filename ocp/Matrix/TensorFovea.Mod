MODULE TensorFovea; (** AUTHOR "Patrick Hunziker"; PURPOSE "Foveal data patterns with central high res and peripheral blur"; *)

(* 
currently foveal image structure is a small 2*2 core of inner blocks (each block has "block size" >=1 pixels ), 
surrounded by multiple concentric shells of 12 blocks of same size as inner block => doubling side length at each shell.
this i stored in a [nLayers, nShells, 12] or [nLayers, 2*nShells, 12], or [nShells, 12] or [2*nShells, 12] format.
in this format, 
shift up/down of the data is equivalent to scaling about the center,
move left/right of the data is equivalent to approximate rotation around the center.
*)

IMPORT Random, Files, Commands, WMMatrix, WMGraphics, MatrixRaster, WMArrayPanel, Stat:=StatisticsBase, Streams;

CONST (*structure*)
	SingleShell*=1;
	DoubleShell*=2;
	
	(*mode*)
	ModeMean*=0;
	ModeSample*=1;
	ModeGridpoint*=2;

TYPE Datatype* = FLOAT64;
TYPE Array* = ARRAY [?] OF Datatype;
	Tensor*=Array;
	Vector* = ARRAY [*] OF Datatype;
	Matrix* = ARRAY [*,*] OF Datatype;
	SizeVector*=ARRAY [*] OF SIZE;
	Image* = Array ; (** foveal images have high central resolution and peripheral blur. They are stored as with size 12 in the last dimension due to special structure *)
	ArrayFunction*= PROCEDURE{DELEGATE}(CONST m:Array): Datatype;

TYPE Transformer*=OBJECT
	VAR mode*: SIGNED32;
		innerBlockSize*, shells*: SIGNED32;
		blockSize: SizeVector;
		img: Tensor; 
		
	PROCEDURE &Init*((*roiWidth, roiHeight: SIGNED32*)innerBlockSize:=1,shells:=5:SIGNED32);(*shells can be split to 2 or more concentric sub-shells -> changes the resulting fovea size*)
	BEGIN
		SELF.innerBlockSize:=innerBlockSize; SELF.shells:=shells;
		blockSize:=GetBlockSize(innerBlockSize,shells);
	END Init;

	(*extract foveal representation from matrix at given location; block aspect ratio is =1, i.e. thicker shells*)
	PROCEDURE GetFovea*(CONST m:Matrix; centerX,centerY: SIZE; sample:=Mean: ArrayFunction): Matrix; (* *)
	VAR i, x,y, len, slen:SIZE;
	BEGIN
		IF ~HasSize(img, [shells+1, 12]) THEN NEW(img, shells+1, 12) END; (* subblocks *)
		(*NEW(img, shells+1, 12);*) (* blocks*)
		len:=innerBlockSize; (*inner block has four quadrants, each of them has size= len*len, ...*)
		slen:=len DIV 2;
		x:=centerX;
		y:=centerY;
		img[0, 0..2]:=sample(m[y..y+len-1, x-len..x-1]); (* rotating from 9 o clock, clockwise*)
		img[0, 3..5]:=sample(m[y..y+len-1, x..x+len-1]); 
		img[0, 6..8]:=sample(m[y-len..y-1, x..x+len-1]); 
		img[0, 9..11]:=sample(m[y-len..y-1, x-len..x-1]); (* core *)(*to do: blocks instead of fixed pixel size*)
		FOR i:=0 TO shells-1 DO
			img[i+1, 0] := sample(m[y+0*len..y+1*len-1, x-2*len..x-1*len-1]); (* performance: could substitute sample() by simple sampling *)
			img[i+1, 1] := sample(m[y+1*len..y+2*len-1, x-2*len..x-1*len-1]);
			img[i+1, 2] := sample(m[y+1*len..y+2*len-1, x-1*len..x+0*len-1]);
			img[i+1, 3] := sample(m[y+1*len..y+2*len-1, x+0*len..x+1*len-1]);
			img[i+1, 4] := sample(m[y+1*len..y+2*len-1, x+1*len..x+2*len-1]);
			img[i+1, 5] := sample(m[y+0*len..y+1*len-1, x+1*len..x+2*len-1]);
			img[i+1, 6] := sample(m[y-1*len..y+0*len-1, x+1*len..x+2*len-1]);
			img[i+1, 7] := sample(m[y-2*len..y-1*len-1, x+1*len..x+2*len-1]);
			img[i+1, 8] := sample(m[y-2*len..y-1*len-1, x+0*len..x+1*len-1]);
			img[i+1, 9] := sample(m[y-2*len..y-1*len-1, x-1*len..x+0*len-1]);
			img[i+1,10] := sample(m[y-2*len..y-1*len-1, x-2*len..x-1*len-1]);
			img[i+1,11] := sample(m[y-1*len..y+0*len-1, x-2*len..x-1*len-1]);

			len:=len*2;
			slen:=len DIV 2
		END;
		RETURN img
	END GetFovea;

	(*extract foveal representation from matrix at given location; block aspect ratio is =2, i.r. thinner shells *)
	PROCEDURE GetFovea2*(CONST m:Matrix; centerX,centerY:SIZE; sample:=Mean: ArrayFunction): Matrix; (* *)
	VAR i, x,y, len, slen:SIZE;
	BEGIN
		(*ASSERT(DIM(m)=2, 202);*) (*implementation limitation*)		
		IF ~HasSize(img, [2*shells+1, 12]) THEN NEW(img, 2*shells+1, 12) END; (* subblocks *)
		(*NEW(img, 2*shells+1, 12);*) (* subblocks *)
		len:=innerBlockSize;
		slen:=len DIV 2;
		x:=centerX;
		y:=centerY;
		img[0, 0..2]:=sample(m[y..y+len-1, x-len..x-1]); (* rotating from 9 o clock, clockwise*)
		img[0, 3..5]:=sample(m[y..y+len-1, x..x+len-1]); 
		img[0, 6..8]:=sample(m[y-len..y-1, x..x+len-1]); 
		img[0, 9..11]:=sample(m[y-len..y-1, x-len..x-1]); (* core *)(*to do: blocks instead of fixed pixel size*)
		FOR i:=0 TO shells-1 DO
			
			img[2*i+1, 0] := sample(m[y+0*len..		y+1*len-1, 					x-2*len+slen..	x-1*len-1]); (* performance: could substitute sample() by simple sampling *)
			img[2*i+1, 1] := sample(m[y+1*len..		y+2*len-1, 					x-2*len+slen..	x-1*len-1]);
			img[2*i+1, 2] := sample(m[y+1*len..		y+1*len+MAX(1,slen)-1, x-1*len..			x+0*len-1]);
			img[2*i+1, 3] := sample(m[y+1*len..		y+1*len+MAX(1,slen)-1, x+0*len..			x+1*len-1]);
			img[2*i+1, 4] := sample(m[y+1*len..		y+1*len+MAX(1,slen)-1, x+1*len..			x+2*len-1]);
			img[2*i+1, 5] := sample(m[y+0*len..		y+1*len-1, 					x+1*len..			x+1*len+MAX(1,slen)-1]);
			img[2*i+1, 6] := sample(m[y-1*len..		y+0*len-1, 					x+1*len..			x+1*len+MAX(1,slen)-1]);
			img[2*i+1, 7] := sample(m[y-2*len..		y-1*len-1, 					x+1*len..			x+1*len+MAX(1,slen)-1]);
			img[2*i+1, 8] := sample(m[y-2*len+slen..y-1*len-1, 					x+0*len..			x+1*len-1]);
			img[2*i+1, 9] := sample(m[y-2*len+slen..y-1*len-1, 					x-1*len..			x+0*len-1]);
			img[2*i+1,10] := sample(m[y-2*len+slen..y-1*len-1, 					x-2*len..			x-1*len-1]); (*! there is some indexing problem here ...*)
			img[2*i+1,11] := sample(m[y-1*len..		y+0*len-1, 					x-2*len+slen..	x-1*len-1]);

			img[2*i+2, 0] := sample(m[y+0*len..		y+1*len-1, 					x-2*len..			x-2*len+MAX(1,slen)-1]); 
			img[2*i+2, 1] := sample(m[y+1*len..		y+2*len-1, 					x-2*len..			x-2*len+MAX(1,slen)-1]);
			img[2*i+2, 2] := sample(m[y+1*len+slen..y+2*len-1, 					x-1*len..			x+0*len-1]);
			img[2*i+2, 3] := sample(m[y+1*len+slen..y+2*len-1, 					x+0*len..			x+1*len-1]);
			img[2*i+2, 4] := sample(m[y+1*len+slen..y+2*len-1, 					x+1*len..			x+2*len-1]);
			img[2*i+2, 5] := sample(m[y+0*len..		y+1*len-1, 					x+1*len+slen..	x+2*len-1]);
			img[2*i+2, 6] := sample(m[y-1*len..		y+0*len-1, 					x+1*len+slen..	x+2*len-1]);
			img[2*i+2, 7] := sample(m[y-2*len..		y-1*len-1, 					x+1*len+slen..	x+2*len-1]);
			img[2*i+2, 8] := sample(m[y-2*len..		y-2*len+MAX(1,slen)-1, x+0*len..			x+1*len-1]);
			img[2*i+2, 9] := sample(m[y-2*len..		y-2*len+MAX(1,slen)-1, x-1*len..			x+0*len-1]);
			img[2*i+2,10] := sample(m[y-2*len..		y-2*len+MAX(1,slen)-1, x-2*len..			x-1*len-1]);
			img[2*i+2,11] := sample(m[y-1*len..		y+0*len-1, 					x-2*len..			x-2*len+MAX(1,slen)-1]);

			len:=len*2;
			slen:=len DIV 2
		END;
		RETURN img
	END GetFovea2;

	(*extract multilayer foveal representation from tensor at given location; block aspect ratio is =2, i.r. thinner shells *)
	PROCEDURE GetFoveaStack2*(CONST m:Tensor; centerX,centerY: SIZE; sample:=Mean: ArrayFunction): Tensor; (*! tbd: which index position is layer index ? *)
	VAR i, x,y, len, slen, layer:SIZE;
	BEGIN
		ASSERT(DIM(m)=3, 202); (*implementation limitation*)
		IF ~HasSize(img, [LEN(m,0), 2*shells+1, 12]) THEN NEW(img, LEN(m,0), 2*shells+1, 12) END; (* subblocks *)
		x:=centerX;
		y:=centerY;
		FOR layer:=0 TO LEN(m,0)-1 DO
			len:=innerBlockSize;
			slen:=len DIV 2;		
			img[layer, 0, 0..2]:=sample(m[layer, y..y+len-1, x-len..x-1]); (* rotating from 9 o clock, clockwise*)
			img[layer, 0, 3..5]:=sample(m[layer, y..y+len-1, x..x+len-1]); 
			img[layer, 0, 6..8]:=sample(m[layer, y-len..y-1, x..x+len-1]); 
			img[layer, 0, 9..11]:=sample(m[layer, y-len..y-1, x-len..x-1]); (* core *)(*to do: blocks instead of fixed pixel size*)
			FOR i:=0 TO shells-1 DO	
				img[layer, 2*i+1, 0] := sample(m[layer, y+0*len..y+1*len-1, x-2*len+slen..x-1*len-1]); (* performance: could substitute sample() by simple sampling *)
				img[layer, 2*i+1, 1] := sample(m[layer, y+1*len..y+2*len-1, x-2*len+slen..x-1*len-1]);
				img[layer, 2*i+1, 2] := sample(m[layer, y+1*len..y+1*len+MAX(1,slen)-1, x-1*len..x+0*len-1]);
				img[layer, 2*i+1, 3] := sample(m[layer, y+1*len..y+1*len+MAX(1,slen)-1, x+0*len..x+1*len-1]);
				img[layer, 2*i+1, 4] := sample(m[layer, y+1*len..y+1*len+MAX(1,slen)-1, x+1*len..x+2*len-1]);
				img[layer, 2*i+1, 5] := sample(m[layer, y+0*len..y+1*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
				img[layer, 2*i+1, 6] := sample(m[layer, y-1*len..y+0*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
				img[layer, 2*i+1, 7] := sample(m[layer, y-2*len..y-1*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
				img[layer, 2*i+1, 8] := sample(m[layer, y-2*len+slen..y-1*len-1, x+0*len..x+1*len-1]);
				img[layer, 2*i+1, 9] := sample(m[layer, y-2*len+slen..y-1*len-1, x-1*len..x+0*len-1]);
				img[layer, 2*i+1,10] := sample(m[layer, y-2*len+slen..y-1*len-1, x-2*len..x-1*len-1]); (*! there is some indexing problem here ...*)
				img[layer, 2*i+1,11] := sample(m[layer, y-1*len..y+0*len-1, x-2*len+slen..x-1*len-1]);
	 
				img[layer, 2*i+2, 0] := sample(m[layer, y+0*len..y+1*len-1, x-2*len..x-2*len+MAX(1,slen)-1]); 
				img[layer, 2*i+2, 1] := sample(m[layer, y+1*len..y+2*len-1, x-2*len..x-2*len+MAX(1,slen)-1]);
				img[layer, 2*i+2, 2] := sample(m[layer, y+1*len+slen..y+2*len-1, x-1*len..x+0*len-1]);
				img[layer, 2*i+2, 3] := sample(m[layer, y+1*len+slen..y+2*len-1, x+0*len..x+1*len-1]);
				img[layer, 2*i+2, 4] := sample(m[layer, y+1*len+slen..y+2*len-1, x+1*len..x+2*len-1]);
				img[layer, 2*i+2, 5] := sample(m[layer, y+0*len..y+1*len-1, x+1*len+slen..x+2*len-1]);
				img[layer, 2*i+2, 6] := sample(m[layer, y-1*len..y+0*len-1, x+1*len+slen..x+2*len-1]);
				img[layer, 2*i+2, 7] := sample(m[layer, y-2*len..y-1*len-1, x+1*len+slen..x+2*len-1]);
				img[layer, 2*i+2, 8] := sample(m[layer, y-2*len..y-2*len+MAX(1,slen)-1, x+0*len..x+1*len-1]);
				img[layer, 2*i+2, 9] := sample(m[layer, y-2*len..y-2*len+MAX(1,slen)-1, x-1*len..x+0*len-1]);
				img[layer, 2*i+2,10] := sample(m[layer, y-2*len..y-2*len+MAX(1,slen)-1, x-2*len..x-1*len-1]);
				img[layer, 2*i+2,11] := sample(m[layer, y-1*len..y+0*len-1, x-2*len..x-2*len+MAX(1,slen)-1]);
				len:=len*2;
				slen:=len DIV 2
			END
		END;
		RETURN img
	END GetFoveaStack2;

	(*extract multilayer foveal representation from tensor at given location; block aspect ratio is =2, i.r. thinner shells *)
	(*here, the random sample location is different for each layer*)
	PROCEDURE GetFoveaSampledStack2*(CONST m:Tensor; centerX,centerY: SIZE; sample:=Sample: ArrayFunction): Tensor; (*! tbd: which index position is layer index ? *)
	VAR i, x,y, len, slen, layer:SIZE;
	BEGIN
		ASSERT(DIM(m)=3, 202); (*implementation limitation*)
		IF ~HasSize(img, [LEN(m,0), 2*shells+1, 12]) THEN NEW(img, LEN(m,0), 2*shells+1, 12) END; (* subblocks *)
		x:=centerX;
		y:=centerY;
		FOR layer:=0 TO LEN(m,0)-1 DO
			len:=innerBlockSize;
			slen:=len DIV 2;		
			img[layer, 0, 0..2]:=sample(m[layer, y..y+len-1, x-len..x-1]); (* rotating from 9 o clock, clockwise*)
			img[layer, 0, 3..5]:=sample(m[layer, y..y+len-1, x..x+len-1]); 
			img[layer, 0, 6..8]:=sample(m[layer, y-len..y-1, x..x+len-1]); 
			img[layer, 0, 9..11]:=sample(m[layer, y-len..y-1, x-len..x-1]); (* core *)(*to do: blocks instead of fixed pixel size*)
			FOR i:=0 TO shells-1 DO	
				img[layer, 2*i+1, 0] := sample(m[layer, y+0*len..y+1*len-1, x-2*len+slen..x-1*len-1]);  
				img[layer, 2*i+1, 1] := sample(m[layer, y+1*len..y+2*len-1, x-2*len+slen..x-1*len-1]);
				img[layer, 2*i+1, 2] := sample(m[layer, y+1*len..y+1*len+MAX(1,slen)-1, x-1*len..x+0*len-1]);
				img[layer, 2*i+1, 3] := sample(m[layer, y+1*len..y+1*len+MAX(1,slen)-1, x+0*len..x+1*len-1]);
				img[layer, 2*i+1, 4] := sample(m[layer, y+1*len..y+1*len+MAX(1,slen)-1, x+1*len..x+2*len-1]);
				img[layer, 2*i+1, 5] := sample(m[layer, y+0*len..y+1*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
				img[layer, 2*i+1, 6] := sample(m[layer, y-1*len..y+0*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
				img[layer, 2*i+1, 7] := sample(m[layer, y-2*len..y-1*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
				img[layer, 2*i+1, 8] := sample(m[layer, y-2*len+slen..y-1*len-1, x+0*len..x+1*len-1]);
				img[layer, 2*i+1, 9] := sample(m[layer, y-2*len+slen..y-1*len-1, x-1*len..x+0*len-1]);
				img[layer, 2*i+1,10] := sample(m[layer, y-2*len+slen..y-1*len-1, x-2*len..x-1*len-1]); (*! there is some indexing problem here ...*)
				img[layer, 2*i+1,11] := sample(m[layer, y-1*len..y+0*len-1, x-2*len+slen..x-1*len-1]);
	 
				img[layer, 2*i+2, 0] := sample(m[layer, y+0*len..y+1*len-1, x-2*len..x-2*len+MAX(1,slen)-1]); 
				img[layer, 2*i+2, 1] := sample(m[layer, y+1*len..y+2*len-1, x-2*len..x-2*len+MAX(1,slen)-1]);
				img[layer, 2*i+2, 2] := sample(m[layer, y+1*len+slen..y+2*len-1, x-1*len..x+0*len-1]);
				img[layer, 2*i+2, 3] := sample(m[layer, y+1*len+slen..y+2*len-1, x+0*len..x+1*len-1]);
				img[layer, 2*i+2, 4] := sample(m[layer, y+1*len+slen..y+2*len-1, x+1*len..x+2*len-1]);
				img[layer, 2*i+2, 5] := sample(m[layer, y+0*len..y+1*len-1, x+1*len+slen..x+2*len-1]);
				img[layer, 2*i+2, 6] := sample(m[layer, y-1*len..y+0*len-1, x+1*len+slen..x+2*len-1]);
				img[layer, 2*i+2, 7] := sample(m[layer, y-2*len..y-1*len-1, x+1*len+slen..x+2*len-1]);
				img[layer, 2*i+2, 8] := sample(m[layer, y-2*len..y-2*len+MAX(1,slen)-1, x+0*len..x+1*len-1]);
				img[layer, 2*i+2, 9] := sample(m[layer, y-2*len..y-2*len+MAX(1,slen)-1, x-1*len..x+0*len-1]);
				img[layer, 2*i+2,10] := sample(m[layer, y-2*len..y-2*len+MAX(1,slen)-1, x-2*len..x-1*len-1]);
				img[layer, 2*i+2,11] := sample(m[layer, y-1*len..y+0*len-1, x-2*len..x-2*len+MAX(1,slen)-1]);
				len:=len*2;
				slen:=len DIV 2
			END
		END;
		RETURN img
	END GetFoveaSampledStack2;

	(*extract multilayer foveal representation from tensor at given location; block aspect ratio is =2, i.r. thinner shells *)
	(*here, the random sample location is same for each layer, in contrast to GetFoveaSampledStack2() *)
	PROCEDURE GetFoveaFixSampledStack2*(CONST m:Tensor; centerX,centerY: SIZE): Tensor; (*! tbd: which index position is layer index ? *)
	VAR i, x,y, len, slen, layer:SIZE;
	BEGIN
		ASSERT(DIM(m)=3, 202); (*implementation limitation*)
		IF ~HasSize(img, [LEN(m,0), 2*shells+1, 12]) THEN NEW(img, LEN(m,0), 2*shells+1, 12) END; (* subblocks *)
		x:=centerX;
		y:=centerY;
		(*FOR layer:=0 TO LEN(m,0)-1 DO*)
			len:=innerBlockSize;
			slen:=len DIV 2;		
			img[..(*layer*), 0, 0]:=SampleStack(m[..(*layer*), y..y+len-1, x-len..x-1]); (* rotating from 9 o clock, clockwise*)(*? tbd: core might also be sampled*)
			img[..(*layer*), 0, 1]:=img[..(*layer*), 0, 0];
			img[..(*layer*), 0, 2]:=img[..(*layer*), 0, 0];
			img[..(*layer*), 0, 3]:=SampleStack(m[..(*layer*), y..y+len-1, x..x+len-1]); 
			img[..(*layer*), 0, 4]:= img[..(*layer*), 0, 3];
			img[..(*layer*), 0, 5]:= img[..(*layer*), 0, 3];
			img[..(*layer*), 0, 6]:=SampleStack(m[..(*layer*), y-len..y-1, x..x+len-1]); 
			img[..(*layer*), 0, 7]:=img[..(*layer*), 0, 6];
			img[..(*layer*), 0, 8]:=img[..(*layer*), 0, 6]; 
			img[..(*layer*), 0, 9]:=SampleStack(m[..(*layer*), y-len..y-1, x-len..x-1]); (* core *)(*to do: blocks instead of fixed pixel size*)
			img[..(*layer*), 0, 10]:=img[..(*layer*), 0, 9];
			img[..(*layer*), 0, 11]:=img[..(*layer*), 0, 9];	(*END;*)
		len:=innerBlockSize;
		slen:=len DIV 2;		
		FOR i:=0 TO shells-1 DO	
			img[.., 2*i+1, 0] := SampleStack(m[.., y+0*len..y+1*len-1, x-2*len+slen..x-1*len-1]);  
			img[.., 2*i+1, 1] := SampleStack(m[.., y+1*len..y+2*len-1, x-2*len+slen..x-1*len-1]);
			img[.., 2*i+1, 2] := SampleStack(m[.., y+1*len..y+1*len+MAX(1,slen)-1, x-1*len..x+0*len-1]);
			img[.., 2*i+1, 3] := SampleStack(m[.., y+1*len..y+1*len+MAX(1,slen)-1, x+0*len..x+1*len-1]);
			img[.., 2*i+1, 4] := SampleStack(m[.., y+1*len..y+1*len+MAX(1,slen)-1, x+1*len..x+2*len-1]);
			img[.., 2*i+1, 5] := SampleStack(m[.., y+0*len..y+1*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
			img[.., 2*i+1, 6] := SampleStack(m[.., y-1*len..y+0*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
			img[.., 2*i+1, 7] := SampleStack(m[.., y-2*len..y-1*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
			img[.., 2*i+1, 8] := SampleStack(m[.., y-2*len+slen..y-1*len-1, x+0*len..x+1*len-1]);
			img[.., 2*i+1, 9] := SampleStack(m[.., y-2*len+slen..y-1*len-1, x-1*len..x+0*len-1]);
			img[.., 2*i+1,10] := SampleStack(m[.., y-2*len+slen..y-1*len-1, x-2*len..x-1*len-1]); (*! there is some indexing problem here ...*)
			img[.., 2*i+1,11] := SampleStack(m[.., y-1*len..y+0*len-1, x-2*len+slen..x-1*len-1]);
 
			img[.., 2*i+2, 0] := SampleStack(m[.., y+0*len..y+1*len-1, x-2*len..x-2*len+MAX(1,slen)-1]); 
			img[.., 2*i+2, 1] := SampleStack(m[.., y+1*len..y+2*len-1, x-2*len..x-2*len+MAX(1,slen)-1]);
			img[.., 2*i+2, 2] := SampleStack(m[.., y+1*len+slen..y+2*len-1, x-1*len..x+0*len-1]);
			img[.., 2*i+2, 3] := SampleStack(m[.., y+1*len+slen..y+2*len-1, x+0*len..x+1*len-1]);
			img[.., 2*i+2, 4] := SampleStack(m[.., y+1*len+slen..y+2*len-1, x+1*len..x+2*len-1]);
			img[.., 2*i+2, 5] := SampleStack(m[.., y+0*len..y+1*len-1, x+1*len+slen..x+2*len-1]);
			img[.., 2*i+2, 6] := SampleStack(m[.., y-1*len..y+0*len-1, x+1*len+slen..x+2*len-1]);
			img[.., 2*i+2, 7] := SampleStack(m[.., y-2*len..y-1*len-1, x+1*len+slen..x+2*len-1]);
			img[.., 2*i+2, 8] := SampleStack(m[.., y-2*len..y-2*len+MAX(1,slen)-1, x+0*len..x+1*len-1]);
			img[.., 2*i+2, 9] := SampleStack(m[.., y-2*len..y-2*len+MAX(1,slen)-1, x-1*len..x+0*len-1]);
			img[.., 2*i+2,10] := SampleStack(m[.., y-2*len..y-2*len+MAX(1,slen)-1, x-2*len..x-1*len-1]);
			img[.., 2*i+2,11] := SampleStack(m[.., y-1*len..y+0*len-1, x-2*len..x-2*len+MAX(1,slen)-1]);
			len:=len*2;
			slen:=len DIV 2
		END;
		RETURN img
	END GetFoveaFixSampledStack2;

	(*extract foveal representation from matrix at given location; block aspect ratio is =2, i.r. thinner shells *)
	PROCEDURE GetFoveaSampled2*(CONST m:Matrix; centerX,centerY: SIZE; sample:=Sample: ArrayFunction): Matrix; (* *)
	VAR  i, x,y, len, slen:SIZE;
	BEGIN
		IF ~HasSize(img, [2*shells+1, 12]) THEN NEW(img, 2*shells+1, 12) END; (* subblocks *)
		(*NEW(img, 2*shells+1, 12);*) (* subblocks *)
		len:=innerBlockSize;
		slen:=len DIV 2;
		x:=centerX;
		y:=centerY;
		img[0, 0..2]:=sample(m[y..y+len-1, x-len..x-1]); (* rotating from 9 o clock, clockwise*)
		img[0, 3..5]:=sample(m[y..y+len-1, x..x+len-1]); 
		img[0, 6..8]:=sample(m[y-len..y-1, x..x+len-1]); 
		img[0, 9..11]:=sample(m[y-len..y-1, x-len..x-1]); (* core *)(*to do: blocks instead of fixed pixel size*)
		FOR i:=0 TO shells-1 DO
			
			img[2*i+1, 0] := sample(m[y+0*len..y+1*len-1, x-2*len+slen..x-1*len-1]); 
			img[2*i+1, 1] := sample(m[y+1*len..y+2*len-1, x-2*len+slen..x-1*len-1]);
			img[2*i+1, 2] := sample(m[y+1*len..y+1*len+MAX(1,slen)-1, x-1*len..x+0*len-1]);
			img[2*i+1, 3] := sample(m[y+1*len..y+1*len+MAX(1,slen)-1, x+0*len..x+1*len-1]);
			img[2*i+1, 4] := sample(m[y+1*len..y+1*len+MAX(1,slen)-1, x+1*len..x+2*len-1]);
			img[2*i+1, 5] := sample(m[y+0*len..y+1*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
			img[2*i+1, 6] := sample(m[y-1*len..y+0*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
			img[2*i+1, 7] := sample(m[y-2*len..y-1*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
			img[2*i+1, 8] := sample(m[y-2*len+slen..y-1*len-1, x+0*len..x+1*len-1]);
			img[2*i+1, 9] := sample(m[y-2*len+slen..y-1*len-1, x-1*len..x+0*len-1]);
			img[2*i+1,10] := sample(m[y-2*len+slen..y-1*len-1, x-2*len..x-1*len-1]);
			img[2*i+1,11] := sample(m[y-1*len..y+0*len-1, x-2*len+slen..x-1*len-1]);

			img[2*i+2, 0] := sample(m[y+0*len..y+1*len-1, x-2*len..x-2*len+MAX(1,slen)-1]); 
			img[2*i+2, 1] := sample(m[y+1*len..y+2*len-1, x-2*len..x-2*len+MAX(1,slen)-1]);
			img[2*i+2, 2] := sample(m[y+1*len+slen..y+2*len-1, x-1*len..x+0*len-1]);
			img[2*i+2, 3] := sample(m[y+1*len+slen..y+2*len-1, x+0*len..x+1*len-1]);
			img[2*i+2, 4] := sample(m[y+1*len+slen..y+2*len-1, x+1*len..x+2*len-1]);
			img[2*i+2, 5] := sample(m[y+0*len..y+1*len-1, x+1*len+slen..x+2*len-1]);
			img[2*i+2, 6] := sample(m[y-1*len..y+0*len-1, x+1*len+slen..x+2*len-1]);
			img[2*i+2, 7] := sample(m[y-2*len..y-1*len-1, x+1*len+slen..x+2*len-1]);
			img[2*i+2, 8] := sample(m[y-2*len..y-2*len+MAX(1,slen)-1, x+0*len..x+1*len-1]);
			img[2*i+2, 9] := sample(m[y-2*len..y-2*len+MAX(1,slen)-1, x-1*len..x+0*len-1]);
			img[2*i+2,10] := sample(m[y-2*len..y-2*len+MAX(1,slen)-1, x-2*len..x-1*len-1]);
			img[2*i+2,11] := sample(m[y-1*len..y+0*len-1, x-2*len..x-2*len+MAX(1,slen)-1]);
			len:=len*2;
			slen:=len DIV 2
		END;
		RETURN img
	END GetFoveaSampled2;

	(*extract foveal representation from 2 side-by-side matrices at given location; block aspect ratio is =2, i.r. thinner shells *)
	PROCEDURE GetFoveaSampled2Dual*(CONST m,m1:Matrix; centerX,centerY: SIZE): Matrix; (* *)
	CONST Dual=2; D=12;
	VAR  i, x,y, len, slen:SIZE; d2: ARRAY [2] OF Datatype;
	BEGIN
		IF ~HasSize(img, [2*shells+1, Dual*12]) THEN NEW(img, 2*shells+1, Dual*12) END; (* subblocks *)
		len:=innerBlockSize;
		slen:=len DIV 2;
		x:=centerX;
		y:=centerY;
		img[0, 0..2]:=Mean(m[y..y+len-1, x-len..x-1]); (* rotating from 9 o clock, clockwise*)(*! use Mean() or sample() ?*)
		img[0, 3..5]:=Mean(m[y..y+len-1, x..x+len-1]); 
		img[0, 6..8]:=Mean(m[y-len..y-1, x..x+len-1]); 
		img[0, 9..11]:=Mean(m[y-len..y-1, x-len..x-1]); (* core *)(*to do: blocks instead of fixed pixel size*)

		img[0, D+0..D+2]:=Mean(m1[y..y+len-1, x-len..x-1]); (* rotating from 9 o clock, clockwise*)
		img[0, D+3..D+5]:=Mean(m1[y..y+len-1, x..x+len-1]); 
		img[0, D+6..D+8]:=Mean(m1[y-len..y-1, x..x+len-1]); 
		img[0, D+9..D+11]:=Mean(m1[y-len..y-1, x-len..x-1]); (* core *)(*to do: blocks instead of fixed pixel size*)

		FOR i:=0 TO shells-1 DO
			
			d2:= Sample2(m[y+0*len..y+1*len-1, x-2*len+slen..x-1*len-1],m1[y+0*len..y+1*len-1, x-2*len+slen..x-1*len-1]); 
			img[2*i+1, 0] := d2[0]; img[2*i+1, D+0] := d2[1];
			d2:= Sample2(m[y+1*len..y+2*len-1, x-2*len+slen..x-1*len-1],m1[y+1*len..y+2*len-1, x-2*len+slen..x-1*len-1]);
			img[2*i+1, 1] :=  d2[0]; img[2*i+1, D+1] := d2[1];			
			d2:= Sample2(m[y+1*len..y+1*len+MAX(1,slen)-1, x-1*len..x+0*len-1],m1[y+1*len..y+1*len+MAX(1,slen)-1, x-1*len..x+0*len-1]);
			img[2*i+1, 2] := d2[0]; img[2*i+1,D+2] := d2[1]; 			
			d2:= Sample2(m[y+1*len..y+1*len+MAX(1,slen)-1, x+0*len..x+1*len-1],m1[y+1*len..y+1*len+MAX(1,slen)-1, x+0*len..x+1*len-1]);
			img[2*i+1, 3] := d2[0]; img[2*i+1,D+3] := d2[1]; 			
			d2:= Sample2(m[y+1*len..y+1*len+MAX(1,slen)-1, x+1*len..x+2*len-1],m1[y+1*len..y+1*len+MAX(1,slen)-1, x+1*len..x+2*len-1]);
			img[2*i+1, 4] := d2[0]; img[2*i+1,D+4] := d2[1]; 			
			d2:= Sample2(m[y+0*len..y+1*len-1, x+1*len..x+1*len+MAX(1,slen)-1],m1[y+0*len..y+1*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
			img[2*i+1, 5] := d2[0]; img[2*i+1,D+5] := d2[1]; 			
			d2:= Sample2(m[y-1*len..y+0*len-1, x+1*len..x+1*len+MAX(1,slen)-1],m1[y-1*len..y+0*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
			img[2*i+1, 6] := d2[0]; img[2*i+1,D+6] := d2[1]; 			
			d2:= Sample2(m[y-2*len..y-1*len-1, x+1*len..x+1*len+MAX(1,slen)-1],m1[y-2*len..y-1*len-1, x+1*len..x+1*len+MAX(1,slen)-1]);
			img[2*i+1, 7] := d2[0]; img[2*i+1,D+7] := d2[1]; 			
			d2:= Sample2(m[y-2*len+slen..y-1*len-1, x+0*len..x+1*len-1],m1[y-2*len+slen..y-1*len-1, x+0*len..x+1*len-1]);
			img[2*i+1, 8] := d2[0]; img[2*i+1,D+8] := d2[1]; 			
			d2:= Sample2(m[y-2*len+slen..y-1*len-1, x-1*len..x+0*len-1],m1[y-2*len+slen..y-1*len-1, x-1*len..x+0*len-1]);
			img[2*i+1, 9] := d2[0]; img[2*i+1,D+9] := d2[1]; 			
			d2:= Sample2(m[y-2*len+slen..y-1*len-1, x-2*len..x-1*len-1],m1[y-2*len+slen..y-1*len-1, x-2*len..x-1*len-1]);
			img[2*i+1,10] := d2[0]; img[2*i+1,D+10] := d2[1]; 			
			d2:= Sample2(m[y-1*len..y+0*len-1, x-2*len+slen..x-1*len-1],m1[y-1*len..y+0*len-1, x-2*len+slen..x-1*len-1]);
			img[2*i+1,11] := d2[0]; img[2*i+1,D+11] := d2[1]; 


			d2:= Sample2(m[y+0*len..y+1*len-1, x-2*len..x-2*len+MAX(1,slen)-1],m1[y+0*len..y+1*len-1, x-2*len..x-2*len+MAX(1,slen)-1]); 
			img[2*i+2, 0] := d2[0]; img[2*i+2,D+0] := d2[1]; 			
			d2:= Sample2(m[y+1*len..y+2*len-1, x-2*len..x-2*len+MAX(1,slen)-1],m1[y+1*len..y+2*len-1, x-2*len..x-2*len+MAX(1,slen)-1]);
			img[2*i+2, 1] := d2[0]; img[2*i+2,D+1] := d2[1]; 			
			d2:= Sample2(m[y+1*len+slen..y+2*len-1, x-1*len..x+0*len-1],m1[y+1*len+slen..y+2*len-1, x-1*len..x+0*len-1]);
			img[2*i+2, 2] := d2[0]; img[2*i+2,D+2] := d2[1]; 			
			d2:= Sample2(m[y+1*len+slen..y+2*len-1, x+0*len..x+1*len-1],m1[y+1*len+slen..y+2*len-1, x+0*len..x+1*len-1]);
			img[2*i+2, 3] := d2[0]; img[2*i+2,D+3] := d2[1]; 			
			d2:= Sample2(m[y+1*len+slen..y+2*len-1, x+1*len..x+2*len-1],m1[y+1*len+slen..y+2*len-1, x+1*len..x+2*len-1]);
			img[2*i+2, 4] := d2[0]; img[2*i+2,D+4] := d2[1]; 			
			d2:= Sample2(m[y+0*len..y+1*len-1, x+1*len+slen..x+2*len-1],m1[y+0*len..y+1*len-1, x+1*len+slen..x+2*len-1]);
			img[2*i+2, 5] := d2[0]; img[2*i+2,D+5] := d2[1]; 			
			d2:= Sample2(m[y-1*len..y+0*len-1, x+1*len+slen..x+2*len-1],m1[y-1*len..y+0*len-1, x+1*len+slen..x+2*len-1]);
			img[2*i+2, 6] := d2[0]; img[2*i+2,D+6] := d2[1]; 			
			d2:= Sample2(m[y-2*len..y-1*len-1, x+1*len+slen..x+2*len-1],m1[y-2*len..y-1*len-1, x+1*len+slen..x+2*len-1]);
			img[2*i+2, 7] := d2[0]; img[2*i+2,D+7] := d2[1]; 			
			d2:= Sample2(m[y-2*len..y-2*len+MAX(1,slen)-1, x+0*len..x+1*len-1],m1[y-2*len..y-2*len+MAX(1,slen)-1, x+0*len..x+1*len-1]);
			img[2*i+2, 8] := d2[0]; img[2*i+2,D+8] := d2[1]; 			
			d2:= Sample2(m[y-2*len..y-2*len+MAX(1,slen)-1, x-1*len..x+0*len-1],m1[y-2*len..y-2*len+MAX(1,slen)-1, x-1*len..x+0*len-1]);
			img[2*i+2, 9] := d2[0]; img[2*i+2,D+9] := d2[1]; 			
			d2:= Sample2(m[y-2*len..y-2*len+MAX(1,slen)-1, x-2*len..x-1*len-1],m1[y-2*len..y-2*len+MAX(1,slen)-1, x-2*len..x-1*len-1]);
			img[2*i+2,10] := d2[0]; img[2*i+2,D+10] := d2[1]; 			
			d2:= Sample2(m[y-1*len..y+0*len-1, x-2*len..x-2*len+MAX(1,slen)-1],m1[y-1*len..y+0*len-1, x-2*len..x-2*len+MAX(1,slen)-1]);
			img[2*i+2,11] := d2[0]; img[2*i+2,D+11] := d2[1]; 
			
			len:=len*2;
			slen:=len DIV 2
		END;
		RETURN img
	END GetFoveaSampled2Dual;

	(*extract foveal representation from matrix at given location; block aspect ratio is =1*)
	PROCEDURE GetFoveaSampled*(CONST m:Matrix; centerX,centerY: SIZE; sample:=Sample: ArrayFunction): Matrix; (* *)
	VAR i, x,y, len:SIZE;
	BEGIN
		IF ~HasSize(img, [shells+1, 12]) THEN NEW(img, shells+1, 12) END; (* subblocks *)
		len:=innerBlockSize;
		x:=centerX;
		y:=centerY;
		img[0, 0..2]:=sample(m[y..y+len-1, x-len..x-1]); (* rotating from 9 o clock, clockwise*)
		img[0, 3..5]:=sample(m[y..y+len-1, x..x+len-1]); 
		img[0, 6..8]:=sample(m[y-len..y-1, x..x+len-1]); 
		img[0, 9..11]:=sample(m[y-len..y-1, x-len..x-1]); (* core *)(*to do: blocks instead of fixed pixel size*)
		FOR i:=0 TO shells-1 DO
			img[i+1, 0] := sample(m[y+0*len..y+1*len-1, x-2*len..x-1*len-1]); (* performance: could substitute Mean() by simple sampling *)
			img[i+1, 1] := sample(m[y+1*len..y+2*len-1, x-2*len..x-1*len-1]);
			img[i+1, 2] := sample(m[y+1*len..y+2*len-1, x-1*len..x+0*len-1]);
			img[i+1, 3] := sample(m[y+1*len..y+2*len-1, x+0*len..x+1*len-1]);
			img[i+1, 4] := sample(m[y+1*len..y+2*len-1, x+1*len..x+2*len-1]);
			img[i+1, 5] := sample(m[y+0*len..y+1*len-1, x+1*len..x+2*len-1]);
			img[i+1, 6] := sample(m[y-1*len..y+0*len-1, x+1*len..x+2*len-1]);
			img[i+1, 7] := sample(m[y-2*len..y-1*len-1, x+1*len..x+2*len-1]);
			img[i+1, 8] := sample(m[y-2*len..y-1*len-1, x+0*len..x+1*len-1]);
			img[i+1, 9] := sample(m[y-2*len..y-1*len-1, x-1*len..x+0*len-1]);
			img[i+1,10] := sample(m[y-2*len..y-1*len-1, x-2*len..x-1*len-1]);
			img[i+1,11] := sample(m[y-1*len..y+0*len-1, x-2*len..x-1*len-1]);
			len:=len*2;
		END;
		RETURN img
	END GetFoveaSampled;
	
	PROCEDURE Transform*(CONST rawData, rawLabels:Tensor; VAR transformedData, labels:Tensor; mode: SIGNED32);
	BEGIN
		ASSERT(DIM(rawData)=2, 200);
		SELF.mode:=mode;
		labels:=rawLabels;
		IF (mode=ModeMean) THEN 		(*performance: averaging and distortion more costly than subsampling below*)
			transformedData:= GetFovea2(rawData, blockSize[0] DIV 2, blockSize[1] DIV 2); (*uses internal*)
		ELSIF mode=ModeSample THEN
			transformedData:= GetFoveaSampled2(rawData, blockSize[0] DIV 2, blockSize[1] DIV 2); (*!implementation limitation, uses global function*)(*speedier ? adds noise for more robust learning ?*)
		ELSE HALT(300)
			(*transformedData:= GetFovea2(rawData, blockSize[0] DIV 2, blockSize[1] DIV 2, Gridpoints);*) (*!implementation limitation, uses global function*)(*speedier ? adds noise for more robust learning ?*)
		END;
	END Transform;

	PROCEDURE TransformStack*(CONST rawData, rawLabels:Tensor; VAR transformedData, labels:Tensor; mode: SIGNED32);
	BEGIN
		SELF.mode:=mode;
		labels:=rawLabels;
		IF (mode=ModeMean) THEN 		(*performance: averaging and distortion more costly than subsampling below*)
			transformedData:= GetFoveaStack2(rawData, blockSize[0] DIV 2, blockSize[1] DIV 2, Stat.Mean); (*uses internal*)
		ELSIF mode=ModeSample THEN
			transformedData:= GetFoveaSampledStack2(rawData, blockSize[0] DIV 2, blockSize[1] DIV 2); (*!implementation limitation, uses global function*)(*speedier ? adds noise for more robust learning ?*)
		ELSE
			transformedData:= GetFoveaStack2(rawData, blockSize[0] DIV 2, blockSize[1] DIV 2, Gridpoints); (*!implementation limitation, uses global function*)(*speedier ? adds noise for more robust learning ?*)
		END;
	END TransformStack;


	PROCEDURE Reconstruct*(CONST fovea:Matrix; shellAspectRatio:=2:INTEGER; innerBlockSize:=1:INTEGER):Matrix;
	VAR w,shells:INTEGER;
	BEGIN
		ASSERT(LEN(fovea,0)=LEN(fovea,1),300); (* square foveas only. implememntation limitation *)
		w:=2*innerBlockSize; 
		shells:=0;
		WHILE w<LEN(fovea,DIM(fovea)-1) DO w:=w*2; INC(shells, shellAspectRatio) END;
		ASSERT(w=LEN(fovea,DIM(fovea)-1),200);
		IF shellAspectRatio=1 THEN		RETURN ReconstructFovea(fovea,innerBlockSize,shells); 
		ELSIF shellAspectRatio=2 THEN	RETURN ReconstructFovea2(fovea,innerBlockSize,shells); (*default for roi size 64x64 *)
		ELSE HALT(202)
		END;
	END Reconstruct;
	
	PROCEDURE ReconstructStack*(CONST fovea:Tensor; shellAspectRatio:=2:INTEGER; innerBlockSize:=1:INTEGER):Tensor;
	VAR w, shells:INTEGER;
	BEGIN
		ASSERT(LEN(fovea,0)=LEN(fovea,1),300); (* square foveas only. implememntation limitation *)
		w:=2*innerBlockSize; 
		shells:=0;
		WHILE w<LEN(fovea,DIM(fovea)-1) DO w:=w*2; INC(shells, shellAspectRatio) END;
		IF shellAspectRatio=1 THEN	HALT(200); (*RETURN ReconstructFoveaStack(fovea,innerBlockSize,shells0); *)(*not yet implemented *)
		ELSIF shellAspectRatio=2 THEN	RETURN ReconstructFovea2(fovea,innerBlockSize,shells); (*default for roi size 64x64 *)
		ELSE HALT(200);
		END;
	END ReconstructStack;
END Transformer;

VAR rand:Random.Generator; 
	oldName: Files.FileName;

PROCEDURE HasSize(CONST a:Array; CONST size:SizeVector):BOOLEAN;
VAR i:SIZE;
BEGIN
	IF DIM(a)#LEN(size,0) THEN RETURN FALSE
	ELSE
		FOR i:=0 TO DIM(a)-1 DO
			IF LEN(a,i)#size[i] THEN RETURN FALSE END;
		END;
		RETURN TRUE
	END;
END HasSize;

(*sampling modes*)

PROCEDURE Mean(CONST m: Array):Datatype;
BEGIN
	RETURN Stat.Mean(m);
END Mean;

PROCEDURE Sample*(CONST m: Array):Datatype;
VAR x,y: SIGNED32;
BEGIN
	IF LEN(m,1)<=1 THEN x:=0 ELSE x:=rand.Dice(SIGNED32(LEN(m,1))) END; 
	IF LEN(m,0)<=1 THEN y:=0 ELSE y:=rand.Dice(SIGNED32(LEN(m,0))) END;
	IF LEN(m,1)*LEN(m,0)>0 THEN RETURN m[y, x] ELSE RETURN 0 END;(*catch zero size subblocks*)
END Sample;

(* sample 2 arrays at same random position in parallel *)
PROCEDURE Sample2*(CONST m,m1: Array):ARRAY [2] OF Datatype;
VAR x,y: SIGNED32; res:ARRAY [2] OF Datatype;
BEGIN
	IF LEN(m,1)<=1 THEN x:=0 ELSE x:=rand.Dice(SIGNED32(LEN(m,1))) END; 
	IF LEN(m,0)<=1 THEN y:=0 ELSE y:=rand.Dice(SIGNED32(LEN(m,0))) END;
	IF LEN(m,1)*LEN(m,0)>0 THEN res[0]:=m[y, x]; res[1]:=m1[y, x] END;(*catch zero size subblocks*)
	RETURN res
END Sample2;

PROCEDURE SampleStack*(CONST m: Array):Vector;
VAR x,y: SIGNED32; empty:Vector;
BEGIN
	ASSERT(DIM(m)=3,200);
	IF LEN(m,1)<=1 THEN x:=0 ELSE x:=rand.Dice(SIGNED32(LEN(m,2))) END; 
	IF LEN(m,0)<=1 THEN y:=0 ELSE y:=rand.Dice(SIGNED32(LEN(m,1))) END;
	IF LEN(m,1)*LEN(m,2)>0 THEN RETURN m[..,y, x] ELSE (*NEW(empty,LEN(m,0)); empty:=0;*) RETURN empty END;(*catch zero size subblocks*)
END SampleStack;

(*sample at gridpoints*)
PROCEDURE Gridpoints(CONST m: Array):Datatype;
BEGIN
	ASSERT(DIM(m)=2, 200);
	IF LEN(m,1)*LEN(m,0)>0 THEN RETURN m[0, 0] ELSE RETURN 0 END;(*catch zero size subblocks*)
END Gridpoints;

(*sample is range in ROI*)
PROCEDURE Range(CONST m: Array):Datatype;
BEGIN
	ASSERT(DIM(m)=2, 200);
	TRACE("Range ",LEN(m,0));
	RETURN MAX(m)-MIN(m)
END Range;

(*sample at gridpoints*)
PROCEDURE GridpointStack(CONST m: Array):Vector;
VAR empty:Vector;
BEGIN
	ASSERT(DIM(m)=3, 200);
	IF LEN(m,1)*LEN(m,2)>0 THEN RETURN m[0, 0] ELSE (*NEW(empty,LEN(m,0)); empty:=0;*) RETURN empty END;(*catch zero size subblocks*)
END GridpointStack;

PROCEDURE GetBlockSize*(innerBlockSize, shells: SIGNED32):SizeVector;
VAR w,h: SIZE; i:SIGNED32;
BEGIN
	IF LEN(RESULT,0)#2 THEN NEW(RESULT,2) END;
	w:=2*innerBlockSize; 
	h:=2*innerBlockSize;
	FOR i:=0 TO shells-1 DO
		w:=w*2; h:=h*2;
	END;
	RESULT[0]:=h; RESULT[1]:=w;
	RETURN RESULT
END GetBlockSize;

PROCEDURE GetFoveaSize*(innerBlockSize, shells, shellType: SIGNED32):SizeVector;
BEGIN
	IF LEN(RESULT,0)#2 THEN NEW(RESULT,2) END;
	RESULT[0]:=1+shells*shellType; RESULT[1]:=12;
	RETURN RESULT
END GetFoveaSize;

PROCEDURE GetFoveaShells*(innerBlockSize, outerBlockSize: SIZE):SIGNED32; (*Full shells. These can be split into concentric sub-shells per shell. *)
VAR shells:SIZE;
BEGIN
	outerBlockSize:=outerBlockSize DIV innerBlockSize DIV 2;
	DEC(outerBlockSize);
	shells:=0;
	WHILE outerBlockSize>=1 DO
		INC(shells);
		outerBlockSize:=outerBlockSize DIV 2
	END;
	RETURN SIGNED32(shells)  (* xaspectRatio*)
END GetFoveaShells;

(*extract foveal representation from matrix at given location; block aspect ratio is =1*)
PROCEDURE GetFovea*(CONST m:Matrix; centerX,centerY: SIZE; innerBlockSize:=1, shells:=5: SIGNED32): Matrix; (* default parameterization for roi size 64x64 *)
VAR t:Transformer;
BEGIN
	NEW(t,innerBlockSize,shells);
	RETURN t.GetFovea(m,centerX,centerY(*,innerBlockSize,shells*));
END GetFovea;

(*extract foveal representation from matrix at given location; block aspect ratio is =2, i.r. thinner shells *)
PROCEDURE GetFovea2*(CONST m:Matrix; centerX,centerY:SIZE; innerBlockSize:=1, shells:=5: SIGNED32): Matrix; (*default for roi size 64x64 *)
VAR t:Transformer;
BEGIN
	NEW(t,innerBlockSize,shells);
	RETURN t.GetFovea2(m,centerX,centerY(*,innerBlockSize,shells*));
END GetFovea2;

(*extract multilayer foveal representation from tensor at given location; block aspect ratio is =2, i.r. thinner shells *)
PROCEDURE GetFoveaStack2*(CONST m:Tensor; centerX,centerY: SIZE;func: ArrayFunction; innerBlockSize:=1, shells:=5: SIGNED32): Tensor; (*default for roi size 64x64 *)(*! tbd: which index position is layer index ? *)
VAR t:Transformer;
BEGIN
	NEW(t,innerBlockSize,shells);
	RETURN t.GetFoveaStack2(m,centerX,centerY,(*innerBlockSize,shells,*)func);
END GetFoveaStack2;

(*extract multilayer foveal representation from tensor at given location; block aspect ratio is =2, i.r. thinner shells *)
PROCEDURE GetFoveaSampledStack2*(CONST m:Tensor; centerX,centerY: SIZE; innerBlockSize:=1, shells:=5: SIGNED32): Tensor;(*default for roi size 64x64 *) (*! tbd: which index position is layer index ? *)
VAR t:Transformer;
BEGIN
	NEW(t,innerBlockSize,shells);
	RETURN t.GetFoveaSampledStack2(m,centerX,centerY(*,innerBlockSize,shells*));
END GetFoveaSampledStack2;

(*extract multilayer foveal representation from tensor at given location; block aspect ratio is =2, i.r. thinner shells *)
PROCEDURE GetFoveaFixSampledStack2*(CONST m:Tensor; centerX,centerY: SIZE; innerBlockSize:=1, shells:=5: SIGNED32): Tensor;(*default for roi size 64x64 *) (*! tbd: which index position is layer index ? *)
VAR t:Transformer;
BEGIN
	NEW(t,innerBlockSize,shells);
	RETURN t.GetFoveaFixSampledStack2(m,centerX,centerY);
END GetFoveaFixSampledStack2;


(*extract foveal representation from matrix at given location; block aspect ratio is =2, i.r. thinner shells *)
PROCEDURE GetFoveaSampled2*(CONST m:Matrix; centerX,centerY: SIZE; innerBlockSize:=1, shells:=5: SIGNED32): Matrix; (*default for roi size 64x64 *)
VAR 	t:Transformer;
BEGIN
	NEW(t,innerBlockSize,shells);
	RETURN t.GetFoveaSampled2(m,centerX,centerY(*,innerBlockSize,shells*));
END GetFoveaSampled2;

(*extract foveal representation from matrix at given location; block aspect ratio is =1*)
PROCEDURE GetFoveaSampled*(CONST m:Matrix; centerX,centerY: SIZE; innerBlockSize:=1, shells:=5: SIGNED32): Matrix; (*default for roi size 64x64 *)
VAR t:Transformer;
BEGIN
	NEW(t,innerBlockSize,shells);
	RETURN t.GetFoveaSampled(m,centerX,centerY(*,innerBlockSize,shells*));
END GetFoveaSampled;

PROCEDURE ReconstructFovea*(CONST img:Matrix; innerBlockSize:=1, shells:=5: SIGNED32): Matrix; (*default for roi size 64x64 *)
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

PROCEDURE ReconstructFovea2*(CONST img:Matrix; (*centerX,centerY: SIZE; *)innerBlockSize:=1, shells:=5: SIGNED32): Matrix; (* *)
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
		m[y+0*len..y+1*len-1, x-2*len+slen..x-1*len-1] := img[2*i+1, 0]; 
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

PROCEDURE ReconstructFoveaStack2*(CONST img:Tensor; innerBlockSize:=1, shells:=5: SIGNED32): Tensor; (*default for roi size 64x64 *)
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
			m[layer, y+0*len..y+1*len-1, x-2*len+slen..x-1*len-1] := img[layer, 2*i+1, 0]; 
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
END ReconstructFoveaStack2;

(* Helper proc: write information about fovea to writer*)
TYPE Reporter*=OBJECT
	VAR log:Streams.Writer;
	PROCEDURE &Init*(w:Streams.Writer);
	BEGIN
		log:=w;
	END Init;
	
	PROCEDURE Report*(shell,i, y0,y1, x0,x1:SIZE);
	BEGIN
		log.Int(shell,6); log.Int(i,6); log.Int(y0,6); log.Int(y1,6); log.Int(x0,6); log.Int(x1,6); log.Ln;
	END Report;
	
	PROCEDURE ReportShell*(shell:SIZE);
	VAR x,y,len,slen,i:SIZE;
	BEGIN
			len:=1;i:=0;
			FOR i:=0 TO shell-1 DO len:=len*2 END;
			slen:=len DIV 2;
			Report(2*shell, 0,y+0*len,		y+1*len-1, 					x-2*len+slen,	x-1*len-1); (* performance: could substitute Mean() by simple sampling *)
			Report(2*shell, 1,y+1*len,		y+2*len-1, 					x-2*len+slen,	x-1*len-1);
			Report(2*shell, 2,y+1*len,		y+1*len+MAX(1,slen)-1, x-1*len,			x+0*len-1);
			Report(2*shell, 3,y+1*len,		y+1*len+MAX(1,slen)-1, x+0*len,			x+1*len-1);
			Report(2*shell, 4,y+1*len,		y+1*len+MAX(1,slen)-1, x+1*len,			x+2*len-1);
			Report(2*shell, 5,y+0*len,		y+1*len-1, 					x+1*len,			x+1*len+MAX(1,slen)-1);
			Report(2*shell, 6,y-1*len,		y+0*len-1, 					x+1*len,			x+1*len+MAX(1,slen)-1);
			Report(2*shell, 7,y-2*len,		y-1*len-1, 					x+1*len,			x+1*len+MAX(1,slen)-1);
			Report(2*shell, 8,y-2*len+slen,y-1*len-1, 					x+0*len,			x+1*len-1);
			Report(2*shell, 9,y-2*len+slen,y-1*len-1, 					x-1*len,			x+0*len-1);
			Report(2*shell,10,y-2*len+slen,y-1*len-1, 					x-2*len,			x-1*len-1); (*! there is some indexing problem here ,.*)
			Report(2*shell,11,y-1*len,		y+0*len-1, 					x-2*len+slen,	x-1*len-1);
			
			log.Ln;

			Report(2*shell+1, 0,y+0*len,		y+1*len-1, 					x-2*len,			x-2*len+MAX(1,slen)-1); 
			Report(2*shell+1, 1,y+1*len,		y+2*len-1, 					x-2*len,			x-2*len+MAX(1,slen)-1);
			Report(2*shell+1, 2,y+1*len+slen,y+2*len-1, 					x-1*len,			x+0*len-1);
			Report(2*shell+1, 3,y+1*len+slen,y+2*len-1, 					x+0*len,			x+1*len-1);
			Report(2*shell+1, 4,y+1*len+slen,y+2*len-1, 					x+1*len,			x+2*len-1);
			Report(2*shell+1, 5,y+0*len,		y+1*len-1, 					x+1*len+slen,	x+2*len-1);
			Report(2*shell+1, 6,y-1*len,		y+0*len-1, 					x+1*len+slen,	x+2*len-1);
			Report(2*shell+1, 7,y-2*len,		y-1*len-1, 					x+1*len+slen,	x+2*len-1);
			Report(2*shell+1, 8,y-2*len,		y-2*len+MAX(1,slen)-1, x+0*len,			x+1*len-1);
			Report(2*shell+1, 9,y-2*len,		y-2*len+MAX(1,slen)-1, x-1*len,			x+0*len-1);
			Report(2*shell+1,10,y-2*len,		y-2*len+MAX(1,slen)-1, x-2*len,			x-1*len-1);
			Report(2*shell+1,11,y-1*len,		y+0*len-1, 					x-2*len,			x-2*len+MAX(1,slen)-1);
			log.Ln; 
			log.Update;
	END ReportShell;
END Reporter;


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

(*decompose and reconstruct diagonal test pattern*)
PROCEDURE TestA*;
VAR img, recon, fovea: Tensor;
	i:SIZE;
BEGIN
	NEW(img, 3, 512, 512);
	FOR i:=2 TO LEN(img,1)-3 BY 10 DO
		img[*,i-2..i+2, i-2..i+2] := 1;
	END;
	img[1,?]:=img[0,?] /2; 
	fovea:=GetFoveaStack2(img, 256, 256, Mean, 1, 6);
	recon:=ReconstructFoveaStack2(fovea, 1, 6);
	
	WMArrayPanel.AddWindow(img, "img"); 
	WMArrayPanel.AddWindow(fovea, "fovea"); 
	WMArrayPanel.AddWindow(recon, "recon"); 
END TestA;

(*decompose and reconstruct diagonal gradient pattern*)
PROCEDURE TestB*;
VAR img, recon, fovea: Tensor;
	i,j:SIZE;
BEGIN
	NEW(img, 3, 512, 512);
	FOR i:=4 TO LEN(img,1)-4 BY 8 DO
		FOR j:=4 TO LEN(img,2)-4 BY 8 DO
			img[*,j-4..j+3, i-4..i+3] := i+j;
		END;
	END;
	img[1,?]:=img[0,?] /2; 
	fovea:=GetFoveaStack2(img, 256, 256, Mean, 1, 6);
	recon:=ReconstructFoveaStack2(fovea, 1, 6);
	
	WMArrayPanel.AddWindow(img, "img"); 
	WMArrayPanel.AddWindow(fovea, "fovea"); 
	WMArrayPanel.AddWindow(recon, "recon"); 
END TestB;

(*decompose and resize/reconstruct diagonal gradient pattern*)
PROCEDURE TestC*;
VAR img, recon, fovea: Tensor;
	i,j:SIZE;
BEGIN
	NEW(img, 3, 512, 512);
	FOR i:=4 TO LEN(img,1)-4 BY 8 DO
		FOR j:=4 TO LEN(img,2)-4 BY 8 DO
			img[*,j-4..j+3, i-4..i+3] := i+j;
		END;
	END;
	img[1,?]:=img[0,?] /2; 
	fovea:=GetFoveaStack2(img, 256, 256, Mean, 1, 6);
	recon:=ReconstructFoveaStack2(fovea, 2, 6);
	
	WMArrayPanel.AddWindow(img, "img"); 
	WMArrayPanel.AddWindow(fovea, "fovea"); 
	WMArrayPanel.AddWindow(recon, "recon"); 
END TestC;

(*decompose and resize/reconstruct diagonal gradient pattern*)
PROCEDURE TestD*;
VAR img, recon, fovea: Tensor;
	i,j:SIZE;
BEGIN
	NEW(img, 3, 512, 512);
	FOR i:=4 TO LEN(img,1)-4 BY 8 DO
		FOR j:=4 TO LEN(img,2)-4 BY 8 DO
			img[*,j-4..j+3, i-4..i+3] := i+j;
		END;
	END;
	img[1,?]:=img[0,?] /2; 
	fovea:=GetFoveaSampledStack2(img, 256, 256, 1, 6);
	recon:=ReconstructFoveaStack2(fovea, 2, 6);
	
	WMArrayPanel.AddWindow(img, "img"); 
	WMArrayPanel.AddWindow(fovea, "fovea"); 
	WMArrayPanel.AddWindow(recon, "recon"); 
END TestD;

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
	x:=len DIV 2 -64 + rand.Dice(128);(*somewhere in the middle*)
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

PROCEDURE Test2*(context:Commands.Context); (* 1 layer, split shell blocks in pheriphery*)
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
	x:=len DIV 2 -64 + rand.Dice(128);(*somewhere in the middle*)
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

PROCEDURE TestA2*(context:Commands.Context); (*n layers, split shell blocks in periphery. use Mean() of each block for encoding*)
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
	fovea:=GetFoveaStack2(raster, x, y, Mean, blockSize, nShells); (* compressed averaging sampling*)
	recon:=ReconstructFoveaStack2(fovea, blockSize, nShells);
	IF name#oldName THEN 
		WMArrayPanel.AddWindow(raster,"raster");
	END;
	WMArrayPanel.AddWindow(fovea, "fovea");
	WMArrayPanel.AddWindow(recon, "recon");
	COPY(name, oldName);
END TestA2;

PROCEDURE TestA2Range*(context:Commands.Context); (*n layers, split shell blocks in periphery. use Mean() of each block for encoding*)
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
	fovea:=GetFoveaStack2(raster, x, y, Range, blockSize, nShells); (* compressed averaging sampling*)
	recon:=ReconstructFoveaStack2(fovea, blockSize, nShells);
	IF name#oldName THEN 
		WMArrayPanel.AddWindow(raster,"raster");
	END;
	WMArrayPanel.AddWindow(fovea, "fovea");
	WMArrayPanel.AddWindow(recon, "recon");
	COPY(name, oldName);
END TestA2Range;


PROCEDURE TestSampledStack2*(context:Commands.Context); (*n layers, split blocks in periphery; sample each block at position [random,random]*)
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
	x:=LEN(raster,2) DIV 2 -64 + rand.Dice(128);(*somewhere in the middle*)
	y:=LEN(raster,1) DIV 2 -64 + rand.Dice(128);
	fovea:=GetFoveaStack2(raster, x, y, Sample, blockSize, nShells); (* compressed averaging sampling*)
	recon:=ReconstructFoveaStack2(fovea, blockSize, nShells);
	IF name#oldName THEN 
		WMArrayPanel.AddWindow(raster,"raster");
		WMArrayPanel.AddWindow(fovea, "fovea");
	END;
	WMArrayPanel.AddWindow(recon, "recon");
	COPY(name, oldName);
END TestSampledStack2;

PROCEDURE TestFixSampledStack2*(context:Commands.Context); (*n layers, split blocks in periphery; sample each block at position [random,random]*)
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
	x:=LEN(raster,2) DIV 2 -64 + rand.Dice(128);(*somewhere in the middle*)
	y:=LEN(raster,1) DIV 2 -64 + rand.Dice(128);
	fovea:=GetFoveaFixSampledStack2(raster, x, y, blockSize, nShells); (* compressed averaging sampling*)
	recon:=ReconstructFoveaStack2(fovea, blockSize, nShells);
	IF name#oldName THEN 
		WMArrayPanel.AddWindow(raster,"raster");
		WMArrayPanel.AddWindow(fovea, "fovea");
	END;
	WMArrayPanel.AddWindow(recon, "recon");
	COPY(name, oldName);
END TestFixSampledStack2;



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
	x:=LEN(raster,2) DIV 2 -64 + rand.Dice(128);(*somewhere in the middle*)
	y:=LEN(raster,1) DIV 2 -64 + rand.Dice(128);
	fovea:=GetFoveaStack2(raster, x, y, Gridpoints, blockSize, nShells); (* sampling at block positions [0,0]*)
	recon:=ReconstructFoveaStack2(fovea, blockSize, nShells);
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
	x:=len DIV 2 -64 + rand.Dice(128);(*somewhere in the middle*)
	y:=len DIV 2 -64 + rand.Dice(128);
	fovea:=GetFoveaSampled2(raster, x, y, 2, 6); (*compressed random sampling*)
	recon:=ReconstructFovea2(fovea, 2, 6);
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

PROCEDURE TestFoveaSize*;
VAR size:SIZE
BEGIN
	size:=GetFoveaShells(1,64);
	TRACE(size);
END TestFoveaSize;


PROCEDURE Report*(context:Commands.Context);
VAR shell:SIZE; reporter:Reporter;
BEGIN
	IF context.arg.GetSize(shell,FALSE) THEN
		NEW(reporter,context.out);
		reporter.ReportShell(shell);
	END;
END Report;

BEGIN
	NEW(rand)
END TensorFovea.

TensorFovea.Test ~
TensorFovea.Test0 ~
TensorFovea.TestA ~
TensorFovea.TestB ~
TensorFovea.TestC ~
TensorFovea.TestD ~
TensorFovea.Test1 ~
TensorFovea.Test1 SimpleEye.jpg ~
TensorFovea.Test2 SimpleEye.jpg ~
TensorFovea.Test2 Yellow_Duck.jpg~
TensorFovea.TestA2 Yellow_Duck.jpg 1 8~
TensorFovea.TestA2Range Yellow_Duck.jpg 1 8~
TensorFovea.Test2 "HIGHDIM:/Code/EyeTracker/EyeDB_Internet/aergaf.jpg"~
TensorFovea.TestSampled2 "HIGHDIM:/Code/EyeTracker/EyeDB_Internet/aergaf.jpg"~
TensorFovea.TestA2 "HIGHDIM:/Code/EyeTracker/EyeDB_Internet/aergaf.jpg"~
TensorFovea.TestSampledStack2 "HIGHDIM:/Code/EyeTracker/EyeDB_Internet/aergaf.jpg"~
TensorFovea.TestFixSampledStack2 "HIGHDIM:/Code/EyeTracker/EyeDB_Internet/aergaf.jpg"~
TensorFovea.TestGridpointsA2 "HIGHDIM:/Code/EyeTracker/EyeDB_Internet/aergaf.jpg"~
TensorFovea.Test3 "HIGHDIM:/Code/EyeTracker/EyeDB_Internet/aergaf.jpg" 4 5 ~
TensorFovea.Test3 "HIGHDIM:/Code/EyeTracker/EyeDB_Internet/aergaf.jpg" 4 5 sampled ~
TensorFovea.TestA2 SaasFee.jpg 3 7~
TensorFovea.TestA2Range SaasFee.jpg 3 7~
TensorFovea.TestA2 "HIGHDIM:/Code/EyeTracker/EyeDB_Internet/8476656067_ee498cc265_b.jpg" 2 7 ~
TensorFovea.TestA2Range "HIGHDIM:/Code/EyeTracker/EyeDB_Internet/8476656067_ee498cc265_b.jpg" 2 7 ~
TensorFovea.Test3 "HIGHDIM:/Code/EyeTracker/EyeDB_Internet/8476656067_ee498cc265_b.jpg" ~
TensorFovea.Report 1~
TensorFovea.Report 3~
TensorFovea.TestFoveaSize ~

System.FreeDownTo WMMatrix ~ 
