MODULE WMArrayPanel; (** AUTHOR ""; PURPOSE "Display of 3D and 4D tensors as image"; *)

IMPORT Inputs, XML, MatrixRaster, MatrixUtilities, Files, Streams, WMMessages, WM:=WMWindowManager, WMComponents, WMProperties, WMStandardComponents, Strings, Models, WMGraphics, Commands;
CONST 	
	unsigned=0;
	signed=1;
	lut=2;
	rgb=3;
	heat=4;

(*! to do: improve current limitation to subtensor[0,?] display. Generalize to 1D, 2D and 5D+ data. implement lookup table display*)
 
TYPE 	
	Tensor= ARRAY [?] OF LONGREAL;

TYPE Data*= OBJECT (Models.Model)
		VAR m*, r*,g*,b*: Tensor;
		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetGenerator("WMArrayPanel.GenData");
			SetNameAsString(Strings.NewString("TensorData"));
		END Init;
	END Data;
	
TYPE TYPE Panel*= OBJECT (WMStandardComponents.ImagePanel) (*! tbd: convert some local variables to properties. move some local variables to model .  tbd: serialization*)
		VAR data*:Data; (*is also in model property*)
		orientation-: WMProperties.Int32Property;
		type, offset*, mx0,my0,mx1,my1,
		current*, cur3:LONGINT; 
		max,min, gain*:LONGREAL; 
		baseTitle, title: ARRAY 256 OF CHAR;
		img0 : WMGraphics.Image;
		
	PROCEDURE &Init*();
	BEGIN
		Init^;
		SetGenerator("WMArrayPanels.GenPanel");
		
		NEW(SELF.orientation, NIL, Strings.NewString("orientation"), Strings.NewString("")); properties.Add(SELF.orientation);
		SELF.orientation.Set(0);
		NEW(img0);
		NEW(data);
	 	model.Set(data); model.Changed;
		COPY(title,baseTitle); 
		id.Set(Strings.NewString(title));
		current:=0;
		RecacheProperties;
	END Init;

	PROCEDURE HandleInternal*(VAR x : WMMessages.Message);
		VAR filename: Files.FileName; f:Files.File; w:Files.Writer;
		BEGIN
			IF (x.msgType = WMMessages.MsgSerialize) & (x.msgSubType = WMMessages.MsgSubSerializeData) THEN
				IF title#"" THEN GenerateName(title, filename)
				ELSE GenerateName(id.Get()^, filename);
				END;
				Strings.Append(filename, ".MtA"); (* file type "MathArray" *)
				f:=Files.New(filename);
				Files.OpenWriter(w,f,0);
				MatrixUtilities.StoreLR(w, data.m);
				w.Update;
				Files.Register(f); 
			ELSE HandleInternal^(x);
			END;
	END HandleInternal;

	PROCEDURE PointerDown*(x, y : LONGINT; keys : SET); 
		BEGIN
			mx0:=x; my0:=y; 
		END PointerDown;
		
	PROCEDURE PointerUp*(x, y : LONGINT; keys : SET);
		BEGIN
			mx1:=x; my1:=y; 
		END PointerUp;
		
	PROCEDURE PointerMove*(x, y : LONGINT; keys : SET);
		BEGIN
			IF keys={2} THEN
				mx1:=x; my1:=y;
				gain:=gain*(1 + (mx1-mx0)/100);
				offset:=offset+(my0-my1);
				mx0:=mx1; my0:=my1;
				model.Set(data);
				model.Changed;
			ELSE
				PointerMove^(x,y,keys)
			END;
		END PointerMove;
	
	PROCEDURE WheelMove*(dz : LONGINT);
	VAR s: ARRAY 16 OF CHAR; 
		BEGIN
			IF DIM(data.m)=3 THEN current:=(current - dz) MOD LEN(data.m, orientation.Get()); (*! to do: fix for 3D, 2D, nD*)
			ELSIF DIM(data.m)=4 THEN current:=(current - dz) MOD LEN(data.m, orientation.Get()(*+1*)); 
			END;
			COPY(baseTitle,title); Strings.Append(title,"-"); 
			IF DIM(data.m)=4 THEN Strings.IntToStr(cur3 MOD LEN(data.m,0), s); Strings.Append(title, s); Strings.Append(title,"_") END;
			Strings.IntToStr(current,s);
			Strings.Append(title,s);
			id.Set(Strings.NewString(title));
					
			model.Set(data);
			model.Changed; 
		END WheelMove;
		
	(*The window can determine wether the key was pressed or released by examining the
			Inputs.Release flag in flags. ucs contains the unicode equivalent of the key. Special input editors
			send the generated unicode characters via KeyEvent.  *)
	PROCEDURE KeyEvent*(ucs : LONGINT; flags : SET; VAR keysym : LONGINT);
		VAR dz: LONGINT; s: ARRAY 32 OF CHAR; dim:LONGINT;
		BEGIN
			IF ~(Inputs.Release IN flags )THEN 
				dim:=MAX(DIM(data.m),DIM(data.r));
				IF keysym = Inputs.KsUp THEN 
					IF dim=3 THEN dz:=1; current:=(current + dz) MOD LEN(data.m, orientation.Get());
					ELSE INC(cur3)
					END;
				ELSIF keysym = Inputs.KsDown THEN 
					IF dim=3 THEN dz:=-1; current:=(current + dz) MOD LEN(data.m, orientation.Get()); 
					ELSE DEC(cur3);
					END;
				ELSIF keysym = Inputs.KsRight THEN 
					orientation.Set((orientation.Get()+1) MOD dim); current:=0;
				ELSIF keysym = Inputs.KsLeft THEN 
					orientation.Set((orientation.Get()-1) MOD dim); current:=0;
				ELSE 
					KeyEvent^(ucs,flags,keysym); RETURN
				END;
				COPY(baseTitle,title); Strings.Append(title,"-"); 
				IF dim=4 THEN Strings.IntToStr(cur3 MOD LEN(data.m,0), s); Strings.Append(title, s); Strings.Append(title,"_") END;
				Strings.IntToStr(current,s);
				Strings.Append(title,s);
				id.Set(Strings.NewString(title));
				
				model.Set(data);
				model.Changed; 
			ELSE 
				KeyEvent^(ucs,flags,keysym);
			END;
		END KeyEvent;
		
	PROCEDURE SetOrientation*(orientation:LONGINT );
	BEGIN
		ASSERT(orientation<DIM(data.m),201);
		SELF.orientation.Set(orientation);
	END SetOrientation;

	PROCEDURE SetArray*(CONST m: Tensor);
	BEGIN
		ASSERT(DIM(m) IN {2,3,4}, 200);
		IF LEN(m)>0 THEN
			data.m:=ALIAS OF m; 
			max:=MAX(m); min:=MIN(m); IF min<0 THEN type:=signed ELSE type:=unsigned END; 
			offset:=0; 
			IF max#min THEN gain:= 255/MAX( ABS(max),ABS(min));
			ELSE gain:=1;
			END;
			model.Set(data); (*? why are both calls needed to assure correct display ? maybe because the former only sends message if object has changed*)
			model.Changed;
		ELSE type:=unsigned;
		END;
	END SetArray;
	
	PROCEDURE SetArrayCustom*(CONST m: Tensor; offset:LONGINT;gain: LONGREAL);
	BEGIN
		IF LEN(m)>0 THEN 
			data.m:=ALIAS OF m; 
			max:=MAX(m); min:=MIN(m); IF min<0 THEN type:=signed ELSE type:=unsigned END; 
			SELF.offset:=offset; SELF.gain:=gain;
			model.Set(data);
			model.Changed;
		END;
	END SetArrayCustom;
	
	PROCEDURE SetArrayHeat*(CONST m: Tensor);
	BEGIN
		IF LEN(m)>0 THEN 
			data.m:=ALIAS OF m;(* no-copy version *)
			max:=MAX(m); min:=MIN(m); 
			type:=heat; 
			IF max#min THEN gain:= 511/(max-min);
			ELSE gain:=1;
			END;
			offset:=ENTIER(-255-gain*min);
			model.Set(data);
			model.Changed;
		END;
	END SetArrayHeat;
	
	PROCEDURE SetArrayRGB*(CONST r,g,b: Tensor); (*? need to assign data.m ?*)
	BEGIN
		IF LEN(r)>0 THEN 
			offset:=0; gain:=255/MAX(MAX(ABS(r)), MAX(MAX(ABS(g)), MAX(ABS(b)))); 
			data.r:=ALIAS OF r; data.g:=ALIAS OF g; data.b:=ALIAS OF b; 
			type:=rgb;
			model.Set(data);
			model.Changed;
		END;
	END SetArrayRGB;
	
	PROCEDURE Render*;
	VAR m,r,g,b: Tensor; orient, w, h: LONGINT; 
		len: ARRAY [*] OF SIZE;
	BEGIN
		orient:=orientation.Get();
		
		IF DIM(data.m)=2 THEN 
			w:=LEN(data.m,1); h:=LEN(data.m,0);
		ELSIF DIM(data.m)=3 THEN
			IF orient=0 THEN w:=LEN(data.m,2); h:= LEN(data.m,1);
			ELSIF orient=1 THEN w:=LEN(data.m,2); h:= LEN(data.m,0);   
			ELSE w:=LEN(data.m,1); h:= LEN(data.m,0); 
			END; 
		ELSIF DIM(data.m)=4 THEN
			IF orient=0 THEN w:=LEN(data.m,3); h:= LEN(data.m,2);
			ELSIF orient=1 THEN w:=LEN(data.m,3); h:= LEN(data.m,1);   
			ELSE w:=LEN(data.m,2); h:= LEN(data.m,1); 
			END; 
		ELSE RETURN 
		END;
		
		(* implicit call of Raster.Create in MatrixRaster calls*)
		len:=LEN(data.m);
		IF type=signed THEN 
			IF DIM(data.m)=4 THEN m:=ALIAS OF data.m[cur3 MOD LEN(data.m,0),?] 
			ELSE m:=ALIAS OF data.m (*only effective in DIM=3*) 
			END;
			IF DIM(data.m)=2 THEN MatrixRaster.LRealToImageBR(data.m[*,*], offset, gain, img0);
			ELSIF orient=0 THEN MatrixRaster.LRealToImageBR(m[current MOD len[0],*,*], offset, gain, img0);
			ELSIF orient=1 THEN MatrixRaster.LRealToImageBR(m[.., current MOD len[1], ..], offset, gain, img0);
			ELSE MatrixRaster.LRealToImageBR(m[..,..,current MOD len[2]], offset, gain, img0);
			END;
		ELSIF type=heat THEN 
			IF DIM(data.m)=4 THEN m:=ALIAS OF data.m[cur3 MOD LEN(data.m,0),?] ELSE m:=ALIAS OF data.m END;	
			IF DIM(data.m)=2 THEN MatrixRaster.LRealToImageHeat(data.m[*,*], offset, gain, img0);
			ELSIF orient=0 THEN MatrixRaster.LRealToImageHeat(m[current MOD len[0],*,*], offset, gain, img0);
			ELSIF orient=1 THEN MatrixRaster.LRealToImageHeat(m[.., current MOD len[1], ..], offset, gain, img0);
			ELSE MatrixRaster.LRealToImageHeat(m[..,..,current MOD len[2]], offset, gain, img0);
			END;
		ELSIF type=rgb THEN 
			IF DIM(data.r)=4 THEN 
				r:=ALIAS OF data.r[cur3 MOD LEN(data.r,0),?];
				g:=ALIAS OF data.g[cur3 MOD LEN(data.g,0),?]; 
				b:=ALIAS OF data.b[cur3 MOD LEN(data.b,0),?] 
			ELSE r:=ALIAS OF data.r; g:=ALIAS OF data.g; b:=ALIAS OF data.b; (*only effective in DIM=3*)
			END;
			IF DIM(data.r)=2 THEN MatrixRaster.LRealRGBToImageB( data.r[*,*], data.g[*,*], data.b[*,*], offset, gain, img0);
			ELSIF orient=0 THEN MatrixRaster.LRealRGBToImageB( r[current MOD len[0],*,*], g[current MOD len[0],*,*], b[current MOD len[0],*,*], offset, gain, img0);
			ELSIF orient=1 THEN MatrixRaster.LRealRGBToImageB( r[..,current MOD len[1],..], g[..,current MOD len[1],..], b[..,current MOD len[1],..], offset, gain, img0);
			ELSE MatrixRaster.LRealRGBToImageB( r[..,..,current MOD len[2]], g[..,..,current MOD len[2]], b[..,..,current MOD len[2]], offset, gain, img0);
			END;
		ELSIF LEN(data.m,0)>0 THEN 
			IF DIM(data.m)=4 THEN m:=ALIAS OF data.m[cur3 MOD LEN(data.m,0),?] ELSE m:=ALIAS OF data.m END;
			IF DIM(data.m)=2 THEN MatrixRaster.LRealToImage(data.m[*,*], offset, gain, img0);
			ELSIF orient=0 THEN MatrixRaster.LRealToImage(m[current MOD len[0],*,*], offset, gain, img0);
			ELSIF orient=1 THEN MatrixRaster.LRealToImage(m[..,current MOD len[1],..], offset, gain, img0);
			ELSE 					MatrixRaster.LRealToImage(m[..,..,current MOD len[2]], offset, gain, img0);
			END;
		ELSE 
		END;
	END Render;
	
	PROCEDURE PropertyChanged*(sender, property : ANY);
		BEGIN
			IF property = model THEN RecacheProperties; (*implicit invalidate in RecacheProperties*)
			ELSE	PropertyChanged^(sender, property)
			END
		END PropertyChanged;
		
		PROCEDURE LinkChanged*(sender, link : ANY); (*TBD: there is reduncancy. ideally, only a LinkChanged message should be n*)
		BEGIN
			IF link = data THEN RecacheProperties; 
			ELSE	LinkChanged^(sender, link)
			END
		END LinkChanged;
		
		PROCEDURE RecacheProperties*;
		BEGIN
			RecacheProperties^;
			Render;
			bounds.SetWidth(img0.width);
			bounds.SetHeight(img0.height);
			SetImage(SELF, img0) (*Implicit invalidate*)
		END RecacheProperties;
	
	END Panel;

