// src/config/database.js
const { Pool } = require('pg');

const useSsl =
    `${process.env.DB_SSL || process.env.DATABASE_SSL || ''}`.toLowerCase() ===
    'true';

const poolConfig = process.env.DATABASE_URL
    ? {
          connectionString: process.env.DATABASE_URL,
          ssl: useSsl ? { rejectUnauthorized: false } : false,
      }
    : {
          user: process.env.DB_USER,
          password: process.env.DB_PASSWORD,
          host: process.env.DB_HOST,
          port: process.env.DB_PORT,
          database: process.env.DB_NAME,
          ssl: useSsl ? { rejectUnauthorized: false } : false,
      };

// Create PostgreSQL connection pool
const pool = new Pool(poolConfig);

pool.on('connect', (client) => {
    client
        .query('SET search_path TO public')
        .catch((error) =>
            console.error('❌ Failed to set PostgreSQL search_path:', error.message)
        );
});

// Test database connection
const connectDB = async () => {
    try {
        const client = await pool.connect();
        console.log('✅ PostgreSQL connected successfully');
        client.release();
        return true;
    } catch (error) {
        console.error('❌ PostgreSQL connection error:', error.message);
        throw error;
    }
};

// Query helper function
const query = (text, params) => {
    return pool.query(text, params);
};

module.exports = {
    pool,
    connectDB,
    query
};
