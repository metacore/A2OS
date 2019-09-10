MODULE CryptoHashes;	(** AUTHOR "G.F."; PURPOSE "Empty Hash"; *)

TYPE
	Hash* = OBJECT
		VAR
			name-: ARRAY 64 OF CHAR;
			size-: SIGNED32;
			initialized*: BOOLEAN;

		PROCEDURE &Init*;
		BEGIN
			initialized := FALSE
		END Init;

		PROCEDURE Initialize*;
		BEGIN
			HALT(301) (* force overwriting *)
		END Initialize;

		(** this method is invoked by subclasses *)
		PROCEDURE SetNameAndSize*( CONST name: ARRAY OF CHAR; size: SIGNED32 );
		BEGIN
			COPY( name, SELF.name );
			SELF.size := size
		END SetNameAndSize;

		(** data: value to be hashed; when Update is invoked several times before GetHash or Initialize
			is invoked, the concatenation of all data-parameters is hashed *)
		PROCEDURE Update*( CONST data: ARRAY OF CHAR; ofs, len: SIZE );
		BEGIN
			HALT(301) (* force overwriting *)
		END Update;

		(** get the hashvalue of length SELF.size *)
		PROCEDURE GetHash*( VAR buffer: ARRAY OF CHAR; position: SIZE );
		BEGIN
			HALT(301) (* force overwriting *)
		END GetHash;

	END Hash;

	HashFactory = PROCEDURE( ): Hash;

	(** get a new hash from module 'modname' *)
	PROCEDURE NewHash*( CONST modname: ARRAY OF CHAR ): Hash;
	VAR hash : Hash; factory : HashFactory;
	BEGIN
		ASSERT( LEN( modname ) < 57 );
		hash := NIL;
		GETPROCEDURE( modname, "NewHash", factory );
		IF factory # NIL THEN
			hash := factory();
		END;
		RETURN hash;
	END NewHash;

END CryptoHashes.


System.Free CryptoHashes~
