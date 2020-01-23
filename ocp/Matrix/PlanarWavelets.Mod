MODULE PlanarWavelets; (** AUTHOR "Patrick Hunziker"; PURPOSE "2D wavelet decomposition"; *)

IMPORT Wavelets, WMArrayPanel, PMath;

CONST 
	Plain*=0; (*can be 1..n levels *)
	Packet*=1;

TYPE Datatype*=Wavelets.Datatype;
	Tensor*=ARRAY [?] OF Datatype;
	Matrix*=ARRAY [*,*] OF Datatype;
	Line*=ARRAY [*] OF Datatype;
	ProcessProc*= PROCEDURE{DELEGATE} (CONST d: Matrix):Matrix;

TYPE Analyzer*= OBJECT
	VAR data*: Matrix;
		waveletType, boundary: SIGNED32;
		conv: Wavelets.WaveletConvolver;
		wavelet*:Wavelets.WaveletFamily;
		lineX,resX, lineY,resY: Line;
		child: Analyzer;

		(*choose wavelet family; need to choose compatible boundary conditions - see Wavelets.Mod*)
	PROCEDURE &Init*(waveletType, boundary: SIGNED32; CONST data: Matrix);
	BEGIN
		SELF.waveletType:=waveletType;
		NEW(wavelet, waveletType);
		IF boundary=Wavelets.default THEN SELF.boundary:=wavelet.defaultBoundary ELSE SELF.boundary:=boundary END;
		NEW(conv, wavelet, boundary);
		SetData(data);
	END Init;

	PROCEDURE SetData*(CONST data: Matrix);
	BEGIN
		IF LEN(data)>0 THEN
			IF LEN(data)#LEN(SELF.data) THEN
				NEW(SELF.data, LEN(data));
				NEW(lineY, LEN(data,0)); NEW(resY, LEN(data,0));
				NEW(lineX, LEN(data,1)); NEW(resX, LEN(data,1));
			END;
			SELF.data:=data; (*!copy. could do in-place ?*)
		END;
	END SetData;
	
	(*location: array of indices(LL,LH,HL,HH), per layer. E.g., for plain: [0,0,3]; e.g. for packet: [2,0,3]*)
	PROCEDURE GetSubband*(CONST d:Matrix; CONST location: ARRAY [*] OF INTEGER):Matrix;
	VAR w,h: SIZE;
	BEGIN
		ASSERT(LEN(location,0)>0, 200);
		ASSERT((location>=0) & (location<4), 201); 
		w:=(LEN(d,1)+1) DIV 2; h:=(LEN(d,0)+1) DIV 2;
		IF LEN(location,0)=1 THEN
			IF location[0]=0 	THEN RESULT:=d[..h-1,..w-1]
			ELSIF location[0]=1 THEN RESULT:=d[..h-1,w..]
			ELSIF location[0]=2 THEN RESULT:=d[h..,..w-1]
			ELSIF location[0]=3 THEN RESULT:=d[h..,w..]
			ELSE HALT(202)
			END;
		ELSE
			IF location[0]=0 	THEN RESULT:=GetSubband(d[..h-1,..w-1], location[1..])
			ELSIF location[0]=1 THEN RESULT:=GetSubband(d[..h-1,w..], location[1..])
			ELSIF location[0]=2 THEN RESULT:=GetSubband(d[h..,..w-1], location[1..])
			ELSIF location[0]=3 THEN RESULT:=GetSubband(d[h..,w..], location[1..])
			ELSE HALT(203)
			END;
		END;
		RETURN RESULT
	END GetSubband;

	(*location: array of indices(LL,LH,HL,HH), per layer. E.g., for plain: [0,0,3]; e.g. for packet: [2,0,3]*)
	PROCEDURE SetSubband*(VAR dest:Matrix; CONST src:Matrix; CONST location: ARRAY [*] OF INTEGER);
	VAR w,h: SIZE;
	BEGIN
		ASSERT(LEN(location,0)>0, 200);
		ASSERT((location>=0) & (location<4), 201); 
		w:=(LEN(dest,1)+1) DIV 2; h:=(LEN(dest,0)+1) DIV 2;
		IF LEN(location,0)=1 THEN
			IF location[0]=0 	THEN dest[..h-1,..w-1]:=src;
			ELSIF location[0]=1 THEN dest[..h-1,w..]:=src;
			ELSIF location[0]=2 THEN dest[h..,..w-1]:=src;
			ELSIF location[0]=3 THEN dest[h..,w..]:=src;
			ELSE HALT(202)
			END;
		ELSE
			IF location[0]=0 	THEN SetSubband(dest[..h-1,..w-1],src, location[1..])
			ELSIF location[0]=1 THEN SetSubband(dest[..h-1,w..],src, location[1..])
			ELSIF location[0]=2 THEN SetSubband(dest[h..,..w-1],src, location[1..])
			ELSIF location[0]=3 THEN SetSubband(dest[h..,w..],src, location[1..])
			ELSE HALT(203)
			END;
		END;
	END SetSubband;

	PROCEDURE Analyze*;
	VAR i:SIZE; 
	BEGIN
		FOR i:=0 TO LEN(data,0)-1 DO
			conv.Analyze(data[i], resX);
			data[i]:=resX; (*could do in-place ?*)
		END;
		FOR i:=0 TO LEN(data,1)-1 DO
			conv.Analyze(data[..,i], resY);
			data[..,i]:=resY; (* could do in-place ? *)
		END;
	END Analyze;

	PROCEDURE AnalyzeMultiscale*(levels:SIGNED32);
	BEGIN
		Analyze;
		IF levels>1 THEN
			NEW(child, waveletType, boundary, data[..(LEN(data,0)+1)DIV 2-1, ..(LEN(data,1)+1) DIV 2-1]);
			child.AnalyzeMultiscale(levels-1);
			data[..(LEN(data,0)+1)DIV 2-1, ..(LEN(data,1)+1) DIV 2-1]:=child.data;
		END;
	END AnalyzeMultiscale;

	PROCEDURE AnalyzePacket*(levels:SIGNED32);
	BEGIN
		Analyze;
		IF levels>1 THEN
			NEW(child, waveletType, boundary, data[..(LEN(data,0)+1)DIV 2-1, ..(LEN(data,1)+1) DIV 2-1]); (*! should use child.SetData for efficiency*)
			child.AnalyzePacket(levels-1);
			data[..(LEN(data,0)+1)DIV 2-1, ..(LEN(data,1)+1) DIV 2-1]:=child.data;

			child.Init(waveletType, boundary, data[(LEN(data,0)+1)DIV 2.., ..(LEN(data,1)+1) DIV 2-1]);
			child.AnalyzePacket(levels-1);
			data[(LEN(data,0)+1)DIV 2.., ..(LEN(data,1)+1) DIV 2-1]:=child.data;

			child.Init(waveletType, boundary, data[..(LEN(data,0)+1)DIV 2-1, (LEN(data,1)+1) DIV 2..]);
			child.AnalyzePacket(levels-1);
			data[..(LEN(data,0)+1)DIV 2-1, (LEN(data,1)+1) DIV 2..]:=child.data;

			child.Init(waveletType, boundary, data[(LEN(data,0)+1)DIV 2.., (LEN(data,1)+1) DIV 2..]);
			child.AnalyzePacket(levels-1);
			data[(LEN(data,0)+1)DIV 2.., (LEN(data,1)+1) DIV 2..]:=child.data;
		END;

	END AnalyzePacket;

	END Analyzer;

