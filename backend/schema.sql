-- Operators table
CREATE TABLE operators (
  operator_id       TEXT PRIMARY KEY,
  name              TEXT NOT NULL,
  rank              TEXT,
  jurisdiction      TEXT,
  role              TEXT DEFAULT 'OPERATOR',
  public_key_jwk    TEXT NOT NULL,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- Records table
CREATE TABLE records (
  record_id         TEXT PRIMARY KEY,
  operator_id       TEXT REFERENCES operators,
  raw_json          JSONB NOT NULL,      -- full canonical JSON
  result            TEXT,
  kit_used          TEXT,
  confidence        FLOAT,
  gps_lat           FLOAT,
  gps_lng           FLOAT,
  address           TEXT,
  case_number       TEXT,
  synced_at         TIMESTAMPTZ DEFAULT NOW(),
  -- integrity fields (indexed for fast verification)
  hash_record       TEXT NOT NULL,
  signature         TEXT NOT NULL,
  supervisor_id     TEXT REFERENCES operators,
  supervisor_signature TEXT
);

-- Audit log
CREATE TABLE audit_log (
  id                BIGSERIAL PRIMARY KEY,
  actor_id          TEXT,
  action            TEXT,
  record_id         TEXT,
  detail            JSONB,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- Kit expiry tracking
CREATE TABLE kit_inventory (
  id                BIGSERIAL PRIMARY KEY,
  operator_id       TEXT REFERENCES operators,
  kit_type          TEXT,
  lot_number        TEXT,
  expiry_date       DATE,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);
