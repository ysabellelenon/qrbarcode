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
    // Get the local app data directory
    final String localAppData = Platform.isWindows
        ? Platform.environment['LOCALAPPDATA']!
        : (await getApplicationDocumentsDirectory()).path;

    final Directory dbDirectory =
        Directory(join(localAppData, 'QRBarcode', 'databases'));
    if (!await dbDirectory.exists()) {
      await dbDirectory.create(recursive: true);
    }

    final String path = join(dbDirectory.path, 'qrbarcode.db');
    print('Database path: $path');

    bool shouldCopy = !await File(path).exists();

    if (shouldCopy) {
      try {
        ByteData data = await rootBundle.load('assets/databases/qrbarcode.db');
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
      version: 12,
      onCreate: (db, version) async {
        await _createTablesIfNotExist(db);
        if ((await db.query('users')).isEmpty) {
          await _insertDefaultUsers(db);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // First ensure license_info table exists
        await _createTablesIfNotExist(db);

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
          await db.execute(
              'ALTER TABLE items ADD COLUMN isActive INTEGER DEFAULT 1');

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
        if (oldVersion < 11) {
          // Add category column to items table
          try {
            await db.execute('ALTER TABLE items ADD COLUMN category TEXT');
            print('Added category column to items table');

            // Update existing items with their category from item_codes
            final items = await db.query('items');
            for (var item in items) {
              final codes = await db.query(
                'item_codes',
                where: 'itemId = ?',
                whereArgs: [item['id']],
              );
              if (codes.isNotEmpty) {
                final category = codes.first['category'];
                await db.update(
                  'items',
                  {'category': category},
                  where: 'id = ?',
                  whereArgs: [item['id']],
                );
              }
            }
          } catch (e) {
            print('Error adding category column: $e');
            // If column already exists, this will fail silently
          }
        }
      },
      onOpen: (db) async {
        print('Database opened successfully');
      },
    );
  }

  Future<void> _createTablesIfNotExist(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS license_info(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        license_key TEXT NOT NULL UNIQUE,
        hardware_id TEXT,
        activated_at TEXT NOT NULL
      )
    ''');

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
        category TEXT,
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS scans(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operatorScanId INTEGER,
        content TEXT,
        result TEXT,
        groupNumber INTEGER,
        groupPosition INTEGER,
        codesInGroup INTEGER,
        sessionId TEXT,
        timestamp TEXT,
        FOREIGN KEY (operatorScanId) REFERENCES operator_scans (id) ON DELETE CASCADE
      )
    ''');

    // Add table for storing current states
    await db.execute('''
      CREATE TABLE IF NOT EXISTS current_states (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemName TEXT,
        poNo TEXT,
        lotNumber TEXT,
        content TEXT,
        operatorScanId INTEGER,
        totalQty INTEGER,
        qtyPerBox TEXT,
        inspectionQty TEXT,
        goodCount TEXT,
        noGoodCount TEXT,
        tableData TEXT,
        sessionId TEXT,
        isQtyPerBoxReached INTEGER,
        isTotalQtyReached INTEGER,
        timestamp TEXT
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

    List<Map<String, dynamic>> devoperatorUser = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: ['dev_operator'],
    );

    if (devoperatorUser.isEmpty) {
      await db.insert('users', {
        'firstName': 'Dev Operator',
        'lastName': 'User',
        'username': 'dev_operator',
        'password': 'pass123',
        'section': 'Operations',
        'lineNo': 'Assembly',
      });
      print('Inserted Dev Operator user with lineNo: Assembly');
    } else {
      print('Dev Operator user already exists. No action taken.');
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
      print('\n=== DEBUG: getItems ===');
      final db = await database;
      final List<Map<String, dynamic>> items =
          await db.query('items', orderBy: 'id DESC');
      print('Retrieved ${items.length} items from database');
      print('Raw items data: $items');

      final List<Map<String, dynamic>> result = [];

      for (var item in items) {
        print('\nProcessing item: ${item['itemCode']}');
        print('Item category from items table: ${item['category']}');

        final codes = await db.query(
          'item_codes',
          where: 'itemId = ?',
          whereArgs: [item['id']],
        );
        print('Retrieved codes: $codes');

        // Get the category from codes if not present in item
        String category = (item['category'] ?? '').toString();
        print('Initial category from items table: $category');

        if (category.isEmpty && codes.isNotEmpty) {
          category = (codes.first['category'] ?? '').toString();
          print('Category from first code: $category');
        }

        final resultItem = {
          ...Map<String, dynamic>.from(item),
          'category': category,
          'codes': codes,
        };
        print('Final item data: $resultItem');
        result.add(resultItem);
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
      print('\n=== DEBUG: updateItem ===');
      print('Updating item with ID: $id');
      print('Item data before update: $item');
      print('Category being set: ${item['category']}');

      await db.transaction((txn) async {
        // Update the main item
        final itemUpdate = {
          'itemCode': item['itemCode'],
          'revision': item['revision'],
          'codeCount': item['codeCount'],
          'category': item['category'],
          'lastUpdated': DateTime.now().toIso8601String(),
        };
        print('Updating items table with: $itemUpdate');

        await txn.update(
          'items',
          itemUpdate,
          where: 'id = ?',
          whereArgs: [id],
        );

        // Delete existing codes
        print('Deleting existing codes for itemId: $id');
        await txn.delete(
          'item_codes',
          where: 'itemId = ?',
          whereArgs: [id],
        );

        // Insert new codes
        print('Inserting new codes:');
        for (var code in (item['codes'] as List)) {
          final codeInsert = {
            'itemId': id,
            'category': code['category'],
            'content': code['content'],
            'hasSubLot': code['hasSubLot'] is bool
                ? (code['hasSubLot'] ? 1 : 0)
                : code['hasSubLot'],
            'serialCount': code['serialCount']?.toString() ?? '0',
          };
          print('Inserting code: $codeInsert');
          await txn.insert('item_codes', codeInsert);
        }
      });

      // Verify the update
      final updatedItem = await db.query(
        'items',
        where: 'id = ?',
        whereArgs: [id],
      );
      print('Item after update: ${updatedItem.first}');

      final updatedCodes = await db.query(
        'item_codes',
        where: 'itemId = ?',
        whereArgs: [id],
      );
      print('Codes after update: $updatedCodes');
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
    final String path =
        join(documentsDirectory.path, 'databases', 'qrbarcode.db');
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

    print('\n=== DEBUG: getHistoricalScans ===');
    print('Item Name: $itemName');
    print('Page: $page, PageSize: $pageSize, Offset: $offset');

    // First get the item details to know if it's counting or non-counting
    final items =
        await db.query('items', where: 'itemCode = ?', whereArgs: [itemName]);
    if (items.isEmpty) {
      print('No item found with itemCode: $itemName');
      return [];
    }

    final item = items.first;
    print('Found item: ${item['itemCode']}');

    final codes = await db
        .query('item_codes', where: 'itemId = ?', whereArgs: [item['id']]);
    final isCountingItem = codes.any((code) => code['category'] == 'Counting');
    print('Is counting item: $isCountingItem');

    List<Map<String, dynamic>> results;
    if (isCountingItem) {
      print('Processing as counting item...');
      results = await db.rawQuery('''
        WITH RankedScans AS (
          SELECT 
            s.*,
            ss.itemName,
            ss.poNo,
            s.groupNumber,
            ROW_NUMBER() OVER (PARTITION BY s.sessionId, s.groupNumber ORDER BY s.created_at) as position_in_group
          FROM individual_scans s
          JOIN scanning_sessions ss ON s.sessionId = ss.id
          WHERE ss.itemName = ?
        )
        SELECT 
          *,
          CASE 
            WHEN position_in_group = 1 THEN CAST(groupNumber as TEXT)
            ELSE NULL 
          END as display_group_number
        FROM RankedScans
        ORDER BY created_at DESC
        LIMIT ? OFFSET ?
      ''', [itemName, pageSize, offset]);
    } else {
      print('Processing as non-counting item...');
      results = await db.rawQuery('''
        WITH RankedScans AS (
          SELECT 
            s.*,
            ss.itemName,
            ss.poNo,
            s.groupNumber,
            ROW_NUMBER() OVER (PARTITION BY s.sessionId, s.groupNumber ORDER BY s.created_at) as position_in_group
          FROM individual_scans s
          JOIN scanning_sessions ss ON s.sessionId = ss.id
          WHERE ss.itemName = ?
        )
        SELECT 
          *,
          CASE 
            WHEN position_in_group = 1 THEN CAST(groupNumber as TEXT)
            ELSE NULL 
          END as display_group_number
        FROM RankedScans
        ORDER BY created_at DESC
        LIMIT ? OFFSET ?
      ''', [itemName, pageSize, offset]);
    }

    print('Query results:');
    for (var row in results) {
      print(
          'Row: groupNumber=${row['groupNumber']}, display_group_number=${row['display_group_number']}, position_in_group=${row['position_in_group']}');
    }

    return results;
  }

  Future<int> getTotalScansForItem(String itemName) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as total_count
      FROM individual_scans s
      JOIN scanning_sessions ss ON s.sessionId = ss.id
      WHERE ss.itemName = ?
    ''', [itemName]);

    return result.first['total_count'] as int? ?? 0;
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
    required String sessionId,
  }) async {
    print('\n=== DEBUG: insertScanContent ===');
    print('OperatorScanId: $operatorScanId');
    print('Content: $content');
    print('Result: $result');
    print('Initial GroupNumber: $groupNumber');
    print('Initial GroupPosition: $groupPosition');
    print('CodesInGroup: $codesInGroup');
    print('SessionId: $sessionId');

    final db = await database;

    // Get the item details from scanning_sessions
    final itemDetails = await db.query(
      'scanning_sessions',
      where: 'id = ?',
      whereArgs: [operatorScanId],
    );

    if (itemDetails.isEmpty) {
      print('No scanning session found for id: $operatorScanId');
      return;
    }

    String itemName = itemDetails.first['itemName'] as String;
    String poNo = itemDetails.first['poNo'] as String;
    print('Found itemName: $itemName, poNo: $poNo');

    // Get the highest group number for this item and PO combination
    print('\n=== Calculating Group Numbers ===');
    print('Getting highest group number for:');
    print('Item Name: $itemName');
    print('PO Number: $poNo');

    final queryResult = await db.rawQuery('''
        SELECT MAX(s.groupNumber) as maxGroup
        FROM scanning_sessions ss
        JOIN individual_scans s ON s.sessionId = ss.id
        WHERE ss.itemName = ? AND ss.poNo = ?
      ''', [itemName, poNo]);

    final highestGroupNumber = queryResult.first['maxGroup'] as int? ?? 0;
    print('Raw query result: $queryResult');
    print('Highest existing group number: $highestGroupNumber');

    // Get count of scans in the current group
    final codesPerGroup = codesInGroup ?? 1;
    print('\nGetting current session scans:');
    print('Session ID: $operatorScanId');
    print('Codes required per group: $codesPerGroup');

    final currentSessionScans = await db.query(
      'individual_scans',
      where: 'sessionId = ?',
      whereArgs: [operatorScanId],
      orderBy: 'created_at DESC',
    );
    print('Current session scans count: ${currentSessionScans.length}');

    // Calculate new group number
    final scansInCurrentGroup = currentSessionScans.length % codesPerGroup;
    print('\nCalculating group details:');
    print('Scans in current group (not yet complete): $scansInCurrentGroup');
    print('Codes per group: $codesPerGroup');

    if (scansInCurrentGroup == 0) {
      // Start a new group
      groupNumber = highestGroupNumber + 1;
      print('\nStarting new group:');
      print('Previous highest group number: $highestGroupNumber');
      print('New group number: $groupNumber');
    } else {
      // Continue the current group
      groupNumber = highestGroupNumber;
      print('\nContinuing current group:');
      print('Current group number: $groupNumber');
    }

    print('\nFinal group assignment:');
    print('Group Number: $groupNumber');

    final scanData = {
      'sessionId': operatorScanId,
      'content': content,
      'result': result,
      'groupNumber': groupNumber,
      'created_at': DateTime.now().toIso8601String(),
    };
    print('Inserting scan data: $scanData');

    final id = await db.insert('individual_scans', scanData);
    print('Inserted scan with id: $id');

    // Verify the insertion
    final inserted = await db.query(
      'individual_scans',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (inserted.isNotEmpty) {
      print('Verified inserted data: ${inserted.first}');
    }
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

  Future<Map<String, int>> getGroupedScanCounts(
      String itemName, String poNo) async {
    final db = await database;

    // First get the item's codeCount to know how many scans make a complete group
    final items =
        await db.query('items', where: 'itemCode = ?', whereArgs: [itemName]);
    if (items.isEmpty)
      return {'inspectionQty': 0, 'goodCount': 0, 'noGoodCount': 0};

    final item = items.first;
    final int codesPerGroup = int.parse(item['codeCount']?.toString() ?? '1');

    print('\n=== DEBUG: getGroupedScanCounts ===');
    print('Item: $itemName');
    print('PO Number: $poNo');
    print('Codes per group: $codesPerGroup');

    // Build the query to count groups
    String query = '''
      WITH GroupedScans AS (
        SELECT 
          ss.itemName,
          ss.poNo,
          ss.id as sessionId,
          s.groupNumber,
          COUNT(*) as scansInGroup,
          SUM(CASE WHEN s.result = 'Good' THEN 1 ELSE 0 END) as goodScansInGroup
        FROM scanning_sessions ss
        JOIN individual_scans s ON s.sessionId = ss.id
        WHERE ss.itemName = ? AND ss.poNo = ?
        GROUP BY ss.itemName, ss.poNo, ss.id, s.groupNumber
        HAVING COUNT(*) = ? -- Only consider complete groups
      )
      SELECT 
        COUNT(*) as inspectionQty,
        SUM(CASE WHEN scansInGroup = goodScansInGroup THEN 1 ELSE 0 END) as goodCount,
        SUM(CASE WHEN scansInGroup > goodScansInGroup THEN 1 ELSE 0 END) as noGoodCount
      FROM GroupedScans
    ''';

    final result = await db.rawQuery(query, [itemName, poNo, codesPerGroup]);
    print('Query result: $result');

    return {
      'inspectionQty': result.first['inspectionQty'] as int? ?? 0,
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
    final db = await database;

    // Get the current user ID from the current_user table
    final currentUserResult = await db.query('current_user', limit: 1);
    final userId = currentUserResult.isNotEmpty
        ? currentUserResult.first['user_id'] as int
        : null;

    if (userId == null) return null;

    // Get the user details from the users table
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

      print('DEBUG: Set current user ID to: $userId');
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
    final userId = result.isNotEmpty ? result.first['user_id'] as int : null;
    print('DEBUG: Current user ID from DB: $userId');
    return userId;
  }

  Future<int> getCompletedGroupsCount(
      int operatorScanId, int codesPerGroup) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT groupNumber) as completed_groups
      FROM individual_scans
      WHERE sessionId = ?
      AND groupNumber IN (
        SELECT groupNumber
        FROM individual_scans
        WHERE sessionId = ?
        GROUP BY groupNumber
        HAVING COUNT(*) = ?
      )
    ''', [operatorScanId, operatorScanId, codesPerGroup]);

    return result.first['completed_groups'] as int? ?? 0;
  }

  Future<Map<String, int>> getCurrentSessionCounts(
    String itemName,
    String sessionId,
  ) async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_count,
        SUM(CASE WHEN result = 'Good' THEN 1 ELSE 0 END) as goodCount,
        SUM(CASE WHEN result = 'No Good' THEN 1 ELSE 0 END) as noGoodCount
      FROM individual_scans s
      JOIN scanning_sessions ss ON s.sessionId = ss.id
      WHERE ss.itemName = ? AND s.sessionId = ?
    ''', [itemName, sessionId]);

    return {
      'groupCount': result.first['total_count'] as int? ?? 0,
      'goodCount': result.first['goodCount'] as int? ?? 0,
      'noGoodCount': result.first['noGoodCount'] as int? ?? 0,
    };
  }

  Future<List<Map<String, dynamic>>> getPreviousScans(String itemName) async {
    final db = await database;

    // First get all unique session IDs ordered by timestamp
    final sessions = await db.rawQuery('''
      SELECT DISTINCT session_id 
      FROM individual_scans 
      WHERE item_name = ? 
      ORDER BY timestamp
    ''', [itemName]);

    List<Map<String, dynamic>> allScans = [];

    // Process each session separately
    for (var session in sessions) {
      String sessionId = session['session_id']?.toString() ?? '';
      if (sessionId.isEmpty) continue; // Skip if session_id is null or empty

      // Get scans for this session
      final scans = await db.rawQuery('''
        SELECT 
          s.*,
          CASE 
            WHEN s.group_position = 1 THEN s.group_number 
            ELSE NULL 
          END as display_group_number
        FROM individual_scans s
        WHERE s.item_name = ? 
        AND s.session_id = ?
        ORDER BY s.timestamp
      ''', [itemName, sessionId]);

      allScans.addAll(scans);
    }

    return allScans;
  }

  Future<void> clearAllDataForItem(String itemName) async {
    final db = await database;

    // Get all session IDs for this item
    final sessions = await db.query(
      'scanning_sessions',
      columns: ['id'],
      where: 'itemName = ?',
      whereArgs: [itemName],
    );

    if (sessions.isEmpty) return;

    final sessionIds = sessions.map((s) => s['id']).toList();

    // Start a transaction to ensure all deletes happen together
    await db.transaction((txn) async {
      // Delete all individual scans for these sessions
      await txn.delete(
        'individual_scans',
        where:
            'sessionId IN (${List.filled(sessionIds.length, '?').join(',')})',
        whereArgs: sessionIds,
      );

      // Delete all box labels for these sessions
      await txn.delete(
        'box_labels',
        where:
            'sessionId IN (${List.filled(sessionIds.length, '?').join(',')})',
        whereArgs: sessionIds,
      );

      // Delete all scanning sessions for this item
      await txn.delete(
        'scanning_sessions',
        where: 'itemName = ?',
        whereArgs: [itemName],
      );
    });
  }

  Future<void> saveCurrentState(Map<String, dynamic> state) async {
    final db = await database;

    // Convert complex objects to JSON strings
    final serializedState = Map<String, dynamic>.from(state);
    serializedState['tableData'] = jsonEncode(state['tableData']);

    // Convert boolean values to integers for SQLite
    serializedState['isQtyPerBoxReached'] = state['isQtyPerBoxReached'] ? 1 : 0;
    serializedState['isTotalQtyReached'] = state['isTotalQtyReached'] ? 1 : 0;

    // Delete previous state for this item
    await db.delete(
      'current_states',
      where: 'itemName = ?',
      whereArgs: [state['itemName']],
    );

    // Insert new state
    await db.insert(
      'current_states',
      serializedState,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getLastSavedState(String itemName) async {
    final db = await database;

    final List<Map<String, dynamic>> results = await db.query(
      'current_states',
      where: 'itemName = ?',
      whereArgs: [itemName],
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    if (results.isNotEmpty) {
      final state = Map<String, dynamic>.from(results.first);
      // Deserialize complex objects
      state['tableData'] = jsonDecode(state['tableData'].toString());

      // Convert integers back to booleans
      state['isQtyPerBoxReached'] = state['isQtyPerBoxReached'] == 1;
      state['isTotalQtyReached'] = state['isTotalQtyReached'] == 1;

      return state;
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> getBoxQuantities(String itemName) async {
    final db = await database;

    return await db.rawQuery('''
      SELECT 
        bl.qtyPerBox,
        bl.createdAt,
        COUNT(DISTINCT CASE WHEN s.result = 'Good' THEN s.groupNumber END) as goodGroups,
        COUNT(DISTINCT CASE WHEN s.result = 'No Good' THEN s.groupNumber END) as noGoodGroups
      FROM box_labels bl
      JOIN scanning_sessions ss ON bl.sessionId = ss.id
      LEFT JOIN individual_scans s ON s.sessionId = ss.id
      WHERE ss.itemName = ?
      GROUP BY bl.id
      ORDER BY bl.createdAt ASC
    ''', [itemName]);
  }

  Future<void> updateScanResult(
    int operatorScanId,
    String content,
    String result, {
    required String sessionId,
    required int groupNumber,
  }) async {
    final db = await database;
    await db.update(
      'individual_scans',
      {'result': result},
      where: 'sessionId = ? AND groupNumber = ? AND content = ?',
      whereArgs: [sessionId, groupNumber, content],
    );
  }

  // License-related methods
  Future<bool> saveLicense(String licenseKey, String? hardwareId) async {
    try {
      final db = await database;
      await db.insert(
        'license_info',
        {
          'license_key': licenseKey,
          'hardware_id': hardwareId,
          'activated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      print('Error saving license: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getLicense() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.query(
        'license_info',
        orderBy: 'activated_at DESC',
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('Error getting license: $e');
      return null;
    }
  }

  Future<bool> clearLicense() async {
    try {
      final db = await database;
      await db.delete('license_info');
      return true;
    } catch (e) {
      print('Error clearing license: $e');
      return false;
    }
  }

  Future<bool> isLicenseValid(String licenseKey) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.query(
        'license_info',
        where: 'license_key = ?',
        whereArgs: [licenseKey],
      );
      return result.isNotEmpty;
    } catch (e) {
      print('Error checking license validity: $e');
      return false;
    }
  }
}
