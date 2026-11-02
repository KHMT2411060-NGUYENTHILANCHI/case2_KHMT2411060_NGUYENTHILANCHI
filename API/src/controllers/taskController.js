const mongoose = require('mongoose');
const Task = require('../models/task.model');

const POPULATE = [
  { path: 'createdBy', select: 'fullName email' },
  { path: 'assigneeIds', select: 'fullName email' },
  { path: 'primaryAssigneeId', select: 'fullName email' },
];

const PRIORITY_RANK = { high: 3, medium: 2, low: 1 };

const escapeRegex = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const isCreator = (task, userId) => task.createdBy.equals(userId);
const isAssignee = (task, userId) =>
  task.assigneeIds.some((id) => id.equals(userId));

// Tìm công việc theo id và kiểm tra quyền truy cập.
// (Phần C sẽ bổ sung thêm quyền của người được chia sẻ)
async function findAccessibleTask(req, res) {
  if (!mongoose.isValidObjectId(req.params.id)) {
    res.status(400).json({ message: 'Mã công việc không hợp lệ' });
    return null;
  }
  const task = await Task.findById(req.params.id);
  if (!task) {
    res.status(404).json({ message: 'Không tìm thấy công việc' });
    return null;
  }
  const uid = req.user._id;
  if (!isCreator(task, uid) && !isAssignee(task, uid)) {
    res.status(403).json({ message: 'Bạn không có quyền truy cập công việc này' });
    return null;
  }
  return task;
}

function handleError(err, res) {
  if (err.name === 'ValidationError') {
    const first = Object.values(err.errors)[0];
    return res.status(400).json({ message: first.message });
  }
  console.error(err);
  return res.status(500).json({ message: 'Lỗi máy chủ' });
}

function checkDates(startDate, dueDate) {
  if (startDate && dueDate && new Date(dueDate) < new Date(startDate)) {
    return 'Hạn hoàn thành phải sau ngày bắt đầu';
  }
  return null;
}

// GET /api/tasks?scope=created|assigned&status=&priority=&q=&sortBy=&order=
exports.getTasks = async (req, res) => {
  try {
    const { scope, status, priority, q, sortBy = 'createdAt', order = 'desc' } = req.query;
    const me = req.user._id;

    const filter =
      scope === 'created'
        ? { createdBy: me }
        : scope === 'assigned'
        ? { assigneeIds: me }
        : { $or: [{ createdBy: me }, { assigneeIds: me }] };

    if (status) filter.status = status;
    if (priority) filter.priority = priority;
    if (q) filter.title = { $regex: escapeRegex(q), $options: 'i' };

    const dir = order === 'asc' ? 1 : -1;
    let query = Task.find(filter).populate(POPULATE);
    if (sortBy !== 'priority') {
      const field = sortBy === 'dueDate' ? 'dueDate' : 'createdAt';
      query = query.sort({ [field]: dir });
    }
    let tasks = await query;

    if (sortBy === 'priority') {
      tasks.sort((a, b) => dir * (PRIORITY_RANK[a.priority] - PRIORITY_RANK[b.priority]));
    }
    res.json(tasks);
  } catch (err) {
    handleError(err, res);
  }
};

// POST /api/tasks
exports.createTask = async (req, res) => {
  try {
    const { title, description, startDate, dueDate, priority, status } = req.body;
    if (!title || !title.trim()) {
      return res.status(400).json({ message: 'Tên công việc là bắt buộc' });
    }
    const dateError = checkDates(startDate, dueDate);
    if (dateError) return res.status(400).json({ message: dateError });

    const task = await Task.create({
      title,
      description,
      startDate,
      dueDate,
      priority,
      status,
      createdBy: req.user._id,
    });
    await task.populate(POPULATE);
    res.status(201).json(task);
  } catch (err) {
    handleError(err, res);
  }
};

// GET /api/tasks/:id
exports.getTask = async (req, res) => {
  try {
    const task = await findAccessibleTask(req, res);
    if (!task) return;
    await task.populate(POPULATE);
    res.json(task);
  } catch (err) {
    handleError(err, res);
  }
};

// PUT /api/tasks/:id  (chỉ người tạo)
exports.updateTask = async (req, res) => {
  try {
    const task = await findAccessibleTask(req, res);
    if (!task) return;
    if (!isCreator(task, req.user._id)) {
      return res.status(403).json({ message: 'Chỉ người tạo mới được sửa công việc' });
    }

    const { title, description, startDate, dueDate, priority, status } = req.body;
    if (title !== undefined) {
      if (!title.trim()) {
        return res.status(400).json({ message: 'Tên công việc không được để trống' });
      }
      task.title = title;
    }
    if (description !== undefined) task.description = description;
    if (startDate !== undefined) task.startDate = startDate || null;
    if (dueDate !== undefined) task.dueDate = dueDate || null;
    if (priority !== undefined) task.priority = priority;
    if (status !== undefined) task.status = status;

    const dateError = checkDates(task.startDate, task.dueDate);
    if (dateError) return res.status(400).json({ message: dateError });

    await task.save();
    await task.populate(POPULATE);
    res.json(task);
  } catch (err) {
    handleError(err, res);
  }
};

// PATCH /api/tasks/:id/status  (người tạo hoặc người được giao)
exports.updateStatus = async (req, res) => {
  try {
    const task = await findAccessibleTask(req, res);
    if (!task) return;
    task.status = req.body.status;
    await task.save();
    await task.populate(POPULATE);
    res.json(task);
  } catch (err) {
    handleError(err, res);
  }
};

// DELETE /api/tasks/:id  (chỉ người tạo)
exports.deleteTask = async (req, res) => {
  try {
    const task = await findAccessibleTask(req, res);
    if (!task) return;
    if (!isCreator(task, req.user._id)) {
      return res.status(403).json({ message: 'Chỉ người tạo mới được xóa công việc' });
    }
    await task.deleteOne();
    res.json({ message: 'Đã xóa công việc' });
  } catch (err) {
    handleError(err, res);
  }
};