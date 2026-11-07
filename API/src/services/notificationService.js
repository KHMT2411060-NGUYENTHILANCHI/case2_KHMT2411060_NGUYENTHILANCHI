const Notification = require('../models/notification.model');
const User = require('../models/user.model');
const TaskShare = require('../models/taskShare.model');
const { sendEmail } = require('./emailService');
const { buildEmail } = require('../utils/emailTemplates');

// Tạo thông báo trong app và gửi email cho danh sách người nhận.
// Bỏ qua chính người thao tác. Hàm này không bao giờ ném lỗi.
async function notify({ recipients, actor, task, type, title, message }) {
  try {
    const actorId = String(actor._id);
    const ids = [...new Set(recipients.map(String))].filter(
      (id) => id !== actorId
    );
    if (ids.length === 0) return;

    const users = await User.find({ _id: { $in: ids } }).select(
      'fullName email'
    );
    if (users.length === 0) return;

    await Notification.insertMany(
      users.map((u) => ({
        userId: u._id,
        taskId: task._id,
        type,
        title,
        message,
      }))
    );

    // Gửi email nền, không chờ để không làm chậm API
    const html = buildEmail({ heading: title, message, task });
    users.forEach((u) => {
      sendEmail({
        to: u.email,
        subject: `[Task Manager] ${title}`,
        html,
        taskId: task._id,
        eventType: type,
      }).catch((err) => console.error('Lỗi gửi email:', err.message));
    });
  } catch (err) {
    console.error('Lỗi tạo thông báo:', err.message);
  }
}

// Người tạo + người được giao + người được chia sẻ
async function getInvolvedUserIds(task) {
  const shares = await TaskShare.find({ taskId: task._id }).select('userId');
  return [task.createdBy, ...task.assigneeIds, ...shares.map((s) => s.userId)];
}

module.exports = { notify, getInvolvedUserIds };