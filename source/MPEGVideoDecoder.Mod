(** AUTHOR "Yves Weber";
	PURPOSE "MPEG System Demultiplexer and MPEG Video Decoder";
*)
MODULE MPEGVideoDecoder;

IMPORT
	SYSTEM, Codec := Codecs, Raster, Streams, KernelLog, Files, WMGraphics, MPEGTables,
	WM := WMWindowManager, Rectangles := WMRectangles, Kernel, Commands,
	Util := MPEGUtilities;

CONST
	(* Video start codes in numeric order *)
	SCPicture* = 			CHR(000H);
	(* 						CHR(001H)
								 :
							CHR(0AFH) are slice start codes
	 						CHR(0B0H) and
	 						CHR(0B1H) are reserved *)
	SCUserData* = 			CHR(0B2H);
	SCSequenceHeader* = 	CHR(0B3H);
	SCSequenceError* = 	CHR(0B4H);
	SCExtension* = 			CHR(0B5H);
	(* 						CHR(0B6H) is reserved *)
	SCSequenceEnd* = 		CHR(0B7H);
	SCGOP* = 				CHR(0B8H);

	(* System start codes in numeric order *)
	SCSystemEnd* =			CHR(0B9H);
	SCPack* = 				CHR(0BAH);
	SCSystemHeader* = 		CHR(0BBH);
	SCReservedStream* = 	CHR(0BCH);
	SCPrivateStream* = 		CHR(0BDH);
	SCPaddingStream* = 	CHR(0BEH);
	SCPrivateStream2* =	CHR(0BFH);
	(*						CHR(0C0H)
								:
							CHR(0DFH) are audio streams 0..31
							CHR(0E0H)
								:
							CHR(0EFH) are video streams 0..15
							CHR(0F0H)
								:
							CHR(0FFH) are reserved streams 0..15 *)

	(* Picture Structures (MPEG-2 only) *)
	PicStructReserved* =	0;
	PicStructTopField* = 	1;
	PicStructBottomField* =	2;
	PicStructFrame* =		3;

	(* Frame Motion Types *)
	FMTReserved* =			0;
	FMTField* =				1;
	FMTFrame* =			2;
	FMTDualPrime* =		3;

	(* index in MotionVectorInfos *)
	forward = 0;
	backward = 1;
	horizontal = 0;
	vertical = 1;
	mv1 = 0;		(* first motion vector *)
	mv2 = 1;		(* second motion vector (MPEG-1 always uses just the first one) *)

