-- phpMyAdmin SQL Dump
-- version 5.2.1
-- Host: 127.0.0.1
-- Waktu pembuatan: 16 Des 2025 14:06
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';
START TRANSACTION;
SET time_zone = '+00:00';

SET NAMES utf8mb4;

-- --------------------------------------------------------
-- Table: activity_logs
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS activity_logs (
  id INT(11) NOT NULL AUTO_INCREMENT,
  user_id INT(11) DEFAULT NULL,
  store_id INT(11) DEFAULT NULL,
  action VARCHAR(64) DEFAULT NULL,
  detail TEXT DEFAULT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------
-- Table: clients
-- --------------------------------------------------------
CREATE TABLE clients (
  id INT(11) NOT NULL,
  owner_id INT(11) DEFAULT NULL,
  user_id INT(11) DEFAULT NULL,
  db_name VARCHAR(100) DEFAULT NULL,
  db_user VARCHAR(100) DEFAULT NULL,
  db_password VARCHAR(100) DEFAULT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------
-- Table: owners
-- --------------------------------------------------------
CREATE TABLE owners (
  id INT(11) NOT NULL,
  business_name VARCHAR(255) NOT NULL,
  email VARCHAR(100) NOT NULL,
  phone VARCHAR(20) DEFAULT NULL,
  password VARCHAR(255) NOT NULL,
  package_id INT(11) DEFAULT 1,
  package_expired_at DATETIME DEFAULT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  address TEXT DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------
-- Table: products
-- --------------------------------------------------------
CREATE TABLE products (
  id INT(11) NOT NULL,
  store_id INT(11) NOT NULL,
  name VARCHAR(200) NOT NULL,
  sku VARCHAR(50) DEFAULT NULL,
  barcode VARCHAR(100) DEFAULT NULL,
  price DECIMAL(10,2) NOT NULL,
  cost_price DECIMAL(18,2) DEFAULT 0,
  stock INT(11) DEFAULT 0,
  category ENUM(
    'Kesehatan & Kecantikan',
    'Rumah Tangga & Gaya Hidup',
    'Fashion & Aksesoris',
    'Elektronik',
    'Bayi & Anak',
    'Makanan & Minuman'
  ) DEFAULT NULL,
  description TEXT DEFAULT NULL,
  image_url TEXT DEFAULT NULL,
  is_active TINYINT(1) DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  jenis_diskon ENUM('percentage','nominal') DEFAULT NULL,
  nilai_diskon DECIMAL(10,2) DEFAULT NULL,
  diskon_bundle_min_qty INT(11) DEFAULT NULL,
  diskon_bundle_value DECIMAL(10,2) DEFAULT NULL,
  buy_qty INT(11) DEFAULT NULL,
  free_qty INT(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------
-- Table: stores
-- --------------------------------------------------------
CREATE TABLE stores (
  id INT(11) NOT NULL,
  type VARCHAR(32) NOT NULL DEFAULT 'store',
  owner_id INT(11) NOT NULL,
  name VARCHAR(100) NOT NULL,
  business_name VARCHAR(150) DEFAULT NULL,
  address TEXT DEFAULT NULL,
  phone VARCHAR(20) DEFAULT NULL,
  receipt_template TEXT DEFAULT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  tax_percentage DECIMAL(5,2) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------
-- Table: struck_receipt
-- --------------------------------------------------------
CREATE TABLE struck_receipt (
  id INT(11) NOT NULL,
  store_id INT(11) DEFAULT NULL,
  template_name VARCHAR(100) NOT NULL,
  template_data TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------
-- Table: subscriptions
-- --------------------------------------------------------
CREATE TABLE subscriptions (
  id INT(11) NOT NULL,
  owner_id INT(11) NOT NULL,
  user_id INT(11) DEFAULT NULL,
  status ENUM('Aktif','Nonaktif') NOT NULL DEFAULT 'Nonaktif',
  plan ENUM('Pro','Standard','Eksklusif') NOT NULL DEFAULT 'Standard',
  start_date DATETIME NOT NULL,
  end_date DATETIME NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------
-- Table: transactions
-- --------------------------------------------------------
CREATE TABLE transactions (
  id INT(11) NOT NULL AUTO_INCREMENT,
  store_id INT(11) DEFAULT NULL,
  user_id INT(11) DEFAULT NULL,
  total_cost DECIMAL(10,2) NOT NULL,
  payment_type VARCHAR(50) DEFAULT NULL,
  payment_method VARCHAR(50) DEFAULT NULL,
  received_amount DECIMAL(10,2) NOT NULL,
  change_amount DECIMAL(10,2) NOT NULL,
  customer_name VARCHAR(100) DEFAULT NULL,
  customer_phone VARCHAR(15) DEFAULT NULL,
  payment_status VARCHAR(50) DEFAULT 'pending',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  tax DECIMAL(12,2) DEFAULT 0,
  tax_percentage DECIMAL(5,2) DEFAULT 0,
  role VARCHAR(20),
  is_owner BOOLEAN,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------
-- Table: transaction_items
-- --------------------------------------------------------
CREATE TABLE transaction_items (
  id INT(11) NOT NULL AUTO_INCREMENT,
  transaction_id INT(11) NOT NULL,
  product_name VARCHAR(255) DEFAULT NULL,
  product_id INT(11) DEFAULT NULL,
  qty INT(11) NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  subtotal DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------
-- Table: users
-- --------------------------------------------------------
CREATE TABLE users (
  id INT(11) NOT NULL,
  owner_id INT(11) NOT NULL,
  store_id INT(11) DEFAULT NULL,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(100) DEFAULT NULL,
  username VARCHAR(50) NOT NULL,
  password VARCHAR(255) NOT NULL,
  role ENUM('owner','admin','cashier') DEFAULT 'cashier',
  is_active TINYINT(1) DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------
-- Table: reports_daily
-- --------------------------------------------------------
CREATE TABLE reports_daily (
  id INT(11) NOT NULL AUTO_INCREMENT,
  store_id INT(11) NOT NULL,
  report_date DATE NOT NULL,
  total_transactions INT DEFAULT 0,
  total_income DECIMAL(18,2) DEFAULT 0,
  total_discount DECIMAL(18,2) DEFAULT 0,
  net_revenue DECIMAL(18,2) DEFAULT 0,
  total_hpp DECIMAL(18,2) DEFAULT 0,
  gross_profit DECIMAL(18,2) DEFAULT 0,
  operational_cost DECIMAL(18,2) DEFAULT 0,
  net_profit DECIMAL(18,2) DEFAULT 0,
  margin VARCHAR(10) DEFAULT '0%',
  best_sales_day DECIMAL(18,2) DEFAULT 0,
  lowest_sales_day DECIMAL(18,2) DEFAULT 0,
  avg_daily DECIMAL(18,2) DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_store_date (store_id, report_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------
-- INDEXES
-- --------------------------------------------------------
ALTER TABLE clients ADD PRIMARY KEY (id);

ALTER TABLE owners
  ADD PRIMARY KEY (id),
  ADD UNIQUE KEY email (email);

ALTER TABLE products
  ADD PRIMARY KEY (id),
  ADD UNIQUE KEY sku (sku),
  ADD KEY idx_store (store_id),
  ADD KEY idx_sku (sku),
  ADD KEY idx_active (is_active);

ALTER TABLE stores
  ADD PRIMARY KEY (id),
  ADD KEY owner_id (owner_id);

ALTER TABLE struck_receipt
  ADD PRIMARY KEY (id),
  ADD KEY store_id (store_id);

ALTER TABLE subscriptions
  ADD PRIMARY KEY (id),
  ADD KEY owner_id (owner_id);

ALTER TABLE transactions
  ADD KEY store_id (store_id),
  ADD KEY user_id (user_id);

ALTER TABLE users
  ADD PRIMARY KEY (id),
  ADD UNIQUE KEY username (username),
  ADD KEY owner_id (owner_id),
  ADD KEY store_id (store_id);

ALTER TABLE reports_daily
  ADD PRIMARY KEY (id),
  ADD KEY idx_store_date (store_id,report_date);

-- --------------------------------------------------------
-- AUTO_INCREMENT
-- --------------------------------------------------------
ALTER TABLE clients MODIFY id INT(11) NOT NULL AUTO_INCREMENT;
ALTER TABLE owners MODIFY id INT(11) NOT NULL AUTO_INCREMENT;
ALTER TABLE products MODIFY id INT(11) NOT NULL AUTO_INCREMENT;
ALTER TABLE stores MODIFY id INT(11) NOT NULL AUTO_INCREMENT;
ALTER TABLE struck_receipt MODIFY id INT(11) NOT NULL AUTO_INCREMENT;
ALTER TABLE subscriptions MODIFY id INT(11) NOT NULL AUTO_INCREMENT;
ALTER TABLE users MODIFY id INT(11) NOT NULL AUTO_INCREMENT;
ALTER TABLE reports_daily MODIFY id INT(11) NOT NULL AUTO_INCREMENT;

-- --------------------------------------------------------
-- FOREIGN KEYS
-- --------------------------------------------------------
ALTER TABLE products
  ADD CONSTRAINT products_ibfk_1
  FOREIGN KEY (store_id) REFERENCES stores (id)
  ON DELETE CASCADE;

ALTER TABLE stores
  ADD CONSTRAINT stores_ibfk_1
  FOREIGN KEY (owner_id) REFERENCES owners (id)
  ON DELETE CASCADE;

ALTER TABLE struck_receipt
  ADD CONSTRAINT struck_receipt_ibfk_1
  FOREIGN KEY (store_id) REFERENCES stores (id)
  ON DELETE CASCADE;

ALTER TABLE subscriptions
  ADD CONSTRAINT subscriptions_ibfk_1
  FOREIGN KEY (owner_id) REFERENCES owners (id)
  ON DELETE CASCADE;

ALTER TABLE transactions
  ADD CONSTRAINT transactions_ibfk_1
  FOREIGN KEY (store_id) REFERENCES stores (id)
  ON DELETE SET NULL,
  ADD CONSTRAINT transactions_ibfk_2
  FOREIGN KEY (user_id) REFERENCES users (id)
  ON DELETE SET NULL;

ALTER TABLE transaction_items
  ADD CONSTRAINT transaction_items_ibfk_1
  FOREIGN KEY (transaction_id) REFERENCES transactions (id)
  ON DELETE CASCADE,
  ADD CONSTRAINT transaction_items_ibfk_2
  FOREIGN KEY (product_id) REFERENCES products (id)
  ON DELETE CASCADE;

ALTER TABLE users
  ADD CONSTRAINT users_ibfk_1
  FOREIGN KEY (owner_id) REFERENCES owners (id)
  ON DELETE CASCADE,
  ADD CONSTRAINT users_ibfk_2
  FOREIGN KEY (store_id) REFERENCES stores (id)
  ON DELETE SET NULL;

COMMIT;
