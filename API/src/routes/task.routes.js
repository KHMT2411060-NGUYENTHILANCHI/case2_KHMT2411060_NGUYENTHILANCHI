const express = require('express');
const router = express.Router();
const taskController = require('../controllers/taskController');
const assignment = require('../controllers/assignmentController');
const share = require('../controllers/taskShareController');
const authMiddleware = require('../middleware/authMiddleware');

// Tất cả API công việc đều cần đăng nhập
router.use(authMiddleware);

// Công việc
router.get('/', taskController.getTasks);
router.post('/', taskController.createTask);
router.get('/:id', taskController.getTask);
router.put('/:id', taskController.updateTask);
router.patch('/:id/status', taskController.updateStatus);
router.delete('/:id', taskController.deleteTask);

// Giao việc
router.get('/:id/assignees', assignment.getAssignees);
router.post('/:id/assignees', assignment.addAssignees);
router.patch('/:id/assignees/:userId', assignment.setPrimary);
router.delete('/:id/assignees/:userId', assignment.removeAssignee);

// Chia sẻ và phân quyền
router.get('/:id/shares', share.getShares);
router.post('/:id/shares', share.addShares);
router.patch('/:id/shares/:shareId', share.updateShare);
router.delete('/:id/shares/:shareId', share.deleteShare);

module.exports = router;