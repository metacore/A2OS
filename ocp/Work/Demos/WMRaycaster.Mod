MODULE WMRaycaster; (** AUTHOR "Yaroslav Romanchenko (SAGE)"; PURPOSE "Lode's Computer Graphics Raycasting Tutorial ported to Active Oberon. Raycasting III: Sprites"; *)

IMPORT
	SYSTEM, PrecisionTimer, Modules, Inputs, Strings, Commands, Raster, Files, Math, Machine,
	Float32Collections := GenericCollections(FLOAT32, Float32Less),
	WMWindowManager, Graphics := WMGraphics, Rectangles := WMRectangles, WMDialogs;

CONST
	SCREEN_WIDTH = 1280;
	SCREEN_HEIGHT = 720;

	MOVE_SPEED = 2.5;	(* m/sec *)
	ROTATE_SPEED = 1; (* rad/sec *)

	DATA_FILE = "WMRaycaster.zip";
	DATA_PATH = "pics/";

	MAP_HEIGHT = LEN(worldMap, 0);
	MAP_WIDTH = LEN(worldMap, 1);

	worldMap =
		[
			[8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 4, 4, 6, 4, 4, 6, 4, 6, 4, 4, 4, 6, 4],
			[8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4],
			[8, 0, 3, 3, 0, 0, 0, 0, 0, 8, 8, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6],
			[8, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6],
			[8, 0, 3, 3, 0, 0, 0, 0, 0, 8, 8, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4],
			[8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 4, 0, 0, 0, 0, 0, 6, 6, 6, 0, 6, 4, 6],
			[8, 8, 8, 8, 0, 8, 8, 8, 8, 8, 8, 4, 4, 4, 4, 4, 4, 6, 0, 0, 0, 0, 0, 6],
			[7, 7, 7, 7, 0, 7, 7, 7, 7, 0, 8, 0, 8, 0, 8, 0, 8, 4, 0, 4, 0, 6, 0, 6],
			[7, 7, 0, 0, 0, 0, 0, 0, 7, 8, 0, 8, 0, 8, 0, 8, 8, 6, 0, 0, 0, 0, 0, 6],
			[7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 6, 0, 0, 0, 0, 0, 4],
			[7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 6, 0, 6, 0, 6, 0, 6],
			[7, 7, 0, 0, 0, 0, 0, 0, 7, 8, 0, 8, 0, 8, 0, 8, 8, 6, 4, 6, 0, 6, 6, 6],
			[7, 7, 7, 7, 0, 7, 7, 7, 7, 8, 8, 4, 0, 6, 8, 4, 8, 3, 3, 3, 0, 3, 3, 3],
			[2, 2, 2, 2, 0, 2, 2, 2, 2, 4, 6, 4, 0, 0, 6, 0, 6, 3, 0, 0, 0, 0, 0, 3],
			[2, 2, 0, 0, 0, 0, 0, 2, 2, 4, 0, 0, 0, 0, 0, 0, 4, 3, 0, 0, 0, 0, 0, 3],
			[2, 0, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 4, 3, 0, 0, 0, 0, 0, 3],
			[1, 0, 0, 0, 0, 0, 0, 0, 1, 4, 4, 4, 4, 4, 6, 0, 6, 3, 3, 0, 0, 0, 3, 3],
			[2, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 1, 2, 2, 2, 6, 6, 0, 0, 5, 0, 5, 0, 5],
			[2, 2, 0, 0, 0, 0, 0, 2, 2, 2, 0, 0, 0, 2, 2, 0, 5, 0, 5, 0, 0, 0, 5, 5],
			[2, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 2, 5, 0, 5, 0, 5, 0, 5, 0, 5],
			[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5],
			[2, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 2, 5, 0, 5, 0, 5, 0, 5, 0, 5],
			[2, 2, 0, 0, 0, 0, 0, 2, 2, 2, 0, 0, 0, 2, 2, 0, 5, 0, 5, 0, 0, 0, 5, 5],
			[2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 5, 5, 5, 5, 5, 5, 5, 5, 5]
		];

	SpriteX = 0;
	SpriteY = 1;
	SpriteTexture = 2;

	(** Sprites: x pos, y pos, texture num *)
	sprites =
		[
			(** green light in front of playerstart *)
			[20.5, 11.5, 10],

			(** devil *)
			[20.0, 11.0, 11],

			(** green lights in every room *)
			[18.5, 4.5, 10],
			[10.0, 4.5, 10],
			[10.0, 12.5, 10],
			[3.5, 6.5, 10],
			[3.5, 20.5, 10],
			[3.5, 14.5, 10],
			[14.5, 20.5, 10],

			(** row of pillars in front of wall: fisheye test *)
			[18.5, 10.5, 9],
			[18.5, 11.5, 9],
			[18.5, 12.5, 9],

			(** some barrels around the map *)
			[21.5, 1.5, 8],
			[15.5, 1.5, 8],
			[16.0, 1.8, 8],
			[16.2, 1.2, 8],
			[3.5,  2.5, 8],
			[9.5, 15.5, 8],
			[10.0, 15.1, 8],
			[10.5, 15.8, 8]
		];

	numSprites = LEN(sprites, 0);

	(** parameters for scaling and moving the sprites *)
	uDiv = 1.0;
	vDiv = 1.0;
	vMove = 0.0;

	ceilingTexture = 6;
	floorTexture = 3;

