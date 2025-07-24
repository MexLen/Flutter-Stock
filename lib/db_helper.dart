import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'fetch.dart';

class FundDbHelper {
  static const _dbName = 'fund.db';
  static const _dbVersion = 1;
  static Database? _db;

  Future<Database> get database async => _db ??= await _initDatabase();

  Future<Database> _initDatabase() async {
    print('Initializing Android SQLite database...');
    
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    
    print('Database path: $path');
    
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createAndImport,
    );
  }

  Future<void> _createAndImport(Database db, int version) async {
    print('Creating tables for Android...');
    
    // 创建主表 - 只保留基金代码和名称
    await db.execute('''
      CREATE TABLE fund (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fundcode TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL
      );
    ''');

    // 为基金代码和名称创建索引，提高查询性能
    await db.execute('''
      CREATE INDEX idx_fundcode ON fund(fundcode);
    ''');
    
    await db.execute('''
      CREATE INDEX idx_name ON fund(name);
    ''');

    print('Tables created successfully');

    // 导入初始数据
    await _loadSampleData(db);
    print('Sample data loaded');
  }

  Future<void> _loadSampleData(Database db) async {
    final sampleData = [
      {'fundcode': '000001', 'name': '华夏成长混合'},
      {'fundcode': '000002', 'name': '华夏策略混合'},
      {'fundcode': '110022', 'name': '易方达消费行业股票'},
      {'fundcode': '110003', 'name': '易方达上证50指数A'},
      {'fundcode': '161725', 'name': '招商中证白酒指数分级'},
      {'fundcode': '163407', 'name': '兴全沪深300指数LOF'},
      {'fundcode': '001102', 'name': '前海开源国家比较优势混合'},
      {'fundcode': '050002', 'name': '博时沪深300指数A'},
      {'fundcode': '470009', 'name': '汇添富民营活力混合A'},
      {'fundcode': '519772', 'name': '交银深证300价值ETF联接'},
      {'fundcode': '016573', 'name': '招商中证银行AH价格优选ETF发起式联接C'},
      {'fundcode': '003096', 'name': '中欧医疗健康混合A'},
      {'fundcode': '000376', 'name': '华安中证细分医药ETF联接A'},
      {'fundcode': '260108', 'name': '景顺长城新兴成长混合'},
      {'fundcode': '000300', 'name': '嘉实沪深300ETF联接A'},
      {'fundcode': '519066', 'name': '汇添富蓝筹稳健混合A'},
      {'fundcode': '040025', 'name': '华安科技动力混合'},
      {'fundcode': '217005', 'name': '招商先锋混合'},
      {'fundcode': '000828', 'name': '泰达宏利转型机遇股票'},
      {'fundcode': '001618', 'name': '天弘中证电子ETF联接A'},
    ];

    // 使用事务批量插入
    await db.transaction((txn) async {
      final batch = txn.batch();
      
      for (final data in sampleData) {
        batch.insert('fund', data, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      
      await batch.commit();
    });
  }

  // 修复: 返回类型明确为 List<Map<String, dynamic>>
  Future<List<Map<String, dynamic>>> search(String keyword, {int limit = 30}) async {
    final db = await database;
    
    if (keyword.isEmpty) {
      return db.query('fund', limit: limit, orderBy: 'name');
    }

    // 使用 LIKE 查询进行模糊搜索
    // 支持基金代码和基金名称搜索
    final searchPattern = '%$keyword%';
    
    return db.rawQuery('''
      SELECT * FROM fund 
      WHERE fundcode LIKE ? OR name LIKE ?
      ORDER BY 
        CASE 
          WHEN fundcode = ? THEN 1
          WHEN fundcode LIKE ? THEN 2
          WHEN name LIKE ? THEN 3
          ELSE 4
        END,
        name
      LIMIT ?
    ''', [
      searchPattern, searchPattern,  // WHERE 条件
      keyword, '$keyword%', '%$keyword%',  // ORDER BY 条件
      limit
    ]);
  }

  // 根据基金代码精确查找
  Future<Fund?> findByCode(String fundcode) async {
    final db = await database;
    final maps = await db.query(
      'fund',
      where: 'fundcode = ?',
      whereArgs: [fundcode],
      limit: 1,
    );
    
    return maps.isEmpty ? null : Fund.fromDbMap(maps.first);
  }

  // 根据基金名称模糊查找
  Future<List<Fund>> findByName(String name) async {
    final db = await database;
    final maps = await db.query(
      'fund',
      where: 'name LIKE ?',
      whereArgs: ['%$name%'],
      orderBy: 'name',
    );
    
    return maps.map(Fund.fromDbMap).toList();
  }

  // 添加新基金
  Future<int> insertFund(Fund fund) async {
    final db = await database;
    
    return db.insert(
      'fund', 
      fund.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // 批量添加基金
  Future<void> insertFunds(List<Fund> funds) async {
    final db = await database;
    
    await db.transaction((txn) async {
      final batch = txn.batch();
      
      for (final fund in funds) {
        batch.insert(
          'fund', 
          fund.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      await batch.commit();
    });
  }

  // 更新基金信息
  Future<int> updateFund(Fund fund) async {
    final db = await database;
    
    return db.update(
      'fund',
      fund.toDbMap(),
      where: 'fundcode = ?',
      whereArgs: [fund.fundcode],
    );
  }

  // 删除基金
  Future<int> deleteFund(String fundcode) async {
    final db = await database;
    
    return db.delete(
      'fund',
      where: 'fundcode = ?',
      whereArgs: [fundcode],
    );
  }

  // 获取所有基金
  Future<List<Fund>> loadAllFunds() async {
    final db = await database;
    final maps = await db.query('fund', orderBy: 'name');
    return maps.map(Fund.fromDbMap).toList();
  }

  // 获取基金总数
  Future<int> getFundCount() async {
    final db = await database;
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM fund')
    ) ?? 0;
  }

  // 清空所有数据
  Future<void> clearAllFunds() async {
    final db = await database;
    await db.delete('fund');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

class FundRepo {
  final _helper = FundDbHelper();

  Future<List<Fund>> search(String keyword) async {
    final rows = await _helper.search(keyword);
    return rows.map(Fund.fromDbMap).toList();
  }

  Future<Fund?> findByCode(String fundcode) => _helper.findByCode(fundcode);
  
  Future<List<Fund>> findByName(String name) => _helper.findByName(name);
  
  Future<int> addFund(Fund fund) => _helper.insertFund(fund);
  
  Future<void> addFunds(List<Fund> funds) => _helper.insertFunds(funds);
  
  Future<int> updateFund(Fund fund) => _helper.updateFund(fund);
  
  Future<int> deleteFund(String fundcode) => _helper.deleteFund(fundcode);

  Future<List<Fund>> loadAllFunds() => _helper.loadAllFunds();
  
  Future<int> getFundCount() => _helper.getFundCount();
  
  Future<void> clearAllFunds() => _helper.clearAllFunds();

  void dispose() => _helper.close();
}