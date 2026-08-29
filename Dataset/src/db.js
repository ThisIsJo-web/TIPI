import pg from 'pg';
import dotenv from 'dotenv';

dotenv.config();

const { Pool } = pg;

const defaultDatasetNeonUrl = 'postgresql://neondb_owner:npg_Zzsqek0Mr2jy@ep-super-boat-azwklbf4-pooler.c-3.ap-southeast-1.aws.neon.tech/neondb?sslmode=require';
const connectionString = process.env.DATABASE_URL || defaultDatasetNeonUrl;

console.log('Connecting Dataset API to Neon PostgreSQL database...');

export const pool = new Pool({
  connectionString,
  ssl: {
    rejectUnauthorized: false
  }
});

// Helper to initialize table schema in Neon DB
export async function initDatabaseSchema() {
  const client = await pool.connect();
  try {
    console.log('Initializing prices table schema in Neon PostgreSQL...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS prices (
        id SERIAL PRIMARY KEY,
        date VARCHAR(50),
        admin1 VARCHAR(100),
        admin2 VARCHAR(100),
        market VARCHAR(100),
        market_id INT,
        latitude FLOAT,
        longitude FLOAT,
        category VARCHAR(100),
        commodity VARCHAR(150),
        unit VARCHAR(50),
        price NUMERIC(10, 2),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('Prices table schema verified in Neon DB.');
  } catch (error) {
    console.error('Error initializing Neon DB schema:', error);
  } finally {
    client.release();
  }
}

// Bulk upsert records into Neon PostgreSQL
export async function saveRecordsToNeon(records) {
  if (!records || records.length === 0) return 0;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    
    for (const r of records) {
      if (!r.commodity) continue;
      await client.query(`
        INSERT INTO prices (date, admin1, admin2, market, market_id, latitude, longitude, category, commodity, unit, price)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      `, [
        r.date || new Date().toISOString().split('T')[0],
        r.admin1 || 'Region XI',
        r.admin2 || 'Davao del Norte',
        r.market || 'Tagum Public Market',
        r.market_id || 1,
        r.latitude || 7.4474,
        r.longitude || 125.8080,
        r.category || 'General',
        r.commodity,
        r.unit || 'kg',
        r.price || 0
      ]);
    }
    
    await client.query('COMMIT');
    console.log(`Successfully persisted ${records.length} records to Neon DB.`);
    return records.length;
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Failed to save records to Neon DB:', error);
    throw error;
  } finally {
    client.release();
  }
}

// Fetch price records from Neon PostgreSQL
export async function getPricesFromNeon(category, commodity) {
  const client = await pool.connect();
  try {
    let query = 'SELECT * FROM prices WHERE 1=1';
    const params = [];

    if (category) {
      params.push(`%${category.toLowerCase()}%`);
      query += ` AND LOWER(category) LIKE $${params.length}`;
    }

    if (commodity) {
      params.push(`%${commodity.toLowerCase()}%`);
      query += ` AND LOWER(commodity) LIKE $${params.length}`;
    }

    query += ' ORDER BY commodity ASC';
    const res = await client.query(query, params);
    return res.rows;
  } catch (error) {
    console.error('Error fetching prices from Neon DB:', error);
    return [];
  } finally {
    client.release();
  }
}

// Clear all dataset prices in Neon DB
export async function clearNeonPrices() {
  const client = await pool.connect();
  try {
    await client.query('DELETE FROM prices');
    console.log('Cleared existing prices from Neon DB.');
  } catch (error) {
    console.error('Error clearing prices in Neon DB:', error);
  } finally {
    client.release();
  }
}

export default {
  pool,
  initDatabaseSchema,
  saveRecordsToNeon,
  getPricesFromNeon,
  clearNeonPrices
};
