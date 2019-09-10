MODULE SVNArgument; (** AUTHOR "rstoll"; PURPOSE "parse context and provide query methods"; *)

(*
	TODO
	 - strings/arrays dynamisch machen
*)

IMPORT
	Commands, Streams;

CONST
	ResOK* = 0;
	ResKEYNOTFOUND* = -1;
	ResEXPECTEDPARAMCOUNTFAILED* = -2;


	MaxArgumentValues = 32;

TYPE

	Argument *= OBJECT
	VAR
		next, error*, last, unkeyed : SIGNED16;
		msg* : ARRAY 256 OF CHAR;

		arguments : ARRAY 256 OF RECORD
			key : ARRAY 32 OF CHAR;
			value : ARRAY MaxArgumentValues,256 OF CHAR;
			expParams : SIGNED16;
			isset : BOOLEAN;
		END;

		arguments2 : ARRAY MaxArgumentValues, 256 OF CHAR; (* dynamisch machen *)


		PROCEDURE &Init*;
		BEGIN
			next := 0;
			error := ResOK;
		END Init;


		PROCEDURE Push* ( CONST key : ARRAY OF CHAR; expParams : SIGNED16 );
		BEGIN
			ASSERT ( next < MaxArgumentValues );

			COPY ( key, arguments[next].key );
			arguments[next].expParams := expParams;
			arguments[next].isset := FALSE;

			INC ( next );
		END Push;


		PROCEDURE GetKeyedArgument* ( CONST key : ARRAY OF CHAR; VAR value : ARRAY OF CHAR; index : SIGNED16 );
		BEGIN
			IF IsSet ( key ) & (index < next) THEN
				COPY ( arguments[last].value[index], value );
			END;
		END GetKeyedArgument;


		PROCEDURE GetUnkeyedArgument* ( VAR value : ARRAY OF CHAR; index : SIGNED16 );
		BEGIN
			IF index < unkeyed THEN (* muss man array bounds testen? :) *)
				COPY ( arguments2[index], value );
			END;
		END GetUnkeyedArgument;


		PROCEDURE CountUnkeyedArguments* (): SIGNED16;
		BEGIN
			RETURN unkeyed;
		END CountUnkeyedArguments;


		PROCEDURE IsSet* ( CONST key : ARRAY OF CHAR ) : BOOLEAN;
		VAR
			idx : SIGNED16;
			found : BOOLEAN;

		BEGIN
			FindKey ( key, idx, found );

			IF ~found THEN RETURN FALSE END;
			last := idx;

			RETURN arguments[idx].isset;
		END IsSet;


		PROCEDURE Read* ( context : Commands.Context );
		VAR
			ch : CHAR;
			arg : Streams.Reader;
			s : ARRAY 256 OF CHAR;
			a, j : SIGNED16;
			found : BOOLEAN;

		BEGIN
			unkeyed := 0;
			arg := context.arg;

			WHILE( arg.res = 0 ) DO
				arg.SkipWhitespace();

				IF arg.Peek() = '\' THEN
					arg.Char( ch );
					arg.String ( s );

					FindKey ( s, a, found );

					IF ~found THEN
						COPY ( s, msg );
						error := ResKEYNOTFOUND;
						RETURN;
					END;

					arguments[a].isset := TRUE;

					j := 0;
					WHILE( (arg.res = 0) & (j < arguments[a].expParams) ) DO
						ASSERT ( j < MaxArgumentValues );

						arg.SkipWhitespace();
						arg.String ( arguments[a].value[j] );

						INC ( j );
					END;

					IF j # arguments[a].expParams THEN
						COPY ( s, msg );
						error := ResEXPECTEDPARAMCOUNTFAILED;
						RETURN;
					END;
				ELSE
					ASSERT ( unkeyed < MaxArgumentValues );

					arg.String ( arguments2[unkeyed] );

					IF arguments2[unkeyed] # "" THEN
						INC ( unkeyed );
					END;
				END;
			END;
		END Read;


		PROCEDURE FindKey ( CONST s : ARRAY OF CHAR; VAR index : SIGNED16; VAR found : BOOLEAN );
		BEGIN
			found := FALSE;
			index := 0;

			WHILE( (index < next) & ~found ) DO
				IF arguments[index].key = s THEN
					found := TRUE;
				ELSE
					INC ( index );
				END;
			END;

			ASSERT ( (index = next) OR found);
		END FindKey;


	BEGIN
	END Argument;

END SVNArgument.


System.Free Argument ~
PC.Compile \s \W SVNArgument.Mod ~