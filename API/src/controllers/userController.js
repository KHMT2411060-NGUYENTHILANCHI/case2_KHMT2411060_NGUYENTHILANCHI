const mongoose = require('mongoose');
const User = require('../models/user.model');
const { handleError } = require('../utils/taskAccess');

const escapeRegex = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// GET /api/users/search?q=   (tìm theo họ tên hoặc email, bỏ qua chính mình)
exports.searchUsers = async (req, res) => {
  try {
    const q = (req.query.q || '').trim();
    if (q.length < 2) return res.json([]);

    const re = new RegExp(escapeRegex(q), 'i');
    const users = await User.find({
      _id: { $ne: req.user._id },
      $or: [{ fullName: re }, { email: re }],
    })
      .select('fullName email')
      .limit(10);

    res.json(users);
  } catch (err) {
    handleError(err, res);
  }
};

// GET /api/users/:id   (thông tin công khai)
exports.getUser = async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({ message: 'Mã người dùng không hợp lệ' });
    }
    const user = await User.findById(req.params.id).select('fullName email avatarUrl');
    if (!user) {
      return res.status(404).json({ message: 'Không tìm thấy người dùng' });
    }
    res.json(user);
  } catch (err) {
    handleError(err, res);
  }
};