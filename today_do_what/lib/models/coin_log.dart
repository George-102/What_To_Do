/// 金币流水条目。
class CoinLog {
  const CoinLog({
    required this.id,
    required this.date,
    required this.type,
    required this.amount,
    required this.note,
    required this.createdAt,
  });

  final String id;

  /// 记录产生的日期（yyyy-MM-dd）。
  final String date;

  /// 类型：earn（打卡收入） / spend（兑换支出）。
  final String type;

  /// 金额：正数为收入，负数为支出。
  final int amount;

  final String note;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'type': type,
        'amount': amount,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CoinLog.fromJson(Map<String, dynamic> json) => CoinLog(
        id: json['id'] as String,
        date: json['date'] as String,
        type: json['type'] as String,
        amount: json['amount'] as int,
        note: json['note'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}