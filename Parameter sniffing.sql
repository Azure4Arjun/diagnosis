CREATE PROC dbo.AddressByCity @City NVARCHAR(30)
AS
-- This allows me to bypass parameter sniffing
DECLARE @LocalCity NVARCHAR(30) = @City;

SELECT  a.AddressID,
        a.AddressLine1,
        AddressLine2,
        a.City,
        sp.[Name] AS StateProvinceName,
        a.PostalCode
FROM    Person.Address AS a
JOIN    Person.StateProvince AS sp
        ON a.StateProvinceID = sp.StateProvinceID
WHERE   a.City = @LocalCity;
GO


---method 2

ALTER PROC dbo.AddressByCity @City NVARCHAR(30)
AS
SELECT  a.AddressID,
        a.AddressLine1,
        AddressLine2,
        a.City,
        sp.[Name] AS StateProvinceName,
        a.PostalCode
FROM    Person.Address AS a
JOIN    Person.StateProvince AS sp
        ON a.StateProvinceID = sp.StateProvinceID
WHERE   a.City = @City
OPTION (OPTIMIZE FOR (@City = 'Mentor'));

exec dbo.addressbycity @city = 'London';

--before parameter snnipig
CREATE PROCEDURE Customer_Search
 @FirstName varchar(100),
 @LastName varchar(100)
AS
BEGIN

 SELECT 
  CustomerID,
  Firstname,
  Lastname,
  Username,
  Email
 FROM
  Customer
 WHERE
  Firstname LIKE ('%' + @FirstName + '%') AND
  LastName LIKE ('%' + @LastName + '%')
END
GO


--method 1  after implimentation of parameter snniffing
CREATE PROCEDURE Customer_Search
 @FirstName varchar(100),
 @LastName varchar(100)
AS
BEGIN
 -- Variables added to prevent problems that were occuring with parameter sniffing
 DECLARE 
  @FName VARCHAR(100),
  @LName VARCHAR(100)
   
 SELECT
  @FName = @FirstName,
  @LName = @LastName

 SELECT 
  CustomerID,
  Firstname,
  Lastname,
  Username,
  Email
 FROM
  Customer
 WHERE
  Firstname LIKE ('%' + @FName + '%') AND
  LastName LIKE ('%' + @LName + '%')
END
GO



--demo  make_sandbox_parametersniffing.sql

---Create a playground
create database sandbox;
go
use sandbox
go
drop table dbo.tableOfThings
go
create table dbo.tableOfThings (
id int identity(1,1) not null constraint pk_tableOfThings primary key
, date_created datetime2 not null constraint df_date_created  default getdate()
, thing varchar(max) not null
, importance tinyint not null constraint df_importance default 1
);
go
set nocount on;
insert into dbo.tableOfThings(thing) values (replace(newid(), '-', ''));
GO 500000
UPDATE dbo.tableOfThings SET importance = 2 where id % 2 = 0;
UPDATE dbo.tableOfThings SET importance = 3 WHERE id % 3 = 0;
UPDATE dbo.tableOfThings SET importance = 1 WHERE id % 6 = 0;
UPDATE dbo.tableOfThings SET importance = 1 WHERE id % 16 = 0;
UPDATE dbo.tableOfThings SET importance = 4 WHERE id % 97 = 0
GO
CREATE INDEX idx_importance ON dbo.tableOfThings (importance ASC) with (fillfactor = 100)
GO

--scenario-1_causeparametersniffing.sql
---Scenario-1: Create a Parameter Sniff
CREATE PROCEDURE #get_things
	@importance tinyint
 AS 
	SELECT thing FROM dbo.tableOfThings WHERE importance = @importance;
GO
EXECUTE #get_things 4;
EXECUTE #get_things 1;
GO

-----Scenario-2: Copy parameters to local variables
CREATE PROCEDURE #get_things_localvariables
	@importance tinyint
 AS 
	DECLARE @local_importance tinyint;
	SET @local_importance = @importance;

	SELECT thing FROM dbo.tableOfThings WHERE importance = @local_importance;
GO
EXECUTE #get_things_localvariables 4;
EXECUTE #get_things_localvariables 1;
GO

/*
This produced the following plan...
https://www.brentozar.com/pastetheplan/?id=rkKWzdyrN
*/
