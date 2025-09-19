import pg from 'pg';
import env from './env.js';

const { Pool } = pg;

export const pool = new Pool({
  connectionString: env.databaseUrl,
  max: env.poolMax,
  idleTimeoutMillis: env.poolIdleTimeout
});

pool.on('error', (err) => {
  console.error('PostgreSQL pool error', err);
});

export const db = {
  query: (text, params) => pool.query(text, params),
  async getClient() {
    return pool.connect();
  }
};

export async function withTransaction(callback) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export default db;
