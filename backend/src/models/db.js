import { Sequelize } from 'sequelize';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const defaultNeonUrl = 'postgresql://neondb_owner:npg_z8DHYpd4LmVK@ep-red-mountain-azlgoct7-pooler.c-3.ap-southeast-1.aws.neon.tech/neondb?sslmode=require';
const databaseUrl = process.env.DATABASE_URL || defaultNeonUrl;

console.log('Connecting backend API to Neon PostgreSQL database...');

const sequelize = new Sequelize(databaseUrl, {
  dialect: 'postgres',
  logging: false,
  dialectOptions: {
    ssl: {
      require: true,
      rejectUnauthorized: false
    }
  }
});

export default sequelize;
export { sequelize };