TYPE Reconstructor*= OBJECT
	VAR data*: Matrix;
		 waveletType, boundary: SIGNED32;
		conv: Wavelets.WaveletConvolver;
		wavelet*:Wavelets.WaveletFamily;
		lineX,resX, lineY,resY: Line;
		child: Reconstructor;

		(*choose wavelet family; need to choose compatible boundary conditions - see Wavelets.Mod*)
	PROCEDURE &Init*(waveletType, boundary: SIGNED32; CONST data: Matrix);
	BEGIN
		SELF.waveletType:=waveletType;
		NEW(wavelet, waveletType);
		IF boundary=Wavelets.default THEN SELF.boundary:=wavelet.defaultBoundary ELSE SELF.boundary:=boundary END;
		NEW(conv, wavelet, boundary);
		SetData(data);
	END Init;

	PROCEDURE SetData*(CONST data: Matrix);
	BEGIN
		IF LEN(data)>0 THEN
			IF LEN(data)#LEN(SELF.data) THEN
				NEW(SELF.data, LEN(data));
				NEW(lineY, LEN(data,0)); NEW(resY, LEN(data,0));
				NEW(lineX, LEN(data,1)); NEW(resX, LEN(data,1));
			END;
			SELF.data:=data; (*!copy. could do in-place ?*)
		END;
	END SetData;


	PROCEDURE Reconstruct*;
	VAR i:SIZE; 
	BEGIN
		FOR i:=0 TO LEN(data,0)-1 DO
			conv.Reconstruct(data[i], resX);
			data[i]:=resX; (*could do in-place ?*)
		END;
		FOR i:=0 TO LEN(data,1)-1 DO
			conv.Reconstruct(data[..,i], resY);
			data[..,i]:=resY; (* could do in-place ? *)
		END;
	END Reconstruct;

	PROCEDURE ReconstructMultiscale*(levels:SIGNED32);
	BEGIN
		IF levels>1 THEN
			NEW(child, waveletType, boundary, data[..(LEN(data,0)+1)DIV 2-1, ..(LEN(data,1)+1) DIV 2-1]);
			child.ReconstructMultiscale(levels-1);
			data[..(LEN(data,0)+1)DIV 2-1, ..(LEN(data,1)+1) DIV 2-1]:=child.data;
		END;
		Reconstruct;
	END ReconstructMultiscale;

	PROCEDURE ReconstructPacket*(levels:SIGNED32);
	BEGIN
		IF levels>1 THEN
			NEW(child, waveletType, boundary, data[..(LEN(data,0)+1)DIV 2-1, ..(LEN(data,1)+1) DIV 2-1]); (*! should use child.SetData for efficiency*)
			child.ReconstructPacket(levels-1);
			data[..(LEN(data,0)+1)DIV 2-1, ..(LEN(data,1)+1) DIV 2-1]:=child.data;

			child.Init(waveletType, boundary, data[(LEN(data,0)+1)DIV 2.., ..(LEN(data,1)+1) DIV 2-1]);
			child.ReconstructPacket(levels-1);
			data[(LEN(data,0)+1)DIV 2.., ..(LEN(data,1)+1) DIV 2-1]:=child.data;

			child.Init(waveletType, boundary, data[..(LEN(data,0)+1)DIV 2-1, (LEN(data,1)+1) DIV 2..]);
			child.ReconstructPacket(levels-1);
			data[..(LEN(data,0)+1)DIV 2-1, (LEN(data,1)+1) DIV 2..]:=child.data;

			child.Init(waveletType, boundary, data[(LEN(data,0)+1)DIV 2.., (LEN(data,1)+1) DIV 2..]);
			child.ReconstructPacket(levels-1);
			data[(LEN(data,0)+1)DIV 2.., (LEN(data,1)+1) DIV 2..]:=child.data;
		END;
		Reconstruct;
	END ReconstructPacket;

	END Reconstructor;
	
	TYPE Filter*= OBJECT 
			VAR structure*: INTEGER;
