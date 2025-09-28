const { Pool } = require('pg');
const logger = require('../utils/logger');

// Database configuration
const dbConfig = {
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME || 'member_management',
    user: process.env.DB_USER || 'memberapp_user',
    password: process.env.DB_PASSWORD,
    max: 20, // maximum number of clients in the pool
    idleTimeoutMillis: 30000, // how long a client is allowed to remain idle
    connectionTimeoutMillis: 2000, // how long to wait when connecting a client
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
};

// Create connection pool
const pool = new Pool(dbConfig);

// Handle pool errors
pool.on('error', (err, client) => {
    logger.error('Unexpected error on idle client', err);
    process.exit(-1);
});

// Test database connection
pool.connect((err, client, release) => {
    if (err) {
        logger.error('Error acquiring client', err.stack);
        return;
    }
    
    client.query('SELECT NOW()', (err, result) => {
        release();
        if (err) {
            logger.error('Error executing query', err.stack);
            return;
        }
        logger.info('Database connected successfully');
    });
});

// Helper function to execute queries
const query = async (text, params) => {
    const start = Date.now();
    try {
        const res = await pool.query(text, params);
        const duration = Date.now() - start;
        logger.debug('Executed query', { text, duration, rows: res.rowCount });
        return res;
    } catch (error) {
        logger.error('Database query error', { text, error: error.message });
        throw error;
    }
};

// Helper function to get a client from the pool
const getClient = async () => {
    return await pool.connect();
};

// Helper function to execute queries within a transaction
const transaction = async (callback) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        const result = await callback(client);
        await client.query('COMMIT');
        return result;
    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }
};

// Helper function to set user context for RLS
const setUserContext = async (client, userId) => {
    if (userId) {
        await client.query('SELECT set_config($1, $2, true)', ['app.current_user_id', userId]);
    }
};

module.exports = {
    pool,
    query,
    getClient,
    transaction,
    setUserContext
};