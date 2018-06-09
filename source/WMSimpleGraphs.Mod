MODULE WMSimpleGraphs;	(** AUTHOR "Patrick Hunziker"; PURPOSE "Minimum-overhead graph drawing and storing"; *)

(** right-click on navigator thumbnail allows window storage as image file *)

(*ToDo: ticks for Graph. labels on axes *)
(*ToDo: catch NaN and Inf in data and other strategies to avoid erratic window sizes*)

IMPORT Strings, WMGraphics, WMRectangles, WMMessages, Modules, Reals, Files, Streams, WM:=WMWindowManager, MathL, Raster, Commands;

CONST Colors=[WMGraphics.Red,WMGraphics.Blue,WMGraphics.Green,WMGraphics.Yellow, WMGraphics.Magenta, WMGraphics.Cyan, WMGraphics.Gray];
		MinSize=30;
		MaxSize=2048;
	
TYPE 
	Regressor=PROCEDURE{DELEGATE}(CONST data: ARRAY [*,*] OF LONGREAL; VAR slope,intercept: LONGREAL);

TYPE
	Window=OBJECT(WM.BufferWindow);
	VAR width,height:LONGINT;
		data:ARRAY [?] OF LONGREAL;
	
		PROCEDURE Update(w,h: LONGINT);
		BEGIN
			(* overwrite me *)
		END Update;

		PROCEDURE & Init(w,h: LONGINT; alpha: BOOLEAN);
		BEGIN
			Init^(w,h, alpha); 
			Update(w,h);
			INCL(flags, WM.FlagStorable);
		END Init;

		PROCEDURE Resized( width, height: LONGINT);
		VAR rect: WMRectangles.Rectangle;
		BEGIN
			Resized^(width, height);
			IF useAlpha THEN Raster.Create(img, width, height, Raster.BGRA8888) 
			ELSE Raster.Create(img, width, height, WM.format) 
			END;
			canvas:=canvasGen(img);
			Update(width, height);
			rect := WMGraphics.MakeRectangle(0,0,GetWidth(), GetHeight());
			Invalidate(rect);
		END Resized;
		
		PROCEDURE Handle*(VAR x : WMMessages.Message);
		VAR filename: Files.FileName; f:Files.File; w:Files.Writer;
		BEGIN
			IF (x.msgType = WMMessages.MsgSerialize) THEN
				IF x.msgSubType= WMMessages.MsgSubSerializeData THEN
					GenerateName(GetTitle(),filename);
					Strings.Append(filename, ".MtA"); (* file type "MathArray" *)
					f:=Files.New(filename);
					Files.OpenWriter(w,f,0);
					StoreLR(w, data);
					w.Update;
					Files.Register(f);	
				ELSIF x.msgSubType=WMMessages.MsgSubSerializeComponent THEN
					(*TBD*)
				END;
			ELSE Handle^(x)
			END
		END Handle;

		
	END Window;
	
	Histogram* = OBJECT (Window);
	

		PROCEDURE &New*(CONST data: ARRAY [*] OF LONGREAL; CONST title: ARRAY OF CHAR);
		VAR max:LONGREAL; w0,h0:LONGINT;
		BEGIN
			SELF.data:=data;
			max:=MAX(data);
			width:=LEN(data,0); height:=ENTIER(max)+1;
			IF (width<MinSize) THEN w0:=10*width ELSE w0:=MIN(width,MaxSize) END;
			IF height<MinSize THEN h0:=10*height ELSE h0:=height END;
			Init(w0,h0,FALSE);
			WM.GetDefaultManager().Add(PosX, PosY, SELF, {WM.FlagFrame,WM.FlagClose});
			NewWindowPos(GetWidth());
			SetTitle(Strings.NewString(title));
			SetPointerInfo(manager.pointerCrosshair);
		END New;
		

		
		PROCEDURE NewData*(CONST data: ARRAY [*] OF LONGREAL);
		BEGIN
			SELF.data:=data;
			Update(GetWidth(), GetHeight());
			Invalidate(WMGraphics.MakeRectangle(0,0,GetWidth(), GetHeight()));
		END NewData;
		
		PROCEDURE Update(w,h: LONGINT);
		VAR i:LONGINT;
		BEGIN
			IF Reals.IsNaNL(data[i]) THEN RETURN END;
			canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), WMGraphics.White, WMGraphics.ModeCopy);
			FOR i:=0 TO LEN(data,0)-1 DO
				canvas.Fill(WMRectangles.MakeRect(      i*w DIV width , h-ENTIER(data[i]*h / height), 
														(i+1)*w DIV width , h), WMGraphics.Black, WMGraphics.ModeCopy);
			END;
			INC(timestamp);
		END Update;

		
	END Histogram;
	
	(** display matrix values in checkerboard like fashion. positive values are in black/grey/white, negative values in red*)
	Matrix* = OBJECT (Window);
	VAR 
		(*data:ARRAY [*,*] OF LONGREAL;*)
		max,min, offset, gain:LONGREAL;

		PROCEDURE &New*(CONST data: ARRAY [*,*] OF LONGREAL; CONST title: ARRAY OF CHAR);
		BEGIN
			SELF.data:=data;
			min:=MIN(data); max:=MAX(data);
			max:=MAX(ABS(min), ABS(max));
			min:=MIN(0, min); 
			IF max=0 THEN max:=1 END;
			width:=MIN(MaxSize, MAX(1,LEN(data,0))); 
			height:=MIN(MaxSize, MAX(1,LEN(data,1)));
			Init(width, height, TRUE );
			offset:=0; gain:=255/max;
			IF( width<10) OR (height<10) THEN 
				bounds := WMGraphics.MakeRectangle(0, 0, 10*width, 10*height);(* grow small images *)
				Resized(GetWidth(), GetHeight());
			END;
			WM.GetDefaultManager().Add(PosX, PosY, SELF, {WM.FlagFrame,WM.FlagClose});
			NewWindowPos(GetWidth());
			SetTitle(Strings.NewString(title));
			SetPointerInfo(manager.pointerCrosshair);
		END New;
		
		PROCEDURE NewData*(CONST data: ARRAY [*,*] OF LONGREAL);
		BEGIN
			SELF.data:=data;
			min:=MIN(data); max:=MAX(data);
			max:=MAX(ABS(min), ABS(max));
			min:=MIN(0, min); 
			IF max=0 THEN max:=1 END;
			offset:=0; gain:=255/max;
			Update(GetWidth(), GetHeight());
			Invalidate(WMGraphics.MakeRectangle(0,0,GetWidth(), GetHeight()));
		END NewData;

		PROCEDURE Update(w,h: LONGINT);
		VAR col: WMGraphics.Color; x,y:LONGINT; val:LONGREAL; valI:LONGINT;
		BEGIN
			FOR y:=0 TO LEN(data,0)-1 DO
				FOR x:=0 TO LEN(data,1)-1 DO
					val:=data[y,x]; IF Reals.IsNaNL(val) THEN val:=0 END;
					valI:=ENTIER(offset+gain*val);
					valI:=MAX(-255, MIN( 255, valI));
					IF valI>=0 THEN	col:=WMGraphics.RGBAToColor(valI,valI,valI,255);
					ELSE				col:=WMGraphics.RGBAToColor(-valI,0,0,255);
					END;
					canvas.Fill(WMRectangles.MakeRect(x*w DIV width, h-ENTIER(0.5+(y+1)*h/height),  
														(x+1)*w DIV width, h-ENTIER(0.5+y*h/height)), 
														col, WMGraphics.ModeCopy);
				END;
			END;
			INC(timestamp);
		END Update;

	END Matrix;

	Graph* = OBJECT (Window);
	CONST border=5;
	VAR 
		(*data:ARRAY [*] OF LONGREAL;*)
		max,min:LONGREAL;

		PROCEDURE &New*(CONST data: ARRAY [*] OF LONGREAL; CONST title: ARRAY OF CHAR);
		VAR w0,h0:LONGINT;
		BEGIN
			SELF.data:=data;
			max:=MAX(1, MAX(data));
			min:=MIN(0, MIN(data)); 
			width:=LEN(data,0); height:=ENTIER(max-min)+1;
			IF Reals.IsNaNL(width) THEN width:=100 END;
			IF Reals.IsNaNL(height) THEN height:=100 END;
			IF (width<MinSize) THEN w0:=10*width ELSE w0:=MIN(MaxSize, width) END;
			IF height<MinSize THEN h0:=10*height ELSE h0:=MIN(MaxSize, height) END;
			Init(w0,h0,FALSE);
			WM.GetDefaultManager().Add(PosX, PosY, SELF, {WM.FlagFrame,WM.FlagClose});
			NewWindowPos(GetWidth());
			SetTitle(Strings.NewString(title));
			SetPointerInfo(manager.pointerCrosshair);
		END New;
		
		PROCEDURE NewData*(CONST data: ARRAY [*] OF LONGREAL);
		BEGIN
			SELF.data:=data;
			max:=MAX(1, MAX(data));
			min:=MIN(0, MIN(data)); 
			Update(GetWidth(), GetHeight());
			Invalidate(WMGraphics.MakeRectangle(0,0,GetWidth(), GetHeight()));
		END NewData;

		PROCEDURE Update(w,h: LONGINT);
		VAR i:LONGINT; mn,mx,x0,y0,x1,y1:LONGINT;
		BEGIN
			canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), WMGraphics.White, WMGraphics.ModeCopy);
			mn:=-border+ENTIER(0.5+min*h / height);
			mx:=ENTIER(0.5+max*h / height);
			FOR i:=0 TO LEN(data,0)-2 DO
				IF ~Reals.IsNaNL(data[i]) &~Reals.IsNaNL(data[i+1]) THEN
					x0:=border+i*w DIV width;
					y0:=h+mn-ENTIER(0.5+data[i]*h / height);
					x1:=border+(i+1)*w DIV width;
					y1:=h+mn-ENTIER(0.5+data[i+1]*h / height); 
					canvas.Line(x0,y0,x1,y1, WMGraphics.Black, WMGraphics.ModeCopy);
				END;
			END;
			IF mn#0 THEN canvas.Line(0, h+mn, w, h+mn, WMGraphics.Black, WMGraphics.ModeCopy);	END;
			INC(timestamp);
		END Update;