PROCEDURE GenerateName(prefix: ARRAY OF CHAR; VAR str: ARRAY OF CHAR);
VAR  i,j:LONGINT; title: Files.FileName; c:CHAR; s:ARRAY 8 OF CHAR;
BEGIN
	i:=0; j:=0;
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
	COPY(title, str);
END GenerateName;
	
PROCEDURE GenPanel*() : XML.Element;
VAR
	p : Panel;
BEGIN
	NEW(p);
	RETURN p
END GenPanel;

PROCEDURE GenData*() : XML.Element;
VAR d : Data; 
BEGIN NEW(d); RETURN d
END GenData;

PROCEDURE GetPanel*(CONST tensor: ARRAY [?] OF LONGREAL): Panel;
VAR	panel:Panel;
BEGIN
	NEW(panel);
	panel.SetArray(tensor);
	panel.SetOrientation(0);
	RETURN panel
END GetPanel;

(*

PROCEDURE AddWindow*(CONST tensor: ARRAY [?] OF LONGREAL; CONST title: ARRAY OF CHAR);
VAR window:WMComponents.FormWindow; w,h:LONGINT;
	panel:Panel;
BEGIN
	NEW(panel);
	panel.SetArray(tensor);
	panel.SetOrientation(0);
	IF DIM(tensor)>1 THEN w:=LEN(tensor)[DIM(tensor)-1]; h:=LEN(tensor)[DIM(tensor)-2];
	ELSE w:=400; h:=400;
	END;
	NEW(window, w, h, FALSE); 
	window.SetTitle(Strings.NewString(title));
	INCL(window.flags, WM.FlagStorable); (* allow storing of data interactively, through right-click on navigator icon*)
	WM.DefaultAddWindow(window);
	window.SetContent(panel);
	window.form.fillColor.Set(008888FFH);(*background*)
END AddWindow;
*)

