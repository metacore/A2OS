MODULE W3dMenu;	(** AUTHOR "TF"; PURPOSE "3d Menu (case study)"; *)

IMPORT
(* Low level *)
	KernelLog, Kernel, MathL, Modules, Files, Commands, Inputs, Strings,
(* Window Manager *)
	WM := WMWindowManager, Messages := WMMessages, Rect := WMRectangles, Raster, WMGraphics,
(* 3d framework *)
	Classes := TFClasses, Vectors := W3dVectors, Matrix := W3dMatrix,
	AbstractWorld := W3dAbstractWorld, World := W3dWorld, ObjectGenerator := W3dObjectGenerator,
(* XML framework *)
	XML, Scanner := XMLScanner, XMLParser, Objects := XMLObjects;

CONST BoxDistance = 200;
	SphereSel = 1;
	BlurpSel = 2;

TYPE
	ReloadMsg = OBJECT
	VAR
		name:ARRAY 100 OF CHAR
	END ReloadMsg;

	Symbol = OBJECT
	VAR
		pos : Vectors.TVector3d;
		command : ARRAY 128 OF CHAR;
		obj : AbstractWorld.Object;
		world : AbstractWorld.World;
		tex : AbstractWorld.Texture;
		index : LONGINT;

		PROCEDURE &Init*(world : AbstractWorld.World; pos : Vectors.TVector3d; command : ARRAY OF CHAR);
		BEGIN
			COPY(command, SELF.command); SELF.pos := pos; SELF.world := world
		END Init;
	END Symbol;

	UpdateProc = PROCEDURE {DELEGATE};

	Blurp = OBJECT
		VAR
			timer : Kernel.Timer;
			alive : BOOLEAN;
			obj, o2 : AbstractWorld.Object;
			update : UpdateProc;
			i, direct : LONGINT;
			dead, run, anirun : BOOLEAN;
			pos : Vectors.TVector3d;
			tex : AbstractWorld.Texture;
			world : AbstractWorld.World;

		 PROCEDURE &Init*(world: AbstractWorld.World; update: UpdateProc);
		 BEGIN
		 	SELF.update := update; SELF.world := world;
		 	SELF.obj := world.CreateObject(); SELF.o2 := world.CreateObject(); direct := 1; tex := NIL;
		 	world.AddObject(obj);
		 	(* a bit a trick *)
			world.SetAnimated(obj, TRUE); world.SetAnimated(o2, TRUE);
		END Init;

		PROCEDURE Update;
		VAR temp : AbstractWorld.Object;
		BEGIN
			o2.Clear;
			IF run THEN
				ObjectGenerator.TexBox(Matrix.Translation4x4(pos.x, pos.y + i * 2, pos.z),  105 + i*4,  105 + i*4,  105 + i*4, o2, 0FF0000H, tex);
				i := i + direct;
				IF i > 8 THEN BEGIN {EXCLUSIVE} anirun := FALSE END END
			END;
			temp := obj; world.ReplaceObject(obj, o2); obj := o2; o2 := temp;
			update
		END Update;

		PROCEDURE Set(pos : Vectors.TVector3d; tex : AbstractWorld.Texture);
		BEGIN {EXCLUSIVE}
			run := TRUE; anirun := TRUE; i := 0; timer.Wakeup; SELF.pos := pos; SELF.tex := tex; direct := 1
		END Set;

		PROCEDURE Stop;
		BEGIN {EXCLUSIVE}
			IF run THEN run := FALSE; Update END
		END Stop;

		PROCEDURE Kill;
		BEGIN {EXCLUSIVE}
			alive := FALSE; timer.Wakeup
		END Kill;

		PROCEDURE AwaitDead;
		BEGIN {EXCLUSIVE}
			AWAIT(dead)
		END AwaitDead;

	BEGIN {ACTIVE}
		dead := FALSE; alive := TRUE; NEW(timer);
		WHILE alive DO
			timer.Sleep(10);
			BEGIN {EXCLUSIVE} AWAIT(anirun & run OR ~alive) END;
			IF alive THEN Update END
		END;
		BEGIN {EXCLUSIVE} dead := TRUE END
	END Blurp;

	Window = OBJECT ( WM.BufferWindow )
	VAR
		(* Navigation *)
		lookat: Vectors.TVector3d;
		radius, angle, height : LONGREAL;
		mouseKeys, keyflags : SET;
		oldX, oldY : LONGINT;

		(* 3d World *)
		world : World.World;
		mx, my, mz : LONGREAL;

		infoList : Classes.List;
		index : LONGINT;
		aniObj, aniObj2 : AbstractWorld.Object;

		selectionMethod : SET;
		blurp : Blurp;
		selectedSymbol : Symbol;

		PROCEDURE SetSelection(pos : Vectors.TVector3d; l : LONGREAL; visible : BOOLEAN);
		VAR temp : AbstractWorld.Object;
		BEGIN
			aniObj2.Clear;
			IF visible THEN
				IF SphereSel IN selectionMethod THEN
					ObjectGenerator.Sphere(Matrix.Translation4x4(pos.x, pos.y + 80, pos.z), 30, 15, aniObj2, 0FFFF00H)
				END;
			END;
			temp := aniObj; world.ReplaceObject(aniObj, aniObj2); aniObj := aniObj2; aniObj2 := temp;
			RenderAnimation
		END SetSelection;

		PROCEDURE AddSelectionObjects;
		BEGIN
			NEW(blurp, world, RenderAnimation);
			aniObj := world.CreateObject(); world.SetAnimated(aniObj, TRUE);
			aniObj2 := world.CreateObject(); world.SetAnimated(aniObj2, TRUE);
			world.AddObject(aniObj)
		END AddSelectionObjects;

		PROCEDURE ParseLine(line : XML.Element; pos: Vectors.TVector3d);
		VAR cont : Objects.Enumerator; p : ANY; el : XML.Element; s, t : Strings.String;
			x: Symbol;
		BEGIN
			cont := line.GetContents(); cont.Reset();
			WHILE cont.HasMoreElements() DO
				p := cont.GetNext();
				el := p(XML.Element);
				s := el.GetName();
				IF s^ = "ImgBox" THEN
					s := el.GetAttributeValue("cmd"); IF s = NIL THEN NEW(x, world, pos, "hello") ELSE NEW(x, world, pos, s^) END;
					x.index := index; INC(index); infoList.Add(x);

					x.pos := pos; mx := MAX(pos.x, mx);
					pos.x := pos.x + BoxDistance;
					s := el.GetAttributeValue("img");
					IF s = NIL THEN NEW(s, 16) END;
					x.obj := world.CreateObject(); x.obj.SetIndex(x.index); world.AddObject(x.obj);
					x.tex := TextureByName(s^, x.obj);
					ObjectGenerator.TexBox(Matrix.Translation4x4(x.pos.x, x.pos.y, x.pos.z), 100, 100, 100, x.obj, 0FFAA00H,
						x.tex)

				ELSIF s^="SymbolBox" THEN
					s := el.GetAttributeValue("cmd"); IF s = NIL THEN NEW(x, world, pos, "hello") ELSE NEW(x, world, pos, s^) END;
					x.index := index; INC(index); winstance.infoList.Add(x);

					x.pos := pos; mx := MAX(pos.x, mx);
					pos.x := pos.x + BoxDistance;
					s := el.GetAttributeValue("img"); IF s = NIL THEN NEW(s, 16) END;
					t := el.GetAttributeValue("title"); IF t = NIL THEN NEW(t, 16) END;
					x.obj := world.CreateObject(); x.obj.SetIndex(x.index); world.AddObject(x.obj);
					x.tex := GenTexture(s^, t^, x.obj);
					ObjectGenerator.TexBox(Matrix.Translation4x4(x.pos.x, x.pos.y, x.pos.z), 100, 100, 100, x.obj, 0FFAA00H,
						x.tex)
				END
			END
		END ParseLine;

		PROCEDURE ParseLayer(layer : XML.Element; pos : Vectors.TVector3d);
		VAR cont : Objects.Enumerator; p : ANY; el : XML.Element;s : Strings.String;

		BEGIN
			cont := layer.GetContents(); cont.Reset();
			WHILE cont.HasMoreElements() DO
				p := cont.GetNext();
				el := p(XML.Element);
				s := el.GetName(); IF s^ = "Line" THEN
					ParseLine(el, pos); mz := MAX(pos.z, mz);
					pos.z := pos.z + BoxDistance
				END
			END
		END ParseLayer;

		PROCEDURE Load(filename: ARRAY OF CHAR);
		VAR f : Files.File;
			scanner : Scanner.Scanner;
			parser : XMLParser.Parser;
			reader : Files.Reader;
			doc : XML.Document;
			p : ANY;
			root: XML.Element;
			el : XML.Content;
			s : Strings.String;
			cont : Objects.Enumerator;
			pos : Vectors.TVector3d;
			obj : AbstractWorld.Object;
		BEGIN
			world.Clear; infoList.Clear; mx := 0; my := 0; mz := 0;
			IF blurp # NIL THEN blurp.Kill; blurp.AwaitDead END;

			index := 1;
			KernelLog.String(filename); KernelLog.Ln;
			f := Files.Old(filename);
			IF f # NIL THEN
				NEW(reader, f, 0);
				NEW(scanner, reader); NEW(parser, scanner); doc := parser.Parse();

				root := doc.GetRoot();
				cont := root.GetContents(); cont.Reset();
				WHILE cont.HasMoreElements() DO
					p := cont.GetNext();
					IF p IS XML.Element THEN
						el := p(XML.Element);
						s := el(XML.Element).GetName(); IF s^ = "Layer" THEN
							ParseLayer(el(XML.Element), pos); my := MAX(pos.z, my);
							pos.y := pos.y + BoxDistance
						END
					END
				END
			END;
			lookat := Vectors.Vector3d(mx / 2, my / 2, mz / 2);

			obj := world.CreateObject(); obj.SetIndex(index); world.AddObject(obj);
			ObjectGenerator.Box(Matrix.Translation4x4(mx/2, my/2 - 50 - 5,  mz/2), mx +100, 10, mz + 100, obj, 0FFFFCCH);
			AddSelectionObjects;
			Render
		END Load;

		PROCEDURE &New*(fileName: ARRAY OF CHAR);
		VAR w, h : LONGINT;
		BEGIN
			IF winstance = NIL THEN  winstance := SELF  END;  (* fld, adapt to new semantics of NEW *)
			manager := WM.GetDefaultManager();
			h := 480; w := 640;
			Init(w, h, FALSE);

			(* Init navigation parameters *)
			radius := 800; angle := -MathL.pi / 2; height := 200;

			(* Setup the 3d World *)
			NEW(world, w, h, 000000088H); world.quality := 1;
			NEW(infoList); Load(fileName);
			selectionMethod := { BlurpSel };

			WM.DefaultAddWindow(SELF);
			SetTitle(Strings.NewString("Menu 3d"));
			Render
		END New;

		PROCEDURE Close*;
		BEGIN
			IF blurp # NIL THEN blurp.Kill; blurp.AwaitDead END;
			Close^;
			winstance := NIL
		END Close;

		(* BEGIN Navigation and Rendering *)

		PROCEDURE RenderAnimation;
		BEGIN
			world.Render(img, TRUE);
			Invalidate(Rect.MakeRect(0,0,img.width, img.height))
		END RenderAnimation;

		PROCEDURE Render;
		VAR pos, dir, up : Vectors.TVector3d;
		BEGIN {EXCLUSIVE}
			pos := Vectors.VAdd3(lookat, Vectors.Vector3d(MathL.cos(angle) * radius, 0, MathL.sin(angle) * radius)); pos.y := height;
	(*		lookat := Vectors.Vector3d(lookat.x, lookat.y, lookat.z); *)
			dir := Vectors.VNormed3(Vectors.VSub3(lookat, pos));
			up := Vectors.VNeg3(Vectors.VNormed3(Vectors.Cross(Vectors.Cross(Vectors.Vector3d(0, 1, 0), dir), dir)));

			world.SetCamera(pos, dir, up); world.Render(img, FALSE);
			Invalidate(Rect.MakeRect(0, 0, img.width, img.height))
		END Render;

		PROCEDURE PointerDown*(x, y : LONGINT; keys :SET);
		BEGIN
			mouseKeys := (keys * {0, 1, 2});
			oldX := x; oldY := y
		END PointerDown;

		PROCEDURE PointerMove*(x, y: LONGINT; keys: SET);
		VAR idx : LONGINT;
			info : Symbol; dummy : ANY;
		BEGIN
			IF mouseKeys = {} THEN
				idx := world.GetOwnerIndex(x, y) - 1;
				IF (idx >= 0) THEN
					infoList.Lock;
					info := NIL;
					IF idx < infoList.GetCount() THEN dummy := infoList.GetItem(idx); info := dummy(Symbol) END;
					infoList.Unlock;
					IF selectedSymbol # info THEN
						IF info # NIL THEN
							SetSelection(info.pos, 0, TRUE);
							IF BlurpSel IN selectionMethod THEN blurp.Set(info.pos, info.tex)
							ELSE blurp.Stop;
							END
						ELSE blurp.Stop; SetSelection(Vectors.Vector3d(0,0,0), 0, FALSE)
						END
					END;
					selectedSymbol := info
				ELSE
					IF selectedSymbol # NIL THEN
						selectedSymbol := NIL; blurp.Stop;
						SetSelection(Vectors.Vector3d(0,0,0), 0, FALSE)
					END
				END;
				RETURN
			END;
			IF mouseKeys * {0} # {} THEN
				IF mouseKeys * {2} # {} THEN
					radius := radius - (y - oldY) * 10; IF radius < 10 THEN radius := 10 END;
				ELSE
					height := height + (y - oldY)
				END;
				angle := angle - (x - oldX) / img.width * 3.141;
				Render
			END;
			oldX := x; oldY := y
		END PointerMove;

		PROCEDURE PointerUp*(x, y: LONGINT; keys: SET);
		BEGIN
			IF mouseKeys = {0} THEN
				IF selectedSymbol # NIL THEN
					IF keyflags * Inputs.Shift # {} THEN
						lookat := selectedSymbol.pos; Render
			(*		ELSE
						Commands.Call(selectedSymbol.command, {}, res, msg);
						IF res # 0 THEN
							KernelLog.Enter; KernelLog.String(msg); KernelLog.Exit
						END *)
					END
				END
			END;
			mouseKeys := (keys * {0, 1, 2});
		END PointerUp;