END Graph;

Graphs* = OBJECT (Window);
	CONST border=5;
	VAR 
		(*data:ARRAY [*,*] OF LONGREAL;*)
		max,min:LONGREAL;

		PROCEDURE &New*(CONST data: ARRAY [*,*] OF LONGREAL; CONST title: ARRAY OF CHAR);
		VAR w0,h0:LONGINT;
		BEGIN
			SELF.data:=data;
			max:=MAX(1, MAX(data));
			min:=MIN(0, MIN(data)); 
			width:=MAX(2,LEN(data,1)); height:=MAX(2, ENTIER(max-min)+1);
			IF Reals.IsNaNL(width) THEN width:=100 END;
			IF Reals.IsNaNL(height) THEN height:=100 END;
			IF width<MinSize THEN w0:=10*width ELSE w0:=MIN(width,MaxSize) END;
			IF height<MinSize THEN h0:=10*height ELSE h0:=MIN(height,MaxSize) END;
			Init(w0,h0,FALSE);
			WM.GetDefaultManager().Add(PosX, PosY, SELF, {WM.FlagFrame,WM.FlagClose});
			NewWindowPos(GetWidth());
			SetTitle(Strings.NewString(title));
			SetPointerInfo(manager.pointerCrosshair);
		END New;

		PROCEDURE NewData*(CONST data: ARRAY [*,*] OF LONGREAL);
		BEGIN
			SELF.data:=data;
			max:=MAX(1, MAX(data));
			min:=MIN(0, MIN(data)); 
			Update(GetWidth(), GetHeight());
			Invalidate(WMGraphics.MakeRectangle(0,0,GetWidth(), GetHeight()));
		END NewData;

		PROCEDURE Update(w,h: LONGINT);		
		VAR i,j:LONGINT; mn,mx, x0,x1,y0,y1:LONGINT;
		BEGIN
			canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), WMGraphics.White, WMGraphics.ModeCopy);
			mn:=-border+ENTIER(0.5+min*h / height);
			mx:=ENTIER(0.5+max*h / height);
			FOR j:=0 TO LEN(data,0)-1 DO
				FOR i:=0 TO LEN(data,1)-2 DO
					IF ~Reals.IsNaNL(data[j,i]) &~Reals.IsNaNL(data[j,i+1]) THEN
						x0:=border+i*w DIV width;
						y0:=h+mn-ENTIER(0.5+data[j,i]*h / height);
						x1:=border+(i+1)*w DIV width;
						y1:=h+mn-ENTIER(0.5+data[j,i+1]*h / height);
						canvas.Line(x0, y0,	x1, y1, Colors[j MOD LEN(Colors,0)], WMGraphics.ModeCopy);
					END;
				END;
			END;
			IF mn#0 THEN canvas.Line(0, h+mn, w, h+mn, WMGraphics.Black, WMGraphics.ModeCopy); END;
			INC(timestamp);
		END Update;
