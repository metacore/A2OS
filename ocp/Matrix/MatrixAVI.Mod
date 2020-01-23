MODULE MatrixAVI;		(*(c) Patrick Hunziker *)
IMPORT Out:=KernelLog, Files;
CONST
		NULL=0;
	(* AVI RIFFs *)			(*RIFF is little endian, like INTEL hardware, and the Oberon system; RIFX would be for big endian *)
		RIFF="AVI ";
		MainHeader="hdrl";
		StreamList="strl";
		StreamHeader="strh";
		StreamFormat="strf";
		StreamAdditionalHeader="strd";
		StreamName="strn";
		StreamData="movi";
		Index="idxl";
	(* MainHeader dwFlags *)	(* *)
		AVIFHASINDEX=4;
		AVIFMUSTUSEINDEX=5;
		AVIFISINTERLEAVED=8;
		AVIFTRUSTCKTYPE=11;
		AVIFWASCAPTUREFILE=16;
		AVIFCOPYRIGHTED=17;
	(* StreamHeader dwFlags*)
		AVISFDISABLED=0;
		AVISFVIDEOPALCHANGES=4;
	(* StreamTypes *)
		Audio="wb";
		UncompressedVideo="db";
		CompressedVideo="dc";
		RLE8*=1;
		NOcompress*=0;

		(*LUT*)
		gray*=0;
		flow*=1;

		(*normalization (intensity scaling min->max) *)
		none*=0;
		frame*=1;
		loop*=2;

TYPE
	Datatype=FLOAT64;
	Matrix=ARRAY [*,*] OF Datatype;
	AVIMainHeader=RECORD
		dwMicroSecPerFrame,
		dwMaxBytesPerSec,
		dwReserved1:	SIGNED32;
		dwFlags:			SET;
		dwTotalFrames,
		dwInitialFrames,
		dwStreams,
		dwSuggestedBufferSize,
		dwWidth,
		dwHeight: 	SIGNED32;
		dwReserved: ARRAY 16 OF CHAR;
	END;

	AVIStreamHeader=RECORD
		fccType: 	ARRAY 4 OF CHAR;	(*'vids', 'auds', 'txts'*) (*take care: the system automatically appends a 0X char at the
																	end of string operations like COPY and so on;
																	rather use an array which is 1 Byte longer..*)
		fccHandler: ARRAY 4 OF CHAR;	(*for uncompressed video: 'DIB '; alternatively 'RGB ' or 'RAW ' are used for the same.. *)
																(* for compressed video, e.g. 'mrle' for 8bit RLE *)
		dwFlags:	SET;
		dwPriority,
		dwInitialFrames,
		dwScale,
		dwRate,
		dwStart,
		dwLength,
		dwSuggestedBufferSize,
		dwQuality,
		dwSampleSize:	SIGNED32;
		rcFrame: ARRAY 4 OF SIGNED16; (*  left, top, xDim, yDim; left-top is relative to left-top edge of container *)
	END;

	AVIStreamData=RECORD
		StreamID:ARRAY 2 OF CHAR;
		StreamType: ARRAY 2 OF CHAR;
	END;

	(*identical to BMP.BitmapHeader; compare to GDI32.HBitmap and User32.Hbitmap*)

	BITMAPINFOHEADER=RECORD	(* video stream info *)
		biSize,		(*40 Bytes*)
		biWidth,
		biHeight:SIGNED32;
		biPlanes,
		biBitCount: SIGNED16;
		biCompression,				(*0L for uncompressed RGB; 1 for RLE8; 2 for RLE4; 3 for Bitfields -see below - *)
		biSizeImage,					(*   tDim*zDim*yDim*xDim  *)
		biXPelsPerMeter,
		biYPelsPerMeter,
		biClrUsed,						(* IF uncompressed THEN 256 ELSE nr of colors used *)
		biClrImportant: SIGNED32;
	END;

	RGBQUAD=ARRAY 4 OF CHAR;

	BITMAPINFO=RECORD				(* palette info; only needed if biBitCount <=8 *)
		bmiHeader:BITMAPINFOHEADER;
		bmiColors: ARRAY 1 OF RGBQUAD;
	END;

	WAVEFORMATEX=RECORD		(* audio stream info *)
		wFormatTag,
		nChannels:	SIGNED16;
		nSamplesPerSec,
		nAvgBytesPerSec: SIGNED32;
		nBlockAlign,
		wBitsPerSample,
		cbSize:		SIGNED16;
	END;

