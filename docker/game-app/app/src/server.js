const express = require('express');
const { Pool } = require('pg');
const path = require('path');

const app = express();
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

async function initDb(retries = 15) {
  for (let i = 0; i < retries; i++) {
    try {
      await pool.query(`
        CREATE TABLE IF NOT EXISTS counter (
          id INTEGER PRIMARY KEY DEFAULT 1,
          value INTEGER NOT NULL DEFAULT 0,
          CONSTRAINT single_row CHECK (id = 1)
        )
      `);
      await pool.query(
        `INSERT INTO counter (id, value) VALUES (1, 0) ON CONFLICT (id) DO NOTHING`
      );
      console.log('Database ready');
      return;
    } catch (err) {
      console.log(`Waiting for DB (${i + 1}/${retries}): ${err.message}`);
      await new Promise((r) => setTimeout(r, 2000));
    }
  }
  throw new Error('Cannot connect to database after multiple retries');
}

app.get('/api/counter', async (req, res) => {
  try {
    const { rows } = await pool.query('SELECT value FROM counter WHERE id = 1');
    res.json({ value: rows[0]?.value ?? 0 });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/counter/increment', async (req, res) => {
  try {
    const { rows } = await pool.query(
      'UPDATE counter SET value = value + 1 WHERE id = 1 RETURNING value'
    );
    res.json({ value: rows[0].value });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

initDb()
  .then(() => app.listen(3000, () => console.log('App listening on port 3000')))
  .catch((err) => {
    console.error(err.message);
    process.exit(1);
  });
