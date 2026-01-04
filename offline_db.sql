-- Table: activity_logs
CREATE TABLE IF NOT EXISTS activity_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER,
  store_id INTEGER,
  action TEXT,
  detail TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Table: clients
CREATE TABLE IF NOT EXISTS clients (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id INTEGER,
  user_id INTEGER,
  db_name TEXT,
  db_user TEXT,
  db_password TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Table: import_logs
CREATE TABLE IF NOT EXISTS import_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  store_id INTEGER,
  user_id INTEGER,
  filename TEXT,
  size INTEGER DEFAULT 0,
  status TEXT CHECK(status IN ('success','failed','pending')) DEFAULT 'success',
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Table: owners
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

-- Table: products
CREATE TABLE IF NOT EXISTS products (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  store_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  sku TEXT UNIQUE,
  barcode TEXT,
  price REAL NOT NULL,
  cost_price REAL DEFAULT 0,
  stock INTEGER DEFAULT 0,
  category TEXT CHECK(category IN (
    'Kesehatan & Kecantikan',
    'Rumah Tangga & Gaya Hidup',
    'Fashion & Aksesoris',
    'Elektronik',
    'Bayi & Anak',
    'Makanan & Minuman'
  )) DEFAULT NULL,
  description TEXT DEFAULT NULL,
  image_url TEXT DEFAULT NULL,
  is_active INTEGER DEFAULT 1,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  jenis_diskon TEXT CHECK(jenis_diskon IN ('percentage','nominal', 'buyxgety')) DEFAULT NULL,
  nilai_diskon REAL DEFAULT NULL,
  diskon_bundle_min_qty INTEGER DEFAULT NULL,
  diskon_bundle_value REAL DEFAULT NULL,
  buy_qty INTEGER DEFAULT NULL,
  free_qty INTEGER DEFAULT NULL,
  FOREIGN KEY(store_id) REFERENCES stores(id) ON DELETE CASCADE
);

-- Table: stores
CREATE TABLE IF NOT EXISTS stores (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL DEFAULT 'store',
  owner_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  business_name TEXT DEFAULT NULL,
  address TEXT DEFAULT NULL,
  phone TEXT DEFAULT NULL,
  receipt_template TEXT DEFAULT NULL,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  tax_percentage REAL DEFAULT 0,
  FOREIGN KEY(owner_id) REFERENCES owners(id) ON DELETE CASCADE
);

-- Table: struck_receipt
CREATE TABLE IF NOT EXISTS struck_receipt (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  store_id INTEGER,
  template_name TEXT NOT NULL,
  template_data TEXT NOT NULL,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(store_id) REFERENCES stores(id) ON DELETE CASCADE
);

-- Table: subscriptions
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

-- Table: transactions
CREATE TABLE IF NOT EXISTS transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  store_id INTEGER,
  user_id INTEGER,
  total_cost REAL NOT NULL,
  payment_type TEXT DEFAULT NULL,
  payment_method TEXT DEFAULT NULL,
  received_amount REAL NOT NULL,
  change_amount REAL NOT NULL,
  customer_name TEXT DEFAULT NULL,
  customer_phone TEXT DEFAULT NULL,
  payment_status TEXT DEFAULT 'pending',
  subtotal REAL DEFAULT 0,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  tax REAL DEFAULT 0,
  tax_percentage REAL DEFAULT 0,
  jenis_diskon TEXT CHECK(jenis_diskon IN ('percentage','nominal', 'buyxgety')) DEFAULT NULL,
  nilai_diskon REAL DEFAULT NULL,
  buy_qty INTEGER DEFAULT NULL,
  free_qty INTEGER DEFAULT NULL,
  role TEXT DEFAULT NULL,
  is_owner INTEGER DEFAULT 0,
  FOREIGN KEY(store_id) REFERENCES stores(id) ON DELETE SET NULL,
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- Table: transaction_items
CREATE TABLE IF NOT EXISTS transaction_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  transaction_id INTEGER NOT NULL,
  product_name TEXT DEFAULT NULL,
  product_id INTEGER DEFAULT NULL,
  qty INTEGER NOT NULL,
  price REAL NOT NULL,
  cost_price REAL NOT NULL DEFAULT 0,
  subtotal REAL NOT NULL,
  FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
  FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE
);

-- Table: users
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id INTEGER NOT NULL,
  store_id INTEGER DEFAULT NULL,
  name TEXT NOT NULL,
  email TEXT DEFAULT NULL,
  username TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,
  role TEXT CHECK(role IN ('owner','admin','cashier')) DEFAULT 'cashier',
  is_active INTEGER DEFAULT 1,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(owner_id) REFERENCES owners(id) ON DELETE CASCADE,
  FOREIGN KEY(store_id) REFERENCES stores(id) ON DELETE SET NULL
);

-- Table: reports_daily
CREATE TABLE IF NOT EXISTS reports_daily (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  store_id INTEGER NOT NULL,
  report_date TEXT NOT NULL,
  total_transactions INTEGER DEFAULT 0,
  total_income REAL DEFAULT 0,
  total_discount REAL DEFAULT 0,
  net_revenue REAL DEFAULT 0,
  total_hpp REAL DEFAULT 0,
  gross_profit REAL DEFAULT 0,
  operational_cost REAL DEFAULT 0,
  net_profit REAL DEFAULT 0,
  margin TEXT DEFAULT '0%',
  best_sales_day REAL DEFAULT 0,
  lowest_sales_day REAL DEFAULT 0,
  avg_daily REAL DEFAULT 0,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(store_id) REFERENCES stores(id)
);