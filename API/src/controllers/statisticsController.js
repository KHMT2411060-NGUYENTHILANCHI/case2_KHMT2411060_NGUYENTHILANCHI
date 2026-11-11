const Task = require('../models/task.model');
const TaskShare = require('../models/taskShare.model');
const { handleError } = require('../utils/taskAccess');

// Điều kiện: công việc tôi tạo, được giao hoặc được chia sẻ
async function accessibleFilter(userId) {
  const shares = await TaskShare.find({ userId }).select('taskId');
  return {
    $or: [
      { createdBy: userId },
      { assigneeIds: userId },
      { _id: { $in: shares.map((s) => s.taskId) } },
    ],
  };
}

// GET /api/statistics/tasks   -> số công việc theo trạng thái
exports.getTaskStats = async (req, res) => {
  try {
    const base = await accessibleFilter(req.user._id);
    const count = (extra = {}) => Task.countDocuments({ $and: [base, extra] });

    const [total, todo, inProgress, completed] = await Promise.all([
      count(),
      count({ status: 'todo' }),
      count({ status: 'in_progress' }),
      count({ status: 'completed' }),
    ]);

    res.json({ total, todo, in_progress: inProgress, completed });
  } catch (err) {
    handleError(err, res);
  }
};

// GET /api/statistics/assignments   -> việc được giao và việc đang phụ trách
exports.getAssignmentStats = async (req, res) => {
  try {
    const me = req.user._id;
    const notDone = { status: { $ne: 'completed' } };

    const [
      assignedToMe,
      assignedToMeActive,
      primary,
      primaryActive,
      createdByMe,
      assignedByMe,
    ] = await Promise.all([
      Task.countDocuments({ assigneeIds: me }),
      Task.countDocuments({ assigneeIds: me, ...notDone }),
      Task.countDocuments({ primaryAssigneeId: me }),
      Task.countDocuments({ primaryAssigneeId: me, ...notDone }),
      Task.countDocuments({ createdBy: me }),
      Task.countDocuments({ createdBy: me, 'assigneeIds.0': { $exists: true } }),
    ]);

    res.json({
      assignedToMe, // được giao cho tôi (tất cả)
      assignedToMeActive, // được giao cho tôi, chưa hoàn thành
      primary, // tôi là người phụ trách chính (tất cả)
      primaryActive, // tôi là người phụ trách chính, chưa hoàn thành
      createdByMe, // tôi tạo
      assignedByMe, // tôi tạo và đã giao cho người khác
    });
  } catch (err) {
    handleError(err, res);
  }
};

// GET /api/statistics/deadlines?days=7   -> việc sắp đến hạn và đã quá hạn
exports.getDeadlines = async (req, res) => {
  try {
    const days = Math.min(Math.max(parseInt(req.query.days, 10) || 7, 1), 60);

    // Hạn là ngày (không có giờ) nên việc đến hạn hôm nay vẫn tính là "sắp đến hạn"
    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);
    const limit = new Date(startOfToday.getTime() + days * 24 * 60 * 60 * 1000);

    const base = await accessibleFilter(req.user._id);
    const notDone = { status: { $ne: 'completed' } };
    const FIELDS = 'title dueDate priority status primaryAssigneeId';

    const find = (dueCond) =>
      Task.find({ $and: [base, notDone, { dueDate: dueCond }] })
        .select(FIELDS)
        .populate('primaryAssigneeId', 'fullName email')
        .sort({ dueDate: 1 })
        .limit(50);

    const [overdue, upcoming] = await Promise.all([
      find({ $lt: startOfToday }),
      find({ $gte: startOfToday, $lte: limit }),
    ]);

    res.json({ days, overdue, upcoming });
  } catch (err) {
    handleError(err, res);
  }
};