import { v4 as uuidv4 } from 'uuid';
import createError from 'http-errors';
import { db, withTransaction } from '../config/db.js';
import env from '../config/env.js';
import { hashPassword, verifyPassword } from '../utils/hash.js';
import { signAccessToken, signRefreshToken, verifyRefreshToken } from '../utils/token.js';

function generateOtp() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

async function hashValue(value) {
  return hashPassword(value);
}

function ttlToInterval(ttl) {
  const match = /^([0-9]+)([smhdw])$/i.exec(ttl.trim());
  if (!match) return '30 days';
  const value = Number(match[1]);
  const unit = match[2].toLowerCase();
  switch (unit) {
    case 's':
      return `${value} seconds`;
    case 'm':
      return `${value} minutes`;
    case 'h':
      return `${value} hours`;
    case 'd':
      return `${value} days`;
    case 'w':
      return `${value * 7} days`;
    default:
      return '30 days';
  }
}

const refreshInterval = ttlToInterval(env.jwt.refreshTtl);

export async function signupStep1({ fullName, username, email, password, phoneCountryCode, phoneNumber }) {
  const existing = await db.query(
    `SELECT user_id FROM civic_app.users WHERE username = $1 OR email = $2`,
    [username, email]
  );
  if (existing.rowCount > 0) {
    throw createError(409, 'Username or email already taken');
  }

  const hashedPassword = await hashPassword(password);
  const otp = generateOtp();
  const otpHash = await hashValue(otp);

  const result = await withTransaction(async (client) => {
    const userRes = await client.query(
      `INSERT INTO civic_app.users (full_name, username, email, hashed_password, phone_country_code, phone_number)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING user_id, full_name, username, email, phone_country_code, phone_number, account_status, role`,
      [fullName, username, email, hashedPassword, phoneCountryCode, phoneNumber]
    );
    const user = userRes.rows[0];

    await client.query(
      `INSERT INTO civic_app.phone_verifications (user_id, phone_country_code, phone_number, code_hash, expires_at)
       VALUES ($1, $2, $3, $4, NOW() + INTERVAL '10 minutes')`,
      [user.user_id, phoneCountryCode, phoneNumber, otpHash]
    );

    return user;
  });

  return { user: result, otp };
}

export async function signupStep2({ userId, idNumber, frontIdUrl, backIdUrl }) {
  return withTransaction(async (client) => {
    const userRes = await client.query(
      `UPDATE civic_app.users SET id_number = $1 WHERE user_id = $2 RETURNING user_id`,
      [idNumber, userId]
    );
    if (userRes.rowCount === 0) {
      throw createError(404, 'User not found');
    }

    await client.query(
      `INSERT INTO civic_app.user_identity_documents (user_id, document_type, file_url)
       VALUES ($1, 'national_id_front', $2)
       ON CONFLICT (user_id, document_type) DO UPDATE SET file_url = EXCLUDED.file_url, uploaded_at = NOW()`,
      [userId, frontIdUrl]
    );

    await client.query(
      `INSERT INTO civic_app.user_identity_documents (user_id, document_type, file_url)
       VALUES ($1, 'national_id_back', $2)
       ON CONFLICT (user_id, document_type) DO UPDATE SET file_url = EXCLUDED.file_url, uploaded_at = NOW()`,
      [userId, backIdUrl]
    );

    const verificationRes = await client.query(
      `INSERT INTO civic_app.account_verifications (user_id)
       VALUES ($1)
       ON CONFLICT (user_id) WHERE status = 'pending' DO NOTHING
       RETURNING verification_id, status`,
      [userId]
    );

    return {
      userId,
      verification: verificationRes.rows[0] || null
    };
  });
}

