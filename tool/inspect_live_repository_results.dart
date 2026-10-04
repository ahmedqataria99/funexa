import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/purchasing/data/datasources/purchasing_local_data_source.dart';
import 'package:furnexa/features/purchasing/data/repositories/purchasing_repository_impl.dart';
import 'package:furnexa/features/warehouses_stock/data/datasources/warehouses_stock_local_data_source.dart';
import 'package:furnexa/features/warehouses_stock/data/repositories/warehouses_stock_repository_impl.dart';

Future<void> main() async {
  final database = await FurnexaDatabase.instance.database;
  print('[DB PATH] ${database.path}');
  print(
    '[DB VERSION] ${(await database.rawQuery('PRAGMA user_version')).single['user_version']}',
  );
  final stockRepository = WarehousesStockRepositoryImpl(
    WarehousesStockLocalDataSource(),
  );
  final warehouses = await stockRepository.warehouses();
  final items = await stockRepository.activeItems();
  print(
    '[STOCK WAREHOUSES] count=${warehouses.length} ids=${warehouses.map((value) => value.id).toList()}',
  );
  print(
    '[ACTIVE ITEMS] count=${items.length} items=${items.map((value) => '${value.id}:${value.type.name}:${value.name}:${value.active}').toList()}',
  );
  final allStock = await stockRepository.stock(null);
  print(
    '[STOCK REPOSITORY ALL] count=${allStock.length} lines=${allStock.map((line) => '${line.item.id}:${line.item.type.name}:warehouse=${line.balance.warehouseId}:quantity=${line.balance.quantity}:name=${line.item.name}').toList()}',
  );
  for (final warehouse in warehouses) {
    final lines = await stockRepository.stock(warehouse.id);
    print(
      '[STOCK REPOSITORY WAREHOUSE] id=${warehouse.id} count=${lines.length} quantities=${lines.map((line) => '${line.item.id}:${line.balance.quantity}').toList()}',
    );
  }
  final requestRepository = PurchasingRepositoryImpl(
    PurchasingLocalDataSource(),
  );
  final requests = await requestRepository.requests();
  print(
    '[PURCHASE REQUEST REPOSITORY] count=${requests.length} requests=${requests.map((request) => '${request.id}:${request.requestNumber}:${request.status.name}:items=${request.items.length}').toList()}',
  );
  await FurnexaDatabase.instance.close();
}
