import GroceryRun from '../models/GroceryRun.js';
import GroceryRunItem from '../models/GroceryRunItem.js';

// --- Runs Header CRUD ---

export async function listRuns(req, res) {
  try {
    const runs = await GroceryRun.findAll({
      where: { userId: req.userId },
      include: [{ model: GroceryRunItem, as: 'items' }],
      order: [['createdAt', 'DESC']]
    });
    res.json(runs);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}

export async function createRun(req, res) {
  const { name, budget, status } = req.body;
  if (!name || budget === undefined) {
    return res.status(400).json({ error: 'Name and budget are required' });
  }

  try {
    const run = await GroceryRun.create({
      userId: req.userId,
      name,
      budget,
      status: status || 'active'
    });
    
    // Return with empty items array
    res.status(201).json({
      ...run.toJSON(),
      items: []
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}

export async function updateRun(req, res) {
  const { id } = req.params;
  const { name, budget, status } = req.body;
  
  try {
    const run = await GroceryRun.findOne({ where: { id, userId: req.userId } });
    if (!run) {
      return res.status(404).json({ error: 'Grocery run not found or unauthorized' });
    }

    if (name !== undefined) run.name = name;
    if (budget !== undefined) run.budget = budget;
    if (status !== undefined) run.status = status;

    await run.save();
    
    // Fetch updated run with items
    const updated = await GroceryRun.findByPk(run.id, {
      include: [{ model: GroceryRunItem, as: 'items' }]
    });

    res.json(updated);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}

export async function deleteRun(req, res) {
  const { id } = req.params;
  try {
    const run = await GroceryRun.findOne({ where: { id, userId: req.userId } });
    if (!run) {
      return res.status(404).json({ error: 'Grocery run not found or unauthorized' });
    }

    await run.destroy();
    res.json({ success: true, message: 'Grocery run deleted successfully.' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}

// --- Runs Items CRUD ---

export async function addRunItem(req, res) {
  const { runId } = req.params;
  const { commodity, price, quantity, unit, category, market } = req.body;

  if (!commodity || price === undefined) {
    return res.status(400).json({ error: 'Commodity and price are required' });
  }

  try {
    // Verify run belongs to user
    const run = await GroceryRun.findOne({ where: { id: runId, userId: req.userId } });
    if (!run) {
      return res.status(404).json({ error: 'Grocery run not found or unauthorized' });
    }

    const item = await GroceryRunItem.create({
      runId,
      commodity,
      price,
      quantity: quantity || 1.0,
      unit: unit || '',
      category: category || '',
      market: market || ''
    });

    res.status(201).json(item);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}

export async function updateRunItem(req, res) {
  const { runId, itemId } = req.params;
  const { price, quantity, checked, category, market, commodity, unit } = req.body;

  try {
    // Verify run belongs to user
    const run = await GroceryRun.findOne({ where: { id: runId, userId: req.userId } });
    if (!run) {
      return res.status(404).json({ error: 'Grocery run not found or unauthorized' });
    }

    const item = await GroceryRunItem.findOne({ where: { id: itemId, runId } });
    if (!item) {
      return res.status(404).json({ error: 'Grocery run item not found' });
    }

    if (commodity !== undefined) item.commodity = commodity;
    if (price !== undefined) item.price = price;
    if (quantity !== undefined) item.quantity = quantity;
    if (checked !== undefined) item.checked = checked;
    if (category !== undefined) item.category = category;
    if (market !== undefined) item.market = market;
    if (unit !== undefined) item.unit = unit;

    await item.save();
    res.json(item);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}

export async function deleteRunItem(req, res) {
  const { runId, itemId } = req.params;

  try {
    // Verify run belongs to user
    const run = await GroceryRun.findOne({ where: { id: runId, userId: req.userId } });
    if (!run) {
      return res.status(404).json({ error: 'Grocery run not found or unauthorized' });
    }

    const item = await GroceryRunItem.findOne({ where: { id: itemId, runId } });
    if (!item) {
      return res.status(404).json({ error: 'Grocery run item not found' });
    }

    await item.destroy();
    res.json({ success: true, message: 'Item deleted successfully.' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}