export async function signupStep3({ userId, selfieUrl }) {
  return withTransaction(async (client) => {
    await client.query(
      `INSERT INTO civic_app.user_identity_documents (user_id, document_type, file_url)
       VALUES ($1, 'selfie', $2)
       ON CONFLICT (user_id, document_type) DO UPDATE SET file_url = EXCLUDED.file_url, uploaded_at = NOW()`,
      [userId, selfieUrl]
    );

    const result = await client.query(
      `SELECT account_status FROM civic_app.users WHERE user_id = $1`,
      [userId]
    );
    if (result.rowCount === 0) {
      throw createError(404, 'User not found');
    }

    return { userId, accountStatus: result.rows[0].account_status };
  });
}

export async function requestPhoneCode({ userId }) {
  const user = await db.query(
    `SELECT user_id, phone_country_code, phone_number FROM civic_app.users WHERE user_id = $1`,
    [userId]
  );
  if (user.rowCount === 0) throw createError(404, 'User not found');
  const { phone_country_code: countryCode, phone_number: number } = user.rows[0];
  if (!countryCode || !number) throw createError(400, 'Phone number missing');

  const otp = generateOtp();
  const otpHash = await hashValue(otp);

  await db.query(
    `INSERT INTO civic_app.phone_verifications (user_id, phone_country_code, phone_number, code_hash, expires_at)
     VALUES ($1, $2, $3, $4, NOW() + INTERVAL '10 minutes')`,
    [userId, countryCode, number, otpHash]
  );

  return { userId, otp };
}

export async function verifyPhone({ userId, code }) {
  const result = await db.query(
    `SELECT phone_verification_id, code_hash, expires_at FROM civic_app.phone_verifications
     WHERE user_id = $1 AND verified_at IS NULL
     ORDER BY created_at DESC
     LIMIT 1`,
    [userId]
  );
  if (result.rowCount === 0) throw createError(404, 'Verification code not found');

  const verification = result.rows[0];
  if (verification.expires_at < new Date()) throw createError(410, 'Verification code expired');
  const matches = await verifyPassword(code, verification.code_hash);
  if (!matches) throw createError(401, 'Invalid verification code');

  await withTransaction(async (client) => {
    await client.query(
      `UPDATE civic_app.phone_verifications
       SET verified_at = NOW()
       WHERE phone_verification_id = $1`,
      [verification.phone_verification_id]
    );

    await client.query(
      `UPDATE civic_app.users SET phone_verified_at = NOW()
       WHERE user_id = $1`,
      [userId]
    );
  });

  return { userId, verified: true };
}

async function findUserByIdentifier(identifier) {
  return db.query(
    `SELECT user_id, username, email, hashed_password, account_status, role, failed_login_attempts, locked_until
     FROM civic_app.users
     WHERE username = $1 OR email = $1`,
    [identifier]
  );
}

async function incrementFailedAttempts(userId) {
  await db.query(
    `UPDATE civic_app.users
     SET failed_login_attempts = failed_login_attempts + 1,
         locked_until = CASE WHEN failed_login_attempts + 1 >= 5 THEN NOW() + INTERVAL '15 minutes' ELSE locked_until END
     WHERE user_id = $1`,
    [userId]
  );
}

async function resetFailedAttempts(userId) {
  await db.query(
    `UPDATE civic_app.users SET failed_login_attempts = 0, locked_until = NULL WHERE user_id = $1`,
    [userId]
  );
}

