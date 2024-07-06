part of '../belatuk_rethinkdb.dart';

const defaultNestingDepth = 20;

List buildInvocationParams(List<dynamic> positionalArguments,
    [List<String>? optionsNames]) {
  List argsList = [];
  argsList.addAll(positionalArguments);
  Map? options = {};
  if (argsList.length > 1 && argsList.last is Map) {
    if (optionsNames == null) {
      options = argsList.removeLast();
    } else {
      Map lastArgument = argsList.last;
      bool isOptions = true;
      lastArgument.forEach((key, _) {
        if (!optionsNames.contains(key)) {
          isOptions = false;
        }
      });
      if (isOptions) {
        options = argsList.removeLast();
      }
    }
  }
  List invocationParams = [argsList];
  if (options!.isNotEmpty) {
    invocationParams.add(options);
  }
  return invocationParams;
}

// TODO: handle index.
// TODO: handle multi.
class GroupFunction {
  final RqlQuery? _rqlQuery;

  GroupFunction([this._rqlQuery]);

  Group call(args) {
    if (args is List) {
      return Group(_rqlQuery, args, null);
    } else {
      return Group(_rqlQuery, [args], null);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    List positionalArguments = [];
    positionalArguments.addAll(invocation.positionalArguments);
    List invocationParams =
        buildInvocationParams(positionalArguments, ['index', 'multi']);
    return Group(_rqlQuery, invocationParams[0],
        invocationParams.length == 2 ? invocationParams[1] : null);
  }
}

class HasFieldsFunction {
  final RqlQuery? _rqlQuery;

  HasFieldsFunction([this._rqlQuery]);

  HasFields call(items) {
    return HasFields(_rqlQuery, items);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    List positionalArguments = [];
    positionalArguments.addAll(invocation.positionalArguments);
    return HasFields(_rqlQuery, buildInvocationParams(positionalArguments));
  }
}

class MergeFunction {
  final RqlQuery? _rqlQuery;

  MergeFunction([this._rqlQuery]);

  Merge call(obj) {
    return Merge([_rqlQuery, obj]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    List positionalArguments = [];
    positionalArguments.add(_rqlQuery);
    positionalArguments.addAll(invocation.positionalArguments);
    return Merge(positionalArguments);
  }
}

class PluckFunction {
  final RqlQuery? _rqlQuery;

  PluckFunction([this._rqlQuery]);

  Pluck call(args) {
    return Pluck(_rqlQuery!._listify(args, _rqlQuery));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    List positionalArguments = [];
    positionalArguments.addAll(invocation.positionalArguments);
    return Pluck(_rqlQuery!
        ._listify(buildInvocationParams(positionalArguments), _rqlQuery));
  }
}

// TODO: handle interleave.
class UnionFunction {
  final RqlQuery? _rqlQuery;

  UnionFunction([this._rqlQuery]);

  Union call(sequence) {
    return Union(_rqlQuery, [sequence]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    List positionalArguments = [];
    positionalArguments.addAll(invocation.positionalArguments);
    List invocationParams =
        buildInvocationParams(positionalArguments, ['interleave']);
    if (invocationParams.length == 2) {
      return Union(_rqlQuery, [invocationParams[0], invocationParams[1]]);
    } else {
      return Union(_rqlQuery, invocationParams[0]);
    }
  }
}

class WithoutFunction {
  final RqlQuery? _rqlQuery;

  WithoutFunction([this._rqlQuery]);

  Without call(items) {
    return Without(_rqlQuery!._listify(items, _rqlQuery));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    List positionalArguments = [];
    positionalArguments.addAll(invocation.positionalArguments);
    return Without(_rqlQuery!
        ._listify(buildInvocationParams(positionalArguments), _rqlQuery));
  }
}

class WithFieldsFunction {
  final RqlQuery? _rqlQuery;

  WithFieldsFunction([this._rqlQuery]);

  WithFields call(items) {
    return WithFields(_rqlQuery, items);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    List positionalArguments = [];
    positionalArguments.addAll(invocation.positionalArguments);
    return WithFields(_rqlQuery, buildInvocationParams(positionalArguments));
  }
}

class RqlMapFunction {
  final RqlQuery _rqlQuery;

  RqlMapFunction(this._rqlQuery);

  call(mappingFunction) {
    if (mappingFunction is List) {
      mappingFunction.insert(0, _rqlQuery);
      var item = _rqlQuery._funcWrap(
          mappingFunction.removeLast(), mappingFunction.length);
      return RqlMap(mappingFunction, item);
    }
    return RqlMap([_rqlQuery], mappingFunction);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    List mappingFunction = List.from(invocation.positionalArguments);
    mappingFunction.insert(0, _rqlQuery);
    var item = _rqlQuery._funcWrap(
        mappingFunction.removeLast(), mappingFunction.length);
    return RqlMap(mappingFunction, item);
  }
}

class RqlQuery {
  p.Term_TermType? termType;

  List args = [];
  Map optargs = {};

  RqlQuery([List? args, Map? optargs]) {
    if (args != null) {
      for (var e in args) {
        if (_checkIfOptions(e, termType)) {
          optargs ??= e;
        } else if (e != null) {
          this.args.add(_expr(e));
        }
      }
    }

    if (optargs != null) {
      optargs.forEach((k, v) {
        if ((k == "conflict") && (v is Function)) {
          this.optargs[k] = _expr(v, defaultNestingDepth, 3);
        } else {
          this.optargs[k] = _expr(v);
        }
      });
    }
  }

  _expr(val, [nestingDepth = defaultNestingDepth, argsCount]) {
    if (nestingDepth <= 0) {
      throw RqlDriverError("Nesting depth limit exceeded");
    }

    if (nestingDepth is int == false) {
      throw RqlDriverError("Second argument to `r.expr` must be a number.");
    }

    if (val is RqlQuery) {
      return val;
    } else if (val is List) {
      for (var v in val) {
        v = _expr(v, nestingDepth - 1, argsCount);
      }

      return MakeArray(val);
    } else if (val is Map) {
      Map obj = {};

      val.forEach((k, v) {
        obj[k] = _expr(v, nestingDepth - 1, argsCount);
      });

      return MakeObj(obj);
    } else if (val is Function) {
      return Func(val, argsCount);
    } else if (val is DateTime) {
      return Time(Args([
        val.year,
        val.month,
        val.day,
        val.hour,
        val.minute,
        val.second,
        _formatTimeZoneOffset(val)
      ]));
    }
    return Datum(val);
  }

  String _formatTimeZoneOffset(DateTime val) {
    String tz = val.timeZoneOffset.inHours.toString();

    if (!val.timeZoneOffset.inHours.isNegative) {
      tz = "+$tz";
    }

    if (tz.length == 2) {
      tz = tz.replaceRange(0, 1, "${tz[0]}0");
    }

    return tz;
  }

  Future run(Connection c, [globalOptargs]) {
    //if (c == null) {
    //  throw RqlDriverError("RqlQuery.run must be given a connection to run.");
    //}

    return c._start(this, globalOptargs);
  }

