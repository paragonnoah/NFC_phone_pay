import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class CardDbService {
  static final CardDbService _instance = CardDbService._internal();
  factory CardDbService() => _instance;
  CardDbService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'cards.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cards (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            token TEXT,
            nfcId TEXT,
            paymentLink TEXT
          )
        ''');
      }
    );
  }

  Future<List<Map<String, dynamic>>> getCards() async {
    final db = await database;
    return await db.query('cards');
  }

  Future<int> addCard(String name, String token, {String? nfcId, String? paymentLink}) async {
    final db = await database;
    return await db.insert('cards', {
      'name': name,
      'token': token,
      'nfcId': nfcId,
      'paymentLink': paymentLink,
    });
  }

  Future<int> updateCard(int id, {String? name, String? token, String? nfcId, String? paymentLink}) async {
    final db = await database;
    final values = <String, Object?>{};
    if (name != null) values['name'] = name;
    if (token != null) values['token'] = token;
    if (nfcId != null) values['nfcId'] = nfcId;
    if (paymentLink != null) values['paymentLink'] = paymentLink;
    return await db.update('cards', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCard(int id) async {
    final db = await database;
    return await db.delete('cards', where: 'id = ?', whereArgs: [id]);
  }
}