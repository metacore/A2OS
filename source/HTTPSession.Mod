MODULE HTTPSession; (** AUTHOR "Luc Blaeser/cs"; PURPOSE "HTTP Session Management";
	code parts from CSHTTPSupport of "cs" *)

IMPORT HTTPSupport, WebHTTP, MD5, IP, Random, Dates, Strings, TFClasses, Kernel, Modules, KernelLog;

CONST
	(** variable name for the sesiion id in the HTTP request *)
	HTTPVarSessionIdName* = "sessionid";

	(* in units of LeaseManagerInterval *)
	InitialLeaseTime = 5.0;
	LeaseTimeIncrement = 2.0;
	MaxLeaseTime = 15.0; (* 15 min *)
	LeaseManagerInterval = 60*1000; (* 1 min *)

TYPE
	SessionId* = ARRAY 80 OF CHAR; (** fixed length for session id *)

	(** name must be unique for all variables for a session *)
	SessionVariable* = POINTER TO RECORD
		name*: Strings.String;
		value*: ANY
	END;

	Session* = OBJECT (** client activated object by leasing concept *)
		VAR
			sessionId*: SessionId;
			sessionVariables*: TFClasses.List; (** List of SessionVariable *)
			leaseTime*: FLOAT32;

		PROCEDURE &Init*(sessionId: SessionId);
		BEGIN
			COPY(sessionId, SELF.sessionId);
			NEW(sessionVariables);
			leaseTime :=  InitialLeaseTime
		END Init;

		PROCEDURE GetVariableValue*(name: ARRAY OF CHAR) : ANY;
		VAR var: SessionVariable;
		BEGIN
			var := GetVariableByName(name);
			IF (var # NIL) THEN
				RETURN var.value
			ELSE
				RETURN NIL
			END
		END GetVariableValue;

		(** returns NIL if the session variable is not present *)
		PROCEDURE GetVariableByName*(name: ARRAY OF CHAR) : SessionVariable;
			VAR p: ANY; i : SIZE; var: SessionVariable;
		BEGIN
			sessionVariables.Lock;
			FOR i := 0 TO sessionVariables.GetCount()-1 DO
				p := sessionVariables.GetItem(i); var := p(SessionVariable); (* var # NIL *)
				IF (var.name^ = name) THEN
					sessionVariables.Unlock;
					RETURN var
				END
			END;
			sessionVariables.Unlock;
			RETURN NIL
		END GetVariableByName;

		PROCEDURE AddVariableValue*(name: ARRAY OF CHAR; value: ANY);
		VAR var: SessionVariable;
		BEGIN
			(* avoid multiple occurrences of the same variable *)
			var := GetVariableByName(name);
			IF (var # NIL) THEN
				sessionVariables.Remove(var)
			END;
			NEW(var); NEW(var.name, Strings.Length(name)+1);
			COPY(name, var.name^); var.value := value;
			sessionVariables.Add(var)
		END AddVariableValue;

		PROCEDURE RemoveVariable*(name: ARRAY OF CHAR);
		VAR var: SessionVariable;
		BEGIN
			var := GetVariableByName(name);
			IF (var # NIL) THEN
				sessionVariables.Remove(var)
			END
		END RemoveVariable;

		PROCEDURE IncreaseLifeTime*;
		BEGIN {EXCLUSIVE}
			leaseTime := leaseTime + LeaseTimeIncrement;
			IF (leaseTime > MaxLeaseTime) THEN leaseTime := MaxLeaseTime END
		END IncreaseLifeTime;
	END Session;

	SessionExpirationHandler* = PROCEDURE {DELEGATE} (session: Session);

	(* checks whether certain session have to be freed *)
	LeaseManager = OBJECT
		VAR timer: Kernel.Timer; i, j: SIZE; pSession, pHandler: ANY; s: Session;
			expiredSessions: TFClasses.List; alive, dead: BOOLEAN; expObj: ExpirationHandlerObject;

		PROCEDURE Kill*;
		BEGIN
			BEGIN {EXCLUSIVE}
				alive := FALSE;
			END;
			timer.Wakeup;
		END Kill;

		PROCEDURE SetDead;
		BEGIN {EXCLUSIVE}
			dead:=TRUE
		END SetDead;

		PROCEDURE WaitDead*;
		BEGIN {EXCLUSIVE}
			AWAIT(dead)
		END WaitDead;

	BEGIN {ACTIVE}
		KernelLog.String("Session.LeaseManager started."); KernelLog.Ln;
		NEW(timer); NEW(expiredSessions); alive := TRUE; (*terminated := FALSE;*)
		WHILE (alive) DO
			(* Session.LeaseManager looks for expired sessions *)

			(* search expired sessions *)
			sessions.Lock;
			expiredSessions.Clear;
			FOR i:= 0 TO sessions.GetCount()-1 DO
				pSession := sessions.GetItem(i); s := pSession(Session); (* s # NIL *)
				BEGIN {EXCLUSIVE}
					IF (s.leaseTime <= 1.0) THEN
						expiredSessions.Add(s)
					ELSE
						s.leaseTime := s.leaseTime-1
						(* ;KernelLog.String("Session "); KernelLog.String(s.sessionId); KernelLog.String(" stays alive for ");
						KernelLog.Int(ENTIER(s.leaseTime), 0); KernelLog.String(" minutes."); KernelLog.Ln *)
					END
				END
			END;
			sessions.Unlock;
			FOR i := 0 TO expiredSessions.GetCount()-1 DO
				pSession := expiredSessions.GetItem(i); s := pSession(Session); (* s # NIL *)
				sessions.Remove(s);
			(*	KernelLog.String("Session "); KernelLog.String(s.sessionId); KernelLog.String(" expired."); KernelLog.Ln; *)

				expirationHandlers.Lock;
				FOR j := 0 TO expirationHandlers.GetCount()-1 DO
					pHandler := expirationHandlers.GetItem(j); expObj := pHandler(ExpirationHandlerObject); (* expObj # NIL *)
					expObj.handler(s)
					(* the handler is not allowed to call AddExpirationHandler or
					    RemoveExpirationHandler since this provokes a deadlock *)
				END;
				expirationHandlers.Unlock
			END;

			(* Session.LeaseManager suspends. *)
			timer.Sleep(LeaseManagerInterval)
		END;
		(* Session.LeaseManager terminated. *)
		SetDead
		(* terminated := TRUE*)
	END LeaseManager;

	ExpirationHandlerObject = POINTER TO RECORD
		handler: SessionExpirationHandler
	END;

VAR
	sessions: TFClasses.List; (* List of Session *)
	expirationHandlers: TFClasses.List; (* List of ExpirationHandlerPtr *)
	leaseManager: LeaseManager;
	randomSequence: Random.Sequence;
	date, time: SIGNED32;

	PROCEDURE GetSessionId*(request: HTTPSupport.HTTPRequest; VAR sessionId: SessionId);
	VAR s: Session;
	BEGIN
		s := GetSession(request);
		COPY(s.sessionId, sessionId)
	END GetSessionId;

	(** looks for an existing session object of the client - returns NIL IF not existing*)
	PROCEDURE GetExistingSession*(request: HTTPSupport.HTTPRequest) : Session;
	VAR var : HTTPSupport.HTTPVariable; id: SessionId; sess : Session;
	BEGIN {EXCLUSIVE} (* request # NIL *)
		var := request.GetVariableByName(HTTPVarSessionIdName);
		sess := NIL;
		IF (var # NIL) THEN
			COPY(var.value, id);
			sess := FindSessionBySessionId(id)
		END;
		RETURN sess
	END GetExistingSession;

	(** looks for an existing session object of the client - if no matching session object is present
		then a new session will be created *)
	PROCEDURE GetSession*(request: HTTPSupport.HTTPRequest) : Session;
	VAR var : HTTPSupport.HTTPVariable; id: SessionId; sess : Session;
	BEGIN {EXCLUSIVE} (* request # NIL *)
		var := request.GetVariableByName(HTTPVarSessionIdName);
		IF (var # NIL) THEN
			COPY(var.value, id);
			sess := FindSessionBySessionId(id);
			IF (sess = NIL) THEN
				(* leasing expired, create a new session *)
				NEW(sess, id); sessions.Add(sess);
			END
		ELSE
			NewSessionId(request.header, id);
			NEW(sess, id); sessions.Add(sess);
			(* add the new session id variable to the HTTP request *)
			NEW(var);
			COPY(HTTPVarSessionIdName, var.name); COPY(id, var.value);
			request.variables.Add(var)
		END;
		RETURN sess
	END GetSession;

	PROCEDURE FindSessionBySessionId(sessionId: SessionId) : Session;
	VAR i: SIZE; p: ANY; sess: Session;
	BEGIN
		sessions.Lock;
		FOR i := 0 TO sessions.GetCount()-1 DO
			p := sessions.GetItem(i); sess := p(Session); (* sess # NIL *)
			IF (sess.sessionId = sessionId) THEN
				sessions.Unlock;
				RETURN sess
			END
		END;
		sessions.Unlock;
		RETURN NIL
	END FindSessionBySessionId;

	(** Creates a new Session Id. The Session ID is unique and consists of an MD5 Hash of the client IP,
		the date and time and a random component. by "cs" *)
	PROCEDURE NewSessionId(header: WebHTTP.RequestHeader; VAR sessionId: SessionId);
	VAR
		i: SIZE;
		buffer1,buffer2: POINTER TO ARRAY OF CHAR;
		context: MD5.Context;
		digest: MD5.Digest;
		date,time: SIGNED32;
	BEGIN
		NEW(buffer1,16384);
		NEW(buffer2,16384);
		IP.AdrToStr(header.fadr,buffer1^);
		i := Strings.Length(buffer1^);
		buffer1^[i] := "-";
		buffer1^[i+1] := 0X;
		Dates.DateTimeToOberon(Dates.Now(), date, time);
		Strings.IntToStr(8192*date+time,buffer2^); (* some continuous number *)
		Strings.Append(buffer1^,buffer2^);
		Strings.IntToStr(randomSequence.Integer(),buffer2^); (* some random number *)
		Strings.Append(buffer1^,buffer2^);
		context := MD5.New();
		MD5.WriteBytes(context,buffer1^,Strings.Length(buffer1^));
		MD5.Close(context,digest);
		MD5.ToString(digest,sessionId)
	END NewSessionId;

	PROCEDURE AddExpirationHandler*(handler: SessionExpirationHandler);
	VAR expObj: ExpirationHandlerObject;
	BEGIN {EXCLUSIVE}
		NEW(expObj); expObj.handler := handler;
		expirationHandlers.Add(expObj);
	END AddExpirationHandler;

	PROCEDURE RemoveExpirationHandler*(handler: SessionExpirationHandler);
	VAR expObj, delObj: ExpirationHandlerObject; p: ANY; i : SIZE;
	BEGIN {EXCLUSIVE}
		delObj := NIL;
		expirationHandlers.Lock;
		FOR i := 0 TO expirationHandlers.GetCount()-1 DO
			p := expirationHandlers.GetItem(i); expObj := p(ExpirationHandlerObject); (* expObj # NIL *)
			IF (expObj.handler = handler) THEN delObj := expObj END
		END;
		expirationHandlers.Unlock;
		IF (delObj # NIL) THEN
			expirationHandlers.Remove(delObj)
		END
	END RemoveExpirationHandler;

	PROCEDURE StopLeaseManager*;
	BEGIN
		IF (leaseManager # NIL) THEN
			leaseManager.Kill;
			leaseManager.WaitDead;
		END
	END StopLeaseManager;

	PROCEDURE StartLeaseManager*;
	BEGIN {EXCLUSIVE}
		IF (leaseManager = NIL) THEN
			NEW(leaseManager)
		END
	END StartLeaseManager;

BEGIN
	NEW(sessions); NEW(expirationHandlers);
	(* init random sequence for session id *)
	NEW(randomSequence);
	Dates.DateTimeToOberon(Dates.Now(), date, time);
	randomSequence.InitSeed(time);
	StartLeaseManager;
	Modules.InstallTermHandler(StopLeaseManager)
END HTTPSession.

System.Free HTTPSession~
HTTPSession.StopLeaseManager
HTTPSession.StartLeaseManager
