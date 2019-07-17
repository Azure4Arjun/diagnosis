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


--method 1
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
