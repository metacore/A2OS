(* OBERON System 3, Release 2.3.

Copyright 1999 ETH Zürich Institute for Computer Systems,
ETH Center, CH-8092 Zürich.  e-mail: oberon@inf.ethz.ch.

This module may be used under the conditions of the general Oberon
System 3 license contract.  The full text can be downloaded from

	"ftp://ftp.inf.ethz.ch/pub/software/Oberon/System3/license.txt;A"

Under the license terms stated it is in particular (a) prohibited to modify
the interface of this module in any way that disagrees with the style
or content of the system and (b) requested to provide all conversions
of the source code to another platform with the name OBERON. *)

MODULE ODBC; (** non-portable / source: Windows.ODBC.Mod *)

IMPORT S:= SYSTEM, Kernel32, Modules;

CONST
	MAXMESSAGELENGTH = 512;
	NTS = -3;

TYPE
	HENV = POINTER TO HENVDesc;
	HENVDesc = RECORD
			henv: Kernel32.HANDLE;
		END;

	HDBC* = POINTER TO HDBCDesc;
	HDBCDesc* = RECORD
			hdbc: Kernel32.HANDLE;
		END;

	HSTMT* = POINTER TO HSTMTDesc;
	HSTMTDesc* = RECORD
			hstmt: Kernel32.HANDLE;
		END;

(*
	type conversion C to Oberon:
		UWORD / SWORD	->	SIGNED16
		UDWORD / SDWORD	->	SIGNED32
*)

VAR
	lib: ADDRESS;
	env: HENV;

	res1*: SIGNED16;
	nullString-: ARRAY 1 OF CHAR;

(*	Core Functions Prototypes	*)

	SQLAllocConnect: PROCEDURE {WINAPI} (
		henv: Kernel32.HANDLE;
		hdbc: ADDRESS): SIGNED16;

	SQLAllocEnv: PROCEDURE {WINAPI} (
		henv: Kernel32.HANDLE): SIGNED16;

	SQLAllocStmt: PROCEDURE {WINAPI} (
		hdbc: ADDRESS;
		hstmt: Kernel32.HANDLE): SIGNED16;

	SQLBindCol: PROCEDURE {WINAPI} (
		hstmt: ADDRESS;
		icol: SIGNED16;
		fcType: SIGNED16;
		rgbValue: ADDRESS;
		cbValueMax: SIGNED32;
		pcbValue: ADDRESS): SIGNED16;

	SQLCancel: PROCEDURE {WINAPI} (
		hstmt: ADDRESS): SIGNED16;

	SQLColAttributes: PROCEDURE {WINAPI} (
		hstmt: ADDRESS;
		icol: SIGNED16;
		fDescType: SIGNED16;
		rgbDesc: ADDRESS;
		cbDescMax: SIGNED16;
		pcbDesc: ADDRESS;
		pfDesc: ADDRESS): SIGNED16;

	SQLConnect: PROCEDURE {WINAPI} (
		hdbc: ADDRESS;
		DSN: ADDRESS;
		DSNMax: SIGNED16;
		UID: ADDRESS;
		UIDMax: SIGNED16;
		AuthStr: ADDRESS;
		AuthStrMax: SIGNED16): SIGNED16;

	SQLDescribeCol: PROCEDURE {WINAPI} (
		hstmt: ADDRESS;
		icol: SIGNED16;
		szColName: ADDRESS;
		cbColNameMax: SIGNED16;
		pcbColName: ADDRESS;
		pfSqlType: ADDRESS;
		pcbColDef: ADDRESS;
		pibScale: ADDRESS;
		pfNullable: ADDRESS): SIGNED16;

	SQLDisconnect: PROCEDURE {WINAPI} (
		hdbc: Kernel32.HANDLE): SIGNED16;

	SQLError: PROCEDURE {WINAPI} (
		henv: ADDRESS;
		hdbc: Kernel32.HANDLE;
		hstmt: Kernel32.HANDLE;
		szSqlState: ADDRESS;
		pfNativeError: ADDRESS;
		szErrorMessage: ADDRESS;
		cbErrorMessage: SIGNED16;
		pcbErrorMessage: ADDRESS): SIGNED16;

	SQLExecDirect: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		szSqlStr: ADDRESS;
		cbSqlStr: SIGNED16): SIGNED16;

	SQLExecute: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE): SIGNED16;

	SQLFetch: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE): SIGNED16;

	SQLFreeConnect: PROCEDURE {WINAPI} (
		hdbc: Kernel32.HANDLE): SIGNED16;

	SQLFreeEnv: PROCEDURE {WINAPI} (
		henv: ADDRESS): SIGNED16;

	SQLFreeStmt: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		fOption: SIGNED16): SIGNED16;

	SQLGetCursorName: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		szCursor: ADDRESS;
		cbCursorMax: SIGNED16;
		pcbCursor: ADDRESS): SIGNED16;

	SQLNumResultCols: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		pccol: ADDRESS): SIGNED16;

	SQLPrepare: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		szSqlStr: ADDRESS;
		cbSqlStr: ADDRESS): SIGNED16;

	SQLRowCount: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		pcrow: ADDRESS): SIGNED16;

	SQLSetCursorName: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		szCursor: ADDRESS;
		cbCursor: SIGNED16): SIGNED16;

	SQLTransact: PROCEDURE {WINAPI} (
		henv: ADDRESS;
		hdbc: Kernel32.HANDLE;
		fType: SIGNED16): SIGNED16;

