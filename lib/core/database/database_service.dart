import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';


import '../security/crypto_utils.dart';
import '../security/secure_storage_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;
  final SecureStorageService _secureStorage = SecureStorageService();
  
  static final List<Future<void> Function(Database)> onDbOpen = [];

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'narcos.db');

    // Bootstrap DB key from secure storage (Option A)
    // 32 random bytes stored as hex
    final dbKeyHex = await _secureStorage.getOrCreateDbKey(() {
      return _bytesToHex(CryptoUtils.generateRandomBytes(32));
    });

    try {
      return await openDatabase(
        path,
        version: 6,
        password: dbKeyHex,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) async {
          await db.insert('app_preferences', {'key': 'confidence_green_threshold', 'value': '0.8'}, conflictAlgorithm: ConflictAlgorithm.ignore);
          await db.insert('app_preferences', {'key': 'confidence_yellow_threshold', 'value': '0.5'}, conflictAlgorithm: ConflictAlgorithm.ignore);
          for (final callback in onDbOpen) {
            await callback(db);
          }
        },
      );
    } catch (e) {
      // If the database was previously unencrypted or the key changed on the emulator, wipe it and recreate.
      await deleteDatabase(path);
      return await openDatabase(
        path,
        version: 6,
        password: dbKeyHex,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) async {
          await db.insert('app_preferences', {'key': 'confidence_green_threshold', 'value': '0.8'}, conflictAlgorithm: ConflictAlgorithm.ignore);
          await db.insert('app_preferences', {'key': 'confidence_yellow_threshold', 'value': '0.5'}, conflictAlgorithm: ConflictAlgorithm.ignore);
          for (final callback in onDbOpen) {
            await callback(db);
          }
        },
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // 1. Credentials table
    batch.execute('''
      CREATE TABLE credentials (
        operator_id     TEXT PRIMARY KEY,
        name            TEXT NOT NULL,
        rank            TEXT,
        jurisdiction    TEXT,
        role            TEXT DEFAULT 'OPERATOR',
        pin_hash        BLOB NOT NULL,
        pin_salt        BLOB NOT NULL,
        wrap_salt       BLOB NOT NULL,
        recovery_salt   BLOB NOT NULL,
        failed_attempts INTEGER DEFAULT 0,
        locked_until    INTEGER
      )
    ''');

    // 2. Keys table
    batch.execute('''
      CREATE TABLE keys (
        operator_id    TEXT PRIMARY KEY,
        public_key_jwk TEXT NOT NULL,
        FOREIGN KEY (operator_id) REFERENCES credentials(operator_id)
      )
    ''');

    // 3. Sessions table
    batch.execute('''
      CREATE TABLE sessions (
        operator_id     TEXT PRIMARY KEY,
        last_active     INTEGER NOT NULL,
        created_at      INTEGER NOT NULL,
        expires_at      INTEGER NOT NULL,
        inactivity_lock INTEGER,
        FOREIGN KEY (operator_id) REFERENCES credentials(operator_id)
      )
    ''');

    // 5. Sync Queue
    batch.execute('''
      CREATE TABLE sync_queue (
        id           TEXT PRIMARY KEY,
        type         TEXT NOT NULL,
        payload      TEXT NOT NULL,
        queued_at    INTEGER NOT NULL,
        status       TEXT DEFAULT 'pending',
        attempts     INTEGER DEFAULT 0,
        last_attempt INTEGER
      )
    ''');

    // 6. Audit Log
    batch.execute('''
      CREATE TABLE audit_log (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        operator_id TEXT,
        action      TEXT NOT NULL,
        detail      TEXT,
        created_at  INTEGER NOT NULL
      )
    ''');

    await batch.commit(noResult: true);
    // Execute all upgrades internally as well for new DBs
    await _onUpgrade(db, 1, 6);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE app_preferences (
          key   TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      // Seed defaults
      await db.insert('app_preferences', {'key': 'theme_mode', 'value': 'dark'});
      await db.insert('app_preferences', {'key': 'onboarding_complete', 'value': '0'});
    }
    if (oldVersion < 3) {
      await db.insert('app_preferences', {'key': 'quality_min_luminance', 'value': '40'});
      await db.insert('app_preferences', {'key': 'quality_blur_threshold', 'value': '100'});
      await db.insert('app_preferences', {'key': 'quality_card_min_area', 'value': '0.15'});
    }
    if (oldVersion < 4) {
      await db.insert('app_preferences', {'key': 'calibration_delta_e_warn', 'value': '5.0'});
      await db.insert('app_preferences', {'key': 'calibration_delta_e_fail', 'value': '10.0'});
    }
    if (oldVersion < 5) {
      await db.execute('DROP TABLE IF EXISTS records');
      await db.execute('''
        CREATE TABLE record_counters (
          jurisdiction  TEXT PRIMARY KEY,
          year          INTEGER NOT NULL,
          counter       INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE records (
          id                        INTEGER PRIMARY KEY AUTOINCREMENT,
          record_id                 TEXT NOT NULL UNIQUE,
          operator_id               TEXT NOT NULL,
          operator_name             TEXT NOT NULL,
          raw_json                  TEXT NOT NULL,
          result                    TEXT,
          kit_used                  TEXT,
          confidence                INTEGER,
          is_inconclusive           INTEGER DEFAULT 0,
          is_unknown                INTEGER DEFAULT 0,
          gps_lat                   REAL,
          gps_lng                   REAL,
          address                   TEXT,
          case_number               TEXT,
          raw_image_path            TEXT,
          calibrated_image_path     TEXT,
          raw_image_hash            TEXT NOT NULL,
          calibrated_image_hash     TEXT NOT NULL,
          record_hash               TEXT NOT NULL,
          signature                 TEXT NOT NULL,
          cloudinary_raw_id         TEXT,
          cloudinary_calibrated_id  TEXT,
          synced                    INTEGER DEFAULT 0,
          created_at                INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE VIRTUAL TABLE records_fts USING fts5(
          record_id, operator_name, address, result, case_number, content='records', content_rowid='id'
        )
      ''');
      await db.execute('''
        CREATE TRIGGER records_ai AFTER INSERT ON records BEGIN
          INSERT INTO records_fts(rowid, record_id, operator_name, address, result, case_number)
          VALUES (new.id, new.record_id, new.operator_name, new.address, new.result, new.case_number);
        END;
      ''');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE records ADD COLUMN is_disputed INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE records ADD COLUMN dispute_note TEXT');
      await db.execute('ALTER TABLE records ADD COLUMN supervisor_id TEXT');
      await db.execute('ALTER TABLE records ADD COLUMN supervisor_signature TEXT');
      
      await db.execute('ALTER TABLE audit_log ADD COLUMN record_id TEXT');
      await db.execute('CREATE INDEX idx_audit_log_record ON audit_log(record_id)');
      await db.execute('CREATE INDEX idx_audit_log_created ON audit_log(created_at DESC)');
    }
  }

  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // --- Utility queries for auth/sessions ---

  Future<bool> isFirstRun() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM credentials');
    final count = result.first['count'] as int? ?? 0;
    return count == 0;
  }
}