TYPE
	(* required by the demultiplexer to keep track of its streams *)
	StreamType = RECORD
		stream*: Codec.DemuxStream;
		idByte*: CHAR;
		pos: LONGINT;
		bytesLeftInPacket: LONGINT;
		eos: BOOLEAN;			(* end of stream *)
	END;

	(* Window of a very (!) simple stand-alone player *)
	TYPE PW* =  OBJECT(WM.DoubleBufferWindow)
		PROCEDURE & InitNew*(w, h:LONGINT; alpha:BOOLEAN);
		BEGIN
			Init(w, h, alpha);
			manager := WM.GetDefaultManager();
			WM.DefaultAddWindow(SELF);
		END InitNew;

		(* Overwrite draw procedure because we do not want any interpolation *)
		PROCEDURE Draw*(canvas : WMGraphics.Canvas; w, h, q : LONGINT);
		BEGIN
			Draw^(canvas, w, h, 0)
		END Draw;

		PROCEDURE Close*;
		BEGIN
			Close^;
		END Close;
	END PW;


	(* Decoder for an MPEG Video Sequence *)
	MPEGVideoDecoder* = OBJECT(Codec.VideoDecoder)
	VAR
		(* Video Information *)
		videoWidth, videoHeight: LONGINT;
		videoWidthDiv2, videoHeightDiv2: LONGINT;
		videoWidthDiv16, videoHeightDiv16: LONGINT;
		aspectRatioIndex, frameRateIndex: LONGINT;
		bitRate: LONGINT;

		stream*: Util.BitStream;						(* the stream we read from *)
		reader: Util.StreamReader;					(* allows to read VLCs and other information from the stream *)
		idct: Util.IDCT;								(* performs the iDCT *)
		yuv2rgb: Util.ColorSpace;					(* performs the colorspace transformation YUV -> RGB *)
		dequantizer: Util.Dequantizer;				(* performs the dequantization of intra and non-intra quantizer matrices *)
		blocks: Util.BlockActions;						(* required for motion compensation *)

		intraQM: Util.PointerToArrayOfLONGINT;		(* intra quantizer matrix *)
		nonintraQM: Util.PointerToArrayOfLONGINT;	(* non-intra quantizer matrix *)

		curFrame: Util.Frame;						(* the dequantized and iDCT'ed YUV values *)
		prevRef, nextRef: Util.Frame;				(* previous and next reference picture *)
		nextFrameToRender: Util.Frame;				(* the next frame ready to be rendered *)

		mvinfos: Util.MotionVectorInfos;				(* everything that is somehow connected to motion vectors *)
		frameNr: LONGINT;							(* number of the current frame (restarts for each GOP) *)
		realFrameNr: LONGINT;						(* number of the current frame (restarts at the beginning of the movie) *)
		time: LONGINT;								(* current time in milliseconds *)
		mspf: LONGINT;								(* milliseconds per frame *)

		hasMoreFrames: BOOLEAN;					(* FALSE at the end of a video sequence *)

		(* MPEG-2 stuff *)
		MPEG2: BOOLEAN;							(* TRUE -> MPEG-2; FALSE -> MPEG-1 *)
		MainProfile: BOOLEAN;						(* TRUE -> Main Profile; FALSE -> Simple Profile *)
		LevelID: LONGINT;							(* 1 -> Low, 2 -> Main, 3 -> High1440, 4 -> High *)
		ChromaFormat: LONGINT;					(* 1 -> 4:2:0, 2 -> 4:2:2, 3-> 4:4:4 *)
		picExt: Util.PicCodingExt;					(* some infos about the picture *)

		(* less important VARs *)
		mbSkipped: BOOLEAN;								(* TRUE if last macroblock was skipped (required for DC prediction) *)
		dcY, dcCb, dcCr: LONGINT;							(* DC coefficient prediction for Y, Cb and Cr blocks *)
		mbMotionForwOld, mbMotionBackOld: BOOLEAN;	(* required for skipped macroblocks of B-Frames *)
		mbIntraOld: BOOLEAN;

		(* local in picture *)
		mbAddress: LONGINT;								(* Address of the current macroblock *)
		mbAddressLast: LONGINT;							(* Address of the last coded macroblock *)
		mbAddressLastIntra: LONGINT;
		macroblockNr: INTEGER;								(* number of the macroblock currently decoded (in slice) *)

		(* local in macroblock *)
		frameMotionType: LONGINT;
		dctType: BOOLEAN;
		block: Util.PointerToArrayOfLONGINT;				(* current block of a macroblock *)

		frametype: LONGINT;

		(* Constructor *)
		PROCEDURE &Init*;
		VAR
			i: SHORTINT;

		BEGIN
			NEW(idct);
			NEW(yuv2rgb);
			NEW(dequantizer);
			NEW(picExt);
			NEW(mvinfos);
			NEW(blocks);

			NEW(block, 64);

			hasMoreFrames := TRUE;
			realFrameNr := -1;

			(* init QMs with default values *)
			NEW(intraQM, 64);
			NEW(nonintraQM, 64);

			FOR i := 0 TO 63 DO
				intraQM[i] := MPEGTables.IQM[i];
				nonintraQM[i] := 16;
			END;
		END Init;

		(* Open a video stream by reading the sequence header *)
		PROCEDURE Open*(in : Streams.Reader; VAR res : WORD);
		VAR
			marker: CHAR;

		BEGIN
			res := Codec.ResFailed;
			IF ~(in IS Codec.DemuxStream) THEN RETURN END;

			NEW(stream, in(Codec.DemuxStream));
			NEW(reader, stream);

			frameNr := -1;

			(* read (next) start code *)
			IF ~GotoNextMarker(stream, marker) THEN
				(* stream does not start with a startcode *)
				KernelLog.String("this is not a legal MPEG video stream (no startcode found)"); KernelLog.Ln;
				RETURN;
			END;

			(* check if startcode is legal *)
			IF marker # SCSequenceHeader THEN
				IF marker = CHR(0BAH) THEN
					KernelLog.String("This is a multiplexed (audio & video) MPEG stream. Use the demultiplexer."); KernelLog.Ln;
				ELSE
					(* video sequence must start with 00 00 01 B3 *)
					KernelLog.String("This is not a valid Video Stream (Marker="); KernelLog.Hex(ORD(marker), -1);
					KernelLog.String(")"); KernelLog.Ln;
				END;
				RETURN;
			END;

			(* skip the startcode *)
			stream.SkipBits(32);

			IF ParseSequenceHeader() THEN
				(* create image buffers *)
				videoWidthDiv2 := videoWidth DIV 2;
				videoHeightDiv2 := videoHeight DIV 2;
				videoWidthDiv16 := videoWidth DIV 16;
				videoHeightDiv16 := videoHeight DIV 16;

				NEW(curFrame);
				NEW(curFrame.buffer, videoHeight * videoWidth + 2 * (videoHeightDiv2 * videoWidthDiv2));
				curFrame.cbOffset := videoHeight * videoWidth;
				curFrame.crOffset := videoHeight * videoWidth + videoHeightDiv2 * videoWidthDiv2;
				curFrame.frameNr := -1;

				NEW(prevRef);
				NEW(prevRef.buffer, videoHeight * videoWidth + 2 * (videoHeightDiv2 * videoWidthDiv2));
				prevRef.cbOffset := videoHeight * videoWidth;
				prevRef.crOffset := videoHeight * videoWidth + videoHeightDiv2 * videoWidthDiv2;
				prevRef.frameNr := -1;

				NEW(nextRef);
				NEW(nextRef.buffer, videoHeight * videoWidth + 2 * (videoHeightDiv2 * videoWidthDiv2));
				nextRef.cbOffset := videoHeight * videoWidth;
				nextRef.crOffset := videoHeight * videoWidth + videoHeightDiv2 * videoWidthDiv2;
				nextRef.frameNr := -1;

				res  := Codec.ResOk;
				RETURN;
			ELSE
				KernelLog.String("Failed parsing (first) Sequence Header"); KernelLog.Ln;
			END;
		END Open;

		PROCEDURE HasMoreData*(): BOOLEAN;
		BEGIN
			RETURN hasMoreFrames;
		END HasMoreData;


		PROCEDURE ParseSequenceHeader(): BOOLEAN;
		VAR
			marker: CHAR;

		BEGIN
			videoWidth := stream.GetBits(12);
			videoHeight := stream.GetBits(12);

			(* we just extend the video to a multiple of 16. not perfect, but it works... *)
			IF videoWidth MOD 16 # 0 THEN
				videoWidth := ((videoWidth DIV 16) + 1) * 16;
			END;

			IF videoHeight MOD 16 # 0 THEN
				videoHeight := ((videoHeight DIV 16) + 1) * 16;
			END;

			aspectRatioIndex := stream.GetBits(4);
			frameRateIndex := stream.GetBits(4);

			CASE frameRateIndex OF
					1: mspf := 42	(* 23.976 fps 	-> 41.70837... *)
				|	2: mspf := 42 	(* 24 fps 		-> 41.66666... *)
				| 	3: mspf := 40	(* 25 fps		-> 40.00000... *)
				|	4: mspf := 33	(* 29.97 fps 		-> 33.36670... *)
				|	5: mspf := 33	(* 30 fps 		-> 33.33333... *)
				| 	6: mspf := 20	(* 50 fps 		-> 20.00000... *)
				|	7: mspf := 17	(* 59.94 fps		-> 16.68335... *)
				|	8: mspf := 17	(* 60 fps 		-> 16.66666... *)
				ELSE
					mspf := 40;		(* illegal framerate, just assume something *)
					KernelLog.String("Unknown Framerate Index: "); KernelLog.Int(frameRateIndex, 0); KernelLog.Ln;
			END;

			bitRate := stream.GetBits(18);
			stream.SkipBits(1);						(* marker bit *)
			stream.SkipBits(10);						(* vbv buffer size *)
			stream.SkipBits(1);						(* constrained bit *)

			IF stream.GetBits(1) = 1 THEN
				(* intra quantizer matrix coming... *)
				reader.ReadQuantizerMatrix(intraQM);
				IF reader.eof THEN RETURN FALSE END;
			END;

			IF stream.GetBits(1) = 1 THEN
				(* non-intra quantizer matrix coming *)
				reader.ReadQuantizerMatrix(nonintraQM);
				IF reader.eof THEN RETURN FALSE END;
			END;

			IF ~stream.HasMoreData() THEN hasMoreFrames := FALSE; RETURN FALSE END;

			IF ~GotoNextMarker(stream, marker) THEN
				RETURN FALSE;
			END;

			(* read extension block(s) if present *)
			IF marker = SCExtension THEN
				(* This is an MPEG-2 stream! *)
				MPEG2 := TRUE;

				REPEAT
					IF marker = SCExtension THEN
						stream.SkipBits(32);
						IF ~ReadExtension() THEN RETURN FALSE END;
						IF ~GotoNextMarker(stream, marker) THEN RETURN FALSE END;
					ELSE
						(* skip user data - they are unimportant for the decoder *)
						stream.SkipBits(32);
						IF ~GotoNextMarker(stream, marker) THEN RETURN FALSE END;
					END;
				UNTIL (marker # SCExtension) & (marker # SCUserData);
			ELSE
				(* This is an MPEG-1 stream! *)
				MPEG2 := FALSE;

				WHILE marker = SCUserData DO
					stream.SkipBits(32);

					IF ~GotoNextMarker(stream, marker) THEN
						RETURN FALSE;
					END;
				END;
			END;

			RETURN TRUE;
		END ParseSequenceHeader;

		(* Read an extension. It is assumed that the stream is currently at the end of an extension start code *)
		PROCEDURE ReadExtension(): BOOLEAN;
		VAR
			fourbits: LONGINT;
			tmp: BOOLEAN;

		BEGIN
			fourbits := stream.GetBits(4);

			CASE fourbits OF
				0, 5, 6, 9..15:
					(* not supported by MP@ML or not defined by the standard *)
					KernelLog.String("Extension not supported: "); KernelLog.Int(stream.ShowBits(4), 0); KernelLog.Ln;
					RETURN FALSE;

			|	1:	(* sequence extension *)
					tmp := reader.ReadSequenceExtension(MainProfile, LevelID, ChromaFormat, videoWidth, videoHeight);
					IF reader.eof THEN
						RETURN FALSE;
					ELSE
						RETURN tmp;
					END;

			|	2:	(* sequence display extension *)
					tmp := reader.ReadSequenceDisplayExtension();
					IF reader.eof THEN
						RETURN FALSE;
					ELSE
						RETURN tmp;
					END;

			|	3:	(* quant matrix extension *)
					tmp := reader.ReadQuantMatrixExtension();
					IF reader.eof THEN
						RETURN FALSE;
					ELSE
						RETURN tmp;
					END;

			|	4:	(* copyright extension *)
					tmp := reader.ReadCopyrightExtension();
					IF reader.eof THEN
						RETURN FALSE;
					ELSE
						RETURN tmp;
					END;

			|	7:	(* picture display extension *)
					tmp := reader.ReadPictureDisplayExtension();
					IF reader.eof THEN
						RETURN FALSE;
					ELSE
						RETURN tmp;
					END;

			|	8:	(* picture coding extension *)
					tmp := reader.ReadPictureCodingExtension(picExt, mvinfos);
					IF reader.eof THEN
						RETURN FALSE;
					ELSE
						RETURN tmp;
					END;
			ELSE
				hasMoreFrames := FALSE;
				RETURN FALSE;
			END;

			(* we can't come here... *)
			RETURN FALSE;
		END ReadExtension;

		(* parse an SMTPE timecode (25 bits) *)
		PROCEDURE ReadTimecode;
		VAR
			h, min, sec, frames: LONGINT;

		BEGIN
			stream.SkipBits(1);
			h := stream.GetBits(5);
			min := stream.GetBits(6);
			stream.SkipBits(1);
			sec := stream.GetBits(6);
			frames := stream.GetBits(6);

			(* the timecode may not be used for seeking because it does not
			always start at 0:00:00.00 for all movies *)

			(*
			KernelLog.String("Timecode: ");
			KernelLog.Int(h, 0); KernelLog.String(":");
			KernelLog.Int(min, 0); KernelLog.String(":");
			KernelLog.Int(sec, 0); KernelLog.String(".");
			KernelLog.Int(frames, 0); KernelLog.Ln;
			*)

			IF ~stream.HasMoreData() THEN
				hasMoreFrames := FALSE;
			END;
		END ReadTimecode;


		(* return some information about the video stream *)
		PROCEDURE GetVideoInfo*(VAR width, height, millisecondsPerFrame : LONGINT);
		BEGIN
			width := videoWidth;
			height := videoHeight;
			millisecondsPerFrame := mspf;
		END GetVideoInfo;

		PROCEDURE CanSeek*() : BOOLEAN;
		BEGIN
			RETURN TRUE
		END CanSeek;

		PROCEDURE GetCurrentFrame*() : LONGINT;
		BEGIN
			RETURN realFrameNr;
		END GetCurrentFrame;

		PROCEDURE GetCurrentTime*() : LONGINT;
		BEGIN
			RETURN time;
		END GetCurrentTime;

		PROCEDURE SeekFrame*(frame : LONGINT; goKeyFrame : BOOLEAN; VAR res : WORD);
		VAR
			i: LONGINT;
			code: CHAR;
			lastIntraPosOld, lastIntraNrOld, lastIntraPos, lastIntraNr, lastFramePos: LONGINT;
			nrB, nrBOld: LONGINT;
			countB: BOOLEAN;
			type: LONGINT;

		BEGIN
			res := Codec.ResFailed;

			(* start at the beginning *)
			stream.Reset;

			IF ~GotoNextMarker(stream, code) THEN RETURN END;
			stream.SkipBits(32);
			IF ~ParseSequenceHeader() THEN RETURN END;

			lastIntraPos := stream.Pos();
			lastFramePos := stream.Pos();

			(* to be sure, we need to decode the last 2 i-frames. consider (decoding!) order IBBPBBIB *)
			FOR i := 0 TO frame DO
				(* skip frame i *)
				type := SkipNext();
				IF type = 1 THEN
					(* skipped frame was an I-frame *)
					lastIntraPosOld := lastIntraPos;
					lastIntraNrOld := lastIntraNr;
					lastIntraPos := lastFramePos;
					lastIntraNr := i;
					countB := TRUE;
					nrBOld := nrB;
					nrB := 0;
				ELSE
					IF countB THEN
						IF type = 3 THEN
							INC(nrB);
						ELSE
							countB := FALSE;
						END;
					END;
				END;
				lastFramePos := stream.Pos();
			END;

			(* jump to the second last I-frame *)
			stream.SetPos(lastIntraPosOld);
			realFrameNr := lastIntraNrOld;
			frameNr := 10000;					(* expected frameNr > tempRef => frameNr gets adjusted *)

			Next();
			FOR i := 1 TO nrBOld DO
				type := SkipNext();
			END;
			DEC(frameNr, nrBOld);

			FOR i := lastIntraNrOld+1 TO lastIntraNr-1 DO
				Next();
			END;

			IF ~goKeyFrame THEN
				FOR i := lastIntraNr TO frame DO
					Next();
				END;
			END;

			res := Codec.ResOk;
		END SeekFrame;

		PROCEDURE SeekMillisecond*(millisecond : LONGINT; goKeyFrame : BOOLEAN; VAR res : WORD);
		VAR
			newframe: LONGINT;

		BEGIN
			newframe := millisecond DIV mspf;
			SeekFrame(newframe, goKeyFrame, res);
			time := newframe * mspf;
		END SeekMillisecond;

		(* skips one frame *)
		PROCEDURE SkipNext(): LONGINT;
		VAR
			marker: CHAR;
			picType: LONGINT;			(* 1=I-, 2=P-, 3=B-, 4=D-Picture, other values are illegal *)
			tempRef: LONGINT;			(* temporal reference *)
			nextCode: LONGINT;
			tmpFrame: Util.Frame;			(* required to switch two frames *)

		BEGIN
			IF ~hasMoreFrames THEN RETURN -1 END;

			INC(frameNr);
			INC(realFrameNr);

			IF frameNr = nextRef.frameNr THEN
				(* we have already decoded this frame, just take it from the nextRef buffer *)
				tmpFrame := curFrame;
				curFrame := nextRef;
				nextRef := tmpFrame;
			ELSE
				(* decode one or two frames *)
				REPEAT
					mbAddress := -1;
					mbAddressLast := -1;

					IF ~GotoNextMarker(stream, marker) THEN RETURN -1 END;

					WHILE marker # SCPicture DO
						IF marker = SCSequenceHeader THEN
							stream.SkipBits(32);
							IF ~ParseSequenceHeader() THEN
								hasMoreFrames := FALSE;
								RETURN -1;
							END;

						ELSIF marker = SCGOP THEN
							stream.SkipBits(32);
							ReadTimecode;			(* SMPTE Timecode *)
							stream.SkipBits(1);		(* closed GOP -> if closed wipe out prev and next buffer (black) *)
							stream.SkipBits(1);		(* broken link *)
							stream.SkipBits(5);		(* not used, should be 0... *)

							(* temporal reference restarts at zero *)
							frameNr := 0;
							prevRef.frameNr := -1;	(* make sure they are at most used as reference *)
							nextRef.frameNr := -1;	(* make sure they are at most used as reference *)

						ELSE
							KernelLog.String("Unexpected marker found: "); KernelLog.Hex(ORD(marker), -1); KernelLog.Ln;
							RETURN -1;
						END;

						IF ~GotoNextMarker(stream, marker) THEN RETURN -1 END;
					END;

					(* parse picture header *)
					stream.SkipBits(32);
					tempRef := stream.GetBits(10);							(* temporal reference *)
					curFrame.frameNr := tempRef;
					picType := stream.GetBits(3);								(* the picture type (I, P, B or D) *)
					frametype := picType;
					curFrame.picType := picType;
					stream.SkipBits(16);										(* vbv buffer delay -> not relevant for us *)

					IF (picType = 2) OR (picType = 3) THEN
						stream.SkipBits(4);
					END;

					IF picType = 3 THEN
						stream.SkipBits(4);
					END;

					WHILE stream.ShowBits(1) = 1 DO
						stream.SkipBits(1);				(* extra information follows *)
						stream.SkipBits(8);				(* undefined by the standard *)
					END;

					stream.SkipBits(1);					(* skip '0' marker bit *)

					IF ~stream.HasMoreData() THEN
						hasMoreFrames := FALSE;
						RETURN -1;
					END;

					IF ~GotoNextMarker(stream, marker) THEN RETURN -1 END;

					(* read extension data if present *)
					IF marker = SCExtension THEN
						IF ~MPEG2 THEN
							HALT(1234);
						END;
						stream.SkipBits(32);
						IF stream.ShowBits(4) # 8 THEN
							RETURN -1;
						ELSE
							stream.SkipBits(4);
						END;
						IF ~reader.ReadPictureCodingExtension(picExt, mvinfos) THEN RETURN -1 END;
						IF reader.eof THEN hasMoreFrames := FALSE; RETURN 0 END;
						IF picExt.framePredFrameDct THEN frameMotionType := FMTFrame END;
						IF ~GotoNextMarker(stream, marker) THEN RETURN -1 END;
						IF ~GotoNextMarker(stream, marker) THEN RETURN -1 END;
					ELSIF MPEG2 THEN
						(* MPEG-2 requires a picture extension ! *)
						KernelLog.String("MPEG-2 picture extension not found"); KernelLog.Ln;
						HALT(1234);
					END;

					(* read user data if present *)
					IF marker = SCUserData THEN
						stream.SkipBits(32);
						WHILE stream.ShowBits(24) # 1 DO
							stream.SkipBits(8);
						END;
						IF ~GotoNextMarker(stream, marker) THEN RETURN -1 END;
					END;

					(* now we are really ready to decode the picture *)
					IF (picType = 1) OR (picType = 2) OR (picType = 3) THEN
						REPEAT
							(* Skip Slice *)
							stream.SkipBits(32);
							WHILE stream.ShowBits(24) # 1 DO
								stream.SkipBits(8);
							END;
							nextCode := stream.ShowBits(32);
						UNTIL ~(nextCode > 100H) & (nextCode <= 1AFH);
					ELSIF picType = 4 THEN
						(* D-Picture *)
						RETURN -1;		(* D-Pictures not supported *)
					ELSE
						(* illegal or reserved value *)
						RETURN -1;
					END;

					IF tempRef > frameNr THEN
						(* dont display the frame yet - it is a future reference for upcoming B-Pics *)
						tmpFrame := nextRef;
						nextRef := curFrame;
						curFrame := tmpFrame;
					END;
				UNTIL tempRef <= frameNr;
			END;

			(* now we are sure that the correct frame is in the curFrame buffer *)

			(* store I- and P-Pictures as prediction for further pics *)
			IF (curFrame.picType = 1) OR (curFrame.picType = 2) THEN
				tmpFrame := prevRef;
				prevRef := curFrame;
				curFrame := tmpFrame;
				nextFrameToRender := prevRef;
			ELSE
				nextFrameToRender := curFrame;
			END;

			RETURN picType;
		END SkipNext;


		(* Prepare the next frame *)
		PROCEDURE Next*;
		VAR
			marker: CHAR;
			picType: LONGINT;			(* 1=I-, 2=P-, 3=B-, 4=D-Picture, other values are illegal *)
			tempRef: LONGINT;			(* temporal reference *)
			res: BOOLEAN;
			nextCode: LONGINT;
			tmpFrame: Util.Frame;			(* required to switch two frames *)

		BEGIN
			IF ~hasMoreFrames THEN RETURN END;

			INC(frameNr);
			INC(realFrameNr);
			INC(time, mspf);

			IF frameNr = nextRef.frameNr THEN
				(* we have already decoded this frame, just take it from the nextRef buffer *)
				tmpFrame := curFrame;
				curFrame := nextRef;
				nextRef := tmpFrame;
			ELSE
				(* decode one or two frames *)
				REPEAT
					mbAddress := -1;
					mbAddressLast := -1;

					IF ~GotoNextMarker(stream, marker) THEN RETURN END;

					WHILE marker # SCPicture DO
						IF marker = SCSequenceHeader THEN
							stream.SkipBits(32);
							IF ~ParseSequenceHeader() THEN
								hasMoreFrames := FALSE;
							RETURN END;

						ELSIF marker = SCGOP THEN
							stream.SkipBits(32);
							ReadTimecode;			(* SMPTE Timecode *)
							stream.SkipBits(1);		(* closed GOP -> if closed wipe out prev and next buffer (black) *)
							stream.SkipBits(1);		(* broken link *)
							stream.SkipBits(5);		(* not used, should be 0... *)

							(* temporal reference restarts at zero *)
							frameNr := 0;
							prevRef.frameNr := -1;	(* make sure they are at most used as reference *)
							nextRef.frameNr := -1;	(* make sure they are at most used as reference *)

						ELSIF marker = SCSequenceEnd THEN
							(* video sequence finished - there are no more frames to be decoded *)
							hasMoreFrames := FALSE;
							RETURN;

						ELSE
							KernelLog.String("Unexpected marker found: "); KernelLog.Hex(ORD(marker), -1); KernelLog.Ln;
							RETURN;
						END;

						IF ~GotoNextMarker(stream, marker) THEN RETURN END;
					END;

					(* parse picture header *)
					stream.SkipBits(32);
					tempRef := stream.GetBits(10);							(* temporal reference *)
					curFrame.frameNr := tempRef;
					picType := stream.GetBits(3);								(* the picture type (I, P, B or D) *)
					frametype := picType;
					curFrame.picType := picType;
					stream.SkipBits(16);										(* vbv buffer delay -> not relevant for us *)

					IF tempRef < frameNr THEN
						frameNr := tempRef;
					END;

					IF (picType = 2) OR (picType = 3) THEN
						IF stream.ShowBits(1) = 1 THEN
							mvinfos.fullPel[mv1][forward] := TRUE;
						ELSE
							mvinfos.fullPel[mv1][forward] := FALSE;
						END;
						stream.SkipBits(1);

						mvinfos.fCode[mv1][forward] := stream.GetBits(3);
						mvinfos.rSize[mv1][forward] := mvinfos.fCode[mv1][forward] - 1;
						mvinfos.f[mv1][forward] := SYSTEM.VAL(LONGINT, {mvinfos.rSize[mv1][forward]});		(* 2 ^ rSize *)
					END;

					IF picType = 3 THEN
						IF stream.ShowBits(1) = 1 THEN
							mvinfos.fullPel[mv1][backward] := TRUE;
						ELSE
							mvinfos.fullPel[mv1][backward] := FALSE;
						END;
						stream.SkipBits(1);

						mvinfos.fCode[mv1][backward] := stream.GetBits(3);
						mvinfos.rSize[mv1][backward] := mvinfos.fCode[mv1][backward] - 1;
						mvinfos.f[mv1][backward] := SYSTEM.VAL(LONGINT, {mvinfos.rSize[mv1][backward]});		(* 2 ^ rSize *)
					END;

					WHILE stream.ShowBits(1) = 1 DO
						stream.SkipBits(1);				(* extra information follows *)
						stream.SkipBits(8);				(* undefined by the standard *)
					END;

					stream.SkipBits(1);					(* skip '0' marker bit *)

					IF ~stream.HasMoreData() OR reader.eof THEN
						hasMoreFrames := FALSE;
						RETURN;
					END;

					IF ~GotoNextMarker(stream, marker) THEN RETURN END;

					(* read extension data if present *)
					IF marker = SCExtension THEN
						IF ~MPEG2 THEN
							HALT(1234);
						END;
						stream.SkipBits(32);
						IF stream.ShowBits(4) # 8 THEN
							RETURN;
						ELSE
							stream.SkipBits(4);
						END;
						IF ~reader.ReadPictureCodingExtension(picExt, mvinfos) THEN RETURN END;
						IF reader.eof THEN hasMoreFrames := FALSE; RETURN END;
						IF picExt.framePredFrameDct THEN frameMotionType := FMTFrame END;
						IF ~GotoNextMarker(stream, marker) THEN RETURN END;
						IF ~GotoNextMarker(stream, marker) THEN RETURN END;
					ELSIF MPEG2 THEN
						(* MPEG-2 requires a picture extension ! *)
						KernelLog.String("MPEG-2 picture extension not found"); KernelLog.Ln;
						HALT(1234);
					END;

					(* read user data if present *)
					IF marker = SCUserData THEN
						stream.SkipBits(32);
						WHILE stream.ShowBits(24) # 1 DO
							stream.SkipBits(8);
						END;
						IF ~GotoNextMarker(stream, marker) THEN RETURN END;
					END;

					(* now we are really ready to decode the picture *)
					IF (picType = 1) OR (picType = 2) OR (picType = 3) THEN
						REPEAT
							res := DecodeSlice(picType);
							IF ~res THEN hasMoreFrames := FALSE; RETURN END;
							nextCode := stream.ShowBits(32);
						UNTIL ~(res & (nextCode > 100H) & (nextCode <= 1AFH));
					ELSIF picType = 4 THEN
						(* D-Picture *)
						RETURN;		(* D-Pictures not supported *)
					ELSE
						(* illegal or reserved value *)
						RETURN;
					END;

					IF tempRef > frameNr THEN
						(* dont display the frame yet - it is a future reference for upcoming B-Pics *)
						tmpFrame := nextRef;
						nextRef := curFrame;
						curFrame := tmpFrame;
					END;
				UNTIL tempRef <= frameNr;
			END;

			(* now we are sure that the correct frame is in the curFrame buffer *)

			(* store I- and P-Pictures as prediction for further pics *)
			IF (curFrame.picType = 1) OR (curFrame.picType = 2) THEN
				tmpFrame := prevRef;
				prevRef := curFrame;
				curFrame := tmpFrame;
				nextFrameToRender := prevRef;
			ELSE
				nextFrameToRender := curFrame;
			END;
		END Next;

		(* Decode one slice. Precondition: stream is positioned at the beginning of a slice *)
		PROCEDURE DecodeSlice(type: LONGINT):BOOLEAN;
		VAR
			quantScale: LONGINT;
			marker: CHAR;

		BEGIN
			(* re-init DC prediction *)
			IF MPEG2 THEN
				dcY := MPEGTables.DCP[picExt.dcPrecision];
				dcCb := MPEGTables.DCP[picExt.dcPrecision];
				dcCr := MPEGTables.DCP[picExt.dcPrecision];
			ELSE
				dcY := 8 * 128;
				dcCb := 8 * 128;
				dcCr := 8 * 128;
			END;

			(* re-init motion vector prediction *)
			mvinfos.pmv[mv1][forward][horizontal] := 0;
			mvinfos.pmv[mv1][forward][vertical] := 0;
			mvinfos.pmv[mv1][backward][horizontal] := 0;
			mvinfos.pmv[mv1][backward][vertical] := 0;
			mvinfos.pmv[mv2][forward][horizontal] := 0;
			mvinfos.pmv[mv2][forward][vertical] := 0;
			mvinfos.pmv[mv2][backward][horizontal] := 0;
			mvinfos.pmv[mv2][backward][vertical] := 0;
			mvinfos.motionVerticalFieldSelect[mv1][forward] := FALSE;
			mvinfos.motionVerticalFieldSelect[mv1][backward] := FALSE;
			mvinfos.motionVerticalFieldSelect[mv2][forward] := TRUE;
			mvinfos.motionVerticalFieldSelect[mv2][backward] := TRUE;

			macroblockNr := 0;
			stream.SkipBits(24);
			mbAddress := ((stream.GetBits(8)-1) * videoWidthDiv16) - 1;
			mbAddressLast := mbAddress;
			quantScale := stream.GetBits(5);

			IF quantScale < 0 THEN hasMoreFrames := FALSE; RETURN FALSE END;

			IF MPEG2 THEN
				(* translate qscalecode to qscale *)
				IF picExt.qScaleType THEN
					(* take from table 1 *)
					quantScale := MPEGTables.QS1[quantScale];
				ELSE
					(* take from table 0 *)
					quantScale := MPEGTables.QS0[quantScale];
				END;
			END;

			(* extra slice information, not yet defined by the standard *)
			WHILE stream.ShowBits(1) = 1 DO
				stream.SkipBits(9);
			END;
			stream.SkipBits(1);

			(* decode all macroblocks in this slice *)
			WHILE stream.ShowBits(23) # 0 DO
				IF ~DecodeMacroBlock(type, quantScale) THEN hasMoreFrames := FALSE; RETURN FALSE END;
			END;

			RETURN GotoNextMarker(stream, marker);
		END DecodeSlice;

		(* Decode one macroblock *)
		PROCEDURE DecodeMacroBlock(type: LONGINT; VAR quantScale: LONGINT):BOOLEAN;
		VAR
			tmp: LONGINT;
			cbp: LONGINT;
			cbpBits: LONGINT;
			mbIntra, mbPattern, mbMotionBack, mbMotionForw, mbQuant: BOOLEAN;
			i: LONGINT;
			offsetX, offsetY, offsetXDiv2, offsetYDiv2: LONGINT;
			first: BOOLEAN;					(* whether or not a block is the first one coded in a macroblock *)
			fpmf, fpmb: LONGINT;		(* full pel multiplier forward & backward *)
			yoffs, yincr: LONGINT;		(* parameters for CopyBlock - different for interlaced/non-interlaced blocks *)

		BEGIN
			INC(macroblockNr);

			(* skip stuffing *)
			WHILE stream.ShowBits(11) = 15 DO
				stream.SkipBits(11);
			END;

			(* read the macroblock address *)
			WHILE stream.ShowBits(11) = 8 DO
				stream.SkipBits(11);
				INC(mbAddress, 33);
			END;
			tmp := reader.ReadAddressIncrement();
			IF reader.eof THEN hasMoreFrames := FALSE END;
			IF tmp # -1 THEN
				INC(mbAddress, tmp);
			ELSE
				RETURN FALSE;
			END;

			mbSkipped := (mbAddress - mbAddressLast) > 1;

			(* fill in prediction for all skipped macroblocks *)
			IF mbSkipped THEN
				CASE type OF
					1:	(* I-Frame *)
						(* I-Frames are not allowed to skip MBs *)
						HALT(1234);

				|	2:	(* P-Frame *)
						FOR i := mbAddressLast + 1 TO (mbAddress - 1) DO
							(* motion vector reset to zero, just copy prediction *)
							InsertPrediction(TRUE, FALSE, i, 0, 0, 0, 0);
						END;

				|	3:	(* B-Frame *)
						IF mvinfos.fullPel[mv1][forward] THEN
							fpmf := 2;
						ELSE
							fpmf := 1;
						END;

						IF mvinfos.fullPel[mv1][backward] THEN
							fpmb := 2;
						ELSE
							fpmb := 1;
						END;

						FOR i := mbAddressLast + 1 TO (mbAddress - 1) DO
							(* use motion vector and prediction type (forward, backward, both) from last mb *)
							InsertPrediction(
								mbMotionForwOld,
								mbMotionBackOld,
								i,
								 mvinfos.mv[mv1][forward][horizontal] * fpmf,
								 mvinfos.mv[mv1][forward][vertical] * fpmf,
								 mvinfos.mv[mv1][backward][horizontal] * fpmb,
								 mvinfos.mv[mv1][backward][vertical] * fpmb);
						END;
				END;
			END;

			(* read macroblock type *)
			IF ~reader.ReadMacroBlockType(type, mbIntra, mbPattern, mbMotionBack, mbMotionForw, mbQuant) THEN
				RETURN FALSE;
			END;

			IF reader.eof THEN
				RETURN FALSE;
			END;

			IF MPEG2 THEN
				(* read additional macroblock info *)
				IF mbMotionForw OR mbMotionBack THEN
					IF picExt.picStructure = PicStructFrame THEN
						IF ~picExt.framePredFrameDct THEN
							frameMotionType := stream.GetBits(2);
						END;
					ELSE
						(* read field motion type -> interlaced video not supported atm *)
						HALT(1234);
					END;
				END;

				IF (picExt.picStructure = PicStructFrame) & (~picExt.framePredFrameDct) & (mbIntra OR mbPattern) THEN
					dctType := (stream.GetBits(1) = 1);
				ELSE
					dctType := FALSE;
				END;
			END;

			(* concealment vectors in MPEG-2 -> not supported atm *)
			IF picExt.concealmentMV THEN
				HALT(1234);
			END;

			(* reset motion prediction if required *)
			IF	mbIntraOld OR
				((type = 2) & mbSkipped) OR
				((type = 2) & ~mbMotionForw) THEN
				mvinfos.pmv[0][0][0] := 0;
				mvinfos.pmv[0][0][1] := 0;
				mvinfos.pmv[0][1][0] := 0;
				mvinfos.pmv[0][1][1] := 0;
				mvinfos.pmv[1][0][0] := 0;
				mvinfos.pmv[1][0][1] := 0;
				mvinfos.pmv[1][1][0] := 0;
				mvinfos.pmv[1][1][1] := 0;
				mvinfos.mv[0][0][0] := 0;
				mvinfos.mv[0][0][1] := 0;
				mvinfos.mv[0][1][0] := 0;
				mvinfos.mv[0][1][1] := 0;
				mvinfos.mv[1][0][0] := 0;
				mvinfos.mv[1][0][1] := 0;
				mvinfos.mv[1][1][0] := 0;
				mvinfos.mv[1][1][1] := 0;
				mvinfos.motionVerticalFieldSelect[mv1][forward] := FALSE;
				mvinfos.motionVerticalFieldSelect[mv1][backward] := FALSE;
				mvinfos.motionVerticalFieldSelect[mv2][forward] := TRUE;
				mvinfos.motionVerticalFieldSelect[mv2][backward] := TRUE;
			END;

			IF ~stream.HasMoreData() THEN
				hasMoreFrames := FALSE;
				RETURN FALSE;
			END;

			(* read new quantizer scale *)
			IF mbQuant THEN
				quantScale := stream.GetBits(5);
				IF quantScale < 0 THEN hasMoreFrames := FALSE; RETURN FALSE END;

				IF MPEG2 THEN
					(* translate qscalecode to qscale *)
					IF picExt.qScaleType THEN
						(* take from table 1 *)
						quantScale := MPEGTables.QS1[quantScale];
					ELSE
						(* take from table 0 *)
						quantScale := MPEGTables.QS0[quantScale];
					END;
				END;
			END;

			(* read forward motion vector *)
			IF mbMotionForw OR (MPEG2 & mbIntra & picExt.concealmentMV) THEN
				IF ~MPEG2 THEN
					mvinfos.motionCode[mv1][forward][horizontal] := reader.ReadMotionCode();
					IF (mvinfos.fCode[mv1][forward] # 1) & (mvinfos.motionCode[mv1][forward][horizontal] # 0) THEN
						mvinfos.motionResidual[mv1][forward][horizontal] := stream.GetBits(mvinfos.fCode[mv1][forward]-1);
					END;
					mvinfos.motionCode[mv1][forward][vertical] := reader.ReadMotionCode();
					IF (mvinfos.fCode[mv1][forward] # 1) & (mvinfos.motionCode[mv1][forward][vertical] # 0) THEN
						mvinfos.motionResidual[mv1][forward][vertical] := stream.GetBits(mvinfos.fCode[mv1][forward]-1);
					END;
				ELSE
					(* MPEG-2 *)
					reader.ReadMotionVectors(0, mvinfos, frameMotionType);
				END;
			END;

			(* read backward motion vector *)
			IF mbMotionBack OR (MPEG2 & mbIntra & picExt.concealmentMV) THEN
				IF ~MPEG2 THEN
					mvinfos.motionCode[mv1][backward][horizontal] := reader.ReadMotionCode();
					IF (mvinfos.fCode[mv1][backward] # 1) & (mvinfos.motionCode[mv1][backward][horizontal] # 0) THEN
						mvinfos.motionResidual[mv1][backward][horizontal] := stream.GetBits(mvinfos.fCode[mv1][backward]-1);
					END;
					mvinfos.motionCode[mv1][backward][vertical] := reader.ReadMotionCode();
					IF (mvinfos.fCode[mv1][backward] # 1) & (mvinfos.motionCode[mv1][backward][vertical] # 0) THEN
						mvinfos.motionResidual[mv1][backward][vertical] := stream.GetBits(mvinfos.fCode[mv1][backward]-1);
					END;
				ELSE
					(* MPEG-2 *)
					reader.ReadMotionVectors(1, mvinfos, frameMotionType);
				END;
			END;

			IF reader.eof OR ~stream.HasMoreData() THEN
				hasMoreFrames := FALSE;
				RETURN FALSE;
			END;

			(* read pattern of coded blocks (CBP) *)
			IF mbPattern THEN
				IF stream.ShowBits(3) = 0 THEN
					(* code is 8 or 9 bits long, use table CBP9 *)
					cbpBits := stream.ShowBits(9);
					cbp := MPEGTables.CBP9[cbpBits][0];
					stream.SkipBits(MPEGTables.CBP9[cbpBits][1]);
				ELSE
					(* code is at most 7 bits long, use table CBP7 *)
					cbpBits := stream.ShowBits(7)-16;
					cbp := MPEGTables.CBP7[cbpBits][0];
					stream.SkipBits(MPEGTables.CBP7[cbpBits][1]);
				END;
			ELSE
				IF mbIntra THEN
					(* intra-blocks: all blocks are coded *)
					cbp := 63;
				ELSE
					(* inter-block: no blocks are coded if no pattern is specified *)
					cbp := 0;
				END;
			END;

			(* calculate motion vectors *)
			IF ~MPEG2 THEN
				IF mbMotionForw THEN
					MotionDisplacement(forward, horizontal);
					MotionDisplacement(forward, vertical);
				END;

				IF mbMotionBack THEN
					MotionDisplacement(backward, horizontal);
					MotionDisplacement(backward, vertical);
				END;
			ELSE
				(* MPEG-2 *)

				(* decode all required motion vectors *)
				IF mbMotionForw THEN
					DecodeMotionVectors(mv1, forward, horizontal);
					DecodeMotionVectors(mv1, forward, vertical);
				END;
				IF mbMotionBack THEN
					DecodeMotionVectors(mv1, backward, horizontal);
					DecodeMotionVectors(mv1, backward, vertical);
				END;

				IF frameMotionType = FMTField THEN
					(* decode second pair of motion vectors *)
					IF mbMotionForw THEN
						DecodeMotionVectors(mv2, forward, horizontal);
						DecodeMotionVectors(mv2, forward, vertical);
					END;
					IF mbMotionBack THEN
						DecodeMotionVectors(mv2, backward, horizontal);
						DecodeMotionVectors(mv2, backward, vertical);
					END;
				END;

				(* adjust predictions of non-used MVs *)
				IF frameMotionType = FMTFrame THEN
					IF mbMotionForw THEN
						mvinfos.pmv[mv2][forward][horizontal] := mvinfos.pmv[mv1][forward][horizontal];
						mvinfos.pmv[mv2][forward][vertical] := mvinfos.pmv[mv1][forward][vertical];
					END;

					IF mbMotionBack THEN
						mvinfos.pmv[mv2][backward][horizontal] := mvinfos.pmv[mv1][backward][horizontal];
						mvinfos.pmv[mv2][backward][vertical] := mvinfos.pmv[mv1][backward][vertical];
					END;
				END;
			END;

			IF MPEG2 THEN
				mvinfos.fullPel[mv1][forward] := FALSE;
				mvinfos.fullPel[mv1][backward] := FALSE;
			END;

			IF (type # 1) & ~mbIntra THEN
				(* P- or B-Frame *)
				IF frameMotionType = FMTField THEN
					(* MPEG2 interlaced block *)
					InsertInterlacedPrediction(
						(type = 2) OR ((type = 3) & mbMotionForw),
						mbMotionBack,
						mbAddress,
						mvinfos);
				ELSE
					(* MPEG1 or MPEG2 *)
					IF mvinfos.fullPel[mv1][forward] THEN
						fpmf := 2;
					ELSE
						fpmf := 1;
					END;

					IF mvinfos.fullPel[mv1][backward] THEN
						fpmb := 2;
					ELSE
						fpmb := 1;
					END;

					InsertPrediction(
						(type = 2) OR ((type = 3) & mbMotionForw),
						mbMotionBack,
						mbAddress,
						 mvinfos.mv[mv1][forward][horizontal] * fpmf,
						 mvinfos.mv[mv1][forward][vertical] * fpmf,
						 mvinfos.mv[mv1][backward][horizontal] * fpmb,
						 mvinfos.mv[mv1][backward][vertical] * fpmb);
					END;
			END;

			(* calculate offset of the macroblock in the current frame *)
			offsetX := (mbAddress MOD (videoWidthDiv16)) * 16;
			offsetY := (mbAddress DIV (videoWidthDiv16)) * 16;
			offsetXDiv2 := offsetX DIV 2;
			offsetYDiv2 := offsetY DIV 2;

			(* decode all coded blocks *)
			IF ~MPEG2 THEN
				first := TRUE;

				(* Y0 *)
				IF 5 IN SYSTEM.VAL(SET, cbp) THEN
					IF ~DecodeBlock(0, block, mbIntra, quantScale, first, type) THEN RETURN FALSE END;
					IF mbIntra THEN
						blocks.TransferIDCTCopy(block, curFrame.buffer, offsetY*videoWidth + offsetX, videoWidth);
					ELSE
						blocks.TransferIDCTAdd(block, curFrame.buffer, offsetY*videoWidth + offsetX, videoWidth);
					END;
					first := FALSE;
				END;

				(* Y1 *)
				IF 4 IN SYSTEM.VAL(SET, cbp) THEN
					IF ~DecodeBlock(1, block, mbIntra, quantScale, first, type) THEN RETURN FALSE END;
					IF mbIntra THEN
						blocks.TransferIDCTCopy(block, curFrame.buffer, offsetY*videoWidth + offsetX + 8, videoWidth);
					ELSE
						blocks.TransferIDCTAdd(block, curFrame.buffer, offsetY*videoWidth + offsetX + 8, videoWidth);
					END;
					first := FALSE;
				END;

				(* Y2 *)
				IF 3 IN SYSTEM.VAL(SET, cbp) THEN
					IF ~DecodeBlock(2, block, mbIntra, quantScale, first, type) THEN RETURN FALSE END;
					IF mbIntra THEN
						blocks.TransferIDCTCopy(block, curFrame.buffer, (offsetY+8)*videoWidth + offsetX, videoWidth);
					ELSE
						blocks.TransferIDCTAdd(block, curFrame.buffer, (offsetY+8)*videoWidth + offsetX, videoWidth);
					END;
					first := FALSE;
				END;

				(* Y3 *)
				IF 2 IN SYSTEM.VAL(SET, cbp) THEN
					IF ~DecodeBlock(3, block, mbIntra, quantScale, first, type) THEN RETURN FALSE END;
					IF mbIntra THEN
						blocks.TransferIDCTCopy(block, curFrame.buffer, (offsetY+8)*videoWidth + offsetX+8, videoWidth);
					ELSE
						blocks.TransferIDCTAdd(block, curFrame.buffer, (offsetY+8)*videoWidth + offsetX+8, videoWidth);
					END;
					first := FALSE;
				END;

				(* Cb *)
				IF 1 IN SYSTEM.VAL(SET, cbp) THEN
					IF ~DecodeBlock(4, block, mbIntra, quantScale, TRUE, type) THEN RETURN FALSE END;
					IF mbIntra THEN
						blocks.TransferIDCTCopy(block, curFrame.buffer, videoWidth*videoHeight + offsetYDiv2*videoWidthDiv2 + offsetXDiv2, videoWidthDiv2);
					ELSE
						blocks.TransferIDCTAdd(block, curFrame.buffer, videoWidth*videoHeight + offsetYDiv2*videoWidthDiv2 + offsetXDiv2, videoWidthDiv2);
					END;
				END;

				(* Cr *)
				IF 0 IN SYSTEM.VAL(SET, cbp) THEN
					IF ~DecodeBlock(5, block, mbIntra, quantScale, TRUE, type) THEN RETURN FALSE END;
					IF mbIntra THEN
						blocks.TransferIDCTCopy(block, curFrame.buffer, videoWidth*videoHeight + videoWidthDiv2*videoHeightDiv2 + offsetYDiv2*videoWidthDiv2 + offsetXDiv2, videoWidthDiv2);
					ELSE
						blocks.TransferIDCTAdd(block, curFrame.buffer, videoWidth*videoHeight + videoWidthDiv2*videoHeightDiv2 + offsetYDiv2*videoWidthDiv2 + offsetXDiv2, videoWidthDiv2);
					END;
				END;
			ELSE
				(* MPEG-2 *)

				IF dctType THEN
					(* interlaced block *)
					yincr := 2;
					yoffs := 1;
				ELSE
					(* progressive block *)
					yincr := 1;
					yoffs := 8;
				END;

				first := TRUE;

				(* Y0 *)
				IF 5 IN SYSTEM.VAL(SET, cbp) THEN
					IF ~DecodeBlock2(0, block, mbIntra, quantScale, first, type) THEN RETURN FALSE END;
					IF mbIntra THEN
						blocks.TransferIDCTCopy(block, curFrame.buffer, offsetY*videoWidth + offsetX, videoWidth * yincr);
					ELSE
						blocks.TransferIDCTAdd(block, curFrame.buffer, offsetY*videoWidth + offsetX, videoWidth * yincr);
					END;
					first := FALSE;
				END;

				(* Y1 *)
				IF 4 IN SYSTEM.VAL(SET, cbp) THEN
					IF ~DecodeBlock2(1, block, mbIntra, quantScale, first, type) THEN RETURN FALSE END;
					IF mbIntra THEN
						blocks.TransferIDCTCopy(block, curFrame.buffer, offsetY*videoWidth + offsetX + 8, videoWidth * yincr);
					ELSE
						blocks.TransferIDCTAdd(block, curFrame.buffer, offsetY*videoWidth + offsetX + 8, videoWidth * yincr);
					END;
					first := FALSE;
				END;

				(* Y2 *)
				IF 3 IN SYSTEM.VAL(SET, cbp) THEN
					IF ~DecodeBlock2(2, block, mbIntra, quantScale, first, type) THEN RETURN FALSE END;
					IF mbIntra THEN
						blocks.TransferIDCTCopy(block, curFrame.buffer, (offsetY+yoffs)*videoWidth + offsetX, videoWidth * yincr);
					ELSE
						blocks.TransferIDCTAdd(block, curFrame.buffer, (offsetY+yoffs)*videoWidth + offsetX, videoWidth * yincr);
					END;
					first := FALSE;
				END;

				(* Y3 *)
				IF 2 IN SYSTEM.VAL(SET, cbp) THEN
					IF ~DecodeBlock2(3, block, mbIntra, quantScale, first, type) THEN RETURN FALSE END;
					IF mbIntra THEN
						blocks.TransferIDCTCopy(block, curFrame.buffer, (offsetY+yoffs)*videoWidth + offsetX + 8, videoWidth * yincr);
					ELSE
						blocks.TransferIDCTAdd(block, curFrame.buffer, (offsetY+yoffs)*videoWidth + offsetX + 8, videoWidth * yincr);
					END;
				END;

				(* Cb *)
				IF 1 IN SYSTEM.VAL(SET, cbp) THEN
					IF ~DecodeBlock2(4, block, mbIntra, quantScale, TRUE, type) THEN RETURN FALSE END;
					IF mbIntra THEN
						blocks.TransferIDCTCopy(block, curFrame.buffer, videoWidth*videoHeight + offsetYDiv2*videoWidthDiv2 + offsetXDiv2, videoWidthDiv2);
					ELSE
						blocks.TransferIDCTAdd(block, curFrame.buffer, videoWidth*videoHeight + offsetYDiv2*videoWidthDiv2 + offsetXDiv2, videoWidthDiv2);
					END;
				END;

				IF 0 IN SYSTEM.VAL(SET, cbp) THEN
					IF ~DecodeBlock2(5, block, mbIntra, quantScale, TRUE, type) THEN RETURN FALSE END;
					IF mbIntra THEN
						blocks.TransferIDCTCopy(block, curFrame.buffer, videoWidth*videoHeight + videoWidthDiv2*videoHeightDiv2 + offsetYDiv2*videoWidthDiv2 + offsetXDiv2, videoWidthDiv2);
					ELSE
						blocks.TransferIDCTAdd(block, curFrame.buffer, videoWidth*videoHeight + videoWidthDiv2*videoHeightDiv2 + offsetYDiv2*videoWidthDiv2 + offsetXDiv2, videoWidthDiv2);
					END;
				END;
			END;

			(* skip "end of macroblock"-bit of a D-Picture *)
			IF type = 4 THEN
				IF stream.ShowBits(1) # 1 THEN
					RETURN FALSE;
				ELSE
					stream.SkipBits(1);
				END;
			END;

			mbMotionForwOld := mbMotionForw;
			mbMotionBackOld := mbMotionBack;
			mbIntraOld := mbIntra;
			mbAddressLast := mbAddress;

			IF mbIntra THEN
				mbAddressLastIntra := mbAddress;
			END;

			RETURN TRUE;
		END DecodeMacroBlock;


		PROCEDURE InsertInterlacedPrediction(forw, back: BOOLEAN; address: LONGINT; VAR mvi: Util.MotionVectorInfos);
		VAR
			yOffs, cbOffs, crOffs: LONGINT;				(* offsets in the Frame.buffer array *)
			mvfx1, mvfy1, mvbx1, mvby1: LONGINT;		(* luminance motion vectors, first set *)
			mvfx2, mvfy2, mvbx2, mvby2: LONGINT;		(* luminance motion vectors, second set *)
			mvfx1c, mvfy1c, mvbx1c, mvby1c: LONGINT;		(* chrominance motion vectors, first set *)
			mvfx2c, mvfy2c, mvbx2c, mvby2c: LONGINT;		(* chrominance motion vectors, second set *)

		BEGIN
			(* calculate position of the destination macroblock *)
			yOffs := (address DIV videoWidthDiv16) * videoWidth * 16 + (address MOD videoWidthDiv16) * 16;
			cbOffs := videoWidth * videoHeight + (address DIV videoWidthDiv16) * videoWidthDiv2 * 8 + (address MOD videoWidthDiv16) * 8;
			crOffs := cbOffs + videoHeightDiv2 * videoWidthDiv2;

			(* set motion vectors (vertical components are field-based, so they are handled differently) *)
			mvfx1 := mvi.mv[mv1][forward][horizontal];
			mvfy1 := mvi.mv[mv1][forward][vertical];
			mvbx1 := mvi.mv[mv1][backward][horizontal];
			mvby1 := mvi.mv[mv1][backward][vertical];
			mvfx2 := mvi.mv[mv2][forward][horizontal];
			mvfy2 := mvi.mv[mv2][forward][vertical];
			mvbx2 := mvi.mv[mv2][backward][horizontal];
			mvby2 := mvi.mv[mv2][backward][vertical];

			mvfx1c := mvfx1 DIV 2;
			mvfy1c := mvfy1 DIV 2;
			mvbx1c := mvbx1 DIV 2;
			mvby1c := mvby1 DIV 2;
			mvfx2c := mvfx2 DIV 2;
			mvfy2c := mvfy2 DIV 2;
			mvbx2c := mvbx2 DIV 2;
			mvby2c := mvby2 DIV 2;

			IF mvi.motionVerticalFieldSelect[mv1][forward] THEN INC(mvfy1); INC(mvfy1c) END;
			IF mvi.motionVerticalFieldSelect[mv1][backward] THEN INC(mvby1); INC(mvby1c) END;
			IF ~mvi.motionVerticalFieldSelect[mv2][forward] THEN DEC(mvfy2); DEC(mvfy2c) END;
			IF ~mvi.motionVerticalFieldSelect[mv2][backward] THEN DEC(mvby2); DEC(mvby2c) END;

			IF forw THEN
				blocks.MoveBlockOverwrite(prevRef.buffer, curFrame.buffer, yOffs, mvfx1, mvfy1, 2*videoWidth, 2*videoWidth, 8);
				blocks.MoveBlockOverwrite(prevRef.buffer, curFrame.buffer, yOffs+8, mvfx1, mvfy1, 2*videoWidth, 2*videoWidth, 8);
				blocks.MoveBlockOverwrite(prevRef.buffer, curFrame.buffer, yOffs+videoWidth, mvfx2, mvfy2, 2*videoWidth, 2*videoWidth, 8);
				blocks.MoveBlockOverwrite(prevRef.buffer, curFrame.buffer, yOffs+videoWidth+8, mvfx2, mvfy2, 2*videoWidth, 2*videoWidth, 8);
				blocks.MoveBlockOverwrite(prevRef.buffer, curFrame.buffer, cbOffs, mvfx1c, mvfy1c, videoWidth, videoWidth, 4);
				blocks.MoveBlockOverwrite(prevRef.buffer, curFrame.buffer, cbOffs+videoWidthDiv2, mvfx2c, mvfy2c, videoWidth, videoWidth, 4);
				blocks.MoveBlockOverwrite(prevRef.buffer, curFrame.buffer, crOffs, mvfx1c, mvfy1c, videoWidth, videoWidth, 4);
				blocks.MoveBlockOverwrite(prevRef.buffer, curFrame.buffer, crOffs+videoWidthDiv2, mvfx2c, mvfy2c, videoWidth, videoWidth, 4);
			END;

			IF back THEN
				IF forw THEN
					blocks.MoveBlockInterp(nextRef.buffer, curFrame.buffer, yOffs, mvbx1, mvby1, 2*videoWidth, 2*videoWidth, 8);
					blocks.MoveBlockInterp(nextRef.buffer, curFrame.buffer, yOffs+8, mvbx1, mvby1, 2*videoWidth, 2*videoWidth, 8);
					blocks.MoveBlockInterp(nextRef.buffer, curFrame.buffer, yOffs+videoWidth, mvbx2, mvby2, 2*videoWidth, 2*videoWidth, 8);
					blocks.MoveBlockInterp(nextRef.buffer, curFrame.buffer, yOffs+videoWidth+8, mvbx2, mvby2, 2*videoWidth, 2*videoWidth, 8);
					blocks.MoveBlockInterp(nextRef.buffer, curFrame.buffer, cbOffs, mvbx1c, mvby1c, videoWidth, videoWidth, 4);
					blocks.MoveBlockInterp(nextRef.buffer, curFrame.buffer, cbOffs+videoWidthDiv2, mvbx2c, mvby2c, videoWidth, videoWidth, 4);
					blocks.MoveBlockInterp(nextRef.buffer, curFrame.buffer, crOffs, mvbx1c, mvby1c, videoWidth, videoWidth, 4);
					blocks.MoveBlockInterp(nextRef.buffer, curFrame.buffer, crOffs+videoWidthDiv2, mvbx2c, mvby2c, videoWidth, videoWidth, 4);
				ELSE
					blocks.MoveBlockOverwrite(nextRef.buffer, curFrame.buffer, yOffs, mvbx1, mvby1, 2*videoWidth, 2*videoWidth, 8);
					blocks.MoveBlockOverwrite(nextRef.buffer, curFrame.buffer, yOffs+8, mvbx1, mvby1, 2*videoWidth, 2*videoWidth, 8);
					blocks.MoveBlockOverwrite(nextRef.buffer, curFrame.buffer, yOffs+videoWidth, mvbx2, mvby2, 2*videoWidth, 2*videoWidth, 8);
					blocks.MoveBlockOverwrite(nextRef.buffer, curFrame.buffer, yOffs+videoWidth+8, mvbx2, mvby2, 2*videoWidth, 2*videoWidth, 8);
					blocks.MoveBlockOverwrite(nextRef.buffer, curFrame.buffer, cbOffs, mvbx1c, mvby1c, videoWidth, videoWidth, 4);
					blocks.MoveBlockOverwrite(nextRef.buffer, curFrame.buffer, cbOffs+videoWidthDiv2, mvbx2c, mvby2c, videoWidth, videoWidth, 4);
					blocks.MoveBlockOverwrite(nextRef.buffer, curFrame.buffer, crOffs, mvbx1c, mvby1c, videoWidth, videoWidth, 4);
					blocks.MoveBlockOverwrite(nextRef.buffer, curFrame.buffer, crOffs+videoWidthDiv2, mvbx2c, mvby2c, videoWidth, videoWidth, 4);
				END;
			END;
		END InsertInterlacedPrediction;

		(* copy the prediction into a macroblock *)
		(* param names (capitals): MotionVector, Forward, Backward *)
		PROCEDURE InsertPrediction(forward, backward: BOOLEAN; address, mvfx, mvfy, mvbx, mvby: LONGINT);
		VAR
			yOffs, cbOffs, crOffs: LONGINT;				(* offsets in the Frame.buffer array *)

		BEGIN
			(* calculate position of the destination macroblock *)
			yOffs := (address DIV videoWidthDiv16) * videoWidth * 16 + (address MOD videoWidthDiv16) * 16;
			cbOffs := videoWidth * videoHeight + (address DIV videoWidthDiv16) * videoWidthDiv2 * 8 + (address MOD videoWidthDiv16) * 8;
			crOffs := cbOffs + videoHeightDiv2 * videoWidthDiv2;

			IF forward THEN
				blocks.MoveBlockOverwrite(prevRef.buffer, curFrame.buffer, yOffs, mvfx, mvfy, videoWidth, videoWidth, 16);
				blocks.MoveBlockOverwrite(prevRef.buffer, curFrame.buffer, yOffs+8, mvfx, mvfy, videoWidth, videoWidth, 16);
				blocks.MoveBlockOverwrite(prevRef.buffer, curFrame.buffer, cbOffs, mvfx DIV 2, mvfy DIV 2, videoWidthDiv2, videoWidthDiv2, 8);
				blocks.MoveBlockOverwrite(prevRef.buffer, curFrame.buffer, crOffs, mvfx DIV 2, mvfy DIV 2, videoWidthDiv2, videoWidthDiv2, 8);
			END;

			IF backward THEN
				IF forward THEN
					blocks.MoveBlockInterp(nextRef.buffer, curFrame.buffer, yOffs, mvbx, mvby, videoWidth, videoWidth, 16);
					blocks.MoveBlockInterp(nextRef.buffer, curFrame.buffer, yOffs+8, mvbx, mvby, videoWidth, videoWidth, 16);
					blocks.MoveBlockInterp(nextRef.buffer, curFrame.buffer, cbOffs, mvbx DIV 2, mvby DIV 2, videoWidthDiv2, videoWidthDiv2, 8);
					blocks.MoveBlockInterp(nextRef.buffer, curFrame.buffer, crOffs, mvbx DIV 2, mvby DIV 2, videoWidthDiv2, videoWidthDiv2, 8);
				ELSE
					blocks.MoveBlockOverwrite(nextRef.buffer, curFrame.buffer, yOffs, mvbx, mvby, videoWidth, videoWidth, 16);
					blocks.MoveBlockOverwrite(nextRef.buffer, curFrame.buffer, yOffs+8, mvbx, mvby, videoWidth, videoWidth, 16);
					blocks.MoveBlockOverwrite(nextRef.buffer, curFrame.buffer, cbOffs, mvbx DIV 2, mvby DIV 2, videoWidthDiv2, videoWidthDiv2, 8);
					blocks.MoveBlockOverwrite(nextRef.buffer, curFrame.buffer, crOffs, mvbx DIV 2, mvby DIV 2, videoWidthDiv2, videoWidthDiv2, 8);
				END;
			END;
		END InsertPrediction;

		PROCEDURE DecodeMotionVectors(r, s, t: LONGINT);
		VAR
			rSize: LONGINT;
			f: LONGINT;
			high, low, range: LONGINT;
			delta: LONGINT;
			prediction: LONGINT;

			DEBUG: BOOLEAN;

		BEGIN
			DEBUG := (realFrameNr = -1) & (mbAddress > 1155) & (mbAddress < 1159);

			IF DEBUG THEN
				KernelLog.String("Macroblock "); KernelLog.Int(mbAddress, 0); KernelLog.Ln;
				KernelLog.String("+++ INPUT +++"); KernelLog.Ln;
				mvinfos.Dump(r, s, t);
			END;

			rSize := mvinfos.fCode[s][t] - 1;
			f := SYSTEM.VAL(LONGINT, {rSize});		(* 2 ^ rSize *)
			high := 16 * f - 1;
			low := (-16) * f ;
			range := 32 * f;

			IF (f = 1) OR (mvinfos.motionCode[r][s][t] = 0) THEN
				delta := mvinfos.motionCode[r][s][t];
			ELSE
				IF mvinfos.motionCode[r][s][t] > 0 THEN
					delta := (mvinfos.motionCode[r][s][t] - 1) * f + mvinfos.motionResidual[r][s][t] + 1;
				ELSE
					delta := - ((- mvinfos.motionCode[r][s][t] - 1) * f + mvinfos.motionResidual[r][s][t] + 1);
				END;
			END;

			IF (frameMotionType # FMTFrame) & (t = 1) & (picExt.picStructure = PicStructFrame) THEN
				prediction := mvinfos.pmv[r][s][t] DIV 2;
			ELSE
				prediction := mvinfos.pmv[r][s][t];
			END;

			mvinfos.mv[r][s][t] := prediction + delta;

			IF mvinfos.mv[r][s][t] < low THEN
				INC(mvinfos.mv[r][s][t], range);
			ELSIF mvinfos.mv[r][s][t] > high THEN
				DEC(mvinfos.mv[r][s][t], range);
			END;

			IF (frameMotionType # FMTFrame) & (t = 1) & (picExt.picStructure = PicStructFrame) THEN
				mvinfos.pmv[r][s][t] := mvinfos.mv[r][s][t] * 2;
			ELSE
				mvinfos.pmv[r][s][t] := mvinfos.mv[r][s][t];
			END;
		END DecodeMotionVectors;

		PROCEDURE MotionDisplacement(fb, hv: LONGINT);
		VAR
			delta: LONGINT;
			range: LONGINT;
			motionCode, motionResidual, f, prediction: LONGINT;
		BEGIN
			motionCode := mvinfos.motionCode[mv1][fb][hv];
			motionResidual := mvinfos.motionResidual[mv1][fb][hv];
			f := mvinfos.f[mv1][fb];
			prediction := mvinfos.pmv[mv1][fb][hv];

			IF (f = 1) OR (motionCode = 0) THEN
				delta := motionCode;
			ELSE
				delta := 1 + f * (motionCode * Sign(motionCode) - 1) + motionResidual;
				IF motionCode < 0 THEN
					delta := -delta;
				END;
			END;
			INC(prediction, delta);
			range := f * 32;
			IF prediction > (f * 16 - 1) THEN
				DEC(prediction, range);
			ELSIF prediction < -(f * 16) THEN
				INC(prediction, range);
			END;
			mvinfos.mv[mv1][fb][hv] := prediction;
			mvinfos.pmv[mv1][fb][hv] := prediction;
		END MotionDisplacement;

		(* MPEG-1 only !! *)
		PROCEDURE DecodeBlock(
			nr: SHORTINT;
			coeffs: Util.PointerToArrayOfLONGINT;
			intra: BOOLEAN;
			VAR qScale: LONGINT;
			first: BOOLEAN;
			type: LONGINT): BOOLEAN;
		VAR
			bits: LONGINT;
			size: LONGINT;
			dcDiff: LONGINT;
			tmp: LONGINT;
			cur: LONGINT;									(* current position in coeffs *)
			dummy: BOOLEAN;
			i: LONGINT;
			intraSkipped: BOOLEAN;

		BEGIN
			FOR i := 0 TO 63 DO
				coeffs[i] := 0;
			END;

			cur := 0;
			IF intra THEN
				(* read DC coefficient *)
				bits := stream.ShowBits(3);
				IF nr < 4 THEN
					(* intra coded luminance block *)
					IF bits = 7 THEN
						stream.SkipBits(3);
						size := 4;
						WHILE stream.ShowBits(1) = 1 DO
							INC(size);
							stream.SkipBits(1);
						END;
						INC(size);
						stream.SkipBits(1);
					ELSE
						size := MPEGTables.DCL3[bits][0];
						stream.SkipBits(MPEGTables.DCL3[bits][1]);
					END;
				ELSE
					(* intra coded chrominance block *)
					IF bits = 7 THEN
						stream.SkipBits(3);
						size := 3;
						WHILE stream.ShowBits(1) = 1 DO
							INC(size);
							stream.SkipBits(1);
						END;
						INC(size);
						stream.SkipBits(1);
					ELSE
						size := MPEGTables.DCC3[bits][0];
						stream.SkipBits(MPEGTables.DCC3[bits][1]);
					END;
				END;

				IF size # 0 THEN
					IF stream.ShowBits(1) = 0 THEN
						(* negative difference: invert all bits and make number negative *)
						tmp := stream.GetBits(size);
						IF tmp < 0 THEN hasMoreFrames := FALSE; RETURN FALSE END;
						dcDiff := -(SYSTEM.VAL(INTEGER, ((-SYSTEM.VAL(SET, tmp)) * {0..(size-1)})));
					ELSE
						(* positive difference *)
						dcDiff := stream.GetBits(size);
						IF dcDiff < 0 THEN hasMoreFrames := FALSE; RETURN FALSE END;
					END;
				END;

				coeffs[0] := dcDiff;
				cur := 1;
			ELSE
				(* read first DCT coefficient *)
				IF stream.ShowBits(1) = 1 THEN
					IF stream.ShowBits(2) = 2 THEN
						coeffs[0] := 1;
					ELSE
						coeffs[0] := -1;
					END;
					stream.SkipBits(2);
					INC(cur);
				ELSE
					dummy := reader.ReadRunLevelCode(coeffs, cur, MPEG2);		(* cannot return FALSE! *)
					IF reader.eof THEN hasMoreFrames := FALSE; RETURN FALSE END;
				END;
			END;

			(* MPEG-1 always uses first table. MPEG-2 chooses using the intraVlcFormat flag (for intra blocks only) *)
			IF (~MPEG2) OR (~picExt.intraVlcFormat OR ~intra) THEN
				WHILE ~reader.ReadRunLevelCode(coeffs, cur, MPEG2) DO END;
			ELSE
				WHILE ~reader.ReadRunLevelCode2(coeffs, cur) DO END;
			END;

			IF reader.eof THEN hasMoreFrames := FALSE; RETURN FALSE END;

			intraSkipped := (mbAddress - mbAddressLastIntra) > 1;

			(* dequantize the coefficients *)
			IF intra THEN
				CASE nr OF
					0..3:
						(* Y block *)
						IF ~dequantizer.DequantizeIntraCoeffs(coeffs, intraQM, qScale, dcY, first, intraSkipped) THEN RETURN FALSE END;
				|	4:
						(* Cb block *)
						IF ~dequantizer.DequantizeIntraCoeffs(coeffs, intraQM, qScale, dcCb, first, intraSkipped) THEN RETURN FALSE END;
				|	5:
						(* Cr block *)
						IF ~dequantizer.DequantizeIntraCoeffs(coeffs, intraQM, qScale, dcCr, first, intraSkipped) THEN RETURN FALSE END;
				END;
			ELSE
				IF ~dequantizer.DequantizeNonintraCoeffs(coeffs, nonintraQM, qScale) THEN RETURN FALSE END;
			END;


			idct.PerformIDCT(coeffs);

			IF macroblockNr = -1 THEN KernelLog.String("Block decoded"); KernelLog.Ln; END;
			RETURN TRUE;
		END DecodeBlock;

		PROCEDURE DecodeBlock2(
			nr: SHORTINT;
			coeffs:Util.PointerToArrayOfLONGINT;
			intra: BOOLEAN;
			VAR qScale: LONGINT;
			first: BOOLEAN;
			type: LONGINT): BOOLEAN;
		VAR
			bits: LONGINT;					(* temp variable for reading some bits off the stream *)
			size: LONGINT;					(* amount of bits in the stream for dcDiff *)
			dcDiff: LONGINT;				(* DC difference decoded from stream *)
			dcPrediction: LONGINT;			(* DC prediction *)
			coeffsPos: LONGINT;				(* current position in the coeffs array *)
			dummy: BOOLEAN;				(* dummy variable *)

		BEGIN
			blocks.ClearBlockLongint(coeffs);

			IF intra THEN
				(* special treatment of the first coefficient -> DC *)
				bits := stream.ShowBits(3);
				IF nr < 4 THEN
					(* intra coded Y block -> DCL table *)
					IF bits = 7 THEN
						stream.SkipBits(3);
						size := 4;
						WHILE stream.ShowBits(1) = 1 DO
							INC(size);
							stream.SkipBits(1);
						END;
						INC(size);
						stream.SkipBits(1);
					ELSE
						size := MPEGTables.DCL3[bits][0];
						stream.SkipBits(MPEGTables.DCL3[bits][1]);
					END;
				ELSE
					(* intra coded Cb or Cr block -> DCC table*)
					IF bits = 7 THEN
						stream.SkipBits(3);
						size := 3;
						WHILE stream.ShowBits(1) = 1 DO
							INC(size);
							stream.SkipBits(1);
						END;
						INC(size);
						stream.SkipBits(1);
					ELSE
						size := MPEGTables.DCC3[bits][0];
						stream.SkipBits(MPEGTables.DCC3[bits][1]);
					END;
				END;

				IF size = 0 THEN
					dcDiff := 0;
				ELSE
					IF stream.ShowBits(1) = 0 THEN
						(* negative difference: invert all bits and make number negative *)
						bits := stream.GetBits(size);
						IF bits < 0 THEN hasMoreFrames := FALSE; RETURN FALSE END;
						dcDiff := -(SYSTEM.VAL(INTEGER, ((-SYSTEM.VAL(SET, bits)) * {0..(size-1)})));
					ELSE
						(* positive difference *)
						dcDiff := stream.GetBits(size);
						IF dcDiff < 0 THEN hasMoreFrames := FALSE; RETURN FALSE END;
					END;
				END;

				(* set up DC prediction *)
				IF (mbSkipped OR ((mbAddress - mbAddressLastIntra) > 1)) & first THEN
					(* reset prediction *)
					(* besser auf macroblock ebene? *)
					CASE nr OF
						0..3:
							dcY := MPEGTables.DCP[picExt.dcPrecision];
					|	4:
							dcCb := MPEGTables.DCP[picExt.dcPrecision];
					|	5:
							dcCr := MPEGTables.DCP[picExt.dcPrecision];
					END;
				END;

				CASE nr OF
					0..3:
						(* Y block *)
						dcPrediction := dcY;
				|	4:
						(* Cb block *)
						dcPrediction := dcCb;

				|	5:
						(* Cr block *)
						dcPrediction := dcCr;
				END;

				coeffs[0] := dcPrediction + dcDiff;

				CASE nr OF
					0..3:
						dcY := coeffs[0];
				|	4:
						dcCb := coeffs[0];
				|	5:
						dcCr := coeffs[0];
				END;

				coeffsPos := 1;
			ELSE
				(* read first DCT coefficient, no special treatment *)
				IF stream.ShowBits(1) = 1 THEN
					IF stream.ShowBits(2) = 2 THEN
						coeffs[0] := 1;
					ELSE
						coeffs[0] := -1;
					END;
					stream.SkipBits(2);
					coeffsPos := 1;
				ELSE
					dummy := reader.ReadRunLevelCode(coeffs, coeffsPos, MPEG2);		(* cannot return FALSE! *)
					IF reader.eof THEN hasMoreFrames := FALSE; RETURN FALSE END;
				END;
			END;

			(* read the remaining coefficients *)
			IF ~picExt.intraVlcFormat OR ~intra THEN
				WHILE ~reader.ReadRunLevelCode(coeffs, coeffsPos, MPEG2) DO END;
			ELSE
				WHILE ~reader.ReadRunLevelCode2(coeffs, coeffsPos) DO END;
			END;

			IF reader.eof THEN hasMoreFrames := FALSE; RETURN FALSE END;

			IF picExt.alternateScan THEN
				(* interlaced movie: not supported yet *)
				HALT(1234);
			END;

			(* do the dequantisation *)
			IF intra THEN
				dequantizer.DequantizeIntraCoeffs2(coeffs, intraQM, qScale, picExt.dcPrecision);
			ELSE
				dequantizer.DequantizeNonintraCoeffs2(coeffs, nonintraQM, qScale);
			END;

			(* perform iDCT *)
			idct.PerformIDCT(coeffs);

			RETURN TRUE;
		END DecodeBlock2;


		(* Render the current picture to img *)
		PROCEDURE Render*(img : Raster.Image);
		BEGIN
			yuv2rgb.Convert(
				nextFrameToRender.buffer, 0, videoWidth, videoWidth * videoHeight,
				videoWidth * videoHeight + videoWidthDiv2 * videoHeightDiv2, videoWidthDiv2, img, videoWidth, videoHeight,
				videoWidth);
		END Render;

	END MPEGVideoDecoder;

	MPEGDemultiplexer* = OBJECT(Codec.AVDemultiplexer);
	VAR
		input: Streams.Reader;
		bytesRead: LONGINT;
		streams: ARRAY 64 OF POINTER TO StreamType;
		nextStreamNr: LONGINT;
		singleStream: BOOLEAN;	(* TRUE if there is just one unpacked (video) stream -> no need  to demux *)

		PROCEDURE &Init*;
		BEGIN
			nextStreamNr := 0;
		END Init;

		(** open the demultiplexer on an input stream *)
		PROCEDURE Open*(in : Streams.Reader; VAR res : WORD);
		VAR
			oldPos, i: LONGINT;
			startCode: CHAR;

		BEGIN
			input := in;
			res := Codec.ResFailed;

			(* only seekable streams are supported *)
			IF ~in.CanSetPos() THEN RETURN END;

			IF ~GotoNextStartCode() THEN RETURN END;
			startCode := input.Get();

			IF startCode = SCSequenceHeader THEN
				singleStream := TRUE;
				NEW(streams[0]);
				NEW(streams[0].stream, SELF, 0);
				streams[0].idByte := startCode;
				streams[0].pos := 0;
				streams[0].bytesLeftInPacket := -1;		(* one stream -> no packets -> no bytes to read *)
				streams[0].eos := FALSE;
				nextStreamNr := -1;		(* nextStreamNr should not be accessed - it's the only stream! *)
				input.SetPos(0);			(* reset because we already read a startcode *)
				res := Codec.ResOk;
				RETURN;
			ELSIF startCode # SCPack THEN
				RETURN;
			END;

			(* startCode = SCPack *)
			IF ~ReadPackHeader() THEN RETURN END;

			IF ~GotoNextStartCode() OR (input.Get() # SCSystemHeader) THEN RETURN END;
			IF ~ReadSystemHeader() THEN RETURN END;

			(* search for some more streams *)
			oldPos := input.Pos();
			FOR i := 0 TO 20 DO
				(* read chunk header *)
				IF ~GotoNextStartCode() THEN HALT(1234) END;
				startCode := input.Get();
				IF startCode = SCSystemHeader THEN
					IF ~ReadSystemHeader() THEN HALT(1234) END;
				ELSIF startCode = SCPack THEN
					IF ~ReadPackHeader() THEN HALT(1234) END;
				ELSIF ((ORD(startCode) >= 0BCH) & (ORD(startCode) <= 0FFH)) THEN
					input.SkipBytes(ORD(input.Get()) * 100H + ORD(input.Get()));
				ELSE
					(* we're lost... *)
					HALT(1234);
				END;
			END;
			input.SetPos(oldPos);
			res := Codec.ResOk;
		END Open;

		PROCEDURE GotoNextStartCode(): BOOLEAN;
		BEGIN
			IF SkipZeros() < 2 THEN RETURN FALSE END;
			RETURN input.Get() = CHR(1);
		END GotoNextStartCode;

		PROCEDURE SkipZeros(): LONGINT;
		VAR
			count: LONGINT;

		BEGIN
			WHILE (input.Peek() = CHR(0)) & ~(input.res = Streams.EOF)  DO
				input.SkipBytes(1);
				INC(count);
			END;
			IF input.res = Streams.EOF THEN
				RETURN -1;
			ELSE
				RETURN count;
			END;
		END SkipZeros;


		(* Reads a pack header *)
		PROCEDURE ReadPackHeader(): BOOLEAN;
		VAR
			peek: LONGINT;
			stuffBytes: LONGINT;
			buffer: ARRAY 8 OF CHAR;

		BEGIN
			peek := ORD(input.Peek());

			IF (peek >= 32) & (peek < 48) THEN
				(* 0010 xxxx -> MPEG-1 System *)
				input.Bytes(buffer, 0, 8, bytesRead);
				IF (input.res # Streams.Ok) OR (bytesRead < 8) THEN RETURN FALSE END;

				(* we don't care about SCR and MuxRate, so we ignore the rest *)
				RETURN TRUE;
			ELSIF (peek >= 64) & (peek < 128) THEN
				(* 01xx xxxx -> MPEG-2 System *)
				input.SkipBytes(9);
				stuffBytes := ORD(input.Get()) MOD 8;
				input.SkipBytes(stuffBytes);
				RETURN (input.res = Streams.Ok);
			ELSE
				(* unknown system *)
				RETURN FALSE;
			END;
		END ReadPackHeader;

		(* Reads a system header *)
		PROCEDURE ReadSystemHeader(): BOOLEAN;
		VAR
			headerLength: LONGINT;
			buffer: ARRAY 8 OF CHAR;

		BEGIN
			input.Bytes(buffer, 0, 8, bytesRead);
			IF (input.res # Streams.Ok) OR (bytesRead < 8) THEN RETURN FALSE END;

			headerLength := ORD(buffer[0]) * 256 + ORD(buffer[1]) - 6;

			(* we don't care about rateBound, audioBound, CSPS-, AudioLock- and VideoLock-Flags and videoBound *)

			(* read stream infos *)
			WHILE ORD(input.Peek()) > 127 DO
				input.Bytes(buffer, 0, 3, bytesRead);
				IF (input.res # Streams.Ok) OR (bytesRead < 3) THEN RETURN FALSE END;
				IF isNewStream(buffer[0]) THEN
					(* we found infos about a new stream *)
					NEW(streams[nextStreamNr]);
					NEW(streams[nextStreamNr].stream, SELF, nextStreamNr);
					streams[nextStreamNr].idByte := buffer[0];
					streams[nextStreamNr].pos := -1;
					streams[nextStreamNr].eos := FALSE;
					INC(nextStreamNr);
				END;
			END;

			RETURN TRUE;
		END ReadSystemHeader;

		PROCEDURE isNewStream(id: CHAR): BOOLEAN;
		VAR
			i: LONGINT;

		BEGIN
			FOR i := 0 TO (nextStreamNr-1) DO
				IF streams[i].idByte = id THEN RETURN FALSE END;
			END;
			RETURN TRUE;
		END isNewStream;


		PROCEDURE GetNumberOfStreams*() : LONGINT;
		BEGIN
			IF singleStream THEN
				RETURN 1;
			ELSE
				RETURN nextStreamNr;
			END;
		END GetNumberOfStreams;

		PROCEDURE GetStreamType*(streamNr : LONGINT): LONGINT;
		VAR
			streamid: LONGINT;

		BEGIN
			IF streams[streamNr] # NIL THEN
				streamid := ORD(streams[streamNr].idByte);
				CASE streamid OF
					0BCH..0BFH:
						(* reserved stream, private stream, padding stream, private stream 2 *)
						RETURN Codec.STUnknown;

				|	0C0H..0DFH:
						(* audio stream 0..31 *)
						RETURN Codec.STAudio;

				|	0E0H..0EFH:
						(* video stream 0..15 *)
						RETURN Codec.STVideo;

				|	0F0H..0FFH:
						(* reserved streams *)
						KernelLog.String("Stream-ID: "); KernelLog.Hex(streamid, 0); KernelLog.Ln;
						RETURN Codec.STUnknown;
				ELSE
					KernelLog.String("Stream-ID: "); KernelLog.Hex(streamid, 0); KernelLog.Ln;
					RETURN Codec.STUnknown;
				END;
			ELSE
				(* no such stream... *)
				RETURN Codec.STError;
			END;
		END GetStreamType;

		PROCEDURE GetStream*(streamNr: LONGINT): Codec.DemuxStream;
		BEGIN
			IF streams[streamNr] # NIL THEN
				RETURN streams[streamNr].stream;
			ELSE
				RETURN NIL;
			END;
		END GetStream;

		PROCEDURE GetStreamInfo*(streamNr : LONGINT): Codec.AVStreamInfo;
		VAR si : Codec.AVStreamInfo;
		BEGIN
			CASE GetStreamType(streamNr) OF
				Codec.STAudio:		COPY("MPEGAUDIO", si.contentType);
			|	Codec.STVideo:		COPY("MPEG", si.contentType);
			|	Codec.STUnknown:	COPY("UNKNOWN", si.contentType);
			ELSE					COPY("UNKNOWN", si.contentType);
			END;
			RETURN si
		END GetStreamInfo;

		(* read data from streamNr, store it into buffer buf starting at offset ofs, store size bytes if possible, block if not read min bytes at least. Return number of read bytes in len and return code res *)
		PROCEDURE GetData*(streamNr : LONGINT; VAR buf: ARRAY OF CHAR; ofs, size, min: LONGINT; VAR len, res: LONGINT);
		VAR
			cur: POINTER TO StreamType;
			length: LONGINT;
			offset: LONGINT;

		BEGIN
			IF singleStream THEN
				IF streams[0].eos = TRUE THEN
					(* what else should we do - even when min > 0 ?? *)
					RETURN;
				END;
				input.Bytes(buf, ofs, size, len);
				res := input.res;
				IF input.res = Streams.EOF THEN
					streams[0].eos := TRUE;
				END;
				INC(streams[0].pos, len);
				RETURN;
			END;

			cur := streams[streamNr];
			len := size;
			offset := ofs;

			IF cur.eos = TRUE THEN
				(* what else should we do - even when min > 0 ?? *)
				RETURN;
			END;

			IF cur.pos = -1 THEN
				(* search for the beginning of the stream *)
				input.SetPos(-1);
				IF ~GotoNextPacket(cur^) THEN res := Codec.ResFailed; RETURN END;
			END;

			input.SetPos(cur.pos);

			WHILE (cur.bytesLeftInPacket < size) & ~cur.eos DO
				(* copy bytes left from current packet *)
				input.Bytes(buf, offset, cur.bytesLeftInPacket, length);
				INC(cur.pos, length);

				DEC(size, cur.bytesLeftInPacket);
				INC(offset, cur.bytesLeftInPacket);

				(* jump to next packet of this stream *)
				IF ~GotoNextPacket(cur^) THEN
					(* end of stream ! *)
					cur.eos := TRUE;
					DEC(len, size);
					RETURN;
				END;
			END;

			res := Codec.ResOk;

			IF cur.eos THEN
				(* we couldn't get enough bytes... *)
				DEC(len, size);
			ELSE
				(* copy required bytes *)
				input.Bytes(buf, offset, size, length);
				cur.pos := input.Pos();
				DEC(cur.bytesLeftInPacket, length);
			END;
		END GetData;

		PROCEDURE SkipData(streamNr : LONGINT; size: LONGINT; VAR len, res: LONGINT);
		VAR
			cur: POINTER TO StreamType;

		BEGIN
			IF singleStream THEN
				input.SkipBytes(size);
				res := Codec.ResOk;		(* shouldn't we return input.res? *)
				INC(streams[0].pos, len);
				RETURN;
			END;

			cur := streams[streamNr];
			len := size;

			IF cur.pos = -1 THEN
				(* search for the beginning of the stream *)
				input.SetPos(cur.pos);
				IF ~GotoNextPacket(cur^) THEN res := Codec.ResFailed; RETURN END;
			END;

			input.SetPos(cur.pos);

			WHILE cur.bytesLeftInPacket < size DO
				(* skip bytes left in the current packet *)
				input.SkipBytes(cur.bytesLeftInPacket);

				INC(cur.pos, cur.bytesLeftInPacket);
				DEC(size, cur.bytesLeftInPacket);

				(* jump to next packet of this stream *)
				IF ~GotoNextPacket(cur^) THEN
					res := Codec.ResFailed;
					RETURN;
				END;
			END;

			(* skip required bytes *)
			input.SkipBytes(size);
			cur.pos := input.Pos();
			DEC(cur.bytesLeftInPacket, size);

		END SkipData;


		PROCEDURE GetPosInMuxedStream*(streamNr: LONGINT): LONGINT;
		BEGIN
			RETURN streams[streamNr].pos;
		END GetPosInMuxedStream;


		(* jump to the next packet of the stream with identifier id, starting at the current position of the input-stream *)
		(* assumption: position is at the beginning of a packet (or pack or system header) *)
		PROCEDURE GotoNextPacket(VAR stream: StreamType): BOOLEAN;
		VAR
			nextStartCode: CHAR;
			length: LONGINT;
			peekByte: CHAR;
			flags: LONGINT;
			optionsLength: LONGINT;

		BEGIN
			IF ~GotoNextStartCode() THEN RETURN FALSE END;
			nextStartCode := input.Get();

			WHILE (nextStartCode # stream.idByte) & (input.res # Streams.EOF)  DO
				IF nextStartCode = SCPack THEN
					IF ~ReadPackHeader() THEN RETURN FALSE END;
				ELSIF nextStartCode = SCSystemHeader THEN
					IF ~ReadSystemHeader() THEN RETURN FALSE END;
				ELSE
					(* read length field and skip the packet *)
					length := ORD(input.Get()) * 100H + ORD(input.Get());
					input.SkipBytes(length);
				END;

				(* read startcode of next chunk *)
				IF ~GotoNextStartCode() THEN RETURN FALSE END;
				nextStartCode := input.Get();
			END;

			IF input.res = Streams.EOF THEN
				RETURN FALSE;
			END;

			(* read packet header *)
			length := ORD(input.Get()) * 100H + ORD(input.Get());
			IF nextStartCode # SCPrivateStream2 THEN
				IF (ORD(input.Peek()) >= 128) & (ORD(input.Peek()) < 192) THEN
					(* MPEG-2 System *)
					input.SkipBytes(1);
					flags := ORD(input.Get());
					(* the simple way: skip all additional stuff *)
					optionsLength := ORD(input.Get());
					input.SkipBytes(optionsLength);
					DEC(length, optionsLength + 3);
				ELSE
					(* MPEG-1 System *)
					WHILE ORD(input.Peek()) = 0FFH DO
						(* skip padding *)
						input.SkipBytes(1);
						DEC(length);
					END;
					peekByte := input.Peek();
					IF (ORD(peekByte) > 63) & (ORD(peekByte) <128) THEN
						(* 01xx xxxx *)
						input.SkipBytes(2);
						DEC(length, 2);
						peekByte := input.Peek();
					END;
					IF (ORD(peekByte) > 31) & (ORD(peekByte) < 48) THEN
						(* 0010 xxxx *)
						input.SkipBytes(5);
						DEC(length, 5);
						peekByte := input.Peek();
					ELSIF (ORD(peekByte) > 47) & (ORD(peekByte) < 64) THEN
						(* 0011 xxxx *)
						input.SkipBytes(10);
						DEC(length, 10);
					ELSE
						(* skip 0000 1111 fixed pattern *)
						input.SkipBytes(1);
						DEC(length);
					END;
				END;
			END;

			(* finally we reached the next data bytes of the requested stream *)
			stream.pos := input.Pos() + 1;		(* next byte is first byte of the stream *)
			stream.bytesLeftInPacket := length;
			RETURN TRUE;
		END GotoNextPacket;


		(* seek the streamNr to position pos with seekType. itemSize contains the size of the element seeked to, if known and applicable; res = 0 if Ok, otherwise an error number *)
		PROCEDURE SetStreamPos*(streamNr :  LONGINT; seekType : LONGINT; pos : LONGINT; VAR itemSize : LONGINT;  VAR res : WORD);
		VAR
			cur: POINTER TO StreamType;
			len: LONGINT;
		BEGIN
			res := Codec.ResFailed;

			IF seekType # Codec.SeekByte THEN
				(* we can only seek for bytes here. seeking for frames can be done directly in the decoder *)
				RETURN;
			END;

			itemSize := 1;			(* does this make sense? one byte has always size one...*)

			IF singleStream THEN
				IF streamNr # 0 THEN RETURN END;
				input.SetPos(pos);
				streams[0].pos := pos;
				res := Codec.ResOk;
				RETURN;
			END;

			IF streamNr >= nextStreamNr THEN
				RETURN
			END;

			cur := streams[streamNr];

			IF (cur.stream.Pos()+cur.stream.Available()) > pos THEN
				(* reset stream and start searching at the beginning *)
				input.SetPos(-1);
				IF ~GotoNextPacket(cur^) THEN HALT(1234); res := Codec.ResFailed; RETURN END;

				(* skip some data *)
				SkipData(streamNr, pos, len, res);
			ELSE
				(* skip some data *)
				SkipData(streamNr, pos - (cur.stream.Pos()+cur.stream.Available()), len, res);
			END;
		END SetStreamPos;

		PROCEDURE HasMoreData(streamNr: LONGINT): BOOLEAN;
		BEGIN
			RETURN ~streams[streamNr].eos;
		END HasMoreData;


	END MPEGDemultiplexer;


	PROCEDURE GotoNextMarker(VAR stream: Util.BitStream; VAR marker: CHAR): BOOLEAN;
	VAR
		i: INTEGER;
		DEBUG: BOOLEAN;
	BEGIN
		DEBUG := FALSE;
		i := 0;
		stream.ByteAlign();

		(* skip stuffing zeros *)
		WHILE (stream.ShowBits(24) # 1) DO
			stream.SkipBits(8);
			INC(i);
		END;
		marker := CHR(stream.ShowBits(32) MOD 256);

		RETURN TRUE;
	END GotoNextMarker;

	PROCEDURE Sign(value: LONGINT): LONGINT;
	BEGIN
		IF value > 0 THEN
			RETURN 1;
		ELSIF value < 0 THEN
			RETURN -1;
		ELSE
			RETURN 0;
		END;
	END Sign;

	PROCEDURE DecoderFactory*() : Codec.VideoDecoder;
	VAR p: MPEGVideoDecoder;
	BEGIN
		NEW(p);
		RETURN p;
	END DecoderFactory;

	PROCEDURE DemuxFactory*() : Codec.AVDemultiplexer;
	VAR d: MPEGDemultiplexer;
	BEGIN
		NEW(d);
		RETURN d
	END DemuxFactory;

	PROCEDURE Test*(context : Commands.Context);
	VAR
		demux: MPEGDemultiplexer;
		decoder: MPEGVideoDecoder;
		file: Files.File;
		fileinputstream: Codec.FileInputStream;
		vstream: Codec.DemuxStream;
		result: LONGINT;
		i: LONGINT;

		w, h, ms: LONGINT;

		(* Player stuff *)
		wnd: PW;
		timer: Kernel.Timer;
		milliTimer : Kernel.MilliTimer;
		ticks: LONGINT;

		filename:ARRAY 100 OF CHAR;

		min, max, total: LONGINT;
		minFrame, maxFrame: LONGINT;

	BEGIN
		(* parse parameter: filename *)

		context.arg.SkipWhitespace; context.arg.String(filename);

		file := Files.Old(filename);
		IF file = NIL THEN
			context.error.String("Couldn't open File "); context.error.String(filename);
			context.error.Ln();
			RETURN;
		END;

		NEW(timer);
		NEW(fileinputstream, file, 0);

		NEW(demux);
		demux.Open(fileinputstream, result);

		IF result # Codec.ResOk THEN
			context.error.String("error opening the demultiplexer"); context.error.Ln;
		END;

		vstream := demux.GetStream(0);

		NEW(decoder);
		decoder.Open(vstream, result);

		IF result = Codec.ResOk THEN
			(* get information *)
			decoder.GetVideoInfo(w, h, ms);

			(* open the window *)
			NEW(wnd, w, h, FALSE);
			wnd.SetTitle(WM.NewString("Simple MPEG Player"));

			(* decode some frames ... *)

			(* decoder.SeekFrame(100, FALSE, result); *)
			(* decoder.SeekMillisecond(5000, FALSE, result); *)

			FOR i := 0 TO 50 DO
				Kernel.SetTimer(milliTimer, 0);
				decoder.Next();
				decoder.Render(wnd.backImg);
				wnd.Swap();
				wnd.Invalidate(Rectangles.MakeRect( 0, 0, wnd.backImg.width, wnd.backImg.height ) );
				ticks := Kernel.Elapsed(milliTimer);

(*				context.out.String("Time required: "); context.out.Int(ticks, 0); context.out.Ln; *)
				IF ticks < min THEN
					min := ticks;
					minFrame := i;
				ELSIF ticks > max THEN
					max := ticks;
					maxFrame := i;
				END;
				INC(total, ticks);
(*				timer.Sleep(100); *)
			END;

			context.out.String("Finished decoding "); context.out.Int(i, 0); context.out.String(" Frames (min/avg/max): ");
			context.out.Int(min, 0); context.out.String(" (Frame "); context.out.Int(minFrame, 0); context.out.String(") / ");
			context.out.Int(total DIV i, 0); context.out.String(" /"); context.out.Int(max, 0); context.out.String(" (Frame "); context.out.Int(maxFrame, 0);
			context.out.String(")"); context.out.Ln;
		END;
	END Test;

END MPEGVideoDecoder.


System.Free MPEGVideoDecoder ~
MPEGVideoDecoder.Test beauty.mpg~


(* end of file *)