import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Dịch vụ quản lý lưu trữ cục bộ:
/// 1. SQLite: Lưu các giao dịch ngân hàng bắt được chờ chia bill và cache danh mục ngân hàng
/// 2. Secure Storage: Lưu trữ an toàn JWT Token và thông tin định danh
class LocalStorageService {
  static const String _dbName = 'billsplit_local.db';
  static const int _dbVersion = 1;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        // 1. Bảng lưu các giao dịch ngân hàng tự động bắt được từ notification
        await db.execute('''
          CREATE TABLE pending_transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bank_name TEXT NOT NULL,
            amount REAL NOT NULL,
            transaction_type TEXT NOT NULL,
            raw_content TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            is_processed INTEGER DEFAULT 0
          )
        ''');

        // 2. Bảng cache danh mục ngân hàng phục vụ mở offline
        await db.execute('''
          CREATE TABLE bank_cache (
            bin TEXT PRIMARY KEY,
            short_name TEXT NOT NULL,
            full_name TEXT NOT NULL,
            logo_url TEXT
          )
        ''');

        // 3. Bảng lưu các khoản nợ của người ngoài app nhập tay khi offline
        await db.execute('''
          CREATE TABLE local_debts (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            debtor_name TEXT NOT NULL,
            amount REAL NOT NULL,
            status TEXT DEFAULT 'PENDING',
            created_at INTEGER NOT NULL,
            paid_at INTEGER
          )
        ''');
      },
    );
  }

  // Quản lý Secure Storage (Token)
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: 'jwt_token', value: token);
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: 'jwt_token');
  }

  Future<void> clearToken() async {
    await _secureStorage.delete(key: 'jwt_token');
  }

  // Quản lý cache thông tin User (tránh phải gọi lại API khi mở app, vì Backend
  // chưa có endpoint GET /users/profile - xem Module 2 trong spec, chưa triển khai).
  Future<void> saveUserJson(String userJson) async {
    await _secureStorage.write(key: 'user_json', value: userJson);
  }

  Future<String?> getUserJson() async {
    return await _secureStorage.read(key: 'user_json');
  }

  Future<void> clearUserJson() async {
    await _secureStorage.delete(key: 'user_json');
  }

  // Quản lý Giao dịch chờ chia (Pending Transactions)
  Future<int> insertPendingTransaction({
    required String bankName,
    required double amount,
    required String transactionType,
    required String rawContent,
    required int timestamp,
  }) async {
    final db = await database;
    return await db.insert('pending_transactions', {
      'bank_name': bankName,
      'amount': amount,
      'transaction_type': transactionType,
      'raw_content': rawContent,
      'timestamp': timestamp,
      'is_processed': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getUnprocessedTransactions() async {
    final db = await database;
    return await db.query(
      'pending_transactions',
      where: 'is_processed = ? AND transaction_type = ?',
      whereArgs: [0, 'OUT'],
      orderBy: 'timestamp DESC',
    );
  }

  Future<void> markTransactionAsProcessed(int id) async {
    final db = await database;
    await db.update(
      'pending_transactions',
      {'is_processed': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
