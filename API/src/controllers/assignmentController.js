const mongoose = require('mongoose');
const User = require('../models/user.model');
const { POPULATE, loadTask, handleError } = require('../utils/taskAccess');
const { notify } = require('../services/notificationService');
const { logActivity } = require('../services/activityService');

async function assigneeView(task) {
  await task.populate(POPULATE);
  return {
    assignees: task.assigneeIds,
    primaryAssignee: task.primaryAssigneeId,
  };
}

// GET /api/tasks/:id/assignees
exports.getAssignees = async (req, res) => {
  try {
    const found = await loadTask(req, res, 'canView');
    if (!found) return;
    res.json(await assigneeView(found.task));
  } catch (err) {
    handleError(err, res);
  }
};

// POST /api/tasks/:id/assignees   body: { userIds: [], primaryAssigneeId? }
exports.addAssignees = async (req, res) => {
  try {
    const found = await loadTask(req, res, 'canManage');
    if (!found) return;
    const { task } = found;

    const { userIds, primaryAssigneeId } = req.body;
    if (!Array.isArray(userIds) || userIds.length === 0) {
      return res.status(400).json({ message: 'Vui lòng chọn ít nhất một người' });
    }
    if (userIds.some((id) => !mongoose.isValidObjectId(id))) {
      return res.status(400).json({ message: 'Mã người dùng không hợp lệ' });
    }

    const uniqueIds = [...new Set(userIds.map(String))];
    const users = await User.find({ _id: { $in: uniqueIds } }).select('fullName');
    if (users.length !== uniqueIds.length) {
      return res.status(400).json({ message: 'Có người dùng không tồn tại' });
    }
    const nameOf = new Map(users.map((u) => [String(u._id), u.fullName]));

    // Chỉ những người mới được giao thì mới nhận thông báo
    const current = new Set(task.assigneeIds.map(String));
    const newIds = uniqueIds.filter((id) => !current.has(id));
    newIds.forEach((id) => task.assigneeIds.push(id));

    if (primaryAssigneeId) {
      const inList = task.assigneeIds.some(
        (u) => String(u) === String(primaryAssigneeId)
      );
      if (!inList) {
        return res.status(400).json({
          message: 'Người phụ trách chính phải nằm trong danh sách được giao',
        });
      }
      task.primaryAssigneeId = primaryAssigneeId;
    } else if (!task.primaryAssigneeId) {
      task.primaryAssigneeId = uniqueIds[0]; // mặc định người đầu tiên
    }

    await task.save();

    if (newIds.length > 0) {
      await logActivity({
        taskId: task._id,
        userId: req.user._id,
        action: 'assigned',
        details: { users: newIds.map((id) => nameOf.get(id)) },
      });

      await notify({
        recipients: newIds,
        actor: req.user,
        task,
        type: 'task_assigned',
        title: 'Bạn được giao công việc mới',
        message: `${req.user.fullName} đã giao cho bạn công việc "${task.title}"`,
      });
    }

    res.json(await assigneeView(task));
  } catch (err) {
    handleError(err, res);
  }
};

// PATCH /api/tasks/:id/assignees/:userId   -> đặt làm người phụ trách chính
exports.setPrimary = async (req, res) => {
  try {
    const found = await loadTask(req, res, 'canManage');
    if (!found) return;
    const { task } = found;

    const { userId } = req.params;
    if (!task.assigneeIds.some((u) => String(u) === userId)) {
      return res.status(400).json({ message: 'Người này chưa được giao công việc' });
    }

    if (String(task.primaryAssigneeId) !== userId) {
      task.primaryAssigneeId = userId;
      await task.save();

      const user = await User.findById(userId).select('fullName');
      await logActivity({
        taskId: task._id,
        userId: req.user._id,
        action: 'primary_changed',
        details: { user: user ? user.fullName : '' },
      });
    }

    res.json(await assigneeView(task));
  } catch (err) {
    handleError(err, res);
  }
};

// DELETE /api/tasks/:id/assignees/:userId   -> hủy giao việc
exports.removeAssignee = async (req, res) => {
  try {
    const found = await loadTask(req, res, 'canManage');
    if (!found) return;
    const { task } = found;

    const { userId } = req.params;
    if (!task.assigneeIds.some((u) => String(u) === userId)) {
      return res.status(404).json({ message: 'Người này chưa được giao công việc' });
    }

    const user = await User.findById(userId).select('fullName');

    task.assigneeIds = task.assigneeIds.filter((u) => String(u) !== userId);
    if (String(task.primaryAssigneeId) === userId) {
      task.primaryAssigneeId = task.assigneeIds[0] || null;
    }
    await task.save();

    await logActivity({
      taskId: task._id,
      userId: req.user._id,
      action: 'unassigned',
      details: { user: user ? user.fullName : '' },
    });

    res.json(await assigneeView(task));
  } catch (err) {
    handleError(err, res);
  }
};