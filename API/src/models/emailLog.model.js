const mongoose = require('mongoose');

const emailLogSchema = new mongoose.Schema(
  {
    taskId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Task',
      default: null,
    },
    recipientEmail: { type: String, required: true },
    eventType: { type: String, default: '' },
    subject: { type: String, default: '' },
    status: {
      type: String,
      enum: ['pending', 'sent', 'failed'],
      default: 'pending',
    },
    attempts: { type: Number, default: 0 },
    errorMessage: { type: String, default: '' },
    sentAt: { type: Date },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

module.exports = mongoose.model('EmailLog', emailLogSchema);