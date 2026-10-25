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
3. **Sending:** `run` wraps the term in a `Query` with a new token. `Connection._sendQuery()` takes it off `_sendQueue`, writes it to the socket as JSON (the 8-byte token, the 4-byte length, then the body), and stores it in `_replyQueries` under its token.
4. **Replies:** `_readResponse` matches each `Response` to its query by token. An atom completes the query's `Future`. A sequence or a changefeed returns a `Cursor`.
5. **Cursors:** every batch is passed to `Cursor._extend`, which adds it to the cursor's stream. If more batches remain, it sends a `CONTINUE` query with the same token. Closing the connection ends the open cursors.

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
- **Versioning:** follows semantic versioning. A bug fix is a patch release (`1.4.0` → `1.4.1`), and a new SDK requirement or dependency major has been a minor release. Bump `version` in `pubspec.yaml` together with the `CHANGELOG.md` entry.
- **Commit messages:** use [Conventional Commits](https://www.conventionalcommits.org/) (`type(scope): description`, with `!` for breaking changes), e.g. `fix(cursor): end open cursors when the connection closes`.
- **Changelog**: Every user-facing change gets an entry in the affected package's `CHANGELOG.md`, written as plain-English statements about the package (not commit messages). Group a release's entries under `### Breaking changes in X.Y.Z` (each entry prefixed `**Breaking:**`), `### New in X.Y.Z` and `### Fixes in X.Y.Z`, in that order, omitting empty sections. Prefix each fix with a bold area label, e.g. `* **Services:** An invalid id is a 400`. See `packages/framework/CHANGELOG.md` (10.0.0) for the reference style. Commit messages use [Conventional Commits](https://www.conventionalcommits.org/) (`type(scope): description`, `!` for breaking changes).

## Known Technical Debt

- **Loose typing:** much of the internals is untyped. For example, `Connection._replyQueries` is a plain `Map`, and many terms take `dynamic`. Add types when touching such code, without changing the public API.
- **In-flight queries on close:** closing a connection ends its cursors, but a query still waiting for its reply is not failed, so its `Future` never completes.
- **Leftovers from the fork:** `// ignore: unnecessary_null_comparison` comments for checks that null safety made redundant, and `TODO`s in `ast.dart` (e.g. `index`, `multi` and `interleave` options) and `net.dart` (errors from closing the socket are ignored).