PROCEDURE AddWindow*(CONST tensor: ARRAY [?] OF LONGREAL; CONST title: ARRAY OF CHAR);
VAR window:WMComponents.FormWindow; w,h:LONGINT;
	panel:Panel;
BEGIN
	IF DIM(tensor)>1 THEN w:=LEN(tensor)[DIM(tensor)-1]; h:=LEN(tensor)[DIM(tensor)-2];
	ELSE w:=400; h:=400;
	END;
	NEW(window, w, h, FALSE); 
	window.SetTitle(Strings.NewString(title));
	INCL(window.flags, WM.FlagStorable); (* allow storing of data interactively, through right-click on navigator icon*)
	WM.DefaultAddWindow(window);
	panel:=GetPanel(tensor);
	COPY(title, panel.title); COPY(title, panel.baseTitle);
	window.SetContent(panel);
	window.form.fillColor.Set(008888FFH);(*background*)
END AddWindow;


PROCEDURE  Test*(context:Commands.Context); (*deprecated -  will be eliminated from source*)
VAR window:WMComponents.FormWindow;
	panel:Panel;
	tensor: ARRAY [?] OF LONGREAL; (* or LONGREAL or other..*)
BEGIN
	log:=context.out;
	(*have some data in a 3D array ready*)
	NEW(tensor,50,100,120); 
	tensor[..,10..40,..]:=1;
	tensor[10..15,..,..]:=2;
	tensor[..,..,10..30]:=3;
	
	(*show data as mouse or arrow key scrollable window*)
	NEW(panel);
	panel.SetArray(tensor);
	panel.SetOrientation(0);
	NEW(window, 400,400, FALSE); 
	window.SetTitle(Strings.NewString("tensor window"));
	INCL(window.flags, WM.FlagStorable); (* allow storing of data interactively, through right-click on navigator icon*)
	WM.DefaultAddWindow(window);
	window.SetContent(panel);
	window.form.fillColor.Set(008888FFH);(*background*)
	
	LOOP		
		tensor[10..15,..,..]:= MatrixUtilities.Random([1,5,100,120],MatrixUtilities.Uniform);
		panel.SetArray(tensor);
	END;
	
END Test;

VAR log:Streams.Writer;

END WMArrayPanel.

WMArrayPanel.Test~

System.FreeDownTo WMArrayPanel~

System.FreeDownTo MatrixUtilities ~