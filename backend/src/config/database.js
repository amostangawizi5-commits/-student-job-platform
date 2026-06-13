// src/config/database.js
const { Pool } = require('pg');

const databaseUrl = `${process.env.DATABASE_URL || ''}`;
const sslRequestedViaEnv =
    `${process.env.DB_SSL || process.env.DATABASE_SSL || ''}`.toLowerCase() ===
    'true';
const sslRequestedViaUrl = /(?:^|[?&])ssl(?:mode)?=(?:require|true)/i.test(databaseUrl);
const useSsl = sslRequestedViaEnv || sslRequestedViaUrl;
const parseInteger = (value, fallback) => {
    const parsed = Number.parseInt(`${value || ''}`, 10);
    return Number.isNaN(parsed) ? fallback : parsed;
};
const poolSize = parseInteger(process.env.DB_POOL_MAX, 30);
const idleTimeoutMillis = parseInteger(process.env.DB_IDLE_TIMEOUT_MS, 30000);
const connectionTimeoutMillis = parseInteger(
    process.env.DB_CONNECTION_TIMEOUT_MS,
    10000
);

const poolConfig = process.env.DATABASE_URL
    ? {
          connectionString: process.env.DATABASE_URL,
          ssl: useSsl ? { rejectUnauthorized: false } : false,
          max: poolSize,
          idleTimeoutMillis,
          connectionTimeoutMillis,
          keepAlive: true,
          application_name: process.env.DB_APPLICATION_NAME || 'iptkiganjani-api',
      }
    : {
          user: process.env.DB_USER,
          password: process.env.DB_PASSWORD,
          host: process.env.DB_HOST,
          port: process.env.DB_PORT,
          database: process.env.DB_NAME,
          ssl: useSsl ? { rejectUnauthorized: false } : false,
          max: poolSize,
          idleTimeoutMillis,
          connectionTimeoutMillis,
          keepAlive: true,
          application_name: process.env.DB_APPLICATION_NAME || 'iptkiganjani-api',
      };

// Create PostgreSQL connection pool
const pool = new Pool(poolConfig);
pool.on('error', (error) => {
    console.error('Unexpected PostgreSQL pool error:', error);
});

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

