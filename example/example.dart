import 'package:rethink_db_ns/rethink_db_ns.dart';

void main() async {
  RethinkDb r = RethinkDb();
  Connection conn = await r.connect(
      db: 'testDB',
      host: "localhost",
      port: 28015,
      user: "admin",
      password: "");

  // Insert data
  Map createdRecord = await r.table("user_account").insert([
    {
      'id': 1,
      'name': 'William',
      'children': [
        {'id': 1, 'name': 'Robert'},
        {'id': 2, 'name': 'Mariah'}
      ]
    },
    {
      'id': 2,
      'name': 'Peter',
      'children': [
        {'id': 1, 'name': 'Louis'}
      ],
      'nickname': 'Jo'
    },
    {'id': 3, 'name': 'Firstname Last'}
  ]).run(conn);

  // Retrive data
  Cursor users =
      await r.table("user_account").filter({'name': 'Peter'}).run(conn);

  List userList = await users.toList();

  conn.close();
}
