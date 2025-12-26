-- Tabel owners
CREATE TABLE IF NOT EXISTS owners (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  business_name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  phone TEXT,
  password TEXT NOT NULL,
  package_id INTEGER DEFAULT 1,
  package_expired_at TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  address TEXT
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
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  tax_percentage REAL DEFAULT 0,
  FOREIGN KEY(owner_id) REFERENCES owners(id) ON DELETE CASCADE
);

-- Tabel users
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id INTEGER NOT NULL,
  store_id INTEGER,
  name TEXT NOT NULL,
  email TEXT,
  username TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,
  role TEXT CHECK(role IN ('owner','admin','cashier')) DEFAULT 'cashier',
  is_active INTEGER DEFAULT 1,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(owner_id) REFERENCES owners(id) ON DELETE CASCADE,
  FOREIGN KEY(store_id) REFERENCES stores(id) ON DELETE SET NULL
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
  FOREIGN KEY(store_id) REFERENCES stores(id) ON DELETE CASCADE
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
  tax REAL DEFAULT 0,
  tax_percentage REAL DEFAULT 0,
  role TEXT,
  is_owner INTEGER DEFAULT 0,
  FOREIGN KEY(store_id) REFERENCES stores(id),
  FOREIGN KEY(user_id) REFERENCES users(id)
);

-- Tabel transaction_items
CREATE TABLE IF NOT EXISTS transaction_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  transaction_id INTEGER NOT NULL,
  product_id INTEGER,
  product_name TEXT,         -- <--- Tambahkan baris ini
  qty INTEGER NOT NULL,
  price REAL NOT NULL,
  subtotal REAL NOT NULL,
  FOREIGN KEY(transaction_id) REFERENCES transactions(id),
  FOREIGN KEY(product_id) REFERENCES products(id)
);

-- Tabel struck_receipt
CREATE TABLE IF NOT EXISTS struck_receipt (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  store_id INTEGER NOT NULL,
  template_name TEXT NOT NULL,
  template_data TEXT NOT NULL,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(store_id) REFERENCES stores(id) ON DELETE CASCADE
);

-- Tabel subscriptions
CREATE TABLE IF NOT EXISTS subscriptions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id INTEGER NOT NULL,
  user_id INTEGER,
  status TEXT CHECK(status IN ('Aktif','Nonaktif')) NOT NULL DEFAULT 'Nonaktif',
  plan TEXT CHECK(plan IN ('Pro','Standard','Eksklusif')) NOT NULL DEFAULT 'Standard',
  start_date TEXT NOT NULL,
  end_date TEXT NOT NULL,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(owner_id) REFERENCES owners(id) ON DELETE CASCADE
);

-- Tabel clients
CREATE TABLE IF NOT EXISTS clients (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id INTEGER,
  user_id INTEGER,
  db_name TEXT,
  db_user TEXT,
  db_password TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Tabel activity_logs
CREATE TABLE IF NOT EXISTS activity_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER,
  store_id INTEGER,
  action TEXT,
  detail TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);