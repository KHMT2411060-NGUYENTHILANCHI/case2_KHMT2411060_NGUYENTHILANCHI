const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const authMiddleware = require('../middleware/authMiddleware');

router.use(authMiddleware);

router.get('/search', userController.searchUsers); // phải đặt trước '/:id'
router.get('/:id', userController.getUser);

module.exports = router;