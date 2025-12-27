const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const pool = require('../config/db');
const UserModel = require('../models/user.model');

const JWT_SECRET = process.env.JWT_SECRET || 'secret';

module.exports = {
  // ================= LOGIN =================
  async login(req, res) {
    try {
      const { username, email, password } = req.body;

      let user = null;

      // Owner login pakai email
      if (email) {
        user = await UserModel.findOwnerByEmail(email);
      }
      // Admin / Kasir login pakai username
      else if (username) {
        const conn = await pool.getConnection();
        user = await UserModel.findByUsername(conn, username);
        conn.release();
      }

      if (!user) {
        return res.status(401).json({
          success: false,
          message: 'Username / Email tidak ditemukan'
        });
      }

      const isMatch = await bcrypt.compare(password, user.password);
      if (!isMatch) {
        return res.status(401).json({
          success: false,
          message: 'Password salah'
        });
      }

      const token = jwt.sign(
        {
          id: user.id,
          owner_id: user.owner_id,
          store_id: user.store_id,
          role: user.role
        },
        JWT_SECRET,
        { expiresIn: '7d' }
      );

      res.json({
        success: true,
        token
      });

    } catch (err) {
      console.error(err);
      res.status(500).json({ success: false, message: 'Login error' });
    }
  },

  // ================= PROFILE =================
  async getProfile(req, res) {
    res.json({
      success: true,
      user: req.user
    });
  },

  // ================= TEST =================
  async testProtected(req, res) {
    res.json({
      success: true,
      message: 'Token valid',
      user: req.user
    });
  },

  // ================= LOGOUT =================
  async logout(req, res) {
    res.json({
      success: true,
      message: 'Logout berhasil'
    });
  }
};