END Graphs;

GraphXY* = OBJECT (Window);
	CONST border=5; scaleRatio=0.95;
	VAR 
		(*data:ARRAY [*,*] OF LONGREAL;*)
		minx,miny,maxx,maxy:LONGREAL;
		ticks: ARRAY [*,*] OF LONGREAL;

		PROCEDURE &New*(CONST data: ARRAY [*,*] OF LONGREAL; CONST title: ARRAY OF CHAR);
		VAR w0,h0:LONGINT;
		BEGIN
			SELF.data:=data;
			maxx:=MAX(0,MAX(data[0]));maxy:=MAX(0,MAX(data[1]));
			minx:=MIN(0, MIN(data[0])); miny:=MIN(0, MIN(data[1])); 
			width:=ENTIER(maxx-minx)+1; height:=ENTIER(maxy-miny)+1;
			IF Reals.IsNaNL(width) THEN width:=100 END;
			IF Reals.IsNaNL(height) THEN height:=100 END;
			IF (width<MinSize) THEN w0:=10*width ELSE w0:=MIN(MaxSize,width) END;
			IF height<MinSize THEN h0:=10*height ELSE h0:=MIN(MaxSize, height) END;
			Init(w0,h0,FALSE);
			WM.GetDefaultManager().Add(PosX, PosY, SELF, {WM.FlagFrame,WM.FlagClose});
			NewWindowPos(GetWidth());
			SetTitle(Strings.NewString(title));
			SetPointerInfo(manager.pointerCrosshair);
			GetTicks;
		END New;
		
		PROCEDURE NewData*(CONST data: ARRAY [*,*] OF LONGREAL);
		BEGIN
			SELF.data:=data;
			maxx:=MAX(0,MAX(data[0]));maxy:=MAX(0,MAX(data[1]));
			minx:=MIN(0, MIN(data[0])); miny:=MIN(0, MIN(data[1])); 
			Update(GetWidth(), GetHeight());
			Invalidate(WMGraphics.MakeRectangle(0,0,GetWidth(), GetHeight()));
		END NewData;

		
		PROCEDURE GetTicks ; (*ticks along X, along Y, at decimal units*)
		VAR maxx,maxy,stepx,stepy: LONGREAL; log:LONGREAL; steps,i:LONGINT;
		BEGIN
			maxx:=MAX(ABS(data[0,*]));
			log:=Log10(maxx);
			stepx:=Exp10(log);
			
			maxy:=MAX(ABS(data[1,*]));
			log:=Log10(maxy);
			stepy := Exp10(log);
			
			steps:=MAX(ENTIER(maxx/stepx), ENTIER(maxy/stepy));
			NEW(ticks,2,steps);
			FOR i:=0 TO steps-1 DO
				ticks[0,i]:=(i+1)*stepx;
				ticks[1,i]:=(i+1)*stepy;
			END;
		END GetTicks;
		
		PROCEDURE Axes(canvas: WMGraphics.Canvas; w,h,mnw,mnh:LONGINT; scalex,scaley:REAL);
		VAR i:LONGINT;
		BEGIN
			IF mnh#0 THEN canvas.Line(0, h+mnh, w, h+mnh, WMGraphics.Black, WMGraphics.ModeCopy)	END;
			IF mnw#0 THEN canvas.Line(-mnw, 0, -mnw, h, WMGraphics.Black, WMGraphics.ModeCopy)	END;
			FOR i:=0 TO LEN(ticks,1)-1 DO 
				canvas.Line(-mnw+ENTIER(0.5+ticks[0,i]*scalex), h+mnh-1, -mnw+ENTIER(0.5+ticks[0,i]*scalex), h+mnh+1, WMGraphics.Black, WMGraphics.ModeCopy); (* ticks are at multiples of largest decimal unit *)
				canvas.Line(-mnw-1, h+mnh-ENTIER(0.5+ticks[1,i]*scaley), -mnw+1, h+mnh-ENTIER(0.5+ticks[1,i]*scaley), WMGraphics.Black, WMGraphics.ModeCopy)
			END;
		END Axes;
		
		PROCEDURE Update(w,h: LONGINT);
		VAR i:LONGINT; mnw,mnh,mxw,mxh,x0,x1,y0,y1:LONGINT; scalex,scaley:REAL;
		BEGIN
			canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), WMGraphics.White, WMGraphics.ModeCopy);
			scalex:=scaleRatio*w/width; scaley:=scaleRatio*h/height;
			mnw:=-border+ENTIER(0.5+minx* scalex);	mxw:=ENTIER(0.5+maxx* scalex);
			mnh:=-border+ENTIER(0.5+miny* scaley);	mxh:=ENTIER(0.5+maxy* scaley);
			FOR i:=0 TO LEN(data,1)-2 DO
				IF ~Reals.IsNaNL(data[0,i]) &~Reals.IsNaNL(data[1,i]) & ~Reals.IsNaNL(data[0,i+1]) &~Reals.IsNaNL(data[1,i+1])THEN
					x0:=-mnw+ENTIER(0.5+data[0,i]*scalex);
					y0:= h+mnh-ENTIER(0.5+data[1,i]*scaley);
					x1:= -mnw+ENTIER(0.5+data[0,i+1]*scalex);
					y1:= h+mnh-ENTIER(0.5+data[1,i+1]*scaley); 
					canvas.Line(x0,y0,x1,y1, WMGraphics.Blue, WMGraphics.ModeCopy);
				END;
			END;
			Axes(canvas, w,h,mnw,mnh,scalex,scaley);
			INC(timestamp);
		END Update;
