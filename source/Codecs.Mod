MODULE Codecs; (** AUTHOR "TF"; PURPOSE "CODEC repository"; *)

IMPORT
	Streams, Commands, Files, SoundDevices, Raster, Modules, Strings, Configuration, Unzip, Texts, Archives;

CONST
	ResFailed* = -1;
	ResOk* = 0;
	ResSeekInexact* = 1;

	ImgFmtBW* = 0;
	ImgFmtGrey* = 1;
	ImgFmtRGB* = 2;
	ImgFmtRGBA* = 3;

	STError* = -1;		(* e.g. when requested stream does not exist *)
	STUnknown* = 0;
	STAudio* = 1;
	STVideo* = 2;
	STImage* = 3;

	SeekByte* = 0;
	SeekSample* = 1;
	SeekKeySample* = 2;
	SeekFrame* = 3;
	SeekKeyFrame* = 4;

TYPE
	AVStreamInfo* = RECORD
		streamType* : LONGINT;
		seekability* : SET;
		contentType* : ARRAY 16 OF CHAR;

		length* : LONGINT;
		frames* : LONGINT;
		rate*: LONGINT;
	END;

	FileInputStream* = OBJECT(Streams.Reader)
	VAR
		r : Files.Rider;
		f* : Files.File;
		streamInfo*: AVStreamInfo;

		PROCEDURE Receive(VAR buf: ARRAY OF CHAR; ofs, size, min: LONGINT; VAR len: LONGINT; VAR res: WORD);
		BEGIN
			f.ReadBytes(r, buf, ofs, size);
			len := size - r.res;
			IF len >= min THEN res := Streams.Ok ELSE res := Streams.EOF (* end of file *) END
		END Receive;

		PROCEDURE &InitFileReader*(f : Files.File; pos: LONGINT);
		BEGIN
			InitReader(SELF.Receive, 4096);
			SELF.f := f;
			f.Set(r, pos);
			streamInfo.seekability := {SeekByte};
		END InitFileReader;

		PROCEDURE CanSetPos*(): BOOLEAN;
		BEGIN
			RETURN TRUE;
		END CanSetPos;

		PROCEDURE SetPos*(pos : Streams.Position);
		BEGIN
			f.Set(r, pos);
			Reset;
			received := pos;
		END SetPos;
	END FileInputStream;

	AVDemultiplexer* = OBJECT

		(** open the demultiplexer on an input stream *)
		PROCEDURE Open*(in : Streams.Reader; VAR res : WORD);
		END Open;

		PROCEDURE GetNumberOfStreams*() : LONGINT;
		BEGIN
			RETURN 0
		END GetNumberOfStreams;

		PROCEDURE GetStreamType*(streamNr : LONGINT): LONGINT;
		BEGIN
			RETURN -1;
		END GetStreamType;

		PROCEDURE GetStreamInfo*(streamNr : LONGINT): AVStreamInfo;
		END GetStreamInfo;

		(* get stream streamNr *)
		PROCEDURE GetStream*(streamNr: LONGINT): DemuxStream;
		END GetStream;

		(* read data from streamNr, store it into buffer buf starting at offset ofs, store size bytes if possible, block if not read min bytes at least. Return number of read bytes in len and return code res *)
		(* this procedure should not be directly called - it is called by the DemuxStream object! *)
		PROCEDURE GetData*(streamNr : LONGINT; VAR buf: ARRAY OF CHAR; ofs, size, min: LONGINT; VAR len: LONGINT; VAR res: WORD);
		END GetData;

		(* seek the streamNr to position pos (defined bz seekType), res = 0 if Ok, otherwise an error number *)
		(* this procedure should not be directly called - it is called by the DemuxStream object! *)
		PROCEDURE SetStreamPos*(streamNr : LONGINT; seekType : LONGINT; pos : LONGINT; VAR itemSize : LONGINT; VAR res : WORD);
		END SetStreamPos;

	END AVDemultiplexer;

	DemuxStream* = OBJECT(Streams.Reader)
	VAR
		demultiplexer* : AVDemultiplexer;
		streamNr* : LONGINT;
		streamInfo* : AVStreamInfo;

		PROCEDURE& Open*(demultiplexer : AVDemultiplexer; streamNr : LONGINT);
		BEGIN
			SELF.demultiplexer := demultiplexer;
			SELF.streamNr := streamNr;
			InitReader(Receive, 4096)
		END Open;

		PROCEDURE Receive(VAR buf: ARRAY OF CHAR; ofs, size, min: LONGINT; VAR len: LONGINT; VAR res: WORD);
		BEGIN
			demultiplexer.GetData(streamNr, buf, ofs, size, min, len, res)
		END Receive;

		PROCEDURE SetPos*(pos : Streams.Position);
		VAR  seekType, itemSize: LONGINT; res: WORD;
		BEGIN
			seekType := SeekByte;
			demultiplexer.SetStreamPos(streamNr, seekType, pos, itemSize, res);
			Reset
		END SetPos;

		(* seek the streamNr to position pos with seekType. itemSize contains the size of the element seeked to, if known and applicable; res = 0 if Ok, otherwise an error number *)
		PROCEDURE SetPosX*(seekType : LONGINT; pos : LONGINT; VAR itemSize : LONGINT; VAR res : WORD);
		BEGIN
			demultiplexer.SetStreamPos(streamNr, seekType, pos, itemSize, res);
			Reset
		END SetPosX;
	END DemuxStream;

	AudioDecoder* = OBJECT
		(* open the decoder on a file *)
		PROCEDURE Open*(in : Streams.Reader; VAR res : WORD);
		END Open;

		PROCEDURE HasMoreData*():BOOLEAN;
		END HasMoreData;

		PROCEDURE GetAudioInfo*(VAR nofChannels, samplesPerSecond, bitsPerSample : LONGINT);
		END GetAudioInfo;

		PROCEDURE SetAudioInfo*(nofChannels, samplesPerSecond, bitsPerSample : LONGINT);
		END SetAudioInfo;

		PROCEDURE CanSeek*() : BOOLEAN;
		BEGIN RETURN FALSE
		END CanSeek;

		PROCEDURE GetCurrentSample*() : LONGINT;
		BEGIN HALT(301); RETURN 0
		END GetCurrentSample;

		PROCEDURE GetTotalSamples*() : LONGINT;
		BEGIN HALT(301); RETURN 0
		END GetTotalSamples;

		PROCEDURE GetCurrentTime*() : LONGINT;
		BEGIN HALT(301); RETURN 0
		END GetCurrentTime;

		PROCEDURE SetStreamLength*(length : LONGINT);
		END SetStreamLength;

		PROCEDURE SeekSample*(sample: LONGINT; goKeySample : BOOLEAN; VAR res : WORD);
		END SeekSample;

		PROCEDURE SeekMillisecond*(millisecond : LONGINT; goKeySample : BOOLEAN; VAR res : WORD);
		END SeekMillisecond;

		(** Prepare the next audio bytes not yet filled into a buffer *)
		PROCEDURE Next*;
		END Next;

		PROCEDURE FillBuffer*(buffer : SoundDevices.Buffer);
		END FillBuffer;

	END AudioDecoder;

	AudioEncoder* = OBJECT
		(* open the encoder *)
		PROCEDURE Open*(out : Streams.Writer; sRate, sRes, nofCh: LONGINT; VAR res : WORD);
		END Open;

		PROCEDURE Write*(buffer : SoundDevices.Buffer; VAR res : WORD);
		END Write;

		PROCEDURE Close*(VAR res : WORD);
		END Close;

	END  AudioEncoder;

	VideoDecoder* = OBJECT
		(* open the decoder on a file *)
		PROCEDURE Open*(in : Streams.Reader; VAR res : WORD);
		END Open;

		PROCEDURE HasMoreData*():BOOLEAN;
		END HasMoreData;

		PROCEDURE GetVideoInfo*(VAR width, height, millisecondsPerFrame : LONGINT);
		END GetVideoInfo;

		PROCEDURE CanSeek*() : BOOLEAN;
		BEGIN RETURN FALSE
		END CanSeek;

		PROCEDURE GetCurrentFrame*() : LONGINT;
		END GetCurrentFrame;

		PROCEDURE GetCurrentTime*() : LONGINT;
		END GetCurrentTime;

		PROCEDURE SeekFrame*(frame : LONGINT; goKeyFrame : BOOLEAN; VAR res : WORD);
		END SeekFrame;

		PROCEDURE SeekMillisecond*(millisecond : LONGINT; goKeyFrame : BOOLEAN; VAR res : WORD);
		END SeekMillisecond;

		(** Prepare the next frame *)
		PROCEDURE Next*;
		END Next;

		PROCEDURE Render*(img : Raster.Image);
		END Render;

	END VideoDecoder;

	ImageDecoder* = OBJECT
		(* open the decoder on an InputStream *)
		PROCEDURE Open*(in : Streams.Reader; VAR res : WORD);
		END Open;

		PROCEDURE GetImageInfo*(VAR width, height, format, maxProgressionLevel : LONGINT);
		END GetImageInfo;

		(** Render will read and decode the image data up to progrssionLevel.
			If the progressionLevel is lower than a previously rendered progressionLevel,
			the new level can be ignored by the decoder. If no progressionLevel is set with
			SetProgressionLevel, the level is assumed to be maxProgressionLevel of the image,
			which corresponds to best image quality.
		 *)
		PROCEDURE SetProgressionLevel*(progressionLevel: LONGINT);
		END SetProgressionLevel;

		(* return the image in Raster format that best matches the format *)
		PROCEDURE GetNativeImage*(VAR img : Raster.Image);
		END GetNativeImage;

		(* renders the image into the given Raster.Image at the given progressionLevel *)
		PROCEDURE Render*(img : Raster.Image);
		END Render;

	END ImageDecoder;


	ImageEncoder* = OBJECT
		(* open the encoder on a stream*)
		PROCEDURE Open*(out : Streams.Writer);
		END Open;

		PROCEDURE SetQuality*(quality : LONGINT);
		END SetQuality;

		PROCEDURE WriteImage*(img : Raster.Image; VAR res : WORD);
		END WriteImage;

	END ImageEncoder;


	TextDecoder* = OBJECT
		(* open the decoder on an InputStream *)
		PROCEDURE Open*(in : Streams.Reader; VAR res : WORD);
		END Open;

		PROCEDURE GetText*() : Texts.Text;
		BEGIN
			HALT(301); RETURN NIL
		END GetText;
	END TextDecoder;

	TextEncoder* = OBJECT
		(* open the encoder on a stream*)
		PROCEDURE Open*(out : Streams.Writer);
		END Open;

		PROCEDURE WriteText*(text : Texts.Text; VAR res : WORD);
		END WriteText;
	END TextEncoder;

	CryptoDecoder* = OBJECT
		PROCEDURE Open*(in: Streams.Reader; VAR res: WORD);
		END Open;

		PROCEDURE GetReader*(): Streams.Reader;
		END GetReader;
	END CryptoDecoder;

	CryptoEncoder* = OBJECT
		PROCEDURE Open*(out: Streams.Writer);
		END Open;

		PROCEDURE GetWriter*(): Streams.Writer;
		END GetWriter;
	END CryptoEncoder;

