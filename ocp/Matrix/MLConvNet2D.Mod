MODULE MLConvNet2D; (** AUTHOR "Patrick Hunziker"; PURPOSE "convolutional neural network"; *)
(*Literature
generics: LeCun, Bengio, Hinton: Deep Learning. Nature 2015

specifics for convolutional neural networks:
Jake Bouvrie, Notes on Convolutional Neural Networks. 2006
David Stutz, Understanding Convolutional Neural Networks: good tutorial
Quoc V. Le: A Tutorial on Deep Learning Part 1: Backpropagation etc
Quoc V. Le: A Tutorial on Deep Learning Part 2: Autoencoders, Convolutional Neural Networks and Recurrent Neural Networks
https://www.tensorflow.org/tutorials/deep_cnn : a great ressource for implementation strategies and optional features
*)

IMPORT MatrixBase, Commands, WMMatrix, Util:=MatrixUtilities, Streams, Mathe:=MathL, EulFftwConvolve, PMathSSE, WMGraphics;
	(* ,Filters:=LinearFilters, Wavelets, PlanarTransform,PlanarWavelets, Files,  *)

CONST
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

OPERATOR "SUM"(m:Dataset; dimension:SIGNED32):Dataset;
VAR len:IntVector; i:SIGNED32;
BEGIN
	ASSERT(dimension<LEN(LEN(m),0));
	NEW(len, LEN(m)-1);
	FOR i:=0 TO dimension-1 DO
		len[i]:=LEN(m,i);
	END;
	FOR i:=dimension TO LEN(len,0)-1 DO
		len[i]:=LEN(m,i+1);
	END;
	IF (DIM(RESULT)#DIM(m)-1) OR (LEN(RESULT)#len) THEN NEW(RESULT,len) END;
	RESULT:=0;
	CASE dimension OF
	|0: FOR i:=0 TO LEN(m,0)-1 DO RESULT:=RESULT+m[i] END;
	|1:FOR i:=0 TO LEN(m,1)-1 DO RESULT:=RESULT+m[..,i] END;
	|2:FOR i:=0 TO LEN(m,2)-1 DO RESULT:=RESULT+m[..,..,i] END;
	|3:FOR i:=0 TO LEN(m,3)-1 DO RESULT:=RESULT+m[..,..,..,i] END;
	ELSE HALT(200);
	END;
END "SUM";

PROCEDURE PROD(CONST v: Vector): Datatype;
VAR res: Datatype; i:SIGNED32;
BEGIN
	res:=1;
	FOR i:=0 TO LEN(v,0)-1 DO
		res:=res*v[i]
	END;
	RETURN res;
END PROD;


PROCEDURE Linear(x:Datatype):Datatype;
BEGIN
	RETURN x
END Linear;

PROCEDURE LinearDerivative(x:Datatype):Datatype;
BEGIN
	RETURN 1
END LinearDerivative;

PROCEDURE RectifiedLinear(x:Datatype):Datatype;
CONST leak=0; (*0.01*)
BEGIN
	RETURN MAX(x,leak);
END RectifiedLinear;

PROCEDURE RectifiedLinearDerivative(x:Datatype):Datatype;
BEGIN
	IF x>0 THEN RETURN 1 ELSE RETURN 0 END;
END RectifiedLinearDerivative;

PROCEDURE Tanh( x: Datatype): Datatype;
BEGIN
	RETURN PMathSSE.tanh(SHORT(x))
END Tanh;

PROCEDURE TanhDerivative( y: Datatype ): Datatype;
VAR a: Datatype;
BEGIN
	a:=PMathSSE.tanh(SHORT(y));
	RETURN 1- a*a
END TanhDerivative;

(*!to do: ReduceAbsMax() ?*)
PROCEDURE ReduceMax*( CONST g: Matrix; VAR map: Util.BoolMatrix ): Matrix;  (* select MAX of each 2*2 group.*)(*? note that map can contain >1 TRUEs in quad field if values are same - MAY BE problematic on backprop ?*)
	BEGIN
		(*ASSERT(MAX(LEN(g) DIV 2)=0); *)(*implementation limitation: even dimensions*)
		IF (LEN( RESULT, 0 ) # ((LEN( g, 0 ) + 1) DIV 2)) OR (LEN( RESULT, 1 ) # ((LEN( g, 1 ) + 1) DIV 2)) THEN NEW( RESULT, (LEN( g, 0 ) + 1) DIV 2, (LEN( g, 1 ) + 1) DIV 2 ) END;
		IF (LEN(map)#LEN(g)) THEN NEW(map,LEN(g)) END;
		RESULT[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1] := g[.. BY 2, .. BY 2];
		RESULT[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1] := MAX(RESULT[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1], g[1.. BY 2, .. BY 2]);
		RESULT[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1] := MAX(RESULT[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1], g[.. BY 2, 1.. BY 2]);
		RESULT[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1] := MAX(RESULT[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1], g[1.. BY 2, 1.. BY 2]);

		map[.. BY 2, .. BY 2] := g[.. BY 2, .. BY 2] .= RESULT[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1];
		map[1.. BY 2, .. BY 2] := g[1.. BY 2, .. BY 2] .=RESULT[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1];
		map[.. BY 2, 1.. BY 2] := g[.. BY 2, 1.. BY 2] .= RESULT[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1];
		map[1.. BY 2, 1.. BY 2] := g[1.. BY 2, 1.. BY 2] .= RESULT[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1];

		RETURN RESULT
	END ReduceMax;


PROCEDURE ExpandMax*( CONST g: Matrix; VAR map: Util.BoolMatrix ): Dataset;  (* select MAX of each 2*2 group.*)(*? note that map can contain >1 TRUEs in quad field if values are same*)
	BEGIN
		(*precondition: correct dimensions*)
		IF LEN(RESULT)#LEN(map) THEN NEW(RESULT,LEN(map)) END;
		RESULT[.. BY 2, .. BY 2] := Util.ApplyMask(g, map[.. BY 1, .. BY 2], 0);
		RESULT[1.. BY 2, .. BY 2] := Util.ApplyMask(g, map[1.. BY 2, .. BY 2], 0);
		RESULT[.. BY 2, 1.. BY 2] := Util.ApplyMask(g, map[.. BY 2, 1.. BY 2], 0);
		RESULT[1.. BY 2, 1.. BY 2] := Util.ApplyMask(g, map[1.. BY 2, 1.. BY 2], 0);
		RETURN RESULT
	END ExpandMax;

PROCEDURE Rot180(CONST m:Dataset):Dataset;(* tbd: accelerated in library*)
VAR j,i:SIGNED32; x:Datatype;
BEGIN
	IF LEN(RESULT) # LEN(m) THEN NEW(RESULT, LEN(m)) END;
	ASSERT(DIM(m)=2); (*!implementation limitation*)
	FOR j:=0 TO LEN(m,0) DIV 2-1 DO
		FOR i:=0 TO LEN(m,1) -1 DO
			x:=m[j,i];
			RESULT[j,i]:=m[LEN(m,0)-j-1, LEN(m,1)-i-1];
			RESULT[LEN(m,0)-j-1, LEN(m,1)-i-1]:=x;
		END;
	END;
	RETURN RESULT
END Rot180;

PROCEDURE GenTestFilter(size:IntVector):Dataset;
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

TYPE
	Layer* = OBJECT
		VAR
			prior,next: Layer;
			x, y, delta, dIn: Dataset;
			show:BOOLEAN;
			window: WMMatrix.Window;

		PROCEDURE Propagate*(CONST in: Dataset) ; (* returns activations of this*)
		END Propagate;

		PROCEDURE Backprop*(CONST deltaNext:Dataset);
		END Backprop;
	END Layer;

TYPE PoolLayer*= OBJECT(Layer)
		PROCEDURE Downsample(CONST in:Dataset):Dataset;
		END Downsample;

		PROCEDURE Upsample(CONST delta:Dataset):Dataset;
		END Upsample;
	END PoolLayer;

TYPE  MaxPoolLayer*= OBJECT(PoolLayer)
		VAR xSmall, z: Dataset;
			map: Util.BoolMatrix;
			beta, dBeta, bias, dBias:Datatype;

		PROCEDURE &New;
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
		BEGIN
			 IF LEN(map)#LEN(x) THEN NEW(map, LEN(x)) END;
			 IF LEN(xSmall) # ((LEN(x)+1) DIV 2) THEN NEW(xSmall, ((LEN(x)+1) DIV 2)) END;
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
			x:=in;
			y:=Downsample(x);
			IF show THEN
				IF window=NIL THEN NEW(window, y, "maxPool"); window.AddWindow;
				ELSE window.SetImage( y)
				END;
			END;
		END Propagate;

		PROCEDURE Backprop(CONST dNext:Dataset);
		BEGIN
			DeltaFromDNext(dNext);
			dIn:=Upsample(delta);
			AdaptWeights; (*!? should backpropagation of delta occur before or after weight update ??*)
		END Backprop;
	END MaxPoolLayer;

TYPE ConvLayer*=OBJECT(Layer)
		CONST step=0.00007;
		VAR z, w, dw, tmp, ztmp: Dataset;
			bias, dBias: Datatype;
			size, filtersize: IntVector;
			window: WMMatrix.Window;
			NonLinear, NonLinearDerivative: Function;
			convolver, convolver1, convolver2: EulFftwConvolve.MultiKernelConvolver2d_LR;
			weightWindow, dWeightWindow: WMMatrix.Window;


		PROCEDURE &New(CONST filtersize:IntVector; nonLinear, nonLinearDerivative: Function);
		BEGIN
			SELF.filtersize:=filtersize;
			show:=TRUE;
			bias:=0;

			InitWeights(filtersize);

			NEW(convolver);  IF convolver.SetOutputShape(EulFftwConvolve.Valid) THEN END;
			NEW(convolver1); IF convolver1.SetOutputShape(EulFftwConvolve.Valid) THEN  END;
			NEW(convolver2); IF  convolver2.SetOutputShape(EulFftwConvolve.Full) THEN  END;

			NonLinear:=nonLinear;
			NonLinearDerivative:=nonLinearDerivative;
		END New;

		PROCEDURE InitWeights(filtersize: IntVector); (* see Stutz, formulae 16,17*)
		VAR w0: Datatype;
		BEGIN
			ASSERT(LEN(filtersize,0)=2); (*implementation limitation*)
			NEW(w, filtersize);
			w0:=1/PROD(filtersize) ; 			 (*w0 := Mathe.sqrt(6)/... *)
			w:=Util.Random(filtersize, Util.Uniform);
			w:=w-0.5;
			w:= 2*w0 * w; (* see Stutz, formulae 16,17*)
			IF show THEN
				NEW(weightWindow, w, "w"); weightWindow.AddWindow;
				NEW(dWeightWindow, w, "dw"); dWeightWindow.AddWindow;
			END;
		END InitWeights;


		PROCEDURE Propagate(CONST x: Dataset); (* returns activations of this*)
		VAR tmp0: Dataset;
		BEGIN
			SELF.x := x;
			size:=LEN(x);
			IF convolver.SetKernels(w) THEN ztmp := convolver.Convolve(x); z:=ztmp+bias; END; (*z := Convolve(x, w, VALID)+bias;*)
			IF NonLinear#NIL THEN y := ALL(z, NonLinear); ELSE y:=z END;
			IF show THEN
				IF window=NIL THEN NEW(window, y, "conv"); window.AddWindow;
				ELSE window.SetImage(y);
				END;
			END;
		END Propagate;

		PROCEDURE DeltaFromError(CONST error:Dataset);
		BEGIN
			tmp:= ALL(z, NonLinearDerivative);
			delta:= error .* tmp  ; (* last element *) (* delta:= 2* error .* delta  ; ? *)
			(* according to Quoc, the factor is 2(y-target), corresponding i.e. the derivative of of square(y-target) ...; originates from differentiation dE/dy *)
		END DeltaFromError;

		PROCEDURE DeltaFromDNext(CONST dNext (*, betaNext*): Dataset);
		BEGIN
			IF NonLinearDerivative#NIL THEN tmp:=ALL(z, NonLinearDerivative); delta:= tmp  .* dNext;
			ELSE delta:=dNext (*debug*)
			END;
			(*delta:=betaNext * delta;*) (*?*)
		END DeltaFromDNext;

		(* Notes on Convolutional Neural Networks. Jake Bouvrie, 2006 *)
		PROCEDURE AdaptWeights;
		BEGIN
			dBias := SUM(delta)/LEN(delta,0)/LEN(delta,1);  (*should it go here or after backprop ?*)(*?; see http://cogprints.org/5869/1/cnn_tutorial.pdf page 3;     *)
			dBias:=step*dBias;
			bias := bias - dBias ; (* with or without scaling ??? see Quoc Le, tutorial 1, page 8 *)
			delta:=delta-dBias; (*? this is min addition , works- is it justified to change the delta by this gradient ?*)

			IF convolver1.SetKernels(Rot180(delta)) THEN dw:=Rot180(convolver1.Convolve(x)) END; (*dw :=	Rot180(Convolve1(x, Rot180(delta),VALID)); *)
			dw:=step*dw;
			w:=w - dw;
			IF weightWindow#NIL THEN weightWindow.SetImage(w) END;
			IF dWeightWindow#NIL THEN dWeightWindow.SetImage(dw) END;
		END AdaptWeights;

		PROCEDURE 	Backprop(CONST dNext:Dataset);
		BEGIN
			DeltaFromDNext(dNext);
			AdaptWeights;  (*? should backpropagation occur before or after weight update ?*)
			IF convolver2.SetKernels(Rot180(w)) THEN (*dIn:=Convolve2(delta, Rot180(w), FULL); *)(*? beta, bias ?*)
				dIn:=convolver2.Convolve(delta);
			END;
		END Backprop;

	END ConvLayer;

TYPE NormalizeLayer*= OBJECT(Layer)(*! not yet ready -  TBD*)
		VAR beta, bias, ss: Datatype;

		PROCEDURE Propagate*(CONST in: Dataset):Dataset ; (* returns activations of this*) (*how to handle ?*)
		BEGIN
			bias:=SUM(in)/PROD(LEN(in);
			y:=in-bias;
			ss:= y+*y;
			beta:=1/Mathe.sqrt(ss)/LEN(y,0)/LEN(y,1);
			y:= beta * y ;
			y:= y + bias; (*backpropagate bias ?*)
		END Propagate;

		PROCEDURE Backprop*(CONST deltaNext:Dataset);
		BEGIN
			dIn:=1/beta * deltaNext;
			dIn:= dIn+bias
		END Backprop;

	END NormalizeLayer;

TYPE Network= OBJECT
	VAR layers, last:Layer; (*linked list of layers*)
		error: Dataset;
		log: Streams.Writer;

		PROCEDURE Append*(l:Layer);
		BEGIN
			IF layers=NIL THEN layers:=l; last:=l; l.next:=NIL; l.prior:=NIL;
			ELSE last.next:=l; l.prior:=last; last:=l;
			END;
		END Append;

		PROCEDURE TrainingRound(CONST data, target: Dataset);
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
			IF log#NIL THEN log.String("round"); log.Ln; log.Update END;
		END TrainingRound;

		PROCEDURE Evaluate(CONST data:Dataset):Dataset;
		VAR thisLayer:Layer;
		BEGIN
			ASSERT(layers#NIL);
			thisLayer:=layers;
			thisLayer.Propagate(data);
			WHILE thisLayer.next#NIL DO
				thisLayer.next.Propagate(thisLayer.y);
				thisLayer:=thisLayer.next;
			END;
			RETURN thisLayer.y
		END Evaluate;

	END Network;

(*
PROCEDURE Do0*(context:Commands.Context);
VAR data,result: PlanarWavelets.Matrix;
	analyzer: PlanarWavelets.Analyzer;
	window: WMMatrix.Window;
BEGIN
	NEW(data,256,256);
	data[100..110,150..160]:=1;
	NEW(result,256,256);
	NEW(analyzer, Wavelets.Haar, Wavelets.default, data);
	analyzer.Analyze;
	result:=analyzer.data;
	NEW(window, data, "data"); window.AddWindow;
	NEW(window, result, "result"); window.AddWindow;
END Do0;

PROCEDURE Do4*(context:Commands.Context);
VAR
	raw: ARRAY [?] OF SIGNED16;
	data,result,result1,result2,result3: PlanarWavelets.Matrix;
	analyzer: PlanarWavelets.Analyzer;
	window: WMMatrix.Window;
	filename: Files.FileName;
	w,h: SIGNED32;
	f:Files.File; r:Files.Reader;
BEGIN
	IF context.arg.GetString(filename) & context.arg.GetInteger(h, FALSE) & context.arg.GetInteger(w,FALSE) THEN
		f:=Files.Old(filename); Files.OpenReader(r,f,0);
		NEW(raw,w,h);
		MatrixUtilities.ReadInt8(r, raw);
		data:=raw[..,..];

		NEW(analyzer, Wavelets.Haar, Wavelets.default, data);
		(*NEW(analyzer, Wavelets.Cubicspline, Wavelets.periodicH, data);*)
		analyzer.AnalyzePacket(2);
		NEW( window, analyzer.data,  "Hologram - Wavelet"); window.AddWindow;

	END;
END Do4;

PROCEDURE Do*;
VAR data, temp, result: Matrix;
	map, map1, map2: ARRAY [*] OF Matrix;
	analyzer: PlanarWavelets.Analyzer;
	window: WMMatrix.Window;
BEGIN
	(*get data*)
	NEW(data,256,256);
	data[100..110,150..160]:=1;
	NEW(result,256,256);
	NEW(analyzer, Wavelets.Haar, Wavelets.default, data);
	analyzer.Analyze;

	(*redundant; just to show where things are*)
	NEW(map, 4, LEN(data,0) DIV 2, LEN(data,1) DIV 2);
	map[0]:=analyzer.data[..LEN(data,0)DIV 2-1, .. LEN(data,1)DIV 2-1];
	map[1]:=analyzer.data[..LEN(data,0)DIV 2-1, LEN(data,1)DIV 2 ..];
	map[2]:=analyzer.data[LEN(data,0)DIV 2 .., .. LEN(data,1)DIV 2-1];
	map[3]:=analyzer.data[LEN(data,0)DIV 2 .., LEN(data,1)DIV 2 ..];
	NEW(window, map[0], "00"); window.AddWindow;
	NEW(window, map[1], "01"); window.AddWindow;
	NEW(window, map[2], "10"); window.AddWindow;
	NEW(window, map[3], "11"); window.AddWindow;
	(*NEW(window, analyzer.data[..LEN(data,0)DIV 2-1, .. LEN(data,1)DIV 2-1],"w0"); window.AddWindow;
	NEW(window, analyzer.data[..LEN(data,0)DIV 2-1, LEN(data,1) DIV 2 ..],"w1"); window.AddWindow;
	NEW(window, analyzer.data[LEN(data,0)DIV 2 .., .. LEN(data,1) DIV 2-1],"w2"); window.AddWindow;
	NEW(window, analyzer.data[LEN(data,0) DIV 2 .., LEN(data,1) DIV 2 ..],"w3"); window.AddWindow;
	*)



END Do;

PROCEDURE Do1*;
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
	show=TRUE;
VAR data, temp, result: Dataset;
	target:Matrix;
	window, resultWindow, errorWindow: WMMatrix.Window;
	net:Network;
	cl: ConvLayer;
	ml:MaxPoolLayer;
	i, rounds:SIGNED32;
	e: Datatype;
BEGIN
	IF ~context.arg.GetInteger(rounds,FALSE) THEN rounds:=100 END;
	NEW(data, [200,300]);
	data[100..110,150..160]:=1;
	data[60..80, 80..100]:=1.0;
	data[90..100, 20..30]:=1.0;
	data[20..30, 60..80]:=1.0;
	data[120..130, 60..80]:=1.0;
	data[140..150, 100..120]:=1.0;
	NEW(window, data, "data"); window.AddWindow;

	NEW(net);
	(*NEW(cl, [10,10], RectifiedLinear, RectifiedLinearDerivative); *)
	NEW(cl, [20,30], Tanh, TanhDerivative);
	net.Append(cl);
	NEW(ml); net.Append(ml);

	(*NEW(cl, [10,10], RectifiedLinear, RectifiedLinearDerivative); ml.Connect(cl);*)
	NEW(cl, [10,15], Tanh, TanhDerivative); net.Append(cl);
	NEW(ml); net.Append(ml);

	NEW(cl, [10,15], Linear, LinearDerivative); net.Append(cl);
	NEW(ml); net.Append(ml);

	result:=net.Evaluate(data);
	NEW(resultWindow, result, "output"); resultWindow.maxInterpolation := WMGraphics.ScaleBox;  resultWindow.AddWindow;

	(*target:=Util.RandomMatrix(LEN(result,0),LEN(result,1),Util.Uniform);*)
	NEW(target, LEN(result,0),LEN(result,1));
	target[..BY 2,..]:=1.0; target[1,0]:=-0.01; (* force signed display *)
	NEW(window, target, "target"); window.maxInterpolation := WMGraphics.ScaleBox; window.AddWindow;
	FOR i:=0 TO rounds-1 DO
		net.TrainingRound(data,target);

		e:=SUM(ABS(net.error));
		IF i MOD (rounds DIV 100)=0 THEN
			context.out.Int(i,0); context.out.String("   "); context.out.Float(e,12); context.out.Ln; context.out.Update;
		END;
		IF show THEN
			IF resultWindow#NIL THEN resultWindow.SetImage(net.last.y) END;
			IF errorWindow=NIL THEN NEW(errorWindow, net.error, "error"); errorWindow.maxInterpolation := WMGraphics.ScaleBox; errorWindow.AddWindow;
			ELSE errorWindow.SetImage(net.error);
			END;
		END;
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
	NEW(convolver); convolver.SetInputSize(256,256);
	IF convolver.SetKernels(filter) & convolver.SetOutputShape(EulFftwConvolve.Valid) THEN result := convolver.Convolve(data);
	ELSE HALT(200)
	END;

	NEW(window, data, "data"); window.AddWindow;
	NEW(window, filter, "filter"); window.AddWindow;
	NEW(window, result, "result"); window.AddWindow;
END TestConvolveEul;

END MLConvNet2D.

(*
Testing:
note that maps display scalar values, with white=only positive, and red/blue indicating positive and negative values *)
MLConvNet2D.TestTraining 10000 ~
MLConvNet2D.TestConvolve~

SystemTools.FreeDownTo WMMatrix MLConvNet2D~
