MODULE WMBass3DTest; (** AUTHOR "SAGE"; PURPOSE "BASS 2.4 A2 OS Wrapper - BASS 3D Test"; *)

IMPORT
	Modules, Commands, Strings, Files, Codecs, Streams,
	XML, Models,	WMComponents, WMStringGrids, WMGrids, WMWindowManager,
	WMDialogs, WMDropDownLists, WMEditors, WMProperties, WMStandardComponents,
	WMGraphics, Raster, BASS, MathUtils, Generics, AAGraphics;

CONST
	RADIUS = 5;
  MAXDIST = 50; (* maximum distance of the channels (m) *)

TYPE
	FileName = ARRAY Files.NameLength + 1 OF CHAR;

	Source = POINTER TO RECORD
		nChannel: LONGINT;
		pos, vel: BASS.BASS_3DVECTOR;
	END;

	SourceHandler = PROCEDURE {DELEGATE} (source: Source; bSelected: BOOLEAN; VAR bIsPlaying: BOOLEAN);

	Window = OBJECT(WMComponents.FormWindow)
	VAR
		ddlEAXEnv: WMDropDownLists.DropDownList;

		fldMovementX,
		fldMovementZ: WMEditors.TextField;

		grChannels: WMStringGrids.StringGrid;

		slDoppler,
		slRollOff: WMStandardComponents.Slider;

		btnChannelsAdd,
		btnChannelsRemove,
		btnChannelsPlay,
		btnChannelsStop,
		btnMovementReset: WMStandardComponents.Button;

		timPeriod: WMStandardComponents.Timer;
		iTimeInterval: LONGINT;

		pnlSourcesImage: WMStandardComponents.ImagePanel;
		imgSources: WMGraphics.Image;
		iCenterX, iCenterY: LONGINT;
		imgSourcesCanvas: WMGraphics.BufferCanvas;
		px: Raster.Pixel;
		rmode: Raster.Mode;

		PROCEDURE FillEAXDropDownList;
		VAR
			res: LONGINT;
		BEGIN
			IF bEAXSupported THEN
				ddlEAXEnv.mode.Set(WMDropDownLists.Mode_SelectOnly);
				ddlEAXEnv.model.Add(0, "Off", res);
				ddlEAXEnv.model.Add(1, "Generic", res);
				ddlEAXEnv.model.Add(2, "Padded Cell", res);
				ddlEAXEnv.model.Add(3, "Room", res);
				ddlEAXEnv.model.Add(4, "Bathroom", res);
				ddlEAXEnv.model.Add(5, "Living Room", res);
				ddlEAXEnv.model.Add(6, "Stone Room", res);
				ddlEAXEnv.model.Add(7, "Auditorium", res);
				ddlEAXEnv.model.Add(8, "Concert Hall", res);
				ddlEAXEnv.model.Add(9, "Cave", res);
				ddlEAXEnv.model.Add(10, "Arena", res);
				ddlEAXEnv.model.Add(11, "Hangar", res);
				ddlEAXEnv.model.Add(12, "Carpeted Hallway", res);
				ddlEAXEnv.model.Add(13, "Hallway", res);
				ddlEAXEnv.model.Add(14, "Stone Corridor", res);
				ddlEAXEnv.model.Add(15, "Alley", res);
				ddlEAXEnv.model.Add(16, "Forest", res);
				ddlEAXEnv.model.Add(17, "City", res);
				ddlEAXEnv.model.Add(18, "Mountains", res);
				ddlEAXEnv.model.Add(19, "Quarry", res);
				ddlEAXEnv.model.Add(20, "Plain", res);
				ddlEAXEnv.model.Add(21, "Parking Lot", res);
				ddlEAXEnv.model.Add(22, "Sewer Pipe", res);
				ddlEAXEnv.model.Add(23, "Under Water", res);
				ddlEAXEnv.model.Add(24, "Drugged", res);
				ddlEAXEnv.model.Add(25, "Dizzy", res);
				ddlEAXEnv.model.Add(26, "Psychotic", res);
				ddlEAXEnv.SelectKey(0)
			ELSE
				ddlEAXEnv.enabled.Set(FALSE)
			END
		END FillEAXDropDownList;

		PROCEDURE SetupSourcesImage;
		BEGIN

			Raster.SetRGBA(px, 192, 192, 192, 255);
			Raster.InitMode(rmode, Raster.srcOverDst);

			NEW(imgSources);
			Raster.Create(imgSources, pnlSourcesImage.bounds.GetWidth(),
				pnlSourcesImage.bounds.GetHeight(), Raster.BGRA8888);
			NEW(imgSourcesCanvas, imgSources);
			Raster.Fill(imgSources, 0, 0, imgSources.width, imgSources.height, px, rmode);
			iCenterX := imgSources.width DIV 2;
			iCenterY := imgSources.height DIV 2;
			AAGraphics.AADisk(imgSources, iCenterX, iCenterY, RADIUS, WMGraphics.Gray);
		END SetupSourcesImage;

		PROCEDURE SetupComponents;
		VAR
			model: Models.Model;
		BEGIN
			FillEAXDropDownList;

			SetupSourcesImage;
			pnlSourcesImage.SetImage(NIL, imgSources);

			grChannels.SetSelectionMode(WMGrids.GridSelectSingleCell);
			grChannels.alwaysShowScrollY.Set(TRUE);
			grChannels.alwaysShowScrollX.Set(FALSE);
			grChannels.showScrollX.Set(FALSE);

			(* Assertions triggered here means inproperly initialized system *)

			ASSERT(WMProperties.GetModel(slDoppler.model, model));
			(* model.AcquireWrite; *)
			model(Models.Integer).Set(50);
			(*model.ReleaseWrite;*)

			ASSERT(WMProperties.GetModel(slRollOff.model, model));
			(*model.AcquireWrite;*)
			model(Models.Integer).Set(50);
			(*model.ReleaseWrite;*)

		END SetupComponents;

		PROCEDURE WireEvents;
		VAR
			model: Models.Model;
		BEGIN
			ddlEAXEnv.onSelect.Add(EAXEnvOnSelect);
			grChannels.onSelect.Add(ChannelsOnSelect);
			btnChannelsAdd.onClick.Add(ChannelsAddOnClick);
			btnChannelsRemove.onClick.Add(ChannelsRemoveOnClick);
			btnChannelsPlay.onClick.Add(ChannelsPlayOnClick);
			btnChannelsStop.onClick.Add(ChannelsStopOnClick);
			btnMovementReset.onClick.Add(MovementResetOnClick);

			ASSERT(WMProperties.GetModel(fldMovementX.model, model));
			model.onChanged.Add(MovementXModelOnChanged);
			ASSERT(WMProperties.GetModel(fldMovementZ.model, model));
			model.onChanged.Add(MovementZModelOnChanged);
			ASSERT(WMProperties.GetModel(slDoppler.model, model));
			model.onChanged.Add(DopplerModelOnChanged);
			ASSERT(WMProperties.GetModel(slRollOff.model, model));
			model.onChanged.Add(RollOffModelOnChanged);

			timPeriod.onTimer.Add(PeriodOnTimer)
		END WireEvents;

		PROCEDURE FormInit;
		BEGIN
			SetTitle(Strings.NewString("BASS 3D Test"));

			SetupComponents;

			WireEvents;

			ActualizeControls;

			iTimeInterval := timPeriod.interval.Get();

		END FormInit;

		PROCEDURE SourceSelected(VAR source: Source; VAR iRow: LONGINT): BOOLEAN;
		VAR
			scol, srow, ecol, erow: LONGINT;
			data: ANY;
		BEGIN
			source := NIL;
			grChannels.Acquire;
			grChannels.model.Acquire;
			IF (grChannels.model.GetNofCols() = 1) &
				(grChannels.model.GetNofRows() > 0)
			THEN
				grChannels.GetSelection(scol, srow, ecol, erow);
				data := grChannels.model.GetCellData(scol, srow);
				IF data # NIL THEN
					source := data(Source);
					iRow := srow
				END
			END;
			grChannels.model.Release;
			grChannels.Release;
			RETURN source # NIL
		END SourceSelected;

		PROCEDURE SourcesIterate(handler: SourceHandler; VAR iNumberOfPlaying: LONGINT);
		VAR
			scol, srow, ecol, erow, i, iSelCell: LONGINT;
			data: ANY;
			bPlaying: BOOLEAN;
		BEGIN
			iNumberOfPlaying := 0;
			IF handler # NIL THEN
				iSelCell := -1;
				grChannels.Acquire;
				grChannels.model.Acquire;
				IF (grChannels.model.GetNofCols() = 1) &
					(grChannels.model.GetNofRows() > 0)
				THEN
					grChannels.GetSelection(scol, srow, ecol, erow);
					data := grChannels.model.GetCellData(scol, srow);
					IF data # NIL THEN
						iSelCell := srow
					END;
					FOR i := 0 TO grChannels.model.GetNofRows() - 1 DO
						data := grChannels.model.GetCellData(0, i);
						IF data # NIL THEN
							handler(data(Source), i = iSelCell, bPlaying);
							IF bPlaying THEN
								INC(iNumberOfPlaying)
							END
						END
					END
				END;
				grChannels.model.Release;
				grChannels.Release;
			END
		END SourcesIterate;

		PROCEDURE SourceDrawHandler(source: Source; bSelected: BOOLEAN; VAR bDummy: BOOLEAN);
		VAR
			str1, str2: ARRAY 16 OF CHAR;
			textWidth, textHeight: LONGINT;
		BEGIN
			IF bSelected THEN
				AAGraphics.AADisk(imgSources, iCenterX + ENTIER(source.pos.x + 0.5),
					iCenterY - ENTIER(source.pos.z + 0.5), RADIUS, WMGraphics.Red);

				imgSourcesCanvas.SetColor(WMGraphics.Red);
				Strings.FloatToStr(source.pos.x, 0, 1, 0, str1);
				Strings.TrimLeft(str1, 20X);
				Strings.Concat("x:", str1, str1);
				Strings.Concat(str1, " ", str1);
				Strings.FloatToStr(source.pos.z, 0, 1, 0, str2);
				Strings.TrimLeft(str2, 20X);
				Strings.Concat("z:", str2, str2);
				Strings.Concat(str1, str2, str2);
				imgSourcesCanvas.GetFont().GetStringSize(str2, textWidth, textHeight);
				imgSourcesCanvas.DrawString(4, textHeight + 4, str2)

			ELSE
				AAGraphics.AADisk(imgSources, iCenterX + ENTIER(source.pos.x + 0.5),
					iCenterY - ENTIER(source.pos.z + 0.5), RADIUS, WMGraphics.Black)
			END
		END SourceDrawHandler;

		PROCEDURE DrawSources;
		VAR
			iDummy: LONGINT;
		BEGIN
			Raster.Fill(imgSources, 0, 0, imgSources.width, imgSources.height, px, rmode);
			AAGraphics.AADisk(imgSources, iCenterX, iCenterY, RADIUS, WMGraphics.Gray);
			SourcesIterate(SourceDrawHandler, iDummy);
			pnlSourcesImage.SetImage(NIL, imgSources)
		END DrawSources;

		PROCEDURE SourceActualizeHandler(source: Source; bSelected: BOOLEAN; VAR bPlaying: BOOLEAN);
		VAR
			tmp: BASS.BASS_3DVECTOR;
			res: LONGINT;
		BEGIN
			bPlaying := BASS.BASS_ChannelIsActive(source.nChannel) = BASS.BASS_ACTIVE_PLAYING;
			IF bPlaying THEN
				IF (source.pos.z >= MAXDIST) OR (source.pos.z <= -MAXDIST) THEN
					source.vel.z := -source.vel.z
				END;
				IF (source.pos.x >= MAXDIST) OR (source.pos.x <= -MAXDIST) THEN
					source.vel.x := -source.vel.x;
				END;
				source.pos.z := source.pos.z + source.vel.z * iTimeInterval / 1000;
				source.pos.x := source.pos.x + source.vel.x * iTimeInterval / 1000;
				tmp.x := 0.0; tmp.y := 0.0; tmp.z := 0.0;
				res := BASS.BASS_ChannelSet3DPosition(source.nChannel, source.pos, tmp, source.vel)
			END
		END SourceActualizeHandler;

		PROCEDURE ActualizeSources(bForceUpdate: BOOLEAN);
		VAR
			iNumberOfPlaying: LONGINT;
		BEGIN
			SourcesIterate(SourceActualizeHandler, iNumberOfPlaying);
			IF bForceUpdate OR (iNumberOfPlaying > 0) THEN
				DrawSources;
				BASS.BASS_Apply3D
			END
		END ActualizeSources;

		PROCEDURE ActualizeControls;
		VAR
			source: Source;
			iRow: LONGINT;
			bEnabled: BOOLEAN;
			model: Models.Model;
		BEGIN

			bEnabled := SourceSelected(source, iRow);

			fldMovementX.enabled.Set(bEnabled);
			fldMovementZ.enabled.Set(bEnabled);
			btnChannelsRemove.enabled.Set(bEnabled);
			btnChannelsPlay.enabled.Set(bEnabled);
			btnChannelsStop.enabled.Set(bEnabled);
			btnMovementReset.enabled.Set(bEnabled);

			timPeriod.enabled.Set(bEnabled);

			IF bEnabled THEN
				fldMovementX.Acquire;
				ASSERT(WMProperties.GetModel(fldMovementX.model, model));
				model.AcquireWrite;
				model(Models.Real).Set(source.vel.x);
				model.ReleaseWrite;
				fldMovementX.Release;
				fldMovementZ.Acquire;
				ASSERT(WMProperties.GetModel(fldMovementZ.model, model));
				model.AcquireWrite;
				model(Models.Real).Set(source.vel.z);
				model.ReleaseWrite;
				fldMovementZ.Release;
				DrawSources
			END

		END ActualizeControls;

		PROCEDURE PeriodOnTimer(sender, par: ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.PeriodOnTimer, sender, par)
			ELSE
				ActualizeSources(FALSE)
			END
		END PeriodOnTimer;

		PROCEDURE ChannelsOnSelect(sender, par: ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.ChannelsOnSelect, sender, par)
			ELSE
				ActualizeControls
			END
		END ChannelsOnSelect;

		PROCEDURE RequestFileName(VAR sName: FileName): BOOLEAN;
		VAR
			bResult: BOOLEAN;
			x, y: LONGINT;
		BEGIN
			timPeriod.enabled.Set(FALSE);
			DialogPos(x, y, SELF, 350, 100);
			bResult := (WMDialogs.QueryStringXY(x, y, "Open file", sName) = WMDialogs.ResOk)
				& (sName # "");
			timPeriod.enabled.Set(TRUE);
			RETURN bResult
		END RequestFileName;

		PROCEDURE ChannelsAddOnClick(sender, par: ANY);
		VAR
			sName: FileName;
			sFullPath: FileName;
			nChan, nRows, res: LONGINT;
			r: Streams.Reader;
			source: Source;
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.ChannelsAddOnClick, sender, par)
			ELSIF RequestFileName(sName) THEN

				r := Codecs.OpenInputStream(sName);
				IF r # NIL THEN
					(* File exists, get full path *)
					r(Codecs.FileInputStream).f.GetName(sFullPath);
				ELSE
					context.out.String("File doesn't exist"); context.out.Ln;
					context.out.Update;
					RETURN
				END;

				context.out.String("Full path: ");
				context.out.String(sFullPath);
				context.out.Ln;
				context.out.Update;

				(*ConvertChar(sFullPath, '/', '\');*)

				  (* Load a music from "file" with 3D enabled, and make it loop & use ramping *)
				  nChan := BASS.BASS_MusicLoad(0, ADDRESSOF(sFullPath), 0, 0,
				  	BASS.BASS_MUSIC_RAMP + BASS.BASS_MUSIC_LOOP + BASS.BASS_SAMPLE_3D, 1);
				  IF nChan = 0 THEN
				    (* Load a sample from "file" with 3D enabled, and make it loop *)
				    nChan := BASS.BASS_SampleLoad(0, ADDRESSOF(sFullPath), 0, 0, 1,
				    	BASS.BASS_SAMPLE_LOOP + BASS.BASS_SAMPLE_3D + BASS.BASS_SAMPLE_MONO)
				  END;

				  IF nChan = 0 THEN
				  	BASS_Error("Can't load file (note samples must be mono)");
					RETURN
				  END;

				  (* initialize sample channel *)
				  res := BASS.BASS_SampleGetChannel(nChan, 0);

				  NEW(source);
				  source.nChannel := nChan;

				grChannels.Acquire;
				grChannels.model.Acquire;
				IF grChannels.model.GetNofCols() # 1 THEN
					grChannels.model.SetNofCols(1);
				END;
				nRows := grChannels.model.GetNofRows();
				grChannels.model.InsertEmptyRow(nRows);
				(*grChannels.model.SetNofRows(nRows + 1);*)
				grChannels.model.SetCellText(0, nRows, Strings.NewString(sName));
				grChannels.model.SetCellData(0, nRows, source);
				grChannels.model.Release;
				grChannels.Release
			END
		END ChannelsAddOnClick;

		PROCEDURE ChannelsRemoveOnClick(sender, par: ANY);
		VAR
			source: Source;
			iRow, res: LONGINT;
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.ChannelsRemoveOnClick, sender, par)
			ELSE
				IF SourceSelected(source, iRow) THEN
					res := BASS.BASS_SampleFree(source.nChannel);
					res := BASS.BASS_MusicFree(source.nChannel);
					(* It's needed to unselect cell before removal of row
						in case if it was the last row *)
					grChannels.Acquire;
					grChannels.model.Acquire;
					IF grChannels.model.GetNofRows() = 1 THEN
						grChannels.SetSelection(-1, -1, -1, -1);
					END;
					grChannels.model.DeleteRow(iRow, TRUE);
					grChannels.model.Release;
					grChannels.Release;
				END;
				ActualizeControls
			END
		END ChannelsRemoveOnClick;

		PROCEDURE ChannelsPlayOnClick(sender, par: ANY);
		VAR
			source: Source;
			iRow, res: LONGINT;
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.ChannelsPlayOnClick, sender, par)
			ELSIF SourceSelected(source, iRow) THEN
				IF ~(BASS.BASS_ChannelIsActive(source.nChannel) = BASS.BASS_ACTIVE_PLAYING) THEN
					res := BASS.BASS_ChannelPlay(source.nChannel, 0)
				END
			END
		END ChannelsPlayOnClick;

		PROCEDURE ChannelsStopOnClick(sender, par: ANY);
		VAR
			source: Source;
			iRow, res: LONGINT;
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.ChannelsStopOnClick, sender, par)
			ELSIF SourceSelected(source, iRow) THEN
				IF BASS.BASS_ChannelIsActive(source.nChannel) = BASS.BASS_ACTIVE_PLAYING THEN
					res := BASS.BASS_ChannelPause(source.nChannel)
				END
			END
		END ChannelsStopOnClick;

		PROCEDURE MovementResetOnClick(sender, par: ANY);
		VAR
			source: Source;
			model: Models.Model;
			iRow: LONGINT;
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.MovementResetOnClick, sender, par)
			ELSIF SourceSelected(source, iRow) THEN
				fldMovementX.Acquire;
				ASSERT(WMProperties.GetModel(fldMovementX.model, model));
				model.AcquireWrite;
				model(Models.Real).Set(0.0);
				model.ReleaseWrite;
				fldMovementX.Release;
				fldMovementZ.Acquire;
				ASSERT(WMProperties.GetModel(fldMovementZ.model, model));
				model.AcquireWrite;
				model(Models.Real).Set(0.0);
				model.ReleaseWrite;
				fldMovementZ.Release;
				source.pos.x := 0; source.pos.y := 0; source.pos.z := 0;
				source.vel.x := 0; source.vel.y := 0; source.vel.z := 0;
				ActualizeSources(TRUE);
			END
		END MovementResetOnClick;

		PROCEDURE MovementXModelOnChanged(sender, par: ANY);
		VAR
			source: Source;
			iRow: LONGINT;
			model: Models.Model;
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.MovementXModelOnChanged, sender, par)
			ELSIF SourceSelected(source, iRow) THEN
				fldMovementX.Acquire;
				ASSERT(WMProperties.GetModel(fldMovementX.model, model));
				model.AcquireRead;
				source.vel.x := model(Models.Real).Get();
				model.ReleaseRead;
				fldMovementX.Release
			END
		END MovementXModelOnChanged;

		PROCEDURE MovementZModelOnChanged(sender, par: ANY);
		VAR
			source: Source;
			iRow: LONGINT;
			model: Models.Model;
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.MovementZModelOnChanged, sender, par)
			ELSIF SourceSelected(source, iRow) THEN
				fldMovementZ.Acquire;
				ASSERT(WMProperties.GetModel(fldMovementZ.model, model));
				model.AcquireRead;
				source.vel.z := model(Models.Real).Get();
				model.ReleaseRead;
				fldMovementZ.Release
			END
		END MovementZModelOnChanged;

		PROCEDURE EAXEnvOnSelect(sender, par: ANY);
		VAR
			entry: WMDropDownLists.Entry;
			res: LONGINT;
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.EAXEnvOnSelect, sender, par)
			ELSE
				ddlEAXEnv.Acquire;
				ddlEAXEnv.model.Acquire;
				entry := ddlEAXEnv.GetSelection();
				IF entry # NIL THEN
					CASE entry.key OF
						0: res := BASS.BASS_SetEAXParameters (-1, 0, -1, -1);
					|	1: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_GENERIC);
					|	2: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_PADDEDCELL);
					|	3: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_ROOM);
					|	4: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_BATHROOM);
					|	5: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_LIVINGROOM);
					|	6: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_STONEROOM);
					|	7: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_AUDITORIUM);
					|	8: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_CONCERTHALL);
					|	9: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_CAVE);
					|	10: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_ARENA);
					|	11: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_HANGAR);
					|	12: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_CARPETEDHALLWAY);
					|	13: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_HALLWAY);
					|	14: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_STONECORRIDOR);
					|	15: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_ALLEY);
					|	16: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_FOREST);
					|	17: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_CITY);
					|	18: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_MOUNTAINS);
					|	19: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_QUARRY);
					|	20: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_PLAIN);
					|	21: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_PARKINGLOT);
					|	22: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_SEWERPIPE);
					|	23: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_UNDERWATER);
					|	24: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_DRUGGED);
					|	25: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_DIZZY);
					|	26: res := BASS.BASS_SetEAXPreset(BASS.EAX_ENVIRONMENT_PSYCHOTIC);
					ELSE
					END
				END;
				ddlEAXEnv.model.Release;
				ddlEAXEnv.Release
			END
		END EAXEnvOnSelect;

		PROCEDURE DopplerModelOnChanged(sender, par: ANY);
		VAR
			model: Models.Model;
			res: LONGINT;
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.DopplerModelOnChanged, sender, par)
			ELSE
				slDoppler.Acquire;
				ASSERT(WMProperties.GetModel(slDoppler.model, model));
				res := BASS.BASS_Set3DFactors(
					-1, -1, MathUtils.power(2, model(Models.Integer).Get() - 10 / 5.0));
				slDoppler.Release
			END
		END DopplerModelOnChanged;

		PROCEDURE RollOffModelOnChanged(sender, par: ANY);
		VAR
			model: Models.Model;
			res: LONGINT;
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.RollOffModelOnChanged, sender, par)
			ELSE
				slRollOff.Acquire;
				ASSERT(WMProperties.GetModel(slRollOff.model, model));
				res := BASS.BASS_Set3DFactors(
					-1, MathUtils.power(2, (model(Models.Integer).Get() - 10) / 5.0), -1);
				slRollOff.Release
			END
		END RollOffModelOnChanged;

		PROCEDURE Close;
		VAR
			res: LONGINT;
		BEGIN
			timPeriod.Stop(SELF, NIL);
			IF bBASSInitialized THEN
				res := BASS.BASS_Stop();
				IF BASS.BASS_Free() # 0 THEN
					context.out.String("BASS freed");
					context.out.Ln
				ELSE
					context.out.String("BASS didn't freed");
					context.out.Ln
				END;
				context.out.Update;
			END;
			Close^;
			window := NIL
		END Close;

	END Window;

