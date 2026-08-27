import express from 'express';
import { 
  listRuns, 
  createRun, 
  updateRun, 
  deleteRun, 
  addRunItem, 
  updateRunItem, 
  deleteRunItem 
} from '../controllers/runs_controller.js';
import authMiddleware from '../middleware/auth.js';

const router = express.Router();

// Apply auth authMiddleware globally to all runs endpoints
router.use(authMiddleware);

// Runs Header Routes
router.get('/', listRuns);
router.post('/', createRun);
router.put('/:id', updateRun);
router.delete('/:id', deleteRun);

// Run Items Routes
router.post('/:runId/items', addRunItem);
router.put('/:runId/items/:itemId', updateRunItem);
router.delete('/:runId/items/:itemId', deleteRunItem);

export default router;
