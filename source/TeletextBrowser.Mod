MODULE TeletextBrowser;	(** AUTHOR "oljeger@student.ethz.ch"; PURPOSE "Browsing Interface for Aos Teletext" *)

IMPORT
	TeletextDecoder, KernelLog;

CONST
	VbiUndefined = TeletextDecoder.VbiUndefined;

TYPE
	(** Container for a teletext page in markup form. Concrete implementation will contain
		  Texts.Text or HTML content *)
	TeletextPage* = OBJECT
	END TeletextPage;

	(** Procedure that creates markup content and returns it *)
	LoadProc* = PROCEDURE{DELEGATE}() : TeletextPage;

	(** Generic teletext browser *)
	TeletextBrowser* = OBJECT
	VAR
		page-, subPage: SIZE;
		suite-: TeletextDecoder.TeletextSuite;
		pgSet: TeletextDecoder.TeletextPageSet;
		pgData*: TeletextDecoder.TeletextPage;
		content*: TeletextPage;
		channel-: ARRAY 33 OF CHAR;
		refreshInterval*: LONGINT;
		rotating*: BOOLEAN;
		transparent*: BOOLEAN;
		loadProc*: LoadProc;

		PROCEDURE &Init*(suite: TeletextDecoder.TeletextSuite);
		BEGIN
			IF suite = NIL THEN
				KernelLog.String("{TeletextBrowser.Init} Parameter 'suite' = NIL"); KernelLog.Ln;
				RETURN
			END;
			SELF.suite := suite;
			COPY(suite.channel.name, channel);
			page := 0;
			pgSet := suite.pages[page];
			pgData := pgSet.data;
			IF pgData # NIL THEN
				subPage := pgData.subPageNo
			END
		END Init;

		(** Does the current page have any subpages? *)
		PROCEDURE HasSubpages*() : BOOLEAN;
		BEGIN
			IF pgData = NIL THEN
				RETURN FALSE
			END;
			RETURN pgData # pgData.nextSub
		END HasSubpages;

		(** Select another teletext suite for browsing *)
		PROCEDURE SetSuite*(suite: TeletextDecoder.TeletextSuite);
		BEGIN
			Init(suite)
		END SetSuite;

		(** Select another teletext suite for browsing according to the given TV frequency *)
		PROCEDURE SetSuiteFromFreq*(freq: LONGINT);
		BEGIN
			Init(TeletextDecoder.SelectTeletextSuite(freq))
		END SetSuiteFromFreq;

		(** Reload the current teletext page *)
		PROCEDURE ReloadPage*() : TeletextPage;
		VAR
			sub: SIZE;
			tmp: TeletextPage;
		BEGIN
			sub := subPage;
			BEGIN {EXCLUSIVE}
				pgData := pgSet.data
			END;
			WHILE (pgData # NIL) & (sub # pgData.subPageNo) DO
				tmp := GetNextSubpage()
			END;
			RETURN loadProc()
		END ReloadPage;

		(** Get the next valid teletext page *)
		PROCEDURE GetNextPage*() : TeletextPage;
		BEGIN
			page := pgSet.next;
			IF page = VbiUndefined THEN
				RETURN NIL
			END;
			pgSet := suite.pages[page];
			BEGIN {EXCLUSIVE}
				pgData := pgSet.data
			END;
			IF pgData # NIL THEN
				subPage := pgData.subPageNo
			END;
			RETURN loadProc()
		END GetNextPage;

		(** Get the previous valid teletext page *)
		PROCEDURE GetPreviousPage*() : TeletextPage;
		BEGIN
			page := pgSet.prev;
			IF page = VbiUndefined THEN
				RETURN NIL
			END;
			pgSet := suite.pages[page];
			BEGIN {EXCLUSIVE}
				pgData := pgSet.data
			END;
			IF pgData # NIL THEN
				subPage := pgData.subPageNo
			END;
			RETURN loadProc()
		END GetPreviousPage;

		(** Get the next subpage *)
		PROCEDURE GetNextSubpage*() : TeletextPage;
		BEGIN
			IF pgData = NIL THEN
				RETURN NIL
			END;
			BEGIN {EXCLUSIVE}
				pgData := pgData.nextSub
			END;
			subPage := pgData.subPageNo;
			RETURN loadProc()
		END GetNextSubpage;

		(** Get the previous subpage *)
		PROCEDURE GetPreviousSubpage*() : TeletextPage;
		BEGIN
			IF pgData = NIL THEN
				RETURN NIL
			END;
			BEGIN {EXCLUSIVE}
				pgData := pgData.prevSub
			END;
			subPage := pgData.subPageNo;
			RETURN loadProc()
		END GetPreviousSubpage;

		(** Get a teletext page by number. page is in range 100-899 *)
		PROCEDURE GetPage*(page: SIZE) : TeletextPage;
		BEGIN
			page := page - 100;
			SELF.page := page;
			IF (page < 0) OR (page >= 800) OR (suite = NIL) OR (suite.pages[page].data = NIL) THEN
				BEGIN {EXCLUSIVE}
					pgData := NIL
				END
			ELSE
				pgSet := suite.pages[page];
				BEGIN {EXCLUSIVE}
					pgData := pgSet.data
				END;
				subPage := pgData.subPageNo
			END;
			RETURN loadProc()
		END GetPage;

	END TeletextBrowser;

END TeletextBrowser.


System.Free TeletextBrowser ~
