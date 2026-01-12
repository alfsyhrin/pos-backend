const Joi = require('joi');

const transactionItemSchema = Joi.object({
  product_id: Joi.number().required(),
  quantity: Joi.number().integer().min(1).required(),
  discount_type: Joi.string()
    .valid('percentage', 'nominal', 'buyxgety', 'bundle')
    .allow(null),
  discount_value: Joi.number().min(0).allow(null),
  buy_qty: Joi.number().integer().min(1).allow(null),
  free_qty: Joi.number().integer().min(1).allow(null),
  // Bundle fields (tambahkan agar diterima backend)
  bundleQty: Joi.number().integer().min(1).allow(null),
  bundleTotalPrice: Joi.number().min(0).allow(null),
  diskon_bundle_min_qty: Joi.number().integer().min(1).allow(null),      // ⬅️ Tambahkan ini
  diskon_bundle_value: Joi.number().min(0).allow(null),                 // ⬅️ Tambahkan ini
  notes: Joi.string().allow('', null)
});

const createTransactionSchema = Joi.object({
  payment_type: Joi.string().required(),
  payment_method: Joi.string().required(),
  received_amount: Joi.number().min(0).required(),
  tax_percentage: Joi.number().min(0).max(100).allow(null),

  discount_type: Joi.string().valid('percentage', 'nominal', 'buyxgety', 'bundle').allow(null), // ⬅️ Tambahkan 'bundle'
  discount_value: Joi.number().min(0).allow(null),
  buy_qty: Joi.number().integer().min(1).allow(null),
  free_qty: Joi.number().integer().min(1).allow(null),

  items: Joi.array()
    .items(transactionItemSchema)
    .min(1)
    .required()
    .custom((value, helpers) => {
      const ids = value.map(i => i.product_id);
      if (ids.length !== new Set(ids).size) {
        return helpers.message('Duplicate product_id in items');
      }
      return value;
    })
});

module.exports = {
  createTransactionSchema
};