(*		PROCEDURE KeyPressed(ch : CHAR; flags : SET; keysym : LONGINT);
		BEGIN
			keyflags := flags;
			IF ch = "s" THEN
				IF SphereSel IN selectionMethod THEN selectionMethod := selectionMethod - {SphereSel}
				ELSE selectionMethod := selectionMethod + {SphereSel}
				END
			ELSIF ch = "b" THEN
				IF BlurpSel IN selectionMethod THEN selectionMethod := selectionMethod - {BlurpSel}
				ELSE selectionMethod := selectionMethod + {BlurpSel}
				END
			END
		END KeyPressed;
*)

		PROCEDURE Handle*(VAR m : Messages.Message);
		BEGIN
			IF m.msgType = Messages.MsgExt THEN
				IF m.ext IS ReloadMsg THEN Load(m.ext(ReloadMsg).name) END
			ELSE
				Handle^(m)
			END
		END Handle;
		(* END Navigation and Rendering *)
	END Window;

	TextureInfo = OBJECT
		VAR
			img : Raster.Image;
			name : ARRAY 128 OF CHAR
	END TextureInfo;

VAR
	winstance : Window;
	textures: Classes.List;

PROCEDURE GenTexture(icon, title: ARRAY OF CHAR; obj : AbstractWorld.Object): AbstractWorld.Texture;
VAR res : BOOLEAN;
	 mode: Raster.Mode;
	 pix : Raster.Pixel;
	 tex : AbstractWorld.Texture;
	 img : Raster.Image;
	timg: Raster.Image;
	tw, th, dx, dy : LONGINT;
