-- Migration: Add discount columns to transactions table
-- Run this SQL on your database to add discount fields to transactions

ALTER TABLE transactions
ADD COLUMN jenis_diskon ENUM('percentage','nominal','buyxgety') DEFAULT NULL AFTER tax_percentage,
ADD COLUMN nilai_diskon DECIMAL(10,2) DEFAULT NULL AFTER jenis_diskon,
ADD COLUMN buy_qty INT(11) DEFAULT NULL AFTER nilai_diskon,
ADD COLUMN free_qty INT(11) DEFAULT NULL AFTER buy_qty;

-- Add comment for documentation
ALTER TABLE transactions COMMENT 'Transaction table with discount support';
