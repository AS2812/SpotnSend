import multer from 'multer';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import env from '../config/env.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function ensureDir(dir) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

const storage = multer.diskStorage({
  destination(req, file, cb) {
    const base = env.uploadsBasePath.startsWith('.')
      ? path.join(__dirname, '../../', env.uploadsBasePath)
      : env.uploadsBasePath;
    const folder = path.join(base, file.fieldname || 'general');
    ensureDir(folder);
    cb(null, folder);
  },
  filename(req, file, cb) {
    const timestamp = Date.now();
    const safeName = file.originalname.replace(/[^a-zA-Z0-9.\-]/g, '_');
    cb(null, `${timestamp}-${safeName}`);
  }
});

export const upload = multer({
  storage,
  limits: {
    fileSize: 15 * 1024 * 1024,
    files: 5
  }
});
