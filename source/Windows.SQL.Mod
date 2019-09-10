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

MODULE SQL; (** non-portable / source: Windows.SQL.Mod *)	(** MAD  **)

IMPORT ODBC, Modules, KernelLog, SYSTEM, Files, Kernel, Heaps;

CONST
	NTS = -3;
	DataAtExec = -2;
	BlockSize = 1024;

	(** result codes **)
	Error* = -1;	(** error occured while executin last operation **)
	Success* = 0;	(** last operation completed successfully **)
	SuccessWithInfo* = 1;	(** last operation completed successfully, but information available with EnumErrors **)
	NeedData* = 99;	(** execution of statement needs more data, eg not all paramters bound to statement **)
	NoDataFound* = 100;	(** Fetch could not retrieve more data **)

	(** parameter types used for ParamType.inOut **)
	InParam* = 1;	(** parameter used only for input, ie to put data into database **)
	InOutParam* = 2;	(** parameter used both for input and output **)
	OutParam* = 4;	(** parameter used only for output, ie. to retrieve data from database **)

	(** SQL data types **)
	SqlBitType* = -7;	(** single bit binary data **)
	SqlTinyIntType* = -6;	(** SIGNED8 **)
	SqlBigIntType* = -5;	(** 64 bit integer data **)
	SqlLongVarBinaryType* = -4;	(** variable length binary data, maximum length is data source dependant **)
	SqlVarBinaryType* = -3;	(** variable length binary data of maximum length n (1 <= n <= 255) **)
	SqlBinaryType* = -2;	(** binary data of fixed length n (1<= n <=255) **)
	SqlLongVarCharType* = -1;	(** variable length character data, maximum length is data source dependant **)
	SqlCharType* = 1;	(** character string of fixed length n (1 <= n <= 254) **)
	SqlNumericType* = 2;	(** signed exact numeric value with a precision p and scale s (1<=p<=15, 0<=s<=p) **)
	SqlDecimalType* = 3;	(** signed exact numeric value with a precision p and scale s (1<=p<=15, 0<=s<=p) **)
	SqlLongIntType* = 4;	(** SIGNED32 **)
	SqlIntType* = 5;	(** SIGNED16 **)
	SqlFloatType* = 6;	(** FLOAT64 **)
	SqlRealType* = 7;	(** FLOAT32 **)
	SqlLongRealType* = 8;	(** FLOAT64 **)
	SqlDateType* = 9;	(** date data (yyyy-mm-dd) **)
	SqlTimeType* = 10;	(** time data (hh:mm:ss) **)
	SqlTimeStampType* = 11;	(** date/time data (yyyy-mm-dd hh:mm:ss[f..]) **)
	SqlVarCharType* = 12;	(** variable length character string with maximum string length n (1 <= n <= 254) **)

	(** Oberon data types **)
	CharType* = 1;	(* SqlCharType *)
	LongIntType* = 4;	(* SqlLongIntType *)
	IntType* = 5;	(* SqlIntType *)
	ShortIntType* = -6;	(* SqlTinyIntType *)
	RealType* = 7;	(* SqlRealType *)
	LongRealType* = 8;	(* SqlLongRealType *)
	DateType* = 9;	(* SqlDateType *)
	TimeType* = 10;	(*SqlTimeType *)
	TimeStampType* = 11;	(* SqlTimeStampType *)
	FileType* = -4;	(* SqlLongVarBinaryType *)
	BinaryType* = -2;	(* SqlBinaryType *)
	BooleanType* = -7;	(* SqlBitType *)

	(** All these came from FreePascal  *)

    FetchNext* = 1;
    FetchFirst* = 2;
    FetchLast* = 3;
    FetchPrevious* = 4;
    FetchAbsolute* = 5;
    FetchRelative* = 6;

    SQLAttrCursorScrollable = -(1);
	SQLNonScrollable = 0;
    SQLScrollable = 1;

    SQLAttrODBCCursors = 110;
    SQLCursorUseIfNeeded = 0;
    SQLCursorUseODBC = 1;
    SQLCursorUseDriver = 2;


