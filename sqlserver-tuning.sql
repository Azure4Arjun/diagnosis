DBCC FREEPROCCACHE;

-- -----------------------
-- Find Long Running Query
-- Execute the query inside target database
-- -----------------------
SELECT st.text
, qp.query_plan
, qs.*
FROM (
    SELECT  TOP 100 *
    FROM    sys.dm_exec_query_stats
    ORDER BY total_worker_time DESC
) AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
WHERE qs.max_worker_time > 300
OR qs.max_elapsed_time > 300;


-- -----------------------
-- Find Long Running Query
-- Execute the query inside target database
-- -----------------------
SELECT DISTINCT TOP 100 t.TEXT QueryName
, s.execution_count AS ExecutionCount
, s.max_elapsed_time AS MaxElapsedTime
, ISNULL(s.total_elapsed_time / NULLIF(s.execution_count, 0), 0) AS AvgElapsedTime
, s.creation_time AS LogCreatedOn
, ISNULL(s.execution_count / NULLIF(DATEDIFF(s, s.creation_time, GETDATE()), 0), 0) AS FrequencyPerSec
FROM sys.dm_exec_query_stats s
CROSS APPLY sys.dm_exec_sql_text( s.sql_handle ) t
ORDER BY s.max_elapsed_time DESC, ExecutionCount DESC;

-- -----------------------
-- Find Long Running Query
-- Execute the query inside target database
-- -----------------------
SELECT TOP 100 DB_NAME(qt.dbid) AS database_name
, o.name AS object_name
, qs.total_elapsed_time / qs.execution_count / 1000000.0 AS average_seconds
, qs.total_elapsed_time / 1000000.0 AS total_seconds
, qs.execution_count
, SUBSTRING (qt.text,qs.statement_start_offset/2, 
         (CASE WHEN qs.statement_end_offset = -1 
            THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2 
          ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) AS individual_query
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
LEFT JOIN sys.objects o ON qt.objectid = o.object_id
WHERE qt.dbid = DB_ID()
ORDER BY average_seconds DESC;


-- -----------------------
-- Find Most I/O Query
-- Execute the query inside target database
-- -----------------------
SELECT TOP 100 DB_NAME(qt.dbid) AS database_name
, o.name AS object_name
, (total_logical_reads + total_logical_writes) / qs.execution_count AS average_IO
, (total_logical_reads + total_logical_writes) AS total_IO
, qs.execution_count AS execution_count
, SUBSTRING (qt.text,qs.statement_start_offset/2
, (CASE WHEN qs.statement_end_offset = -1 
            THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2 
          ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) AS indivudual_query
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
LEFT JOIN sys.objects o ON qt.objectid = o.object_id
WHERE qt.dbid = DB_ID()
ORDER BY average_IO DESC;


-- -----------------------
-- Find Long Running Query
-- Query Plans with Scans on Nonclustered Hash Indexes
-- Execute the query inside target database
-- -----------------------
WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sqlx) 
SELECT ProcedureName = IsNull(object_name(st.objectid, st.dbid), N'Ad hoc or object not found')
, qp.query_plan AS QueryPlan
, IndexName = I.n.value('(//sqlx:IndexScan/sqlx:Object/@Index)[1]', 'sysname')
, TableName = I.n.value('(//sqlx:IndexScan/sqlx:Object/@Schema)[1]', 'sysname') + N'.' + I.n.value('(//sqlx:IndexScan/sqlx:Object/@Table)[1]', 'sysname')
, SQLText = I.n.value('(//sqlx:StmtSimple/@StatementText)[1]', 'varchar(max)')
FROM sys.dm_exec_cached_plans AS cp 
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) AS qp 
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) AS st
CROSS APPLY qp.query_plan.nodes('//sqlx:IndexScan[@Storage="MemoryOptimized"]') As I(n)
INNER JOIN sys.hash_indexes HI On Quotename(HI.name) = I.n.value('(//sqlx:IndexScan/sqlx:Object/@Index)[1]', 'sysname')
	AND HI.object_id = OBJECT_ID(I.n.value('(//sqlx:IndexScan/sqlx:Object/@Schema)[1]', 'sysname') + N'.' + I.n.value('(//sqlx:IndexScan/sqlx:Object/@Table)[1]', 'sysname'))
WHERE qp.dbid = DB_ID()
AND I.n.exist('//sqlx:IndexScan/sqlx:Object[@IndexKind="NonClusteredHash"]') = 1;


-- -----------------------
-- Find Long Running Query
-- Execute the query inside target database
-- -----------------------
SELECT SUBSTRING(st.text, (qs.statement_start_offset/2) + 1, 
	( (
		CASE statement_end_offset
		WHEN -1 THEN DATALENGTH(st.text)
		ELSE qs.statement_end_offset END
		- qs.statement_start_offset) / 2
	) + 1
) AS statement_text
, creation_time 
, last_execution_time
, execution_count
, total_worker_time
, total_elapsed_time
, total_elapsed_time / execution_count avg_elapsed_time
, total_physical_reads
, total_logical_reads 
, total_logical_writes
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY total_elapsed_time / execution_count DESC;



-- -----------------------
-- Find Long Running Stored Procedure
-- Execute againts SQL Profiles Trace
-- -----------------------
SELECT ObjectName
, COUNT(*) AS SP_Count
, MIN(Duration) Min_Duration
, MAX(Duration) Max_Duration
, MIN(CPU) Min_CPU_Time
, MAX(CPU) Max_CPU_Time
, SUM(CPU) Sum_CPU_Time
FROM    master.t_trace_2
WHERE   Duration > 300
        AND ObjectName IS NOT NULL
GROUP BY ObjectName
ORDER BY SP_Count DESC

-- -----------------------
-- Find Long Running Query
-- Execute againts SQL Profiles Trace
-- -----------------------
SELECT convert(nvarchar(max),TextData) The_Query
, COUNT(*) AS Query_Count
, MIN(Duration) Min_Duration
, MAX(Duration) Max_Duration
, MIN(CPU) Min_CPU_Time
, MAX(CPU) Max_CPU_Time
, SUM(CPU) Sum_CPU_Time
FROM    master.t_trace_2
WHERE   Duration > 300
        AND ObjectName IS NULL
		AND EventClass = 12
GROUP BY convert(nvarchar(max),TextData)
ORDER BY Query_Count DESC;



-- -----------------------
