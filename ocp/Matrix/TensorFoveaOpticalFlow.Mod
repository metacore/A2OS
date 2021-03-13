MODULE TensorFoveaOpticalFlow; (** AUTHOR "Patrick Hunziker"; PURPOSE ""; *)

IMPORT MOF:=MatrixOpticalFlow, TV:=TensorFovea, Commands, WMGraphics, Files, MatrixRaster, Random, WMArrayPanel, Stat:=StatisticsBase;

TYPE Tensor=TV.Tensor;

PROCEDURE TestA2*(context:Commands.Context); (*n layers, split shell blocks in periphery. use Mean() of each block for encoding*)
VAR 
	raster3 : ARRAY [*,*,*] OF SIGNED16;
	raster, recon, fovea, fovea2: Tensor;
	foveaM,fovea2M: TV.Matrix;
	img: WMGraphics.Image;
	blockSize, nShells:SIGNED32; len, x,y,dx,dy, size, i:SIZE;
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
	dx:=rand.Dice(SIGNED32(size))- size DIV 2;
	dy:=rand.Dice(SIGNED32(size))- size DIV 2;
	fovea:=TV.GetFoveaA2(raster, x, y, blockSize, nShells, Stat.Mean); (* compressed averaging sampling*)
	foveaM:=fovea[0]+fovea[1]; foveaM:=foveaM+fovea[2];
	fovea2:=TV.GetFoveaA2(raster, x+dx, y+dy, blockSize, nShells, Stat.Mean); (* compressed averaging sampling*)
	fovea2M:=fovea2[0]+fovea2[1]; fovea2M:=fovea2M+fovea2[2];
	
	
	recon:=TV.ReconstructFoveaA2(fovea, blockSize, nShells);
	IF TRUE THEN 
		WMArrayPanel.AddWindow(raster,"raster");
	END;
	WMArrayPanel.AddWindow(fovea, "fovea");
	WMArrayPanel.AddWindow(recon, "recon");
END TestA2;

PROCEDURE Test*(context:Commands.Context);
VAR 
	data,labels, data1,labels1:MLData.Dataset;
	source:Source;
	m,i,j, n:SIZE;
	fn:Files.FileName;
	f:Files.File; fr:Files.Reader; fw:Files.Writer;
	s:ARRAY 256 OF CHAR;
BEGIN
	IF ~context.arg.GetString(fn) THEN (*if no parameters, write test file first*)
		COPY("Test.MlA", fn); 
		f:=Files.New(fn); Files.Register(f);
		Files.OpenWriter(fw,f,0);
		context.out.String("writing"); context.out.String(fn); context.out.Ln; context.out.Update;
		NEW(source); source.log:=context.out;
		source.SetSize([32, 128,128],[32,1,20]);
		source.InitWrite(fw, MatrixUtilities.DatatypeInt);
		NEW(data,32, 128,128); NEW(labels, 32,1,20);
		FOR i:=0 TO 10 DO
			data:=0;
			FOR j:=0 TO LEN(data,0)-1 DO
				data[j,*,*]:=j;
			END;
			data[*,i*4..i*4+2,3*i..5*i]:=1.0;
			labels:=0; 
			FOR j:=0 TO LEN(labels,0)-1 DO
				labels[*,0,5..]:=1.0;
			END;
			labels[i, 0,i DIV 2]:=1.0;
			Strings.IntToStr(i,s);
			IF source.AddMinibatch(32,data,labels,s) THEN END;
			INC(n,32);
		END;
		
	context.out.String("written"); context.out.String(fn); context.out.Int(n,7); context.out.Ln; context.out.Update;
	END;	
	
	f:=Files.Old(fn);
	i:=0;
	IF f#NIL THEN
		Files.OpenReader(fr,f,0);
		NEW(source); source.maxResets:=3; source.log:=context.out;
		source.InitRead(fr);
		NEW(data1,source.batchSize); 
		NEW(labels1,source.labelSize);
		context.out.String("opened reader"); context.out.Ln; context.out.Update;
		WHILE (source.HasMoreData()) OR (source.Reset()) DO
			context.out.String("load data "); context.out.Update;
			m:=32;
			s:="";
			source.GetMiniBatch(m, data1,labels1, s);
			INC(i, m);
			IF TRUE THEN context.out.Int(i,8); context.out.Int(m,8); context.out.Ln; context.out.Update END;
		END;
		context.out.String("samples loaded="); context.out.Int(i,0); context.out.Ln;
	ELSE context.out.String("no file");
	END;
	context.out.Ln;
	context.out.Update;
END Test;


VAR rand:Random.Generator;
BEGIN
	NEW(rand);
END TensorFoveaOpticalFlow.

TensorFoveaOpticalFlow.TestA2~

TensorFovea.TestA2 "HIGHDIM:/Code/EyeTracker/EyeDB_Internet/8476656067_ee498cc265_b.jpg" 2 7 ~

