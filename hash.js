const bcrypt = require('bcryptjs');

const password = 'password123';

bcrypt.hash(password, 10).then(hash => {
  console.log('HASH:', hash);
});
