-- Extraction Individual Customer
insert into [star_schema_aw2017].[Stage].[stage_d_individual_customer] (IndividualCustomerID, FirstName, LastName)
select [PersonID], [FirstName], [LastName]
from [AdventureWorks2017].[Sales].[Customer]
         join [AdventureWorks2017].[Person].[Person] on [AdventureWorks2017].[Person].[Person].[BusinessEntityID] =
                                                        [AdventureWorks2017].[Sales].[Customer].[PersonID]
where BusinessEntityID is not null
  and PersonID is not null;

-- Transformation
UPDATE Stage.stage_d_individual_customer
set FirstName='Unknown'
where FirstName is null;

UPDATE Stage.stage_d_individual_customer
set LastName='Unknown'
where LastName is null;

-- Load
insert into star_schema_aw2017.dbo.D_Individual_Customer (IndividualCustomerID, FirstName, LastName)
select IndividualCustomerID, FirstName, LastName
from Stage.stage_d_individual_customer;

-- Extraction Product
insert into star_schema_aw2017.Stage.stage_d_product (ProductName, ProductID)
select Name, ProductID
from AdventureWorks2017.Production.Product;

-- Transformation
UPDATE Stage.stage_d_product
set ProductName='Unknown'
where ProductName is null;

-- Load
insert into star_schema_aw2017.dbo.D_Product (ProductName, ProductID)
SELECT ProductName, ProductID
from Stage.stage_d_product;

-- Extraction Date
insert into star_schema_aw2017.Stage.stage_order_date (OrderDateSql, DateID)
select OrderDate, SalesOrderID
from AdventureWorks2017.Sales.SalesOrderHeader
where OnlineOrderFlag = 1;

-- Transformation
update Stage.stage_order_date
set OrderMonthNumber =datepart(month, stage_order_date.OrderDateSql);

update Stage.stage_order_date
set OrderMonthName = CASE MONTH([OrderDateSql])
                         WHEN 1 THEN 'January'
                         WHEN 2 THEN 'February'
                         WHEN 3 THEN 'March'
                         WHEN 4 THEN 'April'
                         WHEN 5 THEN 'May'
                         WHEN 6 THEN 'June'
                         WHEN 7 THEN 'July'
                         WHEN 8 THEN 'August'
                         WHEN 9 THEN 'September'
                         WHEN 10 THEN 'October'
                         WHEN 11 THEN 'November'
                         WHEN 12 THEN 'December'
    END;

-- Load
insert into dbo.D_Order_Date (OrderDateSql, OrderMothNumber, OrderMonthName, DateID)
SELECT OrderDateSql, OrderMonthNumber, OrderMonthName, DateID
from Stage.stage_order_date;

-- Extract Fact Table
insert into Stage.stage_f_internet_sales (ProductID, OrderDateID, CustomerID, OrderProductQuantity, LineTotal,
                                          UnitPrice, DiscountUnitPrice)
select Product.ProductID,
       SalesOrderHeader.SalesOrderID,
       Customer.CustomerID,
       OrderQty,
       LineTotal,
       UnitPrice,
       UnitPriceDiscount
from AdventureWorks2017.Sales.SalesOrderDetail
         join AdventureWorks2017.Production.Product on Product.ProductID = SalesOrderDetail.ProductID
         join AdventureWorks2017.Sales.SalesOrderHeader on SalesOrderDetail.SalesOrderID = SalesOrderHeader.SalesOrderID
         join AdventureWorks2017.Sales.Customer on SalesOrderHeader.CustomerID = Customer.CustomerID
where OnlineOrderFlag = 1;

-- Transform
UPDATE Stage.stage_f_internet_sales
set ActualUnitPrice=UnitPrice * (1 - DiscountUnitPrice);

UPDATE Stage.stage_f_internet_sales
set CustomerID=(
    select IndividualCustomerKey
    from dbo.D_Individual_Customer
    where IndividualCustomerID = stage_f_internet_sales.CustomerID
)

UPDATE Stage.stage_f_internet_sales
set ProductID=(
    select ProductKey
    from dbo.D_Product p
    where p.ProductID = stage_f_internet_sales.ProductID
)

UPDATE Stage.stage_f_internet_sales
set OrderDateID=(
    select DateKey
    from dbo.D_Order_Date d
    where d.DateID = stage_f_internet_sales.OrderDateID
)

-- Load
insert into F_Internet_Sales (DateKey, IndividualCustomerKey, ProductKey, OrderProductQuantity, LineTotal, UnitPrice,
                              DiscountUnitPrice, ActualUnitPrice)
select OrderDateID,
       CustomerID,
       ProductID,
       OrderProductQuantity,
       LineTotal,
       UnitPrice,
       DiscountUnitPrice,
       ActualUnitPrice
from Stage.stage_f_internet_sales

-- Clear staging tables
DELETE star_schema_aw2017.Stage.stage_d_individual_customer;
DELETE star_schema_aw2017.Stage.stage_d_product;
DELETE star_schema_aw2017.Stage.stage_order_date;
DELETE star_schema_aw2017.Stage.stage_f_internet_sales;