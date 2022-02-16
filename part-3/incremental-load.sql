-- set LastUpdated
-- UPDATE LastUpdated
-- SET LastUpdated.LastUpdated ='2013-12-31';

------------------------------------------------------NEW PRODUCTS------------------------------------------------------
INSERT INTO star_schema_aw2017.dbo.D_Product(ProductID, ProductName, CurrentPrice, ValidFrom, ValidTo)
SELECT ProductID, Name, ListPrice, DATEADD(HOUR, 1, (SELECT LastUpdated FROM star_schema_aw2017.dbo.LastUpdated)), '9999-12-31'
FROM AdventureWorks2017.Production.Product
WHERE ProductID IN
      (
          (
--               today
              SELECT ProductID
              FROM AdventureWorks2017.Production.Product
          )
          EXCEPT
          (
--               yesterday
              SELECT ProductID
              FROM star_schema_aw2017.dbo.D_Product
          )
      )
------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------DELETED PRODUCTS----------------------------------------------------
UPDATE star_schema_aw2017.dbo.D_Product
SET ValidTo=(SELECT LastUpdated FROM star_schema_aw2017.dbo.LastUpdated)
WHERE ProductID IN
      (
          (
--               yesterday
              SELECT ProductID
              FROM star_schema_aw2017.dbo.D_Product
          )
          EXCEPT
          (
--               today
              SELECT ProductID
              FROM AdventureWorks2017.Production.Product
          )
      )
------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------CHANGED PRODUCTS----------------------------------------------------
-- create a temporary table for the changed items - #TempChangedProducts
DROP TABLE IF EXISTS #TempChangedProducts;
CREATE TABLE #TempChangedProducts
(
    ProductName nvarchar(50),
    ProductID   int NOT NULL,
    CurrentPrice money,
    ValidFrom   date,
    ValidTo     date
)
GO

-- Insert the changed products into #TempChangedProducts
INSERT INTO #TempChangedProducts(ProductID, ProductName, CurrentPrice)
    (
--         today
        SELECT ProductID, Name, ListPrice
        FROM AdventureWorks2017.Production.Product
    )
    EXCEPT
    (
--     yesterday
        SELECT ProductID, ProductName, CurrentPrice
        FROM star_schema_aw2017.dbo.D_Product
    )
    EXCEPT
    (
        SELECT ProductID, Name, ListPrice
        FROM AdventureWorks2017.Production.Product
        WHERE ProductID NOT IN (SELECT ProductID FROM star_schema_aw2017.dbo.D_Product)
    )