TYPE
	(** enumerate procedure used for EnumDataSources and EnumDrivers **)
	SourcesHandler* = PROCEDURE(name, desc: ARRAY OF CHAR);

	(** enumerate procedure used for EnumErrors **)
	ErrorProc* = PROCEDURE(state, msg: ARRAY OF CHAR; errorcode: SIGNED32);

	(** database connection handle **)
	Connection* = POINTER TO ConnectionDesc;

	(** SQL statement handle **)
	Statement* = POINTER TO StatementDesc;

	(** row handle
	Whenever you prepare a SQL statement that delievers any data (SELECT statement) a Row is created. A Row contains
	a list of records which are extensions of a base type Field. Each such Field in the Row represents a column in the
	result set of the SQL statement, so they are used to access the data. The data in a result row only valid after
	executing the statement (Execute) and fetching data (Fetch).
	A Row must also be created if you want to execute a SQL statement which needs some parameters, ie. if you call
	a stored procedure or execute an INSERT statement with data at execution (for example"INSERT INTO person
	VALUES (?, ?)" where the question marks signal that the corresponding data is set in the parameter row). This
	parameter row must be created with the rocedure BindParamaters after a call to PrepareStataement and before
	you execute the statement with with procedure Execute. The data in a parameter row muts be set before executing
	the statement, and if a parameter is used to get it data the retrieved data is valid after executing the statement **)
	Row* = POINTER TO RowDesc;

	ErrBuff = POINTER TO ErrBuffDesc;

	ConnectionDesc = RECORD
			hdbc: ODBC.HDBC;
			closed: BOOLEAN;
			stmt: Statement;
			res*: SIGNED16;
		END;

	StatementDesc = RECORD
			next: Statement;
			hstmt: ODBC.HSTMT;
			c: Connection;
			results, params: Row;
			firstExec, errBuffered: BOOLEAN;
			error: ErrBuff;
			res*: SIGNED16;
		END;

	ErrBuffDesc = RECORD
			state: ARRAY 6 OF CHAR;
			msg: ARRAY 512 OF CHAR;
			native: SIGNED32;
			next: ErrBuff
		END;

	(** base type of each field in a result set or a parameter list **)
	Field* = POINTER TO FieldDesc;
	FieldDesc* = RECORD
			next, prev: Field;
			dir: SIGNED16;	(* in/out/inout *)
			name*: ARRAY 32 OF CHAR;	(** name of column **)
			len*: SIGNED32;	(** maximum number of characters needed to represent data, only valid for Fields in a result set
												(ie. not for parameters), and only between a call to PrepareStatement and Execute **)
			sqlType*: SIGNED16;	(** SQL type of column (needed because different SQL types are mapped into same
													field type) **)
			isNull*: BOOLEAN;	(** get/set if field is NULL **)
			nullable*: BOOLEAN	(** determine if field is nullable **)
		END;

	(** field extension to hold integer data **)
	IntField* = POINTER TO IntFieldDesc;
	IntFieldDesc* = RECORD(FieldDesc)
			i*: SIGNED32
		END;

	(*ALEX 2005.10.20*)
	(** field extension to hold character data for numeric(n,m) fields **)
	NumericField* = POINTER TO NumericFieldDesc;
	NumericFieldDesc* = RECORD(FieldDesc)
			str*: ARRAY 256 OF CHAR
		END;


	(** field extension to hold character data (SQLCharType and SQLVarCharType) **)
	StringField* = POINTER TO StringFieldDesc;
	StringFieldDesc* = RECORD(FieldDesc)
			str*: ARRAY 256 OF CHAR
		END;

	(** field extension to hold floating point data (SQLFloatType, SQLRealType and SQLLongRealType) **)
	RealField* = POINTER TO RealFieldDesc;
	RealFieldDesc* = RECORD(FieldDesc)
			r*: FLOAT64
		END;

	(** field extension to hold date (SQLDateType) **)
	DateField* = POINTER TO DateFieldDesc;
	DateFieldDesc* = RECORD(FieldDesc)
			year*, month*, day*: SIGNED16
		END;

	(** field extension to hold time (SQLTimeType) **)
	TimeField* = POINTER TO TimeFieldDesc;
	TimeFieldDesc* = RECORD(FieldDesc)
			hour*, minute*, second*: SIGNED16
		END;

	(** field extension to hold time stamp (SQLTimeStampType) **)
	TimeStampField* = POINTER TO TimeStampFieldDesc;
	TimeStampFieldDesc* = RECORD(FieldDesc)
			year*, month*, day*, hour*, minute*, second*: SIGNED16;
			fraction*: SIGNED32
		END;

	(** field extension to hold long data like SQLLongVarCharType or SQLLongBinaryType **)
	FileField* = POINTER TO FileFieldDesc;
	FileFieldDesc* = RECORD(FieldDesc)
			f*: Files.File
		END;

	(** field extension to hold binary data **)
	BinaryField* = POINTER TO BinaryFieldDesc;
	BinaryFieldDesc* = RECORD(FieldDesc)
			b*: ARRAY 256 OF SYSTEM.BYTE
		END;

	(** field extension to hold boolean data **)
	BooleanField* = POINTER TO BooleanFieldDesc;
	BooleanFieldDesc* = RECORD(FieldDesc)
			b*: BOOLEAN
		END;

	SentinelField = POINTER TO SentinelFieldDesc;
	SentinelFieldDesc = RECORD(FieldDesc)
		END;

	(** handle for SQL statement results and parameters **)
	RowDesc* = RECORD
			dsc: Field;
			cols*: SIGNED16
		END;

	(** parameter description record **)
	ParamType* = RECORD
			oberonType*, sqlType*, inOut*: SIGNED16;
			name*: ARRAY 32 OF CHAR;
		END;

VAR
	(** result code of last operation **)
	(*res*: SIGNED16;*)

(* ----------------------- Row handling ----------------------- *)

PROCEDURE AllocRow(VAR row: Row);
	VAR sentinel: SentinelField;
BEGIN
	NEW(row); NEW(sentinel); row.dsc:= sentinel;
	sentinel.next:= sentinel; sentinel.prev:= sentinel
END AllocRow;

PROCEDURE AppendField(r: Row; f: Field);
BEGIN
	r.dsc.prev.next:= f; f.prev:= r.dsc.prev; f.next:= r.dsc; r.dsc.prev:= f
END AppendField;

(** set f to first field in row r **)
PROCEDURE FirstField*(r: Row; VAR f: Field);
BEGIN
	IF r.dsc.next = r.dsc THEN f:= NIL ELSE f:= r.dsc.next END
END FirstField;

(** get next field in row containing f, NIL if there are no more fields **)
PROCEDURE NextField*(VAR f: Field);
BEGIN
	IF f.next IS SentinelField THEN f:= NIL ELSE f:=f.next END
END NextField;

(** get previous field in row containing f, NIL if there is no previous field **)
PROCEDURE PrevField*(VAR f: Field);
BEGIN
	IF f.prev IS SentinelField THEN f:= NIL ELSE f:= f.prev END
END PrevField;

(** find field named name in row r **)
PROCEDURE FindField*(r: Row; name: ARRAY OF CHAR; VAR f: Field);
	VAR cur: Field;
BEGIN
	cur:= r.dsc.next;
	WHILE ~(cur IS SentinelField) DO
		IF cur.name = name THEN f:= cur; RETURN END;
		cur:= cur.next
	END;
	f:= NIL
END FindField;

(* -------------------------------------------------------------------------- *)

PROCEDURE PrintError(state, msg: ARRAY OF CHAR; errorCode: SIGNED32);
BEGIN
	KernelLog.String(state); KernelLog.String(msg); KernelLog.Ln
END PrintError;

PROCEDURE DummyEnum(state, msg: ARRAY OF CHAR; code: SIGNED32);
END DummyEnum;

PROCEDURE InsertError(stmt: Statement; state, msg: ARRAY OF CHAR; nativeCode: SIGNED32);
	VAR err: ErrBuff;
BEGIN
	NEW(err); stmt.errBuffered:= TRUE; err.next:= stmt.error; stmt.error:= err;
	COPY(state, err.state); COPY(msg, err.msg); err.native:= nativeCode
END InsertError;

(** enumerate all errors belonging to connection c and statement s. IF s = NIL and c # NIL then all errors for
	connection c are enumerated. If both s and c are NIL then all errors belonging to SQL and ODBC themselves
	are enumerated **)
PROCEDURE EnumErrors*(c: Connection; s: Statement; enum: ErrorProc);
	VAR localErr: ErrBuff; errorState: ARRAY 6 OF CHAR; errorMsg: ARRAY 512 OF CHAR; nativeError: SIGNED32;
BEGIN
	IF s # NIL THEN
		IF s.errBuffered THEN
			localErr:= s.error;
			WHILE localErr # NIL DO
				enum(s.error.state, s.error.msg, s.error.native); localErr:= localErr.next
			END;
			s.errBuffered:= FALSE; s.error:= NIL
		END;
		ODBC.StatementError(s.hstmt, errorState, nativeError, errorMsg, s.res);
		WHILE s.res # 100 DO
			enum(errorState, errorMsg, nativeError);
			ODBC.StatementError(s.hstmt, errorState, nativeError, errorMsg, s.res);
		END;
		ODBC.ConnectionError(s.c.hdbc, errorState, nativeError, errorMsg, s.res);
		WHILE s.res # 100 DO
			enum(errorState, errorMsg, nativeError);
			ODBC.ConnectionError(s.c.hdbc, errorState, nativeError, errorMsg, s.res);
		END
	ELSIF c # NIL THEN
		ODBC.ConnectionError(c.hdbc, errorState, nativeError, errorMsg, c.res);
		WHILE c.res # 100 DO
			enum(errorState, errorMsg, nativeError);
			ODBC.ConnectionError(c.hdbc, errorState, nativeError, errorMsg, c.res);
		END
	END
END EnumErrors;

PROCEDURE FinalizeConnection(obj: ANY);
	VAR c: Connection;
BEGIN
	c:= obj(Connection); KernelLog.String("SQL.FinalizeConnection: ");
	IF ~c.closed THEN
		KernelLog.String("closing connection"); KernelLog.Ln;
		ODBC.Commit(c.hdbc, c.res);
		ODBC.Disconnect(c.hdbc, c.res);
		ODBC.FreeConnect(c.hdbc, c.res)
	ELSE
		KernelLog.String("connection already closed"); KernelLog.Ln
	END
END FinalizeConnection;

PROCEDURE Terminate;
BEGIN
	(* call garbage collector to finalize all registered connections *)
	KernelLog.String("SQL.Terminate: calling Kernel.GC"); KernelLog.Ln;
	Kernel.GC;
	KernelLog.String("SQL.Terminate: calling Kernel.GC a second time"); KernelLog.Ln;
	Kernel.GC
END Terminate;

(** open a connection to database source  **)
PROCEDURE Open*(source, user, passwd: ARRAY OF CHAR): Connection;
	VAR connect: ODBC.HDBC; connection: Connection;
	finalizerNode: Heaps.FinalizerNode;
BEGIN
	NEW(connection); NEW(connection.hdbc); connection.stmt:= NIL; connection.closed:= FALSE;
	ODBC.AllocConnect(connection.hdbc, connection.res);
	ODBC.SetConnectAttr(connection.hdbc, SQLAttrODBCCursors, SQLCursorUseODBC, 0, connection.res);
	ODBC.Connect(connection.hdbc, source, user, passwd, connection.res);
	(*ALEX 2005.11.14*)
	NEW(finalizerNode); finalizerNode.finalizer := FinalizeConnection;
	Heaps.AddFinalizer(connection, finalizerNode);

	RETURN connection
END Open;

(** close a connection **)
PROCEDURE Close*(c: Connection);
	VAR stmt: Statement;
BEGIN
	(* Free all statements, disconnect and free connection *)
	stmt:= c.stmt; c.closed:= TRUE;
	(*
	WHILE stmt # NIL DO
		ODBC.FreeStmt(stmt.hstmt, 1); stmt:= stmt.next	(* opt = 1: drop statement and all resources associated with it *)
	END;
	*)
	ODBC.Disconnect(c.hdbc, c.res);
	ODBC.FreeConnect(c.hdbc, c.res);
END Close;

(** bind parameter fields to statement s. The array types contains a description of each paramete:
		types[i].oberonType determines the type to be used in Obeorn, ie. what sort of Field (IntField, FielField, etc) should
			be added to paramRow
		types[i].sqlType determines the type the parameter uses in the data source (SqlInt, SqlLongVarBinary, etc)
		types[i].inOut determines for which operation the parameter is used: to put data into the DB -> InParam (parameter
			is used in an INSERT statement or in a stored procedure), to retrieve data from the DB -> OutParam (parameter is
			used in a stored procedure the get data), or to put and get data -> InOutParam (parameter is used in a stored
			procedure for input an output)
		types[i].name can be used to name the parameter, ie you can find the corresponding Field in paramRow with
			the procedure FindField
	A row containing a Field for each parameter is returned in paramRow **)
PROCEDURE BindParameters*(s: Statement; types: ARRAY OF ParamType; numParams: SIGNED16; VAR paramRow: Row);
	TYPE arr6 = ARRAY 6 OF CHAR; arr16 = ARRAY 16 OF CHAR;
	VAR i, parType: SIGNED16; if: IntField; sf: StringField; rf: RealField; df: DateField; tf: TimeField; tsf: TimeStampField;
		ff: FileField; bf: BinaryField; boolf: BooleanField; buffer: ARRAY BlockSize OF CHAR;
BEGIN
	AllocRow(s.params); s.params.cols:= numParams;
	FOR i:= 0 TO numParams-1 DO
		(* insert field into params row of statement *)
		(* Out.String("binding param "); Out.Int(i+1, 1); Out.Ln; *)
		CASE types[i].oberonType OF
			CharType:
				NEW(sf); AppendField(s.params, sf);
				ODBC.BindParameter(s.hstmt, i+1, types[i].inOut, types[i].oberonType, types[i].sqlType, 255, 0, sf.str, sf.len, s.res)
				(* sf.len will be set to NTS before executing the statement *)

			| LongIntType, IntType, ShortIntType:
				NEW(if); AppendField(s.params, if);
				ODBC.BindParameter(s.hstmt, i+1, types[i].inOut, types[i].oberonType, types[i].sqlType, 0, 0, if.i, if.len, s.res)

			| RealType, LongRealType:
				NEW(rf); AppendField(s.params, rf);
				ODBC.BindParameter(s.hstmt, i+1, types[i].inOut, types[i].oberonType, types[i].sqlType, 0, 0, rf.r, rf.len, s.res)

			| DateType:
				NEW(df); AppendField(s.params, df);
				ODBC.BindParameter(s.hstmt, i+1, types[i].inOut, types[i].oberonType, types[i].sqlType, 0, 0,
					df, df.len, s.res)

			| TimeType:
				NEW(tf); AppendField(s.params, tf);
				ODBC.BindParameter(s.hstmt, i+1, types[i].inOut, types[i].oberonType, types[i].sqlType, 0, 0,
					tf, tf.len, s.res)

			| TimeStampType:
				NEW(tsf); AppendField(s.params, tsf);
				ODBC.BindParameter(s.hstmt, i+1, types[i].inOut, types[i].oberonType, types[i].sqlType, 0, 0,
					tsf, tsf.len, s.res)

			| FileType:
				NEW(ff); ff.f:= Files.New(""); AppendField(s.params, ff);
				(* to be compatible with drivers which don't have convert functions, require that the data in file
					is already in right format *)
				IF (types[i].sqlType = SqlVarCharType) OR (types[i].sqlType = SqlLongVarCharType) THEN
					parType:= CharType
				ELSIF (types[i].sqlType = SqlVarBinaryType) OR (types[i].sqlType = SqlLongVarBinaryType) THEN
					parType:= BinaryType
				ELSIF (types[i].sqlType = SqlFloatType) THEN
					parType:= RealType
				ELSIF (types[i].sqlType = SqlNumericType) OR (types[i].sqlType = SqlDecimalType) THEN
					parType:= CharType
				ELSIF types[i].sqlType = SqlBigIntType THEN
					parType:= CharType
				ELSE
					parType:= types[i].sqlType
				END;
				ODBC.BindParameter(s.hstmt, i+1, types[i].inOut, parType, types[i].sqlType, (*BlockSize*) 0, 0, buffer, ff.len, s.res)
				(* ff.len will be set to DataAtExec before executing the statement *)

			| BinaryType:
				NEW(bf); AppendField(s.params, bf);
				ODBC.BindParameter(s.hstmt, i+1, types[i].inOut, types[i].oberonType, types[i].sqlType, 255, 0, bf.b, bf.len, s.res)

			| BooleanType:
				NEW(boolf); AppendField(s.params, boolf);
				ODBC.BindParameter(s.hstmt, i+1, types[i].inOut, types[i].oberonType, types[i].sqlType, 255, 0, boolf.b, boolf.len, s.res)

		ELSE HALT(99)
		END;
		s.params.dsc.prev.dir:= types[i].inOut; COPY(types[i].name, s.params.dsc.prev.name);
		IF s.res < 0 THEN s.params:= NIL; paramRow:= NIL; (* EnumErrors(s.c, s, PrintError); *) RETURN END
	END;
	paramRow:= s.params
END BindParameters;

(** prepares a SQL statement for execution. If sqlStatement returns any results (eg. a SELECT-statement) resultRow
	will point to row conataining a field for every element of the result set, else row is set to NIL. After PrepareStatement
	the record field len of each element of resultRow contains the maximum number of characters needed to represent
	the corresponding data. The value in this record field len will only be valid until a call to Execute, so if you need
	this data you must check it between the calls to PrepareStatement and to Execute. **)
PROCEDURE PrepareStatement*(c: Connection; sqlStatement: ARRAY OF CHAR; VAR resultRow: Row): Statement;
	TYPE arr6 = ARRAY 6 OF CHAR; arr16 = ARRAY 16 OF CHAR;
	VAR stmt: Statement; cols, i, type, scale, oldres: SIGNED16; name: ARRAY 256 OF CHAR; nullable: BOOLEAN;
		prec, nativeBuf: SIGNED32; stateBuf: ARRAY 6 OF CHAR; msgBuf: ARRAY 512 OF CHAR;
		if: IntField; sf: StringField; rf: RealField; df: DateField; tf: TimeField; tsf: TimeStampField; cur: Field;
		bf: BinaryField; ff: FileField; boolf: BooleanField;
		nf: NumericField;
BEGIN
	NEW(stmt); NEW(stmt.hstmt); ODBC.AllocStmt(c.hdbc, stmt.hstmt, stmt.res);
	stmt.next:= c.stmt; c.stmt:= stmt;
	stmt.c:= c; stmt.results:= NIL; stmt.params:= NIL; stmt.firstExec:= TRUE; stmt.errBuffered:= FALSE; resultRow:= NIL;

	(*ALEX 2005.12.06 - commented out because of sybase not suporting this property*)
	(*
	ODBC.SetStmtAttr(stmt.hstmt, SQLAttrCursorScrollable, SQLScrollable, 0, stmt.res);
	IF stmt.res #  Success THEN
		KernelLog.String('SetStmtAttr:ODBC.res: '); KernelLog.Int(stmt.res,0); KernelLog.Ln;
		EnumErrors(c, stmt, PrintError)
	END;
	*)

	ODBC.Prepare(stmt.hstmt, sqlStatement, stmt.res);
	IF stmt.res < 0 THEN
		RETURN stmt
	ELSE
		(* As the Prepare function is not guaranteed to do the same work on all the different ODBC database drivers
			it is not always sufficient calling ODBC.Prepare to get all needed information about the result set. So we also
			need to make a call to ODBC.Execute. Afterwards a call to ODBC.NumResultCols and ODBC.DescribeCol
			should work with every ODBC database (except MicroSoft included some other features) *)
		ODBC.Execute(stmt.hstmt, stmt.res);
		IF stmt.res < 0 THEN
			(* check why error occured: if parameters are missing (state = 07001) just ignore error, else buffer error and
			exit prepare *)
			(* Out.String("ODBC.res = "); Out.Int(ODBC.res, 1); Out.Ln; *)
			oldres:= stmt.res; ODBC.StatementError(stmt.hstmt, stateBuf, nativeBuf, msgBuf, stmt.res);
			(* Out.String("Error in PrepareStatement: "); Out.Ln; Out.String(stateBuf); Out.String(msgBuf); Out.Ln; *)
			IF stateBuf = "07001" THEN
				(* ignore error, but read remaining errors of statement *)
				(* Out.String("error ignored, continuing PrepareStatement"); Out.Ln; *)
				EnumErrors(c, stmt, DummyEnum); stmt.errBuffered:= FALSE; stmt.firstExec:= FALSE
			ELSE
				(* 'real' error *)
				(* Out.String("aborting PrepareStatement"); Out.Ln; *)
				stmt.errBuffered:= TRUE; NEW(stmt.error);
				COPY(stateBuf, stmt.error.state); COPY(msgBuf, stmt.error.msg); stmt.error.native:= nativeBuf;
				stmt.firstExec:= FALSE; stmt.res:= oldres; RETURN stmt
			END
		END;
		ODBC.NumResultCols(stmt.hstmt, cols, stmt.res);
		IF cols > 0 THEN
			AllocRow(resultRow); resultRow.cols:= cols;
			(* Out.String("Anzahl ResultCols: "); Out.Int(cols, 5); Out.Ln; *)
			FOR i:= 1 TO cols DO
				ODBC.DescribeCol(stmt.hstmt, i, name, type, prec, scale, nullable, stmt.res);
				(* Out.String(name); Out.Char(9X); Out.Int(type, 5); Out.Char(9X); Out.Int(prec, 5); Out.Char(9X);
				Out.Int(scale, 5); Out.Char(9X); IF nullable THEN Out.String("nullable") ELSE Out.String("not nullable") END;
				Out.Ln; *)
				CASE type OF
					1, 12: NEW(sf); AppendField(resultRow, sf); sf.len:= prec;
						ODBC.BindCol(stmt.hstmt, i, CharType, sf.str, sf.len, stmt.res);

					| 2, 3: NEW(nf); AppendField(resultRow, nf); nf.len:= prec + 2; (* prec digits, sign, decimal point *)
						ODBC.BindCol(stmt.hstmt, i, CharType, nf.str, nf.len, stmt.res);
						(*ALEX 2005.10.20 modified from StringField to NumericField*)

					| 4, 5, -6: NEW(if); AppendField(resultRow, if);
						IF type = 4 THEN if.len:= 11 ELSIF type = 5 THEN if.len:= 6 ELSE if.len:= 4 END;
						ODBC.BindCol(stmt.hstmt, i, LongIntType, if.i, if.len, stmt.res);

					| 6, 7, 8: NEW(rf); AppendField(resultRow, rf);
						IF type = 7 THEN rf.len:= 13 ELSE rf.len:= 22 END;
						ODBC.BindCol(stmt.hstmt, i, LongRealType, rf.r, rf.len, stmt.res);

					| 9: NEW(df); AppendField(resultRow, df); df.len:= prec;
						ODBC.BindCol(stmt.hstmt, i, DateType, df, df.len, stmt.res);

					| 10: NEW(tf); AppendField(resultRow, tf); tf.len:= prec;
						ODBC.BindCol(stmt.hstmt, i, TimeType, tf, tf.len, stmt.res);

					| 11: NEW(tsf); AppendField(resultRow, tsf); IF scale > 0 THEN tsf.len:= 20+scale ELSE tsf.len:= 19 END;
						ODBC.BindCol(stmt.hstmt, i, TimeStampType, tsf, tsf.len, stmt.res);

					| -2, -3: NEW(bf); AppendField(resultRow, bf); bf.len:= prec;
						ODBC.BindCol(stmt.hstmt, i, LongIntType, bf.b, bf.len, stmt.res);

					| -1, -4: NEW(ff); ff.f:= Files.New(""); AppendField(resultRow, ff); ff.len:= prec;
						(* don't bind this column, but get the data with ODBC.GetData *)
						(* ODBC.BindCol(stmt.hstmt, i, LongIntType, ff.f, ff.len); *)

					| -5: NEW(sf); AppendField(resultRow, sf); sf.len:= 20;
						ODBC.BindCol(stmt.hstmt, i, CharType, sf.str, sf.len, stmt.res);

					| -7: NEW(boolf); AppendField(resultRow, boolf); boolf.len:= 5;
						ODBC.BindCol(stmt.hstmt, i, LongIntType, boolf.b, boolf.len, stmt.res);

					ELSE HALT(99)
				END;
				resultRow.dsc.prev.sqlType:= type; COPY(name, resultRow.dsc.prev.name);
				resultRow.dsc.prev.nullable:= nullable;
				IF stmt.res < 0 THEN
					resultRow:= NIL; RETURN stmt
				END
			END;	(* FOR *)
			stmt.results:= resultRow;
			(* cur:= resultRow.dsc.next; FOR i:= 1 TO resultRow.cols DO Out.String(cur.name); Out.Ln; cur:= cur.next END; *)
		END	(* IF *)
	END;
	RETURN stmt
END PrepareStatement;

(** execute a previously prepared statement. If the statement delievers any data it can now be retrieved using procedure
	Fetch.
	IMPORTANT: a statement which does not need parameters and does not return any data (for example
	"DROP TABLE MyTable") will take effect even if you don't call Execute for this statement handle **)
PROCEDURE Execute*(s: Statement);
	VAR parDesc, cur: Field; buffer: ARRAY BlockSize OF CHAR; r: Files.Rider; cnt: SIGNED32;
BEGIN
	IF s.firstExec THEN
		(* Out.String("discarding Execute"); Out.Ln; *)
		s.firstExec:= FALSE; RETURN
	END;
	(* Out.String("doing Execute"); Out.Ln; *)
	cur:= s.params.dsc.next;
	WHILE ~(cur IS SentinelField) DO
		IF cur.isNull THEN cur.len:= -1
		ELSIF cur IS StringField THEN cur.len:= NTS
		ELSIF cur IS FileField THEN cur.len:= DataAtExec
		ELSE cur.len:= 0
		END;
		cur:= cur.next
	END;
	ODBC.Execute(s.hstmt, s.res);
	cur:= s.params.dsc.next;
	(* must also put data with ODBC.PutData if there are any FileFields *)
	WHILE s.res = NeedData DO
		ODBC.ParamData(s.hstmt, parDesc^, s.res);
		IF s.res = NeedData THEN
			(* Out.String("needing data"); Out.Ln; *)
			WHILE ~(cur IS SentinelField) & ~(cur IS FileField) DO cur:= cur.next END;
			IF cur IS SentinelField THEN
				KernelLog.String("Warning: Field used for PutData is not a FileField"); KernelLog.Ln; HALT(99)
			ELSIF cur IS FileField THEN
				cnt:= 0; cur(FileField).f.Set(r, 0);
				REPEAT INC(cnt);
					cur(FileField).f.ReadBytes(r, buffer, 0, BlockSize); ODBC.PutData(s.hstmt, buffer, BlockSize-r.res, s.res);
					IF s.res < 0 THEN RETURN END;
					(* Out.Int(cnt, 5); Out.Int(BlockSize-r.res, 5); Out.Ln; Out.String(buffer); *)
				UNTIL r.eof;
				cur:= cur.next;
				(* Out.Ln *)
			END
		ELSE
			(* Out.String("don't need more data, ODBC.res = "); Out.Int(ODBC.res, 1); Out.Ln *)
		END
	END;	(* WHILE *)
	cur:= s.params.dsc.next;
	WHILE ~(cur IS SentinelField) DO
		IF cur.len = -1 THEN cur.isNull:= TRUE ELSE cur.isNull:= FALSE END;
		cur:= cur.next
	END;
END Execute;

(** returns the number of rows affected by the execution of statement s. This is not the number of rows which are
	delievered by a SELECT Statement but rather the number of rows affected by an UPDATE or DELETE statement.
	If you want the number of rows in the result set of a SELECT statement use "SELECT COUNT( * ) .." or increment
	a counter variable after each call to Fetch **)
PROCEDURE RowCount*(s: Statement; VAR rows: SIGNED32);
BEGIN
	ODBC.RowCount(s.hstmt, rows, s.res);
END RowCount;

(** fetch the next result row for statement s (of course statement s must have been executed before you can call
	the procedure Fetch) **)
PROCEDURE Fetch*(s: Statement);
	VAR cur: Field; col: SIGNED16; resSize, actSize: SIGNED32; buffer: ARRAY BlockSize OF CHAR; r: Files.Rider;
BEGIN
	ODBC.Fetch(s.hstmt, s.res);
	IF (s.res < 0) OR (s.res = 100) THEN RETURN END;
	(* now get all unbound columns with ODBC.GetData *)
	FirstField(s.results, cur); col:= 1;
	WHILE ~(cur IS SentinelField) DO
		IF cur IS FileField THEN
			cur(FileField).f := Files.New( "" );	(* Dan 12.10.04 *)
			cur(FileField).f.Set(r,  0);
			REPEAT
				ODBC.GetData(s.hstmt, col, -2, buffer, resSize, s.res);
				IF s.res < 0 THEN
					(* Out.String("Error while fetching data from res col "); Out.Int(col, 1); Out.Ln; *)
					(* EnumErrors(s.c, s, PrintError); *) RETURN
				END;
				IF resSize > LEN(buffer) THEN actSize:= LEN(buffer) ELSE actSize:= resSize END;
				(* Out.Int(actSize, 5); Out.Ln; *)
				IF actSize > 0 THEN cur(FileField).f.WriteBytes(r, buffer, 0, actSize) END; (*ALEX 2006.02.15 added the IF*)
			UNTIL s.res # 1;
			(* Out.String("Filesize: "); Out.Int(Files.Length(cur(FileField).f), 1); Out.Ln *)
		ELSE
		END;
		INC(col); cur:= cur.next
	END;
	cur:= s.results.dsc.next;
	WHILE ~(cur IS SentinelField) DO
		IF cur.len = -1 THEN cur.isNull:= TRUE ELSE cur.isNull:= FALSE END;
		cur:= cur.next
	END;
END Fetch;

(** JSS: fetch the result row for statement s (s must have been executed before you can call
	the procedure ExtendedFetch), based on fetchType and rowToFetch  **)
PROCEDURE FetchExtended*(s: Statement; fetchType: SIGNED16; rowToFetch: SIGNED32; VAR numFetchedRows: SIGNED32; VAR rowStatus: SIGNED16 );
	VAR
		cur: Field;
		col: SIGNED16;
		resSize,
			actSize: SIGNED32;
		(*buffer: ARRAY BlockSize OF SYSTEM.BYTE; *)
		buffer: ARRAY BlockSize OF CHAR;
		r: Files.Rider;

BEGIN
	ODBC.ExtendedFetch(s.hstmt, fetchType, rowToFetch, numFetchedRows, rowStatus, s.res);

	IF (s.res < 0) OR (s.res = 100) THEN RETURN END;
	(* now get all unbound columns with ODBC.GetData *)
	FirstField(s.results, cur); col:= 1;
	WHILE ~(cur IS SentinelField) DO
		IF cur IS FileField THEN
			cur(FileField).f.Set(r, 0);
			REPEAT
				ODBC.GetData(s.hstmt, col, -2, buffer, resSize, s.res);
				IF s.res < 0 THEN
					(* Out.String("Error while fetching data from res col "); Out.Int(col, 1); Out.Ln; *)
					(* EnumErrors(s.c, s, PrintError); *) RETURN
				END;
				IF resSize > LEN(buffer) THEN actSize:= LEN(buffer) ELSE actSize:= resSize END;
				(* Out.Int(actSize, 5); Out.Ln; *)
				IF actSize > 0 THEN cur(FileField).f.WriteBytes(r, buffer, 0, actSize) END; (*ALEX 2006.02.15 added the IF*)
			UNTIL s.res # 1;
			(* Out.String("Filesize: "); Out.Int(Files.Length(cur(FileField).f), 1); Out.Ln *)
		ELSE
		END;
		INC(col); cur:= cur.next
	END;
	cur:= s.results.dsc.next;
	WHILE ~(cur IS SentinelField) DO
		IF cur.len = -1 THEN cur.isNull:= TRUE ELSE cur.isNull:= FALSE END;
		cur:= cur.next
	END;
END FetchExtended;

(** commits all statements for connection c (works only if supported by the database) **)
PROCEDURE Commit*(c: Connection);
BEGIN
	ODBC.Commit(c.hdbc, c.res)
END Commit;

(** rolls back all statements executed since last Commit for connection c (works only if supported by the database)  **)
PROCEDURE Rollback*(c: Connection);
BEGIN
	ODBC.Rollback(c.hdbc, c.res)
END Rollback;

(** enumerates all data sources **)
PROCEDURE EnumDataSources*(enum: SourcesHandler; VAR res: SIGNED16);
	VAR name, desc: ARRAY 256 OF CHAR;
BEGIN
	ODBC.DataSources(2, name, desc, res);
	IF res < 0 THEN RETURN END;
	WHILE res = 0 DO
		enum(name, desc);
		ODBC.DataSources(1, name, desc, res);

		IF res < 0 THEN RETURN END;
	END;
END EnumDataSources;

(** enumerates all installed ODBC database drivers **)
PROCEDURE EnumDrivers*(enum: SourcesHandler; VAR res: SIGNED16);
	VAR name, desc: ARRAY 256 OF CHAR;
BEGIN
	ODBC.Drivers(2, name, desc, res);
	IF res < 0 THEN RETURN END;
	WHILE res = 0 DO
		enum(name, desc);
		ODBC.Drivers(1, name, desc, res);
		IF res < 0 THEN RETURN END;
	END;
END EnumDrivers;

(** prepares statement to retrieve all tables accessible within connection c
	result row:	field name	field type
		TABLE_QUALIFIER	StringField
		TABLE_OWNER	StringField
		TABLE_NAME	StringField
		TABLE_TYPE	StringField	("TABLE", "VIEW", "SYSTEM TABLE", "GLOBAL TEMPORARY"
								"LOCAL TEMPORARY", "ALIAS", "SYNONYM", or data-source specific)
		REMARKS	StringField
**)
PROCEDURE Tables*(c: Connection; VAR row: Row): Statement;
	VAR stmt: Statement; i, cols, type, scale: SIGNED16; if: IntField; sf: StringField; rf: RealField; cur: Field;
		name: ARRAY 256 OF CHAR; prec: SIGNED32; nullable: BOOLEAN;
BEGIN
	NEW(stmt); NEW(stmt.hstmt); ODBC.AllocStmt(c.hdbc, stmt.hstmt, stmt.res); stmt.c:= c; row:= NIL; stmt.firstExec:= TRUE;
	ODBC.Tables(stmt.hstmt, ODBC.nullString, ODBC.nullString, ODBC.nullString, ODBC.nullString, stmt.res);
	IF stmt.res < 0 THEN
		row:= NIL; RETURN stmt
	ELSE
		ODBC.NumResultCols(stmt.hstmt, cols, stmt.res);
		AllocRow(row); row.cols:= cols; stmt.results:= row;
		FOR i:= 1 TO cols DO
			ODBC.DescribeCol(stmt.hstmt, i, name, type, prec, scale, nullable, stmt.res);
			CASE type OF
				1, 12: NEW(sf); AppendField(row, sf);
					ODBC.BindCol(stmt.hstmt, i, CharType, sf.str, sf.len, stmt.res);
				ELSE HALT(99)
			END;
			row.dsc.prev.sqlType:= type; COPY(name, row.dsc.prev.name); row.dsc.prev.nullable:= nullable;
			IF stmt.res < 0 THEN
				row:= NIL; RETURN stmt
			END
		END
	END;
	RETURN stmt
END Tables;

(** retrieve the name of a SQL data type as it is used in the data source connected to by Connection c.
	For example some DBs call a 4 byte integer "LONG", and others call it "INT4". **)
PROCEDURE GetTypeName*(c: Connection; sqlType: SIGNED16; VAR typeName: ARRAY OF CHAR; VAR res: SIGNED16);
	VAR stmt: Statement; len: SIGNED32;
BEGIN
	NEW(stmt); NEW(stmt.hstmt); ODBC.AllocStmt(c.hdbc, stmt.hstmt, stmt.res);
	typeName[0]:= 0X;
	ODBC.GetTypeInfo(stmt.hstmt, sqlType, stmt.res);
	IF stmt.res < 0 THEN
		res:= stmt.res; RETURN
	END;
	ODBC.BindCol(stmt.hstmt, 1, CharType, typeName, len, stmt.res);
	ODBC.Fetch(stmt.hstmt, stmt.res);
	res:= stmt.res
END GetTypeName;

(*ALEX 2006.03.22 added this function*)
(**closes a statement and removes it from the connection statements list*)
PROCEDURE CloseStatement*(s: Statement);
VAR prevStmt, stmt: Statement;
BEGIN
	ODBC.FreeStmt(s.hstmt, 1, s.res);	(* opt = 1: drop statement and all resources associated with it *)
	stmt := s.c.stmt;

	WHILE (stmt # NIL) & (stmt # s) DO
		 prevStmt := stmt; stmt:= stmt.next
	END;
	IF prevStmt # NIL THEN prevStmt.next := s.next ELSE s.c.stmt := s.next END;
END CloseStatement;

BEGIN
	Modules.InstallTermHandler(Terminate)
END SQL.


(**
Remarks:

Before you can execute a SQL statement you need to open a connection to the data source. Use procedure
Open to get a connection. When you no longer need the connection you can close it with Close.

In the following the basic steps used in commonly routines are described. It is assumed that there is already
an open connection

1. A simple SQL statement which needs no input and delievers no output:
	example: "INSERT INTO addresses VALUES ('Markus', 'Dätwyler')"
	- Prepare the statement with PrepareStatement. As the statement retrieves no data, resultRow is NIL.
	- Execute the statement with procedure Execute
	- The number of rows affected by the execution of this statement can be get with procedure RowCount.

2. A SQL statement with retrieves data:
	example: "SELECT * FROM addresses WHERE name = 'Dätwyler' "
	- Prepare the statement with PrepareStatement. A result row containig a field for each column in the table
		addresses is generated.
	- Execute the statement.
	- Retrieve data from the result set with the procedure Fetch. Each call to Fetch delievers the next row in the
		result set. When there is no more data to get when calling Fetch the variable res will be set to NoDataFound.
		After fetching a row the fields containing the data can be accessed using resultRow generated by
		PrepareStatement and the procedures FirstField, NextField, PrevField and FindField.

3. A SQL statement which needs input:
	example: "INSERT INTO addresses VALUES (?, ?)"
	- Prepare the statement with PrepareStatement. As the statement retrieves no data, resultRow is NIL.
	- Create a row to hold the input data of the parameters with procedure BindParameters. paramRow
		will now contain this row.
	- Set the values of the parameters. To access the fields representing the parameters use paramRow and the
		procedures FirstField, NextField, PrevField and FindField.
	- Execute the statement.
	- The number of rows affected by the execution of this statement can be get with procedure RowCount.

4. A SQL statement which needs input and retrieves data:
	example: "SELECT * FROM addresses WHERE name LIKE ?"
	- Prepare the statement with procedure PrepareStatement. resultRow will be created and contain a field
		for each column in the result set.
	- Create a row to hold the parameter values with BindParameters.
	- Set the values of the parameters. Access the parameters using paramRow and FirstField, NextField,
		PrevField and FindField.
	- Execute the statement.
	- Fetch the data from the result set.
**)
