MODULE MediaPlayer; (** AUTHOR "PL/staubesv"; PURPOSE "Media Player"; *)
(**
 *
 * History:
 *
 *	15.02.2006	Set UpdateInterval to 500ms, optionally open player window in current view,
 *				added SetEofAction & EofHandler for testing purposes, improved closing behaviour (staubesv)
 *
 * TODOs:
 *	- 	reuse filler threads
 *	-	optimize filler threads seek procedure (first look at already decoded pictures before flushing them - maybe we can use them)
 *	-	Does the player need to be able to play standalone at all? (Remove GUI related code from module?)
 *	-	implement/finish drop frame mechanism
 *	- 	improve SetPos
 *	-	Don't change volume of audio play channels
 *	- 	USE same position info for both audio and video!!! (milliseconds)
 *)

IMPORT
	SoundDevices, Codecs, KernelLog, Streams, Commands, Kernel, Modules, WMTransitions,
	WMRectangles, WMGraphics, WMWindowManager, Raster, Strings;

CONST
	(* Result codes *)
	Ok* = 0;
	CouldNotOpenStream* = 1;	(* Could not open the specified ressource as stream *)
	AudioNotCompatible* = 2;	(* Audio decoder found but not compatible *)
	VideoNotCompatible* = 3;	(* Video decoder found but not compatible *)
	DemuxNotCompatible* = 4; 	(* Demultiplexer found but not compatible *)
	NoVideoDecoder* = 5;
	NoAudioDecoder* = 6;
	NoDecoders* = 7;
	WrongParameters* = 8;

	(**	Player States 											*)
	NotReady* = 1;		(* No files opened, not playing anything 	*)
	Ready* = 2;	 		(* Player is ready to play 				*)
	Playing* = 3;	 	(* Player is playing a video 				*)
	Paused* = 4;			(* Player is paused 						*)
	Stopped* = 5;		(* Player is stopped 					 	*)
	Stepping* = 6; 	(* Framewise stepping*)
	InTransition* = 7;	(* Transition between two videos 		*)
	Finished* = 9;		(* Finished video/audio					*)
	Closed* = 10;		(* Player has been closed 				*)
	Error* = 99;			(* Player is in error state 				*)

	(* Next state field *)
	NoRequest = 0;

	(* Audio buffers *)
	AudioBufferSize = 288;
	AudioBuffers = 160;
	AudioConstantDelay = 100; (* Guessed time from playchannel.Start until audio is played *)

	(* How many video frames may filler thread decode ahead? *)
	VBUFFERS = 10;

	(* Interval in millisecond when update is called (it is, however, always called when the state of the player changes *)
	UpdateInterval = 500;

	(* Should the player window be forced to be always fullscreen? *)
	ForceFullscreen = FALSE;

	(* Should the player window be forced to open in the default view? (Makes sense when operating over VNC) *)
	ForceDefaultView = FALSE;

	(* Time in milliseconds when pointer should disappear. 0 = Cursor always hidden *)
	PointerInvisibleAfter = 2000;

	(* Gather performance data. Will be displayed on kernel log each time a filler is closed (loaded other video / quit) *)
	PerformanceStats = FALSE;

	TraceNone = {};
	TracePlayer = {1};
	TraceOpen = {2};		(* Get new context 			*)
	TraceFiller = {3};			(* Video filler thread 		*)
	TraceTransitions = {4};	(* Video transitions 			*)
	TraceStates = {5}; 		(* Player states 				*)
	TraceRendering = {6}; 	(* Per frame rendering stats 	*)
	TraceEof = {7};			(* Trace calls to end of file handlers *)

	Trace = {2,4,5};

	Debug = TRUE;

TYPE
	(* video buffer *)
	VideoBuffer* = WMGraphics.Image;

	(* buffer pool for the video frames *)
	VideoBufferPool = OBJECT
	VAR
		head, num: SIZE;
		buffer: POINTER TO ARRAY OF VideoBuffer;

		PROCEDURE &Init*(n: SIZE);
		BEGIN
			head := 0; num := 0; NEW(buffer, n)
		END Init;

		PROCEDURE Add(x: VideoBuffer);
		BEGIN {EXCLUSIVE}
			AWAIT(num # LEN(buffer));
			buffer[(head+num) MOD LEN(buffer)] := x;
			INC(num)
		END Add;

		PROCEDURE Remove(): VideoBuffer;
		VAR x: VideoBuffer;
		BEGIN {EXCLUSIVE}
			AWAIT(num # 0);
			x := buffer[head];
			head := (head+1) MOD LEN(buffer);
			DEC(num);
			RETURN x
		END Remove;

		PROCEDURE NofBuffers(): SIZE;
		BEGIN {EXCLUSIVE}
			RETURN num
		END NofBuffers;

	END VideoBufferPool;

TYPE

	KeyEventHandler* = PROCEDURE {DELEGATE} (ucs : SIZE; flags : SET; keysym : SIZE);

	PointerDownHandler* = PROCEDURE {DELEGATE} (x, y : SIZE; keys : SET);

	(** default Player Window where the video is played *)
	PlayerWindow* =  OBJECT(WMWindowManager.DoubleBufferWindow)
	VAR
		player : Player;
		rect : WMRectangles.Rectangle;
		videoWidth, videoHeight : SIZE;

		(* Fullscreen functionality related *)
		fullscreen- : BOOLEAN;
		lastFrame : WMGraphics.Image;
		posX, posY : SIZE; (* Last window position in windowed-mode *)

		(* Pointer invisible functionality related *)
		timer : Kernel.Timer;
		lastTimestamp, timestamp : SIGNED32; (* Timemark when mouse pointer was moved last time *)

		(* External handlers for key/pointer events. CURRENTLY ACCESS IS NOT SYNCHRONIZED! *)
		extPointerDownHandler* : PointerDownHandler;
		extKeyEventHandler* : KeyEventHandler;

		(* Active object control *)
		alive, dead : BOOLEAN;

		PROCEDURE &New*(w, h : SIGNED32; alpha : BOOLEAN; player : Player; autoHideCursor : BOOLEAN);
		BEGIN
			SELF.player := player; videoWidth := w; videoHeight := h; posX := 100; posY := 100;
			rect := WMRectangles.MakeRect(0, 0, w, h);
			Init(w, h, alpha);
			manager := WMWindowManager.GetDefaultManager ();
			IF ForceDefaultView THEN
				manager.Add(posX, posY, SELF, {WMWindowManager.FlagFrame});
			ELSE
				WMWindowManager.AddWindow(SELF, posX, posY);
			END;
			manager.SetFocus(SELF);
			SetTitle(WMWindowManager.NewString("Video Panel"));
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://MediaPlayer.png", TRUE));
			IF autoHideCursor & (PointerInvisibleAfter > 0) THEN
				NEW(timer);
				alive := TRUE; dead := FALSE;
				SetPointerVisible(TRUE);
			ELSE
				alive := FALSE; dead := TRUE;
				SetPointerVisible(FALSE);
			END;
			fullscreen := FALSE;
		END New;

		(** Toggle between fullscreen and window mode *)
		PROCEDURE ToggleFullscreen*;
		VAR view : WMWindowManager.ViewPort; width, height : SIZE;
		BEGIN
			IF fullscreen THEN
				ReInit(videoWidth, videoHeight);
				manager.SetWindowSize(SELF, videoWidth, videoHeight);
				rect := WMRectangles.MakeRect(0, 0, videoWidth, videoHeight);
				manager.SetWindowPos(SELF, posX, posY);
				IF lastFrame # NIL THEN ShowFrame(lastFrame); END;
				fullscreen := FALSE;
			ELSE
				posX := bounds.l; posY := bounds.t;
				view := WMWindowManager.GetDefaultView();
				width := ENTIER(view.range.r - view.range.l);
				height := ENTIER(view.range.b - view.range.t);
				ReInit(width, height);
				manager.SetWindowSize(SELF, width, height);
				manager.SetWindowPos(SELF, ENTIER(view.range.l), ENTIER(view.range.t));
				rect := WMRectangles.MakeRect(0, 0, width, height);
				IF lastFrame # NIL THEN ShowFrame(lastFrame); END;
				fullscreen := TRUE;
			END;
		END ToggleFullscreen;

		(* Overwrite draw procedure because we do not want any interpolation *)
		PROCEDURE Draw*(canvas : WMGraphics.Canvas; w, h : SIZE; q : SIGNED32);
		BEGIN
			Draw^(canvas, w, h, 0);
		END Draw;

		PROCEDURE Close*;
		BEGIN
			player.Close;
			alive := FALSE; IF timer # NIL THEN timer.Wakeup; END;
			BEGIN {EXCLUSIVE} AWAIT(dead); END;
			Close^;
		END Close;

		(* Key Handler *)
		PROCEDURE KeyEvent*(ucs : SIZE; flags : SET; keysym : SIZE);
		BEGIN
			IF extKeyEventHandler # NIL THEN extKeyEventHandler(ucs, flags, keysym); END;
			IF keysym = 0FF50H THEN (* Cursor Home *)
				player.ToggleFullScreen(NIL, NIL)
			END;
		END KeyEvent;

		PROCEDURE ShowBlack*;
		VAR rect : WMRectangles.Rectangle;
		BEGIN
			Raster.Clear(img);
			Invalidate(rect);
		END ShowBlack;

		PROCEDURE ShowFrame*(frame : WMGraphics.Image);
		VAR s, d : WMRectangles.Rectangle; h, w : SIGNED32;
		BEGIN
			BEGIN {EXCLUSIVE} (* Don't execute the same time as SELF.ReInit does *)
				lastFrame := frame;
				IF (img.width = frame.width) & (img.height = frame.height) THEN
					canvas.DrawImage(0, 0, frame, WMGraphics.ModeCopy);
					d := WMRectangles.MakeRect(0, 0, img.width, img.height)
				ELSE
					s := WMRectangles.MakeRect(0, 0, frame.width, frame.height);
					IF (img.width/frame.width) < (img.height/frame.height) THEN
						h := ENTIER(frame.height/frame.width*img.width);
						d := WMRectangles.MakeRect(0, (img.height- h) DIV 2, img.width, img.height - (img.height - h) DIV 2)
					ELSE
						w := ENTIER(frame.width/frame.height*img.height);
						d := WMRectangles.MakeRect((img.width - w) DIV 2, 0, img.width - (img.width - w) DIV 2, img.height)
					END;
					canvas.ScaleImage(frame, s, d, WMGraphics.ModeCopy, 0)
				END;
			END;
			Swap;
			Invalidate(d);
		END ShowFrame;

		(* Make pointer visible when it is moved *)
		PROCEDURE PointerMove*(x, y : SIZE; keys : SET);
		BEGIN
			IF PointerInvisibleAfter > 0 THEN
				lastTimestamp := Kernel.GetTicks();
				SetPointerVisible(TRUE);
			END;
		END PointerMove;

		PROCEDURE PointerDown*(x, y : SIZE; keys : SET);
		BEGIN
			IF PointerInvisibleAfter > 0 THEN
				lastTimestamp := Kernel.GetTicks();
				SetPointerVisible(TRUE);
				IF keys # {2} THEN ToggleFullscreen; END;
				IF extPointerDownHandler # NIL THEN extPointerDownHandler(x, y, keys); END;
			END;
		END PointerDown;

		PROCEDURE SetPointerVisible(visible : BOOLEAN);
		BEGIN (* Since pointer move messages are not just sent once, we don't need to synchronize access to the pointerVisible field *)
			IF visible THEN
				SetPointerInfo(manager.pointerStandard);
			ELSE
				SetPointerInfo(manager.pointerNull);
			END;
		END SetPointerVisible;

	BEGIN {ACTIVE}
		IF PointerInvisibleAfter < 1 THEN alive := FALSE; END;
		WHILE alive DO (* Make pointer invisible when it is not moved for a certain amount of time *)
			timer.Sleep(PointerInvisibleAfter + 10);
			timestamp := Kernel.GetTicks();
			IF (timestamp - lastTimestamp >= PointerInvisibleAfter) THEN
				 SetPointerVisible(FALSE);
			END;
		END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END PlayerWindow;

TYPE

	(* buffer filler thread *)
	Filler = OBJECT
	VAR
		videoDecoder : Codecs.VideoDecoder;
		vBufferPool : VideoBufferPool;
		readyBufferPool : VideoBufferPool;
		vBuffer : VideoBuffer;
		blackBuffer : VideoBuffer;
		drop : SIGNED32;
		frame : VideoBuffer;

		alive, positionChanged : BOOLEAN;

		(* Performance statistics *)
		framesDecoded : SIGNED32;
		min, max, tot : SIGNED32;
		perf : SIGNED32;
		dropped : SIGNED32;

		PROCEDURE &New*(videoWidth, videoHeight : SIZE; videoDecoder : Codecs.VideoDecoder);
		VAR i : SIGNED32;
		BEGIN
			(* empty buffers *)
			NEW(vBufferPool, VBUFFERS);
			FOR i := 0 TO VBUFFERS-1 DO
				NEW(vBuffer);
				Raster.Create(vBuffer, videoWidth, videoHeight, Raster.BGR565);
				vBufferPool.Add(vBuffer)
			END;
			(* full buffers *)
			NEW(readyBufferPool, VBUFFERS);
			(* temp buffer *)
			NEW(blackBuffer); NEW(frame);
			Raster.Create(blackBuffer, videoWidth, videoHeight, Raster.BGR565);
			Raster.Create(frame, videoWidth, videoHeight, Raster.BGR565);
			SELF.videoDecoder := videoDecoder;
			alive := TRUE; positionChanged := FALSE;
			IF PerformanceStats THEN
				min := MAX(SIGNED32);
			END;
		END New;

		(* Returns the next Buffer ready to be played *)
		PROCEDURE GetNextBuffer(): VideoBuffer;
		BEGIN
			IF readyBufferPool.NofBuffers() > 0 THEN
				RETURN readyBufferPool.Remove()
			ELSE
				INC(dropped);
				RETURN blackBuffer;
			END;
		END GetNextBuffer;

		(* Puts the buffer back into the empty BufferPool *)
		PROCEDURE ReturnBuffer(buf : VideoBuffer);
		BEGIN
			IF buf # blackBuffer THEN
				vBufferPool.Add(buf)
			END
		END ReturnBuffer;

		PROCEDURE DropFrames(n : SIGNED32);
		BEGIN
			drop := n
		END DropFrames;

		PROCEDURE GetPos(): SIGNED32;
		BEGIN {EXCLUSIVE}
			 RETURN videoDecoder.GetCurrentFrame()
		END GetPos;

		PROCEDURE SeekAndGetFrame(pos: SIGNED32; VAR f : WMGraphics.Image; VAR res : SIGNED32);
		BEGIN  {EXCLUSIVE}
			ASSERT(frame # NIL);
			WHILE readyBufferPool.NofBuffers() > 0 DO (* flush Buffer *)
				vBufferPool.Add(readyBufferPool.Remove())
			END;
			videoDecoder.SeekFrame(pos, TRUE, res);
			videoDecoder.Next; videoDecoder.Next;
			videoDecoder.Render(frame);
			f := frame;
			videoDecoder.SeekFrame(pos, TRUE, res);
			videoDecoder.Next;
			IF videoDecoder.HasMoreData() THEN positionChanged := TRUE; END;
		END SeekAndGetFrame;

		PROCEDURE SeekFrame(pos : SIGNED32; isKeyFrame : BOOLEAN; VAR res : SIGNED32);
		BEGIN {EXCLUSIVE}
			WHILE readyBufferPool.NofBuffers() > 0 DO (* flush Buffer *)
				vBufferPool.Add(readyBufferPool.Remove())
			END;
			videoDecoder.SeekFrame(pos, TRUE, res);
			videoDecoder.Next;
			IF videoDecoder.HasMoreData() THEN positionChanged := TRUE; END;
		END SeekFrame;

		(* Returns the number of decoded frames available *)
		PROCEDURE NofFullBuffers() : SIZE;
		BEGIN
			RETURN readyBufferPool.NofBuffers()
		END NofFullBuffers;

		(* Terminate the filler process, but still grant access to already decoded frames *)
		PROCEDURE Stop;
		BEGIN {EXCLUSIVE}
			IF Trace * TraceFiller # {} THEN KernelLog.String("MediaPlayer: Filler stopped."); KernelLog.Ln; END;
			alive := FALSE;
		END Stop;

		(* Terminate the filler process *)
		PROCEDURE Close;
		BEGIN {EXCLUSIVE}
			IF Trace * TraceFiller # {} THEN KernelLog.String("MediaPlayer: Closing filler..."); KernelLog.Ln; END;
			alive := FALSE;
			(* To establish await conditions required to exit the active objects body *)
			IF readyBufferPool.NofBuffers() > 0 THEN vBufferPool.Add(readyBufferPool.Remove()); END;
		END Close;

	BEGIN {ACTIVE}
		WHILE alive DO
			IF videoDecoder.HasMoreData() THEN
				vBuffer := vBufferPool.Remove(); (* Will block of no buffers available *)
				BEGIN {EXCLUSIVE}
					IF alive & videoDecoder.HasMoreData() THEN
						IF PerformanceStats THEN
							perf := Kernel.GetTicks();
						END;
						videoDecoder.Next;
						videoDecoder.Render(vBuffer);
						IF PerformanceStats THEN
							perf := Kernel.GetTicks() - perf;
							IF perf < min THEN min := perf;
							ELSIF perf > max THEN max := perf;
							END;
							INC(tot, perf);
							INC(framesDecoded);
						END;
					END;
				END;
				readyBufferPool.Add(vBuffer);
			ELSE
				BEGIN {EXCLUSIVE} AWAIT(positionChanged OR ~alive); positionChanged := FALSE; END;
			END;
		END;
		IF Trace * TraceFiller # {} THEN KernelLog.String("MediaPlayer: Filler closed."); KernelLog.Ln; END;
		IF PerformanceStats THEN
			IF framesDecoded > 0 THEN
				KernelLog.String("MediaPlayer: Decoded "); KernelLog.Int(framesDecoded, 0); KernelLog.String(" frames in "); KernelLog.Int(tot, 0);
				KernelLog.String("ms (min: "); KernelLog.Int(min, 0);
				KernelLog.String(", avg: "); KernelLog.Int(tot DIV framesDecoded, 0); KernelLog.String(", max: "); KernelLog.Int(max, 0); KernelLog.String(")");
				KernelLog.String(", "); KernelLog.Int(dropped, 0); KernelLog.String(" frames not decoded in time"); KernelLog.Ln;
			END;
		END;
	END Filler;

TYPE

	Setup* = POINTER TO RECORD
		uri- : ARRAY 256 OF CHAR;

		hasAudio-, hasVideo- : BOOLEAN;	(* Does the opened ressource contain audio and video? *)
		canSeek- : BOOLEAN;				(* Is seeking supported? *)

		maxTime- : SIGNED32;				(* Duration of Video/Audio in 1/10 sec *)

		(* If hasVideo *)
		width-, height- : SIGNED32;			(* width and height of video frames if applicable *)
		mspf- : SIGNED32;					(* milliseconds per frame *)
		maxFrames- : SIGNED32;

		(* If hasAudio *)
		channels-, bits-, rate-: SIGNED32; 	(* Number of audio channels, resolution and rate *)
	END;

	(* The context record stores all information needed to play the associated ressource *)
	Context = POINTER TO RECORD
		uri : ARRAY 256 OF CHAR;					(* Ressource to be played *)
		hasVideo, hasAudio : BOOLEAN;	 			(* Does the ressource contain video and/or audio? *)
		canSeek : BOOLEAN;						(* Do the video and the audio stream support seeking? *)

		pos, oldPos : SIGNED32;						(* Current/last position in stream *)

		(* Only accessible if hasVideo = TRUE *)
		video : Codecs.VideoDecoder;
		maxFrames, maxTime : SIGNED32;
		width, height, mspf : SIGNED32;				(* width, heigth & milliseconds per frame of video *)
		filler : Filler;									(* Video Filler Thread *)
		vBuffer : VideoBuffer;						(* Video Buffer Object *)

		(* Only accessible if hasAudio = TRUE *)
		audio : Codecs.AudioDecoder;
		channels, bits, rate : SIGNED32;				(* Number of audio channels, their resolution (bits) and sampling rate (rate) (reported by GetAudioInfo() *)
		posRate : SIGNED32;							(* StreamInfo reports other rate than GetAudioInfo(). Use this value for calculating audio positions  *)
		aBuffer : SoundDevices.Buffer;
		channel : SoundDevices.Channel;
		bufferpool : SoundDevices.BufferPool;
		delay : SIGNED32;							(* Delay in milliseconds induced by using audio buffers *)

		(* Transition related *)
		transition : WMTransitions.TransitionFade;	(* Transition Object*)
		transitionFrame : SIGNED32;					(* Current frame in Transition *)
		transitionDuration : SIGNED32;				(* Number of frames the transition endures *)
		transitionImg : VideoBuffer;					(* Transition target video buffer *)
		black : VideoBuffer; 							(* Black frame *)
	END;

TYPE

	EofProc = PROCEDURE {DELEGATE} (sender, data: ANY);

	(* Decouples end-of-file handlers from media player main loop. This enables eof handlers to call methods
	 * of the media player *)
	EofHandler* = OBJECT
	VAR
		proc* : EofProc;
		player* : Player;
		alive, dead, called : BOOLEAN;

		PROCEDURE Call*;
		BEGIN {EXCLUSIVE}
			called := TRUE;
		END Call;

		PROCEDURE Terminate*;
		BEGIN
			IF Trace * TraceEof # {} THEN KernelLog.String("MediaPlayer: Terminating EOF handler."); KernelLog.Ln; END;
			BEGIN {EXCLUSIVE} alive := FALSE; END;
			(* Release obj lock to force condition evaluation *)
			BEGIN {EXCLUSIVE} AWAIT(dead); END;
		END Terminate;

		PROCEDURE &New*(player : Player);
		BEGIN
			SELF.player := player; alive := TRUE; dead := FALSE;
		END New;

	BEGIN {ACTIVE}
		WHILE alive DO
			BEGIN {EXCLUSIVE} AWAIT(~alive OR called); called := FALSE; END;
			IF alive & (proc # NIL) THEN
				IF Trace * TraceEof # {} THEN KernelLog.String("MediaPlayer: Call EOF procedure."); KernelLog.Ln; END;
				proc(player, NIL);
			END;
		END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END EofHandler;

	(**
	 * Player Object
	 * The body of the active object manages the state of the player. If a client wants to change the player state, it
	 * issues a state change request using (indirectly) RequestState.
	 *)
	Player*= OBJECT
	VAR
		(* Access the fields 'state', 'current' and 'next' only from within exclusive regions! *)
		state : SIGNED32;												(* Current state of player *)
		current, next : Context;

		(* State change request fields. Access via RequestState and GetRequestedState. *)
		nextState : SIGNED32;
		nextContext : Context;
		requestProcessed : BOOLEAN;

		lock : BOOLEAN;

		console* : BOOLEAN; (* Should error messages be displayed on console? *)

		(* Audio *)
		soundDevice : SoundDevices.Driver;									(* Audio Device *)
		mixerChannel, pcmChannel, mChannel : SoundDevices.MixerChannel;	(* Audio Mixer Channel *)
		channelName : ARRAY 128 OF CHAR;							(* Audio Mixer Channel Name *)

		(* player window *)
		pw : PlayerWindow;												(* Video Window *)

		(* Timing *)
		timer : Kernel.Timer;
		tickStart : SIGNED32;												(* TimeMark Start of Playing *)
		tickDelay : SIGNED32;											(* Number of milliseconds the decoding was too slow *)
		lastUpdate : SIGNED32;											(* Last time the update procedure was called *)
		videoFramesPlayed : SIGNED32;									(* Video Frames played since TimeMarkStart *)
		(* Milliseconds per frame; used for time synchronisation. TODO: Currently, the mspf value of the 'current' context is used.
		what if 'next' context has another mspf value and is concurrently played (transition)? *)
		mspf : SIGNED32;

		(* Delegates *)
		setup* : PROCEDURE {DELEGATE} (data : Setup);											(* init for GUI *)
		update* : PROCEDURE {DELEGATE} (state, pos, maxpos, displayTime: SIGNED32);			(* update for GUI *)
		eof : EofHandler;																		(* fired on End of File *)
		pointerDownHandler*: PROCEDURE {DELEGATE}(x,y: SIZE; keys:SET);
		(** -- Player Controls ----------------------------------------------- *)

		(* Open the given uri *)
		PROCEDURE Open*(CONST uri : ARRAY OF CHAR; VAR msg : ARRAY OF CHAR; VAR res : INTEGER);
		VAR  context : Context;
		BEGIN
			context := GetContext(uri, msg, res);
			IF (res # Ok) OR (context = NIL) THEN
				IF Debug OR console THEN
					KernelLog.String("MediaPlayer: Could not open file "); KernelLog.String(uri);
					KernelLog.String("(res: "); KernelLog.Int(res, 0); KernelLog.String(", "); KernelLog.String(msg); KernelLog.String(")");
					KernelLog.Ln;
				END;
				RETURN;
			END;
			RequestState(Ready, context);
			IF Trace * TraceOpen # {} THEN KernelLog.String("MediaPlayer: Opened "); KernelLog.String(uri); KernelLog.Ln; END;
		END Open;

		PROCEDURE Play*;
		BEGIN
			RequestState(Playing, NIL);
		END Play;

		PROCEDURE Step*;
		BEGIN
			SetState(Stepping);
		END Step;

		(* pos & duration set in number of video frames *)
		PROCEDURE DoTransition*(CONST uri: ARRAY OF CHAR; pos, duration : SIGNED32; VAR msg : ARRAY OF CHAR; VAR res : INTEGER);
		VAR context : Context; audioPos : SIGNED32;
		BEGIN
			IF Trace * TraceTransitions # {} THEN
				KernelLog.String("MediaPlayer: Doing a Transition to "); KernelLog.String(uri); KernelLog.String(" (Duration: ");
				KernelLog.Int(duration, 0); KernelLog.String(" frames)"); KernelLog.Ln;
			END;
			IF (duration < 1) OR (pos < 0) THEN
				IF Debug OR console THEN KernelLog.String("MediaPlayer: Warning: DoTransition: Pos or duration value adjusted."); KernelLog.Ln; END;
				IF pos < 0 THEN pos := 0; END;
				IF duration < 1 THEN duration := 1; END;
			END;

			context := GetContext(uri, msg, res);
			IF context = NIL THEN
				IF Debug OR console THEN KernelLog.String("MediaPlayer: Could not get context for transition: "); KernelLog.String(msg); KernelLog.Ln; END;
				RETURN;
			END;

			IF context.hasVideo & (pos > context.maxFrames) THEN
				IF Debug OR console THEN
					KernelLog.String("MediaPlayer: Warning: DoTransition: Pos value clipped to maxFrames: ");
					KernelLog.Int(context.maxFrames, 0); KernelLog.Ln;
				END;
				pos := context.maxFrames;
				(* Continue *)
			END;

			IF context.hasVideo THEN
				context.filler.SeekFrame(pos, TRUE, res);
				context.pos := res; context.oldPos := res-1;
				IF context.hasAudio THEN (* search the according Audio *)
					(* The value 12 corresponds to cdSize in the AVI - WaveFormatStructure - should be given via Codecs *)
					audioPos := ENTIER(context.maxTime/10*context.posRate*(res/context.maxFrames) -
						ENTIER(context.maxTime/10*context.posRate*(res/context.maxFrames)) MOD 12);
					IF audioPos  < 0 THEN audioPos := 0 END;
				END;

				(* Init Transition *)
				NEW(context.transition); context.transition.Init(context.width, context.height);
				NEW(context.transitionImg); Raster.Create(context.transitionImg, context.width, context.height, Raster.BGR565);
				NEW(context.black); Raster.Create(context.black, context.width, context.height, Raster.BGR565);
				context.transitionFrame := 0;
				context.transitionDuration := duration;
			END;

			IF context.hasAudio & (soundDevice # NIL) THEN
				context.audio.SeekSample(audioPos, FALSE, res);
				context.channel.SetVolume(0);
				context.channel.Start;
			END;

			IF Trace * TraceTransitions # {} THEN
				KernelLog.String("MediaPlayer: Transition to pos (next keyframe): "); KernelLog.Int(context.pos, 0);
				KernelLog.String(" (wanted: "); KernelLog.Int(pos, 0); KernelLog.String(")"); KernelLog.Ln;
			END;
			RequestState(InTransition, context);
		END DoTransition;

		PROCEDURE Stop*;
		BEGIN
			RequestState(Stopped, NIL);
		END Stop;

		PROCEDURE Pause*;
		BEGIN
			RequestState(Paused, NIL);
		END Pause;

		(* Get in  1/10 sec. Returns -1 if information is not available. *)
		PROCEDURE GetPos*(): SIGNED32;
		VAR context : Context; res : INTEGER;
		BEGIN {EXCLUSIVE}
			res := -1;
			context := current;
			IF context # NIL THEN
				IF context.hasVideo THEN res := 10*current.filler.GetPos() DIV (1000 DIV current.mspf);
				ELSIF current.hasAudio THEN res := current.audio.GetCurrentTime();
				END;
			END;
			RETURN res;
		END GetPos;

		(* Set position *)
		PROCEDURE SetPos*(pos: SIGNED32);
		VAR current : Context;  audioPos, res : SIGNED32; img : WMGraphics.Image;
		BEGIN {EXCLUSIVE}
			IF pos < 0 THEN
				IF Debug THEN KernelLog.String("MediaPlayer: Warning: Setpos to "); KernelLog.Int(pos, 0); KernelLog.String("!?!"); KernelLog.Ln; END;
				pos := 0;
			END;
			current := SELF.current;
			IF (current # NIL) & current.canSeek THEN
				IF current.hasVideo THEN
					IF pos > current.maxFrames THEN
						IF Debug THEN KernelLog.String("MediaPlayer: Warning: Setpos to "); KernelLog.Int(pos, 0); KernelLog.String(" (>MaxFrames)!?! "); KernelLog.Ln; END;
						pos := current.maxFrames;
					END;
					current.filler.SeekAndGetFrame(pos, img, res);
					IF img # NIL THEN
						IF pw # NIL THEN pw.ShowFrame(img); END;
					END;
					current.pos := res;
					current.oldPos := current.pos-1;
					IF current.hasAudio THEN (* search the according Audio *)
						(* The value 12 corresponds to cdSize in the AVI - WaveFormatStructure - should be given via Codecs *)
						audioPos := ENTIER(current.maxTime/10*current.posRate*(res/current.maxFrames) -
							ENTIER(current.maxTime/10*current.posRate*(res/current.maxFrames)) MOD 12);
						IF audioPos  < 0 THEN audioPos := 0 END;
						current.audio.SeekSample(audioPos, FALSE, res);
					END;
				ELSIF current.hasAudio THEN	(* search audio only *)
					pos := ENTIER(pos / 10 * current.posRate);
					current.audio.SeekSample(pos, FALSE, res);
					pos := current.audio.GetCurrentTime();
					current.pos := pos;
					current.oldPos := current.pos-1;
				END;
				(* IF update # NIL THEN update(state, pos, current.maxFrames, pos) END *)
			END;
		END SetPos;

		PROCEDURE SetEofAction*(proc : EofProc);
		BEGIN {EXCLUSIVE}
			IF eof = NIL THEN NEW(eof, SELF); END;
			eof.proc := proc;
		END SetEofAction;

		(* Creates a new Player Instance *)
		PROCEDURE &New*;
		VAR i : SIGNED32;
		BEGIN
			NEW(timer);
			IF (SoundDevices.devices.Get("") # NIL) THEN
			 	soundDevice := SoundDevices.GetDefaultDevice();
				(* set mixerchannel to max output *)
				soundDevice.GetMixerChannel(0, mixerChannel); (* global mixer channel *)
				mixerChannel.SetVolume(255);
				(* find PCM MixerChannel *)
				FOR i := 0 TO soundDevice.GetNofMixerChannels() - 1 DO
					soundDevice.GetMixerChannel(i, mChannel);
					mChannel.GetName(channelName);
					IF channelName = "PCMOut" THEN pcmChannel := mChannel; pcmChannel.SetVolume(255) END
				END;
			END;
			eof := NIL;
			SetState(NotReady);
		END New;

		PROCEDURE Acquire;
		BEGIN {EXCLUSIVE}
			AWAIT(lock = FALSE);
			lock := TRUE;
		END Acquire;

		PROCEDURE Release;
		BEGIN {EXCLUSIVE}
			lock := FALSE;
		END Release;

		(* Request to media player to go into the specified state *)
		PROCEDURE RequestState(state : SIGNED32; context : Context);
		BEGIN
			Acquire;
			BEGIN {EXCLUSIVE}
				requestProcessed := FALSE;
				IF nextState # NoRequest THEN (* Skip the already scheduled state change *)
					IF nextContext # NIL THEN FreeContext(nextContext); END;
				END;
				nextState := state;
				nextContext := context;
			END;
			(* Release the lock to evaluate the 'nextState' await condition which in turn will
			lead to requestProcessed to be set. *)
			BEGIN {EXCLUSIVE}
				AWAIT(requestProcessed OR (state >= Closed));
			END;
			Release;
		END RequestState;

		PROCEDURE GetRequestedState(VAR state : SIGNED32; VAR context : Context);
		BEGIN {EXCLUSIVE}
			state := nextState; nextState := NoRequest;
			context := nextContext; nextContext := NIL;
			requestProcessed := TRUE;
		END GetRequestedState;

		PROCEDURE SetState*(state : SIGNED32);
		BEGIN {EXCLUSIVE}
			IF Trace * TraceStates # {} THEN KernelLog.String("MediaPlayer: Set state to "); KernelLog.Int(state, 0); KernelLog.Ln; END;
			SELF.state := state;
		END SetState;

		PROCEDURE GetState*() : SIGNED32;
		BEGIN {EXCLUSIVE}
			RETURN state;
		END GetState;

		PROCEDURE GetCurrentFrame*() : VideoBuffer;
		BEGIN {EXCLUSIVE}
			RETURN current.vBuffer;
		END GetCurrentFrame;

		PROCEDURE ToggleFullScreen*(sender, data : ANY);
		BEGIN {EXCLUSIVE}
			IF (pw # NIL) & (~ForceFullscreen) THEN pw.ToggleFullscreen; END;
		END ToggleFullScreen;

		PROCEDURE CheckWindow(context : Context);
		VAR oldPw : PlayerWindow;
		BEGIN
			IF context.hasVideo THEN
				IF (pw # NIL) & pw.fullscreen THEN
					(* do nothing *)
				ELSIF (pw = NIL) OR (pw.GetWidth() # context.width) OR (pw.GetHeight() # context.height) THEN
					oldPw := pw;
					NEW(pw, context.width, context.height, FALSE, SELF, TRUE);
					pw.extPointerDownHandler:=pointerDownHandler;
					IF ForceFullscreen THEN pw.ToggleFullscreen; END;
					IF oldPw # NIL THEN oldPw.Close; END;
				END;
			ELSIF pw # NIL THEN
				pw.Close;
			END;
		END CheckWindow;

		(* reset the tickTimer *)
		PROCEDURE InitTime;
		BEGIN
			 tickStart := Kernel.GetTicks(); tickDelay := 0;
			videoFramesPlayed := 0;
		END InitTime;

		(* Allocate ressources required for playing the audio/video stream *)
		PROCEDURE GetContext(CONST uri : ARRAY OF CHAR; VAR msg : ARRAY OF CHAR; VAR res : INTEGER) : Context;
		VAR
			in, audioStream, videoStream : Streams.Reader;
			demux : Codecs.AVDemultiplexer;
			audioDecoder : Codecs.AudioDecoder; videoDecoder : Codecs.VideoDecoder;
			streamInfo : Codecs.AVStreamInfo;
			nofStreams, type, maxFrames, maxTime, width, height, mspf : SIGNED32;
			channels, rate, bits: SIGNED32;
			buffer : SoundDevices.Buffer;
			hasAudio, hasVideo : BOOLEAN;
			audioCanSeek, videoCanSeek : BOOLEAN;
			name, ext : ARRAY 256 OF CHAR;
			context : Context;
			i : SIGNED32;
		BEGIN
			IF Trace * TraceOpen # {} THEN KernelLog.String("MediaPlayer: Get decoders for: "); KernelLog.String(uri); KernelLog.Ln; END;
			in := Codecs.OpenInputStream(uri);
			IF (in = NIL) THEN
				res := CouldNotOpenStream; COPY("Can't open stream: ", msg); Strings.Append(msg, uri);
				IF Debug OR console THEN KernelLog.String("MediaPlayer: "); KernelLog.String(msg); KernelLog.Ln; END;
				RETURN NIL;
			END;

			Strings.GetExtension(uri, name, ext);	(* split uri into name & extension *)
			Strings.UpperCase(ext);					(* convert extension to UpperCase for Codecs *)

			(* find Demultiplexer *)
			demux := Codecs.GetDemultiplexer(ext);
			IF demux = NIL THEN
				IF Trace * TraceOpen # {} THEN KernelLog.String("MediaPlayer: No Demux found: "); KernelLog.String(ext); KernelLog.Ln; END;
				(* no demuxable file / no suitable demux *)
				audioDecoder := Codecs.GetAudioDecoder(ext);
				IF (audioDecoder # NIL) THEN
					audioDecoder.Open(in, res);
					IF (res # Codecs.ResOk) THEN
						res := AudioNotCompatible; COPY("Audio stream not compatible: ", msg); Strings.Append(msg, uri);
						IF Debug OR console THEN KernelLog.String("MediaPlayer: "); KernelLog.String(msg); KernelLog.Ln; END;
						RETURN NIL;
					END;
					hasAudio := TRUE;
					audioCanSeek := audioDecoder.CanSeek();
					IF in IS Codecs.FileInputStream THEN (* Set the Stream Length in Bytes, needed for some Functions in some Decoders *)
						audioDecoder.SetStreamLength(in(Codecs.FileInputStream).f.Length()(SIGNED32));
					END;
				ELSE
					videoDecoder := Codecs.GetVideoDecoder(ext);
					IF (videoDecoder # NIL) THEN
						videoDecoder.Open(in, res);
						IF (res # Codecs.ResOk) THEN
							res := VideoNotCompatible; COPY("Video stream not compatible: ", msg); Strings.Append(msg, uri);
							IF Debug OR console THEN KernelLog.String("MediaPlayer: "); KernelLog.String(msg); KernelLog.Ln; END;
							RETURN NIL;
						END;
						hasVideo := TRUE;
						videoCanSeek := videoDecoder.CanSeek();
					ELSE
						res := NoDecoders; COPY("No decoder available for: ", msg); Strings.Append(msg, uri);
						IF Debug OR console THEN KernelLog.String("MediaPlayer: "); KernelLog.String(msg); KernelLog.Ln; END;
						RETURN NIL;
					END;
				END;
			ELSE
				IF Trace * TraceOpen # {} THEN KernelLog.String("MediaPlayer: Demux found: "); KernelLog.String(ext); KernelLog.Ln; END;
				demux.Open(in, res);
				IF (res # Codecs.ResOk) THEN
					res := DemuxNotCompatible; COPY("Demux stream not compatible: ", msg); Strings.Append(msg, uri);
					IF Debug OR console THEN KernelLog.String("MediaPlayer: "); KernelLog.String(msg); KernelLog.Ln; END;
					RETURN NIL;
				END;
				nofStreams := demux.GetNumberOfStreams();
				IF Trace * TraceOpen # {} THEN KernelLog.String("MediaPlayer: Number of Streams: "); KernelLog.Int(nofStreams, 0); KernelLog.Ln; END;
				FOR i := 0 TO nofStreams-1 DO
					IF Trace * TraceOpen # {} THEN KernelLog.String("MediaPlayer: Processing Stream: "); KernelLog.Int(i, 0); END;
					type := demux.GetStreamType(i);
					IF Trace * TraceOpen # {}  THEN KernelLog.String(" with Type: "); KernelLog.Int(type, 0); KernelLog.Ln; END;
					IF (type = Codecs.STVideo) THEN (* Video Stream *)
						videoStream := demux.GetStream(i);
						videoStream(Codecs.DemuxStream).Open(demux, i);
						streamInfo := demux.GetStreamInfo(i);
						videoDecoder := Codecs.GetVideoDecoder(streamInfo.contentType);
						IF (videoDecoder = NIL) THEN
							res := NoVideoDecoder; COPY("No Decoder for video format: ", msg); Strings.Append(msg, streamInfo.contentType);
							IF Debug OR console THEN KernelLog.String("MediaPlayer: "); KernelLog.String(msg); KernelLog.Ln; END;
							hasVideo := FALSE;
						ELSE
							videoDecoder.Open(videoStream, res);
							IF (res # Codecs.ResOk) THEN
								res := VideoNotCompatible; COPY("Video stream not compatible: ", msg); Strings.Append(msg, uri);
								IF Debug OR console THEN KernelLog.String("MediaPlayer: "); KernelLog.String(msg); KernelLog.Ln; END;
								hasVideo := FALSE;
							ELSE
								videoCanSeek := videoDecoder.CanSeek();
								maxFrames := streamInfo.frames;
								IF streamInfo.rate # 0 THEN maxTime := 10 * streamInfo.frames DIV streamInfo.rate; (* 1/10 sec *)
								ELSE videoCanSeek := FALSE;
								END;
								hasVideo := TRUE;
							END;
						END;
					ELSIF (type = Codecs.STAudio) THEN (* Audio Stream *)
						audioStream := demux.GetStream(i);
						audioStream(Codecs.DemuxStream).Open(demux, i);
						streamInfo := demux.GetStreamInfo(i);
						audioDecoder := Codecs.GetAudioDecoder(streamInfo.contentType);
						IF (audioDecoder = NIL) THEN
							res := NoAudioDecoder; COPY("No Decoder for audio format: ", msg); Strings.Append(msg, streamInfo.contentType);
							IF Debug OR console THEN KernelLog.String("MediaPlayer: "); KernelLog.String(msg); KernelLog.Ln; END;
							hasAudio := FALSE;
						ELSE
							audioDecoder.Open(audioStream, res);
							IF (res # Codecs.ResOk) THEN
								res := AudioNotCompatible; COPY("Audio stream not compatible: ", msg); Strings.Append(msg, uri);
								IF Debug OR console THEN KernelLog.String("MediaPlayer: "); KernelLog.String(msg); KernelLog.Ln; END;
								hasAudio := FALSE;
							ELSE
								audioCanSeek := audioDecoder.CanSeek();
								hasAudio := TRUE;
							END;
						END;
					ELSE
						IF Trace * TraceOpen # {} THEN KernelLog.String("MediaPlayer: Unknown Stream Type: "); KernelLog.Int(type, 0); KernelLog.Ln; END;
					END;
				END;
			END;

			IF hasVideo OR hasAudio THEN
				NEW(context);
				COPY(uri, context.uri);
				IF hasVideo THEN
					context.hasVideo := TRUE;
					context.video := videoDecoder;
					context.maxFrames := maxFrames; context.maxTime := maxTime;
					videoDecoder.GetVideoInfo(width, height, mspf);
					context.width := width; context.height := height; context.mspf := mspf;
					NEW(context.filler, width, height, videoDecoder);
				END;
				IF hasAudio & (soundDevice # NIL)THEN
					context.hasAudio := TRUE;
					context.audio := audioDecoder;

					(* Calculate delay induced by audio buffering *)
					IF (channels # 0) & (bits # 0) & (rate # 0) THEN
						context.delay := ENTIER(AudioBuffers * AudioBufferSize * 8 (* Buffersize in bits *) / (channels * bits * rate) (* bit rate of audio stream *)) + 1 ;
					ELSE
						context.delay := 50; (* guess *)
					END;
					context.delay := context.delay + AudioConstantDelay;
					IF Trace * TraceOpen # {} THEN KernelLog.String("Audio delay: "); KernelLog.Int(context.delay, 0); KernelLog.String("ms"); KernelLog.Ln; END;

					NEW(context.bufferpool, AudioBuffers);
					FOR i := 0 TO AudioBuffers-1 DO
						NEW(buffer); buffer.len := AudioBufferSize; NEW(buffer.data, AudioBufferSize);
						context.bufferpool.Add(buffer);
					END;
					audioDecoder.GetAudioInfo(channels, rate, bits);
					context.channels := channels; context.rate := rate; context.bits := bits;

					(* UGLY: AVStreamInfo reports different rate as GetAudioInfo does. *)
					IF (audioStream # NIL) & (audioStream IS Codecs.DemuxStream) THEN
						context.posRate := audioStream(Codecs.DemuxStream).streamInfo.rate;
					END;

					IF ~hasVideo THEN
						context.maxTime := audioDecoder.GetTotalSamples() DIV rate * 10;
						context.maxFrames := maxTime;
					END;
					audioDecoder.SeekSample(0, FALSE, res);(* what if stream not seekable? *)
					soundDevice.OpenPlayChannel(context.channel, rate, bits, channels, SoundDevices.FormatPCM, res);
					IF context.channel = NIL THEN
						IF Debug OR console THEN KernelLog.String("MediaPlayer: Could not open audio play channel."); KernelLog.Ln; END;
					ELSE
						context.channel.RegisterBufferListener(context.bufferpool.Add);
						context.channel.SetVolume(255);
					END;
				END;
				context.canSeek := (~hasVideo OR videoCanSeek) & (~hasAudio OR audioCanSeek);
			ELSE
				res := NoDecoders; COPY("No demux/decoder found for ", msg); Strings.Append(msg, uri);
				IF Debug OR console THEN KernelLog.String("MediaPlayer: "); KernelLog.String(msg); KernelLog.Ln; END;
			END;
			IF Trace * TraceOpen # {} THEN
				KernelLog.String("Context opened: Maxtime: "); KernelLog.Int(context.maxTime, 0);
				KernelLog.String(", maxFrames: "); KernelLog.Int(context.maxFrames, 0); KernelLog.Ln;
			END;
			RETURN context;
		END GetContext;

		PROCEDURE FreeContext(context : Context);
		BEGIN
			IF context # NIL THEN
				IF context.filler # NIL THEN context.filler.Close; context.filler := NIL; END;
				IF context.channel # NIL THEN context.channel.Close; context.channel := NIL; END;
			END;
		END FreeContext;

		PROCEDURE NoAction*(sender, data: ANY);
		BEGIN
			IF Trace * TraceEof # {} THEN KernelLog.String("MediaPlayer: EOF NoAction."); KernelLog.Ln; END;
			Stop;
		END NoAction;

		PROCEDURE Loop*(sender, data: ANY);
		BEGIN
			IF Trace * TraceEof # {} THEN KernelLog.String("MediaPlayer: EOF Loop."); KernelLog.Ln; END;
			Stop; Play;
		END Loop;

		PROCEDURE Quit*(sender, data: ANY);
		BEGIN
			IF Trace * TraceEof # {} THEN KernelLog.String("MediaPlayer: EOF Quit."); KernelLog.Ln; END;
			Close;
		END Quit;

		PROCEDURE RenderAudio(c :  Context);
		BEGIN (* no concurrency allowed *)
			ASSERT(c # NIL);
			WHILE c.hasAudio & c.audio.HasMoreData() & (c.bufferpool.NofBuffers() > 0) DO
				c.aBuffer := c.bufferpool.Remove();
				c.audio.FillBuffer(c.aBuffer);
				c.channel.QueueBuffer(c.aBuffer);
				IF ~c.hasVideo THEN
					c.pos := c.audio.GetCurrentTime();
				END
			END;
		END RenderAudio;

		(* Render the next video frame of the specified context *)
		PROCEDURE RenderVideo(c : Context);
		BEGIN
			ASSERT((c # NIL) & (c.hasVideo));
			c.vBuffer := c.filler.GetNextBuffer();
			IF pw # NIL THEN pw.ShowFrame(c.vBuffer) END;
			c.filler.ReturnBuffer(c.vBuffer);
			INC(videoFramesPlayed); c.oldPos := c.pos; INC(c.pos);
		END RenderVideo;

		(* Render transition from context 'from' to context 'to' *)
		PROCEDURE RenderVideoTransition(from, to : Context);
		VAR temp : VideoBuffer;
		BEGIN
			ASSERT((to # NIL) & (to.transition # NIL) & (to.transitionImg # NIL) & (to.black # NIL));
			INC(to.transitionFrame);
			IF Trace * TraceTransitions # {} THEN
				KernelLog.String("MediaPlayer: Transition Frame ");
				KernelLog.Int(to.transitionFrame, 0); KernelLog.String(" of "); KernelLog.Int(to.transitionDuration, 0);
				KernelLog.Ln;
			END;
			(* stop filler if enough frames already precalced in buffer *)
			IF (from # NIL) THEN
				IF from.filler.NofFullBuffers() >= (to.transitionDuration - to.transitionFrame) THEN from.filler.Stop; END;
				from.vBuffer := from.filler.GetNextBuffer();
				temp := from.vBuffer;
			ELSE
				temp := to.black;
			END;
			(* display frame *)
			to.vBuffer := to.filler.GetNextBuffer();
			to.transition.CalcImage(temp, to.vBuffer, to.transitionImg, to.transitionFrame*255 DIV to.transitionDuration);
			IF pw # NIL THEN pw.ShowFrame(to.transitionImg) END;

			to.filler.ReturnBuffer(to.vBuffer);
			to.oldPos := to.pos; INC(to.pos);
			IF from # NIL THEN
				from.filler.ReturnBuffer(from.vBuffer);
				from.oldPos := from.pos; INC(from.pos);
			END;
			INC(videoFramesPlayed);
			IF to.transitionFrame >= to.transitionDuration THEN
				IF (from # NIL) THEN FreeContext(from); from := NIL; END;
				IF Trace * TraceTransitions # {} THEN KernelLog.String("MediaPlayer: Transition Finished."); KernelLog.Ln; END;
			 END;
		END RenderVideoTransition;

		(* Render video and/or audio *)
		PROCEDURE Render(c1, c2 : Context);
		VAR
			tickIs: SIGNED32;
			tickShould : SIGNED32;
		BEGIN
			IF c1 # NIL THEN
				IF GetState() = InTransition THEN (* Render transition from c2 to c1 *)
					IF c2 # NIL THEN
						IF c2.hasAudio THEN
							RenderAudio(c2);
							c2.channel.SetVolume(256 - c1.transitionFrame*(256 DIV c1.transitionDuration));
						ELSE
							timer.Sleep(40);
						END;
					END;
					IF c1.hasAudio THEN
						RenderAudio(c1);
						c1.channel.SetVolume(256*c1.transitionFrame DIV c1.transitionDuration);
					END;
					IF c1.hasVideo THEN RenderVideoTransition(c2, c1); END;
				ELSE
					IF c1.hasAudio THEN
						RenderAudio(c1);
					END;
					IF c1.hasVideo THEN
						RenderVideo(c1);
					END;
				END;
			END;
			(* Check time and sleep or drop frames *)
			tickIs := Kernel.GetTicks() - tickStart;
			tickShould := videoFramesPlayed * mspf;
			IF tickIs < tickShould THEN (* We were too fast *)
				timer.Sleep(tickShould-tickIs);
			END;

			IF Trace * TraceRendering # {} THEN
				KernelLog.String("Frame: "); KernelLog.Int(videoFramesPlayed, 0);
				KernelLog.String(" [Is: "); KernelLog.Int(tickIs, 0); KernelLog.String(", Should="); KernelLog.Int(tickShould, 0);
				KernelLog.String(",Sleep: ");
				IF (tickIs < tickShould) THEN
					IF tickDelay < (tickShould-tickIs) THEN
						KernelLog.Int(tickShould - tickIs - tickDelay, 0);
					ELSE
						KernelLog.Int(8, 0);
					END;
				ELSE KernelLog.Int(0, 0);
				END;
				KernelLog.String(", Delay: "); KernelLog.Int(tickDelay, 0);
				KernelLog.String("]"); KernelLog.Ln;
			END;
		END Render;

		PROCEDURE Close*;
		BEGIN
			RequestState(Closed, NIL);
			BEGIN {EXCLUSIVE} AWAIT(state = Closed); END;
			mplayer := NIL;
			IF Trace * TracePlayer # {} THEN KernelLog.String("MediaPlayer closed."); KernelLog.Ln; END;
		END Close;

		PROCEDURE StopIntern;
		VAR img : WMGraphics.Image; res : INTEGER;
		BEGIN
			FreeContext(next); next := NIL;
			IF current # NIL THEN
				IF current.hasVideo THEN current.filler.SeekAndGetFrame(0, img, res); END;
				IF current.hasAudio THEN current.channel.Stop; current.audio.SeekSample(0, FALSE, res); END;
				current.pos := 0; current.oldPos := -1;
			END;
			IF pw # NIL THEN
				IF img # NIL THEN pw.ShowFrame(img); ELSE pw.ShowBlack; END;
			END;
		END StopIntern;

		PROCEDURE StartPlayIntern;
		VAR res : INTEGER;
		BEGIN
			IF current # NIL THEN
				IF state = Finished THEN
					current.pos := 0; current.oldPos := -1;
					IF current.hasVideo THEN current.filler.SeekFrame(0, TRUE, res); END;
					IF current.hasAudio THEN current.channel.Stop; current.audio.SeekSample(0, FALSE, res); END;
				END;
				IF current.hasAudio THEN current.channel.SetVolume(255); current.channel.Start; END;
				InitTime;
			END;
		END StartPlayIntern;

		(* Pause the current and next context if applicable *)
		PROCEDURE PauseIntern;
		BEGIN
			IF (current # NIL) & current.hasAudio THEN current.channel.Pause; END;
			IF (next # NIL) & next.hasAudio THEN next.channel.Pause; END;
		END PauseIntern;

		(* Resume playing the curent and next context that are paused *)
		PROCEDURE ResumeIntern;
		VAR audioPos, res : SIGNED32;
		BEGIN
			IF (current # NIL) THEN
				IF current.hasVideo THEN
					res := (current.video.GetCurrentFrame()-current.filler.NofFullBuffers()(SIGNED32));
					IF current.hasAudio THEN
						audioPos := ENTIER(current.maxTime/10*current.posRate*(res/current.maxFrames) -
							ENTIER(current.maxTime/10*current.posRate*(res/current.maxFrames)) MOD 12);
						IF audioPos  < 0 THEN audioPos := 0 END;
						current.audio.SeekSample(audioPos, FALSE, res);
					END;
				END;
				IF current.hasAudio THEN current.channel.Start; END;
			END;
			IF (next # NIL) THEN
				IF next.hasVideo THEN
					res := (next.video.GetCurrentFrame()-next.filler.NofFullBuffers()(SIGNED32));
					IF next.hasAudio THEN
						audioPos := ENTIER(next.maxTime/10*next.posRate*(res/next.maxFrames) -
							ENTIER(next.maxTime/10*next.posRate*(res/next.maxFrames)) MOD 12);
						IF audioPos  < 0 THEN audioPos := 0 END;
						next.audio.SeekSample(audioPos, FALSE, res);
					END;
				END;
				IF next.hasAudio THEN next.channel.Start; END;
			END;
			IF (current # NIL) OR (next # NIL) THEN
				InitTime;
			END;
		END ResumeIntern;

		PROCEDURE OpenIntern(nextContext : Context);
		VAR img : WMGraphics.Image; data : Setup; res : INTEGER;
		BEGIN
			FreeContext(next); next := NIL;
			FreeContext(current); current := nextContext;
			mspf := current.mspf; current.pos := 0; current.oldPos := -1;
			CheckWindow(current);
			IF current.hasVideo THEN
				current.filler.SeekAndGetFrame(0, img, res);
			END;
			IF pw # NIL THEN
				IF img # NIL THEN pw.ShowFrame(img); ELSE pw.ShowBlack; END;
			END;
			IF setup # NIL THEN
				NEW(data);
				data.hasVideo := current.hasVideo;
				data.hasAudio := current.hasAudio;
				data.canSeek := current.canSeek;
				COPY(nextContext.uri, data.uri);
				data.mspf := current.mspf;
				data.maxFrames := current.maxFrames;
				data.maxTime := current.maxTime;
				IF current.hasVideo THEN
					data.width := current.width; data.height := current.height;
				END;
				IF current.hasAudio THEN
					data.channels := current.channels; data.bits := current.bits; data.rate := current.rate;
				END;
				setup(data);
			END;
		END OpenIntern;

		PROCEDURE IsValidStateTransition(from, to : SIGNED32) : BOOLEAN;
		VAR res : BOOLEAN;
		BEGIN
			res := FALSE;
			CASE from OF
				|NotReady:		IF (to = Ready) OR (to = InTransition) THEN res := TRUE; END;
				|Ready:			IF (to = Ready) OR (to = Playing) OR (to = InTransition) OR (to = Stepping) THEN res := TRUE; END;
				|Playing:		IF (to = Ready) OR (to = Paused)  OR (to = Stepping) OR (to = Stopped) OR (to = InTransition) THEN res := TRUE; END;
				|Paused:		IF (to = Ready) OR (to = Playing) OR (to = Stepping) OR (to = Stopped) OR (to = Paused) OR (to = InTransition) THEN res := TRUE; END;
				|Stopped:		IF (to = Ready) OR (to = Playing) OR (to = InTransition) THEN res := TRUE; END;
				|Stepping:	IF	(to = Ready) OR (to = Playing) OR (to = Stepping) OR (to = Paused)   OR (to = InTransition) THEN res := TRUE; END;
				|Finished:		IF (to = Ready) OR (to = Playing) OR (to = Stopped) OR (to = InTransition) THEN res := TRUE; END;
				|InTransition:	IF (to = Ready) OR (to = Paused) OR (to = Stopped) OR (to = InTransition) THEN res := TRUE; END;
				|Error: 			(* Do not execute commands anymore *)
				|Closed:  		(* Do not execute commands anymore *)
			ELSE
				IF Debug THEN KernelLog.String("MediaPlayer: Start state of state transition not known."); KernelLog.Ln; END;
			END;
			IF (to = Error) OR (to = Closed)  THEN res := TRUE; END;
			RETURN res;
		END IsValidStateTransition;

		(* Pre-Condition: (state = Playing) OR (state = InTransition) OR (nextState # NoRequest) *)
		PROCEDURE EvaluateState;
		VAR
			oldState : SIGNED32;
			isValid : BOOLEAN; nextState : SIGNED32; nextContext : Context;
			audioFinished, videoFinished : BOOLEAN;
			currentTime : SIGNED32; callUpdate : BOOLEAN;
			temp : SIGNED32;
		BEGIN
			GetRequestedState(nextState, nextContext); oldState := state;
			IF state=Stepping THEN nextState:= Paused END;
			IF (nextState # NoRequest) THEN
				isValid :=  IsValidStateTransition(state, nextState);
				IF isValid THEN
					CASE nextState OF
						NoRequest: (* Remain in current state *)
						|Ready: (* Abort whatever the player is doing and go to 'Ready' state *)
							OpenIntern(nextContext);
							SetState(Ready);
						|Playing:
							StartPlayIntern; SetState(Playing);
						(*|Stepping:
							ResumeIntern; SetState(Playing);
							(*IF state=Paused THEN 
								ResumeIntern; SetState(Playing);
							ELSE 
								PauseIntern; SetState(Paused);
							END;*)*)
						|Paused:
							IF state = Paused THEN
								ResumeIntern; SetState(Playing);
							ELSE
								PauseIntern; SetState(Paused);
							END;
						|Stopped:
							StopIntern; SetState(Stopped);
						|InTransition:
							FreeContext(next); next := current;
							current := nextContext;
							mspf := current.mspf;
							CheckWindow(current);
							InitTime;
							SetState(InTransition);
						|Closed:
							FreeContext(current); current := NIL;
							FreeContext(next); next := NIL;
							FreeContext(nextContext); nextContext := NIL;
							SetState(Closed);
					ELSE
						IF Debug THEN KernelLog.String("MediaPlayer: Warning: Ignore request to set state to: "); KernelLog.Int(nextState, 0); KernelLog.Ln; END;
					END;
				END;
				IF Trace * TraceStates # {} THEN
					KernelLog.String("MediaPlayer: Request state transition from '");
					KernelLog.Int(oldState, 0); KernelLog.String("' to '"); KernelLog.Int(nextState, 0);	KernelLog.String("': ");
					IF isValid THEN KernelLog.String("Valid (New state: "); KernelLog.Int(state, 0); KernelLog.String(")");
					ELSE KernelLog.String("Invalid (Rejected)");
					END;
					KernelLog.Ln;
				END;
			END;

			IF nextState = NoRequest THEN (* Check whether current video is still playing *)
				IF (state = InTransition) & (current.transitionFrame >= current.transitionDuration) THEN (* Transition Finished *)
					SetState(Playing);
				END;
				audioFinished := FALSE; videoFinished := FALSE;
				IF current = NIL THEN
					audioFinished := TRUE; videoFinished := TRUE;
				ELSE
					IF ~current.hasVideo OR (current.hasVideo & ~current.video.HasMoreData() & (current.filler.NofFullBuffers() <= 0)) THEN videoFinished := TRUE; END;
					IF ~current.hasAudio OR (current.hasAudio & ~current.audio.HasMoreData()) THEN audioFinished := TRUE; END;
					IF Debug THEN
					(*	IF (current.hasVideo = current.hasAudio) & (videoFinished # audioFinished) THEN
							KernelLog.String("MediaPlayer: Audio & Video not finished at the same time."); KernelLog.Ln;
						END; *)
					END;
				END;
				IF (current = NIL) OR ((current # NIL) & current.hasVideo & videoFinished) OR ((current # NIL) & (~current.hasVideo) & audioFinished) THEN
					IF state # Finished THEN
						IF Trace * TracePlayer # {} THEN
							KernelLog.String("MediaPlayer: Finished playing: ");
							IF (current = NIL) THEN KernelLog.String("No context.");
							ELSE
								IF videoFinished THEN KernelLog.String("[Video finished]"); END;
								IF audioFinished THEN KernelLog.String("[Audio finished]"); END;
							END;
							KernelLog.Ln;
						END;
						IF eof # NIL THEN eof.Call; END;
					END;
					SetState(Finished);
				END
			END;
			IF current # NIL THEN
				IF current.hasVideo THEN
					currentTime := 10*current.pos DIV (1000 DIV current.mspf);
				ELSE
					currentTime := current.audio.GetCurrentTime();
				END;
				temp := Kernel.GetTicks();
				callUpdate := (update # NIL) & ((state = Finished) OR (nextState # NoRequest) OR (temp - lastUpdate >= UpdateInterval));
				IF callUpdate THEN lastUpdate := temp; update(state, current.pos, current.maxFrames, currentTime); END;
			ELSE
				IF update # NIL THEN update(state, 0, 0, 0); END;
			END;
		END EvaluateState;

	BEGIN {ACTIVE}
		WHILE state < Closed DO
			(* Synchronization to player commands *)
			BEGIN {EXCLUSIVE} AWAIT((state = Playing) OR (state = Stepping) OR (state = InTransition) OR (state >= Closed) OR (nextState # NoRequest)); END;
			IF state < Closed THEN
				(* Within this IF statement we have exlusive access to all Context objects *)
				(* Render next video/audio frame *)
				IF nextState IN {NoRequest, Stepping} THEN Render(current, next); END;
				(* State management (process state change requests and current state *)
				EvaluateState;
			END;
		END;
	FINALLY
		FreeContext(current); current := NIL;
		FreeContext(next); next := NIL;
		FreeContext(nextContext); nextContext := NIL;
		IF eof # NIL THEN eof.Terminate; END;
		IF pw # NIL THEN pw.Close; pw := NIL; END;
		SetState(Closed);
	END Player;

VAR mplayer : Player;

(** Command line user interface *)

(** Play the specified video/audio file *)
PROCEDURE Open*(context : Commands.Context); (** <filename> ~ *)
VAR filename, msg : ARRAY 256 OF CHAR; res : INTEGER;
BEGIN {EXCLUSIVE}
	context.arg.String(filename);
	IF mplayer = NIL THEN NEW(mplayer); END;
	mplayer.Open(filename, msg, res);
	IF res = Streams.Ok THEN
		mplayer.Play;
	ELSE
		context.error.String("MediaPlayer: Could not open file: "); context.error.String(filename);
		context.error.String(" (res: "); context.error.Int(res, 0); context.error.String(", ");
		context.error.String(msg); context.error.String(")"); context.error.Ln;
	END;
END Open;

PROCEDURE Pause*(context : Commands.Context); (** <filename> ~ *)
VAR filename, msg : ARRAY 256 OF CHAR; res : INTEGER;
BEGIN {EXCLUSIVE}
	context.arg.String(filename);
	IF mplayer # NIL THEN 
		(*mplayer.SetState(Paused);*)
		mplayer.RequestState(Paused, NIL);
	ELSE
		context.error.String("MediaPlayer: no player open "); context.error.Ln; context.error.Update;
	END;
END Pause;

PROCEDURE Step*(context : Commands.Context); (** <filename> ~ *)
VAR filename, msg : ARRAY 256 OF CHAR; res : INTEGER;
BEGIN {EXCLUSIVE}
	IF mplayer # NIL THEN 
		mplayer.Step;
	ELSE
		context.error.String("MediaPlayer: no player open "); context.error.Ln; context.error.Update;
	END;
END Step;

(** Do a transition to the specified video/audio file (of the specified duration) *)
PROCEDURE TransitionTo*(context : Commands.Context); (** <filename> [transitionDuration] ~ *)
VAR filename, msg : ARRAY 256 OF CHAR; duration : SIGNED32; res : INTEGER;
BEGIN {EXCLUSIVE}
	context.arg.SkipWhitespace; context.arg.String(filename);
	context.arg.SkipWhitespace; context.arg.Int(duration, FALSE);
	IF (context.arg.res # Streams.Ok) OR (duration < 1) THEN duration := 25; END;
	IF mplayer # NIL THEN
		mplayer.DoTransition(filename, 0, duration, msg, res);
		IF res # Ok THEN
			context.error.String("MediaPlayer.DoTransition Error (res: "); context.error.Int(res, 0);
			context.error.String(", "); context.error.String(msg); context.error.String(")"); context.error.Ln;
		END;
	ELSE
		NEW(mplayer); mplayer.DoTransition(filename, 0, duration, msg, res);
		IF res # Ok THEN
			context.error.String("MediaPlayer.DoTransition Error (res: "); context.error.Int(res, 0);
			context.error.String(", "); context.error.String(msg); context.error.String(")"); context.error.Ln;
		END;
	END;
END TransitionTo;

(** Close the media player and its window *)
PROCEDURE Close*; (** ~ *)
BEGIN
	Cleanup;
END Close;

(** Set a EOF (end of file) handler, i.e. action to be taken when playing of a ressource finished. *)
PROCEDURE SetEofAction*(context : Commands.Context); (* [none | loop | quit] ~ *)
VAR command : ARRAY 32 OF CHAR;
BEGIN
	IF mplayer # NIL THEN
		context.arg.SkipWhitespace; context.arg.String(command);
		IF Strings.Match("none", command) THEN
			mplayer.eof := NIL;
			context.out.String("MediaPlayer: Set EOF to NIL.");
		ELSIF Strings.Match("loop", command) THEN
			mplayer.SetEofAction(mplayer.Loop);
			context.out.String("MediaPlayer: Set EOF to Loop.");
		ELSIF Strings.Match("quit", command) THEN
			mplayer.SetEofAction(mplayer.Quit);
			context.out.String("MediaPlayer: Set EOF to Quit.");
		ELSE
			context.out.String("MediaPlayer: Command not recognized.");
		END;
	ELSE
		context.error.String("MediaPlayer: Cannot set EOF - player not running."); context.error.Ln;
	END;
	context.out.Ln;
END SetEofAction;

PROCEDURE Cleanup;
BEGIN {EXCLUSIVE}
	IF mplayer # NIL THEN mplayer.Close; mplayer := NIL; END;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END MediaPlayer.

------------------------------------------------------------
i810Sound.Install ~
System.Free MediaPlayer ~
System.Free WMPlayer MediaPlayer DivXDecoder DivXHelper DivXTypes AVI~
PC.Compile AVI.Mod DivXTypes.Mod DivXHelper.Mod DivXDecoder.Mod MediaPlayer.Mod WMPlayer.Mod~

System.Free WMPlayer MediaPlayer ~

WMPlayer.Open flags.avi~

MediaPlayer.Open flags.avi~
MediaPlayer.TransitionTo flags.avi 25 ~
MediaPlayer.TransitionTo flags.avi 300 ~

MediaPlayer.Pause ~
MediaPlayer.Step ~

FfmpegCodecs.Install -f "WORK" ~

MediaPlayer.Open "HIGHDIM:/Data/Sperm/IMSI1.wmv" ~
WMPlayer.Open "HIGHDIM:/Data/Sperm/IMSI1.wmv" ~
MediaPlayer.Open "HIGHDIM:/Data/Sperm/IMSI2.wmv" ~
MediaPlayer.Open "HIGHDIM:/Data/Sperm/IMSI3.wmv" ~
MediaPlayer.Open "HIGHDIM:/Data/Sperm/IMSI4.wmv" ~
MediaPlayer.Open "HIGHDIM:/Data/Sperm/IMSI5.wmv" ~
MediaPlayer.Open "HIGHDIM:/Data/Sperm/IMSI6.wmv" ~

MediaPlayer.Open "HIGHDIM:/Data/Sperm/ICSI_20190905/20190329_155655.mp4" ~
MediaPlayer.Open "HIGHDIM:/Data/Sperm/ICSI_20190905/20190329_160050.mp4" ~
MediaPlayer.Open "HIGHDIM:/Data/Sperm/ICSI_20190905/20190329_163128.mp4" ~

MediaPlayer.Open "HIGHDIM:/Data/Sperm/CRYPTOZOOSPERMIA1.wmv" ~
MediaPlayer.Close ~

MediaPlayer.SetEofAction none ~
MediaPlayer.SetEofAction loop ~
MediaPlayer.SetEofAction quit ~

