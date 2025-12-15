-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Waktu pembuatan: 15 Des 2025 pada 06.32
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
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `owners`
--

INSERT INTO `owners` (`id`, `business_name`, `email`, `phone`, `password`, `package_id`, `package_expired_at`, `created_at`) VALUES
(1, 'Toko Maju Jaya', 'owner1@example.com', '081234567890', '$2b$10$CX9v03fRq3lkkJK4dCZtRudMcnAMDgORooL5lMpF.isMukUBNLiou', 1, NULL, '2025-12-13 20:22:56'),
(2, 'Warung Sederhana', 'owner2@example.com', '081298765432', '$2b$10$CX9v03fRq3lkkJK4dCZtRudMcnAMDgORooL5lMpF.isMukUBNLiou', 1, NULL, '2025-12-13 20:22:56');

-- --------------------------------------------------------

--
-- Struktur dari tabel `products`
--

CREATE TABLE `products` (
  `id` int(11) NOT NULL,
  `store_id` int(11) NOT NULL,
  `name` varchar(200) NOT NULL,
  `sku` varchar(50) DEFAULT NULL,
  `price` decimal(10,2) NOT NULL,
  `stock` int(11) DEFAULT 0,
  `image_url` text DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `jenis_diskon` enum('percentage','nominal') DEFAULT NULL,
  `nilai_diskon` decimal(10,2) DEFAULT NULL,
  `diskon_bundle_min_qty` int(11) DEFAULT NULL,
  `diskon_bundle_value` decimal(10,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `products`
--

INSERT INTO `products` (`id`, `store_id`, `name`, `sku`, `price`, `stock`, `image_url`, `is_active`, `created_at`, `updated_at`, `jenis_diskon`, `nilai_diskon`, `diskon_bundle_min_qty`, `diskon_bundle_value`) VALUES
(21, 2, 'Indomie Goreng', 'IND-001', 3500.00, 100, NULL, 1, '2025-12-13 22:58:48', '2025-12-13 22:58:48', NULL, NULL, NULL, NULL),
(22, 2, 'Aqua 600ml', 'AQU-001', 3000.00, 50, NULL, 1, '2025-12-13 22:58:48', '2025-12-13 22:58:48', NULL, NULL, NULL, NULL),
(23, 2, 'Rokok Sampoerna Mild', 'ROK-001', 27000.00, 20, NULL, 1, '2025-12-13 22:58:48', '2025-12-13 22:58:48', NULL, NULL, NULL, NULL),
(24, 2, 'Pepsodent 100g', 'PEP-001', 8500.00, 30, NULL, 1, '2025-12-13 22:58:48', '2025-12-13 22:58:48', NULL, NULL, NULL, NULL),
(25, 2, 'Sunlight 200ml', 'SUN-001', 5000.00, 15, NULL, 1, '2025-12-13 22:58:48', '2025-12-13 22:58:48', NULL, NULL, NULL, NULL),
(26, 2, 'Buku Tulis Sidu', 'BUK-001', 4500.00, 200, NULL, 1, '2025-12-13 22:58:48', '2025-12-13 22:58:48', NULL, NULL, NULL, NULL),
(27, 3, 'Pulpen Pilot', 'PUL-001', 3000.00, 150, NULL, 1, '2025-12-13 22:58:48', '2025-12-13 22:58:48', NULL, NULL, NULL, NULL),
(28, 3, 'Penghapus Faber', 'PEN-001', 2000.00, 100, NULL, 1, '2025-12-13 22:58:48', '2025-12-13 22:58:48', NULL, NULL, NULL, NULL),
(29, 3, 'Kopi Kapal Api', 'KOP-001', 12000.00, 40, NULL, 1, '2025-12-13 22:58:48', '2025-12-13 22:58:48', NULL, NULL, NULL, NULL),
(30, 3, 'Gula Gulaku 1kg', 'GUL-001', 15000.00, 25, NULL, 1, '2025-12-13 22:58:48', '2025-12-13 22:58:48', NULL, NULL, NULL, NULL),
(39, 2, 'Indomie', 'IND-100', 3150.00, 100, 'http://example.com/image.jpg', 1, '2025-12-14 18:30:18', '2025-12-14 18:30:18', NULL, NULL, NULL, NULL);

-- --------------------------------------------------------

--
-- Struktur dari tabel `stores`
--

CREATE TABLE `stores` (
  `id` int(11) NOT NULL,
  `owner_id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `address` text DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `receipt_template` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `stores`
--

INSERT INTO `stores` (`id`, `owner_id`, `name`, `address`, `phone`, `receipt_template`, `created_at`, `updated_at`) VALUES
(2, 1, 'Toko Maju Jaya Cabang 2', 'Jl. Sudirman No. 20', '081222222222', NULL, '2025-12-13 20:22:56', '2025-12-14 05:03:18'),
(3, 2, 'Warung Sederhana Utama', 'Jl. Pahlawan No. 5', '081333333333', NULL, '2025-12-13 20:22:56', '2025-12-14 05:03:18'),
(5, 1, 'Toko Maju Jaya', 'Jl. Sudirman No. 1', '08123456789', 'default_template', '2025-12-14 16:57:24', '2025-12-14 23:57:24');

-- --------------------------------------------------------

--
-- Struktur dari tabel `struck_receipt`
--

CREATE TABLE `struck_receipt` (
  `id` int(11) NOT NULL,
  `store_id` int(11) NOT NULL,
  `template_name` varchar(100) NOT NULL,
  `template_data` text NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `struck_receipt`
--

INSERT INTO `struck_receipt` (`id`, `store_id`, `template_name`, `template_data`, `created_at`, `updated_at`) VALUES
(2, 2, 'Default Receipt', '<html><body><h1>Receipt</h1><p>Store: {{store_name}}</p><p>Total: {{total_amount}}</p></body></html>', '2025-12-14 17:01:04', '2025-12-14 17:01:04');

-- --------------------------------------------------------

--
-- Struktur dari tabel `transactions`
--

CREATE TABLE `transactions` (
  `id` int(11) NOT NULL,
  `id_short` varchar(20) NOT NULL,
  `id_full` varchar(50) NOT NULL,
  `store_id` int(11) NOT NULL,
  `cashier_id` int(11) NOT NULL,
  `payment_method` varchar(20) NOT NULL,
  `total` int(11) NOT NULL,
  `received` int(11) NOT NULL,
  `change_amount` int(11) NOT NULL,
  `customer_name` varchar(100) DEFAULT NULL,
  `customer_phone` varchar(20) DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `is_active` tinyint(1) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Struktur dari tabel `transaction_items`
--

CREATE TABLE `transaction_items` (
  `id` int(11) NOT NULL,
  `transaction_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `product_name` varchar(100) NOT NULL,
  `sku` varchar(50) DEFAULT NULL,
  `price` int(11) NOT NULL,
  `quantity` int(11) NOT NULL,
  `line_total` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Struktur dari tabel `users`
--

CREATE TABLE `users` (
  `id` int(11) NOT NULL,
  `owner_id` int(11) NOT NULL,
  `store_id` int(11) DEFAULT NULL,
  `name` varchar(100) NOT NULL,
  `username` varchar(50) NOT NULL,
  `password` varchar(255) NOT NULL,
  `role` enum('owner','admin','cashier') DEFAULT 'cashier',
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `users`
--

INSERT INTO `users` (`id`, `owner_id`, `store_id`, `name`, `username`, `password`, `role`, `is_active`, `created_at`) VALUES
(1, 1, NULL, 'Admin Toko 1', 'admin1', '$2b$10$0JyACX3D3NJidjggqz/Ze.4Qi6gSGvUechtEYh80zWJDARoECmUFK', 'admin', 1, '2025-12-13 20:22:56'),
(2, 1, NULL, 'Kasir Toko 1', 'kasir1', '$2b$10$dmsdKZmlAFTBnZ0wmSXhM.i.7Bu0PPvEW1h/EK2oq28Bl2YEHSmhu', 'cashier', 1, '2025-12-13 20:22:56'),
(3, 1, 2, 'Admin Toko 2', 'admin2', '$2b$10$dmsdKZmlAFTBnZ0wmSXhM.i.7Bu0PPvEW1h/EK2oq28Bl2YEHSmhu', 'admin', 1, '2025-12-13 20:22:56'),
(4, 2, 3, 'Owner Warung', 'owner2', '$2b$10$dmsdKZmlAFTBnZ0wmSXhM.i.7Bu0PPvEW1h/EK2oq28Bl2YEHSmhu', 'owner', 1, '2025-12-13 20:22:56'),
(6, 2, 2, 'Kasir Toko 1', 'kasir2', '$2b$10$dmsdKZmlAFTBnZ0wmSXhM.i.7Bu0PPvEW1h/EK2oq28Bl2YEHSmhu', 'cashier', 1, '2025-12-13 20:22:56');

--
-- Indexes for dumped tables
--

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
-- Indeks untuk tabel `transactions`
--
ALTER TABLE `transactions`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `id_full` (`id_full`),
  ADD KEY `store_id` (`store_id`),
  ADD KEY `cashier_id` (`cashier_id`);

--
-- Indeks untuk tabel `transaction_items`
--
ALTER TABLE `transaction_items`
  ADD PRIMARY KEY (`id`),
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
-- AUTO_INCREMENT untuk tabel `owners`
--
ALTER TABLE `owners`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT untuk tabel `products`
--
ALTER TABLE `products`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=40;

--
-- AUTO_INCREMENT untuk tabel `stores`
--
ALTER TABLE `stores`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT untuk tabel `struck_receipt`
--
ALTER TABLE `struck_receipt`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT untuk tabel `transactions`
--
ALTER TABLE `transactions`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT untuk tabel `transaction_items`
--
ALTER TABLE `transaction_items`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT untuk tabel `users`
--
ALTER TABLE `users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

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
-- Ketidakleluasaan untuk tabel `transactions`
--
ALTER TABLE `transactions`
  ADD CONSTRAINT `transactions_ibfk_1` FOREIGN KEY (`store_id`) REFERENCES `stores` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `transactions_ibfk_2` FOREIGN KEY (`cashier_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

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

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
