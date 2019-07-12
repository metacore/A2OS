MODULE MP3Player; (** AUTHOR "TF,PL"; PURPOSE "MP3 Player"; *)

IMPORT
	SoundDevices, Codecs, WMDialogs, KernelLog, Streams, Files, Commands;

CONST
	Title = "MP3 Player";

TYPE
	Player*= OBJECT
	VAR decoder : Codecs.AudioDecoder;
		soundDevice : SoundDevices.Driver;
		playChannel : SoundDevices.Channel;
		bufferPool : SoundDevices.BufferPool;
		buffer : SoundDevices.Buffer;
		in : Streams.Reader;
		channels, rate, bits : LONGINT;

		ready, paused, finished : BOOLEAN;
		pos, oldPos : LONGINT;

		setup* : PROCEDURE {DELEGATE} (canSeek: BOOLEAN; totTime, totSamp : LONGINT);
		update* : PROCEDURE {DELEGATE} (status: BOOLEAN; pos, displayTime: LONGINT);
		eof* : PROCEDURE {DELEGATE} (sender, data: ANY);

		(* Initialize Player with the given File *)
		PROCEDURE &Init*(in : Streams.Reader; length: LONGINT);
		VAR i: LONGINT; res: WORD;
		BEGIN
			ready := FALSE; finished := FALSE; paused := FALSE; oldPos := 0;
			SELF.in := in;

			decoder := Codecs.GetAudioDecoder("MP3");
			IF decoder = NIL THEN
				WMDialogs.Error("Error", "MP3 decoder not installed");
				RETURN
			END;

			soundDevice := SoundDevices.GetDefaultDevice();
			NEW(bufferPool, 10);
			FOR i := 0 TO 9 DO
				NEW(buffer); buffer.len := 4096; NEW(buffer.data, 4096);
				bufferPool.Add(buffer)
			END;

			decoder.Open(in, res);
			IF res # 0 THEN
				WMDialogs.Error(Title, "File not compatible.");
				RETURN
			END;

			(* Pass the length Information to the Decoder... *)
			decoder.SetStreamLength(length);

			decoder.GetAudioInfo(channels, rate, bits);
			soundDevice.OpenPlayChannel(playChannel, rate, bits, channels, SoundDevices.FormatPCM, res);
			IF playChannel = NIL THEN
				WMDialogs.Error(Title, "Could not open play channel");
				RETURN
			END;
			playChannel.RegisterBufferListener(bufferPool.Add);
			playChannel.SetVolume(255);

			ready := TRUE
		END Init;

		PROCEDURE Play*;
		BEGIN {EXCLUSIVE}
			playChannel.Start
		END Play;

		PROCEDURE Stop*;
		VAR res : WORD;
		BEGIN {EXCLUSIVE}
			(* playChannel.Stop *)
			playChannel.Pause;
			decoder.SeekSample(0, FALSE, res);
			pos := decoder.GetCurrentTime();
			IF update # NIL THEN update(paused, pos, pos) END
		END Stop;

		PROCEDURE Pause*;
		BEGIN {EXCLUSIVE}
			IF paused THEN playChannel.Start; paused := FALSE
			ELSE playChannel.Pause; paused := TRUE END
		END Pause;

		(* set in 1/10 sec *)
		PROCEDURE SetPos*(pos: LONGINT);
		VAR res : WORD;
		BEGIN {EXCLUSIVE}
			pos := ENTIER(pos / 10 * rate);
			decoder.SeekSample(pos, FALSE, res);
			pos := decoder.GetCurrentTime();
			IF update # NIL THEN update(paused, pos, pos) END
		END SetPos;

		(* get in  1/10 sec *)
		PROCEDURE GetPos*(): LONGINT;
		BEGIN {EXCLUSIVE}
			RETURN decoder.GetCurrentTime()
		END GetPos;

		PROCEDURE Close*;
		BEGIN {EXCLUSIVE}
			finished := TRUE;
		END Close;

	BEGIN	{ACTIVE}
		IF ready THEN
			IF setup # NIL THEN setup(TRUE, ENTIER(decoder.GetTotalSamples()/rate*10), ENTIER(decoder.GetTotalSamples()/rate*10)) END;

			WHILE decoder.HasMoreData() & ~finished DO
				buffer := bufferPool.Remove();
				decoder.FillBuffer(buffer);
				playChannel.QueueBuffer(buffer);
				pos := decoder.GetCurrentTime();
				IF (update # NIL) & (pos # oldPos) THEN update(paused, pos, pos) END;
				oldPos := pos
			END;
			playChannel.Close;
			KernelLog.String("finished playing..."); KernelLog.Ln;
			IF eof # NIL THEN eof(SELF, NIL) END
		END
	END Player;

VAR player : Player;

PROCEDURE Open*(context : Commands.Context);
VAR
	filename : ARRAY 256 OF CHAR;
	file : Files.File;
	in : Streams.Reader;
BEGIN
	context.arg.String(filename);

	in := Codecs.OpenInputStream(filename);
	IF in = NIL THEN
		WMDialogs.Error(Title, "File not found");
		RETURN;
	END;

	file := Files.Old(filename);
	NEW(player, in, file.Length());
	player.Play;
END Open;

PROCEDURE Stop*;
BEGIN
	player.Stop;
END Stop;

END MP3Player.


------------------------------------------------------------
i810Sound.Install ~
System.Free MP3Player ~

MP3Player.Open htf_44_128.mp3~
MP3Player.Open track.mp3~
MP3Player.Stop~

MP3Player.Open "FAT:/Audio/MP3/MVP/H01 Kopie.mp3"~
MP3Player.Open "FAT:/Audio/MP3/Mpegger/H01 Kopie 1.mp3"~
MP3Player.Open "FAT:/Audio/MP3/AMAZING/H01 Kopie 1.mp3"~