END GraphXY;

	(** scatter plot with optional error bars. 
	data[0,..]: x coordinates
	data[1,..]: y coordinates
	optional data[2,..]: y error bars
	optional data[3,..]: x error bars *)
TYPE Scatter* = OBJECT (GraphXY);

		PROCEDURE Update(w,h: LONGINT);
		VAR i:LONGINT; mnw,mnh,mxw,mxh, x,y, ex,ey:LONGINT; scalex,scaley:REAL; rect:WMRectangles.Rectangle;
		BEGIN
			canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), WMGraphics.White, WMGraphics.ModeCopy);
			scalex:=scaleRatio*w/width; 
			scaley:=scaleRatio*h/height;
			mnw:=-border+ENTIER(0.5+minx* scalex);	mxw:=ENTIER(0.5+maxx* scalex);
			mnh:=-border+ENTIER(0.5+miny* scaley);	mxh:=ENTIER(0.5+maxy* scaley);
			FOR i:=0 TO LEN(data,1)-1 DO
				x:=-mnw+ENTIER(0.5+data[0,i]*scalex);
				y:=h+mnh-ENTIER(0.5+data[1,i]*scaley);
				WMRectangles.SetRect(rect, x-1,y-1,x+2,y+2 );
				canvas.Fill(rect, WMGraphics.Black, WMGraphics.ModeCopy);
				IF LEN(data,0)>2 THEN (* vertical error bars*)
					ey:=ENTIER(0.5+data[2,i]*scaley);
					canvas.Line(x, y-ey, x, y+ey,WMGraphics.Blue, WMGraphics.ModeCopy);  
					IF LEN(data,0)>3 THEN (*horizontal error bars*)
						ex:=ENTIER(0.5+data[3,i]*scalex);
						canvas.Line(x-ex, y, x+ex, y,WMGraphics.Red, WMGraphics.ModeCopy);  
					END;
				END;
			END;
			Axes(canvas,w,h,mnw,mnh,scalex,scaley); 
			INC(timestamp);
		END Update;
