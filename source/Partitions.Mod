MODULE Partitions; (** AUTHOR "staubesv"; PURPOSE "Commandline front-end for PartitionsLib"; *)
(**
 * This is the commandline front-end for PartitionsLib.
 *
 * Command overview:
 *
 * Uncritical operations:
 *
 *	Partitions.Show ~  								Show all disk devices and their partition layout
 * 	Partitions.Show detail ~							Show detailed information about all disk devices and their partition layout
 *	Partitions.ShowAosFSLimits ~ 					Show limitations of the Aos File System
 *
 * 	Partitions.ShowOps~   							Show all pending disk operations
 * 	Partitions.ShowOps detail ~						Show detailed information about all pending disk operations
 *
 *	Partitions.ShowOp uid ~							Show detailed status of the specified operation
 *	Partitions.Abort <opID> ~ 						Abort the disk operation with the specified operation ID
 * 	Partitions.Remove <opID> ~						Abort the disk operation with the specified operation ID and remove it from the operation manager
 *
 *	Partitions.Check dev#part ~						Perform a read test on the specified partition
 *	Partitions.Eject dev ~								Eject medium of the specified device
 *	Partitions.Sync dev ~								Synchronize device caches to medium
 *
 * 	Partitions.Safe~ 									Disallow extremely critical operations
 * 	Partitions.Unsafe~								Allow extermely critical operations
 *
 *	Partitions.ShowBlocks dev#part first nbr			Show <nbr> blocks starting at block <first> of the specified partition
 *
 * Critical operations:
 *
 *	Partitions.Create dev#part type sizeMB ~			Create a partition
 *	Partitions.Delete dev#part type ~					Delete the specified partition
 *	Partitions.Activate dev#part ~					Set the active bit (boot) of the specified partition
 *	Partitions.Deactivate dev#part ~					Clear the active bit (boot) of the specified partition
 *	Partitions.ChangeType dev#part from to ~			Change the type of the specified partition from <from> to <to>
 * 	Partitions.Format dev#part fs ~					Format the specified partition with the specified file system (AosFS, FatFS)
 *	Partitions.WriteMBR dev#part ~					Write MBR boot code to specified partition (partition table will be untouched)
 *
 *	Partitions.InstallBootManager dev#0 ~			Install boot manager
 *	Partitions.PartitionToFile dev#part file f nbr~ 		Write <nbr> blocks starting at block <f> to the specified file.
 *	Partitions.FileToPartition dev#part file f nbr~		Write the content of <file> to the specified partition starting at block <f>, <nbr> blocks
 *
 * Bluebottle-specific opertaions
 *
 *	Partitions.UpdateBootFile dev#part bootfile		Update the boot file (e.g. IDE.Bin) for the specified partition
 *	Partitions.UpdateBootLoader dev#part bl			Update the boot loader (e.g. OBL.Bin) for the specified partition
 *
 *	Partitions.GetConfig dev#part ~					Get the config string of the specified partition
 * 	Partitions.SetConfig dev#part config				Set the config string for the specified partition
 *
 *
 * History:
 *
 * 	05.08.2005	Cleanup (staubesv)
 *	25.11.2005	Added ShowOp procedure (staubesv)
 *	06.01.2006	Small cleanup (staubesv)
 *	17.01.2006	WriteMBR: Caller can specify "DESTROY" parameter, fixed SetConfig (staubesv)
 *)

IMPORT KernelLog, Texts, TextUtilities, Disks, Files, Lib := PartitionsLib, Plugins, Commands, Streams, Strings, FATScavenger;

CONST

	Trace = FALSE;

	Invalid = MIN(LONGINT);

	(* InstallBootManager default arguments *)
	BootManagerMBRFile = "BootManagerMBR.Bin";
	BootManagerTailFile = "BootManagerTail.Bin";

(** Show all currently pending disk operations *)
PROCEDURE ShowOps*(context : Commands.Context); (** [detail] ~ *)
VAR par : ARRAY 10 OF CHAR; details : BOOLEAN;
BEGIN
	par := ""; context.arg.SkipWhitespace; context.arg.String(par);
	details := (par = "detail");
	Lib.operations.Show(context.out, details);
END ShowOps;

