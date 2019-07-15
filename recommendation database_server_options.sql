---database settings info.sql

--Last Update: 12/11/2018

IF OBJECT_ID('tempdb..#DBSettings') IS NOT NULL
    BEGIN
	   DROP TABLE #DBSettings;
    END;

select 
	name
,	[compatibility_level]	
,	[dbstate] = case when state_desc = 'online' and is_read_only = 1 then state_desc + ' ' +'(Read-Only)' else state_desc end 		
,	recovery_model_desc
,	page_verify_option_desc
,	user_access_desc				--should be MULTI_USER
,	is_auto_close_on				--should be 0
,	is_auto_shrink_on				--should be 0
,	is_auto_create_stats_on			--should be 1 except for some SharePoint db's
,	is_auto_update_stats_on			--should be 1 except for some SharePoint db's
,	is_auto_update_stats_async_on	--should be 1 except for some SharePoint db's
,	log_reuse_wait
,	log_reuse_wait_desc
,	target_recovery_time_in_seconds
into #DBSettings
from sys.databases;

--Compatibility Level Check
WITH cteDB (Database_Name, [compatibility_level], State, Up_To_Date)
AS (
SELECT 
 	Database_Name			= name
,	[Compatibility Level]	= [compatibility_level] --should be latest (130 = SQL2016, 120 = SQL2014, 110 = SQL2012, 100 = SQL2008, 90 = SQL2005)
,	[State]					= dbstate		
,	Up_To_Date				= CASE WHEN LEFT(convert(char(3), [compatibility_level]),2) <> LEFT(convert(varchar(15), SERVERPROPERTY('ProductVersion')),2) THEN 'Database is in old compatibility mode' ELSE null END
from #DBSettings
)
select
	cteDB.*
,	[SQL Server Version]	= SERVERPROPERTY('ProductVersion')
,	[Alter]					= CASE WHEN Up_To_Date is not null THEN 'ALTER DATABASE [' + Database_Name +'] SET COMPATIBILITY_LEVEL = ' + LEFT(convert(varchar(15), SERVERPROPERTY('ProductVersion')),2) + '0;' ELSE NULL END
,	[Revert]				= CASE WHEN Up_To_Date is not null THEN 'ALTER DATABASE [' + Database_Name +'] SET COMPATIBILITY_LEVEL = ' + convert(char(3), [compatibility_level]) + ';' ELSE NULL END
from cteDB
WHERE Up_to_Date is not null
order by [Database_Name];

--Databases where page verify option is not CHECKSUM
--Changing this setting does not instantly put a checksum on every page. Need to do an index REBUILD of all objets to get CHECKSUMS in place, or, it'll happen slowly over time as data is written.
select
 	[Database Name]			= name
,	[Page Verify Option]	= page_verify_option_desc
,	[Message]				= 'Page Verify Option MUST be CHECKSUM!'
,	[Alter]					= 'ALTER DATABASE [' + name +'] SET PAGE_VERIFY CHECKSUM WITH NO_WAIT; --Need to rebuild indexes on all objects in DB to take effect '
,	[Revert]				= 'ALTER DATABASE [' + name +'] SET PAGE_VERIFY ' + page_verify_option_desc COLLATE DATABASE_DEFAULT + ' WITH NO_WAIT;'
,	[State]					= dbstate		
from #DBSettings
where page_verify_option_desc <> 'CHECKSUM'
ORDER BY name;

--Databases where auto-close and/or auto-shrink is enabled. 
--Strongly recommend NEVER enabling either of these two settings.
select 
 	[Database Name]			= name
,	[Is Auto Close On]		= is_auto_close_on		--should be 0
,	[Is Auto Shrink On]		= is_auto_shrink_on		--should be 0
,	[Alter]					= CASE
									WHEN is_auto_close_on = 1 THEN 'ALTER DATABASE [' + name + '] SET AUTO_CLOSE OFF WITH NO_WAIT;'
									WHEN is_auto_shrink_on = 1 THEN 'ALTER DATABASE [' + name + '] SET AUTO_SHRINK OFF WITH NO_WAIT;'
									WHEN is_auto_close_on = 1 AND is_auto_shrink_on = 1 THEN 'ALTER DATABASE [' + name + '] SET AUTO_CLOSE OFF WITH NO_WAIT; ALTER DATABASE [' + name + '] SET AUTO_SHRINK OFF WITH NO_WAIT;'
							  ELSE 'N/A'
							  END
