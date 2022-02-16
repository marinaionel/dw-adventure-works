USE AdventureWorks2017
GO

INSERT INTO AdventureWorks2017.Production.Product (Name, ProductNumber, MakeFlag, FinishedGoodsFlag, Color,
                                                   SafetyStockLevel, ReorderPoint, StandardCost, ListPrice, Size,
                                                   SizeUnitMeasureCode, WeightUnitMeasureCode, Weight,
                                                   DaysToManufacture, ProductLine, Class, Style, ProductSubcategoryID,
                                                   ProductModelID, SellStartDate, SellEndDate, DiscontinuedDate,
                                                   rowguid, ModifiedDate)
VALUES (N'Rockrider All-Mountain Black, 50', N'BK-R18B-50', 1, 1, N'Black', 300, 75, 31.6537, 65.7854, N'50', N'CM',
        N'LB', 1.86, 2, N'R', N'M', N'U', 22, 13, N'2013-05-30 00:00:00.000', NULL, NULL, DEFAULT, DEFAULT);

DELETE FROM AdventureWorks2017.Production.Product WHERE ProductID = 1

UPDATE AdventureWorks2017.Production.Product SET Name = N'Blade L' WHERE ProductID = 316