(*				coeffs*: ARRAY [? ] OF Datatype; (* [2,2] for each level of a multiscale analysis; [2^n,2^n] for wavelet packets at level n *)
				process*: ARRAY [?] OF PROCEDURE (CONST d: Matrix):Matrix; (*arbitrary processing of data*)
*)				nextLevel*: Filter;	
				PROCEDURE &New*(structure, level, levels:INTEGER);
				BEGIN
					SELF.structure:=structure;
					IF level<levels-1 THEN NEW(nextLevel, structure, level+1, levels) END;
				END New;
				
				(* for n levels, structure of coeffs/proc is:
						in Plain wavelets, coeff/proc = ARRAY [n,2,2]
						in wavelet packets, coeff/proc = ARRAY [2^n,2^n]
				*) 
				PROCEDURE Apply*(VAR data: Matrix; CONST coeffs: ARRAY[?] OF Datatype; CONST proc: ARRAY [?] OF ProcessProc; level, levels:INTEGER); 
				VAR w,h, cw,ch: SIZE; p00,p01,p10,p11: ARRAY [*,*] OF ProcessProc; c00,c01,c10,c11: Matrix;
				BEGIN
					ASSERT(
						(structure=Plain) & ((LEN(coeffs)=[levels,2,2]) OR (LEN(coeffs)=0))		OR
						(structure=Packet) & ((LEN(coeffs)=[PMath.powerof2(levels-level),PMath.powerof2(levels-level)]) OR (LEN(coeffs)=0))		
						, 201);
					ASSERT(
						(structure=Plain) & ((LEN(proc)=[levels,2,2]) OR (LEN(proc)=0))		OR
						(structure=Packet) & ((LEN(proc)=[PMath.powerof2(levels-level),PMath.powerof2(levels-level)]) OR (LEN(proc)=0))		
						, 202);
					w:=(LEN(data,1)+1) DIV 2; (* can be non-power-of-2 *)
					h:=(LEN(data,0)+1) DIV 2;
					cw:=LEN(coeffs,1) DIV 2;(* always power-of-2 *)
					ch:=LEN(coeffs,0) DIV 2;
					IF (structure=Plain) THEN
						IF DIM(coeffs)>0 THEN
							IF level=levels-1 THEN data[..h-1,..w-1]:=coeffs[level, 0,0]*data[..h-1,..w-1] END;
							data[..h-1,w..]:=coeffs[level, 0,1]*data[..h-1,w..];
							data[h..,..w-1]:=coeffs[level, 1,0]*data[h..,..w-1];
							data[h..,w..]:=coeffs[level, 1,1]*data[h..,w..];
						END;
						IF (DIM(proc)>0) & (LEN(proc)>0) THEN
							IF level=levels-1 THEN data[..h-1,..w-1]:=proc[level,0,0](data[..h-1,..w-1]) END;
							data[..h-1,w..]:=proc[level,0,1](data[..h-1,w..]);
							data[h..,..w-1]:=proc[level,1,0](data[h..,..w-1]);
							data[h..,w..]:=proc[level,1,1](data[h..,w..]);
						END;
						IF level<levels-1 THEN
							nextLevel.Apply(data[..h-1,..w-1], coeffs, proc, level+1, levels) 
						END;
					ELSE (*packets*)
						IF level=levels-1 THEN
							IF DIM(coeffs)>0 THEN
								data[..h-1,..w-1]:=coeffs[0,0]*data[..h-1,..w-1];
								data[..h-1,w..]:=coeffs[0,1]*data[..h-1,w..];
								data[h..,..w-1]:=coeffs[1,0]*data[h..,..w-1];
								data[h..,w..]:=coeffs[1,1]*data[h..,w..];
							END;
							IF (DIM(proc)>0) & (LEN(proc)>0) THEN
								data[..h-1,..w-1]:=proc[0,0](data[..h-1,..w-1]);
								data[..h-1,w..]:=proc[0,1](data[..h-1,w..]);
								data[h..,..w-1]:=proc[1,0](data[h..,..w-1]);
								data[h..,w..]:=proc[1,1](data[h..,w..]);
							END;
						ELSE
							IF (DIM(proc)>0) & (LEN(proc)>0) THEN
								p00:=ALIAS OF proc[..ch-1,..cw-1];
								p01:=ALIAS OF proc[..ch-1,cw..];
								p10:=ALIAS OF proc[ch..,..cw-1];
								p11:=ALIAS OF proc[cw..,ch..];
							END;
							IF LEN(coeffs)>1 THEN 
								c00:=ALIAS OF coeffs[..ch-1,..cw-1];
								c01:=ALIAS OF coeffs[..ch-1,cw..];
								c10:=ALIAS OF coeffs[ch..,..cw-1];
								c11:=ALIAS OF coeffs[cw..,ch..];
							END;
							nextLevel.Apply(data[..h-1,..w-1], c00, p00, level+1, levels);
							nextLevel.Apply(data[..h-1,w..], 	c01,	p01, level+1, levels);
							nextLevel.Apply(data[h..,..w-1], 	c10,	p10, level+1, levels);
							nextLevel.Apply(data[h..,w..], 		c11,	p11, level+1, levels);
						END;
					END;
				END Apply;
		END Filter;
	