TYPE
	Texture = RECORD
		width, height: SIZE;
		bSprite: BOOLEAN; (* texture is sprite *)
		pixels: POINTER TO ARRAY OF Raster.Pixel;
		pixelsDark: POINTER TO ARRAY OF Raster.Pixel;
		mask: POINTER TO ARRAY OF BOOLEAN;
	END;

	TextureArray = POINTER TO ARRAY OF Texture;

	TimeMeasUnit = ENUM Seconds, Milliseconds END;

	FPSCounter = OBJECT
	CONST
		AVG_WND_LEN = 10;
	VAR
		measUnit: TimeMeasUnit;
		iAvgWndLen: UNSIGNED16;
		fifo: Float32Collections.DEQue;
		fSum, fAvgTime: FLOAT32;

		PROCEDURE &New(measUnit: TimeMeasUnit; iAvgWndLen: UNSIGNED16);
		BEGIN
			SELF.measUnit := measUnit;
			IF iAvgWndLen <= 1 THEN
				SELF.iAvgWndLen := AVG_WND_LEN
			ELSE
				SELF.iAvgWndLen := iAvgWndLen
			END;
			NEW(fifo);
			fSum := 0.0;
			fAvgTime := 0.0
		END New;

		PROCEDURE AddTimeMeasure(fTime: FLOAT32);
		BEGIN
			fifo.Push(fTime);
			IF fifo.Count() <= iAvgWndLen THEN
				fSum := fSum + fTime
			ELSE
				VAR fTimeFirst := 0.0 : FLOAT32;
				IGNORE fifo.Pop(fTimeFirst);
				fSum := fSum - fTimeFirst + fTime
			END;
			fAvgTime := fSum / fifo.Count()
		END AddTimeMeasure;

		PROCEDURE GetAverageFrameTime(): FLOAT32;
		BEGIN
			RETURN fAvgTime
		END GetAverageFrameTime;

		PROCEDURE GetAverageFPS(): FLOAT32;
		BEGIN
			CASE measUnit OF
				TimeMeasUnit.Seconds: RETURN 1 / fAvgTime;
			|	TimeMeasUnit.Milliseconds: RETURN 1000 / fAvgTime;
			ELSE
				RETURN 1 / fAvgTime
			END
		END GetAverageFPS;

	END FPSCounter;

	RenderThread = OBJECT
	VAR
		w: RaycasterWindow;
		bucket, iXStart, iXEnd: SIGNED32;
		suspend: BOOLEAN;

		PROCEDURE &New(w: RaycasterWindow);
		BEGIN
			SELF.w := w
		END New;

		PROCEDURE Render;
		VAR
			cameraX, (** x-coordinate in camera space *)
			rayDirX, rayDirY,
			sideDistX, sideDistY, (** length of ray from current position to next x or y-side *)
			deltaDistX, deltaDistY,
			perpWallDist,
			wallX, (** where exactly the wall was hit *)
			floorXWall, floorYWall, (** x, y position of the floor texel at the bottom of the wall *)
			distWall, weight,
			currentFloorX, currentFloorY,
			rayDirX2, rayDirY2: FLOAT32;
			mapX, mapY,
			stepX, stepY, (** what direction to step in x or y-direction (either +1 or -1) *)
			side, (** was a NS or a EW wall hit? *)
			lineHeight, drawStart, drawEnd, texNum, d: SIGNED32;
			texWidth, texHeight, texX: SIZE;
			pixelOffset, floorPixelOffset, ceilingPixelOffset,
			x, y: SIGNED32;
		BEGIN
			FOR x := iXStart TO iXEnd DO

				(** calculate ray position and direction *)
				cameraX := 2 * x / SCREEN_WIDTH - 1;
				rayDirX := w.dirX + w.planeX * cameraX;
				rayDirY := w.dirY + w.planeY * cameraX;

				(** which box of the map we're in *)
				mapX := ENTIER(w.posX);
				mapY := ENTIER(w.posY);

				(** length of ray from one x or y-side to next x or y-side *)
				rayDirX2 := rayDirX * rayDirX;
				rayDirY2 := rayDirY * rayDirY;
				deltaDistX := Math.sqrt(1 + rayDirY2 / rayDirX2);
				deltaDistY := Math.sqrt(1 + rayDirX2 / rayDirY2);

				(** calculate step and initial sideDist *)
				IF rayDirX < 0 THEN
					stepX := -1;
					sideDistX := (w.posX - mapX) * deltaDistX
				ELSE
					stepX := 1;
					sideDistX := (mapX + 1.0 - w.posX) * deltaDistX
				END;
				IF rayDirY < 0 THEN
					stepY := -1;
					sideDistY := (w.posY - mapY) * deltaDistY;
				ELSE
					stepY := 1;
					sideDistY := (mapY + 1.0 - w.posY) * deltaDistY;
				END;

				(** perform DDA *)
				(** Check if ray has hit a wall *)
				REPEAT
					(** jump to next map square, OR in x-direction, OR in y-direction *)
					IF sideDistX < sideDistY THEN
						sideDistX := sideDistX + deltaDistX;
						INC(mapX, stepX);
						side := 0
					ELSE
						sideDistY := sideDistY + deltaDistY;
						INC(mapY, stepY);
						side := 1
					END
				UNTIL worldMap[mapX, mapY] > 0;

				(** Calculate distance of perpendicular ray (calculate distance projected on camera direction) (oblique distance will give fisheye effect!) *)
				(** calculate value of wallX *)
				IF side = 0 THEN
					perpWallDist := (mapX - w.posX + (1 - stepX) / 2) / rayDirX;
					wallX := w.posY + perpWallDist * rayDirY
				ELSE
					perpWallDist := (mapY - w.posY + (1 - stepY) / 2) / rayDirY;
					wallX := w.posX + perpWallDist * rayDirX
				END;
				perpWallDist := ABS(perpWallDist);
				wallX := wallX - ENTIER(wallX);

				(** Calculate height of line to draw on screen *)
				lineHeight := ENTIER(SCREEN_HEIGHT / perpWallDist);

				(** calculate lowest and highest pixel to fill in current stripe *)
				drawStart := -(lineHeight DIV 2) + SCREEN_HEIGHT DIV 2;
				IF drawStart < 0 THEN drawStart := 0 END;
				drawEnd := lineHeight DIV 2 + SCREEN_HEIGHT DIV 2 - 1;
				IF drawEnd >= SCREEN_HEIGHT THEN drawEnd := SCREEN_HEIGHT - 1 END;

				(** texturing calculations *)
				texNum := worldMap[mapX, mapY] - 1; (** 1 subtracted from it so that texture 0 can be used! *)
				texWidth := w.textures[texNum].width;
				texHeight := w.textures[texNum].height;

				(** x coordinate on the texture *)
				texX := ENTIER(wallX * texWidth);
				IF ((side = 0) & (rayDirX > 0)) OR ((side = 1) & (rayDirY < 0)) THEN
					texX := texWidth - texX - 1
				END;

				d := -(SCREEN_HEIGHT DIV 2) + lineHeight DIV 2;
				pixelOffset := SCREEN_WIDTH * 4 * drawStart + x * 4;
				FOR y := drawStart TO drawEnd DO
					IF side = 1 THEN
						SYSTEM.PUT32(ADDRESSOF(w.bufferPixels[pixelOffset]) ,
							SYSTEM.VAL(SIGNED32, w.textures[texNum].pixelsDark[texWidth * (((y + d) * texHeight) DIV lineHeight) + texX]))
					ELSE
						SYSTEM.PUT32(ADDRESSOF(w.bufferPixels[pixelOffset]),
							SYSTEM.VAL(SIGNED32, w.textures[texNum].pixels[texWidth * (((y + d) * texHeight) DIV lineHeight) + texX]))
					END;
					INC(pixelOffset, SCREEN_WIDTH * 4)
				END;

				(** SET THE ZBUFFER FOR THE SPRITE CASTING *)
				w.ZBuffer[x] := perpWallDist; (** perpendicular distance is used *)

				(** FLOOR CASTING *)

				(** 4 different wall directions possible *)
				IF (side = 0) & (rayDirX > 0) THEN
					floorXWall := mapX;
					floorYWall := mapY + wallX
				ELSIF (side = 0) & (rayDirX < 0) THEN
					floorXWall := mapX + 1.0;
					floorYWall := mapY + wallX
				ELSIF(side = 1) & (rayDirY > 0) THEN
					floorXWall := mapX + wallX;
					floorYWall := mapY
				ELSE
					floorXWall := mapX + wallX;
					floorYWall := mapY + 1.0
				END;

				distWall := perpWallDist;
				w.distPlayer := 0.0;

				(** draw the floor from drawEnd to the bottom of the screen *)
				floorPixelOffset := SCREEN_WIDTH * 4 * (drawEnd + 1) + x * 4;
				ceilingPixelOffset := SCREEN_WIDTH * 4 * (SCREEN_HEIGHT - drawEnd - 2) + x * 4;
				FOR y := drawEnd + 1 TO SCREEN_HEIGHT - 1 DO
					weight := (w.currentDistLookUp[y] - w.distPlayer) / (perpWallDist - w.distPlayer);
					currentFloorX := weight * floorXWall + (1.0 - weight) * w.posX;
					currentFloorY := weight * floorYWall + (1.0 - weight) * w.posY;
					(** floor *)
					SYSTEM.PUT32(ADDRESSOF(w.bufferPixels[floorPixelOffset]),
						SYSTEM.VAL(SIGNED32, w.textures[floorTexture].pixelsDark[w.floorTexWidth * (ENTIER(currentFloorY * w.floorTexHeight) MOD w.floorTexHeight) +
							(ENTIER(currentFloorX * w.floorTexWidth) MOD w.floorTexWidth)]));
					INC(floorPixelOffset, SCREEN_WIDTH * 4);
					(** ceiling (symmetrical!) *)
					SYSTEM.PUT32(ADDRESSOF(w.bufferPixels[ceilingPixelOffset]),
						SYSTEM.VAL(SIGNED32, w.textures[ceilingTexture].pixels[w.ceilingTexWidth * (ENTIER(currentFloorY * w.ceilingTexHeight) MOD w.ceilingTexHeight) +
							(ENTIER(currentFloorX * w.ceilingTexWidth) MOD w.ceilingTexWidth)]));
					DEC(ceilingPixelOffset, SCREEN_WIDTH * 4)
				END
			END
		END Render;

	BEGIN {ACTIVE}

		WHILE w.active DO

			w.Render_GetNextBucket(bucket, suspend);

			IF ~suspend & (bucket < w.nBuckets) THEN

				iXStart := bucket * w.nBucketSizeX;
				iXEnd := MIN(iXStart + w.nBucketSizeX - 1, SCREEN_WIDTH - 1);

				Render

			END

		END;
		w.Render_DecActiveThreads

	END RenderThread;

	RaycasterWindow* = OBJECT(WMWindowManager.BufferWindow)
	VAR
		alpha: BOOLEAN;
		active, terminated, suspendRender: BOOLEAN;

		font: Graphics.Font;
		(** Lookup table for speedup *)
		textures: TextureArray;
		currentDistLookUp: ARRAY SCREEN_HEIGHT OF FLOAT32;
		bufferPixels: POINTER TO ARRAY OF CHAR;
		posX, posY: FLOAT32;  (** x and y start position *)
		dirX, dirY: FLOAT32; (** initial direction vector *)
		planeX, planeY: FLOAT32; (** the 2d raycaster version of camera plane *)

		fpsCounter: FPSCounter;
		floorTexWidth, floorTexHeight, ceilingTexWidth, ceilingTexHeight: SIZE;
		distPlayer: FLOAT32;

		(* The flag and time when player started some activity *)
		timeBeginActive, timeFrameStart: PrecisionTimer.Counter;

		(** 1D Zbuffer *)
		ZBuffer: ARRAY SCREEN_WIDTH OF FLOAT32;

		KeysBuffer : ARRAY 4 OF RECORD
			keysym: SIZE;
			flags: SET;
		END;

		nBuckets, nBucketSizeX, nBucketsComputed, nThreads, nActiveThreads: SIGNED32;
		threads: POINTER TO ARRAY OF RenderThread;

		PROCEDURE Render_GetNextBucket(VAR bucket: SIGNED32; VAR suspend: BOOLEAN);
		BEGIN {EXCLUSIVE}
			bucket := nBucketsComputed;
			INC(nBucketsComputed);
			suspend := suspendRender;
		END Render_GetNextBucket;

		PROCEDURE Render_DecActiveThreads;
		BEGIN {EXCLUSIVE}
			DEC(nActiveThreads)
		END Render_DecActiveThreads;

		PROCEDURE Terminate;
		BEGIN {EXCLUSIVE}
			nActiveThreads := nThreads;
			active := FALSE;
			suspendRender := TRUE;
			AWAIT(nActiveThreads = 0);
			AWAIT(terminated)
		END Terminate;

		PROCEDURE KeysBufferInit;
		BEGIN
			KeysBuffer[0].keysym := Inputs.KsLeft;
			KeysBuffer[1].keysym := Inputs.KsUp;
			KeysBuffer[2].keysym := Inputs.KsRight;
			KeysBuffer[3].keysym := Inputs.KsDown;
			VAR i := 0;
			FOR i := 0 TO LEN(KeysBuffer) - 1 DO
				KeysBuffer[i].flags := {Inputs.Release}
			END
		END KeysBufferInit;

		PROCEDURE SubdivideToBuckets;
		VAR
			N: SIGNED32;
		BEGIN
			(* Searching for best divisor of SCREEN_WIDTH *)
			N := 8;
			WHILE (N >= 1) & (SCREEN_WIDTH MOD N # 0) DO
				N := N DIV 2
			END;
			nBuckets := SCREEN_WIDTH DIV N;
			nBucketSizeX := N;
			context.out.String('Bucket size: ');
			context.out.Int(nBucketSizeX, 0);
			context.out.String(', number of buckets: ');
			context.out.Int(nBuckets, 0);
			context.out.Ln
		END SubdivideToBuckets;

		PROCEDURE &New(textures: TextureArray; alpha: BOOLEAN);
		VAR
			y: SIGNED32;
			manager: WMWindowManager.WindowManager;
		BEGIN

			nThreads := Machine.NumberOfProcessors();
			context.out.String('Number of threads: ');
			context.out.Int(nThreads, 0); context.out.Ln;
			threads := NIL;

			SubdivideToBuckets;

			active := TRUE;
			terminated := FALSE;
			suspendRender := TRUE;

			KeysBufferInit;

			SELF.textures := textures;
			SELF.alpha := alpha;
			posX := 22;
			posY := 11.5;
			dirX := -1;
			dirY := 0;
			planeX := 0;
			planeY := 0.66;
			FOR y := 0 TO SCREEN_HEIGHT - 1 DO
				currentDistLookUp[y] := SCREEN_HEIGHT / (2.0 * y - SCREEN_HEIGHT)
			END;
			NEW(bufferPixels, SCREEN_WIDTH * SCREEN_HEIGHT * 4);

			fpsCounter := NEW FPSCounter(TimeMeasUnit.Seconds, 100);

			Init(SCREEN_WIDTH, SCREEN_HEIGHT, alpha);
			VAR winPosX, winPosY: SIZE;
			WMDialogs.DefaultPos(winPosX, winPosY, SCREEN_WIDTH, SCREEN_HEIGHT);
			WMWindowManager.ExtAddWindow(SELF, winPosX, winPosY,
				{WMWindowManager.FlagFrame, WMWindowManager.FlagClose,
				WMWindowManager.FlagMinimize, WMWindowManager.FlagNoResizing});

			SetTitle(Strings.NewString("Textured raycaster with floor, ceiling and sprites"));

			canvas.SetColor(Graphics.White);
			font := canvas.GetFont();

			manager	 := WMWindowManager.GetDefaultManager();
			IF manager # NIL THEN
				manager.ToFront(SELF);
				manager.SetFocus(SELF)
			END

		END New;

		PROCEDURE Draw(canvas: Graphics.Canvas; w, h: SIZE; q: INTEGER);
		VAR
			str: ARRAY 30 OF CHAR;
			font: Graphics.Font;
			textWidth, textHeight, textPosY: SIZE;
		BEGIN
			Draw^(canvas, w, h, q);
			canvas.SetColor(Graphics.White);
			font := canvas.GetFont();
			Strings.FloatToStr(fpsCounter.GetAverageFPS(), 0, 1, 0, str);
			Strings.Concat("FPS:", str, str);
			font.GetStringSize(str, textWidth, textHeight);
			textPosY := textHeight + 4;
			canvas.DrawString(4, textPosY, str); INC(textPosY, textHeight);
			Strings.IntToStr(nThreads, str);
			Strings.Concat("Threads: ", str, str);
			canvas.DrawString(4, textPosY, str); INC(textPosY, textHeight);
		END Draw;

		PROCEDURE RenderFrame;
		BEGIN

			timeFrameStart := PrecisionTimer.GetCounter();

			floorTexWidth := textures[floorTexture].width;
			floorTexHeight := textures[floorTexture].height;
			ceilingTexWidth := textures[ceilingTexture].width;
			ceilingTexHeight := textures[ceilingTexture].height;

			IF threads = NIL THEN
				NEW(threads, nThreads);
				VAR iThread: SIGNED32;
				FOR iThread := 0 TO nThreads - 1 DO
					NEW(threads^[iThread], SELF)
				END;
			END;
			BEGIN {EXCLUSIVE}
				(* Restart computing of new frame *)
				nBucketsComputed := 0; suspendRender := FALSE;
				(* And wait of finishing *)
				AWAIT(~active OR (nBucketsComputed = nBuckets));
				suspendRender := TRUE
			END;

		END RenderFrame;

		PROCEDURE RenderSpites;
		VAR
			mode: Raster.Mode;

			(** arrays used to sort the sprites *)
			spriteOrder: ARRAY numSprites OF SIGNED32;
			spriteDistance: ARRAY numSprites OF FLOAT32;

			texX, texY: SIZE;
			d, spriteScreenX, vMoveScreen: SIGNED32;
			spritePixelOffset, texWidth, texHeight: SIZE;
			pixelOffset,
			spriteHeight, drawStartY, drawEndY,
			spriteWidth, drawStartX, drawEndX,
			stripe, y, i, iTexture: SIGNED32;

			spriteX, spriteY, invDet,
			transformX, transformY: FLOAT32;

		BEGIN

			distPlayer := 0.0;

			(** SPRITE CASTING *)

			(** sort sprites from far to close *)
			FOR i := 0 TO numSprites - 1 DO
				spriteOrder[i] := i;
				spriteDistance[i] := ((posX - sprites[i, SpriteX]) * (posX - sprites[i, SpriteX]) + (posY - sprites[i, SpriteY]) * (posY - sprites[i, SpriteY])); (** sqrt not taken, unneeded *)
			END;

			CombSort(spriteOrder, spriteDistance, numSprites);

			(** after sorting the sprites, do the projection and draw them *)
			FOR i := 0 TO numSprites - 1 DO
				iTexture := ENTIER(sprites[spriteOrder[i], SpriteTexture]);
				texWidth := textures[iTexture].width;
				texHeight := textures[iTexture].height;

				(** translate sprite position to relative to camera *)
				spriteX := sprites[spriteOrder[i], SpriteX] - posX;
				spriteY := sprites[spriteOrder[i], SpriteY] - posY;

				(** transform sprite with the inverse camera matrix *)
				(**  [ planeX   dirX ] -1                                       [ dirY      -dirX ] *)
				(**  [               ]       =  1/(planeX*dirY-dirX*planeY) *   [                 ] *)
				(**  [ planeY   dirY ]                                          [ -planeY  planeX ] *)

				invDet := 1.0 / (planeX * dirY - dirX * planeY); (** required for correct matrix multiplication *)
				transformX := invDet * (dirY * spriteX - dirX * spriteY);
				transformY := invDet * (-planeY * spriteX + planeX * spriteY); (** this is actually the depth inside the screen, that what Z is in 3D *)
				spriteScreenX := ENTIER((SCREEN_WIDTH / 2) * (1 + transformX / transformY));

				vMoveScreen := ENTIER(vMove / transformY);

				(** calculate height of the sprite on screen *)
				spriteHeight := ENTIER((SCREEN_HEIGHT / ABS(transformY)) / vDiv); (** using "transformY" instead of the real distance prevents fisheye *)
				d := -(SCREEN_HEIGHT DIV 2) + spriteHeight DIV 2;

				(** calculate lowest and highest pixel to fill in current stripe *)
				drawStartY := -(spriteHeight DIV 2) + SCREEN_HEIGHT DIV 2 + vMoveScreen;
				IF drawStartY < 0 THEN drawStartY := 0 END;
				drawEndY := spriteHeight DIV 2 + SCREEN_HEIGHT DIV 2 + vMoveScreen;
				IF drawEndY >= SCREEN_HEIGHT THEN drawEndY := SCREEN_HEIGHT - 1 END;

				(** calculate width of the sprite *)
				spriteWidth := ENTIER((SCREEN_HEIGHT / ABS(transformY)) / uDiv);
				drawStartX := -(spriteWidth DIV 2) + spriteScreenX;
				IF drawStartX < 0 THEN drawStartX := 0 END;
				drawEndX := spriteWidth DIV 2 + spriteScreenX;
				IF drawEndX >= SCREEN_WIDTH THEN drawEndX := SCREEN_WIDTH - 1 END;

				(** loop through every vertical stripe of the sprite on screen *)
				FOR stripe := drawStartX TO drawEndX - 1 DO
					texX := ENTIER(256 * (stripe - (-spriteWidth / 2 + spriteScreenX)) * texWidth / spriteWidth) DIV 256;
					(** the conditions in the if are: *)
					(** 1) it's in front of camera plane so you don't see things behind you *)
					(** 2) it's on the screen (left) *)
					(** 3) it's on the screen (right) *)
					(** 4) ZBuffer, with perpendicular distance *)
					IF (transformY > 0) & (stripe > 0) & (stripe < SCREEN_WIDTH) & (transformY < ZBuffer[stripe]) THEN
						(** for every pixel of the current stripe *)
						pixelOffset := SCREEN_WIDTH * 4 * drawStartY + stripe * 4;
						FOR y := drawStartY TO drawEndY - 1 DO
							texY := (((y - vMoveScreen + d) * texHeight) DIV spriteHeight);
							(** paint pixel if it isn't black, black is the invisible color *)
							spritePixelOffset := texWidth * texY + texX;
							IF textures[iTexture].mask[spritePixelOffset] THEN
								SYSTEM.PUT32(ADDRESSOF(bufferPixels[pixelOffset]),
									SYSTEM.VAL(SIGNED32, textures[iTexture].pixels[spritePixelOffset]))
							END;
							INC(pixelOffset, SCREEN_WIDTH * 4)
						END
					END
				END
			END;

			Raster.InitMode(mode, Raster.srcCopy);
			FOR y := 0 TO SCREEN_HEIGHT - 1 DO
				Raster.PutPixels(img, 0, y, SCREEN_WIDTH, Raster.BGRA8888, bufferPixels^, y * SCREEN_WIDTH * 4, mode)
			END;
			fpsCounter.AddTimeMeasure((PrecisionTimer.GetCounter() - timeFrameStart) / PrecisionTimer.GetFrequency());
			Invalidate(Rectangles.MakeRect(0, 0, GetWidth(), GetHeight()))

		END RenderSpites;

		PROCEDURE Close;
		BEGIN
			Terminate;
			Close^;
			window := NIL
		END Close;

		PROCEDURE Rotate(dx: SIGNED32);
		VAR
			fAngle, fSin, fCos: FLOAT32;
			oldDirX, oldPlaneX: FLOAT32;
			time: FLOAT32;
		BEGIN
			IF dx # 0 THEN
				time := (PrecisionTimer.GetCounter() - timeBeginActive) / PrecisionTimer.GetFrequency();
				fAngle := dx * ROTATE_SPEED * time;
				fSin := Math.sin(fAngle);
				fCos := Math.cos(fAngle);
				oldDirX := dirX;
				dirX := dirX * fCos - dirY * fSin;
				dirY := oldDirX * fSin + dirY * fCos;
				oldPlaneX := planeX;
				planeX := planeX * fCos - planeY * fSin;
				planeY := oldPlaneX * fSin + planeY * fCos;
				timeBeginActive := PrecisionTimer.GetCounter()
			END
		END Rotate;

		PROCEDURE Move(dy: SIGNED32);
		VAR
			fDist: FLOAT32;
			x, y: SIGNED32;
			time: FLOAT32;
		BEGIN
			IF dy # 0 THEN
				time := (PrecisionTimer.GetCounter() - timeBeginActive) / PrecisionTimer.GetFrequency();
				fDist := dy * MOVE_SPEED * time;
				x := ENTIER(posX + dirX * fDist);
				y := ENTIER(posY);
				IF (x >= 0) & (x < MAP_WIDTH) & (y >= 0) & (y < MAP_HEIGHT) & (worldMap[x, y] = 0) THEN
					posX := posX + dirX * fDist
				END;
				x := ENTIER(posX);
				y := ENTIER(posY + dirY * fDist);
				IF (x >= 0) & (x < MAP_WIDTH) & (y >= 0) & (y < MAP_HEIGHT) & (worldMap[x, y] = 0) THEN
					posY := posY + dirY * fDist
				END;
				timeBeginActive := PrecisionTimer.GetCounter()
			END
		END Move;

		PROCEDURE KeyEvent(ucs: SIZE; flags: SET; keysym: SIZE);
		VAR
			i: SIZE;
		BEGIN
			IF keysym = Inputs.KsEscape THEN
				Close
			ELSIF ~(Inputs.Release IN flags) & ((keysym = Inputs.KsShiftL) OR (keysym = Inputs.KsShiftR)) THEN
				(* If one of the Shift keys is pressed and one of the keys that
				  interesting for us is in pressed state, we should update its
				  Shift flag in the table *)
				FOR i := 0 TO LEN(KeysBuffer) - 1 DO
					IF ~(Inputs.Release IN KeysBuffer[i].flags) THEN
						CASE keysym OF
							Inputs.KsShiftL: INCL(KeysBuffer[i].flags, Inputs.LeftShift);
						|	Inputs.KsShiftR: INCL(KeysBuffer[i].flags, Inputs.RightShift)
						ELSE
						END
					END
				END
			ELSE
				IF Inputs.Release IN flags THEN
					(* If some button released, reset flags for all keys that we monitor, 
						because, we can't determine which key was released. At least, it works *)
					FOR i := 0 TO LEN(KeysBuffer) - 1 DO
						KeysBuffer[i].flags := {Inputs.Release}
					END
				ELSE
					(* Some key pressed, if one of keys that we monitor, copy flags to table *)
					FOR i := 0 TO LEN(KeysBuffer) - 1 DO
						IF (KeysBuffer[i].keysym = keysym) & (KeysBuffer[i].flags # flags) THEN
							timeBeginActive := PrecisionTimer.GetCounter();
							KeysBuffer[i].flags := flags
						END
					END
				END
			END
		END KeyEvent;

	BEGIN {ACTIVE}

		WHILE active DO
			VAR i := 0;
			FOR i := 0 TO LEN(KeysBuffer) - 1 DO
				IF ~(Inputs.Release IN KeysBuffer[i].flags) THEN
					CASE KeysBuffer[i].keysym OF
						Inputs.KsLeft: Rotate(1);
					|	Inputs.KsUp:
							(* This should work, because Inputs.Shift includes 
							  Inputs.LeftShift and Inputs.RightShift both *)
							IF KeysBuffer[i].flags * Inputs.Shift # {} THEN
								(** Run *)
								Move(3)
							ELSE
								Move(1)
							END;
					|	Inputs.KsRight: Rotate(-1);
					|	Inputs.KsDown: Move(-1)
					ELSE
					END
				END
			END;

			RenderFrame;
			RenderSpites

		END;

		BEGIN {EXCLUSIVE}
			terminated := TRUE
		END

	END RaycasterWindow;


VAR
	context: Commands.Context;
	window: RaycasterWindow;

	PROCEDURE Float32Less(f1, f2: FLOAT32): BOOLEAN;
	BEGIN
		RETURN f1 < f2
	END Float32Less;

	(** sort algorithm *)
	PROCEDURE CombSort(VAR order: ARRAY OF SIGNED32; VAR dist: ARRAY OF FLOAT32; amount: SIGNED32);
	VAR
		gap, i, j: SIGNED32;
		tmpOrder: SIGNED32;
		tmpDist: FLOAT32;
		swapped: BOOLEAN;
	BEGIN
		gap := amount;
		swapped := FALSE;
		WHILE (gap > 1) OR swapped DO
			(** shrink factor 1.3 *)
			gap := (gap * 10) DIV 13;
			IF (gap = 9) OR (gap = 10) THEN gap := 11 END;
			IF gap < 1 THEN gap := 1 END;
			swapped := FALSE;
			FOR i := 0 TO amount - gap - 1 DO
				j := i + gap;
				IF dist[i] < dist[j] THEN
					tmpDist := dist[i];
					dist[i] := dist[j];
					dist[j] := tmpDist;
					tmpOrder := order[i];
					order[i] := order[j];
					order[j] := tmpOrder;
					swapped := TRUE
				END
			END
		END
	END CombSort;

	PROCEDURE LoadTexture(CONST strPath, strName: ARRAY OF CHAR; VAR tex: Texture; bSprite: BOOLEAN): BOOLEAN;
	VAR
		image: Graphics.Image;
		bResult: BOOLEAN;
		mode: Raster.Mode;
		x, y, offset: SIZE;
		pixel: Raster.Pixel;
		strFullPath: ARRAY 256 OF CHAR;
	BEGIN
		bResult := FALSE;
		tex.bSprite := bSprite;
		Strings.Concat(strPath, strName, strFullPath);
		image := Graphics.LoadImage(strFullPath, FALSE);
		IF image # NIL THEN
			bResult := TRUE;
			tex.width := image.width;
			tex.height := image.height;
			NEW(tex.pixels, image.width * image.height);
			IF bSprite THEN
				NEW(tex.mask, image.width * image.height)
			ELSE
				NEW(tex.pixelsDark, image.width * image.height)
			END;
			Raster.InitMode(mode, Raster.srcCopy);
			FOR x := 0 TO tex.width - 1 DO
				FOR y := 0 TO tex.height - 1 DO
					Raster.Get(image, x, y, pixel, mode);
					offset := tex.width * y + x;
					tex.pixels[offset] := pixel;
					IF bSprite THEN
						tex.mask[offset] := ~((pixel[Raster.r] = 0X) & (pixel[Raster.g] = 0X) & (pixel[Raster.b] = 0X))
					ELSE
						tex.pixelsDark[offset][Raster.b] :=  CHR(ORD(pixel[Raster.b]) DIV 2);
						tex.pixelsDark[offset][Raster.g] :=  CHR(ORD(pixel[Raster.g]) DIV 2);
						tex.pixelsDark[offset][Raster.r] :=  CHR(ORD(pixel[Raster.r]) DIV 2);
						tex.pixelsDark[offset][Raster.a] :=  pixel[Raster.a]
					END
				END
			END
		END;
		RETURN bResult
	END LoadTexture;

	PROCEDURE TestCounter*(ctx: Commands.Context);
	VAR
		times := [35, 41, 23, 30, 33, 37, 45, 50, 48, 44, 41, 32, 30, 34] : ARRAY [*] OF FLOAT32;
		counter: FPSCounter;
		i: SIZE;
		str: ARRAY 32 OF CHAR;
	BEGIN
		counter := NEW FPSCounter(TimeMeasUnit.Milliseconds, 3);
		FOR i := 0 TO LEN(times, 0) - 1 DO
			counter.AddTimeMeasure(times[i]);
			Strings.FloatToStr(counter.GetAverageFrameTime(), 0, 1, 0, str); ctx.out.String(str);
			ctx.out.String(', FPS: ');
			Strings.FloatToStr(counter.GetAverageFPS(), 0, 1, 0, str); ctx.out.String(str);
			ctx.out.Ln;
		END
	END TestCounter;

	PROCEDURE WindowGenerator*(ctx: Commands.Context): WMWindowManager.Window;
	VAR
		texArchive: Files.File;
		bError: BOOLEAN;
		strPath: ARRAY 256 OF CHAR;
		textures: TextureArray;
	BEGIN
		IF window # NIL THEN RETURN NIL END;
		context := ctx;
		texArchive := Files.Old(DATA_FILE);
		bError := ~(texArchive # NIL);
		IF ~bError THEN
			context.out.String("Loading textures..."); context.out.Ln;
			Strings.Concat(DATA_FILE, "://", strPath);
			Strings.Concat(strPath, DATA_PATH, strPath);
			NEW(textures, 12);
			bError := bError OR ~LoadTexture(strPath, "eagle.png", textures[0], FALSE);
			bError := bError OR ~LoadTexture(strPath, "redbrick.png", textures[1], FALSE);
			bError := bError OR ~LoadTexture(strPath, "purplestone.png", textures[2], FALSE);
			bError := bError OR ~LoadTexture(strPath, "greystone.png", textures[3], FALSE);
			bError := bError OR ~LoadTexture(strPath, "bluestone.png", textures[4], FALSE);
			bError := bError OR ~LoadTexture(strPath, "mossy.png", textures[5], FALSE);
			bError := bError OR ~LoadTexture(strPath, "wood.png", textures[6], FALSE);
			bError := bError OR ~LoadTexture(strPath, "colorstone.png", textures[7], FALSE);
			IF ~bError THEN
				context.out.String("Loading sprite textures..."); context.out.Ln;
				bError := bError OR ~LoadTexture(strPath, "barrel.png", textures[8], TRUE);
				bError := bError OR ~LoadTexture(strPath, "pillar.png", textures[9], TRUE);
				bError := bError OR ~LoadTexture(strPath, "greenlight.png", textures[10], TRUE);
				bError := bError OR ~LoadTexture(strPath, "devil.png", textures[11], TRUE)
			END;
			IF ~bError THEN
				context.out.String("Textures loaded successfully"); context.out.Ln;
				NEW(window, textures, FALSE);
				RETURN window
			END
		ELSE
			context.out.String("Error: Textures package not found."); context.out.Ln;
		END;
		RETURN NIL
	END WindowGenerator;

	PROCEDURE Open*(ctx: Commands.Context);
	BEGIN
		IF window = NIL THEN
			IGNORE WindowGenerator(ctx)
		END
	END Open;

	PROCEDURE Cleanup;
	BEGIN
		IF window # NIL THEN
			window.Close
		END
	END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END WMRaycaster.

WMRaycaster.Open ~

WMRaycaster.TestCounter ~

System.Free WMRaycaster GenericCollections(@Float32,WMRaycaster_Float32Less) ~

