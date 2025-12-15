require('dotenv').config();

// Import app yang sudah lengkap dari app.js
const app = require('./app');

const PORT = process.env.PORT || 8000;

// Start server
app.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`🌐 http://localhost:${PORT}`);
    console.log(`🔗 API Documentation: http://localhost:${PORT}/`);
    
    console.log('\n📋 Available Routes:');
    console.log('├── /api/auth/* - Authentication endpoints');
    console.log('├── /api/stores/* - Store management');
    console.log('└── / - API Documentation');
});