PROCEDURE Test*;
CONST levels=3;
(*	wavelet=Wavelets.Haar;*)
	wavelet=Wavelets.Spline610;
(*	wavelet=Wavelets.Spline97;*)
	(*wavelet=Wavelets.Cubicspline;*)
VAR a, subHHH, subLLL: Matrix;
	an:Analyzer;
	rec:Reconstructor;
	filter:Filter;
	coeff: ARRAY [?] OF Datatype;
	procs: ARRAY [?] OF ProcessProc;
	d:Matrix;
BEGIN
	NEW(a,200,200); a[50..100,50..100]:=1.0;
	WMArrayPanel.AddWindow(a,"data");
	NEW(an, wavelet, Wavelets.default, a);
	an.AnalyzePacket(levels);
	WMArrayPanel.AddWindow(an.data,"analysis");
	d:=an.data;
	
	(*get subband*)
	subHHH:=an.GetSubband(an.data,[3,3,3]);
	WMArrayPanel.AddWindow(subHHH,"HHH");
	subLLL:=an.GetSubband(an.data,[0,0,0]);
	WMArrayPanel.AddWindow(subLLL,"LLL");
	
	NEW(rec, wavelet, Wavelets.default, d);
	rec.ReconstructPacket(levels);
	WMArrayPanel.AddWindow(rec.data,"reconstruction");
	
	subLLL:=0; (*filtering via subband setting*)
	an.SetSubband(an.data, subLLL, [0,0,0]);
	NEW(rec, wavelet, Wavelets.default, an.data);
	rec.ReconstructPacket(levels);
	WMArrayPanel.AddWindow(rec.data,"reconstruction after subband mod");

	NEW(filter, Packet, 0, levels);
	NEW(coeff, PMath.powerof2(levels), PMath.powerof2(levels));
	coeff:=1.0; coeff[0,0]:=0;
	filter.Apply(d, coeff, procs, 0, levels); 
	
	NEW(rec, wavelet, Wavelets.finite, d);
	rec.ReconstructPacket(levels);
	WMArrayPanel.AddWindow(rec.data,"filtered reconstruction");

	WMArrayPanel.AddWindow(rec.data-a,"error");
