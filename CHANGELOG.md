# Change Log

## 2.0.0

### Breaking changes in 2.0.0

* **Breaking:** A query run on a closed connection throws an `RqlDriverError`, where it returned `null` and the error was uncaught. It is not kept and sent after a `reconnect()`
* **Breaking:** When the server or the network closes the connection, the queries waiting for a reply fail with an `RqlDriverError`, where they never completed. After `close()`, they are dropped as before
* **Breaking:** An error of a cursor, such as a changefeed whose table is dropped, is the server's error and ends the cursor, where it was `Unexpected response type received for cursor` followed by the error message as data
* **Breaking:** `reconnect()` waits for the new connection, where it returned at once and its queries failed with `Connection is closed.`. A `reconnect()` while a connect is in progress replaces it, and the earlier connect fails with an `RqlDriverError`

### Fixes in 2.0.0

* **Cursors:** Closing a cursor, such as a changefeed waiting for changes, stops its query on the server, and a batch that arrives afterwards is not delivered, where it threw an uncaught `StateError`
* **Cursors:** A cursor can be closed while it delivers a batch, where `close()` threw a `StateError`
* **Cursors:** Every batch of a cursor goes to that cursor only, where each one also made a new cursor that held its data until the connection closed
* **Cursors:** Closing a connection while a cursor asks for its next batch no longer causes an uncaught `Connection is closed.` error
* **Connections:** Closing a connection, or the server or the network closing it, ends its open cursors, such as changefeeds waiting for changes, where their streams never ended. A write that fails because the peer closed the socket is no longer an uncaught error
* **Connections:** `connect()` fails with an `RqlDriverError` when the connection closes during the handshake, where it never completed
* **Connections:** A reply to a query the connection no longer waits for is ignored, where it could throw an uncaught error
* **Connections:** `close()` and `server()` no longer leave a query in the send queue, whose result the next query could get instead of its own
* **Queries:** `wait()`, `slice()` and `getNearest()` work without options, where they threw a null-check error

## 1.4.0

* Require dart >= 3.13.0
* Upgraded `protobuf` to 6.0.0

## 1.3.0

* Require dart >= 3.9.0
* Upgraded `protobuf` to 5.0.0

## 1.2.0

* Require dart >= 3.8.0
* Updated `lints` to 6.0.0
* Updated dependencies
* Updated README
* Fixed linter warnings

## 1.1.0

* Require dart >= 3.5.0
* Updated `lints` to 5.0.0
* Updated dependencies
* Updated README
* Fixed linter warnings

## 1.0.1

* Updated README
* Fixed linter warnings

## 1.0.0

* Require dart >= 3.3.0
* Updated dependencies
* Updated README
* Fixed linter warnings
* Added `lints` 4.0.0
* Added `hashlib`
* Removed `pbkdf2ns`

## 0.0.4

* Fix readme info

## 0.0.3

* Remove flutter as a dependency
* Fix failing test

## 0.0.2

* Update dependencies
* Update documentation

## 0.0.1

* Null safety support
* [PBKDF2](https://github.com/G0mb/pbkdf2) dependency update
