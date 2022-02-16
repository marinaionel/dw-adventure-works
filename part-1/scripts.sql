CREATE TABLE [dbo].[D_Individual_Customer](
    [IndividualCustomerKey] [int] IDENTITY(1, 1) PRIMARY KEY NOT NULL,
    [IndividualCustomerID] [int] UNIQUE NOT NULL,
    [FirstName] [nvarchar](50) NOT NULL,
    [LastName] [nvarchar](50) NOT NULL
)
GO CREATE TABLE [dbo].[D_Order_Date](
        [DateKey] [int] IDENTITY(1, 1) PRIMARY KEY NOT NULL,
        [OrderDateSql] [datetime] UNIQUE NOT NULL,
        [OrderMothName] [nvarchar](15) NOT NULL,
        [OrderMothNumber] AS (datepart(month, [OrderDateSql])) PERSISTED
    )
GO CREATE TABLE [dbo].[D_Product](
        [ProductKey] [int] IDENTITY(1, 1) PRIMARY KEY NOT NULL,
        [ProductName] [nvarchar](50) UNIQUE NOT NULL,
        [ProductNumber] [nvarchar](25) NOT NULL
    )
GO CREATE TABLE [dbo].[F_Internet_Sales](
        [DateKey] [int] NOT NULL,
        [IndividualCustomerKey] [int] NOT NULL,
        [ProductKey] [int] NOT NULL,
        [OrderProductQuantity] [smallint] NOT NULL,
        [LineTotal] [numeric](38, 6) NOT NULL,
        [UnitPrice] [money] NOT NULL,
        [DiscountUnitPrice] [money] NOT NULL,
        [ActualUnitPrice] AS ([UnitPrice] *((1) - [DiscountUnitPrice])) PERSISTED CONSTRAINT PK_Fact PRIMARY KEY CLUSTERED ([DateKey], [IndividualCustomerKey], [ProductKey])
    )
GO
ALTER TABLE [dbo].[F_Internet_Sales] WITH CHECK
ADD CONSTRAINT [FK_F_Sales_D_Date] FOREIGN KEY([DateKey]) REFERENCES [dbo].[D_Order_Date] ([DateKey])
GO
ALTER TABLE [dbo].[F_Internet_Sales] CHECK CONSTRAINT [FK_F_Sales_D_Date]
GO
ALTER TABLE [dbo].[F_Internet_Sales] WITH CHECK
ADD CONSTRAINT [FK_F_Sales_D_Individual_Customer] FOREIGN KEY([IndividualCustomerKey]) REFERENCES [dbo].[D_Individual_Customer] ([IndividualCustomerKey])
GO
ALTER TABLE [dbo].[F_Internet_Sales] CHECK CONSTRAINT [FK_F_Sales_D_Individual_Customer]
GO
ALTER TABLE [dbo].[F_Internet_Sales] WITH CHECK
ADD CONSTRAINT [FK_F_Sales_D_Product] FOREIGN KEY([ProductKey]) REFERENCES [dbo].[D_Product] ([ProductKey])
GO
ALTER TABLE [dbo].[F_Internet_Sales] CHECK CONSTRAINT [FK_F_Sales_D_Product]
GO