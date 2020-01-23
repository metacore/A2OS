MODULE WMBassDSPTest; (** AUTHOR "SAGE"; PURPOSE "BASS 2.4 A2 OS Wrapper - BASS simple DSP Test"; *)

IMPORT
	SYSTEM, Math, Modules, Commands, Strings, Files, Codecs, Streams,
	XML, WMComponents, WMWindowManager, WMDialogs, WMStandardComponents,
	BASS, MathUtils, Generics;

CONST
	ECHBUFLEN = 1200;	(* buffer length *)
	FLABUFLEN = 350;		(* buffer length *)

TYPE
	DWORD = LONGINT;
	HDSP = LONGINT;

	FileName = ARRAY Files.NameLength + 1 OF CHAR;

	Window = OBJECT(WMComponents.FormWindow)
	VAR
		btnOpen: WMStandardComponents.Button;
		chbRotate,
		chbEcho,
		chbFlanger: WMStandardComponents.Checkbox;

		PROCEDURE WireEvents;
		BEGIN
			btnOpen.onClick.Add(OpenOnClick);
			chbRotate.onClick.Add(RotateOnClick);
			chbEcho.onClick.Add(EchoOnClick);
			chbFlanger.onClick.Add(FlangerOnClick);
		END WireEvents;

		PROCEDURE FormInit;
		BEGIN
			SetTitle(Strings.NewString("BASS simple DSP Test"));
			chbRotate.hasThreeStates.Set(FALSE);
			chbEcho.hasThreeStates.Set(FALSE);
			chbFlanger.hasThreeStates.Set(FALSE);
			WireEvents
		END FormInit;

		PROCEDURE OpenOnClick(sender, par: ANY);
		VAR
			sName: FileName;
			sFullPath: FileName;
			res: LONGINT;
			r: Streams.Reader;
			info: BASS.BASS_CHANNELINFO;
			x, y: LONGINT;
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.OpenOnClick, sender, par)
			ELSE
				DialogPos(x, y, SELF, 350, 100);
				IF (WMDialogs.QueryStringXY(x, y, "Open file", sName) = WMDialogs.ResOk)
					& (sName # "")
				THEN

					r := Codecs.OpenInputStream(sName);
					IF r # NIL THEN
						(* File exists, get full path *)
						r(Codecs.FileInputStream).f.GetName(sFullPath);
					ELSE
						context.out.String("File doesn't exist"); context.out.Ln;
						context.out.Update;
						RETURN
					END;

					context.out.String("Full path: ");
					context.out.String(sFullPath);
					context.out.Ln;
					context.out.Update;

					(* free both MOD and stream, it must be one of them! :) *)
					res := BASS.BASS_MusicFree(chan);
					res := BASS.BASS_StreamFree(chan);

					chan := BASS.BASS_StreamCreateFile(0, ADDRESSOF(sFullPath), 0, 0,
						floatable + BASS.BASS_SAMPLE_LOOP);
					IF (chan = 0) THEN
						chan := BASS.BASS_MusicLoad(0, ADDRESSOF(sFullPath), 0, 0,
							floatable + BASS.BASS_MUSIC_LOOP + BASS.BASS_MUSIC_RAMPS, 1)
					END;
					IF chan = 0 THEN
						(* whatever it is, it ain't playable *)
						btnOpen.caption.Set(Strings.NewString("click here to open a file..."));
						context.out.String("Can't play the file");
						context.out.Ln;
						context.out.Update;
						RETURN
					END;

					res := BASS.BASS_ChannelGetInfo(chan, info);
					IF info.chans # 2 THEN (* only stereo is allowed *)
						btnOpen.caption.Set(Strings.NewString("click here to open a file..."));
						res := BASS.BASS_MusicFree(chan);
						res := BASS.BASS_StreamFree(chan);
						context.out.String("Only stereo sources are supported");
						context.out.Ln;
						context.out.Update;
						RETURN
					END;

					btnOpen.caption.Set(Strings.NewString(sFullPath));

					(* setup DSPs on new channel *)
					(*CheckBox1.OnClick(Self);
					CheckBox2.OnClick(Self);
					CheckBox3.OnClick(Self);*)

					(* play both MOD and stream, it must be one of them! *)
					res := BASS.BASS_ChannelPlay(chan, 0)
				END

			END
		END OpenOnClick;

		PROCEDURE RotateOnClick(sender, par: ANY);
		VAR
			res: LONGINT;
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.RotateOnClick, sender, par)
			ELSE
				IF chbRotate.state.Get() = 1 THEN
					rotpos := 0.7853981;
					rotdsp := BASS.BASS_ChannelSetDSP(chan, Rotate, 0, 2);
				ELSE
					res := BASS.BASS_ChannelRemoveDSP(chan, rotdsp)
				END
			END
		END RotateOnClick;

		PROCEDURE EchoOnClick(sender, par: ANY);
		VAR
			i, j, res: LONGINT;
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.EchoOnClick, sender, par)
			ELSE
				IF chbEcho.state.Get() = 1 THEN
					FOR i := 0 TO LEN(echbuf, 0) - 1 DO
						FOR j := 0 TO LEN(echbuf, 1) - 1 DO
							echbuf[i][j] := 0.0
						END
					END;
					echpos := 0;
					echdsp := BASS.BASS_ChannelSetDSP(chan, Echo, 0, 1);
				ELSE
					res := BASS.BASS_ChannelRemoveDSP(chan, echdsp)
				END
			END
		END EchoOnClick;

		PROCEDURE FlangerOnClick(sender, par: ANY);
		VAR
			i, j, res: LONGINT;
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.FlangerOnClick, sender, par)
			ELSE

				IF chbFlanger.state.Get() = 1 THEN
					FOR i := 0 TO LEN(flabuf, 0) - 1 DO
						FOR j := 0 TO LEN(flabuf, 1) - 1 DO
							flabuf[i][j] := 0.0
						END
					END;

					flapos := 0;
					flas := FLABUFLEN / 2;
					flasinc := 0.002;
					fladsp := BASS.BASS_ChannelSetDSP(chan, Flanger, 0, 0);
				ELSE
					res := BASS.BASS_ChannelRemoveDSP(chan, fladsp)
				END

			END
		END FlangerOnClick;

		PROCEDURE Close;
		VAR
			res: LONGINT;
		BEGIN
			Close^;
			IF bBASSInitialized THEN
				res := BASS.BASS_Stop();
				IF BASS.BASS_Free() # 0 THEN
					context.out.String("BASS freed");
					context.out.Ln
				ELSE
					context.out.String("BASS didn't freed");
					context.out.Ln
				END;
				context.out.Update;
			END;
			window := NIL
		END Close;

	END Window;

