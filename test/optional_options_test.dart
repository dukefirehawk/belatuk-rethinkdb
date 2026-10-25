import 'package:belatuk_rethinkdb/belatuk_rethinkdb.dart';
import 'package:test/test.dart';

/// Methods whose options are optional work without them.
void main() {
  RethinkDb r = RethinkDb();
  late Connection connection;
  late String databaseName;
  String tableName = 'items';

  setUpAll(() async {
    connection = await r.connect();
    String dbName = await r.uuid().run(connection);
    databaseName = "test_database_${dbName.replaceAll("-", "")}";
    await r.dbCreate(databaseName).run(connection);
    await r.db(databaseName).tableCreate(tableName).run(connection);
    connection.use(databaseName);
  });

  tearDownAll(() async {
    await r.dbDrop(databaseName).run(connection);
    connection.close();
  });

  test("wait() waits for a table without options", () async {
    Map result = await r.table(tableName).wait().run(connection);
    expect(result['ready'], 1);
  });

  test("slice() slices without options", () async {
    expect(await r.expr([0, 1, 2, 3]).slice(1, 3).run(connection), [1, 2]);
  });

  test(
    "getNearest() without options is sent, and the server needs an index",
    () async {
      await expectLater(
        r.table(tableName).getNearest(r.point(0, 0)).run(connection),
        throwsA(isA<RqlError>()),
      );
    },
  );
}
