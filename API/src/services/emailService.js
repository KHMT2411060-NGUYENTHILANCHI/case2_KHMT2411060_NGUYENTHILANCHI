const nodemailer = require('nodemailer');
const EmailLog = require('../models/emailLog.model');

let transporter = null;

function getTransporter() {
  if (transporter) return transporter;

  const { SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS } = process.env;
  if (!SMTP_HOST || !SMTP_USER || !SMTP_PASS) return null;

  const port = Number(SMTP_PORT) || 587;
  transporter = nodemailer.createTransport({
    host: SMTP_HOST,
    port,
    secure: port === 465,
    auth: { user: SMTP_USER, pass: SMTP_PASS },
  });
  return transporter;
}

// Gửi email và lưu lịch sử (pending -> sent / failed). Không ném lỗi ra ngoài.
async function sendEmail({ to, subject, html, taskId = null, eventType = '' }) {
  const log = await EmailLog.create({
    taskId,
    recipientEmail: to,
    eventType,
    subject,
    status: 'pending',
    attempts: 0,
  });

  const mailer = getTransporter();
  if (!mailer) {
    log.status = 'failed';
    log.errorMessage = 'Chưa cấu hình SMTP';
    await log.save();
    return log;
  }

  try {
    log.attempts += 1;
    await mailer.sendMail({
      from: process.env.MAIL_FROM || process.env.SMTP_USER,
      to,
      subject,
      html,
    });
    log.status = 'sent';
    log.sentAt = new Date();
  } catch (err) {
    log.status = 'failed';
    log.errorMessage = err.message;
  }

  await log.save();
  return log;
}

module.exports = { sendEmail };