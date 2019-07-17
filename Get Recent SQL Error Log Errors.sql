DECLARE @MinutesBackToCheck INT = 10;

SET NOCOUNT ON;
DECLARE @start DATETIME;
SET @start=DATEADD(MINUTE,-@MinutesBackToCheck,GETDATE());

DECLARE @errors AS TABLE
(
	ID INT IDENTITY(1,1) NOT NULL PRIMARY KEY CLUSTERED,
	LogDate DATETIME,
	ProcessInfo NVARCHAR (10),
	Error NVARCHAR(MAX)
);

INSERT INTO @errors(LogDate,ProcessInfo,Error)
EXEC master..xp_readerrorlog 0, 1, NULL, NULL, @start, NULL, 'Desc';

--DECLARE @Alerts AS TABLE
--(
--	LogDate DATETIME,
--	ProcessInfo NVARCHAR (10),
--	Error NVARCHAR(MAX)
--)

;WITH logs
AS
(
	SELECT
		 head.ID AS RootID
		,head.ID
		,head.LogDate
		,head.ProcessInfo
		,CONVERT(nvarchar(max), head.Error) AS Error
		, 1 AS Lvl
	FROM @errors as head
	WHERE
		head.Error LIKE N'Error:%Severity: %'

	UNION ALL

	SELECT
		 head.RootID
		,tail.ID
		,tail.LogDate
		,tail.ProcessInfo
		,CONVERT(nvarchar(max), head.Error + CHAR(13) + CHAR(10) + tail.Error)
		,head.Lvl + 1
	FROM logs as head
	INNER JOIN @errors as tail
	ON head.ProcessInfo = tail.ProcessInfo
	AND head.LogDate = tail.LogDate
	AND head.Error <> tail.Error
	AND head.ID > tail.ID
)
--INSERT INTO @Alerts
SELECT
	LogDate,
	ProcessInfo,
	Error
FROM
(
	SELECT *,
		RowRank = ROW_NUMBER() OVER (PARTITION BY RootID ORDER BY Lvl DESC)
	FROM logs
) AS d
WHERE RowRank = 1
OPTION (MAXRECURSION 0);
