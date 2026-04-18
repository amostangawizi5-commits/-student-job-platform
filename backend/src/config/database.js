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

const getFormattedColumnType = async (tableName, columnName) => {
    const result = await pool.query(
        `
        SELECT pg_catalog.format_type(a.atttypid, a.atttypmod) AS formatted_type
        FROM pg_catalog.pg_attribute a
        JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
        JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
        WHERE n.nspname = 'public'
          AND c.relname = $1
          AND a.attname = $2
          AND a.attnum > 0
          AND NOT a.attisdropped
        LIMIT 1
        `,
        [tableName, columnName]
    );

    return result.rows[0]?.formatted_type || null;
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
        ADD COLUMN IF NOT EXISTS signature_url TEXT,
        ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    `);
};

const ensureStudentRegistrationSchema = async () => {
    if (!(await tableExists('students'))) {
        console.warn(
            'Skipping student registration schema update because table "students" does not exist yet.'
        );
        return;
    }

    await pool.query(`
        ALTER TABLE students
        ADD COLUMN IF NOT EXISTS registration_number TEXT,
        ADD COLUMN IF NOT EXISTS identification_card_url TEXT,
        ADD COLUMN IF NOT EXISTS identification_card_name TEXT,
        ADD COLUMN IF NOT EXISTS gpa NUMERIC(4,2)
    `);

    await pool.query(`
        UPDATE students
        SET student_type = CASE
            WHEN student_type IS NULL OR BTRIM(student_type) = '' THEN 'current'
            ELSE LOWER(BTRIM(student_type))
        END
    `);

    await pool.query(`
        ALTER TABLE students
        DROP CONSTRAINT IF EXISTS students_student_type_check
    `);

    await pool.query(`
        ALTER TABLE students
        ADD CONSTRAINT students_student_type_check
        CHECK (student_type IN ('current', 'graduate'))
    `);

    await pool.query(`
        ALTER TABLE students
        DROP CONSTRAINT IF EXISTS students_gpa_check
    `);

    await pool.query(`
        ALTER TABLE students
        ADD CONSTRAINT students_gpa_check
        CHECK (gpa IS NULL OR (gpa >= 0 AND gpa <= 5))
    `);

    await pool.query(`
        CREATE UNIQUE INDEX IF NOT EXISTS students_registration_number_normalized_idx
        ON students ((LOWER(BTRIM(registration_number))))
        WHERE BTRIM(COALESCE(registration_number, '')) <> ''
    `);
};

const ensureJobEligibilitySchema = async () => {
    if (!(await tableExists('jobs'))) {
        console.warn(
            'Skipping job eligibility schema update because table "jobs" does not exist yet.'
        );
        return;
    }

    await pool.query(`
        ALTER TABLE jobs
        ADD COLUMN IF NOT EXISTS eligible_programs TEXT[] DEFAULT ARRAY[]::text[],
        ADD COLUMN IF NOT EXISTS minimum_gpa NUMERIC(4,2),
        ADD COLUMN IF NOT EXISTS minimum_academic_year INTEGER,
        ADD COLUMN IF NOT EXISTS eligibility_notes TEXT,
        ADD COLUMN IF NOT EXISTS eligibility_match_mode VARCHAR(10) NOT NULL DEFAULT 'all'
    `);

    await pool.query(`
        UPDATE jobs
        SET eligibility_match_mode = LOWER(BTRIM(COALESCE(eligibility_match_mode, 'all')))
    `);

    await pool.query(`
        ALTER TABLE jobs
        DROP CONSTRAINT IF EXISTS jobs_required_applicants_check
    `);

    await pool.query(`
        ALTER TABLE jobs
        ADD CONSTRAINT jobs_required_applicants_check
        CHECK (required_applicants >= 1)
    `);

    await pool.query(`
        ALTER TABLE jobs
        DROP CONSTRAINT IF EXISTS jobs_minimum_gpa_check
    `);

    await pool.query(`
        ALTER TABLE jobs
        ADD CONSTRAINT jobs_minimum_gpa_check
        CHECK (minimum_gpa IS NULL OR (minimum_gpa >= 0 AND minimum_gpa <= 5))
    `);

    await pool.query(`
        ALTER TABLE jobs
        DROP CONSTRAINT IF EXISTS jobs_minimum_academic_year_check
    `);

    await pool.query(`
        ALTER TABLE jobs
        ADD CONSTRAINT jobs_minimum_academic_year_check
        CHECK (minimum_academic_year IS NULL OR minimum_academic_year >= 1)
    `);

    await pool.query(`
        ALTER TABLE jobs
        DROP CONSTRAINT IF EXISTS jobs_eligibility_match_mode_check
    `);

    await pool.query(`
        ALTER TABLE jobs
        ADD CONSTRAINT jobs_eligibility_match_mode_check
        CHECK (eligibility_match_mode IN ('all', 'any'))
    `);
};

const ensureUniversityProfileSchema = async () => {
    if (!(await tableExists('users'))) {
        console.warn(
            'Skipping university profile schema update because table "users" does not exist yet.'
        );
        return;
    }

    const userIdType = await getFormattedColumnType('users', 'user_id');
    if (!userIdType) {
        console.warn(
            'Skipping university profile schema update because users.user_id type could not be resolved.'
        );
        return;
    }

    const universityIdType =
        (await getFormattedColumnType('students', 'university_id')) ||
        (await getFormattedColumnType('universities', 'university_id'));

    await pool.query(`
        CREATE TABLE IF NOT EXISTS university_profiles (
            user_id ${userIdType} PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
            ${universityIdType ? `university_id ${universityIdType},` : ''}
            college_name VARCHAR(255) NOT NULL,
            registration_number VARCHAR(120) NOT NULL,
            college_email TEXT NOT NULL,
            college_phone TEXT NOT NULL,
            address TEXT NOT NULL,
            region VARCHAR(120) NOT NULL,
            district VARCHAR(120) NOT NULL,
            website_url TEXT,
            college_type VARCHAR(60),
            subscription_status VARCHAR(30) NOT NULL DEFAULT 'trial',
            coordinator_name VARCHAR(255) NOT NULL,
            coordinator_phone TEXT NOT NULL,
            coordinator_email TEXT NOT NULL,
            logo_url TEXT,
            logo_name TEXT,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    `);

    if (universityIdType) {
        await pool.query(`
            ALTER TABLE university_profiles
            ADD COLUMN IF NOT EXISTS university_id ${universityIdType}
        `);
    }

    await pool.query(`
        ALTER TABLE university_profiles
        ADD COLUMN IF NOT EXISTS college_name VARCHAR(255),
        ADD COLUMN IF NOT EXISTS registration_number VARCHAR(120),
        ADD COLUMN IF NOT EXISTS college_email TEXT,
        ADD COLUMN IF NOT EXISTS college_phone TEXT,
        ADD COLUMN IF NOT EXISTS address TEXT,
        ADD COLUMN IF NOT EXISTS region VARCHAR(120),
        ADD COLUMN IF NOT EXISTS district VARCHAR(120),
        ADD COLUMN IF NOT EXISTS website_url TEXT,
        ADD COLUMN IF NOT EXISTS college_type VARCHAR(60),
        ADD COLUMN IF NOT EXISTS subscription_status VARCHAR(30) NOT NULL DEFAULT 'trial',
        ADD COLUMN IF NOT EXISTS coordinator_name VARCHAR(255),
        ADD COLUMN IF NOT EXISTS coordinator_phone TEXT,
        ADD COLUMN IF NOT EXISTS coordinator_email TEXT,
        ADD COLUMN IF NOT EXISTS logo_url TEXT,
        ADD COLUMN IF NOT EXISTS logo_name TEXT,
        ADD COLUMN IF NOT EXISTS created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    `);

    await pool.query(`
        UPDATE university_profiles
        SET registration_number = NULLIF(BTRIM(registration_number), ''),
            college_email = NULLIF(LOWER(BTRIM(college_email)), ''),
            coordinator_email = NULLIF(LOWER(BTRIM(coordinator_email)), ''),
            subscription_status = CASE
                WHEN subscription_status IS NULL OR BTRIM(subscription_status) = ''
                    THEN 'trial'
                ELSE LOWER(BTRIM(subscription_status))
            END
    `);

    if (universityIdType && (await tableExists('universities'))) {
        await pool.query(`
            UPDATE university_profiles up
            SET university_id = u.university_id,
                college_name = COALESCE(NULLIF(BTRIM(u.name), ''), up.college_name),
                updated_at = CURRENT_TIMESTAMP
            FROM universities u
            WHERE (
                up.university_id IS NULL
                OR BTRIM(COALESCE(up.college_name, '')) <> BTRIM(COALESCE(u.name, ''))
            )
              AND LOWER(BTRIM(COALESCE(up.college_name, ''))) = LOWER(BTRIM(COALESCE(u.name, '')))
        `);
    }

    await pool.query(`
        ALTER TABLE university_profiles
        DROP CONSTRAINT IF EXISTS university_profiles_subscription_status_check
    `);

    await pool.query(`
        ALTER TABLE university_profiles
        ADD CONSTRAINT university_profiles_subscription_status_check
        CHECK (subscription_status IN ('trial', 'active', 'inactive'))
    `);

    await pool.query(`
        CREATE UNIQUE INDEX IF NOT EXISTS university_profiles_registration_number_normalized_idx
        ON university_profiles ((LOWER(BTRIM(registration_number))))
        WHERE BTRIM(COALESCE(registration_number, '')) <> ''
    `);

    await pool.query(`
        CREATE UNIQUE INDEX IF NOT EXISTS university_profiles_college_email_normalized_idx
        ON university_profiles ((LOWER(BTRIM(college_email))))
        WHERE BTRIM(COALESCE(college_email, '')) <> ''
    `);

    if (universityIdType) {
        await pool.query(`
            CREATE INDEX IF NOT EXISTS university_profiles_university_id_idx
            ON university_profiles (university_id)
        `);
    }
};

const ensureAwardsSchema = async () => {
    const requiredTables = ['applications', 'companies', 'students', 'users'];
    const availability = await Promise.all(requiredTables.map((table) => tableExists(table)));

    if (availability.includes(false)) {
        console.warn(
            'Skipping awards schema update because one or more required tables are missing.'
        );
        return;
    }

    const [
        applicationIdType,
        companyIdType,
        studentIdType,
        jobIdType
    ] = await Promise.all([
        getFormattedColumnType('applications', 'application_id'),
        getFormattedColumnType('companies', 'company_id'),
        getFormattedColumnType('students', 'student_id'),
        getFormattedColumnType('jobs', 'job_id')
    ]);

    if (!applicationIdType || !companyIdType || !studentIdType || !jobIdType) {
        console.warn(
            'Skipping awards schema update because one or more required key column types could not be resolved.'
        );
        return;
    }

    await pool.query(`
        CREATE TABLE IF NOT EXISTS awards (
            award_id SERIAL PRIMARY KEY,
            application_id ${applicationIdType} NOT NULL UNIQUE REFERENCES applications(application_id) ON DELETE CASCADE,
            company_id ${companyIdType} NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
            student_id ${studentIdType} NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
            job_id ${jobIdType} REFERENCES jobs(job_id) ON DELETE SET NULL,
            title VARCHAR(255) NOT NULL,
            award_type VARCHAR(120),
            category VARCHAR(120),
            description TEXT,
            reason TEXT,
            highlights JSONB NOT NULL DEFAULT '[]'::jsonb,
            prize_type VARCHAR(60),
            prize_value VARCHAR(120),
            prize_description TEXT,
            rating INTEGER NOT NULL DEFAULT 5,
            certificate_url TEXT,
            certificate_name TEXT,
            award_date DATE,
            award_status VARCHAR(30) NOT NULL DEFAULT 'published',
            announce_on_homepage BOOLEAN NOT NULL DEFAULT TRUE,
            is_student_of_month BOOLEAN NOT NULL DEFAULT FALSE,
            featured_label TEXT,
            award_year INTEGER,
            likes_count INTEGER NOT NULL DEFAULT 0,
            comments_count INTEGER NOT NULL DEFAULT 0,
            share_count INTEGER NOT NULL DEFAULT 0,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    `);

    await pool.query(`
        ALTER TABLE awards
        ADD COLUMN IF NOT EXISTS award_type VARCHAR(120),
        ADD COLUMN IF NOT EXISTS category VARCHAR(120),
        ADD COLUMN IF NOT EXISTS description TEXT,
        ADD COLUMN IF NOT EXISTS reason TEXT,
        ADD COLUMN IF NOT EXISTS highlights JSONB NOT NULL DEFAULT '[]'::jsonb,
        ADD COLUMN IF NOT EXISTS prize_type VARCHAR(60),
        ADD COLUMN IF NOT EXISTS prize_value VARCHAR(120),
        ADD COLUMN IF NOT EXISTS prize_description TEXT,
        ADD COLUMN IF NOT EXISTS rating INTEGER NOT NULL DEFAULT 5,
        ADD COLUMN IF NOT EXISTS certificate_url TEXT,
        ADD COLUMN IF NOT EXISTS certificate_name TEXT,
        ADD COLUMN IF NOT EXISTS award_date DATE,
        ADD COLUMN IF NOT EXISTS award_status VARCHAR(30) NOT NULL DEFAULT 'published',
        ADD COLUMN IF NOT EXISTS announce_on_homepage BOOLEAN NOT NULL DEFAULT TRUE,
        ADD COLUMN IF NOT EXISTS is_student_of_month BOOLEAN NOT NULL DEFAULT FALSE,
        ADD COLUMN IF NOT EXISTS featured_label TEXT,
        ADD COLUMN IF NOT EXISTS award_year INTEGER,
        ADD COLUMN IF NOT EXISTS likes_count INTEGER NOT NULL DEFAULT 0,
        ADD COLUMN IF NOT EXISTS comments_count INTEGER NOT NULL DEFAULT 0,
        ADD COLUMN IF NOT EXISTS share_count INTEGER NOT NULL DEFAULT 0,
        ADD COLUMN IF NOT EXISTS created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    `);

    const existingAwardColumnTypes = await pool.query(
        `
        SELECT a.attname AS column_name, pg_catalog.format_type(a.atttypid, a.atttypmod) AS formatted_type
        FROM pg_catalog.pg_attribute a
        JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
        JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
        WHERE n.nspname = 'public'
          AND c.relname = 'awards'
          AND a.attname IN ('application_id', 'company_id', 'student_id', 'job_id')
          AND a.attnum > 0
          AND NOT a.attisdropped
        `
    );

    const awardsTypeMap = Object.fromEntries(
        existingAwardColumnTypes.rows.map((row) => [row.column_name, row.formatted_type])
    );

    const typeMismatch = (
        awardsTypeMap.application_id &&
        awardsTypeMap.application_id !== applicationIdType
    ) || (
        awardsTypeMap.company_id &&
        awardsTypeMap.company_id !== companyIdType
    ) || (
        awardsTypeMap.student_id &&
        awardsTypeMap.student_id !== studentIdType
    ) || (
        awardsTypeMap.job_id &&
        awardsTypeMap.job_id !== jobIdType
    );

    if (typeMismatch) {
        throw new Error(
            'Awards table key column types do not match the current database schema. ' +
            'Please drop and recreate the "awards" table before restarting the server.'
        );
    }

    await pool.query(`
        CREATE INDEX IF NOT EXISTS awards_company_id_idx ON awards(company_id)
    `);

    await pool.query(`
        CREATE INDEX IF NOT EXISTS awards_student_id_idx ON awards(student_id)
    `);

    await pool.query(`
        CREATE INDEX IF NOT EXISTS awards_created_at_idx ON awards(created_at DESC)
    `);

    await pool.query(`
        ALTER TABLE awards
        DROP CONSTRAINT IF EXISTS awards_rating_check
    `);

    await pool.query(`
        ALTER TABLE awards
        ADD CONSTRAINT awards_rating_check
        CHECK (rating >= 1 AND rating <= 5)
    `);

    await pool.query(`
        ALTER TABLE awards
        DROP CONSTRAINT IF EXISTS awards_engagement_counts_check
    `);

    await pool.query(`
        ALTER TABLE awards
        ADD CONSTRAINT awards_engagement_counts_check
        CHECK (
            likes_count >= 0 AND
            comments_count >= 0 AND
            share_count >= 0
        )
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

const ensureUserRoleSchema = async () => {
    if (!(await tableExists('users'))) {
        console.warn(
            'Skipping user role schema update because table "users" does not exist yet.'
        );
        return;
    }

    if (await tableExists('students')) {
        await pool.query(`
            UPDATE students AS s
            SET student_type = 'graduate'
            FROM users AS u
            WHERE u.user_id = s.student_id
              AND u.role = 'graduate'
              AND COALESCE(NULLIF(TRIM(s.student_type), ''), 'current') <> 'graduate'
        `);
    }

    await pool.query(`
        UPDATE users
        SET role = 'student'
        WHERE role = 'graduate'
    `);

    await pool.query(`
        ALTER TABLE users
        DROP CONSTRAINT IF EXISTS users_role_check
    `);

    await pool.query(`
        ALTER TABLE users
        ADD CONSTRAINT users_role_check
        CHECK (role IN ('student', 'company', 'university', 'admin'))
    `);
};

// Test database connection
const connectDB = async () => {
    try {
        const client = await pool.connect();
        console.log('✅ PostgreSQL connected successfully');
        client.release();
        await ensureUserRoleSchema();
        await ensureUserAuthVersionSchema();
        await ensureApplicationWorkflowSchema();
        await ensureCompanyProfileSchema();
        await ensureStudentRegistrationSchema();
        await ensureJobEligibilitySchema();
        await ensureUniversityProfileSchema();
        await ensureAwardsSchema();
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
