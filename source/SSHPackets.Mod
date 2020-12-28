MODULE SSHPackets;  (* GF 10.12.2020 *)

IMPORT Strings, Log := KernelLog, B := CryptoBigNumbers, U := CryptoUtils;

CONST				
	Disconn* = 1X;  Ignore* = 2X;  Unimpl* = 3X;  Debug* = 4X;
	ServiceRequest* = 5X;  ServiceAccept* = 6X;
	
	KEXInit* = 14X;  NewKeys* = 15X;  DHInit* = 1EX;  DHReply* = 1FX;   
	GEXInit* = 20X;  GEXReply* = 21X;  GEXRequest* = 22X;  GEXGroup* = 1FX;  
	
	UserauthRequest* = 32X;  UserauthFailure* = 33X;
	UserauthSuccess* = 34X;  UserauthBanner* = 35X;
	UserauthPkOk* = 3CX;
	
	GlobalRequest* = 50X;  RequestSuccess* = 51X;  RequestFailure* = 52X;  
	ChannelOpen* = 5AX;  OpenConfirm* = 5BX;  OpenFailure* = 5CX;  
	WindAdjust* = 5DX;  Data* = 5EX;  ExtData* = 5FX;  
	
	ChannelEOF* = 60X;  ChannelClose* = 61X;
	ChannelRequest* = 62X;  ChannelSuccess* = 63X;  ChannelFailure* = 64X;


