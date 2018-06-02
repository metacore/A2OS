MODULE W3dClusterWatch;	(** AUTHOR "TF"; PURPOSE "Simple 3d viewer"; *)


IMPORT
(* Low level *)
	KernelLog, Kernel, MathL, Streams, Modules, Files, Commands,
	Strings,
(* Window Manager *)
	WM := WMWindowManager, Rect := WMRectangles, Raster, WMGraphics,
(* Network *)
	 IP, DNS, TCP,
(* 3d framework *)
	Classes := TFClasses, Vectors := W3dVectors, Matrix := W3dMatrix,
	AbstractWorld := W3dAbstractWorld, World := W3dWorld, ObjectGenerator := W3dObjectGenerator,
(* XML framework *)
	XML, Scanner := XMLScanner, XMLParser, Objects := XMLObjects;

CONST CATPort = 9999;
	NoCAT = 0;
	AosCAT = 1;
	LinuxCAT = 2;
	WindowsCAT = 3;
	SuseCAT = 4;
	UnknownCAT = 5;

	BoxDistance = 250;

VAR OSColor : ARRAY 6 OF LONGINT;
	OSImg : ARRAY 6 OF Raster.Image;

TYPE
	UpdateProc = PROCEDURE {DELEGATE};
	Info = OBJECT
	VAR
		pos : Vectors.TVector3d;
		host : ARRAY 64 OF CHAR;
		os, oldos : ARRAY 32 OF CHAR;
		load : ARRAY 32 OF CHAR;
		running, oldrunning : LONGINT;
		obj : AbstractWorld.Object;
		timer : Kernel.Timer;
		interval : LONGINT;
		world : AbstractWorld.World;
		connection : TCP.Connection;

		alive : BOOLEAN;

		index : LONGINT;

		render : UpdateProc;

		PROCEDURE &Init*(world : AbstractWorld.World; pos : Vectors.TVector3d; host : ARRAY OF CHAR; interval : LONGINT;
			update: UpdateProc);
		BEGIN
			COPY(host, SELF.host); SELF.pos := pos; SELF.world := world; SELF.interval := interval; SELF.render := update;
			NEW(timer)
		END Init;

		PROCEDURE RefreshInfo(host: ARRAY OF CHAR; VAR osName, osLoad: ARRAY OF CHAR) : BOOLEAN;
		VAR res: WORD;
			fip: IP.Adr;
			in : Streams.Reader;
			out : Streams.Writer;
		BEGIN
			NEW(connection);
			DNS.HostByName(host, fip, res);
			IF res # 0 THEN RETURN FALSE END;
			connection.Open(TCP.NilPort, fip, CATPort, res);
			IF res # 0 THEN connection.Close; RETURN FALSE END;
			Streams.OpenReader(in, connection.Receive); Streams.OpenWriter(out, connection.Send);
			(* query os *)
			out.String("getOS"); out.Ln; out.Update; in.Ln(osName);
			(* query load *)
			out.String("getLoad"); out.Ln; out.Update; in.Ln(osLoad);

			IF connection # NIL THEN connection.Close END;
			RETURN in.res = 0
		END RefreshInfo;

		PROCEDURE Update;
		BEGIN
			IF RefreshInfo(host, os, load) THEN
				IF MatchI(os, "Aos") THEN running := AosCAT
				ELSIF MatchI(os, "Linux") OR MatchI(os, "RH_Linux") THEN running := LinuxCAT
				ELSIF MatchI(os, "WinNT") THEN running := WindowsCAT
				ELSIF MatchI(os, "SUSE") THEN running := SuseCAT
				ELSE running := UnknownCAT; KernelLog.String("FAH : "); KernelLog.String(os); KernelLog.Ln;
				END
			ELSE running := NoCAT
			END;

			IF running # oldrunning THEN
				IF obj = NIL THEN obj := world.CreateObject(); obj.SetIndex(index); world.AddObject(obj) END; obj.Clear;

				IF OSImg[running] # NIL THEN
					ObjectGenerator.TexBox(Matrix.Translation4x4(pos.x, pos.y, pos.z),
							100, 100, 100, obj, OSColor[running], obj.AddTexture(OSImg[running]));
				ELSE
					ObjectGenerator.Box(Matrix.Translation4x4(pos.x, pos.y, pos.z),
							100, 100, 100, obj, OSColor[running]);
				END;
				oldrunning := running;
				render
			END
		END Update;

		PROCEDURE Kill;
		BEGIN
			alive := FALSE;
			IF connection # NIL THEN connection.Close END;
			timer.Wakeup
		END Kill;

	BEGIN {ACTIVE}
		oldrunning := -1;
		alive := TRUE;
		WHILE alive DO
			Update;
			IF alive THEN timer.Sleep(interval) END
		END;
	END Info;

	Window = OBJECT ( WM.BufferWindow )
		VAR
			alive, dead:BOOLEAN;
			timer : Kernel.Timer;
			interval : LONGINT;

			(* Navigation *)
			lookat: Vectors.TVector3d;
			radius, angle, height : LONGREAL;
			mouseKeys : SET;
			oldX, oldY : LONGINT;

			(* 3d World *)
			world : World.World;
			mx, my, mz : LONGREAL;

			infoList : Classes.List;
			index : LONGINT;

		PROCEDURE ParseLine(line : XML.Element; pos: Vectors.TVector3d);
		VAR cont : Objects.Enumerator; p : ANY; el : XML.Element;s : Strings.String;
			x: Info;
		BEGIN
			cont := line.GetContents(); cont.Reset();
			WHILE cont.HasMoreElements() DO
				p := cont.GetNext();
				el := p(XML.Element);
				s := el.GetName(); IF s^ = "Entry" THEN
					s := el.GetAttributeValue("Host");
					NEW(x, world, pos, s^, interval, Render); x.index := index; INC(index); w.infoList.Add(x);
					x.pos := pos; mx := Max(pos.x, mx);
					pos.x := pos.x + BoxDistance
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
					ParseLine(el, pos); mz := Max(pos.z, mz);
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
		BEGIN
			index := 1;
			f := Files.Old(filename);
			IF f # NIL THEN
				NEW(reader, f, 0);
				NEW(scanner, reader); NEW(parser, scanner); doc := parser.Parse()
			END;

			root := doc.GetRoot();
			cont := root.GetContents(); cont.Reset();
			WHILE cont.HasMoreElements() DO
				p := cont.GetNext();
				el := p(XML.Element);
				IF el IS XML.Element THEN
					s := el(XML.Element).GetName(); IF s^ = "Layer" THEN
						ParseLayer(el(XML.Element), pos); my := Max(pos.z, my);
						pos.y := pos.y + BoxDistance;
					END
				END
			END;
			lookat := Vectors.Vector3d(mx / 2, my / 2, mz / 2)
		END Load;

		PROCEDURE &New*(interval: LONGINT; fileName: ARRAY OF CHAR);
		VAR xpos, ypos : LONGINT;
				w, h : LONGINT;
		BEGIN
			w := 400; h := 400;
			xpos := 20; ypos := 30;
			Init(w, h, FALSE);

			SELF.interval := interval;
			manager := WM.GetDefaultManager();
			manager.Add(xpos, ypos, SELF, {WM.FlagFrame});
			manager.SetWindowTitle(SELF, WM.NewString("Cluster Watch 3d"));

			(* Init navigation parameters *)
			radius := 2000; angle := 0; height := 0;

			(* Setup the 3d World *)
			NEW(world, w, h, 0);
			world.quality := 1;
			NEW(infoList);
			Load(fileName);

			(* Background box *)
			NEW(timer)
		END New;

		PROCEDURE Close*;
		VAR i : LONGINT; o : ANY; info : Info;
		BEGIN {EXCLUSIVE}
			infoList.Lock;
			FOR i := 0 TO infoList.GetCount() - 1 DO o := infoList.GetItem(i); info := o(Info); info.Kill END;
			infoList.Unlock;
			infoList.Clear;
			manager.Remove(SELF);
			(*alive:=FALSE; timer.Wakeup *)
		END Close;

		(* BEGIN Navigation and Rendering *)
		PROCEDURE Render;
		VAR pos, dir, up : Vectors.TVector3d;
		BEGIN {EXCLUSIVE}
			pos := Vectors.VAdd3(lookat, Vectors.Vector3d(MathL.cos(angle) * radius, 0, MathL.sin(angle) * radius)); pos.y := height;
			lookat := Vectors.Vector3d(lookat.x, height, lookat.z);
			dir := Vectors.VNormed3(Vectors.VSub3(lookat, pos));
			up := Vectors.Vector3d(0, 1, 0);
			world.SetCamera(pos, dir, up); world.Render(img, FALSE);
			Invalidate(Rect.MakeRect(0,0,img.width, img.height))
		END Render;

		PROCEDURE PointerDown*(x, y:LONGINT; keys:SET);
		BEGIN
			mouseKeys := (keys * {0, 1, 2});
			oldX := x; oldY := y;
			IF mouseKeys = {1} THEN
				KernelLog.Int(world.GetOwnerIndex(x, y), 8); KernelLog.Ln
			END
		END PointerDown;

		PROCEDURE PointerMove*(x, y: LONGINT; keys : SET);
		BEGIN
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

		PROCEDURE PointerUp*(x, y:LONGINT; keys:SET);
		BEGIN
			mouseKeys := (keys * {0, 1, 2});
		END PointerUp;
		(* END Navigation and Rendering *)
	END Window;

