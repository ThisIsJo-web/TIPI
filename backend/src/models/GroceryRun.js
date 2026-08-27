import { DataTypes } from 'sequelize';
import sequelize from './db.js';
import User from './User.js';

const GroceryRun = sequelize.define('GroceryRun', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true
  },
  userId: {
    type: DataTypes.UUID,
    allowNull: false,
    field: 'user_id',
    references: {
      model: User,
      key: 'id'
    }
  },
  name: {
    type: DataTypes.STRING,
    allowNull: false
  },
  budget: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false
  },
  spent: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0.0
  },
  status: {
    type: DataTypes.STRING,
    defaultValue: 'active',
    validate: {
      isIn: [['active', 'completed', 'draft']]
    }
  }
}, {
  tableName: 'grocery_runs',
  timestamps: true
});

// Associations
User.hasMany(GroceryRun, { foreignKey: 'userId', as: 'runs', onDelete: 'CASCADE' });
GroceryRun.belongsTo(User, { foreignKey: 'userId', as: 'user' });

export default GroceryRun;
