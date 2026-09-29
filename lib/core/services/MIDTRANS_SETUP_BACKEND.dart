// ============================================================================
// SETUP MIDTRANS - BACKEND (LARAVEL)
// ============================================================================
//
// Untuk mengintegrasikan Midtrans dengan Flutter App, Anda perlu setup
// beberapa endpoint di backend Laravel. Ikuti langkah-langkah di bawah:

// ============================================================================
// STEP 1: Install Midtrans PHP Library
// ============================================================================
/*
composer require midtrans/midtrans-php
*/

// ============================================================================
// STEP 2: Buat Controller untuk Midtrans
// ============================================================================
/*
File: app/Http/Controllers/Api/MidtransController.php

<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Midtrans\Config;
use Midtrans\Snap;
use Midtrans\Transaction;

class MidtransController extends Controller
{
    public function __construct()
    {
        // Set Midtrans Configuration
        Config::$serverKey = env('MIDTRANS_SERVER_KEY');
        Config::$clientKey = env('MIDTRANS_CLIENT_KEY');
        Config::$isProduction = env('MIDTRANS_IS_PRODUCTION', false);
        Config::$isSanitized = true;
        Config::$is3ds = true;
    }

    /**
     * Get Snap Token untuk Payment
     */
    public function getToken(Request $request)
    {
        try {
            $order_id = $request->order_id;
            $gross_amount = (int)$request->gross_amount;
            $customer_name = $request->customer_name ?? 'Customer';
            $customer_email = $request->customer_email ?? 'customer@laundry.com';
            $customer_phone = $request->customer_phone ?? '08123456789';

            // Parameter Midtrans Snap
            $transaction_details = array(
                'order_id' => $order_id,
                'gross_amount' => $gross_amount,
            );

            $customer_details = array(
                'first_name' => $customer_name,
                'email' => $customer_email,
                'phone' => $customer_phone,
            );

            $snap_params = array(
                'transaction_details' => $transaction_details,
                'customer_details' => $customer_details,
            );

            // Get Snap Token
            $snap_token = Snap::getSnapToken($snap_params);

            return response()->json([
                'token' => $snap_token,
                'order_id' => $order_id,
            ], 200);

        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Error: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Verify Payment Status
     */
    public function verify(Request $request)
    {
        try {
            $order_id = $request->order_id;
            $transaction_id = $request->transaction_id;

            // Get Transaction Status
            $status = Transaction::status($transaction_id);

            // Update Database berdasarkan status
            $pesanan = \App\Models\Pesanan::where('id', 
                str_replace('PINT-', '', explode('-', $order_id)[1])
            )->first();

            if ($pesanan) {
                if ($status->transaction_status == 'settlement') {
                    $pesanan->update([
                        'status_pembayaran' => 'paid',
                        'payment_method' => 'midtrans',
                        'transaction_id' => $transaction_id,
                    ]);
                    
                    // Trigger notification ke user & admin
                    event(new \App\Events\PaymentSuccessful($pesanan));
                }
            }

            return response()->json([
                'verified' => true,
                'status' => $status->transaction_status,
                'message' => 'Payment verified successfully',
            ], 200);

        } catch (\Exception $e) {
            return response()->json([
                'verified' => false,
                'message' => 'Error: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get Payment Status
     */
    public function getStatus($order_id)
    {
        try {
            $transaction_id = $order_id;
            $status = Transaction::status($transaction_id);

            return response()->json([
                'transaction_status' => $status->transaction_status,
                'gross_amount' => $status->gross_amount,
                'transaction_time' => $status->transaction_time,
            ], 200);

        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Error: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Webhook Callback dari Midtrans (Untuk Server-to-Server)
     * PENTING: Aktifkan di Midtrans Dashboard Settings > Notification URL
     */
    public function webhook(Request $request)
    {
        try {
            $json = json_decode($request->getContent());
            $signature_key = $request->server_key;
            $order_id = $json->order_id;
            $status_code = $json->status_code;
            $transaction_status = $json->transaction_status;
            $transaction_id = $json->transaction_id;

            // Verify Signature
            $serverKey = env('MIDTRANS_SERVER_KEY');
            $hash = hash('sha512', $order_id . $status_code . $json->gross_amount . $serverKey);

            if ($hash !== $json->signature_key) {
                return response()->json(['error_msg' => 'Invalid signature'], 403);
            }

            // Process Based on Transaction Status
            if ($transaction_status == 'capture' || $transaction_status == 'settlement') {
                // Payment Success
                $pesanan = \App\Models\Pesanan::find(str_replace('PINT-', '', explode('-', $order_id)[1]));
                
                if ($pesanan) {
                    $pesanan->update([
                        'status_pembayaran' => 'paid',
                        'payment_method' => 'midtrans',
                        'transaction_id' => $transaction_id,
                    ]);

                    // Send Notification
                    event(new \App\Events\PaymentSuccessful($pesanan));
                }
            } else if ($transaction_status == 'pending') {
                // Payment Pending
                // Jangan update status pesanan
            } else if ($transaction_status == 'deny' || $transaction_status == 'cancel' || 
                      $transaction_status == 'expire') {
                // Payment Failed
                $pesanan = \App\Models\Pesanan::find(str_replace('PINT-', '', explode('-', $order_id)[1]));
                
                if ($pesanan) {
                    $pesanan->update([
                        'status_pembayaran' => 'failed',
                    ]);
                }
            }

            return response()->json(['status' => 'ok'], 200);

        } catch (\Exception $e) {
            return response()->json(['error' => $e->getMessage()], 500);
        }
    }
}
?>
*/

// ============================================================================
// STEP 3: Setup Routes di Laravel
// ============================================================================
/*
File: routes/api.php

Route::prefix('midtrans')->group(function () {
    Route::post('/token', [\App\Http\Controllers\Api\MidtransController::class, 'getToken']);
    Route::post('/verify', [\App\Http\Controllers\Api\MidtransController::class, 'verify']);
    Route::get('/status/{order_id}', [\App\Http\Controllers\Api\MidtransController::class, 'getStatus']);
    Route::post('/webhook', [\App\Http\Controllers\Api\MidtransController::class, 'webhook']);
});
*/

// ============================================================================
// STEP 4: Setup .env di Laravel
// ============================================================================
/*
MIDTRANS_SERVER_KEY=SB-Mid-server-XXXXXXXXXXXXXXXXXX
MIDTRANS_CLIENT_KEY=SB-Mid-client-XXXXXXXXXXXXXXXXXX
MIDTRANS_IS_PRODUCTION=false

// Untuk production, ubah sandbox key ke live key:
MIDTRANS_IS_PRODUCTION=true
*/

// ============================================================================
// STEP 5: Update Model Pesanan untuk Payment Status
// ============================================================================
/*
Migration: add_payment_fields_to_pesanan

Schema::table('pesanan', function (Blueprint $table) {
    $table->enum('status_pembayaran', ['pending', 'paid', 'failed'])->default('pending');
    $table->string('payment_method')->nullable();
    $table->string('transaction_id')->nullable();
    $table->timestamp('paid_at')->nullable();
});
*/

// ============================================================================
// STEP 6: Update Flutter App Config
// ============================================================================
/*
File: lib/core/services/midtrans_service.dart

Ganti SERVER_KEY dan CLIENT_KEY dengan Midtrans credentials Anda:

static const String _serverKey = "SB-Mid-server-XXXXXXXXXXXXXXXXXX";
static const String _clientKey = "SB-Mid-client-XXXXXXXXXXXXXXXXXX";

Untuk production, update environment:
environment: MidtransEnvironment.production, // dari sandbox
*/

// ============================================================================
// STEP 7: Setup Webhook di Midtrans Dashboard
// ============================================================================
/*
1. Login ke Midtrans Dashboard: https://dashboard.midtrans.com
2. Pilih Environment Sandbox/Production
3. Settings > Notification URL
4. Masukkan URL Webhook:
   http://192.168.1.7:8000/api/midtrans/webhook
5. Pilih HTTP POST method
6. Test webhook dari dashboard
*/

// ============================================================================
// STEP 8: Admin Panel Integration (Notifikasi Pembayaran)
// ============================================================================
/*
Buat Event untuk Payment Success:

File: app/Events/PaymentSuccessful.php

class PaymentSuccessful
{
    public $pesanan;

    public function __construct($pesanan)
    {
        $this->pesanan = $pesanan;
    }

    public function broadcastOn()
    {
        return new PrivateChannel('pesanan.' . $this->pesanan->id);
    }
}

Di Admin Panel, listen untuk event ini:
- Update status pesanan ke "Dibayar"
- Kirim notifikasi ke admin
- Update dashboard dengan data terbaru
*/

// ============================================================================
// STEP 9: Test Payment Flow
// ============================================================================
/*
1. Login ke aplikasi Flutter
2. Buat pesanan
3. Klik "Lanjut ke Pembayaran"
4. Midtrans payment UI akan tampil di aplikasi
5. Pilih metode pembayaran (Transfer Bank, E-Wallet, dll)
6. Selesaikan pembayaran
7. Aplikasi akan menampilkan notifikasi sukses
8. Admin panel akan menerima notifikasi pembayaran

Untuk testing, gunakan kartu kredit sandbox Midtrans:
- Card: 4111111111111111
- Exp: 12/25
- CVV: 123
*/

// ============================================================================
// TROUBLESHOOTING
// ============================================================================
/*
1. Token Error?
   - Pastikan SERVER_KEY dan CLIENT_KEY benar
   - Cek MIDTRANS_IS_PRODUCTION setting sesuai environment

2. Payment tidak terverifikasi?
   - Check webhook setup di Midtrans Dashboard
   - Pastikan Notification URL bisa di-reach dari internet

3. Status pesanan tidak ter-update?
   - Cek event listener di admin panel
   - Cek database migration untuk payment fields

4. Payment timeout?
   - Tambah timeout di midtrans_service.dart:
     .timeout(const Duration(seconds: 60));

5. Android App Error?
   - Pastikan network_security_config.xml sudah dikonfigurasi
   - Cleartext traffic harus diizinkan untuk Midtrans server
*/
