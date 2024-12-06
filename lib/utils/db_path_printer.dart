import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import '../database_helper.dart';
import 'dart:io';

class DbPathPrinter {
  static Future<void> printPath() async {
    try {
      final dbPath = await DatabaseHelper().getDatabasePath();
      print('Database file location: $dbPath');
      
      final File dbFile = File(dbPath);
      if (await dbFile.exists()) {
        print('Database file exists');
        
        // Print database contents
        final contents = await DatabaseHelper().getAllDatabaseContents();
        
        print('\nDatabase Contents:');
        print('==================');
        
        print('\nUsers Table:');
        print('------------');
        for (var user in contents['users']!) {
          print(user);
        }
        
        print('\nItems Table:');
        print('------------');
        for (var item in contents['items']!) {
          print(item);
        }
        
        print('\nItem Codes Table:');
        print('----------------');
        for (var code in contents['item_codes']!) {
          print(code);
        }
      } else {
        print('Database file does not exist at the specified location');
      }
    } catch (e) {
      print('Error accessing database: $e');
    }
  }
}