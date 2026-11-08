const TaskActivity = require('../models/taskActivity.model');

// Ghi lịch sử hoạt động. Không bao giờ ném lỗi ra ngoài.
async function logActivity({ taskId, userId, action, details = {} }) {
  try {
    await TaskActivity.create({ taskId, userId, action, details });
  } catch (err) {
    console.error('Lỗi ghi lịch sử hoạt động:', err.message);
  }
}

module.exports = { logActivity };