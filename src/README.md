# Project BetaKasir - Backend

Backend REST API untuk aplikasi kasir multi-tenant, multi-cabang, dan multi-role.  
Dibangun dengan Node.js, Express, dan MySQL.

---

## Fitur Utama

- Multi-owner, multi-cabang (store), multi-role (owner, admin, cashier)
- Manajemen produk, transaksi, dan user
- Sistem paket berlangganan (subscription)
- Otentikasi JWT
- Validasi input & error handling
- Siap untuk integrasi dengan aplikasi mobile (Flutter)

---

## Struktur Folder
src/
app.js
server.js
config/
controllers/
middleware/
models/
routes/
tests/
utils/
validations/

---

## Environment Variables

Buat file `.env` di root project:
PORT=5000
NODE_ENV=development
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=
DB_NAME=kasir_multi_tenant
JWT_SECRET=your_super_secret_jwt_key
JWT_EXPIRE=1d
BCRYPT_SALT_ROUNDS=10

---

## API Endpoints

### AUTH

#### Login
- **POST** `/api/auth/login`
  - **Body:**
    ```json
    { "username": "admin", "password": "yourpassword" }
    ```
  - **Response:**
    ```json
    { "token": "..." }
    ```

---

### USERS (Manajemen Karyawan/Admin/Kasir)

#### List Karyawan/Admin/Kasir di Store
- **GET** `/api/stores/:store_id/users`
  - **Headers:** Authorization: Bearer {token}
  - **Response:** Array of user objects (role: admin/kasir) di store tersebut

#### Tambah Karyawan/Admin/Kasir ke Store
- **POST** `/api/stores/:store_id/users`
  - **Headers:** Authorization: Bearer {token}
  - **Akses:** Owner **dan** Admin
  - **Body:**
    ```json
    {
      "name": "Nama Karyawan",
      "username": "username",
      "password": "password",
      "role": "cashier" // atau "admin"
    }
    ```
  - **owner_id** diambil otomatis dari token login.

#### Update Data Karyawan/Admin/Kasir
- **PUT** `/api/users/:id`
  - **Headers:** Authorization: Bearer {token}
  - **Body:** (fields yang ingin diupdate, misal:)
    ```json
    {
      "name": "Nama Baru",
      "username": "username_baru",
      "password": "password_baru",
      "role": "admin",
      "is_active": 1
    }
    ```
  - **Response:** 
    ```json
    { "success": true, "message": "User berhasil diupdate" }
    ```

#### Nonaktifkan/Hapus Karyawan/Admin/Kasir
- **DELETE** `/api/users/:id`
  - **Headers:** Authorization: Bearer {token}
  - **Response:** 
    ```json
    { "success": true, "message": "User berhasil dinonaktifkan" }
    ```

---

### OWNERS

#### Get Owner Info
- **GET** `/api/owners/:id`
  - **Headers:** Authorization: Bearer {token}
  - **Response:** Owner object

---

### STORES (CABANG)

#### List Stores
- **GET** `/api/stores`
  - **Headers:** Authorization: Bearer {token}
  - **Response:** Array of store objects

#### Create Store
- **POST** `/api/stores`
  - **Headers:** Authorization: Bearer {token}
  - **Body:**
    ```json
    {
      "owner_id": 1,
      "name": "Toko A",
      "address": "Alamat",
      "phone": "08123456789"
    }
    ```
  - **Response:** Store object

#### Get Store by ID
- **GET** `/api/stores/:id`
  - **Headers:** Authorization: Bearer {token}
  - **Response:** Store object

#### Update Store
- **PUT** `/api/stores/:id`
  - **Headers:** Authorization: Bearer {token}
  - **Body:** (fields to update)
  - **Response:** Updated store object

#### Delete Store
- **DELETE** `/api/stores/:id`
  - **Headers:** Authorization: Bearer {token}
  - **Response:** Success message

---

### PRODUCTS

#### List Products in Store
- **GET** `/api/stores/:store_id/products`
  - **Headers:** Authorization: Bearer {token}
  - **Response:** Array of product objects

#### Create Product
- **POST** `/api/stores/:store_id/products`
  - **Headers:** Authorization: Bearer {token}
  - **Body:**
    ```json
    {
      "name": "Indomie Goreng",
      "sku": "IND-001",
      "price": 3500,
      "stock": 100,
      "category": "Makanan & Minuman",
      "description": "Mi goreng favorit",
      "image_url": "https://...",
      "jenis_diskon": null,
      "nilai_diskon": null,
      "diskon_bundle_min_qty": null,
      "diskon_bundle_value": null,
      "buy_qty": null,
      "free_qty": null
    }
    ```
  - **Response:** Product object

