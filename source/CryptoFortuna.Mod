(**
	AUTHOR: Alexey Morozov
	PURPOSE: Building blocks for Fortuna cryptographic pseudorandom generator
					by Niels Ferguson, Bruce Schneier, Tadayoshi Kohno ( https://www.schneier.com/wp-content/uploads/2015/12/fortuna.pdf ).
					PyCrypto 2.6.1 ( https://www.dlitz.net/software/pycrypto ) was used as a reference for testing the code.
*)
MODULE CryptoFortuna;

IMPORT
	CryptoHashes, CryptoCiphers;

CONST
	HashSize* = 32; (** Fortuna reseed hash size in bytes *)
	CipherBlockSize* = 16; (* Fortuna cipher-based generator block size in bytes *)
	CipherKeySize* = 32; (* Fortuna generator cipher key size in bytes *)
	CounterSize* = CipherBlockSize; (** Fortuna counter size in bytes *)
	MaxRandomEventDataLen* = 32; (** maximal amount of random event data in bytes to feed the Fortuna accumulator *)
	NumPools* = 32; (** number of Fortuna accumulator pools *)
 	MinPoolSize* = 64;  (** minimal size in bytes of the 0-th pool data to be collected before a reseed *)

	ReseedIntervalMs = 100; (* reseed time interval in milliseconds *)
TYPE

	Crc32* = RECORD
		poly- := 0: UNSIGNED32;
		xorMsk- := 0xFFFFFFFF: UNSIGNED32;
		table-: ARRAY 256 OF SET32;

		crc- := 0xFFFFFFFF: UNSIGNED32; (** CRC32 value without applying the XOR mask *)

		(** Set the algorithm to its initial state

			initialValue : algorithm initial value (default 0xFFFFFFFF)
			polynomial : the used polynomial in reverse bit order (default 0xEDB88320 that corresponds to the standard CRC32 polynomial 0x04C11DB7)
			xorMask : XOR mask used for computing the checksum result (default 0xFFFFFFFF)
		*)
		PROCEDURE Init*(polynomial := 0xEDB88320: UNSIGNED32; initialValue := 0xFFFFFFFF: UNSIGNED32; xorMask := 0xFFFFFFFF: UNSIGNED32);
		BEGIN
			IF poly # polynomial THEN
				poly := polynomial;

				(* initialize the table *)
				VAR k, m: INTEGER;
				FOR k := 0 TO 256-1 DO
					VAR v := k: UNSIGNED32;
					FOR m := 0 TO 8-1 DO
						IF SET32(v) * {0} # {} THEN
							v := UNSIGNED32(SET32(poly) / SET32(LSH(v, -1)));
						ELSE
							v := LSH(v, -1);
						END;
					END;
					table[k] := SET32(v);
				END;
			END;

			crc := initialValue;
			xorMsk := xorMask;
		END Init;

		(* Get the checksum value with application of the used XOR mask *)
		PROCEDURE Get*(): UNSIGNED32;
		BEGIN
			RETURN UNSIGNED32(SET32(crc) / SET32(xorMsk));
		END Get;
	END;

	(*! exporting this inline operator causes compiler crash when compiling a module that uses the operator *)
	OPERATOR -(VAR crc: Crc32) "()" (data: SIGNED8);
	BEGIN
		crc.crc := UNSIGNED32(crc.table[UNSIGNED8(SET32(crc.crc) / SET32(data))] / SET32(LSH(crc.crc,-8)));
	END "()";

	OPERATOR (VAR crc: Crc32) "()"* (data: CHAR);
	BEGIN
		crc.crc := UNSIGNED32(crc.table[UNSIGNED8(SET32(crc.crc) / SET32(ORD(data)))] / SET32(LSH(crc.crc,-8)));
	END "()";

	OPERATOR (VAR crc: Crc32) "()"* (data: SIGNED16);
	BEGIN
		crc(SIGNED8(data));
		crc(SIGNED8(LSH(data,-8)));
	END "()";

	OPERATOR (VAR crc: Crc32) "()"* (data: SIGNED32);
	BEGIN
		crc(SIGNED8(data));
		crc(SIGNED8(LSH(data,-8)));
		crc(SIGNED8(LSH(data,-16)));
		crc(SIGNED8(LSH(data,-24)));
	END "()";

	OPERATOR (VAR crc: Crc32) "()"* (data: SIGNED64);
	BEGIN
		crc(SIGNED8(data));
		crc(SIGNED8(LSH(data,-8)));
		crc(SIGNED8(LSH(data,-16)));
		crc(SIGNED8(LSH(data,-24)));
		crc(SIGNED8(LSH(data,-32)));
		crc(SIGNED8(LSH(data,-40)));
		crc(SIGNED8(LSH(data,-48)));
		crc(SIGNED8(LSH(data,-56)));
	END "()";

	OPERATOR (VAR crc: Crc32) "()"* (CONST data: ARRAY OF CHAR; dataOffs, dataLen: SIZE);
	BEGIN
		WHILE dataLen > 0 DO
			crc.crc := UNSIGNED32(crc.table[UNSIGNED8(SET32(crc.crc) / SET32(ORD(data[dataOffs])))] / SET32(LSH(crc.crc,-8)));
			INC(dataOffs); DEC(dataLen);
		END;
	END "()";

	OPERATOR (VAR crc: Crc32) "()"* (CONST str: ARRAY OF CHAR);
	BEGIN
		VAR k := 0: SIZE;
		WHILE str[k] # 0X DO
			crc(str[k]);
			(*crc.crc := UNSIGNED32(crc.table[UNSIGNED8(SET32(crc.crc) / SET32(ORD(str[k])))] / SET32(LSH(crc.crc,-8)));*)
			INC(k);
		END;
	END "()";

TYPE

	(** CounterSize*8 bit counter with big endian storage format *)
	Counter* = RECORD;
		data-: ARRAY CounterSize OF CHAR;

		(** Clear (zero) the counter *)
		PROCEDURE Clear*();
		BEGIN
			VAR k := 0: INTEGER;
			WHILE k < CipherBlockSize DO
				data[k] := 0X; INC(k);
			END;
		END Clear;

		(** Set counter value given a CounterSize long byte array *)
		PROCEDURE Set*(CONST value: ARRAY OF CHAR; offs: SIZE);
		BEGIN
			ASSERT(LEN(value) >= offs+CipherBlockSize);
			VAR k := 0: INTEGER;
			WHILE k < CipherBlockSize DO
				data[k] := value[offs+k]; INC(k);
			END;
		END Set;

		(** Increment the counter *)
		PROCEDURE Inc*(increment: SIGNED32);
		BEGIN
			ASSERT(increment > 0);
			VAR d := ORD(data[CipherBlockSize-1]) + increment: UNSIGNED32;
			data[CipherBlockSize-1] := CHR(d);
			VAR k := CipherBlockSize-1: INTEGER;
			WHILE (k # 0) & (d > 255) DO
				DEC(k); d :=  LSH(d, -8) + ORD(data[k]);
				data[k] := CHR(d);
			END;
		END Inc;
	END;

	(** Hash function used for Fortuna seeding *)
	Hash* = RECORD
		hash: CryptoHashes.Hash;

		(** Set the hash to its initial state *)
		PROCEDURE Init*();
		BEGIN
			IF hash = NIL THEN
				hash := CryptoHashes.NewHash("CryptoSHA256");
				ASSERT(hash # NIL);
			END;
			hash.Initialize;
		END Init;

		(** Update the hash with a given data *)
		PROCEDURE Update*(CONST data: ARRAY OF CHAR; dataOffs, dataLen: SIZE);
		BEGIN
			hash.Update(data, dataOffs, dataLen);
		END Update;

		(** Get the HashSize byte long hash value *)
		PROCEDURE GetHash*(VAR hashValue: ARRAY OF CHAR; hashValueOffs: SIZE);
		BEGIN
			(* SHAd256 (SHA256-doubled) hash as described in the original algorithm description *)
			hash.GetHash(hashValue, hashValueOffs);
			hash.Initialize;
			hash.Update(hashValue, hashValueOffs, hash.size);
			hash.GetHash(hashValue, hashValueOffs);
		END GetHash;
	END;

	(** Cipher-based pseudorandom stream generator *)
	Generator* = RECORD
		isSeeded-: BOOLEAN; (** TRUE if the generator is already seeded *)
		key-: ARRAY CipherKeySize OF CHAR;

		ctr: Counter;
		hash: Hash;
		cipher: CryptoCiphers.Cipher;

		(** Set the generator to its initial state *)
		PROCEDURE Init*();
		BEGIN
			IF cipher = NIL THEN
				cipher := CryptoCiphers.NewCipher("CryptoAES");
				ASSERT(cipher # NIL);
			END;

			isSeeded := FALSE;
			hash.Init;
			ctr.Clear;
			VAR k := 0: SIZE;
			WHILE k < CipherKeySize DO
				key[k] := 0X; INC(k);
			END;
		END Init;

		(** Reseed the generator with given seed data  *)
		PROCEDURE Reseed*(CONST seed: ARRAY OF CHAR; seedOffs, seedLen: SIZE);
		BEGIN
			(* hash the current key concatenated with the provided seed *)
			hash.Init;
			hash.Update(key, 0, CipherKeySize);
			hash.Update(seed, seedOffs, seedLen);
			hash.GetHash(key, 0);
			(* use the computed hash as the cipher key *)
			ctr.Inc(1);
			cipher.InitKey(key, CipherKeySize);
			cipher.SetIV(ctr.data, CryptoCiphers.CTR);
			isSeeded := TRUE;
		END Reseed;

		(* A private method for cipher-based generation of multiple pseudorandom data blocks of size CipherBlockSize *)
		PROCEDURE GenerateBlocksPrivate(VAR buf: ARRAY OF CHAR; bufOffs, numBlocks: SIZE);
		BEGIN
			VAR k := 0, bufLen := numBlocks * CipherBlockSize: SIZE;
			WHILE k < bufLen DO
				buf[k+bufOffs] := 0X; INC(k);
			END;
			(*! In the original algorithm description the counter is in little endian format.
				However, here we use a big endian counter to be compatible with A2 and OpenSSL cipher implementations in CTR mode.
			*)
			cipher.Encrypt(buf, bufOffs, bufLen);
			ctr.Inc(SIGNED32(numBlocks)); (* increment the counter by the number of processed blocks *)

			(* this is how it would be in case of a little-endian format
			WHILE bufLen > 0 DO
				cipher.Encrypt(buf, bufOffs, CipherBlockSize);
				ctr.Inc(1);
				cipher.SetIV(ctr.data, CryptoCiphers.CTR);
				INC(bufOffs, CipherBlockSize); DEC(bufLen, CipherBlockSize);
			END;
			*)
		END GenerateBlocksPrivate;

		(* A private method for switching to a new cipher key to avoid later compromises of the generator output *)
		PROCEDURE ChangeKeyPrivate();
		BEGIN
			GenerateBlocksPrivate(key, 0, CipherKeySize DIV CipherBlockSize);
			cipher.InitKey(key, CipherKeySize);
			cipher.SetIV(ctr.data, CryptoCiphers.CTR);
		END ChangeKeyPrivate;

		(** Generate a specified amount of pseudorandom data *)
		PROCEDURE Generate*(VAR data: ARRAY OF CHAR; dataOffs, dataLen: SIZE);
		BEGIN
			(* process 1048576 bytes chunks with rekeying of the cipher after every chunk *)
			WHILE dataLen >= 1048576 DO
				GenerateBlocksPrivate(data, dataOffs, 1048576 DIV CipherBlockSize);
				ChangeKeyPrivate;
				INC(dataOffs, 1048576); DEC(dataLen, 1048576);
			END;

			IF dataLen > 0 THEN

				(* process remaining complete blocks *)
				IF dataLen >= CipherBlockSize THEN
					VAR numBlocks := dataLen DIV CipherBlockSize: SIZE;
					GenerateBlocksPrivate(data, dataOffs, numBlocks);
					VAR n := numBlocks*CipherBlockSize: SIZE;
					INC(dataOffs, n); DEC(dataLen, n);
				END;

				(* process remaining bytes *)
				IF dataLen > 0 THEN
					VAR block: ARRAY CipherBlockSize OF CHAR;
					GenerateBlocksPrivate(block, 0, 1);
					VAR k := 0: INTEGER;
					WHILE dataLen > 0 DO
						data[dataOffs] := block[k];
						INC(k); INC(dataOffs); DEC(dataLen);
					END;
				END;

				ChangeKeyPrivate;
			END;
		END Generate;
	END;

	(** Fortuna pool *)
	Pool* = RECORD
		length-: SIZE; (** amount of data fed to the pool since the last call of Init *)

		hash: Hash;

		(** Set the pool to its initial state *)
		PROCEDURE Init*();
		BEGIN
			hash.Init;
			length := 0;
		END Init;

		(** Append to the pool given amount of data with entropy *)
		PROCEDURE Append*(CONST data: ARRAY OF CHAR; dataOffs, dataLen: SIZE);
		BEGIN
			hash.Update(data, dataOffs, dataLen);
			INC(length, dataLen);
		END Append;

		(** Get the HashSize byte long pool hash value *)
		PROCEDURE GetHash*(VAR hashValue: ARRAY OF CHAR; hashValueOffs: SIZE);
		BEGIN
			hash.GetHash(hashValue, hashValueOffs);
		END GetHash;
	END;

	(** A helper object for computing indices of pool to reseed based on the reseed count as described in the original algorithm description *)
	ReseedPoolIndices* = RECORD
		r, k, mask: SIZE;

		PROCEDURE Init*(reseedCount: SIZE);
		BEGIN
			ASSERT(reseedCount >= 1);
			r := reseedCount;
			k :=0;
			mask := 0;
		END Init;

		(** Get the next index of a pool to reseed *)
		PROCEDURE GetNext*(VAR index: SIZE): BOOLEAN;
		BEGIN
			IF (k < NumPools) & (SET(mask) * SET(r) = {}) THEN
				mask := SIZE(SET(LSH(mask, 1)) + {0});
				index := k; INC(k);
				RETURN TRUE;
			ELSE RETURN FALSE;
			END;
		END GetNext;
	END;

	(** Fortuna accumulator *)
	Accumulator* = RECORD
		reseedCount-: SIZE; (** generator reseed count *)

		generator: Generator;
		pools: ARRAY NumPools OF Pool;
		lastReseedTime: SIGNED64; (* last reseed time in ms *)

		seedBuf: ARRAY NumPools*HashSize OF CHAR; (* buffer for concatenating up to NumPools pool hash values used for generator reseeding *)

		(** Set the accumulator to its initial state *)
		PROCEDURE Init*();
		VAR k: SIZE;
		BEGIN
			(* set the pools to the empty string *)
			FOR k := 0 TO LEN(pools)-1 DO pools[k].Init; END;
			reseedCount := 0;
			generator.Init;
			lastReseedTime := MIN(SIGNED64);
		END Init;

		(** Generate pseudorandom data.

			currentTimeMs : current time counter value in ms
			data :  output data array
			dataOffs : offset in the output array
			dataLen : requested amount of data in bytes
		*)
		PROCEDURE Generate*(currentTimeMs: SIGNED32; VAR data: ARRAY OF CHAR; dataOffs, dataLen: SIZE);
		BEGIN
			IF (pools[0].length >= MinPoolSize) & ((lastReseedTime = MIN(SIGNED64)) OR (lastReseedTime > currentTimeMs) OR (currentTimeMs - lastReseedTime > ReseedIntervalMs)) THEN
				(* reseed the generator *)
				INC(reseedCount);

				VAR inds: ReseedPoolIndices;
				inds.Init(reseedCount);
				VAR seedLen := 0, ind: SIZE;
				WHILE inds.GetNext(ind) DO
					pools[ind].GetHash(seedBuf, seedLen);
					pools[ind].Init; (* reset the pool *)
					INC(seedLen, HashSize);
				END;
				generator.Reseed(seedBuf, 0, seedLen);

				lastReseedTime := currentTimeMs;
			END;
			ASSERT(reseedCount # 0); (*! the generator is not yet seeded *)
			generator.Generate(data, dataOffs, dataLen);
		END Generate;

		(** Add random source event data to a selected pool

			sourceNum : random source number within [0, 255]
			poolIndex : selected pool index within [0, NumPools)
			data: random source data
			dataOffs : random source data offset
			dataLen : random source data length (not more than MaxRandomEventDataLen bytes)
		*)
		PROCEDURE AddRandomEvent*(sourceNum: INTEGER; poolIndex: SIZE; CONST data: ARRAY OF CHAR; dataOffs, dataLen: SIZE);
		VAR buf: ARRAY 2 OF CHAR;
		BEGIN
			ASSERT((sourceNum >= 0) & (sourceNum <= 255));
			ASSERT((poolIndex >= 0) & (poolIndex < NumPools));
			ASSERT((dataLen > 0) & (dataLen <= MaxRandomEventDataLen));
			buf[0] := CHR(sourceNum);
			buf[1] := CHR(dataLen);
			pools[poolIndex].Append(buf, 0, 2);
			pools[poolIndex].Append(data, dataOffs, dataLen);
		END AddRandomEvent;

		(** Returns TRUE if the accumulator is ready for use and the user can call Generate method

			currentTimeMs : current time counter value in ms
		*)
		PROCEDURE IsReady*(currentTimeMs: SIGNED32): BOOLEAN;
		BEGIN
			RETURN generator.isSeeded OR ((pools[0].length >= MinPoolSize) & ((lastReseedTime = MIN(SIGNED64)) OR (lastReseedTime > currentTimeMs) OR (currentTimeMs - lastReseedTime > ReseedIntervalMs)));
		END IsReady;
	END;

	(** Pool of randomly permuted integer indices *)
	Permutation* = RECORD
		size-: SIZE; (** size of the pool in number of elements *)

		values: ARRAY 256 OF UNSIGNED8;

		(** Initialize the permutation

			rand : random generator procedure; NIL to implement linear indexing
			poolSize : permutation index pool size; pool indices are within the range [0, poolSize)
		*)
		PROCEDURE Init*(rand: PROCEDURE{DELEGATE}(): SIGNED32; poolSize: SIZE);

			PROCEDURE Swap(VAR x, y: UNSIGNED8);
			BEGIN
				VAR z := x; x := y; y := z;
			END Swap;

		BEGIN
			ASSERT((poolSize > 0) & (poolSize <= 256));

			size := poolSize;

			(* initialize the pool with ordered indices *)
			VAR k := 0: SIZE;
			WHILE k < size DO
				values[k] := UNSIGNED8(k);
				INC(k);
			END;

			IF rand # NIL THEN (* in case if rand is NIL the permutation will be equivalent to linear indexing *)
				(* permute by swapping value pairs *)
				k := 0;
				WHILE k < size DO (* (size DIV 2) would be enough, but let's do more *)
					Swap(values[rand() MOD size], values[rand() MOD size]);
					INC(k);
				END;
			END;
		END Init;

		(** Get permuted index at a given pool position; (pos >= 0) & (pos < poolSize) *)
		PROCEDURE Get*(pos: SIZE): SIZE;
		BEGIN
			ASSERT((pos >= 0) & (pos < size));
			RETURN values[pos];
		END Get;
	END;

	(** Fortuna entropy collector *)
	EntropyCollector* = RECORD
		poolIndex: INTEGER;

		PROCEDURE Init*();
		BEGIN
			poolIndex := 0;
		END Init;

		(** Collect entropy data from a randomness source *)
		PROCEDURE Collect*(VAR accumulator: Accumulator; sourceNum: INTEGER; CONST data: ARRAY OF CHAR; dataOffs, dataLen: SIZE);
		BEGIN
			IF dataLen # 0 THEN
				accumulator.AddRandomEvent(sourceNum, poolIndex, data, dataOffs, dataLen);
				INC(poolIndex);
				IF poolIndex >= NumPools THEN poolIndex := 0; END;
			END;
		END Collect;
	END;

	PROCEDURE Int16ToBytes*(v: INTEGER; VAR bytes: ARRAY OF CHAR; VAR bytesOffs: SIZE);
	BEGIN
		bytes[bytesOffs+0] := CHR(v);
		bytes[bytesOffs+1] := CHR(LSH(v, -8));
		INC(bytesOffs, 2);
	END Int16ToBytes;

	PROCEDURE Int24ToBytes*(v: SIGNED32; VAR bytes: ARRAY OF CHAR; VAR bytesOffs: SIZE);
	BEGIN
		bytes[bytesOffs+0] := CHR(v);
		bytes[bytesOffs+1] := CHR(LSH(v, -8));
		bytes[bytesOffs+2] := CHR(LSH(v, -16));
		INC(bytesOffs, 3);
	END Int24ToBytes;

	PROCEDURE Int32ToBytes*(v: SIGNED32; VAR bytes: ARRAY OF CHAR; VAR bytesOffs: SIZE);
	BEGIN
		bytes[bytesOffs+0] := CHR(v);
		bytes[bytesOffs+1] := CHR(LSH(v, -8));
		bytes[bytesOffs+2] := CHR(LSH(v, -16));
		bytes[bytesOffs+3] := CHR(LSH(v, -24));
		INC(bytesOffs, 4);
	END Int32ToBytes;

	PROCEDURE IntToBytes*(v: SIGNED64; VAR bytes: ARRAY OF CHAR; VAR bytesOffs: SIZE; byteCount: SIZE);
	BEGIN
		INC(bytesOffs, byteCount);
		WHILE byteCount > 0 DO
			bytes[bytesOffs] := CHR(v);
			v := LSH(v, -8);
			DEC(byteCount);
		END;
	END IntToBytes;

END CryptoFortuna.

System.FreeDownTo CryptoFortuna ~

FoxTest.Compile	-l=Test.Log CryptoFortuna.Execution.Test  ~
