import { readFile } from 'node:fs/promises'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import pg from 'pg'

const { Client } = pg

async function main () {
  const connectionString = process.env.DATABASE_URL
  if (!connectionString) {
    console.error('DATABASE_URL is not set.')
    process.exit(1)
  }

  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false }
  })

  let connected = false

  try {
    await client.connect()
    connected = true

    const existingSeed = await client.query(
      'SELECT 1 FROM information_schema.tables WHERE table_schema = \'public\' AND table_name = \'users\';'
    )

    if (existingSeed.rowCount > 0) {
      console.log("Schema 'public' already contains base tables. Skipping initialization.")
      return
    }

    const currentDir = dirname(fileURLToPath(import.meta.url))
    const sqlPath = resolve(currentDir, '..', '..', 'database.sql')
    const rawSql = await readFile(sqlPath, 'utf8')
    const normalizedSql = rawSql.replace(/''([A-Za-z0-9_]+)''/g, "'$1'")

    console.log('Applying schema to database...')
    await client.query(normalizedSql)
    console.log('Schema applied successfully.')
  } catch (error) {
    console.error('Failed to apply schema:', error)
    process.exitCode = 1
  } finally {
    if (connected) {
      await client.end().catch((closeError) => {
        console.error('Failed to close database connection:', closeError)
      })
    }
  }
}

main()
