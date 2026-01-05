const bcrypt = require('bcryptjs');

const password = 'Dflowers27';

bcrypt.hash(password, 10).then(hash => {
  console.log('HASH:', hash);
});
