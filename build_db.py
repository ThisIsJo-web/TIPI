import sqlite3
import zipfile
import xml.etree.ElementTree as ET
import os
import csv
from datetime import datetime
import json

db_file = r"c:\dev\tipi\tipi_data.db"
version_file = r"c:\dev\tipi\version.json"

# Search for the dataset in the current folder or downloads
def find_dataset():
    target = r"C:\Users\This PC\Downloads\wfp_food_prices_phl.csv"
    if os.path.exists(target):
        print(f"Found latest dataset in Downloads: {target}")
        return target
        
    folder = r"c:\dev\tipi"
    for file in os.listdir(folder):
        if file.startswith("Final Normalized Dataset") or file.endswith(".xlsx") or file.endswith(".csv"):
            if not file.endswith(".py") and not file.endswith(".db") and not file.endswith(".json"):
                full_path = os.path.join(folder, file)
                print(f"Found dataset file: {full_path}")
                return full_path
    return None

def parse_excel_date(val):
    if not val:
        return None
    
    # Try converting from Excel serial number
    try:
        serial = float(val)
        if serial < 60:
            ordinal = datetime(1900, 1, 1).toordinal() + int(serial) - 1
        else:
            ordinal = datetime(1900, 1, 1).toordinal() + int(serial) - 2
        return datetime.fromordinal(ordinal).strftime('%Y-%m-%d')
    except ValueError:
        pass
    
    # Try parsing as standard date strings
    for fmt in ('%m/%d/%Y', '%m/%d/%y', '%Y-%m-%d', '%d/%m/%Y', '%d/%m/%y'):
        try:
            return datetime.strptime(str(val).strip(), fmt).strftime('%Y-%m-%d')
        except ValueError:
            continue
            
    return str(val).strip()