(****** Animations *)

CONST
	(** ImageDescriptor.disposeMode *)
	Unspecified* = 0;
	DoNotDispose* = 1;
	RestoreToBackground* = 2;
	RestoreToPrevious* = 3;

	(** ImageDescriptor.flags *)
	WaitForUserInput* = 0;

TYPE

	ImageDescriptor* = OBJECT
	VAR
		left*, top*, width*, height*  : LONGINT;
		image* : Raster.Image;
		delayTime* : LONGINT; (* in milliseconds *)
		disposeMode* : LONGINT;
		flags* : SET;
		previous*, next* : ImageDescriptor;

		PROCEDURE &Init*;
		BEGIN
			left := 0; top := 0; width := 0; height := 0;
			image := NIL;
			delayTime := 20; disposeMode := Unspecified;
			flags := {};
			previous := NIL; next := NIL;
		END Init;

	END ImageDescriptor;

	ImageSequence* = RECORD
		width*, height* : LONGINT;
		bgColor* : LONGINT;
		images* : ImageDescriptor;
	END;

	AnimationDecoder* = OBJECT

		(* open the decoder on an InputStream *)
		PROCEDURE Open*(in : Streams.Reader; VAR res : WORD);
		END Open;

		PROCEDURE GetImageSequence*(VAR sequence : ImageSequence; VAR res : WORD);
		END GetImageSequence;

	END AnimationDecoder;

