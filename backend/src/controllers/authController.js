import createError from 'http-errors';
import {
  signupStep1,
  signupStep2,
  signupStep3,
  requestPhoneCode,
  verifyPhone,
  login,
  refreshTokens,
  logout,
  getUserById,
  changePassword
} from '../services/authService.js';

export async function handleSignupStep1(req, res, next) {
  try {
    const { user, otp } = await signupStep1(req.body);
    res.status(201).json({ user, otp });
  } catch (error) {
    next(error);
  }
}

export async function handleSignupStep2(req, res, next) {
  try {
    const result = await signupStep2(req.body);
    res.json(result);
  } catch (error) {
    next(error);
  }
}

export async function handleSignupStep3(req, res, next) {
  try {
    const result = await signupStep3(req.body);
    res.json(result);
  } catch (error) {
    next(error);
  }
}

export async function handleRequestPhoneCode(req, res, next) {
  try {
    const result = await requestPhoneCode(req.body);
    res.json(result);
  } catch (error) {
    next(error);
  }
}

export async function handleVerifyPhone(req, res, next) {
  try {
    const result = await verifyPhone(req.body);
    res.json(result);
  } catch (error) {
    next(error);
  }
}

export async function handleLogin(req, res, next) {
  try {
    const { tokens, sessionId, user } = await login(req.body, {
      clientIp: req.ip,
      userAgent: req.headers['user-agent'],
      deviceName: req.body.deviceName
    });
    res.json({ tokens, sessionId, user });
  } catch (error) {
    next(error);
  }
}

export async function handleRefresh(req, res, next) {
  try {
    const result = await refreshTokens(req.body.refreshToken);
    res.json(result);
  } catch (error) {
    next(error);
  }
}

export async function handleLogout(req, res, next) {
  try {
    const sessionId = req.body.sessionId || req.user?.sid;
    if (!sessionId) {
      throw createError(400, 'Session id required');
    }
    await logout(sessionId);
    res.status(204).send();
  } catch (error) {
    next(error);
  }
}

export async function handleMe(req, res, next) {
  try {
    const user = await getUserById(req.user.sub);
    res.json(user);
  } catch (error) {
    next(error);
  }
}

export async function handleChangePassword(req, res, next) {
  try {
    await changePassword(req.user.sub, req.body.currentPassword, req.body.newPassword);
    res.status(204).send();
  } catch (error) {
    next(error);
  }
}
