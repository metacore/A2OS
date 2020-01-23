MODULE WMTensor; (** AUTHOR ""; PURPOSE "Display of 3D and 4D tensors as image"; *)
(*! THIS MODULE IS TO BE REPLACED BY A COMPONENT-BASED VERSION - use with caution. only partly tested, in 4D case only*)
IMPORT Modules, Inputs, Raster, MatrixRaster, MatrixUtilities, Files, WMMessages, WM:=WMWindowManager, Strings, Models, WMRectangles, WMGraphics, Commands;
CONST 	signed=1;
		lut=2;
		rgb=3;
		heat=4;

		Frontal*=0;
		Sagittal*=1;
		Horizontal*=2;

(*! to do: improve current limitation to subtensor[0,?] display. Generalize to 1D, 2D and 5D+ data*)

TYPE
	Tensor= ARRAY [?] OF FLOAT64;

TYPE Model*= OBJECT (Models.Model)
		VAR m*, r*,g*,b*: Tensor;
	END Model;

TYPE Window*= OBJECT (WM.BufferWindow) (* or could use WM.DoubleBufferWindow or WMComponents.FormWindow) *)
	VAR model*:Model;
		max,min, gain*:FLOAT64;
		exists:BOOLEAN;
		type, orientation,cur3:SIGNED32;
		offset*,current*:SIZE;
		mx0,my0,mx1,my1:SIZE;
		baseTitle, title: ARRAY 256 OF CHAR;
		source*:ANY;

	PROCEDURE &Initialize*(CONST m: Tensor; CONST title: ARRAY OF CHAR; orientation:SIGNED32);
	BEGIN
		ASSERT(DIM(m) IN {2, 3,4}, 200);
		(*ASSERT(LEN(m)>0, 201);*)
		SELF.orientation:=orientation;
		IF LEN(m)>0 THEN
			IF ~exists THEN
				IF DIM(m)=2 THEN
					Init(LEN(m,1),LEN(m,0),TRUE);
				ELSIF DIM(m)=3 THEN
					IF orientation=0 THEN Init(LEN(m,2), LEN(m,1), TRUE);
					ELSIF orientation=1 THEN Init(LEN(m,2), LEN(m,0), TRUE);
					ELSE Init(LEN(m,1), LEN(m,0), TRUE);
					END;
				ELSIF DIM(m)=4 THEN
					IF orientation=0 THEN Init(LEN(m,3), LEN(m,2), TRUE);
					ELSIF orientation=1 THEN Init(LEN(m,3), LEN(m,1), TRUE);
					ELSE Init(LEN(m,2), LEN(m,1), TRUE);
					END;
				END;
				exists:=TRUE;
				bounds := WMGraphics.MakeRectangle(0, 0, GetWidth(), GetHeight());
			END;
			NEW(model);
			SetImage(m);
		END;
		COPY(title,baseTitle);
		SetTitle(Strings.NewString(title));
		INCL(flags, WM.FlagStorable);
		current:=0;
		(*maxInterpolation:=1; => default bilinear interpolation;  maxInterpolation:=0; => nearest neighbour interpolation*)
	END Initialize;

	PROCEDURE SetOrientation*(orientation:SIGNED32);
	VAR w,h: SIZE; m: WM.WindowManager;
	BEGIN
		IF (orientation#SELF.orientation) & (LEN(model.m)>0) THEN
			IF DIM(model.m)=2 THEN
				w:=LEN(model.m,1); h:=LEN(model.m,0);
			ELSIF DIM(model.m)=3 THEN
				IF orientation=0 THEN w:=LEN(model.m,2); h:= LEN(model.m,1);
				ELSIF orientation=1 THEN w:=LEN(model.m,2); h:= LEN(model.m,0);
				ELSE w:=LEN(model.m,1); h:= LEN(model.m,0);
				END;
			ELSIF DIM(model.m)=4 THEN
				IF orientation=0 THEN w:=LEN(model.m,3); h:= LEN(model.m,2);
				ELSIF orientation=1 THEN w:=LEN(model.m,3); h:= LEN(model.m,1);
				ELSE w:=LEN(model.m,2); h:= LEN(model.m,1);
				END;
			END;
			Raster.Create(img, w,h, img.fmt);
			m:=GetManager();
			IF m#NIL THEN m.SetWindowSize(SELF, w,h);
			ELSE bounds.r:=bounds.l+w; bounds.b:=bounds.t+h;
			END;
			SELF.orientation:=orientation
		END;
	END SetOrientation;

	PROCEDURE PostInvalidate;
	VAR m: WMMessages.Message;
	BEGIN
			m.sender:=SELF; m.msgType := WMMessages.MsgInvalidate; m.msgSubType := WMMessages.MsgSubAll;
			IF (sequencer#NIL) & sequencer.Add(m) THEN END; (* Invalidate window contents when first put on display. *)
	END PostInvalidate;

	PROCEDURE Handle*(VAR x : WMMessages.Message);
		VAR filename: Files.FileName; f:Files.File; w:Files.Writer;
		BEGIN
			IF (x.msgType = WMMessages.MsgSerialize) THEN
				GenerateName(GetTitle(),filename);
				Strings.Append(filename, ".MtA"); (* file type "MathArray" *)
				f:=Files.New(filename);
				Files.OpenWriter(w,f,0);
				MatrixUtilities.StoreLR(w, model.m);
				w.Update;
				Files.Register(f);
			ELSIF x.msgType = WMMessages.MsgInvalidate THEN
			IF x.msgSubType = WMMessages.MsgSubAll THEN
				Invalidate(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()));
			ELSE
				HALT(200)
			END;
		ELSE Handle^(x);
		END;
	END Handle;


	PROCEDURE PointerDown*(x, y : SIZE; keys : SET); (* does not work ... ?? *)
		BEGIN
			mx0:=x; my0:=y;
		END PointerDown;

	PROCEDURE PointerUp*(x, y : SIZE; keys : SET);
		BEGIN
			mx1:=x; my1:=y;
		END PointerUp;

	PROCEDURE PointerMove*(x, y : SIZE; keys : SET);
		BEGIN
			IF keys={2} THEN
				mx1:=x; my1:=y;
				gain:=gain*(1 + (mx1-mx0)/100);
				offset:=offset+(my0-my1);
				mx0:=mx1; my0:=my1;
				Render;
			ELSE
				PointerMove^(x,y,keys)
			END;
		END PointerMove;

	PROCEDURE WheelMove*(dz : SIZE);
	VAR s: ARRAY 16 OF CHAR;
		BEGIN
			IF DIM(model.m)=3 THEN current:=(current - dz) MOD LEN(model.m,orientation); (*! to do: fix for 3D, 2D, nD*)
			ELSIF DIM(model.m)=4 THEN current:=(current - dz) MOD LEN(model.m,orientation+1);
			END;
			Strings.IntToStr(current,s);
			COPY(baseTitle,title); Strings.Append(title,"-"); Strings.Append(title,s);
			SetTitle(Strings.NewString(title));
			Render
		END WheelMove;

	(*The window can determine wether the key was pressed or released by examining the
			Inputs.Release flag in flags. ucs contains the unicode equivalent of the key. Special input editors
			send the generated unicode characters via KeyEvent.  *)
	PROCEDURE KeyEvent(ucs : SIZE; flags : SET; keysym : SIZE);
		VAR dz: SIGNED32; s: ARRAY 16 OF CHAR; dim:SIZE;
		BEGIN
			IF ~(Inputs.Release IN flags )THEN
				dim:=MAX(DIM(model.m),DIM(model.r));
				IF keysym = Inputs.KsUp THEN
					IF MAX(DIM(model.m),DIM(model.r))=3 THEN dz:=1; current:=(current + dz) MOD LEN(model.m, orientation);
					ELSE INC(cur3)
					END;
				ELSIF keysym = Inputs.KsDown THEN
					IF MAX(DIM(model.m),DIM(model.r))=3 THEN dz:=-1; current:=(current + dz) MOD LEN(model.m, orientation);
					ELSE DEC(cur3);
					END;
				ELSIF keysym = Inputs.KsRight THEN
					SetOrientation( (orientation+1) MOD 3); current:=0;
				ELSIF keysym = Inputs.KsLeft THEN
					SetOrientation( (orientation-1) MOD 3); current:=0;
				ELSE
					KeyEvent^(ucs,flags,keysym); RETURN
				END;
				COPY(baseTitle,title); Strings.Append(title,"-");
				IF dim=4 THEN
					Strings.IntToStr(cur3 MOD LEN(model.m,0), s); Strings.Append(title, s); Strings.Append(title,"_");
				END;
				Strings.IntToStr(current,s);
				Strings.Append(title,s);
				SetTitle(Strings.NewString(title));
				Render
			ELSE
				KeyEvent^(ucs,flags,keysym);
			END;
		END KeyEvent;

	PROCEDURE SetImage*(CONST m: Tensor);
	BEGIN
		IF LEN(m)>0 THEN
			IF ~exists THEN
				IF DIM(m)=2 THEN
					Init(LEN(m,1), LEN(m,0), TRUE);
				ELSIF DIM(m)=3 THEN
					IF orientation=0 THEN Init(LEN(m,2), LEN(m,1), TRUE);
					ELSIF orientation=1 THEN Init(LEN(m,2), LEN(m,0), TRUE);
					ELSE Init(LEN(m,1), LEN(m,0), TRUE);
					END;
				ELSIF DIM(m)=4 THEN
					IF orientation=0 THEN Init(LEN(m,3), LEN(m,2), TRUE);
					ELSIF orientation=1 THEN Init(LEN(m,3), LEN(m,1), TRUE);
					ELSE Init(LEN(m,2), LEN(m,1), TRUE);
					END;
				END;
				exists:=TRUE;
				bounds := WMGraphics.MakeRectangle(0, 0, GetWidth(), GetHeight());
			END;
			model.m:=ALIAS OF m;
			max:=MAX(m); min:=MIN(m); IF min<0 THEN type:=signed ELSE type:=0 END;;
			offset:=0;
			IF max#min THEN gain:= 255/MAX( ABS(max),ABS(min));
			ELSE gain:=1;
			END;
			Render;
		ELSE type:=0;
		END;
	END SetImage;

	PROCEDURE SetImageB*(CONST m: Tensor; offset:SIGNED32;gain: FLOAT64);
	BEGIN
		IF ~exists  & (LEN(m)>0) THEN
			IF DIM(m)=2 THEN
					Init(LEN(m,1), LEN(m,0), TRUE);
			ELSIF DIM(m)=3 THEN
				IF orientation=0 THEN Init(LEN(m,2), LEN(m,1), TRUE);
				ELSIF orientation=1 THEN Init(LEN(m,2), LEN(m,0), TRUE);
				ELSE Init(LEN(m,1), LEN(m,0), TRUE);
				END;
			ELSIF DIM(m)=4 THEN
				IF orientation=0 THEN Init(LEN(m,3), LEN(m,2), TRUE);
				ELSIF orientation=1 THEN Init(LEN(m,3), LEN(m,1), TRUE);
				ELSE Init(LEN(m,2), LEN(m,1), TRUE);
				END;
			END;
			exists:=TRUE;
			bounds := WMGraphics.MakeRectangle(0, 0, GetWidth(), GetHeight());
		END;
		model.m:=ALIAS OF m; (*! ALIAS is not yet done in WMMatrix - maybe introduce it there *)
		max:=MAX(m); min:=MIN(m); IF min<0 THEN type:=signed ELSE type:=0 END;
		SELF.offset:=offset; SELF.gain:=gain;
		Render;
	END SetImageB;

	PROCEDURE SetImageHeat*(CONST m: Tensor);
	BEGIN
		IF ~exists  & (LEN(m)>0) THEN
			IF DIM(m)=2 THEN
				Init(LEN(m,1), LEN(m,0), TRUE);
			ELSIF DIM(m)=3 THEN
				IF orientation=0 THEN Init(LEN(m,2), LEN(m,1), TRUE);
				ELSIF orientation=1 THEN Init(LEN(m,2), LEN(m,0), TRUE);
				ELSE Init(LEN(m,1), LEN(m,0), TRUE);
				END;
			ELSIF DIM(m)=4 THEN
				IF orientation=0 THEN Init(LEN(m,3), LEN(m,2), TRUE);
				ELSIF orientation=1 THEN Init(LEN(m,3), LEN(m,1), TRUE);
				ELSE Init(LEN(m,2), LEN(m,1), TRUE);
				END;
			END;
			exists:=TRUE;
			bounds := WMGraphics.MakeRectangle(0, 0, GetWidth(), GetHeight());
		END;
		model.m:=ALIAS OF m;(* no-copy version *)
		max:=MAX(m); min:=MIN(m);
		type:=heat;
		IF max#min THEN gain:= 511/(max-min);
		ELSE gain:=1;
		END;
		offset:=ENTIER(-255-gain*min);
		Render;
	END SetImageHeat;

	PROCEDURE SetImageRGB*(CONST r,g,b: Tensor);
	BEGIN
		IF ~exists  & (LEN(r)>0) THEN
			IF DIM(r)=2 THEN
				Init(LEN(r,1), LEN(r,0), TRUE);
			ELSIF DIM(r)=3 THEN
				IF orientation=0 THEN Init(LEN(r,2), LEN(r,1), TRUE);
				ELSIF orientation=1 THEN Init(LEN(r,2), LEN(r,0), TRUE);
				ELSE Init(LEN(r,1), LEN(r,0), TRUE);
				END;
			ELSIF DIM(r)=4 THEN
				IF orientation=0 THEN Init(LEN(r,3), LEN(r,2), TRUE);
				ELSIF orientation=1 THEN Init(LEN(r,3), LEN(r,1), TRUE);
				ELSE Init(LEN(r,2), LEN(r,1), TRUE);
				END;
			END;
			exists:=TRUE;
			bounds := WMGraphics.MakeRectangle(0, 0, GetWidth(), GetHeight());
		END;
		offset:=0; gain:=255/MAX(MAX(ABS(r)), MAX(MAX(ABS(g)), MAX(ABS(b))));
		model.r:=ALIAS OF r; model.g:=ALIAS OF g; model.b:=ALIAS OF b; (*! ALIAS is not yet done in WMMatrix - maybe introduce it there *)
		type:=rgb;
		Render;
	END SetImageRGB;

	PROCEDURE Render*;
	VAR m,r,g,b: Tensor;
	BEGIN
		IF type=signed THEN
			IF DIM(model.m)=4 THEN m:=ALIAS OF model.m[cur3 MOD LEN(model.m,0),?]
			ELSE m:=ALIAS OF model.m (*only effective in DIM=3*)
			END;
			IF DIM(model.m)=2 THEN MatrixRaster.LRealToImageBR(model.m[*,*], offset, gain, img);
			ELSIF orientation=0 THEN MatrixRaster.LRealToImageBR(m[current,*,*], offset, gain, img);
			ELSIF orientation=1 THEN MatrixRaster.LRealToImageBR(m[.., current, ..], offset, gain, img);
			ELSE MatrixRaster.LRealToImageBR(m[..,..,current], offset, gain, img);
			END;
		ELSIF type=heat THEN
			IF DIM(model.m)=4 THEN m:=ALIAS OF model.m[cur3 MOD LEN(model.m,0),?] ELSE m:=ALIAS OF model.m END;
			IF DIM(model.m)=2 THEN MatrixRaster.LRealToImageHeat(model.m[*,*], offset, gain, img);
			ELSIF orientation=0 THEN MatrixRaster.LRealToImageHeat(m[current,*,*], offset, gain, img);
			ELSIF orientation=1 THEN MatrixRaster.LRealToImageHeat(m[.., current, ..], offset, gain, img);
			ELSE MatrixRaster.LRealToImageHeat(m[..,..,current], offset, gain, img);
			END;
		ELSIF type=rgb THEN
			IF DIM(model.r)=4 THEN
				r:=ALIAS OF model.r[cur3 MOD LEN(model.r,0),?];
				g:=ALIAS OF model.g[cur3 MOD LEN(model.g,0),?];
				b:=ALIAS OF model.b[cur3 MOD LEN(model.b,0),?]
			ELSE r:=ALIAS OF model.r; g:=ALIAS OF model.g; b:=ALIAS OF model.b; (*only effective in DIM=3*)
			END;
			IF DIM(model.r)=2 THEN MatrixRaster.LRealRGBToImageB( model.r[*,*], model.g[*,*], model.b[*,*], offset, gain, img);
			ELSIF orientation=0 THEN MatrixRaster.LRealRGBToImageB( r[current,*,*], g[current,*,*], b[current,*,*], offset, gain, img);
			ELSIF orientation=1 THEN MatrixRaster.LRealRGBToImageB( r[..,current,..], g[..,current,..], b[..,current,..], offset, gain, img);
			ELSE MatrixRaster.LRealRGBToImageB( r[..,..,current], g[..,..,current], b[..,..,current], offset, gain, img);
			END;
		ELSIF LEN(model.m,0)>0 THEN
			IF DIM(model.m)=4 THEN m:=ALIAS OF model.m[cur3 MOD LEN(model.m,0),?] ELSE m:=ALIAS OF model.m END;
			IF DIM(model.m)=2 THEN MatrixRaster.LRealToImage(model.m[*,*], offset, gain, img);
			ELSIF orientation=0 THEN MatrixRaster.LRealToImage(m[current,*,*], offset, gain, img);
			ELSIF orientation=1 THEN MatrixRaster.LRealToImage(m[..,current,..], offset, gain, img);
			ELSE 						MatrixRaster.LRealToImage(m[..,..,current], offset, gain, img);
			END;
		ELSE
		END;
		PostInvalidate;
	END Render;

	PROCEDURE RenderScaled*(offset:SIGNED32;gain: FLOAT64);
	BEGIN
		SELF.offset:=offset; SELF.gain:=gain;
		Render;
	END RenderScaled;

	PROCEDURE AddWindow*;
	BEGIN
		ASSERT(exists);
		WM.ExtAddWindow(SELF,  32+(pos MOD 10)*48 + (pos DIV 10) *200, 96+(pos MOD 10) *48,
									{WM.FlagFrame,WM.FlagClose,WM.FlagMinimize});
		INC(pos);
	END AddWindow;

END Window;

VAR InsertPosX*,InsertPosY*, pos: SIGNED32; (* default insertion point for new window *)

PROCEDURE GenerateName(prefix: Strings.String; VAR str: ARRAY OF CHAR);
VAR  i,j:SIGNED32; title: Files.FileName; c:CHAR;
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
		IF title="" THEN title:="Matrix" END;
	ELSE title:="Matrix"
	END;
	COPY(title, str);
END GenerateName;

PROCEDURE RemoveWindows*(context:Commands.Context); (*! does this need a wait for termination ?  *)
VAR manager:WM.WindowManager; w,remove:WM.Window; i:SIGNED32;
BEGIN {EXCLUSIVE}
	IF (context=NIL) OR (~context.arg.GetInteger(i,FALSE)) THEN i:=MAX(SIGNED32) END;
	manager:=WM.GetDefaultManager();
	manager.lock.AcquireWrite;
	w:=manager.GetFirst();
	WHILE (w#NIL) & (i>0) DO
		remove:=w;
		w:=manager.GetNext(w);
		IF (remove#NIL)&(remove IS Window) THEN manager.Remove(remove); DEC(i) END;
	END;
	manager.lock.ReleaseWrite;
END RemoveWindows;

PROCEDURE RemoveAllWindows;
BEGIN
	RemoveWindows(NIL)
END RemoveAllWindows;

PROCEDURE Test*;
VAR window:Window;
	tensor: ARRAY [?] OF SIGNED32; (* or FLOAT64 or other..*)
BEGIN
	(*have some data in a 3D array ready*)
	NEW(tensor, 4, 50,100,120);
	tensor[..,..,10..40,..]:=1;
	tensor[..,10..15,..,..]:=2;
	tensor[..,..,..,10..30]:=3;

	tensor[0,..,0..10,..]:=tensor[0,..,0..10,..]+1;
	tensor[1,..,10..20,..]:=tensor[1,..,10..20,..]+1;
	tensor[2,..,20..30,..]:=tensor[2,..,20..30,..]+1;
	tensor[3,..,30..40,..]:=tensor[3,..,30..40,..]+1;

	(*show data as mouse or arrow key scrollable window*)
	NEW(window, tensor, "MyTensor",0);
	window.AddWindow;
END Test;


BEGIN
	Modules.InstallTermHandler(RemoveAllWindows);
	InsertPosX:=30; InsertPosY:=30;
END WMTensor.
~

(*
example code in application:
*)

MODULE Test;

IMPORT WMStack;

PROCEDURE Test*;
VAR window:WMStack.Window;
	tensor: ARRAY [?] OF FLOAT64; (* or FLOAT64 or other..*)
BEGIN
	(*have some data in a 4D array ready*)
	NEW(tensor, 5, 40,100,100);
	tensor[..,..,10..40,..]:=1;
	tensor[..,10..15,..,..]:=2;
	tensor[..,..,..,10..30]:=3;
	(*show data as mouse or arrow key scrollable window*)
	NEW(window, tensor, "MyTensor",0);
	window.AddWindow;
END Test;

END Test.


WMTensor.RemoveWindows ~ (*close and remove all stack windows*)
WMTensor.RemoveWindows 5 ~ (* close and remove a number of stack windows*)
WMTensor.Test

Test.Test 

System.FreeDownTo WMTensor~

