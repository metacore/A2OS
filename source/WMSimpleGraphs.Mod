MODULE WMSimpleGraphs;	(** AUTHOR "Patrick Hunziker"; PURPOSE "Minimum-overhead graph drawing and storing"; *)
(** right-click on navigator thumbnail allows window storage as image file *)

(*ToDo: catch NaN and Inf in data and other strategies to avoid erratic window sizes*)

IMPORT Strings, WMGraphics, WMRectangles, Modules, Reals, WM:=WMWindowManager;

CONST Colors=[WMGraphics.Red,WMGraphics.Blue,WMGraphics.Green,WMGraphics.Yellow, WMGraphics.Magenta, WMGraphics.Cyan, WMGraphics.Gray];

TYPE
	Histogram* = OBJECT (WM.Window);
	VAR 
		data:ARRAY [*] OF LONGREAL;
		width,height:LONGINT;

		PROCEDURE &New*(CONST data: ARRAY [*] OF LONGREAL; CONST title: ARRAY OF CHAR);
		VAR max:LONGREAL; 
		BEGIN
			SELF.data:=data;
			max:=MAX(data);
			width:=LEN(data,0); height:=ENTIER(max)+1;
			Init(10*width, 10*height, FALSE);
			WM.GetDefaultManager().Add(PosX, PosY, SELF, {WM.FlagFrame,WM.FlagClose});
			NewWindowPos(GetWidth());
			SetTitle(Strings.NewString(title));
			SetPointerInfo(manager.pointerCrosshair);
		END New;
		
		PROCEDURE Draw*(canvas : WMGraphics.Canvas; w, h, q : LONGINT);
		VAR i:LONGINT;
		BEGIN
			canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), WMGraphics.White, WMGraphics.ModeCopy);
			FOR i:=0 TO LEN(data,0)-1 DO
				canvas.Fill(WMRectangles.MakeRect(      i*w DIV width , h-ENTIER(data[i]*h / height), 
														(i+1)*w DIV width , h), WMGraphics.Black, WMGraphics.ModeCopy);
			END;
			INC(timestamp);
		END Draw;
	END Histogram;

	Graph* = OBJECT (WM.Window);
	VAR 
		data:ARRAY [*] OF LONGREAL;
		width,height:LONGINT;
		max,min:LONGREAL;

		PROCEDURE &New*(CONST data: ARRAY [*] OF LONGREAL; CONST title: ARRAY OF CHAR);
		BEGIN
			SELF.data:=data;
			max:=MAX(data);
			min:=MIN(0, MIN(data)); 
			width:=LEN(data,0); height:=ENTIER(max-min)+1;
			Init(10*width, 10*height, FALSE);
			WM.GetDefaultManager().Add(PosX, PosY, SELF, {WM.FlagFrame,WM.FlagClose});
			NewWindowPos(GetWidth());
			SetTitle(Strings.NewString(title));
			SetPointerInfo(manager.pointerCrosshair);
		END New;
		
		PROCEDURE Draw*(canvas : WMGraphics.Canvas; w, h, q : LONGINT);
		VAR i:LONGINT; mn,mx:LONGINT;
		BEGIN
			canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), WMGraphics.White, WMGraphics.ModeCopy);
			mn:=ENTIER(0.5+min*h / height);
			mx:=ENTIER(0.5+max*h / height);
			FOR i:=0 TO LEN(data,0)-2 DO
				canvas.Line(i*w DIV width, 	h+mn-ENTIER(0.5+data[i]*h / height),  
							(i+1)*w DIV width, h+mn-ENTIER(0.5+data[i+1]*h / height), 
							WMGraphics.Black, WMGraphics.ModeCopy);
			END;
			IF mn#0 THEN canvas.Line(0, h+mn, w, h+mn, WMGraphics.Black, WMGraphics.ModeCopy);	END;
			INC(timestamp);
		END Draw;
