USE star_schema_aw2017
GO

-- set LastUpdated
UPDATE LastUpdated
SET LastUpdated.LastUpdated ='2013-12-31';

----------------------------------------------INDIVIDUAL CUSTOMER DIMENSION---------------------------------------------
-- drop the temporary table if exists
DROP TABLE IF EXISTS #stage_d_individual_customer;
-- Create temporary staging table for customer dimension
CREATE TABLE #stage_d_individual_customer
(
    IndividualCustomerID int,
    FirstName            nvarchar(50),
    LastName             nvarchar(50),
    ValidFrom            date,
    ValidTo              date
)
GO

-- Extraction Individual Customer
INSERT INTO #stage_d_individual_customer (IndividualCustomerID, FirstName, LastName)
SELECT CustomerID, FirstName, LastName
FROM AdventureWorks2017.Sales.Customer
         JOIN AdventureWorks2017.Person.Person ON AdventureWorks2017.Person.Person.BusinessEntityID =
                                                  AdventureWorks2017.Sales.Customer.PersonID
WHERE PersonID IS NOT NULL
  AND StoreID IS NULL;

-- Transformation

-- Set ValidFrom and ValidTo dates
UPDATE #stage_d_individual_customer
SET ValidFrom='2011-05-31',
    ValidTo='9999-12-31';

-- There is no need to repair the data, because, based on the source database,
-- the first and last name of a customer cannot be null

-- Load
INSERT INTO star_schema_aw2017.dbo.D_Individual_Customer (IndividualCustomerID, FirstName, LastName, ValidFrom, ValidTo)
SELECT IndividualCustomerID, FirstName, LastName, ValidFrom, ValidTo
FROM #stage_d_individual_customer;
------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------PRODUCT DIMENSION---------------------------------------------------
-- drop the temporary table if exists
DROP TABLE IF EXISTS #stage_d_product;
-- Create temporary staging table for product dimension
CREATE TABLE #stage_d_product
(
    ProductName nvarchar(50),
    ProductID   int NOT NULL,
    ValidFrom   date,
    ValidTo     date
)
GO

-- Extraction Product
INSERT INTO #stage_d_product (ProductName, ProductID)
SELECT Name, ProductID
FROM AdventureWorks2017.Production.Product;

-- Transformation

-- Set ValidFrom and ValidTo dates
UPDATE #stage_d_product
SET ValidFrom='2011-05-31',
    ValidTo  = '9999-12-31';

-- There is no need to repair the data, because, based on the source database,
-- the name of a product cannot be null

-- Load
INSERT INTO star_schema_aw2017.dbo.D_Product (ProductName, ProductID, ValidFrom, ValidTo)
SELECT ProductName, ProductID, ValidFrom, ValidTo
FROM #stage_d_product;
------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------SALES FACT-------------------------------------------------------

-- drop the temporary table if exists
DROP TABLE IF EXISTS #stage_f_internet_sales;
-- Create temporary staging fact table
CREATE TABLE #stage_f_internet_sales
(
    ProductID       int,
    CustomerID      int,
    DateID          int,
    ProductKey      int,
    CustomerKey     int,
    DateKey         int,
    ProductQuantity int,
    LineTotal       numeric(38, 6),
    OrderDate       date
)
GO

-- Extract Fact Table
INSERT INTO #stage_f_internet_sales (ProductID, OrderDate, CustomerID, ProductQuantity,
                                     LineTotal)
SELECT Product.ProductID,
       SalesOrderHeader.OrderDate,
       SalesOrderHeader.CustomerID,
       OrderQty,
       LineTotal
FROM AdventureWorks2017.Sales.SalesOrderHeader
         LEFT JOIN AdventureWorks2017.Sales.SalesOrderDetail
                   ON SalesOrderDetail.SalesOrderID = SalesOrderHeader.SalesOrderID
         LEFT JOIN AdventureWorks2017.Production.Product ON Product.ProductID = SalesOrderDetail.ProductID
         LEFT JOIN AdventureWorks2017.Sales.Customer
                   ON AdventureWorks2017.Sales.SalesOrderHeader.CustomerID = Customer.CustomerID
