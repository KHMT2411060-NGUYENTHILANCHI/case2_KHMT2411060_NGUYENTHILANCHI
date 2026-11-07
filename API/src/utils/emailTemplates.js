const PRIORITY = { low: 'Thấp', medium: 'Trung bình', high: 'Cao' };
const STATUS = {
  todo: 'Chưa thực hiện',
  in_progress: 'Đang thực hiện',
  completed: 'Đã hoàn thành',
};

const escapeHtml = (s = '') =>
  String(s).replace(
    /[&<>"']/g,
    (c) =>
      ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]
  );

const fmtDate = (d) =>
  new Date(d).toLocaleDateString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' });

function buildEmail({ heading, message, task }) {
  const rows = [
    ['Công việc', task.title],
    ['Mức ưu tiên', PRIORITY[task.priority] || task.priority],
    ['Trạng thái', STATUS[task.status] || task.status],
    ['Hạn hoàn thành', task.dueDate ? fmtDate(task.dueDate) : 'Chưa đặt'],
  ];

  const rowsHtml = rows
    .map(
      ([k, v]) =>
        `<tr>
          <td style="padding:6px 12px;color:#666;">${escapeHtml(k)}</td>
          <td style="padding:6px 12px;font-weight:600;">${escapeHtml(v)}</td>
        </tr>`
    )
    .join('');

  return `
  <div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;border:1px solid #e0e0e0;border-radius:8px;overflow:hidden;">
    <div style="background:#1976d2;color:#fff;padding:16px 20px;font-size:18px;font-weight:bold;">
      ${escapeHtml(heading)}
    </div>
    <div style="padding:20px;">
      <p style="margin-top:0;">${escapeHtml(message)}</p>
      <table style="border-collapse:collapse;width:100%;background:#f7f9fc;border-radius:6px;">
        ${rowsHtml}
      </table>
      <p style="color:#888;font-size:12px;margin-bottom:0;">
        Đây là email tự động từ ứng dụng Task Manager.
      </p>
    </div>
  </div>`;
}

module.exports = { buildEmail, fmtDate };