MODULE SVN; (** AUTHOR "rstoll"; *)

IMPORT
	Files, Commands, SVNArgument, WebHTTP, Strings, Modules, KernelLog,
	OdSvn,
	SVNAdmin, SVNOutput, SVNUtil, SVNWebDAV;


TYPE

	Subversion = OBJECT
	VAR
		f : Files.File;
		svn : OdSvn.OdSvn;

		PROCEDURE &Init;
		BEGIN
			NEW ( svn );
			svn.UseSvn ( TRUE );
			svn.client.SvnSetBasicAuth ( "test:test" );
		END Init;

		PROCEDURE SetPassword ( args : SVNArgument.Argument; context : Commands.Context );
		VAR
			str, tmp : ARRAY 256 OF CHAR;
		BEGIN
			args.Push ( "username", 1 );
			args.Push ( "password", 1 );
			args.Read ( context );

			IF args.IsSet ( "username" ) OR args.IsSet ( "password" ) THEN
				args.GetKeyedArgument ( "username", str, 0 );
				args.GetKeyedArgument ( "password", tmp, 0 );

				Strings.Append ( str, ":" );
				Strings.Append ( str, tmp );

				svn.client.SvnSetBasicAuth ( str );
			END;
		END SetPassword;

		PROCEDURE Info (context: Commands.Context);
		VAR
			i : INTEGER;
			res : WORD;
			s : ARRAY 256 OF CHAR;
			args : SVNArgument.Argument;
			b : BOOLEAN;
			adminEntry : SVNAdmin.Entry;
			m : SVNOutput.Message;
		BEGIN { EXCLUSIVE }
			NEW ( adminEntry, context );
			NEW ( args );
			NEW ( m, context );

			SetPassword ( args, context );
			svn.context := context;

			b := TRUE;

			FOR i := 0 TO args.CountUnkeyedArguments()-1 DO
				IF ~b THEN context.out.Ln END;
				b := FALSE;
				args.GetUnkeyedArgument ( s, i );
				adminEntry.SetPath ( s, res );
				IF res = SVNOutput.ResOK THEN
					adminEntry.ReadData ( res );
					IF res = SVNOutput.ResOK THEN
						adminEntry.PrintData;
					END;
				END;
				m.Print ( res, s );
			END;

			IF b THEN
				adminEntry.SetPath ( ".", res );
				IF res = SVNOutput.ResOK THEN
					adminEntry.ReadData ( res );
					IF res = SVNOutput.ResOK THEN
						adminEntry.PrintData;
					END;
				END;
				m.Print ( res, s );
			END;
		END Info;

		PROCEDURE Update (context: Commands.Context);
		VAR
			s, tmp, tmp2, svndir : ARRAY 256 OF CHAR;
			b : BOOLEAN;
			i : INTEGER;
			args : SVNArgument.Argument;
			adminEntry : SVNAdmin.Entry;
			m : SVNOutput.Message;
			res : WORD;
		BEGIN { EXCLUSIVE }
			NEW ( adminEntry, context );
			NEW ( args );
			NEW ( m, context );

			SetPassword ( args, context );
			svn.context := context;

			b := TRUE;

			(* iterate throught every parameter *)
			FOR i := 0 TO args.CountUnkeyedArguments()-1 DO
				IF ~b THEN
					context.out.Ln;
				ELSE
					b := FALSE;
				END;

				args.GetUnkeyedArgument ( s, i );

				SVNUtil.RemoveFileDelimiterAtEnd ( s );

				adminEntry.SetPath ( s, res );

				IF res # SVNOutput.ResOK THEN
					m.Print ( res, s );
				ELSE
					adminEntry.ReadData ( res );
					IF res # SVNOutput.ResOK THEN
						m.Print ( res, s );
					ELSE
						adminEntry.GetRepo( tmp );
						adminEntry.GetUrl ( tmp2 );
						WebHTTP.GetPath ( tmp2, svndir );

						svn.client.SvnSetRepos ( tmp );

						SVNWebDAV.Update ( svn, svndir, adminEntry.GetVersion(), s, res );
						m.Print ( res, s );

						IF res = SVNOutput.ResOK THEN
							IF svn.svnUpdated THEN
								context.out.String ( "Updated to revision " );
								context.out.String ( svn.nextVersion );
							ELSE
								context.out.String ( "At revision " );
								context.out.Int ( adminEntry.GetVersion(), 0 );
							END;
							context.out.String ( "." ); context.out.Ln;
						END;
					END;
				END;
			END;

			IF b THEN
				m.Print ( SVNOutput.UsageUpdate, "" );
			END;

			svn.client.CloseConnection;
		END Update;

		PROCEDURE Commit (context: Commands.Context);
		VAR
			adminEntry : SVNAdmin.Entry;
			args : SVNArgument.Argument;
			m : SVNOutput.Message;
			i : INTEGER;
			s, tmp, tmp2, svndir : ARRAY 256 OF CHAR;
			b : BOOLEAN;
			res : WORD;
		BEGIN { EXCLUSIVE }
			NEW ( adminEntry, context );
			NEW ( args );
			NEW ( m, context );

			args.Push ( "m", 1 ); (* commit message as argument *)
			SetPassword ( args, context );
			svn.context := context;

			IF ~args.IsSet ( "m" ) THEN
				m.Print ( SVNOutput.ResCOMMITNOMESSAGE, "" ); KernelLog.Ln;
				m.Print ( SVNOutput.UsageCommit, "" );
				RETURN;
			END;

			(* iterate throught every parameter *)
			FOR i := 0 TO args.CountUnkeyedArguments()-1 DO
				IF ~b THEN
					context.out.Ln;
				ELSE
					b := FALSE;
				END;

				args.GetUnkeyedArgument ( s, i );

				SVNUtil.RemoveFileDelimiterAtEnd ( s );

				adminEntry.SetPath ( s, res );

				IF res # SVNOutput.ResOK THEN
					m.Print ( res, s );
				ELSE
					adminEntry.ReadData ( res );
					IF res # SVNOutput.ResOK THEN
						m.Print ( res, s );
					ELSE
						adminEntry.GetRepo( tmp );
						adminEntry.GetUrl ( tmp2 );
						WebHTTP.GetPath ( tmp2, svndir );

						svn.client.SvnSetRepos ( tmp );
						svn.context := context;

						args.GetKeyedArgument ( "m", tmp, 0 ); (* get commit message *)

						SVNWebDAV.Commit ( svn, svndir, s, tmp, res );

						m.Print ( res, s );
					END;
				END;
			END;

			context.out.String ( "done." ); context.out.Ln;

			IF b THEN
				m.Print ( SVNOutput.UsageCommit, "" );
			END;

			svn.client.CloseConnection;
		END Commit;

		PROCEDURE Add (context: Commands.Context);
		VAR
			s : ARRAY 256 OF CHAR;
			b : BOOLEAN;
			i : INTEGER;
			res : WORD;
			cnt, j : LONGINT;
			args : SVNArgument.Argument;
			adminEntry : SVNAdmin.Entry;
			m : SVNOutput.Message;
			tmp : Strings.StringArray;
			entriesfile, path, name, repoDir : Strings.String;
			searcher : SVNUtil.FSItemSearch;
			fAdmin : Files.File;
			w : Files.Writer;
		BEGIN { EXCLUSIVE }
			NEW ( adminEntry, context );
			NEW ( args );
			NEW ( m, context );
			NEW ( entriesfile, 512 );
			NEW ( path, 512 );
			NEW ( name, 512 );
			NEW ( repoDir, 512 );
			NEW ( searcher );

			SetPassword ( args, context );
			svn.context := context;

			b := TRUE;

			(* iterate throught every parameter *)
			FOR i := 0 TO args.CountUnkeyedArguments()-1 DO
				IF ~b THEN
					context.out.Ln;
				ELSE
					b := FALSE;
				END;

				args.GetUnkeyedArgument ( s, i );

				SVNUtil.RemoveFileDelimiterAtEnd ( s );

				searcher.Open ( s, {} );

				IF ~searcher.Exists () THEN
					m.Print ( SVNOutput.ResFILENOTFOUND, s );
				ELSE
					COPY(s, path^);

					tmp := Strings.Split ( path^, Files.PathDelimiter );
					cnt := LEN ( tmp );

					(* search for the first directory which is in the repository; beginning from the right *)
					f := NIL;
					WHILE (path^ # "") & (f = NIL) DO
						Files.SplitPath ( path^, path^, name^ );
						Files.JoinPath ( path^, ".svn/entries", entriesfile^ );
						f := Files.Old ( entriesfile^ );
						DEC ( cnt );
					END;

					ASSERT ( cnt >= 0 );

					IF f # NIL THEN

						adminEntry.SetPath ( path^, res );
						IF (cnt > LEN(tmp)-2) & (adminEntry.IsItemVersioned ( name^ )) THEN
							m.Print ( SVNOutput.ResALREADYVERSIONED, s );
						ELSE
							repoDir^ := "";

							SVNAdmin.RemoveFileAttribute ( entriesfile^ );
							fAdmin := Files.Old ( entriesfile^ );
							SVNAdmin.RemoveFileAttribute2 ( entriesfile^, fAdmin );

							adminEntry.ReadData ( res );

							ASSERT ( res = SVNOutput.ResOK );

							SVNAdmin.RemoveFileAttribute ( entriesfile^ );
							fAdmin := Files.Old ( entriesfile^ ); (* needed? *)
							SVNAdmin.RemoveFileAttribute2 ( entriesfile^, fAdmin );
							Files.OpenWriter ( w, fAdmin, fAdmin.Length() );

							(* create dummy entries up to the next to last one *)
							FOR j := cnt TO LEN(tmp)-2 DO
								SVNAdmin.WriteAddEntry ( w, tmp[j]^, FALSE );
								w.Update;

								Files.JoinPath ( path^, tmp[j]^, path^ );
								Files.JoinPath ( path^, ".svn/entries", entriesfile^ );

								IF j = cnt THEN
									Strings.AppendX ( repoDir^, tmp[j]^ );
								ELSE
									Files.JoinPath ( repoDir^, tmp[j]^, repoDir^ );
								END;

								w := adminEntry.CreateDummy ( path^, repoDir^ );
							END;

							(* either add a file or recursively add everything inside the directory *)
							KernelLog.String ( " A " ); KernelLog.String ( path^ ); KernelLog.String ( Files.PathDelimiter );
							KernelLog.String ( tmp[j]^ ); KernelLog.Ln;

							IF searcher.FileExists () THEN
								SVNAdmin.WriteAddEntry ( w, tmp[j]^, TRUE );
								w.Update;
							ELSE
								w.Update;
								adminEntry.Add ( path^, tmp[j]^, TRUE, res );
								m.Print ( res, s );
							END;

							SVNAdmin.SetFileAttribute2 ( entriesfile^, fAdmin );
						END;
					ELSE
						Files.SplitPath ( s, path^, name^ );
						m.Print ( SVNOutput.ResNOTVERSIONED, path^ );
					END;
				END;
			END;

			IF b THEN
				m.Print ( SVNOutput.UsageAdd, "" );
			END;

			svn.client.CloseConnection;
		END Add;

		PROCEDURE Delete (context: Commands.Context);
		BEGIN { EXCLUSIVE }
		END Delete;


		PROCEDURE Checkout (context: Commands.Context);
		VAR
			args : SVNArgument.Argument;
			m : SVNOutput.Message;
			tmp, svndir, tmp2 : ARRAY 256 OF CHAR;
			res : WORD;
			adminEntry : SVNAdmin.Entry;
			searcher : SVNUtil.FSItemSearch;
		BEGIN { EXCLUSIVE }
			NEW ( adminEntry, context );
			NEW ( args );
			NEW ( m, context );

			SetPassword ( args, context );
			svn.context := context;

			IF args.CountUnkeyedArguments() # 2 THEN
				m.Print ( SVNOutput.UsageCheckout, "" );
				RETURN;
			END;

			args.GetUnkeyedArgument ( tmp, 0 ); (* URL *)
			svn.client.SvnSetRepos ( tmp );
			COPY ( tmp, svn.repositoryURL );

			WebHTTP.GetPath ( tmp, svndir );

			args.GetUnkeyedArgument ( tmp, 1 ); (* directory *)
			SVNUtil.RemoveFileDelimiterAtEnd ( tmp );

			Files.CreateDirectory ( tmp, res );
			ASSERT ( (res = 0) OR (res=1) );

			IF res = 1 THEN
				adminEntry.SetPath ( tmp, res );

				IF res = SVNOutput.ResOK THEN
					m.Print ( SVNOutput.ResCHECKOUTALREADYDONE, tmp );
					RETURN;
				ELSE
					Files.JoinPath ( tmp, ".svn", tmp2 );
					NEW ( searcher );
					searcher.Open ( tmp2, {Files.Directory} );
					IF searcher.Exists () THEN
						m.Print ( SVNOutput.ResCHECKOUTALREADYDONE, tmp );
						RETURN;
					END;
				END;
			END;

			SVNAdmin.CreateDirectory ( tmp );

			SVNWebDAV.Checkout ( svn, svndir, tmp, res );
			m.Print ( res, tmp );

			IF res = SVNOutput.ResOK THEN
				context.out.String ( "Checked out revision " );
				context.out.String ( svn.nextVersion );
				context.out.String ( "." );
				context.out.Ln;
			END;

			svn.client.CloseConnection;
		END Checkout;


		PROCEDURE Close ;
		BEGIN
		END Close;

	END Subversion;




VAR

	svn : Subversion;


	PROCEDURE Cleanup;
	BEGIN {EXCLUSIVE}
		IF svn # NIL THEN
			svn.Close;
			svn := NIL;
		END;

		ASSERT ( svn = NIL );
	END Cleanup;

	PROCEDURE CreateSubversion;
	BEGIN { EXCLUSIVE }
		IF svn = NIL THEN
			NEW ( svn );
		END;

		ASSERT ( svn # NIL );
	END CreateSubversion;


	PROCEDURE info* ( c : Commands.Context );
	BEGIN
		CreateSubversion();
		svn.Info ( c );
	END info;

	PROCEDURE update* ( c : Commands.Context );
	BEGIN
		CreateSubversion ();
		svn.Update ( c );
	END update;

	PROCEDURE commit* ( c : Commands.Context );
	BEGIN
		CreateSubversion ();
		svn.Commit ( c );
	END commit;

	PROCEDURE add* ( c : Commands.Context );
	BEGIN
		CreateSubversion ();
		svn.Add ( c );
	END add;

	PROCEDURE delete* ( c : Commands.Context );
	BEGIN
		CreateSubversion ();
		svn.Delete ( c );
	END delete;

	PROCEDURE checkout* ( c : Commands.Context );
	BEGIN
		CreateSubversion ();
		svn.Checkout ( c );
	END checkout;


	PROCEDURE close*;
	BEGIN
		Cleanup;
	END close;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END SVN.