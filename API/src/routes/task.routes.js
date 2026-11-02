const express = require('express');
const router = express.Router();
const taskController = require('../controllers/taskController');
const authMiddleware = require('../middleware/authMiddleware');

// Tất cả API công việc đều cần đăng nhập
router.use(authMiddleware);

router.get('/', taskController.getTasks);
router.post('/', taskController.createTask);
router.get('/:id', taskController.getTask);
router.put('/:id', taskController.updateTask);
router.patch('/:id/status', taskController.updateStatus);
router.delete('/:id', taskController.deleteTask);

module.exports = router;