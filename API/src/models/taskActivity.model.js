const mongoose = require('mongoose');

const taskActivitySchema = new mongoose.Schema(
  {
    taskId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Task',
      required: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    // created | updated | status_changed | assigned | unassigned |
    // primary_changed | shared | share_updated | share_revoked
    action: { type: String, required: true },
    details: { type: mongoose.Schema.Types.Mixed, default: {} },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

taskActivitySchema.index({ taskId: 1, createdAt: -1 });

module.exports = mongoose.model('TaskActivity', taskActivitySchema);