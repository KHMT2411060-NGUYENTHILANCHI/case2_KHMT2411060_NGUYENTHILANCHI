const mongoose = require('mongoose');
const Task = require('../models/task.model');
const TaskShare = require('../models/taskShare.model');
const TaskActivity = require('../models/taskActivity.model');
const Notification = require('../models/notification.model');
const {
  POPULATE,
  buildAccess,
  loadTask,
  withAccess,
  handleError,
} = require('../utils/taskAccess');
const { notify, getInvolvedUserIds } = require('../services/notificationService');
const { logActivity } = require('../services/activityService');
const { fmtDate } = require('../utils/emailTemplates');

const PRIORITY_RANK = { high: 3, medium: 2, low: 1 };
const TRACKED_FIELDS = ['title', 'description', 'startDate', 'dueDate', 'priority'];

const escapeRegex = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const timeOf = (d) => (d ? new Date(d).getTime() : null);

function checkDates(startDate, dueDate) {
  if (startDate && dueDate && new Date(dueDate) < new Date(startDate)) {
    return 'Hạn hoàn thành phải sau ngày bắt đầu';
  }
  return null;
}

// Chụp lại các trường quan trọng trước khi sửa để so sánh
function snapshot(task) {
  return {
    title: task.title,
    description: task.description,
    startDate: timeOf(task.startDate),
    dueDate: timeOf(task.dueDate),
    priority: task.priority,
    status: task.status,
  };
}

// Danh sách trường (không gồm status) đã thay đổi
function changedFields(before, task) {
  const now = snapshot(task);
  return TRACKED_FIELDS.filter((key) => before[key] !== now[key]);
}

// Thông báo khi đổi hạn hoặc hoàn thành công việc.
async function notifyChanges(task, actor, before) {
  const dueChanged = timeOf(task.dueDate) !== before.dueDate;
  const justCompleted = before.status !== 'completed' && task.status === 'completed';
  if (!dueChanged && !justCompleted) return;

  const recipients = await getInvolvedUserIds(task);

  if (dueChanged) {
    await notify({
      recipients,
      actor,
      task,
      type: 'due_date_changed',
      title: 'Hạn hoàn thành đã thay đổi',
      message: task.dueDate
        ? `${actor.fullName} đã đổi hạn hoàn thành của "${task.title}" thành ${fmtDate(task.dueDate)}`
        : `${actor.fullName} đã bỏ hạn hoàn thành của "${task.title}"`,
    });
  }

  if (justCompleted) {
    await notify({
      recipients,
      actor,
      task,
      type: 'task_completed',
      title: 'Công việc đã hoàn thành',
      message: `${actor.fullName} đã đánh dấu hoàn thành công việc "${task.title}"`,
    });
  }
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

    await logActivity({
      taskId: task._id,
      userId: req.user._id,
      action: 'created',
      details: { title: task.title },
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

// GET /api/tasks/:id/activities   -> lịch sử hoạt động
exports.getActivities = async (req, res) => {
  try {
    const found = await loadTask(req, res, 'canView');
    if (!found) return;

    const list = await TaskActivity.find({ taskId: found.task._id })
      .populate('userId', 'fullName email')
      .sort({ createdAt: -1 })
      .limit(100);
    res.json(list);
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

    const before = snapshot(task);

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

    const fields = changedFields(before, task);
    if (fields.length > 0) {
      await logActivity({
        taskId: task._id,
        userId: req.user._id,
        action: 'updated',
        details: { fields },
      });
    }
    if (before.status !== task.status) {
      await logActivity({
        taskId: task._id,
        userId: req.user._id,
        action: 'status_changed',
        details: { from: before.status, to: task.status },
      });
    }

    await notifyChanges(task, req.user, before);

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

    const before = snapshot(task);

    task.status = req.body.status;
    await task.save();

    if (before.status !== task.status) {
      await logActivity({
        taskId: task._id,
        userId: req.user._id,
        action: 'status_changed',
        details: { from: before.status, to: task.status },
      });
    }

    await notifyChanges(task, req.user, before);

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

    const taskId = found.task._id;
    await Promise.all([
      TaskShare.deleteMany({ taskId }),
      TaskActivity.deleteMany({ taskId }),
      Notification.deleteMany({ taskId }),
    ]);
    await found.task.deleteOne();
    res.json({ message: 'Đã xóa công việc' });
  } catch (err) {
    handleError(err, res);
  }
};