VAR Comments*:BOOLEAN;

PROCEDURE writeByteFrame();
END writeByteFrame;

PROCEDURE writeRGBFrame();
END writeRGBFrame;

PROCEDURE WriteLUT(VAR R: Files.Writer; lut:SIGNED16);
VAR i,j:SIGNED16;
BEGIN
	CASE lut OF
	gray:
		FOR j:=0 TO 256-1 DO
			R.Char(CHR(j));
			R.Char(CHR(j));
			R.Char(CHR(j));
			R.Char(CHR(0));
		END;
	| flow:
		FOR i:=0 TO 127 DO
			R.Char( CHR(2*(127-i)));
			R.Char( CHR(0));
			R.Char( CHR(0));
			R.Char( CHR(0));
		END;
		FOR i:=0 TO 127 DO
			R.Char( CHR(0));
			R.Char( CHR(0));
			R.Char( CHR(2*i));
			R.Char( CHR(0));
		END;
	END;
END WriteLUT;

PROCEDURE minmax(CONST A:ARRAY [*] OF Matrix; VAR min,max:Datatype);
VAR i:SIZE;
BEGIN
	max:=MIN(Datatype); min:=MAX(Datatype);
	FOR i:=0 TO LEN(A,0)-1 DO
		max:=MAX(max, MAX(A[i]));
		min:=MIN(min, MIN(A[i]));
	END;
END minmax;

PROCEDURE WriteFOURCC(VAR R:Files.Writer; FOURCC:ARRAY OF CHAR);
BEGIN	(*use an input array of >5 Bytes to avoid the automatically appended 0X character in strings  ?? *)
	R.Bytes(FOURCC,0,4)
END WriteFOURCC;

PROCEDURE WritePixelsUncompressed(VAR R:Files.Writer; CONST P:Matrix; NrBytes:SIGNED16; gain:Datatype; offset:SIGNED32);
VAR line:POINTER TO ARRAY OF SIGNED16; x,y:SIZE; Red,Green,Blue:SIGNED16;
BEGIN
	FOR y:=0 TO LEN(P,0)-1 DO
		IF NrBytes=1 THEN
			FOR x:=0 TO (LEN(P,1)+3) DIV 4*4-1 DO 		(* padding to a multiple of 4 Bytes *)
				R.Char(CHR(SHORT(offset+ENTIER(P[y,x]*gain))));
			END;
		ELSE
			Out.String("Bit depth not currently supported :"); Out.Int(NrBytes,4); Out.Ln;
		END;
	END;
END WritePixelsUncompressed;


PROCEDURE WriteRLE8(VAR R:Files.Writer; CONST P:Matrix; NrBytes:SIGNED16; gain:Datatype; offset:SIGNED32); (** NrBytes=NrBytesPerPixel. Multiple frames not yet implemented *)
VAR pixIndex,encodeIndex,i,zDimSlices,index:SIZE; x,y,xDim,yDim,count:SIZE;
	pixStore,encodeStore,line: POINTER TO ARRAY OF SIGNED16;