END Scatter;

(** Regression plot. requires computation of slope,intercept by suited procedure, e.g. derived from /Matrix/StatisticsLinearRegression.SimpleRegression()  *)
TYPE Regression*= OBJECT (Scatter)
	VAR slope,intercept: LONGREAL; regressor:Regressor;
	
	PROCEDURE &Initialize*(CONST data: ARRAY [*,*] OF LONGREAL; CONST title: ARRAY OF CHAR; regress:Regressor);
	BEGIN
		regressor:=regress;
		regressor(data,slope,intercept);
		New(data,title);
	END Initialize;
	
	PROCEDURE NewData*(CONST data: ARRAY [*,*] OF LONGREAL);
	BEGIN
		regressor(data,slope,intercept);
		NewData^(data);
	END NewData;
	
	PROCEDURE Update(w,h: LONGINT);
	VAR mnw,mnh,x,y,xx,yy:LONGINT; scalex,scaley, x0, y0, x1, y1:LONGREAL; 
	BEGIN
		Update^(w,h);
		x0:= minx; y0:= x0*slope+intercept;
		IF (y0<miny) THEN y0:=miny; x0:=(y0-intercept)/slope;
		ELSIF y1>maxy THEN y0:=maxy; x0:=(y0-intercept)/slope;
		END;
		x1:=maxx; y1:=x1*slope+intercept;
		IF (y1<miny) THEN y1:=miny; x1:=(y1-intercept)/slope;
		ELSIF y1>maxy THEN y1:=maxy; x1:=(y1-intercept)/slope;
		END;
		scalex:=scaleRatio*w/width; 
		scaley:=scaleRatio*h/height;
		mnw:=-border+ENTIER(0.5+minx* scalex); mnh:=-border+ENTIER(0.5+miny* scaley);	
		x:=-mnw+ENTIER(0.5+x0*scalex);  y:=h+mnh-ENTIER(0.5+y0*scaley);
		xx:=-mnw+ENTIER(0.5+x1*scalex); yy:=h+mnh-ENTIER(0.5+y1*scaley);
		canvas.Line(x,y,xx,yy,WMGraphics.Red, WMGraphics.ModeCopy);  
	END Update;	
