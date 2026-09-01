const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const MONGO_URI = process.env.MONGO_URI || 'mongodb://root:examplepassword@localhost:27017/uart?authSource=admin';

mongoose.connect(MONGO_URI, { useNewUrlParser: true, useUnifiedTopology: true })
  .then(() => console.log('MongoDB Connected successfully'))
  .catch(err => console.error('MongoDB connection error:', err));

// Flexible Performance Schema
const performanceSchema = new mongoose.Schema({
  id: { type: String, unique: true, index: true },
  kopisId: { type: String, sparse: true, index: true },
  title: { type: String, required: true, index: true },
  normTitle: { type: String, index: true },
  startDate: { type: String, index: true },
  endDate: { type: String, index: true },
  venue: { type: String, index: true },
  posterUrl: String,
  genre: String,
  price: String,
  state: String,
  source: String, // "KOPIS" or "CRAWLED"
  bookingLinks: [{ name: String, url: String }],
  updatedAt: { type: Date, default: Date.now }
}, { strict: false });

const Performance = mongoose.model('Performance', performanceSchema);

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// API Endpoint to get all performances with optional filtering
app.get('/api/performances', async (req, res) => {
  try {
    const { genre, venue, q, stdate, eddate, district } = req.query;
    const filter = {};

    if (genre && genre !== '전체') {
      filter.genre = { $regex: genre, $options: 'i' };
    }

    if (venue) {
      filter.venue = { $regex: venue, $options: 'i' };
    }
    
    if (district && district !== '전체') {
      filter.district = { $regex: district, $options: 'i' };
    }

    if (q) {
      filter.$or = [
        { title: { $regex: q, $options: 'i' } },
        { venue: { $regex: q, $options: 'i' } }
      ];
    }

    if (stdate && eddate) {
      filter.endDate = { $gte: stdate };
      filter.startDate = { $lte: eddate };
    }

    const performances = await Performance.find(filter).sort({ startDate: 1 });
    res.json(performances);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// API Endpoint for single performance detail
app.get('/api/performances/:id', async (req, res) => {
  try {
    const perf = await Performance.findOne({ 
      $or: [{ id: req.params.id }, { kopisId: req.params.id }] 
    });
    if (!perf) {
      return res.status(404).json({ error: 'Performance not found' });
    }
    res.json(perf);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`U-Art API Server running on port ${PORT}`));
