part of '../belatuk_rethinkdb.dart';

class Cursor extends Stream {
  final Connection _conn;
  final Query _query;
  final Map _opts;
  int _outstandingRequests = 0;
  bool _endFlag = false;
  bool _delivering = false;
  bool _closing = false;
  final StreamController _s = StreamController();

  Cursor(this._conn, this._query, this._opts) {
    _conn._cursors.add(this);
  }

  void _extend(Response response) {
    // A batch that arrives after close(), such as the reply to its STOP, is
    // not delivered.
    if (_closing) return;
    _endFlag = response._type != p.Response_ResponseType.SUCCESS_PARTIAL.value;

    var error =
        _conn._checkErrorResponse(response, _query._term) ??
        (response._type != p.Response_ResponseType.SUCCESS_PARTIAL.value &&
                response._type != p.Response_ResponseType.SUCCESS_SEQUENCE.value
            ? RqlDriverError("Unexpected response type received for cursor")
            : null);
    if (error != null) {
      // The data of an error response is its message, not results, and the
      // server has ended the query.
      _s.addError(error);
      close();
      return;
    }

    var convertedData = _query._recursivelyConvertPseudotypes(
      response._data,
      _opts,
    );
    _delivering = true;
    _s.addStream(Stream.fromIterable(convertedData as Iterable)).then((f) {
      _delivering = false;
      if (_closing || _endFlag) {
        // Closed while this batch was delivered, or the last batch.
        _end();
      } else {
        _outstandingRequests++;
        Query query = Query(
          p.Query_QueryType.CONTINUE,
          _query._token,
          null,
          null,
        );
        query._cursor = this;
        // An error of the next batch is added to this cursor by _extend, so
        // the future of the query itself is not listened to.
        _conn._send(query).ignore();
      }
    });
  }

  /// Ends this cursor: it asks for no more batches, and the server stops the
  /// query unless it has ended. A batch being delivered is delivered first,
  /// since the stream cannot be closed before.
  Future close() {
    if (!_closing) {
      _closing = true;
      if (!_endFlag && !_conn.isClosed) {
        _outstandingRequests++;
        Query query = Query(p.Query_QueryType.STOP, _query._token, null, null);
        // The reply goes to this cursor, which ignores it.
        query._cursor = this;
        _conn._send(query).ignore();
      }
      if (!_delivering) _end();
    }
    return _s.done;
  }

  void _end() {
    _s.close();
    _conn._cursors.remove(this);
  }

  /// Ends this cursor, as its connection is closed.
  void _connectionClosed() {
    close();
  }

  @override
  StreamSubscription listen(
    Function(dynamic)? onData, {
    Function? onError,
    Function()? onDone,
    bool? cancelOnError,
  }) {
    return _s.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class Feed extends Cursor {
  Feed(super.conn, super.opts, super.query);

  @override
  toSet() => throw RqlDriverError("`toSet` is not available for feeds.");
  @override
  toList() => throw RqlDriverError("`toList` is not available for feeds.");
  @override
  toString() => "Instance of 'Feed'";
}

class UnionedFeed extends Cursor {
  UnionedFeed(super.conn, super.opts, super.query);

  @override
  toSet() => throw RqlDriverError("`toSet` is not available for feeds.");
  @override
  toList() => throw RqlDriverError("`toList` is not available for feeds.");
  @override
  toString() => "Instance of 'UnionedFeed'";
}

class AtomFeed extends Cursor {
  AtomFeed(super.conn, super.opts, super.query);

  @override
  toSet() => throw RqlDriverError("`toSet` is not available for feeds.");
  @override
  toList() => throw RqlDriverError("`toList` is not available for feeds.");
  @override
  toString() => "Instance of 'AtomFeed'";
}

class OrderByLimitFeed extends Cursor {
  OrderByLimitFeed(super.conn, super.opts, super.query);

  @override
  toSet() => throw RqlDriverError("`toSet` is not available for feeds.");
  @override
  toList() => throw RqlDriverError("`toList` is not available for feeds.");
  @override
  toString() => "Instance of 'OrderByLimitFeed'";
}
