# Walkthrough - BharatPe Direct UPI Payment Integration

Implemented a direct BharatPe UPI payment option in the Ziko application with automatic transaction verification.

## Changes Made

### 1. Payment Service & BharatPe Integration
- **[NEW] [bharatpe_service_impl.dart](file:///C:/Users/LG/AndroidStudioProjects/ziko_v4/lib/core/services/payment/bharatpe_service_impl.dart)**:
  - Implemented unique payable amount generator (`calculateUniquePayableAmount`) to prevent concurrent order amount collisions.
  - Built UPI deep link URI generator (`getUpiIntentUri`) with prefilled amount, VPA, and order ID.
  - Implemented `getBharatPeTransactions` querying `https://payments-tesseract.bharatpe.in/api/v1/merchant/transactions` using observed headers (`token`) and query parameters (`module=PAYMENT_QR`, `merchantId=68424909`, `isFromOtDashboard=1`).
  - Implemented `verifyBharatPePayment` candidate matching logic (`merchantId`, `type == 'PAYMENT_RECV'`, `status == 'SUCCESS'`, `amount == expectedAmount`, `paymentTimestamp >= orderCreatedAtMs`).

- **[MODIFY] [payment_service.dart](file:///C:/Users/LG/AndroidStudioProjects/ziko_v4/lib/core/services/payment/payment_service.dart)**:
  - Added `PaymentGateway.bharatpe` to the enum and wired it up in `paymentServiceFor`.

### 2. Order Repository & Database Fields
- **[MODIFY] [order_repository.dart](file:///C:/Users/LG/AndroidStudioProjects/ziko_v4/lib/features/customer/data/order_repository.dart)**:
  - Added support for `payable_amount`, `bank_reference_no`, `internal_utr`, and `bharatpe_txn_id` during order placement.
  - Implemented `verifyAndConfirmBharatPeOrder` to check BharatPe transactions and update order status to `placed` and payment status to `paid` upon success with uniqueness constraints.

### 3. Customer Checkout UI & Realtime Polling
- **[MODIFY] [checkout_screen.dart](file:///C:/Users/LG/AndroidStudioProjects/ziko_v4/lib/features/customer/presentation/checkout_screen.dart)**:
  - Added **"BharatPe UPI / QR Code"** payment tile option.
  - Implemented `_showBharatPePaymentDialog` featuring:
    - Exact Unique Payable Amount display (e.g. ₹499.17).
    - Dynamic QR Code rendering (`QrImageView`).
    - **"Pay via Any UPI App"** button launching UPI intent URI via `url_launcher`.
    - Real-time polling timer checking verification every 4 seconds, automatically redirecting to `OrderSuccessScreen` on success.

### 4. Admin Reconciliation
- **[MODIFY] [admin_orders_tab.dart](file:///C:/Users/LG/AndroidStudioProjects/ziko_v4/lib/features/admin/presentation/admin_orders_tab.dart)**:
  - Added display for payment method, status, and Bank Reference / UTR Number (`bank_reference_no`) in the admin orders list for auditing and reconciliation.

## Verification Results
- Verified clean compilation and static analysis with zero errors across all modified and new files.
