MODULE HostClipboard; (** AUTHOR "staubesv"; PURPOSE "Interface to host system clipboard"; *)
(**
 * This module provides an interface for accessing the host system clipboard (e.g. Windows, Virtual Machine, ...)
 *)

IMPORT
	Texts;

CONST
	Ok* = 0;
	ClipboardNotAvailable* = 1;

TYPE
	ClipboardHandler = PROCEDURE {DELEGATE} (text : Texts.Text);

VAR
	getFromClipboard, putToClipboard : ClipboardHandler;

PROCEDURE Get*(text : Texts.Text; VAR res : INTEGER);
BEGIN {EXCLUSIVE}
	ASSERT((text # NIL) & (text.HasWriteLock()));
	IF (getFromClipboard # NIL) THEN
		getFromClipboard(text);
		res := Ok;
	ELSE
		res := ClipboardNotAvailable;
	END;
END Get;

PROCEDURE Put*(text : Texts.Text; VAR res : INTEGER);
BEGIN {EXCLUSIVE}
	ASSERT((text # NIL) & (text.HasReadLock()));
	IF (putToClipboard # NIL) THEN
		putToClipboard(text);
		res := Ok;
	ELSE
		res := ClipboardNotAvailable;
	END;
END Put;

PROCEDURE SetHandlers*(get, put : ClipboardHandler);
BEGIN {EXCLUSIVE}
	getFromClipboard := get; putToClipboard := put;
END SetHandlers;

END HostClipboard.
