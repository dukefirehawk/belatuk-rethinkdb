import 'dart:async';
import 'dart:io';

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
    await r.db(databaseName).table(tableName).wait().run(conn);
    conn.close();
  });

  tearDownAll(() async {
    Connection conn = await r.connect();
    await r.dbDrop(databaseName).run(conn);
    conn.close();
  });

  /// Creates the table [name], and waits until it can be used: other test
  /// files reconfigure the server at the same time.
  Future<void> createTable(Connection conn, String name) async {
    await r.tableCreate(name).run(conn);
    await r.table(name).wait().run(conn);
  }

  /// Starts a proxy to the server, whose connections the test can drop, and
  /// whose replies from the server it can hold back.
  Future<_Proxy> proxy() async {
    var proxy = _Proxy(
      await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
    );
    addTearDown(proxy.close);
    return proxy;
  }

  /// Listens to [feed], completing with its end, or with its error.
  Future<void> ended(Feed feed, {void Function(dynamic)? onData}) {
    var done = Completer<void>();
    feed.listen(
      onData ?? (_) {},
      onError: done.completeError,
      onDone: done.complete,
    );
    return done.future.timeout(const Duration(seconds: 5));
  }

  test("a query on a closed connection throws", () async {
    Connection conn = await r.connect();
    conn.close();
    await expectLater(
      r.db(databaseName).table(tableName).count().run(conn),
      throwsA(isA<RqlDriverError>()),
    );
  });

  test("reconnect connects again", () async {
    Connection conn = await r.connect();
    conn.close();
    await conn.reconnect();
    expect(conn.isClosed, isFalse);
    expect(await r.expr(2).run(conn), 2);
    conn.close();
  });

  test("a query that failed on a closed connection is not sent after a "
      "reconnect", () async {
    Connection setup = await r.connect(db: databaseName);
    await createTable(setup, 'writes');
    addTearDown(() async {
      await r.tableDrop('writes').run(setup);
      setup.close();
    });

    Connection conn = await r.connect(db: databaseName);
    // close() runs noreplyWait, which must not leave a query behind either.
    conn.close();
    conn.close();
    await expectLater(
      r.table('writes').insert({'id': 'lost'}).run(conn),
      throwsA(isA<RqlDriverError>()),
    );

    await conn.reconnect();
    expect(await r.expr(1).run(conn), 1);
    expect(await r.table('writes').count().run(conn), 0);
    conn.close();
  });

  test("closing the connection ends a feed that delivered a change", () async {
    Connection setup = await r.connect(db: databaseName);
    addTearDown(setup.close);
    Connection conn = await r.connect(db: databaseName);
    var feed = await r.table(tableName).changes().run(conn) as Feed;

    var changed = Completer<void>();
    var done = ended(feed, onData: (_) => changed.complete());
    await r.table(tableName).insert({'title': 'a'}).run(setup);
    await changed.future.timeout(const Duration(seconds: 5));
    // Let the feed ask the server for its next batch, which it does as soon
    // as the change is delivered.
    await Future.delayed(const Duration(milliseconds: 200));

    conn.close();
    await done;
  });

  test("closing the connection while a feed starts ends the feed", () async {
    // The feed asks for its next batch right after delivering one, so closing
    // the connection then is a race, tried several times here. An uncaught
    // error fails the test.
    for (var i = 0; i < 20; i++) {
      Connection conn = await r.connect(db: databaseName);
      var feed = await r.table(tableName).changes().run(conn) as Feed;
      var done = ended(feed);
      conn.close();
      await done;
    }
  });

  test("a feed can be closed while it delivers a change", () async {
    Connection setup = await r.connect(db: databaseName);
    addTearDown(setup.close);
    Connection conn = await r.connect(db: databaseName);
    addTearDown(conn.close);
    var feed = await r.table(tableName).changes().run(conn) as Feed;

    var done = ended(feed, onData: (_) => feed.close());
    await r.table(tableName).insert({'title': 'b'}).run(setup);
    await done;
  });

  test("a feed can be closed while it waits for changes", () async {
    Connection setup = await r.connect(db: databaseName);
    addTearDown(setup.close);
    Connection conn = await r.connect(db: databaseName);
    addTearDown(conn.close);
    var feed = await r.table(tableName).changes().run(conn) as Feed;
    var done = ended(feed);
    // Let the feed ask the server for its next batch.
    await Future.delayed(const Duration(milliseconds: 200));

    await feed.close();
    await done;
    // The change is not delivered to the closed feed, and the connection
    // still works. An uncaught error fails the test.
    await r.table(tableName).insert({'title': 'c'}).run(setup);
    await Future.delayed(const Duration(milliseconds: 200));
    expect(await r.expr(1).run(conn), 1);
  });

  test("an error of a feed is the server's error, and ends it", () async {
    Connection setup = await r.connect(db: databaseName);
    await createTable(setup, 'dropped');
    addTearDown(setup.close);
    Connection conn = await r.connect(db: databaseName);
    addTearDown(conn.close);
    var feed = await r.table('dropped').changes().run(conn) as Feed;

    var errors = [];
    var done = Completer<void>();
    feed.listen((_) {}, onError: errors.add, onDone: done.complete);
    await r.tableDrop('dropped').run(setup);

    await done.future.timeout(const Duration(seconds: 5));
    expect(errors, [isA<RqlError>()]);
  });

  test("a connection dropped by the network ends its feeds", () async {
    var server = await proxy();
    Connection conn = await r.connect(
      db: databaseName,
      host: server.host,
      port: server.port,
    );
    var feed = await r.table(tableName).changes().run(conn) as Feed;
    var done = ended(feed);

    server.drop();
    await done;
    expect(conn.isClosed, isTrue);
  });

  test("a connection dropped by the network fails the queries waiting for a "
      "reply", () async {
    var server = await proxy();
    Connection conn = await r.connect(
      db: databaseName,
      host: server.host,
      port: server.port,
    );
    server.holdReplies = true;
    var count = r.table(tableName).count().run(conn);
    await Future.delayed(const Duration(milliseconds: 200));

    server.drop();
    await expectLater(count, throwsA(isA<RqlDriverError>()));
  });

  test(
    "connect fails when the connection closes during the handshake",
    () async {
      var server = await proxy();
      server.dropOnConnect = true;
      await expectLater(
        r.connect(host: server.host, port: server.port),
        throwsA(isA<RqlDriverError>()),
      );
    },
  );

  test("reconnect replaces a connect in progress", () async {
    Connection conn = Connection('test', 'localhost', 28015, 'admin', '', null);
    var first = conn.connect();
    var second = conn.reconnect();
    await expectLater(first, throwsA(isA<RqlDriverError>()));
    await second;
    expect(await r.expr(1).run(conn), 1);
    conn.close();
  });
}

/// A proxy to the RethinkDB server on localhost.
class _Proxy {
  final ServerSocket _server;
  final List<Socket> _sockets = [];

  /// Whether replies from the server are held back.
  bool holdReplies = false;

  /// Whether a client that connects is dropped at once.
  bool dropOnConnect = false;

  _Proxy(this._server) {
    _server.listen((client) async {
      if (dropOnConnect) {
        client.destroy();
        return;
      }
      var server = await Socket.connect('localhost', 28015);
      _sockets.addAll([client, server]);
      client.listen(server.add, onDone: server.destroy, onError: (_) {});
      server.listen(
        (data) {
          if (!holdReplies) client.add(data);
        },
        onDone: client.destroy,
        onError: (_) {},
      );
    });
  }

  String get host => _server.address.address;

  int get port => _server.port;

  /// Drops every connection, as the network would.
  void drop() {
    for (var socket in _sockets) {
      socket.destroy();
    }
  }

  Future close() {
    drop();
    return _server.close();
  }
}
