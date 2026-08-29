part of '../api_service.dart';

extension ApiProfile on SwingApiService {
  // ── PROFIL ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final r = await _authedGet(Uri.parse('$_baseUrl/users/me'));
      if (r.statusCode == 200) {
        final data = json.decode(r.body) as Map<String, dynamic>;
        _canDownload = data['can_download'] ?? false;
        return data;
      }
    } catch (e) { LoggerService.warning('Silent error caught in api_profile.dart', e); }
    return {};
  }

  Future<Map<String, dynamic>?> updateProfile({
    String? username, String? email, String? birthDate, String? bio,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (username  != null) body['username']   = username;
      if (email     != null) body['email']      = email;
      if (birthDate != null) body['birth_date'] = birthDate;
      if (bio       != null) body['bio']        = bio;
      final r = await _client.patch(
        Uri.parse('$_baseUrl/users/me'),
        headers: _headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
      final err = json.decode(r.body);
      throw Exception(err['detail'] ?? 'Erreur serveur');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> changePassword(String current, String newPwd) async {
    final r = await _client.post(
      Uri.parse('$_baseUrl/users/me/password'),
      headers: _headers,
      body: json.encode({'current_password': current, 'new_password': newPwd}),
    ).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) {
      final err = json.decode(r.body);
      throw Exception(err['detail'] ?? 'Erreur changement mot de passe');
    }
  }

  Future<String?> uploadAvatar(List<int> imageBytes) async {
    try {
      final r = await _client.post(
        Uri.parse('$_baseUrl/users/me/avatar'),
        headers: {..._headers, 'Content-Type': 'application/octet-stream'},
        body: imageBytes,
      ).timeout(const Duration(seconds: 30));
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        return data['avatar'] as String?;
      }
    } catch (e) { LoggerService.warning('Silent error caught in api_profile.dart', e); }
    return null;
  }

  String getAvatarUrl(int userId) => '$_baseUrl/users/me/avatar/$userId';



}
