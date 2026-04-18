const AwardModel = require('../models/award.model');
function normalizeInteger(value, fallback) {
    const parsed = Number.parseInt(`${value ?? ''}`.trim(), 10);
    return Number.isNaN(parsed) ? fallback : parsed;
}

const getAwardsHome = async (req, res) => {
    try {
        const [
            featuredAward,
            companyHighlights,
            recentAnnouncements,
            leaderboard,
            wallOfFamePreview
        ] = await Promise.all([
            AwardModel.getFeaturedAward(),
            AwardModel.getCompanyHighlights(3),
            AwardModel.getRecentAnnouncements(6),
            AwardModel.getLeaderboard(8),
            AwardModel.getWallOfFame({ limit: 6 })
        ]);

        return res.json({
            success: true,
            data: {
                featured_award: featuredAward,
                company_highlights: companyHighlights,
                recent_announcements: recentAnnouncements,
                leaderboard,
                wall_of_fame_preview: wallOfFamePreview
            }
        });
    } catch (error) {
        console.error('Get awards home error:', error);
        return res.status(500).json({
            success: false,
            message: 'Failed to load awards home',
            error: error.message
        });
    }
};

const getWallOfFame = async (req, res) => {
    try {
        const limit = Math.max(1, Math.min(200, normalizeInteger(req.query?.limit, 60)));
        const awards = await AwardModel.getWallOfFame({ limit });

        return res.json({
            success: true,
            data: awards
        });
    } catch (error) {
        console.error('Get wall of fame error:', error);
        return res.status(500).json({
            success: false,
            message: 'Failed to load wall of fame',
            error: error.message
        });
    }
};

const getLeaderboard = async (req, res) => {
    try {
        const limit = Math.max(1, Math.min(100, normalizeInteger(req.query?.limit, 20)));
        const leaderboard = await AwardModel.getLeaderboard(limit);

        return res.json({
            success: true,
            data: leaderboard
        });
    } catch (error) {
        console.error('Get leaderboard error:', error);
        return res.status(500).json({
            success: false,
            message: 'Failed to load leaderboard',
            error: error.message
        });
    }
};

module.exports = {
    getAwardsHome,
    getWallOfFame,
    getLeaderboard
};
