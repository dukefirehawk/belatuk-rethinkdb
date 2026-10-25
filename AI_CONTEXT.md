# AI Context for Belatuk RethinkDB

## Project Overview

**Belatuk RethinkDB** (`belatuk_rethinkdb` on pub.dev) is a Dart driver for [RethinkDB](https://rethinkdb.com/), the open-source database for the realtime web. It is a fork of [rethink_db](https://github.com/G0mb/rethink_db), kept up to date with current Dart SDKs and dependencies. It is a single package, not a monorepo.

Its main consumer is `angel3_rethinkdb` in the [Angel3 framework](https://github.com/dart-backend/angel), which builds a `RethinkService` on top of it. A change to cursors, changefeeds or connections can affect that package.

## Repository Structure

- `lib/belatuk_rethinkdb.dart`: The library. It defines `RethinkDb` (the `r` entry point that builds queries and opens connections) and the callable helper classes (`AddFunction` and others), and pulls in everything under `lib/src/` as `part` files. Private members are therefore shared across all of these files.
- `lib/src/ast.dart`: The ReQL query tree. Every term (`Table`, `Get`, `Filter`, `Insert`, ...) extends `RqlQuery`, whose `run(connection)` sends the query.
- `lib/src/net.dart`: `Connection` (handshake, send queue, replies), and the `Query` and `Response` wire types.
- `lib/src/cursor.dart`: `Cursor`, a `Stream` of results fetched in batches, and the changefeed types `Feed`, `UnionedFeed`, `AtomFeed` and `OrderByLimitFeed`.
- `lib/src/errors.dart`: The `RqlError` hierarchy (`RqlDriverError`, `RqlClientError`, `RqlCompileError`, `RqlRuntimeError`, ...).
- `lib/src/generated/`: Protobuf code generated from RethinkDB's `ql2.proto`, used for the protocol's enums (query, response and term types). **Do not edit by hand**: regenerate with `regenerate-proto.sh`, which downloads the latest `ql2.proto` and needs `protoc` and `protoc-gen-dart` on the `PATH`.
- `test/`: Integration tests, one file per area of the API (`selectingdata_test.dart`, `writingdata_test.dart`, `cursor_close_test.dart`, ...).
- `example/example.dart`: A runnable usage example.
- `doc/deployment/`: Compose files for running RethinkDB with Podman, Rancher (`nerdctl`) or Docker.

## How the Driver Works

1. **Building a query:** `r.table('x').filter(...)` builds a tree of `RqlQuery` terms. Nothing is sent until `run(connection)` is called.
2. **Connecting:** `RethinkDb.connect()` opens a socket, sends the V1_0 handshake and authenticates with SCRAM-SHA-256. The defaults are `localhost:28015`, user `admin`, no password.
3. **Sending:** `run` wraps the term in a `Query` with a new token, and `Connection._send()` queues it and returns its `Future`. `_sendQuery()` empties `_sendQueue`: it writes each query to the socket as JSON (the 8-byte token, the 4-byte length, then the body) and stores it in `_replyQueries` under its token, or fails it if the connection is closed, so no query is left for a later connection.
4. **Replies:** `_readResponse` matches each `Response` to its query by token, and ignores a reply to a query it no longer waits for. A reply to a query with a cursor goes to `_handleCursorResponse` only; any other goes to `_handleQueryResponse`, where an atom completes the query's `Future`, and a sequence or a changefeed creates a `Cursor`.
5. **Cursors:** every batch is passed to `Cursor._extend`, which adds it to the cursor's stream. If more batches remain, it sends a `CONTINUE` query with the same token; the query is forgotten after the last batch. An error response ends the cursor with the server's error. `Cursor.close()` sends a `STOP` query unless the cursor has ended, and ignores the batches that arrive afterwards.
6. **Closing:** `Connection._closed()` is the one teardown, whether `close()`, the server or the network closed the socket. It ends the open cursors, which the connection keeps in `_cursors`, and fails a connect waiting for its handshake. When the server or the network dropped the connection, it fails the queries waiting for a reply; after `close()`, it drops them, so that a query run without waiting for it is not an uncaught error. A cursor delivering a batch ends once the batch is delivered, since its stream cannot be closed before. `close()` forgets the socket before destroying it, since destroying it ends its stream, which would otherwise count as a drop.
7. **Reconnecting:** each `reconnect()` has its own completer. A `reconnect()` while a connect is in progress fails the earlier one, and a socket that arrives for a replaced attempt is destroyed.

Errors from the server are checked with `_checkErrorResponse` and turned into `RqlError`s. A query on a closed connection fails with `RqlDriverError('Connection is closed.')`.

## Technology Stack & Requirements

- **Language**: Dart
- **Minimum SDK Version**: `>=3.13.0 <4.0.0`
- **Dependencies**: `protobuf` (wire protocol enums), `hashlib` and `crypto` (SCRAM authentication), `convert`, `fixnum`
- **Lints**: `package:lints/recommended.yaml`, with `constant_identifier_names` ignored for the generated protobuf names

## Testing

- **A running RethinkDB server is required.** The tests connect to `localhost:28015` as `admin` with no password. Start one with a compose file in `doc/deployment/`, e.g. `podman-compose -f doc/deployment/podman-compose-rethinkdb.yml -p rethink up -d`.
- **Test databases:** most test files create a database with a random name (`r.uuid()`, e.g. `test_database_<uuid>`) and drop it in their last test, so test files can run in parallel without clashing. Follow this pattern in new tests, and always drop what the test creates.
- **Run everything** with `dart test`, or one area with, e.g., `dart test test/cursor_close_test.dart`.
- **Changes to connections, cursors or changefeeds:** test the close and error paths, not only the happy path. An error on a `Future` that nobody listens to is an uncaught error, which fails whichever test happens to be running, not necessarily the one at fault. Running such a test several times in a row helps reveal races.
- **Before committing**, `dart format .`, `dart analyze` and `dart test` should all pass.

## Development Workflow

- **Branches:** `main` is the released branch. Work is done on `feature/<name>` branches (e.g. `feature/dart3.13`) and merged through pull requests; release preparation is done on `release/<name>` branches.
- **Versioning:** follows semantic versioning. A bug fix is a patch release (e.g. `2.0.0` → `2.0.1`), and a new SDK requirement or dependency major has been a minor release. Bump `version` in `pubspec.yaml` together with the `CHANGELOG.md` entry.
- **Commit messages:** use [Conventional Commits](https://www.conventionalcommits.org/) (`type(scope): description`, with `!` for breaking changes), e.g. `fix(cursor): end open cursors when the connection closes`.
- **Changelog**: Every user-facing change gets an entry in `CHANGELOG.md`, written as plain-English statements about the driver (not commit messages). Group a release's entries under `### Breaking changes in X.Y.Z` (each entry prefixed `**Breaking:**`), `### New in X.Y.Z` and `### Fixes in X.Y.Z`, in that order, omitting empty sections. Prefix each fix with a bold area label, e.g. `* **Cursors:** Closing a cursor while it delivers a batch no longer throws`. See the 2.0.0 entry for the reference style; releases before it are plain lists.

## Known Technical Debt

- **Loose typing:** much of the internals is untyped. For example, `Connection._replyQueries` is a plain `Map`, and many terms take `dynamic`. Add types when touching such code, without changing the public API.
- **In-flight queries on close():** after a deliberate `close()`, a query still waiting for its reply is dropped, so its `Future` never completes. Failing it would turn queries run without waiting for them into uncaught errors; a drop by the server or the network does fail them.
- **Leftovers from the fork:** `// ignore: unnecessary_null_comparison` comments for checks that null safety made redundant, and `TODO`s in `ast.dart` (e.g. `index`, `multi` and `interleave` options) and `net.dart` (errors from closing the socket are ignored).
