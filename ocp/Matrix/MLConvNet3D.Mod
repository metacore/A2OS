MODULE MLConvNet3D; (** AUTHOR "Patrick Hunziker"; PURPOSE "convolutional neural network"; *)
(*Literature
generics: LeCun, Bengio, Hinton: Deep Learning. Nature 2015

specifics for convolutional neural networks:
Jake Bouvrie, Notes on Convolutional Neural Networks. 2006
David Stutz, Understanding Convolutional Neural Networks: good tutorial
Quoc V. Le: A Tutorial on Deep Learning Part 1: Backpropagation etc
Quoc V. Le: A Tutorial on Deep Learning Part 2: Autoencoders, Convolutional Neural Networks and Recurrent Neural Networks
https://www.tensorflow.org/tutorials/deep_cnn : a great ressource for implementation strategies and optional features

*)


			(*! to do: gain and local contrast normalization compensation, see http://davidstutz.de/wordpress/wp-content/uploads/2014/07/seminar.pdf, p 15*)
			(*! to do: enforce sparsity, see http://cogprints.org/5869/1/cnn_tutorial.pdf page 5 *)

IMPORT MatrixBase, Commands, WMMatrix, WMStack, Util:=MatrixUtilities, Streams, Mathe:=MathL, EulFftwConvolve, PMathSSE, WMGraphics, Kernel, Strings, Files, Random, WMSimpleGraphs, StatisticsBase, MatrixSVD;
	(* ,Filters:=LinearFilters, Wavelets, PlanarTransform,PlanarWavelets, Files,  *)

CONST
	DefaultStep* = 0.05;   (* approximation step *)
	DefaultStepBias*=0.001;
	DefaultMomentum* = 0.9;   (*momentum for gradient descent, either =0 or some small value, like 0.5; could be adapted during learning*)
	DefaultDecay* = 0.0005;(*was 0.0005*) (*decay of network weights -> leads to elimination of near-irrelevant nodes and smaller number of relevant weights*)
	DefaultEpisodes* = 10000;
	DefaultShowError* = TRUE;
	ClampValue*=1.0;
	ClampValue01*=0.1;

	EpsL*=1.11022302463E-16;


	(* convolution types following the Matlab conv2 conventions *)
	FULL=0;(** return full convolution (Default) *)
	SAME=1;(** central part of the convolution with the same size as the input data *)
	VALID=2; (** returns only those parts of the convolution that are computed without the padded edges *)
	CUSTOM=3;



TYPE
	IntVector* = ARRAY [ * ] OF SIGNED32;
	Datatype* = MatrixBase.Datatype;
	Vector* = MatrixBase.Vector;
	Matrix* = MatrixBase.Matrix;
	Dataset*= ARRAY [?] OF Datatype;
	Function*= PROCEDURE(x:Datatype):Datatype;
	Function2*=PROCEDURE(x,delta:Datatype):Datatype;
	FilterProc*=PROCEDURE{DELEGATE}(CONST data: Dataset; CONST filter:Dataset; boundary: SIGNED32): Dataset;

OPERATOR "SUM"*(CONST m:Dataset; dimension:SIGNED32):Dataset;
VAR len:IntVector; i:SIGNED32;
BEGIN
	ASSERT(dimension<DIM(m));
	NEW(len, DIM(m)-1);
	FOR i:=0 TO dimension-1 DO
		len[i]:=LEN(m,i);
	END;
	FOR i:=dimension TO LEN(len,0)-1 DO
		len[i]:=LEN(m,i+1);
	END;
	IF LEN(RESULT)#len THEN NEW(RESULT,len) END;
	RESULT:=0;
	CASE dimension OF
	|0: FOR i:=0 TO LEN(m,0)-1 DO RESULT:=RESULT+m[i,?] END;
	|1:FOR i:=0 TO LEN(m,1)-1 DO RESULT:=RESULT+m[..,i,?] END;
	|2:FOR i:=0 TO LEN(m,2)-1 DO RESULT:=RESULT+m[..,..,i,?] END;
	|3:FOR i:=0 TO LEN(m,3)-1 DO RESULT:=RESULT+m[..,..,..,i,?] END;
	ELSE HALT(200);
	END;
	RETURN RESULT
END "SUM";

OPERATOR "SUM"*(CONST m:Dataset; CONST dimensions: IntVector):Dataset;
VAR len:IntVector; i:SIGNED32;
BEGIN
	ASSERT(DIM(m)=3, 200); (*implementation limitation*)
	i:=DIM(m)-LEN(dimensions,0);
	len:=LEN(m);
	IF dimensions=[0] THEN IF (DIM(RESULT)#2) OR (LEN(RESULT)#LEN(m)[1..2]) THEN NEW(RESULT, LEN(m)[1..2]) END;
	ELSIF dimensions=[1] THEN IF (DIM(RESULT)#2) OR (LEN(RESULT,0)#LEN(m,0)) OR (LEN(RESULT,1)#LEN(m,2))  THEN NEW(RESULT, LEN(m,0), LEN(m,2)); END;
	ELSIF dimensions=[2] THEN IF (DIM(RESULT)#2) OR (LEN(RESULT)#LEN(m)[0..1]) THEN NEW(RESULT, LEN(m)[0..1]) END;
	ELSIF dimensions=[0,1] THEN IF (DIM(RESULT)#1) OR (LEN(RESULT,0)#LEN(m,2)) THEN NEW(RESULT, LEN(m,2)) END;
	ELSIF dimensions=[0,2] THEN IF (DIM(RESULT)#1) OR (LEN(RESULT,0)#LEN(m,1)) THEN NEW(RESULT, LEN(m,1)) END;
	ELSIF dimensions=[1,2] THEN IF (DIM(RESULT)#1) OR (LEN(RESULT,0)#LEN(m,0)) THEN NEW(RESULT, LEN(m,0)) END;
	ELSIF dimensions=[0,1,2] THEN HALT(201);
	ELSE HALT(202)
	END;

	RESULT:=0;
	IF dimensions=[0] THEN HALT(203); FOR i:=0 TO LEN(m,0)-1 DO RESULT:=RESULT+m[i] END;
	ELSIF dimensions=[1] THEN HALT(204);FOR i:=0 TO LEN(m,1)-1 DO RESULT:=RESULT+m[..,i] END;
	ELSIF dimensions=[2] THEN HALT(205); FOR i:=0 TO LEN(m,2)-1 DO RESULT:=RESULT+m[..,..,i] END;

	ELSIF dimensions=[0,1] THEN FOR i:=0 TO LEN(m,2)-1 DO RESULT[i]:=SUM(m[..,..,i]) END; (*!to do: this still involves temporary array allocation - avoid*)
	ELSIF dimensions=[0,2] THEN FOR i:=0 TO LEN(m,1)-1 DO RESULT[i]:=SUM(m[..,i,..]) END;
	ELSIF dimensions=[1,2] THEN FOR i:=0 TO LEN(m,0)-1 DO RESULT[i]:=SUM(m[i,..,..]) END;

	ELSIF dimensions=[0,1,2] THEN RESULT:=[SUM(m)]; HALT(206); (* what is a zero-dimensional array ?*)
	ELSE HALT(207)
	END;
	RETURN RESULT
END "SUM";

PROCEDURE PROD*(CONST v: IntVector): SIGNED32;
VAR res: SIGNED32; i:SIGNED32;
BEGIN
	res:=1;
	FOR i:=0 TO LEN(v,0)-1 DO
		res:=res*v[i]
	END;
	RETURN res;
END PROD;

PROCEDURE AddToRows(CONST l:Matrix; CONST r: Vector):Matrix;
VAR i:SIGNED32;
BEGIN
	IF (DIM(l)#DIM(RESULT)) OR (LEN(l)#LEN(RESULT)) THEN NEW (RESULT, LEN(l)) END;
	FOR i:=0 TO LEN(l,0)-1 DO RESULT [i,*]:=r END;
	RETURN RESULT
END AddToRows;

PROCEDURE AddToCols(CONST l:Matrix; CONST r: Vector):Matrix;
VAR i:SIGNED32;
BEGIN
	IF (DIM(l)#DIM(RESULT)) OR (LEN(l)#LEN(RESULT)) THEN NEW (RESULT, LEN(l)) END;
	FOR i:=0 TO LEN(l,1)-1 DO RESULT [*,i]:=r END;
	RETURN RESULT
END AddToCols;

PROCEDURE Linear*(x:Datatype):Datatype;
BEGIN
	RETURN x
END Linear;

PROCEDURE LinearDerivative*(x:Datatype):Datatype;
BEGIN
	RETURN 1
END LinearDerivative;

PROCEDURE LinearInverse*(y:Datatype):Datatype;
BEGIN
	RETURN y
END LinearInverse;

(*https://en.wikipedia.org/wiki/Rectifier_(neural_networks)*)(* Nair & Hinton, 2010. *)(*! it is not clear from the Hinton paper, which variance is used; it seems from their graph that they only use positives ?*)
PROCEDURE RectifiedLinear*(x:Datatype):Datatype;
CONST leak=0;
BEGIN
	RETURN MAX(x,leak);
END RectifiedLinear;

PROCEDURE RectifiedLinearDerivative*(x:Datatype):Datatype;
(*? CONST leak= ?; *)
BEGIN
	IF x>0 THEN RETURN 1 ELSE RETURN 0 END; (*!? or <=0 ?*)
END RectifiedLinearDerivative;

PROCEDURE RectifiedLinearInverse*(y:Datatype):Datatype;
CONST leak=0;
BEGIN
	RETURN y
END RectifiedLinearInverse;

PROCEDURE SoftPlus*(x: Datatype): Datatype; (*derivative is exactly the logistic function.*)
BEGIN
	RETURN Mathe.ln(1+Mathe.exp(x));
END SoftPlus;

(*https://en.wikipedia.org/wiki/Rectifier_(neural_networks)*)(*Nair & Hinton, 2010*)
PROCEDURE NoisyReLu*(x:Datatype):Datatype;
(*CONST variance=1; *)
BEGIN
	RETURN MAX(x, rand.Gaussian()); (* assuming that rand.Gaussian has variance=1, to be checked*)
END NoisyReLu;

PROCEDURE LeakyReLu*(x:Datatype):Datatype;
CONST leak=0.01;
BEGIN
	RETURN MAX(x, leak*x );
END LeakyReLu;

PROCEDURE LeakyReLuDerivative*(x:Datatype):Datatype;
CONST leak=0.01;
BEGIN
	IF x>0 THEN RETURN 1 ELSE RETURN leak END;
END LeakyReLuDerivative;

PROCEDURE Tanh*( x: Datatype): Datatype;
BEGIN
	RETURN PMathSSE.tanh(SHORT(x))
END Tanh;

PROCEDURE TanhDerivative*( y: Datatype ): Datatype;
VAR a: Datatype;
BEGIN
	a:=PMathSSE.tanh(SHORT(y));
	RETURN 1- a*a
END TanhDerivative;

PROCEDURE TanhInverse*( y: Datatype): Datatype;
VAR x:Datatype;
BEGIN
	ASSERT((-1<=y)&(y<=1), 200);
	IF 1-y=0 THEN RETURN MAX(Datatype)
	ELSE x:=(1+y)/(1-y); RETURN 0.5*Mathe.ln(x);
	END;
END TanhInverse;

PROCEDURE Exp(x:Datatype):Datatype;
BEGIN
	RETURN Mathe.exp(x)
END Exp;

PROCEDURE Logistic*( x: Datatype ): Datatype;  (* logistic function as nonlinear element for unit response *)
BEGIN
	(*RETURN PMath.logisticL(x)*)
	RETURN PMathSSE.logisticL(x)
END Logistic;

PROCEDURE LogisticDerivative*( x: Datatype ): Datatype;  (* logistic function as nonlinear element for unit response *)
BEGIN
	RETURN (1 - x) * x
END LogisticDerivative;

PROCEDURE ScaledSigmoid*(x:Datatype):Datatype; (* according to LeCun et al, these are well working parameters based on tanh(), if inputs/outputs are scaled in a suited manner  *)
CONST scaley=1.7159;
		scalex=2/3;
BEGIN
	RETURN  scaley * PMathSSE.tanh(SHORT(scalex * x))
END ScaledSigmoid;

PROCEDURE ScaledSigmoidDerivative*(x:Datatype):Datatype;
CONST scaley=1.7159;
		scalex=2/3;
VAR a: Datatype;
BEGIN
	a:= PMathSSE.tanh(SHORT(scalex * x));
	RETURN scaley * (1- a*a)
END ScaledSigmoidDerivative;

PROCEDURE ScaledSigmoidInverse*(y:Datatype):Datatype;
CONST scaley=1.7159;
		scalex=2/3;
BEGIN
	RETURN 1/scalex * TanhInverse(y/scaley);
END ScaledSigmoidInverse;

(*!to do: ReduceAbsMax() ?*)
PROCEDURE ReduceMax*( CONST g: Dataset; VAR map: Util.BoolTensor ): Dataset;  (* select MAX of each 2*2 group.*)(*? note that map can contain >1 TRUEs in quad field if values are same - MAY BE problematic on backprop ?*)
VAR len: IntVector; i:SIGNED32;
	BEGIN
		IF DIM(g)=2 THEN
			len:=LEN(g); len:= (len+1) DIV 2;
			IF LEN( RESULT) # len THEN NEW( RESULT, len) END;
			IF LEN(map)#LEN(g) THEN NEW(map,LEN(g)) END;
			RESULT[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1] := g[.. BY 2, .. BY 2];
			RESULT[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1] := MAX(RESULT[ .. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1], g[ 1.. BY 2, .. BY 2]);
			RESULT[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1] := MAX(RESULT[ .. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1], g[ .. BY 2, 1.. BY 2]);
			RESULT[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1] := MAX(RESULT[ .. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1], g[ 1.. BY 2, 1.. BY 2]);
			map[.. BY 2, .. BY 2] := g[.. BY 2, .. BY 2] .= RESULT[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1];
			map[1.. BY 2, .. BY 2] := g[1.. BY 2, .. BY 2] .=RESULT[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1];
			map[.. BY 2, 1.. BY 2] := g[.. BY 2, 1.. BY 2] .= RESULT[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1];
			map[1.. BY 2, 1.. BY 2] := g[1.. BY 2, 1.. BY 2] .= RESULT[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1];
		ELSIF DIM(g)=3 THEN
			len:=LEN(g); len[1..2]:= (len[1..2]+1) DIV 2;
			IF LEN( RESULT) # len THEN NEW( RESULT, len) END;
			IF LEN(map)#LEN(g) THEN NEW(map,LEN(g)) END;
			FOR i:=0 TO LEN(g,0)-1 DO (* currently: in-plane MAX; might be extended to 3rd dimension eventually *)
				RESULT[i,.. (LEN( g, 1 ) + 1) DIV 2 - 1, .. (LEN( g, 2 ) + 1) DIV 2 - 1] := g[i,.. BY 2, .. BY 2];
				RESULT[i,.. (LEN( g, 1 ) + 0) DIV 2 - 1, .. (LEN( g, 2 ) + 1) DIV 2 - 1] := MAX(RESULT[i, .. (LEN( g, 1 ) + 0) DIV 2 - 1, .. (LEN( g, 2 ) + 1) DIV 2 - 1], g[i, 1.. BY 2, .. BY 2]);
				RESULT[i,.. (LEN( g, 1 ) + 1) DIV 2 - 1, .. (LEN( g, 2 ) + 0) DIV 2 - 1] := MAX(RESULT[i, .. (LEN( g, 1 ) + 1) DIV 2 - 1, .. (LEN( g, 2 ) + 0) DIV 2 - 1], g[i, .. BY 2, 1.. BY 2]);
				RESULT[i,.. (LEN( g, 1 ) + 0) DIV 2 - 1, .. (LEN( g, 2 ) + 0) DIV 2 - 1] := MAX(RESULT[i, .. (LEN( g, 1 ) + 0) DIV 2 - 1, .. (LEN( g, 2 ) + 0) DIV 2 - 1], g[i, 1.. BY 2, 1.. BY 2]);
			END;
			map[..,.. BY 2, .. BY 2] := g[..,.. BY 2, .. BY 2] .= RESULT[..,.. (LEN( g, 1 ) + 1) DIV 2 - 1, .. (LEN( g, 2 ) + 1) DIV 2 - 1];
			map[..,1.. BY 2, .. BY 2] := g[..,1.. BY 2, .. BY 2] .=RESULT[..,.. (LEN( g, 1 ) + 0) DIV 2 - 1, .. (LEN( g, 2 ) + 1) DIV 2 - 1];
			map[..,.. BY 2, 1.. BY 2] := g[..,.. BY 2, 1.. BY 2] .= RESULT[..,.. (LEN( g, 1 ) + 1) DIV 2 - 1, .. (LEN( g, 2 ) + 0) DIV 2 - 1];
			map[..,1.. BY 2, 1.. BY 2] := g[..,1.. BY 2, 1.. BY 2] .= RESULT[..,.. (LEN( g, 1 ) + 0) DIV 2 - 1, .. (LEN( g, 2 ) + 0) DIV 2 - 1];
		END;

		RETURN RESULT
	END ReduceMax;


PROCEDURE ExpandMax*( CONST g: Dataset; VAR map: Util.BoolTensor ): Dataset;  (* select MAX of each 2*2 group.*)(*? note that map can contain >1 TRUEs in quad field if values are same*)
	BEGIN
		(*precondition: correct dimensions*)
		IF DIM(g)=2 THEN
		IF LEN(RESULT)#LEN(map) THEN NEW(RESULT,LEN(map)) END;
			RESULT[.. BY 2, .. BY 2] := Util.ApplyMask(g, map[.. BY 1, .. BY 2], 0);
			RESULT[1.. BY 2, .. BY 2] := Util.ApplyMask(g, map[1.. BY 2, .. BY 2], 0);
			RESULT[.. BY 2, 1.. BY 2] := Util.ApplyMask(g, map[.. BY 2, 1.. BY 2], 0);
			RESULT[1.. BY 2, 1.. BY 2] := Util.ApplyMask(g, map[1.. BY 2, 1.. BY 2], 0);
		ELSIF DIM(g)=3 THEN
			IF LEN(RESULT)#LEN(map) THEN NEW(RESULT,LEN(map)) END;
			RESULT[..,.. BY 2, .. BY 2] := Util.ApplyMask(g, map[..,.. BY 1, .. BY 2], 0);
			RESULT[..,1.. BY 2, .. BY 2] := Util.ApplyMask(g, map[..,1.. BY 2, .. BY 2], 0);
			RESULT[..,.. BY 2, 1.. BY 2] := Util.ApplyMask(g, map[..,.. BY 2, 1.. BY 2], 0);
			RESULT[..,1.. BY 2, 1.. BY 2] := Util.ApplyMask(g, map[..,1.. BY 2, 1.. BY 2], 0);
		END;
		RETURN RESULT
	END ExpandMax;

PROCEDURE Rot180(CONST m:Dataset):Dataset;(* tbd: accelerated in library*)
VAR j,i:SIGNED32; x:Vector; x0: Datatype;
BEGIN
	IF LEN(RESULT) # LEN(m) THEN NEW(RESULT, LEN(m)) END;
	CASE DIM(m) OF (*!implementation limitation*)
	|2:
		FOR j:=0 TO (LEN(m,0)+1) DIV 2-1 DO
			FOR i:=0 TO LEN(m,1) -1 DO
				x0:=m[j,i];
				RESULT[j,i]:=m[LEN(m,0)-j-1, LEN(m,1)-i-1];
				RESULT[LEN(m,0)-j-1, LEN(m,1)-i-1]:=x0;
			END;
		END;
	|3:
		FOR j:=0 TO (LEN(m,1)+1) DIV 2-1 DO
			FOR i:=0 TO LEN(m,2) -1 DO
				x:=m[..,j,i];
				RESULT[..,j,i]:=m[..,LEN(m,1)-j-1, LEN(m,2)-i-1];
				RESULT[..,LEN(m,1)-j-1, LEN(m,2)-i-1]:=x;
			END;
		END;
	ELSE HALT(200)
	END;
	RETURN RESULT
END Rot180;
(*
PROCEDURE Rot180(CONST m:Dataset):Dataset;(* tbd: accelerated in library*)
VAR j,i:SIGNED32; x:Vector; x0: Datatype;
BEGIN
	IF LEN(RESULT) # LEN(m) THEN NEW(RESULT, LEN(m)) END;
	CASE DIM(m) OF (*!implementation limitation*)
	|2:
		RESULT:=m[.. BY -1, .. BY -1];
	|3:
		RESULT:=[.., .. BY -1, .. BY -1]
	ELSE HALT(200)
	END;
	RETURN RESULT
END Rot180;*)


PROCEDURE RoundBinary*(x:Datatype):Datatype;
	BEGIN
		IF x>=0.5 THEN RETURN 1
		ELSE RETURN 0
		END;
END RoundBinary;

PROCEDURE DefaultNormalization*(VAR input,output:Dataset; function: Function);
VAR maxI,minI,meanI, maxO,minO,meanO, rangeI, rangeO: Datatype;
BEGIN
	IF function=ScaledSigmoid THEN (* to range <0..1>*)
		minI:=MIN(input); minO:=MIN(output);
		maxI:=MAX(input); maxO:=MAX(output);
		meanI:=StatisticsBase.Mean(input); meanO:=StatisticsBase.Mean(output);
		rangeI:=maxI-minI; rangeO:=maxO-minO;
		input:=input-minI;
		input:=1/rangeI*input;
		output:=output-minO;
		output:=1/rangeO*output;

	ELSIF function=RectifiedLinear THEN
	ELSIF function=Tanh THEN
	ELSIF function=Logistic THEN
	ELSIF function=Linear THEN
	ELSE HALT(200)
	END;
END DefaultNormalization;


PROCEDURE TruncateStochastic*(x:Datatype):Datatype; (* binary result based on probability <0..1> *)
	BEGIN
		IF random.Uniform()>x THEN RETURN 0
		ELSE RETURN 1
		END;
END TruncateStochastic;

PROCEDURE ResizeDataset(VAR dataset:Dataset; CONST newLen:IntVector);
VAR tmp: Dataset; len: IntVector;
BEGIN
	len:=LEN(dataset);
	IF DIM(dataset)=2 THEN
		tmp:=dataset;
		NEW(dataset, newLen);
		dataset[..MIN(len[0],newLen[0])-1, ..MIN(len[1],newLen[1])-1] :=tmp[..MIN(len[0],newLen[0])-1, ..MIN(len[1],newLen[1])-1];
	ELSIF DIM(dataset)=3 THEN
		tmp:=dataset;
		NEW(dataset, newLen);
		dataset[..MIN(len[0],newLen[0])-1, ..MIN(len[1],newLen[1])-1, ..MIN(len[2],newLen[2])-1]:=tmp[..MIN(len[0],newLen[0])-1, ..MIN(len[1],newLen[1])-1, ..MIN(len[2],newLen[2])-1];
	END;
END ResizeDataset;

PROCEDURE Diagonal(VAR data:Dataset);
VAR i,j:SIGNED32;
BEGIN
	data:=0;
	IF DIM(data)=2 THEN
		IF LEN(data,DIM(data)-2) > LEN(data,DIM(data)-1) THEN
			FOR i:=0 TO LEN(data,DIM(data)-2) -1 DO
				j:= i * LEN(data,DIM(data)-1) DIV LEN(data,DIM(data)-2);
				data[i,j]:=1;
			END;
		ELSE
			FOR i:=0 TO LEN(data,DIM(data)-1) -1 DO
				j:= i * LEN(data,DIM(data)-2) DIV LEN(data,DIM(data)-1);
				data[j,i]:=1;
			END;
		END;
	ELSE
		IF LEN(data,DIM(data)-2) > LEN(data,DIM(data)-1) THEN
			FOR i:=0 TO LEN(data,DIM(data)-2) -1 DO
				j:= i * LEN(data,DIM(data)-1) DIV LEN(data,DIM(data)-2);
				data[?,i,j]:=1;
			END;
		ELSE
			FOR i:=0 TO LEN(data,DIM(data)-1) -1 DO
				j:= i * LEN(data,DIM(data)-2) DIV LEN(data,DIM(data)-1);
				data[?,j,i]:=1;
			END;
		END;
	END;
END Diagonal;

PROCEDURE GenTestFilter(CONST size:IntVector):Dataset;
VAR j,i:SIGNED32;
BEGIN
	NEW(RESULT,size);
	FOR j:=30 TO 39 DO
		FOR i:= 30 TO 39 DO
			IF j<i THEN RESULT[j,i]:=1.0 END;
		END;
	END;
	RETURN RESULT
END GenTestFilter;

PROCEDURE GetFunction(CONST s:ARRAY OF CHAR): Function;
BEGIN
	IF s="ScaledSigmoid" THEN RETURN ScaledSigmoid
	ELSIF s="ScaledSigmoidDerivative" THEN RETURN ScaledSigmoidDerivative
	ELSIF s="Linear" THEN RETURN Linear
	ELSIF s="LinearDerivative" THEN RETURN LinearDerivative
	ELSIF s="RectifiedLinear" THEN RETURN RectifiedLinear
	ELSIF s="RectifiedLinearDerivative" THEN RETURN RectifiedLinearDerivative
	(*! to do: more functions to implement*)
	ELSIF s="NIL" THEN RETURN NIL
	ELSE HALT(200)
	END;
END GetFunction;

PROCEDURE WriteFunction(w:Streams.Writer; f:Function);
BEGIN
	IF f = Tanh THEN w.String("Tanh ");
	ELSIF f = TanhDerivative THEN w.String("TanhDerivative");
	ELSIF f =ScaledSigmoid THEN w.String("ScaledSigmoid ")
	ELSIF f = ScaledSigmoidDerivative THEN w.String("ScaledSigmoidDerivative ")
	ELSIF f = Linear THEN w.String("Linear ")
	ELSIF f = LinearDerivative THEN w.String("LinearDerivative ")
	ELSIF f = RectifiedLinear THEN w.String("RectifiedLinear ")
	ELSIF f = RectifiedLinearDerivative THEN w.String("RectifiedLinearDerivative ")
	ELSIF f = LeakyReLu THEN w.String("LeakyReLu ");
	ELSIF f = LeakyReLuDerivative THEN w.String("LeakyReLuDerivative ");
	ELSIF f = NoisyReLu THEN w.String("NoisyReLu ");
	ELSIF f = Logistic THEN w.String("Logistic ");
	ELSIF f = LogisticDerivative THEN w.String("LogisticDerivative ");
	(*! to do: more functions to implement*)
	ELSE HALT(200)
	END;
END WriteFunction;

PROCEDURE StoreLayer(w:Streams.Writer; l:Layer);
VAR lc: ConvLayer; lf: FullLayerM1M;
BEGIN
	w.String("MLConvNet3D.GenLayer ");
	IF l IS ConvLayer THEN
		lc:=l(ConvLayer);
		IF lc IS ConvLayerMMM THEN w.String("ConvLayerMMM ");
		ELSIF lc IS ConvLayerMM1 THEN w.String("ConvLayerMM1 ");
		ELSIF lc IS ConvLayerM1M THEN w.String("ConvLayerM1M ");
		ELSIF lc IS ConvLayerMNM THEN w.String("ConvLayerMNM ");
		ELSIF lc IS ConvLayerMNMP THEN w.String("ConvLayerMNMP ");
		ELSIF lc IS ConvLayerMNMN THEN w.String("ConvLayerMNMN ");
		ELSE HALT(201);
		END;
		WriteFunction(w, lc.NonLinear);
		WriteFunction(w, lc.NonLinearDerivative);
		Util.StoreLR(w, lc.w);
		w.RawLReal(lc.bias);
		w.RawLReal(lc.momentum);
		w.RawLReal(lc.step);
		w.RawLReal(lc.decay);
	ELSIF l IS FullLayerM1M THEN
		lf:=l(FullLayerM1M);
		w.String("FullLayerM1M ");
		WriteFunction(w, lf.NonLinear);
		WriteFunction(w, lf.NonLinearDerivative);
		Util.StoreLR(w, lf.w);
		w.RawLReal(lf.bias);
		w.RawLReal(lf.momentum);
		w.RawLReal(lf.step);
		w.RawLReal(lf.decay);
	ELSIF l IS MaxPoolLayer THEN w.String("MaxPoolLayer ");
	ELSIF l IS NormalizeLayer THEN w.String("NormalizeLayer ");
	ELSE HALT(203)
	END;
	w.Ln;
	w.Update;
END StoreLayer;

(* generate layer from a stream. in the stream, this procedure can be preceded by "MLConvNet3D.GenLayer "*)
PROCEDURE GenLayer*(r:Streams.Reader):Layer;
VAR
	type, function, derivative,show,s: ARRAY 32 OF CHAR;
	lp:MaxPoolLayer;
	lc: ConvLayer;
	lmmm: ConvLayerMMM;
	lmm1:ConvLayerMM1;
	lm1m: ConvLayerM1M;
	lmnm: ConvLayerMNM;
	lmnmp:ConvLayerMNMP;
	lmnmn:ConvLayerMNMN;
	ln: NormalizeLayer;
	lf: FullLayerM1M;
	lfn: FullLayerMNMN;
	l:Layer;
	filtersize, inputSize,outputSize: ARRAY[?] OF SIGNED32;
	NonLinear, Derivative: PROCEDURE (x:Datatype):Datatype;
	version:SIGNED32;
BEGIN
	IF ~r.GetInteger(version,FALSE) THEN HALT(200) END;
	ASSERT (version<MAX(SIGNED32)); (*! to do*)
	IF ~r.GetString(type) THEN HALT(201) END;
	IF type="MaxPoolLayer" THEN
	ELSIF type="NormalizeLayer" THEN
	ELSIF Strings.Pos("ConvLayerM", type)=0 THEN
		filtersize:=Util.LoadLInt(r);
		IF r.GetString(function) & r.GetString(derivative) THEN
			NonLinear:=GetFunction(function);
			Derivative:=GetFunction(derivative);
			IF ~r.GetString (show) THEN HALT(202)	END;
			IF type="ConvLayerMMM" THEN NEW(lmmm,filtersize, NonLinear, Derivative, show="TRUE"); l:=lmmm; lc:=lmmm;
			ELSIF type="ConvLayerMM1" THEN NEW(lmm1,filtersize, NonLinear, Derivative, show="TRUE"); l:=lmm1; lc:=lmm1;
			ELSIF type="ConvLayerM1M" THEN NEW(lm1m,filtersize, NonLinear, Derivative, show="TRUE"); l:=lm1m; lc:=lm1m;
			ELSIF type="ConvLayerMNM" THEN NEW(lmnm,filtersize, NonLinear, Derivative, show="TRUE"); l:=lmnm; lc:=lmnm;
			ELSE HALT(204);
			END;
			lc.w:=Util.LoadLR(r);
			r.RawLReal(lc.bias);
			r.RawLReal(lc.momentum);
			r.RawLReal(lc.step);
			r.RawLReal(lc.decay);
		ELSE HALT(203)
		END;
	ELSIF type="FullLayerM1M" THEN
		inputSize:=Util.LoadLInt(r);
		outputSize:=Util.LoadLInt(r);
		NonLinear:=GetFunction(function);
		Derivative:=GetFunction(derivative);
		IF ~r.GetString (show) THEN HALT(206) END;
		NEW(lf, inputSize, outputSize, NonLinear, Derivative, show="TRUE"); l:=lf;
		lf.w:=Util.LoadLR(r);
		r.RawLReal(lf.bias);
		r.RawLReal(lf.momentum);
		r.RawLReal(lf.step);
		r.RawLReal(lf.decay);
	ELSE HALT(204)
	END;
	r.Ln(s);
END GenLayer;


TYPE SoftMax= OBJECT
		VAR tmp:Dataset; sum:Datatype;
		PROCEDURE SoftMax(CONST d:Dataset):Dataset;
		BEGIN
			IF (DIM(tmp)#DIM(d)) OR (LEN(tmp)#LEN(d)) THEN NEW(tmp, LEN(d)) END;
			IF (DIM(RESULT)#DIM(d)) OR (LEN(RESULT)#LEN(d)) THEN NEW(RESULT, LEN(d)) END;
			tmp:=ALL(d, Exp);
			sum:=SUM(tmp);
			RETURN tmp/sum
		END SoftMax;

		PROCEDURE Derivative(CONST d:Dataset):Dataset;
		BEGIN
			(*see https://stackoverflow.com/questions/37790990/derivative-of-a-softmax-function-explanation?rq=1
			and
			https://math.stackexchange.com/questions/945871/derivative-of-softmax-loss-function*)
		END Derivative;
	END SoftMax;


TYPE
	Layer* = OBJECT
		VAR
			prior,next*: Layer;
			NonLinear*, NonLinearDerivative*, InverseNonLinear*: Function;
			w*, x*, y*, delta*, dIn*, rotDelta, dw, dwOld, goodW*, oldGoodW, invW, invZ, reconstruction: Dataset;
			drop*: Util.IntTensor;
			stochastic*: BOOLEAN;
			show*, clamp*, timing*, validInverse:BOOLEAN;
			bias*: Datatype; (*todo: this should be a vector!*)
			step*, stepBias*, momentum*, decay*, dropout*,
			slow*, (* slow down for a time by scaling step temporarily*)
			goodStep, goodBias, goodMomentum, oldGoodStep, oldGoodBias, oldGoodMomentum,
			maxWeight,minWeight: Datatype;
			window: WMMatrix.Window;
			growStep*:SIGNED32; (* enable dynamic change of dimension of layer & layer.next; currently only implemented for FullLayerM1M *)
			(*random:Util.RandomGenerator;*) (* consider own random generator per network, to avoid concurrency issues when several nets are run*)
			tProp*, tBackprop*: SIGNED32;
			timer*: Kernel.MilliTimer;


		(* data propagation *)
		PROCEDURE Propagate*(CONST in: Dataset) ; (* returns activations of this*)
		END Propagate;

		(* error backpropagation *)
		PROCEDURE Backprop*(CONST deltaNext:Dataset);
		END Backprop;

		PROCEDURE Store(writer: Streams.Writer);
		BEGIN
			Util.StoreLR(writer,w);
			Util.StoreLR(writer,[bias]); (*todo: bias is supposed to be a vector everywhere*)
		END Store;

		PROCEDURE Load(reader: Streams.Reader);
		VAR
			biasAsVec: Vector;
		BEGIN
				w:=Util.LoadLR(reader);
				biasAsVec:=Util.LoadLR(reader);
				bias:=biasAsVec[0];
		END Load;

				(* Set/GetGoodParameters allows to reconstruct situation before parameter explosion *)
		PROCEDURE MemorizeGoodParameters;
		BEGIN
			oldGoodW:=goodW; goodW:= w;
			oldGoodStep:=goodStep; goodStep:=step;
			oldGoodBias:=goodBias; goodBias:=bias;
			oldGoodMomentum:=goodMomentum; goodMomentum:=momentum;
			IF oldGoodStep=0 THEN (* detect first occurrance*)(*!expensive multi testing, could be implemented much leaner*)
				oldGoodW:=goodW;
				oldGoodStep:=goodStep;
				oldGoodBias:=goodBias;
				oldGoodMomentum:=goodMomentum
			END;
		END MemorizeGoodParameters;

		PROCEDURE Rollback(n:SIGNED32); (* Roll parameters back by 2 good epochs*)
		BEGIN
			IF n=1 THEN
				w:=goodW;
				IF DIM(dw)>0 THEN dw:=0; END;
				step:=goodStep;
				bias:=goodBias;
				momentum:=goodMomentum;
			ELSIF n=2 THEN
				w:=oldGoodW;
				IF DIM(dw)>0 THEN dw:=0; END;
				step:=oldGoodStep;
				bias:=oldGoodBias;
				momentum:=oldGoodMomentum;
			ELSE HALT(200)
			END;
		END Rollback;

		(*create a binary (currently integer...) map for weights. Only weights*)
		PROCEDURE NewDropout*(dropoutFactor: Datatype); (*!implementation limitation - currently only done for fully connected layer type*)
		BEGIN
			dropout:=dropoutFactor;
			IF dropoutFactor>0 THEN drop:=random.Binary(LEN(dw),dropout) END;
		END NewDropout;

		(* generate image from activation*)
		PROCEDURE Reconstruct*(CONST activation: Dataset);
			(*involves solution of AX=B for fully connected layers,
			and deconvolution for convolutional layers*)
		END Reconstruct;

		PROCEDURE ChangeSize*(d: SIGNED32); (* allow dynamic modification of layer structure*)
		END ChangeSize;

		PROCEDURE ChangeDepth*; (* allow dynamic modification of layer structure*)
		END ChangeDepth;

		PROCEDURE InsertLayer*; (* allow dynamic modification of layer structure*)
		END InsertLayer;
	END Layer;

TYPE PoolLayer*= OBJECT(Layer)
		PROCEDURE Downsample(CONST in:Dataset):Dataset;
		END Downsample;

		PROCEDURE Upsample(CONST delta:Dataset):Dataset;
		END Upsample;
	END PoolLayer;

TYPE  MaxPoolLayer*= OBJECT(PoolLayer)
		VAR xSmall, z: Dataset;
			map: Util.BoolTensor;
			beta:Datatype;
			wp: WMMatrix.Window;

		PROCEDURE &New*;
		BEGIN
			beta:= 1.0;
			bias:= 0.0;
			show:=TRUE;
		END New;

		PROCEDURE DeltaFromDNext(CONST dNext: Dataset);
		BEGIN
			delta:=dNext;
		END DeltaFromDNext;

		PROCEDURE AdaptWeights;
		BEGIN
			(* (*from http://cogprints.org/5869/1/cnn_tutorial.pdf  - is it necessary that this layer has bias and scale ?*)
			dBias:=SUM(delta);
			dBeta:=SUM(z .* delta)
			*)
		END AdaptWeights;

		PROCEDURE Downsample(CONST x:Dataset):Dataset;
		VAR len:IntVector;
		BEGIN
			IF DIM(x)=2 THEN
				IF LEN(map)#LEN(x) THEN NEW(map, LEN(x)) END;
				len:=LEN(x); len:=(len+1) DIV 2;
			 ELSIF DIM(x)=3 THEN
				 IF LEN(map)#LEN(x) THEN NEW(map, LEN(x)) END;
				 len:=LEN(x); len[1..2]:=(len[1..2]+1) DIV 2;
			 END;
			 IF LEN(xSmall) # len THEN NEW(xSmall, len) END;
			 xSmall:=ReduceMax(x, map);
			 z:=xSmall; (*z := beta .* xSmall + bias;*)
			 RETURN z
		END Downsample;

		PROCEDURE Upsample(CONST delta:Dataset):Dataset;
		BEGIN
			RESULT:=ExpandMax(delta, map); (*? need handling bias and weights ?*)
			RETURN RESULT
		END Upsample;

		PROCEDURE Propagate*(CONST in: Dataset) ;
		BEGIN
			Kernel.SetTimer(timer,0);
			x:=in;
			y:=Downsample(x);
			IF show THEN
				IF window=NIL THEN
					IF DIM(in)=2 THEN NEW (window, y[..,..], "maxPool"); window.AddWindow; ELSE NEW(window, y[0,..,..], "maxPool") END;
				ELSE
					IF DIM(in)=2 THEN window.SetImage( y[..,..]) ELSE window.SetImage( y[0,..,..]) END;
				END;
			END;
			tProp:=tProp+Kernel.Elapsed(timer);
		END Propagate;

		PROCEDURE Backprop(CONST dNext:Dataset);
		BEGIN
			Kernel.SetTimer(timer,0);
			DeltaFromDNext(dNext);
			dIn:=Upsample(delta);
			AdaptWeights; (*!? should backpropagation of delta occur before or after weight update ??*)
			tBackprop:=tBackprop+Kernel.Elapsed(timer);
		END Backprop;
	END MaxPoolLayer;

TYPE ConvLayer*=OBJECT(Layer)
		VAR
			(*w*, *) z, (*dwOld,*) dw0, rotDw, rotW, tmp,btmp: Dataset;
			dBias: Datatype;
			size, filtersize: IntVector;
			convolver, convolver1, convolver2: EulFftwConvolve.MultiKernelConvolver2d_LR;
			window: WMStack.Window;
			ww,wdw,windowM: WMMatrix.Window;
			weightWindow, dWeightWindow: WMStack.Window;

		PROCEDURE &New*(CONST filtersize:IntVector; nonLinear, nonLinearDerivative: Function; show: BOOLEAN);
		BEGIN
			NonLinear:=nonLinear;
			NonLinearDerivative:=nonLinearDerivative;
			SELF.filtersize:=filtersize;
			SELF.show:=show;
			bias:=0;
			step:=DefaultStep;
			stepBias:=DefaultStepBias; (*!to do: how to decouple bias update from remainer ?*)
			momentum:=DefaultMomentum;
			decay:=DefaultDecay;
			slow:=1.0;
			InitWeights(filtersize);

			NEW(convolver);  IF convolver.SetOutputShape(EulFftwConvolve.Valid) THEN END;
			NEW(convolver1); IF convolver1.SetOutputShape(EulFftwConvolve.Valid) THEN  END;
			NEW(convolver2); IF  convolver2.SetOutputShape(EulFftwConvolve.Full) THEN  END;


		END New;

		PROCEDURE InitWeights(CONST filtersize: IntVector); (* see Stutz, formulae 16,17*) (* to do: more rational initializatino of weights*)
		VAR w0: Datatype;
		BEGIN
			NEW(w, filtersize);
			NEW(dw, filtersize);
			w:=Util.Random(filtersize, Util.Uniform);
			IF (NonLinear=ScaledSigmoid) OR (NonLinear=LeakyReLu) THEN
				IF LEN(filtersize,0)=2 THEN
					(*w0:=Mathe.sqrt(6)/filtersize[0] ; *)
					w0:=(*2* *) 0.3* Mathe.sqrt(6)/Mathe.sqrt(SUM(filtersize[0..1])) ;
				ELSIF LEN(filtersize,0)=3 THEN
					(*w0:=Mathe.sqrt(6)/filtersize[1] ;*)
					w0:=(*2* *) 0.3* Mathe.sqrt(6)/Mathe.sqrt(SUM(filtersize[1..2])) ;
				END;
			ELSE
				IF LEN(filtersize,0)=2 THEN
					(*w0:=(*1.1**) 2* Mathe.sqrt(6)/filtersize[0]; *)
					w0:=2* 0.3*Mathe.sqrt(6)/Mathe.sqrt(SUM(filtersize[0..1]));
				ELSIF LEN(filtersize,0)=3 THEN
					(*w0:=(*1.1**) 2* Mathe.sqrt(6)/filtersize[1] ;*)
					w0:=2* 0.3*Mathe.sqrt(6)/Mathe.sqrt(SUM(filtersize[1..2]));
				END;
			END;

			w:=w-0.5;
			w:= w0 * w; (* see Stutz, formulae 16,17*)
			IF show & (LEN(filtersize,0)=2) THEN
					NEW(ww, w, "w"); ww.maxInterpolation := WMGraphics.ScaleBox; ww.AddWindow;
					NEW(wdw, dw, "dw"); wdw.maxInterpolation := WMGraphics.ScaleBox; wdw.AddWindow;
			ELSIF show & (LEN(filtersize,0)=3) THEN
					NEW(weightWindow, w, "w",0); weightWindow.maxInterpolation := WMGraphics.ScaleBox; weightWindow.AddWindow;
					NEW(dWeightWindow, dw, "dw",0); dWeightWindow.maxInterpolation := WMGraphics.ScaleBox; dWeightWindow.AddWindow;
			END;
		END InitWeights;

		PROCEDURE Propagate(CONST x: Dataset); (* returns activations of this*)
		BEGIN
			SELF.x := ALIAS OF x;
			size:=LEN(x);
			(*default boundary conditions here, according to z := Convolve(x, w, VALID)+bias;*)
			IF convolver.SetKernels(w) THEN z:= convolver.Convolve(x); y:=z+bias; END;
			IF NonLinear#NIL THEN y := ALL(y, NonLinear); END;
			IF show THEN
				IF windowM=NIL THEN NEW(windowM, y, "conv"); windowM.AddWindow;
				ELSIF window.isVisible THEN windowM.SetImage(y);
				END;
			END;
		END Propagate;

		PROCEDURE DeltaFromError(CONST error:Dataset);
		BEGIN
			tmp:= ALL(z, NonLinearDerivative);
			delta:= error .* tmp  ; (* delta:= 2* error .* delta  ; ? *)
		END DeltaFromError;

		PROCEDURE DeltaFromDNext(CONST dNext (*, betaNext*): Dataset);
		BEGIN
			IF NonLinearDerivative#NIL THEN tmp:=ALL(z, NonLinearDerivative); delta:= tmp  .* dNext;
			ELSE delta:=dNext (*debug*)
			END;
		END DeltaFromDNext;

		(* Notes on Convolutional Neural Networks. Jake Bouvrie, 2006 *)
		PROCEDURE AdaptWeights;
		BEGIN
			dBias:=stepBias*SUM(delta)/PROD(LEN(delta));  (*!to do: decouple bias update from weight step size *)
			(*should it go here or after backprop ?*)(*?; see http://cogprints.org/5869/1/cnn_tutorial.pdf page 3;     *)
			bias := bias - dBias ; (* with or without scaling ??? see Quoc Le, tutorial 1, page 8 *)

			rotDelta:=Rot180(delta);
			IF convolver1.SetKernels(rotDelta) THEN rotDw:=convolver1.Convolve(x); dw:=Rot180(rotDw) END;

			(*IF convolver1.SetKernels(Rot180(delta)) THEN dw:=Rot180(convolver1.Convolve(x)) END;*)
			dw:=1/LEN(x,0)*step*slow*dw;

			IF momentum#0 THEN IF LEN(dw)=LEN(dwOld) THEN dw:=dw+dwOld END; dwOld:=momentum*dw END;
			IF decay#0 THEN w:=(1-step*decay) * w END;
			w:=w - dw;
			IF clamp THEN ClampWeights END;
		END AdaptWeights;

		PROCEDURE AdaptWeightsN;
		CONST stepBias=0.01;
		VAR i:SIGNED32;
		BEGIN
			(*dBias:=step/10*SUM(delta)/PROD(LEN(delta));  *)
			dBias:=stepBias * SUM(delta)/PROD(LEN(delta));
			bias:=bias-dBias;
			delta:=delta-dBias; (*??*)
			FOR i:=0 TO LEN(x,0)-1 DO
				rotDelta:=Rot180(delta[i,..,..]);
				IF convolver1.SetKernels(rotDelta) THEN rotDw:=convolver1.Convolve(x[i,..,..]);  dw[i,..,..]:=Rot180(rotDw) END;
				(*IF convolver1.SetKernels(Rot180(delta[i,..,..])) THEN dw[i,..,..]:=Rot180(convolver1.Convolve(x[i,..,..])) END; *)
			END;
			dw:=1/LEN(x,0)*step*slow*dw;
			IF momentum#0 THEN
				IF LEN(dw)=LEN(dwOld) THEN dw:=dw+dwOld END;
				dwOld:=momentum*dw
			END;
			IF decay#0 THEN w:=(1-step*decay) * w END;
			w:=w - dw;
			IF clamp THEN ClampWeights END;
			IF show THEN ShowWeights END;
		END AdaptWeightsN;

		PROCEDURE AdaptWeightsNCompact;
		(*CONST stepBias=0.01;*)
		VAR i:SIGNED32;
		BEGIN
			bias:=bias-stepBias * SUM(delta)/PROD(LEN(delta));
			FOR i:=0 TO LEN(x,0)-1 DO
				IF ~convolver1.SetKernels(Rot180(delta[i,..,..])-bias) THEN HALT(200)
				ELSE
					IF (momentum#0)  THEN
						dw[i,..,..]:=1/LEN(x,0)*step*slow*Rot180(convolver1.Convolve(x[i,..,..]))+momentum*dw;
					ELSE
						dw[i,..,..]:=1/LEN(x,0)*step*slow*Rot180(convolver1.Convolve(x[i,..,..]));
					END;
				END;
			END;
			IF (decay=0) & clamp THEN  HALT(200); (*w:=ALL(w-dw, Clamp)*)(*! does not compile*)
			ELSIF decay=0 THEN w:=w-dw
			ELSIF clamp THEN HALT(200); (*w:=ALL((1-step*decay) * w -dw, Clamp);*) (*!does not compile*)
			ELSE
				 w:=(1-step*decay) * w -dw
			END;
			IF show THEN ShowWeights END;
		END AdaptWeightsNCompact;


		PROCEDURE 	Backprop(CONST dNext:Dataset);
		BEGIN
			Kernel.SetTimer(timer,0);
			DeltaFromDNext(dNext);
			AdaptWeights;  (*? should backpropagation occur before or after weight update ?*)
			rotW:=Rot180(w);
			IF convolver2.SetKernels(rotW) THEN
				dIn:=convolver2.Convolve(delta);
			END;
			tBackprop:=tBackprop+Kernel.Elapsed(timer);
		END Backprop;

		PROCEDURE 	BackpropN(CONST dNext:Dataset);
		VAR i:SIGNED32; len: ARRAY [3] OF SIGNED32;
		BEGIN
			Kernel.SetTimer(timer,0);
			DeltaFromDNext(dNext);
			AdaptWeights;  (*? should backpropagation occur before or after weight update ?*)
			FOR i:=0 TO LEN(delta,0)-1 DO
				rotW:=Rot180(w[i,..,..]);
				IF convolver2.SetKernels(rotW) THEN
					btmp:=convolver2.Convolve(delta[i,..,..]);
					len[0]:=LEN(delta,0); len[1]:=LEN(btmp,0); len[2]:=LEN(btmp,1);
					IF (DIM(dIn)#DIM(delta)) OR (LEN(dIn)#len) THEN NEW(dIn, len) END;
					dIn[i,..,..]:=btmp[..,..]
				END;
				(*
				IF convolver2.SetKernels(Rot180(w[i,..,..])) THEN
					btmp:=convolver2.Convolve(delta[i,..,..]);
					len[0]:=LEN(delta,0); len[1]:=LEN(btmp,0); len[2]:=LEN(btmp,1);
					IF (DIM(dIn)#DIM(delta)) OR (LEN(dIn)#len) THEN NEW(dIn, len) END;
					dIn[i,..,..]:=btmp[..,..]
				END;
				*)
			END;
			tBackprop:=tBackprop+Kernel.Elapsed(timer);
		END BackpropN;

				(* generate image from activation*)
		PROCEDURE Reconstruct*(CONST activation: Dataset);
			(*involves solution of AX=B for fully connected layers,
			and deconvolution for convolutional layers*)
		END Reconstruct;

		PROCEDURE ClampWeights;
		VAR msq, sd: Datatype;
		BEGIN
			msq:= w+*w / PROD(LEN(w));
			sd:=Mathe.sqrt(msq);
			w:=MIN(w,5*sd);
			w:=MAX(w,-5*sd);
		END ClampWeights;

		PROCEDURE Clamp(x: Datatype):Datatype;
		BEGIN
			RETURN MAX(-maxWeight, MIN(x, minWeight))
		END Clamp;

		PROCEDURE ShowWeights;
		BEGIN
			IF (weightWindow#NIL) & weightWindow.isVisible THEN weightWindow.SetImage(w) END;
			IF (ww#NIL ) & ww.isVisible THEN ww.SetImage(w) END;
			IF (dWeightWindow#NIL) & dWeightWindow.isVisible THEN dWeightWindow.SetImage(dw) END;
			IF (wdw#NIL) & wdw.isVisible THEN wdw.SetImage(dw) END;
		END ShowWeights;

	END ConvLayer;

TYPE ConvLayerMMM*=OBJECT(ConvLayer) (*M input images, M filters, M outputs*)
		VAR
			vBias, dBias: Vector;

		PROCEDURE &New*(CONST filtersize:IntVector; nonLinear, nonLinearDerivative: Function; show: BOOLEAN);
		BEGIN
			New^(filtersize, nonLinear, nonLinearDerivative, show);
			NEW(vBias,filtersize[0]); vBias:=0;
			NEW(dBias, filtersize[0]); dBias:=0;
		END New;

		PROCEDURE Propagate(CONST x: Dataset); (* returns activations of this*)
		VAR i:SIGNED32;
		BEGIN
			Kernel.SetTimer(timer,0);
			ASSERT(LEN(x,0)=LEN(w,0), 200);
			SELF.x := ALIAS OF x;
			size:=LEN(x);
			size[1..2]:=LEN(x)[1..2] - LEN(w)[1..2] + 1;
			IF LEN(z)#size THEN NEW(z, size) END;
			IF LEN(y)#size THEN NEW(y, size) END;

			FOR i:=0 TO LEN(w,0)-1 DO
				IF convolver.SetKernels(w[i,..,..]) THEN
					z[i,..,..] := convolver.Convolve(x[i,..,..]);
				END; (*! to do: implement as one array operation, as soon as convolver is ready*)
			END;

			FOR i:=0 TO LEN(z,0)-1 DO
				IF NonLinear#NIL THEN y[i,..,..]:=z[i,..,..]+vBias[i]; y[i,..,..] := ALL(y[i,..,..], NonLinear); ELSE y[i,..,..]:=z[i,..,..]+vBias[i] END;
			END;
			tProp:=tProp+Kernel.Elapsed(timer);
			IF show THEN
				IF window=NIL THEN NEW(window, y, "conv",0); window.maxInterpolation := WMGraphics.ScaleBox; window.AddWindow;
				ELSE window.SetImage(y);
				END;
			END;
		END Propagate;


		(* Notes on Convolutional Neural Networks. Jake Bouvrie, 2006 *)
		PROCEDURE AdaptWeights;
		VAR i:SIGNED32;
		BEGIN
			dBias:=stepBias*SUM(delta, [1,2])/PROD(LEN(delta)[1..2]);
			vBias := vBias - dBias ; (* with or without scaling ??? see Quoc Le, tutorial 1, page 8 *)
			FOR i:=0 TO LEN(delta,0)-1 DO
				delta[i,..,..]:=delta[i,..,..]-dBias[i]; (*? this is min addition , works- is it justified to change the delta by this gradient ?*)
			END;
			FOR i:=0 TO LEN(x,0)-1 DO
				rotDelta:=Rot180(delta[i,?]);
				IF convolver1.SetKernels(rotDelta) THEN	rotDw:=convolver1.Convolve(x[i,..,..]); dw[i,?]:=Rot180(rotDw) END;
			END;
			dw:=1/LEN(x,0)*step*slow*dw;
			IF momentum#0 THEN  IF LEN(dw)=LEN(dwOld) THEN dw:=dw+dwOld END; 	dwOld:=momentum*dw END;
			IF decay#0 THEN w:=(1-step*decay) * w END;
			w:=w - dw;
			IF clamp THEN ClampWeights END;
			IF show THEN ShowWeights END;;
		END AdaptWeights;

		PROCEDURE 	Backprop(CONST dNext:Dataset);
		BEGIN
			BackpropN(dNext);
		END Backprop;

				(* generate image from activation*)
		PROCEDURE Reconstruct*(CONST activation: Dataset);
			(*involves solution of AX=B for fully connected layers,
			and deconvolution for convolutional layers*)
		END Reconstruct;

	END ConvLayerMMM;

TYPE ConvLayerMM1*=OBJECT(ConvLayer) (*M input images, M filters, 1 output; contributions of input images could be subject to learning, *)

		PROCEDURE Propagate(CONST x: Dataset);
		VAR i:SIGNED32;
		BEGIN
			Kernel.SetTimer(timer,0);
			ASSERT(LEN(x,0)=LEN(w,0), 200);
			SELF.x := ALIAS OF x;
			size:=LEN(x);
			size[1..2]:=LEN(x)[1..2] - LEN(w)[1..2] + 1;
			IF LEN(z)#size THEN NEW(z, size) END;
			FOR i:=0 TO LEN(x,0)-1 DO
				IF convolver.SetKernels(w[i,..,..]) THEN
					z[i,..,..]:= convolver.Convolve(x[i,..,..]);
				END;
			END;
			IF LEN(y)#size[1..2] THEN NEW(y,size[1..2]) END;
			y:= SUM(z, 0);
			y:=y+bias;
			IF NonLinear#NIL THEN y := ALL(y, NonLinear) END;
			tProp:=tProp+Kernel.Elapsed(timer);
			IF show THEN
				IF windowM=NIL THEN NEW(windowM, y, "conv"); windowM.maxInterpolation := WMGraphics.ScaleBox; windowM.AddWindow;
				ELSE windowM.SetImage(y);
				END;
			END;
		END Propagate;

		PROCEDURE DeltaFromDNext(CONST dNext : Dataset);
		VAR len:ARRAY [3] OF SIGNED32; i:SIGNED32;
		BEGIN
			len:=[LEN(z,0), LEN(dNext,0), LEN(dNext,1)];
			IF (DIM(delta)#LEN(len,0)) OR (LEN(delta,0)#len) THEN NEW(delta, len) END;
			FOR i:=0 TO len[0]-1 DO
				IF NonLinearDerivative#NIL THEN
					tmp:=ALL(z[i,..,..], NonLinearDerivative);
					tmp:=1/len[0] * tmp; (*!?? scaling actually of dNext that is distributed to several paths; because in Propagate, there is summed up. possibly, scaling of forward and backward paths should be handled differently ?*)
					delta[i,..,..]:= tmp  .* dNext;
				ELSE delta[i,..,..]:=1/len[0] * dNext (*debug*)
				END;
			END;
		END DeltaFromDNext;

		PROCEDURE DeltaFromDNextCompact(CONST dNext : Dataset);
		VAR len:ARRAY [3] OF SIGNED32; i:SIGNED32;
		BEGIN
			len:=[LEN(z,0), LEN(dNext,0), LEN(dNext,1)];
			IF (DIM(delta)#LEN(len,0)) OR (LEN(delta,0)#len) THEN NEW(delta, len) END;
			FOR i:=0 TO len[0]-1 DO
				IF NonLinearDerivative#NIL THEN
					delta[i,..,..]:=1/len[0] * ALL(z[i,..,..], NonLinearDerivative)  .* dNext;
	 			ELSE delta[i,..,..]:=1/len[0] * dNext (*debug*)
				END;
			END;
		END DeltaFromDNextCompact;

		(* Notes on Convolutional Neural Networks. Jake Bouvrie, 2006 *)
		PROCEDURE AdaptWeights;
		BEGIN
			AdaptWeightsN;
		END AdaptWeights;

		PROCEDURE Backprop(CONST dNext:Dataset);
		BEGIN
			BackpropN(dNext);
		END Backprop;

				(* generate image from activation*)
		PROCEDURE Reconstruct*(CONST activation: Dataset);
			(*involves solution of AX=B for fully connected layers,
			and deconvolution for convolutional layers*)
		END Reconstruct;

	END ConvLayerMM1;

TYPE ConvLayerM1M*=OBJECT(ConvLayer) (*M input images, 1 filter, M outputs*)

		PROCEDURE Propagate(CONST x: Dataset); (* returns activations of this*)
		VAR i:SIGNED32;
		BEGIN
			Kernel.SetTimer(timer,0);
			SELF.x := ALIAS OF x;
			size:=LEN(x);
			size[1..2]:=LEN(x)[1..2] - LEN(w) + 1;
			IF LEN(z)#size THEN NEW(z, size) END;
			IF LEN(y)#size THEN NEW(y, size) END;

			IF convolver.SetKernels(w) THEN
				FOR i:=0 TO LEN(x,0)-1 DO
					z[i,..,..] := convolver.Convolve(x[i,..,..]);
				END; (*! to do: implement as one array operation, as soon as convolver is ready*)
			END;

			IF NonLinear#NIL THEN y:=z+bias; y := ALL(y, NonLinear); ELSE y:=z+bias END;
			tProp:=tProp+Kernel.Elapsed(timer);
			IF show THEN
				IF window=NIL THEN NEW(window, y, "conv",0); window.maxInterpolation := WMGraphics.ScaleBox; window.AddWindow;
				ELSE window.SetImage(y);
				END;
			END;
		END Propagate;

		(* Notes on Convolutional Neural Networks. Jake Bouvrie, 2006 *)
		PROCEDURE AdaptWeights;
		VAR i:SIGNED32;
		BEGIN
			dBias:=stepBias*SUM(delta)/PROD(LEN(delta));
			bias:=bias-dBias;
			(*! to do: gain and local contrast normalization compensation, see http://davidstutz.de/wordpress/wp-content/uploads/2014/07/seminar.pdf, p 15*)
			(*! to do: enforce sparsity, see http://cogprints.org/5869/1/cnn_tutorial.pdf page 5 *)

			dw:=0;
			FOR i:=0 TO LEN(x,0)-1 DO
				rotDelta:=Rot180(delta[i,..,..]);
				IF convolver1.SetKernels(rotDelta) THEN
					rotDw:=convolver1.Convolve(x[i,..,..]);
					dw0:=Rot180(rotDw);
					dw:=dw+dw0;
				END;
			END;
			dw:=1/LEN(x,0)*step*slow*dw;
			IF momentum#0 THEN
				IF LEN(dw)=LEN(dwOld) THEN dw:=dw+dwOld END;
			 	dwOld:=momentum*dw
			 END;
			IF decay#0 THEN w:=(1-step*decay) * w END;
			w:=w - dw;
			IF clamp THEN ClampWeights END;
			IF show THEN ShowWeights END;
		END AdaptWeights;

		PROCEDURE 	Backprop(CONST dNext:Dataset);
		VAR i:SIGNED32; len: ARRAY [3] OF SIGNED32;
		BEGIN
			Kernel.SetTimer(timer,0);
			DeltaFromDNext(dNext);
			AdaptWeights;  (*? should backpropagation occur before or after weight update ?*)
			FOR i:=0 TO LEN(delta,0)-1 DO
				rotW:=Rot180(w[..,..]);
				IF convolver2.SetKernels(rotW) THEN (*? beta, bias ?*)
					btmp:=convolver2.Convolve(delta[i,..,..]);
					len[0]:=LEN(delta,0); len[1]:=LEN(btmp,0); len[2]:=LEN(btmp,1);
					IF (DIM(dIn)#DIM(delta)) OR (LEN(dIn)#len) THEN NEW(dIn, len) END;
					dIn[i,..,..]:=btmp[..,..]
				END;
			END;
			tBackprop:=tBackprop+Kernel.Elapsed(timer);
		END Backprop;

				(* generate image from activation*)
		PROCEDURE Reconstruct*(CONST activation: Dataset);
			(*involves solution of AX=B for fully connected layers,
			and deconvolution for convolutional layers*)
		END Reconstruct;
END ConvLayerM1M;

TYPE ConvLayerMNM*=OBJECT(ConvLayer);(*  [M,N] input images, N filters, M output images*)
	VAR nn1: ConvLayerMM1;
		lenX, lenY: IntVector;

	PROCEDURE &New*(CONST filtersize:IntVector; nonLinear, nonLinearDerivative: Function; show: BOOLEAN); (*filtersize is [w,h]*)
	BEGIN
		ASSERT(LEN(filtersize,0)=3);
		NonLinear:=nonLinear;
		NonLinearDerivative:=nonLinearDerivative;
		SELF.filtersize:=filtersize;
		SELF.show:=show;
		bias:=0;
		step:=DefaultStep;
		stepBias:=DefaultStepBias;
		decay:=DefaultDecay;
		slow:=1.0;
		NEW(nn1,filtersize, nonLinear, nonLinearDerivative, show);
	END New;

	PROCEDURE Propagate*(CONST x: Dataset);
	VAR m:SIGNED32;
	BEGIN
		ASSERT(DIM(x)=4);
		Kernel.SetTimer(timer,0);
		lenX:=LEN(x);
		IF LEN(x)#LEN(SELF.x) THEN NEW(SELF.x, LEN(x))
		ELSIF x=SELF.x THEN RETURN (* already processed image; somewhat costly test..*)
		ELSE SELF.x:=x (*! probably redundant, as content of x is also stored in nn1*)
		END;
		NEW(lenY,3); lenY[0]:=LEN(x,0); lenY[1..2]:=LEN(x)[2..3]-filtersize[1..2]+1;
		IF LEN(y)#lenY THEN NEW(y,lenY) END;
		nn1.step:=step;
		nn1.stepBias:=stepBias;
		nn1.momentum:=momentum;
		nn1.decay:=decay;
		nn1.clamp:=clamp;
		nn1.slow:=slow;
		FOR m:=0 TO LEN(x,0)-1 DO
			nn1.Propagate(x[m,?]);
			y[m,*,*]:=nn1.y[*,*];
		END;
		tProp:=tProp+Kernel.Elapsed(timer);
	END Propagate;

	PROCEDURE 	Backprop*(CONST dNext: Dataset); (*to do: scaling ?*)
	VAR m:SIGNED32;
	BEGIN
		Kernel.SetTimer(timer,0);
		IF dIn#lenX THEN NEW(dIn,lenX) END;
		FOR m:=0 TO LEN(dIn,0)-1 DO
			nn1.Backprop(dNext[m,?]);
			dIn[m,*,*,*]:=nn1.dIn[*,*,*]
		END;
		step:=nn1.step;
		stepBias:=nn1.stepBias;
		momentum:=nn1.momentum;
		decay:=nn1.decay;
		clamp:=nn1.clamp;
		slow:=nn1.slow;
		tBackprop:=tBackprop+Kernel.Elapsed(timer);
	END Backprop;

			(* generate image from activation*)
		PROCEDURE Reconstruct*(CONST activation: Dataset);
			(*involves solution of AX=B for fully connected layers,
			and deconvolution for convolutional layers*)
		END Reconstruct;

	PROCEDURE Store(writer: Streams.Writer);
	BEGIN
		nn1.Store(writer);
	END Store;

	PROCEDURE Load(reader: Streams.Reader);
	VAR
		biasAsVec: Vector;
	BEGIN
		nn1.Load(reader);
	END Load;


	PROCEDURE MemorizeGoodParameters*;
		BEGIN
			oldGoodW:=goodW; goodW:= nn1.w;
			oldGoodStep:=goodStep; goodStep:=step;
			oldGoodBias:=goodBias; goodBias:=bias;
			oldGoodMomentum:=goodMomentum; goodMomentum:=momentum;
			IF oldGoodStep=0 THEN (* detect first occurrance*)
				oldGoodW:=goodW;
				oldGoodStep:=goodStep;
				oldGoodBias:=goodBias;
				oldGoodMomentum:=goodMomentum
			END;
		END MemorizeGoodParameters;

		PROCEDURE Rollback(n:SIGNED32); (* Roll parameters back by n good epochs*)
		BEGIN
			IF n=1 THEN
				nn1.w:=goodW;
				IF DIM(nn1.dw)>0 THEN nn1.dw:=0; END;
				step:=goodStep;
				bias:=goodBias;
				momentum:=goodMomentum;
			ELSIF n=2 THEN
				nn1.w:=oldGoodW;
				IF DIM(nn1.dw)>0 THEN nn1.dw:=0; END;
				step:=oldGoodStep;
				bias:=oldGoodBias;
				momentum:=oldGoodMomentum;
			ELSE HALT(200)
			END;
		END Rollback;
END ConvLayerMNM;

TYPE ConvLayerMNMP*=OBJECT(ConvLayer);(**  [mMinibatch, nLayers, height, width] input data; nLayers*pFeaturemaps filters[filtersize]; [mMinibatch,pFeatureMaps, height, width] output data *)
	VAR nnp: POINTER TO ARRAY OF ConvLayerMM1;
		lenX, lenY: IntVector;
		pOutputs:SIGNED32;

	PROCEDURE &Init*(CONST filtersize:IntVector; pOutputs:SIGNED32; nonLinear, nonLinearDerivative: Function; show: BOOLEAN); (*filtersize is [h,,w]*)
	VAR p:SIGNED32;
	BEGIN
		ASSERT(LEN(filtersize,0)=3);
		SELF.pOutputs:=pOutputs;
		NonLinear:=nonLinear;
		NonLinearDerivative:=nonLinearDerivative;
		SELF.filtersize:=filtersize;
		SELF.show:=show;
		bias:=0;
		step:=DefaultStep;
		stepBias:=DefaultStepBias;
		decay:=DefaultDecay;
		slow:=1.0;
		NEW(nnp,pOutputs);
		FOR p:=0 TO pOutputs-1 DO	 NEW(nnp[p], filtersize, nonLinear, nonLinearDerivative, show) END;
	END Init;

	PROCEDURE Propagate*(CONST x: Dataset);
	VAR m,p:SIGNED32;
	BEGIN
		Kernel.SetTimer(timer,0);
		ASSERT(DIM(x)=4, 200);
		lenX:=LEN(x);
		IF LEN(x)#LEN(SELF.x) THEN NEW(SELF.x, LEN(x))
		ELSIF x=SELF.x THEN RETURN (* already processed image; somewhat costly test..*)
		ELSE SELF.x:=x (*! probably redundant, as content of x is also stored in nnp[..].x*)
		END;

		NEW(lenY,4);
		lenY[0]:=LEN(x,0); (*minibatch size*)
		lenY[1]:=pOutputs; (*number of feature maps in output*)
		lenY[2..3]:=LEN(x)[2..3]-filtersize[1..2]+1; (*reduced number of rows and columns per feature map due to valid convolution*)
		IF LEN(y)#lenY THEN NEW(y,lenY) END;

		FOR p:=0 TO LEN(y,1)-1 DO
			nnp[p].step:=step;
			nnp[p].stepBias:=stepBias;
			nnp[p].momentum:=momentum;
			nnp[p].decay:=decay;
			nnp[p].clamp:=clamp;
			nnp[p].slow:=slow;
			FOR m:=0 TO LEN(x,0)-1 DO
				nnp[p].Propagate(x[m,*,*,*]); (* all N go into one P*)
				y[m,p,*,*]:=nnp[p].y[*,*];
			END;
		END;
		tProp:=tProp+Kernel.Elapsed(timer);
	END Propagate;

	PROCEDURE 	Backprop*(CONST dNext: Dataset);
	VAR m,p:SIGNED32;
	BEGIN
		Kernel.SetTimer(timer,0);
		ASSERT(DIM(dNext)=4, 200);
		IF dIn#lenX THEN NEW(dIn,lenX) ELSE dIn:=0 END;
		FOR p:=0 TO pOutputs-1 DO
			FOR m:=0 TO LEN(dIn,0)-1 DO
				nnp[p].Backprop(dNext[m,p,?]);
				dIn[m,*,*,*]:=dIn[m,*,*,*] + nnp[p].dIn[*,*,*]
			END;
		END;
		tBackprop:=tBackprop+Kernel.Elapsed(timer);
	END Backprop;

		(* generate image from activation*)
	PROCEDURE Reconstruct*(CONST activation: Dataset);
		(*involves solution of AX=B for fully connected layers,
		and deconvolution for convolutional layers*)
	END Reconstruct;

	PROCEDURE Store(writer: Streams.Writer);
	VAR
		p: SIGNED32;
	BEGIN
		FOR p:=0 TO pOutputs-1 DO
			nnp[p].Store(writer);
		END;
	END Store;

	PROCEDURE Load(reader: Streams.Reader);
	VAR
		p: SIGNED32;
	BEGIN
		FOR p:=0 TO pOutputs-1 DO
			nnp[p].Load(reader);
		END;
	END Load;
	PROCEDURE MemorizeGoodParameters*;
	VAR p:SIGNED32;
	BEGIN
		FOR p:=0 TO pOutputs-1 DO
			nnp[p].MemorizeGoodParameters;
		END;
	END MemorizeGoodParameters;

	PROCEDURE Rollback(n:SIGNED32); (* Roll parameters back by n good epochs*)
	VAR p:SIGNED32;
	BEGIN
		FOR p:=0 TO pOutputs-1 DO
			nnp[p].Rollback(n);
		END;
	END Rollback;

END ConvLayerMNMP;

TYPE ConvLayerMNMN*=OBJECT(ConvLayer);(**  [mMinibatch, nLayers, height, width] input data; nLayers filters[filtersize]; [mMinibatch,nLayers, height, width] output data *)
	VAR nnn: ConvLayerMMM;
		lenX, lenY: IntVector;

	PROCEDURE &Init*(CONST filtersize:IntVector; nonLinear, nonLinearDerivative: Function; show: BOOLEAN); (*filtersize is [n, h,w]*)
	BEGIN
		ASSERT(LEN(filtersize)=3,200);
		NonLinear:=nonLinear;
		NonLinearDerivative:=nonLinearDerivative;
		SELF.filtersize:=filtersize;
		SELF.show:=show;
		bias:=0;
		step:=DefaultStep;
		stepBias:=DefaultStepBias;
		decay:=DefaultDecay;
		slow:=1.0;
		NEW(nnn, filtersize, nonLinear, nonLinearDerivative, show);
	END Init;

	PROCEDURE Propagate*(CONST x: Dataset);
	VAR m:SIGNED32;
	BEGIN
		Kernel.SetTimer(timer,0);
		ASSERT(DIM(x)=4, 200);
		lenX:=LEN(x);
		IF LEN(x)#LEN(SELF.x) THEN NEW(SELF.x, LEN(x))
		ELSIF x=SELF.x THEN RETURN (* already processed image; somewhat costly test..*)
		ELSE SELF.x:=x (*! probably redundant, as content of x is also stored in nnp[..].x*)
		END;

		NEW(lenY,4);
		lenY[0]:=LEN(x,0); (*minibatch size*)
		lenY[1]:=LEN(x,1);
		lenY[2..3]:=LEN(x)[2..3]-filtersize[1..2]+1; (*reduced number of rows and columns per feature map due to valid convolution*)
		IF LEN(y)#lenY THEN NEW(y,lenY) END;

		nnn.step:=step;
		nnn.stepBias:=stepBias;
		nnn.momentum:=momentum;
		nnn.decay:=decay;
		nnn.clamp:=clamp;
		nnn.slow:=slow;
		FOR m:=0 TO LEN(x,0)-1 DO
			nnn.Propagate(x[m,*,*,*]);
			y[m,*,*,*]:=nnn.y[*,*,*];
		END;
		tProp:=tProp+Kernel.Elapsed(timer);
	END Propagate;

	PROCEDURE 	Backprop*(CONST dNext: Dataset);
	VAR m:SIGNED32;
	BEGIN
		Kernel.SetTimer(timer,0);
		ASSERT(DIM(dNext)=4, 200);
		IF dIn#lenX THEN NEW(dIn,lenX) ELSE dIn:=0 END;
		FOR m:=0 TO LEN(dIn,0)-1 DO
			nnn.Backprop(dNext[m,*,*,*]);
			dIn[m,*,*,*]:=nnn.dIn[*,*,*]
		END;
		tBackprop:=tBackprop+Kernel.Elapsed(timer);
	END Backprop;

		(* generate image from activation*)
	PROCEDURE Reconstruct*(CONST activation: Dataset);
		(*involves solution of AX=B for fully connected layers,
		and deconvolution for convolutional layers*)
	END Reconstruct;

	PROCEDURE MemorizeGoodParameters*;
	BEGIN
		nnn.MemorizeGoodParameters;
	END MemorizeGoodParameters;

	PROCEDURE Rollback(n:SIGNED32); (* Roll parameters back by n good epochs*)
	BEGIN
		nnn.Rollback(n);
	END Rollback;

END ConvLayerMNMN;

TYPE NormalizeLayer*= OBJECT(Layer)(*! untested*)
		VAR beta: Dataset;
		vBias:Vector;
		ss:Datatype;

		PROCEDURE Propagate*(CONST in: Dataset); (* returns activations of this*) (*how to handle ?*)
		VAR i:SIGNED32;
		BEGIN
			Kernel.SetTimer(timer,0);
			vBias:=SUM(in, [1,2])/PROD(LEN(in)[1..2]); (*? does reinitialization ???*)
			NEW(beta,LEN(vBias)); (*? does reinitialization ???*)
			IF (DIM(y)#DIM(in)) OR (LEN(y)#LEN(in)) THEN NEW(y, LEN(in)) END;
			FOR i:=0 TO LEN(in,0)-1 DO
				y[i,..,..]:=in[i,..,..]-vBias[i];
				ss:= y[i,..,..] +* y[i,..,..];
				beta[i]:=1/Mathe.sqrt(ss)/PROD(LEN(y)[1..2]);
				y[i,..,..]:= beta[i] * y[i,..,..] ;
			END;
			tProp:=tProp+Kernel.Elapsed(timer);
		END Propagate;

		PROCEDURE Backprop*(CONST deltaNext:Dataset);
		VAR i:SIGNED32;
		BEGIN
			Kernel.SetTimer(timer,0);
			IF (DIM(dIn)#DIM(deltaNext)) OR (LEN(dIn)#LEN(deltaNext)) THEN NEW(dIn, LEN(deltaNext)) END;
			FOR i:= 0 TO LEN(beta,0)-1 DO
				dIn[i,..,..]:=1/beta[i] * deltaNext[i,..,..];
				dIn[i,..,..]:= dIn[i,..,..]+vBias[i]
			END;
			tBackprop:=tBackprop+Kernel.Elapsed(timer);
		END Backprop;
	END NormalizeLayer;

	(* A fully connected layer, using the matrix multiplication representation of neural network, handling minibatches of images [samples, imageRws,imageColumns]
		in this case, data areinternally  RESHAPED to be matrices with 1 sample(images) per row; a minibatch is therefore a matrix
		weight matrix w connects every input pixel with every output pixel.
	 *)
	 (*! to do: use a non-copy version of RESHAPE where possible, without destroying the standard layer interface*)

TYPE	FullLayer* = OBJECT (Layer)
		VAR
			dnext : Dataset;
			posGradient, negGradient,bx, bz, x0, z0, y0: Matrix;
			w0, z, dIn0: Matrix;
			biasX,  biasZ, dBiasX, dBiasZ: Vector;
			dBias:Datatype;
			ww, wdw, wd: WMMatrix.Window;
			inputSize, outputSize,tmpSize: IntVector;
			canDoUnsupervised*:BOOLEAN; (*allow to selectively apply contrastive divergence etc. to indivicual layers*)
			solver:MatrixSVD.Solver;
		END FullLayer;

TYPE	FullLayerM1M* = OBJECT (FullLayer)

		PROCEDURE &New*(CONST inputSize,outputSize: IntVector; nonLinear, nonLinearDerivative: Function; show: BOOLEAN);
		BEGIN
			ASSERT(LEN(inputSize,0)=3, 200);
			NonLinear:=nonLinear;
			NonLinearDerivative:=nonLinearDerivative;
			SELF.inputSize:=inputSize;
			SELF.outputSize:=outputSize;
			SELF.show:=show;
			canDoUnsupervised:=TRUE;
			stochastic:=FALSE;
			bias:=0;
			dBias:=0;
			step:=DefaultStep;
			stepBias:=DefaultStepBias;
			momentum:=DefaultMomentum;
			decay:=DefaultDecay;
			slow:=1.0;
			NEW(delta, [outputSize[0], outputSize[1]*outputSize[2]]);
			InitWeights([PROD(inputSize[1..2]), PROD(outputSize[1..2])]);
			NEW(biasX, PROD(inputSize[1..2])); NEW(dBiasX,LEN(biasX));
			NEW(biasZ, PROD(outputSize[1..2])); NEW(dBiasZ,LEN(biasZ));
		END New;

		PROCEDURE InitWeights(CONST weightSize: IntVector);
		VAR w0: Datatype;
		BEGIN
			ASSERT(LEN(weightSize,0)=2, 200);
			NEW(w, weightSize);
			NEW(dw, weightSize);
			NEW(dwOld, weightSize);
			w:=Util.Random(weightSize, Util.Uniform);
			w:=w-0.5;
				(* see Stutz, formulae 16,17*)
				(* see http://deeplearning.net/tutorial/mlp.html *)
			IF NonLinear=ScaledSigmoid THEN w0:=2*Mathe.sqrt(6)/Mathe.sqrt(SUM(weightSize[0..1])) ; 	(*was IF NonLinear=ScaledSigmoid THEN w0:=Mathe.sqrt(6)/weightSize[0] ;*)
			ELSIF NonLinear=LeakyReLu THEN w0:=2*Mathe.sqrt(6)/Mathe.sqrt(SUM(weightSize[0..1])) ;
			ELSE w0:=4* 2* Mathe.sqrt(6)/Mathe.sqrt(SUM(weightSize[0..1]));
			END;
			w:= w0 * w;
			IF show THEN
				NEW(wd, delta[..MIN(200,LEN(delta,0))-1, ..MIN(200,LEN(delta,1))-1], "delta part"); wd.maxInterpolation := WMGraphics.ScaleBox; wd.AddWindow;
				NEW(ww, w[..MIN(200,LEN(w,0))-1, ..MIN(200,LEN(w,1))-1], "w part"); ww.maxInterpolation := WMGraphics.ScaleBox; ww.AddWindow;
				NEW(wdw, dw[..MIN(200,LEN(dw,0))-1, ..MIN(200,LEN(dw,1))-1], "dw part"); wdw.maxInterpolation := WMGraphics.ScaleBox; wdw.AddWindow;
			END;
		END InitWeights;

		PROCEDURE InitWeightsB(CONST weightSize: IntVector);
		BEGIN
			NEW(w, weightSize); Util.Identity(w[*,*]);
			NEW(dw, weightSize);
			NEW(dwOld, weightSize);
			IF show THEN
				NEW(wd, delta[..MIN(200,LEN(delta,0))-1, ..MIN(200,LEN(delta,1))-1], "delta part"); wd.maxInterpolation := WMGraphics.ScaleBox; wd.AddWindow;
				NEW(ww, w[..MIN(200,LEN(w,0))-1, ..MIN(200,LEN(w,1))-1], "w part"); ww.maxInterpolation := WMGraphics.ScaleBox; ww.AddWindow;
				NEW(wdw, dw[..MIN(200,LEN(dw,0))-1, ..MIN(200,LEN(dw,1))-1], "dw part"); wdw.maxInterpolation := WMGraphics.ScaleBox; wdw.AddWindow;
			END;
		END InitWeightsB;

		PROCEDURE Propagate*(CONST in: Dataset) ; (* returns activations of this*)
		BEGIN
			Kernel.SetTimer(timer,0);
			ASSERT(DIM(in)=3); (*a minibatch of images N/H/W)*)
			x:=ALIAS OF in;
			x:= RESHAPE(x, [LEN(in,0), LEN(in,1)* LEN(in,2)]); (* produce a matrix, whereby each row=1 image;  *)
			IF dropout>0 THEN
				w0:=drop .* w;
				z := x * w0;
			ELSE
				z := x * w; (* matrix multiplication with weight matrix *)
			END;
			IF dropout>0 THEN z:= (1-dropout) * z END;(* compensate for zeroed data; could also be done in a different way in Evaluate only *)
			y0:=z+bias;
			IF NonLinear#NIL THEN y0:=ALL(y0, NonLinear) END;
			IF stochastic THEN  y0:=ALL(y0, TruncateStochastic) END;
			y:=ALIAS OF y0;
			y:=RESHAPE(y, outputSize); (* starting from matrix where each row is an image, reconstruct original Dataset format *)
			tProp:=tProp+Kernel.Elapsed(timer);
		END Propagate;

		PROCEDURE LearnNonSupervised*(CONST in: Dataset; iterations:SIGNED32) ; (* not yet improving results - wrong algo ? wrong example data ?*)
		BEGIN
			ASSERT(DIM(in)=3); (*a minibatch of images N/H/W)*)
			x:= RESHAPE(in, [LEN(in,0), LEN(in,1)* LEN(in,2)]); (* produce a matrix, whereby each row=1 image;  *)
			IF canDoUnsupervised THEN ContrastiveDivergence(iterations); END;
			z := x * w ;
			y0:= z+bias;
			IF NonLinear #NIL THEN y0:=ALL(y0, NonLinear) END;
			y:=RESHAPE(y0, outputSize);
		END LearnNonSupervised;

		PROCEDURE DeltaFromDNext(CONST dNext: Dataset);
		BEGIN
			IF NonLinearDerivative#NIL THEN delta:=ALL(z, NonLinearDerivative); delta:= delta  .* dNext;
			ELSE delta:=dNext (*debug*)
			END;
		END DeltaFromDNext;

		PROCEDURE AdaptWeights;
		BEGIN
			dBias := stepBias * SUM(delta)/PROD(LEN(delta)); (*!to do: decouple bias update from weight step size *)
			bias := bias - dBias ;
			dw := x`* delta;
			dw:=1/LEN(x,0)* step*slow*dw;
			IF momentum#0 THEN
				IF LEN(dw)=LEN(dwOld) THEN dw:=dw+dwOld END;
				dwOld:=momentum*dw
			END;
			IF decay#0 THEN w:=(1-step*decay) * w END;
			IF dropout>0 THEN dw:= drop.*dw END; (* dropped out nodes are not updated *)
			w:=w - dw;
			IF clamp THEN ClampWeights END;
			validInverse:=FALSE;
			IF show THEN	ShowWeights	END;
		END AdaptWeights;

		(* literature
			Hinton 2010 tutorial
			https://en.wikipedia.org/wiki/Restricted_Boltzmann_machine
			http://deeplearning.net/tutorial/rbm.html
		*)

		PROCEDURE     ContrastiveDivergence*(GibbsSteps:SIGNED32); (* this works as a minibatch - is this the original design ?*)
		(*CONST GibbsSteps=1; *)
		VAR i:SIGNED32;
		BEGIN
			x0:=x;

			FOR i:=0 TO GibbsSteps-1 DO
				TRACE(i);
				z := x0 * w ;
				bz:=AddToRows(z, biasZ);(*	bz:=z+ biasZ;*)
				(*?Smooth reLu works well and is supposedly better than logistic, tanh. see 'Rectified Linear Units Improve Restricted Boltzmann Machines', Nair Hinton *)
				IF NonLinear#NIL THEN bz:=ALL(bz,NonLinear) END;
				IF i=0 THEN (*only throw the dice when the input is con*)
					IF stochastic THEN  bz:=ALL(bz, TruncateStochastic); (*binary, stochastic *) END;
				END;
 				posGradient:=x0`* bz; (*posGradient:=data` * hidden;*)

				z0:=bz;

				bx := bz * w`;(*reconstructed := hidden * weights`;*)
				bx:=AddToRows(bx, biasX); (*bx:=bx+ biasX; for each row*)
				IF NonLinear#NIL THEN bz:=ALL(bx,NonLinear) END;
				(*bx:=TruncateStochastic(bx);*)(*binary, stochastic - not needed here according to Hinton 2010*)

				bz := bx * w ;
				bz:=AddToRows(bz,biasZ);(*	bz:=bz+ biasZ;*)
				IF NonLinear#NIL THEN bz:=ALL(bz,NonLinear) END;
				(*bz:=TruncateStochastic(bz); *)(*binary, stochastic: not needed here according to Hinton2010*)
				negGradient:=bx` * bz ;	(*negGradient:=reconstruction` * hidden; *)

				dBiasZ:= SUM(z0-bz,0)/LEN(z0,0);
				dBiasX:= SUM(x0-bx,0)/LEN(x0,0);

				x0:=bx;
			END;

			dw := posGradient-negGradient;
			dw := step * dw;
			(*? can use momentum ?*)
			w := w + dw;
			dBiasX:=step*dBiasX; biasX:=biasX+dBiasX;
			dBiasZ:=step*dBiasZ; biasZ:=biasZ+dBiasZ;
		END ContrastiveDivergence;

		PROCEDURE Backprop*(CONST dNext:Dataset);
		BEGIN
			Kernel.SetTimer(timer,0);
			ASSERT(DIM(dNext)=3); (* a minibatch of images*)
			(*dnext:=ALIAS OF dNext; RESHAPE(dnext, ... *)
			dnext:=RESHAPE(dNext, [outputSize[0], outputSize[1]* outputSize[2]]);(* produce a matrix, whereby each row=1 image;  *)
			DeltaFromDNext(dnext);
			AdaptWeights;
			IF dropout>0 THEN
				w0:= drop .* w;
				dIn0 := delta * w0`
			ELSE
				dIn0 := delta * w`;
			END;
			IF dropout>0 THEN dIn0:= (1-dropout) * dIn0 END;(* compensate for zeroed data; could also be done in a different way in Evaluate only *)
			(*dIn:=ALIAS OF dIn0; dIn:=RESHAPE(dIn0, inputSize); *)
			dIn:=RESHAPE(dIn0, inputSize); (* starting from matrix where each row is an image, reconstruct original Dataset format *)
			tBackprop:=tBackprop+Kernel.Elapsed(timer);
		END Backprop;

		PROCEDURE ClampWeights;
		VAR msq, sd: Datatype;
		BEGIN
			msq:= w+*w / PROD(LEN(w));
			sd:=Mathe.sqrt(msq);
			w:=MIN(w,5*sd);
			w:=MAX(w,-5*sd);
		END ClampWeights;

		(* reconstruct dataset from activations*)
		PROCEDURE Reconstruct*(CONST activation: Dataset);
		BEGIN
			ASSERT(InverseNonLinear#NIL,200);
			IF solver=NIL THEN NEW(solver, w);	invW:=solver.PseudoInverse();
			ELSIF ~validInverse THEN solver.Init(w); invW:=solver.PseudoInverse(); (*! to do: reset validInverse at suited location when adequate*)
			END;
			invZ:=ALL(activation, InverseNonLinear);
			reconstruction := invZ * invW;
		END Reconstruct;

		(*! experimental: dynamic size change of layer output and next layer input. should grow or shrink a layer; only grow is currently tested*)
		PROCEDURE ChangeSize*(d: SIGNED32);
		VAR  wSize: IntVector;
		BEGIN
			ASSERT((next#NIL) & (next IS FullLayerM1M),201); (*implementation limitation*)

			outputSize[1..2]:=outputSize[1..2]+d;
			wSize:=[PROD(inputSize[1..2]), PROD(outputSize[1..2])];
			ResizeDataset(w, wSize);

			NEW(dw, wSize);
			NEW(dwOld, wSize);
			NEW(goodW, wSize);
			NEW(oldGoodW, wSize);
			NEW(w0, wSize);
			NEW(z, outputSize[0], wSize[1]);
			NEW(y0, outputSize[0], wSize[1]);
			NEW(dnext, outputSize[0], wSize[1]);
			NEW(delta, outputSize[0], wSize[1]);

			next(FullLayerM1M).inputSize[1..2] := next(FullLayerM1M).inputSize[1..2]+d;
			wSize:=[PROD(next(FullLayerM1M).inputSize[1..2]), PROD(next(FullLayerM1M).outputSize[1..2])];
			ResizeDataset(next.w, wSize);
			NEW(next.dw, wSize);
			NEW(next.dwOld, wSize);
			NEW(next.goodW, wSize);
			NEW(next.oldGoodW, wSize);
			NEW(next(FullLayerM1M).w0, wSize);
			NEW(next(FullLayerM1M).dIn0, outputSize[0], wSize[0]);
			NEW(next(FullLayerM1M).dIn, next(FullLayerM1M).inputSize);
		END ChangeSize;

		PROCEDURE InsertLayer*; (* allow dynamic modification of layer structure*)
		VAR full: FullLayerM1M;
		BEGIN
			NEW(full, outputSize, outputSize, NonLinear, NonLinearDerivative, show);
			full.step:=step;
			full.stepBias:=stepBias;
			full.decay:=decay;
			full.clamp:=clamp;
			full.slow:=slow;
			Diagonal(full.w);
			full.next:=next; next.prior:=full;
			full.prior:=SELF; next:=full;
		END InsertLayer;

		PROCEDURE ShowWeights;
		BEGIN
			IF (wd#NIL) & wd.isVisible THEN wd.SetImage(delta[..MIN(200,LEN(delta,0))-1, ..MIN(200,LEN(delta,1))-1]) END;
			IF (ww#NIL) & ww.isVisible THEN ww.SetImage(w[..MIN(200,LEN(w,0))-1, ..MIN(200,LEN(w,1))-1]) END;
			IF (wdw#NIL) & wdw.isVisible THEN wdw.SetImage(dw[..MIN(200,LEN(dw,0))-1, ..MIN(200,LEN(dw,1))-1]) END;
		END ShowWeights;

	END FullLayerM1M;

	TYPE	FullLayerMNMN* = OBJECT (FullLayer) (** [M, N, H,W] input, N fully connected filters, [M,N,H,W] outputs *)
		VAR n1n: POINTER TO ARRAY OF FullLayerM1M;

		PROCEDURE &New*(CONST inputSize,outputSize: IntVector; nonLinear, nonLinearDerivative: Function; show: BOOLEAN);
		VAR n:SIGNED32;
		BEGIN
			ASSERT(LEN(inputSize,0)=4, 200);
			NonLinear:=nonLinear;
			NonLinearDerivative:=nonLinearDerivative;
			SELF.inputSize:=inputSize;
			SELF.outputSize:=outputSize;
			SELF.show:=show;
			canDoUnsupervised:=TRUE;
			stochastic:=FALSE;
			bias:=0;
			dBias:=0;
			step:=DefaultStep;
			stepBias:=DefaultStepBias;
			momentum:=DefaultMomentum;
			decay:=DefaultDecay;
			slow:=1.0;
			NEW(n1n, inputSize[1]);
			NEW(dIn, inputSize);
			FOR n:=0 TO LEN(n1n)-1 DO
				NEW(n1n[n], [inputSize[0],inputSize[2],inputSize[3]], [outputSize[0],outputSize[2],outputSize[3]], nonLinear, nonLinearDerivative, show);
			END;
			NEW(y, outputSize);
		END New;

		PROCEDURE Propagate*(CONST in: Dataset) ; (* returns activations of this*)
		VAR n:SIGNED32;
		BEGIN
			Kernel.SetTimer(timer,0);
			ASSERT(DIM(in)=4); (*a minibatch of images N/H/W)*)
			x:=ALIAS OF in;
			FOR n:=0 TO LEN(n1n)-1 DO
				n1n[n].bias:=bias;
				n1n[n].dBias:=dBias;
				n1n[n].step:=step;
				n1n[n].stepBias:=stepBias;
				n1n[n].momentum:=momentum;
				n1n[n].decay:=decay;
				n1n[n].slow:=slow;
				y[*,n,*,*]:=n1n[n].y (* starting from matrix where each row is an image, reconstruct original Dataset format *)
			END;
			tProp:=tProp+Kernel.Elapsed(timer);
		END Propagate;

		PROCEDURE Backprop*(CONST dNext:Dataset);
		VAR n:SIGNED32;
		BEGIN
			Kernel.SetTimer(timer,0);
			ASSERT(DIM(dNext)=4);
			FOR n:=0 TO LEN(n1n)-1 DO
				n1n[n].Backprop(dNext[*,n,*,*]);
				dIn[*,n,*,*]:=n1n[n].dIn;
			END;
			tBackprop:=tBackprop+Kernel.Elapsed(timer);
		END Backprop;


	END FullLayerMNMN;


TYPE Network*= OBJECT
	VAR layers*, last*: Layer; (*linked list of layers*)
		error*: Dataset;
		plasticity*:BOOLEAN;
		stopped*:BOOLEAN;
		priorError*:Datatype;
		slowTimer*:SIGNED32; (* reduce steps for a number of times *)

		next*:Network; (* can create linked lists of networks *)

		PROCEDURE &Init*;
		BEGIN
			priorError:=MAX(Datatype);
			stopped:=FALSE;
		END Init;


		PROCEDURE Append*(l:Layer);
		BEGIN
			IF layers=NIL THEN layers:=l; last:=l; l.next:=NIL; l.prior:=NIL;
			ELSE
				last.next:=l; l.prior:=last; last:=l;
			END;
		END Append;

		PROCEDURE LearnNonSupervised*(CONST data: Dataset; iterations: SIGNED32);
		VAR thisLayer:Layer;
		BEGIN
			thisLayer:=layers;
			thisLayer(FullLayerM1M).LearnNonSupervised(data, iterations);
			WHILE thisLayer.next#NIL DO
				IF thisLayer.next IS FullLayerM1M THEN
					thisLayer.next(FullLayerM1M).LearnNonSupervised(thisLayer.y, iterations); (*! incorrect parameter passing if not all layers are Full*)
				END;
				thisLayer:=thisLayer.next;
			END;
		END LearnNonSupervised;


		PROCEDURE TrainingRound*(CONST data, target: Dataset);
		VAR thisLayer:Layer;
		BEGIN
			ASSERT(layers#NIL);
			thisLayer:=layers;
			thisLayer.Propagate(data);
			WHILE thisLayer.next#NIL DO
				thisLayer.next.Propagate(thisLayer.y);
				thisLayer:=thisLayer.next;
			END;
			error:= thisLayer.y-target;
			thisLayer.Backprop(error);
			WHILE thisLayer.prior#NIL DO
				thisLayer.prior.Backprop(thisLayer.dIn);
				thisLayer:=thisLayer.prior;
			END;
		END TrainingRound;

		PROCEDURE ScaleStep*(scale:Datatype); (*scale step size definitely*)
		VAR l:Layer;
		BEGIN
			l:=layers;
			WHILE (l#NIL) DO
				l.step:= scale * l.step;
				l:=l.next
			END;
		END ScaleStep;

		PROCEDURE SlowStep*(speed:Datatype); (* change step temporarily, e.g. when impending parameter explosion is suspected*)
		VAR l:Layer;
		BEGIN
			l:=layers;
			WHILE (l#NIL) DO
				l.slow:=speed;
				l:=l.next
			END;
		END SlowStep;


		(*todo: use StoreLayer/GenLayer procedures to store the layer's config together with the weights*)
		PROCEDURE StoreParameters*(w: Streams.Writer);
		VAR l:Layer;
		BEGIN
			ASSERT(layers#NIL);
			l:=layers;
			WHILE l#NIL DO
				l.Store(w);
				l:=l.next;
			END;
		END StoreParameters;

		PROCEDURE LoadParameters*(r: Streams.Reader);
		VAR l: Layer
		BEGIN
			ASSERT(layers#NIL);
			l:=layers;
			WHILE l#NIL DO
				l.Load(r);
				l:=l.next;
			END;
		END LoadParameters;
		(* Set/GetGoodParameters allows to reconstruct situation before parameter explosion *)
		PROCEDURE MemorizeGoodParameters*;
		VAR l:Layer;
		BEGIN
			ASSERT(layers#NIL);
			l:=layers;
			WHILE l#NIL DO
				l.MemorizeGoodParameters;
				l:=l.next;
			END;
		END MemorizeGoodParameters;

		PROCEDURE Rollback*(n:SIGNED32); (* roll back to last good parameters that are found at n layers earlier*)
		VAR l:Layer;
		BEGIN
			l:=layers;
			WHILE l#NIL DO	l.Rollback(n);  l:=l.next END;
		END Rollback;

		PROCEDURE Evaluate*(CONST data:Dataset):Dataset;
		VAR thisLayer:Layer; sTmp:BOOLEAN;
		BEGIN
			ASSERT(layers#NIL);
			thisLayer:=layers;
			sTmp:=thisLayer.stochastic; thisLayer.stochastic:=FALSE; thisLayer.Propagate(data); thisLayer.stochastic:=sTmp;
			WHILE thisLayer.next#NIL DO
				sTmp:=thisLayer.stochastic; thisLayer.stochastic:=FALSE;
				thisLayer.next.Propagate(thisLayer.y);
				thisLayer.stochastic:=sTmp;
				thisLayer:=thisLayer.next;
			END;
			RETURN thisLayer.y
		END Evaluate;

		PROCEDURE Stop*;
		BEGIN
			stopped:=TRUE;
		END Stop;


	END Network;

VAR random:Util.RandomGenerator;
	rand:Random.Sequence;
	nilArray: Dataset;
	nilMatrix: Matrix;

(*PROCEDURE Do1*;
CONST nFilters=8;
VAR data, temp, result: Matrix;
	map, map1: ARRAY [*] OF Matrix;
	analyzer: PlanarWavelets.Analyzer;
	window: WMMatrix.Window;
	filter, filter1,filter2: Filters.Filter;
BEGIN
	(*get data*)
	NEW(data,256,256);
	data[100..110,150..160]:=1;
	NEW(result,256,256);

	NEW(map, nFilters, LEN(data,0), LEN(data,1));

	filter:=Filters.CreateFIRFilter([0.7,0.7],1);
	filter1:=Filters.CreateSplineFilter(Filters.MomentCubic1);
	filter2:=Filters.CreateSplineFilter(Filters.MomentCubic2);

	ASSERT(filter#NIL);
	ASSERT(filter1#NIL);

(*apply filter bank*)
	map[0]:=data;
	PlanarTransform.Filter2D(data, map[1], filter, {0}, Filters.finite);
	PlanarTransform.Filter2D(data, map[2], filter, {1}, Filters.finite);
	PlanarTransform.Filter2D(data, map[3], filter, {0,1}, Filters.finite);
	PlanarTransform.Filter2D(data, map[4], filter1, {0}, Filters.finite);
	PlanarTransform.Filter2D(data, map[5], filter1, {1}, Filters.finite);
	PlanarTransform.Filter2D(data, map[6], filter2, {0}, Filters.finite);
	PlanarTransform.Filter2D(data, map[7], filter2, {1}, Filters.finite);

	NEW(window, map[0], "00"); window.AddWindow;
	NEW(window, map[1], "01"); window.AddWindow;
	NEW(window, map[2], "10"); window.AddWindow;
	NEW(window, map[3], "11"); window.AddWindow;
	NEW(window, map[4], "02"); window.AddWindow;
	NEW(window, map[5], "20"); window.AddWindow;
	NEW(window, map[6], "03"); window.AddWindow;
	NEW(window, map[7], "30"); window.AddWindow;

(*nonlinear transform*)
	map:=ALL(map, RectifiedLinear);

	NEW(window, map[0], "100"); window.AddWindow;
	NEW(window, map[1], "101"); window.AddWindow;
	NEW(window, map[2], "110"); window.AddWindow;
	NEW(window, map[3], "111"); window.AddWindow;
	NEW(window, map[4], "102"); window.AddWindow;
	NEW(window, map[5], "120"); window.AddWindow;
	NEW(window, map[6], "103"); window.AddWindow;
	NEW(window, map[7], "130"); window.AddWindow;


(* MAX pooling *)
	NEW(map1, nFilters, LEN(data,0) DIV 2, LEN(data,1) DIV 2);
	map1[0]:=PlanarTransform.ReduceMax(map[0]);
	map1[1]:=PlanarTransform.ReduceMax(map[1]);
	map1[2]:=PlanarTransform.ReduceMax(map[2]);
	map1[3]:=PlanarTransform.ReduceMax(map[3]);
	map1[4]:=PlanarTransform.ReduceMax(map[4]);
	map1[5]:=PlanarTransform.ReduceMax(map[5]);
	map1[6]:=PlanarTransform.ReduceMax(map[6]);

	NEW(window, map1[0], "200"); window.AddWindow;
	NEW(window, map1[1], "201"); window.AddWindow;
	NEW(window, map1[2], "210"); window.AddWindow;
	NEW(window, map1[3], "211"); window.AddWindow;
	NEW(window, map1[4], "202"); window.AddWindow;
	NEW(window, map1[5], "220"); window.AddWindow;
	NEW(window, map1[6], "203"); window.AddWindow;
	NEW(window, map1[7], "230"); window.AddWindow;
(*BackProp Error*)

(*adjust filter*)

END Do1;
*)

(* TestTraining starts from a 2D dataset "data" and learns the 2D filters "w" needed to fit a "target" dataset by convolution layers and max pooling layers *)
(* in addition to serving as a minimalistic implementation, the example also shows the limitations of the convolutional-only layers:  lack of local features in source dataset leads to target image areas that cannot be fitted*)
(* not that this works currently for sigmoid (tanh) nonlinearity, but not yet for ReLU; the latter is probably critically dependent on some kind of normalization. Also, it is not clear to me if the "MaxPool" layer should rather be a "MaxAbsPool" layer *)
PROCEDURE TestTraining*(context:Commands.Context);
CONST nFilters=8;
	nSamples=4;
	show=TRUE;
VAR data, result: Dataset;
	target:Dataset;
	window, resultWindow, errorWindow: WMStack.Window;
	tWindow,wr,we,wd: WMMatrix.Window;
	net:Network;
	l: Layer;
	cl: ConvLayer;
	clm: ConvLayerMMM;
	clmm1: ConvLayerMM1;
	clm1m: ConvLayerM1M;
	clmnmp: ConvLayerMNMP;
	fl: FullLayerM1M;
	ml:MaxPoolLayer;
	nl: NormalizeLayer;
	i, rounds:SIGNED32;
	e: Datatype;
	type, dynamic:ARRAY 10 OF CHAR;
	history, oldHistory: Matrix;
	historyGraph: WMSimpleGraphs.Graphs;
BEGIN
	IF ~context.arg.GetString(type) THEN type:="S" END;
	IF ~context.arg.GetInteger(rounds,FALSE) THEN rounds:=100 END;
	IF ~context.arg.GetString(dynamic) THEN dynamic:="" END;
	IF type="S"	 THEN
		NEW(data, [200,300]);
		data[100..110,150..160]:=1;
		data[60..80, 80..100]:=1.0;
		data[90..100, 20..30]:=1.0;
		data[20..30, 60..80]:=1.0;
		data[120..130, 60..80]:=1.0;
		data[140..150, 100..120]:=1.0;
		NEW(net);
		(*NEW(nl); net.Append(nl);*)
		NEW(cl, [20,30], Tanh, TanhDerivative,FALSE); net.Append(cl);
		NEW(ml); net.Append(ml);
		NEW(cl, [10,15], Tanh, TanhDerivative,FALSE); net.Append(cl);
		NEW(ml); net.Append(ml);
		NEW(cl, [10,15], Linear, LinearDerivative,FALSE); net.Append(cl);
		NEW(ml); net.Append(ml);
		NEW(wd, data, "data"); wd.AddWindow;

	ELSE
		NEW(data, [nFilters, 200,300]);
		data[..,100..110,150..160]:=1;
		data[..,60..80, 80..100]:=1.0;
		data[..,90..100, 20..30]:=1.0;
		data[..,20..30, 60..80]:=1.0;
		data[..,120..130, 60..80]:=1.0;
		data[..,140..150, 100..120]:=1.0;
		FOR i:=0 TO LEN(data,0)-1 BY 2 DO
			data[i,?]:=Rot180(data[i,?]);
		END;
		FOR i:=0 TO LEN(data,0)-1 DO
			data[i,?]:=((LEN(data,0)-i)/nFilters) * data[i,?]
		END;

		IF type="MM1" THEN
			NEW(net);
			(*NEW(nl); net.Append(nl);*)
			NEW(clmm1, [nFilters, 20,30], Tanh, TanhDerivative,FALSE); net.Append(clmm1);
			NEW(ml); net.Append(ml);
			NEW(cl, [10,15], Tanh, TanhDerivative,FALSE); net.Append(cl);
			NEW(ml); net.Append(ml);
			NEW(cl, [10,15], Linear, LinearDerivative,FALSE); net.Append(cl);
			NEW(ml); net.Append(ml);

		ELSIF type="MMM" THEN
			NEW(net);
			(*NEW(nl); net.Append(nl);*)
			NEW(clm, [nFilters, 20,30], Tanh, TanhDerivative,TRUE); clm.step:=0.0005; net.Append(clm);
			NEW(ml); net.Append(ml);
			NEW(clm, [nFilters,10,15], Tanh, TanhDerivative,TRUE); clm.step:=0.0005; net.Append(clm);
			NEW(ml); net.Append(ml);
			NEW(clm, [nFilters, 10,15], Linear, LinearDerivative,TRUE); clm.step:=0.0005; net.Append(clm);
			NEW(ml); net.Append(ml);

		ELSIF type="M1M" THEN
			NEW(net);
			(*NEW(nl); net.Append(nl);*)
			NEW(clm1m, [ 20,30], Tanh, TanhDerivative,FALSE); net.Append(clm1m);
			NEW(ml); net.Append(ml);
			NEW(clm1m, [10,15], Tanh, TanhDerivative,FALSE); net.Append(clm1m);
			NEW(ml); net.Append(ml);
			NEW(clm1m, [ 10,15], Linear, LinearDerivative,FALSE); net.Append(clm1m);
			NEW(ml); net.Append(ml);

		ELSIF type="FULL2" THEN (* 2 fully connected layers*)
			NEW(data, [nSamples, 100,100]);
			data[.. BY 2,60..80, 80..90]:=1.0;
			data[.. BY 2,90..95, 20..30]:=1.0;
			data[.. BY 2,20..30, 60..80]:=1.0;
			data[1,?]:=Rot180(data[0,?]);
			data[3,?]:=Rot180(data[0,?]);
			data[2..3,?]:=0.3*data[2..3,?];
			NEW(net);
			NEW(fl, [nSamples,100,100],[nSamples,20,20 ], Tanh, TanhDerivative, TRUE); fl.step:=0.0001; net.Append(fl); (*big pretrained layer*)
			NEW(fl, [nSamples,20,20],[nSamples,10,10], Linear, LinearDerivative, TRUE); fl.step:=0.0001; net.Append(fl);

		ELSIF type="FULL" THEN (* N fully connected layers*)
			NEW(data, [nSamples, 100,100]);
			data[.. BY 2,60..80, 80..90]:=1.0;
			data[.. BY 2,90..95, 20..30]:=1.0;
			data[.. BY 2,20..30, 60..80]:=1.0;
			data[1,?]:=Rot180(data[0,?]);
			data[3,?]:=Rot180(data[0,?]);
			data[2..3,?]:=0.3*data[2..3,?];
			NEW(net);
			NEW(fl, [nSamples,100,100],[nSamples,20,20 ], Logistic, LogisticDerivative, FALSE); fl.step:=0.0001; net.Append(fl); (*big pretrained layer*)
			NEW(fl, [nSamples,20,20],[nSamples,20,20 ], Logistic, LogisticDerivative, TRUE); fl.step:=0.0001; net.Append(fl);
			NEW(fl, [nSamples,20,20],[nSamples,20,20 ], Logistic, LogisticDerivative, TRUE); fl.step:=0.0001; net.Append(fl);
			NEW(fl, [nSamples,20,20],[nSamples,10,10], Linear, LinearDerivative, FALSE); fl.step:=0.0001; net.Append(fl);

		ELSIF type="CD" THEN
			NEW(data, [nSamples, 100,100]);
			data[.. BY 2,60..80, 80..90]:=1.0;
			data[.. BY 2,90..95, 20..30]:=1.0;
			data[.. BY 2,20..30, 60..80]:=1.0;
			data[1,?]:=Rot180(data[0,?]);
			data[3,?]:=Rot180(data[0,?]);
			data[2..3,?]:=0.3*data[2..3,?];
			NEW(net);
			NEW(fl, [nSamples,100,100],[nSamples,20,20 ], Logistic, LogisticDerivative, TRUE); net.Append(fl); (*big pretrained layer*)
			NEW(fl, [nSamples,20,20],[nSamples,20,20 ], Logistic, LogisticDerivative, FALSE); net.Append(fl);
			NEW(fl, [nSamples,20,20],[nSamples,20,20 ], Logistic, LogisticDerivative, FALSE); net.Append(fl);
			(*?;
			probable explanation:
				1) The pretraining uses logistic sigmoid, the backprop uses TanHDerivative, that can't work.
				2) the pretrained layer finds features that characterize the input, they're not necessarily all useful for discrimination -> the layers with pretraining need to be a bit bigger
				3) the very top layer that produces the network's cannot be pretrained since it will put its features at a random place and they might be mixtures of what we're actually interested in the end.
			*)
			NEW(fl, [nSamples,20,20],[nSamples,10,10], Linear, LinearDerivative, FALSE); net.Append(fl);

		ELSIF (type="DEEP") OR (type="DEEPCD") THEN
			NEW(data, [nSamples, 100,100]);
			data[.. BY 2,60..80, 80..90]:=1.0;
			data[.. BY 2,90..95, 20..30]:=1.0;
			data[.. BY 2,20..30, 60..80]:=1.0;
			data[1,?]:=Rot180(data[0,?]);
			data[3,?]:=Rot180(data[0,?]);
			data[2..3,?]:=0.3*data[2..3,?];
			NEW(net);
			NEW(fl, [nSamples,100,100],[nSamples,20,20 ], Logistic, LogisticDerivative, TRUE); net.Append(fl); (*big pretrained layer*)

			NEW(fl, [nSamples,20,20],[nSamples,20,20 ], Logistic, LogisticDerivative, FALSE); net.Append(fl);
			NEW(fl, [nSamples,20,20],[nSamples,20,20 ], Logistic, LogisticDerivative, FALSE); net.Append(fl);
			NEW(fl, [nSamples,20,20],[nSamples,20,20 ], Logistic, LogisticDerivative, FALSE); net.Append(fl);
			NEW(fl, [nSamples,20,20],[nSamples,20,20 ], Logistic, LogisticDerivative, FALSE); net.Append(fl);
			NEW(fl, [nSamples,20,20],[nSamples,20,20 ], Logistic, LogisticDerivative, FALSE); net.Append(fl);
			NEW(fl, [nSamples,20,20],[nSamples,20,20 ], Logistic, LogisticDerivative, FALSE); net.Append(fl);
			NEW(fl, [nSamples,20,20],[nSamples,20,20 ], Logistic, LogisticDerivative, FALSE); net.Append(fl);
			NEW(fl, [nSamples,20,20],[nSamples,20,20 ], Logistic, LogisticDerivative, FALSE); net.Append(fl);
			NEW(fl, [nSamples,20,20],[nSamples,20,20 ], Logistic, LogisticDerivative, FALSE); net.Append(fl);

			NEW(fl, [nSamples,20,20],[nSamples,10,10], Linear, LinearDerivative, FALSE); net.Append(fl)
ELSIF (type="DEEP10B") OR (type="DEEPCD10B") THEN
			NEW(data, [nSamples, 100,100]);
			data[.. BY 2,60..80, 80..90]:=1.0;
			data[.. BY 2,90..95, 20..30]:=1.0;
			data[.. BY 2,20..30, 60..80]:=1.0;
			data[1,?]:=Rot180(data[0,?]);
			data[3,?]:=Rot180(data[0,?]);
			data[2..3,?]:=0.3*data[2..3,?];
			NEW(net);
			NEW(fl, [nSamples,100,100],[nSamples,80,80 ], Logistic, LogisticDerivative, TRUE); net.Append(fl); (*big pretrained layer*)

			NEW(fl, [nSamples,80,80],[nSamples,60,60 ], Logistic, LogisticDerivative, FALSE); net.Append(fl);
			NEW(fl, [nSamples,60,60],[nSamples,40,40 ], Logistic, LogisticDerivative, FALSE); net.Append(fl);
			NEW(fl, [nSamples,40,40],[nSamples,20,20 ], Logistic, LogisticDerivative, FALSE); net.Append(fl);
			NEW(fl, [nSamples,20,20],[nSamples,20,20 ], Logistic, LogisticDerivative, FALSE); net.Append(fl);
			NEW(fl, [nSamples,20,20],[nSamples,20,20 ], Logistic, LogisticDerivative, FALSE); net.Append(fl);
			NEW(fl, [nSamples,20,20],[nSamples,20,20 ], Logistic, LogisticDerivative, FALSE); net.Append(fl);
			NEW(fl, [nSamples,20,20],[nSamples,20,20 ], Logistic, LogisticDerivative, FALSE); net.Append(fl);
			NEW(fl, [nSamples,20,20],[nSamples,20,20 ], Logistic, LogisticDerivative, FALSE); net.Append(fl);
			NEW(fl, [nSamples,20,20],[nSamples,10,10 ], Logistic, LogisticDerivative, FALSE); net.Append(fl);

			NEW(fl, [nSamples,10,10],[nSamples,10,10], Linear, LinearDerivative, FALSE); net.Append(fl)		ELSE HALT(200)
		END;
		IF show THEN NEW(window, data, "data",0); window.AddWindow; END;
	END;

	result:=net.Evaluate(data);

	NEW(target, LEN(result));
	IF DIM(target)=2 THEN
		target[ ..BY 2,..]:=1.0; target[ 1,0]:=-0.01; (* force signed display *)
		IF show THEN
			NEW(wr, result[..,..],"result0"); wr.maxInterpolation:=WMGraphics.ScaleBox; wr.AddWindow;
			NEW(tWindow, target, "target0"); tWindow.maxInterpolation := WMGraphics.ScaleBox; tWindow.AddWindow;
			NEW(we, result[..,..],"error0"); we.maxInterpolation:=WMGraphics.ScaleBox; we.AddWindow;
		END;
	ELSIF DIM(target)=3 THEN
		target[.., ..BY 2,..]:=1.0; target[..,1,0]:=-0.01; (* force signed display *)
		IF show THEN
			NEW(resultWindow, result, "result",0); resultWindow.maxInterpolation := WMGraphics.ScaleBox;  resultWindow.AddWindow;
			NEW(window, target, "target",0); window.maxInterpolation := WMGraphics.ScaleBox; window.AddWindow;
			NEW(errorWindow, target, "error",0); errorWindow.maxInterpolation := WMGraphics.ScaleBox; errorWindow.AddWindow;
		END;
	ELSIF DIM(target)=4 THEN
		target[..,.., ..BY 2,..]:=1.0; target[..,..,1,0]:=-0.01; (* force signed display *)
		(*to do: show*)
	END;

	FOR i:=0 TO 6 DO
		IF (type="CD") OR (type="DEEPCD") THEN
			net.LearnNonSupervised(data, 1);
			context.out.Float(SUM(fl.w)/PROD(LEN(fl.w)),14); context.out.Float(SUM(fl.dw)/PROD(LEN(fl.dw)),14); context.out.Ln; context.out.Update;
		END;
	END; (* mechanics work but result worse than without CD learning *)

	(*NEW(history, 2,100);
	NEW(historyGraph, history, "History");*)

	FOR i:=0 TO rounds-1 DO
		net.TrainingRound(data,target);

		IF (type="FULL2") & (i=10) THEN
			net.layers.InsertLayer;
		END;

		e:=SUM(ABS(net.error));
		(*history[0, i MOD rounds]:=e;
		historyGraph.NewData(history);*)

		IF i MOD MAX(1,(rounds DIV 100))=0 THEN
			context.out.String(type); context.out.Int(i,4); context.out.String("   "); context.out.Float(e,12); context.out.Ln; context.out.Update;
		END;
		IF show THEN
			IF resultWindow#NIL THEN resultWindow.SetImage(net.last.y) END;
			IF wr#NIL THEN wr.SetImage(net.last.y) END;
			IF errorWindow#NIL THEN errorWindow.SetImage(net.error) END;
			IF we#NIL THEN we.SetImage(net.error) END;
		END;

		IF (dynamic#"") &  (i MOD 10 = 0) (* & (i= rounds DIV 2)*) & (net.layers.next IS FullLayerM1M) THEN
			net.layers.next(FullLayerM1M).ChangeSize(2);
			context.out.String(" grow to "); context.out.Int(1,0); context.out.Ln;
		END;
	END;

	result:=net.Evaluate(data);

	e:=SUM(ABS(target-result));
	context	.out.String(type); context.out.Int(i,4); context.out.String("   "); context.out.Float(e,12);
	context.out.String(" timing ");
	l:=net.layers;
	WHILE l#NIL DO context.out.Int(l.tProp,7); context.out.Int(l.tBackprop,7); l:=l.next	END;

	context.out.Ln; context.out.Update;
	IF show THEN
		IF resultWindow#NIL THEN resultWindow.SetImage(result) END;
		IF wr#NIL THEN wr.SetImage(result) END;
		IF errorWindow#NIL THEN errorWindow.SetImage(target-result) END;
		IF we#NIL THEN we.SetImage(target-result) END;
	END;

END TestTraining;


(*
PROCEDURE TestConvolve*;
VAR convolver: Convolver;
	data, filter, result: Dataset;
	window:WMMatrix.Window;
BEGIN
	NEW(data, 256,256); data[60..80, 80..100]:=1.0;
	(*NEW(filter, 64,64); filter[20..30,20..30]:=1.0;*)
	filter:=GenTestFilter([64,64]);
	NEW(convolver);
	result:=convolver.Convolve(data,filter,VALID);

	NEW(window, data, "data"); window.AddWindow;
	NEW(window, filter, "filter"); window.AddWindow;
	NEW(window, result, "result"); window.AddWindow;
END TestConvolve;*)

PROCEDURE TestConvolveEul*;
VAR convolver: EulFftwConvolve.MultiKernelConvolver2d_LR;
	data, filter, result: Dataset;
	window:WMMatrix.Window;
BEGIN
	NEW(data, 256,256);
	data[60..80, 80..100]:=1.0;
	data[90..100, 20..30]:=1.0;
	data[20..30, 60..80]:=1.0;
	data[120..130, 60..80]:=1.0;
	data[140..150, 100..120]:=1.0;
	(*NEW(filter, 64,64); filter[20..30,20..30]:=1.0;*)
	filter:=GenTestFilter([64,64]);
	NEW(convolver); IF convolver.SetInputSize([256,256]) THEN END;
	IF convolver.SetKernels(filter) & convolver.SetOutputShape(EulFftwConvolve.Valid) THEN result := convolver.Convolve(data);
	ELSE HALT(200)
	END;

	NEW(window, data, "data"); window.AddWindow;
	NEW(window, filter, "filter"); window.AddWindow;
	NEW(window, result, "result"); window.AddWindow;
END TestConvolveEul;

PROCEDURE TestStochastic*(context:Commands.Context);
VAR a: Vector;
BEGIN
	a:=[0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0];
	Util.Out(ALL(a, TruncateStochastic));
END TestStochastic;

PROCEDURE TestStream*;
VAR f:Files.File; r:Files.Reader; w:Files.Writer;
	l:Layer;
	l0,l1: ConvLayerMMM;
	f0,f1: FullLayerM1M;
BEGIN
	NEW(l0, [10,10], Linear, LinearDerivative, TRUE);
	f:=Files.New("TestLayerStore.file");
	Files.OpenWriter(w,f,0);
	StoreLayer(w, l0);
	Files.OpenReader(r,f,0);
	l:=GenLayer(r);

END TestStream;

PROCEDURE TestDiagonal*(context:Commands.Context);
VAR a,b: Dataset;
BEGIN
	NEW(a, 1,4,6);
	NEW(b, 1,6,4);
	Diagonal(a); Util.WriteArray(context.out, a, 9,2,0);
	Diagonal(b); Util.WriteArray(context.out, b, 9,2,0);
END TestDiagonal;


BEGIN
	NEW(random);
	NEW(rand);
END MLConvNet3D.

(*
Testing:
note that maps display scalar values, with white=only positive, and red/blue indicating positive and negative values *)
MLConvNet3D.TestTraining S 1000 ~
MLConvNet3D.TestTraining MM1 10000 ~
MLConvNet3D.TestTraining MMM 1000 ~
MLConvNet3D.TestTraining M1M 1000 ~
MLConvNet3D.TestTraining FULL2 100 ~
MLConvNet3D.TestTraining FULL2 20 ~

MLConvNet3D.TestTraining FULL 60 reduce~
MLConvNet3D.TestTraining FULL 60~
MLConvNet3D.TestTraining CD 100 ~
MLConvNet3D.TestTraining DEEP 100 ~
MLConvNet3D.TestTraining DEEP10B 100 ~
MLConvNet3D.TestTraining DEEPCD 100 ~
MLConvNet3D.TestConvolveEul~
MLConvNet3D.TestStochastic ~

SystemTools.FreeDownTo WMStack WMMatrix MLConvNet3D~
SystemTools.FreeDownTo WMMatrix MLConvNet3D~


Debugging.DisableGC~
Debugging.EnableGC~

SystemTools.FreeDownTo FoxIntermediateBackend~

SystemTools.FreeDownTo MNISTTest ~
MNISTTest.TrainNetwork CONV5b 6000~

