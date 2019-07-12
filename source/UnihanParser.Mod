MODULE UnihanParser;	(** AUTHOR "tf"; PURPOSE "Parse unihan database of unicode.org"; *)
(* the file Unihan.txt is not included in the release since it should be downloaded directly from
unicode.org

 *)
IMPORT
	Streams, Files, Strings, UTF8Strings, TextUtilities, KernelLog;

CONST
	MaxCode = 200000;

TYPE
	String = Strings.String;
	Character* = OBJECT
	VAR
		radical*, tradvariant*, simpvariant*,
		additionalstrokes*, totalstrokes*, freq*, xfreq* : LONGINT;
		mandarin*, pinyin*, cantonese*, korean*, definition* : String;
	END Character;

TYPE (* generic sortable list *)
	ListElement = POINTER TO RECORD
		next : ListElement;
	END;

	(* return -1, if a < b; 0, if a = b; 1, if a > b *)
	CompareProc = PROCEDURE {DELEGATE} (a, b : ListElement) : LONGINT;

TYPE
	PIMEEntry = POINTER TO RECORD(ListElement)
		pinyin : ARRAY 8 OF CHAR;
		ucs : LONGINT;
		freq : LONGINT;
	END;


VAR
	codeArray : POINTER TO ARRAY OF Character;
	nofLines : LONGINT;
	tok : ARRAY 32 OF CHAR;
	data : ARRAY 256 OF CHAR;
	cap : ARRAY 256 OF CHAR; (* lookup for capital characters *)
	isNum : ARRAY 256 OF BOOLEAN;

PROCEDURE GetHex(r : Streams.Reader) : LONGINT;
VAR c : CHAR; res: LONGINT;
BEGIN
	res := 0;
	c := r.Get();
	WHILE (c >= "0") & (c <= "9") OR (CAP(c) >= "A") & (CAP(c) <= "F") DO
		IF (c >= "0") & (c <= "9") THEN res := res * 16 + (ORD(c)-ORD("0"))
		ELSE res := res * 16 + (ORD(CAP(c))-ORD("A") + 10)
		END;
		c := r.Get()
	END;
	RETURN res
END GetHex;