VAR
	w: Window;
	timg: Raster.Image;
	mode : Raster.Mode;

	PROCEDURE MatchI(VAR buf: ARRAY OF CHAR; with: ARRAY OF CHAR): BOOLEAN;
	VAR i: LONGINT;
	BEGIN
		i := 0; WHILE (with[i] # 0X) & (CAP(buf[i]) = CAP(with[i])) DO INC(i) END;
		RETURN with[i] = 0X
	END MatchI;

PROCEDURE Watch*(context : Commands.Context);
VAR
	name : ARRAY 100 OF CHAR;
	i, interval : LONGINT;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(name);
	(* steps *)
	context.arg.SkipWhitespace; context.arg.Int(interval, FALSE);
	IF interval = 0 THEN interval := 30000; END;
	NEW(w, interval, name);
END Watch;

PROCEDURE Cleanup;
END Cleanup;

PROCEDURE Max(a, b: LONGREAL):LONGREAL;
BEGIN IF a > b THEN RETURN a ELSE RETURN b END
END Max;

BEGIN
	timg := WMGraphics.LoadImage("W3dClusterWatchIcons.tar://tux.bmp", TRUE);
	IF timg # NIL THEN
		NEW(OSImg[LinuxCAT]); Raster.Create(OSImg[LinuxCAT], timg.width, timg.height, Raster.BGR565);
		Raster.InitMode(mode, Raster.srcCopy);
		Raster.Copy(timg, OSImg[LinuxCAT], 0, 0, timg.width, timg.height, 0, 0, mode)
	END;

	timg := WMGraphics.LoadImage("W3dClusterWatchIcons.tar://windows.bmp", TRUE);
	IF timg # NIL THEN
		NEW(OSImg[WindowsCAT]); Raster.Create(OSImg[WindowsCAT], timg.width, timg.height, Raster.BGR565);
		Raster.InitMode(mode, Raster.srcCopy);
		Raster.Copy(timg, OSImg[WindowsCAT], 0, 0, timg.width, timg.height, 0, 0, mode)
	END;

	timg := WMGraphics.LoadImage("W3dClusterWatchIcons.tar://aos.gif", TRUE);
	IF timg # NIL THEN
		NEW(OSImg[AosCAT]); Raster.Create(OSImg[AosCAT], timg.width, timg.height, Raster.BGR565);
		Raster.InitMode(mode, Raster.srcCopy);
		Raster.Copy(timg, OSImg[AosCAT], 0, 0, timg.width, timg.height, 0, 0, mode)
	END;

	timg := WMGraphics.LoadImage("W3dClusterWatchIcons.tar://suse.bmp", TRUE);
	IF timg # NIL THEN
		NEW(OSImg[SuseCAT]); Raster.Create(OSImg[SuseCAT], timg.width, timg.height, Raster.BGR565);
		Raster.InitMode(mode, Raster.srcCopy);
		Raster.Copy(timg, OSImg[SuseCAT], 0, 0, timg.width, timg.height, 0, 0, mode)
	END;

	timg := WMGraphics.LoadImage("W3dClusterWatchIcons.tar://nocat.bmp", TRUE);
	IF timg # NIL THEN
		NEW(OSImg[NoCAT]); Raster.Create(OSImg[NoCAT], timg.width, timg.height, Raster.BGR565);
		Raster.InitMode(mode, Raster.srcCopy);
		Raster.Copy(timg, OSImg[NoCAT], 0, 0, timg.width, timg.height, 0, 0, mode)
	END;

	timg := WMGraphics.LoadImage("W3dClusterWatchIcons.tar://unknowncat.bmp", TRUE);
	IF timg # NIL THEN
		NEW(OSImg[UnknownCAT]); Raster.Create(OSImg[UnknownCAT], timg.width, timg.height, Raster.BGR565);
		Raster.InitMode(mode, Raster.srcCopy);
		Raster.Copy(timg, OSImg[UnknownCAT], 0, 0, timg.width, timg.height, 0, 0, mode)
	END;

	OSColor[NoCAT] := 0AAAAAAH; OSColor[AosCAT] := 0FF0000H; OSColor[LinuxCAT] := 0FFFF00H;
	OSColor[WindowsCAT] := 008080H; OSColor[SuseCAT] := 0FFH; OSColor[UnknownCAT] := 0FFFFFFH;
	Modules.InstallTermHandler(Cleanup)
END W3dClusterWatch.


Aos.Call W3dClusterWatch.Watch Cluster.XML 60000~

Compiler.Compile \s TFVectors.Mod TFMatrix.Mod TFGeometry.Mod TFAbstractWorld.Mod TFObjectGenerator.Mod
Float.TFRasterizer3d.Mod TFWorld3d.Mod TFExplorer.Mod ClusterWatch3d.Mod~

PC.Compile \s TFVectors.Mod TFMatrix.Mod TFGeometry.Mod TFAbstractWorld.Mod TFObjectGenerator.Mod
Float.TFRasterizer3d.Mod TFWorld3d.Mod TFExplorer.Mod ClusterWatch3d.Mod ~
~

System.Free W3dClusterWatch W3dWorld W3dRasterizer W3dObjectGenerator W3dAbstractWorld W3dGeometry W3dMatrix W3dVectors~

(* FILES *)
Cluster.XML ClusterWatch3d.Mod TFAbstractWorld.Mod TFWorld3d.Mod TFObjectGenerator.Mod

EditTools.OpenUnix Cluster.XML~