END Test;

PROCEDURE {TEST}  Test1*; (* wavelet-decomposition and reconstruction leads to perfect reconstruction of original *)
VAR a: Matrix;
	ana:Analyzer;
	rec:Reconstructor;
BEGIN
	NEW(a,200,200); a[50..100,50..100]:=1.0;
	NEW(ana, Wavelets.Haar, Wavelets.finite, a);
	ana.AnalyzePacket(3);
	NEW(rec, Wavelets.Haar, Wavelets.finite, ana.data);
	rec.ReconstructPacket(3);
	ASSERT(SUM(ABS(rec.data-a)) < 0.0001,200);
END Test1;

END PlanarWavelets.

PlanarWavelets.Test~
PlanarWavelets.Test1~
WMArrayPanel.AddWindow(rec.data,"reconstruction");
System.FreeDownTo PlanarWavelets ~
System.FreeDownTo WMArrayPanel ~

System.DoCommands
Compiler.Compile --test=Test Matrix/PlanarWavelets.Mod ~
Compiler.Compile --test=Test TestTest.Mod ~
FoxTest.Compile -l=ExecutionTest.Log  Execution.Test Execution.TestDiff ~

~ 

System.DoCommands
Compiler.Compile --test=Test TestTest.Mod ~
FoxTest.Compile -l=ExecutionTest.Log  Execution.Test Execution.TestDiff ~

~ 
