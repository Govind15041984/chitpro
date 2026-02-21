class MemberSlot {
  final int slotNo;
  final String name;
  final String? mobile;

  const MemberSlot({
    required this.slotNo,
    required this.name,
    this.mobile,
  });

  factory MemberSlot.fromJson(Map<String, dynamic> json) {
    // SAFETY: support multiple key styles & nulls
    final slot = json['slot_no'] ?? json['slotNo'];

    return MemberSlot(
      slotNo: slot is int ? slot : int.parse(slot.toString()),
      name: json['name']?.toString() ?? '',
      mobile: json['mobile']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "slot_no": slotNo,
      "name": name,
      "mobile": mobile,
    };
  }

  MemberSlot copyWith({
    String? name,
    String? mobile,
  }) {
    return MemberSlot(
      slotNo: slotNo,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
    );
  }
}
