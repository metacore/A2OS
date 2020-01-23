MODULE WMHexEditor; (** AUTHOR "BohdanT"; PURPOSE ""; *)
(** 
AUTHOR "BohdanT"; November 25, 2014,
PURPOSE "part of WMDebugger, HexEditor visual component"
VERSION 1.1
*)
IMPORT 
	SYSTEM,
	KernelLog, WMComponents, Commands,
	Modules,WM := WMWindowManager, 
	WMGraphics, WMRectangles, Strings,
	WMStandardComponents,
	WMMessages,
	Inputs,
	Files;

(*Common types and constants*)
TYPE
	String=Strings.String;
	Canvas = WMGraphics.Canvas;

CONST
	Trace = FALSE;

	AlignTop=WMComponents.AlignTop;
	AlignNone=WMComponents.AlignNone;
	AlignLeft=WMComponents.AlignLeft;
	AlignClient=WMComponents.AlignClient;
	AlignRight=WMComponents.AlignRight;
	AlignBottom=WMComponents.AlignBottom;

	mouseWheelScrollSpeedI = 3;
	
	CONST
		(* Color scheme *)	
		clrSelection* = LONGINT(08080FFFFH);
		clrCursor* = LONGINT(00000FFFFH);
		clrBackGround* = LONGINT(000080FFH);
		clrText* = LONGINT(0FFFF00FFH);
		clrTextMod* = LONGINT(0FF9400FFH);
		clrTextDif* = LONGINT(090FF00FFH);
		