def read_xlsx(file_path):
    print("Parsing as Excel (.xlsx)...")
    with zipfile.ZipFile(file_path, 'r') as zip_ref:
        # Load shared strings
        shared_strings = []
        ns = {'ns': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
        if 'xl/sharedStrings.xml' in zip_ref.namelist():
            ss_data = zip_ref.read('xl/sharedStrings.xml')
            ss_root = ET.fromstring(ss_data)
            for t in ss_root.findall('.//ns:t', ns):
                shared_strings.append(t.text if t.text is not None else "")

        # Load Sheet1
        sheet_data = zip_ref.read('xl/worksheets/sheet1.xml')
        root = ET.fromstring(sheet_data)
        
        rows = root.findall('.//ns:row', ns)
        if not rows:
            print("No rows found in sheet1.")
            return [], []
            
        # Parse headers
        headers = []
        header_cells = rows[0].findall('ns:c', ns)
        for cell in header_cells:
            val_el = cell.find('ns:v', ns)
            val = val_el.text if val_el is not None else ""
            t = cell.get('t')
            if t == 's' and val:
                idx = int(val)
                if idx < len(shared_strings):
                    val = shared_strings[idx]
            headers.append(val.strip().lower())
            
        records = []
        for row in rows[1:]:
            cells = row.findall('ns:c', ns)
            row_data = {}
            for cell in cells:
                r = cell.get('r')
                if not r:
                    continue
                col_letters = ''.join(c for c in r if c.isalpha())
                col_idx = 0
                for char in col_letters:
                    col_idx = col_idx * 26 + (ord(char.upper()) - ord('A') + 1)
                col_idx -= 1
                
                val_el = cell.find('ns:v', ns)
                val = val_el.text if val_el is not None else ""
                t = cell.get('t')
                if t == 's' and val:
                    idx = int(val)
                    if idx < len(shared_strings):
                        val = shared_strings[idx]
                row_data[col_idx] = val
            records.append(row_data)
            
        return headers, records

def read_csv(file_path):
    print("Parsing as CSV...")
    # Try different encodings to be robust
    encodings = ['utf-8', 'latin-1', 'cp1252']
    for encoding in encodings:
        try:
            with open(file_path, 'r', encoding=encoding) as f:
                reader = csv.reader(f)
                headers = [h.strip().lower() for h in next(reader)]
                records = []
                for row in reader:
                    row_data = {}
                    for idx, val in enumerate(row):
                        row_data[idx] = val
                    records.append(row_data)
                return headers, records
        except UnicodeDecodeError:
            continue
    raise Exception("Could not decode CSV with supported encodings.")

def build_database():
    dataset_file = find_dataset()
    if not dataset_file:
        print("Error: Could not find any dataset file in the directory.")
        return

    # Check if ZIP format (xlsx)
    is_xlsx = False
    try:
        with open(dataset_file, 'rb') as f:
            header_bytes = f.read(4)
            is_xlsx = (header_bytes == b'PK\x03\x04')
    except Exception as e:
        print(f"Error reading file headers: {e}")
        return

    if is_xlsx:
        headers, raw_records = read_xlsx(dataset_file)
    else:
        headers, raw_records = read_csv(dataset_file)

    print("Detected Sheet Headers:", headers)
    
    # Map headers to standard SQLite columns
    column_mappings = {
        'date': ['date', 'source_date'],
        'admin1': ['admin1', 'region', 'region '],
        'admin2': ['admin2', 'province'],
        'market': ['market'],
        'market_id': ['market_id'],
        'latitude': ['latitude'],
        'longitude': ['longitude'],
        'category': ['category'],
        'commodity': ['commodity'],
        'commodity_id': ['commodity_id'],
        'unit': ['unit'],
        'priceflag': ['priceflag'],
        'pricetype': ['pricetype'],
        'currency': ['currency'],
        'price': ['price']
    }
    
    header_indices = {}
    for col, aliases in column_mappings.items():
        found_idx = -1
        for alias in aliases:
            clean_alias = alias.strip().lower()
            for i, h in enumerate(headers):
                if h.strip() == clean_alias:
                    found_idx = i
                    break
            if found_idx != -1:
                break
        header_indices[col] = found_idx
        
    print("Header index mapping:", {k: v for k, v in header_indices.items() if v != -1})

    # Connect to SQLite
    if os.path.exists(db_file):
        os.remove(db_file)
        
    conn = sqlite3.connect(db_file)
    cursor = conn.cursor()

    cursor.execute('''
        CREATE TABLE IF NOT EXISTS prices (
            id INTEGER PRIMARY KEY,
            date TEXT,
            admin1 TEXT,
            admin2 TEXT,
            market TEXT,
            market_id INTEGER,
            latitude REAL,
            longitude REAL,
            category TEXT,
            commodity TEXT,
            commodity_id INTEGER,
            unit TEXT,
            priceflag TEXT,
            pricetype TEXT,
            currency TEXT,
            price REAL
        )
    ''')

    records = []
    for r_idx, row_data in enumerate(raw_records):
        record_vals = {}
        for col_name, h_idx in header_indices.items():
            val = row_data.get(h_idx, "")
            
            # Clean and cast
            if col_name == 'date':
                val = parse_excel_date(val)
            elif col_name in ('latitude', 'longitude', 'price'):
                try:
                    val = float(val) if (val is not None and str(val).strip() != "") else None
                except ValueError:
                    val = None
            elif col_name in ('market_id', 'commodity_id'):
                try:
                    val = int(float(val)) if (val is not None and str(val).strip() != "") else None
                except ValueError:
                    val = None
            else:
                val = str(val).strip() if (val is not None and str(val).strip() != "") else None
                
            record_vals[col_name] = val
            
        records.append((
            record_vals.get('date'),
            record_vals.get('admin1'),
            record_vals.get('admin2'),
            record_vals.get('market'),
            record_vals.get('market_id'),
            record_vals.get('latitude'),
            record_vals.get('longitude'),
            record_vals.get('category'),
            record_vals.get('commodity'),
            record_vals.get('commodity_id'),
            record_vals.get('unit'),
            record_vals.get('priceflag'),
            record_vals.get('pricetype'),
            record_vals.get('currency'),
            record_vals.get('price')
        ))

    # Bulk insert
    cursor.executemany('''
        INSERT INTO prices (
            date, admin1, admin2, market, market_id, latitude, longitude,
            category, commodity, commodity_id, unit, priceflag, pricetype, currency, price
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', records)
    
    conn.commit()

    # Index table for speed
    print("Creating database indexes for offline speed...")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_prices_commodity ON prices(commodity);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_prices_market ON prices(market);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_prices_date ON prices(date);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_prices_admin1 ON prices(admin1);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_prices_admin2 ON prices(admin2);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_prices_coords ON prices(latitude, longitude);")
    conn.commit()

    cursor.execute("SELECT COUNT(*) FROM prices;")
    total_rows = cursor.fetchone()[0]
    print(f"Success! Imported {total_rows} rows into SQLite database.")
    conn.close()

    # Compress database file into zip
    zip_file = r"c:\dev\tipi\tipi_data.zip"
    print("Compressing database into tipi_data.zip...")
    with zipfile.ZipFile(zip_file, 'w', zipfile.ZIP_DEFLATED) as zipf:
        zipf.write(db_file, arcname="tipi_data.db")
    print(f"Compression complete. Zip size: {os.path.getsize(zip_file) / 1024 / 1024:.2f} MB")

    # Write version info
    version_data = {
        "version": 1,
        "release_date": datetime.now().strftime("%Y-%m-%d"),
        "total_records": total_rows
    }
    with open(version_file, "w") as f:
        json.dump(version_data, f, indent=2)
    print("Version metadata created.")

if __name__ == "__main__":
    build_database()