TYPE

	DemuxFactory = PROCEDURE () : AVDemultiplexer;

	AudioDecoderFactory = PROCEDURE () : AudioDecoder;
	AudioEncoderFactory = PROCEDURE () : AudioEncoder;

	VideoDecoderFactory = PROCEDURE () : VideoDecoder;

	ImageDecoderFactory = PROCEDURE () : ImageDecoder;
	ImageEncoderFactory = PROCEDURE () : ImageEncoder;

	TextDecoderFactory = PROCEDURE () : TextDecoder;
	TextEncoderFactory = PROCEDURE () : TextEncoder;

	CryptoDecoderFactory = PROCEDURE () : CryptoDecoder;
	CryptoEncoderFactory = PROCEDURE () : CryptoEncoder;

	AnimationDecoderFactory = PROCEDURE () : AnimationDecoder;


PROCEDURE GetDemuxFactoryName(CONST name : ARRAY OF CHAR; VAR module , procedure : Modules.Name; VAR res : WORD);
VAR config, factoryName, msg : ARRAY 128 OF CHAR;
BEGIN
	res := ResFailed;
	config := "Codecs.Demultiplexer."; Strings.Append(config, name);
	Configuration.Get(config, factoryName, res);
	IF (res = Configuration.Ok) THEN
		Commands.Split(factoryName, module, procedure, res, msg);
	END
