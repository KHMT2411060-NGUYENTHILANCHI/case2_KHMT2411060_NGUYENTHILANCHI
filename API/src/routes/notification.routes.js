const express = require('express');
const router = express.Router();
const c = require('../controllers/notificationController');
const authMiddleware = require('../middleware/authMiddleware');

router.use(authMiddleware);

router.get('/', c.getNotifications);
router.get('/unread-count', c.getUnreadCount);
router.patch('/read-all', c.markAllRead); // đặt trước '/:id/read'
router.patch('/:id/read', c.markRead);

module.exports = router;