,	[Revert]				= CASE
									WHEN is_auto_close_on = 1 THEN 'ALTER DATABASE [' + name + '] SET AUTO_CLOSE ON WITH NO_WAIT;'
									WHEN is_auto_shrink_on = 1 THEN 'ALTER DATABASE [' + name + '] SET AUTO_SHRINK ON WITH NO_WAIT;'
									WHEN is_auto_close_on = 1 AND is_auto_shrink_on = 1 THEN 'ALTER DATABASE [' + name + '] SET AUTO_CLOSE ON WITH NO_WAIT; ALTER DATABASE [' + name + '] SET AUTO_SHRINK ON WITH NO_WAIT;'
							  ELSE 'N/A'
							  END
,	[State]					= dbstate	
from #DBSettings
where is_auto_close_on = 1		
   OR is_auto_shrink_on	= 1	
ORDER BY name;

--Databases where auto create and/or auto update stats is disabled
--Recommend enabling these settings.
select 
	[Database Name]					= name
,	[Is Auto Create Stats On]		= is_auto_create_stats_on		--should be 1 except for some SharePoint db's
,	[Is Auto Update Stats On]		= is_auto_update_stats_on		--should be 1 except for some SharePoint db's
,	[Is Auto Update Stats Async On]	= is_auto_update_stats_async_on	--should be 1 except for some SharePoint db's
,	[Alter]							= CASE
											WHEN is_auto_create_stats_on = 0 THEN 'ALTER DATABASE [' + name + '] SET AUTO_CREATE_STATISTICS ON WITH NO_WAIT;'
											WHEN is_auto_update_stats_on = 0 THEN 'ALTER DATABASE [' + name + '] SET AUTO_UPDATE_STATISTICS ON WITH NO_WAIT;'
											WHEN is_auto_update_stats_async_on = 0 THEN 'ALTER DATABASE [' + name + '] SET AUTO_UPDATE_STATISTICS_ASYNC ON WITH NO_WAIT;'
											WHEN is_auto_create_stats_on = 0 AND is_auto_update_stats_on = 0 THEN 'ALTER DATABASE [' + name + '] SET AUTO_CREATE_STATISTICS ON WITH NO_WAIT; ALTER DATABASE [' + name + '] SET AUTO_UPDATE_STATISTICS ON WITH NO_WAIT;'
											WHEN is_auto_create_stats_on = 0 AND is_auto_update_stats_async_on = 0 THEN 'ALTER DATABASE [' + name + '] SET AUTO_CREATE_STATISTICS ON WITH NO_WAIT; ALTER DATABASE [' + name + '] SET AUTO_UPDATE_STATISTICS_ASYNC ON WITH NO_WAIT;'
											WHEN is_auto_update_stats_on = 0 AND is_auto_update_stats_async_on = 0 THEN 'ALTER DATABASE [' + name + '] SET AUTO_UPDATE_STATISTICS ON WITH NO_WAIT; ALTER DATABASE [' + name + '] SET AUTO_UPDATE_STATISTICS_ASYNC ON WITH NO_WAIT;'
											WHEN is_auto_create_stats_on = 0 AND is_auto_update_stats_on = 0 AND is_auto_update_stats_async_on = 0 THEN 'ALTER DATABASE [' + name + '] SET AUTO_CREATE_STATISTICS ON WITH NO_WAIT; ALTER DATABASE [' + name + '] SET AUTO_UPDATE_STATISTICS ON WITH NO_WAIT; ALTER DATABASE [' + name + '] SET AUTO_UPDATE_STATISTICS_ASYNC ON WITH NO_WAIT;'
									  ELSE 'N/A'
									  END
