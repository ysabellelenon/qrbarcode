import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import '../database_helper.dart';

class DbPathPrinter {
  static Future<void> printPath() async {
    final dbPath = await DatabaseHelper().getDatabasePath();
    print('Database file location: $dbPath');
    
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
  }
}