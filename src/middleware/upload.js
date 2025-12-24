const multer = require('multer');
const path = require('path');
const fs = require('fs');

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    let owner_id = req.body.owner_id || (req.user && req.user.owner_id);
    // Fallback: coba ambil dari store_id jika owner_id tidak ada
    if (!owner_id && req.params && req.params.store_id) owner_id = req.params.store_id;
    if (!owner_id) owner_id = 'unknown';
    const dir = path.join(__dirname, '../../uploads', `tenant_${owner_id}`);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: function (req, file, cb) {
    cb(null, Date.now() + '-' + file.originalname);
  }
});

const upload = multer({ storage });
module.exports = upload;