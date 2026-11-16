Map<String, dynamic> apiKeyTestBody(String key, {String? pin}) => {
      'key': key.trim(),
      if (pin != null && pin.trim().isNotEmpty) 'pin': pin.trim(),
    };