export async function login({ identifier, password }, { clientIp, userAgent, deviceName }) {
  const userRes = await findUserByIdentifier(identifier);
  if (userRes.rowCount === 0) throw createError(401, 'Invalid credentials');
  const user = userRes.rows[0];

  if (user.locked_until && user.locked_until > new Date()) {
    throw createError(423, 'Account temporarily locked');
  }

  const valid = await verifyPassword(password, user.hashed_password);
  if (!valid) {
    await incrementFailedAttempts(user.user_id);
    throw createError(401, 'Invalid credentials');
  }

  await resetFailedAttempts(user.user_id);

  const sessionId = uuidv4();
  const accessToken = signAccessToken({ sub: user.user_id, role: user.role });
  const refreshToken = signRefreshToken({ sub: user.user_id, role: user.role, sid: sessionId });
  const refreshHash = await hashValue(refreshToken);

  await db.query(
    `INSERT INTO civic_app.user_sessions (
      session_id, user_id, refresh_token_hash, client_ip, user_agent, device_name,
      remember_me, expires_at
    ) VALUES ($1, $2, $3, $4, $5, $6, FALSE, NOW() + $7::interval)`,
    [sessionId, user.user_id, refreshHash, clientIp || null, userAgent || null, deviceName || null, refreshInterval]
  );

  await db.query(
    `UPDATE civic_app.users SET last_login_at = NOW() WHERE user_id = $1`,
    [user.user_id]
  );

  return {
    tokens: { accessToken, refreshToken },
    sessionId,
    user: {
      userId: user.user_id,
      username: user.username,
      email: user.email,
      role: user.role,
      accountStatus: user.account_status
    }
  };
}

export async function refreshTokens(refreshToken) {
  let decoded;
  try {
    decoded = verifyRefreshToken(refreshToken);
  } catch (error) {
    throw createError(401, 'Invalid refresh token');
  }

  const sessionRes = await db.query(
    `SELECT session_id, user_id, refresh_token_hash, revoked_at, expires_at
     FROM civic_app.user_sessions WHERE session_id = $1`,
    [decoded.sid]
  );
  if (sessionRes.rowCount === 0) throw createError(401, 'Session not found');
  const session = sessionRes.rows[0];
  if (session.revoked_at || session.expires_at < new Date()) throw createError(401, 'Session expired');

  const matches = await verifyPassword(refreshToken, session.refresh_token_hash);
  if (!matches) throw createError(401, 'Invalid refresh token');

  const userRes = await db.query(
    `SELECT user_id, role, account_status FROM civic_app.users WHERE user_id = $1`,
    [session.user_id]
  );
  if (userRes.rowCount === 0) throw createError(404, 'User missing');
  const user = userRes.rows[0];

  const newAccess = signAccessToken({ sub: user.user_id, role: user.role });
  const newRefresh = signRefreshToken({ sub: user.user_id, role: user.role, sid: session.session_id });
  const newHash = await hashValue(newRefresh);

  await db.query(
    `UPDATE civic_app.user_sessions
     SET refresh_token_hash = $1,
         last_used_at = NOW(),
         expires_at = NOW() + $2::interval
     WHERE session_id = $3`,
    [newHash, refreshInterval, session.session_id]
  );

  return {
    tokens: { accessToken: newAccess, refreshToken: newRefresh },
    user: {
      userId: user.user_id,
      role: user.role,
      accountStatus: user.account_status
    }
  };
}

export async function logout(sessionId) {
  await db.query(
    `UPDATE civic_app.user_sessions SET revoked_at = NOW() WHERE session_id = $1`,
    [sessionId]
  );
}

export async function getUserById(userId) {
  const res = await db.query(
    `SELECT user_id, full_name, username, email, phone_country_code, phone_number,
            account_status, role, phone_verified_at, created_at
     FROM civic_app.users WHERE user_id = $1`,
    [userId]
  );
  if (res.rowCount === 0) throw createError(404, 'User not found');
  return res.rows[0];
}

export async function changePassword(userId, currentPassword, newPassword) {
  const res = await db.query(
    `SELECT hashed_password FROM civic_app.users WHERE user_id = $1`,
    [userId]
  );
  if (res.rowCount === 0) throw createError(404, 'User not found');
  const matches = await verifyPassword(currentPassword, res.rows[0].hashed_password);
  if (!matches) throw createError(401, 'Invalid current password');

  const hashed = await hashPassword(newPassword);
  await db.query(
    `UPDATE civic_app.users SET hashed_password = $1, password_changed_at = NOW()
     WHERE user_id = $2`,
    [hashed, userId]
  );
}
