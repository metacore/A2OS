MODULE Performance;

	VAR
		load*: ARRAY 3 OF FLOAT32;	(* load estimates *)
		idle*: ARRAY 1 OF SIGNED32;	(* idle percentage estimates *)
BEGIN
	idle[0] := -1;
END Performance.

(*
Notes:
o "load" is a Unix-like estimate of the average number of ready and running processes over the past 1, 5 and 15 minutes.
o "idle" is an estimate of the percentage of idle time per processor over the last 10 seconds.
o When a processor is not available, its idle estimate is -1.
*)