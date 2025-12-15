const Joi = require('joi');

// Validasi untuk item transaksi
const transactionItemSchema = Joi.object({
  product_id: Joi.number().required(),
  quantity: Joi.number().integer().min(1).required(),
  price: Joi.number().min(0).required(),
  discount_type: Joi.string().valid('percentage', 'nominal', '', null).allow(null, ''),
  discount_value: Joi.number().min(0).allow(null),
  notes: Joi.string().allow('', null)
});

// Validasi untuk pembuatan transaksi baru
const createTransactionSchema = Joi.object({
  user_id: Joi.number().required(),
  total_cost: Joi.number().min(0).required(),
  payment_type: Joi.string().required(),
  payment_method: Joi.string().required(),
  received_amount: Joi.number().min(0).required(),
  change_amount: Joi.number().min(0).required(),
  items: Joi.array().items(transactionItemSchema).min(1).required()
});

// Validasi untuk update transaksi (opsional, bisa disesuaikan)
const updateTransactionSchema = Joi.object({
  total_cost: Joi.number().min(0),
  payment_type: Joi.string(),
  payment_method: Joi.string(),
  received_amount: Joi.number().min(0),
  change_amount: Joi.number().min(0),
  items: Joi.array().items(transactionItemSchema)
});

module.exports = {
  createTransactionSchema,
  updateTransactionSchema
};