END Graph;

GraphXY* = OBJECT (WM.Window);
	VAR 
		data:ARRAY [*,*] OF LONGREAL;
		width,height:LONGINT;
		max,min:LONGREAL;

		PROCEDURE &New*(CONST data: ARRAY [*,*] OF LONGREAL; CONST title: ARRAY OF CHAR);
		BEGIN
			SELF.data:=data;
			max:=MAX(0,MAX(data));
			min:=MIN(0, MIN(data)); 
			width:=ENTIER(max-min)+1; height:=ENTIER(max-min)+1;
			Init(10*width, 10*height, FALSE);
			WM.GetDefaultManager().Add(PosX, PosY, SELF, {WM.FlagFrame,WM.FlagClose});
			NewWindowPos(GetWidth());
			SetTitle(Strings.NewString(title));
			SetPointerInfo(manager.pointerCrosshair);
		END New;
		
		PROCEDURE Draw*(canvas : WMGraphics.Canvas; w, h, q : LONGINT);
		VAR i:LONGINT; mnw,mnh,mxw,mxh:LONGINT; scalex,scaley:REAL;
		BEGIN
			canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), WMGraphics.White, WMGraphics.ModeCopy);
			scalex:=w/width; scaley:=h/height;
			mnw:=ENTIER(0.5+min* scalex);	mxw:=ENTIER(0.5+max* scalex);
			mnh:=ENTIER(0.5+min* scaley);	mxh:=ENTIER(0.5+max* scaley);
			FOR i:=0 TO LEN(data,1)-2 DO
				canvas.Line(-mnw+ENTIER(0.5+data[0,i]*scalex), 	h+mnh-ENTIER(0.5+data[1,i]*scaley),  
							-mnw+ENTIER(0.5+data[0,i+1]*scalex), h+mnh-ENTIER(0.5+data[1,i+1]*scaley), 
							WMGraphics.Blue, WMGraphics.ModeCopy);
			END;
			IF mnh#0 THEN canvas.Line(0, h+mnh, w, h+mnh, WMGraphics.Black, WMGraphics.ModeCopy)	END;
			IF mnw#0 THEN canvas.Line(-mnw, 0, -mnw, h, WMGraphics.Black, WMGraphics.ModeCopy)	END;
			INC(timestamp);
		END Draw;
END GraphXY;

Graphs* = OBJECT (WM.Window);
	VAR 
		data:ARRAY [*,*] OF LONGREAL;
		width,height:LONGINT;
		max,min:LONGREAL;

		PROCEDURE &New*(CONST data: ARRAY [*,*] OF LONGREAL; CONST title: ARRAY OF CHAR);
		BEGIN
			SELF.data:=data;
			max:=MAX(data);
			min:=MIN(0, MIN(data)); 
			width:=LEN(data,1); height:=ENTIER(max-min)+1;
			Init(10*width, 10*height, FALSE);
			WM.GetDefaultManager().Add(PosX, PosY, SELF, {WM.FlagFrame,WM.FlagClose});
			NewWindowPos(GetWidth());
			SetTitle(Strings.NewString(title));
			SetPointerInfo(manager.pointerCrosshair);
		END New;
		
		PROCEDURE Draw*(canvas : WMGraphics.Canvas; w, h, q : LONGINT);
		VAR i,j:LONGINT; mn,mx:LONGINT;
		BEGIN
			canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), WMGraphics.White, WMGraphics.ModeCopy);
			mn:=ENTIER(0.5+min*h / height);
			mx:=ENTIER(0.5+max*h / height);
			FOR j:=0 TO LEN(data,0)-1 DO
				FOR i:=0 TO LEN(data,1)-2 DO
					canvas.Line(i*w DIV width, 	h+mn-ENTIER(0.5+data[j,i]*h / height),  
								(i+1)*w DIV width, h+mn-ENTIER(0.5+data[j,i+1]*h / height), 
								Colors[j MOD LEN(Colors,0)], WMGraphics.ModeCopy);
				END;
			END;
			IF mn#0 THEN canvas.Line(0, h+mn, w, h+mn, WMGraphics.Black, WMGraphics.ModeCopy); END;
			INC(timestamp);
		END Draw;
