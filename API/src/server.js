const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();

const app = express();

app.use(cors());
app.use(express.json());

// Kết nối MongoDB (Sửa MONGO_URI thành MONGODB_URI)
mongoose
  .connect(process.env.MONGODB_URI)
  .then(() => console.log('MongoDB connected'))
  .catch((error) => console.error('MongoDB connection error:', error));

// Route kiểm tra
app.get('/', (req, res) => {
  res.json({ message: 'Task Manager API is running' });
});

// Route chính cho Task
app.use('/api/tasks', require('./routes/task.routes'));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});