WHERE OnlineOrderFlag = 1
  AND OrderDate <= (SELECT LastUpdated FROM LastUpdated);

-- Transform
-- Update surrogate keys
UPDATE #stage_f_internet_sales
SET ProductKey=(
    SELECT ProductKey
    FROM star_schema_aw2017.dbo.D_Product p
    WHERE p.ProductID = #stage_f_internet_sales.ProductID
)

UPDATE #stage_f_internet_sales
SET DateKey=(
    SELECT DateKey
    FROM star_schema_aw2017.dbo.D_Date d
    WHERE d.DateSql = #stage_f_internet_sales.OrderDate
)

UPDATE #stage_f_internet_sales
SET CustomerKey=(
    SELECT star_schema_aw2017.dbo.D_Individual_Customer.IndividualCustomerKey
    FROM star_schema_aw2017.dbo.D_Individual_Customer
    WHERE D_Individual_Customer.IndividualCustomerID = #stage_f_internet_sales.CustomerID
)

-- The code below is handling duplicates. Duplicates can happen if a person bought
-- the same product in the same day 2 or more times in different orders.
-- As a solution, if such situations are encountered, the values of product
-- quantity and line total are summed.
DROP TABLE IF EXISTS #temp_fact;

SELECT ProductKey,
       CustomerKey,
       DateKey,
       SUM(ProductQuantity) AS ProductQuantity,
       SUM(LineTotal)       AS LineTotal
INTO #temp_fact
FROM #stage_f_internet_sales
GROUP BY ProductKey, CustomerKey, DateKey;

DROP TABLE IF EXISTS #stage_f_internet_sales;

SELECT *
INTO #stage_f_internet_sales
FROM #temp_fact;

-- Load
INSERT INTO star_schema_aw2017.dbo.F_Internet_Sales (DateKey, IndividualCustomerKey, ProductKey, ProductQuantity,
                                                     LineTotal)
SELECT DateKey,
       CustomerKey,
       ProductKey,
       ProductQuantity,
       LineTotal
FROM #stage_f_internet_sales
------------------------------------------------------------------------------------------------------------------------

-----------------------------------------------------DATE DIMENSION-----------------------------------------------------

-- drop the temporary table if exists
DROP TABLE IF EXISTS #stage_d_date;
-- Create stage table for date dimension
CREATE TABLE #stage_d_date
(
    DateSql     date        NOT NULL,
    MonthNumber int         NOT NULL,
    MonthName   varchar(15) NOT NULL,
    Year        int,
    DayOfMonth  int
)
GO

-- Populate date dimension staging table

-- for testing
DELETE star_schema_aw2017.dbo.D_Date;
-- reset index (for testing)
DBCC CHECKIDENT ('D_Date', RESEED, 1)

DECLARE @StartDate date = '20110101';
DECLARE @EndDate date = DATEADD(DAY, -1, DATEADD(YEAR, 4, @StartDate));
WHILE @StartDate < @EndDate
    BEGIN
        INSERT INTO #stage_d_date(DateSql, MonthNumber, MonthName, Year, DayOfMonth)
        VALUES (@StartDate,
                DATEPART(MONTH, @StartDate),
                DATENAME(MONTH, @StartDate),
                DATEPART(YEAR, @StartDate),
                DATEPART(DAY, @StartDate))
        SET @StartDate = DATEADD(DD, 1, @StartDate)
    END

-- Load
INSERT INTO D_Date(DateSql, MonthNumber, MonthName, Year, DayOfMonth)
SELECT DateSql, MonthNumber, MonthName, Year, DayOfMonth
FROM #stage_d_date;
------------------------------------------------------------------------------------------------------------------------