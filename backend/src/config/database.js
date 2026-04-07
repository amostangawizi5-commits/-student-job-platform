// src/config/database.js
const { Pool } = require('pg');

const databaseUrl = `${process.env.DATABASE_URL || ''}`;
const sslRequestedViaEnv =
    `${process.env.DB_SSL || process.env.DATABASE_SSL || ''}`.toLowerCase() ===
    'true';
const sslRequestedViaUrl = /(?:^|[?&])ssl(?:mode)?=(?:require|true)/i.test(databaseUrl);
const useSsl = sslRequestedViaEnv || sslRequestedViaUrl;

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

const tableExists = async (tableName) => {
    const result = await pool.query('SELECT to_regclass($1) AS table_name', [
        `public.${tableName}`
    ]);

    return Boolean(result.rows[0]?.table_name);
};

const ensureApplicationWorkflowSchema = async () => {
    if (!(await tableExists('applications'))) {
        console.warn(
            'Skipping application workflow schema update because table "applications" does not exist yet.'
        );
        return;
    }

    await pool.query(`
        ALTER TABLE applications
        ADD COLUMN IF NOT EXISTS supportive_document_url TEXT,
        ADD COLUMN IF NOT EXISTS supportive_document_name TEXT,
        ADD COLUMN IF NOT EXISTS supportive_document_verified BOOLEAN,
        ADD COLUMN IF NOT EXISTS supportive_document_verification_notes TEXT,
        ADD COLUMN IF NOT EXISTS supportive_document_reviewed_at TIMESTAMP,
        ADD COLUMN IF NOT EXISTS response_letter_url TEXT,
        ADD COLUMN IF NOT EXISTS response_letter_name TEXT,
        ADD COLUMN IF NOT EXISTS response_letter_sent_at TIMESTAMP
    `);
};

const ensureCompanyProfileSchema = async () => {
    if (!(await tableExists('companies'))) {
        console.warn(
            'Skipping company profile schema update because table "companies" does not exist yet.'
        );
        return;
    }

    await pool.query(`
        ALTER TABLE companies
        ADD COLUMN IF NOT EXISTS website_url TEXT,
        ADD COLUMN IF NOT EXISTS logo_url TEXT,
        ADD COLUMN IF NOT EXISTS stamp_url TEXT,
        ADD COLUMN IF NOT EXISTS signature_url TEXT
    `);
};

const ensureUserAuthVersionSchema = async () => {
    if (!(await tableExists('users'))) {
        console.warn(
            'Skipping user auth version schema update because table "users" does not exist yet.'
        );
        return;
    }

    await pool.query(`
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS auth_version INTEGER NOT NULL DEFAULT 0
    `);

    await pool.query(`
        CREATE OR REPLACE FUNCTION sync_user_auth_version()
        RETURNS trigger
        AS $$
        BEGIN
            IF TG_OP = 'UPDATE' AND (
                NEW.email IS DISTINCT FROM OLD.email OR
                NEW.password_hash IS DISTINCT FROM OLD.password_hash OR
                NEW.role IS DISTINCT FROM OLD.role OR
                NEW.is_active IS DISTINCT FROM OLD.is_active
            ) THEN
                NEW.auth_version := COALESCE(OLD.auth_version, 0) + 1;
            ELSIF NEW.auth_version IS NULL THEN
                NEW.auth_version := COALESCE(OLD.auth_version, 0);
            END IF;

            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql
    `);

    await pool.query(`
        DROP TRIGGER IF EXISTS users_auth_version_trigger ON users
    `);

    await pool.query(`
        CREATE TRIGGER users_auth_version_trigger
        BEFORE UPDATE ON users
        FOR EACH ROW
        EXECUTE FUNCTION sync_user_auth_version()
    `);
};

// Test database connection
const connectDB = async () => {
    try {
        const client = await pool.connect();
        console.log('✅ PostgreSQL connected successfully');
        client.release();
        await ensureUserAuthVersionSchema();
        await ensureApplicationWorkflowSchema();
        await ensureCompanyProfileSchema();
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
