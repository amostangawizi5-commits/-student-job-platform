// src/controllers/skill.controller.js
const { query } = require('../config/database');

// Get trending skills based on job postings frequency
const getTrendingSkills = async (req, res) => {
    try {
        const { limit = 10 } = req.query;
        
        const result = await query(
            `SELECT 
                s.skill_id,
                s.name,
                s.category,
                COUNT(js.job_id) as job_count
            FROM skills s
            JOIN job_skills js ON s.skill_id = js.skill_id
            GROUP BY s.skill_id, s.name, s.category
            ORDER BY job_count DESC, s.name ASC
            LIMIT $1`,
            [limit]
        );
        
        res.json({
            success: true,
            data: result.rows,
            message: 'Trending skills based on job postings'
        });
    } catch (error) {
        console.error('Get trending skills error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch trending skills',
            error: error.message
        });
    }
};

// Get all skills
const getAllSkills = async (req, res) => {
    try {
        const result = await query(
            'SELECT skill_id, name, category FROM skills ORDER BY name'
        );
        
        res.json({
            success: true,
            data: result.rows
        });
    } catch (error) {
        console.error('Get all skills error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch skills',
            error: error.message
        });
    }
};

// Get skill match for a student
const getSkillMatch = async (req, res) => {
    try {
        const studentId = req.user.user_id;
        
        // Get student's skills
        const studentSkills = await query(
            `SELECT s.skill_id, s.name 
             FROM student_skills ss
             JOIN skills s ON ss.skill_id = s.skill_id
             WHERE ss.student_id = $1`,
            [studentId]
        );
        
        // Get top required skills from jobs
        const topJobSkills = await query(
            `SELECT s.skill_id, s.name, COUNT(js.job_id) as demand_count
             FROM job_skills js
             JOIN skills s ON js.skill_id = s.skill_id
             GROUP BY s.skill_id, s.name
             ORDER BY demand_count DESC
             LIMIT 10`
        );
        
        const studentSkillIds = studentSkills.rows.map(s => s.skill_id);
        
        const recommendedSkills = topJobSkills.rows.filter(
            skill => !studentSkillIds.includes(skill.skill_id)
        );
        
        res.json({
            success: true,
            data: {
                student_skills: studentSkills.rows,
                trending_skills: topJobSkills.rows,
                recommended_skills: recommendedSkills,
                match_percentage: studentSkills.rows.length > 0 
                    ? Math.min(100, Math.round((studentSkills.rows.length / topJobSkills.rows.length) * 100))
                    : 0
            }
        });
    } catch (error) {
        console.error('Get skill match error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch skill match',
            error: error.message
        });
    }
};

module.exports = {
    getTrendingSkills,
    getAllSkills,
    getSkillMatch
};
