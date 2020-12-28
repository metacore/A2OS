MODULE SSHChannels;   (* GF  7.12.2020 *)

IMPORT Kernel, Streams, Log := KernelLog,
		P := SSHPackets, T := SSHTransport;

CONST
	WinSize = 8*1024;
	MaxPacketSize = 4*1024;   (* max packet size *)

	Opening* = 0;  Open* = 1;  Closed* = 2;  (* chanel states *)

	(*-----------------------------------------------------------------------*)

	
TYPE
	Packet = P.Packet;
	Connection = T.Connection;
	
	Channel* = OBJECT (Streams.Connection)
	CONST
		BufSize = 2*2048;
		VAR
			state-: INTEGER;
			conn: Connection;
			rchan: SIGNED32;
			clchan: SIGNED32;
			rwsize: SIZE;
			clwsize: SIZE;
			rpmax: SIZE;   (* max packet size accepted by remote host *)
			interactive: BOOLEAN;
			
			timer: Kernel.Timer;
			
			sendBuffer: ARRAY BufSize OF CHAR; bufPos, sentBytes: SIZE;
			rpac: Packet;

			PROCEDURE Send*( CONST data: ARRAY OF CHAR;  ofs, len: SIZE;  propagate: BOOLEAN;  VAR res: INTEGER );
			VAR 
				i: SIZE;
			BEGIN 
				FOR i := 0 TO len - 1 DO
					sendBuffer[bufPos] := data[ofs + i];  INC( bufPos );
					IF bufPos = BufSize THEN  FlushBuffer  END
				END;
				IF propagate THEN FlushBuffer  END;
				res := Streams.Ok
			END Send;

			PROCEDURE Receive*( VAR data: ARRAY OF CHAR;  ofs, size, min: SIZE;  VAR len: SIZE; VAR res: INTEGER );
			BEGIN
				len := 0; 
				REPEAT
					IF rpac.pos < rpac.len THEN
						WHILE (len < size) & (rpac.pos < rpac.len) DO
							data[ofs] := rpac.GetChar( );
							INC( ofs ); INC( len ); 
						END;
					ELSE
						IF state = Closed THEN
							res := Streams.EOF;  RETURN
						END;
						IF conn.PacketAvailable() THEN
							rpac := GetPacket( );
							IF rpac.type = P.ChannelEOF THEN
								res := Streams.EOF;  
								RETURN
							END;
							ASSERT( rpac.type = P.Data );
						END
					END;
				UNTIL len >= min;
				res := Streams.Ok;
			END Receive;


			PROCEDURE FlushBuffer;
			VAR 
				p: Packet;
			BEGIN 
				IF ~interactive THEN  GetWindowSpace  END;
				IF bufPos > 0 THEN
					NEW( p, P.Data, bufPos + 9 );
						p.AppInteger( rchan );
						p.AppArray( sendBuffer, 0, bufPos );
					conn.SendPacket( p );  
					INC( sentBytes, bufPos );
					DEC( rwsize, bufPos );
					bufPos := 0;
				END;
			END FlushBuffer;
			
			PROCEDURE GetWindowSpace;
			VAR p: Packet;
				space: SIZE;
			BEGIN
				IF sentBytes > 500 THEN
					WHILE conn.PacketAvailable( ) DO	
						p := conn.GetPacket( );
						ASSERT( p.type = P.WindAdjust );
						p.SetPos( 5 );
						space :=  p.GetInteger( );
						INC( rwsize, space );
						timer.Sleep( 50 );
					END
				END
			END GetWindowSpace; 


			PROCEDURE GetPacket( ): Packet;
			VAR newspace: SIGNED32;
				rp, sp: Packet; 
				msg: ARRAY 256 OF CHAR; repl: BOOLEAN;
			BEGIN 
				rp := conn.GetPacket( );
				CASE rp.type OF
				| P.WindAdjust:
						rp.SetPos( 5 );
						newspace := rp.GetInteger( );
						INC( rwsize, newspace );
						RETURN GetPacket( )
				| P.ChannelEOF:
						RETURN rp
				| P.ChannelClose:
						SkipInput; (* if any *)
						IF state # Closed THEN
							Close
						END;
						RETURN P.emptyPacket
				| P.Data:
						rp.SetPos( 5 );
						DEC( clwsize, rp.GetInteger( ) );	
						IF clwsize < 5000 THEN	
							NEW( sp, P.WindAdjust, 128 );
								sp.AppInteger( rchan );  
								sp.AppInteger( WinSize - clwsize );
							conn.SendPacket( sp );
							clwsize := WinSize
						END;
						RETURN rp
				| P.ExtData:  (* stderr *)
						rp.SetPos( 9 );
						rp.GetString( msg );
						Log.String( msg ); Log.Ln;
						RETURN GetPacket( )
				| P.ChannelRequest:
						(* ignore signal, exit-signal, exit-status *)
						rp.SetPos( 5 );  
						rp.GetString( msg );
						repl := rp.GetChar( ) # 0X;
						IF repl THEN  rp.Show  END;
						RETURN P.emptyPacket
				ELSE
					IF state = Opening THEN
						RETURN rp
					ELSE
						ErrorResponse( "SSHChannels.GetPacket", rp ); 
						RETURN P.emptyPacket
					END
				END;
			END GetPacket;
				
				

			PROCEDURE WindowChange*( width, height: SIZE );
			VAR p: Packet;
			BEGIN
				FlushBuffer;
				NEW( p, P.ChannelRequest, 512 );
					p.AppInteger( rchan );
					p.AppString( "window-change" );
					p.AppChar( 0X );	(* false *)
					p.AppInteger( width );
					p.AppInteger( height );
					p.AppInteger( 0 );	(* width, pixel *)
					p.AppInteger( 0 );	(* height, pixel *)
				conn.SendPacket( p );
			END WindowChange;

			
			PROCEDURE Eof*;
			VAR p: Packet;
			BEGIN
				FlushBuffer;
				IF state = Open THEN
					NEW( p, P.ChannelEOF, 16 ); 
						p.AppInteger( rchan );  
					conn.SendPacket( p );
				END;
			END Eof;

			PROCEDURE Close*;
			VAR p: Packet;
			BEGIN
				FlushBuffer;
				IF state = Open THEN
					state := Closed;
					NEW( p, P.ChannelClose, 64 );  
						p.AppInteger( rchan );  
					conn.SendPacket( p );
				END;
				SkipInput;	(* exit-signal, exit-status *)
				bufPos := 0;
			END Close;
			
			PROCEDURE SkipInput;  
			(* consume any incoming packets until connection is quiet *)
			VAR 
				p: Packet;
			BEGIN
				timer.Sleep( 200 );
				WHILE conn.PacketAvailable( )  DO  
					p := GetPacket( );  
					timer.Sleep( 100 )  
				END;
			END SkipInput;

			PROCEDURE & Init*( c: Connection );
			BEGIN
				conn := c;  state := Opening;
				clchan := conn.GetChannelNo();
				rwsize := 0;  clwsize := WinSize;
				bufPos := 0;  sentBytes := 0;
				NEW( timer );
				rpac := P.emptyPacket
			END Init;

		END Channel;

