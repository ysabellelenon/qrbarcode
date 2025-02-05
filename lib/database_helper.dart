import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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
      version: 10,
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
              groupNumber INTEGER,
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
            INSERT INTO individual_scans (id, sessionId, content, result, groupNumber)
            SELECT id, operator_scan_id, content, result, groupNumber 
            FROM scan_contents
          ''');

          // Drop old tables
          await db.execute('DROP TABLE IF EXISTS operator_scans');
          await db.execute('DROP TABLE IF EXISTS article_labels');
          await db.execute('DROP TABLE IF EXISTS scan_contents');
        }
        if (oldVersion < 8) {
          // Add new columns to items table
          await db.execute('ALTER TABLE items ADD COLUMN lastUpdated DATETIME');
          await db.execute('ALTER TABLE items ADD COLUMN isActive INTEGER DEFAULT 1');
          
          // Update existing records with default values
          await db.execute('''
            UPDATE items 
            SET lastUpdated = createdAt,
                isActive = 1
            WHERE lastUpdated IS NULL
          ''');
        }
        if (oldVersion < 9) {
          // Add groupNumber column to individual_scans table
          try {
            await db.execute('''
              ALTER TABLE individual_scans 
              ADD COLUMN groupNumber INTEGER
            ''');
            print('Added groupNumber column to individual_scans table');
          } catch (e) {
            print('Error adding groupNumber column: $e');
            // If column already exists, this will fail silently
          }
        }
        if (oldVersion < 10) {
          // Add current_user table in upgrade
          await db.execute('''
            CREATE TABLE IF NOT EXISTS current_user(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id INTEGER
            )
          ''');
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
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
        lastUpdated DATETIME,
        isActive INTEGER DEFAULT 1
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
        groupNumber INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (sessionId) REFERENCES scanning_sessions (id) ON DELETE CASCADE
      )
    ''');

    // Add current_user table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS current_user(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER
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

  Future<void> updateItem(int id, Map<String, dynamic> item) async {
    final db = await database;
    
    try {
      await db.transaction((txn) async {
        // Update the main item
        await txn.update(
          'items',
          {
            'itemCode': item['itemCode'],
            'revision': item['revision'],
            'codeCount': item['codeCount'],
            'lastUpdated': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [id],
        );

        // Delete existing codes
        await txn.delete(
          'item_codes',
          where: 'itemId = ?',
          whereArgs: [id],
        );

        // Insert new codes
        for (var code in (item['codes'] as List)) {
          await txn.insert('item_codes', {
            'itemId': id,
            'category': code['category'],
            'content': code['content'],
            'hasSubLot': code['hasSubLot'] is bool ? (code['hasSubLot'] ? 1 : 0) : code['hasSubLot'],
            'serialCount': code['serialCount']?.toString() ?? '0',
          });
        }
      });
    } catch (e) {
      print('Error in updateItem: $e');
      throw e;
    }
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
    
    // First get the item details to know if it's counting or non-counting
    final items = await db.query('items', where: 'itemCode = ?', whereArgs: [itemName]);
    if (items.isEmpty) return [];
    
    final item = items.first;
    final codes = await db.query('item_codes', where: 'itemId = ?', whereArgs: [item['id']]);
    final isCountingItem = codes.any((code) => code['category'] == 'Counting');

    if (isCountingItem) {
      // For counting items, just return scans in reverse chronological order
      return await db.rawQuery('''
        SELECT s.*, ss.itemName, ss.poNo, NULL as groupNumber
        FROM individual_scans s
        JOIN scanning_sessions ss ON s.sessionId = ss.id
        WHERE ss.itemName = ?
        ORDER BY s.created_at DESC
        LIMIT ? OFFSET ?
      ''', [itemName, pageSize, offset]);
    } else {
      // For non-counting items, include the group number and order by it
      return await db.rawQuery('''
        WITH RankedScans AS (
          SELECT 
            s.*,
            ss.itemName,
            ss.poNo,
            ROW_NUMBER() OVER (PARTITION BY s.groupNumber ORDER BY s.created_at) as row_in_group
          FROM individual_scans s
          JOIN scanning_sessions ss ON s.sessionId = ss.id
          WHERE ss.itemName = ?
        )
        SELECT 
          *,
          CASE 
            WHEN row_in_group = 1 THEN groupNumber 
            ELSE NULL 
          END as display_group_number
        FROM RankedScans
        ORDER BY groupNumber ASC, created_at ASC
        LIMIT ? OFFSET ?
      ''', [itemName, pageSize, offset]);
    }
  }

  Future<int> getTotalScansForItem(String itemName) async {
    final db = await database;
    final result = await db.rawQuery('''
      WITH GroupedScans AS (
        SELECT 
          s.groupNumber,
          COUNT(*) as scans_in_group
        FROM individual_scans s
        JOIN scanning_sessions ss ON s.sessionId = ss.id
        WHERE ss.itemName = ?
        GROUP BY s.groupNumber
      )
      SELECT COUNT(*) as completed_groups
      FROM GroupedScans
      WHERE scans_in_group = (
        SELECT CAST(codeCount AS INTEGER)
        FROM items 
        WHERE itemCode = ?
      )
    ''', [itemName, itemName]);

    // Print debug information
    print('Total completed groups for $itemName: ${result.first['completed_groups']}');
    
    return result.first['completed_groups'] as int? ?? 0;
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

  Future<void> insertScanContent(
    int operatorScanId,
    String content,
    String result, {
    int? groupNumber,
    int? groupPosition,
    int? codesInGroup,
  }) async {
    final db = await database;
    await db.insert(
      'individual_scans',
      {
        'sessionId': operatorScanId,
        'content': content,
        'result': result,
        'groupNumber': groupNumber,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
    final result = await db.rawQuery('''
      WITH GroupedScans AS (
        SELECT 
          s.groupNumber,
          COUNT(*) as scans_in_group,
          MIN(s.result) as group_result
        FROM individual_scans s
        JOIN scanning_sessions ss ON s.sessionId = ss.id
        WHERE ss.itemName = ?
        GROUP BY s.groupNumber
      )
      SELECT 
        SUM(CASE 
          WHEN scans_in_group = (
            SELECT CAST(codeCount AS INTEGER)
            FROM items 
            WHERE itemCode = ?
          ) AND group_result = 'Good' 
          THEN 1 
          ELSE 0 
        END) as goodCount,
        SUM(CASE 
          WHEN scans_in_group = (
            SELECT CAST(codeCount AS INTEGER)
            FROM items 
            WHERE itemCode = ?
          ) AND group_result != 'Good' 
          THEN 1 
          ELSE 0 
        END) as noGoodCount
      FROM GroupedScans
    ''', [itemName, itemName, itemName]);

    // Print debug information
    print('Total Good/No Good counts for $itemName:');
    print('Good count: ${result.first['goodCount']}');
    print('No Good count: ${result.first['noGoodCount']}');

    return {
      'goodCount': result.first['goodCount'] as int? ?? 0,
      'noGoodCount': result.first['noGoodCount'] as int? ?? 0,
    };
  }

  Future<List<Map<String, dynamic>>> getAllHistoricalScans(
      String itemName) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT s.*, ss.itemName, ss.poNo
      FROM individual_scans s
      JOIN scanning_sessions ss ON s.sessionId = ss.id
      WHERE ss.itemName = ?
      ORDER BY s.created_at DESC
    ''', [itemName]);
  }

  Future<int> clearIndividualScans(String itemName) async {
    final db = await database;
    // First get all session IDs for this item
    final sessions = await db.query(
      'scanning_sessions',
      columns: ['id'],
      where: 'itemName = ?',
      whereArgs: [itemName],
    );

    if (sessions.isEmpty) return 0;

    final sessionIds = sessions.map((s) => s['id']).toList();

    // Delete all individual scans for these sessions
    return await db.delete(
      'individual_scans',
      where: 'sessionId IN (${List.filled(sessionIds.length, '?').join(',')})',
      whereArgs: sessionIds,
    );
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    
    if (userId == null) return null;

    final db = await database;
    final List<Map<String, dynamic>> users = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    return users.isNotEmpty ? users.first : null;
  }

  Future<void> setCurrentUserId(int userId) async {
    final db = await database;
    try {
      // First delete any existing entries
      await db.delete('current_user');
      
      // Then insert the new user ID
      await db.insert(
        'current_user',
        {'user_id': userId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error setting current user ID: $e');
      // If there's an error, try to create the table and retry
      await db.execute('''
        CREATE TABLE IF NOT EXISTS current_user(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER
        )
      ''');
      // Retry the insert
      await db.insert(
        'current_user',
        {'user_id': userId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<int?> getCurrentUserId() async {
    final db = await database;
    final result = await db.query('current_user', limit: 1);
    return result.isNotEmpty ? result.first['user_id'] as int : null;
  }

  Future<int> getCompletedGroupsCount(int operatorScanId, int codesPerGroup) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT group_number) as completed_groups
      FROM scan_contents
      WHERE operator_scan_id = ?
      AND group_number IN (
        SELECT group_number
        FROM scan_contents
        WHERE operator_scan_id = ?
        GROUP BY group_number
        HAVING COUNT(*) = ?
      )
    ''', [operatorScanId, operatorScanId, codesPerGroup]);

    return result.first['completed_groups'] as int? ?? 0;
  }
}
