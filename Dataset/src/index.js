import express from 'express';
import cors from 'cors';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import multer from 'multer';
import XLSX from 'xlsx';
import readline from 'readline';

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

// --- CSV Helper: Splits a CSV line correctly handling quotes and commas ---
function splitCsvLine(line) {
  const result = [];
  let current = '';
  let inQuotes = false;
  
  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    if (char === '"') {
      inQuotes = !inQuotes;
    } else if (char === ',' && !inQuotes) {
      result.push(current.trim());
      current = '';
    } else {
      current += char;
    }
  }
  result.push(current.trim());
  return result;
}

// --- Dynamic Column Mapper Helper ---
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

function getColumnIndices(headers) {
  const headerIndices = {};
  for (const [colName, aliases] of Object.entries(columnMappings)) {
    let foundIdx = -1;
    for (const alias of aliases) {
      foundIdx = headers.indexOf(alias);
      if (foundIdx !== -1) break;
    }
    headerIndices[colName] = foundIdx;
  }
  return headerIndices;
}

// --- Stream-based CSV Parser (Low Memory, early filtering) ---
async function parseCsvStream(filePath) {
  const fileStream = fs.createReadStream(filePath);
  const rl = readline.createInterface({
    input: fileStream,
    crlfDelay: Infinity
  });

  let headers = [];
  let headerIndices = {};
  const parsedRecords = [];
  let lineCount = 0;

  for await (const line of rl) {
    const row = splitCsvLine(line);
    if (row.length === 0 || row.join('') === '') continue;

    if (lineCount === 0) {
      headers = row.map(h => h.trim().toLowerCase());
      console.log('Parsed CSV Headers:', headers);
      headerIndices = getColumnIndices(headers);
      console.log('Detected Column Index Map:', headerIndices);
    } else {
      // Early Filtering: Check if admin2 (province) matches 'davao del norte'
      // This saves HUGE amounts of memory by skipping objects we don't need!
      const admin2Idx = headerIndices['admin2'];
      if (admin2Idx !== -1 && row[admin2Idx]) {
        const province = row[admin2Idx].toLowerCase();
        if (!province.includes('davao del norte')) {
          lineCount++;
          continue;
        }
      }

      const record = {};
      let hasData = false;

      for (const [colName, idx] of Object.entries(headerIndices)) {
        if (idx !== -1 && row[idx] !== undefined) {
          let val = row[idx];
          
          if (colName === 'price' || colName === 'latitude' || colName === 'longitude') {
            val = parseFloat(val);
            if (isNaN(val)) val = null;
          } else if (colName === 'market_id') {
            val = parseInt(val);
            if (isNaN(val)) val = null;
          } else {
            if (val.startsWith('"') && val.endsWith('"')) {
              val = val.substring(1, val.length - 1);
            }
            val = val.trim();
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
    lineCount++;
  }

  return parsedRecords;
}

// --- Memory-based Excel Parser (Fallback for .xlsx) ---
function parseExcelFile(filePath) {
  const workbook = XLSX.readFile(filePath);
  const sheetName = workbook.SheetNames[0];
  const sheet = workbook.Sheets[sheetName];
  
  const rows = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: "" });
  if (rows.length === 0) return [];

  const headers = rows[0].map(h => String(h).trim().toLowerCase());
  const headerIndices = getColumnIndices(headers);

  const parsedRecords = [];

  for (let i = 1; i < rows.length; i++) {
    const row = rows[i];
    if (row.length === 0) continue;

    const record = {};
    let hasData = false;

    for (const [colName, idx] of Object.entries(headerIndices)) {
      if (idx !== -1 && row[idx] !== undefined) {
        let val = row[idx];
        
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
// Receives Excel/CSV, parses streamingly if CSV to prevent Heap Limit Out of Memory errors
app.post('/api/upload', upload.single('datasetFile'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ success: false, error: 'No file uploaded.' });
  }

  const tempFilePath = req.file.path;
  const originalName = req.file.originalname.toLowerCase();
  console.log(`File uploaded: ${req.file.originalname} at ${tempFilePath}`);

  try {
    let rawRecords = [];
    const isCsv = originalName.endsWith('.csv');

    if (isCsv) {
      console.log('Streaming CSV line-by-line...');
      rawRecords = await parseCsvStream(tempFilePath);
    } else {
      console.log('Reading Excel file in-memory...');
      rawRecords = parseExcelFile(tempFilePath);
    }

    console.log(`Parsed total of ${rawRecords.length} records matching scope.`);

    // Filter strictly for Davao del Norte
    let filteredRecords = rawRecords.filter(r => 
      r.admin2 && String(r.admin2).toLowerCase().includes('davao del norte')
    );

    // Dynamic filtering for Panabo / Tagum if they exist in the sheet
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
      message: 'Dataset uploaded, parsed and reloaded successfully.',
      version: datasetVersion
    });

  } catch (error) {
    console.error('Failed to parse or save dataset:', error);
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