  //since a term that may take multiple options can now be passed
  //one or two, we can't know if the final argument in a query
  //is actually an option or just another arg.  _check_if_options
  //checks if all of the keys in the object are in options
  _checkIfOptions(obj, p.Term_TermType? tt) {
    if (obj is Map == false) {
      return false;
    } else {
      List? options = _RqlAllOptions(tt).options;

      return obj.keys.every(options!.contains);
    }
  }

  build() {
    List res = [];
    if (tt != null) {
      res.add(tt!.value);
    }

    List argList = [];
    for (var arg in args) {
      if (arg != null) {
        argList.add(arg.build());
      }
    }
    res.add(argList);

    if (optargs.isNotEmpty) {
      Map optArgsMap = {};
      optargs.forEach((k, v) {
        optArgsMap[k] = v.build();
      });
      res.add(optArgsMap);
    }
    return res;
  }

  _recursivelyConvertPseudotypes(obj, formatOpts) {
    if (obj is Map) {
      obj.forEach((k, v) {
        obj[k] = _recursivelyConvertPseudotypes(v, formatOpts);
      });
      obj = _convertPseudotype(obj, formatOpts);
    } else if (obj is List) {
      for (var e in obj) {
        e = _recursivelyConvertPseudotypes(e, formatOpts);
      }
    }
    return obj;
  }

  _listify(args, [parg]) {
    if (args is List) {
      args.insert(0, parg);
      return args;
    } else {
      if (args != null) {
        if (parg != null) {
          return [parg, args];
        } else {
          return [args];
        }
      } else {
        return [];
      }
    }
  }

  bool _ivarScan(query) {
    if (query is! RqlQuery) {
      return false;
    }

    if (query is ImplicitVar) {
      return true;
    }
    if (query.args.any(_ivarScan)) {
      return true;
    }

    var optArgKeys = query.optargs.values;

    if (optArgKeys.any(_ivarScan)) {
      return true;
    }
    return false;
  }

  // Called on arguments that should be functions
  _funcWrap(val, [argsCount]) {
    val = _expr(val, defaultNestingDepth, argsCount);
    if (_ivarScan(val)) {
      return Func((x) => val, argsCount);
    }
    return val;
  }

  _reqlTypeTimeToDatetime(Map obj) {
    if (obj["epoch_time"] == null) {
      throw RqlDriverError(
          'pseudo-type TIME object $obj does not have expected field "epoch_time".');
    } else {
      String s = obj["epoch_time"].toString();
      if (s.contains(".")) {
        List l = s.split('.');
        while (l[1].length < 3) {
          l[1] = l[1] + "0";
        }
        s = l.join("");
      } else {
        s += "000";
      }
      return DateTime.fromMillisecondsSinceEpoch(int.parse(s));
    }
  }

  _reqlTypeGroupedDataToObject(Map obj) {
    if (obj['data'] == null) {
      throw RqlDriverError(
          'pseudo-type GROUPED_DATA object $obj does not have the expected field "data".');
    }

    Map retObj = {};
    obj['data'].forEach((e) {
      retObj[e[0]] = e[1];
    });
    return retObj;
  }

  _convertPseudotype(Map obj, Map? formatOpts) {
    String? reqlType = obj['\$reql_type\$'];
    if (reqlType != null) {
      if (reqlType == 'TIME') {
        if (formatOpts == null || formatOpts.isEmpty) {
          formatOpts = {"time_format": "native"};
        }
        String timeFormat = formatOpts['time_format'];
        if (timeFormat == 'native') {
          // Convert to native dart DateTime
          return _reqlTypeTimeToDatetime(obj);
        } else if (timeFormat != 'raw') {
          throw RqlDriverError("Unknown time_format run option $timeFormat.");
        }
      } else if (reqlType == 'GROUPED_DATA') {
        if (formatOpts == null ||
            formatOpts.isEmpty ||
            formatOpts['group_format'] == 'native') {
          return _reqlTypeGroupedDataToObject(obj);
        } else if (formatOpts['group_format'] != 'raw') {
          throw RqlDriverError(
              "Unknown group_format run option ${formatOpts['group_format']}.");
        }
      } else if (reqlType == "BINARY") {
        if (formatOpts == null || formatOpts["binary_format"] == "native") {
          /// TODO: the official drivers decode the BASE64 string to binary data
          /// this driver currently has a bug with its [_reqlTypeBinaryToBytes]
          /// for some reason, when trying to convert the index function for
          /// `indexWait` commands, we get a FormatException.
          ///  so for the short term we will just return the BASE64 string
          ///  with a to find out what is wrong and fix it.

          try {
            return _reqlTypeBinaryToBytes(obj);
          } on FormatException {
            return obj['data'];
          }
        } else {
          throw RqlDriverError(
              "Unknown binary_format run option: ${formatOpts["binary_format"]}");
        }
      } else if (reqlType == "GEOMETRY") {
        obj.remove('\$reql_type\$');
        return obj;
      } else {
        throw RqlDriverError("Unknown pseudo-type $reqlType");
      }
    }

    return obj;
  }

  _reqlTypeBinaryToBytes(Map obj) {
    return base64.decode(obj['data']);
  }

  Update update(args, [options]) => Update(this, _funcWrap(args, 1), options);

  // Comparison operators
  dynamic get eq => EqFunction(this);

  dynamic get ne => NeFunction(this);

  dynamic get lt => LtFunction(this);

  dynamic get le => LeFunction(this);

  dynamic get gt => GtFunction(this);

  dynamic get ge => GeFunction(this);

  // Numeric operators
  Not not() => Not(this);

  dynamic get add => AddFunction(this);

  dynamic get sub => SubFunction(this);

  dynamic get mul => MulFunction(this);

  dynamic get div => DivFunction(this);

  Mod mod(other) => Mod(this, other);

  dynamic get and => AndFunction(this);

  dynamic get or => OrFunction(this);

  Contains contains(args) => Contains(this, _funcWrap(args, 1));

  dynamic get hasFields => HasFieldsFunction(this);

  dynamic get withFields => WithFieldsFunction(this);

  Keys keys() => Keys(this);

  Values values() => Values(this);

  Changes changes([Map? opts]) => Changes(this, opts);

  // Polymorphic object/sequence operations
  dynamic get pluck => PluckFunction(this);

  dynamic get without => WithoutFunction(this);

  FunCall rqlDo(arg, [expression]) {
    if (expression == null) {
      return FunCall(this, _funcWrap(arg, 1));
    } else {
      return FunCall(_listify(arg, this), _funcWrap(expression, arg.length));
    }
  }

  Default rqlDefault(args) => Default(this, args);

  Replace replace(expr, [options]) =>
      Replace(this, _funcWrap(expr, 1), options);

  Delete delete([options]) => Delete(this, options);

  // Rql type inspection
  coerceTo(String type) => CoerceTo(this, type);

  Ungroup ungroup() => Ungroup(this);

