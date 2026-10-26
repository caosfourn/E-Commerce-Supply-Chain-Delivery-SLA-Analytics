USE olist;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
-- First run: python scripts/prepare_review_bulk.py (from project root).
-- Review comments contain embedded newlines/quotes. Load their lossless
-- prepared representation in character mode instead of the BULK CSV parser.
BEGIN TRY
BEGIN TRAN;
DECLARE @folder NVARCHAR(260) = N'D:\HuynhHan\E-Commerce_Supply_Chain&Delivery_SLA_Analytics\data\raw\';    
-- Both paths are read by the SQL Server service, not by SSMS on the client.
DECLARE @review_file NVARCHAR(4000) = @folder + N'..\prepared\olist_order_reviews.bulk';

DECLARE @files TABLE (stg_table SYSNAME, file_name NVARCHAR(200), row_term NVARCHAR(10) NOT NULL);

INSERT @files (stg_table, file_name, row_term) VALUES
 (N'stg.customers',            N'olist_customers_dataset.csv',        N'0x0a'),
 (N'stg.geolocation',          N'olist_geolocation_dataset.csv',      N'0x0a'),
 (N'stg.order_items',          N'olist_order_items_dataset.csv',      N'0x0a'),
 (N'stg.order_payments',       N'olist_order_payments_dataset.csv',   N'0x0a'),
 (N'stg.order_reviews',        N'olist_order_reviews.bulk',           N'0x1e'),
 (N'stg.orders',               N'olist_orders_dataset.csv',           N'0x0a'),
 (N'stg.products',             N'olist_products_dataset.csv',         N'0x0a'),
 (N'stg.sellers',              N'olist_sellers_dataset.csv',          N'0x0a'),
 (N'stg.category_translation', N'product_category_name_translation.csv', N'0x0a');

DECLARE @t SYSNAME, @f NVARCHAR(200), @rt NVARCHAR(10), @sql NVARCHAR(MAX);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT stg_table, file_name, row_term FROM @files;
OPEN c;
FETCH NEXT FROM c INTO @t, @f, @rt;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF @t = N'stg.order_reviews'
        SET @sql = N'TRUNCATE TABLE stg.order_reviews;
            BULK INSERT stg.order_reviews FROM ''' + REPLACE(@review_file, N'''', N'''''') + N'''
            WITH (DATAFILETYPE = ''char'', CODEPAGE = ''65001'',
                  FIELDTERMINATOR = ''0x1f'', ROWTERMINATOR = ''0x1e'',
                  FIRSTROW = 1, MAXERRORS = 0, TABLOCK);';
    ELSE
        SET @sql = N'TRUNCATE TABLE ' + @t + N';
        BULK INSERT ' + @t + N' FROM ''' + REPLACE(@folder + @f, N'''', N'''''') + N'''
        WITH (FORMAT = ''CSV'', FIELDQUOTE = ''"'', FIELDTERMINATOR = '','','
        + CASE WHEN @rt = N'' THEN N'' ELSE N' ROWTERMINATOR = ''' + @rt + N''',' END
        + N' FIRSTROW = 2, CODEPAGE = ''65001'', MAXERRORS = 0, TABLOCK);';
    BEGIN TRY
        EXEC sys.sp_executesql @sql;
        -- Original Olist snapshot: prevent publishing a partial review load.
        -- If using another snapshot, update this expected count from the prepared .json manifest.
        IF @t=N'stg.order_reviews' AND (SELECT COUNT_BIG(*) FROM stg.order_reviews)<>99224
            THROW 50002, 'Expected 99224 reviews. Check prepared manifest and source snapshot.', 1;
        PRINT N'Đã nạp ' + @f;
    END TRY
    BEGIN CATCH
        PRINT N'LỖI khi nạp ' + @f + N': ' + ERROR_MESSAGE();
        IF @t = N'stg.order_reviews'
            PRINT N'Chạy python scripts/prepare_review_bulk.py; kiểm tra @review_file và quyền đọc của SQL Server.';
        THROW;      
    END CATCH
    FETCH NEXT FROM c INTO @t, @f, @rt;
END
CLOSE c; DEALLOCATE c;


COMMIT;
PRINT N'COMMIT: Đã nạp đủ 9 bảng staging. Có thể chạy bước 03.';
END TRY
BEGIN CATCH
IF XACT_STATE()<>0 ROLLBACK;
IF CURSOR_STATUS('local','c')>=0 CLOSE c;
IF CURSOR_STATUS('local','c')>-3 DEALLOCATE c;
PRINT N'ROLLBACK: Không giữ thay đổi của lần nạp lỗi này. Sửa lỗi rồi chạy lại toàn bộ bước 02.';
THROW;
END CATCH;
