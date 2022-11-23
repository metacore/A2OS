MODULE PrettyPrint; (** AUTOR "GF"; PURPOSE "pretty printing of Oberon programs"; *)

(* ----------------------------------------------------------
	Usage:
		PrettyPrint.Convert --format=Oberon
			<filename>  <filename>  ...  ~


	The real printing on a postscript printer can be done in the Oberon subsystem:

		Desktops.PrintDoc  <printer name>	PPr/<filename> ~

  ----------------------------------------------------------- *)

IMPORT Commands, Files, Strings, Streams, Texts, TextUtilities, SyntaxHighlighter, Options;

CONST
	PPDir = "PPr";

VAR
	highlighterU, highlighterL: SyntaxHighlighter.Highlighter;
	out, err: Streams.Writer;

	PROCEDURE CheckSubDirectory( CONST dname: ARRAY OF CHAR ): BOOLEAN;
	VAR
		enum: Files.Enumerator;
		fname, cname: ARRAY 64 OF CHAR; time, date: SIGNED32; size: Files.Size; flags: SET;
	BEGIN
		cname := "./";  Strings.Append( cname, dname );
		NEW( enum );
		enum.Open( "./*", {} );
		WHILE enum.GetEntry( fname, flags, time, date, size ) DO
			IF fname = cname THEN  RETURN TRUE  END
		END;
		RETURN FALSE
	END CheckSubDirectory;


	(* convert program sources into syntax highlighted Oberon Texts in subdir 'PPr' *)

	PROCEDURE Convert*( context: Commands.Context );	(*  {filename} ~ *)
	VAR
		filename, dest: ARRAY 64 OF CHAR;  format, outFormat: TextUtilities.Format; l: SIZE; res: INTEGER;
		f: Files.File;  text: Texts.Text;
		highlighter: SyntaxHighlighter.Highlighter; options: Options.Options;
	BEGIN
		NEW(options);
		options.Add("f", "format", Options.String);
		IF options.Parse(context.arg, context.error) THEN
			out := context.out;  err := context.error;

			out.String( "PrettyPrint.Convert" ); out.Ln;
			IF ~CheckSubDirectory( PPDir ) THEN  Files.CreateDirectory( PPDir, res )  END;
			IF highlighterU = NIL THEN  LoadHighlighter  END;
			IF highlighterU # NIL THEN
				WHILE context.arg.GetString( filename ) DO
					out.String( "    " );  out.String( filename );
					l := Strings.Length( filename );
					IF filename[l-3] = 'm' THEN  highlighter := highlighterL  ELSE  highlighter := highlighterU END;
					f := Files.Old( filename );
					IF f = NIL THEN
						context.result := Commands.CommandError;
						err.String( " : file not found" ); err.Ln;
					ELSE
						NEW( text );
						TextUtilities.LoadTextAuto( text, filename, format, res );
						out.String( " (" ); out.String(format); out.String( ")" );
						IF ~options.GetString("format", outFormat) THEN outFormat := format END;
						SyntaxHighlighter.HighlightText( text, highlighter );
						dest := PPDir; Strings.Append( dest, "/" ); Strings.Append( dest, filename );
						
						TextUtilities.Store( text, dest, outFormat, res );
						out.String( " => " ); out.String( dest );
						out.String( " (" ); out.String(outFormat); out.String( ")" );
						out.Ln;
					END
				END
			ELSE
				context.result := Commands.CommandError;
				err.String( "Highlighter 'PrintOberon' not found" );  err.Ln
			END;
		ELSE
			context.result := Commands.CommandParseError;
			context.out.String('Usage: PrettyPrint.Convert [--format=<Codec>] <files>'); context.out.Ln; 	
		END;
		context.out.Update;  context.error.Update;
	END Convert;


	PROCEDURE LoadHighlighter;
	VAR res: INTEGER; msg: ARRAY 128 OF CHAR;
	BEGIN
		Commands.Call( "SyntaxHighlighter.Open PrettyPrintHighlighter.XML", {}, res, msg );
		highlighterU := SyntaxHighlighter.GetHighlighter( "PrintOberon" );
		highlighterL := SyntaxHighlighter.GetHighlighter( "printoberon" );
		Commands.Call( "SyntaxHighlighter.Open SyntaxHighlighter.XML", {}, res, msg );
	END LoadHighlighter;

BEGIN
	highlighterU := NIL;
	highlighterL := NIL
END PrettyPrint.


	System.Free PrettyPrint ~

	PrettyPrint.Convert  --format=Oberon  PrettyPrint.Mod ~



