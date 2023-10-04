CREATE DATABASE customer_data;
USE customer_data;

SELECT * FROM details LIMIT 10;

-- Data Cleaning --

-- Normalise Text

SET sql_safe_updates = 0;

UPDATE details
SET 
    first_name = LOWER(first_name),
    last_name = LOWER(last_name),
    email = LOWER(email),
    city = LOWER(city),
    country = LOWER(country),
    street_address = LOWER(street_address);
    
-- Remove Whitespaces

UPDATE details
SET 
    first_name = TRIM(first_name),
    last_name = TRIM(last_name),
    email = TRIM(email),
    city = TRIM(city),
    country = TRIM(country),
    street_address = TRIM(street_address);
    
    -- Handling Special Characters 
UPDATE details
SET street_address = REPLACE(street_address, '&', 'and');

UPDATE details 
SET phone = REPLACE(phone, '-', '');



-- Deterministic Matching --


-- Extracting potential matches based on exact street address and phone number

SELECT A.*, B.*
FROM details A
JOIN details B 
ON A.id <> B.id
AND A.street_address = B.street_address
AND A.phone = B.phone;

SELECT COUNT(*) / 2 AS num_matches
FROM details A
JOIN details B 
ON A.id <> B.id
AND A.street_address = B.street_address
AND A.phone = B.phone;

-- Create the name_variations table for fuzzy matching
CREATE TABLE name_variations (
    long_name VARCHAR(255),
    alias VARCHAR(255)
);

-- Insert name variations
INSERT INTO name_variations (long_name, alias) VALUES
('Abigail', 'Abi'),
('Elizabeth', 'Lizzie'),
('David', 'Dave'),
('William', 'Will'),
('William', 'Bill'),
('William', 'Billy'),
('Robert', 'Rob'),
('Robert', 'Bobby'),
('Robert', 'Bob'),
('Johnathan', 'John'),
('Johnathan', 'Johnny'),
('Katherine', 'Kate'),
('Katherine', 'Katie'),
('Katherine', 'Kathy');

-- Create a table for identified matches to prevent duplicates

CREATE TABLE identified_matches (
    id_A BIGINT,
    first_name_A VARCHAR(255),
    last_name_A VARCHAR(255),
    id_B BIGINT,
    first_name_B VARCHAR(255),
    last_name_B VARCHAR(255)
);



-- Fuzzy Matching using reference table
SELECT A.*, B.*
FROM details A
JOIN name_variations NV ON A.first_name = NV.long_name
JOIN details B 
ON NV.alias = B.first_name 
AND A.id <> B.id
AND A.street_address = B.street_address
AND A.phone = B.phone;

SELECT COUNT(*)
FROM details A
JOIN name_variations NV ON A.first_name = NV.long_name
JOIN details B 
ON NV.alias = B.first_name 
AND A.id <> B.id
AND A.street_address = B.street_address
AND A.phone = B.phone;

INSERT INTO identified_matches (id_A, first_name_A, last_name_A, id_B, first_name_B, last_name_B)
SELECT A.id, A.first_name, A.last_name, B.id, B.first_name, B.last_name
FROM details A
JOIN name_variations NV ON A.first_name = NV.long_name
JOIN details B 
ON NV.alias = B.first_name 
AND A.id <> B.id
AND A.street_address = B.street_address
AND A.phone = B.phone;


-- Matching using SOUNDEX for similar sounding names

SELECT A.*, B.*
FROM details A
JOIN details B 
ON SOUNDEX(A.first_name) = SOUNDEX(B.first_name)
AND A.id < B.id
AND A.street_address = B.street_address
AND A.phone = B.phone
WHERE A.first_name <> B.first_name;

SELECT COUNT
FROM details A
JOIN details B 
ON SOUNDEX(A.first_name) = SOUNDEX(B.first_name)
AND A.id < B.id
AND A.street_address = B.street_address
AND A.phone = B.phone
WHERE A.first_name <> B.first_name;

INSERT INTO identified_matches (id_A, first_name_A, last_name_A, id_B, first_name_B, last_name_B)
SELECT A.id, A.first_name, A.last_name, B.id, B.first_name, B.last_name
FROM details A
JOIN details B 
ON SOUNDEX(A.first_name) = SOUNDEX(B.first_name)
AND A.id < B.id  
AND A.street_address = B.street_address
AND A.phone = B.phone
WHERE A.first_name <> B.first_name
AND (A.id, B.id) NOT IN (SELECT id_A, id_B FROM identified_matches)
AND (B.id, A.id) NOT IN (SELECT id_A, id_B FROM identified_matches);

-- Matching using first 3 characters (for abbreviated names)
SELECT A.*, B.*
FROM details A
JOIN details B 
ON LEFT(A.first_name, 3) = LEFT(B.first_name, 3)
AND A.id <> B.id
AND A.street_address = B.street_address
AND A.phone = B.phone
WHERE A.first_name <> B.first_name;

SELECT COUNT(*)
FROM details A
JOIN details B 
ON LEFT(A.first_name, 3) = LEFT(B.first_name, 3)
AND A.id <> B.id
AND A.street_address = B.street_address
AND A.phone = B.phone
WHERE A.first_name <> B.first_name;

INSERT INTO identified_matches (id_A, first_name_A, last_name_A, id_B, first_name_B, last_name_B)
SELECT A.id, A.first_name, A.last_name, B.id, B.first_name, B.last_name
FROM details A
JOIN details B 
ON LEFT(A.first_name, 3) = LEFT(B.first_name, 3)
AND A.id < B.id  
AND A.street_address = B.street_address
AND A.phone = B.phone
WHERE A.first_name <> B.first_name
AND (A.id, B.id) NOT IN (SELECT id_A, id_B FROM identified_matches)
AND (B.id, A.id) NOT IN (SELECT id_A, id_B FROM identified_matches);


SELECT * FROM identified_matches;

-- Link records on required criteria. For this project, I will choose the longer name as the master record

SELECT
    CASE 
        WHEN LENGTH(first_name_A) + LENGTH(last_name_A) >= LENGTH(first_name_B) + LENGTH(last_name_B) THEN id_A
        ELSE id_B
    END AS master_id,
    CASE 
        WHEN LENGTH(first_name_A) + LENGTH(last_name_A) < LENGTH(first_name_B) + LENGTH(last_name_B) THEN id_A
        ELSE id_B
    END AS non_master_id
FROM identified_matches;

-- Archive non-master records

CREATE TABLE archived_records AS
SELECT details.*
FROM details
JOIN (
    SELECT 
        CASE 
            WHEN LENGTH(first_name_A) + LENGTH(last_name_A) < LENGTH(first_name_B) + LENGTH(last_name_B) THEN id_A
            ELSE id_B
        END AS non_master_id
    FROM identified_matches
) AS NonMasterIDs ON details.id = NonMasterIDs.non_master_id;

SELECT * FROM archived_records;

-- Delete non-master records

DELETE FROM details
WHERE id IN (SELECT id FROM archived_records);