  TypeOf typeOf() => TypeOf(this);

  dynamic get merge => MergeFunction(this);

  Append append(val) => Append(this, val);

  Floor floor() => Floor(this);

  Ceil ceil() => Ceil(this);

  Round round() => Round(this);

  Prepend prepend(val) => Prepend(this, val);

  Difference difference(List ar) => Difference(this, ar);

  SetInsert setInsert(val) => SetInsert(this, val);

  SetUnion setUnion(ar) => SetUnion(this, ar);

  SetIntersection setIntersection(ar) => SetIntersection(this, ar);

  SetDifference setDifference(ar) => SetDifference(this, ar);

  GetField getField(index) => GetField(this, index);

  Nth nth(int index) => Nth(this, index);

  Match match(String regex) => Match(this, regex);

  Split split([seperator = " ", maxSplits]) =>
      Split(this, seperator, maxSplits);

  Upcase upcase() => Upcase(this);

  Downcase downcase() => Downcase(this);

  IsEmpty isEmpty() => IsEmpty(this);

  Slice slice(int start, [end, Map? options]) =>
      Slice(this, start, end, options!);

  Fold fold(base, function, [options]) => Fold(this, base, function, options);

  Skip skip(int i) => Skip(this, i);

  Limit limit(int i) => Limit(this, i);

  Reduce reduce(reductionFunction, [base]) =>
      Reduce(this, _funcWrap(reductionFunction, 2), base);

  Sum sum([args]) => Sum(this, args);

  Avg avg([args]) => Avg(this, args);

  Min min([args]) => Min(this, args);

  Max max([args]) => Max(this, args);

  dynamic get map => RqlMapFunction(this);

  Filter filter(expr, [options]) => Filter(this, _funcWrap(expr, 1), options);

  ConcatMap concatMap(mappingFunction) =>
      ConcatMap(this, _funcWrap(mappingFunction, 1));

  Get get(id) => Get(this, id);

  OrderBy orderBy(attrs, [index]) {
    if (attrs is Map && attrs.containsKey("index")) {
      index = attrs;
      attrs = [];

      index.forEach((k, ob) {
        if (ob is Asc || ob is Desc) {
          //do nothing
        } else {
          ob = _funcWrap(ob, 1);
        }
      });
    } else if (attrs is List) {
      if (index is Map == false && index != null) {
        attrs.add(index);
        index = null;
      }
      for (var ob in attrs) {
        if (ob is Asc || ob is Desc) {
          //do nothing
        } else {
          ob = _funcWrap(ob, 1);
        }
      }
    } else {
      List tmp = [];
      tmp.add(attrs);
      if (index is Map == false && index != null) {
        tmp.add(index);
        index = null;
      }
      attrs = tmp;
    }

    return OrderBy(_listify(attrs, this), index);
  }

  operator +(other) => add(other);
  operator -(other) => sub(other);
  operator *(other) => mul(other);
  operator /(other) => div(other);
  // TODO see if we can still do this. != isn't assignable so maybe
  // it makes more sense not to do == anyway.
  //operator ==(other) => this.eq(other);
  operator <=(other) => le(other);
  operator >=(other) => ge(other);
  operator <(other) => lt(other);
  operator >(other) => gt(other);
  operator %(other) => mod(other);
  operator [](attr) => pluck(attr);

  Between between(lowerKey, [upperKey, options]) =>
      Between(this, lowerKey, upperKey, options);

  Distinct distinct() => Distinct(this);

  Count count([filter]) {
    if (filter == null) return Count(this);
    return Count(this, _funcWrap(filter, 1));
  }

  dynamic get union => UnionFunction(this);

  InnerJoin innerJoin(otherSequence, [predicate]) =>
      InnerJoin(this, otherSequence, predicate);

  OuterJoin outerJoin(otherSequence, [predicate]) =>
      OuterJoin(this, otherSequence, predicate);

  EqJoin eqJoin(leftAttr, [otherTable, options]) =>
      EqJoin(this, _funcWrap(leftAttr, 1), otherTable, options);

  Zip zip() => Zip(this);

  dynamic get group => GroupFunction(this);

  ForEach forEach(writeQuery) => ForEach(this, _funcWrap(writeQuery, 1));

  Info info() => Info(this);

  //Array only operations

  InsertAt insertAt(index, [value]) => InsertAt(this, index, value);

  SpliceAt spliceAt(index, [ar]) => SpliceAt(this, index, ar);

  DeleteAt deleteAt(index, [end]) => DeleteAt(this, index, end);

  ChangeAt changeAt(index, [value]) => ChangeAt(this, index, value);

  Sample sample(int i) => Sample(this, i);

  // Time support
  ToISO8601 toISO8601() => ToISO8601(this);

  ToEpochTime toEpochTime() => ToEpochTime(this);

  During during(start, [end, options]) => During(this, start, end, options);

  Date date() => Date(this);

  TimeOfDay timeOfDay() => TimeOfDay(this);

  Timezone timezone() => Timezone(this);

  Year year() => Year(this);

  Month month() => Month(this);

  Day day() => Day(this);

  DayOfWeek dayOfWeek() => DayOfWeek(this);

  DayOfYear dayOfYear() => DayOfYear(this);

  Hours hours() => Hours(this);

  Minutes minutes() => Minutes(this);

  Seconds seconds() => Seconds(this);

  InTimezone inTimezone(tz) => InTimezone(this, tz);

  Binary binary(data) => Binary(data);

  Distance distance(geo, [opts]) => Distance(this, geo, opts);

  Fill fill() => Fill(this);

  ToGeoJson toGeojson() => ToGeoJson(this);

  GetIntersecting getIntersecting(geo, Map? options) =>
      GetIntersecting(this, geo, options);

  GetNearest getNearest(point, [Map? options]) =>
      GetNearest(this, point, options!);

  Includes includes(geo) => Includes(this, geo);

  Intersects intersects(geo) => Intersects(this, geo);

  PolygonSub polygonSub(var poly) => PolygonSub(this, poly);

  Config config() => Config(this);

  Rebalance rebalance() => Rebalance(this);

  Reconfigure reconfigure(Map? options) => Reconfigure(this, options);

  Status status() => Status(this);

  Wait wait([Map? options]) => Wait(this, options!);

  call(attr) {
    return GetField(this, attr);
  }
}

//TODO write pretty compose functions
class RqlBoolOperQuery extends RqlQuery {
  RqlBoolOperQuery([super.args, super.optargs]);
}

class RqlBiOperQuery extends RqlQuery {
  RqlBiOperQuery([super.args, super.optargs]);
}

class RqlBiCompareOperQuery extends RqlBiOperQuery {
  RqlBiCompareOperQuery([super.args, super.optargs]);
}

class RqlTopLevelQuery extends RqlQuery {
  RqlTopLevelQuery([super.args, super.optargs]);
}

class RqlMethodQuery extends RqlQuery {
  RqlMethodQuery([super.args, super.optargs]);
}

class RqlBracketQuery extends RqlMethodQuery {
  RqlBracketQuery([super.args, super.optargs]);
}

class Datum extends RqlQuery {
  //@override
  //List args = [];
  //@override
  //Map optargs = {};
  dynamic data;

