MODULE BassSound; (** AUTHOR "Yaroslav Romanchenko (SAGE)"; PURPOSE "A2 BASS Sound driver"; *)

IMPORT
	Commands, Plugins, Modules, Strings, SoundDevices, KernelLog, BASS;

CONST
	FREQ = 48000;
	SDriverDesc = "BASS library sound driver";

TYPE
	MixerKind = ENUM MasterOut, MasterIn END;

	PlayChannelList = POINTER TO RECORD
		channel : PlayChannel;
		next : PlayChannelList;
	END;

	RecChannelList = POINTER TO RECORD
		channel : RecChannel;
		next : RecChannelList;
	END;

	MixerChangedProcList = POINTER TO RECORD
		mixerChangedProc : SoundDevices.MixerChangedProc;
		next : MixerChangedProcList;
	END;

	PlayChannel = OBJECT(SoundDevices.Channel);
	VAR
		bassChannel: BASS.HSTREAM;

		PROCEDURE &Constr(VAR channel: SoundDevices.Channel; samplingRate, samplingResolution, nofSubChannels: SIGNED32; VAR res: INTEGER);
		VAR
			flags: SET32;
		BEGIN
			channel := NIL;
			res := SoundDevices.ResOK;
			flags := {};

			IF samplingResolution = 8 THEN
				flags := flags + BASS.BASS_SAMPLE_8BITS
			END;

			bassChannel := BASS.BASS_StreamCreate(samplingRate, nofSubChannels, flags, BASS.STREAMPROC_PUSH, 0);
			IF bassChannel # 0 THEN

				(* Set Pan to center *)
				IGNORE BASS.BASS_ChannelSetAttribute(bassChannel, BASS.BASS_ATTRIB_PAN, 0);

				(* Play *)
				IGNORE BASS.BASS_ChannelPlay(bassChannel, 0);

				(*driver.RegisterMixerChangeListener(MixerChangedProc);*)
				channel := SELF

			END
		END Constr;

		(*PROCEDURE MixerChangedProc(mixerChannel: SoundDevices.MixerChannel);
		BEGIN
			BassSetVolume(bassChannel, mixerChannel(MixerChannel).volume)
		END MixerChangedProc;*)

		(** Return if the channel is ChannelPlay or ChannelRecord *)
		PROCEDURE GetChannelKind*() : SIGNED32;
		BEGIN
			RETURN SoundDevices.ChannelPlay
		END GetChannelKind;

		(** Set the current volume of the channel *)
		(** Volume is a 8.8 bit fix-point value, 0 is silent *)
		PROCEDURE SetVolume*(volume: SIGNED32);
		BEGIN
			BassSetChannelVolume(bassChannel, volume)
		END SetVolume;

		(** Get the current volume of the channel *)
		PROCEDURE GetVolume*() : SIGNED32;
		BEGIN
			RETURN BassGetChannelVolume(bassChannel)
		END GetVolume;

		(** GetPosition return the current position in samples. MAY CHANGE TO SIGNED64*)
		PROCEDURE GetPosition*() : SIGNED32;
		BEGIN HALT(99) (* abstract *)
		END GetPosition;

		(** Register a delegate that handles reuse / processing of buffers. Only one Buffer listener can be registered
		per channel *)
		PROCEDURE RegisterBufferListener*(bufferListener : SoundDevices.BufferListener);
		BEGIN HALT(99) (* abstract *)
		END RegisterBufferListener;

		(** Start playing / recording *)
		PROCEDURE Start*;
		BEGIN HALT(99) (* abstract *)
		END Start;

		(** Queue another buffer for playing / recording *)
		PROCEDURE QueueBuffer*(x : SoundDevices.Buffer);
		BEGIN HALT(99) (* abstract *)
		END QueueBuffer;

		(** Pause playing / recording, no buffers are returned *)
		PROCEDURE Pause*;
		BEGIN HALT(99) (* abstract *)
		END Pause;

		(** Stop the playing / recording and return all buffers *)
		PROCEDURE Stop*;
		BEGIN HALT(99) (* abstract *)
		END Stop;

		(** The channel is closed, the driver may release any ressources reserved for it. The object is still there
			but can never be opened again*)
		PROCEDURE Close*;
		BEGIN HALT(99) (* abstract *)
		END Close;
	END PlayChannel;

	RecChannel = OBJECT(SoundDevices.Channel);
	END RecChannel;

	MixerChannel = OBJECT(SoundDevices.MixerChannel)
	VAR
		driver: Driver;
		mixerKind: MixerKind;
		name, desc: Strings.String;
		volume, muteVol: SIGNED32;
		mute: BOOLEAN;

		PROCEDURE &Constr*(driver: Driver; mixerKind: MixerKind; mute: BOOLEAN; name, desc: ARRAY OF CHAR);
		BEGIN
			SELF.driver := driver;
			SELF.mixerKind := mixerKind;
			volume := 128;
			SELF.mute := mute;
			SELF.name := Strings.NewString(name);
			SELF.desc := Strings.NewString(desc);
			SetVolume(volume)
		END Constr;

		PROCEDURE GetName*(VAR name: ARRAY OF CHAR);
		BEGIN
			COPY(SELF.name^, name)
		END GetName;

		PROCEDURE GetDesc*(VAR desc: ARRAY OF CHAR);
		BEGIN
			COPY(SELF.desc^, desc)
		END GetDesc;

		PROCEDURE SetVolume*(volume: SIGNED32);
		BEGIN
			ASSERT((volume >= 0) & (volume <= 255));
			SELF.volume := volume;
			BassSetMixerVolume(mixerKind, volume);
			CallMixerListeners
		END SetVolume;

		PROCEDURE GetVolume*() : SIGNED32;
		BEGIN
			RETURN volume
		END GetVolume;

		(* Volume has to be 0 <= volume < 256 *)
		PROCEDURE SetMute*(mute : BOOLEAN);
		BEGIN
			SELF.mute := mute;
			IF mute THEN muteVol := volume; volume := 0
			ELSE volume := muteVol END;
			BassSetMixerVolume(mixerKind, volume);
			CallMixerListeners
		END SetMute;

		PROCEDURE GetIsMute*() : BOOLEAN;
		BEGIN
			RETURN SELF.mute
		END GetIsMute;

		PROCEDURE CallMixerListeners;
		VAR
			item: MixerChangedProcList;
		BEGIN
			item := driver.firstMixerChangedProc;
			WHILE item # NIL DO
				item.mixerChangedProc(SELF);
				item := item.next
			END
		END CallMixerListeners;

	END MixerChannel;

	Driver* = OBJECT(SoundDevices.Driver)
	VAR
		DriverTab: Plugins.Table;
		(*masterIn, masterOut: MixerChannel;*)

		firstPlayChannel: PlayChannelList;
		firstRecChannel: RecChannelList;
		firstMixerChangedProc: MixerChangedProcList;

		bassPlayChannel: BASS.HSTREAM;

		PROCEDURE &Constr*;
		VAR
			res: INTEGER;
		BEGIN
			desc := SDriverDesc;
			(* Register Driver in SoundDevices *)
			SoundDevices.devices.Add(SELF, res);
			ASSERT(res = Plugins.Ok);
			(* Update driver table *)
			SoundDevices.devices.GetAll(DriverTab);
			masterOut := NEW MixerChannel(SELF, MixerKind.MasterOut, FALSE, "Master out", "Master Output mixer channel");
			masterIn := NEW MixerChannel(SELF, MixerKind.MasterIn, FALSE, "Master in", "Master Input mixer channel");
			Enable
		END Constr;

		PROCEDURE Finalize;
		BEGIN
			Disable;
			(* Remove registered driver *)
			SoundDevices.devices.Remove(SELF);
			(* Update driver table *)
			SoundDevices.devices.GetAll(DriverTab)
		END Finalize;

		(** Generic functions *)

		PROCEDURE Init*;
		BEGIN
			SetName("BASS sound driver");
			desc := "Cross-platform BASS sound driver";
		END Init;

		PROCEDURE Enable*;
		BEGIN
		END Enable;

		PROCEDURE Disable*;
		BEGIN
		END Disable;

		(** Capabilities *)

		PROCEDURE NofNativeFrequences*(): SIGNED32;
		BEGIN
			RETURN 0
		END NofNativeFrequences;

		PROCEDURE GetNativeFrequency*(nr: SIGNED32): SIGNED32;
		BEGIN
			RETURN FREQ
		END GetNativeFrequency;

		PROCEDURE NofSamplingResolutions*(): SIGNED32;
		BEGIN
			RETURN 1 (* 16 bit *)
		END NofSamplingResolutions;

		PROCEDURE GetSamplingResolution*(nr : SIGNED32):SIGNED32;
		BEGIN
			RETURN 16
		END GetSamplingResolution;

		(** How many different sub channel settings are possible.
			Default implementation returns 2 for mono and stereo *)
		PROCEDURE NofSubChannelSettings*():SIGNED32;
		BEGIN
			RETURN 2
		END NofSubChannelSettings;

		(** Get sub channel setting nr.
			Default implementation returns mono and stereo *)
		PROCEDURE GetSubChannelSetting*(nr : SIGNED32):SIGNED32;
		BEGIN
			IF nr = 0 THEN RETURN 1
			ELSIF nr = 1 THEN RETURN 2
			ELSE RETURN 1
			END
		END GetSubChannelSetting;

		(** How many different wave formats are possible.
			Default implementation returns 1 *)
		PROCEDURE NofWaveFormats*():SIGNED32;
		BEGIN
			RETURN 1
		END NofWaveFormats;

		(** Get wave format nr.
			Default implementation returns FormatPCM *)
		PROCEDURE GetWaveFormat*(nr : SIGNED32):SIGNED32;
		BEGIN
			RETURN SoundDevices.FormatPCM
		END GetWaveFormat;

		(** Playing *)
		(** Open a new channel for playing. If more than one channel is opened, the sound driver needs to mix the
			channels in software or hardware, using the respective volumes. Sampling rate conversion must be done if needed.
			The driver may respond with res = ResNoMoreChannels, if it can not open more channels. (The driver
			SHOULD support more play channels (eg. 8 / 16 or more channels))
			The driver can also respond with res = ResReducedQuality if the playback quality is reduced due to insufficient
			ressources.
			channel is the resulting Play channel, NIL if an error that prevents playing has occured.
			(Applications only interested in the ability of playing and not in playback quality should only check for
			  channel # NIL and not for res = ResOk)
			samplingRate is the desired samplingRate
			samplingResolution = 8 / 16 / 24 / 32 (All drivers should support at least 8 and 16 bit)
			nofSubChannes = 1 for Mono, 2 for Stereo, 4 for Quadro etc.
			format is the wave format
		*)
		PROCEDURE OpenPlayChannel*(VAR channel : SoundDevices.Channel; samplingRate, samplingResolution, nofSubChannels, format : SIGNED32; VAR res : INTEGER);
		VAR
			chan: PlayChannel;
		BEGIN
			NEW(chan, channel, samplingRate, samplingResolution, nofSubChannels, res)
		END OpenPlayChannel;

		(** Recording *)
		(** Open a new channel for recording.
			If more than one channel is opened, the sound driver copies the recorded data to all the recording
			channels, using the respective volumes. Sampling rate conversion must be done if needed. Support for
			multichannel recording is possible but NOT required. The driver may respond with res := ResNoMoreChannels, if
			more than one recording channel is opened.
			channel is the resulting Recorder channel, NIL if an error occured.
			samplingRate is the desired samplingRate
			samplingResolution = 8 / 16 / 24 / 32 (All drivers should support at least 8 and 16 bit)
			nofSubChannes = 1 for Mono, 2 for Stereo, 4 for Quadro etc.
			format is the wave format
		*)
		PROCEDURE OpenRecordChannel*(VAR channel : SoundDevices.Channel; samplingRate, samplingResolution, nofSubChannels, format : SIGNED32; VAR res : INTEGER);
		END OpenRecordChannel;

		(** Mixer *)
		(** Register a listener for channel changes,
			The number of listeners is not limited
		  *)
		PROCEDURE RegisterMixerChangeListener*(mixChangedProc : SoundDevices.MixerChangedProc);
		VAR
			item : MixerChangedProcList;
		BEGIN {EXCLUSIVE}
			ASSERT(mixChangedProc # NIL);
			NEW(item);
			item.mixerChangedProc := mixChangedProc;
			item.next := firstMixerChangedProc;
			firstMixerChangedProc := item
		END RegisterMixerChangeListener;

		(** Unregister a previously registered channel change listener  *)
		PROCEDURE UnregisterMixerChangeListener*(mixChangeProc : SoundDevices.MixerChangedProc);
		VAR
			item : MixerChangedProcList;
		BEGIN {EXCLUSIVE}
			item := firstMixerChangedProc;
			(* No registered listeners *)
			IF item = NIL THEN
				RETURN;
			END;
			(* Check first entry *)
			IF item.mixerChangedProc = mixChangeProc THEN
				firstMixerChangedProc := item.next;
				(*IF DebugTraceListeners IN Debug THEN KernelLog.String("Removed mixerChangedProc"); KernelLog.Ln END;*)
				RETURN
			END;
			WHILE (item.next # NIL) & (item.next.mixerChangedProc # mixChangeProc) DO
				item := item.next
			END;
			IF item.next # NIL THEN
				item.next := item.next.next;
				(*IF DebugTraceListeners IN Debug THEN KernelLog.String("Removed mixerChangedProc"); KernelLog.Ln END*)
			ELSE
				(*IF DebugTraceListeners IN Debug THEN KernelLog.String("Could not remove mixerChangeProc"); KernelLog.Ln END*)
			END
		END UnregisterMixerChangeListener;

		(** Return channel object
			channel 0 is always present and is specified as the master output volume
			channel 1 is always present and is specified as the master input volume
				Drivers may ignore channel 0 or 1 but need to return a generic "Channel" object for these channel numbers
			GetMixerChannel returns NIL if the channelNr is invalid
		*)
		PROCEDURE GetMixerChannel*(channelNr : SIGNED32; VAR channel : SoundDevices.MixerChannel);
		BEGIN
			IF channelNr = 0 THEN channel := masterOut
			ELSIF channelNr = 1 THEN channel := masterIn
			ELSE channel := NIL
			END
		END GetMixerChannel;

		(** Returns the number of mixer channels available, at least 2 *)
		PROCEDURE GetNofMixerChannels*() : SIGNED32;
		BEGIN
			RETURN 2
		END GetNofMixerChannels;

	END Driver;

VAR
	driver: Driver;
	
(** Mathematical rounding *)
PROCEDURE round*(x: FLOAT32): SIGNED32;
BEGIN
	RETURN SIGNED32(x + 0.5)
END round;

PROCEDURE BassGetChannelVolume(bassChannel: BASS.HSTREAM): SIGNED32;
VAR
	bassVolume: FLOAT32;
BEGIN
	IF bassChannel # 0 THEN
		IGNORE BASS.BASS_ChannelGetAttribute(bassChannel, BASS.BASS_ATTRIB_VOL, bassVolume);
		RETURN	MIN(255, MAX(0, round(bassVolume * 255)))
	ELSE
		RETURN 255
	END
END BassGetChannelVolume;

PROCEDURE BassSetChannelVolume(bassChannel: BASS.HSTREAM; volume : SIGNED32);
VAR
	bassVolume: FLOAT32;
BEGIN
	IF bassChannel # 0 THEN
		bassVolume := MIN(1, MAX(0, volume / 255));
		IGNORE BASS.BASS_ChannelSetAttribute(bassChannel, BASS.BASS_ATTRIB_VOL, bassVolume)
	END
END BassSetChannelVolume;

PROCEDURE BassGetMixerVolume(mixerKind: MixerKind): SIGNED32;
VAR
	bassVolume: FLOAT32;
BEGIN
	IF mixerKind = MixerKind.MasterIn THEN
		IGNORE BASS.BASS_RecordGetInput(-1, bassVolume)
	ELSE
		bassVolume := BASS.BASS_GetVolume()
	END;
	RETURN	MIN(255, MAX(0, round(bassVolume * 255)))
END BassGetMixerVolume;

PROCEDURE BassSetMixerVolume(mixerKind: MixerKind; volume: SIGNED32);
VAR
	bassVolume: FLOAT32;
BEGIN
	bassVolume := MIN(1, MAX(0, volume / 255));
	IF mixerKind = MixerKind.MasterIn THEN
		IGNORE BASS.BASS_RecordSetInput(-1, BASS.BASS_INPUT_ON, bassVolume)
	ELSE
		IGNORE BASS.BASS_SetVolume(bassVolume)
	END
END BassSetMixerVolume;

(* Install the driver *)
PROCEDURE Install*(context: Commands.Context);
BEGIN
	IF (driver = NIL) & (BASS.BASS_Init(-1, FREQ, {}, 0, NIL) # 0) THEN
		KernelLog.String(SDriverDesc);	
		KernelLog.String(" installed.");
		KernelLog.Ln;
		NEW(driver)
	END
END Install;

PROCEDURE Cleanup;
BEGIN
	IF driver # NIL THEN
		driver.Finalize;
		IGNORE BASS.BASS_Free();
		KernelLog.String(SDriverDesc);
		KernelLog.String(" uninstalled.");
		KernelLog.Ln
	END
END Cleanup;

BEGIN
	driver := NIL;
	Modules.InstallTermHandler(Cleanup)
END BassSound.

WMMixer.Open ~
BassSound.Install ~
System.Free WMMixer BassSound BASS ~
