/// 自定义奖励：名称 + 兑换所需金币。
class Reward {
  const Reward({required this.id, required this.name, required this.price});

  final String id;
  final String name;
  final int price;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price};

  factory Reward.fromJson(Map<String, dynamic> json) => Reward(
        id: json['id'] as String,
        name: json['name'] as String,
        price: json['price'] as int,
      );
}