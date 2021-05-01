(**
	AUTHOR: Alexey Morozov
	PURPOSE: WebSocket (RFC 6455) server and client support for A2
*)
MODULE WebSockets;

IMPORT
	Rng := CryptoFortunaRng, Streams, CryptoSHA1, CryptoBase64, WebHTTP, WebHTTPServer,
	Objects, Locks, Strings, Commands, Modules
	(*, TFLog*);

CONST
	MaxNumEndpoints* = 32; (** maximal number of WebSocket server endpoints *)

TYPE
	(** WebSocket opcodes *)
	Opcode* = ENUM
		Continuation* = 0x00,
		Text* = 0x01,
		Binary* = 0x02,
		Close* = 0x08,
		Ping* = 0x09,
		Pong* = 0x0A,

		None = 0xFF (* used internally only *)
	END;

	(** WebSocket closure status codes according to RFC 6455 *)
	CloseStatus* = ENUM

		(**1000 indicates a normal closure, meaning that the purpose for
		which the connection was established has been fulfilled.*)
		NormalClosure* = 1000,

		(**1001 indicates that an endpoint is "going away", such as a server
		going down or a browser having navigated away from a page.*)
		GoingAway* = 1001,

		(**1002 indicates that an endpoint is terminating the connection due
		to a protocol error.*)
		ProtocolError* = 1002,

		(**1003 indicates that an endpoint is terminating the connection
		because it has received a type of data it cannot accept(e.g., an
		endpoint that understands only text data MAY send this if it
		receives a binary message).*)
		NotUnderstood* = 1003,

		(*1004
		Reserved.  The specific meaning might be defined in the future.*)

		(*1005 is a reserved value and MUST NOT be set as a status code in a
		Close control frame by an endpoint.  It is designated for use in
		applications expecting a status code to indicate that no status
		code was actually present.*)
		NoStatusCode* = 1005,

		(*1006 is a reserved value and MUST NOT be set as a status code in a
		Close control frame by an endpoint.  It is designated for use in
		applications expecting a status code to indicate that the
		connection was closed abnormally, e.g., without sending or
		receiving a Close control frame.*)
		ClosedAbnormally* = 1006,

		(**1007 indicates that an endpoint is terminating the connection
		because it has received data within a message that was not
		consistent with the type of the message(e.g., non - UTF - 8[RFC3629]
		data within a text message).*)
		NotConsistent* = 1007,

		(**1008 indicates that an endpoint is terminating the connection
		because it has received a message that violates its policy.This
		is a generic status code that can be returned when there is no
		other more suitable status code(e.g., 1003 or 1009) or if there
		is a need to hide specific details about the policy.*)
		PolicyViolated* = 1008,

		(**1009 indicates that an endpoint is terminating the connection
		because it has received a message that is too big for it to
		process.*)
		MessageTooBig* = 1009,

		(**1010 indicates that an endpoint (client) is terminating the
		connection because it has expected the server to negotiate one or
		more extension, but the server didn't return them in the response
		message of the WebSocket handshake.  The list of extensions that
		are needed SHOULD appear in the /reason/ part of the Close frame.
		Note that this status code is not used by the server, because it
		can fail the WebSocket handshake instead.*)
		MandatoryExtension* = 1010,

		(**1011 indicates that a server is terminating the connection because
		it encountered an unexpected condition that prevented it from
		fulfilling the request.*)
		UnexpectedCondition* = 1011,

		(*1015 is a reserved value and MUST NOT be set as a status code in a
		Close control frame by an endpoint.  It is designated for use in
		applications expecting a status code to indicate that the
		connection was closed due to a failure to perform a TLS handshake
		(e.g., the server certificate can't be verified).*)
		TlsHandshakeFailure* = 1015
	END;

	(** WebSocket endpoint handler *)
	EndpointHandler* = PROCEDURE{DELEGATE}(CONST uri: ARRAY OF CHAR; VAR conn: Connection);

	(** WebSocket server plugin for WebHTTPServer *)
	ServerPlugin* = OBJECT(WebHTTPServer.HTTPPlugin)
	TYPE
		(* WebSocket server endpoint descriptor *)
		Endpoint = RECORD
			pathPrefix: Strings.String;
			description: Strings.String;
			handler: EndpointHandler;
		END;
	VAR
		(*log: TFLog.Log;*)

		numEndpoints-: SIZE;
		endpoints: ARRAY MaxNumEndpoints OF Endpoint;

		PROCEDURE SetEndpoint*(CONST pathPrefix: ARRAY OF CHAR; handler: EndpointHandler; CONST description: ARRAY OF CHAR);
		BEGIN{EXCLUSIVE}
			ASSERT(handler # NIL);
			ASSERT(pathPrefix[0] = "/");
			VAR k := FindEndpoint(pathPrefix);
			IF k < 0 THEN
				k := numEndpoints;
				endpoints[k].pathPrefix := Strings.NewString(pathPrefix);
				endpoints[k].description := Strings.NewString(description);
				INC(numEndpoints);
			ELSE
				IF endpoints[k].description^ # description THEN
					endpoints[k].description := Strings.NewString(description);
				END;
			END;
			endpoints[k].handler := handler;
		END SetEndpoint;

		PROCEDURE RemoveEndpoint*(CONST pathPrefix: ARRAY OF CHAR): BOOLEAN;
		BEGIN{EXCLUSIVE}
			VAR k := FindEndpoint(pathPrefix);
			IF k >= 0 THEN
				DEC(numEndpoints);
				WHILE k < numEndpoints DO
					endpoints[k] := endpoints[k+1];
					INC(k);
				END;
				endpoints[k].pathPrefix := NIL;
				endpoints[k].description := NIL;
				endpoints[k].handler := NIL;
				RETURN TRUE;
			ELSE RETURN FALSE;
			END;
		END RemoveEndpoint;

		PROCEDURE ListEndpoints(out: Streams.Writer);
		VAR k: SIZE;
		BEGIN{EXCLUSIVE}
			IF numEndpoints > 0 THEN
				out.String("Available WebSocket endpoints:"); out.Ln;
				FOR k := 0 TO numEndpoints-1 DO
					out.String("    ");
					out.Int(k, 0); out.String(': "');
					out.String(endpoints[k].pathPrefix^);
					out.String('", "');
					out.String(endpoints[k].description^);
					out.String('"'); out.Ln;
				END;
			ELSE
				out.String("no WebSocket endpoints available"); out.Ln;
			END;
		END ListEndpoints;

		PROCEDURE FindEndpoint(CONST path: ARRAY OF CHAR): SIZE;
		BEGIN
			VAR k := 0: SIZE;
			WHILE (k < numEndpoints) & ~Strings.StartsWith2(endpoints[k].pathPrefix^, path) DO
				INC(k);
			END;
			IF k < numEndpoints THEN RETURN k;
			ELSE RETURN -1;
			END;
		END FindEndpoint;

		PROCEDURE &Init(CONST name: WebHTTPServer.Name);
		BEGIN
			Init^(name);
			(*NEW(log,"WsPlugin");*)
		END Init;

		(* Returns TRUE for a WebSocket upgrade request *)
		PROCEDURE CanHandle(host: WebHTTPServer.Host; VAR request: WebHTTP.RequestHeader; secure: BOOLEAN): BOOLEAN;
		BEGIN
			(*BEGIN{EXCLUSIVE}
				log.String("got a request"); log.Ln;
				WebHTTP.LogRequestHeader(log, request);
			END;*)

			IF request.method = WebHTTP.GetM THEN
				VAR field := WebHTTP.GetAdditionalField(request.additionalFields, "Upgrade");
				RETURN (field # NIL) & (field.value = "websocket");
			END;
			RETURN FALSE;
		END CanHandle;

		(* Handle a WebSocket upgrade request *)
		PROCEDURE Handle(host: WebHTTPServer.Host; VAR request: WebHTTP.RequestHeader; VAR reply: WebHTTP.ResponseHeader; VAR in: Streams.Reader; VAR out: Streams.Writer);
		VAR
			handshake: Handshake;
			endpointHandler: EndpointHandler;
		BEGIN
			ASSERT(request.method = WebHTTP.GetM);

			(*BEGIN{EXCLUSIVE}
				log.String("got a WebSocket upgrade request"); log.Ln;
				WebHTTP.LogRequestHeader(log, request);
			END;*)

			VAR clientKeyField := WebHTTP.GetAdditionalField(request.additionalFields, "Sec-WebSocket-Key");
			IF clientKeyField = NIL THEN
				SendError(WebHTTP.BadRequest, request, reply, out);
				RETURN;
			END;

			BEGIN{EXCLUSIVE}
				VAR k := FindEndpoint(request.uri);
				IF k >= 0 THEN
					endpointHandler := endpoints[k].handler;
				END;
			END;

			IF endpointHandler = NIL THEN
				SendError(WebHTTP.NotFound, request, reply, out);
				RETURN;
			END;

			reply.statuscode := WebHTTP.SwitchingProtocols;
			WebHTTP.SetAdditionalFieldValue(reply.additionalFields, "Upgrade", "websocket");
			WebHTTP.SetAdditionalFieldValue(reply.additionalFields, "Connection", "Upgrade");
			handshake.GenerateServerAccept(clientKeyField.value);
			WebHTTP.SetAdditionalFieldValue(reply.additionalFields, "Sec-WebSocket-Accept", handshake.result);
			WebHTTP.SendResponseHeader(reply,out);
			out.Update;

			VAR connection := NEW Connection(in, out, FALSE);
			endpointHandler(request.uri, connection);

			(* make sure the underlying connection is closed by the host *)
			WebHTTP.SetAdditionalFieldValue(request.additionalFields, "Connection", "close");
		END Handle;

		(* Send an error response *)
		PROCEDURE SendError(code: SIGNED32; VAR request: WebHTTP.RequestHeader; VAR reply: WebHTTP.ResponseHeader; out: Streams.Writer);
		BEGIN
			reply.statuscode := code;
			WebHTTP.GetReasonPhrase(code,reply.reasonphrase);
			reply.contenttype := "text/html; charset=UTF-8";
			reply.contentlength := 0;
			WebHTTP.SendResponseHeader(reply,out);
			out.Update;
		END SendError;

	END ServerPlugin;

	(** WebSocket handshake helper *)
	Handshake* = RECORD
		result-: ARRAY 64 OF CHAR; (** handshake result string - request key in case of the client, accept response in case of the server *)

		hash: CryptoSHA1.SHA1;

		PROCEDURE GenerateClientKey*();
		VAR buf: ARRAY 16 OF CHAR;
		BEGIN
			(* 16 random bytes *)
			Rng.Generate(buf, 0, 16);
			CryptoBase64.Encode(buf, 16, result);
		END GenerateClientKey;

		PROCEDURE GenerateServerAccept*(CONST clientKey: ARRAY OF CHAR);
		VAR buf: ARRAY 20 OF CHAR;
		BEGIN
			hash.Initialize;
			hash(clientKey, 0, Strings.Length(clientKey));
			hash("258EAFA5-E914-47DA-95CA-C5AB0DC85B11", 0, 36);
			hash.GetHash(buf, 0);
			CryptoBase64.Encode(buf, 20, result);
		END GenerateServerAccept;
	END;

	(** WebSocket connection state *)
	ConnectionState* = ENUM
		Open* = 0, (** socket connection is open and can be used for sending and receiving messages *)
		ClosingByLocalRequest* = 1, (** closing the socket connection by a request from the user; the connection is unusable *)
		ClosingByRemoteRequest* = 2, (** closing the socket connection by a request from the remote peer; the connection is unusable *)
		ClosedByLocalRequest* = 3, (** socket connection is closed locally by the user; the connection is unusable *)
		ClosedByRemoteRequest* = 4, (** socket connection is closed by a request from the remote peer; the connection is unusable *)
		Aborted* = 5, (** socket connection has been aborted locally by the user; the connection is unusable *)
		StreamError* = 6 (** WebSocket stream IO error has occurred; the connection is unusable *)
	END;

	(** WebSocket connection exposing Streams-compatible Sender and Receiver interface *)
	Connection* = OBJECT
	TYPE
		ReadState = ENUM
			ReadingHeader = 0,
			ReadingExtPayloadLen = 1,
			ReadingMask = 2,
			ReadingPayload = 3,
			ReadingPingPayload = 4,
			ReadingClosePayload = 5
		END;
	VAR
		isClient-: BOOLEAN; (** TRUE in case of a client WebSocket connection *)
		state-: ConnectionState; (** WebSocket connection state *)
		closeStatus-: INTEGER; (** WebSocket close status received from the remote peer *)
		closeReason-: ARRAY 1024 OF CHAR; (** WebSocket close reason received from the remote peer *)

		in: Streams.Reader;
		out: Streams.Writer;

		(* transmit-specific variables *)
		txLock: Locks.Lock;
		sendingFragmentedMessage: BOOLEAN; (* TRUE if sending a fragmented message *)
		txOpcode: Opcode;
		txMask: ARRAY 4 OF CHAR;
		txBuf: ARRAY 4096 OF CHAR;

		(* receive-specific variables *)
		rxLock: Locks.Lock;
		rxState: ReadState;
		rxHdr0: INTEGER; (* first byte of the frame header *)
		rxOpcode, rxOpcodeFragmented: Opcode;
		rxFinal: BOOLEAN;
		rxPayloadLen: UNSIGNED64;
		rxPayloadLenSize: INTEGER;
		rxDataPos: SIZE;
		rxMask: ARRAY 4 OF CHAR;
		rxMaskPos: INTEGER;
		rxTerminatingNull: BOOLEAN;

		(*
			Initialize a WebSocket connection

			input, output : input/output streams
			isClientConnection : TRUE for a client connection
		*)
		PROCEDURE &Init(input: Streams.Reader; output: Streams.Writer; isClientConnection: BOOLEAN);
		BEGIN
			isClient := isClientConnection;
			state := ConnectionState.Open;
			closeStatus := -1;
			closeReason := "";

			in := input; out := output;
			txOpcode := Opcode.Binary; (* binary data mode by default *)

			GetReadyForNextFrame;
			rxOpcodeFragmented := Opcode.None;
			rxTerminatingNull := FALSE;

			IF rxLock = NIL THEN
				NEW(rxLock); NEW(txLock);
			END;
		END Init;

		PROCEDURE SetDataMode*(binaryMode: BOOLEAN);
		BEGIN
			txLock.Acquire;
			IF state = ConnectionState.Open THEN
				IF sendingFragmentedMessage THEN
					(* finalize the current fragmented frame *)
					WriteHeader(out, TRUE, Opcode.Continuation, 0); out.Update;
					sendingFragmentedMessage := FALSE;
				END;
				IF binaryMode THEN
					txOpcode := Opcode.Binary;
				ELSE
					txOpcode := Opcode.Text;
				END;
			END;
		FINALLY
			txLock.Release;
		END SetDataMode;

		(** Streams-compatible sender *)
		PROCEDURE Send*(CONST data: ARRAY OF CHAR;  offset, length: SIZE; propagate: BOOLEAN; VAR res: INTEGER);
		BEGIN
			res := -1; (* -1 will remain if trapped *)
			txLock.Acquire;
			IF state = ConnectionState.Open THEN
				IF sendingFragmentedMessage THEN
					VAR opcode := Opcode.Continuation;
				ELSE opcode := txOpcode;
				END;
				IF isClient THEN
					IF length > 0 THEN
						Rng.Generate(txMask, 0, 4);
						WriteFrameMasked(out, propagate, opcode, data, offset, length, txMask, txBuf);
					ELSE
						WriteHeader(out, propagate, opcode, 0);
					END;
				ELSE
					WriteFrame(out, propagate, opcode, data, offset, length);
				END;
				sendingFragmentedMessage := ~propagate;
				out.Update;
				res := out.res;
				IF res # 0 THEN
					(*!do not use rxLock here to avoid a dead-lock, instead use the atomic CAS instruction *)
					IGNORE CAS(state, ConnectionState.Open, ConnectionState.StreamError);
				END;
			ELSE res := Streams.EOF;
			END;
		FINALLY
			txLock.Release;
		END Send;

		(** Streams-compatible receiver *)
		PROCEDURE Receive*(VAR data: ARRAY OF CHAR; dataOffs, dataSize, min: SIZE; VAR len: SIZE; VAR res: INTEGER);

			PROCEDURE HandleReadingHeader();
			BEGIN
				IF rxHdr0 < 0 THEN (* first header byte not yet available *)
					rxHdr0 := INTEGER(ORD(in.Get()));
					DEC(available);
				END;
				IF available >= 1 THEN
					VAR rxHdr1 := INTEGER(ORD(in.Get())); (* second header byte *)
					DEC(available);

					rxFinal := 7 IN INTEGERSET(rxHdr0);
					rxPayloadLen := INTEGER(INTEGERSET(rxHdr1) * INTEGERSET(0x7f));
					VAR masked := 7 IN INTEGERSET(rxHdr1);

					IF isClient THEN
						IF masked THEN (*! "server MUST NOT mask any frames that it sends to the client"  *)
							CloseDueError(CloseStatus.ProtocolError, "server must not mask any frames");
							RETURN;
						END;
					ELSIF ~masked THEN (*! "client MUST mask all frames that it sends to the server" *)
						CloseDueError(CloseStatus.ProtocolError, "client must mask all frames");
						RETURN;
					END;

					VAR opcode := rxHdr0 MOD 0x10; (* rxHdr0 & 0x0F *)

					(*! "Control frames themselves MUST NOT be fragmented" *)
					IF ~rxFinal & IsControlFrame(opcode) THEN
						CloseDueError(CloseStatus.ProtocolError, "control frames must not be fragmented");
						RETURN;
					END;

					VAR receivingFragmentedMessage := (rxOpcodeFragmented # Opcode.None);

					(*! "A fragmented message consists of a single frame with the FIN bit
						clear and an opcode other than 0, followed by zero or more frames
						with the FIN bit clear and the opcode set to 0, and terminated by
						a single frame with the FIN bit set and an opcode of 0.".

						"Control frames MAY be injected in the middle of a fragmented message"
					*)
					IF receivingFragmentedMessage THEN
						IF (opcode # INTEGER(Opcode.Continuation)) & ~IsControlFrame(opcode) THEN
							CloseDueError(CloseStatus.ProtocolError, "expected a continuation frame");
							RETURN;
						END;
					ELSIF (opcode = INTEGER(Opcode.Continuation)) THEN
						CloseDueError(CloseStatus.ProtocolError, "unexpected continuation frame");
						RETURN;
					END;

					(*! a close frame must contain at least the status code *)
					IF (opcode = INTEGER(Opcode.Close)) & (rxPayloadLen < 2) THEN
						CloseDueError(CloseStatus.ProtocolError, "close frame too short");
						RETURN;
					END;

					CASE opcode OF
						|INTEGER(Opcode.Continuation):
							ASSERT(rxOpcodeFragmented # Opcode.None);
						|INTEGER(Opcode.Text):
							rxOpcode := Opcode.Text;
							IF ~rxFinal THEN rxOpcodeFragmented := Opcode.Text;
							ELSE ASSERT(rxOpcodeFragmented = Opcode.None);
							END;
						|INTEGER(Opcode.Binary):
							rxOpcode := Opcode.Binary;
							IF ~rxFinal THEN rxOpcodeFragmented := Opcode.Binary;
							ELSE ASSERT(rxOpcodeFragmented = Opcode.None);
							END;
						|INTEGER(Opcode.Close):
							rxOpcode := Opcode.Close;
							(* flag in case of a close request from the remote peer *)
							IGNORE CAS(state, ConnectionState.Open, ConnectionState.ClosingByRemoteRequest);
						|INTEGER(Opcode.Ping):
							rxOpcode := Opcode.Ping;
						|INTEGER(Opcode.Pong):
							rxOpcode := Opcode.Pong;
					ELSE
						CloseDueError(CloseStatus.ProtocolError, "unknown frame opcode");
						RETURN;
					END;

					IF rxPayloadLen >= 126 THEN
						IF rxPayloadLen = 126 THEN rxPayloadLenSize := 2;
						ELSE rxPayloadLenSize := 8;
						END;
						rxState := ReadState.ReadingExtPayloadLen;
						rxPayloadLen := 0;
						rxDataPos := 0;
					ELSIF isClient THEN
						IF rxPayloadLen # 0 THEN
							rxState := ReadState.ReadingPayload;
						ELSE (* frame without payload *)
							GetReadyForNextFrame;
						END;
					ELSE
						(*! read the mask for any frame (even for an empty one) *)
						rxState := ReadState.ReadingMask;
						rxDataPos := 0;
					END;
				END;
			END HandleReadingHeader;

			PROCEDURE HandleReadingExtPayloadLen();
			BEGIN
				WHILE (available > 0) & (rxDataPos < rxPayloadLenSize) DO
					INC(rxPayloadLen, LSH(UNSIGNED64(ORD(in.Get())), rxDataPos*8));
					DEC(available); INC(rxDataPos);
				END;
				IF rxDataPos = rxPayloadLenSize THEN (* finished reading the payload length *)
					rxDataPos := 0;
					IF isClient THEN
						IF rxOpcode = Opcode.Close THEN
							rxPayloadLen := MIN(rxPayloadLen, LEN(closeReason)-1);
							rxState := ReadState.ReadingClosePayload;
						ELSIF rxOpcode = Opcode.Ping THEN
							rxState := ReadState.ReadingPingPayload;
							IF isClient THEN
								Rng.Generate(rxMask, 0, 4); (* mask for forwarding ping data in a pong *)
							END;
							rxMaskPos := 0;
						ELSE
							rxState := ReadState.ReadingPayload;
							rxMaskPos := 0;
							available := MIN(available, dataSize-len);
						END;
					ELSE
						rxState := ReadState.ReadingMask;
					END;
				END;
			END HandleReadingExtPayloadLen;

			PROCEDURE HandleReadingMask;
			BEGIN
				ASSERT(~isClient);
				WHILE (available > 0) & (rxDataPos < 4) DO
					rxMask[rxDataPos] := in.Get();
					DEC(available); INC(rxDataPos);
				END;
				IF rxDataPos = 4 THEN
					IF rxOpcode # Opcode.Close THEN
						rxState := ReadState.ReadingPayload;
						available := MIN(available, dataSize-len);
					ELSE
						rxState := ReadState.ReadingClosePayload;
						rxDataPos := 0;
					END;
					IF ~isClient THEN
						rxMaskPos := 0;
					END;
				END;
			END HandleReadingMask;

			PROCEDURE HandleReadingPayload();
			BEGIN
				VAR n := 0: SIZE;
				in.Bytes(data, dataOffs, MIN(rxPayloadLen,available), n);
				IF ~isClient THEN
					ApplyMask(data, dataOffs, n, rxMask, rxMaskPos);
				END;
				DEC(available, n); DEC(rxPayloadLen, n); INC(dataOffs, n); INC(len, n);
				IF rxPayloadLen = 0 THEN (* finished to read the frame payload *)
					IF (rxOpcode = Opcode.Text) OR ((rxOpcode = Opcode.Continuation) & (rxOpcodeFragmented = Opcode.Text)) THEN
						(*! add a terminating null if received a text message *)
						IF len < dataSize THEN
							data[dataOffs] := 0X;
							INC(dataOffs); INC(len);
						ELSE (* set a flag to add the terminating null at the next call of "Receive" *)
							rxTerminatingNull := TRUE;
						END;
					END;
					IF rxFinal & (rxOpcode = Opcode.Continuation) THEN (* final frame of a fragmented message *)
						ASSERT(rxOpcodeFragmented # Opcode.None);
						rxOpcodeFragmented := Opcode.None;
					END;
					GetReadyForNextFrame;
				END;
			END HandleReadingPayload;

			PROCEDURE HandleReadingPingPayload();
			BEGIN
				(* forward the ping frame payload as a pong frame response *)
				WHILE (rxPayloadLen # 0) & (available > 0) & (state = ConnectionState.Open) DO
					txLock.Acquire;
					VAR n := 0: SIZE;
					in.Bytes(txBuf, 0, MIN(MIN(rxPayloadLen,available),LEN(txBuf)), n);
					DEC(available, n); DEC(rxPayloadLen, n);
					IF isClient THEN
						WritePayloadMasked(out, txBuf, 0, n, rxMask, rxMaskPos, txBuf);
					ELSE
						ApplyMask(txBuf, 0, n, rxMask, rxMaskPos);
						out.Bytes(txBuf, 0, n);
					END;
					IF out.res # 0 THEN
						state := ConnectionState.StreamError;
					END;
					txLock.Release;
				END;
				IF rxPayloadLen = 0 THEN (* finished sending the frame *)
					txLock.Acquire;
					IF state = ConnectionState.Open THEN
						out.Update;
						IF out.res = 0 THEN
							GetReadyForNextFrame;
						ELSE
							state := ConnectionState.StreamError;
						END;
					END;
					txLock.Release;
				END;
				RETURN;
			FINALLY
				IF txLock.HasLock() THEN txLock.Release; END;
			END HandleReadingPingPayload;

			PROCEDURE HandleReadingClosePayload();
			BEGIN
				VAR n := 0: SIZE;
				in.Bytes(closeReason, rxDataPos, MIN(rxPayloadLen,available), n);
				IF ~isClient THEN
					ApplyMask(closeReason, rxDataPos, n, rxMask, rxMaskPos);
				END;
				DEC(available, n); DEC(rxPayloadLen, n); INC(rxDataPos, n);
				IF rxPayloadLen = 0 THEN
					closeStatus := LSH(INTEGER(ORD(closeReason[0])),8) + ORD(closeReason[1]);
					IF rxDataPos = 2 THEN
						closeReason[0] := 0X;
					END;
					ASSERT(state # ConnectionState.Open);
					IF state = ConnectionState.ClosingByRemoteRequest THEN
						txLock.Acquire;
						SendClose(CloseStatus.NormalClosure, "");
						out.Update;
						IF out.res = 0 THEN
							state := ConnectionState.ClosedByRemoteRequest;
						ELSE
							state := ConnectionState.StreamError;
						END;
						txLock.Release;
					ELSIF state = ConnectionState.ClosingByLocalRequest THEN
						state := ConnectionState.ClosedByLocalRequest;
					END;
				END;
				RETURN;
			FINALLY
				IF txLock.HasLock() THEN txLock.Release; END;
			END HandleReadingClosePayload;

		BEGIN
			res := -1; len := 0;
			rxLock.Acquire;

			ASSERT(dataSize > 0);

			IF rxTerminatingNull THEN
				data[dataOffs] := 0X;
				INC(dataOffs); INC(len);
				rxTerminatingNull := FALSE;
			END;

			IF ~IsFullyClosed() THEN

				min := MAX(0, MIN(min, dataSize));

				REPEAT
					VAR available := in.Available();
					IF available # 0 THEN
						WHILE (available > 0) & (len < dataSize) & ~IsFullyClosed() DO
							CASE rxState OF
								|ReadState.ReadingHeader: HandleReadingHeader;
								|ReadState.ReadingExtPayloadLen: HandleReadingExtPayloadLen;
								|ReadState.ReadingMask: HandleReadingMask;
								|ReadState.ReadingPayload: HandleReadingPayload;
								|ReadState.ReadingPingPayload: HandleReadingPingPayload;
								|ReadState.ReadingClosePayload: HandleReadingClosePayload;
							END;
						END;
					ELSIF len < min THEN
						(*!TODO: implement timeout mechanism to avoid inifinite waiting for a close response *)
						IF ~IsFullyClosed() THEN
							Objects.Yield;
						ELSE
							res := Streams.EOF; RETURN;
						END;
					ELSE dataSize := len; (* got minimal amount of data, - terminate the loop *)
					END;
				UNTIL (len = dataSize);

				res := 0;

			ELSE res := Streams.EOF;
			END;

		FINALLY
			rxLock.Release;
		END Receive;

		(* Send a close frame *)
		PROCEDURE SendClose(status: CloseStatus; CONST reason: ARRAY OF CHAR);
		BEGIN
			IF isClient THEN
				Rng.Generate(txMask, 0, 4);
				WriteCloseMasked(out, status, reason, txMask, txBuf);
			ELSE WriteClose(out, status, reason);
			END;
			out.Update;
		END SendClose;

		PROCEDURE CloseDueError(status: CloseStatus; CONST reason: ARRAY OF CHAR);
		BEGIN
			ASSERT(rxLock.HasLock());
			txLock.Acquire;
			IF state = ConnectionState.Open THEN
				SendClose(status, reason);
				IF out.res = 0 THEN
					state := ConnectionState.ClosingByLocalRequest;
				ELSE
					state := ConnectionState.StreamError;
				END;
			ELSE
				ASSERT((state = ConnectionState.StreamError) OR (state = ConnectionState.Aborted));
			END;
		FINALLY
			txLock.Release;
		END CloseDueError;

		(** Closing of the connection

			status : closing status
			reason : null-terminated closing reason string
		*)
		PROCEDURE Close*(status: CloseStatus; CONST reason: ARRAY OF CHAR);
		BEGIN
			rxLock.Acquire; txLock.Acquire;
			IF state = ConnectionState.Open THEN
				SendClose(status, reason);
				IF out.res = 0 THEN
					state := ConnectionState.ClosingByLocalRequest;
				ELSE
					state := ConnectionState.StreamError;
				END;
			END;
		FINALLY
			rxLock.Release; txLock.Release;
		END Close;

		(** Abort the connection *)
		PROCEDURE Abort*();
		BEGIN
			IGNORE CAS(state, ConnectionState.Open, ConnectionState.Aborted);
		END Abort;

		(* Prepare for receiving a new frame *)
		PROCEDURE GetReadyForNextFrame();
		BEGIN
			rxState := ReadState.ReadingHeader;
			rxOpcode := Opcode.None;
			rxHdr0 := -1;
		END GetReadyForNextFrame;

		(* Returns TRUE if the connection is fully closed *)
		PROCEDURE -IsFullyClosed(): BOOLEAN;
		CONST
			FullyClosedStates = {INTEGER(ConnectionState.ClosedByLocalRequest), INTEGER(ConnectionState.ClosedByRemoteRequest), INTEGER(ConnectionState.Aborted)};
		BEGIN
			RETURN (INTEGER(state) IN FullyClosedStates);
		END IsFullyClosed;

	END Connection;

	(* Returns TRUE for a control frame opcode *)
	PROCEDURE -IsControlFrame(opcode: INTEGER): BOOLEAN;
	BEGIN
		(* Control frames are identified by opcodes where the most significant bit of the opcode is 1. *)
		RETURN 3 IN INTEGERSET(opcode);
	END IsControlFrame;

	(** Inplace application of WebSocket masking algorithm (same algorithm applies to both encoding and decoding) *)
	PROCEDURE ApplyMask*(VAR data: ARRAY OF CHAR; dataOffs, dataLen: SIZE; CONST mask: ARRAY 4 OF CHAR; VAR maskPos: INTEGER);
	BEGIN
		WHILE dataLen > 0 DO
			data[dataOffs] := CHR(INTEGER(INTEGERSET(ORD(data[dataOffs])) / INTEGERSET(ORD(mask[maskPos MOD 4]))));
			DEC(dataLen); INC(dataOffs); INC(maskPos);
		END;
	END ApplyMask;

	(** Write frame payload length

		out : output stream writer
		payloadLen : payload length in bytes
		masked : TRUE for a masked frame
	*)
	PROCEDURE WritePayloadLen*(out: Streams.Writer; payloadLen: SIZE; masked: BOOLEAN);
	BEGIN
		IF payloadLen < 126 THEN
			IF masked THEN
				out.Char(CHR(SIGNED8(SET8(payloadLen)+SET8(0x80)))); (* payloadLen|0x80 *)
			ELSE
				out.Char(CHR(payloadLen));
			END;
		ELSIF payloadLen < 65536 THEN
			IF masked THEN out.Char(CHR(0xFE)); (* 126|0x80 *)
			ELSE out.Char(CHR(126));
			END;
			out.Net16(SIGNED16(payloadLen));
		ELSE
			IF masked THEN out.Char(CHR(0xFF)); (* 127|0x80 *)
			ELSE out.Char(CHR(127));
			END;
			out.Net64(payloadLen);
		END;
	END WritePayloadLen;

	(** Write the header of an unmasked frame

		out : output stream writer
		final : TRUE if this is the final fragment of the current message
		opcode : frame opcode
		payloadLen : frame payload data length in bytes
	*)
	PROCEDURE WriteHeader*(out: Streams.Writer; final: BOOLEAN; opcode: Opcode; payloadLen: SIZE);
	BEGIN
		IF final THEN
			out.Char(CHR(SIGNED8(SET8(SIGNED8(opcode))+SET8(0x80))));
		ELSE
			out.Char(CHR(SIGNED8(opcode)));
		END;
		WritePayloadLen(out, payloadLen, FALSE);
	END WriteHeader;

	(** Write the header of a masked frame

		out : output stream writer
		final : TRUE if this is the final fragment of the current message
		opcode : frame opcode
		payloadLen : frame payload data length in bytes
		mask : pseudorandom frame data mask
	*)
	PROCEDURE WriteHeaderMasked*(out: Streams.Writer; final: BOOLEAN; opcode: Opcode; payloadLen: SIZE; CONST mask: ARRAY 4 OF CHAR);
	BEGIN
		WriteHeader(out, final, opcode, payloadLen);
		out.Bytes(mask, 0, 4);
	END WriteHeaderMasked;

	(** Write paylod data of a masked frame

		out : output stream writer
		data : payload data array
		dataOffs : data offset position
		dataLen : payload data length in bytes
		mask : pseudorandom frame data mask
		maskPos : mask byte index
		buf : buffer used for masking
	*)
	PROCEDURE WritePayloadMasked*(
													out: Streams.Writer;
													CONST data: ARRAY OF CHAR;
													dataOffs, dataLen: SIZE;
													CONST mask: ARRAY 4 OF CHAR;
													VAR maskPos: INTEGER;
													VAR buf: ARRAY OF CHAR
													);
	BEGIN
		WHILE dataLen > 0 DO
			VAR n := MIN(dataLen, LEN(buf));
			VAR k := 0: SIZE;
			WHILE k < n DO
				buf[k] := CHR(SIGNED8(SET8(ORD(data[dataOffs])) / SET8(ORD(mask[maskPos MOD 4]))));
				INC(k); INC(dataOffs); INC(maskPos);
			END;
			out.Bytes(buf, 0, n);
			DEC(dataLen, n);
		END;
	END WritePayloadMasked;

	(** Write an unmasked frame

		out : output stream writer
		final : TRUE if this is the final fragment of the current message
		opcode : frame opcode
		data : payload data array
		dataOffs : data offset position
		dataLen : payload data length in bytes
	*)
	PROCEDURE WriteFrame*(
										out: Streams.Writer;
										final: BOOLEAN;
										opcode: Opcode;
										CONST data: ARRAY OF CHAR;
										dataOffs, dataLen: SIZE
										);
	BEGIN
		WriteHeader(out, final, opcode, dataLen);
		IF dataLen # 0 THEN
			out.Bytes(data, dataOffs, dataLen);
		END;
	END WriteFrame;

	(** Write a masked frame

		out : output stream writer
		final : TRUE if this is the final fragment of the current message
		opcode : frame opcode
		data : payload data array
		dataOffs : data offset position
		dataLen : payload data length in bytes
		mask : pseudorandom frame data mask
		buf : buffer used for data masking
	*)
	PROCEDURE WriteFrameMasked*(
													out: Streams.Writer;
													final: BOOLEAN;
													opcode: Opcode;
													CONST data: ARRAY OF CHAR;
													dataOffs, dataLen: SIZE;
													CONST mask: ARRAY 4 OF CHAR;
													VAR buf: ARRAY OF CHAR
													);
	BEGIN
		WriteHeaderMasked(out, final, opcode, dataLen, mask);
		IF dataLen # 0 THEN
			VAR maskPos := 0: INTEGER;
			WritePayloadMasked(out, data, dataOffs, dataLen, mask, maskPos, buf);
		END;
	END WriteFrameMasked;

	(** Write an unmasked close frame

		out : output stream writer
		status : close status code
		reason : a null-terminated closing reason string
	*)
	PROCEDURE WriteClose*(out: Streams.Writer; status: CloseStatus; CONST reason: ARRAY OF CHAR);
	BEGIN
		VAR reasonLen := Strings.Length(reason);
		WriteHeader(out, TRUE, Opcode.Close, 2+reasonLen);
		out.Net16(SIGNED16(status));
		IF reasonLen # 0 THEN
			out.Bytes(reason, 0, reasonLen);
		END;
	END WriteClose;

	(** Write a masked close frame

		out : output stream writer
		status : close status code
		reason : a null-terminated closing reason string
		mask : pseudorandom frame data mask
		buf : buffer used for data masking
	*)
	PROCEDURE WriteCloseMasked*(
															out: Streams.Writer;
															status: CloseStatus;
															CONST reason: ARRAY OF CHAR;
															CONST mask: ARRAY 4 OF CHAR;
															VAR buf: ARRAY OF CHAR
															);
	BEGIN
		VAR reasonLen := Strings.Length(reason);
		WriteHeaderMasked(out, TRUE, Opcode.Close, 2+reasonLen, mask);
		VAR statusBytes: ARRAY 2 OF CHAR;
		statusBytes[0] := CHR(LSH(SIGNED16(status),-8));
		statusBytes[1] := CHR(SIGNED16(status));
		VAR maskPos  := 0: INTEGER;
		WritePayloadMasked(out, statusBytes, 0, 2, mask, maskPos, buf);
		IF reasonLen # 0 THEN
			WritePayloadMasked(out, reason, 0, reasonLen, mask, maskPos, buf);
		END;
	END WriteCloseMasked;

VAR
	serverPlugin: ServerPlugin;

	(** Install the WebSocket server plugin on a running WebHTTP server *)
	PROCEDURE InstallPlugin*(ctx: Commands.Context);
	BEGIN
		VAR hl := WebHTTPServer.FindHosts("");
		hl.host.AddPlugin(serverPlugin);
		ctx.out.String("WebSocketPlugin support installed to default host"); ctx.out.Ln;

		hl := WebHTTPServer.FindHosts("*");
		WHILE hl # NIL DO
			hl.host.AddPlugin(serverPlugin);
			ctx.out.String("WebSocketPlugin support installed to "); ctx.out.String(hl.host.name); ctx.out.Ln;
			hl := hl.next
		END;
	END InstallPlugin;

	PROCEDURE TerminateMod;
	BEGIN
		VAR hl := WebHTTPServer.FindHosts("");
		hl.host.RemovePlugin(serverPlugin);

		hl := WebHTTPServer.FindHosts("*");
		WHILE hl # NIL DO
			hl.host.RemovePlugin(serverPlugin);
			hl := hl.next
		END;
	END TerminateMod;

	PROCEDURE SetEndpoint*(CONST pathPrefix: ARRAY OF CHAR; handler: EndpointHandler; CONST description: ARRAY OF CHAR);
	BEGIN
		serverPlugin.SetEndpoint(pathPrefix, handler, description);
	END SetEndpoint;

	PROCEDURE RemoveEndpoint*(CONST pathPrefix: ARRAY OF CHAR): BOOLEAN;
	BEGIN
		RETURN serverPlugin.RemoveEndpoint(pathPrefix);
	END RemoveEndpoint;

	(** list all installed WebSocket endpoints *)
	PROCEDURE ListEndpoints*(ctx: Commands.Context);
	BEGIN
		ASSERT(serverPlugin # NIL);
		serverPlugin.ListEndpoints(ctx.out);
	END ListEndpoints;
(*
	PROCEDURE TestEndpoint(CONST path: ARRAY OF CHAR; VAR conn: Connection);
	VAR
		res: INTEGER;
		buf: ARRAY 256 OF CHAR;
		n: SIZE;
	BEGIN
		conn.SetDataMode(FALSE);
		conn.Send("hello ", 0, 6, FALSE, res);
		conn.Send("there!", 0, 6, FALSE, res);
		conn.Send("", 0, 0, TRUE, res);
		TRACE(res);

		(*conn.Receive(buf, 0, LEN(buf), LEN(buf), n, res);
		TRACE(n, res, buf, INTEGER(conn.state));*)

		conn.Close(CloseStatus.GoingAway, "endpoint exiting");
		TRACE(INTEGER(conn.state));
		conn.Receive(buf, 0, LEN(buf), LEN(buf), n, res);
		TRACE(n, res, buf, INTEGER(conn.state));
	END TestEndpoint;

	PROCEDURE InstallTestEndpoint*;
	BEGIN
		serverPlugin.SetEndpoint("/test", TestEndpoint, "test WebSocket endpoint");
	END InstallTestEndpoint;
*)
BEGIN
	NEW(serverPlugin,"WebSocketPlugin");
	Modules.InstallTermHandler(TerminateMod);
END WebSockets.

FoxTest.Compile	-l=Test.Log WebSockets.Execution.Test ~

WebHTTPServerTools.Start \s:on \r:httproot \l:WebHTTP.Log ~
WebHTTPServerTools.Stop ~

WebSockets.InstallPlugin ~

System.FreeDownTo WebHTTP ~
System.FreeDownTo TLS ~