END Regression;

PROCEDURE NewWindowPos(dx:LONGINT);
BEGIN
	INC(Pos,dx);
	PosX:=Pos MOD 700;
	PosY:=100+ (Pos DIV 700)*50 MOD 700;
END NewWindowPos;

PROCEDURE Log10(x:LONGREAL):LONGREAL;
BEGIN RETURN MathL.ln(x)/MathL.ln(10);
END Log10;

PROCEDURE Exp10(x:LONGREAL):LONGREAL;
BEGIN RETURN MathL.exp(ENTIER(x)*MathL.ln(10));
END Exp10;



PROCEDURE DummyRegressor(CONST data: ARRAY [*,*] OF LONGREAL; VAR slope,intercept:LONGREAL);
BEGIN
	slope:=1; intercept:=2;
END DummyRegressor;

PROCEDURE WriteLR(W:Streams.Writer; CONST t: ARRAY [?] OF LONGREAL);
VAR len: ARRAY [*] OF SIZE; i:LONGINT;
BEGIN
	ASSERT(DIM(t)>0);
	len:=LEN(t);
	IF  DIM(t)=1 THEN 
		FOR i:=0 TO LEN(t,0)-1 DO W.RawLReal(t[i]) END;
	ELSE
		FOR i:=0 TO LEN(t,0)-1 DO WriteLR(W, t[i,?]) END;
	END;
