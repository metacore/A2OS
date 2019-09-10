MODULE WAVRecorder; (** AUTHOR "TF,PL"; PURPOSE "WAV Recorder"; *)

IMPORT
	SoundDevices, Codecs, WMDialogs, KernelLog, Streams, Files, Commands, Kernel;

CONST
	Title = "WAV Recorder";

TYPE
	Recorder*= OBJECT
	VAR encoder : Codecs.AudioEncoder;
		soundDevice : SoundDevices.Driver;
		recChannel : SoundDevices.Channel;
		bufferPool : SoundDevices.BufferPool;
		buffer : SoundDevices.Buffer;
		out : Streams.Writer;
		channels, rate, bits : SIGNED32;
		recLength: SIZE;
		t : Kernel.Timer;

		ready, recording, paused, finished : BOOLEAN;

		(* Initialize Recorder with the given File *)
		PROCEDURE &Init*(out : Streams.Writer);
		VAR i: SIGNED32; res: INTEGER;
		BEGIN
			ready := FALSE; recording := FALSE; paused := FALSE; finished := FALSE;
			SELF.out := out; recLength := 0;

			(* set channel properties *)
			channels := 2;
			rate := 44100;
			bits := 16;

			encoder := Codecs.GetAudioEncoder("WAV");
			IF encoder = NIL THEN
				WMDialogs.Error(Title, "WAV encoder not installed");
				RETURN
			END;

			soundDevice := SoundDevices.GetDefaultDevice();
			NEW(bufferPool, 10);
			FOR i := 0 TO 9 DO
				NEW(buffer); buffer.len := 4096; NEW(buffer.data, 4096);
				bufferPool.Add(buffer)
			END;

			encoder.Open(out, rate, bits, channels, res);
			IF res # 0 THEN
				WMDialogs.Error(Title, "Header could not be written.");
				RETURN
			END;

			soundDevice.OpenRecordChannel(recChannel, rate, bits, channels, SoundDevices.FormatPCM, res);
			IF recChannel = NIL THEN
				WMDialogs.Error(Title, "Could not open record channel");
				RETURN
			END;
			recChannel.RegisterBufferListener(WriteBuffer);
			recChannel.SetVolume(255);

			ready := TRUE
		END Init;

		PROCEDURE WriteBuffer(buf : SoundDevices.Buffer);
		VAR res : INTEGER;
		BEGIN
			encoder.Write(buf, res);
			INC(recLength, buf.len);
			bufferPool.Add(buf)
		END WriteBuffer;

		PROCEDURE Start*;
		BEGIN {EXCLUSIVE}
			IF ready THEN recChannel.Start; NEW(t); t.Sleep(100); recording := TRUE;  END
		END Start;

		PROCEDURE Stop*;
		BEGIN {EXCLUSIVE}
			IF ready & recording THEN
				recording := FALSE;
				recChannel.Stop;
			END
		END Stop;

		PROCEDURE Pause*;
		BEGIN {EXCLUSIVE}
			IF paused THEN recChannel.Start; paused := FALSE; recording := TRUE;
			ELSE recChannel.Pause; paused := TRUE; recording := FALSE END
		END Pause;

		PROCEDURE Close*;
		BEGIN {EXCLUSIVE}
			finished := TRUE;
			recording := TRUE
		END Close;

		PROCEDURE GetLength*() : SIZE;
		BEGIN
			RETURN recLength;
		END GetLength;

	BEGIN {ACTIVE}
		IF ready THEN

			WHILE  ~finished DO
				BEGIN {EXCLUSIVE}
					buffer := bufferPool.Remove();
					recChannel.QueueBuffer(buffer);
					AWAIT(recording);
				END
			END;
			NEW(t); t.Sleep(1000);
			recChannel.Close;
			KernelLog.String("finished recording..."); KernelLog.Ln;
		END
	END Recorder;

	Bridge*= OBJECT
	VAR soundDevice : SoundDevices.Driver;
		recChannel : SoundDevices.Channel;
		playChannel : SoundDevices.Channel;
		bufferPool : SoundDevices.BufferPool;
		buffer : SoundDevices.Buffer;
		channels, rate, bits : SIGNED32;
		t : Kernel.Timer;

		ready, recording, paused, finished : BOOLEAN;

		(* Initialize Recorder with the given File *)
		PROCEDURE &Init*;
		VAR i, res : INTEGER;
		BEGIN
			ready := FALSE; recording := FALSE; paused := FALSE; finished := FALSE;

			(* set channel properties *)
			channels := 2;
			rate := 44100;
			bits := 16;

			(* get device *)
			soundDevice := SoundDevices.GetDefaultDevice();
			NEW(bufferPool, 10);
			FOR i := 0 TO 9 DO
				NEW(buffer); buffer.len := 4096; NEW(buffer.data, 4096);
				bufferPool.Add(buffer)
			END;

			(* open play channel *)
			soundDevice.OpenPlayChannel(playChannel, rate, bits, channels, SoundDevices.FormatPCM, res);
			IF playChannel = NIL THEN
				WMDialogs.Error(Title, "Could not open play channel");
				RETURN
			END;
			playChannel.RegisterBufferListener(bufferPool.Add);
			playChannel.SetVolume(255);

			(* open record channel *)
			soundDevice.OpenRecordChannel(recChannel, rate, bits, channels, SoundDevices.FormatPCM, res);
			IF recChannel = NIL THEN
				WMDialogs.Error(Title, "Could not open record channel");
				RETURN
			END;
			recChannel.RegisterBufferListener(playChannel.QueueBuffer);
			recChannel.SetVolume(255);

			ready := TRUE
		END Init;

		PROCEDURE Start*;
		BEGIN {EXCLUSIVE}
			IF ready THEN recChannel.Start; playChannel.Start; NEW(t); t.Sleep(100); recording := TRUE;  END
		END Start;

		PROCEDURE Stop*;
		BEGIN {EXCLUSIVE}
			IF ready & recording THEN
				recording := FALSE;
				recChannel.Stop;
				playChannel.Stop
			END
		END Stop;

		PROCEDURE Pause*;
		BEGIN {EXCLUSIVE}
			IF paused THEN recChannel.Start; playChannel.Start; paused := FALSE; recording := TRUE;
			ELSE recChannel.Pause; playChannel.Pause; paused := TRUE; recording := FALSE END
		END Pause;

		PROCEDURE Close*;
		BEGIN {EXCLUSIVE}
			finished := TRUE;
			recording := TRUE
		END Close;

	BEGIN {ACTIVE}
		IF ready THEN

			WHILE  ~finished DO
				BEGIN {EXCLUSIVE}
					buffer := bufferPool.Remove();
					recChannel.QueueBuffer(buffer);
					AWAIT(recording);
				END
			END;
			NEW(t); t.Sleep(1000);
			recChannel.Close;
			playChannel.Close;
			KernelLog.String("finished bridging..."); KernelLog.Ln;
		END
	END Bridge;

