import http from 'http';
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import morgan from 'morgan';
import cookieParser from 'cookie-parser';
import path from 'path';
import fs from 'fs';
import env from './config/env.js';
import apiRoutes from './routes/index.js';
import { notFound, errorHandler } from './middleware/errorHandler.js';
import { createSocketServer } from './sockets/index.js';

const app = express();

if (!fs.existsSync(env.uploadsBasePath)) {
  fs.mkdirSync(env.uploadsBasePath, { recursive: true });
}

app.use(helmet());
app.use(morgan('dev'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(cookieParser());

const corsOrigins = env.server.corsOrigins.length ? env.server.corsOrigins : '*';
app.use(cors({ origin: corsOrigins, credentials: true }));

app.get('/health', (req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

app.use('/uploads', express.static(path.resolve(env.uploadsBasePath)));
app.use('/api', apiRoutes);

app.use(notFound);
app.use(errorHandler);

const server = http.createServer(app);
const io = createSocketServer(server);
app.set('io', io);

server.listen(env.server.port, () => {
  console.log(`API running on port ${env.server.port}`);
});

export { app, server, io };
