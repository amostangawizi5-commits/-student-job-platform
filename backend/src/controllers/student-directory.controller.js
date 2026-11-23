const { query } = require('../config/database');

const normalizeText = (value) => {
  const text = `${value ?? ''}`.trim();
  return text || null;
};

const normalizeBoolean = (value, fallback = false) => {
  if (value === undefined || value === null) return fallback;
  if (typeof value === 'boolean') return value;
  return ['1', 'true', 'yes', 'on'].includes(`${value}`.trim().toLowerCase());
};

const normalizeLimit = (value) => {
  const parsed = Number.parseInt(`${value ?? ''}`, 10);
  if (!Number.isInteger(parsed)) return 24;
  return Math.min(Math.max(parsed, 1), 100);
};

const normalizeOffset = (value) => {
  const parsed = Number.parseInt(`${value ?? ''}`, 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : 0;
};

const publicProfileSelect = `
  SELECT
    u.user_id AS student_id,
    u.full_name,
    u.email,
    u.phone,
    u.profile_image_url,
    s.program,
    s.experience_level,
    s.gpa,
    s.expected_graduation_year,
    s.github_url,
    s.linkedin_url,
    uni.university_id,
    uni.name AS university_name,
    spp.is_public,
    spp.headline,
    spp.about,
    spp.desired_role,
    spp.preferred_location,
    spp.updated_at,
    COALESCE((
      SELECT json_agg(
        json_build_object(
          'skill_id', sk.skill_id,
          'name', sk.name,
          'category', sk.category
        ) ORDER BY sk.name
      )
      FROM student_skills ss
      JOIN skills sk ON sk.skill_id = ss.skill_id
      WHERE ss.student_id = u.user_id
    ), '[]'::json) AS skills,
    COALESCE((
      SELECT json_agg(
        json_build_object(
          'project_id', p.project_id,
          'title', p.title,
          'description', p.description,
          'technologies', p.technologies,
          'github_link', p.github_link,
          'live_demo_link', p.live_demo_link
        ) ORDER BY p.created_at DESC
      )
      FROM projects p
      WHERE p.student_id = u.user_id
    ), '[]'::json) AS projects
  FROM users u
  JOIN students s ON s.student_id = u.user_id
  LEFT JOIN universities uni ON uni.university_id = s.university_id
  LEFT JOIN student_public_profiles spp ON spp.student_id = u.user_id
`;

const getOwnPublicProfile = async (req, res) => {
  try {
    const result = await query(
      `${publicProfileSelect}
       WHERE u.user_id = $1
       LIMIT 1`,
      [req.user.user_id],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Student profile not found',
      });
    }

    return res.json({ success: true, data: result.rows[0] });
  } catch (error) {
    console.error('Get student public profile error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to load public profile',
    });
  }
};

const updateOwnPublicProfile = async (req, res) => {
  try {
    const body = req.body && typeof req.body === 'object' ? req.body : {};
    const result = await query(
      `INSERT INTO student_public_profiles (
         student_id,
         is_public,
         headline,
         about,
         desired_role,
         preferred_location,
         updated_at
       ) VALUES ($1, $2, $3, $4, $5, $6, CURRENT_TIMESTAMP)
       ON CONFLICT (student_id) DO UPDATE SET
         is_public = EXCLUDED.is_public,
         headline = COALESCE(EXCLUDED.headline, student_public_profiles.headline),
         about = COALESCE(EXCLUDED.about, student_public_profiles.about),
         desired_role = COALESCE(EXCLUDED.desired_role, student_public_profiles.desired_role),
         preferred_location = COALESCE(EXCLUDED.preferred_location, student_public_profiles.preferred_location),
         updated_at = CURRENT_TIMESTAMP
       RETURNING *`,
      [
        req.user.user_id,
        normalizeBoolean(body.is_public),
        normalizeText(body.headline),
        normalizeText(body.about),
        normalizeText(body.desired_role),
        normalizeText(body.preferred_location),
      ],
    );

    return res.json({
      success: true,
      message: result.rows[0].is_public
        ? 'Your profile is now visible to companies'
        : 'Your profile is hidden from companies',
      data: result.rows[0],
    });
  } catch (error) {
    console.error('Update student public profile error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to update public profile',
    });
  }
};

const listStudentDirectory = async (req, res) => {
  try {
    const search = normalizeText(req.query.search || req.query.q);
    const skill = normalizeText(req.query.skill);
    const universityId = normalizeText(req.query.university_id);
    const limit = normalizeLimit(req.query.limit);
    const offset = normalizeOffset(req.query.offset);
    const values = [];
    const conditions = [
      "u.role IN ('student', '')",
      'u.is_active = TRUE',
      'COALESCE(spp.is_public, FALSE) = TRUE',
    ];

    const addValue = (value) => {
      values.push(value);
      return `$${values.length}`;
    };

    if (search) {
      const parameter = addValue(`%${search}%`);
      conditions.push(`(
        u.full_name ILIKE ${parameter}
        OR s.program ILIKE ${parameter}
        OR spp.headline ILIKE ${parameter}
        OR spp.about ILIKE ${parameter}
        OR spp.desired_role ILIKE ${parameter}
        OR uni.name ILIKE ${parameter}
        OR EXISTS (
          SELECT 1
          FROM student_skills search_ss
          JOIN skills search_sk ON search_sk.skill_id = search_ss.skill_id
          WHERE search_ss.student_id = u.user_id
            AND search_sk.name ILIKE ${parameter}
        )
      )`);
    }

    if (skill) {
      const parameter = addValue(`%${skill}%`);
      conditions.push(`EXISTS (
        SELECT 1
        FROM student_skills filter_ss
        JOIN skills filter_sk ON filter_sk.skill_id = filter_ss.skill_id
        WHERE filter_ss.student_id = u.user_id
          AND filter_sk.name ILIKE ${parameter}
      )`);
    }

    if (universityId) {
      conditions.push(`s.university_id = ${addValue(universityId)}`);
    }

    const limitParameter = addValue(limit);
    const offsetParameter = addValue(offset);
    const result = await query(
      `${publicProfileSelect}
       WHERE ${conditions.join(' AND ')}
       ORDER BY spp.updated_at DESC NULLS LAST, u.full_name ASC
       LIMIT ${limitParameter} OFFSET ${offsetParameter}`,
      values,
    );

    return res.json({
      success: true,
      data: result.rows,
      count: result.rows.length,
      pagination: { limit, offset },
    });
  } catch (error) {
    console.error('List student directory error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to load student directory',
    });
  }
};

module.exports = {
  getOwnPublicProfile,
  updateOwnPublicProfile,
  listStudentDirectory,
};
