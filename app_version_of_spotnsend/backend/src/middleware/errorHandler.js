export function notFound(req, res, next) {
  res.status(404).json({ message: 'Not found' });
}

export function errorHandler(err, req, res, next) { // eslint-disable-line no-unused-vars
  const status = err.status || err.statusCode || 500;
  const payload = {
    message: err.message || 'Internal Server Error'
  };
  if (err.details) payload.details = err.details;
  if (process.env.NODE_ENV !== 'production') {
    payload.stack = err.stack;
  }
  res.status(status).json(payload);
}
