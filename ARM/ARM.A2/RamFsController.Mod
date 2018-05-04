MODULE RamFsController; (** AUTHOR "Timothée Martiel, 2014/11"; PURPOSE "Instanciate a RAM FS on Zynq"; *)

IMPORT Commands, Files, RAMVolumes, DiskFS;

	(** Mounts the previously created RAMFS. *)
	PROCEDURE NewDiskFS * (context : Commands.Context);
	VAR
		params: Files.Parameters;
	BEGIN
		NEW(params, context.in, context.arg, context.out, context.error, context.caller);
		params.vol := volume;
		params.prefix := prefix;
		DiskFS.NewFS(params);
		volume := params.vol;
		prefix := params.prefix
	END NewDiskFS;

	(** Creates a RAM volume with a native AOS filesystem on it. *)
	PROCEDURE NewRamVolume * (context : Commands.Context);
	VAR
		params: Files.Parameters;
	BEGIN
		NEW(params, context.in, context.arg, context.out, context.error, context.caller);
		params.vol := volume;
		params.prefix := prefix;
		RAMVolumes.New(params);
		volume := params.vol;
		prefix := params.prefix
	END NewRamVolume;

VAR
	volume: Files.Volume;
	prefix: Files.Prefix;

BEGIN
	prefix := "RAM";
END RamFsController.