,	[Revert]						= CASE
											WHEN is_auto_create_stats_on = 0 THEN 'ALTER DATABASE [' + name + '] SET AUTO_CREATE_STATISTICS OFF WITH NO_WAIT;'
											WHEN is_auto_update_stats_on = 0 THEN 'ALTER DATABASE [' + name + '] SET AUTO_UPDATE_STATISTICS OFF WITH NO_WAIT;'
											WHEN is_auto_update_stats_async_on = 0 THEN 'ALTER DATABASE [' + name + '] SET AUTO_UPDATE_STATISTICS_ASYNC OFF WITH NO_WAIT;'
											WHEN is_auto_create_stats_on = 0 AND is_auto_update_stats_on = 0 THEN 'ALTER DATABASE [' + name + '] SET AUTO_CREATE_STATISTICS OFF WITH NO_WAIT; ALTER DATABASE [' + name + '] SET AUTO_UPDATE_STATISTICS OFF WITH NO_WAIT;'
											WHEN is_auto_create_stats_on = 0 AND is_auto_update_stats_async_on = 0 THEN 'ALTER DATABASE [' + name + '] SET AUTO_CREATE_STATISTICS OFF WITH NO_WAIT; ALTER DATABASE [' + name + '] SET AUTO_UPDATE_STATISTICS_ASYNC OFF WITH NO_WAIT;'
											WHEN is_auto_update_stats_on = 0 AND is_auto_update_stats_async_on = 0 THEN 'ALTER DATABASE [' + name + '] SET AUTO_UPDATE_STATISTICS OFF WITH NO_WAIT; ALTER DATABASE [' + name + '] SET AUTO_UPDATE_STATISTICS_ASYNC OFF WITH NO_WAIT;'
											WHEN is_auto_create_stats_on = 0 AND is_auto_update_stats_on = 0 AND is_auto_update_stats_async_on = 0 THEN 'ALTER DATABASE [' + name + '] SET AUTO_CREATE_STATISTICS OFF WITH NO_WAIT; ALTER DATABASE [' + name + '] SET AUTO_UPDATE_STATISTICS OFF WITH NO_WAIT; ALTER DATABASE [' + name + '] SET AUTO_UPDATE_STATISTICS_ASYNC OFF WITH NO_WAIT;'
									  ELSE 'N/A'
									  END
,	[State]							= dbstate	
from #DBSettings
where is_auto_create_stats_on = 0
   OR is_auto_update_stats_on = 0
   OR is_auto_update_stats_async_on = 0
ORDER BY name;

--Databases log reuse wait and description
--Expected types: NOTHING, CHECKPOINT, LOG_BACKUP, ACTIVE_BACKUP_OR_RESTORE, DATABASE_SNAPSHOT_CREATION, AVAILABILITY_REPLICA, OLDEST_PAGE, XTP_CHECKPOINT
--Potentially problematic if long-lasting, research: DATABASE_MIRRORING, REPLICATION, ACTIVE_TRANSACTION, LOG_SCAN, OTHER_TRANSIENT 
select 
	[Database Name]		= name
,	[Log Reuse Wait]	= log_reuse_wait
,	[Description]		= log_reuse_wait_desc
,	[State]				= dbstate		
,	[Recovery Model]	= recovery_model_desc
from #DBSettings
ORDER BY name;

--Databases where target recovery time in seconds is < 60 (only applies to 2014+), and recommended in 2014+
select 
	[Database Name]			= name
,	[Target Recovery Time]	= target_recovery_time_in_seconds
,	[Alter]					= 'ALTER DATABASE [' + name + '] SET TARGET_RECOVERY_TIME = 60 SECONDS WITH NO_WAIT'
,	[Revert]				= 'ALTER DATABASE [' + name + '] SET TARGET_RECOVERY_TIME = ' + CAST(target_recovery_time_in_seconds AS VARCHAR(3)) + ' SECONDS WITH NO_WAIT'
,	[State]					= dbstate		
from #DBSettings
where target_recovery_time_in_seconds = 0
ORDER BY name;



--optimize for ad hoc workloads.sql
select 
	PlanUse = case when p.usecounts > 1 THEN '>1' else '1' end
,	PlanCount = count(1) 
,	SizeInMB = sum(p.size_in_bytes/1024./1024.)
FROM sys.dm_exec_cached_plans p
group by case when p.usecounts > 1 THEN '>1' else '1' end

GO




--If size of Adhoc is listed first or second, perhaps Optimize for Ad Hoc Workloads should be enabled (see comments) 
SELECT objtype AS [CacheType]
        , count_big(*) AS [Total Plans]
        , sum(cast(size_in_bytes as decimal(18,2)))/1024/1024 AS [Total MBs]
