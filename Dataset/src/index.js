import express from 'express';
import cors from 'cors';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 4001;

app.use(cors());
app.use(express.json());

// Path to scoped prices data
const dataPath = path.join(__dirname, '../data/scoped_prices.json');

// In-memory cache of the dataset
let priceDataset = [];
let datasetVersion = {
  version: 1,
  releaseDate: '2026-06-15', // Matches latest WFP record date
  totalRecords: 0
};

// Helper to load dataset from disk
function loadDataset() {
  try {
    if (fs.existsSync(dataPath)) {
      const rawData = fs.readFileSync(dataPath, 'utf8');
      priceDataset = JSON.parse(rawData);
      
      // Calculate latest date from records
      let latestDate = '2026-06-15';
      if (priceDataset.length > 0) {
        const dates = priceDataset.map(r => r.date).filter(Boolean);
        if (dates.length > 0) {
          latestDate = dates.reduce((max, d) => d > max ? d : max, dates[0]);
        }
      }

      datasetVersion = {
        version: 1,
        releaseDate: latestDate,
        totalRecords: priceDataset.length
      };
      console.log(`Dataset loaded. Records: ${priceDataset.length}, Last Updated: ${latestDate}`);
    } else {
      console.warn(`Dataset file not found at ${dataPath}`);
      priceDataset = [];
    }
  } catch (error) {
    console.error('Failed to load dataset:', error);
  }
}

// Initial load
loadDataset();

// --- API Endpoints ---

// 1. GET /api/version
app.get('/api/version', (req, res) => {
  res.json(datasetVersion);
});

// 2. GET /api/prices
app.get('/api/prices', (req, res) => {
  // Optional filter query parameters: category, commodity
  const { category, commodity } = req.query;
  let filtered = priceDataset;

  if (category) {
    filtered = filtered.filter(item => 
      item.category.toLowerCase().includes(category.toString().toLowerCase())
    );
  }

  if (commodity) {
    filtered = filtered.filter(item => 
      item.commodity.toLowerCase().includes(commodity.toString().toLowerCase())
    );
  }

  res.json(filtered);
});

// 3. POST /api/update
// Triggers reloading the dataset from disk (for local changes or railway volume changes)
app.post('/api/update', (req, res) => {
  console.log('Update triggered, reloading dataset...');
  loadDataset();
  res.json({
    success: true,
    message: 'Dataset reloaded successfully.',
    version: datasetVersion
  });
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', time: new Date() });
});

app.listen(PORT, () => {
  console.log(`Dataset API running on port ${PORT}`);
});