VAR
	window: Window;
	context: Commands.Context;
	bBASSInitialized: BOOLEAN;
	bEAXSupported: BOOLEAN;

PROCEDURE BASS_CheckVersion(context: Commands.Context): BOOLEAN;
BEGIN
	IF (BASS.BASS_GetVersion() DIV 10000H) MOD 10000H = BASS.BASSVERSION THEN
		context.out.String("Version of BASS library is correct");
		context.out.Ln;
		context.out.Update;
		RETURN TRUE
	ELSE
		context.out.String("An incorrect version of BASS library was loaded");
		context.out.Ln;
		context.out.Update;
		RETURN FALSE
	END
END BASS_CheckVersion;

PROCEDURE BASS_Error(CONST msg: ARRAY OF CHAR);
BEGIN
	context.out.String(msg);
	context.out.String(" (error code: ");
	context.out.Int(BASS.BASS_ErrorGetCode(), 0);
	context.out.Char(')');
	context.out.Ln;
	context.out.Update
END BASS_Error;

PROCEDURE FindComponents(c: XML.Content; data: ANY);
VAR
	comp: WMComponents.Component;
	sUID: Strings.String;
BEGIN
	IF c IS WMComponents.Component THEN
		comp := c(WMComponents.Component);
		sUID := comp.uid.Get();
		IF (sUID # NIL) & (sUID^ # "") THEN
			data(Generics.ObjectMap).Insert(sUID, comp)
		END
	END
END FindComponents;

PROCEDURE WireComponents(root: WMComponents.VisualComponent; win: Window): BOOLEAN;
VAR
	trap: BOOLEAN;
	components: Generics.ObjectMap;
BEGIN
	trap := FALSE;

	NEW(components);
	root.Traverse(FindComponents, components);

	win.ddlEAXEnv := components.GetAOC("ddlEAXEnv")(WMDropDownLists.DropDownList);
	win.fldMovementX := components.GetAOC("fldX")(WMEditors.TextField);
	win.fldMovementZ := components.GetAOC("fldZ")(WMEditors.TextField);
	win.grChannels := components.GetAOC("grChannels")(WMStringGrids.StringGrid);
	win.slDoppler := components.GetAOC("slDoppler")(WMStandardComponents.Slider);
	win.slRollOff := components.GetAOC("slRollOff")(WMStandardComponents.Slider);
	win.btnChannelsAdd := components.GetAOC("btnAdd")(WMStandardComponents.Button);
	win.btnChannelsRemove := components.GetAOC("btnRemove")(WMStandardComponents.Button);
	win.btnChannelsPlay := components.GetAOC("btnPlay")(WMStandardComponents.Button);
	win.btnChannelsStop := components.GetAOC("btnStop")(WMStandardComponents.Button);
	win.btnMovementReset := components.GetAOC("btnReset")(WMStandardComponents.Button);
	win.timPeriod := components.GetAOC("timPeriod")(WMStandardComponents.Timer);
	win.pnlSourcesImage := components.GetAOC("pnlImage")(WMStandardComponents.ImagePanel);

FINALLY

	RETURN ~trap

END WireComponents;

PROCEDURE DialogPos(VAR x, y: LONGINT; win: WMWindowManager.Window; dlgWidth, dlgHeight: LONGINT);
VAR
	manager: WMWindowManager.WindowManager;
	s: WMWindowManager.WindowStyle;
BEGIN
	manager := WMWindowManager.GetDefaultManager();
	s := manager.GetStyle();
	x := ENTIER(win.bounds.l + (win.bounds.r - win.bounds.l - dlgWidth) / 2);
	y := ENTIER(win.bounds.t + (win.bounds.b - win.bounds.t - dlgHeight) / 2);
	(*IF s # NIL THEN y := y +  s.th END;*)
END DialogPos;

PROCEDURE WindowGenerator*(ctx: Commands.Context): WMWindowManager.Window;
VAR
	xml: XML.Content;
	root: WMComponents.VisualComponent;
	x, y, res: LONGINT;
	manager: WMWindowManager.WindowManager;
BEGIN

	IF (window = NIL) & BASS_CheckVersion(ctx) THEN
	
		context := ctx;
		bBASSInitialized := FALSE;
		bEAXSupported := FALSE;

		xml := WMComponents.Load("WMBass3DTest.xml");
		IF (xml # NIL) & (xml IS WMComponents.VisualComponent) THEN

			context.out.String("Form is loaded");
			context.out.Ln;
			context.out.Update;

			root := xml(WMComponents.VisualComponent);

			(* Window setup *)
			NEW(window, root.bounds.GetWidth(), root.bounds.GetHeight(), FALSE);
			IF window # NIL THEN
				context.out.String("Window is created");
				context.out.Ln;
				context.out.Update
			END;

			window.SetContent(root);
			IF ~WireComponents(root, window) THEN
				context.out.String("Form resource corrupted"); context.out.Ln;
				context.out.Update;
				RETURN NIL
			END;

			IF BASS.BASS_Init(-1, 44100, BASS.BASS_DEVICE_3D, 0, NIL) = 0 THEN
				context.out.String("Can't initialize output device"); context.out.Ln;
				context.out.Update;
				RETURN NIL
			END;

			context.out.String("BASS initialized"); context.out.Ln;
			context.out.Update;
			bBASSInitialized := TRUE;

			(* Use meters as distance unit, real world rolloff, real doppler effect *)
			res := BASS.BASS_Set3DFactors(1.0, 1.0, 1.0);

			bEAXSupported := BASS.BASS_SetEAXParameters(-1, 0.0, -1.0, -1.0) # 0;
			IF bEAXSupported THEN
				context.out.String("EAX supported"); context.out.Ln
			ELSE
				context.out.String("EAX not supported"); context.out.Ln
			END;
			context.out.Update;

			(* Initialize form and wire event handlers *)
			window.FormInit;

			(* Form show *)
			WMDialogs.DefaultPos(x, y, window.GetWidth(), window.GetHeight());
			WMWindowManager.ExtAddWindow(	window, x, y,
				{WMWindowManager.FlagFrame, WMWindowManager.FlagClose,
					WMWindowManager.FlagMinimize, WMWindowManager.FlagNoResizing});
			manager := WMWindowManager.GetDefaultManager();
			manager.SetFocus(window);

	  END
	END;
	RETURN window
END WindowGenerator;

PROCEDURE Open*(ctx: Commands.Context);
VAR
	wDummy: WMWindowManager.Window;
BEGIN
	IF window = NIL THEN
		wDummy := WindowGenerator(ctx)
	END
END Open;

PROCEDURE Cleanup;
BEGIN
	IF window # NIL THEN
		window.Close;
	END
END Cleanup;

BEGIN
	bBASSInitialized := FALSE;
	Modules.InstallTermHandler(Cleanup)
END WMBass3DTest.



