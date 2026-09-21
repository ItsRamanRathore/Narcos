require('dotenv').config();
const fastify = require('fastify')({ logger: true });

// Register JWT
fastify.register(require('@fastify/jwt'), {
  secret: process.env.JWT_SECRET || 'super-secret'
});

// Register Postgres
fastify.register(require('@fastify/postgres'), {
  connectionString: process.env.DATABASE_URL
});

// Register Rate Limit
fastify.register(require('@fastify/rate-limit'), {
  max: 100,
  timeWindow: '1 minute'
});

// Auth Route
fastify.post('/api/v1/operators/register', async (request, reply) => {
  const { operator_id, name, rank, jurisdiction, public_key_jwk } = request.body;
  const client = await fastify.pg.connect();
  try {
    const { rows } = await client.query(
      'INSERT INTO operators (operator_id, name, rank, jurisdiction, public_key_jwk) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [operator_id, name, rank, jurisdiction, public_key_jwk]
    );
    reply.send(rows[0]);
  } catch (err) {
    reply.status(500).send({ error: 'Database error', detail: err.message });
  } finally {
    client.release();
  }
});

fastify.post('/api/v1/auth/token', async (request, reply) => {
  const { operator_id, signature } = request.body;
  // Simplified auth: normally we'd verify the signature with public_key_jwk
  const token = fastify.jwt.sign({ operator_id });
  reply.send({ token });
});

// Protect routes
fastify.decorate("authenticate", async function (request, reply) {
  try {
    await request.jwtVerify();
  } catch (err) {
    reply.send(err);
  }
});

// Sync records
fastify.post('/api/v1/records/sync', { preValidation: [fastify.authenticate] }, async (request, reply) => {
  const { records } = request.body;
  const client = await fastify.pg.connect();
  try {
    await client.query('BEGIN');
    const syncedIds = [];
    for (const record of records) {
      // Upsert record
      await client.query(
        `INSERT INTO records (record_id, operator_id, raw_json, result, kit_used, confidence, hash_record, signature) 
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         ON CONFLICT (record_id) DO UPDATE SET
         synced_at = NOW()`,
        [record.recordId, record.operatorId, record.rawJson, record.result, record.kitUsed, record.confidence, record.hashRecord, record.signature]
      );
      syncedIds.push(record.recordId);
    }
    await client.query('COMMIT');
    reply.send({ success: true, syncedIds });
  } catch (err) {
    await client.query('ROLLBACK');
    reply.status(500).send({ error: 'Sync failed', detail: err.message });
  } finally {
    client.release();
  }
});

// Search/Filter records
fastify.get('/api/v1/records', { preValidation: [fastify.authenticate] }, async (request, reply) => {
  const client = await fastify.pg.connect();
  try {
    const { rows } = await client.query('SELECT * FROM records ORDER BY synced_at DESC LIMIT 50');
    reply.send(rows);
  } finally {
    client.release();
  }
});

const start = async () => {
  try {
    await fastify.listen({ port: 3000, host: '0.0.0.0' });
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};
start();
