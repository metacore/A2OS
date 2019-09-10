MODULE TeletextDecoder; (** AUTHOR "oljeger@student.ethz.ch"; PURPOSE "Teletext Decoder"; *)

IMPORT
	SYSTEM, TVDriver, TVChannels, KernelLog, Texts, Dates, Strings, UTF8Strings;


CONST
	DEBUG = FALSE;

	VtPageSize = 40*24;
	FormattedPageSize = 41*24;
	VbiLines = TVDriver.VbiMaxLines;
	VbiLineSize = TVDriver.VbiLineSize;
	VbiDataSize = TVDriver.VbiDataSize;
	VbiBufferSize = TVDriver.VbiBufferSize;
	VbiVT = {1};
	VbiUndefined* = -1;
	FpFac = 65536;

	Red = 0;
	Green = 1;
	Blue = 2;
	Yellow = 3;
	Magenta = 4;
	Cyan = 5;
	White = 6;
	Black = 7;


TYPE
	TeletextSuite* = OBJECT
	VAR
		channel*: TVChannels.TVChannel;
		pages- : ARRAY 800 OF TeletextPageSet;
		next* : TeletextSuite;

		PROCEDURE &Init*;
		VAR
			i : SIZE;
		BEGIN
			FOR i := 0 TO 799 DO
				NEW(pages[i]);
				pages[i].data := NIL;
				pages[i].next := VbiUndefined;
				pages[i].prev := VbiUndefined
			END
		END Init;

		(** Get the number of cached teletext pages. Subpages are counted too *)
		PROCEDURE Count*() : SIGNED32;
		VAR
			i, cnt : SIGNED32;
			pag, cur : TeletextPage;
		BEGIN
			FOR i := 0 TO 799 DO
				IF (pages[i].data # NIL) THEN
					pag := pages[i].data;
					cur := pag;
					INC(cnt);
					WHILE cur.nextSub # pag DO
						INC(cnt);
						cur := cur.nextSub
					END
				END
			END;
			RETURN cnt
		END Count;

		PROCEDURE MakeEmptyPage(pageNum, subPage : SIGNED32) : TeletextPage;
		VAR
			existingPage, newPage : TeletextPage;
			newPageNumber : BOOLEAN;
			next, prev : SIGNED32;
		BEGIN {EXCLUSIVE}
			(* subPage: ordered double-linked list *)
			IF pages[pageNum].data = NIL THEN
				NEW(pages[pageNum].data);
				newPage := pages[pageNum].data;

				newPage.nextSub := newPage;
				newPage.prevSub := newPage;
				newPageNumber := TRUE
			ELSE
				newPageNumber := FALSE;
				existingPage := pages[pageNum].data;

				(* search for the appropriate subpage position in the ordered list *)
				IF subPage < existingPage.subPageNo THEN
					(* new subpage is smaller than all others *)
					NEW(newPage);
					newPage.nextSub := existingPage;
					newPage.prevSub := existingPage.prevSub;
					newPage.prevSub.nextSub := newPage;
					existingPage.prevSub := newPage;
					pages[pageNum].data := newPage
				ELSE
					(* traverse the list backwards to find the insertion position *)
					WHILE (existingPage.prevSub.subPageNo > subPage) DO
						existingPage := existingPage.prevSub
					END;

					existingPage := existingPage.prevSub;
					(* existingPage points now either to the subpage with the next lower index or with the same index *)

					IF existingPage.subPageNo # subPage THEN
						(* create a new subPage and insert it in the list *)
						NEW(newPage);
						newPage.nextSub := existingPage.nextSub;
						newPage.prevSub := existingPage;
						existingPage.nextSub := newPage;
						newPage.nextSub.prevSub := newPage
					ELSE
						newPage := existingPage
					END
				END
			END;
			(* newPage points now to the correct datapage *)
			newPage.pageNumber := pageNum;
			newPage.subPageNo := subPage;
			newPage.Reset;

			(* Adjust the page linking if necessary *)
			IF newPageNumber THEN
				(* insert the new page in the double linked list: *)
				(* determine the previous valid page *)
				prev := (pageNum - 1);
				WHILE (prev >= 0) & (pages[prev].data = NIL) DO
					DEC(prev)
				END;
				IF prev >= 0 THEN
					(* there exists a valid page with a lower index *)
					IF pages[prev].next # VbiUndefined THEN
						(* it has a successor *)
						pages[pageNum].next := pages[prev].next;
						pages[pages[pageNum].next].prev := pageNum
					ELSE
						pages[pageNum].next := VbiUndefined
					END;

					(* link the page with its precessor *)
					pages[pageNum].prev := prev;
					pages[prev].next := pageNum
				ELSE
					pages[pageNum].prev := VbiUndefined;

					(* determine the next valid page *)
					next := pageNum + 1;
					WHILE (next < 800) & (pages[next].data = NIL) DO
						INC(next)
					END;
					IF next < 800 THEN (* fall 3) *)
						(* valid page found *)
						pages[pageNum].next := next;
						pages[next].prev := pageNum
					ELSE
						pages[pageNum].next := VbiUndefined
					END
				END
			END;

			RETURN newPage
		END MakeEmptyPage;
	END TeletextSuite;

	TeletextPageSet* = OBJECT
		VAR
		next-, prev- : SIGNED32;
		data- : TeletextPage;
	END TeletextPageSet;

	TeletextPage* = OBJECT
	VAR
		nextSub-, prevSub- : TeletextPage;
		pageNumber, subPageNo- : SIGNED32;
		text- : Texts.Text;
		attributes-: ARRAY FormattedPageSize OF SIGNED8;

		PROCEDURE &Init*;
		BEGIN
			NEW(text)
		END Init;

		PROCEDURE Reset;
		VAR
			i : SIGNED32;
		BEGIN
			text.AcquireWrite;
			text.Delete(0, text.GetLength());
			text.ReleaseWrite;
			FOR i := 0 TO VtPageSize-1 DO
				attributes[i] := 0
			END
		END Reset;

	END TeletextPage;

	PageBuffer = OBJECT
	VAR
		vbi : VbiDecoder;	(* needed to write into the correct TeletextSuite *)
		pageNo, subPageNo : SIGNED32;
		data : ARRAY VtPageSize OF CHAR;
		language : SIGNED32;
		discardPage, suppressHeader, boxedContent : BOOLEAN;
		packets: SET;
		lastPacket: SIGNED32;

		PROCEDURE &Init*(vbi : VbiDecoder);
		BEGIN
			SELF.vbi := vbi
		END Init;

		PROCEDURE Reset(page, sub : SIGNED32);
		VAR
			i : SIGNED32;
		BEGIN
			pageNo := page;
			subPageNo := sub;
			FOR i := 0 TO VtPageSize-1 DO
				data[i] := ' '
			END;
			language := 0;
			discardPage := FALSE;
			suppressHeader := FALSE;
			boxedContent := FALSE;
			packets := {};
			lastPacket := -1
		END Reset;

		(* Remove any non-printable characters from the channel name *)
		PROCEDURE SkipBlanks(VAR name : ARRAY OF CHAR; VAR startPos : SIGNED32);
		VAR
			i : SIGNED32;
		BEGIN
			i := startPos;
			WHILE (i < LEN(name)-1) & ((name[i] < '0') OR (ORD(name[i]) > 150)) DO
				name[i] := ' ';
				INC(i)
			END;
			startPos := i
		END SkipBlanks;

		PROCEDURE IsDigit(ch : CHAR) : BOOLEAN;
		BEGIN
			RETURN (ch >= '0') & (ch <='9')
		END IsDigit;

		(* remove the page number from the channel name *)
		PROCEDURE SkipPageNum(VAR name : ARRAY OF CHAR; VAR startPos : SIGNED32);
		VAR
			i : SIGNED32;
		BEGIN
			i := startPos;
			IF IsDigit(name[i]) & IsDigit(name[i+1]) & IsDigit(name[i+2]) & (name[i+3] = ' ') THEN
				FOR i := startPos TO startPos + 2 DO
					name[i] := ' '
				END;
				startPos := startPos + 4
			ELSIF (name[i] = 'P') & IsDigit(name[i+1]) & IsDigit(name[i+2]) & IsDigit(name[i+3]) & (name[i+4] = ' ')THEN
				FOR i := startPos TO startPos + 3 DO
					name[i] := ' '
				END;
				startPos := startPos + 5
			END
		END SkipPageNum;

		PROCEDURE MarkupPage;
		VAR
			text: ARRAY FormattedPageSize OF Texts.Char32;
			fgColor, bgColor: ARRAY FormattedPageSize OF SIGNED8;
			flashing, boxed: ARRAY FormattedPageSize OF BOOLEAN;
			forceAlpha, isGraphics, holdGraphics, isDouble, hasDouble, conceal, isFlashing, separatedGraphics : BOOLEAN;
			teletextPage: TeletextPage;
			i, j, k, begin : SIGNED32;
			ch : SIGNED32;
			fg, bg, isBoxed : SIGNED8;

		PROCEDURE CreateAttribute(fg, bg: SIGNED8; flashing, boxed: BOOLEAN) : SIGNED8;
		VAR
			attr: SIGNED8;
		BEGIN
			(* Teletext is very memory-intensive (approx. 1000 pages per TV channel) => Compress attributes *)
			(* 'fg' is coded into bits 0-2, 'bg' is coded into 3-5, 'flashing' is coded in bit no. 6 and 'boxed' modifies the sign *)
			(* Note: bit 0 = LSB *)
			attr := fg + 8*bg;
			IF flashing THEN
				INC(attr, 64)
			END;
			IF boxed THEN
				attr := -attr
			END;
			RETURN attr
		END CreateAttribute;

		BEGIN
			(* Some pages are invalidated, don't display them *)
			IF (pageNo = 0) OR (vbi.currentSuite = NIL) THEN RETURN END;
			teletextPage := vbi.currentSuite.MakeEmptyPage(pageNo-100, subPageNo);
			(* datapage is not NIL and has been resetted automatically *)

			(* Initialize Arrays *)
			FOR i := 0 TO FormattedPageSize-1 DO
				text[i] := 0;
				fgColor[i] := 0;
				bgColor[i] := 0;
				flashing[i] := FALSE;
				boxed[i] := FALSE
			END;

			(* Overwrite unprintable chars at the beginning of a page *)
			FOR i := 0 TO 7 DO
				text[i] := ORD(' ');
				fgColor[i] := White;
				bgColor[i] := Black
			END;

			FOR i := 0 TO 23 DO
				(* Beginning of a new line: Reset attributes *)
				isGraphics := FALSE;
				holdGraphics := FALSE;
				separatedGraphics := FALSE;
				isDouble := FALSE;
				isFlashing := FALSE;
				isBoxed := 0;
				hasDouble := FALSE;
				conceal := FALSE;
				fg := White;
				bg := Black;

				(* Process line *)
				FOR j := 0 TO 39 DO
					ch := ORD (data[40*i + j]) MOD 128;	(* remove odd parity bit (no check for correctness) *)

					(* Write only to empty cells (non-empty cells have already been processed) *)
					IF text[i*41 + j] = 0 THEN
						(* Handle 'Set At' Attributes *)
						CASE ch OF
							  9 : isFlashing := FALSE			    (* Steady (not flashing) *)
						  | 12 : isDouble := FALSE				(* normal height *)
						  | 24 : conceal := TRUE					(* Conceal display (these characters are NEVER displayed) *)
						  | 25 : separatedGraphics := FALSE (* Contiguous graphics *)
						  | 26 : separatedGraphics := TRUE  (* Separated graphics *)
						  | 28 : bg := Black						   (* black background *)
						  | 29 : bg := fg								 (* new background *)
						  | 30 : holdGraphics := TRUE		   (* hold graphics *)
						ELSE
						END;

						forceAlpha := (ch >= 64) & (ch < 96);

						(* Replace non-printable characters by a space *)
						IF boxedContent & (isBoxed < 2) THEN
							(* We are in a newsflash or subtitle page, but not inside boxed content => discard text *)
							text[i*41 + j] := 32
						ELSIF (ch < 32) THEN
							IF isGraphics & holdGraphics THEN
								(* hold graphics: Repeat the last mosaic character *)
								text[i*41 + j] := text[i*41 + j-1]
							ELSE
								text[i*41 + j] := 32	(* space *)
							END
						ELSIF conceal THEN
							(* Concealed characters are not to be displayed *)
							text [i*41 + j] := 32
						ELSIF isGraphics & (~ forceAlpha) THEN
							(* Offset to mosaic graphics section *)
							text [i*41 + j] := ch + 57312
						ELSE
							(* Normal text *)
							(* Take care of the language-specific characters *)
							CASE ch OF
								  35 : text [i*41 + j] := nationals [language][0]
							  |   36 : text [i*41 + j] := nationals [language][1]
							  |   64 : text [i*41 + j] := nationals [language][2]
							  |   91 : text [i*41 + j] := nationals [language][3]
							  |   92 : text [i*41 + j] := nationals [language][4]
							  |   93 : text [i*41 + j] := nationals [language][5]
							  |   94 : text [i*41 + j] := nationals [language][6]
							  |   95 : text [i*41 + j] := nationals [language][7]
							  |   96 : text [i*41 + j] := nationals [language][8]
							  | 123 : text [i*41 + j] := nationals [language][9]
							  | 124 : text [i*41 + j] := nationals [language][10]
							  | 125 : text [i*41 + j] := nationals [language][11]
							  | 126 : text [i*41 + j] := nationals [language][12]
							  | 127 : text [i*41 + j] := 57440	(* filled square *)
							ELSE
								text [i*41 + j] := ch
							END

						END;
						IF isDouble THEN
							DoubleHeight (text, i*41 + j)
						END;

						(* Set attributes for the current character *)
						IF fgColor [i*41 + j] = 0 THEN
							fgColor [i*41 + j] := fg;
							bgColor [i*41 + j] := bg;
							flashing [i*41 + j] := isFlashing;
							IF isBoxed > 1 THEN
								boxed[i*41 + j-1] := TRUE;	(* Start box is transmitted twice, include the first one *)
								boxed[i*41 + j] := TRUE
							END;
							IF isDouble & (i < 23) THEN
								flashing [(i+1)*41 + j] := isFlashing;
								IF isBoxed > 1 THEN
									boxed[(i+1)*41 + j-1] := TRUE;	(* Start box is transmitted twice, include the first one *)
									boxed[(i+1)*41 + j] := TRUE
								END
							END
						END;

						(* Handle 'Set After' Attributes *)
						CASE ch OF
							 0 : isGraphics := FALSE; conceal := FALSE; fg := Black			(* Black alpha, not documented *)
						 |   1 : isGraphics := FALSE; conceal := FALSE; fg := Red			  (* Red alpha *)
						 |   2 : isGraphics := FALSE; conceal := FALSE; fg := Green		  (* Green alpha *)
						 |   3 : isGraphics := FALSE; conceal := FALSE; fg := Yellow		  (* Yellow alpha *)
						 |   4 : isGraphics := FALSE; conceal := FALSE; fg := Blue			 (* Blue alpha *)
						 |   5 : isGraphics := FALSE; conceal := FALSE; fg := Magenta	  (* Magenta alpha *)
						 |   6 : isGraphics := FALSE; conceal := FALSE; fg := Cyan			(* Cyan alpha *)
						 |   7 : isGraphics := FALSE; conceal := FALSE; fg := White		  (* White alpha *)

						 |   8 : isFlashing := TRUE															(* Flashing *)
						 | 10 : DEC(isBoxed)																   (* End box *)
						 | 11 : INC(isBoxed)																	(* Start box *)
						 | 13 : isDouble := TRUE; hasDouble := TRUE							 (* Double height *)

						 | 16 : isGraphics := TRUE; conceal := FALSE; fg := Black			(* Black graphics, not documented *)
						 | 17 : isGraphics := TRUE; conceal := FALSE; fg := Red			  (* Red graphics *)
						 | 18 : isGraphics := TRUE; conceal := FALSE; fg := Green		  (* Green graphics *)
						 | 19 : isGraphics := TRUE; conceal := FALSE; fg := Yellow		  (* Yellow graphics *)
						 | 20 : isGraphics := TRUE; conceal := FALSE; fg := Blue			 (* Blue graphics *)
						 | 21 : isGraphics := TRUE; conceal := FALSE; fg := Magenta	  (* Magenta graphics *)
						 | 22 : isGraphics := TRUE; conceal := FALSE; fg := Cyan			(* Cyan graphics *)
						 | 23 : isGraphics := TRUE; conceal := FALSE; fg := White		  (* White graphics *)

						 | 27 : (* ESC/Switch: TO BE DONE *)
						 | 31 : holdGraphics := FALSE													(* Release graphics *)
						ELSE
						END
					END
				END;

				(* Terminate the line *)
				text [i*41 + 40] := Texts.NewLineChar;
				fgColor[i*41 + 40] := White;
				bgColor[i*41 + 40] := Black;

				(* Adjust attributes of the following row if the row contained double height chars. *)
				IF (i < 23) & hasDouble THEN
					FOR j := 0 TO 39 DO
						fgColor [(i+1)*41 + j] := fgColor [i*41 + j];
						bgColor [(i+1)*41 + j] := bgColor [i*41 + j];
						(* Prevent that any characters on the second line will be visible *)
						IF text [(i+1)*41 + j] = 0 THEN
							text [(i+1)*41 + j] := 32
						END
					END
				END
			END;
			text[FormattedPageSize-1] := 0;

			teletextPage.text.AcquireWrite;
			teletextPage.text.InsertUCS32 (0, text);
			teletextPage.text.ReleaseWrite;

			(* Extract attributes and prepare them to be stored in compressed format *)
			fg := White;
			bg := Black;
			begin := 0;
			FOR i := 0 TO FormattedPageSize-1 DO
				(* Minimize amount of attributes:
					1. Span over multiple lines
					2. Consider only visible attributes
					=> reducing amount by approx. 70% *)
				IF (bgColor[i] # bg) & (i # begin) THEN
					(* New background: Apply last attributes *)
					fg := fgColor[i];
					bg := bgColor[i];
					begin := i
				ELSIF (fgColor[i] # fg) & (text[i] > 32) & (i # begin) THEN
					(* overwrite previous attribute if foreground was not visible. *)
					j := i;
					REPEAT
						DEC(j)
					UNTIL (j < begin) OR (text[j] > 32);
					INC(j);

					IF j > begin THEN
						FOR k := begin TO j-1 DO
							fgColor[k] := fg
						END;
						begin := j
					END;
					fg := fgColor[i]
				END
			END;
			(* Get compressed attributes *)
			FOR i := 0 TO FormattedPageSize-1 DO
				teletextPage.attributes[i] := CreateAttribute(fgColor[i], bgColor[i], flashing[i], boxed[i])
			END;
			(* Write caching time *)
			vbi.currentSuite.channel.cachingTime := Dates.Now()
		END MarkupPage;

		(* Process double height content. Stretch graphic characters to double height. Characters: Underline on the succeeding row..
			The result will be stored in current and succeeding line *)
		PROCEDURE DoubleHeight (VAR txt : ARRAY OF SIGNED32; pos : SIGNED32);
		VAR
			c : SIGNED32;
		BEGIN
			c := txt [pos];
			IF ((c >= 57344) & (c < 57376)) OR ((c >= 57408) & (c < 57440)) THEN
				(* Graphic symbol: Stretch upper part *)
				CASE ((c-57184) MOD 16) OF
						0 : txt [pos] := 57344
					|   1 : txt [pos] := 57349
					|   2 : txt [pos] := 57354
					|   3 : txt [pos] := 57359
					|   4 : txt [pos] := 57360
					|   5 : txt [pos] := 57365
					|   6 : txt [pos] := 57370
					|   7 : txt [pos] := 57375
					|   8 : txt [pos] := 57408
					|   9 : txt [pos] := 57413
					| 10 : txt [pos] := 57418
					| 11 : txt [pos] := 57423
					| 12 : txt [pos] := 57424
					| 13 : txt [pos] := 57429
					| 14 : txt [pos] := 57434
					| 15 : txt [pos] := 57439
				END;

				(* Process lower part on succeeding row; Return if no space available *)
				IF pos+41 >= FormattedPageSize THEN
					RETURN
				END;

				(* Write lower part of the graphics to the succeeding line *)
				CASE ((c-57184) DIV 4) OF
					  40 : txt [pos+41] := 57344
					| 41 : txt [pos+41] := 57345
					| 42 : txt [pos+41] := 57346
					| 43 : txt [pos+41] := 57347
					| 44 : txt [pos+41] := 57364
					| 45 : txt [pos+41] := 57365
					| 46 : txt [pos+41] := 57366
					| 47 : txt [pos+41] := 57367

					| 56 : txt [pos+41] := 57416
					| 57 : txt [pos+41] := 57417
					| 58 : txt [pos+41] := 57418
					| 59 : txt [pos+41] := 57419
					| 60 : txt [pos+41] := 57436
					| 61 : txt [pos+41] := 57437
					| 62 : txt [pos+41] := 57438
					| 63 : txt [pos+41] := 57439
				END

			ELSIF pos+41 < FormattedPageSize THEN
				(* process non-graphic characters *)
				CASE c OF
					  10 : (* Newline character: Do nothing *)
					| 32 : txt [pos+41] := 32
				ELSE
					(* Emulate double height characters by underlining the first row *)
					txt [pos+41] := 57347
				END
			END
		END DoubleHeight;

	END PageBuffer;

	VbiDecoder* = OBJECT
	VAR
		vcd : TVDriver.VideoCaptureDevice;
		tuner : TVDriver.TVTuner;
		vbiBuffer : TVDriver.VbiBuffer;
		chName- : ARRAY 17 OF CHAR;
		extractName* : BOOLEAN;
		dead : BOOLEAN;
		parallel: BOOLEAN;
		off, thresh : SIGNED32;
		line, spos : SIGNED32;
		buffers: ARRAY 8 OF PageBuffer;
		freq : FLOAT32;
		vtstep, vcstep, vpsstep : SIGNED32;
		norm : SIGNED32;
		currentSuite : TeletextSuite;

		PROCEDURE &Init*(vcd : TVDriver.VideoCaptureDevice);
		VAR
			i : SIGNED32;
			tuner : TVDriver.TVTuner;
		BEGIN
			IF vcd = NIL THEN
				KernelLog.String("{TeletextDecoder.Init} Parameter vcd = NIL. Aborting.");
				KernelLog.Ln;
				RETURN
			END;
			vbiBuffer := vcd.GetVbiBuffer();
			tuner := vcd.GetTuner();
			currentSuite := SelectTeletextSuite(tuner.GetFrequency());
			extractName := FALSE;
			SetFreq(0, 0);
			FOR i := 0 TO 7 DO
				NEW(buffers[i], SELF)
			END;
			dead := FALSE
		END Init;

		(** Get the TV channel that currently being cached *)
		PROCEDURE GetChannel*(): TVChannels.TVChannel;
		BEGIN
			RETURN currentSuite.channel
		END GetChannel;

		(** Get the amount of pages in the current teletext suite *)
		PROCEDURE Count*(): SIGNED32;
		BEGIN
			RETURN currentSuite.Count()
		END Count;

		(** Reset the ringbuffer with raw data, the channel name and all page buffers *)
		PROCEDURE ResetAll*;
		VAR
			i : SIGNED32;
		BEGIN
			vbiBuffer.readPos := vbiBuffer.insertPos;
			vbiBuffer.vbiSize := 0;
			FOR i := 0 TO 7 DO
				buffers[i].discardPage := TRUE
			END;
			chName := ""
		END ResetAll;

		(** Stop teletext capturing *)
		PROCEDURE Stop*;
		BEGIN {EXCLUSIVE}
			dead := TRUE
		END Stop;

		(** Channel switch: Redirect teletext output to the appropriate TeletextSuite *)
		PROCEDURE SetFrequency*(freq : SIGNED32);
		BEGIN
			currentSuite := SelectTeletextSuite(freq);
			ResetAll
		END SetFrequency;

		(* unham 2 bytes into 1, auto-correct 1 bit errors, report 2 bit errors by returning FALSE *)
		PROCEDURE UnHam(ch1, ch2 : CHAR; VAR error: BOOLEAN) : CHAR;
		VAR
			v1, v2: SIGNED32;
		BEGIN
			v1 := unHamTab [ORD (ch1)];
			v2 := unHamTab [ORD (ch2)];

			IF (v1 = -1) OR (v2 = -1) THEN
				IF DEBUG THEN
					KernelLog.String("{ TeletextDecoder } Bad Hamming Code!"); KernelLog.Ln;
				END;
				error := TRUE;
				RETURN 0FFX
			ELSE
				error := FALSE;
				RETURN CHR(16*v2 + v1)
			END
		END UnHam;

		(* Extract channel name from the first teletext line *)
		PROCEDURE ExtractChannelName (rawName : ARRAY OF CHAR; language: SIGNED32);
		VAR
			tmp: ARRAY 17 OF CHAR;
			i, j, begin, end: SIGNED32;
			done : BOOLEAN;

			PROCEDURE Is3Digits (pos: SIGNED32) : BOOLEAN;
			BEGIN
				IF pos > 14 THEN RETURN FALSE END;
				IF (rawName[pos] < '0') OR (rawName[pos] > '9') THEN RETURN FALSE END;
				IF (rawName[pos+1] < '0') OR (rawName[pos+1] > '9') THEN RETURN FALSE END;
				IF (rawName[pos+2] < '0') OR (rawName[pos+2] > '9') THEN RETURN FALSE END;
				IF (rawName[pos+3] > ' ') THEN RETURN FALSE END;
				RETURN TRUE
			END Is3Digits;

			PROCEDURE GetChar(ch: CHAR) : CHAR;
			VAR
				utf: SIGNED32;
			BEGIN
				CASE ORD(ch) OF
					  35 : utf := nationals [language][0]
				  |   36 : utf := nationals [language][1]
				  |   64 : utf := nationals [language][2]
				  |   91 : utf := nationals [language][3]
				  |   92 : utf := nationals [language][4]
				  |   93 : utf := nationals [language][5]
				  |   94 : utf := nationals [language][6]
				  |   95 : utf := nationals [language][7]
				  |   96 : utf := nationals [language][8]
				  | 123 : utf := nationals [language][9]
				  | 124 : utf := nationals [language][10]
				  | 125 : utf := nationals [language][11]
				  | 126 : utf := nationals [language][12]
				ELSE
					utf := ORD(ch)
				END;
				IF utf < 256 THEN
					RETURN CHR(utf)
				ELSE
					RETURN ch
				END;
			END GetChar;

		BEGIN
			(* Convert the channel name to uppercase and replace non-printable chars by whitespaces *)
			FOR i := 0 TO 15 DO
				IF ORD(rawName[i]) <= 32 THEN
					tmp[i] := ' '
				ELSE
					tmp[i] := rawName[i]
				END
			END;

			(* Search for a 3-digit page number, possibly preceeded by a 'P' *)
			i := 0;
			REPEAT
				done := TRUE;
				IF Is3Digits (i) THEN
					begin := i;
					end := i + 3
				ELSIF ((tmp[i] = 'P') OR (tmp[i] = 'p')) & Is3Digits (i+1) THEN
					begin := i;
					end := i + 4
				ELSE
					done := FALSE
				END;

				(* If number is not found, search for the next word *)
				IF ~done THEN
					REPEAT
						INC (i)
					UNTIL (i >= 14) OR (rawName[i] = ' ');
					INC (i)
				END
			UNTIL done OR (i >= 14);

			(* Cut out page number, if possible *)
			IF done THEN
				IF begin < 3 THEN
					WHILE (end < 16) & (tmp[end] = ' ') DO
						INC(end)
					END;
					i := 15;
					WHILE (i >= 0) & (tmp[i] # ' ') DO
						DEC (i)
					END;
					(* set index back if channel name fills the whole string *)
					IF i < end THEN
						i := 15
					END;
					FOR j := end TO i DO
						(* Handle language-specific characters *)
						CASE ORD(rawName[j]) OF
							 35,36,64,91,92,93,94,95,96,123,124,125,126: chName[j-end] := GetChar(rawName[j])
						ELSE
							chName[j-end] := tmp[j]
						END
					END;
					chName[i-end+1] := 0X
				ELSE
					i := 0;
					WHILE tmp[i] = ' ' DO
						INC(i)
					END;
					FOR j := i TO begin-1 DO
						(* Handle language-specific characters *)
						CASE ORD(rawName[j]) OF
							 35,36,64,91,92,93,94,95,96,123,124,125,126: chName[j-end] := GetChar(rawName[j])
						ELSE
							chName[j-i] := tmp[j]
						END
					END;
					chName[begin] := 0X
				END
			END;
			Strings.Trim(chName, ' ');
			UTF8Strings.ASCIItoUTF8(chName, chName)
		END ExtractChannelName;

		(* decode data in teletext-like packages *)
		PROCEDURE DecodeVt(dat : ARRAY OF CHAR);
		VAR
			magPack, mag, pack : SIGNED32;
			pg : CHAR;
			page, subPage, pTen, pUnit, designationCode, pageFunction, pageCoding : SIGNED32;
			sub1, sub2 : SIGNED32;
			chName : ARRAY 17 OF CHAR;
			i, flg : SIGNED32;
			flags, bits : SET;
			error: BOOLEAN;
		BEGIN
			(* Extract Hamming-protected magazine and packet number *)
			magPack := ORD(UnHam(dat[3], dat[4], error));
			IF error THEN
				RETURN
			END;
			mag := magPack MOD 8;
			pack := magPack DIV 8;

			IF pack = 0 THEN
				(* Header packet received. Extract (sub)page number and flags *)
				pg := UnHam(dat[5], dat[6], error);
				IF error THEN
					IF DEBUG THEN
						KernelLog.String("Hamming error on page "); KernelLog.Int(buffers[mag].pageNo, 0)
					END;
					buffers[mag].discardPage := TRUE;
					RETURN
				END;
				pTen := ORD(pg) DIV 16;
				pUnit := ORD (pg) MOD 16;
				page := mag*100 + pTen*10 + pUnit;
				(* mag = 0 corresponds to mag = 800 *)
				IF page < 100 THEN
					page := page + 800
				END;

				(* Terminate the last received page if the transmission is completed *)
				IF (page # buffers[mag].pageNo) THEN
					IF ~buffers[mag].discardPage THEN
						buffers[mag].MarkupPage
					END;
					buffers[mag].Reset(page, subPage)
				END;

				(* Discard Pages with hexadecimal elements in the number *)
				IF (pg = 0FFX) OR (pTen > 9) OR (pUnit > 9) THEN
					buffers[mag].discardPage := TRUE;
					RETURN
				END;

				(* If the page number is valid, proceed with data extraction *)
				IF pg # 0FFX THEN
					(* sub1 contains subpage bits and Control bit C4 *)
					sub1 := ORD(UnHam(dat[7], dat[8], error));
					IF error THEN
						IF DEBUG THEN
							KernelLog.String("Hamming Error on page "); KernelLog.Int(page, 0); KernelLog.Ln
						END;
						buffers[mag].discardPage := TRUE;
						RETURN
					END;
					(* sub2 contains further subpage bits and Control bits C5 and C6 *)
					sub2 := ORD(UnHam(dat[9], dat[10], error));
					IF error THEN
						IF DEBUG THEN
							KernelLog.String("Hamming Error on page "); KernelLog.Int(page, 0)
						END;
						buffers[mag].discardPage := TRUE;
						RETURN
					END;

					(* Calculate the subpage number (mask out control bits) *)
					subPage := 256*(sub2 MOD 64) + (sub1 MOD 128);

					(* Extract page Flags *)
					IF sub1 > 128 THEN
						(* C4: Erase Page *)
						buffers[mag].Reset (page, subPage);
					END;

					IF (sub2 MOD 128) > 64 THEN
						(* C5: Newsflash *)
						buffers[mag].boxedContent := TRUE
					END;

					IF sub2 > 128 THEN
						(* C6: Subtitle *)
						buffers[mag].boxedContent := TRUE
					END;

					(* Important Control bits C7-C14 *)
					flg := ORD(UnHam(dat[11], dat[12], error));
					IF error THEN
						IF DEBUG THEN
							KernelLog.String("Hamming Error on page "); KernelLog.Int(page, 0); KernelLog.Ln
						END;
						buffers[mag].discardPage := TRUE;
						RETURN
					END;
					flags := SYSTEM.VAL(SET, flags);
					IF 0 IN flags THEN
						(* C7: Suppress Header *)
						buffers[mag].suppressHeader := TRUE
					END;
					IF 3 IN flags THEN
						(* C10: Inhibit Display *)
						KernelLog.String("Inhibit Display... Discarding Page"); KernelLog.Ln;
						buffers[mag].discardPage := TRUE
					END;
					IF ~ (4 IN flags) THEN
						(* C11: Magazine Serial *)
						parallel := TRUE
					END;

					(* Extract the language *)
					buffers[mag].language := flg DIV 32;
					IF DEBUG THEN
						CASE buffers[mag].language OF
							 0: KernelLog.String("    Language: English")
						|	1: KernelLog.String("    Language: French")
						|	2: KernelLog.String("    Language: Swedish/Finnish/Hungarian")
						|	3: KernelLog.String("    Language: Czech/Slovak")
						|	4: KernelLog.String("    Language: German")
						|	5: KernelLog.String("    Language: Portuguese/Spanish")
						|	6: KernelLog.String("    Language: Italian")
						|	7: KernelLog.String("    Language: <Undefined>")
						END;
						KernelLog.Ln
					END;

					(* Copy the page header into the page buffer *)
					IF (~ buffers[mag].suppressHeader) & (~ buffers[mag].discardPage) THEN
						FOR i := 0 TO 39 DO
							buffers[mag].data[i] := dat[i+5]
						END
					END;
					buffers[mag].lastPacket := 0;
					buffers[mag].packets := buffers[mag].packets + {0};

					(* Extract channel name from first line *)
					IF extractName THEN
						FOR i := 0 TO 15 DO
							chName[i] := CHR(ORD(dat[i+13]) MOD 128)
						END;
						ExtractChannelName (chName, flg DIV 32)
					END
				END
			ELSIF (1 <= pack) & (pack < 24) THEN
				(* Error detection: Only increasing package numbers allowed. Avoid duplicate packages *)
				IF (pack <= buffers[mag].lastPacket) OR (pack IN buffers[mag].packets) THEN
					buffers[mag].discardPage := TRUE
				ELSE
					buffers[mag].lastPacket := pack;
					buffers[mag].packets := buffers[mag].packets + {pack}
				END;
				(* Copy the teletext line into the page buffer *)
				IF ~ buffers[mag].discardPage THEN
					FOR i := 0 TO 39 DO
						buffers[mag].data[pack*40 + i] := dat[i+5]
					END
				END
			ELSIF pack <= 25 THEN
				(* TOP/Fastext: To be done *)
			ELSIF pack = 28 THEN
				(* Page function / coding definition *)
				designationCode := unHamTab [ORD (dat[5])];
				(* Designation code > 0 is only for Teletext Levels > 1.0 *)
				IF designationCode = -1 THEN
					(* Unrecoverable hamming error *)
					(* packet 28 might have lead to discard page => be conservative *)
					buffers[mag].discardPage := TRUE
				ELSIF designationCode = 0 THEN
					(* Extract hamming 24/18 protected page function *)
					bits := SYSTEM.VAL(SET, dat[6]);
					pageFunction := 0;
					IF 2 IN bits THEN INC(pageFunction, 1) END;
					IF 4 IN bits THEN INC(pageFunction, 2) END;
					IF 5 IN bits THEN INC(pageFunction, 4) END;
					IF 6 IN bits THEN INC(pageFunction, 8) END;
					IF pageFunction # 0 THEN
						(* Page is not intended for display (contains object or color definitions) *)
						buffers[mag].discardPage := TRUE
					END;
					pageCoding := ORD(dat[7]) MOD 8;
					IF pageCoding # 0 THEN
						(* Not ODD parity coded => not intended for display *)
						buffers[mag].discardPage := TRUE
					END
				END
			ELSIF (26 <= pack) & (pack <= 29) THEN
				(* VPS/PDC *)
			ELSIF pack = 31 THEN
				(* Intercast *)
			END
		END DecodeVt;

		PROCEDURE SetFreq(f : FLOAT32; n : SIGNED32);
		VAR
			vtfreq : FLOAT32;
			vpsfreq : FLOAT32;
			vcfreq : FLOAT32;
		BEGIN
			IF norm # 0 THEN
				vtfreq := 5.72725
			ELSE
				vtfreq := 6.9375
			END;

			vpsfreq := 5;
			vcfreq := 0.77;
			norm := n;

			(* if no frequency given, use standard ones for Bt848 an PAL/NTSC *)
			IF f = 0 THEN
				IF norm # 0 THEN
					freq := 28.636363
				ELSE
					freq := 35.468950
				END
			ELSE
				freq := f
			END;

			vtstep := ENTIER((freq/vtfreq)*FpFac + 0.5);
			(* VPS is shift encoded, so just sample first "state" *)
			vpsstep := 2*ENTIER((freq/vtfreq)*FpFac + 0.5);
			vcstep := ENTIER((freq/vcfreq)*FpFac + 0.5)
		END SetFreq;

		(* primitive automatic gain control to determine the right slicing offset *)
		(*it should suffice to do this once per channel change *)
		PROCEDURE AGC(pos, start, stop, step : SIGNED32);
		VAR
			i : SIGNED32;
			min, max : SIGNED32;
		BEGIN
			min := 255;
			max := 0;
			i := start;
			WHILE i < stop DO
				IF ORD(vbiBuffer.data[pos + i]) < min THEN
					min := ORD(vbiBuffer.data[pos + i])
				END;
				IF ORD(vbiBuffer.data[pos + i]) > max THEN
					max := ORD(vbiBuffer.data[pos + i])
				END;
				i := i + step
			END;

			thresh := (min + max) DIV 2;
			off := 128 - thresh
		END AGC;

		PROCEDURE Scan(step, pos : SIGNED32) : CHAR;
		VAR
			dat : SET;
			j, ord : SIGNED32;
		BEGIN
			dat := {};
			FOR j := 7 TO 0 BY -1 DO
				ord := ORD(vbiBuffer.data[pos + (spos DIV FpFac)]) + off;
				IF (ord >= 128) & (ord < 256) THEN
					dat := dat + { (7-j) }
				END;
				spos := spos + step
			END;
			RETURN SYSTEM.VAL(CHAR, dat)
		END Scan;

		(** Search for teletext packages and decode them if found *)
		PROCEDURE DecodeLine(pos : SIGNED32);
		VAR
			i, p : SIGNED32;
			data : ARRAY 45 OF CHAR;
		BEGIN
			AGC(pos, 120, 450, 1);

			(* search for first 1 bit (VT always starts with 55X 55X 27X !!! *)
			p := 50;
			WHILE (vbiBuffer.data[pos + p] < CHR(thresh)) & (p < 350) DO
				INC(p)
			END;
			spos := p*FpFac + vtstep DIV 2;

			(* ignore first bit for now *)
			data[0] := Scan(vtstep, pos);

			IF (ORD(data[0]) DIV 2) = 42 THEN
				data[1] := Scan(vtstep, pos);
				IF data[1] = 0D5X THEN
					(* oops, missed first 1-bit: backup 2 bits *)
					spos := spos - 2*vtstep;
					data[1] := 55X
				END;
				IF data[1] = 55X THEN
					data[2] := Scan(vtstep, pos);
					IF data[2] = 0D8X THEN
						(* this shows up on some channels!?!?! *)
						FOR i := 3 TO 44 DO
							data[i] := CHR(ORD(Scan(vtstep, pos)) MOD 128)
						END;
						RETURN
					ELSIF data[2] =27X THEN
						FOR i := 3 TO 44 DO
							data[i] := CHR(ORD(Scan(vtstep, pos)) MOD 128)
						END;
						DecodeVt(data);
						RETURN
					END
				END
			END
		END DecodeLine;

		PROCEDURE Decode;
		VAR
			readPos, curPos : SIGNED32;
		BEGIN
			readPos := vbiBuffer.readPos;
			IF vbiBuffer.vbiSize >= VbiDataSize THEN
				FOR line := 0 TO 2*VbiLines-1 DO
					curPos := readPos + line*VbiLineSize;
					DecodeLine(curPos)
				END
			END
		END Decode;


	BEGIN {ACTIVE}
		(* Wait until the initial teletext suite is selected *)
		WHILE currentSuite = NIL DO
		END;
		IF vbiBuffer = NIL THEN
			KernelLog.String("{TeletextDecoder} vbiBuffer is NIL!"); KernelLog.Ln
		ELSE
			KernelLog.String("{TeletextDecoder} Decoding started"); KernelLog.Ln;
			dead := FALSE;
			REPEAT
				vbiBuffer.AwaitData;
				(* AwaitData return after a 30sec. timeout. Decode only after non-timeouts *)
				IF vbiBuffer.vbiSize > 0 THEN
					Decode();
					vbiBuffer.readPos := (vbiBuffer.readPos + VbiDataSize) MOD VbiBufferSize;
					vbiBuffer.vbiSize := vbiBuffer.vbiSize - VbiDataSize
				END
			UNTIL dead
		END;
		KernelLog.String("{TeletextDecoder} Decoding stopped"); KernelLog.Ln
	END VbiDecoder;


VAR
	(** Linked list that contains the teletext pages for each channel *)
	teletextSuites*: TeletextSuite;

	(* Hamming table for fast decoding *)
	unHamTab : ARRAY 256 OF SIGNED32;

	(* Latin national option character subset *)
	nationals : ARRAY 8 OF ARRAY 13 OF SIGNED32;

	PROCEDURE BuildTeletextSuites;
	VAR
		i: SIZE;
		suite: TeletextSuite;
	BEGIN
		teletextSuites := NIL;
		FOR i := TVChannels.channels.GetCount()-1 TO 0 BY -1 DO
			NEW(suite);
			suite.channel := TVChannels.channels.GetItem(i);
			suite.next := teletextSuites;
			teletextSuites := suite
		END
	END BuildTeletextSuites;

	(** Select teletext suite according to the given TV frequency *)
	PROCEDURE SelectTeletextSuite* (freq: SIGNED32): TeletextSuite;
	VAR
		suite: TeletextSuite;
	BEGIN
		(* traverse the list of teletext suites and find the correct one according to the TV frequency *)
		(* Tolerance for the frequency is +/- 10 *)
		suite := teletextSuites;
		WHILE (suite # NIL) & ((suite.channel.freq-10 > freq) OR (suite.channel.freq+10 < freq)) DO
			suite := suite.next
		END;
		IF (suite = NIL) & DEBUG THEN
			KernelLog.String("{TeletextDecoder} SelectTeletextSuite: Suite = NIL"); KernelLog.Ln
		END;
		RETURN suite
	END SelectTeletextSuite;

	(* Initialize the table for hamming 8/4 decoding *)
	PROCEDURE InitUnhamTab;
	BEGIN
		unHamTab [0] := -1;	unHamTab [1] := -1;	unHamTab [2] := 1;	unHamTab [3] := 1;
		unHamTab [4] := -1;	unHamTab [5] := 0;	unHamTab [6] := 1;	unHamTab [7] := -1;
		unHamTab [8] := -1;	unHamTab [9] := 2;	unHamTab [10] := 1;	unHamTab [11] := -1;
		unHamTab [12] := 10;	unHamTab [13] := -1;	unHamTab [14] := -1;	unHamTab [15] := 7;
		unHamTab [16] := -1;	unHamTab [17] := 0;	unHamTab [18] := 1;	unHamTab [19] := -1;
		unHamTab [20] := 0;	unHamTab [21] := 0;	unHamTab [22] := -1;	unHamTab [23] := -1;
		unHamTab [24] := 6;	unHamTab [25] := -1;	unHamTab [26] := -1;	unHamTab [27] := 11;
		unHamTab [28] := -1;	unHamTab [29] := 0;	unHamTab [30] := 3;	unHamTab [31] := -1;
		unHamTab [32] := -1;	unHamTab [33] := 12;	unHamTab [34] := 1;	unHamTab [35] := -1;
		unHamTab [36] := 4;	unHamTab [37] := -1;	unHamTab [38] := -1;	unHamTab [39] := 7;
		unHamTab [40] := 6;	unHamTab [41] := -1;	unHamTab [42] := -1;	unHamTab [43] := 7;
		unHamTab [44] := -1;	unHamTab [45] := -1;	unHamTab [46] := 7;	unHamTab [47] := 7;
		unHamTab [48] := 6;	unHamTab [49] := -1;	unHamTab [50] := -1;	unHamTab [51] := 5;
		unHamTab [52] := -1;	unHamTab [53] := 0;	unHamTab [54] := 13;	unHamTab [55] := -1;
		unHamTab [56] := 6;	unHamTab [57] := 6;	unHamTab [58] := -1;	unHamTab [59] := -1;
		unHamTab [60] := 6;	unHamTab [61] := -1;	unHamTab [62] := -1;	unHamTab [63] := 7;
		unHamTab [64] := -1;	unHamTab [65] := 2;	unHamTab [66] := 1;	unHamTab [67] := -1;
		unHamTab [68] := 4;	unHamTab [69] := -1;	unHamTab [70] := -1;	unHamTab [71] := 9;
		unHamTab [72] := 2;	unHamTab [73] := 2;	unHamTab [74] := -1;	unHamTab [75] := -1;
		unHamTab [76] := -1;	unHamTab [77] := 2;	unHamTab [78] := 3;	unHamTab [79] := -1;
		unHamTab [80] := 8;	unHamTab [81] := -1;	unHamTab [82] := -1;	unHamTab [83] := 5;
		unHamTab [84] := -1;	unHamTab [85] := 0;	unHamTab [86] := 3;	unHamTab [87] := -1;
		unHamTab [88] := -1;	unHamTab [89] := 2;	unHamTab [90] := 3;	unHamTab [91] := -1;
		unHamTab [92] := -1;	unHamTab [93] := -1;	unHamTab [94] := 3;	unHamTab [95] := 3;
		unHamTab [96] := 4;	unHamTab [97] := -1;	unHamTab [98] := -1;	unHamTab [99] := 5;
		unHamTab [100] := 4;	unHamTab [101] := 4;	unHamTab [102] := -1;	unHamTab [103] := -1;
		unHamTab [104] := -1;	unHamTab [105] := 2;	unHamTab [106] := 15;	unHamTab [107] := -1;
		unHamTab [108] := 4;	unHamTab [109] := -1;	unHamTab [110] := -1;	unHamTab [111] := 7;
		unHamTab [112] := -1;	unHamTab [113] := -1;	unHamTab [114] := 5;	unHamTab [115] := 5;
		unHamTab [116] := 4;	unHamTab [117] := -1;	unHamTab [118] := -1;	unHamTab [119] := 5;
		unHamTab [120] := 6;	unHamTab [121] := -1;	unHamTab [122] := -1;	unHamTab [123] := 5;
		unHamTab [124] := -1;	unHamTab [125] := 14;	unHamTab [126] := 3;	unHamTab [127] := -1;
		unHamTab [128] := -1;	unHamTab [129] := 12;	unHamTab [130] := 1;	unHamTab [131] := -1;
		unHamTab [132] := 10;	unHamTab [133] := -1;	unHamTab [134] := -1;	unHamTab [135] := 9;
		unHamTab [136] := 10;	unHamTab [137] := -1;	unHamTab [138] := -1;	unHamTab [139] := 11;
		unHamTab [140] := 10;	unHamTab [141] := 10;	unHamTab [142] := -1;	unHamTab [143] := -1;
		unHamTab [144] := 8;	unHamTab [145] := -1;	unHamTab [146] := -1;	unHamTab [147] := 11;
		unHamTab [148] := -1;	unHamTab [149] := 0;	unHamTab [150] := 13;	unHamTab [151] := -1;
		unHamTab [152] := -1;	unHamTab [153] := -1;	unHamTab [154] := 11;	unHamTab [155] := 11;
		unHamTab [156] := 10;	unHamTab [157] := -1;	unHamTab [158] := -1;	unHamTab [159] := 11;
		unHamTab [160] := 12;	unHamTab [161] := 12;	unHamTab [162] := -1;	unHamTab [163] := -1;
		unHamTab [164] := -1;	unHamTab [165] := 12;	unHamTab [166] := 13;	unHamTab [167] := -1;
		unHamTab [168] := -1;	unHamTab [169] := 12;	unHamTab [170] := 15;	unHamTab [171] := -1;
		unHamTab [172] := 10;	unHamTab [173] := -1;	unHamTab [174] := -1;	unHamTab [175] := 7;
		unHamTab [176] := -1;	unHamTab [177] := 12;	unHamTab [178] := 13;	unHamTab [179] := -1;
		unHamTab [180] := -1;	unHamTab [181] := -1;	unHamTab [182] := 13;	unHamTab [183] := 13;
		unHamTab [184] := 6;	unHamTab [185] := -1;	unHamTab [186] := -1;	unHamTab [187] := 11;
		unHamTab [188] := -1;	unHamTab [189] := 14;	unHamTab [190] := 13;	unHamTab [191] := -1;
		unHamTab [192] := 8;	unHamTab [193] := -1;	unHamTab [194] := -1;	unHamTab [195] := 9;
		unHamTab [196] := -1;	unHamTab [197] := -1;	unHamTab [198] := 9;	unHamTab [199] := 9;
		unHamTab [200] := -1;	unHamTab [201] := 2;	unHamTab [202] := 15;	unHamTab [203] := -1;
		unHamTab [204] := 10;	unHamTab [205] := -1;	unHamTab [206] := -1;	unHamTab [207] := 9;
		unHamTab [208] := 8;	unHamTab [209] := 8;	unHamTab [210] := -1;	unHamTab [211] := -1;
		unHamTab [212] := 8;	unHamTab [213] := -1;	unHamTab [214] := -1;	unHamTab [215] := 9;
		unHamTab [216] := 8;	unHamTab [217] := -1;	unHamTab [218] := -1;	unHamTab [219] := 11;
		unHamTab [220] := -1;	unHamTab [221] := 14;	unHamTab [222] := 3;	unHamTab [223] := -1;
		unHamTab [224] := -1;	unHamTab [225] := 12;	unHamTab [226] := 15;	unHamTab [227] := -1;
		unHamTab [228] := 4;	unHamTab [229] := -1;	unHamTab [230] := -1;	unHamTab [231] := 9;
		unHamTab [232] := -1;	unHamTab [233] := -1;	unHamTab [234] := 15;	unHamTab [235] := 15;
		unHamTab [236] := -1;	unHamTab [237] := 14;	unHamTab [238] := 15;	unHamTab [239] := -1;
		unHamTab [240] := 8;	unHamTab [241] := -1;	unHamTab [242] := -1;	unHamTab [243] := 5;
		unHamTab [244] := -1;	unHamTab [245] := 14;	unHamTab [246] := 13;	unHamTab [247] := -1;
		unHamTab [248] := -1;	unHamTab [249] := 14;	unHamTab [250] := 15;	unHamTab [251] := -1;
		unHamTab [252] := 14;	unHamTab [253] := 14;	unHamTab [254] := -1;	unHamTab [255] := -1;
	END InitUnhamTab;

	(** Unicode positions of the national special characters *)
	PROCEDURE InitNationals;
	BEGIN
		(* English *)
		nationals[0][0] := 163; nationals[0][1] := 36; nationals[0][2] := 64; nationals[0][3] := 8592;
		nationals[0][4] := 189; nationals[0][5] := 8594; nationals[0][6] := 8593; nationals[0][7] := 35;
		nationals[0][8] := 45; nationals[0][9] := 188; nationals[0][10] := 8741; nationals[0][11] := 190;
		nationals[0][12] := 247;
		(* French *)
		nationals[1][0] := 233; nationals[1][1] := 239; nationals[1][2] := 224; nationals[1][3] := 235;
		nationals[1][4] := 234; nationals[1][5] := 249; nationals[1][6] := 238; nationals[1][7] := 35;
		nationals[1][8] := 232; nationals[1][9] := 226; nationals[1][10] := 244; nationals[1][11] := 251;
		nationals[1][12] := 231;
		(* Swedish/Finnish/Hungarian *)
		nationals[2][0] := 35; nationals[2][1] := 164; nationals[2][2] := 201; nationals[2][3] := 196;
		nationals[2][4] := 214; nationals[2][5] := 197; nationals[2][6] := 220; nationals[2][7] := 239;
		nationals[2][8] := 233; nationals[2][9] := 228; nationals[2][10] := 246; nationals[2][11] := 229;
		nationals[2][12] := 252;
		(* Czech/Slovak *)
		nationals[3][0] := 35; nationals[3][1] := 367; nationals[3][2] := 269; nationals[3][3] := 357;
		nationals[3][4] := 382; nationals[3][5] := 253; nationals[3][6] := 237; nationals[3][7] := 345;
		nationals[3][8] := 233; nationals[3][9] := 225; nationals[3][10] := 277; nationals[3][11] := 250;
		nationals[3][12] := 353;
		(* German *)
		nationals[4][0] := 35; nationals[4][1] := 36; nationals[4][2] := 167; nationals[4][3] := 196;
		nationals[4][4] := 214; nationals[4][5] := 220; nationals[4][6] := 94; nationals[4][7] := 95;
		nationals[4][8] := 176; nationals[4][9] := 228; nationals[4][10] := 246; nationals[4][11] := 252;
		nationals[4][12] := 223;
		(* Portuguese/Spanish *)
		nationals[5][0] := 231; nationals[5][1] := 36; nationals[5][2] := 161; nationals[5][3] := 225;
		nationals[5][4] := 233; nationals[5][5] := 237; nationals[5][6] := 243; nationals[5][7] := 250;
		nationals[5][8] := 191; nationals[5][9] := 252; nationals[5][10] := 241; nationals[5][11] := 232;
		nationals[5][12] := 224;
		(* Italian *)
		nationals[6][0] := 163; nationals[6][1] := 36; nationals[6][2] := 233; nationals[6][3] := 176;
		nationals[6][4] := 231; nationals[6][5] := 8594; nationals[6][6] := 8593; nationals[6][7] := 35;
		nationals[6][8] := 249; nationals[6][9] := 224; nationals[6][10] := 242; nationals[6][11] := 232;
		nationals[6][12] := 236;
		(* Default *)
		nationals[7][0] := 35; nationals[7][1] := 164; nationals[7][2] := 64; nationals[7][3] := 91;
		nationals[7][4] := 92; nationals[7][5] := 93; nationals[7][6] := 94; nationals[7][7] := 95;
		nationals[7][8] := 96; nationals[7][9] := 123; nationals[7][10] := 166; nationals[7][11] := 125;
		nationals[7][12] := 126;
	END InitNationals;

BEGIN
	IF TVChannels.channels.GetCount() # 0 THEN
		BuildTeletextSuites
	ELSE
		KernelLog.String("{TeletextDecoder} No channels found");
		KernelLog.Ln
	END;
	InitUnhamTab;
	InitNationals
END TeletextDecoder.
