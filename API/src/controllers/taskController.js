const mongoose = require('mongoose');
const Task = require('../models/task.model');
const TaskShare = require('../models/taskShare.model');
const {
  POPULATE,
  buildAccess,
  loadTask,
  withAccess,
  handleError,
} = require('../utils/taskAccess');

const PRIORITY_RANK = { high: 3, medium: 2, low: 1 };

const escapeRegex = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

function checkDates(startDate, dueDate) {
  if (startDate && dueDate && new Date(dueDate) < new Date(startDate)) {
    return 'Hạn hoàn thành phải sau ngày bắt đầu';
  }
  return null;
}

// GET /api/tasks?scope=created|assigned|shared&status=&priority=&q=&assigneeId=&sortBy=&order=
exports.getTasks = async (req, res) => {
  try {
    const {
      scope,
      status,
      priority,
      q,
      assigneeId,
      sortBy = 'createdAt',
      order = 'desc',
    } = req.query;
    const me = req.user._id;

    // Các công việc được chia sẻ cho tôi
    const shares = await TaskShare.find({ userId: me }).select('taskId permission');
    const shareMap = new Map(shares.map((s) => [String(s.taskId), s.permission]));
    const sharedIds = shares.map((s) => s.taskId);

    let scopeCond;
    if (scope === 'created') scopeCond = { createdBy: me };
    else if (scope === 'assigned') scopeCond = { assigneeIds: me };
    else if (scope === 'shared') scopeCond = { _id: { $in: sharedIds } };
    else {
      scopeCond = {
        $or: [
          { createdBy: me },
          { assigneeIds: me },
          { _id: { $in: sharedIds } },
        ],
      };
    }

    const conds = [scopeCond];
    if (status) conds.push({ status });
    if (priority) conds.push({ priority });
    if (q) conds.push({ title: { $regex: escapeRegex(q), $options: 'i' } });
    if (assigneeId && mongoose.isValidObjectId(assigneeId)) {
      conds.push({ assigneeIds: assigneeId });
    }

    const dir = order === 'asc' ? 1 : -1;
    let query = Task.find({ $and: conds }).populate(POPULATE);
    if (sortBy !== 'priority') {
      const field = sortBy === 'dueDate' ? 'dueDate' : 'createdAt';
      query = query.sort({ [field]: dir });
    }
    const tasks = await query;

    if (sortBy === 'priority') {
      tasks.sort(
        (a, b) => dir * (PRIORITY_RANK[a.priority] - PRIORITY_RANK[b.priority])
      );
    }

    res.json(
      tasks.map((t) =>
        withAccess(t, buildAccess(t, me, shareMap.get(String(t._id)) || null))
      )
    );
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
    const access = buildAccess(task, req.user._id, null);
    await task.populate(POPULATE);
    res.status(201).json(withAccess(task, access));
  } catch (err) {
    handleError(err, res);
  }
};

// GET /api/tasks/:id
exports.getTask = async (req, res) => {
  try {
    const found = await loadTask(req, res, 'canView');
    if (!found) return;
    await found.task.populate(POPULATE);
    res.json(withAccess(found.task, found.access));
  } catch (err) {
    handleError(err, res);
  }
};

// PUT /api/tasks/:id  (người tạo hoặc editor)
exports.updateTask = async (req, res) => {
  try {
    const found = await loadTask(req, res, 'canEdit');
    if (!found) return;
    const { task, access } = found;

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
    res.json(withAccess(task, access));
  } catch (err) {
    handleError(err, res);
  }
};

// PATCH /api/tasks/:id/status  (người tạo, editor hoặc người được giao)
exports.updateStatus = async (req, res) => {
  try {
    const found = await loadTask(req, res, 'canChangeStatus');
    if (!found) return;
    const { task, access } = found;

    task.status = req.body.status;
    await task.save();
    await task.populate(POPULATE);
    res.json(withAccess(task, access));
  } catch (err) {
    handleError(err, res);
  }
};

// DELETE /api/tasks/:id  (chỉ người tạo)
exports.deleteTask = async (req, res) => {
  try {
    const found = await loadTask(req, res, 'canDelete');
    if (!found) return;

    await TaskShare.deleteMany({ taskId: found.task._id });
    await found.task.deleteOne();
    res.json({ message: 'Đã xóa công việc' });
  } catch (err) {
    handleError(err, res);
  }
};