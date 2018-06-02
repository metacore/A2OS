MODULE PDF; (** AUTHOR "TF"; PURPOSE "PDF Data-Structures"; *)

IMPORT
	Streams, Strings, Files, WMRectangles, WMGraphics, DynamicStrings, UTF8Strings;

CONST
	FontTimes = 0;
	FontHelvetica = 1;
	FontCourier = 2;
	FontArial = 3; (*ALEX 2005.10.28*)

	PageA0* = 1;
	PageA1* = 2;
	PageA2* = 3;
	PageA3* = 4;
	PageA4* = 5;
	PageA5* = 6;
	PageA6* = 7;
	PageA7* = 8;

	Unitmm* = 1;
	Unitmm10* = 2;
	Unitmm100* = 3;


TYPE
	PDFObject = OBJECT
	VAR context : Document;

		PROCEDURE &Init*(context : Document);
		BEGIN
			SELF.context := context
		END Init;

		PROCEDURE Write(w : Streams.Writer);
		END Write;
	END PDFObject;

	PDFObjArray = POINTER TO ARRAY OF PDFObject;
	PDFObjList = OBJECT
	VAR nof : LONGINT;
		data : PDFObjArray;

		PROCEDURE &Init*;
		BEGIN
			NEW(data, 4);
		END Init;

		PROCEDURE Add(o : PDFObject);
		VAR n : PDFObjArray; i : LONGINT;
		BEGIN
			IF nof = LEN(data) THEN
				NEW(n, LEN(data) * 2);
				FOR i := 0 TO nof - 1 DO n[i] := data[i] END;
				data := n;
			END;
			data[nof] := o;
			INC(nof)
		END Add;
	END PDFObjList;

	Int = OBJECT(PDFObject)
	VAR val : LONGINT;
		PROCEDURE Write(w : Streams.Writer);
		BEGIN
			w.Int(val, 0)
		END Write;
	END Int;

	Real = OBJECT(PDFObject)
	VAR val : REAL;
		PROCEDURE Write(w : Streams.Writer);
		BEGIN
			WriteReal(w, val);
		END Write;
	END Real;

	String = OBJECT(PDFObject)
	VAR data : Strings.String;

		PROCEDURE Write(w : Streams.Writer);
		BEGIN
			WritePDFString(w, data^)
		END Write;

	END String;

	Stream = OBJECT(PDFObject)
	VAR length : LONGINT;
		data : Strings.String;

		PROCEDURE &Init*(context : Document);
		BEGIN
			SELF.context := context; NEW(data, 4 *  4096); length := 0;
		END Init;

		PROCEDURE Add (CONST buf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: WORD);
		VAR i : LONGINT; n : Strings.String;
		BEGIN
			IF length + len >= LEN(data) THEN
				NEW(n, LEN(data) + len); FOR i := 0 TO length - 1 DO n[i] := data[i] END;
				data := n
			END;
			WHILE len > 0 DO
				data[length] := buf[ofs];
				INC(ofs); INC(length); DEC(len)
			END;
		END Add;

		PROCEDURE GetWriter() : Streams.Writer;
		VAR w : Streams.Writer;
		BEGIN
			NEW(w, SELF.Add, 4 * 4096);
			RETURN w
		END GetWriter;


		PROCEDURE Write(w : Streams.Writer);
		VAR i : LONGINT;
		BEGIN
			w.String("<< /Length "); w.Int(length, 0); w.String(" >>"); w.Ln;
			w.String("stream"); w.Ln;
			FOR i := 0 TO length - 1 DO w.Char(data[i]) END;
			w.Ln;
			w.String("endstream"); w.Ln;
		END Write;

	END Stream;

	Name = OBJECT(PDFObject)
	VAR s : Strings.String;

		PROCEDURE Write(w : Streams.Writer);
		BEGIN
			w.String(s^)
		END Write;
	END Name;