-- Update validTo of existing rows in product dimension
UPDATE D_Product
SET ValidTo= (SELECT LastUpdated FROM star_schema_aw2017.dbo.LastUpdated)
WHERE ProductID IN (SELECT ProductID FROM #TempChangedProducts)

-- Insert new products into D_Product
INSERT INTO star_schema_aw2017.dbo.D_Product(ProductID, ProductName, CurrentPrice, ValidFrom, ValidTo)
SELECT ProductID,
       ProductName,
       CurrentPrice,
       (SELECT DATEADD(HOUR, 1, LastUpdated) FROM star_schema_aw2017.dbo.LastUpdated),
       '9999-12-31'
FROM #TempChangedProducts

-- Drop #TempChangedProducts table
DROP TABLE #TempChangedProducts
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------NEW CUSTOMERS-----------------------------------------------------
INSERT INTO star_schema_aw2017.dbo.D_Individual_Customer(IndividualCustomerID, FirstName, LastName, ValidFrom, ValidTo)
SELECT CustomerID,
       FirstName,
       LastName,
       DATEADD(HOUR, 1, (SELECT LastUpdated FROM star_schema_aw2017.dbo.LastUpdated)),
       '9999-12-31'
FROM AdventureWorks2017.Sales.Customer
         JOIN AdventureWorks2017.Person.Person ON AdventureWorks2017.Person.Person.BusinessEntityID =
                                                  AdventureWorks2017.Sales.Customer.PersonID
WHERE PersonID IS NOT NULL
  AND StoreID IS NULL
  AND CustomerID IN
      (
          (
--               today
              SELECT CustomerID
              FROM AdventureWorks2017.Sales.Customer
              WHERE PersonID IS NOT NULL
                AND StoreID IS NULL
          )
          EXCEPT
          (
--               yesterday
              SELECT IndividualCustomerID
              FROM star_schema_aw2017.dbo.D_Individual_Customer
          )
      )
------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------DELETED CUSTOMERS---------------------------------------------------
UPDATE star_schema_aw2017.dbo.D_Individual_Customer
SET ValidTo=(SELECT LastUpdated FROM star_schema_aw2017.dbo.LastUpdated)
WHERE IndividualCustomerID IN
      (
          (
--               yesterday
              SELECT IndividualCustomerID
              FROM star_schema_aw2017.dbo.D_Individual_Customer
          )
          EXCEPT
          (
--               today
              SELECT CustomerID
              FROM AdventureWorks2017.Sales.Customer
              WHERE PersonID IS NOT NULL
                AND StoreID IS NULL
          )
      )
------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------CHANGED CUSTOMERS---------------------------------------------------
-- create a temporary table for the changed items - #TempChangedCustomers
DROP TABLE IF EXISTS #TempChangedCustomers;
CREATE TABLE #TempChangedCustomers
(
    IndividualCustomerID int,
    FirstName            nvarchar(50),
    LastName             nvarchar(50),
    ValidFrom            date,
    ValidTo              date
)
GO

-- Insert the changed customers into #TempChangedCustomers
INSERT INTO #TempChangedCustomers(IndividualCustomerID, FirstName, LastName)
    (
--         today
        SELECT CustomerID, FirstName, LastName
        FROM AdventureWorks2017.Sales.Customer
                 JOIN AdventureWorks2017.Person.Person ON AdventureWorks2017.Person.Person.BusinessEntityID =
                                                          AdventureWorks2017.Sales.Customer.PersonID
        WHERE PersonID IS NOT NULL
          AND StoreID IS NULL
    )
    EXCEPT
    (
--     yesterday
        SELECT IndividualCustomerID, FirstName, LastName
        FROM star_schema_aw2017.dbo.D_Individual_Customer
    )
    EXCEPT
    (
        SELECT CustomerID, FirstName, LastName
        FROM AdventureWorks2017.Sales.Customer
                 JOIN AdventureWorks2017.Person.Person ON AdventureWorks2017.Person.Person.BusinessEntityID =
                                                          AdventureWorks2017.Sales.Customer.PersonID
        WHERE PersonID IS NOT NULL
          AND StoreID IS NULL
          AND CustomerID NOT IN (SELECT IndividualCustomerID FROM star_schema_aw2017.dbo.D_Individual_Customer)
    )

-- Update validTo of existing rows in customer dimension
UPDATE D_Individual_Customer
SET ValidTo=(SELECT LastUpdated FROM star_schema_aw2017.dbo.LastUpdated)
WHERE IndividualCustomerID IN (SELECT IndividualCustomerID FROM #TempChangedCustomers)

-- Insert changed customers into D_Individual_Customer
INSERT INTO star_schema_aw2017.dbo.D_Individual_Customer(IndividualCustomerID, FirstName, LastName, ValidFrom, ValidTo)
SELECT IndividualCustomerID,
       FirstName,
       LastName,
       (SELECT DATEADD(HOUR, 1, LastUpdated) FROM star_schema_aw2017.dbo.LastUpdated),
       '9999-12-31'
FROM #TempChangedCustomers

-- Drop #TempChangedCustomers table
DROP TABLE #TempChangedCustomers
------------------------------------------------------------------------------------------------------------------------

-----------------------------------------------INCREMENTAL LOAD SALES FACT----------------------------------------------

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
  AND OrderDate > (SELECT LastUpdated FROM LastUpdated);

UPDATE #stage_f_internet_sales
SET ProductKey=(
    SELECT ProductKey
    FROM star_schema_aw2017.dbo.D_Product p
    WHERE p.ProductID = #stage_f_internet_sales.ProductID
      AND ValidTo = '9999-12-31'
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
      AND ValidTo = '9999-12-31'
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

INSERT INTO star_schema_aw2017.dbo.F_Internet_Sales (DateKey, IndividualCustomerKey, ProductKey, ProductQuantity,
                                                     LineTotal)
SELECT DateKey,
       CustomerKey,
       ProductKey,
       ProductQuantity,
       LineTotal
FROM #stage_f_internet_sales
------------------------------------------------------------------------------------------------------------------------
UPDATE LastUpdated
SET LastUpdated.LastUpdated=GETDATE()