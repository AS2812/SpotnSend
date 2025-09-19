import { Router } from 'express';
import {
  handleSignupStep1,
  handleSignupStep2,
  handleSignupStep3,
  handleRequestPhoneCode,
  handleVerifyPhone,
  handleLogin,
  handleRefresh,
  handleLogout,
  handleMe,
  handleChangePassword
} from '../controllers/authController.js';
import {
  signupStep1Schema,
  signupStep2Schema,
  signupStep3Schema,
  requestPhoneCodeSchema,
  verifyPhoneSchema,
  loginSchema,
  refreshTokenSchema
} from '../validators/authSchemas.js';
import { changePasswordSchema } from '../validators/userSchemas.js';
import { validate } from '../middleware/validate.js';
import { authenticate } from '../middleware/auth.js';
import { authRateLimiter } from '../middleware/rateLimiters.js';

const router = Router();

router.post('/signup/step1', authRateLimiter, validate(signupStep1Schema), handleSignupStep1);
router.post('/signup/step2', authRateLimiter, validate(signupStep2Schema), handleSignupStep2);
router.post('/signup/step3', authRateLimiter, validate(signupStep3Schema), handleSignupStep3);

router.post('/request-phone-code', authRateLimiter, validate(requestPhoneCodeSchema), handleRequestPhoneCode);
router.post('/verify-phone', authRateLimiter, validate(verifyPhoneSchema), handleVerifyPhone);

router.post('/login', authRateLimiter, validate(loginSchema), handleLogin);
router.post('/refresh', validate(refreshTokenSchema), handleRefresh);
router.post('/logout', authenticate(), handleLogout);

router.get('/me', authenticate(), handleMe);
router.post('/change-password', authenticate(), validate(changePasswordSchema), handleChangePassword);

export default router;
