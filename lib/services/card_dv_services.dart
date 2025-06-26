import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class CardDbService {
  static final CardDbService _instance = CardDbService._internal();
  factory CardDbService() => _instance;
  CardDbService._internal();

  static Database? _database;
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  // --- Encryption helpers ---
  Future<String> _getEncKey() async {
    String? key = await _secureStorage.read(key: 'aes_key');
    if (key == null) {
      final randomKey = encrypt.Key.fromSecureRandom(32);
      key = randomKey.base64;
      await _secureStorage.write(key: 'aes_key', value: key);
    }
    return key;
  }

  Future<String> encryptCardNumber(String cardNumber) async {
    final key = encrypt.Key.fromBase64(await _getEncKey());
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    return encrypter.encrypt(cardNumber, iv: iv).base64;
  }

  Future<String> decryptCardNumber(String encrypted) async {
    final key = encrypt.Key.fromBase64(await _getEncKey());
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    return encrypter.decrypt64(encrypted, iv: iv);
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'cards.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cards (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            card_number TEXT, -- Encrypted
            expiry TEXT,
            nfcId TEXT UNIQUE,
            paymentLink TEXT,
            balance REAL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cardId INTEGER,
            paymentLink TEXT,
            amount REAL,
            timestamp TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE cards ADD COLUMN card_number TEXT');
          await db.execute('ALTER TABLE cards ADD COLUMN expiry TEXT');
        }
      }
    );
  }

  // --- Card CRUD ---

  Future<List<Map<String, dynamic>>> getCards({bool showFullNumber = false}) async {
    final db = await database;
    final cards = await db.query('cards');
    if (!showFullNumber) {
      for (final c in cards) {
        if (c['card_number'] != null) {
          final cardNum = await decryptCardNumber(c['card_number'] as String);
          c['masked_card_number'] = '**** **** **** ${cardNum.substring(cardNum.length - 4)}';
        }
      }
    } else {
      for (final c in cards) {
        if (c['card_number'] != null) {
          c['card_number'] = await decryptCardNumber(c['card_number'] as String);
        }
      }
    }
    return cards;
  }

  Future<int> addCard(
    String name,
    String cardNumber,
    String expiry, {
    String? nfcId,
    String? paymentLink,
    double balance = 0,
  }) async {
    final db = await database;
    if (nfcId != null && nfcId.isNotEmpty) {
      final existing = await db.query('cards', where: 'nfcId = ?', whereArgs: [nfcId]);
      if (existing.isNotEmpty) throw Exception('This NFC tag is already assigned!');
    }
    final encryptedNum = await encryptCardNumber(cardNumber);
    return await db.insert('cards', {
      'name': name,
      'card_number': encryptedNum,
      'expiry': expiry,
      'nfcId': nfcId,
      'paymentLink': paymentLink,
      'balance': balance,
    });
  }

  Future<int> updateCard(
    int id, {
    String? name,
    String? cardNumber,
    String? expiry,
    String? nfcId,
    String? paymentLink,
    double? balance,
  }) async {
    final db = await database;
    final values = <String, Object?>{};
    if (name != null) values['name'] = name;
    if (cardNumber != null) values['card_number'] = await encryptCardNumber(cardNumber);
    if (expiry != null) values['expiry'] = expiry;
    if (nfcId != null) {
      final existing = await db.query('cards', where: 'nfcId = ? AND id != ?', whereArgs: [nfcId, id]);
      if (existing.isNotEmpty) throw Exception('This NFC tag is already assigned!');
      values['nfcId'] = nfcId;
    }
    if (paymentLink != null) values['paymentLink'] = paymentLink;
    if (balance != null) values['balance'] = balance;
    return await db.update('cards', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCard(int id) async {
    final db = await database;
    await db.delete('transactions', where: 'cardId = ?', whereArgs: [id]);
    return await db.delete('cards', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getCardByNfcId(String nfcId) async {
    final db = await database;
    final result = await db.query('cards', where: 'nfcId = ?', whereArgs: [nfcId]);
    if (result.isEmpty) return null;
    final card = result.first;
    card['card_number'] = await decryptCardNumber(card['card_number'] as String);
    return card;
  }

  // --- Balance methods ---

  Future<void> deductBalance(int id, double amount) async {
    final db = await database;
    await db.rawUpdate('UPDATE cards SET balance = balance - ? WHERE id = ?', [amount, id]);
  }

  // --- Transactions ---

  Future<int> logTransaction(int cardId, String paymentLink, double amount) async {
    final db = await database;
    return await db.insert('transactions', {
      'cardId': cardId,
      'paymentLink': paymentLink,
      'amount': amount,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getTransactions() async {
    final db = await database;
    return await db.query('transactions', orderBy: 'timestamp DESC');
  }

  Future<List<Map<String, dynamic>>> getTransactionsForCard(int cardId) async {
    final db = await database;
    return await db.query('transactions', where: 'cardId = ?', whereArgs: [cardId], orderBy: 'timestamp DESC');
  }
}