END GetDemuxFactoryName;

PROCEDURE GetDecoderFactoryName(CONST type, name : ARRAY OF CHAR; VAR module, procedure : Modules.Name; VAR res : WORD);
VAR config, factoryName, msg : ARRAY 128 OF CHAR;
BEGIN
	res := ResFailed;
	config := "Codecs.Decoder."; Strings.Append(config, type); Strings.Append(config, ".");
	Strings.Append(config, name);
	Configuration.Get(config, factoryName, res);
	IF (res = Configuration.Ok) THEN
		Commands.Split(factoryName, module, procedure, res, msg);
	END
END GetDecoderFactoryName;

PROCEDURE GetEncoderFactoryName(CONST type, name : ARRAY OF CHAR; VAR module, procedure : Modules.Name; VAR res : WORD);
VAR config, factoryName, msg : ARRAY 128 OF CHAR;
BEGIN
	res := ResFailed;
	config := "Codecs.Encoder."; Strings.Append(config, type); Strings.Append(config, ".");
	Strings.Append(config, name);
	Configuration.Get(config, factoryName, res);
	IF (res = Configuration.Ok) THEN
		Commands.Split(factoryName, module, procedure, res, msg);
	END
END GetEncoderFactoryName;

(** Return a registered demultiplexer e.g. "AVI" *)
PROCEDURE GetDemultiplexer*(CONST name : ARRAY OF CHAR) : AVDemultiplexer;
VAR
	demux : AVDemultiplexer; factory : DemuxFactory;
	moduleName, procedureName : Modules.Name; res : WORD;