TYPE
	EditState= ENUM edAddr, edHex, edText END;
		
	Highlight* = POINTER TO RECORD
		enable:BOOLEAN;
		from*, to*:LONGINT;
		color*:LONGINT;
		mem*:POINTER TO ARRAY OF CHAR;
		next:Highlight;
	END;
		PROCEDURE Dump(VAR highlights: Highlight);
		VAR
			p:Highlight;
		BEGIN
			KernelLog.String("Dump"); KernelLog.Ln; 
			p:= highlights;
			WHILE p#NIL DO 
				KernelLog.String("f: "); KernelLog.Int(p.from, 5); KernelLog.String(" t: "); KernelLog.Int(p.to, 5);KernelLog.String(":");KernelLog.String(p.mem^); KernelLog.Ln;
				p:=p.next;
			END
		END Dump;

		PROCEDURE AddNewChar(VAR highlights: Highlight; pos:LONGINT;ch:CHAR);
		VAR
			str: String;
		BEGIN
			NEW(str,10);
			str[0] := ch; str[1] := 0X;
			AddNewBlock(highlights, pos, str);
		END AddNewChar;
		
		PROCEDURE AddNewBlock(VAR highlights: Highlight; pos:LONGINT;str:String);
		VAR
			llen:LONGINT;
			p,p1, last:Highlight;
			mem:POINTER TO ARRAY OF CHAR;

			PROCEDURE NormaL(VAR l,r:Highlight);
			VAR
				i, n:LONGINT;
				a, b:LONGINT;
			BEGIN
				IF l.to>r.to THEN
					a:=r.from-l.from;
					FOR i:=0 TO r.to-r.from-1 DO
						l.mem[i+a]:=r.mem[i];
					END;
				ELSE
					n:=r.to-l.from;
					IF n>LEN(l.mem) THEN
						NEW(mem,n*2);
						FOR i:=0 TO r.from-l.from-1 DO
							mem[i]:=l.mem[i];
						END;
						l.mem:=mem;
					END;
					a:=r.from-l.from;
					b:=r.to-r.from-1;
					FOR i:=0 TO b DO
						l.mem[i+a]:=r.mem[i];
					END;
					l.to:=r.to
				END;
			END NormaL;
			
			PROCEDURE NormaR(VAR l:Highlight;r:Highlight);
			VAR
				n,i:LONGINT;
			BEGIN
				WHILE (r#NIL)&(l.to>=r.from) DO
					IF r.to>=l.to THEN
(*						KernelLog.String("!!!!!!!!!!!!!!!!!!!");KernelLog.Ln; 
						KernelLog.String("L");KernelLog.String(l.mem^); KernelLog.Ln; 
						KernelLog.String("R");KernelLog.String(r.mem^); KernelLog.Ln; *)
						n:=r.to-l.from;
						IF n>LEN(l.mem) THEN
							NEW(mem,n*2);
							FOR i:=0 TO l.to-l.from-1 DO
								mem[i]:=l.mem[i];
							END;
(*							KernelLog.String("@@1 "); KernelLog.Ln; *)
							l.mem:=mem;
						END;
(*						KernelLog.String("@@2 "); KernelLog.Ln; *)
						FOR i:=0 TO r.to-l.to-1 DO
(*							KernelLog.String("*");*)
							l.mem[l.to-l.from+i]:=r.mem[l.to-r.from+i];
						END;
(*						KernelLog.Ln; 
						KernelLog.String(l.mem^);
						KernelLog.Ln; *)
						l.to:=r.to;
					END;
					l.next:=r.next;
					r:=r.next;
				END;
			END NormaR;
			
		BEGIN
			llen:=Strings.Length(str^);
			IF Trace THEN 
				KernelLog.String("************ ");
				KernelLog.String("add at:"); KernelLog.Int(pos, 5);KernelLog.String("to:"); KernelLog.Int(pos+llen, 5);KernelLog.Ln;
			END;
		
			IF highlights=NIL THEN (*List emty*)
				NEW(p);
				highlights:=p;
				p.from:=pos;
				p.to:=pos+llen;
				p.mem:=str;
				highlights.next:=NIL;
			ELSE
				p:=highlights;
				last:=p;
				WHILE (p.to<pos)&(p.next#NIL) DO 
					last:=p; 
					p:=p.next 
				END;
				IF Trace THEN KernelLog.String("<<<f: "); KernelLog.Int(p.from, 5); KernelLog.String(" t: "); KernelLog.Int(p.to, 5);KernelLog.Ln; END;

				IF pos<p.from THEN (*Insert first*)
				IF Trace THEN KernelLog.String("*0*");  KernelLog.Ln; END;
				
					NEW(p1);
					IF p=highlights THEN 
						highlights:=p1 
					ELSIF pos+llen<p.from THEN
						last.next:=p1;
					END;
					p1.next:=p;
					p1.from:=pos;
					p1.to:=pos+llen;
					p1.mem:=str;
					IF Trace THEN KernelLog.String("c= "); KernelLog.Char(str[0]); KernelLog.Ln; END;
					NormaR(p1,p);
				ELSIF pos<=p.to THEN
				IF Trace THEN KernelLog.String("*1*");  KernelLog.Ln; END;
					NEW(p1);
					p1.from:=pos;
					p1.to:=pos+llen;
					p1.mem:=str;
					NormaL(p,p1);
					NormaR(p,p.next);
				ELSE
					IF Trace THEN KernelLog.String("*2*");  KernelLog.Ln; 
					KernelLog.String("len= "); KernelLog.Int(llen, 0); KernelLog.Ln;
					END;
					NEW(p1);
					p1.from:=pos;
					p1.to:=pos+llen;
					p1.mem:=str;
					p.next:=p1;
				END;
			END;	

(*			p.mem[pos-p.from] := char;*)
		END AddNewBlock;
		
TYPE		
	MemPanel* = OBJECT(WMComponents.VisualComponent)
	VAR
		font:WMGraphics.Font;
		hl:Highlight;	
		editState : EditState;

(*TODO: Make property*)
		selectionColor-,
		backGroundColor-,
		textColor- : LONGINT;
		fontHeight:LONGINT; fontWidth:LONGINT;

		addrVisible*:BOOLEAN;
		addrWidth:LONGINT;

		textTop,
		textLeft:LONGINT;
		
		cursorIsVisible:BOOLEAN;
		cursor:LONGINT;
		selection:Highlight;
		
(*		address-:WMProperties.Int32Property;*)
		adrfrom:ADDRESS;
		adr:ADDRESS;
		siz:LONGINT;
		adrMode-:BOOLEAN;
		

		PROCEDURE SetFont(f:WMGraphics.Font);
		VAR
			g : WMGraphics.GlyphSpacings;
		BEGIN
			font:=f;
			fontHeight:=font.GetHeight();
			textTop:= fontHeight;
			font.GetGlyphSpacings(ORD('0'), g);
			fontWidth:=g.bearing.l + g.width + g.bearing.r;
			addrVisible:=TRUE;
			addrWidth:=fontWidth*9;
			textLeft:=addrWidth+(16*3+6+2)*fontWidth;
			Invalidate();
		END SetFont;
		
		PROCEDURE &Init*();
		VAR
			i:LONGINT;
			s:String;
		BEGIN
			Init^;

			hl:=NIL;
			adrMode:=FALSE;
			SetNameAsString(Strings.NewString("MemPanel"));
(*			NEW(address, NIL,  Strings.NewString("Address"), Strings.NewString("Set begin address")); properties.Add(address);*)
			NEW(selection);
			selection.enable:=FALSE;
			selection.from:=-1;
			selection.to:=-1;

			
			adr:=SELF;

(*			font:=WMGraphics.GetFont("Courier", 12, {});*)
			font:=WMGraphics.GetFont("Vera", 14, {});
			fillColor.Set (clrBackGround);
(*			textColor:=LONGINT(0FFFF00FFH);*)

			textColor:=clrText;
			selectionColor:=clrSelection;
			
			SetNameAsString(Strings.NewString("MemPanel"));
(*			SetFont(WMGraphics.GetFont((*"Courier"*)"Courier", 12, {0}));*)
			SetFont(WMGraphics.GetFont((*"Courier"*)"VeraMo", 12, {}));

			cursor:=0;
(*			KernelLog.String("fontHeight= ");KernelLog.Int(fontHeight,0); KernelLog.Ln; 
			KernelLog.String("fontWidth= ");KernelLog.Int(fontWidth,0); KernelLog.Ln; *)
			SetPointerInfo(manager.pointerText);

			takesFocus.Set(TRUE);

(*			WMStandardComponents.blinker.events.Add(SetBlinker);*)
		END Init;

		PROCEDURE SetLimit(adr:ADDRESS;siz:LONGINT);
		BEGIN
			adrfrom:=adr;
			SELF.siz:=siz;
			cursor:=0;
			SELF.adr:=adr;
(*			address.Set(adr)*);
(*			DisableUpdate;
			EnableUpdate;*)
			Invalidate();
		END SetLimit;
		
		PROCEDURE SetAdrViewMode*(m:BOOLEAN);
		BEGIN
			adrMode:=m;
			Invalidate();
		END SetAdrViewMode;
		
		
		PROCEDURE SetPageAdr*(a:ADDRESS);
		BEGIN
			IF a<adrfrom THEN
				a:=adrfrom;
				cursor:=0;
			END;
				
			IF a<(adrfrom+siz) THEN
				adr := a;
			ELSE
				cursor:=(siz-(adr-adrfrom))*2;
			END;
			Invalidate;

		END SetPageAdr;
		

		PROCEDURE PropertyChanged*(sender, property : ANY);
		BEGIN
(*			IF (property = address) THEN
			ELSE
				PropertyChanged^(sender, property)
			END
						*)
				PropertyChanged^(sender, property)

		END PropertyChanged;


		PROCEDURE GetCursorRect():WMRectangles.Rectangle;
		VAR
			cliprect : WMRectangles.Rectangle;
			pos:LONGINT;
			x,y:LONGINT;
		BEGIN
			CASE editState OF
			|EditState.edAddr:
				RETURN WMRectangles.MakeRect(0,0,fontWidth,2);
			|EditState.edHex:
				pos:=cursor DIV 2;
				x:=pos MOD 16;
				x:=fontWidth*(2+x*3+(cursor MOD 2)+(x DIV 4)+(x DIV 8) )+addrWidth;
				y:=fontHeight*(1+pos DIV 16)+textTop;
				RETURN WMRectangles.MakeRect(x,y,x+fontWidth,y+2);
			|EditState.edText:	
				pos:=cursor DIV 2;
				x:=pos MOD 16;
				x:=fontWidth*(x)+textLeft;
				y:=fontHeight*(1+pos DIV 16)+textTop;
				RETURN WMRectangles.MakeRect(x,y,x+fontWidth,y+2);
			END;
		END GetCursorRect;

		PROCEDURE GetLineCount():LONGINT;
		BEGIN
			ASSERT(fontHeight>0);
			RETURN ((bounds.GetHeight()-5) DIV fontHeight)-1;
		END GetLineCount;

		PROCEDURE FindLineByY(y:LONGINT):LONGINT;
		BEGIN
			RETURN ((y-textTop) DIV fontHeight);
		END FindLineByY;
		
		PROCEDURE CheckPointer(a,b:ADDRESS):BOOLEAN;
		BEGIN
			IF a<04000000H THEN
			IF (a+b) DIV 10000H>=((1+a DIV 10000H)) THEN RETURN FALSE ELSE RETURN TRUE END;
			END;
			RETURN TRUE;
		END CheckPointer;

		PROCEDURE GetActualChar(ofs:LONGINT):CHAR;
		VAR
			h:Highlight;
			ch:CHAR;
		BEGIN
			ofs:=ofs-adrfrom;
			h:=hl;
			WHILE (h#NIL)&(h.to<=(ofs)) DO h:=h.next; END;
			IF (h#NIL)&(h.from<=(ofs))THEN
				IF Trace THEN KernelLog.String("nh= "); KernelLog.Hex(ORD(h.mem[ofs-h.from]),8); END;
				SYSTEM.GET(adrfrom+ofs,ch);
				IF Trace THEN
					KernelLog.String("oh= "); KernelLog.Hex(ORD(ch),8); KernelLog.Ln; 
					KernelLog.Ln;
				END;
				RETURN h.mem[ofs-h.from];
			END;
			SYSTEM.GET(ofs+adrfrom,ch);
			RETURN ch;
		END GetActualChar;

		
		PROCEDURE Draw*(canvas : Canvas);
		VAR
			i, j, pos, y, x, xi : LONGINT;
			tmps1, tmps2 : ARRAY 9 OF CHAR; 
			tmp : LONGINT;
			cursr, cliprect : WMRectangles.Rectangle; cstate : WMGraphics.CanvasState;
			ch, cho, chn : CHAR;(*New and old char*)
			hnc:BOOLEAN;(*has new char*)
			la,lb : LONGINT;
			h:Highlight;
		BEGIN
(*			Draw^(canvas);*)
			h:=hl;
			canvas.SaveState(cstate);
			canvas.GetClipRect(cliprect);
			IF WMRectangles.RectEmpty(cliprect) THEN RETURN END;
	
			canvas.SetClipRect(cliprect);
			canvas.Fill(bounds.Get(), clrBackGround, WMGraphics.ModeSrcOverDst) ;
			canvas.SetColor(textColor);
			canvas.SetFont(font);
			
			la := FindLineByY(cliprect.t);
			lb := FindLineByY(cliprect.b);
			
			pos:=0;
			y:=0;xi:=0;
			x:=addrWidth; y:=fontHeight;
			tmp:=0;

			IF la<0 THEN (*if need render top area*)
				x:=addrWidth + fontWidth DIV 2;
				FOR j:=0 TO 0FH DO (*Render line*)
					IF (j MOD 4)=0 THEN INC(x,fontWidth); END;
					IF (j MOD 8)=0 THEN INC(x,fontWidth); END;
					Strings.IntToHexStr(j, 1, tmps1);
					canvas.DrawString(x, textTop, tmps1);(*Draw line offset*)
					INC(x,fontWidth*3);
				END;
				la:=0;
			END;
			
			WHILE (h#NIL)&(h.to<(la*16+adr-adrfrom)) DO h:=h.next; END;
			
			FOR i:=la TO lb DO
				y:=(i+1)*(fontHeight)+textTop; pos:=i*16; 
				(*Render line*)
				IF adrMode THEN
					Strings.IntToHexStr(adr+pos, 8, tmps1);
				ELSE
					Strings.IntToHexStr(adr+pos-adrfrom, 8, tmps1);
				END;
				canvas.SetColor(textColor);
				Strings.Append(tmps1, ":");
				canvas.DrawString(fontWidth,y,tmps1);	(*Render address*)

				x:=addrWidth;
				FOR j:=0 TO 0FH DO (*Render line*)
					IF ((adr+pos)>=adrfrom)&((adr+pos)<(adrfrom+siz)) THEN
						IF (j MOD 4)=0 THEN INC(x,fontWidth); END;
						IF (j MOD 8)=0 THEN INC(x,fontWidth); END;
						IF (adr+pos)>1024 THEN(*??? TODO: WTF *)
								
							 	IF CheckPointer(adr,pos) THEN
									SYSTEM.GET(adr+pos,cho);				(*TODO: make protect to read N/A address*)
							 	ELSE
										cho:=0X;				(*TODO: make protect to read N/A address*)
							 	END;
						ELSE
							cho:=0X;
						END;
						hnc:=FALSE;
						WHILE (h#NIL)&(h.to<(pos+adr-adrfrom)) DO h:=h.next; END;
						IF (h#NIL)&(h.from<=(pos+adr-adrfrom))&(h.to>(pos+adr-adrfrom)) THEN
							hnc:=TRUE;
							chn:=h.mem[pos-h.from+adr-adrfrom];
						END;
						(*Draw selection bkgrnd*)
						IF ((adr+pos)>=MIN(selection.from,selection.to))&((adr+pos)<MAX(selection.from,selection.to)) THEN
							canvas.Fill( (*Hex area *)
							WMGraphics.MakeRectangle(x,y - fontHeight,x+(3)*fontWidth, y),
							clrSelection, WMGraphics.ModeSrcOverDst) ;

							canvas.Fill( (*Text area *)
							WMGraphics.MakeRectangle(textLeft+(j)*fontWidth,y - fontHeight,textLeft+(j+1)*fontWidth, y),
							clrSelection, WMGraphics.ModeSrcOverDst) ;
						
						END;

						(*Draw cursor mark*)
						IF pos=(cursor DIV 2) THEN
							IF editState#EditState.edText THEN
								canvas.Fill(
								WMGraphics.MakeRectangle(textLeft+(j)*fontWidth,y - fontHeight,textLeft+(j+1)*fontWidth, y),
								clrCursor, WMGraphics.ModeSrcOverDst);
							END;
							IF  editState#EditState.edHex THEN
								canvas.Fill(
								WMGraphics.MakeRectangle(x,y - fontHeight,x+fontWidth*2, y), 
								clrCursor, WMGraphics.ModeSrcOverDst);
							END;
						END;

						Strings.IntToHexStr(ORD(cho), 2, tmps1);

						IF hnc THEN
							ch:=chn;
							Strings.IntToHexStr(ORD(chn), 2, tmps2);
							IF tmps1[0]#tmps2[0] THEN canvas.SetColor(LONGINT(0FF0000FFH)); ELSE canvas.SetColor(textColor); END;
							(*Render char code*)
							font.RenderChar(canvas,x,y,ORD(tmps2[0]));
							IF tmps1[1]#tmps2[1] THEN canvas.SetColor(LONGINT(0FF0000FFH)); ELSE canvas.SetColor(textColor); END;
							(*Render char code*)
							font.RenderChar(canvas,x+fontWidth,y,ORD(tmps2[1]));

							IF chn#cho THEN canvas.SetColor(LONGINT(0FF0000FFH)); ELSE canvas.SetColor(textColor); END;
						ELSE
							ch:=cho;
							canvas.SetColor(textColor);
							canvas.DrawString(x,y,tmps1);				(*Render char code*)
						END;
						IF font.HasChar(ORD(ch)) THEN
							font.RenderChar(canvas,textLeft+j*fontWidth,y,ORD(ch));(*Render char*)
						END;
						INC(pos);INC(x,fontWidth*3);
					END;
				END;			
			END;
			
			cursr:=GetCursorRect();
			IF cursorIsVisible THEN
				canvas.Fill(cursr,LONGINT(0C0C040FFH),WMGraphics.ModeSrcOverDst);
			ELSE
				canvas.Fill(cursr,fillColor.Get(),WMGraphics.ModeSrcOverDst);
			END;

			canvas.RestoreState(cstate);

	END Draw;
	
		PROCEDURE WheelMove*(dz: LONGINT); (** PROTECTED *)
		BEGIN
			IF mouseWheelScrollSpeedI # 0 THEN
				SetPageAdr(adr+16*mouseWheelScrollSpeedI*dz);
			END;
			Invalidate();

		END WheelMove;

		PROCEDURE ViewToTextPos(x, y : LONGINT; VAR st:EditState):LONGINT;
				PROCEDURE GetHexX(x:LONGINT):LONGINT;
				BEGIN
					x:=x DIV fontWidth;
					x:=x-((x+1) DIV 27);					
					x:=x-((x+1)  DIV 13);
					x:=x-((x+1) DIV 3);
					RETURN x;
				END GetHexX;

		BEGIN
			y := (y - textTop) DIV fontHeight;
			y := MAX(y, 0);
			IF x<addrWidth+fontWidth*2 THEN
				st:=EditState.edAddr;
			ELSIF x<textLeft THEN
				st:=EditState.edHex;
				x:=GetHexX(x-addrWidth-fontWidth*2);
				cursor:=y*32+x;
			ELSE
				st:=EditState.edText;
				x:=MIN((x-textLeft) DIV fontWidth, 15);
				cursor:=y*32+x*2;
			END;

(*			KernelLog.String("dh= "); KernelLog.Hex(LONGINT(st),8); 
			KernelLog.String("x= "); KernelLog.Int(x, 0); 
			KernelLog.String(" y= "); KernelLog.Int(y, 0); KernelLog.Ln;*)
			RETURN 0;
		END ViewToTextPos;
		
		PROCEDURE PointerDown*(x, y : LONGINT; keys : SET);
		VAR pos : LONGINT;
		TYPE
		BEGIN
			pos:=ViewToTextPos(x,y,editState);
			cursorIsVisible := TRUE;
			Invalidate;
		END PointerDown;

		PROCEDURE Handle*(VAR m: WMMessages.Message);
		BEGIN
			IF m.msgType = WMMessages.MsgKey THEN
				IF ~HandleShortcut(m.x, m.flags, m.y) THEN
					Handle^(m);
				END;
			ELSE Handle^(m)
			END
		END Handle;


		PROCEDURE SetSelection(select:BOOLEAN;old:LONGINT);
		VAR
		BEGIN
			IF select THEN
				
				IF ~selection.enable THEN
					selection.from:=adr+((old +1)DIV 2);
				END;
				selection.to:=adr+((cursor+1) DIV 2);
				
				selection.enable:=TRUE;
					
			ELSE
				selection.enable:=FALSE;
(*				selection.from:=-1;
				selection.to:=-1;*)
			END
		END SetSelection;
		PROCEDURE MoveCursor(inc:LONGINT);
		BEGIN
			IF ((adr-adrfrom)*2+cursor+inc)<(siz*2) THEN
				cursor:=cursor+inc;
			ELSE
				cursor:=(siz-(adr-adrfrom))*2;
			END;
			

		END MoveCursor;
		
		PROCEDURE HandleShortcut(ucs : LONGINT; flags : SET; keysym : LONGINT) : BOOLEAN;
		VAR
			tmp : ADDRESS;
			oldcur:LONGINT;
			incx:LONGINT;
			ss:BOOLEAN;
		PROCEDURE Tetrada(ch:CHAR);
		VAR
			t:LONGINT;
			c:CHAR;
		BEGIN
			c:=GetActualChar(adr+cursor DIV 2);
			CASE ch OF
			|'0'..'9':t:=ORD(ch)-ORD('0');
			|'a'..'f':t:=ORD(ch)-57H;
			|'A'..'F':t:=ORD(ch)-37H;
			END;
			IF cursor MOD 2 = 0 THEN
				c:=CHR(SYSTEM.VAL(LONGINT,SYSTEM.VAL(SET, c)*{0..3})+t*16)
			ELSE
				IF Trace THEN
					KernelLog.String("<<<c= ");  KernelLog.Hex(ORD(c),8); 
					KernelLog.String(" di= "); KernelLog.Int(t, 0); KernelLog.Ln;
				END;
					c:=CHR(SYSTEM.VAL(LONGINT,SYSTEM.VAL(SET, c)*{4..7})+t);
				IF Trace THEN
					KernelLog.String(">>>c= ");  KernelLog.Hex(ORD(c),8); KernelLog.Ln;
				END;
			END;
			AddNewChar(hl,adr-adrfrom+ cursor DIV 2, c);
			IF Trace THEN
				Dump(hl);
			END;

		END Tetrada;
		PROCEDURE ToLeft(inc:LONGINT);
		BEGIN
		END ToLeft;
		PROCEDURE ToRight(inc:LONGINT):BOOLEAN;
		BEGIN
			IF cursor<(GetLineCount()*32-inc) THEN
				MoveCursor(incx);
			ELSE
				cursorIsVisible := TRUE;
				SetPageAdr(adr+1);
				RETURN TRUE; (*small optimize, no need do invalidate twice*)
			END;
			RETURN FALSE;
		END ToRight;
		
		BEGIN
			ss:=selection.enable;
			IF editState=EditState.edHex THEN
				incx:=1;
			ELSE
				incx:=2;
			END;
			IF flags * Inputs.Ctrl # {} THEN incx:=8; END;
			

(*			KernelLog.String("dh= "); KernelLog.Hex(keysym, 8);KernelLog.Hex(SYSTEM.VAL(LONGINT,flags), 8);  KernelLog.Ln;*)
				oldcur:=cursor;
				IF (keysym= 0FF09H)  THEN (* TAB *)
					IF editState=EditState.edText THEN
						editState:=EditState.edHex;
					ELSE
						editState:=EditState.edText;
					END;
					Invalidate();
					RETURN FALSE; 
				ELSIF (keysym= 0FF51H)  THEN (* LEFT *)
					IF	cursor>0 THEN
						MoveCursor(-incx)
					ELSE
						cursorIsVisible := TRUE;
						SetPageAdr(adr-1);
						RETURN FALSE; (*small optimize, no need do invalidate twice*)
					END;
				ELSIF (keysym= 0FF52H) THEN (* UP *)
					IF cursor<16*2 THEN
						cursorIsVisible := TRUE;
						SetPageAdr(adr-16);
						RETURN FALSE; (*small optimize, no need do invalidate twice*)
					ELSE
						MoveCursor(-16*2)
					END;
				ELSIF (keysym= 0FF53H)  THEN (* RIGHT *)
					IF ToRight(incx) THEN RETURN FALSE END;
				ELSIF (keysym= 0FF54H)  THEN (* DOWN *)
					IF cursor<(GetLineCount()-1)*32 THEN
						MoveCursor(16*2);
					ELSE
						cursorIsVisible := TRUE;
						SetPageAdr(adr+16);
						RETURN FALSE; (*small optimize, no need do invalidate twice*)
					END;
				ELSIF keysym = 0FF56H THEN (* Page Down *)
					SetPageAdr(adr+(GetLineCount()-1)*16);
					cursorIsVisible := TRUE;
					RETURN FALSE; 
				ELSIF keysym = 0FF55H THEN (* Page Up *)
					SetPageAdr(adr-(GetLineCount()-1)*16);
					cursorIsVisible := TRUE;
					RETURN FALSE; 
				ELSIF keysym = 0FF50H THEN (* Cursor Home *)
					MoveCursor((cursor DIV 32)*32-cursor);
				ELSIF keysym = 0FF57H THEN (* Cursor End *)
					MoveCursor((cursor DIV 32)*32+30-cursor);
				ELSIF (keysym= 0FFBFH) & (flags = {})THEN (* F2 *)
					KernelLog.Memory(adr,GetLineCount()*32);
				ELSIF (keysym= 0FFC2H)& (flags = {}) THEN (* F5 *)
					SYSTEM.GET(adr,tmp);
					cursor:=0;
					cursorIsVisible := TRUE;
					SetPageAdr(tmp);
					RETURN FALSE;
				ELSIF (flags-Inputs.Shift) = {} THEN 
					IF editState=EditState.edText THEN
						IF keysym<=0FFH THEN
							selection.enable:=FALSE;
							AddNewChar(hl,adr-adrfrom+cursor DIV 2, CHR(keysym));
							IF ToRight(2) THEN RETURN FALSE END;
							Invalidate();
							RETURN FALSE;
						END;
					ELSE
						IF ((keysym>=ORD('0'))&(keysym<=ORD('9')))
							OR ((keysym>=ORD('a'))&(keysym<=ORD('f')))
							OR ((keysym>=ORD('A'))&(keysym<=ORD('F')))
						 THEN
							selection.enable:=FALSE;
						 	Tetrada(CHR(keysym));
							IF ToRight(1) THEN RETURN FALSE END;
							Invalidate();
							RETURN FALSE;
						END;
					END;
				END;
				SetSelection(flags * Inputs.Shift # {}, oldcur);(**********************)
				cursorIsVisible := TRUE;
				IF (cursor#oldcur)OR(ss#selection.enable) THEN
					Invalidate();
				END;
			RETURN FALSE;
		END HandleShortcut;
		
		PROCEDURE SetBlinker(sender, data: ANY);
		BEGIN
			WITH sender: WMStandardComponents.Blinker DO
				cursorIsVisible := sender.visible;
			END;
			InvalidateRect(GetCursorRect());
		END SetBlinker;
		
		PROCEDURE FocusReceived;
		BEGIN
			FocusReceived^;
			cursorIsVisible := TRUE;
			WMStandardComponents.blinker.events.Add(SetBlinker);
			Invalidate;
		END FocusReceived;

		PROCEDURE FocusLost;
		BEGIN
			FocusLost^;
			WMStandardComponents.blinker.events.Remove(SetBlinker);
			cursorIsVisible := FALSE;
			Invalidate;
		END FocusLost;

		PROCEDURE Finalize;
		BEGIN
			WMStandardComponents.blinker.events.Remove(SetBlinker);
			Finalize^;
		END Finalize;

	END MemPanel;


	
	Window* = OBJECT (WMComponents.FormWindow)
	VAR
		memPanel : MemPanel;
		buf:String;
		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR
			panel : WMStandardComponents.Panel;
			
		BEGIN
			NEW(panel);
			panel.bounds.SetExtents(655, 700);
			panel.fillColor.Set(LONGINT(0FFFFFFFFH));
			panel.fillColor.Set(0BCE0E0FFH(*LONGINT(0FFFFFFFFH)*));

			NEW(memPanel);
			memPanel.bounds.SetWidth (640);
			memPanel.bounds.SetHeight (600);
			memPanel.alignment.Set(WMComponents.AlignClient); 
(*			memPanel.SetLimit(ADDRESSOF(memPanel.font),2048-8(*SIZEOF(memPanel^)*) );*)
			panel.AddContent(memPanel);
			RETURN panel
		END CreateForm;

		PROCEDURE &New*;
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			IncCount;	(* A *)
			vc := CreateForm ();
			Init (vc.bounds.GetWidth (), vc.bounds.GetHeight (), FALSE);
			SetContent (vc);
			WM.DefaultAddWindow (SELF);
			SetTitle (Strings.NewString ("WMHexEditor -"));
		END New;

		PROCEDURE Close;
		BEGIN

			Close^;
			DecCount		(* B *)
		END Close;

		PROCEDURE Handle (VAR x: WMMessages.Message);		(* C *)
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) & (x.ext IS KillerMsg) THEN Close
			ELSE Handle^ (x)
			END
		END Handle;			
		PROCEDURE Load(CONST filename : ARRAY OF CHAR);
		VAR
			f:Files.File;
			r: Files.Rider;
		BEGIN
				f := Files.Old(filename);
				IF f # NIL THEN
					IF Trace THEN KernelLog.String("Loading ");  KernelLog.String(filename);  KernelLog.Ln END;
					f.Set(r, 0);
					NEW(buf, f.Length());
					r.file.ReadBytes(r, buf^, 0, f.Length());
					memPanel.SetLimit(ADDRESSOF(buf[0]), f.Length());
				END;
				memPanel.Invalidate();
		END Load;
		
	END Window;
	
	KillerMsg = OBJECT	(* D *)
	END KillerMsg; 	

VAR manager : WM.WindowManager;

VAR
	nofWindows : LONGINT;

(** Standard multiple windows controlled by number, non-restorable. *)
PROCEDURE Open* (context : Commands.Context); (** [Options] {filename['@'position]} ~ *)
VAR winstance : Window;
	filename : ARRAY 256 OF CHAR;

BEGIN
	NEW (winstance);
	
(*	winstance.DisableUpdate;
	winstance.EnableUpdate;*)
	WHILE context.arg.GetString(filename) DO
		Strings.Trim(filename,' ');
		KernelLog.String("filename= "); KernelLog.String(filename);  KernelLog.Ln;
		IF  filename # "" THEN winstance.Load(filename);  END
	END;

END Open;
PROCEDURE Test*;
VAR winstance : Window;

BEGIN 
	NEW (winstance);
	winstance.memPanel.SetAdrViewMode(TRUE);
	winstance.memPanel.SetLimit(ADDRESSOF(winstance.memPanel.font), 4096);

END Test;
PROCEDURE IncCount;	(* E *)
BEGIN {EXCLUSIVE}
	INC (nofWindows);
END IncCount;		

PROCEDURE DecCount;	(* F *)
BEGIN {EXCLUSIVE}
	DEC (nofWindows);
END DecCount;	

PROCEDURE Cleanup;	(* G *)
VAR die : KillerMsg;
	 msg : WMMessages.Message;
	 m : WM.WindowManager;
BEGIN {EXCLUSIVE}
	NEW (die);
	msg.ext := die;
	msg.msgType := WMMessages.MsgExt;
	m := WM.GetDefaultManager ();
	m.Broadcast (msg);
	AWAIT (nofWindows = 0)
END Cleanup;

(** *)

BEGIN
	manager := WM.GetDefaultManager();

	Modules.InstallTermHandler(Cleanup)
END WMHexEditor.Open~

SystemTools.Free  WMHexEditor~

WMDebugger.Open  WMHexEditor.Mod~

SystemTools.Free WMDebugger BtMenus BtDTraps BtDbgPanel I386Decoder2 BtDecoder WMComboBox WMHexEditor ~

WMHexEditor.Open~		
WMHexEditor.Test~	
-b=AMD --warnings --objectFile=Generic --newObjectFile --mergeSections --symbolFileExtension=".SymW"  objectFileExtension=.GofW



FSTools.CloseFiles A2.exe ~
WMKeyCode.Open ~
WMHexEditor.Open rugby.wav ~