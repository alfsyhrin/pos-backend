const Joi = require('joi');

// Validasi untuk item transaksi
const transactionItemSchema = Joi.object({
  product_id: Joi.number().required(),
  quantity: Joi.number().integer().min(1).required(),
  price: Joi.number().min(0).required(), // <-- INI YANG WAJIB, PADAHAL BACKEND SUDAH AMBIL DARI DATABASE
  discount_type: Joi.string().valid('percentage', 'nominal', '', null).allow(null, ''),
  discount_value: Joi.number().min(0).allow(null),
  notes: Joi.string().allow('', null)
});

// Validasi untuk pembuatan transaksi baru
const createTransactionSchema = Joi.object({
  user_id: Joi.number().required(),
  // total_cost: Joi.number().min(0).required(), // <-- HAPUS atau jadikan opsional
  payment_type: Joi.string().required(),
  payment_method: Joi.string().required(),
  received_amount: Joi.number().min(0).required(),
  change_amount: Joi.number().min(0).required(),
  items: Joi.array().items(transactionItemSchema).min(1).required()
    .custom((value, helpers) => {
      const ids = value.map(i => i.product_id);
      const hasDuplicate = ids.length !== new Set(ids).size;
      if (hasDuplicate) {
        return helpers.error('any.invalid', { message: 'Duplicate product_id in items' });
      }
      return value;
    }, 'No duplicate product_id in items')
});

// Validasi untuk update transaksi (opsional, bisa disesuaikan)
const updateTransactionSchema = Joi.object({
  total_cost: Joi.number().min(0).optional(),
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