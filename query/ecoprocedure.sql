
-- auto dtect the uniqness

DELIMITER $$

CREATE PROCEDURE AutoDetectColumnCategory(IN tbl_name VARCHAR(64))
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE col VARCHAR(64);
    DECLARE col_type VARCHAR(64);
    DECLARE distinct_count INT;
    DECLARE total_count INT;
    DECLARE category_name VARCHAR(100);
    
    -- Cursor to get all columns from the table
    DECLARE col_cursor CURSOR FOR 
        SELECT COLUMN_NAME, DATA_TYPE
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_SCHEMA = DATABASE() 
          AND TABLE_NAME = tbl_name
        ORDER BY ORDINAL_POSITION;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Create temporary table to store results
    DROP TEMPORARY TABLE IF EXISTS column_analysis_results;
    CREATE TEMPORARY TABLE column_analysis_results (
        column_name VARCHAR(64),
        data_type VARCHAR(64),
        distinct_values INT,
        total_rows INT,
        category VARCHAR(100),
        uniqueness_pct DECIMAL(5, 2)
    );
    
    -- Get total row count once
    SET @sql = CONCAT('SELECT COUNT(*) INTO @total_cnt FROM `', tbl_name, '`');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SET total_count = @total_cnt;
    
    -- Open cursor and loop through all columns
    OPEN col_cursor;
    
    read_loop: LOOP
        FETCH col_cursor INTO col, col_type;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- Get distinct count for this column
        SET @sql = CONCAT(
            'SELECT COUNT(DISTINCT `', col, '`) INTO @distinct_cnt FROM `', tbl_name, '`'
        );
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
        SET distinct_count = @distinct_cnt;
        
        -- Determine category based on data type and distinct values
        IF col_type IN ('int','bigint','smallint','tinyint','mediumint','decimal','float','double','numeric') THEN
            -- Numerical column
            IF distinct_count < 20 THEN
                SET category_name = 'Numerical Discrete';
            ELSE
                SET category_name = 'Numerical Continuous';
            END IF;
        ELSEIF col_type IN ('date','datetime','timestamp','time','year') THEN
            -- Date/Time column
            SET category_name = 'Temporal';
        ELSEIF col_type IN ('char','varchar','text','mediumtext','longtext') THEN
            -- Text column
            IF distinct_count < 20 THEN
                SET category_name = 'Nominal / Categorical';
            ELSEIF distinct_count >= total_count * 0.95 THEN
                SET category_name = 'Unique Identifier';
            ELSE
                SET category_name = 'Nominal / Text (High Cardinality)';
            END IF;
        ELSE
            -- Other types (enum, set, etc.)
            SET category_name = 'Other';
        END IF;
        
        -- Insert results
        INSERT INTO column_analysis_results VALUES (
            col, 
            col_type, 
            distinct_count, 
            total_count, 
            category_name,
            ROUND((distinct_count / total_count) * 100, 2)
        );
        
    END LOOP;
    
    CLOSE col_cursor;
    
    -- Display results in formatted table (Main Output)
    SELECT 
        column_name AS 'Column Name',
        data_type AS 'Data Type',
        distinct_values AS 'Distinct Values',
        total_rows AS 'Total Rows',
        category AS 'Category',
        CONCAT(uniqueness_pct, '%') AS 'Uniqueness %'
    FROM column_analysis_results
    ORDER BY 
        CASE category
            WHEN 'Unique Identifier' THEN 1
            WHEN 'Numerical Continuous' THEN 2
            WHEN 'Numerical Discrete' THEN 3
            WHEN 'Temporal' THEN 4
            WHEN 'Nominal / Categorical' THEN 5
            WHEN 'Nominal / Text (High Cardinality)' THEN 6
            ELSE 7
        END,
        column_name;
    
    -- Clean up
    DROP TEMPORARY TABLE IF EXISTS column_analysis_results;
    
END $$

DELIMITER ;
select * from dim_product;
call basictable('basic_calculation','dim_product','ajio_mrp,amazon_mrp,flipkart_mrp,limeroad_mrp,myntra_mrp,paytm_mrp');
select * from basic_calculation;
drop procedure basictable;
-- basic calculation like min,max,sum,avg
- basic calculation
DELIMITER //

CREATE PROCEDURE basictable(
    IN view_name VARCHAR(100),
    IN table_name VARCHAR(100),
    IN metric_columns TEXT             -- Comma-separated: 'col1,col2,col3'
)
BEGIN
    DECLARE col_name VARCHAR(100);
    DECLARE query_text TEXT DEFAULT '';
    DECLARE union_text TEXT DEFAULT '';
    DECLARE col_count INT;
    DECLARE i INT DEFAULT 1;
    DECLARE first_union BOOLEAN DEFAULT TRUE;
    DECLARE drop_sql TEXT;

    -- Drop existing view if it exists
    SET @drop_sql = CONCAT('DROP VIEW IF EXISTS `', view_name, '`');
    PREPARE stmt FROM @drop_sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- Count number of metric columns
    SET col_count = (CHAR_LENGTH(metric_columns) - CHAR_LENGTH(REPLACE(metric_columns, ',', '')) + 1);

    -- Loop through columns
    WHILE i <= col_count DO
        SET col_name = TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(metric_columns, ',', i), ',', -1));

        -- Add UNION ALL if not the first column
        IF NOT first_union THEN
            SET union_text = CONCAT(union_text, ' UNION ALL ');
        END IF;

        -- Build the SELECT part (NO semicolon here!)
        SET union_text = CONCAT(
            union_text,
            'SELECT ',
               '''', col_name, ''' AS metric_name, ',
               'COUNT(`', col_name, '`) AS count_value, ',
               'COUNT(DISTINCT `', col_name, '`) AS distinct_count, ',
               'AVG(`', col_name, '`) AS avg_value, ',
               'SUM(`', col_name, '`) AS sum_value, ',
               'MIN(`', col_name, '`) AS min_value, ',
               'MAX(`', col_name, '`) AS max_value, ',
               'STDDEV(`', col_name, '`) AS stddev_value ',
            'FROM `', table_name, '` ',
            'WHERE `', col_name, '` > 0'
        );

        SET first_union = FALSE;
        SET i = i + 1;
    END WHILE;

    -- Build full CREATE VIEW query
    SET query_text = CONCAT('CREATE OR REPLACE VIEW `', view_name, '` AS ', union_text);

    -- Debug (optional): view generated query
    SELECT query_text AS generated_query;

    -- Execute final SQL
    SET @sql = query_text;
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- Confirmation
    SELECT CONCAT('View "', view_name, '" created successfully') AS status;
END //

DELIMITER ;



