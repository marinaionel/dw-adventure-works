-- For testing - clear dimensions and fact table
delete star_schema_aw2017.dbo.F_Internet_Sales;
DELETE star_schema_aw2017.dbo.D_Product;
DBCC CHECKIDENT ('D_Product', RESEED, 1)
delete star_schema_aw2017.dbo.D_Individual_Customer;
DBCC CHECKIDENT ('D_Individual_Customer', RESEED, 1)

drop table if exists #stage_d_individual_customer;
-- Create temporary staging table for customer dimension
create table #stage_d_individual_customer
(
    IndividualCustomerID int,
    FirstName            nvarchar(50),
    LastName             nvarchar(50)
)
go

-- Extraction Individual Customer
insert into #stage_d_individual_customer (IndividualCustomerID, FirstName, LastName)
select CustomerID, FirstName, LastName
from AdventureWorks2017.Sales.Customer
         join [AdventureWorks2017].[Person].[Person] on [AdventureWorks2017].[Person].[Person].[BusinessEntityID] =
                                                        [AdventureWorks2017].[Sales].[Customer].[PersonID]
where BusinessEntityID is not null
  and PersonID is not null
  and StoreID is null;

-- Transformation
UPDATE #stage_d_individual_customer
set FirstName='Unknown'
where FirstName is null;

UPDATE #stage_d_individual_customer
set LastName='Unknown'
where LastName is null;

-- Load
insert into star_schema_aw2017.dbo.D_Individual_Customer (IndividualCustomerID, FirstName, LastName)
select IndividualCustomerID, FirstName, LastName
from #stage_d_individual_customer;

drop table if exists #stage_d_product;
-- Create temporary staging table for product dimension
create table #stage_d_product
(
    ProductName nvarchar(50),
    ProductID   int not null,
    ValidFrom   date,
    ValidTo date
)
go

-- Extraction Product
insert into #stage_d_product (ProductName, ProductID)
select Name, ProductID
from AdventureWorks2017.Production.Product;

-- Transformation
UPDATE #stage_d_product
set ProductName='Unknown'
where ProductName is null;

UPDATE #stage_d_product
set ValidFrom='2011-05-31';

UPDATE #stage_d_product
set ValidTo = '2099-12-31';

-- Load
insert into star_schema_aw2017.dbo.D_Product (ProductName, ProductID, ValidFrom, ValidTo)
SELECT ProductName, ProductID, ValidFrom, ValidTo
from #stage_d_product;

-- Create date dimension
create table D_Date
(
    DateKey     int identity
        constraint PK_D_Date
            primary key,
    DateSql     date        not null,
    MonthNumber int         not null,
    MonthName   varchar(15) not null,
    Year        int,
    DayOfMonth  int
)
go

drop table if exists #stage_d_date;
-- Create stage table for date dimension
create table #stage_d_date
(
    DateSql     date        not null,
    MonthNumber int         not null,
    MonthName   varchar(15) not null,
    Year        int,
    DayOfMonth  int
)
go

-- Populate date dimension staging table

-- for testing
DELETE star_schema_aw2017.dbo.D_Date;
-- reset index (for testing)
DBCC CHECKIDENT ('D_Date', RESEED, 1)

DECLARE @StartDate date = '20100101';
DECLARE @EndDate date = DATEADD(DAY, -1, DATEADD(YEAR, 30, @StartDate));
WHILE @StartDate < @EndDate
    BEGIN
        INSERT INTO #stage_d_date(DateSql, MonthNumber, MonthName, Year, DayOfMonth)
        VALUES (@StartDate,
                DATEPART(MONTH, @StartDate),
                DATENAME(MONTH, @StartDate),
                DATEPART(YEAR, @StartDate),
                DATEPART(DAY, @StartDate))
        SET @StartDate = DATEADD(dd, 1, @StartDate)
    END

-- Load
insert into D_Date(DateSql, MonthNumber, MonthName, Year, DayOfMonth)
select DateSql, MonthNumber, MonthName, Year, DayOfMonth
from #stage_d_date;

drop table if exists #stage_f_internet_sales;
-- Create temporary staging fact table
create table #stage_f_internet_sales
(
    ProductID       int,
    CustomerID      int,
    ProductQuantity smallint,
    LineTotal       numeric(38, 6),
    DateID          int,
    OrderDate       date
)
go

-- Extract Fact Table
insert into #stage_f_internet_sales (ProductID, OrderDate, CustomerID, ProductQuantity,
                                     LineTotal)
select Product.ProductID,
       SalesOrderHeader.OrderDate,
       SalesOrderHeader.CustomerID,
       OrderQty,
       LineTotal
from AdventureWorks2017.Sales.SalesOrderHeader
         left join AdventureWorks2017.Sales.SalesOrderDetail
                   on SalesOrderDetail.SalesOrderID = SalesOrderHeader.SalesOrderID
         left join AdventureWorks2017.Production.Product on Product.ProductID = SalesOrderDetail.ProductID
         left join AdventureWorks2017.Sales.Customer
                   on AdventureWorks2017.Sales.SalesOrderHeader.CustomerID = Customer.CustomerID
where OnlineOrderFlag = 1
  AND OrderDate <= '2013-12-31';

-- Transform
-- Update surrogate keys
UPDATE #stage_f_internet_sales
set ProductID=(
    select top 1 ProductKey
    from star_schema_aw2017.dbo.D_Product p
    where p.ProductID = #stage_f_internet_sales.ProductID
)

UPDATE #stage_f_internet_sales
set DateID=(
    select top 1 DateKey
    from star_schema_aw2017.dbo.D_Date d
    where d.DateSql = #stage_f_internet_sales.OrderDate
)

UPDATE #stage_f_internet_sales
set CustomerID=(
    select top 1 star_schema_aw2017.dbo.D_Individual_Customer.IndividualCustomerKey
    from star_schema_aw2017.dbo.D_Individual_Customer
    where D_Individual_Customer.IndividualCustomerID = #stage_f_internet_sales.CustomerID
)

-- The code below is handling duplicates. Duplicates can happen if a person bought
-- the same product in the same day 2 or more times in different orders.
-- As a solution, if such situations are encountered, the values of product
-- quantity and line total are summed.
drop table if exists #temp_fact;

select ProductID, CustomerID, DateID, SUM(ProductQuantity) as ProductQuantity, SUM(LineTotal) as LineTotal
into #temp_fact
from #stage_f_internet_sales
group by ProductID, CustomerID, DateID;

drop table if exists #stage_f_internet_sales;

select *
into #stage_f_internet_sales
from #temp_fact;

-- Load
insert into star_schema_aw2017.dbo.F_Internet_Sales (DateKey, IndividualCustomerKey, ProductKey, ProductQuantity,
                                                     LineTotal)
select DateID,
       CustomerID,
       ProductID,
       ProductQuantity,
       LineTotal
from #stage_f_internet_sales