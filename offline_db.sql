-- Tabel owners
CREATE TABLE owners (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  business_name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  phone TEXT,
  password TEXT NOT NULL,
  package_id INTEGER DEFAULT 1,
  package_expired_at TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Tabel stores
CREATE TABLE stores (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  receipt_template TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Tabel users
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id INTEGER NOT NULL,
  store_id INTEGER,
  name TEXT NOT NULL,
  username TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,
  role TEXT CHECK(role IN ('owner','admin','cashier')) DEFAULT 'cashier',
  is_active INTEGER DEFAULT 1,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Tabel products
CREATE TABLE products (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  store_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  sku TEXT UNIQUE,
  price REAL NOT NULL,
  stock INTEGER DEFAULT 0,
  image_url TEXT,
  is_active INTEGER DEFAULT 1,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  jenis_diskon TEXT CHECK(jenis_diskon IN ('percentage','nominal')) DEFAULT NULL,
  nilai_diskon REAL DEFAULT NULL,
  diskon_bundle_min_qty INTEGER DEFAULT NULL,
  diskon_bundle_value REAL DEFAULT NULL,
  buy_qty INTEGER DEFAULT NULL,
  free_qty INTEGER DEFAULT NULL,
  category TEXT DEFAULT NULL,
  description TEXT DEFAULT NULL,
  barcode TEXT DEFAULT NULL
);

-- Tabel transactions
CREATE TABLE transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  id_short TEXT NOT NULL,
  id_full TEXT NOT NULL UNIQUE,
  store_id INTEGER NOT NULL,
  cashier_id INTEGER NOT NULL,
  payment_method TEXT NOT NULL,
  total INTEGER NOT NULL,
  received INTEGER NOT NULL,
  change_amount INTEGER NOT NULL,
  customer_name TEXT,
  customer_phone TEXT,
  notes TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  is_active INTEGER DEFAULT 1,
  payment_status TEXT DEFAULT 'pending'
);

-- Tabel transaction_items
CREATE TABLE transaction_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  transaction_id INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  product_name TEXT NOT NULL,
  sku TEXT,
  price INTEGER NOT NULL,
  quantity INTEGER NOT NULL,
  line_total INTEGER NOT NULL
);

-- Tabel struck_receipt
CREATE TABLE struck_receipt (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  store_id INTEGER NOT NULL,
  template_name TEXT NOT NULL,
  template_data TEXT NOT NULL,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE subscriptions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  status TEXT CHECK(status IN ('Aktif','Nonaktif')) NOT NULL DEFAULT 'Nonaktif',
  plan TEXT CHECK(plan IN ('Pro','Standard','Eksklusif')) NOT NULL,
  start_date TEXT NOT NULL,
  end_date TEXT NOT NULL,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS clients (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id INTEGER,
  db_name TEXT,
  db_user TEXT,
  db_password TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);