BEGIN
	timg := WMGraphics.LoadImage(icon, TRUE);
	Raster.InitMode(mode, Raster.srcCopy);
	NEW(img); Raster.Create(img, 64, 64, Raster.BGR565);
	Raster.SetRGB(pix, 0C0H, 0C0H, 0C0H); Raster.Fill(img, 1, 1, 62, 62, pix, mode);
	Raster.SetRGB(pix, 0H, 0H, 0H);
	Raster.Fill(img, 0, 11, 63, 12, pix, mode);
	Raster.Fill(img, 7, 12, 56, 62, pix, mode);
	Raster.SetRGB(pix, 0FFH, 0FFH, 0FFH);
	Raster.Fill(img, 9, 14, 54, 60, pix, mode);
	timg := WMGraphics.LoadImage(icon, TRUE);	tex := NIL;
	IF res THEN
		tw := MIN(timg.width, 46); th := MIN(timg.height, 46);
		dx := (46 - tw) DIV 2 + 9;
		dy := (46 - th) DIV 2 + 14;
		Raster.Copy(timg, img, 0, 0, tw, th, dx, dy, mode)
	END;
	tex := obj.AddTexture(img);
	RETURN tex
END GenTexture;

PROCEDURE TextureByName(name: ARRAY OF CHAR; obj : AbstractWorld.Object): AbstractWorld.Texture;
VAR i : LONGINT;
	dummy : ANY;
	ti : TextureInfo; mode: Raster.Mode;
	timg: Raster.Image;