(** Show the detailed state of the specified operation *)
PROCEDURE ShowOp*(context : Commands.Context); (** uid ~ *)
VAR operation : Lib.Operation; uid : LONGINT;
BEGIN
	IF context.arg.GetInteger(uid, FALSE)  THEN
		operation := Lib.operations.GetByUid(uid);
		IF operation # NIL THEN
			operation.Show(context.out, TRUE);
		ELSE
			context.error.String("Error: Operation UID "); context.error.Int(uid, 0); context.error.String(" not found"); context.error.Ln;
			context.result := Commands.CommandError;
		END;
	ELSE
		context.error.String("Exspected parameters: uid"); context.error.Ln;
		context.result := Commands.CommandParseError;
	END;
END ShowOp;

(** Abort a running operation *)
PROCEDURE Abort*(context : Commands.Context); (** uid  ~ *)
VAR operation : Lib.Operation; uid : LONGINT;
BEGIN
	IF context.arg.GetInteger(uid, FALSE) THEN
		operation := Lib.operations.GetByUid(uid);
		IF operation # NIL THEN
			operation.Abort;
			context.out.String("Operation UID "); context.out.Int(uid, 0); context.out.String(" aborted"); context.out.Ln;
		ELSE
			context.error.String("Error: Operation UID "); context.error.Int(uid, 0); context.error.String(" not found"); context.error.Ln;
			context.result := Commands.CommandParseError;

		END;
	ELSE
		context.error.String("Exspected parameters: uid"); context.error.Ln;
		context.result := Commands.CommandError;
	END;
END Abort;

(** Remove (and if necessary abort) operations from the operations registry *)
PROCEDURE Remove*(context : Commands.Context); (** uid | "all" | "finished" ~*)
VAR par : ARRAY 128 OF CHAR; uid, num : LONGINT;
BEGIN
	IF context.arg.GetInteger(uid, FALSE) THEN
		IF Lib.operations.RemoveByUid(uid) THEN
			context.out.String("Operation UID "); context.out.Int(uid, 0); context.out.String(" has been removed"); context.out.Ln;
		ELSE
			context.error.String("Error: Could not remove operation UID "); context.error.Int(uid, 0); context.error.Ln;
			context.result := Commands.CommandError;
		END;
	ELSIF context.arg.res = Streams.FormatError THEN
		par := "";
		context.arg.SetPos(0);
		IF context.arg.GetString(par)  THEN
			Strings.UpperCase(par);
			IF par = "ALL" THEN
				num := Lib.operations.RemoveAll(TRUE);
				context.out.Int(num, 0); context.out.String(" operations have been removed"); context.out.Ln;
			ELSIF par = "FINISHED" THEN
				context.out.String("All finished operation have been removed"); context.out.Ln;
			ELSE
				context.error.String("Expected parameters: uid | all | finished"); context.error.Ln;
				context.result := Commands.CommandParseError;
			END;
		ELSE
			context.error.String("Expected parameters: uid | all | finished"); context.error.Ln;
			context.result := Commands.CommandParseError;
		END;
	ELSE
		context.error.String("Expected parameters: uid | all | finished"); context.error.Ln;
		context.result := Commands.CommandParseError;
	END;
END Remove;

PROCEDURE Mount*(context : Commands.Context);
VAR
	mount :Lib.Mount;
	prefix, alias, volumePars, fsPars : ARRAY 64 OF CHAR;
	selection : Lib.Selection;
BEGIN
	IF GetSelection(context, TRUE, selection) THEN
		volumePars := ""; fsPars := "";
		IF context.arg.GetString(alias) & context.arg.GetString(prefix) THEN
			NEW(mount, selection.disk, selection.partition, context.out);
			mount.SetParameters(prefix, alias, volumePars, fsPars);
			mount.SetBlockingStart;
		ELSE
			context.error.String("Expected parameters: dev#part alias prefix"); context.error.Ln;
			context.result := Commands.CommandError;
		END;
	END;
END Mount;