VAR
	window: Window;
	context: Commands.Context;
	bBASSInitialized: BOOLEAN;
	floatable: SET;		(* floating-point channel support? *)

	chan: DWORD;				(* the channel... HMUSIC or HSTREAM *)

	rotdsp: HDSP;			(* DSP handle *)
	rotpos: REAL;			(* cur.pos *)

	echdsp: HDSP;			(* DSP handle *)
	echbuf: ARRAY ECHBUFLEN OF ARRAY 2 OF REAL;	(* buffer *)
	echpos: LONGINT;		(* cur.pos *)

	fladsp: HDSP;			(* DSP handle *)
	flabuf: ARRAY FLABUFLEN OF ARRAY 2 OF REAL;	(* buffer *)
	flapos: LONGINT;		(* cur.pos *)
	flas,
	flasinc: REAL;			(* sweep pos/increment *)

PROCEDURE fmod(a, b: REAL): REAL;
BEGIN
	RETURN a - (b * MathUtils.trunc(a / b));
END fmod;

PROCEDURE {WINAPI} Rotate(handle: HDSP; channel: DWORD; buffer: ADDRESS; length: DWORD; user: ADDRESS);
VAR
	offset: DWORD;
BEGIN

	offset := 0;
	WHILE offset < length DO
		SYSTEM.PUT(buffer + offset,
			SYSTEM.VAL(REAL, SYSTEM.GET32(buffer + offset)) * ABS(Math.sin(rotpos)));
		INC(offset, 4);
		SYSTEM.PUT(buffer + offset,
			SYSTEM.VAL(REAL, SYSTEM.GET32(buffer + offset)) * ABS(Math.cos(rotpos)));
		rotpos := fmod(rotpos + 0.00003, Math.pi);
		INC(offset, 4)
	END

END Rotate;

