import 'dart:async';

import 'package:belatuk_rethinkdb/belatuk_rethinkdb.dart';
import 'package:test/test.dart';

void main() {
  RethinkDb r = RethinkDb();
  late String databaseName;
  String tableName = 'items';

  setUpAll(() async {
    Connection conn = await r.connect();
    String dbName = await r.uuid().run(conn);
    databaseName = "test_database_${dbName.replaceAll("-", "")}";
    await r.dbCreate(databaseName).run(conn);
    await r.db(databaseName).tableCreate(tableName).run(conn);
    conn.close();
  });

  tearDownAll(() async {
    Connection conn = await r.connect();
    await r.dbDrop(databaseName).run(conn);
    conn.close();
  });

  test("a query on a closed connection throws", () async {
    Connection conn = await r.connect();
    conn.close();
    await expectLater(
      r.db(databaseName).table(tableName).count().run(conn),
      throwsA(isA<RqlDriverError>()),
    );
  });

  test("closing the connection ends a feed waiting for changes", () async {
    Connection conn = await r.connect(db: databaseName);
    var feed = await r.table(tableName).changes().run(conn) as Feed;
    var done = Completer<void>();
    feed.listen((_) {}, onError: done.completeError, onDone: done.complete);
    // Let the feed ask the server for its next batch.
    await Future.delayed(const Duration(milliseconds: 200));
    conn.close();
    await done.future.timeout(const Duration(seconds: 5));
  });

  test("closing the connection while a feed starts ends the feed", () async {
    // The feed asks for its next batch right after delivering one, so closing
    // the connection then is a race, tried several times here. An uncaught
    // error fails the test.
    for (var i = 0; i < 20; i++) {
      Connection conn = await r.connect(db: databaseName);
      var feed = await r.table(tableName).changes().run(conn) as Feed;
      var done = Completer<void>();
      feed.listen((_) {}, onError: done.completeError, onDone: done.complete);
      conn.close();
      await done.future.timeout(const Duration(seconds: 5));
    }
  });
}
