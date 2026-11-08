const mongoose = require('mongoose');
const User = require('../models/user.model');
const TaskShare = require('../models/taskShare.model');
const { sameId, loadTask, handleError } = require('../utils/taskAccess');
const { notify } = require('../services/notificationService');
const { logActivity } = require('../services/activityService');

const PERMISSIONS = ['viewer', 'editor'];

function listShares(taskId) {
  return TaskShare.find({ taskId })
    .populate('userId', 'fullName email')
    .populate('sharedBy', 'fullName email')
    .sort({ createdAt: 1 });
}

// GET /api/tasks/:id/shares
exports.getShares = async (req, res) => {
  try {
    const found = await loadTask(req, res, 'canView');
    if (!found) return;
    res.json(await listShares(found.task._id));
  } catch (err) {
    handleError(err, res);
  }
};

// POST /api/tasks/:id/shares   body: { userIds: [], permission: 'viewer' | 'editor' }
exports.addShares = async (req, res) => {
  try {
    const found = await loadTask(req, res, 'canManage');
    if (!found) return;
    const { task } = found;

    const { userIds, permission = 'viewer' } = req.body;
    if (!PERMISSIONS.includes(permission)) {
      return res.status(400).json({ message: 'Quyền phải là viewer hoặc editor' });
    }
    if (!Array.isArray(userIds) || userIds.length === 0) {
      return res.status(400).json({ message: 'Vui lòng chọn ít nhất một người' });
    }
    if (userIds.some((id) => !mongoose.isValidObjectId(id))) {
      return res.status(400).json({ message: 'Mã người dùng không hợp lệ' });
    }

    // Không chia sẻ cho chính người tạo
    const targets = [...new Set(userIds.map(String))].filter(
      (id) => !sameId(task.createdBy, id)
    );
    if (targets.length === 0) {
      return res
        .status(400)
        .json({ message: 'Không thể chia sẻ công việc cho người tạo' });
    }

    const users = await User.find({ _id: { $in: targets } }).select('fullName');
    if (users.length !== targets.length) {
      return res.status(400).json({ message: 'Có người dùng không tồn tại' });
    }
    const nameOf = new Map(users.map((u) => [String(u._id), u.fullName]));

    // Xác định ai mới được chia sẻ (để gửi thông báo)
    const existing = await TaskShare.find({
      taskId: task._id,
      userId: { $in: targets },
    }).select('userId');
    const existingIds = new Set(existing.map((s) => String(s.userId)));
    const newTargets = targets.filter((id) => !existingIds.has(id));

    // Đã chia sẻ rồi thì chỉ cập nhật quyền
    for (const userId of targets) {
      await TaskShare.findOneAndUpdate(
        { taskId: task._id, userId },
        { permission, sharedBy: req.user._id },
        { upsert: true, new: true, setDefaultsOnInsert: true }
      );
    }

    if (newTargets.length > 0) {
      await logActivity({
        taskId: task._id,
        userId: req.user._id,
        action: 'shared',
        details: { users: newTargets.map((id) => nameOf.get(id)), permission },
      });

      const permText = permission === 'editor' ? 'chỉnh sửa' : 'chỉ xem';
      await notify({
        recipients: newTargets,
        actor: req.user,
        task,
        type: 'task_shared',
        title: 'Bạn được mời tham gia công việc',
        message: `${req.user.fullName} đã chia sẻ công việc "${task.title}" cho bạn với quyền ${permText}`,
      });
    }

    res.status(201).json(await listShares(task._id));
  } catch (err) {
    handleError(err, res);
  }
};

// PATCH /api/tasks/:id/shares/:shareId   body: { permission }
exports.updateShare = async (req, res) => {
  try {
    const found = await loadTask(req, res, 'canManage');
    if (!found) return;

    const { shareId } = req.params;
    const { permission } = req.body;
    if (!PERMISSIONS.includes(permission)) {
      return res.status(400).json({ message: 'Quyền phải là viewer hoặc editor' });
    }
    if (!mongoose.isValidObjectId(shareId)) {
      return res.status(400).json({ message: 'Mã chia sẻ không hợp lệ' });
    }

    const share = await TaskShare.findOneAndUpdate(
      { _id: shareId, taskId: found.task._id },
      { permission },
      { new: true }
    ).populate('userId', 'fullName');
    if (!share) {
      return res.status(404).json({ message: 'Không tìm thấy bản ghi chia sẻ' });
    }

    await logActivity({
      taskId: found.task._id,
      userId: req.user._id,
      action: 'share_updated',
      details: {
        user: share.userId ? share.userId.fullName : '',
        permission,
      },
    });

    res.json(await listShares(found.task._id));
  } catch (err) {
    handleError(err, res);
  }
};

// DELETE /api/tasks/:id/shares/:shareId   -> thu hồi quyền
exports.deleteShare = async (req, res) => {
  try {
    const found = await loadTask(req, res, 'canManage');
    if (!found) return;

    const { shareId } = req.params;
    if (!mongoose.isValidObjectId(shareId)) {
      return res.status(400).json({ message: 'Mã chia sẻ không hợp lệ' });
    }

    const share = await TaskShare.findOneAndDelete({
      _id: shareId,
      taskId: found.task._id,
    }).populate('userId', 'fullName');
    if (!share) {
      return res.status(404).json({ message: 'Không tìm thấy bản ghi chia sẻ' });
    }

    await logActivity({
      taskId: found.task._id,
      userId: req.user._id,
      action: 'share_revoked',
      details: { user: share.userId ? share.userId.fullName : '' },
    });

    res.json(await listShares(found.task._id));
  } catch (err) {
    handleError(err, res);
  }
};