END WriteLR;

PROCEDURE StoreLR(W:Streams.Writer; CONST t: ARRAY [?] OF LONGREAL);
VAR i:LONGINT; len: ARRAY [*] OF SIZE;
BEGIN
	W.String("TENSOR 1.0 LR "); (* type, version *) W.Ln;
	W.Int(DIM(t),0);
	len:=LEN(t);
	FOR i:=0 TO LEN(len,0)-1 DO W.Char(" "); W.Int(len[i],0); END;
	W.Ln;
	WriteLR(W,t);
	W.Update;
END StoreLR;

PROCEDURE GenerateName(prefix: Strings.String; VAR str: ARRAY OF CHAR);
VAR  i,j:LONGINT; title: Files.FileName; c:CHAR;
BEGIN
	i:=0; j:=0;
	IF prefix#NIL THEN
		WHILE (i<LEN(prefix)) & (j<LEN(title)-1) DO
			c:=prefix[i];
			IF (c>="A")&(c<="Z") OR (c>="a")&(c<="z") OR(c>="0")&(c<="9") OR (c="_") OR (c=" ")THEN
				IF c=" " THEN c:="_" END;
				title[j]:=c; INC(i); INC(j);
			ELSE
				INC(i);
			END;
		END;
		title[j]:=0X;
		IF title="" THEN title:="GraphData" END;
	ELSE title:="GraphData"
	END;
	COPY(title, str);
END GenerateName;

VAR Pos, PosX,PosY: LONGINT;

PROCEDURE Demo*;
VAR h:Histogram; g:Graph; k: Graphs; gx:GraphXY; m:Matrix; s:Scatter; r:Regression;
BEGIN {EXCLUSIVE}
	NEW(h, [4,7,8,4,5,9,6,5,3,2,12,17,3,0,2], "Histogram"); 
	NEW(g, [4,7,8,4,5,9,6,5,3,2,12,17,3,-3,2], "Graph"); 
	NEW(k, [[-2,7,8,4,5,9,6,4,7,8,4,5,9,6],
			[5,3,2,12,21,3,0,5,3,-2,12,17,4,1]], "MultiGraph"); 
	NEW(gx, [[0.2,-1,0,1,5,9,6,4,7,3,4,5,9,6],
				[0.2,3,4,7,12,3,0,5,3,-2,12,17,4,1]], "GraphXY"); 
	NEW(s, [  [0.2,-1,0,1,5,9,6,4,7,3,4,5,9,6],
				[0.2,3,4,7,12,3,0,5,3,-2,12,17,4,1],
				[1,0.6,1.1,1,1.4,1,1,1,0.7,1,1,0.8,1,1],
				[0.5,0.3,0.6,0.4,0.5,0.3,0.6,0.5,0.5,0.4,0.7,0.5,0.5,0.5]], "Scatter with x and y error bars"); 
	NEW(r, [  [0.2,-1,0,1,5,9,6,4,7,3,4,5,9,6],
				[0.2,3,4,7,12,3,0,5,3,-2,12,17,4,1],
				[1,1,1,1,1,1,1,1,1,1,1,1,1,1]], "Regression with y error bars", DummyRegressor); 
	NEW(m, [[1,2,3,4],[4,3,2,4],[5,4,-2,-6],[3,1,0,-1]], "Matrix"); 
END Demo;

(*PROCEDURE Demo1*; (*associate new dataset with existing graph*)
VAR h:Histogram; g:Graph; k: Graphs; gx:GraphXY; m:Matrix; s:Scatter; r:Regression; i:LONGINT;
BEGIN {EXCLUSIVE}
	NEW(k, [[-2,7,8,4,5,9,6,4,7,8,4,5,9,6],
			[5,3,2,12,21,3,0,5,3,-2,12,17,4,1]], "MultiGraph"); 
	NEW(g, [4,7,8,4,5,9,6,5,3,2,12,17,3,-3,2], "Graph"); 
			FOR i:=0 TO 100000000 DO END;
	k.NewData(
			[[5,3,2,12,21,3,0,5,3,-2,12,17,4,1],
			[-2,7,8,4,5,9,6,4,7,8,4,5,9,6],
			[5-1,3,2-1,12,21-1,3,0,5-1,3,-2,12-1,17,4,1]]
			);
	g.NewData([-2,7,8,4,5,9,6,4,7,8,4,5,9,6]);
END Demo1;*)

