MODULE antsTexts IN Oberon; 	(** fof  **)
(* Copyright notice:

This file is part of AntsInFields
Copyright (C) 1997-2002, Felix Friedrich

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

Copy of the GNU Lesser General Public License can be found in the file COPYING.TXT
Report any problems as soon as possible to ants@AntsInFields.de
*)




IMPORT Texts, Objects, (* Log,*)Strings, aM := antsMessages;

	VAR nls: ARRAY 256 OF CHAR;  nll: SIGNED32;



PROCEDURE CheckPattern (t: Texts.Text;  VAR pattern: ARRAY OF CHAR;  len, pos: SIGNED32): BOOLEAN;
	VAR r: Texts.Reader;  ch: CHAR;  i: SIGNED32;
BEGIN
	i := 0;
	Texts.OpenReader(r, t, pos);
	Texts.Read(r, ch);
	ASSERT(ch = pattern[0]);
	WHILE(i < len) DO
		IF (ch # pattern[i]) OR (r.eot) THEN RETURN FALSE END;
		Texts.Read(r, ch);  INC(i)
	END;
	RETURN TRUE
END CheckPattern;

PROCEDURE FindPattern* (t: Texts.Text;  pattern: ARRAY OF CHAR;  len: SIGNED32;  VAR pos: SIGNED32): BOOLEAN;
	VAR  ch, first: CHAR;  r: Texts.Reader;
BEGIN
	(* Log.Ln; Log.Str("Finding patter: "); Log.Str(pattern); *)

	nls[0] := 0DX;  nll := 1;
	Texts.OpenReader(r, t, pos);
	first := pattern[0];
	Texts.Read(r, ch);
	WHILE ~r.eot DO
		IF ch = 0DX THEN nll := 1
		ELSIF (ch = " ") OR (ch = 09X) THEN
			nls[nll] := ch;  INC(nll)
		END;
		IF ch = first THEN
			IF CheckPattern(t, pattern, len, pos) THEN (* Log.Ln; Log.Str("found!"); *)RETURN TRUE END
		END;
		Texts.Read(r, ch);  INC(pos)
	END;
	(* Log.Ln; Log.Str("not found ! "); *)
	RETURN FALSE
END FindPattern;

PROCEDURE MakeBuf (s: ARRAY OF CHAR;  len: SIGNED32;  NL: BOOLEAN): Texts.Buffer;
	VAR W: Texts.Writer;  i: SIGNED32;
BEGIN
	Texts.OpenWriter(W);
	IF NL THEN
		i := 0;  WHILE(i < nll) DO
			Texts.Write(W, nls[i]);  INC(i)
		END
	END;
	i := 0;  WHILE(i < len) DO
		Texts.Write(W, s[i]);  INC(i)
	END;
	RETURN W.buf
END MakeBuf;

PROCEDURE CheckLen (VAR s: ARRAY OF CHAR;  VAR len: SIGNED32);
	VAR i: SIGNED16;
BEGIN
	i := 0;
	WHILE (i < len) & (s[i] # 0X) DO INC(i) END;
	len := i
END CheckLen;


PROCEDURE ReplacePatterns* (t: Texts.Text;  pattern: ARRAY OF CHAR;  slen: SIGNED32;  by: ARRAY OF CHAR;  dlen: SIGNED32);
	VAR pos: SIGNED32;
BEGIN
	CheckLen(pattern, slen);  CheckLen(by, dlen);
	pos := 0;
	WHILE(FindPattern(t, pattern, slen, pos)) DO
		Texts.Replace(t, pos, pos + slen, MakeBuf(by, dlen, FALSE));  INC(pos)
	END
END ReplacePatterns;

PROCEDURE AppendPatterns* (t: Texts.Text;  pattern: ARRAY OF CHAR;  slen: SIGNED32;  by: ARRAY OF CHAR;  dlen: SIGNED32);
	VAR pos: SIGNED32;
BEGIN
	CheckLen(pattern, slen);  CheckLen(by, dlen);
	pos := 0;
	WHILE(FindPattern(t, pattern, slen, pos)) DO
		Texts.Insert(t, pos + slen, MakeBuf(by, dlen, FALSE));  INC(pos)
	END
END AppendPatterns;

PROCEDURE AppendPatternsNl* (t: Texts.Text;  pattern: ARRAY OF CHAR;  slen: SIGNED32;  by: ARRAY OF CHAR;  dlen: SIGNED32);
	VAR pos: SIGNED32;
BEGIN
	CheckLen(pattern, slen);  CheckLen(by, dlen);
	pos := 0;
	WHILE(FindPattern(t, pattern, slen, pos)) DO
		Texts.Insert(t, pos + slen, MakeBuf(by, dlen, TRUE));  INC(pos)
	END
END AppendPatternsNl;

PROCEDURE Copy* (t: Texts.Text): Texts.Text;
	VAR cm: Objects.CopyMsg;
BEGIN
	cm.obj := NIL;
	IF t.handle # NIL THEN t.handle(t, cm)
	ELSE Texts.Handle(t, cm)
	END;
	IF cm.obj # NIL THEN
		RETURN cm.obj(Texts.Text)
	ELSE
		RETURN NIL
	END
END Copy;

PROCEDURE ReplaceTextPart* (T: Texts.Text;  begpat, endpat: ARRAY OF CHAR;  by: Texts.Buffer;  VAR pos0: SIGNED32): BOOLEAN;
	(* replaces part of Text t beginning with begpat ending with endpat by contents of Text by *)
	VAR beg, end: SIGNED32;
BEGIN
	IF FindPattern(T, begpat, Strings.Length(begpat), pos0) THEN
		beg := pos0;
		ASSERT( FindPattern(T, endpat, Strings.Length(endpat), pos0), 104);
		end := pos0 + Strings.Length(endpat);
		Texts.Delete(T, beg, end);
		Texts.Insert(T, beg, by);
		pos0 := beg + by.len;
		RETURN TRUE
	ELSE
		RETURN FALSE
	END
END ReplaceTextPart;

PROCEDURE GetTextPart*(T: Texts.Text;  begpat, endpat: ARRAY OF CHAR; VAR in: Texts.Buffer; VAR pos0: SIGNED32): BOOLEAN;
	VAR beg, end: SIGNED32;
BEGIN
	IF FindPattern(T, begpat, Strings.Length(begpat), pos0) THEN
		beg := pos0;
		ASSERT( FindPattern(T, endpat, Strings.Length(endpat), pos0), 104);
		end := pos0 + Strings.Length(endpat);
		Texts.OpenBuf(in);
		Texts.Save(T, beg+Strings.Length(begpat), end-Strings.Length(endpat),in);
		(* Texts.Insert(T, beg, by);*)
		pos0 := end;
		RETURN TRUE
	ELSE
		RETURN FALSE
	END

END GetTextPart;




BEGIN aM.launch;
END antsTexts.
