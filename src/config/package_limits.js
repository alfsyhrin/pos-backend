const fs = require('fs');
const path = require('path');

const DEFAULT_LIMITS = {
  Standard: {
    product_limit: 100,
    user_limit: 1,
    image_limit: 0,
    role_limits: { owner: 1, admin: 0, cashier: 0, user: 0 }
  },
  Pro: {
    product_limit: 1000,
    user_limit: 6,
    image_limit: 100,
    role_limits: { owner: 1, admin: 1, cashier: 4, user: 6 }
  },
  Eksklusif: {
    product_limit: 10000,
    user_limit: 11,
    image_limit: 10000,
    role_limits: { owner: 1, admin: 2, cashier: 8, user: 11 }
  }
};

let customLimits = {};
try {
  const file = path.join(__dirname, 'custom_package_limits.json');
  if (fs.existsSync(file)) {
    customLimits = JSON.parse(fs.readFileSync(file, 'utf8'));
  }
} catch (e) {
  customLimits = {};
}

function getPackageLimit(plan, key) {
  if (customLimits[plan] && customLimits[plan][key] !== undefined) {
    return customLimits[plan][key];
  }
  return DEFAULT_LIMITS[plan][key];
}

function getRoleLimit(plan, role) {
  if (customLimits[plan] && customLimits[plan].role_limits && customLimits[plan].role_limits[role] !== undefined) {
    return customLimits[plan].role_limits[role];
  }
  return DEFAULT_LIMITS[plan].role_limits[role];
}

module.exports = { getPackageLimit, getRoleLimit };