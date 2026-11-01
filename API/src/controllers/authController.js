const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const User = require('../models/user.model');

const signToken = (user) =>
  jwt.sign({ id: user._id }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  });

const isEmail = (s) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s);

// POST /api/auth/register
exports.register = async (req, res) => {
  try {
    const { fullName, email, password } = req.body;
    if (!fullName?.trim() || !email || !password) {
      return res.status(400).json({ message: 'Vui lòng nhập họ tên, email và mật khẩu' });
    }
    if (!isEmail(email)) {
      return res.status(400).json({ message: 'Email không hợp lệ' });
    }
    if (password.length < 6) {
      return res.status(400).json({ message: 'Mật khẩu tối thiểu 6 ký tự' });
    }
    const exists = await User.findOne({ email: email.toLowerCase().trim() });
    if (exists) {
      return res.status(409).json({ message: 'Email đã được sử dụng' });
    }
    const passwordHash = await bcrypt.hash(password, 10);
    const user = await User.create({ fullName, email, passwordHash });
    res.status(201).json({ token: signToken(user), user });
  } catch (err) {
    res.status(500).json({ message: 'Lỗi máy chủ' });
  }
};

// POST /api/auth/login
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ message: 'Vui lòng nhập email và mật khẩu' });
    }
    const user = await User.findOne({ email: email.toLowerCase().trim() });
    const ok = user && (await bcrypt.compare(password, user.passwordHash));
    if (!ok) {
      return res.status(401).json({ message: 'Email hoặc mật khẩu không đúng' });
    }
    res.json({ token: signToken(user), user });
  } catch (err) {
    res.status(500).json({ message: 'Lỗi máy chủ' });
  }
};

// GET /api/auth/me
exports.getMe = (req, res) => {
  res.json(req.user);
};

// PUT /api/auth/me
exports.updateMe = async (req, res) => {
  try {
    const { fullName, avatarUrl } = req.body;
    if (fullName !== undefined) {
      if (!fullName.trim()) {
        return res.status(400).json({ message: 'Họ tên không được để trống' });
      }
      req.user.fullName = fullName.trim();
    }
    if (avatarUrl !== undefined) req.user.avatarUrl = avatarUrl;
    await req.user.save();
    res.json(req.user);
  } catch (err) {
    res.status(500).json({ message: 'Lỗi máy chủ' });
  }
};

// PUT /api/auth/change-password
exports.changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ message: 'Vui lòng nhập mật khẩu hiện tại và mật khẩu mới' });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({ message: 'Mật khẩu mới tối thiểu 6 ký tự' });
    }
    const ok = await bcrypt.compare(currentPassword, req.user.passwordHash);
    if (!ok) {
      return res.status(400).json({ message: 'Mật khẩu hiện tại không đúng' });
    }
    req.user.passwordHash = await bcrypt.hash(newPassword, 10);
    await req.user.save();
    res.json({ message: 'Đổi mật khẩu thành công' });
  } catch (err) {
    res.status(500).json({ message: 'Lỗi máy chủ' });
  }
};