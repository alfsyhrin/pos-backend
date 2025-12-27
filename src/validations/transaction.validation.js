const Joi = require('joi');

const transactionItemSchema = Joi.object({
  product_id: Joi.number().required(),
  quantity: Joi.number().integer().min(1).required(),
  discount_type: Joi.string()
    .valid('percentage', 'nominal')
    .allow(null),
  discount_value: Joi.number().min(0).allow(null),
  notes: Joi.string().allow('', null)
});

const createTransactionSchema = Joi.object({
  user_id: Joi.number().required(),
  payment_type: Joi.string().required(),
  payment_method: Joi.string().required(),
  received_amount: Joi.number().min(0).required(),

  // ⛔ JANGAN DIVALIDASI
  // total_cost
  // change_amount

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