  Datum(dynamic val) : super(null, null) {
    data = val;
  }

  @override
  build() {
    return data;
  }
}

class MakeArray extends RqlQuery {
  MakeArray(super.args) {
    tt = p.Term_TermType.MAKE_ARRAY;
  }
}

class MakeObj extends RqlQuery {
  MakeObj(objDict) : super(null, objDict) {
    tt = p.Term_TermType.MAKE_OBJ;
  }

  @override
  build() {
    var res = {};
    optargs.forEach((k, v) {
      res[k is RqlQuery ? k.build() : k] = v is RqlQuery ? v.build() : v;
    });
    return res;
  }
}

class Var extends RqlQuery {
  Var(args) : super([args]) {
    tt = p.Term_TermType.VAR;
  }

  @override
  call(attr) => GetField(this, attr);
}

class JavaScript extends RqlTopLevelQuery {
  JavaScript(args, [optargs]) : super([args], optargs) {
    tt = p.Term_TermType.JAVASCRIPT;
  }
}

class Http extends RqlTopLevelQuery {
  Http(args, [optargs]) : super([args], optargs) {
    tt = p.Term_TermType.HTTP;
  }
}

class UserError extends RqlTopLevelQuery {
  UserError(args, [optargs]) : super([args], optargs) {
    tt = p.Term_TermType.ERROR;
  }
}

class Random extends RqlTopLevelQuery {
  Random(optargs) : super(null, optargs ?? {}) {
    tt = p.Term_TermType.RANDOM;
  }

  Random.leftBound(left, optargs) : super([left], optargs ?? {}) {
    tt = p.Term_TermType.RANDOM;
  }

  Random.rightBound(left, right, optargs)
      : super([left, right], optargs ?? {}) {
    tt = p.Term_TermType.RANDOM;
  }
}

class Changes extends RqlMethodQuery {
  Changes([arg, opts]) : super([arg], opts) {
    tt = p.Term_TermType.CHANGES;
  }
}

class Fold extends RqlMethodQuery {
  Fold(seq, base, func, [opts]) : super([seq, base, func], opts) {
    tt = p.Term_TermType.FOLD;
  }
}

class Grant extends RqlMethodQuery {
  Grant([scope, user, options]) : super([scope, user], options) {
    tt = p.Term_TermType.GRANT;
  }
}

class Default extends RqlMethodQuery {
  Default(obj, value) : super([obj, value]) {
    tt = p.Term_TermType.DEFAULT;
  }
}

class ImplicitVar extends RqlQuery {
  ImplicitVar() : super() {
    tt = p.Term_TermType.IMPLICIT_VAR;
  }

  @override
  call(attr) => GetField(this, attr);
}

class Eq extends RqlBiCompareOperQuery {
  Eq(super.numbers) {
    tt = p.Term_TermType.EQ;
  }
}

class Ne extends RqlBiCompareOperQuery {
  Ne(super.numbers) {
    tt = p.Term_TermType.NE;
  }
}

class Lt extends RqlBiCompareOperQuery {
  Lt(super.numbers) {
    tt = p.Term_TermType.LT;
  }
}

class Le extends RqlBiCompareOperQuery {
  Le(super.numbers) {
    tt = p.Term_TermType.LE;
  }
}

class Gt extends RqlBiCompareOperQuery {
  Gt(super.numbers) {
    tt = p.Term_TermType.GT;
  }
}

class Ge extends RqlBiCompareOperQuery {
  Ge(super.numbers) {
    tt = p.Term_TermType.GE;
  }
}

class Not extends RqlQuery {
  Not([args]) : super([args]) {
    tt = p.Term_TermType.NOT;
  }
}

class Add extends RqlBiOperQuery {
  Add(super.objects) {
    tt = p.Term_TermType.ADD;
  }
}

class Sub extends RqlBiOperQuery {
  Sub(super.numbers) {
    tt = p.Term_TermType.SUB;
  }
}

class Mul extends RqlBiOperQuery {
  Mul(super.numbers) {
    tt = p.Term_TermType.MUL;
  }
}

class Div extends RqlBiOperQuery {
  Div(super.numbers) {
    tt = p.Term_TermType.DIV;
  }
}

class Mod extends RqlBiOperQuery {
  Mod(modable, obj) : super([modable, obj]) {
    tt = p.Term_TermType.MOD;
  }
}

class Append extends RqlMethodQuery {
  Append(ar, val) : super([ar, val]) {
    tt = p.Term_TermType.APPEND;
  }
}

class Floor extends RqlMethodQuery {
  Floor(ar) : super([ar]) {
    tt = p.Term_TermType.FLOOR;
  }
}

class Ceil extends RqlMethodQuery {
  Ceil(ar) : super([ar]) {
    tt = p.Term_TermType.CEIL;
  }
}

class Round extends RqlMethodQuery {
  Round(ar) : super([ar]) {
    tt = p.Term_TermType.ROUND;
  }
}

class Prepend extends RqlMethodQuery {
  Prepend(ar, val) : super([ar, val]) {
    tt = p.Term_TermType.PREPEND;
  }
}

class Difference extends RqlMethodQuery {
  Difference(diffable, ar) : super([diffable, ar]) {
    p.Term_TermType.DIFFERENCE;
  }
}

class SetInsert extends RqlMethodQuery {
  SetInsert(ar, val) : super([ar, val]) {
    p.Term_TermType.SET_INSERT;
  }
}

class SetUnion extends RqlMethodQuery {
  SetUnion(un, val) : super([un, val]) {
    tt = p.Term_TermType.SET_UNION;
  }
}

class SetIntersection extends RqlMethodQuery {
  SetIntersection(inter, ar) : super([inter, ar]) {
    tt = p.Term_TermType.SET_INTERSECTION;
  }
}

class SetDifference extends RqlMethodQuery {
  SetDifference(diff, ar) : super([diff, ar]) {
    tt = p.Term_TermType.SET_DIFFERENCE;
  }
}

class Slice extends RqlBracketQuery {
  Slice(selection, int start, [end, Map? options])
      : super([selection, start, end], options) {
    tt = p.Term_TermType.SLICE;
  }
}

class Skip extends RqlMethodQuery {
  Skip(selection, int number) : super([selection, number]) {
    tt = p.Term_TermType.SKIP;
  }
}

class Limit extends RqlMethodQuery {
  Limit(selection, int number) : super([selection, number]) {
    tt = p.Term_TermType.LIMIT;
  }
}

class GetField extends RqlBracketQuery {
  GetField(obj, field) : super([obj, field]) {
    tt = p.Term_TermType.BRACKET;
  }
}

class Contains extends RqlMethodQuery {
  Contains(tbl, items) : super([tbl, items]) {
    tt = p.Term_TermType.CONTAINS;
  }
}

class HasFields extends RqlMethodQuery {
  HasFields(obj, items) : super([obj, items]) {
    tt = p.Term_TermType.HAS_FIELDS;
  }
}

class WithFields extends RqlMethodQuery {
  WithFields(obj, fields) : super([obj, fields]) {
    tt = p.Term_TermType.WITH_FIELDS;
  }
}

class Keys extends RqlMethodQuery {
  Keys(obj) : super([obj]) {
    tt = p.Term_TermType.KEYS;
  }
}

class Values extends RqlMethodQuery {
  Values(obj) : super([obj]) {
    tt = p.Term_TermType.VALUES;
  }
}

class RqlObject extends RqlMethodQuery {
  RqlObject(super.args) {
    tt = p.Term_TermType.OBJECT;
  }
}

class Pluck extends RqlMethodQuery {
  Pluck(super.items) {
    tt = p.Term_TermType.PLUCK;
  }
}

class Without extends RqlMethodQuery {
  Without(super.items) {
    tt = p.Term_TermType.WITHOUT;
  }
}

class Merge extends RqlMethodQuery {
  Merge(super.objects) {
    tt = p.Term_TermType.MERGE;
  }
}

class Between extends RqlMethodQuery {
  Between(tbl, lower, upper, [options]) : super([tbl, lower, upper], options) {
    tt = p.Term_TermType.BETWEEN;
  }
}

class DB extends RqlTopLevelQuery {
  DB(String dbName) {
    tt = p.Term_TermType.DB;
    super([dbName]);
  }

