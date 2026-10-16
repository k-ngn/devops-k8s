const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 4000;
const ENVIRONMENT = process.env.NODE_ENV || 'development';
const APP_VERSION = process.env.APP_VERSION || '1.0.0';

app.use(cors());
app.use(express.json());

// Basic health check endpoint for K8s readiness/liveness probes
app.get('/healthz', (req, res) => {
  res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
});

// App status endpoint
app.get('/api/status', (req, res) => {
  res.status(200).json({
    service: 'backend',
    status: 'healthy',
    version: APP_VERSION,
    environment: ENVIRONMENT,
    uptime_seconds: Math.floor(process.uptime()),
    hostname: process.env.HOSTNAME || 'localhost'
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.send(`Demo Backend API (${APP_VERSION}) is running on ${ENVIRONMENT}`);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Backend server listening on port ${PORT} [Env: ${ENVIRONMENT}]`);
});
