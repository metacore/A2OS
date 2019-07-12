MODULE UndoManager; (** AUTHOR "???"; PURPOSE "Undo/Redo" *)

IMPORT Texts;

CONST
	None = 99;
	CStyle = 100;
	PStyle = 101;
	Attribute = 102;
	SpecialPiece = 103;

	AdvancedUndoStrategy = TRUE;

TYPE

	ListenerProc* = PROCEDURE {DELEGATE} (nrUndos, nrRedos : SIZE);

	UndoManager*= OBJECT(Texts.UndoManager)
		VAR
			text: Texts.Text;
			undoQu, redoQu: Buffer;
			objUpdate: StyleUpdateInfo;
			nrUndoUpdates-, nrRedoUpdates-: SIZE;
			nrUpdatesListener* : ListenerProc;
			redo: BOOLEAN;
			actualPos-: SIZE;

		PROCEDURE & New*(memorySize: SIZE; redo: BOOLEAN);
		BEGIN
			IF memorySize <= 0 THEN memorySize := 1001;END;
			SELF.redo := redo;
			text := NIL;
			NEW(undoQu, memorySize);
			IF redo THEN
				NEW(redoQu, memorySize)
			ELSE
				redoQu := NIL;
			END;
			objUpdate := NIL;
			nrUndoUpdates := 0; nrRedoUpdates := 0;
			nrUpdatesListener := NIL;
			actualPos := 0;
		END New;

		PROCEDURE ResetRedo;
		BEGIN
			nrRedoUpdates := 0;
			redoQu.Clear()
		END ResetRedo;

		PROCEDURE NextOperation(u: UpdateInfo);
		VAR ui: UpdateInfo;
		BEGIN
			IF undoQu.IsFull() THEN
				ui := undoQu.RemoveOldest();
				DEC(nrUndoUpdates);
			END;
			undoQu.Push(u);
			INC(nrUndoUpdates);
		END NextOperation;

		PROCEDURE SaveOperation(u: UpdateInfo);
		BEGIN
			IF ~redo THEN RETURN END;
			redoQu.Push(u);
			INC(nrRedoUpdates);
		END SaveOperation;

		PROCEDURE InsertText*(pos: SIZE; text: Texts.Text);
		VAR i: InsertUpdateInfo; u:UpdateInfo; tr: Texts.TextReader; ucs32: LONGINT;
		BEGIN
			ResetRedo;
			text.AcquireRead;
			IF ~(undoQu.IsEmpty()) & (undoQu.Peek()  IS InsertUpdateInfo) & (text.GetLength() = 1) THEN
				u := undoQu.Peek();
				i := u(InsertUpdateInfo);
				IF (~u.sealed) & (i.pos + i.len = pos) THEN
					i.t.AcquireWrite;
					i.t.CopyFromText(text, 0, text.GetLength(), i.len);
					i.len := i.len + text.GetLength();
					i.t.ReleaseWrite;

					NEW(tr, text);
					tr.ReadCh(ucs32);
					IF IsSeparator(ucs32) THEN i.sealed := TRUE END;
					text.ReleaseRead;

					RETURN
				END
			END;
			text.ReleaseRead;
			NEW(i, pos, text);
			NextOperation(i);
		END InsertText;

		PROCEDURE DeleteText*(pos: SIZE; text: Texts.Text);
		VAR d: DeleteUpdateInfo; u: UpdateInfo;
		BEGIN
			ResetRedo;
			text.AcquireRead;
			IF (~ undoQu.IsEmpty()) & (undoQu.Peek() IS DeleteUpdateInfo) & (text.GetLength() = 1) THEN
				u := undoQu.Peek();
				d := u(DeleteUpdateInfo);
				IF (d.pos = pos) THEN (* Delete key *)
					d.t.AcquireWrite;
					d.t.CopyFromText(text, 0, text.GetLength(),d.len);
					d.len := d.len + text.GetLength();
					d.t.ReleaseWrite;
					RETURN
				ELSIF (d.pos - 1 = pos) THEN (* Backspace key *)
					d.t.AcquireWrite;
					d.t.CopyFromText(text, 0, text.GetLength(), 0);
					d.pos := pos;
					d.len := d.len + text.GetLength();
					d.t.ReleaseWrite;
					RETURN
				END;
			END;
			text.ReleaseRead;

			NEW(d, pos, text);
			NextOperation(d);
		END DeleteText;

		PROCEDURE BeginObjectChange*(pos: SIZE);
		BEGIN
			NEW(objUpdate, pos);
		END BeginObjectChange;

		PROCEDURE ObjectChanged*(pos, len: SIZE; type: WORD; obj: ANY);
		BEGIN
			objUpdate.Append(pos, len, obj, type)
		END ObjectChanged;

		PROCEDURE EndObjectChange*(len: SIZE; type: WORD; to: ANY);
		BEGIN
			ResetRedo;
			objUpdate.len := len;
			objUpdate.type := type;
			objUpdate.new := to;
			NextOperation(objUpdate);
			objUpdate := NIL
		END EndObjectChange;

		PROCEDURE SetText*(text: Texts.Text);
		BEGIN
			SELF.text := text;
		END SetText;

		PROCEDURE Undo*;
		VAR temp: Texts.Text; ui: UpdateInfo;
		BEGIN
			temp := SELF.text;
			IF temp # NIL THEN
				temp.AcquireWrite;
				IF ~ undoQu.IsEmpty() THEN
					ui := undoQu.Pop();
					temp.SetUndoManager(NIL); (* Disable recording *)
					ui.Undo(temp);
					temp.SetUndoManager(SELF); (* Re-enable recording *)
					DEC(nrUndoUpdates);
					SaveOperation(ui);
					actualPos := ui.pos;
				END;
				temp.ReleaseWrite
			END
		END Undo;

		PROCEDURE Redo*;
		VAR temp: Texts.Text; ui: UpdateInfo;
		BEGIN
			IF ~redo THEN RETURN END;
			temp := SELF.text;
			IF temp # NIL THEN
				temp.AcquireWrite;
				IF ~ redoQu.IsEmpty() THEN
					ui := redoQu.Pop();
					temp.SetUndoManager(NIL); (* Disable recording *)
					ui.Redo(temp);
					temp.SetUndoManager(SELF); (* Re-enable recording *)
					DEC(nrRedoUpdates);
					NextOperation(ui);
					actualPos := ui.pos;
				END;
				temp.ReleaseWrite
			END
		END Redo;

		PROCEDURE InformListeners*;
		VAR l : ListenerProc;
		BEGIN
			l := nrUpdatesListener;
			IF (l # NIL) THEN l(nrUndoUpdates, nrRedoUpdates); END;
		END InformListeners;

	END UndoManager;

	Buffer = OBJECT
		VAR head, num: SIZE; buffer: POINTER TO ARRAY OF UpdateInfo;

		PROCEDURE Push*(x: UpdateInfo);
		BEGIN
			ASSERT(num <= LEN(buffer));
			buffer[(head+num) MOD LEN(buffer)] := x;
			INC(num)
		END Push;

		PROCEDURE RemoveOldest*(): UpdateInfo;
		VAR x: UpdateInfo;
		BEGIN
			x := buffer[head];
			head := (head+1) MOD LEN(buffer);
			DEC(num);
			RETURN x
		END RemoveOldest;

		PROCEDURE Peek*(): UpdateInfo;
		BEGIN
			RETURN buffer[((head+num - 1) MOD LEN(buffer))]
		END Peek;

		PROCEDURE Pop*(): UpdateInfo;
		VAR x: UpdateInfo;
		BEGIN
			x := buffer[((head+num - 1) MOD LEN(buffer))];
			DEC(num);
			RETURN x
		END Pop;

		PROCEDURE IsFull*(): BOOLEAN;
		BEGIN
			RETURN num = LEN(buffer)
		END IsFull;

		PROCEDURE IsEmpty*(): BOOLEAN;
		BEGIN
			RETURN num = 0
		END IsEmpty;

		PROCEDURE Clear*;
		BEGIN
			head := 0; num := 0;
		END Clear;

		PROCEDURE &Init*(n: SIZE);
		BEGIN
			head := 0; num := 0; NEW(buffer, n)
		END Init;

	END Buffer;

	UpdateInfo= OBJECT
		VAR
			pos : SIZE;
			sealed*: BOOLEAN;

		PROCEDURE Undo(text: Texts.Text); (* abstract *)
		END Undo;

		PROCEDURE Redo(text: Texts.Text); (* abstract *)
		END Redo;

	END UpdateInfo;

TYPE

	InsertUpdateInfo= OBJECT(UpdateInfo)
		VAR
			len: SIZE;
			t: Texts.Text;

		PROCEDURE &New*(pos: SIZE; text: Texts.Text);
		BEGIN
			SELF.pos := pos;
			SELF.t := text;
			t.AcquireRead;
			SELF.len := t.GetLength();
			t.ReleaseRead;
		END New;

		PROCEDURE Undo(text: Texts.Text);
		BEGIN
			t.AcquireRead;
			text.Delete(pos, t.GetLength());
			t.ReleaseRead;
		END Undo;

		PROCEDURE Redo(text: Texts.Text);
		BEGIN
			t.AcquireRead;
			text.CopyFromText(t, 0, t.GetLength(), pos);
			t.ReleaseRead;
		END Redo;

	END InsertUpdateInfo;

	DeleteUpdateInfo= OBJECT(UpdateInfo)
		VAR
			len: SIZE;
			t: Texts.Text;

		PROCEDURE &New*(pos: SIZE; text: Texts.Text);
		BEGIN
			SELF.pos := pos;
			SELF.t := text;
			t.AcquireRead;
			SELF.len := t.GetLength();
			t.ReleaseRead;
		END New;

		PROCEDURE Undo(text: Texts.Text);
		BEGIN
			t.AcquireRead;
			text.CopyFromText(t, 0, t.GetLength(), pos);
			t.ReleaseRead;
		END Undo;

		PROCEDURE Redo(text: Texts.Text);
		BEGIN
			t.AcquireRead;
			text.Delete(pos, t.GetLength());
			t.ReleaseRead;
		END Redo;

	END DeleteUpdateInfo;


	StyleInfo= POINTER TO RECORD
		next: StyleInfo;
		pos, len: SIZE;
		style: ANY;
		type: WORD;
	END;


	StyleUpdateInfo= OBJECT(UpdateInfo)
		VAR
			len: SIZE;
			type: WORD;
			new: ANY;
			old: StyleInfo;

		PROCEDURE &New*(pos: SIZE);
		BEGIN
			SELF.pos := pos;
		END New;

		PROCEDURE Append(pos, len: SIZE; style: ANY; type: WORD);
		VAR ai: StyleInfo;
		BEGIN
			NEW(ai);
			ai.next := old;
			ai.pos := pos;
			ai.len := len;
			ai.style := style;
			ai.type := type;
			old := ai
		END Append;

		PROCEDURE SetObject(new: ANY);
		BEGIN
			SELF.new := new;
		END SetObject;

		PROCEDURE SetLen(len: SIZE);
		BEGIN
			SELF.len := len;
		END SetLen;

		PROCEDURE SetStyle*(textpos, len: SIZE; style: ANY);
		END SetStyle;

		PROCEDURE Undo(text: Texts.Text);
		VAR cur: StyleInfo;
		BEGIN
			cur := old;
			WHILE cur # NIL DO
				CASE cur.type OF
					Attribute:
						IF cur.style # NIL THEN
							text.SetAttributes(cur.pos, cur.len, cur.style(Texts.Attributes))
						ELSE
							text.SetAttributes(cur.pos, cur.len, NIL)
						END
					| CStyle:
						IF cur.style # NIL THEN
							text.SetCharacterStyle(cur.pos, cur.len, cur.style(Texts.CharacterStyle))
						ELSE
							text.SetCharacterStyle(cur.pos, cur.len, NIL)
						END
					| PStyle:
						IF cur.style # NIL THEN
							text.SetParagraphStyle(cur.pos, cur.len, cur.style(Texts.ParagraphStyle))
						ELSE
							text.SetParagraphStyle(cur.pos, cur.len, NIL)
						END
				END;
				cur := cur.next;
			END;
		END Undo;

		PROCEDURE Redo(text: Texts.Text);
		BEGIN
			CASE type OF
				Attribute:
					IF new # NIL THEN
						text.SetAttributes(pos, len, new(Texts.Attributes))
					ELSE
						text.SetAttributes(pos, len, NIL)
					END
				| CStyle:
					IF new # NIL THEN
						text.SetCharacterStyle(pos, len, new(Texts.CharacterStyle))
					ELSE
						text.SetCharacterStyle(pos, len, NIL)
					END
				| PStyle:
					IF new # NIL THEN
						text.SetParagraphStyle(pos, len, new(Texts.ParagraphStyle))
					ELSE
						text.SetParagraphStyle(pos, len, NIL)
					END
			END
		END Redo;

	END StyleUpdateInfo;


PROCEDURE IsSeparator(uc: Texts.Char32): BOOLEAN;
BEGIN
	CASE uc OF
		 Texts.NewLineChar: RETURN TRUE
		 | Texts.TabChar: IF AdvancedUndoStrategy THEN RETURN TRUE ELSE RETURN FALSE END
		 | Texts.SpaceChar: IF AdvancedUndoStrategy THEN RETURN TRUE ELSE RETURN FALSE END
	ELSE
		RETURN FALSE;
	END
END IsSeparator;

END UndoManager.