BEGIN
	textures.Lock;
	FOR i := 0 TO textures.GetCount()-1 DO
		dummy := textures.GetItem(i); ti := dummy(TextureInfo);
		IF ti.name = name THEN
			IF ti.img = NIL THEN
				textures.Unlock;
				RETURN NIL
			ELSE textures.Unlock;
				RETURN obj.AddTexture(ti.img)
			END
		END
	END;
	textures.Unlock;
	NEW(ti); COPY(name, ti.name);
	timg := WMGraphics.LoadImage(name, TRUE);
	IF timg # NIL THEN
		NEW(ti.img); Raster.Create(ti.img, timg.width, timg.height, Raster.BGR565);
		Raster.InitMode(mode, Raster.srcCopy);
		Raster.Copy(timg, ti.img, 0, 0, timg.width, timg.height, 0, 0, mode)
	END;
	IF ti.img # NIL THEN RETURN obj.AddTexture(ti.img) ELSE RETURN NIL END
END TextureByName;

(*	PROCEDURE MatchI(VAR buf: ARRAY OF CHAR; with: ARRAY OF CHAR): BOOLEAN;
	VAR i: LONGINT;
	BEGIN
		i := 0; WHILE (with[i] # 0X) & (CAP(buf[i]) = CAP(with[i])) DO INC(i) END;
		RETURN with[i] = 0X
	END MatchI;
*)

PROCEDURE Open*(context : Commands.Context);
VAR name : ARRAY 100 OF CHAR;
BEGIN
	IF context.arg.GetString(name) THEN
		IF winstance = NIL THEN NEW(winstance, name) END;
	END;
END Open;

PROCEDURE Cleanup;
BEGIN
	IF winstance # NIL THEN winstance.Close END
END Cleanup;


BEGIN
	NEW(textures);
	Modules.InstallTermHandler(Cleanup)
END W3dMenu.

W3dMenu.Open W3dFun.XML ~
W3dMenu.Open W3dMenu.XML ~
W3dMenu.Open W3dNetTool.XML ~
W3dMenu.Open W3dPersonal.XML ~
System.Free W3dMenu ~

Compiler.Compile \s W3dVectors.Mod W3dMatrix.Mod W3dGeometry.Mod W3dAbstractWorld.Mod W3dObjectGenerator.Mod
W3dRasterizer.Mod W3dWorld.Mod W3dExplorer.Mod W3dClusterWatch.Mod W3dMenu.Mod~

oberon.bmp objecttracker.bmp networktracker.bmp launcher.bmp tetris.bmp iconvnc.bmp iconhome.bmp iconreload.bmp
iconbones.bmp iconbunny.bmp iconfrog.bmp iconfire.bmp iconfun.bmp iconmemory.bmp iconnettools.bmp iconkeycode.bmp
iconxml.bmp

PC.Compile \s TFVectors.Mod TFMatrix.Mod TFGeometry.Mod TFAbstractWorld.Mod TFObjectGenerator.Mod
Float.TFRasterizer3d.Mod TFWorld3d.Mod TFExplorer.Mod Menu3d.Mod ~
~

System.Free W3dMenu W3dWorld W3dRasterizer W3dObjectGenerator W3dAbstractWorld W3dGeometry W3dMatrix W3dVectors~

EditTools.OpenAscii W3dFun.XML ~
EditTools.OpenAscii W3dMenu.XML ~
EditTools.OpenAscii W3dNetTools.XML ~
EditTools.OpenAscii W3dPersonal.XML ~