  TableList tableList() => TableList(this);

  TableCreate tableCreate(String tableName, [Map? options]) =>
      TableCreate.fromDB(this, tableName, options);

  TableDrop tableDrop(String tableName) => TableDrop.fromDB(this, tableName);

  Table table(String tableName, [Map? options]) =>
      Table.fromDB(this, tableName, options);

  Grant grant(String user, [Map? options]) => Grant(this, user, options);
}

class FunCall extends RqlQuery {
  FunCall(argslist, expression) : super() {
    tt = p.Term_TermType.FUNCALL;

    List temp = [];
    temp.add(expression);
    int argsCount;
    if (argslist is List) {
      argsCount = argslist.length;
      temp.addAll(argslist);
    } else {
      argsCount = 1;
      temp.add(argslist);
    }

    args.addAll(temp.map((arg) {
      return _expr(arg, defaultNestingDepth, argsCount);
    }));
  }
}

class GetAllFunction extends RqlQuery {
  final Table _table;

  GetAllFunction(this._table);

  @override
  GetAll call(attr, [options]) {
    if (options != null && options is Map == false) {
      attr = _listify(attr, _table);
      options = attr.add(options);
      return GetAll(attr, options);
    }
    return GetAll(_listify(attr, _table), options);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    List argsList = [];
    argsList.addAll(invocation.positionalArguments);
    return Function.apply(call, [argsList]);
  }
}

class IndexStatusFunction extends RqlQuery {
  final Table _table;

  IndexStatusFunction(this._table);

  @override
  IndexStatus call([attr]) {
    if (attr == null) {
      return IndexStatus.all(_table);
    }
    return IndexStatus(_table, attr);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    List argsList = [];
    argsList.addAll(invocation.positionalArguments);
    return Function.apply(call, [argsList]);
  }
}

class IndexWaitFunction extends RqlQuery {
  final Table _table;

  IndexWaitFunction(this._table);

  @override
  IndexWait call([attr]) {
    if (attr == null) {
      return IndexWait.all(_table);
    }
    return IndexWait(_table, attr);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    List argsList = [];
    argsList.addAll(invocation.positionalArguments);
    return Function.apply(call, [argsList]);
  }
}

class Table extends RqlQuery {
  Table(String tableName, [Map? options]) : super([tableName], options) {
    tt = p.Term_TermType.TABLE;
  }

  Table.fromDB(DB db, String tableName, [Map? options])
      : super([db, tableName], options) {
    tt = p.Term_TermType.TABLE;
  }

  Insert insert(records, [options]) => Insert(this, records, options);

  Grant grant(user, [options]) => Grant(this, user, options);

  IndexList indexList() => IndexList(this);

  IndexCreate indexCreate(indexName, [indexFunction, Map? options]) {
    if (indexFunction == null && options == null) {
      return IndexCreate(this, indexName);
    } else if (indexFunction != null && indexFunction is Map) {
      return IndexCreate(this, indexName, indexFunction);
    }
    return IndexCreate.withIndexFunction(
        this, indexName, _funcWrap(indexFunction, 1), options);
  }

  IndexDrop indexDrop(indexName) => IndexDrop(this, indexName);

  IndexRename indexRename(oldName, newName, [Map? options]) =>
      IndexRename(this, oldName, newName, options);

  dynamic get indexStatus => IndexStatusFunction(this);

  dynamic get indexWait => IndexWaitFunction(this);

  @override
  Update update(args, [options]) => Update(this, _funcWrap(args, 1), options);

  Sync sync() => Sync(this);

  dynamic get getAll => GetAllFunction(this);

  @override
  InnerJoin innerJoin(otherSequence, [predicate]) =>
      InnerJoin(this, otherSequence, predicate);
}

class Get extends RqlMethodQuery {
  Get(table, key) : super([table, key]) {
    tt = p.Term_TermType.GET;
  }

  @override
  call(attr) {
    return GetField(this, attr);
  }
}

class GetAll extends RqlMethodQuery {
  GetAll(super.keys, [super.options]) {
    tt = p.Term_TermType.GET_ALL;
  }

