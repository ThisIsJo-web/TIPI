import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import User from '../models/User.js';
import { JWT_SECRET } from '../middleware/auth.js';

// Helper to generate active_since string
const getActiveSinceString = () => {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const now = new Date();
  return `${months[now.getMonth()]} ${now.getFullYear()}`;
};

export async function register(req, res) {
  const { email, password, name, budgetGoal } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }

  try {
    const existing = await User.findOne({ where: { email: email.toLowerCase() } });
    if (existing) {
      return res.status(400).json({ error: 'A user with this email already exists' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = await User.create({
      email: email.toLowerCase(),
      password: hashedPassword,
      name: name || '',
      budgetGoal: budgetGoal || 0.0,
      activeSince: getActiveSinceString()
    });

    const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '30d' });

    res.status(201).json({
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        budgetGoal: user.budgetGoal,
        activeSince: user.activeSince,
        runsCompleted: user.runsCompleted,
        totalSaved: user.totalSaved,
        language: user.language
      }
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}

export async function login(req, res) {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }

  try {
    const user = await User.findOne({ where: { email: email.toLowerCase() } });
    if (!user) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const isValid = await bcrypt.compare(password, user.password);
    if (!isValid) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '30d' });

    res.json({
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        budgetGoal: user.budgetGoal,
        activeSince: user.activeSince,
        runsCompleted: user.runsCompleted,
        totalSaved: user.totalSaved,
        language: user.language,
        preferredProvince: user.preferredProvince,
        preferredMarket: user.preferredMarket
      }
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}

export async function getProfile(req, res) {
  try {
    const user = await User.findByPk(req.userId, {
      attributes: { exclude: ['password'] }
    });
    if (!user) {
      return res.status(404).json({ error: 'User profile not found' });
    }
    res.json(user);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}

export async function updateProfile(req, res) {
  const { name, budgetGoal, language, preferredProvince, preferredMarket, runsCompleted, totalSaved } = req.body;
  try {
    const user = await User.findByPk(req.userId);
    if (!user) {
      return res.status(404).json({ error: 'User profile not found' });
    }

    if (name !== undefined) user.name = name;
    if (budgetGoal !== undefined) user.budgetGoal = budgetGoal;
    if (language !== undefined) user.language = language;
    if (preferredProvince !== undefined) user.preferredProvince = preferredProvince;
    if (preferredMarket !== undefined) user.preferredMarket = preferredMarket;
    
    // Allow updating runs count and savings stats
    if (runsCompleted !== undefined) user.runsCompleted = runsCompleted;
    if (totalSaved !== undefined) user.totalSaved = totalSaved;

    await user.save();

    res.json({
      id: user.id,
      email: user.email,
      name: user.name,
      budgetGoal: user.budgetGoal,
      activeSince: user.activeSince,
      runsCompleted: user.runsCompleted,
      totalSaved: user.totalSaved,
      language: user.language,
      preferredProvince: user.preferredProvince,
      preferredMarket: user.preferredMarket
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}
