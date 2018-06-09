MODULE ExampleTextWriter;	(** AUTHOR "TF"; PURPOSE "Template/Example  for component windows"; *)

(** This program shows the implementation of a multi instance component containing window *)

IMPORT
	Strings, WMGraphics, WMComponents, WMWindowManager,
	WMEditors, TextUtilities, Math;

TYPE
	Window* = OBJECT (WMComponents.FormWindow)
	VAR editor : WMEditors.Editor;

		PROCEDURE &New*;
		BEGIN
			NEW(editor);  editor.bounds.SetExtents(800, 700);
			editor.fillColor.Set(WMGraphics.White);

			Init(editor.bounds.GetWidth(), editor.bounds.GetHeight(), FALSE);
			SetContent(editor);

			 WMWindowManager.DefaultAddWindow(SELF);
			SetTitle(Strings.NewString("TextWriter Example"));

			WriteToEditor;
		END New;

		PROCEDURE WriteToEditor;
		VAR
			tw : TextUtilities.TextWriter;
			i : LONGINT;
			buffer : ARRAY 256 OF CHAR;
		BEGIN
			NEW(tw, editor.text);

			tw.SetFontSize(20);
			tw.String("This is a simple text. Count from 0 to 10 : "); tw.Ln;
			FOR i := 0 TO 10 DO tw.Int(i, 5) END; tw.Ln;

			tw.SetFontStyle({WMGraphics.FontBold});
			tw.String("This is bold. ");

			tw.SetFontStyle({WMGraphics.FontItalic});
			tw.String("This is italic.");

			tw.SetFontStyle({WMGraphics.FontBold});
			tw.SetFontColor(WMGraphics.Red);
			tw.String("This is bold red."); tw.Ln;

			tw.SetBgColor(WMGraphics.Black);
			tw.SetFontColor(WMGraphics.White);
			tw.String("This is bold white on black");
			tw.Ln;

			tw.SetFontStyle({});
			tw.SetBgColor(WMGraphics.White);
			tw.SetFontColor(WMGraphics.Black);

			buffer := "This is a bit fancy! It modulates the vertical offset with a cosine function and fades out.";
			i := 0;
			tw.SetFontStyle({WMGraphics.FontBold});
			WHILE buffer[i] # 0X DO
				tw.SetFontColor(WMGraphics.RGBAToColor(i * 2, i * 2, i * 2, 0FFH));
				tw.SetVerticalOffset(ENTIER(15 * Math.cos(i/4)));
				tw.Char(buffer[i]);
				INC(i)
			END;
			tw.Update;
		END WriteToEditor;

	END Window;

PROCEDURE Open*;
VAR inst, i2 : Window;
BEGIN
	NEW(inst);
	NEW(i2);
	i2.editor.SetText(inst.editor.text);
END Open;

END ExampleTextWriter.

System.Free ExampleTextWriter ~
ExampleTextWriter.Open
 