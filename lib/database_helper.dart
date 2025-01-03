import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'dart:convert';

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
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    final Directory dbDirectory =
        Directory(join(documentsDirectory.path, 'databases'));
    if (!await dbDirectory.exists()) {
      await dbDirectory.create(recursive: true);
    }

    final String path = join(dbDirectory.path, 'users.db');
    print('Database path: $path');

    bool shouldCopy = !await File(path).exists();

    if (shouldCopy) {
      try {
        ByteData data = await rootBundle.load('assets/databases/users.db');
        List<int> bytes = data.buffer.asUint8List();
        await File(path).writeAsBytes(bytes, flush: true);
        print('Database copied from assets successfully');
      } catch (e) {
        print('Error copying database from assets: $e');
        shouldCopy = false;
      }
    }

    return await openDatabase(
      path,
      version: 7,
      onCreate: (db, version) async {
        await _createTablesIfNotExist(db);
        if ((await db.query('users')).isEmpty) {
          await _insertDefaultUsers(db);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _migrateToVersion2(db);
        }
        if (oldVersion < 3) {
          await _migrateToVersion3(db);
        }
        if (oldVersion < 4) {
          await _addNewTablesIfNotExist(db);
        }
        if (oldVersion < 5) {
          await db.execute('DROP TABLE IF EXISTS item_codes_backup');
          await db
              .execute('ALTER TABLE item_codes RENAME TO item_codes_backup');
          await db.execute('''
            CREATE TABLE item_codes(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              itemId INTEGER,
              category TEXT,
              content TEXT,
              hasSubLot INTEGER NOT NULL DEFAULT 0,
              serialCount TEXT,
              FOREIGN KEY (itemId) REFERENCES items (id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            INSERT INTO item_codes(id, itemId, category, content, hasSubLot, serialCount)
            SELECT id, itemId, category, content, hasSubLot, serialCount
            FROM item_codes_backup
          ''');
          await db.execute('DROP TABLE item_codes_backup');
        }
        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS scan_contents(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              operator_scan_id INTEGER,
              content TEXT,
              result TEXT,
              created_at TEXT DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (operator_scan_id) REFERENCES operator_scans (id) ON DELETE CASCADE
            )
          ''');
        }
        if (oldVersion < 7) {
          // First create new tables with the new structure
          await db.execute('''
            CREATE TABLE IF NOT EXISTS scanning_sessions(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              itemName TEXT,
              poNo TEXT,
              totalQty INTEGER,
              createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS box_labels(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              sessionId INTEGER,
              labelNumber TEXT,
              lotNumber TEXT,
              qtyPerBox TEXT,
              content TEXT,
              createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (sessionId) REFERENCES scanning_sessions (id) ON DELETE CASCADE
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS individual_scans(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              sessionId INTEGER,
              content TEXT,
              result TEXT,
              created_at TEXT DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (sessionId) REFERENCES scanning_sessions (id) ON DELETE CASCADE
            )
          ''');

          // Copy data from old tables to new ones
          await db.execute('''
            INSERT INTO scanning_sessions (id, itemName, poNo, totalQty, createdAt)
            SELECT id, itemName, poNo, totalQty, createdAt FROM operator_scans
          ''');

          await db.execute('''
            INSERT INTO box_labels (id, sessionId, labelNumber, lotNumber, qtyPerBox, content, createdAt)
            SELECT id, operatorScanId, articleLabel, lotNumber, qtyPerBox, content, createdAt 
            FROM article_labels
          ''');

          await db.execute('''
            INSERT INTO individual_scans (id, sessionId, content, result, created_at)
            SELECT id, operator_scan_id, content, result, created_at 
            FROM scan_contents
          ''');

          // Drop old tables
          await db.execute('DROP TABLE IF EXISTS operator_scans');
          await db.execute('DROP TABLE IF EXISTS article_labels');
          await db.execute('DROP TABLE IF EXISTS scan_contents');
        }
      },
      onOpen: (db) async {
        print('Database opened successfully');
      },
    );
  }

  Future<void> _createTablesIfNotExist(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firstName TEXT,
        middleName TEXT,
        lastName TEXT,
        section TEXT,
        lineNo TEXT,
        username TEXT UNIQUE,
        password TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemCode TEXT,
        revision TEXT,
        codeCount TEXT,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS item_codes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemId INTEGER,
        category TEXT,
        content TEXT,
        hasSubLot INTEGER NOT NULL DEFAULT 0,
        serialCount TEXT,
        FOREIGN KEY (itemId) REFERENCES items (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS scanning_sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemName TEXT,
        poNo TEXT,
        totalQty INTEGER,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS box_labels(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId INTEGER,
        labelNumber TEXT,
        lotNumber TEXT,
        qtyPerBox TEXT,
        content TEXT,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (sessionId) REFERENCES scanning_sessions (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS individual_scans(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId INTEGER,
        content TEXT,
        result TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (sessionId) REFERENCES scanning_sessions (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _addNewTablesIfNotExist(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS unfinished_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemName TEXT,
        lotNumber TEXT,
        date TEXT,
        content TEXT,
        poNo TEXT,
        quantity TEXT,
        remarks TEXT,
        tableData TEXT,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<void> _insertDefaultUsers(Database db) async {
    List<Map<String, dynamic>> engineer = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: ['engineer'],
    );

    if (engineer.isEmpty) {
      await db.insert('users', {
        'firstName': 'Engineer',
        'lastName': 'User',
        'username': 'engineer',
        'password': 'password123',
        'section': 'Engineering',
        'lineNo': 'Admin',
      });
      print('Inserted Engineer user with lineNo: Admin');
    } else {
      if (engineer.first['lineNo'] != 'Admin') {
        await db.update(
          'users',
          {'lineNo': 'Admin'},
          where: 'username = ?',
          whereArgs: ['engineer'],
        );
        print('Updated Engineer user\'s lineNo to Admin');
      }
    }

    List<Map<String, dynamic>> operatorUser = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: ['operator'],
    );

    if (operatorUser.isEmpty) {
      await db.insert('users', {
        'firstName': 'Operator',
        'lastName': 'User',
        'username': 'operator',
        'password': 'password123',
        'section': 'Operations',
        'lineNo': 'Assembly',
      });
      print('Inserted Operator user with lineNo: Assembly');
    } else {
      print('Operator user already exists. No action taken.');
    }
  }

  Future<void> _migrateToVersion2(Database db) async {
    await db.update(
      'users',
      {'lineNo': 'Admin'},
      where: 'username = ? AND lineNo != ?',
      whereArgs: ['engineer', 'Admin'],
    );
    print('Migrated Engineer user\'s lineNo to Admin');
  }

  Future<void> _migrateToVersion3(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scanning_sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemName TEXT,
        poNo TEXT,
        totalQty INTEGER,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS box_labels(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId INTEGER,
        labelNumber TEXT,
        lotNumber TEXT,
        qtyPerBox TEXT,
        content TEXT,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (sessionId) REFERENCES scanning_sessions (id) ON DELETE CASCADE
      )
    ''');

    print(
        'Migrated database to version 3: Added scanning_sessions and box_labels tables');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS unfinished_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemName TEXT,
        lotNumber TEXT,
        date TEXT,
        content TEXT,
        poNo TEXT,
        quantity TEXT,
        remarks TEXT,
        tableData TEXT,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final db = await database;
    return await db.query('users');
  }

  Future<void> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    await db.insert('users', user,
        conflictAlgorithm: ConflictAlgorithm.replace);
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
    try {
      final db = await database;
      final List<Map<String, dynamic>> items =
          await db.query('items', orderBy: 'id DESC');
      print('Retrieved ${items.length} items from database');

      final List<Map<String, dynamic>> result = [];

      for (var item in items) {
        final codes = await db.query(
          'item_codes',
          where: 'itemId = ?',
          whereArgs: [item['id']],
        );
        print('Retrieved codes for item ${item['id']}: $codes');

        result.add({
          ...Map<String, dynamic>.from(item),
          'codes': codes,
        });
      }

      return result;
    } catch (e) {
      print('Error retrieving items: $e');
      throw e;
    }
  }

  Future<void> insertItem(Map<String, dynamic> item) async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        final itemId = await txn.insert('items', {
          'itemCode': item['itemCode'],
          'revision': item['revision'],
          'codeCount': item['codeCount'],
        });
        print('Inserted item with ID: $itemId');

        for (var code in (item['codes'] as List)) {
          print('Inserting code: $code');
          final hasSubLot =
              (code['hasSubLot'] == true || code['hasSubLot'] == 1) ? 1 : 0;
          final codeId = await txn.insert('item_codes', {
            'itemId': itemId,
            'category': code['category'],
            'content': code['content'],
            'hasSubLot': hasSubLot,
            'serialCount': code['serialCount'],
          });
          print('Inserted code with ID: $codeId, hasSubLot value: $hasSubLot');
        }
      });
      print('Successfully inserted item and all codes');
    } catch (e) {
      print('Error inserting item: $e');
      throw e;
    }
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

      await txn.delete(
        'item_codes',
        where: 'itemId = ?',
        whereArgs: [itemId],
      );

      for (var code in (item['codes'] as List)) {
        final hasSubLot =
            (code['hasSubLot'] == true || code['hasSubLot'] == 1) ? 1 : 0;
        await txn.insert('item_codes', {
          'itemId': itemId,
          'category': code['category'],
          'content': code['content'],
          'hasSubLot': hasSubLot,
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

  Future<Map<String, dynamic>?> getUserByUsernameAndPassword(
      String username, String password) async {
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

  Future<String> getDatabasePath() async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    final String path = join(documentsDirectory.path, 'databases', 'users.db');
    return path;
  }

  Future<Map<String, List<Map<String, dynamic>>>>
      getAllDatabaseContents() async {
    final db = await database;

    final users = await db.query('users');
    final items = await db.query('items');
    final itemCodes = await db.query('item_codes');

    return {
      'users': users,
      'items': items,
      'item_codes': itemCodes,
    };
  }

  Future<int> insertOperatorScan(Map<String, dynamic> scan) async {
    final db = await database;
    return await db.insert('scanning_sessions', {
      'itemName': scan['itemName'],
      'poNo': scan['poNo'],
      'totalQty': scan['totalQty'],
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<int> insertArticleLabel(Map<String, dynamic> label) async {
    final db = await database;
    return await db.insert('box_labels', {
      'sessionId': label['operatorScanId'],
      'labelNumber': label['articleLabel'],
      'lotNumber': label['lotNumber'],
      'qtyPerBox': label['qtyPerBox'],
      'content': label['content'],
      'createdAt': label['createdAt'] ?? DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getOperatorScans() async {
    final db = await database;
    return await db.query('scanning_sessions', orderBy: 'createdAt DESC');
  }

  Future<List<Map<String, dynamic>>> getArticleLabels(int sessionId) async {
    final db = await database;
    return await db.query('box_labels',
        where: 'sessionId = ?',
        whereArgs: [sessionId],
        orderBy: 'createdAt DESC');
  }

  Future<void> verifyDatabaseTables() async {
    final db = await database;
    try {
      // Get list of all tables
      final tables = await db
          .query('sqlite_master', where: 'type = ?', whereArgs: ['table']);

      print('\nDatabase Tables:');
      print('---------------');
      for (var table in tables) {
        print('Table: ${table['name']}');
        // Get count of records in each table
        final count = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM ${table['name']}'));
        print('Record count: $count');
      }
    } catch (e) {
      print('Error verifying tables: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getHistoricalScans(String itemName,
      {int page = 1, int pageSize = 10}) async {
    final db = await database;
    final offset = (page - 1) * pageSize;
    return await db.rawQuery('''
      SELECT s.*, ss.itemName, ss.poNo
      FROM individual_scans s
      JOIN scanning_sessions ss ON s.sessionId = ss.id
      WHERE ss.itemName = ?
      ORDER BY s.created_at DESC
      LIMIT ? OFFSET ?
    ''', [itemName, pageSize, offset]);
  }

  Future<int> getTotalScansForItem(String itemName) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM individual_scans s
      JOIN scanning_sessions ss ON s.sessionId = ss.id
      WHERE ss.itemName = ?
    ''', [itemName]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getHistoricalScansCount(String itemName) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM individual_scans s
      JOIN scanning_sessions ss ON s.sessionId = ss.id
      WHERE ss.itemName = ?
    ''', [itemName]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> insertScanContent(
      int sessionId, String content, String result) async {
    final db = await database;
    return await db.insert('individual_scans', {
      'sessionId': sessionId,
      'content': content,
      'result': result,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getScanContents(int sessionId) async {
    final db = await database;
    return await db.query(
      'individual_scans',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
  }

  Future<Map<String, int>> getTotalGoodNoGoodCounts(String itemName) async {
    final db = await database;

    final List<Map<String, dynamic>> goodCount = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM individual_scans s
      JOIN scanning_sessions ss ON s.sessionId = ss.id
      WHERE ss.itemName = ? AND s.result = 'Good'
    ''', [itemName]);

    final List<Map<String, dynamic>> noGoodCount = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM individual_scans s
      JOIN scanning_sessions ss ON s.sessionId = ss.id
      WHERE ss.itemName = ? AND s.result = 'No Good'
    ''', [itemName]);

    return {
      'goodCount': Sqflite.firstIntValue(goodCount) ?? 0,
      'noGoodCount': Sqflite.firstIntValue(noGoodCount) ?? 0,
    };
  }
}
