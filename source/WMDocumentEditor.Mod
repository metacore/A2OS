MODULE WMDocumentEditor; (** AUTHOR "staubesv"; PURPOSE "Document editor component"; *)

IMPORT
	KernelLog, Streams, Files, Inputs, Strings, XML, XMLObjects, Configuration, Texts, TextUtilities, Codecs,
	WMMacros, WMGraphics, WMRectangles, WMMessages, WMComponents, WMStandardComponents,
	WMPopups, WMTextView, WMEditors, WMSearchComponents, WMDialogs, WMRestorable;

CONST
	LoadButton* = {0};
	StoreButton* = {1};
	FormatButton*= {2};
	SearchButton* = {3};
	WrapButton* = {4};
	ClearButton* = {5};

	All* = {0..31};

	DefaultTextEncoder = "Oberon";

TYPE

	CaptionObject = OBJECT
	VAR
		caption : ARRAY 100 OF CHAR;

		PROCEDURE &New*(CONST caption : ARRAY OF CHAR);
		BEGIN
			COPY(caption, SELF.caption);
		END New;

	END CaptionObject;

TYPE

	Editor* = OBJECT(WMComponents.VisualComponent)
	VAR
		editor- : WMEditors.Editor;

		toolbar : WMStandardComponents.Panel;

		filenamePanel : WMStandardComponents.Panel;
		filenameEdit : WMEditors.Editor;
		resizer : WMStandardComponents.Resizer;
		loadBtn, storeBtn, formatBtn : WMStandardComponents.Button;

		searchBtn : WMStandardComponents.Button;
		searchPanel : WMSearchComponents.SearchPanel;

		wrapBtn, clearBtn : WMStandardComponents.Button;

		popup : WMPopups.Popup;

		lastFilename : Files.FileName;
		codecFormat : ARRAY 100 OF CHAR;
		autoCodecFormat : ARRAY 100 OF CHAR;

		wordWrap, modified : BOOLEAN;

		buttons : SET;

		PROCEDURE FilenameEscapeHandler(sender, data : ANY);
		BEGIN
			filenameEdit.SetAsString(lastFilename);
		END FilenameEscapeHandler;

		PROCEDURE LoadHandler(sender, data : ANY);
		VAR filename : Files.FileName;
		BEGIN
			filenameEdit.GetAsString(filename);
			Strings.TrimWS(filename);
			IF (filename # "") THEN
				Load(filename, codecFormat);
			END;
		END LoadHandler;

		PROCEDURE Load*(CONST filename,  format : ARRAY OF CHAR);
		VAR
			text : Texts.Text;
			msg : ARRAY 512 OF CHAR; res : INTEGER;
			name, fullname, archiveName, entryName : Files.FileName;
			decoder : Codecs.TextDecoder;
			in : Streams.Reader;
			file : Files.File;
		BEGIN
			res := -1;
			Codecs.SplitName(filename, archiveName, entryName);
			IF (archiveName # "") THEN
				COPY(archiveName, name);
			ELSE
				COPY(filename, name);
			END;
			COPY(name, fullname);

			(* Check whether file exists and get its canonical name *)
			file := Files.Old(name);
			IF (file # NIL) THEN
				file.GetName(fullname);
			ELSE
				file := Files.New(filename); (* to get path *)
				IF (file # NIL) THEN
					file.GetName(fullname);
					file := NIL;
				END;
			END;

			IF (archiveName # "") THEN Codecs.JoinName(fullname, entryName, fullname); END;

			IF (filenameEdit # NIL) THEN
				filenameEdit.SetAsString(fullname);
				lastFilename := fullname;
			END;

			text := editor.text;
			text.AcquireWrite;
			modified := TRUE; (* avoid the ! on the store button while loading *)
			text.Delete(0, text.GetLength());
			editor.tv.firstLine.Set(0);
			text.ReleaseWrite;

			IF (file # NIL) THEN
				IF (format = "AUTO") THEN
					decoder := TextUtilities.DecodeAuto(fullname, autoCodecFormat);
				ELSE
					decoder := Codecs.GetTextDecoder(format);
				END;

				IF decoder # NIL THEN
					COPY(format, codecFormat);
					in := Codecs.OpenInputStream(fullname);
					IF in # NIL THEN
						decoder.Open(in, res);
						IF res = 0 THEN
							editor.text.onTextChanged.Remove(TextChanged);
							SetText(decoder.GetText());
							editor.text.onTextChanged.Add(TextChanged);
						END;
					ELSE
						msg := "Can't open input stream on file "; Strings.Append(msg, fullname);
						WMDialogs.Error("Error", msg);
					END;
				ELSE
					msg := "No decoder for file "; Strings.Append(msg, fullname);
					Strings.Append(msg, " (Format: "); Strings.Append(msg, format); Strings.Append(msg, ")");
					WMDialogs.Error("Error", msg);
				END;
			END;

			SetFormatCaption(format);
			editor.tv.firstLine.Set(0);
			editor.tv.cursor.SetPosition(0);
			editor.tv.SetFocus;
			modified := FALSE;
			IF (buttons * StoreButton # {}) THEN storeBtn.caption.SetAOC("::System:ButtonTitles:SStore") END;
		END Load;

		PROCEDURE StoreHandler(sender, data : ANY);
		VAR filename : Files.FileName;
		BEGIN
			filenameEdit.GetAsString(filename);
			Strings.TrimWS(filename);
			IF filename # "" THEN
				Store(filename, codecFormat);
			ELSE
				WMDialogs.Error("Error", "Filename invalid"); (* ignore res *)
				filenameEdit.SetAsString(filename);
			END;
		END StoreHandler;

		PROCEDURE Store*(CONST filename,format : ARRAY OF CHAR);
		VAR
			name, backName, fullname, archiveName, entryName : Files.FileName;
			msg : ARRAY 512 OF CHAR; res : INTEGER;
			encoder : Codecs.TextEncoder;
			w : Streams.Writer;
			f : Files.File;
		BEGIN
			IF (filenameEdit # NIL) THEN filenameEdit.SetAsString(filename); END;

			Codecs.SplitName(filename, archiveName, entryName);
			IF (archiveName # "") THEN
				COPY(archiveName, name);
			ELSE
				COPY(filename, name);
			END;
			COPY(name, fullname);

			f := Files.Old(name);
			IF (f # NIL) THEN
				IF (Files.ReadOnly IN f.flags) THEN
					msg := "File is read-only: "; Strings.Append(msg, filename);
					WMDialogs.Error("Error", msg);
					RETURN;
				END;

				IF (archiveName = "") THEN (*! create backup *)
					Strings.Concat(filename, ".Bak", backName);
					Files.Rename(filename, backName, res);
					IF res = 0 THEN KernelLog.String("Backup created  in "); KernelLog.String(backName); KernelLog.Ln END;
				END;
			END;

			IF (format = "AUTO") THEN
				IF (autoCodecFormat = "") THEN
					encoder := Codecs.GetTextEncoder(DefaultTextEncoder);
				ELSE
					encoder := Codecs.GetTextEncoder(autoCodecFormat);
				END;
			ELSE
				encoder := Codecs.GetTextEncoder(format);
			END;

			IF (encoder # NIL) THEN
				IF (archiveName = "") OR ( f = NIL ) THEN
					f := Files.New(name);
					IF (f = NIL) THEN
						msg := "Could not create f "; Strings.Append(msg, name);
						WMDialogs.Error("Error", msg);
						RETURN;
					END;
				END;

				f.GetName(fullname);
				IF (archiveName # "") THEN Codecs.JoinName(fullname, entryName, fullname); END;
				IF (filenameEdit # NIL) THEN filenameEdit.SetAsString(fullname); END;
				w := Codecs.OpenOutputStream(fullname);

				encoder.Open(w);
				editor.text.AcquireWrite;
				encoder.WriteText(editor.text, res);
				editor.text.ReleaseWrite;
				w.Update;
				IF res # 0 THEN
					msg := "Could not encode file "; Strings.Append(msg, fullname);
					WMDialogs.Error("Error", msg);
				END;
			ELSE
				msg := "Could not store file "; Strings.Append(msg, fullname); Strings.Append(msg, " (No encoder found)");
				WMDialogs.Error("Error", msg);
			END;

			modified := FALSE;

			IF (buttons * StoreButton # {}) THEN storeBtn.caption.SetAOC("::System:ButtonTitles:SStore") END;
		END Store;

		PROCEDURE FormatHandler(x, y : SIZE; keys : SET; VAR handled : BOOLEAN);
		VAR rectangle : WMRectangles.Rectangle; left, top : SIZE;
		BEGIN
			IF (formatBtn = NIL) THEN RETURN END;
			handled := TRUE;
			rectangle := formatBtn.bounds.Get();
			ToWMCoordinates(rectangle.l, rectangle.t, left, top);
			popup.Popup(left, top + formatBtn.bounds.GetHeight());
		END FormatHandler;

		PROCEDURE SetFormatCaption(CONST format : ARRAY OF CHAR);
		VAR caption : ARRAY 128 OF CHAR;
		BEGIN
			IF (formatBtn = NIL) THEN RETURN END;
			caption := "::System:ButtonTitles::SFormat::SColon: ";
			IF format = "AUTO" THEN
				Strings.Append(caption, ":SAUTO: "); Strings.Append(caption, autoCodecFormat)
			ELSE
				Strings.Append(caption, format)
			END;
			formatBtn.caption.SetAOC(caption);
			formatBtn.Invalidate;
		END SetFormatCaption;

		PROCEDURE FormatPopupHandler(sender, data : ANY);
		BEGIN
			IF (popup # NIL) & (data # NIL) & (data IS CaptionObject) THEN
				popup.Close;
				COPY(data(CaptionObject).caption, codecFormat);
				SetFormatCaption(codecFormat);
			END;
		END FormatPopupHandler;

		PROCEDURE SearchHandler(sender, data : ANY);
		VAR searchString : WMSearchComponents.SearchString;
		BEGIN
			EnsureSearchPanel;
			searchPanel.visible.Set(TRUE);
			searchPanel.SetToLastSelection;
			searchPanel.searchEdit.GetAsString(searchString);
			IF (searchString # "") THEN
				searchPanel.SearchHandler(NIL, NIL);
			ELSE
				searchPanel.searchEdit.SetFocus;
			END;
		END SearchHandler;

		PROCEDURE WrapHandler(sender, data : ANY);
		BEGIN
			SetWordWrap(~wordWrap);
		END WrapHandler;

		PROCEDURE SetWordWrap*(wordWrap : BOOLEAN);
		BEGIN
			SELF.wordWrap := wordWrap;
			IF wordWrap THEN
				editor.tv.wrapMode.Set(WMTextView.WrapWord);
			ELSE
				editor.tv.wrapMode.Set(WMTextView.NoWrap);
			END;
			IF (wrapBtn # NIL) THEN wrapBtn.SetPressed(wordWrap); END;
		END SetWordWrap;

		PROCEDURE ClearHandler(sender, data : ANY);
		BEGIN
			Clear;
		END ClearHandler;

		PROCEDURE Clear*;
		BEGIN
			editor.text.AcquireWrite;
			editor.text.Delete(0, editor.text.GetLength());
			editor.tv.firstLine.Set(0); editor.tv.cursor.SetPosition(0);
			editor.text.ReleaseWrite;
		END Clear;

		PROCEDURE TextChanged(sender, data : ANY);
		BEGIN
			IF (buttons * StoreButton # {}) & ~modified THEN
				storeBtn.caption.SetAOC("::System:ButtonTitles::SStore:!");
				modified := TRUE
			END
		END TextChanged;

		PROCEDURE SetText*(text : Texts.Text);
		BEGIN
			IF (editor.text # NIL) THEN
				editor.text.onTextChanged.Remove(TextChanged);
			END;
			text.onTextChanged.Add(TextChanged);
			editor.SetText(text);
			IF (searchPanel # NIL) THEN searchPanel.SetText(text); END;
		END SetText;

		PROCEDURE SetToolbar*(buttons : SET);
		BEGIN
			SELF.buttons := buttons;
			IF (buttons * LoadButton # {}) OR (buttons * StoreButton # {}) THEN
				NEW(filenamePanel);
				filenamePanel.alignment.Set(WMComponents.AlignLeft);
				filenamePanel.bounds.SetWidth(200);
				toolbar.AddInternalComponent(filenamePanel);

				NEW(resizer);
				resizer.alignment.Set(WMComponents.AlignRight);
				resizer.bounds.SetWidth(5);
				filenamePanel.AddInternalComponent(resizer);

				NEW(filenameEdit);
				filenameEdit.alignment.Set(WMComponents.AlignClient);
				filenameEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
				filenameEdit.multiLine.Set(FALSE);
				filenameEdit.tv.showBorder.Set(TRUE);
				filenameEdit.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
				filenamePanel.AddInternalComponent(filenameEdit); filenameEdit.fillColor.Set(SIGNED32(0FFFFFFFFH));
				filenameEdit.onEscape.Add(FilenameEscapeHandler);

				IF (buttons * LoadButton # {}) THEN
					filenameEdit.onEnter.Add(LoadHandler);
					NEW(loadBtn);
					loadBtn.caption.SetAOC("::System:ButtonTitles:SLoad"); loadBtn.alignment.Set(WMComponents.AlignLeft);
					loadBtn.onClick.Add(LoadHandler); loadBtn.bounds.SetWidth(80);
					toolbar.AddInternalComponent(loadBtn);
				END;

				IF (buttons * StoreButton # {}) THEN
					NEW(storeBtn);
					storeBtn.caption.SetAOC("::System:ButtonTitles:SStore"); storeBtn.alignment.Set(WMComponents.AlignLeft);
					storeBtn.onClick.Add(StoreHandler); storeBtn.bounds.SetWidth(80);
					toolbar.AddInternalComponent(storeBtn);
				END;

				IF (buttons * FormatButton # {}) THEN
					NEW(formatBtn);
					formatBtn.caption.SetAOC("Format"); formatBtn.alignment.Set(WMComponents.AlignLeft);
					formatBtn.SetExtPointerDownHandler(FormatHandler);
					formatBtn.bounds.SetWidth(3 * formatBtn.bounds.GetWidth());
					toolbar.AddInternalComponent(formatBtn);

					SetFormatCaption("AUTO");
				END;
			END;

			IF (buttons * WrapButton # {}) THEN
				NEW(wrapBtn);
				wrapBtn.caption.SetAOC("::System:ButtonTitles:SWordWrap"); wrapBtn.alignment.Set(WMComponents.AlignLeft);
				wrapBtn.isToggle.Set(TRUE); wrapBtn.SetPressed(wordWrap);
				wrapBtn.onClick.Add(WrapHandler); wrapBtn.bounds.SetWidth(80);
				toolbar.AddInternalComponent(wrapBtn);
			END;

			IF (buttons * ClearButton # {}) THEN
				NEW(clearBtn);
				clearBtn.caption.SetAOC("::System:ButtonTitles:SClear"); clearBtn.alignment.Set(WMComponents.AlignRight);
				clearBtn.onClick.Add(ClearHandler); clearBtn.bounds.SetWidth(80);
				toolbar.AddInternalComponent(clearBtn);
			END;

			IF (buttons * SearchButton # {}) THEN
				NEW(searchBtn);
				searchBtn.alignment.Set(WMComponents.AlignRight);
				searchBtn.SetCaption("::System:ButtonTitles:SSearch");
				searchBtn.onClick.Add(SearchHandler); searchBtn.bounds.SetWidth(80);
				toolbar.AddInternalComponent(searchBtn);
			END;

			toolbar.visible.Set(TRUE);
		END SetToolbar;

		PROCEDURE HandleShortcut*(ucs : SIZE; flags : SET; keysym : SIZE) : BOOLEAN;
		BEGIN
			IF (buttons * StoreButton # {}) & (keysym = 13H) & ControlKeyDown(flags) THEN (* CTRL-S *)
				StoreHandler(NIL, NIL);
			ELSIF (buttons * LoadButton # {}) & (keysym = 0FH) & ControlKeyDown(flags) THEN (* CTRL-O *)
				filenameEdit.SetAsString("");
				filenameEdit.SetFocus;
			ELSIF (buttons * SearchButton # {}) & (keysym = 06H) & ControlKeyDown(flags)THEN (* CTRL-F *)
				EnsureSearchPanel; searchPanel.ToggleVisibility;
			ELSIF (buttons * SearchButton # {}) & (keysym= 0EH) & ControlKeyDown(flags) & (searchPanel # NIL) THEN (* CTRL-N *)
				searchPanel.HandlePreviousNext(TRUE);
			ELSIF (buttons * SearchButton # {}) & (keysym = 10H) & ControlKeyDown(flags) & (searchPanel # NIL) THEN (* CTRL-P *)
				searchPanel.HandlePreviousNext(FALSE);
			ELSIF (buttons * SearchButton # {}) & (keysym = Inputs.KsTab) & (flags = {}) THEN (* TAB *)
				RETURN (searchPanel # NIL) & searchPanel.HandleTab();
			ELSE
				RETURN FALSE; (* Key not handled *)
			END;
			RETURN TRUE;
		END HandleShortcut;

		PROCEDURE ToXml*(config : XML.Element);
		VAR filename : Files.FileName;
		BEGIN
			filenameEdit.GetAsString(filename);
			WMRestorable.StoreString(config, "file", filename);
			WMRestorable.StoreString(config, "codecFormat", codecFormat);
			WMRestorable.StoreSize(config, "firstLine", editor.tv.firstLine.Get());
			WMRestorable.StoreSize(config, "cursorPos", editor.tv.cursor.GetPosition());
			WMRestorable.StoreBoolean(config, "wordWrap", wordWrap);
		END ToXml;

		PROCEDURE FromXml*(config : XML.Element);
		VAR filename : Files.FileName; firstLine, cursorPos : SIZE; wordWrap : BOOLEAN;
		BEGIN
			ASSERT(config # NIL);
			WMRestorable.LoadString(config, "file", filename);
			WMRestorable.LoadString(config, "codecFormat", codecFormat);
			WMRestorable.LoadSize(config, "firstLine", firstLine);
			WMRestorable.LoadSize(config, "cursorPos", cursorPos);
			WMRestorable.LoadBoolean(config, "wordWrap", wordWrap);
			Load(filename, codecFormat);
			editor.tv.firstLine.Set(firstLine);
			editor.tv.cursor.SetPosition(cursorPos);
			SetWordWrap(wordWrap);
		END FromXml;

		PROCEDURE Handle*(VAR m: WMMessages.Message);
		BEGIN
			IF m.msgType = WMMessages.MsgKey THEN
				IF ~HandleShortcut(m.x, m.flags, m.y) THEN
					Handle^(m);
				END;
			ELSE Handle^(m)
			END
		END Handle;

		PROCEDURE InitCodecs;
		VAR caption : CaptionObject;
			elem : XML.Element; enum : XMLObjects.Enumerator; ptr : ANY; str : Strings.String;
		BEGIN
			NEW(popup);
			(* retrieve available Text-Codecs *)
			IF Configuration.config # NIL THEN
				elem := Configuration.config.GetRoot();
				IF elem # NIL THEN
					enum := elem.GetContents(); enum.Reset();
					WHILE enum.HasMoreElements() DO
						ptr := enum.GetNext();
						IF ptr IS XML.Element THEN
							str := ptr(XML.Element).GetAttributeValue("name");
							IF (str # NIL) & (str^ = "Codecs") THEN
								enum := ptr(XML.Element).GetContents(); enum.Reset();
								WHILE enum.HasMoreElements() DO
									ptr := enum.GetNext();
									IF ptr IS XML.Element THEN
										str := ptr(XML.Element).GetAttributeValue("name");
										IF (str # NIL) & (str^ = "Decoder") THEN
											enum := ptr(XML.Element).GetContents(); enum.Reset();
											WHILE enum.HasMoreElements() DO
												ptr := enum.GetNext();
												IF ptr IS XML.Element THEN
													str := ptr(XML.Element).GetAttributeValue("name");
													IF (str # NIL) & (str^ = "Text") THEN
														enum := ptr(XML.Element).GetContents(); enum.Reset();
														WHILE enum.HasMoreElements() DO
															ptr := enum.GetNext();
															IF ptr IS XML.Element THEN
																str := ptr(XML.Element).GetAttributeValue("name");
																NEW(caption, str^);
																popup.AddParButton(str^, FormatPopupHandler, caption);
															END;
														END;
													END;
												END;
											END;
										END;
									END;
								END;
							END;
						END;
					END;
				END;
			END;
			NEW(caption, "AUTO");
			popup.AddParButton("AUTO", FormatPopupHandler, caption);
		END InitCodecs;

		PROCEDURE EnsureSearchPanel;
		BEGIN
			IF (searchPanel = NIL) THEN
				RemoveContent(editor);
				NEW(searchPanel);
				searchPanel.alignment.Set(WMComponents.AlignBottom);
				searchPanel.bounds.SetHeight(40);
				searchPanel.SetText(editor.text);
				searchPanel.SetTextView(editor.tv);
				searchPanel.visible.Set(FALSE);
				AddInternalComponent(searchPanel);
				AddInternalComponent(editor);
				Reset(NIL, NIL);
			END;
		END EnsureSearchPanel;

		PROCEDURE Finalize*;
		BEGIN
			Finalize^;
			IF (editor.text # NIL) THEN
				editor.text.onTextChanged.Remove(TextChanged);
			END;
		END Finalize;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrDocumentEditor);
			wordWrap := FALSE;
			InitCodecs;
			lastFilename := "";
			codecFormat := "AUTO";
			autoCodecFormat := "";
			modified := FALSE;

			fillColor.Set(WMGraphics.White);

			NEW(toolbar);
			toolbar.alignment.Set(WMComponents.AlignTop);
			toolbar.bounds.SetHeight(20);
			toolbar.visible.Set(FALSE);
			AddInternalComponent(toolbar);

			searchPanel := NIL;

			NEW(editor);
			editor.alignment.Set(WMComponents.AlignClient); editor.tv.showBorder.Set(TRUE);
			editor.macros.Add(WMMacros.Handle);
			editor.multiLine.Set(TRUE);
			editor.tv.wrapMode.Set(WMTextView.NoWrap);
			editor.text.onTextChanged.Add(TextChanged);
			AddInternalComponent(editor);

			SetFormatCaption("AUTO");
			SetWordWrap(wordWrap);
		END Init;

	END Editor;

VAR
	StrDocumentEditor : Strings.String;

PROCEDURE InitStrings;
BEGIN
	StrDocumentEditor := Strings.NewString("DocumentEditor");
END InitStrings;

PROCEDURE ControlKeyDown(flags : SET) : BOOLEAN;
BEGIN
	RETURN (flags * Inputs.Ctrl # {}) & (flags - Inputs.Ctrl = {});
END ControlKeyDown;

BEGIN
	InitStrings;
END WMDocumentEditor.

System.FreeDownTo WMDocumentEditor ~
