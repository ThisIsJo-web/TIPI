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

// Paths to dataset data and uploads
const dataDir = path.join(__dirname, '../data');
const dataPath = path.join(__dirname, '../data/scoped_prices.json');
const uploadDir = path.join(__dirname, '../uploads');

// Ensure directories exist
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
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

// --- Dataset Storage & Auto-Sync Helpers ---

// Find raw CSV or Excel dataset file in dataDir or parent Dataset folder
function findRawDatasetFile() {
  if (fs.existsSync(dataDir)) {
    const files = fs.readdirSync(dataDir);
    const rawFile = files.find(f => {
      const ext = path.extname(f).toLowerCase();
      return (ext === '.csv' || ext === '.xlsx' || ext === '.xls') && f !== 'scoped_prices.json';
    });
    if (rawFile) return path.join(dataDir, rawFile);
  }
  
  // Fallback: check dataset root folder
  const rootDir = path.join(__dirname, '..');
  if (fs.existsSync(rootDir)) {
    const rootFiles = fs.readdirSync(rootDir);
    const rawFile = rootFiles.find(f => {
      const ext = path.extname(f).toLowerCase();
      return (ext === '.csv' || ext === '.xlsx' || ext === '.xls');
    });
    if (rawFile) return path.join(rootDir, rawFile);
  }

  return null;
}

