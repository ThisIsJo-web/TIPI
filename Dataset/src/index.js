import express from 'express';
import cors from 'cors';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import multer from 'multer';
import * as XLSX from 'xlsx';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 4001;

app.use(cors());
app.use(express.json());

// Serve static admin Web UI
app.use(express.static(path.join(__dirname, 'public')));

// Path to scoped prices data
const dataPath = path.join(__dirname, '../data/scoped_prices.json');
const uploadDir = path.join(__dirname, '../uploads');

// Ensure directories exist
if (!fs.existsSync(path.dirname(dataPath))) {
  fs.mkdirSync(path.dirname(dataPath), { recursive: true });
}
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

// Multer upload config
const upload = multer({ dest: uploadDir });

// In-memory cache of the dataset
let priceDataset = [];
let datasetVersion = {
  version: 1,
  releaseDate: '2026-06-15',
  totalRecords: 0
};

// Helper to load dataset from disk
function loadDataset() {
  try {
    if (fs.existsSync(dataPath)) {
      const rawData = fs.readFileSync(dataPath, 'utf8');
      priceDataset = JSON.parse(rawData);
      
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

// --- Excel / CSV Parsing Helper ---
function parseSpreadsheet(filePath) {
  const workbook = XLSX.readFile(filePath);
  const sheetName = workbook.SheetNames[0];
  const sheet = workbook.Sheets[sheetName];
  
  // Convert sheet to raw 2D array of cells (header: 1)
  const rows = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: "" });
  if (rows.length === 0) return [];

  // Parse headers from the first row
  const headers = rows[0].map(h => String(h).trim().toLowerCase());
  console.log('Parsed Sheet Headers:', headers);

  // Column aliases mapping
  const columnMappings = {
    date: ['date', 'source_date'],
    admin1: ['admin1', 'region', 'region '],
    admin2: ['admin2', 'province'],
    market: ['market'],
    market_id: ['market_id', 'market id'],
    latitude: ['latitude', 'lat'],
    longitude: ['longitude', 'lon', 'lng'],
    category: ['category'],
    commodity: ['commodity', 'item'],
    unit: ['unit'],
    price: ['price', 'value']
  };

  // Find index of each mapped column
  const headerIndices = {};
  for (const [colName, aliases] of Object.entries(columnMappings)) {
    let foundIdx = -1;
    for (const alias of aliases) {
      foundIdx = headers.indexOf(alias);
      if (foundIdx !== -1) break;
    }
    headerIndices[colName] = foundIdx;
  }

  console.log('Detected Column Index Map:', headerIndices);

  const parsedRecords = [];

  // Parse remaining rows
  for (let i = 1; i < rows.length; i++) {
    const row = rows[i];
    if (row.length === 0) continue;

    const record = {};
    let hasData = false;

    for (const [colName, idx] of Object.entries(headerIndices)) {
      if (idx !== -1 && row[idx] !== undefined) {
        let val = row[idx];
        
        // Clean values
        if (colName === 'price' || colName === 'latitude' || colName === 'longitude') {
          val = parseFloat(val);
          if (isNaN(val)) val = null;
        } else if (colName === 'market_id') {
          val = parseInt(val);
          if (isNaN(val)) val = null;
        } else {
          val = String(val).trim();
        }

        record[colName] = val;
        if (val !== null && val !== '') hasData = true;
      } else {
        record[colName] = null;
      }
    }

    if (hasData) {
      parsedRecords.push(record);
    }
  }

  return parsedRecords;
}

// --- API Endpoints ---

// 1. GET /api/version
app.get('/api/version', (req, res) => {
  res.json(datasetVersion);
});

// 2. GET /api/prices
app.get('/api/prices', (req, res) => {
  const { category, commodity } = req.query;
  let filtered = priceDataset;

  if (category) {
    filtered = filtered.filter(item => 
      item.category && item.category.toLowerCase().includes(category.toString().toLowerCase())
    );
  }

  if (commodity) {
    filtered = filtered.filter(item => 
      item.commodity && item.commodity.toLowerCase().includes(commodity.toString().toLowerCase())
    );
  }

  res.json(filtered);
});

// 3. POST /api/upload
// Receives an Excel/CSV file, parses it, filters for Davao del Norte, and saves to scoped_prices.json
app.post('/api/upload', upload.single('datasetFile'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ success: false, error: 'No file uploaded.' });
  }

  const tempFilePath = req.file.path;
  console.log(`File uploaded: ${req.file.originalname} at ${tempFilePath}`);

  try {
    const rawRecords = parseSpreadsheet(tempFilePath);
    console.log(`Parsed total of ${rawRecords.length} rows.`);

    // Filter strictly for Davao del Norte
    let filteredRecords = rawRecords.filter(r => 
      r.admin2 && String(r.admin2).toLowerCase().includes('davao del norte')
    );

    // Dynamic filtering for Panabo / Tagum if they exist in the uploaded sheet
    const hasPanaboOrTagum = filteredRecords.some(r => 
      r.market && (
        String(r.market).toLowerCase().includes('panabo') || 
        String(r.market).toLowerCase().includes('tagum')
      )
    );

    if (hasPanaboOrTagum) {
      filteredRecords = filteredRecords.filter(r => 
        r.market && (
          String(r.market).toLowerCase().includes('panabo') || 
          String(r.market).toLowerCase().includes('tagum')
        )
      );
      console.log(`Filtered strictly by Panabo/Tagum. Total records: ${filteredRecords.length}`);
    } else {
      console.log(`No Panabo/Tagum specific markets found. Kept all Davao del Norte records (${filteredRecords.length}).`);
    }

    // Save to disk
    fs.writeFileSync(dataPath, JSON.stringify(filteredRecords, null, 2));

    // Clean up temporary uploaded file
    fs.unlinkSync(tempFilePath);

    // Reload memory cache
    loadDataset();

    res.json({
      success: true,
      message: 'Dataset uploaded, parsed and reloaded.',
      version: datasetVersion
    });

  } catch (error) {
    console.error('Failed to parse or save dataset:', error);
    // Ensure temp file cleanup in case of error
    if (fs.existsSync(tempFilePath)) {
      fs.unlinkSync(tempFilePath);
    }
    res.status(500).json({ success: false, error: error.message });
  }
});

// 4. POST /api/update
app.post('/api/update', (req, res) => {
  if (Array.isArray(req.body)) {
    try {
      fs.writeFileSync(dataPath, JSON.stringify(req.body, null, 2));
      console.log('New dataset array written to disk.');
    } catch (error) {
      return res.status(500).json({ success: false, error: 'Failed to write dataset to disk: ' + error.message });
    }
  } else if (req.body && Array.isArray(req.body.prices)) {
    try {
      fs.writeFileSync(dataPath, JSON.stringify(req.body.prices, null, 2));
      console.log('New dataset body.prices array written to disk.');
    } catch (error) {
      return res.status(500).json({ success: false, error: 'Failed to write dataset to disk: ' + error.message });
    }
  }

  console.log('Reloading dataset...');
  loadDataset();
  res.json({
    success: true,
    message: 'Dataset updated and reloaded successfully.',
    version: datasetVersion
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok', time: new Date() });
});

app.listen(PORT, () => {
  console.log(`Dataset API running on port ${PORT}`);
});
