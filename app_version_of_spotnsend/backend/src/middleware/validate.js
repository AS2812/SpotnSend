import { ZodError } from 'zod';
import createError from 'http-errors';

export function validate(schema, property = 'body') {
  return async (req, res, next) => {
    try {
      const data = await schema.parseAsync(req[property]);
      req[property] = data;
      next();
    } catch (error) {
      if (error instanceof ZodError) {
        return next(createError(422, {
          message: 'Validation failed',
          details: error.flatten()
        }));
      }
      next(error);
    }
  };
}
