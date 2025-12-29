const jwt = require('jsonwebtoken');

const authMiddleware = (roles = []) => {
    return async (req, res, next) => {
        try {
            // 1. Get token from header
            const authHeader = req.headers.authorization;
            if (!authHeader || !authHeader.startsWith('Bearer ')) {
                return res.status(401).json({
                    success: false,
                    message: 'Token tidak ditemukan'
                });
            }

            const token = authHeader.split(' ')[1];

            // 2. Verify token
            const decoded = jwt.verify(token, process.env.JWT_SECRET);

            // 3. Attach user to request
            req.user = {
                id: decoded.id,
                owner_id: decoded.owner_id,
                store_id: decoded.store_id,
                role: decoded.role,
                username: decoded.username,
                db_name: decoded.db_name,
                plan: decoded.plan, // <-- tambahkan ini!
                email: decoded.email
            };

            // 4. Check role authorization (if roles array is provided)
            if (roles.length > 0 && !roles.includes(req.user.role)) {
                return res.status(403).json({
                    success: false,
                    message: 'Akses ditolak. Role tidak sesuai.'
                });
            }

            next();
        } catch (error) {
            if (error.name === 'TokenExpiredError') {
                return res.status(401).json({
                    success: false,
                    message: 'Token telah kadaluarsa'
                });
            }
            
            return res.status(401).json({
                success: false,
                message: 'Token tidak valid'
            });
        }
    };
};

module.exports = authMiddleware;