PROCEDURE {WINAPI} Echo(handle: HDSP; channel: DWORD; buffer: ADDRESS; length: DWORD; user: ADDRESS);
VAR
	offset: DWORD;
	l, r: REAL;
BEGIN

	offset := 0;
	WHILE offset < length DO

		l := SYSTEM.VAL(REAL, SYSTEM.GET32(buffer + offset)) + (echbuf[echpos, 1] / 2);
		INC(offset, 4);
		r := SYSTEM.VAL(REAL, SYSTEM.GET32(buffer + offset)) + (echbuf[echpos, 0] / 2);
		DEC(offset, 4);

		(* Basic "bathroom" reverb *)
		SYSTEM.PUT(buffer + offset, l);
		echbuf[echpos, 0] := l;
		INC(offset, 4);
		SYSTEM.PUT(buffer + offset, r);
		echbuf[echpos, 1] := r;

		INC(echpos);
		IF echpos = ECHBUFLEN THEN
			echpos := 0
		END;
		INC(offset, 4)

	END

END Echo;

PROCEDURE {WINAPI} Flanger(handle: HDSP; channel: DWORD; buffer: ADDRESS; length: DWORD; user: ADDRESS);
VAR
	offset: DWORD;
	d, f, s: REAL;
	p1, p2: LONGINT;
BEGIN

	offset := 0;
	WHILE offset < length DO

		p1 := MathUtils.trunc(flapos + flas) MOD FLABUFLEN;
		p2 := (p1 + 1) MOD FLABUFLEN;
		f := fmod(flas, 1);

		d := SYSTEM.VAL(REAL, SYSTEM.GET32(buffer + offset));
		s := d + ((flabuf[p1, 0] * (1 - f)) + (flabuf[p2, 0] * f));
		flabuf[flapos, 0] := d;
		SYSTEM.PUT(buffer + offset, s);

		INC(offset, 4);

		d := SYSTEM.VAL(REAL, SYSTEM.GET32(buffer + offset));
		s := d + ((flabuf[p1, 1] * (1 - f)) + (flabuf[p2, 1] * f));
		flabuf[flapos, 1] := d;
		SYSTEM.PUT(buffer + offset, s);

		INC(flapos);
		IF flapos = FLABUFLEN THEN
			flapos := 0
		END;

		flas := flas + flasinc;
		IF (flas < 0.0) OR (flas > FLABUFLEN) THEN
			flasinc := -flasinc
		END;

		INC(offset, 4)

	END

END Flanger;

PROCEDURE DialogPos(VAR x, y: LONGINT; win: WMWindowManager.Window; dlgWidth, dlgHeight: LONGINT);
VAR
	manager: WMWindowManager.WindowManager;
	s: WMWindowManager.WindowStyle;
