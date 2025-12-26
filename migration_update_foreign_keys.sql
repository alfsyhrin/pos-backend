-- Migration script to update foreign key constraints for more flexible relationships
-- Run this on your existing database to apply the changes

-- Update transactions table foreign keys
ALTER TABLE `transactions`
  DROP FOREIGN KEY `transactions_ibfk_1`,
  DROP FOREIGN KEY `transactions_ibfk_2`;

ALTER TABLE `transactions`
  ADD CONSTRAINT `transactions_ibfk_1` FOREIGN KEY (`store_id`) REFERENCES `stores` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `transactions_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL;

-- Update transaction_items table foreign keys
ALTER TABLE `transaction_items`
  DROP FOREIGN KEY `transaction_items_ibfk_1`,
  DROP FOREIGN KEY `transaction_items_ibfk_2`;

ALTER TABLE `transaction_items`
  ADD CONSTRAINT `transaction_items_ibfk_1` FOREIGN KEY (`transaction_id`) REFERENCES `transactions` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `transaction_items_ibfk_2` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE SET NULL;