--        , avg(usecounts) AS [Avg Use Count]
        , sum(cast((CASE WHEN usecounts = 1 THEN size_in_bytes ELSE 0 END) as decimal(18,2)))/1024/1024 AS [Total MBs – USE Count 1]
        , sum(CASE WHEN usecounts = 1 THEN 1 ELSE 0 END) AS [Total Plans – USE Count 1]
FROM sys.dm_exec_cached_plans
GROUP BY grouping sets (objtype, ())
ORDER BY [Total MBs – USE Count 1] DESC
go 
/*
go
EXEC sys.sp_configure N'show advanced options', N'1' 
GO
RECONFIGURE WITH OVERRIDE
go
EXEC sys.sp_configure 
go
EXEC sys.sp_configure N'show advanced options', N'0' 
GO
RECONFIGURE WITH OVERRIDE
go
EXEC sys.sp_configure 
go
EXEC sys.sp_configure N'optimize for ad hoc workloads' 
go
EXEC sys.sp_configure N'show advanced options', N'0'  RECONFIGURE WITH OVERRIDE
go
*/
/*
SELECT usecounts, cacheobjtype, objtype, TEXT, SizeMB= convert(decimal(19,2), p.size_in_bytes/1024./1024.), 'DBCC FREEPROCCACHE (', p.plan_handle, ')'
FROM sys.dm_exec_cached_plans p
CROSS APPLY sys.dm_exec_sql_text(plan_handle)
WHERE usecounts =1 
ORDER BY usecounts DESC;
GO
*/

/*
EXEC sys.sp_configure N'show advanced options', N'1'  RECONFIGURE WITH OVERRIDE
GO
EXEC sys.sp_configure N'optimize for ad hoc workloads', N'1'
GO
RECONFIGURE WITH OVERRIDE
GO
EXEC sys.sp_configure N'show advanced options', N'0'  RECONFIGURE WITH OVERRIDE
GO
*/

---database_server_options.sql

USE [master]
GO
-- Limit error logs
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'NumErrorLogs', REG_DWORD, 15
GO

-- Set sp_configure settings
EXEC sys.sp_configure N'show advanced options', N'1'
RECONFIGURE WITH OVERRIDE
GO
EXEC sys.sp_configure N'remote admin connections', N'1'
RECONFIGURE WITH OVERRIDE
GO
-- Use 'backup compression default' when server is NOT CPU bound
IF CONVERT(int, (@@microsoftversion / 0x1000000) & 0xff) >= 10
EXEC sys.sp_configure N'backup compression default', N'1'
RECONFIGURE WITH OVERRIDE
GO
-- Use 'optimize for ad hoc workloads' for OLTP workloads ONLY
IF CONVERT(int, (@@microsoftversion / 0x1000000) & 0xff) >= 10
EXEC sys.sp_configure N'optimize for ad hoc workloads', N'1'
RECONFIGURE WITH OVERRIDE
GO
EXEC sys.sp_configure N'show advanced options', N'0'
RECONFIGURE WITH OVERRIDE
GO

USE [master]
GO
-- Set model defaults
ALTER DATABASE [model] MODIFY FILE ( NAME = N'modeldev', FILEGROWTH = 102400KB )
GO
ALTER DATABASE [model] MODIFY FILE ( NAME = N'modellog', FILEGROWTH = 102400KB )
GO

-- Set database option defaults (ignore errors on tempdb and read-only databases)
USE [master]
GO
EXEC master.dbo.sp_MSforeachdb @command1='USE master; ALTER DATABASE [?] SET AUTO_CLOSE OFF WITH NO_WAIT'
EXEC master.dbo.sp_MSforeachdb @command1='USE master; ALTER DATABASE [?] SET AUTO_SHRINK OFF WITH NO_WAIT'
EXEC master.dbo.sp_MSforeachdb @command1='USE master; ALTER DATABASE [?] SET PAGE_VERIFY CHECKSUM WITH NO_WAIT'
--EXEC master.dbo.sp_MSforeachdb @command1='USE master; ALTER DATABASE [?] SET AUTO_CREATE_STATISTICS ON'
--EXEC master.dbo.sp_MSforeachdb @command1='USE master; ALTER DATABASE [?] SET AUTO_UPDATE_STATISTICS ON'
GO