BEGIN
	demux := NIL;
	GetDemuxFactoryName(name, moduleName, procedureName, res);
	IF (res = ResOk) THEN
		GETPROCEDURE(moduleName, procedureName, factory);
		IF (factory # NIL) THEN
			demux := factory();
		END;
	END;
	RETURN demux;
END GetDemultiplexer;

(** Return a registered image decoder e.g. "JP2", "BMP", "PNG" *)
PROCEDURE GetImageDecoder*(CONST name : ARRAY OF CHAR) : ImageDecoder;
VAR
	decoder : ImageDecoder; factory : ImageDecoderFactory;
	moduleName, procedureName : Modules.Name; res : WORD;
BEGIN
	decoder := NIL;
	GetDecoderFactoryName("Image", name, moduleName, procedureName, res);
	IF (res = ResOk) THEN
		GETPROCEDURE(moduleName, procedureName, factory);
		IF (factory # NIL) THEN
			decoder := factory();
		END;
	END;
	RETURN decoder;
END GetImageDecoder;

(** Return a registered image decoder e.g. "BMP" *)
PROCEDURE GetImageEncoder*(CONST name : ARRAY OF CHAR) : ImageEncoder;
VAR
	encoder : ImageEncoder; factory : ImageEncoderFactory;
	moduleName, procedureName : Modules.Name; res : WORD;
BEGIN
	encoder := NIL;
	GetEncoderFactoryName("Image", name, moduleName, procedureName, res);
	IF (res = ResOk) THEN
		GETPROCEDURE(moduleName, procedureName, factory);
		IF (factory # NIL) THEN
			encoder := factory();
		END;
	END;
	RETURN encoder;
END GetImageEncoder;

(** Return a registered video decoder. The decoder name is typically a FourCC code  e.g. "DivX" *)
PROCEDURE GetVideoDecoder*(CONST name : ARRAY OF CHAR) : VideoDecoder;
VAR
	decoder : VideoDecoder; factory : VideoDecoderFactory;
	moduleName, procedureName : Modules.Name; res : WORD;
BEGIN
	decoder := NIL;
	GetDecoderFactoryName("Video", name, moduleName, procedureName, res);
	IF (res = ResOk) THEN
		GETPROCEDURE(moduleName, procedureName, factory);
		IF (factory # NIL) THEN
			decoder := factory();
		END;
	END;
	RETURN decoder;
END GetVideoDecoder;

(** Return a registered audio decoder e.g. "MP3" *)
PROCEDURE GetAudioDecoder*(CONST name : ARRAY OF CHAR) : AudioDecoder;
VAR
	decoder : AudioDecoder; factory : AudioDecoderFactory;
	moduleName, procedureName : Modules.Name; res : WORD;
BEGIN
	decoder := NIL;
	GetDecoderFactoryName("Audio", name, moduleName, procedureName, res);
	IF (res = ResOk) THEN
		GETPROCEDURE(moduleName, procedureName, factory);
		IF (factory # NIL) THEN
			decoder := factory();
		END;
	END;
	RETURN decoder;
END GetAudioDecoder;

(** Return a registered audio encoder e.g. "WAV" *)
PROCEDURE GetAudioEncoder*(CONST name : ARRAY OF CHAR) : AudioEncoder;
VAR
	encoder : AudioEncoder; factory : AudioEncoderFactory;
	moduleName, procedureName : Modules.Name; res : WORD;
BEGIN
	encoder := NIL;
	GetEncoderFactoryName("Audio", name, moduleName, procedureName, res);
	IF (res = ResOk) THEN
		GETPROCEDURE(moduleName, procedureName, factory);
		IF (factory # NIL) THEN
			encoder := factory();
		END;
	END;
	RETURN encoder;
END GetAudioEncoder;

PROCEDURE GetTextDecoder*(CONST name : ARRAY OF CHAR) : TextDecoder;
VAR
	decoder : TextDecoder; factory : TextDecoderFactory;
	moduleName, procedureName : Modules.Name; res : WORD;
BEGIN
	decoder := NIL;
	GetDecoderFactoryName("Text", name, moduleName, procedureName, res);
	IF (res = ResOk) THEN
		GETPROCEDURE(moduleName, procedureName, factory);
		IF (factory # NIL) THEN
			decoder := factory();
		END;
	END;
	RETURN decoder;
END GetTextDecoder;

(** Return a registered image decoder e.g. "BMP" *)
PROCEDURE GetTextEncoder*(CONST name : ARRAY OF CHAR) : TextEncoder;
VAR
	encoder : TextEncoder; factory : TextEncoderFactory;
	moduleName, procedureName : Modules.Name; res : WORD;
BEGIN
	encoder := NIL;
	GetEncoderFactoryName("Text", name, moduleName, procedureName, res);
	IF (res = ResOk) THEN
		GETPROCEDURE(moduleName, procedureName, factory);
		IF (factory # NIL) THEN
			encoder := factory();
		END;
	END;
	RETURN encoder;
END GetTextEncoder;

(** Return a registered crypto decoder *)
PROCEDURE GetCryptoDecoder*(CONST name : ARRAY OF CHAR) : CryptoDecoder;
VAR
	decoder : CryptoDecoder; factory : CryptoDecoderFactory;
	moduleName, procedureName : Modules.Name; res : WORD;
BEGIN
	decoder := NIL;
	GetDecoderFactoryName("Crypto", name, moduleName, procedureName, res);
	IF (res = ResOk) THEN
		GETPROCEDURE(moduleName, procedureName, factory);
		IF (factory # NIL) THEN
			decoder := factory();
		END;
	END;
	RETURN decoder;
END GetCryptoDecoder;

(** Return a registered crypto encoder *)
PROCEDURE GetCryptoEncoder*(CONST name : ARRAY OF CHAR) : CryptoEncoder;
VAR
	encoder : CryptoEncoder; factory : CryptoEncoderFactory;
	moduleName, procedureName : Modules.Name; res : WORD;
BEGIN
	encoder := NIL;
	GetEncoderFactoryName("Crypto", name, moduleName, procedureName, res);
	IF (res = ResOk) THEN
		GETPROCEDURE(moduleName, procedureName, factory);
		IF (factory # NIL) THEN
			encoder := factory();
		END;
	END;
	RETURN encoder;
END GetCryptoEncoder;

(** Return a registered animation decoder e.g. "GIF", "ANI" *)
PROCEDURE GetAnimationDecoder*(CONST name : ARRAY OF CHAR) : AnimationDecoder;
VAR
	decoder : AnimationDecoder; factory : AnimationDecoderFactory;
	moduleName, procedureName : Modules.Name; res : WORD;
BEGIN
	decoder := NIL;
	GetDecoderFactoryName("Animation", name, moduleName, procedureName, res);
	IF (res = ResOk) THEN
		GETPROCEDURE(moduleName, procedureName, factory);
		IF (factory # NIL) THEN
			decoder := factory();
		END;
	END;
	RETURN decoder;
END GetAnimationDecoder;

PROCEDURE SplitName*(CONST  name : ARRAY OF CHAR; VAR protocol, filename : ARRAY OF CHAR);
VAR pos, i : LONGINT;
BEGIN
	pos := Strings.Pos("://", name);
	IF pos >= 0 THEN
		FOR i := 0 TO pos - 1 DO protocol[i] := name[i] END;
		protocol[pos] := 0X;
		INC(pos, 3);	i := 0; WHILE name[pos] # 0X DO filename[i] := name[pos]; INC(pos); INC(i) END;
		filename[i] := 0X
	ELSE
		COPY("", protocol);
		COPY(name, filename)
	END
END SplitName;

PROCEDURE JoinName*(CONST protocol, filename : ARRAY OF CHAR; VAR name : ARRAY OF CHAR);
BEGIN
	IF (protocol # "") THEN
		Strings.Concat(protocol, "://", name); Strings.Concat(name, filename, name);
	ELSE
		COPY(filename, name);
	END;
END JoinName;

PROCEDURE OpenInputStream*(CONST name : ARRAY OF CHAR) : Streams.Reader;
VAR f : Files.File;
	is : FileInputStream;
	inpStream : Streams.Reader;
	r : Streams.Receiver;
	tp, protocol, filename : ARRAY 1024 OF CHAR;
	zf : Unzip.ZipFile;
	entry : Unzip.Entry;
	archive : Archives.Archive;
	res : WORD;
BEGIN
	SplitName(name, protocol, filename);
	COPY(protocol, tp); Strings.LowerCase(tp);
	IF protocol = "" THEN
		f := Files.Old(filename);
		IF f = NIL THEN RETURN NIL END;
		NEW(is, f, 0);
		RETURN is
	ELSIF Strings.Match("*.zip", tp) THEN
		f := Files.Old(protocol);
		IF f = NIL THEN RETURN NIL END;
		NEW(zf, f, res);
		IF res = 0 THEN
			entry := zf.FindEntry(filename);
			IF entry # NIL THEN
				zf.OpenReceiver(r, entry, res);
				IF res = 0 THEN
					NEW(inpStream, r, 1024);
					RETURN inpStream
				ELSE RETURN NIL
				END
			ELSE RETURN NIL
			END
		ELSE RETURN NIL
		END
	ELSIF Strings.Match("*.skin", tp) THEN
		archive := Archives.Old(protocol, "skin");
		IF archive = NIL THEN
			RETURN NIL
		ELSE
			archive.Acquire; r := archive.OpenReceiver(filename); archive.Release;
			IF r = NIL THEN
				RETURN NIL
			ELSE
				NEW(inpStream, r, 1024);
				RETURN inpStream
			END
		END
	ELSIF Strings.Match("*.tar", tp) OR Strings.Match("*.rep", tp) THEN
		archive := Archives.Old(protocol, "tar");
		IF archive = NIL THEN
			RETURN NIL
		ELSE
			archive.Acquire; r := archive.OpenReceiver(filename); archive.Release;
			IF r = NIL THEN
				RETURN NIL
			ELSE
				NEW(inpStream, r, 1024);
				RETURN inpStream
			END
		END
	END;
	RETURN NIL
END OpenInputStream;

PROCEDURE OpenOutputStream*(CONST name : ARRAY OF CHAR) : Streams.Writer;
VAR
	file : Files.File; w : Files.Writer;
	writer : Streams.Writer;
	sender : Streams.Sender;
	tp, protocol, filename : ARRAY 1024 OF CHAR;
	archive : Archives.Archive;
BEGIN
	writer := NIL;
	SplitName(name, protocol, filename);
	COPY(protocol, tp); Strings.LowerCase(tp);
	IF protocol = "" THEN
		file := Files.New(filename);
		IF file # NIL THEN
			Files.Register(file);
			NEW(w, file, 0); writer := w;
		END
	ELSIF Strings.Match("*.skin", tp) THEN
		archive := Archives.Old(protocol, "skin");
		IF archive = NIL THEN archive := Archives.New(protocol, "skin"); END;
		IF archive # NIL THEN
			archive.Acquire; sender := archive.OpenSender(filename); archive.Release;
			IF sender # NIL THEN
				NEW(writer, sender, 1024);
			END
		END
	ELSIF Strings.Match("*.tar", tp) OR Strings.Match("*.rep", tp)  THEN
		archive := Archives.Old(protocol, "tar");
		IF archive = NIL THEN archive := Archives.New(protocol, "tar"); END;
		IF archive # NIL THEN
			archive.Acquire; sender := archive.OpenSender(filename); archive.Release;
			IF sender # NIL THEN
				NEW(writer, sender, 1024);
			END
		END
	END;
	RETURN writer;
END OpenOutputStream;

END Codecs.

--------------------------
System.Free Codecs~