  @override
  call(attr) {
    return GetField(this, attr);
  }
}

class Reduce extends RqlMethodQuery {
  Reduce(seq, reductionFunction, [base])
      : super([seq, reductionFunction], base) {
    tt = p.Term_TermType.REDUCE;
  }
}

class Sum extends RqlMethodQuery {
  Sum(obj, args) : super([obj, args]) {
    tt = p.Term_TermType.SUM;
  }
}

class Avg extends RqlMethodQuery {
  Avg(obj, args) : super([obj, args]) {
    tt = p.Term_TermType.AVG;
  }
}

class Min extends RqlMethodQuery {
  Min(obj, args) : super([obj, args]) {
    tt = p.Term_TermType.MIN;
  }
}

class Max extends RqlMethodQuery {
  Max(obj, args) : super([obj, args]) {
    tt = p.Term_TermType.MAX;
  }
}

class RqlMap extends RqlMethodQuery {
  RqlMap(argslist, expression) : super() {
    tt = p.Term_TermType.MAP;
    int argsCount = argslist.length;
    List temp = [];
    temp.addAll(argslist);
    temp.add(_funcWrap(expression, argsCount));
    args.addAll(temp.map((arg) {
      return _expr(arg, defaultNestingDepth, argsCount);
    }));
  }
}

class Filter extends RqlMethodQuery {
  Filter(selection, predicate, [Map? options])
      : super([selection, predicate], options) {
    tt = p.Term_TermType.FILTER;
  }
}

class ConcatMap extends RqlMethodQuery {
  ConcatMap(seq, mappingFunction) : super([seq, mappingFunction]) {
    tt = p.Term_TermType.CONCAT_MAP;
  }
}

class OrderBy extends RqlMethodQuery {
  OrderBy(super.args, [super.options]) {
    tt = p.Term_TermType.ORDER_BY;
  }
}

class Distinct extends RqlMethodQuery {
  Distinct(sequence) : super([sequence]) {
    tt = p.Term_TermType.DISTINCT;
  }
}

class Count extends RqlMethodQuery {
  Count([seq, filter]) : super([seq, filter]) {
    tt = p.Term_TermType.COUNT;
  }
}

class Union extends RqlMethodQuery {
  Union(first, second) : super([first, second]) {
    tt = p.Term_TermType.UNION;
  }
}

class Nth extends RqlBracketQuery {
  Nth(selection, int index) : super([selection, index]) {
    tt = p.Term_TermType.NTH;
  }
}

class Match extends RqlMethodQuery {
  Match(obj, regex) : super([obj, regex]) {
    tt = p.Term_TermType.MATCH;
  }
}

class Split extends RqlMethodQuery {
  Split(tbl, [obj, maxSplits]) : super([tbl, obj, maxSplits]) {
    tt = p.Term_TermType.SPLIT;
  }
}

class Upcase extends RqlMethodQuery {
  Upcase(obj) : super([obj]) {
    tt = p.Term_TermType.UPCASE;
  }
}

class Downcase extends RqlMethodQuery {
  Downcase(obj) : super([obj]) {
    tt = p.Term_TermType.DOWNCASE;
  }
}

class OffsetsOf extends RqlMethodQuery {
  OffsetsOf(seq, index) : super([seq, index]) {
    tt = p.Term_TermType.OFFSETS_OF;
  }
}

class IsEmpty extends RqlMethodQuery {
  IsEmpty(selection) : super([selection]) {
    tt = p.Term_TermType.IS_EMPTY;
  }
}

class Group extends RqlMethodQuery {
  Group(obj, groups, [options]) : super([obj, ...groups], options) {
    tt = p.Term_TermType.GROUP;
  }
}

class InnerJoin extends RqlMethodQuery {
  InnerJoin(first, second, predicate) : super([first, second, predicate]) {
    tt = p.Term_TermType.INNER_JOIN;
  }
}

class OuterJoin extends RqlMethodQuery {
  OuterJoin(first, second, predicate) : super([first, second, predicate]) {
    tt = p.Term_TermType.OUTER_JOIN;
  }
}

class EqJoin extends RqlMethodQuery {
  EqJoin(first, second, predicate, [Map? options])
      : super([first, second, predicate], options) {
    tt = p.Term_TermType.EQ_JOIN;
  }
}

class Zip extends RqlMethodQuery {
  Zip(seq) : super([seq]) {
    tt = p.Term_TermType.ZIP;
  }
}

class CoerceTo extends RqlMethodQuery {
  CoerceTo(obj, String type) : super([obj, type]) {
    tt = p.Term_TermType.COERCE_TO;
  }
}

class Ungroup extends RqlMethodQuery {
  Ungroup(obj) : super([obj]) {
    tt = p.Term_TermType.UNGROUP;
  }
}

class TypeOf extends RqlMethodQuery {
  TypeOf(obj) : super([obj]) {
    tt = p.Term_TermType.TYPE_OF;
  }
}

class Update extends RqlMethodQuery {
  Update(tbl, expression, [Map? options]) : super([tbl, expression], options) {
    tt = p.Term_TermType.UPDATE;
  }
}

class Delete extends RqlMethodQuery {
  Delete(selection, [Map? options]) : super([selection], options) {
    tt = p.Term_TermType.DELETE;
  }
}

class Replace extends RqlMethodQuery {
  Replace(table, expression, [options]) : super([table, expression], options) {
    tt = p.Term_TermType.REPLACE;
  }
}

class Insert extends RqlMethodQuery {
  Insert(table, records, [Map? options]) : super([table, records], options) {
    tt = p.Term_TermType.INSERT;
  }
}

class DbCreate extends RqlTopLevelQuery {
  DbCreate(String dbName, [Map? options]) : super([dbName], options) {
    tt = p.Term_TermType.DB_CREATE;
  }
}

class DbDrop extends RqlTopLevelQuery {
  DbDrop(String dbName, [Map? options]) : super([dbName], options) {
    tt = p.Term_TermType.DB_DROP;
  }
}

class DbList extends RqlTopLevelQuery {
  DbList() : super() {
    tt = p.Term_TermType.DB_LIST;
  }
}

class Range extends RqlTopLevelQuery {
  Range(end) : super([end]) {
    tt = p.Term_TermType.RANGE;
  }

  Range.asStream() : super() {
    tt = p.Term_TermType.RANGE;
  }

  Range.withStart(start, end) : super([start, end]) {
    tt = p.Term_TermType.RANGE;
  }
}

class TableCreate extends RqlMethodQuery {
  TableCreate(table, [Map? options]) : super([table], options) {
    tt = p.Term_TermType.TABLE_CREATE;
  }

  TableCreate.fromDB(db, table, [Map? options]) : super([db, table], options) {
    tt = p.Term_TermType.TABLE_CREATE;
  }
}

class TableDrop extends RqlMethodQuery {
  TableDrop(tbl, [Map? options]) : super([tbl], options) {
    tt = p.Term_TermType.TABLE_DROP;
  }

  TableDrop.fromDB(db, tbl, [Map? options]) : super([db, tbl], options) {
    tt = p.Term_TermType.TABLE_DROP;
  }
}

class TableList extends RqlMethodQuery {
  TableList([db]) : super(db == null ? [] : [db]) {
    tt = p.Term_TermType.TABLE_LIST;
  }
}

class IndexCreate extends RqlMethodQuery {
  IndexCreate(tbl, index, [Map? options]) : super([tbl, index], options) {
    tt = p.Term_TermType.INDEX_CREATE;
  }