(*=================================================================*)

	
	PROCEDURE OpenSession*( conn: Connection;  interactive: BOOLEAN ): Channel;
	VAR 
		sp, rp: Packet;  chan: Channel;
	BEGIN
		NEW( chan, conn );  

		NEW( sp, P.ChannelOpen, 512 );
		sp.AppString( "session" );
		sp.AppInteger( chan.clchan );
		sp.AppInteger( WinSize );
		IF interactive THEN  sp.AppInteger( 512 )  ELSE  sp.AppInteger( MaxPacketSize )  END;

		conn.SendPacket( sp );
		rp := chan.GetPacket( );
		IF rp.type = P.GlobalRequest THEN  
			(* ignore server hostkey *)
			rp := chan.GetPacket( )
		END;
		IF rp.type # P.OpenConfirm THEN
			ErrorResponse( "SSHChannels.OpenSession", rp );  RETURN NIL
		END;
		
		rp.SetPos( 5 );
		chan.rchan := rp.GetInteger( );
		chan.rwsize := rp.GetInteger( );
		chan.rpmax := rp.GetInteger( );
		
		NEW( sp, P.ChannelRequest, 512 );
			sp.AppInteger( chan.rchan );
			sp.AppString( "pty-req" );
			sp.AppChar( 1X );   (* want reply *)
			sp.AppString( "vt100" );
			sp.AppInteger( 80 );  sp.AppInteger( 24 );   (* chars *)
			sp.AppInteger( 640 );  sp.AppInteger( 480 );   (* pixels *)
			IF ~interactive THEN
				sp.AppInteger( 26 );
				sp.AppChar( CHR( 50 ) );  sp.AppInteger( 0 );   (* -isig *)
				sp.AppChar( CHR( 51 ) );  sp.AppInteger( 0 );   (* -icanon*)
				sp.AppChar( CHR( 52 ) );  sp.AppInteger( 0 );   (* -xcase*)
				sp.AppChar( CHR( 53 ) );  sp.AppInteger( 0 );   (* -echo *)
				sp.AppChar( CHR( 91 ) );  sp.AppInteger( 1 );   (* 8 bit mode *)
			ELSE
				sp.AppInteger( 1 )
			END;
		sp.AppChar( 0X );   (* 0 = TTY OP END *)
		conn.SendPacket( sp );
		
		rp := chan.GetPacket( );
		IF rp.type # P.ChannelSuccess THEN
			ErrorResponse( "SSHChannels.OpenSession: pty-request", rp );  RETURN NIL
		END;
		
		NEW( sp, P.ChannelRequest, 128 );
			sp.AppInteger( chan.rchan );
			sp.AppString( "shell" );
			sp.AppChar( 1X );   (* want reply *)
		conn.SendPacket( sp );

		rp := chan.GetPacket( );
		IF (rp.type # P.ChannelSuccess) THEN
			ErrorResponse( "SSHChannels.OpenSession: shell request", rp );  RETURN NIL
		END;
		IF ~interactive THEN  chan.SkipInput (* shell promt *)  END;
		chan.interactive := interactive;
		chan.state := Open;
		RETURN chan
	END OpenSession;
	
	
(*=================================================================*)
	

	PROCEDURE ErrorResponse( CONST caller: ARRAY OF CHAR; p: Packet );
	VAR msg: ARRAY 1024 OF CHAR;
	BEGIN
		Log.Ln;  Log.String( caller );
		IF p.type = P.OpenFailure THEN
			p.SetPos( 5 );
			Log.String( ": error code = " );  Log.Int( p.GetInteger( ), 1 );
			p.GetString( msg );
			Log.Char( ' ' );  Log.String( msg );
		ELSIF p.type = P.RequestFailure THEN
			Log.String( ": request failed " );
		ELSE
			Log.String( ": got unexpected packet: " );  
			p.Show
		END;
		Log.Ln;
	END ErrorResponse;


END SSHChannels.