#### Get Product by ID
- **GET** `/api/stores/:store_id/products/:id`
  - **Headers:** Authorization: Bearer {token}
  - **Response:** Product object

#### Update Product
- **PUT** `/api/stores/:store_id/products/:id`
  - **Headers:** Authorization: Bearer {token}
  - **Body:** (fields to update)
  - **Response:** Updated product object

#### Delete Product
- **DELETE** `/api/stores/:store_id/products/:id`
  - **Headers:** Authorization: Bearer {token}
  - **Response:** Success message

#### Cari Produk Berdasarkan Barcode
- **GET** `/api/stores/:store_id/products/barcode/:barcode`
  - **Headers:** Authorization: Bearer {token}
  - **Response jika ditemukan:**
    ```json
    {
      "success": true,
      "data": {
        "id": 1,
        "store_id": 3,
        "name": "Indomie Goreng",
        "sku": "IND-001",
        "barcode": "1234567890123",
        "price": 3500,
        "stock": 100,
        ...
      },
      "message": "Produk ditemukan"
    }
    ```
  - **Response jika tidak ditemukan:**
    ```json
    {
      "success": false,
      "message": "Produk dengan barcode ini belum terdaftar"
    }
    ```

#### Tambah Produk (dengan Barcode)
- **POST** `/api/stores/:store_id/products`
  - **Headers:** Authorization: Bearer {token}
  - **Body:**
    ```json
    {
      "name": "Nama Produk",
      "sku": "SKU001",
      "barcode": "1234567890123",
      "price": 10000,
      "stock": 10,
      "category": "Makanan & Minuman",
      "description": "Deskripsi produk",
      "image_url": "https://...",
      "jenis_diskon": null,
      "nilai_diskon": null,
      "diskon_bundle_min_qty": null,
      "diskon_bundle_value": null,
      "buy_qty": null,
      "free_qty": null
    }
    ```
  - **Response:**
    ```json
    {
      "success": true,
      "data": {
        "id": 2,
        "store_id": 3,
        "name": "Nama Produk",
        "barcode": "1234567890123",
        ...
      },
      "message": "Produk berhasil ditambah"
    }
    ```

---

### TRANSACTIONS

#### List Transactions in Store
- **GET** `/api/stores/:store_id/transactions`
  - **Headers:** Authorization: Bearer {token}
  - **Response:** Array of transaction objects

#### Create Transaction
- **POST** `/api/stores/:store_id/transactions`
  - **Headers:** Authorization: Bearer {token}
  - **Body:**
    ```json
    {
      "cashier_id": 2,
      "payment_method": "cash",
      "total": 10000,
      "received": 15000,
      "change_amount": 5000,
      "customer_name": "Budi",
      "customer_phone": "08123456789",
      "notes": "Terima kasih",
      "items": [
        {
          "product_id": 1,
          "quantity": 2,
          "price": 5000
        }
      ]
    }
    ```
  - **Response:** Transaction object

#### Get Transaction by ID
- **GET** `/api/stores/:store_id/transactions/:id`
  - **Headers:** Authorization: Bearer {token}
  - **Response:** Transaction object

#### Update Transaction
- **PUT** `/api/stores/:store_id/transactions/:id`
  - **Headers:** Authorization: Bearer {token}
  - **Body:** (fields to update)
  - **Response:** Updated transaction object

#### Delete Transaction
- **DELETE** `/api/stores/:store_id/transactions/:id`
  - **Headers:** Authorization: Bearer {token}
  - **Response:** Success message

---

### SUBSCRIPTION (PAKET)

#### Get Active Subscription
- **GET** `/api/subscription`
  - **Headers:** Authorization: Bearer {token}
  - **Response:** Subscription object

#### Create/Update Subscription
- **POST** `/api/subscription`
  - **Headers:** Authorization: Bearer {token}
  - **Body:**
    ```json
    {
      "plan": "Pro",
      "start_date": "2025-12-01",
      "end_date": "2025-12-31"
    }
    ```
  - **Response:** Subscription object

---

### Backup & Import Data (Offline/Online)

#### Backup Data (Export)
- Buka aplikasi, masuk ke menu **Pengaturan > Backup/Export**.
- Klik **Export Data**.
- File backup (format JSON) akan tersimpan di perangkat.

#### Import Data
- Buka aplikasi, masuk ke menu **Pengaturan > Import Data**.
- Pilih file backup (format JSON) yang sudah diekspor sebelumnya.
- Data akan otomatis diimpor ke aplikasi.

