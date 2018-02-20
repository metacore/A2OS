MODULE CyberbitNetInstall; (** AUTHOR "PL"; PURPOSE "Downloads Cyberbit Unicode Truetype Font from Netscape FTP"; *)

IMPORT
	Streams, KernelLog, Files, Strings, WMDialogs, WMComponents, WMWindowManager, Commands,
	WMGraphics, WMGraphicUtilities, WMStandardComponents, WMRectangles, FTPClient;

CONST
	user = "anonymous";
	pass = "anonymous@the.net";
	address = "ftp.netscape.com";
	path = "/pub/communicator/extras/fonts/windows/";
	file = "Cyberbit.ZIP";

	BufSize = 16*1024;

TYPE
	Downloader = OBJECT

		PROCEDURE &New*;
		VAR res : LONGINT; temp : ARRAY 16 OF CHAR;
			r : Streams.Reader; w : Files.Writer;
			buf: ARRAY BufSize OF CHAR; len : LONGINT;
			msg, s : ARRAY 256 OF CHAR; i, j : LONGINT;
			ftpConnection : FTPClient.FTPClient;
			errorStr : ARRAY 512 OF CHAR;
			f : Files.File;
			status : StatusWindow; transCount : LONGINT;
		BEGIN
			NEW(ftpConnection);
			(* open connection to the ftp *)
			ftpConnection.Open(address, user, pass, 21, res);
			IF (res # 0) THEN
				Strings.IntToStr(res, temp);
				COPY("Connection Failed with Error: ", errorStr); Strings.Append(errorStr, temp);
				WMDialogs.Error("CyberbitNetInstall  Error", errorStr);
				RETURN
			END;
			(* change into correct directory *)
			ftpConnection.ChangeDir(path, res);
			IF (res # 0) THEN
				Strings.IntToStr(res, temp);
				COPY("Directory not found: ", errorStr); Strings.Append(errorStr, path);
				WMDialogs.Error("CyberbitNetInstall Error", errorStr);
				ftpConnection.Close(res);
				RETURN
			END;
			(* open the remote file *)
			ftpConnection.OpenGet(file, r, res);
			IF (res # 0) THEN
				Strings.IntToStr(res, temp);
				COPY("Couldn't open file: ", errorStr); Strings.Append(errorStr, file);
				WMDialogs.Error("CyberbitNetInstall Error", errorStr);
				ftpConnection.Close(res);
				RETURN
			END;
			(* get the size of the file *)
			COPY(ftpConnection.msg, msg); j := 0;
			FOR i := Strings.Pos("(", msg) TO Strings.Pos("bytes", msg)-2 DO
				temp[j] := msg[i+1];
				INC(j)
			END;
			temp[j] := 0X;
			Strings.StrToInt(temp, i);
			(* open the local file *)
			res := -1;
			IF (Files.Old(file) = NIL) OR (WMDialogs.Confirmation("Confirm overwriting", file) = WMDialogs.ResYes) THEN
				f := Files.New(file);
				IF f # NIL THEN
					Files.OpenWriter(w, f, 0);
					res := 0
				END
			ELSE
				RETURN
			END;
			(* create the status window *)
			NEW(status);
			status.fileSize := i;
			status.nofFiles := 1;
			(* transfer the bytes and update the statuswindow *)
			IF res = 0 THEN
				status.Show; transCount := 0;
				REPEAT
					r.Bytes(buf, 0, BufSize, len); w.Bytes(buf, 0, len);
					INC(transCount, len);
					status.UpdateStatus(1, transCount);
				UNTIL r.res # 0;
				ftpConnection.CloseGet(res);
				(* register/update file *)
				w.Update;
				f.Update;
				Files.Register(f);
				status.Hide
			END;
			(* close FTP connection *)
			ftpConnection.Close(res);
			(* extract File *)
			COPY("Unzip.ExtractAll ", s); Strings.Append(s, file);
			Commands.Call(s, {}, res, msg);
			IF res # 0 THEN
				KernelLog.String(msg); KernelLog.Ln
			ELSE
				KernelLog.String("CyberbitNetInstall finished"); KernelLog.Ln;
			END

		END New;

	END Downloader;

	StatusWindow = OBJECT(WMComponents.FormWindow)
	VAR
		nofFiles* : LONGINT;
		currentFile* : LONGINT;
		fileSize* : LONGINT;
		transferred* : LONGINT;
		currentFilename* : ARRAY 256 OF CHAR;

		shown : BOOLEAN;
		windowWidth, windowHeight : LONGINT;
		px, py : LONGINT;
		bar : WMStandardComponents.Panel;

		PROCEDURE &New*;
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			manager := WMWindowManager.GetDefaultManager();
			px := 300; py := 200; shown := FALSE;
			windowWidth := 350; windowHeight := 100;
			vc := CreateForm();
			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			SetContent(vc);
			SetTitle(Strings.NewString("Status Window"));
		END New;

		PROCEDURE CreateForm*(): WMComponents.VisualComponent;
		VAR form, panel : WMStandardComponents.Panel;
			back : BevelPanel;
			label : WMStandardComponents.Label;
			rect : WMRectangles.Rectangle;
			windowStyle : WMWindowManager.WindowStyle;
		BEGIN
			windowStyle := manager.GetStyle();

			NEW(form);
			form.bounds.SetExtents(windowWidth, windowHeight);
			form.fillColor.Set(windowStyle.bgColor);

			NEW(panel);
			panel.alignment.Set(WMComponents.AlignClient);
			rect := WMRectangles.MakeRect(20, 10, 20, 20); panel.bearing.Set(rect);
			form.AddContent(panel);

			NEW(label);
			label.bounds.SetHeight(20); label.alignment.Set(WMComponents.AlignTop);
			label.textColor.Set(windowStyle.fgColor); label.alignH.Set(WMGraphics.AlignCenter);
			label.caption.SetAOC("Transfering...");
			panel.AddContent(label);

			NEW(back); back.bevelWidth := 2; back.bevelColor := windowStyle.bgColor;
			back.bounds.SetHeight(20);
			back.alignment.Set(WMComponents.AlignTop); (* back.fillColor.Set(0FFFFFFFFH); *)
			rect := WMRectangles.MakeRect(0, 10, 0, 10);
			back.bearing.Set(rect);
			panel.AddContent(back);

			NEW(bar);
			bar.bounds.SetWidth(0);
			bar.alignment.Set(WMComponents.AlignLeft); bar.fillColor.Set(0FFFFH);
			back.AddContent(bar);

			RETURN form

		END CreateForm;

		PROCEDURE Show*;
		BEGIN
			IF ~shown THEN
				shown := TRUE;
				WMWindowManager.ExtAddWindow(SELF, px, py,
					{WMWindowManager.FlagFrame, WMWindowManager.FlagStayOnTop, WMWindowManager.FlagClose, WMWindowManager.FlagMinimize});
			END;
		END Show;

		PROCEDURE Hide*;
		BEGIN
			manager.Remove(SELF);
			shown := FALSE
		END Hide;

		PROCEDURE UpdateStatus*(file, size : LONGINT);
		BEGIN
			bar.bounds.SetWidth(ENTIER((windowWidth-20)/fileSize*size));
		END UpdateStatus;

	END StatusWindow;

	BevelPanel* = OBJECT(WMStandardComponents.Panel);
	VAR
		bevelWidth* : LONGINT;
		bevelColor* : LONGINT;

		PROCEDURE DrawBackground*(canvas : WMGraphics.Canvas);
		BEGIN
			IF ~visible.Get() THEN RETURN END;
			Acquire;
			WMGraphicUtilities.DrawBevelPanel(canvas, GetClientRect(), bevelWidth, TRUE, bevelColor, 0 );
			Release;
		END DrawBackground;
	END BevelPanel;

PROCEDURE Start*;
VAR loader : Downloader;
BEGIN
	NEW(loader);
END Start;

END CyberbitNetInstall.

------------------------------------------------------------------------------------------

SystemTools.Free CyberbitNetInstall~
CyberbitNetInstall.Start~
