MODULE SVNOutput; (** AUTHOR "rstoll"; *)

IMPORT
	Commands;

CONST
	ResOK* = 0;
	ResNOTVERSIONED* = -1;
	ResCLIENTOLD* = -2;
	ResFILENOTFOUND* = -3;
	ResALREADYVERSIONED* = -4;
	ResUPDATEFILEALREADYEXISTS* = -5;
	ResCHECKSUMMISMATCH* = -6;
	ResCOMMITNOMESSAGE* = -7;
	ResUNEXPECTEDSERVERRESPONSE* = -8;
	ResCOMMITOUTOFDATE* = -9;
	ResCOMMITUNSPECIFIED* = -10;
	ResNOTAUTHORIZED* = -11;
	ResADDDIRECTORYEXISTS* = -12;
	ResCHECKOUTALREADYDONE* = -13;

	UsageInfo* = 1;
	UsageCheckout* = 2;
	UsageCommit* = 3;
	UsageAdd* = 4;
	UsageDelete* = 5;
	UsageUpdate* = 6;


	DateFormat* = "yyyy-mm-ddThh:nn:ss.000000Z";


TYPE
	Message* = OBJECT
	VAR
		context : Commands.Context;

		PROCEDURE &Init* ( c : Commands.Context );
		BEGIN
			context := c;
		END Init;

		PROCEDURE Print* ( num : INTEGER; CONST msg : ARRAY OF CHAR );
		BEGIN
			IF num = ResOK THEN
				RETURN;
			END;

			IF num < 0 THEN
				context.out.String ( "svn: " );
			END;

			CASE num OF
				ResNOTVERSIONED :
					context.out.String ( "'" );
					context.out.String ( msg );
					context.out.String ( "'" );
					context.out.String ( " is not a working copy" );
				| ResCLIENTOLD :
					context.out.String ( "This client is too old to work with working copy '" );
					context.out.String ( msg );
					context.out.String ( "'.  You need to get a newer Subversion client, or downgrade this working copy." );
				| ResFILENOTFOUND :
					context.out.String ( "warning: '" );
					context.out.String ( msg );
					context.out.String ( "' not found" );
				| ResALREADYVERSIONED :
					context.out.String ( "warning: '" );
					context.out.String ( msg );
					context.out.String ( "' is already under version control" );
				| ResUPDATEFILEALREADYEXISTS :
					context.out.String ( "error: failed to add '" );
					context.out.String ( msg );
					context.out.String ( "': object of the same name already exists" );
				| ResCHECKSUMMISMATCH :
					context.out.String ( "Checksum mismatch for '" );
					context.out.String ( msg );
					context.out.String ( "'" );
				| ResCOMMITNOMESSAGE :
					context.out.String ( "error: no commit message specified" );
				| ResUNEXPECTEDSERVERRESPONSE :
					context.out.String ( "Server sent unexpected return value" );
				| ResCOMMITOUTOFDATE :
					context.out.String ( "Commit failed (details follow):" ); context.out.Ln;
					context.out.String ( "svn: File or directory '" );
					context.out.String ( msg );
					context.out.String ( "' is out of date; try updating" );
				| ResCOMMITUNSPECIFIED :
					context.out.String ( "Commit failed:" ); context.out.Ln;
					context.out.String ( "svn: Unknown Reason '" );
					context.out.String ( msg );
					context.out.String ( "'" );
				| ResNOTAUTHORIZED :
					context.out.String ( "not authorized. Please specify some credentials." );
				| ResADDDIRECTORYEXISTS :
					context.out.String ( "Failed to add directory '" );
					context.out.String ( msg );
					context.out.String ( "': an unversioned directory of the same name already exists" );
				| ResCHECKOUTALREADYDONE :
					context.out.String ( "Can't do a checkout into this directory: " );
					context.out.String ( msg );
					context.out.Ln;
					context.out.String ( "svn: Already checked out." );


				| UsageInfo :
					context.out.String ( "info: Displays information about a local item." ); context.out.Ln;
					context.out.String ( "usage: info [TARGET] ~" );
				| UsageUpdate :
					context.out.String ( "update: Bring changes from the repository into the working copy." ); context.out.Ln;
					context.out.String ( "usage: update [PATH] ~" ); context.out.Ln;
				| UsageCommit :
					context.out.String ( "commit: Send changes from your working copy to the repository." ); context.out.Ln;
					context.out.String ( "usage: commit [PATH] [OPTION] ~" ); context.out.Ln; context.out.Ln;
					context.out.String ( "options: \m ''Commit Message''" ); context.out.Ln;
				| UsageAdd :
					context.out.String ( "add: Put files and directories under version control, scheduling them for addition to repository.  They will be added in the next commit." ); context.out.Ln;
					context.out.String ( "usage: add PATH... ~" ); context.out.Ln;
				| UsageDelete :
					context.out.String ( "delete: Remove files and directories from version control. Each item specified by a PATH is scheduled for deletion upon the next commit." ); context.out.Ln;
					context.out.String ( "usage: delete PATH... ~" ); context.out.Ln;
				| UsageCheckout :
					context.out.String ( "checkout: Check out a working copy from a repository." ); context.out.Ln;
					context.out.String ( "usage: checkout URL [PATH]" ); context.out.Ln;
			END;
			context.out.Ln; context.out.Update;
		END Print;
	END Message;


END SVNOutput.