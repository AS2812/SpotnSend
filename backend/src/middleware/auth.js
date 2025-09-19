import createError from 'http-errors';
import { verifyAccessToken } from '../utils/token.js';

export function authenticate({ optional = false } = {}) {
  return (req, res, next) => {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;

    if (!token) {
      if (optional) return next();
      return next(createError(401, 'Authentication required'));
    }

    try {
      const decoded = verifyAccessToken(token);
      req.user = decoded;
      return next();
    } catch (error) {
      if (optional) return next();
      return next(createError(401, 'Invalid or expired token'));
    }
  };
}

export function requireRoles(...roles) {
  return (req, res, next) => {
    if (!req.user) return next(createError(401, 'Authentication required'));
    if (!roles.includes(req.user.role)) {
      return next(createError(403, 'Insufficient privileges'));
    }
    next();
  };
}