(*	Level 1 Functions	*)

	SQLColumns: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		tableQualifier: ADDRESS;
		qualLen: SIGNED16;
		tableOwner: ADDRESS;
		ownerLen: SIGNED16;
		tableName: ADDRESS;
		nameLen: SIGNED16;
		columnName: ADDRESS;
		colNameLen: SIGNED16): SIGNED16;

	SQLDriverConnect: PROCEDURE {WINAPI} (
		hdbc: Kernel32.HANDLE;
		hwnd: ADDRESS;
		connStrIn: ADDRESS;
		connStrInLen: SIGNED16;
		connStrOut: ADDRESS;
		connStrOutMaxSize: SIGNED16;
		connStrOutActSize: ADDRESS;	(* address of integer containig result len *)
		driverCompletion: SIGNED16): SIGNED16;

	SQLGetConnectOption: PROCEDURE {WINAPI} (
		hdbc: Kernel32.HANDLE;
		whatOption: SIGNED16;
		option: ADDRESS): SIGNED16;

	SQLGetData: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		col: SIGNED16;
		resType: SIGNED16;
		resValue: ADDRESS;
		resMaxSize: SIGNED32;
		resActSize: ADDRESS): SIGNED16;	(* address of longint containing result len *)

	SQLGetFunctions: PROCEDURE {WINAPI} (
		hdbc: Kernel32.HANDLE;
		whichFunction: SIGNED16;
		functExists: ADDRESS): SIGNED16;

	SQLGetInfo: PROCEDURE {WINAPI} (
		hdbc: Kernel32.HANDLE;
		infoType: SIGNED16;
		resInfo: ADDRESS;
		resInfoMaxSize: SIGNED16;
		resInfoActSize: ADDRESS): SIGNED16;	(* address of integer containing result len *)

	SQLGetStmtOption: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		whichOption: SIGNED16;
		option: ADDRESS): SIGNED16;

	SQLGetTypeInfo: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		whichType: SIGNED16): SIGNED16;

	SQLParamData: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		dataAdr: ADDRESS): SIGNED16;

	SQLPutData: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		dataAdr: ADDRESS;
		dataSize: SIZE): SIGNED16;

	SQLSetConnectOption: PROCEDURE {WINAPI} (
		hdbc: Kernel32.HANDLE;
		whichOption: SIGNED16;
		option: ADDRESS): SIGNED16;

	SQLSetStmtOption: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		whichOption: SIGNED16;
		option: ADDRESS): SIGNED16;

	SQLSpecialColumns: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		whichColType: SIGNED16;
		tableQualifier: ADDRESS;
		tabelQualifierLen: SIGNED16;
		tableOwner: ADDRESS;
		tableOwnerLen: SIGNED16;
		tableName: ADDRESS;
		tableNameLen: SIGNED16;
		scope: SIGNED16;
		nullableCols: SIGNED16): SIGNED16;

	SQLStatistics: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		tableQualifier: ADDRESS;
		tableQualifierLen: SIGNED16;
		tableOwner: ADDRESS;
		tableOwnerLen: SIGNED16;
		tableName: ADDRESS;
		tableNameLen: SIGNED16;
		indexType: SIGNED16;
		accuracy: SIGNED16): SIGNED16;

	SQLTables: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		tableQualifier: ADDRESS;
		tableQualifierLen: SIGNED16;
		tableOwner: ADDRESS;
		tableOwnerLen: SIGNED16;
		tableName: ADDRESS;
		tableNameLen: SIGNED16;
		tableType: ADDRESS;
		tableTypeLen: SIGNED16): SIGNED16;

(*	Level 2 Functions	*)

	SQLBrowseConnect: PROCEDURE {WINAPI} (
		hdbc: ADDRESS;
		connStrIn: ADDRESS;
		connStrInLen: SIGNED16;
		connStrOut: ADDRESS;
		connStrOutMaxLen: SIGNED16;
		connStrOutActLen: ADDRESS): SIGNED16;	(* address of integer *)

	SQLColumnPrivileges: PROCEDURE {WINAPI} (
		hstmt: ADDRESS;
		tableQualifier: ADDRESS;
		tableQualifierLen: SIGNED16;
		tableOwner: ADDRESS;
		tableOwnerLen: SIGNED16;
		tableName: ADDRESS;
		tableNameLen: SIGNED16;
		columnName: ADDRESS;
		columnNameLen: SIGNED16): SIGNED16;

	SQLDataSources: PROCEDURE {WINAPI} (
		henv: ADDRESS;
		direction: SIGNED16;
		dataSourceName: ADDRESS;
		dataSourceNameMaxLen: SIGNED16;
		dataSourceNameActLen: ADDRESS;	(* address of integer *)
		description: ADDRESS;
		descriptionMaxLen: SIGNED16;
		descriptionActLen: ADDRESS): SIGNED16;	(* address of integer *)

	SQLDescribeParam: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		par: SIGNED16;
		sqlType: ADDRESS;	(* address of integer *)
		colPrecision: ADDRESS;	(* address of longint *)
		colScale: ADDRESS;	(* address of integer *)
		colNullable: ADDRESS): SIGNED16;	(* address of integer *)

	SQLExtendedFetch: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		fetchType: SIGNED16;
		rowToFetch: SIGNED32;
		numFetchedRows: ADDRESS;	(* address of longint *)
		rowStatus: ADDRESS): SIGNED16;	(* address of array of integer *)

	SQLForeignKeys: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		primKeyTabQualifier: ADDRESS;
		primKeyTabQualifierLen: SIGNED16;
		primKeyTabOwner: ADDRESS;
		primKeyTabOwnerLen: SIGNED16;
		primKeyTabName: ADDRESS;
		primKeyTabNameLen: SIGNED16;
		forKeyTabQualifier: ADDRESS;
		forKeyTabQualifierLen: SIGNED16;
		forKeyTabOwner: ADDRESS;
		forKeyTabOwnerLen: SIGNED16;
		forKeyTabName: ADDRESS;
		forKeyTabNameLen: SIGNED16): SIGNED16;

	SQLMoreResults: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE): SIGNED16;

	SQLNativeSql: PROCEDURE {WINAPI} (
		hdbc: Kernel32.HANDLE;
		sqlStrIn: ADDRESS;
		sqlStrInLen: SIGNED32;
		sqlStrOut: ADDRESS;
		sqlStrOutMaxLen: SIGNED32;
		sqlStrOutActLen: ADDRESS): SIGNED16;	(* address of longint *)

	SQLNumParams: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		numParams: ADDRESS): SIGNED16;	(* address of integer *)

	SQLParamOptions: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		numRows: SIGNED32;
		curRow: ADDRESS): SIGNED16;	(* address of longint *)

	SQLPrimaryKeys: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		tableQualifier: ADDRESS;
		tableQualifierLen: SIGNED16;
		tableOwner: ADDRESS;
		tableOwnerLen: SIGNED16;
		tableName: ADDRESS;
		tableNameLen: SIGNED16): SIGNED16;

	SQLProcedureColumns: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		procQualifier: ADDRESS;
		procQualifierLen: SIGNED16;
		procOwner: ADDRESS;
		procOwnerLen: SIGNED16;
		procName: ADDRESS;
		procNameLen: SIGNED16;
		columnName: ADDRESS;
		columnNameLen: SIGNED16): SIGNED16;

	SQLProcedures: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		procQualifier: ADDRESS;
		procQualifierLen: SIGNED16;
		procOwner: ADDRESS;
		procOwnerLen: SIGNED16;
		procName: ADDRESS;
		procNameLen: SIGNED16): SIGNED16;

	SQLSetPos: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		row: SIGNED16;
		op: SIGNED16;
		lock: SIGNED16): SIGNED16;

	SQLTablePrivileges: PROCEDURE {WINAPI} (
		hstmt: Kernel32.HANDLE;
		tableQualifier: ADDRESS;
		tableQualifierLen: SIGNED16;
		tableOwner: ADDRESS;
		tableOwnerLen: SIGNED16;
		tableName: ADDRESS;
		tableNameLen: SIGNED16): SIGNED16;

	SQLDrivers: PROCEDURE {WINAPI} (
		henv: ADDRESS;
		direction: SIGNED16;
		driverDesc: ADDRESS;
		driverDescMaxLen: SIGNED16;
		driverDescActLen: ADDRESS;	(* address of integer *)
		driverAttributes: ADDRESS;
		driverAttributesMaxLen: SIGNED16;
		driverAttributesActLen: ADDRESS): SIGNED16;	(* address of integer *)

	SQLBindParameter: PROCEDURE {WINAPI} (
		hstmt: ADDRESS;
		parNum: SIGNED16;
		paramType: SIGNED16;
		cType: SIGNED16;
		sqlType: SIGNED16;
		colPrec: SIGNED32;
		colScale: SIGNED16;
		inOutBuff: ADDRESS;
		inOutBuffMaxLen: SIGNED32;
		inOutBuffActLen: ADDRESS): SIGNED16;	(* address of longint *)

	(* Level 3 functions *)
	SQLFetchScroll: PROCEDURE {WINAPI} (
		hstmt: ADDRESS;
		fetchorientation: SIGNED16;
		fetchoffset: SIGNED32): SIGNED16;

	SQLSetStmtAttr: PROCEDURE {WINAPI} (
		hstmt: ADDRESS;
		attribute: SIGNED32;
		value: SIGNED32;
		stringlength: SIGNED32): SIGNED16;

	SQLSetConnectAttr: PROCEDURE {WINAPI} (
		hdbc: ADDRESS;
		attribute: SIGNED32;
		valuePtr: SIGNED32;
		stringLength: SIGNED32): SIGNED16;



