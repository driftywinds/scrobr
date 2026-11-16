String normalizeDeviceCode(String raw) =>
    raw.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

Map<String, dynamic> deviceApproveBody({
  required String userCode,
  required bool approve,
  String? name,
}) =>
    {
      'user_code': normalizeDeviceCode(userCode),
      'action': approve ? 'approve' : 'deny',
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
    };
