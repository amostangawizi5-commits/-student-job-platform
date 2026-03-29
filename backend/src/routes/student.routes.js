const express = require('express');
const router = express.Router();
const { query } = require('../config/database');
const { authMiddleware, authorize } = require('../middleware/auth.middleware');

// GET - Get student skills
router.get('/skills', authMiddleware, authorize('student', 'graduate'), async (req, res) => {
  try {
    const result = await query(
      `SELECT s.skill_id, s.name, s.category 
       FROM student_skills ss 
       JOIN skills s ON ss.skill_id = s.skill_id 
       WHERE ss.student_id = $1
       ORDER BY s.name`,
      [req.user.user_id]
    );
    res.json({ success: true, data: result.rows });
  } catch (error) {
    console.error('Error fetching student skills:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST - Add student skill
router.post('/skills', authMiddleware, authorize('student', 'graduate'), async (req, res) => {
  try {
    const { skill_id } = req.body;
    const student_id = req.user.user_id;
    
    // Check if skill already exists
    const existing = await query(
      'SELECT * FROM student_skills WHERE student_id = $1 AND skill_id = $2',
      [student_id, skill_id]
    );
    
    if (existing.rows.length > 0) {
      return res.status(400).json({ success: false, message: 'Skill already added' });
    }
    
    await query(
      'INSERT INTO student_skills (student_id, skill_id) VALUES ($1, $2)',
      [student_id, skill_id]
    );
    
    res.json({ success: true, message: 'Skill added successfully' });
  } catch (error) {
    console.error('Error adding student skill:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE - Remove student skill
router.delete('/skills/:skill_id', authMiddleware, authorize('student', 'graduate'), async (req, res) => {
  try {
    const { skill_id } = req.params;
    const student_id = req.user.user_id;
    
    await query(
      'DELETE FROM student_skills WHERE student_id = $1 AND skill_id = $2',
      [student_id, skill_id]
    );
    
    res.json({ success: true, message: 'Skill removed successfully' });
  } catch (error) {
    console.error('Error removing student skill:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET - Get student projects
router.get('/projects', authMiddleware, authorize('student', 'graduate'), async (req, res) => {
  try {
    const result = await query(
      `SELECT * FROM projects 
       WHERE student_id = $1
       ORDER BY created_at DESC`,
      [req.user.user_id]
    );
    res.json({ success: true, data: result.rows });
  } catch (error) {
    console.error('Error fetching student projects:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST - Add student project
router.post('/projects', authMiddleware, authorize('student', 'graduate'), async (req, res) => {
  try {
    const { title, description, technologies, github_link, live_demo_link } = req.body;
    const student_id = req.user.user_id;
    
    const result = await query(
      `INSERT INTO projects (student_id, title, description, technologies, github_link, live_demo_link)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [student_id, title, description, technologies || [], github_link || null, live_demo_link || null]
    );
    
    res.json({ success: true, message: 'Project added successfully', data: result.rows[0] });
  } catch (error) {
    console.error('Error adding student project:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE - Remove student project
router.delete('/projects/:project_id', authMiddleware, authorize('student', 'graduate'), async (req, res) => {
  try {
    const { project_id } = req.params;
    const student_id = req.user.user_id;
    
    await query(
      'DELETE FROM projects WHERE project_id = $1 AND student_id = $2',
      [project_id, student_id]
    );
    
    res.json({ success: true, message: 'Project removed successfully' });
  } catch (error) {
    console.error('Error removing student project:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