(*	-------------------------- interface to core functions --------------------------	*)

PROCEDURE AllocConnect*(hdbc: HDBC; VAR res: SIGNED16);
BEGIN
	res:= SQLAllocConnect(env.henv, ADDRESSOF(hdbc.hdbc));
END AllocConnect;

(* don't export AllocEnv as it's called in module initialization *)
PROCEDURE AllocEnv(henv: HENV; VAR res: SIGNED16);
BEGIN
	res:= SQLAllocEnv(ADDRESSOF(henv.henv));
END AllocEnv;

PROCEDURE AllocStmt*(hdbc: HDBC; hstmt: HSTMT; VAR res: SIGNED16);
BEGIN
	res:= SQLAllocStmt(hdbc.hdbc, ADDRESSOF(hstmt.hstmt));
END AllocStmt;

PROCEDURE BindCol*(hstmt: HSTMT; col, retType: SIGNED16; VAR buf: ARRAY OF S.BYTE; VAR resSize: SIGNED32;
VAR res: SIGNED16);
BEGIN
	res:= SQLBindCol(hstmt.hstmt, col, retType, ADDRESSOF(buf), LEN(buf)(SIGNED32), ADDRESSOF(resSize));
END BindCol;

PROCEDURE Cancel*(hstmt: HSTMT; VAR res: SIGNED16);
BEGIN
	res:= SQLCancel(hstmt.hstmt);
END Cancel;

PROCEDURE ColAttributes*(hstmt: HSTMT; col, fDescType: SIGNED16; VAR rgbDesc: ARRAY OF CHAR; VAR pfDesc: ADDRESS;
VAR res: SIGNED16);
	VAR DescLen: SIGNED16;
BEGIN
	res:= SQLColAttributes(hstmt.hstmt, col, fDescType, ADDRESSOF(rgbDesc), SIGNED16(LEN(rgbDesc)),
		ADDRESSOF(DescLen), ADDRESSOF(pfDesc));
END ColAttributes;

PROCEDURE Connect*(hdbc: HDBC; DSN, UID, PW: ARRAY OF CHAR; VAR res: SIGNED16);
BEGIN
	res:= SQLConnect(hdbc.hdbc, ADDRESSOF(DSN), NTS, ADDRESSOF(UID), NTS, ADDRESSOF(PW), NTS);
END Connect;

PROCEDURE DescribeCol*(hstmt: HSTMT; icol: SIGNED16; VAR ColName: ARRAY OF CHAR;VAR SqlType: SIGNED16;
VAR ColDef: SIGNED32; VAR Scale: SIGNED16; VAR Nullable: BOOLEAN; VAR res: SIGNED16);
	VAR colLen, null: SIGNED16;
