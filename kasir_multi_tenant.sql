-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Waktu pembuatan: 16 Des 2025 pada 14.06
-- Versi server: 10.4.32-MariaDB
-- Versi PHP: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `kasir_multi_tenant`
--

-- --------------------------------------------------------
-- Struktur dari tabel `activity_logs`
CREATE TABLE IF NOT EXISTS `activity_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `store_id` int(11) DEFAULT NULL,
  `action` varchar(64) DEFAULT NULL,
  `detail` text DEFAULT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;




--
-- Struktur dari tabel `clients`
--

CREATE TABLE `clients` (
  `id` int(11) NOT NULL,
  `owner_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `db_name` varchar(100) DEFAULT NULL,
  `db_user` varchar(100) DEFAULT NULL,
  `db_password` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Struktur dari tabel `owners`
--

CREATE TABLE `owners` (
  `id` int(11) NOT NULL,
  `business_name` varchar(255) NOT NULL,
  `email` varchar(100) NOT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `password` varchar(255) NOT NULL,
  `package_id` int(11) DEFAULT 1,
  `package_expired_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `address` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `owners`
--

-- INSERT INTO `owners` (`id`, `business_name`, `email`, `phone`, `password`, `package_id`, `package_expired_at`, `created_at`) VALUES
-- (1, 'Toko Maju Jaya', 'owner1@example.com', '081234567890', '$2b$10$CX9v03fRq3lkkJK4dCZtRudMcnAMDgORooL5lMpF.isMukUBNLiou', 1, NULL, '2025-12-13 20:22:56'),
-- (2, 'Warung Sederhana', 'owner2@example.com', '081298765432', '$2b$10$CX9v03fRq3lkkJK4dCZtRudMcnAMDgORooL5lMpF.isMukUBNLiou', 1, NULL, '2025-12-13 20:22:56');

-- --------------------------------------------------------

--
-- Struktur dari tabel `products`
--

CREATE TABLE `products` (
  `id` int(11) NOT NULL,
  `store_id` int(11) NOT NULL,
  `name` varchar(200) NOT NULL,
  `sku` varchar(50) DEFAULT NULL,
  `barcode` varchar(100) DEFAULT NULL,
  `price` decimal(10,2) NOT NULL,
  `cost_price` DECIMAL(18,2) DEFAULT 0,
  `stock` int(11) DEFAULT 0,
  `category` enum('Kesehatan & Kecantikan','Rumah Tangga & Gaya Hidup','Fashion & Aksesoris','Elektronik','Bayi & Anak','Makanan & Minuman') DEFAULT NULL,
  `description` text DEFAULT NULL,
  `image_url` text DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `jenis_diskon` enum('percentage','nominal') DEFAULT NULL,
  `nilai_diskon` decimal(10,2) DEFAULT NULL,
  `diskon_bundle_min_qty` int(11) DEFAULT NULL,
  `diskon_bundle_value` decimal(10,2) DEFAULT NULL,
  `buy_qty` int(11) DEFAULT NULL,
  `free_qty` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `products`
--

-- INSERT INTO `products` (`id`, `store_id`, `name`, `sku`, `barcode`, `price`, `stock`, `category`, `description`, `image_url`, `is_active`, `created_at`, `updated_at`, `jenis_diskon`, `nilai_diskon`, `diskon_bundle_min_qty`, `diskon_bundle_value`, `buy_qty`, `free_qty`) VALUES
-- (21, 2, 'Indomie Goreng', 'IND-001', NULL, 3500.00, 100, NULL, NULL, NULL, 1, '2025-12-13 22:58:48', '2025-12-13 22:58:48', NULL, NULL, NULL, NULL, NULL, NULL),
-- (22, 2, 'Aqua 600ml', 'AQU-001', NULL, 3000.00, 50, NULL, NULL, NULL, 1, '2025-12-13 22:58:48', '2025-12-13 22:58:48', NULL, NULL, NULL, NULL, NULL, NULL),
-- (23, 2, 'Rokok Sampoerna Mild', 'ROK-001', NULL, 27000.00, 20, NULL, NULL, NULL, 1, '2025-12-13 22:58:48', '2025-12-13 22:58:48', NULL, NULL, NULL, NULL, NULL, NULL),
-- (24, 2, 'Pepsodent 100g', 'PEP-001', NULL, 8500.00, 30, NULL, NULL, NULL, 1, '2025-12-13 22:58:48', '2025-12-13 22:58:48', NULL, NULL, NULL, NULL, NULL, NULL),
-- (25, 2, 'Sunlight 200ml', 'SUN-001', NULL, 5000.00, 15, NULL, NULL, NULL, 1, '2025-12-13 22:58:48', '2025-12-13 22:58:48', NULL, NULL, NULL, NULL, NULL, NULL),
-- (26, 2, 'Buku Tulis Sidu', 'BUK-001', NULL, 4500.00, 200, NULL, NULL, NULL, 1, '2025-12-13 22:58:48', '2025-12-13 22:58:48', NULL, NULL, NULL, NULL, NULL, NULL),
-- (27, 3, 'Pulpen Pilot', 'PUL-001', NULL, 3000.00, 150, NULL, NULL, NULL, 1, '2025-12-13 22:58:48', '2025-12-13 22:58:48', NULL, NULL, NULL, NULL, NULL, NULL),
-- (28, 3, 'Penghapus Faber', 'PEN-001', NULL, 2000.00, 100, NULL, NULL, NULL, 1, '2025-12-13 22:58:48', '2025-12-13 22:58:48', NULL, NULL, NULL, NULL, NULL, NULL),
-- (29, 3, 'Kopi Kapal Api', 'KOP-001', NULL, 12000.00, 40, NULL, NULL, NULL, 1, '2025-12-13 22:58:48', '2025-12-13 22:58:48', NULL, NULL, NULL, NULL, NULL, NULL),
-- (30, 3, 'Gula Gulaku 1kg', 'GUL-001', NULL, 15000.00, 25, NULL, NULL, NULL, 1, '2025-12-13 22:58:48', '2025-12-13 22:58:48', NULL, NULL, NULL, NULL, NULL, NULL),
-- (39, 2, 'Indomie', 'IND-100', NULL, 3150.00, 100, NULL, NULL, 'http://example.com/image.jpg', 1, '2025-12-14 18:30:18', '2025-12-14 18:30:18', NULL, NULL, NULL, NULL, NULL, NULL),
-- (42, 2, 'Sunscreen SPF 50', 'SKN-001', NULL, 50000.00, 50, 'Kesehatan & Kecantikan', 'Sunscreen untuk perlindungan maksimal', 'https://example.com/sunscreen.jpg', 1, '2025-12-15 14:24:44', '2025-12-15 14:24:44', 'percentage', 10.00, NULL, NULL, NULL, NULL),
-- (43, 2, 'Pop Mie', 'POP-001', NULL, 8000.00, 200, 'Makanan & Minuman', 'Pop Mie semua rasa', 'https://example.com/popmie.jpg', 1, '2025-12-15 14:26:04', '2025-12-15 14:26:04', '', NULL, NULL, NULL, 2, 1),
-- (45, 2, 'Pop Mie Pedas', 'POP-002', NULL, 8000.00, 200, 'Makanan & Minuman', 'Pop Mie semua rasa', 'https://example.com/popmie.jpg', 1, '2025-12-15 14:30:16', '2025-12-15 14:30:16', '', NULL, NULL, NULL, 2, 1);

-- --------------------------------------------------------

--
-- Struktur dari tabel `stores`
--

CREATE TABLE `stores` (
  `id` int(11) NOT NULL,
  `type` VARCHAR(32) NOT NULL DEFAULT 'store',
  `owner_id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `business_name` varchar(150) DEFAULT NULL,
  `address` text DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `receipt_template` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp(),
  `tax_percentage` decimal(5,2) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `stores`
--

-- INSERT INTO `stores` (`id`, `owner_id`, `name`, `address`, `phone`, `receipt_template`, `created_at`, `updated_at`) VALUES
-- (2, 1, 'Toko Maju Jaya Cabang 2', 'Jl. Sudirman No. 20', '081222222222', NULL, '2025-12-13 20:22:56', '2025-12-14 05:03:18'),
-- (3, 2, 'Warung Sederhana Utama', 'Jl. Pahlawan No. 5', '081333333333', NULL, '2025-12-13 20:22:56', '2025-12-14 05:03:18'),
-- (5, 1, 'Toko Maju Jaya', 'Jl. Sudirman No. 1', '08123456789', 'default_template', '2025-12-14 16:57:24', '2025-12-14 23:57:24');

-- --------------------------------------------------------

--
-- Struktur dari tabel `struck_receipt`
--

CREATE TABLE `struck_receipt` (
  `id` int(11) NOT NULL,
  `store_id` int(11) NULL,
  `template_name` varchar(100) NOT NULL,
  `template_data` text NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `struck_receipt`
--

-- INSERT INTO `struck_receipt` (`id`, `store_id`, `template_name`, `template_data`, `created_at`, `updated_at`) VALUES
-- (2, 2, 'Default Receipt', '<html><body><h1>Receipt</h1><p>Store: {{store_name}}</p><p>Total: {{total_amount}}</p></body></html>', '2025-12-14 17:01:04', '2025-12-14 17:01:04');

-- --------------------------------------------------------

--
-- Struktur dari tabel `subscriptions`
--

CREATE TABLE `subscriptions` (
  `id` int(11) NOT NULL,
  `owner_id` int(11) NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `status` enum('Aktif','Nonaktif') NOT NULL DEFAULT 'Nonaktif',
  `plan` enum('Pro','Standard','Eksklusif') NOT NULL DEFAULT 'Standard',
  `start_date` datetime NOT NULL,
  `end_date` datetime NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Struktur dari tabel `transactions`
--

CREATE TABLE `transactions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `store_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `total_cost` decimal(10,2) NOT NULL,
  `payment_type` varchar(50) DEFAULT NULL,
  `payment_method` varchar(50) DEFAULT NULL,
  `received_amount` decimal(10,2) NOT NULL,
  `change_amount` decimal(10,2) NOT NULL,
  `customer_name` varchar(100) DEFAULT NULL,
  `customer_phone` varchar(15) DEFAULT NULL,
  `payment_status` varchar(50) DEFAULT 'pending',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `tax` DECIMAL(12,2) DEFAULT 0,
  `tax_percentage` DECIMAL(5,2) DEFAULT 0,
  `role` VARCHAR(20),
  `is_owner` BOOLEAN,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `transactions`
--
--test
-- INSERT INTO `transactions` (`id`, `store_id`, `user_id`, `total_cost`, `payment_type`, `payment_method`, `received_amount`, `change_amount`, `customer_name`, `customer_phone`, `payment_status`, `created_at`, `updated_at`) VALUES
-- (2, 2, 4, 100000.00, 'cash', 'manual', 200000.00, 100000.00, NULL, NULL, 'pending', '2025-12-15 06:11:38', '2025-12-15 06:11:38'),
-- (3, 2, 4, 100000.00, 'cash', 'manual', 200000.00, 100000.00, NULL, NULL, 'pending', '2025-12-15 06:12:07', '2025-12-15 06:12:07'),
-- (4, 2, 4, 100000.00, 'cash', 'manual', 200000.00, 100000.00, NULL, NULL, 'pending', '2025-12-15 06:13:42', '2025-12-15 06:13:42'),
-- (5, 2, 4, 100000.00, 'cash', 'manual', 200000.00, 100000.00, NULL, NULL, 'pending', '2025-12-15 06:17:40', '2025-12-15 06:17:40'),
-- (6, 2, 4, 100000.00, 'cash', 'tunai', 100000.00, 0.00, NULL, NULL, 'pending', '2025-12-15 08:53:45', '2025-12-15 08:53:45'),
-- (7, 2, 4, 100000.00, 'cash', 'tunai', 100000.00, 96500.00, NULL, NULL, 'paid', '2025-12-15 09:12:07', '2025-12-15 09:12:07');

-- --------------------------------------------------------

--
-- Struktur dari tabel `transaction_items`
--

CREATE TABLE `transaction_items` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `transaction_id` int(11) NOT NULL,
  `product_name` VARCHAR(255) DEFAULT NULL,
  `product_id` int(11) DEFAULT NULL,
  `qty` int(11) NOT NULL,
  `price` decimal(10,2) NOT NULL,
  `subtotal` decimal(10,2) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `transaction_items`
--

-- INSERT INTO `transaction_items` (`id`, `transaction_id`, `product_id`, `qty`, `price`, `subtotal`) VALUES
-- (1, 4, 22, 2, 3000.00, 6000.00),
-- (2, 5, 22, 5, 3000.00, 15000.00),
-- (3, 6, 21, 1, 100000.00, 100000.00),
-- (4, 7, 21, 1, 3500.00, 3500.00);

-- --------------------------------------------------------

--
-- Struktur dari tabel `users`
--

CREATE TABLE `users` (
  `id` int(11) NOT NULL,
  `owner_id` int(11) NOT NULL,
  `store_id` int(11) DEFAULT NULL,
  `name` varchar(100) NOT NULL,
  `email` varchar(100) DEFAULT NULL,
  `username` varchar(50) NOT NULL,
  `password` varchar(255) NOT NULL,
  `role` enum('owner','admin','cashier') DEFAULT 'cashier',
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `users`
--

-- INSERT INTO `users` (`id`, `owner_id`, `store_id`, `name`, `username`, `password`, `role`, `is_active`, `created_at`) VALUES
-- (1, 1, NULL, 'Admin Toko 1', 'admin1', '$2b$10$0JyACX3D3NJidjggqz/Ze.4Qi6gSGvUechtEYh80zWJDARoECmUFK', 'admin', 1, '2025-12-13 20:22:56'),
-- (2, 1, NULL, 'Kasir Toko 1', 'kasir1', '$2b$10$dmsdKZmlAFTBnZ0wmSXhM.i.7Bu0PPvEW1h/EK2oq28Bl2YEHSmhu', 'cashier', 1, '2025-12-13 20:22:56'),
-- (3, 1, 2, 'Admin Toko 2', 'admin2', '$2b$10$dmsdKZmlAFTBnZ0wmSXhM.i.7Bu0PPvEW1h/EK2oq28Bl2YEHSmhu', 'admin', 1, '2025-12-13 20:22:56'),
-- (4, 2, 3, 'Owner Warung', 'owner2', '$2b$10$dmsdKZmlAFTBnZ0wmSXhM.i.7Bu0PPvEW1h/EK2oq28Bl2YEHSmhu', 'owner', 1, '2025-12-13 20:22:56'),
-- (6, 2, 2, 'Kasir Toko 1', 'kasir2', '$2b$10$dmsdKZmlAFTBnZ0wmSXhM.i.7Bu0PPvEW1h/EK2oq28Bl2YEHSmhu', 'cashier', 1, '2025-12-13 20:22:56'),
-- (7, 1, 3, 'A Ming Lang', 'abyan db', '$2a$10$.1d6qwVFuli9CKxen9MEmOxY75d1e4qGpO56RwENLmVGoEOS9WxiK', 'cashier', 1, '2025-12-16 08:20:29'),
-- (9, 2, 3, 'Abyan Dzakwan B.', 'abyan', '$2a$10$yuUDa0SguXpVksWw6NkuU.axyLM4THmnVT0vv1piWJgweFXWneANC', 'cashier', 1, '2025-12-16 09:31:31'),
-- (11, 1, 2, 'Owner Warung 1', 'owner1', '$2b$10$dmsdKZmlAFTBnZ0wmSXhM.i.7Bu0PPvEW1h/EK2oq28Bl2YEHSmhu', 'owner', 1, '2025-12-13 20:22:56');

--
-- Indexes for dumped tables
--

--
-- Indeks untuk tabel `clients`
--
ALTER TABLE `clients`
  ADD PRIMARY KEY (`id`);

--
-- Indeks untuk tabel `owners`
--
ALTER TABLE `owners`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `email` (`email`);

--
-- Indeks untuk tabel `products`
--
ALTER TABLE `products`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `sku` (`sku`),
  ADD KEY `idx_store` (`store_id`),
  ADD KEY `idx_sku` (`sku`),
  ADD KEY `idx_active` (`is_active`);

--
-- Indeks untuk tabel `stores`
--
ALTER TABLE `stores`
  ADD PRIMARY KEY (`id`),
  ADD KEY `owner_id` (`owner_id`);

--
-- Indeks untuk tabel `struck_receipt`
--
ALTER TABLE `struck_receipt`
  ADD PRIMARY KEY (`id`),
  ADD KEY `store_id` (`store_id`);

--
-- Indeks untuk tabel `subscriptions`
--
ALTER TABLE `subscriptions`
  ADD PRIMARY KEY (`id`),
  ADD KEY `owner_id` (`owner_id`);

--
-- Indeks untuk tabel `transactions`
--
ALTER TABLE `transactions`
  ADD KEY `store_id` (`store_id`),
  ADD KEY `user_id` (`user_id`);

--
-- Indeks untuk tabel `transaction_items`
--
ALTER TABLE `transaction_items`
  ADD KEY `transaction_id` (`transaction_id`),
  ADD KEY `product_id` (`product_id`);

--
-- Indeks untuk tabel `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `username` (`username`),
  ADD KEY `owner_id` (`owner_id`),
  ADD KEY `store_id` (`store_id`);

--
-- AUTO_INCREMENT untuk tabel yang dibuang
--

--
-- AUTO_INCREMENT untuk tabel `clients`
--
ALTER TABLE `clients`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT untuk tabel `owners`
--
ALTER TABLE `owners`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;

--
-- AUTO_INCREMENT untuk tabel `products`
--
ALTER TABLE `products`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;

--
-- AUTO_INCREMENT untuk tabel `stores`
--
ALTER TABLE `stores`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;

--
-- AUTO_INCREMENT untuk tabel `struck_receipt`
--
ALTER TABLE `struck_receipt`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;

--
-- AUTO_INCREMENT untuk tabel `subscriptions`
--
ALTER TABLE `subscriptions`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT untuk tabel `transactions`
--
-- ALTER TABLE `transactions`
--   MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;

-- --
-- -- AUTO_INCREMENT untuk tabel `transaction_items`
-- --
-- ALTER TABLE `transaction_items`
--   MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;

--
-- AUTO_INCREMENT untuk tabel `users`
--
ALTER TABLE `users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;

--
-- Ketidakleluasaan untuk tabel pelimpahan (Dumped Tables)
--

--
-- Ketidakleluasaan untuk tabel `products`
--
ALTER TABLE `products`
  ADD CONSTRAINT `products_ibfk_1` FOREIGN KEY (`store_id`) REFERENCES `stores` (`id`) ON DELETE CASCADE;

--
-- Ketidakleluasaan untuk tabel `stores`
--
ALTER TABLE `stores`
  ADD CONSTRAINT `stores_ibfk_1` FOREIGN KEY (`owner_id`) REFERENCES `owners` (`id`) ON DELETE CASCADE;

--
-- Ketidakleluasaan untuk tabel `struck_receipt`
--
ALTER TABLE `struck_receipt`
  ADD CONSTRAINT `struck_receipt_ibfk_1` FOREIGN KEY (`store_id`) REFERENCES `stores` (`id`) ON DELETE CASCADE;

--
-- Ketidakleluasaan untuk tabel `subscriptions`
--
ALTER TABLE `subscriptions`
  ADD CONSTRAINT `subscriptions_ibfk_1` FOREIGN KEY (`owner_id`) REFERENCES `owners` (`id`) ON DELETE CASCADE;

--
-- Ketidakleluasaan untuk tabel `transactions`
--
ALTER TABLE `transactions`
  ADD CONSTRAINT `transactions_ibfk_1` FOREIGN KEY (`store_id`) REFERENCES `stores` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `transactions_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- Ketidakleluasaan untuk tabel `transaction_items`
--
ALTER TABLE `transaction_items`
  ADD CONSTRAINT `transaction_items_ibfk_1` FOREIGN KEY (`transaction_id`) REFERENCES `transactions` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `transaction_items_ibfk_2` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE;

--
-- Ketidakleluasaan untuk tabel `users`
--
ALTER TABLE `users`
  ADD CONSTRAINT `users_ibfk_1` FOREIGN KEY (`owner_id`) REFERENCES `owners` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `users_ibfk_2` FOREIGN KEY (`store_id`) REFERENCES `stores` (`id`) ON DELETE SET NULL;
COMMIT;

-- ALTER TABLE `transaction_items`
--   ADD COLUMN `product_name` VARCHAR(255) DEFAULT NULL AFTER `product_id`;


/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
