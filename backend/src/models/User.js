import { DataTypes } from 'sequelize';
import sequelize from './db.js';

const User = sequelize.define('User', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true
  },
  email: {
    type: DataTypes.STRING,
    allowNull: false,
    unique: true,
    validate: {
      isEmail: true
    }
  },
  password: {
    type: DataTypes.STRING,
    allowNull: false
  },
  name: {
    type: DataTypes.STRING,
    allowNull: true
  },
  budgetGoal: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0.0,
    field: 'budget_goal'
  },
  activeSince: {
    type: DataTypes.STRING,
    allowNull: true,
    field: 'active_since'
  },
  runsCompleted: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
    field: 'runs_completed'
  },
  totalSaved: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0.0,
    field: 'total_saved'
  },
  language: {
    type: DataTypes.STRING,
    defaultValue: 'English'
  },
  preferredProvince: {
    type: DataTypes.STRING,
    allowNull: true,
    field: 'preferred_province'
  },
  preferredMarket: {
    type: DataTypes.STRING,
    allowNull: true,
    field: 'preferred_market'
  }
}, {
  tableName: 'users',
  timestamps: true
});

export default User;
