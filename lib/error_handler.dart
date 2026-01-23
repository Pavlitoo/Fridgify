import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'translations.dart';

class ErrorHandler {
  static String getMessage(Object error) {
    String errorString = error.toString().toLowerCase();
    print("🔴 Error Caught: $errorString");

    // Обробка проблем з інтернетом (включаючи Internal Error)
    if (error is SocketException ||
        errorString.contains('socketexception') ||
        errorString.contains('network_error') ||
        errorString.contains('network_request_failed') ||
        errorString.contains('timeout') ||
        errorString.contains('offline') ||
        errorString.contains('internal error') ||
        errorString.contains('an internal error has occurred')) {
      return AppText.get('err_no_internet');
    }

    if (errorString.contains('canceled') ||
        errorString.contains('aborted') ||
        errorString.contains('user_cancelled')) {
      return AppText.get('err_canceled');
    }

    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found': return AppText.get('err_user_not_found');
        case 'wrong-password': return AppText.get('err_wrong_pass');
        case 'email-already-in-use': return AppText.get('err_email_exist');
        case 'invalid-email': return AppText.get('err_invalid_email');
        case 'weak-password': return AppText.get('err_weak_pass');
      // Додав ці два коди, бо вони теж бувають, щоб було красиво
        case 'too-many-requests': return AppText.get('err_too_many');
        case 'access-denied': return AppText.get('err_access_denied');
        default: return "${AppText.get('err_general')}: ${error.code}"; // Замінив err_unknown на err_general
      }
    }

    if (errorString.contains('permission-denied')) {
      return AppText.get('err_access_denied');
    }

    return AppText.get('err_general');
  }
}