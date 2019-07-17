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
