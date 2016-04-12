MODULE WMInterpreterShell; (** AUTHOR "staubesv"; PURPOSE "GUI for shell"; *)
(**
 * Usage:
 *
 *	WMShell.Open ~ opens new shell
 *	SystemTools.Free WMShell ~ closes all open shells
 *
 * History:
 *
 *	25.06.2007	First release (staubesv)
 *
 * TODO:
 * 	- nice shutdown when freeing module
 *)

IMPORT
	Shell := InterpreterShell, Streams, Pipes, Texts, TextUtilities, Strings,
	Modules, Kernel, Inputs,
	WMGraphics, WMWindowManager, WMMessages, WMRestorable,
	WMComponents, WMDocumentEditor;

CONST

	(* Default size of window at start up *)
	DefaultWidth = 640; DefaultHeight = 300;

	ReceiveBufferSize = 256;

	Prompt = "SHELL>";

	Backspace = 08X;
	ESC = 1BX;
	DEL = 7FX;

TYPE

	ShellComponent = OBJECT(WMComponents.VisualComponent)
	VAR
		out : Streams.Writer;
		in : Streams.Reader;

		pipeOut, pipeIn : Pipes.Pipe;

		(* Terminal window text writer *)
		w : TextUtilities.TextWriter;
		text : Texts.Text;

		shell : Shell.Shell;

		editor : WMDocumentEditor.Editor;

		running, dead : BOOLEAN;
		timer : Kernel.Timer;

		PROCEDURE Clear;
		BEGIN
			editor.Clear;
			Invalidate;
		END Clear;

		PROCEDURE ExtPointerUp(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		BEGIN
			text.AcquireRead;
			editor.editor.tv.cursor.SetPosition(text.GetLength());
			text.ReleaseRead;
		END ExtPointerUp;

		PROCEDURE ExtKeyPressed(ucs : LONGINT; flags : SET; VAR keySym : LONGINT; VAR handled : BOOLEAN);
		BEGIN
			handled := FALSE;
			IF editor.HandleShortcut(ucs, flags, keySym) THEN handled := TRUE; END;

			IF ~handled & ~(Inputs.Release IN flags) THEN
				handled := TRUE;
				IF keySym = 01H THEN (* Ctrl-A *)
					editor.editor.tv.SelectAll
				ELSIF keySym = 03H THEN (* Ctrl-C *)
					editor.editor.tv.CopySelection
				ELSIF keySym = 16H THEN (* Ctrl-V *)
					CopyFromClipboard;
	 			ELSIF (keySym = 0FF63H) & (flags * Inputs.Ctrl # {}) THEN  (*Ctrl Insert *)
	 				editor.editor.tv.CopySelection
				ELSIF keySym = 0FF56H THEN (* Page Down *)
					editor.editor.tv.PageDown(flags * Inputs.Shift # {})
				ELSIF keySym = 0FF55H THEN (* Page Up *)
					editor.editor.tv.PageUp(flags * Inputs.Shift # {})
				ELSIF keySym = 0FF50H THEN (* Cursor Home *)
					editor.editor.tv.Home(flags * Inputs.Ctrl # {}, flags * Inputs.Shift # {})
				ELSIF keySym = 0FF57H THEN (* Cursor End *)
					editor.editor.tv.End(flags * Inputs.Ctrl # {}, flags * Inputs.Shift # {})
				ELSIF keySym = 0FF1BH THEN (* Esc *)
					IF ~(Inputs.Release IN flags) THEN
						out.Char(ESC); out.Char(ESC); out.Update;
					END;
				ELSE
					handled := FALSE;
				END
			END;

			IF ~handled & (ucs > 0) & (ucs < 256) THEN
				IF ~(Inputs.Release IN flags) THEN
					IF ucs > 127 THEN (* Escape non-ascii characters *)
						out.Char(ESC); out.Char("["); ucs := ucs - 128;
					END;
					out.Char(CHR(ucs)); out.Update;
				END;
				handled := TRUE;
			END;
		END ExtKeyPressed;

		PROCEDURE Wait(ms : LONGINT);
		BEGIN
			timer.Sleep(ms);
		END Wait;

		PROCEDURE InitShell;
		VAR shellIn : Streams.Reader; shellOut : Streams.Writer;
		BEGIN
			NEW(pipeOut, 256); NEW(pipeIn, 256);

			(* wire pipes *)
			NEW(shellIn, pipeOut.Receive, 256);
			NEW(shellOut, pipeIn.Send, 256);

			NEW(out, pipeOut.Send, 256);
			NEW(in, pipeIn.Receive, 256);

			NEW(shell, shellIn,shellOut, shellOut, TRUE, Prompt);
		END InitShell;

		PROCEDURE CopyFromClipboard;
		VAR string : POINTER TO ARRAY OF CHAR;
		BEGIN
			Texts.clipboard.AcquireRead;
			IF Texts.clipboard.GetLength() > 0 THEN
				NEW(string, Texts.clipboard.GetLength()+1);
				TextUtilities.TextToStr(Texts.clipboard, string^);
			END;
			Texts.clipboard.ReleaseRead;
			out.String(string^); out.Update;
		END CopyFromClipboard;

		PROCEDURE Finalize;
		BEGIN
(*			pipeIn.Close; pipeOut.Close; *)
			shell.Exit;
			BEGIN {EXCLUSIVE}
				running := FALSE;
				AWAIT(dead);
			END;
		END Finalize;

		PROCEDURE DeleteNCharacters(nbrOfCharacters : LONGINT);
		VAR pos : LONGINT;
		BEGIN
			text.AcquireWrite;
			pos := editor.editor.tv.cursor.GetPosition();
			text.Delete(pos - nbrOfCharacters, nbrOfCharacters);
			text.ReleaseWrite;
		END DeleteNCharacters;

		PROCEDURE ReceiveCharacters;
		VAR ch : CHAR; buffer : ARRAY ReceiveBufferSize OF CHAR; backspaces, i, size, len : LONGINT;
		BEGIN
			(* Receive at least one character *)
			size := in.Available();
			IF size > ReceiveBufferSize THEN size := ReceiveBufferSize; END;
			in.Bytes(buffer, 0, size, len);
			IF in.res = Streams.Ok THEN
				FOR i := 0 TO len-1 DO
					ch := buffer[i];
					IF (ch = DEL) OR (ch = Backspace) THEN
						INC(backspaces);
					ELSE
						IF (backspaces > 0) THEN
							w.Update;
							DeleteNCharacters(backspaces);
							backspaces := 0;
						END;
						w.Char(ch);
					END;
				END;
				w.Update;
			END;
			DeleteNCharacters(backspaces);
		END ReceiveCharacters;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			running := TRUE;
			NEW(timer);

			NEW(editor); editor.alignment.Set(WMComponents.AlignClient);
			editor.SetToolbar(WMDocumentEditor.StoreButton + WMDocumentEditor.WrapButton + WMDocumentEditor.SearchButton + WMDocumentEditor.ClearButton);
			editor.editor.tv.SetExtKeyEventHandler(ExtKeyPressed);
			editor.editor.tv.SetExtPointerUpHandler(ExtPointerUp);
			AddContent(editor);

			NEW(text);
			NEW(w, text); w.SetFontName("Courier");
			editor.SetText(text);
			InitShell;
			SetNameAsString(StrShellComponent);
		END Init;

	BEGIN {ACTIVE}
		WHILE running DO
			IF running & (in.Available() > 0) THEN ReceiveCharacters; END;
			Wait(2);
		END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END ShellComponent;

TYPE

	KillerMsg = OBJECT
	END KillerMsg;

	Window* = OBJECT (WMComponents.FormWindow)
	VAR
		shell : ShellComponent;

		PROCEDURE HandleUpcall(command : LONGINT);
		BEGIN
			IF command = Shell.Clear THEN
				shell.Clear;
			ELSIF command = Shell.ExitShell THEN
				Close;
			END;
		END HandleUpcall;

		PROCEDURE &New*(c : WMRestorable.Context);
		BEGIN
			IncCount;

			NEW(shell); shell.alignment.Set(WMComponents.AlignClient);
			shell.shell.SetUpcall(HandleUpcall);

			Init(DefaultWidth, DefaultHeight, FALSE);

			SetContent(shell);
			SetTitle(Strings.NewString("BlueShell"));
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://WMShell.png", TRUE));

			IF c # NIL THEN
				WMRestorable.AddByContext(SELF, c);
				Resized(GetWidth(), GetHeight());
			ELSE
				WMWindowManager.DefaultAddWindow(SELF);
			END;
			shell.editor.editor.SetFocus();
		END New;

		PROCEDURE Close;
		BEGIN
			Close^;
			DecCount
		END Close;

		PROCEDURE Handle(VAR x : WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS KillerMsg) THEN
					Close;
				ELSIF (x.ext IS WMRestorable.Storage) THEN
					x.ext(WMRestorable.Storage).Add("Shell", "WMShell.Restore", SELF, NIL);
				ELSE
					Handle^(x);
				END;
			ELSE Handle^(x)
			END
		END Handle;

	END Window;

VAR
	nofWindows : LONGINT;

	StrShellComponent : Strings.String;

PROCEDURE InitStrings;
BEGIN
	StrShellComponent := Strings.NewString("ShellComponent");
END InitStrings;

PROCEDURE Restore*(context : WMRestorable.Context);
VAR window : Window;
BEGIN
	ASSERT(context # NIL);
	NEW(window, context);
END Restore;

PROCEDURE Open*;
VAR window : Window;
BEGIN
	NEW(window, NIL);
END Open;

PROCEDURE IncCount;
BEGIN {EXCLUSIVE}
	INC(nofWindows)
END IncCount;

PROCEDURE DecCount;
BEGIN {EXCLUSIVE}
	DEC(nofWindows)
END DecCount;

PROCEDURE Cleanup;
VAR die : KillerMsg;
	 msg : WMMessages.Message;
	 m : WMWindowManager.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die);
	msg.ext := die;
	msg.msgType := WMMessages.MsgExt;
	m := WMWindowManager.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0)
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	InitStrings;
END WMInterpreterShell.

WMShell.Open ~

SystemTools.Free WMShell ~
SystemTools.Free WMShell Shell ~