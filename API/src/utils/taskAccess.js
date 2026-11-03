const mongoose = require('mongoose');
const Task = require('../models/task.model');
const TaskShare = require('../models/taskShare.model');

const POPULATE = [
  { path: 'createdBy', select: 'fullName email' },
  { path: 'assigneeIds', select: 'fullName email' },
  { path: 'primaryAssigneeId', select: 'fullName email' },
];

// So sánh id, dùng được cho cả ObjectId lẫn document đã populate
const sameId = (a, b) => String((a && a._id) || a) === String((b && b._id) || b);

// sharePerm: 'viewer' | 'editor' | null
function buildAccess(task, userId, sharePerm) {
  const isOwner = sameId(task.createdBy, userId);
  const isAssignee = task.assigneeIds.some((u) => sameId(u, userId));
  const isEditor = sharePerm === 'editor';
  const isViewer = sharePerm === 'viewer';

  let role = null;
  if (isOwner) role = 'owner';
  else if (isEditor) role = 'editor';
  else if (isAssignee) role = 'assignee';
  else if (isViewer) role = 'viewer';

  return {
    role,
    canView: isOwner || isAssignee || isEditor || isViewer,
    canEdit: isOwner || isEditor,
    canChangeStatus: isOwner || isEditor || isAssignee,
    canDelete: isOwner,
    canManage: isOwner,
  };
}

const DENIED = {
  canView: 'Bạn không có quyền truy cập công việc này',
  canEdit: 'Bạn không có quyền sửa công việc này',
  canChangeStatus: 'Bạn không có quyền đổi trạng thái công việc này',
  canDelete: 'Chỉ người tạo mới được xóa công việc',
  canManage: 'Chỉ người tạo mới được giao việc và quản lý chia sẻ',
};

// Tìm công việc theo req.params.id và kiểm tra quyền `need`.
// Nếu không hợp lệ thì đã trả lỗi cho client và hàm trả về null.
async function loadTask(req, res, need = 'canView') {
  const { id } = req.params;
  if (!mongoose.isValidObjectId(id)) {
    res.status(400).json({ message: 'Mã công việc không hợp lệ' });
    return null;
  }

  const task = await Task.findById(id);
  if (!task) {
    res.status(404).json({ message: 'Không tìm thấy công việc' });
    return null;
  }

  const share = await TaskShare.findOne({
    taskId: task._id,
    userId: req.user._id,
  });
  const access = buildAccess(task, req.user._id, share ? share.permission : null);

  if (!access.canView) {
    res.status(403).json({ message: DENIED.canView });
    return null;
  }
  if (!access[need]) {
    res.status(403).json({ message: DENIED[need] });
    return null;
  }
  return { task, access };
}

// Thêm vai trò và quyền của người đang đăng nhập vào JSON trả về
function withAccess(task, access) {
  const obj = task.toJSON();
  obj.myRole = access.role;
  obj.permissions = {
    canEdit: access.canEdit,
    canChangeStatus: access.canChangeStatus,
    canDelete: access.canDelete,
    canManage: access.canManage,
  };
  return obj;
}

function handleError(err, res) {
  if (err.name === 'ValidationError') {
    const first = Object.values(err.errors)[0];
    return res.status(400).json({ message: first.message });
  }
  console.error(err);
  return res.status(500).json({ message: 'Lỗi máy chủ' });
}

module.exports = {
  POPULATE,
  sameId,
  buildAccess,
  loadTask,
  withAccess,
  handleError,
};