VAR recorder : Recorder;
	bridge : Bridge;
	file : Files.File;
	filename : ARRAY 256 OF CHAR;

PROCEDURE WriteRawBELongInt(VAR w: Files.Writer; value: SIZE);
BEGIN
	w.Char(CHR(value MOD 100H));
	value := value DIV 100H;
	w.Char(CHR(value MOD 100H));
	value := value DIV 100H;
	w.Char(CHR(value MOD 100H));
	w.Char(CHR(value DIV 100H));
END WriteRawBELongInt;

PROCEDURE Open*(context : Commands.Context);
VAR out : Files.Writer;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(filename);
	file := Files.New(filename);
	IF file = NIL THEN
		WMDialogs.Error(Title, "Could not create file");
		RETURN;
	END;
	Files.OpenWriter(out, file, 0);

	NEW(recorder, out);
	recorder.Start;
	context.out.String("Started recording"); context.out.Ln;
END Open;

PROCEDURE Stop*(context : Commands.Context);
VAR writer : Files.Writer;
	length : SIZE;
BEGIN
	IF recorder = NIL THEN RETURN END;
	length := recorder.GetLength() + 44;
	recorder.Close;
	Files.Register(file);
	file.Update;

	file := Files.Old(filename);
	(* Update header info *)
	Files.OpenWriter(writer, file, 4);
	WriteRawBELongInt(writer, length-8);
	writer.Update;
	Files.OpenWriter(writer, file, 40);
	WriteRawBELongInt(writer, length-44);
	writer.Update;
	Files.Register(file);
	file.Update;
	context.out.String("Stopped recording. Data written to "); context.out.String(filename); context.out.Ln;
END Stop;

PROCEDURE StartBridge*;
BEGIN
	NEW(bridge);
	bridge.Start;
END StartBridge;

PROCEDURE StopBridge*;
BEGIN
	IF (bridge # NIL) THEN bridge.Close; END;
END StopBridge;

END WAVRecorder.


------------------------------------------------------------
i810Sound.Install ~
System.Free WAVRecorder ~

WAVRecorder.Open test.wav~
WAVRecorder.Stop~

WAVRecorder.StartBridge~
WAVRecorder.StopBridge~
