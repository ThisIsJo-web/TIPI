import express from 'express';
import cors from 'cors';
import sequelize from './models/db.js';
import authRoutes from './routes/auth_routes.js';
import runsRoutes from './routes/runs_routes.js';

const app = express();
const PORT = process.env.PORT || 4000;

app.use(cors());
app.use(express.json());

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/runs', runsRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', time: new Date() });
});

// Sync database and start server
async function startServer() {
  try {
    await sequelize.authenticate();
    console.log('Database connected successfully.');

    // Sync database models (creates tables if they don't exist)
    // Note: In production migrations are preferred, but sync is ideal for rapid development and clean resets.
    await sequelize.sync({ alter: true });
    console.log('Database synchronized.');

    app.listen(PORT, () => {
      console.log(`Tipi backend API running on port ${PORT}`);
    });
  } catch (error) {
    console.error('Failed to connect to the database or start server:', error);
    process.exit(1);
  }
}

startServer();
