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
    final Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final Directory dbDirectory = Directory(join(documentsDirectory.path, 'databases'));
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
      version: 4,
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
        hasSubLot INTEGER,
        serialCount TEXT,
        FOREIGN KEY (itemId) REFERENCES items (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS operator_scans(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemName TEXT,
        poNo TEXT,
        totalQty INTEGER,
        content TEXT,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS article_labels(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operatorScanId INTEGER,
        articleLabel TEXT,
        lotNumber TEXT,
        qtyPerBox TEXT,
        content TEXT,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (operatorScanId) REFERENCES operator_scans (id) ON DELETE CASCADE
      )
    ''');

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
      CREATE TABLE IF NOT EXISTS operator_scans(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemName TEXT,
        poNo TEXT,
        totalQty INTEGER,
        content TEXT,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS article_labels(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operatorScanId INTEGER,
        articleLabel TEXT,
        lotNumber TEXT,
        qtyPerBox TEXT,
        content TEXT,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (operatorScanId) REFERENCES operator_scans (id) ON DELETE CASCADE
      )
    ''');
    
    print('Migrated database to version 3: Added operator_scans and article_labels tables');

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
    await db.insert('users', user, conflictAlgorithm: ConflictAlgorithm.replace);
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
      final List<Map<String, dynamic>> items = await db.query('items', orderBy: 'id DESC');
      print('Retrieved ${items.length} items from database');
      
      final List<Map<String, dynamic>> result = [];
      
      for (var item in items) {
        final codes = await db.query(
          'item_codes',
          where: 'itemId = ?',
          whereArgs: [item['id']],
        );
        print('Retrieved ${codes.length} codes for item ${item['id']}');
        
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
          final codeId = await txn.insert('item_codes', {
            'itemId': itemId,
            'category': code['category'],
            'content': code['content'],
            'hasSubLot': code['hasSubLot'] == true ? 1 : 0,
            'serialCount': code['serialCount'],
          });
          print('Inserted code with ID: $codeId for item: $itemId');
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
        await txn.insert('item_codes', {
          'itemId': itemId,
          'category': code['category'],
          'content': code['content'],
          'hasSubLot': code['hasSubLot'] == 1 ? 1 : 0,
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

  Future<String> getDatabasePath() async {
    final Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final String path = join(documentsDirectory.path, 'databases', 'users.db');
    return path;
  }

  Future<Map<String, List<Map<String, dynamic>>>> getAllDatabaseContents() async {
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
    return await db.insert('operator_scans', scan);
  }

  Future<int> insertArticleLabel(Map<String, dynamic> label) async {
    final db = await database;
    return await db.insert('article_labels', label);
  }

  Future<List<Map<String, dynamic>>> getOperatorScans() async {
    final db = await database;
    return await db.query('operator_scans', orderBy: 'createdAt DESC');
  }

  Future<List<Map<String, dynamic>>> getArticleLabels(int operatorScanId) async {
    final db = await database;
    return await db.query(
      'article_labels',
      where: 'operatorScanId = ?',
      whereArgs: [operatorScanId],
      orderBy: 'createdAt DESC'
    );
  }

  Future<void> insertUnfinishedItem(Map<String, dynamic> item) async {
    final db = await database;
    await db.insert(
      'unfinished_items',
      {
        ...item,
        'tableData': jsonEncode(item['tableData']),
      },
    );
  }

  Future<List<Map<String, dynamic>>> getUnfinishedItems() async {
    final db = await database;
    final List<Map<String, dynamic>> items = await db.query('unfinished_items', orderBy: 'date DESC');
    return items.map((item) {
      return {
        ...item,
        'tableData': jsonDecode(item['tableData']),
      };
    }).toList();
  }

  Future<void> deleteUnfinishedItems(List<int> ids) async {
    final db = await database;
    await db.delete(
      'unfinished_items',
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }

  Future<void> verifyDatabaseTables() async {
    final db = await database;
    try {
      // Get list of all tables
      final tables = await db.query('sqlite_master', 
        where: 'type = ?', 
        whereArgs: ['table']
      );
      
      print('\nDatabase Tables:');
      print('---------------');
      for (var table in tables) {
        print('Table: ${table['name']}');
        // Get count of records in each table
        final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM ${table['name']}')
        );
        print('Record count: $count');
      }
    } catch (e) {
      print('Error verifying tables: $e');
    }
  }
} 