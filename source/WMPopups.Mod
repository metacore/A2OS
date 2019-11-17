MODULE WMPopups;	(** AUTHOR "BF"; PURPOSE "Popup Windows"; *)

IMPORT
	Strings, WMRectangles, WMGraphics, WMEvents, WMWindowManager, WMComponents, WMStandardComponents,
	Localization, Repositories;

CONST

	LineHeight = 20;

TYPE

	Entry = OBJECT
	VAR
		caption : Strings.String; (* {caption # NIL} *)
		onClickHandler : WMEvents.EventListener; (* {onClickHandler # NIL} *)
		parameter : ANY;
		next : Entry;

		PROCEDURE &Init(caption : Strings.String; onClickHandler : WMEvents.EventListener; parameter : ANY);
		BEGIN
			ASSERT((caption # NIL) & (onClickHandler # NIL));
			SELF.caption := caption;
			SELF.onClickHandler := onClickHandler;
			SELF.parameter := parameter;
			next := NIL;
		END Init;

	END Entry;

TYPE

	PopupWindow = OBJECT(WMComponents.FormWindow)
	VAR
		isClosed : BOOLEAN;
		languages : Localization.Languages;
		
		PROCEDURE &New(entries : Entry);
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			ASSERT(entries # NIL);
			vc := CreateForm(entries);
			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			SetContent(vc);
			isClosed := FALSE;
		END New;

		PROCEDURE Translate(value: Strings.String): Strings.String;
		VAR
			res : INTEGER;
			temp, word : Strings.String;
			dictionary : Repositories.Dictionary;
		BEGIN
			IF (value # NIL) & (LEN(value^) > 4) & (value^[0] = ':') & (value^[1] = ':') THEN
				(** If string needs translation. E.g. has prefix that points to repository and dictionary	at least:
					::<Repository name>:<Dictionary name>: **)
				Repositories.GetTranslationInfo(value^, dictionary, word, res);
				IF (dictionary # NIL) & (word # NIL) THEN
					temp := dictionary.Translate(word, languages);
					IF (temp # word) THEN
						RETURN temp
					END
				END
			END;
			RETURN NIL
		END Translate;

		PROCEDURE CreateForm(entries : Entry) : WMComponents.VisualComponent;
		VAR
			panel : WMStandardComponents.Panel;
			button : WMStandardComponents.Button;
			font : WMGraphics.Font;
			entry : Entry;
			width, height, w, h : SIZE;
			temp : Strings.String;
		BEGIN
			NEW(panel);
			panel.fillColor.Set(WMGraphics.White);

			languages := Localization.GetLanguagePreferences();

			width := 100; height := 0;

			entry := entries;
			WHILE (entry # NIL) DO
				NEW(button);
				button.alignment.Set(WMComponents.AlignTop);
				button.bounds.SetExtents(width, LineHeight);
				button.caption.Set(entry.caption);
				button.onClick.Add(entry.onClickHandler);
				button.onClick.Add(Clicked);
				button.userData := entry.parameter;
				panel.AddInternalComponent(button);

				font := button.GetFont();

				temp := Translate(entry.caption);
				IF temp # NIL THEN
					font.GetStringSize(temp^, w, h);
				ELSE
					font.GetStringSize(entry.caption^, w, h);
				END;

				IF (w + 10 > width) THEN
					width := w + 10;
				END;
				height := height + LineHeight;

				entry := entry.next;
			END;

			width := MIN(width, 1024);

			panel.bounds.SetExtents(width, height);

			RETURN panel;
		END CreateForm;

		PROCEDURE Clicked(sender, data : ANY);
		BEGIN
			Close;
		END Clicked;

		PROCEDURE FocusLost*;
		BEGIN
			Close
		END FocusLost;

		PROCEDURE Close*;
		BEGIN
			BEGIN {EXCLUSIVE}
				IF isClosed THEN RETURN; END;
				isClosed := TRUE;
			END;

			Close^;
		END Close;

		PROCEDURE FocusGot*;
		BEGIN
			manager.SetFocus(SELF)
		END FocusGot;

	END PopupWindow;


	(* Open a Popup *)
	Popup* = OBJECT
	VAR
		first, last : Entry;

		window : PopupWindow;
		(*closeOnFocusLost:BOOLEAN;*)

		PROCEDURE &New*;
		BEGIN
			first := NIL; last := NIL;
			window := NIL;
		END New;

		PROCEDURE Add*(CONST caption : ARRAY OF CHAR; onClickHandler : WMEvents.EventListener);
		BEGIN
			AddParButton(caption, onClickHandler, NIL);
		END Add;

		PROCEDURE AddParButton*(CONST caption : ARRAY OF CHAR; onClickHandler : WMEvents.EventListener; par : ANY);
		VAR entry : Entry;
		BEGIN {EXCLUSIVE}
			NEW(entry, Strings.NewString(caption), onClickHandler, par);
			IF (first = NIL) THEN
				first := entry; last := entry;
			ELSE
				last.next := entry; last := entry;
			END;
		END AddParButton;

		PROCEDURE Close*;
		BEGIN {EXCLUSIVE}
			IF (window # NIL) THEN
				window.Close;
				window := NIL;
			END;
		END Close;

		PROCEDURE Popup* (x, y : SIZE);
		VAR manager : WMWindowManager.WindowManager;
		BEGIN {EXCLUSIVE}
			IF (first # NIL) THEN
				IF (window # NIL) THEN window.Close; END;
				NEW(window, first);
				manager := WMWindowManager.GetDefaultManager();
				manager.Add(x, y, window, {WMWindowManager.FlagStayOnTop, WMWindowManager.FlagHidden});
				manager.SetFocus(window);
			END;
		END Popup;

	END Popup;

(** Open a color swatch dialog *)
	ColorSwatchPopup* = OBJECT (WMComponents.FormWindow)
	VAR colorPanel : ColorSwatchPanel;
		color- : WMGraphics.Color;
		onColorChosen* : PROCEDURE {DELEGATE} (color : WMGraphics.Color);

		PROCEDURE &New*;
		BEGIN
			color := 0H;
			CreatePopup;
			Init(colorPanel.bounds.GetWidth(), colorPanel.bounds.GetHeight(), FALSE);
			SetContent(colorPanel);
		END New;

		PROCEDURE CreatePopup;
		BEGIN
			NEW(colorPanel);
			colorPanel.ChosenColorProc := SetColor;
		END CreatePopup;

		PROCEDURE Popup*(x, y : SIZE);
		BEGIN
			manager := WMWindowManager.GetDefaultManager();
			manager.Add(x, y, SELF, {WMWindowManager.FlagStayOnTop, WMWindowManager.FlagHidden});
			manager.SetFocus(SELF);
		END Popup;

		PROCEDURE Clicked(sender, data : ANY);
		BEGIN
			manager.Remove(SELF)
		END Clicked;

		PROCEDURE FocusLost*;
		BEGIN
			manager.Remove(SELF)
		END FocusLost;

		PROCEDURE FocusGot*;
		BEGIN
			manager.SetFocus(SELF)
		END FocusGot;

		PROCEDURE SetColor(color : WMGraphics.Color);
		BEGIN
			SELF.color := color;
			IF onColorChosen # NIL THEN onColorChosen(color) END;
			manager.Remove(SELF)
		END SetColor;

	END ColorSwatchPopup;

(** Color Swatch Visual Component *)
	ColorSwatchPanel* = OBJECT(WMComponents.VisualComponent)
	VAR colors : ARRAY 19 OF WMGraphics.Color;
		ChosenColorProc* : PROCEDURE {DELEGATE} (color: WMGraphics.Color);
		(* CloseProc : PROCEDURE {DELEGATE}; *)

		PROCEDURE &Init*;
		BEGIN
			Init^;
			bounds.SetExtents(190, 70);
			BuildPalette;
		END Init;

		PROCEDURE PointerDown*(x, y : SIZE; keys : SET);
		VAR r, g, b, a: INTEGER; i, j: SIZE; cColor: WMGraphics.Color;
		BEGIN
			i := y DIV 10; j := x DIV 10;
			IF (i>= 0) & (i<=2) THEN
				WMGraphics.ColorToRGBA(colors[j], r, g, b, a);
				r := ENTIER((i+1)/4*r); g:= ENTIER((i+1)/4*g); b:= ENTIER((i+1)/4*b);
				cColor := WMGraphics.RGBAToColor(r, g, b, a);
			ELSIF (i= 3) THEN
				cColor := colors[j];
			ELSIF (i>=4) & (i<=6) THEN
				i := i - 4;
				WMGraphics.ColorToRGBA(colors[j], r, g, b, a);
				r := 255-ENTIER((3-i)/4*(255-r)); g:= 255-ENTIER((3-i)/4*(255-g)); b:= 255-ENTIER((3-i)/4*(255-b));
				cColor := WMGraphics.RGBAToColor(r, g, b, a);
			ELSE
			END;
			IF (y>0) & (y<bounds.GetHeight()) & (x>0) &(x<bounds.GetWidth())THEN
				ChosenColorProc(cColor); 
			END;
		END PointerDown;

		PROCEDURE DrawBackground*(canvas: WMGraphics.Canvas);
		VAR r, g, b, a: INTEGER; i, j: SIZE; color: WMGraphics.Color;
		BEGIN
			DrawBackground^(canvas);

			FOR i := 0 TO 2 DO
				FOR j := 0 TO 18 DO
					WMGraphics.ColorToRGBA(colors[j], r, g, b, a);
					r := ENTIER((i+1)/4*r); g:= ENTIER((i+1)/4*g); b:= ENTIER((i+1)/4*b);
					color := WMGraphics.RGBAToColor(r, g, b, a);
					canvas.Fill(WMRectangles.MakeRect(10*j,10*i,10*j+10,10*i+10),color , WMGraphics.ModeCopy);
				END;
			END;

			FOR j := 0 TO 18 DO
				color := colors[j];
				canvas.Fill(WMRectangles.MakeRect(10*j,30,10*j+10,10+30),color , WMGraphics.ModeCopy);
			END;

			FOR i := 0 TO 2 DO
				FOR j := 0 TO 18 DO
					WMGraphics.ColorToRGBA(colors[j], r, g, b, a);
					r := 255-ENTIER((3-i)/4*(255-r)); g:= 255-ENTIER((3-i)/4*(255-g)); b:= 255-ENTIER((3-i)/4*(255-b));
					color := WMGraphics.RGBAToColor (r, g, b, a);
					canvas.Fill(WMRectangles.MakeRect(10*j,10*i+40,10*j+10,10*i+10+40),color , WMGraphics.ModeCopy);
				END;
			END;
		END DrawBackground;

		PROCEDURE BuildPalette;
		BEGIN
			colors[0] := SIGNED32(0FF0000FFH);							(* red *)
			colors[1] := SIGNED32(0FF5500FFH);
			colors[2] := SIGNED32(0FFAA00FFH);
			colors[3] := SIGNED32(0FFFF00FFH);							(* yellow *)
			colors[4] := SIGNED32(0AAFF00FFH);
			colors[5] := SIGNED32(055FF00FFH);
			colors[6] := 000FF00FFH;							(* green *)
			colors[7] := 000FF55FFH;
			colors[8] := 000FFAAFFH;
			colors[9] := 000FFFFFFH;							(* cyan *)
			colors[10] := 000AAFFFFH;
			colors[11] := 00055FFFFH;
			colors[12] := 00000FFFFH;						(* blue *)
			colors[13] := 05500FFFFH;
			colors[14] :=SIGNED32( 0AA00FFFFH);
			colors[15] :=SIGNED32( 0FF00FFFFH);						(* magenta *)
			colors[16] :=SIGNED32( 0FF00AAFFH);
			colors[17] :=SIGNED32( 0FF0055FFH);
			colors[18] :=SIGNED32( 0888888FFH);						(* grey *)
		END BuildPalette;

	END ColorSwatchPanel;

	PROCEDURE PopupNoFocus* (popup:Popup; x, y : SIZE);
		VAR manager : WMWindowManager.WindowManager;
		BEGIN 
			IF (popup.first # NIL) THEN
				IF (popup.window # NIL) THEN popup.window.Close; END;
				NEW(popup.window, popup.first);
				manager := WMWindowManager.GetDefaultManager();
				manager.Add(x, y, popup.window, {WMWindowManager.FlagStayOnTop, WMWindowManager.FlagHidden});
			END;
		END PopupNoFocus;

END WMPopups.
-----------------------------------------------------
System.Free WMPopups ~

ProcedureInterfaces.Install ~
ProcedureInterfaces.UnInstall ~
