require('dotenv').config();
const app = require('./src/app');
const connectDB = require('./src/config/db');
const seedCategories = require('./src/utils/seedCategories');
const logger = require('./src/utils/logger');
const { startCronJobs } = require('./src/jobs/recurringTransactions');

const PORT = process.env.PORT || 5000;

const start = async () => {
  await connectDB();
  await seedCategories();

  // Only run scheduled jobs on one designated instance. EB (and any
  // auto-scaled/multi-replica environment) can run several copies of this
  // process at once; leaving this unguarded would create every recurring
  // transaction N times over. Set ENABLE_CRON=true on exactly one
  // environment/instance (see backend/.ebextensions).
  if (process.env.ENABLE_CRON === 'true') {
    startCronJobs();
    logger.info('Cron jobs enabled on this instance');
  } else {
    logger.info('Cron jobs disabled on this instance (set ENABLE_CRON=true to enable)');
  }

  app.listen(PORT, () => {
    logger.info(`Backend running on port ${PORT} [${process.env.NODE_ENV || 'development'}]`);
  });
};

start().catch((err) => {
  logger.error('Failed to start server', err);
  process.exitCode = 1;
});
