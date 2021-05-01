(**
	AUTHOR: Alexey Morozov
	PURPOSE: JPEG image encoding library
*)
MODULE JPEGEncoder;

IMPORT SYSTEM,  Streams, Codecs, Raster;

CONST
	QuantFracWidth* = 10; (** number of fractional bits for fixed point representation of quantization weights *)

	BlockAlignment* = 64; (** data block alignment in bytes (cache line size) *)

	QuantFactor = 8; (* factor used for computing quantization weights in fixed point format *)

TYPE

	(** JPEG output bitstream writer *)
	BitstreamWriter* = RECORD

		write: PROCEDURE{DELEGATE}(byte: CHAR);
		bufBits, numBufBits: UNSIGNED32;

		(** Initialize the writer with a single byte writing procedure *)
		PROCEDURE Init*(writeByte: PROCEDURE{DELEGATE}(byte: CHAR));
		BEGIN
			ASSERT(writeByte # NIL);
			write := writeByte;
			bufBits := 0; numBufBits := 0;
		END Init;

		(** Write multiple bits of data

			bits : input bitmap with up to 32 bits with least bit being the first one
			numBites : number of bits in the bitmap
		 *)
		PROCEDURE WriteBits*(bits, numBits: UNSIGNED32);
		BEGIN
			bufBits := LSH(bufBits, numBits) + bits;
			INC(numBufBits, numBits);

			(* write complete bytes *)
			WHILE numBufBits >= 8 DO
				DEC(numBufBits, 8);
				VAR x := LSH(bufBits,-numBufBits) MOD 100H;
				write(CHR(x));
				IF x = 0FFH THEN write(00X); END; (* replace 0xff by 0xff00 *)
			END;
		END WriteBits;

		(** Flush the remaining bits into the output stream (used at the end of image encoding)
		*)
		PROCEDURE Flush*();
		BEGIN
			(* write remaining buffered bits *)
			IF numBufBits # 0 THEN
				ASSERT(numBufBits < 8);
				WriteBits(0, 8 - numBufBits);
				ASSERT(numBufBits = 0);
			END;
		END Flush;
	END;

	(** JPEG channel (Y or U/Cb or V/Cr) encoder *)
	ChannelEncoder* = RECORD
		qTable: ARRAY 8 * 8 OF UNSIGNED8; (* quantization table *)

		huffDcCodes: ARRAY 17 OF UNSIGNED8;
		huffDcValues: ARRAY 12 OF UNSIGNED8;
		huffAcCodes: ARRAY 17 OF UNSIGNED8;
		huffAcValues: ARRAY 162 OF UNSIGNED8;

		huffDcTable: ARRAY 12 OF UNSIGNED32;
		huffAcTable: ARRAY 16 * 12 OF UNSIGNED32;

		qWeights{ALIGNED(BlockAlignment)}: ARRAY 8 * 8 OF INTEGER; (* quantization weight table *)

		blk{ALIGNED(BlockAlignment)}: ARRAY 8 * 8 OF INTEGER;

		dcPrev := 0: INTEGER; (* previous value of DC component *)

		acZerosBits, acZerosNumBits: UNSIGNED32;
		acEndOfBlockBits, acEndOfBlockNumBits: UNSIGNED32;

		PROCEDURE &Init*();
		BEGIN
			dcPrev := 0;
		END Init;

		(** Setup default quantization and Huffman coding configuration for Luma (Y) data *)
		PROCEDURE SetupDefaultsLuma*();
		BEGIN
			SetQuantization(DefaultQuantLuma);
			SetHuffman(DefaultHuffDcTableLuma, DefaultHuffAcTableLuma);

			huffDcCodes := DefaultDcNrCodesLuma;
			huffDcValues := DefaultDcValuesLuma;
			huffAcCodes := DefaultAcNrCodesLuma;
			huffAcValues := DefaultAcValuesLuma;
		END SetupDefaultsLuma;

		(** Setup default quantization and Huffman coding configuration for Chroma (U/Cb or V/Cr) data *)
		PROCEDURE SetupDefaultsChroma*();
		BEGIN
			SetQuantization(DefaultQuantChroma);
			SetHuffman(DefaultHuffDcTableChroma, DefaultHuffAcTableChroma);

			huffDcCodes := DefaultDcNrCodesChroma;
			huffDcValues := DefaultDcValuesChroma;
			huffAcCodes := DefaultAcNrCodesChroma;
			huffAcValues := DefaultAcValuesChroma;
		END SetupDefaultsChroma;

		(** Setup the quantization table *)
		PROCEDURE SetQuantization*(CONST quantizationTable: ARRAY 8 * 8 OF UNSIGNED8);
		CONST One = FLOAT32(LSH(INTEGER(1), QuantFracWidth));
		VAR i: SIZE;
		BEGIN
			qTable := quantizationTable;
			(* compute quantization weights used in QDTC *)
			FOR i := 0 TO LEN(qTable) - 1 DO
				qWeights[i] := INTEGER(0.5 + One /(INTEGER(qTable[i]) * QuantFactor * QuantFactors[i DIV 8] * QuantFactors[i MOD 8]));
			END;
		END SetQuantization;

		(** Setup Huffman encoding tables

			dcTable : DC encoding table
			acTable : AC encoding table
		*)
		PROCEDURE SetHuffman*(CONST dcTable: ARRAY 12 OF UNSIGNED32; CONST acTable: ARRAY 16 * 12 OF UNSIGNED32);
		BEGIN
			huffDcTable := dcTable;
			huffAcTable := acTable;

			acZerosBits := LSH(huffAcTable[15*12],-16);
			acZerosNumBits := huffAcTable[15*12] MOD 100H;

			acEndOfBlockBits := LSH(huffAcTable[0],-16);
			acEndOfBlockNumBits := huffAcTable[0] MOD 100H;
		END SetHuffman;

		(** Encode a single 8x8 image data block *)
		PROCEDURE Encode*(VAR out: BitstreamWriter; CONST x: ARRAY 8 * 8 OF UNSIGNED8);
		BEGIN
			(* Transform data *)
			QuantizedDct8x8(x, qWeights, blk);

			(* Huffman encoding *)
			HuffmanEncode(out, blk);
		END Encode;

		(* Huffman encoding of a DCT-transformed and quantized 8x8 data block *)
		PROCEDURE HuffmanEncode(VAR out: BitstreamWriter; CONST data: ARRAY 8 * 8 OF INTEGER);
		VAR i: INTEGER;
		BEGIN
			VAR v := data[0]: INTEGER;
			VAR bits := v - dcPrev: INTEGER; (* difference between previous and current DC value *)
			dcPrev := v;

			IF bits >= 0 THEN
				VAR numBits := CountBits(bits): INTEGER;
			ELSE
				numBits := CountBits(-bits);
				bits := INTEGER(INTEGERSET(bits-1) * BitsMask[numBits]);
			END;

			VAR tdc := huffDcTable[numBits];
			out.WriteBits(LSH(LSH(tdc,-16),numBits)+bits, numBits+(tdc MOD 100H));

			VAR numZeros := 0: SIZE;
			FOR i := 1 TO 63 DO
				bits := data[ZigZag[i]];
				IF bits # 0 THEN
					WHILE numZeros >= 16 DO
						DEC(numZeros, 16);
						out.WriteBits(acZerosBits, acZerosNumBits);
					END;

					IF bits >= 0 THEN
						numBits := CountBits(bits);
					ELSE
						numBits := CountBits(-bits);
						bits := INTEGER(INTEGERSET(bits-1) * BitsMask[numBits]);
					END;

					VAR tac := huffAcTable[numZeros*12+numBits];
					out.WriteBits(LSH(LSH(tac,-16),numBits) + bits, numBits + tac MOD 100H);
					numZeros := 0;
				ELSE
					INC(numZeros);
				END;
			END;

			IF numZeros # 0 THEN (* End Of Block (EOB) *)
				out.WriteBits(acEndOfBlockBits, acEndOfBlockNumBits);
			END;
		END HuffmanEncode;
	END;

	(** JPEG file header writing helper *)
	HeaderWriter* = RECORD
		out: Streams.Writer;

		(** Setup writer output stream *)
		PROCEDURE SetOutput*(output: Streams.Writer);
		BEGIN
			out := output;
		END SetOutput;

		PROCEDURE App0*();
		BEGIN
			out.Net16(0FFE0H); (* marker *)
			out.Net16(16); (* length *)
			out.Net8(ORD('J'));
			out.Net8(ORD('F'));
			out.Net8(ORD('I'));
			out.Net8(ORD('F'));
			out.Net8(0);
			out.Net8(1); (* JFIF version HI *)
			out.Net8(1); (* JFIF version LO *)
			out.Net8(0); (* Density units *)
			out.Net16(1); (* Xdensity *)
			out.Net16(1); (* Ydensity *)
			out.Net8(0); (* Xthumbnail *)
			out.Net8(0); (* Ythumbnail *)
		END App0;

		PROCEDURE Sof0*(width, height: INTEGER);
		BEGIN
			out.Net16(0xFFC0); (* marker *)
			out.Net16(17); (* length *)
			out.Net8(8); (* precision *)
			out.Net16(height); (* height *)
			out.Net16(width); (* width *)
			out.Net8(3); (* nrofcomponents *)
			out.Net8(1); (* IdY *)
			out.Net8(0x22); (* HVY, 4:2:0 subsampling *)
			out.Net8(0); (* QTY *)
			out.Net8(2); (* IdCb *)
			out.Net8(0x11); (* HVCb *)
			out.Net8(1); (* QTCb *)
			out.Net8(3); (* IdCr *)
			out.Net8(0x11); (* HVCr *)
			out.Net8(1); (* QTCr *)
		END Sof0;

		PROCEDURE Sof0Gray*(width, height: INTEGER);
		BEGIN
			out.Net16(0FFC0H); (* marker *)
			out.Net16(11); (* length *)
			out.Net8(8); (* precision *)
			out.Net16(height); (* height *)
			out.Net16(width); (* width *)
			out.Net8(1); (* nrofcomponents *)
			out.Net8(1); (* IdY *)
			out.Net8(11H); (* HVY, no subsampling *)
			out.Net8(0); (* QTY *)
		END Sof0Gray;

		PROCEDURE Sos*();
		BEGIN
			out.Net16(0xFFDA); (* marker *)
			out.Net16(12); (* length *)
			out.Net8(3); (* nrofcomponents *)
			out.Net8(1); (* IdY *)
			out.Net8(0); (* HTY *)
			out.Net8(2); (* IdCb *)
			out.Net8(0x11); (* HTCb *)
			out.Net8(3); (* IdCr *)
			out.Net8(0x11); (* HTCr *)
			out.Net8(0); (* Ss *)
			out.Net8(0x3F); (* Se *)
			out.Net8(0); (* Bf *)
		END Sos;

		PROCEDURE SosGray*();
		BEGIN
			out.Net16(0FFDAH); (* marker *)
			out.Net16(8); (* length *)
			out.Net8(1); (* nrofcomponents *)
			out.Net8(1); (* IdY *)
			out.Net8(0); (* HTY *)
			out.Net8(0); (* Ss *)
			out.Net8(03FH); (* Se *)
			out.Net8(0); (* Bf *)
		END SosGray;

		PROCEDURE Dqt*(CONST qLuma, qChroma: ARRAY 8 * 8 OF UNSIGNED8);
		VAR i: SIZE;
		BEGIN
			out.Net16(0FFDBH);
			out.Net16(132);
			out.Net8(0);

			FOR i := 0 TO LEN(qLuma) - 1 DO
				out.Net8(qLuma[ZigZag[i]]); (* zig-zag order *)
			END;

			out.Net8(0x01);

			FOR i := 0 TO LEN(qLuma) - 1 DO
				out.Net8(qChroma[ZigZag[i]]); (* zig-zag order *)
			END;
		END Dqt;

		PROCEDURE DqtGray*(CONST qLuma: ARRAY 8 * 8 OF UNSIGNED8);
		VAR i: SIZE;
		BEGIN
			out.Net16(0FFDBH);
			out.Net16(67);
			out.Net8(0);

			FOR i := 0 TO LEN(qLuma) - 1 DO
				out.Net8(qLuma[ZigZag[i]]); (* zig-zag order *)
			END;
		END DqtGray;

		PROCEDURE Dht*(
									CONST dcNrCodesLuma: ARRAY 17 OF UNSIGNED8; CONST dcValuesLuma: ARRAY 12 OF UNSIGNED8;
									CONST acNrCodesLuma: ARRAY 17 OF UNSIGNED8; CONST acValuesLuma: ARRAY 162 OF UNSIGNED8;
									CONST dcNrCodesChroma: ARRAY 17 OF UNSIGNED8; CONST dcValuesChroma: ARRAY 12 OF UNSIGNED8;
									CONST acNrCodesChroma: ARRAY 17 OF UNSIGNED8; CONST acValuesChroma: ARRAY 162 OF UNSIGNED8
									);
		VAR i: SIZE;
		BEGIN
			out.Net16(0FFC4H); (* marker *)
			out.Net16(0x01A2); (* length *)

			out.Net8(0);(* HTYDCinfo *)
			FOR i := 0 TO LEN(dcNrCodesLuma) - 2 DO
				out.Net8(dcNrCodesLuma[i + 1]);
			END;
			FOR i := 0 TO LEN(dcValuesLuma) - 1 DO
				out.Net8(dcValuesLuma[i]);
			END;

			out.Net8(0x10); (* HTYACinfo *)
			FOR i := 0 TO LEN(acNrCodesLuma) - 2 DO
				out.Net8(acNrCodesLuma[i + 1]);
			END;
			FOR i := 0 TO LEN(acValuesLuma) - 1 DO
				out.Net8(acValuesLuma[i]);
			END;

			out.Net8(1);(* HTCbDCinfo *)
			FOR i := 0 TO LEN(dcNrCodesChroma) - 2 DO
				out.Net8(dcNrCodesChroma[i + 1]);
			END;
			FOR i := 0 TO LEN(dcValuesChroma) - 1 DO
				out.Net8(dcValuesChroma[i]);
			END;

			out.Net8(0x11); (* HTCbACinfo *)
			FOR i := 0 TO LEN(acNrCodesChroma) - 2 DO
				out.Net8(acNrCodesChroma[i + 1]);
			END;
			FOR i := 0 TO LEN(acValuesChroma) - 1 DO
				out.Net8(acValuesChroma[i]);
			END;
		END Dht;

		PROCEDURE DhtGray*(
										CONST dcNrCodesLuma: ARRAY 17 OF UNSIGNED8; CONST dcValuesLuma: ARRAY 12 OF UNSIGNED8;
										CONST acNrCodesLuma: ARRAY 17 OF UNSIGNED8; CONST acValuesLuma: ARRAY 162 OF UNSIGNED8
										);
		VAR i: SIZE;
		BEGIN
			out.Net16(0FFC4H); (* marker *)
			out.Net16(000D2H); (* length *)

			out.Net8(0);(* HTYDCinfo *)
			FOR i := 0 TO LEN(dcNrCodesLuma) - 2 DO
				out.Net8(dcNrCodesLuma[i + 1]);
			END;
			FOR i := 0 TO LEN(dcValuesLuma) - 1 DO
				out.Net8(dcValuesLuma[i]);
			END;

			out.Net8(0x10); (* HTYACinfo *)
			FOR i := 0 TO LEN(acNrCodesLuma) - 2 DO
				out.Net8(acNrCodesLuma[i + 1]);
			END;
			FOR i := 0 TO LEN(acValuesLuma) - 1 DO
				out.Net8(acValuesLuma[i]);
			END;
		END DhtGray;

		(** Write JPEG header for a color image *)
		PROCEDURE WriteHeader*(CONST encoderY, encoderU: ChannelEncoder; width, height: INTEGER);
		BEGIN
			out.Net16(0FFD8H);
			App0();
			Dqt(encoderY.qTable, encoderU.qTable);
			Sof0(width, height);
			Dht(
				encoderY.huffDcCodes, encoderY.huffDcValues, encoderY.huffAcCodes, encoderY.huffAcValues,
				encoderU.huffDcCodes, encoderU.huffDcValues, encoderU.huffAcCodes, encoderU.huffAcValues
				);
			Sos();
		END WriteHeader;

		(** Write JPEG header for a grayscale image *)
		PROCEDURE WriteHeaderGray*(CONST encoder: ChannelEncoder; width, height: INTEGER);
		BEGIN
			out.Net16(0FFD8H);
			App0();
			DqtGray(encoder.qTable);
			Sof0Gray(width, height);
			DhtGray(encoder.huffDcCodes, encoder.huffDcValues, encoder.huffAcCodes, encoder.huffAcValues);
			SosGray();
		END WriteHeaderGray;

		(** Write end of image marker *)
		PROCEDURE EndOfImage*();
		BEGIN;
			out.Net8(0FFH);
			out.Net8(0D9H);
		END EndOfImage;
	END;

	(** 8x8 byte data block *)
	Block8x8* = ARRAY 8 * 8 OF UNSIGNED8;

	(** 2x2x8x8 byte data block *)
	Block2x2x8x8* = RECORD
		d00*{ALIGNED(BlockAlignment)}: Block8x8;
		d01*{ALIGNED(BlockAlignment)}: Block8x8;
		d10*{ALIGNED(BlockAlignment)}: Block8x8;
		d11*{ALIGNED(BlockAlignment)}: Block8x8;
	END;

	(** JPEG image encoder implementing A2 Codecs.ImageEncoder interface *)
	Encoder* = OBJECT(Codecs.ImageEncoder)
	VAR
		grayScale-: BOOLEAN; (** TRUE if grayscale option is enabled *)

		out: Streams.Writer;

		bitstreamWriter: BitstreamWriter;
		headerWriter: HeaderWriter;
		encoderY, encoderU, encoderV: ChannelEncoder;

		r, g, b: Block2x2x8x8;
		y: Block2x2x8x8;
		u{ALIGNED(BlockAlignment)}: Block8x8;
		v{ALIGNED(BlockAlignment)}: Block8x8;

		PROCEDURE &Init*();
		BEGIN
			encoderY.SetupDefaultsLuma;
			encoderU.SetupDefaultsChroma;
			encoderV.SetupDefaultsChroma;
		END Init;

		PROCEDURE Open*(output: Streams.Writer);
		BEGIN
			out := output;
			headerWriter.SetOutput(out);
			bitstreamWriter.Init(out.Char);
		END Open;

		PROCEDURE SetQuality*(quality: SIGNED32);
		BEGIN
			(*!TODO: implement support of quality regulation *)
		END SetQuality;

		PROCEDURE SetGrayscale*(enableGrayscale: BOOLEAN);
		BEGIN
			grayScale := enableGrayscale;
		END SetGrayscale;

		PROCEDURE WriteImage*(img: Raster.Image; VAR res: INTEGER);
		VAR
			getRgbBlock8x8: PROCEDURE(CONST src: ARRAY OF CHAR; srcOffs: SIZE; x0, x1: INTEGER; rowStride: SIZE; VAR r, g, b: Block8x8);
			i0, i1: INTEGER;
		BEGIN
			CASE img.fmt.code OF
				|Raster.bgr888: getRgbBlock8x8 := GetRgbBlock8x8_BGR888;
				|Raster.bgra8888: getRgbBlock8x8 := GetRgbBlock8x8_BGRA888;
			ELSE
				res := Codecs.ResFailed; RETURN;
			END;

			(*!TODO: handle the boundary cases when image width and/or height are not multiple of 16 *)
			VAR width := INTEGER(img.width DIV 16) * 16;
			VAR height := INTEGER(img.height DIV 16) * 16;

			VAR imgOffs := ADDRESSOF(img.mem[0]) - img.adr: SIZE;

			IF ~grayScale THEN (* color processing *)

				encoderY.Init;
				encoderU.Init;
				encoderV.Init;

				headerWriter.WriteHeader(encoderY, encoderU, INTEGER(img.width), INTEGER(img.height));

				i0 := 0;
				WHILE i0 < height DO
					i1 := 0;
					WHILE i1 < width DO

						GetRgbBlock2x2x8x8(img.mem^, imgOffs, i0, i1, img.bpr, getRgbBlock8x8, r, g, b);

						RgbToI420(r, g, b, y, u, v);

						encoderY.Encode(bitstreamWriter, y.d00);
						encoderY.Encode(bitstreamWriter, y.d01);
						encoderY.Encode(bitstreamWriter, y.d10);
						encoderY.Encode(bitstreamWriter, y.d11);

						encoderU.Encode(bitstreamWriter, u);
						encoderV.Encode(bitstreamWriter, v);
						INC(i1, 16);
					END;
					INC(i0, 16);
				END;

			ELSE (* grayscale processing *)

				encoderY.Init;

				headerWriter.WriteHeaderGray(encoderY, INTEGER(img.width), INTEGER(img.height));

				i0 := 0;
				WHILE i0 < height DO
					i1 := 0;
					WHILE i1 < width DO
						getRgbBlock8x8(img.mem^, imgOffs, i0, i1, img.bpr, r.d00, g.d00, b.d00);
						RgbToY8x8(r.d00, g.d00, b.d00, y.d00);
						encoderY.Encode(bitstreamWriter, y.d00);
						INC(i1, 8);
					END;
					INC(i0, 8);
				END;

			END;

			bitstreamWriter.Flush;
			headerWriter.EndOfImage;
		END WriteImage;

	END Encoder;

VAR
	ZigZag-: ARRAY 64 OF INTEGER; (* zig-zag permutation indices *)

	(* Default configuration tables *)
	DefaultQuantLuma-: ARRAY 8 * 8 OF UNSIGNED8;
	DefaultQuantChroma-: ARRAY 8 * 8 OF UNSIGNED8;
	DefaultDcNrCodesLuma-: ARRAY 17 OF UNSIGNED8;
	DefaultDcValuesLuma-: ARRAY 12 OF UNSIGNED8;
	DefaultDcNrCodesChroma-: ARRAY 17 OF UNSIGNED8;
	DefaultDcValuesChroma-: ARRAY 12 OF UNSIGNED8;
	DefaultAcNrCodesLuma-: ARRAY 17 OF UNSIGNED8;
	DefaultAcValuesLuma-: ARRAY 162 OF UNSIGNED8;
	DefaultAcNrCodesChroma-: ARRAY 17 OF UNSIGNED8;
	DefaultAcValuesChroma-: ARRAY 162 OF UNSIGNED8;
	DefaultHuffDcTableLuma-: ARRAY 12 OF UNSIGNED32;
	DefaultHuffDcTableChroma-: ARRAY 12 OF UNSIGNED32;
	DefaultHuffAcTableLuma-: ARRAY 16 * 12 OF UNSIGNED32;
	DefaultHuffAcTableChroma-: ARRAY 16 * 12 OF UNSIGNED32;

	QuantFactors: ARRAY 8 OF FLOAT32; (* factors used for computing DCT transform quantization weights *)

	BitsMask : ARRAY SIZEOF(INTEGER)*8 OF INTEGERSET;

#IF I386 OR AMD64 THEN
	(** Returns the number of bits required for representation of the input integer (of at least 16-bit) number *)
	PROCEDURE CountBits*(x: INTEGER): INTEGER;
	CODE
		MOV EAX, 0
		BSR EAX, DWORD [RBP+x]
		JZ exit
		INC EAX
	exit:
	END CountBits;
#ELSE
	(** Returns the number of bits required for representation of the input integer (of at least 16-bit) number *)
	PROCEDURE CountBits*(x: INTEGER): INTEGER;
	BEGIN
		VAR m := 0: INTEGER;
		WHILE x # 0 DO x := LSH(x, -1); INC(m) END;
		RETURN m;
	END CountBits;
#END

	(** Discrete Cosine Transform (DCT) combined with quantization applied to a 8x8 image data block

		x : input 8x8 data block to transform
		qWeights : quantization weights in fixed point format with QuantFracWidth fractional bits and the overall bitwidth of at least 16 bit
		y : output transformed 8x8 data block

		Remark: this implementation applies level offset to the input data (signed subtraction of 128)
	*)
	PROCEDURE QuantizedDct8x8*(
												CONST x: ARRAY 8 * 8 OF UNSIGNED8;
												CONST qWeights: ARRAY 8 * 8 OF INTEGER;
												VAR y: ARRAY 8 * 8 OF INTEGER
												);
	CONST
		Shift = 31 - (8 + 6) - 3 - 1;
		One = LSH(INTEGER(1), Shift);
		QuantHalf = LSH(INTEGER(1), QuantFracWidth - 1);
		C0 = SIGNED32(One * 0.707106781 + 0.5);
		C1 = SIGNED32(One * 0.382683433 + 0.5);
		C2 = SIGNED32(One * 0.541196100 + 0.5);
		C3 = SIGNED32(One * 1.306562965 + 0.5);
	BEGIN
		VAR i := 0: INTEGER;
		WHILE i < 64 DO
			(* apply level offset *)
			VAR u0 := INTEGER(x[i+0]) - 128;
			VAR u1 := INTEGER(x[i+1]) - 128;
			VAR u2 := INTEGER(x[i+2]) - 128;
			VAR u3 := INTEGER(x[i+3]) - 128;
			VAR u4 := INTEGER(x[i+4]) - 128;
			VAR u5 := INTEGER(x[i+5]) - 128;
			VAR u6 := INTEGER(x[i+6]) - 128;
			VAR u7 := INTEGER(x[i+7]) - 128;

			VAR v0 := u0 + u7;
			VAR v7 := u0 - u7;
			VAR v1 := u1 + u6;
			VAR v6 := u1 - u6;
			VAR v2 := u2 + u5;
			VAR v5 := u2 - u5;
			VAR v3 := u3 + u4;
			VAR v4 := u3 - u4;

			u0 := v0 + v3;
			u3 := v0 - v3;
			u1 := v1 + v2;
			u2 := v1 - v2;

			y[i+0] := u0 + u1;
			y[i+4] := u0 - u1;

			v0 := INTEGER(ASH((u2 + u3) * C0, -Shift));
			y[i+2] := u3 + v0;
			y[i+6] := u3 - v0;

			u0 := v4 + v5;
			u1 := v5 + v6;
			u2 := v6 + v7;

			VAR t := (u0 - u2) * C1: SIGNED32;
			v2 := INTEGER(ASH(u0 * C2 + t, -Shift));
			v4 := INTEGER(ASH(u2 * C3 + t, -Shift));
			v3 := INTEGER(ASH(u1 * C0, -Shift));

			v5 := v7 + v3;
			v6 := v7 - v3;

			y[i+5] := v6 + v2;
			y[i+3] := v6 - v2;
			y[i+1] := v5 + v4;
			y[i+7] := v5 - v4;

			INC(i,8);
		END;

		FOR i := 0 TO 7 DO
			u0 := y[0*8+i];
			u1 := y[1*8+i];
			u2 := y[2*8+i];
			u3 := y[3*8+i];
			u4 := y[4*8+i];
			u5 := y[5*8+i];
			u6 := y[6*8+i];
			u7 := y[7*8+i];

			v0 := u0 + u7;
			v7 := u0 - u7;
			v1 := u1 + u6;
			v6 := u1 - u6;
			v2 := u2 + u5;
			v5 := u2 - u5;
			v3 := u3 + u4;
			v4 := u3 - u4;

			u0 := v0 + v3;
			u3 := v0 - v3;
			u1 := v1 + v2;
			u2 := v1 - v2;

			y[0*8+i] := INTEGER(ASH(SIGNED32(u0 + u1) * qWeights[0*8+i] + QuantHalf, -QuantFracWidth));
			y[4*8+i] := INTEGER(ASH(SIGNED32(u0 - u1) * qWeights[4*8+i] + QuantHalf, -QuantFracWidth));

			v0 := INTEGER(ASH((u2 + u3) * C0, -Shift));
			y[2*8+i] := INTEGER(ASH(SIGNED32(u3 + v0) * qWeights[2*8+i] + QuantHalf, -QuantFracWidth));
			y[6*8+i] := INTEGER(ASH(SIGNED32(u3 - v0) * qWeights[6*8+i] + QuantHalf, -QuantFracWidth));

			u0 := v4 + v5;
			u1 := v5 + v6;
			u2 := v6 + v7;

			t := (u0 - u2) * C1;
			v2 := INTEGER(ASH(u0 * C2 + t, -Shift));
			v4 := INTEGER(ASH(u2 * C3 + t, -Shift));
			v3 := INTEGER(ASH(u1 * C0, -Shift));

			v5 := v7 + v3;
			v6 := v7 - v3;

			y[5*8+i] := INTEGER(ASH(SIGNED32(v6 + v2) * qWeights[5*8+i] + QuantHalf, -QuantFracWidth));
			y[3*8+i] := INTEGER(ASH(SIGNED32(v6 - v2) * qWeights[3*8+i] + QuantHalf, -QuantFracWidth));
			y[1*8+i] := INTEGER(ASH(SIGNED32(v5 + v4) * qWeights[1*8+i] + QuantHalf, -QuantFracWidth));
			y[7*8+i] := INTEGER(ASH(SIGNED32(v5 - v4) * qWeights[7*8+i] + QuantHalf, -QuantFracWidth));
		END;
	END QuantizedDct8x8;

	(** Get 8x8 R G B blocks from image data with BGR888 format

		src : image data byte array
		srcOffs :  image first pixel offset in bytes
		x0 : starting vertical pixel position
		x1 : starting horizontal (row) pixel position
		rowStride : image row stride in bytes
		r, g, b : output 8x8 R G B blocks
	*)
	PROCEDURE GetRgbBlock8x8_BGR888*(CONST src: ARRAY OF CHAR; srcOffs: SIZE; x0, x1: INTEGER; rowStride: SIZE; VAR r, g, b: Block8x8);
	BEGIN
		INC(srcOffs, SIZE(x0)*rowStride + x1*3);
		VAR dstOffs := 0: INTEGER;
		WHILE dstOffs < 64 DO
			b[dstOffs] := UNSIGNED8(ORD(src[srcOffs+0*3])); g[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(0*3+1)])); r[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(0*3+2)])); INC(dstOffs);
			b[dstOffs] := UNSIGNED8(ORD(src[srcOffs+1*3])); g[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(1*3+1)])); r[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(1*3+2)])); INC(dstOffs);
			b[dstOffs] := UNSIGNED8(ORD(src[srcOffs+2*3])); g[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(2*3+1)])); r[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(2*3+2)])); INC(dstOffs);
			b[dstOffs] := UNSIGNED8(ORD(src[srcOffs+3*3])); g[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(3*3+1)])); r[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(3*3+2)])); INC(dstOffs);
			b[dstOffs] := UNSIGNED8(ORD(src[srcOffs+4*3])); g[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(4*3+1)])); r[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(4*3+2)])); INC(dstOffs);
			b[dstOffs] := UNSIGNED8(ORD(src[srcOffs+5*3])); g[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(5*3+1)])); r[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(5*3+2)])); INC(dstOffs);
			b[dstOffs] := UNSIGNED8(ORD(src[srcOffs+6*3])); g[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(6*3+1)])); r[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(6*3+2)])); INC(dstOffs);
			b[dstOffs] := UNSIGNED8(ORD(src[srcOffs+7*3])); g[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(7*3+1)])); r[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(7*3+2)])); INC(dstOffs);
			INC(srcOffs, rowStride);
		END;
	END GetRgbBlock8x8_BGR888;

	(** Get 8x8 R G B blocks from image data with BGRA8888 format

		src : image data byte array
		srcOffs :  image first pixel offset in bytes
		x0 : starting vertical pixel position
		x1 : starting horizontal (row) pixel position
		rowStride : image row stride in bytes
		r, g, b : output 8x8 R G B blocks
	*)
	PROCEDURE GetRgbBlock8x8_BGRA888*(CONST src: ARRAY OF CHAR; srcOffs: SIZE; x0, x1: INTEGER; rowStride: SIZE; VAR r, g, b: Block8x8);
	BEGIN
		INC(srcOffs, SIZE(x0)*rowStride + x1*4);
		VAR dstOffs := 0: INTEGER;
		WHILE dstOffs < 64 DO
			b[dstOffs] := UNSIGNED8(ORD(src[srcOffs+0*4])); g[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(0*4+1)])); r[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(0*4+2)])); INC(dstOffs);
			b[dstOffs] := UNSIGNED8(ORD(src[srcOffs+1*4])); g[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(1*4+1)])); r[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(1*4+2)])); INC(dstOffs);
			b[dstOffs] := UNSIGNED8(ORD(src[srcOffs+2*4])); g[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(2*4+1)])); r[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(2*4+2)])); INC(dstOffs);
			b[dstOffs] := UNSIGNED8(ORD(src[srcOffs+3*4])); g[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(3*4+1)])); r[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(3*4+2)])); INC(dstOffs);
			b[dstOffs] := UNSIGNED8(ORD(src[srcOffs+4*4])); g[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(4*4+1)])); r[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(4*4+2)])); INC(dstOffs);
			b[dstOffs] := UNSIGNED8(ORD(src[srcOffs+5*4])); g[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(5*4+1)])); r[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(5*4+2)])); INC(dstOffs);
			b[dstOffs] := UNSIGNED8(ORD(src[srcOffs+6*4])); g[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(6*4+1)])); r[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(6*4+2)])); INC(dstOffs);
			b[dstOffs] := UNSIGNED8(ORD(src[srcOffs+7*4])); g[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(7*4+1)])); r[dstOffs] := UNSIGNED8(ORD(src[srcOffs+(7*4+2)])); INC(dstOffs);
			INC(srcOffs, rowStride);
		END;

		(*VAR srcAddr := ADDRESSOF(src[srcOffs + SIZE(x0)*rowStride + x1*4]);
		VAR dstOffs := 0: INTEGER;
		WHILE dstOffs < 64 DO
			VAR ptr := srcAddr: POINTER {UNSAFE, UNTRACED} TO ARRAY 8 OF UNSIGNED32;
			VAR bgra := ptr[0]; b[dstOffs] := UNSIGNED8(bgra); g[dstOffs] := UNSIGNED8(LSH(bgra,-8)); r[dstOffs] := UNSIGNED8(LSH(bgra,-16)); INC(dstOffs);
			bgra := ptr[1]; b[dstOffs] := UNSIGNED8(bgra); g[dstOffs] := UNSIGNED8(LSH(bgra,-8)); r[dstOffs] := UNSIGNED8(LSH(bgra,-16)); INC(dstOffs);
			bgra := ptr[2]; b[dstOffs] := UNSIGNED8(bgra); g[dstOffs] := UNSIGNED8(LSH(bgra,-8)); r[dstOffs] := UNSIGNED8(LSH(bgra,-16)); INC(dstOffs);
			bgra := ptr[3]; b[dstOffs] := UNSIGNED8(bgra); g[dstOffs] := UNSIGNED8(LSH(bgra,-8)); r[dstOffs] := UNSIGNED8(LSH(bgra,-16)); INC(dstOffs);
			bgra := ptr[4]; b[dstOffs] := UNSIGNED8(bgra); g[dstOffs] := UNSIGNED8(LSH(bgra,-8)); r[dstOffs] := UNSIGNED8(LSH(bgra,-16)); INC(dstOffs);
			bgra := ptr[5]; b[dstOffs] := UNSIGNED8(bgra); g[dstOffs] := UNSIGNED8(LSH(bgra,-8)); r[dstOffs] := UNSIGNED8(LSH(bgra,-16)); INC(dstOffs);
			bgra := ptr[6]; b[dstOffs] := UNSIGNED8(bgra); g[dstOffs] := UNSIGNED8(LSH(bgra,-8)); r[dstOffs] := UNSIGNED8(LSH(bgra,-16)); INC(dstOffs);
			bgra := ptr[7]; b[dstOffs] := UNSIGNED8(bgra); g[dstOffs] := UNSIGNED8(LSH(bgra,-8)); r[dstOffs] := UNSIGNED8(LSH(bgra,-16)); INC(dstOffs);
			INC(srcAddr, rowStride);
		END;*)
	END GetRgbBlock8x8_BGRA888;

	(** Get 2x2x8x8 R G B blocks from image data

		src : image data byte array
		srcOffs :  image first pixel offset in bytes
		x0 : starting vertical pixel position
		x1 : starting horizontal (row) pixel position
		rowStride : image row stride in bytes
		getBlock : procedure for getting 8x8 R G B blocks at a given pixel position
		r, g, b : output 8x8 R G B blocks
	*)
	PROCEDURE GetRgbBlock2x2x8x8*(
														CONST src: ARRAY OF CHAR;
														srcOffs: SIZE;
														x0, x1: INTEGER;
														rowStride: SIZE;
														getBlock: PROCEDURE(CONST src: ARRAY OF CHAR; srcOffs: SIZE; x0, x1: INTEGER; rowStride: SIZE; VAR r, g, b: Block8x8);
														VAR r, g, b: Block2x2x8x8
														);
	BEGIN
		getBlock(src, srcOffs, x0, x1, rowStride, r.d00, g.d00, b.d00);
		getBlock(src, srcOffs, x0, x1+8, rowStride, r.d01, g.d01, b.d01);
		getBlock(src, srcOffs, x0+8, x1, rowStride, r.d10, g.d10, b.d10);
		getBlock(src, srcOffs, x0+8, x1+8, rowStride, r.d11, g.d11, b.d11);
	END GetRgbBlock2x2x8x8;

	(** Get a 8x8 data block from image data with planar single byte per pixel format

		src : image data byte array
		x0 : starting vertical pixel position
		x1 : starting horizontal (row) pixel position
		rowStride : image row stride in bytes
		dst : output 8x8 block
	*)
	PROCEDURE GetBlock8x8*(CONST src: ARRAY OF CHAR; x0, x1: INTEGER; rowStride: SIZE; VAR dst: Block8x8);
	BEGIN
		VAR srcAddr := ADDRESSOF(src[SIZE(x0)*rowStride+x1]);
		VAR dstAddr := ADDRESSOF(dst[0]);
		SYSTEM.MOVE(srcAddr, dstAddr+0*8, 8); INC(srcAddr, rowStride);
		SYSTEM.MOVE(srcAddr, dstAddr+1*8, 8); INC(srcAddr, rowStride);
		SYSTEM.MOVE(srcAddr, dstAddr+2*8, 8); INC(srcAddr, rowStride);
		SYSTEM.MOVE(srcAddr, dstAddr+3*8, 8); INC(srcAddr, rowStride);
		SYSTEM.MOVE(srcAddr, dstAddr+4*8, 8); INC(srcAddr, rowStride);
		SYSTEM.MOVE(srcAddr, dstAddr+5*8, 8); INC(srcAddr, rowStride);
		SYSTEM.MOVE(srcAddr, dstAddr+6*8, 8); INC(srcAddr, rowStride);
		SYSTEM.MOVE(srcAddr, dstAddr+7*8, 8);
	END GetBlock8x8;

	(** Compute Luma data for a given 8x8 R G B blockset

		r, g, b : input 8x8 R G B blocks
		y : output 8x8 Luma (Y) block
	*)
	PROCEDURE RgbToY8x8*(CONST r, g, b: Block8x8; VAR y: Block8x8);
	VAR i: INTEGER;
	BEGIN
		FOR i := 0 TO 63 DO
			y[i] := UNSIGNED8(LSH(153*SIGNED32(r[i]) + 301*SIGNED32(g[i]) + 58*SIGNED32(b[i]), -9));
		END;
	END RgbToY8x8;

	(** Compute 4:2:0 subsampled Chroma data for a given 8x8 R G B blockset

		r, g, b : input 8x8 R G B blocks
		x0 : starting vertical pixel position in the output
		x1 : starting horizontal (row) pixel position in the output
		u : output 8x8 U (Cb) Chroma block
		v : output 8x8 V (Cr) Chroma block
	*)
	PROCEDURE RgbToCbCr8x8*(CONST r, g, b: Block8x8; x0, x1: INTEGER; VAR u, v: Block8x8);

		PROCEDURE -RgbToCb(rs, gs, bs: SIGNED32): UNSIGNED8;
		BEGIN
			RETURN UNSIGNED8(LSH(65536*4 - 86*rs - 170*gs + 256*bs, -11));
		END RgbToCb;

		PROCEDURE -RgbToCr(rs, gs, bs: SIGNED32): UNSIGNED8;
		BEGIN
			RETURN UNSIGNED8(LSH(65536*4 + 256*rs - 214*gs - 42*bs, -11));
		END RgbToCr;

	BEGIN
		VAR dstOffs := x0*8 + x1;
		VAR srcOffs := 0: INTEGER;

		VAR i0 := 0: INTEGER;
		WHILE i0 < 4 DO
			VAR rs := INTEGER(r[srcOffs]) + INTEGER(r[srcOffs+1]) + INTEGER(r[srcOffs+8]) + INTEGER(r[srcOffs+9]);
			VAR gs := INTEGER(g[srcOffs]) + INTEGER(g[srcOffs+1]) + INTEGER(g[srcOffs+8]) + INTEGER(g[srcOffs+9]);
			VAR bs := INTEGER(b[srcOffs]) + INTEGER(b[srcOffs+1]) + INTEGER(b[srcOffs+8]) + INTEGER(b[srcOffs+9]);
			u[dstOffs+0] := RgbToCb(rs,gs,bs); v[dstOffs+0] := RgbToCr(rs,gs,bs);

			rs := INTEGER(r[srcOffs+2]) + INTEGER(r[srcOffs+3]) + INTEGER(r[srcOffs+10]) + INTEGER(r[srcOffs+11]);
			gs := INTEGER(g[srcOffs+2]) + INTEGER(g[srcOffs+3]) + INTEGER(g[srcOffs+10]) + INTEGER(g[srcOffs+11]);
			bs := INTEGER(b[srcOffs+2]) + INTEGER(b[srcOffs+3]) + INTEGER(b[srcOffs+10]) + INTEGER(b[srcOffs+11]);
			u[dstOffs+1] := RgbToCb(rs,gs,bs); v[dstOffs+1] := RgbToCr(rs,gs,bs);

			rs := INTEGER(r[srcOffs+4]) + INTEGER(r[srcOffs+5]) + INTEGER(r[srcOffs+12]) + INTEGER(r[srcOffs+13]);
			gs := INTEGER(g[srcOffs+4]) + INTEGER(g[srcOffs+5]) + INTEGER(g[srcOffs+12]) + INTEGER(g[srcOffs+13]);
			bs := INTEGER(b[srcOffs+4]) + INTEGER(b[srcOffs+5]) + INTEGER(b[srcOffs+12]) + INTEGER(b[srcOffs+13]);
			u[dstOffs+2] := UNSIGNED8(RgbToCb(rs,gs,bs)); v[dstOffs+2] := UNSIGNED8(RgbToCr(rs,gs,bs));

			rs := INTEGER(r[srcOffs+6]) + INTEGER(r[srcOffs+7]) + INTEGER(r[srcOffs+14]) + INTEGER(r[srcOffs+15]);
			gs := INTEGER(g[srcOffs+6]) + INTEGER(g[srcOffs+7]) + INTEGER(g[srcOffs+14]) + INTEGER(g[srcOffs+15]);
			bs := INTEGER(b[srcOffs+6]) + INTEGER(b[srcOffs+7]) + INTEGER(b[srcOffs+14]) + INTEGER(b[srcOffs+15]);
			u[dstOffs+3] := RgbToCb(rs,gs,bs); v[dstOffs+3] := RgbToCr(rs,gs,bs);

			INC(i0); INC(srcOffs, 16); INC(dstOffs, 8);
		END;
	END RgbToCbCr8x8;

	(**
		Perform RGB to I420 (a.k. YUV420) 2x2x8x8 block conversion

		r, g, b : input 2x2x8x8 RGB data block
		y : output 2x2x8x8 Luma (Y) block
		u: output 8x8 block of Chroma U a.k. Cb (blue-difference)
		v: output 8x8 block of Chroma V a.k. Cr (red-difference)
	*)
	PROCEDURE RgbToI420*(CONST r, g, b: Block2x2x8x8; VAR y: Block2x2x8x8; VAR u, v: Block8x8);
	BEGIN
		RgbToY8x8(r.d00, g.d00, b.d00, y.d00);
		RgbToY8x8(r.d01, g.d01, b.d01, y.d01);
		RgbToY8x8(r.d10, g.d10, b.d10, y.d10);
		RgbToY8x8(r.d11, g.d11, b.d11, y.d11);

		RgbToCbCr8x8(r.d00, g.d00, b.d00, 0,0, u, v);
		RgbToCbCr8x8(r.d01, g.d01, b.d01, 0,4, u, v);
		RgbToCbCr8x8(r.d10, g.d10, b.d10, 4,0, u, v);
		RgbToCbCr8x8(r.d11, g.d11, b.d11, 4,4, u, v);
	END RgbToI420;

	PROCEDURE InitMod;
	BEGIN
		ZigZag :=
		[
			INTEGER(0),
			1, 8,
			16, 9, 2,
			3,10,17,24,
			32,25,18,11, 4,
			5,12,19,26,33,40,
			48,41,34,27,20,13, 6,
			7,14,21,28,35,42,49,56,
			57,50,43,36,29,22,15,
			23,30,37,44,51,58,
			59,52,45,38,31,
			39,46,53,60,
			61,54,47,
			55,62,
			63
		];

		DefaultQuantLuma :=
		[
			 UNSIGNED8(8),  6,  5,  8, 12, 20, 26, 31,
			 6,  6,  7, 10, 13, 29, 30, 28,
			 7,  7,  8, 12, 20, 29, 35, 28,
			 7,  9, 11, 15, 26, 44, 40, 31,
			 9, 11, 19, 28, 34, 55, 52, 39,
			 12, 18, 28, 32, 41, 52, 57, 46,
			 25, 32, 39, 44, 52, 61, 60, 51,
			 36, 46, 48, 49, 56, 50, 52, 50
		];

		DefaultQuantChroma :=
		[
			UNSIGNED8(9),  9, 12, 24, 50, 50, 50, 50,
			9, 11, 13, 33, 50, 50, 50, 50,
			12, 13, 28, 50, 50, 50, 50, 50,
			24, 33, 50, 50, 50, 50, 50, 50,
			50, 50, 50, 50, 50, 50, 50, 50,
			50, 50, 50, 50, 50, 50, 50, 50,
			50, 50, 50, 50, 50, 50, 50, 50,
			50, 50, 50, 50, 50, 50, 50, 50
		];

		DefaultDcNrCodesLuma := [UNSIGNED8(0), 0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0];

		DefaultDcValuesLuma := [UNSIGNED8(0), 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

		DefaultDcNrCodesChroma := [UNSIGNED8(0), 0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0];

		DefaultDcValuesChroma := [UNSIGNED8(0), 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

		DefaultAcNrCodesLuma := [UNSIGNED8(0), 0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 0x7d];

		DefaultAcValuesLuma :=
		[
			UNSIGNED8(0x01), 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12,
			0x21, 0x31, 0x41, 0x06, 0x13, 0x51, 0x61, 0x07,
			0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xa1, 0x08,
			0x23, 0x42, 0xb1, 0xc1, 0x15, 0x52, 0xd1, 0xf0,
			0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0a, 0x16,
			0x17, 0x18, 0x19, 0x1a, 0x25, 0x26, 0x27, 0x28,
			0x29, 0x2a, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39,
			0x3a, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49,
			0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59,
			0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69,
			0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79,
			0x7a, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
			0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98,
			0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7,
			0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6,
			0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3, 0xc4, 0xc5,
			0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2, 0xd3, 0xd4,
			0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda, 0xe1, 0xe2,
			0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea,
			0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8,
			0xf9, 0xfa
		];

		DefaultAcNrCodesChroma := [UNSIGNED8(0), 0, 2, 1, 2, 4, 4, 3, 4, 7, 5, 4, 4, 0, 1, 2, 0x77];

		DefaultAcValuesChroma :=
		[
			UNSIGNED8(0x00), 0x01, 0x02, 0x03, 0x11, 0x04, 0x05, 0x21,
			0x31, 0x06, 0x12, 0x41, 0x51, 0x07, 0x61, 0x71,
			0x13, 0x22, 0x32, 0x81, 0x08, 0x14, 0x42, 0x91,
			0xa1, 0xb1, 0xc1, 0x09, 0x23, 0x33, 0x52, 0xf0,
			0x15, 0x62, 0x72, 0xd1, 0x0a, 0x16, 0x24, 0x34,
			0xe1, 0x25, 0xf1, 0x17, 0x18, 0x19, 0x1a, 0x26,
			0x27, 0x28, 0x29, 0x2a, 0x35, 0x36, 0x37, 0x38,
			0x39, 0x3a, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48,
			0x49, 0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58,
			0x59, 0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68,
			0x69, 0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78,
			0x79, 0x7a, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87,
			0x88, 0x89, 0x8a, 0x92, 0x93, 0x94, 0x95, 0x96,
			0x97, 0x98, 0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5,
			0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4,
			0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3,
			0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2,
			0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda,
			0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9,
			0xea, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8,
			0xf9, 0xfa
		];

		DefaultHuffDcTableLuma := [UNSIGNED32(0x00000002),0x00020003,0x00030003,0x00040003,0x00050003,0x00060003,0x000e0004,0x001e0005,0x003e0006,0x007e0007,0x00fe0008,0x01fe0009];

		DefaultHuffDcTableChroma := [UNSIGNED32(0x00000002),0x00010002,0x00020002,0x00060003,0x000e0004,0x001e0005,0x003e0006,0x007e0007,0x00fe0008,0x01fe0009,0x03fe000a,0x07fe000b];

		DefaultHuffAcTableLuma :=
		[
			UNSIGNED32(0x000a0004),0x00000002,0x00010002,0x00040003,0x000b0004,0x001a0005,0x00780007,0x00f80008,0x03f6000a,0xff820010,0xff830010,0x00000000,
			0x00000000,0x000c0004,0x001b0005,0x00790007,0x01f60009,0x07f6000b,0xff840010,0xff850010,0xff860010,0xff870010,0xff880010,0x00000000,
			0x00000000,0x001c0005,0x00f90008,0x03f7000a,0x0ff4000c,0xff890010,0xff8a0010,0xff8b0010,0xff8c0010,0xff8d0010,0xff8e0010,0x00000000,
			0x00000000,0x003a0006,0x01f70009,0x0ff5000c,0xff8f0010,0xff900010,0xff910010,0xff920010,0xff930010,0xff940010,0xff950010,0x00000000,
			0x00000000,0x003b0006,0x03f8000a,0xff960010,0xff970010,0xff980010,0xff990010,0xff9a0010,0xff9b0010,0xff9c0010,0xff9d0010,0x00000000,
			0x00000000,0x007a0007,0x07f7000b,0xff9e0010,0xff9f0010,0xffa00010,0xffa10010,0xffa20010,0xffa30010,0xffa40010,0xffa50010,0x00000000,
			0x00000000,0x007b0007,0x0ff6000c,0xffa60010,0xffa70010,0xffa80010,0xffa90010,0xffaa0010,0xffab0010,0xffac0010,0xffad0010,0x00000000,
			0x00000000,0x00fa0008,0x0ff7000c,0xffae0010,0xffaf0010,0xffb00010,0xffb10010,0xffb20010,0xffb30010,0xffb40010,0xffb50010,0x00000000,
			0x00000000,0x01f80009,0x7fc0000f,0xffb60010,0xffb70010,0xffb80010,0xffb90010,0xffba0010,0xffbb0010,0xffbc0010,0xffbd0010,0x00000000,
			0x00000000,0x01f90009,0xffbe0010,0xffbf0010,0xffc00010,0xffc10010,0xffc20010,0xffc30010,0xffc40010,0xffc50010,0xffc60010,0x00000000,
			0x00000000,0x01fa0009,0xffc70010,0xffc80010,0xffc90010,0xffca0010,0xffcb0010,0xffcc0010,0xffcd0010,0xffce0010,0xffcf0010,0x00000000,
			0x00000000,0x03f9000a,0xffd00010,0xffd10010,0xffd20010,0xffd30010,0xffd40010,0xffd50010,0xffd60010,0xffd70010,0xffd80010,0x00000000,
			0x00000000,0x03fa000a,0xffd90010,0xffda0010,0xffdb0010,0xffdc0010,0xffdd0010,0xffde0010,0xffdf0010,0xffe00010,0xffe10010,0x00000000,
			0x00000000,0x07f8000b,0xffe20010,0xffe30010,0xffe40010,0xffe50010,0xffe60010,0xffe70010,0xffe80010,0xffe90010,0xffea0010,0x00000000,
			0x00000000,0xffeb0010,0xffec0010,0xffed0010,0xffee0010,0xffef0010,0xfff00010,0xfff10010,0xfff20010,0xfff30010,0xfff40010,0x00000000,
			0x07f9000b,0xfff50010,0xfff60010,0xfff70010,0xfff80010,0xfff90010,0xfffa0010,0xfffb0010,0xfffc0010,0xfffd0010,0xfffe0010,0x00000000
		];

		DefaultHuffAcTableChroma :=
		[
			UNSIGNED32(0x00000002),0x00010002,0x00040003,0x000a0004,0x00180005,0x00190005,0x00380006,0x00780007,0x01f40009,0x03f6000a,0x0ff4000c,0x00000000,
			0x00000000,0x000b0004,0x00390006,0x00f60008,0x01f50009,0x07f6000b,0x0ff5000c,0xff880010,0xff890010,0xff8a0010,0xff8b0010,0x00000000,
			0x00000000,0x001a0005,0x00f70008,0x03f7000a,0x0ff6000c,0x7fc2000f,0xff8c0010,0xff8d0010,0xff8e0010,0xff8f0010,0xff900010,0x00000000,
			0x00000000,0x001b0005,0x00f80008,0x03f8000a,0x0ff7000c,0xff910010,0xff920010,0xff930010,0xff940010,0xff950010,0xff960010,0x00000000,
			0x00000000,0x003a0006,0x01f60009,0xff970010,0xff980010,0xff990010,0xff9a0010,0xff9b0010,0xff9c0010,0xff9d0010,0xff9e0010,0x00000000,
			0x00000000,0x003b0006,0x03f9000a,0xff9f0010,0xffa00010,0xffa10010,0xffa20010,0xffa30010,0xffa40010,0xffa50010,0xffa60010,0x00000000,
			0x00000000,0x00790007,0x07f7000b,0xffa70010,0xffa80010,0xffa90010,0xffaa0010,0xffab0010,0xffac0010,0xffaf0010,0xffae0010,0x00000000,
			0x00000000,0x007a0007,0x07f8000b,0xffaf0010,0xffb00010,0xffb10010,0xffb20010,0xffb30010,0xffb40010,0xffb50010,0xffb60010,0x00000000,
			0x00000000,0x00f90008,0xffb70010,0xffb80010,0xffb90010,0xffba0010,0xffbb0010,0xffbc0010,0xffbd0010,0xffbe0010,0xffbf0010,0x00000000,
			0x00000000,0x01f70009,0xffc00010,0xffc10010,0xffc20010,0xffc30010,0xffc40010,0xffc50010,0xffc60010,0xffc70010,0xffc80010,0x00000000,
			0x00000000,0x01f80009,0xffc90010,0xffca0010,0xffcb0010,0xffcc0010,0xffcd0010,0xffce0010,0xffcf0010,0xffd00010,0xffd10010,0x00000000,
			0x00000000,0x01f90009,0xffd20010,0xffd30010,0xffd40010,0xffd50010,0xffd60010,0xffd70010,0xffd80010,0xffd90010,0xffda0010,0x00000000,
			0x00000000,0x01fa0009,0xffdb0010,0xffdc0010,0xffdd0010,0xffde0010,0xffdf0010,0xffe00010,0xffe10010,0xffe20010,0xffe30010,0x00000000,
			0x00000000,0x07f9000b,0xffe40010,0xffe50010,0xffe60010,0xffe70010,0xffe80010,0xffe90010,0xffea0010,0xffeb0010,0xffec0010,0x00000000,
			0x00000000,0x3fe0000e,0xffed0010,0xffee0010,0xffef0010,0xfff00010,0xfff10010,0xfff20010,0xfff30010,0xfff40010,0xfff50010,0x00000000,
			0x03fa000a,0x7fc3000f,0xfff60010,0xfff70010,0xfff80010,0xfff90010,0xfffa0010,0xfffb0010,0xfffc0010,0xfffd0010,0xfffe0010,0x00000000
		];

		QuantFactors := [1.0, 1.387039845, 1.306562965 , 1.175875602, 1.0, 0.785694958, 0.541196100, 0.275899379];

		VAR i: INTEGER;
		BitsMask[0] := INTEGERSET({});
		FOR i := 1 TO LEN(BitsMask)-1 DO
			BitsMask[i] := INTEGERSET({0..i-1});
		END;
	END InitMod;

BEGIN
	InitMod;
END JPEGEncoder.

System.FreeDownTo JPEGEncoder ~

FoxTest.Compile	-l=Test.Log JPEG.Execution.Test  ~
