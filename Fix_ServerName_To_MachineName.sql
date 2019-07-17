DECLARE @MachineName NVARCHAR(60)
SET @MachineName = CONVERT(nvarchar,SERVERPROPERTY('ServerName'));

IF @MachineName IS NULL
BEGIN
	PRINT 'Could not retrieve machine name using SERVERPROPERTY!';
	GOTO Quit;
END

DECLARE @CurrSrv VARCHAR(MAX)
SELECT @CurrSrv = name FROM sys.servers WHERE server_id = 0;

IF @CurrSrv = @MachineName
BEGIN
	PRINT 'Server name already matches actual machine name.'
	GOTO Quit;
END

PRINT 'Dropping local server name ' + @CurrSrv
EXEC sp_dropserver @CurrSrv
PRINT 'Creating local server name ' + @MachineName
EXEC sp_addserver @MachineName, local

Quit:

IF EXISTS (SELECT name FROM sys.servers WHERE server_id = 0 AND name <> @@SERVERNAME)
	PRINT 'Your server name was changed. Please restart the SQL Server service to apply changes.';
