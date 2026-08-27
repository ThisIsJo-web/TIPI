import { DataTypes } from 'sequelize';
import sequelize from './db.js';
import GroceryRun from './GroceryRun.js';

const GroceryRunItem = sequelize.define('GroceryRunItem', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true
  },
  runId: {
    type: DataTypes.UUID,
    allowNull: false,
    field: 'run_id',
    references: {
      model: GroceryRun,
      key: 'id'
    }
  },
  commodity: {
    type: DataTypes.STRING,
    allowNull: false
  },
  price: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false
  },
  quantity: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 1.0
  },
  unit: {
    type: DataTypes.STRING,
    allowNull: true
  },
  category: {
    type: DataTypes.STRING,
    allowNull: true
  },
  market: {
    type: DataTypes.STRING,
    allowNull: true
  },
  checked: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  }
}, {
  tableName: 'grocery_run_items',
  timestamps: true,
  indexes: [
    {
      fields: ['run_id']
    },
    {
      fields: ['commodity']
    }
  ]
});

// Associations
GroceryRun.hasMany(GroceryRunItem, { foreignKey: 'runId', as: 'items', onDelete: 'CASCADE' });
GroceryRunItem.belongsTo(GroceryRun, { foreignKey: 'runId', as: 'run' });

// Add hook to recalculate grocery run spent budget after inserts, updates, and deletes
const recalculateSpent = async (runId) => {
  try {
    const items = await GroceryRunItem.findAll({ where: { runId } });
    const spent = items.reduce((sum, item) => {
      return sum + (Number(item.price) * Number(item.quantity));
    }, 0);
    await GroceryRun.update({ spent }, { where: { id: runId } });
  } catch (error) {
    console.error('Error recalculating spent budget:', error);
  }
};

GroceryRunItem.afterCreate(async (item) => {
  await recalculateSpent(item.runId);
});

GroceryRunItem.afterUpdate(async (item) => {
  await recalculateSpent(item.runId);
});

GroceryRunItem.afterDestroy(async (item) => {
  await recalculateSpent(item.runId);
});

export default GroceryRunItem;
export { recalculateSpent };
