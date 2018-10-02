MODULE Installer; (** AUTHOR "staubesv"; PURPOSE "Installer"; *)

IMPORT
	KernelLog, Streams, Commands, Strings, Disks, Files, AosUnzip := Unzip, Partitions, PartitionsLib, Codecs,
	XML, XMLScanner, XMLParser, XMLObjects;


CONST

	AosPartitionType = 76;
	Free = -1;
	AosFsName = "AosFS";

	DefaultMBRFile = "OBEMBR.BIN";
	DefaultBootLoader = "OBL.Bin";
	DefaultBootfile = "IDE.Bin";
	DefaultUsbBootfile = "USB.Bin";
	DefaultBootManMBR = "BootManagerMBR.Bin";
	DefaultBootManRest = "BootManagerTail.Bin";

	BootVolString = "AOS AosFS "; (* dev#part will be appended *)

	DefaultPrefix = "INSTALLER";

	MaxPackages = 128;

	XmlPackage = "Package";
	XmlPackageNumber = "nr";
	XmlPackageFilename = "file";
	XmlPackageName = "name";
	XmlPackageDescription = "description";
	XmlPackageInstall="install";

	XmlInstallYes="YES";
	XmlInstallNo="NO";
	XmlInstallRequired="REQUIRED";

	Invalid = -1;
	Mandatory* = 0;
	OptionalYes* = 1;
	OptionalNo* = 2;
	NotAllowed* = 3;

	(* AosFS block size [Bytes] *)
	BlockSize = 4096;

	(* Overhead in file system metadata per file (guess) *)
	FsMetaOverheadPerFile = 128;

	NofSteps* = 12;

	Undefined* = 0;
	WriteMBR* = 1;
	CreatePartition* = 2;
	ChangeType* = 3;
	Activate* = 4;
	Format* = 5;
	UpdateBootfile* = 6;
	SetConfig* = 7;
	InstallBootManager* = 8;
	Mount* = 9;
	InstallPackages* = 10;
	Unmount* = 11;

TYPE

	Configuration* = OBJECT
	VAR
		steps : ARRAY NofSteps OF LONGINT;

		(* WriteMBR: MBR filename *)
		mbrFile* : Files.FileName;

		(* CreatePartition: partition size *)
		size* : LONGINT;

		(* Format: Boot loader and Boot file filenames *)
		bootloader* : Files.FileName;
		bootfile* : Files.FileName; (* also for updateBootfile *)

		(* SetConfig: *)
		configTable- : PartitionsLib.ConfigTable;

		(* Install BB boot manager into MBR? *)
		bootManMBR*, bootManRest* : Files.FileName;

		(* Mount: File system prefix to be used *)
		mountPrefix* : Files.Prefix;

		(* InstallPackages: Package description *)
		packages : Packages;

		disk : PartitionsLib.Disk;
		partition : LONGINT;
		diskpartString : PartitionsLib.String;

		PROCEDURE SetInstallStep*(step : LONGINT; doStep : BOOLEAN; VAR msg : ARRAY OF CHAR) : BOOLEAN;
		BEGIN
			IF ~IsValidStepNumber(step) THEN msg := "Invalid installation step specified"; RETURN FALSE; END;
			CASE steps[step] OF
				|Mandatory:
					IF ~doStep THEN msg := "This installation step is mandatory"; RETURN FALSE; END;
				|OptionalYes:
					IF ~doStep THEN steps[step] := OptionalNo; END;
				|OptionalNo:
					IF doStep THEN steps[step] := OptionalYes; END;
				|NotAllowed:
					IF doStep THEN msg := "This installation step is not allowed"; RETURN FALSE; END;
			ELSE
				HALT(99);
			END;
			RETURN TRUE;
		END SetInstallStep;

		PROCEDURE IsValidStepNumber(stepNr : LONGINT) : BOOLEAN;
		BEGIN
			RETURN (0 <= stepNr) & (stepNr < NofSteps);
		END IsValidStepNumber;

		(* Return TRUE of the specified install step will be performed, FALSE otherwise *)
		PROCEDURE DoStep*(step : LONGINT) : BOOLEAN;
		BEGIN
			ASSERT(IsValidStepNumber(step));
			RETURN (steps[step] = Mandatory) OR (steps[step] = OptionalYes);
		END DoStep;

		(* Return the number of steps that will be performed *)
		PROCEDURE GetNofSteps() : LONGINT;
		VAR nofSteps, i : LONGINT;
		BEGIN
			nofSteps := 0;
			FOR i := 0 TO LEN(steps)-1 DO
				IF DoStep(i) THEN INC(nofSteps); END;
			END;
			RETURN nofSteps;
		END GetNofSteps;

		PROCEDURE IsUsbDisk() : BOOLEAN;
		BEGIN
			RETURN ((LEN(diskpartString) > 2) & (diskpartString[0] = "U") & (diskpartString[1] = "S") & (diskpartString[2] = "B")) OR
				(* WinAOS hack: Assume that removable devices are USB devices *)
				(Strings.Match("PhysicalDrive*", diskpartString) & (disk.device # NIL) & (Disks.Removable IN disk.device.flags));
		END IsUsbDisk;

		PROCEDURE SpaceAvailable*() : LONGINT;
		VAR spaceAvailable : LONGINT;
		BEGIN
			spaceAvailable := (disk.table[partition].size DIV 1024) * disk.device.blockSize;
			spaceAvailable := spaceAvailable - 640; (* 640KB for boot file *)
			RETURN spaceAvailable;
		END SpaceAvailable;

		PROCEDURE CheckConfiguration*(w : Streams.Writer) : BOOLEAN;
		VAR errors : LONGINT; installSize, installSizeOnDisk, nofEntries : LONGINT;

			PROCEDURE ShowError(CONST string : ARRAY OF CHAR);
			BEGIN
				INC(errors);
				w.String("Error "); w.Int(errors, 2); w.String(": "); w.String(string);
			END ShowError;

			PROCEDURE CheckFile(CONST filename, description : ARRAY OF CHAR);
			BEGIN
				IF ~FileExists(filename) THEN
					ShowError(description); w.String(" "); w.String(filename); w.String(" not found"); w.Ln;
				END;
			END CheckFile;

		BEGIN
			ASSERT(w # NIL);
			errors := 0;
			IF DoStep(WriteMBR) THEN CheckFile(mbrFile, "MBR file"); END;
			IF DoStep(Format) THEN CheckFile(bootloader, "Boot loader file "); CheckFile(bootfile, "Boot file"); END;
			IF DoStep(UpdateBootfile) THEN CheckFile(bootfile, "Boot file"); END;
			IF DoStep(SetConfig) & (configTable = NIL) THEN
				ShowError("No configurations strings set"); w.Ln;
			END;
			IF DoStep(InstallBootManager) THEN
				CheckFile(bootManMBR, "Boot Manager MBR file"); CheckFile(bootManRest, "Boot Manager Rest file");
			END;
			IF ~DoStep(Mount) THEN
				IF (disk.fs = NIL) OR ((disk.fs # NIL) & (partition < LEN(disk.fs)) & (disk.fs[partition] = NIL)) THEN
					ShowError("Disk is already mounted, but could not determine file system prefix"); w.Ln;
				END;
			END;
			IF DoStep(InstallPackages) & (packages # NIL) THEN
				packages.GetInstallSize(installSize, installSizeOnDisk, nofEntries);
				installSizeOnDisk := installSizeOnDisk DIV 1024 + 1;
				IF (installSizeOnDisk > SpaceAvailable()) THEN
					ShowError("Not enough disk space: "); w.Ln;
					w.String("Available disk space: "); w.Int(SpaceAvailable(), 0); w.String(" KB"); w.Ln;
					w.String("Required disk space: "); w.Int(installSizeOnDisk, 0); w.String(" KB"); w.Ln;
				END;
			END;
			w.Update;
			RETURN errors = 0;
		END CheckConfiguration;

		PROCEDURE ToStream*(w : Streams.Writer);
		VAR step : LONGINT;

			PROCEDURE ShowStep(CONST string : ARRAY OF CHAR);
			BEGIN
				INC(step);
				w.Int(step, 3); w.String(": "); w.String(string);
			END ShowStep;

		BEGIN
			ASSERT(w # NIL);
			w.String("To install A2 on partition "); w.String(diskpartString); w.String(", the following steps will be done:");
			w.Ln; w.Ln;

			step := 0;
			IF DoStep(WriteMBR)THEN ShowStep("Write MBR ("); w.String(mbrFile); w.String(")"); w.Ln; END;
			IF DoStep(CreatePartition) THEN ShowStep("Create partition of type 4C (AosFS)"); w.Ln; END;
			IF DoStep(ChangeType) THEN
				ShowStep("Change type of partition "); w.String(diskpartString); w.String(" from ");
				w.Hex(disk.table[partition].type, -2); w.String(" to "); w.Hex(AosPartitionType, -2); w.Ln;
			END;
			IF DoStep(Activate) THEN ShowStep("Set active flag of partiton "); w.String(diskpartString); w.Ln; END;
			IF DoStep(Format) THEN
				ShowStep("Format partiton "); w.String(diskpartString); w.String(" as AosFS (");
				w.String("Boot Loader: "); w.String(bootloader); w.String(", ");
				w.String("Boot File: "); w.String(bootfile); w.String(")");
				w.Ln;
			END;
			IF DoStep(UpdateBootfile) THEN
				ShowStep("Update boot file (Boot file: "); w.String(bootfile); w.String(")"); w.Ln;
			END;
			IF DoStep(SetConfig) THEN
				ShowStep("Set configuration strings"); w.Ln;
			END;
			IF DoStep(InstallBootManager) THEN
				ShowStep("Install Boot Manager into MBR ("); w.String(bootManMBR); w.String(", "); w.String(bootManRest);
				w.String(")"); w.Ln;
			END;
			IF DoStep(Mount) THEN
				ShowStep("Mounting partition "); w.String(diskpartString); w.Ln;
			END;
			IF DoStep(InstallPackages) THEN
				ShowStep("Installing packages"); w.Ln;
			END;
			IF DoStep(Unmount) THEN
				ShowStep("Ummount partition "); w.String(diskpartString); w.Ln;
			END;
			w.Update;
		END ToStream;

		PROCEDURE DisallowAllSteps;
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO LEN(steps)-1 DO
				steps[i] := NotAllowed;
			END;
		END DisallowAllSteps;


		PROCEDURE DetectInstallSettings;
		BEGIN
			DisallowAllSteps;

			IF (Disks.Mounted IN disk.table[partition].flags) OR (Disks.Valid IN disk.table[0].flags) THEN
				steps[WriteMBR] := NotAllowed;
			ELSE
				steps[WriteMBR] := Mandatory;
			END;
			mbrFile := DefaultMBRFile;

			IF (disk.table[partition].type = Free) THEN
				steps[CreatePartition] := Mandatory;
			ELSE
				steps[CreatePartition] := NotAllowed;
			END;
			size := 0;

			IF ~(Disks.Mounted IN disk.table[partition].flags) & (disk.table[partition].type # Free) & (disk.table[partition].type # AosPartitionType) THEN
				steps[ChangeType] := Mandatory;
			ELSE
				steps[ChangeType] := NotAllowed;
			END;

			IF (Disks.Mounted IN disk.table[partition].flags) OR (Disks.Boot IN disk.table[partition].flags) THEN steps[Activate] := NotAllowed;
			ELSE
				IF (steps[WriteMBR] = Mandatory) OR ((steps[CreatePartition] = Mandatory) & (LEN(disk.table)=2)) THEN
					steps[Activate] := OptionalYes;
				ELSE
					steps[Activate] := OptionalNo;
				END;
			END;

			IF ~(Disks.Mounted IN disk.table[partition].flags) THEN
				steps[Format] := Mandatory;
			ELSE
				steps[Format] := NotAllowed;
			END;
			bootloader := DefaultBootLoader;

			IF ~DoStep(Format) THEN
				steps[UpdateBootfile] := OptionalYes;
			ELSE
				steps[UpdateBootfile] := OptionalNo;
			END;

			IF IsUsbDisk() THEN
				bootfile := DefaultUsbBootfile;
			ELSE
				bootfile := DefaultBootfile;
			END;

			IF DoStep(Format) THEN
				steps[SetConfig] := OptionalYes;
			ELSE
				steps[SetConfig] := OptionalNo;
			END;

			IF DoStep(WriteMBR) & IsUsbDisk() THEN
				steps[InstallBootManager] := OptionalYes;
			ELSE
				steps[InstallBootManager] := OptionalNo;
			END;
			bootManMBR := DefaultBootManMBR;
			bootManRest := DefaultBootManRest;

			mountPrefix := "";
			IF (Disks.Mounted IN disk.table[partition].flags) THEN
				steps[Mount] := NotAllowed;
				IF (disk.fs # NIL) & (partition < LEN(disk.fs)) & (disk.fs[partition] # NIL) THEN
					mountPrefix := disk.fs[partition].prefix;
				END;
			ELSE
				steps[Mount] := Mandatory;
				mountPrefix := GetPrefix();
			END;
			steps[InstallPackages] := OptionalNo;

			IF (Disks.Mounted IN disk.table[partition].flags) THEN
				steps[Unmount] := NotAllowed;
			ELSE
				steps[Unmount] := OptionalYes;
			END;
		END DetectInstallSettings;

		PROCEDURE Clone*() : Configuration;
		VAR c : Configuration; i : LONGINT;
		BEGIN
			NEW(c, disk, partition);
			FOR i := 0 TO LEN(c.steps)-1 DO c.steps[i] := steps[i]; END;
			c.mbrFile := mbrFile;
			c.size := size;
			c.bootloader := bootloader;
			c.bootfile := bootfile;
			c.configTable := configTable.Clone();
			c.bootManMBR := bootManMBR;
			c.bootManRest := bootManRest;
			c.mountPrefix := mountPrefix;
			c.packages := packages;
			RETURN c;
		END Clone;

		PROCEDURE SetPackages*(packages : Packages);
		BEGIN
			SELF.packages := packages;
			IF (packages # NIL) THEN
				steps[InstallPackages] := OptionalYes;
			ELSE
				steps[InstallPackages] := NotAllowed;
			END;
		END SetPackages;

		PROCEDURE &Init*(disk : PartitionsLib.Disk; partition : LONGINT);
		VAR nbr : ARRAY 8 OF CHAR;
		BEGIN
			ASSERT(disk.device # NIL);
			ASSERT((1 <= partition) & (partition < LEN(disk.table)));
			SELF.disk := disk; SELF.partition := partition;
			COPY(disk.device.name, diskpartString);
			Strings.Append(diskpartString, "#"); Strings.IntToStr(partition, nbr); Strings.Append(diskpartString, nbr);
			packages := NIL;
			NEW(configTable);
			DetectInstallSettings;
		END Init;

	END Configuration;

TYPE

	Installer* = OBJECT(PartitionsLib.Operation)
	VAR
		(* parameters *)
		config : Configuration;

		currentStep, nofSteps : LONGINT;
		nofFiles : LONGINT;

		installLog : Streams.Writer;

		PROCEDURE SetInstallLog*(installLog : Streams.Writer);
		BEGIN
			ASSERT(installLog # NIL);
			SELF.installLog := installLog;
		END SetInstallLog;

		(** Write lock partition before this operation is running *)
		PROCEDURE Lock*() : BOOLEAN;
		BEGIN
			RETURN PartitionsLib.diskModel.AcquirePartition(disk, partition, PartitionsLib.WriterLock);
		END Lock;

		(** Release write lock *)
		PROCEDURE Unlock*;
		BEGIN
			PartitionsLib.diskModel.ReleasePartition(disk, partition);
		END Unlock;

		PROCEDURE SetParameters*(config : Configuration);
		BEGIN
			SELF.config := config;
		END SetParameters;

		PROCEDURE ValidParameters*() : BOOLEAN;
		BEGIN
			IF (config = NIL) THEN
				ReportError("No install configuration set");
				RETURN FALSE;
	(*		ELSIF (Disks.ReadOnly IN disk.table[partition].flags) THEN
				ReportError("Cannot install A2 on read-only device");
				RETURN FALSE; *)
			ELSIF (Disks.Mounted IN disk.table[partition].flags) & (disk.table[partition].type # AosPartitionType) THEN
				ReportError("Partition is mounted but type is not 76");
				RETURN FALSE;
			ELSIF (partition = 0) THEN
				ReportError("A2 must be installed into partition != 0");
				RETURN FALSE;
			END;
			RETURN TRUE;
		END ValidParameters;

		PROCEDURE SetStep(CONST string : PartitionsLib.String);
		VAR caption : PartitionsLib.String; nbr : ARRAY 8 OF CHAR;
		BEGIN
			INC(currentStep);
			Strings.IntToStr(currentStep, caption); Strings.Append(caption, " of "); Strings.IntToStr(nofSteps, nbr); Strings.Append(caption, nbr);
			Strings.Append(caption, ": "); Strings.Append(caption, string);
			SetStatus(state.status,  caption, 0, currentStep, 100, TRUE);
		END SetStep;

		PROCEDURE PackagesProgress(nofFilesExtracted : LONGINT);
		VAR progress : LONGINT;
		BEGIN
			IF nofFilesExtracted = nofFiles THEN
				progress := 100;
			ELSE
				progress := currentStep + ENTIER((100 - currentStep) * (nofFilesExtracted / nofFiles));
			END;
			SetCurrentProgress(progress);
		END PackagesProgress;

		PROCEDURE DoOperation*;
		VAR i : LONGINT; res : WORD;
		BEGIN
			ASSERT((config.disk.device = disk.device) & (config.partition = partition));
			installLog.String("Starting installation on partition "); installLog.String(diskpartString); installLog.String("..."); installLog.Ln; installLog.Update;
			currentStep := 0;
			nofSteps := config.GetNofSteps();

			IF Aborted() THEN ReportAbort; RETURN; END;
			IF config.DoStep(WriteMBR) THEN (* no MBR *)
				ASSERT(disk.table[0].flags * {Disks.Valid} = {});
				SetStep("Writing MBR");
				IF ~DoWriteMBR() THEN
					ReportError("Could not write MBR to disk");
					RETURN;
				END;
			END;

			IF Aborted() THEN ReportAbort; RETURN; END;
			IF config.DoStep(CreatePartition) THEN
				ASSERT(disk.table[partition].type = Free);
				SetStep("Creating partition");
				ASSERT(disk.device.openCount = 1);
				IF DoCreatePartition() THEN
					ASSERT((partition = 1));
					disk.device.Close(res);
					Disks.UpdatePartitionTable(disk.device, res);
					disk.device.Open(res);
					FOR i := 0 TO LEN(disk.device.table)-1 DO
						disk.table[i] := disk.device.table[i];
					END;
				ELSE
					ReportError("Could not create primary partition");
					RETURN;
				END;
			END;

			IF Aborted() THEN ReportAbort; RETURN; END;
			IF config.DoStep(ChangeType) THEN
				ASSERT(disk.table[partition].type # AosPartitionType);
				SetStep("Change partition type");
				IF ~DoChangePartitionTypeTo(disk.table[partition].type, AosPartitionType) THEN
					ReportError("Could not change partition type");
					RETURN;
				END;
			END;

			IF Aborted() THEN ReportAbort; RETURN; END;
			IF config.DoStep(Activate) & (disk.table[partition].flags * {Disks.Boot} = {}) THEN
				SetStep("Activate partition");
				IF ~DoActivatePartition() THEN
					ReportError("Could not set active flag");
					RETURN;
				END;
			END;

			IF Aborted() THEN ReportAbort; RETURN; END;
			IF config.DoStep(InstallBootManager) THEN
				IF ~DoInstallBootManager() THEN
					ReportError("Could not install boot manager");
					RETURN;
				END;
			END;

			IF Aborted() THEN ReportAbort; RETURN; END;
			IF config.DoStep(Format) THEN
				SetStep("Formatting partition");
				IF ~DoFormatPartition() THEN
					ReportError("Could not format the partition");
					RETURN;
				END;
			END;

			IF Aborted() THEN ReportAbort; RETURN; END;
			IF config.DoStep(UpdateBootfile) THEN
				SetStep("Updating boot file");
				IF ~DoUpdateBootFile() THEN
					ReportError("Could not update boot file");
					RETURN;
				END;
			END;

			IF Aborted() THEN ReportAbort; RETURN; END;
			IF config.DoStep(SetConfig) THEN
				SetStep("Setting configuration");
				IF ~DoSetConfiguration() THEN
					ReportError("Could not write configuration string");
					RETURN;
				END;
			END;

			IF Aborted() THEN ReportAbort; RETURN; END;
			IF config.DoStep(Mount) & (disk.table[partition].flags * {Disks.Mounted} = {}) THEN
				SetStep("Mounting partition");
				IF ~DoMountPartition() THEN
					ReportError("Could not mount the partition");
					RETURN;
				END;
			END;

			IF Aborted() THEN ReportAbort; RETURN; END;
			IF config.DoStep(InstallPackages) THEN
				SetStep("Installing packages");
				IF ~DoInstallPackages() THEN
					ReportError("Could not install packages");
					RETURN;
				END;
			END;

			IF Aborted() THEN ReportAbort; RETURN; END;
			IF config.DoStep(Unmount) THEN
				DoUnmount;
			END;
			SetCurrentProgress(100);
			installLog.String("Successfully installed on partition "); installLog.String(diskpartString); installLog.String("."); installLog.Update;
		END DoOperation;

		PROCEDURE DoInstallPackages() : BOOLEAN;
		VAR path : Files.FileName; ignore : LONGINT;
		BEGIN
			ASSERT(config.packages # NIL);
			installLog.String("Installing packages to "); installLog.String(config.mountPrefix); installLog.String(" ... "); installLog.Ln; installLog.Update;
			COPY(config.mountPrefix, path); Strings.Append(path, ":");
			config.packages.SetInstallLog(installLog);
			config.packages.SetReportProgressProc(PackagesProgress);
			config.packages.SetAbortedProc(Aborted);
			config.packages.GetInstallSize(ignore, ignore, nofFiles);
			config.packages.InstallPackages(path);
			RETURN TRUE;
		END DoInstallPackages;

		PROCEDURE DoWriteMBR() : BOOLEAN;
		VAR operation : PartitionsLib.WriteMBR;
		BEGIN
			installLog.String("Writing MBR to disk (MBR File: "); installLog.String(config.mbrFile); installLog.String(") ... "); installLog.Update;
			NEW(operation, disk, 0, out);
			operation.SetParent(SELF);
			operation.SetParameters(config.mbrFile, FALSE, FALSE);
			operation.SetBlockingStart;
			RETURN OperationDone(operation);
		END DoWriteMBR;

		PROCEDURE DoCreatePartition() : BOOLEAN;
		VAR operation : PartitionsLib.CreatePartition;
		BEGIN
			installLog.String("Creating partition... "); installLog.Update;
			NEW(operation, disk, partition, out);
			operation.SetParent(SELF);
			operation.SetParameters(999999, AosPartitionType, TRUE);
			operation.SetBlockingStart;
			RETURN OperationDone(operation);
		END DoCreatePartition;

		PROCEDURE DoChangePartitionTypeTo(oldType, newType : LONGINT) : BOOLEAN;
		VAR operation : PartitionsLib.ChangePartType;
		BEGIN
			installLog.String("Change partition type from "); installLog.Hex(oldType, 2); installLog.String("h to "); installLog.Hex(newType, 2);
			installLog.String("h ... "); installLog.Update;
			NEW(operation, disk, partition, out);
			operation.SetParent(SELF);
			operation.SetParameters(oldType, newType);
			operation.SetBlockingStart;
			RETURN OperationDone(operation);
		END DoChangePartitionTypeTo;

		PROCEDURE DoActivatePartition() : BOOLEAN;
		VAR operation : PartitionsLib.SetFlags;
		BEGIN
			installLog.String("Set active flag... "); installLog.Update;
			NEW(operation, disk, partition, out);
			operation.SetParent(SELF);
			operation.SetParameters(TRUE);
			operation.SetBlockingStart;
			RETURN OperationDone(operation);
		END DoActivatePartition;

		PROCEDURE DoInstallBootManager() : BOOLEAN;
		VAR operation : PartitionsLib.InstallBootManager;
		BEGIN
			installLog.String("Install Bluebottle Boot Manager..."); installLog.Update;
			NEW(operation, disk, 0, out);
			operation.SetParent(SELF);
			operation.SetParameters(config.bootManMBR, config.bootManRest);
			operation.SetBlockingStart;
			RETURN OperationDone(operation);
		END DoInstallBootManager;

		PROCEDURE DoFormatPartition() : BOOLEAN;
		VAR operation : PartitionsLib.FormatPartition;
		BEGIN
			installLog.String("Formatting partition (Boot Loader: "); installLog.String(config.bootloader);
			installLog.String(", Boot File: "); installLog.String(config.bootfile); installLog.String(") ... "); installLog.Update;
			NEW(operation, disk, partition, out);
			operation.SetParent(SELF);
			operation.SetParameters(AosFsName, config.bootfile, -2, 0);
			operation.SetBlockingStart;
			RETURN OperationDone(operation);
		END DoFormatPartition;

		PROCEDURE DoUpdateBootFile() : BOOLEAN;
		VAR operation : PartitionsLib.UpdateBootFile;
		BEGIN
			installLog.String("Updating boot file ("); installLog.String(config.bootfile); installLog.String(") ... "); installLog.Update;
			NEW(operation, disk, partition, out);
			operation.SetParent(SELF);
			operation.SetParameters(config.bootfile);
			operation.SetBlockingStart;
			RETURN OperationDone(operation);
		END DoUpdateBootFile;

		PROCEDURE DoSetConfiguration() : BOOLEAN;
		VAR
			operation : PartitionsLib.SetConfig; configString : Strings.String;
			bootString : ARRAY 128 OF CHAR;
		BEGIN
			installLog.String("Writing configuration strings (BootVol is "); installLog.String(diskpartString); installLog.String(") ... "); installLog.Update;
			IF (config.configTable = NIL) THEN ReportError("Configuration table is NIL"); RETURN FALSE; END;

			COPY(BootVolString, bootString);
			Strings.Append(bootString, diskpartString);
			config.configTable.SetValueOf(Strings.NewString("BootVol1"), Strings.NewString(bootString));
			configString := config.configTable.GetAsString();

			NEW(operation, disk, partition, out);
			operation.SetParent(SELF);
			operation.SetParameters(configString, 0);
			operation.SetBlockingStart;
			RETURN OperationDone(operation);
		END DoSetConfiguration;

		PROCEDURE DoMountPartition() : BOOLEAN;
		VAR operation : PartitionsLib.Mount;
		BEGIN
			installLog.String("Mounting partition... "); installLog.Update;
			NEW(operation, disk, partition, out);
			operation.SetParent(SELF);
			operation.SetParameters(config.mountPrefix, "AosFS", "", "");
			operation.SetBlockingStart;
			RETURN OperationDone(operation);
		END DoMountPartition;

		PROCEDURE DoUnmount;
		VAR context : Commands.Context; arg : Streams.StringReader;  msg : ARRAY 128 OF CHAR; res : WORD;
		BEGIN
			installLog.String("Unmounting "); installLog.String(diskpartString); installLog.String("... "); installLog.Update;
			NEW(arg, LEN(config.mountPrefix)); arg.SetRaw(config.mountPrefix, 0, LEN(config.mountPrefix));
			NEW(context, NIL, arg, NIL, NIL, SELF);
			Commands.Activate("FSTools.Unmount", context, {Commands.Wait}, res, msg);
			IF (res = Commands.Ok) THEN
				installLog.String("done.");
			ELSE
				installLog.String("failed");
				installLog.String(" ("); installLog.String(msg); installLog.String(")");
			END;
			installLog.Ln;
			installLog.Update;
		END DoUnmount;

		PROCEDURE OperationDone(operation : PartitionsLib.Operation) : BOOLEAN;
		VAR noErrors : BOOLEAN; state : PartitionsLib.OperationState; errors: Strings.String;
		BEGIN
			state := operation.GetState();
			noErrors := (state.status * PartitionsLib.StatusFinished = PartitionsLib.StatusFinished) & (state.errorCount = 0);
			IF noErrors THEN
				installLog.String("done."); installLog.Ln;
			ELSE
				installLog.Ln;
				errors := operation.GetErrors (); installLog.String(errors^);
				installLog.Ln;
			END;
			installLog.Update;
			RETURN noErrors;
		END OperationDone;

		PROCEDURE ReportAbort;
		BEGIN
			installLog.String("Installation aborted by user."); installLog.Ln; installLog.Update;
		END ReportAbort;

		PROCEDURE &Init*(disk :PartitionsLib.Disk; partition : LONGINT; out : Streams.Writer);
		BEGIN
			Init^(disk, partition, out);
			name := "Installer"; desc := "Install A2 on partition"; locktype := PartitionsLib.WriterLock;
			NEW(installLog, KernelLog.Send, 128);
		END Init;

	END Installer;

TYPE

	ReportProgressProc = PROCEDURE {DELEGATE} (nofFilesExtracted : LONGINT);
	AbortedProc = PROCEDURE {DELEGATE} () : BOOLEAN;
	ReportErrorProc = PROCEDURE {DELEGATE} (CONST msg : ARRAY OF CHAR);

	Package* = OBJECT
	VAR
		number- : LONGINT;

		(** Shall this package be installed? *)
		install- : BOOLEAN;
		installType- : LONGINT; (* Mandatory, OptionalYes, OptionalNo, NotAllowed *)

		filename- : XML.String;
		file- : Files.File;

		name-, description- : XML.String;

		(* Number of files contained in the package *)
		nofEntries- : LONGINT;

		(* Size of all files in package  in bytes when extracted *)
		size- : LONGINT;

		(* size plus overhead introduced with Files file system (conservative approximation) *)
		sizeOnDisk- : LONGINT;

		user* : ANY;

		next : Package;

		(** Set his package to be installed or not. *)
		PROCEDURE SetInstall*(install : BOOLEAN; VAR msg : ARRAY OF CHAR) : BOOLEAN;
		BEGIN
			msg := "";
			IF install THEN
				IF (file = NIL) THEN
					msg := "File "; Strings.Append(msg, filename^); Strings.Append(msg, " not found");
					RETURN FALSE;
				ELSIF (installType = NotAllowed) THEN
					msg := "Installation of this package is not allowed";
					RETURN FALSE;
				END;
			ELSE
				IF (installType = Mandatory) THEN
					msg := "This package is required";
					RETURN FALSE;
				END;
			END;
			SELF.install := install;
			RETURN TRUE;
		END SetInstall;

		PROCEDURE Parse(p : XML.Element; error : Streams.Writer) : BOOLEAN;
		VAR nofErrors : LONGINT;
		BEGIN
			nofErrors := 0;

			number := GetXmlNumber(p, XmlPackageNumber);
			IF (number = -1) THEN
				error.String("Package number attribute not found"); error.Ln;
				INC(nofErrors);
			ELSIF (number < 1) OR (MaxPackages < number) THEN
				error.String("Package number invalid"); error.Ln;
				INC(nofErrors);
			END;

			filename := p.GetAttributeValue(XmlPackageFilename);
			IF (filename = NIL) THEN
				error.String("Filename attribute not found"); error.Ln;
				INC(nofErrors);
			ELSE
				file := Files.Old(filename^);
			END;

			name:= p.GetAttributeValue(XmlPackageName);
			IF (name = NIL) THEN
				name := Strings.NewString("NoName");
			END;

			description := p.GetAttributeValue(XmlPackageDescription);
			IF (description = NIL) THEN
				description := Strings.NewString("No Description Available");
			END;

			installType := GetInstallType(p);
			IF (installType = Invalid) THEN installType := OptionalNo; END;

			install := TRUE;
			IF (installType = OptionalNo) OR (installType = NotAllowed) OR (file = NIL) THEN
				install := FALSE;
			END;

			RETURN (nofErrors = 0);
		END Parse;

		PROCEDURE Show;
		BEGIN
			KernelLog.String("Package Nr "); KernelLog.Int(number, 0); KernelLog.String(": ");
			KernelLog.String(name^); KernelLog.String(" ("); KernelLog.String(description^); KernelLog.String(") ");
			KernelLog.String(", Filename: "); KernelLog.String(filename^);
			KernelLog.String(", installType: "); KernelLog.Int(installType, 0);
			KernelLog.Ln;
		END Show;

		PROCEDURE &Init*;
		BEGIN
			number := -1; install := FALSE;
			filename := NIL; file := NIL;
			name := NIL; description := NIL;
			nofEntries := 0; size := 0; sizeOnDisk := 0;
			user := NIL; next := NIL;
		END Init;

	END Package;

	PackageArray*= POINTER TO ARRAY OF Package;

TYPE

	Packages* = OBJECT
	VAR
		hasErrors : BOOLEAN;
		ReportError : ReportErrorProc;

		(* Head and tail of package list *)
		head, tail : Package;

		info : Streams.Writer;
		path : Files.FileName;

		nofFilesExtracted : LONGINT;

		reportProgress : ReportProgressProc;
		Aborted : AbortedProc;

		PROCEDURE GetNofPackages() : LONGINT;
		VAR nofPackages : LONGINT; package : Package;
		BEGIN
			nofPackages := 0;
			package := head;
			WHILE (package # NIL) DO INC(nofPackages); package := package.next; END;
			RETURN nofPackages;
		END GetNofPackages;

		PROCEDURE GetPackages*() : PackageArray;
		VAR result : PackageArray; package : Package; nofPackages, i : LONGINT;
		BEGIN
			result := NIL;
			nofPackages := GetNofPackages();
			IF (nofPackages > 0) THEN
				NEW(result, nofPackages);
				package := head;
				i := 0;
				WHILE (package # NIL) DO
					result[i] := package; INC(i);
					package := package.next;
				END;
			END;
			RETURN result;
		END GetPackages;

		PROCEDURE ReportProgress(nofFilesExtracted : LONGINT);
		BEGIN
			IF (reportProgress # NIL) THEN reportProgress(nofFilesExtracted); END;
		END ReportProgress;

		PROCEDURE ExtractEntry(zip: AosUnzip.ZipFile; entry: AosUnzip.Entry; CONST name: ARRAY OF CHAR; VAR res : WORD);
		VAR file: Files.File; w : Files.Writer; string : ARRAY 256 OF CHAR;
		BEGIN
			res := 0;
			file := Files.New(name);
			IF file = NIL THEN
				string := "Could not create file "; Strings.Append(string, name);
				ReportError(string); res := 99;
				RETURN
			END;
			Files.OpenWriter(w, file, 0);
			zip.Extract(entry, w, res);
			IF res = Streams.Ok THEN
				w.Update(); Files.Register(file);
			ELSE
				string := "Extracting "; Strings.Append(string, name); Strings.Append(string, " failed");
				ReportError(string); res := 99;
			END;
		END ExtractEntry;

		PROCEDURE Unzip(zipFile : AosUnzip.ZipFile) : BOOLEAN;
		VAR e : AosUnzip.Entry; res : WORD; name : Files.FileName;
		BEGIN
			res := 0;
			e := zipFile.GetFirst();
			WHILE e # NIL DO
				IF (path # "") THEN
					COPY(path, name); Strings.Append(name, e.name^)
				ELSE
					COPY(e.name^, name)
				END;
				ExtractEntry(zipFile, e, name, res);
				IF res # 0 THEN RETURN FALSE; END;
				INC(nofFilesExtracted);
				ReportProgress(nofFilesExtracted);
				e := zipFile.GetNext(e);
				IF Aborted() THEN e := NIL; END;
			END;
			RETURN res = 0;
		END Unzip;

		PROCEDURE OpenZipFile(CONST filename : ARRAY OF CHAR; reportErrors : BOOLEAN) : AosUnzip.ZipFile;
		VAR file : Files.File; res : WORD; string : ARRAY 256 OF CHAR; zipFile : AosUnzip.ZipFile;
		BEGIN
			zipFile := NIL;
			file := Files.Old(filename);
			IF (file # NIL) THEN
				NEW(zipFile, file, res);
				IF (res # Streams.Ok) THEN
					zipFile := NIL;
					COPY(filename, string); Strings.Append(string, " is not a valid ZIP file");
					ReportError(string);
				END;
			ELSIF reportErrors THEN
				string := "ZIP file "; Strings.Append(string, filename); Strings.Append(string, " not found");
				ReportError(string);
			END;
			RETURN zipFile;
		END OpenZipFile;

		PROCEDURE GetPackageSizes*;
		VAR package : Package; zipFile : AosUnzip.ZipFile;

			PROCEDURE GetSizes(zipFile : AosUnzip.ZipFile; VAR size, sizeOnDisk : LONGINT);
			VAR e : AosUnzip.Entry;
			BEGIN
				size := 0; sizeOnDisk := 0;
				e := zipFile.GetFirst();
				WHILE e # NIL DO
					size := size + e.size;
					(* Round up file size to file system block size and add an constant representing the overhead of meta data per file *)
					sizeOnDisk := sizeOnDisk + e.size + (BlockSize - (e.size MOD BlockSize)) + FsMetaOverheadPerFile;
					e := zipFile.GetNext(e)
				END;
			END GetSizes;

		BEGIN
			package := head;
			WHILE (package # NIL) DO
				zipFile := OpenZipFile(package.filename^, FALSE);
				IF (zipFile # NIL) THEN
					package.nofEntries := zipFile.NoOfEntries();
					GetSizes(zipFile, package.size, package.sizeOnDisk);
				END;
				package := package.next;
			END;
		END GetPackageSizes;

		PROCEDURE GetInstallSize*(VAR size, sizeOnDisk, nofEntries : LONGINT);
		VAR package : Package;
		BEGIN
			size := 0; sizeOnDisk := 0; nofEntries := 0;
			package := head;
			WHILE (package # NIL) DO
				IF package.install THEN
					size := size + package.size;
					sizeOnDisk := sizeOnDisk + package.sizeOnDisk;
					nofEntries := nofEntries + package.nofEntries;
				END;
				package := package.next;
			END;
			size := size DIV 1024;
		END GetInstallSize;

		PROCEDURE InstallPackages*(CONST targetPath : ARRAY OF CHAR);
		VAR package : Package; zipFile : AosUnzip.ZipFile; oldNofFilesExtracted : LONGINT;
		BEGIN
			nofFilesExtracted := 0;
			COPY(targetPath, path);
			package := head;
			WHILE (package # NIL) DO
				IF package.install THEN
					zipFile := OpenZipFile(package.filename^, TRUE);
					IF (zipFile # NIL) THEN
						oldNofFilesExtracted := nofFilesExtracted;
						info.String("Extracting package "); info.String(package.filename^); info.String("... "); info.Update;
						IF ~Unzip(zipFile) THEN
							ReportError("ERROR");
						END;
						info.Int(nofFilesExtracted - oldNofFilesExtracted, 0); info.String(" files unpacked, done."); info.Ln; info.Update;
					END;
				END;
				package := package.next;
				IF Aborted() THEN package := NIL; END;
			END;
		END InstallPackages;

		PROCEDURE DefaultReportError(CONST msg : ARRAY OF CHAR);
		BEGIN
			KernelLog.String("Installer.Packages: Error: "); KernelLog.String(msg); KernelLog.Ln;
		END DefaultReportError;

		PROCEDURE SetInstallLog*(info : Streams.Writer);
		BEGIN
			ASSERT(info # NIL);
			SELF.info := info;
		END SetInstallLog;

		PROCEDURE SetReportErrorProc(proc : ReportErrorProc);
		BEGIN
			ReportError := proc;
		END SetReportErrorProc;

		PROCEDURE SetReportProgressProc(proc : ReportProgressProc);
		BEGIN
			reportProgress := proc;
		END SetReportProgressProc;

		PROCEDURE SetAbortedProc(proc : AbortedProc);
		BEGIN
			ASSERT(proc # NIL);
			Aborted := proc;
		END SetAbortedProc;

		(* Report errors while parsing *)
		PROCEDURE Error(pos, line, row: LONGINT; CONST msg: ARRAY OF CHAR);
		VAR string : ARRAY 256 OF CHAR; nbr : ARRAY 16 OF CHAR;
		BEGIN
			string := "Parse error at pos "; Strings.IntToStr(pos, nbr); Strings.Append(string, nbr);
			Strings.Append(string, " in line "); Strings.IntToStr(line, nbr); Strings.Append(string, nbr);
			Strings.Append(string, " row "); Strings.IntToStr(row, nbr); Strings.Append(string, nbr);
			Strings.Append(string, msg);
			ReportError(msg);
			hasErrors := TRUE
		END Error;

		PROCEDURE OpenPackages*(CONST name : ARRAY OF CHAR; error : Streams.Writer) : BOOLEAN;
		VAR
			reader : Streams.Reader;
			scanner : XMLScanner.Scanner; parser : XMLParser.Parser; doc : XML.Document;
		BEGIN
			ASSERT(error # NIL);
			hasErrors := FALSE;
			reader := Codecs.OpenInputStream(name);
			IF reader # NIL THEN
				NEW(scanner, reader); scanner.reportError := Error;
				NEW(parser, scanner); parser.reportError := Error;
				doc := parser.Parse();
				IF ~hasErrors THEN
					head := ParsePackages(doc, error);
					IF (head # NIL) THEN
						RETURN TRUE;
					END;
				ELSE
					error.String("XML parsing error(s) occured"); error.Ln;
				END;
			ELSE
				error.String("XML file '"); error.String(name); error.String("' not found"); error.Ln;
			END;
			RETURN FALSE;
		END OpenPackages;

		PROCEDURE ParsePackages(document : XML.Document; error : Streams.Writer) : Package;
		VAR
			enum : XMLObjects.Enumerator; e : XML.Element; p : ANY; s : XML.String;
			package : Package;
		BEGIN
			ASSERT(error # NIL);
			head := NIL; tail := NIL;
			e := document.GetRoot(); enum := e.GetContents();
			WHILE enum.HasMoreElements() DO
				p := enum.GetNext();
				IF p IS XML.Element THEN
					e := p(XML.Element); s := e.GetName();
					IF (s # NIL) & (s^ = XmlPackage) THEN
						NEW(package);
						IF package.Parse(e, error) THEN
							package.next := NIL;
							IF (head = NIL) THEN
								head := package; tail := package;
							ELSE
								tail.next := package; tail := package;
							END;
						ELSE
							head := NIL; tail := NIL;
							RETURN NIL;
						END;
					END;
				END;
			END;
			RETURN head;
		END ParsePackages;

		PROCEDURE CheckPackages() : BOOLEAN;
		VAR package : Package; errors : LONGINT;

			PROCEDURE Error(packagename : XML.String; CONST msg1, msg2 : ARRAY OF CHAR);
			VAR string : ARRAY 256 OF CHAR;
			BEGIN
				string := "Package ";
				IF (packagename # NIL) THEN Strings.Append(string, packagename^) ELSE Strings.Append(string, "Unknown"); END;
				Strings.Append(string, ": "); Strings.Append(string, msg1); Strings.Append(string, msg2);
				ReportError(string);
				INC(errors);
			END Error;

		BEGIN
			errors := 0;
			IF (head # NIL) THEN
				package := head;
				WHILE (package # NIL) DO
					IF (package.install) & (package.file = NIL) THEN
						Error(package.name, "File not found; ", package.filename^);
					END;
					package := package.next;
				END;
			ELSE
				ReportError("No packages found"); INC(errors);
			END;
			RETURN errors = 0;
		END CheckPackages;

		PROCEDURE Show;
		VAR package : Package;
		BEGIN
			KernelLog.String("Packages: "); KernelLog.Ln;
			IF (head # NIL) THEN
				package := head;
				WHILE (package # NIL) DO
					package.Show; package := package.next;
				END;
			ELSE
				KernelLog.String("No packages loaded."); KernelLog.Ln;
			END;
		END Show;

		PROCEDURE DefaultAborted() : BOOLEAN;
		BEGIN
			RETURN FALSE;
		END DefaultAborted;

		PROCEDURE &Init*;
		BEGIN
			SELF.Aborted := DefaultAborted;
			SetReportErrorProc(DefaultReportError);
			NEW(info, KernelLog.Send, 256);
		END Init;

	END Packages;

VAR
	suffix : LONGINT;

PROCEDURE FileExists(CONST filename : ARRAY OF CHAR) : BOOLEAN;
VAR file : Files.File;
BEGIN
	file := Files.Old(filename);
	RETURN file # NIL;
END FileExists;

PROCEDURE GetInstallType(p : XML.Element) : LONGINT;
VAR installType : LONGINT; string : XML.String;
BEGIN
	ASSERT(p # NIL);
	installType := OptionalYes;
	string := p.GetAttributeValue(XmlPackageInstall);
	IF (string # NIL) THEN
		Strings.UpperCase(string^);
		IF (string^  = XmlInstallYes) THEN installType := OptionalYes;
		ELSIF (string^ = XmlInstallNo) THEN installType := OptionalNo;
		ELSIF (string^ = XmlInstallRequired) THEN installType := Mandatory;
		END;
	END;
	RETURN installType;
END GetInstallType;

(* Returns -1 in case that the attribute has not been found *)
PROCEDURE GetXmlNumber(p : XML.Element; CONST attributeName : ARRAY OF CHAR) : LONGINT;
VAR number : LONGINT; string : XML.String;
BEGIN
	ASSERT(p # NIL);
	number := -1;
	string := p.GetAttributeValue(attributeName);
	IF (string # NIL) THEN
		Strings.StrToInt(string^, number);
	END;
	RETURN number;
END GetXmlNumber;

PROCEDURE GetPrefix() : Files.Prefix;
VAR prefix : Files.Prefix; nbr : ARRAY 8 OF CHAR;
BEGIN {EXCLUSIVE}
	COPY(DefaultPrefix, prefix);
	Strings.IntToStr(suffix, nbr);
	Strings.Append(prefix, nbr);
	INC(suffix);
	RETURN prefix;
END GetPrefix;

PROCEDURE TestPackages*(context : Commands.Context);
VAR
	filename : Files.FileName;
	packages : Packages;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(filename);
	context.out.String("Test packages object for file "); context.out.String(filename); context.out.String("... "); context.out.Ln;
	NEW(packages);
	IF packages.OpenPackages(filename, context.error) THEN
		IF packages.CheckPackages() THEN
			packages.Show;
		ELSE
			context.error.String("Package check failed."); context.error.Ln;
		END;
	ELSE
		context.error.String("Could not open packages"); context.error.Ln;
	END;
END TestPackages;

(** Quick-install the system on specified partition *)
PROCEDURE Install*(context : Commands.Context); (** dev#part ~ *)
VAR selection : PartitionsLib.Selection; installer : Installer;
BEGIN
	IF Partitions.GetSelection(context, FALSE, selection) THEN
		NEW(installer, selection.disk, selection.partition, context.out);
(*		installer.SetParameters(); *)
		installer.SetStart;
	ELSE (* skip; error written to <w> by ScanOpenPart *)
	END;
END Install;

END Installer.

Installer.TestPackages Packages.XML ~

System.Free Installer ~

System.FreeDownTo Installer ~

AosTar.Create Install.Tar
Installer.Mod WMInstaller.Mod
PartitionsLib.Mod Partitions.Mod WMPartitions.Mod
WMPartitionsComponents.Mod
InstallerPackages.XML
~