BEGIN
	IF NrBytes>1 THEN Out.String("Bitdepth not currently supported :"); Out.Int(NrBytes,4); Out.Ln; RETURN END;
	pixIndex:=0;
	xDim:= (LEN(P,1)+3) DIV 4*4; (* padding to multiple of 4 *)
	yDim:=LEN(P,0);
	NEW(pixStore,xDim*yDim);
	NEW(encodeStore,2*xDim*yDim + xDim); (*maximum 'compressed' length; shows problem of this RLE algorithm... *)
	NEW(line,LEN(P,1));
	FOR y:=0 TO yDim-1  DO
		(*Pictures.GetLine(P,line^,0,SHORT(y),P.width);*)
		FOR x:=0 TO LEN(P,1)-1 DO pixStore[pixIndex]:= SHORT(offset+ENTIER(P[y,x]*gain)); INC(pixIndex); END;
		FOR x:=LEN(P,1) TO xDim-1 DO pixStore[pixIndex]:=0; INC(pixIndex); END;
	END;
	encodeIndex:=0;
	count:=0;
	FOR y:=0 TO yDim-1 DO
		FOR x:=0 TO xDim-1 DO
			index:=x+y*xDim;
			IF x=0 THEN count:=1
			ELSIF (count>0) & (pixStore[index]=pixStore[index-1]) THEN
				INC(count);
				IF x=xDim-1 THEN
					encodeStore[encodeIndex]:= SIGNED16(count); INC(encodeIndex);
					encodeStore[encodeIndex]:=pixStore[index]; INC(encodeIndex);
					IF y<yDim-1 THEN	(* end of line *)
						encodeStore[encodeIndex]:= 0; INC(encodeIndex);
						encodeStore[encodeIndex]:= 0; INC(encodeIndex);
					ELSE						(* end of bitmap *)
						encodeStore[encodeIndex]:= 0; INC(encodeIndex);
						encodeStore[encodeIndex]:= 1; INC(encodeIndex);
					END;
				ELSIF count=255 THEN
					encodeStore[encodeIndex]:= 255; INC(encodeIndex);
					encodeStore[encodeIndex]:=pixStore[index]; INC(encodeIndex);
					count:=0;
				END;
			ELSIF (count>0) & (pixStore[index]#pixStore[index-1]) THEN
				encodeStore[encodeIndex]:= SIGNED16(count); INC(encodeIndex);
				encodeStore[encodeIndex]:=pixStore[index-1]; INC(encodeIndex);
				count:=1;
				IF x=xDim-1 THEN
					encodeStore[encodeIndex]:= 1; INC(encodeIndex);
					encodeStore[encodeIndex]:=pixStore[index]; INC(encodeIndex);
					count:=1;
					IF y<yDim-1 THEN	(* end of line *)
						encodeStore[encodeIndex]:= 0; INC(encodeIndex);
						encodeStore[encodeIndex]:= 0; INC(encodeIndex);
					ELSE						(* end of bitmap *)
						encodeStore[encodeIndex]:= 0; INC(encodeIndex);
						encodeStore[encodeIndex]:= 1; INC(encodeIndex);
					END;
				END;
			ELSIF count=0 THEN
				count:=1;
				IF x=xDim-1 THEN
					encodeStore[encodeIndex]:= 1; INC(encodeIndex);
					encodeStore[encodeIndex]:=pixStore[index]; INC(encodeIndex);
					IF y<yDim-1 THEN	(* end of line *)
						encodeStore[encodeIndex]:= 0; INC(encodeIndex);
						encodeStore[encodeIndex]:= 0; INC(encodeIndex);
					ELSE						(* end of bitmap *)
						encodeStore[encodeIndex]:= 0; INC(encodeIndex);
						encodeStore[encodeIndex]:= 1; INC(encodeIndex);
					END;
				END;
			END;
		END;
	END;
	R.RawLInt(encodeIndex(SIGNED32));
	FOR i :=0 TO encodeIndex-1  DO R.Char(CHR(encodeStore[i])) END;
END WriteRLE8;


PROCEDURE Store*(CONST data:ARRAY [*] OF Matrix; filename:ARRAY OF CHAR):Files.File;
BEGIN
	RETURN StoreB(data,filename,7,RLE8, gray, loop);
END Store;

(** Store files as .avi ; for first try, see Store() ;  *)
PROCEDURE StoreB*(CONST data:ARRAY [*] OF Matrix; filename:ARRAY OF CHAR; framesPerSec:FLOAT32; compression, lut, normalize:SIGNED16):Files.File;
VAR R,Counter:Files.Writer;
		F:Files.File;
		saveFileSize,saveLIST1Size,saveList1subSize,savestrfSize,savestrnPos,saveJUNKsignature,saveLIST2Size,
		idx1Pos,endPos,saveidx1Length,savemovi:Files.Position;
		savedbLength,savedcLength:POINTER TO ARRAY OF Files.Position;
		dcLength:POINTER TO ARRAY OF Files.Position;
		i,x,y,z,xDim,yDim,zDim,tDim, paddingbytes:SIZE;
		avistreamheader:AVIStreamHeader;
		bitmapinfoheader:BITMAPINFOHEADER;
		avimainheader:AVIMainHeader;
		datasignature,FOURCC:ARRAY 5 OF CHAR;
		string16:ARRAY 16 OF CHAR;
		bytesperpixel:SIGNED16;
		(*compression:SIGNED16;*)
		max,min, absmax:Datatype;

	PROCEDURE WriteAVIMainHeader;
	BEGIN
		R.RawLInt(ENTIER(1000000/framesPerSec) (*avimainheader.dwMicroSecPerFrame*));
		R.RawLInt(500000 (*avimainheader.dwMaxBytesPerSec*));
		R.RawLInt(avimainheader.dwReserved1);
		avimainheader.dwFlags:={4}; R.RawSet(avimainheader.dwFlags);
		avimainheader.dwTotalFrames:=LEN(data,0)(SIGNED32);
		R.RawLInt(avimainheader.dwTotalFrames);
		R.RawLInt(avimainheader.dwInitialFrames);
		R.RawLInt(1(*avimainheader.dwStreams*));
		R.RawLInt(4000000 (*avimainheader.dwSuggestedBufferSize*));
		avimainheader.dwWidth:=xDim(SIGNED32);
		avimainheader.dwHeight:=yDim(SIGNED32);
		R.RawLInt(avimainheader.dwWidth);
		R.RawLInt(avimainheader.dwHeight);
		R.Bytes(avimainheader.dwReserved,0,16);
	END WriteAVIMainHeader;

	PROCEDURE WriteAVIStreamHeader;
	VAR vids,DIB:ARRAY 5 OF CHAR;
	BEGIN
		COPY("vids",vids);
		IF compression=0 THEN COPY("DIB ",DIB)
		ELSIF compression=1 THEN COPY("mrle",DIB)
		ELSE HALT(99);
		END;
		R.Bytes(vids (*avistreamheader.fccType*),0,4);
		R.Bytes(DIB (*avistreamheader.fccHandler*),0,4);
		R.RawSet(avistreamheader.dwFlags);
		R.RawLInt(avistreamheader.dwPriority);
		R.RawLInt(avistreamheader.dwInitialFrames);
		R.RawLInt( 1 (*avimainheader.dwMicroSecPerFrame DIV 10000*) (*avistreamheader.dwScale*));
		R.RawLInt(ENTIER(framesPerSec) (*avistreamheader.dwRate*));
		R.RawLInt(avistreamheader.dwStart);
		avistreamheader.dwLength:=LEN(data,0)(SIGNED32);
		R.RawLInt(avistreamheader.dwLength);
		R.RawLInt(4000000(*avistreamheader.dwSuggestedBufferSize*));
		R.RawLInt(10000 (*avistreamheader.dwQuality; (*-1=default quality*)*));
		IF compression=0 THEN
			avistreamheader.dwSampleSize:=(bytesperpixel*xDim*yDim)(SIGNED32);
		ELSE (*compression *) avistreamheader.dwSampleSize:=(xDim*yDim)(SIGNED32); (*HALT(99);*)
		END;
		R.RawLInt(avistreamheader.dwSampleSize);
		avistreamheader.rcFrame[0]:=0; R.RawInt(0);
		avistreamheader.rcFrame[1]:=0; R.RawInt(0);
		avistreamheader.rcFrame[2]:=SIGNED16(xDim); R.RawInt(SIGNED16(xDim));
		avistreamheader.rcFrame[3]:=SIGNED16(yDim); R.RawInt(SIGNED16(yDim));
	END WriteAVIStreamHeader;

	PROCEDURE WriteBitmapInfoHeader;
	BEGIN
		R.RawLInt(40 (*bitmapinfoheader.biSize*));
		R.RawLInt(xDim(SIGNED32) (*bitmapinfoheader.biWidth*));
		R.RawLInt(yDim(SIGNED32) (*bitmapinfoheader.biHeight*));
		R.RawInt(1 (*bitmapinfoheader.biPlanes*));
		IF compression=0 THEN R.RawInt( 8*bytesperpixel (*IF NO COMPRESSION*) (*bitmapinfoheader.biBitCount*))
		ELSIF compression=1 THEN R.RawInt(8)
		END;
		R.RawLInt( compression (*bitmapinfoheader.biCompression*));	(*0 for uncompressed RGB; 1 for RLE8; 2 for RLE4; 3 for Bitfields -see below - *)
		IF compression=0 THEN R.RawLInt( (bytesperpixel*tDim*zDim*yDim*xDim)(SIGNED32) (*bitmapinfoheader.biSizeImage*))
		ELSIF compression=1 THEN R.RawLInt((tDim*zDim*yDim*xDim)(SIGNED32))	(* may be 0 for uncompressed RGB *)
		END;
		R.RawLInt( 2000 (*bitmapinfoheader.biXPelsPerMeter*));
		R.RawLInt( 2000 (*bitmapinfoheader.biYPelsPerMeter*));
		IF compression=0 THEN R.RawLInt( 256 (*bitmapinfoheader.biClrUsed*))
		ELSIF compression=1 THEN R.RawLInt(256)											(*INCOMPLETE IMPLEMENTATION*)
		END;
		R.RawLInt( bitmapinfoheader.biClrImportant);			(* 0: all are important *)
	END WriteBitmapInfoHeader;

	PROCEDURE WriteBitmapInfo;
	BEGIN
	END WriteBitmapInfo;

BEGIN
	zDim:=LEN(data,0);
	xDim:=LEN(data[0],1) +3 DIV 4*4; (*padding*)
	yDim:=LEN(data[0],0);
	minmax(data,min,max);
	absmax:=MAX(ABS(min),ABS(max));
	tDim:=1;
	bytesperpixel:=1;
	compression:=1;			(*0 for uncompressed RGB; 1 for RLE8; 2 for RLE4; 3 for Bitfields .. *)
	(*IF compression>= 1 THEN Out.String("unimplemented compression"); Out.Ln; HALT(99); END;*)
	NEW(savedbLength,tDim*zDim); (*"long" SIGNED32 ARRAY FOR uncompressed image data*)
	NEW(savedcLength,tDim*zDim); (*"long" SIGNED32 ARRAY FOR uncompressed image data*)
	NEW(dcLength,tDim*zDim); (*"int" SIGNED32 ARRAY for uncompressed image data*)

	F:=Files.New(filename);
	NEW(R,F,0);
	NEW(Counter,F,0);
	WriteFOURCC(R,"RIFF"); (*WriteRIFFHeader*)
			saveFileSize:=R.Pos();
			R.RawLInt(NULL); (* to be updated with FileSizeFromNextPos *)
			WriteFOURCC(R,"AVI ");
				WriteFOURCC(R,"LIST");(*WritehdrlLIST*)
				saveLIST1Size:=R.Pos();
				R.RawLInt(NULL);		(* to be updated with hdrl ChunkSizeFromNextPos *)
				WriteFOURCC(R,"hdrl");(*Write Chunks*)
						WriteFOURCC(R,"avih"); (*Write subchunks*)
						R.RawLInt( 56);	(*this is the avih subchunk length from next position on*)
						WriteAVIMainHeader;
						WriteFOURCC(R,"LIST");
						saveList1subSize:=R.Pos();
						R.RawLInt(NULL);		(* to be updated with strl ChunkSizeFromNextPos *)
						WriteFOURCC(R,"strl");	(*stream line header *)
									WriteFOURCC(R,"strh");(*Write subchunks*)
									R.RawLInt(56); (* the length of the strh sub-chunk *)
									WriteAVIStreamHeader;
									WriteFOURCC(R,"strf");	(*stream format chunk*)
									savestrfSize:=R.Pos();
									R.RawLInt(NULL);		(* to be updated with strl ChunkSizeFromNextPos *)
									WriteBitmapInfoHeader;
									IF TRUE (*(compression=1) OR (bytesperpixel=1)*) THEN WriteLUT(R,lut);  END;
									savestrnPos:=R.Pos();
									R.Update;
									Counter.SetPos(savestrfSize); Counter.RawLInt((savestrnPos-savestrfSize-4)(SIGNED32));
									Counter.Update;
									WriteFOURCC(R,"strn");
									R.RawLInt(16); (* the length of the strn subchunk *)
									COPY("FileAvi write  ",string16);
									R.Bytes(string16,0,15); R.Char(0X); (*! TO DO - CHECK FOR CORRECT STRING LENGHT *)
									saveJUNKsignature := R.Pos();
									R.Update;
									Counter.SetPos(saveLIST1Size); Counter.RawLInt((saveJUNKsignature-saveLIST1Size-4)(SIGNED32));
									Counter.SetPos(saveList1subSize); Counter.RawLInt((saveJUNKsignature-saveList1subSize-4)(SIGNED32));
									Counter.Update;
						WriteFOURCC(R,"JUNK");
						paddingbytes:=(4084-saveJUNKsignature-8)(SIZE);
						R.RawLInt(paddingbytes(SIGNED32));
						FOR i:=0 TO paddingbytes DIV 2 -1 DO R.RawInt(0)END;
			WriteFOURCC(R,"LIST");
			saveLIST2Size:=R.Pos();
			R.RawLInt(NULL); (* to be updated with strl ChunkSizeFromNextPos *)
			savemovi:=R.Pos();
			WriteFOURCC(R,"movi");
			IF normalize=loop THEN
				minmax(data,min,max);
				absmax:=MAX(ABS(min),ABS(max));
			END;
			IF compression=0 THEN
				COPY("00db",datasignature);
				FOR z:=0 TO zDim-1 DO
					IF normalize=frame THEN
						minmax(data[z..z],min,max);
						absmax:=MAX(ABS(min),ABS(max));
					END;
					WriteFOURCC(R,datasignature);
					savedbLength[z]:=R.Pos();
					R.RawLInt((bytesperpixel*xDim*yDim)(SIGNED32));
					IF lut=gray THEN WritePixelsUncompressed(R,data[z],bytesperpixel, 254/absmax, 1);
					ELSIF lut=flow THEN WritePixelsUncompressed(R,data[z],bytesperpixel, 127/absmax, 128);
					END;
				END;
			ELSIF compression=1 THEN
				COPY("00dc",datasignature);
				FOR z:=0 TO zDim-1 DO
					IF normalize=frame THEN
						minmax(data[z..z],min,max);
						absmax:=MAX(ABS(min),ABS(max));
					END;
					WriteFOURCC(R,datasignature);
					savedcLength[z]:=R.Pos();
					(*R.RawLInt(0);  encoded length is inserted here within WriteRLE8() *)
					IF lut=gray THEN WriteRLE8(R,data[z],bytesperpixel,254/absmax, 1);
					ELSIF lut=flow THEN WriteRLE8(R,data[z],bytesperpixel,127/absmax, 128);
					ELSE HALT(199);
					END;
					dcLength[z]:=R.Pos()-savedcLength[z]-4;
					END;
			END;
			(*WriteIDXList *)
			idx1Pos:=R.Pos();
			R.Update;
			Counter.SetPos(saveLIST2Size); Counter.RawLInt((idx1Pos-saveLIST2Size-4)(SIGNED32));
			Counter.Update;
			WriteFOURCC(R,"idx1");
			saveidx1Length:=R.Pos();
			R.RawLInt(NULL);		(* to be updated with strl ChunkSizeFromNextPos *)
			FOR z:=0 TO zDim-1 DO
				WriteFOURCC(R,datasignature);
				IF z=0 THEN R.RawSet({4})
							(*WriteTheFlags,( not well understood flags)
														4 is AVIIFKeyFrame
														8 is AVIIFNoTime
														0 is AVIIFList (suggestest JUNK content)
														1 is AVIIFTwoCC
														0x0FFF0000L is AVIIFCompuse*)
				ELSE R.RawSet({});END;
				IF compression=0 THEN
					R.RawLInt((savedbLength[z]-savemovi-4)(SIGNED32));	(*WriteOffsetRelativeToMovi*)
					R.RawLInt((bytesperpixel*xDim*yDim)(SIGNED32));
				ELSIF compression=1 THEN
					R.RawLInt((savedcLength[z]-savemovi-4)(SIGNED32));
					R.RawLInt((dcLength[z])(SIGNED32));
				END;
			END;
			R.Update;
			endPos:=R.Pos();
			Counter.SetPos(saveFileSize); Counter.RawLInt((endPos-saveFileSize-4)(SIGNED32));
			Counter.SetPos(saveidx1Length); Counter.RawLInt((endPos-saveidx1Length-4)(SIGNED32));
			Counter.Update;
		Files.Register(F);
		RETURN(F);
	END StoreB;

PROCEDURE Test*;
VAR frames: ARRAY [*,*,*] OF Datatype; i:SIGNED32; F:Files.File;
BEGIN
	NEW(frames,30,100,100);
	frames[..14, 30..50,30..50]:=1;
	frames[15.., 50..80, 50..80]:=1;
	F:=Store(frames,"demoRLE.avi");
END Test;

BEGIN
	Comments:=FALSE;
END MatrixAVI.

System.Free MatrixAVI ~
MatrixAVI.Test
System.State AVI