--SET proper MaxDOP
DECLARE @cpucount int, @numa int, @affined_cpus int, @sqlcmd NVARCHAR(255)
SELECT @affined_cpus = COUNT(cpu_id) FROM sys.dm_os_schedulers WHERE is_online = 1 AND scheduler_id < 255 AND parent_node_id < 64;
SELECT @cpucount = COUNT(cpu_id) FROM sys.dm_os_schedulers WHERE scheduler_id < 255 AND parent_node_id < 64
SELECT @numa = COUNT(DISTINCT parent_node_id) FROM sys.dm_os_schedulers WHERE scheduler_id < 255 AND parent_node_id < 64;
SELECT @sqlcmd = 'sp_configure ''max degree of parallelism'', ' + CONVERT(NVARCHAR(255), 
		CASE 
		-- If not NUMA, and up to 16 @affined_cpus then MaxDOP up to 16
		WHEN @numa = 1 AND @affined_cpus <= 16 THEN @affined_cpus
		-- If not NUMA, and more than 16 @affined_cpus then MaxDOP 16
		WHEN @numa = 1 AND @affined_cpus > 16 THEN 16
		-- If NUMA and # logical CPUs per NUMA up to 16, then MaxDOP is set as # logical CPUs per NUMA, up to 16 
		WHEN @numa > 1 AND (@cpucount/@numa) <= 16 THEN CEILING(@cpucount/@numa)
		-- If NUMA and # logical CPUs per NUMA > 16, then MaxDOP is set as 1/2 of # logical CPUs per NUMA
		WHEN @numa > 1 AND (@cpucount/@numa) > 16 THEN CEILING((@cpucount/@numa)/2)
		ELSE 0
	END)
FROM sys.configurations (NOLOCK) WHERE name = 'max degree of parallelism';	

EXECUTE sp_executesql @sqlcmd;
GO

-- SET proper server memory (below calculations are for one instance only)
DECLARE @maxservermem bigint, @minservermem bigint, @systemmem bigint, @mwthreads_count int, @sqlmajorver int, @numa int, @numa_nodes_afinned tinyint, @arch NVARCHAR(10), @sqlcmd NVARCHAR(255)
-- Change below to 1 to set a max server memory config that is aligned with current affinied NUMA nodes.
DECLARE @numa_affined_config bit = 0

SELECT @sqlmajorver = CONVERT(int, (@@microsoftversion / 0x1000000) & 0xff);
SELECT @arch = CASE WHEN @@VERSION LIKE '%<X64>%' THEN 64 WHEN @@VERSION LIKE '%<IA64>%' THEN 128 ELSE 32 END FROM sys.dm_os_windows_info WITH (NOLOCK);
SELECT @systemmem = total_physical_memory_kb/1024 FROM sys.dm_os_sys_memory;
SELECT @numa = COUNT(DISTINCT parent_node_id) FROM sys.dm_os_schedulers WHERE scheduler_id < 255 AND parent_node_id < 64;
SELECT @numa_nodes_afinned = COUNT (DISTINCT parent_node_id) FROM sys.dm_os_schedulers WHERE scheduler_id < 255 AND parent_node_id < 64 AND is_online = 1;
SELECT @minservermem = CONVERT(int, [value]) FROM sys.configurations WITH (NOLOCK) WHERE [Name] = 'min server memory (MB)';
SELECT @maxservermem = CONVERT(int, [value]) FROM sys.configurations WITH (NOLOCK) WHERE [Name] = 'max server memory (MB)';
SELECT @mwthreads_count = max_workers_count FROM sys.dm_os_sys_info;