#### Format File Backup
- File backup berupa JSON dengan struktur:
  ```json
  {
    "products": [ ... ],
    "transactions": [ ... ],
    "transaction_items": [ ... ],
    "users": [ ... ]
  }
  ```

---

## Testing

- Jalankan test dengan:
npm test

- Contoh test ada di folder `tests/`

---

## Import Database

- Import file [kasir_multi_tenant.sql](http://_vscodecontentref_/0) ke MySQL sebelum menjalankan backend.

---

## Menjalankan Server

npm install
npm run dev

---

## Dokumentasi API Otomatis

- (Opsional) Integrasi Swagger: akses di `/docs` jika sudah di-setup.

---

## Kontribusi

Pull request dan issue sangat terbuka untuk pengembangan lebih lanjut.

---

## Lisensi

MIT

---

### REPORTS (LAPORAN)

#### Summary Laporan Keuangan
- **GET** `/api/stores/:store_id/reports/summary?start=YYYY-MM-DD&end=YYYY-MM-DD`
  - **Headers:** Authorization: Bearer {token}
  - **Query Params:**
    - `start`: tanggal mulai (format YYYY-MM-DD)
    - `end`: tanggal akhir (format YYYY-MM-DD)
  - **Response:**
    ```json
    {
      "success": true,
      "data": {
        "total_transaksi": 10,
        "total_pendapatan": 1500000,
        "margin": 0,
        "top_products": [
          { "product_id": 1, "name": "Indomie Goreng", "total_terjual": 50 }
        ],
        "stok_menipis": [
          { "id": 2, "name": "Aqua 600ml", "stock": 3 }
        ]
      }
    }
    ```

#### Laporan Produk (Top Produk & Stok Menipis)
- **GET** `/api/stores/:store_id/reports/products`
  - **Headers:** Authorization: Bearer {token}
  - **Response:**
    ```json
    {
      "success": true,
      "data": {
        "top_products": [
          { "product_id": 1, "name": "Indomie Goreng", "total_terjual": 50 }
        ],
        "stok_menipis": [
          { "id": 2, "name": "Aqua 600ml", "stock": 3 }
        ]
      }
    }
    ```

#### Laporan Kasir/Karyawan
- **GET** `/api/stores/:store_id/reports/cashiers`
  - **Headers:** Authorization: Bearer {token}
  - **Response:**
    ```json
    {
      "success": true,
      "data": [
        {
          "id": 2,
          "name": "Kasir Toko 1",
          "total_transaksi": 20,
          "total_penjualan": 500000
        }
      ]
    }
    ```

---

### INFO TOKO & SUBSCRIPTION

#### Info Toko
- **GET** `/api/stores/:store_id`
  - **Headers:** Authorization: Bearer {token}
  - **Response:**
    ```json
    {
      "success": true,
      "data": {
        "id": 1,
        "owner_id": 10,
        "name": "Toko Sukses Jaya",
        "address": "Jl. Contoh No. 123, Jakarta, Indonesia",
        "phone": "+62 812-3456-7890",
        "receipt_template": "DEFAULT_TEMPLATE_V1",
        "created_at": "2025-12-01 10:22:11",
        "updated_at": "2025-12-15 19:05:45"
      }
    }
    ```

#### Info Subscription (Plan & Billing)
- **GET** `/api/subscription/:owner_id`
  - **Headers:** Authorization: Bearer {token}
  - **Response:**
    ```json
    {
      "success": true,
      "data": {
        "id": 1,
        "owner_id": 10,
        "status": "Aktif",
        "plan": "Pro",
        "start_date": "2025-12-01",
        "end_date": "2025-12-31",
        "created_at": "2025-12-01 10:22:11"
      }
    }
    ```

### Upload Gambar Produk
POST /api/products/upload-image
Headers: Authorization: Bearer {token}
Body: form-data
image: file gambar produk
product_id: ID produk yang akan diupdate gambarnya
Response:
{
  "success": true,
  "image_url": "uploads/tenant_1/1702730000000-nama-gambar.jpg"
}
---

> **Catatan:**  
> - Semua endpoint di atas membutuhkan header Authorization: Bearer {token}.
> - Response `success: true` dan data sesuai kebutuhan frontend.
> - Untuk laporan, parameter tanggal (`start`, `end`) wajib diisi untuk filter periode.

---

**Tambahkan bagian ini ke README.md di bawah bagian API Endpoints agar dokumentasi API kamu lengkap dan mudah dipahami!**