(* Dictionary *)
	DictionaryEntry = RECORD
		key : Name;
		data : PDFObject;
	END;

	DictionaryList = POINTER TO ARRAY OF DictionaryEntry;
	Dictionary = OBJECT (PDFObject)
	VAR data : DictionaryList;
		nofData : LONGINT;

		PROCEDURE &Init*(context : Document);
		BEGIN
			Init^(context);
			NEW(data, 4); nofData := 0
		END Init;

		PROCEDURE Add(key : Name; obj : PDFObject);
		VAR n : DictionaryList; i : LONGINT;
		BEGIN
			i := 0; WHILE (i < nofData) & (data[i].key # key) DO INC(i) END;
			IF i = nofData THEN (* key not found *)
				IF nofData = LEN(data) THEN
					NEW(n, LEN(data) * 2);
					FOR i := 0 TO nofData - 1 DO n[i] := data[i] END;
					data := n;
				END;
				data[nofData].key := key; data[nofData].data := obj;
				INC(nofData)
			ELSE (* key found --> redefinition *)
				data[i].data := obj
			END
		END Add;

		PROCEDURE GetObject(key : Name) : PDFObject;
		VAR i : LONGINT;
		BEGIN
			i := 0; WHILE (i < nofData) & (data[i].key # key) DO INC(i) END;
			IF i = nofData THEN RETURN NIL
			ELSE RETURN data[i].data
			END
		END GetObject;

		PROCEDURE Write(w : Streams.Writer);
		VAR i : LONGINT;
		BEGIN
			w.String("<<"); w.Ln;
			FOR i := 0 TO nofData - 1 DO
				data[i].key.Write(w); w.Char(" "); data[i].data.Write(w); w.Ln;
			END;
			w.String(">>");
		END Write;

	END Dictionary;

	Array = OBJECT(PDFObject)
	VAR content : PDFObjList;

		PROCEDURE &Init*(context : Document);
		BEGIN
			Init^(context);
			NEW(content)
		END Init;

		PROCEDURE Add(content : PDFObject);
		BEGIN
			SELF.content.Add(content)
		END Add;

		PROCEDURE Write(w : Streams.Writer);
		VAR i : LONGINT;
		BEGIN
			w.Char("[");
			FOR i := 0 TO content.nof - 1 DO
				content.data[i].Write(w); w.Char(" ");
			END;
			w.Char("]");
		END Write;

		PROCEDURE Get(i : LONGINT): PDFObject;
		BEGIN
			RETURN content.data[i]
		END Get;


	END Array;

	Object = OBJECT(PDFObject)
	VAR id, generation : LONGINT;
		filepos : LONGINT;
		content : PDFObjList;
		next : Object;

		PROCEDURE &Init*(context : Document);
		BEGIN
			Init^(context);
			context.RegisterObj(SELF);
			NEW(content)
		END Init;

		PROCEDURE AddContent(content : PDFObject);
		BEGIN
			SELF.content.Add(content)
		END AddContent;

		PROCEDURE WriteContent(w : Streams.Writer);
		VAR i : LONGINT;
		BEGIN
			filepos := w.Pos();
			w.Int(id, 0); w.String(" "); w.Int(generation, 0); w.String(" obj"); w.Ln;
			FOR i := 0 TO content.nof - 1 DO
				content.data[i].Write(w); w.Ln;
			END;
			w.String("endobj"); w.Ln; w.Ln
		END WriteContent;

		PROCEDURE Write(w : Streams.Writer);
		BEGIN
			w.Int(id, 0); w.Char(" "); w.Int(generation, 0); w.String(" R")
		END Write;

	END Object;

	PageNode = OBJECT(Object)
	VAR dict : Dictionary;
		kids : Array;
		count : Int;

		PROCEDURE &Init*(context : Document);
		BEGIN
			Init^(context);
			dict := context.NewDictionary();
			AddContent(dict);
			count := context.NewInt(0);
			kids := context.NewArray();

			dict.Add(context.NewName("/Type"), context.NewName("/Pages"));
			dict.Add(context.NewName("/Kids"), kids);
			dict.Add(context.NewName("/Count"), count);
		END Init;

		PROCEDURE AddPage(page : Page);
		BEGIN
			kids.Add(page);
			page.dict.Add(context.NewName("/Parent"), SELF);
			INC(count.val)
		END AddPage;

	END PageNode;

	Font = OBJECT(Object)
	VAR dict : Dictionary;
		name : Name;
		type : LONGINT;
		style : SET;
		next : Font;

		PROCEDURE &New*(context : Document; type : LONGINT; style : SET);
		BEGIN
			Init(context);
			dict := context.NewDictionary();
			AddContent(dict);
			dict.Add(context.NewName("/Type"), context.NewName("/Font"));
			dict.Add(context.NewName("/Subtype"), context.NewName("/Type1"));
			(*dict.Add(context.NewName("/Encoding"), context.NewName("/MacRomanEncoding"));*)
			dict.Add(context.NewName("/Encoding"), context.NewName("/WinAnsiEncoding")); (*ALEX 2006.04.06*)
			SetName("/F1");
			SELF.type := type; SELF.style := style;
			SetStandard(type, style)
		END New;

		PROCEDURE SetName(n : ARRAY OF CHAR);
		BEGIN
			name := context.NewName(n);
			dict.Add(context.NewName("/Name"), name);
		END SetName;


		PROCEDURE SetStandard(type : LONGINT; style : SET);
		VAR fontName : ARRAY 64 OF CHAR;
			s : LONGINT;
		BEGIN
			s := 0;
			IF WMGraphics.FontBold IN style THEN s := 1;
				IF WMGraphics.FontItalic IN style THEN s := 3 END;
			ELSIF WMGraphics.FontItalic IN style THEN s := 2
 			END;
			CASE type OF
				|FontTimes :
					CASE s OF
						|0 : fontName := "/Times-Roman"
						|1 : fontName := "/Times-Bold"
						|2 : fontName := "/Times-Italic"
						|3 : fontName := "/Times-BoldItalic"
					END;
				|FontHelvetica :
					CASE s OF
						|0 : fontName := "/Helvetica"
						|1 : fontName := "/Helvetica-Bold"
						|2 : fontName := "/Helvetica-Oblique"
						|3 : fontName := "/Helvetica-BoldOblique"
					END;
				|FontCourier :
					CASE s OF
						|0 : fontName := "/Courier"
						|1 : fontName := "/Courier-Bold"
						|2 : fontName := "/Courier-Oblique"
						|3 : fontName := "/Courier-BoldOblique"
					END;
				|FontArial : (*ALEX 2005.10.28*)
					CASE s OF
						|0 : fontName := "/Arial"
						|1 : fontName := "/Arial-Bold"
						|2 : fontName := "/Arial-Oblique"
						|3 : fontName := "/Arial-BoldOblique"
					END;
			ELSE
				fontName := "/Helvetica" (* PH corrected typo 100301*)
			END;
			dict.Add(context.NewName("/BaseFont"), context.NewName(fontName));
		END SetStandard;

	END Font;

	Page = OBJECT(Object)
	VAR dict : Dictionary;
		mediaBox : Array;
		procSet : Array;
		resources, fonts : Dictionary;

		PROCEDURE &Init*(context : Document);
		BEGIN
			Init^(context);
			dict := context.NewDictionary();
			AddContent(dict);
			dict.Add(context.NewName("/Type"), context.NewName("/Page"));

			mediaBox := context.NewArray();
			(* set default to A4 in 1/72 inches *)
			mediaBox.Add(context.NewReal(0));
			mediaBox.Add(context.NewReal(0));
			mediaBox.Add(context.NewReal(569.734));
			mediaBox.Add(context.NewReal(841.846));

			resources := context.NewDictionary();
			resources.Add(context.NewName("/ProcSet"), context.GetDefaultProcSet());
			dict.Add(context.NewName("/Resources"), resources);

			fonts := context.NewDictionary();
			resources.Add(context.NewName("/Font"), fonts);

			dict.Add(context.NewName("/MediaBox"), mediaBox);
		END Init;

		PROCEDURE SetPaper(paper : LONGINT; landscape : BOOLEAN);
		VAR t, w, h : REAL;
		BEGIN
			CASE paper OF
				|PageA0 : w := 841; h := 1189;
				|PageA1 : w := 594; h := 841;
				|PageA2 : w := 420; h := 594;
				|PageA3 : w := 297; h := 420;
				|PageA4 : w := 210; h := 297;
				|PageA5 : w := 148; h := 210;
				|PageA6 : w := 105; h := 148;
				|PageA7 : w := 74; h := 105;
			ELSE w := 210; h := 297;
			END;
			IF landscape THEN t := w; w := h ; h := t END;
			SetExtents(0, 0, w * 72 / 25.4, h * 72 / 25.4)
		END SetPaper;

		PROCEDURE SetExtents(x, y, w, h : REAL);
		VAR r : PDFObject;
		BEGIN
			r := mediaBox.Get(0); r(Real).val := x;
			r := mediaBox.Get(1); r(Real).val := y;
			r := mediaBox.Get(2); r(Real).val := w;
			r := mediaBox.Get(3); r(Real).val := h;
		END SetExtents;

		PROCEDURE GetExtents(VAR x, y, w, h : REAL);
		VAR r : PDFObject;
		BEGIN
			r := mediaBox.Get(0); x := r(Real).val;
			r := mediaBox.Get(1); y := r(Real).val;
			r := mediaBox.Get(2); w := r(Real).val;
			r := mediaBox.Get(3); h := r(Real).val;
		END GetExtents;

		PROCEDURE GetFont(type : LONGINT; style : SET) : Font;
		VAR f : Font;
		BEGIN
			f := context.GetFont(type, style);
			fonts.Add(f.name, f);
			RETURN f
		END GetFont;

		PROCEDURE SetContent(content : Object);
		BEGIN
			dict.Add(context.NewName("/Contents"), content)
		END SetContent;
	END Page;

	NameList = POINTER TO ARRAY OF Name;

	Document = OBJECT
	VAR version : ARRAY 64 OF CHAR;
		nofObjects : LONGINT;
		firstObj, lastObj : Object;

		catalog, infoObj : Object;
		infoDict : Dictionary;

		rootPages : PageNode; (* root page node *)
		pageDict : Dictionary;

		defaultProcSet : Object;

		names : NameList;
		nofNames : LONGINT;

		fonts : Font;
		nofFonts : LONGINT;

		PROCEDURE &Init*;
		VAR cDict : Dictionary;
			a : Array;
		BEGIN
			version := "%PDF-1.4";
			nofObjects := 0;
			nofNames := 0; NEW(names, 16);
			nofFonts := 0;
			(* document info *)
			infoObj := NewObject();
			infoDict := NewDictionary();
			infoObj.AddContent(infoDict);
			infoDict.Add(NewName("/Producer"), NewString("Bluebottle PDF support"));

			(* building up the required catalog *)
			catalog := NewObject();
			cDict := NewDictionary();
			catalog.AddContent(cDict);
			cDict.Add(NewName("/Type"), NewName("/Catalog"));
			rootPages := NewPageNode(TRUE);
			cDict.Add(NewName("/Pages"), rootPages);


			defaultProcSet := NewObject();
			a := NewArray();
			a.Add(NewName("/PDF"));
			a.Add(NewName("/Text"));
			defaultProcSet.AddContent(a)
		END Init;

		PROCEDURE GetDefaultProcSet():Object;
		BEGIN
			RETURN defaultProcSet
		END GetDefaultProcSet;

		PROCEDURE RegisterObj(obj : Object);
		BEGIN
			obj.id := nofObjects + 1; obj.generation := 0;
			IF firstObj = NIL THEN firstObj := obj; lastObj := obj
			ELSE lastObj.next := obj; lastObj := obj
			END;
			INC(nofObjects);
		END RegisterObj;

		PROCEDURE NewObject() : Object;
		VAR obj : Object;
		BEGIN
			NEW(obj, SELF);
			RETURN obj
		END NewObject;

		PROCEDURE NewPageNode(root : BOOLEAN) : PageNode;
		VAR pn : PageNode;
		BEGIN
			NEW(pn, SELF);
			RETURN pn
		END NewPageNode;

		PROCEDURE NewArray() : Array;
		VAR a : Array;
		BEGIN
			NEW(a, SELF); RETURN a
		END NewArray;

		PROCEDURE NewDictionary():Dictionary;
		VAR d : Dictionary;
		BEGIN
			NEW(d, SELF);
			RETURN d
		END NewDictionary;

		PROCEDURE NewInt(val : LONGINT) : Int;
		VAR i : Int;
		BEGIN
			NEW(i, SELF); i.val := val;
			RETURN i
		END NewInt;

		PROCEDURE NewReal(val : REAL) : Real;
		VAR i : Real;
		BEGIN
			NEW(i, SELF); i.val := val;
			RETURN i
		END NewReal;

		PROCEDURE NewString(str : ARRAY OF CHAR) : String;
		VAR s : String;
		BEGIN
			NEW(s, SELF); s.data := Strings.NewString(str);
			RETURN s
		END NewString;

		PROCEDURE NewPage(): Page;
		VAR p : Page;
		BEGIN
			NEW(p, SELF);
			RETURN p
		END NewPage;

		PROCEDURE GetFont(type : LONGINT; style : SET) : Font;
		VAR cur : Font; name, s : ARRAY 10 OF CHAR;
		BEGIN
			cur := fonts;
			WHILE cur # NIL DO
				IF (cur.type = type) & (cur.style = style) THEN RETURN cur END;
				cur := cur.next
			END;
			NEW(cur, SELF, type, style);
			name := "/F";
			Strings.IntToStr(nofFonts, s); Strings.Append(name, s);
			cur.SetName(name);
			cur.next := fonts;
			fonts := cur;
			INC(nofFonts);
			RETURN cur
		END GetFont;

		PROCEDURE NewName(name : ARRAY OF CHAR) : Name;
		VAR i, j : LONGINT; nn : NameList;
		BEGIN
			i := 0; WHILE (i < nofNames) & (names[i].s^ # name) DO INC(i) END;
			IF i = nofNames THEN
				IF nofNames = LEN(names) THEN (* grow *)
					NEW(nn, LEN(names) * 2);
					FOR j := 0 TO nofNames - 1 DO nn[j] := names[j] END;
					names := nn
				END;
				NEW(names[nofNames], SELF);
				names[nofNames].s := Strings.NewString(name);
				INC(nofNames)
			END;
			RETURN names[i]
		END NewName;


		PROCEDURE WriteLZInt(w : Streams.Writer; val, digits : LONGINT);
		VAR s : ARRAY 16 OF CHAR; i : LONGINT;
		BEGIN
			Strings.IntToStr(val, s);
			FOR i := 1 TO digits - Strings.Length(s) DO w.Char("0") END;
			w.String(s)
		END WriteLZInt;

		PROCEDURE Write(w : Streams.Writer);
		VAR cur : Object;
			lastXRefPos : LONGINT;
			trailDict : Dictionary;
		BEGIN
			(* header *)
			w.String(version); w.Ln;
			(* body *)
			cur := firstObj;
			WHILE cur # NIL DO
				cur.WriteContent(w);
				cur := cur.next
			END;

			(* cross-reference section *)
			lastXRefPos := w.Pos();
			w.String("xref"); w.Ln;
			(* cross- reference subsections *)
			w.String("0 "); (* only one for now starts with object 0 *)
			w.Int(nofObjects + 1, 0); w.Ln; (* nofObjects objects in the subsection *)
			(* write subsection entries *)
			w.String("0000000000 65535 f"); w.Ln;
			cur := firstObj;
			WHILE cur # NIL DO
				(* offset (10 digits) <space> generation (5 digits) <space> "n" CRLF *)
				WriteLZInt(w, cur.filepos, 10); w.Char(" "); WriteLZInt(w, 0, 5); w.Char(" "); w.Char("n"); w.Ln;
				cur := cur.next
			END;
			w.Ln;

			(* trailer *)
			w.String("trailer"); w.Ln;
			trailDict := NewDictionary();
			trailDict.Add(NewName("/Size"), NewInt(nofObjects + 1));
			trailDict.Add(NewName("/Root"), catalog);
			trailDict.Add(NewName("/Info"), infoObj);
			trailDict.Write(w); w.Ln;
			w.String("startxref"); w.Ln;
			w.Int(lastXRefPos, 0); w.Ln;
			w.String("%%EOF"); w.Ln;(* end of file marker *)

			w.Update

		END Write;

	END Document;

(* integration into WMGraphics.Canvas *)
	PDFCanvas* = OBJECT(WMGraphics.Canvas)
	VAR d : Document;
		pc : PDFCreator;
		p : Page;
		s : Stream;
		c : Object;
		w : Streams.Writer;
		font : Font;
		next : PDFCanvas;
		prl, prt, prr, prb, scale : REAL;
		colrg, colRG: LONGINT;
		fSize : REAL;
		xfont : Font;

		PROCEDURE &Init*(pc : PDFCreator; pageFormat : LONGINT; landscape : BOOLEAN; unit : LONGINT);
		BEGIN
			SELF.pc := pc; d := pc.d;
			p := d.NewPage();
			d.rootPages.AddPage(p);
			c := d.NewObject();
			p.SetContent(c);
			NEW(s, d);
			c.AddContent(s);
			w := s.GetWriter();
			p.SetPaper(pageFormat, landscape);
			p.GetExtents(prl, prt, prr, prb);

			CASE unit OF
				|1 :  scale := 72 / 24.5;
				|2 :  scale := 72 / 245;
				|3 :  scale := 72 / 2450;
			ELSE
				scale := 1
			END;
			limits := WMRectangles.MakeRect(0, 0, ENTIER(prr / scale), ENTIER(prb / scale));
			WriteReal(w, 1/72); w.String(" w"); w.Ln;
		END Init;

		PROCEDURE Transform(x, y : LONGINT; VAR rx, ry : REAL);
		BEGIN
			rx := x * scale;
			ry := prb - y * scale
		END Transform;

		PROCEDURE WriteTrafoCoord(x, y : LONGINT);
		VAR rx, ry : REAL;
		BEGIN
			Transform(x, y, rx, ry);
			WriteReal(w, rx); w.Char(" "); WriteReal(w, ry)
		END WriteTrafoCoord;

		PROCEDURE SetColor*(col : LONGINT);
		BEGIN
			IF col # color THEN
				SetColor^(col);
				SetColrg(col)
			END
		END SetColor;

		PROCEDURE SetColrg(col : LONGINT);
		BEGIN
			IF col # colrg THEN
				WriteReal(w, ((col DIV 1000000H) MOD 100H)/ 255);w.Char(" ");
				WriteReal(w, ((col DIV 10000H) MOD 100H)/ 255);w.Char(" ");
				WriteReal(w, ((col DIV 100H) MOD 100H)/ 255);w.String(" rg"); w.Ln;
				colrg := col
			END
		END SetColrg;

		PROCEDURE SetColRG(col : LONGINT);
		BEGIN
			IF col # colRG THEN
				WriteReal(w, ((col DIV 1000000H) MOD 100H)/ 255);w.Char(" ");
				WriteReal(w, ((col DIV 10000H) MOD 100H)/ 255);w.Char(" ");
				WriteReal(w, ((col DIV 100H) MOD 100H)/ 255);w.String(" RG"); w.Ln;
				colRG := col
			END
		END SetColRG;

		PROCEDURE Fill*(r : WMRectangles.Rectangle; col : LONGINT; mode : LONGINT);
		VAR ax, ay, bx ,by : REAL;
		BEGIN
			SetColrg(col);
			WriteTrafoCoord(r.l, r.t); w.Char(" ");
			Transform(r.l, r.t, ax, ay); Transform(r.r, r.b, bx, by);
			WriteReal(w, bx - ax); w.Char(" "); WriteReal(w, by - ay);
			w.String(" re f "); w.Ln;
		END Fill;

		PROCEDURE GetPDFFont(f : WMGraphics.Font) : Font;
		VAR (* font : Font; *) t : LONGINT;
		BEGIN
(*			IF f.name = "Oberon" THEN t := FontHelvetica
			ELSIF f.name = "Courier" THEN t := FontCourier
			ELSE t := FontTimes
			END;
(*			font := p.GetFont(t, f.style); *)
			fSize := f.size;  *)
			IF xfont = NIL THEN xfont := p.GetFont(t, f.style) END;
			RETURN xfont
		END GetPDFFont;

		(*ALEX 2005.10.26 changed signature*)
		PROCEDURE PDFSetFont*(name : ARRAY OF CHAR; size : LONGINT(*REAL*); style : SET);
		VAR t : LONGINT;
		BEGIN
			IF name = "Oberon" THEN t := FontHelvetica
			ELSIF name = "Courier" THEN t := FontCourier
			ELSIF name = "Arial" THEN t := FontArial
			ELSE t := FontTimes
			END;
			xfont := p.GetFont(t, style);
			fSize := size;
			(*ALEX 2005.10.26*)
			SetFont(WMGraphics.GetFont(name, size, style));
		END PDFSetFont;


		PROCEDURE DrawString*(x, y: LONGINT; CONST text : ARRAY OF CHAR);
		BEGIN
			font := GetPDFFont(GetFont());
			SetColrg(color);
			w.String("BT");w.Ln;
			font.name.Write(w); w.Char(" "); WriteReal(w, fSize * scale); w.String(" Tf"); w.Ln;
			WriteTrafoCoord(x, y); w.String(" Td"); w.Ln;
			WritePDFString(w, text);  w.String(" Tj"); w.Ln;
			w.String("ET"); w.Ln;
			w.Ln
		END DrawString;

		(*ALEX 2005.10.26*)
		PROCEDURE DrawStringMultiLine*(x, y, width,height: LONGINT; resizeHeight: BOOLEAN; CONST stext : ARRAY OF CHAR; VAR actualHeight: LONGINT);
		VAR i: LONGINT;
			buf: ARRAY 2 OF CHAR;
			sumW, sumH, strW, strH, lineH: LONGINT;
			beginLine: LONGINT;
			f : WMGraphics.Font;
			overflowH: BOOLEAN;

			text: Strings.String;
			sz, ret: LONGINT;

			PROCEDURE  WriteLine;
			BEGIN
				w.String("BT");w.Ln;
				font.name.Write(w); w.Char(" "); WriteReal(w, fSize * scale); w.String(" Tf"); w.Ln;

				WriteTrafoCoord(x, y + sumH); w.String(" Td"); w.Ln;
				WritePDFStringPos(w, text^, beginLine, i);
				w.String(" Tj"); w.Ln;

				w.String("ET"); w.Ln;
				w.Ln
			END WriteLine;

		BEGIN
			buf[1] := 0X; buf[0] := " ";
			font := GetPDFFont(GetFont());
			SetColrg(color);
			f := GetFont();

			f.GetStringSize(buf, strW, lineH);
			beginLine := 0;

			(*ALEX 2006.04.06*)
			sz := DynamicStrings.StringLength(stext);
			NEW(text, sz + 1);
			ret := UTF8Strings.UTF8toASCII(stext, "?", text^);


			WHILE (text[i] # 0X) & (~overflowH OR resizeHeight) DO
				IF (text[i] = 0DX) OR (text[i] = 0AX) THEN
					IF sumH + lineH > height THEN overflowH := TRUE END;
					IF ~overflowH OR resizeHeight THEN
						WriteLine();
						IF (text[i] = 0DX) & (text[i+1] = 0AX) THEN INC(i) END;
						beginLine := i+1; sumW := 0; INC(sumH, lineH)
					END
				ELSE
					buf[0] := text[i];
					f.GetStringSize(buf, strW, strH);
					IF sumW + strW > width THEN
						IF sumH + lineH > height THEN overflowH := TRUE END;
						IF ~overflowH OR resizeHeight THEN
							WriteLine();
							beginLine := i; sumW := strW; INC(sumH, lineH)
						END
					ELSE
						INC(sumW, strW)
					END
				END;

				INC(i);
			END;

			IF ~overflowH OR resizeHeight THEN WriteLine() END;
			IF resizeHeight THEN actualHeight := sumH + lineH ELSE actualHeight := height END
		END DrawStringMultiLine;

		(*ALEX 2005.10.25*)
		PROCEDURE DrawStringSingleLine*(x, y, width, align: LONGINT; stext : ARRAY OF CHAR);
		VAR f : WMGraphics.Font;
			sz, i, j: LONGINT;
			overflow: BOOLEAN;
			buf: ARRAY 2 OF CHAR;
			sumW, sumWLeft, strW, strH: LONGINT;
			g: WMGraphics.GlyphSpacings;
			lbRet: BOOLEAN;
			text: Strings.String;
			ret: LONGINT;
		BEGIN
			buf[1] := 0X;
			font := GetPDFFont(GetFont());
			SetColrg(color);

			f := GetFont();
			(*ALEX 2006.04.06*)
			sz := DynamicStrings.StringLength(stext);
			NEW(text, sz + 1);
			ret := UTF8Strings.UTF8toASCII(stext, "?", text^);
			sz := DynamicStrings.StringLength(text^);

			IF align = WMGraphics.AlignRight THEN
				i := sz-1;
				WHILE (i >= 0) & ~overflow DO
					buf[0] := text[i];
					lbRet := GetCharSpacings(f, text^, i, g);
					strW := g.bearing.l + g.width + g.bearing.r;
					IF sumW + strW > width THEN overflow := TRUE
					ELSE
						INC(sumW, strW);
						w.String("BT");w.Ln;
						font.name.Write(w); w.Char(" "); WriteReal(w, fSize * scale); w.String(" Tf"); w.Ln;
						WriteTrafoCoord(x + width - sumW + g.bearing.l, y); w.String(" Td"); w.Ln;
						WritePDFStringPos(w, buf, 0, 1); w.String(" Tj"); w.Ln;
						w.String("ET"); w.Ln;
						w.Ln;
						DEC(i);
					END;
				END;
			ELSIF align = WMGraphics.AlignCenter THEN
				i := (sz-1) DIV 2; j := i;
				w.String("BT");w.Ln;
				font.name.Write(w); w.Char(" "); WriteReal(w, fSize * scale); w.String(" Tf"); w.Ln;
				WHILE ~overflow DO
					IF i >= 0 THEN
						buf[0] := text[i];
						f.GetStringSize(buf, strW, strH);
						IF sumW + strW > width THEN overflow := TRUE
						ELSE DEC(i); INC(sumW, strW); INC(sumWLeft, strW);
						END;
					END;

					IF j = i THEN INC(j) END;
					IF j < sz THEN
						buf[0] := text[j];
						f.GetStringSize(buf, strW, strH);
						IF sumW + strW > width THEN overflow := TRUE
						ELSE INC(j); INC(sumW, strW)
						END;
					END;
					IF ~overflow & (i < 0) & (j >= sz) THEN overflow := TRUE END;
				END;
				WriteTrafoCoord(x + (width - sumW) DIV 2, y); w.String(" Td"); w.Ln;
				WritePDFStringPos(w, text^, i+1, j);
				w.String(" Tj"); w.Ln;
				w.String("ET"); w.Ln;
				w.Ln
			ELSE (*align left*)
				i := 0;
				w.String("BT");w.Ln;
				font.name.Write(w); w.Char(" "); WriteReal(w, fSize * scale); w.String(" Tf"); w.Ln;
				WHILE (i < sz) & ~overflow DO
					buf[0] := text[i];
					f.GetStringSize(buf, strW, strH);
					IF sumW + strW > width THEN overflow := TRUE
					ELSE INC(i); INC(sumW, strW)
					END;
				END;
				WriteTrafoCoord(x, y); w.String(" Td"); w.Ln;
				WritePDFStringPos(w, text^, 0, i);
				w.String(" Tj"); w.Ln;
				w.String("ET"); w.Ln;
				w.Ln
			END;
		END DrawStringSingleLine;

		PROCEDURE PDFSetLineWidth*(width : REAL);
		BEGIN
			WriteReal(w, width * scale);
			w.String(" w"); w.Ln;
		END PDFSetLineWidth;

		(*Default : lines not joined => param := 0; joined lines => param := 1;*)
		PROCEDURE PDFSetLineJoin*(param : INTEGER);
		VAR
			str : ARRAY 15 OF CHAR;
		BEGIN
			Strings.IntToStr(param, str);
			w.String(str); w.String(" j");
		END PDFSetLineJoin;

		PROCEDURE PolyLine*(CONST points : ARRAY OF WMGraphics.Point2d; nofPoints : LONGINT; closed : BOOLEAN;  color : WMGraphics.Color; mode : LONGINT);
		VAR i : LONGINT;
		BEGIN
			IF nofPoints < 2 THEN RETURN END;
			ASSERT(nofPoints <= LEN(points));
			SetColRG(color);
			WriteTrafoCoord(points[0].x, points[0].y); w.String(" m ");
			FOR i := 1 TO nofPoints - 1 DO
				WriteTrafoCoord(points[i].x, points[i].y); w.String(" l ");
			END;
			IF closed THEN w.String("h ") END;
			w.Char("S"); w.Ln
		END PolyLine;

		PROCEDURE FillPoly*(CONST points : ARRAY OF WMGraphics.Point2d; nofPoints : LONGINT; color : WMGraphics.Color; mode : LONGINT);
		VAR i : LONGINT;
		BEGIN
			IF nofPoints < 2 THEN RETURN END;
			ASSERT(nofPoints <= LEN(points));
			SetColrg(color);
			WriteTrafoCoord(points[0].x, points[0].y); w.String(" m ");
			FOR i := 1 TO nofPoints - 1 DO
				WriteTrafoCoord(points[i].x, points[i].y); w.String(" l ");
			END;
			w.String("f*"); w.Ln
		END FillPoly;

		PROCEDURE Line*(x0, y0, x1, y1 : LONGINT; color : LONGINT; mode : LONGINT);
		BEGIN
			SetColRG(color);
			WriteTrafoCoord(x0, y0); w.String(" m ");
			WriteTrafoCoord(x1, y1);  w.String(" l S");
			w.Ln
		END Line;


		PROCEDURE Close;
		BEGIN
			w.Update;
		END Close;

	END PDFCanvas;

	(* simple helper object to create pdf files via WM Graphics *)
	PDFCreator* = OBJECT
	VAR d : Document;
		closed : BOOLEAN;
		pages : PDFCanvas;

		PROCEDURE &Init*;
		BEGIN
			NEW(d);
			closed := FALSE;
		END Init;

		PROCEDURE NewPage*(pageFormat : LONGINT; landscape : BOOLEAN; unit : LONGINT) : PDFCanvas;
		VAR c : PDFCanvas;
		BEGIN
			NEW(c, SELF, pageFormat, landscape, unit);
			c.next := pages;
			pages := c;
			RETURN c
		END NewPage;

		PROCEDURE Write*(w : Streams.Writer);
		VAR cur : PDFCanvas;
		BEGIN
			cur := pages; WHILE cur # NIL DO cur.Close; cur := cur.next END;
			d.Write(w)
		END Write;

		PROCEDURE Store*(filename : ARRAY OF CHAR);
		VAR f : Files.File; fw : Files.Writer;
(*			ml : MultiLogger.LogWindow;
			mlw : Streams.Writer; *)
		BEGIN
			f := Files.New(filename);
			Files.OpenWriter(fw, f, 0);
			Write(fw);
			Files.Register(f);

			(*NEW(ml, "PDF Output", mlw);
			d.Write(mlw); *)
		END Store;


	END PDFCreator;

PROCEDURE WriteReal(w : Streams.Writer; val : REAL);
VAR s : ARRAY 10 OF CHAR;
BEGIN
	Strings.FloatToStr(val, 0, 5, 0, s);
	w.String(s)
END WriteReal;

PROCEDURE WritePDFString(w : Streams.Writer; CONST  data : ARRAY OF CHAR);
VAR i : LONGINT;
BEGIN
	w.Char("(");
	i := 0; WHILE data[i] # 0X DO
		CASE data[i] OF
			|"(" : w.String("\(");
			|")" : w.String("\)");
			|"\" : w.String("\\");
			|0AX : w.String("\n");
			|0DX: w.String("\r");
			|08X: w.String("\b");
			|09X: w.String("\t");
		ELSE w.Char(data[i])
		END;
		INC(i)
	END;
	w.Char(")");
END WritePDFString;

(*ALEX 2005.10.26: same asa the above function only that writes data[from..to-1]*)
PROCEDURE WritePDFStringPos(w : Streams.Writer; CONST data : ARRAY OF CHAR; from, to: LONGINT);
VAR i : LONGINT;
BEGIN
	w.Char("(");
	i := from; WHILE (i < to) & (data[i] # 0X)  DO
		CASE data[i] OF
			|"(" : w.String("\(");
			|")" : w.String("\)");
			|"\" : w.String("\\");
			|0AX : w.String("\n");
			|0DX: w.String("\r");
			|08X: w.String("\b");
			|09X: w.String("\t");
		ELSE w.Char(data[i])
		END;
		INC(i)
	END;
	w.Char(")");
END WritePDFStringPos;

(*ALEX 2005.10.31*)
PROCEDURE GetCharSpacings(f: WMGraphics.Font; VAR text: ARRAY OF CHAR; i: LONGINT; VAR g : WMGraphics.GlyphSpacings): BOOLEAN;
VAR code: LONGINT;
BEGIN
	IF UTF8Strings.DecodeChar(text, i, code) THEN
		IF f.HasChar(code) THEN f.GetGlyphSpacings(code, g);
		ELSE WMGraphics.FBGetGlyphSpacings(code, g)
		END;
		RETURN TRUE
	ELSE RETURN FALSE
	END
END GetCharSpacings;

END PDF.

SystemTools.Free PDF ~



Header
Body
	* sequence of indirect objects
Cross-references
Trailer


FTP.Open enigon.net backup tfrey ~
FTP.PutFiles PDF.Mod => PDF20040709.Mod ~
FTP.Close