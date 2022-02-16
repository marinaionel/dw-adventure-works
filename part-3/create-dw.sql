USE star_schema_aw2017
GO

-----------------------------------------------------DATE DIMENSION-----------------------------------------------------
CREATE TABLE dbo.D_Date
(
    DateKey     int IDENTITY
        CONSTRAINT PK_D_Date PRIMARY KEY,
    DateSql     date        NOT NULL,
    MonthNumber int         NOT NULL,
    MonthName   varchar(15) NOT NULL,
    Year        int,
    DayOfMonth  int
)
GO
------------------------------------------------------------------------------------------------------------------------

----------------------------------------------INDIVIDUAL CUSTOMER DIMENSION---------------------------------------------
CREATE TABLE dbo.D_Individual_Customer
(
    IndividualCustomerKey int IDENTITY
        CONSTRAINT PK_D_Customer PRIMARY KEY,
    IndividualCustomerID  int          NOT NULL,
    FirstName             nvarchar(50) NOT NULL,
    LastName              nvarchar(50) NOT NULL,
    ValidFrom             date,
    ValidTo               date
)
GO
------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------PRODUCT DIMENSION---------------------------------------------------
CREATE TABLE dbo.D_Product
(
    ProductKey  int IDENTITY
        CONSTRAINT PK_D_Product PRIMARY KEY,
    ProductName nvarchar(50) NOT NULL,
    ProductID   int          NOT NULL,
    ValidFrom   date,
    ValidTo     date
)
GO
------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------SALES FACT-------------------------------------------------------
CREATE TABLE dbo.F_Internet_Sales
(
    DateKey               int            NOT NULL
        CONSTRAINT FK_F_Sales_D_Date REFERENCES dbo.D_Date,
    IndividualCustomerKey int            NOT NULL
        CONSTRAINT FK_F_Sales_D_Individual_Customer REFERENCES dbo.D_Individual_Customer,
    ProductKey            int            NOT NULL
        CONSTRAINT FK_F_Sales_D_Product REFERENCES dbo.D_Product,
    ProductQuantity       int            NOT NULL,
    LineTotal             numeric(38, 6) NOT NULL,
    CONSTRAINT PK_F_Internet_Sales PRIMARY KEY (DateKey, IndividualCustomerKey, ProductKey)
)
GO
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------LAST UPDATED------------------------------------------------------
CREATE TABLE dbo.LastUpdated
(
    LastUpdated date
)
GO
------------------------------------------------------------------------------------------------------------------------