  IndexCreate.withIndexFunction(tbl, index, [indexFunction, Map? options])
      : super([tbl, index, indexFunction], options) {
    tt = p.Term_TermType.INDEX_CREATE;
  }
}

class IndexDrop extends RqlMethodQuery {
  IndexDrop(table, index) : super([table, index]) {
    tt = p.Term_TermType.INDEX_DROP;
  }
}

class IndexRename extends RqlMethodQuery {
  IndexRename(table, oldName, newName, options)
      : super([table, oldName, newName], options) {
    tt = p.Term_TermType.INDEX_RENAME;
  }
}

class IndexList extends RqlMethodQuery {
  IndexList(table) : super([table]) {
    tt = p.Term_TermType.INDEX_LIST;
  }
}

class IndexStatus extends RqlMethodQuery {
  IndexStatus(tbl, indexList)
      : super([tbl, indexList is List ? Args(indexList) : indexList]) {
    tt = p.Term_TermType.INDEX_STATUS;
  }
  IndexStatus.all(tbl) : super([tbl]) {
    tt = p.Term_TermType.INDEX_STATUS;
  }
}

class IndexWait extends RqlMethodQuery {
  IndexWait(tbl, indexList)
      : super([tbl, indexList is List ? Args(indexList) : indexList]) {
    tt = p.Term_TermType.INDEX_WAIT;
  }
  IndexWait.all(tbl) : super([tbl]) {
    tt = p.Term_TermType.INDEX_WAIT;
  }
}

class Sync extends RqlMethodQuery {
  Sync(table) : super([table]) {
    tt = p.Term_TermType.SYNC;
  }
}

class Branch extends RqlTopLevelQuery {
  Branch(predicate, trueBranch, falseBranch)
      : super([predicate, trueBranch, falseBranch]) {
    tt = p.Term_TermType.BRANCH;
  }
  Branch.fromArgs(Args args) : super([args]) {
    tt = p.Term_TermType.BRANCH;
  }
}

class Or extends RqlBoolOperQuery {
  Or(super.orables) {
    tt = p.Term_TermType.OR;
  }
}

class And extends RqlBoolOperQuery {
  And(super.andables) {
    tt = p.Term_TermType.AND;
  }
}

class ForEach extends RqlMethodQuery {
  ForEach(obj, writeQuery) : super([obj, writeQuery]) {
    tt = p.Term_TermType.FOR_EACH;
  }
}

class Info extends RqlMethodQuery {
  Info(knowable) : super([knowable]) {
    tt = p.Term_TermType.INFO;
  }
}

class InsertAt extends RqlMethodQuery {
  InsertAt(ar, index, value) : super([ar, index, value]) {
    tt = p.Term_TermType.INSERT_AT;
  }
}

class SpliceAt extends RqlMethodQuery {
  SpliceAt(ar, index, value) : super([ar, index, value]) {
    tt = p.Term_TermType.SPLICE_AT;
  }
}

class DeleteAt extends RqlMethodQuery {
  DeleteAt(ar, index, value) : super([ar, index, value]) {
    tt = p.Term_TermType.DELETE_AT;
  }
}

class ChangeAt extends RqlMethodQuery {
  ChangeAt(ar, index, value) : super([ar, index, value]) {
    tt = p.Term_TermType.CHANGE_AT;
  }
}

class Sample extends RqlMethodQuery {
  Sample(selection, int i) : super([selection, i]) {
    tt = p.Term_TermType.SAMPLE;
  }
}

class Uuid extends RqlQuery {
  Uuid(str) : super(str == null ? [] : [str]) {
    tt = p.Term_TermType.UUID;
  }
}

class Json extends RqlTopLevelQuery {
  Json(String jsonString, [Map? options]) : super([jsonString], options) {
    tt = p.Term_TermType.JSON;
  }
}

class Args extends RqlTopLevelQuery {
  Args(List array) : super([array]) {
    tt = p.Term_TermType.ARGS;
  }
}

class ToISO8601 extends RqlMethodQuery {
  ToISO8601(obj) : super([obj]) {
    tt = p.Term_TermType.TO_ISO8601;
  }
}

class During extends RqlMethodQuery {
  During(obj, start, end, [Map? options]) : super([obj, start, end], options) {
    tt = p.Term_TermType.DURING;
  }
}

class Date extends RqlMethodQuery {
  Date(obj) : super([obj]) {
    tt = p.Term_TermType.DATE;
  }
}

class TimeOfDay extends RqlMethodQuery {
  TimeOfDay(obj) : super([obj]) {
    tt = p.Term_TermType.TIME_OF_DAY;
  }
}

class Timezone extends RqlMethodQuery {
  Timezone(zone) : super([zone]) {
    tt = p.Term_TermType.TIMEZONE;
  }
}

class Year extends RqlMethodQuery {
  Year(year) : super([year]) {
    tt = p.Term_TermType.YEAR;
  }
}

class Month extends RqlMethodQuery {
  Month(month) : super([month]) {
    tt = p.Term_TermType.MONTH;
  }
}

class Day extends RqlMethodQuery {
  Day(day) : super([day]) {
    tt = p.Term_TermType.DAY;
  }
}

class DayOfWeek extends RqlMethodQuery {
  DayOfWeek(dow) : super([dow]) {
    tt = p.Term_TermType.DAY_OF_WEEK;
  }
}

class DayOfYear extends RqlMethodQuery {
  DayOfYear(doy) : super([doy]) {
    tt = p.Term_TermType.DAY_OF_YEAR;
  }
}

class Hours extends RqlMethodQuery {
  Hours(hours) : super([hours]) {
    tt = p.Term_TermType.HOURS;
  }
}

class Minutes extends RqlMethodQuery {
  Minutes(minutes) : super([minutes]) {
    tt = p.Term_TermType.MINUTES;
  }
}

class Seconds extends RqlMethodQuery {
  Seconds(seconds) : super([seconds]) {
    tt = p.Term_TermType.SECONDS;
  }
}

class Binary extends RqlTopLevelQuery {
  Binary(data) : super([data]) {
    tt = p.Term_TermType.BINARY;
  }
}

class Time extends RqlTopLevelQuery {
  Time(Args args) : super([args]) {
    tt = p.Term_TermType.TIME;
  }

  Time.withHour(int year, int month, int day, String timezone, int hour)
      : super([year, month, day, hour, timezone]) {
    tt = p.Term_TermType.TIME;
  }

  Time.withMinute(
      int year, int month, int day, String timezone, int hour, int minute)
      : super([year, month, day, hour, minute, timezone]) {
    tt = p.Term_TermType.TIME;
  }