const ensureCoreAuthSchema = async () => {
    await pool.query(`
        CREATE EXTENSION IF NOT EXISTS pgcrypto
    `);

    await pool.query(`
        CREATE TABLE IF NOT EXISTS users (
            user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            email VARCHAR(255) NOT NULL UNIQUE,
            password_hash VARCHAR(255) NOT NULL,
            role VARCHAR(50),
            full_name VARCHAR(255),
            phone VARCHAR(50),
            profile_image_url TEXT,
            is_verified BOOLEAN NOT NULL DEFAULT false,
            is_active BOOLEAN NOT NULL DEFAULT true,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            auth_version INTEGER NOT NULL DEFAULT 0
        )
    `);

    await pool.query(`
        CREATE TABLE IF NOT EXISTS universities (
            university_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            name VARCHAR(255) NOT NULL UNIQUE,
            location VARCHAR(255),
            website TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    `);

    await pool.query(`
        CREATE TABLE IF NOT EXISTS students (
            student_id UUID PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
            university_id UUID REFERENCES universities(university_id) ON DELETE SET NULL,
            program VARCHAR(255),
            student_type VARCHAR(50),
            expected_graduation_year INTEGER,
            graduation_year INTEGER,
            experience_level VARCHAR(120),
            bio TEXT,
            resume_url TEXT,
            github_url TEXT,
            linkedin_url TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            registration_number TEXT,
            identification_card_url TEXT,
            identification_card_name TEXT,
            gpa NUMERIC(4,2)
        )
    `);

    await pool.query(`
        CREATE TABLE IF NOT EXISTS companies (
            company_id UUID PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
            company_name VARCHAR(255) NOT NULL,
            industry VARCHAR(255),
            company_size VARCHAR(100),
            location VARCHAR(255),
            description TEXT,
            website_url TEXT,
            logo_url TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            stamp_url TEXT,
            signature_url TEXT,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            region VARCHAR(120),
            district VARCHAR(120),
            organization_subtype VARCHAR(40),
            government_category VARCHAR(120),
            tin_number VARCHAR(120),
            brela_number VARCHAR(120),
            business_license_number VARCHAR(120),
            department VARCHAR(160),
            sector VARCHAR(160)
        )
    `);

    await pool.query(`
        CREATE TABLE IF NOT EXISTS notifications (
            notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
            title VARCHAR(255),
            message TEXT,
            type VARCHAR(120),
            is_read BOOLEAN DEFAULT false,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    `);

    await pool.query(`
        CREATE INDEX IF NOT EXISTS notifications_user_read_idx
        ON notifications (user_id, is_read, created_at DESC)
    `);
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
        ADD COLUMN IF NOT EXISTS response_letter_sent_at TIMESTAMP,
        ADD COLUMN IF NOT EXISTS reporting_start_date DATE,
        ADD COLUMN IF NOT EXISTS reporting_end_date DATE,
        ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMP,
        ADD COLUMN IF NOT EXISTS student_confirmation_status VARCHAR(40),
        ADD COLUMN IF NOT EXISTS student_confirmed_at TIMESTAMP,
        ADD COLUMN IF NOT EXISTS student_confirmation_expires_at TIMESTAMP,
        ADD COLUMN IF NOT EXISTS student_confirmation_released_at TIMESTAMP
    `);

    await pool.query(`
        ALTER TABLE applications
        DROP CONSTRAINT IF EXISTS applications_status_check
    `);

    await pool.query(`
        ALTER TABLE applications
        ADD CONSTRAINT applications_status_check
        CHECK (status IN ('pending', 'assigned', 'shortlisted', '', 'accepted', 'rejected'))
    `);
};

const ensureApplicationJobForeignKeySchema = async () => {
    const requiredTables = ['applications', 'training'];
    const availability = await Promise.all(requiredTables.map((table) => tableExists(table)));

    if (availability.includes(false)) {
        console.warn(
            'Skipping applications.job_id foreign key update because "applications" or "training" does not exist yet.'
        );
        return;
    }

    const [applicationJobIdType, trainingJobIdType] = await Promise.all([
        getFormattedColumnType('applications', 'job_id'),
        getFormattedColumnType('training', 'job_id')
    ]);

    if (!applicationJobIdType || !trainingJobIdType) {
        console.warn(
            'Skipping applications.job_id foreign key update because one of the column types could not be resolved.'
        );
        return;
    }

    if (applicationJobIdType !== trainingJobIdType) {
        console.warn(
            `applications.job_id type (${applicationJobIdType}) does not match training.job_id type (${trainingJobIdType}).`
        );
        console.warn(
            'Skipping applications.job_id foreign key sync until legacy schema is migrated.'
        );
        return;
    }

    const constraintResult = await pool.query(
        `
        SELECT c.conname,
               c.confrelid::regclass::text AS referenced_table
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = t.relnamespace
        WHERE n.nspname = 'public'
          AND t.relname = 'applications'
          AND c.contype = 'f'
          AND EXISTS (
              SELECT 1
              FROM unnest(c.conkey) AS key_col(attnum)
              JOIN pg_attribute a
                ON a.attrelid = t.oid
               AND a.attnum = key_col.attnum
              WHERE a.attname = 'job_id'
          )
        `
    );

    for (const row of constraintResult.rows) {
        const referencedTable = `${row.referenced_table || ''}`.trim();
        if (
            referencedTable === 'training' ||
            referencedTable === 'public.training'
        ) {
            return;
        }

        await pool.query(
            `ALTER TABLE applications DROP CONSTRAINT IF EXISTS ${row.conname}`
        );
    }

    await pool.query(`
        ALTER TABLE applications
        DROP CONSTRAINT IF EXISTS applications_job_id_fkey
    `);

    await pool.query(`
        ALTER TABLE applications
        ADD CONSTRAINT applications_job_id_fkey
        FOREIGN KEY (job_id)
        REFERENCES training(job_id)
        ON DELETE CASCADE
        NOT VALID
    `);

    try {
        await pool.query(`
            ALTER TABLE applications
            VALIDATE CONSTRAINT applications_job_id_fkey
        `);
    } catch (error) {
        console.warn(
            'applications.job_id foreign key now points to training(job_id), but legacy rows still need cleanup before validation succeeds:',
            error.message
        );
    }
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
        ADD COLUMN IF NOT EXISTS organization_subtype VARCHAR(40),
        ADD COLUMN IF NOT EXISTS government_category VARCHAR(120),
        ADD COLUMN IF NOT EXISTS tin_number VARCHAR(120),
        ADD COLUMN IF NOT EXISTS brela_number VARCHAR(120),
        ADD COLUMN IF NOT EXISTS business_license_number VARCHAR(120),
        ADD COLUMN IF NOT EXISTS department VARCHAR(160),
        ADD COLUMN IF NOT EXISTS sector VARCHAR(160),
        ADD COLUMN IF NOT EXISTS region VARCHAR(120),
        ADD COLUMN IF NOT EXISTS district VARCHAR(120),
        ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    `);

    await pool.query(`
        UPDATE companies
        SET organization_subtype = CASE
                WHEN organization_subtype IS NULL OR BTRIM(organization_subtype) = ''
                    THEN NULL
                ELSE LOWER(REPLACE(BTRIM(organization_subtype), ' ', '_'))
            END,
            government_category = NULLIF(BTRIM(government_category), ''),
            tin_number = NULLIF(BTRIM(tin_number), ''),
            brela_number = NULLIF(BTRIM(brela_number), ''),
            business_license_number = NULLIF(BTRIM(business_license_number), ''),
            department = NULLIF(BTRIM(department), ''),
            sector = NULLIF(BTRIM(sector), '')
    `);

    await pool.query(`
        ALTER TABLE companies
        DROP CONSTRAINT IF EXISTS companies_organization_subtype_check
    `);

    await pool.query(`
        ALTER TABLE companies
        ADD CONSTRAINT companies_organization_subtype_check
        CHECK (
            organization_subtype IS NULL OR
            organization_subtype IN ('private_sector', 'government_sector')
        )
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
            WHEN LOWER(BTRIM(student_type)) = 'current' THEN 'current'
            ELSE ''
        END
    `);

    await pool.query(`
        ALTER TABLE students
        DROP CONSTRAINT IF EXISTS students_student_type_check
    `);

    await pool.query(`
        ALTER TABLE students
        ADD CONSTRAINT students_student_type_check
        CHECK (student_type IN ('current', ''))
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
    const companyIdType = await getFormattedColumnType('companies', 'company_id');
    const applicationJobIdType = await getFormattedColumnType(
        'applications',
        'job_id'
    );

    if (!(await tableExists('training'))) {
        if (!companyIdType) {
            console.warn(
                'Skipping training schema creation because companies.company_id type could not be resolved.'
            );
            return;
        }

        const jobIdType = applicationJobIdType || 'uuid';
        const jobIdDefinition =
            jobIdType === 'uuid'
                ? `${jobIdType} PRIMARY KEY DEFAULT gen_random_uuid()`
                : `${jobIdType} PRIMARY KEY`;

        await pool.query(`
            CREATE TABLE IF NOT EXISTS training (
                job_id ${jobIdDefinition},
                company_id ${companyIdType} NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
                title VARCHAR(255) NOT NULL,
                type VARCHAR(120) NOT NULL DEFAULT '_program',
                target_candidates TEXT[] NOT NULL DEFAULT ARRAY[]::text[],
                description TEXT NOT NULL,
                location TEXT NOT NULL,
                salary_range TEXT,
                required_applicants INTEGER NOT NULL DEFAULT 1,
                application_deadline TIMESTAMP NOT NULL,
                eligible_programs TEXT[] NOT NULL DEFAULT ARRAY[]::text[],
                minimum_gpa NUMERIC(4,2),
                minimum_academic_year INTEGER,
                eligibility_notes TEXT,
                eligibility_match_mode VARCHAR(10) NOT NULL DEFAULT 'all',
                status VARCHAR(20) NOT NULL DEFAULT 'open',
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
        `);
    }

    await pool.query(`
        ALTER TABLE training
        ADD COLUMN IF NOT EXISTS eligible_programs TEXT[] DEFAULT ARRAY[]::text[],
        ADD COLUMN IF NOT EXISTS minimum_gpa NUMERIC(4,2),
        ADD COLUMN IF NOT EXISTS minimum_academic_year INTEGER,
        ADD COLUMN IF NOT EXISTS eligibility_notes TEXT,
        ADD COLUMN IF NOT EXISTS eligibility_match_mode VARCHAR(10) NOT NULL DEFAULT 'all'
    `);

    await pool.query(`
        UPDATE training
        SET eligibility_match_mode = LOWER(BTRIM(COALESCE(eligibility_match_mode, 'all')))
    `);

    await pool.query(`
        ALTER TABLE training
        DROP CONSTRAINT IF EXISTS training_required_applicants_check
    `);

    await pool.query(`
        ALTER TABLE training
        ADD CONSTRAINT training_required_applicants_check
        CHECK (required_applicants >= 0)
    `);

    await pool.query(`
        ALTER TABLE training
        DROP CONSTRAINT IF EXISTS training_minimum_gpa_check
    `);

    await pool.query(`
        ALTER TABLE training
        ADD CONSTRAINT training_minimum_gpa_check
        CHECK (minimum_gpa IS NULL OR (minimum_gpa >= 0 AND minimum_gpa <= 5))
    `);

    await pool.query(`
        ALTER TABLE training
        DROP CONSTRAINT IF EXISTS training_minimum_academic_year_check
    `);

    await pool.query(`
        ALTER TABLE training
        ADD CONSTRAINT training_minimum_academic_year_check
        CHECK (minimum_academic_year IS NULL OR minimum_academic_year >= 1)
    `);

    await pool.query(`
        ALTER TABLE training
        DROP CONSTRAINT IF EXISTS training_eligibility_match_mode_check
    `);

    await pool.query(`
        ALTER TABLE training
        ADD CONSTRAINT training_eligibility_match_mode_check
        CHECK (eligibility_match_mode IN ('all', 'any'))
    `);

    await pool.query(`
        ALTER TABLE training
        DROP CONSTRAINT IF EXISTS training_status_check
    `);

    await pool.query(`
        ALTER TABLE training
        ADD CONSTRAINT training_status_check
        CHECK (status IN ('open', 'closed'))
    `);

    await pool.query(`
        CREATE INDEX IF NOT EXISTS training_company_id_idx
        ON training (company_id)
    `);

    await pool.query(`
        CREATE INDEX IF NOT EXISTS training_status_deadline_idx
        ON training (status, application_deadline)
    `);

    const jobIdType = await getFormattedColumnType('training', 'job_id');
    const skillIdType = await getFormattedColumnType('skills', 'skill_id');

    if (jobIdType && skillIdType && (await tableExists('skills'))) {
        await pool.query(`
            CREATE TABLE IF NOT EXISTS job_skills (
                job_id ${jobIdType} NOT NULL REFERENCES training(job_id) ON DELETE CASCADE,
                skill_id ${skillIdType} NOT NULL REFERENCES skills(skill_id) ON DELETE CASCADE,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (job_id, skill_id)
            )
        `);

        await pool.query(`
            CREATE INDEX IF NOT EXISTS job_skills_skill_id_idx
            ON job_skills (skill_id)
        `);

        await pool.query(`
            ALTER TABLE job_skills
            DROP CONSTRAINT IF EXISTS job_skills_job_id_fkey
        `);

        await pool.query(`
            ALTER TABLE job_skills
            ADD CONSTRAINT job_skills_job_id_fkey
            FOREIGN KEY (job_id) REFERENCES training(job_id) ON DELETE CASCADE
        `);
    }
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

const ensureUniversityOrganizationChatSchema = async () => {
    if (!(await tableExists('users'))) {
        console.warn(
            'Skipping university-organization chat schema update because table "users" does not exist yet.'
        );
        return;
    }

    const userIdType = await getFormattedColumnType('users', 'user_id');
    if (!userIdType) {
        console.warn(
            'Skipping university-organization chat schema update because users.user_id type could not be resolved.'
        );
        return;
    }

    await pool.query(`
        CREATE TABLE IF NOT EXISTS university_organization_messages (
            chat_message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            university_user_id ${userIdType} NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
            company_user_id ${userIdType} NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
            sender_user_id ${userIdType} NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
            sender_role VARCHAR(30) NOT NULL DEFAULT 'organization',
            sender_name VARCHAR(255) NOT NULL,
            sender_phone TEXT,
            message TEXT NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            edited_at TIMESTAMP,
            deleted_for_university_at TIMESTAMP,
            deleted_for_company_at TIMESTAMP,
            read_at TIMESTAMP,
            read_by_user_id ${userIdType} REFERENCES users(user_id) ON DELETE SET NULL
        )
    `);

    await pool.query(`
        ALTER TABLE university_organization_messages
        ADD COLUMN IF NOT EXISTS sender_role VARCHAR(30) NOT NULL DEFAULT 'organization',
        ADD COLUMN IF NOT EXISTS sender_name VARCHAR(255),
        ADD COLUMN IF NOT EXISTS sender_phone TEXT,
        ADD COLUMN IF NOT EXISTS message TEXT,
        ADD COLUMN IF NOT EXISTS created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        ADD COLUMN IF NOT EXISTS edited_at TIMESTAMP,
        ADD COLUMN IF NOT EXISTS deleted_for_university_at TIMESTAMP,
        ADD COLUMN IF NOT EXISTS deleted_for_company_at TIMESTAMP,
        ADD COLUMN IF NOT EXISTS read_at TIMESTAMP,
        ADD COLUMN IF NOT EXISTS read_by_user_id ${userIdType}
    `);

    await pool.query(`
        ALTER TABLE university_organization_messages
        ADD CONSTRAINT university_organization_messages_read_by_user_fk
        FOREIGN KEY (read_by_user_id) REFERENCES users(user_id) ON DELETE SET NULL
    `).catch((error) => {
        if (error?.code !== '42710') {
            throw error;
        }
    });

    await pool.query(`
        CREATE INDEX IF NOT EXISTS university_organization_messages_company_university_idx
        ON university_organization_messages (company_user_id, university_user_id, created_at DESC)
    `);

    await pool.query(`
        CREATE INDEX IF NOT EXISTS university_organization_messages_university_company_idx
        ON university_organization_messages (university_user_id, company_user_id, created_at DESC)
    `);

    await pool.query(`
        CREATE INDEX IF NOT EXISTS university_organization_messages_unread_company_idx
        ON university_organization_messages (company_user_id, university_user_id, read_at)
    `);

    await pool.query(`
        CREATE INDEX IF NOT EXISTS university_organization_messages_unread_university_idx
        ON university_organization_messages (university_user_id, company_user_id, read_at)
    `);
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
        getFormattedColumnType('training', 'job_id')
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
            job_id ${jobIdType} REFERENCES training(job_id) ON DELETE SET NULL,
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
        console.warn(
            'Awards table key column types do not match the current database schema. ' +
            'Skipping awards schema sync until the legacy table is migrated.'
        );
        return;
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

const ensureUserLookupSchema = async () => {
    if (!(await tableExists('users'))) {
        console.warn(
            'Skipping user lookup schema update because table "users" does not exist yet.'
        );
        return;
    }

    await pool.query(`
        CREATE INDEX IF NOT EXISTS users_email_normalized_idx
        ON users ((LOWER(BTRIM(email))))
    `);

    await pool.query(`
        CREATE INDEX IF NOT EXISTS users_role_is_active_idx
        ON users (role, is_active)
    `);
};

const ensureUserProfileSchema = async () => {
    if (!(await tableExists('users'))) {
        console.warn(
            'Skipping user profile schema update because table "users" does not exist yet.'
        );
        return;
    }

    await pool.query(`
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT false,
        ADD COLUMN IF NOT EXISTS profile_image_url TEXT
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
            SET student_type = ''
            FROM users AS u
            WHERE u.user_id = s.student_id
              AND u.role = ''
              AND COALESCE(NULLIF(TRIM(s.student_type), ''), 'current') <> ''
        `);
    }

    await pool.query(`
        UPDATE users
        SET role = 'student'
        WHERE role = ''
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

const ensureOnlineTestSchema = async () => {
    await pool.query(`
        ALTER TABLE students
        ADD COLUMN IF NOT EXISTS id UUID,
        ADD COLUMN IF NOT EXISTS name TEXT,
        ADD COLUMN IF NOT EXISTS email TEXT,
        ADD COLUMN IF NOT EXISTS university TEXT,
        ADD COLUMN IF NOT EXISTS training TEXT,
        ADD COLUMN IF NOT EXISTS status VARCHAR(40) NOT NULL DEFAULT 'pending'
    `);

    await pool.query(`
        UPDATE students AS s
        SET id = COALESCE(s.id, s.student_id),
            name = COALESCE(NULLIF(BTRIM(s.name), ''), u.full_name),
            email = COALESCE(NULLIF(BTRIM(s.email), ''), u.email),
            university = COALESCE(
                NULLIF(BTRIM(s.university), ''),
                (
                    SELECT uni.name
                    FROM universities AS uni
                    WHERE uni.university_id = s.university_id
                    LIMIT 1
                )
            ),
            training = COALESCE(NULLIF(BTRIM(s.training), ''), s.program),
            status = COALESCE(NULLIF(BTRIM(s.status), ''), 'pending')
        FROM users AS u
        WHERE u.user_id = s.student_id
    `);

    await pool.query(`
        CREATE UNIQUE INDEX IF NOT EXISTS students_id_compat_idx
        ON students (id)
        WHERE id IS NOT NULL
    `);

    await pool.query(`
        ALTER TABLE students
        DROP CONSTRAINT IF EXISTS students_selection_status_check
    `);

    await pool.query(`
        ALTER TABLE students
        ADD CONSTRAINT students_selection_status_check
        CHECK (status IN ('pending', 'shortlisted', 'accepted', 'rejected'))
    `);

    await pool.query(`
        CREATE TABLE IF NOT EXISTS tests (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            title VARCHAR(255) NOT NULL,
            duration INTEGER NOT NULL,
            pass_mark NUMERIC(5,2) NOT NULL,
            deadline TIMESTAMPTZ NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
    `);

    await pool.query(`
        ALTER TABLE tests
        ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES companies(company_id) ON DELETE CASCADE,
        ADD COLUMN IF NOT EXISTS job_id UUID REFERENCES training(job_id) ON DELETE SET NULL
    `);

    await pool.query(`
        CREATE INDEX IF NOT EXISTS tests_company_job_idx
        ON tests (company_id, job_id, created_at DESC)
    `);

    await pool.query(`
        CREATE TABLE IF NOT EXISTS questions (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            test_id UUID NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
            question_text TEXT NOT NULL,
            question_type VARCHAR(40) NOT NULL,
            marks NUMERIC(8,2) NOT NULL,
            correct_answer TEXT,
            question_options TEXT[] NOT NULL DEFAULT ARRAY[]::text[],
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
    `);

    await pool.query(`
        ALTER TABLE questions
        DROP CONSTRAINT IF EXISTS questions_question_type_check
    `);

    await pool.query(`
        ALTER TABLE questions
        ADD CONSTRAINT questions_question_type_check
        CHECK (question_type IN ('short_answer', 'multiple_choice', 'paragraph', 'code'))
    `);

    await pool.query(`
        ALTER TABLE questions
        DROP CONSTRAINT IF EXISTS questions_marks_check
    `);

    await pool.query(`
        ALTER TABLE questions
        ADD CONSTRAINT questions_marks_check
        CHECK (marks > 0)
    `);

    await pool.query(`
        CREATE TABLE IF NOT EXISTS test_attempts (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            student_id UUID NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
            test_id UUID NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
            unique_link TEXT NOT NULL UNIQUE,
            started_at TIMESTAMPTZ,
            submitted_at TIMESTAMPTZ,
            total_score NUMERIC(6,2),
            status VARCHAR(40) NOT NULL DEFAULT 'pending',
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            UNIQUE (student_id, test_id)
        )
    `);

    await pool.query(`
        ALTER TABLE test_attempts
        DROP CONSTRAINT IF EXISTS test_attempts_status_check
    `);

    await pool.query(`
        ALTER TABLE test_attempts
        ADD CONSTRAINT test_attempts_status_check
        CHECK (status IN ('pending', 'in_progress', 'completed'))
    `);

    await pool.query(`
        CREATE TABLE IF NOT EXISTS answers (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            attempt_id UUID NOT NULL REFERENCES test_attempts(id) ON DELETE CASCADE,
            question_id UUID NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
            answer_text TEXT,
            score_awarded NUMERIC(8,2),
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            UNIQUE (attempt_id, question_id)
        )
    `);

    await pool.query(`
        CREATE INDEX IF NOT EXISTS questions_test_id_idx
        ON questions (test_id)
    `);

    await pool.query(`
        CREATE INDEX IF NOT EXISTS test_attempts_test_status_score_idx
        ON test_attempts (test_id, status, total_score DESC NULLS LAST)
    `);
};

const runStartupMigration = async (name, migrate, { required = false } = {}) => {
    try {
        await migrate();
    } catch (error) {
        const message = error?.message || error;
        if (required) {
            console.error(`Required startup migration failed: ${name}:`, message);
            throw error;
        }

        console.warn(`Optional startup migration skipped: ${name}:`, message);
    }
};

// Test database connection
const connectDB = async () => {
    try {
        const client = await pool.connect();
        console.log(' PostgreSQL connected successfully');
        client.release();
        await runStartupMigration('core auth schema', ensureCoreAuthSchema, {
            required: true
        });
        await runStartupMigration('user role schema', ensureUserRoleSchema, {
            required: true
        });
        await runStartupMigration('user auth version schema', ensureUserAuthVersionSchema);
        await runStartupMigration('user profile schema', ensureUserProfileSchema);
        await runStartupMigration('user lookup schema', ensureUserLookupSchema);
        await runStartupMigration(
            'application workflow schema',
            ensureApplicationWorkflowSchema
        );
        await runStartupMigration('company profile schema', ensureCompanyProfileSchema);
        await runStartupMigration(
            'student registration schema',
            ensureStudentRegistrationSchema
        );
        await runStartupMigration('job eligibility schema', ensureJobEligibilitySchema);
        await runStartupMigration(
            'application job foreign key schema',
            ensureApplicationJobForeignKeySchema
        );
        await runStartupMigration(
            'university profile schema',
            ensureUniversityProfileSchema
        );
        await runStartupMigration(
            'university organization chat schema',
            ensureUniversityOrganizationChatSchema
        );
        await runStartupMigration('awards schema', ensureAwardsSchema);
        await runStartupMigration('online test schema', ensureOnlineTestSchema);
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
