const express = require('express');
const router = express.Router();
const c = require('../controllers/statisticsController');
const authMiddleware = require('../middleware/authMiddleware');

router.use(authMiddleware);

router.get('/tasks', c.getTaskStats);
router.get('/assignments', c.getAssignmentStats);
router.get('/deadlines', c.getDeadlines);

module.exports = router;