(* Copyright 2005-2006, Markus Heule, ETH Zurich *)

MODULE OSCService;  (** AUTHOR "heulemar"; PURPOSE "OpenSoundControl: OSC Service (scheduler)"; *)

(*
	This module contains an OSCService. This active object receives OSCPackets from other active objects like the networkplugins,
	stores them if necessary in an internal OSCQueue. The messages are eventually executed through the OSCRegistry supplied during
	construction of this object.

	If you are using this service object, it's now very simple to create an OSC Server. You can even configure multiple network
	plugins to serve packets to this service.

	1. Create a OSCRegistry.
	2. Register all your client procedures with the corresponding address in the registry.
	3. Create a new OSCService with your registry.
	4. Create one or more networkplugins with your service.

	If you want to stop your osc service, stop first all netowrk plugins with their 'Stop'-function. After you can stop
	the service also with the 'Stop'-function.

*)

IMPORT
	OSC, OSCRegistry, OSCQueue, KernelLog, Objects;

CONST
	Trace* = FALSE;

TYPE

	OSCService* = OBJECT
		VAR
			reg: OSCRegistry.OSCRegistry; (* the associated registry with this service *)
			q: OSCQueue.OSCQueue; (* the queue to store the OSCBundles for later execution *)

			newpacket: OSC.OSCPacket; (* buffer with one packet *)
			gotpacket: BOOLEAN; (* specifies the state of the buffer *)

			stopping:  BOOLEAN; (* flag to stop the service *)

			processing: OSC.OSCPacket;
			queuetimer: Objects.Timer;
			queuetimeout: BOOLEAN;

			(* internal variables *)
			storedbundleready: BOOLEAN;
			storedbundle: OSC.OSCBundle;


		PROCEDURE &Init*(reg: OSCRegistry.OSCRegistry);
		BEGIN
			SELF.reg := reg;
			NEW(q);
			NEW(queuetimer);
			gotpacket := FALSE;
			stopping := FALSE;
			queuetimeout := FALSE;
		END Init;

		(* stores a new packet in the buffer. notifies the main function with the gotpacket-flag. *)
		PROCEDURE NewPacket*(p: OSC.OSCPacket);
		BEGIN { EXCLUSIVE }
			AWAIT(~gotpacket OR stopping); (* wait until the buffer is empty *)
			IF stopping THEN RETURN; END;
			newpacket := p;
			gotpacket := TRUE;
		END NewPacket;

		(* sets the flag to stop the service *)
		PROCEDURE Stop*;
		BEGIN { EXCLUSIVE }
			stopping := TRUE;
		END Stop;

		(* when an timer of the queue expires, this function is executed to notify the main-function *)
		PROCEDURE queueTimeout;
		BEGIN { EXCLUSIVE }
			queuetimeout := TRUE;
		END queueTimeout;

		(* updates the timer with the timeout of the first message. This is also used to refresh the timer, when
			an timeout cannot be expressed in a LONGINT. (~ 24days) *)
		PROCEDURE updateTimer;
		VAR
			b: OSC.OSCBundle;
			bundletimeout: LONGINT;
		BEGIN
			b := q.Peek();
			bundletimeout := b.GetTimeout();
			queuetimeout := FALSE;
			Objects.SetTimeout(queuetimer, queueTimeout, bundletimeout);
		END updateTimer;

		PROCEDURE processPacket(processing: OSC.OSCPacket);
		BEGIN
			IF processing IS OSC.OSCMessage THEN
				WITH processing: OSC.OSCMessage DO
					reg.Run(processing);
				END;
			ELSIF processing IS OSC.OSCBundle THEN
				WITH processing: OSC.OSCBundle DO
					q.Queue(processing);
				END;
			ELSE (* unknown packet class *)
				KernelLog.String('OSCServer: Recieved unknown OSCPacket-Subclass'); KernelLog.Ln;
			END;
		END processPacket;

		(* Every OSCBundle is processed with this function. This ensures the atomicity of an OSCBundle *)
		PROCEDURE processBundle(b: OSC.OSCBundle);
		VAR
			i: SIZE;
		BEGIN
			FOR i:=0 TO b.messagescount-1 DO
				processPacket(b.messages[i]);
			END;
		END processBundle;

	BEGIN {ACTIVE}
			IF Trace THEN KernelLog.String('OSCService started'); KernelLog.Ln; END;
			REPEAT
				(* check if an stored bundle is ready *)
				storedbundleready := FALSE;
				IF ~q.IsEmpty() THEN
					storedbundle := q.Peek();
					IF Trace THEN KernelLog.String('Stored Bundle has timeout of '); KernelLog.Int(storedbundle.GetTimeout(),10); KernelLog.Ln; END;
					IF storedbundle.GetTimeout() = 0 THEN
						storedbundleready := TRUE;
					END;
				END;
				(* process first stored bundle, if one is ready *)
				IF storedbundleready THEN
					storedbundle := q.Dequeue();
					processBundle(storedbundle);
				(* if none was ready, process a newly received packet *)
				ELSIF gotpacket THEN
					(* we got a new packet. Store the new packet in processing to release the buffer as soon as possible *)
					BEGIN { EXCLUSIVE }
						gotpacket := FALSE;
						processing := newpacket;
					END;
					processPacket(processing);
				ELSE (* we havn't processed any packet *)
					BEGIN { EXCLUSIVE }
						IF q.IsEmpty() THEN
							AWAIT(gotpacket OR stopping); (* if no packet is queued wait for a new packet or the stop signal *)
						ELSE
							updateTimer;
							(* wait for a timeout of the queue, a new packet or the stop signal *)
							AWAIT(queuetimeout OR gotpacket OR stopping);
						END;
					END;
				END;
			UNTIL stopping;
			(* cleanup *)
			Objects.CancelTimeout(queuetimer);
			IF Trace THEN KernelLog.String('OSCService stopped'); KernelLog.Ln; END;
	END OSCService;


	(* these global variables are only used for the testing function *)
	(*
	VAR
		ts: OSCService;
		reg: OSCRegistry.OSCRegistry;

	PROCEDURE TestService*(ptr: ANY): ANY;
	BEGIN
		NEW(reg);
		NEW(ts, reg);
		RETURN NIL;
	END TestService;

	PROCEDURE EndTestService*(ptr: ANY): ANY;
	BEGIN
		ts.Stop;
		RETURN NIL;
	END EndTestService; *)

END OSCService.

(*
	System.Free OSCService ~
	OSCService.TestService ~
	OSCService.EndTestService ~
*)