BEGIN
	res:= SQLDescribeCol(hstmt.hstmt, icol, ADDRESSOF(ColName), SIGNED16(LEN(ColName)), ADDRESSOF(colLen),
				ADDRESSOF(SqlType), ADDRESSOF(ColDef), ADDRESSOF(Scale), ADDRESSOF(null));
	Nullable:= (null # 0);
END DescribeCol;

PROCEDURE Disconnect*(hdbc: HDBC; VAR res: SIGNED16);
BEGIN
	res:= SQLDisconnect(hdbc.hdbc);
END Disconnect;

PROCEDURE StatementError*(hstmt: HSTMT; VAR SqlState: ARRAY OF CHAR; VAR NativeError: SIGNED32;
VAR ErrorMsg: ARRAY OF CHAR; VAR res: SIGNED16);
	VAR state: ARRAY 6 OF CHAR; len, msgSize: SIGNED16;
BEGIN
	len:= SIGNED16(MIN(MAXMESSAGELENGTH-1, LEN(ErrorMsg)));
	res:= SQLError(0, 0, hstmt.hstmt, ADDRESSOF(state), ADDRESSOF(NativeError), ADDRESSOF(ErrorMsg), len,
		ADDRESSOF(msgSize));
	COPY (state, SqlState);
END StatementError;

PROCEDURE ConnectionError*(hdbc: HDBC; VAR SqlState: ARRAY OF CHAR; VAR NativeError: SIGNED32;
ErrorMsg: ARRAY OF CHAR; VAR res: SIGNED16);
	VAR state: ARRAY 6 OF CHAR; len, msgSize: SIGNED16;
BEGIN
	len:= SIGNED16(MIN(MAXMESSAGELENGTH-1, LEN(ErrorMsg)));
	IF hdbc # NIL THEN
		res:= SQLError(0, hdbc.hdbc, 0, ADDRESSOF(state), ADDRESSOF(NativeError), ADDRESSOF(ErrorMsg), len, ADDRESSOF(msgSize))
	ELSE
		res:= SQLError(env.henv, 0, 0, ADDRESSOF(state), ADDRESSOF(NativeError), ADDRESSOF(ErrorMsg), len, ADDRESSOF(msgSize))
	END;
	COPY (state, SqlState)
END ConnectionError;

PROCEDURE ExecDirect*(hstmt: HSTMT; SqlStr: ARRAY OF CHAR; VAR res: SIGNED16);
BEGIN
	res:= SQLExecDirect(hstmt.hstmt, ADDRESSOF(SqlStr), NTS)
END ExecDirect;

PROCEDURE Execute*(hstmt: HSTMT; VAR res: SIGNED16);
BEGIN
	res:= SQLExecute(hstmt.hstmt)
END Execute;

PROCEDURE Fetch*(hstmt: HSTMT; VAR res: SIGNED16);
BEGIN
	res:= SQLFetch(hstmt.hstmt)
END Fetch;

PROCEDURE FreeConnect*(hdbc: HDBC; VAR res: SIGNED16);
BEGIN
	res:= SQLFreeConnect(hdbc.hdbc)
END FreeConnect;

(* don't expor FreeEnv as it's called in the teminate procedure *)
PROCEDURE FreeEnv(henv: HENV; VAR res: SIGNED16);
BEGIN
	res:= SQLFreeEnv(henv.henv)
END FreeEnv;

PROCEDURE FreeStmt*(hstmt: HSTMT; opt: SIGNED16; VAR res: SIGNED16);
BEGIN
	res:= SQLFreeStmt(hstmt.hstmt, opt)
END FreeStmt;

PROCEDURE GetCursorName*(hstmt: HSTMT; VAR Cursor: ARRAY OF CHAR; VAR res: SIGNED16);
	VAR size: SIGNED16;
BEGIN
	res:= SQLGetCursorName(hstmt.hstmt, ADDRESSOF(Cursor), SIGNED16(LEN(Cursor)), ADDRESSOF(size))
END GetCursorName;

PROCEDURE NumResultCols*(hstmt: HSTMT; VAR cols: SIGNED16; VAR res: SIGNED16);
BEGIN
	res:= SQLNumResultCols(hstmt.hstmt, ADDRESSOF(cols))
END NumResultCols;

PROCEDURE Prepare*(hstmt: HSTMT; SqlStr: ARRAY OF CHAR; VAR res: SIGNED16);
BEGIN
	res:= SQLPrepare(hstmt.hstmt, ADDRESSOF(SqlStr), NTS)
END Prepare;

PROCEDURE RowCount*(hstmt: HSTMT; VAR rows: SIGNED32; VAR res: SIGNED16);
BEGIN
	res:= SQLRowCount(hstmt.hstmt, ADDRESSOF(rows))
END RowCount;

PROCEDURE SetCursorName*(hstmt: HSTMT; Cursor: ARRAY OF CHAR; VAR res: SIGNED16);
BEGIN
	res:= SQLSetCursorName(hstmt.hstmt, ADDRESSOF(Cursor), NTS)
END SetCursorName;

PROCEDURE Commit*(hdbc: HDBC; VAR res: SIGNED16);
BEGIN
	res:= SQLTransact(0, hdbc.hdbc, 0)
END Commit;

PROCEDURE Rollback*(hdbc: HDBC; VAR res: SIGNED16);
BEGIN
	res:= SQLTransact(0, hdbc.hdbc, 1)
END Rollback;

(*	-------------------------- interface to level 1 functions --------------------------	*)

PROCEDURE Columns*(hstmt: HSTMT; tabQualifier, tabOwner, tabName, colName: ARRAY OF CHAR; VAR res: SIGNED16): SIGNED16;
	VAR qualAdr, ownAdr, nameAdr, colAdr: ADDRESS; qualLen, ownLen, nameLen, colLen: SIGNED16;
BEGIN
	(* should be possible to pass NIL for the 4 arrays *)
	IF (LEN(tabQualifier) = 1) & (tabQualifier[0] = 1X) THEN qualAdr:= 0; qualLen:= 0
	ELSE qualAdr:= ADDRESSOF(tabQualifier); qualLen:= NTS END;
	IF (LEN(tabOwner) = 1) & (tabOwner[0] = 1X) THEN ownAdr:= 0; ownLen:= 0
	ELSE ownAdr:= ADDRESSOF(tabOwner); ownLen:= NTS END;
	IF (LEN(tabName) = 1) & (tabName[0] = 1X) THEN nameAdr:= 0; nameLen:= 0
	ELSE nameAdr:= ADDRESSOF(tabName); nameLen:= NTS END;
	IF (LEN(colName) = 1) & (colName[0] = 1X) THEN colAdr:= 0; colLen:= 0
	ELSE colAdr:= ADDRESSOF(colName); colLen:= NTS END;

	res:= SQLColumns(hstmt.hstmt, qualAdr, qualLen, ownAdr, ownLen, nameAdr, nameLen, colAdr, colLen)
END Columns;

PROCEDURE DriverConnect*(hdbc: HDBC; VAR connStrIn, connStrOut: ARRAY OF CHAR; VAR res: SIGNED16);
	VAR connOutSize: SIGNED16;
BEGIN
	res:= SQLDriverConnect(hdbc.hdbc, 0, ADDRESSOF(connStrIn), NTS, ADDRESSOF(connStrOut), SIGNED16(LEN(connStrOut)),
		ADDRESSOF(connOutSize), 0)	(* don't show a dialog box *)
END DriverConnect;

PROCEDURE GetConnectOption*(hdbc: HDBC; whichOption: SIGNED16; VAR optValue: ARRAY OF S.BYTE; VAR res: SIGNED16);
BEGIN
	res:= SQLGetConnectOption(hdbc.hdbc, whichOption, ADDRESSOF(optValue))
END GetConnectOption;

PROCEDURE GetData*(hstmt: HSTMT; col, resType: SIGNED16; VAR resValue: ARRAY OF S.BYTE; VAR resSize: SIGNED32;
VAR res: SIGNED16);
BEGIN
	res:= SQLGetData(hstmt.hstmt, col, resType, ADDRESSOF(resValue), LEN(resValue)(SIGNED32), ADDRESSOF(resSize))
END GetData;

PROCEDURE GetFunctions*(hdbc: HDBC; whichFunct: SIGNED16; VAR exists: BOOLEAN; VAR res: SIGNED16);
	VAR ex: SIGNED16;
BEGIN
	res:= SQLGetFunctions(hdbc.hdbc, whichFunct, ADDRESSOF(ex)); exists:= ex # 0
END GetFunctions;

PROCEDURE GetInfo*(hdbc: HDBC; infoType: SIGNED16; VAR info: ARRAY OF S.BYTE; VAR res: SIGNED16);
	VAR actSize: SIGNED16;
BEGIN
	(* should check that the size of info is at least 4 bytes if infoType not of character type *)
	res:= SQLGetInfo(hdbc.hdbc, infoType, ADDRESSOF(info), SIGNED16(LEN(info)), ADDRESSOF(actSize))
END GetInfo;

PROCEDURE GetStmtOption*(hstmt: HSTMT; whichOption: SIGNED16; VAR optValue: ARRAY OF S.BYTE; VAR res: SIGNED16);
BEGIN
	(* size of optValue should be at least 4 bytes *)
	res:= SQLGetStmtOption(hstmt.hstmt, whichOption, ADDRESSOF(optValue))
END GetStmtOption;

PROCEDURE GetTypeInfo*(hstmt: HSTMT; whichSQLType: SIGNED16; VAR res: SIGNED16);
BEGIN
	res:= SQLGetTypeInfo(hstmt.hstmt, whichSQLType)
END GetTypeInfo;

PROCEDURE ParamData*(hstmt: HSTMT; VAR data:ARRAY OF S.BYTE; VAR res: SIGNED16);
BEGIN
	res:= SQLParamData(hstmt.hstmt, ADDRESSOF(data))
END ParamData;

PROCEDURE PutData*(hstmt: HSTMT; VAR data: ARRAY OF S.BYTE; len: SIZE; VAR res: SIGNED16);
BEGIN
	res:= SQLPutData(hstmt.hstmt, ADDRESSOF(data), len)
END PutData;

PROCEDURE SetConnectOption*(hdbc: HDBC; whichOpt: SIGNED16; VAR option: ARRAY OF S.BYTE; VAR res: SIGNED16);
BEGIN
	res:= SQLSetConnectOption(hdbc.hdbc, whichOpt, ADDRESSOF(option))
END SetConnectOption;

PROCEDURE SetStmtOption*(hstmt: HSTMT; whichOpt: SIGNED16; VAR option: ARRAY OF S.BYTE; VAR res: SIGNED16);
BEGIN
	res:= SQLSetStmtOption(hstmt.hstmt, whichOpt, ADDRESSOF(option))
END SetStmtOption;

PROCEDURE SpecialColumns*(hstmt: HSTMT; colType: SIGNED16; tabQualifier, tabOwner, tabName: ARRAY OF CHAR;
scope: SIGNED16; nullables: BOOLEAN; VAR res: SIGNED16);
	VAR nulls: SIGNED16; qualAdr, ownAdr, nameAdr: ADDRESS; qualLen, ownLen, nameLen: SIGNED16;
BEGIN
	IF nullables THEN nulls:= 1 ELSE nulls:= 0 END;
	(* should be possible to pass NIL for the 3 arrays *)
	IF (LEN(tabQualifier) = 1) & (tabQualifier[0] = 1X) THEN qualAdr:= 0; qualLen:= 0
	ELSE qualAdr:= ADDRESSOF(tabQualifier); qualLen:= NTS END;
	IF (LEN(tabOwner) = 1) & (tabOwner[0] = 1X) THEN ownAdr:= 0; ownLen:= 0
	ELSE ownAdr:= ADDRESSOF(tabOwner); ownLen:= NTS END;
	IF (LEN(tabName) = 1) & (tabName[0] = 1X) THEN nameAdr:= 0; nameLen:= 0
	ELSE nameAdr:= ADDRESSOF(tabName); nameLen:= NTS END;

	res:= SQLSpecialColumns(hstmt.hstmt, colType, qualAdr, qualLen, ownAdr, ownLen, nameAdr, nameLen, scope, nulls)
END SpecialColumns;

PROCEDURE  Statistics*(hstmt: HSTMT; tabQualifier, tabOwner, tabName: ARRAY OF CHAR; uniqueIndexes,
accurate: BOOLEAN; VAR res: SIGNED16);
	VAR indexType, accuracy: SIGNED16; qualAdr, ownAdr, nameAdr: ADDRESS; qualLen, ownLen, nameLen: SIGNED16;
BEGIN
	IF uniqueIndexes THEN indexType:= 0 ELSE indexType:= 1 END;
	IF accurate THEN accuracy:= 1 ELSE accuracy:= 0 END;
	(* should be possible to pass NIL for the 3 arrays *)
	IF (LEN(tabQualifier) = 1) & (tabQualifier[0] = 1X) THEN qualAdr:= 0; qualLen:= 0
	ELSE qualAdr:= ADDRESSOF(tabQualifier); qualLen:= NTS END;
	IF (LEN(tabOwner) = 1) & (tabOwner[0] = 1X) THEN ownAdr:= 0; ownLen:= 0
	ELSE ownAdr:= ADDRESSOF(tabOwner); ownLen:= NTS END;
	IF (LEN(tabName) = 1) & (tabName[0] = 1X) THEN nameAdr:= 0; nameLen:= 0
	ELSE nameAdr:= ADDRESSOF(tabName); nameLen:= NTS END;

	res:= SQLStatistics(hstmt.hstmt, qualAdr, qualLen, ownAdr, ownLen, nameAdr, nameLen, indexType, accuracy)
END Statistics;

PROCEDURE Tables*(hstmt: HSTMT; tabQualifier, tabOwner, tabName, tabType: ARRAY OF CHAR; VAR res: SIGNED16);
	VAR qualAdr, ownAdr, nameAdr, typeAdr: ADDRESS; qualLen, ownLen, nameLen, typeLen: SIGNED16;
BEGIN
	(* should be possible to pass NIL for the 4 tab... arrays *)
	IF (LEN(tabQualifier) = 1) & (tabQualifier[0] = 1X) THEN qualAdr:= 0; qualLen:= 0
	ELSE qualAdr:= ADDRESSOF(tabQualifier); qualLen:= NTS END;
	IF (LEN(tabOwner) = 1) & (tabOwner[0] = 1X) THEN ownAdr:= 0; ownLen:= 0
	ELSE ownAdr:= ADDRESSOF(tabOwner); ownLen:= NTS END;
	IF (LEN(tabName) = 1) & (tabName[0] = 1X) THEN nameAdr:= 0; nameLen:= 0
	ELSE nameAdr:= ADDRESSOF(tabName); nameLen:= NTS END;
	IF (LEN(tabType) = 1) & (tabType[0] = 1X) THEN typeAdr:= 0; typeLen:= 0
	ELSE typeAdr:= ADDRESSOF(tabType); typeLen:= NTS END;
	res:= SQLTables(hstmt.hstmt, qualAdr, qualLen, ownAdr, ownLen, nameAdr, nameLen, typeAdr, typeLen)
END Tables;

(*	-------------------------- interface to level 2 functions --------------------------	*)

PROCEDURE BrowseConnect*(hdbc: HDBC; connStrIn: ARRAY OF CHAR; VAR connStrOut: ARRAY OF CHAR; VAR res: SIGNED16);
	VAR outLen: SIGNED16;
BEGIN
	res:= SQLBrowseConnect(hdbc.hdbc, ADDRESSOF(connStrIn), NTS, ADDRESSOF(connStrOut), SIGNED16(LEN(connStrOut)),
		ADDRESSOF(outLen))
END BrowseConnect;

PROCEDURE ColumnPrivileges*(hstmt: HSTMT; tabQualifier, tabOwner, tabName, colName: ARRAY OF CHAR; VAR res: SIGNED16);
	VAR qualAdr, ownAdr, nameAdr, colAdr: ADDRESS; qualLen, ownLen, nameLen, colLen: SIGNED16;
BEGIN
	(* should be possible to pass NIL for the 4 arrays *)
	IF (LEN(tabQualifier) = 1) & (tabQualifier[0] = 1X) THEN qualAdr:= 0; qualLen:= 0
	ELSE qualAdr:= ADDRESSOF(tabQualifier); qualLen:= NTS END;
	IF (LEN(tabOwner) = 1) & (tabOwner[0] = 1X) THEN ownAdr:= 0; ownLen:= 0
	ELSE ownAdr:= ADDRESSOF(tabOwner); ownLen:= NTS END;
	IF (LEN(tabName) = 1) & (tabName[0] = 1X) THEN nameAdr:= 0; nameLen:= 0
	ELSE nameAdr:= ADDRESSOF(tabName); nameLen:= NTS END;
	IF (LEN(colName) = 1) & (colName[0] = 1X) THEN colAdr:= 0; colLen:= 0
	ELSE colAdr:= ADDRESSOF(colName); colLen:= NTS END;

	res:= SQLColumnPrivileges(hstmt.hstmt, qualAdr, qualLen, ownAdr, ownLen, nameAdr, nameLen, colAdr, colLen)
END ColumnPrivileges;

PROCEDURE DataSources*(direction: SIGNED16; VAR dataSourceName, dataSourceDesc: ARRAY OF CHAR; VAR res: SIGNED16);
	VAR nameLen, descLen: SIGNED16;
BEGIN
	(* could implement it with enumerate procedure *)
	res:= SQLDataSources(env.henv, direction, ADDRESSOF(dataSourceName), SIGNED16(LEN(dataSourceName)),
		ADDRESSOF(nameLen), ADDRESSOF(dataSourceDesc), SIGNED16(LEN(dataSourceDesc)), ADDRESSOF(descLen))
END DataSources;

PROCEDURE DescribeParam*(hstmt: HSTMT; par: SIGNED16; VAR sqlType: SIGNED16; VAR prec: SIGNED32; VAR scale,
nullable: SIGNED16; VAR res: SIGNED16);
BEGIN
	res:= SQLDescribeParam(hstmt.hstmt, par, ADDRESSOF(sqlType), ADDRESSOF(prec), ADDRESSOF(scale),
		ADDRESSOF(nullable))
END DescribeParam;

PROCEDURE ExtendedFetch*(hstmt: HSTMT; fetchType: SIGNED16; rowToFetch: SIGNED32; VAR numFetchedRows: SIGNED32;
VAR rowStatus: SIGNED16; VAR res: SIGNED16);
BEGIN
	res:= SQLExtendedFetch(hstmt.hstmt, fetchType, rowToFetch, ADDRESSOF(numFetchedRows), ADDRESSOF(rowStatus))
END ExtendedFetch;

PROCEDURE SetStmtAttr*(hstmt: HSTMT; attribute: SIGNED32; valuePtr: SIGNED32; stringLength: SIGNED32; VAR res: SIGNED16);

BEGIN
	res:= SQLSetStmtAttr(hstmt.hstmt, attribute, valuePtr, stringLength)
END SetStmtAttr;


PROCEDURE ForeignKeys*(hstmt: HSTMT; primKeyTabQualifier, primKeyTabOwner, primKeyTabName, forKeyTabQualifier,
forKeyTabOwner, forKeyTabName: ARRAY OF CHAR; VAR res: SIGNED16);
	VAR pQualAdr, pOwnAdr, pNameAdr: ADDRESS; pQualLen, pOwnLen, pNameLen: SIGNED16;
		fQualAdr, fOwnAdr, fNameAdr: ADDRESS; fQualLen, fOwnLen, fNameLen: SIGNED16;
BEGIN
	(* should be possible to pass NIL for the 6 arrays *)
	IF (LEN(primKeyTabQualifier) = 1) & (primKeyTabQualifier[0] = 1X) THEN pQualAdr:= 0; pQualLen:= 0
	ELSE pQualAdr:= ADDRESSOF(primKeyTabQualifier); pQualLen:= NTS END;
	IF (LEN(primKeyTabOwner) = 1) & (primKeyTabOwner[0] = 1X) THEN pOwnAdr:= 0; pOwnLen:= 0
	ELSE pOwnAdr:= ADDRESSOF(primKeyTabOwner); pOwnLen:= NTS END;
	IF (LEN(primKeyTabName) = 1) & (primKeyTabName[0] = 1X) THEN pNameAdr:= 0; pNameLen:= 0
	ELSE pNameAdr:= ADDRESSOF(primKeyTabName); pNameLen:= NTS END;

	IF (LEN(forKeyTabQualifier) = 1) & (forKeyTabQualifier[0] = 1X) THEN fQualAdr:= 0; fQualLen:= 0
	ELSE fQualAdr:= ADDRESSOF(forKeyTabQualifier); fQualLen:= NTS END;
	IF (LEN(forKeyTabOwner) = 1) & (forKeyTabOwner[0] = 1X) THEN fOwnAdr:= 0; fOwnLen:= 0
	ELSE fOwnAdr:= ADDRESSOF(forKeyTabOwner); fOwnLen:= NTS END;
	IF (LEN(forKeyTabName) = 1) & (forKeyTabName[0] = 1X) THEN fNameAdr:= 0; fNameLen:= 0
	ELSE fNameAdr:= ADDRESSOF(forKeyTabName); fNameLen:= NTS END;

	res:= SQLForeignKeys(hstmt.hstmt, pQualAdr, pQualLen, pOwnAdr, pOwnLen, pNameAdr, pNameLen, fQualAdr,
		fQualLen, fOwnAdr, fOwnLen, fNameAdr, fNameLen)
END ForeignKeys;

PROCEDURE MoreResults*(hstmt: HSTMT): BOOLEAN;
VAR more: SIGNED16;
BEGIN
	more:= SQLMoreResults(hstmt.hstmt);
	IF more = 0 THEN RETURN TRUE ELSE RETURN FALSE END
END MoreResults;

PROCEDURE NativeSql*(hdbc: HDBC; origSql: ARRAY OF CHAR; VAR nativeSql: ARRAY OF CHAR; VAR res: SIGNED16);
	VAR len: SIGNED32;
BEGIN
	res:= SQLNativeSql(hdbc.hdbc, ADDRESSOF(origSql), NTS, ADDRESSOF(nativeSql), LEN(nativeSql)(SIGNED32), ADDRESSOF(len))
END NativeSql;

PROCEDURE NumParams*(hstmt: HSTMT; VAR res: SIGNED16): SIGNED16;
	VAR num: SIGNED16;
BEGIN
	res:= SQLNumParams(hstmt.hstmt, ADDRESSOF(num));
	RETURN num
END NumParams;

PROCEDURE ParamOptions*(hstmt: HSTMT; numRows: SIGNED32; VAR curRow: SIGNED32; VAR res: SIGNED16);
BEGIN
	res:= SQLParamOptions(hstmt.hstmt, numRows, ADDRESSOF(curRow))
END ParamOptions;

PROCEDURE PrimaryKeys*(hstmt: HSTMT; tabQualifier, tabOwner, tabName: ARRAY OF CHAR; VAR res: SIGNED16);
	VAR qualAdr, ownAdr, nameAdr: ADDRESS; qualLen, ownLen, nameLen: SIGNED16;
BEGIN
	(* should be possible to pass NIL for the 3 arrays *)
	IF (LEN(tabQualifier) = 1) & (tabQualifier[0] = 1X) THEN qualAdr:= 0; qualLen:= 0
	ELSE qualAdr:= ADDRESSOF(tabQualifier); qualLen:= NTS END;
	IF (LEN(tabOwner) = 1) & (tabOwner[0] = 1X) THEN ownAdr:= 0; ownLen:= 0
	ELSE ownAdr:= ADDRESSOF(tabOwner); ownLen:= NTS END;
	IF (LEN(tabName) = 1) & (tabName[0] = 1X) THEN nameAdr:= 0; nameLen:= 0
	ELSE nameAdr:= ADDRESSOF(tabName); nameLen:= NTS END;

	res:= SQLPrimaryKeys(hstmt.hstmt, qualAdr, qualLen, ownAdr, ownLen, nameAdr, nameLen)
END PrimaryKeys;

PROCEDURE ProcedureColumns*(hstmt: HSTMT; procQualifier, procOwner, procName, colName: ARRAY OF CHAR; VAR res: SIGNED16);
	VAR qualAdr, ownAdr, nameAdr, colAdr: ADDRESS; qualLen, ownLen, nameLen, colLen: SIGNED16;
BEGIN
	(* should be possible to pass NIL for the 4 arrays *)
	IF (LEN(procQualifier) = 1) & (procQualifier[0] = 1X) THEN qualAdr:= 0; qualLen:= 0
	ELSE qualAdr:= ADDRESSOF(procQualifier); qualLen:= NTS END;
	IF (LEN(procOwner) = 1) & (procOwner[0] = 1X) THEN ownAdr:= 0; ownLen:= 0
	ELSE ownAdr:= ADDRESSOF(procOwner); ownLen:= NTS END;
	IF (LEN(procName) = 1) & (procName[0] = 1X) THEN nameAdr:= 0; nameLen:= 0
	ELSE nameAdr:= ADDRESSOF(procName); nameLen:= NTS END;
	IF (LEN(colName) = 1) & (colName[0] = 1X) THEN colAdr:= 0; colLen:= 0
	ELSE colAdr:= ADDRESSOF(colName); colLen:= NTS END;

	res:= SQLProcedureColumns(hstmt.hstmt, qualAdr, qualLen, ownAdr, ownLen, nameAdr, nameLen, colAdr, colLen)
END ProcedureColumns;

PROCEDURE Procedures*(hstmt: HSTMT; procQualifier, procOwner, procName: ARRAY OF CHAR; VAR res: SIGNED16);
	VAR qualAdr, ownAdr, nameAdr: ADDRESS; qualLen, ownLen, nameLen: SIGNED16;
BEGIN
	(* should be possible to pass NIL for the 3 arrays *)
	IF (LEN(procQualifier) = 1) & (procQualifier[0] = 1X) THEN qualAdr:= 0; qualLen:= 0
	ELSE qualAdr:= ADDRESSOF(procQualifier); qualLen:= NTS END;
	IF (LEN(procOwner) = 1) & (procOwner[0] = 1X) THEN ownAdr:= 0; ownLen:= 0
	ELSE ownAdr:= ADDRESSOF(procOwner); ownLen:= NTS END;
	IF (LEN(procName) = 1) & (procName[0] = 1X) THEN nameAdr:= 0; nameLen:= 0
	ELSE nameAdr:= ADDRESSOF(procName); nameLen:= NTS END;

	res:= SQLProcedures(hstmt.hstmt, qualAdr, qualLen, ownAdr, ownLen, nameAdr, nameLen)
END Procedures;

PROCEDURE SetPos*(hstmt: HSTMT; row, op, lock: SIGNED16; VAR res: SIGNED16);
BEGIN
	res:= SQLSetPos(hstmt.hstmt, row, op, lock)
END SetPos;

PROCEDURE TablePrivileges*(hstmt: HSTMT; tabQualifier, tabOwner, tabName: ARRAY OF CHAR; VAR res: SIGNED16);
	VAR qualAdr, ownAdr, nameAdr: ADDRESS; qualLen, ownLen, nameLen: SIGNED16;
BEGIN
	(* should be possible to pass NIL for the 3 arrays *)
	IF (LEN(tabQualifier) = 1) & (tabQualifier[0] = 1X) THEN qualAdr:= 0; qualLen:= 0
	ELSE qualAdr:= ADDRESSOF(tabQualifier); qualLen:= NTS END;
	IF (LEN(tabOwner) = 1) & (tabOwner[0] = 1X) THEN ownAdr:= 0; ownLen:= 0
	ELSE ownAdr:= ADDRESSOF(tabOwner); ownLen:= NTS END;
	IF (LEN(tabName) = 1) & (tabName[0] = 1X) THEN nameAdr:= 0; nameLen:= 0
	ELSE nameAdr:= ADDRESSOF(tabName); nameLen:= NTS END;

	res:= SQLTablePrivileges(hstmt.hstmt, qualAdr, qualLen, ownAdr, ownLen, nameAdr, nameLen)
END TablePrivileges;

PROCEDURE Drivers*(dir: SIGNED16; VAR driverDesc, driverAttr: ARRAY OF CHAR; VAR res: SIGNED16);
	VAR descLen, attrLen: SIGNED16;
BEGIN
	res:= SQLDrivers(env.henv, dir, ADDRESSOF(driverDesc), SIGNED16(LEN(driverDesc)), ADDRESSOF(descLen),
		ADDRESSOF(driverAttr), SIGNED16(LEN(driverAttr)), ADDRESSOF(attrLen))
END Drivers;

PROCEDURE BindParameter*(hstmt: HSTMT; par, parType, cType, sqlType: SIGNED16; prec: SIGNED32; scale: SIGNED16;
VAR parBuff: ARRAY OF S.BYTE; VAR parBuffActLen: SIGNED32; VAR res: SIGNED16);
BEGIN
	res:= SQLBindParameter(hstmt.hstmt, par, parType, cType, sqlType, prec, scale, ADDRESSOF(parBuff), LEN(parBuff)(SIGNED32),
		ADDRESSOF(parBuffActLen))
END BindParameter;

(* Interface to Level 3 fucntions *)

PROCEDURE FetchScroll*(hstmt: HSTMT; fetchOrientation: SIGNED16; fetchOffset: SIGNED32; VAR res: SIGNED16);

BEGIN
	res := SQLFetchScroll(hstmt.hstmt, fetchOrientation, fetchOffset)
END FetchScroll;

PROCEDURE SetConnectAttr*(hdbc: HDBC; attribute: SIGNED32; valuePtr: SIGNED32; stringLength: SIGNED32; VAR res: SIGNED16);

BEGIN
	res := SQLSetConnectAttr(hdbc.hdbc, attribute, valuePtr, stringLength)
END SetConnectAttr;



(*	-------------------------- internal procedures --------------------------	*)

PROCEDURE Init;
VAR str: ARRAY 64 OF CHAR;
BEGIN
	str := "ODBC32.DLL";
	lib:= Kernel32.LoadLibrary(str);	(* Was just ODBC32.DLL *)
	IF lib = 0 THEN HALT(99) END;

	(*	binding core functions	*)
	Kernel32.GetProcAddress(lib, "SQLAllocConnect", S.VAL(ADDRESS, SQLAllocConnect));
	Kernel32.GetProcAddress(lib, "SQLAllocEnv", S.VAL(ADDRESS, SQLAllocEnv));
	Kernel32.GetProcAddress(lib, "SQLAllocStmt", S.VAL(ADDRESS, SQLAllocStmt));
	Kernel32.GetProcAddress(lib, "SQLBindCol", S.VAL(ADDRESS, SQLBindCol));
	Kernel32.GetProcAddress(lib, "SQLCancel", S.VAL(ADDRESS, SQLCancel));
	Kernel32.GetProcAddress(lib, "SQLColAttributes", S.VAL(ADDRESS, SQLColAttributes));
	Kernel32.GetProcAddress(lib, "SQLConnect", S.VAL(ADDRESS, SQLConnect));
	Kernel32.GetProcAddress(lib, "SQLDescribeCol", S.VAL(ADDRESS, SQLDescribeCol));
	Kernel32.GetProcAddress(lib, "SQLDisconnect", S.VAL(ADDRESS, SQLDisconnect));
	Kernel32.GetProcAddress(lib, "SQLError", S.VAL(ADDRESS, SQLError));
	Kernel32.GetProcAddress(lib, "SQLExecDirect", S.VAL(ADDRESS, SQLExecDirect));
	Kernel32.GetProcAddress(lib, "SQLExecute", S.VAL(ADDRESS, SQLExecute));
	Kernel32.GetProcAddress(lib, "SQLFetch", S.VAL(ADDRESS, SQLFetch));
	Kernel32.GetProcAddress(lib, "SQLFreeConnect", S.VAL(ADDRESS, SQLFreeConnect));
	Kernel32.GetProcAddress(lib, "SQLFreeEnv", S.VAL(ADDRESS, SQLFreeEnv));
	Kernel32.GetProcAddress(lib, "SQLFreeStmt", S.VAL(ADDRESS, SQLFreeStmt));
	Kernel32.GetProcAddress(lib, "SQLGetCursorName", S.VAL(ADDRESS, SQLGetCursorName));
	Kernel32.GetProcAddress(lib, "SQLNumResultCols", S.VAL(ADDRESS, SQLNumResultCols));
	Kernel32.GetProcAddress(lib, "SQLPrepare", S.VAL(ADDRESS, SQLPrepare));
	Kernel32.GetProcAddress(lib, "SQLRowCount", S.VAL(ADDRESS, SQLRowCount));
	Kernel32.GetProcAddress(lib, "SQLSetCursorName", S.VAL(ADDRESS, SQLSetCursorName));
	Kernel32.GetProcAddress(lib, "SQLTransact", S.VAL(ADDRESS, SQLTransact));

	(*	binding level 1 functions	*)
	Kernel32.GetProcAddress(lib, "SQLColumns", S.VAL(ADDRESS, SQLColumns));
	Kernel32.GetProcAddress(lib, "SQLDriverConnect", S.VAL(ADDRESS, SQLDriverConnect));
	Kernel32.GetProcAddress(lib, "SQLGetConnectOption", S.VAL(ADDRESS, SQLGetConnectOption));
	Kernel32.GetProcAddress(lib, "SQLGetData", S.VAL(ADDRESS, SQLGetData));
	Kernel32.GetProcAddress(lib, "SQLGetFunctions", S.VAL(ADDRESS, SQLGetFunctions));
	Kernel32.GetProcAddress(lib, "SQLGetInfo", S.VAL(ADDRESS, SQLGetInfo));
	Kernel32.GetProcAddress(lib, "SQLGetStmtOption", S.VAL(ADDRESS, SQLGetStmtOption));
	Kernel32.GetProcAddress(lib, "SQLGetTypeInfo", S.VAL(ADDRESS, SQLGetTypeInfo));
	Kernel32.GetProcAddress(lib, "SQLParamData", S.VAL(ADDRESS, SQLParamData));
	Kernel32.GetProcAddress(lib, "SQLPutData", S.VAL(ADDRESS, SQLPutData));
	Kernel32.GetProcAddress(lib, "SQLSetConnectOption", S.VAL(ADDRESS, SQLSetConnectOption));
	Kernel32.GetProcAddress(lib, "SQLSetStmtOption", S.VAL(ADDRESS, SQLSetStmtOption));
	Kernel32.GetProcAddress(lib, "SQLSpecialColumns", S.VAL(ADDRESS, SQLSpecialColumns));
	Kernel32.GetProcAddress(lib, "SQLStatistics", S.VAL(ADDRESS, SQLStatistics));
	Kernel32.GetProcAddress(lib, "SQLTables", S.VAL(ADDRESS, SQLTables));

	(*	binding level 2 functions	*)
	Kernel32.GetProcAddress(lib, "SQLBrowseConnect", S.VAL(ADDRESS, SQLBrowseConnect));
	Kernel32.GetProcAddress(lib, "SQLColumnPrivileges", S.VAL(ADDRESS, SQLColumnPrivileges));
	Kernel32.GetProcAddress(lib, "SQLDataSources", S.VAL(ADDRESS, SQLDataSources));
	Kernel32.GetProcAddress(lib, "SQLExtendedFetch", S.VAL(ADDRESS, SQLExtendedFetch));
	Kernel32.GetProcAddress(lib, "SQLForeignKeys", S.VAL(ADDRESS, SQLForeignKeys));
	Kernel32.GetProcAddress(lib, "SQLMoreResults", S.VAL(ADDRESS, SQLMoreResults));
	Kernel32.GetProcAddress(lib, "SQLNativeSql", S.VAL(ADDRESS, SQLNativeSql));
	Kernel32.GetProcAddress(lib, "SQLNumParams", S.VAL(ADDRESS, SQLNumParams));
	Kernel32.GetProcAddress(lib, "SQLParamOptions", S.VAL(ADDRESS, SQLParamOptions));
	Kernel32.GetProcAddress(lib, "SQLPrimaryKeys", S.VAL(ADDRESS, SQLPrimaryKeys));
	Kernel32.GetProcAddress(lib, "SQLProcedureColumns", S.VAL(ADDRESS, SQLProcedureColumns));
	Kernel32.GetProcAddress(lib, "SQLProcedures", S.VAL(ADDRESS, SQLProcedures));
	Kernel32.GetProcAddress(lib, "SQLSetPos", S.VAL(ADDRESS, SQLSetPos));
	Kernel32.GetProcAddress(lib, "SQLTablePrivileges", S.VAL(ADDRESS, SQLTablePrivileges));
	Kernel32.GetProcAddress(lib, "SQLDrivers", S.VAL(ADDRESS, SQLDrivers));
	Kernel32.GetProcAddress(lib, "SQLBindParameter", S.VAL(ADDRESS, SQLBindParameter));

	(* binding level 3 functions *)
	Kernel32.GetProcAddress(lib, "SQLFetchScroll", S.VAL(ADDRESS, SQLFetchScroll));
	Kernel32.GetProcAddress(lib, "SQLSetStmtAttr", S.VAL(ADDRESS, SQLSetStmtAttr));
	Kernel32.GetProcAddress(lib, "SQLSetConnectAttr", S.VAL(ADDRESS, SQLSetConnectAttr))
END Init;

PROCEDURE Term;
BEGIN
	FreeEnv(env, res1);
	(* Kernel32.FreeLibrary(lib) *)
END Term;

BEGIN
	Init;
	nullString[0]:= 1X;
	Modules.InstallTermHandler(Term);
	NEW(env); AllocEnv(env, res1)
END ODBC.

System.Free SQL ODBC ~
