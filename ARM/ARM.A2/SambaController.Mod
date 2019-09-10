MODULE SambaController; (** AUTHOR "Timothee Martiel, 2014/11"; PURPOSE "Initialize the sambaFS on ARM"; *)

IMPORT Commands, Files, SambaClient, Strings;

	PROCEDURE NewSambaFS * (context: Commands.Context);
	VAR
		params: Files.Parameters;
	BEGIN
		NEW(params, context.in, context.arg, context.out, context.error, context.caller);
		params.prefix := "SMB";
		SambaClient.NewFS(params);
	END NewSambaFS;

	PROCEDURE LoadCycle * (context: Commands.Context);
	VAR
		msg: ARRAY 128 OF CHAR;
		res: SIGNED32;
	BEGIN
		Commands.Activate('SystemTools.Load', context, {Commands.Wait}, res, msg);
		IF res # Commands.Ok THEN
			context.error.String("Error while loading: ");
			context.error.String(msg);
			context.error.Ln;
			context.error.Update;
			RETURN
		END;

		context.arg.SetPos(0);
		Commands.Activate('SystemTools.Free', context, {Commands.Wait}, res, msg);
		IF res # Commands.Ok THEN
			context.error.String("Error while loading: ");
			context.error.String(msg);
			context.error.Ln;
			context.error.Update;
			RETURN
		END
	END LoadCycle;
END SambaController.