IF (@maxservermem = 2147483647 OR @maxservermem > @systemmem) AND @numa_affined_config = 0
BEGIN
	SELECT @sqlcmd = 'sp_configure ''max server memory (MB)'', '+ CONVERT(NVARCHAR(20), 
		CASE WHEN @systemmem <= 2048 THEN @systemmem-512-(@mwthreads_count*(CASE WHEN @arch = 64 THEN 2 WHEN @arch = 128 THEN 4 WHEN @arch = 32 THEN 0.5 END)- CASE WHEN @arch = 32 THEN 256 ELSE 0 END)
			WHEN @systemmem BETWEEN 2049 AND 4096 THEN @systemmem-819-(@mwthreads_count*(CASE WHEN @arch = 64 THEN 2 WHEN @arch = 128 THEN 4 WHEN @arch = 32 THEN 0.5 END)- CASE WHEN @arch = 32 THEN 256 ELSE 0 END)
			WHEN @systemmem BETWEEN 4097 AND 8192 THEN @systemmem-1228-(@mwthreads_count*(CASE WHEN @arch = 64 THEN 2 WHEN @arch = 128 THEN 4 WHEN @arch = 32 THEN 0.5 END)- CASE WHEN @arch = 32 THEN 256 ELSE 0 END)
			WHEN @systemmem BETWEEN 8193 AND 12288 THEN @systemmem-2048-(@mwthreads_count*(CASE WHEN @arch = 64 THEN 2 WHEN @arch = 128 THEN 4 WHEN @arch = 32 THEN 0.5 END)- CASE WHEN @arch = 32 THEN 256 ELSE 0 END)
			WHEN @systemmem BETWEEN 12289 AND 24576 THEN @systemmem-2560-(@mwthreads_count*(CASE WHEN @arch = 64 THEN 2 WHEN @arch = 128 THEN 4 WHEN @arch = 32 THEN 0.5 END)- CASE WHEN @arch = 32 THEN 256 ELSE 0 END)
			WHEN @systemmem BETWEEN 24577 AND 32768 THEN @systemmem-3072-(@mwthreads_count*(CASE WHEN @arch = 64 THEN 2 WHEN @arch = 128 THEN 4 WHEN @arch = 32 THEN 0.5 END)- CASE WHEN @arch = 32 THEN 256 ELSE 0 END)
			WHEN @systemmem > 32768 AND SERVERPROPERTY('EditionID') IN (284895786, 1293598313) THEN CAST(0.5 * (((@systemmem-4096-(@mwthreads_count*(CASE WHEN @arch = 64 THEN 2 WHEN @arch = 128 THEN 4 WHEN @arch = 32 THEN 0.5 END)- CASE WHEN @arch = 32 THEN 256 ELSE 0 END)) + 65536) - ABS((@systemmem-4096-(@mwthreads_count*(CASE WHEN @arch = 64 THEN 2 WHEN @arch = 128 THEN 4 WHEN @arch = 32 THEN 0.5 END)- CASE WHEN @arch = 32 THEN 256 ELSE 0 END)) - 65536)) AS int) -- Find min of max mem for machine or max mem for Web and Business Intelligence SKU
			WHEN @systemmem > 32768 AND SERVERPROPERTY('EditionID') = -1534726760 THEN CAST(0.5 * (((@systemmem-4096-(@mwthreads_count*(CASE WHEN @arch = 64 THEN 2 WHEN @arch = 128 THEN 4 WHEN @arch = 32 THEN 0.5 END)- CASE WHEN @arch = 32 THEN 256 ELSE 0 END)) + 131072) - ABS((@systemmem-4096-(@mwthreads_count*(CASE WHEN @arch = 64 THEN 2 WHEN @arch = 128 THEN 4 WHEN @arch = 32 THEN 0.5 END)- CASE WHEN @arch = 32 THEN 256 ELSE 0 END)) - 131072)) AS int) -- Find min of max mem for machine or max mem for Standard SKU
			WHEN @systemmem > 32768 AND SERVERPROPERTY('EngineEdition') IN (3,8) THEN @systemmem-4096-(@mwthreads_count*(CASE WHEN @arch = 64 THEN 2 WHEN @arch = 128 THEN 4 WHEN @arch = 32 THEN 0.5 END)- CASE WHEN @arch = 32 THEN 256 ELSE 0 END) -- Enterprise Edition or Managed Instance
		END);
	EXECUTE sp_executesql @sqlcmd;