END Graphs;

(** display matrix values in checkerboard like fashion. positive values are in black/grey/white, negative values in red*)
Matrix* = OBJECT (WM.Window);
	VAR 
		data:ARRAY [*,*] OF LONGREAL;
		width,height:LONGINT;
		max,min, offset, gain:LONGREAL;

		PROCEDURE &New*(CONST data: ARRAY [*,*] OF LONGREAL; CONST title: ARRAY OF CHAR);
		BEGIN
			SELF.data:=data;
			min:=MIN(data); max:=MAX(data);
			max:=MAX(ABS(min), ABS(max));
			min:=MIN(0, min); 
			IF max=0 THEN max:=1 END;
			width:=MAX(1,LEN(data,0)); 
			height:=MAX(1,LEN(data,1));
			Init(width, height, TRUE);
			offset:=0; gain:=255/max;
			IF( width<10) OR (height<10) THEN 
				bounds := WMGraphics.MakeRectangle(0, 0, 10*width, 10*height);(* grow small images *)
			END;
			WM.GetDefaultManager().Add(PosX, PosY, SELF, {WM.FlagFrame,WM.FlagClose});
			NewWindowPos(GetWidth());
			SetTitle(Strings.NewString(title));
			SetPointerInfo(manager.pointerCrosshair);
		END New;
		
		PROCEDURE Draw*(canvas : WMGraphics.Canvas; w, h, q : LONGINT);
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
		END Draw;
END Matrix;

PROCEDURE NewWindowPos(dx:LONGINT);
BEGIN
	INC(Pos,dx);
	PosX:=Pos MOD 900;
	PosY:=100+ (Pos DIV 900)*100 MOD 700;
END NewWindowPos;

VAR Pos, PosX,PosY: LONGINT;

PROCEDURE Demo*;
VAR h:Histogram; g:Graph; k: Graphs; gx:GraphXY; m:Matrix;
BEGIN {EXCLUSIVE}
	NEW(h, [4,7,8,4,5,9,6,5,3,2,12,17,3,0,2], "Histogram"); 
	NEW(g, [4,7,8,4,5,9,6,5,3,2,12,17,3,-3,2], "Graph"); 
	NEW(k, [[-2,7,8,4,5,9,6,4,7,8,4,5,9,6],
			[5,3,2,12,21,3,0,5,3,-2,12,17,3,1]], "MultiGraph"); 
	NEW(gx, [[-2,-1,0,1,5,9,6,4,7,3,4,5,9,6],
				[1,3,4,7,12,3,0,5,3,-2,12,17,3,1]], "GraphXY"); 
	NEW(m, [[1,2,3,4],[4,3,2,4],[5,4,-2,-6],[3,1,0,-1]], "Matrix"); 
END Demo;

PROCEDURE Cleanup;
VAR manager:WM.WindowManager; w,remove:WM.Window;
BEGIN {EXCLUSIVE}
	manager:=WM.GetDefaultManager();
	manager.lock.AcquireWrite;
	w:=manager.GetFirst();
	WHILE w#NIL DO
		remove:=w;
		w:=manager.GetNext(w);
		IF (remove#NIL)&
			((remove IS Histogram) OR  (remove IS Graph)  OR  (remove IS GraphXY) OR  (remove IS Graphs) OR (remove IS Matrix))
		THEN manager.Remove(remove);
		END;
	END;
	manager.lock.ReleaseWrite;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	Pos:=0; NewWindowPos(0);
END WMSimpleGraphs.

SystemTools.Free WMSimpleGraphs ~

WMSimpleGraphs.Demo ~