  Time.withSecond(int year, int month, int day, String timezone, int hour,
      int minute, int second)
      : super([year, month, day, hour, minute, second, timezone]) {
    tt = p.Term_TermType.TIME;
  }
}

class RqlISO8601 extends RqlTopLevelQuery {
  RqlISO8601(strTime, [defaultTimeZone = "Z"])
      : super([strTime], {"default_timezone": defaultTimeZone}) {
    tt = p.Term_TermType.ISO8601;
  }
}

class EpochTime extends RqlTopLevelQuery {
  EpochTime(eptime) : super([eptime]) {
    tt = p.Term_TermType.EPOCH_TIME;
  }
}

class Now extends RqlTopLevelQuery {
  Now() : super() {
    tt = p.Term_TermType.NOW;
  }
}

class InTimezone extends RqlMethodQuery {
  InTimezone(zoneable, tz) : super([zoneable, tz]) {
    tt = p.Term_TermType.IN_TIMEZONE;
  }
}

class ToEpochTime extends RqlMethodQuery {
  ToEpochTime(obj) : super([obj]) {
    tt = p.Term_TermType.TO_EPOCH_TIME;
  }
}

class Func extends RqlQuery {
  Function fun;
  int argsCount;
  static int nextId = 0;
  Func(this.fun, this.argsCount) : super(null, null) {
    tt = p.Term_TermType.FUNC;
    List vrs = [];
    List vrids = [];

    for (int i = 0; i < argsCount; i++) {
      vrs.add(Var(Func.nextId));
      vrids.add(Func.nextId);
      Func.nextId++;
    }

    args = [MakeArray(vrids), _expr(Function.apply(fun, vrs))];
  }
}

class Asc extends RqlTopLevelQuery {
  Asc(obj) : super([obj]) {
    tt = p.Term_TermType.ASC;
  }
}

class Desc extends RqlTopLevelQuery {
  Desc(attr) : super([attr]) {
    tt = p.Term_TermType.DESC;
  }
}

class Literal extends RqlTopLevelQuery {
  Literal(attr) : super([attr]) {
    tt = p.Term_TermType.LITERAL;
  }
}

class Circle extends RqlTopLevelQuery {
  Circle(point, radius, [Map? options]) : super([point, radius], options) {
    tt = p.Term_TermType.CIRCLE;
  }
}

class Distance extends RqlMethodQuery {
  Distance(obj, geo, [Map? options]) : super([obj, geo], options) {
    tt = p.Term_TermType.DISTANCE;
  }
}

class Fill extends RqlMethodQuery {
  Fill(obj) : super([obj]) {
    tt = p.Term_TermType.FILL;
  }
}

class GeoJson extends RqlTopLevelQuery {
  GeoJson(Map geoJson) : super([geoJson]) {
    tt = p.Term_TermType.GEOJSON;
  }
}

class ToGeoJson extends RqlMethodQuery {
  ToGeoJson(obj) : super([obj]) {
    tt = p.Term_TermType.TO_GEOJSON;
  }
}

class GetIntersecting extends RqlMethodQuery {
  GetIntersecting(table, geo, [Map? options]) : super([table, geo], options) {
    tt = p.Term_TermType.GET_INTERSECTING;
  }
}

class GetNearest extends RqlMethodQuery {
  GetNearest(table, point, Map? options) : super([table, point], options) {
    tt = p.Term_TermType.GET_NEAREST;
  }
}

class Includes extends RqlMethodQuery {
  Includes(obj, geo) : super([obj, geo]) {
    tt = p.Term_TermType.INCLUDES;
  }
}

class Intersects extends RqlMethodQuery {
  Intersects(obj, geo) : super([obj, geo]) {
    tt = p.Term_TermType.INTERSECTS;
  }
}

class Line extends RqlTopLevelQuery {
  Line(super.points) {
    tt = p.Term_TermType.LINE;
  }
}

class Point extends RqlTopLevelQuery {
  Point(long, lat) : super([long, lat]) {
    tt = p.Term_TermType.POINT;
  }
}

class Polygon extends RqlTopLevelQuery {
  Polygon(super.points) {
    tt = p.Term_TermType.POLYGON;
  }
}

class PolygonSub extends RqlMethodQuery {
  PolygonSub(var poly1, var poly2) : super([poly1, poly2]) {
    tt = p.Term_TermType.POLYGON_SUB;
  }
}

class Config extends RqlMethodQuery {
  Config(obj) : super([obj]) {
    tt = p.Term_TermType.CONFIG;
  }
}

class Rebalance extends RqlMethodQuery {
  Rebalance(obj) : super([obj]) {
    tt = p.Term_TermType.REBALANCE;
  }
}

class Reconfigure extends RqlMethodQuery {
  Reconfigure(obj, Map? options) : super([obj], options) {
    tt = p.Term_TermType.RECONFIGURE;
  }
}

class Status extends RqlMethodQuery {
  Status(obj) : super([obj]) {
    tt = p.Term_TermType.STATUS;
  }
}

class Wait extends RqlMethodQuery {
  Wait(obj, [Map? options]) : super([obj], options) {
    tt = p.Term_TermType.WAIT;
  }
}

class RqlTimeName extends RqlQuery {
  RqlTimeName(p.Term_TermType termType) {
    super.tt = termType;
  }
}

class RqlConstant extends RqlQuery {
  RqlConstant(p.Term_TermType termType) {
    super.tt = termType;
  }
}

class _RqlAllOptions {
  //list of every option from any term
  List? options;

  _RqlAllOptions(p.Term_TermType? tt) {
    switch (tt) {
      case p.Term_TermType.TABLE_CREATE:
        options = ['primary_key', 'durability', 'datacenter'];
        break;
      case p.Term_TermType.INSERT:
        options = ['durability', 'return_changes', 'conflict'];
        break;
      case p.Term_TermType.UPDATE:
        options = ['durability', 'return_changes', 'non_atomic'];
        break;
      case p.Term_TermType.REPLACE:
        options = ['durability', 'return_changes', 'non_atomic'];
        break;
      case p.Term_TermType.DELETE:
        options = ['durability', 'return_changes'];
        break;
      case p.Term_TermType.TABLE:
        options = ['read_mode'];
        break;
      case p.Term_TermType.INDEX_CREATE:
        options = ["multi"];
        break;
      case p.Term_TermType.GET_ALL:
        options = ['index'];
        break;
      case p.Term_TermType.BETWEEN:
        options = ['index', 'left_bound', 'right_bound'];
        break;
      case p.Term_TermType.FILTER:
        options = ['default'];
        break;
      case p.Term_TermType.CHANGES:
        options = ['includeOffsets', 'includeTypes'];
        break;
      case p.Term_TermType.EQ_JOIN:
        options = ['index', 'ordered'];
        break;
      case p.Term_TermType.UNION:
        options = ['interleave'];
        break;
      case p.Term_TermType.SLICE:
        options = ['left_bound', 'right_bound'];
        break;
      case p.Term_TermType.GROUP:
        options = ['index'];
        break;
      case p.Term_TermType.RANDOM:
        options = ['float'];
        break;
      case p.Term_TermType.ISO8601:
        options = ['default_timezone'];
        break;
      case p.Term_TermType.DURING:
        options = ['left_bound', 'right_bound'];
        break;
      case p.Term_TermType.JAVASCRIPT:
        options = ['timeout'];
        break;
      case p.Term_TermType.HTTP:
        options = [
          'timeout',
          'attempts',
          'redirects',
          'verify',
          'result_format',
          'method',
          'auth',
          'params',
          'header',
          'data',
          'page',
          'page_limit'
        ];
        break;
      case p.Term_TermType.CIRCLE:
        options = ['num_vertices', 'geo_system', 'unit', 'fill'];
        break;
      case p.Term_TermType.GET_NEAREST:
        options = ['index', 'max_results', 'max_dist', 'unit', 'geo_system'];
        break;
      case p.Term_TermType.RECONFIGURE:
        options = [
          'shards',
          'replicas',
          'primary_replica_tag',
          'dry_run',
          "emergency_repair"
        ];
        break;
      case p.Term_TermType.WAIT:
        options = ['wait_for', 'timeout'];
        break;
      default:
        options = [];
    }
  }
}