(* Format a partition with an N2KFS, AosFS or FatFS. *)
PROCEDURE Format*(context : Commands.Context); (** dev#part [ "AosFS" | "NatFS" | "NatFS2" [ FSRes [ BootFile [ Flag ] ] ] ] | ["FatFS" ["Quick"]] ~ *)
VAR
	formatAos : Lib.FormatPartition; formatFat : FATScavenger.FormatPartition;
	fsname, bootfile, quick : ARRAY 128 OF CHAR;
	fsRes, flags : LONGINT;
	quickFormat : BOOLEAN;
	selection : Lib.Selection;
BEGIN
	IF GetSelection(context, TRUE, selection) THEN
		IF context.arg.GetString(fsname) THEN
			IF fsname = "FatFS" THEN
				quickFormat := context.arg.GetString(quick) & (quick = "Quick");
				NEW(formatFat, selection.disk, selection.partition, context.out);
				formatFat.SetParameters(Strings.NewString("no name"), quickFormat);
				formatFat.SetBlockingStart;
				context.out.String("Partitions UID "); context.out.Int(formatFat.uid, 0);
				context.out.String(": Started FAT format on "); context.out.String(formatFat.diskpartString); context.out.Ln;
			ELSIF (fsname = "AosFS") OR (fsname = "NatFS") OR (fsname = "NatFS1") OR (fsname = "NatFS2") THEN
				bootfile := ""; fsRes := -2; flags := 0;
				IF context.arg.GetInteger(fsRes, FALSE) THEN
					IF context.arg.GetString(bootfile) THEN
						context.arg.SkipWhitespace; context.arg.Int(flags, FALSE);
					END;
				END;
				NEW(formatAos, selection.disk, selection.partition, context.out);
				formatAos.SetParameters(fsname, bootfile, fsRes, flags);
				formatAos.SetBlockingStart;
			ELSE
				context.error.String("File system "); context.error.String(fsname); context.error.String(" is not supported"); context.error.Ln;
				context.result := Commands.CommandError;
			END;
		ELSE (* optional parameters not specified *)
			NEW(formatAos, selection.disk, selection.partition, context.out);
			formatAos.SetParameters("AosFS", "", -2, 0);
			formatAos.SetBlockingStart;
			context.out.String("Partitions UID "); context.out.Int(formatAos.uid, 0);
			context.out.String(": Started format on "); context.out.String(formatAos.diskpartString); context.out.Ln;
		END;
	END;
END Format;

(* Update the boot file in an existing Oberon partition. *)
PROCEDURE UpdateBootFile*(context : Commands.Context); (** dev#part BootFile ~ *)
VAR
	updateBootFile : Lib.UpdateBootFile;
	selection : Lib.Selection;
	filename : Files.FileName;
BEGIN
	IF GetSelection(context, FALSE, selection) THEN
		IF context.arg.GetString(filename) THEN
			NEW(updateBootFile, selection.disk, selection.partition, context.out);
			updateBootFile.SetParameters(filename);
			updateBootFile.SetBlockingStart;
		ELSE
			context.error.String("Expected parameters: dev#part bootfilename"); context.error.Ln;
			context.result := Commands.CommandParseError;
		END;
	END;
END UpdateBootFile;

PROCEDURE GetConfig*(context : Commands.Context);	(** dev#part  *)
CONST MaxSize = 2048;
VAR
	getConfig : Lib.GetConfig;
	selection : Lib.Selection;
	configuration : Lib.Configuration;
	table : Streams.StringWriter;
	string : ARRAY MaxSize OF CHAR;
	i : LONGINT;
BEGIN
	IF GetSelection(context, TRUE, selection) THEN
		NEW(getConfig, selection.disk, selection.partition, context.out);
		getConfig.SetBlockingStart;
		IF getConfig.state.status * Lib.StatusError = {} THEN
			NEW(configuration);
			configuration.table := getConfig.GetTable();
			table := configuration.GetTableAsString();
			table.Get(string);
			(* Commands uses the quote character to separate commands *)
			FOR i := 0 TO LEN(string)-1 DO IF string[i] = ";" THEN string[i] := ","; END; END;
			context.out.String("Partitions.SetConfig "); context.out.String(getConfig.diskpartString); context.out.Ln;
			context.out.String(string); context.out.Ln;
		END;
	END;
END GetConfig;

(* Write the specified configuration string to the specified partition.							*)
(* Notes:																					*)
(*	- Use the "," character to separate commands 											*)
(*	- After an "#" character, the rest of the line is skipped/ignored							*)
PROCEDURE SetConfig*(context : Commands.Context); (** dev#part { str = "val" } ~ *)
VAR
	setConfig : Lib.SetConfig;
	selection : Lib.Selection;
	configString : Strings.String;
	ch : CHAR;
	i : LONGINT;
BEGIN
	IF GetSelection(context, TRUE, selection) THEN
		IF context.arg.CanSetPos() THEN
			(* append character "~" to config string *)
			NEW(configString, context.arg.Available() + 1);
			i := 0;
			WHILE (context.arg.Available() > 0) DO
				context.arg.Char(ch);
				IF (ch = ",") THEN
					configString[i] := ";"; (* Commands uses comma character to separate commands *)
				ELSE
					configString[i] := ch;
				END;
				INC(i);
			END;
			configString[i-1] := "~";
			configString[i] := 0X;
			NEW(setConfig, selection.disk, selection.partition, context.out);
			setConfig.SetParameters(configString, 0);
			setConfig.SetBlockingStart;
		ELSE
			context.error.String("Expected argument stream that supports SetPos"); context.error.Ln;
			context.result := Commands.CommandError;
		END;
	END;
END SetConfig;

(** Perform a read check on partition *)
PROCEDURE Check*(context : Commands.Context); (** dev#part *)
VAR
 	selection : Lib.Selection;
 	checkPartition : Lib.CheckPartition;
BEGIN
	IF GetSelection(context, FALSE, selection) THEN
		NEW(checkPartition, selection.disk, selection.partition, context.out);
		checkPartition.SetBlockingStart;
	ELSE (* skip; error written to <w> by ScanOpenPart *)
	END;
END Check;

(** Change the type of dev#part from oldtype to newtype *)
PROCEDURE ChangeType*(context : Commands.Context); (** dev#part oldtype newtype ~ *)
VAR
	change : Lib.ChangePartType;
	oldtype, newtype : LONGINT;
	selection : Lib.Selection;
BEGIN
	IF GetSelection(context, TRUE, selection) THEN
		IF ~selection.disk.isDiskette THEN
			IF context.arg.GetInteger(oldtype, FALSE) & (oldtype > 0) & (oldtype < 256) THEN
				IF context.arg.GetInteger(newtype, FALSE) & (newtype > 0) & (newtype < 256) THEN
					NEW(change, selection.disk, selection.partition, context.out);
					change.SetParameters(oldtype, newtype);
					change.SetBlockingStart;
				ELSE
					context.error.String("Expected parameters: dev#part oldtype newtype, failed to parse newtype"); context.error.Ln;
					context.result := Commands.CommandParseError;
				END;
			ELSE
				context.error.String("Expected parameters: dev#part oldtype newtype, failed to parse oldtype"); context.error.Ln;
				context.result := Commands.CommandParseError;
			END;
		ELSE
			context.error.String("Operation not support for floppy disk drives."); context.error.Ln;
			context.result := Commands.CommandError;
		END;
	END;
END ChangeType;

(** Delete a partition *)
PROCEDURE Delete*(context : Commands.Context); (** dev#part type ~ *)
VAR
	delete : Lib.DeletePartition;
	selection : Lib.Selection;
	type : LONGINT;
BEGIN
	IF GetSelection(context, FALSE, selection) THEN
		IF ~selection.disk.isDiskette THEN
			IF context.arg.GetInteger(type, FALSE) & (type > 0) & (type < 256) THEN
				NEW(delete, selection.disk, selection.partition, context.out);
				delete.SetParameters(type);
				delete.SetBlockingStart;
			ELSE
				context.error.String("Expected parameters: dev#part type sizeMB, error while parsing type"); context.error.Ln;
				context.result := Commands.CommandParseError;
			END;
		ELSE
			context.error.String("Operation not supported for floppy disks"); context.error.Ln;
			context.result := Commands.CommandError;
		END;
	END;
END Delete;

PROCEDURE Create*(context : Commands.Context); (** dev#part type sizeMB ~ *)
VAR
	create : Lib.CreatePartition;
	selection : Lib.Selection;
	type, size : LONGINT;
BEGIN
	IF GetSelection(context, FALSE, selection) THEN
		IF ~selection.disk.isDiskette THEN
			IF context.arg.GetInteger(type, FALSE) & (type > 0) & (type < 256) THEN
				IF context.arg.GetInteger(size, FALSE) & (size > 0) THEN
					NEW(create, selection.disk, selection.partition, context.out);
					create.SetParameters(size, type, FALSE);
					create.SetBlockingStart;
				ELSE
					context.error.String("Expected parameters: dev#part type sizeMB, error while parsing size"); context.error.Ln;
					context.result := Commands.CommandParseError;
				END;
			ELSE
				context.error.String("Expected parameters: dev#part type sizeMB, error while parsing type"); context.error.Ln;
				context.result := Commands.CommandParseError;
			END;
		ELSE
			context.error.String("Operation not supported on floppy disks"); context.error.Ln;
			context.result := Commands.CommandError;
		END;
	END;
END Create;

(** Mark partition as active *)
PROCEDURE Activate*(context : Commands.Context); (** dev#part ~ *)
BEGIN
	ChangeActiveBit(TRUE, context);
END Activate;

(** Mark partition as inactive *)
PROCEDURE Deactivate*(context : Commands.Context); (** dev#part ~ *)
BEGIN
	ChangeActiveBit(FALSE, context);
END Deactivate;

PROCEDURE ChangeActiveBit(active : BOOLEAN; context : Commands.Context);
VAR
	setFlags : Lib.SetFlags;
	selection : Lib.Selection;
BEGIN
	IF GetSelection(context, TRUE, selection) THEN
		IF ~selection.disk.isDiskette THEN
			NEW(setFlags, selection.disk, selection.partition, context.out);
			setFlags.SetParameters(active);
			setFlags.SetBlockingStart;
		ELSE
			context.error.String("Operation not supported for floppy disks"); context.error.Ln;
			context.result := Commands.CommandError;
		END;
	END;
END ChangeActiveBit;

(** Write <numblock> sectors from a file to a partition, starting at block <block> *)
PROCEDURE FileToPartition*(context : Commands.Context); (** dev#part filename [block numblocks] ~ *)
VAR
	fileToPartition : Lib.FileToPartition;
	filename : ARRAY 128 OF CHAR;
	block, numblocks : LONGINT;
	selection : Lib.Selection;
BEGIN
	IF GetSelection(context, TRUE, selection) THEN
		IF context.arg.GetString(filename) THEN
			IF context.arg.GetInteger(block, FALSE) THEN
				IF ~context.arg.GetInteger(numblocks, FALSE) THEN
					context.error.String("Exspected parameters: dev#part filename [block numblocks], failed to parse numblocks"); context.error.Ln;
					context.result := Commands.CommandParseError;
					RETURN;
				END;
			ELSE (* optional parameters not specified *)
				block := -1; numblocks := -1;
			END;
			NEW(fileToPartition, selection.disk, selection.partition, context.out);
			fileToPartition.SetParameters(filename, block, numblocks);
			fileToPartition.SetBlockingStart;
		ELSE
			context.error.String("Exspected parameters: dev#part name [block numblocks], failed to parse filename"); context.error.Ln;
			context.result := Commands.CommandParseError;
		END;
	END;
END FileToPartition;

(** Write <numblock> sectors from a partition to a file, starting at block <block>.
	If the optional parameters are not specified, store whole partition into file *)
PROCEDURE PartitionToFile*(context : Commands.Context); (** dev#part filename [block numblocks] ~ *)
VAR
	partitionToFile : Lib.PartitionToFile;
	filename : ARRAY 128 OF CHAR;
	block, numblocks : LONGINT;
	selection : Lib.Selection;
BEGIN
	IF GetSelection(context, TRUE, selection) THEN
		IF context.arg.GetString(filename) THEN
			IF context.arg.GetInteger(block, FALSE) THEN
				IF ~context.arg.GetInteger(numblocks, FALSE) THEN
					context.error.String("Exspected parameters: dev#part filename [block numblocks], failed to parse numblocks"); context.error.Ln;
					context.result := Commands.CommandParseError;
					RETURN;
				END;
			ELSE (* optional parameters not specified *)
				block := -1; numblocks := -1;
			END;
			NEW(partitionToFile, selection.disk, selection.partition, context.out);
			partitionToFile.SetParameters(filename, block, numblocks);
			partitionToFile.SetBlockingStart;
			context.out.String("Partitions UID "); context.out.Int(partitionToFile.uid, 0); context.out.String(": Started PartitionToFile on ");
			context.out.String(partitionToFile.diskpartString); context.out.Ln;
		ELSE
			context.error.String("Exspected parameters: dev#part name [block numblocks], failed to parse filename"); context.error.Ln;
			context.result := Commands.CommandParseError;
		END;
	END;
END PartitionToFile;

(** Write the specified Master Boot Record (MBR) to the specified partition. The partition table will be preserved 	*)
(*	unless the optional parameter "DESTROY" is specified.														*)
(*	WARNING: Using the DESTROY parameter will render any disk content unusable.								*)
PROCEDURE WriteMBR*(context : Commands.Context); (** dev#0 filename ["DESTROY"] ~ *)
VAR
	writeMBR : Lib.WriteMBR;
	filename, destroy : ARRAY 128 OF CHAR;
	selection : Lib.Selection;
BEGIN
	IF GetSelection(context, FALSE, selection) THEN
		IF ~selection.disk.isDiskette THEN
			IF selection.partition = 0 THEN
				IF context.arg.GetString(filename) THEN
					NEW(writeMBR, selection.disk, selection.partition, context.out);
					IF context.arg.GetString(destroy) & (destroy = "DESTROY") THEN
						writeMBR.SetParameters(filename, FALSE, FALSE);
					ELSE
						writeMBR.SetParameters(filename, TRUE, FALSE);
					END;
					writeMBR.SetBlockingStart;
				ELSE
					context.error.String("Expected parameters: dev#0 filename, failed to parse filename"); context.error.Ln;
					context.result := Commands.CommandParseError;
				END;
			ELSE
				context.error.String("Expected parameters: dev#0 filename, partition is not 0"); context.error.Ln;
				context.result := Commands.CommandParseError;
			END;
		ELSE
			context.error.String("Operation not supported for floppy disks"); context.error.Ln;
			context.result := Commands.CommandError;
		END;
	END;
END WriteMBR;

(** Update the boot loader OBL in an existing AosFS partition, replacing it by the new BBL handling the Init string differently.
The BBL must imperatively have the same size, 4 blocks, as the OBL. The same BBL is applicable to all AosFS partitions. *)
PROCEDURE UpdateBootLoader*(context : Commands.Context); (** dev#part BootLoader ~ *)
VAR
	updateLoader : Lib.UpdateBootLoader;
	selection : Lib.Selection;
	filename : Files.FileName;
BEGIN
	IF GetSelection(context, FALSE, selection) THEN
		IF context.arg.GetString(filename) THEN
			NEW(updateLoader, selection.disk, selection.partition, context.out);
			updateLoader.SetParameters(filename);
			updateLoader.SetBlockingStart;
		ELSE
			context.error.String("Expected parameters: dev#part bootloader"); context.error.Ln;
			context.result := Commands.CommandError;
		END;
	END;
END UpdateBootLoader;

(** Install boot manager on the specified device *)
PROCEDURE InstallBootManager*(context : Commands.Context); (** dev#0 [BootManagerMBR [BootManagerTail]] ~ *)
VAR installBootManager : Lib.InstallBootManager; selection : Lib.Selection; mbrFile, tailFile : Files.FileName;
BEGIN
	IF GetSelection(context, FALSE, selection) THEN
		IF ~context.arg.GetString(mbrFile) THEN mbrFile := BootManagerMBRFile; END;
		IF ~context.arg.GetString(tailFile) THEN tailFile := BootManagerTailFile; END;
		NEW(installBootManager, selection.disk, selection.partition, context.out);
		installBootManager.SetParameters(mbrFile, tailFile);
		installBootManager.SetBlockingStart;
	END;
END InstallBootManager;

PROCEDURE ShowBlockCallback(text : Texts.Text);
VAR string : Strings.String;
BEGIN
	text.AcquireRead;
	NEW(string, text.GetLength()); TextUtilities.TextToStr(text, string^);
	text.ReleaseRead;
	KernelLog.String(string^); KernelLog.Ln;
END ShowBlockCallback;

PROCEDURE ShowBlocks*(context : Commands.Context); (** dev#part block [numblocks] ~ *)
VAR
	showBlocks : Lib.ShowBlocks;
	block, numblocks : LONGINT;
	selection : Lib.Selection;
BEGIN
	IF GetSelection(context, FALSE, selection) THEN
		IF context.arg.GetInteger(block, FALSE) THEN
			IF ~context.arg.GetInteger(numblocks, FALSE) THEN
				(* optional parameter not specified *) numblocks := -1;
			END;
			NEW(showBlocks, selection.disk, selection.partition, context.out);
			showBlocks.SetParameters(block, numblocks);
			showBlocks.SetCallback(ShowBlockCallback);
			showBlocks.SetBlockingStart;
		ELSE
			context.error.String("Exspected parameters: dev#part block [numblocks], failed to parse block"); context.error.Ln;
			context.result := Commands.CommandParseError;
		END;
	END;
END ShowBlocks;

(** Eject medium of device dev *)
PROCEDURE Eject*(context : Commands.Context); (** dev ~ *)
VAR
	plugin : Plugins.Plugin;
	dev : Disks.Device;
	name : ARRAY 32 OF CHAR;
	temp: ARRAY 256 OF CHAR;
BEGIN
	IF context.arg.GetString(name)  THEN
		plugin := Disks.registry.Get(name);
		IF plugin # NIL THEN
			dev := plugin (Disks.Device);
			Lib.Eject(dev, temp); context.out.String(temp); context.out.Ln;
		ELSE
			context.error.String("Device "); context.error.String(name); context.error.String(" not found"); context.error.Ln;
			context.result := Commands.CommandError;
		END;
	ELSE
		context.error.String("Expected parameters: dev"); context.error.Ln;
		context.result := Commands.CommandParseError;
	END;
END Eject;

(** Sync device to medium *)
PROCEDURE Sync*(context: Commands.Context); (** dev ~ *)
VAR
	plugin: Plugins.Plugin;
	dev: Disks.Device;
	name: ARRAY 32 OF CHAR;
	temp: ARRAY 256 OF CHAR;
BEGIN
	IF context.arg.GetString(name) THEN
		plugin := Disks.registry.Get(name);
		IF plugin # NIL THEN
			dev := plugin (Disks.Device);
			Lib.Sync(dev, temp); context.out.String(temp); context.out.Ln;
		ELSE
			context.error.String("Device "); context.error.String(name); context.error.String(" not found"); context.error.Ln;
			context.result := Commands.CommandError;
		END;
	ELSE
		context.error.String("Expected parameters: dev"); context.error.Ln;
		context.result := Commands.CommandParseError;
	END;
END Sync;

PROCEDURE Unsafe*(context : Commands.Context); (** ~ *)
BEGIN
	Lib.safe := FALSE;
	context.out.String("NOW in UNSAFE mode!"); context.out.Ln;
END Unsafe;

PROCEDURE Safe*(context : Commands.Context); (** ~ *)
BEGIN
	Lib.safe := TRUE;
	context.out.String("Now in safe mode"); context.out.Ln;
END Safe;

(** Show all disk devices and their partition layout. *)
PROCEDURE Show*(context : Commands.Context); (** ["detail"] ~ *)
VAR
	diskTable : Lib.Disks; disk : Lib.Disk;
	par : ARRAY 10 OF CHAR;
	verbose : BOOLEAN;
	i : LONGINT;
	temp : ARRAY 256 OF CHAR;
BEGIN
	par := ""; context.arg.SkipWhitespace; context.arg.String(par);
	verbose := (par = "detail");
	Lib.diskModel.Update;
	Lib.diskModel.Acquire;
	diskTable := Lib.diskModel.disks;
	IF diskTable # NIL THEN
		FOR i := 0 TO LEN(diskTable)-1 DO
			disk := diskTable[i];
			ShowDevice(context, disk, verbose);
			IF disk.res # Disks.MediaMissing THEN
				IF (disk.table # NIL) THEN
					ShowTable(context, disk, disk.table, verbose)
				ELSE
					Lib.GetErrorMsg("Error", disk.res, temp); context.error.String(temp); context.error.Ln;
				END
			END;
			context.error.Ln;
		END;
	ELSE
		context.error.String("No Devices found"); context.error.Ln;
		context.result := Commands.CommandError;
	END;
	Lib.diskModel.Release;
END Show;

PROCEDURE ShowDevice(context : Commands.Context; disk: Lib.Disk; verbose: BOOLEAN);
VAR temp: ARRAY 256 OF CHAR;
BEGIN
	context.out.String("Disk: "); context.out.String(disk.device.name); context.out.String(", ");
	IF disk.res = Disks.Ok THEN
		Lib.WriteK(context.out, ENTIER(disk.size * 1.0 * disk.device.blockSize / 1024));
		IF verbose THEN
			context.out.String(" = "); context.out.Int(disk.size, 1);
			context.out.String(" * "); context.out.Int(disk.device.blockSize,1);
		END
	ELSE
		Lib.GetErrorMsg("GetSize failed", disk.res, temp); context.error.String(temp);
	END;
	IF Disks.Removable IN disk.device.flags THEN context.out.String(", removable") END;
	IF Disks.ReadOnly IN disk.device.flags THEN context.out.String(", read-only") END;
	IF verbose THEN
		IF disk.res # Disks.MediaMissing THEN
			context.out.String(", ");
			IF disk.gres = Disks.Ok THEN
				context.out.String("CHS: "); context.out.Int(disk.geo.cyls, 1); context.out.String("*");
				context.out.Int(disk.geo.hds, 1); context.out. String("*"); context.out.Int(disk.geo.spt, 1);
			ELSE
				Lib.GetErrorMsg("GetCHS: ", disk.gres, temp); context.error.String(temp);
			END
		END
	END;
	IF disk.device.desc # "" THEN context.out.String(", "); context.out.String(disk.device.desc) END;
	IF verbose THEN	context.out.String(", mntcnt="); context.out.Int(disk.device.openCount, 1) END;
	context.out.Ln;
END ShowDevice;

PROCEDURE ShowTable( context : Commands.Context; disk: Lib.Disk; table: Disks.PartitionTable; verbose: BOOLEAN);
VAR j: LONGINT; r: LONGREAL; ugly : ARRAY 10 OF CHAR; temp : ARRAY 128 OF CHAR; ignore : LONGINT;
BEGIN
	FOR j := 0 TO LEN(table)-1 DO
		r := (table[j].size * 1.0D0 * disk.device.blockSize) / (1024*1024); (* M *)
		Lib.WritePart(context.out, disk.device, j);
		IF verbose THEN
			context.out.Int(table[j].start, 12);
			context.out.Int(table[j].size, 12)
		END;
		Strings.FloatToStr(r, 6, 1, 0, ugly);
		IF r < 10 THEN context.out.String(ugly);
		ELSE context.out.Int(ENTIER(r), 6)
		END;
		context.out.String(" MB ");
		IF (table[j].type >= 1) & (table[j].type <= 255) THEN
			context.out.Int(table[j].type, 3)
		ELSE
			context.out.String("---")
		END;
		context.out.Char(" ");
		IF (j # 0) & ~(Disks.Primary IN table[j].flags) THEN context.out.String( " | ") END; (* logical drive *)
		IF Disks.Boot IN table[j].flags THEN context.out.String(" * ") END; (* bootable *)
		Lib.WriteType(table[j].type, temp, ignore); context.out.String(temp);
		IF verbose THEN
			IF Disks.Mounted IN table[j].flags THEN context.out.String(" [mounted]") END
		END;
		context.out.Ln;
	END
END ShowTable;

(** Display limitations of AosFS *)
PROCEDURE ShowAosFSLimits*(context : Commands.Context); (** ~ *)
BEGIN
	Lib.ShowAosFSLimits;
END ShowAosFSLimits;

PROCEDURE UpdateDiskModel*(context : Commands.Context);(** ~ *)
BEGIN
	Lib.diskModel.Update;
	context.out.String("Disk model updated."); context.out.Ln;
END UpdateDiskModel;

(* Scan the command line parameters for a device#partition specification. *)
(* The Writer <w> is used to return error messages, <r> contains p.str (dev#part skipped) *)
(* check : IF TRUE, only Disks.Valid partitions are returns *)
PROCEDURE GetSelection*(context : Commands.Context; check : BOOLEAN;  VAR selection : Lib.Selection) : BOOLEAN;
VAR devpart : ARRAY 32 OF CHAR;
BEGIN
	selection.disk.device := NIL; selection.partition := -1; (* invalid *)
	IF ~context.arg.GetString(devpart) THEN
		context.error.String("Expected parameters: dev#part"); context.error.Ln; context.error.Update;
		context.result := Commands.CommandParseError;
		RETURN FALSE;
	END;
	context.arg.SkipWhitespace;

	(* special case: diskette *)
	IF Strings.Match("Diskette*", devpart) THEN
		check := FALSE;
	END;
	Lib.diskModel.Update;
	IF Lib.diskModel.GetDisk(devpart, selection, check) THEN
		IF Trace THEN
			KernelLog.String("Partitions: Command line selection: "); KernelLog.String(selection.disk.device.name);
			KernelLog.Char("#"); KernelLog.Int(selection.partition, 0); KernelLog.Ln;
		END;
		RETURN TRUE;
	ELSE
		context.error.String("Partition "); context.error.String(devpart); context.out.String(" not found."); context.error.Ln;
		context.error.Update; context.result := Commands.CommandError;
	END;
	RETURN FALSE;
END GetSelection;

END Partitions.

System.Free DiskBenchmark Partitions ~
