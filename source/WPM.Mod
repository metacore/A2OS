MODULE WPM; (** AUTHOR "TF"; PURPOSE "WebPageMaker"; *)

IMPORT
	Commands, Texts, TextUtils := TextUtilities, UTF8Strings, KernelLog, Dates, Strings;

TYPE Text = Texts.Text;

CONST
	contentBegin = "<!-- start -->";
	contentEnd = "<!-- stop -->";
	titleBegin = "<title>";
	titleEnd = "</title>";

	titlePlace = "%title%";
	contentPlace = "%content%";
	changedatePlace = "%changedate%";

PROCEDURE ReplaceString(text : Text; search : ARRAY OF CHAR; replace : Text; sfrom, slen : LONGINT);
VAR pos, len : LONGINT;
	xs : ARRAY 128 OF LONGINT;
BEGIN
	text.AcquireWrite;
	pos := 0; UTF8Strings.UTF8toUnicode(search, xs, pos);
	len := TextUtils.UCS32StrLength(xs);
	REPEAT
		pos := TextUtils.Pos(xs, 0, text);
		IF pos >= 0 THEN text.Delete(pos, len); text.CopyFromText(replace, sfrom, slen, pos) END
	UNTIL pos < 0;
	text.ReleaseWrite
END ReplaceString;

PROCEDURE UTFUCS(src : ARRAY OF CHAR; VAR dst : ARRAY OF LONGINT);
VAR pos : LONGINT;
BEGIN
	pos := 0; UTF8Strings.UTF8toUnicode(src, dst, pos)
END UTFUCS;

PROCEDURE MergeWithTemplate(template, src, date : Text; VAR dst : Text);
VAR tb, te, cb, ce: LONGINT; str : ARRAY 32 OF LONGINT;
BEGIN
	NEW(dst);
	template.AcquireRead; src.AcquireRead; dst.AcquireWrite;

	(* copy template to dst *)
	dst.CopyFromText(template, 0, template.GetLength(), 0);

	(* find title *)
	UTFUCS(titleBegin, str); tb := TextUtils.Pos(str, 0, src); IF tb > 0 THEN INC(tb, TextUtils.UCS32StrLength(str)) END;
	UTFUCS(titleEnd, str); te := TextUtils.Pos(str, 0, src);
	IF (tb >= 0) & (tb < te) THEN ReplaceString(dst, titlePlace, src, tb, te - tb) END;

	(* find content *)
	UTFUCS(contentBegin, str); cb := TextUtils.Pos(str, 0, src); IF cb > 0 THEN INC(cb, TextUtils.UCS32StrLength(str)) END;
	UTFUCS(contentEnd, str); ce := TextUtils.Pos(str, 0, src);
	IF (cb >= 0) & (cb < ce) THEN ReplaceString(dst, contentPlace, src, cb, ce - cb) END;

	IF date # NIL THEN date.AcquireRead; ReplaceString(dst, changedatePlace, date, 0, date.GetLength()); date.ReleaseRead END;
	template.ReleaseRead; src.ReleaseRead; dst.ReleaseWrite;
END MergeWithTemplate;

(** template srcdir dstdir name {name} *)
PROCEDURE Replace*(context : Commands.Context);
VAR srcdir, dstdir, src, dst, name, template, tdate : ARRAY 128 OF CHAR;
	templateT, srcT, dstT, dateT : Text;
	res : WORD;
BEGIN
	context.arg.Token(template); context.arg.SkipWhitespace; context.arg.Token(srcdir); context.arg.SkipWhitespace;
	context.arg.Token(dstdir); context.arg.SkipWhitespace;
	NEW(templateT);
	TextUtils.LoadUTF8(templateT, template, res); ASSERT(res = 0);
	Strings.DateToStr(Dates.Now(), tdate); NEW(dateT); TextUtils.StrToText(dateT, 0, tdate);
	context.arg.Token(name); context.arg.SkipWhitespace;
	WHILE context.arg.res = 0 DO
		KernelLog.String("Processing "); KernelLog.String(name);
		NEW(srcT); NEW(dstT);

		COPY(srcdir, src); Strings.Append(src, name);
		COPY(dstdir, dst); Strings.Append(dst, name);
		TextUtils.LoadUTF8(srcT, src, res);
		IF res = 0 THEN
			MergeWithTemplate(templateT, srcT, dateT, dstT);
			TextUtils.ExportUTF8(dstT, dst, res); ASSERT(res = 0);
			KernelLog.String(" --> "); KernelLog.String(dst); KernelLog.String(" done."); KernelLog.Ln;
		ELSE
			KernelLog.String('"'); KernelLog.String(src); KernelLog.String('"'); KernelLog.String(" not found."); KernelLog.Ln
		END;
		context.arg.Token(name); context.arg.SkipWhitespace
	END;
END Replace;

END WPM.


System.Free WPM TextUtilities Texts ~