BEGIN
	manager := WMWindowManager.GetDefaultManager();
	s := manager.GetStyle();
	x := ENTIER(win.bounds.l + (win.bounds.r - win.bounds.l - dlgWidth) / 2);
	y := ENTIER(win.bounds.t + (win.bounds.b - win.bounds.t - dlgHeight) / 2);
	(*IF s # NIL THEN y := y +  s.th END;*)
END DialogPos;

PROCEDURE BASS_CheckVersion(context: Commands.Context): BOOLEAN;
BEGIN
	IF (BASS.BASS_GetVersion() DIV 10000H) MOD 10000H = BASS.BASSVERSION THEN
		RETURN TRUE
	ELSE
		context.out.String("An incorrect version of BASS library was loaded");
		context.out.Ln;
		context.out.Update;
		RETURN FALSE
	END
END BASS_CheckVersion;

PROCEDURE FindComponents(c: XML.Content; data: ANY);
VAR
	comp: WMComponents.Component;
	sUID: Strings.String;
BEGIN
	IF c IS WMComponents.Component THEN
		comp := c(WMComponents.Component);
		sUID := comp.uid.Get();
		IF (sUID # NIL) & (sUID^ # "") THEN
			data(Generics.ObjectMap).Insert(sUID, comp)
		END
	END
END FindComponents;

PROCEDURE WireComponents(root: WMComponents.VisualComponent; win: Window): BOOLEAN;
VAR
	trap: BOOLEAN;
	components: Generics.ObjectMap;
BEGIN
	trap := FALSE;

	NEW(components);
	root.Traverse(FindComponents, components);

	win.btnOpen := components.GetAOC("btnOpen")(WMStandardComponents.Button);
	win.chbRotate := components.GetAOC("chbRotate")(WMStandardComponents.Checkbox);
	win.chbEcho := components.GetAOC("chbEcho")(WMStandardComponents.Checkbox);
	win.chbFlanger := components.GetAOC("chbFlanger")(WMStandardComponents.Checkbox);

FINALLY

	RETURN ~trap

END WireComponents;

PROCEDURE WindowGenerator*(ctx: Commands.Context): WMWindowManager.Window;
VAR
	xml: XML.Content;
	root: WMComponents.VisualComponent;
	x, y, res: LONGINT;
	manager: WMWindowManager.WindowManager;

BEGIN
	IF (window = NIL) & BASS_CheckVersion(ctx) THEN
		context := ctx;
		bBASSInitialized := FALSE;

		xml := WMComponents.Load("WMBassDSPTest.xml");
		IF (xml # NIL) & (xml IS WMComponents.VisualComponent) THEN

			root := xml(WMComponents.VisualComponent);

			(* Window setup *)
			NEW(window, root.bounds.GetWidth(), root.bounds.GetHeight(), FALSE);
			window.SetContent(root);
			IF ~WireComponents(root, window) THEN
				context.out.String("Form resource corrupted"); context.out.Ln;
				context.out.Update;
				RETURN NIL
			END;

			IGNORE BASS.BASS_SetConfig(BASS.BASS_CONFIG_FLOATDSP, 1);
			IF BASS.BASS_Init(-1, 44100, {}, 0, NIL) = 0 THEN
				context.out.String("Can't initialize output device"); context.out.Ln;
				context.out.Update;
				RETURN NIL
			END;

			context.out.String("BASS initialized"); context.out.Ln;
			context.out.Update;
		  bBASSInitialized := TRUE;

		  floatable := {};
		  res := BASS.BASS_StreamCreate(44100, 2, BASS.BASS_SAMPLE_FLOAT, NIL, 0);
			IF res > 0 THEN
				IGNORE BASS.BASS_StreamFree(res);
				floatable := BASS.BASS_SAMPLE_FLOAT;
				context.out.String("Floating-point samples supported"); context.out.Ln;
				context.out.Update;
			ELSE
				context.out.String("Floating-point samples not supported"); context.out.Ln;
				context.out.Update;
			END;

			(* Initialize form and wire event handlers *)
			window.FormInit;

			(* Form show *)
			WMDialogs.DefaultPos(x, y, window.GetWidth(), window.GetHeight());
			WMWindowManager.ExtAddWindow(	window, x, y,
				{WMWindowManager.FlagFrame, WMWindowManager.FlagClose,
					WMWindowManager.FlagMinimize, WMWindowManager.FlagNoResizing});
			manager := WMWindowManager.GetDefaultManager();
			manager.SetFocus(window);

			RETURN window

	  END
	END
END WindowGenerator;

PROCEDURE Open*(ctx: Commands.Context);
VAR
	wDummy: WMWindowManager.Window;
BEGIN
	IF window = NIL THEN
		wDummy := WindowGenerator(ctx)
	END
END Open;

PROCEDURE Cleanup;
BEGIN
	IF window # NIL THEN
		window.Close;
	END
END Cleanup;

(*
PROCEDURE Test*(c: Commands.Context);
VAR
	fa: ARRAY 4 OF REAL;
	a: ADDRESS;
	f: REAL;
	i: LONGINT;

BEGIN
	fa[0] := 1.2;
	fa[1] := 3.4;
	fa[2] := 5.6;
	fa[3] := 7.8;
	a := ADDRESSOF(fa);

	FOR i := 0 TO 3 DO
		f := SYSTEM.VAL(REAL, SYSTEM.GET32(a));
		c.out.Float(fa[i], 16);
		c.out.Ln;
		f := f + 0.1;
		SYSTEM.PUT(a, f);
		INC(a, 4)
	END;

	c.out.Ln;

	FOR i := 0 TO 3 DO
		c.out.Float(fa[i], 16);
		c.out.Ln
	END;

	c.out.Update
END Test;
*)

BEGIN
	bBASSInitialized := FALSE;
	Modules.InstallTermHandler(Cleanup)
END WMBassDSPTest.

WMBassDSPTest.Open ~
SystemTools.Free WMBassDSPTest ~



