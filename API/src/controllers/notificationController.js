const mongoose = require('mongoose');
const Notification = require('../models/notification.model');
const { handleError } = require('../utils/taskAccess');

// GET /api/notifications?unread=true
exports.getNotifications = async (req, res) => {
  try {
    const filter = { userId: req.user._id };
    if (req.query.unread === 'true') filter.isRead = false;

    const list = await Notification.find(filter)
      .sort({ createdAt: -1 })
      .limit(100);
    res.json(list);
  } catch (err) {
    handleError(err, res);
  }
};

// GET /api/notifications/unread-count
exports.getUnreadCount = async (req, res) => {
  try {
    const count = await Notification.countDocuments({
      userId: req.user._id,
      isRead: false,
    });
    res.json({ count });
  } catch (err) {
    handleError(err, res);
  }
};

// PATCH /api/notifications/:id/read
exports.markRead = async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({ message: 'Mã thông báo không hợp lệ' });
    }
    const n = await Notification.findOneAndUpdate(
      { _id: req.params.id, userId: req.user._id },
      { isRead: true },
      { new: true }
    );
    if (!n) {
      return res.status(404).json({ message: 'Không tìm thấy thông báo' });
    }
    res.json(n);
  } catch (err) {
    handleError(err, res);
  }
};

// PATCH /api/notifications/read-all
exports.markAllRead = async (req, res) => {
  try {
    await Notification.updateMany(
      { userId: req.user._id, isRead: false },
      { isRead: true }
    );
    res.json({ message: 'Đã đánh dấu tất cả là đã đọc' });
  } catch (err) {
    handleError(err, res);
  }
};