PROCEDURE HasCode*(code : LONGINT) : BOOLEAN;
BEGIN
	RETURN (code >= 0) & (code < MaxCode) & (codeArray[code] # NIL)
END HasCode;

(** If not existing, creates the character *)
PROCEDURE GetCharacter*(code : LONGINT) : Character;
BEGIN
	ASSERT( (code >= 0) & (code < MaxCode) );
	IF (codeArray[code] = NIL) THEN NEW(codeArray[code]) END;
	RETURN codeArray[code]
END GetCharacter;

PROCEDURE CountCharacters() : LONGINT;
VAR i, count : LONGINT;
BEGIN
	count := 0;
	FOR i := 0 TO MaxCode - 1 DO IF codeArray[i] # NIL THEN INC(count) END END;
	RETURN count
END CountCharacters;

PROCEDURE ParseLine(r: Streams.Reader);
VAR code : LONGINT; c : CHAR; char : Character;
BEGIN
	c := r.Get();
	IF c = "U" THEN
		r.SkipBytes(1);
		code := GetHex(r);
		char := GetCharacter(code);
		r.SkipWhitespace;
		r.Token(tok);
		r.SkipWhitespace;
		IF tok = "kDefinition" THEN
			r.Ln(data);
			char.definition := Strings.NewString(data)
		ELSIF tok = "kMandarin" THEN
			r.Ln(data);
			char.mandarin := Strings.NewString(data)
		ELSIF tok = "kFrequency" THEN
			(* r.SkipWhitespace; r.Int(char.freq, FALSE); r.SkipLn; *)
		ELSIF tok = "kCantonese" THEN
			r.Ln(data);
			char.cantonese := Strings.NewString(data)
		ELSIF tok = "kKorean" THEN
			r.Ln(data);
			char.korean := Strings.NewString(data)
		ELSIF tok = "kSimplifiedVariant" THEN
			r.Ln(data);
		ELSIF tok = "kTraditionalVariant" THEN
			r.Ln(data);
		ELSE r.SkipLn;
		END
	ELSE r.SkipLn;
	END;
	INC(nofLines);
	IF nofLines MOD 50000 = 0 THEN KernelLog.Int(nofLines, 5); KernelLog.String(" lines and counting..."); KernelLog.Ln END;
END ParseLine;

PROCEDURE AddRadicals;
VAR f : Files.File; r : Files.Reader;
	code, count : LONGINT; char : Character;
BEGIN
	f := Files.Old("Radicals.txt");
	IF f # NIL THEN
		KernelLog.String("Adding radical info..."); KernelLog.Ln;
		Files.OpenReader(r, f, 0);
		count := 0;
		WHILE r.res = 0 DO
			IF ~TextUtilities.GetUTF8Char(r, code) THEN HALT(1234) END; r.SkipWhitespace;
			char := GetCharacter(code);
			IF ~TextUtilities.GetUTF8Char(r, char.radical) THEN HALT(1234) END; r.SkipWhitespace;
			r.Ln(data);
			char.pinyin := Strings.NewString(data);
			INC(count)
		END;
		KernelLog.String("Radical info to "); KernelLog.Int(count, 4); KernelLog.String(" characters added."); KernelLog.Ln
	ELSE
		KernelLog.String("Could not find radicals.txt"); KernelLog.Ln
	END
END AddRadicals;

PROCEDURE AddFrequencies;
VAR f : Files.File; r : Files.Reader;
	code, count, i : LONGINT; char : Character;
BEGIN
	f := Files.Old("frequencies.txt");
	IF f # NIL THEN
		KernelLog.String("Adding frequency info..."); KernelLog.Ln;
		count := 0;
		Files.OpenReader(r, f, 0);
		(* input is sorted list of characters, most frequent on top *)
		WHILE r.res = 0 DO
			r.SkipLn; INC(count)
		END;

		Files.OpenReader(r, f, 0);
		i := 0;
		WHILE r.res = 0 DO
			IF ~TextUtilities.GetUTF8Char(r, code) THEN HALT(1234) END; r.SkipWhitespace;
			char := GetCharacter(code);
			char.xfreq := ENTIER(99 * i / count) + 1;
			r.SkipLn;
			INC(i)
		END;

		(* rescale the unicode frequencies to frequency numbers found above *)
		FOR i := 0 TO MaxCode - 1 DO
			IF codeArray[i] # NIL THEN
				IF (codeArray[i].xfreq = 0) & (codeArray[i].freq # 0) THEN
					codeArray[i].xfreq := (codeArray[i].freq - 1) * 20
				END
			END
		END;


		KernelLog.String("Frequency info added to "); KernelLog.Int(count, 4); KernelLog.String(" characters."); KernelLog.Ln
	ELSE
		KernelLog.String("Could not find frequencies.txt"); KernelLog.Ln
	END
END AddFrequencies;

PROCEDURE ParseFile*;
VAR f : Files.File; r : Files.Reader;
BEGIN
	f := Files.Old("Unihan.txt");
	IF f # NIL THEN
		Files.OpenReader(r, f, 0);
		WHILE r.res = 0 DO ParseLine(r) END;
		KernelLog.Int(nofLines, 5); KernelLog.String(" lines processed."); KernelLog.Ln;
		KernelLog.Int(CountCharacters(), 5); KernelLog.String(" unique characters"); KernelLog.Ln;
		AddRadicals;
		AddFrequencies
	ELSE KernelLog.String("Unihan.txt not found"); KernelLog.Ln
	END;
END ParseFile;

(** Merge-sort a single-linked list. The root element is a dummy node *)
(* Algorithm by Simon Tatham *)
PROCEDURE Sort(root: ListElement; compare : CompareProc);	(* root is dummy node *)
VAR m, n, np, nq: LONGINT; p, q, tail: ListElement;
BEGIN
	n := 1;
	REPEAT
		p := root.next; q := p; tail := root; m := 0;
		WHILE p # NIL DO	(* merge sorted lists of length n into sorted lists of length 2*n (sort of) *)
			np := 0;	(* step q over <= n nodes *)
			REPEAT q := q.next; INC(np) UNTIL (q = NIL) OR (np = n);
			nq := n; INC(m);
			LOOP	(* merge list p with np nodes and list q with <= nq nodes at end of tail *)
				IF (np # 0) & ((nq = 0) OR (q = NIL) OR (compare(p, q) <= 0)) THEN
					tail.next := p; tail := p; p := p.next; DEC(np)
				ELSIF (nq # 0) & (q # NIL) THEN
					tail.next := q; tail := q; q := q.next; DEC(nq)
				ELSE	(* (np = 0) & ((nq = 0) OR (q = NIL)) *)
					EXIT
				END
			END;
			tail.next := NIL; p := q
		END;
		n := n*2
	UNTIL m <= 1
END Sort;

PROCEDURE ComparePinyinFreq(a, b: ListElement) : LONGINT;
BEGIN
	IF a(PIMEEntry).pinyin < b(PIMEEntry).pinyin THEN RETURN -1 END;
	IF a(PIMEEntry).pinyin > b(PIMEEntry).pinyin THEN RETURN 1 END;
	(* equals *)
	IF a(PIMEEntry).freq > b(PIMEEntry).freq THEN RETURN -1 END;
	IF a(PIMEEntry).freq < b(PIMEEntry).freq THEN RETURN 1 END;
	RETURN 0
END ComparePinyinFreq;


PROCEDURE BuildBasicPinyinIMETable*;
VAR i, words : LONGINT;
	list : ListElement; (* first element is dummy for sort *)
	cur : ListElement;
	str : ARRAY 16 OF CHAR;
	f : Files.File;
	w : Files.Writer;

	PROCEDURE AddEntry(pinyin : ARRAY OF CHAR; code, freq : LONGINT);
	VAR e : PIMEEntry;
	BEGIN
		NEW(e);
		INC(words);
		COPY(pinyin, e.pinyin); e.ucs := code; e.freq := freq; e.next := list.next;
		list.next := e
	END AddEntry;


	PROCEDURE FixBugs(pinyin : ARRAY OF CHAR; code, freq : LONGINT);
	VAR i, l : LONGINT; t : ARRAY 100 OF CHAR;
	BEGIN
		Strings.Trim(pinyin, " ");

		(* workaround some bugs in the Unihan table *)
		l := Strings.Length(pinyin);
		i := 1; WHILE i < l DO
			IF (isNum[ORD(pinyin[i])]) & (pinyin[i + 1] # 0X) THEN
				Strings.Copy(pinyin, 0, i + 1, t);
				AddEntry(t, code, freq);
				Strings.Delete(pinyin, 0, i + 1);
				i := 1; l := Strings.Length(pinyin);
			ELSE INC(i)
			END
		END;
		IF pinyin # "" THEN
			AddEntry(pinyin, code, freq)
		END
	END FixBugs;

	PROCEDURE DumpChar(i : LONGINT; c : Character);
	VAR p, t : ARRAY 256 OF CHAR;
	BEGIN
		IF c.mandarin = NIL THEN
			KernelLog.String("unexpected :  no mandarininfo "); KernelLog.String("i = "); KernelLog.Int(i, 0); KernelLog.Ln;
			RETURN
		END;
		COPY(c.mandarin^, p);
		Strings.Trim(p, " ");
		WHILE Strings.Length(p) > 1 DO
			IF Strings.Pos(" ", p) >= 0 THEN
				Strings.Copy(p, 0, Strings.Pos(" ", p), t);
				FixBugs(t, i, c.xfreq);
				Strings.Delete(p, 0, Strings.Pos(" ", p));
				Strings.Trim(p, " ");
			ELSE
				FixBugs(p, i, c.xfreq);
				p := ""
			END
		END
	END DumpChar;

BEGIN
	NEW(list);
	words := 0;
	KernelLog.String("creating list...");
	FOR i := 0 TO MaxCode - 1 DO
		IF codeArray[i] # NIL THEN
			IF codeArray[i].xfreq > 0 THEN
				DumpChar(i, codeArray[i])
			END
		END
	END;
	KernelLog.String("done."); KernelLog.Ln;
	KernelLog.String("sorting");
	Sort(list, ComparePinyinFreq);
	KernelLog.String("done."); KernelLog.Ln;
	KernelLog.String("Writing PinyinIMETable.txt");


	f := Files.New("PinyinIMETable.txt");
	Files.OpenWriter(w, f, 0);
	w.Int(words, 0); w.Ln;

	cur := list.next;
	WHILE cur # NIL DO
		w.String(cur(PIMEEntry).pinyin); w.Char(09X);
		i := 0; IF UTF8Strings.EncodeChar(cur(PIMEEntry).ucs, str, i) THEN END;
		w.String(str); w.Char(09X);
		w.Int(cur(PIMEEntry).freq, 0);
		w.Ln;
		INC(words);
		cur := cur.next
	END;
	w.Update;
	Files.Register(f);
	KernelLog.String("done."); KernelLog.Ln;
END BuildBasicPinyinIMETable;

PROCEDURE InitLookup;
VAR i : LONGINT;
BEGIN
	(* to captial conversion table *)
	FOR i := 0 TO 255 DO cap[i] := CHR(i) END;
	FOR i := ORD("a") TO ORD("z") DO cap[i] := CHR(i - 32) END;
	(* number lookup *)
	FOR i := 0 TO 255 DO isNum[i] := FALSE END;
	FOR i := ORD("0") TO ORD("9") DO isNum[i] := TRUE END;
END InitLookup;

BEGIN
	InitLookup;
	NEW(codeArray, MaxCode);
	ParseFile;
END UnihanParser.

System.Free UnihanParser ~
UnihanParser.ParseFile ~
PET.Open PinyinIMETable.txt

UnihanParser.BuildBasicPinyinIMETable ;