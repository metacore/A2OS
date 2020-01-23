MODULE MLConvWavelets; (** AUTHOR "Patrick Hunziker"; PURPOSE "Wavelet Decomposition Layer for Machine learning"; *)

IMPORT Conv:=MLConvNet3D, Wavelets, PlanarWavelets, WMStack, Commands, Util:=MatrixUtilities;

(* M Input Image, M*N output Images*)
TYPE WavePacketLayerMN* = OBJECT (Conv.Layer)
	VAR
		analyzer: PlanarWavelets.Analyzer;
		window: WMStack.Window;
		levels, waveletType:SIGNED32;
		lenX, lenY: Conv.IntVector;

	PROCEDURE &Init*(levels:SIGNED32; waveletType:SIGNED32; show: BOOLEAN);
	BEGIN
		SELF.levels:=levels;
		SELF.waveletType:=waveletType;
		SELF.show:=show;
		CASE waveletType OF
		0:
		ELSE HALT(200)
		END;
	END Init;

	PROCEDURE Propagate*(CONST x: Conv.Dataset); (* [M,h,w] images, resulting in [M,L^2,h/L,w/L]*)
	VAR i,L:SIGNED32;
	BEGIN
		ASSERT(DIM(x)=3, 200);(* implementation limitation*)
		lenX:=LEN(x);
		NEW(lenY,4);
		IF levels=1 THEN L:=2
		ELSIF levels=2 THEN L:=4
		ELSE HALT(201);
		END;
		lenY[0]:=lenX[0]; lenY[1]:=L*L; lenY[2..3]:=lenX[1..2] DIV L;

		ASSERT(Conv.PROD(lenX)=Conv.PROD(lenY), 202);
		IF LEN(y)#lenY THEN NEW(y, lenY) END;
		FOR i:=0 TO LEN(x,0)-1 DO
			NEW(analyzer, Wavelets.Haar, Wavelets.default, x[i,*,*]);  (*move analyser instantaneation to Init()*)
			analyzer.AnalyzePacket(levels);
			IF levels=1 THEN y[i,?]:=Split4(analyzer.data);
			ELSIF levels=2 THEN y[i,?]:=Split16(analyzer.data);
			END;
		END;
	END Propagate;


	PROCEDURE BackProp*(CONST dNext:Conv.Dataset);
	VAR n:SIGNED32;
	BEGIN
		IF LEN(dIn)#lenX THEN NEW(dIn,lenX) END;
		(* remember that wavelet decomposition is a linear operation*)
		dIn:=0;
		FOR n:=0 TO LEN(dNext,1)-1 DO
			dIn:=dIn+dNext[*,n,?];
		END;
	END BackProp;

	PROCEDURE Generate;
	END Generate;

	END WavePacketLayerMN;

	(*TYPE ConvLayerMNM*=OBJECT(Conv.Layer);(*  [M,N] input images, N filters, M output images*)
		VAR mm1: Conv.ConvLayerMM1;
			lenX, lenY: Conv.IntVector;
			filtersize:Conv.IntVector;

		PROCEDURE &New*(CONST filtersize:Conv.IntVector; nonLinear, nonLinearDerivative: Conv.Function); (*filtersize is [w,h]*)
		BEGIN
			SELF.filtersize:=filtersize;
			NEW(mm1,filtersize, nonLinear, nonLinearDerivative);
		END New;

		PROCEDURE Propagate*(CONST x: Conv.Dataset);
		VAR i:SIGNED32;
		BEGIN
			ASSERT(DIM(x)=4);
			lenX:=LEN(x);
			IF LEN(x)#LEN(SELF.x) THEN NEW(SELF.x, LEN(x))
			ELSIF x=SELF.x THEN RETURN (* already processed image; somewhat costly test..*)
			ELSE SELF.x:=x (*! probably redundant, as content of x is also stored in mm1*)
			END;
			NEW(lenY,3); lenY[0]:=LEN(x,0); lenY[1..2]:=LEN(x)[2..3]-filtersize[1..2]+1;
			IF LEN(y)#lenY THEN NEW(y,lenY) END;
			mm1.step:=step;
			mm1.momentum:=momentum;
			mm1.clamp:=clamp;
			FOR i:=0 TO LEN(x,0)-1 DO
				mm1.Propagate(x[i,?]);
				y[i,*,*]:=mm1.y[*,*];
			END;
		END Propagate;

		PROCEDURE 	Backprop*(CONST dNext:Conv.Dataset); (*to do: scaling ?*)
		VAR i:SIGNED32;
		BEGIN
			IF dIn#lenX THEN NEW(dIn,lenX) END;
			FOR i:=0 TO LEN(dIn,0)-1 DO
				mm1.Backprop(dNext[i,?]);
				dIn[i,*,*,*]:=mm1.dIn[*,*,*]
			END;
		END Backprop;
	END ConvLayerMNM;
	*)


