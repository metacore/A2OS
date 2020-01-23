MODULE MLNeuralNet;   (** Patrick.Hunziker@unibas.ch  Date: 2008-2015  **)
(**
Artificial Neural Network of arbitrary levels with arbitrary number of units of linear or sigmoid type
 trains the network with Input/Output pairs to find configuration of network weights with
 minimal individual and overall error

 Restricted Boltzmann machines for unsupervised training.
 *)

 (*
 CAVE: too high input values ~>10 not well handled (undetected sigmoid function overflow)...,
 normalize values to lower ones... => Normalize input and output range first to range  {-1 .. 1 }  !

 ToDo: Performance bottlenecks:
 - FLOAT32 instead of FLOAT64
 - SSE instead of scalar.
 - better All2 procedure.
 - for DBNs, packed boolean arrays may be considered together with SSE. Also, fixedpoint, e.g. 16Bit, may be good for parallelization and performance.
 - Matrix multiplication with transpose is performed consecutively (with very slow isolated transpose)  instead of in one fast transpose/multiply. An earlier version of MatOberon did it better.
 *)

(* Here, a neural network is mapped to a series of matrix multiplications and ALL(Sigmoid()) transformations *)


(* HERE is a key paper about deep learning for document retrieval, DBNs etc from https://www.cs.utoronto.ca/~rsalakhu/papers/semantic_final.pdf*)

(*! TO DO
	-resolve question of binary input units and binary hidden units; probably, inputs and hidden units should just be of the same type. See Hinton, UTML TR2010-003, p
		see discussion in chapter 13, and in chapter 3 about gaussian visible and hidden units
	-backprop: sigmoid or linear ? see Hinton tutorial,  chapter 3.2: should initially be stochastic 1/0 of sigmoid (at least for binary data) but finaly propagate the probability (sigmoid)
		note: for non-binary data, a smaller learning rate may be needed
	-dynamic increase in eta durin gtraining ?
	- adapt nonlinear transform functions so that they can be used in All1V instead of All1 ?. But for later use of ALL() operator, this may be a bad idea.
*)


(*! to do: SoftMax for multidimensional classification, see wikipedia*)
(*! to do: Conjugate gradient for batch optimization of 1000 samples at once in backpropagation learning*)
(* to do: better adaptive learning rate *)
(* Some tricks:  LeCun, Y.; Bottou, L.; Orr, G.; Muller, K. (1998). Orr, G.; Muller, K., eds. Efficient BackProp (PDF). Neural Networks: Tricks of the trade (Springer). ISBN 3-540-65311-2
	Sigmoid function: tricks for nonlinear response in ANNs:
	- symmetric sigmoids like tanh() may converge faster than logistic function
	- recommended is f(x)= 1.7159 * tanh (2/3* x)
	- sometimes it it helpful to add a small linear term, like f(x)=tanh(x)+ a*x  to avoid flat spots.
	Output:
	- do not put on saturated values of sigmoid function because of potential instabilities. using the f(x)=1.7*tanh from above, -1 and +1 are adequate for binary target
	Normalize inputs and outputs.
	In stochastic descent, feed new samples in a way to maximize novelty, i.e. avoiding ordered feeding of similar data.

	In deep neural networks, the rectifier function f(x)=MAX(x,0);  (https://en.wikipedia.org/wiki/Rectifier_%28neural_networks%29) is the most widely used variant; see also the 'noisy' and 'leaky' variants on that page

	Vanishing Gradient Problem leading to slow learning in deep networks: https://en.wikipedia.org/wiki/Vanishing_gradient_problem
	*)


(* to do: detect and avoid overflow when eta chosen too high  for given problem. some problems stem from exp(x) overflow in sigmoid functions *)

IMPORT Out := KernelLog, MathL, MatrixBase, Math, PMath, Util := MatrixUtilities,  WMMatrix, MLBase, Files, Commands, Random,
	Kernel, FoxArrayBase,KernelLog, PMathSSE, Streams, MatrixIterativeSolvers;

CONST
	linear* = 0;  sigmoid* = 1;  softmax *= 2;

	DefaultStartweight* = 0.05;   (*may need adaptation depending on network node number*)
	DefaultEta* = 0.0001;   (* approximation step *)
	DefaultAlpha* = 0.5;   (*momentum for gradient descent, either =0 or some small value; is adapted during learning*)
	DefaultDecay* = 0;   (*decay of network weights -> leads to elimination of near-irrelevant nodes and smaller number of relevant weights*)
	DefaultEpisodes* = 10000;
	DefaultShowError* = TRUE;

	EpsL*=1.11022302463E-16;



TYPE
	IntVector* = ARRAY [ * ] OF SIGNED32;
	Datatype* = MatrixBase.Datatype;
	Vector* = MatrixBase.Vector;
	Matrix* = MatrixBase.Matrix;
	Dataset*= ARRAY [?] OF Datatype;
	Function*= PROCEDURE(x:Datatype):Datatype;
	Function2*=PROCEDURE(x,delta:Datatype):Datatype;
	FilterProc*=PROCEDURE{DELEGATE}(VAR data: ARRAY[?] OF Datatype)

TYPE
	Layer* = OBJECT
	VAR
		out*, (*activations of this layer*)
		dout,
		weights, (*weights connecting previous layer to this layer*)
		dweights, (*weight change*)
		oldweights: (*weights before last weight update, for momentum*)
		   Matrix;
		type*: SIGNED32; (*linear, sigmoid, softmax etc*)
		Error*: Datatype;
		next, last*: Layer;
		eta, alpha, startweight, decay: Datatype;   (*decay of network weights -> leads to elimination of near-irrelevant nodes and smaller number of relevant weights*)
		function:Function;
		derivativeDelta:Function2;
		(* This is the neural network training procedure:
			A) For gradient descent: do all samples at  at time;
			B) For stochastic search: in an inner loop, do oneRound for each training samples (eta: stepsize: e.g. 0.05-0.3 to start with);
			C) In an outer loop, do the whole training a few thousand times or untila set of validation samples gives the minimum error *)

		(*this procedure  calculates the activation of a layer, propagates  it (recursively) to the next layer and returns (backpropagates) the cost function derivative for the previous layer
		the backpropagated error must be multiplied with the derivative delta of the weighted input first though.
		*)
		(* TO DO: also consider error backpropagation described in Bastian Leibe 2014. Seminar Report, Understanding Convolutional Neural Networks *)
		PROCEDURE round*( CONST in, target: Matrix ): Matrix;
		BEGIN
			IF (LEN( out, 1) # LEN(weights,1)) OR (LEN(out,0)#LEN(in,0)) THEN NEW(out, LEN(in,0), LEN(weights,1)) END;
			IF (LEN( dout,1)#LEN(weights,1)) OR (LEN(dout,0)#LEN(in,0)) THEN NEW(dout,LEN(in,0), LEN(weights,1)) END;

			out := in * weights;
			IF type = sigmoid THEN
				out:=ALL(out,function)  (*apply sigmoid to activations*)
			ELSIF type = softmax THEN
				SoftMax(out);
			END;

			IF next # NIL THEN
				dout := next.round( out, target ) (*propagate input values to next layer, get the error derivative for this layer back.*)
			ELSE(*output layer*)
				dout := target - out; (*same for normal output layer with quadratic loss or softmax with cross entropy loss*)
			END;
			Error := (dout +* dout)/LEN(dout,0)/LEN(dout,1);   (*L2 Norm. Not correct for a softmax output layer*)

			IF alpha # 0 THEN
				oldweights := alpha * dweights
			END;

			IF type = sigmoid THEN
				dout:=All2(out, dout, derivativeDelta ); (*All2M( dout, out, dout, derivativeDelta ); *)
			END;  (* *)

			dweights := in`* dout ;   (*delta weight calculation*)
			(*IF decay THEN (*! to be implemented*)END;	*)

			dweights := dweights * eta; (*apply learning rate*)
			IF alpha # 0 THEN dweights := dweights + oldweights END;   (*momentum*)
			weights := weights + dweights;

			RETURN dout * weights`;
		END round;

		PROCEDURE evaluate*( CONST in: Matrix ): Matrix;
		BEGIN
			IF (LEN( out, 1 ) # LEN( weights, 1 )) OR (LEN( out, 0 ) # LEN( in, 0 )) THEN NEW( out,  LEN( in, 0 ), LEN( weights, 1 ) );  END;
			out := in * weights;
			IF next # NIL THEN
				IF type = sigmoid THEN
					(*out:=All1(out,function) *) out:=ALL(out,function)
				END;
				RETURN next.evaluate( out );   (*propagate input values recursively*)
			ELSE
				IF type = sigmoid THEN
					(*out:=All1(out,function) *) out:=ALL(out,function)
				ELSIF type=softmax THEN
					out:=AllVec(out,SoftMax);
				END;
				RETURN out;
			END;
		END evaluate;

		(**
			Initializes weights to a range of values between -startweight and +startweight.
			Not a very good initialization, but is deterministic and guaranteed to break symmetry even with constant input data
		*)
		(* TO DO: also consider better weight initialization, as  described in Bastian Leibe 2014. Seminar Report, Understanding Convolutional Neural Networks *)

		PROCEDURE initWeights;
		VAR
			i, j: SIGNED32;
			deltaX, x: Datatype;
		BEGIN
			deltaX := 2 * startweight / (LEN( weights, 0 ) * LEN( weights, 1 ));  x := -startweight;
			FOR i := 0 TO LEN( weights, 0 ) - 1 DO
				FOR j := 0 TO LEN( weights, 1 ) - 1 DO
					weights[i, j] := x;  x := x + deltaX
				END;
			END
		END initWeights;

		PROCEDURE SetWeights(CONST initW: ARRAY[*,*] OF Datatype);
		VAR
		BEGIN
			ASSERT(LEN(initW)=LEN(weights));
			weights:=initW;
		END SetWeights;

	END Layer;

(* Layer corresponding to restricted Boltzmann machine, usually has binary/Bernoulli visible and hidden nodes
 RBMs are suited for unsupervised learning using the CD or the PCD algorithms.
 For implementation details, study "Geoffrey Hinton, A practical guide to training restricted Boltzmann machines, UTML TR 2010-003, 2010"
  *)
TYPE	RestrictedBoltzmannMachine* = OBJECT
	CONST DefaultStochasticEta=0.1;
		DefaultBatchEta=0.0001; (*make dependent from batch size*)
		DefaultWeightDecay=0.0001;
	VAR (*out*, *) weights-, dweights-, oldDweights, oldweights, reconstructed, posGradient,negGradient, hidden, hiddenAll: Matrix;
		out*, delta: Dataset;
		hid, recon, v: Vector;
		hidden3, reconstructed3, dout3: Dataset;
		type*: SIGNED32;
		weightDecayType*:SIGNED32; (* 0=non, 1=L1, 2=L2;   L2 dampens strong weights, L1 drives many less important weights to zero*)
		Error*, weightL2, weightL1: Datatype;
		eta*, alpha*, weightDecay*, startweight: Datatype;
		hidBias, visBias: Datatype; (*? should bias be  a matrix ? *)
		function:Function;
		derivativeDelta:Function2; (*needed for backpropagation learning*)
		binary:BOOLEAN;
		weightWindow*, dweightWindow*: WMMatrix.Window;
		next*,prior*: RestrictedBoltzmannMachine;
		conjugateGradient:MatrixIterativeSolvers.ConjugateGradient;

		PROCEDURE &Init*;
		BEGIN
			startweight := DefaultStartweight;
			eta:=0.1; (* works for single element stochastic update; reduce by N for mini-batches of N samples*)
			eta:=DefaultBatchEta; (*hinton recommends that weight updates ~ weights/1000 , possibly smaller if many small inputs. shrinking dweights towards the end of training, or weight averaging, may smooth out noise*)
			weightDecayType:=0; weightDecay:=DefaultWeightDecay;
			(*alpha:=0.5;*)

			(* see Semantic Hashing by Salakhutdinov & Hinton, https://www.cs.utoronto.ca/~rsalakhu/papers/semantic_final.pdf
			eta:=0.1 ? divided by MiniBatchCount;
			momentum:=0.9;
			weightDecay:=0.0002*weight*Eta;
			*)
		END Init;

		PROCEDURE Create*(nVisible, nHidden:SIGNED32; function:Function; derivativeDelta:Function2; binary:BOOLEAN);
		BEGIN
			NEW(hidden, 1, nHidden);
			NEW(weights, nVisible, nHidden);
			SELF.function:=function;
			SELF.derivativeDelta:=derivativeDelta;
			initWeights;
			oldweights:=weights;
			SELF.binary:=binary; (*classically, is binary, but can encode input better with continous value. Binary leads to an useful information bottleneck that improves training. Binary programmin structures might lead to very fast code . *)
		END Create;

		(* from wikipedia: restricted Boltzmann machine:
		The basic, single-step contrastive divergence (CD-1) procedure for a single sample can be summarized as follows:
		Take a training sample v, compute the probabilities of the hidden units and sample a hidden activation vector h from this probability distribution.
		Compute the outer product of v and h and call this the positive gradient.

		From h, sample a reconstruction v' of the visible units, then resample the hidden activations h' from this. (Gibbs sampling step)
		Compute the outer product of v' and h' and call this the negative gradient.
		Let the weight update to w_{i,j} be the positive gradient minus the negative gradient, times some learning rate: \Delta w_{i,j} = \epsilon (vh^\mathsf{T} - v'h'^\mathsf{T}).
		The update rule for the biases a, b is defined analogously.
		*)
		PROCEDURE ContrastiveDivergenceStep*( CONST visible: Matrix ): Matrix; (* or (CONST (visible, hidden:Matrix):Matrix; have Boolean/Bernoullian value *)
		CONST GibbsSteps=1;
		VAR i:SIGNED32;
		BEGIN
			hidden := visible * weights (*+ hidBias?*);

		(* ---  optionally repeating this learning rule, i.e. N Gibbs steps, can improve the model *)
			IF function#NIL THEN All1V(hidden,Sigmoid1); (*hidden:=All1(hidden,function) *) (*hidden:=ALL(hidden,function) *) END;
			IF binary THEN hidden:=TruncateStochastic(hidden) END; (* needs work ... *)
			IF weightDecayType=1 THEN weightL1:= SUM(ABS(weights))(*/LEN(weights,0)/LEN(weights,1)*); weights:=  weights * (1-weightDecay*eta * weightL1) ; (*? need to normalize weightL1 by number of weights? *)
			ELSIF weightDecayType=2 THEN weightL2:= weights+*weights(*/LEN(weights,0)/LEN(weights,1)*); weights:=  weights * (1-weightDecay*eta * weightL2)
			END;
			reconstructed:=visible;
			FOR i:=0 TO GibbsSteps-1 DO (*can take some computations out of the loop*)
				posGradient:=reconstructed` * hidden; (*outer product*)
				reconstructed := hidden * weights` (*+ visBias ?*);
				hidden := reconstructed * weights (*+hidBias  ?*);
				IF function#NIL THEN (*hidden:=All1(hidden,function) *) hidden:=ALL(hidden,function)  END;
				IF binary THEN hidden:=TruncateStochastic(hidden) END; (*? does sampling need improvement, see text above this procedure ?*)
				negGradient:=reconstructed` * hidden; (*outer product*)
			END;
		(* -----------------------*)
			IF alpha # 0 THEN oldDweights := alpha * dweights END;

			dweights := posGradient-negGradient;
			dweights := eta * dweights;
			IF (alpha # 0)&(LEN(dweights)=LEN(oldDweights)) THEN dweights := dweights + oldDweights END;   (*should momentum be used here ??*)
			(*dweights:=ALL(dweights,constrain01);*)
			weights := weights + dweights;
			RETURN hidden* weights`;
		END ContrastiveDivergenceStep;

		(*works - does it perform sufficiently better to justify separate implementation ?*) (* probably not - minibatches are usually used to benefit from fast matrix-matrix multiplications*)
		(*
		PROCEDURE ContrastiveDivergenceStepVector*( CONST visible: Vector ): Vector; (* or (CONST (visible, hidden:Matrix):Matrix; have Boolean/Bernoullian value *)
		CONST GibbsSteps=1;
		VAR i:SIGNED32;
		BEGIN
			hid := visible * weights + hidBias(*?*);

		(* ---  optionall yrepeating this learning rule, i.e. N Gibbs steps, can improve the model *)
			IF function#NIL THEN hid:=ALL(hid,function) END;
			IF binary THEN hid:=Truncate(hid) END; (*binarization needs work ...*)
			recon:=visible;
			FOR i:=0 TO GibbsSteps-1 DO (*can take some computations out of the loop*)
				posGradient:=recon ** hid; (*outer product*)

				recon := weights * hid + visBias (*?*);
				hid := recon * weights +hidBias(*?*);
				IF function#NIL THEN hid:=ALL(hid,function) END;
				IF binary THEN (*hidden:=ALL(hidden, BinarizeHalf); *)hid:=Truncate(hid) END;
				negGradient:=recon ** hid; (*outer product*)
			END;
		(* -----------------------*)
			IF alpha # 0 THEN oldDweights := alpha * dweights END;
			dweights := posGradient-negGradient;
			dweights := eta * dweights;
			IF alpha # 0 THEN dweights := dweights + oldDweights END;   (*should momentum be used here ??*)
			(*dweights:=ALL(dweights,constrain01);*)
			weights := weights + dweights;
			v:=weights*hid;
			RETURN v;
		END ContrastiveDivergenceStepVector;
		*)
		(*
		PROCEDURE PCDStep;
		BEGIN
			decide how to initialize persistent chain:
        		# for CD, we use the newly generated hidden sample
        		# for PCD, we initialize from the old state of the chain

		END PCDStep;
		*)

		PROCEDURE GibbsVHV;
		BEGIN

		END GibbsVHV;

		PROCEDURE GibbsHVH;
		BEGIN

		END GibbsHVH;

		PROCEDURE freeEnergy(CONST sample:Matrix):Datatype;
		BEGIN
			(*temp:=sample*weights + hBias;
			vbiasTerm:=SUM(sample*vBias);
			hiddenTerm:=...
			*)
		END freeEnergy;

		PROCEDURE cost;
		BEGIN
			(*
			pseudo-likelihood is a better proxy for PCD
			reconstruction cross-entropy is a better proxy for CD
			*)
		END cost;

		PROCEDURE Propagate*( CONST in: Dataset );
		VAR j:SIGNED32;
		BEGIN
			IF DIM(in)=2 THEN
				SameDimension(hiddenAll, [LEN(in,0), LEN(weights,1)]);
				hiddenAll := in * weights;
				IF function#NIL THEN All1V(hiddenAll,Sigmoid1);(* hiddenAll:=All1(hiddenAll,function) *)(*hiddenAll:=ALL(hiddenAll,function)*) END;  (* should function include hidBias, or code it separately ?*)
			ELSIF DIM(in)=3 THEN
				SameDimension(hidden3, [LEN(in,0), LEN(in,1), LEN(weights,1)]);
				FOR j:=0 TO LEN(in,0)-1 DO
					hidden3[j, .. , ..] := in[j,..,..] * weights;
				END;
				IF function#NIL THEN All1V(hidden3,Sigmoid1); (*hidden3:=All1(hidden3,function) *)(* hidden3:=ALL(hidden3,function) *)END;
			END;

		END Propagate;

		(* includes chain of children - should this be kept or moved to DBN ?*)
		PROCEDURE Evaluate*( CONST in: Dataset ): Dataset;
		VAR j:SIGNED32;
		BEGIN
			IF DIM(in)=2 THEN
				SameDimension(out, [LEN( in, 0 ), LEN( weights, 1 )] );
				out := in * weights;
			ELSIF DIM(in)=3 THEN
				SameDimension(out, [LEN(in,0), LEN(in,1), LEN(weights,1)]);
				FOR j:=0 TO LEN(in,0)-1 DO
					out[j,..,..]:=in[j,..,..] * weights;
				END;
			END;
			IF function#NIL THEN All1V(hidden3,Sigmoid1); (*out:=All1(out,function) ; *)(*out:=ALL(out,function) *)END;
			RETURN out;
		END Evaluate;

		PROCEDURE BackPropagate*( CONST out: Dataset);
		VAR j:SIGNED32;
		BEGIN
			IF DIM(out)=2 THEN
				SameDimension(reconstructed, [LEN(out,0), LEN(weights,0)]);
				reconstructed:=out* weights` (*? + visBias *);
				(*All1V(reconstructed, Sigmoid1);*)
				(*!XX sigmoid backpropagation would be correct acc.to Hinton - in my understanding it should rather be inv sigmoid ?
					but for small x values, sigmoid(x) function is anyway almost linear.
					in my experiments, using sigmoid was longer computation with no better result.*)
			ELSIF DIM(out)=3 THEN
				SameDimension(reconstructed3, [LEN(out,0), LEN(out,1), LEN(weights,0)]);
				FOR j:=0 TO LEN(out,0)-1 DO
					reconstructed3[j,..,..]:= out[j,..,..]* weights` (*? + visBias*);
				END;
				(*All1V(reconstructed3, Sigmoid1);*)(*!XX see above*)
				(*reconstructed:=reconstructed3[0,..,..];*)
			END;

		END BackPropagate;

		(*to do: find out, if the implemented conjugate gradient procedure is beneficial, compared to simple backpropagation as in "Network" *)
		(* conjugate gradient may be good or bad ...: http://www.researchgate.net/publication/3857463_Overfitting_and_neural_networks_conjugate_gradient_andbackpropagation *)
		PROCEDURE BackPropError*( CONST in, dout: Dataset; useConjugateGradient:BOOLEAN):Dataset;
		VAR i,j:SIGNED32;
		BEGIN
			(*! unfinished, untested *)

			IF ~useConjugateGradient THEN
				IF DIM(dout)=2 THEN
					SameDimension(dout3, LEN(dout));
					IF alpha # 0 THEN oldDweights := alpha * dweights END;
					IF type = sigmoid THEN dout3:=All2(out, dout, derivativeDelta ); (*All2M( dout, out, dout, derivativeDelta ); *) END;  (* ? is this really needed *)
					dweights := in`* dout3 ;   (*delta weight calculation*)
					(*IF decay THEN (*! to be implemented*)END;	*)
					dweights := dweights * eta;
					IF alpha # 0 THEN dweights := dweights + oldDweights END;   (*momentum*)
					weights := weights + dweights;
					RETURN dout * weights`;

				ELSIF DIM(dout)=3 THEN
					SameDimension(dout3, LEN(dout));
					IF alpha # 0 THEN oldDweights := alpha * dweights END;
					IF type = sigmoid THEN dout3:=All2(out, dout, derivativeDelta ); (*All2M( dout, out, dout, derivativeDelta ); *) END;  (* ? is this really needed *)

					dweights:=0;
					FOR j:=0 TO LEN(out,0)-1 DO
						dweights:=dweights+ in[j,?]`* dout3[j];
					END;

					dweights := dweights * eta;
					IF alpha # 0 THEN dweights := dweights + oldDweights END;   (*momentum*)
					weights := weights + dweights;
					(*IF decay THEN (*! to be implemented*)END;	*)

					SameDimension(RESULT, LEN(in) );
					FOR j:=0 TO LEN(dout,0)-1 DO
						RESULT[j,..,..]:= dout[j,..,..]* weights` (*? + visBias*);
					END;
					RETURN RESULT;
				END;
			ELSE
				HALT(200);
				(*
				IF conjugateGradient=NIL THEN NEW(conjugateGradient, weights`); (* here, a transposed version would be beneficial*)
				ELSE conjugateGradient.Init(weights`);
				END;
				(*??*)
				IF DIM(dout)=2 THEN
					SameDimension(reconstructed, [LEN(dout,0), LEN(weights,0)]);
					FOR i:=0 TO LEN(dout,0)-1 DO
						reconstructed[i]:=conjugateGradient.Solve(out[i,..]);(*? + visBias *)
					END;
				ELSIF DIM(out)=3 THEN
					SameDimension(reconstructed3, [LEN(out,0), LEN(out,1), LEN(weights,0)]);
					FOR j:=0 TO LEN(out,0)-1 DO
						FOR i:=0 TO LEN(out,1)-1 DO
							reconstructed3[j,i,..]:=conjugateGradient.Solve(out[j,i,..]);(*? + visBias*)
						END;
					END;
				END;
				*)
			END;
		END BackPropError;


		PROCEDURE initWeights;
		VAR i, j: SIGNED32;  deltaX, x: Datatype;
		BEGIN
			(*deltaX := 2 * startweight / (LEN( weights, 0 ) * LEN( weights, 1 ));  x := -startweight;
			FOR i := 0 TO LEN( weights, 0 ) - 1 DO
				FOR j := 0 TO LEN( weights, 1 ) - 1 DO weights[i, j] := x;  x := x + deltaX END;
			END;*)
			weights:=2*(-0.5+Util.RandomMatrix(LEN(weights,0), LEN(weights,1), Util.Uniform));(*random, mean zero, range -1 to 1*)
			weights:= 1/LEN(weights,1) * weights; (*each input is connected to all outputs -> normalize by output count*)
		END initWeights;

	END RestrictedBoltzmannMachine;


TYPE
	(* artificial neural network *)
	Network* = OBJECT (MLBase.LearningMachine)
	VAR InMatrix*, TargetMatrix*, ErrorMatrix*: Matrix;
		ValidationIn*, ValidationTarget*, ValidationResult: Matrix;
		Inputs, Outputs, trainingEpisodes*: SIGNED32;
		Layers*: Layer; (* linked list of Layers *)
		trainingError*: Datatype;
		eta*, alpha*, startweight*, decay*: Datatype;
		bias*: BOOLEAN; (* add additional input containing constant at 1.0 to allow fiting target value even if all inputs are zero  - not yet implemented*)
		showError*:BOOLEAN;
		function*:Function;
		derivativeDelta*:Function2;


		PROCEDURE & Init* ();
		BEGIN
			eta := DefaultEta;  alpha := 0;  decay := DefaultDecay;
			startweight := DefaultStartweight;
			trainingEpisodes := DefaultEpisodes;  showError:=DefaultShowError;
			function:=Sigmoid;
			derivativeDelta:=SigmoidDerivativeDelta;
		END Init;


	(** Builds artificial neural network structure from scratch.Chain of levels is forward and backward connected
			Nr of levels=LEN(Nodes);
			Nr of nodes in level i = Nodes [i];
			Type of nodes in level i:
			1st.Level = Input level (no type to be defined)
			2nd level = first hidden level, type is Type[0]
			Type of nodes in level i= Type[i-2]
			last level = output level.*)
		PROCEDURE Build*( CONST Nodes: IntVector;  CONST Type: IntVector );   (*(Nodes:ARRAY OF SIGNED16; Type:ARRAY OF SIGNED16):Layer;*)
		VAR
			i: SIGNED32;  L: Layer;
		BEGIN
			Inputs := Nodes[0];  Outputs := Nodes[LEN( Nodes,0 ) - 1];
			ASSERT( LEN( Nodes ) = LEN( Type ) + 1, 100 );  ASSERT( LEN( Nodes ) > 1, 101 );  i := 0;
			L := NewLayer( Nodes[0], Nodes[1], Type[0] );
			L.eta := eta;  L.alpha := alpha;  L.decay := decay;  L.initWeights;
			L.function:=function; L.derivativeDelta:=derivativeDelta;
			Layers := L;
			IF bias THEN (*! to be implemented*)  END;
			FOR i := 1 TO LEN( Nodes,0 ) - 2 DO
				L.next := NewLayer( Nodes[i], Nodes[i + 1], Type[i] );  L := L.next;
				L.eta := Layers.eta;  L.alpha := Layers.alpha;  L.decay := Layers.decay;
				L.startweight := Layers.startweight;  L.initWeights;
				L.function:=function; L.derivativeDelta:=derivativeDelta;
				Layers.last := L;
			END;
		END Build;

		PROCEDURE Build2*(CONST Nodes: IntVector; CONST Type: IntVector; CONST InitWeights: Matrix); (*todo: initialize multiple layers*)
		VAR
			i: SIGNED32;
			L: Layer;
		BEGIN
			Build(Nodes,Type);
			L:=Layers;

			L.SetWeights(InitWeights);
			(*FOR i:=1 TO LEN(Nodes,0)-2 DO
				L.SetWeights(InitWeights[i]);
				L:=L.next;
			END;*)
		END Build2;

		(** Precondition: training data arranged in matrices:  Samples[samples,features]; Targets[samples, results] *)
		PROCEDURE Learn*( CONST Samples, Targets: Matrix );
		VAR episode:SIGNED32; l:Layer;
		BEGIN
			InMatrix := Samples;  TargetMatrix := Targets;
			FOR episode := 0 TO trainingEpisodes - 1 DO
				(* propagate InMatrix through network, use deviation from TargetMatrix for backpropagation of error, report backpropagated ErrorMatrix*)
				ErrorMatrix := Layers.round( InMatrix, TargetMatrix );

				IF showError & (episode MOD (trainingEpisodes DIV 100) = 0) THEN
					Out.String("training ... residual "); Util.OutFloat(Layers.last.Error,20,13,0);
					IF LEN(ValidationIn,0)>0 THEN
						ValidationResult:=EvaluateVectorN(ValidationIn)-ValidationTarget; Util.OutFloat(ValidationResult+*ValidationResult,20,13,0);
					END;
					Out.Ln;
				END;
				(*could do  adaptive change of stepsize over time  here *)
			END;
			trainingError := Layers.last.Error;
			IF showError THEN Out.String("training - final residual "); Util.OutFloat(trainingError,20,13,0); Out.Ln; END;
		END Learn;

		PROCEDURE EvaluateVector*( CONST Features: Vector ): Vector;   (*implementation limitation:  1D = single feature vector, and 2D = multiple feature vectors*)
		VAR inM, outM: Matrix;
		BEGIN
			NEW( inM, 1, Inputs);
			 inM[0] := Features;
			 outM := Layers.evaluate( inM );
			 RETURN outM[0]
		END EvaluateVector;

		PROCEDURE EvaluateVectorN*( CONST Features: Matrix ): Matrix;   (*implementation limitation:  1D = single feature vector, and 2D = multiple feature vectors*)
		BEGIN
			RETURN Layers.evaluate( Features );
		END EvaluateVectorN;

	END Network;

(** Wikipedia:  AutoEncoder = an artificial neural network used for learning efficient codings.
Architecturally, the simplest form of the autoencoder is a feedforward, non-recurrent neural net that is
very similar to the multilayer perceptron (MLP), with an input layer, an output layer and one or more hidden layers connecting them.
The difference with the MLP is that in an autoencoder, the output layer has equally many nodes as the input layer,
and instead of training it to predict some target value y given inputs x,
an autoencoder is trained to reconstruct its own inputs x.

an alternative architecture is described in
http://deeplearning4j.org/deepautoencoder.html
A deep autoencoder is composed of two, symmetrical deep-belief networks that typically have four or five shallow layers representing the encoding half of the net,
and second set of four or five layers that make up the decoding half.
The layers are restricted Boltzmann machines, the building blocks of deep-belief networks.
Use cases ,e.g. for image search or for topic modeling (Watson) or document retrieval are also described there.
*)
(*for  use in document retrieval including noise for binarization see
https://www.cs.utoronto.ca/~rsalakhu/papers/semantic_final.pdf
*)
TYPE AutoEncoder=OBJECT(Network)
	END AutoEncoder;


(* see theory in wikipedia
for implementation tricks,  http://deeplearning.net/tutorial/rbm.html *)
TYPE	DeepBelieveNetwork*= OBJECT (MLBase.LearningMachine) (*! untested*)
	(* Wikipedia:
	A deep belief network is a generative graphical model, or alternatively a type of deep neural network,
	composed of multiple layers of latent variables ("hidden units"), with connections between the layers but not between units within each layer.
	When trained on a set of examples in an unsupervised way, a DBN can learn to probabilistically reconstruct its inputs.
	The layers then act as feature detectors on inputs.
	After this learning step, a DBN can be further trained in a supervised way to perform classification.

	DBNs can be viewed as a composition of simple, unsupervised networks such as restricted Boltzmann machines (RBMs) or autoencoders,
	where each sub-network's hidden layer serves as the visible layer for the next.
	This also leads to a fast, layer-by-layer unsupervised training procedure, where contrastive divergence is applied to each sub-network in turn,
	starting from the "lowest" pair of layers (the lowest visible layer being a training set).
	The observation that DBNs can be trained greedily, one layer at a time, has been called a breakthrough in deep learning
	*)
		VAR
			layers*, last: RestrictedBoltzmannMachine;
			layercount:SIGNED32;
			persistent:ANY;
			log*: Streams.Writer;
			evaluation,reconstruction,delta: Dataset;
			(*evaluation3,reconstruction3,delta3: ARRAY [*,*,*] OF Datatype;*)
			error:FLOAT64;
			filter: FilterProc;
			randomLines:BOOLEAN;

			DBNeta*, DBNalpha*, DBNstartweight: Datatype;
			(*:param persistent: None for CD. For PCD, shared variable containing old state of Gibbs chain.
			This must be a shared variable of size (batch size, number of hidden units).
			   :param k: number of Gibbs steps to do in CD-k/PCD-k:
			           Returns a proxy for the cost and the updates dictionary.
			           The dictionary contains the update rules for weights and biases but also an update of the
			           shared variable used to store the persistent chain, if one is used.
			           *)

		(** nodes[0..1] are visible  and hidden node for layer 0;
			nodes [1..2] are visible and hidden nodes of layer 1, etc
			types [0..n-1] is sigmoid or linear for each layer
			function contains function pointer for desired nonlinear transform functions
			binary sets  binary or continous visible or hidden variables. weights are always continuous.
			*)
		PROCEDURE & Build*( CONST nodes: IntVector; CONST types: IntVector; function:Function; derivativeDelta:Function2; binary: BOOLEAN );
		VAR rbm: RestrictedBoltzmannMachine;
			i:SIGNED32;
		BEGIN
			DBNeta:=0.1;
			layercount:=LEN(nodes,0)-1;
			FOR i:=0 TO layercount-1 DO
				IF layers=NIL THEN
					   NEW(rbm); layers:=rbm;
				ELSE NEW(rbm.next); rbm.next.prior:=rbm; rbm:=rbm.next;
				END;
				last:=rbm;
				IF types[i]=sigmoid THEN
					   rbm.Create(nodes[i], nodes[i+1],function, NIL, binary);
				ELSE rbm.Create(nodes[i], nodes[i+1],NIL, NIL, binary);
				END;
			END;
		END Build;

		(* input: Matrix: rows=samples, columns =sample values
		 3D input: first two dimensions=sampes, last dimension =sample values*)
		PROCEDURE TrainUnsupervised*(CONST input:Dataset; iterations: SIGNED32); (*! to do: reasonable progress output,e.g. residual on backpropagation*)
		VAR rbm:RestrictedBoltzmannMachine; m,oldweights:Matrix; i,j,k,line, level,reportStep:SIGNED32; t0,t1:SIGNED32;
			alias:Dataset;
		BEGIN
			rbm:=layers;
			IF iterations<10 THEN reportStep:=1 ELSIF iterations<50 THEN reportStep:= 4 ELSE reportStep:=10 END;
			level:=0;
			(*rbm.oldweights:=rbm.weights;*)
			IF log#NIL THEN log.String("training .") ; log.Ln; log.Update;
				log.Float(input+*input/Count(input),14); log.Ln; log.Update;
			END;
			t0:=Kernel.GetTicks();
			FOR i:=0 TO iterations-1 DO
				FOR j:=0 TO LEN(input,0)-1 DO
					IF randomLines THEN line:=rand.Dice(LEN(input,0)) ELSE line:=j END;
					IF DIM(input)=2 THEN
						m:=rbm.ContrastiveDivergenceStep(input[line..line,..]); (*sample-wise*)
					ELSIF DIM(input)=3 THEN
						FOR k:=0 TO LEN(input,1)-1 DO
							(*alias:=ALIAS OF input[line,k..k,..];
							m:=rbm.ContrastiveDivergenceStep(alias);*) (*sample-wise*)
							m:=rbm.ContrastiveDivergenceStep(input[line,k..k,..]); (*sample-wise*)
						END;
					END;
				END;
				IF  i MOD reportStep = 0 THEN
					IF DIM(input)=2 THEN
						rbm.Propagate(input); rbm.BackPropagate(rbm.hiddenAll);
						IF log#NIL THEN
							t1:=Kernel.GetTicks();
							log.Int(level,6); log.Int(i,6); log.String("  "); rbm.delta:=input-rbm.reconstructed; log.Float(rbm.delta+*rbm.delta/Count(rbm.delta),14);
							log.String("; t=("); log.Int(t1-t0,0); log.String(")");log.Ln; log.Update;
							t0:=Kernel.GetTicks();
						END;
					ELSIF DIM(input)=3 THEN
						rbm.Propagate(input); rbm.BackPropagate(rbm.hidden3);
						IF log#NIL THEN log.Int(level,6); log.Int(i,6); log.String("  "); rbm.delta:= input-rbm.reconstructed3;log.Float(rbm.delta+*rbm.delta/Count(rbm.delta),14); log.Ln;  log.Update; END;
					END;
					IF rbm.weightWindow#NIL THEN rbm.weightWindow.SetImage(rbm.weights) END;
					IF rbm.dweightWindow#NIL THEN
						rbm.dweightWindow.SetImage(rbm.weights-rbm.oldweights);
						rbm.oldweights:=rbm.weights
					END;
				END;
			END;
			rbm.Propagate(input);
			IF DIM(input)=2 THEN rbm.BackPropagate(rbm.hiddenAll); (* populate reconstructed*)
			ELSIF DIM(input)=3 THEN rbm.BackPropagate(rbm.hidden3);
			END;
			IF (log#NIL)&(DIM(input)=2) THEN rbm.delta:=input-rbm.reconstructed; log.Float(rbm.delta+*rbm.delta/Count(rbm.delta),14); log.Ln;  log.Update; END;
			IF (log#NIL)&(DIM(input)=3) THEN rbm.delta:= input-rbm.reconstructed3; log.Float(rbm.delta+*rbm.delta/Count(rbm.delta),14); log.Ln;  log.Update; END;
			NEW(rbm.delta,1,1,1); Kernel.GC;(*free memory*)

			WHILE rbm.next#NIL DO
				INC(level);

				FOR i:=0 TO iterations-1 DO
					IF DIM(input)=2 THEN
						FOR j:=0 TO LEN(rbm.hiddenAll,0)-1 DO
							IF randomLines THEN line:=rand.Dice(LEN(input,0)) ELSE line:=j END;
							m:=rbm.next.ContrastiveDivergenceStep(rbm.hiddenAll[line..line]);
							(*rbm.v:=rbm.next.ContrastiveDivergenceStepVector(rbm.hiddenAll[j]); *)
						END;
					ELSIF DIM(input)=3 THEN
						FOR j:=0 TO LEN(rbm.hidden3,0)-1 DO
							IF randomLines THEN line:=rand.Dice(LEN(input,0)) ELSE line:=j END;
							FOR k:=0 TO LEN(rbm.hidden3,1)-1 DO
								(*alias:=ALIAS OF rbm.hidden3[line,k..k,..];
								m:=rbm.next.ContrastiveDivergenceStep(alias);*)
								m:=rbm.next.ContrastiveDivergenceStep(rbm.hidden3[j,k..k,..]);
								(*rbm.v:=rbm.next.ContrastiveDivergenceStepVector(rbm.hidden3[j,k,..]); *)
							END;
						END;
					END;
					IF i MOD reportStep=0 THEN
						IF DIM(input)=2 THEN
							rbm.next.Propagate(rbm.hiddenAll);
							rbm.next.BackPropagate(rbm.next.hiddenAll);
							IF (log#NIL) THEN log.Int(level,6); log.Int(i,6); log.String("  "); rbm.next.delta:=rbm.hiddenAll-rbm.next.reconstructed; log.Float(rbm.next.delta+*rbm.next.delta/Count(rbm.next.delta),14); log.Ln;  log.Update; END;
						ELSIF DIM(input)=3 THEN
							rbm.next.Propagate(rbm.hidden3);
							rbm.next.BackPropagate(rbm.next.hidden3);
							IF (log#NIL) THEN log.Int(level,6); log.Int(i,6); log.String("  "); rbm.next.delta:=rbm.hidden3-rbm.next.reconstructed3 ;log.Float(rbm.next.delta+*rbm.next.delta/Count(rbm.next.delta),14); log.Ln;  log.Update; END;
						END;
						IF rbm.next.weightWindow#NIL THEN rbm.next.weightWindow.SetImage(rbm.next.weights) END;
						IF rbm.next.dweightWindow#NIL THEN
							rbm.next.dweightWindow.SetImage(rbm.next.weights-rbm.next.oldweights);
							rbm.next.oldweights:=rbm.next.weights
						END;
					END;
				END;
				IF DIM(input)=2 THEN
					rbm.next.Propagate(rbm.hiddenAll);
					rbm.next.BackPropagate(rbm.next.hiddenAll);
					IF (log#NIL)THEN rbm.next.delta:= rbm.hiddenAll-rbm.next.reconstructed; log.Float(rbm.next.delta+*rbm.next.delta/Count(rbm.next.delta),14); log.Ln;  log.Update; END;
				ELSIF DIM(input)=3 THEN
					rbm.next.Propagate(rbm.hidden3);
					rbm.next.BackPropagate(rbm.next.hidden3);
					IF (log#NIL)THEN rbm.next.delta:= rbm.hidden3-rbm.next.reconstructed3; log.Float(rbm.next.delta+*rbm.next.delta/Count(rbm.next.delta),14); log.Ln;  log.Update; END;
				END;
				NEW(rbm.next.delta,1,1,1); Kernel.GC;(*free memory*)

				rbm:=rbm.next;
			END;

			evaluation:=Evaluate(input);
			reconstruction:=Reconstruct(evaluation);
			delta:=input-reconstruction;
			error:=(delta+*delta);
			IF log#NIL THEN
				log.String("squared signal "); log.Float(input+*input/Count(input), 14); log.Ln;
				log.String("squared error ");log.Float(error/Count(delta),14); log.Ln;  log.Update;
			END;
		END TrainUnsupervised;

				(* input: Matrix: rows=samples, columns =sample values*)
		PROCEDURE TrainUnsupervisedBatch*(CONST input:ARRAY [*,*,*] OF Datatype; iterations: SIGNED32); (*! to do: reasonable progress output,e.g. residual on backpropagation*)
		VAR rbm:RestrictedBoltzmannMachine; m,oldweights:Matrix; i,j,level,reportStep:SIGNED32; t0,t1:SIGNED32;
		BEGIN
			ASSERT(DIM(input)=3, 200);
			rbm:=layers;
			level:=0;
			oldweights:=rbm.weights;
			t0:=Kernel.GetTicks();
			IF iterations<10 THEN reportStep:=1 ELSIF iterations<50 THEN reportStep:= 4 ELSE reportStep:=10 END;
			IF log#NIL THEN
				log.String("training level "); log.Int(level,6); log.String("; squared error per sample "); log.Ln;
				log.Float(input+*input/Count(input),14); log.Ln; log.Update;
			END;
			FOR i:=0 TO iterations-1 DO
				FOR j:=0 TO LEN(input,0)-1 DO
					m:=rbm.ContrastiveDivergenceStep(input[j]); (*mini batch*)
				END;
				IF i MOD reportStep =0 THEN
					rbm.Propagate(input);
					rbm.BackPropagate(rbm.hidden3);
					IF log#NIL THEN log.Int(level,6); log.Int(i,6); log.String(" "); rbm.delta:= input-rbm.reconstructed3; log.Float(rbm.delta+*rbm.delta/Count(rbm.delta),14); log.Ln;  log.Update; END;
					IF rbm.weightWindow#NIL THEN rbm.weightWindow.SetImage(rbm.weights) END;
					IF rbm.dweightWindow#NIL THEN
						(*rbm.dweightWindow.SetImage(rbm.dweights);*)
						rbm.dweightWindow.SetImage(rbm.weights-oldweights);
						oldweights:=rbm.weights
					END;
					t1:=Kernel.GetTicks();log.String("; t=("); log.Int(t1-t0,0); log.String(")"); t0:=Kernel.GetTicks();
				END
			END;

			NEW(rbm.delta,1,1,1); Kernel.GC;(*free memory*)

			rbm.Propagate(input);
			rbm.BackPropagate(rbm.hidden3); (* populate reconstructed*)

			WHILE rbm.next#NIL DO
				INC(level);
				FOR i:=0 TO iterations-1 DO
					FOR j:=0 TO LEN(rbm.hidden3,0)-1 DO
						m:=rbm.next.ContrastiveDivergenceStep(rbm.hidden3[j,..,..]);
					END;
					IF i MOD reportStep=0 THEN
						rbm.next.Propagate(rbm.hidden3);
						rbm.next.BackPropagate(rbm.next.hidden3);
						IF log#NIL THEN log.Int(level,6);  log.Int(i,6); log.String("  SOS="); rbm.next.delta:= rbm.hidden3-rbm.next.reconstructed3; log.Float(rbm.next.delta+*rbm.next.delta/Count(rbm.next.delta),14); log.Ln;  log.Update; END;
						IF rbm.next.weightWindow#NIL THEN rbm.next.weightWindow.SetImage(rbm.next.weights) END;
						IF rbm.next.dweightWindow#NIL THEN rbm.next.dweightWindow.SetImage(rbm.next.dweights) END;
						t1:=Kernel.GetTicks();log.String("; t=("); log.Int(t1-t0,0); log.String(")"); t0:=Kernel.GetTicks();
					END;
				END;
				rbm.next.Propagate(rbm.hidden3);
				rbm.next.BackPropagate(rbm.next.hidden3);
				NEW(rbm.next.delta,1,1,1); Kernel.GC;(*free memory*)
				rbm:=rbm.next;
			END;

			evaluation:=Evaluate(input);
			reconstruction:=Reconstruct(evaluation);
			delta:=input-reconstruction;
			error:=(delta+*delta);
			IF log#NIL THEN
				log.String("squared signal "); log.Float(input+*input/Count(input), 14); log.Ln;
				log.String("squared error");log.Float(error/Count(delta),14); log.Ln;  log.Update;
			END;
		END TrainUnsupervisedBatch;


		PROCEDURE TrainSupervised*(CONST input,target:Dataset; iterations: SIGNED32);
		VAR i:SIGNED32;
			rbm: RestrictedBoltzmannMachine;
		BEGIN
			FOR i:=0 TO iterations-1 DO
				delta:=Evaluate(input);
				delta:=delta-target;
			END;
			rbm:=layers;
			HALT(200); (*! implement error backprop*)
		END TrainSupervised;


		PROCEDURE Evaluate*( CONST in: Dataset): Dataset;
		VAR rbm: RestrictedBoltzmannMachine;
		BEGIN
			rbm:=layers;
			rbm.Propagate(in);
			IF DIM(in)=2 THEN
				WHILE rbm.next#NIL DO
					rbm.next.Propagate(rbm.hiddenAll);
					rbm:=rbm.next
				END;
				RETURN rbm.hiddenAll
			ELSIF DIM(in)=3 THEN
				WHILE rbm.next#NIL DO
					rbm.next.Propagate(rbm.hidden3);
					rbm:=rbm.next
				END;
				RETURN rbm.hidden3
			END;
		END Evaluate;

		PROCEDURE Reconstruct*( CONST data: Dataset ): Dataset;
		VAR rbm: RestrictedBoltzmannMachine;
		BEGIN
			rbm:=layers;
			WHILE rbm.next#NIL DO
				rbm:=rbm.next
			END;
			rbm.BackPropagate(data);
			WHILE rbm.prior#NIL DO
				IF DIM(data) =2 THEN rbm.prior.BackPropagate(rbm.reconstructed);
				ELSIF DIM(data)=3 THEN rbm.prior.BackPropagate(rbm.reconstructed3);
				END;
				rbm:=rbm.prior;
			END;
			IF DIM (data)=2 THEN RETURN rbm.reconstructed
			ELSIF DIM(data)=3 THEN RETURN rbm.reconstructed3
			END;
		END Reconstruct;

	END DeepBelieveNetwork;

	PROCEDURE SameDimension(VAR a:Dataset; CONST len:ARRAY [*] OF SIZE);
	VAR d:SIGNED32;
	BEGIN
		IF (DIM(a)#LEN(len,0)) OR (LEN(a)#len) THEN NEW(a,len) END;
	END SameDimension;

	PROCEDURE All1(CONST m: ARRAY [?] OF Datatype; op: PROCEDURE(x:Datatype):Datatype):ARRAY [?] OF Datatype;
	VAR i,j,k:SIGNED32;
	BEGIN
		SameDimension(RESULT, LEN(m));
		CASE DIM(m) OF
		|1:	FOR i:=0 TO LEN(m,0)-1 DO
				RESULT[i]:=op(m[i])
			END;
		|2: FOR j:=0 TO LEN(m,0)-1 DO
				FOR i:=0 TO LEN(m,1)-1 DO
					RESULT[j,i]:=op(m[j,i])
				END;
			END;
		|3: 	FOR k:=0 TO LEN(m,0)-1 DO
				FOR j:=0 TO LEN(m,1)-1 DO
					FOR i:=0 TO LEN(m,2)-1 DO
						RESULT[k,j,i]:=op(m[k,j,i])
					END;
				END;
			END;
		ELSE
			FOR i:=0 TO LEN(m,0)-1 DO
				RESULT[i,?]:=All1(m[i,?], op);
			END;
		END;
		RETURN RESULT
	END All1;

	PROCEDURE All1V(VAR m: ARRAY [?] OF Datatype; op: PROCEDURE(VAR x:Datatype));
	VAR i,j,k:SIGNED32;
	BEGIN
		CASE DIM(m) OF
		|1:	FOR i:=0 TO LEN(m,0)-1 DO
				op(m[i])
			END;
		|2: FOR j:=0 TO LEN(m,0)-1 DO
				FOR i:=0 TO LEN(m,1)-1 DO
					op(m[j,i])
				END;
			END;
		|3: 	FOR k:=0 TO LEN(m,0)-1 DO
				FOR j:=0 TO LEN(m,1)-1 DO
					FOR i:=0 TO LEN(m,2)-1 DO
						op(m[k,j,i])
					END;
				END;
			END;
		ELSE
			FOR i:=0 TO LEN(m,0)-1 DO
				All1V(m[i,?], op);
			END;
		END;
	END All1V;

	(*apply a procedure operating on a line at a time to a matrix*)
	PROCEDURE AllVec(CONST m: ARRAY [?] OF Datatype; op: PROCEDURE(VAR m: ARRAY[?] OF Datatype)  ):ARRAY [?] OF Datatype;
	VAR i,j,k:SIGNED32;
		temp: ARRAY[?] OF Datatype;
	BEGIN
		SameDimension(RESULT, LEN(m));
		CASE DIM(m) OF
		|1:
			temp:=m;
			op(temp);
			RESULT:=temp;
		|2:
			FOR j:=0 TO LEN(m,0)-1 DO
				temp:=m[j,?];
				op(temp);
				RESULT[j,?]:=temp;
			END;
		|3:
			FOR k:=0 TO LEN(m,0)-1 DO
				FOR j:=0 TO LEN(m,1)-1 DO
					temp:=m[k,j,?];
					op(temp);
					RESULT[k,j,?]:=temp;
				END;
			END;
		ELSE
			FOR i:=0 TO LEN(m,0)-1 DO
				RESULT[i,?]:=AllVec(m[i,?], op);
			END;
		END;
		RETURN RESULT
	END AllVec;

	PROCEDURE Count(CONST a: Dataset):SIGNED32;
	VAR i:SIGNED32; res:SIGNED32;
	BEGIN
		res:=1;
		FOR i:=0 TO DIM(a)-1 DO
			res:=res*LEN(a,i);
		END;
		RETURN res
	END Count;

	PROCEDURE constrain01(a:Datatype):Datatype;
	BEGIN
		RETURN MIN(0.1, MAX(-0.1,a))
	END constrain01;


	PROCEDURE All2(CONST m1,m2: ARRAY [?] OF Datatype; op: PROCEDURE(x,y:Datatype):Datatype):ARRAY [?] OF Datatype;
	VAR i, j: SIGNED32;
	BEGIN
		FOR i := 0 TO LEN( m1, 0 ) - 1 DO
			FOR j := 0 TO LEN( m1, 1 ) - 1 DO RESULT[i, j] := op( m1[i, j], m2[i, j] );  END;
		END;
		RETURN RESULT
	END All2;
	(*
	current repertoire of nonlinear response functions and their derivatives:
	- logistic function is historical standard, has very fast derivative
	-symmetric logistic function
	- tanh() is similar but is reported to converge faster, but has  more involved derivative
	- rectifier() is claimed to be well suited to deep networks, and fast
	- softplus is an analytic function similar to rectifier, but computationally more demanding
	*)

	(* Sigmoid function: tricks for nonlinear response in ANNs:
	LeCun, Y.; Bottou, L.; Orr, G.; Muller, K. (1998). Orr, G.; Muller, K., eds. Efficient BackProp (PDF). Neural Networks: Tricks of the trade (Springer). ISBN 3-540-65311-2
	- symmetric sigmoids like tanh() may converge faster than logistic function
	- recommended is f(x)= 1.7159 * tanh (2/3* x)
	- sometimes it it helpful to add a small linear term, like f(x)=tanh(x)+ a*x  to avoid flat spots.
	*)

(*
	PROCEDURE -Truncate0(x:FLOAT32):SIGNED32; (*fast truncation*)
	CODE{SYSTEM.i386, SYSTEM.SSE3, SYSTEM.FPU}
	        CVTTSS2SI EAX, [ESP+x] ; convert single precision floating point to scalar DWORD
	        ADD ESP, 4
	END Truncate0;
	*)

	PROCEDURE truncate(x:Datatype):Datatype;
	BEGIN
		RETURN ENTIER(x+0.5)
	END truncate;

	PROCEDURE truncateStochastic(x:Datatype):Datatype; (* binary based on probability *)
	BEGIN
		IF rand.Uniform()>x THEN RETURN 0
		ELSE RETURN 1
		END;
	END truncateStochastic;


	PROCEDURE Truncate(CONST m:Dataset):Dataset; (* version may depend on result range of sigmoid function used *)
	BEGIN
		RESULT:=m+0.5;
		(*RESULT:=ENTIER(RESULT); *)(*allocation & conversion*)
		RESULT:=ALL(RESULT, truncate);
		(*RESULT:=All1(RESULT, truncate);*)
		RETURN RESULT
	END Truncate;

PROCEDURE TruncateStochastic(CONST m:Dataset):Dataset; (* version may depend on result range of sigmoid function used *)
	BEGIN
		RESULT:=m+0.5;
		RESULT:=MAX(RESULT,0); RESULT:=MIN(RESULT,1);
		(*RESULT:=All1(RESULT, truncateStochastic);*)
		RESULT:=ALL(RESULT, truncateStochastic);
		RESULT:=RESULT-0.5;
		RESULT:=2*RESULT;
		RETURN RESULT
	END TruncateStochastic;

	PROCEDURE Logistic*( x: Datatype ): Datatype;  (* logistic function as nonlinear element for unit response *)
	BEGIN
		(*RETURN PMath.logisticL(x)*)
		RETURN PMathSSE.logisticL(x)
	END Logistic;

	PROCEDURE LogisticDerivativeDelta*( y, delta: Datatype ): Datatype;
	BEGIN
		RETURN delta * (1 - y) * y
	END LogisticDerivativeDelta;

	(* shifted and scale to go from -1 to 1 *)
	PROCEDURE SymmetricLogistic*( x: Datatype ): Datatype;
	BEGIN
		RETURN 2*PMathSSE.logisticL(x)-1
	END SymmetricLogistic;

	PROCEDURE SymmetricLogisticDerivativeDelta*( y, delta: Datatype ): Datatype;
	BEGIN
		RETURN delta * 2* (1 - y) * y
	END SymmetricLogisticDerivativeDelta;

	PROCEDURE Tanh*( x: FLOAT64 ): FLOAT64;
	BEGIN
		(*RETURN PMath.tanhL(x);*)
		RETURN PMathSSE.tanh(SHORT(x))
	END Tanh;

	PROCEDURE TanhDerivative*( y: Datatype ): Datatype;
	VAR a: Datatype;
	BEGIN
		(*a:= Tanh(y); *)
		a:=PMathSSE.tanh(SHORT(y));
		RETURN 1- a*a
	END TanhDerivative;

	(*Xavier Glorot, Antoine Bordes and Yoshua Bengio (2011). Deep sparse rectifier neural networks (PDF). AISTATS.*)
	PROCEDURE Rectifier*(x:Datatype):Datatype;
	CONST leak=0; (*leak=0.01;*)
	BEGIN
		RETURN MAX(x,leak);
		(*RETURN MIN(1, MAX(x,-1));*)
	END Rectifier;

	PROCEDURE RectifierDerivativeDelta*(x,delta:Datatype):Datatype;
	BEGIN
		IF x>0 THEN RETURN delta (*??*)
		(*IF (x>-1)&(x<0) THEN RETURN delta*)
		ELSE RETURN 0
		END;
	END RectifierDerivativeDelta;

	 PROCEDURE SoftPlus*(x:Datatype):Datatype;
	 BEGIN
	 	RETURN MathL.ln(1+ MathL.exp(x))
	 END SoftPlus;

	PROCEDURE SoftPlusDerivativeDelta*(x,delta:Datatype):Datatype;
	BEGIN
		RETURN delta * PMath.tanhL(x); (*tanh is derivative of SoftPlus, see https://en.wikipedia.org/wiki/Rectifier_%28neural_networks%29*)
		(*! however, wikipedia: rectifier(neural networks) says that the derivative of SoftPlus is the logistic function*)
	END SoftPlusDerivativeDelta;

	PROCEDURE Sigmoid*(x:Datatype):Datatype; (* according to LeCun et al, these are well working parameters based on tanh(), if inputs/outputs are scaled in a suited manner  *)
	CONST scaley=1.7159;
			scalex=2/3;
	BEGIN
		(*RETURN scaley * PMath.tanhL(scalex * x) *)
		(*RETURN scaley * Tanh(scalex * x) *)
		RETURN  scaley * PMathSSE.tanh(SHORT(scalex * x))
	END Sigmoid;

	PROCEDURE Sigmoid1*(VAR x:Datatype); (* according to LeCun et al, these are well working parameters based on tanh(), if inputs/outputs are scaled in a suited manner  *)
	CONST scaley=1.7159;
			scalex=2/3;
	BEGIN
		(*x:= scaley * PMath.tanhL(scalex * x) *)
		(*x:= scaley * Tanh(scalex * x) *)
		x:=  scaley * PMathSSE.tanh(SHORT(scalex * x))
	END Sigmoid1;

	PROCEDURE SigmoidDerivativeDelta*(x,delta:Datatype):Datatype;  (*consistently crashes the system*)
	CONST scaley=1.7159;
			scalex=2/3;
	VAR a: Datatype;
	BEGIN
		a:= PMathSSE.tanh(SHORT(scalex * x));
		RETURN delta *scaley * (1- a*a)
		(*RETURN delta*scaley * TanhDerivative( scalex * x)*)
	END SigmoidDerivativeDelta;

	(*Normalize data using a sigmoid function to -1..0..1 using statistical descriptors *)
	PROCEDURE SoftMaxTanHNormalize*(x, mean, sdev: Datatype): Datatype;
	BEGIN
		RETURN PMathSSE.tanh(SHORT((x-mean)/sdev));
	END SoftMaxTanHNormalize;

	(*working on data arrays*)
	(*Normalize data using a sigmoid function to -1..0..1 using statistical descriptors *)
	PROCEDURE SoftMaxTanhNormalize*(VAR x: ARRAY[?] OF Datatype);
	VAR mean, sd:Datatype; N: SIGNED32;
	BEGIN
		N:=Count(x);
		x:=x-SUM(x)/N;
		sd:= MathL.sqrt(x+*x/N); (*speedup square*)
		x:=1/sd*x;
		(*x:=All1(x, Tanh)*)
		x:=ALL(x, Tanh)
	END SoftMaxTanhNormalize;

	PROCEDURE SoftMax*(VAR m: ARRAY[?] OF Datatype);
	(* a = softmax(n) = exp(n)/sum(exp(n)) *)
	BEGIN
		(*m :=All1(m, MathL.exp);*)
		m :=ALL(m, MathL.exp);
		m:=1/SUM(m) * m
	END SoftMax;

	PROCEDURE SoftMaxNormalize*(VAR m: ARRAY[?] OF Datatype);
	VAR N:SIGNED32; sd: Datatype;
	BEGIN
		N:=Count(m);
		m:=m-SUM(m)/N;
		sd:=MathL.sqrt(m+*m/N);
		m:=1/sd*m;
		m :=All1(m, MathL.exp);
		m:=1/SUM(m) * m
	END SoftMaxNormalize;

	PROCEDURE NewLayer( InNodes, outNodes, type: SIGNED32 ): Layer;
	VAR L: Layer;
	BEGIN
		ASSERT( (InNodes > 0) & (outNodes > 0), 100 );  ASSERT( type IN {linear, sigmoid, softmax}, 101 );
		NEW( L );
		NEW( L.weights, InNodes, outNodes );  NEW( L.dweights, InNodes, outNodes );
		NEW( L.oldweights, InNodes, outNodes );
		L.startweight := DefaultStartweight;  L.type := type;
		RETURN L
	END NewLayer;


	PROCEDURE LoadDataFromFile(VAR alldata: ARRAY[*,*] OF Datatype);
	CONST
		maxSamples=100;
		valuesPerSample=768;
	VAR
		f: Files.File;
		r: Files.Reader;
		filename: ARRAY 128 OF  CHAR;
		numLines: SIGNED32;
		i,j: SIGNED32;
	BEGIN
		filename:="layer0rawinput.MtA";
		(*NEW(alldata,MIN(maxSamples, numLines DIV valuesPerSample),valuesPerSample);*)
		f:=Files.Old(filename);
		ASSERT(~(f=NIL));
		Files.OpenReader(r,f,0);
		alldata:=Util.LoadLR(r);
		f.Close();
	END LoadDataFromFile;

	PROCEDURE LoadTargetFromFile(VAR target: ARRAY[*,*] OF SIGNED32);
	CONST
		filename="train-labels.idx1-ubyte";
		maxSamples=100;
	VAR
		numLabels: SIGNED32;
	BEGIN
		(*numLabels:=RBMFineTuning.LoadLabels(target, filename,maxSamples);  MNIST dataformat specific, omitted for now*)
		HALT(100);
	END LoadTargetFromFile;


	PROCEDURE	LoadWeightsFromFile(VAR weights: ARRAY[*,*] OF Datatype; filename: ARRAY OF CHAR);  (*todo: more generic*)
	CONST
		numInput=784;
		numOutput=200;
	VAR
		visBias,hidBias: ARRAY[*] OF Datatype;
		i,j: SIGNED32;
		wab: ARRAY[*] OF Datatype;
		f: Files.File;
		r: Files.Reader;
	BEGIN
		(*for now, throw away the biases*)
		NEW(wab,numInput*numOutput);
		NEW(visBias,numInput);
		NEW(hidBias,numOutput);
	 	f:=Files.Old(filename);
		ASSERT(~(f=NIL));
		Files.OpenReader(r,f,0);
		wab:=Util.LoadLR(r);
		f.Close();
	 	NEW(weights, numOutput,numInput);
 		FOR j:=0 TO numOutput-1 DO
 			weights[*,j]:=wab[j*numInput..((j+1)*numInput-1)]; (*data type conversion and reordering*)
 		END;
	END LoadWeightsFromFile;

(* invent some training data for demo *)
	PROCEDURE SampleData( Samples, InputNodes, OutputNodes: SIGNED32;  VAR InMatrix, TargetMatrix: Matrix );
	VAR i, j: SIGNED32;
	BEGIN
		(*Initialize input & output matrices with the corresponding, relatively arbitrary, datasets *)
		NEW( InMatrix, Samples, InputNodes );
		FOR j := 0 TO InputNodes - 1 DO i := j + 1;  InMatrix[0, j] := (i + 7 DIV i) ;   END;
		FOR j := 0 TO InputNodes - 1 DO i := j + 1;  InMatrix[1, j] := (i) ;  END;
		FOR j := 0 TO InputNodes - 1 DO i := j + 1;  InMatrix[2, j] := (1 - i) ;   END;
		FOR j := 0 TO InputNodes - 1 DO i := j + 1;  InMatrix[3, j] := (2 MOD i + 1) ;   END;
		FOR j := 0 TO InputNodes - 1 DO i := j + 1;  InMatrix[4, j] := (3 DIV i) ;   END;
		FOR j := 0 TO InputNodes - 1 DO i := j + 1;  InMatrix[5, j] := (4 / i + i) ;  END;
		FOR j := 0 TO InputNodes - 1 DO i := j + 1;  InMatrix[6, j] := (i / 5 + i) ;   END;
		FOR j := 0 TO InputNodes - 1 DO i := j + 1;  InMatrix[7, j] := (6 MOD i) ;   END;

		NEW( TargetMatrix, Samples, OutputNodes);
		FOR j := 0 TO OutputNodes - 1 DO i := j + 1;  TargetMatrix[0, j] := (i + 0.4) ;  END;
		FOR j := 0 TO OutputNodes - 1 DO i := j + 1;  TargetMatrix[1, j] := (-i) ;  END;
		FOR j := 0 TO OutputNodes - 1 DO i := j + 1;  TargetMatrix[2, j] := (Math.sqrt( i )) ;  END;
		FOR j := 0 TO OutputNodes - 1 DO i := j + 1;  TargetMatrix[3, j] := (i - 3) ;  END;
		FOR j := 0 TO OutputNodes - 1 DO i := j + 1;  TargetMatrix[4, j] := ((3 - i) * i) ;  END;
		FOR j := 0 TO OutputNodes - 1 DO i := j + 1;  TargetMatrix[5, j] := (-(4 * i - 1)) ;  END;
		FOR j := 0 TO OutputNodes - 1 DO i := j + 1;  TargetMatrix[6, j] := (0.73) ;  END;
		FOR j := 0 TO OutputNodes - 1 DO i := j + 1;  TargetMatrix[7, j] := (Math.sqrt( i + 3 )) ;  END;
	END SampleData;

	PROCEDURE BinarizeNumber(x:Datatype):Datatype;
	BEGIN
		IF ODD(ENTIER(x)) THEN RETURN 1 ELSE RETURN 0 END;
	END BinarizeNumber;

	PROCEDURE BinarizeHalf(x:Datatype):Datatype;
	BEGIN
		IF x>=0.5 THEN RETURN 1 ELSE RETURN 0 END;
	END BinarizeHalf;

	PROCEDURE BinarizeZero(x:Datatype):Datatype;
	BEGIN
		IF x>=0 THEN RETURN 1 ELSE RETURN 0 END;
	END BinarizeZero;

	(* invent some training data for demo *)
	PROCEDURE SampleDataBinary( Samples, InputNodes, OutputNodes: SIGNED32;  VAR InMatrix, TargetMatrix: Matrix );
	VAR i, j: SIGNED32;
	BEGIN
		(*Initialize input & output matrices with the corresponding, relatively arbitrary, datasets *)
		NEW( InMatrix, Samples, InputNodes );
		FOR j := 0 TO InputNodes - 1 DO i := j + 1;  InMatrix[0, j] := BinarizeNumber(i + 7 DIV i) END;
		FOR j := 0 TO InputNodes - 1 DO i := j + 1;  InMatrix[1, j] := BinarizeNumber(i) ;  END;
		FOR j := 0 TO InputNodes - 1 DO i := j + 1;  InMatrix[2, j] := BinarizeNumber(1 - i) ;   END;
		FOR j := 0 TO InputNodes - 1 DO i := j + 1;  InMatrix[3, j] := BinarizeNumber(2 MOD i + 1) ;   END;
		FOR j := 0 TO InputNodes - 1 DO i := j + 1;  InMatrix[4, j] := BinarizeNumber(3 DIV i) ;   END;
		FOR j := 0 TO InputNodes - 1 DO i := j + 1;  InMatrix[5, j] := BinarizeNumber(4 / i + i) ;  END;
		FOR j := 0 TO InputNodes - 1 DO i := j + 1;  InMatrix[6, j] := BinarizeNumber(i / 5 + i) ;   END;
		FOR j := 0 TO InputNodes - 1 DO i := j + 1;  InMatrix[7, j] := BinarizeNumber(6 MOD i) ;   END;

		NEW( TargetMatrix, Samples, OutputNodes);
		FOR j := 0 TO OutputNodes - 1 DO i := j + 1;  TargetMatrix[0, j] := BinarizeNumber(i + 0.4) ;  END;
		FOR j := 0 TO OutputNodes - 1 DO i := j + 1;  TargetMatrix[1, j] := BinarizeNumber(-i) ;  END;
		FOR j := 0 TO OutputNodes - 1 DO i := j + 1;  TargetMatrix[2, j] := BinarizeNumber(Math.sqrt( i )) ;  END;
		FOR j := 0 TO OutputNodes - 1 DO i := j + 1;  TargetMatrix[3, j] := BinarizeNumber(i - 3) ;  END;
		FOR j := 0 TO OutputNodes - 1 DO i := j + 1;  TargetMatrix[4, j] := BinarizeNumber((3 - i) * i) ;  END;
		FOR j := 0 TO OutputNodes - 1 DO i := j + 1;  TargetMatrix[5, j] := BinarizeNumber(-(4 * i - 1)) ;  END;
		FOR j := 0 TO OutputNodes - 1 DO i := j + 1;  TargetMatrix[6, j] := BinarizeNumber(0.73) ;  END;
		FOR j := 0 TO OutputNodes - 1 DO i := j + 1;  TargetMatrix[7, j] := BinarizeNumber(Math.sqrt( i + 3 )) ;  END;
	END SampleDataBinary;


	(* invent some training data for demo with one-hot output*)
	PROCEDURE SampleData2( Samples, InputNodes, OutputNodes: SIGNED32;  VAR InMatrix, TargetMatrix: Matrix );
	VAR i, j: SIGNED32;
	BEGIN
		(*Initialize input & output matrices with the corresponding, relatively arbitrary, datasets *)
		NEW( InMatrix, Samples, InputNodes );
		FOR i:=0 TO Samples-1 BY 8 DO
			FOR j := 0 TO InputNodes - 1 DO  InMatrix[i +0, j] := ((j MOD 8 +1) + 7 DIV (j MOD 8 +1)) ;   END;
			FOR j := 0 TO InputNodes - 1 DO  InMatrix[i +1, j] := ((j MOD 8 +1)) ;  END;
			FOR j := 0 TO InputNodes - 1 DO  InMatrix[i +2, j] := (1 - (j MOD 8 +1)) ;   END;
			FOR j := 0 TO InputNodes - 1 DO  InMatrix[i +3, j] := (2 MOD (j MOD 8 +1) + 1) ;   END;
			FOR j := 0 TO InputNodes - 1 DO  InMatrix[i +4, j] := (3 DIV (j MOD 8 +1)) ;   END;
			FOR j := 0 TO InputNodes - 1 DO  InMatrix[i +5, j] := (4 / (j MOD 8 +1) + (j MOD 8 +1)) ;  END;
			FOR j := 0 TO InputNodes - 1 DO  InMatrix[i +6, j] := ((j MOD 8 +1) / 5 + (j MOD 8 +1)) ;   END;
			FOR j := 0 TO InputNodes - 1 DO  InMatrix[i +7, j] := (6 MOD (j MOD 8 +1)) ;   END;
		END;

		NEW( TargetMatrix, Samples, OutputNodes);
		FOR i:=0 TO Samples-1 DO
			TargetMatrix[i, i MOD 8] := 1; (* else 0 *)
		END;

	END SampleData2;

	(* invent some embarrassingly simple training data*)
	PROCEDURE SampleDataSimple( Samples, InputNodes, OutputNodes: SIGNED32;  VAR InMatrix, TargetMatrix: Matrix );
	VAR i: SIGNED32;
	BEGIN
		(*Initialize input & output matrices with the corresponding, relatively arbitrary, datasets *)
		NEW( InMatrix, Samples, InputNodes );
		FOR i:=0 TO Samples-1 DO
			InMatrix[i,0]:=0.5;
		END;

		NEW( TargetMatrix, Samples, OutputNodes);
		FOR i:=0 TO Samples-1 DO
			TargetMatrix[i, 3] := 1; (* else 0 *)
		END;

	END SampleDataSimple;


	(* worst case scenario: data have no hidden structure *)
	PROCEDURE RandomData( Samples, InputNodes, OutputNodes: SIGNED32;  VAR InMatrix, TargetMatrix: Matrix );
	VAR i, j: SIGNED32;
	BEGIN
		(*Initialize input & output matrices with the corresponding, relatively arbitrary, datasets *)
		NEW( InMatrix, Samples, InputNodes );
		NEW( TargetMatrix, Samples, OutputNodes);
		FOR i:=0 TO Samples-1 DO
			FOR j:=0 TO InputNodes-1 DO
				InMatrix[i, j] := rand.Uniform()
			END;
			FOR j:=0 TO OutputNodes-1 DO
				TargetMatrix[i, j] := rand.Uniform()
			END;
		END;
	END RandomData;


	PROCEDURE	 TestWeightLoading*(context: Commands.Context);
	CONST
		 InputNodes = 768;  InnerNodes = 200;  outputNodes = 10;
		layer0initfilename="learn_output0.idx3-ubyte";
	VAR
		w01: Matrix;
		samples: ARRAY[*,*] OF Datatype;
		target: ARRAY [*,*] OF SIGNED32;
		Classification: Matrix;
		Net: Network;
		iterations:SIGNED32;
		layers:SIGNED32;
		layerVector, typeVector: ARRAY [*] OF SIGNED32;
		SSE: FLOAT64;

	BEGIN

		Out.String( "Loading weights...  " );
		LoadWeightsFromFile(w01,layer0initfilename);

		Out.String("Loading samples...  ");
		LoadDataFromFile(samples);
		Out.Int(LEN(samples,0),3);Out.Int(LEN(samples,1),3); Out.Ln;

		LoadTargetFromFile(target);

		(*create matrices depending on sample size and input/output number; example is for linear descent search;
		Note that InMatrix and TargetMatrix differ in structure for stochastic search...*)


		(* create the artificial neural network *)
		NEW( Net );
		(*Net.alpha:=0.4;*)
		Net.eta:=0.000001;
		Net.function:=Sigmoid;
		Net.derivativeDelta:=SigmoidDerivativeDelta;

		 layers:=3;
		NEW(layerVector,layers);
		layerVector[0]:=InputNodes;
		layerVector[1]:=InnerNodes;
		layerVector[2]:=outputNodes;

		Net.trainingEpisodes:=1000;
		NEW(typeVector, layers-1);
		typeVector[0]:=sigmoid;
		typeVector[1]:=linear;
		(*Net.Build( layerVector, typeVector);*)
		Net.Build2( layerVector, typeVector, w01); (*todo: temporary*)

		(* train the network*)
		Net.Learn( samples, target);

		(* evaluate the network's performance *)
		Out.String( "..Neural Network evaluates first sample to check fitting to single target." );  Out.Ln;
		Util.Out(Net.EvaluateVector(samples[0])); (* evaluation of single feature vector*) Out.Ln;

		Out.String( "..Neural Network evaluates all training samples to check fitting to targets.." );  Out.Ln;
		Classification := Net.EvaluateVectorN( samples);   (* evaluation of multiple feature vectors *)
		Util.Out( Classification );

		Out.String( "..Sum of Squared Residuals; MSE: " );
		SSE:=(Classification - target)+*(Classification - target);
		Util.OutFloat(SSE,12,5,0); Util.OutFloat(SSE/LEN(Classification,0)/LEN(Classification,1),12,5,0); Out.Ln;

		Util.Out( Classification - target);








	END TestWeightLoading;

	PROCEDURE TestSigmoid*(context: Commands.Context);
	VAR
		dummy: FLOAT64;
	BEGIN
			dummy:=PMath.tanh(0.3); (*works fine*)
			TRACE(ENTIER(1000*dummy));

			dummy:=PMathSSE.tanh(0.3); (*crashes the system with recursive trap*)
			TRACE(ENTIER(1000*dummy));



			dummy:=Sigmoid(0.8);
			TRACE(dummy);
			dummy:=SigmoidDerivativeDelta(0.1,0.3);
			TRACE(dummy);
	END TestSigmoid;

	PROCEDURE Test*(context:Commands.Context);
	CONST Samples = 10;  InputNodes = 8;  FirstLayerNodes = 5;  outputNodes = 8;
	VAR InMatrix, TargetMatrix, Classification: Matrix;  Net: Network;
	iterations:SIGNED32;
		SSE: FLOAT64;
		i,o,f,s,l:SIGNED32;

	BEGIN

		Out.String( "Neural Network Demo" );  Out.Ln;
		(*create matrices depending on sample size and input/output number; example is for linear descent search;
		Note that InMatrix and TargetMatrix differ in structure for stochastic search...*)

		(* invent test data *)
		SampleData( Samples, InputNodes, outputNodes, InMatrix, TargetMatrix );
		InMatrix:=Util.Normalize(InMatrix);
		TargetMatrix:=Util.Normalize(TargetMatrix);
		Out.String( "..samples.." );  Out.Ln;
		Util.Out( InMatrix );
		Out.String( "..target to be approximated by learning machine.." );  Out.Ln;
		Util.Out( TargetMatrix );

		(* create the artificial neural network *)
		NEW( Net);
		IF context.arg.GetInteger(iterations,FALSE) THEN Net.trainingEpisodes:=iterations END;
		i:=InputNodes; f:=FirstLayerNodes; o:=outputNodes; s:=sigmoid; l:=linear;(*hack due to compiler problem*)

		Net.function:=Sigmoid;
		Net.derivativeDelta:=SigmoidDerivativeDelta;

		(*Net.Build( [InputNodes, FirstLayerNodes, outputNodes], [sigmoid, linear]);  *)
		Net.Build( [i,f,o], [s,l]);

		(* train the network*)
		Net.Learn( InMatrix, TargetMatrix );

		(* evaluate the network's performance *)
		Out.String( "..Neural Network evaluates first sample to check fitting to single target." );  Out.Ln;
		Util.Out(Net.EvaluateVector(InMatrix[0])); (* evaluation of single feature vector*) Out.Ln;

		Out.String( "..Neural Network evaluates all training samples to check fitting to targets.." );  Out.Ln;
		Classification := Net.EvaluateVectorN( InMatrix );   (* evaluation of multiple feature vectors *)
		Util.Out( Classification );

		Out.String( "..Sum of Squared Residuals; MSE: " );
		SSE:=(Classification - TargetMatrix)+*(Classification - TargetMatrix);

		Util.OutFloat(SSE,12,5,0); Util.OutFloat(SSE/LEN(Classification,0)/LEN(Classification,1),12,5,0); Out.Ln;
		Util.Out( Classification - TargetMatrix );

	END Test;

	PROCEDURE TestDeep*(context:Commands.Context);
	CONST Samples = 40;  InputNodes = 8;  InnerNodes = 10;  outputNodes = 8;
	VAR InMatrix, TargetMatrix, Classification: Matrix;  Net: Network;
		iterations:SIGNED32;
		layers:SIGNED32;
		layerVector, typeVector: ARRAY [*] OF SIGNED32;
		SSE: FLOAT64;
	BEGIN
		Out.String( "Neural Network Demo" );  Out.Ln;
		(*create matrices depending on sample size and input/output number; example is for linear descent search;
		Note that InMatrix and TargetMatrix differ in structure for stochastic search...*)

		(* invent test data *)
		(*SampleData( Samples, InputNodes, outputNodes, InMatrix, TargetMatrix );    *)
		SampleData2( Samples, InputNodes, outputNodes, InMatrix, TargetMatrix );
		Out.String( "..samples.." );  Out.Ln;
		Util.Out( InMatrix );
		Out.String( "..target to be approximated by learning machine.." );  Out.Ln;
		Util.Out( TargetMatrix );

		(* create the artificial neural network *)
		NEW( Net );
		Net.alpha:=0.4;
		Net.function:=Rectifier;
		Net.derivativeDelta:=RectifierDerivativeDelta;
		(*
		Net.function:=SoftPlus;
		Net.derivativeDelta:=SoftPlusDerivativeDelta;
		*)

		(*
		Net.function:=Sigmoid;
		Net.derivativeDelta:=SigmoidDerivativeDelta;
		*)

		IF ~context.arg.GetInteger(layers,FALSE) THEN layers:=3 END;
		NEW(layerVector,layers);
		layerVector[0]:=InputNodes; layerVector[1..layers-2]:=InnerNodes; layerVector[layers-1]:=outputNodes;

		IF context.arg.GetInteger(iterations,FALSE) THEN Net.trainingEpisodes:=iterations END;
		NEW(typeVector, layers-1);
		typeVector[..layers-3]:=sigmoid; typeVector[layers-2]:=linear;
		Net.Build( layerVector, typeVector);

		(* train the network*)
		Net.Learn( InMatrix, TargetMatrix );

		(* evaluate the network's performance *)
		Out.String( "..Neural Network evaluates first sample to check fitting to single target." );  Out.Ln;
		Util.Out(Net.EvaluateVector(InMatrix[0])); (* evaluation of single feature vector*) Out.Ln;

		Out.String( "..Neural Network evaluates all training samples to check fitting to targets.." );  Out.Ln;
		Classification := Net.EvaluateVectorN( InMatrix );   (* evaluation of multiple feature vectors *)
		Util.Out( Classification );

		Out.String( "..Sum of Squared Residuals; MSE: " );
		SSE:=(Classification - TargetMatrix)+*(Classification - TargetMatrix);
		Util.OutFloat(SSE,12,5,0); Util.OutFloat(SSE/LEN(Classification,0)/LEN(Classification,1),12,5,0); Out.Ln;

		Util.Out( Classification - TargetMatrix );
	END TestDeep;

	PROCEDURE TestCO*;
	CONST FirstLayerNodes = 12;
	VAR InMatrix, TargetMatrix, InMatrixTrain, InMatrixTest, TargetMatrixTrain, TargetMatrixTest, Classification: Matrix; Net: Network;
		insamples, outsamples, innodes, outnodes, row, col: SIGNED32;
		fileIn, fileOut: Files.File; inreader,outreader: Files.Reader;
		SSE: FLOAT64;
		l:SIGNED32;
	BEGIN
		Out.String( "Neural Network Analysis of Cardiac Output" );  Out.Ln;

		(* grab test data *)
		fileIn:=Files.Old("test_data.dat");
		fileOut:=Files.Old("target_data.dat");
		ASSERT(fileIn #NIL, 500); ASSERT(fileOut#NIL,501);
		NEW(inreader, fileIn, 0);
		NEW(outreader, fileOut, 0);
		inreader.RawLInt(insamples); outreader.RawLInt(outsamples);
		inreader.RawLInt(innodes); outreader.RawLInt(outnodes);
		ASSERT(insamples=outsamples, 502);
		NEW(InMatrix, insamples, innodes);
		NEW(TargetMatrix, outsamples, outnodes);

		FOR row:=0 TO insamples-1 DO
			FOR col:=0 TO innodes-1 DO
				inreader.RawLReal(InMatrix[row,col]);
			END;
			FOR col:=0 TO outnodes-1 DO
				outreader.RawLReal(TargetMatrix[row,col]);
			END;
		END;
		(*
		InMatrixTrain:=InMatrix[..BY 2,..];
		InMatrixTest:=InMatrix[1..BY 2,..];
		TargetMatrixTrain:=TargetMatrix[.. BY 2, ..];
		TargetMatrixTest:=TargetMatrix[1.. BY 2, ..];
		*)

		Out.String( "..samples.." );  Out.Int(LEN(InMatrix,0),6); Out.Int(LEN(InMatrix,1),6); Out.Int(LEN(TargetMatrix,0),6); Out.Int(LEN(TargetMatrix,1),6);  Out.Ln;

		Out.String( "..samples.." );  Out.Ln;
		Util.Out( InMatrix[0..2,..] );
		Out.String( "..target to be approximated by learning machine.." );  Out.Ln;
		Util.Out( TargetMatrix[0..2,..]);

		(* create an artificial neural network with default parameters *)
		NEW( Net );
		l:=linear;
		Net.Build( [innodes, FirstLayerNodes, outnodes], [sigmoid, l]);  (*hack due to compiler problem to be solved 2/16*)

		(* train the network*)
		Net.Learn( InMatrix, TargetMatrix );
		(*! version with train and test dataset*)
		(*Net.Learn( InMatrixTrain, TargetMatrixTrain );  *)


		(* evaluate the network's performance *)

		Out.String( "..Neural Network evaluates first sample to check fitting to single target." );  Out.Ln;
		Util.Out(Net.EvaluateVector(InMatrix[0])); (* evaluation of single feature vector*) Out.Ln;

		Out.String( "..Neural Network evaluates all training samples to check fitting to targets.." );  Out.Ln;

		Classification := Net.EvaluateVectorN( InMatrix );   (* evaluation of multiple feature vectors *)
		(*! version with train and test dataset*)
		(*Classification := Net.EvaluateVectorN( InMatrixTest );    *)

		(*Util.Out( Classification );  *)

		Out.String( "..Sum of Squared Residuals; MSE: " );
		SSE:=(Classification - TargetMatrix)+*(Classification - TargetMatrix);
		Util.OutFloat(SSE,12,5,0); Util.OutFloat(SSE/LEN(Classification,0)/LEN(Classification,1),12,5,0); Out.Ln;

		Util.Out( Classification[..5,..] - TargetMatrix[..5,..] );
		Util.Out( Classification[0..5,..] );
		Util.Out( TargetMatrix[0..5,..] );


		(*! version with train and test dataset*)
		(*Classification := Net.EvaluateVectorN( InMatrixTest );
			Out.String( "..Residual.." );  Util.OutFloat((Classification - TargetMatrixTest)+*(Classification - TargetMatrixTest),12,5,0); Out.Ln;
		*)

	END TestCO;

	PROCEDURE TestCO2*(context:Commands.Context);
	CONST InnerNodes = 12;
	VAR InMatrix, TargetMatrix, InMatrixTrain, InMatrixTest, TargetMatrixTrain, TargetMatrixTest, Classification: Matrix; Net: Network;
		insamples, outsamples, innodes, outnodes, row, col: SIGNED32;
		fileIn, fileOut: Files.File; inreader,outreader: Files.Reader;
		iterations:SIGNED32;
		layers:SIGNED32;
		layerVector, typeVector: ARRAY [*] OF SIGNED32;

	BEGIN
		Out.String( "Neural Network Analysis of Cardiac Output" );  Out.Ln;

		(* grab test data *)
		fileIn:=Files.Old("test_data.dat");
		fileOut:=Files.Old("target_data.dat");
		ASSERT(fileIn #NIL, 500); ASSERT(fileOut#NIL,501);
		NEW(inreader, fileIn, 0);
		NEW(outreader, fileOut, 0);
		inreader.RawLInt(insamples); outreader.RawLInt(outsamples);
		inreader.RawLInt(innodes); outreader.RawLInt(outnodes);
		ASSERT(insamples=outsamples, 502);
		NEW(InMatrix, insamples, innodes);
		NEW(TargetMatrix, outsamples, outnodes);


		FOR row:=0 TO insamples-1 DO
			FOR col:=0 TO innodes-1 DO
				inreader.RawLReal(InMatrix[row,col]);
			END;
			FOR col:=0 TO outnodes-1 DO
				outreader.RawLReal(TargetMatrix[row,col]);
			END;
		END;

		InMatrixTrain:=InMatrix[..BY 2,..];
		InMatrixTest:=InMatrix[1..BY 2,..];
		TargetMatrixTrain:=TargetMatrix[.. BY 2, ..];
		TargetMatrixTest:=TargetMatrix[1.. BY 2, ..];


		Out.String( "..samples.." );  Out.Int(LEN(InMatrix,0),6); Out.Int(LEN(InMatrix,1),6); Out.Int(LEN(TargetMatrix,0),6); Out.Int(LEN(TargetMatrix,1),6);  Out.Ln;

		Out.String( "..samples.." );  Out.Ln;
		Util.Out( InMatrix[0..2,..] );
		Out.String( "..target to be approximated by learning machine.." );  Out.Ln;
		Util.Out( TargetMatrix[0..2,..]);

		(* create an artificial neural network with default parameters *)
		NEW( Net );
		Net.eta:=15*Net.eta;
		Net.ValidationIn:=InMatrixTest;
		Net.ValidationTarget:=TargetMatrixTest;

		Net.function:=Rectifier;
		Net.derivativeDelta:=RectifierDerivativeDelta;


		IF ~context.arg.GetInteger(layers,FALSE) THEN layers:=3 END;
		NEW(layerVector,layers);
		layerVector[0]:=innodes; layerVector[1..layers-2]:=InnerNodes; layerVector[layers-1]:=outnodes;
		NEW(typeVector, layers-1);
		typeVector[..layers-3]:=sigmoid; typeVector[layers-2]:=linear;

		IF context.arg.GetInteger(iterations,FALSE) THEN Net.trainingEpisodes:=iterations END;
		Net.Build( layerVector, typeVector);

		(*Net.Build( [innodes, FirstLayerNodes, outnodes], [sigmoid, linear]);  *)

		(* train the network*)
		(*Net.Learn( InMatrix, TargetMatrix );  *)
		(*! version with train and test dataset*)
		Net.Learn( InMatrixTrain, TargetMatrixTrain );

		(* evaluate the network's performance *)

		Out.String( "..Neural Network evaluates first sample to check fitting to single target." );  Out.Ln;
		Util.Out(Net.EvaluateVector(InMatrix[0])); (* evaluation of single feature vector*) Out.Ln;

		Out.String( "..Neural Network evaluates all training samples to check fitting to targets.." );  Out.Ln;

		(*Classification := Net.EvaluateVectorN( InMatrix ); *)  (* evaluation of multiple feature vectors *)
		(*! version with train and test dataset*)
		Classification := Net.EvaluateVectorN( InMatrixTest );

		(*Util.Out( Classification );  *)
		(*
		Out.String( "..Sum of Squared Residuals; MSE: " );
		SSE:=(Classification - TargetMatrix)+*(Classification - TargetMatrix);
		Util.OutFloat(SSE,12,5,0); Util.OutFloat(SSE/LEN(Classification,0)/LEN(Classification,1),12,5,0); Out.Ln;

		Util.Out( Classification[..5,..] - TargetMatrix[..5,..] );
		Util.Out( Classification[0..5,..] );
		Util.Out( TargetMatrix[0..5,..] );
		*)

		(*! version with train and test dataset*)
		Classification := Net.EvaluateVectorN( InMatrixTest );
			Out.String( "..Residual.." );  Util.OutFloat((Classification - TargetMatrixTest)+*(Classification - TargetMatrixTest),12,5,0); Out.Ln;

	END TestCO2;

	PROCEDURE DoNothing(x:FLOAT64):FLOAT64;
	BEGIN
		RETURN x;
	END DoNothing;

	PROCEDURE TestNegl*(context:Commands.Context);
	BEGIN
		context.out.Float(PMath.expNegligible,20);
		context.out.Float(PMath.expNegligibleL,20);
		context.out.Ln; context.out.Update;
	END TestNegl;

	PROCEDURE TestAll*(context:Commands.Context);
	VAR a,b,c,d: ARRAY [*,*] OF FLOAT64;
		cs: ARRAY [*,*] OF FLOAT32;
		x,y:FLOAT32; X,Y:FLOAT64;
		i,j, t0,t1,t2,t3,t4,t5,t6,t7,t8,t9,t10,t11,t12,t13,t14,t15,t16,t17,t18,t19:SIGNED32;
	BEGIN
		IF ~context.arg.GetInteger(i,FALSE) THEN i:=1000 END;
		NEW(a,i,i);
		NEW(b,i,i);
		NEW(c,i,i);
		NEW(d,i,i);

		t8:=Kernel.GetTicks();
		FOR j:=0 TO i*i-1 DO
			Y:=Tanh(X);
		END;
		t9:=Kernel.GetTicks();

		t10:=Kernel.GetTicks();
		(*d:=ALL(c,Tanh);*)
		d:=All1(c,Tanh);
		t11:=Kernel.GetTicks();

		cs:=SHORT(c);
		t12:=Kernel.GetTicks();
		(*d:=ALL(cs,PMathSSE.tanhFast);*)
		(*d:=All1(cs,PMathSSE.tanhFast);*)
		t13:=Kernel.GetTicks();


		t16:=Kernel.GetTicks();
		FOR j:=0 TO i*i -1 DO
			y:=Math.exp(x);
		END;
		t17:=Kernel.GetTicks();

		KernelLog.Int(t1-t0,10); KernelLog.Int(t3-t2,10); KernelLog.Int(t5-t4,10); KernelLog.Int(t7-t6,10); KernelLog.Int(t9-t8,10);
		KernelLog.Int(t11-t10,10); KernelLog.Int(t13-t12,10); KernelLog.Int(t15-t14,10);
		KernelLog.Int(t17-t16,10); KernelLog.Int(t19-t18,10); KernelLog.Ln;
	END TestAll;

	PROCEDURE TestSoftMax*(context:Commands.Context);
	VAR a,b:ARRAY [*] OF Datatype;
	BEGIN
		a:=[-1, 1,3,5,7];

		a:=[ 1.0093 , 0.8955, -0.5723,  0.6810 , 0.2726,  1.0361,  1.0238,  0.6846];
		b:=a;
		Util.Out(b);
		SoftMax(b);
		Util.Out(b);
		b:=a;
		SoftMaxTanhNormalize(b);
		Util.Out(b);
		b:=a;
		SoftMaxNormalize(b); context.out.Float(SUM(b),14); context.out.Ln; context.out.Update;
		Util.Out(b);
	END TestSoftMax;

	(*2 layers with sigmoid with a softmax layer on top*)
	PROCEDURE TestDeepSoftmax*(context:Commands.Context);
	CONST Samples = 40;  InputNodes = 8;  InnerNodes = 10;  outputNodes = 8;
	VAR InMatrix, TargetMatrix, Classification: Matrix;  Net: Network;
		iterations:SIGNED32;
		layers:SIGNED32;
		layerVector, typeVector: ARRAY [*] OF SIGNED32;
		SSE: FLOAT64;
	BEGIN
		Out.String( "Neural Network Demo with softmax output" );  Out.Ln;
		(*create matrices depending on sample size and input/output number; example is for linear descent search;
		Note that InMatrix and TargetMatrix differ in structure for stochastic search...*)

		(* invent test data *)
		SampleData2( Samples, InputNodes, outputNodes, InMatrix, TargetMatrix );
		Out.String( "..samples.." );  Out.Ln;
		Util.Out( InMatrix );
		Out.String( "..target to be approximated by learning machine.." );  Out.Ln;
		Util.Out( TargetMatrix );

		(* create the artificial neural network *)
		NEW( Net );
		Net.alpha:=0.4;
		Net.function:=Sigmoid;
		Net.derivativeDelta:=SigmoidDerivativeDelta;

		layers:=6;
		NEW(layerVector,layers);
		layerVector[0]:=InputNodes;
		layerVector[1..layers-2]:=InnerNodes;
		layerVector[layers-1]:=outputNodes;

		Net.trainingEpisodes:=5000;


		NEW(typeVector, layers-1);
		typeVector[..layers-3]:=sigmoid;
		typeVector[layers-2]:=softmax;
		Net.Build( layerVector, typeVector);

		(* train the network*)
		Net.Learn( InMatrix, TargetMatrix );

		(* evaluate the network's performance *)
		Out.String( "..Neural Network evaluates first sample to check fitting to single target." );  Out.Ln;
		Util.Out(Net.EvaluateVector(InMatrix[0])); (* evaluation of single feature vector*) Out.Ln;

		Out.String( "..Neural Network evaluates all training samples to check fitting to targets.." );  Out.Ln;
		Classification := Net.EvaluateVectorN( InMatrix );   (* evaluation of multiple feature vectors *)
		Util.Out( Classification );

		Out.String( "..Sum of Squared Residuals; MSE: " );
		SSE:=(Classification - TargetMatrix)+*(Classification - TargetMatrix);
		Util.OutFloat(SSE,12,5,0); Util.OutFloat(SSE/LEN(Classification,0)/LEN(Classification,1),12,5,0); Out.Ln;

		Util.Out( Classification - TargetMatrix );
	END TestDeepSoftmax;



	PROCEDURE TestWide*(context:Commands.Context);
	CONST  outputNodes = 8;
	VAR InMatrix, TargetMatrix, Classification: Matrix;  Net: Network;
		samples, inputNodes, innerNodes, iterations:SIGNED32;
		layers:SIGNED32;
		layerVector, typeVector: ARRAY [*] OF SIGNED32;
		SSE: FLOAT64;
		t0,t1:SIGNED32;
	BEGIN
		Out.String( "Neural Network Demo" );  Out.Ln;
		(*create matrices depending on sample size and input/output number; example is for linear descent search;
		Note that InMatrix and TargetMatrix differ in structure for stochastic search...*)

		(* invent test data *)
		IF ~context.arg.GetInteger(inputNodes,FALSE) THEN inputNodes:=40 END;
		Out.Int(inputNodes, 0); Out.String(" inputNodes, ");

		IF ~context.arg.GetInteger(samples,FALSE) THEN samples:=40 END;
		Out.Int(samples, 0); Out.String(" samples, ");

		SampleData2( samples, inputNodes, outputNodes, InMatrix, TargetMatrix );


		(* create the artificial neural network *)
		NEW( Net );
		Net.eta:=Net.eta/4;

		(*Net.alpha:=0.4;*)
		(*

		Net.function:=Rectifier;
		Net.derivativeDelta:=RectifierDerivativeDelta;
		*)
		(*
		Net.function:=SoftPlus;
		Net.derivativeDelta:=SoftPlusDerivativeDelta;
		*)
		(*
		Net.function:=Sigmoid;
		Net.derivativeDelta:=SigmoidDerivativeDelta;
		*)
		(*
		Net.function:=Logistic;
		Net.derivativeDelta:=LogisticDerivativeDelta;
		*)

		IF ~context.arg.GetInteger(layers,FALSE) THEN layers:=3 END;
		Out.Int(layers, 0); Out.String(" layers, ");

		IF ~context.arg.GetInteger(innerNodes,FALSE) THEN innerNodes:=10 END;
		Out.Int(innerNodes, 0); Out.String(" innerNodes, ");

		NEW(layerVector,layers);
		layerVector[0]:=inputNodes; layerVector[1..layers-2]:=innerNodes; layerVector[layers-1]:=outputNodes;

		IF context.arg.GetInteger(iterations,FALSE) THEN Net.trainingEpisodes:=iterations END;
		Out.Int(iterations, 0); Out.String(" iterations "); Out.Ln;
		NEW(typeVector, layers-1);
		typeVector[..layers-3]:=sigmoid;
		typeVector[layers-2]:=linear;
		Net.Build( layerVector, typeVector);
		(*
		Net.Layers.next.function:=Sigmoid;
		Net.Layers.next.derivativeDelta:=SigmoidDerivativeDelta;
		*)

		(* train the network*)
		t0:=Kernel.GetTicks();
		Net.Learn( InMatrix, TargetMatrix );
		t1:=Kernel.GetTicks();

		(* evaluate the network's performance *)
		Out.String( "..Neural Network evaluates first sample to check fitting to single target." );  Out.Ln;
		Util.Out(Net.EvaluateVector(InMatrix[0])); (* evaluation of single feature vector*) Out.Ln;

		Out.String( "..Neural Network evaluates all training samples to check fitting to targets.." );  Out.Ln;
		Classification := Net.EvaluateVectorN( InMatrix );   (* evaluation of multiple feature vectors *)
		(*Util.Out( Classification );  *)

		Out.String( "..Sum of Squared Residuals; MSE: " );
		SSE:=(Classification - TargetMatrix)+*(Classification - TargetMatrix);
		Util.OutFloat(SSE,12,5,0); Util.OutFloat(SSE/LEN(Classification,0)/LEN(Classification,1),12,5,0); Out.Ln;

		Out.String("compute time [ms]: "); Out.Int(t1-t0,0); Out.Ln;
		(*Util.Out( Classification - TargetMatrix );  *)

	END TestWide;

	PROCEDURE TestRBM*(context:Commands.Context);
	CONST Samples = 8;  InputNodes = 8;  FirstLayerNodes = 6;
	VAR InMatrix, TargetMatrix, Reconstruction, r : Matrix;
		iterations:SIGNED32;
		rbm: RestrictedBoltzmannMachine;
		i:SIGNED32;
	BEGIN
		Out.String( "Restricted Boltzmann Machine Demo" );  Out.Ln;

		(* invent test data *)
		SampleDataBinary( Samples, InputNodes, FirstLayerNodes, InMatrix, TargetMatrix );
		NEW(Reconstruction, Samples, InputNodes);

		NEW(rbm);
		rbm.Create(InputNodes, FirstLayerNodes, Sigmoid, NIL, TRUE);

		IF ~context.arg.GetInteger(iterations,FALSE) THEN iterations:=100 END;
		FOR i:=0 TO iterations-1 DO
			Reconstruction[i MOD 8..i MOD 8]:=rbm.ContrastiveDivergenceStep(InMatrix[i MOD 8..i MOD 8]); (*stochastic descent - one sample at a time*)
			(*Reconstruction:=rbm.ContrastiveDivergenceStep(InMatrix);*) (* gradient descent, all samples together; needs improved handling of rbm.hidden in ContrastiveDivergenceStep() *)
			IF i MOD (iterations DIV 100)=0 THEN
				IF (i MOD 8)=0 THEN
				context.out.Float( (Reconstruction-InMatrix)+* (Reconstruction-InMatrix), 24); context.out.Ln; context.out.Update;
				END;
			END;
		END;

		Out.String( "Input, weights, reconstruction, error: " );  Out.Ln;
		Util.Out( InMatrix );
		FOR i:=0 TO LEN(InMatrix,0)-1 DO
			r:=rbm.ContrastiveDivergenceStep(InMatrix[i MOD 8..i MOD 8]);
			Util.Out(rbm.hidden[0,..]);
		END;
		Out.Ln;
		Util.Out(rbm.weights);
		Util.Out(Reconstruction);
		Util.Out(InMatrix-Reconstruction);
	END TestRBM;

	PROCEDURE TestDBN*(context:Commands.Context);
	CONST Samples = 8;  InputNodes = 8;  FirstLayerNodes = 6;
	VAR InMatrix, TargetMatrix, Reconstruction,
		h0,h1,h2, r0,r1,r2 : Matrix;
		rv0, v:Vector;
		iterations:SIGNED32;
		rbm,rbm1,rbm2: RestrictedBoltzmannMachine;
		i:SIGNED32;
	BEGIN
		Out.String( "Deep Believe Network Demo" );  Out.Ln;

		(* invent test data *)
		SampleDataBinary( Samples, InputNodes, FirstLayerNodes, InMatrix, TargetMatrix );
		Util.Out( InMatrix );

		NEW(Reconstruction, Samples, InputNodes);

		NEW(rbm);
		rbm.Create(InputNodes, FirstLayerNodes, Sigmoid, NIL, TRUE);
		IF ~context.arg.GetInteger(iterations,FALSE) THEN iterations:=100 END;
		FOR i:=0 TO iterations-1 DO
			Reconstruction[i MOD 8..i MOD 8]:=rbm.ContrastiveDivergenceStep(InMatrix[i MOD 8..i MOD 8]); (*stochastic descent - one sample at a time*)
(*			Reconstruction[i MOD 8]:=rbm.ContrastiveDivergenceStepVector(InMatrix[i MOD 8]); *)(*stochastic descent - one sample at a time*)

			IF i MOD (iterations DIV 100)=0 THEN
				IF (i MOD 8)=0 THEN
				context.out.Float( (Reconstruction-InMatrix)+* (Reconstruction-InMatrix), 24); context.out.Ln; context.out.Update;
				END;
			END;
		END;
		NEW(h0, Samples, FirstLayerNodes);
		FOR i:=0 TO Samples-1 DO
			r0:=rbm.ContrastiveDivergenceStep(InMatrix[i..i]);
			h0[i]:=rbm.hidden[0,..];

			(*rv0:=rbm.ContrastiveDivergenceStepVector(InMatrix[i]);
			h0[i,..]:=rbm.hid;*)
		END;

		Out.String("----- level 1--------");Out.Ln;
		context.out.String("-------------"); context.out.Ln;
		NEW(rbm1);
		rbm1.Create(FirstLayerNodes, FirstLayerNodes-1, Sigmoid , NIL, TRUE);
		NEW(r1,LEN(h0));
		FOR i:=0 TO iterations-1 DO
			r1[i MOD 8..i MOD 8]:=rbm1.ContrastiveDivergenceStep(h0[i MOD 8..i MOD 8]); (*stochastic descent - one sample at a time*)
			(*r1[i MOD 8]:=rbm1.ContrastiveDivergenceStepVector(h0[i MOD 8]); *)
			IF i MOD (iterations DIV 100)=0 THEN
				IF (i MOD 8)=0 THEN
				context.out.Float( (r1-h0)+* (r1-h0), 24); context.out.Ln; context.out.Update;
				END;
			END;
		END;
		NEW(h1, Samples, LEN(rbm1.hidden,1));
		FOR i:=0 TO Samples-1 DO
			r1[i..i]:=rbm1.ContrastiveDivergenceStep(h0[i..i]);
			h1[i]:=rbm1.hidden[0,..];
			(*r1[i]:=rbm1.ContrastiveDivergenceStepVector(h0[i]);*)
			(*h1[i]:=rbm1.hid[..];*)
		END;

		Out.String("----- level 2--------");Out.Ln;
		context.out.String("-------------"); context.out.Ln;
		NEW(rbm2);
		rbm2.Create(FirstLayerNodes-1, FirstLayerNodes-2, Sigmoid, NIL, TRUE );
		NEW(r2,LEN(h1));
		FOR i:=0 TO iterations-1 DO
			r2[i MOD 8..i MOD 8]:=rbm2.ContrastiveDivergenceStep(h1[i MOD 8..i MOD 8]); (*stochastic descent - one sample at a time*)
			(*r2[i MOD 8]:=rbm2.ContrastiveDivergenceStepVector(h1[i MOD 8]);*) (*stochastic descent - one sample at a time*)
			IF i MOD (iterations DIV 100)=0 THEN
				IF (i MOD 8)=0 THEN
				context.out.Float( (r2-h1)+* (r2-h1), 24); context.out.Ln; context.out.Update;
				END;
			END;
		END;
		context.out.String(".."); context.out.Update;
		NEW(h2, Samples, LEN(rbm2.hidden,1));
		FOR i:=0 TO Samples-1 DO
			r2[i..i]:=rbm2.ContrastiveDivergenceStep(h1[i..i]);
			h2[i]:=rbm2.hidden[0,..];
			(*r2[i]:=rbm2.ContrastiveDivergenceStepVector(h1[i]);
			h2[i]:=rbm2.hid[..];*)
		END;

		Out.String( "---------Input, weights, reconstruction, error: --------" );  Out.Ln;
		Util.Out(InMatrix);
		h0:=rbm.Evaluate(InMatrix);
		h1:=rbm1.Evaluate(h0);
		h2:=rbm2.Evaluate(h1);
		rbm2.BackPropagate(h2); r2:=rbm2.reconstructed;
		rbm1.BackPropagate(r2); r1:=rbm1.reconstructed;
		rbm.BackPropagate(r1); r0:=rbm.reconstructed;
		Util.Out(h0);
		Util.Out(h1);
		Util.Out(h2);

		Out.String("--");Out.Ln;
		Util.Out(r2);
		Util.Out(r1);
		Util.Out(r0);
		Util.Out(InMatrix);
		Out.String("----"); Out.Ln;
		Util.Out(InMatrix-r0);
		Out.String("-------------");Out.Ln;
	END TestDBN;

	PROCEDURE TestDBN2*(context:Commands.Context);
	CONST Samples = 8;  InputNodes = 8;  FirstLayerNodes = 6;
	VAR InMatrix,  TargetMatrix,
		h0,r0: Matrix;
		iterations:SIGNED32;
		dbn:DeepBelieveNetwork;
		sig:SIGNED32;
	BEGIN
		Out.String( "Deep Believe Network Demo" );  Out.Ln;
		sig:=sigmoid;
		NEW(dbn, [8, 6,5,4], [sig,sig,sig], Sigmoid, SigmoidDerivativeDelta, FALSE); (*hack for compiler problem solved in 2/16*)
		(*NEW(dbn, [8, 6,5,4], [sigmoid,sigmoid,sigmoid], Sigmoid, SigmoidDerivativeDelta, FALSE);*)
		dbn.log:=context.out;

		IF ~context.arg.GetInteger(iterations,FALSE) THEN iterations:=100 END;

		(* invent test data *)
		SampleDataBinary( Samples, InputNodes, FirstLayerNodes, InMatrix, TargetMatrix );
		dbn.TrainUnsupervised(InMatrix, iterations);

		Out.String( "---------Input, output, reconstruction, error: ----------" );  Out.Ln;
		Util.Out(InMatrix);

		h0:=dbn.Evaluate(InMatrix);
		Util.Out(h0);

		r0:=dbn.Reconstruct(h0);
		Util.Out(r0);

		Util.Out(r0-InMatrix);
		dbn.log.String("reconstruction error = "); dbn.log.Float((r0-InMatrix)+*(r0-InMatrix),24); dbn.log.Ln; dbn.log.Update;
		Out.String("-------------");Out.Ln;
	END TestDBN2;


	PROCEDURE TestMM*(context:Commands.Context);
	VAR iterations, i,t0,t1,t2,t3,t4,t5:SIGNED32;
		a,b,c: Matrix;
	BEGIN
		IF ~context.arg.GetInteger(iterations,FALSE) THEN iterations:=100 END;
		NEW(a,100,100);
		b:=a;
		c:=a;
		t0:=Kernel.GetTicks();
		FOR i:=0 TO iterations-1 DO
			a:=b*c;
		END;
		t1:=Kernel.GetTicks();
		FOR i:=0 TO iterations-1 DO
			a:=b`*c;
		END;
		t2:=Kernel.GetTicks();
		FOR i:=0 TO iterations-1 DO
			a:=b*c`;
		END;
		t3:=Kernel.GetTicks();
		t4:=Kernel.GetTicks();
		t5:=Kernel.GetTicks();
		context.out.Int(t1-t0, 10);
		context.out.Int(t2-t1, 10);
		context.out.Int(t3-t2, 10);
	END TestMM;



VAR rand:Random.Generator;

BEGIN
	NEW(rand);
END MLNeuralNet.

(*PROCEDURE MLNeuralNet.Test maps sample vectors (InMatrix) of which each has 8 features (elements) through a 3 layer neural network (linear-sigmoid-linear) to the target vectors (TargetMatrix).
Note the decreasing error indicating improving fit of the mapping; Note that longer training time can improve fitting in the training data set, while at a given point, new test data start
to give worse result due to 'overfitting', i.e. modeling noise in the data. This can be avoided if in parallel to the training, a small test set is tested without using it for training; when the error for this
test set definitely rises, the optimum training point may have been already passed *)

MLNeuralNet.Test~
MLNeuralNet.Test 1000000~
MLNeuralNet.Test 50000000~
MLNeuralNet.TestDeep 4 200000~

MLNeuralNet.TestDeepSoftmax~

(* inputNodes - samples - layers - innerNodes - iterations *)
MLNeuralNet.TestWide 40 128 3 128 20000~

MLNeuralNet.TestCO~
MLNeuralNet.TestCO2~
MLNeuralNet.TestCO2 4 2000~
MLNeuralNet.TestCO2 8 15000~

MLNeuralNet.TestAll 4000~
MLNeuralNet.TestSoftMax ~
MLNeuralNet.TestNegl~

MLNeuralNet.TestRBM 20000000 ~
MLNeuralNet.TestDBN 10000 ~
MLNeuralNet.TestDBN2 30000 ~
MLNeuralNet.TestMM 1000 ~

MLNeuralNet.TestSigmoid ~

MLNeuralNet.TestWeightLoading ~


OFormatter.Format *
fofPC.Compile \s *
fofPC.Compile \f *
SystemTools.Free MLNeuralNet RBMFineTuning~
System.State MLNeuralNet
SystemTools.FreeDownTo BSplines PMath FoxArrayBase ~

------------------------------------------
A neural network creates a mapping a set of M input vectors (LEN=N) to a set of M output vectors (LEN=P);
A new example vector or a set of new example vectors (packed into a matrix) can then be evaluated with this mapping for classification.

In contrast to solving a set of linear equations for this task (using for example SVD)
neural networks are also capable of modeling nonlinear relations (like XOR, which cannot be modeled by linear algebra).
It has been proven that arbitrary functions can be represented to an arbitrary precision using at least a 3-layer neural network with sigmoid behaviour of the hidden (middle) layer.
The drawback, however, is that neural networks can be are very tedious to train necessitating thousands of training repetitions;
however, evaluation of new examples is very fast.

Here is what it does:

1) Build a Neural network structure (NeuralNet.Build) with, in our case,
	a total of 3 layers of 8,12,8 nodes, respectively
	the input into layer 2 is subjected to a sigmoid transform, the input and output layer is linear.
2) Initialize (arbitrary) weights for propagation of individual node values from a level to the
	next level (NeuralNet.initWeights; NeuralNet.New)
3) Take  one dataset, propagate it forward through the network (NeuralNet.round)
	when you reach the last level, calculate the difference of the result from the expected value;
4) Use the error of step 3 for adjusting retrogradely the network weights by stochastic gradient descent
	(also in NeuralNet.round)

5) repeat steps 3 & 4 for all input-output pairs
6) repeat step 5 many times, leading to minimisation of the error produced; i.e.
	from the set of given inputs, the neuralnet is able to calculate the expected outputs.
7) After a large enough number of input-output pairs is used for this training of the network,
	new inputs (not part of the training sets) can be fed into the network (NeuralNet.eval)
	and the probable output yielded.

startweight is the average initial value of the weights, which is initially arbitrarily distributed. A reasonable value is: startweight <= 1/(NrOfInputs)
eta is the approximation step, a possible value is 0.005;
alpha is the momentum term: if consecutive gradient descent steps go into the same direction, the stepsize is increased by the factor alpha. This is not absolutely needed, but may speed up convergence.

This algorithm has been published before by Mitchell,
and has proven robust in several tasks, including image recognition.

Future evolution: see BLAS background:
- optimized matrix operations depend on further "meta" knowledge about content of matrices:
	-> diagonal matrices, symmetric matrices, triangular matrices are frequent and can achieve a speedup of 2 or more just by knowing their structure.