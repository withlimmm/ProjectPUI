import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class MidtransService {
  static final MidtransService _instance = MidtransService._internal();

  static String get _baseUrl => apiBaseUrl;

  factory MidtransService() {
    return _instance;
  }

  MidtransService._internal();

  // Initialize Midtrans (For WebView, tidak perlu SDK init)
  Future<void> initMidtrans() async {
    // WebView approach tidak perlu initialization
  }

  // Get Transaction Token dari Backend
  // Returns redirect_url untuk dibuka di WebView
  Future<String?> getTransactionToken({
    required String orderId,
    required int grossAmount,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$_baseUrl/midtrans/token"),
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: jsonEncode({
              "order_id": orderId,
              "gross_amount": grossAmount,
              "customer_name": customerName,
              "customer_email": customerEmail,
              "customer_phone": customerPhone,
            }),
          )
          .timeout(const Duration(seconds: 30));

      // Debug log for backend response
      try {
        // ignore: avoid_print
        print(
          '[MidtransService] /midtrans/token status=${response.statusCode} body=${response.body}',
        );
      } catch (_) {}

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Prefer redirect_url for VT-Web flow
        if (data.containsKey('redirect_url') && data['redirect_url'] != null) {
          return data['redirect_url'];
        }

        // If backend returned a token (snap), surface a clear error
        if (data.containsKey('token') && data['token'] != null) {
          throw Exception(
            'Backend returned Snap token. For WebView flow the backend should return a redirect_url.',
          );
        }

        throw Exception(
          'Unexpected response from midtrans/token: ${response.body}',
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception("Error: ${errorData['message'] ?? 'Unknown error'}");
      }
    } catch (e) {
      throw Exception("Failed to get token: $e");
    }
  }

  // Proses Payment dengan WebView
  // Controller dan loading logic di-handle di payment screen
  Future<Map<String, dynamic>> processPayment({
    required String paymentUrl,
    required String orderId,
  }) async {
    try {
      return {'success': true, 'paymentUrl': paymentUrl, 'orderId': orderId};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e', 'orderId': orderId};
    }
  }

  // Verify Payment Status di Backend
  Future<Map<String, dynamic>> verifyPayment({
    required String orderId,
    required String transactionId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$_baseUrl/midtrans/verify"),
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: jsonEncode({
              "order_id": orderId,
              "transaction_id": transactionId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'verified': true,
          'status': data['status'],
          'message': data['message'],
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'verified': false,
          'message': errorData['message'] ?? 'Verification failed',
        };
      }
    } catch (e) {
      return {'verified': false, 'message': 'Error verifying payment: $e'};
    }
  }

  // Get Payment Status
  Future<Map<String, dynamic>> getPaymentStatus({
    required String orderId,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse("$_baseUrl/midtrans/status/$orderId"),
            headers: {"Accept": "application/json"},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'status': data['transaction_status'],
          'amount': data['gross_amount'],
          'timestamp': data['transaction_time'],
        };
      } else {
        return {'success': false, 'message': 'Payment status not found'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}

// Global instance
final midtransService = MidtransService();