PROCEDURE Split4(CONST d:Conv.Matrix):Conv.Dataset; (*! to do: split recursive*)
VAR len: ARRAY [3] OF SIGNED32;
BEGIN
	len[0]:=4; len[1..2]:= (LEN(d)[0..1]+1) DIV 2;
	IF LEN(RESULT)#len THEN NEW(RESULT, len) END;
	RESULT[0,..,..]:=d[..len[1]-1, ..len[2]-1];
	RESULT[1,..,..]:=d[..len[1]-1, len[2]..];
	RESULT[2,..,..]:=d[len[1].., ..len[2]-1];
	RESULT[3,..,..]:=d[len[1].., len[2]..];
	RETURN RESULT
END Split4;

PROCEDURE Split16(CONST d:Conv.Matrix):Conv.Dataset;
VAR len2, len4: ARRAY [3] OF SIGNED32;
BEGIN
	len2[0]:=4; len2[1..2]:= (LEN(d)[0..1]+1) DIV 2;
	len4[0]:=16; len4[1..2]:= (len2[1..2]+1) DIV 2;
	IF LEN(RESULT)#len4 THEN NEW(RESULT, len4) END;
	RESULT[0..3,..,..]:=Split4(d[..len2[1]-1, ..len2[2]-1]);
	RESULT[4..7,..,..]:=Split4(d[..len2[1]-1, len2[2]..]);
	RESULT[8..11,..,..]:=Split4(d[len2[1].., ..len2[2]-1]);
	RESULT[12..15,..,..]:=Split4(d[len2[1].., len2[2]..]);
	RETURN RESULT
END Split16;

PROCEDURE Split64(CONST d:Conv.Matrix):Conv.Dataset;
END Split64;

PROCEDURE Test*(context:Commands.Context);
VAR a: Conv.Dataset;
	wl:WavePacketLayerMN;
	l4: Conv.ConvLayerMNM;
	win: WMStack.Window;
	i, levels:SIGNED32;
BEGIN
	IF ~context.arg.GetInteger(levels, FALSE) THEN levels:=1 END;
	NEW(wl, levels, 0, FALSE);
	NEW(a, 2, 200, 200);
	a[0,30..50, 20..30]:=1;
	a[1,70..80, 50..70]:=1;
	NEW(win, a, "data",0); win.AddWindow;

	wl.Propagate(a); (*wavelet transform*)
	FOR i:=0 TO LEN(a,0)-1 DO
		NEW(wl.window, wl.y[i,*,*,*], "waveletPacket",0);  wl.window.AddWindow;
	END;

	IF levels=1 THEN NEW(l4, [4,10,10], Conv.ScaledSigmoid, Conv.ScaledSigmoidDerivative, FALSE);
	ELSIF levels =2 THEN NEW(l4, [16,10,10], Conv.ScaledSigmoid, Conv.ScaledSigmoidDerivative, FALSE);
	ELSE HALT(200)
	END;
	l4.Propagate(wl.y[?]);
	NEW(wl.window, l4.y[*,*,*], "L4",0);  wl.window.AddWindow;

END Test;



END MLConvWavelets.

MLConvWavelets.Test 1~
MLConvWavelets.Test 2~
SystemTools.FreeDownTo WMStack ~
SystemTools.FreeDownTo WMMatrix ~
