--sp_add_cdc.sql

/*****************************************************************
                 -------------------------------------
                 tsqltools - RDS Add CDC
                 -------------------------------------
Description: This stored procedure will help you to enable CDC on 
all the exsiting tables. You have to run this store procedure on the 
database where you need to add the tables. It won't support Cross 
database's tables.
How to Run: If you want to enable CDC on the tables which 
all are in DBAdmin database,
USE DBAdmin
GO
EXEC sp_add_cdc 'DBAdmin'
-------------------------------------------------------------------
Version: v1.0 
Release Date: 2018-02-09
Author: Bhuvanesh(@SQLadmin)
Feedback: mailto:r.bhuvanesh@outlook.com
Updates: https://github.com/SqlAdmin/tsqltools/
Blog: http://www.sqlgossip.com/automatically-enable-cdc-in-rds-sql-server/
License: GPL-3.0
  tsqltools is free to download.It contains Tsql stored procedures 
  and scripts to help the DBAs and Developers to make job easier
(C) 2017
*******************************************************************/  

-- READ THE DESCRIPTION BEFORE EXECUTE THIS ***
IF OBJECT_ID('dbo.sp_add_cdc') IS NULL
  EXEC ('CREATE PROCEDURE dbo.sp_add_cdc AS RETURN 0;');
GO

ALTER PROCEDURE [dbo].[sp_add_cdc]
    @cdcdbname NVARCHAR(100)
as begin
    exec msdb.dbo.rds_cdc_enable_db @cdcdbname
    DECLARE @name VARCHAR(50)
    -- For PrimaryKey Tables
    DECLARE primary_tbl_cursor CURSOR FOR  
SELECT t1.table_name
    FROM INFORMATION_SCHEMA.TABLES t1
        Join INFORMATION_SCHEMA.TABLE_CONSTRAINTS t2 on t1.TABLE_NAME=t2.TABLE_NAME
        Join sys.tables t3 on t1.table_name = t3.name
    WHERE t1.TABLE_TYPE='BASE TABLE' and t2.CONSTRAINT_TYPE='PRIMARY KEY' and t1.table_schema !='cdc' and t3.is_tracked_by_cdc=0;
    OPEN primary_tbl_cursor
    FETCH NEXT FROM primary_tbl_cursor INTO @name
    WHILE @@FETCH_STATUS = 0   
BEGIN
        declare @primary int = 1
        declare @p_schema nvarchar(100)=(select table_schema
        FROM INFORMATION_SCHEMA.TABLES
        where TABLE_NAME=@name)
        declare @p_tbl nvarchar(100)=(select table_name
        FROM INFORMATION_SCHEMA.TABLES
        where TABLE_NAME=@name)
        exec sys.sp_cdc_enable_table 
@source_schema = @p_schema, 
@source_name = @p_tbl, 
@role_name = NULL, 
@supports_net_changes = @primary

        FETCH NEXT FROM primary_tbl_cursor INTO @name
    END
    CLOSE primary_tbl_cursor
    DEALLOCATE primary_tbl_cursor

    -- For Non-PrimaryKey Tables

    DECLARE nonprimary_cursor CURSOR FOR  
SELECT table_name
    FROM INFORMATION_SCHEMA.TABLES Join sys.tables t3 on table_name = t3.name
    where TABLE_NAME not in (select table_name
        from INFORMATION_SCHEMA.TABLE_CONSTRAINTS) and table_schema !='cdc' and TABLE_NAME !='systranschemas' and t3.is_tracked_by_cdc=0;

    OPEN nonprimary_cursor
    FETCH NEXT FROM nonprimary_cursor INTO @name
    WHILE @@FETCH_STATUS = 0   
BEGIN
        declare @n_primary int = 0
        declare @n_schema nvarchar(100)=(select table_schema
        FROM INFORMATION_SCHEMA.TABLES
        where TABLE_NAME=@name)
        declare @n_tbl nvarchar(100)=(select table_name
        FROM INFORMATION_SCHEMA.TABLES
        where TABLE_NAME=@name)
        exec sys.sp_cdc_enable_table 
