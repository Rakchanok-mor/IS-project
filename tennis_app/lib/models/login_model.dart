import 'package:flutter/material.dart';

class LoginModel extends ChangeNotifier {
  String _username = '';

  String get username => _username;

  set username(String value) {
    _username = value;
    notifyListeners();
  }
}