(* from MatrixUtilities.Mod*)
PROCEDURE LoadData(R:Streams.Reader): ARRAY [?] OF LONGREAL;
VAR s: ARRAY 16 OF CHAR; i, k:LONGINT; len: ARRAY [*] OF SIZE; n: LONGINT;
BEGIN
	R.Ln(s);
	ASSERT(s="TENSOR 1.0 LR "); 
	IF R.GetInteger(k, FALSE) THEN NEW(len,k) ELSE HALT(200) END;
	FOR i:=0 TO k-1 DO 
		IF R.GetInteger(n,FALSE) THEN len[i] := n; END;
	END;
	R.SkipLn;
	IF (DIM(RESULT)#k) OR (LEN(RESULT)#len) THEN NEW(RESULT,len) END;
	ReadLR(R,RESULT);
	RETURN RESULT
END LoadData;

PROCEDURE ReadLR(R:Streams.Reader; VAR t: ARRAY [?] OF LONGREAL);
VAR i:LONGINT;
BEGIN
	ASSERT(DIM(t)>0);
	IF  DIM(t)=1 THEN 
		FOR i:=0 TO LEN(t,0)-1 DO R.RawLReal(t[i]) END;
	ELSE
		FOR i:=0 TO LEN(t,0)-1 DO ReadLR(R, t[i,?]) END;
	END;
END ReadLR;

(* Draw Graph from File, currently implemented for .MtA Files (see MatrixUtilities.Mod) *)
PROCEDURE Open*(context:Commands.Context);
VAR filename: Files.FileName; type: ARRAY 16 OF CHAR; 
	data: ARRAY [?] OF LONGREAL;
	f:Files.File; r:Files.Reader;
	h:Histogram; g:Graph; k: Graphs; gx:GraphXY; m:Matrix; s:Scatter; rg:Regression;
BEGIN
	IF context.arg.GetString(filename) THEN
		IF Strings.Pos(".MtA",filename)<0 THEN context.out.String("wrong file type of "); context.out.String(filename); context.out.Ln; context.out.Update;
		ELSE
			IF ~context.arg.GetString(type) THEN type:="" END;
			f:=Files.Old(filename);
			IF f#NIL THEN
				Files.OpenReader(r,f,0);
				data:=LoadData(r);
				IF type="Histogram" THEN NEW(h, data, filename); 
				ELSIF type="Matrix" THEN NEW(m, data, filename);
				ELSIF type="Graph" THEN NEW(g, data, filename);
				ELSIF type="Graphs" THEN NEW(k, data, filename);
				ELSIF type="GraphXY" THEN NEW(gx, data, filename);
				ELSIF type="Scatter" THEN NEW(s, data, filename);
				ELSIF type="Regression" THEN NEW(rg, data, filename,DummyRegressor);
				ELSE
				END;
			END;
		END
	END;
END Open;


PROCEDURE Cleanup;
VAR manager:WM.WindowManager; w,remove:WM.Window;
BEGIN {EXCLUSIVE}
	manager:=WM.GetDefaultManager();
	manager.lock.AcquireWrite;
	w:=manager.GetFirst();
	WHILE w#NIL DO
		remove:=w;
		w:=manager.GetNext(w);
		IF (remove#NIL) & (remove IS Window) THEN manager.Remove(remove) END;
	END;
	manager.lock.ReleaseWrite;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	Pos:=50; NewWindowPos(0);
END WMSimpleGraphs.

System.Free WMSimpleGraphs ~
System.FreeDownTo MatrixBase ~

Compiler.Compile -p=Win32 WMSimpleGraphs.Mod ~

WMSimpleGraphs.Demo 1 ~
WMSimpleGraphs.Open  MultiGraph.MtA Graphs~ 