@source_schema = @n_schema, 
@source_name = @n_tbl, 
@role_name = NULL, 
@supports_net_changes = @n_primary

        FETCH NEXT FROM nonprimary_cursor INTO @name
    END
    CLOSE nonprimary_cursor
    DEALLOCATE nonprimary_cursor
END


-----sp_auto_cdc.sql


/*****************************************************************
                 -------------------------------------
                 tsqltools - RDS - Auto CDC
                 -------------------------------------
Description: This stored procedure will help you to enable CDC 
automatically when a tables is created. This is basically a database
Trigger and it'll ecxecute enable CDC procedure when we creat a 
new table. This is a database level trigger, so it won't replicate
the new tables which are in another database.
How to Run: If you to enable this on DBAdmin database, 
USE DBAdmin
GO
-- Execute the below Query.
-------------------------------------------------------------------
Version: v1.0 
Release Date: 2018-02-10
Author: Bhuvanesh(@SQLadmin)
Feedback: mailto:r.bhuvanesh@outlook.com
Updates: https://github.com/SqlAdmin/tsqltools/
Blog: http://www.sqlgossip.com/automatically-enable-cdc-in-rds-sql-server/
License: GPL-3.0
  tsqltools is free to download.It contains Tsql stored procedures 
  and scripts to help the DBAs and Developers to make job easier
(C) 2018
*******************************************************************/  

-- READ THE DESCRIPTION BEFORE EXECUTE THIS ***

CREATE TABLE [dbo].[DBSchema_Change_Log]
(
    [RecordId] [int] IDENTITY(1,1) NOT NULL,
    [EventTime] [datetime] NULL,
    [LoginName] [varchar](50) NULL,
    [UserName] [varchar](50) NULL,
    [DatabaseName] [varchar](50) NULL,
    [SchemaName] [varchar](50) NULL,
    [ObjectName] [varchar](50) NULL,
    [ObjectType] [varchar](50) NULL,
    [DDLCommand] [varchar](max) NULL

) ON [PRIMARY]
GO

CREATE TRIGGER [auto_cdc] ON Database
FOR CREATE_TABLE  
AS 
DECLARE       @eventInfo XML 
SET           @eventInfo = EVENTDATA() 
INSERT INTO DBSchema_Change_Log
VALUES
    (
        REPLACE(CONVERT(VARCHAR(50),@eventInfo.query('data(/EVENT_INSTANCE/PostTime)')),'T', ' '),
        CONVERT(VARCHAR(50),@eventInfo.query('data(/EVENT_INSTANCE/LoginName)')),
        CONVERT(VARCHAR(50),@eventInfo.query('data(/EVENT_INSTANCE/UserName)')),
        CONVERT(VARCHAR(50),@eventInfo.query('data(/EVENT_INSTANCE/DatabaseName)')),
        CONVERT(VARCHAR(50),@eventInfo.query('data(/EVENT_INSTANCE/SchemaName)')),
        CONVERT(VARCHAR(50),@eventInfo.query('data(/EVENT_INSTANCE/ObjectName)')),
        CONVERT(VARCHAR(50),@eventInfo.query('data(/EVENT_INSTANCE/ObjectType)')),
        CONVERT(VARCHAR(MAX),@eventInfo.query('data(/EVENT_INSTANCE/TSQLCommand/CommandText)')) 
) 
 
declare @tbl varchar(100) =(select top(1)
    OBJECTname
from DBSchema_Change_Log
order by recordid desc)
 DECLARE @schemaname varchar(100) =(select top(1)
    schemaname
from DBSchema_Change_Log
order by recordid desc)
DECLARE @primarykey int =( select case CONSTRAINT_TYPE when 'PRIMARY KEY' THen 1   else 0 end as PRIMARYkey
from INFORMATION_SCHEMA.TABLE_CONSTRAINTS
where TABLE_NAME=@tbl and TABLE_SCHEMA=@schemaname)
 
exec sys.sp_cdc_enable_table 
@source_schema = @schemaname, 
@source_name = @tbl, 
@role_name = NULL, 
@supports_net_changes = @primarykey 
GO
--Enable the Trigger 
ENABLE TRIGGER [auto_cdc] ON database
GO
 
