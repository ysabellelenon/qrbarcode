import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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
    // Get the path to the documents directory.
    String documentsDirectory = (await getApplicationDocumentsDirectory()).path;
    String path = join(documentsDirectory, 'users.db');

    // Open or create the database
    return await openDatabase(
      path,
      version: 2, // Incremented version for migration
      onCreate: (db, version) async {
        await _createTables(db);
        await _insertDefaultUsers(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Migration for version 2
          await _migrateToVersion2(db);
        }
        // Future migrations can be handled here
      },
    );
  }

  Future<void> _createTables(Database db) async {
    // Create 'users' table if it doesn't exist
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

    // Create 'items' table if it doesn't exist
    await db.execute('''
      CREATE TABLE IF NOT EXISTS items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemCode TEXT,
        revision TEXT,
        codeCount TEXT,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create 'item_codes' table if it doesn't exist
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
  }

  Future<void> _insertDefaultUsers(Database db) async {
    // Check if the Engineer user already exists
    List<Map<String, dynamic>> engineer = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: ['engineer'],
    );

    if (engineer.isEmpty) {
      // Insert Engineer user with correct lineNo
      await db.insert('users', {
        'firstName': 'Engineer',
        'lastName': 'User',
        'username': 'engineer',
        'password': 'password123',
        'section': 'Engineering',
        'lineNo': 'Admin', // Correct lineNo
      });
      print('Inserted Engineer user with lineNo: Admin');
    } else {
      // Optional: Update Engineer user's lineNo if incorrect
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

    // Check if the Operator user already exists
    List<Map<String, dynamic>> operatorUser = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: ['operator'],
    );

    if (operatorUser.isEmpty) {
      // Insert Operator user
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
    // Example migration: Update Engineer user's lineNo to Admin
    await db.update(
      'users',
      {'lineNo': 'Admin'},
      where: 'username = ? AND lineNo != ?',
      whereArgs: ['engineer', 'Admin'],
    );
    print('Migrated Engineer user\'s lineNo to Admin');
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
          'hasSubLot': code['hasSubLot'] == 1 ? 1 : 0,
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
    String path = join(await getDatabasesPath(), 'users.db');
    return path;
  }

  Future<Map<String, List<Map<String, dynamic>>>> getAllDatabaseContents() async {
    final db = await database;
    
    // Get contents of each table
    final users = await db.query('users');
    final items = await db.query('items');
    final itemCodes = await db.query('item_codes');

    return {
      'users': users,
      'items': items, 
      'item_codes': itemCodes,
    };
  }
} 