END
ELSE IF (@maxservermem = 2147483647 OR @maxservermem > @systemmem) AND @numa_affined_config = 1
BEGIN
	SELECT @sqlcmd = 'sp_configure ''max server memory (MB)'', '+ CONVERT(NVARCHAR(20), 
		CASE WHEN @systemmem <= 2048 THEN ((@systemmem-512-(@mwthreads_count*(CASE WHEN @arch = 64 THEN 2 WHEN @arch = 128 THEN 4 WHEN @arch = 32 THEN 0.5 END)- CASE WHEN @arch = 32 THEN 256 ELSE 0 END))/@numa) * @numa_nodes_afinned
			WHEN @systemmem BETWEEN 2049 AND 4096 THEN ((@systemmem-819-(@mwthreads_count*(CASE WHEN @arch = 64 THEN 2 WHEN @arch = 128 THEN 4 WHEN @arch = 32 THEN 0.5 END)- CASE WHEN @arch = 32 THEN 256 ELSE 0 END))/@numa) * @numa_nodes_afinned
			WHEN @systemmem BETWEEN 4097 AND 8192 THEN ((@systemmem-1228-(@mwthreads_count*(CASE WHEN @arch = 64 THEN 2 WHEN @arch = 128 THEN 4 WHEN @arch = 32 THEN 0.5 END)- CASE WHEN @arch = 32 THEN 256 ELSE 0 END))/@numa) * @numa_nodes_afinned
			WHEN @systemmem BETWEEN 8193 AND 12288 THEN ((@systemmem-2048-(@mwthreads_count*(CASE WHEN @arch = 64 THEN 2 WHEN @arch = 128 THEN 4 WHEN @arch = 32 THEN 0.5 END)- CASE WHEN @arch = 32 THEN 256 ELSE 0 END))/@numa) * @numa_nodes_afinned
			WHEN @systemmem BETWEEN 12289 AND 24576 THEN ((@systemmem-2560-(@mwthreads_count*(CASE WHEN @arch = 64 THEN 2 WHEN @arch = 128 THEN 4 WHEN @arch = 32 THEN 0.5 END)- CASE WHEN @arch = 32 THEN 256 ELSE 0 END))/@numa) * @numa_nodes_afinned
			WHEN @systemmem BETWEEN 24577 AND 32768 THEN ((@systemmem-3072-(@mwthreads_count*(CASE WHEN @arch = 64 THEN 2 WHEN @arch = 128 THEN 4 WHEN @arch = 32 THEN 0.5 END)- CASE WHEN @arch = 32 THEN 256 ELSE 0 END))/@numa) * @numa_nodes_afinned
			WHEN @systemmem > 32768 AND SERVERPROPERTY('EditionID') IN (284895786, 1293598313) THEN ((CAST(0.5 * (((@systemmem-4096-(@mwthreads_count*(CASE WHEN @arch = 64 THEN 2 WHEN @arch = 128 THEN 4 WHEN @arch = 32 THEN 0.5 END)- CASE WHEN @arch = 32 THEN 256 ELSE 0 END)) + 65536) - ABS((@systemmem-4096-(@mwthreads_count*(CASE WHEN @arch = 64 THEN 2 WHEN @arch = 128 THEN 4 WHEN @arch = 32 THEN 0.5 END)- CASE WHEN @arch = 32 THEN 256 ELSE 0 END)) - 65536)) AS int))/@numa) * @numa_nodes_afinned -- Find min of max mem for machine or max mem for Web and Business Intelligence SKU
			WHEN @systemmem > 32768 AND SERVERPROPERTY('EditionID') = -1534726760 THEN ((CAST(0.5 * (((@systemmem-4096-(@mwthreads_count*(CASE WHEN @arch = 64 THEN 2 WHEN @arch = 128 THEN 4 WHEN @arch = 32 THEN 0.5 END)- CASE WHEN @arch = 32 THEN 256 ELSE 0 END)) + 131072) - ABS((@systemmem-4096-(@mwthreads_count*(CASE WHEN @arch = 64 THEN 2 WHEN @arch = 128 THEN 4 WHEN @arch = 32 THEN 0.5 END)- CASE WHEN @arch = 32 THEN 256 ELSE 0 END)) - 131072)) AS int))/@numa) * @numa_nodes_afinned -- Find min of max mem for machine or max mem for Standard SKU
			WHEN @systemmem > 32768 AND SERVERPROPERTY('EngineEdition') IN (3,8) THEN ((@systemmem-4096-(@mwthreads_count*(CASE WHEN @arch = 64 THEN 2 WHEN @arch = 128 THEN 4 WHEN @arch = 32 THEN 0.5 END)- CASE WHEN @arch = 32 THEN 256 ELSE 0 END))/@numa) * @numa_nodes_afinned -- Enterprise Edition or Managed Instance
		END);
	EXECUTE sp_executesql @sqlcmd;
END;
GO

EXEC sys.sp_configure N'show advanced options', N'0'
RECONFIGURE WITH OVERRIDE
GO
