MODULE vyOut IN Oberon;
(* Copyright notice:

This file is part of Voyager
Copyright (C) 1993-2002 Project Voyager, StatLab Heidelberg ; (C) 1993-2002 G. Sawitzki et al.

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
Report any problems as soon as possible to voyager@statlab.uni-heidelberg.de
*)


IMPORT Texts, vyBase, vyHostTexts;

	VAR w: vyBase.TextsWriter;
PROCEDURE tab*;  	BEGIN Texts.Write(w, 09X)  END tab;
PROCEDURE Flush;   BEGIN vyHostTexts.InsertLog(w.buf) END Flush;

PROCEDURE Char* (ch: CHAR);
BEGIN Texts.Write(w, ch);   vyHostTexts.InsertLog(w.buf) END Char;

PROCEDURE String* (str: ARRAY OF CHAR);
BEGIN Texts.WriteString(w, str);   vyHostTexts.InsertLog(w.buf) END String;

PROCEDURE Int* (i, n: LONGINT);
BEGIN Texts.WriteInt(w, i, n);   vyHostTexts.InsertLog(w.buf) END Int;

PROCEDURE Real* (x: REAL;   n: INTEGER);
BEGIN Texts.WriteReal(w, x, n);   vyHostTexts.InsertLog(w.buf) END Real;

PROCEDURE LongReal* (x: LONGREAL;   n: INTEGER);
BEGIN Texts.WriteLongReal(w, x, n);   vyHostTexts.InsertLog(w.buf) END LongReal;

PROCEDURE Ln*;
BEGIN Texts.WriteLn(w);   vyHostTexts.InsertLog(w.buf) END Ln;

PROCEDURE Mean* (x: LONGREAL);
BEGIN Texts.WriteString(w, 'Mean=');  tab;  Texts.WriteReal(w, SHORT(x), 0);  Flush  END Mean;

PROCEDURE Open*;
BEGIN vyHostTexts.DoOpenLog('Output')
END Open;

BEGIN
	Texts.OpenWriter(w);
END vyOut.