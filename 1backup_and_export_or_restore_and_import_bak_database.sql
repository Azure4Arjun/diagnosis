--1backup_and_export_or_restore_and_import_bak_database.sql

/*www.technical-programming.com, lo sauer 2013
* description: Step by step process to load or save .bak Database backup files
* credits: RameshVel,Tim Partridge for the @fileListTable; StackOverflow
*/

/* Export/Save a Database Backup 
   See: http://technet.microsoft.com/en-us/library/ms186865.aspx
*/
BACKUP DATABASE logicalnameofthedatabase TO DISK = 'c:\physicalnameofthedatabase.bak'

/* ...using compression. Cannot be used with 'COPY_ONLY' and on SQL Server Express editions */
BACKUP DATABASE logicalnameofthedatabase TO DISK = 'c:\physicalnameofthedatabase.bak'
      WITH COMPRESSION

/* Restore/Load a Database Backup 
   See: http://technet.microsoft.com/en-us/library/ms186858.aspx
*/
/* Step 1: First find out the 'LogicalName' of the mdf, ldf to fill in in step 2 */
RESTORE FILELISTONLY FROM DISK = 'c:\physicalnameofthedatabase.bak' 

/* Step 2: */
RESTORE DATABASE logicalnameofthedatabase
FROM DISK = 'c:\physicalnameofthedatabase.bak' 
   WITH MOVE 'MyDbName' To 'c:\database\physicalnameofthedatabase.mdf', 
        MOVE 'MyDbName_log' To 'c:\database\physicalnameofthedatabase.ldf';
 
/* Create and attach the restored database */
USE [master];
CREATE DATABASE 'MyRestoredDB' ON 
  ( FILENAME = n'c:\database\physicalnameofthedatabase.mdf' ),
  ( FILENAME = n'c:\database\physicalnameofthedatabase.ldf' )
  FOR ATTACH ;
  
  
  
  ---2automated_restore_script_for_databases.sql
  
  /*www.technical-programming.com, lo sauer 2013
* description: Script to restore a database from a .bak backup file
* See:Automated Microsoft MS SQL-Server / TSQL: backup and export or restore and import .bak Database backups
*/
DECLARE @physicalnameofthedatabase nvarchar(1000); /* the path to the .bak file*/
SET @physicalnameofthedatabase = 'c:\physicalnameofthedatabase.bak';
DECLARE @logicalnameofthedatabase nvarchar(1000); /* the name of your imported database */
SET @logicalnameofthedatabase = 'MyRestoredDB';
DECLARE @physicalpathofthedatabase nvarchar(1000); /* the path of your imported database */
SET @physicalpathofthedatabase = 'c:\db\physicalnameofthedatabase.mdf';
DECLARE @physicalpathofthelog nvarchar(1000); /* the path of your imported database */
SET @physicalpathofthelog = 'c:\db\physicalnameofthedatabase.log';
/* ------------------------Do not modify below this line ------------------------ */
DECLARE @fileListTable TABLE
(
    LogicalName          nvarchar(128),
    PhysicalName         nvarchar(260),
    [Type]               char(1),
    FileGroupName        nvarchar(128),
    Size                 numeric(20,0),
    MaxSize              numeric(20,0),
    FileID               bigint,
    CreateLSN            numeric(25,0),
    DropLSN              numeric(25,0),
    UniqueID             uniqueidentifier,
    ReadOnlyLSN          numeric(25,0),
    ReadWriteLSN         numeric(25,0),
    BackupSizeInBytes    bigint,
    SourceBlockSize      int,
    FileGroupID          int,
    LogGroupGUID         uniqueidentifier,
    DifferentialBaseLSN  numeric(25,0),
    DifferentialBaseGUID uniqueidentifier,
    IsReadOnl            bit,
    IsPresent            bit,
    TDEThumbprint        varbinary(32) -- remove this column if using SQL 2005
);
INSERT INTO @fileListTable EXECUTE('RESTORE FILELISTONLY FROM DISK = ''' + @physicalnameofthedatabase + '''');
DECLARE @logicalnamedb nvarchar(1000);
DECLARE @logicalnamelog nvarchar(1000);

SET @logicalnamedb = (SELECT LogicalName FROM @fileListTable WHERE Type = 'D');
SET @logicalnamelog = (SELECT LogicalName FROM @fileListTable WHERE Type = 'L');
RESTORE DATABASE @logicalnameofthedatabase
FROM DISK = @physicalnameofthedatabase
     WITH MOVE @logicalnamedb To @physicalpathofthedatabase , 
          MOVE @logicalnamelog To @physicalpathofthelog;
          
/*Create and attach the database*/
USE master;
EXEC('CREATE DATABASE '''+ @logicalnameofthedatabase + ''' ON ( FILENAME = ''' +@physicalpathofthedatabase 
     + ''' ),( FILENAME = '''+ @physicalpathofthelog +''' ) FOR ATTACH');