// Process a raw dataset file (CSV/Excel), filter records, write scoped_prices.json & generate comparison
async function processAndSaveDataset(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  let rawRecords = [];
  if (ext === '.csv') {
    console.log(`Streaming CSV line-by-line: ${filePath}...`);
    rawRecords = await parseCsvStream(filePath);
  } else {
    console.log(`Reading Excel file in-memory: ${filePath}...`);
    rawRecords = parseExcelFile(filePath);
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

  // Backup current scoped_prices.json to previous_prices.json before updating
  const previousPath = path.join(dataDir, 'previous_prices.json');
  if (fs.existsSync(dataPath)) {
    try {
      fs.copyFileSync(dataPath, previousPath);
    } catch (e) {
      console.error('Failed to snapshot previous dataset:', e);
    }
  }

  // Save to disk as JSON cache
  fs.writeFileSync(dataPath, JSON.stringify(filteredRecords, null, 2));

  // Generate dataset comparison report
  generateComparisonReport(previousPath, filteredRecords);

  return filteredRecords;
}

// Generate dataset comparison report between previous and new datasets
function generateComparisonReport(oldPath, newDataset) {
  let oldDataset = [];
  if (fs.existsSync(oldPath)) {
    try {
      oldDataset = JSON.parse(fs.readFileSync(oldPath, 'utf8'));
    } catch (e) {
      oldDataset = [];
    }
  }

  const oldCount = oldDataset.length;
  const newCount = newDataset.length;
  const recordDiff = newCount - oldCount;

  // Map old dataset by key: commodity_market_unit
  const oldMap = new Map();
  oldDataset.forEach(item => {
    if (item.commodity && item.market) {
      const key = `${item.commodity.toLowerCase()}_${item.market.toLowerCase()}_${(item.unit || '').toLowerCase()}`;
      oldMap.set(key, item);
    }
  });

  let increasedCount = 0;
  let decreasedCount = 0;
  let unchangedCount = 0;
  let newCommodityCount = 0;
  const priceChanges = [];

  newDataset.forEach(newItem => {
    if (!newItem.commodity || !newItem.market) return;
    const key = `${newItem.commodity.toLowerCase()}_${newItem.market.toLowerCase()}_${(newItem.unit || '').toLowerCase()}`;
    const oldItem = oldMap.get(key);

    if (oldItem && oldItem.price !== null && newItem.price !== null) {
      const diff = parseFloat((newItem.price - oldItem.price).toFixed(2));
      if (diff > 0) {
        increasedCount++;
        priceChanges.push({
          commodity: newItem.commodity,
          category: newItem.category || 'General',
          market: newItem.market,
          unit: newItem.unit || 'kg',
          oldPrice: oldItem.price,
          newPrice: newItem.price,
          diff: `+₱${diff.toFixed(2)}`,
          status: 'increased',
          date: newItem.date || ''
        });
      } else if (diff < 0) {
        decreasedCount++;
        priceChanges.push({
          commodity: newItem.commodity,
          category: newItem.category || 'General',
          market: newItem.market,
          unit: newItem.unit || 'kg',
          oldPrice: oldItem.price,
          newPrice: newItem.price,
          diff: `-₱${Math.abs(diff).toFixed(2)}`,
          status: 'decreased',
          date: newItem.date || ''
        });
      } else {
        unchangedCount++;
      }
    } else if (!oldItem) {
      newCommodityCount++;
    }
  });

  const report = {
    updatedAt: new Date().toISOString(),
    oldCount,
    newCount,
    recordDiff,
    increasedCount,
    decreasedCount,
    unchangedCount,
    newCommodityCount,
    priceChanges: priceChanges.slice(0, 50)
  };

  try {
    fs.writeFileSync(path.join(dataDir, 'comparison_report.json'), JSON.stringify(report, null, 2));
  } catch (e) {
    console.error('Failed to write comparison report:', e);
  }

  return report;
}

// Helper to load dataset from disk, auto-parsing raw CSV/Excel if newer or if JSON is missing
async function syncAndLoadDataset() {
  try {
    const rawFilePath = findRawDatasetFile();
    let shouldParseRaw = false;

    if (rawFilePath && fs.existsSync(rawFilePath)) {
      if (!fs.existsSync(dataPath)) {
        shouldParseRaw = true;
      } else {
        const rawStat = fs.statSync(rawFilePath);
        const jsonStat = fs.statSync(dataPath);
        if (rawStat.mtimeMs > jsonStat.mtimeMs) {
          shouldParseRaw = true;
        }
      }
    }

    if (shouldParseRaw && rawFilePath) {
      console.log(`Auto-parsing raw dataset file: ${path.basename(rawFilePath)}...`);
      await processAndSaveDataset(rawFilePath);
    }

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
    console.error('Failed to sync/load dataset:', error);
  }
}

// File watcher on dataDir to auto-sync when a CSV is added/replaced directly on disk
let watchTimeout = null;
if (fs.existsSync(dataDir)) {
  fs.watch(dataDir, (eventType, filename) => {
    if (!filename) return;
    const ext = path.extname(filename).toLowerCase();
    if ((ext === '.csv' || ext === '.xlsx' || ext === '.xls') && filename !== 'scoped_prices.json' && filename !== 'previous_prices.json' && filename !== 'comparison_report.json') {
      if (watchTimeout) clearTimeout(watchTimeout);
      watchTimeout = setTimeout(() => {
        console.log(`Detected change in ${filename}. Re-syncing dataset...`);
        syncAndLoadDataset();
      }, 500);
    }
  });
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

// 3. GET /api/preview (Returns first 30 rows of current dataset)
app.get('/api/preview', (req, res) => {
  const limit = parseInt(req.query.limit) || 30;
  const previewData = priceDataset.slice(0, limit);
  const rawFile = findRawDatasetFile();
  res.json({
    totalRecords: priceDataset.length,
    showing: previewData.length,
    releaseDate: datasetVersion.releaseDate,
    fileName: rawFile ? path.basename(rawFile) : 'dataset.csv',
    filePath: 'Dataset/data/dataset.csv',
    data: previewData
  });
});

// 4. GET /api/comparison (Returns dataset comparison details)
app.get('/api/comparison', (req, res) => {
  const compPath = path.join(dataDir, 'comparison_report.json');
  if (fs.existsSync(compPath)) {
    try {
      const report = JSON.parse(fs.readFileSync(compPath, 'utf8'));
      return res.json(report);
    } catch (e) {}
  }

  res.json({
    updatedAt: new Date().toISOString(),
    oldCount: priceDataset.length,
    newCount: priceDataset.length,
    recordDiff: 0,
    increasedCount: 0,
    decreasedCount: 0,
    unchangedCount: priceDataset.length,
    newCommodityCount: 0,
    priceChanges: []
  });
});

// 5. POST /api/upload
// Receives Excel/CSV, persists it as Dataset/data/dataset.csv, parses streamingly
app.post('/api/upload', upload.single('datasetFile'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ success: false, error: 'No file uploaded.' });
  }

  const tempFilePath = req.file.path;
  const originalName = req.file.originalname;
  const ext = path.extname(originalName).toLowerCase();
  console.log(`File uploaded: ${originalName} at ${tempFilePath}`);

  try {
    // Copy uploaded file permanently to Dataset/data/dataset.csv
    const targetFileName = `dataset${ext || '.csv'}`;
    const targetPath = path.join(dataDir, targetFileName);

    // Remove any previous raw dataset CSV/Excel files in dataDir
    if (fs.existsSync(dataDir)) {
      const existingFiles = fs.readdirSync(dataDir);
      for (const file of existingFiles) {
        const fileExt = path.extname(file).toLowerCase();
        if ((fileExt === '.csv' || fileExt === '.xlsx' || fileExt === '.xls') && file !== 'scoped_prices.json' && file !== 'previous_prices.json' && file !== 'comparison_report.json') {
          try {
            fs.unlinkSync(path.join(dataDir, file));
          } catch (e) {}
        }
      }
    }

    fs.copyFileSync(tempFilePath, targetPath);
    console.log(`Saved persistent dataset file to: ${targetPath}`);

    // Parse raw dataset file, save scoped_prices.json & generate comparison
    await processAndSaveDataset(targetPath);

    // Clean up temporary Multer upload
    if (fs.existsSync(tempFilePath)) {
      fs.unlinkSync(tempFilePath);
    }

    // Reload memory cache
    await syncAndLoadDataset();

    res.json({
      success: true,
      message: `Dataset uploaded, saved to Dataset/data/${targetFileName}, parsed and reloaded successfully.`,
      targetFile: `Dataset/data/${targetFileName}`,
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

// 6. POST /api/update
app.post('/api/update', async (req, res) => {
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
  await syncAndLoadDataset();
  res.json({
    success: true,
    message: 'Dataset updated and reloaded successfully.',
    version: datasetVersion
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok', time: new Date() });
});

// Initial load on server startup
syncAndLoadDataset().then(() => {
  app.listen(PORT, () => {
    console.log(`Dataset API running on port ${PORT}`);
  });
});
