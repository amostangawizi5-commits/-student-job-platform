const express = require('express');
const router = express.Router();
const { query } = require('../config/database');
const { authMiddleware, authorize } = require('../middleware/auth.middleware');

console.log('📁 PROJECT ROUTES DB VERSION LOADED');

const normalizeTechnologies = (technologies) => {
  if (Array.isArray(technologies)) return technologies;
  if (typeof technologies === 'string' && technologies.trim().length > 0) {
    return technologies
      .split(',')
      .map((item) => item.trim())
      .filter((item) => item.length > 0);
  }
  return [];
};

// Simple health route
router.get('/test', (req, res) => {
  res.json({ success: true, message: 'Project routes DB version working!' });
});

// Get student projects
router.get('/student', authMiddleware, authorize('student', ''), async (req, res) => {
  try {
    const result = await query(
      `SELECT project_id, student_id, title, description, technologies, github_link, live_demo_link, image_url, created_at, updated_at
       FROM projects
       WHERE student_id = $1
       ORDER BY created_at DESC`,
      [req.user.user_id]
    );

    res.json({ success: true, data: result.rows });
  } catch (error) {
    console.error('Error fetching projects:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch projects', error: error.message });
  }
});

// Add project
router.post('/student', authMiddleware, authorize('student', ''), async (req, res) => {
  try {
    const { title, description, technologies, github_link, live_demo_link } = req.body;

    if (!title || String(title).trim().length === 0) {
      return res.status(400).json({ success: false, message: 'Project title is required' });
    }

    const result = await query(
      `INSERT INTO projects (student_id, title, description, technologies, github_link, live_demo_link)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING project_id, student_id, title, description, technologies, github_link, live_demo_link, image_url, created_at, updated_at`,
      [
        req.user.user_id,
        String(title).trim(),
        description ? String(description).trim() : null,
        normalizeTechnologies(technologies),
        github_link || null,
        live_demo_link || null,
      ]
    );

    res.status(201).json({
      success: true,
      message: 'Project added successfully',
      data: result.rows[0],
    });
  } catch (error) {
    console.error('Error adding project:', error);
    res.status(500).json({ success: false, message: 'Failed to add project', error: error.message });
  }
});

// Delete project
router.delete('/student/:project_id', authMiddleware, authorize('student', ''), async (req, res) => {
  try {
    const { project_id } = req.params;

    const result = await query(
      `DELETE FROM projects
       WHERE project_id = $1 AND student_id = $2
       RETURNING project_id`,
      [project_id, req.user.user_id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Project not found' });
    }

    res.json({ success: true, message: 'Project removed successfully' });
  } catch (error) {
    console.error('Error deleting project:', error);
    res.status(500).json({ success: false, message: 'Failed to delete project', error: error.message });
  }
});

module.exports = router;
