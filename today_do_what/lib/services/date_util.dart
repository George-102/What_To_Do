/// 日期工具：统一使用本地 yyyy-MM-dd 字符串。
///
/// 所有「天」相关的逻辑都走这里，避免各处重复解析、格式不一致。
String ymd(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// 返回 yyyy-MM-dd 减去 [days] 天后的日期。
String subtractDays(String ymdStr, int days) {
  final p = ymdStr.split('-');
  final dt = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  return ymd(dt.subtract(Duration(days: days)));
}

/// 昨天的日期。
String yesterdayOf(String s) => subtractDays(s, 1);

/// 两个 yyyy-MM-dd 相差的天数（[b] - [a]）。
int daysBetween(String a, String b) {
  final pa = a.split('-');
  final pb = b.split('-');
  final da = DateTime(int.parse(pa[0]), int.parse(pa[1]), int.parse(pa[2]));
  final db = DateTime(int.parse(pb[0]), int.parse(pb[1]), int.parse(pb[2]));
  return db.difference(da).inDays;
}

/// 返回 [dt] 所属的 ISO 周序号（周一起始）。
///
/// 用于「每周一次反悔」的判定：同一年内同一自然周返回同一序号。
int isoWeek(DateTime dt) {
  final date = DateTime(dt.year, dt.month, dt.day);
  // 该周周一的日期（ISO 每周从周一开始，weekday 1=周一）。
  final monday = date.subtract(Duration(days: date.weekday - 1));
  final year = monday.year;
  // 1 月 4 日必在 ISO 第 1 周内，用它算出第 1 周的周一，再求周数差。
  final jan4 = DateTime(year, 1, 4);
  final yearStartMonday = jan4.subtract(Duration(days: jan4.weekday - 1));
  return monday.difference(yearStartMonday).inDays ~/ 7 + 1;
}