TYPE	
	Packet* = OBJECT (** SSH Packet *)
		VAR
			buf-: POINTER TO ARRAY OF CHAR;
			type-: CHAR;
			len-: SIZE;	(* packet size *)
			pos-: SIZE;	(* read position *)
			sent: BOOLEAN;
			
			PROCEDURE &Init*( ptype: CHAR; bufsize: SIZE );
			BEGIN
				NEW( buf, bufsize );
				type := ptype; buf[0] := ptype;  len := 1;
				sent := TRUE
			END Init;
			
			(*===============================================================*)
			
			PROCEDURE AppInteger* ( v: SIZE );
			BEGIN
				buf[len] := CHR( v DIV 1000000H MOD 100H );
				buf[len+1] := CHR( v DIV 10000H MOD 100H );
				buf[len+2] := CHR( v DIV 100H MOD 100H );
				buf[len+3] := CHR( v MOD 100H );
				INC( len, 4 )
			END AppInteger;
			
			PROCEDURE AppChar*( c: CHAR );
			BEGIN
				buf[len] := c;  INC( len )
			END AppChar;
			
			PROCEDURE AppString*( CONST str: ARRAY OF CHAR );
			VAR slen, i: SIZE; 
			BEGIN
				slen := Strings.Length( str );
				AppInteger( slen );
				FOR i := 0 TO slen-1 DO  buf[len+i] := str[i]  END;
				INC( len, slen )
			END AppString;

			PROCEDURE AppArray*( CONST arr: ARRAY OF CHAR;  pos, arlen: SIZE );
			VAR i: SIZE;
			BEGIN
				AppInteger( SIGNED32(arlen) );
				FOR i := 0 TO arlen-1 DO  buf[len+i] := arr[pos+i]  END;
				INC( len, arlen )
			END AppArray;
			
			PROCEDURE AppBigNumber*( b: B.BigNumber );
			BEGIN
				U.PutBigNumber( buf^, len, b );
			END AppBigNumber;
			
			(*================================================================*)
			
			PROCEDURE SetPos*( p: SIZE );
			BEGIN
				pos := p
			END SetPos;
			
			PROCEDURE IncPos*( i: INTEGER );
			BEGIN
				INC( pos, i )
			END IncPos;
			
			PROCEDURE GetInteger*(): SIGNED32;
			VAR i: SIGNED32;
			BEGIN
				i :=	ASH( SIGNED32( ORD( buf[pos] ) ), 24 ) +
						ASH( SIGNED32( ORD( buf[pos + 1] ) ), 16 ) +
						ASH( SIGNED32( ORD( buf[pos + 2] ) ), 8 ) +
						SIGNED32( ORD( buf[pos + 3] ) );
				INC( pos, 4 );
				RETURN i
			END GetInteger;
			
			PROCEDURE GetChar*(): CHAR;
			VAR c: CHAR; p: SIZE;
			BEGIN 
				p := pos;
				c := buf[pos];  INC( pos );  RETURN c
			END GetChar;
			
			PROCEDURE GetBlobInfo*( VAR start, size: SIZE );
			VAR l: SIGNED32;
			BEGIN
				start := pos;
				l := GetInteger( );
				INC( pos, l );
				size := l + 4
			END GetBlobInfo;
			
			PROCEDURE GetString*( VAR str: ARRAY OF CHAR );
			VAR i, slen: SIGNED32;
			BEGIN
				slen := GetInteger();
				FOR i := 0 TO slen - 1 DO  str[i] := buf[pos + i]  END;
				str[slen] := 0X;  INC( pos, slen )
			END GetString;
			
			PROCEDURE GetArray*( VAR arr: ARRAY OF CHAR; VAR arlen: SIZE );
			VAR i: SIZE;
			BEGIN
				arlen := GetInteger();
				FOR i := 0 TO arlen - 1 DO  arr[i] := buf[pos + i]  END;
				INC( pos, arlen )
			END GetArray;
			
			PROCEDURE GetBigNumber*( ): B.BigNumber;
			VAR b: B.BigNumber;  l: SIGNED32;
			BEGIN
				l := GetInteger( );
				B.AssignBin( b, buf^, pos, l );
				INC( pos, l );
				RETURN b
			END GetBigNumber;
			
			(*================================================================*)
			
			
			PROCEDURE Show*;
			VAR i, j, d: SIZE;  c: CHAR;
			BEGIN
				IF sent THEN  Log.String( "Sent: " )  ELSE  Log.String( "Got: " )  END;
				Log.Hex( ORD( type ), -2 ); Log.String( "X(" );  Log.Int( ORD( type ), 0 );  Log.String( "), len=" ); Log.Int( len, 0 ); 
				SetPos( 1 );
				IF (type = 50X) OR (type = 5DX) OR (type = 5EX) THEN
					i := GetInteger( );  
					Log.String( ", " );  Log.Int( i, 0 );
				END;
				Log.Ln; Log.String( "      " ); i := 0;
				REPEAT
					c := buf[i];  INC( i );
					Log.Hex( ORD(c), -2 );  Log.Char( ' ' );
					IF i MOD 32 = 0 THEN  
						Log.String( "   " );
						j := i - 32;
						REPEAT
							c := buf[j];  INC( j );
							IF (c < ' ') OR (c > '~') THEN  Log.Char( '.' )  ELSE  Log.Char( c )  END
						UNTIL j = i;
						Log.Ln;  Log.String( "      " )  
					END
				UNTIL i >= len;
				d := i MOD 32;
				IF d # 0 THEN
					Log.String( "   " );
					j := i - d;
					REPEAT
						c := buf[j];  INC( j );
						IF (c < ' ') OR (c > '~') THEN  Log.Char( '.' )  ELSE  Log.Char( c )  END
					UNTIL j = i;
				END;		
				Log.Ln;
			END Show;

	END Packet;
	
VAR
	emptyPacket-: Packet; (* marks end of data from remote host *)
	
	
	
	PROCEDURE MakeReceivedPacket*( CONST trbuf: ARRAY OF CHAR;  len: SIZE ): Packet;
	VAR p: Packet; i: SIZE;
	BEGIN
		NEW( p, 0X, len ); 
		FOR i := 0 TO len - 1 DO  p.buf[i] := trbuf[i+5]  END;
		p.type := p.buf[0];
		p.len := len;
		p.pos := 1;
		p.sent := FALSE;
		RETURN p
	END MakeReceivedPacket;
	

BEGIN
	NEW( emptyPacket, Data, 16 );	 
		emptyPacket.sent := FALSE;
		emptyPacket.pos := 5;
END SSHPackets.
