# Belatuk RethinkDB

This is a fork of [RethinkDB Driver](https://github.com/G0mb/rethink_db) with update to support Dart 3.

## Getting Started

### Install package

* Install from [Pub](https://pub.dev/)

```bash
dart pub add belatuk_rethinkdb

```

* Add to pubspec.yaml file

```yaml
dependencies:
  belatuk_rethinkdb: ^1.0.0
```

* Import the package into your project:

```dart
import 'package:belatuk_rethinkdb/belatuk_rethinkdb.dart';
```

### Example

```dart
RethinkDb r = RethinkDb();

final connection = await r.connection(
  db: 'test',
  host: 'localhost',
  port: 28015,
  user: 'admin',
  password: '',
);

// Create table
await r.db('test').tableCreate('tv_shows').run(connection);

// Insert data
await r.table('tv_shows').insert([
      {'name': 'Star Trek TNG', 'episodes': 178},
      {'name': 'Battlestar Galactica', 'episodes': 75}
    ]).run(connection);

// Fetch data
var result = await r.table('tv_shows').get(1).run(connection);
```

Refer to [RethinkDB Documentation](https://rethinkdb.com/api/javascript/) for other types of queries.

### Unit Test

```sh
dart test
```
