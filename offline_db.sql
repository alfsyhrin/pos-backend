-- Tabel owners
CREATE TABLE IF NOT EXISTS owners (
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
CREATE TABLE IF NOT EXISTS stores (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT DEFAULT 'store',
  owner_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  receipt_template TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Tabel users
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id INTEGER NOT NULL,
  store_id INTEGER,
  name TEXT NOT NULL,
  username TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,
  role TEXT CHECK(role IN ('owner','admin','cashier')) DEFAULT 'cashier',
  is_active INTEGER DEFAULT 1,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  is_synced INTEGER DEFAULT 0
);

-- Tabel products
CREATE TABLE IF NOT EXISTS products (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  store_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  sku TEXT UNIQUE,
  barcode TEXT,
  price REAL NOT NULL,
  cost_price REAL DEFAULT 0,
  stock INTEGER DEFAULT 0,
  category TEXT DEFAULT NULL,
  description TEXT DEFAULT NULL,
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
  is_synced INTEGER DEFAULT 0
);

-- Tabel transactions
CREATE TABLE IF NOT EXISTS transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  store_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  total_cost REAL NOT NULL,
  payment_type TEXT,
  payment_method TEXT,
  received_amount REAL NOT NULL,
  change_amount REAL NOT NULL,
  customer_name TEXT,
  customer_phone TEXT,
  payment_status TEXT DEFAULT 'pending',
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  is_synced INTEGER DEFAULT 0
);

-- Tabel transaction_items
CREATE TABLE IF NOT EXISTS transaction_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  transaction_id INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  qty INTEGER NOT NULL,
  price REAL NOT NULL,
  subtotal REAL NOT NULL,
  is_synced INTEGER DEFAULT 0
);

-- Tabel struck_receipt
CREATE TABLE IF NOT EXISTS struck_receipt (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  store_id INTEGER NOT NULL,
  template_name TEXT NOT NULL,
  template_data TEXT NOT NULL,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Tabel subscriptions
CREATE TABLE IF NOT EXISTS subscriptions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id INTEGER NOT NULL,
  status TEXT CHECK(status IN ('Aktif','Nonaktif')) NOT NULL DEFAULT 'Nonaktif',
  plan TEXT CHECK(plan IN ('Pro','Standard','Eksklusif')) NOT NULL DEFAULT 'Standard',
  start_date TEXT NOT NULL,
  end_date TEXT NOT NULL,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Tabel clients
CREATE TABLE IF NOT EXISTS clients (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id INTEGER,
  db_name TEXT,
  db_user TEXT,
  db_password TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);