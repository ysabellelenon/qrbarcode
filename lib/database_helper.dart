import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'users.db');
    
    return await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createTables(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('DROP TABLE IF EXISTS item_codes');
    await db.execute('DROP TABLE IF EXISTS items');
    await db.execute('DROP TABLE IF EXISTS users');

    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firstName TEXT,
        middleName TEXT,
        lastName TEXT,
        section TEXT,
        lineNo TEXT,
        username TEXT,
        password TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemCode TEXT,
        revision TEXT,
        codeCount TEXT,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE item_codes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemId INTEGER,
        category TEXT,
        content TEXT,
        hasSubLot INTEGER,
        serialCount TEXT,
        FOREIGN KEY (itemId) REFERENCES items (id)
      )
    ''');
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final db = await database;
    return await db.query('users');
  }

  Future<void> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    await db.insert('users', user);
  }

  Future<void> updateUser(Map<String, dynamic> user) async {
    final db = await database;
    await db.update(
      'users',
      user,
      where: 'id = ?',
      whereArgs: [user['id']],
    );
  }

  Future<List<Map<String, dynamic>>> getItems() async {
    final db = await database;
    final List<Map<String, dynamic>> items = await db.query('items', orderBy: 'id DESC');
    final List<Map<String, dynamic>> result = [];
    
    // For each item, fetch its codes and create a new map
    for (var item in items) {
      final codes = await db.query(
        'item_codes',
        where: 'itemId = ?',
        whereArgs: [item['id']],
      );
      
      // Create a new map with all item data plus codes
      result.add({
        ...Map<String, dynamic>.from(item),
        'codes': codes,
      });
    }
    
    return result;
  }

  Future<void> insertItem(Map<String, dynamic> item) async {
    final db = await database;
    
    await db.transaction((txn) async {
      final itemId = await txn.insert('items', {
        'itemCode': item['itemCode'],
        'revision': item['revision'],
        'codeCount': item['codeCount'],
      });

      for (var code in (item['codes'] as List)) {
        await txn.insert('item_codes', {
          'itemId': itemId,
          'category': code['category'],
          'content': code['content'],
          'hasSubLot': code['hasSubLot'] ? 1 : 0,
          'serialCount': code['serialCount'],
        });
      }
    });
  }

  Future<void> updateItem(int itemId, Map<String, dynamic> item) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.update(
        'items',
        {
          'itemCode': item['itemCode'],
          'revision': item['revision'],
          'codeCount': item['codeCount'],
        },
        where: 'id = ?',
        whereArgs: [itemId],
      );

      // Delete existing codes
      await txn.delete(
        'item_codes',
        where: 'itemId = ?',
        whereArgs: [itemId],
      );

      // Insert updated codes
      for (var code in (item['codes'] as List)) {
        await txn.insert('item_codes', {
          'itemId': itemId,
          'category': code['category'],
          'content': code['content'],
          'hasSubLot': code['hasSubLot'] ? 1 : 0,
          'serialCount': code['serialCount'],
        });
      }
    });
  }

  Future<void> deleteItems(List<int> ids) async {
    final db = await database;
    await db.delete(
      'items',
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }

  Future<Map<String, dynamic>?> getUserByUsernameAndPassword(String username, String password) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }
} 