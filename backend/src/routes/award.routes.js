const express = require('express');
const router = express.Router();
const awardController = require('../controllers/award.controller');

router.get('/home', awardController.getAwardsHome);
router.get('/wall-of-fame', awardController.getWallOfFame);
router.get('/leaderboard', awardController.getLeaderboard);

module.exports = router;
